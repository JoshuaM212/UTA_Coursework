// RGB LED Library
// Jason Losh

//-----------------------------------------------------------------------------
// Hardware Target
//-----------------------------------------------------------------------------

// Target Platform: EK-TM4C123GXL with LCD Interface
// Target uC:       TM4C123GH6PM
// System Clock:    40 MHz

// Hardware configuration:
// Red Backlight LED:
//   M1PWM5 (PF1) drives an NPN transistor that powers the red LED
// Green Backlight LED:
//   M1PWM7 (PF3) drives an NPN transistor that powers the green LED
// Blue Backlight LED:
//   M1PWM6 (PF2) drives an NPN transistor that powers the blue LED

//-----------------------------------------------------------------------------
// Device includes, defines, and assembler directives
//-----------------------------------------------------------------------------

#include <motor_control.h>
#include <stdint.h>
#include "tm4c123gh6pm.h"

// PortD masks
#define COIL_A_MASK 1  // PD0
#define COIL_B_MASK 2   // PD1

//-----------------------------------------------------------------------------
// Global variables
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// Subroutines
//-----------------------------------------------------------------------------

// Initialize RGB
void initPwm()
{
    // Enable clocks
    SYSCTL_RCGCPWM_R |= SYSCTL_RCGCPWM_R1; // Turns on PWM mod. 1
    SYSCTL_RCGCGPIO_R |= SYSCTL_RCGCGPIO_R3 ; // Ports D enable
    _delay_cycles(3);

    //Configure Motor Pins
    GPIO_PORTD_DIR_R |= COIL_A_MASK | COIL_B_MASK;
    GPIO_PORTD_DEN_R |= COIL_A_MASK | COIL_B_MASK;
    GPIO_PORTD_AFSEL_R |= COIL_A_MASK | COIL_B_MASK;
    GPIO_PORTD_PCTL_R &= ~(GPIO_PCTL_PD0_M | GPIO_PCTL_PD1_M);
    GPIO_PORTD_PCTL_R |= GPIO_PCTL_PD0_M1PWM0 | GPIO_PCTL_PD1_M1PWM1;

    // Configure PWM modulE
    SYSCTL_SRPWM_R |= SYSCTL_SRPWM_R1;               // reset PWM1 module
    SYSCTL_SRPWM_R &= ~SYSCTL_SRPWM_R1;              // leave reset state
    _delay_cycles(3);                                // wait 3 clocks
    PWM1_0_CTL_R = 0;                                // turn-off PWM1 generator 0
    PWM1_0_GENA_R = PWM_1_GENA_ACTCMPAD_ONE | PWM_1_GENA_ACTLOAD_ZERO;
    PWM1_0_GENB_R = PWM_1_GENB_ACTCMPBD_ONE | PWM_1_GENB_ACTLOAD_ZERO;
    PWM1_0_LOAD_R = 1024;                            // set period to 40 MHz sys clock / 2 / 1024 = 19.53125 kHz
    PWM1_0_CMPA_R = 0;                               // PWM off (0=always low, 1023=always high)
    PWM1_0_CMPB_R = 0;                               // PWM off (0=always low, 1023=always high)
    PWM1_0_CTL_R = PWM_1_CTL_ENABLE;                 // turn-on PWM1 generator 0
    PWM1_ENABLE_R = PWM_ENABLE_PWM0EN | PWM_ENABLE_PWM1EN;               // enable PWM output

    }

void setPwm(uint16_t COIL_A, uint16_t COIL_B)
{
    PWM1_0_CMPA_R = COIL_A;
    PWM1_0_CMPB_R = COIL_B;
}

