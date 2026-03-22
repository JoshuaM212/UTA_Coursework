`timescale 1ns / 1ps

module rv32_ex_top (
    // system clock and synchronous reset
    input clk,
    input reset,
    // from id
    input [31:0] pc_in,
    input [31:0] iw_in,
    input [31:0] rs1_data_in,
    input [31:0] rs2_data_in,
    input [4:0] wb_reg_in,
    input wb_enable_in,
    input store_we_in,                  // new wire for lab 8
    // to mem
    output reg [31:0] pc_out,
    output reg [31:0] iw_out,
    output reg [31:0] alu_out,
    output reg [4:0] wb_reg_out,
    output reg wb_enable_out,
    output reg [31:0] rs2_data_out,     // new wire for lab 8
    output reg store_we_out,            // new wire for lab 8
    // data hazard: df to id
    output df_ex_enable,
    output [4:0] df_ex_reg,
    output [31:0] df_ex_data
);

    // ALU output wire
    wire [31:0] alu_mod_output;

    // Data Forward Handlers
    assign df_ex_enable = wb_enable_in;
    assign df_ex_reg    = wb_reg_in;
    assign df_ex_data   = alu_mod_output;

    // EX synchronous output
    // -reset: all outputs are zero'd
    // -default:  output latched data for MEM 
    always_ff @ (posedge (clk))
    begin
        if (reset)
        begin
            alu_out       <= 32'b0;
            wb_reg_out    <= 5'b0;
            wb_enable_out <= 1'b0;
            pc_out        <= 32'b0;
            iw_out        <= 32'b0;
            rs2_data_out  <= 32'b0;
            store_we_out  <= 1'b0;
        end
        else
        begin
            alu_out       <= alu_mod_output;
            pc_out        <= pc_in;
            iw_out        <= iw_in;
            wb_reg_out    <= wb_reg_in;
            wb_enable_out <= wb_enable_in;
            rs2_data_out  <= rs2_data_in;
            store_we_out  <= store_we_in;
        end
    end

    // Instantiated alu.sv module 
    alu al (
    .pc_in(pc_in),              // pc variable received
    .iw_in(iw_in),              // instruction word received
    .rs1_data_in(rs1_data_in),  // register 1 received
    .rs2_data_in(rs2_data_in),  // register 2 received
    .alu_out(alu_mod_output)    // ALU output from module
    );
endmodule