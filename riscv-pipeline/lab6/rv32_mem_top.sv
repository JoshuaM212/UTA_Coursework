`timescale 1ns / 1ps

module rv32_mem_top (
    // system clock and synchronous reset
    input clk,
    input reset,
    // from ex
    input [31:0] pc_in,
    input [31:0] iw_in,
    input [31:0] alu_in,
    input [4:0] wb_reg_in,
    input wb_enable_in,
    // to wb
    output reg [31:0] pc_out,
    output reg [31:0] iw_out,
    output reg [31:0] alu_out,
    output reg [4:0] wb_reg_out,
    output reg wb_enable_out,

    // data hazard: df to id
    output df_mem_enable,
    output [4:0] df_mem_reg,
    output [31:0] df_mem_data
);

    // Data Forward Handler
    assign df_mem_enable = wb_enable_in;
    assign df_mem_reg    = wb_reg_in;
    assign df_mem_data   = alu_in;

    // pc, iw, alu, wb_reg, & wb_enable handler
    always_ff @ (posedge (clk))
    begin
        if (reset)
        begin
            pc_out <= 32'b0;
            iw_out <= 32'b0;
            alu_out <= 32'b0;
            wb_reg_out <= 5'b0;
            wb_enable_out <= 1'b0;
        end
        else
        begin
            pc_out <= pc_in;
            iw_out <= iw_in;
            alu_out <= alu_in;
            wb_reg_out <= wb_reg_in;
            wb_enable_out <= wb_enable_in;
        end
    end
endmodule