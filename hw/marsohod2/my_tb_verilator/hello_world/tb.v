
`timescale  1 ns / 1 ns

module tb(
	input wire clk_80mhz,
	input wire clk_uart,
	input wire sysrst
);

reg [31:0]              clk_count = 'd0;

integer                 log_file;

integer                 boot_mem_file;
reg     [31:0]          boot_mem_file_address;
reg     [31:0]          boot_mem_file_data;
reg     [127:0]         boot_mem_file_data_128;
integer                 boot_mem_line_count;
integer                 fgets_return;
reg     [120*8-1:0]     line;
reg     [120*8-1:0]     aligned_line;
integer                 timeout = 0;

wire                    uart0_cts;
wire                    uart0_rx;
wire                    uart0_rts;
wire                    uart0_tx;
wire 	led;

`include "debug_functions.v"
`include "global_defines.v"

`define AMBER_TEST_NAME         "my ARM simulation"
`define BOOT_MEM_FILE           "hello-world.mem"
`define AMBER_LOG_FILE          "tests.log"
`define AMBER_UART_BAUD 921600

// ======================================
// Instantiate FPGA
// ======================================
msystem u_system (
    // Clocks and resets
    .brd_n_rst          ( sysrst            ),
    .brd_clk_p          ( clk_80mhz        ),
    
    // UART 0 signals
    //.o_uart0_cts        ( uart0_cts         ),
    .o_uart0_rx         ( uart0_rx          ),
    //.i_uart0_rts        ( uart0_rts         ),
    .i_uart0_tx         ( uart0_tx          ),
        
	.led				(led)
);

// ======================================
// Instantiate Testbench UART
// ======================================
tb_uart2 u_tb_uart (
    .clk_uart( clk_uart ),
    .clk_uart_rst_n( sysrst ),
    .i_uart_cts_n   ( uart0_cts ),          // Clear To Send
    .i_uart_rxd     ( uart0_rx  ),
    .o_uart_rts_n   ( uart0_rts ),          // Request to Send
    .o_uart_txd     ( uart0_tx  )
);

// ======================================
// Counter of system clock ticks        
// ======================================
always @ ( posedge `U_SYSTEM.sys_clk )
    clk_count <= clk_count + 1'd1;

// ======================================
// Initialize Boot Memory
// ======================================
    initial
        begin
`ifndef XILINX_FPGA
        $display("Load boot memory from %s", `BOOT_MEM_FILE);
        boot_mem_line_count   = 0;
        boot_mem_file         = $fopen(`BOOT_MEM_FILE,    "r");
        if (boot_mem_file == 0)
            begin
            `TB_ERROR_MESSAGE
            $display("ERROR: Can't open input file %s", `BOOT_MEM_FILE);
            end
        
        if (boot_mem_file != 0)
            begin  
            fgets_return = 1;
            while (fgets_return != 0)
                begin
                fgets_return        = $fgets(line, boot_mem_file);
                boot_mem_line_count = boot_mem_line_count + 1;
                aligned_line        = align_line(line);
                
                // if the line does not start with a comment
                if (aligned_line[120*8-1:118*8] != 16'h2f2f)
                    begin
                    // check that line doesnt start with a '@' or a blank
                    if (aligned_line[120*8-1:119*8] != 8'h40 && aligned_line[120*8-1:119*8] != 8'h00)
                        begin
                        $display("Format ERROR in input file %s, line %1d. Line must start with a @, not %08x", 
                                 `BOOT_MEM_FILE, boot_mem_line_count, aligned_line[118*8-1:117*8]);
                        `TB_ERROR_MESSAGE
                        end
                    
                    if (aligned_line[120*8-1:119*8] != 8'h00)
                        begin
                        boot_mem_file_address  =   hex_chars_to_32bits (aligned_line[119*8-1:111*8]);
                        boot_mem_file_data     =   hex_chars_to_32bits (aligned_line[110*8-1:102*8]);
                        
                        `ifdef AMBER_A25_CORE
                            boot_mem_file_data_128 = `U_BOOT_MEM.u_mem.mem[boot_mem_file_address[12:4]];
                            `U_BOOT_MEM.u_mem.mem[boot_mem_file_address[12:4]] = 
                                    insert_32_into_128 ( boot_mem_file_address[3:2], 
                                                         boot_mem_file_data_128, 
                                                         boot_mem_file_data );
                        `else
                            `U_BOOT_MEM.u_mem.mem[boot_mem_file_address[12:2]] = boot_mem_file_data;
                        `endif
                        
                        `ifdef AMBER_LOAD_MEM_DEBUG
                            $display ("Load Boot Mem: PAddr: 0x%08x, Data 0x%08x", 
                                        boot_mem_file_address, boot_mem_file_data);
                        `endif   
                        end
                    end  
                end
                
            $display("Read in %1d lines", boot_mem_line_count);      
            end
`endif
            
        // Grab the test name from memory    
        timeout   = `AMBER_TIMEOUT   ;           
        $display("log file %s, timeout %0d, test name %0s ", `AMBER_LOG_FILE, timeout, `AMBER_TEST_NAME );          
        log_file = $fopen(`AMBER_LOG_FILE, "a");                               
        end

// ======================================
reg testfail;
initial
begin
	testfail  = 1'd0;
end

// ======================================
// Functions
// ======================================
function [127:0] insert_32_into_128;
input [1:0]   pos;
input [127:0] word128;
input [31:0]  word32;
begin
     case (pos)
         2'd0: insert_32_into_128 = {word128[127:32], word32};
         2'd1: insert_32_into_128 = {word128[127:64], word32, word128[31:0]};
         2'd2: insert_32_into_128 = {word128[127:96], word32, word128[63:0]};
         2'd3: insert_32_into_128 = {word32, word128[95:0]};
     endcase
end
endfunction

endmodule

