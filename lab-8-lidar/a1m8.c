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
#include "a1m8.h"
#include "wait.h"

//-----------------------------------------------------------------------------
// Global variables
//-----------------------------------------------------------------------------
bool scan_flag = 0;

//-----------------------------------------------------------------------------
// Subroutines
//-----------------------------------------------------------------------------

void a1m8_stop_request()
{
    char stop_message[3] = {0xA5, 0x25, '\0'};
    putsUart1(stop_message);

    // Wait 1ms after making request to process
    waitMicrosecond(1000);
}

void a1m8_info_request()
{
    putcUart1(0xA5);
    putcUart1(0x50);
}

info_response get_a1m8_info()
{
    info_response response;

    getcUart1();
    getcUart1();
    getcUart1();
    getcUart1();
    getcUart1();
    getcUart1();
    getcUart1();

    char serial_data[20];
    int i = 0;

    for (i = 0; i<20;i++)
    {
        serial_data[i] = getcUart1();
    }

    response = *((info_response*) serial_data);
    return response;
}

void a1m8_scan_request()
{
    putcUart1(0xA5);
    putcUart1(0x20);
}

scan_response get_a1m8_scan()
{
    scan_response response;

    char serial_data[5];
    int i = 0;
    
    for (i=0;i<5;i++)
    {
        serial_data[i] = getcUart1();
    }

    scan_flag = true;
    response = *((scan_response*) serial_data);
    return response;
}
