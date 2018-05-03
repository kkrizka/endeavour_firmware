`default_nettype none
`timescale 1ns/1ps
 
/*
 * N-bit D-type flip-flop with triplication
 *
 * modified 2017-10-26 by WJA from PTK's mon_reg32t.v
 */

module dffe_nbit_t #( parameter 
		      W=6,     // register width
		      PU=6'b0  // "power-up" (reset) value
		      ) 
    (
     input  wire         rstb,   // asynchronous reset*
     input  wire         clk,    // clock
     input  wire         ena,    // enable (as in standard DFFE)
     input  wire [W-1:0] d,      // input data
     output wire [W-1:0] q,      // flip-flop output value (majority logic)
     output wire         serOut  // soft error
     ); 


    reg [W-1:0] SRa;  //state-reg A copy
    reg [W-1:0] SRb;  //state-reg B copy
    reg [W-1:0] SRc;  //state-reg C copy

    // majority logic
    assign q = (SRa & SRb) | (SRa & SRc) | (SRb & SRc);
   
    // soft-error detect
    assign serOut = |((SRa ^ SRb) | (SRa ^ SRc) | (SRb ^ SRc));

   /*
    * Register state
    */
    always @(posedge clk, negedge rstb) begin
	if (!rstb) begin
	    SRa <= PU;
	    SRb <= PU;
	    SRc <= PU;
	end else if (ena) begin
            SRa <= d;
            SRb <= d;
            SRc <= d;
	end else begin
	    SRa <= q;  // refresh majority-logic value
	    SRb <= q;  // refresh majority-logic value
	    SRc <= q;  // refresh majority-logic value
	end
    end
endmodule // dffe_nbit_t
