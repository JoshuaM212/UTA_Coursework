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

/*

    // INITIALIZED MEMORY VALUES FOR TESTING ILA
    initial 
    begin
        RAM[0]  = 32'h12345678; 
        RAM[1]  = 32'h12000680; 
        RAM[2]  = 32'h9AB00110;
        RAM[3]  = 32'hDEADBEEF;
        RAM[4]  = 32'h00FF00FF;
        RAM[5]  = 32'hAABBCCDD; 
        RAM[6]  = 32'h9ABCDEF0;
        RAM[7]  = 32'hD212323F;
        RAM[8]  = 32'h000000F0;
        RAM[9]  = 32'hA1B1C1D1;
        RAM[10] = 32'h11148628; 
        RAM[11] = 32'h11108620; 
        RAM[12] = 32'h91108120;
        RAM[13] = 32'hD11D8E2F;
        RAM[14] = 32'h011F802F;
        RAM[15] = 32'hA11B8C2D; 
        RAM[16] = 32'h911C8E20;
        RAM[17] = 32'hD112822F;
        RAM[18] = 32'h01108020;
        RAM[19] = 32'hA1118121;
        RAM[20] = 32'h1aaa8628; 
        RAM[21] = 32'h11bb8620; 
        RAM[22] = 32'h9110cc20;
        RAM[23] = 32'hD11D8ddF;
        RAM[24] = 32'h011F80ee;
        RAM[25] = 32'hA1aaaa2D; 
        RAM[26] = 32'h91acccc0;
        RAM[27] = 32'hD1128deF;
        RAM[28] = 32'h0110ea13;
        RAM[29] = 32'h3235e121;
        RAM[30] = 32'h166a8628; 
        RAM[31] = 32'h11b68620; 
        RAM[32] = 32'h91107c20;
        RAM[33] = 32'h113D8ddF;
        RAM[34] = 32'h011Fea4e;
        RAM[35] = 32'hA1a3523D; 
        RAM[36] = 32'h91ac2450;
        RAM[37] = 32'hD1341467;
        RAM[38] = 32'h01144566;
        RAM[39] = 32'h32544533;
        RAM[40] = 32'h1aac8a28; 
        RAM[41] = 32'h11cb8620; 
        RAM[42] = 32'h911ccc20;
        RAM[43] = 32'hD1cc8ddF;
        RAM[44] = 32'h011F8cce;
        RAM[45] = 32'hA1aaaaee; 
        RAM[46] = 32'h9134c9c0;
        RAM[47] = 32'he1128d3F;
        RAM[48] = 32'h01103a13;
        RAM[49] = 32'h32353921;
    end
*/