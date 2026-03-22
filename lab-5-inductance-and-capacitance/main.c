// Frequency Counter / Timer Example
// Jason Losh

//-----------------------------------------------------------------------------
// Hardware Target
//-----------------------------------------------------------------------------

// Target Platform: EK-TM4C123GXL
// Target uC:       TM4C123GH6PM
// System Clock:    40 MHz
// Stack:           4096 bytes (needed for snprintf)

// Hardware configuration:
// Green LED:
//   PF3 drives an NPN transistor that powers the green LED
// Blue LED:
//   PF2 drives an NPN transistor that powers the blue LED
// Pushbutton:
//   SW1 pulls pin PF4 low (internal pull-up is used)
// UART Interface:
//   U0TX (PA1) and U0RX (PA0) are connected to the 2nd controller
//   The USB on the 2nd controller enumerates to an ICDI interface and a virtual COM port
//   Configured to 115,200 baud, 8N1
// Frequency counter and timer input:
//   SIGNAL_IN on PC6 (WT1CCP0)

//-----------------------------------------------------------------------------
// Device includes, defines, and assembler directives
//-----------------------------------------------------------------------------

#include <inttypes.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include "clock.h"
#include "wait.h"
#include "uart0.h"
#include "tm4c123gh6pm.h"

#define Comp_Out     (*((volatile uint32_t *)(0x42000000 + (0x400253FC-0x40000000)*32 + 0*4)))
#define RED_LED      (*((volatile uint32_t *)(0x42000000 + (0x400253FC-0x40000000)*32 + 1*4)))
#define BLUE_LED     (*((volatile uint32_t *)(0x42000000 + (0x400253FC-0x40000000)*32 + 2*4)))
#define GREEN_LED    (*((volatile uint32_t *)(0x42000000 + (0x400253FC-0x40000000)*32 + 3*4)))
#define PUSH_BUTTON  (*((volatile uint32_t *)(0x42000000 + (0x400253FC-0x40000000)*32 + 4*4)))
#define Reset_Pin    (*((volatile uint32_t *)(0x42000000 + (0x400043FC-0x40000000)*32 + 5*4)))
#define Comp_Pos     (*((volatile uint32_t *)(0x42000000 + (0x400063FC-0x40000000)*32 + 5*4)))
#define Comp_Neg     (*((volatile uint32_t *)(0x42000000 + (0x400063FC-0x40000000)*32 + 4*4)))

// PortA masks
#define Reset_Pin_Mask 32 // PA5

// PortC masks
#define Comp_Neg_Mask 16 // PC4
#define Comp_Pos_Mask 32 // PC5
#define FREQ_IN_MASK  64 // PC6

// PortF masks
#define Comp_Out_Mask    2
//#define RED_LED_MASK     2
#define BLUE_LED_MASK    4
#define GREEN_LED_MASK   8
#define PUSH_BUTTON_MASK 16

//-----------------------------------------------------------------------------
// Global variables
//-----------------------------------------------------------------------------

bool timeMode = false;
uint32_t frequency = 0;
uint32_t time = 0;

float Comp_Time = 0;
float Comp_Result = 0;

//-----------------------------------------------------------------------------
// Subroutines
//-----------------------------------------------------------------------------

void enableCounterMode()
{
    // Configure Timer 1 as the time base
    TIMER1_CTL_R &= ~TIMER_CTL_TAEN;                 // turn-off timer before reconfiguring
    TIMER1_CFG_R = TIMER_CFG_32_BIT_TIMER;           // configure as 32-bit timer (A+B)
    TIMER1_TAMR_R = TIMER_TAMR_TAMR_PERIOD;          // configure for periodic mode (count down)
    TIMER1_TAILR_R = 40000000;                       // set load value to 40e6 for 1 Hz interrupt rate
    TIMER1_IMR_R = TIMER_IMR_TATOIM;                 // turn-on interrupts
    TIMER1_CTL_R |= TIMER_CTL_TAEN;                  // turn-on timer
    NVIC_EN0_R = 1 << (INT_TIMER1A-16);              // turn-on interrupt 37 (TIMER1A)

    // Configure Wide Timer 1 as counter of external events on CCP0 pin
    WTIMER1_CTL_R &= ~TIMER_CTL_TAEN;                // turn-off counter before reconfiguring
    WTIMER1_CFG_R = 4;                               // configure as 32-bit counter (A only)
    WTIMER1_TAMR_R = TIMER_TAMR_TAMR_CAP | TIMER_TAMR_TACDIR; // configure for edge count mode, count up
    WTIMER1_CTL_R = TIMER_CTL_TAEVENT_POS;           // count positive edges
    WTIMER1_IMR_R = 0;                               // turn-off interrupts
    WTIMER1_TAV_R = 0;                               // zero counter for first period
    WTIMER1_CTL_R |= TIMER_CTL_TAEN;                 // turn-on counter
}

void disableCounterMode()
{
    TIMER1_CTL_R &= ~TIMER_CTL_TAEN;                 // turn-off time base timer
    WTIMER1_CTL_R &= ~TIMER_CTL_TAEN;                // turn-off event counter
    NVIC_DIS0_R = 1 << (INT_TIMER1A-16);             // turn-off interrupt 37 (TIMER1A)
}

void enableTimerMode()
{
    WTIMER1_CTL_R &= ~TIMER_CTL_TAEN;                // turn-off counter before reconfiguring
    WTIMER1_CFG_R = 4;                               // configure as 32-bit counter (A only)
    WTIMER1_TAMR_R = TIMER_TAMR_TACMR | TIMER_TAMR_TAMR_CAP | TIMER_TAMR_TACDIR;
                                                     // configure for edge time mode, count up
    WTIMER1_CTL_R = TIMER_CTL_TAEVENT_POS;           // measure time from positive edge to positive edge
    WTIMER1_IMR_R = TIMER_IMR_CAEIM;                 // turn-on interrupts
    WTIMER1_TAV_R = 0;                               // zero counter for first period
    WTIMER1_CTL_R |= TIMER_CTL_TAEN;                 // turn-on counter
    NVIC_EN3_R = 1 << (INT_WTIMER1A-16-96);          // turn-on interrupt 112 (WTIMER1A)
}

void disableTimerMode()
{
    WTIMER1_CTL_R &= ~TIMER_CTL_TAEN;                // turn-off counter
    NVIC_DIS3_R = 1 << (INT_WTIMER1A-16-96);         // turn-off interrupt 112 (WTIMER1A)
}

// Frequency counter service publishing latest frequency measurements every second
void timer1Isr()
{
    frequency = WTIMER1_TAV_R;                   // read counter input
    WTIMER1_TAV_R = 0;                           // reset counter for next period
    TIMER1_ICR_R = TIMER_ICR_TATOCINT;           // clear interrupt flag
}

// Period timer service publishing latest time measurements every positive edge
void wideTimer1Isr()
{
    time = WTIMER1_TAV_R;                        // read counter input
    WTIMER1_TAV_R = 0;                           // zero counter for next edge
    GREEN_LED ^= 1;                              // status
    WTIMER1_ICR_R = TIMER_ICR_CAECINT;           // clear interrupt flag
}

void Measure_Water_Level()
{
    Reset_Pin = 1;
    waitMicrosecond(20000);
    Reset_Pin = 0;

    WTIMER1_TAV_R = 0;
    // at zero - comp output is 1 and goes to zero once vin- is larger
    while (COMP_ACSTAT1_R) {};
    Comp_Time = WTIMER1_TAV_R;

    // Converts captured time to mL estimate
    Comp_Result = (Comp_Time*0.8146) - 412.21;
}

// Initialize Hardware
void initHw()
{
    // Initialize system clock to 40 MHz
    initSystemClockTo40Mhz();

    // Enable clocks
    SYSCTL_RCGCTIMER_R |= SYSCTL_RCGCTIMER_R1;
    SYSCTL_RCGCWTIMER_R |= SYSCTL_RCGCWTIMER_R1;
    SYSCTL_RCGCGPIO_R |= SYSCTL_RCGCGPIO_R0 | SYSCTL_RCGCGPIO_R2 | SYSCTL_RCGCGPIO_R5;
    _delay_cycles(3);

    GPIO_PORTA_DIR_R |= Reset_Pin_Mask;
    GPIO_PORTA_DEN_R |= Reset_Pin_Mask;

    // Configure LED and pushbutton pins
    GPIO_PORTF_DIR_R |= GREEN_LED_MASK | BLUE_LED_MASK;  // bits 1 and 2 are outputs, other pins are inputs
    GPIO_PORTF_DIR_R &= ~PUSH_BUTTON_MASK;               // bit 4 is an input
    GPIO_PORTF_DR2R_R |= GREEN_LED_MASK | BLUE_LED_MASK; // set drive strength to 2mA (not needed since default configuration -- for clarity)
    GPIO_PORTF_DEN_R |= PUSH_BUTTON_MASK | GREEN_LED_MASK | BLUE_LED_MASK;
                                                         // enable LEDs and pushbuttons
    GPIO_PORTF_PUR_R |= PUSH_BUTTON_MASK;                // enable internal pull-up for push button

    // Configure SIGNAL_IN for frequency and time measurements
    GPIO_PORTC_AFSEL_R |= FREQ_IN_MASK;              // select alternative functions for SIGNAL_IN pin
    GPIO_PORTC_PCTL_R &= ~GPIO_PCTL_PC6_M;           // map alt fns to SIGNAL_IN
    GPIO_PORTC_PCTL_R |= GPIO_PCTL_PC6_WT1CCP0;
    GPIO_PORTC_DEN_R |= FREQ_IN_MASK;                // enable bit 6 for digital input

    // Comparator 1 setup
    SYSCTL_RCGCACMP_R = SYSCTL_RCGCACMP_R0;

    GPIO_PORTC_DIR_R &= ~(Comp_Pos_Mask | Comp_Neg_Mask);
    GPIO_PORTC_DEN_R |= Comp_Pos_Mask | Comp_Neg_Mask;

    // Configure PF1 for Comparator Function
    GPIO_PORTF_AFSEL_R |= Comp_Out_Mask;              // select alternative functions for SIGNAL_IN pin
    GPIO_PORTF_PCTL_R &= ~GPIO_PCTL_PF1_M;           // map alt fns to SIGNAL_IN
    GPIO_PORTF_PCTL_R |= GPIO_PCTL_PF1_C1O;
    GPIO_PORTF_DEN_R |= Comp_Out_Mask;                // enable bit 6 for digital input

    COMP_ACREFCTL_R |= 0x020F; //  Ideal step size = VDDA/29.4  &   Ideal Vref = 2.469 V
    COMP_ACCTL1_R |= 0x040C;

    waitMicrosecond(10);
}
    // Unlock PF0
    // GPIO_PORTF_LOCK_R = 0x4C4F434B;
    // GPIO_PORTF_CR_R = 0x01;

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

    // Configure selected mode
    if (timeMode)
    {
        disableCounterMode();
        enableTimerMode();
    }
    else
    {
        disableTimerMode();
        enableCounterMode();
    }

    // Use blue LED to show mode
    BLUE_LED = timeMode;

    // Endless loop performing multiple tasks
    char str[40];
    while (true)
    {
        if (timeMode)
        {
            Measure_Water_Level();
            snprintf(str, sizeof(str), "Time:  %f\r\n", Comp_Time);
            putsUart0(str);
            snprintf(str, sizeof(str), "Water Level:    %f\r\n\r\n", Comp_Result);
            putsUart0(str);
        }
        else
        {
            snprintf(str, sizeof(str), "Frequency: %7"PRIu32" (Hz)\r\n", frequency);
            putsUart0(str);
            if (frequency >= 89300 && frequency <= 89500)
            {
                putsUart0("Coil Detected: ALUMINUM BOTTLE\r\n");
                BLUE_LED = 1;
            }
            else if (frequency >= 91000 && frequency <= 93000)
            {
                putsUart0("Coil Detected: SCALE\r\n");
                BLUE_LED = 1;
                GREEN_LED = 1;
            }
            else if (frequency >= 139500 && frequency <= 147500)
            {
                putsUart0("Coil Detected: STOOL\r\n");
                GREEN_LED = 1;
            }
            else
            {
                putsUart0("Coil state: IDLE\r\n");
                BLUE_LED = 0;
                GREEN_LED = 0;
            }
        }

        // debouncing not implemented until keyboard.c example
        // for now, use a delay to allow unique key presses to be detected
        if (!PUSH_BUTTON)
        {
            timeMode = !timeMode;
            BLUE_LED = timeMode;
            if (timeMode)
            {
                disableCounterMode();
                enableTimerMode();
            }
            else
            {
                disableTimerMode();
                enableCounterMode();
            }
        }
        waitMicrosecond(1000000);
    }
}







