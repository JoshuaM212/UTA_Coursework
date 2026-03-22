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

    // Write enable check
    wire wb_true = (wb_enable && (wb_reg != 0));

    // At posedge(clk)
    //   Reset - zero's all registers 
    //   WB Enable - stores data recieved into selected Register
    always_ff@(posedge(clk))
    begin
        if (reset)
        begin
            for (int i = 0; i < 32; i = i + 1)
                REGISTER[i] <= 32'b0;
        end
        else
        begin
            if (wb_true)
                REGISTER[wb_reg] <= wb_data;
        end
    end
endmodule