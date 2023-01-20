            PAGE 0                  ; suppress page headings in ASW listing file

            include "bitfuncs.inc"

; 8048 LED blink program

            cpu 8048

CR          equ 0DH
LF          equ 0AH

pattern     reg R2                  ; pointer to the LED pattern
delaytm     reg R3                  ; delay time in milliseconds
length      reg R4                  ; length of the LED pattern
saveA       reg R5                  ; register for saving contents of Accumulator
count       reg R6                  ; loop counter
offset      reg R7                  ; offset to the selected LED pattern

            org 0000H               ; reset
reset:      jmp entry

            org 0003H               ; external interrupt
extisr:     retr

            org 0007H               ; timer overflow interrupt
timerisr:   retr

            org 0010H
entry:      dis I                   ; disable external interrupt
            dis TCNTI               ; disable timer overflow interrupt
            mov A,#0FFH
            outl P1,A               ; turn off all LEDs
            mov R0,#lo(signontxt)
            call txtout             ; prompt for the pattern selection

choose:     call getch              ; get the pattern selection input
            mov R3,A                ; move the input character to R3 for compare
            mov A,#'1'
            call compare            ; is it '1'?
            jnz choose1             ; jump if not '1'
            mov offset,#18*0        ; else, store offset to the first array in R7
            jmp choose4

choose1:    mov A,#'2'
            call compare            ; is it '2'?
            jnz choose2             ; jump if not '2'
            mov offset,#18*1        ; else, store offset to the second array in R7
            jmp choose4

choose2:    mov A,#'3'
            call compare            ; is it '3'?
            jnz choose3             ; jump if not '3'
            mov offset,#18*2        ; else, store offset to the third array in R7
            jmp choose4

choose3:    mov A,#'4'
            call compare            ; is it '4'?
            jnz choose              ; jump if not '4'
            mov offset,#18*3        ; else, store offset to the fourth array in R7

choose4:    mov A,R3
            call putch              ; it's a valid choice, so echo the character
            call newline            ; start on a new line

loop:       mov A,#lo(array)        ; point to delay in the first array
            add A,offset            ; add the offset in R7 depending on the choice
            movp A,@A               ; look up the delay in milliseconds
            mov delaytm,A           ; save it in R3

loop1:      mov A,#lo(array+1)      ; point to length in the first array
            add A,offset            ; add the offset in R7 depending on the choice
            movp A,@A               ; look up the length of the pattern sequence
            mov length,A            ; save it in R4

            mov pattern,#lo(array+2); point to the pattern sequence in the first array
            mov A,pattern           ; move it from R2 to the Accumulator
            add A,offset            ; add the offset in R7 to the pointer depending on the choice
            mov pattern,A           ; save the pointer in R2

loop2:      mov A,pattern           ; retrieve the pointer to the LED pattern from R2
            movp A,@A               ; look up the led pattern from program memory
            outl P1,A               ; output the pattern to port 1 to light the LEDs

            mov saveA,A             ; save the current value of A in R5
            mov A,delaytm           ; get the delay value from R3
            mov count,A             ; move the delay value to the counter to R6
            mov A,saveA             ; restore the previous value of A from R5

            call _1mSec             ; 1 millisecond delay
            djnz count,$-2          ; number if millseconds to delay in R6
            inc pattern             ; increment the pointer in R2 to point to the next pattern in the sequence
            djnz length,loop2       ; loop through all the patterns in the selection
            jmp loop1               ; back to start

_1mSec:     mov R0,#2
            mov R1,#164
            djnz R1,$
            djnz R0,$-4
            jnt0 entry              ; start over if key is pressed
            ret

            ; delay in mSec, length of pattern in bytes, LED pattern
            ; LED cathodes are connected to P1, so driving them low sinks current and light the LEDs
array       db 50, 8,01111110B,01111110B,10111101B,11011011B,11100111B,11011011B,10111101B,01111110B,11111111B,11111111B,11111111B,11111111B,11111111B,11111111B,11111111B,11111111B
            db 100,9,11111111B,01111111B,00111111B,00011111B,00001111B,00000111B,00000011B,00000001B,00000000B,11111111B,11111111B,11111111B,11111111B,11111111B,11111111B,11111111B
            db 50,14,01111111B,10111111B,11011111B,11101111B,11110111B,11111011B,11111101B,11111110B,11111101B,11111011B,11110111B,11101111B,11011111B,10111111B,11111111B,11111111B
            db 50,16,11111111B,01111111B,00111111B,00011111B,00001111B,00000111B,00000011B,00000001B,00000000B,10000000B,11000000B,11100000B,11110000B,11111000B,11111100B,11111110B

            org 0200H
;------------------------------------------------------------------------
; sends the character in A out from the serial output (P2.7)
; uses A, R6 and R7 in register bank 1.
;------------------------------------------------------------------------
putch:      sel RB1
            anl P2,#7FH             ; make serial output low to send the start bit
            mov R6,#8               ; load R6 with the number of bits to send
            mov R7,#(58-2)/2        ; load the number of cycles to delay into R7
            call delay              ; delay 58 cycles
            nop

            ;send bits 0-7
putch1:     jb0 putch2              ; jump if the bit to send is "1"
            anl P2,#7FH             ; else, send "0"
            jmp putch3              ; skip the next part
putch2:     orl P2,#80H             ; send "1"
            jmp putch3              ; makes the timing equal for both "0" and "1" bits
putch3:     rr A                    ; rotate the next bit into position
            mov R7,#(56-2)/2        ; load the number of cycles to delay into R7
            call delay              ; delay 56 cycles
            djnz R6,putch1          ; loop to send all 8 bits

            ;send the stop bit
            nop
            nop
            orl P2,#80H             ; make serial output high to send the stop bit
            mov R7,#(34-2)/2        ; load the number of cycles to delay into R7
            call delay              ; delay 34 cycles (1/2 bit time)
            sel RB0
            ret

;------------------------------------------------------------------------
; waits for a character from the serial input (T0).
; returns the character in A.
; uses A, R6 and R7 in register bank 1.
;------------------------------------------------------------------------
getch:      sel RB1
            jt0 $                   ; wait here for the start bit
            clr A                   ; start with A cleared
            mov R6,#8               ; load the number of bits to receive into R6
            mov R7,#(30-2)/2        ; load the number of cycles to delay into R7
            call delay              ; delay 30 cycles (1/2 bit time)

            ;get bits 0-7
getch1:     mov R7,#(56-2)/2        ; load the number of cycles to delay into R7
            call delay              ; delay 56 cycles (1 bit time)
            jnt0 getch2             ; jump if the serial input is zero
            orl A,#01H              ; else, set the bit of the recieved character
            jmp getch3              ; skip the next part
getch2:     anl A,#0FEH             ; clear the bit of the received character
            jmp getch3              ; makes the timing equal for both "0" and "1" bits
getch3:     rr A                    ; rotate the bits in the received character right
            djnz R6,getch1          ; loop to receive all 8 bits

            ;stop bit
            mov R7,#(34-2)/2        ; load the number of cycles to delay into R7
            call delay              ; delay 34 cycles (1/2 bit time) for the stop bit
            sel RB0
            ret

;------------------------------------------------------------------------
; waits for a character from the serial input (T0).
; echos the character bit by bit (output on P2.7).
; returns the character in A.
; uses A, R6 and R7 in register bank 1.
;------------------------------------------------------------------------
getche:     sel RB1
            jt0 $                   ; wait here for the start bit
            clr A                   ; start with A cleared
            mov R6,#8               ; load the number of bits to receive into R6
            mov R7,#(26-2)/2        ; load the number of cycles to delay into R7
            call delay              ; delay 26 cycles (1/2 bit time)
            anl P2,#7FH             ; make serial output low to send the start bit
            mov R7,#(4-2)/2         ; load the number of cycles to delay into R7
            call delay              ; delay 4 cycles

            ;get bits 0-7
getche1:    mov R7,#(54-2)/2        ; load the number of cycles to delay into R7
            call delay              ; delay 54 cycles (1 bit time)
            jnt0 getche2            ; jump if the serial input is zero
            orl P2,#80H             ; send "1"
            orl A,#01H              ; else, set the bit of the recieved character
            jmp getche3             ; skip the next part
getche2:    anl P2,#7FH             ; else, send "0"
            anl A,#0FEH             ; clear the bit of the received character
            jmp getche3             ; makes the timing equal for both "0" and "1" bits
getche3:    rr A                    ; rotate the bits in the received character right
            djnz R6,getche1         ; loop to receive all 8 bits

            ;stop bit
            mov R7,#(56-2)/2        ; load the number of cycles to delay into R7
            call delay              ; delay 56 cycles (1 bit time)
            orl P2,#80H             ; make serial output high to send the stop bit
            mov R7,#(56-2)/2        ; load the number of cycles to delay into R7
            call delay              ; delay 56 cycles (1 bit time) for the stop bit
            sel RB0
            ret

;------------------------------------------------------------------------
; compare the value in R3 to the value in the Accumulator.
; returns with zero flag set if the values are equal.
; returns with carry flag set if the value in R0 is equal to or greater than the value in the Accumulator.
; returns with carry flag cleared if the value in R0 is less than the value in the Accumulator.
;------------------------------------------------------------------------
compare:    cpl A
            inc A
            add A,R3
            ret

;------------------------------------------------------------------------
; print carriage return and line feed
;------------------------------------------------------------------------
newline:    mov A,#CR
            call putch
            mov A,#LF
            jmp putch

;------------------------------------------------------------------------
; print the string in page 3 of program memory pointed to by R0.
; the string must be terminated by zero.
; uses R0
;------------------------------------------------------------------------
txtout:     mov A,R0
            movp3 A,@A          ; move to A from page 3 of program memory
            anl A,#07FH
            jz txtdone
            call putch
            inc R0
            jmp txtout
txtdone:    ret

;------------------------------------------------------------------------
; delay the number of cycles in R7
; mov R7,#(cycles-2)/2      ; load R7 with number of cycles to delay
; call delay                ; call the delay function
; uses R7 in register bank 1
;------------------------------------------------------------------------
delay:      djnz R7,delay
            ret

            org 0300H       ; page 3 of program memory
signontxt   db  CR,LF,LF,LF
            db  "8048 LED Demo",CR,LF
            db  "Assembled on ",DATE," at ",TIME,CR,LF,LF
            db  "LED pattern (1-4)? ",0

            end