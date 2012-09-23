`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company:         M. A. Morris & Associates 
// Engineer:        Michael A. Morris
//
// Create Date:     19:02:54 08/17/2012
// Design Name:     MiniCPU_SerALU
// Module Name:     C:/XProjects/ISE10.1i/MiniCPU/tb_MiniCPU_SerALU.v
// Project Name:    MiniCPU
// Target Device:   CPLDs  
// Tool versions:   ISE10.1i SP3
//    
// Description: 
//
// Verilog Test Fixture created by ISE for module: MiniCPU_SerALU
//
// Dependencies:
// 
// Revision:
//
//  0.00    12H17   MAM     File Created
//
//  1.00    12H19   MAM     Adjusted the INB test to accomodate the change in
//                          the definition that zeros the upper byte instead of
//                          duplicating the input in both halves.
//
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module tb_MiniCPU_SerALU;

////////////////////////////////////////////////////////////////////////////////
//
//  Parameters
//

`include "MiniCPU_SerALU.txt"

////////////////////////////////////////////////////////////////////////////////
//
//  Declarations
//

reg     Rst;            // System Reset
reg     Clk;            // System Clock

reg     CE;             // Serial ALU Enable
reg     [4:0] I;        // Serial ALU Instruction Code
reg     DI;             // Serial ALU Data Input (MISO)
reg     [15:0] Op;      // Serial ALU Operand Register Input (LSB)
reg     [15:0] W;       // Serial ALU Workspace Pointer Input (LSB)
wire    DO;             // Serial ALU Output
wire    Z;              // Serial ALU Zero Flag
wire    N;              // Serial ALU Negative Flag 

wire    [48:0] TstPort; // Serial ALU Test Port

//  UUT Internal Signals

reg     [15:0] A, B, C;
reg     Cy;

//  Simulation Variables

integer j = 0;
reg     [5*8:0] IDec;
reg     [15:0] MISO, MOSI;

// Instantiate the Unit Under Test (UUT)

MiniCPU_SerALU  uut (
                    .Rst(Rst), 
                    .Clk(Clk), 
                    .CE(CE), 
                    .I(I), 
                    .DI(DI), 
                    .Op(Op[15]), 
                    .W(W[15]), 
                    .DO(DO),
                    .Zer(Z),
                    .Neg(N),
                    .TstPort(TstPort)
                );

initial begin
//  Initialize Inputs

    Rst  = 1;
    Clk  = 1;
    
    MISO = 0;
    MOSI = 0;
    Op   = 0;
    W    = 0;

    CE   = 0;
    I    = 0;
    DI   = MISO[0];
    Op   = 0;
    W    = 0;

//  Wait 100 ns for global reset to finish
    
    #101 Rst = 0;
    
//  Add stimulus here

    for(j = 0; j < 32; j = j + 1) begin
        @(posedge Clk) #1 I = j;
    end
    
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    
    // Test LDL instruction
    
    CE = 1; I = pLDL; MISO = 16'hF00F; Op = 16'hFFFF; W = 16'h8000;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[(15 - j)];
        @(posedge Clk) #1;
    end

    CE = 1; I = pLDL; MISO = 16'h0FF0; Op = 16'hFFFF; W = 16'h8000;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[(15 - j)];
        @(posedge Clk) #1;
    end

    CE = 1; I = pLDL; MISO = 16'hAAAA; Op = 16'hFFFF; W = 16'h8000;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[(15 - j)];
        @(posedge Clk) #1;
    end
    CE = 0; I = pHLT; MISO = 16'h0000; Op = 16'h0000; W = 16'h0000;
    
    #1;
    if(   (A  == 16'hAAAA)
       && (B  == 16'h0FF0)
       && (C  == 16'hF00F)
       && (Cy == 1'b0)
       && (Z  == 1'b0)
       && (N  == 1'b1))
        $display("LDL  - Passed\n");
    else begin
        $display("LDL  - Fail\n");
        $stop;
    end

    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;

    // Test XAB instruction

    CE = 1; I = pXAB; MISO = 16'h0000; Op = 16'h0000; W = 16'h0000;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[15];
        @(posedge Clk) #1;
    end
    CE = 0; I = pHLT; MISO = 16'h0000; Op = 16'h0000; W = 16'h0000;
    
    #1;
    if(   (A  == 16'h0FF0)
       && (B  == 16'hAAAA)
       && (C  == 16'hF00F)
       && (Cy == 1'b0)
       && (Z  == 1'b0)
       && (N  == 1'b0))
        $display("XAB  - Passed\n");
    else begin
        $display("XAB  - Fail\n");
        $stop;
    end

    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;

    // Test RAS instruction

    CE = 1; I = pRAS; MISO = 16'h0000; Op = 16'h0000; W = 16'h0000;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[15];
        @(posedge Clk) #1;
    end
    CE = 0; I = pHLT; MISO = 16'h0000; Op = 16'h0000; W = 16'h0000;
    
    #1;
    if(   (A  == 16'hAAAA)
       && (B  == 16'hF00F)
       && (C  == 16'h0FF0)
       && (Cy == 1'b0)
       && (Z  == 1'b0)
       && (N  == 1'b1))
        $display("RAS  - Passed\n");
    else begin
        $display("RAS  - Fail\n");
        $stop;
    end

    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;

    // Test STL instruction

    CE = 1; I = pSTL; MISO = 16'h0000; Op = 16'h0000; W = 16'h0000;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[15];
        @(posedge Clk) #1;
        MOSI[15 - j] = DO;
    end
    CE = 0; I = pHLT; MISO = 16'h0000; Op = 16'h0000; W = 16'h0000;
    
    #1;
    if(   (A    == 16'hF00F)
       && (B    == 16'h0FF0)
       && (C    == 16'h0FF0)
       && (Cy   == 1'b0)
       && (Z    == 1'b0)
       && (N    == 1'b1)
       && (MOSI == 16'hAAAA))
        $display("STL  - Passed\n");
    else begin
        $display("STL  - Fail\n");
        $stop;
    end

    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;

    // Test STNL instruction

    CE = 1; I = pSTNL; MISO = 16'h0000; Op = 16'h0000; W = 16'h0000;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[15];
        @(posedge Clk) #1;
        MOSI[15 - j] = DO;
    end
    CE = 0; I = pHLT; MISO = 16'h0000; Op = 16'h0000; W = 16'h0000;
    
    #1;
    if(   (A    == 16'h0FF0)
       && (B    == 16'h0FF0)
       && (C    == 16'h0FF0)
       && (Cy   == 1'b0)
       && (Z    == 1'b0)
       && (N    == 1'b0)
       && (MOSI == 16'hF00F))
        $display("STNL - Passed\n");
    else begin
        $display("STNL - Fail\n");
        $stop;
    end

    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;

    // Test LDNL instruction

    CE = 1; I = pLDNL; MISO = 16'h96A5; Op = 16'h0000; W = 16'h0000;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[15 - j];
        @(posedge Clk) #1;
        MOSI[15 - j] = DO;
    end
    CE = 0; I = pHLT; MISO = 16'h0000; Op = 16'h0000; W = 16'h0000;
    
    #1;
    if(   (A    == 16'h96A5)
       && (B    == 16'h0FF0)
       && (C    == 16'h0FF0)
       && (Cy   == 1'b0)
       && (Z    == 1'b0)
       && (N    == 1'b1)
       && (MOSI == 16'h0000))
        $display("LDNL - Passed\n");
    else begin
        $display("LDNL - Fail\n");
        $stop;
    end

    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;

    // Test LDK instruction

    CE = 1; I = pLDK; MISO = 16'h0000; Op = 16'h5A69; W = 16'h0000;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[15 - j];
        @(posedge Clk) #1;
        MOSI[15 - j] = DO;
        Op = (Op << 1);
    end
    CE = 0; I = pHLT; MISO = 16'h0000; Op = 16'h0000; W = 16'h0000;
    
    #1;
    if(   (A    == 16'h5A69)
       && (B    == 16'h96A5)
       && (C    == 16'h0FF0)
       && (Cy   == 1'b0)
       && (Z    == 1'b0)
       && (N    == 1'b0)
       && (MOSI == 16'h0000))
        $display("LDK  - Passed\n");
    else begin
        $display("LDK  - Fail\n");
        $stop;
    end

    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;

    // Test IN instruction

    CE = 1; I = pIN; MISO = 16'hA55A; Op = 16'h0000; W = 16'h0000;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[15 - j];
        @(posedge Clk) #1;
        MOSI[15 - j] = DO;
        Op = (Op << 1);
    end
    CE = 0; I = pHLT; MISO = 16'h0000; Op = 16'h0000; W = 16'h0000;
    
    #1;
    if(   (A    == 16'hA55A)
       && (B    == 16'h5A69)
       && (C    == 16'h96A5)
       && (Cy   == 1'b0)
       && (Z    == 1'b0)
       && (N    == 1'b1)
       && (MOSI == 16'h0000))
        $display("IN   - Passed\n");
    else begin
        $display("IN   - Fail\n");
        $stop;
    end

    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;

    // Test OUT instruction

    CE = 1; I = pOUT; MISO = 16'h0000; Op = 16'h0000; W = 16'h0000;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[15 - j];
        @(posedge Clk) #1;
        MOSI[15 - j] = DO;
        Op = (Op << 1);
    end
    CE = 0; I = pHLT; MISO = 16'h0000; Op = 16'h0000; W = 16'h0000;
    
    #1;
    if(   (A    == 16'h5A69)
       && (B    == 16'h96A5)
       && (C    == 16'h96A5)
       && (Cy   == 1'b0)
       && (Z    == 1'b0)
       && (N    == 1'b0)
       && (MOSI == 16'hA55A))
        $display("OUT  - Passed\n");
    else begin
        $display("OUT  - Fail\n");
        $stop;
    end

    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;

    // Test POP instruction

    CE = 1; I = pPOP; MISO = 16'h0000; Op = 16'h0000; W = 16'h0000;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[15 - j];
        @(posedge Clk) #1;
        MOSI[15 - j] = DO;
        Op = (Op << 1);
    end
    CE = 0; I = pHLT; MISO = 16'h0000; Op = 16'h0000; W = 16'h0000;
    
    #1;
    if(   (A    == 16'h96A5)
       && (B    == 16'h96A5)
       && (C    == 16'h96A5)
       && (Cy   == 1'b0)
       && (Z    == 1'b0)
       && (N    == 1'b1)
       && (MOSI == 16'h0000))
        $display("POP  - Passed\n");
    else begin
        $display("POP  - Fail\n");
        $stop;
    end

    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;

    // Test TAW instruction

    CE = 1; I = pTAW; MISO = 16'h0000; Op = 16'h0000; W = 16'h0000;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[15 - j];
        @(posedge Clk) #1;
        MOSI[15 - j] = DO;
        Op = (Op << 1);
    end
    CE = 0; I = pHLT; MISO = 16'h0000; Op = 16'h0000; W = 16'h0000;
    
    #1;
    if(   (A    == 16'h96A5)
       && (B    == 16'h96A5)
       && (C    == 16'h96A5)
       && (Cy   == 1'b0)
       && (Z    == 1'b0)
       && (N    == 1'b1)
       && (MOSI == 16'h96A5))
        $display("TAW  - Passed\n");
    else begin
        $display("TAW  - Fail\n");
        $stop;
    end

    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;

    // Test TWA instruction

    CE = 1; I = pTWA; MISO = 16'hFFFF; Op = 16'hFFFF; W = 16'h0000;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[15 - j];
        @(posedge Clk) #1;
        MOSI[15 - j] = DO;
        Op = (Op << 1);
        W  = (W  << 1);
    end
    CE = 0; I = pHLT; MISO = 16'h0000; Op = 16'h0000; W = 16'h0000;
    
    #1;
    if(   (A    == 16'h0000)
       && (B    == 16'h96A5)
       && (C    == 16'h96A5)
       && (Cy   == 1'b0)
       && (Z    == 1'b1)
       && (N    == 1'b0)
       && (MOSI == 16'h0000))
        $display("TWA  - Passed\n");
    else begin
        $display("TWA  - Fail\n");
        $stop;
    end

    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;

    // Test DUP instruction

    CE = 1; I = pDUP; MISO = 16'hFFFF; Op = 16'hFFFF; W = 16'hFFFF;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[15 - j];
        @(posedge Clk) #1;
        MOSI[15 - j] = DO;
        Op = (Op << 1);
        W  = (W  << 1);
    end
    
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[15 - j];
        @(posedge Clk) #1;
        MOSI[15 - j] = DO;
        Op = (Op << 1);
        W  = (W  << 1);
    end
    CE = 0; I = pHLT; MISO = 16'h0000; Op = 16'h0000; W = 16'h0000;
    
    #1;
    if(   (A    == 16'h0000)
       && (B    == 16'h0000)
       && (C    == 16'h0000)
       && (Cy   == 1'b0)
       && (Z    == 1'b1)
       && (N    == 1'b0)
       && (MOSI == 16'h0000))
        $display("DUP  - Passed\n");
    else begin
        $display("DUP  - Fail\n");
        $stop;
    end

    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;

    // Test INB instruction

    CE = 1; I = pINB; MISO = 16'hC300; Op = 16'hFFFF; W = 16'h0000;
    for(j = 0; j < 8; j = j + 1) begin
        DI = MISO[15 - j];
        @(posedge Clk) #1;
        MOSI[15 - j] = DO;
        Op = (Op << 1);
        W  = (W  << 1);
    end
    CE = 0; I = pHLT; MISO = 16'h0000; Op = 16'h0000; W = 16'h0000;
    
    #1;
    if(   (A    == 16'h00C3)
       && (B    == 16'h0000)
       && (C    == 16'h0000)
       && (Cy   == 1'b0)
       && (Z    == 1'b0)
       && (N    == 1'b0)
       && (MOSI == 16'h0000))
        $display("INB  - Passed\n");
    else begin
        $display("INB  - Fail\n");
        $stop;
    end

    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;

    // Test OUTB instruction

    CE = 1; I = pOUTB; MISO = 16'hFFFF; Op = 16'hFFFF; W = 0; MOSI = 16'hFFFF;
    for(j = 0; j < 8; j = j + 1) begin
        DI = MISO[15 - j];
        @(posedge Clk) #1;
        MOSI[15 - j] = DO;
        Op = (Op << 1);
        W  = (W  << 1);
    end
    CE = 0; I = pHLT; MISO = 16'h0000; Op = 16'h0000; W = 16'h0000;
    
    #1;
    if(   (A    == 16'h0000)
       && (B    == 16'h0000)
       && (C    == 16'h0000)
       && (Cy   == 1'b0)
       && (Z    == 1'b1)
       && (N    == 1'b0)
       && (MOSI == 16'hC3FF))
        $display("OUTB - Passed\n");
    else begin
        $display("OUTB - Fail\n");
        $stop;
    end

    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;

    // Test Default Operation of Serial ALU
    //      CALL, NFX, PFX, BEQ, BLT, JMP, HLT

    CE = 1; I = pLDL; MISO = 16'hFF00; Op = 16'hFFFF; W = 16'h8000;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[(15 - j)];
        @(posedge Clk) #1;
    end
    CE = 1; I = pLDL; MISO = 16'h0FF0; Op = 16'hFFFF; W = 16'h8000;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[(15 - j)];
        @(posedge Clk) #1;
    end
    CE = 1; I = pLDL; MISO = 16'h00FF; Op = 16'hFFFF; W = 16'h8000;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[(15 - j)];
        @(posedge Clk) #1;
    end

    CE = 1; I = pCALL; MISO = 16'hFFFF; Op = 16'hFFFF; W = 0; MOSI = 16'hFFFF;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[15 - j];
        @(posedge Clk) #1;
        MOSI[15 - j] = DO;
        Op = (Op << 1);
        W  = (W  << 1);
    end
    CE = 1; I = pNFX; MISO = 16'hFFFF; Op = 16'hFFFF; W = 0; MOSI = 16'hFFFF;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[15 - j];
        @(posedge Clk) #1;
        MOSI[15 - j] = DO;
        Op = (Op << 1);
        W  = (W  << 1);
    end
    CE = 1; I = pPFX; MISO = 16'hFFFF; Op = 16'hFFFF; W = 0; MOSI = 16'hFFFF;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[15 - j];
        @(posedge Clk) #1;
        MOSI[15 - j] = DO;
        Op = (Op << 1);
        W  = (W  << 1);
    end
    CE = 1; I = pBEQ; MISO = 16'hFFFF; Op = 16'hFFFF; W = 0; MOSI = 16'hFFFF;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[15 - j];
        @(posedge Clk) #1;
        MOSI[15 - j] = DO;
        Op = (Op << 1);
        W  = (W  << 1);
    end
    CE = 1; I = pBLT; MISO = 16'hFFFF; Op = 16'hFFFF; W = 0; MOSI = 16'hFFFF;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[15 - j];
        @(posedge Clk) #1;
        MOSI[15 - j] = DO;
        Op = (Op << 1);
        W  = (W  << 1);
    end
    CE = 1; I = pJMP; MISO = 16'hFFFF; Op = 16'hFFFF; W = 0; MOSI = 16'hFFFF;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[15 - j];
        @(posedge Clk) #1;
        MOSI[15 - j] = DO;
        Op = (Op << 1);
        W  = (W  << 1);
    end
    CE = 1; I = pHLT; MISO = 16'hFFFF; Op = 16'hFFFF; W = 0; MOSI = 16'hFFFF;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[15 - j];
        @(posedge Clk) #1;
        MOSI[15 - j] = DO;
        Op = (Op << 1);
        W  = (W  << 1);
    end
    CE = 0; I = pHLT; MISO = 16'h0000; Op = 16'h0000; W = 16'h0000;
    
    #1;
    if(   (A    == 16'h00FF)
       && (B    == 16'h0FF0)
       && (C    == 16'hFF00)
       && (Cy   == 1'b0)
       && (Z    == 1'b0)
       && (N    == 1'b0)
       && (MOSI == 16'h0000)) begin
        $display("Default Operation Instructions - Passed\n");
        $display("    CALL, NFX, PFX, BEQ, BLT, JMP, HLT\n");
    end else begin
        $display("Default Operation Instructions - Fail\n");
        $stop;
    end

    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    
    //  Test SEC Instruction

    CE = 1; I = pSEC; MISO = 16'hFFFF; Op = 16'hFFFF; W = 0; MOSI = 16'hFFFF;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[15 - j];
        @(posedge Clk) #1;
        MOSI[15 - j] = DO;
        Op = (Op << 1);
        W  = (W  << 1);
    end
    CE = 0; I = pHLT; MISO = 16'h0000; Op = 16'h0000; W = 16'h0000;
    
    #1;
    if(   (A    == 16'h00FF)
       && (B    == 16'h0FF0)
       && (C    == 16'hFF00)
       && (Cy   == 1'b1)
       && (Z    == 1'b0)
       && (N    == 1'b0)
       && (MOSI == 16'h0000))
        $display("SEC  - Passed\n");
    else begin
        $display("SEC  - Fail\n");
        $stop;
    end

    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;

    //  Test CLC Instruction

    CE = 1; I = pCLC; MISO = 16'hFFFF; Op = 16'hFFFF; W = 0; MOSI = 16'hFFFF;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[15 - j];
        @(posedge Clk) #1;
        MOSI[15 - j] = DO;
        Op = (Op << 1);
        W  = (W  << 1);
    end
    CE = 0; I = pHLT; MISO = 16'h0000; Op = 16'h0000; W = 16'h0000;
    
    #1;
    if(   (A    == 16'h00FF)
       && (B    == 16'h0FF0)
       && (C    == 16'hFF00)
       && (Cy   == 1'b0)
       && (Z    == 1'b0)
       && (N    == 1'b0)
       && (MOSI == 16'h0000))
        $display("CLC  - Passed\n");
    else begin
        $display("CLC  - Fail\n");
        $stop;
    end

    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;

    //  Test ROR Instruction

    CE = 1; I = pROR; MISO = 16'hFFFF; Op = 16'hFFFF; W = 0; MOSI = 16'hFFFF;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[15 - j];
        @(posedge Clk) #1;
        MOSI[15 - j] = DO;
        Op = (Op << 1);
        W  = (W  << 1);
    end
    CE = 0; I = pHLT; MISO = 16'h0000; Op = 16'h0000; W = 16'h0000;
    
    #1;
    if(   (A    == 16'hFF00)
       && (B    == 16'hFF00)
       && (C    == 16'hFF00)
       && (Cy   == 1'b1)
       && (Z    == 1'b0)
       && (N    == 1'b1)
       && (MOSI == 16'h0000))
        $display("ROR  - Passed\n");
    else begin
        $display("ROR  - Fail\n");
        $stop;
    end

    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;

    //  Test ROL Instruction

    CE = 1; I = pLDL; MISO = 16'h000F; Op = 16'hFFFF; W = 0; MOSI = 16'hFFFF;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[15 - j];
        @(posedge Clk) #1;
        MOSI[15 - j] = DO;
        Op = (Op << 1);
        W  = (W  << 1);
    end
    CE = 1; I = pLDL; MISO = 16'hA596; Op = 16'hFFFF; W = 0; MOSI = 16'hFFFF;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[15 - j];
        @(posedge Clk) #1;
        MOSI[15 - j] = DO;
        Op = (Op << 1);
        W  = (W  << 1);
    end
    CE = 1; I = pROL; MISO = 16'hFFFF; Op = 16'hFFFF; W = 0; MOSI = 16'hFFFF;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[15 - j];
        @(posedge Clk) #1;
        MOSI[15 - j] = DO;
        Op = (Op << 1);
        W  = (W  << 1);
    end
    CE = 0; I = pHLT; MISO = 16'h0000; Op = 16'h0000; W = 16'h0000;
    
    #1;
    if(   (A    == 16'h596A)
       && (B    == 16'hFF00)
       && (C    == 16'hFF00)
       && (Cy   == 1'b0)
       && (Z    == 1'b0)
       && (N    == 1'b0)
       && (MOSI == 16'h0000))
        $display("ROL  - Passed\n");
    else begin
        $display("ROL  - Fail\n");
        $stop;
    end

    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;

    //  Test ADC Instruction

    CE = 1; I = pLDL; MISO = 16'hA695; Op = 16'hFFFF; W = 0; MOSI = 16'hFFFF;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[15 - j];
        @(posedge Clk) #1;
        MOSI[15 - j] = DO;
        Op = (Op << 1);
        W  = (W  << 1);
    end
    CE = 1; I = pADC; MISO = 16'hFFFF; Op = 16'hFFFF; W = 0; MOSI = 16'hFFFF;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[15 - j];
        @(posedge Clk) #1;
        MOSI[15 - j] = DO;
        Op = (Op << 1);
        W  = (W  << 1);
    end
    CE = 0; I = pHLT; MISO = 16'h0000; Op = 16'h0000; W = 16'h0000;
    
    #1;
    if(   (A    == 16'hFFFF)
       && (B    == 16'hFF00)
       && (C    == 16'hFF00)
       && (Cy   == 1'b0)
       && (Z    == 1'b0)
       && (N    == 1'b1)
       && (MOSI == 16'h0000))
        $display("ADC  - Passed\n");
    else begin
        $display("ADC  - Fail\n");
        $stop;
    end

    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;

    //  Test SBC Instruction

    CE = 1; I = pSEC; MISO = 16'h0000; Op = 16'h0000; W = 0; MOSI = 16'h0000;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[15 - j];
        @(posedge Clk) #1;
        MOSI[15 - j] = DO;
        Op = (Op << 1);
        W  = (W  << 1);
    end
    CE = 1; I = pSBC; MISO = 16'h0000; Op = 16'h0000; W = 0; MOSI = 16'h0000;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[15 - j];
        @(posedge Clk) #1;
        MOSI[15 - j] = DO;
        Op = (Op << 1);
        W  = (W  << 1);
    end
    CE = 1; I = pSEC; MISO = 16'h0000; Op = 16'h0000; W = 0; MOSI = 16'h0000;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[15 - j];
        @(posedge Clk) #1;
        MOSI[15 - j] = DO;
        Op = (Op << 1);
        W  = (W  << 1);
    end
    CE = 1; I = pSBC; MISO = 16'h0000; Op = 16'h0000; W = 0; MOSI = 16'h0000;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[15 - j];
        @(posedge Clk) #1;
        MOSI[15 - j] = DO;
        Op = (Op << 1);
        W  = (W  << 1);
    end
    CE = 0; I = pHLT; MISO = 16'h0000; Op = 16'h0000; W = 16'h0000;
    
    #1;
    if(   (A    == 16'hFFFF)
       && (B    == 16'hFF00)
       && (C    == 16'hFF00)
       && (Cy   == 1'b0)
       && (Z    == 1'b0)
       && (N    == 1'b1)
       && (MOSI == 16'h0000))
        $display("SBC  - Passed\n");
    else begin
        $display("SBC  - Fail\n");
        $stop;
    end

    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;

    //  Test Logic Instructions

    CE = 1; I = pRAS; MISO = 16'h0000; Op = 16'h0000; W = 0; MOSI = 16'h0000;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[15 - j];
        @(posedge Clk) #1;
        MOSI[15 - j] = DO;
        Op = (Op << 1);
        W  = (W  << 1);
    end
    CE = 1; I = pPOP; MISO = 16'h0000; Op = 16'h0000; W = 0; MOSI = 16'h0000;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[15 - j];
        @(posedge Clk) #1;
        MOSI[15 - j] = DO;
        Op = (Op << 1);
        W  = (W  << 1);
    end
    CE = 1; I = pPOP; MISO = 16'h0000; Op = 16'h0000; W = 0; MOSI = 16'h0000;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[15 - j];
        @(posedge Clk) #1;
        MOSI[15 - j] = DO;
        Op = (Op << 1);
        W  = (W  << 1);
    end
    CE = 1; I = pLDL; MISO = 16'hAAAA; Op = 16'h0000; W = 0; MOSI = 16'h0000;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[15 - j];
        @(posedge Clk) #1;
        MOSI[15 - j] = DO;
        Op = (Op << 1);
        W  = (W  << 1);
    end
    CE = 1; I = pAND; MISO = 16'h0000; Op = 16'h0000; W = 0; MOSI = 16'h0000;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[15 - j];
        @(posedge Clk) #1;
        MOSI[15 - j] = DO;
        Op = (Op << 1);
        W  = (W  << 1);
    end
    CE = 1; I = pLDK; MISO = 16'h0000; Op = 16'h5555; W = 0; MOSI = 16'h0000;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[15 - j];
        @(posedge Clk) #1;
        MOSI[15 - j] = DO;
        Op = (Op << 1);
        W  = (W  << 1);
    end
    CE = 1; I = pORL; MISO = 16'h0000; Op = 16'h0000; W = 0; MOSI = 16'h0000;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[15 - j];
        @(posedge Clk) #1;
        MOSI[15 - j] = DO;
        Op = (Op << 1);
        W  = (W  << 1);
    end
    CE = 1; I = pXOR; MISO = 16'h0000; Op = 16'h0000; W = 0; MOSI = 16'h0000;
    for(j = 0; j < 16; j = j + 1) begin
        DI = MISO[15 - j];
        @(posedge Clk) #1;
        MOSI[15 - j] = DO;
        Op = (Op << 1);
        W  = (W  << 1);
    end
    CE = 0; I = pHLT; MISO = 16'h0000; Op = 16'h0000; W = 16'h0000;
    
    #1;
    if(   (A    == 16'h0000)
       && (B    == 16'hFFFF)
       && (C    == 16'hFFFF)
       && (Cy   == 1'b0)
       && (Z    == 1'b1)
       && (N    == 1'b0)
       && (MOSI == 16'h0000))
        $display("Logic Unit Test - Passed\n");
    else begin
        $display("Logic Unit Test - Fail\n");
        $stop;
    end

    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;

//  End of Simulation

    $stop;
end

////////////////////////////////////////////////////////////////////////////////
//
//  Clocks
//

always #5 Clk = ~Clk;

////////////////////////////////////////////////////////////////////////////////
//
//  Simulation Elements
//

always @(*) // UUT Test Port Assignments
begin
    Cy = TstPort[48];
    A  = TstPort[47:32];
    B  = TstPort[31:16];
    C  = TstPort[15: 0];
end

always @(*) // Instruction Mnemonics Decode
begin
    case(I)
        5'b0_0000   : IDec = "PFX ";
        5'b0_0001   : IDec = "NFX ";
        5'b0_0010   : IDec = "----";
        5'b0_0011   : IDec = "LDK ";
        5'b0_0100   : IDec = "LDL ";
        5'b0_0101   : IDec = "LDNL";
        5'b0_0110   : IDec = "STL ";
        5'b0_0111   : IDec = "STNL";
        5'b0_1000   : IDec = "IN  ";
        5'b0_1001   : IDec = "INB ";
        5'b0_1010   : IDec = "OUT ";
        5'b0_1011   : IDec = "OUTB";
        5'b0_1100   : IDec = "BEQ ";
        5'b0_1101   : IDec = "BLT ";
        5'b0_1110   : IDec = "JMP ";
        5'b0_1111   : IDec = "CALL";
        5'b1_0000   : IDec = "CLC ";
        5'b1_0001   : IDec = "SEC ";
        5'b1_0010   : IDec = "TAW ";
        5'b1_0011   : IDec = "TWA ";
        5'b1_0100   : IDec = "DUP ";
        5'b1_0101   : IDec = "XAB "; 
        5'b1_0110   : IDec = "POP ";
        5'b1_0111   : IDec = "RAS ";
        5'b1_1000   : IDec = "ROR ";
        5'b1_1001   : IDec = "ROL ";
        5'b1_1010   : IDec = "ADC ";
        5'b1_1011   : IDec = "SBC ";
        5'b1_1100   : IDec = "AND ";
        5'b1_1101   : IDec = "ORL ";
        5'b1_1110   : IDec = "XOR ";
        5'b1_1111   : IDec = "HALT"; 
    endcase
end      

////////////////////////////////////////////////////////////////////////////////
//
//  Tasks and Functions
//


endmodule

