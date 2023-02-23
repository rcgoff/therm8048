;LCDSFT - interface from 8048 to LCD-shift-register

;4MHz - every single-byte command takes 15/4=3.75usec, double-byte 7.5usec

;pin 25 (extender strobe) - CLK of sft.reg
;pin 21 (P2.0) - DATA of sft.reg
;shifting by rising edge of CLK (0->1)
;       this is compartible with data output by MOVD P(4..7) command
;strobe to LCD controller (/E) is by falling edge of DI (1->0)
;       this is compartible with extenal program memory reading with A8=1

;F0: data (0) / command (1) send to LCD in SENDI/SENDD
;F1: data (0) / command (1) string send to LCD in ARROUT
;       defaults are 0's
;R5 is a user-flag register
;       bit 0: ROM (0) / RAM (1) reading for ARROUT, default 0

;L.Yadrennikov (13-28).04.2019
;based on old routines lcd44780_sftreg.asm for PIC16 (thermometer project)


;----------------
;LCD initialisation
;----------------
LCDINIT:
        mov r7,#250d
        call DELAY_Nx60US       ;wait 15ms for LCD initialisation
        clr a
        call SFTREG             ;clear shift register

        mov a,#010 0011 0b      ;init word for LCD 1/3
        mov r0,a                ;back it up
        call SFTREG
        mov r7,#84d
        call DELAY_Nx60US       ;wait ~5ms
        clr a
        call SFTREG

        mov a,r0
        call STDOUT             ;init word for LCD 2/3
        mov a,r0
        call STDOUT             ;init word for LCD 3/3

        mov a,#010 0010 0b
        call STDOUT             ;set 4-bit mode 1/2

        mov r0,#INITSEQ
        mov r4,#5               ;init sequence length
        cpl f1
        call ARRLOOP            ;array-based initialisation w/variable
                                ;..length
        ret

;--------------------
;Array output to LCD
;--------------------
;Before call, in R0 should be starting (base) address of array
;Default length is 8, if no, put length in R4 and call ARRLOOP
;F1 shows if command (=1) or data (=0,default) array
;uses r5 bit 0 (ROM (0)/RAM (1) reading
;uses r4 (array count)
;uses r0 (array pointer)
;iterating by r4 downwards
;on exit, we will have in r5 "final addr"+1 - this is useful

ARRLEN  equ     8h              ;default array length
ARROUT: mov r4,#ARRLEN
ARRLOOP:                        ;entry when ARRLEN is other (can Vary)
;now r0=st.addr
;    r4=arrlen
;and index should be in a, note that 1st index=st.addr
        mov a,r5
        jb0 RAMRD
        mov a,r0                ;ROM reading @r0
        movp a,@a
        jmp RDCOM               ;to ReaD COMmon part
RAMRD:  mov a,@r0               ;RAM reading  @r0
RDCOM:  jf1 COMMD               ;command or data array?
        call SENDD
        jmp ARRNX               ;ARRay NeXt code
COMMD:  call SENDI
ARRNX:  inc r0                  ;next index
        djnz r4,ARRLOOP
        clr f1                  ;restore default (data) array type
        ret

;----------------
;Acc->LCD (SENDI - send instruction, SENDD - send data)
;----------------
SENDI:  cpl f0                  ;command means f0=1, otherwise f0=0
SENDD:  mov r3,a
        anl a,#0F0h             ;higher nibble
        swap a
        call SFTPREP            ;out to LCD
        mov a,r3
        anl a,#0Fh              ;lower nibble
        call SFTPREP            ;out to LCD
        clr f0                  ;restore default flag value
        ret

;---------------------------------
;output acc's lower nibble to LCD
;---------------------------------
;How to assign flags its values and sense? (command/data)
;in the byte to send to shift register (and to LCD):
;command send - bit 5=0
;data send - bit 5=1
;initially we're sending commands, bit 5 clear
;it's resonable to make bit 5 = flag,
;   but jumps is posible only by flag=true
;so, it's better to set flag opposite to bit 5:
;F0=1 :=command; by default flag is clear (data)

SFTPREP:rl a
        jf0 COMSEND             ;f0=1? yes - this is command sending
        orl a,#0010 0000b       ;no - set bit 5 - data sending
COMSEND:orl a,#0100 0000b       ;bit 6 is necessary to shift register
                                ;and now, in natural way, go to STDOUT...
;------------------------------------
;Out byte from Acc
;to shift register on PROG and P2.0
;(front-end) - with 1.5ms delay.
;This is maximum LCD command execution
;time.
;------------------------------------
STDOUT: call SFTREG
        mov r7,#25d
        call DELAY_Nx60US
        clr a
        call SFTREG
        ret

;------------------------------------
;Out byte from Acc
;to shift register on PROG and P2.0
;(back-end)
;------------------------------------
SFTREG: mov r2,#8               ;amount of shifts
SFTLOOP:rl a                    ;shift right (and current MSB to LSB)
        movd p4,a               ;out LSB to shift register
        djnz r2,SFTLOOP
IF P8748 = 1
        orl p2,#1h              ;force DI to 1
        anl p2,#1111 1110b      ;force DI to 0 - writing to LCD controller
ELSE
        movp3 a,@a              ;DI (P2.0) 0->1->0 switching - wr to LCD
ENDIF
        ret

;----------------------------
;(Nx60) us delay, N stored in r7
;----------------------------
;exact delay time is 2t2c+5Nt2c=60N+15 usec,
;or, if we count mov r7,#val too, 60N+22.5 usec.
DELAY_Nx60US:                   ;t2c to call
        call DELAY_52US         ;4*Nt2c
        djnz r7,DELAY_Nx60US    ;N*t2c, with previous we have 5Nt2c=N*60usec
        ret                     ;t2c

;-----------------------------
;52.5us delay
;-----------------------------
DELAY_52US:
        mov r6,#4               ;delay time is t=t2c(3+x),x=4, t=52.5us
                                ;see Stashin-Urusov 1990, p.142
                                ;for 1ms set value 130: t=997.5us;
                                ;for 1.5ms set value 197
DELOOP: djnz r6,DELOOP
        ret


;initialising sequence for display
INITSEQ:        DB      28h     ;4bit mode
                DB      08h     ;disp off
                DB      01h     ;disp clr
                DB      0Ch     ;disp on
                DB      06h     ;incr without shift mode

;-----------------
       END
;-----------------

