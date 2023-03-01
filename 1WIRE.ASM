;1WIRE - interface from 8048 to DS18B20 thermal sensor (1-Wire bus)
;L.Yadrennikov, 02-03.2023

;4MHz - every single-byte command takes 15/4=3.75usec, double-byte 7.5usec

;pin 27 - P1.0 - data pin of DS18B20

;R5 is a user-flag register

DS18LO    EQU   11111110b
DS18HI    EQU   1

INIT1W:
;initialise sensor, get presence pulse
;on return,
;CY=0 means NO presence pulse
;CY=1 means PRESENCE pulse
;r4,r6,r7,acc are destroyed
;    480us min      15...60us    60...240us
;__   host        _____________  sensor respond        _______________
;  \_____________/ host        \______________________/
;granted PRESENSE sensing time after host forced line HIGH is:
;from 60us (granted 0) to 75us (min 15us highlevel state+min 60us low sensor state) 
	mov r4,#2               ;amount of attempts to initialize
IN1WL:	orl P1,#DS18HI
	anl P1,#DS18LO
	mov r7,#9d
	call Nx60US             ;540us
	orl P1,#DS18HI          ;out at cycle2,state4. One state left (0.75us)
	clr c                   ;3.75us
	call DL52US             ;52.5us
        in a,P1                 ;in at cycle 2,state2, so before sensing 3.75us (1 cycle)+0.75us (1 state)=4.5us
                                ;total time before 1st sensing is:0.75+3.75+52.5+4.5= 61.5us
	mov r6,a                ;3.75us
	in a,P1                 ;second sensing for granted; 4.5us before sensing
                                ;second sensing occurs at: 3states of 1st IN=2.25+3.75+4.5=10.5us;+61.5=72us
	xrl a,r6                ;now bit0=0 if both values are the same
	jb0 PRFAIL              ;and if they're different it's obvious error
        mov a,r6                ;if both are the same r6.0 should be 0
	jb0 PRFAIL
	mov r7,#7
	call Nx60US             ;420us delay (t_rst_h min 480us)
	cpl c
	ret        
PRFAIL: djnz r4,IN1WL           ;continue initializing attempts
	ret                     ;exit if no chances

;IN_BYTE:

;OUT_BYTE: