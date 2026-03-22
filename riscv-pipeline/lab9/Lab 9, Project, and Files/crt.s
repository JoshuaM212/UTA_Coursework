/* 
// CSE 4372/5372 RISC Processor Design
// Simplified C Runtime
// J Losh
*/

.globl _start

/* put this code in the init section (attributes: accessible and executable) */
.section .init, "ax"

_start:

/* setup global pointer */
/* notes: no relax ensures that a fully qualified address is loaded in gp
          if call is +/ 2^11, then a 12-bit offset is used (relaxed address)
          __global_pointer$ is defined in the custom linker descriptor file 
            (cse4372_riscv.ld) 
          aside: normally this is placed in the middle of the global space
*/        
.option push
.option norelax
    la gp, __global_pointer$
.option pop

/* setup stack */
/* note: __stack_top is defined in the our custom cse4372_riscv.ld file
         __stack_top must be a multiple of 128-bits (16 bytes) per ABI 
*/
    la sp, __stack_top
    mv s0, sp
    
/* call main */
    jal ra, main

/* on return from main, program enters an endless loop */
/* note: according to N1570 (C11) spec, the behavior of a return from main()
         in freestanding mode (not managed by an OS) is unspecified 
*/    
loop_on_return_from_main:
    j loop_on_return_from_main

.end

