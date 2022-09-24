            PAGE 0              ; suppress page headings in ASW listing file
            
; 8048 timer interrupt test
; flash the LEDs connected to P1 at about 1 Hz

; RAM:  00-07   register bank 0
;       08-17   stack
;       18-1F   register bank 1
;       20-7F   data RAM

            cpu 8048
            
preload     equ 256-208             ; timer preload value            
            
leds        reg R5                  ; value to write to P1 to control LEDs
count       reg R6                  ; interrupts count
saveA       reg R7                  ; accumulator gets saved here

            org 0000H
reset:      jmp entry

            org 0003H           
ext:        retr                    ; external interrupt

            org 0007H
timer:      jmp timerisr

            org 0010H
entry:      dis I                   ; disable external interrupt
            dis TCNTI               ; disable timer overflow interrupt
            orl P2,#80H             ; set serial output high (mark)            
            clr F1                  ; clear flag
            mov leds,#1             ; pre-load value to write to P1 in R5
            mov count,#100          ; pre-load interrupts/second count into R6
            mov A,#preload
            mov T,A                 
            strt T                  ; start timer
            en TCNTI                ; enable timer interrupt

here:       jf1 there               ; jump if an interrupt occured (F1 set by timerisr)
            jmp here
            
there:      clr F1                  ; clear flag
            djnz count,here         ; decrement the interrupt count in R6
            mov count,#100          ; reload count
            mov A,leds              ; load the value to control the LEDs from R5 of register bank 1 
            cpl A                   ; complement A (low lights LEDs)                        
            outl P1,A               ; turn on/off the LEDs
            inc leds                ; next pattern
            jmp here                ; loop here waiting for a timer interrupt

;------------------------------------------------------------------------
; timer interrupt service routine called when the timer overflows.
; the timer is clocked at 20833.33 Hz (10 Mhz/15/32) or every 48 microseconds.
; the timer overflow occurs every 9.984 milliseconds (48 microseconds*208) or 100.16 times per second.
; sets flag F1 to indicate that a Timer interrupt has occurred.
;------------------------------------------------------------------------
timerisr:   sel RB1                 ; select register bank 1
            mov saveA,A             ; save the accumulator in R7 of register bank 1
            mov A,#preload
            mov T,A                             
            clr F1
            cpl F1                  ; set F1
exitisr:    mov A,saveA             ; restore the accumulator from R7 of register bank 1
            retr                    ; restore working registers, restore psw and re-enable interrupts

            end