///////////////////////////////////////////////////////////////////////////////
//
//  Copyright 2012 by Michael A. Morris, dba M. A. Morris & Associates
//
//  All rights reserved. The source code contained herein is publicly released
//  under the terms and conditions of the GNU Lesser Public License. No part of
//  this source code may be reproduced or transmitted in any form or by any
//  means, electronic or mechanical, including photocopying, recording, or any
//  information storage and retrieval system in violation of the license under
//  which the source code is released.
//
//  The souce code contained herein is free; it may be redistributed and/or 
//  modified in accordance with the terms of the GNU Lesser General Public
//  License as published by the Free Software Foundation; either version 2.1 of
//  the GNU Lesser General Public License, or any later version.
//
//  The souce code contained herein is freely released WITHOUT ANY WARRANTY;
//  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
//  PARTICULAR PURPOSE. (Refer to the GNU Lesser General Public License for
//  more details.)
//
//  A copy of the GNU Lesser General Public License should have been received
//  along with the source code contained herein; if not, a copy can be obtained
//  by writing to:
//
//  Free Software Foundation, Inc.
//  51 Franklin Street, Fifth Floor
//  Boston, MA  02110-1301 USA
//
//  Further, no use of this source code is permitted in any form or means
//  without inclusion of this banner prominently in any derived works. 
//
//  Michael A. Morris
//  Huntsville, AL
//
///////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company:         M. A. Morris & Assoc. 
// Engineer:        Michael A. Morris
// 
// Create Date:     18:03:47 08/01/2012 
// Design Name:     Minimal CPU Implementation for CPLD 
// Module Name:     MiniCPU_SerALU.v 
// Project Name:    C:\XProjects\ISE10.1i\MiniCPU 
// Target Devices:  CPLDs 
// Tool versions:   ISE 10.1i SP3
//
// Description:
//
//  This module is a serial implementation of the parallel ALU implemented in
//  MiniCPU_ALU. It provides the same stack based architecture, and performs the
//  same arithmetic (ADC/SBC), logic (AND/ORL/XOR), and shift (ROR/ROL) opera-
//  tions. It also supports ST (ALU stack pop), and LD (ALU stack push) opera-
//  tions, and provides a means for initializing the Cy registers to support
//  multi-precision additions and subtractions.
//
// Dependencies:    none
//
// Revision:
//  0.00    12H01   MAM     Initial Coding
//
//  0.10    12H03   MAM     Changed the Add signal to a Sub signal, and adjusted
//                          order of the Ai signal multiplexer. This change did
//                          not result in any substantive changes to performance
//                          or to the number of p-terms required to implement
//                          the design.
//
//  0.20    12H03   MAM     Changed the default condition for each of the three
//                          ALU registers so if no ALU operation is required, a
//                          circular shift is performed when the ALU CE is high.
//                          Resulted in a substantial decrease from 201 to 125
//                          in the number of p-terms (8-bit ALU), and perfor-
//                          mance: 70 MHz operation increased to 86 MHz.
//
//  0.50    12H12   MAM     Modified to match the instruction definitions adopt-
//                          for the MiniCPU-S in its System Design Description
//                          (SDD): "1012-0001 SDD for SPI-based Minimal CPU for
//                          CPLDs". A new instruction set is defined in that
//                          document.
//
//  0.51    12H12   MAM     Removed TOS as an output, and added an output signal
//                          multiplexer.
//
//  0.60    12H17   MAM     Changed the definition and implementation of the RRC
//                          and RLC instructions. Refer to 1012-0001 SDD for the
//                          change in definition of the instructions as 16-bit
//                          rotate instructions ROR/ROL, respectively. ALU
//                          register B is the shift mask, and ALU register A is
//                          the working register. Also changed the direction of
//                          stack rotation for the RAS instruction.
//
//  0.61    12H18   MAM     Changed the dafault shift mechanism of the ALU stack
//                          so that STL/STNL shift data in an MSB first manner.
//                          By convention, most SPI devices shift data in/out in
//                          an MSB first manner. This is particularly true for
//                          memory addresses.
//
//  0.70    12H18   MAM     Changed the behavior INB and OUTB instructions so
//                          that 8 shift clocks will shift all 16 bits of the
//                          affected ALU stack registers. Had to adjust the
//                          CPLD fitting parameters to maintain a fit in the
//                          XC9572 CPLD: input collapsing limit changed to 20,
//                          and pterm collapsing limit changed to 9. Also needed
//                          a change in the instruction codes for the LDx/STx,
//                          and INx/OUTx instructions. Organized as LDL/LDNL,
//                          STL/STNL, IN/INB, and OUT/OUTB instead of LD/ST,
//                          LDNL/STNL, IN/OUT, and INB/OUTB. These changes allow
//                          the fitter to maintain the MiniCPU_SerALU in the
//                          target CPLD.
//
//  0.80    12H18   MAM     Added ALU Condition Code Flags: Zer, and Neg. These
//                          flags are required for the BEQ and BLT instructions.
//
//  0.90    12H18   MAM     Reworked the instruction set to add to new functions
//                          which will allow the Carry register to be cleared or
//                          set. The instruction set now consists of 33 instruc-
//                          tions: 15 direct, and 18 indirect. RTS/RTI have been
//                          replaced by CLC/SEC, which clear and set the carry,
//                          respectively. RTS/RTI are replaced by two byte in-
//                          direct instructions with no effects on the ALU. Need-
//                          ed adjustment to input and pterm collapsing limits in
//                          order to fit these last two instructions: 20, 7, re-
//                          spectively.
//
//  0.91    12H19   MAM     Since the fitter was able to fit the design, the INB
//                          instruction was modified to zero the upper byte as
//                          the data is being input. This is in contrast to the
//                          previous definition which duplicated the input byte
//                          in both halves of the TOS.
//
// Additional Comments:
//
//  The ALU is presented with a parallel function code when an operation is to
//  be performed. A clock enable signal is also required. When CE is asserted,
//  the instruction that the CPU is executing is an ALU operation. Therefore,
//  the ALU registers only perform a circular shift by default when an ALU func-
//  tion is being executed. Since loading and storing ALU registers requires N
//  cycles to perform, circularly shifting unused registers will not result in
//  a change to the value of registers not involved in an ALU operation.
//
////////////////////////////////////////////////////////////////////////////////

//`define DEBUG   // Enable Test Port of UUT

module MiniCPU_SerALU #(
    parameter N = 16
)(
    input   Rst,
    input   Clk,

    input   CE,
    input   [4:0] I,

    input   DI,
    input   Op,
    input   W,

    output  DO,
    output  Zer,

`ifndef DEBUG
    output  Neg
`else
    output  Neg,
    output  [48:0] TstPort
`endif
);

////////////////////////////////////////////////////////////////////////////////
//
//  Module Parameters
//

`include "MiniCPU_SerALU.txt"

////////////////////////////////////////////////////////////////////////////////
//
//  Module Declarations
//

wire    Sub;
wire    Ai, Bi, Ci, Sum, Co;

reg     ALU_DO;

reg     [(N - 1):0] A, B, C;
reg     Cy;

////////////////////////////////////////////////////////////////////////////////
//
//  Implementation
//

//  Debug Port for testing with self-checking testbench

`ifdef DEBUG
assign TstPort[48]    = Cy;
assign TstPort[47:32] = A;
assign TstPort[31:16] = B;
assign TstPort[15: 0] = C;
`endif

//  ALU Serial Adder

assign Sub = (I == pSBC);

assign Ci  = Cy;
assign Bi  = B[0];
assign Ai  = ((Sub) ? ~A[0] : A[0]);

assign Sum = (Bi ^ Ai ^ Ci);
assign Co  = ((Bi & Ai) | ((Bi ^ Ai) & Ci));

//  ALU Condition Code Flags

assign Zer = ~|A; 
assign Neg = A[(N-1)];

//  ALU Register A and Carry Register 
//      A register provides the right operand of any two operand ALU functions
//      A is automatically pushed or popped as required.
//      A is generally rotated left, i.e. MSB first, except for the case
//          where ROR or ADC/SBC being performed. In the case of these three
//          instructions, the A operand always rotates LSB first. In the case of
//          ADC/SBC, A rotates LSB first because binary arithmetic progresses
//          from LSB to MSB. In these three cases, the LSB of A shifts into the
//          MSB of A so that at the completion of these instructions, the ALU's
//          result has fully replaced A.

always @(posedge Clk)
begin
    if(Rst)
        {Cy, A} <= #1 0;
    else if(CE)
        case(I)
            pLDK    : {Cy, A} <= #1 {Cy, A[(N-2):0], Op      };
            pLDL    : {Cy, A} <= #1 {Cy, A[(N-2):0], DI      };
            pLDNL   : {Cy, A} <= #1 {Cy, A[(N-2):0], DI      };
            pSTL    : {Cy, A} <= #1 {Cy, A[(N-2):0], B[(N-1)]};
            pSTNL   : {Cy, A} <= #1 {Cy, A[(N-2):0], B[(N-1)]};

            pIN     : {Cy, A} <= #1 {Cy, {A[(N-2):    0], DI}};
            pINB    : {Cy, A} <= #1 {Cy, {A[(N-2):(N/2)], 1'b0},
                                         {A[((N/2)-2):0], DI  }};

            pOUT    : {Cy, A} <= #1 {Cy, {A[(N-2):    0], B[(N-1)]}};
            pOUTB   : {Cy, A} <= #1 {Cy, {A[(N-2):(N/2)], B[(N-1)]},
                                         {A[((N/2)-2):0], B[((N/2)-1)]}};

            pCLC    : {Cy, A} <= #1 {1'b0, A[(N-2):0], A[(N-1)]};
            pSEC    : {Cy, A} <= #1 {1'b1, A[(N-2):0], A[(N-1)]};
            
            pTAW    : {Cy, A} <= #1 {Cy, A[(N-2):0], B[(N-1)]};
            pTWA    : {Cy, A} <= #1 {Cy, A[(N-2):0], W       };

            pDUP    : {Cy, A} <= #1 {Cy, A[(N-2):0], A[(N-1)]};
            pXAB    : {Cy, A} <= #1 {Cy, A[(N-2):0], B[(N-1)]};
            pPOP    : {Cy, A} <= #1 {Cy, A[(N-2):0], B[(N-1)]};
            pRAS    : {Cy, A} <= #1 {Cy, A[(N-2):0], B[(N-1)]};

            pROR    : {Cy, A} <= #1 ((B[0]) ? {A[0], {A[0], A[(N-1):1]}}
                                            : {Cy, A} );
            pROL    : {Cy, A} <= #1 ((B[0]) ? {A[(N-1)], {A[(N-2):0], A[(N-1)]}}
                                            : {Cy, A} );
            pADC    : {Cy, A} <= #1 {Co, Sum, A[(N-1):1]};
            pSBC    : {Cy, A} <= #1 {Co, Sum, A[(N-1):1]};
            pAND    : {Cy, A} <= #1 {Cy, A[(N-2):0], (B[(N-1)] & A[(N-1)])};
            pORL    : {Cy, A} <= #1 {Cy, A[(N-2):0], (B[(N-1)] | A[(N-1)])};
            pXOR    : {Cy, A} <= #1 {Cy, A[(N-2):0], (B[(N-1)] ^ A[(N-1)])};
            
            default : {Cy, A} <= #1 {Cy, A[(N-2):0], A[(N-1)]};
        endcase
end

//  ALU Register B
//      B register provides the left operand of any two operand ALU functions
//      B is automatically pushed or popped as required.
//      B is generally rotated left, i.e. MSB first, except for the case
//          where ROR/ROL or ADC/SBC being performed. In the case of these four
//          instructions, the B operand always rotates LSB first. In the case of
//          ROR/ROL, it rotates in this manner because the shift mask in B needs
//          to rotate LSB first. In the case of ADC/SBC, it rotates LSB first
//          because binary arithmetic progresses from LSB to MSB. In either of
//          these cases, the LSB of C shifts into the MSB of B so that at the
//          completion of these instructions, C has fully replaced B.

always @(posedge Clk)
begin
    if(Rst)
        B <= #1 0;
    else if(CE)
        case(I)
            pLDK    : B <= #1 {B[(N-2):0], A[(N-1)]};
            pLDL    : B <= #1 {B[(N-2):0], A[(N-1)]};
            pLDNL   : B <= #1 {B[(N-2):0], A[(N-1)]};
            pSTL    : B <= #1 {B[(N-2):0], C[(N-1)]};
            pSTNL   : B <= #1 {B[(N-2):0], C[(N-1)]};

            pIN     : B <= #1  {B[(N-2):    0], A[(N-1)]};
            pINB    : B <= #1 {{B[(N-2):(N/2)], A[(N-1)]},      // High Byte
                               {B[((N/2)-2):0], A[((N/2)-1)]}}; // Low Byte

            pOUT    : B <= #1  {B[(N-2):0],     C[(N-1)]};
            pOUTB   : B <= #1 {{B[(N-2):(N/2)], C[(N-1)]},      // High Byte
                               {B[((N/2)-2):0], C[((N/2)-1)]}}; // Low Byte
            
            pTAW    : B <= #1 {B[(N-2):0], C[(N-1)]};
            pTWA    : B <= #1 {B[(N-2):0], A[(N-1)]};
            
            pDUP    : B <= #1 {B[(N-2):0], A[(N-1)]};
            pXAB    : B <= #1 {B[(N-2):0], A[(N-1)]};
            pPOP    : B <= #1 {B[(N-2):0], C[(N-1)]};
            pRAS    : B <= #1 {B[(N-2):0], C[(N-1)]};
            
            pROR    : B <= #1 {C[0], B[(N-1):1]};
            pROL    : B <= #1 {C[0], B[(N-1):1]};
            pADC    : B <= #1 {C[0], B[(N-1):1]};
            pSBC    : B <= #1 {C[0], B[(N-1):1]};
            
            pAND    : B <= #1 {B[(N-2):0], C[(N-1)]};
            pORL    : B <= #1 {B[(N-2):0], C[(N-1)]};
            pXOR    : B <= #1 {B[(N-2):0], C[(N-1)]};

            default : B <= #1 {B[(N-2):0], B[(N-1)]};
        endcase
end

//  ALU Register C
//      C is automatically pushed or popped as required.
//      C is generally rotated left, i.e. MSB first, except for the case
//          where ROR/ROL or ADC/SBC being performed. In the case of these four
//          instructions, the B operand always rotates LSB first. In the case of
//          ROR/ROL, it rotates in this manner because the shift mask in B needs
//          to rotate LSB first. In the case of ADC/SBC, it rotates LSB first
//          because binary arithmetic progresses from LSB to MSB. In either of
//          these cases, the LSB of C shifts into the MSB of B so that at the
//          completion of these instructions, C has fully replaced B.

always @(posedge Clk)
begin
    if(Rst)
        C <= #1 0;
    else if(CE)
        case(I)
            pLDK    : C <= #1 {C[(N-2):0], B[(N-1)]};
            pLDL    : C <= #1 {C[(N-2):0], B[(N-1)]};
            pLDNL   : C <= #1 {C[(N-2):0], B[(N-1)]};
            
            pIN     : C <= #1 {C[(N-2):     0], B[(N-1)]};
            pINB    : C <= #1 {{C[(N-2):(N/2)], B[(N-1)]},      // High Byte
                               {C[((N/2)-2):0], B[((N/2)-1)]}}; // Low Byte
            
            pOUTB   : C <= #1 {{C[(N-2):(N/2)], C[(N-1)]},      // High Byte
                               {C[((N/2)-2):0], C[((N/2)-1)]}}; // Low Byte
            
            pTWA    : C <= #1 {C[(N-2):0], B[(N-1)]};
            
            pDUP    : C <= #1 {C[(N-2):0], B[(N-1)]};
            pRAS    : C <= #1 {C[(N-2):0], A[(N-1)]};

            pROR    : C <= #1 {C[0], C[(N-1):1]};
            pROL    : C <= #1 {C[0], C[(N-1):1]};
            pADC    : C <= #1 {C[0], C[(N-1):1]};
            pSBC    : C <= #1 {C[0], C[(N-1):1]};
            
            default : C <= #1 {C[(N-2):0], C[(N-1)]};
        endcase
end

//  Output Data Multiplexer

always @(*)
begin
    case(I)
        pSTL    : ALU_DO <= A[(N-1)];
        pSTNL   : ALU_DO <= A[(N-1)];

        pOUT    : ALU_DO <= A[(N-1)];
        pOUTB   : ALU_DO <= A[((N/2)-1)];

        pTAW    : ALU_DO <= A[(N-1)];

        default : ALU_DO <= 0;
    endcase
end

assign DO = ALU_DO;

endmodule
