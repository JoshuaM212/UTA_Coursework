`timescale 1ns / 1ps

// RISC-V for Xilinx XUP Blackboard rev D (riscv.sv)
// Based on Jason Losh's Combo_Logic example
//
// Switch inputs
//   ALU sliced output mode on SW[11:10]
//   test case selection on SW[3:0]
// Reset
//   Active-high reset on PB0
// Onboard LEDs
//   ALU output on LED[9:0]


module riscv_top (
    input  CLK100,           // 100 MHz clock input
    output [9:0] LED,        // RGB1, RGB0, LED 9..0 placed from left to right
    output [2:0] RGB0,      
    output [2:0] RGB1,
    output [3:0] SS_ANODE,   // Anodes 3..0 placed from left to right
    output [7:0] SS_CATHODE, // Bit order: DP, G, F, E, D, C, B, A
    input  [11:0] SW,        // SWs 11..0 placed from left to right
    input  [3:0] PB,         // PBs 3..0 placed from left to right
    inout  [23:0] GPIO,      // PMODA-C 1P, 1N, ... 3P, 3N order
    output [3:0] SERVO,      // Servo outputs
    output PDM_SPEAKER,      // PDM signals for mic and speaker
    input  PDM_MIC_DATA,      
    output PDM_MIC_CLK,
    output ESP32_UART1_TXD,  // WiFi/Bluetooth serial interface 1
    input  ESP32_UART1_RXD,
    output IMU_SCLK,         // IMU spi clk
    output IMU_SDI,          // IMU spi data input
    input  IMU_SDO_AG,       // IMU spi data output (accel/gyro)
    input  IMU_SDO_M,        // IMU spi data output (mag)
    output IMU_CS_AG,        // IMU cs (accel/gyro) 
    output IMU_CS_M,         // IMU cs (mag)
    input  IMU_DRDY_M,       // IMU data ready (mag)
    input  IMU_INT1_AG,      // IMU interrupt (accel/gyro)
    input  IMU_INT_M,        // IMU interrupt (mag)
    output IMU_DEN_AG        // IMU data enable (accel/gyro)
    );
     
    // Terminate all of the unused outputs or i/o's - (remove terminated assignments - '//', if planning to use variable)
    // assign LED = 10'b0000000000;
    assign RGB0 = 3'b000;
    assign RGB1 = 3'b000;
    // assign SS_ANODE = 4'b0000;
    // assign SS_CATHODE = 8'b11111111;
    assign GPIO = 24'bzzzzzzzzzzzzzzzzzzzzzzzz;
    assign SERVO = 4'b0000;
    assign PDM_SPEAKER = 1'b0;
    assign PDM_MIC_CLK = 1'b0;
    assign ESP32_UART1_TXD = 1'b0;
    assign IMU_SCLK = 1'b0;
    assign IMU_SDI = 1'b0;
    assign IMU_CS_AG = 1'b1;
    assign IMU_CS_M = 1'b1;
    assign IMU_DEN_AG = 1'b0;

    // display r on left seven segment display
    assign SS_ANODE = 4'b0111;
    assign SS_CATHODE = 8'b10101111;

    // use a simpler clock name
    wire clk = CLK100;
    
    // handle reset input metastability safely
    reg reset;
    reg pre_reset;
    always_ff @ (posedge(clk))
    begin
        pre_reset <= PB[0];
        reset <= pre_reset;
    end

    // Variables used for ALU Testing - should be temp variables for lab 1
    reg [31:0] pc_in_top;
    reg [31:0] iw_in_top;
    reg [31:0] rs1_data_in_top;
    reg [31:0] rs2_data_in_top;
    reg [31:0] alu_out_top;

    // Iw_In Quick Dissect:
    //   ADD: 32'b00000000000000000000000000110011
    //   SUB: 32'b01000000000000000000000000110011
    //   SLL: 32'b00000000000000000001000000110011
    //   SLT: 32'b00000000000000000010000000110011
    //  SLTU: 32'b00000000000000000011000000110011
    //   XOR: 32'b00000000000000000100000000110011
    //   SRL: 32'b00000000000000000101000000110011
    //   SRA: 32'b01000000000000000101000000110011
    //    OR: 32'b00000000000000000110000000110011
    //   AND: 32'b00000000000000000111000000110011

    //  JALR: 32'b[    12    ]00000000000001100111

    //    LB: 32'b[    12    ]00000000000000000011
    //    LH: 32'b[    12    ]00000001000000000011
    //    LW: 32'b[    12    ]00000010000000000011
    //   LBU: 32'b[    12    ]00000100000000000011
    //   LHU: 32'b[    12    ]00000101000000000011
    //  ADDI: 32'b[    12    ]00000000000000010011
    //  SLTI: 32'b[    12    ]00000010000000010011
    // SLTIU: 32'b[    12    ]00000011000000010011
    //  XORI: 32'b[    12    ]00000100000000010011
    //   ORI: 32'b[    12    ]00000110000000010011
    //  ANDI: 32'b[    12    ]00000111000000010011
    //  SLLI: 32'b0000000[ 5 ]00000001000000010011
    //  SRLI: 32'b0000000[ 5 ]00000101000000010011
    //  SRAI: 32'b1000000[ 5 ]00000101000000010011

    //    SB: 32'b[  7  ]0000000000000[ 5 ]0100011
    //    SH: 32'b[  7  ]0000000000001[ 5 ]0100011
    //    SW: 32'b[  7  ]0000000000010[ 5 ]0100011

    //   LUI: 32'b[        20        ]000000110111
    // AUIPC: 32'b[        20        ]000000010011
    //   JAL: 32'b[        20        ]000001101111

    wire [8:0] mode = SW[8:0];
    always @ (mode)
    begin
        case (mode)
            9'b000000000:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000000000000110011};
                rs1_data_in_top = {32'd1};
                rs2_data_in_top = {32'd1};
            end
            9'b000000001:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000000000000110011};
                rs1_data_in_top = {32'd2};
                rs2_data_in_top = {32'd100};
            end
            9'b000000010:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000000000000110011};
                rs1_data_in_top = {32'd3};
                rs2_data_in_top = {32'd100000};
            end
            9'b000000011:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000000000000110011};
                rs1_data_in_top = {32'd55};
                rs2_data_in_top = {32'd111222};
            end
           9'b000000100:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000000000000110011};
                rs1_data_in_top = {32'd444444};
                rs2_data_in_top = {32'd444444};
            end
            9'b000000101:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000000000000110011};
                rs1_data_in_top = {32'd1};
                rs2_data_in_top = {32'd4294967295};
            end
            9'b000000110:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b01000000000000000000000000110011};
                rs1_data_in_top = {32'd1};
                rs2_data_in_top = {32'd1};
            end
            9'b000000111:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b01000000000000000000000000110011};
                rs1_data_in_top = {32'd10};
                rs2_data_in_top = {32'd5};
            end
            9'b000001000:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b01000000000000000000000000110011};
                rs1_data_in_top = {32'd2000};
                rs2_data_in_top = {32'd124};
            end    
            9'b000001001:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b01000000000000000000000000110011};
                rs1_data_in_top = {32'd10};
                rs2_data_in_top = {32'd100};
            end
            9'b000001010:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b01000000000000000000000000110011};
                rs1_data_in_top = {32'd0};
                rs2_data_in_top = {32'd1};
            end
            9'b000001011:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b01000000000000000000000000110011};
                rs1_data_in_top = {32'd4294967295};
                rs2_data_in_top = {32'd1};
            end
            9'b000001100:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000001000000110011};
                rs1_data_in_top = {32'd1};
                rs2_data_in_top = {32'd1};
            end
            9'b000001101:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000001000000110011};
                rs1_data_in_top = {32'd1};
                rs2_data_in_top = {32'd5};
            end
            9'b000001110:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000001000000110011};
                rs1_data_in_top = {32'd1};
                rs2_data_in_top = {32'd10};
            end
            9'b000001111:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000001000000110011};
                rs1_data_in_top = {32'd44};
                rs2_data_in_top = {32'd1};
            end

            // LEFT OFF HERE ------------------------------------------------------
            9'b000010000:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000001000000110011};
                rs1_data_in_top = {32'd44};
                rs2_data_in_top = {32'd6};
            end
            9'b000010001:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000001000000110011};
                rs1_data_in_top = {32'd100};
                rs2_data_in_top = {32'd5};
            end
            9'b000010010:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000001000000110011};
                rs1_data_in_top = {32'd1};
                rs2_data_in_top = {32'd31};
            end            
            9'b000010011:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000010000000110011};
                rs1_data_in_top = {32'd1};
                rs2_data_in_top = {32'd0};
            end  
            9'b000010100:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000010000000110011};
                rs1_data_in_top = {32'd0};
                rs2_data_in_top = {32'd1};
            end  
            9'b000010101:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000010000000110011};
                rs1_data_in_top = {32'b11111111111111111111111110100110};
                rs2_data_in_top = {32'd0};
            end  
            9'b000010110:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000010000000110011};
                rs1_data_in_top = {32'd0};
                rs2_data_in_top = {32'b11111111111111111111111110100110};
            end  
            9'b000010111:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000010000000110011};
                rs1_data_in_top = {32'd10203};
                rs2_data_in_top = {32'd544};
            end  
            9'b000011000:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000010000000110011};
                rs1_data_in_top = {32'd4294967295};
                rs2_data_in_top = {32'd33333};
            end  
            9'b000011001:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000010000000110011};
                rs1_data_in_top = {32'b11111111111111111111111110100110};
                rs2_data_in_top = {32'b11111111111111111111111111010100};
            end  
            9'b000011010:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000010000000110011};
                rs1_data_in_top = {32'b11111111111111111111111111010100};
                rs2_data_in_top = {32'b11111111111111111111111110100110};
            end  
            9'b000011011:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000011000000110011};
                rs1_data_in_top = {32'd1};
                rs2_data_in_top = {32'd0};
            end  
            9'b000011100:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000011000000110011};
                rs1_data_in_top = {32'd0};
                rs2_data_in_top = {32'd1};
            end  
            9'b000011101:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000011000000110011};
                rs1_data_in_top = {32'b11111111111111111111111110100110};
                rs2_data_in_top = {32'd0};
            end  
            9'b000011110:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000011000000110011};
                rs1_data_in_top = {32'd0};
                rs2_data_in_top = {32'b11111111111111111111111110100110};
            end  
            9'b000011111:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000011000000110011};
                rs1_data_in_top = {32'd10203};
                rs2_data_in_top = {32'd544};
            end  
            9'b000100000:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000011000000110011};
                rs1_data_in_top = {32'd4294967295};
                rs2_data_in_top = {32'd33333};
            end  
            9'b000100001:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000011000000110011};
                rs1_data_in_top = {32'b11111111111111111111111110100110};
                rs2_data_in_top = {32'b11111111111111111111111111010100};
            end  
            9'b000100010:  // 34 = 36 on chart
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000011000000110011};
                rs1_data_in_top = {32'b11111111111111111111111111010100};
                rs2_data_in_top = {32'b11111111111111111111111110100110};
            end  
            9'b000100011:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000100000000110011};
                rs1_data_in_top = {32'b1};
                rs2_data_in_top = {32'b1};
            end  
            9'b000100100:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000100000000110011};
                rs1_data_in_top = {32'd15};
                rs2_data_in_top = {32'd15};
            end  
            9'b000100101:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000100000000110011};
                rs1_data_in_top = {32'b11111111111111111111111110100110};
                rs2_data_in_top = {32'b11111111111111111111111110100110};
            end  
            9'b000100110:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000100000000110011};
                rs1_data_in_top = {32'd12345};
                rs2_data_in_top = {32'd50000};
            end  
            9'b000100111:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000100000000110011};
                rs1_data_in_top = {32'd31};
                rs2_data_in_top = {32'd0};
            end  
            9'b000101000: // 40 = 42 on chart
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000100000000110011};
                rs1_data_in_top = {32'b11111111111111111111111110100110};
                rs2_data_in_top = {32'b0};
            end  
            9'b000101001:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000101000000110011};
                rs1_data_in_top = {32'd10};
                rs2_data_in_top = {32'd1};
            end  
            9'b000101010:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000101000000110011};
                rs1_data_in_top = {32'd1234};
                rs2_data_in_top = {32'd4};
            end  
            9'b000101011:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000101000000110011};
                rs1_data_in_top = {32'b11111111111111111111111110100110};
                rs2_data_in_top = {32'b1};
            end  
            9'b000101100:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000101000000110011};
                rs1_data_in_top = {32'b11111111111111111111111110100110};
                rs2_data_in_top = {32'd8};
            end  
            9'b000101101:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000101000000110011};
                rs1_data_in_top = {32'b1};
                rs2_data_in_top = {32'b1};
            end  
            9'b000101110: // 46 = 48 on chart
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000101000000110011};
                rs1_data_in_top = {32'd4294967295};
                rs2_data_in_top = {32'd30};
            end  
            9'b000101111:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b01000000000000000101000000110011};
                rs1_data_in_top = {32'd10};
                rs2_data_in_top = {32'd1};
            end  
            9'b000110000:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b01000000000000000101000000110011};
                rs1_data_in_top = {32'd1234};
                rs2_data_in_top = {32'd4};
            end  
            9'b000110001:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b01000000000000000101000000110011};
                rs1_data_in_top = {32'b11111111111111111111111110100110};
                rs2_data_in_top = {32'd1};
            end  
            9'b000110010:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b01000000000000000101000000110011};
                rs1_data_in_top = {32'b11111111111111111111111110100110};
                rs2_data_in_top = {32'd8};
            end  
            9'b000110011:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b01000000000000000101000000110011};
                rs1_data_in_top = {32'b1};
                rs2_data_in_top = {32'b1};
            end  
            9'b000110100: // 52 = 54 on chart
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b01000000000000000101000000110011};
                rs1_data_in_top = {32'd4294967295};
                rs2_data_in_top = {32'd30};
            end  
            9'b000110101:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000110000000110011};
                rs1_data_in_top = {32'd8};
                rs2_data_in_top = {32'd4};
            end  
            9'b000110110:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000110000000110011};
                rs1_data_in_top = {32'd12};
                rs2_data_in_top = {32'd2};
            end  

            9'b000110111:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000110000000110011};
                rs1_data_in_top = {32'b11111111111111111111111110100110};
                rs2_data_in_top = {32'd100};
            end  

            9'b000111000:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000110000000110011};
                rs1_data_in_top = {32'd36};
                rs2_data_in_top = {32'b0};
            end  
            9'b000111001:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000110000000110011};
                rs1_data_in_top = {32'd55000};
                rs2_data_in_top = {32'd300};
            end  
            9'b000111010: // 58 = 60 on chart 
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000110000000110011};
                rs1_data_in_top = {32'b1};
                rs2_data_in_top = {32'b1};
            end  
            9'b000111011:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000111000000110011};
                rs1_data_in_top = {32'b1};
                rs2_data_in_top = {32'b0};
            end  
            9'b000111100:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000111000000110011};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'b1};
            end  
            9'b000111101:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000111000000110011};
                rs1_data_in_top = {32'd15};
                rs2_data_in_top = {32'd12};
            end  
            9'b000111110:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000111000000110011};
                rs1_data_in_top = {32'b11111111111111111111111110100110};
                rs2_data_in_top = {32'd1440};
            end      
            9'b000111111: // 63 = 65 on chart
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000111000000110011};
                rs1_data_in_top = {32'd4294967295};
                rs2_data_in_top = {32'd511};
            end  

            // LB Start - 64 = 66 on chart

            9'b001000000:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000000000000000011};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'b0};
            end
            9'b001000001:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000001100000000000000000011};
                rs1_data_in_top = {32'b1};
                rs2_data_in_top = {32'b0};
            end
            9'b001000010:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000110000000000000000000011};
                rs1_data_in_top = {32'd1234};
                rs2_data_in_top = {32'b0};
            end 
            9'b001000011:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000011000000000000000000000011};
                rs1_data_in_top = {32'b11111111111111111111111111111111};
                rs2_data_in_top = {32'b0};
            end 
            9'b001000100:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00011000001100000000000000000011};
                rs1_data_in_top = {32'b11111111111111111111111110100110};
                rs2_data_in_top = {32'b0};
            end 
            9'b001000101:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b11111111111100000000000000000011};
                rs1_data_in_top = {32'b11111111111111111111111111111111};
                rs2_data_in_top = {32'b0};
            end 

            // LH Start - 70 = 72 on chart

            9'b001000110:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000001000000000011};
                rs1_data_in_top = {32'd57344};
                rs2_data_in_top = {32'b0};
            end 
            9'b001000111:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000001100000001000000000011};
                rs1_data_in_top = {32'b1};
                rs2_data_in_top = {32'b0};
            end 
            9'b001001000:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000110000000001000000000011};
                rs1_data_in_top = {32'd1234};
                rs2_data_in_top = {32'b0};
            end 
            9'b001001001:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000011000000000001000000000011};
                rs1_data_in_top = {32'b11111111111111111111111111111111};
                rs2_data_in_top = {32'b0};
            end 
            9'b001001010:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00011000001100000001000000000011};
                rs1_data_in_top = {32'b11111111111111111111111110100110};
                rs2_data_in_top = {32'b0};
            end 
            9'b001001011:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b11111111111100000001000000000011};
                rs1_data_in_top = {32'd4294967295};
                rs2_data_in_top = {32'b0};
            end 

            // LW Start - 76 = 78 on chart

            9'b001001100:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000010000000000011};
                rs1_data_in_top = {32'd3758096384};
                rs2_data_in_top = {32'b0};
            end 
            9'b001001101:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000001100000010000000000011};
                rs1_data_in_top = {32'b1};
                rs2_data_in_top = {32'b0};
            end 
            9'b001001110:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000110000000010000000000011};
                rs1_data_in_top = {32'd1234};
                rs2_data_in_top = {32'b0};
            end 
            9'b001001111:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000011000000000010000000000011};
                rs1_data_in_top = {32'b11111111111111111111111111111111};
                rs2_data_in_top = {32'b0};
            end 
            9'b001010000:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00011000001100000010000000000011};
                rs1_data_in_top = {32'b11111111111111111111111110100110};
                rs2_data_in_top = {32'b0};
            end 
            9'b001010001:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b11111111111100000010000000000011};
                rs1_data_in_top = {32'd4294967295};
                rs2_data_in_top = {32'b0};
            end 

            // LBU Start - 82 = 84 on chart

            9'b001010010:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000100000000000011};
                rs1_data_in_top = {32'd192};
                rs2_data_in_top = {32'b0};
            end 
            9'b001010011:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000001100000100000000000011};
                rs1_data_in_top = {32'b1};
                rs2_data_in_top = {32'b0};
            end 
            9'b001010100:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000110000000100000000000011};
                rs1_data_in_top = {32'd1234};
                rs2_data_in_top = {32'b0};
            end 
            9'b001010101:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000011000000000100000000000011};
                rs1_data_in_top = {32'b11111111111111111111111111111111};
                rs2_data_in_top = {32'b0};
            end 
            9'b001010110:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00011000001100000100000000000011};
                rs1_data_in_top = {32'b11111111111111111111111110100110};
                rs2_data_in_top = {32'b0};
            end 
            9'b001010111:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b11111111111100000100000000000011};
                rs1_data_in_top = {32'd4294967295};
                rs2_data_in_top = {32'b0};
            end 

            // LHU Start - 88 = 90 on chart

            9'b001011000:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000101000000000011};
                rs1_data_in_top = {32'd57344};
                rs2_data_in_top = {32'b0};
            end 
            9'b001011001:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000001100000101000000000011};
                rs1_data_in_top = {32'b1};
                rs2_data_in_top = {32'b0};
            end 
            9'b001011010:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000110000000101000000000011};
                rs1_data_in_top = {32'd1234};
                rs2_data_in_top = {32'b0};
            end 
            9'b001011011:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000011000000000101000000000011};
                rs1_data_in_top = {32'b11111111111111111111111111111111};
                rs2_data_in_top = {32'b0};
            end 
            9'b001011100:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00011000001100000101000000000011};
                rs1_data_in_top = {32'b11111111111111111111111110100110};
                rs2_data_in_top = {32'b0};
            end 
            9'b001011101:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b11111111111100000101000000000011};
                rs1_data_in_top = {32'd4294967295};
                rs2_data_in_top = {32'b0};
            end 

            // ADDI Start - 94 = 96 on chart

            9'b001011110:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000000000000010011};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'b0};
            end 
            9'b001011111:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000001100000000000000010011};
                rs1_data_in_top = {32'b1};
                rs2_data_in_top = {32'b0};
            end 
            9'b001100000:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000110000000000000000010011};
                rs1_data_in_top = {32'd1234};
                rs2_data_in_top = {32'b0};
            end 
            9'b001100001:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000011000000000000000000010011};
                rs1_data_in_top = {32'b11111111111111111111111111111111};
                rs2_data_in_top = {32'b0};
            end 
            9'b001100010:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00011000001100000000000000010011};
                rs1_data_in_top = {32'b11111111111111111111111110100110};
                rs2_data_in_top = {32'b0};
            end 
            9'b001100011:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b11111111111100000000000000010011};
                rs1_data_in_top = {32'd4294959104};
                rs2_data_in_top = {32'b0};
            end 

            // SLTI Start - 100 = 102 on chart

            9'b001100100:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000010000000010011};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'b0};
            end 
            9'b001100101:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000001100000010000000010011};
                rs1_data_in_top = {32'b1};
                rs2_data_in_top = {32'b0};
            end 
            9'b001100110:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000110000000010000000010011};
                rs1_data_in_top = {32'd1234};
                rs2_data_in_top = {32'b0};
            end 
            9'b001100111:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000011000000000010000000010011};
                rs1_data_in_top = {32'b11111111111111111111111111111111};
                rs2_data_in_top = {32'b0};
            end 
            9'b001101000:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00011000001100000010000000010011};
                rs1_data_in_top = {32'b11111111111111111111111110100110};
                rs2_data_in_top = {32'b0};
            end 
            9'b001101001:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b11111111111100000010000000010011};
                rs1_data_in_top = {32'd4294967295};
                rs2_data_in_top = {32'b0};
            end 

            // SLTIU Start - 106 = 108 on chart

            9'b001101010:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000011000000010011};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'b0};
            end 
            9'b001101011:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000001100000011000000010011};
                rs1_data_in_top = {32'b1};
                rs2_data_in_top = {32'b0};
            end 
            9'b001101100:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000110000000011000000010011};
                rs1_data_in_top = {32'd1234};
                rs2_data_in_top = {32'b0};
            end 
            9'b001101101:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000011000000000011000000010011};
                rs1_data_in_top = {32'b11111111111111111111111111111111};
                rs2_data_in_top = {32'b0};
            end 
            9'b001101110:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00011000001100000011000000010011};
                rs1_data_in_top = {32'b11111111111111111111111110100110};
                rs2_data_in_top = {32'b0};
            end 
            9'b001101111:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b11111111111100000011000000010011};
                rs1_data_in_top = {32'd4294967295};
                rs2_data_in_top = {32'b0};
            end 

            // XORI Start - 112 = 114 on chart

            9'b001110000:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000100000000010011};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'b0};
            end 
            9'b001110001:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000001100000100000000010011};
                rs1_data_in_top = {32'b1};
                rs2_data_in_top = {32'b0};
            end 
            9'b001110010:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000110000000100000000010011};
                rs1_data_in_top = {32'd1234};
                rs2_data_in_top = {32'b0};
            end 
            9'b001110011:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000011000000000100000000010011};
                rs1_data_in_top = {32'b11111111111111111111111111111111};
                rs2_data_in_top = {32'b0};
            end 
            9'b001110100:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00011000001100000100000000010011};
                rs1_data_in_top = {32'b11111111111111111111111110100110};
                rs2_data_in_top = {32'b0};
            end 
            9'b001110101:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b11111111111100000100000000010011};
                rs1_data_in_top = {32'd4294967295};
                rs2_data_in_top = {32'b0};
            end 

            // ORI Start - 118 = 120 on chart

            9'b001110110:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000110000000010011};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'b0};
            end 
            9'b001110111:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000001100000110000000010011};
                rs1_data_in_top = {32'b1};
                rs2_data_in_top = {32'b0};
            end 
            9'b001111000:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000110000000110000000010011};
                rs1_data_in_top = {32'd1234};
                rs2_data_in_top = {32'b0};
            end 
            9'b001111001:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000011000000000110000000010011};
                rs1_data_in_top = {32'b11111111111111111111111111111111};
                rs2_data_in_top = {32'b0};
            end 
            9'b001111010:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00011000001100000110000000010011};
                rs1_data_in_top = {32'b11111111111111111111111110100110};
                rs2_data_in_top = {32'b0};
            end 
            9'b001111011:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b11111111111100000110000000010011};
                rs1_data_in_top = {32'd4294967295};
                rs2_data_in_top = {32'b0};
            end 

            // ANDI Start - 124 = 126 on chart

            9'b001111100:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000111000000010011};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'b0};
            end 
            9'b001111101:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000001100000111000000010011};
                rs1_data_in_top = {32'b1};
                rs2_data_in_top = {32'b0};
            end 
            9'b001111110:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000110000000111000000010011};
                rs1_data_in_top = {32'd1234};
                rs2_data_in_top = {32'b0};
            end 
            9'b001111111:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000011000000000111000000010011};
                rs1_data_in_top = {32'b11111111111111111111111111111111};
                rs2_data_in_top = {32'b0};
            end 
            9'b010000000:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00011000001100000111000000010011};
                rs1_data_in_top = {32'b11111111111111111111111110100110};
                rs2_data_in_top = {32'b0};
            end 
            9'b010000001:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b11111111111100000111000000010011};
                rs1_data_in_top = {32'd4294967295};
                rs2_data_in_top = {32'b0};
            end 

            // SLLI Start - 130 = 132 on chart

            9'b010000010:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000001000000010011};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'b0};
            end 
            9'b010000011:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000100000001000000010011};
                rs1_data_in_top = {32'b1};
                rs2_data_in_top = {32'b0};
            end 
            9'b010000100:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000001100000001000000010011};
                rs1_data_in_top = {32'd1234};
                rs2_data_in_top = {32'b0};
            end 
            9'b010000101:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000011100000001000000010011};
                rs1_data_in_top = {32'b11111111111111111111111111111111};
                rs2_data_in_top = {32'b0};
            end 
            9'b010000110:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000111100000001000000010011};
                rs1_data_in_top = {32'b11111111111111111111111110100110};
                rs2_data_in_top = {32'b0};
            end 
            9'b010000111:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000001111100000001000000010011};
                rs1_data_in_top = {32'd4294967295};
                rs2_data_in_top = {32'b0};
            end 

            // SRLI Start - 136 = 138 on chart

            9'b010001000:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000101000000010011};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'b0};
            end 
            9'b010001001:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000100000101000000010011};
                rs1_data_in_top = {32'b1};
                rs2_data_in_top = {32'b0};
            end 
            9'b010001010:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000001100000101000000010011};
                rs1_data_in_top = {32'd1234};
                rs2_data_in_top = {32'b0};
            end 
            9'b010001011:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000011100000101000000010011};
                rs1_data_in_top = {32'b11111111111111111111111111111111};
                rs2_data_in_top = {32'b0};
            end 
            9'b010001100:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000111100000101000000010011};
                rs1_data_in_top = {32'b11111111111111111111111110100110};
                rs2_data_in_top = {32'b0};
            end 
            9'b010001101:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000001111100000101000000010011};
                rs1_data_in_top = {32'd4294967295};
                rs2_data_in_top = {32'b0};
            end 

            // SRAI Start - 142 = 144 on chart

            9'b010001110:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b01000000000000000101000000010011};
                rs1_data_in_top = {32'b1};
                rs2_data_in_top = {32'b0};
            end 
            9'b010001111:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b01000000000100000101000000010011};
                rs1_data_in_top = {32'b1};
                rs2_data_in_top = {32'b0};
            end 
            9'b010010000:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b01000000001100000101000000010011};
                rs1_data_in_top = {32'd1234};
                rs2_data_in_top = {32'b0};
            end 
            9'b010010001:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b01000000011100000101000000010011};
                rs1_data_in_top = {32'b11111111111111111111111111111111};
                rs2_data_in_top = {32'b0};
            end 
            9'b010010010:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b01000000111100000101000000010011};
                rs1_data_in_top = {32'b11111111111111111111111110100110};
                rs2_data_in_top = {32'b0};
            end 
            9'b010010011:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b01000001111100000101000000010011};
                rs1_data_in_top = {32'd4294967295};
                rs2_data_in_top = {32'b0};
            end 

            // SB Start - 148 = 150 on chart
            9'b010010100:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000000000000100011};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'd1};
            end  
            9'b010010101:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000000111100100011};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'd10};
            end
            9'b010010110:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b11111110000000000000000000100011};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'd100};
            end
            9'b010010111:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b11111110000000000000111100100011};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'd10000};
            end
            9'b010011000:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b11000000000000000000110010100011};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'd100000};
            end
            9'b010011001:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b11111110000000000000110010100011};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'd4294967295};
            end

            // SH Start - 154 = 156 on chart
            9'b010011010:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000001000000100011};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'd1};
            end  
            9'b010011011:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000001111100100011};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'd10};
            end
            9'b010011100:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b11111110000000000001000000100011};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'd100};
            end
            9'b010011101:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b11111110000000000001111100100011};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'd10000};
            end
            9'b010011110:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b11000000000000000001110010100011};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'd100000};
            end
            9'b010011111:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b11111110000000000001110010100011};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'd4294967295};
            end


            // SW Start - 160 = 162 on chart
            9'b010100000:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000010000000100011};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'd1};
            end  
            9'b010100001:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000010111100100011};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'd10};
            end
            9'b010100010:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b11111110000000000010000000100011};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'd100};
            end
            9'b010100011:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b11111110000000000010111100100011};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'd10000};
            end
            9'b010100100:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b11000000000000000010110010100011};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'd100000};
            end
            9'b010100101:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b1111111000000000010110010100011};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'd4294967295};
            end


            // JALR starts 166  = 168 on chart
            9'b010100110:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000000000001100111};
                rs1_data_in_top = {32'd55};
                rs2_data_in_top = {32'b0};
            end
            9'b010100111:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000111100000000000001100111};
                rs1_data_in_top = {32'd165};
                rs2_data_in_top = {32'b0};
            end
            9'b010101000:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00001111000000000000000001100111};
                rs1_data_in_top = {32'd495};
                rs2_data_in_top = {32'b0};
            end
            9'b010101001:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b11110000000000000000000001100111};
                rs1_data_in_top = {32'd1485};
                rs2_data_in_top = {32'b0};
            end
            9'b010101010:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b11111111111100000000000001100111};
                rs1_data_in_top = {32'd4455};
                rs2_data_in_top = {32'b0};
            end
            9'b010101011:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000000000001100111};
                rs1_data_in_top = {32'd13365};
                rs2_data_in_top = {32'b0};
            end

            // LUI starts 172  = 174 on chart
            9'b010101100:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000111000000110111};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'b0};
            end
            9'b010101101:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000001110000000000110111};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'b0};
            end
            9'b010101110:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000010000001010000000110111};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'b0};
            end
            9'b010101111:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b11100000101011101010000000110111};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'b0};
            end
            9'b010110000:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b00000000000000000000000000110111};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'b0};
            end
            9'b010110001:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b10101010101010101010000000110111};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'b0};
            end

            // AUIPC starts 178  = 180 on chart

            9'b010110010:
            begin
                pc_in_top       = {32'd5};
                iw_in_top       = {32'b00000000000000000111000000010111};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'b0};
            end
            9'b010110011:
            begin
                pc_in_top       = {32'd25};
                iw_in_top       = {32'b00000000000001110000000000010111};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'b0};
            end
            9'b010110100:
            begin
                pc_in_top       = {32'd125};
                iw_in_top       = {32'b00000000010000001010000000010111};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'b0};
            end
            9'b010110101:
            begin
                pc_in_top       = {32'd625};
                iw_in_top       = {32'b11100000101011101010000000010111};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'b0};
            end
            9'b010110110:
            begin
                pc_in_top       = {32'd3125};
                iw_in_top       = {32'b00000000000000000000000000010111};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'b0};
            end
            9'b010110111:
            begin
                pc_in_top       = {32'd15625};
                iw_in_top       = {32'b10101010101010101010000000010111};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'b0};
            end

            // JAL starts 184  = 186 on chart

            9'b010111000:
            begin
                pc_in_top       = {32'd4};
                iw_in_top       = {32'b00000000000000000111000001101111};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'b0};
            end
            9'b010111001:
            begin
                pc_in_top       = {32'd20};
                iw_in_top       = {32'b00000000000001110000000001101111};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'b0};
            end
            9'b010111010:
            begin
                pc_in_top       = {32'd100};
                iw_in_top       = {32'b00000000010000001010000001101111};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'b0};
            end
            9'b010111011:
            begin
                pc_in_top       = {32'd500};
                iw_in_top       = {32'b11100000101011101010000001101111};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'b0};
            end
            9'b010111100:
            begin
                pc_in_top       = {32'd2500};
                iw_in_top       = {32'b00000000000000000000000001101111};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'b0};
            end
            9'b010111101:
            begin
                pc_in_top       = {32'd12500};
                iw_in_top       = {32'b10101010101010101010000001101111};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'b0};
            end

            // DEFAULT - ( DON'T CHANGE ) -----------------------------------------------------------
            default:
            begin
                pc_in_top       = {32'b0};
                iw_in_top       = {32'b0};
                rs1_data_in_top = {32'b0};
                rs2_data_in_top = {32'b0};
            end  
        endcase
    end

    // Switch to LED - [9:0] LED 
    reg [9:0] alu_2_led;
    assign LED = alu_2_led;

    // ALU output via LED via switches
    wire [1:0] led_mode = SW[11:10];
    always @ (led_mode)
    begin
        case (led_mode)
            2'b00:   alu_2_led = {alu_out_top[9:0]};
            2'b01:   alu_2_led = {alu_out_top[19:10]};
            2'b10:   alu_2_led = {alu_out_top[29:20]};
            2'b11:   alu_2_led = {7'b0000000, alu_out_top[31:30]};
            default: alu_2_led = 10'b0000000000;
        endcase
    end

    // Instantiated Modules - Format: .<module variable>(<current module variable>)
    //  - Current Instntiated List:
    //      ~ rv32_ext_top.sv : (module for Execute Stage of pipeline)

    // Instantiate rv32_ex_top module 
    rv32_ex_top ex (
    .clk(clk),                      // system clock       
    .reset(reset),                  // synchronous reset
    .pc_in(pc_in_top),              // temp variable meant for ( id ) to pass
    .iw_in(iw_in_top),              // temp variable meant for ( id ) to pass
    .rs1_data_in(rs1_data_in_top),  // temp variable meant for ( id ) to pass
    .rs2_data_in(rs2_data_in_top),  // temp variable meant for ( id ) to pass
    .alu_out(alu_out_top)           // temp variable meant for ( memory ) to accept
    );
endmodule