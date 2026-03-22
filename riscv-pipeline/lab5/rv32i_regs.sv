`timescale 1ns / 1ps

module rv32i_regs (
    input  clk,
    input  reset,
    input  [4:0] rs1_reg,
    input  [4:0] rs2_reg,
    input  wb_enable,
    input  [4:0] wb_reg,
    input  [31:0] wb_data,
    output [31:0] rs1_data,
    output [31:0] rs2_data
);

    // List of 32-bit width registers
    reg [31:0] REGISTER [0:31];
    
    // rs data reg handlers - (rsX-reg -> rsX_data)
    assign rs1_data = {REGISTER[rs1_reg]};
    assign rs2_data = {REGISTER[rs2_reg]};

    // At posedge(clk) 
    //   Reset - zero's all registers
    //   WB Enable - stores data recieved into selected Register
    always_ff@(posedge(clk))
    begin
        if (reset)
        begin
            //for (int i = 0; i < 32; i = i + 1)
            //    REGISTER[i] <= 32'b0;
            REGISTER[0]  = 32'h00000000; 
            REGISTER[1]  = 32'h00000001;
            REGISTER[2]  = 32'h00000002;
            REGISTER[3]  = 32'h00000003;
            REGISTER[4]  = 32'h00000004;
            REGISTER[5]  = 32'h00000005;
            REGISTER[6]  = 32'h00000006;
            REGISTER[7]  = 32'h00000007;
            REGISTER[8]  = 32'h00000008;
            REGISTER[9]  = 32'h00000009;
            REGISTER[10] = 32'h0000000A;
            REGISTER[11] = 32'h0000000B;
            REGISTER[12] = 32'h0000000C;
            REGISTER[13] = 32'h0000000D;
            REGISTER[14] = 32'h0000000E;
            REGISTER[15] = 32'h0000000F;
            REGISTER[16] = 32'h00000010;
            REGISTER[17] = 32'h00000011;
            REGISTER[18] = 32'h00000012;
            REGISTER[19] = 32'h00000013;
            REGISTER[20] = 32'h00000014;
            REGISTER[21] = 32'h00000015;
            REGISTER[22] = 32'h00000016;
            REGISTER[23] = 32'h00000017;
            REGISTER[24] = 32'h00000018;
            REGISTER[25] = 32'h00000019;
            REGISTER[26] = 32'h0000001A;
            REGISTER[27] = 32'h0000001B;
            REGISTER[28] = 32'h0000001C;
            REGISTER[29] = 32'h0000001D;
            REGISTER[30] = 32'h0000001E;
            REGISTER[31] = 32'h0000001F;
        end
        else
        begin
            if (wb_enable && (wb_reg != 0))
                REGISTER[wb_reg] <= wb_data;
        end
    end
endmodule