`default_nettype none
`timescale 1ns/1ps
 
// 32-bit parallel loading read-only register

module mon_reg32ro #(parameter REG_ADDR = 8'b0 ) (
					  output wire shiftOut,
						
					  input wire bclk,
					  input wire [31:0] dataIn,
					  input wire [7:0] addrIn,
					  input wire latchOut,
					  input wire shiftEn,
					  input wire rstb
					  ); 


   reg [31:0] shifter;  // Output shift register
   
   assign shiftOut = shifter[31];
   

   /*
    * Output shift register
    */
   always @( posedge bclk, negedge rstb )
     if ( rstb == 1'b0 )
       shifter <= 32'h0;
     else if ( (latchOut == 1'b1) && (addrIn == REG_ADDR) )
       shifter <= dataIn;
     else if ( shiftEn == 1'b1 )
       shifter <= {shifter[30:0], 1'b0};
   
   
endmodule // mon_reg32ro



