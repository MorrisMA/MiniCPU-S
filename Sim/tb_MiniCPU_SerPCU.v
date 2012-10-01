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
reg     [1:0] PCU_OE;       // Output select for PCU_DO

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
                    .Op_Inv(Op_Inv),
                    .PCU_Inc(PCU_Inc), 
                    .PCU_OE(PCU_OE),
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
    PCU_OE  = 0;

    PCU_DI  = 0;
    ALU_DI  = 0;

    // Wait 100 ns for global reset to finish
    
    #101 Rst = 0;
    
    // Add stimulus here
    
    //  IP_Plus_1 Test
    //
    //      This operation is being tested independently of the Op_In shift
    //      operation which is tested next. The IP is incremented by the EU 
    //      during each instruction fetch.
    //
    
    $display("Testing IP_Plus_1\n");
    
    Tst_IP_Plus_1(IP + 1);          // Increment IP: 16'h0001
    Tst_IP_Plus_1(IP + 1);          // Increment IP: 16'h0002
    
    //  Op_In Test
    //
    //      This operation is being tested independently of the IP_Plus_1
    //      operation which was previously tested. The Op is loaded with the
    //      four LSBs of every instruction fetched from memory. 
    
    $display("Testing Op_In\n");
    
    Tst_Op_In(1, 4'hF, 16'hFFF0);   // NFX 15
    Tst_Op_In(0, 4'h5, 16'hFF05);   // PFX 5
    Tst_Op_In(1, 4'h0, 16'h0FAF);   // NFX 0
    
    // Reset Registers
    
    $display("Reset PCU registers\n");
    
    Rst = 1; @(posedge Clk) #1 Rst = 0;
    
    //  Simultaneous IP_Plus_1 and Op_In Test
    //
    //      These two operations are performed simultaneously in the MiniCPU-S
    //      whenever an instruction is being fetched. The SPI MISO data is read
    //      into the EU's IR and into the Op during the last 4 cycles of the
    //      fetch. Simultaneously, the EU increments the IP in order to have
    //      the IP accurately reflect the state of the internal address counter
    //      in the memory device being read.
    //
    
    $display("Testing simultaneous operations: IP_Plus_1, Op_In\n");
    
    #0.01 fork
        Tst_IP_Plus_1(IP + 1);
        Tst_Op_In(1, 4'b0, 16'hFFFF);
    join
    
    //  Simultaneous IP_Plus_Op and Op_Out
    //
    //      This operation is performed by the EU whenever a program branch is
    //      taken. The operation is performed during the transmission of the
    //      new SPI read command to the instruction memory. The adjusted IP is
    //      then available as the address to send to the memory.
    
    $display("Testing simultaneous operations: IP_Plus_Op, Op_Out\n");
    
    #0.01 fork
        Tst_IP_Plus_Op(IP + Op);    // IP' = Op' = 0, since IP = 1, OP = -1
        Tst_Op_Out(1, 0);           // Test Op_Out for IP_Plus_Op
    join

    Tst_IP_Plus_1(IP + 1);
    #0.01 fork
        Tst_IP_Plus_1(IP + 1);
        Tst_Op_In(1, 4'b1, 16'hFFFE);
    join

    #0.01 fork
        Tst_IP_Plus_Op(IP + Op);    // IP' = Op' = 0, since IP = 1, OP = -1
        Tst_Op_Out(1, 0);           // Test Op_Out for IP_Plus_Op
    join
    
    //  Test IP_In operation
    
    $display("Testing IP_In\n");
    
    Tst_IP_In(16'h5AA5);
    Tst_IP_In(16'hFFFF);
    Tst_IP_Plus_1(IP + 1);

    //  Test IP_In operation
    
    $display("Testing IP_Out\n");
    
    Tst_IP_In(16'h5555);
    Tst_IP_Out(IP);
    Tst_IP_Plus_1(IP + 1);
    Tst_IP_Out(IP);

    //  Test Op_Plus_A operation
    
    $display("Testing Op_Plus_A\n");
    
    Tst_Op_Plus_A(16'hFFFF, Op + 16'hFFFF);

    //  Test Op_Out operation
    
    $display("Testing Op_Out - Non-Local Address Output\n");
    
    Tst_Op_Out(1, 0);

    // Stop Simulation
    
    $display("Tests Complete - Pass\n");

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

//------------------------------------------------------------------------------
//
//  IP Operations
//

function [((11 * 8) - 1):0] IP_Str;
    input [1:0] IP_Op;
    
begin
    case(IP_Op)
        pIP_Out     : IP_Str = "IP_Out    ";
        pIP_In      : IP_Str = "IP_In     ";
        pIP_Plus_1  : IP_Str = "IP_Plus_1 ";
        pIP_Plus_Op : IP_Str = "IP_Plus_Op";
        default     : IP_Str = "----------";
    endcase
end

endfunction

//  Test IP_Out
//
//      Expectation is that the EU will write to the return address from the IP
//      to the workspace as a 16-bit value. Like IP_In, the IP_En is gated by
//      the SPI shift clock enable, but on the opposite clock phase. The IP_Out
//      shift is a circular shift. Thus, at the end of the 16 shifts (32 clock
//      cycles), the IP is the same as it was at the start.
//
//      IP_Out is used during the data output phase of a SPI write cycle to the
//      data memory. It follows the decrement (-2) of W during the write command
//      cycle, and the output of W during the write address cycle.

task Tst_IP_Out;
    input [15:0] ExpVal;

begin
    // Bit #15
    @(posedge Clk) #1 IP_En = 0; IP_Op = pIP_Out; PCU_OE = pOE_IP;
    @(posedge Clk) #1 IP_En = 1; 
    // Bit #14
    @(posedge Clk) #1 IP_En = 0;
    @(posedge Clk) #1 IP_En = 1; 
    // Bit #13   
    @(posedge Clk) #1 IP_En = 0;
    @(posedge Clk) #1 IP_En = 1; 
    // Bit #12
    @(posedge Clk) #1 IP_En = 0;
    @(posedge Clk) #1 IP_En = 1; 
    // Bit #11
    @(posedge Clk) #1 IP_En = 0;
    @(posedge Clk) #1 IP_En = 1; 
    // Bit #10
    @(posedge Clk) #1 IP_En = 0;
    @(posedge Clk) #1 IP_En = 1; 
    // Bit #9
    @(posedge Clk) #1 IP_En = 0;
    @(posedge Clk) #1 IP_En = 1; 
    // Bit #8
    @(posedge Clk) #1 IP_En = 0;
    @(posedge Clk) #1 IP_En = 1; 
    // Bit #7
    @(posedge Clk) #1 IP_En = 0;
    @(posedge Clk) #1 IP_En = 1; 
    // Bit #6
    @(posedge Clk) #1 IP_En = 0;
    @(posedge Clk) #1 IP_En = 1; 
    // Bit #5    
    @(posedge Clk) #1 IP_En = 0;
    @(posedge Clk) #1 IP_En = 1; 
    // Bit #4
    @(posedge Clk) #1 IP_En = 0;
    @(posedge Clk) #1 IP_En = 1; 
    // Bit #3
    @(posedge Clk) #1 IP_En = 0;
    @(posedge Clk) #1 IP_En = 1; 
    // Bit #2
    @(posedge Clk) #1 IP_En = 0;
    @(posedge Clk) #1 IP_En = 1; 
    // Bit #1
    @(posedge Clk) #1 IP_En = 0;
    @(posedge Clk) #1 IP_En = 1; 
    // Bit #0
    @(posedge Clk) #1 IP_En = 0;
    @(posedge Clk) #1 IP_En = 1; 

    @(posedge Clk) #1 IP_En = 0; IP_Op = 0; PCU_OE = 0;

    #1 if(IP == ExpVal) begin
        $display("\tTest IP_Out - Pass\n");
    end else begin
        $display("\tTest IP_Out - Fail: Expected %h, found %h\n", ExpVal, IP);
        @(posedge Clk) #1;
        @(posedge Clk) #1;
        @(posedge Clk) #1;
        @(posedge Clk) #1;
        $stop;               // Stop Simulation
    end
end

endtask

//  Test IP_In
//
//      Expectation is that the EU will read the return address from the
//      workspace as a 16-bit value. In this case, IP_En is gated by the SPI
//      shift clock enable. Thus, a total of 32 cycles are required to read in
//      the data.
//
//      The task shifts out the input data in 32 clock cycles and then verifies
//      that IP equals the data provide. (While IP_In is being performed by the
//      PCU's IP logic using PCU_DI, the PCU's W logic is incrementing W twice
//      in the same interval to remove the offset put in during the push of the
//      return address during the CALL instruction.)

task Tst_IP_In;
    input [15:0] Data;
    
begin
    // Bit #15
    @(posedge Clk) #1 IP_En = 1; IP_Op = pIP_In; PCU_DI = Data[15];
    @(posedge Clk) #1 IP_En = 0; 
    // Bit #14
    @(posedge Clk) #1 IP_En = 1; IP_Op = pIP_In; PCU_DI = Data[14];
    @(posedge Clk) #1 IP_En = 0; 
    // Bit #13
    @(posedge Clk) #1 IP_En = 1; IP_Op = pIP_In; PCU_DI = Data[13];
    @(posedge Clk) #1 IP_En = 0; 
    // Bit #12
    @(posedge Clk) #1 IP_En = 1; IP_Op = pIP_In; PCU_DI = Data[12];
    @(posedge Clk) #1 IP_En = 0; 
    // Bit #11
    @(posedge Clk) #1 IP_En = 1; IP_Op = pIP_In; PCU_DI = Data[11];
    @(posedge Clk) #1 IP_En = 0; 
    // Bit #10
    @(posedge Clk) #1 IP_En = 1; IP_Op = pIP_In; PCU_DI = Data[10];
    @(posedge Clk) #1 IP_En = 0; 
    // Bit #9
    @(posedge Clk) #1 IP_En = 1; IP_Op = pIP_In; PCU_DI = Data[9];
    @(posedge Clk) #1 IP_En = 0; 
    // Bit #8
    @(posedge Clk) #1 IP_En = 1; IP_Op = pIP_In; PCU_DI = Data[8];
    @(posedge Clk) #1 IP_En = 0; 
    // Bit #7
    @(posedge Clk) #1 IP_En = 1; IP_Op = pIP_In; PCU_DI = Data[7];
    @(posedge Clk) #1 IP_En = 0; 
    // Bit #6
    @(posedge Clk) #1 IP_En = 1; IP_Op = pIP_In; PCU_DI = Data[6];
    @(posedge Clk) #1 IP_En = 0; 
    // Bit #5
    @(posedge Clk) #1 IP_En = 1; IP_Op = pIP_In; PCU_DI = Data[5];
    @(posedge Clk) #1 IP_En = 0; 
    // Bit #4
    @(posedge Clk) #1 IP_En = 1; IP_Op = pIP_In; PCU_DI = Data[4];
    @(posedge Clk) #1 IP_En = 0; 
    // Bit #3
    @(posedge Clk) #1 IP_En = 1; IP_Op = pIP_In; PCU_DI = Data[3];
    @(posedge Clk) #1 IP_En = 0; 
    // Bit #2
    @(posedge Clk) #1 IP_En = 1; IP_Op = pIP_In; PCU_DI = Data[2];
    @(posedge Clk) #1 IP_En = 0; 
    // Bit #1
    @(posedge Clk) #1 IP_En = 1; IP_Op = pIP_In; PCU_DI = Data[1];
    @(posedge Clk) #1 IP_En = 0; 
    // Bit #0
    @(posedge Clk) #1 IP_En = 1; IP_Op = pIP_In; PCU_DI = Data[0];
    @(posedge Clk) #1 IP_En = 0; 

    #1 if(IP == Data) begin
        $display("\tTest IP_In - Pass\n");
    end else begin
        $display("\tTest IP_In - Fail: Expected %h, found %h\n",        
                 Data, IP);
        @(posedge Clk) #1;
        @(posedge Clk) #1;
        @(posedge Clk) #1;
        @(posedge Clk) #1;
        $stop;               // Stop Simulation
    end
end

endtask

//  Test IP_Plus_1
//
//      Expectation is that the EU will increment IP while an instruction is
//      being fetched. Thus, the IP <= IP + 1 operation is simultaneous with the
//      Op input shift operation tested by the Tst_Op_Shift_In task.
//
//      The EU enables IP for 16 clock cycles, and asserts PCU_Inc for one cycle
//      to increment IP. Asserting PCU_Inc during the first cycle inhibits the
//      carry in the IP_Cy register and asserts the second input to the adder.
//      For the remaining 15 cycles, the second input to the adder is 0 because
//      PCU_Inc is not asserted. Thus, Cy handles the propagation of any inter-
//      bit carries from the LSB to MSB, and no additional input is required 
//      from the EU.

task Tst_IP_Plus_1;
    input [15:0] ExpVal;

begin
    @(posedge Clk) #1 IP_En = 1; IP_Op = pIP_Plus_1; PCU_Inc = IP_Op[1];
    // Bit #15
    @(posedge Clk) #1 PCU_Inc = 0;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    // Bit #11
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    // Bit #7
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    // Bit #3
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1 IP_En = 0; IP_Op = 0;

    #1 if(IP == ExpVal) begin
        $display("\tTest IP_Plus_1 - Pass\n");
    end else begin
        $display("\tTest IP_Plus_1 - Fail: Expected %h, found %h\n",        
                 ExpVal, IP);
        @(posedge Clk) #1;
        @(posedge Clk) #1;
        @(posedge Clk) #1;
        @(posedge Clk) #1;
        $stop;               // Stop Simulation
    end
end

endtask

//  Test IP_Plus_Op
//
//      Expectation is that the EU will the relative offset in Op to IP while an
//      read command is being output by the EU to the memory device. At the end
//      of that 8-bit transfer (16 clock cycles), IP is ready to be output MSB
//      first using an IP_Out operation. While Op is shifted into the IP adder,
//      a 0 should be shifted in from the left. At the completion of IP_Plus_Op,
//      Op should be cleared.

task Tst_IP_Plus_Op;
    input [15:0] ExpVal;

begin
    @(posedge Clk) #1 IP_En = 1; IP_Op = pIP_Plus_Op; PCU_Inc = 1;
    // Bit #15
    @(posedge Clk) #1 PCU_Inc = 0;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    // Bit #11
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    // Bit #7
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    // Bit #3
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    @(posedge Clk) #1 IP_En = 0; IP_Op = pIP_Out;

    #1 if(IP == ExpVal) begin
        $display("\tTest Op_Plus_Op - Pass\n");
    end else begin
        $display("\tTest Op_Plus_Op - Fail: Expected %h found %h\n",
                    ExpVal, IP);
        @(posedge Clk) #1;
        @(posedge Clk) #1;
        @(posedge Clk) #1;
        @(posedge Clk) #1;
        $stop;               // Stop Simulation
    end
end

endtask

//------------------------------------------------------------------------------
//
//  Op Operations
//

function [((10 * 8) - 1):0] Op_Str;
    input [1:0] Op_Op;
    
begin
    case(Op_Op)
        pOp_Out    : Op_Str = "Op_Out   ";
        pOp_In     : Op_Str = "Op_In    ";
        pOp_Plus_A : Op_Str = "Op_Plus_A";
        pOp_Plus_W : Op_Str = "Op_Plus_W";
        default    : Op_Str = "---------";
    endcase
end

endfunction

//  Test Op_Out
//
//      There are two uses of this operation: (1) Op to offset IP for program
//      branches; and (2) Op is the memory address for local/non-local accesses.
//
//      In the first case, Op is added to IP and the result is stored in IP. The
//      sum is computed during the SPI output cycle which send the SPI read
//      command to the instruction memory. In this case, Op_En is not gated with
//      the SPI output/input clock enable signal
//
//      In the second case, A or W is added to Op to form the address of non-
//      local variables, or local variables, respectively. The sum is returned
//      to Op instead of A or W. When the address in Op is to be transmitted to
//      the memory, Op is output, but Op_En is gated with the appropriate SPI
//      clock enable signal to ensure the correct data is output on MOSI.
//
//      The EU simply selects the Op_Out operation, and gates Op_En as needed.
//      The PCU determines which Op_Out operation is required by whether IP_En
//      is asserted simultaneously with Op_En while the operation select input
//      is set for Op_Out. If this is the case, then Op_Out performs a right
//      shift for every cycle and fills in with 0 from the left. If Op_Out is
//      selected, but IP_En is not asserted, then PCU performs a left shift of
//      Op and fills Op from the right with 0.
//
//      The task below mimics the operation of the EU with respect to the Op_Out
//      operation. For case 1, the task expects to be used simultaneously with
//      the IP_Plus_Op task. In this case, the task asserts Op_En for 16 cycles,
//      and sets the operation to Op_Out. For case 2, the task performs 16 shift
//      operations over a 32 cycle period. In this case, IP_En is not expected
//      to be asserted. Also in this case, Op_Out is selected for the entire 32
//      clock interval.

task Tst_Op_Out;
    input IP_En;
    input [15:0] ExpVal;    // Expected Value of Op after shift cycle completes
    
begin
    Op_Op = pOp_Out;
    if(IP_En) begin
        // Bit #0
        @(posedge Clk) #1 Op_En = 1; PCU_OE = pOE_Op;
        @(posedge Clk) #1; 
        @(posedge Clk) #1;
        @(posedge Clk) #1; 
        // Bit #4   
        @(posedge Clk) #1;
        @(posedge Clk) #1; 
        @(posedge Clk) #1;
        @(posedge Clk) #1; 
        // Bit #8
        @(posedge Clk) #1;
        @(posedge Clk) #1; 
        @(posedge Clk) #1;
        @(posedge Clk) #1; 
        // Bit #12
        @(posedge Clk) #1;
        @(posedge Clk) #1; 
        @(posedge Clk) #1;
        @(posedge Clk) #1; 
    end else begin
        // Bit #15
        @(posedge Clk) #1 Op_En = 0; PCU_OE = pOE_Op;
        @(posedge Clk) #1 Op_En = 1; 
        // Bit #14
        @(posedge Clk) #1 Op_En = 0;
        @(posedge Clk) #1 Op_En = 1; 
        // Bit #13   
        @(posedge Clk) #1 Op_En = 0;
        @(posedge Clk) #1 Op_En = 1; 
        // Bit #12
        @(posedge Clk) #1 Op_En = 0;
        @(posedge Clk) #1 Op_En = 1; 
        // Bit #11
        @(posedge Clk) #1 Op_En = 0;
        @(posedge Clk) #1 Op_En = 1; 
        // Bit #10
        @(posedge Clk) #1 Op_En = 0;
        @(posedge Clk) #1 Op_En = 1; 
        // Bit #9
        @(posedge Clk) #1 Op_En = 0;
        @(posedge Clk) #1 Op_En = 1; 
        // Bit #8
        @(posedge Clk) #1 Op_En = 0;
        @(posedge Clk) #1 Op_En = 1; 
        // Bit #7
        @(posedge Clk) #1 Op_En = 0;
        @(posedge Clk) #1 Op_En = 1; 
        // Bit #6
        @(posedge Clk) #1 Op_En = 0;
        @(posedge Clk) #1 Op_En = 1; 
        // Bit #5    
        @(posedge Clk) #1 Op_En = 0;
        @(posedge Clk) #1 Op_En = 1; 
        // Bit #4
        @(posedge Clk) #1 Op_En = 0;
        @(posedge Clk) #1 Op_En = 1; 
        // Bit #3
        @(posedge Clk) #1 Op_En = 0;
        @(posedge Clk) #1 Op_En = 1; 
        // Bit #2
        @(posedge Clk) #1 Op_En = 0;
        @(posedge Clk) #1 Op_En = 1; 
        // Bit #1
        @(posedge Clk) #1 Op_En = 0;
        @(posedge Clk) #1 Op_En = 1; 
        // Bit #0
        @(posedge Clk) #1 Op_En = 0;
        @(posedge Clk) #1 Op_En = 1; 
    end

    @(posedge Clk) #1 Op_En = 0; Op_Op = 0; PCU_OE = 0;

    #1 if(Op == ExpVal) begin
        $display("\tTest Op_Out - Pass\n");
    end else begin
        $display("\tTest Op_Out - Fail: Expected %h, found %h\n", ExpVal, Op);
        @(posedge Clk) #1;
        @(posedge Clk) #1;
        @(posedge Clk) #1;
        @(posedge Clk) #1;
        $stop;               // Stop Simulation
    end
end

endtask
    
//  Test Op_In
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

task Tst_Op_In;
    input Inv;              // 0 - PFX; 1 - NFX;
    input [ 3:0] Data;      // Data to shift into 
    input [15:0] ExpVal;    // Expected Value of Op after shift cycle completes
    
begin
    // Bit #7
    @(posedge Clk) #1 Op_En  = 0;
                      Op_Op  = pOp_In;
                      Op_Inv = 0;
                      PCU_DI = 0;
    @(posedge Clk) #1;
    // Bit #6
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    // Bit #5    
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    // Bit #4
    @(posedge Clk) #1;
    @(posedge Clk) #1;
    // Bit #3
    @(posedge Clk) #1 Op_En = 1; PCU_DI = Data[3];
    @(posedge Clk) #1 Op_En = 0;
    // Bit #2
    @(posedge Clk) #1 Op_En = 1; PCU_DI = Data[2];
    @(posedge Clk) #1 Op_En = 0;
    // Bit #1
    @(posedge Clk) #1 Op_En = 1; PCU_DI = Data[1];
    @(posedge Clk) #1 Op_En = 0;
    // Bit #0
    @(posedge Clk) #1 Op_En = 1; PCU_DI = Data[0]; Op_Inv = Inv;
    @(posedge Clk) #1 Op_En = 0; Op_Inv = 0;
    
    @(posedge Clk) #1 Op_Op = 0; PCU_DI = 0;
    
    #1 if(Op == ExpVal) begin
        $display("\tTest Op_In - Pass\n");
    end else begin
        $display("\tTest Op_In - Fail: Expected %h, found %h\n", ExpVal, Op);
        @(posedge Clk) #1;
        @(posedge Clk) #1;
        @(posedge Clk) #1;
        @(posedge Clk) #1;
        $stop;               // Stop Simulation
    end
end

endtask

//  Test Op_Plus_A
//
//      When access is required to a non-local variable, the address is computed
//      using Op_Plus_A and stored in Op during the SPI command cycle. The 
//      target address in Op is output during the subsequent 16-bit address
//      address cycle using Op_Out. To compute the non-local address, an ALU POP
//      operation is required which shifts the ALU TOS LSB first, and Op_Plus_A
//      computes the sum of Op and ALU_DI. The resulting sum is shifted into Op.

task Tst_Op_Plus_A;
    input [15:0] Data;
    input [15:0] ExpVal;

begin
    // Bit #0
    @(posedge Clk) #1 Op_En = 1; Op_Op = pOp_Plus_A; ALU_DI = Data[0];
    @(posedge Clk) #1 ALU_DI = Data[1]; 
    @(posedge Clk) #1 ALU_DI = Data[2];
    @(posedge Clk) #1 ALU_DI = Data[3]; 
    // Bit #4   
    @(posedge Clk) #1 ALU_DI = Data[4];
    @(posedge Clk) #1 ALU_DI = Data[5]; 
    @(posedge Clk) #1 ALU_DI = Data[6];
    @(posedge Clk) #1 ALU_DI = Data[7]; 
    // Bit #8
    @(posedge Clk) #1 ALU_DI = Data[8];
    @(posedge Clk) #1 ALU_DI = Data[9]; 
    @(posedge Clk) #1 ALU_DI = Data[10];
    @(posedge Clk) #1 ALU_DI = Data[11]; 
    // Bit #12
    @(posedge Clk) #1 ALU_DI = Data[12];
    @(posedge Clk) #1 ALU_DI = Data[13]; 
    @(posedge Clk) #1 ALU_DI = Data[14];
    @(posedge Clk) #1 ALU_DI = Data[15];

    @(posedge Clk) #1 Op_En = 0; Op_Op = 0; ALU_DI = 0;

    #1 if(Op == ExpVal) begin
        $display("\tTest Op_Plus_A - Pass\n");
    end else begin
        $display("\tTest Op_Plus_A - Fail: Expected %h, found %h\n",
                 ExpVal, Op);
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

