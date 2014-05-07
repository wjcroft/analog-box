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
;// ABox_FFTOP.asm
;//
comment ~ /*

    fft operations

    many of these require a magnitude
    seems asshamed to do that over and over when the fft itself could store such information


*/ comment ~


OPTION CASEMAP:NONE

.586
.MODEL FLAT

USE_THIS_FILE equ 1

IFDEF USE_THIS_FILE

        .NOLIST
        include <Abox.inc>
        .LIST

.DATA


osc_FFTOP OSC_CORE {fftop_Ctor,,,fftop_Calc}
          OSC_GUI  {,fftop_SetShape,,,,fftop_Command,fftop_InitMenu,,,osc_SaveUndo,fftop_LoadUndo}
          OSC_HARD {}

    OSC_DATA_LAYOUT { NEXT_FFTOP,IDB_FFTOP, OFFSET popup_FFTOP,BASE_SHAPE_EFFECTS_GEOMETRY,
    5,4,
    SIZEOF OSC_OBJECT + SIZEOF APIN*5,
    SIZEOF OSC_OBJECT + SIZEOF APIN*5 + SAMARY_SIZE,
    SIZEOF OSC_OBJECT + SIZEOF APIN*5 + SAMARY_SIZE }

    OSC_DISPLAY_LAYOUT {fftop_container,FFTOP_SHIFT_PSOURCE,ICON_LAYOUT(12,2,2,6)}

    APIN_init{ -0.9,OFFSET sz_Spectrum,'X',,UNIT_SPECTRUM } ;// input data
    APIN_init{  0.9,,'n',,UNIT_BINS }                   ;// input data
    APIN_init{  0.6,,'r',,UNIT_BINS }                   ;// parameter 1
    APIN_init{  0.4,,'i',,UNIT_BINS }                   ;// parameter 1
    APIN_init{  0.0,,'=',,PIN_OUTPUT OR UNIT_SPECTRUM   }   ;// output data

    short_name  db  'FFT Oper',0
    description db  'Used to perform data processing and DSP functions on frequency spectrums.',0
    ALIGN 4

    ;// values for dwUser, never really used directly
    ;// dwUser will always be an index
    ;// use IDC_FFTOP_BASE to xlate between control ID's and dwUser values

        ;// function                    form        spec    scale       total
        ;//                                         input   inputs      inputs

        FFTOP_SHIFT     EQU     0   ;// Z[]=X[+a]       1       1           2
        FFTOP_SCALE     EQU     1   ;// Z[]=X[*a]       1       1           2
        FFTOP_CULL      EQU     2   ;// Z[]=nearest     1                   1
        FFTOP_MAG2      EQU     3   ;// Z[]=X[]^2       1                   1
        FFTOP_CONJ      EQU     4   ;// Z[]=*X[]        1                   1
        FFTOP_SORT      EQU     5   ;// sort by mag2    1       1           2
        FFTOP_REPLACE   EQU     6   ;// Z[n]=(r,i)      1       3           4
        FFTOP_INJECT    EQU     7   ;// Z[n]+=(r,i)     1       3           4
        FFTOP_MULTIPLY  EQU     8   ;// X[]*Y[]         2                   2
        FFTOP_DIVIDE    EQU     9   ;// X[]/Y[]         2                   2
        FFTOP_POWER     EQU     10  ;// X[n]^2          1       1           2
        FFTOP_REAL      EQU     11
        FFTOP_IMAG      EQU     12

        FFTOP_MAXIMUM  equ  12      ;// don't allow higher than this

    ;// PSOURCE table, indexed by dwUser, points at source bits for graphics

    fftop_pSource   LABEL DWORD

        dd  FFTOP_SHIFT_PSOURCE
        dd  FFTOP_SCALE_PSOURCE
        dd  FFTOP_CULL_PSOURCE
        dd  FFTOP_MAG2_PSOURCE
        dd  FFTOP_CONJ_PSOURCE
        dd  FFTOP_SORT_PSOURCE
        dd  FFTOP_REPLACE_PSOURCE
        dd  FFTOP_INJECT_PSOURCE
        dd  FFTOP_MUL_PSOURCE
        dd  FFTOP_DIV_PSOURCE
        dd  FFTOP_POWER_PSOURCE
        dd  FFTOP_REAL_PSOURCE
        dd  FFTOP_IMAG_PSOURCE

    ;// calc jump table

    fftop_calc_jump LABEL DWORD

        dd  fftop_shift
        dd  fftop_scale
        dd  fftop_cull
        dd  fftop_mag2
        dd  fftop_conj
        dd  fftop_sort
        dd  fftop_replace
        dd  fftop_inject
        dd  fftop_mul
        dd  fftop_div
        dd  fftop_power
        dd  fftop_real
        dd  fftop_imag


    ;// pin fonts and config info

    fftop_pin_table LABEL DWORD

        dd  -1  ;// = 0     ;// -1 tags this table as needing to be built
        dd  'n' ;// n   1
        dd  'Y' ;// Y   2
        dd  'b' ;// b   3
        dd  'a' ;// a   4
        dd  'r' ;// r   5
        dd  'i' ;// i   6
        dd  0   ;// terminator

    fftop_pin_name_table LABEL DWORD

        dd  0   ;// = 0
        dd  OFFSET sz_Index     ;// n   1
        dd  OFFSET sz_Spectrum  ;// Y   2
        dd  OFFSET sz_Shift     ;// b   3
        dd  OFFSET sz_Scale     ;// a   4
        dd  OFFSET sz_Real      ;// r   5
        dd  OFFSET sz_Imag      ;// i   6

    fftop_pin_unit_table LABEL DWORD

        dd  0   ;// = 0
        dd  UNIT_BINS       ;// n   1
        dd  UNIT_SPECTRUM   ;// Y   2
        dd  UNIT_PERCENT    ;// b   3
        dd  UNIT_PERCENT    ;// a   4
        dd  UNIT_VALUE      ;// r   5
        dd  UNIT_VALUE      ;// i   6


    fftop_config_table  LABEL DWORD

        ;// read as 3 bytes i,r,n that are indexes into the above table
        ;// if any are zero, the pin must be hidden
        ;// the ff at the top terminates the loop
        ;//
        ;//     i r n                       X   n           r       i       =
        dd  0ff000003h  ;// fftop_shift     X   b percent                   spectrum
        dd  0ff000004h  ;// fftop_scale     X   a percent                   spectrum
        dd  0ff000000h  ;// fftop_cull      X                               spectrum
        dd  0ff000000h  ;// fftop_mag2      X                               spectrum
        dd  0ff000000h  ;// fftop_conj      X                               spectrum
        dd  0ff000001h  ;// fftop_sort      X   n bins                      spectrum
        dd  0ff060501h  ;// fftop_replace   X   n bins      r val   i val   spectrum
        dd  0ff060501h  ;// fftop_inject    X   n bin       r val   i val   spectrum
        dd  0ff000002h  ;// fftop_mul       X   Y spectrum                  spectrum
        dd  0ff000002h  ;// fftop_div       X   Y spectrum                  spectrum
        dd  0ff000001h  ;// fftop_power     X   n bin                       value
        dd  0ff000001h  ;// fftop_real      X   n bin                       value
        dd  0ff000001h  ;// fftop_imag      X   n bin                       value


    ;// OSC MAP for this object

    OSC_MAP STRUCT

        OSC_OBJECT  {}
        pin_x   APIN    {}
        pin_n   APIN    {}
        pin_r   APIN    {}
        pin_i   APIN    {}
        pin_y   APIN    {}
        data_y  dd SAMARY_LENGTH DUP (0)

    OSC_MAP ENDS




.CODE





ASSUME_AND_ALIGN
fftop_SyncPins  PROC uses edi

    ;// destroys ebx and edi

    ASSUME esi:PTR OSC_MAP
    ASSUME ebp:PTR LIST_CONTEXT

    ;// make suret he resources are built

        .IF fftop_pin_table

            inc fftop_pin_table

            lea ebx, fftop_pin_table[4]
            ASSUME ebx:PTR DWORD

            mov eax, [ebx]
            .REPEAT

                lea edi, font_pin_slist_head
                invoke font_Locate
                mov [ebx], edi

                xor eax, eax
                add ebx, 4
                or eax, [ebx]

            .UNTIL ZERO?

        .ENDIF

    ;// verify dwUser and set the shape

        mov ecx, [esi].dwUser   ;// ecx will scan the three config values

        .IF ecx > FFTOP_MAXIMUM
            xor ecx, ecx
            mov [esi].dwUser, ecx
        .ENDIF

        mov eax, fftop_pSource[ecx*4]
        mov [esi].pSource, eax

    ;// set the ouput pin to the correct units

        mov eax, UNIT_SPECTRUM
        .IF ecx >= FFTOP_POWER && ecx <= FFTOP_IMAG
            mov eax, UNIT_VALUE
        .ENDIF
        lea ebx, [esi].pin_y
        invoke pin_SetUnit

    ;// scan through the three parameter pins

        lea ebx, [esi].pin_n    ;// ebx will iterate pins
        ASSUME ebx:PTR APIN

        mov ecx, fftop_config_table[ecx*4]
        mov edi, 0ffh

    top_of_loop:

        and edi, ecx
        invoke pin_Show, edi    ;// GDI_INVALIDATE_PIN eax  ;// hide or not

        .IF edi
            invoke pin_SetNameAndUnit,
                fftop_pin_table[edi*4],
                fftop_pin_name_table[edi*4],
                fftop_pin_unit_table[edi*4]
        .ENDIF

        shr ecx, 8
        mov edi, 0ffh
        add ebx, SIZEOF APIN

        cmp edi, ecx
        jne top_of_loop

        ret

fftop_SyncPins ENDP


ASSUME_AND_ALIGN
fftop_Ctor PROC

    invoke fftop_SyncPins
    ret

fftop_Ctor ENDP








ASSUME_AND_ALIGN
fftop_Calc  PROC USES esi

    ASSUME esi:PTR OSC_MAP

    mov ecx, [esi].dwUser
    cmp ecx, FFTOP_MAXIMUM
    ja all_done

    xor ebx, ebx

    lea edi, [esi].data_y
    ASSUME edi:PTR DWORD

    OR_GET_PIN [esi].pin_x.pPin, ebx
    .IF ZERO?
        mov ebx, math_pNullPin
    .ENDIF

    jmp fftop_calc_jump[ecx*4]


;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
ALIGN 16
fftop_shift::

    ASSUME edi:PTR DWORD    ;// edi points at dest data
    ASSUME ebx:PTR APIN     ;// ebx points at X input source pin

    ;// if neg then shift back, zero at end
    ;// if pos shift forward, zero at begin


    ;// set the changing status correctly

        mov ecx, [esi].pin_y.dwStatus   ;// load the current bit
        mov edx, [ebx].dwStatus         ;// load the new bit

        btr ecx, LOG2(PIN_CHANGING)     ;// reset the current pin changing bit
        xor eax, eax                    ;// use for rebuilding the bit

        bt edx, LOG2(PIN_CHANGING)      ;// put the new changing bit in the carry flag
        rcl eax, LOG2(PIN_CHANGING)+1   ;// build the new bit
        or ecx, eax                     ;// merge into out flag

        mov [esi].pin_y.dwStatus, ecx   ;// put new value back in dwUser


    ;// determine the desired shift index

        xor edx, edx        ;// clear for testing

        push esi            ;// need to save
        push ebp            ;// will use for sign testing

        OR_GET_PIN [esi].pin_n.pPin, edx    ;// get the index pin

        fld math_512        ;// load the scaling value

        .IF ZERO?           ;// make sure index pin is connected
            mov edx, math_pNullPin
        .ENDIF

        mov edx, [edx].pData;// point at index pin's source data
        ASSUME edx:PTR DWORD

        xor eax, eax        ;// clear

        fmul [edx]          ;// scale to 512
        push edx            ;// make room on the stack
        mov ebp, [edx]      ;// load value for sign testing
        fabs                ;// always be positive
        mov ecx, eax        ;// gots to zero
        fistp DWORD PTR [esp];// store on stack

        mov ebx, [ebx].pData;// point at source data
        ASSUME ebx:PTR DWORD

        pop edx             ;// get the index
        .IF edx > 512       ;// must 512 or less
            mov edx, 512
        .ENDIF

    ;// determine left or right

        or ebp, ebp         ;// test for sign
        js negative_shift   ;// jump if negative


    positive_shift:

    ;// pos shift
    ;//
    ;// state
    ;//
    ;// esi points at OSC_MAP
    ;// edx has index n
    ;// edi points at dest data
    ;// ebx points at source data
    ;// eax is zero
    ;// ecx is zero
        comment ~ /*

            k > 0

            assume that an iterator will keep track of the destination
            the iterator always start s at dest zero

            0                                    512
            |------------------------b->|        |
        IN  --------------------------------------

        OUT --------------------------------------
            |------->|------------------------b->|
                0    a                           512


            a = k*512       edx
            b = 512 - a

            zero for a
            copy from 0 for b

        */ comment ~

            shrd ecx, edx, 31   ;// scale ecx as edx*2 and check for zero
            jz SP1

            lea ecx, [edx*2];// (always do pairs)
            rep stosd

    SP1:    mov ecx, 512    ;// 512
            sub ecx, edx    ;// 512 - a
            jz SP2          ;// exit if zero
            mov esi, ebx
            shl ecx, 1      ;// (always do pairs)
            rep movsd

    SP2:    pop ebp
            pop esi
            jmp all_done


    ALIGN 16
    negative_shift:

    ;// neg shift
    ;//
    ;// state
    ;//
    ;// esi points at OSC_MAP
    ;// edx has index n
    ;// edi points at dest data
    ;// ebx points at source data
    ;// eax is zero
    ;// ecx is zero
        comment ~ /*

            k < 0

            assume that an iterator will keep track of the destination
            the iterator always start s at dest zero

            0        a                           512
            |        |------------------------b->|
        IN  --------------------------------------

        OUT --------------------------------------
            |------------------------b->|-----c->|
            0                               0    512


            a = k*512
            b = 512 - a
            c = 512 - b = 512 - 512 + a  = a

            copy from a for b
            zero for c

        */ comment ~

            mov ecx, 512
            sub ecx, edx            ;// 512 - a
            jz SN1
            lea esi, [ebx+edx*8]    ;// a
            shl ecx, 1              ;// copy pairs
            rep movsd

    SN1:    shrd ecx, edx, 31   ;// a*2 and check for zero
            jz SN2
            rep stosd

    SN2:    pop ebp
            pop esi
            jmp all_done




;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
ALIGN 16
fftop_scale::

    ASSUME edi:PTR DWORD    ;// edi points at dest data
    ASSUME ebx:PTR APIN     ;// ebx points at X input source pin

    comment ~ /*

    ver 1

        there are two modes, scale up and scale down
        scale up means a > 0  it is an expand operation
        scale down means a < 0 , it is shrink operation

        to convert a to k, the scale value
        we'll use the formula k = 2 ^ 2a

            this means that +- 1/2 goes to * / 2 x

        after that, we do the two mode differently

        for both modes, the following nomenclature is adopted

        k   scaling ratio

        X   input spectrum
        m   bin index of the input data
        Y   output spectrum
        n   bin index of the output data
        end index to stop scanning

    algorithm for either

    0)  set changing status
    1)  determine expand or reduce and derive k
        if zero, copy the data and split
    2)  zero the output data
    3)  do the scan

    */ comment ~

    ;// 0) set changing status

        or [esi].pin_y.dwStatus, PIN_CHANGING

    ;// 1) determine expand or reduce and derive k

        ;// get the scale value

        xor edx, edx
        OR_GET_PIN [esi].pin_n.pPin, edx    ;// get the pin
        .IF ZERO?                       ;// connected ?
            mov edx, math_pNullPin
        .ENDIF

        mov edx, [edx].pData        ;// point at data
        ASSUME edx:PTR DWORD

        .IF !([edx])                ;// a == 0 ?

            ;// move the data and split
            push esi
            mov ecx, SAMARY_LENGTH
            mov esi, [ebx].pData
            rep movsd
            pop esi
            jmp all_done

        .ENDIF

        ;// determine k

        ;// k = 2^2a
        ;// need to do extra work to make sure the exponent works right

        fld [edx]       ;// a
        fadd st, st     ;// 2a

        ;// equ_pow2:   barrowed from equation.asm
            fld1        ;// 1   x   ...
            fxch        ;// x   1   ...
            fld st      ;// x   x   1   ...
            fabs        ;// x   x   1   ...
            fucomp st(2);// x   1   ...
            fnstsw ax
            sahf
            ja pow2_long_method
        pow2_short_method:  ;// x < 1
            f2xm1           ;// ex-1    1
            fadd
            jmp equ_pow2_done
        pow2_long_method:   ;// 2^frac_part * 2^int_part
            fld st          ;// x   x   1
            fsub math_1_2
            frndint         ;// ix  x   1
            fsub st(1), st  ;// ix  fx  1
            fxch            ;// fx  ix  1
            f2xm1           ;// efx-1   ix  1
            faddp st(2), st ;// ix  efx
            fxch            ;// efx ix
            fscale          ;// ex  ix
            fxch            ;// ix  ex
            fstp st         ;// ex
        equ_pow2_done:
        ;// now k is in fpu

    ;// 2) zero the output data

        mov ecx, SAMARY_LENGTH
        xor eax, eax
        rep stosd
        lea edi, [esi].data_y

    ;// jump to correct method

        or edx, [edx]           ;// simple enough, the high bit should never be set for a pointer
        push eax                ;// make room on the stack
        st_iter TEXTEQU <(DWORD PTR [esp])>
        mov ebx, [ebx].pData    ;// get the input data pointer
        ASSUME ebx:PTR DWORD    ;// input data
        js negative_scale


    positive_scale:

    ;// expand  k > 1

    comment ~ /*

            0   m       end
            |-->|       |
    IN  X   --------------------------
            |    \       \__________
            |     \                 \
    OUT Y   --------------------------
            |      |                 |
            0      n                 512

        start n and m at 0

        Y[n] = X[m]

        n += k  ; edi + ecx*8
        m += 1  ; ebx

        N = round(n)
        N >= 512 ? exit : loop

    */ comment ~

            fldz            ;// n   K

            xor ecx, ecx

    PS1:    fadd st, st(1)          ;// n+=K    K

            mov eax, [ebx]          ;// get the real part
            mov edx, [ebx+4]        ;// get the imaginary part

            fist st_iter            ;// store

            mov [edi+ecx*8], eax    ;// store the real part
            mov [edi+ecx*8+4], edx  ;// store the imaginary part

            mov ecx, st_iter        ;// load in ecx

            add ebx, 8              ;// m += 1

            cmp ecx, 512            ;// done yet ?
            jb PS1                  ;// loop if not done

        ;// done, clean out two fpu's, clean up the stack, exit

            fstp st
            add esp, 4
            fstp st
            jmp all_done


    ALIGN 16
    negative_scale:

    ;// reduce k < 1

    comment ~ /*
                   ecx
            0       m                512        start m and n at 0
            |       |                |
    IN  X   --------------------------          Y[n] = X[m]
            |      /       _________/
            |     /       /                     n += 1
    OUT Y   --------------------------          m += 1/k
            |--->|       |
            0    n       end                    M = round(m)
                edi                             M >= 512 ? exit : loop
    */ comment ~



;// version 1 drop bins

        ;// we need 1/k

            fld1            ;// 1   K
            fdivr           ;// 1/K
            fldz            ;// M   1/K

            xor ecx, ecx    ;// start scanning at m=0

            .REPEAT

                fadd st, st(1)          ;// M += 1/K

                mov eax, [ebx+ecx*8]    ;// get the real part
                mov edx, [ebx+ecx*8+4]  ;// get the imaginary part

                fist st_iter            ;// store M as integer m  (round closest)

                mov [edi], eax          ;// store the real part
                mov [edi+4], edx        ;// store the imaginary part

                mov ecx, st_iter        ;// load in ecx

                add edi, 8              ;// n += 1

            .UNTIL ecx >= 512           ;// loop if not done

        ;// done, clean out two fpu's, clean up the stack, exit

            fstp st
            add esp, 4
            fstp st
            jmp all_done



;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
ALIGN 16
fftop_cull::

    ASSUME edi:PTR DWORD    ;// edi points at dest data
    ASSUME ebx:PTR APIN     ;// ebx points at X input source pin

    mov ebx, [ebx].pData
    ASSUME ebx:PTR DWORD    ;// ebx must be the source pointer

    or [esi].pin_y.dwStatus, PIN_CHANGING

    lea ecx, [ebx+(SAMARY_LENGTH-4)*4]  ;// ecx is when to stop
                                        ;// skip the last two points

    xor eax, eax    ;// eax is for testing
    push esi    ;// esi will xfer non nulled points
    xor edx, edx    ;// edx is for zeroing
    push ebp    ;// ebp will xfer non nulled points

;// for all points
;// if the middle point is below either of its neighbors
;// then zero the point
;// otherwise, copy the point from the source
;// have to keep the previous two points in the fpu
;// skip the first point


        fld [ebx]           ;// a
        fmul st, st
        fld [ebx+4]
        fmul st, st
        stosd       ;// zero the first point
        fadd

        fld [ebx+8]         ;// b   a
        fmul st, st
        fld [ebx+0Ch]
        fmul st, st
        stosd       ;// zero the first point
        fadd
        jmp G2

    ;// iterate

G1:     add edi, 8      ;// top of loop
G2:     add ebx, 8      ;// enter loop

    ;// get a new point

        fld [ebx+8]         ;// c   b   a
        fmul st, st
        fld [ebx+0Ch]
        fmul st, st
        fadd

    ;// put in order and compare with prev point, dumping prev in the process

        fxch st(2)          ;// a   b   c
        fucomp              ;// b   c       ;// done with a
        fnstsw ax
        sahf
        jb G4   ;// jump if a is less than b

    ;// a was greater than b, so we zero the current point

        fxch                ;// c   b

G3: ;// zero the current point

        mov [edi], edx      ;// zero
        cmp ebx, ecx        ;// done yet ?
        mov [edi+4], edx    ;// zero
        jbe G1

        jmp G5          ;// done

    ;// a was less than b
G4: ;// see if b is less than c

        fucom           ;// b   c
        fnstsw ax
        fxch            ;// c   b
        sahf
        jbe G3  ;// have to zero

    ;// else, have to xfer

        mov esi, [ebx]
        mov ebp, [ebx+4]
        mov [edi], esi
        cmp ebx, ecx    ;// done yet ??
        mov [edi+4], ebp
        jb G1           ;// jump if not done

G5: ;// clear out the fpu

        fstp st         ;// dump the fpu
        xor eax, eax
        fstp st

    ;// zero the last two points

        stosd
        stosd
;//     stosd
;//     stosd

    ;// retrieve registers and split

        pop ebp
        pop esi

        jmp all_done






;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
ALIGN 16
fftop_mag2::

    ASSUME edi:PTR DWORD    ;// edi points at dest data
    ASSUME ebx:PTR APIN     ;// ebx points at X input source pin

;// Y[n] = a^2 + b^2
;// we'll do four at a time

    xor ecx, ecx
    xor eax, eax

    test [ebx].dwStatus, PIN_CHANGING
    mov ebx, [ebx].pData

    ASSUME ebx:PTR DWORD

    .IF !ZERO?

        or [esi].pin_y.dwStatus, PIN_CHANGING
        .REPEAT

            fld [ebx+ecx*4]     ;// r1
            fmul st, st
            fld [ebx+ecx*4+04h] ;// i1  r1
            fmul st, st

            fld [ebx+ecx*4+08h] ;// r2  i1  r1
            fmul st, st
            fld [ebx+ecx*4+0Ch] ;// i2  r2  i1  r1
            fmul st, st

            fld [ebx+ecx*4+10h] ;// r3  i2  r2  i1  r1
            fmul st, st
            fld [ebx+ecx*4+14h] ;// i3  r3  i2  r2  i1  r1
            fmul st, st

            fld [ebx+ecx*4+18h] ;// r4  i3  r3  i2  r2  i1  r1
            fmul st, st
            fld [ebx+ecx*4+1Ch] ;// i4  r4  i3  r3  i2  r2  i1  r1
            fmul st, st

            fxch st(7)          ;// r1  r4  i3  r3  i2  r2  i1  i4
            faddp st(6), st     ;// r4  i3  r3  i2  r2  y1  i4

            fxch st(4)          ;// r2  i3  r3  i2  r4  y1  i4
            faddp st(3), st     ;// i3  r3  y2  r4  y1  i4

            fadd                ;// y3  y2  r4  y1  i4
            fxch st(4)          ;// i4  y2  r4  y1  y3
            faddp st(2), st     ;// y2  y4  y1  y3

            fxch st(2)          ;// y1  y4  y2  y3

            fstp [edi+ecx*4]    ;// y4  y2  y3
            mov  [edi+ecx*4+04h], eax
            fxch                ;// y2  y4  y3

            fstp [edi+ecx*4+08h];// y4  y3
            mov  [edi+ecx*4+0Ch], eax
            fxch                ;// y3  y4

            fstp [edi+ecx*4+10h];// y4
            mov  [edi+ecx*4+14h], eax

            fstp [edi+ecx*4+18h];//
            mov  [edi+ecx*4+1Ch], eax

            add ecx, 8

        .UNTIL ecx >= SAMARY_LENGTH
        jmp all_done

    .ENDIF

    ;// not changing
    fld [ebx]
    fmul st, st
    fld [ebx+4]
    fmul st, st
    fadd

fftop_store_static_real:

    ;// fpu must have the results to store

    push edx
    fstp DWORD PTR [esp]
    test [esi].pin_y.dwStatus, PIN_CHANGING

    pop eax

    jnz FFT_1
    cmp eax, [edi]
    je all_done

FFT_1:

    and [esi].pin_y.dwStatus, NOT PIN_CHANGING
    xor ecx, ecx
    xor edx, edx
    .REPEAT
        mov [edi+ecx*4], eax
        mov [edi+ecx*4+04h], edx
        mov [edi+ecx*4+08h], eax
        mov [edi+ecx*4+0Ch], edx
        mov [edi+ecx*4+10h], eax
        mov [edi+ecx*4+14h], edx
        mov [edi+ecx*4+18h], eax
        mov [edi+ecx*4+1Ch], edx
        add ecx, 8

    .UNTIL ecx >= SAMARY_LENGTH

    ;// that's it

    jmp all_done

;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
ALIGN 16
fftop_conj::

    ASSUME edi:PTR DWORD    ;// edi points at dest data
    ASSUME ebx:PTR APIN     ;// ebx points at X input source pin

    ;// ABOX232 added null input test

        xor eax, eax    ;// in case we have to abort
        CMPJMP ebx, math_pNullPin, je store_static_y
        test [ebx].dwStatus, PIN_CHANGING

        mov ebx, [ebx].pData
        ASSUME ebx:PTR DWORD
        jnz C1
        CMPJMP eax, [ebx], je store_static_y

    C1: or [esi].pin_y.dwStatus, PIN_CHANGING

    ;// copy the existing data in one shot

        push esi
        mov ecx, SAMARY_LENGTH
        mov esi, ebx
        rep movsd
        pop esi

    ;// negate every second value, well do four at a time

        lea edi, [esi].data_y
        ;// ecx is already zero

        mov eax, 80000000h
        mov edx, 80000000h

        .REPEAT

            xor [edi+ecx*4+ 4], eax
            xor [edi+ecx*4+12], edx
            xor [edi+ecx*4+20], eax
            xor [edi+ecx*4+28], edx

            add ecx, 8

        .UNTIL ecx >= SAMARY_LENGTH - 4

    ;// that's it

        jmp all_done

;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
ALIGN 16
fftop_sort::

    ASSUME edi:PTR DWORD    ;// edi points at dest data
    ASSUME ebx:PTR APIN     ;// ebx points at X input source pin

    ;// 1) convert data to index, mag2 pairs
    ;// 2) buble sort (yuk!)

; AJT: hmmm, we have red black trees at our disposal ...
; at what n value is the performance crossover?

        or [esi].pin_y.dwStatus, PIN_CHANGING

    ;// convert to index, mag2

        fld math_1_512
        mov ebx, [ebx].pData    ;// ebx points at input spectrum
        xor ecx, ecx
        fld st
        fchs            ;// n   dn  ;// start at 1-, then add first

        ASSUME ebx:PTR DWORD

        .REPEAT

        ;// compute mag2

            fld [ebx+ecx*4]     ;// r   n   dn
            fmul st, st         ;// r2  n   dn
            fld [ebx+ecx*4+4]   ;// i   r2  n   dn
            fmul st, st         ;// i2  r2  n   dn

        ;// update index and finish mag 2

            fld st(3)           ;// dn  i2  r2  n   dn
            faddp st(3), st     ;// i2  r2  n   dn      ; next n

            fadd                ;// M2  n   dn

        ;// store as index mag and iterate

            fxch
            fst [edi+ecx*4]     ;// store the index
            inc ecx
            fxch
            fstp [edi+ecx*4]    ;// store the magnitude
            inc ecx

        .UNTIL ecx >= SAMARY_LENGTH

        fstp st
        xor ebx, ebx
        fstp st

    ;// 2 bubble sort

    ;// all we want to do is find the highest n values
    ;// if n is zero, use 1

    ;// 2a) determine how many values to sort

        OR_GET_PIN [esi].pin_n.pPin, ebx
        push ecx    ;// make room on the stack
        .IF ZERO?
            mov ebx, math_pNullPin
        .ENDIF

        fld math_512
        mov ebx, [ebx].pData
        ASSUME ebx:PTR DWORD

        fld [ebx]
        fmul
        fabs
        fistp DWORD PTR [esp]
        pop ebx
        .IF !ebx
            inc ebx
        .ELSEIF ebx >= 512
            mov ebx, 511
        .ENDIF

        lea ebx, [esi].data_y[ebx*8]    ;// when to stop

        ;// now ebx is the number of values to sort

    ;// 2b) sort them
    comment ~ /*


        picture

            start_value         stop_value = start_value[n*8]
            [esi].data_x        |  ebx
            |                   |                          last value = start_value[1022*4]
            |------>|           |                          |
            ------------------------------|----------------|
                    |     |<-------------------------------|
                    |     scan_value      |
                    |     [ecx]           |
                    |                     max_value
                    curr_value [edi]      [edx]

        iterate curr_value from start to stop

            f load curr value
            set max_value as curr_value

            iterate scan_value from last_value to curr_value - 1

                *scan > *curr ?

                    f swap
                    set max_value as scan_value

            max_value != curr_value ?

                swap max with cur (4 values)

        zero data from curr_value+1 to last_value


    */ comment ~

        xor eax, eax            ;// eax used for flag testing
        lea edi, [esi].data_y   ;// edi scans cur value

        ASSUME edi:PTR DWORD
        ASSUME ecx:PTR DWORD
        ASSUME edx:PTR DWORD

        .REPEAT     ;// iterate curr_value from start to stop

            fld [edi+4]     ;// f load curr value
            mov edx, edi    ;// set max_value as curr_value

            ;// iterate scan_value from last_value to curr_value - 1

            lea ecx, [esi].data_y[1022*4]
            xor eax, eax

            B1: fld [ecx+4]     ;// x[n]    max
                fucom           ;// compare
                fnstsw ax
                sahf
                jbe B2          ;// bigger ?
                fxch            ;// swap
                mov edx, ecx    ;// save index in max value
            B2: sub ecx, 8      ;// scan backwards
                fstp st         ;// dump the smaller value
                cmp edi, ecx
                jb B1

            ;// max_value != curr_value ?
            .IF edi != edx

                ;// swap max with cur (4 values)

                xor eax, eax
                mov ecx, [edi]      ;// get the current index
                mov eax, [edi+4]    ;// get the current mag

                xchg ecx, [edx]     ;// swap current index with new max index
                mov [edx+4], eax    ;// save current mag in old max mag (new max is in fpu)

                mov [edi], ecx  ;// store the new max index

            .ENDIF

            fstp [edi+4]    ;// store the new max mag, and clean out the fpu

            add edi, 8  ;// next slot

        .UNTIL edi >= ebx

    ;// zero data from stop_value to last_value

        lea ecx, [esi].data_y[1024*4]
        sub ecx, edi
        jz all_done

        xor eax, eax
        shr ecx, 2
        rep stosd

    ;// that's it

    jmp all_done

;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
ALIGN 16
fftop_replace::

    ASSUME edi:PTR DWORD    ;// edi points at dest data
    ASSUME ebx:PTR APIN     ;// ebx points at X input source pin


        or [esi].pin_y.dwStatus, PIN_CHANGING

    ;// copy the data

        push esi
        mov ecx, SAMARY_LENGTH
        mov esi, [ebx].pData
        rep movsd
        pop esi
        ;// ecx will be zero

        mov edx, [esi].pin_r.pPin
        mov ebx, [esi].pin_i.pPin
        ASSUME edx:PTR APIN

        .IF !edx
            mov edx, math_pNullPin
        .ENDIF
        .IF !ebx
            mov ebx, math_pNullPin
        .ENDIF

        mov edx, [edx].pData
        mov ebx, [ebx].pData

        OR_GET_PIN [esi].pin_n.pPin, ecx

        fld math_511

        .IF ZERO?
            mov ecx, math_pNullPin
        .ENDIF


        .IF [ecx].dwStatus & PIN_CHANGING

        ;// index (ecx) has changing data

            lea edi, [esi].data_y
            push ebp                ;// must preserve
            push esi                ;// need esi for index
            mov ebp, [ecx].pData    ;// point at input data
            push eax        ;// make some room on the stack

            xor ecx, ecx    ;// ecx will index and count

            ;// state

            ASSUME ebp:PTR DWORD    ;// ebp points at index data
            ASSUME edx:PTR DWORD    ;// edx points at real data
            ASSUME ebx:PTR DWORD    ;// ebx points at imag data

            R1: fld [ebp+ecx*4]         ;// load the normalized index
                fmul st, st(1)          ;// scale to 512
                add ecx, 2      ;// every second point
                fabs                    ;// always do abs
                fistp DWORD PTR [esp]   ;// store as integer

                mov esi, DWORD PTR [esp];// load the index
                .IF esi >= 512          ;// make sure less than 512
                    mov esi, 511
                .ENDIF

                mov eax, [edx+esi*8]    ;// get the real value
                mov [edi+esi*8], eax

                cmp ecx, SAMARY_LENGTH

                mov eax, [ebx+esi*8+4]  ;// get the imaginary value
                mov [edi+esi*8+4], eax

                jb R1

            add esp, 4  ;// clean up the stack
            fstp st     ;// clean out the fpu
            pop esi     ;// retrieve esi
            pop ebp     ;// retrieve ebp

            jmp all_done

        .ENDIF

    ;// index (ecx) does not have changing data
    ;// r and i might, but we don't care

        push eax                ;// make some room on the stack
        mov ecx, [ecx].pData    ;// point at index data
        fld DWORD PTR [ecx]     ;// get the first index
        fmul                    ;// scale to 512
        fabs                    ;// must be positive
        fistp DWORD PTR [esp]   ;// store as integer
        pop ecx
        .IF ecx >= 512
            mov ecx, 511
        .ENDIF

    ;// point at the values to get and get the values

        lea edi, [esi+ecx*8].data_y     ;// point at spot to store
        mov eax, DWORD PTR [edx+ecx*8]  ;// get the real value from pin_r
        mov edx, DWORD PTR [ebx+ecx*8+4];// get the imag value from pin_i

    ;// xfer to where they belong

        stosd
        mov [edi], edx

    ;// that's it

        jmp all_done

;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
ALIGN 16
fftop_inject::

    ASSUME edi:PTR DWORD    ;// edi points at dest data
    ASSUME ebx:PTR APIN     ;// ebx points at X input source pin

        or [esi].pin_y.dwStatus, PIN_CHANGING

    ;// copy the input spectrum data

        push esi
        mov ecx, SAMARY_LENGTH
        mov esi, [ebx].pData
        rep movsd
        pop esi
        ;// ecx will be zero

        mov edx, [esi].pin_r.pPin   ;// r input source
        mov ebx, [esi].pin_i.pPin   ;// i input source
        ASSUME edx:PTR APIN

        .IF !edx
            mov edx, math_pNullPin
        .ENDIF
        .IF !ebx
            mov ebx, math_pNullPin
        .ENDIF

        mov edx, [edx].pData    ;// r_input source
        mov ebx, [ebx].pData    ;// i_input source

        OR_GET_PIN [esi].pin_n.pPin, ecx    ;// check for input spectrum

        fld math_511            ;// load the index scalar

        .IF ZERO?
            mov ecx, math_pNullPin
        .ENDIF

        .IF [ecx].dwStatus & PIN_CHANGING

        ;// index has changing data

            lea edi, [esi].data_y   ;// point at output data
            push ebp                ;// gots to store
            push esi                ;// need esi for index
            mov ebp, [ecx].pData    ;// ebp will point at index data

            xor ecx, ecx            ;// ecx counts
            push eax                ;// make some room on the stack

            ;// state

            ASSUME ebp:PTR DWORD    ;// ebp points at index data
            ASSUME edx:PTR DWORD    ;// edx points at real data
            ASSUME ebx:PTR DWORD    ;// ebx points at imag data

            I1: fld [ebp+ecx*4]         ;// load the normalized index
                fmul st, st(1)          ;// scale to 512

                add ecx, 2  ;// every second point

                fabs                    ;// always do abs
                fistp DWORD PTR [esp]   ;// store as integer

                mov esi, DWORD PTR [esp];// esi is now the sample index the index
                .IF esi >= 512          ;// make sure less than 512
                    mov esi, 511
                .ENDIF

                fld [edx+esi*8]     ;// load the real value
                fadd [edi+esi*8]    ;// add what's already there

                fld [ebx+esi*8+4]   ;// load the imaginary value
                fadd [edi+esi*8+4]  ;// add what's already there

                fxch
                cmp ecx, SAMARY_LENGTH

                fstp [edi+esi*8]
                fstp [edi+esi*8+4]

                jb I1

            add esp, 4
            fstp st
            pop esi
            pop ebp

            jmp all_done

        .ENDIF

    ;// pin_n (ecx) is NOT changing
    ;// r and i might be changing, but we don't care

        push eax                ;// make some room on the stack
        mov ecx, [ecx].pData    ;// point at index data
        fld DWORD PTR [ecx]     ;// load the first value
        fmul                    ;// scale to 512
        fabs                    ;// must be positive
        fistp DWORD PTR [esp]   ;// store index on stack
        pop ecx                 ;// retireve it
        .IF ecx >= 512          ;// must be < 512
            mov ecx, 511
        .ENDIF

    ;// point at the values to get, get the values, and accumulate them

        lea edi, [esi+ecx*8].data_y ;// point at desired output slot

        fld DWORD PTR [edx+ecx*8]   ;// load the r value
        fadd [edi]                  ;// add to input data

        fld DWORD PTR [ebx+ecx*8+4] ;// load the i value
        fadd [edi+4]                ;// add to input data

        fxch

        fstp [edi]      ;// store new real value
        fstp [edi+4]    ;// store new imag value

    ;// that's it

        jmp all_done


;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
ALIGN 16
fftop_mul::

    ;// ( a + bi ) * ( c + di ) = ( a*c-b*d ) , i ( a*d + c*b )

;// ABOX232: added detect zero

    ASSUME edi:PTR DWORD    ;// edi points at dest data
    ASSUME ebx:PTR APIN     ;// ebx points at X input source pin

    xor eax, eax            ;// just in case we are zero and have to store

    ;// check if ebx is zero data

    CMPJMP ebx, math_pNullPin, je store_static_y    ;// exit now if x pin is zero
    test [ebx].dwStatus, PIN_CHANGING   ;// check if changing
    mov ebx, [ebx].pData                ;// ebx is now x input data
    ASSUME ebx:PTR DWORD
    jnz M1                              ;// have to continue if changing input
    CMPJMP eax, [ebx], jz store_static_y;// abort if not changing and zero
M1:
    ;// check if pin_n is zero data, eax is still zero

    mov edx, [esi].pin_n.pPin           ;// get the y pin
    ASSUME edx:PTR APIN                 ;// edx points at X input source pin
    TESTJMP edx, edx, jz store_static_y ;// abort now if zero
    test [edx].dwStatus, PIN_CHANGING   ;// check if changing
    mov edx, [edx].pData                ;// ebx is now x input data
    ASSUME edx:PTR DWORD
    jnz M2                              ;// have to continue if changing input
    CMPJMP eax, [edx], jz store_static_y;// abort if not changing and zero
M2:
    xor ecx, ecx
    or [esi].pin_y.dwStatus, PIN_CHANGING


    ;// ( a + bi ) * ( c + di )
    ;// a*c - b*d   ,   a*d + b*c

    .REPEAT

        fld [ebx+ecx*4]
        fld [ebx+ecx*4+4]
        fld [edx+ecx*4]
        fld [edx+ecx*4+4]   ;// d   c   b   a

        fld st(3)           ;// a   d   c   b   a
        fmul st, st(1)      ;// ad  d   c   b   a
        fxch st(4)          ;// a   d   c   b   ad
        fmul st, st(2)      ;// ac  d   c   b   ad
        fxch st(3)          ;// b   d   c   ac  ad
        fmul st(1), st      ;// b   bd  c   ac  ad
        fmulp st(2), st     ;// bd  bc  ac  ad

        fsubp st(2), st     ;// bc  R   ad
        faddp st(2), st     ;// R   I

        fstp [edi+ecx*4]
        fstp [edi+ecx*4+4]

        add ecx, 2

    .UNTIL ecx >= SAMARY_LENGTH

    ;// that's it

    jmp all_done

;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
ALIGN 16
fftop_div::


    ASSUME edi:PTR DWORD    ;// edi points at dest data
    ASSUME ebx:PTR APIN     ;// ebx points at X input source pin

    ;// a + bi     a*c + b*d   b*c - a*d
    ;// ------  =  --------- , ---------
    ;// c + di     c*c + d*d   c*c + d*d

;//ABOX232: added zero numerator test
    xor eax, eax    ;// in case we have to store static
    CMPJMP ebx, math_pNullPin, je store_static_y    ;// abort now if zero numerator
    test [ebx].dwStatus, PIN_CHANGING       ;// see if input is changing
    mov ebx, [ebx].pData                    ;// load the input data pointer
    ASSUME ebx:PTR DWORD                    ;// ebx = input data
    jnz D1                                  ;// if changing then have to do full calc
    CMPJMP eax, [ebx], je store_static_y    ;// not changing, abort if zero
D1:

    ;// somehow we need a bias for this

    mov edx, [esi].pin_n.pPin
    .IF !edx
        mov edx, math_pNullPin
    .ENDIF
    xor ecx, ecx
    mov edx, (APIN PTR [edx]).pData
    ASSUME edx:PTR DWORD

    or [esi].pin_y.dwStatus, PIN_CHANGING


    .REPEAT

        fld [edx+ecx*4]
        fmul st, st
        fld [edx+ecx*4+4]
        fmul st, st         ;// d2  c2

        fld [ebx+ecx*4]
        fld [ebx+ecx*4+4]
        fld [edx+ecx*4]
        fld [edx+ecx*4+4]   ;// d   c   b   a   d2  c2

        fld st(3)           ;// a   d   c   b   a   d2  c2
        fmul st, st(1)      ;// ad  d   c   b   a   d2  c2
        fxch st(4)          ;// a   d   c   b   ad  d2  c2
        fmul st, st(2)      ;// ac  d   c   b   ad  d2  c2
        fxch st(3)          ;// b   d   c   ac  ad  d2  c2
        fmul st(1), st      ;// b   bd  c   ac  ad  d2  c2
        fmulp st(2), st     ;// bd  bc  ac  ad  d2  c2

        faddp st(2), st     ;// bc  R   ad  d2  c2
        fsubrp st(2), st    ;// R   I   d2  c2

        fld math_1_256      ;// e   R   I   d2  c2
        faddp st(3), st     ;// R   I   ed2 c2
        fxch st(3)          ;// c2  I   ed2 R
        faddp st(2), st     ;// I   CD  R

        fld1                ;// 1   I   CD  R
        fdivrp st(2), st    ;// I   1/  R

        fmul st, st(1)      ;// i   1/  R
        fxch st(2)          ;// R   1/  i
        fmul                ;// r   i

        fstp [edi+ecx*4]
        fstp [edi+ecx*4+4]

        add ecx, 2

    .UNTIL ecx >= SAMARY_LENGTH

    ;// that's it

    jmp all_done

;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
ALIGN 16
fftop_power::

    ASSUME edi:PTR DWORD    ;// edi points at dest data
    ASSUME ebx:PTR APIN     ;// ebx points at X input source pin

    xor edx, edx
    OR_GET_PIN [esi].pin_n.pPin, edx    ;// edx is n source pin
    .IF ZERO?
        mov edx, math_pNullPin
    .ENDIF

    fld math_512
    mov ebx, [ebx].pData
    ASSUME ebx:PTR DWORD

    .IF [edx].dwStatus & PIN_CHANGING

        ;// n is changing

            push edx    ;// make some room on the stack

            mov edx, [edx].pData    ;// point at index data
            or [esi].pin_y.dwStatus, PIN_CHANGING   ;// set pin changing
            xor ecx, ecx            ;// clear for counting

        .REPEAT

        ;// determine the index

            fld DWORD PTR [edx+ecx*4]
            fmul st, st(1)
            fabs
            fistp DWORD PTR [esp]
            mov eax, DWORD PTR [esp]
            .IF eax >= 512
                mov eax, 511
            .ENDIF

        ;// get the data
        ;// fill the data

            fld [ebx+eax*8]
            fmul st, st
            fld [ebx+eax*8+4]
            fmul st, st
            fadd

        ;// store and iterate

            fst DWORD PTR [edi+ecx*4]
            inc ecx
            fstp DWORD PTR [edi+ecx*4]
            inc ecx

        .UNTIL ecx >= SAMARY_LENGTH

        add esp, 4
        fstp st

        jmp all_done

    .ENDIF

    ;// n is not changing

    ;// determine the index

        mov edx, [edx].pData
        fld DWORD PTR [edx]
        fmul
        push edx
        fabs
        fistp DWORD PTR [esp]
        pop edx
        .IF edx >= 512
            mov edx, 511
        .ENDIF

    ;// get the data
    ;// fill the data

        fld [ebx+edx*8]
        fmul st, st
        fld [ebx+edx*8+4]
        fmul st, st
        push eax
        fadd
        fstp DWORD PTR [esp]
        pop eax

        jmp store_static_y


;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
ALIGN 16
fftop_real::

    ASSUME edi:PTR DWORD    ;// edi points at dest data
    ASSUME ebx:PTR APIN     ;// ebx points at X input source pin

    ;// determine the index
    ;// get the data
    ;// fill the data

        xor edx, edx
        xor ecx, ecx
        OR_GET_PIN [esi].pin_n.pPin, edx
        fld math_512
        push ecx    ;// make room on the stack
        .IF ZERO?
            mov edx, math_pNullPin
        .ENDIF

        mov ebx, [ebx].pData
        ASSUME ebx:PTR DWORD

        .IF [edx].dwStatus & PIN_CHANGING

            mov edx, [edx].pData
            or [esi].pin_y.dwStatus, PIN_CHANGING

            .REPEAT

            ;// dtermine the index

                fld DWORD PTR [edx+ecx*4]
                fmul st, st(1)
                fabs
                fistp DWORD PTR [esp]

                mov eax, DWORD PTR [esp]
                .IF eax >= 512
                    mov eax, 511
                .ENDIF

            ;// get the value

                mov eax, [ebx+eax*8]

            ;// store and iterate

                mov [edi+ecx*4], eax
                inc ecx
                mov [edi+ecx*4], eax
                inc ecx

            .UNTIL ecx >= SAMARY_LENGTH

            add esp, 4
            fstp st
            jmp all_done


        .ENDIF

        ;// n is not changing

        mov edx, [edx].pData
        fld DWORD PTR [edx]
        fmul
        fabs
        fistp DWORD PTR [esp]
        pop edx
        .IF edx >= 512
            mov edx, 511
        .ENDIF

        ASSUME ebx:PTR DWORD

        mov eax, [ebx+edx*8]
        jmp store_static_y


;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
ALIGN 16
fftop_imag::

    ASSUME edi:PTR DWORD    ;// edi points at dest data
    ASSUME ebx:PTR APIN     ;// ebx points at X input source pin

    ;// determine the index
    ;// get the data
    ;// fill the data

        xor edx, edx
        xor ecx, ecx
        OR_GET_PIN [esi].pin_n.pPin, edx
        fld math_512
        push ecx    ;// make room on the stack
        .IF ZERO?
            mov edx, math_pNullPin
        .ENDIF

        mov ebx, [ebx].pData
        ASSUME ebx:PTR DWORD

        .IF [edx].dwStatus & PIN_CHANGING

            mov edx, [edx].pData
            or [esi].pin_y.dwStatus, PIN_CHANGING

            .REPEAT

            ;// determine the index

                fld DWORD PTR [edx+ecx*4]
                fmul st, st(1)
                fabs
                fistp DWORD PTR [esp]

                mov eax, DWORD PTR [esp]
                .IF eax >= 512
                    mov eax, 511
                .ENDIF

            ;// get the value

                mov eax, [ebx+eax*8+4]

            ;// store and iterate

                mov [edi+ecx*4], eax
                inc ecx
                mov [edi+ecx*4], eax
                inc ecx

            .UNTIL ecx >= SAMARY_LENGTH

            add esp, 4
            fstp st
            jmp all_done


        .ENDIF

        ;// n is not changing

        mov edx, [edx].pData
        fld DWORD PTR [edx]
        fmul
        fabs
        fistp DWORD PTR [esp]
        pop edx
        .IF edx >= 512
            mov edx, 511
        .ENDIF
        ASSUME ebx:PTR DWORD
        mov eax, [ebx+edx*8+4]

        jmp store_static_y



ALIGN 16
store_static_y:

    ;// eax has value to store
    ;// edi points at y output data data
    ;// esi points at object

        BITR [esi].pin_y.dwStatus, PIN_CHANGING ;// turn off changing and test previous
        mov ecx, SAMARY_LENGTH                  ;// load length to store
        jc have_to_fill_y                       ;// fill if previous changing
        cmp eax, [edi]                          ;// not previous changing, same value ?
        je all_done                             ;// if so, we can exit now

    have_to_fill_y:

        rep stosd

    ;// that's it

        jmp all_done


;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
ALIGN 16
all_done:

    ret


fftop_Calc  ENDP



ASSUME_AND_ALIGN
fftop_InitMenu  PROC

    ASSUME esi:PTR OSC_OBJECT

    mov eax, [esi].dwUser
    add eax, IDC_FFTOP_BASE
    invoke CheckDlgButton, popup_hWnd, eax, BST_PUSHED

    xor eax, eax

    ret

fftop_InitMenu  ENDP



ASSUME_AND_ALIGN
fftop_Command   PROC

    ASSUME esi:PTR OSC_OBJECT
    ASSUME ebp:PTR LIST_CONTEXT

    cmp eax, IDC_FFTOP_BASE
    jb osc_Command
    cmp eax, IDC_FFTOP_LAST
    ja osc_Command

    sub eax, IDC_FFTOP_BASE
    mov [esi].dwUser, eax

    GDI_INVALIDATE_OSC HINTI_OSC_SHAPE_CHANGED

    mov eax, POPUP_SET_DIRTY + POPUP_REDRAW_OBJECT

    ret

fftop_Command   ENDP




;////////////////////////////////////////////////////////////////////
;//
;//
;//     _LoadUndo
;//

ASSUME_AND_ALIGN
fftop_LoadUndo PROC

        ASSUME esi:PTR OSC_OBJECT   ;// preserve
        ASSUME ebp:PTR LIST_CONTEXT ;// preserve

    ;// edx enters as either UNREDO_CONTROL_OSC or UNREDO_COMMAND
    ;// edi enters as where to load
    ;//
    ;// task:   1) load nessary data
    ;//         2) do what it takes to initialize it
    ;//
    ;// may use all registers except ebp and esi
    ;// return will invalidate HINTI_OSC_UPDATE

        mov eax, [edi]
        mov [esi].dwUser, eax

        invoke fftop_SyncPins

        ret

fftop_LoadUndo ENDP

;//
;//
;//     _LoadUndo
;//
;////////////////////////////////////////////////////////////////////



ASSUME_AND_ALIGN
fftop_SetShape  PROC

    ASSUME esi:PTR OSC_OBJECT

    invoke fftop_SyncPins

    jmp osc_SetShape


fftop_SetShape  ENDP


ASSUME_AND_ALIGN


ENDIF   ;// USE_THIS_FILE
END
