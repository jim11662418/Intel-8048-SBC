            PAGE 0              ; suppress page headings in ASW listing file
            
; serial I/O at 9600 bps N-8-1
            
            include "bitfuncs.inc"

            cpu 8048

CR          equ 0DH
LF          equ 0AH
ESC         equ 1BH

ram:        equ 20H                 ; usable RAM starts at 20H

            org 0000H               ; reset 
reset:      jmp entry

            org 0003H               ; external interrupt
extisr:     retr

            org 0007H               ; timer overflow interrupt
timerisr:   retr

            org 0010H
entry:      dis I                   ; disable external interrupt
            dis TCNTI               ; disable timer overflow interrupt
            orl P2,#80H             ; set serial output high (mark)

start:      ;mov R0,#lo(titletxt)
            ;call txtout
loop:       call getch
            call putch
            jmp loop
  
;------------------------------------------------------------------------
; print the string in page 3 of program memory pointed to by R0.
; the string must be terminated by zero.
; uses A in addition to R0
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
; sends the character in A out from the serial output (P2.7)
; uses A, R6 and R7.
;------------------------------------------------------------------------
putch:      anl P2,#7FH             ; make serial output low to send the start bit
            mov R6,#8               ; load R6 with the number of bits to send
            mov R7,#30              ; load the number of cycles to delay into R7
            djnz R7,$               ; delay 60 cycles
            nop

            ;send bits 0-7
putch1:     jb0 putch2              ; jump if the bit to send is "1"
            anl P2,#7FH             ; else, send "0"
            jmp putch3              ; skip the next part
putch2:     orl P2,#80H             ; send "1"
            jmp putch3              ; makes the timing equal for both "0" and "1" bits
putch3:     rr A                    ; rotate the next bit into position
            mov R7,#29              ; load the number of cycles to delay into R7
            djnz R7,$               ; delay 58 cycles
            djnz R6,putch1          ; loop to send all 8 bits

            ;send the stop bit
            nop
            nop
            orl P2,#80H             ; make serial output high to send the stop bit
            mov R7,#18              ; load the number of cycles to delay into R7
            djnz R7,$               ; delay 36 cycles (1/2 bit time)
            ret

;------------------------------------------------------------------------
; waits for a character from the serial input (T0).
; returns the character in A. 
; uses A, R6 and R7.
;------------------------------------------------------------------------
getch:      jt0 getch               ; wait here for the start bit
            clr A                   ; start with A cleared
            mov R6,#8               ; load the number of bits to receive into R6
            mov R7,#18              ; load the number of cycles to delay into R7
            djnz R7,$               ; delay 36 cycles (1/2 bit time)

            ;get bits 0-7
getch1:     mov R7,#29              ; load the number of cycles to delay into R7
            djnz R7,$               ; delay 58 cycles (1 bit time)
            jnt0 getch2             ; jump if the serial input is zero
            orl A,#01H              ; else, set the bit of the recieved character
            jmp getch3              ; skip the next part
getch2:     anl A,#0FEH             ; clear the bit of the received character
            jmp getch3              ; makes the timing equal for both "0" and "1" bits
getch3:     rr A                    ; rotate the bits in the received character right
            djnz R6,getch1          ; loop to receive all 8 bits

            ;stop bit
            mov R7,#18              ; load the number of cycles to delay into R7
            djnz R7,$               ; delay 36 cycles (1/2 bit time) for the stop bit
            ret
            
;------------------------------------------------------------------------
; waits for a character from the serial input (T0).
; echos the character bit by bit (output on P2.7).
; returns the character in A.
; uses A, R6 and R7.
;------------------------------------------------------------------------
getche:     jt0 getche              ; wait here for the start bit
            clr A                   ; start with A cleared
            mov R6,#8               ; load the number of bits to receive into R6
            mov R7,#14              ; load the number of cycles to delay into R7
            djnz R7,$               ; delay 28 cycles
            anl P2,#7FH             ; make serial output low to send the start bit
            mov R7,#2               ; load the number of cycles to delay into R7
            djnz R7,$               ; delay 4 cycles
            nop

            ;get bits 0-7
getche1:    mov R7,#28              ; load the number of cycles to delay into R7
            djnz R7,$               ; delay 56 cycles
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
            mov R7,#29              ; load the number of cycles to delay into R7
            djnz R7,$               ; delay 58 cycles
            orl P2,#80H             ; make serial output high to send the stop bit    
            mov R7,#29              ; load the number of cycles to delay into R7
            djnz R7,$               ; delay 58 cycles
            ret            

            org 0300H               ; page 3 of program memory bank 0
titletxt:   db  CR,LF
            db  "Serial I/O test",CR,LF
            db  "Assembled on ",DATE," at ",TIME,CR,LF
            db  "Type some text... ",0

            end