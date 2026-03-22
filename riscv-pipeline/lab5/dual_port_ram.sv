`timescale 1ns / 1ps

module dual_port_ram
(
    input clk,                  // System clock input
    input [31:2] i_addr,        // Instruction Port: instr address (RO)
    output reg [31:0] i_rdata,  // Instruction Port: instr read data (RO)
    input [31:2] d_addr,        // Data port: data address (RW)
    output reg [31:0] d_rdata,  // Data port: data read data (RW)
    input d_we,                 // Data port: data write enable (RW)
    input [3:0] d_be,           // Data port: byte enable (RW)
    input [31:0] d_wdata        // Data port: data write data (RW)
);
    // Dual Port Memory - 32-bit width of 32k memory/registers
    parameter integer RAM_WIDTH = 13;
    reg [31:0] RAM [2**RAM_WIDTH-1:0];

    // INITIALIZED MEMORY VALUES FOR TESTING ILA
    initial 
    begin
        RAM[0]  = 32'b0;  // NOP
        RAM[1]  = 32'b0;  // NOP
        RAM[2]  = 32'b0;  // NOP
        RAM[3]  = 32'b00000000001100110000000010110011; // ADD 
        RAM[4]  = 32'b0;  // NOP
        RAM[5]  = 32'b0;  // NOP
        RAM[6]  = 32'b0;  // NOP
        RAM[7]  = 32'b01000000000100000001010000110011; // SUB
        RAM[8]  = 32'b0;  // NOP
        RAM[9]  = 32'b0;  // NOP
        RAM[10] = 32'b0;  // NOP
        RAM[11] = 32'h00100073;  // EBREAK
        RAM[12] = 32'b0;  // NOP
        RAM[13] = 32'b0;  // NOP
        RAM[14] = 32'b0;  // NOP
        RAM[15] = 32'h314afd30;  // Random  
        RAM[16] = 32'b0;  // NOP
        RAM[17] = 32'b0;  // NOP
        RAM[18] = 32'b0;  // NOP
        RAM[19] = 32'h0011da70; // Random
    end

    // Instruction: Read Only 
    always_ff @ (posedge(clk))
        i_rdata <= RAM[i_addr];

    // Data: Write/Read
    always_ff @ (posedge(clk))
    begin
        if (d_we)
        begin
            if (d_be[0])
                RAM[d_addr][7:0]   <= d_wdata[7:0];
            if (d_be[1])
                RAM[d_addr][15:8]  <= d_wdata[15:8];
            if (d_be[2])
                RAM[d_addr][23:16] <= d_wdata[23:16];
            if (d_be[3])
                RAM[d_addr][31:24] <= d_wdata[31:24];
        end
        else
            d_rdata <= RAM[d_addr[31:2]][31:0];
    end
endmodule