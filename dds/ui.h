// User Interface Library
// Dario Ugalde

//-----------------------------------------------------------------------------
// Hardware Target
//-----------------------------------------------------------------------------

// Target Platform: EK-TM4C123GXL
// Target uC:       TM4C123GH6PM
// System Clock:    -

// Purpose:
//   Takes text data provided from end user to select feature to be executed

//-----------------------------------------------------------------------------
// Device includes, defines, and assembler directives
//-----------------------------------------------------------------------------

#ifndef UI_H_
#define UI_H_

//-----------------------------------------------------------------------------
// Subroutines
//-----------------------------------------------------------------------------

void parseStr(uint8_t* strInput, uint8_t* argIndex, uint8_t* fieldCount);
void getVerb(uint8_t argIndex, uint8_t* strVerb, uint8_t* strInput);
bool isCommand(uint8_t minArgs, uint8_t* strVerb);
uint8_t is_digit(uint8_t c);
uint8_t is_alpha(uint8_t c);
int32_t ATOI(uint8_t* num);
uint8_t* ITOA (int16_t value, uint8_t* result);
void ATOF(uint8_t* num, float* result);
void FTOA(float* value, uint8_t* result);

#endif
