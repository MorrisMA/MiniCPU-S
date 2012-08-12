`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Company:         M. A. Morris & Assoc. 
// Engineer:        Michael A. Morris
// 
// Create Date:     18:03:47 08/01/2012 
// Design Name:     Minimal CPU Implementation for CPLD 
// Module Name:     MiniCPU_SerALU 
// Project Name:    MiniCPU 
// Target Devices:  CPLDs 
// Tool versions:   ISE 10.1i SP3
//
// Description:
//
//  This module is a serial implementation of the parallel ALU implemented in
//  MiniCPU_APU. It provides the same stack based architecture, and performs the
//  same arithmetic (ADC/SBB), logic (AND/ORL/XOR), and shift (RRC/RLC) opera-
//  tions. It also supports ST (ALU stack pop), and LD (ALU stack push) opera-
//  tions.
//
// Dependencies:    none
//
// Revision:
//  0.00    12H01   MAM     Initial Coding
//
//  0.10    12H03   MAM     Changed the Add signal to a Sub signal, and adjusted
//                          order of the Ai signal multiplexer. This change did
//                          not result in any sunstantive changes to performance
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
//                          (SDD), "1012-0001 SDD for SPI-based Minimal CPU for
//                          CPLDs". A new instruction set is defined in that
//                          document.
//
//  0.51    12H12   MAM     Removed TOS as an output, and added an output signal
//                          multiplexer.
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

    output  DO
);

////////////////////////////////////////////////////////////////////////////////
//
//  Module Parameters
//

//  Direct Instructions

localparam pCALL = 5'b00000;    // CALL : *(W-1)<=I;W<=W-1;
                                //      : IR<=*(I'=I+1+0&Op);Op<=0;                                
localparam pLDK  = 5'b00001;    // LDK  : IR<=*(I'=I+1);{A,B,C}<={Op,A,B};Op<=0;
localparam pLDL  = 5'b00010;    // LDL  : {A,B,C}<={*(W+Op),A,B};
                                //      : IR<=*(I'=I+1);Op<=0; 
localparam pSTL  = 5'b00011;    // STL  : *(W+Op)<=A;{A,B,C}<={B,C,C};
                                //      : IR<=*(I'=I+1);Op<=0;
localparam pLDNL = 5'b00100;    // LDNL : {A,B,C}<={*(A+Op),A,B};
                                //      : IR<=*(I'=I+1);Op<=0;  
localparam pSTNL = 5'b00101;    // STNL : *(A+Op)<=B;{A,B,C}<={C,C,C};
                                //      : IR<=*(I'=I+1);Op<=0;
localparam pNFX  = 5'b00110;    // NFX  : IR<=*(I'=I+1); Op<=(~Op|IR[3:0])<<4;
localparam pPFX  = 5'b00111;    // PFX  : IR<=*(I'=I+1); Op<=( Op|IR[3:0])<<4;
localparam pIN   = 5'b01000;    // IN   : {A,B,C}<={SPI_Rd16(Op,A),A,B};
                                //      : IR<=*(I'=I+1);Op<=0;
localparam pOUT  = 5'b01001;    // OUT  : SPI_Wr16(Op,A,B);{A,B,C}<={C,C,C};
                                //      : IR<=*(I'=I+1);Op<=0; 
localparam pINB  = 5'b01010;    // INB  : {A,B,C}<={SPI_Rd08(Op,A),A,B};
                                //      : IR<=*(I'=I+1);Op<=0;
localparam pOUTB = 5'b01011;    // OUTB : SPI_Wr08(Op,A,B);{A,B,C}<={C,C,C};
                                //      : IR<=*(I'=I+1);Op<=0;
localparam pBEQ  = 5'b01100;    // BEQ  : IR<=*(I'=I+1+Z&Op);Op<=0;
localparam pBLT  = 5'b01101;    // BLT  : IR<=*(I'=I+1+N&Op);Op<=0;
localparam pJMP  = 5'b01110;    // JMP  : IR<=*(I'=I+1+1&Op);Op<=0;
localparam pEXE  = 5'b01111;    // EXE  : Execute(Op);IR<=*(I'=I+1);Op<=0;

//  Indirect Instructions       

localparam pRTS  = 5'b10000;    // RTS  : I'<=*(W);W<=W+1;
localparam pRTI  = 5'b10001;    // RTI  : reserved for future use
localparam pTAW  = 5'b10010;    // TAW  : {A,B,C}<={B,C,C};W<=A;
localparam pTWA  = 5'b10011;    // TWA  : {A,B,C}<={W,A,B};
localparam pDUP  = 5'b10100;    // DUP  : {A,B,C}<={A,A,B};
localparam pXAB  = 5'b10101;    // XAB  : {A,B,C}<={B,A,C};
localparam pPOP  = 5'b10110;    // POP  : {A,B,C}<={B,C,C};
localparam pRAS  = 5'b10111;    // RAS  : {A,B,C}<={C,A,B};
localparam pRRC  = 5'b11000;    // RRC  : {A,B,C}<={{CY,A[15:1]},B,C};CY<=A[0];
localparam pRLC  = 5'b11001;    // RLC  : {A,B,C}<={{A[14:0],CY},B,C};CY<=A[15];
localparam pADC  = 5'b11010;    // ADC  : {A,B,C}<={B+ A+CY,C,C};CY<=CY[16];
localparam pSBB  = 5'b11011;    // SBC  : {A,B,C}<={B+~A+CY,C,C};CY<=CY[16];
localparam pAND  = 5'b11100;    // AND  : {A,B,C}<={B&A,C,C};
localparam pORL  = 5'b11101;    // ORL  : {A,B,C}<={B|A,C,C};
localparam pXOR  = 5'b11110;    // XOR  : {A,B,C}<={B^A,C,C};
localparam pHLT  = 5'b11111;    // HLT  : Processor Halts

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

//  ALU Serial Adder

assign Sub = (I == pSBB);

assign Ci  = Cy;
assign Bi  = B[0];
assign Ai  = ((Sub) ? ~A[0] : A[0]);

assign Sum = (Bi ^ Ai ^ Ci);
assign Co  = ((Bi & Ai) | ((Bi ^ Ai) & Ci)); 

//  ALU Register A and Carry Register 

always @(posedge Clk)
begin
    if(Rst)
        {Cy, A} <= #1 0;
    else if(CE)
        case(I)
            pLDK    : {Cy, A} <= #1 {Cy,   Op, A[(N - 1):1]};
            pLDL    : {Cy, A} <= #1 {Cy,   DI, A[(N - 1):1]};
            pSTL    : {Cy, A} <= #1 {Cy, B[0], A[(N - 1):1]};
            pLDNL   : {Cy, A} <= #1 {Cy,   DI, A[(N - 1):1]};
            pSTNL   : {Cy, A} <= #1 {Cy, B[0], A[(N - 1):1]};

            pIN     : {Cy, A} <= #1 {Cy,   DI, A[(N - 1):1]};
            pOUT    : {Cy, A} <= #1 {Cy, B[0], A[(N - 1):1]};
            pINB    : {Cy, A} <= #1 {Cy,   DI, A[(N - 1):1]};
            pOUTB   : {Cy, A} <= #1 {Cy, B[0], A[(N - 1):1]};

            pTAW    : {Cy, A} <= #1 {Cy, B[0], A[(N - 1):1]};
            pTWA    : {Cy, A} <= #1 {Cy,    W, A[(N - 1):1]};

            pDUP    : {Cy, A} <= #1 {Cy, A[0], A[(N - 1):1]};
            pXAB    : {Cy, A} <= #1 {Cy, B[0], A[(N - 1):1]};
            pPOP    : {Cy, A} <= #1 {Cy, B[0], A[(N - 1):1]};
            pRAS    : {Cy, A} <= #1 {Cy, C[0], A[(N - 1):1]};

            pRRC    : {Cy, A} <= #1 {A[0], Cy, A[(N - 1):1]};
            pRLC    : {Cy, A} <= #1 {A[(N - 1)], A[(N - 2):0], Cy};
            pADC    : {Cy, A} <= #1 {Co, Sum, A[(N - 1):1]};
            pSBB    : {Cy, A} <= #1 {Co, Sum, A[(N - 1):1]};
            pAND    : {Cy, A} <= #1 {Cy, (B[0] & A[0]), A[(N - 1):1]};
            pORL    : {Cy, A} <= #1 {Cy, (B[0] | A[0]), A[(N - 1):1]};
            pXOR    : {Cy, A} <= #1 {Cy, (B[0] ^ A[0]), A[(N - 1):1]};

            default : {Cy, A} <= #1 {Cy, A[0], A[(N - 1):1]};
        endcase
end

//  B register provides the left operand of any two operand ALU functions
//      B is automatically pushed or popped as required.

//  ALU Register B

always @(posedge Clk)
begin
    if(Rst)
        B <= #1 0;
    else if(CE)
        case(I)
            pLDK    : B <= #1 {A[0], B[(N - 1):1]};
            pLDL    : B <= #1 {A[0], B[(N - 1):1]};
            pSTL    : B <= #1 {C[0], B[(N - 1):1]};
            pLDNL   : B <= #1 {A[0], B[(N - 1):1]};
            pSTNL   : B <= #1 {C[0], B[(N - 1):1]};

            pIN     : B <= #1 {A[0], B[(N - 1):1]};
            pOUT    : B <= #1 {C[0], B[(N - 1):1]};
            pINB    : B <= #1 {A[0], B[(N - 1):1]};
            pOUTB   : B <= #1 {C[0], B[(N - 1):1]};
            
            pTAW    : B <= #1 {C[0], B[(N - 1):1]};
            pTWA    : B <= #1 {A[0], B[(N - 1):1]};
            
            pDUP    : B <= #1 {A[0], B[(N - 1):1]};
            pXAB    : B <= #1 {A[0], B[(N - 1):1]};
            pPOP    : B <= #1 {C[0], B[(N - 1):1]};
            pRAS    : B <= #1 {A[0], B[(N - 1):1]};
            
            pADC    : B <= #1 {C[0], B[(N - 1):1]};
            pSBB    : B <= #1 {C[0], B[(N - 1):1]};
            pAND    : B <= #1 {C[0], B[(N - 1):1]};
            pORL    : B <= #1 {C[0], B[(N - 1):1]};
            pXOR    : B <= #1 {C[0], B[(N - 1):1]};

            default : B <= #1 {B[0], B[(N - 1):1]};
        endcase
end

//  ALU Register C

always @(posedge Clk)
begin
    if(Rst)
        C <= #1 0;
    else if(CE)
        case(I)
            pLDK    : C <= #1 {B[0], C[(N - 1):1]};
            pLDL    : C <= #1 {B[0], C[(N - 1):1]};
            pLDNL   : C <= #1 {B[0], C[(N - 1):1]};
            
            pIN     : C <= #1 {B[0], C[(N - 1):1]};
            pINB    : C <= #1 {B[0], C[(N - 1):1]};
            
            pTWA    : C <= #1 {B[0], C[(N - 1):1]};
            
            pDUP    : C <= #1 {B[0], C[(N - 1):1]};
            pRAS    : C <= #1 {B[0], C[(N - 1):1]};

            default : C <= #1 {C[0], C[(N - 1):1]};
        endcase
end

//  Output Data Multiplexer

always @(*)
begin
    case(I)
        pSTL    : ALU_DO <= A[0];
        pSTNL   : ALU_DO <= A[0];

        pOUT    : ALU_DO <= A[0];
        pOUTB   : ALU_DO <= A[0];

        pTAW    : ALU_DO <= A[0];

        default : ALU_DO <= 0;
    endcase
end

assign DO = ((CE) ? ALU_DO : 1'bZ);

endmodule
