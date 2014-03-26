//////////////////////////////////////////////////////////////////
//                                                              //
//  Top-level module instantiating the entire Amber 2 system.   //
//                                                              //
//  This file is part of the Amber project                      //
//  http://www.opencores.org/project,amber                      //
//                                                              //
//  Description                                                 //
//  This is the highest level synthesizable module in the       //
//  project. The ports in this module represent pins on the     //
//  FPGA.                                                       //
//                                                              //
//  Author(s):                                                  //
//      - Conor Santifort, csantifort.amber@gmail.com           //
//                                                              //
//////////////////////////////////////////////////////////////////
//                                                              //
// Copyright (C) 2010 Authors and OPENCORES.ORG                 //
//                                                              //
// This source file may be used and distributed without         //
// restriction provided that this copyright statement is not    //
// removed from the file and that any derivative work contains  //
// the original copyright notice and the associated disclaimer. //
//                                                              //
// This source file is free software; you can redistribute it   //
// and/or modify it under the terms of the GNU Lesser General   //
// Public License as published by the Free Software Foundation; //
// either version 2.1 of the License, or (at your option) any   //
// later version.                                               //
//                                                              //
// This source is distributed in the hope that it will be       //
// useful, but WITHOUT ANY WARRANTY; without even the implied   //
// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      //
// PURPOSE.  See the GNU esser General Public License for more //
// details.                                                     //
//                                                              //
// You should have received a copy of the GNU Lesser General    //
// Public License along with this source; if not, download it   //
// from http://www.opencores.org/lgpl.shtml                     //
//                                                              //
//////////////////////////////////////////////////////////////////


module msystem  
(
input                       brd_n_rst,
input                       brd_clk_p,  

`ifdef SDRAM
	//SDRAM interface
	output wire sdr_clk,
	output wire sdr_ras_n,
	output wire sdr_cas_n,
	output wire sdr_we_n,
	output wire [1:0]sdr_dqm,
	output wire [1:0]sdr_ba,
	output wire [11:0]sdr_addr,
	inout [15:0]sdr_dq,
`endif

// UART 0 Interface
input                       i_uart0_rts,
output                      o_uart0_rx,
output                      o_uart0_cts,
input                       i_uart0_tx,

`ifdef ETHERNET
// Ethmac B100 MAC to PHY Interface
input                       mtx_clk_pad_i,
output  [3:0]               mtxd_pad_o, 
output                      mtxen_pad_o,
output                      mtxerr_pad_o,
input                       mrx_clk_pad_i,
input   [3:0]               mrxd_pad_i,
input                       mrxdv_pad_i,
input                       mrxerr_pad_i,
input                       mcoll_pad_i,
input                       mcrs_pad_i,
inout                       md_pad_io,
output                      mdc_pad_o,    
output                      phy_reset_n,
`endif

`ifdef ENABLE_TXTSCR
	output wire [4:0]VGA_RED,
	output wire [5:0]VGA_GREEN,
	output wire [4:0]VGA_BLUE,
	output wire VGA_HSYNC,
	output wire VGA_VSYNC,
	input wire io_ps2_clock,
	input wire io_ps2_data,
`endif

output  led
);

wire brd_rst; assign brd_rst = ~brd_n_rst;
assign led = brd_rst;

wire            phy_init_done;
wire            system_rdy;

// ======================================
// Ethmac MII
// ======================================
wire            md_pad_i;
wire            md_pad_o;
wire            md_padoe_o;

// ======================================
// Wishbone Buses
// ======================================

localparam WB_MASTERS = 2;
localparam WB_SLAVES  = 9;

`ifdef AMBER_A25_CORE
localparam WB_DWIDTH  = 128;
localparam WB_SWIDTH  = 16;
`else
localparam WB_DWIDTH  = 32;
localparam WB_SWIDTH  = 4;
`endif

// Wishbone Master Buses
wire      [31:0]            m_wb_adr      [WB_MASTERS-1:0];
wire      [WB_SWIDTH-1:0]   m_wb_sel      [WB_MASTERS-1:0];
wire      [WB_MASTERS-1:0]  m_wb_we                       ;
wire      [WB_DWIDTH-1:0]   m_wb_dat_w    [WB_MASTERS-1:0];
wire      [WB_DWIDTH-1:0]   m_wb_dat_r    [WB_MASTERS-1:0];
wire      [WB_MASTERS-1:0]  m_wb_cyc                      ;
wire      [WB_MASTERS-1:0]  m_wb_stb                      ;
wire      [WB_MASTERS-1:0]  m_wb_ack                      ;
wire      [WB_MASTERS-1:0]  m_wb_err                      ;

// Wishbone Slave Buses
wire      [31:0]            s_wb_adr      [WB_SLAVES-1:0];
wire      [WB_SWIDTH-1:0]   s_wb_sel      [WB_SLAVES-1:0];
wire      [WB_SLAVES-1:0]   s_wb_we                      ;
wire      [WB_DWIDTH-1:0]   s_wb_dat_w    [WB_SLAVES-1:0];
wire      [WB_DWIDTH-1:0]   s_wb_dat_r    [WB_SLAVES-1:0];
wire      [WB_SLAVES-1:0]   s_wb_cyc                     ;
wire      [WB_SLAVES-1:0]   s_wb_stb                     ;
wire      [WB_SLAVES-1:0]   s_wb_ack                     ;
wire      [WB_SLAVES-1:0]   s_wb_err                     ;

`ifdef ETHERNET
wire      [31:0]            emm_wb_adr;  
wire      [3:0]             emm_wb_sel;  
wire                        emm_wb_we;   
wire      [31:0]            emm_wb_rdat; 
wire      [31:0]            emm_wb_wdat; 
wire                        emm_wb_cyc;  
wire                        emm_wb_stb;  
wire                        emm_wb_ack;  
wire                        emm_wb_err;  

wire      [31:0]            ems_wb_adr;  
wire      [3:0]             ems_wb_sel;  
wire                        ems_wb_we;   
wire      [31:0]            ems_wb_rdat; 
wire      [31:0]            ems_wb_wdat; 
wire                        ems_wb_cyc;  
wire                        ems_wb_stb;  
wire                        ems_wb_ack;  
wire                        ems_wb_err;  
`endif

// ======================================
// Interrupts
// ======================================
wire                        amber_irq;
wire                        amber_firq;
wire                        ethmac_int;
wire                        test_reg_irq;
wire                        test_reg_firq;
wire                        uart0_int;
wire                        uart1_int;
wire      [2:0]             timer_int;

wire sys_clk;
wire mem_clk;
wire sys_rst;
wire sdr_ena;

// ======================================
// Clocks and Resets Module
// ======================================
`ifdef MARSOHOD2
wire vga_clock;
my_clocks_resets u_clk_r(
	.i_brd_rst(brd_rst),		//from board button
	.i_brd_clk(brd_clk_p),	//from board crystal
	.i_memory_initialized(phy_init_done),
	.o_sys_rst(sys_rst),		//main project reset made out of board button reset
	.o_sys_clk(sys_clk),		//main system clock
	.o_mem_clk(mem_clk),
	.o_vga_clk(vga_clock),
	.o_system_ready(system_rdy),
	.o_sdr_ena(sdr_ena)
);
`else
`ifdef ICARUS
my_clocks_resets u_clk_r(
	.i_brd_rst(brd_rst),		//from board button
	.i_brd_clk(brd_clk_p),	//from board crystal
	.i_memory_initialized(phy_init_done),
	.o_sys_rst(sys_rst),		//main project reset made out of board button reset
	.o_sys_clk(sys_clk),		//main system clock
	.o_mem_clk(mem_clk),
	.o_system_ready(system_rdy),
	.o_sdr_ena(sdr_ena)
);
`else
clocks_resets u_clocks_resets (
    .i_brd_rst          ( brd_rst           ),
    .i_brd_clk_n        ( brd_clk_n         ),  
    .i_brd_clk_p        ( brd_clk_p         ),  
    .i_ddr_calib_done   ( phy_init_done     ),
    .o_sys_rst          ( sys_rst           ),
    .o_sys_clk          ( sys_clk           ),
    .o_clk_200          ( clk_200           )
);
`endif
`endif

// -------------------------------------------------------------
// Instantiate Amber Processor Core
// -------------------------------------------------------------
`ifdef AMBER_A25_CORE
a25_core u_amber (
`else
a23_core u_amber (
`endif
    .i_clk          ( sys_clk         ),
    
    .i_irq          ( amber_irq       ),
    .i_firq         ( amber_firq      ),

    .i_system_rdy   ( system_rdy      ),
    
    .o_wb_adr       ( m_wb_adr  [1]   ),
    .o_wb_sel       ( m_wb_sel  [1]   ),
    .o_wb_we        ( m_wb_we   [1]   ),
    .i_wb_dat       ( m_wb_dat_r[1]   ),
    .o_wb_dat       ( m_wb_dat_w[1]   ),
    .o_wb_cyc       ( m_wb_cyc  [1]   ),
    .o_wb_stb       ( m_wb_stb  [1]   ),
    .i_wb_ack       ( m_wb_ack  [1]   ),
    .i_wb_err       ( m_wb_err  [1]   )
);

// -------------------------------------------------------------
// Instantiate B100 Ethernet MAC
// -------------------------------------------------------------
`ifdef ETHERNET  
eth_top u_eth_top (
    .wb_clk_i                   ( sys_clk                ),
    .wb_rst_i                   ( sys_rst                ),

    // WISHBONE slave
    .wb_adr_i                   ( ems_wb_adr [11:2]      ),     
    .wb_sel_i                   ( ems_wb_sel             ),     
    .wb_we_i                    ( ems_wb_we              ),     
    .wb_cyc_i                   ( ems_wb_cyc             ),     
    .wb_stb_i                   ( ems_wb_stb             ),     
    .wb_ack_o                   ( ems_wb_ack             ),     
    .wb_dat_i                   ( ems_wb_wdat            ),     
    .wb_dat_o                   ( ems_wb_rdat            ),     
    .wb_err_o                   ( ems_wb_err             ),     

    // WISHBONE master
    .m_wb_adr_o                 ( emm_wb_adr             ), 
    .m_wb_sel_o                 ( emm_wb_sel             ), 
    .m_wb_we_o                  ( emm_wb_we              ), 
    .m_wb_dat_i                 ( emm_wb_rdat            ), 
    .m_wb_dat_o                 ( emm_wb_wdat            ), 
    .m_wb_cyc_o                 ( emm_wb_cyc             ), 
    .m_wb_stb_o                 ( emm_wb_stb             ), 
    .m_wb_ack_i                 ( emm_wb_ack             ), 
    .m_wb_err_i                 ( emm_wb_err             ), 

    // MAC to PHY I/F
    .mtx_clk_pad_i              ( mtx_clk_pad_i          ),
    .mtxd_pad_o                 ( mtxd_pad_o             ),
    .mtxen_pad_o                ( mtxen_pad_o            ),
    .mtxerr_pad_o               ( mtxerr_pad_o           ),
    .mrx_clk_pad_i              ( mrx_clk_pad_i          ),
    .mrxd_pad_i                 ( mrxd_pad_i             ),
    .mrxdv_pad_i                ( mrxdv_pad_i            ),
    .mrxerr_pad_i               ( mrxerr_pad_i           ), 
    .mcoll_pad_i                ( mcoll_pad_i            ), 
    .mcrs_pad_i                 ( mcrs_pad_i             ), 
    .md_pad_i                   ( md_pad_i               ), 
    .mdc_pad_o                  ( mdc_pad_o              ), 
    .md_pad_o                   ( md_pad_o               ), 
    .md_padoe_o                 ( md_padoe_o             ), 

    // Interrupt
    .int_o                      ( ethmac_int             )
);
`else
	assign ethmac_int = 0;
`endif

`ifdef ETHERNET
// -------------------------------------------------------------
// Instantiate Ethernet Control Interface tri-state buffer
// -------------------------------------------------------------
`ifdef XILINX_FPGA
IOBUF u_iobuf (
`else
generic_iobuf u_iobuf (
`endif
    .O                          ( md_pad_i              ), 
    .IO                         ( md_pad_io             ), 
    .I                          ( md_pad_o              ), 
    // T is high for tri-state output
    .T                          ( ~md_padoe_o           ) 
);
`endif

// -------------------------------------------------------------
// Instantiate Boot Memory - 8KBytes of Embedded SRAM
// -------------------------------------------------------------

generate
if (WB_DWIDTH == 32) begin : boot_mem32
    boot_mem32 u_boot_mem (
        .i_wb_clk               ( sys_clk         ),
        .i_wb_adr               ( s_wb_adr  [1]   ),
        .i_wb_sel               ( s_wb_sel  [1]   ),
        .i_wb_we                ( s_wb_we   [1]   ),
        .o_wb_dat               ( s_wb_dat_r[1]   ),
        .i_wb_dat               ( s_wb_dat_w[1]   ),
        .i_wb_cyc               ( s_wb_cyc  [1]   ),
        .i_wb_stb               ( s_wb_stb  [1]   ),
        .o_wb_ack               ( s_wb_ack  [1]   ),
        .o_wb_err               ( s_wb_err  [1]   )
    );
end
else begin : boot_mem128
    boot_mem128 u_boot_mem (
        .i_wb_clk               ( sys_clk         ),
        .i_wb_adr               ( s_wb_adr  [1]   ),
        .i_wb_sel               ( s_wb_sel  [1]   ),
        .i_wb_we                ( s_wb_we   [1]   ),
        .o_wb_dat               ( s_wb_dat_r[1]   ),
        .i_wb_dat               ( s_wb_dat_w[1]   ),
        .i_wb_cyc               ( s_wb_cyc  [1]   ),
        .i_wb_stb               ( s_wb_stb  [1]   ),
        .o_wb_ack               ( s_wb_ack  [1]   ),
        .o_wb_err               ( s_wb_err  [1]   )
    );
end
endgenerate

// -------------------------------------------------------------
// Instantiate UART0
// -------------------------------------------------------------
uart  #(
    .WB_DWIDTH              ( WB_DWIDTH       ),
    .WB_SWIDTH              ( WB_SWIDTH       )
    )
u_uart0 (
    .i_clk                  ( sys_clk        ),

    .o_uart_int             ( uart0_int      ),
    
    .i_uart_cts_n           ( 1'b0 ), //i_uart0_rts    ),
    .o_uart_txd             ( o_uart0_rx     ),
    .o_uart_rts_n           ( o_uart0_cts    ),
    .i_uart_rxd             ( i_uart0_tx     ),
    
    .i_wb_adr               ( s_wb_adr  [3]  ),
    .i_wb_sel               ( s_wb_sel  [3]  ),
    .i_wb_we                ( s_wb_we   [3]  ),
    .o_wb_dat               ( s_wb_dat_r[3]  ),
    .i_wb_dat               ( s_wb_dat_w[3]  ),
    .i_wb_cyc               ( s_wb_cyc  [3]  ),
    .i_wb_stb               ( s_wb_stb  [3]  ),
    .o_wb_ack               ( s_wb_ack  [3]  ),
    .o_wb_err               ( s_wb_err  [3]  )
);

`ifdef ENABLE_UART1
// -------------------------------------------------------------
// Instantiate UART1
// -------------------------------------------------------------
uart  #(
    .WB_DWIDTH              ( WB_DWIDTH       ),
    .WB_SWIDTH              ( WB_SWIDTH       )
    ) 
u_uart1 (
    .i_clk                  ( sys_clk        ),

    .o_uart_int             ( uart1_int      ),
    
    // These are not connected. ONly pins for 1 UART
    // on my development board
    .i_uart_cts_n           ( 1'd1           ),
    .o_uart_txd             (                ),
    .o_uart_rts_n           (                ),
    .i_uart_rxd             ( 1'd1           ),
    
    .i_wb_adr               ( s_wb_adr  [4]  ),
    .i_wb_sel               ( s_wb_sel  [4]  ),
    .i_wb_we                ( s_wb_we   [4]  ),
    .o_wb_dat               ( s_wb_dat_r[4]  ),
    .i_wb_dat               ( s_wb_dat_w[4]  ),
    .i_wb_cyc               ( s_wb_cyc  [4]  ),
    .i_wb_stb               ( s_wb_stb  [4]  ),
    .o_wb_ack               ( s_wb_ack  [4]  ),
    .o_wb_err               ( s_wb_err  [4]  )
);
`else

`ifdef ENABLE_TXTSCR
txtscreen u_txtscreen (
   .pixel_clock( vga_clock ),
	.in_ps2_clock( io_ps2_clock ),
	.in_ps2_data( io_ps2_data ),
	.hsync( VGA_HSYNC ),
	.vsync( VGA_VSYNC),

	//high-color test video signal
	.r( VGA_RED ),
	.g( VGA_GREEN ),
	.b( VGA_BLUE ),
	
	.i_wb_clk               ( sys_clk  ),
	.i_wb_adr               ( s_wb_adr  [4]  ),
	.i_wb_sel               ( s_wb_sel  [4]  ),
	.i_wb_we                ( s_wb_we   [4]  ),
	.o_wb_dat               ( s_wb_dat_r[4]  ),
	.i_wb_dat               ( s_wb_dat_w[4]  ),
	.i_wb_cyc               ( s_wb_cyc  [4]  ),
	.i_wb_stb               ( s_wb_stb  [4]  ),
	.o_wb_ack               ( s_wb_ack  [4]  ),
	.o_wb_err               ( s_wb_err  [4]  )
);
    assign uart1_int = 0;

`else
    assign uart1_int = 0;
    assign s_wb_dat_r[4] = 0;
    assign s_wb_ack  [4] = 0;
    assign s_wb_err  [4] = 0;
`endif

`endif

// -------------------------------------------------------------
// Instantiate Test Module
//   - includes register used to terminate tests
// -------------------------------------------------------------
test_module #(
    .WB_DWIDTH              ( WB_DWIDTH      ),
    .WB_SWIDTH              ( WB_SWIDTH      )
    ) 
u_test_module (
    .i_clk                  ( sys_clk        ),
    
    .o_irq                  ( test_reg_irq   ),
    .o_firq                 ( test_reg_firq  ),
    .o_mem_ctrl             ( test_mem_ctrl  ),
    .i_wb_adr               ( s_wb_adr  [5]  ),
    .i_wb_sel               ( s_wb_sel  [5]  ),
    .i_wb_we                ( s_wb_we   [5]  ),
    .o_wb_dat               ( s_wb_dat_r[5]  ),
    .i_wb_dat               ( s_wb_dat_w[5]  ),
    .i_wb_cyc               ( s_wb_cyc  [5]  ),
    .i_wb_stb               ( s_wb_stb  [5]  ),
    .o_wb_ack               ( s_wb_ack  [5]  ),
    .o_wb_err               ( s_wb_err  [5]  ),
    .o_led                  ( /*led*/        ),
    .o_phy_rst_n            ( phy_reset_n    )
);

// -------------------------------------------------------------
// Instantiate Timer Module
// -------------------------------------------------------------
timer_module  #(
    .WB_DWIDTH              ( WB_DWIDTH      ),
    .WB_SWIDTH              ( WB_SWIDTH      )
    ) 
u_timer_module (
    .i_clk                  ( sys_clk        ),
    
    // Interrupt outputs
    .o_timer_int            ( timer_int      ),
    
    // Wishbone interface
    .i_wb_adr               ( s_wb_adr  [6]  ),
    .i_wb_sel               ( s_wb_sel  [6]  ),
    .i_wb_we                ( s_wb_we   [6]  ),
    .o_wb_dat               ( s_wb_dat_r[6]  ),
    .i_wb_dat               ( s_wb_dat_w[6]  ),
    .i_wb_cyc               ( s_wb_cyc  [6]  ),
    .i_wb_stb               ( s_wb_stb  [6]  ),
    .o_wb_ack               ( s_wb_ack  [6]  ),
    .o_wb_err               ( s_wb_err  [6]  )
);

// -------------------------------------------------------------
// Instantiate Interrupt Controller Module
// -------------------------------------------------------------
interrupt_controller  #(
    .WB_DWIDTH              ( WB_DWIDTH      ),
    .WB_SWIDTH              ( WB_SWIDTH      )
    )
u_interrupt_controller (
    .i_clk                  ( sys_clk        ),
    
    // Interrupt outputs
    .o_irq                  ( amber_irq      ),
    .o_firq                 ( amber_firq     ),
    
    // Interrupt inputs
    .i_uart0_int            ( uart0_int      ),
    .i_uart1_int            ( uart1_int      ),
    .i_ethmac_int           ( ethmac_int     ),
    .i_test_reg_irq         ( test_reg_irq   ),
    .i_test_reg_firq        ( test_reg_firq  ),
    .i_tm_timer_int         ( timer_int      ),
    
    // Wishbone interface
    .i_wb_adr               ( s_wb_adr  [7]  ),
    .i_wb_sel               ( s_wb_sel  [7]  ),
    .i_wb_we                ( s_wb_we   [7]  ),
    .o_wb_dat               ( s_wb_dat_r[7]  ),
    .i_wb_dat               ( s_wb_dat_w[7]  ),
    .i_wb_cyc               ( s_wb_cyc  [7]  ),
    .i_wb_stb               ( s_wb_stb  [7]  ),
    .o_wb_ack               ( s_wb_ack  [7]  ),
    .o_wb_err               ( s_wb_err  [7]  )
);

`ifndef XILINX_FPGA

`ifdef SDRAM
	//system with SDRAM
	assign s_wb_err[2] = 0;
	wire sdr_init_done;
	assign phy_init_done = sdr_init_done;
	assign sdr_clk = mem_clk;
	
   sdrc_top #(.SDR_DW(16),.SDR_BW(2)) u_sdram(
          .cfg_sdr_width      (2'b01              ), // 16 BIT SDRAM
          .cfg_colbits        (2'b00              ), // 8 Bit Column Address

	/* WISHBONE */
          .wb_rst_i           (sys_rst),
          .wb_clk_i           (sys_clk            ),

          .wb_stb_i           (s_wb_stb[2]        ),
          .wb_ack_o           (s_wb_ack[2]        ),
          .wb_addr_i          (s_wb_adr[2]>>2     ),
          .wb_we_i            (s_wb_we[2]         ),
          .wb_dat_i           (s_wb_dat_w[2]      ),
          .wb_sel_i           (s_wb_sel[2]        ),
          .wb_dat_o           (s_wb_dat_r[2]      ),
          .wb_cyc_i           (s_wb_cyc[2]        ),
          .wb_cti_i           (0), 
	
	/* Interface to SDRAMs */
          .sdram_clk          (sdr_clk			  ),
          .sdram_resetn       (~sys_rst			  ),
          .sdr_cs_n           ( /*sdr_cs_n*/      ),
          .sdr_cke            ( /*sdr_cke*/       ),
          .sdr_ras_n          (sdr_ras_n          ),
          .sdr_cas_n          (sdr_cas_n          ),
          .sdr_we_n           (sdr_we_n           ),
          .sdr_dqm            (sdr_dqm       	  ),
          .sdr_ba             (sdr_ba             ),
          .sdr_addr           (sdr_addr           ), 
          .sdr_dq             (sdr_dq             ),

	/* Parameters */
          .sdr_init_done      (sdr_init_done      ),
          .cfg_req_depth      (2'h3               ), //how many req. buffer should hold
          .cfg_sdr_en         (sdr_ena            ),
          .cfg_sdr_mode_reg   (12'h023            ),
          .cfg_sdr_tras_d     (4'h4               ), //44-120000ns
          .cfg_sdr_trp_d      (4'h2               ), //min 20ns
          .cfg_sdr_trcd_d     (4'h2               ), //min 20ns
          .cfg_sdr_cas        (3'h3               ), //cas latency in clocks, depends on mode reg
          .cfg_sdr_trcar_d    (4'h7               ), //min 66ns
          .cfg_sdr_twr_d      (4'h1               ), //write recovery time, 1ck+7,5/15ns
          .cfg_sdr_rfsh       (12'h100            ), //16 or 64 ms?
          .cfg_sdr_rfmax      (3'h6               )
);
`else
//assume memory always ready if no SDRAM
assign phy_init_done = 1'd1;
`endif

    // ======================================
    // Instantiate non-synthesizable main memory model
    // ======================================
    
`ifdef NOMEMORY
`else
    main_mem #(
                .WB_DWIDTH             ( WB_DWIDTH             ),
                .WB_SWIDTH             ( WB_SWIDTH             )
                ) 
    u_main_mem (
               .i_clk                  ( sys_clk               ),
               .i_mem_ctrl             ( test_mem_ctrl         ),
               .i_wb_adr               ( s_wb_adr  [2]         ),        
               .i_wb_sel               ( s_wb_sel  [2]         ),        
               .i_wb_we                ( s_wb_we   [2]         ),        
               .o_wb_dat               ( s_wb_dat_r[2]         ),        
               .i_wb_dat               ( s_wb_dat_w[2]         ),        
               .i_wb_cyc               ( s_wb_cyc  [2]         ),        
               .i_wb_stb               ( s_wb_stb  [2]         ),        
               .o_wb_ack               ( s_wb_ack  [2]         ),        
               .o_wb_err               ( s_wb_err  [2]         )     
            );
`endif
`endif

// -------------------------------------------------------------
// Instantiate Wishbone Arbiter
// -------------------------------------------------------------
wishbone_arbiter #(
    .WB_DWIDTH              ( WB_DWIDTH         ),
    .WB_SWIDTH              ( WB_SWIDTH         )
    )
u_wishbone_arbiter (
    .i_wb_clk               ( sys_clk           ),

    // WISHBONE master 0 - Ethmac
    .i_m0_wb_adr            ( m_wb_adr   [0]    ),
    .i_m0_wb_sel            ( m_wb_sel   [0]    ),
    .i_m0_wb_we             ( m_wb_we    [0]    ),
    .o_m0_wb_dat            ( m_wb_dat_r [0]    ),
    .i_m0_wb_dat            ( m_wb_dat_w [0]    ),
    .i_m0_wb_cyc            ( m_wb_cyc   [0]    ),
    .i_m0_wb_stb            ( m_wb_stb   [0]    ),
    .o_m0_wb_ack            ( m_wb_ack   [0]    ),
    .o_m0_wb_err            ( m_wb_err   [0]    ),


    // WISHBONE master 1 - Amber Process or
    .i_m1_wb_adr            ( m_wb_adr   [1]    ),
    .i_m1_wb_sel            ( m_wb_sel   [1]    ),
    .i_m1_wb_we             ( m_wb_we    [1]    ),
    .o_m1_wb_dat            ( m_wb_dat_r [1]    ),
    .i_m1_wb_dat            ( m_wb_dat_w [1]    ),
    .i_m1_wb_cyc            ( m_wb_cyc   [1]    ),
    .i_m1_wb_stb            ( m_wb_stb   [1]    ),
    .o_m1_wb_ack            ( m_wb_ack   [1]    ),
    .o_m1_wb_err            ( m_wb_err   [1]    ),


    // WISHBONE slave 0 - Ethmac
    .o_s0_wb_adr            ( s_wb_adr   [0]    ),
    .o_s0_wb_sel            ( s_wb_sel   [0]    ),
    .o_s0_wb_we             ( s_wb_we    [0]    ),
    .i_s0_wb_dat            ( s_wb_dat_r [0]    ),
    .o_s0_wb_dat            ( s_wb_dat_w [0]    ),
    .o_s0_wb_cyc            ( s_wb_cyc   [0]    ),
    .o_s0_wb_stb            ( s_wb_stb   [0]    ),
    .i_s0_wb_ack            ( s_wb_ack   [0]    ),
    .i_s0_wb_err            ( s_wb_err   [0]    ),


    // WISHBONE slave 1 - Boot Memory
    .o_s1_wb_adr            ( s_wb_adr   [1]    ),
    .o_s1_wb_sel            ( s_wb_sel   [1]    ),
    .o_s1_wb_we             ( s_wb_we    [1]    ),
    .i_s1_wb_dat            ( s_wb_dat_r [1]    ),
    .o_s1_wb_dat            ( s_wb_dat_w [1]    ),
    .o_s1_wb_cyc            ( s_wb_cyc   [1]    ),
    .o_s1_wb_stb            ( s_wb_stb   [1]    ),
    .i_s1_wb_ack            ( s_wb_ack   [1]    ),
    .i_s1_wb_err            ( s_wb_err   [1]    ),


    // WISHBONE slave 2 - Main Memory
    .o_s2_wb_adr            ( s_wb_adr   [2]    ),
    .o_s2_wb_sel            ( s_wb_sel   [2]    ),
    .o_s2_wb_we             ( s_wb_we    [2]    ),
    .i_s2_wb_dat            ( s_wb_dat_r [2]    ),
    .o_s2_wb_dat            ( s_wb_dat_w [2]    ),
    .o_s2_wb_cyc            ( s_wb_cyc   [2]    ),
    .o_s2_wb_stb            ( s_wb_stb   [2]    ),
    .i_s2_wb_ack            ( s_wb_ack   [2]    ),
    .i_s2_wb_err            ( s_wb_err   [2]    ),


    // WISHBONE slave 3 - UART 0
    .o_s3_wb_adr            ( s_wb_adr   [3]    ),
    .o_s3_wb_sel            ( s_wb_sel   [3]    ),
    .o_s3_wb_we             ( s_wb_we    [3]    ),
    .i_s3_wb_dat            ( s_wb_dat_r [3]    ),
    .o_s3_wb_dat            ( s_wb_dat_w [3]    ),
    .o_s3_wb_cyc            ( s_wb_cyc   [3]    ),
    .o_s3_wb_stb            ( s_wb_stb   [3]    ),
    .i_s3_wb_ack            ( s_wb_ack   [3]    ),
    .i_s3_wb_err            ( s_wb_err   [3]    ),


    // WISHBONE slave 4 - UART 1
    .o_s4_wb_adr            ( s_wb_adr   [4]    ),
    .o_s4_wb_sel            ( s_wb_sel   [4]    ),
    .o_s4_wb_we             ( s_wb_we    [4]    ),
    .i_s4_wb_dat            ( s_wb_dat_r [4]    ),
    .o_s4_wb_dat            ( s_wb_dat_w [4]    ),
    .o_s4_wb_cyc            ( s_wb_cyc   [4]    ),
    .o_s4_wb_stb            ( s_wb_stb   [4]    ),
    .i_s4_wb_ack            ( s_wb_ack   [4]    ),
    .i_s4_wb_err            ( s_wb_err   [4]    ),


    // WISHBONE slave 5 - Test Module
    .o_s5_wb_adr            ( s_wb_adr   [5]    ),
    .o_s5_wb_sel            ( s_wb_sel   [5]    ),
    .o_s5_wb_we             ( s_wb_we    [5]    ),
    .i_s5_wb_dat            ( s_wb_dat_r [5]    ),
    .o_s5_wb_dat            ( s_wb_dat_w [5]    ),
    .o_s5_wb_cyc            ( s_wb_cyc   [5]    ),
    .o_s5_wb_stb            ( s_wb_stb   [5]    ),
    .i_s5_wb_ack            ( s_wb_ack   [5]    ),
    .i_s5_wb_err            ( s_wb_err   [5]    ),


    // WISHBONE slave 6 - Timer Module
    .o_s6_wb_adr            ( s_wb_adr   [6]    ),
    .o_s6_wb_sel            ( s_wb_sel   [6]    ),
    .o_s6_wb_we             ( s_wb_we    [6]    ),
    .i_s6_wb_dat            ( s_wb_dat_r [6]    ),
    .o_s6_wb_dat            ( s_wb_dat_w [6]    ),
    .o_s6_wb_cyc            ( s_wb_cyc   [6]    ),
    .o_s6_wb_stb            ( s_wb_stb   [6]    ),
    .i_s6_wb_ack            ( s_wb_ack   [6]    ),
    .i_s6_wb_err            ( s_wb_err   [6]    ),


    // WISHBONE slave 7 - Interrupt Controller
    .o_s7_wb_adr            ( s_wb_adr   [7]    ),
    .o_s7_wb_sel            ( s_wb_sel   [7]    ),
    .o_s7_wb_we             ( s_wb_we    [7]    ),
    .i_s7_wb_dat            ( s_wb_dat_r [7]    ),
    .o_s7_wb_dat            ( s_wb_dat_w [7]    ),
    .o_s7_wb_cyc            ( s_wb_cyc   [7]    ),
    .o_s7_wb_stb            ( s_wb_stb   [7]    ),
    .i_s7_wb_ack            ( s_wb_ack   [7]    ),
    .i_s7_wb_err            ( s_wb_err   [7]    )
    );

`ifdef ETHERNET
ethmac_wb #(
    .WB_DWIDTH              ( WB_DWIDTH         ),
    .WB_SWIDTH              ( WB_SWIDTH         )
    )
u_ethmac_wb (
    // Wishbone arbiter side
    .o_m_wb_adr             ( m_wb_adr   [0]    ),
    .o_m_wb_sel             ( m_wb_sel   [0]    ),
    .o_m_wb_we              ( m_wb_we    [0]    ),
    .i_m_wb_rdat            ( m_wb_dat_r [0]    ),
    .o_m_wb_wdat            ( m_wb_dat_w [0]    ),
    .o_m_wb_cyc             ( m_wb_cyc   [0]    ),
    .o_m_wb_stb             ( m_wb_stb   [0]    ),
    .i_m_wb_ack             ( m_wb_ack   [0]    ),
    .i_m_wb_err             ( m_wb_err   [0]    ),

    // Wishbone arbiter side
    .i_s_wb_adr             ( s_wb_adr   [0]    ),
    .i_s_wb_sel             ( s_wb_sel   [0]    ),
    .i_s_wb_we              ( s_wb_we    [0]    ),
    .i_s_wb_cyc             ( s_wb_cyc   [0]    ),
    .i_s_wb_stb             ( s_wb_stb   [0]    ),
    .o_s_wb_ack             ( s_wb_ack   [0]    ),
    .i_s_wb_wdat            ( s_wb_dat_w [0]    ),
    .o_s_wb_rdat            ( s_wb_dat_r [0]    ),
    .o_s_wb_err             ( s_wb_err   [0]    ),

    // Ethmac side
    .i_m_wb_adr             ( emm_wb_adr        ),
    .i_m_wb_sel             ( emm_wb_sel        ),
    .i_m_wb_we              ( emm_wb_we         ),
    .o_m_wb_rdat            ( emm_wb_rdat       ),
    .i_m_wb_wdat            ( emm_wb_wdat       ),
    .i_m_wb_cyc             ( emm_wb_cyc        ),
    .i_m_wb_stb             ( emm_wb_stb        ),
    .o_m_wb_ack             ( emm_wb_ack        ),
    .o_m_wb_err             ( emm_wb_err        ),

    // Ethmac side
    .o_s_wb_adr             ( ems_wb_adr        ),
    .o_s_wb_sel             ( ems_wb_sel        ),
    .o_s_wb_we              ( ems_wb_we         ),
    .i_s_wb_rdat            ( ems_wb_rdat       ),
    .o_s_wb_wdat            ( ems_wb_wdat       ),
    .o_s_wb_cyc             ( ems_wb_cyc        ),
    .o_s_wb_stb             ( ems_wb_stb        ),
    .i_s_wb_ack             ( ems_wb_ack        ),
    .i_s_wb_err             ( ems_wb_err        )
);
`else	 
	assign m_wb_adr   [0] = 0;
	assign m_wb_sel   [0] = 0;
	assign m_wb_we    [0] = 0;
	assign m_wb_dat_w [0] = 0;
	assign m_wb_cyc   [0] = 0;
	assign m_wb_stb   [0] = 0;

	assign s_wb_ack   [0] = 0;
	assign s_wb_dat_r [0] = 0;
	assign s_wb_err   [0] = 0;	 
`endif

endmodule


