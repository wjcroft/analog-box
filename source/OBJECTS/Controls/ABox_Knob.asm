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
;//     ABOX242 AJT -- detabified + text adjustments for 'lines too long' errors
;//
;//##////////////////////////////////////////////////////////////////////////
;//
;//     ABox_Knob.asm       ABox 228    major revisions
;//                                     many of the texts have been removed
;// TOC                     (source code garbage collection)
;// knob_Calc_2             see source code for previous revisions if this is really important
;// knob_PrePlay
;// knob_Ctor

;// knob_Move

;// knob_sync   <-- central function updates all settings

;// knob_GetUnit

;// knob_SetShape
;// knob_Render
;// knob_HitTest
;// knob_Control

;// knob_InitMenu
;// knob_Command

;// knob_SaveUndo
;// knob_LoadUndo

;// xlate_knob_turns




OPTION CASEMAP:NONE

.586
.MODEL FLAT

USE_THIS_FILE EQU 1

IFDEF USE_THIS_FILE

        .NOLIST
        include <Abox.inc>
        include <ABox_Knob.inc>
        .LIST


;//
;// layout parameters, shapes and containers
;//

    ;// there are several shapes used by knobs.
    ;// all of these are assumed to be refenced to the owning objects pDest
    ;// if this is not the case, the object must take of it

    ;// the inside of knob is layed out in two sections
    ;//
    ;// VALUE   the value rectangle
    ;//         where the value is displayed as teext
    ;//         determined by VALUE_HEIGHT
    ;//
    ;// and the control rectangle
    ;//     where the wipers, unit and +/- indicatorees are displayed
    ;//     this area is devided into three concentric circles
    ;//     MASK    is the inside of the track circle
    ;//             a small circle is moved here to cover up the center of the knob
    ;//     TRACK   is the outside of the track circle
    ;//     HOVER   is where the knob control hover is set
    ;//
    ;// TAPER there are also two taper indicators displayed at the bottom of the shape





.DATA

;// fonts and positions for the indicators

    ;// taper
    knob_pShape_L       dd 0
    knob_pShape_A       dd 0
    knob_TaperOffset    dd 0    ;// where to shove the A and L taper to

    ;// plus minus indicator
    knob_pShape_pos     dd 0
    knob_pShape_neg     dd 0
    knob_pShape_pos_offset  dd 0    ;// where to shove the pos sign
    knob_pShape_neg_offset  dd 0    ;// where to shove the neg sign


    ;// mask source's for the three knob mode
    knob_mask_source    EQU KNOB_PSOURCE + (KNOB_OC_X-KNOB_HOVER_RADIUS_IN) - 2

    knob_ModeOffset     dd  0   ;

;// shared fonts (slider and knob)

    pFont_add   dd  0   ;
    pFont_mul   dd  0   ;

;//
;// layout parameters
;//

        kludge_radius_in TEXTEQU %KNOB_HOVER_RADIUS_IN
%       knob_hover_radius_in REAL4 kludge_radius_in.0e+0

        kludge_radius_out TEXTEQU %KNOB_HOVER_RADIUS_OUT
%       knob_hover_radius_out REAL4 kludge_radius_out.0e+0


;//
;// Knob OSC_OBJECT definition
;//

osc_Knob OSC_CORE { knob_Ctor,,knob_PrePlay,knob_Calc_2 }
         OSC_GUI  { knob_Render,knob_SetShape,
                    knob_HitTest,knob_Control,knob_Move,
                    knob_Command,knob_InitMenu,,,knob_SaveUndo,knob_LoadUndo,knob_GetUnit }
         OSC_HARD { }

    KNOB_BASE = BASE_SHAPE_EFFECTS_GEOMETRY OR \
                BASE_HAS_AUTO_UNITS         OR \
                BASE_XLATE_CTLCOLORLISTBOX  OR \
                BASE_WANT_EDIT_FOCUS_MSG

    ;// don't make lines too long
    ofsPinData  = SIZEOF OSC_OBJECT + (SIZEOF APIN)*2
    ofsOscData  = SIZEOF OSC_OBJECT + (SIZEOF APIN)*2 + SAMARY_SIZE
    oscBytes    = SIZEOF OSC_OBJECT + (SIZEOF APIN)*2 + SAMARY_SIZE + SIZEOF KNOB_DATA

    OSC_DATA_LAYOUT { NEXT_Knob , IDB_KNOB,OFFSET popup_KNOB,KNOB_BASE,
        2, 8+(SIZEOF KNOB_SETTINGS)*9,
        ofsPinData,
        ofsOscData,
        oscBytes    }

    OSC_DISPLAY_LAYOUT {knob_container, KNOB_PSOURCE, ICON_LAYOUT(4,0,2,2) }

    APIN_init { 0.0,, '=',, PIN_OUTPUT  }
    APIN_init {-1.0,, 'x',,  }

    short_name  db  'Knob',0
    description db  'May be multi-turn, adder, multiplier or just a knob. Use the mouse and cursors keys to adjust value. ',0
    ALIGN 4

    ;// values for dwUser are defined in knob.inc




;//////////////////////////////////////////////////////////////////////////////////////
;//
;// KNOB default presets
;//

;// 0   1       0
;// 1   4       24
;// 2   16      48
;// 3   64      72
;// 4   256     96
;// 5   1K      120
;// 6   4K      144
;// 7   16K     168
;// 8   64K     192
;// 9   256K    216


;// KNOB_SETTINGS STRUCT
;//     dwUser          dd  0   ;// see below
;//     value2          dd  0
;// KNOB_SETTINGS ENDS  ;// 8 bytes and there are 8 of them

    EXTERNDEF knob_preset_table: KNOB_SETTINGS  ;// needed by knob_228_xlate_add_data
    knob_preset_table   LABEL KNOB_SETTINGS

KNOB_SETTINGS {                  120 SHL 24 + UNIT_AUTO_UNIT      , 1.953125e-3 } ;// 1024 turn at 2 turn
KNOB_SETTINGS { KNOB_MODE_MULT +  48 SHL 24 + UNIT_DB + KNOB_TAPER_AUDIO , 0.25 };//    -12db
KNOB_SETTINGS { KNOB_MODE_ADD  +  72 SHL 24 + UNIT_MIDI                  , 0.5  };//  midi 60
KNOB_SETTINGS { KNOB_MODE_MULT +  72 SHL 24 + UNIT_MIDI                  , 0.09375 }    ;// 12 midi
KNOB_SETTINGS { KNOB_MODE_KNOB + 120 SHL 24 + UNIT_BPM + KNOB_TAPER_AUDIO, 9.07029e-005 }   ;// 120 BPM
KNOB_SETTINGS { KNOB_MODE_ADD  +  24 SHL 24 + UNIT_DEGREES , 0.0 }
KNOB_SETTINGS {}
KNOB_SETTINGS {}
not_used_228_0  dd  0
not_used_228_1  dd  0


;//////////////////////////////////////////////////////////////////////////////////////
;//
;// KNOB private data
;//





        knob_1_turn dd  't1'

    ;// for big small, we propose these adjusters

        KNOB_SMALL_ADJUST_X EQU 4
        KNOB_SMALL_ADJUST_Y EQU 16


.DATA






comment ~ /*

    / dV mM dI  \   V = value2 and value1 (stop start)
    | sV mA sI  |   m = mode (Multiply, Add, Knob)
    \ zV mK nI  /   I = input data (mK cancels all input data)

*/ comment ~

    ;// jump table for knob calc

    knob_calc_jump LABEL DWORD

        dd  knob_zVmKxI,knob_sVmKxI,knob_dVmKxI ;// 0   1  2

        dd  knob_zVmAnI,knob_sVmAnI,knob_dVmAnI ;// 3   4  5
        dd  knob_zVmAsI,knob_sVmAsI,knob_dVmAsI ;// 6   7  8
        dd  knob_zVmAdI,knob_sVmAdI,knob_dVmAdI ;// 9  10 11

        dd  knob_zVmMnI,knob_sVmMnI,knob_dVmMnI ;// 12 13 14
        dd  knob_zVmMsI,knob_sVmMsI,knob_dVmMsI ;// 15 16 17
        dd  knob_zVmMdI,knob_sVmMdI,knob_dVmMdI ;// 18 19 20

.CODE

ASSUME_AND_ALIGN
knob_Calc_2 PROC

    ASSUME esi:PTR OSC_KNOB_MAP

    ;// determine zV sV dV

    mov eax, [esi].knob.value2
    xor ecx, ecx            ;// ecx will be the jumper
    or eax, eax
    mov edx, [esi].dwUser   ;// load the mode
    .IF !ZERO?
        inc ecx             ;// bump to sV
        .IF eax != [esi].knob.value1
            inc ecx         ;// bump to dV
        .ENDIF
    .ENDIF

    ;// determine mM mA mK

    and edx, KNOB_MODE_TEST ;// either mode set ?
    .IF !ZERO?
        add ecx, 3          ;// bump to mA
        xor ebx, ebx
        bt edx, LOG2(KNOB_MODE_MULT)    ;// mult mode ?
        .IF CARRY?
            add ecx, 9      ;// bump to mM
        .ENDIF

        ;// determine dI sI nI
        OR_GET_PIN [esi].pin_I.pPin, ebx
        .IF !ZERO?
            add ecx, 3              ;// bump to sI
            test [ebx].dwStatus, PIN_CHANGING   ;// check changing
            mov ebx, [ebx].pData    ;// load the data pointer
        ASSUME ebx:PTR DWORD
            .IF !ZERO?              ;// changing ?
                add ecx, 3          ;// bump to dI
            .ENDIF
        .ENDIF
    .ENDIF


    DEBUG_IF <ecx !> 20>

    jmp knob_calc_jump[ecx*4]


;/////////////////////////////////
;//
;//
;//     knob calcs that store zero
;//
    ALIGN 16
    knob_zVmMdI::   ;// value is zero and we are multiplying
    knob_zVmMsI::   ;// value is zero and we are multiplying

    knob_sVmMnI::   ;// input is not connected and we are multiplying
    knob_zVmMnI::   ;// value is zero and input is not connected

    knob_zVmAnI::   ;// value is zero and input is not connected
    knob_zVmKxI::   ;// value is zero

        xor eax, eax
        jmp knob_check_store_static

;//
;//
;//     knob calcs that store zero
;//
;/////////////////////////////////


;/////////////////////////////////
;//
;//
;//     knob calcs that store a static value
;//
    ALIGN 16

    knob_sVmAnI::   ;// input is not connected, we are adding
    knob_sVmKxI::   ;// knob hasn't changed

        mov eax, [esi].knob.value1
        jmp knob_check_store_static

    ALIGN 16
    knob_zVmAsI::   ;// value is zero, we are adding

        mov eax, [ebx]
        jmp knob_check_store_static

    ALIGN 16
    knob_sVmAsI::   ;// value is static, input is static, we are adding

        fld  [ebx]
        fadd [esi].knob.value1
        pushd 0
        fstp DWORD PTR [esp]
        pop eax
        jmp knob_check_store_static

    ALIGN 16
    knob_sVmMsI::   ;// value is static, input is static, we are multiplying

        fld  [ebx]
        fmul [esi].knob.value1
        pushd 0
        fstp DWORD PTR [esp]
        pop eax
        jmp knob_check_store_static


;//
;//
;//     knob calcs that store a static value
;//
;/////////////////////////////////

;/////////////////////////////////
;//
;//
;//     knob calcs that update the ramp then store a static value
;//
    ALIGN 16
    knob_dVmMnI::   ;// multiplying, no input, store zero

        mov edx, [esi].knob.value2
        xor eax, eax
        mov [esi].knob.value1, edx
        jmp knob_check_store_static


;//
;//
;//     knob calcs that update the ramp then store a static value
;//
;/////////////////////////////////





;/////////////////////////////////
;//
;//
;//     knob calcs that xfer data
;//

    ALIGN 16
    knob_zVmAdI::   ;// value is zero, input is connected, we are adding

        or [esi].pin_X.dwStatus, PIN_CHANGING
        mov ecx, SAMARY_LENGTH
        lea edi, [esi].data_x
        xchg esi, ebx
        rep movsd
        xchg ebx, esi
        jmp all_done

;//
;//
;//     knob calcs that xfer data
;//
;/////////////////////////////////


;/////////////////////////////////
;//
;//
;//     knob calcs that build ramps only
;//

    ALIGN 16
    knob_dVmAnI::   ;// no input, we are adding
    knob_dVmKxI::

        fld [esi].knob.value1   ;// start
        fld [esi].knob.value2   ;// stop
        fst [esi].knob.value1   ;// put in value 1
        jmp knob_store_ramp

    ALIGN 16
    knob_dVmAsI::   ;// static input, we are adding

        fld [esi].knob.value1   ;// start
        fld [esi].knob.value2   ;// stop
        fst [esi].knob.value1   ;// put in value 1
        fadd [ebx]
        fxch
        fadd [ebx]
        fxch
        jmp knob_store_ramp


    ALIGN 16
    knob_dVmMsI::   ;// static input, we are multiplying

        fld [esi].knob.value1   ;// start
        fld [esi].knob.value2   ;// stop
        fst [esi].knob.value1   ;// put in value 1
        fmul [ebx]
        fxch
        fmul [ebx]
        fxch
        jmp knob_store_ramp

;//
;//
;//     knob calcs that build ramps only
;//
;/////////////////////////////////



;/////////////////////////////////
;//
;//
;//     knob calcs that call math functions (no ramp)
;//
    ALIGN 16
    knob_sVmAdI::   ;// add dI with our static value

        or [esi].pin_X.dwStatus, PIN_CHANGING
        lea edi, [esi].data_x       ;// output
        lea edx, [esi].knob.value1  ;// edx = sB
        xchg esi, ebx               ;// esi = dX (store esi in ebx)
        invoke math_add_dXsB
        xchg esi, ebx               ;// (stored esi in ebx)
        jmp all_done

    ALIGN 16
    knob_sVmMdI::   ;// multiply dI with our static value

        or [esi].pin_X.dwStatus, PIN_CHANGING
        push esi
        lea edi, [esi].data_x       ;// output
        lea esi, [esi].knob.value1  ;// sA
        xchg esi, ebx               ;// swap to get esi=dX and ebx=sA
        invoke math_mul_dXsA
        pop esi
        jmp all_done



;//
;//
;//     knob calcs that call math functions (no ramp)
;//
;/////////////////////////////////


;////////////////////////////////////////////////////////////////////
;//
;//
;//     knob calcs that build ramps and store values
;//

    ALIGN 16
    knob_dVmAdI::   ;// add the changing dI to a ramp

        fld [esi].knob.value1   ;// start
        fld [esi].knob.value2   ;// stop
        fst [esi].knob.value1   ;// put in value 1
        lea edi, [esi].data_x
        or [esi].pin_X.dwStatus, PIN_CHANGING
        invoke math_ramp

        lea edi, [esi].data_x   ;// output
        push esi
        mov esi, edi            ;// dX input
        mov edx, ebx            ;// dB
        invoke math_add_dXdB
        pop esi
        jmp all_done

    ALIGN 16
    knob_dVmMdI::   ;// multiply the changing di with a ramp

        fld [esi].knob.value1   ;// start
        fld [esi].knob.value2   ;// stop
        fst [esi].knob.value1   ;// put in value 1
        lea edi, [esi].data_x
        or [esi].pin_X.dwStatus, PIN_CHANGING
        invoke math_ramp

        lea edi, [esi].data_x   ;// output
        push esi
        mov esi, edi            ;// dX input
        invoke math_mul_dXdA
        pop esi
        jmp all_done


;//
;//
;//     knob calcs that build ramps and store values
;//
;////////////////////////////////////////////////////////////////////


ALIGN 16
knob_store_ramp:
;// fpu must be loaded with start stop values

    lea edi, [esi].data_x
    or [esi].pin_X.dwStatus, PIN_CHANGING
    invoke math_ramp
    jmp all_done

ALIGN 16
knob_check_store_static:

    ;// eax must have value to store

    btr [esi].pin_X.dwStatus, LOG2(PIN_CHANGING)
    jc knob_store_static
    cmp eax, [esi].data_x[0]
    je all_done

    knob_store_static:

        lea edi, [esi].data_x
        mov ecx, SAMARY_LENGTH
        rep stosd
        jmp all_done


ALIGN 16
all_done:

    ret

knob_Calc_2 ENDP








ASSUME_AND_ALIGN
knob_PrePlay PROC

    ASSUME esi:PTR OSC_KNOB_MAP

    ;// here, we want to set our state as changing, so we force an update of the value

    xor eax, eax    ;// so play_start will erase our data
    mov [esi].knob.value1, eax

    ret

knob_PrePlay ENDP









ASSUME_AND_ALIGN
knob_Ctor PROC

        ;// register call
        ASSUME ebp:PTR LIST_CONTEXT ;// preserve
        ASSUME esi:PTR OSC_KNOB_MAP ;// preserve
        ASSUME edi:PTR OSC_BASE     ;// may destroy
        ASSUME ebx:PTR FILE_OSC     ;// may destroy
        ASSUME edx:PTR FILE_HEADER  ;// may destroy

    ;// we're being called from the constructor
    ;// all file data has already been loaded

    ;// set to defaults if not loading from file

        .IF !edx    ;// empty ?
            mov [esi].dwUser, UNIT_AUTO_UNIT
            mov edx, esi
            lea edi, [esi].knob.config
            mov esi, OFFSET knob_preset_table
            mov ecx, ((SIZEOF KNOB_SETTINGS)*9)/4
            rep movsd
            mov esi, edx
        .ENDIF

        or [esi].knob.dwFlags, KNOB_NEW_TEST

    ;// that's it, setshape/render/hittest will take care of the rest

        ret

knob_Ctor ENDP









ASSUME_AND_ALIGN
knob_Move PROC

    ;// this adds mouse_delta to the appropriate points
    ;// then jumps to osc_Move to exit

    ASSUME esi:PTR OSC_KNOB_MAP

    .IF !([esi].dwUser & KNOB_SMALL)

        point_Get mouse_delta

        point_AddTo [esi].knob.middleArm
        point_AddTo [esi].knob.controlArm
        point_AddTo [esi].knob.displayArm

        point_AddToTL [esi].knob.hoverRect_out
        point_AddToBR [esi].knob.hoverRect_out
        point_AddToTL [esi].knob.valueRect
        point_AddToBR [esi].knob.valueRect
        point_AddToTL [esi].knob.center_text
        point_AddToBR [esi].knob.center_text

    .ENDIF

    jmp osc_Move

knob_Move   ENDP



;////////////////////////////////////////////////////////////////////////////////
;//
;//                                 these break up functions to avoid
;//     settings functions          doing some unessesary work
;//
;//     ABox228: one central routine does all
;//              use knob.dwFlags to sequence




comment ~ /*

    some math


    max_turns = 2^(log_max_turns * k_log_turns) k_log_turns = 1/12

    scale = 1/max_turns

    value2 = ( angle + 2 * turns ) * scale

    angle + 2 * turns = value2 / scale

    angle is fraction
    turns is integer


*/ comment ~

PROLOGUE_OFF
ASSUME_AND_ALIGN
knob_log_turns_to_turns PROC STDCALL dwLogTurns:DWORD

    ;// utility function
    ;// returns fpu as turns, requires 3 free registers
    ;// destroys eax

    ;// turns = round(2^(log_turns*scale))

        fild DWORD PTR [esp+4]
        fabs
        fmul knob_1_turns_scale ;// math_1_16   ;//     knob_k_scale
        fld math_1

        fxch                ;// X       1

        xor eax, eax
        fucom st(1)         ;// X       1
        fnstsw ax
        sahf
        je return_2
        jb do_easy_way

    do_hard_way:

        fxch            ;// 1       X
        fld st(1)       ;// X       1       X
        .REPEAT
            fprem       ;// fX      1       X
            xor eax, eax
            fnstsw ax
            sahf
        .UNTIL !PARITY? ;// fX      1       X

        f2xm1           ;// 2^fX-1  1       X
        fadd            ;// 2^fX    X
        fscale          ;// 2^X     X
        fxch            ;// X       2^X
        fstp st         ;// 2^X
        jmp done

    do_easy_way:

        f2xm1           ;// 2^X-1   1
        fadd            ;// 2^X

    done:

        frndint

    all_done:

        retn 4  ;// STDCALL 1 arg

    return_2:   ;// value in fpu was exactly equal to 1

        fadd
        jmp all_done

knob_log_turns_to_turns ENDP
PROLOGUE_ON


ASSUME_AND_ALIGN
knob_sync PROC USES ebx

        ASSUME esi:PTR OSC_KNOB_MAP ;// preserved
        ASSUME ebp:PTR LIST_CONTEXT ;// preserved

        mov ecx, [esi].dwUser
        mov ebx, [esi].knob.dwFlags

BITR ebx, KNOB_NEW_TAPER
.IF CARRY?

    DEBUG_IF < ecx !!= [esi].dwUser >


            ;// SET TAPER
            xor eax, eax
            test ecx, KNOB_TAPER_AUDIO
            setnz al
            mov edx, knob_pShape_L[eax*4]       ;// load the correct shape
            mov [esi].knob.pTaperShape, edx     ;// store in knob struct

            ;// assume that log lin is already called ??

.ENDIF


BITR ebx, KNOB_NEW_TURNS    ;// MAX TURNS has changed
.IF CARRY?

    DEBUG_IF < ecx !!= [esi].dwUser >


            ;// KNOB SET TURNS MAX

            ;// task:   log_turns --> max_turns
            ;//                   --> turns_scale
            ;//                   --> max_turns_text

            xor eax, eax
            shld eax, ecx, 8

            invoke knob_log_turns_to_turns, eax

            fist [esi].knob.max_turns
            fdivr math_1
            fstp [esi].knob.turns_scale

            mov eax, [esi].knob.max_turns
            pushd 0             ;// sz format terminator
            mov ecx, 'ti%'
            .IF eax >= 1000     ;// K unit reduction
                .IF eax < 1000000
                    mov ecx, 1000
                    xor edx, edx
                    idiv ecx
                    mov ecx, 'tKi%'
                .ELSE           ;// M unit reduction
                    mov ecx, 1000000
                    xor edx, edx
                    idiv ecx
                    mov ecx, 'tMi%'
                .ENDIF
            .ENDIF

            push ecx            ;// sz fmt
            mov ecx, esp        ;// ptr sz_fmt
            lea edx, [esi].knob.max_turns_text      ;// buffer
            invoke wsprintfA, edx, ecx, eax

            add esp, 8

            mov ecx, [esi].dwUser
            or ebx, KNOB_NEW_CONTROL

.ENDIF



BITR ebx, KNOB_NEW_MODE
.IF CARRY?

    DEBUG_IF < ecx !!= [esi].dwUser >

            ;// KNOB SET MODE

            ;// this sets the mask source for the knob

            xor eax, eax    ;// defualt to none
            .IF ecx & KNOB_MODE_MULT
                mov eax, pFont_mul
            .ELSEIF ecx & KNOB_MODE_ADD
                mov eax, pFont_add
            .ENDIF
            mov [esi].knob.pModeShape, eax

            ;// make sure the input pin is either hidden or un hidden
            ;// and that the correct shape is shown
            push ebx

            OSC_TO_PIN_INDEX esi, ebx, 1;// get the input pin

            .IF !(ecx & KNOB_MODE_TEST) ;// check if it needs hidden
                xor eax, eax            ;// hide
            .ELSE
                invoke pin_SetName      ;// set the font shape to the operation
                or eax, 1               ;// unhide
            .ENDIF

            invoke pin_Show, eax        ;// GDI_INVALIDATE_PIN eax

            pop ebx
        ;// mov ecx, [esi].dwUser

.ENDIF


BITR ebx, KNOB_NEW_UNITS
.IF CARRY?

    DEBUG_IF < ecx !!= [esi].dwUser >

            push ebx

            test ecx, UNIT_AUTO_UNIT
            lea ebx, [esi].pin_X
            .IF !ZERO?      ;// we are auto

            ;// set both pins to auto

                mov eax, UNIT_AUTO_UNIT
                invoke pin_SetUnit

                lea ebx, [esi].pin_I
                mov eax, UNIT_AUTO_UNIT
                invoke pin_SetUnit

            .ELSE   ;// we have a fixed unit

                ;// set both pins to fixed units

                mov eax, ecx
                and eax, UNIT_TEST
                push eax
                invoke pin_SetUnit

                lea ebx, [esi].pin_I
                pop eax
                invoke pin_SetUnit

                ;// make sure we set the unit name shape

            .ENDIF

            pop ebx
            or ebx, KNOB_NEW_VALUE OR KNOB_NEW_AUTO

.ENDIF




BITR ebx, KNOB_NEW_VALUE
.IF CARRY?

    DEBUG_IF < ecx !!= [esi].dwUser >

            fld [esi].knob.value2
            invoke unit_BuildString, ADDR [esi].knob.text, ecx, 0

            ;// now we back up, separate the strings, and determine the length of each

            ASSUME eax:PTR BYTE

            ;// vvvvv uuu
            ;// D     <--A

            lea edx, [esi].knob.text    ;// beginning of string
            xor ecx,ecx                 ;// length counter

        J0: cmp [eax-1], ' '    ;// check for space
            je J1               ;// done if we found one
            dec eax             ;// back up on char
            inc ecx             ;// increase the char count
            cmp eax, edx        ;// check for beggining of string
            ja J0               ;// keep scanning if not at beggining

        ;// no space was found

            mov [esi].knob.lenTextValue, ecx
            mov [esi].knob.lenTextUnit, 0
            jmp J2

        ;// a space was found
        J1: mov [esi].knob.lenTextUnit, ecx
            sub eax, edx
            dec eax
            mov [esi].knob.lenTextValue, eax

        J2: ;// all_done:

            mov ecx, [esi].dwUser


.ENDIF




BITR ebx, KNOB_NEW_AUTO
.IF CARRY?

    invoke context_SetAutoTrace

.ENDIF






BITR ebx, KNOB_NEW_CONTROL
.IF CARRY?

    DEBUG_IF < ecx !!= [esi].dwUser >

            ;// task:   value2 --> turns_current
            ;//                --> turns_angle

            ;// make sure the number of turns is correct
            ;// assume value2 is correct and angle is wrong

            DEBUG_IF <!![esi].knob.turns_scale> ;// should have set by knob_set_turns_max

            fld [esi].knob.turns_scale
            fld [esi].knob.value2

            .IF [esi].dwUser & KNOB_TAPER_AUDIO

                invoke math_lin_log

            .ENDIF

            ;// value2  scale

            fdivr       ;// value2 / scale
            fld st
            fmul math_1_2
            frndint
            fist    [esi].knob.turns_current
            fld st
            fadd
            fsub
            fstp    [esi].knob.turns_angle

        ;// determine where the end of the control arm is

            fld knob_hover_radius_in
            fld [esi].knob.turns_angle
            mov eax, [esi].knob.turns_angle

            call knob_layout_xy

            fistp [esi].knob.controlArm.x
            fistp [esi].knob.controlArm.y

        ;// determine where the end of the display arm is

            fld knob_hover_radius_out
            fld [esi].knob.value2

            call knob_layout_xy

            fistp [esi].knob.displayArm.x
            fistp [esi].knob.displayArm.y

        ;// set up the psource and shape for the pos neg sign

            xor eax, eax                ;// clear for testing
            mov edx, [esi].knob.value2
            .IF edx & 7FFFFFFFh

                .IF edx & 80000000h
                    inc eax
                .ENDIF

                mov edx, knob_pShape_pos[eax*4] ;// load the shape pointer
                mov [esi].knob.pSignShape, edx      ;// store in knob struct

                mov edx, knob_pShape_pos_offset[eax*4]  ;// load the appropriate offset
                mov [esi].knob.pSignOffset, edx         ;// save in knob struct

            .ELSE

                mov [esi].knob.pSignShape, eax  ;// zero

            .ENDIF

.ENDIF


;// done
        mov [esi].knob.dwFlags, ebx

        ret






        ;///////////////////////////////////////////////////

        ;// local functions
        ALIGN 16
        knob_layout_xy:


            ;// given the angle in the fpu
            ;// trash it and compute the xy coords

            ;// asumes registers are set as above
            ;// uses eax, edx

            ;// returns x y in the fpu

            ;// middleArm must be set before calling this
            ;// desired radius must be loaded as well

            ;// FPU = angle radius

        sub esp, 4

            fmul  math_NormToOfs            ;// scale angle to an offset
            mov edx, math_pSin              ;// edx references the sin/cos table
            mov eax, math_OfsQuarter        ;// load one quarter
            ASSUME edx:PTR DWORD
            fistp DWORD PTR [esp]           ;// store as integer

            add eax, DWORD PTR [esp]        ;// load the angle offset, convert to cos
            and eax, math_AdrMask           ;// dword align and wrap negative

        add esp, 4

            fld DWORD PTR [edx+eax]         ;// load the cosine

            fmul st, st(1)                  ;// scale by the knob radius
            sub eax, math_OfsQuarter        ;// scoot eax back to the sine
            and eax, math_AdrMask           ;// account for table wrap
            fiadd [esi].knob.middleArm.x    ;// add offset to center

            fxch

            fmul DWORD PTR [edx+eax]        ;// multiply by the sine
            fisubr [esi].knob.middleArm.y   ;// subtract from middle arm add offset to center
            fxch                            ;// x   y

            retn



knob_sync ENDP





ASSUME_AND_ALIGN
knob_post_autotrace PROC

        ASSUME esi:PTR OSC_KNOB_MAP
        ;// must return ecx as dwUser !!

        ;// we need to determine what knob.pUnitShape should be
        ;// as well as set the desired units in dwUser

        mov ecx, [esi].dwUser
        mov eax, [esi].pin_X.dwStatus   ;// see if X has units
        and ecx, NOT UNIT_TEST          ;// remove any residual unit from dwUser
        TESTJMP eax, UNIT_AUTOED, jnz eax_has_units ;// X have a unit ?
        mov eax, [esi].pin_I.dwStatus       ;// nope, try I for a unit
        TESTJMP eax, UNIT_AUTOED, jz set_the_unit   ;// I have a unit ?

    eax_has_units:  ;// now eax is the unit we want

        and eax, UNIT_TEST          ;// remove extra stuff
        or ecx, eax                 ;// merge in with ecx
        or ecx, UNIT_AUTOED         ;// set the autoed bit so the units display correctly

    set_the_unit:

        mov [esi].dwUser, ecx       ;// set the new units in dwUser
        or [esi].knob.dwFlags, KNOB_NEW_VALUE   ;// do NOT set KNOB_NEW_UNITS
        invoke knob_sync            ;// build the label
        mov ecx, [esi].dwUser

        ret

knob_post_autotrace ENDP















ASSUME_AND_ALIGN
knob_GetUnit    PROC

        ASSUME esi:PTR OSC_KNOB_MAP
        ASSUME ebx:PTR APIN

    ;// grab the unit from the other pin

        DEBUG_IF <!!([esi].dwUser & UNIT_AUTO_UNIT)>    ;// should have caught this by now

        lea ecx, [esi].pin_X
        .IF ecx == ebx
            add ecx, SIZEOF APIN    ;// pin_I
        .ENDIF
        ASSUME ecx:PTR APIN

        mov eax, [ecx].dwStatus
        BITT eax, UNIT_AUTOED
        ret

knob_GetUnit    ENDP







ASSUME_AND_ALIGN
knob_SetShape PROC

        ASSUME esi:PTR OSC_KNOB_MAP ;// preserved
        ASSUME edi:PTR OSC_BASE     ;// preserved
        ;// must preserve ebx

        DEBUG_IF <edi!!=[esi].pBase>    ;// supposed to be

    ;// make sure the fonts and offsets are defined

        .IF !knob_pShape_A

        ;// calculate the offsets first

            mov eax, KNOB_SIZE_Y - KNOB_TAPER_MARGIN_Y
            mul gdi_bitmap_size.x

            lea edx, [eax+ (KNOB_SIZE_X - KNOB_TAPER_MARGIN_X)]
            mov knob_TaperOffset, edx

            lea edx, [eax+ KNOB_TAPER_MARGIN_X ]
            mov knob_ModeOffset, edx

            mov eax, KNOB_OC_Y - KNOB_SIGN_MARGIN_Y
            mul gdi_bitmap_size.x
            add eax, KNOB_OC_X + KNOB_SIGN_MARGIN_X
            mov knob_pShape_pos_offset, eax

            mov eax, KNOB_OC_Y + KNOB_SIGN_MARGIN_Y
            mul gdi_bitmap_size.x
            add eax, KNOB_OC_X + KNOB_SIGN_MARGIN_X
            mov knob_pShape_neg_offset, eax

        ;// then define the fonts we need
        push edi

            .IF !pFont_add  ;// make sure that the slider hasn't already done this

                lea edi, font_pin_slist_head
                mov eax, '+'
                invoke font_Locate
                mov pFont_add, edi

                lea edi, font_pin_slist_head
                mov eax, 'x'
                invoke font_Locate
                mov pFont_mul, edi

            .ENDIF

            lea edi, font_pin_slist_head
            mov eax, 'L'
            invoke font_Locate
            mov knob_pShape_L, edi

            lea edi, font_pin_slist_head
            mov eax, 'A'
            invoke font_Locate
            mov knob_pShape_A, edi

            lea edi, font_bus_slist_head
            mov eax, '+'
            invoke font_Locate
            mov knob_pShape_pos, edi

            lea edi, font_bus_slist_head
            mov eax, '-'
            invoke font_Locate
            mov knob_pShape_neg, edi

        ;// that's it

        pop edi
        ASSUME edi:PTR OSC_BASE

        .ENDIF

    ;// set up the shape

        .IF [esi].dwUser & KNOB_SMALL

            mov eax, KNOB_SMALL_PSOURCE
            lea edx, fftop_container

            mov [esi].pSource, eax
            mov [esi].pContainer, edx

            or [esi].knob.dwFlags, KNOB_NEW_MODE OR KNOB_NEW_UNITS OR KNOB_NEW_VALUE

            invoke knob_sync

            jmp osc_SetShape

        .ENDIF

    ;// we are a normal knob

        xor eax, eax    ;// this will make osc_SetShape
        xor edx, edx    ;// set the pSource and container from the base class
        mov [esi].pSource, eax
        mov [esi].pContainer, edx

        invoke osc_SetShape         ;// call base class first

        ;// our task here is to make sure we have the correct
        ;// shapes assigned and layout the lines needed to show the knob
        ;// doing this here will greatly speed up drawing because it will only be called
        ;// when the user moves the object, or adjusts the control

        ;// this function should only be called once, as a result of creating the object
        ;// and only if it needed hit tested or rendered. it may never get called,

        ;// calculate the value rect

            point_GetTL [esi].rect
            point_SetTL [esi].knob.valueRect

            add edx, KNOB_VALUE_HEIGHT
            mov eax, [esi].rect.right
            point_SetBR [esi].knob.valueRect

        ;// caclulate the hover rect and middle arm

            point_GetTL [esi].rect      ;// get the top left
            point_Add KNOB_OC           ;// scoot to center

            point_Set [esi].knob.middleArm  ;// store as middle arm

            sub eax, KNOB_HOVER_RADIUS_OUT
            sub edx, KNOB_HOVER_RADIUS_OUT

            point_SetTL [esi].knob.hoverRect_out

            add eax, KNOB_HOVER_RADIUS_OUT * 2
            add edx, KNOB_HOVER_RADIUS_OUT * 2

            point_SetBR [esi].knob.hoverRect_out

            ;// do the center_text

            add edx, [esi].knob.hoverRect_out.top
            shr edx, 1
            mov [esi].knob.center_text.top, edx
            mov [esi].knob.center_text.bottom, edx
            mov eax, [esi].knob.hoverRect_out.left
            mov edx, [esi].knob.hoverRect_out.right
            mov [esi].knob.center_text.left, eax
            mov [esi].knob.center_text.right, edx

        ;// layout controls

            invoke knob_sync

        ;// that just might do it

            ret

knob_SetShape ENDP



;///////////////////////////////////////////////////////////////////////////////////////
;//
;//
;//     RENDER
;//
ASSUME_AND_ALIGN
knob_Render PROC

    ASSUME esi:PTR OSC_KNOB_MAP ;// esi must point at osc   preserved
    ASSUME edi:PTR OSC_BASE     ;// also preserved

    ;// to draw the knob we:

    ;// call osc_render, it will draw the back ground, and the hover if nessesary
    ;// it will also shut off extra flags

        invoke gdi_render_osc

    ;// for the rest of this function, ecx must be dwUser

        mov ecx, [esi].dwUser

    ;// check if we do auto trace

        BITR ecx, UNIT_AUTO_TRACE
        .IF CARRY?

            mov [esi].dwUser, ecx
            invoke knob_post_autotrace
            DEBUG_IF <ecx !!= [esi].dwUser>

        .ENDIF

    ;// draw the details of the knob

        .IF !(ecx & KNOB_SMALL)     ;// if we are small, we do a different operation

            ;// display the value track
            ;// draw a pie slice
            ;// also check if we're not drawing a pie, but a line

            point_Get [esi].knob.displayArm
            .IF edx == [esi].knob.middleArm.y && eax > [esi].knob.middleArm.x

                ;// just draw a short line
                GDI_DC_SELECT_RESOURCE hPen_1, COLOR_OSC_2
                invoke MoveToEx, gdi_hDC, [esi].knob.middleArm.x, [esi].knob.middleArm.y, 0
                invoke LineTo, gdi_hDC, [esi].knob.hoverRect_out.right, [esi].knob.middleArm.y

            .ELSE   ;// draw_pie:

                ;// different order if angle is negative
                .IF !([esi].knob.value2 & 80000000h)    ;// counter_clockwise:

                    push edx    ;// int nYRadial2 // y-coord. of second radial’s endpoint
                    push eax    ;// int nXRadial2, // x-coord. of second radial’s endpoint
                    push [esi].knob.middleArm.y     ;// int nYRadial1, // y-coord. of first radial’s endpoint
                    push [esi].knob.hoverRect_out.right ;//int nXRadial1, x-coord. of first radial’s endpoint

                .ELSE   ;// clockwise:

                    push [esi].knob.middleArm.y     ;// int nYRadial2
                    push [esi].knob.hoverRect_out.right ;// int nXRadial2
                    push edx                    ;//int nYRadial1
                    push eax                    ;//int nXRadial1

                .ENDIF  ;// do_pie:

                push [esi].knob.hoverRect_out.bottom
                push [esi].knob.hoverRect_out.right
                push [esi].knob.hoverRect_out.top
                push [esi].knob.hoverRect_out.left
                push gdi_hDC

                ;//GDI_DC_SELECT_RESOURCE hPen_1, COLOR_OSC_2
                ;// do this by hand, there is no gdi pen defined as null
                mov eax, hPen_null
                .IF eax != gdi_current_pen
                    mov gdi_current_pen, eax
                    invoke SelectObject, gdi_hDC, eax
                .ENDIF
                GDI_DC_SELECT_RESOURCE hBrush, COLOR_OSC_1

                call Pie

            .ENDIF

            ;// mask out the center

            push edi
            push esi

            ;// stack looks like this
            ;// osc     base    ret
            ;// esi     edi
            ;// 00      04      08

            mov edi, [esi].pDest            ;// dest is always the object dest
            mov ebx, knob_shape_mask.pMask  ;// load masker from the shape
            mov esi, knob_mask_source       ;// always the same
            invoke shape_Move               ;// do the blit

            mov esi, [esp];// should still be osc

            ;// display the plus minus sign, only if we need to

            point_Get [esi].knob.displayArm
            .IF eax > [esi].knob.middleArm.x
                sub edx, [esi].knob.middleArm.y
                .IF SIGN?
                    neg edx
                .ENDIF
                .IF edx < KNOB_PLUS_MINUS_THRESHOLD

                    .IF [esi].knob.pSignShape           ;// skip if zero

                        mov edi, [esi].knob.pSignOffset ;// load the offset
                        DEBUG_IF <!!edi>            ;// this was not set yet
                        mov ebx, [esi].knob.pSignShape  ;// load masker from the shape
                        add edi, [esi].pDest        ;// add the osc dest
                        mov ebx, (GDI_SHAPE PTR [ebx]).pMask
                        mov eax, F_COLOR_OSC_TEXT   ;// osc text color
                        invoke shape_Fill           ;// fill the font

                        mov esi, [esp];// should still be esi

                    .ENDIF
                .ENDIF
            .ENDIF

            ;// display the audio/linear taper

            mov edi, knob_TaperOffset   ;// load the offset
            DEBUG_IF <!!edi>            ;// this was not set yet
            mov ebx, [esi].knob.pTaperShape ;// load the shape
            DEBUG_IF <!!ebx>            ;// this was not set yet
            add edi, [esi].pDest        ;// add the osc dest
            mov ebx, (GDI_SHAPE PTR [ebx]).pMask    ;// load masker from the shape
            mov eax, F_COLOR_OSC_TEXT   ;// osc text color
            invoke shape_Fill           ;// do the blit

            mov esi, [esp];// should still be esi

            ;// display the mode

            .IF [esi].knob.pModeShape

                mov edi, knob_ModeOffset    ;// load the offset
                DEBUG_IF <!!edi>            ;// this was not set yet
                mov ebx, [esi].knob.pModeShape  ;// load the shape
                DEBUG_IF <!!ebx>            ;// this was not set yet
                add edi, [esi].pDest        ;// add the osc dest
                mov ebx, (GDI_SHAPE PTR [ebx]).pMask    ;// load masker from the shape
                mov eax, F_COLOR_OSC_TEXT   ;// osc text color
                invoke shape_Fill           ;// do the blit

                mov esi, [esp];// should still be esi

            .ENDIF

            ;// display the control angle

            GDI_DC_SELECT_RESOURCE hPen_1, COLOR_OSC_2

            invoke MoveToEx, gdi_hDC, [esi].knob.middleArm.x, [esi].knob.middleArm.y, 0
            invoke LineTo, gdi_hDC, [esi].knob.controlArm.x, [esi].knob.controlArm.y

        ;// display the center label (and maybe the hover)
        ;// this section exits with ebx set as the center label shape to draw


            ;// hover con hover inner outer

            .IF (esi == osc_hover) && (app_bFlags & APP_MODE_CON_HOVER)

                ;// we have control hover, we outline the control shape
                ;// outline the correct control, exit with ebx as ptr to turns text

                .IF [esi].knob.dwFlags & KNOB_OUTTER_HOVER

                    mov ebx, knob_shape_hover_out.pOut1
                    mov edi, [esi].pDest
                    mov eax, F_COLOR_OSC_HOVER  ;// osc hover color
                    invoke shape_Fill

                    mov esi, [esp];// should still be esi
                    mov ebx, OFFSET knob_1_turn     ;// we have outter hover, so we show one turn

                .ELSE   ;// we have inner hover

                    mov ebx, knob_shape_hover_in.pOut1
                    mov edi, [esi].pDest
                    mov eax, F_COLOR_OSC_HOVER  ;// osc hover color
                    invoke shape_Fill

                    mov esi, [esp];// should still be esi

                    ;// don't have outter hover,
                    ;// number of turns

                    lea ebx, [esi].knob.max_turns_text  ;// set to show number of turns

                .ENDIF

                ;// display the center texts

                GDI_DC_SELECT_FONT hFont_osc
                GDI_DC_SET_COLOR COLOR_OSC_TEXT

                ;// turns

                invoke DrawTextA, gdi_hDC, ebx, -1,
                    ADDR [esi].knob.center_text,
                    DT_CENTER + DT_TOP + DT_SINGLELINE + DT_NOCLIP + DT_NOPREFIX

                ;// units

                mov edx, [esi].knob.lenTextUnit
                mov eax, [esi].knob.lenTextValue
                .IF edx

                    lea ebx, [esi].knob.text[eax][1]
                    invoke DrawTextA, gdi_hDC, ebx, edx,
                        ADDR [esi].knob.center_text,
                        DT_CENTER + DT_BOTTOM + DT_SINGLELINE + DT_NOCLIP + DT_NOPREFIX

                .ENDIF

            .ELSE   ;// we may have hover, but we do not have con hover
                    ;// so we show only the units at the center

                GDI_DC_SELECT_FONT hFont_osc
                GDI_DC_SET_COLOR COLOR_OSC_TEXT

                mov edx, [esi].knob.lenTextUnit
                mov eax, [esi].knob.lenTextValue
                .IF edx

                    lea ebx, [esi].knob.text[eax][1]
                    invoke  DrawTextA,gdi_hDC,ebx,edx,
                            ADDR [esi].knob.center_text,
                            DT_CENTER + DT_VCENTER + DT_SINGLELINE + DT_NOCLIP + DT_NOPREFIX

                .ENDIF

            .ENDIF  ;// inner texts and hovers


            pop esi
            pop edi

            ;// display the main text
            GDI_DC_SELECT_FONT hFont_osc
            GDI_DC_SET_COLOR COLOR_OSC_TEXT

            invoke DrawTextA, gdi_hDC, ADDR [esi].knob.text, [esi].knob.lenTextValue,
                ADDR [esi].knob.valueRect,
                DT_CENTER + DT_VCENTER + DT_SINGLELINE + DT_NOCLIP + DT_NOPREFIX

        .ELSE   ;// we are small

        ;// display the main text

            GDI_DC_SELECT_FONT hFont_pin
            GDI_DC_SET_COLOR COLOR_OSC_TEXT

            invoke DrawTextA, gdi_hDC, ADDR [esi].knob.text, [esi].knob.lenTextValue,
                ADDR [esi].rect,
                DT_CENTER + DT_TOP + DT_SINGLELINE + DT_NOCLIP + DT_NOPREFIX

        ;// display the the unit string

            mov edx, [esi].knob.lenTextUnit
            mov eax, [esi].knob.lenTextValue
            .IF edx

                lea ebx, [esi].knob.text[eax][1]
                invoke DrawTextA, gdi_hDC, ebx, edx,
                    ADDR [esi].rect,
                    DT_CENTER + DT_BOTTOM + DT_SINGLELINE + DT_NOCLIP + DT_NOPREFIX

            .ENDIF

        .ENDIF

    ;// that's it

        ret


knob_Render ENDP
;//
;//     RENDER
;//
;//
;///////////////////////////////////////////////////////////////////////////////////////



;/////////////////////////////////////////////////////////////////////////////////
;//
;//
;//     HITTEST and CONTROL
;//
;//

;// jumped to from mouse_hittest_osc
ASSUME_AND_ALIGN
knob_HitTest PROC

    ASSUME esi:PTR OSC_KNOB_MAP ;// preserve
    ASSUME edi:PTR OSC_BASE     ;// can destroy
    ASSUME ebp:PTR LIST_CONTEXT ;// preserve
    ;// ebx is also free

    ;// we know the mouse is inside the box
    ;// our job now is to see if the mouse is over the knob itself

    ;// return carry if yes
    ;// return (no sign, no carry, no zero) if not hit


    ;// check if we are small

        .IF [esi].dwUser & KNOB_SMALL
            ret
        .ENDIF

    ;// we also assume that we are setup enough to do this

        point_Get mouse_now
        point_SubTL [esi].rect
        point_Sub KNOB_OC

        mov ecx, edx

    ;// now point is the delta between knob center and mouse_now

        imul eax
        xchg eax, ecx
        imul eax
        add eax, ecx

    ;// now eax is the distance squared
    ;// since we have two hovers, we detect which here

        .IF eax <= KNOB_HOVER_RADIUS_OUT * KNOB_HOVER_RADIUS_OUT

            ;// outter hover must be on
            CMPJMP eax, KNOB_HOVER_RADIUS_IN * KNOB_HOVER_RADIUS_IN, jb hit_inner

            BITSJMP [esi].knob.dwFlags, KNOB_OUTTER_HOVER, jc hit_done

        hit_redraw:

            GDI_INVALIDATE_OSC HINTI_OSC_UPDATE
            jmp hit_done

        hit_inner:  ;// outter hover must be off

            BITRJMP [esi].knob.dwFlags, KNOB_OUTTER_HOVER, jc hit_redraw

        hit_done:

            xor eax, eax    ;// clear extra flags
            stc             ;// hit, set the carry flag

        .ENDIF

        inc eax ;// not hit, clear all flags

    ;// that's it

        ret

knob_HitTest ENDP


;/////////////////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
knob_Control PROC

    ;// this new (ABox2) version only requires that we do the steps
    ;// required to control the knob

    ;// if we need them, the flags that caused this are in eax

        ASSUME esi:PTR OSC_KNOB_MAP ;// preserved
        ASSUME edi:PTR OSC_BASE     ;// preserved
        ASSUME ebp:PTR LIST_CONTEXT

    ;// here we want to calculate a new angle
    ;// atan cy/cx

        mov ecx, [esi].dwUser

        sub esp, SIZEOF RECT
        st_rect TEXTEQU <(RECT PTR [esp])>

        point_Get mouse_now
        point_SubTL [esi].rect
        point_Sub KNOB_OC
        point_SetTL st_rect

        fild st_rect.top
        fchs
        fild st_rect.left
        fpatan

        add esp, SIZEOF RECT
        st_rect TEXTEQU <>

        fmul math_RadToNorm

    ;// now things get tricky
    ;// we're a multi turn, we have to determine if we wrapped
    ;// if we are moving the outter control, we use a different strategy

        .IF [esi].knob.dwFlags & KNOB_OUTTER_HOVER

        ;// outter hover always controls the value directly

            .IF !(ecx & KNOB_WRAP)

            ;// in this case, we use value insead of angle

                xor eax, eax
                fld [esi].knob.value2;// a2     a3
                fsub st, st(1)  ;// a2-a3
                fabs            ;//|a2-a3|  a3
                fld1            ;// 1       |a2-a3|   a3
                fsubr           ;// 1-|a2-a3| a3
                ftst
                fnstsw ax
                fstp st
                sahf

                .IF CARRY? && !ZERO?

                    fstp st ;// we'll replace this
                    fld1    ;// no wrap is +/- one

                    ;// we wrapped, determine which way

                    xor eax, eax
                    or eax, [esi].knob.value2
                    .IF SIGN?

                        ;// value was negative, now it's positive
                        ;// we want to keep it positive

                        fchs

                    .ENDIF

                .ENDIF

            .ENDIF

            fstp [esi].knob.value2

        .ELSE

            ;// inner hover relies on number of turns

            ;// check if we wrapped
            ;// we know we wrap if |a2-a3| > 1

                xor eax, eax
                fld [esi].knob.turns_angle  ;// a2      a3
                fsub st, st(1)          ;// a2-a3
                fabs                    ;//|a2-a3|  a3
                fld1                    ;// 1       |a2-a3|   a3
                fsubr                   ;// 1-|a2-a3| a3
                ftst
                fnstsw ax
                fstp st
                sahf

                .IF CARRY? && !ZERO?

                    ;// we wrapped, determine which way
                    xor eax, eax
                    or eax, [esi].knob.turns_angle
                    .IF SIGN?

                        ;// angle was negative, now it's positive
                        ;// so we're wrapping CCW,
                        ;// which means we decrease turns

                        dec [esi].knob.turns_current

                    .ELSE

                        ;// angle was positive, now it's negative
                        ;// so we're wrapping CW
                        ;// which means we increase turns

                        inc [esi].knob.turns_current

                    .ENDIF

                .ENDIF

            ;// compute value2
            ;// value2 = ( angle + 2 * turns ) * scale

                fild  [esi].knob.turns_current
                fadd  st, st
                fadd  st, st(1)
                fmul  [esi].knob.turns_scale    ;// value2 angle

            ;// now we check if out of range

                fld1        ;// 1   value2 angle
                fucom
                fnstsw ax
                sahf
                jnc check_under_range

                    ;// over range, too many turns
                    fstp st

                    .IF !(ecx & KNOB_WRAP)

                    ;// to make the knob stay where it is
                    ;// we do this

                        fstp st
                        fstp st

                        fld1
                        jmp update_the_turns

                    .ENDIF

                ;//else to make negative, we do this

                    fsub math_2
                    fxch
                    fstp st
                    jmp update_the_turns

                check_under_range:

                    fchs    ;// -1  value2 angle
                    fucomp
                    fnstsw ax
                    sahf

                    jbe check_log_lin

                        ;// under range, too few turns

                    .IF !(ecx & KNOB_WRAP)

                    ;// to make the knob stay where it is
                    ;// we do this

                        fstp st
                        fstp st

                        fld1
                        fchs
                        jmp update_the_turns

                    .ENDIF

                    fadd math_2
                    fxch
                    fstp st

                update_the_turns:

                    fstp [esi].knob.value2
                    jmp update_the_knob

            ;// now check for lin log
            check_log_lin:

                DEBUG_IF < ecx !!= [esi].dwUser >

                .IF ecx & KNOB_TAPER_AUDIO
                    invoke math_log_lin
                .ENDIF

            ;// finally we store the value

                fstp [esi].knob.value2
                fstp [esi].knob.turns_angle

            ;// now we update what we need to

            update_the_knob:

        .ENDIF  ;// inner outter hover

        or [esi].knob.dwFlags, KNOB_NEW_CONTROL OR KNOB_NEW_VALUE

        invoke knob_sync

        GDI_INVALIDATE_OSC HINTI_OSC_UPDATE ;// tell gdi to redraw

    ;// then we force the mouse state to moved

        mov eax, CON_HAS_MOVED

    ;// that's it

        ret

knob_Control ENDP

;//
;//
;//     HITTEST and CONTROL
;//
;//
;/////////////////////////////////////////////////////////////////////////////////




;/////////////////////////////////////////////////////////////////////////////////
;//
;//
;//     InitMenu and Command
;//
;//


ASSUME_AND_ALIGN
knob_InitMenu PROC USES edi


    ;// this function sets the correct checkmarks for a knob menu

        ASSUME esi:PTR OSC_KNOB_MAP

;// check if we we just auto traced

        .IF [esi].dwUser & UNIT_AUTO_TRACE

            invoke knob_post_autotrace

        .ENDIF



;// IDC_KNOB_UNITS

    ;// read and knob share list functionality
    ;// so we call a common function to do this

            invoke unit_UpdateComboBox, IDC_KNOB_UNITS, 1   ;// is knob

;// EDIT TEXT

            invoke GetDlgItem, popup_hWnd, IDC_KNOB_EDIT
            mov popup_hFocus, eax
            mov edi, eax

            WINDOW eax, EM_SETLIMITTEXT, 63
            sub esp, 64
            mov eax, esp
            invoke knob_BuildCommandString, eax, [esi].dwUser, [esi].knob.value2
            invoke SetWindowTextA, edi, esp
            WINDOW edi, EM_SETSEL, 0, -1
            add esp, 64
            WINDOW edi, EM_SETMODIFY

;// IDC_KNOB_PRESETS

        ;// get the window handle

            invoke GetDlgItem, popup_hWnd, IDC_KNOB_PRESETS
            mov ebx, eax

        ;// add all the strings and set the item data

            WINDOW ebx,LB_GETCOUNT
            dec eax
            .IF SIGN?

            sub esp, 64

                xor edi, edi
                .REPEAT

                    mov eax, esp

                    lea edx, [edi+' )2']
                    mov DWORD PTR [eax], edx
                    add eax, 3

                    invoke knob_BuildCommandString,
                        eax,
                        [esi].knob.config[edi*8].dwUser,
                        [esi].knob.config[edi*8].value2

                KNOB_PRESET_2 EQU 0

                    WINDOW ebx,LB_ADDSTRING,0,esp
                    lea edx, [edi+KNOB_PRESET_2]
                    WINDOW ebx,LB_SETITEMDATA, eax, edx
                    inc edi

                .UNTIL edi >= 8

            add esp, 64

            .ENDIF

;// set the correct mode

            mov eax, [esi].dwUser
            mov edx, BST_CHECKED
            mov ebx, BST_UNCHECKED
            mov edi, BST_UNCHECKED

            .IF eax & KNOB_MODE_ADD
                xchg edx, ebx
            .ELSEIF eax & KNOB_MODE_MULT
                xchg edx, edi
            .ENDIF

            invoke CheckDlgButton, popup_hWnd, IDC_KNOB_MODE_KNOB, edx
            invoke CheckDlgButton, popup_hWnd, IDC_KNOB_MODE_ADD, ebx
            invoke CheckDlgButton, popup_hWnd, IDC_KNOB_MODE_MULT, edi

;// IDC_KNOB_TURNS

        ;// SCROLLINFO STRUCT
        pushd 0                 ;// 6   dwTrackPos  dd      0

        mov eax, [esi].dwUser
        shr eax, 24
        pushd eax               ;// 5   dwPos       SDWORD  0

        pushd 12                ;// 4   dwPage      dd      0
        pushd 255               ;// 3   dwMax       SDWORD  0
        pushd 0                 ;// 2   dwMin       SDWORD  0
        pushd SIF_RANGE OR SIF_PAGE OR SIF_POS;//   1   dwMask      dd      0
        pushd SIZEOF SCROLLINFO ;// 0   dwSize      dd

        invoke GetDlgItem, popup_hWnd, IDC_KNOB_TURNS
        mov edx, esp

        invoke SetScrollInfo, eax, SB_CTL,edx, 1
        add esp, SIZEOF SCROLLINFO

;// set the correct taper

        mov eax, [esi].dwUser
        mov edx, BST_CHECKED
        mov ebx, BST_UNCHECKED

        .IF eax & KNOB_TAPER_AUDIO
            xchg edx, ebx
        .ENDIF

        invoke CheckDlgButton, popup_hWnd, ID_KNOB_LINEAR, edx
        invoke CheckDlgButton, popup_hWnd, ID_KNOB_AUDIO, ebx

    ;// set the small button

        .IF [esi].dwUser & KNOB_SMALL
            invoke CheckDlgButton, popup_hWnd, ID_KNOB_SMALL, BST_CHECKED
        .ENDIF

    ;// set the wrap

        .IF [esi].dwUser & KNOB_WRAP
            invoke CheckDlgButton, popup_hWnd, ID_KNOB_WRAP, BST_CHECKED
        .ENDIF


    ;// that's it

        xor eax, eax    ;// clear eax or popup will think we want a new size

        ret

knob_InitMenu ENDP


;///////////////////////////////////////////////////////////////////////////
;//
;//
;//     _Command
;//
ASSUME_AND_ALIGN
knob_Command PROC

    ASSUME ebp:PTR LIST_CONTEXT
    ASSUME esi:PTR OSC_KNOB_MAP     ;// must preserve
    ASSUME edi:PTR OSC_BASE         ;// may destroy
    DEBUG_IF <edi!!=[esi].pBase>

    ;// eax has the command
    ;// ecx has extra params
    ;// exit by returning popup_flags in eax
    ;// or by jumping to osc_sommand

    mov edx, ecx            ;// clumsy but dozens of other routines need ecx
    mov ecx, [esi].dwUser   ;// load dwUser, probably going to need it

;// KEY STROKES FROM EDIT BOX

    cmp eax, OSC_COMMAND_EDIT_KILLFOCUS
    jne @F

        invoke GetDlgItem, popup_hWnd, IDC_KNOB_EDIT
        mov ebx, eax
        WINDOW eax, EM_GETMODIFY
        test eax, eax
        mov eax, POPUP_IGNORE
        jz all_done

        sub esp, 64
        WINDOW ebx, WM_GETTEXT, 63, esp
        dec eax
        mov eax, POPUP_IGNORE
        .IF !SIGN?  ;// there is text there

            invoke knob_ProcessCommandString, esp
            add esp, 64
            jmp sync_and_done

        .ENDIF
        add esp, 64
        jmp all_done

;// COMMANDS FROM EDIT BOX

@@: cmp eax, OSC_COMMAND_EDIT_CHANGE
    jne @F


        ;// the only key we want is the return key
        ;// so we trap that here
        ;// whithout hijaking the return key, we have to scan for it here

        invoke GetDlgItem, popup_hWnd, IDC_KNOB_EDIT
        mov ebx, eax
        sub esp, 64
        WINDOW ebx, WM_GETTEXT, 63, esp
        ;// looking for a return character
            mov edx, eax
            dec edx
        E0: DECJMP eax, js E2   ;// empty ?
            CMPJMP (BYTE PTR [esp+eax]), 0Ah, je  E1
            CMPJMP (BYTE PTR [esp+eax]), 0Dh, jne E0

        ;// we got a return character somewhere in the string

            ;// if the return char is NOT at the end
            ;// then we have shorten the string
        E1: .IF eax != edx
                mov ecx, esp    ;// get from
                mov edx, esp    ;// put in
            E3: mov al, [ecx]           ;// get_from
                TESTJMP al, al, jz E4   ;// check end of string
                CMPJMP al, 0Ah, je E5   ;// check return char
                CMPJMP al, 0Dh, je E5   ;// check return char
                mov [edx], al           ;// put_in
                inc edx                 ;// advance put in
            E5: INCJMP ecx, jmp E3      ;// advance get_from, back to top
            E4: mov [edx], al           ;// trailing terminator
            .ENDIF

            invoke knob_ProcessCommandString, esp
            add esp, 64
            jmp sync_and_done

        ;// return not found
        E2: add esp, 64
            mov eax, POPUP_IGNORE
            jmp all_done


;// UNITS FROM COMBO BOX

@@: cmp eax, OSC_COMMAND_COMBO_SELENDOK
    jne @F

    ;// edx has the private dword for the units
    ;// edx is now a unit

        mov eax, POPUP_IGNORE
        TESTJMP edx, KNOB_PRESET_TEST, jnz got_preset_SELENDOK
        ;// make sure this is the units combo box

    set_new_units:

        DEBUG_IF <ecx !!= [esi].dwUser>

        and ecx, NOT (UNIT_TEST OR UNIT_AUTO_UNIT)  ;// strip out old unit
        or ecx, edx             ;// merge in new unit
        mov [esi].dwUser, ecx   ;// store in dwUser

        or [esi].knob.dwFlags, KNOB_NEW_UNITS

        CMPJMP popup_Object, 0, je sync_and_done

        push edx
        invoke knob_sync
        pop edx
        invoke unit_HandleComboSelChange, IDC_KNOB_UNITS, edx, 1    ;// is knob
        or eax, POPUP_INITMENU
        jmp all_done

    got_preset_SELENDOK:

        jmp knob_command_done


;// HELP TEXT FROM COMBO BOX

@@: cmp eax, OSC_COMMAND_COMBO_SELCHANGE
    jne @F

    ;// this is our chance to update the help text
    ;// edx has the unit id of the text
    ;// the new unit has NOT been selected yet

        mov eax, POPUP_IGNORE

        TESTJMP edx,KNOB_PRESET_TEST, jne all_done      ;// make sure this is the units combo box
        invoke unit_HandleComboSelChange, IDC_KNOB_UNITS, edx, 1    ;// is knob
        ;// returns values in eax and edx
        jmp all_done

;// PRESET FROM KEYBOARD

@@: cmp eax, ID_KNOB_PRESET_9
    ja @F
    cmp eax, ID_KNOB_PRESET_2
    jb @F

        lea edx, [eax-ID_KNOB_PRESET_2]
        jmp load_preset


;// PRESET FROM LISTBOX

@@: cmp eax, OSC_COMMAND_LIST_DBLCLICK
    jne @F

    ;// edx has the index of the preset we use

    load_preset:

        and [esi].dwUser, KNOB_SMALL OR KNOB_WRAP   ;// leave existing bit in dwUser
        mov eax, [esi].knob.config[edx*8].dwUser
        mov edx, [esi].knob.config[edx*8].value2
        and eax, NOT ( KNOB_SMALL OR KNOB_WRAP )    ;// remove new bits in new value
        mov [esi].knob.value2, edx
        or [esi].dwUser, eax                        ;// merge new bits on to old

        or [esi].knob.dwFlags, KNOB_NEW_TEST
        jmp sync_and_done


;// SET PRESET FROM LISTBOX

@@: cmp eax, ID_KNOB_SET
    jne @F

        invoke GetDlgItem, popup_hWnd, IDC_KNOB_PRESETS
        mov ebx, eax
        LISTBOX ebx, LB_GETCURSEL
        test eax, eax
        mov ecx, eax
        mov eax, POPUP_IGNORE
        js all_done

        mov eax, [esi].dwUser
        mov edx, [esi].knob.value2
        mov [esi].knob.config[ecx*8].dwUser, eax
        mov [esi].knob.config[ecx*8].value2, edx
        LISTBOX ebx, LB_RESETCONTENT
        jmp sync_and_done



;// TURNS VIA SCROLLBAR

@@: cmp eax, IDC_KNOB_TURNS
    jne @F                  ;// dwUser
                            ;// TT--++--
        shl ecx, 8          ;// --++--xx
        shrd ecx, edx, 8    ;// TT--++--
        mov [esi].dwUser, ecx
        or [esi].knob.dwFlags, KNOB_NEW_TURNS

        jmp update_the_turns


;// EDX IS DESTROYED !! put control handlers BEFORE this !!

;// MODE

@@:     xor edx, edx            ;// edx will end up as a bit to set
        cmp eax, IDC_KNOB_MODE_KNOB
        je update_mode

        cmp eax, IDC_KNOB_MODE_ADD
        jne @F
            mov edx, KNOB_MODE_ADD
            jmp update_mode

    @@: cmp eax, IDC_KNOB_MODE_MULT
        jne @F

            mov edx, KNOB_MODE_MULT

    update_mode:

        DEBUG_IF <ecx !!= [esi].dwUser>

        and ecx, NOT KNOB_MODE_TEST ;// strip out the old mode
        or ecx, edx             ;// merge on the new mode
        mov [esi].dwUser, ecx   ;// store in object

        or [esi].knob.dwFlags, KNOB_NEW_MODE
        jmp sync_and_done


;// TURNS via keyboard

comment ~ /*
ID_KNOB_TURNS_1     EQU 31h 1
ID_KNOB_TURNS_4     EQU 32h 2
ID_KNOB_TURNS_16    EQU 33h 3           key = id-30, if zero, add 10
ID_KNOB_TURNS_64    EQU 34h 4
ID_KNOB_TURNS_256   EQU 35h 5           log turns = (key-1)*24
ID_KNOB_TURNS_1K    EQU 36h 6
ID_KNOB_TURNS_4K    EQU 37h 7
ID_KNOB_TURNS_16K   EQU 38h 8
ID_KNOB_TURNS_64K   EQU 39h 9
ID_KNOB_TURNS_256K  EQU 30h 0
*/ comment ~

    @@:
        cmp eax, VK_0   ;// ID_KNOB_TURNS_64K
        jb @F
        cmp eax, VK_9   ;// ID_KNOB_TURNS_256K
        ja @F

        ;// log_max_turns = (num-1)*32
        sub eax, VK_1   ;// key-1
        .IF SIGN?
            mov eax, 9
        .ENDIF
        ;// * 24 = *3*8

        lea eax, [eax+eax*2]    ;// *3
        shl eax, 3
        shl [esi].dwUser, 8
        shrd [esi].dwUser, eax, 8

    update_the_turns:

        or [esi].knob.dwFlags, KNOB_NEW_TURNS
        jmp sync_and_done


;// UNITS VIA KEYBOARD

@@:     invoke unit_FromKeystroke
        jc set_new_units
        xor edx, edx    ;// must be zero

;// TAPER

        cmp eax, ID_KNOB_LINEAR
        je update_taper

    @@: cmp eax, ID_KNOB_AUDIO
        jne @F

        or edx, KNOB_TAPER_AUDIO

    update_taper:

        DEBUG_IF <ecx !!= [esi].dwUser>

        and ecx, NOT KNOB_TAPER_TEST
        or ecx, edx
        mov [esi].dwUser, ecx
        or [esi].knob.dwFlags, KNOB_NEW_TAPER OR KNOB_NEW_CONTROL OR KNOB_NEW_VALUE
        jmp sync_and_done


;// PRESET VALUE COMMANDS

    @@: cmp eax, ID_KNOB_ONE
        jnz @F
        fld1
        jmp update_value

    @@: cmp eax, ID_KNOB_ZERO
        jnz @F
        fldz
        jmp update_value

    @@: cmp eax, ID_KNOB_NEG
        jnz @F
        fld [esi].knob.value2
        fchs

    update_value:

        fstp [esi].knob.value2
        or [esi].knob.dwFlags, KNOB_NEW_VALUE OR KNOB_NEW_CONTROL
        jmp sync_and_done



;// KEYBOARD VALUE CONTROL

    @@: cmp eax, VK_UP
        jne @F

        fld math_1_8
        jmp adjust_the_value

    @@: cmp eax, VK_DOWN
        jne @F

        fld math_neg_1_8
        jmp adjust_the_value

    @@: cmp eax, VK_LEFT
        jne @F

        fld math_1_8
        jmp adjust_the_value_no_scale

    @@: cmp eax, VK_RIGHT
        jne @F

        fld math_neg_1_8
        jmp adjust_the_value_no_scale

    adjust_the_value:

        ;// fpu has the amount of turns to adjust

        fmul  [esi].knob.turns_scale

    adjust_the_value_no_scale:

        ;// add the amount and account for log lin

        .IF ecx & KNOB_TAPER_AUDIO

            fld [esi].knob.value2
            invoke math_lin_log
            fadd
            invoke math_log_lin

        .ELSE

            fadd  [esi].knob.value2

        .ENDIF

    ;// check for over and underflow


        fld1
        fucomp
        fnstsw ax
        sahf
        jae check_neg_value
        .IF !(ecx & KNOB_WRAP)
            fstp st
            fld1
            jmp update_value
        .ENDIF
            fsub math_2
            jmp update_value

        check_neg_value:

            fld1
            fchs
            fucomp
            fnstsw ax
            sahf
            jbe update_value
        .IF !(ecx & KNOB_WRAP)
            fstp st
            fld1
            fchs
            jmp update_value
        .ENDIF
            fadd math_2
            jmp update_value

;// SMALL

@@: cmp eax, ID_KNOB_SMALL
    jne @F

        BITC [esi].dwUser, KNOB_SMALL
        mov eax, KNOB_SMALL_ADJUST_X
        mov edx, KNOB_SMALL_ADJUST_Y
        .IF CARRY?
            or [esi].knob.dwFlags, KNOB_NEW_CONTROL
            neg eax
            neg edx
        .ENDIF

        point_AddToTL [esi].rect
        GDI_INVALIDATE_OSC HINTI_OSC_SHAPE_CHANGED OR HINTI_OSC_MOVED

        jmp knob_command_done   ;// set shape will call knob sync

;// WRAP/NOWRAP

@@: cmp eax, ID_KNOB_WRAP
    jne osc_Command ;// @F  ;//     NONE OF THE ABOVE
                            ;// @@: jmp osc_Command

        xor ecx, KNOB_WRAP
        mov [esi].dwUser, ecx   ;// store in object
        jmp knob_command_done


;// EXIT POINT

    ALIGN 16
    sync_and_done:

        invoke knob_sync

    knob_command_done:

        mov eax, POPUP_SET_DIRTY OR POPUP_REDRAW_OBJECT OR POPUP_INITMENU

    all_done:

        ret




knob_Command ENDP
;//
;//
;//     _Command
;//
;///////////////////////////////////////////////////////////////////////////



ASSUME_AND_ALIGN
knob_SaveUndo   PROC

    ASSUME esi:PTR OSC_KNOB_MAP

    ;// edx enters as either UNREDO_CONTROL_OSC or UNREDO_COMMAND
    ;// edi enters as where to store
    ;//
    ;// task:   1) save nessary data
    ;//         2) iterate edi
    ;//
    ;// may use all registers except ebp

        mov eax, [esi].dwUser
        stosd

        mov eax, [esi].knob.value2
        stosd

        .IF edx == UNREDO_COMMAND_OSC

            add esi, OSC_KNOB_MAP.knob.config
            mov ecx, (SIZEOF KNOB_SETTINGS*9)/4
            rep movsd

        .ENDIF

        ret

knob_SaveUndo ENDP



ASSUME_AND_ALIGN
knob_LoadUndo PROC

    ASSUME esi:PTR OSC_KNOB_MAP     ;// preserve
    ASSUME ebp:PTR LIST_CONTEXT ;// preserve

    ;// edx enters as either UNREDO_CONTROL_OSC or UNREDO_COMMAND_OSC
    ;// edi enters as where to load
    ;//
    ;// task:   1) load nessary data
    ;//         2) do what it takes to itialize it
    ;//
    ;// may use all registers except ebp
    ;// return will invalidate HINTI_OSC_UPDATE

        mov eax, [edi]

        xchg [esi].dwUser, eax
    mov ecx, edx
        xor eax, [esi].dwUser

        .IF eax & KNOB_SMALL    ;// did small change ?

            mov eax, KNOB_SMALL_ADJUST_X
            mov edx, KNOB_SMALL_ADJUST_Y
            bt [esi].dwUser, LOG2(KNOB_SMALL)
            .IF !CARRY?
                neg eax
                neg edx
            .ENDIF

            point_AddToTL [esi].rect

            or [esi].dwHintI, (HINTI_OSC_SHAPE_CHANGED OR HINTI_OSC_MOVED)

        .ENDIF

        mov eax, [edi+4]
        mov [esi].knob.value2, eax

        .IF ecx == UNREDO_COMMAND_OSC

            push esi
            xchg edi, esi
            add edi, OSC_KNOB_MAP.knob.config
            mov ecx, (SIZEOF KNOB_SETTINGS*9)/4
            add esi, 8
            rep movsd
            pop esi

        .ENDIF

        or [esi].knob.dwFlags, KNOB_NEW_TEST
        invoke knob_sync

        ret

knob_LoadUndo ENDP



xlate_knob_turns_221 PROTO  ;// needed by xlate_knob_220, xlate_knob_beta, knob_xlate
xlate_knob_turns_228 PROTO  ;// needed by xlate_knob_227

comment ~ /*

ABox221 turns translation

        new in ABox221 --> KNOB turns is an index

        KNOB_TURNS_TEST     EQU 00F00000h
        KNOB_TURNS_SHIFT    EQU LOG2(00100000h)
        KNOB_MAXIMUM_TURNS_INDEX    EQU 9

    old numbers

        KNOB_TURNS_1       EQU  00010000h
        KNOB_TURNS_4       EQU  00020000h
        KNOB_TURNS_16      EQU  00040000h
        KNOB_TURNS_64      EQU  00080000h
        KNOB_TURNS_256     EQU  00100000h
        KNOB_TURNS_1K      EQU  00200000h
        KNOB_TURNS_4K      EQU  00400000h
        KNOB_TURNS_16K     EQU  00800000h
        KNOB_TURNS_64K     EQU  01000000h
        KNOB_TURNS_256K    EQU  40000000h

        KNOB_TURNS_MASK    EQU 0BE00FFFFh
        KNOB_TURNS_TEST    EQU  41FF0000h
        KNOB_NUM_TURNS EQU 10   ;// there are ten ranges


ABox228 turns translation


        OLD         NEW
        00X00000h   XX000000h

        00000000h   00 SHL 24   ;// 0   1
        00100000h   2*24 SHL 24 ;// 1   4
        00200000h   3*24 SHL 24 ;// 2   16
        00300000h   4*24 SHL 24 ;// 3   64
        00400000h               ;// 4   256
        00500000h               ;// 5   1K
        00600000h   formula:    ;// 6   4K
        00700000h   index*24    ;// 7   16K
        00800000h               ;// 8   64K
        00900000h               ;// 9   256K
        --------
lsb     22211840
shift   84062
                            ;//   X
        KNOB_PRESET_TEST    EQU 00F00000h   ;// index or zero

*/ comment ~



ASSUME_AND_ALIGN
xlate_knob_turns_221 PROC

    ;// eax has old value
    ;// must preserve all registers except eax and edx
    ;// falls into xlate turns 228

    ;// xlate units must be called before this !!!

        mov edx, eax

        and edx,  NOT 41FF0000h ;// remove old turns

        .IF     eax & 00010000h ;//  KNOB_TURNS_1
            or edx,   00000000h
        .ELSEIF eax & 00020000h ;//  KNOB_TURNS_4
            or edx,   00100000h
        .ELSEIF eax & 00040000h ;//  KNOB_TURNS_16
            or edx,   00200000h
        .ELSEIF eax & 00080000h ;//  KNOB_TURNS_64
            or edx,   00300000h
        .ELSEIF eax & 00100000h ;//  KNOB_TURNS_256
            or edx,   00400000h
        .ELSEIF eax & 00200000h ;//  KNOB_TURNS_1K
            or edx,   00500000h
        .ELSEIF eax & 00400000h ;//  KNOB_TURNS_4K
            or edx,   00600000h
        .ELSEIF eax & 00800000h ;//  KNOB_TURNS_16K
            or edx,   00700000h
        .ELSEIF eax & 01000000h ;//  KNOB_TURNS_64K
            or edx,   00800000h
        .ELSEIF eax & 40000000h ;//  KNOB_TURNS_256K
            or edx,   00900000h
        .ENDIF

        mov eax, edx

        ;// fall into next section
        ;// all xlate functions rely on this

xlate_knob_turns_221 ENDP



xlate_knob_turns_228 PROC

;//DEBUG_IF <eax & 0FF000000h>  ;// just checking, these values should be gone by now
;//                             ;// sometimes the 1 bit is set,

        ;// eax has the dwUser to xlate
        ;// must preserve all registers except eax and edx

        ;// task:   convert to new log turns
        ;//         remove the preset index
        ;//
        ;// formula log turns = index*24 shl 24

        mov edx, eax            ;// xfer
        and eax, NOT KNOB_PRESET_TEST   ;// remove old turns index, reset the preset index
        and edx, KNOB_PRESET_TEST       ;// remove all extra turns index bits
        lea edx, [edx+edx*2]    ;// index *3
        shl eax, 8              ;// remove top bits from eax
        shr edx, 20-3           ;// scoot into place, then mulitply by 8
        shrd eax, edx, 8        ;// add new turns to eax

        ret

xlate_knob_turns_228 ENDP

ASSUME_AND_ALIGN

ENDIF   ;// USE_THIS_FILE
END

