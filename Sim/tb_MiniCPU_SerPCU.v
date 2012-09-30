`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company:         M. A. Morris & Associates
// Engineer:        Michael A. Morris
//
// Create Date:     08:43:57 09/29/2012
// Design Name:     Minimal CPU Implementation for CPLD with SPI Interface
// Module Name:     C:/XProjects/ISE10.1i/MiniCPU/tb_MiniCPU_SerPCU.v
// Project Name:    C:/XProjects/ISE10.1i/MiniCPU
// Target Device:   CPLDs  
// Tool versions:   ISE 10.1i SP3
//
// Description: 
//
// Verilog Test Fixture created by ISE for module: MiniCPU_SerPCU
//
// Dependencies:
// 
// Revision:
//
//  0.00    12I29   MAM     File Created
//
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module tb_MiniCPU_SerPCU;

`include "Src\MiniCPU_SerPCU.txt"

// Inputs

reg     Rst;                // System reset
reg     Clk;                // System clock

reg     IP_En;              // Instruction pointer enable
reg     [1:0] IP_Op;        // Instruction pointer operation select
reg     W_En;               // Workspace pointer register enable
reg     [1:0] W_Op;         // Workspace pointer register operation select
reg     Op_En;              // Operand Register enable
reg     [1:0] Op_Op;        // Operand Register operation select

reg     PCU_Inc;            // Suppresses Ci on first cycle of arithmetic ops
reg     Op_Inv;             // Complements Op if set on last cycle of NFX

reg     PCU_DI;             // Input from the Execution Unit (EU) 
reg     ALU_DI;             // Input from the Serial ALU (ALU_DO)

// Outputs

wire    PCU_DO;             // Output from PCU

//  Debug Test Port

wire    [15:0] IP, W, Op;   // Internal PCU registers brought out on test port

// Instantiate the Unit Under Test (UUT)

MiniCPU_SerPCU  uut (
                    .Rst(Rst), 
                    .Clk(Clk), 
                    .IP_En(IP_En), 
                    .IP_Op(IP_Op), 
                    .W_En(W_En), 
                    .W_Op(W_Op), 
                    .Op_En(Op_En), 
                    .Op_Op(Op_Op), 
                    .PCU_Inc(PCU_Inc), 
                    .Op_Inv(Op_Inv), 
                    .PCU_DI(PCU_DI), 
                    .ALU_DI(ALU_DI), 
                    .PCU_DO(PCU_DO),
                    .TstPort({IP, W, Op})
                );

initial begin
    // Initialize Inputs
    Rst     = 1;
    Clk     = 1;

    IP_En   = 0;
    IP_Op   = 0;
    W_En    = 0;
    W_Op    = 0;
    Op_En   = 0;
    Op_Op   = 0;

    PCU_Inc = 0;
    Op_Inv  = 0;

    PCU_DI  = 0;
    ALU_DI  = 0;

    // Wait 100 ns for global reset to finish
    
    #101 Rst = 0;
    
    // Add stimulus here
    
    //  Increment IP
    
    @(posedge Clk) #1 Tst_Increment_IP(IP + 1); // Increment IP: 16'h0001
    @(posedge Clk) #1 Tst_Increment_IP(IP + 1); // Increment IP: 16'h0002
    
    //  Shift Input into Op
    
    @(posedge Clk) #1 Tst_Op_Shift_In(1, 4'hF, 16'hFFF0);   // NFX 15
    @(posedge Clk) #1 Tst_Op_Shift_In(0, 4'h5, 16'hFF05);   // PFX 5
    @(posedge Clk) #1 Tst_Op_Shift_In(1, 4'h0, 16'h0FAF);   // NFX 0

    // Stop Simulation

    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    
    $stop;
end

////////////////////////////////////////////////////////////////////////////////
//
//  Clocks
//

always #5 Clk = ~Clk;

////////////////////////////////////////////////////////////////////////////////
//
//  Simulation Tasks
//

//
//  Test IP Increments
//
//      Expectation is that the EU will increment IP while an instruction is
//      being fetched. Thus, the IP <= IP + 1 operation is simultaneous with the
//      Op input shift operation tested by the Tst_Op_Shift_In task.
//
//      The EU enables the 

task Tst_Increment_IP;
    input [15:0] ExpVal;

begin
    IP_En = 1; IP_Op = pIP_Plus_1; PCU_Inc = 1;
    @(posedge Clk) #1 PCU_Inc = 0;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    IP_En = 0; IP_Op = pIP_Out;

    #1 if(IP == ExpVal) begin
        $display("\tIP Increment Test - Pass\n");
    end else begin
        $display("\tIP Increment Test - Fail: Expected %h, found %h\n", 
                 ExpVal, IP);
        @(posedge Clk) #1;
        @(posedge Clk) #1;
        @(posedge Clk) #1;
        @(posedge Clk) #1;
        $stop;               // Stop Simulation
    end
end

endtask

//
//  Test Operand Register Input Shifts
//
//      Expectation is that the EU asserts Op_En gated by the SPI sample enable.
//      The EU is also expected to gate Op_Inv with the SPI sample enable on the
//      last cycle of the 8-bit instruction fetch: the last 4 bits are Op[3:0].
//      Since this is a shift cycle and not an arithmetic cycle, PCU_Inc, is not
//      asserted by this task.
//
//      The input Inv selects whether the shift is a due to an NFX, PFX, or
//      direct instructon. If Inv is asserted, then Op_Inv is asserted during
//      the last shift cycle as if an NFX instruction was detected by the EU.
//
//      The testbench provides a 4-bit data value for the input shift data, and
//      it also provides the expected value of Op at the end of the shift cycle.
//
//      The task shifts the data and compares the value of Op with the expected
//      value provided. If the values match, the shift cycle passes and the 
//      test bench is allowed to proceed to the next step. Otherwise, the cycle
//      is a failure, and the task stops the simulation.

task Tst_Op_Shift_In;
    input Inv;              // 0 - PFX; 1 - NFX;
    input [ 3:0] Data;      // Data to shift into 
    input [15:0] ExpVal;    // Expected Value of Op after shift cycle completes
    
begin
    // #0
    @(posedge Clk) #1 Op_En  = 0;
                      Op_Op  = pOp_In;
                      Op_Inv = 0;
                      PCU_DI = 0;
    @(posedge Clk) #1;
    // #1
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    // #2    
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    // #3
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    // #4
    @(posedge Clk) #1 Op_En = 1; PCU_DI = Data[3];
    @(posedge Clk) #1 Op_En = 0;
    // #5
    @(posedge Clk) #1 Op_En = 1; PCU_DI = Data[2];
    @(posedge Clk) #1 Op_En = 0;
    // #6
    @(posedge Clk) #1 Op_En = 1; PCU_DI = Data[1];
    @(posedge Clk) #1 Op_En = 0;
    // #7
    @(posedge Clk) #1 Op_En = 1; PCU_DI = Data[0]; Op_Inv = Inv;
    @(posedge Clk) #1 Op_En = 0; Op_Inv = 0;
    
    @(posedge Clk) #1 Op_Op = 0; PCU_DI = 0;
    
    #1 if(Op == ExpVal) begin
        $display("\tOp Shift Test - Pass\n");
    end else begin
        $display("\tOp Shift Test - Fail: Expected %h, found %h\n", ExpVal, Op);
        @(posedge Clk) #1;
        @(posedge Clk) #1;
        @(posedge Clk) #1;
        @(posedge Clk) #1;
        $stop;               // Stop Simulation
    end
end

endtask
    
////////////////////////////////////////////////////////////////////////////////
      
endmodule

