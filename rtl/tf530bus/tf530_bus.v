`timescale 1ns / 1ps
/*
	Copyright (C) 2016-2017, Stephen J. Leary
	All rights reserved.
	
	This file is part of  TF530 (Terrible Fire 030 Accelerator).

    TF530 is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    TF530 is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with TF530. If not, see <http://www.gnu.org/licenses/>.
*/

module tf530_bus(

		// clocks
		input 	 CLKCPU,
		input 	 CLK7M,
        
        // internal signals
        
        input     INTSIG,

		// address bus / spec
		input [2:0] 	 FC,
		input [1:0] 	 SIZ,
		input         A0,   
		input [23:12] A,
		
		// 68030 ASync bus
		input 	 AS20,
		input 	 DS20,
		input 	 RW20,
		output 	 [1:0] DSACK,
		
		// exception handling.
		
		output 	 AVEC,
		output   BERR,
		
		// FPU signals.
		output	 CPCS,
		input    CPSENSE,
        
        // IDE signals
        //input        INT2,
        input        IDEWAIT,
        output [1:0] IDECS, // IDE Chip Selects
        output       IOR, // IDE Read Strobe
        output       IOW, // IDE Write Strobe
        output       OVR, // Disable Gary Decode. 

		// 68000 ASync Bus
		output 	 AS,
		output 	 LDS,
		output 	 UDS,
		output 	 RW00,
		input 	 DTACK,

		// bus arbitration		
		input 	 BG20,
		output 	 BG,
		input 	 BGACK,

		// synchronous bus
		output 	 VMA,
		input 	 VPA,
		output reg E

       );

wire DS20DLY;
wire AS20DLY;

reg SYSDSACK1 = 1'b1;
reg RW20DLY = 1'b1;
reg CLK7MB2 = 1'b1;
reg BGACKD1 = 1'b1;
reg BGACKD2 = 1'b1;
reg DTQUAL = 1'b1;

reg [3:0] Q = 'hF;

reg VMA_SYNC = 1'b1;

initial begin 

	E = 'b0;
	
end

wire DTRIG;

wire CPUSPACE = &FC;


wire FPUOP = CPUSPACE & ({A[19:16]} === {4'b0010});
wire BKPT = CPUSPACE & ({A[19:16]} === {4'b0000});
wire IACK = CPUSPACE & ({A[19:16]} === {4'b1111});
wire DTACKPRELIM = CLK7M | CLK7MB2;
wire GAYLE_IDE = ({A[23:15]} != {8'hDA,1'b0}) | AS20 | FPUOP;

assign CPCS = ~FPUOP | AS20;

FDCP #(.INIT(1'b1)) 
	AS20DLY_FF (
		.Q(AS20DLY), // Data output
		.C(CLK7M), // Clock input
		.CLR(1'b0), // Asynchronous clear input
		.D(AS20), // Data input
		.PRE(AS20 | FPUOP | ~INTSIG) // Asynchronous set input
);


FDCP #(.INIT(1'b1)) 
	ASDLY_FF (
		.Q(ASDLY), // Data output
		.C(CLK7M), // Clock input
		.CLR(1'b0), // Asynchronous clear input
		.D(AS), // Data input
		.PRE(AS20) // Asynchronous set input
);

FDCP #(.INIT(1'b1)) 
	DS20DLY_FF (
		.Q(DS20DLY), // Data output
		.C(CLK7M), // Clock input
		.CLR(1'b0), // Asynchronous clear input
		.D(DS20), // Data input
		.PRE(DS20 | FPUOP | ~INTSIG) // Asynchronous set input
);

FDCP #(.INIT(1'b1)) 
	DTTRIG1_FF (
		.Q(DSACK1INT), // Data output
		.C(~DTRIG), // Clock input
		.CLR(1'b0), // Asynchronous clear input
		.D(AS | ~INTSIG), // Data input
		.PRE(AS) // Asynchronous set input
);

// hold off DTACK until the IDE device is ready.
wire DTACKMOO = AS | ASDLY | DTACK | ~IDEWAIT;
FDCP #(.INIT(1'b1)) 
	DTTACK1_FF (
		.Q(DTACK_INT1), // Data output
		.C(CLKCPU), // Clock input
		.CLR(1'b0), // Asynchronous clear input
		.D(DTACKMOO), // Data input
		.PRE(DTACKMOO | ~INTSIG) // Asynchronous set input
);

FDCP #(.INIT(1'b1)) 
	DTTACK2_FF (
		.Q(DTACK_INT2), // Data output
		.C(CLKCPU), // Clock input
		.CLR(1'b0), // Asynchronous clear input
		.D(DTACK_INT1), // Data input
		.PRE(DTACK_INT1) // Asynchronous set input
);

FDCP #(.INIT(1'b1)) 
	DTTACK3_FF (
		.Q(DTACK_INT3), // Data output
		.C(CLKCPU), // Clock input
		.CLR(1'b0), // Asynchronous clear input
		.D(DTACK_INT2), // Data input
		.PRE(DTACK_INT2) // Asynchronous set input
);

FDCP #(.INIT(1'b1)) 
	DTTACK4_FF (
		.Q(DTACK_INT4), // Data output
		.C(CLKCPU), // Clock input
		.CLR(1'b0), // Asynchronous clear input
		.D(DTACK_INT3), // Data input
		.PRE(DTACK_INT3) // Asynchronous set input
);



reg DTRIG_SYNC = 1'b1;
reg DTRIG_SYNC_D = 1'b1;
reg DTRIG_SYNC_D2 = 1'b1;
reg DTRIG_SYNC_D3 = 1'b1;
reg DTRIG_SYNC_D4 = 1'b1;
reg DTRIG_SYNC_D5 = 1'b1;

always @(posedge CLKCPU) begin 

	SYSDSACK1 <= DSACK1INT | FPUOP ;
    DTRIG_SYNC <= ~Q[3] | VMA_SYNC | ~DTRIG_SYNC | ~DTRIG_SYNC_D |  ~DTRIG_SYNC_D2 | ~DTRIG_SYNC_D3 | ~DTRIG_SYNC_D4 | ~DTRIG_SYNC_D5;
    DTRIG_SYNC_D <= DTRIG_SYNC;
    DTRIG_SYNC_D2 <= DTRIG_SYNC_D;
    DTRIG_SYNC_D3 <= DTRIG_SYNC_D2;
    DTRIG_SYNC_D4 <= DTRIG_SYNC_D3;
    DTRIG_SYNC_D5 <= DTRIG_SYNC_D4;
    
end

always @(posedge CLK7M) begin
     
	DTQUAL 	<= AS20 | FPUOP;
	RW20DLY <= RW20;
     
    BGACKD1 <= BGACK;
    BGACKD2 <= BGACKD1;
    
    // 7Mhz Clock divided by 2
    CLK7MB2 <= ~CLK7MB2;
    
   if (Q == 'd9) begin

      VMA_SYNC <= 1'b1;
      Q <= 'd0;

   end else begin

      Q <= Q + 'd1;

      if (Q == 'd4) begin
            E <= 'b1;       
      end

      if (Q == 'd8) begin
            E <= 'b0;
      end

      if (Q == 'd2) begin

         VMA_SYNC <=  (VPA | CPUSPACE);
		 
      end 
      
   end
 
end


   
//wire HIGHZ = BG20 | //(BG20 & (AS20DLY | AS20)) | CPUSPACE;
wire DSHOLD = {ASDLY,AS, RW00} == {1'b1,1'b0,1'b0};
wire IOR_INT = ~RW00 | GAYLE_IDE | DSHOLD;
wire IOW_INT = RW00 | GAYLE_IDE | DSHOLD; 

FDCP #(.INIT(1'b1)) 
	IOR_FF (
		.Q(IOR), // Data output
		.C(~CLK7M), // Clock input
		.CLR(1'b0), // Asynchronous clear input
		.D(IOR_INT), // Data input
		.PRE(AS20) // Asynchronous set input
);

FDCP #(.INIT(1'b1)) 
	IOW_FF (
		.Q(IOW), // Data output
		.C(~CLK7M), // Clock input
		.CLR(1'b0), // Asynchronous clear input
		.D(IOW_INT), // Data input
		.PRE(AS20) // Asynchronous set input
);

wire HIGHZ = ~BGACK;
wire AS_INT = AS20DLY | AS20;
wire UDS_INT = DS20 | AS | DSHOLD | A0;
wire LDS_INT = DS20 | AS | DSHOLD | ({A0, SIZ[1:0]} == 3'b001);  
wire VMA_INT = VMA_SYNC;  
 
assign RW00 = HIGHZ ? 1'bz : AS | RW20;      
assign AS =   HIGHZ ? 1'bz : AS_INT;   
assign UDS =  HIGHZ ? 1'bz : UDS_INT;
assign LDS =  HIGHZ ? 1'bz : LDS_INT;
assign VMA =  HIGHZ ? 1'bz : VMA_INT;

assign DTRIG = (DTACK_INT3| DTQUAL) & DTRIG_SYNC_D5;
assign DSACK[1] = (AS20DLY |  AS20 | SYSDSACK1);
assign DSACK[0] = 1'b1; // | ~INTSIG | DSACK[1];

assign BG = AS ? BG20 : 1'bz;
assign BERR =  CPCS | ~CPSENSE;
assign AVEC = ~IACK | VPA;

assign IDECS = A[12] ? {GAYLE_IDE, 1'b1} : {1'b1, GAYLE_IDE}; 
assign OVR =  INTSIG;
   
endmodule
