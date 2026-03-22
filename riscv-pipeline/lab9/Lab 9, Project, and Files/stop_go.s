.globl _start

.text

_start:

    LA      t0, 0x20000
    LA      gp, 0x8000
    LA      t2, 0x20008
    LA      a4, 0x1
    LA      a5, 0x55
    SW      a5, 12(t0)    
    SW      a4, 0x400(gp)
    LW      a5, 0x400(gp)
    ADDI    a5, a5, 4
    SW      a5, 12(t0)
loop:
    LW      t3, (t2)
    ANDI    t3, t3, 1024
    BEQZ    t3, loop
    LA      a5, 0x2
    SW      a5, 12(t0)
    NOP
    NOP
    NOP
    NOP
    EBREAK
    NOP
    NOP
    NOP
    
.end

