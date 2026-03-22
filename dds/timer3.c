/*
 * timer3.c
 *
 *  Created on: Apr 15, 2022
 *      Author: Dario Ugalde
 */

#include "nvic.h"
#include "tm4c123gh6pm.h"
#include "timer3.h"

void initTimer3()
{
    SYSCTL_RCGCTIMER_R |= SYSCTL_RCGCTIMER_R3;
    _delay_cycles(3);

    TIMER3_CTL_R &= ~TIMER_CTL_TAEN;                 // turn-off timer before reconfiguring
    TIMER3_CFG_R = TIMER_CFG_32_BIT_TIMER;           // configure as 32-bit timer (A+B)
    TIMER3_TAMR_R = TIMER_TAMR_TAMR_PERIOD;          // configure for one-shot mode (count down)
    TIMER3_TAILR_R = 0x5;                            // set load value to 5 to interrupt every 125ns
    TIMER3_IMR_R = TIMER_IMR_TATOIM;                 // turn-on interrupts
    enableNvicInterrupt(INT_TIMER3A);                // turn-on interrupt 51 (TIMER3A)
}

void startTimer3()
{
    TIMER3_CTL_R |= TIMER_CTL_TAEN;
}

void stopTimer3()
{
    TIMER3_CTL_R &= ~TIMER_CTL_TAEN;
}





