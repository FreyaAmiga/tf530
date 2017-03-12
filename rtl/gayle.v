`timescale 1ns / 1ps
  
module gayle(
	     input 	        CLKCPU,
	     input 	        RESET, 
	     input 	        CS,
         input          DS, 
	     input 	        RW,
	     input 	        IDE_INT,
	     output 	    INT2,
	     input	        A18,
	     input [2:0]    A,
	     input [7:0]    DIN,
         output reg [7:0] DOUT
);
   
parameter GAYLE_ID_VAL = 4'hd;

reg [3:0] gayleid;
reg 	  intchg;
reg 	  intena;
reg 	  intlast;
reg       ds_d;
   
// $DE1000
localparam GAYLE_ID_RD = {1'b1,3'h1,1'b1};
localparam GAYLE_ID_WR = {1'b1,3'h1,1'b0};

// $DA8000
localparam GAYLE_STAT_RD = {4'h0,1'b1};
localparam GAYLE_STAT_WR = {4'h0,4'h0,1'b0};

// $DA9000
localparam GAYLE_INTCHG_RD = {4'h1,1'b1};
localparam GAYLE_INTCHG_WR = {4'h1,1'b0};

// $DAA000
localparam GAYLE_INTENA_RD = {4'h2,1'b1};
localparam GAYLE_INTENA_WR = {4'h2,1'b0};

always @(posedge CLKCPU) begin

   intlast <= IDE_INT;
   ds_d    <= DS;
  
   if (RESET == 1'b0) begin 
      // resetting to low ensures that the next cycle
      // after reset is disasserted is not a bus cycle. 
      intena <= 1'b0;
      intchg <= 1'b0;
      gayleid <= GAYLE_ID_VAL;
   end else begin 
   
       if (IDE_INT != intlast) begin
          intchg <= 1'b1;
       end
       
       if ((CS | DS | ~ds_d) == 1'b0) begin
          case ({A18,A,RW})
                GAYLE_STAT_RD: DOUT <= {IDE_INT, 7'd0};
                GAYLE_INTCHG_RD: DOUT <= {intchg, 7'd0};
                GAYLE_INTCHG_WR: intchg <= DIN[7] & intchg;
                GAYLE_ID_RD: begin 
                   DOUT <=  {gayleid[3], 7'd0};
                   gayleid <= {gayleid[2:0],1'b0};
                end 
                GAYLE_ID_WR: gayleid <= GAYLE_ID_VAL;
                GAYLE_INTENA_RD: DOUT <= {intena, 7'd0};
                GAYLE_INTENA_WR: intena <= DIN[7];
                default: DOUT <= {gayleid[3],7'd3};
          endcase       
       end   
    end
end 
  
assign INT2 = intchg & intena;
   
endmodule
