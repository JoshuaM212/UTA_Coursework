`timescale 1ns / 1ps

module alu (
    input [31:0] pc_in,         // from id (currently top)
    input [31:0] iw_in,         // from id (currently top)
    input [31:0] rs1_data_in,   // from id (currently top)
    input [31:0] rs2_data_in,   // from id (currently top)
    output reg [31:0] alu_out   // to mem (currently top)
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
                    funct3_0: alu_out = $signed(RS1_Instr_comb[7:0]);  // LB
                    funct3_1: alu_out = $signed(RS1_Instr_comb[15:0]); // LH
                    funct3_2: alu_out = $signed(RS1_Instr_comb[31:0]); // LW
                    funct3_4: alu_out = {24'b0, RS1_Instr_comb[7:0]};  // LBU
                    funct3_5: alu_out = {16'b0, RS1_Instr_comb[15:0]}; // LHU
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
                    funct3_0: alu_out = rs2_data_in[7:0];  // SB
                    funct3_1: alu_out = rs2_data_in[15:0]; // SH
                    funct3_2: alu_out = rs2_data_in;       // SW
                    default:  alu_out = 32'b0; // Universal Default case
                endcase
            JALR_opcode:  alu_out = (rs1_data_in + $signed(I_non_shamt)) & ~32'b1; // JALR (Part of I list)
            LUI_opcode:   alu_out = {U_ins_w, 12'b0}; // LUI
            AUIPC_opcode: alu_out = {iw_in[31:12], AUIPC_Instr_comb[11:0]}; // AUIPC
            JAL_opcode:   alu_out = pc_in + 2 * $signed(JAL_ins_w);  // JAL (pc+4 version done outside of ALU)
            default:      alu_out = 32'b0; // Universal Default case 
        endcase
    end
endmodule

/*

// Overview:
//  - The opcode divides the inputs into one of the instruction types.
//  - Afterwards, the funct3 describes which function to use from the set.
//  - If neccessary, the funct7 will further specify which function to use 
//       due to instruction set operation list size.

// Main Functions Reviewed

    // R-type: 10 total functions
    // I-type: 18 total functions
    // S-type: 3 total functions
    // B-type: 6 total functions
    // U-type: 2 total functions
    // J-type: 1 total function

    // [6:0] - optcode (7 bits) - {+ list complete}
    //   Versions: (11 total)
    // + 1:  0110011 - R-type (full list)
    // + 2:  1100111 - I-type (JALR only)
    // + 3:  0000011 - I-type (load)
    // + 4:  0010011 - I-type (immdiate)
    // - 5:  0001111 - I-type (NOP {or FENCE} only)
    // - 6:  1110011 - I-type (ECALL and EBREAK only)
    // + 7:  0100011 - S-type (full list)
    // + 8:  1100011 - B-type (full list)
    // + 9:  0110111 - U-type (LUI only)
    // + 10: 0010111 - U-type (AUIPC only)
    // + 11: 1101111 - J-type (JAL only)
    //   R:f7,f3   I:f3  S:f3   B:f3   U:none   J:none 

    // Unused ALU Functions

    localparam NOP_opcode   = 7'b0001111;
    localparam E_all_opcode = 7'b1110011;
    localparam B_all_opcode = 7'b1100011;

    // Part of I-type list - NOT ON LAB ASSIGNMENT
    if (opcode = 0001111)
        NOP <or FENCE>

    if (opcode = 1110011)
        if (iw_in[20] == 1)
            ECALL
        else if (iw_in[20] == 0)
            EBREAK


    // Full list of B-types - NOT ON LAB ASSIGNMENT
    if (opcode = 1100011)
        if (funct3 = 000)
            BEQ
        else if (funct3 = 001)
            BNE
        else if (funct3 = 100)
            BLT
        else if (funct3 = 101)
            BGE
        else if (funct3 = 110)
            BLTU
        else if (funct3 = 111)
            BGEU
*/