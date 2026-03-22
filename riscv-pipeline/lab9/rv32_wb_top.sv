`timescale 1ns / 1ps

module rv32_wb_top (
    // system clock and synchronous reset
    input clk,
    input reset,
    // from mem
    input [31:0] pc_in,
    input [31:0] iw_in,
    input [31:0] alu_in,
    input [4:0] wb_reg_in,
    input wb_enable_in,
    input [31:0] mem_rdata_in,  
    input [31:0] io_rdata_in,   
    input [2:0] wb_we_select_in,
    input [1:0] address_mod_in, 
    input wb_from_mem_in,          // new wire for lab 9
    // register interface
    output regif_wb_enable,
    output [4:0] regif_wb_reg,
    output [31:0] regif_wb_data,
    // data hazard: df to id
    output df_wb_enable,
    output [4:0] df_wb_reg,
    output [31:0] df_wb_data,
    output df_wb_from_wb_ex        // new wire for lab 9
);

    // Unused Variables - used for pipeline viewing
    wire [31:0] wb_pc = pc_in;
    wire [31:0] wb_iw = iw_in;

    // WB Data Selection Handler
    reg [31:0] wb_data_select;
    always_comb
    begin
        case(wb_we_select_in)
            3'b100:  wb_data_select = io_rdata_in;  // IO Data
            3'b010:  wb_data_select = mem_rdata_in; // Memory Data
            3'b001:  wb_data_select = alu_in;       // ALU Data
            default: wb_data_select = 32'b0;
        endcase
    end

    // Data Shifter Handlers
    wire iw_signed         = ((iw_in[6:0] == 7'b0000011) && (iw_in[14] == 1'b0));  // During Load instr, if !iw[14] - signed
    wire [1:0] data_length = ((iw_in[6:0] == 7'b0000011) && (iw_in[13:12] == 2'b00)) ? 2'b10 :
                             ((iw_in[6:0] == 7'b0000011) && (iw_in[13:12] == 2'b01)) ? 2'b01 : 2'b00; // During load, if iw[13:12] = 0 - byte, if 1 - h, else word 
    wire [31:0] data_shifted;

    // Writeback Handler - For Register Write
    assign regif_wb_enable = wb_enable_in;
    assign regif_wb_reg    = wb_reg_in;
    assign regif_wb_data   = data_shifted;

    // Data Forward Handler - For ID 
    assign df_wb_enable = wb_enable_in;
    assign df_wb_reg    = wb_reg_in;    // Also used in EX for data hazard
    assign df_wb_data   = data_shifted; // Also used in EX for data hazard

    // Data Forward Handler - For EX 
    assign df_wb_from_wb_ex = wb_from_mem_in; // Allows EX instr. to fix potentially corrupt data

    // Instantiate data_shifter.sv
    data_shifter d_s2 (
    .reg_data(wb_data_select),      // Input: Data to be shifted)
    .sign_value(iw_signed),         // Input: Indecates output to be signed/unsigned
    .addr_offset(address_mod_in),   // Input: Address offset (address mod)
    .data_length(data_length),      // Input: Data length desired
    .reg_shift(data_shifted)        // Output: Data shifted for WB (to reg)
    );
endmodule