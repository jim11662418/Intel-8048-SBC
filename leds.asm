            PAGE 0                  ; suppress page headings in ASW listing file

; 8048 LED blink program

; RAM:  00-07     register bank 0
;       08-17     stack
;       18-1F     register bank 1
;       20-7F     data RAM
;
; ROM:  0000-07FF memory bank 0
;       0800-0FFF memory bank 1  

            include "bitfuncs.inc"

            cpu 8048

CR          equ 0DH
LF          equ 0AH

index       reg R3                  ; pointer to the LED pattern
delaytm     reg R4                  ; delay time in milliseconds
length      reg R5                  ; length of the LED pattern in bytes
count       reg R6                  ; delay loop counter
offset      reg R7                  ; offset to the selected LED pattern

            org 0000H               ; reset
reset:      jmp start

            org 0003H               ; external interrupt
extisr:     retr

            org 0007H               ; timer overflow interrupt
timerisr:   retr

            org 0010H
start:      dis I                   ; disable external interrupt
            dis TCNTI               ; disable timer overflow interrupt
            
            mov A,#lo(signontxt)   ; display sign-on message
            call txtout
            
next:       mov A,#0FFH
            outl P1,A               ; turn off all LEDs
            mov A,#lo(prompttxt)    ; prompt for a selection digit 1-6          
            call txtout
            
choose:     call getch              ; get the pattern selection digit
            mov R3,A                ; move the selection digit to R3 for compare
            mov A,#'1'
            call compare            ; compare selection digit in R3 to '1'
            jnc choose              ; go back for another if the selection digit is less than '1'
            mov A,#'9'
            call compare            ; compare selection digit in R3 to '9'
            jc next                 ; go back for another if the selection digit is equal to or greater than '7'

            mov A,#lo(prompt1txt)   ; display 'Press any key...'
            call txtout
            mov A,R3                ; restore the selection digit from R3 to A
            anl A,#0FH              ; convert ASCII selection digit to binary by masking out most the significant nibble
            dec A                   ; decrement to make offset zero based
            mov offset,A            ; save it in R7
            jz loop0                ; jump if the offset is zero (the selection digit was '1')
            mov R1,A                ; else, use the input digit as a counter in R1
            clr A
            add A,#17                       
            djnz R1,$-2             ; add 18 (the length of each entry) for each count
            mov offset,A            ; save it in R7
           
loop0:      mov A,#lo(patterns)     ; address of the delay value of the first entry in the array
            add A,offset            ; add the offset in R7 to the address
            movp A,@A               ; look up the delay in milliseconds
            mov delaytm,A           ; save it in R4

loop1:      mov length,#16          ; each pattern is 16 bytes
            mov A,#lo(patterns+1)   ; address of the first pattern in the first entry in the array
            add A,offset            ; add the index to the offset in R7
            mov index,A             ; save the index in R3

loop2:      mov A,index             ; retrieve the index to the LED pattern from R3
            movp A,@A               ; look up the led pattern from program memory
            outl P1,A               ; output the pattern to port 1 to light the LEDs

            mov A,delaytm           ; get the delay value from R4
            mov count,A             ; move the delay value to the counter to R6

loop3:      mov R0,#165
            jnt0 next
            djnz R0,$-2
            djnz count,loop3        ; delay 'count' milliseconds
            inc index               ; increment the pointer in R3 to point to the next pattern in the sequence
            djnz length,loop2       ; loop through all the patterns in the selection
            jmp loop1               ; back to start

            ; delay in milliSeconds, LED pattern
            ; LED cathodes are connected to P1, so driving them low sinks current and light the LEDs
patterns    db 75, 01111110B,01111110B,10111101B,11011011B,11100111B,11011011B,10111101B,01111110B,01111110B,01111110B,10111101B,11011011B,11100111B,11011011B,10111101B,01111110B
            db 75, 01111111B,00111111B,00011111B,00001111B,00000111B,00000011B,00000001B,00000000B,01111111B,00111111B,00011111B,00001111B,00000111B,00000011B,00000001B,00000000B
            db 50, 01111111B,10111111B,11011111B,11101111B,11110111B,11111011B,11111101B,11111110B,11111111B,11111101B,11111011B,11110111B,11101111B,11011111B,10111111B,11111111B
            db 50, 11111111B,01111111B,00111111B,00011111B,00001111B,00000111B,00000011B,00000001B,00000000B,10000000B,11000000B,11100000B,11110000B,11111000B,11111100B,11111110B
            db 50, 01111111B,00111111B,00011111B,00001111B,00000111B,00000011B,00000001B,00000000B,11111110B,11111100B,11111000B,11110000B,11100000B,11000000B,10000000B,00000000B
            db 100,01111110B,00111100B,00011000B,00000000B,01111110B,00111100B,00011000B,00000000B,01111110B,00111100B,00011000B,00000000B,01111110B,00111100B,00011000B,00000000B
            db 100,11100111B,11000011B,10000001B,00000000B,11100111B,11000011B,10000001B,00000000B,11100111B,11000011B,10000001B,00000000B,11100111B,11000011B,10000001B,00000000B
            db 200,00001111B,11110000B,00001111B,11110000B,00001111B,11110000B,00001111B,11110000B,00001111B,11110000B,00001111B,11110000B,00001111B,11110000B,00001111B,11110000B
            
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
; print carriage return and line feed
; uses A, R6 and R7 in register bank 1.
;------------------------------------------------------------------------
newline:    mov A,#CR
            call putch
            mov A,#LF
            jmp putch

;------------------------------------------------------------------------
; print the string in page 3 of program memory pointed to by A.
; the string must be terminated by zero.
; in addition to A, uses R5, R6 and R7 in register bank 1.
;------------------------------------------------------------------------
txtout:     sel RB1
            mov R5,A
txtout1:    mov A,R5
            movp3 A,@A          ; move to A from page 3 of program memory
            anl A,#07FH
            jz txtdone
            call putch
            sel RB1
            inc R5
            jmp txtout1
txtdone:    sel RB0
            ret

;------------------------------------------------------------------------
; compare the value in R3 to the value in the Accumulator.
; returns with zero flag set if the values are equal.
; returns with carry flag set if the value in R3 is equal to or greater than the value in the Accumulator.
; returns with carry flag cleared if the value in R3 is less than the value in the Accumulator.
;------------------------------------------------------------------------
compare:    cpl A
            inc A
            add A,R3
            ret
            
;------------------------------------------------------------------------
; delay the number of cycles in R7
; mov R7,#(cycles-2)/2      ; load R7 with number of cycles to delay
; call delay                ; call the delay function
; uses R7
;------------------------------------------------------------------------
delay:      djnz R7,delay
            ret

            org 0300H       ; page 3 of program memory
            
signontxt   db  CR,LF,LF,LF
            db  "8048 LED Demo",CR,LF
            db  "Assembled on ",DATE," at ",TIME,CR,LF,0
            
prompttxt:  db  CR,LF,LF,"Enter 1-8 to select an LED pattern.",0
prompt1txt: db  CR,LF,"Press any key to interrupt pattern.",0

            end