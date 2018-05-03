`default_nettype none
`timescale 1ns/1ps
 
// 32-bit serial loading register with triplication

module mon_reg32t #(parameter RESET_VALUE = 32'b0,
		             REG_ADDR = 8'b0 ) (
					  output wire [31:0] dataOut,
					  output wire serOut,  // Soft error
					  output wire shiftOut,
						
					  input wire bclk,
					  input wire [31:0] dataIn,
					  input wire [7:0] addrIn,
					  input wire latchIn,
					  input wire latchOut,
					  input wire shiftEn,
					  input wire rstb
					  ); 


   reg [31:0] SRa;  //state-reg A copy
   reg [31:0] SRb;  //state-reg B copy
   reg [31:0] SRc;  //state-reg C copy

   reg [31:0] shifter;  // Output shift register
   
   assign shiftOut = shifter[31];
   
   //majority logic
   genvar i;
   generate
      for ( i=0; i<32; i=i+1 )
	assign dataOut[i] = (SRa[i] & SRb[i]) | 
			    (SRa[i] & SRc[i]) | 
			    (SRb[i] & SRc[i]);
   endgenerate
   

   //soft-error detect
   assign serOut = (SRa[0] ^ SRb[0])  | (SRa[0] ^ SRc[0]) | (SRb[0] ^ SRc[0])
                 | (SRa[1] ^ SRb[1])  | (SRa[1] ^ SRc[1]) | (SRb[1] ^ SRc[1])
                 | (SRa[2] ^ SRb[2])  | (SRa[2] ^ SRc[2]) | (SRb[2] ^ SRc[2])
	         | (SRa[3] ^ SRb[3])  | (SRa[3] ^ SRc[3]) | (SRb[3] ^ SRc[3])
	         | (SRa[4] ^ SRb[4])  | (SRa[4] ^ SRc[4]) | (SRb[4] ^ SRc[4])
		 | (SRa[5] ^ SRb[5])  | (SRa[5] ^ SRc[5]) | (SRb[5] ^ SRc[5])
		 | (SRa[6] ^ SRb[6])  | (SRa[6] ^ SRc[6]) | (SRb[6] ^ SRc[6])
		 | (SRa[7] ^ SRb[7])  | (SRa[7] ^ SRc[7]) | (SRb[7] ^ SRc[7])
		 | (SRa[8] ^ SRb[8])  | (SRa[8] ^ SRc[8]) | (SRb[8] ^ SRc[8])
		 | (SRa[9] ^ SRb[9])  | (SRa[9] ^ SRc[9]) | (SRb[9] ^ SRc[9])
		 | (SRa[10] ^ SRb[10])  | (SRa[10] ^ SRc[10]) | (SRb[10] ^ SRc[10])
		 | (SRa[11] ^ SRb[11])  | (SRa[11] ^ SRc[11]) | (SRb[11] ^ SRc[11])
		 | (SRa[12] ^ SRb[12])  | (SRa[12] ^ SRc[12]) | (SRb[12] ^ SRc[12])
		 | (SRa[13] ^ SRb[13])  | (SRa[13] ^ SRc[13]) | (SRb[13] ^ SRc[13])
		 | (SRa[14] ^ SRb[14])  | (SRa[14] ^ SRc[14]) | (SRb[14] ^ SRc[14])
		 | (SRa[15] ^ SRb[15])  | (SRa[15] ^ SRc[15]) | (SRb[15] ^ SRc[15])
		 | (SRa[16] ^ SRb[16])  | (SRa[16] ^ SRc[16]) | (SRb[16] ^ SRc[16])
		 | (SRa[17] ^ SRb[17])  | (SRa[17] ^ SRc[17]) | (SRb[17] ^ SRc[17])
		 | (SRa[18] ^ SRb[18])  | (SRa[18] ^ SRc[18]) | (SRb[18] ^ SRc[18])
		 | (SRa[19] ^ SRb[19])  | (SRa[19] ^ SRc[18]) | (SRb[19] ^ SRc[19])
		 | (SRa[20] ^ SRb[20])  | (SRa[20] ^ SRc[20]) | (SRb[20] ^ SRc[20])
		 | (SRa[21] ^ SRb[21])  | (SRa[21] ^ SRc[21]) | (SRb[21] ^ SRc[21])
		 | (SRa[22] ^ SRb[22])  | (SRa[22] ^ SRc[22]) | (SRb[22] ^ SRc[22])
		 | (SRa[23] ^ SRb[23])  | (SRa[23] ^ SRc[23]) | (SRb[23] ^ SRc[23])
		 | (SRa[24] ^ SRb[24])  | (SRa[24] ^ SRc[24]) | (SRb[24] ^ SRc[24])
		 | (SRa[25] ^ SRb[25])  | (SRa[25] ^ SRc[25]) | (SRb[25] ^ SRc[25])
		 | (SRa[26] ^ SRb[26])  | (SRa[26] ^ SRc[26]) | (SRb[26] ^ SRc[26])
		 | (SRa[27] ^ SRb[27])  | (SRa[27] ^ SRc[27]) | (SRb[27] ^ SRc[27])
		 | (SRa[28] ^ SRb[28])  | (SRa[28] ^ SRc[28]) | (SRb[28] ^ SRc[28])
		 | (SRa[29] ^ SRb[29])  | (SRa[29] ^ SRc[28]) | (SRb[29] ^ SRc[29])
		 | (SRa[30] ^ SRb[30])  | (SRa[30] ^ SRc[30]) | (SRb[30] ^ SRc[30])
	         | (SRa[31] ^ SRb[31])  | (SRa[31] ^ SRc[31]) | (SRb[31] ^ SRc[31]);
   
   

   /*
    * Output shift register
    */
   always @( posedge bclk, negedge rstb )
     if ( rstb == 1'b0 )
       shifter <= 32'h0;
     else if ( (latchOut == 1'b1) && (addrIn == REG_ADDR) )
       shifter <= dataOut;
     else if ( shiftEn == 1'b1 )
       shifter <= {shifter[30:0], 1'b0};
   
   /*
    * Register state
    */
   always @(posedge bclk, negedge rstb )
     if ( rstb == 1'b0 ) begin
	SRa <= RESET_VALUE;
	SRb <= RESET_VALUE;
	SRc <= RESET_VALUE;
     end
     else
       if ( (latchIn == 1'b1) && (addrIn == REG_ADDR) ) begin
          SRa <= dataIn;
          SRb <= dataIn;
          SRc <= dataIn;
       end
       else begin
	  SRa <=  dataOut;  // refresh majority-logic'ed value
	  SRb <=  dataOut;  // refresh majority-logic'ed value
	  SRc <=  dataOut;  // refresh majority-logic'ed value
       end
   
	  
endmodule // mon_reg32t
