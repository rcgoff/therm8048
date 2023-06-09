$NOPAGING
;8048 thermometer
;main file
;uses BINBCD, LCDSFT, 1WIRE
;unfortunately 8048 assemblers I use don't support linking
;so, only including

;R5 is a user-flag register
;       bit 0: ROM (0) / RAM (1) reading for ARROUT, default 0
;       bit 1: 2-digit (0) / 3-digit (1) temperature received


;29.04.2019 - notes for future programming:
;'+' has ASCII code 2Bh
;'-' has ASCII code 2Dh, i.e. '-':= '+' + 2
;'1/2' has code F2h
;
;
;degree symbol in MT-16S2D:
;.**..  =0Ch
;*..*.  =12h
;*..*.  =12h
;.**..  =0Ch
;.....
;.....
;.....

P8748   EQU     0               ;0 or 1, changes some code if internal memory is used
NMOS    SET     0               ;0 or 1, changes STOP routine if NMOS chip is used

IF P8748 EQU 1
NMOS    SET     1
ENDIF

	call INITLCD
	call DEGPRG
SENLOP: call INIT1W
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
	call INBT1W              ;read therm. LSB
	mov r2,a
	call INBT1W              ;read therm. MSB

;acc:=MSB,R2:=LSB. Let's shift this pair 4 times
	mov r7,#4                ;4 times
SFTRM:  rrc a                    ;shift MSB
	xch a,r2                 ;acc:=LSB to shift, R2:=shifted MSB	
	rrc a                    ;shift MSB
	xch a,r2                 ;acc:=shifted MSB, R2:=shifted LSB,CY:=ex-MSB.bit0 
	djnz r7,SFTRM
;now acc (bits 7-0): 2^-2, 2^-3, 2^-4, undef, S,S,S,S; R2:=S,therm(2^6..2^0); CY=2^-1
	rrc a                    ;acc:=2^-1 2^-2 2^-3 2^-4 undef S S S, CY=S
;sign processing
	mov r4,a                 ;save sign&fracs for later
        anl a,#10b               ;acc=0 if "+" or 2 if "-"
	mov r3,#'+'
	add a,r3                 ;now a:=ASCII "+" or "-", since ASCII "-":= ASCII "+" + 2
        mov r0,#MSBCD-1
	mov @r0,a                ;store sign in RAM array to display
	mov a,r4                 ;restore sign&fracs
	xch a,r2                 ;acc:=therm,r2:=sign&fracs
	cpl a
	jb7 PLUS                 ;check sign
;process negative themperature
	mov r3,a                 ;save temp for later
	mov a,r2                 ;frac byte
	cpl a
	add a,#10h               ;convert frac byte, CY:=if need to incr integer part
	mov r2,a                 ;save frac
	clr a
	addc a,r3                ;+1 to saved temp depending on carry from fracture
	jmp PRNTRM
PLUS:	cpl a
;BINBCD 
PRNTRM: mov r3,a                 ;save temp for later
	call BINASCI             ;now @21H and 22H of RAM is BCD of temperature; R5.1=1 means 3-digit (@23H too)
;fractures processing
	mov a,r2
	swap a
	rr a
	rr a                     ;acc:=0 0 undef S S 2^-1 2^-2
	anl a,#3
	jb1 FRMLCD
	jz NOFRAC
	dec a                    ;here we if 0001 (1/4), LCD code of 1/4 is F0h, so, correct
FRMLCD:	orl a,#0F0h              ;form LCD code for fractures
        mov r0,#MSBCD+3
	xch a,r5
	jb1 LESS99
	dec r0
LESS99: xch a,r5
	mov @r0,a                ;store fracture
	mov r4,#5                ;worst-case length with fractures 
	jmp PRNTMP
;output
NOFRAC: mov r4,#4
	mov a,r3                 ;restore temp
	jnz PRNTMP               ;is integer part=0 too?
	mov r0,#MSBCD-1
	mov a,#' '
	mov @r0,a                ;eliminate sign if both int and frac parts are 0
PRNTMP: mov a,#1
	call SENDI               ;clear display
	mov r0,#MSBCD-1
	xch a,r5
	jb1 TREDGT
	dec r4
TREDGT:	orl a,#1
	xch a,r5
        call ARRLOOP             ;print sign, 2 or 3 digits of temperature and fracture (if present)
	clr a
	call SENDD               ;print degree symbol

SENPRE:	mov a,#80h
        call SENDI               ;set DDRAM to 0h (line1)
        jmp SENLOP
;        mov a,#11000000b
;        call SENDI              ;set DDRAM to 40h (line2)


NOSENS: mov r5,#0
	mov r0,#NOSTR MOD 100h  ;not necessary if NOSTR is next to INITSEQ
	call ARROUT             ;print SENPRE or NOSTR (8 bytes)
	jmp SENPRE

;program degree character
DEGPRG: mov a,#40h
	call SENDI              ;set CGRAM addr:=0
	mov r0,#DEGCHR MOD 100h ;degree symbol bitmap
	call ARROUT
	mov a,#80h
	call SENDI		;deg DDRAM to 0h (line1)
	ret

;blank lines between INCLUDEs are mandatory for INTEL ASM48
$INCLUDE (1WIRE.ASM)

$INCLUDE (DELAY.ASM)

org 	100h

$INCLUDE (BINBCD.ASM)

$INCLUDE (LCDSFT.ASM)

;------------------strings for output
NOSTR:  DB      'NoSensor'

;degree symbol bitmap
DEGCHR: DB      0Ch     ;.**..
        DB      12h     ;*..*.
        DB      12h     ;*..*.
        DB      0Ch     ;.**..
        DB      00h     ;.....
        DB      00h     ;.....
        DB      00h     ;.....
        DB      00h     ;.....

;-----------------
        END
;-----------------

