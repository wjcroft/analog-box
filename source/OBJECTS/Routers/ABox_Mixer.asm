;// This file is part of the Analog Box open source project.
;// Copyright 1999-2011 Andy J Turner
;//
;//     This program is free software: you can redistribute it and/or modify
;//     it under the terms of the GNU General Public License as published by
;//     the Free Software Foundation, either version 3 of the License, or
;//     (at your option) any later version.
;//
;//     This program is distributed in the hope that it will be useful,
;//     but WITHOUT ANY WARRANTY; without even the implied warranty of
;//     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;//     GNU General Public License for more details.
;//
;//     You should have received a copy of the GNU General Public License
;//     along with this program.  If not, see <http://www.gnu.org/licenses/>.
;//
;////////////////////////////////////////////////////////////////////////////
;//
;// Authors:    AJT Andy J Turner
;//
;// History:
;//
;//     2.41 Mar 04, 2011 AJT
;//         Initial port to GPLv3
;//
;//     ABOX242 AJT -- detabified
;//
;//##////////////////////////////////////////////////////////////////////////
;//
;// ABox_Mixer.asm
;//
OPTION CASEMAP:NONE

.586
.MODEL FLAT

USE_THIS_FILE equ 1

IFDEF USE_THIS_FILE

        .NOLIST
        include <Abox.inc>
        .LIST

.DATA

osc_Mixer OSC_CORE { ,,,mixer_Calc }
          OSC_GUI  {,,,,,,,,,osc_SaveUndo,mixer_LoadUndo,mixer_GetUnit}
          OSC_HARD { }

    OSC_DATA_LAYOUT {NEXT_Mixer,IDB_MIXER,OFFSET popup_MIXER,,18,,
        SIZEOF OSC_OBJECT + ( SIZEOF APIN * 18 ),
        SIZEOF OSC_OBJECT + ( SIZEOF APIN * 18 ) + SAMARY_SIZE * 2,
        SIZEOF OSC_OBJECT + ( SIZEOF APIN * 18 ) + SAMARY_SIZE * 2 }

    OSC_DISPLAY_LAYOUT {mixer_container, MIXER_PSOURCE, ICON_LAYOUT( 0,2,2,0 ) }

    APIN_init { -0.695,,'1' ,, UNIT_AUTO_UNIT }         ;// 0 input 1
    APIN_init { -0.305,sz_Pan,'p1',, UNIT_PANNER }  ;// 1 pan 1

    APIN_init { -0.808,,'2' ,, UNIT_AUTO_UNIT }         ;// 2 input 2
    APIN_init { -0.192,sz_Pan,'p2',, UNIT_PANNER }  ;// 3 pan 2

    APIN_init { -0.893,,'3' ,, UNIT_AUTO_UNIT }         ;// 4 input 3
    APIN_init { -0.107,sz_Pan,'p3',, UNIT_PANNER }  ;// 5 pan 3

    APIN_init { -0.965,,'4' ,, UNIT_AUTO_UNIT }         ;// 6 input 4
    APIN_init { -0.035,sz_Pan,'p4',, UNIT_PANNER }  ;// 7 pan 4

    APIN_init {  0.965,,'5' ,, UNIT_AUTO_UNIT }         ;// 8 input 5
    APIN_init {  0.035,sz_Pan,'p5',, UNIT_PANNER }  ;// 9 pan 5

    APIN_init {  0.893,,'6' ,, UNIT_AUTO_UNIT }         ;// 10 input 6
    APIN_init {  0.107,sz_Pan,'p6',, UNIT_PANNER }  ;// 11 pan 6

    APIN_init {  0.808,,'7' ,, UNIT_AUTO_UNIT }         ;// 12 input 7
    APIN_init {  0.192,sz_Pan,'p7',, UNIT_PANNER }  ;// 13 pan 7

    APIN_init {  0.695,,'8' ,, UNIT_AUTO_UNIT }         ;// 14 input 8
    APIN_init {  0.305,sz_Pan,'p8',, UNIT_PANNER }  ;// 15 pan 8

    APIN_init { -0.5,sz_Left ,'L',, PIN_OUTPUT OR UNIT_AUTO_UNIT }  ;// 16 left output
    APIN_init {  0.5,sz_Right,'R',, PIN_OUTPUT OR UNIT_AUTO_UNIT }  ;// 17 right output

    short_name  db  'Mixer',0
    description db  '8 input 2 output mixer with a pan control for each channel.',0
    ALIGN 4


    ;// osc map for this object

    OSC_MAP STRUCT

        OSC_OBJECT  {}
        pin_x0  APIN    {}
        pin_p0  APIN    {}
        pin_x1  APIN    {}
        pin_p1  APIN    {}
        pin_x2  APIN    {}
        pin_p2  APIN    {}
        pin_x3  APIN    {}
        pin_p3  APIN    {}
        pin_x4  APIN    {}
        pin_p4  APIN    {}
        pin_x5  APIN    {}
        pin_p5  APIN    {}
        pin_x6  APIN    {}
        pin_p6  APIN    {}
        pin_x7  APIN    {}
        pin_p7  APIN    {}

        pin_L   APIN    {}
        pin_R   APIN    {}

        data_L  dd  SAMARY_LENGTH dup(0)
        data_R  dd  SAMARY_LENGTH dup(0)

    OSC_MAP ENDS


;// macros


;//    if pK is negative
;//       L = I * ( 1 + pK )  =  I + I * pk
;//       R = I
;//
;//    if pK is positive
;//       L = I
;//       R = I * ( 1 - pK )  =  I - I * pk
;//
;//    if pK is zero
;//       L = I
;//       R = I



.CODE

ASSUME_AND_ALIGN
mixer_LoadUndo PROC

    ret

mixer_LoadUndo ENDP


comment ~ /*

    the new mixer calc

    for 8 pairs of inputs:  X S [L R]

        case        output          changing
        -------------------------------------
        if S > 0
                    L += X          cL |= cX
                    R += X-S*X      cR |= cX | cS
        else S < 0
                    L += X+S*X      cL |= cX | cS
                    R += X          cR |= cX

    by keeping track of changing seperately, it can be blocked if nessesary

    optimization can be accomplished by breaking the stream into pairs of two samples
    there are then four cases indicated by two bits

    dXdS_both

    ;// dXdS_both_loader

        xor eax, eax    ;// make sure this is zero

        fld L0
        mov edx, S0
        fld R0
        shld eax, edx, 1
        fld L1
        mov edx, S1
        fld R1
        shld eax, edx, 1

        fld X0
        fld S0
        fmul st, st(1)

        fld X1
        fld S1
        fmul st, st(1)

        jmp mixer_dXdS_both[eax*4]


    for these, L and/or R are to be set as changing

;// mixer_dXdS_both:

    ;// mixer_dXdS_00_both:
    ;// mixer_dXdS_01_both:
    ;// mixer_dXdS_10_both:
    ;// mixer_dXdS_11_both:

;// mixer_dXdS_left:

    ;// mixer_dXdS_00_left:     work out the correct form for left right
    ;// mixer_dXdS_01_left:     should be able to do 4 at a time ?
    ;// mixer_dXdS_10_left:     need seperate left and right, becuase one adds,
    ;// mixer_dXdS_11_left:     the other subtracts

;// mixer_dXdS_right:

    ;// mixer_dXdS_00_right:
    ;// mixer_dXdS_01_right:
    ;// mixer_dXdS_10_right:
    ;// mixer_dXdS_11_right:


    set changing on the fly according to S

;// mixer_sXdS_both:

    ;// mixer_sXdS_00_both:
    ;// mixer_sXdS_01_both:
    ;// mixer_sXdS_10_both:
    ;// mixer_sXdS_11_both:

;// mixer_sXdS_left:

    ;// mixer_sXdS_00_left:
    ;// mixer_sXdS_01_left:
    ;// mixer_sXdS_10_left:
    ;// mixer_sXdS_11_left:

;// mixer_sXdS_right:

    ;// mixer_sXdS_00_right:
    ;// mixer_sXdS_01_right:
    ;// mixer_sXdS_10_right:
    ;// mixer_sXdS_11_right:

    set changing is on for both,
    unless S=1 or -1, then output is simply xefrred
    do these using the appropriate math_MulAdd function

;// mixer_dXsS_both:
;// mixer_dXsS_left:
;// mixer_dXsS_right:

;// mixer_dXnS_both:
;// mixer_dXnS_left:
;// mixer_dXnS_right:

    all of these produce static output

;// mixer_sXsS_both:
;// mixer_sXsS_left:
;// mixer_sXsS_right:

;// mixer_sXnS_both:
;// mixer_sXnS_left:
;// mixer_sXnS_right:



registers

    esi is osc
    ecx counts

    LR outputs are addressed by [esi].data_L and [esi].data_R

    ebx is X
    edi is S

    that leaves eax, edx and ebp to mess with

    let ebp scan pairs of pins

        we'll trick it by setting as osc_map
        then always adding two pairs to it
        we'll also kludge the first pass by zeroing the outputs (when nessesary)
        the last pair is when ebp goes past pin_L

    edx can be the status


ALGORITHM

    after determining what mode (LEFT RIGHT BOTH)

    1)  for all X connections do this

        dXdS, dXsS, sXdS, dXnS

            add to list and increase the 'todo' counter

        sXsS, sXnS

            caclulate the first value and set the GOT_STATIC flags

    2) fill the frame(s) with first value

    3) process the 'todo' count using lookahead methods described above

    4) clean up

*/ comment ~


;// special values used in the calc


    dX_COUNT_TEST   equ 000000FFh   ;// test value for the 'todo' list
    LEFT_CHANGING   equ 00000100h   ;// tracks the changing signal state for left side
    RIGHT_CHANGING  equ 00000200h   ;// tracks the changing signal state for right side

    BOTH_CHANGING equ LEFT_CHANGING OR RIGHT_CHANGING

    GOT_STATIC      equ 00000400h   ;// previous change state of left



;////////////////////////////////////////////////////////////////////
;//
;//
;//     mixer_Calc
;//
ASSUME_AND_ALIGN
mixer_Calc PROC uses ebp    ;// STDCALL uses esi edi pObject:PTR OSC_OBJECT

    ASSUME esi:PTR OSC_MAP
    ASSUME ebp:PTR OSC_MAP

    xor edx, edx    ;// edx will have several purposes
                    ;// see MIXER_FLAGS above

    xor edi, edi    ;// so does edi
    xor ebx, ebx    ;// ebx needs to be cleared between iterations


;////////////////////////////////////////////////////////////////////
;//
;//                     applies to all three modes
;//     mixer_FIRST     first scan
;//
;//
;//     dXdS, dXsS, sXdS, dXnS
;//
;//         add to list and increase the 'todo' counter
;//
;//     sXsS, sXnS
;//
;//         caclulate the first value and set the GOT_STATIC flags
;//         first valuse are stored in the fpu

    fldz            ;// R
    mov ebp, esi    ;// ebp iterates pins
    fld st          ;// L   R

mixer_FIRST:

    OR_GET_PIN [ebp].pin_x0.pPin, ebx   ;// get and test the first pin
    jz mixer_FIRST_loop                 ;// skip if not connected

    test [ebx].dwStatus, PIN_CHANGING   ;// check if changing
    jz mixer_FIRST_sX

mixer_FIRST_dX:

    push ebp    ;// store the pointer
    inc edx     ;// increase the count
    jmp mixer_FIRST_loop    ;// jump to loop

ALIGN 16
mixer_FIRST_sX:

    or edx, GOT_STATIC      ;// set GOT_STATIC

    mov ebx, [ebx].pData    ;// get the X source data
    xor eax, eax            ;// clear for testing
    or eax, DWORD PTR [ebx] ;// load and test first value
    jz mixer_FIRST_loop     ;// if zero, skip this pin

    ;// static value at X is NOT zero

    OR_GET_PIN [ebp].pin_p0.pPin, edi   ;// load and get the pan pin
    jz mixer_FIRST_sXnS                 ;// jump if not connected

    test [edi].dwStatus, PIN_CHANGING   ;// check if changing
    jnz mixer_FIRST_dX                  ;// jump to todo list if so

;mixer_FIRST_sXsS:

    xor ecx, ecx
    mov edi, [edi].pData    ;// get the p0 data pointer

    or ecx, DWORD PTR [edi] ;// load and test the first value
    jz mixer_FIRST_sXnS     ;// zero is th same as not connected

;// state:
;//
;//     ebx points at first X value
;//     edi points at first S value
;//     ecx holds the first S value
;//     sign flag indicates the sign of ecx

    fld DWORD PTR [ebx]             ;// X   L   R
    fld DWORD PTR [edi] ;// S   X   L   R
    fmul st, st(1)      ;// SX  X   L   R

    .IF SIGN?
        fadd st, st(1)  ;// dL  dR  L   R
    .ELSE
        fsubr st, st(1) ;// dR  dL  L   R
        fxch            ;// dL  dR  L   R
    .ENDIF

    faddp st(2), st     ;// dR  L   R
    faddp st(2), st     ;// L   R

    jmp mixer_FIRST_loop

ALIGN 16
mixer_FIRST_sXnS:

    fld DWORD PTR [ebx] ;// X   L   R
    fadd st(2), st      ;// X   L   R
    fadd                ;// L   R
    ;// jmp mixer_FIRST_loop

mixer_FIRST_loop:

    add ebp, (SIZEOF APIN) * 2
    xor ebx, ebx                ;// ebx must be clear for testing
    lea eax, [esi].pin_x7
    xor edi, edi                ;// edi must be clear for testing
    cmp eax, ebp
    ja mixer_FIRST

;// now we have a todo list
;// and the first values in fpu

    fstp [esi].data_L   ;// R
    fstp [esi].data_R   ;// empty

;//
;//     first scan
;//
;//
;////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////
;//
;//
;//     second scan
;//

;// state:  dl has count of pin pointers in the stack
;//         GOT_STATIC may be set, or not
;//         esi is the osc

;// determine LEFT RIGHT BOTH

    xor ebx, ebx

    cmp [esi].pin_L.pPin, ebx
    je mixer_RIGHT

    cmp [esi].pin_R.pPin, ebx
    je mixer_LEFT


;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////
;////
;////   mixer_BOTH
;////
mixer_BOTH:                 ;// both outs are connected

    call static_fill_LEFT   ;// take care of filling the left side
    call static_fill_RIGHT  ;// take care of filling the right side

mixer_BOTH_top:     ;// loop through the todo list

    dec dl                  ;// decrease the counter
    js mixer_BOTH_done      ;// if sign then we're done

    pop ebp                 ;// retrive the pin pair
                            ;// remember, this is a fake OSC_MAP pointer

    xor ebx, ebx    ;// clear for testing
    xor edi, edi    ;// clear for testing

    GET_PIN [ebp].pin_x0.pPin, ebx      ;// get the X pin
    DEBUG_IF <!!ebx>                    ;// supposed to be connected !!

    test [ebx].dwStatus, PIN_CHANGING   ;// test if changing
    mov ebx, [ebx].pData                ;// get the data pointer
    jz mixer_BOTH_sXdS                  ;// jmp if not changing

    OR_GET_PIN [ebp].pin_p0.pPin, edi   ;// get the S pin
    jz mixer_BOTH_dXnS                  ;// check if connected

    test [edi].dwStatus,PIN_CHANGING    ;// see if S pin is changing
    mov edi, [edi].pData                ;// get the data pointer
    jz mixer_BOTH_dXsS                  ;// jump if not changing

;////////////////////////////////////////////////////////////////////
;//
;//
;//     mixer_BOTH_dXdS
;//
mixer_BOTH_dXdS:

    ASSUME ebx:PTR DWORD    ;// state:  ebx is X data
    ASSUME edi:PTR DWORD    ;//         edi is S data

    xor ecx, ecx
    or edx, BOTH_CHANGING

mixer_BOTH_dXdS_top:

    ;// preload/pre-calc the common items

    fld [ebx+ecx]           ;// X0
    fld [edi+ecx]           ;// S0  X0
    fmul st, st(1)          ;// SX0 X0

    fld [ebx+ecx+4]         ;// X1  SX0 X0
    fld [edi+ecx+4]         ;// S1  X1  SX0 X0
    fmul st, st(1)          ;// SX1 X1  SX0 X0

    fld [esi+ecx].data_L    ;// L0  SX1 X1  SX0 X0
    fadd st, st(4)          ;// LX0 SX1 X1  SX0 X0
    fld [esi+ecx].data_R    ;// R0  LX0 SX1 X1  SX0 X0
    faddp st(5), st         ;// LX0 SX1 X1  SX0 RX0

    fld [esi+ecx+4].data_L  ;// L1  LX0 SX1 X1  SX0 RX0
    fadd st, st(3)          ;// LX1 LX0 SX1 X1  SX0 RX0
    fld [esi+ecx+4].data_R  ;// R1  LX1 LX0 SX1 X1  SX0 RX0
    faddp st(4), st         ;// LX1 LX0 SX1 RX1 SX0 RX0

    ;// get enough info to build the jumps

    mov eax, [edi+ecx]
    rcl eax, 1              ;// sign of S0 is in carry flag
    mov eax, [edi+ecx+4]    ;// sign of S1 is in eax

    jc mixer_BOTH_dXdS_1x   ;// first jump

mixer_BOTH_dXdS_0x:             ;// LX1 LX0 SX1 RX1 SX0 RX0

    ;// L0 = LX0
    ;// R0 = RX0-SX0

        fxch                    ;// LX0 LX1 SX1 RX1 SX0 RX0
        fstp [esi+ecx].data_L   ;// LX1 SX1 RX1 SX0 RX0
        or eax, eax
        fxch st(3)              ;// SX0 SX1 RX1 LX1 RX0
        fsubp st(4), st         ;// SX1 RX1 LX1 R0
        js mixer_BOTH_dXdS_01

        mixer_BOTH_dXdS_00:         ;// SX1 RX1 LX1 R0

            ;// L1 = LX1
            ;// R1 = RX1-SX0

            fxch st(2)              ;// LX1 RX1 SX1 R0
            fstp [esi+ecx+4].data_L ;// RX1 SX1 R0
            fsubr                   ;// R1  R0
            fxch                    ;// R0  R1
            fstp [esi+ecx].data_R   ;// R1
            fstp [esi+ecx+4].data_R ;//

            add ecx, 8
            cmp ecx, SAMARY_SIZE
            jb mixer_BOTH_dXdS_top
            jmp mixer_BOTH_top

        ALIGN 16
        mixer_BOTH_dXdS_01:         ;// SX1 RX1 LX1 R0

            ;// L1 = LX1+SX1
            ;// R1 = RX1

            faddp st(2), st         ;// RX1 L1  R0
            fstp [esi+ecx+4].data_R ;// L1  R0
            fxch                    ;// R0  L1
            fstp [esi+ecx].data_R   ;// L1
            fstp [esi+ecx+4].data_L ;//

            add ecx, 8
            cmp ecx, SAMARY_SIZE
            jb mixer_BOTH_dXdS_top
            jmp mixer_BOTH_top


ALIGN 16
mixer_BOTH_dXdS_1x:             ;// LX1 LX0 SX1 RX1 SX0 RX0

    ;// L0 = LX0+SX0
    ;// R0 = RX0

        fxch st(5)              ;// RX0 LX0 SX1 RX1 SX0 LX1
        fstp [esi+ecx].data_R   ;// LX0 SX1 RX1 SX0 LX1
        or eax, eax
        faddp st(3), st         ;// SX1 RX1 L0  LX1

        js mixer_BOTH_dXdS_11

        mixer_BOTH_dXdS_10:         ;// SX1 RX1 L0  LX1

            ;// L1 = LX1
            ;// R1 = RX1-SX1

            fsub                    ;// R1  L0  L1

            fxch st(2)              ;// L1  L0  R1
            fstp [esi+ecx+4].data_L ;// L0  R1
            fstp [esi+ecx].data_L   ;// R1
            fstp [esi+ecx+4].data_R ;//

            add ecx, 8
            cmp ecx, SAMARY_SIZE
            jb mixer_BOTH_dXdS_top
            jmp mixer_BOTH_top

        ALIGN 16
        mixer_BOTH_dXdS_11:         ;// SX1 RX1 L0  LX1

            ;// L1 = LX1+SX1
            ;// R1 = RX1

            faddp st(3), st         ;// R1  L0  L1

            fstp [esi+ecx+4].data_R ;// L0  L1
            fstp [esi+ecx].data_L   ;// L1
            fstp [esi+ecx+4].data_L ;//

            add ecx, 8
            cmp ecx, SAMARY_SIZE
            jb mixer_BOTH_dXdS_top
            jmp mixer_BOTH_top


;//
;//     mixer_BOTH_dXdS
;//
;//
;////////////////////////////////////////////////////////////////////






;////////////////////////////////////////////////////////////////////
;//
;//
;//     mixer_BOTH_dXsS
;//
ALIGN 16
mixer_BOTH_dXsS:

    ASSUME ebx:PTR DWORD    ;// state:  ebx is X data
    ASSUME edi:PTR DWORD    ;//         edi is S data

    ;// this will simply call appropriate muladd functions

    xor eax, eax            ;// clear for testing
    or eax, [edi]           ;// test the first S value
    jz mixer_BOTH_dXnS      ;// if zero, same as nS
    js mixer_BOTH_dXsS_neg  ;// if neg

mixer_BOTH_dXsS_pos:        ;// if pos

    cmp eax, math_1         ;// if S != 1
    je mixer_BOTH_dXsS_pos_1

;mixer_BOTH_dXsS_pos_0:

    or edx, RIGHT_CHANGING  ;// set right as changing

    fld math_1          ;// 1
    fld [edi]               ;// S   1
    fsub                    ;// 1-S

    push edx
    push esi
    push ebx
    push ecx                ;// make room on the stack

    lea edx, [esi].data_R   ;// point dB at right

    fstp DWORD PTR [esp]    ;// store the multiply value

    mov esi, ebx            ;// point dX at X data
    mov edi, edx            ;// dB is also the destination
    mov ebx, esp            ;// point sA at (1-S)

    invoke math_muladd_dXsAdB   ;// call lib function

    pop ecx     ;// clear up the stack
    pop ebx
    pop esi
    pop edx

mixer_BOTH_dXsS_pos_1:

;// stack:  edx esi ebx
;//         00  04  08

    call mixer_accumulate_LEFT

    jmp mixer_BOTH_top

ALIGN 16
mixer_BOTH_dXsS_neg:        ;// if neg

    cmp eax, math_neg_1 ;// if S != -1
    je mixer_BOTH_dXsS_neg_1

;mixer_BOTH_dXsS_neg_0:

    or edx, LEFT_CHANGING   ;// set left as changing

    fld math_1          ;// 1
    fld [edi]               ;// S   1
    fadd                    ;// 1+S

    push edx
    push esi
    push ebx
    push ecx                ;// make room on the stack

    lea edx, [esi].data_L   ;// point dB at left

    fstp DWORD PTR [esp]    ;// store the multiply value

    mov esi, ebx            ;// point dX at X data
    mov edi, edx            ;// dB is also the destination
    mov ebx, esp            ;// point sA at (1-S)

    invoke math_muladd_dXsAdB   ;// call lib function

    pop ecx     ;// clear up the stack
    pop ebx
    pop esi
    pop edx

mixer_BOTH_dXsS_neg_1:

;// stack:  edx esi ebx
;//         00  04  08

    call mixer_accumulate_RIGHT

    jmp mixer_BOTH_top

;//
;//     mixer_BOTH_dXsS
;//
;//
;////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////
;//
;//
;//     mixer_BOTH_dXnS
;//
ALIGN 16
mixer_BOTH_dXnS:
;// state:  ebx is X data
;//         edi is zero

    call mixer_accumulate_LEFT
    call mixer_accumulate_RIGHT

    jmp mixer_BOTH_top
;//
;//     mixer_BOTH_dXnS
;//
;//
;////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////
;//
;//
;//     mixer_BOTH_sXdS
;//
ALIGN 16
mixer_BOTH_sXdS:
;// state:  ebx is X data
;//         edi is zero

    GET_PIN [ebp].pin_p0.pPin, edi
    xor ecx, ecx
    DEBUG_IF < !!([edi].dwStatus & PIN_CHANGING)>   ;// not supposed to be here
    mov edi, [edi].pData

    ASSUME ebx:PTR DWORD    ;// state:  ebx is X data
    ASSUME edi:PTR DWORD    ;//         edi is S data

    DEBUG_IF <!![ebx]>  ;// X data is zero, not s'posed to be here
                        ;// this pin should not have been scheduled in the satck
    fld [ebx]

mixer_BOTH_sXdS_top:

    ;// preload/pre-calc the common items

    fld [esi+ecx].data_L    ;// L0  X
    fadd st, st(1)          ;// LX0 X
    fld [esi+ecx].data_R    ;// R0  LX0 X
    fadd st, st(2)          ;// RX0 LX0 X

    fld [edi+ecx]           ;// S0  RX0 LX0 X
    fmul st, st(3)          ;// SX0 RX0 LX0 X

    fld [esi+ecx+4].data_L  ;// L1  SX0 RX0 LX0 X
    fadd st, st(4)          ;// LX1 SX0 RX0 LX0 X
    fld [esi+ecx+4].data_R  ;// R1  LX1 SX0 RX0 LX0 X
    fadd st, st(5)          ;// RX1 LX1 SX0 RX0 LX0 X

    fld [edi+ecx+4]         ;// S1  RX1 LX1 SX0 RX0 LX0 X
    fmul st, st(6)          ;// SX1 RX1 LX1 SX0 RX0 LX0 X

    ;// get enough info to build the jumps

    mov eax, [edi+ecx]
    rcl eax, 1              ;// sign of S0 is in carry flag
    mov eax, [edi+ecx+4]    ;// sign of S1 is in eax

    jc mixer_BOTH_sXdS_1x   ;// first jump

mixer_BOTH_sXdS_0x:         ;// SX1 RX1 LX1 SX0 RX0 LX0 X

    ;// L0 = LX0
    ;// R0 = RX0-SX0    cR

        or edx, RIGHT_CHANGING

        fxch st(3)              ;// SX0 RX1 LX1 SX1 RX0 L0  X
        fsubp st(4), st         ;// RX1 LX1 SX1 R0  L0  X
        fxch st(4)              ;// L0  LX1 SX1 R0  RX1 X
        or eax, eax
        fstp [esi+ecx].data_L   ;// LX1 SX1 R0  RX1 X
        js mixer_BOTH_sXdS_01

        mixer_BOTH_sXdS_00:         ;// LX1 SX1 R0  RX1 X       cR

            ;// L1 = LX1
            ;// R1 = RX1-SX0    cR

            fstp [esi+ecx+4].data_L ;// SX1 R0  RX1 X
            fsubp st(2), st         ;// R0  R1  X
            fstp [esi+ecx].data_R   ;// R1  X
            fstp [esi+ecx+4].data_R ;// X

            add ecx, 8
            cmp ecx, SAMARY_SIZE
            jb mixer_BOTH_sXdS_top
            fstp st
            jmp mixer_BOTH_top

        ALIGN 16
        mixer_BOTH_sXdS_01:         ;// LX1 SX1 R0  RX1 X       cR

            ;// L1 = LX1+SX1    cL
            ;// R1 = RX1

            fsubr                   ;// L1  R0  R1  X
            fxch st(2)              ;// R1  R0  L1  X

            fstp [esi+ecx+4].data_R ;// R0  L1  X
            or edx, LEFT_CHANGING
            fstp [esi+ecx].data_R   ;// L1  X
            fstp [esi+ecx+4].data_L ;// X

            add ecx, 8
            cmp ecx, SAMARY_SIZE
            jb mixer_BOTH_sXdS_top
            fstp st
            jmp mixer_BOTH_top


ALIGN 16
mixer_BOTH_sXdS_1x:         ;// SX1 RX1 LX1 SX0 RX0 LX0 X

    ;// L0 = LX0+SX0    cL
    ;// R0 = RX0

        or edx, LEFT_CHANGING

        fxch st(3)              ;// SX0 RX1 LX1 SX1 RX0 LX0 X
        faddp st(5), st         ;// RX1 LX1 SX1 RX0 L0  X

        or eax, eax

        fxch st(3)              ;// RX0 LX1 SX1 RX1 L0  X
        fstp [esi+ecx].data_R   ;// LX1 SX1 RX1 L0  X

        js mixer_BOTH_sXdS_11

        mixer_BOTH_sXdS_10:         ;// LX1 SX1 RX1 L0  X       cL

            ;// L1 = LX1
            ;// R1 = RX1-SX1    cR

            fstp [esi+ecx+4].data_L ;// SX1 RX1 L0  X
            or edx, RIGHT_CHANGING
            fsub                    ;// R1  L0  X
            fxch                    ;// L0  R1  X

            fstp [esi+ecx].data_L   ;// R1  X
            fstp [esi+ecx+4].data_R ;// X

            add ecx, 8
            cmp ecx, SAMARY_SIZE
            jb mixer_BOTH_sXdS_top
            fstp st
            jmp mixer_BOTH_top

        ALIGN 16
        mixer_BOTH_sXdS_11:         ;// LX1 SX1 RX1 L0  X       cL

            ;// L1 = LX1+SX1    cL
            ;// R1 = RX1

            fadd                    ;// L1  R1  L0  X
            fxch st(2)              ;// L0  R1  L1  X

            fstp [esi+ecx].data_L   ;// R1  L1  X
            fstp [esi+ecx+4].data_R ;// L1  X
            fstp [esi+ecx+4].data_L ;// X


            add ecx, 8
            cmp ecx, SAMARY_SIZE
            jb mixer_BOTH_sXdS_top
            fstp st
            jmp mixer_BOTH_top


;//
;//     mixer_BOTH_sXdS
;//
;//
;////////////////////////////////////////////////////////////////////


ALIGN 16
mixer_BOTH_done:

    ;// take care of the changing bits

    xor eax, eax
    xor ecx, ecx

    bt edx, LOG2(LEFT_CHANGING)
    rcl eax, LOG2(PIN_CHANGING)+1

    bt edx, LOG2(RIGHT_CHANGING)
    rcl ecx, LOG2(PIN_CHANGING)+1

    or [esi].pin_L.dwStatus, eax
    or [esi].pin_R.dwStatus, ecx

    jmp mixer_all_done

;////
;////   mixer_BOTH
;////
;////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////
;////
;////   mixer_LEFT
;////
ALIGN 16
mixer_LEFT:         ;// only the left out is connected

    DEBUG_IF <!![esi].pin_L.pPin>   ;// not supposed to be scheduled

    call static_fill_LEFT   ;// take care of filling the left side

mixer_LEFT_top:     ;// loop through the todo list

    dec dl                  ;// decrease the counter
    js mixer_LEFT_done      ;// if sign then we're done

    pop ebp                 ;// retrive the pin pair
                            ;// remember, this is a fake OSC_MAP pointer

    xor ebx, ebx    ;// clear for testing
    xor edi, edi    ;// clear for testing

    GET_PIN [ebp].pin_x0.pPin, ebx      ;// get the X pin
    DEBUG_IF <!!ebx>                    ;// supposed to be connected !!

    test [ebx].dwStatus, PIN_CHANGING   ;// test if changing
    mov ebx, [ebx].pData                ;// get the data pointer
    jz mixer_LEFT_sXdS                  ;// jmp if not changing

    OR_GET_PIN [ebp].pin_p0.pPin, edi   ;// get the S pin
    jz mixer_LEFT_dXnS                  ;// check if connected

    test [edi].dwStatus,PIN_CHANGING    ;// see if S pin is changing
    mov edi, [edi].pData                ;// get the data pointer
    jz mixer_LEFT_dXsS                  ;// jump if not changing

;////////////////////////////////////////////////////////////////////
;//
;//
;//     mixer_LEFT_dXdS
;//
mixer_LEFT_dXdS:

    ASSUME ebx:PTR DWORD    ;// state:  ebx is X data
    ASSUME edi:PTR DWORD    ;//         edi is S data

    xor ecx, ecx
    or edx, LEFT_CHANGING

mixer_LEFT_dXdS_top:

    ;// preload/pre-calc the common items

    fld [esi+ecx].data_L    ;// L0
    fld [ebx+ecx]           ;// X0  L0
    fadd st(1), st          ;// X0  LX0

    fld [esi+ecx+4].data_L  ;// L1  X0  LX0
    fld [ebx+ecx+4]         ;// X1  L1  X0  LX0
    fadd st(1), st          ;// X1  LX1 X0  LX0

    ;// get enough info to build the jumps

    mov eax, [edi+ecx]
    rcl eax, 1              ;// sign of S0 is in carry flag
    mov eax, [edi+ecx+4]    ;// sign of S1 is in eax

    jc mixer_LEFT_dXdS_1x   ;// first jump

mixer_LEFT_dXdS_0x:         ;// X1  LX1 X0  LX0

    ;// L0 = LX0

        fxch st(3)              ;// LX0 LX1 X0  X1
        or eax, eax
        fstp [esi+ecx].data_L   ;// LX1 X0  X1
        js mixer_LEFT_dXdS_01

        mixer_LEFT_dXdS_00:         ;// LX1 X0  X1

            ;// L1 = LX1

            fstp [esi+ecx+4].data_L ;// X0  X1
            add ecx, 8
            fstp st                 ;// X1
            cmp ecx, SAMARY_SIZE
            fstp st                 ;//
            jb mixer_LEFT_dXdS_top
            jmp mixer_LEFT_top

        ALIGN 16
        mixer_LEFT_dXdS_01:         ;// LX1 X0  X1

            ;// L1 = LX1+SX1

            fld [edi+ecx+4]         ;// S1  LX1 X0  X1
            fmulp st(3), st         ;// LX1 X0  SX1
            fxch                    ;// X0  LX1 SX1
            fstp st                 ;// LX1 SX1
            fadd                    ;// L1
            fstp [esi+ecx+4].data_L ;//

            add ecx, 8
            cmp ecx, SAMARY_SIZE
            jb mixer_LEFT_dXdS_top
            jmp mixer_LEFT_top


ALIGN 16
mixer_LEFT_dXdS_1x:             ;// X1  LX1 X0  LX0

    ;// L0 = LX0+SX0

        fld [edi+ecx]           ;// S0  X1  LX1 X0  LX0
        or eax, eax
        fmulp st(3), st         ;// X1  LX1 SX0 LX0
        js mixer_LEFT_dXdS_11

        mixer_LEFT_dXdS_10:         ;// X1  LX1 SX0 LX0

            ;// L1 = LX1

            fstp st                 ;// LX1 SX0 LX0
            fstp [esi+ecx+4].data_L ;// SX0 LX0
            fadd                    ;// L0
            fstp [esi+ecx].data_L   ;//

            add ecx, 8
            cmp ecx, SAMARY_SIZE
            jb mixer_LEFT_dXdS_top
            jmp mixer_LEFT_top

        ALIGN 16
        mixer_LEFT_dXdS_11:     ;// X1  LX1 SX0 LX0

            ;// L1 = LX1+SX1

            fld [edi+ecx+4]     ;// S1  X1  LX1 SX0 LX0
            fmul                ;// SX1 LX1 SX0 LX0
            fxch st(2)          ;// SX0 LX1 SX1 LX0
            faddp st(3), st     ;// LX1 SX1 L0
            fadd                ;// L1  L0
            fxch                ;// L0  L1
            fstp [esi+ecx].data_L
            fstp [esi+ecx+4].data_L

            add ecx, 8
            cmp ecx, SAMARY_SIZE
            jb mixer_LEFT_dXdS_top
            jmp mixer_LEFT_top

;//
;//     mixer_LEFT_dXdS
;//
;//
;////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////
;//
;//
;//     mixer_LEFT_dXsS
;//     mixer_LEFT_dXnS
ALIGN 16
mixer_LEFT_dXsS:

    ASSUME ebx:PTR DWORD    ;// state:  ebx is X data
    ASSUME edi:PTR DWORD    ;//         edi is S data

    xor eax, eax            ;// clear for testing
    or eax, [edi]           ;// test the first S value
    ;// jz mixer_LEFT_dXnS  ;// if zero, same as nS
    js mixer_LEFT_dXsS_neg  ;// if neg

;mixer_LEFT_dXsS_pos:       ;// if pos
mixer_LEFT_dXnS:            ;// if zero

    call mixer_accumulate_LEFT

    jmp mixer_LEFT_top

mixer_LEFT_dXsS_neg:        ;// if neg

    cmp eax, math_neg_1 ;// if S != -1
    je mixer_LEFT_top       ;// can skip completely

    or edx, LEFT_CHANGING   ;// set left as changing

    fld math_1          ;// 1
    fld [edi]               ;// S   1
    fadd                    ;// 1+S

    push edx
    push esi
    push ebx
    push ecx                ;// make room on the stack

    lea edx, [esi].data_L   ;// point dB at left

    fstp DWORD PTR [esp]    ;// store the multiply value

    mov esi, ebx            ;// point dX at X data
    mov edi, edx            ;// dB is also the destination
    mov ebx, esp            ;// point sA at (1-S)

    invoke math_muladd_dXsAdB   ;// call lib function

    pop ecx     ;// clear up the stack
    pop ebx
    pop esi
    pop edx

    jmp mixer_LEFT_top

;//
;//     mixer_LEFT_dXsS
;//
;//
;////////////////////////////////////////////////////////////////////




;////////////////////////////////////////////////////////////////////
;//
;//
;//     mixer_LEFT_sXdS
;//
ALIGN 16
mixer_LEFT_sXdS:
;// state:  ebx is X data
;//         edi is zero

    GET_PIN [ebp].pin_p0.pPin, edi
    xor ecx, ecx
    DEBUG_IF < !!([edi].dwStatus & PIN_CHANGING)>   ;// not supposed to be here
    mov edi, [edi].pData

    ASSUME ebx:PTR DWORD    ;// state:  ebx is X data
    ASSUME edi:PTR DWORD    ;//         edi is S data

    DEBUG_IF <!![ebx]>  ;// X data is zero, not s'posed to be here
                        ;// this pin should not have been scheduled in the satck
    fld [ebx]

mixer_LEFT_sXdS_top:

    ;// preload/pre-calc the common items

    fld [esi+ecx].data_L    ;// L0  X
    fadd st, st(1)          ;// LX0 X

    fld [esi+ecx+4].data_L  ;// L1  LX0 X
    fadd st, st(2)          ;// LX1 LX0 X

    ;// get enough info to build the jumps

    mov eax, [edi+ecx]
    rcl eax, 1              ;// sign of S0 is in carry flag
    mov eax, [edi+ecx+4]    ;// sign of S1 is in eax

    jc mixer_LEFT_sXdS_1x   ;// first jump

mixer_LEFT_sXdS_0x:         ;// LX1 LX0 X

    ;// L0 = LX0

        fxch
        or eax, eax
        fstp [esi+ecx].data_L   ;// LX1 X
        js mixer_LEFT_sXdS_01

        mixer_LEFT_sXdS_00:         ;// LX1 X

            ;// L1 = LX1

            fstp [esi+ecx+4].data_L ;// X
            add ecx, 8
            cmp ecx, SAMARY_SIZE
            jb mixer_LEFT_sXdS_top
            fstp st
            jmp mixer_LEFT_top

        ALIGN 16
        mixer_LEFT_sXdS_01:         ;// LX1 X

            ;// L1 = LX1+SX1    cL

            fld [edi+ecx+4]         ;// S1  LX1 X
            fmul st, st(2)          ;// SX1 LX1 X
            or edx, LEFT_CHANGING
            fadd                    ;// L1  X
            fstp [esi+ecx+4].data_L ;// X

            add ecx, 8
            cmp ecx, SAMARY_SIZE
            jb mixer_LEFT_sXdS_top
            fstp st
            jmp mixer_LEFT_top


ALIGN 16
mixer_LEFT_sXdS_1x:         ;// LX1 LX0 X

    ;// L0 = LX0+SX0    cL

        or edx, LEFT_CHANGING

        fld [edi+ecx]           ;// S0  LX1 LX0 X
        or eax, eax
        fmul st, st(3)          ;// SX0 LX1 LX0 X
        js mixer_LEFT_sXdS_11

        mixer_LEFT_sXdS_10:         ;// SX0 LX1 LX0 X       cL

            ;// L1 = LX1

            fxch                    ;// LX1 SX0 LX0 X
            fstp [esi+ecx+4].data_L ;// SX0 LX0 X
            fadd                    ;// L0  X
            fstp [esi+ecx].data_L   ;// X

            add ecx, 8
            cmp ecx, SAMARY_SIZE
            jb mixer_LEFT_sXdS_top
            fstp st
            jmp mixer_LEFT_top

        ALIGN 16
        mixer_LEFT_sXdS_11:         ;// SX0 LX1 LX0 X       cL

            ;// L1 = LX1+SX1    cL

            fld [edi+ecx+4]         ;// S1  SX0 LX1 LX0 X
            fmul st, st(4)          ;// SX1 SX0 LX1 LX0 X
            fxch                    ;// SX0 SX1 LX1 LX0 X
            faddp st(3), st         ;// SX1 LX1 L0  X
            fadd                    ;// L1  L0  X
            fxch                    ;// L0  L1  X

            fstp [esi+ecx].data_L   ;// L1  X
            fstp [esi+ecx+4].data_L ;// X

            add ecx, 8
            cmp ecx, SAMARY_SIZE
            jb mixer_LEFT_sXdS_top
            fstp st
            jmp mixer_LEFT_top

;//
;//     mixer_LEFT_sXdS
;//
;//
;////////////////////////////////////////////////////////////////////

ALIGN 16
mixer_LEFT_done:

    ;// take care of the changing bits

    xor eax, eax

    bt edx, LOG2(LEFT_CHANGING)
    rcl eax, LOG2(PIN_CHANGING)+1

    or [esi].pin_L.dwStatus, eax

    jmp mixer_all_done

;////
;////   mixer_LEFT
;////
;////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////
;////
;////   mixer_RIGHT
;////
ALIGN 16
mixer_RIGHT:            ;// only the left out is connected

    DEBUG_IF <!![esi].pin_R.pPin>   ;// not supposed to be scheduled

    call static_fill_RIGHT  ;// take care of filling the right side

mixer_RIGHT_top:    ;// loop through the todo list

    dec dl                  ;// decrease the counter
    js mixer_RIGHT_done     ;// if sign then we're done

    pop ebp                 ;// retrive the pin pair
                            ;// remember, this is a fake OSC_MAP pointer

    xor ebx, ebx    ;// clear for testing
    xor edi, edi    ;// clear for testing

    GET_PIN [ebp].pin_x0.pPin, ebx      ;// get the X pin
    DEBUG_IF <!!ebx>                    ;// supposed to be connected !!

    test [ebx].dwStatus, PIN_CHANGING   ;// test if changing
    mov ebx, [ebx].pData                ;// get the data pointer
    jz mixer_RIGHT_sXdS                 ;// jmp if not changing

    OR_GET_PIN [ebp].pin_p0.pPin, edi   ;// get the S pin
    jz mixer_RIGHT_dXnS                 ;// check if connected

    test [edi].dwStatus,PIN_CHANGING    ;// see if S pin is changing
    mov edi, [edi].pData                ;// get the data pointer
    jz mixer_RIGHT_dXsS                 ;// jump if not changing

;////////////////////////////////////////////////////////////////////
;//
;//
;//     mixer_RIGHT_dXdS
;//
mixer_RIGHT_dXdS:

    ASSUME ebx:PTR DWORD    ;// state:  ebx is X data
    ASSUME edi:PTR DWORD    ;//         edi is S data

    xor ecx, ecx
    or edx, RIGHT_CHANGING

mixer_RIGHT_dXdS_top:

    ;// preload/pre-calc the common items

    fld [esi+ecx].data_R    ;// R0
    fld [ebx+ecx]           ;// X0  R0
    fadd st(1), st          ;// X0  RX0

    fld [esi+ecx+4].data_R  ;// R1  X0  RX0
    fld [ebx+ecx+4]         ;// X1  R1  X0  RX0
    fadd st(1), st          ;// X1  RX1 X0  RX0

    ;// get enough info to build the jumps

    mov eax, [edi+ecx]
    rcl eax, 1              ;// sign of S0 is in carry flag
    mov eax, [edi+ecx+4]    ;// sign of S1 is in eax

    jc mixer_RIGHT_dXdS_1x  ;// first jump

mixer_RIGHT_dXdS_0x:            ;// X1  RX1 X0  RX0

    ;// R0 = RX0-SX0

        fld [edi+ecx]           ;// S0  X1  RX1 X0  RX0
        or eax, eax
        fmulp st(3), st         ;// X1  RX1 SX0 RX0
        js mixer_RIGHT_dXdS_01

        mixer_RIGHT_dXdS_00:        ;// X1  RX1 SX0 RX0

            ;// R1 = RX1-SX0

            fld [edi+ecx+4]         ;// S1  X1  RX1 SX0 RX0
            fmul                    ;// SX1 RX1 SX0 RX0

            fxch st(3)              ;// RX0 RX1 SX0 SX1
            fsubrp st(2), st        ;// RX1 R0  SX1
            fsubrp st(2), st        ;// R0  R1

            fstp [esi+ecx].data_R   ;// R1
            fstp [esi+ecx+4].data_R ;//

            add ecx, 8
            cmp ecx, SAMARY_SIZE
            jb mixer_RIGHT_dXdS_top
            jmp mixer_RIGHT_top

        ALIGN 16
        mixer_RIGHT_dXdS_01:        ;// X1  RX1 SX0 RX0

            ;// R1 = RX1

            fstp st                 ;// RX1 SX0 RX0
            fstp [esi+ecx+4].data_R ;// SX0 RX0
            fsub                    ;// R0
            fstp [esi+ecx].data_R   ;//

            add ecx, 8
            cmp ecx, SAMARY_SIZE
            jb mixer_RIGHT_dXdS_top
            jmp mixer_RIGHT_top


ALIGN 16
mixer_RIGHT_dXdS_1x:            ;// X1  RX1 X0  RX0

    ;// R0 = RX0

        fxch st(3)              ;// RX0 RX1 X0  X1
        fstp [esi+ecx].data_R   ;// RX1 X0  X1

        or eax, eax
        js mixer_RIGHT_dXdS_11

        mixer_RIGHT_dXdS_10:        ;// RX1 X0  X1

            ;// R1 = RX1-SX1

            fld [edi+ecx+4]         ;// S1  RX1 X0  X1
            fmulp st(3), st         ;// RX1 X0  SX1
            fxch                    ;// X0  RX1 SX1
            fstp st
            fsubr
            fstp [esi+ecx+4].data_R ;//

            add ecx, 8
            cmp ecx, SAMARY_SIZE
            jb mixer_RIGHT_dXdS_top
            jmp mixer_RIGHT_top

        ALIGN 16
        mixer_RIGHT_dXdS_11:        ;// RX1 X0  X1

            ;// R1 = RX1

            fstp [esi+ecx+4].data_R ;// X0  X1

            add ecx, 8
            fstp st
            cmp ecx, SAMARY_SIZE
            fstp st

            jb mixer_RIGHT_dXdS_top
            jmp mixer_RIGHT_top


;//
;//     mixer_RIGHT_dXdS
;//
;//
;////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////
;//
;//
;//     mixer_RIGHT_dXsS
;//     mixer_RIGHT_dXnS
;//
ALIGN 16
mixer_RIGHT_dXsS:

    ASSUME ebx:PTR DWORD    ;// state:  ebx is X data
    ASSUME edi:PTR DWORD    ;//         edi is S data

    xor eax, eax            ;// clear for testing
    or eax, [edi]           ;// test the first S value
    jz mixer_RIGHT_dXnS     ;// if zero, same as nS
    js mixer_RIGHT_dXsS_neg ;// if neg

mixer_RIGHT_dXsS_pos:       ;// if pos

    cmp eax, math_1     ;// if S != 1
    je mixer_RIGHT_top      ;// skip if hard left

;mixer_RIGHT_dXsS_pos_0:

    or edx, RIGHT_CHANGING  ;// set right as changing

    fld math_1          ;// 1
    fld [edi]               ;// S   1
    fsub                    ;// 1-S

    push edx
    push esi
    push ebx
    push ecx                ;// make room on the stack

    lea edx, [esi].data_R   ;// point dB at right

    fstp DWORD PTR [esp]    ;// store the multiply value

    mov esi, ebx            ;// point dX at X data
    mov edi, edx            ;// dB is also the destination
    mov ebx, esp            ;// point sA at (1-S)

    invoke math_muladd_dXsAdB   ;// call lib function

    pop ecx     ;// clear up the stack
    pop ebx
    pop esi
    pop edx

    jmp mixer_RIGHT_top

ALIGN 16
mixer_RIGHT_dXsS_neg:       ;// if neg
mixer_RIGHT_dXnS:

    call mixer_accumulate_RIGHT

    jmp mixer_RIGHT_top

;//
;//
;//     mixer_RIGHT_dXsS
;//
;////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////
;//
;//
;//     mixer_RIGHT_sXdS
;//
ALIGN 16
ALIGN 16
mixer_RIGHT_sXdS:
;// state:  ebx is X data
;//         edi is zero

    GET_PIN [ebp].pin_p0.pPin, edi
    xor ecx, ecx
    DEBUG_IF < !!([edi].dwStatus & PIN_CHANGING)>   ;// not supposed to be here
    mov edi, [edi].pData

    ASSUME ebx:PTR DWORD    ;// state:  ebx is X data
    ASSUME edi:PTR DWORD    ;//         edi is S data

    DEBUG_IF <!![ebx]>  ;// X data is zero, not s'posed to be here
                        ;// this pin should not have been scheduled in the satck
    fld [ebx]

mixer_RIGHT_sXdS_top:

    ;// preload/pre-calc the common items

    fld [esi+ecx].data_R    ;// R0  X
    fadd st, st(1)          ;// RX0 X
    fld [esi+ecx+4].data_R  ;// R1  RX0 X
    fadd st, st(2)          ;// RX1 RX0 X

    ;// get enough info to build the jumps

    mov eax, [edi+ecx]
    rcl eax, 1              ;// sign of S0 is in carry flag
    mov eax, [edi+ecx+4]    ;// sign of S1 is in eax

    jc mixer_RIGHT_sXdS_1x  ;// first jump

mixer_RIGHT_sXdS_0x:        ;// RX1 RX0 X

    ;// R0 = RX0-SX0    cR

        or edx, RIGHT_CHANGING

        fld [edi+ecx]           ;// S0  RX1 RX0 X
        or eax, eax
        fmul st, st(3)          ;// SX0 RX1 RX0 X
        js mixer_RIGHT_sXdS_01

        mixer_RIGHT_sXdS_00:        ;// SX0 RX1 RX0 X       cR

            ;// R1 = RX1-SX0    cR

            fld [edi+ecx+4]         ;// S1  SX0 RX1 RX0 X
            fmul st, st(4)          ;// SX1 SX0 RX1 RX0 X
            fxch                    ;// SX0 SX1 RX1 RX0 X
            fsubp st(3), st         ;// SX1 RX1 R0  X
            fsub                    ;// R1  R0  X
            fxch                    ;// R0  R1  X
            fstp [esi+ecx].data_R   ;// R1  X
        mixer_RIGHT_sXdS_1x_R1:
            fstp [esi+ecx+4].data_R ;// X

            add ecx, 8
            cmp ecx, SAMARY_SIZE
            jb mixer_RIGHT_sXdS_top
            fstp st
            jmp mixer_RIGHT_top

        ALIGN 16
        mixer_RIGHT_sXdS_01:        ;// SX0 RX1 RX0 X       cR

            ;// R1 = RX1

            fsubp st(2), st         ;// R1  R0  X
            fstp [esi+ecx+4].data_R ;// R0  X
            fstp [esi+ecx].data_R   ;// X

            add ecx, 8
            cmp ecx, SAMARY_SIZE
            jb mixer_RIGHT_sXdS_top
            fstp st
            jmp mixer_RIGHT_top


ALIGN 16
mixer_RIGHT_sXdS_1x:            ;// RX1 RX0 X

    ;// R0 = RX0

        fxch                    ;// R0  RX1 X
        or eax, eax
        fstp [esi+ecx].data_R   ;// RX1 X
        js mixer_RIGHT_sXdS_1x_R1

        mixer_RIGHT_sXdS_10:        ;// RX1 X

            ;// R1 = RX1-SX1    cR

            fld [edi+ecx+4]         ;// S1  RX1 X
            fmul st, st(2)          ;// SX1 RX1 X
            or edx, RIGHT_CHANGING
            fsub                    ;// R1  X
            jmp mixer_RIGHT_sXdS_1x_R1

;//
;//     mixer_RIGHT_sXdS
;//
;//
;////////////////////////////////////////////////////////////////////

ALIGN 16
mixer_RIGHT_done:

    ;// take care of the changing bits

    xor eax, eax
    bt edx, LOG2(RIGHT_CHANGING)
    rcl eax, LOG2(PIN_CHANGING)+1
    or [esi].pin_R.dwStatus, eax

;////
;////   mixer_RIGHT
;////
;////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////



mixer_all_done:

    ret






;// local functions
;//


;////////////////////////////////////////////////////////////////////
;//
;//
;//     static_fill     must preserve edx
;//

;// if previously changing
;// or first value does not equal second value

;//     then fill the frame

;// always reset pin changing



ALIGN 16
static_fill_LEFT:

    mov ebx, [esi].pin_L.dwStatus   ;// load the previous pin status
    lea edi, [esi].data_L           ;// get a pointer to the pin data
    btr ebx, LOG_PIN_CHANGING       ;// test and reset the changing bit
    mov eax, DWORD PTR [edi]        ;// load the first value
    jc sfl_00                   ;// if previously changing, have to fill
    cmp eax, DWORD PTR [edi+4]      ;// compare first value with second value
    je @F                           ;// skip fill if they were equal

sfl_00: mov ecx, SAMARY_LENGTH
        rep stosd

@@: mov [esi].pin_L.dwStatus, ebx   ;// store the new pin status
    retn    ;// that's it

ALIGN 16
static_fill_RIGHT:

    mov ebx, [esi].pin_R.dwStatus   ;// load the previous pin status
    lea edi, [esi].data_R           ;// get a pointer to the pin data
    btr ebx, LOG_PIN_CHANGING       ;// test and reset the changing bit
    mov eax, DWORD PTR [edi]        ;// load the first value
    jc sfr_00                       ;// if previously changing, have to fill
    cmp eax, DWORD PTR [edi+4]      ;// compare first value with second value
    je @F                           ;// skip fill if they were equal

sfr_00: mov ecx, SAMARY_LENGTH
        rep stosd

@@: mov [esi].pin_R.dwStatus, ebx   ;// store the new pin status
    retn    ;// that's it


;//
;//     static_fill     must preserve edx
;//
;//
;////////////////////////////////////////////////////////////////////




;////////////////////////////////////////////////////////////////////
;//
;//                             ebx must point at dX data
;//     acumulate routines      edi will be destroyed
;//
ALIGN 16
mixer_accumulate_LEFT:

    ;// ebx must point at X data and is destroyed

    or edx, LEFT_CHANGING   ;// set left changing

    push esi
    push edx

    lea edx, [esi].data_L   ;// set dB as destination
    mov esi, ebx            ;// set dX as X
    mov edi, edx            ;// Y is the same as B
    invoke math_add_dXdB    ;// accumulare left

    pop edx
    pop esi

    retn

ALIGN 16
mixer_accumulate_RIGHT:

    ;// ebx must point at X data and is destroyed
    ;// destroys edi as well

    or edx, RIGHT_CHANGING  ;// set left changing

    push esi
    push edx

    lea edx, [esi].data_R   ;// set dB as destination
    mov esi, ebx            ;// set dX as X
    mov edi, edx            ;// Y is the same as B
    invoke math_add_dXdB    ;// accumulare left

    pop edx
    pop esi

    retn


;//
;//     acumulate routines      edi will be destroyed
;//                             ebx must point at dX data
;//
;////////////////////////////////////////////////////////////////////


mixer_Calc ENDP



ASSUME_AND_ALIGN
mixer_GetUnit PROC

        ASSUME esi:PTR OSC_MAP  ;// preserve
        ASSUME ebx:PTR APIN     ;// preserve

    ;// the mixer wants to xmit units from output to input
    ;// this might be a problem ...

    ;// make sure ebx is lower than pin_L

        lea ecx, [esi].pin_L

        cmp ebx, ecx
        jae all_done    ;// carry flag is clear

    ;// get the status and remove extra bits

        mov eax, [esi].pin_L.dwStatus
        mov edx, [esi].pin_R.dwStatus
        and eax, UNIT_TEST OR UNIT_AUTOED
        and edx, UNIT_TEST OR UNIT_AUTOED

    ;// check the connections

        cmp [esi].pin_L.pPin, 0
        jz L_not_connected

        cmp [esi].pin_R.pPin, 0
        jz L_only

    LR_connected:   ;// both pins are connected

    ;// both units must be autoed and must match

        btr eax, LOG2(UNIT_AUTOED)
        jnc all_done

        btr edx, LOG2(UNIT_AUTOED)
        jnc all_done

        cmp eax, edx
        jne dont_know

        stc
        jmp all_done

    L_only:

    ;// only L is connected

        btr eax, LOG2(UNIT_AUTOED)
        jmp all_done

    L_not_connected:

        cmp [esi].pin_R.pPin, 0
        jz dont_know

    R_only:

    ;// only R is connected

        btr edx, LOG2(UNIT_AUTOED)
        mov eax, edx
        jmp all_done


    dont_know:

        clc

    all_done:

        ret

mixer_GetUnit ENDP





ASSUME_AND_ALIGN

ENDIF   ;// USE_THIS_FILE.
END




