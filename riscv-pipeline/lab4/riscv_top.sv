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

    // Variables used for Dual Port Memory Testing - temp vars for lab 4
    reg [31:0] i_addr;    // Step 5: Instruction Address To Read - DONE
    reg [31:0] i_rdata;   // Step 5: Instruction Data at Address - DONE
    reg [31:0] d_addr;    // Test Block: Address where to Read/Write - DONE
    reg [31:0] d_rdata;   // Test Block: Data to Read from Memory - DONE
    reg d_we;             // Test Block: Signal to Write/Read - DONE
    reg [3:0] d_be;       // Test Block: Byte Enables - DONE
    reg [31:0] d_wdata;   // Test Block: Data to Write rom Memory - DONE

    // Lab 4

    // Test Block Case Counter

    // Test Case Counter: 16 States for Writes, 16 States for Reads = 48 Test Cases (Extra Room Given)
    reg [5:0] Test_Block_State;
    always_ff @ (posedge(clk))
    begin
        if (reset)
            Test_Block_State <= 6'b0;
        else
            Test_Block_State <= Test_Block_State + 1;
    end

    // STEP 5: Program Counter (PC) - Increment every clock
    reg [31:0] pc;    
    assign i_addr = pc[31:0]; // Instruction Address for memory

    always_ff @ (posedge(clk))
        pc <= Test_Block_State * 4;
   
    // USE ILA TO VERIFY I_RDATA MATCHES HEX FILES DURING READINGS

    // Test Block Variables
    reg [1:0] data_width;
    reg if_signed;

    // Test Block Explained:
    // Even Clocks: Write Data (d_addr, d_wdata, Data_Width, if_signed, d_we)
    // Odd Clocks:  Read  Data (d_addr, if_signed, d_we)
    // d_addr:     d_addr to Read/Write
    // d_wdata:  Data to Write
    // Data Width:  00 = WORD, 01 = HALFWORD, 10 = BYTE
    // if_signed:   1 = SIGNED, 0 = UNSIGNED
    // d_we:     1 = WRITE, 0 = READ
    
    always_comb
    begin
        case (Test_Block_State)

        // WORD TESTCASES
            6'd1: // Test 1 - Write Unsigned Word 
            begin 
                d_addr     <= 32'h00001358; // Dual Port: ALU_OUT (R/W)
                d_wdata    <= 32'h12345678; // Dual Port: RS2 (W)
                data_width <= 2'b00;        // Dual Port: Byte Select (W)
                if_signed  <= 1'b0;         // Data Shifter: Signed/Unsigned (W)
                d_we       <= 1'b1;         // Dual Port: Write Enable (W)
            end
            6'd2: // Empty State
            begin 
                d_addr     <= 32'h00001358; 
                d_wdata    <= 32'h12345678;
                data_width <= 2'b00;         
                if_signed  <= 1'b0;         
                d_we       <= 1'b0;         
            end    
            6'd3: // Read Unsigned Word
            begin 
                d_addr     <= 32'h00001358; 
                d_wdata    <= 32'h12345678;
                data_width <= 2'b00;         
                if_signed  <= 1'b0;         
                d_we       <= 1'b0;         
            end  
            6'd4: // Test 4 - Write Signed Word
            begin 
                d_addr     <= 32'h00001358; 
                d_wdata    <= 32'h80045600; 
                data_width <= 2'b00;        
                if_signed  <= 1'b1;         
                d_we       <= 1'b1;         
            end            
            6'd5: // Empty
            begin 
                d_addr     <= 32'h00001358; 
                d_wdata    <= 32'h80045600; 
                data_width <= 2'b00;        
                if_signed  <= 1'b1;         
                d_we       <= 1'b0;         
            end     
            6'd6: // Read Signed Word
            begin 
                d_addr     <= 32'h00001358; 
                d_wdata    <= 32'h80045600; 
                data_width <= 2'b00;        
                if_signed  <= 1'b1;         
                d_we       <= 1'b0;         
            end            

        // HALFWORD TESTCASES       
            6'd7: // Test 3 - Write Unsigned Halfword (0 offset)
            begin 
                d_addr     <= 32'h00001358; 
                d_wdata    <= 32'h5678ABCD; 
                data_width <= 2'b01;        
                if_signed  <= 1'b0;         
                d_we       <= 1'b1;         
            end   
            6'd8: // Empty
            begin 
                d_addr     <= 32'h00001358; 
                d_wdata    <= 32'h5678ABCD; 
                data_width <= 2'b01;        
                if_signed  <= 1'b0;         
                d_we       <= 1'b0;         
            end   
            6'd9: // Read Unsigned Halfword (0 offset)
            begin 
                d_addr     <= 32'h00001358; 
                d_wdata    <= 32'h5678ABCD; 
                data_width <= 2'b01;        
                if_signed  <= 1'b0;         
                d_we       <= 1'b0;         
            end    
            6'd10: // Test 4 - Write Signed Halfword (0 offset)        
            begin 
                d_addr     <= 32'h00001358; 
                d_wdata    <= 32'h5678FFCD; 
                data_width <= 2'b01;        
                if_signed  <= 1'b1;         
                d_we       <= 1'b1;         
            end   
            6'd11: // Empty
            begin 
                d_addr     <= 32'h00001358; 
                d_wdata    <= 32'h5678FFCD; 
                data_width <= 2'b01;        
                if_signed  <= 1'b1;         
                d_we       <= 1'b0;         
            end
            6'd12: // Read Signed Halfword (0 offset)
            begin 
                d_addr     <= 32'h00001358; 
                d_wdata    <= 32'h5678FFCD; 
                data_width <= 2'b01;        
                if_signed  <= 1'b1;         
                d_we       <= 1'b0;         
            end
            6'd13: // Test 5 - Write Unsigned Halfword (1 offset)
            begin 
                d_addr     <= 32'h00001359; 
                d_wdata    <= 32'h56000BCD; 
                data_width <= 2'b01;        
                if_signed  <= 1'b0;         
                d_we       <= 1'b1;         
            end   
            6'd14: // Empty
            begin 
                d_addr     <= 32'h00001359; 
                d_wdata    <= 32'h56000BCD; 
                data_width <= 2'b01;        
                if_signed  <= 1'b0;         
                d_we       <= 1'b0;         
            end   
            6'd15: // Read Unsigned Halfword (1 offset)
            begin 
                d_addr     <= 32'h00001359; 
                d_wdata    <= 32'h56000BCD; 
                data_width <= 2'b01;        
                if_signed  <= 1'b0;         
                d_we       <= 1'b0;         
            end   
            6'd16: // Test 6 - Write Signed Halfword (1 offset)
            begin 
                d_addr     <= 32'h00001359; 
                d_wdata    <= 32'h4930BB1D; 
                data_width <= 2'b01;        
                if_signed  <= 1'b1;         
                d_we       <= 1'b1;         
            end   
            6'd17: // Empty
            begin 
                d_addr     <= 32'h00001359; 
                d_wdata    <= 32'h4930BB1D; 
                data_width <= 2'b01;        
                if_signed  <= 1'b1;         
                d_we       <= 1'b0;         
            end  
            6'd18: // Read Signed Halfword (1 offset)
            begin 
                d_addr     <= 32'h00001359; 
                d_wdata    <= 32'h4930BB1D; 
                data_width <= 2'b01;        
                if_signed  <= 1'b1;         
                d_we       <= 1'b0;         
            end
            6'd19: // Test 7 - Write Unsigned Halfword (2 offset)
            begin 
                d_addr     <= 32'h0000135A; 
                d_wdata    <= 32'h56011111; 
                data_width <= 2'b01;        
                if_signed  <= 1'b0;         
                d_we       <= 1'b1;         
            end   
            6'd20: // Empty
            begin 
                d_addr     <= 32'h0000135A; 
                d_wdata    <= 32'h56011111; 
                data_width <= 2'b01;        
                if_signed  <= 1'b0;         
                d_we       <= 1'b0;         
            end  
            6'd21: // Read Unsigned Halfword (2 offset)
            begin 
                d_addr     <= 32'h0000135A; 
                d_wdata    <= 32'h56011111; 
                data_width <= 2'b01;        
                if_signed  <= 1'b0;         
                d_we       <= 1'b0;         
            end
            6'd22: // Test 8 - Write Signed Halfword (2 offset)
            begin 
                d_addr     <= 32'h0000135A; 
                d_wdata    <= 32'h4930F222; 
                data_width <= 2'b01;        
                if_signed  <= 1'b1;         
                d_we       <= 1'b1;         
            end   
            6'd23: // Empty
            begin 
                d_addr     <= 32'h0000135A; 
                d_wdata    <= 32'h4930F222; 
                data_width <= 2'b01;        
                if_signed  <= 1'b1;         
                d_we       <= 1'b0;         
            end
            6'd24: // Read Signed Halfword (2 offset)
            begin 
                d_addr     <= 32'h0000135A; 
                d_wdata    <= 32'h4930F222; 
                data_width <= 2'b01;        
                if_signed  <= 1'b1;         
                d_we       <= 1'b0;         
            end

            // BYTE TESTCASES
            6'd25: // Test 9 - Write Unsigned Byte (0 offset)
            begin 
                d_addr     <= 32'h00001358; 
                d_wdata    <= 32'h03311330; 
                data_width <= 2'b10;        
                if_signed  <= 1'b0;         
                d_we       <= 1'b1;         
            end
            6'd26: // Empty
            begin 
                d_addr     <= 32'h00001358; 
                d_wdata    <= 32'h03311330; 
                data_width <= 2'b10;        
                if_signed  <= 1'b0;         
                d_we       <= 1'b0;         
            end
            6'd27: // Read Unsigned Byte (0 offset)
            begin 
                d_addr     <= 32'h00001358; 
                d_wdata    <= 32'h03311330; 
                data_width <= 2'b10;        
                if_signed  <= 1'b0;         
                d_we       <= 1'b0;         
            end
            6'd28: // Test 10 - Write Signed Byte (0 offset)
            begin 
                d_addr     <= 32'h00001358; 
                d_wdata    <= 32'h03318880; 
                data_width <= 2'b10;        
                if_signed  <= 1'b1;         
                d_we       <= 1'b1;         
            end
            6'd29: // Empty
            begin 
                d_addr     <= 32'h00001358; 
                d_wdata    <= 32'h03318880; 
                data_width <= 2'b10;        
                if_signed  <= 1'b1;         
                d_we       <= 1'b0;         
            end
            6'd30: // Read Signed Byte (0 offset)
            begin 
                d_addr     <= 32'h00001358; 
                d_wdata    <= 32'h03318880; 
                data_width <= 2'b10;        
                if_signed  <= 1'b1;         
                d_we       <= 1'b0;         
            end            
            6'd31: // Test 11 - Write Unsigned Byte (1 offset)
            begin 
                d_addr     <= 32'h00001359; 
                d_wdata    <= 32'h04abcde4; 
                data_width <= 2'b10;        
                if_signed  <= 1'b0;         
                d_we       <= 1'b1;         
            end
            6'd32: // Empty
            begin 
                d_addr     <= 32'h00001359; 
                d_wdata    <= 32'h04abcde4; 
                data_width <= 2'b10;        
                if_signed  <= 1'b0;         
                d_we       <= 1'b0;         
            end
            6'd33: // Read Unsigned Byte (1 offset)
            begin 
                d_addr     <= 32'h00001359; 
                d_wdata    <= 32'h04abcde4; 
                data_width <= 2'b10;        
                if_signed  <= 1'b0;         
                d_we       <= 1'b0;         
            end
            6'd34: // Test 12 - Write Signed Byte (1 offset)
            begin 
                d_addr     <= 32'h00001359; 
                d_wdata    <= 32'h59876c5; 
                data_width <= 2'b10;        
                if_signed  <= 1'b1;         
                d_we       <= 1'b1;         
            end
            6'd35: // Empty
            begin 
                d_addr     <= 32'h00001359; 
                d_wdata    <= 32'h59876c5; 
                data_width <= 2'b10;        
                if_signed  <= 1'b1;         
                d_we       <= 1'b0;         
            end
            6'd36: // Read Signed Byte (1 offset)
            begin 
                d_addr     <= 32'h00001359; 
                d_wdata    <= 32'h59876c5; 
                data_width <= 2'b10;        
                if_signed  <= 1'b1;         
                d_we       <= 1'b0;         
            end            
            6'd37: // Test 13 - Write Unsigned Byte (2 offset)
            begin 
                d_addr     <= 32'h0000135A; 
                d_wdata    <= 32'h077123d7; 
                data_width <= 2'b10;        
                if_signed  <= 1'b0;         
                d_we       <= 1'b1;         
            end
            6'd38: // Empty
            begin 
                d_addr     <= 32'h0000135A; 
                d_wdata    <= 32'h077123d7; 
                data_width <= 2'b10;        
                if_signed  <= 1'b0;         
                d_we       <= 1'b0;         
            end
             6'd39: // Read Unsigned Byte (2 offset)
            begin 
                d_addr     <= 32'h0000135A; 
                d_wdata    <= 32'h077123d7; 
                data_width <= 2'b10;        
                if_signed  <= 1'b0;         
                d_we       <= 1'b0;         
            end
            6'd40: // Test 14 - Write Signed Byte (2 offset)
            begin 
                d_addr     <= 32'h0000135A; 
                d_wdata    <= 32'h55aa22fa; 
                data_width <= 2'b10;        
                if_signed  <= 1'b1;         
                d_we       <= 1'b1;         
            end
            6'd41: // Empty
            begin 
                d_addr     <= 32'h0000135A; 
                d_wdata    <= 32'h55aa22fa; 
                data_width <= 2'b10;        
                if_signed  <= 1'b1;         
                d_we       <= 1'b0;         
            end
            6'd42: // Read Signed Byte (2 offset)
            begin 
                d_addr     <= 32'h0000135A; 
                d_wdata    <= 32'h55aa22fa; 
                data_width <= 2'b10;        
                if_signed  <= 1'b1;         
                d_we       <= 1'b0;         
            end
            6'd43: // Test 15 - Write Unsigned Byte (3 offset)
            begin 
                d_addr     <= 32'h0000135A; 
                d_wdata    <= 32'h12345688; 
                data_width <= 2'b10;        
                if_signed  <= 1'b0;         
                d_we       <= 1'b1;         
            end
            6'd44: // Empty
            begin 
                d_addr     <= 32'h0000135A; 
                d_wdata    <= 32'h12345688; 
                data_width <= 2'b10;        
                if_signed  <= 1'b0;         
                d_we       <= 1'b0;         
            end
            6'd45: // Read Unsigned Byte (3 offset)
            begin 
                d_addr     <= 32'h0000135A; 
                d_wdata    <= 32'h12345688; 
                data_width <= 2'b10;        
                if_signed  <= 1'b0;         
                d_we       <= 1'b0;         
            end
            6'd46: // Test 16 - Write Signed Byte (3 offset)
            begin 
                d_addr     <= 32'h0000135A; 
                d_wdata    <= 32'h557654aa; 
                data_width <= 2'b10;        
                if_signed  <= 1'b1;         
                d_we       <= 1'b1;         
            end
            6'd47: // Empty
            begin 
                d_addr     <= 32'h0000135A; 
                d_wdata    <= 32'h557654aa; 
                data_width <= 2'b10;        
                if_signed  <= 1'b1;         
                d_we       <= 1'b0;         
            end
            6'd48: // Read Signed Byte (3 offset)
            begin 
                d_addr     <= 32'h0000135A; 
                d_wdata    <= 32'h557654aa; 
                data_width <= 2'b10;        
                if_signed  <= 1'b1;         
                d_we       <= 1'b0;         
            end
            6'd49: // Test 17 - Write Unsigned Byte (4 offset)
            begin 
                d_addr     <= 32'h0000135B; 
                d_wdata    <= 32'h12005692; 
                data_width <= 2'b10;        
                if_signed  <= 1'b0;         
                d_we       <= 1'b1;         
            end
            6'd50: // Empty
            begin 
                d_addr     <= 32'h0000135B; 
                d_wdata    <= 32'h12005692; 
                data_width <= 2'b10;        
                if_signed  <= 1'b0;         
                d_we       <= 1'b0;         
            end
            6'd51: // Read Unsigned Byte (4 offset)
            begin 
                d_addr     <= 32'h0000135B; 
                d_wdata    <= 32'h12005692; 
                data_width <= 2'b10;        
                if_signed  <= 1'b0;         
                d_we       <= 1'b0;         
            end
            6'd52: // Test 18 - Write Signed Byte (4 offset)
            begin 
                d_addr     <= 32'h0000135B; 
                d_wdata    <= 32'h107D34E1; 
                data_width <= 2'b10;        
                if_signed  <= 1'b1;         
                d_we       <= 1'b1;         
            end
            6'd53: // Empty
            begin 
                d_addr     <= 32'h0000135B; 
                d_wdata    <= 32'h107D34E1; 
                data_width <= 2'b10;        
                if_signed  <= 1'b1;         
                d_we       <= 1'b0;         
            end
            6'd54: // Read Signed Byte (4 offset)
            begin 
                d_addr     <= 32'h0000135B; 
                d_wdata    <= 32'h107D34E1; 
                data_width <= 2'b10;        
                if_signed  <= 1'b1;         
                d_we       <= 1'b0;         
            end
        // EMPTY DEFAULT STATE
            default: // Empty State 
            begin 
                d_addr     = 32'h00000000; 
                d_wdata    = 32'h0;        
                data_width = 2'b00;        
                if_signed  = 1'b0;         
                d_we       = 1'b0;         
            end
        endcase
    end

    // Variable for Address Modication 
    reg [1:0] address_mod;

    // Final Variables for Data Shifter (Final versions of data to be stored/read from memory)
    wire [31:0] pc_shifted;
    reg [31:0] reg_shifted;
    reg [31:2] parsed_address;
    assign parsed_address = d_addr[31:2];

    // Instantiated Modules - Format: .<module variable>(<current module variable>)
    //  - Current Instntiated List:
    //      ~ rv32_ext_top.sv : (module for Execute Stage of pipeline)

    // Instantiate dual_port_ram.sv module 
    dual_port_ram dp_ram (
    .clk(clk),               // system clock     
    .i_addr(i_addr),         // Instruct Port: instr address (Read only)
    .i_rdata(i_rdata),       // Instruct Port: instr read data (Read only)
    .d_addr(parsed_address), // Data Port: data address (Read/Write)
    .d_rdata(d_rdata),       // Data Port: data read data (Read/Write)
    .d_we(d_we),             // Data Port: data write enable (Read/Write)
    .d_be(d_be),             // Data Port: byte select enable (Read/Write)
    .d_wdata(pc_shifted)     // Data Port: data write data (Read/Write)
    );
    
    // Instantiate address_mod.sv
   address_mod a_m (
    .d_addr(d_addr),            // Input: Data Address 
    .data_width(data_width),    // Input: Data Width
    .address_mod(address_mod),  // Output: Address Offset 
    .d_be(d_be)                 // Output: Bytes Enabled
    );
    
    // Instantiate data_shifter.sv module 
    data_shifter d_shifter (
    // PC Variables
    .pc_data(d_wdata),          // Data port: Input data from PC (Shift Left)
    .shift(d_be),               // Data port: Input indecating shift amount
    .pc_shift(pc_shifted),      // Data port: Output data shifted for IF (to mem)
    // Register Variables
    .reg_data(d_rdata),         // Data port: Input data from Registers (Shift Right)
    .sign_value(if_signed),     // Data port: Input indecating signed/unsigned
    .addr_offset(address_mod),  // Data port: Input indecating address offset
    .data_length(data_width),   // Data port: Input indecating word length
    .reg_shift(reg_shifted)     // Data port: Output data shifted for WB (to reg)
    );

    // Instantiate ILA module  
    ila_0 ila (
	.clk(clk), // input wire clk
	.probe0(i_addr),           // input wire [31:0]  i_addr  
    .probe1(i_rdata),          // input wire [31:0]  i_rdata
	.probe2(parsed_address),   // input wire [31:0]  d_rdata
	.probe3(d_rdata),          // input wire [31:0]  d_rdata
	.probe4(d_we),             // input wire [0:0]   we 
	.probe5(d_be),             // input wire [3:0]   d_be 
	.probe6(d_wdata),          // input wire [31:0]  d_wdata 

	.probe7(data_width),       // input wire [1:0]   width 
	.probe8(if_signed),        // input wire [0:0]   unsigned 
	.probe9(d_wdata),          // input wire [31:0]  rs2 
	.probe10(reg_shifted),     // input wire [31:0]  reg_shifted
	.probe11(pc_shifted),      // input wire [31:0]  pc_shifted
	.probe12(Test_Block_State) // input wire [5:0]  Test_Block_State
    );
endmodule

    /*  PARSED OUT VARIABLES AND FUNCTIONS

    // Variables used for ALU Testing - temp variables from lab 2
    reg [31:0] pc_in_top;
    reg [31:0] iw_in_top;
    reg [31:0] rs1_data_in_top;
    reg [31:0] rs2_data_in_top;
    reg [31:0] alu_out_top;

    // Variables used for Register File Testing - temp vars for lab 3
    reg [4:0] rs1_reg;
    reg [4:0] rs2_reg; 
    reg wb_enable;     
    reg [4:0] wb_reg;  
    reg [31:0] wb_data;
    reg [31:0] rs1_data;
    reg [31:0] rs2_data;

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
    */