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
//  The source code contained herein is free; it may be redistributed and/or
//  modified in accordance with the terms of the GNU Lesser General Public
//  License as published by the Free Software Foundation; either version 2.1 of
//  the GNU Lesser General Public License, or any later version.
//
//  The source code contained herein is freely released WITHOUT ANY WARRANTY;
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
//  0.61    12H18   MAM     Changed the default shift mechanism of the ALU stack
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
//  1.00    12J13   MAM     When developing the PCU, determined that the compu-
//                          tation of the non-local address required that the
//                          A register be shifted out LSB first rather than MSB
//                          first. When this change was inserted into the case
//                          statements, it resulted in a design which would not
//                          fit into the CPLD in which the Serial ALU had been
//                          fitting, i.e. the XC9572-7PC44. The fitter required
//                          the next larger CPLD, i.e. XC95108-7PC84, to fit the
//                          simple change made to the POP instruction. Thus, a
//                          change was made to all of the case statements, which
//                          entailed changing the selects from localparams into
//                          5-bit constants and removing the default case, i.e.
//                          fully specifying the case statements. To simplify
//                          this operation, the carry and A registers were sepa-
//                          rated into their own always blocks. Putting all of
//                          encoding directly into the case statements allowed
//                          the definition of two default cases: one for left
//                          shifts and one for right shifts. All direct instruc-
//                          tions (I[4]==0) perform left shifts, and indirect
//                          instructions all perform right shifts. In addition,
//                          some additional defaults were included for instruc-
//                          tions which do not use the ALU. The result is that
//                          Serial ALU fits into the XC9572-7PC44 with the new
//                          functionality, and maintains its performance. There
//                          is room for additional optimization, but that will
//                          be left for another time.
//
//  1.01    12J13   MAM     Restored port list modifications that aid in the
//                          interconnection of the Serial PCU and Serial ALU.
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

`define DEBUG   // Enable Test Port of UUT

module MiniCPU_SerALU #(
    parameter N = 16
)(
    input   Rst,
    input   Clk,

    input   ALU_En,
    input   [4:0] ALU_Op,

    input   PCU_DI,
    input   ALU_DI,
    output  reg ALU_DO,

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

wire    CE;                     // Maps to ALU_En
wire    [4:0] I;                // Maps to ALU_Op
wire    Op, W;                  // Maps to PCU_DI
wire    [(N - 1):0] DI;         // Maps to ALU_DI

wire    Sub;
wire    Ai, Bi, Ci, Sum, Co;

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

//  Map ports to internal signals

assign CE = ALU_En;
assign I  = ALU_Op;
assign Op = PCU_DI;
assign W  = PCU_DI;
assign DI = ALU_DI;

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
//      A is generally rotated right, i.e. LSB first, except for ROL/LDK/LDL/
//          LDNL/STL/STNL/IN/INB/OUT/OUTB instructions. For these instructions,
//          A (and the other ALU stack registers) rotate left, i.e. MSB first.
//          Rotating right is required for all arithmetic and logic operations,
//          except ROL. Shifting right is required for the computation of the
//          non-local addresses, A + Op, the result of which is loaded into Op
//          prior to being output to the memory device. In the case of most dual
//          operand arithmetic and logic instructions, the A and B operands
//          shift LSB first (except ROL - B shifts right and A shifts left). The
//          single bit ALU result is shifted into the MSB of A, and the LSB of C
//          is shifted into the MSB of B. Thus, the operands are removed from
//          the stack and the result is pushed onto the ALU stack so the ALU
//          stack is properly adjusted without the need for any extra cycles.

always @(posedge Clk)
begin
    if(Rst)
        Cy <= #1 0;
    else if(CE)
        case(I)
            5'b00000 : Cy <= #1 Cy;                     // PFX
            5'b00001 : Cy <= #1 Cy;                     // NFX
            5'b00010 : Cy <= #1 Cy;                     // EXE
            5'b00011 : Cy <= #1 Cy;                     // LDK
            5'b00100 : Cy <= #1 Cy;                     // LDL
            5'b00101 : Cy <= #1 Cy;                     // LDNL
            5'b00110 : Cy <= #1 Cy;                     // STL
            5'b00111 : Cy <= #1 Cy;                     // STNL
            5'b01000 : Cy <= #1 Cy;                     // IN
            5'b01001 : Cy <= #1 Cy;                     // INB
            5'b01010 : Cy <= #1 Cy;                     // OUT
            5'b01011 : Cy <= #1 Cy;                     // OUTB
            5'b01100 : Cy <= #1 Cy;                     // BEQ
            5'b01101 : Cy <= #1 Cy;                     // BLT
            5'b01110 : Cy <= #1 Cy;                     // JMP
            5'b01111 : Cy <= #1 Cy;                     // CALL
            5'b10000 : Cy <= #1  0;                     // CLC
            5'b10001 : Cy <= #1  1;                     // SEC
            5'b10010 : Cy <= #1 Cy;                     // TAW
            5'b10011 : Cy <= #1 Cy;                     // TWA
            5'b10100 : Cy <= #1 Cy;                     // DUP
            5'b10101 : Cy <= #1 Cy;                     // POP
            5'b10110 : Cy <= #1 Cy;                     // XAB
            5'b10111 : Cy <= #1 Cy;                     // RAS
            5'b11000 : Cy <= #1 (B[0] ? A[0]     : Cy); // ROR
            5'b11001 : Cy <= #1 (B[0] ? A[(N-1)] : Cy); // ROL
            5'b11010 : Cy <= #1 Co;                     // ADC
            5'b11011 : Cy <= #1 Co;                     // SBC
            5'b11100 : Cy <= #1 Cy;                     // AND
            5'b11101 : Cy <= #1 Cy;                     // ORL
            5'b11110 : Cy <= #1 Cy;                     // XOR
            5'b11111 : Cy <= #1 Cy;                     // HLT
        endcase
end

always @(posedge Clk)
begin
    if(Rst)
        A <= #1 0;
    else if(CE)
        case(I)
            5'b00000 : A <= #1 {A[(N-2):0],       Op};                  // PFX
            5'b00001 : A <= #1 {A[(N-2):0],       Op};                  // NFX
            5'b00010 : A <= #1 {A[(N-2):0],       Op};                  // EXE
            5'b00011 : A <= #1 {A[(N-2):0],       Op};                  // LDK
            5'b00100 : A <= #1 {A[(N-2):0],       DI};                  // LDL
            5'b00101 : A <= #1 {A[(N-2):0],       DI};                  // LDNL
            5'b00110 : A <= #1 {A[(N-2):0], B[(N-1)]};                  // STL
            5'b00111 : A <= #1 {A[(N-2):0], B[(N-1)]};                  // STNL
            //
            5'b01000 : A <= #1  {A[ (N-2)   :    0], DI   };            // IN
            5'b01001 : A <= #1 {{A[ (N-2)   :(N/2)], 1'b0},             // INB
                                {A[((N/2)-2):    0], DI  }};            // INB
            5'b01010 : A <= #1  {A[ (N-2)   :    0], B[(N-1)]     };    // OUT
            5'b01011 : A <= #1 {{A[ (N-2)   :(N/2)], B[ (N-1)   ]},     // OUTB
                                {A[((N/2)-2):    0], B[((N/2)-1)]}};    // OUTB
            //
            5'b01100 : A <= #1 {A[(N-2):0], A[(N-1)]};                  // BEQ
            5'b01101 : A <= #1 {A[(N-2):0], A[(N-1)]};                  // BLT
            5'b01110 : A <= #1 {A[(N-2):0], A[(N-1)]};                  // JMP
            5'b01111 : A <= #1 {A[(N-2):0], A[(N-1)]};                  // CALL
            //
            5'b10000 : A <= #1 {A[0], A[(N-1):1]};                      // CLC
            5'b10001 : A <= #1 {A[0], A[(N-1):1]};                      // SEC
            5'b10010 : A <= #1 {B[0], A[(N-1):1]};                      // TAW
            5'b10011 : A <= #1 {   W, A[(N-1):1]};                      // TWA
            5'b10100 : A <= #1 {A[0], A[(N-1):1]};                      // DUP
            5'b10101 : A <= #1 {B[0], A[(N-1):1]};                      // POP
            5'b10110 : A <= #1 {B[0], A[(N-1):1]};                      // XAB
            5'b10111 : A <= #1 {B[0], A[(N-1):1]};                      // RAS
            //
            5'b11000 : A <= #1 ((B[0]) ? {A[0], A[(N-1):1]}            // ROR
                                        :  A                    );       // ROR
            5'b11001 : A <= #1 ((B[0]) ? {A[(N-2):0], A[(N-1)]}        // ROL
                                        :  A                    );       // ROL
            5'b11010 : A <= #1 {Sum, A[(N-1):1]};                       // ADC
            5'b11011 : A <= #1 {Sum, A[(N-1):1]};                       // SBC
            5'b11100 : A <= #1 {(B[0] & A[0]), A[(N-1):1]};            // AND
            5'b11101 : A <= #1 {(B[0] | A[0]), A[(N-1):1]};            // ORL
            5'b11110 : A <= #1 {(B[0] ^ A[0]), A[(N-1):1]};            // XOR
            5'b11111 : A <= #1 {(B[0] ^ A[0]), A[(N-1):1]};            // HLT
        endcase
end

//  ALU Register B
//      B register provides the left operand of any two operand ALU functions
//      B is automatically pushed or popped as required.
//      B is generally rotated right, i.e. LSB first, except for LDK/LDL/LDNL/
//          STL/STNL/IN/INB/OUT/OUTB instructions. For these 9 instructions, B
//          (and the other ALU stack registers) rotate left, i.e. MSB first.
//          Rotating right is required for all arithmetic and logic operations.
//          In the case of dual operand arithmetic and logic instructions, the A
//          and B operands shift LSB first. The single bit ALU result is shifted
//          into the MSB of A, and the LSB of C is shifted into the MSB of B.
//          Thus, the operands are removed from the stack and the result is
//          pushed onto the ALU stack so that the ALU stack is properly adjusted
//          without the need for any extra cycles.

always @(posedge Clk)
begin
    if(Rst)
        B <= #1 0;
    else if(CE)
        case(I)
            5'b00000 : B <= #1 {B[(N-2):0], C[(N-1)]};                  // PFX
            5'b00001 : B <= #1 {B[(N-2):0], C[(N-1)]};                  // NFX
            5'b00010 : B <= #1 {B[(N-2):0], A[(N-1)]};                  // EXE
            5'b00011 : B <= #1 {B[(N-2):0], A[(N-1)]};                  // LDK
            5'b00100 : B <= #1 {B[(N-2):0], A[(N-1)]};                  // LDL
            5'b00101 : B <= #1 {B[(N-2):0], A[(N-1)]};                  // LDNL
            5'b00110 : B <= #1 {B[(N-2):0], C[(N-1)]};                  // STL
            5'b00111 : B <= #1 {B[(N-2):0], C[(N-1)]};                  // STNL
            5'b01000 : B <= #1  {B[ (N-2)   :    0], A[ (N-1)   ]};    // IN
            5'b01001 : B <= #1 {{B[ (N-2)   :(N/2)], A[ (N-1)   ]},    // INB
                                {B[((N/2)-2):    0], A[((N/2)-1)]}};    // INB
            5'b01010 : B <= #1  {B[ (N-2)   :    0], C[ (N-1)   ]};    // OUT
            5'b01011 : B <= #1 {{B[ (N-2)   :(N/2)], C[ (N-1)   ]},    // OUTB
                                {B[((N/2)-2):    0], C[((N/2)-1)]}};    // OUTB
            5'b01100 : B <= #1 {B[(N-2):0], B[(N-1)]};                  // BEQ
            5'b01101 : B <= #1 {B[(N-2):0], B[(N-1)]};                  // BLT
            5'b01110 : B <= #1 {B[(N-2):0], B[(N-1)]};                  // JMP
            5'b01111 : B <= #1 {B[(N-2):0], B[(N-1)]};                  // CALL
            //
            5'b10000 : B <= #1 {B[0], B[(N-1):1]};                      // CLC
            5'b10001 : B <= #1 {B[0], B[(N-1):1]};                      // SEC
            5'b10010 : B <= #1 {C[0], B[(N-1):1]};                      // TAW
            5'b10011 : B <= #1 {A[0], B[(N-1):1]};                      // TWA
            5'b10100 : B <= #1 {A[0], B[(N-1):1]};                      // DUP
            5'b10101 : B <= #1 {C[0], B[(N-1):1]};                      // POP
            5'b10110 : B <= #1 {A[0], B[(N-1):1]};                      // XAB
            5'b10111 : B <= #1 {C[0], B[(N-1):1]};                      // RAS
            //
            5'b11000 : B <= #1 {C[0], B[(N-1):1]};                      // ROR
            5'b11001 : B <= #1 {C[0], B[(N-1):1]};                      // ROL
            5'b11010 : B <= #1 {C[0], B[(N-1):1]};                      // ADC
            5'b11011 : B <= #1 {C[0], B[(N-1):1]};                      // SBC
            5'b11100 : B <= #1 {C[0], B[(N-1):1]};                      // AND
            5'b11101 : B <= #1 {C[0], B[(N-1):1]};                      // ORL
            5'b11110 : B <= #1 {C[0], B[(N-1):1]};                      // XOR
            5'b11111 : B <= #1 {C[0], B[(N-1):1]};                      // HLT
        endcase
end

//  ALU Register C
//      C is automatically pushed or popped as required.
//      C is generally rotated right, i.e. LSB first, except for LDK/LDL/LDNL/
//          STL/STNL/IN/INB/OUT/OUTB instructions. For these 9 instructions, C
//          (and the other ALU stack registers) rotate left, i.e. MSB first.
//          Rotating right is required for all arithmetic and logic operations.
//          In the case of dual operand arithmetic and logic instructions, the A
//          and B operands shift LSB first. The single bit ALU result is shifted
//          into the MSB of A, and the LSB of C is shifted into the MSB of B.
//          Thus, the operands are removed from the stack and the result is
//          pushed onto the ALU stack so that the ALU stack is properly adjusted
//          without the need for any extra cycles.

always @(posedge Clk)
begin
    if(Rst)
        C <= #1 0;
    else if(CE)
        case(I)
            5'b00000 : C <= #1 {C[(N-2):0], C[(N-1)]};                  // PFX
            5'b00001 : C <= #1 {C[(N-2):0], C[(N-1)]};                  // NFX
            5'b00010 : C <= #1 {C[(N-2):0], B[(N-1)]};                  // EXE
            5'b00011 : C <= #1 {C[(N-2):0], B[(N-1)]};                  // LDK
            5'b00100 : C <= #1 {C[(N-2):0], B[(N-1)]};                  // LDL
            5'b00101 : C <= #1 {C[(N-2):0], B[(N-1)]};                  // LDNL
            5'b00110 : C <= #1 {C[(N-2):0], C[(N-1)]};                  // STL
            5'b00111 : C <= #1 {C[(N-2):0], C[(N-1)]};                  // STNL
            5'b01000 : C <= #1  {C[ (N-2)   :    0], B[ (N-1)   ]};     // IN
            5'b01001 : C <= #1 {{C[ (N-2)   :(N/2)], B[ (N-1)   ]},     // INB
                                {C[((N/2)-2):    0], B[((N/2)-1)]}};    // INB
            5'b01010 : C <= #1  {C[ (N-2)   :    0], C[ (N-1)   ]};     // OUT
            5'b01011 : C <= #1 {{C[ (N-2)   :(N/2)], C[ (N-1)   ]},     // OUTB
                                {C[((N/2)-2):    0], C[((N/2)-1)]}};    // OUTB
            5'b01100 : C <= #1 {C[(N-2):0], C[(N-1)]};                  // BEQ
            5'b01101 : C <= #1 {C[(N-2):0], C[(N-1)]};                  // BLT
            5'b01110 : C <= #1 {C[(N-2):0], C[(N-1)]};                  // JMP
            5'b01111 : C <= #1 {C[(N-2):0], C[(N-1)]};                  // CALL
            5'b10000 : C <= #1 {C[0], C[(N-1):1]};                      // CLC
            5'b10001 : C <= #1 {C[0], C[(N-1):1]};                      // SEC
            5'b10010 : C <= #1 {C[0], C[(N-1):1]};                      // TAW
            5'b10011 : C <= #1 {B[0], C[(N-1):1]};                      // TWA
            5'b10100 : C <= #1 {B[0], C[(N-1):1]};                      // DUP
            5'b10101 : C <= #1 {C[0], C[(N-1):1]};                      // POP
            5'b10110 : C <= #1 {C[0], C[(N-1):1]};                      // XAB
            5'b10111 : C <= #1 {A[0], C[(N-1):1]};                      // RAS
            5'b11000 : C <= #1 {C[0], C[(N-1):1]};                      // ROR
            5'b11001 : C <= #1 {C[0], C[(N-1):1]};                      // ROL
            5'b11010 : C <= #1 {C[0], C[(N-1):1]};                      // ADC
            5'b11011 : C <= #1 {C[0], C[(N-1):1]};                      // SBC
            5'b11100 : C <= #1 {C[0], C[(N-1):1]};                      // AND
            5'b11101 : C <= #1 {C[0], C[(N-1):1]};                      // ORL
            5'b11110 : C <= #1 {C[0], C[(N-1):1]};                      // XOR
            5'b11111 : C <= #1 {C[0], C[(N-1):1]};                      // HLT
        endcase
end

//  Output Data Multiplexer

always @(*)
begin
    case(I)
        pSTL    : ALU_DO <= A[( N-1)   ];
        pSTNL   : ALU_DO <= A[ (N-1)   ];

        pOUT    : ALU_DO <= A[ (N-1)   ];
        pOUTB   : ALU_DO <= A[((N/2)-1)];

        pTAW    : ALU_DO <= A[0];
        pPOP    : ALU_DO <= A[0];

        default : ALU_DO <= 0;
    endcase
end

endmodule
