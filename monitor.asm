            PAGE 0              ; suppress page headings in ASW listing file
            include "bitfuncs.inc"
            
; serial I/O at 9600 bps N-8-1

; RAM:  00-07   register bank 0
;       08-17   stack
;       18-1F   register bank 1
;       20-7F   data RAM

            cpu 8048
            
;------------------------------------------------------------------------            
; compare the value in REGISTER to the value in the Accumulator.
; zero flag is set if the values are equal.
; carry flag is set if the value in REGISTER is equal to or greater than the value in the Accumulator.
; carry flag is cleared if the value in REGISTER is less than the value in the Accumulator.
; modifies the Accumulator.
;------------------------------------------------------------------------
compare     MACRO REGISTER
            cpl A
            inc A
            add A,REGISTER
            ENDM

CR          equ 0DH
LF          equ 0AH
ESC         equ 1BH

state       equ 7FH             ; 'state' of keyboard input

            org 0000H           ; reset 
reset:      jmp entry

            org 0003H           ; external interrupt
extisr:     retr

            org 0007H           ; timer overflow interrupt
timerisr:   retr

            org 0010H
entry:      dis I               ; disable external interrupt
            dis TCNTI           ; disable timer overflow interrupt
            
start:      mov R0,#lo(titletxt)
            call txtout
            mov A,#0
            mov R0,#state
            mov @R0,A           ; reset 'state'
            
prompt:     call newline
            mov A,#'>'
            call putch
            call getche
            call toupper
            mov R3,A            ; character in R3 for compare
            mov A,#ESC
            compare R3          ; is it ESCAPE?
            jnz prompt1         ; jump if not ESCAPE
            mov R1,#state
            mov A,@R1
            inc A
            mov @R1,A           ; else, increment key 'state'
            jmp prompt          ; go back for the next key
            
prompt1:    mov A,#'?'
            compare R3          ; is it '?'
            jnz prompt2         ; jump if not '?'
            mov R1,#state
            mov A,@R1
            mov R3,#2           ; 2 in R3 for compare
            compare R3          ; has the ESCAPE key been pressed twice?
            jnz prompt2         ; jump if not
            jmp start           ; else, reprint the banner 
            
prompt2:    mov R1,#state
            mov A,#0
            mov @R1,A           ; reset key 'state' back to zero
            mov A,#'D'
            compare R3          ; is it 'D'?
            jnz prompt3         ; jump if not 'D'
            call dump           ; else, dump memory contents
            jmp prompt          ; go back for another key
            
prompt3:    mov A,#'M'
            compare R3
            jnz prompt
            call modify
            jmp prompt
       
; display and modify internal memory       
modify:     mov R0,#lo(addrtxt)
            call txtout         ; prompt for memory address
            call get2hex        ; get the internal memory address
            jc modify4          ; jump if ESCAPE, ENTER or SPACE
            mov R1,A            ; else, save the internal memory address to R1
modify1:    call newline        ; start on a new line
            mov A,R1
            call printhex       ; print the internal memory address
            mov A,#':'
            call putch
            call space
            mov A,@R1           ; retrieve the memory contents
            call printhex       ; print the internal memory contents
            call space
            call get2hex        ; get the byte to replace the current contents
            jc modify2          ; jump if ESCAPE, ENTER or SPACE
            mov @R1,a           ; else, store the new value
            jmp modify3
            
modify2:    mov R3,#' '
            compare R3          ; is the key SPACE?
            jnz modify4         ; jump if the key is not SPACE (must be ESCAPE or ENTER)
            mov A,@R1           ; else, retrieve the current contents 
            call printhex       ; print the current contents
modify3:    inc R1              ; increment the memory pointer to the next memory location
            jmp modify1         ; go back for the next memory location

modify4:    ret
            
; dump internal memory 00-FF in hex and ASCII
dump:       mov R0,#lo(headingtxt)
            call txtout
            mov R1,#0           ; start at the begining of RAM
            mov R5,#16          ; 16 lines

nextline:   mov A,R1
            mov R2,A            ; save the starting address in R2 for the ASCII print later
            call printhex       ; print the starting address for each line
            call space
            mov R4,#16          ; 16 bytes per line
            
; print one line of 16 bytes in hexadecimal            
nextline1:  mov A,@R1
            call printhex       ; print the RAM value addressed by R1
            call space
            inc R1              ; next RAM address
            djnz R4,nextline1   ; loop for 16 RAM addresses

            call space
            mov R4,#16          ; 16 bytes
            mov A,R2            ; recall the starting address from R2
            mov R1,A            ; put the starting address for this line in R1
            
; print 16 bytes in ASCII
nextline2:  mov A,@R1           ; retrieve the byte from memory
            mov R3,A
            mov A,#' '
            compare R3
            mov A,#'.'          ; '.' for unprintable characters
            jnc nextline3       ; jump if the byte is a control character
            mov A,#7FH
            compare R3
            mov A,#'.'          ; '.' for unprintable characters
            jc nextline3        ; jump if the byte is greater than or equal to 7FH
            mov A,R3            ; else, restore the original byte from R0
nextline3:  call putch          ; print the character
            inc R1              ; next memory location
            djnz R4,nextline2   ; do all 16 bytes on this line
            
            call newline        
            djnz R5,nextline    ; loop for 16 lines (256 bytes)
            ret
       
;------------------------------------------------------------------------            
; convert the lower case character in A to upper case 
; uses R3           
;------------------------------------------------------------------------
toupper:    mov R3,A            ; save character in R3
            mov A,#'a'
            compare R3
            jnc toupper1        ; jump if less than 61H (already upper case)
            mov A,#'z'+1
            compare R3
            jc toupper1         ; jump if greater than 7AH
            mov A,#20H
            cpl A
            inc A
            add A,R3            ; subtract 20H to convert to uppercase
            ret
            
toupper1:   mov A,R3
            ret            
        
;------------------------------------------------------------------------
; print the string in page 3 of program memory pointed to by R0.
; the string must be terminated by zero.
; uses R0 in addition to A.
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
; print carriage return and line feed
;------------------------------------------------------------------------            
newline:    mov A,#CR
            call putch
            mov A,#LF
            jmp putch
            
;------------------------------------------------------------------------
; print a space
;------------------------------------------------------------------------            
space:      mov A,#' '
            jmp putch
            
;------------------------------------------------------------------------            
; prints the contents of the accumulator as two hex digits
;------------------------------------------------------------------------
printhex:   mov R0,A            ; save the value on A in R0
            rr A
            rr A
            rr A
            rr A
            call hex2ascii
            call putch          ; print the most significant digit
            mov A,R0            ; recall the value from R0
            call hex2ascii
            call putch          ; print the least significant digit
            ret

; returns the ASCII value for the hex nibble in A
; the table of hex nibbles starts at 0300H
hex2ascii:  anl A,#0FH
            movp3 A,@A
            ret

            org 0200H
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

;------------------------------------------------------------------------              
; get two hex digits from the serial port. echo the digits. 
; return with carry set if ESCAPE, RETURN or SPACE 
; else, return the two hex digits as the corresponding byte in the accumulator.
; uses R3 and R7
;------------------------------------------------------------------------            
get2hex:    call get1hex        ; get the most significant hex digit
            jc get2hex1         
            rl A
            rl A
            rl A
            rl A
            mov R7,A            ; save it in R1
            call get1hex        ; get the least signficant digit
            jc get2hex1
            orl A,R7            ; combine the two digits into A
get2hex1:   ret
            
; get a hex digit from serial port. echo the digit.       
; return with carry set if ESCAPE, RETURN or SPACE     
; else, return the hex digit as a nibble in A 
get1hex:    call getch
            call toupper        ; convert the character to upper case
            mov R3,A            ; save the character in R3
            mov A,#ESC
            compare R3
            jz gethex2
            mov A,#0DH
            compare R3
            jz gethex2
            mov A,#' '
            compare R3
            jz gethex2
            mov A,#'0'          
            compare R3
            jnc get1hex         ; jump if the character in R3 is less than '0'
            mov A,#'9'+1
            compare R3
            jc get1hex1         ; jump if the character in R3 is equal to or greater than ':'
            mov A,R3            ; else, recall the character from R3
            call putch          ; echo the character
            anl A,#0FH
            clr c               ; clear carry
            ret                 ; return with digit 0-9
            
get1hex1:   mov A,#'A'
            compare R3
            jnc get1hex         ; jump if the character in R0 is less than 'A'
            mov A,#'F'+1
            compare R3
            jc get1hex          ; jump if the character in R0 is equal to or greater than 'G'
            mov A,R3            ; else, recall the character from R3
            call putch          ; echo the character
            anl A,#0FH
            add A,#9
            ret                 ; return with digit A-F
            
gethex2:    mov A,R3            ; retrieve the character from R3
            clr c
            cpl c               ; return with carry set
            ret

            org 0300H       ; page 3 of program memory bank 0
            db  30H,31H,32H,33H,34H,35H,36H,37H,38H,39H,41H,42H,43H,44H,45H,46H  ; hex digits 0-F in ASCII
            
titletxt:   db  CR,LF,LF,LF
            db  "8048 Serial Monitor",CR,LF
            db  "Assembled on ",DATE," at ",TIME,CR,LF,LF,0
            
addrtxt:    db  CR,LF,"Address: ",0            
            
headingtxt: db  CR,LF,"   00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F",CR,LF,0            
            
            end