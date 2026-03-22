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

    // Variables used for ALU Testing - temp variables from lab 2
    reg [31:0] pc_in_top;
    reg [31:0] iw_in_top;
    reg [31:0] rs1_data_in_top;
    reg [31:0] rs2_data_in_top;
    reg [31:0] alu_out_top;

    /* LAB 3 IMPLEMENTATION
       Switch Functions:
        - SW[4:0] displays rs1 data on LEDS
        - SW[4:0] wb reg - (where to store wb data)
        - SW[11:5] limited/mixed data for wb data
        - SW[11:10] displays sectioned values of 32'bits of selected reg
       PB Allocations:
        - reset - pb1 - (zeros all registers)
        - wb enable - pb2 - (stores wb data into selected reg)
        - swaps rs2 data onto LEDS - pb3
    */

    // Variables used for Register File Testing - temp vars for lab 3
    reg [4:0] rs1_reg;
    reg [4:0] rs2_reg; 
    reg wb_enable;     
    reg [4:0] wb_reg;  
    reg [31:0] wb_data;
    reg [31:0] rs1_data;
    reg [31:0] rs2_data;

    wire [4:0] rs1_select = SW[4:0];
    wire [4:0] rs2_select = SW[9:5];
    assign rs1_reg        = {rs1_select[4:0]};
    assign rs2_reg        = {rs2_select[4:0]};
    wire [4:0] wb_reg_sw  = SW[4:0];
    wire [6:0] wb_data_sw = SW[11:5];
    assign wb_reg         = {wb_reg_sw[4:0]};
    assign wb_data = {wb_data_sw[2:0], wb_data_sw[6:0], wb_data_sw[6:0], wb_data_sw[6:0], wb_data_sw[6:0]};

    // handle wb_enable input metastability safely
    reg pre_wb_enable;
    always_ff @ (posedge(clk))
    begin
        pre_wb_enable <= PB[1];
        wb_enable <= pre_wb_enable;
    end

    // handle register view switching input metastability safely
    reg rs_data_switch;
    reg pre_rs_data_switch;
    always_ff @ (posedge(clk))
    begin
        pre_rs_data_switch <= PB[2];
        rs_data_switch <= pre_rs_data_switch;
    end

    // Switch to LED - [9:0] LED 
    reg [9:0] alu_2_led;
    assign LED = alu_2_led;

    // ALU output via LED via switches
    wire [1:0] led_mode = SW[11:10];
    always_comb
    begin
        case(rs_data_switch)
        1'b0:
        begin
            case (led_mode)
            2'b00:   alu_2_led = {rs1_data[9:0]};
            2'b01:   alu_2_led = {rs1_data[19:10]};
            2'b10:   alu_2_led = {rs1_data[29:20]};
            2'b11:   alu_2_led = {7'b0000000, rs1_data[31:30]};
            default: alu_2_led = 10'b0000000000;
        endcase
        end
        1'b1:
        begin
            case (led_mode)
            2'b00:   alu_2_led = {rs2_data[9:0]};
            2'b01:   alu_2_led = {rs2_data[19:10]};
            2'b10:   alu_2_led = {rs2_data[29:20]};
            2'b11:   alu_2_led = {7'b0000000, rs2_data[31:30]};
            default: alu_2_led = 10'b0000000000;
            endcase
        end
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
    
    // Instantiate rv32i_regs.sv module 
    rv32i_regs rv_regs (
    .clk(clk),                      // system clock     
    .reset(reset),                  // synchronous reset
    .rs1_reg(rs1_reg),              // notes register # to grab values fron 
    .rs2_reg(rs2_reg),              // notes register # to grab values fron 
    .wb_enable(wb_enable),          // Enables write back - saves values into registers
    .wb_reg(wb_reg),                // notes which register to write data into
    .wb_data(wb_data),              // the data which will be stored in selected register
    .rs1_data(rs1_data),            // data output from the selected register
    .rs2_data(rs2_data)             // data output from the selected register
    );
endmodule


/*  USED FOR TESTING LAB 2
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
*/