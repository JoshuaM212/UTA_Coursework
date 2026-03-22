// I2C Stop Go C Example
// Jason Losh
//-----------------------------------------------------------------------------
// Hardware Target
//-----------------------------------------------------------------------------

// Target Platform: EK-TM4C123GXL
// Target uC:       TM4C123GH6PM
// System Clock:    40 MHz
// Stack:           4096 bytes (needed for sprintf)

// Hardware configuration:
// UART Interface:
//   U0TX (PA1) and U0RX (PA0) are connected to the 2nd controller
//   The USB on the 2nd controller enumerates to an ICDI interface and a virtual COM port
//   Configured to 115,200 baud, 8N1

// I2C devices on I2C bus 0 with 2kohm pullups on SDA (PB3) and SCL (PB2)

//-----------------------------------------------------------------------------
// Device includes, defines, and assembler directives
//-----------------------------------------------------------------------------
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <ctype.h>
#include "tm4c123gh6pm.h"
#include "clock.h"
#include "uart0.h"
#include "i2c0.h"
#include "wait.h"


// Range of polled devices
// 0 for general call, 1-3 for compatible i2c variants
// 120-123 are for 10-bit address mode
// 123-127 reserved
#define MIN_I2C_ADD 0x08
#define MAX_I2C_ADD 0x77

#define MAX_CHARS 80

char str[80];



int16_t temp_table [381] = {-80, -79, -78, -77, -76, -75, -74, -73, -72, -71,
                            -70, -69, -68, -67, -66, -65, -64, -63, -62, -61,
                            -60, -59, -58, -57, -56, -55, -54, -53, -52, -51,
                            -50, -49, -48, -47, -46, -45, -44, -43, -42, -41,
                            -40, -39, -38, -37, -36, -35, -34, -33, -32, -31,
                            -30, -29, -28, -27, -26, -25, -24, -23, -22, -21,
                            -20, -19, -18, -17, -16, -15, -14, -13, -12, -11,
                            -10,  -9,  -8,  -7,  -6,  -5,  -4,  -3,  -2,  -1,
                              0,   1,   2,   3,   4,   5,   6,   7,   8,   9,
                             10,  11,  12,  13,  14,  15,  16,  17,  18,  19,
                             20,  21,  22,  23,  24,  25,  26,  27,  28,  29,
                             30,  31,  32,  33,  34,  35,  36,  37,  38,  39,
                             40,  41,  42,  43,  44,  45,  46,  47,  48,  49,
                             50,  51,  52,  53,  54,  55,  56,  57,  58,  59,
                             60,  61,  62,  63,  64,  65,  66,  67,  68,  69,
                             70,  71,  72,  73,  74,  75,  76,  77,  78,  79,
                             80,  81,  82,  83,  84,  85,  86,  87,  88,  89,
                             90,  91,  92,  93,  94,  95,  96,  97,  98,  99,
                      100, 101, 102,  103,  104,  105,  106,  107,  108,  109,
                      110, 111, 112,  113,  114,  115,  116,  117,  118,  119,
                      120, 121, 122,  123,  124,  125,  126,  127,  128,  129,
                      130, 131, 132,  133,  134,  135,  136,  137,  138,  139,
                      140, 141, 142,  143,  144,  145,  146,  147,  148,  149,
                      150, 151, 152,  153,  154,  155,  156,  157,  158,  159,
                      160, 161, 162,  163,  164,  165,  166,  167,  168,  169,
                      170, 171, 172,  173,  174,  175,  176,  177,  178,  179,
                      180, 181, 182,  183,  184,  185,  186,  187,  188,  189,
                      190, 191, 192,  193,  194,  195,  196,  197,  198,  199,
                      200, 201, 202,  203,  204,  205,  206,  207,  208,  209,
                      210, 211, 212,  213,  214,  215,  216,  217,  218,  219,
                      220, 221, 222,  223,  224,  225,  226,  227,  228,  229,
                      230, 231, 232,  233,  234,  235,  236,  237,  238,  239,
                      240, 241, 242,  243,  244,  245,  246,  247,  248,  249,
                      250, 251, 252,  253,  254,  255,  256,  257,  258,  259,
                      260, 261, 262,  263,  264,  265,  266,  267,  268,  269,
                      270, 271, 272,  273,  274,  275,  276,  277,  278,  279,
                      280, 281, 282,  283,  284,  285,  286,  287,  288,  289,
                      290, 291, 292,  293,  294,  295,  296,  297,  298,  299,
                      300};

float volt_table[381] = {-2.920, -2.887, -2.854, -2.821, -2.788, -2.755, -2.721, -2.688, -2.654, -2.620, // -80 to -71
                         -2.587, -2.553, -2.519, -2.485, -2.450, -2.416, -2.382, -2.347, -2.312, -2.278, // -70 to -61
                         -2.243, -2.208, -2.173, -2.138, -2.103, -2.067, -2.032, -1.996, -1.961, -1.925, // -60 to -51
                         -1.889, -1.854, -1.818, -1.782, -1.745, -1.709, -1.673, -1.637, -1.600, -1.564, // -50 to -41
                         -1.527, -1.490, -1.453, -1.417, -1.380, -1.343, -1.305, -1.268, -1.231, -1.194, // -40 to -31
                         -1.156, -1.119, -1.081, -1.043, -1.006, -0.968, -0.930, -0.892, -0.854, -0.816, // -30 to -21
                         -0.778, -0.739, -0.701, -0.663, -0.624, -0.586, -0.547, -0.508, -0.470, -0.431, // -20 to -11
                         -0.392, -0.353, -0.314, -0.275, -0.236, -0.197, -0.157, -0.118, -0.079, -0.039, // -10 to  -1
                          0.000,  0.039,  0.079,  0.119,  0.158,  0.198,  0.238,  0.277,  0.317,  0.357, //   0 to  9
                          0.397,  0.437,  0.477,  0.517,  0.557,  0.597,  0.637,  0.677,  0.718,  0.758, //  10 to  19
                          0.798,  0.838,  0.879,  0.919,  0.960,  1.000,  1.041,  1.081,  1.122,  1.168, //  20 to  29
                          1.203,  1.244,  1.285,  1.326,  1.366,  1.407,  1.448,  1.489,  1.530,  1.571, //  30 to  39
                          1.612,  1.653,  1.694,  1.735,  1.776,  1.817,  1.858,  1.899,  1.941,  1.982, //  40 to  49
                          2.023,  2.064,  2.106,  2.147,  2.188,  2.230,  2.271,  2.312,  2.354,  2.395, //  50 to  59
                          2.436,  2.478,  2.519,  2.561,  2.602,  2.644,  2.685,  2.727,  2.768,  2.810, //  60 to  69
                          2.851,  2.893,  2.934,  2.976,  3.017,  3.059,  3.100,  3.142,  3.184,  3.225, //  70 to  79
                          3.267,  3.308,  3.350,  3.391,  3.433,  3.474,  3.516,  3.557,  3.599,  3.640, //  80 to  89
                          3.682,  3.723,  3.765,  3.806,  3.848,  3.889,  3.931,  3.972,  4.013,  4.055, //  90 to  99
                          4.096,  4.138,  4.179,  4.220,  4.262,  4.303,  4.344,  4.385,  4.427,  4.468, // 100 to 109
                          4.509,  4.550,  4.591,  4.633,  4.674,  4.715,  4.756,  4.797,  4.838,  4.879, // 110 to 119
                          4.920,  4.961,  5.002,  5.043,  5.084,  5.124,  5.165,  5.206,  5.247,  5.288, // 120 to 129
                          5.328,  5.369,  5.410,  5.450,  5.491,  5.532,  5.572,  5.613,  5.653,  5.694, // 130 to 139
                          5.735,  5.775,  5.815,  5.856,  5.896,  5.937,  5.977,  6.017,  6.058,  6.098, // 140 to 149
                          6.138,  6.179,  6.219,  6.259,  6.299,  6.339,  6.380,  6.420,  6.460,  6.500, // 150 to 159
                          6.540,  6.580,  6.620,  6.660,  6.701,  6.741,  6.781,  6.821,  6.861,  6.901, // 160 to 169
                          6.941,  6.981,  7.021,  7.060,  7.100,  7.140,  7.180,  7.220,  7.260,  7.300, // 170 to 179
                          7.340,  7.380,  7.420,  7.460,  7.500,  7.540,  7.579,  7.619,  7.659,  7.699, // 180 to 189
                          7.739,  7.779,  7.819,  7.859,  7.899,  7.939,  7.979,  8.019,  8.059,  8.099, // 190 to 199
                          8.138,  8.178,  8.218,  8.258,  8.298,  8.338,  8.378,  8.418,  8.458,  8.499, // 200 to 209
                          8.539,  8.579,  8.619,  8.659,  8.699,  8.739,  8.779,  8.819,  8.860,  8.900, // 210 to 219
                          8.940,  8.980,  9.020,  9.061,  9.101,  9.141,  9.181,  9.222,  9.262,  9.302, // 220 to 229
                          9.343,  9.383,  9.423,  9.464,  9.504,  9.545,  9.585,  9.626,  9.666,  9.707, // 230 to 239
                          9.747,  9.788,  9.828,  9.869,  9.909,  9.950,  9.991, 10.031, 10.072, 10.113, // 240 to 249
                         10.153, 10.194, 10.235, 10.276, 10.316, 10.357, 10.398, 10.439, 10.480, 10.520, // 250 to 259
                         10.561, 10.602, 10.643, 10.684, 10.725, 10.766, 10.807, 10.848, 10.889, 10.930, // 260 to 269
                         10.971, 11.012, 11.053, 11.094, 11.135, 11.176, 11.217, 11.259, 11.300, 11.341, // 270 to 279
                         11.382, 11.423, 11.465, 11.506, 11.547, 11.588, 11.630, 11.671, 11.712, 11.753, // 280 to 289
                         11.795, 11.836, 11.877, 11.919, 11.960, 12.001, 12.043, 12.084, 12.126, 12.167, // 290 to 299
                         12.209};

float temp2volt(int16_t temperature)
{
    float ret = -999.999;
    if (temperature >= -80 && temperature <= 300)
        ret = volt_table[temperature+80];

    return ret;
}

int16_t volt2temp(float volts)
{
    int16_t ret = 999;
    int16_t i = 0;
    sprintf(str,"%f >= -2.921 && %f <= 12.211: %d\n", volts, volts, volts >= -2.921 && volts <= 12.211);
    putsUart0(str);
    if (volts >= -2.921 && volts <= 12.211)
    {
        for (i=0;i<381;i++)
        {
            if (volt_table[i] == volts)
                ret = i - 80;
        }
    }

    return ret;
}

// Initialize Hardware
void initHw()
{
    // Initialize system clock to 40 MHz
    initSystemClockTo40Mhz();
}

void getsUart0(char str[], uint8_t size)
{
    uint8_t count = 0;
    bool end = false;
    char c;
    while(!end)
    {
        c = getcUart0();
        end = (c == 13) || (count == size);
        if (!end)
        {
            if ((c == 8 || c == 127) && count > 0)
                count--;
            if (c >= ' ' && c < 127)
                str[count++] = c;
        }
    }
    str[count] = '\0';
}

uint8_t asciiToUint8(const char str[])
{
    uint8_t data;
    if (str[0] == '0' && tolower(str[1]) == 'x')
        sscanf(str, "%hhx", &data);
    else
        sscanf(str, "%hhu", &data);
    return data;
}


//-----------------------------------------------------------------------------
// Main
//-----------------------------------------------------------------------------

int main(void)
{
    // Initialize hardware
    initHw();
    initUart0();
    initI2c0();

    // Setup UART0 baud rate
    setUart0BaudRate(115200, 40e6);

    putsUart0("I2C0 Utility\r\n");
    uint16_t ADC_sum = 0;
    uint16_t adc_cj  = 0;
    int16_t adc_tc  = 0;
    // uint8_t  *p      = 0;
    float    volt_cj = 0;
    float    temp_cj = 0;
    float    prev_volt_tc = 0;
    float    volt_tc = 0;
    float    temp_tc = 0;
    float    volt_sum = 0;
    float    temp_final = 0;


    float temp_1;
    float temp_2;
    float v_1;
    float v_2;

    while(true)
       {
            // Set TMP36 ADS1115 config register value
            uint8_t m[2] = {0xE5, 0x03};
            writeI2c0Registers(0x48, 1, m, 2);
            waitMicrosecond(500000);

            // Read TMP36 value from AIN2
            putsUart0("Cold Junction Values:\r\n");
            uint8_t p[2] = {0x00, 0x00};
            readI2c0Registers(0x48, 0, p, 2);
            adc_cj  = (p[0]<<8) | p[1];  //62.5

            volt_cj = (float)(adc_cj * (62.5/1000000));
            temp_cj = (volt_cj-0.5)*100;

            sprintf(str, "Cold Junction real: %d\r\n\n", adc_cj);
            putsUart0(str);
            sprintf(str, "Cold Junction volt: %4.3fmV\r\n\n", volt_cj);
            putsUart0(str);


            sprintf(str, "Cold Junction temp: %f\r\n\n", temp_cj);
            putsUart0(str);

            putsUart0("\r\n");

           uint8_t k[2] = {0x8B, 0x03};
           writeI2c0Registers(0x48, 1, k, 2);
           waitMicrosecond(500000);

           // Read Thermocouple value from AIN0/AIN1
           putsUart0("Thermocouple Value: \r\n");
           uint8_t q[2] = {0x00, 0x00};
           readI2c0Registers(0x48, 0, q, 2);
           adc_tc = 0;
           adc_tc  = (q[0]<<8) | q[1];
           prev_volt_tc = (float)adc_tc * (7.8125/1000);

           // FIX THIS CONVERSION LATER
            volt_tc = prev_volt_tc; // ((prev_volt_tc) - 0.825)*-4;

           sprintf(str, "TC real: %d\r\n\n", adc_tc);
           putsUart0(str);

           sprintf(str, "TC volts: %f\r\n\n", volt_tc);
           putsUart0(str);

           int16_t y;
           for (y = 0;y<380;y++)
           {
               if (volt_table[y] < volt_tc && volt_table[y+1] > volt_tc)
               {
                   temp_tc = temp_table[y];
                   break;
               }
           }
           sprintf(str, "TC temp: %f\r\n\n", temp_tc);
           putsUart0(str);

           // Allow time for user to view data
           waitMicrosecond(500000);

           // Calculate voltage sum
           volt_sum = prev_volt_tc + volt_cj;

           // Get values from table and interpolate final temperature value
           int16_t j;
           for (j = 0;j<380;j++)
           {
               if (volt_table[j] < volt_sum && volt_table[j+1] > volt_sum)
               {
                   temp_final = ((temp_table[j+1] - temp_table[j]) / (volt_table[j+1] - volt_table[j])) * (volt_cj - volt_table[j]) + temp_table[j];
                   break;
               }
           }

           // Display final temperature value
           sprintf(str, "Thermocouple contact (final temp) is %6.2f degrees\r\n\r\n", temp_final);
           putsUart0(str);
           printf("\n");
       }
}


