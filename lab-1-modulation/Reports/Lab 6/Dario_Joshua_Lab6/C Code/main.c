// SPI Stop Go C Example
// Dario Ugalde

//-----------------------------------------------------------------------------
// Hardware Target
//-----------------------------------------------------------------------------

// Target Platform: EK-TM4C123GXL Evaluation Board
// Target uC:       TM4C123GH6PM
// System Clock:    40 MHz

// Hardware configuration:
// LDAC:
//   PE1 drives the DAC input registers into the output registers
//
// DAC I is output 0, DAC Q is output 1

//-----------------------------------------------------------------------------
// Device includes, defines, and assembler directives
//-----------------------------------------------------------------------------

#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "uart0.h"
#include "wait.h"
#include "gpio.h"
#include "nvic.h"
#include "spi1.h"
#include "clock.h"
#include "tm4c123gh6pm.h"

// Pins
#define RED_LED PORTF,1
#define GREEN_LED PORTF,3
#define CS PORTD,1
#define LDAC PORTF,4

// Global Defines
#define PI 3.14159265358979323846
#define SYSTEM_CLK      40000000
#define TABLE_SIZE      4096
#define SINE_BASE_INDEX 0    
#define COS_BASE_INDEX  1024 
#define DAC_I_MAX       230
#define DAC_I_MIN       3900
#define DAC_Q_MAX       230
#define DAC_Q_MIN       3900
#define BUFFER_SIZE 31

// Data Struct Variable
USER_DATA data;

// Command Variable
uint16_t input_cmd; 

// Global DAC Variables
int DAC_I_INDEX     = 0;
int DAC_Q_INDEX     = 0;
float DAC_I_AMP     = 0;
float DAC_Q_AMP     = 0;
uint32_t DAC_I_FREQ = 0;
uint32_t DAC_Q_FREQ = 0;
int  DAC_I_PERIOD   = 0;
int  DAC_Q_PERIOD   = 0;
bool DAC_I_ENABLED  = false;
bool DAC_Q_ENABLED  = false;

// DUAL DAC Variables
float    DUAL_DAC_AMP    = 0;
uint32_t DUAL_DAC_FREQ   = 0;
uint32_t DUAL_DAC_PERIOD = 0;
uint16_t i = 0;
uint16_t q = 0;
uint32_t GAIN_I;
uint32_t GAIN_Q;
uint32_t DAC_I_CENTER;
uint32_t DAC_Q_CENTER;
uint32_t DAC_I_DIFF;
uint32_t DAC_Q_DIFF;

// Modulation Global Variables - 1-BPSK,2-QPSK,3-8PSK,4-16QAM
uint32_t MOD_PERIOD;
uint32_t SYMBOLS   = 1;
uint16_t MOD_STATE = 0;
uint64_t BITSTREAM         = 0xFEDCBA9876543210;

uint8_t  GRABBED_BITS      = 0;
uint8_t  CAPTURED_SYMBOL   = 0;
uint32_t STEP_SIZE         = 0;
uint16_t STEP_SIZE_DIVIDER = 0;

// Preamble Variables
uint8_t PREAMBLE_MARK;    // Used for tracking usage of preamble during tranmsissions
uint8_t PREAMBLE_ENABLE;  // Used for tracking when preamble is enabled
uint32_t PREAMBLE_BPSK  = 0x00008000;
uint32_t PREAMBLE_QPSK  = 0x00008000;
uint32_t PREAMBLE_8PSK  = 0x00008000;
uint32_t PREAMBLE_16QAM = 0x00008000;

// RRC Filtering Variables
uint16_t buff_newest = 0;
uint16_t counter = 0;
bool RRC_ENABLED = false;
int j;

// Complex and Real Buffer/Arrays
uint16_t Complex_Buffer[BUFFER_SIZE][2];
float RRC_Filter[31] = {  -0.0055, -0.0097, -0.0084, 0.0000, 0.0124, 0.0211, 0.0180, -0.0000,
                          -0.0264, -0.0460, -0.0408, 0.0000, 0.0724, 0.1567, 0.2242, 0.2500 ,
                          0.2242, 0.1567, 0.0724, 0.0000, -0.0408, -0.0460, -0.0264, -0.0000,
                          0.0180, 0.0211, 0.0124, 0.0000, -0.0084, -0.0097, -0.0055
                        };

// Modulation Array Variables
uint16_t dac_i_max, dac_q_max, dac_i_zero, dac_q_zero, dac_i_min, dac_q_min, dac_i_pos_square, dac_i_neg_square, 
         dac_q_pos_square, dac_q_neg_square, dac_i_pos_third, dac_i_neg_third, dac_q_pos_third, dac_q_neg_third;

// Modulation Arrays - [DAC I, DAC Q]
// - Verify these arrays if proper/correct, may need to swap QPSK with the 8PSK .707 values
uint16_t BPSK_ARRAY[2][2];             
uint16_t QPSK_ARRAY[4][2];       
uint16_t OCTO_PSK_ARRAY[8][2];        
uint16_t HEX_QAM_ARRAY[16][2];

// Sine/Cosine Lookup Table - To be calculated/filled in main function
//float sineLUT[TABLE_SIZE];
int16_t ConvertedSineLUT[TABLE_SIZE][2];

//-----------------------------------------------------------------------------
// Subroutines
//-----------------------------------------------------------------------------
/*
// Sine Lookup Table Functions
void LOAD_SINE_LUT(void)
{
    int i;
    for (i = 0; i < TABLE_SIZE; i++)
        sineLUT[i] = sin(((float)(2 * PI * i)) / TABLE_SIZE);
}
*/
void LOAD_SINE_LUT(void)
{
    int a,b;
    for (a = 0; a < TABLE_SIZE; a++)
        ConvertedSineLUT[a][1] = (int16_t)((sin(((2.0f * PI * a)) / TABLE_SIZE))*4096.0f);


    for (b = 0; b < TABLE_SIZE; b++)
    {
        float LUTValue = (float)((ConvertedSineLUT[b % TABLE_SIZE][1])/4096.0f);
        ConvertedSineLUT[b][0] = DAC_I_CENTER + (int16_t)(GAIN_I * LUTValue);
        ConvertedSineLUT[b][1] = DAC_Q_CENTER + (int16_t)(GAIN_Q * LUTValue);
    }
}

// Spi Write Function
void writeSpi(uint8_t dacSelect, uint16_t data)
{
    // Configure upper 4 bits of SPI message according to pg.17 of MCP4822 spec
    uint16_t spiMessage = 0;
    spiMessage |= 0x8000 & (dacSelect << 15); // Select DAC register
    spiMessage |= 0x4000 & (0 << 14);         // Don't care
    spiMessage |= 0x2000 & (1 << 13);         // Output gain select 1x
    spiMessage |= 0x1000 & (1 << 12);         // Output power-down control bit
    spiMessage |= 0x0FFF & data;              // Set data

    // Transmit spi message
    setPinValue(CS, 0);
    writeSpi1Data(spiMessage);
    setPinValue(CS, 1);
}

void pulseLDAC(void)
{
    setPinValue(LDAC, 0);
    waitMicrosecond(1);
    setPinValue(LDAC, 1);
}

// Enable Interrupt Functions 
void Enable_DAC_I(uint8_t WAVE_TYPE, float AMP, uint32_t FREQ)
{
    // WAVE TYPE: 1 = sine output, 2 = cos output
    DAC_I_INDEX  = (!WAVE_TYPE) ? SINE_BASE_INDEX : COS_BASE_INDEX;
    DAC_I_AMP  = AMP;
    DAC_I_FREQ = FREQ;
    DAC_I_PERIOD = SYSTEM_CLK/(TABLE_SIZE*DAC_I_FREQ);
    DAC_I_ENABLED = true;  

    // Configure Timer 1 as the time base
    TIMER1_CTL_R &= ~TIMER_CTL_TAEN;                // turn-off timer before reconfiguring
    TIMER1_CFG_R = TIMER_CFG_32_BIT_TIMER;          // configure as 32-bit timer (A+B)
    TIMER1_TAMR_R = TIMER_TAMR_TAMR_PERIOD;         // configure for periodic mode (count down)
    TIMER1_TAILR_R = DAC_I_PERIOD;                  // set load value
    TIMER1_IMR_R = TIMER_IMR_TATOIM;                // turn-on interrupts
    TIMER1_CTL_R |= TIMER_CTL_TAEN;                 // turn-on timer
    NVIC_EN0_R = 1 << (INT_TIMER1A-16);             // turn-on interrupt 37 (TIMER1A)
}

void Enable_DAC_Q(uint8_t WAVE_TYPE, float AMP, uint32_t FREQ)
{
    // WAVE TYPE: 1 = sine output, 2 = cos output
    DAC_Q_INDEX  = (!WAVE_TYPE) ? SINE_BASE_INDEX : COS_BASE_INDEX;
    DAC_Q_AMP    = AMP;
    DAC_Q_FREQ   = FREQ;
    DAC_Q_PERIOD = SYSTEM_CLK/(TABLE_SIZE*DAC_Q_FREQ);
    DAC_Q_ENABLED = true;  

    // Configure Timer 2 as the time base
    TIMER2_CTL_R &= ~TIMER_CTL_TAEN;                // turn-off timer before reconfiguring
    TIMER2_CFG_R = TIMER_CFG_32_BIT_TIMER;          // configure as 32-bit timer (A+B)
    TIMER2_TAMR_R = TIMER_TAMR_TAMR_PERIOD;         // configure for periodic mode (count down)
    TIMER2_TAILR_R = DAC_Q_PERIOD;                  // set load value
    TIMER2_IMR_R = TIMER_IMR_TATOIM;                // turn-on interrupts
    TIMER2_CTL_R |= TIMER_CTL_TAEN;                 // turn-on timer
    NVIC_EN0_R = 1 << (INT_TIMER2A-16);             // turn-on interrupt 38 (TIMER2A)
}

void Enable_MOD_Isr()
{
    MOD_PERIOD = SYSTEM_CLK/SYMBOLS;
    GRABBED_BITS = 0;

    // Configure Timer 3 as the time base
    TIMER3_CTL_R &= ~TIMER_CTL_TAEN;                // turn-off timer before reconfiguring
    TIMER3_CFG_R = TIMER_CFG_32_BIT_TIMER;          // configure as 32-bit timer (A+B)
    TIMER3_TAMR_R = TIMER_TAMR_TAMR_PERIOD;         // configure for periodic mode (count down)
    TIMER3_TAILR_R = MOD_PERIOD;                    // set load value
    TIMER3_IMR_R = TIMER_IMR_TATOIM;                // turn-on interrupts
    TIMER3_CTL_R |= TIMER_CTL_TAEN;                 // turn-on timer
    NVIC_EN1_R = 1 << (INT_TIMER3A-16-32);          // turn-on interrupt 51 (TIMER3A)
}

void Enable_DUAL_DAC_Isr(float AMP, uint32_t FREQ)
{
    DAC_I_INDEX  = SINE_BASE_INDEX;
    DAC_Q_INDEX  = COS_BASE_INDEX;
    DUAL_DAC_AMP = AMP;
    GAIN_I = DAC_I_DIFF*2*DUAL_DAC_AMP;
    GAIN_Q = DAC_Q_DIFF*2*DUAL_DAC_AMP;

    LOAD_SINE_LUT();

    // Parsing Freq to Step/Freq Ratios
    if ((FREQ > 0) && (FREQ <= 49))
        STEP_SIZE = 1;
    else if ((FREQ > 49) && (FREQ <= 98))
        STEP_SIZE = 2;
    else if ((FREQ > 98) && (FREQ <= 195))
        STEP_SIZE = 4;
    else if ((FREQ > 195) && (FREQ <= 390))
        STEP_SIZE = 8;
    else if ((FREQ > 390) && (FREQ <= 781))
        STEP_SIZE = 16;
    else if ((FREQ > 781) && (FREQ <= 1562))
        STEP_SIZE = 32;
    else if ((FREQ > 1562) && (FREQ <= 3125))
        STEP_SIZE = 64;
    else if ((FREQ > 3125) && (FREQ <= 6250))
        STEP_SIZE = 128;
    else if ((FREQ > 6250) && (FREQ <= 12500))
        STEP_SIZE = 256;
    else if ((FREQ > 12500) && (FREQ <= 25000))
        STEP_SIZE = 512;
    else if ((FREQ > 25000) && (FREQ <= 50000))
        STEP_SIZE = 1024;
    else if ((FREQ > 50000) && (FREQ <= 100000))
        STEP_SIZE = 2048;

    STEP_SIZE_DIVIDER = 4096/STEP_SIZE;
    DUAL_DAC_PERIOD   = SYSTEM_CLK/(STEP_SIZE_DIVIDER*FREQ);

    // Configure Timer 4 as the time base
    TIMER4_CTL_R &= ~TIMER_CTL_TAEN;                // turn-off timer before reconfiguring
    TIMER4_CFG_R = TIMER_CFG_32_BIT_TIMER;          // configure as 32-bit timer (A+B)
    TIMER4_TAMR_R = TIMER_TAMR_TAMR_PERIOD;         // configure for periodic mode (count down)
    TIMER4_TAILR_R = DUAL_DAC_PERIOD;               // set load value
    TIMER4_IMR_R = TIMER_IMR_TATOIM;                // turn-on interrupts
    TIMER4_CTL_R |= TIMER_CTL_TAEN;                 // turn-on timer
    NVIC_EN2_R = 1 << (INT_TIMER4A-16-64);          // turn-on interrupt 86 (TIMER4A)
}

// Disable Interrupt Functions
void disable_DAC_I_output(void)
{
    TIMER1_CTL_R &= ~TIMER_CTL_TAEN;        // turn-off time base timer
    NVIC_DIS0_R = 1 << (INT_TIMER1A-16);    // turn-off interrupt 37 (TIMER1A)
}

void disable_DAC_Q_output(void)
{
    TIMER2_CTL_R &= ~TIMER_CTL_TAEN;        // turn-off time base timer
    NVIC_DIS0_R = 1 << (INT_TIMER2A-16);    // turn-off interrupt 38 (TIMER2A)
}

void Disable_MOD_Isr(void)
{
    GRABBED_BITS = 0;
    PREAMBLE_MARK = 0;
    TIMER3_CTL_R &= ~TIMER_CTL_TAEN;        // turn-off time base timer
    NVIC_DIS1_R = 1 << (INT_TIMER3A-16-32); // turn-off interrupt 51 (TIMER3A)
}

void Disable_Both_DAC(void)
{
    TIMER4_CTL_R &= ~TIMER_CTL_TAEN;        // turn-off time base timer
    NVIC_DIS2_R = 1 << (INT_TIMER4A-16-64); // turn-off interrupt 86 (TIMER4A)
}

// Interrupt Handler Functions
void DAC_I_Isr(void)
{
    writeSpi(0, ConvertedSineLUT[DAC_I_INDEX][0]);
    pulseLDAC();
    DAC_I_INDEX = ( DAC_I_INDEX + STEP_SIZE) % TABLE_SIZE;
    TIMER1_ICR_R = TIMER_ICR_TATOCINT;                                         // clear interrupt flag
}

void DAC_Q_Isr(void)
{
    writeSpi(1, ConvertedSineLUT[DAC_Q_INDEX][1]);
    pulseLDAC();
    DAC_Q_INDEX = ( DAC_Q_INDEX + STEP_SIZE) % TABLE_SIZE;
    TIMER2_ICR_R = TIMER_ICR_TATOCINT;                                         // clear interrupt flag
}

void MOD_OUTPUT(void)
{
    if (PREAMBLE_MARK)
    {
        switch (MOD_STATE)
        {
            case 1: // BPSK - 1 bit per symbol
                CAPTURED_SYMBOL = (BITSTREAM >> GRABBED_BITS) & 0x1; // shifted bistream & 0001
                i = BPSK_ARRAY[CAPTURED_SYMBOL][0];
                q = BPSK_ARRAY[CAPTURED_SYMBOL][1];
                GRABBED_BITS = GRABBED_BITS + 1;
                break;

            case 2: // QPSK - 2 bits per symbol
                CAPTURED_SYMBOL = (BITSTREAM >> GRABBED_BITS) & 0x3; // 0011
                i = QPSK_ARRAY[CAPTURED_SYMBOL][0];
                q = QPSK_ARRAY[CAPTURED_SYMBOL][1];
                GRABBED_BITS = GRABBED_BITS + 2;
                break;

            case 3: // 8-PSK - 3 bits per symbol
                CAPTURED_SYMBOL = (BITSTREAM >> GRABBED_BITS) & 0x7; // 0111
                i = OCTO_PSK_ARRAY[CAPTURED_SYMBOL][0];
                q = OCTO_PSK_ARRAY[CAPTURED_SYMBOL][1];
                GRABBED_BITS = GRABBED_BITS + 3;
                break;

            case 4: // 16-QAM - 4 bits per symbol
                CAPTURED_SYMBOL = (BITSTREAM >> GRABBED_BITS) & 0xF; // 1111
                i = HEX_QAM_ARRAY[CAPTURED_SYMBOL][0];
                q = HEX_QAM_ARRAY[CAPTURED_SYMBOL][1];
                GRABBED_BITS = GRABBED_BITS + 4;
                break;

            case 5: // Turn Off Mod & leave function
                Disable_MOD_Isr();
                GRABBED_BITS = 0;
                break;

            default: // Failed/Rejected Mod value
                return;
        }
    }
    else
    {
        switch (MOD_STATE)
        {
            case 1: // BPSK - 1 bit per symbol
                CAPTURED_SYMBOL = (PREAMBLE_BPSK >> GRABBED_BITS) & 0x1; // shifted bistream & 0001
                i = BPSK_ARRAY[CAPTURED_SYMBOL][0];
                q = BPSK_ARRAY[CAPTURED_SYMBOL][1];
                GRABBED_BITS = GRABBED_BITS + 1;
                break;

            case 2: // QPSK - 2 bits per symbol
                CAPTURED_SYMBOL = (PREAMBLE_QPSK >> GRABBED_BITS) & 0x3; // 0011
                i = QPSK_ARRAY[CAPTURED_SYMBOL][0];
                q = QPSK_ARRAY[CAPTURED_SYMBOL][1];
                GRABBED_BITS = GRABBED_BITS + 2;
                break;

            case 3: // 8-PSK - 3 bits per symbol
                CAPTURED_SYMBOL = (PREAMBLE_8PSK >> GRABBED_BITS) & 0x7; // 0111
                i = OCTO_PSK_ARRAY[CAPTURED_SYMBOL][0];
                q = OCTO_PSK_ARRAY[CAPTURED_SYMBOL][1];
                GRABBED_BITS = GRABBED_BITS + 3;
                break;

            case 4: // 16-QAM - 4 bits per symbol
                CAPTURED_SYMBOL = (PREAMBLE_16QAM >> GRABBED_BITS) & 0xF; // 1111
                i = HEX_QAM_ARRAY[CAPTURED_SYMBOL][0];
                q = HEX_QAM_ARRAY[CAPTURED_SYMBOL][1];
                GRABBED_BITS = GRABBED_BITS + 4;
                break;

            case 5: // Turn Off Mod & leave function
                Disable_MOD_Isr();
                GRABBED_BITS = 0;
                break;

            default: // Failed/Rejected Mod value
                return;
        }
        if (GRABBED_BITS >=  32)
        PREAMBLE_MARK = 1;
    }
}

void MOD_Isr(void)
{
    if (RRC_ENABLED)
    {
        counter++;
        if (counter >= 4)
        {
            counter = 0;
            MOD_OUTPUT();
        }
        else
        {
            i = 0;
            q = 0;
        }
        // Increment location of the newest value for buffer
        buff_newest = (buff_newest + 1) % BUFFER_SIZE;

        // Place i and q into the Complex Array
        Complex_Buffer[buff_newest][0] = i;
        Complex_Buffer[buff_newest][1] = q;

        // Reset Convolution Variables
        float i_convolved = 0;
        float q_convolved = 0;
        uint16_t index_location = (buff_newest + BUFFER_SIZE -counter) % BUFFER_SIZE;

        // Apply convolution - based on symbol locations
        for (j = counter; j < 31; j = j + 4)
        {
            i_convolved += RRC_Filter[j] * Complex_Buffer[index_location][0];
            q_convolved += RRC_Filter[j] * Complex_Buffer[index_location][1];
            index_location = (index_location + BUFFER_SIZE - 4) % BUFFER_SIZE;
        }

   //  Possible locations for symbols w/ zeros - 8 max
   //  x000 x000 x000 x000 x000 x000 x000 x00
   //  0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x0
   //  00x0 00x0 00x0 00x0 00x0 00x0 00x0 00x
   //  000x 000x 000x 000x 000x 000x 000x 000

        // Convert Y (Convolution Result) for DAC
        i = i_convolved * 4;
        q = q_convolved * 4;

        if (i < DAC_I_MAX)
            i = DAC_I_MAX;
        else if (i > DAC_I_MIN)
            i = DAC_I_MIN;
        if (q < DAC_Q_MAX)
           q = DAC_Q_MAX;
       else if (q > DAC_Q_MIN)
           q = DAC_Q_MIN;

    }
    else
        MOD_OUTPUT();

    // shuffle bitsream when limit reached - might not be needed, TESTING 0-16 HEX VALUES
    if (GRABBED_BITS >= 64)
    {
        //uint32_t temp_bitstream = TIMER3_TAV_R;
        //BITSTREAM = BITSTREAM ^ BITSTREAM>>3 ^ BITSTREAM<<20 ^ temp_bitstream<<5 ^ temp_bitstream<<15;
        GRABBED_BITS = 0;
    }

    // output 'pre-randomized' test i and q values
    writeSpi(0, i);
    pulseLDAC();
    writeSpi(1, q);
    pulseLDAC();

    TIMER3_ICR_R = TIMER_ICR_TATOCINT; // clear interrupt flag
}

void DUAL_DAC_Isr(void)
{
    // Output these positions - (0-sine, 1-cos)
    writeSpi(0, ConvertedSineLUT[DAC_I_INDEX][0]);
    writeSpi(1, ConvertedSineLUT[DAC_Q_INDEX][1]);
    pulseLDAC();

    // Calculate both DACs next index value
    DAC_I_INDEX = ( DAC_I_INDEX + STEP_SIZE) % TABLE_SIZE;
    DAC_Q_INDEX = ( DAC_Q_INDEX + STEP_SIZE) % TABLE_SIZE;

    // clear interrupt flag
    TIMER4_ICR_R = TIMER_ICR_TATOCINT;              
}

// Modulation Setting Function
void ModOutput(uint8_t MOD)
{
    if (DAC_I_ENABLED || DAC_Q_ENABLED)
    {
        disable_DAC_I_output();
        disable_DAC_Q_output();
        DAC_I_ENABLED = false;
        DAC_Q_ENABLED = false;
    }
    if (MOD == 5)
        Disable_MOD_Isr();
    else
    {
        MOD_STATE = MOD;
        Disable_MOD_Isr();
        if (!PREAMBLE_ENABLE)
            PREAMBLE_MARK = 1;
        Enable_MOD_Isr();
    }
}

// Command Parsing Function 
void cmd_manager(uint16_t CMD_STATE, float INPUT_VAL_1, float INPUT_VAL_2)
{
    // Current list:
    // - dac i 0-4096
    // - dac q 0-4096
    // - sine i/q [AMPLITUDE] [FREQUENCY] 
    // - cos i/q [AMPLITUDE] [FREQUENCY] 
    // - dac dual [AMPLITUDE] [FREQUENCY]
    // - stop i/q
    // - mod bspk|qpsk|8psk|16qam
    // - filter rrc|off
    // - preamble on|off

    if (CMD_STATE == 1 || CMD_STATE == 2 || CMD_STATE == 3 || CMD_STATE == 4 || CMD_STATE == 8)
        Disable_MOD_Isr();

    switch (CMD_STATE)
    {
        case 1: // dac i 0-4096
            writeSpi(0,(int)INPUT_VAL_1);
            pulseLDAC();
            break;
        case 2: // dac q 0-4096
            writeSpi(1,(int)INPUT_VAL_1);
            pulseLDAC();
            break;
        case 3: // sine i/q [AMPLITUDE] [FREQUENCY] 
            if (string_cmp(getFieldString(&data, 1), "i"))
                Enable_DAC_I(0, INPUT_VAL_1, INPUT_VAL_2);
            else if (string_cmp(getFieldString(&data, 1), "q"))
                Enable_DAC_Q(0, INPUT_VAL_1, INPUT_VAL_2);
            else
                putsUart0("\n --> Invalid Command\n\n");
            break;
        case 4: // cos i/q [AMPLITUDE] [FREQUENCY] 
            if (string_cmp(getFieldString(&data, 1), "i"))
                Enable_DAC_I(1, INPUT_VAL_1, INPUT_VAL_2);
            else if (string_cmp(getFieldString(&data, 1), "q"))
                Enable_DAC_Q(1, INPUT_VAL_1, INPUT_VAL_2);
            else
                putsUart0("\n --> Invalid Command\n\n");
            break;
        case 5: // stop i/q
            if (string_cmp(getFieldString(&data, 1), "i"))
                disable_DAC_I_output();
            else if (string_cmp(getFieldString(&data, 1), "q"))
                disable_DAC_Q_output();
            break;
        case 6: // mod bpsk|qpsk|8psk|16qam|off
            if (string_cmp(getFieldString(&data, 1), "bpsk"))
                ModOutput(1);
            else if (string_cmp(getFieldString(&data, 1), "qpsk"))
                ModOutput(2);
            else if (string_cmp(getFieldString(&data, 1), "8psk"))
                ModOutput(3);
            else if (string_cmp(getFieldString(&data, 1), "16qam"))
                ModOutput(4);
            else if (string_cmp(getFieldString(&data, 1), "off"))
                ModOutput(5);
            break;
        case 7: // symbols [COUNT]
            SYMBOLS = INPUT_VAL_1;
            ModOutput(5);
        case 8: // dac dual [AMPLITUDE] [FREQUENCY]
            disable_DAC_I_output();
            disable_DAC_Q_output();
            Enable_DUAL_DAC_Isr(INPUT_VAL_1, INPUT_VAL_2);
            break;
        case 9:
            if (string_cmp(getFieldString(&data, 1), "rrc"))
            {
                RRC_ENABLED = true;
                Disable_MOD_Isr();
                Enable_MOD_Isr();
            }
            else if (string_cmp(getFieldString(&data, 1), "off"))
            {
                RRC_ENABLED = false;
                Disable_MOD_Isr();
                Enable_MOD_Isr();
            }
            break;
        case 10:
            putsUart0("Help Menu:\n");
            putsUart0("  to change dac values manually:\n");
            putsUart0("    dac i [0-4096]\n");
            putsUart0("    dac q [0-4096]\n\n");
            putsUart0("  For Cosine & Sine outputs:\n");
            putsUart0("    sine i/q [AMPLITUDE] [FREQUENCY]\n");
            putsUart0("    cos  i/q [AMPLITUDE] [FREQUENCY]\n");
            putsUart0("  For both DAC outputs:\n");
            putsUart0("    dac dual [AMPLITUDE] [FREQUENCY]\n");
            putsUart0("    where:\n\tAMPLITUDE = 0-0.5\n\tFREQUENCY = 0-1000000\n\n");
            putsUart0("  to stop any generating dacs:\n");
            putsUart0("    stop i\n");
            putsUart0("    stop q\n\n");
            putsUart0("  to set mod variants:\n");
            putsUart0("    mod bpsk|qpsk|8psk|16qam|off\n");
            putsUart0("  to set symbol rate:\n");
            putsUart0("    symbols [COUNT] (default 1)\n");
            putsUart0("  to change filtering:\n");
            putsUart0("    filter rrc/off\n");
            putsUart0("  to set preamble:\n");
            putsUart0("    preamble on/off\n");
            break;
        default:
            putsUart0("\n --> Invalid Command\n\n");
    }
}

// Initialize Hardware
void initHw()
{
    // Initialize system clock to 40 MHz
    initSystemClockTo40Mhz();

    // Enable timers
    SYSCTL_RCGCTIMER_R |= SYSCTL_RCGCTIMER_R1 | SYSCTL_RCGCTIMER_R2 | SYSCTL_RCGCTIMER_R3 | SYSCTL_RCGCTIMER_R4;
    _delay_cycles(3);

    // Enable clocks
    enablePort(PORTF);
    enablePort(PORTE);

    // Configure on-board LED
    selectPinPushPullOutput(GREEN_LED);
    selectPinPushPullOutput(RED_LED);

    setPinValue(GREEN_LED, 0);
    setPinValue(RED_LED, 1);
    selectPinPushPullOutput(LDAC);

    // Configure SPI1
    initSpi1(1);
    setSpi1BaudRate(20e6, 40e6);
    setSpi1Mode(1, 1);
}

//-----------------------------------------------------------------------------
// Main
//-----------------------------------------------------------------------------

int main(void)
{
    // Initialize hardware
    initHw();
    initUart0();
    setUart0BaudRate(19200, 40e6);

    writeSpi(0, (DAC_I_MIN+DAC_I_MAX)/2);
    writeSpi(1, (DAC_Q_MIN+DAC_Q_MAX)/2);
    pulseLDAC();

    DAC_I_CENTER = (DAC_I_MIN+DAC_I_MAX)/2;
    DAC_Q_CENTER = (DAC_Q_MIN+DAC_Q_MAX)/2;
    DAC_I_DIFF   = DAC_I_MIN - DAC_I_CENTER;
    DAC_Q_DIFF   = DAC_Q_MIN - DAC_Q_CENTER;
    dac_i_max  = DAC_I_MAX;
    dac_q_max  = DAC_Q_MAX;
    dac_i_zero = DAC_I_CENTER;
    dac_q_zero = DAC_Q_CENTER;
    dac_i_min  = DAC_I_MIN;
    dac_q_min  = DAC_Q_MIN;
    dac_i_pos_square = DAC_I_CENTER - (uint16_t)(.707 * (DAC_I_CENTER-DAC_I_MAX));
    dac_i_neg_square = DAC_I_CENTER + (uint16_t)(.707 * (DAC_I_MIN-DAC_I_CENTER));
    dac_q_pos_square = DAC_Q_CENTER - (uint16_t)(.707 * (DAC_Q_CENTER-DAC_Q_MAX));
    dac_q_neg_square = DAC_Q_CENTER + (uint16_t)(.707 * (DAC_Q_MIN-DAC_Q_CENTER));
    dac_i_pos_third  = DAC_I_CENTER - (DAC_I_CENTER-DAC_I_MAX)/3;
    dac_i_neg_third  = DAC_I_CENTER + (DAC_I_MIN-DAC_I_CENTER)/3;
    dac_q_pos_third  = DAC_Q_CENTER - (DAC_Q_CENTER-DAC_Q_MAX)/3;
    dac_q_neg_third  = DAC_Q_CENTER + (DAC_Q_MIN-DAC_Q_CENTER)/3;

    BPSK_ARRAY[0][0] = dac_i_max; BPSK_ARRAY[0][1] = dac_q_zero;
    BPSK_ARRAY[1][0] = dac_i_min; BPSK_ARRAY[1][1] = dac_q_zero;

    QPSK_ARRAY[0][0] = dac_i_max; QPSK_ARRAY[0][1] = dac_q_max;
    QPSK_ARRAY[1][0] = dac_i_min; QPSK_ARRAY[1][1] = dac_q_max;
    QPSK_ARRAY[2][0] = dac_i_min; QPSK_ARRAY[2][1] = dac_q_min;
    QPSK_ARRAY[3][0] = dac_i_max; QPSK_ARRAY[3][1] = dac_q_min;

    OCTO_PSK_ARRAY[0][0] = dac_i_max;        OCTO_PSK_ARRAY[0][1] = dac_q_zero;
    OCTO_PSK_ARRAY[1][0] = dac_i_pos_square; OCTO_PSK_ARRAY[1][1] = dac_q_pos_square;
    OCTO_PSK_ARRAY[2][0] = dac_i_zero;       OCTO_PSK_ARRAY[2][1] = dac_q_max;
    OCTO_PSK_ARRAY[3][0] = dac_i_neg_square; OCTO_PSK_ARRAY[3][1] = dac_q_pos_square;
    OCTO_PSK_ARRAY[4][0] = dac_i_min;        OCTO_PSK_ARRAY[4][1] = dac_q_zero;
    OCTO_PSK_ARRAY[5][0] = dac_i_neg_square; OCTO_PSK_ARRAY[5][1] = dac_q_neg_square;
    OCTO_PSK_ARRAY[6][0] = dac_i_zero;       OCTO_PSK_ARRAY[6][1] = dac_q_min;
    OCTO_PSK_ARRAY[7][0] = dac_i_pos_square; OCTO_PSK_ARRAY[7][1] = dac_q_neg_square;

    HEX_QAM_ARRAY[0][0]  = dac_i_min;       HEX_QAM_ARRAY[0][1]  = dac_q_max;
    HEX_QAM_ARRAY[1][0]  = dac_i_neg_third; HEX_QAM_ARRAY[1][1]  = dac_q_max;
    HEX_QAM_ARRAY[2][0]  = dac_i_pos_third; HEX_QAM_ARRAY[2][1]  = dac_q_max;
    HEX_QAM_ARRAY[3][0]  = dac_i_max;       HEX_QAM_ARRAY[3][1]  = dac_q_max;
    HEX_QAM_ARRAY[4][0]  = dac_i_min;       HEX_QAM_ARRAY[4][1]  = dac_q_pos_third;
    HEX_QAM_ARRAY[5][0]  = dac_i_neg_third; HEX_QAM_ARRAY[5][1]  = dac_q_pos_third;
    HEX_QAM_ARRAY[6][0]  = dac_i_pos_third; HEX_QAM_ARRAY[6][1]  = dac_q_pos_third;
    HEX_QAM_ARRAY[7][0]  = dac_i_max;       HEX_QAM_ARRAY[7][1]  = dac_q_pos_third;
    HEX_QAM_ARRAY[8][0]  = dac_i_min;       HEX_QAM_ARRAY[8][1]  = dac_q_neg_third;
    HEX_QAM_ARRAY[9][0]  = dac_i_neg_third; HEX_QAM_ARRAY[9][1]  = dac_q_neg_third;
    HEX_QAM_ARRAY[10][0] = dac_i_pos_third; HEX_QAM_ARRAY[10][1] = dac_q_neg_third;
    HEX_QAM_ARRAY[11][0] = dac_i_max;       HEX_QAM_ARRAY[11][1] = dac_q_neg_third;
    HEX_QAM_ARRAY[12][0] = dac_i_min;       HEX_QAM_ARRAY[12][1] = dac_q_min;
    HEX_QAM_ARRAY[13][0] = dac_i_neg_third; HEX_QAM_ARRAY[13][1] = dac_q_min;
    HEX_QAM_ARRAY[14][0] = dac_i_pos_third; HEX_QAM_ARRAY[14][1] = dac_q_min;
    HEX_QAM_ARRAY[15][0] = dac_i_max;       HEX_QAM_ARRAY[15][1] = dac_q_min;

    // Switch LED to green to provide initialize complete feedback
    setPinValue(GREEN_LED, 1);
    setPinValue(RED_LED, 0);

    // Loads Sine LUT
    LOAD_SINE_LUT();

    // Used for 0.5+j0 - dc output
    //cmd_manager(1, 4096, 0);
    //cmd_manager(2, 4096, 0);

    // Cos & Sine output
    //cmd_manager(8, 0.5, 2000);
    // -995.5 de rotated after cos/sine output -slightly off

    // QPSK output w/ preamble
    PREAMBLE_ENABLE = 1;
    cmd_manager(7, 8000, 0);
    ModOutput(2);

    putsUart0("\n\n-------Lab 1: Modulation-----\n"); 
    while(true)
    {
        // Waits to receive and parse user input
        putsUart0("\r\nEnter cmd: ");
        getsUart0(&data);
        parseFields(&data);
        float int0 = getFieldFloat(&data, 1);
        float int1 = getFieldFloat(&data, 2);
        float int2 = getFieldInteger(&data, 3) * 2;

        // CMD list - Explaination in cmd_manager
        if (isCommand(&data, "dac", "i", 3))
        {
            if ((int1 >= 0 && int1 <= 4096))
                input_cmd = 1;
        }
        else if (isCommand(&data, "dac", "q", 3))
        {
            if ((int1 >= 0 && int1 <= 4096))
               input_cmd = 2;
        }
        else if (isCommand(&data, "sine", "", 4))
        {
            if (int1 >= 0 && int1 <= 0.5 && int2 >= 0 && int2 <= 1000000)
                input_cmd = 3;
        }
        else if (isCommand(&data, "cos", "", 4))
        {
            if (int1 >= 0 && int1 <= 0.5 && int2 >= 0 && int2 <= 1000000)
                input_cmd = 4;
        }
        else if ((isCommand(&data, "stop", "i", 2)) || (isCommand(&data, "stop", "q", 2)))
            input_cmd = 5;
        else if ((isCommand(&data, "mod", "bpsk", 2)) || (isCommand(&data, "mod", "qpsk", 2)) || (isCommand(&data, "mod", "8psk", 2)) || (isCommand(&data, "mod", "16qam", 2)) || (isCommand(&data, "mod", "off", 2)))
            input_cmd = 6;
        else if (isCommand(&data, "symbols", "", 2) && int0 >= 1)
        {
            input_cmd = 7;
            int1 = int0;
        }
        else if (isCommand(&data, "dac", "dual", 4))
        {
            if (int1 >= 0 && int1 <= 1.0 && int2 >= 0 && int2 <= 1000000)
                input_cmd = 8;
        }
        else if  (isCommand(&data, "filter", "", 2))
            input_cmd = 9;
        else if (isCommand(&data, "help", "", 1))
            input_cmd = 10;
        else if (isCommand(&data, "preamble", "on", 2))
            PREAMBLE_ENABLE = 1;
        else if (isCommand(&data, "preamble", "off", 2))
            PREAMBLE_ENABLE = 0;
        else
            input_cmd = 0;

        cmd_manager(input_cmd, int1, int2);
    }
}
