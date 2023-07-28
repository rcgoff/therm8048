;LCDSFT - interface from 8048 to LCD-shift-register

;4MHz - every single-byte command takes 15/4=3.75usec, double-byte 7.5usec

;pin 25 (extender strobe) - CLK of sft.reg
;pin 22 (P2.1) - DATA of sft.reg
;shifting by rising edge of CLK (0->1)
;       this is compartible with data output by MOVD P(4..7) command
;strobe to LCD controller (/E) is by falling edge of DI (1->0)
;       this is compartible with extenal program memory reading with A8=1

;F0: data (0) / command (1) send to LCD in ARROUT,SENDI/SENDD
;F1: LCD (0) / 1Wire (1) string send in ARROUT
;       defaults are 0's
;R5 is a user-flag register
;       bit 0: ROM (0) / RAM (1) reading for ARROUT, default 0
;       bit 1: 2-digit (0) / 3-digit (1) temperature received
;       bit 2: 1 if it's array call (for SENDD/SENDI)

;L.Yadrennikov (13-28).04.2019
;based on old routines lcd44780_sftreg.asm for PIC16 (thermometer project)


;----------------
;LCD initialisation
;----------------
INITLCD:
        mov r7,#250d
        call Nx60US             ;wait 15ms for LCD initialisation
        clr a
        call SFTREG             ;clear shift register

        mov a,#01000110b        ;init word for LCD 1/3
        mov r0,a                ;back it up
        call SFTREG
        mov r7,#84d
        call Nx60US             ;wait ~5ms
        clr a
        call SFTREG

        mov a,r0
        call STDOUT             ;init word for LCD 2/3
        mov a,r0
        call STDOUT             ;init word for LCD 3/3

        mov a,#01000100b
        call STDOUT             ;set 4-bit mode 1/2

        mov r0,#LOW INITSEQ
        mov r4,#5               ;init sequence length
        cpl f0                  ;SENDI loop
        call ARRLOOP            ;array-based initialisation w/variable
                                ;..length
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
        mov a,r5                ;was it call from ARRLOOP?
        jb2 SENDEX              ;jump if yes
        clr f0                  ;if no, restore default CMD/DATA flag value
SENDEX: ret

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
        orl a,#00100000b        ;no - set bit 5 - data sending
COMSEND:orl a,#01000000b        ;bit 6 is necessary to shift register
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
        call Nx60US
        clr a
        call SFTREG
        ret

;------------------------------------
;Out byte from Acc
;to shift register on PROG and P2.1
;(back-end)
;------------------------------------
SFTREG: rl a                    ;move MSB to LSB
        mov r2,#8               ;amount of shifts
SFTLOOP:rl a                    ;place next data bit for output to bit1 position
        movd p4,a               ;out bit1 to shift register
        djnz r2,SFTLOOP
IF P8748 EQU 1
        orl p2,#00000010b       ;force DI to 1
        anl p2,#11111101b       ;force DI to 0 - writing to LCD controller
ELSE
        movp3 a,@a              ;DI (P2.1) 0->1->0 switching - wr to LCD
ENDIF
        ret
