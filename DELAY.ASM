;----------------------------
;(Nx60) us delay, N stored in r7
;----------------------------
;exact delay time is 2t2c+5Nt2c=60N+15 usec,
;or, if we count mov r7,#val too, 60N+22.5 usec.
Nx60US:                         ;t2c to call
        call DL52US             ;4*Nt2c
        djnz r7,Nx60US          ;N*t2c, with previous we have 5Nt2c=N*60usec
        ret                     ;t2c

;-----------------------------
;52.5us delay
;-----------------------------
DL52US: mov r6,#4               ;delay time is t=t2c(3+x),x=4, t=52.5us
                                ;see Stashin-Urusov 1990, p.142
                                ;for 1ms set value 130: t=997.5us;
                                ;for 1.5ms set value 197
DELOOP: djnz r6,DELOOP
        ret
