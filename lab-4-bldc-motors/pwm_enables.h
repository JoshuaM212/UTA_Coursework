// Motor Control Library
// Jason Losh

//-----------------------------------------------------------------------------
// Hardware Target
//-----------------------------------------------------------------------------

// Target Platform: EK-TM4C123GXL
// Target uC:       TM4C123GH6PM
// System Clock:    -

// Hardware configuration:
// Servo motor drive:
//   PWM output on M1PWM0 (PD0)

//-----------------------------------------------------------------------------
// Device includes, defines, and assembler directives
//-----------------------------------------------------------------------------

#ifndef PWM_ENABLES_H_
#define PWM_ENABLES_H_

//-----------------------------------------------------------------------------
// Subroutines
//-----------------------------------------------------------------------------

void initPwmEnables();
void setPwmEnableA(unsigned int dutyCycle);
void setPwmEnableB(unsigned int dutyCycle);

#endif
