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
;// ABox_Mplex.asm
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


;// list of pSources

    mplex_source_list   LABEL DWORD

        dd MPLEX_000_PSOURCE, MPLEX_P01_PSOURCE, MPLEX_P10_PSOURCE, MPLEX_P11_PSOURCE
        dd MPLEX_000_PSOURCE, MPLEX_N01_PSOURCE, MPLEX_N10_PSOURCE, MPLEX_N11_PSOURCE
        dd XFADE_000_PSOURCE, XFADE_P01_PSOURCE, XFADE_P10_PSOURCE, XFADE_P11_PSOURCE
        dd XFADE_000_PSOURCE, XFADE_N01_PSOURCE, XFADE_N10_PSOURCE, XFADE_N11_PSOURCE


;// size of the object

    ;// MPLEX_SIZE_X equ 32
    ;// MPLEX_SIZE_Y equ 28

;// object definition


osc_MPlex OSC_CORE { ,,,mplex_Calc}
          OSC_GUI  {,,,,,mplex_Command,mplex_InitMenu,,,osc_SaveUndo,mplex_LoadUndo,mplex_GetUnit }
          OSC_HARD { }

    OSC_DATA_LAYOUT {NEXT_MPlex,IDB_MPLEX,OFFSET popup_MPLEX,,4,4,
        SIZEOF OSC_OBJECT + ( SIZEOF APIN ) * 4,
        SIZEOF OSC_OBJECT + ( SIZEOF APIN ) * 4 + SAMARY_SIZE,
        SIZEOF OSC_OBJECT + ( SIZEOF APIN ) * 4 + SAMARY_SIZE }

    OSC_DISPLAY_LAYOUT { mplex_container,MPLEX_000_PSOURCE,ICON_LAYOUT(2,2,2,1)}

    APIN_init {-0.8,, 'X',, UNIT_AUTO_UNIT  } ;// in 1
    APIN_init {+0.8,, 'Y',, UNIT_AUTO_UNIT  } ;// in 2
    APIN_init { 0.5,sz_Switch, 'S',, UNIT_PERCENT } ;// selector input
    APIN_init { 0.0,, 'Z',, PIN_OUTPUT OR UNIT_AUTO_UNIT }  ;// out

    short_name  db  'MPlex',0
    description db  'Selectively combines two inputs into one output. Also used as a cross fader.',0
    ALIGN 4






    ;// setting for dwUser

    MPLEX_XFADE     equ 00000001h
    MPLEX_XFADE2    equ 00000002h

    MPLEX_MASK      equ NOT (MPLEX_XFADE OR MPLEX_XFADE2)

    OSC_MAP STRUCT

        OSC_OBJECT  {}
        pin_x   APIN    {}
        pin_y   APIN    {}
        pin_s   APIN    {}
        pin_z   APIN    {}
        data_z  dd SAMARY_LENGTH DUP (0)

    OSC_MAP ENDS


.CODE



ASSUME_AND_ALIGN
mplex_GetUnit PROC

        ASSUME esi:PTR OSC_MAP
        ASSUME ebx:PTR APIN

        ;// if ebx is input, return unit from output
        ;// if ebx is output
        ;// we return the matching unit from both inputs

        lea ecx, [esi].pin_z    ;// out
        ASSUME ecx:PTR APIN

        cmp ecx, ebx
        je all_done

        mov eax, [ecx].dwStatus
        BITT eax, UNIT_AUTOED

    all_done:

        ret


mplex_GetUnit ENDP






ASSUME_AND_ALIGN
mplex_InitMenu PROC

    ASSUME esi:PTR OSC_OBJECT

    mov ecx, ID_MPLEX_MPLEX
    .IF [esi].dwUser & MPLEX_XFADE
        mov ecx, ID_MPLEX_XFADE
    .ELSEIF [esi].dwUser & MPLEX_XFADE2
        mov ecx, ID_MPLEX_XFADE2
    .ENDIF

    invoke CheckDlgButton, popup_hWnd, ecx, BST_CHECKED


    xor eax, eax

    ret

mplex_InitMenu ENDP




ASSUME_AND_ALIGN
mplex_Command PROC

    ASSUME esi:PTR OSC_OBJECT
    ;// eax has the command id

    cmp eax, ID_MPLEX_MPLEX
    jnz @F

        xor ecx, ecx
        mov edx, mplex_source_list
        jmp all_done

@@: cmp eax, ID_MPLEX_XFADE
    jnz @F

        mov ecx, MPLEX_XFADE
        mov edx, mplex_source_list
        jmp all_done

@@: cmp eax, ID_MPLEX_XFADE2
    jnz osc_Command

        mov ecx, MPLEX_XFADE2
        mov edx, mplex_source_list[8*4]

all_done:

        and [esi].dwUser, MPLEX_MASK

        or [esi].dwUser, ecx
        mov [esi].pSource, edx

        mov eax, POPUP_SET_DIRTY OR POPUP_REDRAW_OBJECT

    ret

mplex_Command ENDP





;////////////////////////////////////////////////////////////////////
;//
;//
;//     _LoadUndo
;//

ASSUME_AND_ALIGN
mplex_LoadUndo PROC

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

        mov edx, mplex_source_list

        .IF eax & MPLEX_XFADE2
            mov edx, mplex_source_list[8*4]
        .ENDIF

        mov [esi].pSource, edx

        ret

mplex_LoadUndo ENDP

;//
;//
;//     _LoadUndo
;//
;////////////////////////////////////////////////////////////////////





comment ~ /*


;// equations:

;//                X      S>0 ->  Z=S*X
;// multiplex       S Z
;//                Y      S<0 ->  Z=-S*Y



;//                X      S>0 ->  Z=X+Y - S*Y
;// crossfade       S Z
;//                Y      S<0 ->  Z=X+Y + S*X



    mplex calc

    there are a lot of states

    see Demultiplexer for more details



    dX(0)   dY(0)  dS  (0)
    sX(18)  sY(6)  zS  (1)
    zX(36)  zY(12) pS  (2)  MD (0)
                   p1S (3)  MX (54)
                   mS  (4)  MX2(108)
                   m1S (5)

wid 18      6       0       54





*/ comment ~


.DATA

    mplex_calc_jump LABEL DWORD

    dd mplex_dXdY_dS_MD,mplex_dXdY_zS_MD,mplex_dXdY_pS_MD,mplex_dXdY_p1S_MD,mplex_dXdY_mS_MD,mplex_dXdY_m1S_MD
    dd mplex_sXdY_dS_MD,mplex_sXdY_zS_MD,mplex_sXdY_pS_MD,mplex_sXdY_p1S_MD,mplex_sXdY_mS_MD,mplex_sXdY_m1S_MD
    dd mplex_zXdY_dS_MD,mplex_zXdY_zS_MD,mplex_zXdY_pS_MD,mplex_zXdY_p1S_MD,mplex_zXdY_mS_MD,mplex_zXdY_m1S_MD
    dd mplex_dXsY_dS_MD,mplex_dXsY_zS_MD,mplex_dXsY_pS_MD,mplex_dXsY_p1S_MD,mplex_dXsY_mS_MD,mplex_dXsY_m1S_MD
    dd mplex_sXsY_dS_MD,mplex_sXsY_zS_MD,mplex_sXsY_pS_MD,mplex_sXsY_p1S_MD,mplex_sXsY_mS_MD,mplex_sXsY_m1S_MD
    dd mplex_zXsY_dS_MD,mplex_zXsY_zS_MD,mplex_zXsY_pS_MD,mplex_zXsY_p1S_MD,mplex_zXsY_mS_MD,mplex_zXsY_m1S_MD
    dd mplex_dXzY_dS_MD,mplex_dXzY_zS_MD,mplex_dXzY_pS_MD,mplex_dXzY_p1S_MD,mplex_dXzY_mS_MD,mplex_dXzY_m1S_MD
    dd mplex_sXzY_dS_MD,mplex_sXzY_zS_MD,mplex_sXzY_pS_MD,mplex_sXzY_p1S_MD,mplex_sXzY_mS_MD,mplex_sXzY_m1S_MD
    dd mplex_zXzY_dS_MD,mplex_zXzY_zS_MD,mplex_zXzY_pS_MD,mplex_zXzY_p1S_MD,mplex_zXzY_mS_MD,mplex_zXzY_m1S_MD

    dd mplex_dXdY_dS_MX,mplex_dXdY_zS_MX,mplex_dXdY_pS_MX,mplex_dXdY_p1S_MX,mplex_dXdY_mS_MX,mplex_dXdY_m1S_MX
    dd mplex_sXdY_dS_MX,mplex_sXdY_zS_MX,mplex_sXdY_pS_MX,mplex_sXdY_p1S_MX,mplex_sXdY_mS_MX,mplex_sXdY_m1S_MX
    dd mplex_zXdY_dS_MX,mplex_zXdY_zS_MX,mplex_zXdY_pS_MX,mplex_zXdY_p1S_MX,mplex_zXdY_mS_MX,mplex_zXdY_m1S_MX
    dd mplex_dXsY_dS_MX,mplex_dXsY_zS_MX,mplex_dXsY_pS_MX,mplex_dXsY_p1S_MX,mplex_dXsY_mS_MX,mplex_dXsY_m1S_MX
    dd mplex_sXsY_dS_MX,mplex_sXsY_zS_MX,mplex_sXsY_pS_MX,mplex_sXsY_p1S_MX,mplex_sXsY_mS_MX,mplex_sXsY_m1S_MX
    dd mplex_zXsY_dS_MX,mplex_zXsY_zS_MX,mplex_zXsY_pS_MX,mplex_zXsY_p1S_MX,mplex_zXsY_mS_MX,mplex_zXsY_m1S_MX
    dd mplex_dXzY_dS_MX,mplex_dXzY_zS_MX,mplex_dXzY_pS_MX,mplex_dXzY_p1S_MX,mplex_dXzY_mS_MX,mplex_dXzY_m1S_MX
    dd mplex_sXzY_dS_MX,mplex_sXzY_zS_MX,mplex_sXzY_pS_MX,mplex_sXzY_p1S_MX,mplex_sXzY_mS_MX,mplex_sXzY_m1S_MX
    dd mplex_zXzY_dS_MX,mplex_zXzY_zS_MX,mplex_zXzY_pS_MX,mplex_zXzY_p1S_MX,mplex_zXzY_mS_MX,mplex_zXzY_m1S_MX

    dd mplex_dXdY_dS_MX2,mplex_dXdY_zS_MX2,mplex_dXdY_pS_MX2,mplex_dXdY_p1S_MX2,mplex_dXdY_mS_MX2,mplex_dXdY_m1S_MX2
    dd mplex_sXdY_dS_MX2,mplex_sXdY_zS_MX2,mplex_sXdY_pS_MX2,mplex_sXdY_p1S_MX2,mplex_sXdY_mS_MX2,mplex_sXdY_m1S_MX2
    dd mplex_zXdY_dS_MX2,mplex_zXdY_zS_MX2,mplex_zXdY_pS_MX2,mplex_zXdY_p1S_MX2,mplex_zXdY_mS_MX2,mplex_zXdY_m1S_MX2
    dd mplex_dXsY_dS_MX2,mplex_dXsY_zS_MX2,mplex_dXsY_pS_MX2,mplex_dXsY_p1S_MX2,mplex_dXsY_mS_MX2,mplex_dXsY_m1S_MX2
    dd mplex_sXsY_dS_MX2,mplex_sXsY_zS_MX2,mplex_sXsY_pS_MX2,mplex_sXsY_p1S_MX2,mplex_sXsY_mS_MX2,mplex_sXsY_m1S_MX2
    dd mplex_zXsY_dS_MX2,mplex_zXsY_zS_MX2,mplex_zXsY_pS_MX2,mplex_zXsY_p1S_MX2,mplex_zXsY_mS_MX2,mplex_zXsY_m1S_MX2
    dd mplex_dXzY_dS_MX2,mplex_dXzY_zS_MX2,mplex_dXzY_pS_MX2,mplex_dXzY_p1S_MX2,mplex_dXzY_mS_MX2,mplex_dXzY_m1S_MX2
    dd mplex_sXzY_dS_MX2,mplex_sXzY_zS_MX2,mplex_sXzY_pS_MX2,mplex_sXzY_p1S_MX2,mplex_sXzY_mS_MX2,mplex_sXzY_m1S_MX2
    dd mplex_zXzY_dS_MX2,mplex_zXzY_zS_MX2,mplex_zXzY_pS_MX2,mplex_zXzY_p1S_MX2,mplex_zXzY_mS_MX2,mplex_zXzY_m1S_MX2




    ;// clarity macros

    MPLEX_X     TEXTEQU <([edi+ecx])>
    MPLEX_Y     TEXTEQU <([ebp+ecx])>
    MPLEX_S     TEXTEQU <([ebx+ecx])>

    MPLEX_Z     TEXTEQU <([esi+ecx].data_z)>

    ADVANCE     TEXTEQU <add ecx, 4>
    DONE_YET    TEXTEQU <cmp ecx, SAMARY_SIZE>
    CALC_EXIT   TEXTEQU <jmp mplex_calc_done>



IFDEF DEBUGBUILD

.DATA

    debug_counter dd 0

ENDIF


.CODE


ASSUME_AND_ALIGN
mplex_Calc PROC uses ebp

        ASSUME esi:PTR OSC_MAP

        xor ebx, ebx
        xor edi, edi
        xor ebp, ebp
        xor edx, edx
        xor ecx, ecx

    ;// set up x pin

        OR_GET_PIN [esi].pin_x.pPin, edi
        .IF ZERO?
            mov edi, math_pNullPin
        .ENDIF

        test [edi].dwStatus, PIN_CHANGING
        mov edi, [edi].pData
        ASSUME edi:PTR DWORD
        jnz @F
        add edx, 6
        cmp [edi], ecx
        jnz @F
        add edx, 6

        @@:

    ;// set up y pin

        OR_GET_PIN [esi].pin_y.pPin, ebp
        .IF ZERO?
            mov ebp, math_pNullPin
        .ENDIF
        test [ebp].dwStatus, PIN_CHANGING
        mov ebp, [ebp].pData
        ASSUME ebp:PTR DWORD
        jnz @F
        add edx, 18
        cmp [ebp], ecx
        jnz @F
        add edx, 18
        @@:

    ;// setup the S pin

        OR_GET_PIN [esi].pin_s.pPin, ebx    ;// get s's connection
        .IF ZERO?
            mov ebx, math_pNullPin
        .ENDIF

        test [ebx].dwStatus, PIN_CHANGING
        mov ebx, [ebx].pData
        ASSUME ebx:PTR DWORD
        jnz s_is_ready_now  ;// edx = 0 dS

        fld [ebx]       ;// load the first value
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

        test [esi].dwUser, MPLEX_XFADE OR MPLEX_XFADE2
        jz mode_is_ready
        add edx, 54
        test [esi].dwUser, MPLEX_XFADE2
        jz mode_is_ready
        add edx, 54

    mode_is_ready:

    ;// make sure the data pointer is correct

        lea eax, [esi].data_z
        mov [esi].pin_z.pData, eax

    ;// ready to jump

    IFDEF DEBUGBUILD
        inc debug_counter
    ENDIF

        jmp mplex_calc_jump[edx*4]

    ;// return here

    ALIGN 16
    mplex_calc_done::

    ;// take care of pin changing

        and [esi].pin_z.dwStatus, NOT PIN_CHANGING
        .IF edx
            or [esi].pin_z.dwStatus, PIN_CHANGING
        .ENDIF

    ;// take care of the graphic

        xor eax, eax
        or eax, [esi].dwHintOsc     ;// onscreen is hintosc sign bit
        .IF SIGN?                   ;// don't bother if offscreen

            ;// dtermine the index we want to use
            ;//
            ;// the psource table is arragnged:   1/6   1/2   5/6
            ;//                                 0     1     2     3

            xor eax, eax
            xor ecx, ecx
            xor edx, edx            ;// edx ends up as the index

            OSC_TO_PIN_INDEX esi,ebx,2  ;// selector pin
            test [esi].dwUser, MPLEX_XFADE OR MPLEX_XFADE2
            GET_PIN [ebx].pPin, ebx     ;// get the connection
            .IF !ZERO?
                add edx, 8              ;// add 8 if we're a xfader
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

            mov edx, mplex_source_list[edx*4]   ;// load the desired source

            .IF edx != [esi].pSource        ;// same as current ?
                mov [esi].pSource, edx      ;// set a new source
                invoke play_Invalidate_osc  ;// schedule for redraw
            .ENDIF

        .ENDIF

    ;// thats it


        ret

mplex_Calc ENDP


;////////////////////////////////////




;// store zero, no changing
ALIGN 16
mplex_dXdY_zS_MD:
mplex_sXdY_zS_MD:
mplex_zXdY_zS_MD:
mplex_zXdY_pS_MD:
mplex_zXdY_p1S_MD:
mplex_dXsY_zS_MD:
mplex_sXsY_zS_MD:
mplex_zXsY_zS_MD:
mplex_dXzY_zS_MD:
mplex_sXzY_zS_MD:
mplex_zXzY_zS_MD:
mplex_zXsY_pS_MD:
mplex_zXsY_p1S_MD:
mplex_dXzY_mS_MD:
mplex_dXzY_m1S_MD:
mplex_sXzY_mS_MD:
mplex_sXzY_m1S_MD:
mplex_zXzY_dS_MD:
mplex_zXzY_pS_MD:
mplex_zXzY_p1S_MD:
mplex_zXzY_mS_MD:

mplex_zXzY_m1S_MD:
mplex_zXdY_p1S_MX:
mplex_zXsY_p1S_MX:
mplex_dXzY_m1S_MX:
mplex_sXzY_m1S_MX:
mplex_zXzY_p1S_MX:
mplex_zXzY_m1S_MX:
mplex_zXzY_zS_MX:
mplex_zXzY_dS_MX:
mplex_zXzY_pS_MX:
mplex_zXzY_mS_MX:

mplex_zXzY_dS_MX2:
mplex_zXzY_zS_MX2:
mplex_zXzY_pS_MX2:
mplex_zXzY_mS_MX2:
mplex_zXdY_p1S_MX2:
mplex_zXsY_p1S_MX2:
mplex_zXzY_p1S_MX2:
mplex_dXzY_m1S_MX2:
mplex_sXzY_m1S_MX2:
mplex_zXzY_m1S_MX2:

    mov eax, math_pNull
    xor edx, edx
    mov [esi].pin_z.pData, eax
    CALC_EXIT

;// store X, no changing
ALIGN 16
mplex_sXdY_p1S_MD:
mplex_sXsY_p1S_MD:
mplex_sXzY_p1S_MD:

mplex_sXdY_p1S_MX:
mplex_sXsY_p1S_MX:
mplex_sXzY_p1S_MX:
mplex_sXzY_zS_MX:
mplex_sXzY_pS_MX:

mplex_sXdY_p1S_MX2:
mplex_sXsY_p1S_MX2:
mplex_sXzY_p1S_MX2:

    mov [esi].pin_z.pData, edi
    xor edx, edx
    CALC_EXIT

;// store X, changing
ALIGN 16
mplex_dXdY_p1S_MD:
mplex_dXsY_p1S_MD:
mplex_dXzY_p1S_MD:

mplex_dXdY_p1S_MX:
mplex_dXsY_p1S_MX:
mplex_dXzY_p1S_MX:
mplex_dXzY_zS_MX:
mplex_dXzY_pS_MX:

mplex_dXdY_p1S_MX2:
mplex_dXsY_p1S_MX2:
mplex_dXzY_p1S_MX2:

    mov [esi].pin_z.pData, edi
    or edx, 1
    CALC_EXIT

;// scale X, no changing
ALIGN 16
mplex_sXdY_pS_MD:
mplex_sXsY_pS_MD:
mplex_sXzY_pS_MD:

    fld [edi]
    fld [ebx]
    fmul
    fstp [esi].data_z
    call mplex_fill_z
    xor edx, edx
    CALC_EXIT

;// scale X, changing
ALIGN 16
mplex_dXdY_pS_MD:
mplex_dXsY_pS_MD:
mplex_dXzY_pS_MD:

    push esi
    add esi, OFFSET OSC_MAP.data_z
    xchg esi, edi
    invoke math_mul_dXsA
    pop esi
    or edx, 1
    CALC_EXIT

;// store Y, no changing
ALIGN 16
mplex_dXsY_m1S_MD:
mplex_sXsY_m1S_MD:
mplex_zXsY_m1S_MD:

mplex_dXsY_m1S_MX:
mplex_sXsY_m1S_MX:
mplex_zXsY_m1S_MX:
mplex_zXsY_zS_MX:
mplex_zXsY_mS_MX:

mplex_dXsY_m1S_MX2:
mplex_sXsY_m1S_MX2:
mplex_zXsY_m1S_MX2:

    mov [esi].pin_z.pData, ebp
    xor edx, edx
    CALC_EXIT

;// store Y, changing
ALIGN 16
mplex_dXdY_m1S_MD:
mplex_sXdY_m1S_MD:
mplex_zXdY_m1S_MD:

mplex_dXdY_m1S_MX:
mplex_sXdY_m1S_MX:
mplex_zXdY_m1S_MX:
mplex_zXdY_zS_MX:
mplex_zXdY_mS_MX:

mplex_dXdY_m1S_MX2:
mplex_sXdY_m1S_MX2:
mplex_zXdY_m1S_MX2:

    mov [esi].pin_z.pData, ebp
    or edx, 1
    CALC_EXIT

;// scale Y, no changing
ALIGN 16
mplex_dXsY_mS_MD:
mplex_sXsY_mS_MD:
mplex_zXsY_mS_MD:

    fld [ebp]
    fld [ebx]
    fmul
    fchs
    fstp [esi].data_z
    call mplex_fill_z
    xor edx, edx
    CALC_EXIT

;// scale Y, changing
ALIGN 16
mplex_dXdY_mS_MD:
mplex_sXdY_mS_MD:
mplex_zXdY_mS_MD:

    push esi
    mov edi, ebp
    add esi, OFFSET OSC_MAP.data_z
    xchg esi, edi
    invoke math_mul_dXsA_neg
    pop esi
    or edx, 1
    CALC_EXIT

;////////////////////////////////////

ALIGN 16
mplex_dXdY_dS_MD PROC

        xor eax, eax
        or edx, 1

    ALIGN 16
    top_of_loop:

        or eax, MPLEX_S
        jz is_zero
        fld MPLEX_S
        js is_neg

    is_pos:

        fld MPLEX_X
        fmul
        xor eax, eax
        fstp MPLEX_Z

        ADVANCE
        DONE_YET
        jb top_of_loop
        CALC_EXIT

    ALIGN 16
    is_neg:

        fld MPLEX_Y
        fmul
        xor eax, eax
        fchs
        fstp MPLEX_Z

        ADVANCE
        DONE_YET
        jb top_of_loop
        CALC_EXIT

    ALIGN 16
    is_zero:

        mov MPLEX_Z, eax
        ADVANCE
        DONE_YET
        jb top_of_loop
        CALC_EXIT

mplex_dXdY_dS_MD ENDP


ALIGN 16
mplex_sXdY_dS_MD PROC

    fld [edi]
    or edx, 1

    ALIGN 16
    top_of_loop:

        or eax, MPLEX_S
        jz is_zero
        fld MPLEX_S
        js is_neg

    is_pos:

        fmul st, st(1)
        jmp bottom_of_loop

    ALIGN 16
    is_neg:

        fld MPLEX_Y
        fchs
        fmul
        jmp bottom_of_loop

    ALIGN 16
    is_zero:

        fldz

    ALIGN 16
    bottom_of_loop:

        fstp MPLEX_Z
        xor eax, eax

        ADVANCE
        DONE_YET
        jb top_of_loop
        fstp st
        CALC_EXIT

mplex_sXdY_dS_MD ENDP

ALIGN 16
mplex_dXsY_dS_MD PROC

    fld [ebp]
    or edx, 1
    fchs

    ALIGN 16
    top_of_loop:

        or eax, MPLEX_S
        jz is_zero
        fld MPLEX_S
        js is_neg

    is_pos:

        fld MPLEX_X
        fmul
        jmp bottom_of_loop

    ALIGN 16
    is_neg:

        fmul st, st(1)
        jmp bottom_of_loop

    ALIGN 16
    is_zero:

        fldz

    ALIGN 16
    bottom_of_loop:

        fstp MPLEX_Z
        xor eax, eax

        ADVANCE
        DONE_YET
        jb top_of_loop
        fstp st
        CALC_EXIT

mplex_dXsY_dS_MD ENDP

ALIGN 16
mplex_zXdY_dS_MD PROC

        xor eax, eax

        xor edx, edx

        ;// if S is pos, store zero

    ALIGN 16
    top_of_loop:

        or eax, MPLEX_S
        jns is_pos

    is_neg:

        fld MPLEX_Y
        fchs
        fld MPLEX_S
        fmul
        inc edx

        jmp bottom_of_loop

    is_pos:

        fldz

    bottom_of_loop:

        fstp MPLEX_Z
        xor eax, eax

        ADVANCE
        DONE_YET
        jb top_of_loop
        CALC_EXIT


mplex_zXdY_dS_MD ENDP

ALIGN 16
mplex_sXsY_dS_MD PROC

        fld [ebp]
        or edx, 1
        fchs
        fld [edi]

    top_of_loop:

        or eax, MPLEX_S
        jz is_zero
        fld MPLEX_S
        js is_neg

    is_pos:

        fmul st, st(1)
        jmp bottom_of_loop

    is_neg:

        fmul st, st(2)
        jmp bottom_of_loop

    is_zero:

        fldz

    bottom_of_loop:

        fstp MPLEX_Z
        xor eax, eax

        ADVANCE
        DONE_YET
        jb top_of_loop

        fstp st
        fstp st

        CALC_EXIT

mplex_sXsY_dS_MD ENDP

ALIGN 16
mplex_zXsY_dS_MD PROC

        fld [ebp]
        xor eax, eax
        xor edx, edx
        fchs

    top_of_loop:

        or eax, MPLEX_S
        jns is_pos

    is_neg:

        fld MPLEX_S
        fmul st, st(1)
        inc edx
        jmp bottom_of_loop

    is_pos:

        fldz

    bottom_of_loop:

        fstp MPLEX_Z
        xor eax, eax

        ADVANCE
        DONE_YET
        jb top_of_loop

        fstp st
        CALC_EXIT

mplex_zXsY_dS_MD ENDP

ALIGN 16
mplex_dXzY_dS_MD PROC


        xor eax, eax
        xor edx, edx

        ;// if S is neg, store zero

    ALIGN 16
    top_of_loop:

        or eax, MPLEX_S
        jz is_neg
        js is_neg

    is_pos:

        fld MPLEX_S
        fld MPLEX_X
        fmul
        xor eax, eax
        inc edx
        fstp MPLEX_Z

        ADVANCE
        DONE_YET
        jb top_of_loop
        CALC_EXIT

    ALIGN 16
    is_neg:

        xor eax, eax
        mov MPLEX_Z, eax
        ADVANCE
        DONE_YET
        jb top_of_loop
        CALC_EXIT

mplex_dXzY_dS_MD ENDP

ALIGN 16
mplex_sXzY_dS_MD PROC

        fld [edi]
        xor eax, eax
        xor edx, edx

    top_of_loop:

        or eax, MPLEX_S
        jz is_zero
        js is_neg

    is_pos:

        fld MPLEX_S
        fmul st, st(1)
        inc edx
        jmp bottom_of_loop

    is_zero:
    is_neg:

        fldz

    bottom_of_loop:

        fstp MPLEX_Z
        xor eax, eax

        ADVANCE
        DONE_YET
        jb top_of_loop

        fstp st
        CALC_EXIT

mplex_sXzY_dS_MD ENDP

;////////////////////////////////////


;// add X Y changing
ALIGN 16
mplex_dXdY_zS_MX:

    push esi
    add esi, OFFSET OSC_MAP.data_z

    mov edx, ebp
    xchg esi, edi

    invoke math_add_dXdB

    pop esi
    or edx, 1

    CALC_EXIT


;// add X Y one changing
ALIGN 16
mplex_sXdY_zS_MX:

    push esi

    mov edx, edi
    add esi, OFFSET OSC_MAP.data_z
    mov edi, esi
    mov esi, ebp

    invoke math_add_dXsB

    pop esi
    or edx, 1

    CALC_EXIT


ALIGN 16
mplex_dXsY_zS_MX:

    push esi
    add esi, OFFSET OSC_MAP.data_z

    mov edx, ebp
    xchg esi, edi

    invoke math_add_dXsB

    pop esi
    or edx, 1

    CALC_EXIT


;// add X Y no changing
ALIGN 16
mplex_sXsY_zS_MX:

    fld MPLEX_X
    fld MPLEX_Y
    fadd
    fstp MPLEX_Z

    call mplex_fill_z

    xor edx, edx
    CALC_EXIT




ALIGN 16
mplex_sXdY_dS_MX PROC

    ;// S > 0 ? Z = sX + dY * (1-S)
    ;// S < 0 ? Z = dY + sX * (1+S)
    ;// S = 0 ? Z = dY+sX

        fld1
        fld MPLEX_X     ;// sX      1
        xor eax, eax

    ALIGN 16
    top_of_loop:

        or eax, MPLEX_S
        fld MPLEX_Y
        jz is_zero
        fld MPLEX_S
        js is_neg

    is_pos: ;// S   Y   sX  1

        fsubr st, st(3) ;// 1-S Y   sX  1
        fmul
        jmp is_zero

    ALIGN 16
    is_neg: ;// S   Y   sX  1   ;// dY + sX + sX*S

        fmul st, st(2)
        fadd

    ALIGN 16
    is_zero:

        fadd st, st(1)

        xor eax, eax
        fstp MPLEX_Z

        ADVANCE
        DONE_YET
        jb top_of_loop

        fstp st
        or edx, 1
        fstp st
        CALC_EXIT

mplex_sXdY_dS_MX ENDP

ALIGN 16
mplex_dXsY_dS_MX PROC

    ;// S > 0 ? Z = dX + sY*(1-S)
    ;// S < 0 ? Z = sY + dX*(1+S)

        fld1
        fld MPLEX_Y
        xor eax, eax

    ALIGN 16
    top_of_loop:

        or eax, MPLEX_S
        fld MPLEX_X
        jz is_zero
        fld MPLEX_S
        js is_neg

    is_pos:     ;// dS  dX  sY  1

                ;// dX + sY - sY * dS

        fmul st, st(2)  ;// dS*sY   dX  sY  1
        fsub            ;// dX-dS*sY sY 1
        jmp is_zero

    is_neg:     ;// dS  dX  sY  1

        fadd st, st(3)
        fmul

    is_zero:

        fadd st, st(1)
        xor eax, eax
        fstp MPLEX_Z
        ADVANCE
        DONE_YET
        jb top_of_loop

        fstp st
        or edx, 1
        fstp st
        CALC_EXIT

mplex_dXsY_dS_MX ENDP




ALIGN 16
mplex_sXsY_dS_MX PROC

    ;// S > 0 ? Z = (X+Y) - S*Y
    ;// S < 0 ? Z = (X+Y) + S*X

        fld MPLEX_Y     ;// Y
        fchs            ;// -Y
        fld MPLEX_X     ;// X   -Y
        fld st(1)       ;// -Y  X   -Y
        fsubr st, st(1) ;// X+Y X   -Y

        xor eax, eax

    ALIGN 16
    top_of_loop:

        or eax, MPLEX_S
        fld MPLEX_S
        jz is_zero
        js is_neg

    is_pos: ;// S   X+Y X   -Y

        fmul st, st(3)
        jmp bottom_of_loop

    is_neg: ;// S   X+Y X   -Y

        fmul st, st(2)

    bottom_of_loop:

        fadd st, st(1)

    is_zero:

        fstp MPLEX_Z
        xor eax, eax
        ADVANCE
        DONE_YET
        jb top_of_loop

        fstp st
        or edx, 1
        fstp st
        fstp st

        CALC_EXIT


mplex_sXsY_dS_MX ENDP


ALIGN 16
mplex_zXdY_dS_MX PROC

    ;// S > 0 ? Z = dY * (1-dS) = dY - dY*dS
    ;// S < 0 ? Z = dY

        xor eax, eax

    top_of_loop:

        or eax, MPLEX_S
        fld MPLEX_Y
        jz is_neg
        js is_neg

    is_pos:

        fld MPLEX_S
        fmul st, st(1)  ;// dS*dY   dY
        fsub

    is_neg:

        fstp MPLEX_Z
        xor eax, eax
        ADVANCE
        DONE_YET
        jb top_of_loop
        or edx, 1
        CALC_EXIT

mplex_zXdY_dS_MX ENDP

ALIGN 16
mplex_dXzY_dS_MX PROC

    ;// S > 0 ? Z = dX
    ;// S < 0 ? Z = dX * (1+dS)


        xor eax, eax

    top_of_loop:

        or eax, MPLEX_S
        fld MPLEX_X
        jz  is_pos
        jns is_pos

    is_neg:

        fld MPLEX_S
        fmul st, st(1)  ;// dS*dX   dX
        fadd

    is_pos:

        fstp MPLEX_Z
        xor eax, eax
        ADVANCE
        DONE_YET
        jb top_of_loop
        or edx, 1
        CALC_EXIT

mplex_dXzY_dS_MX ENDP

ALIGN 16
mplex_zXsY_dS_MX PROC

    ;// S > 0 ? Z = sY - sY*dS
    ;// S < 0 ? Z = sY

        fld MPLEX_Y
        xor eax, eax
        xor edx, edx

    ALIGN 16
    top_of_loop:

        or eax, MPLEX_S
        jz is_neg
        js is_neg

    is_pos:

        fld MPLEX_S     ;// dS      sY
        fmul st, st(1)  ;// dS*sY   sY
        inc edx
        fsubr st, st(1) ;//
        xor eax, eax
        fstp MPLEX_Z
        ADVANCE
        DONE_YET
        jb top_of_loop

        fstp st

        CALC_EXIT

    ALIGN 16
    is_neg:

        fst MPLEX_Z
        ADVANCE
        xor eax, eax
        DONE_YET
        jb top_of_loop

        fstp st

        CALC_EXIT

mplex_zXsY_dS_MX ENDP

ALIGN 16
mplex_sXzY_dS_MX PROC

    ;// S > 0 ? Z = sX
    ;// S < 0 ? Z = sX * (1+S)

        fld MPLEX_X
        xor eax, eax
        xor edx, edx

    ALIGN 16
    top_of_loop:

        or eax, MPLEX_S
        jz is_neg
        js is_neg

    is_pos:

        fst MPLEX_Z
        ADVANCE
        xor eax, eax
        DONE_YET
        jb top_of_loop

        fstp st

        CALC_EXIT

    ALIGN 16
    is_neg:

        fld MPLEX_S     ;// dS      sX
        fmul st, st(1)  ;// dS*sY   sX
        inc edx
        fadd st, st(1)  ;//

        fstp MPLEX_Z
        ADVANCE
        xor eax, eax
        DONE_YET
        jb top_of_loop

        fstp st

        CALC_EXIT

mplex_sXzY_dS_MX ENDP





ALIGN 16
mplex_dXdY_dS_MX PROC

    ;// S > 0 ? Z = X+Y - S*Y
    ;// S < 0 ? Z = X+Y + S*X
    ;// S = 0 ? Z = X + Y

        xor eax, eax

    ALIGN 16
    top_of_loop:

        or eax, MPLEX_S
        fld MPLEX_Y
        fld MPLEX_X
        jz is_zero
        fld MPLEX_S
        js is_neg

    is_pos:             ;// Z = X+Y - S*Y

        fchs            ;// -S  X   Y
        fmul st, st(2)  ;// SY  X   Y
        fxch
        faddp st(2), st ;// X   SY  Y
        jmp is_zero     ;// SY  X+Y

    ALIGN 16
    is_neg:             ;// Z = X+Y + S*X

        fmul st, st(1)  ;// SX  X   Y
        fxch st(2)      ;// Y   X   SX
        fadd            ;// Y+X

    ALIGN 16
    is_zero:

        fadd
        xor eax, eax
        fstp MPLEX_Z
        ADVANCE
        DONE_YET
        jb top_of_loop

        or edx, 1
        CALC_EXIT

mplex_dXdY_dS_MX ENDP




ALIGN 16
mplex_dXdY_pS_MX:

    ;//     edi   esp  ebp
    ;// Z = dX + (1-S)*dY
    ;//     edx   ebx  esi

    push esi
    push eax

    fld1
    fsub MPLEX_S
    fstp DWORD PTR [esp]

    add esi, OFFSET OSC_MAP.data_z

    mov edx, edi    ;// dB
    mov edi, esi    ;// dest
    mov esi, ebp    ;// dX
    mov ebx, esp    ;// sA

    invoke math_muladd_dXsAdB

    pop eax
    or edx, 1
    pop esi
    CALC_EXIT



ALIGN 16
mplex_dXdY_mS_MX PROC

    ;//     ebp   esp  edi
    ;// Z = dY + (1+S)*dX
    ;//     edx   ebx  esi

    fld1
    push esi
    fadd MPLEX_S
    mov edx, ebp    ;// dB
    push eax
    add esi, OFFSET OSC_MAP.data_z

    fstp DWORD PTR [esp]

    mov ebx, esp    ;// sA
    xchg esi, edi   ;// dX

    invoke math_muladd_dXsAdB

    pop eax
    or edx, 1
    pop esi
    CALC_EXIT

mplex_dXdY_mS_MX ENDP






ALIGN 16
mplex_sXdY_pS_MX:

    ;//     edi  esp    ebp
    ;// Z = sX + (1-S)*dY
    ;//     edx  ebx    esi

    fld MPLEX_S
    fld1
    fsub

    push esi
    push eax
    add esi, OFFSET OSC_MAP.data_z

    fstp DWORD PTR [esp]

    mov edx, edi    ;// sX
    mov edi, esi    ;// dest
    mov esi, ebp    ;// dY
    mov ebx, esp    ;// sA

    invoke math_muladd_dXsAsB

    pop eax
    or edx, 1
    pop esi
    CALC_EXIT




ALIGN 16
mplex_dXsY_pS_MX:

    ;//     edi     esp
    ;// Z = dX + (1-S)*sY
    ;//     esi     edx

    fld1
    fsub MPLEX_S
    push esi
    fmul MPLEX_Y

    push eax
    add esi, OFFSET OSC_MAP.data_z
    xchg esi, edi

    fstp DWORD PTR [esp]

    mov edx, esp

    invoke math_add_dXsB

    pop eax
    pop esi
    or edx, 1

    CALC_EXIT



ALIGN 16
mplex_sXdY_mS_MX:

    ;//     ebp    esp
    ;// Z = dY + (1+S)*sX
    ;//     esi    edx

    fld1
    fadd MPLEX_S
    push esi
    fmul MPLEX_Y

    push eax
    add esi, OFFSET OSC_MAP.data_z

    mov edi, esi
    mov edx, esp
    mov esi, ebp

    fstp DWORD PTR [esp]

    invoke math_add_dXsB

    pop eax
    pop esi
    or edx, 1

    CALC_EXIT


ALIGN 16
mplex_dXsY_mS_MX:

    ;//     ebp   esp  edi
    ;// Z = sY + (1+S)*dX
    ;//     edx   ebx  esi

    fld1
    push esi
    fadd MPLEX_S
    push eax
    fstp DWORD PTR [esp]

    mov ebx, esp
    add esi, OFFSET OSC_MAP.data_z
    xchg esi, edi
    mov edx, ebp

    invoke math_muladd_dXsAsB

    pop eax
    or edx, 1
    pop esi
    CALC_EXIT



ALIGN 16
mplex_dXzY_mS_MX:

    ;//     edi   esp
    ;// Z = dX * (1+S)
    ;//     esi   ebx

    fld1
    push esi
    fadd MPLEX_S
    push eax
    add esi, OFFSET OSC_MAP.data_z
    xchg esi, edi
    fstp DWORD PTR [esp]
    mov ebx, esp

    invoke math_mul_dXsA

    pop eax
    pop esi

    or edx, 1
    CALC_EXIT



ALIGN 16
mplex_zXdY_pS_MX:

    ;//     ebp   esp
    ;// Z = dY * (1-S)
    ;//     esi   ebx

    fld1
    push esi
    fsub MPLEX_S
    push eax
    lea edi, [esi].data_z
    fstp DWORD PTR [esp]

    mov esi, ebp
    mov ebx, esp

    invoke math_mul_dXsA

    pop eax
    or edx, 1
    pop esi
    CALC_EXIT




ALIGN 16
mplex_sXsY_pS_MX:

    ;// Z = X+Y - S*Y

    fld MPLEX_X
    fld MPLEX_Y
    fadd st(1), st  ;// Y   X+Y
    fld MPLEX_S     ;// S   Y   X+Y
    fmul            ;// S*Y X+Y
    fsub
    fstp MPLEX_Z
    call mplex_fill_z
    xor edx, edx
    CALC_EXIT




ALIGN 16
mplex_sXsY_mS_MX:

    ;// Z = X+Y + S*X

    fld MPLEX_X
    fld MPLEX_Y
    fadd st, st(1)  ;// X+Y     X
    fld MPLEX_S
    fmulp st(2), st
    fadd
    fstp MPLEX_Z
    call mplex_fill_z
    xor edx, edx
    CALC_EXIT



ALIGN 16
mplex_zXsY_pS_MX:

    ;// Z = Y - S*Y

    fld MPLEX_Y
    fld MPLEX_S
    fmul st, st(1)
    fsub
    fstp MPLEX_Z
    call mplex_fill_z
    xor edx, edx
    CALC_EXIT



ALIGN 16
mplex_sXzY_mS_MX:

    ;// Z = X + S*X

    fld MPLEX_X
    fld MPLEX_S
    fmul st, st(1)
    fadd
    fstp MPLEX_Z
    call mplex_fill_z
    xor edx, edx
    CALC_EXIT





;////////////////////////////////////


;// Z = 1/2(1+S)*X + 1/2(1-S)*Y

;// Z = 1/2(X+Y+S(X-Y))

ALIGN 16
mplex_sXdY_dS_MX2:
mplex_dXsY_dS_MX2:
mplex_dXdY_dS_MX2:

        fld math_1_2

        .REPEAT

            fld MPLEX_Y
            fld MPLEX_X
            fld MPLEX_S     ;// S       X       Y       1/2

            fld st(2)       ;// Y       S       X       Y       1/2
            fsubr st, st(2) ;// X-Y     S       X       Y       1/2

            fxch st(3)      ;// Y       S       X       X-Y     1/2
            faddp st(2), st ;// S       X+Y     X-Y     1/2
            fmulp st(2), st ;// X+Y     S(X-y)  1/2
            fadd
            fmul st, st(1)
            fstp MPLEX_Z

            ADVANCE
            DONE_YET

        .UNTIL !CARRY?


        fstp st
        or edx, 1
        CALC_EXIT



;// Z = 1/2(1+S)*X + 1/2(1-S)*Y
;//         S1          S2

ALIGN 16
mplex_dXdY_pS_MX2:
mplex_dXdY_mS_MX2:

        fld1
        fld math_1_2
        fld MPLEX_S

        fld st          ;// S       S       1/2     1
        fadd st, st(3)  ;// 1+S     S       1/2     1
        fxch            ;// S       1+S     1/2     1
        fsubp st(3), st ;// 1+S     1/2     1-S
        fxch            ;// 1/2     1+S     1-S
        fmul st(1), st  ;// 1/2     S1      1-S
        fmulp st(2), st ;// S1      S2

    .REPEAT ;// two at a time

        fld MPLEX_Y     ;// Y1      S1      S2
        fmul st, st(2)  ;// Y1*S2   S1      S2
        fld MPLEX_X     ;// X       Y1*S2   S1      S2
        fmul st, st(2)  ;// X1*S1   Y1*S2   S1      S2

        fld MPLEX_Y[4]  ;// Y2      X1*S1   Y1*S2   S1      S2
        fmul st, st(4)  ;// Y2*S2   X1*S1   Y1*S2   S1      S2
        fld MPLEX_X[4]  ;// X2      Y2*S2   X1*S1   Y1*S2   S1      S2
        fmul st, st(4)  ;// X2*S1   Y2*S2   X1*S1   Y1*S2   S1      S2

        fxch st(3)      ;// Y1*S2   Y2*S2   X1*S1   X2*S1   S1      S2
        faddp st(2), st ;// Y2*S2   Z1      X2*S1   S1      S2
        faddp st(2), st ;// Z1      Z2      S1      S2

        fstp MPLEX_Z
        add ecx, 4
        fstp MPLEX_Z
        add ecx, 4

        DONE_YET

    .UNTIL !CARRY?

        fstp st
        or edx, 1
        fstp st

        CALC_EXIT



ALIGN 16
mplex_sXdY_pS_MX2:
mplex_sXdY_mS_MX2:

;//        esp         esp4     ebp
;// Z = 1/2(1+S)*X + 1/2(1-S) * Y
;//        edx         ebx      esi

    fld1
    fsub MPLEX_S
    fmul math_1_2

    fld1
    fadd MPLEX_S
    fmul math_1_2
    fmul MPLEX_X

    push esi
    push eax
    fxch
    fstp DWORD PTR [esp]
    push eax
    fstp DWORD PTR [esp]

    lea edi, [esi].data_z
    mov edx, esp
    lea ebx, [esp+4]
    mov esi, ebp

    invoke math_muladd_dXsAsB

    add esp, 8
    or edx, 1
    pop esi
    CALC_EXIT












ALIGN 16
mplex_dXsY_pS_MX2:
mplex_dXsY_mS_MX2:
;// Z = 1/2(1+S)*X + 1/2(1-S)*Y

;//     esp         esp+4    edi
;// 1/2(1-S)*Y  + 1/2(1+S) * X
;//     edx         ebx      esi

    fld1
    fadd MPLEX_S
    fmul math_1_2

    fld1
    fsub MPLEX_S
    fmul math_1_2
    fmul MPLEX_Y

    push esi
    push eax
    fxch
    fstp DWORD PTR [esp]
    push eax
    fstp DWORD PTR [esp]

    add esi, OFFSET OSC_MAP.data_z
    mov edx, esp
    lea ebx, [esp+4]
    xchg esi, edi

    invoke math_muladd_dXsAsB

    add esp, 8
    or edx, 1
    pop esi
    CALC_EXIT





ALIGN 16
mplex_sXsY_dS_MX2:
;// Z = 1/2(1+S)*X + 1/2(1-S)*Y

;// esp   esp[4]  ebx
;// X+Y + (X-Y) * S
;// edx    ebx    esi

    ;//ABOX237 x and y were swapped!!
    comment ~ /*
    fld MPLEX_Y
    fsub MPLEX_X
    fmul math_1_2
    fld MPLEX_Y
    fadd MPLEX_X
    fmul math_1_2
    */ comment ~

    fld MPLEX_X
    fsub MPLEX_Y
    fmul math_1_2
    fld MPLEX_X
    fadd MPLEX_Y
    fmul math_1_2


    push esi
    fxch
    push eax
    fstp DWORD PTR [esp]
    push eax
    fstp DWORD PTR [esp]

    lea edi, [esi].data_z
    mov edx, esp
    mov esi, ebx
    lea ebx, [esp+4]

    invoke math_muladd_dXsAsB

    add esp, 8
    pop esi
    or edx, 1
    CALC_EXIT






ALIGN 16
mplex_sXsY_pS_MX2:
mplex_sXsY_mS_MX2:
;// Z = 1/2(1+S)*X + 1/2(1-S)*Y

    ;// X+Y+S(X-Y))1/2

    fld MPLEX_X
    fsub MPLEX_Y
    fmul MPLEX_S
    fadd MPLEX_Y
    fadd MPLEX_X
    fmul math_1_2
    fstp MPLEX_Z
    call mplex_fill_z
    xor edx, edx
    CALC_EXIT


ALIGN 16
mplex_sXzY_pS_MX2:
mplex_sXzY_mS_MX2:
;// Z = 1/2(1+S)*X

    fld math_1_2
    fld MPLEX_S
    fadd math_1
    fmul
    fmul MPLEX_X
    fstp MPLEX_Z
    call mplex_fill_z
    xor edx, edx
    CALC_EXIT

ALIGN 16
mplex_zXsY_pS_MX2:
mplex_zXsY_mS_MX2:
;// Z = 1/2(1-S)*Y

    fld math_1_2
    fld1
    fsub MPLEX_S
    fmul MPLEX_Y
    fmul
    fstp MPLEX_Z

    call mplex_fill_z
    xor edx, edx
    CALC_EXIT






ALIGN 16
mplex_dXzY_dS_MX2:

;// Z = 1/2(1+S)*X

    fld math_1_2
    fld1

    .REPEAT

        fld MPLEX_X     ;// X1      1       1/2
        fmul st, st(2)  ;// 1/2X1   1       1/2
        fld MPLEX_S     ;// S1      1/2X1   1       1/2
        fadd st, st(2)  ;// 1+S1    1/2X1   1       1/2

        fld MPLEX_X[4]  ;// X2      1+S1    1/2X1   1       1/2
        fmul st, st(4)  ;// 1/2X2   1+S1    1/2X1   1       1/2
        fld MPLEX_S[4]  ;// S2      1/2X2   1+S1    1/2X1   1       1/2
        fadd st, st(4)  ;// S2+1    1/2X2   1+S1    1/2X1   1       1/2
        fxch st(3)      ;// 1/2X1   1/2X2   1+S1    S2+1    1       1/2

        fmulp st(2), st ;// 1/2X2   Z1      S2+1    1       1/2
        fmulp st(2), st ;// Z1      Z2      1       1/12

        fstp MPLEX_Z
        add ecx, 4
        fstp MPLEX_Z
        add ecx, 4

        DONE_YET

    .UNTIL !CARRY?

    fstp st
    or edx, 1
    fstp st
    CALC_EXIT

ALIGN 16
mplex_zXdY_dS_MX2:
;// Z = 1/2(1-S)*Y

    fld math_1_2
    fld1

    .REPEAT

        fld MPLEX_Y     ;// Y1      1       1/2
        fmul st, st(2)  ;// 1/2Y1   1       1/2
        fld MPLEX_S     ;// S1      1/2Y1   1       1/2
        fsubr st, st(2) ;// 1-S1    1/2Y1   1       1/2

        fld MPLEX_Y[4]  ;// Y2      1-S1    1/2Y1   1       1/2
        fmul st, st(4)  ;// 1/2Y2   1-S1    1/2Y1   1       1/2
        fld MPLEX_S[4]  ;// S2      1/2Y2   1-S1    1/2Y1   1       1/2
        fsubr st, st(4) ;// 1-S2    1/2Y2   1-S1    1/2Y1   1       1/2
        fxch st(3)      ;// 1/2Y1   1/2Y2   1-S1    1-S2    1       1/2

        fmulp st(2), st ;// 1/2Y2   Z1      1-S2    1       1/2
        fmulp st(2), st ;// Z1      Z2      1       1/12

        fstp MPLEX_Z
        add ecx, 4
        fstp MPLEX_Z
        add ecx, 4

        DONE_YET

    .UNTIL !CARRY?

    fstp st
    or edx, 1
    fstp st
    CALC_EXIT



ALIGN 16
mplex_dXzY_pS_MX2:
mplex_dXzY_mS_MX2:

;//      esp      edi
;// Z = 1/2(1+S) * X
;//      ebx      esi

    push esi
    push eax

    fld math_1_2
    fld1
    fadd MPLEX_S
    add esi, OFFSET OSC_MAP.data_z
    fmul
    xchg esi, edi
    mov ebx, esp
    fstp DWORD PTR [esp]

    invoke math_mul_dXsA

    pop eax
    pop esi
    or edx, 1
    CALC_EXIT

ALIGN 16
mplex_zXdY_pS_MX2:
mplex_zXdY_mS_MX2:
;//       esp      ebp
;// Z = 1/2(1-S) * Y
;//       ebx      esi

    push esi
    push eax

    fld math_1_2
    fld1
    fsub MPLEX_S
    lea edi, [esi].data_z
    fmul
    mov ebx, esp
    mov esi, ebp
    fstp DWORD PTR [esp]

    invoke math_mul_dXsA

    pop eax
    pop esi
    or edx, 1
    CALC_EXIT

ALIGN 16
mplex_sXzY_dS_MX2:
;// Z = 1/2(1+S)*X

;// esp     esp   ebx
;// 1/2*X + 1/2*X * S
;// edx     ebx   esi

    push esi
    push eax

    fld math_1_2
    fmul MPLEX_X
    fstp DWORD PTR [esp]

    lea edi, [esi].data_z
    mov esi, ebx
    mov edx, esp
    mov ebx, esp

    invoke math_muladd_dXsAsB

    pop eax
    pop esi
    or edx, 1
    CALC_EXIT


ALIGN 16
mplex_zXsY_dS_MX2:

;// Z = 1/2(1-S)*Y

;// esp    esp4   ebx
;// 1/2Y - 1/2*Y * S
;// edx    ebx    esi

    push esi
    push eax

    fld math_1_2
    fmul MPLEX_Y
    fchs
    fst DWORD PTR [esp]
    push eax
    fchs
    fstp DWORD PTR [esp]

    lea edi, [esi].data_z
    mov esi, ebx
    mov edx, esp
    lea ebx, [esp+4]

    invoke math_muladd_dXsAsB

    add esp, 8
    or edx, 1
    pop esi
    CALC_EXIT






ALIGN 16
mplex_dXdY_zS_MX2:

;// Z = 1/2*X + 1/2*Y

    fld math_1_2

    .REPEAT

        fld MPLEX_X
        fadd MPLEX_Y

        fld MPLEX_X[4]
        fadd MPLEX_Y[4]

        fld MPLEX_X[8]
        fadd MPLEX_Y[8]

        fld MPLEX_X[0Ch]
        fadd MPLEX_Y[0Ch]   ;// 4   3   2   1   1/2

        fxch st(4)          ;// .5  3   2   1   4
        fmul st(3), st
        fmul st(2), st
        fmul st(1), st
        fmul st(4), st

        fxch st(3)          ;// 1   3   2   .5  4
        fstp MPLEX_Z        ;// 3   2   .5  4
        fxch                ;// 2   3   .5  4
        fstp MPLEX_Z[4]     ;// 3   .5  4
        fstp MPLEX_Z[8]     ;// .5  4
        fxch
        fstp MPLEX_Z[0Ch]

        add ecx, 10h
        DONE_YET

    .UNTIL !CARRY?

    fstp st
    or edx, 1
    CALC_EXIT




ALIGN 16
mplex_sXdY_zS_MX2:

;//      esp         ebp
;// Z = 1/2*sX + 1/2*Y
;//      edx     ebx esi

    push esi
    push eax

    fld math_1_2
    fmul MPLEX_X
    lea ebx, math_1_2
    mov edx, esp
    lea edi, [esi].data_z
    mov esi, ebp

    fstp DWORD PTR [esp]

    invoke math_muladd_dXsAsB

    pop eax
    pop esi
    or edx, 1
    CALC_EXIT


ALIGN 16
mplex_dXsY_zS_MX2:

;//
;// Z = 1/2*X + 1/2*sY
;//     ebx edi esp

    push esi
    push eax

    fld math_1_2
    fmul MPLEX_Y
    lea ebx, math_1_2
    mov edx, esp
    add esi, OFFSET OSC_MAP.data_z
    xchg esi, edi

    fstp DWORD PTR [esp]

    invoke math_muladd_dXsAsB

    pop eax
    pop esi
    or edx, 1
    CALC_EXIT



ALIGN 16
mplex_sXsY_zS_MX2:
;// Z = 1/2*X + 1/2*Y

    fld math_1_2
    fld MPLEX_X
    fadd MPLEX_Y
    fmul
    fstp MPLEX_Z
    call mplex_fill_z
    xor edx, edx
    CALC_EXIT

ALIGN 16
mplex_zXdY_zS_MX2:
;// Z = 1/2*Y

    push esi
    lea edi, [esi].data_z
    lea ebx, math_1_2
    mov esi, ebp
    invoke math_mul_dXsA
    pop esi
    or edx, 1
    CALC_EXIT


ALIGN 16
mplex_dXzY_zS_MX2:
;// Z = 1/2*X

    push esi
    lea ebx, math_1_2
    add esi, OFFSET OSC_MAP.data_z
    xchg esi, edi
    invoke math_mul_dXsA
    pop esi
    or edx, 1
    CALC_EXIT

ALIGN 16
mplex_sXzY_zS_MX2:
;// Z = 1/2(1)*X

    fld math_1_2
    fmul MPLEX_X
    fstp MPLEX_Z
    call mplex_fill_z
    xor edx, edx
    CALC_EXIT

ALIGN 16
mplex_zXsY_zS_MX2:
;// Z = 1/2*Y

    fld math_1_2
    fmul MPLEX_Y
    fstp MPLEX_Z
    call mplex_fill_z
    xor edx, edx
    CALC_EXIT



;///////////////////////////////////////



ALIGN 16
mplex_fill_z PROC

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

mplex_fill_z ENDP







ASSUME_AND_ALIGN

ENDIF   ;// USE_THIS_FILE
END

