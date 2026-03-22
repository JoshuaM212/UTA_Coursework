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
    // register interface
    output regif_wb_enable,
    output [4:0] regif_wb_reg,
    output [31:0] regif_wb_data,

    // Temporary EBREAK stop condition
    output reg ebreak
);

    // Writeback Handler
    assign regif_wb_enable = wb_enable_in;
    assign regif_wb_reg    = wb_reg_in;
    assign regif_wb_data   = alu_in;

    // Temporary - EBREAK Handler
    always_ff @ (posedge (clk))
    if (reset)
        ebreak <= 1'b0;
    else if ((iw_in[6:0] == 7'b1110011) && iw_in[20])
        ebreak <= 1'b1;
endmodule