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
// Pushbutton 1:
//   SW1 pulls pin PF4 low (internal pull-up is used) to increase PWM duty cycle 10%
// Pushbutton 2:
//   SW2 pulls pin PF4 low (internal pull-up is used) to decrease PWM duty cycle 10%
// UART Interface:
//   U0TX (PA1) and U0RX (PA0) are connected to the 2nd controller
//   The USB on the 2nd controller enumerates to an ICDI interface and a virtual COM port
//   Configured to 115,200 baud, 8N1
// Frequency counter and timer input:
//   SIGNAL_IN on PC6 (WT1CCP0)
// AIN:
//   PE4 used to read analog input voltage for back emf
// PWM Motor Control
//   PD0 used to control motor pwm duty cycle for speed

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
#include "gpio.h"
#include "uart0.h"
#include "pwm_enables.h"
#include "adc0.h"
#include "timer2.h"
#include "tm4c123gh6pm.h"

#define RED_LED      (*((volatile uint32_t *)(0x42000000 + (0x400253FC-0x40000000)*32 + 1*4)))
#define GREEN_LED    (*((volatile uint32_t *)(0x42000000 + (0x400253FC-0x40000000)*32 + 3*4)))
#define BLUE_LED     (*((volatile uint32_t *)(0x42000000 + (0x400253FC-0x40000000)*32 + 2*4)))
#define PUSH_BUTTON_1  (*((volatile uint32_t *)(0x42000000 + (0x400253FC-0x40000000)*32 + 4*4)))
#define PUSH_BUTTON_2  (*((volatile uint32_t *)(0x42000000 + (0x400253FC-0x40000000)*32 + 0*4)))
#define AIN9 PORTE,4

// PortC masks
#define FREQ_IN_MASK 64

// PortF masks
#define BLUE_LED_MASK 4
#define GREEN_LED_MASK 8
#define PUSH_BUTTON_1_MASK 16
#define PUSH_BUTTON_2_MASK 1

//-----------------------------------------------------------------------------
// Global variables
//-----------------------------------------------------------------------------

bool timeMode = false;
uint32_t frequency = 0;
uint32_t time = 0;
uint32_t rpm = 0;
uint32_t backEmf = 0;
uint32_t backEmfRpm = 0;
float dutyCycle = 512.0;
float backEmfVoltage = 0.0;
float inversebackEmf = 0.0;


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
    rpm = (frequency * 60) / 32;                 // calculate rpm value
    WTIMER1_TAV_R = 0;                           // reset counter for next period
    GREEN_LED ^= 1;                              // status
    TIMER1_ICR_R = TIMER_ICR_TATOCINT;           // clear interrupt flag
}

void timer2Isr()
{
    uint16_t tempDutyCycle = (uint16_t)dutyCycle;
    setPwmEnableA(0);
    waitMicrosecond(200);
    backEmf = readAdc0Ss3();
    inversebackEmf = (float)(((backEmf + 0.5) / 4096) * 3.3);
    backEmfVoltage = 10 - (inversebackEmf * (47 + 10) / 10);
    backEmfRpm = ((backEmfVoltage/10*3.3) * 989-209.17);
    setPwmEnableA(tempDutyCycle);
    TIMER2_ICR_R = TIMER_ICR_TATOCINT;

}

// Period timer service publishing latest time measurements every positive edge
void wideTimer1Isr()
{
    time = WTIMER1_TAV_R;                        // read counter input
    WTIMER1_TAV_R = 0;                           // zero counter for next edge
    GREEN_LED ^= 1;                              // status
    WTIMER1_ICR_R = TIMER_ICR_CAECINT;           // clear interrupt flag
}

// Initialize Hardware
void initHw()
{
    // Initialize system clock to 40 MHz
    initSystemClockTo40Mhz();

    enablePort(PORTE);

    // Enable clocks
    SYSCTL_RCGCTIMER_R |= SYSCTL_RCGCTIMER_R1;
    SYSCTL_RCGCWTIMER_R |= SYSCTL_RCGCWTIMER_R1;
    SYSCTL_RCGCGPIO_R |= SYSCTL_RCGCGPIO_R2 | SYSCTL_RCGCGPIO_R5;
    _delay_cycles(3);

    // Unlock PB2
    GPIO_PORTF_LOCK_R = 0x4C4F434B;
    GPIO_PORTF_CR_R = 0x01;


    // Configure LED and pushbutton pins
    GPIO_PORTF_DIR_R |= GREEN_LED_MASK | BLUE_LED_MASK;  // bits 1 and 2 are outputs, other pins are inputs
    GPIO_PORTF_DIR_R &= ~PUSH_BUTTON_1_MASK;               // bit 4 is an input
    GPIO_PORTF_DIR_R &= ~PUSH_BUTTON_2_MASK;
    GPIO_PORTF_DR2R_R |= GREEN_LED_MASK | BLUE_LED_MASK; // set drive strength to 2mA (not needed since default configuration -- for clarity)
    GPIO_PORTF_DEN_R |= PUSH_BUTTON_1_MASK | PUSH_BUTTON_2_MASK | GREEN_LED_MASK | BLUE_LED_MASK;
                                                         // enable LEDs and pushbuttons
    GPIO_PORTF_PUR_R |= PUSH_BUTTON_1_MASK | PUSH_BUTTON_2_MASK;                // enable internal pull-up for push buttons

    // Configure SIGNAL_IN for frequency and time measurements
    GPIO_PORTC_AFSEL_R |= FREQ_IN_MASK;              // select alternative functions for SIGNAL_IN pin
    GPIO_PORTC_PCTL_R &= ~GPIO_PCTL_PC6_M;           // map alt fns to SIGNAL_IN
    GPIO_PORTC_PCTL_R |= GPIO_PCTL_PC6_WT1CCP0;
    GPIO_PORTC_DEN_R |= FREQ_IN_MASK;                // enable bit 6 for digital input

    // Configure PWM output pins
    initPwmEnables();
    setPwmEnableA(512);
    setPwmEnableB(0);

    // Initialize analog inputs at AN8 on PE5
    initAdc0Ss3();
    selectPinAnalogInput(AIN9);

    initTimer2();
    startTimer2();
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
    uint16_t adcValue = 0;
    setAdc0Ss3Mux(0x9);

    while (true)
    {
        snprintf(str, sizeof(str), "Speed: %7"PRIu32" (RPM)\r\n", rpm);
        putsUart0(str);
        snprintf(str, sizeof(str), "Speed (Back Emf): %7"PRIu32" (RPM)\r\n", backEmfRpm);
        putsUart0(str);

        snprintf(str, sizeof(str), "Back EMF ADC Value: %7"PRIu16" (V)\r\n", backEmf);
        putsUart0(str);

        snprintf(str, sizeof(str), "Back EMF Voltage: %.1f (V)\r\n", backEmfVoltage);
        putsUart0(str);

        if (!PUSH_BUTTON_1)
        {
            dutyCycle += (1023 / 10.0);
            if (dutyCycle > 1023.0)
                dutyCycle = 1023.0;
            setPwmEnableA((uint16_t)dutyCycle);
        }
        if (!PUSH_BUTTON_2)
        {
            dutyCycle -= (1023 / 10.0);
            if (dutyCycle < 0.0)
                dutyCycle = 0.0;
            setPwmEnableA((uint16_t)dutyCycle);
        }
        snprintf(str, sizeof(str), "Current PWM Duty Cycle: %7"PRIu16" \r\n", (uint16_t)dutyCycle);
        putsUart0(str);
        waitMicrosecond(1000000);
        putsUart0("\r\n");
    }
}
