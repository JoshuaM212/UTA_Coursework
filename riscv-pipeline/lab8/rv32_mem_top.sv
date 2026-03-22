`timescale 1ns / 1ps

module rv32_mem_top (
    // system clock and synchronous reset
    input clk,
    input reset,
    // from ex
    input [31:0] pc_in,
    input [31:0] iw_in,
    input [31:0] alu_in,
    input [4:0] wb_reg_in,
    input wb_enable_in,
    input store_we_in,                  // new wire for lab 8
    input [31:0] rs2_data_in,           // new wire for lab 8
    // to wb
    output reg [31:0] pc_out,
    output reg [31:0] iw_out,
    output reg [31:0] alu_out,
    output reg [4:0] wb_reg_out,
    output reg wb_enable_out,
    output [31:0] mem_rdata_out,        // new wire for lab 8 - registered in dual port ram
    output [31:0] io_rdata_out,         // new wire for lab 8 - registered in io module
    output reg [2:0] wb_we_select_out,  // new wire for lab 8
    output reg [1:0] address_mod_out,   // new wire for lab 8
    // memory interface
    output [31:2] memif_addr,           // from alu in
    input [31:0] memif_rdata,           // to wb
    output memif_we,                    // based on addr[31]
    output [3:0] memif_be,              // based on funct3 of store word commands
    output [31:0] memif_wdata,          // from rs2 data
    // io interface
    output [31:2] io_addr,              // from alu in
    input [31:0] io_rdata,              // to wb
    output io_we,                       // based on addr[31]
    output [3:0] io_be,                 // based on funct3 of store word commands
    output [31:0] io_wdata,             // from rs2 data
    // data hazard: df to id
    output df_mem_enable,
    output [4:0] df_mem_reg,
    output [31:0] df_mem_data
);

    // Address Module Wires: Address mod from iw, byte select from mod
    wire [1:0] address_mod = alu_in[1:0];
    wire [1:0] data_width = iw_in[13:12];
    wire [3:0] b_en_select;
    wire [31:0] data_shifted;

    // Data Forward Handler
    assign df_mem_enable = wb_enable_in;
    assign df_mem_reg    = wb_reg_in;
    assign df_mem_data   = alu_in;

    // Memory Interface Handlers
    assign memif_addr    = alu_in;       // READ ONLY - Grabs read data for wb to store
    assign memif_we      = ((alu_in[31] == 1'b0) && (store_we_in));
    assign memif_be      = b_en_select;
    assign memif_wdata   = data_shifted; // rs2_data_in;
    assign mem_rdata_out = memif_rdata;  // READ ONLY - Output grabbed data to wb 

    // IO Interface Handlers
    assign io_addr      = alu_in;       // READ ONLY - Grabs read data for wb to store 
    assign io_we        = ((alu_in[31]) && (store_we_in));
    assign io_be        = b_en_select;
    assign io_wdata     = data_shifted; // rs2_data_in;
    assign io_rdata_out = io_rdata;     // READ ONLY - Output grabbed data to wb

    // Signal for WB indicating where WB data comes from
    wire [2:0] wb_we_select = ( alu_in[31] && (iw_in[6:0] == 7'b0000011)) ? 3'b100 : 
                              (!alu_in[31] && (iw_in[6:0] == 7'b0000011)) ? 3'b010 : (wb_enable_in) ? 3'b001 :  3'b0;

    // pc, iw, alu, wb_reg, & wb_enable handler
    always_ff @ (posedge (clk))
    begin
        if (reset)
        begin
            pc_out           <= 32'b0;
            iw_out           <= 32'b0;
            alu_out          <= 32'b0;
            wb_reg_out       <= 5'b0;
            wb_enable_out    <= 1'b0;
            wb_we_select_out <= 3'b0;
            address_mod_out  <= 2'b0;
        end
        else
        begin
            pc_out           <= pc_in;
            iw_out           <= iw_in;
            alu_out          <= alu_in;
            wb_reg_out       <= wb_reg_in;
            wb_enable_out    <= wb_enable_in;
            wb_we_select_out <= wb_we_select;
            address_mod_out  <= address_mod;
        end
    end

    // Instantiate address_mod.sv
   address_mod a_m (
    .address_mod(address_mod),  // Input: Data Address 
    .data_width(data_width),    // Input: Data Width
    .d_be(b_en_select)          // Output: Bytes Enabled
    );

    // Instantiate data_shifter.sv
    data_shifter d_s1 (
    .pc_data(rs2_data_in),      // Input: Data to be shifted
    .shift(b_en_select),        // Input: Desired bytes to write (shift to accommodate)
    .pc_shift(data_shifted)     // Output: Shifted data to be written
    );
endmodule
