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
Control Unit (PCU) is in development.

The reference target for the MiniCPU-S are Xilinx XC95xxx CPLDs, although the
RTL is not restricted to that family. The RTL for the serial ALU of the MiniCPU-S,
written in Verilog, has been targeted to the XC9572-7PC44 device. A 16-bit version
of the serial ALU fits into that device with 100% utilization of the macrocells 
in that device. The RTL has also been fitted to devices in the Xilinx XC9500XL
and XC2R Coolrunner II CPLD families, and the Xilinx Spartan 3AN FPGA family.

Instruction Set 
---------------

The MiniCPU-S currently implements an instruction set consisting of only 33 defined
instructions. The architecture of the MiniCPU-S determines the capabilities that
the instruction set can support. With the target PLD architecture being the XC9500
CPLDs, the architecture of the MiniCPU-S is restricted to one which is not register
rich. Another restriction to the MiniCPU-S' architecture is the requirement that
the implementation fit into one or two XC9572-xPC84 or XC95108-xPC84 devices.

With these two restrictions in mind, an initial instruction set was defined using
the architectures of the Microchip PIC, Inmos T212, and WDC65C02 as references. 
The result is a 0 address ALU like that of the Inmos T212, with a minimal number of
instructions like the PIC processors, and the adder/subtractor architecture of the
WDC65C02 to enable multi-precision additions/subtractions (unlike the T212).

MiniCPU-S instructions consist of two components: {I[3:0], Op[3:0]}. Each 8-bit
value fetched from instruction memory consists of these two components. I[3:0]
provides the CPU instruction to be performed during the execution phase. Op[3:0]
provides the least significant 4 bits of an operand register. The operand register
is used to provide any constants fetched from instruction memory. The operand
register is the only way to specify data constants, and subroutine and branch
addresses. In addition, the operand register may also be loaded with a value that
represents the operation code for an indirectly executed instruction.

To manipulate the operand register, two instructions are required: Negative Prefix
(NFX), and Prefix (PFX). These two instructions insert the Op[3:0] from the instructions
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
from a workspace pointer which provides the functionality of a external data memory
stack pointer. Thus, the workspace pointer, if appropriately adjusted to allocate
local variables, provides workspace pointer relative (stack pointer indexed)
addressing of the first 16 of these variables in a single byte instruction.

The programmer visible/accessible registers of the MiniCPU-S are:

    I   :   Instruction pointer (not directly accessible)
    W   :   Workspace pointer
    Op  :   Operand register
    A   :   ALU register stack Top-Of-Stack (TOS)
    B   :   ALU register stack Next-On-Stack (NOS)
    C   :   ALU register stack Bottom-Of-Stack (BOS)
    Cy  :   ALU carry register

All of these registers are the same width except Cy, which is a bit register.

A summary of the MiniCPU-S instruction set is provided in the following table:

    0x0-    :   CALL    --  Call subroutine (instruction pointer relative)
    0x1-    :   LDK     --  Load constant
    0x2-    :   LDL     --  Load local (workspace relative)
    0x3-    :   LDNL    --  Load non-local (TOS pointer relative)
    0x4-    :   STL     --  Store local (workspace relative)
    0x5-    :   STNL    --  Store non-local (TOS pointer relative)
    0x6-    :   NFX     --  Negative prefix (load, complement, shift left Op)
    0x7-    :   PFX     --  Prefix (load, shift left Op)
    0x8-    :   IN      --  Input word from SPI peripheral
    0x9-    :   INB     --  Input byte from SPI peripheral
    0xA-    :   OUT     --  Output word to SPI peripheral
    0xB-    :   OUTB    --  Output byte to SPI peripheral
    0xC-    :   BEQ     --  Branch if (TOS == 0)
    0xD-    :   BLT     --  Branch if (TOS < 0)
    0xE-    :   JMP     --  Unconditional jump (instruction pointer relative)
    0xF-    :   EXE     --  Execute Op as indirect instruction
    0xF0    :   CLC     --  Clear carry
    0xF1    :   SEC     --  Set carry
    0xF2    :   TAW     --  Transfer A to W 
    0xF3    :   TWA     --  Transfer W to A 
    0xF4    :   DUP     --  Duplicate A 
    0xF5    :   XAB     --  Exchange A and B
    0xF6    :   POP     --  Pop A
    0xF7    :   RAS     --  Roll ALU stack: A => C; C => B; B => A;
    0xF8    :   ROR     --  Rotate A right (by mask in B) and set C
    0xF9    :   ROL     --  Rotate A left (by mask in B) and set C
    0xFA    :   ADC     --  Add with carry: A = B + A + Cy
    0xFB    :   SBC     --  Subtract with carry: A = B + ~A + Cy
    0xFC    :   AND     --  Logical AND: A = B & A
    0xFD    :   ORL     --  Logical OR:  A = B | A
    0xFE    :   XOR     --  Logical XOR: A = B ^ A
    0xFF    :   HLT     --  Halt processor
    0x60F0  :   RTS     --  Return from subroutine
    0x60F1  :   RTI     --  Return from interrupt
    
Implementation
--------------

The implementation of the serial ALU for the MiniCPU-S is provided in the following
three Verilog source files:

    MiniCPU_SerALU.v            -- RTL source file for the Serial ALU
        MiniCPU_SerALU.txt      -- include file instruction set localparams
        tb_MiniCPU_SerALU.v     -- Rudimentary self-checking testbench

Synthesis
---------

The objective is for the MiniCPU-S to fit into one or two XC9572-xPC84 or XC95108-xPC84
devices. The MiniCPU-S serial ALU provided at this time meets that objective by
fitting into a single XC9572-xPC44 device. Special synthesis constraints to achieve
the fit are: (1) keep hierarchy - NO; (2) collapsing input limit - 20/21; (3) collapsing
p-term limit - 7. Other synthesis, translation, and fitting parameters can be set 
to the defaults given for the ISE 10.1i SP3 CPLD fitter. 

The ISE 10.1i SP3 implementation results are as follows:

    Number Macrocells Used:              72/72  (100%)
    Number P-terms Used:                335/360 ( 93%)
    Number Registers Used:               49/72  ( 69%)
    Number of Pins Used:                 14/34  ( 42%)
    Number Function Block Inputs Used:  132/144 ( 92%)
    
    Best Case Achievable (XC9572-7):    26.000 ns period (38.462 MHz)

Status
------

Definition and documentation of the instruction set is complete. Design of the
serial ALU is complete. Initial verification of the serial ALU is complete. Design
and implementation of the MiniCPU-S PCU is underway.  