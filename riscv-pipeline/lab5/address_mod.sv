`timescale 1ns / 1ps

module address_mod
(
    input [31:0] d_addr,
    input [1:0] data_width,
    output reg [1:0] address_mod,
    output reg [3:0] d_be
);

    assign address_mod = d_addr[1:0];

 // Function to generate the byte enable signal based on d_addr and data width
   always_comb
    begin
        case (address_mod)
            2'b00:
            begin
                case (data_width)
                    2'b00:   d_be <= 4'b1111;
                    2'b01:   d_be <= 4'b0011;
                    2'b10:   d_be <= 4'b0001;
                    default: d_be <= 4'b0000;
                endcase
            end
            2'b01:
            begin
                case (data_width)
                    2'b01:   d_be <= 4'b0110;
                    2'b10:   d_be <= 4'b0010;
                    default: d_be <= 4'b0000;
                endcase
            end
            2'b10:
            begin
                case (data_width)
                    2'b01:   d_be <= 4'b1100;
                    2'b10:   d_be <= 4'b0100;
                    default: d_be <= 4'b0000;
                endcase
            end
            2'b11:
            begin
                case (data_width)
                    2'b10:   d_be <= 4'b1000;
                    default: d_be <= 4'b0000;
                endcase
            end
            default: d_be <= 4'b0000;
        endcase
    end



endmodule