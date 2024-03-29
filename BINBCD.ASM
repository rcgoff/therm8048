;---------------
;BINASCI
;---------------
;Conversion of 8-bit unsigned binary in Acc
;(if CRCDISP=1) or 7-bit (if CRCDISP=0)
;to BCD ASCII codes @r0-1 and @r0,
;and if >99 - in @r0+1 too (3-digit).
;If 3-digit, bit 1 @R5 set to 1

;L.Yadrennikov 03,08.2023


BINASCI:
        clr c
        rbitcl r5,1              ;clear 3-digit flag
        jz BCDZER                ;zeros are incorrectly processed by DJNZ, so, skip
;convert to packed BCD in Acc
        mov r7,a
        clr a
BCDLOP: inc a
        da a
        jc OVER99                ;DAA returns carry if operand was 9Ah, converted to 00 + CY
BCDLO1: djnz r7,BCDLOP
;unpack and form ASCII
BCDZER: mov @r0,#'0'+3h
        xchd a,@r0               ;write LSD (ones), now Acc:="MSD 3"
        swap a                   ;now Acc:="3 MSD",i.e. MSD in ASCII
        dec r0
        mov @r0,a                ;write tens
        ret

OVER99: dec r0
        xch a,r5
IF CRCDISP
        jb1 OVR199
ENDIF
        mov @r0,#'1'             ;hundreds
        abitst 1                 ;set 3-digit flag
OVRCOM: xch a,r5
        inc r0
        inc r0                   ;change ones' address if >99
        clr c                    ;to prevent incorrect DAA work at the rest of loop
        jmp BCDLO1

IF CRCDISP
OVR199: dec r0
        inc @r0                  ;'2' in hundreds
        jmp OVRCOM
ENDIF

$NOLIST
;----------------------------obsolete   
;L.Yadrennikov 28.04.2019

;;"2" complement to 10d is (256-10)=246d=1111.0110=F6h
;NEG10   equ     256d-10d

;      based on BINBCDv3 (see older versions below)
;BINASCI:
;        mov r0,#MSBCD           ;@r0 for tens
;        mov r1,#MSBCD+1         ;@r1 for ones
;        mov @r0,#30h            ;ASCII code "0"
;        mov @r1,a
;GTENTH: mov a,#NEG10
;        add a,@r1
;        jnc BCDFIN
;        inc @r0
;        mov @r1,a
;        jmp GTENTH              ;16 bytes
;now MSB-ASCI is in @R0, LSB-BCD is in @R1.
;BCDFIN: mov a,#30h              ;exit from loop point, CARRY is clear!
;        add a,@r1
;        mov @r1,a
;        ret

;------------------------------------------------------
;version1 - like Microchip PIC AN526 BIN8BCD.asm

;value to proceed must be stored in acc
;subtracting 10d until carry
;if result still positive, carry will always set
;so, as carry is clear - stop right now
;amount of subtractions (plus 1) is a higher bcd digit
;lower bcd digit is result of pre-last substraction
;so we should to conserve subtraction operands somewhere
;or add 10 to result. In the latter case carry will be set on exit.

;r2 is for constant "-10"
;r3 is for higher byte


;;setup phase
;;        mov a,#63d              ;test value
;;routine itself
;BINBCDv1:
;        mov r3,#0
;        mov r2,#NEG10
;GTENTH: add a,r2
;        inc r3
;        jc GTENTH
;        dec r3
;        add a,#10d              ;11 bytes
;STOP:   jmp STOP



;;--------------another variant, more similar to PIC appnote
;;value to convert should be not in acc but in some register
;;for not-a-vague: in r2
;        mov r2,#3d
;BINBCDv2:
;        mov r3,#0
;GTENTH: mov a,#NEG10
;        add a,r2
;        jnc BCDFIN
;        inc r3
;        mov r2,a
;        jmp GTENTH              ;11 bytes too
;;now LSB is in R2, MSB is in R3
;BCDFIN: jmp BCDFIN              ;exit point, CARRY is clear!


;;-------------variant similar to 2 but to store BCD in memory (indirect addr)
;;value to convert should be in acc
;;r0,r1 are address registers
;;100% free data memory space begins from addr 20h (32d):
;;       00-07 reg.B0, 08h-17h stack 16x8 (2 bytes per entry), 18h-1Fh reg.B1
;;so:  @20h - sign
;;     @21h - BCD MSB
;;     @22h - BCD LSB
;;     @23h - degree symbol (or 1/2 in future 9-bit resolution)
;;     @24h - in future 9-bit resolution here will be degree symbol
;MSBCD   equ     21h
;
;;        mov a,#53d              ;value to convert
;BINBCDv3:
;        mov r0,#MSBCD           ;@r0 for tens
;        mov r1,#MSBCD+1         ;@r1 for ones
;        mov @r0,#0
;        mov @r1,a
;GTENTH: mov a,#NEG10
;        add a,@r1
;        jnc BCDFIN
;        inc @r0
;        mov @r1,a
;        jmp GTENTH              ;16 bytes
;;now MSB is in @R0, LSB is in @R1.
;BCDFIN: ;jmp BCDFIN              ;exit point, CARRY is clear!
;        ret

;DB      NEG10
$LIST