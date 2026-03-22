// Mech-Lab 8
// Dario Ugalde and Joshua Martinez

//-----------------------------------------------------------------------------
// Hardware Target
//-----------------------------------------------------------------------------

// Target Platform: EK-TM4C123GXL
// Target uC:       TM4C123GH6PM
// System Clock:    40 MHz
// Stack:           4096 bytes (needed for sprintf)

// Hardware configuration:
// UART Interfaces:
//   U0TX (PA1) and U0RX (PA0) are connected to the 2nd controller
//   The USB on the 2nd controller enumerates to an ICDI interface and a virtual COM port
//   Configured to 115,200 baud, 8N1
//
//   U1TX (PC5) and U1RX (PC4) are connected to the 2nd controller
//   The USB on the 2nd controller enumerates to an ICDI interface and a virtual COM port
//   Configured to 115,200 baud, 8N1

// Hardware configuration:
// GPIO Input:
//   PD0 - PWM1_0_CMPA
//   PD1 - PWM1_0_CMPB

//-----------------------------------------------------------------------------
// Device includes, defines, and assembler directives
//-----------------------------------------------------------------------------
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <ctype.h>
#include <math.h>

#include "tm4c123gh6pm.h"
#include "clock.h"
#include "uart0.h"
#include "uart1.h"
#include "a1m8.h"
#include "wait.h"
#include "pwm_enables.h"

#define PI 3.14159265

char str[80];

uint16_t i = 0;

float angle_array[360] = {0};
float distance_array[360] = {0};
float area_sum = 0.0;

//-----------------------------------------------------------------------------
// Subroutines
//-----------------------------------------------------------------------------

// Initialize Hardware
void initHw()
{
    // Initialize system clock to 40 MHz
    initSystemClockTo40Mhz();

    // Enable clocks
    SYSCTL_RCGCGPIO_R |= SYSCTL_RCGCGPIO_R2;  // enables port C
    _delay_cycles(3);
}


//-----------------------------------------------------------------------------
// Main
//-----------------------------------------------------------------------------

int main(void)
{
    // Initialize hardware
    initHw();
    initUart0();
    initUart1();
    initPwmEnables();

    info_response device_info;
    scan_response scan_response;

    uint16_t value = 0.0;

    // Setup UART0 baud rate
    setUart0BaudRate(115200, 40e6);
    setUart1BaudRate(115200, 40e6);
    waitMicrosecond(100);

    // a1m8_scan_request();

    a1m8_info_request();
    device_info = get_a1m8_info();

    sprintf(str, "Model Number: %d\r\n", device_info.model);
    putsUart0(str);
    sprintf(str, "Firmware Number: %d.%d\r\n", device_info.firmware_major, device_info.firmware_minor);
    putsUart0(str);
    sprintf(str, "Hardware Number: %d\r\n", device_info.hardware);
    putsUart0(str);


    while(true)
    {
        area_sum = 0.0;
        setPwmEnableA(1023);
        a1m8_scan_request();

        // Read out scan response descriptor
        getcUart1();
        getcUart1();
        getcUart1();
        getcUart1();
        getcUart1();
        getcUart1();
        getcUart1();

        for (i=0;i<360;i++)
        {
            scan_response = get_a1m8_scan();

            value = scan_response.angle_q6_h;
            value = value << 7;
            value |= (scan_response.angle_q6_l >> 1);
            angle_array[i] = (float) (value / 64.0);

            value = scan_response.distance_q2_h;
            value = value << 8;
            value |= scan_response.distance_q2_l;
            distance_array[i] = (float) (value / 4000.0 * 39.37);
        }

        // Turn off pwm
        setPwmEnableA(0);
        waitMicrosecond(5000000);

        // Display output for user
        for (i=0; i<360;i++)
        {
            sprintf(str, "Angle @ index[%d]: %.2f degrees\r\n", i, angle_array[i]);
            putsUart0(str);
            sprintf(str, "Distance @ index[%d]: %.2fin\r\n", i, distance_array[i]);
            putsUart0(str);
            putsUart0("\r\n");
        }

        for (i=0;i<359;i++)
        {
            if (distance_array[i] != 0.0 && distance_array[i+1] == 0.0)
            {
                distance_array[i+1] = distance_array[i];
            }
            else
            {
                area_sum += (distance_array[i] * distance_array[i+1] * sin((angle_array[i+1]-angle_array[i]) * (PI/180.0))) / 2.0;
            }
        }

        sprintf(str, "Final Area: %.2fin^2\r\n", area_sum);
        putsUart0(str);
        putsUart0("------------------------------------------------------------------\r\n");
    }
}
