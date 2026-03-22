// Mech-Lab 2 Example
// Dario Ugalde and Joshua Martinez

//-----------------------------------------------------------------------------
// Hardware Target
//-----------------------------------------------------------------------------

// Target Platform: EK-TM4C123GXL Evaluation Board
// Target uC:       TM4C123GH6PM
// System Clock:    40 MHz

// Hardware configuration:
// GPIO Output:
//   PD0 enable for coil A
// GPIO Output:
//   PD1 enable for coil B
// GPIO Output:
//   PA4 driver pin for coil A+
// GPIO Output:
//   PC4 driver pin for coil A-
// GPIO Output:
//   PC5 driver pin for coil B+
// GPIO Output:
//   PC6 driver pin for coil B-
// GPIO Input:
//   PD6 input for IR Collector

//-----------------------------------------------------------------------------
// Device includes, defines, and assembler directives
//-----------------------------------------------------------------------------

#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "clock.h"
#include "uart0.h"
#include "wait.h"
#include "motor_control.h"
#include "tm4c123gh6pm.h"

// Bitband aliases
#define PIN_1           (*((volatile uint32_t *)(0x42000000 + (0x400043FC-0x40000000)*32 + 2*4)))   //PA2
#define PIN_2           (*((volatile uint32_t *)(0x42000000 + (0x400043FC-0x40000000)*32 + 3*4)))   //PA3
#define PIN_3           (*((volatile uint32_t *)(0x42000000 + (0x400043FC-0x40000000)*32 + 4*4)))   //PA4
#define PIN_4           (*((volatile uint32_t *)(0x42000000 + (0x400063FC-0x40000000)*32 + 4*4)))   //PC4
#define PIN_5           (*((volatile uint32_t *)(0x42000000 + (0x400063FC-0x40000000)*32 + 5*4)))   //PC5
#define PIN_6           (*((volatile uint32_t *)(0x42000000 + (0x400063FC-0x40000000)*32 + 6*4)))   //PC6
#define PIN_LED         (*((volatile uint32_t *)(0x42000000 + (0x400073FC-0x40000000)*32 + 6*4)))   //PD6

// PortA masks
#define PIN_1_MASK 4    //PA2
#define PIN_2_MASK 8    //PA3
#define PIN_3_MASK 16   //PA4

// PortC masks
#define PIN_4_MASK 16   //PC4
#define PIN_5_MASK 32   //PC5
#define PIN_6_MASK 64   //PC6

// PortD masks
#define PIN_LED_MASK 64  //PD6

#define PI 3.14159265

uint8_t direction = 0;          // Direction 0 = cw, Direction 1 = ccw
uint8_t cur_state = 32;         // Keeps track of the step state machine
uint8_t dir_state_mngr = 0;     // State 1 -> cw used last, state 2 -> ccw used last

uint8_t m_state_0 = 1;          // Used as reset for state machine at zero
uint8_t m_state_final = 32;     // Used to act as end limit for state machine
uint8_t pre_state_mng = 1;      // Setting to one as basis (32 bit start)

float cur_deg_per_step = 0.0;   // Notes angle to remove/add from current angle based on state during rotation
uint8_t time_per_state = 0;     // Sets time limit between each step of rotation based on state
uint8_t size_of_step = 0;       // Divides state machine to match each type of stepping
uint8_t cur_state_mng = 0;      // Used to compare current state with previous one

// Variables used for PWM values based on cos/sin
uint32_t COIL_A_abs;
uint32_t COIL_B_abs;
float COIL_A_tru;
float COIL_B_tru;

// Basis of degree for each step between maximums based on size of step through state machine
// ex. Full->11.25*8 = 90 degress  &  Quad->11.25*2 = 22.50 degrees
float degree_per_state = 11.25;

//-----------------------------------------------------------------------------
// Subroutines
//-----------------------------------------------------------------------------

// Enables Pos,Neg of associated Coil (A,B)
void SET_COIL_A(int pin1, int pin2)
{
    PIN_3 = pin1;
    PIN_4 = pin2;
}
void SET_COIL_B(int pin3, int pin4)
{
    PIN_5 = pin3;
    PIN_6 = pin4;
}

// Function to stop jittering
void Brake_Hit(void)
{
    waitMicrosecond(1000);      // changed from 1000
    SET_COIL_A(1,1);
    SET_COIL_B(1,1);
}

void state_manager(int state_2_man)
{
    if (state_2_man == 1)   // sets up octo stepping - 32 steps max
    {
        cur_deg_per_step = .225;
        time_per_state = 1;
        size_of_step = 1;
        cur_state_mng = 1;

    }
    if (state_2_man == 2)   // sets up quad stepping - 16 steps max
    {
        cur_deg_per_step = .45;
        time_per_state = 2;
        size_of_step = 2;
        cur_state_mng = 2;

    }
    if (state_2_man == 3)   // sets up half stepping - 8 steps max
    {
        cur_deg_per_step = .9;
        time_per_state = 3;
        size_of_step = 4;
        cur_state_mng = 3;

    }
    if (state_2_man == 4) // sets up full stepping - 4 steps max
    {
        cur_deg_per_step = 1.8;
        m_state_final = 4;
        time_per_state = 4;
        size_of_step = 8;
        cur_state_mng = 4;
    }
}

// Sets time between steps based on state
void time_btwn_steps(void)
{
    if (time_per_state == 1)        // used for octo
        waitMicrosecond(600);
    else if (time_per_state == 2)   // used for quad
        waitMicrosecond(2000);
    else if (time_per_state == 3)   // used for half
        waitMicrosecond(250000);
    else if (time_per_state == 4)   // used for full
        waitMicrosecond(500000);
}

// Manages state machine during direction state, ensures proper switching
void direction_manager (int last_know_dir, int curr_dir)
{
    // if both the prev and curr direction are same, do nothing
    if (last_know_dir == curr_dir)
        dir_state_mngr = curr_dir;

    // if different, changed the current state accordingly
    else
    {
        if (curr_dir) // if currently going ccw -> 32 to 1
        {
            if  (cur_state == 1)
                cur_state = m_state_final - size_of_step;
            else
                cur_state = cur_state - (2*size_of_step);
        }
        else        // if currently going cw -> 1 to 32
        {
            if  (cur_state == m_state_final)
                cur_state = size_of_step;
            else
                cur_state = cur_state + (2*size_of_step);
        }
        dir_state_mngr = curr_dir;      // save the last used state
    }
}

void motor_state(int cur_state) // Motor stepping pin outputs
{
    // converts electrical angle to values for PWM bases on cos/sin
    float COIL_A_cos =  cos(cur_state*degree_per_state*(PI/180));
    float COIL_B_sin = sin(cur_state*degree_per_state*(PI/180));
    COIL_A_tru = 1023*COIL_A_cos;
    COIL_B_tru = 1023*COIL_B_sin;
    COIL_A_abs = abs(COIL_A_tru);
    COIL_B_abs = abs(COIL_B_tru);

    // Enable Coils and their direction based on PWM value and sign
    // Turns motor off when PWM = 0
    if ((COIL_A_cos <= 0.1) && (COIL_A_cos >= -0.1))
        SET_COIL_A(0,0);
    else if (COIL_A_tru > 0.1)
        SET_COIL_A(1,0);
    else if (COIL_A_tru < -0.1)
        SET_COIL_A(0,1);

    if ((COIL_B_sin <= 0.1) && (COIL_B_sin >= -0.1))
        SET_COIL_B(0,0);
    else if (COIL_B_tru > 0.1)
        SET_COIL_B(1,0);
    else if (COIL_B_tru < -0.1)
        SET_COIL_B(0,1);

    setPwm(COIL_A_abs, COIL_B_abs);
}

void motor_step(int direction)
{
    // Manages state machine if direction change
    direction_manager(dir_state_mngr, direction);

    // Enable coils based on angle conversion
    motor_state(cur_state);

    // Increments next state based on direction limit reaches
    if (!direction)  // sets motor going ccw , state 1->32
    {
        if (cur_state == m_state_0)
            cur_state = m_state_final;
        else
            cur_state = cur_state - size_of_step;
    }
    else            // sets motor going ccw, state 32->1
    {
        if (cur_state == m_state_final)
            cur_state = size_of_step;
        else
            cur_state = cur_state + size_of_step;
    }
    // Waits for the time limit set based on current bit state (f, h, q, or o)
    time_btwn_steps();
}

// Rotates motor based on direction and  tracks angle position during execution
motor_dir_by_angle(double old_angle, double new_angle, uint8_t direction)
{
    // Temp copies of current and saved angles
    float temp_old = old_angle;
    float temp_new = new_angle;

    // If ccw, adds degree per step to saved angle until greater than saved degree
    if (direction)
    {
        while (temp_old < temp_new)
        {
            motor_step(direction);
            temp_old = temp_old + cur_deg_per_step;
        }
    }
    // If cw, removes degree per step from saved angle until less than saved degree
    else if (!direction)
    {
        while (temp_old > temp_new)
        {
            motor_step(direction);
            temp_old = temp_old - cur_deg_per_step;
        }
    }
    // Saves the stopped at angle to global variable, then hits brake to prevent jitter
    saved_angle_state = temp_old;
    Brake_Hit();
}

// Initialize Hardware
void initHw()
{
    // Initialize system clock to 40 MHz
    initSystemClockTo40Mhz();

    // Enable clocks
    SYSCTL_RCGCGPIO_R |= SYSCTL_RCGCGPIO_R0 | SYSCTL_RCGCGPIO_R2 | SYSCTL_RCGCGPIO_R3;  // enables ports A, C, and D
    _delay_cycles(3);

    // Configure pins
    GPIO_PORTA_DIR_R |= PIN_1_MASK | PIN_2_MASK | PIN_3_MASK;  // marks port value as digital output
    GPIO_PORTA_DEN_R |= PIN_1_MASK | PIN_2_MASK | PIN_3_MASK;

    GPIO_PORTC_DIR_R |= PIN_4_MASK | PIN_5_MASK | PIN_6_MASK;  // marks port value as digital output
    GPIO_PORTC_DEN_R |= PIN_4_MASK | PIN_5_MASK | PIN_6_MASK;

    GPIO_PORTD_DIR_R &= ~PIN_LED_MASK;      // mark port as input
    GPIO_PORTD_DEN_R |= PIN_LED_MASK;       // enable port

}

//-----------------------------------------------------------------------------
// Main
//-----------------------------------------------------------------------------

int main(void)
{
    initHw();
    initPwm();
    initUart0();
    setUart0BaudRate(19200, 40e6);

    USER_DATA data;

    // Resetting of new and saved angles
     saved_angle_state = 0;                 // keeps track of current angle location
     desired_angle_state = 0;               // new angle used to compare and set direction

    int i = 0;          //Enable Pins (before PWM): PIN_1 = 1 (PA2), PIN_2 = 1 (PA3)
    state_manager(2);   // Sets the zero-balance at octo (32) bits

    // Rotates motor cw until LED hit
    while (!PIN_LED)    // uses PD6
        motor_step(1);

    // Rotates motor ccw until bar hits zero degrees - based on 32-bit state
    for (i = 0; i < 90; i++)
        motor_step(0);

    putsUart0("\n\n-------Lab 2 Test-----\n");  // Echo back to the user of the TTY interface for testing
    while(true)
    {
        bool valid = false;
        putsUart0("enter cmd: ");
        getsUart0(&data);                           // Get the string from the user
        parseFields(&data);                          // Parse fields
        getFieldInteger(&data, 1);
        getFieldString(&data, 0);

        // Sets state manager
        if ( isCommand(&data, "o", 1))          // o - octo (32 bits)
            state_manager(1);
        else if ( isCommand(&data, "q", 1) )    // q - quad (16 bits)
            state_manager(2);
        else if ( isCommand(&data, "h", 1) )    // h - half (8 bits)
            state_manager(3);
        else if ( isCommand(&data, "f", 1) )    // f - full (4 bits)
            state_manager(4);

        // Checks if received angle is within 50 degrees due to limited range of bar
        // If valid, sets direction thru comparing saved and desired angles - cw (0) or ccw (1)
        // Afterwards, use function to rotate motor based on acquired data
        if ( ( desired_angle_state >= -50 ) && ( desired_angle_state <= 50 ) )
                valid = true;
        if (valid)
        {
            if (saved_angle_state >= desired_angle_state)
                direction = 0;
            else
                direction = 1;
            motor_dir_by_angle(saved_angle_state, desired_angle_state, direction);
        }

        // Prints error message when improper command is entered
        if (!valid)
            putsUart0("\nInvalid command\n\n");
    }
}

