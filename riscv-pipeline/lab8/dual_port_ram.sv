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
    parameter integer RAM_WIDTH = 12;
    reg [31:0] RAM [2**RAM_WIDTH-1:0];

    // Initialize RAM memory w/ memory file
    initial 
        $readmemh("riscv.mem", RAM);

    // Instruction Memory: Read Only 
    always_ff @ (posedge(clk))
    begin
        i_rdata <= RAM[i_addr];
    end

    // Data Memory: Write/Read
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