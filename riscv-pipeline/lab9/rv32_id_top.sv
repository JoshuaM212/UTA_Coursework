`timescale 1ns / 1ps

module rv32_id_top (
    // system clock and synchronous reset
    input clk,
    input reset,
    // from IF: pc input, iw input, and wired pc to verify pipeline start
    input [31:0] pc_in,
    input [31:0] iw_in,
    input [31:0] pc_verify,
    // register interface: rs1 & rs2 requested registers and their data 
    output [4:0] regif_rs1_reg,
    output [4:0] regif_rs2_reg,
    input [31:0] regif_rs1_data,
    input [31:0] regif_rs2_data,
    // to EX: rs1 & rs2 data, pc, iw, memory store signal, wb register, and wb enable signal
    output reg [31:0] rs1_data_out,
    output reg [31:0] rs2_data_out,
    output reg [31:0] pc_out,
    output reg [31:0] iw_out,
    output reg [4:0] wb_reg_out,
    output reg wb_enable_out,
    output reg store_we_out,
    output reg wb_from_mem_out,    // used to identify if wb is from mem and used to stall
    output reg [4:0] rs1_reg_out,  // used to inform ex if rs1 had a hazard occur
    output reg [4:0] rs2_reg_out,  // used to inform ex if rs2 had a hazard occur
    // data hazard: df from EX
    input df_ex_enable,
    input [4:0] df_ex_reg,
    input [31:0] df_ex_data,
    // data hazard: df from MEM
    input df_mem_enable,
    input [4:0] df_mem_reg,
    input [31:0] df_mem_data,
    // data hazard: df from WB
    input df_wb_enable,
    input [4:0] df_wb_reg,
    input [31:0] df_wb_data,
    // to IF: jump enable signal and jump address
    output jump_enable_out,
    output [31:0] jump_addr_out,

    // Lab 9 Connections
    output stall,                // stall signal to stop pc incrementing
    input df_wb_from_mem_ex,     // register df from ex
    input df_wb_from_mem_mem,    // register df from mem

    // Test wires - temporary
    output [31:0] rs1_df_output,
    output [31:0] rs2_df_output
);
    // Save PC and IW for stall Handlers
    reg [31:0] stored_pc;
    reg [31:0] stored_iw;

    // Stall PC and IW Handlers
    reg stall_tracker; // used to track if a clock passed while stall is active
    wire [31:0] id_pc = (stall_tracker) ? stored_pc : pc_in;
    wire [31:0] id_iw = (stall_tracker) ? stored_iw : iw_in;

    // IW Handler - used to ensure pipeline runs w/o reset values
    wire [31:0] iw_verified = (pc_verify) ? id_iw : 32'b0;

// RS1 and RS2 Register Number Extraction
    assign regif_rs1_reg = ( (id_iw[6:0] == 7'b0110011) || (id_iw[6:0] == 7'b1100111) || (id_iw[6:0] == 7'b0000011) || 
                             (id_iw[6:0] == 7'b0010011) || (id_iw[6:0] == 7'b0100011) || (id_iw[6:0] == 7'b1100011) ) ? id_iw[19:15] : 5'b0; 
    assign regif_rs2_reg = ( (id_iw[6:0] == 7'b0110011) || (id_iw[6:0] == 7'b0100011) || (id_iw[6:0] == 7'b1100011) ) ? id_iw[24:20] : 5'b0;

    // WB Register Destination (w/ Enable) Extraction - Opcodes: All R-Types, JAL, All Loads, All Immeds, LUI, AUIPC, JALR
    wire [4:0] wb_true_reg = ( (id_iw[6:0] == 7'b0110011) || (id_iw[6:0] == 7'b1100111) || (id_iw[6:0] == 7'b0000011) || 
                               (id_iw[6:0] == 7'b0010011) || (id_iw[6:0] == 7'b0001111) || (id_iw[6:0] == 7'b0110111) ||
                               (id_iw[6:0] == 7'b0010111) || (id_iw[6:0] == 7'b1101111) ) ? id_iw[11:7] : 5'b0;                     

    // Data Hazard Handler - RS1 and RS2 Data Selection w/ priority: ex, mem, wb, and default(registers)
    wire [31:0] rs1_df_data = (df_ex_enable  && (regif_rs1_reg == df_ex_reg))  ? df_ex_data  : 
                              (df_mem_enable && (regif_rs1_reg == df_mem_reg)) ? df_mem_data :
                              (df_wb_enable  && (regif_rs1_reg == df_wb_reg))  ? df_wb_data  : regif_rs1_data;
    wire [31:0] rs2_df_data = (df_ex_enable  && (regif_rs2_reg == df_ex_reg))  ? df_ex_data  : 
                              (df_mem_enable && (regif_rs2_reg == df_mem_reg)) ? df_mem_data :
                              (df_wb_enable  && (regif_rs2_reg == df_wb_reg))  ? df_wb_data  : regif_rs2_data;
    
    // Branch Reminder Register (flush next instr w/ NOP)
    reg branch_break;
    localparam [32:0] nop = 32'h00000013;

    // Detect 1 of 3 instructions requiring branching - jal-1, jalr-2, branch-3
    wire [1:0] jp_inst = (id_iw[6:0] == 7'b1101111) ? 2'b01 :
                         (id_iw[6:0] == 7'b1100111) ? 2'b10 :
                         (id_iw[6:0] == 7'b1100011) ? 2'b11 : 2'b00;

    // Parsed Instruction words for jumps/branching
    wire [31:0] jal_addr_result    = id_pc + $signed(2 * $signed({id_iw[31], id_iw[19:12], id_iw[20], id_iw[30:21]}));
    wire [31:0] jalr_addr_result   = (rs1_df_data + $signed({id_iw[31:20]})) & ~32'b1;
    wire [31:0] branch_addr_result = id_pc + $signed(2 * $signed({id_iw[31], id_iw[7], id_iw[30:25], id_iw[11:8]}));

    // jump enable based on JAL, JALR, B-Types (BEQ, BNE, BLT, BGE, BLTU, & BGEU) taken     
    assign jump_addr_out =  (jp_inst == 2'b01) ? jal_addr_result  :
                            (jp_inst == 2'b10) ? jalr_addr_result :
                            ((jp_inst == 2'b11) && ((id_iw[14:12]) == 3'b000) && ($signed(rs1_df_data) == $signed(rs2_df_data))) ? branch_addr_result :
                            ((jp_inst == 2'b11) && ((id_iw[14:12]) == 3'b001) && ($signed(rs1_df_data) != $signed(rs2_df_data))) ? branch_addr_result :
                            ((jp_inst == 2'b11) && ((id_iw[14:12]) == 3'b100) && ($signed(rs1_df_data) <  $signed(rs2_df_data))) ? branch_addr_result :
                            ((jp_inst == 2'b11) && ((id_iw[14:12]) == 3'b101) && ($signed(rs1_df_data) >= $signed(rs2_df_data))) ? branch_addr_result :
                            ((jp_inst == 2'b11) && ((id_iw[14:12]) == 3'b110) && ($unsigned(rs1_df_data) <  $unsigned(rs2_df_data))) ? branch_addr_result :
                            ((jp_inst == 2'b11) && ((id_iw[14:12]) == 3'b111) && ($unsigned(rs1_df_data) >= $unsigned(rs2_df_data))) ? branch_addr_result : 32'hffffffff;
    
    assign jump_enable_out = ((jump_addr_out != 32'hffffffff) && (branch_break == 1'b0));

    //Store and Load Handler - Data to MEM / WB from MEM
    wire store_we    = (id_iw[6:0] == 7'b0100011);
    wire wb_from_mem = (id_iw[6:0] == 7'b0000011);

    // Stall Logic Handlers - if data is not equal to register data, but a store command is active, stall pipeline
    wire rs1_df_data_stall = (((regif_rs1_reg == df_ex_reg) && df_wb_from_mem_ex) || ((regif_rs1_reg == df_mem_reg) && df_wb_from_mem_mem));
    wire rs2_df_data_stall = (((regif_rs2_reg == df_ex_reg) && df_wb_from_mem_ex) || ((regif_rs2_reg == df_mem_reg) && df_wb_from_mem_mem));
    assign stall = (rs1_df_data_stall || rs2_df_data_stall);

    // Temp wires for testing
    assign rs1_df_output = rs1_df_data;
    assign rs2_df_output = rs2_df_data;

    // ID synchronous output
    // - reset: all outputs are zero'd
    // - branch break: swap instruction to NOP, zero out all output data
    // - default: output data based on their handlers and/or valid registers
    always_ff @ (posedge (clk))
    begin
        if (reset)
        begin
            rs1_data_out    <= 32'b0;
            rs2_data_out    <= 32'b0;
            pc_out          <= 32'b0;
            iw_out          <= 32'b0;
            wb_reg_out      <= 5'b0;
            wb_enable_out   <= 1'b0;
            branch_break    <= 1'b0;
            store_we_out    <= 1'b0;
            wb_from_mem_out <= 1'b0;
            rs1_reg_out     <= 5'b0;
            rs2_reg_out     <= 5'b0;
            stall_tracker   <= 2'b0;
            stored_pc       <= 32'b0;
            stored_iw       <= 32'b0;
        end
        else if (stall)
        begin
            iw_out          <= nop;
            pc_out          <= 32'hffffffff;
            branch_break    <= 1'b0;
            rs1_data_out    <= 32'b0;
            rs2_data_out    <= 32'b0;
            wb_reg_out      <= 5'b0;
            wb_enable_out   <= 1'b0;
            store_we_out    <= 1'b0;
            wb_from_mem_out <= 1'b0;
            rs1_reg_out     <= 5'b0;
            rs2_reg_out     <= 5'b0;
            stall_tracker   <= 1'b1;
            stored_pc       <= (!stored_pc) ? id_pc : stored_pc;
            stored_iw       <= (!stored_iw) ? id_iw : stored_iw;
        end
        else if (branch_break)
        begin
            iw_out          <= nop;
            pc_out          <= 32'hffffffff;
            branch_break    <= 1'b0;
            rs1_data_out    <= 32'b0;
            rs2_data_out    <= 32'b0;
            wb_reg_out      <= 5'b0;
            wb_enable_out   <= 1'b0;
            store_we_out    <= 1'b0;
            wb_from_mem_out <= 1'b0;
            rs1_reg_out     <= 5'b0;
            rs2_reg_out     <= 5'b0;
            stall_tracker   <= 2'b0;
            stored_pc       <= 32'b0;
            stored_iw       <= 32'b0;
        end
        else
        begin
            iw_out          <= iw_verified;
            pc_out          <= id_pc;
            branch_break    <= (jump_enable_out != 1'b0);
            rs1_data_out    <= rs1_df_data;
            rs2_data_out    <= rs2_df_data;
            wb_reg_out      <= wb_true_reg;
            wb_enable_out   <= (wb_true_reg != 5'b0);
            store_we_out    <= store_we;
            wb_from_mem_out <= wb_from_mem;
            rs1_reg_out     <= regif_rs1_reg;
            rs2_reg_out     <= regif_rs2_reg;
            stall_tracker   <= 2'b0;
            stored_pc       <= 32'b0;
            stored_iw       <= 32'b0;
        end
    end
endmodule