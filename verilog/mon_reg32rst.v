`default_nettype none
`timescale 1ns/1ps

  /*
   * Resets the chip if 0xCCCC9999 is written to this register
   */
  
module mon_reg32rst #(
		      parameter REG_ADDR = 8'b0,
		      parameter MAGIC = 32'hCCCC9999
		      ) (
			 output wire chip_rstb,
			 
			 input wire bclk,
			 input wire [31:0] dataIn,
			 input wire [7:0] addrIn,
			 input wire latchIn,
			 input wire rstb
			 ); 


   wire chip;
   
   
   assign chip = (latchIn == 1'b1) && (addrIn == REG_ADDR) && 
		 (dataIn == MAGIC);
   

   reg  SRa, SRb, SRc, SRd, SRe;   // Negative logic!
   
   always @(negedge bclk, negedge rstb)
     if ( rstb == 1'b0 )
       SRa <= 1'b1;
     else if ( chip == 1'b1 )
       SRa <= 1'b0;
     else
       SRa <= 1'b1;

   always @(negedge bclk, negedge rstb)
     if ( rstb == 1'b0 )
       SRb <= 1'b1;
     else if ( chip == 1'b1 )
       SRb <= 1'b0;
     else
       SRb <= 1'b1;

   always @(negedge bclk, negedge rstb)
     if ( rstb == 1'b0 )
       SRc <= 1'b1;
     else if ( chip == 1'b1 )
       SRc <= 1'b0;
     else
       SRc <= 1'b1;

   always @(negedge bclk, negedge rstb)
     if ( rstb == 1'b0 )
       SRd <= 1'b1;
     else if ( chip == 1'b1 )
       SRd <= 1'b0;
     else
       SRd <= 1'b1;

   always @(negedge bclk, negedge rstb)
     if ( rstb == 1'b0 )
       SRe <= 1'b1;
     else if ( chip == 1'b1 )
       SRe <= 1'b0;
     else
       SRe <= 1'b1;
	
	

   assign chip_rstb = SRa | SRb | SRc | SRd | SRe;  // Require all LOW
   
       
   
endmodule // mon_reg32rst

