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


module tf530_ram(

		input	CLKCPU,
		input	RESET,

        input   A0,
        input   A1,
		input	[8:2]  AB,
		input	[23:12] A,
		inout	[7:0] D,
		input   [1:0] SIZ,
		
		input   IDEINT,
        input   IDEWAIT,
		output  INT2,
        
		input 	AS20,
		input	RW20,
		input 	DS20,
		
		// cache and burst control
		input 	CBREQ,
		output  CBACK,
		output  CIIN,
		output 	STERM,	
		// 32 bit internal cycle.
		// i.e. assert OVR
		output  INTCYCLE,
		
		// spare / debug
		output 	SPARE,
		
		// ram chip control 
		output	[3:0] RAMCS,
		output 	RAMOE
		
       );

reg AS20_D = 1'b1;
reg DS20_D = 1'b1;
reg STERM_D = 1'b1;

wire BUS_CYCLE = (~DS20_D | DS20);

reg configured = 'b0;
reg shutup = 'b0;
reg [7:0] data_out = 'h00;
reg [7:0] base = 'h40;

wire GAYLE_INT2;
wire [7:0] GAYLE_DOUT;

//
wire IDE_ACCESS = (A[23:15] != {8'hDA, 1'b0})  | DS20 | AS20;

// $DE0000 or $DA8000 (Ignores A18)
wire GAYLE_REGS = (A[23:15] != {8'hDA, 1'b1});
wire GAYLE_ID= (A[23:15] != {8'hDE, 1'b0});

wire GAYLE_ACCESS = (GAYLE_ID & GAYLE_REGS) | DS20 | AS20;
wire GAYLE_READ = (GAYLE_ACCESS | ~RW20);

gayle GAYLE(
    .CLKCPU ( CLKCPU        ),
    .RESET  ( RESET         ),
    .CS     ( GAYLE_ACCESS  ),
    .DS     ( DS20          ),
    .RW     ( RW20          ),
    .A18    ( A[18]         ),
    .A      ( {1,b0, A[13:12]}),
    .IDE_INT( IDEINT        ),
    .INT2   ( GAYLE_INT2    ),
    .DIN    ( D		       ),
    .DOUT   ( GAYLE_DOUT    )
);


// 0xE80000
wire Z2_ACCESS = ({A[23:16]} != {8'hE8}) | AS20 | DS20 | shutup | configured;
wire Z2_READ =  (Z2_ACCESS | ~RW20);
wire Z2_WRITE = (Z2_ACCESS | RW20);

wire RAM_ACCESS = ({A[23:21]} != {base[7:5]}) | AS20 | DS20 | ~configured;
wire [6:0] zaddr = {AB[7:2],A1};

always @(posedge CLKCPU) begin

    AS20_D  <= AS20;
    DS20_D  <= DS20;
    STERM_D <=  INTCYCLE | ~STERM_D;

    if (RESET == 1'b0) begin 
        configured <= 1'b0;
        shutup <= 1'b0;
        STERM_D <= 1'b1;
    end else begin 
    
        if (Z2_WRITE === 1'b0) begin 
            case (zaddr)         
                'h24: begin 
                    base[7:4] <= D[7:4];
                    configured <= 1'b1;
                end 
                'h25: base[3:0] <= D[7:4];
                'h26: shutup <= 1'b1;
           endcase
        end
    
        data_out <= 8'hff;
        // the Gayle/Gary ID shift register.
        if (Z2_READ == 1'b0) begin  
            // zorro config ROM
            case (zaddr)  
                'h00: data_out[7:4] <= 4'he;
                'h01: data_out[7:4] <= 4'h6;
                'h02: data_out[7:4] <= 4'h7;
                'h03: data_out[7:4] <= 4'h7;
                'h04: data_out[7:4] <= 4'h7;
                'h08: data_out[7:4] <= 4'he;
                'h09: data_out[7:4] <= 4'hc;
                'h0a: data_out[7:4] <= 4'h2;
                'h0b: data_out[7:4] <= 4'h7;
                'h10: data_out[7:4] <= 4'hc;
                'h12: data_out[7:4] <= 4'hc;
                'h13: data_out[7:4] <= 4'h6;
            endcase
        end else if (GAYLE_READ == 1'b0) begin 
            data_out <= GAYLE_DOUT;
        end 
        
    end 
    
end

wire RAMCS3n = A1 | A0; // 
wire RAMCS2n = (~SIZ[1] & SIZ[0] & ~A0) | A1;
wire RAMCS1n = (SIZ[1] & ~SIZ[0] & ~A1 & ~A0) | (~SIZ[1] & SIZ[0] & ~A1) |(A1 & A0);
wire RAMCS0n = (~SIZ[1] & SIZ[0] & ~A1 ) | (~SIZ[1] & SIZ[0] & ~A0 ) | (SIZ[1] & ~A1 & ~A0 ) | (SIZ[1] & ~SIZ[0] & ~A1 );

// disable all the RAM.	   
assign RAMOE = RAM_ACCESS;
assign RAMCS = {RAMCS3n | RAM_ACCESS, RAMCS2n | RAM_ACCESS, RAMCS1n | RAM_ACCESS , RAMCS0n | RAM_ACCESS};
assign INTCYCLE = RAM_ACCESS & GAYLE_ACCESS;

// disable all burst control.
assign STERM = STERM_D;
assign CBACK = 1'b1; //STERM_D | CBREQ;

// cache the sram.
assign CIIN = 1'b0; //~RAM_ACCESS;

assign INT2 = GAYLE_INT2 ? 1'b0 : 1'bz;
assign D = Z2_READ & GAYLE_READ ? 8'bzzzzzzzz : data_out;
       
endmodule
