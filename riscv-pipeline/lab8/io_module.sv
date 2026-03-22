`timescale 1ns / 1ps

module io_module
(
    input clk,
    input [31:2] io_addr,
    output reg [31:0] io_rdata,
    input io_we,                
    input [3:0] io_be,
    input [31:0] io_wdata,         
    input [7:0] io_sw,
    output reg [7:0] io_led
);

    // IO Memory Interface - Write to LEDs, and Read from Switches
    always_ff @ (posedge(clk))
    begin
        if (io_we && io_be[0])
            io_led <= io_wdata[7:0];
        else if (!io_we)
            io_rdata <= io_sw;
    end 
endmodule