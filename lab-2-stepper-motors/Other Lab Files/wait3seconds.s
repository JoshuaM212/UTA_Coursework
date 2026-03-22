

	.def wait3seconds

.thumb

.const
NUMBER              .field   0x00B71B00   ; 12,000,000

.text

wait3seconds:     ; 1+1+(n)+((n-1)+1*3)+((n-1)*6)+((n-1)*2)

loop0:	LDR R1, NUMBER
loop1:	SUB	R1, R1, #1
		CBZ	R1, done0
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		B	loop1

done0:	SUB R0, R0, #1
		BX	LR
