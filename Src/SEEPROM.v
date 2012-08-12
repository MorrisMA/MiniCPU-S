`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Company:         M. A. Morris & Associates 
// Engineer:        Michael A. Morris 
// 
// Create Date:     13:16:25 08/03/2012 
// Design Name:     Serial Electrically Erasable Programmable Read-Only Memory 
// Module Name:     SEEPROM.v 
// Project Name:    C:\XProjects\VerilogComponents\SEEPROM 
// Target Devices:  None 
// Tool versions:   ISE10.1 SP3
// 
// Description:
//
//  This module provides a synthesizable model of an industry standard SEEPROM.
//  As implemented, the module provides a parameterized RTL SEEPROM model to be
//  for simulation and testing of SPI-based memory interfaces. As a model for
//  a 4-wire SPI Serial EEPROM, the model allows the parameterization of various
//  instructions, manufacturer and device ID functions, programming delay time,
//  and other parameters. The model is intended to be used with an external data
//  file so that the full capabilities of the model may be used. 
//
// Dependencies:    none
//
// Revision:
//
//  0.00    12H03   MAM     Initial creation
//
//  0.01    12H04   MAM     Continue entry. Completed initial entry of the
//                          SPI interface, PROM, Command and Status registers.
//
//  0.02    12H05   MAM     Instantiated Rdy module, and added Rdy to the regis-
//                          ter enable signals. Thus, while Hold is asserted,
//                          the SPI and all related control logic is suspended.
//
// Additional Comments: 
//
//  Default model represents a Microchip 25AA1024 serial EEPROM.
//
//  The leading and trailing edges of Slave Select (SSel) provide several criti-
//  cal events. The leading edge is used to derive a reset signal used to align
//  the bit counter, command register, and state machine to each SPI cycle. An
//  SPI cycle is delimited by the leading and trailing edges of SSEL. For the
//  model provided here, the supported SPI mode is mode 0: CPHA = 0; CPOL = 0.
//
//  The leading edge of SSel is used as a 'posedge' clock to set a FF, Rst_SPI,
//  which is subsequently cleared asynchronously by the first positive SCK. This
//  construction allows the command, address, and control SM to be synchronized
//  to the start of an SPI cycle. By requiring operation in SPI Mode 0, SSel is
//  asserted 1/2 SCK period before the first rising edge of SCK. This produces a
//  pulse for the SPI reset signal that is approximately 1/2 of the SCK period.
//
//  The trailing edge of SSel is used as a 'negedge' clock to load various FFs
//  following the completion of the specified SPI cycle. For example, to write
//  the memory array, the write enable latch, WEL, must be set using a single
//  byte SPI transfer cycle which writes the WREN command to the SEEPROM command
//  register. This cycle requires a single 8 bit SPI transfer cycle. In Mode 0,
//  the SSel signal is asserted 1/2 SCK period before first rising edge of SCK,
//  and it is deasserted 1/2 SCK period after the last (8th) rising edge of SCK.
//  For the WREN command to be accepted, the trailing edge of SSel must occur
//  at least 1/2 SCK period after the last bit is registered into the SPI shift
//  register and before another SCK rising edge. The SEEPROM model uses the SSel
//  trailing edge to latch the shift register data into a dedicated WEL FF, but
//  that transfer from the SPI input data shift register, DI, to the WEL FF is
//  predicated on several conditions: (1) the command register is programmed
//  with the WREN code, the bit counter is 0, and the SM is in the correct
//  state. If these conditions are not met, then the data transfer is not per-
//  formed and the state of WEL is unchanged.
//
//  This process is used for several key commands. In particular, WRITE must
//  be completed such that the bit counter is 0 on the trailing edge of SSel. If
//  this condition is not met, then the write process is not initiated. There is
//  an exception to the requirement that the bit counter is 0 on the trailing
//  edge of SSel. When the Deep Power Down command is issued, the model will set
//  the internal Deep Power Down Latch FF, DPDL, which forces the SEEPROM to ig-
//  nore all commands except the Release Deep Power Down and Read Device ID,
//  RDID, command. RDID expects a standard 3 byte address after the command code
//  before the device id value is returned. Unlike other commands, RDID can be 
//  aborted before the device ID is returned and the SEEPROM can be taken out of
//  Deep Power Down mode on the trailing edge of SSel if the bit counter is not 
//  zero. (The only limitation to this exception is that the RDID command must 
//  have been properly loaded into the SEEPROM command register prior to the
//  trailing edge of SSel.) If Deep Power Down is exited in this manner, the de-
//  vice ID will not be returned.
//
//  A note about the programming model used in this module. Generally, serial
//  EEPROMs are organized into pages, sectors, and blocks. In the SEEPROM memory
//  modelled by this module, there are only four blocks because most SEEPROMs
//  provide write protection for memory blocks based on whether protection ex-
//  tends to 1/4 (1 block), 1/2 (2 blocks), 3/4 (3 blocks), or 4/4 (all blocks).
//  Two block protection bits in the SEEPROM status register provide control for
//  this functionality. (In addition, an external write protection input, WP, is
//  generally enabled through the Write Protection Enable, WPEN, bit in the sta-
//  tus register. Only if WPEN is set and WP asserted is the status register
//  protected by external logic. With WPEN is set and WP asserted, the status
//  register is protected from writes even if the write enable latch is set.
//  The WEL plus the BP bit settings is the protection mechanism for memory 
//  blocks, and the WPEN bit and external WP is the only protection mechanism
//  the status register.) Within one of the four memory blocks, there are seve-
//  ral memory sectors consisting of several memory pages. At the lowest level
//  of the memory hierachy, the memory pages, having between 16 and 256 bytes,
//  provide the smallest increment of memory that can be programmed during a
//  write operation. Generally, writing bytes is not performed at the byte level
//  in SEEPROMs, but at the page level. A buffer is filled with data to be writ-
//  ten to the selected page. Between 1 byte and number of bytes in a page are
//  written to the physical memory page selected. The buffer is circularly fill-
//  ed by the data transferred in the WRITE cycle. The address provided is used
//  to initialize a pointer into the page buffer, and data is written into the
//  page buffer in a circular manner. That is, the page address counter counts
//  modulo the page size. If the WRITE SPI cycle starts within a page boundary,
//  and transfers more data than would naturally fit in the remaining portion of
//  the page, the extra data is buffered at the beginning of the page buffer.
//  There is no limit to how much data can be transferred in a WRITE cycle, but
//  there is a limit to how much can be held unambigously in the page buffer. At
//  the completion of the WRITE cycle transfer on a clock boundary where the
//  bit counter is 0, the trailing edge of SSel will initiate a program cycle of
//  the selected page. The entire page buffer is programmed, and any locations
//  not transferred and held in the page buffer are refreshed. (Note: if the bit
//  counter restriction is not observed, the entire WRITE cycle is aborted.) It
//  is this characteristic of programming new data into and refreshing old data
//  at the memory page level that places the programming cyle restriction on all
//  bytes in a page and not just the bytes actually written to the page buffer.
//
//  This behavior of SEEPROM with respect to page level programming is modelled
//  in this module. A page buffer is provided, and a second array is used to 
//  determine if the corresponding page buffer entry was loaded with data in a
//  WRITE cycle. On the trailing edge of SSel, and independent programming state
//  machine is started which will always program all locations in a page. The
//  contents of the memory page will be replaced by those in the page buffer in
//  a manner consistent with Flash EPROM technology. That is, for memory array
//  locations not all 1s, i.e. not erased, only that locations 1 bits can be
//  be changed to 0s by the data in the corresponding page buffer location. An
//  erase cycle, Page, Sector, or Chip, will repeatedly use the page programming
//  state sequence to set all bits in a memory page, sector, or chip to all 1s.
//  (Note: a separate write flag memory is used to track which bytes in a page
//  are to be programmed and which are to be refreshed. Instead of using a sepa-
//  rate memory for these flags, the page buffer locations could be initialized
//  to all 1s on reset and on the completion of any programming operations. This
//  module chose to use the flags memory instead in order to simplify its deve-
//  lopement. It may be synthesizable, but it is just a model of external beha-
//  viour, and does not need to model internal SEEPROM behaviour exactly.)
//
////////////////////////////////////////////////////////////////////////////////

module SEEPROM #(
    parameter pFilename   = "SEEPROM.txt",  // Memory Initialization File
    parameter pAddrsLen   = 3,              // SEEPROM Address Length (3 bytes)
    parameter pPageSize   = 6,              // SEEPROM Page Size    (256 bytes)
    parameter pSectorSize = 2,              // SEEPROM Sector Size  (128 pages)
    parameter pID         = 41              // SEEPROM Manufacturer/Chip ID               
)(
    input   Rst,        // System Reset - aids in simulation
    input   Clk,        // System Clock - implements self timing

    input   SSel,       // SPI Slave Select
    
    input   SCK,        // SPI Master Serial Clock
    input   MOSI,       // SPI Master Out/Slave In
    output  MISO,       // SPI Master Master In/Slave Out
    
    input   WP,         // SEEPROM Write Protect Status Register
    input   HOLD        // SEEPROM Suspend current cycle.
);

////////////////////////////////////////////////////////////////////////////////
//
//  Local Parameters
//

localparam pAddrSize = 3*pAddrsLen;                     // Address Length - bits
localparam pROM_Size = (2**(2+pSectorSize+pPageSize));  // SEEPROM Size - bytes

//  Supported SEEPROM Commands

localparam pREAD  = 3;      // SEEPROM Read Command Code
localparam pWRITE = 2;      // SEEPROM Write Command Code
localparam pWREN  = 6;      // SEEPROM Write Enable  - Set Write Enable Latch
localparam pWRDI  = 4;      // SEEPROM Write Disable - Clr Write Enable Latch
localparam pRDSR  = 5;      // SEEPROM Read Status Register
localparam pWRSR  = 1;      // SEEPROM Write Status Register
localparam pPE    = 64;     // SEEPROM Page Erase
localparam pSE    = 232;    // SEEPROM Sector Erase
localparam pCE    = 200;    // SEEPROM Chip Erase
localparam pRDID  = 171;    // SEEPROM Read Device ID
localparam pDPD   = 185;    // SEEPROM Deep Power Down

////////////////////////////////////////////////////////////////////////////////
//
//  Module Declarations
//

reg     [7:0] PROM [(pROM_Size - 1):0];     // SEEPROM Data Array
reg     [7:0] PROM_DO;                      // SEEPROM Data Array Output

reg     [7:0] DI;                           // SEEPROM SPI Data Input Register
reg     [7:0] DO;                           // SEEPROM SPI Data Output Register

reg     [

reg     [7:0] Cmd;                          // SEEPROM Command Register
reg     [(pAddrsSize - 1):0] Addrs;         // SEEPROM Address Register

reg     [7:0] WrBuf [(pPageBufLen - 1):0];  // SEEPROM Page Write Buffer
reg     WrFlg [(pPageBufLen - 1):0];        // SEEPROM Page Write Flag Register
reg     [pPageSize:0] Page_Cntr;            // SEEPROM Page Buffer Counter
wire    WrErr;                              // SEEPROM Write Error Flag

reg     WIP;                                // SEEPROM Write In Progress Flag
reg     WEL;                                // SEEPROM Write Enable Latch
reg     [1:0] BP;                           // SEEPROM Block Protect bits
reg     WPEN                                // SEEPROM Write Protect Enable
wire    [7:0] Status;                       // SEEPROM Status Register

reg     DPDL;                               // SEEPROM Deep Power Down Latch
wire    Rdy;                                // SEEPROM Ready (!Hold) FF

////////////////////////////////////////////////////////////////////////////////
//
//  Implementation
//

initial
    $readmemh(pFilename, PROM, 0, (pROM_Size - 1));

always @(negedge SCK)
begin
    if(PROM_WE)
        PROM[Addrs] <= #1 WrBuf[Addrs];
        PROM_DO <= #1 PROM[Addrs]; 
    else
        PROM_DO <= #1 PROM[Addrs];
end

////////////////////////////////////////////////////////////////////////////////
//
//  SPI Interface Implementation
//

//  SPI Hold Signal
//      if Hold is asserted on the falling edge of SCK, then the Rdy FF is
//          cleared, and all processing of the current SPI frame is halted.
//      if Hold is not asserted on the falling edge of SCK, then the Rdy FF is
//          set, and processing of the SPI frame is resumed.

SEEPROM_Rdy U1 (
                .Rst(Rst), 

                .Hold(Hold), 
                .SCK(SCK),
                
                .Rdy(Rdy)
            );

//  SPI Reset Signal
//      Set on leading edge of SSel, Cleared on positive pulse of SCK

assign Clr_Rst_SPI = Rdy & SCK;

always @(posedge SSel or posedge Clr_Rst_SPI)
begin
    if(Clr_Rst_SPI)
        Rst_SPI <= #1 0;
    else
        Rst_SPI <= #1 1;
end

//  SPI Data Input Bit Counter
//      Increment after each bit is loaded into DI
//      Initial load is a 1 to account for the fact that Rst_SPI will be
//          asserted until the first positive pulse on SCK. This condition
//          causes the first increment not to occur until the second rising
//          edge of SCK. Following the first TC condition, BitCnt simply
//          counts past the terminal count value on the next SCK rising edge.
//          The expection is that the bit length is a power of two, so no spe-
//          cial test circuitry is needed to return the count value of the
//          counter to 0 when the terminal count value is reached.

always @(posedge SCK or posedge Rst_SPI)
begin
    if(Rst_SPI)
        BitCnt <= #1 1;
    else if(Rdy)
        BitCnt <= #1 (BitCnt + 1);
end

assign TC_BitCnt = &BitCnt;     // Assert TC_BitCnt when BitCnt is all 1s

//  SPI Data Input Shift Register
//      Shift data into MSB of DI on rising edge of SCK; Clear at start of cycle

always @(posedge SCK or posedge Rst_SPI)
begin
    if(Rst_SPI)
        DI <= #1 0;
    else if(Rdy)
        DI <= #1 {MOSI, DI[7:1};
end

//  SPI Data Output Shift Register

always @(negedge SCK or posedge Rst_SPI)
begin
    if(Rst_SPI)
        DO <= #1 0;
    else if(Rdy)
         DO <= #1 ((Ld_DO) ? SPI_DO : {DO[6:0], 1'b0});
end

assign MISO = ((SSel & OE & Rdy) ? DO[7] : 1'bZ);

////////////////////////////////////////////////////////////////////////////////
//
//  SEEPROM Controller Implementation
//

//  SEEPROM Command Register
//      Cleared at the start of every cycle, and loaded on first TC_BitCnt
//      Note: if the SEEPROM is in Deep Power Down, a RDID command is allowed
//            and that command will clear the Deep Power Down Latch (DPDL), but
//            until either reset or RDID clears DPDL, all other commands are
//            ignored, i.e. not loaded into the Cmd register.

assign CE_Cmd = Rdy & ~|Cmd & TC_BitCnt;
assign Rd_ID  = ({MOSI, DI[7:1]} == pRDID);

always @(posedge SCK or posedge Rst_SPI)
begin
    if(Rst_SPI)
        Cmd <= #1 0;
    else if(CE_Cmd)
        Cmd <= #1 ((Rd_ID) ? {MOSI, DI[7:1]}
                           : (~DPDL) ? {MOSI, DI[7:1]}
                                     : Cmd            );
end

//  Deep Power Down Latch
//      Set when SSel deasserted, (SM == Cmd), ~|BitCnt, and (Cmd == DPD)
//      Clr on Rst or when SSel deasserted, (SM == RDIDx) and (Cmd == RDID)

assign DPDL_Set = Rdy & ~|BitCnt & ((SM == pCmd) & (Cmd == pDPD)  );
assign DPDL_Clr = Rdy & (  ((SM == pRDID_Add) | (SM == pRDID_Dat))
                         & (Cmd == pRDID)                         );

always @(negedge SSel or posedge Rst)
begin
    if(Rst)
        DPDL <= #1 0;
    else if(DPDL_Clr)
        DPDL <= #1 0;   // Clr if exiting a Read ID cycle
    else if(DPDL_Set)
        DPDL <= #1 1;   // Set if exiting a Deep Power Down cycle w/o extra data
end

//  Write Enable Latch
//      Set when SSel deasserted, (SM == Cmd), ~|BitCnt, and (Cmd == WREN)
//      Clr when SSel deasserted, ((Cmd==WRITE) | (Cmd==WRSR) | (Cmd==WRDI))
//      else maintain state

always @(negedge SSel or posedge Rst)
begin
    if(Rst)
        WEL <= #1 0;
    else if(Rdy & ~|BitCnt)   // (BitCnt == 0) means no extraneous data, else ignore
        case(Cmd)
            pWREN   : WEL <= #1  (SM == pCmd);              // Write Enable
            pWRDI   : WEL <= #1 ((SM == pCmd) ? 0 : WEL);   // Write Disable
            pWRITE  : WEL <= #1 ((SM == pWrD) ? 0 : WEL);   // Write cycle
            pWRSR   : WEL <= #1 ((SR_WE)      ? 0 : WEL);   // Write Status Reg.
            pPE     : WEL <= #1 ((SM == pCmd) ? 0 : WEL);   // Page Erase
            pSE     : WEL <= #1 ((SM == pCmd) ? 0 : WEL);   // Sector Erase
            pCE     : WEL <= #1 ((SM == pCmd) ? 0 : WEL);   // Chip Erase
            default : WEL <= #1 WEL;                        // Maintain setting
        endcase
end

//  Status Register Write Enable

assign SR_WE = Rdy & (  WEL                 // Write Enable Latch Set
                      & ~(WPEN & WP)        // Hardware Write Protect not Set
                      & (Cmd == pWRSR)      // Write Status Register Command
                      & ( SM == pWrSR)      // SM captured Status Register data
                      & ~|BitCnt      );    // No extraneous cycles

//  Block Protect Register
//      Write only when SR_WE asserted

always @(negedge SSel or posedge Rst)
begin
    if(Rst)
        BP <= #1 0;
    else if(SR_WE)
        BP <= DI[3:2];
end

//  Write Protect Enable Register
//      Write only when SR_WE asserted

always @(negedge SSel or posedge Rst)
begin
    if(Rst)
        WPEN <= #1 0;
    else if(SR_WE)
        WPEN <= DI[7];
end

//  SEEPROM Status Register
//      See 25AA1024 Datasheet for the layout of this register

assign Status = {WPEN, 1'b0, 1'b0, BP, WEL, WIP};

endmodule
