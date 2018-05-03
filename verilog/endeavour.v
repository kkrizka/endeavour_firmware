
/*
 * endeavour.v
 *
 * Attempt to implement Mitch Newcomer's "Morse Code" serial protocol
 * for reading/writing AMAC register file.  (Obscure reference:
 * Inspector Morse's (secret) given name was Endeavour.)
 * 
 * begun 2017-08-16 by WJA (ashmansk@hep.upenn.edu)
 */

/*
 * Write command (MSb first): 56 bits total
 *   3'b111, amacid[4:0], addr[7:0], data[31:0], crc[7:0]
 * Read command:
 *   3'b101, amacid[4:0], addr[7:0]
 * Read-next-address command:
 *   3'b100, amacid[4:0]
 * Write-commID command: 56 bits total
 *   (only works once per hard reset)
 *   3'b110, 5'b11111,              #  [55:48]
 *   3'b111, newamacid[4:0],        #  [47:40]
 *   4'b1111, efuseid[19:0],        #  [39:16]
 *   3'b111, idpads[4:0],           #  [15: 8]
 *   crc[7:0]                       #  [ 7: 0]
 */


`default_nettype none
`timescale 1ns/1ps

module endeavour 
  (
   // utility
   input  wire         hardrstb,      // active-low asynchronous "hard" reset
   input  wire         softrstb,      // active-low asynchronous "soft" reset
   input  wire         clk,           // AMAC ring osc, nominally ~ 40 MHz
   input  wire [4:0]   chipid_pads,   // wire-bonded chip ID number
   input  wire [19:0]  efuse_chipid,  // chip ID number from efuse PROM
   // communication with end-of-stave card
   input  wire         serialin,      // single-ended version of command input
   output wire         serialout,     // response to EOS card
   output wire         serialout_en,  // HIGH=enable, LOW=three-state/high-Z
   // register-file interface
   output wire         wstrobe,       // write strobe, synchronous to clk
   output wire         rstrobe,       // read: target register loads shift reg
   output wire         rshift,        // read: target register shifts 1 bit
   output wire [7:0]   addr,          // write/read address
   output wire [31:0]  wdata,         // write data (to single 32-bit reg)
   input  wire [255:0] rdata          // read data (serial, one per reg)
   );
    // Nearly everything can be reset by either !softrstb or !hardrstb
    wire rstb = softrstb && hardrstb;
    // The communications ID can only be reset by !hardrstb
    wire [4:0] commid;         // this AMAC's address on the serial bus
    wire       commid_known;   // has the commid been set yet?
    wire [4:0] commid_d;
    reg        do_set_commid;  // combinational, not FF
    dffe_nbit_t #(.W(6), .PU(6'b011111)) 
    commid_reg_t  // SEU-protected 'commid' register
      ( .rstb(hardrstb), .clk(clk),
	.ena(do_set_commid && !commid_known),
	.d({1'b1,commid_d}),
	.q({commid_known,commid}),
	.serOut()  // soft-error output unused
	);
    // Synchronize incoming serial data (from EOS card, independent clock)
    reg [4:0] din_sync;
    reg       din;
    always @ (posedge clk or negedge rstb) begin
	if (!rstb) begin
	    din_sync <= 5'b0;
	    din      <= 1'b0;
	end else begin
	    din_sync[0] <= serialin;
	    din_sync[1] <= din_sync[0];
	    din_sync[2] <= din_sync[1];
	    din_sync[3] <= din_sync[2];
	    din_sync[4] <= din_sync[3];
	    din         <= (din_sync[4] && din_sync[2]) || 
			   (din_sync[4] && din_sync[3]) ||
			   (din_sync[3] && din_sync[2]) ;
	end
    end
    // Shift register to accumulate command word
    reg [63:0] sreg;
    reg sreg_clear, sreg_in, sreg_shift;  // combinational, not FF
    always @ (posedge clk or negedge rstb) begin
	if (!rstb) begin
	    sreg <= 64'b0;
	end else if (sreg_clear) begin
	    sreg <= 64'b0;
	end else if (sreg_shift) begin
	    sreg <= {sreg[62:0], sreg_in};
	end
    end
    // Constants determining durations of various FSM timeouts
    localparam TICKS_QUIESCENT = 256;  // required pause between words
    localparam TICKS_BLIP = 4;     // minimum width of a DIT
    localparam TICKS_DIT = 16;     // tBLIP + tDIT = max width of DIT
    localparam TICKS_DMZ = 4;      // tBLIP + tDIT + tDMZ = min width of DAH
    localparam TICKS_DAH = 96;     // tBLIP + ... + tDAH = max width of DAH
    localparam TICKS_BITGAP = 8;   // minimum gap between bits
    localparam TICKS_NEXTBIT = 64; // tBITGAP + tNEXTBIT = max gap betw bits
    localparam TICKS_TXDIT = 8;    // width of reply DIT
    localparam TICKS_TXDAH = 48;   // width of reply DAH
    localparam TICKS_TXGAP = 16;   // gap between bits in reply
    localparam TICKS_RBITS = 32;   // number of shift operations on reg read
    localparam BITCOUNT_MAX = 56;
    localparam CMD_RD     = 3'b101;
    localparam CMD_RDNEXT = 3'b100;
    localparam CMD_SETID  = 3'b110;
    localparam CMD_WR     = 3'b111;
    localparam SHORT_REPLY_NBITS = 6'd8;  // length of reply to WRITE or SETID
    localparam LONG_REPLY_NBITS = 6'd48;  // length of reply to READ
    localparam WRCMD_NBITS     = 6'd56;   // length of WR or SETID command
    localparam RDCMD_NBITS     = 6'd16;   // length of RD command
    localparam RDNEXTCMD_NBITS = 6'd8;    // length of RDNEXT command
    // Decode sreg bits for mnemonic value
    wire [2:0]  sreg_cmd     = sreg[55:53];
    wire [4:0]  sreg_id      = sreg[52:48];
    wire [7:0]  sreg_addr    = sreg[47:40];
    wire [31:0] sreg_data    = sreg[39:8];
    wire [7:0]  sreg_crc     = sreg[7:0];
    assign commid_d = sreg[44:40];  // for SETID command
    wire [19:0] sreg_efuseid = sreg[35:16];
    wire [4:0]  sreg_padid   = sreg[12:8];
    wire id_match = commid_known && (sreg_id == commid);
    wire setid_match =
	 (!commid_known) &&
	 ((sreg_efuseid==efuse_chipid && sreg_padid==5'b11111) ||
	  (sreg_efuseid==20'hfffff    && sreg_padid==chipid_pads));
    // Remember last-used read address, for RDNEXT command
    reg [7:0] rdaddr;
    reg [7:0] rdaddr_d;    // combinational, not FF
    reg       rdaddr_ena;  // combinational, not FF
    always @ (posedge clk or negedge rstb) begin
	if (!rstb) begin
	    rdaddr <= 8'b0;
	end else if (rdaddr_ena) begin
	    rdaddr <= rdaddr_d;
	end
    end
    // Calculate 8-bit CRC (1+x^8) of message bits [55:8]
    wire [7:0] sreg_calccrc =
	       sreg[55:48] ^ sreg[47:40] ^ sreg[39:32] ^ 
	       sreg[31:24] ^ sreg[23:16] ^ sreg[15: 8];
    wire crcok = (sreg_calccrc == sreg_crc);
    // Use flip-flops to drive register-file interface
    reg        rstrobe_ff, rshift_ff;
    reg        wstrobe_ff, wstrobe_ff1;
    reg        wstrobe_d, rstrobe_d, rshift_d;  // combinational, not FF
    reg        addr_clear;  // combinational, not FF
    reg [7:0]  addr_ff;
    reg [31:0] wdata_ff;
    always @ (posedge clk or negedge rstb) begin
	if (!rstb) begin
	    addr_ff  <= 8'b0;
	    wdata_ff <= 32'b0;
	end else if (addr_clear) begin
	    // Make sure that if wstrobe is asserted by an SEU, the
	    // effect (unless this happens at an extremely unfortunate
	    // instant) is a harmless write to read-only address 0.
	    addr_ff  <= 8'b0;
	    wdata_ff <= 32'b0;
	end else if (rstrobe_d) begin
	    addr_ff  <= rdaddr;
	end else if (wstrobe_d) begin
	    addr_ff  <= sreg_addr;
	    wdata_ff <= sreg_data;
	end
    end
    always @ (posedge clk or negedge rstb) begin
	if (!rstb) begin
	    wstrobe_ff  <= 1'b0;
	    wstrobe_ff1 <= 1'b0;
	    rstrobe_ff  <= 1'b0;
	    rshift_ff   <= 1'b0;
	end else begin
	    wstrobe_ff  <= wstrobe_d;
	    wstrobe_ff1 <= wstrobe_ff;
	    rstrobe_ff  <= rstrobe_d;
	    rshift_ff   <= rshift_d;
	end
    end
    assign wstrobe = wstrobe_ff1;  // delay wstrobe one clk wrt addr/wdata
    assign rstrobe = rstrobe_ff;
    assign rshift  = rshift_ff;
    assign addr    = addr_ff;
    assign wdata   = wdata_ff;
    // Shift register to receive data read from register file
    wire rdat;  // selected [addr] bit of rdata
    reg [1:0] rdat_ff;  // pipeline delay
    reg [31:0] srin;
    always @ (posedge clk or negedge rstb) begin
	if (!rstb) begin
	    rdat_ff <= 2'b0;
	    srin    <= 32'b0;
	end else if (rshift_ff) begin
	    rdat_ff <= {rdat_ff[0], rdat};
	    srin    <= {srin[30:0], rdat_ff[1]};
	end
    end
    // Shift register to serialize reply sent to EOS card; also maintain
    // "sequence number" of valid operations processed by this FSM.
    reg [47:0] srout;
    reg [5:0]  srout_bitcount;
    reg [5:0]  srout_bitcount_d;  // comb, not FF
    wire [2:0] seqnum;
    reg srout_load, srout_shift, seqnum_inc;  // comb, not FF
    always @ (posedge clk or negedge rstb) begin
	if (!rstb) begin
	    srout <= 48'b0;
	    srout_bitcount <= 6'b0;
	end else if (srout_load) begin
	    srout_bitcount <= srout_bitcount_d;
	    srout[47:43] <= commid;
	    srout[42:40] <= seqnum;
	    srout[39:32] <= rdaddr;
	    srout[31:0]  <= srin;  // data read from register file
	end else if (srout_shift) begin
	    srout_bitcount <= (srout_bitcount==6'b0 ? 
			       6'b0 : srout_bitcount - 1'b1);
	    srout <= {srout[46:0], 1'b0};
	end
    end
    dffe_nbit_t #(.W(3), .PU(3'b000))
    seqnum_reg_t  // SEU-protected 'seqnum' register
      ( .rstb(rstb), .clk(clk), .ena(seqnum_inc), 
	.d(seqnum + 1'b1), .q(seqnum), 
	.serOut()  // soft-error output unused
	);
    // Count number of bits seen for current word coming in from serialin
    reg [5:0] bitcount;
    reg bitcount_clear, bitcount_inc;  // combinational, not FF
    always @ (posedge clk or negedge rstb) begin
	if (!rstb) begin
	    bitcount <= 6'b0;
	end else if (bitcount_clear) begin
	    bitcount <= 6'b0;
	end else if (bitcount_inc) begin
	    bitcount <= bitcount + 1'b1;
	end
    end
    // Record number of bits seen before right-padding ("no pad")
    reg [5:0] bitcountnp;
    reg bitcountnp_ena;  // combinational, not FF
    always @ (posedge clk or negedge rstb) begin
	if (!rstb) begin
	    bitcountnp <= 6'b0;
	end else if (bitcount_clear) begin
	    bitcountnp <= 6'b0;
	end else if (bitcountnp_ena) begin
	    bitcountnp <= bitcount;
	end
    end
    // Counter to facilitate FSM transitions based on elapsed time
    reg [11:0] ticks;
    reg ticks_clear;  // combinational, not FF
    always @ (posedge clk or negedge rstb) begin
	if (!rstb) begin
	    ticks <= 12'b0;
	end else if (ticks_clear) begin
	    ticks <= 12'b0;
	end else if (ticks != 12'hfff) begin
	    // unusual counter: let's not let it wrap around to zero
	    ticks <= ticks + 1'b1;
	end
    end
    // Use flip-flops to drive serial output (reply to EOS card)
    reg dout_ff, douten_ff;
    reg dout, douten;  // combinational, not FF
    always @ (posedge clk or negedge rstb) begin
	if (!rstb) begin
	    dout_ff    <= 1'b0;
	    douten_ff <= 1'b0;
	end else begin
	    dout_ff <= dout;
	    douten_ff <= douten;
	end
    end
    assign serialout    = dout_ff;
    assign serialout_en = douten_ff;
    // State machine to interpret incoming stream of "Morse Code" bits
    localparam  // FSM state list
      START=7'd0, QUIESCENT=7'd1, WAIT_FIRSTBIT=7'd2, HIGH_BLIP=7'd3,
      HIGH_DIT=7'd4, HIGH_DMZ=7'd5, HIGH_DAH=7'd6, GOT_BIT=7'd7, BITGAP=7'd8,
      WAIT_NEXTBIT=7'd9, REALIGN=7'd10, EOT=7'd11, WRCMD=7'd126,
      SETIDCMD=7'd13, SETIDCMD1=7'd14, RDNEXTCMD=7'd15, RDCMD=7'd16,
      RDCMD1=7'd17, RDCMD2=7'd18, RDCMD3=7'd19, RDCMD4=7'd20, RDCMD5=7'd21,
      RDCMD9=7'd22, REPLY=7'd23, REPLYLOOP=7'd24, SEND_DIT=7'd25,
      SEND_DAH=7'd26, SEND_BITGAP=7'd27, ERROR=7'd31;
    reg [6:0] fsm, fsm_prev;  // flip-flops
    reg [6:0] fsm_d;  // combinational logic
    always @ (posedge clk or negedge rstb) begin
	if (!rstb) begin
	    fsm <= START;
	    fsm_prev <= START;
	end else begin
	    fsm <= fsm_d;  // next state from combinational logic
	    fsm_prev <= fsm;  // remember state from one cycle ago
	end
    end
    // The following is a COMBINATIONAL always block
    always @ (*) begin
	// Assign default values to avoid risk of implicit latches
	fsm_d            = START;
	sreg_clear       = 1'b0;
	sreg_in          = 1'b0;
	sreg_shift       = 1'b0;
	ticks_clear      = 1'b0;
	bitcount_clear   = 1'b0;
	bitcount_inc     = 1'b0;
	bitcountnp_ena   = 1'b0;
	wstrobe_d        = 1'b0;
	rstrobe_d        = 1'b0;
	rshift_d         = 1'b0;
	douten           = 1'b0;
	dout             = 1'b0;
	srout_load       = 1'b0;
	srout_shift      = 1'b0;
	srout_bitcount_d = 6'b0;
	seqnum_inc       = 1'b0;
	do_set_commid    = 1'b0;
	rdaddr_ena       = 1'b0;
	rdaddr_d         = 8'b0;
	addr_clear       = 1'b0;
	case (fsm)
	    START:
	      // Initial state.  Wait for DIN to go LOW.
	      begin
		  sreg_clear = 1'b1;   // zero accumulated incoming message
		  ticks_clear = 1'b1;  // zero multi-purpose timer
		  addr_clear = 1'b1;   // zero regfile write address
		  fsm_d = din ? START : QUIESCENT;
	      end
	    QUIESCENT:
	      // Insist that DIN remain LOW for >= TICKS_QUIESCENT ticks.
	      begin
		  sreg_clear = 1'b1;
		  ticks_clear = 1'b0;
		  addr_clear = 1'b1;
		  if (din) begin
		      fsm_d = START;
		  end else if (ticks >= TICKS_QUIESCENT) begin
		      fsm_d = WAIT_FIRSTBIT;
		  end else begin
		      fsm_d = QUIESCENT;
		  end
	      end
	    WAIT_FIRSTBIT:
	      // Wait for inter-word rising edge.
	      begin
		  sreg_clear = 1'b1;
		  ticks_clear = 1'b1;
		  bitcount_clear = 1'b1;
		  addr_clear = 1'b1;
		  fsm_d = din ? HIGH_BLIP : WAIT_FIRSTBIT;
	      end
	    HIGH_BLIP:
	      // DIN has been HIGH for at least a blip (glitch)
	      begin
		  sreg_clear = 1'b0;
		  ticks_clear = 1'b0;
		  if (!din) begin
		      fsm_d = ERROR;
		  end else if (ticks >= TICKS_BLIP) begin
		      ticks_clear = 1'b1;
		      fsm_d = HIGH_DIT;
		  end else begin
		      fsm_d = HIGH_BLIP;
		  end
	      end
	    HIGH_DIT:
	      // DIN has been HIGH for at least a dit (valid short pulse)
	      begin
		  sreg_clear = 1'b0;
		  ticks_clear = 1'b0;
		  if (!din) begin
		      fsm_d = GOT_BIT;
		  end else if (ticks >= TICKS_DIT) begin
		      ticks_clear = 1'b1;
		      fsm_d = HIGH_DMZ;
		  end else begin
		      fsm_d = HIGH_DIT;
		  end
	      end
	    HIGH_DMZ:
	      // DIN high for longer than a dit but not yet a dah
	      begin
		  sreg_clear = 1'b0;
		  ticks_clear = 1'b0;
		  if (!din) begin
		      fsm_d = ERROR;
		  end else if (ticks >= TICKS_DMZ) begin
		      ticks_clear = 1'b1;
		      fsm_d = HIGH_DAH;
		  end else begin
		      fsm_d = HIGH_DMZ;
		  end
	      end
	    HIGH_DAH:
	      // DIN high for at least a dah
	      begin
		  sreg_clear = 1'b0;
		  ticks_clear = 1'b0;
		  if (!din) begin
		      fsm_d = GOT_BIT;
		  end else if (ticks >= TICKS_DAH) begin
		      fsm_d = ERROR;
		  end else begin
		      fsm_d = HIGH_DAH;
		  end
	      end
	    GOT_BIT:
	      // We've received a valid ZERO or ONE
	      begin
		  if ((fsm_prev==HIGH_DAH || fsm_prev==HIGH_DIT) && !din)
		    // protect against landing in GOT_BIT via SEU
		  begin
		      sreg_in = (fsm_prev==HIGH_DAH);
		      sreg_shift = 1'b1;
		      sreg_clear = 1'b0;
		      ticks_clear = 1'b1;
		      bitcount_inc = 1'b1;
		      fsm_d = BITGAP;
		  end else begin
		      fsm_d = ERROR;
		  end
	      end
	    BITGAP:
	      // Enforce short pause between bits
	      begin
		  if (din) begin
		      fsm_d = ERROR;
		  end else if (ticks >= TICKS_BITGAP) begin
		      ticks_clear = 1'b1;
		      fsm_d = WAIT_NEXTBIT;
		  end else begin
		      fsm_d = BITGAP;
		  end
	      end
	    WAIT_NEXTBIT:
	      // Wait for intra-word rising edge
	      begin
		  if (bitcount > BITCOUNT_MAX) begin
		      fsm_d = ERROR;
		  end else if (din) begin
		      ticks_clear = 1'b1;
		      fsm_d = HIGH_BLIP;
		  end else if (ticks >= TICKS_NEXTBIT) begin
		      fsm_d = REALIGN;
		      bitcountnp_ena = 1'b1;
		  end else begin
		      fsm_d = WAIT_NEXTBIT;
		  end
	      end
	    REALIGN:
	      // Keep shifting zeros into sreg until bitcount == MAX,
	      // so that sreg contents are left-aligned for common
	      // handling of commands of differing lengths.  The need
	      // for this is a consequence of having chosen to send
	      // the command / chipid / address bits first.  Time
	      // spent here should be of no concern for such a slow
	      // communication protocol.
	      begin
		  if (bitcount >= BITCOUNT_MAX) begin
		      fsm_d = EOT;
		  end else begin
		      bitcount_inc = 1'b1;
		      sreg_in = 1'b0;
		      sreg_shift = 1'b1;
		      fsm_d = REALIGN;
		  end
	      end
	    EOT:
	      // Complete message received into sreg, left-aligned.
	      begin
		  $display("EOT: sreg=%x, bitcount=%d/%d", 
			   sreg, bitcountnp, bitcount);
		  if (sreg_cmd==CMD_SETID && 
		      bitcountnp==WRCMD_NBITS &&
		      setid_match && crcok)
		  begin
		      seqnum_inc = 1'b1;
		      fsm_d = SETIDCMD;
		  end else if (sreg_cmd==CMD_WR &&
			       bitcountnp==WRCMD_NBITS &&
			       id_match && crcok)
		  begin
		      seqnum_inc = 1'b1;
		      fsm_d = WRCMD;
		  end else if (sreg_cmd==CMD_RD &&
			       bitcountnp==RDCMD_NBITS &&
			       id_match) begin
		      seqnum_inc = 1'b1;
		      fsm_d = RDCMD;
		  end else if (sreg_cmd==CMD_RDNEXT &&
			       bitcountnp==RDNEXTCMD_NBITS &&
			       id_match) begin
		      seqnum_inc = 1'b1;
		      fsm_d = RDNEXTCMD;
		  end else begin
		      fsm_d = ERROR;
		  end
	      end
	    WRCMD:
	      // Process a WRITE command.  The state code for WRCMD
	      // has a Hamming distance of at least 2 from any other
	      // valid state code.
	      begin
		  if (fsm_prev==EOT) begin
		      $display("WRCMD: addr=%02x data=%08x crc=%02x", 
			       sreg_addr, sreg_data, sreg_crc);
		      wstrobe_d = 1'b1;
		      srout_bitcount_d = SHORT_REPLY_NBITS;
		      srout_load = 1'b1;
		      fsm_d = REPLY;
		  end else begin
		      // In the unlikely event that a double bit flip
		      // gets us into the WRCMD state, branch to the
		      // ERROR state instead of executing a spurious
		      // write cycle.
		      fsm_d = ERROR;
		  end
	      end
	    SETIDCMD:
	      // Process a SETID command.
	      begin
		  $display("SETID: seqnum=%x commid=%x", seqnum, commid_d);
		  // Insist that all unused bits of request be 1.
		  if (sreg[55:48]==8'b11011111 &&
		      sreg[47:45]==3'b111 &&
		      sreg[39:36]==4'b1111 &&
		      sreg[15:13]==3'b111)
		  begin
		      do_set_commid = 1'b1;
		      fsm_d = SETIDCMD1;
		  end else begin
		      fsm_d = ERROR;
		  end
	      end
	    SETIDCMD1:
	      begin
		  srout_bitcount_d = SHORT_REPLY_NBITS;
		  srout_load = 1'b1;
		  fsm_d = REPLY;
	      end
	    RDNEXTCMD:
	      begin
		  fsm_d = RDCMD1;
		  rdaddr_d = rdaddr + 8'h01;
		  rdaddr_ena = 1'b1;
	      end
	    RDCMD:
	      // Process a READ command.
	      begin
		  $display("RDCMD: addr=%02x", sreg_addr);
		  fsm_d = RDCMD1;
		  rdaddr_d = sreg_addr;
		  rdaddr_ena = 1'b1;
	      end
	    RDCMD1:
	      begin
		  // comment
		  fsm_d = RDCMD2;
	      end
	    RDCMD2:
	      begin
		  // comment
		  rstrobe_d = 1'b1;
		  ticks_clear = 1'b1;
		  fsm_d = RDCMD3;
	      end
	    RDCMD3:
	      begin
		  // comment
		  rshift_d = 1'b1;
		  ticks_clear = 1'b1;
		  fsm_d = RDCMD4;
	      end
	    RDCMD4:
	      begin
		  // comment
		  rshift_d = 1'b1;
		  if (ticks < TICKS_RBITS) begin
		      fsm_d = RDCMD4;
		  end else begin
		      fsm_d = RDCMD5;
		  end
	      end
	    RDCMD5:
	      begin
		  // comment
		  fsm_d = RDCMD9;
	      end
	    RDCMD9:
	      begin
		  // comment
		  $display("RDCMD9: a=%02x d=%08x", sreg_addr, srin);
		  srout_bitcount_d = LONG_REPLY_NBITS;
		  srout_load = 1'b1;
		  fsm_d = REPLY;
	      end
	    REPLY:
	      // Respond to the EOS card.  Insert a gap so that
	      // serialout is enabled for about 200ns before starting
	      // to transmit a reply.
	      begin
		  douten = 1'b1;
		  ticks_clear = 1'b1;
		  fsm_d = SEND_BITGAP;
	      end
	    REPLYLOOP:
	      // Loop from here to send each subsequent bit to EOS.
	      begin
		  srout_shift = 1'b1;
		  ticks_clear = 1'b1;
		  addr_clear = 1'b1;
		  douten = 1'b1;
		  if (srout_bitcount==6'b0) begin
		      fsm_d = START;
		  end else if (srout[47]) begin
		      fsm_d = SEND_DAH;
		  end else begin
		      fsm_d = SEND_DIT;
		  end
	      end
	    SEND_DIT:
	      // Transmit a short ("DIT") pulse to EOS card
	      begin
		  douten = 1'b1;
		  dout = 1'b1;
		  if (ticks < TICKS_TXDIT) begin
		      fsm_d = SEND_DIT;
		  end else begin
		      ticks_clear = 1'b1;
		      fsm_d = SEND_BITGAP;
		  end
	      end
	    SEND_DAH:
	      // Transmit a long ("DAH") pulse to EOS card
	      begin
		  douten = 1'b1;
		  dout = 1'b1;
		  if (ticks < TICKS_TXDAH) begin
		      fsm_d = SEND_DAH;
		  end else begin
		      ticks_clear = 1'b1;
		      fsm_d = SEND_BITGAP;
		  end
	      end
	    SEND_BITGAP:
	      // Transmit inter-bit gap within reply to EOS
	      begin
		  douten = 1'b1;
		  dout = 1'b0;
		  if (ticks < TICKS_TXGAP) begin
		      fsm_d = SEND_BITGAP;
		  end else begin
		      fsm_d = REPLYLOOP;
		  end
	      end
	    ERROR:
	      // Error condition detected; state from which we branched
	      // here is recorded (for one tick) in 'fsm_prev'.  We may
	      // eventually maintain some registers counting errors or
	      // recording which state recently detected an error.
	      begin
		  $display("ERROR: fsm_prev=%d", fsm_prev);
		  addr_clear = 1'b1;
		  fsm_d = START;
	      end
	    default:
	      begin
		  $display("INVALID STATE: fsm=%d fsm_prev=%d", 
			   fsm, fsm_prev);
		  addr_clear = 1'b1;
		  fsm_d = START;
	      end
	endcase
    end
    // Multiplexer to select [addr] bit of rdata for register reads.
    // Each register in the regfile sends a serial bit stream.  The
    // register having address 'addr' drives rdata[addr].
    wire [7:0]   a = addr_ff; 
    wire [255:0] d = rdata; 
    assign rdat = d[a];
endmodule // endeavour

`default_nettype wire

