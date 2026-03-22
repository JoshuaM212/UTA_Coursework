#include <stdint.h>

#define LED *((volatile uint32_t *) (uint32_t *)0x80000004)
#define SW  *((volatile uint32_t *) (uint32_t *)0x80000000)

int main(void)
{
    uint32_t i;
    LED = 0;
    while(1)
    {
        LED ^= 1;
        i = 0;
        while(i < 1000000)
            i++;
    }
    return 0;
}

