/*
 * timer1.c
 *
 *  Created on: Apr 11, 2022
 *      Author: Dario Ugalde
 */

#include "nvic.h"
#include "tm4c123gh6pm.h"
#include "timer1.h"

void initTimer1()
{
    SYSCTL_RCGCTIMER_R |= SYSCTL_RCGCTIMER_R1;
    _delay_cycles(3);

    TIMER1_CTL_R &= ~TIMER_CTL_TAEN;                 // turn-off timer before reconfiguring
    TIMER1_CFG_R = TIMER_CFG_32_BIT_TIMER;           // configure as 32-bit timer (A+B)
    TIMER1_TAMR_R = TIMER_TAMR_TAMR_PERIOD;          // configure for one-shot mode (count down)
    TIMER1_TAILR_R = 0x500;                         // set load value to 2048 to interrupt every 20us
    TIMER1_IMR_R = TIMER_IMR_TATOIM;                 // turn-on interrupts
    enableNvicInterrupt(INT_TIMER1A);                // turn-on interrupt 37 (TIMER1A)
}

void startTimer1()
{
    TIMER1_CTL_R |= TIMER_CTL_TAEN;
}

void stopTimer1()
{
    TIMER1_CTL_R &= ~TIMER_CTL_TAEN;
}
