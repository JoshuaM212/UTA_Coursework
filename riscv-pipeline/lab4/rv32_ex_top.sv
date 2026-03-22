`timescale 1ns / 1ps

module rv32_ex_top (
    input clk,                  // system clock       
    input reset,                // synchronous reset
    input [31:0] pc_in,         // from id (currently top)
    input [31:0] iw_in,         // from id (currently top)
    input [31:0] rs1_data_in,   // from id (currently top)
    input [31:0] rs2_data_in,   // from id (currently top)
    output reg [31:0] alu_out   // to mem (currently top)
    );

    wire [31:0] alu_mod_output; // ALU Middleman

    // Main Functions

    // Instantiated Modules - Format: .<module variable>(<current module variable>)
    //  - Current Instntiated List:
    //      ~ alu.sv : (module for ALU within Execution Stage of pipeline)


    // ALU Output Handler
    always_ff @ (clk)
    begin
        if (reset)
            alu_out <= 32'b0;
        else
            alu_out <= alu_mod_output;
    end


    // Instantiate alu.sv module 
    alu al (
    .pc_in(pc_in),              // pc variable received
    .iw_in(iw_in),              // instruction word received
    .rs1_data_in(rs1_data_in),  // register 1 received
    .rs2_data_in(rs2_data_in),  // register 2 received
    .alu_out(alu_mod_output)           // ALU output from module
    );

endmodule
