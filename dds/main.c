// DDS Project
// CSE 5342 Embedded Systems II
// Dario Ugalde
//-----------------------------------------------------------------------------
// Hardware Target
//-----------------------------------------------------------------------------
// Target Platform: EK-TM4C123GXL Evaluation Board
// Target uC:       TM4C123GH6PM
// System Clock:    40 MHz
// Hardware configuration:
// Red LED:
//   PF1 drives an NPN transistor that powers the red LED
// Green LED:
//   PF3 drives an NPN transistor that powers the green LED

//-----------------------------------------------------------------------------
// Device includes, defines, and assembler directives
//-----------------------------------------------------------------------------
#include <math.h>
#include <stdint.h>
#include <string.h>
#include <stdbool.h>

#include "adc0.h"
#include "clock.h"
#include "gpio.h"
#include "nvic.h"
#include "spi1.h"
#include "timer1.h"
#include "timer2.h"
#include "timer3.h"
#include "timer4.h"
#include "tm4c123gh6pm.h"
#include "uart0.h"
#include "ui.h"
#include "wait.h"

// Pins
#define CS PORTD,1
#define LDAC PORTD,2
#define RED_LED PORTF,1
#define GREEN_LED PORTF,3
#define PUSH_BUTTON PORTF,4
#define AIN9 PORTE,4
#define AIN8 PORTE,5

// Define values
#define PI 3.14159265
#define MAX_CHARS 80
#define MAX_LUT 2048
#define N_VALUE 11
#define GAIN_A -381.6
#define GAIN_B -379.2
#define OFS_A 1965
#define OFS_B 1969

//-----------------------------------------------------------------------------
// Global Variables
//-----------------------------------------------------------------------------
bool waveformA = false;
bool waveformB = false;
bool squareWaveA = false;
bool squareWaveB = false;
bool ldacWriting = false;
bool stopRunFlag = false;
bool levelOnFlag = false;
bool differentialFlag = false;
uint8_t strInput[MAX_CHARS + 1];
uint8_t adcValue[4];
uint8_t argIndex[5];
uint8_t strVerb[25];
uint8_t asciiOutput[6];
uint8_t fieldCount = 0;
uint16_t lutA[MAX_LUT];
uint16_t lutB[MAX_LUT];

uint16_t timerCounterA = 0;
uint16_t cycleCounterA = 0;
uint16_t cycleLimiterA = 0;
uint16_t timerCounterB = 0;
uint16_t cycleCounterB = 0;
uint16_t cycleLimiterB = 0;
uint32_t phaseA;
uint32_t phaseB;
uint32_t timer3Load;
uint32_t timer4Load;

float asciiFloat = 0.0;
float sineValue = 0.0;
float squareAmplitudeA = 0.0;
float squareAmplitudeB = 0.0;
float squareOffsetA = 0.0;
float squareOffsetB = 0;
uint16_t frequencyA = 0;
uint16_t frequencyB = 0;
uint16_t squareFrequencyA = 0;
uint16_t squareFrequencyB = 0;



//-----------------------------------------------------------------------------
// Subroutines
//-----------------------------------------------------------------------------

// Initialize Hardware
void initHw()
{
    // Initialize system clock to 40 MHz
    initSystemClockTo40Mhz();

    // Enable clocks
    enablePort(PORTF);
    enablePort(PORTE);

    // Configure LED and pushbutton pins
    selectPinPushPullOutput(GREEN_LED);
    selectPinPushPullOutput(RED_LED);
    selectPinDigitalInput(PUSH_BUTTON);
    enablePinPullup(PUSH_BUTTON);

    // Initialize SPI interface
    initSpi1(USE_SSI_FSS);
    setSpi1BaudRate(2e6, 40e6);
    setSpi1Mode(0,0);

    enablePinPulldown(LDAC);

    setPinValue(CS,1);
    setPinValue(CS,0);
    waitMicrosecond(100);
    setPinValue(CS,1);

    // Initialize UART interface
    initUart0();
    setUart0BaudRate(115200, 40e6);

    // Initialize analog inputs at AN8 on PE5 and AN9 on PE6
    initAdc0Ss3();
    selectPinAnalogInput(AIN8);
    selectPinAnalogInput(AIN9);

    // Initialize timers
    initTimer1();
    initTimer2();
    initTimer3();
    initTimer4();
}

void writeDacA(uint32_t data)
{
    // Build message and transmit to MCP4822
    setPinValue(CS, 0);

    uint32_t dacData = 0x3 << 12;
    dacData = dacData | (0x0FFF & data);
    writeSpi1Data(dacData);

    setPinValue(CS,1);
}

void writeDacB(uint32_t data)
{
    // Build and transmit message to MCP4822
    setPinValue(CS,0);

    uint32_t dacData = 0xB << 12;
    dacData = dacData | (0x0FFF & data);
    writeSpi1Data(dacData);

    setPinValue(CS,1);
}

//-----------------------------------------------------------------------------
// Interrupt Service Routines
//-----------------------------------------------------------------------------
void timer1ISR()
{
    TIMER1_ICR_R = TIMER_ICR_TATOCINT;               // clear interrupt

    writeDacA(lutA[phaseA >> (32-N_VALUE)]);

    if(cycleLimiterA > 0)
    {
        if((phaseA + (0x2 * frequencyA + frequencyA / 4) << 15) < phaseA)
        {
            cycleCounterA--;
        }
        if(!cycleCounterA)
        {
            cycleCounterA = cycleLimiterA;
            stopTimer1();
            writeDacA(OFS_A);
        }
    }

    phaseA += (0x4 * (frequencyA + frequencyA / 12)) << 15;
}

void timer2ISR()
{
    TIMER2_ICR_R = TIMER_ICR_TATOCINT;               // clear interrupt

    writeDacB(lutB[phaseB >> (32-N_VALUE)]);

    if(cycleLimiterB > 0)
    {
        if((phaseB + ((0x2 * (frequencyB + frequencyB / 4)) << 15)) < phaseB)
        {
            cycleCounterB--;
        }
        if(!cycleCounterB)
        {
            cycleCounterB = cycleLimiterB;
            stopTimer2();
            writeDacB(OFS_B);
        }
    }

    phaseB += (0x4 * (frequencyB + frequencyB / 12)) << 15;

}

void timer3ISR()
{

    TIMER3_ICR_R = TIMER_ICR_TATOCINT;               // clear interrupt
    TIMER3_TAILR_R = timer3Load;                     // set load value

    writeDacA((uint32_t)(GAIN_A * squareAmplitudeA + squareOffsetA));
    squareAmplitudeA = squareAmplitudeA * -1;

    if(cycleLimiterA > 0)
    {
        if(timerCounterA == cycleLimiterA * 2)
        {
            timerCounterA = 0;
            stopTimer3();
            writeDacA(squareOffsetA);
        }
        else
        {
            timerCounterA++;
            TIMER3_CTL_R |= TIMER_CTL_TAEN;
        }
    }
    else
    {
        timerCounterA++;
        TIMER3_CTL_R |= TIMER_CTL_TAEN;
    }
}

void timer4ISR()
{
    TIMER4_CTL_R &= ~TIMER_CTL_TAEN;                 // turn-off timer before reconfiguring
    TIMER4_ICR_R = TIMER_ICR_TATOCINT;               // clear interrupt
    TIMER4_TAILR_R = timer4Load;                     // set load value

    writeDacB((uint32_t)(GAIN_B * squareAmplitudeB + squareOffsetB));
    squareAmplitudeB = squareAmplitudeB * -1;

    if(cycleLimiterB > 0)
    {
        if(timerCounterB == cycleLimiterB * 2)
        {
            timerCounterB = 0;
            stopTimer4();
            writeDacB(squareOffsetB);
        }
        else
        {
            timerCounterB++;
            TIMER4_CTL_R |= TIMER_CTL_TAEN;
        }
    }
    else
    {
        timerCounterB++;
        TIMER4_CTL_R |= TIMER_CTL_TAEN;
    }
}

void sine(float amplitude, uint16_t frequency)
{
    uint16_t i = 0;

    // Pause signal generation to update LUT
    stopTimer2();

    // Load LUT-B
    phaseB = 0;
    frequencyB = frequency;
    for(i=0;i<MAX_LUT;i++)
    {
        float calcValue = PI;
        calcValue = 2 * calcValue * i / MAX_LUT;
        sineValue = sin(calcValue) * amplitude;
        lutB[i] = OFS_B + (uint16_t)(GAIN_B * sineValue);
    }

    // Set OFS value
    writeDacB(OFS_B);

    // Set waveform running flag
    waveformB = true;

    // Begin signal output
    startTimer2();
}

void sawtooth(float amplitude, uint16_t frequency, uint16_t offset)
{
    // Set waveform bounds and calculate range
    uint16_t min = (uint16_t)(offset - GAIN_B * amplitude);
    uint16_t max = (uint16_t)(offset + GAIN_B * amplitude);
    uint16_t range = 0;
    uint16_t i = 0;

    if(max > min)
    {
        range = max - min;

        // Set LUT-B
        phaseB = 0;
        for(i=0;i<MAX_LUT;i++)
        {
            lutB[i] = max - range * i / MAX_LUT;
        }
    }
    else
    {
        range = min - max;
        max = min;

        // Set LUT-B
        phaseB = 0;
        for(i=0;i<MAX_LUT;i++)
        {
            lutB[i] = max - range * i / MAX_LUT;
        }
    }
}

void triangle(float amplitude, uint16_t frequency, uint16_t offset)
{
    // Set frequency value
    frequencyB = frequency;
    
    // Calculate waveform bounds and range
    uint16_t min = (uint16_t)(GAIN_B * amplitude / 2);
    uint16_t max = (uint16_t)(GAIN_B * -1.0 * amplitude / 2);
    uint16_t range = max - min;
    uint16_t i = 0;

    phaseB = 0;
    for(i=0;i<MAX_LUT/2;i++)
    {
        lutB[i] = max - range * i / (MAX_LUT/2) + offset;
    }
    for(i=0;i<MAX_LUT/2;i++)
    {
        lutB[i+(MAX_LUT/2)] = min + range * i / (MAX_LUT/2) + offset;
    }
}

void voltage(uint8_t channel, float* voltage)
{
    uint16_t adcValue = 0;

    setAdc0Ss3Mux(0x7 + channel);
    adcValue = readAdc0Ss3();
    *voltage = (adcValue / 4095.0) * 3.3;
}

//-----------------------------------------------------------------------------
// Main
//-----------------------------------------------------------------------------
int main(void)
{
    // Initialize hardware
    initHw();

    // Turn off green LED, turn on red LED
    setPinValue(GREEN_LED, 0);
    setPinValue(RED_LED, 1);

    // Write to 0V to each DAC
    writeDacA(OFS_A); // Set voltage for MCP4822 pin 8
    writeDacB(OFS_B); // Set voltage for MCP4822 pin 6

    while(true)
    {
       // Request command
       putsUart0("Enter a command:\r\n");
       getsUart0(strInput);
       putsUart0("\r\n");

       // Parse input
       parseStr(strInput, argIndex, &fieldCount);
       getVerb(argIndex[0], strVerb, strInput);

       // Validate command
       if(isCommand(fieldCount - 1, strVerb))
       {
           // Handle DC command
           if(!strcmp(strVerb, "dc"))
           {
               // Select channel 1
               if(strInput[argIndex[1]] == '1')
               {
                   // Extract dc output voltage
                   ATOF(&strInput[argIndex[2]], &asciiFloat);

                   // Handle invalid input
                   if(asciiFloat > 5.0 || asciiFloat < -5.0)
                   {
                       putsUart0("\r\nReceived: ");
                       FTOA(&asciiFloat, asciiOutput);
                       putsUart0(asciiOutput);
                       putsUart0("\r\nInvalid voltage range: DAC outputs must be in range of -5.0V to 5.0V\r\n");
                   }
                   // Proceed with valid input
                   else
                   {
                       // Calculate dc output
                       uint16_t dacValue = (uint16_t)(GAIN_A * asciiFloat + OFS_A);

                       // Disable running waveforms
                       if(waveformA)
                       {
                           stopTimer1();
                           stopTimer3();
                       }

                       // Send dc output to DAC-A
                       writeDacA(dacValue);

                       // Notify user of change
                       putsUart0("\r\nSet DAC-A to ");
                       FTOA(&asciiFloat, asciiOutput);
                       putsUart0(asciiOutput);
                       putsUart0("V");
                       putsUart0(" (");
                       putsUart0(ITOA(dacValue, asciiOutput));
                       putsUart0(")\r\n");

                   }
               }
               // Select channel 2
               else if(strInput[argIndex[1] == '2'])
               {
                   // Extract dc output voltage
                   ATOF(&strInput[argIndex[2]], &asciiFloat);

                   // Handle invalid input
                   if(asciiFloat > 5.0 || asciiFloat < -5.0)
                   {
                       putsUart0("\r\nReceived: ");
                       FTOA(&asciiFloat, asciiOutput);
                       putsUart0(asciiOutput);
                       putsUart0("\r\nInvalid voltage range: DAC outputs must be in range of -5.0V to 5.0V\r\n");
                   }
                   // Proceed with valid input
                   else
                   {
                       // Calculate dc output
                       uint16_t dacValue = (uint16_t)(GAIN_B * asciiFloat + OFS_B);

                       // Disable running waveforms
                       if(waveformB)
                       {
                           stopTimer2();
                           stopTimer4();
                       }

                       // Send dc output to DAC-B
                       writeDacB(dacValue);

                       // Notify user of change
                       putsUart0("\r\nSet DAC-B to ");
                       FTOA(&asciiFloat, asciiOutput);
                       putsUart0(asciiOutput);
                       putsUart0("V");
                       putsUart0(" (");
                       putsUart0(ITOA(dacValue, asciiOutput));
                       putsUart0(")\r\n");

                   }
               }
           }

           if(!strcmp(strVerb, "sine"))
           {
               // Select channel 1
               if(strInput[argIndex[1]] == '1')
               {
                   uint16_t i = 0;
                   float amplitude = 0.0;
                   float offset = 0.0;

                   // Extract frequency from user input
                   frequencyA = ATOI(&strInput[argIndex[2]]);
                   if(differentialFlag)
                   {
                       frequencyB = frequencyA;
                   }

                   // Extract amplitude from user input
                   ATOF(&strInput[argIndex[3]], &asciiFloat);
                   amplitude = asciiFloat;

                   // Extract offset from user input
                   if(argIndex[4])
                   {
                       ATOF(&strInput[argIndex[4]], &asciiFloat);
                       offset = GAIN_A * asciiFloat + OFS_A;
                   }
                   else
                   {
                       offset = OFS_A;
                   }

                   // Load LUT-A
                   phaseA = 0;
                   if(differentialFlag)
                   {
                       phaseB = 0;
                   }
                   for(i=0;i<MAX_LUT;i++)
                   {
                       float calcValue = PI;
                       calcValue = 2 * calcValue * i / MAX_LUT;
                       sineValue = sin(calcValue) * amplitude;
                       lutA[i] = (offset) + GAIN_A * sineValue;
                       if(differentialFlag)
                       {
                           lutB[i] = OFS_B + GAIN_B * -sineValue;
                       }
                   }

                   // Set OFS value
                   writeDacA(offset);

                   // Set waveform running flag
                   waveformA = true;
                   if(differentialFlag)
                   {
                       waveformB = true;
                   }

                   // Begin signal output
                   if(!stopRunFlag)
                   {
                       startTimer1();
                       if(differentialFlag)
                       {
                           startTimer2();
                       }
                   }

                   if(levelOnFlag)
                   {
                       float gain = 0;
                       float loadVoltage = 0;

                       // Read load voltage from channel 2
                       waitMicrosecond(500000);
                       voltage(2, &loadVoltage);

                       if(!(loadVoltage <= amplitude / 2 + 0.1 && loadVoltage >= amplitude / 2 - 0.1))
                       {
                           gain = amplitude / 2 / loadVoltage;
                           amplitude = amplitude * gain;
                           sine(amplitude, frequencyA);
                           putsUart0("Adjusted amplitude with a gain of ");
                           FTOA(&gain, asciiOutput);
                           putsUart0(asciiOutput);
                           putsUart0("\r\n");
                       }
                   }
               }
               // Select channel 2
               if(strInput[argIndex[1]] == '2')
               {
                   uint16_t i = 0;
                   float amplitude = 0.0;
                   float offset = 0.0;

                   // Extract frequency from user input
                   frequencyB = ATOI(&strInput[argIndex[2]]);

                   // Extract amplitude from user input
                   ATOF(&strInput[argIndex[3]], &asciiFloat);
                   amplitude = asciiFloat;

                   // Extract offset from user input
                   if(argIndex[4])
                   {
                       ATOF(&strInput[argIndex[4]], &asciiFloat);
                       offset = GAIN_B * asciiFloat + OFS_B;
                   }
                   else
                   {
                       offset = OFS_B;
                   }

                   // Load LUT-B
                   phaseB = 0;
                   for(i=0;i<MAX_LUT;i++)
                   {
                       float calcValue = PI;
                       calcValue = 2 * calcValue * i / 2048;
                       sineValue = sin(calcValue) * amplitude;
                       lutB[i] = (offset) + GAIN_B * sineValue;
                   }

                   // Set OFS value
                   writeDacB(offset);

                   // Set waveform running flag
                   waveformB = true;

                   // Begin signal output
                   if(!stopRunFlag)
                   {
                       startTimer2();
                   }

                   if(levelOnFlag)
                   {
                       float gain = 0;
                       float loadVoltage = 0;

                       // Read load voltage from channel 2
                       waitMicrosecond(500000);
                       voltage(2, &loadVoltage);

                       if(!(loadVoltage <= amplitude / 2 + 0.1 && loadVoltage >= amplitude / 2 - 0.1))
                       {
                           gain = amplitude / 2 / loadVoltage;
                           amplitude = amplitude * gain;
                           sine(amplitude, frequencyB);
                           putsUart0("Adjusted amplitude with a gain of ");
                           FTOA(&gain, asciiOutput);
                           putsUart0(asciiOutput);
                           putsUart0("\r\n");
                       }
                   }
               }
           }

           if(!strcmp(strVerb, "square"))
           {
               // Select channel 1
               if(strInput[argIndex[1]] == '1')
               {
                   uint32_t frequency = 0;

                   // Set frequency to Timer3
                   TIMER3_CTL_R &= ~TIMER_CTL_TAEN;
                   frequency = ATOI(&strInput[argIndex[2]]);
                   timer3Load = (uint32_t)(1.0 / frequency / 0.000000025) / 2;
                   if(differentialFlag)
                   {
                       timer4Load = (uint32_t)(1.0 / frequency / 0.000000025) / 2;
                       TIMER4_TAILR_R = timer4Load;
                   }
                   squareFrequencyA = (uint16_t) frequency;
                   if(differentialFlag)
                   {
                       squareFrequencyB = squareFrequencyA;
                   }
                   TIMER3_TAILR_R = timer3Load;

                   // Extract amplitude from user input
                   ATOF(&strInput[argIndex[3]], &squareAmplitudeA);
                   if(differentialFlag)
                   {
                       squareAmplitudeB = squareAmplitudeA;
                       squareOffsetB = OFS_B;
                   }

                   // Extract offset from user input
                   if(argIndex[4])
                   {
                       ATOF(&strInput[argIndex[4]], &asciiFloat);
                       squareOffsetA = GAIN_A * asciiFloat + OFS_A;
                   }
                   else
                   {
                       squareOffsetA = OFS_A;
                   }

                   // Set OFS value
                   writeDacA((uint32_t)(GAIN_A * squareAmplitudeA + squareOffsetA));
                   if(differentialFlag)
                   {
                       writeDacB((uint32_t)(GAIN_B * -squareAmplitudeA + OFS_B));
                   }

                   // Set waveform running flag
                   waveformA = true;
                   if(differentialFlag)
                   {
                       waveformB = true;
                   }

                   // Begin signal output
                   if(!stopRunFlag)
                   {
                       startTimer3();
                       if(differentialFlag)
                       {
                           startTimer4();
                       }
                   }
               }
               // Select channel 2
               if(strInput[argIndex[1]] == '2')
               {
                   uint32_t frequency = 0;

                   // Extract frequency from user input
                   TIMER4_CTL_R &= ~TIMER_CTL_TAEN;
                   frequency = ATOI(&strInput[argIndex[2]]);
                   timer4Load = (uint32_t)(1.0 / frequency / 0.000000025) / 2;
                   squareFrequencyB = (uint16_t) frequency;
                   TIMER4_TAILR_R = timer4Load;

                   // Extract amplitude from user input
                   ATOF(&strInput[argIndex[3]], &asciiFloat);
                   squareAmplitudeB = asciiFloat;

                   // Extract offset from user input
                   if(fieldCount - 1 == 4)
                   {
                       ATOF(&strInput[argIndex[4]], &asciiFloat);
                       squareOffsetB = GAIN_B * asciiFloat + OFS_B;
                   }
                   else if(fieldCount - 1 == 3)
                   {
                       squareOffsetB = OFS_B;
                   }

                   // Set OFS value
                   writeDacB((uint32_t)(GAIN_B * squareAmplitudeB + squareOffsetB));

                   // Set waveform running flag
                   waveformB = true;

                   // Begin signal output
                   if(!stopRunFlag)
                   {
                       startTimer4();
                   }

                   if(levelOnFlag)
                   {
                       float gain = 0;
                       float loadVoltage = 0;

                       // Read load voltage from channel 2
                       waitMicrosecond(500000);
                       voltage(2, &loadVoltage);

                       if(!(loadVoltage <= squareAmplitudeB + 0.1 && loadVoltage >= squareAmplitudeB - 0.1))
                       {
                           gain = squareAmplitudeB / loadVoltage;
                           squareAmplitudeB = squareAmplitudeB * gain;
                           putsUart0("Adjusted amplitude with a gain of ");
                           FTOA(&gain, asciiOutput);
                           putsUart0(asciiOutput);
                           putsUart0("\r\n");
                       }
                   }
               }
           }

           if(!strcmp(strVerb, "sawtooth"))
           {
               // Select channel 1
               if(strInput[argIndex[1]] == '1')
               {
                   uint16_t i = 0;
                   float amplitude = 0.0;
                   float offset = 0.0;

                   // Extract frequency from user input
                   frequencyA = ATOI(&strInput[argIndex[2]]);

                   // Extract amplitude from user input
                   ATOF(&strInput[argIndex[3]], &asciiFloat);
                   amplitude = asciiFloat;

                   // Extract offset from user input
                   if(argIndex[4])
                   {
                       ATOF(&strInput[argIndex[4]], &asciiFloat);
                       offset = GAIN_A * asciiFloat + OFS_A;
                   }
                   else
                   {
                       offset = OFS_A;
                   }
                   if(differentialFlag)
                   {
                       frequencyB = frequencyA;
                   }

                   // Set waveform bounds and calculate range
                   uint16_t min = (uint16_t)(offset - GAIN_A * amplitude / 2);
                   uint16_t max = (uint16_t)(offset + GAIN_A * amplitude / 2);
                   uint16_t range = 0;


                   if(max > min)
                   {
                       range = max - min;

                       // Set LUT-A
                       phaseA = 0;
                       for(i=0;i<MAX_LUT;i++)
                       {
                           lutA[i] = max - range * i / 2048;
                       }
                   }
                   else
                   {
                       range = min - max;
                       max = min;

                       // Set LUT-A
                       phaseA = 0;
                       for(i=0;i<MAX_LUT;i++)
                       {
                           lutA[i] = max - range * i / 2048;
                       }
                   }

                   if(differentialFlag)
                   {
                       // Set waveform bounds and calculate range
                       max = (uint16_t)(offset - GAIN_B * amplitude / 2);
                       min = (uint16_t)(offset + GAIN_B * amplitude / 2);
                       uint16_t range = 0;


                       if(max > min)
                       {
                           range = max - min;

                           // Set LUT-B
                           phaseB = 0;
                           for(i=0;i<MAX_LUT;i++)
                           {
                               lutB[i] = min + range * i / 2048;
                           }
                       }
                       else
                       {
                           range = min - max;
                           max = min; 
                           // Set LUT-B
                           phaseA = 0;
                           for(i=0;i<MAX_LUT;i++)
                           {
                               lutB[i] = min + range * i / 2048;
                           }
                       }
                   }

                   // Set OFS value
                   writeDacA(offset);

                   // Set waveform running flag
                   waveformA = true;
                   if(differentialFlag)
                   {
                       waveformB = true;
                   }

                   // Begin signal output
                   if(!stopRunFlag)
                   {
                       startTimer1();
                       if(differentialFlag)
                       {
                           startTimer2();
                       }
                   }

               }
               // Select channel 2
               if(strInput[argIndex[1]] == '2')
               {
                   uint16_t i = 0;
                   float amplitude = 0.0;
                   float offset = 0.0;

                   // Extract frequency from user input
                   frequencyB = ATOI(&strInput[argIndex[2]]);

                   // Extract amplitude from user input
                   ATOF(&strInput[argIndex[3]], &asciiFloat);
                   amplitude = asciiFloat;

                   // Extract offset from user input
                   if(argIndex[4])
                   {
                       ATOF(&strInput[argIndex[4]], &asciiFloat);
                       offset = GAIN_B * asciiFloat + OFS_B;
                   }
                   else
                   {
                       offset = OFS_B;
                   }

                   // Set waveform bounds and calculate range
                   uint16_t min = (uint16_t)(offset - GAIN_B * amplitude / 2);
                   uint16_t max = (uint16_t)(offset + GAIN_B * amplitude / 2);
                   uint16_t range = 0;

                   if(max > min)
                   {
                       range = max - min;

                       // Set LUT-B
                       phaseB = 0;
                       for(i=0;i<MAX_LUT;i++)
                       {
                           lutB[i] = max - range * i / 2048;
                       }
                   }
                   else
                   {
                       range = min - max;
                       max = min;

                       // Set LUT-B
                       phaseB = 0;
                       for(i=0;i<MAX_LUT;i++)
                       {
                           lutB[i] = max - range * i / 2048;
                       }
                   }

                   // Set OFS value
                   writeDacB(offset);

                   // Set waveform running flag
                   waveformB = true;

                   // Begin signal generation
                   if(!stopRunFlag)
                   {
                       startTimer2();
                   }

                   if(levelOnFlag)
                   {
                       float gain = 0;
                       float loadVoltage = 0;

                       // Read load voltage from channel 2
                       waitMicrosecond(500000);
                       voltage(2, &loadVoltage);

                       if(!(loadVoltage <= amplitude + 0.1 && loadVoltage >= amplitude - 0.1))
                       {
                           gain = amplitude / 2 / loadVoltage;
                           amplitude = amplitude * gain;
                           sawtooth(amplitude, frequencyB, offset);
                           putsUart0("Adjusted amplitude with a gain of ");
                           FTOA(&gain, asciiOutput);
                           putsUart0(asciiOutput);
                           putsUart0("\r\n");
                       }
                   }
               }
           }

           if(!strcmp(strVerb, "triangle"))
           {
               // Select channel 1
               if(strInput[argIndex[1]] == '1')
               {
                   uint16_t i = 0;
                   float amplitude = 0.0;
                   float offset = 0.0;

                   // Extract frequency from user input
                   frequencyA = ATOI(&strInput[argIndex[2]]);
                   if(differentialFlag)
                   {
                       frequencyB = frequencyA;
                   }

                   // Extract amplitude from user input
                   ATOF(&strInput[argIndex[3]], &asciiFloat);
                   amplitude = asciiFloat;

                   // Extract offset from user input
                   if(argIndex[4])
                   {
                       ATOF(&strInput[argIndex[4]], &asciiFloat);
                       offset = GAIN_A * asciiFloat + OFS_A;
                   }
                   else
                   {
                       offset = OFS_A;
                   }

                   // Calculate waveform bounds and range
                   uint16_t min = (uint16_t)(GAIN_A * amplitude / 2);
                   uint16_t max = (uint16_t)(GAIN_A * -1.0 * amplitude / 2);
                   uint16_t range = max - min;

                   // Set LUT-A
                   phaseA = 0;
                   for(i=0;i<MAX_LUT/2;i++)
                   {
                       lutA[i] = max - range * i / (MAX_LUT/2) + offset;
                   }
                   for(i=0;i<MAX_LUT/2;i++)
                   {
                       lutA[i+(MAX_LUT/2)] = min + range * i / (MAX_LUT/2) + offset;
                   }

                   if(differentialFlag)
                   {
                       // Calculate waveform bounds and range
                       min = (uint16_t)(GAIN_B * amplitude / 2);
                       max = (uint16_t)(GAIN_B * -1.0 * amplitude / 2);
                       range = max - min;
    
                       // Set LUT-B
                       phaseB = 0;
                       for(i=0;i<MAX_LUT/2;i++)
                       {
                           lutB[i] = min + range * i / (MAX_LUT/2) + OFS_B;
                       }
                       for(i=0;i<MAX_LUT/2;i++)
                       {
                           lutB[i+(MAX_LUT/2)] = max - range * i / (MAX_LUT/2) + OFS_B;
                       }
                   }

                   // Set OFS value
                   writeDacA(max);
                   if(differentialFlag)
                   {
                       writeDacA(min);
                       writeDacB(max);
                   }

                   // Set waveform running flag
                   waveformA = true;
                   if(differentialFlag)
                   {
                       waveformB = true;
                   }

                   // Begin signal output
                   if(!stopRunFlag)
                   {
                       startTimer1();
                       if(differentialFlag)
                       {
                           startTimer2();
                       }
                   }
               }
               // Select channel 2
               if(strInput[argIndex[1]] == '2')
               {
                   uint16_t i = 0;
                   float amplitude = 0.0;
                   float offset = 0.0;

                   // Extract frequency from user input
                   frequencyB = ATOI(&strInput[argIndex[2]]);

                   // Extract amplitude from user input
                   ATOF(&strInput[argIndex[3]], &asciiFloat);
                   amplitude = asciiFloat;

                   // Extract offset from user input
                   if(argIndex[4])
                   {
                       ATOF(&strInput[argIndex[4]], &asciiFloat);
                       offset = GAIN_B * asciiFloat + OFS_B;
                   }
                   else
                   {
                       offset = OFS_B;
                   }

                   // Calculate waveform bounds and range
                   uint16_t min = (uint16_t)(GAIN_B * amplitude / 2);
                   uint16_t max = (uint16_t)(GAIN_B * -1.0 * amplitude / 2);
                   uint16_t range = max - min;

                   phaseB = 0;
                   for(i=0;i<MAX_LUT/2;i++)
                   {
                       lutB[i] = max - range * i / (MAX_LUT/2) + offset;
                   }
                   for(i=0;i<MAX_LUT/2;i++)
                   {
                       lutB[i+(MAX_LUT/2)] = min + range * i / (MAX_LUT/2) + offset;
                   }

                   // Set OFS value
                   writeDacB(min);

                   // Set waveform running flag
                   waveformB = true;

                   // Begin signal output
                   if(!stopRunFlag)
                   {
                       startTimer2();
                   }

                   if(levelOnFlag)
                   {
                       float gain = 0;
                       float loadVoltage = 0;

                       // Read load voltage from channel 2
                       waitMicrosecond(500000);
                       voltage(2, &loadVoltage);

                       if(!(loadVoltage <= amplitude + 0.1 && loadVoltage >= amplitude - 0.1))
                       {
                           gain = amplitude / 2 / loadVoltage;
                           amplitude = amplitude * gain;
                           triangle(amplitude, frequencyB, offset);
                           putsUart0("Adjusted amplitude with a gain of ");
                           FTOA(&gain, asciiOutput);
                           putsUart0(asciiOutput);
                           putsUart0("\r\n");
                       }
                   }
               }
           }

           if(!strcmp(strVerb, "cycles"))
           {
               // Select channel 1
               if(strInput[argIndex[1]] == '1')
               {
                   // Extract cycle count from user input
                   cycleLimiterA = ATOI(&strInput[argIndex[2]]);
                   cycleCounterA = cycleLimiterA;
               }
               // Select channel 2
               if(strInput[argIndex[1]] == '2')
               {
                   // Extract cycle count from user input
                   cycleLimiterB = ATOI(&strInput[argIndex[2]]);
                   cycleCounterB = cycleLimiterB;
               }
           }

           if(!strcmp(strVerb, "stop"))
           {
               stopRunFlag = true;
               stopTimer1();
               stopTimer2();
               stopTimer3();
               stopTimer4();
               writeDacA(OFS_A);
               writeDacB(OFS_B);
           }

           if(!strcmp(strVerb, "run"))
           {
               if(squareWaveA)
               {
                   startTimer3();
               }
               else
               {
                   startTimer1();
               }

               if(squareWaveB)
               {
                   startTimer4();
               }
               else
               {
                   startTimer2();
               }

               stopRunFlag = false;
           }

           if(!strcmp(strVerb, "voltage"))
           {
               // Select channel 1
               if(strInput[argIndex[1]] == '1')
               {
                   float v = 0;
                   voltage(1, &v);

                   FTOA(&v, asciiOutput);
                   putsUart0(asciiOutput);
                   putsUart0("V\r\n");
               }
               // Select channel 2
               if(strInput[argIndex[1]] == '2')
               {
                   float v = 0;
                   voltage(2, &v);

                   FTOA(&v, asciiOutput);
                   putsUart0(asciiOutput);
                   putsUart0("V\r\n");
               }
           }

           if(!strcmp(strVerb, "gain"))
           {
               uint16_t gainFrequencyA = 0;
               uint16_t gainFrequencyB = 0;

               uint16_t adcValueA = 0;
               uint16_t adcValueB = 0;


               // Extract frequencyA from user input
               gainFrequencyA = ATOI(&strInput[argIndex[1]]);

               // Extract frequencyB from user input
               gainFrequencyB = ATOI(&strInput[argIndex[2]]);

               // Start UART table
               putsUart0("Frequency, Gain(db)\r\n");

               // Calculate gain at linear interval
               for(;gainFrequencyA <= gainFrequencyB;gainFrequencyA+=100)
               {
                   // Create sinusoids with current frequency value
                   frequencyB = gainFrequencyA;
                   sine(4.0, gainFrequencyA);
                   waitMicrosecond(1000000);

                   // Read AIN values
                   setAdc0Ss3Mux(0x8);
                   adcValueA = readAdc0Ss3();

                   setAdc0Ss3Mux(0x9);
                   adcValueB = readAdc0Ss3();

                   // Perform Gain calculation in decibels
                   asciiFloat = 20 * log10(adcValueA / (float)adcValueB);

                   // Output current frequency
                   putsUart0(ITOA(gainFrequencyA, asciiOutput));
                   putsUart0(", ");

                   // Output gain in tabular format
                   FTOA(&asciiFloat, asciiOutput);
                   putsUart0(asciiOutput);
                   putsUart0("\r\n");
               }
               stopTimer2();
               putsUart0("Built gain table.\r\n");

           }

           if(!strcmp(strVerb, "level"))
           {

               if(strInput[argIndex[1]] == 'o' && strInput[argIndex[1]+1] == 'n')
               {
                   levelOnFlag = true;
               }
               else
               {
                   levelOnFlag = false;
               }
           }

           if(!strcmp(strVerb, "reset"))
           {
               NVIC_APINT_R = NVIC_APINT_VECTKEY | NVIC_APINT_SYSRESETREQ;
           }

           if(!strcmp(strVerb, "differential"))
           {
               if(strInput[argIndex[1]] == 'o' && strInput[argIndex[1]+1] == 'n')
               {
                   differentialFlag = true;
               }
               else
               {
                   differentialFlag = false;
               }
           }
       }
       else
       {
          putsUart0("\r\nCommand not valid, select from the following:\r\n");
          putsUart0("1. DC [1/2] [VOLTAGE (-5.0) - 5.0]\r\n");
          putsUart0("2. SINE [1/2] [FREQ] [AMP] [OFS]\r\n");
          putsUart0("3. SQUARE [1/2] [FREQ] [AMP] [OFS]\r\n");
          putsUart0("4. SAWTOOTH [1/2] [FREQ] [AMP] [OFS]\r\n");
          putsUart0("5. TRIANGLE [1/2] [FREQ] [AMP] [OFS]\r\n");
          putsUart0("6. CYCLES [1/2] [N]\r\n");
          putsUart0("7. STOP/RUN\r\n");
          putsUart0("8. VOLTAGE [1/2]\r\n");
          putsUart0("9. GAIN [FREQ1] [FREQ2]\r\n");
          putsUart0("10. LEVEL [ON/OFF]\r\n");
          putsUart0("11. DIFFERENTIAL [ON/OFF]\r\n");
       }

       fieldCount = 0;
    }
}
