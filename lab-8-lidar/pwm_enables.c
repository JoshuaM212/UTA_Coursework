// Motor Control Library
// Jason Losh

//-----------------------------------------------------------------------------
// Hardware Target
//-----------------------------------------------------------------------------

// Target Platform: EK-TM4C123GXL
// Target uC:       TM4C123GH6PM
// System Clock:    -

// Hardware configuration:
// Servo motor drive:
//   PWM output on M1PWM6 (PF2) - blue on-board LED
//   DIR output on PF3 - green on-board LED

//-----------------------------------------------------------------------------
// Device includes, defines, and assembler directives
//-----------------------------------------------------------------------------

#include <pwm_enables.h>
#include <stdint.h>
#include <stdbool.h>
#include "tm4c123gh6pm.h"
#include "gpio.h"

// Bitband aliases
#define DIRECTION    (*((volatile uint32_t *)(0x42000000 + (0x400253FC-0x40000000)*32 + 3*4)))

// PortF masks
#define PWM_A PORTD,0
#define PWM_B PORTD,1

//-----------------------------------------------------------------------------
// Subroutines
//-----------------------------------------------------------------------------

// Initialize motor control
void initPwmEnables()
{
    // Enable clocks
    SYSCTL_RCGCPWM_R |= SYSCTL_RCGCPWM_R1;
    _delay_cycles(3);
    enablePort(PORTD);

    // Configure PWM pins
    selectPinPushPullOutput(PWM_A);
    setPinAuxFunction(PWM_A, GPIO_PCTL_PD0_M1PWM0);

    selectPinPushPullOutput(PWM_B);
    setPinAuxFunction(PWM_B, GPIO_PCTL_PD1_M1PWM1);

    // PWM on M1PWM0 (PD0)
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

void setPwmEnableA(unsigned int dutyCycle)
{
    PWM1_0_CMPA_R = dutyCycle;
}

void setPwmEnableB(unsigned int dutyCycle)
{
    PWM1_0_CMPB_R = dutyCycle;
}
