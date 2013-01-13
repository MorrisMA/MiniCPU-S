MiniCPU-S : Minimal CPU in Verilog
=======================

Copyright (C) 2012, Michael A. Morris <morrisma@mchsi.com>.
All Rights Reserved.

Released under LGPL.

General Description
-------------------

This project is provides a minimal CPU implementation targeted at CPLDs. Memory
and I/O will be supported using SPI-compatible standard serial EEPROMS and FRAMs, and
standard or custom serial I/O devices.

In its current state, the instruction set for the MiniCPU-S has been defined and
the initial release of the MiniCPU-S System Design Description has been made.
The MiniCPU-S serial ALU has been coded, tested, and released. The MiniCPU-S Program
Control Unit (PCU) has been coded, tested, and released.

The reference target for the MiniCPU-S are Xilinx XC95xxx CPLDs, although the
RTL is not restricted to that family. The RTL for the Serial ALU of the MiniCPU-S,
written in Verilog, has been targeted to the XC9572-7PC44 device. A 16-bit version
of the Serial ALU fits into that device with 71% utilization of the macrocells
in that device. The Serial PCU also fits into an XC9572-7PC44 device with only 73%
utilization of macrocells. (The synthesis and fitting parameters are the same for
both of these MiniCPU-S components.) The RTL has also been fitted to devices in the
Xilinx XC9500XL and XC2R Coolrunner II CPLD families, and the Xilinx Spartan 3AN
FPGA family.

Instruction Set
---------------

The MiniCPU-S currently implements an instruction set consisting of only 33 defined
instructions. The architecture of the MiniCPU-S determines the capabilities that
the instruction set can support. With the target PLD architecture being the XC9500
CPLDs, the architecture of the MiniCPU-S is restricted to one which is not register
rich. Another restriction used to determine the MiniCPU-S' architecture is the desire
that the implementation fit into one or two XC9572-xPC84 or XC95108-xPC84 devices.
(It is clear that this desire will be unfufilled. The MiniCPU-S architecture will
fit very nicely into three or four X9572-xPC44 CPLDs, but the resource utilization
is such that a complete MiniCPU-S will not fit into two XC95108-xPC84 devices.)

With these two restrictions in mind, an initial instruction set was defined using
the architectures of the Microchip PIC, Inmos T212, and WDC65C02 as references.
The result is a 0 address ALU like that of the Inmos T212, with a minimal number of
instructions like the PIC processors, and the adder/subtracter architecture of the
WDC65C02 to enable multi-precision additions/subtractions (unlike the T212).

MiniCPU-S instructions are 8 bits in width and consist of two components:
{I[3:0], Op[3:0]}. Each 8-bit value fetched from instruction memory consists of
these two components. I[3:0] provides the direct CPU instruction to be performed
during the execution phase. Op[3:0] provides the least significant 4 bits of an
operand register. The operand register is used to provide any constants or address
offsets which are fetched from instruction memory. The operand register is the only
way to specify data constants, and subroutine and branch addresses.

With only 4 bits, I[3:0], specifying a direct operation, the operand register is
used to specify an indirect instruction. The operand register is loaded with a value
that represents the operation code for an indirectly executed instruction. One direct
instruction is used to "execute" the indirect operation specified by the contents of
the operand register. This approach allows the instruction set of the MiniCPU-S to
be extended to whatever level is desired.

To manipulate the operand register, two instructions are required: Negative Prefix
(NFX), and Prefix (PFX). These two instructions insert the Op[3:0] from the instruction's
memory fetch value and shift the operand register 4 places left (in preparation
for the next instruction). NFX complements the operand register during the shift,
and PFX does not. All other instructions will clear the operand register when they
complete. Thus, NFX and PFX perform a function like the Intel Architecture (IA)
segment register override prefixes. Therefore, depending on the value of the constant
or relative offsets (program branches use instruction pointer relative addressing)
that must be loaded, the number of NFX/PFX instructions required to appropriately
preload the operand register may vary from 1 to 3; the final 4 bits required will
be contained in instruction. This means that for short forward branches and jumps,
the relative offset required is contained in a single byte instruction. All branches
and jumps less than ±256 can be encoded in two bytes: NFX/PFX, CALL/BEQ/BLT/JMP.

As indicated above, all addresses are relative to the instruction pointer, but also
from a workspace pointer which provides the functionality of an external data memory
stack pointer. Thus, the workspace pointer, if appropriately adjusted to allocate
local variables, provides workspace pointer relative (stack pointer indexed)
addressing of the first 16 of these variables in a single byte instruction.

The programmer visible/accessible registers of the MiniCPU-S are:

    I   :   Instruction pointer (program counter) (not directly accessible)
    W   :   Workspace pointer (stack pointer)
    Op  :   Operand register (relative addresses, constants, and indirect instructions)
    A   :   ALU register stack Top-Of-Stack (TOS)
    B   :   ALU register stack Next-On-Stack (NOS)
    C   :   ALU register stack Bottom-Of-Stack (BOS) (sticky)
    Cy  :   ALU carry register

All of these registers are the same width (16 bits) except Cy, which is a bit register.

A summary of the MiniCPU-S instruction set is provided in the following table:

    0x0-    :   PFX     --  Prefix (load, shift left Op)
    0x1-    :   NFX     --  Negative prefix (load, complement, shift left Op)
    0x2-    :   EXE     --  Execute Op as indirect instruction
    0x3-    :   LDK     --  Load constant
    0x4-    :   LDL     --  Load local (workspace relative)
    0x5-    :   LDNL    --  Load non-local (TOS pointer relative)
    0x6-    :   STL     --  Store local (workspace relative)
    0x7-    :   STNL    --  Store non-local (TOS pointer relative)
    0x8-    :   IN      --  Input word from SPI peripheral
    0x9-    :   INB     --  Input byte from SPI peripheral
    0xA-    :   OUT     --  Output word to SPI peripheral
    0xB-    :   OUTB    --  Output byte to SPI peripheral
    0xC-    :   BEQ     --  Branch if (TOS == 0)
    0xD-    :   BLT     --  Branch if (TOS < 0)
    0xE-    :   JMP     --  Unconditional jump (instruction pointer relative)
    0xF-    :   CALL    --  Call subroutine (instruction pointer relative)
    0x20    :   CLC     --  Clear carry
    0x21    :   SEC     --  Set carry
    0x22    :   TAW     --  Transfer A to W
    0x23    :   TWA     --  Transfer W to A
    0x24    :   DUP     --  Duplicate A
    0x25    :   XAB     --  Exchange A and B
    0x26    :   POP     --  Pop A
    0x27    :   RAS     --  Roll ALU stack: A => C; C => B; B => A;
    0x28    :   ROR     --  Rotate A right (by mask in B) and set C
    0x29    :   ROL     --  Rotate A left (by mask in B) and set C
    0x2A    :   ADC     --  Add with carry: A = B + A + Cy
    0x2B    :   SBC     --  Subtract with carry: A = B + ~A + Cy
    0x2C    :   AND     --  Logical AND: A = B & A
    0x2D    :   ORL     --  Logical OR:  A = B | A
    0x2E    :   XOR     --  Logical XOR: A = B ^ A
    0x2F    :   HLT     --  Halt processor
    0x1020  :   RTS     --  Return from subroutine
    0x1021  :   RTI     --  Return from interrupt

Implementation
--------------

The implementation of the serial ALU for the MiniCPU-S is provided in the following
three Verilog source files:

    MiniCPU_SerALU.v            -- RTL source file for the Serial ALU
        MiniCPU_SerALU.txt      -- include file instruction set localparams
        tb_MiniCPU_SerALU.v     -- Rudimentary self-checking testbench

The implementation of the serial PCU for the MiniCPU-S is provided in the following
three Verilog source files:

    MiniCPU_SerPCU.v            -- RTL source file for the Serial PCU
        MiniCPU_SerPCU.txt      -- include file instruction set localparams
        tb_MiniCPU_SerPCU.v     -- Rudimentary self-checking testbench

Synthesis
---------

The objective is for the MiniCPU-S to fit into one or two XC9572-xPC84 or XC95108-xPC84
devices. The MiniCPU-S serial ALU provided at this time meets that objective by
fitting into a single XC9572-xPC44 device. Special synthesis constraints to achieve
the fit are:

    Device(s) Specified                         : xc9572-7-PC44
    Optimization Method                         : SPEED
    Multi-Level Logic Optimization              : ON
    Ignore Timing Specifications                : OFF
    Default Register Power Up Value             : LOW
    Keep User Location Constraints              : ON
    What-You-See-Is-What-You-Get                : OFF
    Exhaustive Fitting                          : ON
    Keep Unused Inputs                          : OFF
    Slew Rate                                   : FAST
    Power Mode                                  : STD
    Ground on Unused IOs                        : OFF
    Global Clock Optimization                   : ON
    Global Set/Reset Optimization               : ON
    Global Output Enable Optimization           : ON
    FASTConnect/UIM optimization                : ON
    Local Feedback                              : ON
    Pin Feedback                                : ON
    Input Limit                                 : 36
    Pterm Limit                                 : 50

Other synthesis, translation, and fitting parameters can be set to the defaults
given for the ISE 10.1i SP3 CPLD fitter.

The ISE 10.1i SP3 implementation results for the Serial ALU are as follows:

    Number Macrocells Used:              51/72  ( 71%)
    Number P-terms Used:                325/360 ( 91%)
    Number Registers Used:               49/72  ( 69%)
    Number of Pins Used:                 13/34  ( 39%)
    Number Function Block Inputs Used:  126/144 ( 88%)

    Best Case Achievable (XC9572-7PC44): 14.000 ns period (71.429 MHz)

The ISE 10.1i SP3 implementation results for the Serial PCU are as follows:

    Number Macrocells Used:              52/72  ( 73%)
    Number P-terms Used:                243/360 ( 68%)
    Number Registers Used:               51/72  ( 71%)
    Number of Pins Used:                 18/34  ( 53%)
    Number Function Block Inputs Used:   99/144 ( 69%)

    Best Case Achievable (XC9572-7PC44): 14.000 ns period (71.429 MHz)

Status
------

Definition and documentation of the instruction set is complete. Design of the
Serial ALU is complete. Initial verification of the Serial ALU is complete. Design
and implementation of the MiniCPU-S PCU is complete. Verification of the Serial
PCU is underway; expect to complete Serial PCU verification soon.

Other Notes
-----------

Integration of the two modules into a single CPLD has been completed. This effort
resulted in some changes to the operation of some instructions in the Serial ALU
module. In general, the shift direction for all direct instructions was set as MSB
first, and the shift direction for all indirect instructions was set for LSB first.
This change was implemented in order to allow the non-local base address in the ALU
TOS (A) to be shifted into the Serial PCU and summed with the operand register to
form the non-local memory address. With the previous default shift direction of MSB
first for all instructions, to compute the non-local address would have required
a holding register for the non-local base address in the Serial PCU and another
cycle to compute the final non-local address. Thus, the default shift direction
for the direct instructions was set to MSB first, and the shift direction of the
indirect instructions was set for LSB first. This allows the indirect POP instruction
to be used by the EU to sum the relative offset in Op and the base in A in a single
cycle. The final non-local address is left in Op, and the ALU stack is cleaned up
automatically.

Some other optimizations were included when this change was implemented. First,
the Cy and A registers were separated into separate always blocks. Second, each
ALU register's definition was changed from one that used the localparams defined
in the include file to one that was explicitly and fully defined. This means that
the case statements no longer require a default selection. Since a number of
instructions never use the ALU, some encoding of these operations to allow additional
logic optimization by the synthesizer was used to reduce the number of p-terms used
and maintain the performance of the module.
