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

;29.04.2018 - notes for future programming:
;'+' has ASCII code 2Bh
;'-' has ASCII code 2Dh, i.e. '-':= '+' + 2
;'1/2' has code F2h
;a-la degree in LC display (another encoding): ASCII code B2h (by horowitz-hill)
;degree in An6866 doc: 99h (S03 encoding, page 1) - very close to truth because there's no other cyrillic
;tables with such letters order. Also: 93h EFh
;
;
;degree symbol in MT-16S2D:
;.**..
;*..*.
;*..*.
;.**..
;.....
;.....
;.....

P8748   EQU     0               ;0 or 1, changes some code if internal memory is used
NMOS    SET     0               ;0 or 1, changes STOP routine if NMOS chip is used

IF P8748=1
NMOS    SET     1
ENDIF


;-------------------copying text string from program memory to RAM
;-------------------for array output testing
MEMADR  equ     23h             ;starting RAM addr
STRLEN  equ     8h              ;length of string
;r2 is iterator
;r3 is index value
;r0 is indirect address register

        mov r0,#MEMADR
        mov r2,#STRLEN
        mov r3,#STRING3
COPLOOP:mov a,r3
        movp a,@a
        mov @r0,a
        inc r3
        inc r0
        djnz r2,COPLOOP

;STP:     jmp STP


        mov r7,#10d
        call DELAY_Nx1.5MS      ;wait 15ms for LCD initialisation
        clr a
        call SFTREG             ;clear shift register

        mov a,#010 0011 0b      ;init word for LCD 1/3
        mov r0,a                ;back it up
        call SFTREG
        mov r7,#4
        call DELAY_Nx1.5MS      ;wait 6ms (5ms sufficient but..)
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

;        mov r0,#STRING1        ;not necessary becays STRING1 is next to INITSEQ
        call ARROUT
        mov a,#1100 0000b
        call SENDI              ;set DDRAM to 40h (line2)

;BIBCD test in LINE2
        mov a,#76d
        outl p1,a
        call BINASCI
        mov r0,#MSBCD
        mov r5,#01h
        mov r4,#2
        call ARRLOOP

;MEMORY
        mov r0,#MEMADR
        mov r5,#01h             ;RAM-sending
        mov r4,#6
        call ARRLOOP            ;address of STRING2 is next to ending address
                                ;of STRING1 and already stored in R5

DB      01h


;-----------------------------------
;test of presence of 127th byte of RAM (i.e., 8048 or 8049)
;writing byte to RAM @127, then reading and output
;64-byte-RAM devices will be perform readind of 63th byte..
;    ..when we comand them read 127th (checked on 1830ve48)
        mov a,#01010101b
        mov r0,#127d
        mov @r0,a               ;mem(7fh)=55h
        mov a,#10101010b
        mov r1,#63d
        mov @r1,a               ;mem(3fh)=55h
        clr a
        mov a,@r0
        outl p1,a               ;p1:=mem@7fh
        clr a
        mov a,@r1
        outl p2,a               ;p2:=mem@3fh, but if proc is 48(35),
                                ;will be p2 = p1

IF NMOS = 1
STOP:   jmp stop
ELSE
        DB 01h                  ;halt
ENDIF


INCLUDE "BINBCD.ASM"

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
        call DELAY_1.5MS
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
;(Nx1.5) ms delay, N stored in r7
;----------------------------
;exact delay time is t2c*(201*N+2)usec
;residue is t2c*(N+2)usec more
DELAY_Nx1.5MS:                  ;t2c
        call DELAY_1.5MS        ;200*Nt2c
        djnz r7,DELAY_Nx1.5MS   ;N*t2c
        ret                     ;t2c

;-----------------------------
;1500us delay
;-----------------------------
DELAY_1.5MS:
        mov r6,#197d            ;delay time is t=t2c(3+x),x=197, t=1500us
                                ;see Stashin-Urusov 1990, p.142
                                ;for 1ms set value 130: t=997.5us
DELOOP: djnz r6,DELOOP
        ret

;------------------strings for output
;initialising sequence for display
INITSEQ:        DB      28h     ;4bit mode
                DB      08h     ;disp off
                DB      01h     ;disp clr
                DB      0Ch     ;disp on
                DB      06h     ;incr without shift mode
STRING1:        DB      'Køo øaº '      ;cyrillic 'Kto tam ' in LCD encoding
STRING2:        DB      '¥a≥∫aeø?'      ;cyrillic 'gavkaet?' in LCD encoding
STRING3:        DB      '®y∫®y∫√¿'      ;cyrillic 'PukPukich' in LCD encoding

;-----------------
       END
;-----------------

