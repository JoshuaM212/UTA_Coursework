`timescale 1ns / 1ps

module data_shifter
(
    // PC Variables
    input [31:0] pc_data,       // Data port: Input data from PC (Shift Left)
    input [3:0] shift,          // Data port: Input indecating shift amount
    output reg [31:0] pc_shift, // Data port: Output data shifted for IF (to mem)

    // Register Variables
    input [31:0] reg_data,      // Data port: Input data from Registers (Shift Right)
    input sign_value,           // Data port: Input indecating signed/unsigned
    input [1:0] addr_offset,    // Data port: Input indecating address offset
    input [1:0] data_length,    // Data port: Input indecating word length
    output reg [31:0] reg_shift // Data port: Output data shifted for WB (to reg)
);

    // Data Shifter:
    // - shifted direction: 1 = left, 0 = right
    // - shift amount: 0001,0011,1111 = 0 | 0010,0110 = 8 | 0100,1100 = 16, | 1000 = 24
    // - sign_value: 1 = signed, 0 = unsigned
    // - addr_offset: 0 = 0, 1 = 8, 2 = 16, 3 = 24
    // - data_length: 0 = word, 1 = half, 2 = byte
    
    // PC Shifter (Right)
    always_comb
    begin
        case(shift)
            4'b0010: pc_shift <= pc_data << 8;
            4'b0100: pc_shift <= pc_data << 16; 
            4'b0110: pc_shift <= pc_data << 8;
            4'b1000: pc_shift <= pc_data << 24;
            4'b1100: pc_shift <= pc_data << 16;            
            default: pc_shift <= pc_data;
        endcase
    end

    // Reg Shifter (Left)
    always_comb
    begin
        case(data_length)
            2'b01:
            begin
                case(addr_offset)
                    2'b00:   reg_shift <= (sign_value) ? {{16{reg_data[15]}}, reg_data[15:0]}  : {16'b0, reg_data[15:0]};
                    2'b01:   reg_shift <= (sign_value) ? {{16{reg_data[23]}}, reg_data[23:8]}  : {16'b0, reg_data[23:8]};
                    2'b10:   reg_shift <= (sign_value) ? {{16{reg_data[31]}}, reg_data[31:16]} : {16'b0, reg_data[31:16]};
                    default: reg_shift <= (sign_value) ? {{16{reg_data[15]}}, reg_data[15:0]}  : {16'b0, reg_data[15:0]};
                endcase
            end
            2'b10:
            begin
                case(addr_offset)
                    2'b00:   reg_shift <= (sign_value) ? {{24{reg_data[7]}},  reg_data[7:0]}   : {24'b0, reg_data[7:0]};
                    2'b01:   reg_shift <= (sign_value) ? {{24{reg_data[15]}}, reg_data[15:8]}  : {24'b0, reg_data[15:8]};
                    2'b10:   reg_shift <= (sign_value) ? {{24{reg_data[23]}}, reg_data[23:16]} : {24'b0, reg_data[23:16]};
                    2'b11:   reg_shift <= (sign_value) ? {{24{reg_data[31]}}, reg_data[31:24]} : {24'b0, reg_data[31:24]};
                    default: reg_shift <= (sign_value) ? {{24{reg_data[7]}},  reg_data[7:0]}   : {24'b0, reg_data[7:0]};
                endcase
            end
            default: reg_shift <= reg_data;
        endcase
    end
endmodule