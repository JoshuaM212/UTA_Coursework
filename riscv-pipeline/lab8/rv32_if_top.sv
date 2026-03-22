`timescale 1ns / 1ps

module rv32_if_top (
    input clk,                  // system clock
    input reset,                // synchronous reset
    output [31:2] memif_addr,   // to MEMORY: address to fetch instruction
    input [31:0] memif_data,    // from MEMORY: instruuction fectched from memory
    output reg [31:0] pc_out,   // to ID: program counter
    output [31:0] pc_verify,    // to ID: wired pc output to signal start of pipeline
    output [31:0] iw_out,       // to ID: wired instruction output from input mem data (registered in dpram)
    input jump_enable_in,       // from ID: jump enable signal (valid jump taken)
    input [31:0] jump_addr_in,  // from ID: jump address to taken when valid jump taken
    input ebreak                // Temporary EBREAK stop Condition
);

    // Register program counter output (and mem if address) w/ verify wire to start pipeline off reset 
    reg [31:0] pc;
    assign memif_addr = pc[31:2];
    assign pc_out = (pc == 32'b0) ? 32'b0 : pc - 4;
    assign pc_verify = pc; 

    // Program counter reset value
    parameter pc_reset = 32'b0;

    // Mem Instr Fetch data directly drives Instr Word Output
    assign iw_out = memif_data;

    // IF Synchronous Output
    // if reset: clears pc, if ebreak: Stops incrementing pc - (halting pipeline)
    // if jump_enable_in: moves pc to jump address, else:  pc incremented by 4
    always_ff @ (posedge (clk))
    begin
        if (reset)
            pc <= pc_reset;
        else if (ebreak)
            pc <= pc;
        else if (jump_enable_in)
            pc <= jump_addr_in;
        else
            pc <= pc + 4;
    end
endmodule