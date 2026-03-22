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
    input [31:0] mem_rdata_in,  // new wire for lab 8
    input [31:0] io_rdata_in,   // new wire for lab 8
    input [2:0] wb_we_select_in,// new wire for lab 8
    input [1:0] address_mod_in, // new wire for lab 8
    // register interface   
    output regif_wb_enable,
    output [4:0] regif_wb_reg,
    output [31:0] regif_wb_data,

    // Temporary EBREAK stop condition
    output reg ebreak,

    // data hazard: df to id
    output df_wb_enable,
    output [4:0] df_wb_reg,
    output [31:0] df_wb_data
);

    // Unsused WB Values
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
    wire iw_signed = ((iw_in[6:0] == 7'b0000011) && (iw_in[14] == 1'b0)) ? 1'b1 : 1'b0;  // During Load instr, if !iw[14] - signed
    wire [1:0] data_length = ((iw_in[6:0] == 7'b0000011) && (iw_in[13:12] == 2'b00)) ? 2'b10 :
                             ((iw_in[6:0] == 7'b0000011) && (iw_in[13:12] == 2'b01)) ? 2'b01 : 2'b00; // During load, if iw[13:12] = 0 - byte, if 1 - h, else word 
    wire [31:0] data_shifted;

    // Writeback Handler
    assign regif_wb_enable = wb_enable_in;
    assign regif_wb_reg    = wb_reg_in;
    assign regif_wb_data   = data_shifted;

    // Data Forward Handler
    assign df_wb_enable = regif_wb_enable;
    assign df_wb_reg    = regif_wb_reg;
    assign df_wb_data   = regif_wb_data;

    // Temporary - EBREAK Handler
    always_ff @ (posedge (clk))
    begin
    if (reset)
        ebreak <= 1'b0;
    else if ((iw_in[6:0] == 7'b1110011) && iw_in[20])
        ebreak <= 1'b1;
    end

    // Instantiate data_shifter.sv
    data_shifter d_s2 (
    .reg_data(wb_data_select),      // Input: Data to be shifted)
    .sign_value(iw_signed),         // Input: Indecates output to be signed/unsigned
    .addr_offset(address_mod_in),   // Input: Address offset (address mod)
    .data_length(data_length),      // Input: Data length desired
    .reg_shift(data_shifted)        // Output: Data shifted for WB (to reg)
    );
endmodule