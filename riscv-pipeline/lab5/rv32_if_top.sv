`timescale 1ns / 1ps

module rv32_if_top (
    // system clock and synchronous reset
    input clk,
    input reset,
    // memory interface
    output [31:2] memif_addr,
    input [31:0] memif_data,
    // to id
    output reg [31:0] pc_out,
    output [31:0] iw_out,      // note this was registered in the memory already

    // Temporary EBREAK stop Condition
    input ebreak
);

    // Register output for program counter (pc) (and mem if address)
    reg [31:0] pc;
    assign memif_addr = pc[31:2];
    assign pc_out = pc;

    // Program counter reset value
    parameter pc_reset = 32'b0;

    // Mem Instr Fetch data directly drives Instr Word Output
     assign iw_out = memif_data;

    // Synchronous Output for pc w/ reset & increment by 4
    always_ff @ (posedge (clk))
    begin
        if (reset)
            pc <= pc_reset;
        else if (ebreak)
            pc <= pc;
        else
            pc <= pc + 32'd4;
    end
endmodule