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
;// ABox_Delay.asm
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

osc_Delay OSC_CORE { ,,,delay_Calc }
          OSC_GUI  { ,,,,,delay_Command,delay_InitMenu,,,osc_SaveUndo,delay_LoadUndo,delay_GetUnit}
          OSC_HARD { }

    OSC_DATA_LAYOUT { NEXT_Delay,IDB_DELAY,OFFSET popup_DELAY,,6,4,
        SIZEOF OSC_OBJECT + ( SIZEOF APIN ) * 6,
        SIZEOF OSC_OBJECT + ( SIZEOF APIN ) * 6 + SAMARY_SIZE * 3,
        SIZEOF OSC_OBJECT + ( SIZEOF APIN ) * 6 + SAMARY_SIZE * 3 }

    OSC_DISPLAY_LAYOUT { filter_container, DELAY_PSOURCE, ICON_LAYOUT( 4,3,3,2 ) }

        EXTERNDEF delay_apin_init_r:APIN_init

                    APIN_init { -1.0,            ,'X',, UNIT_AUTO_UNIT }  ;// input 1
                    APIN_init {  0.6,sz_Delay    ,'D',, UNIT_SAMPLES }  ;// delay time
delay_apin_init_r   APIN_init {  0.4,sz_Resonance,'R',, UNIT_PERCENT }  ;// recycle

        APIN_init {,,,,PIN_HIDDEN OR PIN_OUTPUT}    ;// buffer 1
        APIN_init {,,,,PIN_HIDDEN OR PIN_OUTPUT}    ;// buffer 2

        APIN_init {  0.0,        ,'=',, PIN_OUTPUT OR UNIT_AUTO_UNIT }  ;// output pin

        short_name  db  'Delay',0
        description db  'Can delay a signal up to 1024 samples.',0
        ALIGN 4

    ;// flags for dwUser

        DELAY_INTERP_ALWAYS EQU 00000001h   ;// always interpolate

    ;// osc map for this object

    OSC_DELAY_MAP STRUCT

        OSC_OBJECT  {}
        pin_x   APIN {} ;// input
        pin_t   APIN {} ;// time
        pin_r   APIN {} ;// recycle
        pin_1   APIN {} ;// buffer 1
        pin_2   APIN {} ;// buffer 2
        pin_y   APIN {} ;// output

        data_1  dd SAMARY_LENGTH DUP (0)
        data_2  dd SAMARY_LENGTH DUP (0)
        data_y  dd SAMARY_LENGTH DUP (0)


    OSC_DELAY_MAP ENDS



.CODE




ASSUME_AND_ALIGN
delay_GetUnit PROC

        ASSUME esi:PTR OSC_DELAY_MAP    ;// must preserve
        ASSUME ebx:PTR APIN     ;// must preserve

        ;// must preserve edi and ebp

    ;// determine the pin we want to grab the unit from

        lea ecx, [esi].pin_x
        .IF ecx == ebx
            lea ecx, [esi].pin_y
        .ENDIF
        ASSUME ecx:PTR APIN

        mov eax, [ecx].dwStatus
        BITT eax, UNIT_AUTOED

        ret

delay_GetUnit ENDP


ASSUME_AND_ALIGN
delay_InitMenu PROC

    ASSUME esi:PTR OSC_DELAY_MAP

    invoke GetDlgItem, popup_hWnd, ID_DELAY_INTERP_ALWAYS

    .IF [esi].dwUser & DELAY_INTERP_ALWAYS
        invoke CheckDlgButton, popup_hWnd, ID_DELAY_INTERP_ALWAYS, 1
    .ENDIF

    xor eax, eax

    ret

delay_InitMenu ENDP

ASSUME_AND_ALIGN
delay_Command PROC

    ASSUME esi:PTR OSC_DELAY_MAP

    cmp eax, ID_DELAY_INTERP_ALWAYS
    jne osc_Command

    xor [esi].dwUser, DELAY_INTERP_ALWAYS
    mov eax, POPUP_SET_DIRTY

    ret

delay_Command ENDP




;////////////////////////////////////////////////////////////////////
;//
;//
;//     _LoadUndo
;//

ASSUME_AND_ALIGN
delay_LoadUndo PROC

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

        ret

delay_LoadUndo ENDP

;//
;//
;//     _LoadUndo
;//
;////////////////////////////////////////////////////////////////////



comment ~ /*


    the new delay calc

    now that we have a resonator pin and an interp always setting
    we get more states

            X   T   R

          /    dT      \ 3
          |    sTy dR  | 2  2 x 4 x 3 = 24 states
          | dX sTn sR  | 1
          \ sX nT  zR  / 0

            sTy is static T, always interpolate
            sTn is static T, don't always interpolate
            nT  is T not connected and defaults to 1.0

            the fpu will be preloaded according to the various values

    special cases

        nX  x_not_connected
        zT  t_static_zero

        if T is not connected, T is 1.0

    exit rules

        we need to define two pin_changing values
        one for Y the other for the previous X frame
        we'll sometimes need to scan the data produced to determine these values

        we also have to check for denormals when R is used

        these conditions create several exit rules

        A   set prev_x and Y by scanning the data
        A0  if prev_x || x[0] != y[0] then y changing, else y ! changing, then reset prev_x

        B   check for denormals

        D0  set both Y and prev_x = 0
        D1  set both Y and prev_x = 1

        E0  set Y based on prev X then set prev_x = 0
        E0  set Y based on prev X then set prev_x = 1


*/ comment ~

    X_JUMP  EQU 12  ;// for parsing the pin states, we use JUMP and MAX
    X_MAX   EQU 1   ;// JUMP defines how much to add or subtract to get to the next state in a column
                    ;// MAX defines the maximum to add to get to the top of the column
    T_JUMP  EQU 3   ;// the parsing routine then works the column from top to bottom
    T_MAX   EQU 3   ;// suntracting as it goes

    R_JUMP  EQU 1
    R_MAX   EQU 2

comment ~ /*


    we'll do this by useing 3 buffers in osc memory
    they're all contigous, so indexing is done by one register

    at the most, this will require two copies


    data_1      data_2      data_y
    |-----------|-----------|-----------|
    0h          400h        800h

                X           Y

    in all cases, we assume X is a copy of the input data

    so X[n-whatever] is previous data

    there are cases when Y data may be set in the data_1 frame


    nomemclature

        n = index of current sample
        m = n - round_up(T*scale)   = index of delayed sample
        m1= m+1

        t = scaled T index value
        f = fractional part of linear interpolater
        i = integer part of index


    formula:

        t = T[n] * scale    ;// scale T to offset
        i = round_up( t )   ;// integer part of index
        m = n - i           ;// index of delayed sample
        f = t - i           ;// fractional part for interpolate

    then:

        Y[n] =  ( X[m1]-X[m] ) * f + X[m]   ;// output value

        X[n] += Y[n] * R[n]                 ;// feedback term

*/ comment ~

    ;// code cleaning macros

    _Tn TEXTEQU <[edx+ecx*4]>       ;// retreives T[n]
    _Rn TEXTEQU <[edi+ecx*4]>       ;// retreives R[n]
    _Xn TEXTEQU <[esi+ecx*4].data_2>;// retreives X[n]
    _Yn TEXTEQU <[esi+ecx*4].data_y>;// retrieves Y

    _Xm MACRO reg:req               ;// retrieves X[m]
        EXITM <[esi+reg*4].data_2>
        ENDM

    _Xm1 MACRO reg:req              ;// retrieves X[m+1]
        EXITM <[esi+reg*4+4].data_2>
        ENDM



    ;// this is used to limit the delay range to -1024
    ;// st_int must have integer n-T value


    DELAY_TEST MACRO reg:req

        LOCAL J0

        cmp reg, -1024
        jge J0

        fstp st
        mov reg, -1024
        fldz

    J0:

        ENDM




.DATA

    ;//   /    dT      \ 3
    ;//   |    sTy dR  | 2  2 x 4 x 3 = 24 states
    ;//   | dX sTn sR  | 1
    ;//   \ sX nT  zR  / 0

    delay_calc_jump LABEL DWORD

    dd  delay_sX_nT_zR,     delay_sX_nT_sR,     delay_sX_nT_dR
    dd  delay_sX_sTn_zR,    delay_sX_sTn_sR,    delay_sX_sTn_dR
    dd  delay_sX_sTy_zR,    delay_sX_sTy_sR,    delay_sX_sTy_dR
    dd  delay_sX_dT_zR,     delay_sX_dT_sR,     delay_sX_dT_dR

    dd  delay_dX_nT_zR,     delay_dX_nT_sR,     delay_dX_nT_dR
    dd  delay_dX_sTn_zR,    delay_dX_sTn_sR,    delay_dX_sTn_dR
    dd  delay_dX_sTy_zR,    delay_dX_sTy_sR,    delay_dX_sTy_dR
    dd  delay_dX_dT_zR,     delay_dX_dT_sR,     delay_dX_dT_dR


.CODE


ASSUME_AND_ALIGN
delay_Calc PROC

        ASSUME esi:PTR OSC_DELAY_MAP

    ;// set default data pointer and prepare to build the jump index

        lea eax, [esi].data_y
        xor ebx, ebx
        mov [esi].pin_y.pData, eax

    ;// X input connected

        OR_GET_PIN [esi].pin_x.pPin, ebx    ;// load and see if pin is connected
        jz x_not_connected                  ;// dont waste time if not connected

    ;// make an aligned stack frame and set the fpu mode

        push ebp
        push esi
        mov ebp, esp
        sub esp, 4
        and esp, 0FFFFFFF8h

        fpu_SetRoundMode UP, HAVESTACK

        st_int TEXTEQU <(DWORD PTR [esp])>
        st_osc TEXTEQU <(DWORD PTR [ebp])>

    ;// continue on parsing the input pins

        xor edx, edx
        xor ecx, ecx

    ;// T input and load static scales

        OR_GET_PIN [esi].pin_t.pPin, edx    ;// load and see if pin is connected
        .IF ZERO?
            mov st_int, 1024        ;// use maximum delay
        .ELSE

            add ecx, T_JUMP * T_MAX ;// scoot to top of range
            test [edx].dwStatus,PIN_CHANGING    ;// is it changing ?
            fld math_1024           ;// scale
            mov edx, [edx].pData
            ASSUME edx:PTR DWORD

            .IF ZERO?       ;// T not changing

                sub ecx, T_JUMP

                test [edx], 7FFFFFFFh   ;// check for zero
                jz T_static_zero

                ;// T is not zero?

                fld [edx]           ;// T   scale
                fabs
                fmul                ;// t

                .IF [esi].dwUser & DELAY_INTERP_ALWAYS

                    fist st_int
                    fild st_int
                    fsubr           ;// f

                .ELSE               ;// no interp

                    fsub math_1_2   ;// must round nearest
                    sub ecx, T_JUMP
                    fistp st_int    ;// empty

                .ENDIF
            .ENDIF
        .ENDIF

        ;// st_int has the integer T rounded up
        ;// fpu may have f or scale or nothing
        ;//
        ;// mode    fpu     st_int  edx
        ;// dT      scale   empty   T data
        ;// sTy     f       n-T     dont care
        ;// sTn     empty   n-T     dont care
        ;// nT      empty   1024    dont care

    ;// X input and xfer data
    ;// prev x changing will be updated at the end of the function

    push ecx    ;// need to save

        test [ebx].dwStatus,PIN_CHANGING;// test x changing
        mov ebx, [ebx].pData            ;// load the data pointer
        ASSUME ebx:PTR DWORD
        lea edi, [esi].data_1
        ASSUME edi:PTR DWORD
        ;//             data_1  data_2
        ;// dX  dpX     copy    copy
        ;//     spX     fill    copy
        ;// sX  dpX     copy    fill
        ;//     spX     fill    fill
        .IF ZERO?                   ;// is it changing ?

            ;// sX

            .IF [esi].pin_x.dwUser & PIN_CHANGING   ;// prev changing

                ;// sX_dpX  ;// copy fill

                lea esi, [esi].data_2       ;// copy data_2 to data_1
                mov ecx, SAMARY_LENGTH
                rep movsd

                mov eax, [ebx]              ;// copy x to data_2
                mov ecx, SAMARY_LENGTH
                rep stosd

                mov esi, st_osc

            ;// we have to xfer changing status to data_1
            ;// and turn off changing in data_2

                or [esi].pin_1.dwUser, PIN_CHANGING  ;// ABox232--> have to keep track of data_1 changing

            .ELSE   ;// sX_spX  ;// fill fill

                ;//ABox 232: here is the problem:
                ;//we have to propegate dpx from data_2 to data_1
                ;//otherwise we may miss filling data_1 if there was data in the center

                test [esi].pin_1.dwUser, PIN_CHANGING
                mov eax, [esi].data_2
                .IF !ZERO? || eax != [edi]
                    mov ecx, SAMARY_LENGTH  ;// fill data_1 with data_2
                    rep stosd
                    and [esi].pin_1.dwUser, PIN_CHANGING    ;// ABox232--> have to keep track of data_1 changing
                .ENDIF

                lea edi, [esi].data_2   ;// fill data 2 with data x
                mov eax, [ebx]
                .IF eax != [edi]
                    mov ecx, SAMARY_LENGTH
                    rep stosd
                .ENDIF

            .ENDIF

        pop ecx

        .ELSE

            ;// dX

            .IF [esi].pin_x.dwUser & PIN_CHANGING

                ;// dX_dpX  ;// copy copy

                lea esi, [esi].data_2
                mov ecx, SAMARY_LENGTH
                rep movsd

                mov esi, ebx
                mov ecx, SAMARY_LENGTH
                rep movsd

                mov esi, st_osc

                or [esi].pin_1.dwUser, PIN_CHANGING ;// ABox232--> have to keep track of data_1 changing

            .ELSE

                ;// dX_spX fill copy

                mov eax, [esi].data_2   ;// fill data_1 with data_2
                mov ecx, SAMARY_LENGTH
                rep stosd

                mov esi, ebx            ;// copy x data to data_2
                mov ecx, SAMARY_LENGTH
                rep movsd

                mov esi, st_osc

                or [esi].pin_1.dwUser, PIN_CHANGING ;// ABox232--> have to keep track of data_1 changing

            .ENDIF

        pop ecx

            add ecx, X_JUMP

        .ENDIF

        xor edi, edi

    ;// R input

        GET_PIN [esi].pin_r.pPin, edi
        .IF edi
            add ecx, R_JUMP * R_MAX
            test [edi].dwStatus, PIN_CHANGING
            mov edi, [edi].pData
            ASSUME edi:PTR DWORD
            .IF ZERO?
                sub ecx, R_JUMP * 2
                .IF [edi] & 7FFFFFFFh
                    add ecx, R_JUMP
                    fld [edi]
                .ENDIF
            .ENDIF
        .ENDIF

        ;// mode    fpu     edi
        ;// dR      ...     R data
        ;// sR      R       dont care
        ;// zR      ...     dont care

    ;// now ecx has the jump address

    ;// ebx points at X source data
    ;// edx points at T source data
    ;// edi points at R source data
    ;// esi is osc

    jmp delay_calc_jump[ecx*4]



ALIGN 16
T_static_zero:

    ;// since T is zero, R doesn't matter
    ;// we can do the calc based solely on X's state

    ;// fpu still has scale loaded

    ;// T is static and zero

    ASSUME ebx:PTR APIN ;// still set from parser

    test [ebx].dwStatus, PIN_CHANGING
    mov ebx, [ebx].pData
    .IF !ZERO?
        or [esi].pin_y.dwStatus, PIN_CHANGING
    .ELSE
        and [esi].pin_y.dwStatus, NOT PIN_CHANGING
    .ENDIF
    mov [esi].pin_y.pData, ebx
    fstp st
    jmp cleanup_stack



ALIGN 16
x_not_connected:

    mov eax, math_pNull
    mov [esi].pin_y.pData, eax
    and [esi].pin_y.dwStatus, NOT PIN_CHANGING
    jmp all_done




ALIGN 16
delay_sX_nT_zR::
    ;//         fpu     st_int  edx
    ;// nT      empty   1024    dont care
    ;//         fpu     edi
    ;// zR      ...     dont care

    ;// set the data pointer to the previous frame

        lea eax, [esi].data_1
        mov [esi].pin_y.pData, eax

    ;// exit to appropriate rule

        jmp exit_rule_E0

ALIGN 16
delay_dX_nT_zR::

    ;// exit rule   E1


    ;//         fpu     st_int  edx
    ;// nT      empty   1024    dont care
    ;//         fpu     edi
    ;// zR      ...     dont care

    ;// set the data pointer to the previous frame

        lea eax, [esi].data_1
        mov [esi].pin_y.pData, eax

    ;// exit to appropriate rule

        jmp exit_rule_E1


ALIGN 16
delay_sX_nT_sR::

    ;//         fpu     st_int  edx
    ;// nT      empty   1024    dont care
    ;//         fpu     edi
    ;// sR      R       dont care

    lea eax, [esi].data_1
    mov [esi].pin_y.pData, eax

    fstp st_int

    ;// esi is always X
    ;// ebx is always A
    ;// edx is always B
    ;// edi is always Y

    ;//        eax    esp
    ;// X[n] = Y[n] * R[n] + X[n]
    ;//  edi   esi    ebx    edx

    lea edi, [esi].data_2
    mov ebx, esp
    mov esi, eax
    mov edx, edi

    invoke math_muladd_dXsAdB
    mov esi, st_osc

    call check_denormals

    jmp exit_rule_A


ALIGN 16
delay_sX_nT_dR::
    ;//         fpu     st_int  edx
    ;// nT      empty   1024    dont care
    ;//         fpu     edi
    ;// dR      ...     R data

    lea eax, [esi].data_1
    mov [esi].pin_y.pData, eax

    ;//        eax    edi
    ;// X[n] = Y[n] * R[n] + X[n]
    ;//  edi   esi    ebx    edx

    mov ebx, edi
    lea edi, [esi].data_2
    mov esi, eax
    mov edx, edi

    invoke math_muladd_dXdAdB
    mov esi, st_osc

    call check_denormals

    jmp exit_rule_A


ALIGN 16
delay_dX_nT_sR::
    ;//         fpu     st_int  edx
    ;// nT      empty   1024    dont care
    ;//         fpu     edi
    ;// sR      R       dont care

    lea eax, [esi].data_1
    mov [esi].pin_y.pData, eax

    fstp st_int

    ;//        eax    esp
    ;// X[n] = Y[n] * R[n] + X[n]
    ;//  edi   esi    ebx    edx

    lea edi, [esi].data_2
    mov ebx, esp
    mov esi, eax
    mov edx, edi

    invoke math_muladd_dXsAdB
    mov esi, st_osc

    call check_denormals

    jmp exit_rule_D1


ALIGN 16
delay_dX_nT_dR::
    ;//         fpu     st_int  edx
    ;// nT      empty   1024    dont care
    ;//         fpu     edi
    ;// dR      ...     R data

    lea eax, [esi].data_1
    mov [esi].pin_y.pData, eax

    ;//        eax    edi
    ;// X[n] = Y[n] * R[n] + X[n]
    ;//  edi   esi    ebx    edx

    mov ebx, edi
    lea edi, [esi].data_2
    mov esi, eax
    mov edx, edi

    invoke math_muladd_dXdAdB
    mov esi, st_osc

    call check_denormals

    jmp exit_rule_D1



ALIGN 16
delay_sX_sTn_zR::
    ;//         fpu     st_int  edx
    ;// sTn     empty   n-T     dont care
    ;//         fpu     edi
    ;// zR      ...     dont care

    ;// FPU empty

    xor eax, eax
    sub eax, st_int
    cmp eax, -1024
    jge @F
    mov eax, -1024
    @@:

    lea ebx, [esi].data_2[eax*4]
    mov [esi].pin_y.pData, ebx

    jmp exit_rule_A0



ALIGN 16
delay_dX_sTn_zR::
    ;//         fpu     st_int  edx
    ;// sTn     empty   n-T     dont care
    ;//         fpu     edi
    ;// zR      ...     dont care

    xor eax, eax
    sub eax, st_int
    cmp eax, -1024
    jge @F
    mov eax, -1024
    @@:
    lea eax, [esi].data_2[eax*4]
    mov [esi].pin_y.pData, eax

    jmp exit_rule_D1



ALIGN 16
delay_dX_sTn_sR::

    xor ebx, ebx
    sub ebx, st_int

    cmp ebx, -1024
    jge @F
    mov ebx, -1024
    @@:

    lea ebx, [esi].data_2[ebx*4]
    mov [esi].pin_y.pData, ebx

    call do_resonate_sR
    call check_denormals
    jmp exit_rule_D1

ALIGN 16
delay_sX_sTn_sR::
    ;//         fpu     st_int  edx
    ;// sTn     empty   n-T     dont care
    ;//         fpu     edi
    ;// sR      R       dont care

    xor ebx, ebx
    sub ebx, st_int

    cmp ebx, -1024
    jge @F
    mov ebx, -1024
    @@:

    lea ebx, [esi].data_2[ebx*4]
    mov [esi].pin_y.pData, ebx

    call do_resonate_sR
    call check_denormals
    jmp exit_rule_A




ALIGN 16
delay_dX_sTn_dR::
    ;//         fpu     st_int  edx
    ;// sTn     empty   n-T     dont care
    ;//         fpu     edi
    ;// dR      ...     R data

    xor ebx, ebx
    sub ebx, st_int

    cmp ebx, -1024
    jge @F
    mov ebx, -1024
    @@:

    lea ebx, [esi].data_2[ebx*4]
    mov [esi].pin_y.pData, ebx

    call do_resonate_dR
    call check_denormals
    jmp exit_rule_D1

ALIGN 16
delay_sX_sTn_dR::
    ;//         fpu     st_int  edx
    ;// sTn     empty   n-T     dont care
    ;//         fpu     edi
    ;// dR      ...     R data

    xor ebx, ebx
    sub ebx, st_int

    cmp ebx, -1024
    jge @F
    mov ebx, -1024
    @@:

    lea ebx, [esi].data_2[ebx*4]
    mov [esi].pin_y.pData, ebx

    call do_resonate_dR
    call check_denormals
    jmp exit_rule_A


ALIGN 16
delay_sX_sTy_zR::
    ;//         fpu     st_int  edx
    ;// sTy     f       n-T     dont care
    ;//         fpu     edi
    ;// zR      ...     dont care

    mov eax, [esi].data_1
    .IF ([esi].pin_x.dwUser & PIN_CHANGING) || (eax != [esi].data_2)

;//     fstp st             ;// abox227: what was the rational behind these lines
;//     fld math_1024       ;// they do NOT operate correctly
        jmp delay_dX_sTy_zR

    .ENDIF

    lea eax, [esi].data_1
    fstp st
    mov [esi].pin_y.pData, eax

    jmp exit_rule_A0


ALIGN 16
delay_sX_sTy_sR::
    ;//         fpu     st_int  edx
    ;// sTy     f       n-T     dont care
    ;//         fpu     edi
    ;// sR      R       dont care

    ;// fpu =   R       f

    ;// if x and prev_x are the same, we can kludge this

    mov eax, [esi].data_1
    .IF [esi].pin_x.dwUser & PIN_CHANGING   ||  \
        eax != [esi].data_2

        jmp delay_dX_sTy_sR

    .ENDIF

    xor ebx, ebx
    sub ebx, st_int
    cmp ebx, -1024
    jge @F
    mov ebx, -1024
    @@:
    lea ebx, [esi].data_2
    mov [esi].pin_y.pData, ebx
    fxch
    fstp st

    call do_resonate_sR
    call check_denormals

    jmp exit_rule_A


ALIGN 16
delay_sX_sTy_dR::
    ;//         fpu     st_int  edx
    ;// sTy     f       n-T     dont care
    ;//         fpu     edi
    ;// dR      ...     R data

    ;// FPU =   f

    ;// if x and prev_x are the same, we can kludge this

    mov eax, [esi].data_1
    .IF [esi].pin_x.dwUser & PIN_CHANGING   ||  \
        eax != [esi].data_2

        jmp delay_dX_sTy_dR

    .ENDIF

    xor ebx, ebx
    sub ebx, st_int
    cmp ebx, -1024
    jge @F
    mov ebx, -1024
    @@:
    lea ebx, [esi].data_2
    mov [esi].pin_y.pData, ebx
    fstp st

    call do_resonate_dR
    call check_denormals

    jmp exit_rule_A


ALIGN 16
delay_sX_dT_zR::
    ;//         fpu     st_int  edx
    ;// dT      scale   empty   T data
    ;//         fpu     edi
    ;// zR      ...     dont care

    test [esi].pin_x.dwUser, PIN_CHANGING
    jnz delay_dX_dT_zR

    mov eax, [esi].data_1
    cmp eax, [esi].data_2
    jne delay_dX_dT_zR

    lea eax, [esi].data_1
    mov [esi].pin_y.pData, eax

    fstp st

    jmp exit_rule_D0





ALIGN 16
delay_dX_sTy_zR::
    ;//         fpu     st_int  edx
    ;// sTy     f       n-T     dont care
    ;//         fpu     edi
    ;// zR      ...     dont care

    ;// FPU f

    xor ebx, ebx
    sub ebx, st_int
    DELAY_TEST ebx

    fld _Xm(ebx)

    xor ecx, ecx

    ;// formula:
    ;//
    ;// dX0 = X1 - X0
    ;// dX1 = X2 - X1       --> X2 becomes new X0
    ;//
    ;// fX0 = dX0 * f
    ;// fX1 = dX1 * f
    ;//
    ;// Y0 = fX0 + X0   --> destroy X0
    ;// Y1 = fX1 + X1   --> destroy X1

    .REPEAT             ;// X0      f

        fld _Xm(ebx)[4] ;// X1      X0      f
        fld st(1)       ;// X0      X1      X0      f
        fsubr st, st(1) ;// dX0     X1      X0      f

        fld _Xm(ebx)[8] ;// X2      dX0     X1      X0      f
        fld st(2)       ;// X1      X2      dX0     X1      X0      f
        fsubr st, st(1) ;// dX1     X2      dX0     X1      X0      f

        fld st(5)       ;// f       dX1     X2      dX0     X1      X0      f
        fmul st(3), st  ;// f       dX1     X2      fX0     X1      X0      f
        add ebx, 2
        fmul            ;// fX1     X2      fX0     X1      X0      f

        fxch            ;// X2      fX1     fX0     X1      X0      f
        fxch st(4)      ;// X0      fX1     fX0     X1      X2      f
        faddp st(2), st ;// fX1     Y0      X1      X2      f
        faddp st(2), st ;// Y0      Y1      X2      f

        fstp _Yn        ;// Y1      X2      f
        inc ecx
        fstp _Yn        ;// X2      f
        inc ecx

    .UNTIL ecx >= SAMARY_LENGTH

    fstp st
    fstp st

    GET_PIN [esi].pin_x.pPin, eax
    test [eax].dwStatus, PIN_CHANGING
    jz exit_rule_A

    jmp exit_rule_D1




ALIGN 16
delay_dX_sTy_sR::
    ;//         fpu     st_int  edx
    ;// sTy     f       n-T     dont care
    ;//         fpu     edi
    ;// sR      R       dont care

    ;// fpu     R       f

    xor ebx, ebx
    sub ebx, st_int
    cmp ebx, -1024
    jge @F
    mov ebx, -1024
    @@:

    ;// ebx is now m

    ;// Y[n] = (X[m1]-X[m])*f + X[m]
    ;// X[n] = Y[n]*R[n] + X[n]

    xor ecx, ecx
    .REPEAT

        fld _Xm1(ebx)   ;// Xm1     R       f
        fsub _Xm(ebx)   ;// dX      R       f
        fmul st, st(2)  ;// fX      R       f
        fld _Xm(ebx)    ;// Xm      fX      R       f
        fadd            ;// Yn      R       f

        fld _Xn         ;// Xn      Yn      R       f
        fxch            ;// Yn      Xn      R       f
        fst _Yn         ;// Yn      Xn      R       f

        fmul st, st(2)  ;// YRn     Xn      R       f
        inc ebx
        fadd            ;// Xn      R       F

        fstp _Xn        ;// R       F

        inc ecx

    .UNTIL ecx >= SAMARY_LENGTH

    fstp st
    fstp st

    call check_denormals

    GET_PIN [esi].pin_x.pPin, eax
    test [eax].dwStatus, PIN_CHANGING
    jz exit_rule_A

    jmp exit_rule_D1





ALIGN 16
delay_dX_sTy_dR::
    ;//         fpu     st_int  edx
    ;// sTy     f       n-T     dont care
    ;//         fpu     edi
    ;// dR      ...     R data

    ;// FPU f

    ;// fpu     R       f

    xor ebx, ebx
    sub ebx, st_int
    cmp ebx, -1024
    jge @F
    mov ebx, -1024
    @@:

    ;// ebx is now m

    ;// Y[n] = (X[m1]-X[m])*f + X[m]
    ;// X[n] = Y[n]*R[n] + X[n]

    xor ecx, ecx
    .REPEAT

        fld _Xm1(ebx)   ;// Xm1     f
        fsub _Xm(ebx)   ;// dX      f
        fmul st, st(1)  ;// fX      f
        fld _Xm(ebx)    ;// Xm      fX      f
        fadd            ;// Yn      f

        fld _Xn         ;// Xn      Yn      f
        fxch            ;// Yn      Xn      f
        fst _Yn         ;// Yn      Xn      f

        fmul _Rn        ;// YRn     Xn      f
        inc ebx
        fadd            ;// Xn      F

        fstp _Xn        ;// F

        inc ecx

    .UNTIL ecx >= SAMARY_LENGTH

    fstp st

    call check_denormals

    GET_PIN [esi].pin_x.pPin, eax
    test [eax].dwStatus, PIN_CHANGING
    jz exit_rule_A

    jmp exit_rule_D1


ALIGN 16
delay_dX_dT_zR::
    ;//         fpu     st_int  edx
    ;// dT      scale   empty   T data
    ;//         fpu     edi
    ;// zR      ...     dont care

    ;// FPU     scale

    xor ecx, ecx    ;// ecx is already zero

    .REPEAT

        fld _Tn         ;// T1      scale
        fabs            ;// T1      scale
        fmul st, st(1)  ;// t1      scale

        fld _Tn[4]      ;// T2      t1      scale
        fabs
        fmul st, st(2)  ;// t2      t1      scale
        fxch            ;// t1      t2      scale

        fist st_int     ;// t1      t2      scale
        mov eax, ecx
        fild st_int     ;// i1      t1      t2      scale
        fsubr           ;// f1      t2      scale

        sub eax, st_int
        DELAY_TEST eax

        fld   _Xm(eax)  ;// mX1     f1      t2      scale
        fsubr _Xm1(eax) ;// dX1     f1      t2      scale

        fld   _Xm(eax)  ;// mX1     dX1     f1      t2      scale
        mov ebx, ecx

        fxch st(3)      ;// t2      dX1     f1      mX1     scale

        fist st_int
        inc ebx
        fild st_int     ;// i2      t2      dX1     f1      mX1     scale
        fsubr           ;// f2      dX1     f1      mX1     scale

        sub ebx, st_int
        DELAY_TEST ebx

        fld _Xm(ebx)    ;// mX2     f2      dX1     f1      mX1     scale
        fsubr _Xm1(ebx) ;// dX2     f2      dX1     f1      mX1     scale

        fxch st(2)      ;// dX1     f2      dX2     f1      mX1     scale
        fmulp st(3), st ;// f2      dX2     fX1     mX1     scale

        fld _Xm(ebx)    ;// mX2     f2      dX2     fX1     mX1     scale
        fxch            ;// f2      mX2     dX2     fX1     mX1     scale
        fmulp st(2), st ;// mX2     fX2     fX1     mX1     scale

        fxch st(3)      ;// mX1     fX2     fX1     mX2     scale
        faddp st(2), st ;// fX2     Y1      mX2     scale
        faddp st(2), st ;// Y1      Y2      scale

        fstp _Yn
        inc ecx
        fstp _Yn
        inc ecx

    .UNTIL ecx >= SAMARY_LENGTH

    fstp st

    GET_PIN [esi].pin_x.pPin, eax
    test [eax].dwStatus, PIN_CHANGING
    jz exit_rule_A

    jmp exit_rule_D1





ALIGN 16
delay_dX_dT_sR::
delay_sX_dT_sR::

    ;//         fpu     st_int  edx
    ;// dT      scale   empty   T data

    ;//         fpu     edi
    ;// sR      R       dont care

    ;// FPU     R       scale

    xor ecx, ecx    ;// ecx is already zero

    .REPEAT

        fld _Tn         ;// T1      R       scale
        fabs            ;// T1      R       scale
        fmul st, st(2)  ;// t1      R       scale

        fld _Tn[4]      ;// T2      t1      R       scale
        fabs
        fmul st, st(3)  ;// t2      t1      R       scale
        fxch            ;// t1      t2      R       scale

        fist st_int     ;// t1      t2      R       scale
        mov eax, ecx
        fild st_int     ;// i1      t1      t2      R       scale
        fsubr           ;// f1      t2      R       scale

        sub eax, st_int
        DELAY_TEST eax

        fld   _Xm(eax)  ;// mX1     f1      t2      R       scale
        fsubr _Xm1(eax) ;// dX1     f1      t2      R       scale

        fld   _Xm(eax)  ;// mX1     dX1     f1      t2      R       scale

        mov ebx, ecx
        fxch st(3)      ;// t2      dX1     f1      mX1     R       scale

        fist st_int
        inc ebx

        fxch            ;// dX1     t2      f1      mX1     R       scale
        fmulp st(2), st ;// t2      fX1     mX1     R       scale

        fild st_int     ;// i2      t2      fX1     mX1     R       scale
        fsubr           ;// f2      fX1     mX1     R       scale

        sub ebx, st_int
        DELAY_TEST ebx

        fxch st(2)      ;// mX1     fX1     f2      R       scale
        fadd            ;// Y1      f2      R       scale

        fld _Xn         ;// nX1     Y1      f2      R       scale

        fld st(3)       ;// R1      nX1     Y1      f2      R       scale
        fxch st(2)      ;// Y1      nX1     R1      f2      R       scale

        fmul st(2), st  ;// Y1      nX1     RY1     f2      R       scale
        fstp _Yn        ;// nX1     RY1     f2
        fadd            ;// NX1     f2      R       scale

        fld st(2)       ;// R2      NX1     f2      R       scale
        fxch            ;// NX1     R2      f2      R       scale

        fstp _Xn        ;// R2      f2      R       scale

        inc ecx

        fld _Xm(ebx)    ;// mX2     R2      f2      R       scale
        fld _Xm1(ebx)   ;// m1X2    mX2     R2      f2      R       scale
        fsub st, st(1)  ;// dX2     mX2     R2      f2

        fld _Xn         ;// nX2     dX2     mX2     R2      f2  R       scale

        fxch st(4)      ;// f2      dX2     mX2     R2      nX2
        fmul            ;// fX2     mX2     R2      nX2
        fadd            ;// Y2      R2      nX2

        fst _Yn
        fmul            ;// RY2     nX2     R       scale
        fadd            ;// NX2     R       scale
        fstp _Xn

        inc ecx

    .UNTIL ecx >= SAMARY_LENGTH

    fstp st
    fstp st

    call check_denormals

    GET_PIN [esi].pin_x.pPin, eax
    test [eax].dwStatus, PIN_CHANGING
    jz exit_rule_A

    jmp exit_rule_D1



ALIGN 16
delay_sX_dT_dR::
delay_dX_dT_dR::
    ;//         fpu     ebx
    ;// dX      empty   x_data
    ;//         fpu     st_int  edx
    ;// dT      scale   empty   T data
    ;//         fpu     edi
    ;// dR      ...     R data

    ;// FPU     scale

    xor ecx, ecx    ;// ecx should be zero

    .REPEAT

        fld _Tn         ;// T1      scale
        fabs            ;// T1      scale
        fmul st, st(1)  ;// t1      scale

        fld _Tn[4]      ;// T2      t1      scale
        fabs
        fmul st, st(2)  ;// t2      t1      scale
        fxch            ;// t1      t2      scale

        fist st_int     ;// t1      t2      scale
        mov eax, ecx
        fild st_int     ;// i1      t1      t2      scale
        fsubr           ;// f1      t2      scale

        sub eax, st_int
        DELAY_TEST eax

        fld   _Xm(eax)  ;// mX1     f1      t2      scale
        fsubr _Xm1(eax) ;// dX1     f1      t2      scale

        fld   _Xm(eax)  ;// mX1     dX1     f1      t2      scale

        mov ebx, ecx
        fxch st(3)      ;// t2      dX1     f1      mX1     scale

        fist st_int
        inc ebx

        fxch            ;// dX1     t2      f1      mX1     scale
        fmulp st(2), st ;// t2      fX1     mX1     scale

        fild st_int     ;// i2      t2      fX1     mX1     scale
        fsubr           ;// f2      fX1     mX1     scale

        sub ebx, st_int
        DELAY_TEST ebx

        fxch st(2)      ;// mX1     fX1     f2      scale
        fadd            ;// Y1      f2      scale

        fld _Xn         ;// nX1     Y1      f2      scale
        fld _Rn         ;// R1      nX1     Y1      f2      scale
        fxch st(2)      ;// Y1      nX1     R1      f2      scale

        fmul st(2), st  ;// Y1      nX1     RY1     f2      scale
        fstp _Yn        ;// nX1     RY1     f2
        fadd            ;// NX1     f2      scale

        fld _Rn[4]      ;// R2      NX1     f2      scale
        fxch            ;// NX1     R2      f2      scale

        fstp _Xn        ;// R2      f2      scale

        inc ecx

        fld _Xm(ebx)    ;// mX2     R2      f2      scale
        fld _Xm1(ebx)   ;// m1X2    mX2     R2      f2      scale
        fsub st, st(1)  ;// dX2     mX2     R2      f2

        fld _Xn         ;// nX2     dX2     mX2     R2      f2  scale

        fxch st(4)      ;// f2      dX2     mX2     R2      nX2
        fmul            ;// fX2     mX2     R2      nX2
        fadd            ;// Y2      R2      nX2

        fst _Yn
        fmul            ;// RY2     nX2     scale
        fadd            ;// NX2     scale
        fstp _Xn

        inc ecx

    .UNTIL ecx >= SAMARY_LENGTH

    fstp st

    call check_denormals

    GET_PIN [esi].pin_x.pPin, eax
    test [eax].dwStatus, PIN_CHANGING
    jz exit_rule_A

    jmp exit_rule_D1



;//////////////////////////////////////////////////////


ALIGN 16
exit_rule_A:
    ;// A   set prev_x and Y by scanning the data

    ;// scan prev_x

        lea edi, [esi].data_2
        mov ecx, SAMARY_LENGTH
        mov eax, [edi]
        and [esi].pin_x.dwUser, NOT PIN_CHANGING

        repe scasd

        jz next_test

        or [esi].pin_x.dwUser, PIN_CHANGING


    ;// scan pin_y
    next_test:

        mov edi, [esi].pin_y.pData

        mov ecx, SAMARY_LENGTH
        mov eax, [edi]
        and [esi].pin_y.dwStatus, NOT PIN_CHANGING

        repe scasd

        jz cleanup_stack
        or [esi].pin_y.dwStatus, PIN_CHANGING

        jmp cleanup_stack


ALIGN 16
exit_rule_A0:

    ;// if prev_x || x[0] != y[0] then y changing, else y ! changing

        and [esi].pin_y.dwStatus, NOT PIN_CHANGING
        mov edx, [esi].pin_x.dwUser
        and [esi].pin_x.dwUser, NOT PIN_CHANGING
        test edx, PIN_CHANGING
        jnz a0_yes
        mov eax, [esi].data_2
        mov ebx, [esi].pin_y.pData
        cmp eax, DWORD PTR [ebx]
        je cleanup_stack

    a0_yes:

        or [esi].pin_y.dwStatus, PIN_CHANGING
        jmp cleanup_stack


ALIGN 16
exit_rule_D0:

    ;// D0  set both Y and prev_x = 0

    and [esi].pin_x.dwUser, NOT PIN_CHANGING
    and [esi].pin_y.dwStatus, NOT PIN_CHANGING

    jmp cleanup_stack


ALIGN 16
exit_rule_D1:

    ;// D1  set both Y and prev_x = 1

    or [esi].pin_x.dwUser, PIN_CHANGING
    or [esi].pin_y.dwStatus, PIN_CHANGING

    jmp cleanup_stack

ALIGN 16
exit_rule_E0:

    ;// E0  set Y based on prev X then set prev_x = 0

    mov eax, [esi].pin_x.dwUser
    and [esi].pin_y.dwStatus, NOT PIN_CHANGING
    and [esi].pin_x.dwUser, NOT PIN_CHANGING
    and eax, PIN_CHANGING
    or [esi].pin_y.dwStatus, eax
    jmp cleanup_stack

ALIGN 16
exit_rule_E1:
    ;// E0  set Y based on prev X then set prev_x = 1

    mov eax, [esi].pin_x.dwUser
    and [esi].pin_y.dwStatus, NOT PIN_CHANGING
    or [esi].pin_x.dwUser, PIN_CHANGING
    and eax, PIN_CHANGING
    or [esi].pin_y.dwStatus, eax
    jmp cleanup_stack

;//////////////////////////////////////////////////////


ALIGN 16
cleanup_stack:

    ;// reset the rounding mode

    fldcw WORD PTR play_fpu_control

    ;// clean up the stack

    mov esp, ebp
    pop esi
    pop ebp

all_done:

    ret



;///////////////////////////////////////////////////
;//
;//     resonate routines are used for sX sT
;//     ebx must point to the X[m] source
;//
;//     if source and dest are more than 4 values apart
;//         call math rountine to do it faster

ASSUME ebx:PTR DWORD


ALIGN 16
do_resonate_sR:

    ;// data_2  ebx    fpu   data_2
    ;// X[n] = X[m] * R[n] + X[n]
    ;// edi     esi    ebx    edx

    ;// ;// math_muladd_dXsAdB

    ;//ASSUME esi:PTR DWORD ;// esi is always X
    ;//ASSUME ebx:PTR DWORD ;// ebx is always A
    ;//ASSUME edx:PTR DWORD ;// edx is always B
    ;//ASSUME edi:PTR DWORD ;// edi is always Y

        lea eax, [esi].data_2
        sub eax, ebx
        .IF eax >= 10h  ;// must be 4 values

            fstp st_int[4]          ;// store the R value
            lea edi, [esi].data_2   ;// point at dest
            mov esi, ebx            ;// load the dX source
            lea ebx, st_int[4]      ;// load the sA source
            mov edx, edi            ;// load the dB source

            invoke math_muladd_dXsAdB

            mov esi, st_osc

        .ELSE   ;// have to use 1 at a time

            xor ecx, ecx
            .REPEAT

                fld [ebx]       ;// Xm      R
                fmul st, st(1)  ;// XmR     R
                fld _Xn         ;// Xn      XmR     R
                fadd
                add ebx, 4
                fstp _Xn

                inc ecx

            .UNTIL ecx >= SAMARY_LENGTH
            fstp st

        .ENDIF


    retn



ALIGN 16
do_resonate_dR:

    ;// data_2  ebx   pin_r  data_2
    ;// X[n] = X[m] * R[n] + X[n]
    ;// edi     esi    ebx    edx

    ;// ;// math_muladd_dXdAdB

    ;//ASSUME esi:PTR DWORD ;// esi is always X
    ;//ASSUME ebx:PTR DWORD ;// ebx is always A
    ;//ASSUME edx:PTR DWORD ;// edx is always B
    ;//ASSUME edi:PTR DWORD ;// edi is always Y

        lea eax, [esi].data_2
        sub eax, ebx
        .IF eax >= 10h  ;// must be 4 values

            mov eax, ebx            ;// need a temp reg for swapping
            mov ebx, edi            ;// point at dA source data
            lea edi, [esi].data_2   ;// point at dest
            mov esi, eax            ;// load the dX source
            mov edx, edi            ;// load the dB source

            invoke math_muladd_dXdAdB

            mov esi, st_osc

        .ELSE   ;// have to use 1 at a time

            xor ecx, ecx
            .REPEAT

                fld [ebx]       ;// Xm
                fmul _Rn        ;// XmR
                fld _Xn         ;// Xn      XmR
                fadd
                add ebx, 4
                fstp _Xn

                inc ecx

            .UNTIL ecx >= SAMARY_LENGTH

        .ENDIF

    retn


;///////////////////////////////////////////////////


ALIGN 16
check_denormals:

    ;// now we need to check for denormals
    ;// we check X and Y

    xor eax, eax
    fnstsw ax
    .IF ax & 2

        xor eax, eax                    ;// use for testing
        xor edx, edx                    ;// use for zeroing
        mov ecx, (SAMARY_LENGTH*2) - 1  ;// check two frames
        .REPEAT

            or eax, [esi+ecx*4].data_2
            .IF !ZERO?
                test eax, 07F800000h
                .IF ZERO?
                    mov [esi+ecx*4].data_2, edx
                .ENDIF
                mov eax, edx
            .ENDIF
            dec ecx

            or eax, [esi+ecx*4].data_2
            .IF !ZERO?
                test eax, 07F800000h
                .IF ZERO?
                    mov [esi+ecx*4].data_2, edx
                .ENDIF
                mov eax, edx
            .ENDIF
            dec ecx

        .UNTIL SIGN?

        fninit
        ;// cleanup_stack will reset the rounding mode
    .ENDIF

    retn

;///////////////////////////////////////////////////

delay_Calc ENDP

ASSUME_AND_ALIGN

ENDIF   ;// USE_THIS_FILE

END



