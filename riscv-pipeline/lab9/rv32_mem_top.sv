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
    input wb_from_mem_in,               // new wire for lab 9
    // to wb
    output reg [31:0] pc_out,
    output reg [31:0] iw_out,
    output reg [31:0] alu_out,
    output reg [4:0] wb_reg_out,
    output reg wb_enable_out,
    output [31:0] mem_rdata_out,        // Grabbed Read Data (MEM) - Send grabbed data to wb 
    output [31:0] io_rdata_out,         // Grabbed Read Data (IO)  - Send grabbed data to wb 
    output reg [2:0] wb_we_select_out,  // new wire for lab 8
    output reg [1:0] address_mod_out,   // new wire for lab 8
    output reg wb_from_mem_out,         // new wire for lab 9
    // memory interface
    output [31:2] memif_addr,           // Data Address - stores data w/ we, else address to read data
    input [31:0] memif_rdata,           // Data Read - grab read data based on address
    output memif_we,                    // Store (Write) Enable - bottom half of address space
    output [3:0] memif_be,              // Bytes Enabled - based on funct3 (amount of data to store)
    output [31:0] memif_wdata,          // Store Data - Shifted data to store into memory
    // io interface
    output [31:2] io_addr,              // Data Address - stores data w/ we, else address to read data
    input [31:0] io_rdata,              // Data Read - grab read data based on address
    output io_we,                       // Store (Write) Enable - bottom half of address space
    output [3:0] io_be,                 // Bytes Enabled - based on funct3 (amount of data to store)
    output [31:0] io_wdata,             // Store Data - Shifted data to store into memory
    // data hazard: df to id
    output df_mem_enable,               // DF Enable - informs ID stage of in-progress writeback
    output [4:0] df_mem_reg,            // DF Register - informs ID stage of the register being written to
    output [31:0] df_mem_data,          // DF Data - informs ID stage of the data to be written
    output df_wb_from_mem_mem           // DF WB from MEM - informs ID stage writeback data is from memory
);

    // Address Module Wires: Address mod from iw, byte select from mod
    wire [1:0] address_mod = alu_in[1:0];   // Address Mod - used to shift data based on address offset
    wire [1:0] data_width = iw_in[13:12];   // Data Width - used to determine type of store (byte, half, word)
    wire [3:0] b_en_select;                 // Bytes Enabled - based on data width and address offset
    wire [31:0] data_shifted;               // Shifted Data - shifted data based on requirements

    // Data Forward Handler
    assign df_mem_enable = wb_enable_in;            
    assign df_mem_reg    = wb_reg_in;               
    assign df_mem_data   = alu_in;                  
    assign df_wb_from_mem_mem = wb_from_mem_in;     

    // Memory Interface Handlers
    assign memif_addr    = alu_in[31:2];
    assign memif_we      = ((alu_in[31] == 1'b0) && (store_we_in)); 
    assign memif_be      = b_en_select;                      
    assign memif_wdata   = data_shifted;                     
    assign mem_rdata_out = memif_rdata;                      

    // IO Interface Handlers
    assign io_addr      = alu_in[31:2];                      
    assign io_we        = ((alu_in[31]) && (store_we_in));   
    assign io_be        = b_en_select;                       
    assign io_wdata     = data_shifted;                      
    assign io_rdata_out = io_rdata;                          

    // Signal for WB indicating where WB data comes from
    wire [2:0] wb_we_select = ( alu_in[31] && wb_from_mem_in) ? 3'b100 : // Load from IO
                              (!alu_in[31] && wb_from_mem_in) ? 3'b010 : // Load from Memory
                              (wb_enable_in)                  ? 3'b001 : // ALU Data 
                              3'b0;                                      // Zero Default

    // FF Data to send to WB stage  
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
            wb_from_mem_out  <= 1'b0;
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
            wb_from_mem_out  <= wb_from_mem_in;
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
