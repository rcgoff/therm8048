;8048 thermometer
;test main file
;uses BINBCD, LCDSFT, 1WIRE
;unfortunately 8048 assemblers I used don't support linking
;so, only including


;29.04.2019 - notes for future programming:
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

;      jmp     STOP

        call LCDINIT
        mov r0,#STRING1         ;not necessary if STRING1 is next to INITSEQ
        call ARROUT            ;print STRING1 (8 bytes)
        mov a,#1100 0000b
        call SENDI              ;set DDRAM to 40h (line2)


;--------------------
;BINBCD test in LINE2
;--------------------
        mov a,#76d
        outl p1,a
        call BINASCI           ;now @21H and 22H of RAM is BCD of 76d
        mov r0,#MSBCD
        mov r5,#01h
        mov r4,#2
        call ARRLOOP           ;print this 2 digits

;MEMORY
        mov r0,#MEMADR
        mov r5,#01h             ;RAM-sending
        mov r4,#6
        call ARRLOOP            ;print the 1st 6 symbols of STRING2 copied to RAM

        jmp STOP


;-----------------------------------
;test of presence of 127th byte of RAM (i.e., 8048 or 8049)
;writing byte to RAM @127, then reading and output
;64-byte-RAM devices will be perform readind of 63th byte..
;    ..when we order them read 127th (checked on 1830ve48)
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
STOP:
IF NMOS = 1
       jmp stop
ELSE
       DB 01h                   ;halt
ENDIF


INCLUDE "BINBCD.ASM"
INCLUDE "LCDSFT.ASM"

;------------------strings for output
STRING1:        DB      'Køo øaº '      ;cyrillic 'Kto tam ' in LCD encoding
STRING2:        DB      '¥a≥∫aeø?'      ;cyrillic 'gavkaet?' in LCD encoding
STRING3:        DB      '®y∫®y∫√¿'      ;cyrillic 'PukPukich' in LCD encoding

