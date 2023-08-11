;--------------------
;Array output to LCD or 1-Wire
;--------------------
;Before call, in R0 should be starting (base) address of array
;Default length is 8, if no, put length in R4 and call ARRLOOP
;F0 shows if command (=1) or data (=0,default) array
;uses r5 bit 0 (ROM (0)/RAM (1) reading
;uses r4 (array count)
;uses r0 (array pointer)
;iterating by r4 downwards
;on exit, we will have in r0 "final addr"+1 - this is useful

ARRLEN  equ     8h              ;default array length
ARROUT: mov r4,#ARRLEN
ARRLOOP:                        ;entry when ARRLEN is other (can Vary)
;now r0=st.addr
;    r4=arrlen
;and index should be in a, note that 1st index=st.addr
        mov a,r5
        jb0 RAMRD
        abitst 2                ;set array call flag
        mov r5,a
        mov a,r0                ;ROM reading @r0
        movp a,@a
        jmp RDCOM               ;to ReaD COMmon part
RAMRD:  mov a,@r0               ;RAM reading  @r0
RDCOM:  jf1 WIRE                ;LCD or 1Wire output?
        call SENDD
        jmp ARRNX               ;ARRay NeXt code
WIRE:   call RDWR1W
ARRNX:  inc r0                  ;next index
        djnz r4,ARRLOOP
        clr f0                  ;restore default (data) array type
        clr f1                  ;restore default (LCD) output type
        rbitcl r5,2             ;clear array call flag
        ret

;initialising sequence for LC display
INITSEQ:        DB      028h    ;4bit mode
                DB      008h    ;disp off
                DB      001h    ;disp clr
                DB      00Ch    ;disp on
                DB      006h    ;incr without shift mode

;write scratchpad sequence for 1-Wire
WRSEQ:          DB      0CCh    ;skip ROM
                DB      04Eh    ;write scratchpad
                DB      03Fh    ;Th
                DB      03Fh    ;Tl
                DB      03Fh    ;0 R1=0 R0=1 1 1111 - 10-bit thermo resolution (2 bits after decimal point)
