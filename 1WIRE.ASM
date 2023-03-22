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
	mov r7,#9
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

;in 1 byte from 1-wire bus
;Acc:=R4:=byte from 1Wire
INBT1W:	mov r7,#8
IN1WLP:	anl P1,#DS18LO          ;out @C2S4, 0.75 us after LOW
        orl P1,#DS18HI          ;out @C2S4, so LOW interval lasts exactly 7.5us; 0.75us after 1 also. 7.5+0.75=8.25us after LOW
	in a,P1                 ;in  @C2S2, since command start 4.5us, sensing @8.25+4.5=12.75us after LOW
	rrc a                   ;CY:=bit from 1Wire
	mov a,r4
	rrc a                   
	mov r4,a                ;put the next bit from DS18 (CY) to R4
	call DL52US
	djnz r7,IN1WLP
	ret


;out 1 byte from Acc to 1Wire bus
OUBT1W: mov r7,#8
OU1WLP: rrc a                   ;CY:=next bit, starting from LSB;
	anl P1,#DS18LO          ;out @C2S4, 0.75 us after LOW
	jnc OUSKHI              ;if bit was 0, no CY, keep LOW (skip pulling HIGH); 7.5us
	orl P1,#DS18HI          ;out @C2S4, LOW (if bit=1) totally keeped: 0.75+7.5+4.5=12.75us
OUSKHI:	call DL52US
	orl P1,#DS18HI          ;no impact if out HIGH, end slot if out LOW
	djnz r7,OU1WLP
        ret