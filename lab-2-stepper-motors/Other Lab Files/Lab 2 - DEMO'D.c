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



double saved_angle_state = 0;
double desired_angle_state = 0;

//-------------------------------------------------------------------------------------------

#define MAX_CHARS 80
#define MAX_FIELDS 5

typedef struct _USER_DATA
{
    char buffer[MAX_CHARS+1];
    uint8_t fieldCount;
    uint8_t fieldPosition[MAX_FIELDS];
    char fieldType[MAX_FIELDS];
} USER_DATA;

void getsUart0(USER_DATA* data)
{
    uint8_t count = 0, i = 0;
    while ( i < MAX_CHARS+1 )
    {
        data->buffer[i++] = '\0';
    }
    while(1)
    {
        char c = getcUart0();
        if ( ( c == 8 || c == 127 ) && count > 0 )
        {
            count--;
        }
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

char* getFieldString(USER_DATA* data, uint8_t fieldNumber)
{
    uint8_t i = data->fieldPosition[fieldNumber];
    uint8_t j = 0, m = 0;
    char get_string[20];

    while ( m < 20 )
    {
        get_string[m++] = '\0';
    }
    while (data->buffer[i] != '\0')
    {
        get_string[j++] = data->buffer[i++];
    }

    if ( ( fieldNumber <= data->fieldCount )  && ( data->fieldType[fieldNumber-1] == 'a' ) )
    {
        return get_string;
    }
    else
    {
        return NULL;
    }
}

int32_t getFieldInteger(USER_DATA* data, uint8_t fieldNumber)
{
    uint8_t i = data->fieldPosition[fieldNumber];
    uint8_t j = 0;
    uint8_t m = 0;
    char num_string[20];

    while ( m < 20 )
    {
        num_string[m++] = '\0';
    }
    while (data->buffer[i] != '\0')
    {
        num_string[j++] = data->buffer[i++];
    }
    //double num_out = strtoul(num_string,NULL, 10);
    double num = atof(num_string);

    if ( ( fieldNumber <= data->fieldCount ) && ( data->fieldType[fieldNumber] == 'n' ) )
    {
        desired_angle_state = num;
    }
    else
    {
        desired_angle_state = 999;
    }
}

int32_t string_cmp(char* str1, char* str2)
{
    uint8_t i = 0;
    while (str1[i] != '\0')
    {
        if (str1[i] != str2[i])
        {
            return 0;
        }
        i++;
    }
    return 1;
}


bool isCommand(USER_DATA* data, const char strCommand[], uint8_t minArguments)
{
    uint8_t i = data->fieldPosition[0];
    uint8_t j = 0, k = 0, m = 0;
    char str1[20];

    while ( k < 20 )
    {
        str1[k++] = '\0';
    }
    while (data->buffer[j] != '\0')
    {
        str1[j++] = data->buffer[i++];
        m++;
    }

     if ( ( string_cmp(strCommand, str1) == 1 ) && (strCommand == "q") && (minArguments  <  data->fieldCount)  )
    {
        return true;
    }
    else if ( ( string_cmp(strCommand, str1) == 1 ) && (strCommand == "h") && (minArguments  <=  data->fieldCount)  )
    {
        return true;
    }

    else if ( ( string_cmp(strCommand, str1) == 1 ) && (strCommand == "f") && (minArguments  <=  data->fieldCount)  )
    {
        return true;
    }
}





//-------------------------------------------------------------------------------------------

uint8_t direction = 0;          // direction 0 = cw, direction 1 = ccw
uint8_t cur_state = 32;          // Keeps track of the step state machine

float cur_deg_per_step = 0.0;  // full step = 1.8 , w/ .18 adds 9 intermediate steps between major states

uint8_t m_state_0 = 1;
uint8_t m_state_final = 32;
uint8_t cur_state_mng = 1;      // setting to one as basis (32 bit start)
uint8_t pre_state_mng = 1;      // setting to one as basis (32 bit start)

uint8_t dir_state_mngr = 0;     // state 1 -> cw used last, state 2 -> ccw used last

uint8_t size_of_step = 0;
uint8_t time_per_state = 0;

uint32_t COIL_A_abs;
uint32_t COIL_B_abs;
float COIL_A_tru;
float COIL_B_tru;

float degree_per_state = 11.25;

#define PI 3.14159265

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

void time_btwn_steps(void) // WIP: state 1 = can be modified to test top speed available
{                               //      state 2 = used to realign the motor to 0 degree in the beginning
    if (time_per_state == 1)  // used for octo
    {
        waitMicrosecond(600);
    }
    else if (time_per_state == 2)  // used for quad
    {
        waitMicrosecond(2000);
    }
    else if (time_per_state == 3)  // used for half
    {
        waitMicrosecond(250000);
    }
    else if (time_per_state == 4)  // used for full
    {
        waitMicrosecond(500000);
    }

}

void direction_manager (int last_know_dir, int curr_dir)
{
    if (last_know_dir == curr_dir)  // if both the prev and curr direction are same, do nothing
    {
        dir_state_mngr = curr_dir;
    }
    else                            // if different, changed the current state accordingly
    {
        // cw -> 1 - 32, ccw -> 32 - 1
        if (curr_dir) // if currently going ccw
        {
            if  (cur_state == 1)
            {
                cur_state = m_state_final - size_of_step;
            }
            else
            {
                cur_state = cur_state - (2*size_of_step);
            }
        }
        else
        {
            if  (cur_state == m_state_final)
            {
                cur_state = size_of_step;
            }
            else
            {
                cur_state = cur_state + (2*size_of_step);
            }
        }
        dir_state_mngr = curr_dir;      // save the last used state
    }
}

void motor_state(int cur_state) // Motor stepping pin outputs
{
    // add the intermediate states between for cycling through the major state changes
    // direction sets motor going cw , state 0->3
    // !direection sets motor going ccw, state 3->0

    float COIL_A_cos =  cos(cur_state*degree_per_state*(PI/180));
    float COIL_B_sin = sin(cur_state*degree_per_state*(PI/180));
    COIL_A_tru = 1023*COIL_A_cos;
    COIL_B_tru = 1023*COIL_B_sin;
    COIL_A_abs = abs(COIL_A_tru);
    COIL_B_abs = abs(COIL_B_tru);


    if ((COIL_A_cos <= 0.1) && (COIL_A_cos >= -0.1))
    {
        SET_COIL_A(0,0);
    }
    else if (COIL_A_tru > 0.1)
    {
        SET_COIL_A(1,0);
    }
    else if (COIL_A_tru < -0.1)
    {
        SET_COIL_A(0,1);
    }

    if ((COIL_B_sin <= 0.1) && (COIL_B_sin >= -0.1))
    {
        SET_COIL_B(0,0);
    }
    else if (COIL_B_tru > 0.1)
    {
        SET_COIL_B(1,0);
    }
    else if (COIL_B_tru < -0.1)
    {
        SET_COIL_B(0,1);
    }
    setPwm(COIL_A_abs, COIL_B_abs);
}

void motor_step(int direction)
{
    direction_manager(dir_state_mngr, direction);
    motor_state(cur_state);
    if (!direction)  // sets motor going cw , state 1->32
    {
        if (cur_state == m_state_0)
        {
            cur_state = m_state_final;
        }
        else
        {
            cur_state = cur_state - size_of_step;
        }
    }
    else        // sets motor going ccw, state 32->1
    {
        if (cur_state == m_state_final)
        {
            cur_state = size_of_step;   /// check--------------------------------------------
        }
        else
        {
            cur_state = cur_state + size_of_step;
        }
    }
    time_btwn_steps();
    // Brake_Hit(); use 10,000
}

motor_dir_by_angle(double old_angle, double new_angle, uint8_t direction) // 45 degree limit = 90 total
{
    float temp_old = old_angle;
    float temp_new = new_angle;

    if (direction)
    {
        while (temp_old < temp_new)
        {
            motor_step(direction);
            temp_old = temp_old + cur_deg_per_step;
        }
    }
    else if (!direction)   // goes cw
    {
        while (temp_old > temp_new)
        {
            motor_step(direction);
            temp_old = temp_old - cur_deg_per_step;
        }
    }
    saved_angle_state = temp_old;
    Brake_Hit();
}


//-----------------------------------------------------------------------------
// Subroutines
//-----------------------------------------------------------------------------

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
  //  GPIO_PORTD_PDR_R |= PIN_LED_MASK;       // pull down resistor

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

    //Enable Pins (before PWM): PIN_1 = 1 (PA2), PIN_2 = 1 (PA3)
    int i = 0;

    state_manager(2); // Sets the zero-balance at octo (32) bits

    while (!PIN_LED)  // PD6 handles while switch
    {
        motor_step(1);
    }

    for (i = 0; i < 90; i++)  // takes about 22 to reset to 0 degrees as full step ----Find for octo
    {
        motor_step(0);
    }

    putsUart0("\n\n-------Lab 2 Test-----\n");  // Echo back to the user of the TTY interface for testing

    while(true)
    {
        bool valid = false;
        putsUart0("enter cmd: ");
        getsUart0(&data);                           // Get the string from the user
        parseFields(&data);                          // Parse fields
        getFieldInteger(&data, 1);
        getFieldString(&data, 0);

        if ( isCommand(&data, "o", 1))
        {
            state_manager(1);
        }
        else if ( isCommand(&data, "q", 1) )
        {
            state_manager(2);
        }
        else if ( isCommand(&data, "h", 1) )
        {
            state_manager(3);
        }
        else if ( isCommand(&data, "f", 1) )
        {
            state_manager(4);
        }

        if ( ( desired_angle_state >= -50 ) && ( desired_angle_state <= 50 ) )
        {
                valid = true;
        }
        if (valid)
        {
            if (saved_angle_state >= desired_angle_state)
            {
                direction = 0;
            }
            else
            {
                direction = 1;
            }
            motor_dir_by_angle(saved_angle_state, desired_angle_state, direction);
        }

        if (!valid)
        {
            putsUart0("\nInvalid command\n\n");
        }
    }
}

