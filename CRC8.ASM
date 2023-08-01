; 8039 Nixie Clock (c) Tronix 2023
;file dated Feb 27, 2023
;simplified by L.Yadrennikov Jul 26,2023
;------------------------------------------------------------------------
; CRC8 Dallas
; Input : #scratch
; Output: A=0 if CRC ok
; uses A, R0, R6, R7
;------------------------------------------------------------------------
CRC8DS: clr a
	mov r7,#8		; scratchpad len counter
	mov r0,#SCRACH
CRCNBY: xrl a,@r0

;----------one byte loop
	mov r6,#8		; for (i = 0; i < 8; i++)
CRCINN: clr c
	rrc a
	jnc CRCNBI              ;jump to Next BIt if former acc.0=0 (no XOR)
	xrl a,#08Ch             ;1000.1100 - polynomial coeffs in inverted order
CRCNBI: djnz r6,CRCINN          ;next bit
;----------end of one byte loop, r0:=byte-CRC

	inc r0
	djnz r7,CRCNBY          ;next byte
	                        ;now r0 points to received CRC
        xrl a,@r0               ;compare with calculated
	retr
