// UART1 Library

//-----------------------------------------------------------------------------
// Hardware Target
//-----------------------------------------------------------------------------

// Target Platform: EK-TM4C123GXL
// Target uC:       TM4C123GH6PM
// System Clock:    -

// Hardware configuration:
// UART Interface:
//   U1TX (PC5) and U1RX (PC4) are connected to the 2nd controller
//   The USB on the 2nd controller enumerates to an ICDI interface and a virtual COM port

//-----------------------------------------------------------------------------
// Device includes, defines, and assembler directives
//-----------------------------------------------------------------------------

#include <stdint.h>
#include <stdbool.h>
#include "tm4c123gh6pm.h"
#include "uart1.h"
#include "gpio.h"

// Pins
#define UART_TX PORTC,5
#define UART_RX PORTC,4

//-----------------------------------------------------------------------------
// Global variables
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// Subroutines
//-----------------------------------------------------------------------------

// Initialize UART1
void initUart1(void)
{
    // Enable clocks
    SYSCTL_RCGCUART_R |= SYSCTL_RCGCUART_R1;
    _delay_cycles(3);
    enablePort(PORTC);

    // Configure UART1 pins
    selectPinPushPullOutput(UART_TX);
    selectPinDigitalInput(UART_RX);
    setPinAuxFunction(UART_TX, GPIO_PCTL_PC5_U1TX);
    setPinAuxFunction(UART_RX, GPIO_PCTL_PC4_U1RX);

    // Configure UART1 with default baud rate
    UART1_CTL_R = 0;                                    // turn-off UART1 to allow safe programming
    UART1_CC_R = UART_CC_CS_SYSCLK;                     // use system clock (usually 40 MHz)
}

// Set baud rate as function of instruction cycle frequency
void setUart1BaudRate(uint32_t baudRate, uint32_t fcyc)
{
    uint32_t divisorTimes128 = (fcyc * 8) / baudRate;   // calculate divisor (r) in units of 1/128,
                                                        // where r = fcyc / 16 * baudRate
    UART1_CTL_R = 0;                                    // turn-off UART1 to allow safe programming
    UART1_IBRD_R = divisorTimes128 >> 7;                // set integer value to floor(r)
    UART1_FBRD_R = ((divisorTimes128 + 1) >> 1) & 63;   // set fractional value to round(fract(r)*64)
    UART1_LCRH_R = UART_LCRH_WLEN_8 | UART_LCRH_FEN;    // configure for 8N1 w/ 16-level FIFO
    UART1_CTL_R = UART_CTL_TXE | UART_CTL_RXE | UART_CTL_UARTEN;
                                                        // turn-on UART1
}

// Blocking function that writes a serial character when the UART buffer is not full
void putcUart1(char c)
{
    while (UART1_FR_R & UART_FR_TXFF);               // wait if uart1 tx fifo full
    UART1_DR_R = c;                                  // write character to fifo
}

// Blocking function that writes a string when the UART buffer is not full
void putsUart1(char* str)
{
    uint8_t i = 0;
    while (str[i] != '\0')
        putcUart1(str[i++]);
}

// Blocking function that returns with serial data once the buffer is not empty
char getcUart1(void)
{
    while (UART1_FR_R & UART_FR_RXFE);               // wait if uart1 rx fifo empty
    return UART1_DR_R & 0xFF;                        // get character from fifo
}

// Returns the status of the receive buffer
bool kbhitUart1(void)
{
    return !(UART1_FR_R & UART_FR_RXFE);
}
