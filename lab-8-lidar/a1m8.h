//-----------------------------------------------------------------------------
// Hardware Target
//-----------------------------------------------------------------------------

// Target Platform: EK-TM4C123GXL
// Target uC:       TM4C123GH6PM
// System Clock:    -

// Hardware configuration:
// 16 MHz external crystal oscillator

//-----------------------------------------------------------------------------
// Device includes, defines, and assembler directives
//-----------------------------------------------------------------------------

#ifndef A1M8_H_
#define A1M8_H_

typedef struct{
    char model;
    char firmware_minor;
    char firmware_major;
    char hardware;
    char serial_number[16];
} info_response;

typedef struct {
    char quality;
    char angle_q6_l;
    char angle_q6_h;
    char distance_q2_l;
    char distance_q2_h;
} scan_response;

//-----------------------------------------------------------------------------
// Subroutines
//-----------------------------------------------------------------------------

void a1m8_stop_request();
void a1m8_info_request();
info_response get_a1m8_info();
void a1m8_scan_request();
scan_response get_a1m8_scan();

#endif
