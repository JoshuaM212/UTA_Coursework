// Mech-Lab 7
// Dario Ugalde and Joshua Martinez

//-----------------------------------------------------------------------------
// Hardware Target
//-----------------------------------------------------------------------------

// Target Platform: EK-TM4C123GXL
// Target uC:       TM4C123GH6PM
// System Clock:    40 MHz
// Stack:           4096 bytes (needed for sprintf)

// Hardware configuration:
// UART Interface:
//   U0TX (PA1) and U0RX (PA0) are connected to the 2nd controller
//   The USB on the 2nd controller enumerates to an ICDI interface and a virtual COM port
//   Configured to 115,200 baud, 8N1


// Hardware configuration:
// GPIO Input:
//   PC5 - DATA
// GPIO Output:
//   PC6 - PD_CLK

//-----------------------------------------------------------------------------
// Device includes, defines, and assembler directives
//-----------------------------------------------------------------------------
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <ctype.h>
#include "tm4c123gh6pm.h"
#include "clock.h"
#include "uart0.h"
#include "wait.h"

// Bitband aliases
#define DATA        (*((volatile uint32_t *)(0x42000000 + (0x400063FC-0x40000000)*32 + 5*4)))   //PC5
#define PD_CLK      (*((volatile uint32_t *)(0x42000000 + (0x400063FC-0x40000000)*32 + 6*4)))   //PC6
#define RED_LED     (*((volatile uint32_t *)(0x42000000 + (0x400253FC-0x40000000)*32 + 1*4)))
#define GREEN_LED   (*((volatile uint32_t *)(0x42000000 + (0x400253FC-0x40000000)*32 + 3*4)))
#define PUSH_BUTTON (*((volatile uint32_t *)(0x42000000 + (0x400253FC-0x40000000)*32 + 4*4)))

// PortF masks
#define GREEN_LED_MASK 8
#define RED_LED_MASK 2
#define PUSH_BUTTON_MASK 16

// PortC masks
#define DATA_MASK   32  //PC5
#define PD_CLK_MASK 64  //PC6

char str[80];

//-----------------------------------------------------------------------------
// Subroutines
//-----------------------------------------------------------------------------

uint32_t tare_offset = 0;
float scale_factor = 0.0;
uint32_t grabbed_value = 0;
int i,j;


int32_t read_ADC()
{
    // Reads 24-bit value, and sends 1 more clk to set gain at 128
    PD_CLK = 0;
    while (DATA);
    int32_t local_grabbed_value = 0;
    uint8_t data[24] = {0};
    for (i=0;i<24;i++)
    {
        PD_CLK = 1;
        waitMicrosecond(20);
        data[i] = DATA;
        local_grabbed_value |= data[i];
        local_grabbed_value = local_grabbed_value<<1;
        PD_CLK = 0;
        waitMicrosecond(1);
    }
    PD_CLK = 1;
    waitMicrosecond(20);
    PD_CLK = 0;
    waitMicrosecond(1);

    // ADC gives values in 2's comp, following line converts
    // said value to easier to read values/conversions
   if ((local_grabbed_value>>24) == 1)
       local_grabbed_value = (local_grabbed_value^0x1FFFFFF) + 1;

    // used to keep baseline from overextending
    if (local_grabbed_value < 0)
        local_grabbed_value = 0;

    return local_grabbed_value;
}


// Function that multiplies grams by 0.00981 for Netwons
float GramstoNewtons(float value)
{
    return value * (0.00981);
}

// Function that converts value to grams via empirically derived equation
float ADCtoGrams(float value)
{
    return (value * 0.0088) -118425;
}

// Blocking function that returns only when SW1 is pressed
void waitPbPress(void)
{
	while(PUSH_BUTTON);
}

// Function that takes the average of 50 readings, used as baseline at start up
void tare()
{
    uint32_t sum = 0;
    for (j = 0; j < 10; j++)
        sum = sum + (read_ADC()/10);
    tare_offset = sum;
}

// Function to get weight in grams (Newtons)
float weight_scale()
{
    long raw_value = read_ADC() - tare_offset;
    return raw_value * scale_factor;
}


// Initialize Hardware
void initHw()
{
    // Initialize system clock to 40 MHz
    initSystemClockTo40Mhz();

    // Enable clocks
    SYSCTL_RCGCGPIO_R |= SYSCTL_RCGCGPIO_R2 | SYSCTL_RCGCGPIO_R5;  // enables port C
    _delay_cycles(3);

    // Configure pins
    GPIO_PORTC_DIR_R |= PD_CLK_MASK;  // marks port value as digital output
    GPIO_PORTC_DEN_R |= PD_CLK_MASK;

    GPIO_PORTC_DIR_R &= ~DATA_MASK;      // mark port as input
    GPIO_PORTC_DEN_R |= DATA_MASK;       // enable port

   // Configure LED and pushbutton pins
    GPIO_PORTF_DIR_R |= GREEN_LED_MASK | RED_LED_MASK;   // bits 1 and 3 are outputs, other pins are inputs
    GPIO_PORTF_DIR_R &= ~PUSH_BUTTON_MASK;               // bit 4 is an input
    GPIO_PORTF_DEN_R |= PUSH_BUTTON_MASK | GREEN_LED_MASK | RED_LED_MASK;
                                                         // enable LEDs and pushbuttons
    GPIO_PORTF_PUR_R |= PUSH_BUTTON_MASK;                // enable internal pull-up for push button
}


//-----------------------------------------------------------------------------
// Main
//-----------------------------------------------------------------------------

int main(void)
{
    // Initialize hardware
    initHw();
    initUart0();

    // Setup UART0 baud rate
    setUart0BaudRate(115200, 40e6);

    putsUart0("Strain Gauge Measurements:\r\n");

    // Turn off green LED, turn on red LED
    GREEN_LED = 0;
    RED_LED = 1;
    tare();

    sprintf(str, "Ready for PB\r\n");
    putsUart0(str);
    // Wait for PB press
    waitPbPress();

    // Turn off red LED, turn on green LED
    RED_LED = 0;
    GREEN_LED = 1;

    while (true)
    {
        // Reads value from strain gauge
       // tare();
       // int32_t cur_read_adc = read_ADC();

        tare();
        int32_t weight = tare_offset;

  /*      int32_t weight = cur_read_adc - tare_offset;
        while (weight < 0)
        {
            tare();
            cur_read_adc = read_ADC();
            weight = cur_read_adc - tare_offset;
        }
*/
        // Converts grabbed value to grams
        float ADC_to_grams = ADCtoGrams((float)weight);

        // Converts grams value to Newtons
        float grams_to_newtons = GramstoNewtons(ADC_to_grams);

        sprintf(str, "Raw ADC data: %d\r\n\n", weight);
        putsUart0(str);

        // Print both values
        sprintf(str, "Weight (grams): %.2f\r\n", ADC_to_grams - 1500);
        // sprintf(str, "ADC reading: %d\r\n", weight);
        putsUart0(str);
        sprintf(str, "Force (Newtons): %.2f\r\n\n", grams_to_newtons);
        putsUart0(str);

        if(!PUSH_BUTTON)
           tare();


    }
}
