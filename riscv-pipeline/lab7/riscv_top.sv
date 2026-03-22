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

    // Unused DUAL PORT RAM Connections
    wire [31:2] xx_ram_daddr;
    wire [31:0] xx_ram_rdata;
    wire xx_ram_d_w_enable;
    wire [3:0] xx_ram_d_b_enable;
    wire [31:0] xx_ram_d_wdata;

    // IF to DUAL PORT RAM Connections
    wire [31:2] if_ram_iaddr;
    wire [31:0] if_ram_idata;

    // IF to ID Connections
    wire [31:0] if_id_pc;
    wire [31:0] if_id_iw;

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

    // EX to MEM Connections
    wire [31:0] ex_mem_pc;
    wire [31:0] ex_mem_iw;
    wire [31:0] ex_mem_alu;
    wire [4:0]  ex_mem_wb_reg;
    wire        ex_mem_wb_enable;

    // MEM to WB Connections
    wire [31:0] mem_wb_pc;
    wire [31:0] mem_wb_iw;
    wire [31:0] mem_wb_alu;
    wire [4:0]  mem_wb_reg;
    wire        mem_wb_wb_enable;
    
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

    wire [1:0] jp_inst_output;
    wire [11:0] b_branch_output;
    wire [2:0] branch_funct3_output;

    wire [31:0] pc_verify;

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

	.probe8(id_regs_rs1_reg),   // input wire [4:0]  probe8 
	.probe9(id_regs_rs2_reg),   // input wire [4:0]  probe9 
	.probe10(id_regs_rs1_data), // input wire [31:0]  probe10 
	.probe11(id_ex_rs1_data),   // input wire [31:0]  probe11 
	.probe12(id_ex_rs2_data),   // input wire [31:0]  probe12 
	.probe13(id_ex_wb_reg),     // input wire [4:0]  probe13 
	.probe14(id_ex_wb_enable),  // input wire [0:0]  probe14 
	.probe15(ex_mem_alu),       // input wire [31:0]  probe15

	.probe16(ex_mem_wb_reg),    // input wire [4:0]  probe16 
	.probe17(ex_mem_wb_enable), // input wire [0:0]  probe17 
	.probe18(mem_wb_alu),       // input wire [31:0]  probe18 
	.probe19(mem_wb_reg),       // input wire [4:0]  probe19 
	.probe20(mem_wb_wb_enable), // input wire [0:0]  probe20 
	.probe21(wb_regs_wb_enable),// input wire [0:0]  probe21 
	.probe22(wb_regs_wb_reg),   // input wire [4:0]  probe22 
	.probe23(wb_regs_wb_data),  // input wire [31:0]  probe23 
	.probe24(ebreak),           // input wire [0:0]  probe24 
	.probe25(jump_addr_id_if), // input wire [31:0]  probe25      -> previously was id_regs_rs2_data
    
    .probe26(df_ex_enable),
    .probe27(df_ex_reg),
    .probe28(df_ex_data),
    .probe29(df_mem_enable),
    .probe30(df_mem_reg),
    .probe31(df_mem_data),
    .probe32(df_wb_enable),
    .probe33(df_wb_reg),
    .probe34(df_wb_data),
    .probe35(rs1_df_output),
    .probe36(rs2_df_output),
    .probe37(jp_inst_output),
    .probe38(b_branch_output),
    .probe39(branch_funct3_output),
    .probe40(if_ram_iaddr),
    .probe41(if_ram_idata)
    );

    // Instantiated dual_port_ram.sv module 
    dual_port_ram dp_ram (
    .clk(clk),                  // system clock
    .reset(reset),
    .i_addr(if_ram_iaddr),      // from if
    .i_rdata(if_ram_idata),     // from if
    .d_addr(xx_ram_daddr),      // CURRENTLY UNUSED
    .d_rdata(xx_ram_rdata),     // CURRENTLY UNUSED
    .d_we(xx_ram_d_w_enable),   // CURRENTLY UNUSED    
    .d_be(xx_ram_d_b_enable),   // CURRENTLY UNUSED
    .d_wdata(xx_ram_d_wdata)    // CURRENTLY UNUSED
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
    .rs2_df_output(rs2_df_output),
    .jp_inst_output(jp_inst_output),
    .b_branch_output(b_branch_output),
    .branch_funct3_output(branch_funct3_output)
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
    .pc_out(ex_mem_pc),                 // to mem
    .iw_out(ex_mem_iw),                 // to mem
    .alu_out(ex_mem_alu),               // to mem
    .wb_reg_out(ex_mem_wb_reg),         // to mem
    .wb_enable_out(ex_mem_wb_enable),   // to mem
    // NEW CONNECTIONS FOR LAB 6
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
    .pc_out(mem_wb_pc),                 // to wb
    .iw_out(mem_wb_iw),                 // to wb
    .alu_out(mem_wb_alu),               // to wb
    .wb_reg_out(mem_wb_reg),            // to wb
    .wb_enable_out(mem_wb_wb_enable),   // to wb
    // NEW CONNECTIONS FOR LAB 6
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