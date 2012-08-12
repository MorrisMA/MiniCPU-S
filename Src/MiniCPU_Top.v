`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Company:         M. A. Morris & Associates 
// Engineer:        Michael A. Morris
// 
// Create Date:     20:21:39 07/28/2012 
// Design Name:     MiniCPU - Minimal CPU
// Module Name:     MiniCPU_ALU 
// Project Name:    C:\XProjects\ISE10.1i\MiniCPU
// Target Devices:  Xilinx XC95xxx CPLD 
// Tool versions:   Xilinx ISE10.1i
// 
// Description:
//
//  The objective of this design is to implement a non-trivial CPU in a CPLD.
//  The implementation is targeting CPLDs such as the Xilinx XC95xxx. A detailed
//  description of the CPU architecture and instruction set can be found in the
//  header of MiniCPU_ALU.v. The MiniCPU is implemented with a 6-bit stack-based
//  ALU, with a 12-bit address bus and separate instruction and data spaces. In
//  other words, the MiniCPU resembles an HP RPN calculator, or an implementa-
//  tion of a minimal Inmos Transputer. The implementation has 16 instructions:
//
//      (1) 15 6-bit instructions
//      (2) 1 12-bit instruction.
//
//  The MiniCPU has three classes of instructions: (1) direct instructions,
//  (2) single word (6-bit) single word (Class 1) indirect instructions, and
//  (3) multi-word (Class 2) indirect instructions. All of the direct instruc-
//  tions and the Class 1 indirect instructions are defined in the header of
//  MiniCPU_ALU.v, but the single Class 2 indirect instruction is defined below
//  in the Additional Comments section.
//
//  ----------------------------------------------------------------------------
//
//  The MiniCPU uses a two-phase execution cycle. During phase 1, E is asserted
//  and the memory address is asserted along with the type indicator, DnI. DnI
//  is asserted for instruction fetches, and not asserted for data fetches. The
//  MiniCPU utilizes a signed address concept, and this definition of DnI allows
//  it to be combined with the 12 bits from the workspace address computation to
//  form a default data memory address of 0x1000, or the most negative value of
//  a 13-bit 2's complement number. Data memory is addressed with positive off-
//  sets from this base address. In this scheme, the instruction memory origin
//  is 0x0000, and grows from there. Asserting nRst will clear the instruction
//  pointer and the workspace pointer. When combined with DnI, the address bus
//  is driven with the correct addresses for the instruction and data spaces.
//
//  During phase 1 of a memory cycle, the execution Finite State Machine (FSM)
//  drives the address bus with either the contents of the instruction pointer
//  plus 1 or 0, or the contents of the workspace pointer plus {Op | ~0 | 1}.
//  The memory cycle phase indicator signal, E, is asserted during phase 1.
//  E is so named because external logic is expected to use it to latch the
//  memory address during phase 1. (Note: the present implementation holds the
//  address constant throughout the memory cycle. That characteristic may not
//  be maintained in later models in order to improve performance, reduce pin
//  counts by multiplexing address and data, re-use of underutilized arithmetic
//  resources during phase 2 of the memory cycle, etc.)
//
//  Also during phase 1 of a memory cycle, the instruction is decoded, and the
//  execution FSM decides on the path to take during the following memory cycle.
//  Following reset or aprogram branch, the execution FSM performs a single
//  memory cycle to instruction memory to fetch the initial instruction.
//
//  During phase 2 of a memory cycle, the cycle type signal RnW is driven and E
//  is deasserted. With E deasserted and RnW asserted, the data from the exter-
//  nal memory is written into the DI register at the completion of phase 2.
//
//  Instruction and data fetches are generally overlapped in the MiniCPU. This
//  means that instruction execution is generally performed in the cycle follow-
//  ing the instruction fetch. No pre-decode of the instruction is performed.
//
//  The overlapped execution model means that during phase 1 of the following
//  memory cycle, the instruction is decoded and any enables for the various
//  functional units are generated combinatorially. The results of any arith-
//  metic operation are then registered into the ALU stack at the completion of
//  the first phase of the memory cycle. This means that during the second phase
//  of the memory cycle, any ALU operations are complete. 
//
//  Data read from either data or instruction memory is registered into the Data
//  Input (DI) register. This register functions as a temporary holding register
//  for both instructions and data. It is loaded from the memory input bus at
//  the end of the phase 2 (beginning of phase 1), and retains its contents for
//  the entire memory cycle. Since the MiniCPU is targeting a FF-poor CPLD, the
//  execution FSM will contain special sequences for any instruction which
//  requires the use of DI to temporarily hold operands. Thus, the MiniCPU does
//  not require a dedicated instruction register, and reduces the number of FFs
//  required in its implementation. In the current implementation, there are
//  only a few instructions which will require this special treatment:
//
//      (1) RTS,
//      (2) LD.
//
//  Modern practice generally requires the use of registered outputs. In the
//  case of the CPLD target of the MiniCPU, this must be avoided as well. Thus,
//  the MiniCPU address bus is driven through a combinatorial circuit which
//  multiplexes the instruction pointer, the workspace address, and the operand
//  register. To reduce the resources that may be required, the combinatorial
//  circuit forming the addresses output from the MiniCPU will include the capa-
//  bility to increment, decrement, offset (using contents of operand register),
//  and leave unmodified the contents of the instruction and workspace pointers.
//
//  ----------------------------------------------------------------------------
//
//  Since the CPLD architecture does not provide RAM/ROM resources, a ROM-based
//  state machine single-chip implementation of the MiniCPU is not possible. The
//  MiniCPU execution FSM must be implemented using standard FSM techniques. The
//  state encoding style that must be used for the execution FSM is also driven
//  by the architecture of CPLDs. Thus, a gray encoded state style is used. This
//  style can generally be considered to reduce the number of p-terms required
//  for the state transition equations. Other than the limited number of FFs,
//  the number of p-terms that can feed into the D input of the FFs is next most
//  scarce resource in a CPLD. In the Xilinx XC95xxx family, each macrocell only
//  provides 5 unrestricted p-terms (AND) to the sum gate (OR). This number can
//  be increased dramatically by sharing p-terms from adjacent macrocells. This
//  architectural feature is present in virtually all CPLDs (and PALs), and is
//  the primary characteristic that allows complex logic equations of greater
//  than 5 p-terms to be fitted into CPLDs.
//
//  However, when p-terms are shared between macrocells, the number of p-terms
//  available to the macrocell sharing its p-terms decreases. This means that
//  macrocells requiring complex functions are generally scattered about the
//  function blocks (composed of 18 macrocells for XC95xxx CPLDs) in order to
//  distribute p-term sharing so that the remaining functionality of the macro-
//  cells are advantageously utilized. Routing p-term sharing signals between
//  function blocks has the potential to create bottlenecks in the inter-block
//  routing matrix. (Within a function block, this is not generally an issue,
//  but inter-block the routing resources are more limited and bottlenecks can
//  arise.) These two characteristics of CPLDs, i.e. inter-block routing bottle-
//  necks and p-term sharing restrictions, are the reason why most complex CPLD
//  designs should not be pin locked early. Instead, pin locking should be put
//  off until late in the design. (Although it may be aesthetically pleasing, or
//  easier to layout the CCA when the pinout of the design is logically organiz-
//  ed around the CPLD package, the p-term sharing restrictions and inter-block
//  routing resource limits may cause the design to fail to fit if the pins are
//  not placed appropriately. It may be difficult to predict the pin placement
//  restrictions, and place the pins in a manner that allows the design to be
//  fitted. A preliminary fitting with unlocked pins should be performed first
//  before any pin locking is performed. The design should be re-fitted after
//  the initial pin locking in order to ensure that the design fits in the pin
//  locked component.)
//
//  The design of the execution FSM for the CPLD-based MiniCPU will be based on
//  the concepts discussed above and the principal that each memory cycle is
//  composed of two phases. In the first phase, E is asserted, the address bus
//  is driven with an address, and instruction execution is completed if the
//  operands are available. With the exception of the RTS instruction, all ope-
//  rands are available when an instruction is loaded into DI from memory. The
//  EXE instruction is only fetched from instruction memory after the Op regis-
//  ter has been loaded appropriately by the PFX instructions. The same is true
//  for the other 6 direct instructions: they either require no PFX instructions
//  to load Op, or the 3-bit Op value included in DI[2:0] is all that is requir-
//  ed for the instruction. The class 1 indirect instructions do not use Op as
//  an operand, and do not require PFX instructions to set Op[11:3] as an in-
//  struction index.
//
//  ----------------------------------------------------------------------------
//
//  A summary of the MiniCPU instruction is provided below. The summary is fol-
//  lowed by a detailed description of the memory cycle behavior of each
//  instruction.
//
//  I[2:0] Op[3:0]  Mnem    Function
//   000    0000    ADC     Add with Carry
//   000    0001    SBB     Subtract with Borrow
//   000    0010    AND     Bit-Wise Logical AND
//   000    0011    ORL     Bit-Wise Logical OR
//   000    0100    XOR     Bit-Wise Logical XOR
//   000    0101    RRC     Rotate Right through Carry
//   000    0110    RLC     Rotate Left through Carry
//   000    0111    RTS     Return From Subroutine
//   000    1000    AJW     Adjust W by adding sign extended TOS value to W
//   001    xxxx    LDW     Load Op into W
//   010    xxxx    JSR     Jump to SubRoutine at location (I + Op + 1)
//   011    xxxx    CJ      Conditional Jump to location (I + Op +1)
//   100    xxxx    ST      Store TOS in location (W + Op + 0)
//   101    xxxx    LD      Load TOS from location (W + Op + 0)
//   110    xxxx    LDK     Load Op into TOS
//   111    xxxx    PFX     Load Op from DI[2:0] and shift left three bits
//
//  ADC, SBB, AND, ORL, XOR, RRC, RLC are Class 1 indirect instructions perform-
//  ed in a single cycle by the ALU. Following the instruction fetch, the arith-
//  metic operation is performed, and the ALU stack is updated with the result.
//  
//  RTS is a Class 1 indirect instruction. Following the fetch cycle, two work-
//  space read cycles. After each workspace read cycle, the workspace pointer is
//  incremented. The first workspace read cycle returns the least significant
//  return address word. It is stored in DI, and transferred to the lower word
//  of the instruction pointer during phase 1 of the second workspace read cy-
//  cle. At the completion of the second workspace read cycle, DI is loaded with
//  the most significant return address word. To eliminate a dummy read cycle,
//  the instruction fetch is from address {DI, I[5:0]}. The upper word of the
//  instruction word is loaded with DI during phase 1, so that the instruction
//  pointer is ready to be incremented at the end of phase 2. Using the second
//  DI value read in this manner reduces the number of cycles required to imple-
//  ment RTS by one cycle. With an implementation as described here, RTS needs
//  only three cycles. (The additional multiplexer used in the address path may
//  cause the number of macrocells required to exceed 108. To reduce the number
//  of macrocells may require adding a dummy workspace read and increasing the
//  number of cycles required to implement RTS from 3 to 4. Given the principal
//  objective of this project, the additional cycle would be a reasonable
//  decrease in performance in order to keep the implementation in a CPLD of
//  less than 108 macrocells, i.e. the largest vailable in a PC84 package.)
//
//  AJW is a Class 2 indirect instruction. It requires a single PFX instruction
//  to set up the upper bits of Op. In the MiniCPU, the address generator arith-
//  metic unit is shared between the workspace pointer and the instruction poin-
//  ter. Therefore, a dummy workspace memory cycle follows the fetch of the AJW
//  instruction. During that cycle, the address is driven with the sum of W and
//  the sign extended TOS value. The sum is loaded into W at the end of the cy-
//  cle, and the ALU stack is popped.
//
//  LDW is a direct instruction. The instruction loads W with the value in the
//  operand register.
//
//  JSR is a direct instruction. The first cycle of the JSR writes the most sig-
//  nificant word of the instruction pointer to workspace address {W + ~0 + 0},
//  i.e. the workspace location pointed to by a pre-decremented workspace point-
//  er. This value is stored into W at the completion of phase 2 of the write
//  cycle. The second cycle writes the least significant word of the instruction
//  pointer to {W + ~0 + 0}, and stores the address in W at the completion of
//  the cycle. Thus, at the end of these two cycles, the workspace pointer has
//  been decremented by 2, and is pointing to the least significant word of the
//  return address. The final cycle of the JSR instruction is a fetch from
//  address {I + Op + 0}. Because of the increment of the instruction pointer
//  that occurs at the completion of most instruction memory read cycles, this
//  address represents the address of the instruction plus one plus a relative
//  offset. It is possible to convert this into an absolute reference by simply
//  gating the instruction pointer portion of the address with an AND gate. Like
//  the RTS instruction, the JSR instruction requires 3 cycles to complete.
//
//  CJ is a direct instruction. CJ check the Z flag to perform a conditional
//  jump. If the Z flag is not set, the address is {I + Op + 1}. If Z is set,
//  the address is {I + 0 + 1}.
//
//  ST is a direct instruction. Following the fetch cycle, a workspace write
//  cycle is performed with address {W + Op + 0}. At the end of the cycle, the
//  ALU register stack is popped. Following the workspace write cycle, a fetch
//  cycle is performed.
//
//  LD is a direct instruction. Following the fetch cycle, a workspace read
//  cycle is performed with address {W + Op + 0}. DI is loaded with the value
//  read from memory at the end of the cycle. After the workspace read cycle, a
//  fetch cycle is performed. During phase 1 of the fetch cycle, DI is pushed
//  onto the ALU register stack. This allows DI to be filled with the instruc-
//  tion during phase 2.
//
//  LDK is a direct instruction. LDK loads the operand register into the ALU
//  register stack.
//
//  ----------------------------------------------------------------------------
//
//  
//
// Dependencies:    MiniCPU_ALU.v
//
// Revision: 
//
//  0.00    12G28   MAM     Initial Coding 
//
// Additional Comments:
//
//  The 15 single word instructions (7 direct, and 8 Class 1 indirect instruc-
//  tions) have already been defined. The only Class 2 multi-word indirect
//  instruction not currently implemented is: AJW - AdJust Workspace pointer.
//
//  The workspace pointer, W, provides a pointer to the local workspace of the
//  MiniCPU processor. Subroutine calls and returns automatically adjust W to
//  account for the two data (6-bit) words required to hold the 12-bit return
//  address. Access to data memory is provided by indexed addressing. The base
//  address is provided by W, and the index is provided by Op, the operand re-
//  gister.
//
//  The workspace is intended to function as stack in which all local variables
//  are maintained. Without an instruction to adjust W, there is no mechanism by
//  which a subroutine can allocate and deallocate temporary variables. Thus, an
//  instruction is needed to adjust W with the contents of the TOS. The instruc-
//  will allow W to be adjusted ±31 words. It will be responsibility of whatever
//  routine that adjusts W to restore it before an RTS instruction is executed.
//
//  The AJW instruction is defined as:
//
//  Op[5:0] Mnem    Function                Operation
//  001000  AJW     AdJust Workspace Ptr    W <= W + SignExt(TOS)
//
//  By this point it should be obvious that there are some limitations to the
//  addressing capabilities of the MiniCPU. One glaring deficiency is that there
//  is no way to perform absolute addessing. The relative addressing provided by
//  the base plus offset addressing of this implementation of the MiniCPU is
//  relatively powerful. However, the offsets to memory-mapped peripherals will
//  vary according to the call depth of the routine attempting to access such
//  a device. In simple controllers this will not be a significant issue since
//  in most cases the call depth of subroutine is generally fixed for an appli-
//  cation. This limitation will be an issue in the event that a more general
//  purpose application program is desired in which the call depth of an I/O
//  handling routine cannot be statically determined. One example of such a 
//  situation is an Interrupt Service Routine; the asynchronous nature of such
//  events will prevent the call depth of ISR to be statically defined. Since
//  the present MiniCPU implementation does not support interrupts, this is not
//  a pressing issue which needs resolution before the project can be completed.
//
//  One approach to resolving this issue is to make the I/O space fixed. One way
//  to do this is to make the Op register the I/O base, and the TOS register the
//  index into the I/O space. Without significant change to current instruction
//  encoding, this approach is not possible. Another approach is to limit the
//  I/O space to 64 locations. In this manner, another multi-word instruction
//  can be defined that uses the value in the TOS as the I/O address. This
//  second approach fits the general character of the MiniCPU, and is likely the
//  way that this problem will be resolved in a future update of the MiniCPU.
//
////////////////////////////////////////////////////////////////////////////////

module MiniCPU_Top(
    input   Rst,            // System Reset
    input   Clk,            // System Clock

    output  E,              // Memory cycle control signal
    output  InD,            // Instruction not Data space indication
    
    output  [11:0] A,       // Memory/Instruction Address
    output  RnW,            // Read/notWrite Strobe
    inout   [5:0] D         // Bidirectional Data bus
);

////////////////////////////////////////////////////////////////////////////////
//
//  Parameter Declarations
//



////////////////////////////////////////////////////////////////////////////////
//
//  Module Wire/Reg Declarations
//



////////////////////////////////////////////////////////////////////////////////
//
//  Implementation
//



endmodule
