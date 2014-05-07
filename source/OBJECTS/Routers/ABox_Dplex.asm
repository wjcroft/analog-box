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
;// ABox_Dplex.asm
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


;// GDI DATA

    ;// list of pSources

    dplex_source_list   LABEL DWORD

        dd DPLEX_000_PSOURCE, DPLEX_P01_PSOURCE, DPLEX_P10_PSOURCE, DPLEX_P11_PSOURCE
        dd DPLEX_000_PSOURCE, DPLEX_N01_PSOURCE, DPLEX_N10_PSOURCE, DPLEX_N11_PSOURCE
        dd PAN_000_PSOURCE, PAN_P01_PSOURCE, PAN_P10_PSOURCE, PAN_P11_PSOURCE
        dd PAN_000_PSOURCE, PAN_N01_PSOURCE, PAN_N10_PSOURCE, PAN_N11_PSOURCE

;// object definition


osc_DPlex OSC_CORE { ,,,dplex_Calc }
          OSC_GUI  {,,,,,dplex_Command,dplex_InitMenu,,,osc_SaveUndo,dplex_LoadUndo,dplex_GetUnit }
          OSC_HARD { }

    OSC_DATA_LAYOUT {NEXT_DPlex,IDB_DPLEX,OFFSET popup_DPLEX,,
        4,4,
        SIZE OSC_OBJECT + ( SIZEOF APIN * 4 ),
        SIZE OSC_OBJECT + ( SIZEOF APIN * 4 ) + SAMARY_SIZE * 2,
        SIZE OSC_OBJECT + ( SIZEOF APIN * 4 ) + SAMARY_SIZE * 2 }

    OSC_DISPLAY_LAYOUT { dplex_container,DPLEX_000_PSOURCE,ICON_LAYOUT(4,2,2,2) }

    APIN_init {-1.0,, 'X',, UNIT_AUTO_UNIT }  ;// input
    APIN_init { 0.5,sz_Switch, 'S',, UNIT_PERCENT };// selector input
    APIN_init {-0.2,, 'Y',, PIN_OUTPUT OR UNIT_AUTO_UNIT }  ;// out 1
    APIN_init {+0.2,, 'Z',, PIN_OUTPUT OR UNIT_AUTO_UNIT }  ;// out 2

    short_name  db  'DPlex',0
    description db  'Selectively routes one signal to two outputs. Also used as a pan control.',0
    ALIGN 4


    ;// values for dwUser

    DPLEX_PAN   EQU 00000001h
    DPLEX_PAN2  EQU 00000002h

    DPLEX_MASK  EQU NOT(DPLEX_PAN OR DPLEX_PAN2)

;// OSC_MAP for this object

    OSC_MAP STRUCT

        OSC_OBJECT  {}
        pin_x   APIN    {}
        pin_s   APIN    {}
        pin_y   APIN    {}
        pin_z   APIN    {}
        data_y  dd SAMARY_LENGTH DUP (0)
        data_z  dd SAMARY_LENGTH DUP (0)

    OSC_MAP ENDS



.CODE

ASSUME_AND_ALIGN
dplex_GetUnit PROC

        ASSUME esi:PTR OSC_MAP
        ASSUME ebx:PTR APIN

    ;// if ebx is input
    ;// we return the matching unit from both outputs
    ;// if ebx is output, we return unit from input

        lea ecx, [esi].pin_x    ;// input
        ASSUME ecx:PTR APIN

        cmp ecx, ebx
        je examine_outputs

    ;// examine_inputs: xfer input unit to eax

        cmp [ecx].pPin, 0   ;// input connected ?
        je all_done         ;// carry flag is clear

        mov eax, [ecx].dwStatus
        jmp check_the_status

    examine_outputs:    ;// outputs must match

        cmp [esi].pin_y.pPin, 0 ;// y connected ?
        je y_not_connected

        mov eax, [esi].pin_y.dwStatus

        cmp [esi].pin_z.pPin, 0 ;// z connected ?
        je check_the_status

    both_are_connected:     ;// both are connected

        ;// mov eax, [esi].pin_y.dwStatus   ;// get status y

        bt eax, LOG2(UNIT_AUTOED)   ;// y auto ?
        jnc all_done

        mov edx, [esi].pin_z.dwStatus   ;// get status z

        bt edx, LOG2(UNIT_AUTOED)   ;// z auto ?
        jnc all_done

        and eax, UNIT_TEST      ;// remove extra bits
        and edx, UNIT_TEST      ;// remove extra bits

        cmp eax, edx            ;// same units ?
        je ok_to_use_already    ;// jump if same

        clc             ;// clear the carry flag
        jmp all_done

    y_not_connected:    ;// y is not connected

        cmp [esi].pin_z.pPin, 0 ;// z connected ?
        je all_done

        mov eax, [esi].pin_z.dwStatus   ;// get z's status

    check_the_status:   ;// common to many branches, eax has the unit to return

        bt eax, LOG2(UNIT_AUTOED)   ;// is auto set ?
        jnc all_done

    ok_to_use:          ;// mask and set carry

    ;// and eax, UNIT_TEST  ;// not nessesary

    ok_to_use_already:  ;// already masked, set the carry

        stc

    all_done:

        ret


dplex_GetUnit ENDP




;////////////////////////////////////////////////////////////////////////////



ASSUME_AND_ALIGN
dplex_InitMenu PROC ;// STDCALL uses esi pObject:PTR OSC_OBJECT

    ASSUME esi:PTR OSC_OBJECT

    mov ecx, ID_DPLEX_DPLEX
    .IF [esi].dwUser & DPLEX_PAN
        mov ecx, ID_DPLEX_PAN
    .ELSEIF [esi].dwUser & DPLEX_PAN2
        mov ecx, ID_DPLEX_PAN2
    .ENDIF

    invoke CheckDlgButton, popup_hWnd, ecx, BST_CHECKED

    xor eax, eax

    ret

dplex_InitMenu ENDP



ASSUME_AND_ALIGN
dplex_Command PROC  ;// STDCALL uses esi pObject:PTR OSC_OBJECT, cmdID:DWORD

    ASSUME esi:PTR OSC_OBJECT

    cmp eax, ID_DPLEX_DPLEX
    jnz @F

        xor ecx, ecx
        mov edx, dplex_source_list
        jmp all_done

@@: cmp eax, ID_DPLEX_PAN
    jnz @F

        mov ecx, DPLEX_PAN
        mov edx, dplex_source_list[8*4]
        jmp all_done

@@: cmp eax, ID_DPLEX_PAN2
    jnz osc_Command

    mov ecx, DPLEX_PAN2
        or [esi].dwUser, DPLEX_PAN2
        mov edx, dplex_source_list[8*4]

all_done:

    and [esi].dwUser, DPLEX_MASK
    mov eax, POPUP_SET_DIRTY OR POPUP_REDRAW_OBJECT
    or [esi].dwUser, ecx
    mov [esi].pSource, edx

    ret

dplex_Command ENDP






;////////////////////////////////////////////////////////////////////
;//
;//
;//     _LoadUndo
;//

ASSUME_AND_ALIGN
dplex_LoadUndo PROC

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

        mov edx, dplex_source_list
        .IF eax & ID_DPLEX_PAN OR ID_DPLEX_PAN2
        mov edx, dplex_source_list[8*4]
        .ENDIF

        mov [esi].pSource, edx

        ret

dplex_LoadUndo ENDP

;//
;//
;//     _LoadUndo
;//
;////////////////////////////////////////////////////////////////////


















comment ~ /*

    base formulas

            demultiplex     |   pan                 |   pan 2
          ------------------|-----------------------|------------
          |                 |                       |
        Y | S>0 ? X*S : 0   |   S>0 ? X : X*(S+1)   |   X*(S+1)/2
          |                 |                       |
        Z | S<0 ? -X*S: 0   |   S<0 ? X : X*(1-S)   |   X*(1-S)/2

    optimizing

        S = 0, 1 and -1 are special cases
        we also need to route the pin changing correctly
        a jump table is used

    nomenclature:

        M   mode

            D   dplex mode
            P   pan mode
            P2  pan half mode

        X   input pin
        S   switch pin

            d   dynamic
            s   static
            n   not connected
            z   static and zero
            p   static and positive
            p1  static and pos 1
            m   static and minus
            m1  static and minus 1

    state table () is base index


        /                   dS (0)  \
        | MD (0)    dX (0)  zS (1)  |   6 x 2 x 3 = 36 states
        | MP (12)   sX (6)  pS (2)  |   nX is special case
        | MP2 (24)  nX ()   p1S(3)  |
        |                   mS (4)  |
        \                   m1S(5)  /

    jump format

        dplex_M?_?X_?S


*/ comment ~

.DATA

    dlpex_calc_jump LABEL DWORD

        dd  dplex_MD_dX_dS, dplex_MD_dX_zS, dplex_MD_dX_pS, dplex_MD_dX_p1S, dplex_MD_dX_mS, dplex_MD_dX_m1S
        dd  dplex_MD_sX_dS, dplex_MD_sX_zS, dplex_MD_sX_pS, dplex_MD_sX_p1S, dplex_MD_sX_mS, dplex_MD_sX_m1S

        dd  dplex_MP_dX_dS, dplex_MP_dX_zS, dplex_MP_dX_pS, dplex_MP_dX_p1S, dplex_MP_dX_mS, dplex_MP_dX_m1S
        dd  dplex_MP_sX_dS, dplex_MP_sX_zS, dplex_MP_sX_pS, dplex_MP_sX_p1S, dplex_MP_sX_mS, dplex_MP_sX_m1S

        dd  dplex_MP2_dX_dS, dplex_MP2_dX_zS, dplex_MP2_dX_pS, dplex_MP2_dX_p1S, dplex_MP2_dX_mS, dplex_MP2_dX_m1S
        dd  dplex_MP2_sX_dS, dplex_MP2_sX_zS, dplex_MP2_sX_pS, dplex_MP2_sX_p1S, dplex_MP2_sX_mS, dplex_MP2_sX_m1S


    ;// clarity macros

    DPLEX_X     TEXTEQU <([edi+ecx])>
    DPLEX_S     TEXTEQU <([ebx+ecx])>

    DPLEX_Y     TEXTEQU <([esi+ecx].data_y)>
    DPLEX_Z     TEXTEQU <([esi+ecx].data_z)>

    CHANGING_Y  EQU 1
    CHANGING_Z  EQU 2

    CHANGE_Y    TEXTEQU <or edx, CHANGING_Y>
    CHANGE_Z    TEXTEQU <or edx, CHANGING_Z>
    CHANGE_XY   TEXTEQU <or edx, CHANGING_Y OR CHANGING_Z>

    ADVANCE     TEXTEQU <add ecx, 4>
    DONE_YET    TEXTEQU <cmp ecx, SAMARY_SIZE>
    CALC_EXIT   TEXTEQU <jmp dplex_calc_done>






.CODE


ASSUME_AND_ALIGN
dplex_Calc  PROC

        ASSUME esi:PTR OSC_MAP

        xor edi, edi    ;// edi looks at X
        xor ebx, ebx    ;// ebx looks at S
        xor edx, edx    ;// edx is the jump index
        xor eax, eax
        xor ecx, ecx    ;// used to count

    ;// setup the x pin

        OR_GET_PIN [esi].pin_x.pPin, edi
        jz x_not_connected      ;// special case if not connected

        test [edi].dwStatus, PIN_CHANGING
        mov edi, [edi].pData
        ASSUME edi:PTR DWORD
        .IF ZERO?

            add edx, 6      ;// edx = 6 sX
            cmp [edi], ecx
            jz x_not_connected

        .ENDIF

    ;// setup the S pin

        OR_GET_PIN [esi].pin_s.pPin, ebx    ;// get s's connection
        .IF ZERO?
            mov ebx, math_pNullPin
        .ENDIF

        test [ebx].dwStatus, PIN_CHANGING
        mov ebx, [ebx].pData
        ASSUME ebx:PTR DWORD
        jnz s_is_ready_now  ;// edx = 0 dS

        fld [ebx]       ;// load th first value
        inc edx         ;// edx = 1 zS
        ftst            ;// test it's sign
        fnstsw ax
        sahf
        jz s_is_ready   ;// edx = 1
        fld1
        inc edx         ;// edx = 2 pS      doesn't change the carry flag
        jnc s_is_pos

    s_is_neg:

        fchs
        add edx, 2      ;// edx = 4     mS

    s_is_pos:

        fucomp          ;// compare and pop
        fnstsw ax
        sahf            ;// jump            fallthrough
        jnz s_is_ready  ;// edx = 2 pS      edx = 4 mS
        inc edx         ;// edx = 3 p1S     edx = 5 m1S

    s_is_ready:     fstp st
    s_is_ready_now:

    ;// set up the mode

        test [esi].dwUser, DPLEX_PAN OR DPLEX_PAN2
        jz mode_is_ready
        add edx, 12
        test [esi].dwUser, DPLEX_PAN2
        jz mode_is_ready
        add edx, 12

    mode_is_ready:

    ;// make sure the data pointers are correct

        lea ecx, [esi].data_z
        lea eax, [esi].data_y
        mov [esi].pin_z.pData, ecx
        mov [esi].pin_y.pData, eax

        xor ecx, ecx

    ;// ready to jump

        jmp dlpex_calc_jump[edx*4]


    ALIGN 16
    dplex_calc_done::

    ;// reset pin changing for both

        and [esi].pin_y.dwStatus, NOT PIN_CHANGING
        and [esi].pin_z.dwStatus, NOT PIN_CHANGING

    xor eax, eax

        .IF edx & CHANGING_Y
            or [esi].pin_y.dwStatus, PIN_CHANGING
        .ENDIF
        .IF edx & CHANGING_Z
            or [esi].pin_z.dwStatus, PIN_CHANGING
        .ENDIF

    ;// now we check which graphic we do

    or eax, [esi].dwHintOsc     ;// onscreen is hintosc sign bit
    .IF SIGN?                   ;// don't bother if offscreen

        ;// dtermine the index we want to use
        ;//
        ;// the psource table is arragnged:   1/6   1/2   5/6
        ;//                                 0     1     2     3

        xor eax, eax
        xor ecx, ecx
        xor edx, edx            ;// edx ends up as the index

        OSC_TO_PIN_INDEX esi,ebx,1  ;// selector pin
        test [esi].dwUser, DPLEX_PAN OR DPLEX_PAN2
        GET_PIN [ebx].pPin, ebx     ;// get the connection
        .IF !ZERO?
            add edx, 8                  ;// add 8 if we're a pan
        .ENDIF

        or ebx, ebx                 ;// make sure we are connected
        jz check_edx                ;// jump if not connected

        ;// we are connected    ecx and eax are cleared
        ;//                     edx is at the start of an index table

        mov ebx, [ebx].pData        ;// load the data pointer
        ASSUME ebx:PTR DWORD

        ;// test for neg/pos and zero

        or ecx, [ebx]   ;// test the first value
        jz check_edx    ;// just in case it's zero, we can exit now

        fld [ebx]       ;// load the value we're testing

        jns @F          ;// jmp if neg
        fabs            ;// make sure we alwys use postive values
        add edx, 4      ;// add 4 if negative
    @@:
        fld math_5_6
        fld math_1_6    ;// load these three values in reverse test order
        fld math_1_2    ;// 1/2     1/6     5_6     value

        ;// test for 1/2

        fucomp st(3)    ;// 1/6     5_6     value

        fnstsw ax
        sahf
        jnc @F      ;// jump if st < st(3)
        fxch        ;// swap the next test value
        add edx, 2  ;// add 2 to get to the next part
    @@:

        ;// test for 1/6 or 5/6

        fucomp st(2)    ;// 5_6     value
        fnstsw ax
        sahf
        jnc @F      ;// jump if st < st(2)
        inc edx     ;// add one
    @@:
        ;// now edx should be at the proper index
        fstp st
        fstp st

    check_edx:

        mov edx, dplex_source_list[edx*4]   ;// load the desired source

        .IF edx != [esi].pSource        ;// same as current ?
            mov [esi].pSource, edx      ;// set a new source
            invoke play_Invalidate_osc  ;// schedule for redraw
        .ENDIF

    .ENDIF


    ;// that's it !

        ret

dplex_Calc  ENDP


;////////////////////////////////////

ALIGN 16
dplex_MD_sX_zS:
dplex_MD_dX_zS:
x_not_connected PROC

    mov eax, math_pNull
    mov [esi].pin_y.pData, eax
    mov [esi].pin_z.pData, eax

    xor edx, edx

    CALC_EXIT

x_not_connected ENDP



;////////////////////////////////////

ALIGN 16
dplex_MD_dX_dS  PROC

        xor eax, eax
        xor edx, edx

    ALIGN 16
    top_of_loop:

        or eax, DPLEX_S
        jz s_is_zero

        fld DPLEX_S
        fld DPLEX_X
        fmul

        js s_is_neg

    ALIGN 16
    s_is_pos:

        fstp DPLEX_Y
        xor eax, eax
        CHANGE_Y
        mov DPLEX_Z, eax

        ADVANCE
        DONE_YET
        jb top_of_loop
        CALC_EXIT

    ALIGN 16
    s_is_neg:

        xor eax, eax
        CHANGE_Z
        fchs
        mov DPLEX_Y, eax
        fstp DPLEX_Z

        ADVANCE
        DONE_YET
        jb top_of_loop
        CALC_EXIT

    ALIGN 16
    s_is_zero:

        mov DPLEX_Y, eax
        mov DPLEX_Z, eax

        ADVANCE
        DONE_YET
        jb top_of_loop
        CALC_EXIT

dplex_MD_dX_dS  ENDP

;////////////////////////////////////

ALIGN 16
dplex_MD_dX_pS PROC

    mov eax, math_pNull
    mov [esi].pin_z.pData, eax

    push esi
    add esi, OFFSET OSC_MAP.data_y
    xchg esi, edi

    invoke math_mul_dXsA

    pop esi

    mov edx, CHANGING_Y

    CALC_EXIT

dplex_MD_dX_pS ENDP

;////////////////////////////////////

ALIGN 16
dplex_MP_dX_p1S:
dplex_MP2_dX_p1S:
dplex_MD_dX_p1S PROC

    mov eax, math_pNull
    mov [esi].pin_z.pData, eax

    mov edx, CHANGING_Y
    mov [esi].pin_y.pData, edi

    CALC_EXIT

dplex_MD_dX_p1S ENDP

;////////////////////////////////////

ALIGN 16
dplex_MD_dX_mS PROC

    mov eax, math_pNull
    mov [esi].pin_y.pData, eax

    push esi
    add esi, OFFSET OSC_MAP.data_z
    xchg esi, edi

    invoke math_mul_dXsA_neg

    pop esi

    mov edx, CHANGING_Z

    CALC_EXIT

dplex_MD_dX_mS ENDP


;////////////////////////////////////

ALIGN 16
dplex_MP_dX_m1S:
dplex_MP2_dX_m1S:
dplex_MD_dX_m1S PROC

    mov eax, math_pNull
    mov [esi].pin_y.pData, eax

    mov edx, CHANGING_Z
    mov [esi].pin_z.pData, edi

    CALC_EXIT

dplex_MD_dX_m1S ENDP

;////////////////////////////////////

ALIGN 16
dplex_MD_sX_dS PROC

        xor eax, eax
        fld DPLEX_X
        xor edx, edx

    ALIGN 16
    top_of_loop:

        or eax, DPLEX_S
        jz s_is_zero

        fld DPLEX_S
        fmul st, st(1)

        js s_is_neg

    s_is_pos:

        xor eax, eax
        CHANGE_Y
        fstp DPLEX_Y
        mov DPLEX_Z, eax

        ADVANCE
        DONE_YET
        jb top_of_loop
        fstp st
        CALC_EXIT

    ALIGN 16
    s_is_neg:

        xor eax, eax
        CHANGE_Z
        mov DPLEX_Y, eax
        fchs
        fstp DPLEX_Z

        ADVANCE
        DONE_YET
        jb top_of_loop
        fstp st
        CALC_EXIT

    ALIGN 16
    s_is_zero:

        mov DPLEX_Y, eax
        mov DPLEX_Z, eax

        ADVANCE
        DONE_YET
        jb top_of_loop
        fstp st
        CALC_EXIT

dplex_MD_sX_dS ENDP

;////////////////////////////////////


ALIGN 16
dplex_MD_sX_pS PROC

    mov eax, math_pNull
    mov [esi].pin_z.pData, eax

    fld [ebx]
    fld [edi]

    fmul

    fstp [esi].data_y

    call dplex_fill_y

    xor edx, edx

    CALC_EXIT

dplex_MD_sX_pS ENDP

;////////////////////////////////////

ALIGN 16
dplex_MP_sX_p1S:
dplex_MP2_sX_p1S:
dplex_MD_sX_p1S PROC

    mov eax, math_pNull
    mov [esi].pin_z.pData, eax
    xor edx, edx
    mov [esi].pin_y.pData, edi

    CALC_EXIT

dplex_MD_sX_p1S ENDP


;////////////////////////////////////

ALIGN 16
dplex_MD_sX_mS PROC

    mov eax, math_pNull
    mov [esi].pin_y.pData, eax

    fld [ebx]
    fld [edi]
    fmul
    fchs
    fstp [esi].data_z

    call dplex_fill_z

    xor edx, edx

    CALC_EXIT

dplex_MD_sX_mS ENDP

;////////////////////////////////////

ALIGN 16
dplex_MP_sX_m1S:
dplex_MP2_sX_m1S:
dplex_MD_sX_m1S PROC

    mov eax, math_pNull
    mov [esi].pin_y.pData, eax
    xor edx, edx
    mov [esi].pin_z.pData, edi

    CALC_EXIT

dplex_MD_sX_m1S ENDP

;////////////////////////////////////







;////////////////////////////////////

ALIGN 16
dplex_MP_dX_dS PROC

        xor eax, eax
        mov edx, CHANGING_Y OR CHANGING_Z

    ALIGN 16
    top_of_loop:

        or eax, DPLEX_S
        fld DPLEX_X     ;// X
        jz s_is_zero

        fld DPLEX_S     ;// S       X
        fmul st, st(1)  ;// SX      X

        js s_is_neg

    s_is_pos:

        ;// Y = X
        ;// Z = X - SX
                        ;// SX      X
        fsubr st, st(1) ;// X-SX    X
        fxch            ;// Y       Z

        fstp DPLEX_Y
        fstp DPLEX_Z

        ADVANCE
        DONE_YET
        jb top_of_loop
        CALC_EXIT

    ALIGN 16
    s_is_neg:

        ;// Y = X + SX
        ;// Z = X

        fadd st, st(1)  ;// X+SX    X
        fxch            ;// Z       Y
        xor eax, eax
        fstp DPLEX_Z
        fstp DPLEX_Y

        ADVANCE
        DONE_YET
        jb top_of_loop
        CALC_EXIT

    ALIGN 16
    s_is_zero:

        fst DPLEX_Y     ;// X
        fstp DPLEX_Z

        ADVANCE
        DONE_YET
        jb top_of_loop
        CALC_EXIT

dplex_MP_dX_dS ENDP

;////////////////////////////////////

ALIGN 16
dplex_MP_dX_zS PROC

    mov [esi].pin_y.pData, edi
    mov [esi].pin_z.pData, edi

    mov edx, CHANGING_Y OR CHANGING_Z

    CALC_EXIT

dplex_MP_dX_zS ENDP

;////////////////////////////////////

ALIGN 16
dplex_MP_dX_pS PROC

    ;// Y = X
    ;// Z = X - SX = X * (1-S)

    mov [esi].pin_y.pData, edi

    fld1        ;// 1
    fld [ebx]   ;// S
    fsub        ;// 1-S

    push esi
    push eax

    add esi, OFFSET OSC_MAP.data_z

    fstp DWORD PTR [esp]
    mov ebx, esp

    xchg esi, edi

    invoke math_mul_dXsA

    pop eax
    mov edx, CHANGING_Y OR CHANGING_Z
    pop esi

    CALC_EXIT

dplex_MP_dX_pS ENDP

;////////////////////////////////////


ALIGN 16
dplex_MP_dX_mS PROC

    ;// Y = X + SX = X*(1+S)
    ;// Z = X

    mov [esi].pin_z.pData, edi

    fld1        ;// 1
    fld [ebx]   ;// S
    fadd        ;// S+1

    push esi
    push eax

    add esi, OFFSET OSC_MAP.data_y

    fstp DWORD PTR [esp]
    mov ebx, esp

    xchg esi, edi

    invoke math_mul_dXsA

    pop eax
    mov edx, CHANGING_Y OR CHANGING_Z
    pop esi

    CALC_EXIT

dplex_MP_dX_mS ENDP


;////////////////////////////////////

ALIGN 16
dplex_MP_sX_dS PROC

        fld [edi]   ;// X

        xor eax, eax
        xor edx, edx

    ALIGN 16
    top_of_loop:

        or eax, DPLEX_S
        jz s_is_zero

        fld DPLEX_S     ;// S       X
        fmul st, st(1)  ;// SX      X

        js s_is_neg

    s_is_pos:

        ;// Y = X
        ;// Z = X - SX

        fsubr st, st(1) ;// X-SX    X
        fxch            ;// Y       Z

        fst DPLEX_Y     ;// X       Z
        CHANGE_Z
        fxch            ;// Z       X
        fstp DPLEX_Z    ;// X

        ADVANCE
        DONE_YET
        jb top_of_loop
        fstp st
        CALC_EXIT

    ALIGN 16
    s_is_neg:

        ;// Y = X + SX
        ;// Z = X

        fadd st, st(1)  ;// X+SX    X
        fxch            ;// Z       Y
        xor eax, eax
        fst DPLEX_Z
        CHANGE_Y
        fxch            ;// Y       X
        fstp DPLEX_Y

        ADVANCE
        DONE_YET
        jb top_of_loop
        fstp st
        CALC_EXIT

    ALIGN 16
    s_is_zero:

        fst DPLEX_Y
        fst DPLEX_Z

        ADVANCE
        DONE_YET
        jb top_of_loop
        fstp st
        CALC_EXIT

dplex_MP_sX_dS ENDP

;////////////////////////////////////

ALIGN 16
dplex_MP_sX_zS PROC

    mov [esi].pin_y.pData, edi
    mov [esi].pin_z.pData, edi

    xor edx, edx

    CALC_EXIT

dplex_MP_sX_zS ENDP

;////////////////////////////////////

ALIGN 16
dplex_MP_sX_pS PROC

    ;// Y = X
    ;// Z = X - SX

    mov [esi].pin_y.pData, edi

    fld [edi]       ;// X
    fld [ebx]       ;// S       X
    fmul st, st(1)  ;// SX      X
    fsub            ;// X-XS

    fstp [esi].data_z

    call dplex_fill_z

    xor edx, edx

    CALC_EXIT

dplex_MP_sX_pS ENDP

;////////////////////////////////////

ALIGN 16
dplex_MP_sX_mS PROC

    ;// Y = X + SX
    ;// Z = X

    mov [esi].pin_z.pData, edi

    fld [edi]       ;// X
    fld [ebx]       ;// S       X
    fmul st, st(1)  ;// SX      X
    fadd            ;// X+SX
    fstp [esi].data_y

    call dplex_fill_y

    xor edx, edx

    CALC_EXIT

dplex_MP_sX_mS ENDP

;////////////////////////////////////









;////////////////////////////////////

ALIGN 16
dplex_MP2_dX_dS PROC

    ;// Y = X/2 + S*X/2
    ;// Z = X/2 - S*X/2

        fld math_1_2

    top_of_loop:

        ;// two at at time

        fld DPLEX_X     ;// X1      1/2
        fmul st, st(1)  ;// x1      1/2
        fld [edi+ecx+4] ;// X2      x1      1/2
        fmul st, st(2)  ;// x2      x1      1/2

        fld [ebx+ecx]   ;// S1      x2      x1      1/2
        fld [ebx+ecx+4] ;// S2      S1      x2      x1      1/2

        fxch            ;// S1      S2      x2      x1      1/2
        fmul st, st(3)  ;// s1x1    S2      x2      x1      1/2
        fxch            ;// S2      S1x1    x2      x1      1/2
        fmul st, st(2)  ;// s2x2    S1x1    x2      x1      1/2

        fld st(3)       ;// x1      s2x2    S1x1    x2      x1      1/2
        fadd st, st(2)  ;// Y1      s2x2    S1x1    x2      x1      1/2
        fld st(3)       ;// x2      Y1      s2x2    S1x1    x2      x1      1/2
        fadd st, st(2)  ;// Y2      Y1      s2x2    S1x1    x2      x1      1/2

        fxch st(3)      ;// S1x1    Y1      s2x2    Y2      x2      x1      1/2
        fsubp st(5), st ;// Y1      s2x2    Y2      x2      Z1      1/2
        fxch            ;// s2x2    Y1      Y2      x2      Z1      1/2
        fsubp st(3), st ;// Y1      Y2      Z2      Z1      1/2

        fstp [esi+ecx].data_y
        fstp [esi+ecx].data_y[4]

        fxch

        fstp [esi+ecx].data_z
        fstp [esi+ecx].data_z[4]

        add ecx, 8

        DONE_YET

        jb top_of_loop

        fstp st
        mov edx, CHANGING_Y OR CHANGING_Z
        CALC_EXIT

dplex_MP2_dX_dS ENDP

;////////////////////////////////////

ALIGN 16
dplex_MP2_dX_zS PROC

    ;// Y = X/2
    ;// Z = X/2

    lea eax, [esi].data_y
    push esi
    mov [esi].pin_z.pData, eax

    push math_1_2

    add esi, OFFSET OSC_MAP.data_y

    mov ebx, esp

    xchg esi, edi

    invoke math_mul_dXsA

    pop eax
    mov edx, CHANGING_Y OR CHANGING_Z
    pop esi

    CALC_EXIT


dplex_MP2_dX_zS ENDP

;////////////////////////////////////

ALIGN 16
dplex_MP2_dX_mS:
dplex_MP2_dX_pS PROC

    ;// Y = X/2 + S*X/2 = X * (1+S)/2
    ;// Z = X/2 - S*X/2 = X * (1-S)/2

    push esi    ;// have to save
    push ebx
    push ecx    ;// room for temp

    fld math_1_2
    fld1
    fld [ebx]
    fadd
    fmul

    fstp DWORD PTR [esp]

    mov ebx, esp

    add esi, OFFSET OSC_MAP.data_y
    xchg esi, edi

    push esi
    push edi

    invoke math_mul_dXsA

    pop edi
    pop esi

    mov ebx, [esp+4]
    add edi, SAMARY_SIZE

    fld math_1_2
    fld1
    fld [ebx]
    fsub
    fmul

    mov ebx, esp

    fstp DWORD PTR [esp]

    invoke math_mul_dXsA

    add esp, 8
    pop esi
    mov edx, CHANGING_Y OR CHANGING_Z

    CALC_EXIT

dplex_MP2_dX_pS ENDP

;////////////////////////////////////

ALIGN 16
dplex_MP2_sX_dS PROC

    ;// Y = X/2 + S*X/2     s*x + x     esi X, ebx A, edx B, edi out
    ;// Z = X/2 - S*X/2     -s*x + x        S      x      x


    push esi    ;// have to save
    push eax    ;// make room for temp

    ;// build x for Y side

    fld math_1_2
    fld [edi]
    fmul
    fstp DWORD PTR [esp]

    ;// stack
    ;// x   esi

    lea edi, [esi].data_y   ;// edi must point at out put
    mov esi, ebx    ;// esi must point at dS
    mov ebx, esp    ;// ebx must point at sX
    mov edx, esp    ;// edx must point at sX as well

    push edi
    push esi

    invoke math_muladd_dXsAsB

    pop esi
    pop edi

    ;// make x negative and save again

    mov eax, [esp]
    xor eax, 80000000h
    push eax
    mov ebx, esp
    lea edx, [ebx+4]

    ;// stack
    ;// -x  x   esi

    add edi, SAMARY_SIZE

    invoke math_muladd_dXsAsB

    add esp, 8
    pop esi

    mov edx, CHANGING_Y OR CHANGING_Z

    CALC_EXIT

dplex_MP2_sX_dS ENDP

;////////////////////////////////////

ALIGN 16
dplex_MP2_sX_zS PROC

    lea eax, [esi].data_y

    fld math_1_2
    fmul [edi]
    fstp [esi].data_y

    mov [esi].pin_z.pData, eax

    call dplex_fill_y

    xor edx, edx

    CALC_EXIT

dplex_MP2_sX_zS ENDP

;////////////////////////////////////

ALIGN 16
dplex_MP2_sX_mS:
dplex_MP2_sX_pS PROC

    ;// Y = X/2 + S*X/2
    ;// Z = X/2 - S*X/2

    fld math_1_2
    fld DPLEX_X
    fmul
    fld DPLEX_S
    fmul st, st(1)  ;// SX  X

    fld st(1)       ;// X   SX  X
    fadd st, st(1)  ;// Y   SX  X
    fxch            ;// SX  Y   X
    fsubp st(2), st ;// Y   Z

    fstp [esi].data_y
    fstp [esi].data_z

    call dplex_fill_y
    call dplex_fill_z

    xor edx, edx

    CALC_EXIT

dplex_MP2_sX_pS ENDP


;////////////////////////////////////


;////////////////////////////////////



ALIGN 16
dplex_fill_y PROC

    ;// first value must already be set

        mov eax, [esi].data_y
        test [esi].pin_y.dwStatus, PIN_CHANGING
        jnz have_to_store
        cmp eax, [esi].data_y[4]
        je all_done

    have_to_store:

        push edi
        mov ecx, SAMARY_LENGTH-1
        lea edi, [esi].data_y[4]
        rep stosd
        pop edi

    all_done:

        ret

dplex_fill_y ENDP


ALIGN 16
dplex_fill_z PROC

    ;// first value must already be set

        mov eax, [esi].data_z
        test [esi].pin_z.dwStatus, PIN_CHANGING
        jnz have_to_store
        cmp eax, [esi].data_z[4]
        je all_done

    have_to_store:

        push edi
        mov ecx, SAMARY_LENGTH-1
        lea edi, [esi].data_z[4]
        rep stosd
        pop edi

    all_done:

        ret

dplex_fill_z ENDP







ASSUME_AND_ALIGN

ENDIF   ;// USE_THIS_FILE
END

