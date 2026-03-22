// NVIC Library
// Jason Losh

//-----------------------------------------------------------------------------
// Hardware Target
//-----------------------------------------------------------------------------

// Target Platform: EK-TM4C123GXL
// Target uC:       TM4C123GH6PM
// System Clock:    -

// Hardware configuration: -

//-----------------------------------------------------------------------------
// Device includes, defines, and assembler directives
//-----------------------------------------------------------------------------

#include "nvic.h"
#include "tm4c123gh6pm.h"

//-----------------------------------------------------------------------------
// Global variables
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// Subroutines
//-----------------------------------------------------------------------------

void enableNvicInterrupt(uint8_t vectorNumber)
{
    volatile uint32_t* p = (uint32_t*) &NVIC_EN0_R;
    vectorNumber -= 16;
    p += vectorNumber / 32;
    *p = 1 << (vectorNumber % 32);
}

void disableNvicInterrupt(uint8_t vectorNumber)
{
    volatile uint32_t* p = (uint32_t*) &NVIC_DIS0_R;
    vectorNumber -= 16;
    p += vectorNumber / 32;
    *p = 1 << (vectorNumber % 32);
}

void setNvicInterruptPriority(uint8_t vectorNumber, uint8_t priority)
{
    volatile uint32_t* p = (uint32_t*) &NVIC_PRI0_R;
    vectorNumber -= 16;
    p += vectorNumber / 4;
    *p &= ~(15 << (vectorNumber % 4));
    *p |= priority << (vectorNumber % 4);
}

