`timescale 1ns / 1ps

// RISC-V for Xilinx XUP Blackboard rev D (riscv.sv)
// Based on Jason Losh's Combo_Logic example
//
// Reset
//   Active-high reset on PB0

module riscv_top (
    input  CLK100,           // 100 MHz clock input
    output [9:0] LED,        // RGB1, RGB0, LED 9..0 placed from left to right
    output [2:0] RGB0,
    output [2:0] RGB1,
    output [3:0] SS_ANODE,   // Anodes 3..0 placed from left to right
    output [7:0] SS_CATHODE, // Bit order: DP, G, F, E, D, C, B, A
    input  [11:0] SW,        // SWs 11..0 placed from left to right
    input  [3:0] PB,         // PBs 3..0 placed from left to right
    inout  [23:0] GPIO,      // PMODA-C 1P, 1N, ... 3P, 3N order
    output [3:0] SERVO,      // Servo outputs
    output PDM_SPEAKER,      // PDM signals for mic and speaker
    input  PDM_MIC_DATA,      
    output PDM_MIC_CLK,
    output ESP32_UART1_TXD,  // WiFi/Bluetooth serial interface 1
    input  ESP32_UART1_RXD,
    output IMU_SCLK,         // IMU spi clk
    output IMU_SDI,          // IMU spi data input
    input  IMU_SDO_AG,       // IMU spi data output (accel/gyro)
    input  IMU_SDO_M,        // IMU spi data output (mag)
    output IMU_CS_AG,        // IMU cs (accel/gyro) 
    output IMU_CS_M,         // IMU cs (mag)
    input  IMU_DRDY_M,       // IMU data ready (mag)
    input  IMU_INT1_AG,      // IMU interrupt (accel/gyro)
    input  IMU_INT_M,        // IMU interrupt (mag)
    output IMU_DEN_AG        // IMU data enable (accel/gyro)
    );
     
    // Terminate all of the unused outputs or i/o's - (remove terminated assignments - '//', if planning to use variable)
    // assign LED = 10'b0000000000;
    assign RGB0 = 3'b000;
    assign RGB1 = 3'b000;
    // assign SS_ANODE = 4'b0000;
    // assign SS_CATHODE = 8'b11111111;
    assign GPIO = 24'bzzzzzzzzzzzzzzzzzzzzzzzz;
    assign SERVO = 4'b0000;
    assign PDM_SPEAKER = 1'b0;
    assign PDM_MIC_CLK = 1'b0;
    assign ESP32_UART1_TXD = 1'b0;
    assign IMU_SCLK = 1'b0;
    assign IMU_SDI = 1'b0;
    assign IMU_CS_AG = 1'b1;
    assign IMU_CS_M = 1'b1;
    assign IMU_DEN_AG = 1'b0;

    // display r on left seven segment display
    assign SS_ANODE = 4'b0111;
    assign SS_CATHODE = 8'b10101111;

    // use a simpler clock name
    wire clk = CLK100;
    
    // handle reset input metastability safely
    reg reset;
    reg pre_reset;
    always_ff @ (posedge(clk))
    begin
        pre_reset <= PB[0];
        reset <= pre_reset;
    end

    // MEM to DUAL PORT RAM Connections
    wire [31:2] mem_ram_addr;
    wire [31:0] mem_ram_rdata;
    wire mem_ram_we;
    wire [3:0] mem_ram_be;
    wire [31:0] mem_ram_wdata;

    // MEM to IO Connections
    wire [31:2] mem_io_addr;
    wire [31:0] mem_io_rdata;
    wire mem_io_we;
    wire [3:0] mem_io_be;
    wire [31:0] mem_io_wdata;

    // RISC TOP to IO Connections
    wire [7:0] risc_top_io_sw = SW[7:0];
    wire [7:0] io_risc_top_led;
    assign LED = io_risc_top_led;

    // IF to DUAL PORT RAM Connections
    wire [31:2] if_ram_iaddr;
    wire [31:0] if_ram_idata;

    // IF to ID Connections
    wire [31:0] if_id_pc;
    wire [31:0] if_id_iw;
    wire [31:0] pc_verify;

    // ID to IF Connections
    wire jump_enable_id_if;
    wire [31:0] jump_addr_id_if;

    // ID to EX Connections
    wire [31:0] id_ex_rs1_data;
    wire [31:0] id_ex_rs2_data;
    wire [31:0] id_ex_pc;
    wire [31:0] id_ex_iw;
    wire [4:0]  id_ex_wb_reg;
    wire        id_ex_wb_enable;
    wire        id_ex_str_we;

    // EX to MEM Connections
    wire [31:0] ex_mem_pc;
    wire [31:0] ex_mem_iw;
    wire [31:0] ex_mem_alu;
    wire [4:0]  ex_mem_wb_reg;
    wire        ex_mem_wb_enable;
    wire [31:0] ex_mem_rs1_data;
    wire        ex_mem_str_we;

    // MEM to WB Connections
    wire [31:0] mem_wb_pc;
    wire [31:0] mem_wb_iw;
    wire [31:0] mem_wb_alu;
    wire [4:0]  mem_wb_reg;
    wire        mem_wb_wb_enable;
    wire [31:0] mem_wb_mem_rdata;
    wire [31:0] mem_wb_io_rdata;
    wire [2:0]  mem_wb_wb_en_select;  // new wire for lab 8
    wire [1:0]  mem_wb_address_mod;   // new wire for lab 8
    
    // ID to REGISTER Connections
    wire [4:0]  id_regs_rs1_reg;
    wire [4:0]  id_regs_rs2_reg;
    wire [31:0] id_regs_rs1_data;
    wire [31:0] id_regs_rs2_data;

    // WB to REGISTER Connections
    wire        wb_regs_wb_enable;
    wire [4:0]  wb_regs_wb_reg;
    wire [31:0] wb_regs_wb_data;

    // Data Hazard: DF from EX Connections
    wire df_ex_enable;
    wire [4:0]  df_ex_reg;
    wire [31:0] df_ex_data;

    // Data Hazard: DF from MEM Connections
    wire df_mem_enable;
    wire [4:0]  df_mem_reg;
    wire [31:0] df_mem_data;

    // Data Hazard: DF from WB Connections
    wire df_wb_enable;
    wire [4:0]  df_wb_reg;
    wire [31:0] df_wb_data;

    // Temp wires to validate df handler
    wire [31:0] rs1_df_output;
    wire [31:0] rs2_df_output;

    // Temporary EBREAK stop Connection
    wire ebreak;

    // Instantiated Modules - Format: .<module variable>(<current module variable>)

    ila_0 ila_temp (
	.clk(clk),          // input wire clk
	.probe0(if_id_pc),  // input wire [31:0]  probe0  
	.probe1(if_id_iw),  // input wire [31:0]  probe1 
	.probe2(id_ex_pc),  // input wire [31:0]  probe2 
	.probe3(id_ex_iw),  // input wire [31:0]  probe3 
	.probe4(ex_mem_pc), // input wire [31:0]  probe4 
	.probe5(ex_mem_iw), // input wire [31:0]  probe5 
	.probe6(mem_wb_pc), // input wire [31:0]  probe6 
	.probe7(mem_wb_iw), // input wire [31:0]  probe7

    .probe8(id_ex_rs1_data),   // input wire [31:0]  probe8 
	.probe9(id_ex_rs2_data),   // input wire [31:0]  probe9 
	.probe10(id_ex_wb_reg),     // input wire [4:0]  probe10 
	.probe11(id_ex_wb_enable),  // input wire [0:0]  probe11 
	.probe12(ex_mem_alu),       // input wire [31:0]  probe12
	.probe13(ex_mem_wb_reg),    // input wire [4:0]  probe13
	.probe14(ex_mem_wb_enable), // input wire [0:0]  probe14 
	.probe15(mem_wb_alu),       // input wire [31:0]  probe15

	.probe16(mem_wb_reg),       // input wire [4:0]  probe16
	.probe17(mem_wb_wb_enable), // input wire [0:0]  probe17 
	.probe18(wb_regs_wb_enable),// input wire [0:0]  probe18 
	.probe19(wb_regs_wb_reg),   // input wire [4:0]  probe19 
	.probe20(wb_regs_wb_data),  // input wire [31:0]  probe20 
	.probe21(ebreak),           // input wire [0:0]  probe21 
    .probe22(rs1_df_output),    // input wire [31:0]  probe22
    .probe23(rs2_df_output),    // input wire [31:0]  probe23

    .probe24(if_ram_iaddr),
    .probe25(if_ram_idata),
    .probe26(id_ex_str_we),
    .probe27(ex_mem_str_we),
    .probe28(ex_mem_rs2_data),
    .probe29(mem_ram_addr),
    .probe30(mem_ram_rdata),
    .probe31(mem_ram_we),

    .probe32(mem_ram_be),
    .probe33(mem_ram_wdata),
    .probe34(mem_io_addr),
    .probe35(mem_io_rdata),
    .probe36(mem_io_we),
    .probe37(mem_io_be),
    .probe38(mem_io_wdata),
    .probe39(mem_wb_mem_rdata),

    .probe40(mem_wb_io_rdata),
    .probe41(mem_wb_wb_en_select)
    );

    // Instantiated io.sv module
    io_module io_mod (
    .clk(clk),
    .io_addr(mem_io_addr),      // from mem
    .io_rdata(mem_io_rdata),    // to mem
    .io_we(mem_io_we),          // from mem
    .io_be(mem_io_be),          // from mem
    .io_wdata(mem_io_wdata),    // from mem
    .io_sw(risc_top_io_sw),     // from riscv top
    .io_led(io_risc_top_led)    // to riscv top
    );

    // Instantiated dual_port_ram.sv module 
    dual_port_ram dp_ram (
    .clk(clk),                  // system clock
    .i_addr(if_ram_iaddr),      // from if
    .i_rdata(if_ram_idata),     // from if
    .d_addr(mem_ram_addr),      // from mem
    .d_rdata(mem_ram_rdata),    // from mem
    .d_we(mem_ram_we),          // from mem
    .d_be(mem_ram_be),          // from mem
    .d_wdata(mem_ram_wdata)     // from mem
    );

    // Instantiated rv32I_regs.sv module 
    rv32i_regs reg_mod (
    .clk(clk),                      // system clock
    .reset(reset),                  // synchronous reset
    .rs1_reg(id_regs_rs1_reg),      // from id
    .rs2_reg(id_regs_rs2_reg),      // from id
    .wb_enable(wb_regs_wb_enable),  // from wb
    .wb_reg(wb_regs_wb_reg),        // from wb
    .wb_data(wb_regs_wb_data),      // from wb
    .rs1_data(id_regs_rs1_data),    // from id
    .rs2_data(id_regs_rs2_data)     // from id
    );

    // Instantiated rv32_if_top.sv module 
    rv32_if_top if_mod (
    .clk(clk),                              // system clock
    .reset(reset),                          // synchronous reset
    .memif_addr(if_ram_iaddr),              // memory interface
    .memif_data(if_ram_idata),              // memory interface
    .pc_out(if_id_pc),                      // to id
    .pc_verify(pc_verify),  // testing wire for pc verification
    .iw_out(if_id_iw),                      // to id
    .jump_enable_in(jump_enable_id_if),     // from id
    .jump_addr_in(jump_addr_id_if),         // from id
    .ebreak(ebreak)                         // TEMPORARY STOP CONIDITION 
    );

    // Instantiated rv32_id_top.sv module 
    rv32_id_top id_mod (
    .clk(clk),                          // system clock
    .reset(reset),                      // synchronous reset
    .pc_in(if_id_pc),                   // from if
    .pc_verify(pc_verify),  // testing wire for pc verification
    .iw_in(if_id_iw),                   // from if
    .regif_rs1_reg(id_regs_rs1_reg),    // register interface
    .regif_rs2_reg(id_regs_rs2_reg),    // register interface
    .regif_rs1_data(id_regs_rs1_data),  // register interface
    .regif_rs2_data(id_regs_rs2_data),  // register interface
    .rs1_data_out(id_ex_rs1_data),      // to ex
    .rs2_data_out(id_ex_rs2_data),      // to ex
    .pc_out(id_ex_pc),                  // to ex  
    .iw_out(id_ex_iw),                  // to ex  
    .wb_reg_out(id_ex_wb_reg),          // to ex      
    .wb_enable_out(id_ex_wb_enable),    // to ex
    .store_we_out(id_ex_str_we),        // to ex - new wire for lab 8
    // NEW CONNECTIONS FOR LAB 6
    .df_ex_enable(df_ex_enable),        // from ex
    .df_ex_reg(df_ex_reg),              // from ex
    .df_ex_data(df_ex_data),            // from ex
    .df_mem_enable(df_mem_enable),      // from mem
    .df_mem_reg(df_mem_reg),            // from mem
    .df_mem_data(df_mem_data),          // from mem
    .df_wb_enable(df_wb_enable),        // from wb
    .df_wb_reg(df_wb_reg),              // from wb
    .df_wb_data(df_wb_data),            // from wb
    // Jump Handlers for lab 7
    .jump_enable_out(jump_enable_id_if), // to id
    .jump_addr_out(jump_addr_id_if),     // to id
    // Temp wires for df testing
    .rs1_df_output(rs1_df_output),
    .rs2_df_output(rs2_df_output)
    );

    // Instantiated rv32_ex_top.sv module 
    rv32_ex_top ex_mod (
    .clk(clk),                          // system clock
    .reset(reset),                      // synchronous reset
    .pc_in(id_ex_pc),                   // from id
    .iw_in(id_ex_iw),                   // from id
    .rs1_data_in(id_ex_rs1_data),       // from id
    .rs2_data_in(id_ex_rs2_data),       // from id
    .wb_reg_in(id_ex_wb_reg),           // from id
    .wb_enable_in(id_ex_wb_enable),     // from id
    .store_we_in(id_ex_str_we),         // from id - new wire for lab 8
    .pc_out(ex_mem_pc),                 // to mem
    .iw_out(ex_mem_iw),                 // to mem
    .alu_out(ex_mem_alu),               // to mem
    .wb_reg_out(ex_mem_wb_reg),         // to mem
    .wb_enable_out(ex_mem_wb_enable),   // to mem

    .store_we_out(ex_mem_str_we),       // from id - new wire for lab 8
    .rs2_data_out(ex_mem_rs1_data),     // to mem - new wire for lab 8

    .df_ex_enable(df_ex_enable),        // to id
    .df_ex_reg(df_ex_reg),              // to id
    .df_ex_data(df_ex_data)             // to id
    );

    // Instantiated rv32_mem_top.sv module 
    rv32_mem_top mem_mod (
    .clk(clk),                          // system clock
    .reset(reset),                      // synchronous reset
    .pc_in(ex_mem_pc),                  // from ex
    .iw_in(ex_mem_iw),                  // from ex
    .alu_in(ex_mem_alu),                // from ex
    .wb_reg_in(ex_mem_wb_reg),          // from ex
    .wb_enable_in(ex_mem_wb_enable),    // from ex

    .store_we_in(ex_mem_str_we),       // from id - new wire for lab 8
    .rs2_data_in(ex_mem_rs1_data),      // from ex - new wire for lab 8
    
    .pc_out(mem_wb_pc),                 // to wb
    .iw_out(mem_wb_iw),                 // to wb
    .alu_out(mem_wb_alu),               // to wb
    .wb_reg_out(mem_wb_reg),            // to wb
    .wb_enable_out(mem_wb_wb_enable),   // to wb

    .wb_we_select_out(mem_wb_wb_en_select), // to wb - new wire for lab 8
    .address_mod_out(mem_wb_address_mod),   // to wb - new wire for lab 8
    .mem_rdata_out(mem_wb_mem_rdata),   // to wb - new wire for lab 8
    .io_rdata_out(mem_wb_io_rdata),     // to wb - new wire for lab 8

    // LAB 7 - memory interface
    .memif_addr(mem_ram_addr),          // to dp ram - new wire for lab 8
    .memif_rdata(mem_ram_rdata),        // to dp ram - new wire for lab 8
    .memif_we(mem_ram_we),              // to dp ram - new wire for lab 8
    .memif_be(mem_ram_be),              // to dp ram - new wire for lab 8
    .memif_wdata(mem_ram_wdata),        // to dp ram - new wire for lab 8
    // LAB 7 - IO interface
    .io_addr(mem_io_addr),              // to io   - new wire for lab 8
    .io_rdata(mem_io_rdata),            // from io - new wire for lab 8
    .io_we(mem_io_we),                  // to io   - new wire for lab 8
    .io_be(mem_io_be),                  // to io   - new wire for lab 8
    .io_wdata(mem_io_wdata),            // to io   - new wire for lab 8
    // data hazard: df to id
    .df_mem_enable(df_mem_enable),      // to id
    .df_mem_reg(df_mem_reg),            // to id
    .df_mem_data(df_mem_data)           // to id
    );

    // Instantiated rv32_wb_top.sv module 
    rv32_wb_top wb_mod (
    .clk(clk),                              // system clock
    .reset(reset),                          // synchronous reset
    .pc_in(mem_wb_pc),                      // from mem
    .iw_in(mem_wb_iw),                      // from mem
    .alu_in(mem_wb_alu),                    // from mem
    .wb_reg_in(mem_wb_reg),                 // from mem
    .wb_enable_in(mem_wb_wb_enable),        // from mem

    .mem_rdata_in(mem_wb_mem_rdata),        // from mem new wire for lab 8
    .io_rdata_in(mem_wb_io_rdata),          // from mem new wire for lab 8
    .wb_we_select_in(mem_wb_wb_en_select),  // from mem new wire for lab 8
    .address_mod_in(mem_wb_address_mod),    // from mem new wire for lab 8

    .regif_wb_enable(wb_regs_wb_enable),    // register interface
    .regif_wb_reg(wb_regs_wb_reg),          // register interface
    .regif_wb_data(wb_regs_wb_data),        // register interface
    .ebreak(ebreak),                        // TEMPORARY STOP CONIDITION 
    // NEW CONNECTIONS FOR LAB 6
    .df_wb_enable(df_wb_enable),            // to id
    .df_wb_reg(df_wb_reg),                  // to id
    .df_wb_data(df_wb_data)                 // to id
    );
endmodule