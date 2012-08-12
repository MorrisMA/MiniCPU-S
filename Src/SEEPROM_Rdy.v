`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Company:         M. A. Morris & Associates
// Engineer:        Michael A. Morris 
// 
// Create Date:     15:25:20 08/05/2012 
// Design Name:     Serial Electrically Erasable Programmable Read-Only Memory
// Module Name:     SEEPROM_Rdy.v
// Project Name:    Serial Electrically Erasable Programmable Read-Only Memory 
// Target Devices:  Synthesizable RTL for SEEPROM Testing/Emulation
// Tool versions:   ISE10.1 SP3
// 
// Description:
//
//  This module implements a logic function intended to pause the SPI interface
//  of a SEEPROM when the Hold signal is asserted. When leading edge of Hold
//  occurs while SCK is low, the Rdy output goes low and stays low until the
//  trailing edge of Hold occurs while SCK is low. In all other cases, the Rdy
//  FF maintains its state.
//
//  Assumption: at least one rising edge of SCK occurs between the leading and
//  trailing edges of Hold. If this does not occur, then the circuit will not
//  operate as specified above.
//
// Dependencies: 
//
// Revision: 
//
//  0.00    12H05   MAM     Initial Code Entry
//
// Additional Comments: 
//
////////////////////////////////////////////////////////////////////////////////

module SEEPROM_Rdy(
    input   Rst,
    
    input   Hold,
    input   SCK,
    
    output  reg Rdy
);

////////////////////////////////////////////////////////////////////////////////
//
//  Module Declarations
//

reg     MuxCntl;

////////////////////////////////////////////////////////////////////////////////
//
//  Module Declarations
//

always @(posedge SCK or posedge Rst)
begin
    if(Rst)
        MuxCntl <= #1 1;
    else
        MuxCntl <= #1 Rdy;
end

assign Rdy_Clk = ((MuxCntl) ? Hold : ~Hold);
assign Rdy_DIn = ((MuxCntl) ? SCK  : ~SCK );

always @(posedge Rdy_Clk or posedge Rst)
begin
    if(Rst)
        Rdy <= #1 1;
    else
        Rdy <= #1 Rdy_DIn;
end

endmodule
