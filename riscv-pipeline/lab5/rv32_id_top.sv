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
    output reg [31:0] rs1_data_out,  // MISSING FROM DOC
    output reg [31:0] rs2_data_out,  // MISSING FROM DOC
    output reg [31:0] pc_out,
    output reg [31:0] iw_out,
    output reg [4:0] wb_reg_out,
    output reg wb_enable_out
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
            rs1_data_out   <= regif_rs1_data; 
            rs2_data_out   <= regif_rs2_data;
            pc_out         <= pc_in;        
            iw_out         <= iw_in;         
            wb_reg_out     <= (wb_true) ? iw_in[11:7] : 5'b0;
            wb_enable_out  <= wb_true;
        end
    end
endmodule