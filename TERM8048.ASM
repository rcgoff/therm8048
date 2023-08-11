$NOPAGING
$MACROFILE
;8048 thermometer using DS18B20 sensor and HD44780-based LCD
;main file
;Written for Intel ASM48
;unfortunately this assembler doesn't support linking
;so, only including:
;uses BINBCD, LCDSFT, 1WIRE, ARRAY, CRC8
;L.Yadrennikov 2019,2023. CRC8 based on Tronix code

;4MHz - every single-byte command takes 15/4=3.75usec, double-byte 7.5usec

;pin 25 (extender strobe) - CLK of sft.reg for HD44780 LCD
;pin 22 (P2.1) - DATA of named sft.reg
;pin 27 (P1.0) - data pin of DS18B20

;F0: data (0) / command (1) send to LCD in ARROUT,SENDI/SENDD
;F1: LCD (0) / 1Wire (1) string send in ARROUT
;       defaults are 0's

;R5 is an user-flag register
;       bit 0: ROM (0) / RAM (1) reading for ARROUT, default 0
;       bit 1: 2-digit (0) / 3-digit (1) temperature received
;       bit 2: 1 if it's array call (for SENDD/SENDI)

P8748   EQU     0                ;0 or 1, changes some code if internal memory is used
CRCDISP EQU     1                ;0 or 1, print CRC error counter or don't

MSBCD   EQU     21h              ;addr of ASCII temperathure value at RAM
SCRACH  EQU     30h              ;addr of DS18B20's scratchpad copy at RAM

ABITST  MACRO bit                ;acc bit set
        orl a,#1 SHL bit
        endm

ABITCL  MACRO bit                ;acc bit clr
        anl a,#NOT(1 SHL bit)
        endm

RBITST  MACRO reg,bit            ;reg bit set
        xch a,reg
        abitst bit
        xch a,reg
        endm

RBITCL  MACRO reg,bit            ;reg bit clr
        xch a,reg
        abitcl bit
        xch a,reg
        endm

CMD2DS  MACRO cmd2               ;init,skip ROM,send command to DS18B20
           call INIT1W
           IRP cmd, <0CCh,cmd2>
              mov a,#cmd
              call OUBT1W
           endm
        endm

PRN23   MACRO                    ;print 2 or 3 decoded BCD bytes, addr in r0, len. for 3 bytes in r4
LOCAL TREDGT
        xch a,r5                 ;2 or 3 digits?
        jb1 TREDGT               ;jump if 3
        dec r4
TREDGT: abitst 0                 ;RAM
        xch a,r5                 ;save flags
        call ARRLOOP
        endm

IF CRCDISP
        clr a
        mov r0,#018h
        mov @r0,a                ;init CRC err cnt
ENDIF
        call INITLCD
        call DEGPRG
SENLOP: call INIT1W
        jnc NOSENS
        mov r0,#LOW WRSEQ        ;write-to-scratchpad command sequence (set 10-bit resolution)
        mov r4,#5                ;its length
        cpl f1
        call ARRLOOP             ;send sequence to DS18B20
        cmd2ds 044h              ;convert T command
CNVDLY: call INBT1W
        cpl a
        jb7 CNVDLY               ;when conversion is finished, DS18B20 outputs 1
RDTEMP: cmd2ds 0BEh              ;read scratchpad command
        mov r0,#SCRACH           ;start addr to receive scratchpad
        cpl f1                   ;set 1-wire array exchange
        cpl f0                   ;set reading
        mov r4,#9                ;scratchpad length
        call ARRLOOP             ;read scratchpad
        call CRC8DS              ;calculate CRC
IF CRCDISP
        jnz ERRCRC               ;inc CRC err cnt and re-read scratchpad if CRC error
ELSE
        jnz RDTEMP               ;re-read scratchpad if CRC error
ENDIF
        mov r1,#SCRACH+1
        mov a,@r1                ;acc:=therm.MSB
        dec r1                   ;@r1:=therm.LSB

;acc:=MSB,@R1:=LSB. Let's shift this pair 4 times
        mov r7,#4                ;4 times
SFTRM:  rrc a                    ;shift MSB
        xch a,@r1                ;acc:=LSB to shift, @R1:=shifted MSB   
        rrc a                    ;shift MSB
        xch a,@r1                ;acc:=shifted MSB, @R1:=shifted LSB,CY:=ex-MSB.bit0 
        djnz r7,SFTRM
;now acc (bits 7-0): 2^-2, 2^-3, 2^-4, undef, S,S,S,S; @R1:=S,therm(2^6..2^0); CY=2^-1
        rrc a                    ;acc:=2^-1 2^-2 2^-3 2^-4 undef S S S, CY=S
;sign processing
        mov r4,a                 ;save sign&fracs for later
        anl a,#10b               ;acc=0 if "+" or 2 if "-"
        mov r3,#'+'
        add a,r3                 ;now a:=ASCII "+" or "-", since ASCII "-":= ASCII "+" + 2
        mov r0,#MSBCD-1
        mov @r0,a                ;store sign in RAM array to display
        mov a,r4                 ;restore sign&fracs
        xch a,@r1                ;acc:=therm,@r1:=sign&fracs
        jb7 MINUS                ;check sign
        jmp PRNTRM
;process negative themperature
MINUS:  cpl a
        mov r3,a                 ;save temp for later
        mov a,@r1                ;frac byte
        cpl a
        add a,#10h               ;convert frac byte, CY:=if need to incr integer part
        mov @r1,a                ;save frac
        clr a
        addc a,r3                ;+1 to saved temp depending on carry from fracture
;BINBCD 
PRNTRM: mov r3,a                 ;save temp for later
        mov r0,#MSBCD+1          ;second byte addr for BINASCI
        call BINASCI             ;now @21H and 22H of RAM is BCD of temperature; R5.1=1 means 3-digit (@23H too)
;fractures processing
        mov a,@r1
        swap a
        rr a
        rr a                     ;acc:=0 0 undef S S 2^-1 2^-2
        anl a,#3
        jb1 FRMLCD
        jz NOFRAC
        dec a                    ;here we if 0001 (1/4), LCD code of 1/4 is F0h, so, correct
FRMLCD: orl a,#0F0h              ;form LCD code for fractures
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
        prn23                    ;print sign, 2 or 3 digits of temperature and fracture (if present)
        clr a
        call SENDD               ;print degree symbol
IF CRCDISP
        mov a,#11000000b
        call SENDI               ;set DDRAM to 40h (line2)
        mov r0,#LOW ERRSTR
        mov r4,#5                ;5 chars
        mov r5,#0
        call ARRLOOP             ;print 'Err: ' string
        mov r0,#18h
        mov a,@r0                ;get CRC error counter
        mov r0,#3Eh
        call BINASCI             ;make CRC error counter ASCII decimal from 3Dh
        mov r4,#3                ;max BCD length
        mov r0,#3Dh              ;CRC cntr addr (if 3-digit, will not saved after BINASCI)
        prn23                    ;print CRC counter
ENDIF

SENPRE: mov a,#80h
        call SENDI               ;set DDRAM to 0h (line1)
        jmp SENLOP
;        mov a,#11000000b
;        call SENDI              ;set DDRAM to 40h (line2)


NOSENS: mov r5,#0
        mov r0,#LOW NOSTR       ;not necessary if NOSTR is next to INITSEQ
        call ARROUT             ;print 'NoSensor' (8 bytes)
        jmp SENPRE

;program degree character
DEGPRG: mov a,#40h
        call SENDI              ;set CGRAM addr:=0
        mov r0,#LOW DEGCHR      ;degree symbol bitmap
        call ARROUT
        mov a,#80h
        call SENDI              ;set DDRAM to 0h (line1)
        ret

IF CRCDISP
ERRCRC: sel rb1
        inc r0                  ;inc CRC err cnt
        sel rb0
        jmp RDTEMP              ;re-read temp
ENDIF

;blank lines between INCLUDEs are mandatory for INTEL ASM48
IF CRCDISP

$INCLUDE (BINBCD.ASM)

org     100h

$INCLUDE (1WIRE.ASM)

$INCLUDE (DELAY.ASM)

ELSE

$INCLUDE (1WIRE.ASM)

$INCLUDE (DELAY.ASM)

org     100h

$INCLUDE (BINBCD.ASM)

ENDIF

$INCLUDE (LCDSFT.ASM)

$INCLUDE (ARRAY.ASM)

$INCLUDE (CRC8.ASM)

;------------------strings for output
NOSTR:  DB      'NoSensor'
ERRSTR: DB      'Err: '

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