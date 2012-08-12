`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company:         M. A. Morris & Associates 
// Engineer:        Michael A. Morris
//
// Create Date:     15:40:11 08/05/2012
// Design Name:     SEEPROM_Rdy
// Module Name:     C:/XProjects/ISE10.1i/MiniCPU/tb_SEEPROM_Rdy.v
// Project Name:    MiniCPU
// Target Device:   Simulation/FPGA
// Tool versions:   ISE10.1i
//
// Description: 
//
// Verilog Test Fixture created by ISE for module: SEEPROM_Rdy
//
// Dependencies:
// 
// Revision:
//
//  0.00    12H05   MAM     File Created
//
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module tb_SEEPROM_Rdy;

// Inputs
reg     Rst;

reg     Hold;
reg     SCK;

// Outputs

wire Rdy;

// Instantiate the Unit Under Test (UUT)

SEEPROM_Rdy uut (
                .Rst(Rst), 
                .Hold(Hold), 
                .SCK(SCK), 
                .Rdy(Rdy)
            );

initial begin
    // Initialize Inputs
    Rst  = 1;
    Hold = 0;
    SCK  = 0;

    // Wait 100 ns for global reset to finish
    #101 Rst = 0;
    
    // Add stimulus here
    
    #25 Hold = 1;
    #20 Hold = 0;
    #27 Hold = 1;
    #5  Hold = 0;
    #20 Hold = 1;
    #8  Hold = 0;
    #2  Hold = 1;
    #20 Hold = 0;
    #40 Hold = 1;
    #10 Hold = 0;
    #10 Hold = 1;
    #33 Hold = 0;

end

always #10 SCK = ~SCK;
      
endmodule

