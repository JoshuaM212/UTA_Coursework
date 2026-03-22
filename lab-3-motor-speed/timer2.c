/*
 * timer2.c
 *
 *  Created on: Apr 14, 2022
 *      Author: Dario Ugalde
 */

#include "nvic.h"
#include "tm4c123gh6pm.h"
#include "timer2.h"

void initTimer2()
{
    SYSCTL_RCGCTIMER_R |= SYSCTL_RCGCTIMER_R2;
    _delay_cycles(3);

    TIMER2_CTL_R &= ~TIMER_CTL_TAEN;                 // turn-off timer before reconfiguring
    TIMER2_CFG_R = TIMER_CFG_32_BIT_TIMER;           // configure as 32-bit timer (A+B)
    TIMER2_TAMR_R = TIMER_TAMR_TAMR_PERIOD;          // configure for one-shot mode (count down)
    TIMER2_TAILR_R = 800000;                            // set load value to 800000 to interrupt every 20ms
    TIMER2_IMR_R = TIMER_IMR_TATOIM;                 // turn-on interrupts
    enableNvicInterrupt(INT_TIMER2A);                // turn-on interrupt 39 (TIMER2A)
}

void startTimer2()
{
    TIMER2_CTL_R |= TIMER_CTL_TAEN;
}

void stopTimer2()
{
    TIMER2_CTL_R &= ~TIMER_CTL_TAEN;
}
