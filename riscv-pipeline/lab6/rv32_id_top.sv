`timescale 1ns / 1ps

module rv32_id_top (
    // system clock and synchronous reset
    input clk,
    input reset,
    // from if
    input [31:0] pc_in,
    input [31:0] iw_in,
    // register interface
    output [4:0] regif_rs1_reg,
    output [4:0] regif_rs2_reg,
    input [31:0] regif_rs1_data,
    input [31:0] regif_rs2_data,
    // to ex
    output reg [31:0] rs1_data_out,
    output reg [31:0] rs2_data_out,
    output reg [31:0] pc_out,
    output reg [31:0] iw_out,
    output reg [4:0] wb_reg_out,
    output reg wb_enable_out,

    // data hazard: df from ex
    input df_ex_enable,
    input [4:0] df_ex_reg,
    input [31:0] df_ex_data,
    // data hazard: df from mem
    input df_mem_enable,
    input [4:0] df_mem_reg,
    input [31:0] df_mem_data,
    // data hazard: df from wb
    input df_wb_enable,
    input [4:0] df_wb_reg,
    input [31:0] df_wb_data,

    // Test wires
    output [31:0] rs1_df_output,
    output [31:0] rs2_df_output
);

    // RS1 and RS2 Register Number Extraction
    wire rs1_reg_true = ( (iw_in[6:0] == 7'b0110011) || (iw_in[6:0] == 7'b1100111) || (iw_in[6:0] == 7'b0000011) || 
                          (iw_in[6:0] == 7'b0010011) || (iw_in[6:0] == 7'b0100011) || (iw_in[6:0] == 7'b1100011) );
    wire rs2_reg_true = ( (iw_in[6:0] == 7'b0110011) || (iw_in[6:0] == 7'b0100011) || (iw_in[6:0] == 7'b1100011) );

    // WB Register Destination (w/ Enable) Extraction
    wire wb_true = ( (iw_in[6:0] == 7'b0110011) || (iw_in[6:0] == 7'b1100111) || (iw_in[6:0] == 7'b0000011) || 
                     (iw_in[6:0] == 7'b0010011) || (iw_in[6:0] == 7'b0001111) || (iw_in[6:0] == 7'b0110111) ||
                     (iw_in[6:0] == 7'b0010111) || (iw_in[6:0] == 7'b1101111) );

    assign regif_rs1_reg = (rs1_reg_true) ? iw_in[19:15] : 32'b0; 
    assign regif_rs2_reg = (rs2_reg_true) ? iw_in[24:20] : 32'b0;

    // Data Hazard Handler
    wire [31:0] rs1_df_data;
    wire [31:0] rs2_df_data;

    assign rs1_df_output = rs1_df_data;
    assign rs2_df_output = rs2_df_data;
    
    assign rs1_df_data = (df_ex_enable  && (regif_rs1_reg == df_ex_reg))  ? df_ex_data  : 
                         (df_mem_enable && (regif_rs1_reg == df_mem_reg)) ? df_mem_data :
                         (df_wb_enable  && (regif_rs1_reg == df_wb_reg))  ? df_wb_data  : regif_rs1_data;

    assign rs2_df_data = (df_ex_enable  && (regif_rs2_reg == df_ex_reg))  ? df_ex_data  : 
                         (df_mem_enable && (regif_rs2_reg == df_mem_reg)) ? df_mem_data :
                         (df_wb_enable  && (regif_rs2_reg == df_wb_reg))  ? df_wb_data  : regif_rs2_data;

    always_ff @(posedge (clk))
    begin
        if (reset)
        begin
            rs1_data_out   <= 32'b0;
            rs2_data_out   <= 32'b0;
            pc_out         <= 32'b0;
            iw_out         <= 32'b0;
            wb_reg_out     <= 5'b0;
            wb_enable_out  <= 1'b0;
        end 
        else 
        begin
            // Data Handler from pre-saved data for rs1 & rs2 data outputs - priority: ex, mem, wb
            rs1_data_out   <= rs1_df_data;
            rs2_data_out   <= rs2_df_data;
            pc_out         <= pc_in; 
            iw_out         <= iw_in;         
            wb_reg_out     <= (wb_true) ? iw_in[11:7] : 5'b0;
            wb_enable_out  <= wb_true;
        end
    end
endmodule

