`timescale 1ns / 1ps

module rv32_id_top (
    // system clock and synchronous reset
    input clk,
    input reset,
    // from if
    input [31:0] pc_in,
    input [31:0] pc_verify,  // testing wire for pc verification
    input [31:0] iw_in,
    // register interface
    output [4:0] regif_rs1_reg,
    output [4:0] regif_rs2_reg,
    input [31:0] regif_rs1_data,
    input [31:0] regif_rs2_data,
    // to ex
    output reg [31:0] rs1_data_out,
    output reg [31:0] rs2_data_out,
    output reg [31:0] pc_out,
    output reg [31:0] iw_out,
    output reg [4:0] wb_reg_out,
    output reg wb_enable_out,

    // data hazard: df from ex
    input df_ex_enable,
    input [4:0] df_ex_reg,
    input [31:0] df_ex_data,
    // data hazard: df from mem
    input df_mem_enable,
    input [4:0] df_mem_reg,
    input [31:0] df_mem_data,
    // data hazard: df from wb
    input df_wb_enable,
    input [4:0] df_wb_reg,
    input [31:0] df_wb_data,
    
    // to if 
    output jump_enable_out,
    output [31:0] jump_addr_out,

    // Test wires
    output [31:0] rs1_df_output,
    output [31:0] rs2_df_output,
    output [1:0] jp_inst_output,
    output [11:0] b_branch_output,
    output [2:0] branch_funct3_output
);

    wire [31:0] iw_verified = (pc_verify) ? iw_in : 32'b0;

    // RS1 and RS2 Register Number Extraction
    assign regif_rs1_reg = ( (iw_in[6:0] == 7'b0110011) || (iw_in[6:0] == 7'b1100111) || (iw_in[6:0] == 7'b0000011) || 
                             (iw_in[6:0] == 7'b0010011) || (iw_in[6:0] == 7'b0100011) || (iw_in[6:0] == 7'b1100011) ) ? iw_in[19:15] : 5'b0; 
    assign regif_rs2_reg = ( (iw_in[6:0] == 7'b0110011) || (iw_in[6:0] == 7'b0100011) || (iw_in[6:0] == 7'b1100011) ) ? iw_in[24:20] : 5'b0;

    // WB Register Destination (w/ Enable) Extraction
    wire [4:0] wb_true_reg = ( (iw_in[6:0] == 7'b0110011) || (iw_in[6:0] == 7'b1100111) || (iw_in[6:0] == 7'b0000011) || 
                               (iw_in[6:0] == 7'b0010011) || (iw_in[6:0] == 7'b0001111) || (iw_in[6:0] == 7'b0110111) ||
                               (iw_in[6:0] == 7'b0010111) || (iw_in[6:0] == 7'b1101111) ) ? iw_in[11:7] : 5'b0;                     

    // Data Hazard Handler
    wire [31:0] rs1_df_data = (df_ex_enable  && (regif_rs1_reg == df_ex_reg))  ? df_ex_data  : 
                              (df_mem_enable && (regif_rs1_reg == df_mem_reg)) ? df_mem_data :
                              (df_wb_enable  && (regif_rs1_reg == df_wb_reg))  ? df_wb_data  : regif_rs1_data;
    wire [31:0] rs2_df_data = (df_ex_enable  && (regif_rs2_reg == df_ex_reg))  ? df_ex_data  : 
                              (df_mem_enable && (regif_rs2_reg == df_mem_reg)) ? df_mem_data :
                              (df_wb_enable  && (regif_rs2_reg == df_wb_reg))  ? df_wb_data  : regif_rs2_data;

    assign rs1_df_output = rs1_df_data;
    assign rs2_df_output = rs2_df_data;

    // Branching Handlers
    
    // Branch reminder(flush next instr w/ NOP)
    reg branch_break;
    localparam [32:0] nop = 32'h00000013;

    // Detect 1 of 3 instructions requiring branching - jal-1, jalr-2, branch-3
    wire [1:0] jp_inst = (iw_in[6:0] == 7'b1101111) ? 2'b01 :
                         (iw_in[6:0] == 7'b1100111) ? 2'b10 :
                         (iw_in[6:0] == 7'b1100011) ? 2'b11 : 2'b00;

    // Parsed Instruction words for jumps/branching
    wire [31:0] jal_addr_result    = pc_in + $signed(2 * $signed({iw_in[31], iw_in[19:12], iw_in[20], iw_in[30:21]}));
    wire [31:0] jalr_addr_result   = (rs1_df_data + $signed({iw_in[31:20]})) & ~32'b1;
    wire [31:0] branch_addr_result = pc_in + $signed(2 * $signed({iw_in[31], iw_in[7], iw_in[30:25], iw_in[11:8]}));

    // jump enable based on JAL, JALR, B-Types (BEQ, BNE, BLT, BGE, BLTU, & BGEU) taken     
    assign jump_addr_out =  (jp_inst == 2'b01) ? jal_addr_result  :
                            (jp_inst == 2'b10) ? jalr_addr_result :
                           ((jp_inst == 2'b11) && ((iw_in[14:12]) == 3'b000) && ($signed(rs1_df_data) == $signed(rs2_df_data))) ? branch_addr_result :
                           ((jp_inst == 2'b11) && ((iw_in[14:12]) == 3'b001) && ($signed(rs1_df_data) != $signed(rs2_df_data))) ? branch_addr_result :
                           ((jp_inst == 2'b11) && ((iw_in[14:12]) == 3'b100) && ($signed(rs1_df_data) <  $signed(rs2_df_data))) ? branch_addr_result :
                           ((jp_inst == 2'b11) && ((iw_in[14:12]) == 3'b101) && ($signed(rs1_df_data) >= $signed(rs2_df_data))) ? branch_addr_result :
                           ((jp_inst == 2'b11) && ((iw_in[14:12]) == 3'b110) && ($unsigned(rs1_df_data) <  $unsigned(rs2_df_data))) ? branch_addr_result :
                           ((jp_inst == 2'b11) && ((iw_in[14:12]) == 3'b111) && ($unsigned(rs1_df_data) >= $unsigned(rs2_df_data))) ? branch_addr_result : pc_in;
    
    assign jump_enable_out = ((jump_addr_out != pc_in) && (branch_break == 1'b0));

    // Temp wires for testing
    assign jp_inst_output = jp_inst;
    assign b_branch_output = branch_addr_result;
    assign branch_funct3_output = iw_in[14:12];

    // Data Handler from pre-saved data for rs1 & rs2 data outputs - priority: ex, mem, wb
    // IW break handler - outputs NOP next clock (throws out grabbed values)
    always_ff @ (posedge (clk))
    begin
        if (reset)
        begin
            rs1_data_out   <= 32'b0;
            rs2_data_out   <= 32'b0;
            pc_out         <= 32'b0;
            iw_out         <= 32'b0;
            wb_reg_out     <= 5'b0;
            wb_enable_out  <= 1'b0;
            branch_break   <= 1'b0;
        end 
        else if (branch_break)
        begin
            iw_out         <= nop;
            pc_out         <= (pc_in == 32'b0) ? 32'b0 : pc_in - 4; // pc_in;
            branch_break   <= 1'b0;   
            rs1_data_out   <= 32'b0;
            rs2_data_out   <= 32'b0;
            wb_reg_out     <= 5'b0;
            wb_enable_out  <= 1'b0;
        end
        else
        begin
            iw_out         <= iw_verified; //iw_in;
            pc_out         <= pc_in; //pc_in; 
            rs1_data_out   <= rs1_df_data;
            rs2_data_out   <= rs2_df_data;
            wb_reg_out     <= wb_true_reg;
            wb_enable_out  <= (wb_true_reg     != 5'b0) ? 1'b1 : 1'b0;
            branch_break   <= (jump_enable_out != 1'b0) ? 1'b1 : 1'b0;
        end
    end
endmodule


/*
`timescale 1ns / 1ps

module rv32_id_top (
    // system clock and synchronous reset
    input clk,
    input reset,
    // from if
    input [31:0] pc_in,
    input [31:0] iw_in,
    // register interface
    output [4:0] regif_rs1_reg,
    output [4:0] regif_rs2_reg,
    input [31:0] regif_rs1_data,
    input [31:0] regif_rs2_data,
    // to ex
    output reg [31:0] rs1_data_out,
    output reg [31:0] rs2_data_out,
    output reg [31:0] pc_out,
    output reg [31:0] iw_out,
    output reg [4:0] wb_reg_out,
    output reg wb_enable_out,

    // data hazard: df from ex
    input df_ex_enable,
    input [4:0] df_ex_reg,
    input [31:0] df_ex_data,
    // data hazard: df from mem
    input df_mem_enable,
    input [4:0] df_mem_reg,
    input [31:0] df_mem_data,
    // data hazard: df from wb
    input df_wb_enable,
    input [4:0] df_wb_reg,
    input [31:0] df_wb_data,
    
    // to if 
    output jump_enable_out,
    output [31:0] jump_addr_out,

    // Test wires
    output [31:0] rs1_df_output,
    output [31:0] rs2_df_output,
    output [1:0] jp_inst_output,
    output [11:0] b_branch_output,
    output [2:0] branch_funct3_output
);

    // RS1 and RS2 Register Number Extraction
    wire rs1_reg_true = ( (iw_in[6:0] == 7'b0110011) || (iw_in[6:0] == 7'b1100111) || (iw_in[6:0] == 7'b0000011) || 
                          (iw_in[6:0] == 7'b0010011) || (iw_in[6:0] == 7'b0100011) || (iw_in[6:0] == 7'b1100011) );
    wire rs2_reg_true = ( (iw_in[6:0] == 7'b0110011) || (iw_in[6:0] == 7'b0100011) || (iw_in[6:0] == 7'b1100011) );

    // WB Register Destination (w/ Enable) Extraction
    wire wb_true = ( (iw_in[6:0] == 7'b0110011) || (iw_in[6:0] == 7'b1100111) || (iw_in[6:0] == 7'b0000011) || 
                     (iw_in[6:0] == 7'b0010011) || (iw_in[6:0] == 7'b0001111) || (iw_in[6:0] == 7'b0110111) ||
                     (iw_in[6:0] == 7'b0010111) || (iw_in[6:0] == 7'b1101111) );
                     
    wire [4:0] wb_true_reg = (wb_true) ? iw_in[11:7] : 5'b0;

    assign regif_rs1_reg = (rs1_reg_true) ? iw_in[19:15] : 5'b0; 
    assign regif_rs2_reg = (rs2_reg_true) ? iw_in[24:20] : 5'b0;

    // Data Hazard Handler
    wire [31:0] rs1_df_data = (df_ex_enable  && (regif_rs1_reg == df_ex_reg))  ? df_ex_data  : 
                              (df_mem_enable && (regif_rs1_reg == df_mem_reg)) ? df_mem_data :
                              (df_wb_enable  && (regif_rs1_reg == df_wb_reg))  ? df_wb_data  : regif_rs1_data;
    wire [31:0] rs2_df_data = (df_ex_enable  && (regif_rs2_reg == df_ex_reg))  ? df_ex_data  : 
                              (df_mem_enable && (regif_rs2_reg == df_mem_reg)) ? df_mem_data :
                              (df_wb_enable  && (regif_rs2_reg == df_wb_reg))  ? df_wb_data  : regif_rs2_data;

    assign rs1_df_output = rs1_df_data;
    assign rs2_df_output = rs2_df_data;

    // Branching Handlers
    
    // ID Branch to NOP Register
    reg branch_break;
    localparam [32:0] nop = 32'h00000013;

    // Detect 1 of 3 instructions requiring branching
    wire [1:0] jal_branch  = (iw_in[6:0] == 7'b1101111) ? 2'b01 : 2'b00;
    wire [1:0] jalr_branch = (iw_in[6:0] == 7'b1100111) ? 2'b10 : 2'b00;
    wire [1:0] b_branch    = (iw_in[6:0] == 7'b1100011) ? 2'b11 : 2'b00;
    wire [1:0] jp_inst     = jal_branch + jalr_branch + b_branch;

    // Detect 1 of 6 B-Types funt3
    wire [2:0] branch_funct3 = iw_in[14:12];

    // Parsed Instruction words for jumps/branching
    wire [19:0] JAL_ins_w  = {iw_in[31], iw_in[19:12], iw_in[20], iw_in[30:21]};
    wire [11:0] JALR_ins_w = {iw_in[31:20]};
    wire [11:0] B_ins_w    = {iw_in[31], iw_in[7], iw_in[30:25], iw_in[11:8]};

   // wire signed [31:0] JAL_signed  = 2 * $signed(JAL_ins_w);
   // wire signed [31:0] JALR_signed = $signed(JALR_ins_w);
   // wire signed [31:0] B_signed    = 2 * $signed(B_ins_w); 

    // register used to grab branch type
    wire [31:0] jal_addr_result = pc_in + $signed(2 * $signed(JAL_ins_w));
    wire [31:0] jalr_addr_result = rs1_df_data + $signed(JALR_ins_w);
    wire [31:0] branch_addr_result = pc_in + $signed(2 * $signed(B_ins_w));

    // jump enable based on JAL, JALR, B-Types (BEQ, BNE, BLT, BGE, BLTU, & BGEU) taken     
    assign jump_addr_out = (jp_inst == 2'b01) ? jal_addr_result  : 
                           (jp_inst == 2'b10) ? jalr_addr_result :
                           ((jp_inst == 2'b11) && (branch_funct3 == 3'b000) && (rs1_df_data == rs2_df_data)) ? branch_addr_result :
                           ((jp_inst == 2'b11) && (branch_funct3 == 3'b001) && (rs1_df_data != rs2_df_data)) ? branch_addr_result :
                           ((jp_inst == 2'b11) && (branch_funct3 == 3'b100) && (rs1_df_data <  rs2_df_data)) ? branch_addr_result :
                           ((jp_inst == 2'b11) && (branch_funct3 == 3'b101) && (rs1_df_data >= rs2_df_data)) ? branch_addr_result :
                           ((jp_inst == 2'b11) && (branch_funct3 == 3'b110) && ($unsigned(rs1_df_data) <  $unsigned(rs2_df_data))) ? branch_addr_result :
                           ((jp_inst == 2'b11) && (branch_funct3 == 3'b111) && ($unsigned(rs1_df_data) >= $unsigned(rs2_df_data))) ? branch_addr_result : pc_in;
    
    assign jump_enable_out = ((jump_addr_out != pc_in));

    assign jp_inst_output = jp_inst;
    assign b_branch_output = branch_addr_result;
    assign branch_funct3_output = branch_funct3;

    always_ff @ (posedge (clk))
    begin
        if (reset)
        begin
            rs1_data_out   <= 32'b0;
            rs2_data_out   <= 32'b0;
            pc_out         <= 32'b0;
            iw_out         <= 32'b0;
            wb_reg_out     <= 5'b0;
            wb_enable_out  <= 1'b0;
            branch_break   <= 1'b0;
        end 
        else 
        begin
            // Data Handler from pre-saved data for rs1 & rs2 data outputs - priority: ex, mem, wb
            // IW break handler - outputs NOP next clock (throws out grabbed values)
            if (jump_enable_out != 1'b0 && branch_break != 1'b0)
            begin
                branch_break   <= 1'b1;
                iw_out         <= iw_in;
                rs1_data_out   <= rs1_df_data;
                rs2_data_out   <= rs2_df_data;
                pc_out         <= pc_in; 
                wb_reg_out     <= wb_true_reg;
                wb_enable_out  <= wb_true;
            end 
            else if (branch_break)
            begin
                iw_out  <= nop;
                branch_break <= 1'b0;   
                rs1_data_out   <= 32'b0;
                rs2_data_out   <= 32'b0;
                pc_out         <= pc_in; 
                wb_reg_out     <= 5'b0;
                wb_enable_out  <= 1'b0;
            end
            else
            begin
                iw_out         <= iw_in;
                rs1_data_out   <= rs1_df_data;
                rs2_data_out   <= rs2_df_data;
                pc_out         <= pc_in; 
                wb_reg_out     <= wb_true_reg;
                wb_enable_out  <= wb_true;
            end
        end
    end
endmodule
*/