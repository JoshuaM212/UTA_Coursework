`timescale 1ns / 1ps

module alu (
    input [31:0] pc_in,         // EX input: from id
    input [31:0] iw_in,         // EX input: from id
    input [31:0] rs1_data_in,   // EX input: from id
    input [31:0] rs2_data_in,   // EX input: from id
    output reg [31:0] alu_out   // EX output: to mem 
    );

    // Opcode, Funct3, and Funct7 Identification - (common locations)
    wire [6:0] opcode = iw_in[6:0];
    wire [2:0] funct3 = iw_in[14:12];
    wire [6:0] funct7 = iw_in[31:25];

    // List of instruction words
    wire [31:0] I_non_shamt = $signed({iw_in[31:20]});
    wire [11:0] I_shamt     = {iw_in[31:20]}; //one unique case: SRAI with funct7_1
    wire [11:0] S_ins_w     = {iw_in[31:25], iw_in[11:7]};
    wire [19:0] U_ins_w     = {iw_in[31:12]};
    wire [19:0] JAL_ins_w   = {iw_in[31], iw_in[19:12], iw_in[20], iw_in[30:21]};

    // Load Istruction Handler
    wire [31:0] RS1_Instr_comb   = {rs1_data_in+$signed(I_non_shamt)};
    wire [11:0] AUIPC_Instr_comb = 12'b0 + pc_in;

    // Store Instruction RS1 Handler
    wire [31:0] rs1_s_type = rs1_data_in + $signed({iw_in[31:25], iw_in[11:7]});

    // Load Instruction RS1 Handler
    wire [31:0] rs1_l_type = rs1_data_in + $signed({iw_in[31:20]});

    // List of opcodes
    localparam R_all_opcode = 7'b0110011;
    localparam JALR_opcode  = 7'b1100111;
    localparam LOAD_opcode  = 7'b0000011;
    localparam Immed_opcode = 7'b0010011;
    localparam S_all_opcode = 7'b0100011;
    localparam LUI_opcode   = 7'b0110111;
    localparam AUIPC_opcode = 7'b0010111;
    localparam JAL_opcode   = 7'b1101111;

    // List of funct7s - named
    localparam funct7_0 = 7'b0000000;
    localparam funct7_1 = 7'b0100000;

    // List of funct3s - named
    localparam funct3_0 = 3'b000;
    localparam funct3_1 = 3'b001;
    localparam funct3_2 = 3'b010;
    localparam funct3_3 = 3'b011;
    localparam funct3_4 = 3'b100;
    localparam funct3_5 = 3'b101;
    localparam funct3_6 = 3'b110;
    localparam funct3_7 = 3'b111;

    // ALU Execution
    always_comb 
    begin
        case(opcode)
            R_all_opcode:  // Full list of R-types
            begin
                case(funct7)
                    funct7_0: 
                    begin
                        case(funct3)
                            funct3_0: alu_out = rs1_data_in + rs2_data_in;       // ADD
                            funct3_1: alu_out = rs1_data_in << rs2_data_in[4:0]; // SLL
                            funct3_2: alu_out = ($signed(rs1_data_in) < $signed(rs2_data_in)) ? 32'b1 : 32'b0;     // SLT
                            funct3_3: alu_out = ($unsigned(rs1_data_in) < $unsigned(rs2_data_in)) ? 32'b1 : 32'b0; // SLTU     
                            funct3_4: alu_out = rs1_data_in ^ rs2_data_in;       // XOR
                            funct3_5: alu_out = rs1_data_in >> rs2_data_in[4:0]; // SRL
                            funct3_6: alu_out = rs1_data_in | rs2_data_in;       // OR
                            funct3_7: alu_out = rs1_data_in & rs2_data_in;       // AND
                            default:  alu_out = 32'b0; // Universal Default case 
                        endcase
                    end
                    funct7_1:
                    begin
                        case(funct3)
                            funct3_0: alu_out = rs1_data_in - rs2_data_in; // SUB
                            funct3_5: alu_out = $signed(rs1_data_in) >>> rs2_data_in[4:0]; // SRA
                            default:  alu_out = 32'b0; // Universal Default case
                        endcase
                    end
                    default: alu_out = 32'b0; // Universal Default case
                endcase
            end
            LOAD_opcode:  // Full list of I-types - JALR moved below 
                case(funct3)
                    funct3_0: alu_out = rs1_l_type; // $signed(RS1_Instr_comb[7:0]);  // LB
                    funct3_1: alu_out = rs1_l_type; // $signed(RS1_Instr_comb[15:0]); // LH
                    funct3_2: alu_out = rs1_l_type; // $signed(RS1_Instr_comb[31:0]); // LW
                    funct3_4: alu_out = rs1_l_type; // {24'b0, RS1_Instr_comb[7:0]};  // LBU
                    funct3_5: alu_out = rs1_l_type; // {16'b0, RS1_Instr_comb[15:0]}; // LHU
                    default:  alu_out = 32'b0; // Universal Default case
                endcase
            Immed_opcode:
                case(funct3)
                    funct3_0: alu_out = rs1_data_in + $signed(I_non_shamt); // ADDI
                    funct3_1: alu_out = rs1_data_in << I_non_shamt;         // SLLI
                    funct3_2: alu_out = ($signed(rs1_data_in) < $signed(I_non_shamt)) ? 32'b1 : 32'b0;     // SLTI
                    funct3_3: alu_out = ($unsigned(rs1_data_in) < $unsigned(I_non_shamt)) ? 32'b1 : 32'b0; // SLTIU
                    funct3_4: alu_out = rs1_data_in ^ $signed(I_non_shamt); // XORI  
                    funct3_5:
                        case(funct7)
                            funct7_0: alu_out = rs1_data_in >> I_shamt[4:0]; // SRLI
                            funct7_1: alu_out = $signed(rs1_data_in) >>> I_shamt[4:0]; // SRAI
                            default:  alu_out = 32'b0; // Universal Default case
                        endcase                
                    funct3_6: alu_out = rs1_data_in | $signed(I_non_shamt); // ORI
                    funct3_7: alu_out = rs1_data_in & $signed(I_non_shamt); // ANDI
                    default:  alu_out = 32'b0; // Universal Default case
                endcase
            S_all_opcode:     // Full list of S-types
                case(funct3)
                    funct3_0: alu_out = rs1_s_type; // SB
                    funct3_1: alu_out = rs1_s_type; // SH
                    funct3_2: alu_out = rs1_s_type; // SW
                    default:  alu_out = 32'b0; // Universal Default case
                endcase
            JALR_opcode:  alu_out = pc_in + 4; // JALR (Part of I list)
            LUI_opcode:   alu_out = {U_ins_w, 12'b0}; // LUI
            AUIPC_opcode: alu_out = {iw_in[31:12], AUIPC_Instr_comb[11:0]}; // AUIPC
            JAL_opcode:   alu_out = pc_in + 4;  // JAL (pc+4 version done outside of ALU)
            default:      alu_out = 32'b0; // Universal Default case 
        endcase
    end
endmodule