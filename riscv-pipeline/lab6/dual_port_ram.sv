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
    parameter integer RAM_WIDTH = 11;
    reg [31:0] RAM [2**RAM_WIDTH-1:0];

    // INITIALIZED MEMORY VALUES FOR TESTING LAB 6
    //initial 
    //    $readmemh("lab6.hex", RAM);
 /* 
    initial
    begin
        $readmemh("lab6.hex", RAM);
        for (int i = 0; i < 10; i = i + 1)
        begin
            $display("RAM[%0d] = %h", i, RAM[i]);
        end
    end
*/

    initial
    begin
        RAM[0]  = 32'h00000000;  // 0  EMPTY
        RAM[1]  = 32'h00c00313;  // 4  li t1, 12
        RAM[2]  = 32'h00d00313;  // 8  li t1, 13
        RAM[3]  = 32'h00e00313;  // C  li t1, 14
        RAM[4]  = 32'h00f00313;  // 10 li t1, 15
        RAM[5]  = 32'h01000313;  // 14 li t1, 16
        RAM[6]  = 32'h00030393;  // 18 mv t2, t1
        RAM[7]  = 32'h00030e13;  // 1C mv t3, t1
        RAM[8]  = 32'h00030e93;  // 20 mv t4, t1
        RAM[9]  = 32'h00030f13;  // 24 mv t5, t1
        RAM[10] = 32'h01cf0eb3;  // 28 add t4, t5
        RAM[11] = 32'h006e83b3;  // 2C add t2, t4
        RAM[12] = 32'h407e8e33;  // 30 sub t3, t4 - should be negative 
        RAM[13] = 32'h000e0313;  // 34
        RAM[14] = 32'h00100073;  // 38
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