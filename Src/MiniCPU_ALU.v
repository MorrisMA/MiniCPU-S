`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Company:         M. A. Morris & Associates 
// Engineer:        Michael A. Morris
// 
// Create Date:     20:43:53 07/24/2012 
// Design Name:     MiniCPU - Minimal CPU
// Module Name:     MiniCPU_ALU 
// Project Name:    C:\XProjects\ISE10.1i\MiniCPU
// Target Devices:  Xilinx XC95xxx CPLD 
// Tool versions:   Xilinx ISE10.1i
// 
// Description:
//
//  This module forms the ALU for a Minimal CPU designed for implementation in
//  a XC95xxx CPLD. The CPU is stack based. Operands are always on the ALU
//  stack, and all results are automatically returned to the stack. User regis-
//  ters of the MiniCPU are as follows:
//
//  I   : Instruction Pointer              (12-bits)
//  W   : Workspace Pointer                (12-bits)
//  A   : ALU Top-Of-Stack  (TOS) register ( 6-bits)
//  B   : ALU Next-On-Stack (NOS) register ( 6-bits)
//  C   : ALU Last-On-Stack (LOS) register ( 6-bits)
//
//  Op  : Operand (temp data) register     (12-bits)
//  MDI : Memory Data Input register       ( 6-bits)
//                                         (60 DFFs)
//
//  External memory address bus is 12-bits wide, and external memory data bus is
//  6 bits wide. Instruction addresses are provided by the instruction ptr, I.
//  Data addresses are provided by the workspace pointer, W, indexed by the
//  operand register, Op. To initialize W, load it with the operand register.
//
//  The workspace is treated as a stack. Local variables and subroutine return
//  addresses are maintained in the workspace. The workspace and the instruction
//  space are considered separate address spaces, and the memory space being
//  accessed is indicated as a 13th address bit. Only reads are allowed from
//  instruction space, but both reads and writes are supported to data space.
//  I/O devices are considered memory mapped into data space.
//
//  Instruction encoding uses MDI[5:3]. The MDI[2:0] are essentially Op[2:0].
//  The PFX instruction inserts MDI[2:0] into Op, and then shifts Op left three
//  bits. Thus, 3 PFX instructions followed another direct instruction, or the
//  indirect execution instruction, EXE, fully fills Op[11:0]. In general, only
//  one or two PFX instructions are needed to load Op with a desired constant.
//  Following the execution of any of the other direct instructions, the operand
//  register is cleared.
//
//  In this instruction encoding scheme, the operand register is used to provide
//  extensions to the MiniCPU instruction set. With only three bits representing
//  the eight directly encoded instructions (defined below), the operand register
//  is used to indirectly encode the remaining instructions of the MiniCPU.
//  Since MDI[2:0] are always loaded into Op[2:0], the indirect instructions can
//  be segregated into two classes: indirect class 1 which does not require a PFX
//  instruction, and indirect class 2 which requires one or more PFX instructions
//  to precede the EXE instruction. The direct instruction set of the MiniCPU is
//  defined below:
//
//  MDI[5:4] Mnem   Function            Operation
//    000     EXE   Execute             Execute Op an instruction
//    001     LDW   Load Op into W      W <= Op
//    010     JSR   Jump to Subroutine  W <= (W + ~1 + 1);  (dummy cycle)
//                                      *(W--) <= I[11:6];  (data write)
//                                      *(W) <= I[5:0];     (data write)
//                                      I <= Op
//    011     CJ    Conditional Jump    (TOS) ? I <= (I + Op + 1): (I + 0 + 1);
//                                      {A, B, C} <= {B, C, C}
//    100     ST    Store               *(W + Op + 0) <= A;              
//                                      {A, B, C} <= {B, C, C}
//    101     LD    Load                {A, B, C} <= {*(W + Op + 0), A, B}
//    110     LDK   Load Op into TOS    {A, B, C} <= {Op[5:0], A, B}
//    111     PFX   Prefix              Op <= (Op | MDI[2:0]) << 3
//
//  For the MiniCPU's stack architecture, the direct instructions represent the
//  most common instructions expected to be performed. In this manner, the Op
//  can most effectively function as a register for indexing external memory.
//  As constructed, the direct instructions allow the indexing of eight memory
//  locations in closest proximity to the workspace pointer without using a
//  PFX instruction to extend the memory index value provided by MDI[2:0].
//  
//  EXE executes the contents of Op as an instruction
//
//  LDW loads Op into W.
//
//  JSR pushes (as 2 6-bit nibbles) the address of the next instruction. 
//
//  CJ loads Op into I if TOS <> 0, else it loads I++. An unconditional jump
//  must be forced by loading TOS with a non-zero value. Also note that CJ pops
//  the test value in TOS from the ALU stack.
//
//  ST stores TOS to the data memory location addressed by the sum of W and Op,
//  and then pops the ALU stack.
//
//  LD pushes the ALU stack, and loads TOS from the data memory location
//  addressed by the sum of W and Op.
//
//  LDK loads Op[5:2] into the TOS. It allows all 64 possible values to be load-
//  ed into the TOS with no more than one PFX instruction.
//
//  PFX loads MDI[2:0] into Op and then shifts Op left three bits.
//
//  The MiniCPU's Class1 Indirect instructions require no PFX instructions to
//  precede the EXE direct instruction. In other words, the Class 1 indirect
//  instructions listed below are effectively single word instructions:
//
//  Op[2:0] Mnem    Function                Operation
//   000    ADC     Add with Carry          {A, B, C} <= {(B + A),      C, C}
//   001    SBB     Subtract with Borrow    {A, B, C} <= {(B - A),      C, C}
//   010    AND     Bit-wise Logical AND    {A, B, C} <= {(B & A),      C, C}
//   011    ORL     Bit-wise Logical OR     {A, B, C} <= {(B | A),      C, C}
//   100    XOR     Bit-wise Logical XOR    {A, B, C} <= {(B ^ A),      C, C}
//   101    RRC     Rotate Right through C  {A, B, C} <= {{Cy, A[5:1]}, B, C};
//                                          Cy <= A[0]
//   110    RLC     Rotate Left through C   {A, B, C} <= {{A[4:0], Cy}, B, C};
//                                          Cy <= A[5]
//   111    RTS     Return from Subroutine  I[ 5:0] <= *(W++);
//                                          I[11:6] <= *(W++)     
//
//  ADC adds ALU register B to ALU register A. The operand values are poped from
//  the ALU stack, and the result is pushed onto the stack. If a carry results,
//  then the hidden Cy bit is set. The hidden carry bit, Cy, should be cleared
//  using either of the following instruction sequences: LDK 0, ROR;
//  or LDK 0, ROL.
//
//  SBB subtracts ALU register A from ALU register B. The operand values are
//  poped from the ALU stack, and the result is pushed onto the stack. If a
//  borrow results, then the hidden Cy bit is cleared. The hidden carry bit, Cy,
//  can be cleared using either of the following instruction sequences to force
//  a borrow: LDK 0, ROR; or LDK 0, ROL. Otherwise, set the hidden Cy bit using
//  either of the following sequences:  LDK 1, ROR; or LDK 1, ROL.
//
//  AND, ORL, and XOR perform bit-wise boolean operations on ALU register A and
//  ALU register B. Both operands are popped off the ALU stack, and the result
//  is pushed onto the ALU stack.
//
//  RRC performs a logical right shift with the most significant bit being re-
//  placed by the hidden carry bit, and the least significant bit being placed
//  in the hidden carry bit.
//
//  RLC performs a logical left shift complementary to the RRC described above.
//
//  RTS reads the workspace and loads the return address. W is adjusted in the
//  process.
//
//  These are the bare minimum instructions and registers required to support a
//  fully functional CPU. The processor instruction set, and register widths can
//  be expanded easily to support a more conventional configuration. However,
//  the primary objective of this project is a full featured CPU which fits in a
//  CPLD having a minimum of logic cells.
//
//  Ideally, this design will fit into a CPLD with a maximum of 72 logic cells.
//  As defined here, the design is expected to easily fit into a 144 logic cell
//  CPLD.
//  
// Dependencies:    none
//
// Revision: 
//
//  0.00    12G24   MAM     Initial Coding
//
//  0.10    12H01   MAM     Added special input, Ld, which pushes DI onto ALU
//                          register stack. Ld takes priority over Op.
//
// Additional Comments: 
//
//  Accounting for the redundant use of the MDI[2:0] FFs for Op[2:0] reduces the
//  estimated FF usage from 60 to 57 FFs. The hidden carry will require one FF, 
//  so the expected FF utilization entering into the design is 58 FFs. A 72 cell
//  CPLD should be able to 58 FFs as registers, and use the remaining 14 cells
//  to implement the sequencer.
//
//  In the XC95xxx CPLD family, the AND-OR array supports 54 inputs and 18 feed-
//  back terms. The ANDs support logic functions of 72 variables, but each OR
//  gate only supports 8 terms be default. This limitation is expected to
//  restrict the number of functions that can be easily multiplexed into the FFs
//  of each macrocell (18 FFs per macrocell). The 18 feedback terms available in
//  each macrocell should provide no restriction on FFs connections to AND-OR
//  array of the macrocell or individual logic cells.
//
////////////////////////////////////////////////////////////////////////////////

module MiniCPU_ALU(
    input   Rst,            // System Reset
    input   Clk,            // System Clock
    input   CE,             // Module Clock Enable
    
    input   [3:0] I,        // Instruction
    
    input   [5:0] DI,       // Data Input Register
    input   Ld,             // Push DI onto ALU register stack
    input   [5:0] Op,       // Operand Register
    
    output  reg [5:0] A,    // ALU Register A (TOS)
    output  reg [5:0] B,    // ALU Register B (NOS)  
    output  reg [5:0] C,    // ALU Register C (LOS)
    
    output  Z,              // Zero Flag - returns zero for the current TOS
    output  reg Cy          // Carry Flag
);

////////////////////////////////////////////////////////////////////////////////
//
//  Parameter Declarations
//

localparam pNOP = 4'b0000;      // {A,B,C} <= {A, B,C}
localparam pLDW = 4'b0001;      // {A,B,C} <= {A, B,C}
localparam pJSR = 4'b0010;      // {A,B,C} <= {A, B,C}
localparam pCJ  = 4'b0011;      // {A,B,C} <= {B, C,C}
localparam pST  = 4'b0100;      // {A,B,C} <= {B, C,C}
localparam pLD  = 4'b0101;      // {A,B,C} <= {DI,A,B}
localparam pLDK = 4'b0110;      // {A,B,C} <= {Op,A,B}
localparam pPFX = 4'b0111;      // {A,B,C} <= {A, B,C}
//
localparam pADC = 4'b1000;      // {A,B,C} <= {(B +  A + Cy),C,C}
localparam pSBB = 4'b1001;      // {A,B,C} <= {(B + ~A + Cy),C,C}
localparam pAND = 4'b1010;      // {A,B,C} <= {(B & A),      C,C}
localparam pORL = 4'b1011;      // {A,B,C} <= {(B | A),      C,C}
localparam pXOR = 4'b1100;      // {A,B,C} <= {(B ^ A),      C,C}
localparam pRRC = 4'b1101;      // {A,B,C} <= {{Cy, A[5:1]}, C,C}; Cy <= A[0]
localparam pRLC = 4'b1110;      // {A,B,C} <= {{A[4:0], Cy}, C,C}; Cy <= A[5]
localparam pRTS = 4'b1111;      // {A,B,C} <= {A,B,C}

////////////////////////////////////////////////////////////////////////////////
//
//  Module Declarations
//

wire    [6:0] Add_Out;          // Adder
wire    [5:0] Ai, Bi;   // Adder Input busse

////////////////////////////////////////////////////////////////////////////////
//
//  Implementation
//

assign Z = ~|A;     // Z is asserted when (A == 0)

//  ALU Adder

assign Bi      = B;
assign Ai      = ((I == pADC)) ? A : ~A; 
assign Add_Out = Bi + Ai + Cy;

//  ALU Register A

always @(posedge Clk)
begin
    if(Rst)
        {Cy, A} <= #1 0;
    else if(CE)
        if(Ld)
            {Cy, A} <= #1 {Cy, DI};
        else
            case(I)
                4'b0011 : {Cy, A} <= #1 {Cy, B };
                
                4'b0100 : {Cy, A} <= #1 {Cy, B };
                4'b0110 : {Cy, A} <= #1 {Cy, Op};
                
                4'b1000 : {Cy, A} <= #1 Add_Out;
                4'b1001 : {Cy, A} <= #1 Add_Out;
                
                4'b1010 : {Cy, A} <= #1 {Cy,  B & A };
                4'b1011 : {Cy, A} <= #1 {Cy,  B | A };
                4'b1100 : {Cy, A} <= #1 {Cy,  B ^ A };
                4'b1101 : {Cy, A} <= #1 {A[0], {Cy, A[5:1]}};
                4'b1110 : {Cy, A} <= #1 {A[5], {A[4:0], Cy}};
                
                default : {Cy, A} <= #1 {Cy, A};
            endcase
end

//  ALU Register B

always @(posedge Clk)
begin
    if(Rst)
        B <= #1 0;
    else if(CE)
        if(Ld)
            B <= #1 A;
        else
            case(I)
                4'b0011 : B <= #1 C;
                
                4'b0100 : B <= #1 C;
                4'b0110 : B <= #1 A;
                
                4'b1000 : B <= #1 C;
                4'b1001 : B <= #1 C;
                4'b1010 : B <= #1 C;
                4'b1011 : B <= #1 C;
                4'b1100 : B <= #1 C;
                
                default : B <= #1 B;
            endcase
end

//  ALU Register C

always @(posedge Clk)
begin
    if(Rst)
        C <= #1 0;
    else if(CE)
        if(Ld)
            C <= #1 B;
        else
            case(I)
                4'b0110 : C <= #1 B;

                default : C <= #1 C;
            endcase
end

endmodule
