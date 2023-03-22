$NOPAGING
;8048 thermometer
;test main file
;uses BINBCD, LCDSFT, 1WIRE
;unfortunately 8048 assemblers I use don't support linking
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

IF P8748 EQU 1
NMOS    SET     1
ENDIF

        call INITLCD
SENLOP: mov r1,#8                ;8bytes to read
        call INIT1W
;        mov r0,#PRESTR
        jnc NOSENS
	mov a,#0CCh              ;skip ROM command
	call OUBT1W
	mov a,#044h              ;convert T
	call OUBT1W
	mov r4,#49d
CNVDLP:	mov r7,#00d
	call Nx60US              ;15.3ms inner delay
	djnz r4,CNVDLP           ;752ms total delay
        call INIT1W
	mov a,#0CCh              ;skip ROM command
	call OUBT1W
	mov a,#0BEh              ;read scratchpad
	call OUBT1W
CRCLOP:	call INBT1W
	call SENDD
	djnz r1,CRCLOP
SENPRE: mov a,#80h
        call SENDI              ;set DDRAM to 0h (line1)
        jmp SENLOP
;        mov a,#11000000b
;        call SENDI              ;set DDRAM to 40h (line2)


NOSENS: mov r0,#NOSTR           ;not necessary if NOSTR is next to INITSEQ
	call ARROUT             ;print SENPRE or NOSTR (8 bytes)
	jmp SENPRE


;--------------------
;BINBCD test in LINE2
;--------------------
        mov a,#76d
        outl p1,a
;        call BINASCI           ;now @21H and 22H of RAM is BCD of 76d
;        mov r0,#MSBCD
        mov r5,#01h
        mov r4,#2
        call ARRLOOP           ;print this 2 digits

;MEMORY
;MEMADR  equ     23h             ;starting RAM addr
;        mov r0,#MEMADR
;        mov r5,#01h             ;RAM-sending
;        mov r4,#6
;        call ARRLOOP            ;print the 1st 6 symbols of PRESTR copied to RAM

STP: IF NMOS EQU 1
        jmp STP
ELSE
        DB 01h                  ;halt
ENDIF


;blank lines between INCLUDEs are mandatory for INTEL ASM48
;$INCLUDE (BINBCD.ASM)

$INCLUDE (LCDSFT.ASM)

$INCLUDE (1WIRE.ASM)

;------------------strings for output
NOSTR:  DB      'NoSensor'
;PRESTR: DB      'Present!'
;-----------------
        END
;-----------------

