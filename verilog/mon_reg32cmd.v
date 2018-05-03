// 8-bit serial loading register with triplication

module mon_reg32cmd #(parameter REG_ADDR = 8'b0 ) (
					  output wire [31:0] flags_rstb,
					  output wire shiftOut,
						  
					  input wire bclk,
					  input wire [31:0] dataIn,
					  input wire [7:0] addrIn,
					  input wire latchIn,
					  input wire rstb
					  ); 


   assign shiftOut = 1'b0;

   wire [5:0] flags;
      
   assign flags[0] = (latchIn == 1'b1) && (addrIn == REG_ADDR) && 
		     (dataIn & 32'h01);
   assign flags[1] = (latchIn == 1'b1) && (addrIn == REG_ADDR) && 
		     (dataIn & 32'h02);
   assign flags[2] = (latchIn == 1'b1) && (addrIn == REG_ADDR) && 
		     (dataIn & 32'h04);
   assign flags[3] = (latchIn == 1'b1) && (addrIn == REG_ADDR) &&
 		     (dataIn & 32'h08);
   assign flags[4] = (latchIn == 1'b1) && (addrIn == REG_ADDR) && 
		     (dataIn & 32'h10);
   assign flags[5] = (latchIn == 1'b1) && (addrIn == REG_ADDR) && 
		     (dataIn & 32'h20);

   assign flags_rstb[31:6] = 26'b0;
   

   reg [5:0]  flags_b;
   
   genvar     i;
   
   generate
      for (i=0; i<6; i=i+1 ) begin
	 always @( posedge bclk, negedge rstb )
	   if ( rstb == 1'b0 )
	     flags_b[i] <= 1'b0;
	   else
	     begin
		if ( flags[i] == 1'b1 )
		  flags_b[i] <= 1'b0;
		else
		  flags_b[i] <= 1'b1;
	     end
      end
   endgenerate


   generate
      for (i=0; i<6; i=i+1 )
	 assign flags_rstb[i] = flags_b[i];
   endgenerate
   
endmodule // mon_reg32cmd
