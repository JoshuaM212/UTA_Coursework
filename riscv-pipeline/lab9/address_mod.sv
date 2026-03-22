`timescale 1ns / 1ps

module address_mod
(
    input  [1:0] address_mod, // offset based on last two bits on address (from alu_in) - used to determine byte select
    input  [1:0] data_width,  // data width (from iw_in[13:12] for sw) - used to determine byte select
    output reg [3:0] d_be     // to dual port ram - selected bytes
);

   always_comb
    begin
        case (address_mod) 
            2'b00:         // pc offset = 0
            begin
                case (data_width)             
                    2'b00:   d_be = 4'b0001; // funct3: 3'b000 - store byte
                    2'b01:   d_be = 4'b0011; // funct3: 3'b001 - store half word
                    2'b10:   d_be = 4'b1111; // funct3: 3'b010 - store word
                    default: d_be = 4'b0000; // default: no store
                endcase
            end
            2'b01:          // pc offset = 1
            begin
                case (data_width)
                    2'b00:   d_be = 4'b0010; // funct3: 3'b000 - store byte
                    2'b01:   d_be = 4'b0110; // funct3: 3'b001 - store half word
                    default: d_be = 4'b0000; // default: no store
                endcase
            end
            2'b10:          // pc offset = 2
            begin
                case (data_width)
                    2'b00:   d_be = 4'b0100; // funct3: 3'b000 - store byte
                    2'b01:   d_be = 4'b1100; // funct3: 3'b001 - store half word
                    default: d_be = 4'b0000; // default: no store
                endcase
            end
            2'b11:          // pc offset = 3
            begin
                case (data_width)
                    2'b00:   d_be = 4'b1000; // funct3: 3'b000 - store byte
                    default: d_be = 4'b0000; // default: no store
                endcase
            end
            default: d_be = 4'b0000;
        endcase
    end
endmodule