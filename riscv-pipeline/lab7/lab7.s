.globl _start

.text

_start:
    LI t1, 5
    LI t2, 10
    LI t3, -5
    LI t4, 5
    LI t5, 0

    BNE t1, t4, end
    BNE t1, t2, test1
    LI t5, 99

jalr_test:
    LA t6, loop_test
    JALR t6
    JAL end
    LI t5, 100

test1:
    LA t5, 5
    BEQ t2, t5, end
    BEQ t1, t5, test2
    LI t1, 99
    LI t1, 19
    LI t1, 29


test2:
    BLT t2, t1, end
    BLT t3, t1, test3
    LI t5, 150
    LI t1, 99
    LI t1, 19
    LI t1, 29

test3:
    BGE t1, t2, end
    BGE t1, t3, test4
    LI t5, 250
    LI t1, 99
    LI t1, 19
    LI t1, 29

test4:
    BLTU t3, t1, end
    BLTU t1, t2, test5
    LI t5, 400
    LI t1, 99
    LI t1, 19
    LI t1, 29

test5:
    BGEU t1, t2, end
    BGEU t3, t1, jal_test
    LI t5, 50
    LI t1, 99
    LI t1, 19
    LI t1, 29

jal_test:
    JAL jalr_test
    LI t5,77
    LI t1, 99
    LI t1, 19
    LI t1, 29

loop_test:
    ADDI t1, t1, 1
    BNE t1, t2, loop_test
    JAL end
    LI t4, 100
    LI t3, 200

end:
    EBREAK