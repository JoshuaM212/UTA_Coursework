//-----------------------------------------------------------------------------
// Hardware Target
//-----------------------------------------------------------------------------
// Target Platform: EK-TM4C123GXL
// Target uC:       TM4C123GH6PM
// System Clock:    40 MHz
// Stack:           1024 bytes

// Hardware configuration:

//-----------------------------------------------------------------------------
// Device includes, defines, and assembler directives
//-----------------------------------------------------------------------------

#include <inttypes.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>

#include "clock.h"
#include "wait.h"
#include "gpio.h"
#include "uart0.h"
#include "pwm_enables.h"
#include "tm4c123gh6pm.h"

#define HALL_A      (*((volatile uint32_t *)(0x42000000 + (0x400043FC-0x40000000)*32 + 2*4)))
#define HALL_B      (*((volatile uint32_t *)(0x42000000 + (0x400043FC-0x40000000)*32 + 3*4)))
#define HALL_C      (*((volatile uint32_t *)(0x42000000 + (0x400043FC-0x40000000)*32 + 4*4)))
#define ENABLE_A    (*((volatile uint32_t *)(0x42000000 + (0x400043FC-0x40000000)*32 + 5*4)))
#define ENABLE_B    (*((volatile uint32_t *)(0x42000000 + (0x400043FC-0x40000000)*32 + 6*4)))
#define ENABLE_C    (*((volatile uint32_t *)(0x42000000 + (0x400043FC-0x40000000)*32 + 7*4)))
#define PIN_A       (*((volatile uint32_t *)(0x42000000 + (0x400063FC-0x40000000)*32 + 4*4)))
#define PIN_B       (*((volatile uint32_t *)(0x42000000 + (0x400063FC-0x40000000)*32 + 5*4)))
#define PIN_C       (*((volatile uint32_t *)(0x42000000 + (0x400063FC-0x40000000)*32 + 6*4)))
#define RED_LED     (*((volatile uint32_t *)(0x42000000 + (0x400253FC-0x40000000)*32 + 1*4)))
#define GREEN_LED   (*((volatile uint32_t *)(0x42000000 + (0x400253FC-0x40000000)*32 + 3*4)))

// PortA masks
#define HALL_A_MASK 4       // PA2
#define HALL_B_MASK 8       // PA3
#define HALL_C_MASK 16      // PA4
#define ENABLE_A_MASK 32    // PA5
#define ENABLE_B_MASK 64    // PA6
#define ENABLE_C_MASK 128   // PA7

// PortC masks
#define PIN_A_MASK 16       //PC4
#define PIN_B_MASK 32       //PC5
#define PIN_C_MASK 64       //PC6

// PortF masks
#define RED_LED_MASK 2      // PF1
#define GREEN_LED_MASK 8    // PF3


#define LOWER_LIMIT 50
#define UPPER_LIMIT 100

//-----------------------------------------------------------------------------
// Global variables
//-----------------------------------------------------------------------------

uint8_t  cur_state;             // Counter for state machine
uint32_t time_var = 7000;       // Min. time where motor doesn't slip
uint32_t stopwatch = 1000;        // Used to run motor for a set time before time decrement

uint8_t temp_A;  // purple
uint8_t temp_B;  // blue
uint8_t temp_C;  // yellow
uint8_t temp_cur_state;
uint8_t temp_total;

//-----------------------------------------------------------------------------
// Subroutines
//-----------------------------------------------------------------------------

void State_Manager()
{
    cur_state = (cur_state + 1) % 6;
    if (stopwatch)
        stopwatch--;
}

void Coil_State(int in_1, int in_2, int in_3)
{
    PIN_A = in_1;
    PIN_B = in_2;
    PIN_C = in_3;
}

void Enable_State(int in_1, int in_2, int in_3)
{
    ENABLE_A = in_1;
    ENABLE_B = in_2;
    ENABLE_C = in_3;
}

void Coil_Manager(int input)
{
    if (input == 0 || input == 5)
        Coil_State(1,0,0);
    else if (input == 1 || input == 2)
        Coil_State(0,0,1);
    else if (input == 3 || input == 4)
        Coil_State(0,1,0);
}

void Enable_Manager(int input)
{
    if (input == 0 || input == 3)
        Enable_State(1,1,0);
    else if (input == 1 || input == 4)
        Enable_State(0,1,1);
    else if (input == 2 || input == 5)
        Enable_State(1,0,1);
}

void Top_Manager(int top_state)
{
    Coil_Manager(top_state);
    Enable_Manager(top_state);
}

void Current_Sensor_Values()
{
    temp_A = HALL_A;  // purple
    temp_B = HALL_B;  // blue
    temp_C = HALL_C;  // yellow
    temp_total = temp_A+temp_B+temp_C;
}

void Sensor_Transition(int value)
{
    Current_Sensor_Values();
    int next_state = (cur_state + 1) % 6;
    while (temp_total == value)
    {
        Top_Manager(next_state);
        Current_Sensor_Values();
    }
    State_Manager();
    Top_Manager(cur_state);
}

void Hall_Sen_Manager()
{
    GREEN_LED ^= 1;
    while (true)
    {
        Current_Sensor_Values();
        if (temp_total == 1)
            Sensor_Transition(1);
        else if (temp_total == 2)
            Sensor_Transition(2);
        else
            RED_LED = 1;
    }
}

void Stopwatch_Manager(int Timer_Version)
{
    if (Timer_Version)
        waitMicrosecond(time_var);
    else
        waitMicrosecond(time_var--);
    State_Manager();
}

void Motor_FSM()
{
    Top_Manager(cur_state);
    if (stopwatch)
        Stopwatch_Manager(1);
    else
    {
        if (time_var > 2790)
            Stopwatch_Manager(0);
        else
//            Stopwatch_Manager(1); // Used to show fastest time motor can run w/o slipping
           Hall_Sen_Manager();
    }
}

// Initialize Hardware
void initHw()
{
    // Initialize system clock to 40 MHz
    initSystemClockTo40Mhz();

    enablePort(PORTA);
    enablePort(PORTC);
    enablePort(PORTF);

    // Configure LED and pins
    GPIO_PORTF_DIR_R |= GREEN_LED_MASK | RED_LED_MASK;  // bits 1 and 2 are outputs, other pins are inputs
    GPIO_PORTF_DR2R_R |= GREEN_LED_MASK | RED_LED_MASK; // set drive strength to 2mA (not needed since default configuration -- for clarity)
    GPIO_PORTF_DEN_R |= GREEN_LED_MASK | RED_LED_MASK; // enable LEDs

    GPIO_PORTA_DIR_R &= ~(HALL_A_MASK | HALL_B_MASK | HALL_C_MASK);     // Input pins
    GPIO_PORTA_DEN_R |= HALL_A_MASK | HALL_B_MASK | HALL_C_MASK;

    GPIO_PORTA_DIR_R |= ENABLE_A_MASK | ENABLE_B_MASK | ENABLE_C_MASK;  // Output pins
    GPIO_PORTA_DEN_R |= ENABLE_A_MASK | ENABLE_B_MASK | ENABLE_C_MASK;

    GPIO_PORTC_DIR_R |= PIN_A_MASK | PIN_B_MASK | PIN_C_MASK;
    GPIO_PORTC_DEN_R |= PIN_A_MASK | PIN_B_MASK | PIN_C_MASK;
}

//-----------------------------------------------------------------------------
// Main
//-----------------------------------------------------------------------------

int main(void)
 {
    // Initialize hardware
    initHw();
    while (true)
        Motor_FSM();
}