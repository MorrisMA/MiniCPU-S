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
// Company:         M. A. Morris & Associates
// Engineer:        Michael A. Morris
//
// Create Date:     10:18:33 09/21/2012
// Design Name:     Minimal CPU Implementation for CPLD with SPI Interface
// Module Name:     MiniCPU_SerPCU.v
// Project Name:    C:\XProjects\ISE10.1i\MiniCPU
// Target Devices:  CLPD
// Tool versions:   Xilinx ISE 10.1i SP3
//
// Description:
//
//  This module provides a serial implementation of the Program Control Unit,
//  PCU, for the MiniCPU-S project. The PCU implements the three of the four
//  remaining non-ALU registers of the MiniCPU-S: Instruction Pointer (IP),
//  Workspace pointer (W), and Operand register (Op). The IP, W, and Op
//  registers match the width of the MiniCPU-S ALU registers, i.e. 16 bits in
//  the target CPLD implementation. The remaining register, the instruction
//  register (IR), is implemented in the MiniCPU-S Execution Unit (EU).
//
//  This module is implemented in a manner similar to that of the MiniCPU-S
//  serial ALU module, MiniCPU_SerALU.v. That is, address computations are
//  performed using a serial adder, and the module is controlled by the external
//  EU module, which implements the IR, the execution state machine, and
//  provides the SPI interface to SPI memory and SPI I/O devices. Like the
//  registers in the MiniCPU_SerALU module, the registers in the MiniCPU_SerPCU
//  are implemented as bidirectional shift registers. The PCU performs all
//  address computations and shifts, and operand shifts under the control of the
//  EU.
//
//  The PCU generally performs address computations at two times during the SPI
//  transfer cycle: (1) while the EU is transferring the 8-bit SPI command code
//  to the addressed device, and (2) during the 8-bit instruction fetch. Since
//  the eight SPI cycles required to transfer the necessary read/write command
//  to the device require 16 MiniCPU clock cycles to complete, the required 16-
//  bit arithmetic operations can be completed within that number of clock
//  cycles and the MSB of the address will be ready to transmit to the addressed
//  device on the 17th cycle of the SPI address transfer cycle. Similarly, the 8
//  SPI cycles required to read the instruction allow the IP to be incremented
//  and thereby track the address pointer/counter of the memory device from
//  which instructions are being read.
//
//  Given the nature of the MiniCPU-S instruction set, most instruction fetches
//  are expected to be sequential. Further, the memory devices being targetted
//  by this design allow the suspension of their SPI cycles, i.e. implement an
//  SPI HOLD function. The MiniCPU-S EU will use this capability to enhance
//  overall performance, but this requires that the instruction and data spaces
//  be separate. That is, the MiniCPU-S must be implemented using a modified
//  Harvard architecture, where separate memory devices are used for
//  instructions and for data. (Note: a true Harvard architecture with separate
//  and independent instruction and data memory interfaces is not required.
//  External logic can allow the functionality of the two memory devices to be
//  swapped. This allows downloading of programs into one device while executing
//  from the other device, and then swapping the functionality of the devices in
//  order to execute the downloaded program.)
//
//  Because separate memory devices are used for instructions and data, and most
//  instructions will be sequential, the EU will assert HOLD on the instruction
//  device after the fetch of each instruction. This suspends the SPI cycle on
//  the instruction memory device, and allows the EU to use the SPI interface to
//  perform data or I/O operations. When the data and I/O operations are
//  complete, the EU can resume instruction fetches by simply performing an 8-
//  bit read from the instruction memory to fetch the next instruction. This
//  saves a minimum of 24 SPI clock cycles (48 processor clock cycles) since a
//  command code and two address bytes are not needed for each instruction
//  fetch. The improvement to the overall performance of the MiniCPU-S is
//  expected to be very significant. However, the performance improvement
//  attained will depend on the number of program branches, data memory
//  operations, and I/O operations that the program performs. The general
//  expectation is that there are more sequential instruction fetches than
//  program branches, and more sequential instructions than data or I/O
//  operations. This means that for each sequential instruction fetch 48
//  processor clock cycles are saved, which allows and/or offsets the cycles
//  required for data or I/O operations.
//
//  Since the SPI memory devices include their own internal memory location
//  pointer, the EU only needs to transfer the value to the instruction memory
//  device when a program branch requires a new SPI cycle to the target device.
//  Because IP is not transferred to the memory device for each instruction
//  fetch, the EU increments the IP during the 8 instruction fetch cycles. This
//  means that when a program branch is encountered, the IP contains the address
//  of the next instruction, assuming that the IP is not otherwise manipulated
//  during the transfer of the memory command code.
//
//  In the MiniCPU-S, all program branches are generally made relative to the
//  IP. With respect to the CALL and JMP instructions, the relative offset is
//  provided by Op, and the address of the target instruction is (IP + Op + 1).
//  With respect to the BEQ and BLT conditional branch instructions, the
//  relative offset is also provided by Op, but whether the branch target
//  address is equal to (IP + Op + 1) or (IP + 0 + 1) is dependent on whether
//  the ALU's TOS register is zero or negative, respectively. The return address
//  for the RTS and RTI instructions is read from the workspace location pointed
//  to by W; the address read is used without modification.
//
//  Data stored in the workspace (local variables and return addresses) is
//  accessed relative to W. A 16-bit data word is read using the LDL, and a 16-
//  bit word is written using STL. The data memory address is W + Op. Since W is
//  the base address and shouldn't be modified, the resulting address is written
//  back into Op as it is calculated, and the value of Op is transmitted to the
//  data memory device as the address during the read/write address transfer
//  operation. Data stored in data memory which is not stored within the
//  workspace is known as non-local data. Like the local variables, the non-
//  local variables are 16-bit values read and written using the LDNL and STNL
//  instructions, respectively. Non-local variables are accessed relative to a
//  pointer in the ALU TOS. The non-local variable address is given as TOS + Op,
//  and is written back into Op as it is computed. Again, the value of Op is
//  transferred to the memory device following the read/write command to set the
//  memory device's address pointer. In both of these cases, the addressed of
//  the variable is computed by the PCU during the SPI command code transfer
//  cycle.
//
//  Four instructions, IN/INB and OUT/OUTB, provide the I/O capabilities of the
//  MiniCPU-S. Like instruction and data memory, the I/O of the MiniCPU-S is
//  attached to the SPI interface controlled by the EU. Unlike the load and
//  store data memory instructions, the I/O instructions provide a mechanism for
//  controlling the operating mode of the SPI interface, and the type of device
//  connected. The least significant 4 bits of the operand register provide the
//  command to the EU regarding the SPI mode, type, and unit number; the
//  MiniCPU-S provides support for 4 SPI I/O units. The SPI commands for memory
//  devices are fixed: 0x03 for reading, 0x02 for writing, and 0x06 for enabling
//  writes for FRAM/MRAM/EEPROMs. On the other hand, SPI I/O devices generally
//  do not adhere to these industry standard command codes. Therefore, the
//  MiniCPU-S SPI I/O architecture assumes that the user loads the ALU TOS
//  register with the device-specific SPI command code in the upper half, and
//  the device-specific register address in the lower half of the ALU TOS
//  register. If the operation is an OUT/OUTB, the Next-On-Stack (NOS) register
//  is loaded with the 16/8-bit output data. The PCU is not directly involved
//  with the command or address transfer for I/O instructions.
//
//  The following table summarizes the address computation and transfer cycles
//  discussed in the preceeding paragraphs which are performed by the PCU.
//  (Note: the address computations for the BEQ and BLT conditional branch
//  instructions shown in the table below assume that the appropriate condition
//  code is true. Otherwise a sequential instruction fetch cycle will occur, and
//  no read command and address transfer cycle is required; simply continue
//  reading from the instruction memory device.)
//
//  ----------------------------------------------------------------------------
//   IR     Mnemonic  -   Command Cycle           |   Address Cycle
//  0x0-  :   PFX     -   none                    |   none
//  0x1-  :   NFX     -   none                    |   none
//  0x2-  :   EXE     -   none                    |   none
//  0x3-  :   LDK     -   none                    |   none
//  0x4-  :   LDL     -   Op <= W + Op            |   Op
//  0x5-  :   LDNL    -   Op <= TOS + Op          |   Op
//  0x6-  :   STL     -   Op <= W + Op            |   Op
//  0x7-  :   STNL    -   Op <= TOS + Op          |   Op
//  0x8-  :   IN      -   none                    |   none
//  0x9-  :   INB     -   none                    |   none
//  0xA-  :   OUT     -   none                    |   none
//  0xB-  :   OUTB    -   none                    |   none
//  0xC-  :   BEQ     -   IP <= IP + Op (Z == 1)  |   IP
//  0xD-  :   BLT     -   IP <= IP + Op (N == 1)  |   IP
//  0xE-  :   JMP     -   IP <= IP + Op           |   IP
//  0xF-  :   CALL    -   IP <= IP + Op           |   IP
//  0x20  :   CLC     -   none                    |   none
//  0x21  :   SEC     -   none                    |   none
//  0x22  :   TAW     -   none                    |   none
//  0x23  :   TWA     -   none                    |   none
//  0x24  :   DUP     -   none                    |   none
//  0x25  :   XAB     -   none                    |   none
//  0x26  :   POP     -   none                    |   none
//  0x27  :   RAS     -   none                    |   none
//  0x28  :   ROR     -   none                    |   none
//  0x29  :   ROL     -   none                    |   none
//  0x2A  :   ADC     -   none                    |   none
//  0x2B  :   SBC     -   none                    |   none
//  0x2C  :   AND     -   none                    |   none
//  0x2D  :   ORL     -   none                    |   none
//  0x2E  :   XOR     -   none                    |   none
//  0x2F  :   HLT     -   none                    |   none
//  0x1020:   RTS     -   none                    |   IP
//  0x1021:   RTI     -   none                    |   IP
//  ----------------------------------------------------------------------------
//
//  The preceeding table shows the address calculations performed by the PCU
//  during the command transfer cycle to instruction or data memory. As shown in
//  the table, only a few basic operations are required. However, the table is
//  incomplete. Not shown in the table are the memory accesses, and therefore
//  the required PCU operations, for pushing the return address of a CALL
//  instruction to the workspace, or for retrieving the return address from the
//  workspace when an RTS or RTI instruction is encountered.
//
//  The CALL instruction requires the pushing of a return address onto the
//  stack. During each instruction fetch cycle, the instruction pointer is
//  incremented. Thus, the value of IP during the execution of phase of the CALL
//  instruction is the return address required. Push and pop operations, in
//  general, require that the stack pointer be adjusted either before or after
//  the operation. The choice whether to pre-decrement or post-decrement to
//  perform the push operation is a design decision.
//
//  The memory organization of the MiniCPU-S is signed, and the instruction set
//  optimized for single byte instructions with positive offsets loaded
//  automatically into Op. Since SPI memory is byte addressable and all stack
//  operations are 16 bits, an offset of -2 is required. The standard MSB shift
//  format of SPI also makes the footprint of the return address in the
//  workspace big-endian. This means that decrementing W during the required two
//  workspace write cycles in the manner used for incrementing IP during
//  instruction fetch cycles will not work because the return address would be
//  stored in little-endian format. Even more importantly, the internal memory
//  address pointers in SPI memory devices only perform increment operations, so
//  two full write command and address transfers would be required to write the
//  return address to the workspace. These restrictions really complicate the
//  handling of a CALL instruction in both the EU and the PCU, and add an
//  unnecessary performance penalty of 50 clock cycles.
//
//  Thus, a separate adjustment cycle to adjust W by ¦2 is required of the PCU
//  to support the push and pop operations required for the CALL and RTS/RTI
//  instructions. The choice is made to pre-decrement W for a push operation, so
//  that W points to the workspace location where the return address if no
//  other adjustments have been made to W by the program. In other words, after
//  a CALL, W points to the return address, and if local variables are required,
//  the programmer must explicitly subtract an amount from W that equals 2x the
//  number of local variables (16-bit words) to allocate on the workspace.
//  (Note: because of the resource restrictions of the target technology for the
//  MiniCPU-S, it is the programmer's responsibility to load the appropriate
//  byte value into the ALU stack. The serial nature of the MiniCPU-s ALU, and
//  the lack of additional resources in the current implementation of the ALU
//  means that having the HW automatically perform the left shift of the operand
//  to convert from byte to word alignment is not possible. If the MiniCPU-S is
//  targeted to a more capable PLD, such as an FPGA, this limitation can be
//  easily removed.)
//
//  During a CALL instruction, IP and Op contain the return address and the
//  offset to the subroutine, respectively. As shown in the table above, the
//  address of the subroutine is IP + Op. Therefore, neither IP nor Op are
//  available as temporary registers when -2 is applied to W. A value of -2 must
//  be provided by the EU to the PCU's serial adder to pre-decrement W before it
//  writes the return address; and it must be provided without the benefit of
//  using Op as a temporary register. Like the address computations required to
//  set up the instruction memory address pointer, the pre-decrement of W can be
//  performed during the workspace memory command transfer cycle, and then W can
//  be shifted out as the address to the workspace memory device. Following the
//  write of the return address to the workspace, the EU will initiate a new
//  read of the instruction memory. During those cycles (refer to the preceeding
//  table), the instruction memory target address is computed and shifted out to
//  the instruction memory device. During the instruction fetch which follows
//  the address transfer, IP is incremented. These two complete SPI cycles,
//  workspace write and instruction read, is how the EU executes the CALL
//  instruction and fetches the first instruction of the subroutine.
//
//  During a return, RTS or RTI, W is expected to point to the MSB of the return
//  address. This means that the programmer has adjusted W for whatever number
//  of local variables the subroutine allocated in the workspace below (more
//  negatively) the return address. Following the retrieval of the return
//  address from the workspace location pointed to by W, W should point to the
//  next 16-bit location in the workspace. This could be accomplished by a
//  separate adjustment cycle. Instead, it will be accomplished using the same
//  process as is used to increment IP during the instruction fetch cycles.
//  Thus, during the first fetch cycle from workspace which returns the 8 MSBs
//  of the return address, W is incremented by 1. During the second fetch  cycle
//  used to retrieve the 8 LSBs of the return address, W is incremented a second
//  time. These two increment cycles yield the desired adjustment of W, so that
//  at the completion of the two workspace reads, W is pointing at the workspace
//  of the calling subroutine. Therefore, like the CALL instruction, the EU
//  performs to SPI transfer cycles, workspace read and instruction read, when
//  it encounters a return instruction. During the workspace read, the EU reads
//  two consecutive bytes which are shifted directly MSB first into IP by the
//  PCU, and simultaneously, the EU has the PCU increment W twice. Following the
//  reading of the return address from the workspace, the EU initiates an new
//  instruction memory read cycle to retrieve the instruction following the CALL
//  instruction.
//
//  Missing from the description of the PCU to this point is a discussion of the
//  operation of Op. From an operand perspective, Op provides a 16-bit register
//  for constants to be loaded into the ALU by the LDK instruction. The SPI I/O
//  instructions, IN/INB and OUT/OUTB, also use Op, but the least significant 4
//  bits directly control the SPI mode, device type, and unit number. With the
//  load/store (LDL/LDNL and STL/STNL) and branch (BEQ/BLT, JMP, CALL, and
//  RTS/RTI) instructions, Op provides an index/relative offset.
//
//  There are several rules which apply to Op in the MiniCPU-S architecture.
//  First, Op is only loaded from the instruction stream using direct
//  instructions, i.e. an instruction whose opcode is taken directly from IR
//  rather than indirectly via Op. Second, all instructions, with the exception
//  of PFX and NFX, clear Op at the completion of the instruction. Thus, except
//  after PFX/NFX, the value of Op is always the least significant 4 bits of the
//  8-bit instruction fetched from memory. Successive PFX/NFX instructions shift
//  four bits into Op, and the final four bits is provided by the 4 LSBs of a
//  direct instruction.
//
//  The 8-bit instruction is fetched from memory MSB first. The EU shifts the
//  first four bits into IR, and the next four bits into Op. However, if the IR
//  just loaded is an NFX instruction, then both the current contents of Op and
//  the new SPI data are complemented during the shift operation. To clear Op,
//  16 zeroes need to be shifted into its LSB. Since the PCU registers operate
//  in a manner similar to those of the ALU, all three registers shift when any
//  operation requires one or more to shift. Using this characteristic, it is
//  easy for the EU to clear Op using an operation involving Op or one of the
//  other two PCU registers. As shown in the table above, Op is also used as a
//  temporary register to hold memory addresses for the LDL/LDNL and STL/STNL
//  instructions. Op is cleared as its temporary memory address is shifted out
//  to the data memory device.
//
//  In regards to the SPI I/O mode, type, and unit number in the 4 LSBs of Op,
//  these four bits are duplicated in the EU. Thus, during SPI I/O operations,
//  Op can be cleared without any concerns about losing the SPI control
//  settigs. Finally, shifts into Op from the SPI MISO input are enabled by the
//  EU after the IR has been filled. In this way, the EU is able to set the Op
//  shift controls to complement the input (MISO) and the bits already in the
//  operand register when an NFX instruction is loaded.
//
// Dependencies:    none
//
// Revision:
//
//  0.00    12I21   MAM     Initial creation
//
//  0.10    12I23   MAM     Completion of the description section
//
//  0.11    12I24   MAM     Added clarification of the operation of the operand
//                          register with respect to the NFX instruction.
//
//  0.20    12I27   MAM     Completed and implemented initial coding. Operation
//                          limited to 24 MHz. Set implementation tool settings
//                          to the default collapsing input and pterm limits,
//                          and result was a dramatic increase in predicted
//                          operating speed to ~42 MHz. Applied same settings to
//                          latest version of the Serial ALU, and its predicted
//                          operating speed went from ~42 MHz to ~76 MHz. 
//
//  0.21    12I28   MAM     Restructured inputs and logic blocks to support
//                          independent adders and control for each PCU register
//                          in an attempt to improve overall performance. With
//                          implementation settings set to defaults, the new
//                          predicted operating speed is ~77 MHz. New approach
//                          to control increases the number of control inputs,
//                          but it simplifies the control of simultaneous
//                          operations on PCU registers and reduces the number
//                          of additional multiplexers required to handle the
//                          special cases previously required.
//
//  0.22    12I29   MAM     Simulation was developed. During development of 
//                          tests specific to IP increment, it became clear that
//                          this operation's simultaneous use with other
//                          operations meant that the EU could not supply +1 to
//                          the PCU using the PCU_DI input while that input was
//                          being used to transfer an operand from the ALU. For
//                          this reason, the PCU's IP_Plus_1, W_Plus_1, and
//                          W_Minus_2 operations were modified so that the old
//                          PCU_FirstCycle (replaced by PCU_Inc) signal would
//                          function as the +1 operand. (The-2 is derived from
//                          +1 by the 1's complement of PCU_Inc control input.)
//
//  0.23    12I30   MAM     Changed the operation of the output multiplexer.
//                          Previously, the PCU register enables and operation
//                          selects were used to select the register to output
//                          on PCU_DO. A new control was added, PCU_OE, and this
//                          is used to select one of the three PCU registers.
//                          Direct control of PCU_DO works better than indirect
//                          control.
//
//  Additional Comments:
//
//  Examining the operations ascribed to the PCU in the description provided
//  above, there are a limited number of operations which are required:
//
//  ( 1) IP_In      : load the return address (RTS/RTI)
//  ( 2) IP_Out     : push return address (CALL), or initiate instruction read
//  ( 3) IP_Plus_1  : increment IP during instruction fetch
//  ( 4) IP_Plus_Op : compute target address of program branch (CALL/JMP/Bxx)
//  ( 5) W_In       : load W from TOS (TAW)
//  ( 6) W_Out      : transfer W to TOS (TWA), or initiate SPI workspace rd/wr
//  ( 7) W_Plus_1   : increment W during read of return address (RTS/RTI)
//  ( 8) W_Minus_2  : decrement W prior to writing return address to workspace
//  ( 9) Op_Out     : output Op to load ALU TOS (LDK), or access data memory
//  (10) Op_Plus_W  : compute workspace address (LDL/STL)
//  (11) Op_Plus_A  : compute data memory address (LDNL/STNL)
//
//  The 11 PCU operations listed above will use a common enable and a 4-bit
//  command input controlled by the EU. Simultaneous to several of the listed
//  operations, Op must be loaded from the SPI data stream or cleared to adhere
//  to the MiniCPU-S architecture requirements. Since loading Op from the SPI
//  data stream is a synchronous operation, Op also requires a separate enable
//  input and control input. When one of the operations shown above, which does
//  not involve Op, is being performed, the separate Op enable and control
//  inputs become active. Op can then be loaded from the SPI data stream, or
//  cleared. If being loaded from the SPI data stream, the SPI input data and Op
//  can be inverted as required by NFX using the dedicated Op_Inv control input.
//  When Op is an element of a PCU operation as shown the above list, then the
//  dedicate Op inputs are not used, and the normal module enable input is used
//  for the operation.
//
//  Direct implementation of the above 11 operations leads to implementation
//  problems when attempting to load Op simultaneously with the increment of IP.
//  Most of these issues can be addressed more readily if separate enables are
//  provided for each of the PCU registers: IP, W, and Op. In addition, the 
//  performance of the PCU can also be improved if separate adders are used
//  instead of the single common adder used in the ALU. The multiplexers needed
//  to potentially implement two simultaneous operations in the PCU dramatically
//  reduce the operating speed that the target XC9572-7PC44 can achieve.
//
//  Thus, the control inputs were refactored into three 3-bit ports; one for 
//  each PCU component. In addition, a common input was added to suppress any 
//  carry remaining in the carry register associated with each serial adder, and 
//  an additional input, specific to the operand register, was added to 
//  implement the complement of the register on the last Op bit shifted in 
//  during an NFX instruction. The implementation results for the PCU with these 
//  modifications results in FF-FF timing in excess of 76 MHz. This is much 
//  faster than the previous best case achieved with the ALU of 42 MHz.
//
//  A final note regarding the interaction between the PCU and EU in order to
//  the increment (+1) operations on IP and W, and the decrement (-2) operation
//  on W. The EU is expected to drive the PCU_DI input with either the data from
//  the SPI memory, or with a 1. When the SPI input is driven onto the PCU_DI
//  input, the expectation is that the PCU is performing a subroutine return, or
//  loading the operand register. In the former case, the PCU_DI input is loaded
//  into IP, and in the latter case, PCU_DI is loaded into Op. In the latter
//  case, the EU will only assert Op_En during the last four bits of the
//  instruction fetch. If the first four bits of the instruction fetch, which
//  are loaded by the EU into the instruction register (implemented in the EU)
//  are an NFX instruction, then on last bit of the instruction fetch, the EU
//  will assert Op_Inv to force Op to be complemented in compliance with the
//  specification of the NFX instruction. 
//
//  The EU drives the PCU_DI input signal with +1 when an increment or decrement
//  of IP or W is required. During the first cycle of these operations, the EU
//  also asserts the PCU_FirstCycle input to the PCU. This causes any carry out
//  from the last serial sum to be ignored during the initial cycle of any PCU
//  arithmetic operation. This means the PCU_DI == 1 is the +1 value required to
//  increment the IP or W when required. If a decrement is required, the PCU 
//  simply complements the data received from the EU on the PCU_DI input. Since
//  the carry is suppressed, the complement of a +1 is equivalent to a -2, and
//  it is in this manner that the EU can perform a +1 operation on IP and/or W,
//  and a -2 operation on W. (Note: the transfer of +1/-2 operands between the
//  EU and PCU has been modified. See revision 0.22 above. In all other respects
//  these operations perform as discussed in these last few paragraphs.)
//
////////////////////////////////////////////////////////////////////////////////

//`define DEBUG   // Enable Test Port of UUT

module MiniCPU_SerPCU #(
    parameter N = 16
)(
    input   Rst,                // System Reset
    input   Clk,                // System Clock

    input   IP_En,              // PCU IP Enable
    input   [1:0] IP_Op,        // PCU IP Operation
    
    input   W_En,               // PCU W Enable
    input   [1:0] W_Op,         // PCU W Operation
    
    input   Op_En,              // PCU Op Enable
    input   [1:0] Op_Op,        // PCU Op Operation
    input   Op_Inv,             // PCU Op Invert (Last cycle of NFX)

    input   PCU_Inc,            // PCU Increment IP, W (asserted on first cycle)
    input   [1:0] PCU_OE,       // PCU Data Output Enable: 2 - Op, 3 - IP
    
    input   ALU_DI,             // ALU Serial Output (Output from ALU)
    input   PCU_DI,             // PCU Serial Input

`ifndef DEBUG
    output  reg PCU_DO          // PCU Serial Output
`else
    output  reg PCU_DO,         // PCU Serial Output
    output  [47:0] TstPort      // PCU Debug Port
`endif
);

////////////////////////////////////////////////////////////////////////////////
//
//  Local Parameters
//

`include "MiniCPU_SerPCU.txt"

////////////////////////////////////////////////////////////////////////////////
//
//  Declarations
//

reg     [(N - 1):0] IP, W, Op;  // PCU Registers

reg     IP_Ai, IP_Bi;           // IP Serial Adder Data Inputs
wire    IP_Ci;                  // IP Serial Adder Carry Input
wire    IP_Co, IP_Sum;          // IP Serial Adder Carry Output, Sum
reg     IP_Cy;                  // IP Serial Adder Carry Output Register

reg     W_Ai, W_Bi;             // W  Serial Adder Data Inputs
wire    W_Ci;                   // W  Serial Adder Carry Input
wire    W_Co, W_Sum;            // W  Serial Adder Carry Output, Sum
reg     W_Cy;                   // W  Serial Adder Carry Output Register

reg     Op_Ai, Op_Bi;           // Op Serial Adder Data Inputs
wire    Op_Ci;                  // Op Serial Adder Carry Input
wire    Op_Co, Op_Sum;          // Op Serial Adder Carry Output, Sum
reg     Op_Cy;                  // Op Serial Adder Carry Output Register

////////////////////////////////////////////////////////////////////////////////
//
//  Implementation
//

//  Debug Port for testing with self-checking testbench

`ifdef DEBUG
assign TstPort[47:32] = IP;
assign TstPort[31:16] = W;
assign TstPort[15: 0] = Op;
`endif

////////////////////////////////////////////////////////////////////////////////
//
//  Instruction Pointer (IP) Logic
//

//  IP Serial Adder

assign IP_Ci = ((PCU_Inc) ? 0 : IP_Cy);

always @(*)
begin
    case(IP_Op)
        pIP_Plus_1  : {IP_Bi, IP_Ai} <= {IP_En & IP[0], IP_En & PCU_Inc};
        pIP_Plus_Op : {IP_Bi, IP_Ai} <= {IP_En & IP[0], IP_En & Op[0]  };
        default     : {IP_Bi, IP_Ai} <= {1'b0,  1'b0};
    endcase
end

assign IP_Sum = (IP_Bi ^ IP_Ai ^ IP_Ci);
assign IP_Co  = ((IP_Bi & IP_Ai) | ((IP_Bi ^ IP_Ai) & IP_Ci));

//  IP Carry Register

always @(posedge Clk)
begin
    if(Rst)
        IP_Cy <= #1 0;
    if(IP_En)
        IP_Cy <= #1 IP_Co;
end

//  Instruction Pointer

always @(posedge Clk)
begin
    if(Rst)
        IP <= #1 0;
    else if(IP_En)
        case(IP_Op)
            pIP_Out     : IP <= #1 {IP[(N - 2):0], IP[(N - 1)]  };
            pIP_In      : IP <= #1 {IP[(N - 2):0], PCU_DI       };
            pIP_Plus_1  : IP <= #1 {IP_Sum,        IP[(N - 1):1]};
            pIP_Plus_Op : IP <= #1 {IP_Sum,        IP[(N - 1):1]};
            default     : IP <= #1 IP;
        endcase
end

////////////////////////////////////////////////////////////////////////////////
//
//  Workspace Pointer (W) Logic
//

//  W Serial Adder

assign W_Ci = ((PCU_Inc) ? 0 : W_Cy);

always @(*)
begin
    case(W_Op)
        pW_Plus_1  : {W_Bi, W_Ai} <= {W_En & W[0], W_En &  PCU_Inc};
        pW_Minus_2 : {W_Bi, W_Ai} <= {W_En & W[0], W_En & ~PCU_Inc};
        default    : {W_Bi, W_Ai} <= {1'b0,  1'b0};
    endcase
end

assign W_Sum = (W_Bi ^ W_Ai ^ W_Ci);
assign W_Co  = ((W_Bi & W_Ai) | ((W_Bi ^ W_Ai) & W_Ci));

//  W Carry Register

always @(posedge Clk)
begin
    if(Rst)
        W_Cy <= #1 0;
    if(W_En)
        W_Cy <= #1 W_Co;
end

//  Workspace Pointer

always @(posedge Clk)
begin
    if(Rst)
        W <= #1 0;
    else if(W_En)
        case(W_Op)
            pW_Out     : W <= #1 {W[(N - 2):0], W[(N - 1)]  };  // Shift Left
            pW_In      : W <= #1 {W[(N - 2):0], ALU_DI      };  // Shift Left
            pW_Plus_1  : W <= #1 {W_Sum,        W[(N - 1):1]};  // Shift Right
            pW_Minus_2 : W <= #1 {W_Sum,        W[(N - 1):1]};  // Shift Right
        endcase
end

////////////////////////////////////////////////////////////////////////////////
//
//  Operand Register (Op) Logic
//

//  Op Serial Adder

assign Op_Ci = ((PCU_Inc) ? 0 : Op_Cy);

always @(*)
begin
    case(Op_Op)
        pOp_Plus_A : {Op_Bi, Op_Ai} <= {Op_En & Op[0], Op_En & ALU_DI};
        pOp_Plus_W : {Op_Bi, Op_Ai} <= {Op_En & Op[0], Op_En & W[0]  };
        default    : {Op_Bi, Op_Ai} <= {1'b0,  1'b0};
    endcase
end

assign Op_Sum = (Op_Bi ^ Op_Ai ^ Op_Ci);
assign Op_Co  = ((Op_Bi & Op_Ai) | ((Op_Bi ^ Op_Ai) & Op_Ci));

//  Op Carry Register

always @(posedge Clk)
begin
    if(Rst)
        Op_Cy <= #1 0;
    if(Op_En)
        Op_Cy <= #1 Op_Co;
end

//  Operand Register

always @(posedge Clk)
begin
    if(Rst)
        Op <= #1 0;
    else if(Op_En)
        case(Op_Op)
            pOp_Out    : Op <= #1 ((IP_En ) ?  {1'b0, Op[(N - 1):1]}     // >> 1
                                            :  {Op[(N - 2):0], 1'b0}  ); // << 1
            pOp_In     : Op <= #1 ((Op_Inv) ? ~{Op[(N - 2):0], PCU_DI}   // << 1
                                            :  {Op[(N - 2):0], PCU_DI}); // << 1
            pOp_Plus_A : Op <= #1 {Op_Sum, Op[(N - 1):1]};  // Shift Right
            pOp_Plus_W : Op <= #1 {Op_Sum, Op[(N - 1):1]};  // Shift Right
        endcase
end

////////////////////////////////////////////////////////////////////////////////
//
//  PCU Data Output Multiplexer
//

assign Op_LSB = (IP_Op == pIP_Plus_Op);

always @(*)
begin
    case(PCU_OE)
        pOE_W   : PCU_DO <=  W[(N - 1)];    // Transfer W to A
        pOE_Op  : PCU_DO <= ((Op_LSB) ? Op[0] : Op[(N - 1)]); // Data/Addresses
        pOE_IP  : PCU_DO <= IP[(N - 1)];    // Branch/Return Addresses
        default : PCU_DO <= 0;
    endcase
end

endmodule
