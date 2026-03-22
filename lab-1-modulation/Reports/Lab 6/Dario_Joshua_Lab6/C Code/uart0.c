// UART0 Library
// Jason Losh

//-----------------------------------------------------------------------------
// Hardware Target
//-----------------------------------------------------------------------------

// Target Platform: EK-TM4C123GXL
// Target uC:       TM4C123GH6PM
// System Clock:    -

// Hardware configuration:
// UART Interface:
//   U0TX (PA1) and U0RX (PA0) are connected to the 2nd controller
//   The USB on the 2nd controller enumerates to an ICDI interface and a virtual COM port

//-----------------------------------------------------------------------------
// Device includes, defines, and assembler directives
//-----------------------------------------------------------------------------

#include <stdint.h>
#include <stdbool.h>
#include "tm4c123gh6pm.h"
#include "uart0.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>


// PortA masks
#define UART_TX_MASK 2
#define UART_RX_MASK 1

//-----------------------------------------------------------------------------
// Global variables
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// Subroutines
//-----------------------------------------------------------------------------

// Initialize UART0
void initUart0()
{
    // Enable clocks
    SYSCTL_RCGCUART_R |= SYSCTL_RCGCUART_R0;
    SYSCTL_RCGCGPIO_R |= SYSCTL_RCGCGPIO_R0;
    _delay_cycles(3);

    // Configure UART0 pins
    GPIO_PORTA_DEN_R |= UART_TX_MASK | UART_RX_MASK;    // enable digital on UART0 pins
    GPIO_PORTA_AFSEL_R |= UART_TX_MASK | UART_RX_MASK;  // use peripheral to drive PA0, PA1
    GPIO_PORTA_PCTL_R &= ~(GPIO_PCTL_PA1_M | GPIO_PCTL_PA0_M); // clear bits 0-7
    GPIO_PORTA_PCTL_R |= GPIO_PCTL_PA1_U0TX | GPIO_PCTL_PA0_U0RX;
                                                        // select UART0 to drive pins PA0 and PA1: default, added for clarity

    // Configure UART0 to 19200 baud (assuming fcyc = 40 MHz), 8N1 format
    UART0_CTL_R = 0;                                    // turn-off UART0 to allow safe programming
    UART0_CC_R = UART_CC_CS_SYSCLK;                     // use system clock (40 MHz)
    UART0_IBRD_R = 130;                                  // r = 40 MHz / (Nx19200Hz), set floor(r)=130, where N=13
    UART0_FBRD_R = 13;                                  // round(fract(r)*64)=13
    UART0_LCRH_R = UART_LCRH_WLEN_8 | UART_LCRH_FEN;    // configure for 8N1 w/ 16-level FIFO
    UART0_CTL_R = UART_CTL_TXE | UART_CTL_RXE | UART_CTL_UARTEN;
                                                        // enable TX, RX, and module
}

// Set baud rate as function of instruction cycle frequency
void setUart0BaudRate(uint32_t baudRate, uint32_t fcyc)
{
    uint32_t divisorTimes128 = (fcyc * 8) / baudRate;   // calculate divisor (r) in units of 1/128,
                                                        // where r = fcyc / 16 * baudRate
    divisorTimes128 += 1;                               // add 1/128 to allow rounding
    UART0_CTL_R = 0;                                    // turn-off UART0 to allow safe programming
    UART0_IBRD_R = divisorTimes128 >> 7;                // set integer value to floor(r)
    UART0_FBRD_R = ((divisorTimes128) >> 1) & 63;       // set fractional value to round(fract(r)*64)
    UART0_LCRH_R = UART_LCRH_WLEN_8 | UART_LCRH_FEN;    // configure for 8N1 w/ 16-level FIFO
    UART0_CTL_R = UART_CTL_TXE | UART_CTL_RXE | UART_CTL_UARTEN;
                                                        // turn-on UART0
}

// Blocking function that writes a serial character when the UART buffer is not full
void putcUart0(char c)
{
    while (UART0_FR_R & UART_FR_TXFF);               // wait if uart0 tx fifo full
    UART0_DR_R = c;                                  // write character to fifo
}

// Blocking function that writes a string when the UART buffer is not full
void putsUart0(char* str)
{
    uint8_t i = 0;
    while (str[i] != '\0')
        putcUart0(str[i++]);
}

// Blocking function that returns with serial data once the buffer is not empty
char getcUart0()
{
    while (UART0_FR_R & UART_FR_RXFE);               // wait if uart0 rx fifo empty
    return UART0_DR_R & 0xFF;                        // get character from fifo, masking off the flags
}

// Returns the status of the receive buffer
bool kbhitUart0()
{
    return !(UART0_FR_R & UART_FR_RXFE);
}

//-------------- ADDED CODE -------------------------------------------------------

// Receives command line prompt from user and stores into USER_DATA struct until [enter] is pressed
void getsUart0(USER_DATA* data)
{
    uint8_t count = 0, i = 0;
    while ( i < MAX_CHARS+1 )
        data->buffer[i++] = '\0';

    while(1)
    {
        char c = getcUart0();
        if ( ( c == 8 || c == 127 ) && count > 0 )
            count--;

        else if (c == 13)
        {
            data->buffer[count++] = '\0';
            return 0;
        }
        else if (c >= 32)
        {
            data->buffer[count] = c;
            count++;
            if ( count ==  MAX_CHARS )
            {
                data->buffer[count] = '\0';
                return 0;
            }
        }
    }
}

// Parses the fields of the USER_DATA struct into alphabet, numberic, or delimiter
void parseFields(USER_DATA* data)
{
    uint8_t count, m = 0;
    data->fieldCount = 0;
    while ( m < MAX_FIELDS )
    {
        data->fieldPosition[m] = '\0';
        data->fieldType[m] = '\0';
        m++;
    }

    char previous_char = '\0';

    // a = Alpha  65-90 & 97-122
    // n = Numeric 48-57 & 46 & 45
    // d = Delimiter
    for ( count = 0; count <= MAX_CHARS; count++ )
    {
        if (data->fieldCount < MAX_FIELDS)
        {
            char current_char = data->buffer[count];

            if ( (current_char >= 65 && current_char <= 90 ) || ( current_char >= 97 && current_char <= 122 ))
            {
                if (previous_char == '\0')
                {
                    data->fieldType[data->fieldCount] = 'a';
                    data->fieldPosition[data->fieldCount] = count;
                    data->fieldCount++;
                }
            }
            else if ((current_char >= 48 && current_char <= 57 ) || ( current_char == 45 ) || ( current_char == 46 ))
            {
                if (previous_char == '\0')
                {
                    data->fieldType[data->fieldCount] = 'n';
                    data->fieldPosition[data->fieldCount] = count;
                    data->fieldCount++;
                }
            }
            else
            {
                current_char = '\0';
                data->buffer[count] = '\0';
            }
            previous_char = current_char;
        }
        else
        {
            char current_char = data->buffer[count];
            current_char = '\0';
            data->buffer[count] = '\0';
        }
    }
    return 0;
}

// Returns string based on location in USER_DATA struct
char* getFieldString(USER_DATA* data, uint8_t fieldNumber)
{
    uint8_t i = data->fieldPosition[fieldNumber];
    uint8_t j = 0, m = 0;
    char get_string[20];

    while ( m < 20 )
        get_string[m++] = '\0';

    while (data->buffer[i] != '\0')
        get_string[j++] = data->buffer[i++];


    if (fieldNumber <= data->fieldCount)
        return get_string;

    else
        return NULL;
}

// Returns integer based on location in USER_DATA struct
int32_t getFieldInteger(USER_DATA* data, uint8_t fieldNumber)
{
    uint8_t i = data->fieldPosition[fieldNumber];
    uint8_t j = 0;
    uint8_t m = 0;
    char num_string[20];

    while ( m < 20 )
        num_string[m++] = '\0';

    while (data->buffer[i] != '\0')
        num_string[j++] = data->buffer[i++];

    double num_out = strtoul(num_string,NULL, 10);
    return num_out;
}

// Returns float based on location in USER_DATA struct
float getFieldFloat(USER_DATA* data, uint8_t fieldNumber)
{
    uint8_t i = data->fieldPosition[fieldNumber];
    uint8_t j = 0;
    uint8_t m = 0;
    char num_string[20];

    while ( m < 20 )
        num_string[m++] = '\0';

    while (data->buffer[i] != '\0')
        num_string[j++] = data->buffer[i++];

    float num_out = strtof(num_string,NULL);
    return num_out;
}


int32_t string_cmp(char* str1, char* str2)
{
    uint8_t i = 0;
    while (str1[i] != '\0')
    {
        if (str1[i] != str2[i])
            return 0;

        i++;
    }
    return 1;
}

// Custom list of commands for current project
bool isCommand(USER_DATA* data, const char strCommand1[], const char strCommand2[], uint8_t minArguments)
{
    // Three locaal variables for cmd
    uint8_t a= 0, b = 0, j = 0, k = 0;
    char str1[10];
    char str2[10];

    // reset the strings
    while (j < 10)
    {
        str1[j]   = '\0';
        str2[j++] = '\0';
    }

    while (data->buffer[k] != '\0')
        str1[a++] = data->buffer[k++];

    k++;

    while (data->buffer[k] != '\0')
        str2[b++] = data->buffer[k++];
    
    // check if given command is valid
 if ( (string_cmp(strCommand1, str1) == 1) && (string_cmp(strCommand2, str2) == 1) && (minArguments  <=  data->fieldCount))
        return true;
    else
        return false;
}

