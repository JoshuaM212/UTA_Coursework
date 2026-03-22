/*
 * ui.c
 *
 *  Created on: Apr 8, 2022
 *      Author: Dario Ugalde
 */

#include <stdint.h>
#include <string.h>
#include <stdbool.h>
#include "ui.h"

uint8_t is_digit(uint8_t c)
{
    if(c >= '0' && c <= '9' )
        return c;
    if(c == '.')
        return c;
    if(c == '-')
        return c;
    return 0;
}

uint8_t is_alpha(uint8_t c)
{
    if((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z'))
    {
        if(c >= 'A' && c <= 'Z')
            return c + 32;
        else
            return c;
    }
    return 0;
}

int32_t ATOI(uint8_t* num)
{
    uint8_t i = 0;
    uint32_t result = 0;
    uint8_t negative = 0;
    if(num[0] == '-')
    {
        negative = 1;
        i++;
    }
    while(num[i] != 0 && is_digit(num[i]))
    {
        result = result * 10 + (num[i] -'0');
        i++;
    }
    if(negative)
        return result * -1;
    else
        return result;
}

uint8_t* ITOA (int16_t value, uint8_t *result)
{
    uint8_t* ptr = result, *ptr1 = result, tmp_char;
    uint16_t tmp_value;

    if(value < 0)
    {
        result[0] = '-';
        value = value * -1;
        *ptr++;
    }
    do {
        tmp_value = value;
        value /= 10;
        *ptr++ = "zyxwvutsrqponmlkjihgfedcba9876543210123456789abcdefghijklmnopqrstuvwxyz" [35 + (tmp_value - value * 10)];
    } while ( value );

    *ptr-- = '\0';
    while (ptr1 < ptr) {
        tmp_char = *ptr;
        *ptr--= *ptr1;
        *ptr1++ = tmp_char;
    }

    return result;
}

void ATOF(uint8_t* num, float* result)
{
    uint8_t i = 0;
    uint8_t negative = 0;
    *result = 0;
    if(num[0] == '-')
    {
        i++;
        negative = 1;
    }
    while(num[i] != 0)
    {
        if(num[i] == '.')
        {
            i++;
            continue;
        }
        else
        {
            *result = *result * 10 + (num[i] -'0');
            if(i > 0 || (i >= 1 && negative))
                *result = *result / 10.0;
            if(negative && i == 1)
            {
                *result = *result * 10.0;
            }
            i++;
        }
    }
    if(negative)
    {
        *result = *result * -1;
    }
    if(*result > 511)
        *result = 511;
}

void FTOA(float* value, uint8_t* result)
{
    uint8_t negative = 0;
    if(*value < 0)
    {
        negative = 1;
        *value = *value * -1;
    }
    *value = *value * 10;
    ITOA((uint8_t)*value, result);
    if(!negative)
    {
        if(*value >= 10)
        {
            result[2] = result[1];
            result[1] = '.';
        }
        else
        {
            result[2] = result[0];
            result[0] = '0';
            result[1] = '.';
        }
        result[3] = 0;
    }
    else
    {
        if(*value >= 10)
        {
            result[3] = result[1];
            result[1] = result[0];
            result[2] = '.';
        }
        else
        {
            result[3] = result[1];
            result[1] = '0';
            result[2] = '.';
        }
        result[0] = '-';
        result[4] = 0;
    }
}

void parseStr(uint8_t* strInput, uint8_t* argIndex, uint8_t* fieldCount)
{
    uint8_t count = 1;
    if(is_alpha(strInput[0])) // base case if command is first input
    {
        argIndex[0] = 0;
        *fieldCount += 1;
    }
    while(strInput[count] != 0)
    {
        if(is_alpha(strInput[count]) && (strInput[count - 1] == ' ')) // look for user commands
        {
            argIndex[*fieldCount] = count;
            *fieldCount += 1;
        }
        if(is_digit(strInput[count]) && (strInput[count - 1] == ' ')) // look for user arguments
        {
            argIndex[*fieldCount] = count;
            *fieldCount += 1;
        }
        count++;
    }
}

void getVerb(uint8_t argIndex, uint8_t* strVerb, uint8_t* strInput)
{
    uint8_t i = argIndex;
    uint8_t count = 0;
    while(is_alpha(strInput[i]))
    {
        strVerb[count] = strInput[i];
        count++;
        i++;
    }
    strVerb[count] = 0;
}

bool isCommand(uint8_t minArgs, uint8_t* strVerb)
{
    if(strcmp("dc", strVerb) == 0  && minArgs == 2)
    {
        return true;
    }
    else if(strcmp("sine", strVerb) == 0 && (minArgs == 3 || minArgs == 4))
    {
        return true;
    }
    else if(strcmp("square", strVerb) == 0 && (minArgs == 3 || minArgs == 4))
    {
        return true;
    }
    else if(strcmp("sawtooth", strVerb) == 0 && (minArgs == 3 || minArgs == 4))
    {
        return true;
    }
    else if(strcmp("triangle", strVerb) == 0 && (minArgs == 3 || minArgs == 4))
    {
        return true;
    }
    else if(strcmp("cycles", strVerb) == 0 && minArgs == 2)
    {
        return true;
    }
    else if(strcmp("stop", strVerb) == 0)
    {
        return true;
    }
    else if(strcmp("run", strVerb) == 0)
    {
        return true;
    }
    else if(strcmp("voltage", strVerb) == 0 && minArgs == 1)
    {
        return true;
    }
    else if(strcmp("gain", strVerb) == 0 && minArgs == 2)
    {
        return true;
    }
    else if(strcmp("level", strVerb) == 0 && minArgs == 1)
    {
        return true;
    }
    else if(strcmp("reset", strVerb) == 0)
    {
        return true;
    }
    else if(strcmp("differential", strVerb) == 0)
    {
        return true;
    }
    else
    {
        return false;
    }
}
