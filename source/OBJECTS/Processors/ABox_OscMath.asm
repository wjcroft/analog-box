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
;//                    -- revamped calc to look for shortcuts if one input is static
;//                        reincorporated ptr passing
;//                        implemented math_bool_X functions
;//
;//##////////////////////////////////////////////////////////////////////////
;//
;// ABox_OscMath.asm
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

;// gdi

    MATH_SIZE equ 32


;// object definition

;// core

osc_Math    OSC_CORE { ,,,osc_Math_Calc }
        OSC_GUI { ,osc_Math_SetShape,,,,
            osc_Math_Command,osc_Math_InitMenu,,,
            osc_SaveUndo,math_LoadUndo,osc_Math_GetUnit }
        OSC_HARD { }
        OSC_DATA_LAYOUT { NEXT_Math,IDB_MATH,OFFSET popup_MATH,,
            3,4,
            SIZEOF OSC_OBJECT + ( SIZEOF APIN ) * 3,
            SIZEOF OSC_OBJECT + ( SIZEOF APIN ) * 3 + SAMARY_SIZE,
            SIZEOF OSC_OBJECT + ( SIZEOF APIN ) * 3 + SAMARY_SIZE }
        OSC_DISPLAY_LAYOUT { circle_container,, ICON_LAYOUT( 6,0,2,3 ) }

;// pins

    APIN_init {-0.90 ,,'x',,            }  ;// in 1
    APIN_init {+0.90 ,,'y',,            }  ;// in 2
    APIN_init { 0.0  ,,'=',, PIN_OUTPUT }  ;// out

    short_name  db  'Math',0
    description db  'Simple arithmetic, logic gates, and comparisons.',0
    ALIGN 4

;// settings stored in object.dwUser

        MATH_OP_ADD     equ  00000000h  ;// indexes
        MATH_OP_MULT    equ  00000001h
        MATH_OP_SUB     equ  00000002h

        MATH_OP_AND     equ  00000003h
        MATH_OP_OR      equ  00000004h
        MATH_OP_NAND    equ  00000005h
        MATH_OP_NOR     equ  00000006h
        MATH_OP_XOR     equ  00000007h

        MATH_OP_LT      equ  00000008h
        MATH_OP_LTE     equ  00000009h
        MATH_OP_GT      equ  0000000Ah
        MATH_OP_GTE     equ  0000000Bh
        MATH_OP_E       equ  0000000Ch
        MATH_OP_NE      equ  0000000Dh

        NUM_MATH_OP     equ  0000000Eh
        MATH_OP_TEST    equ  0000000Fh
        MATH_OP_MASK    equ NOT MATH_OP_TEST


        MATH_OUT_DIGITAL equ  01000000h             ;// dig/bip     =
        MATH_OUT_MASK    equ NOT MATH_OUT_DIGITAL


;// general object properties

    MATH_NUM_OPS    equ 14  ;// there are 14 operations

;// position list for all the bitmaps

    math_pSource_list   \
        dd      M_PLUS_PSOURCE  ;// pos add
        dd      M_MULT_PSOURCE  ;// pos multiply
        dd      M_MINUS_PSOURCE ;// pos subtract

        dd      M_AND_PSOURCE   ;// pos and
        dd      M_OR_PSOURCE    ;// pos or
        dd      M_NAND_PSOURCE  ;// pos nand
        dd      M_NOR_PSOURCE   ;// pos nor
        dd      M_XOR_PSOURCE   ;// pos xor

        dd      M_LT_PSOURCE    ;// pos <
        dd      M_LTE_PSOURCE   ;// pos <=
        dd      M_GT_PSOURCE    ;// pos >
        dd      M_GTE_PSOURCE   ;// pos >=
        dd      M_EQ_PSOURCE    ;// pos ==
        dd      M_NE_PSOURCE    ;// pos !=

;// command id list, use this to xlate key strokes to dwUser

    math_id_list    \
        dd ID_MATH_ADD
        dd ID_MATH_MULT
        dd ID_MATH_SUB
        dd ID_MATH_AND
        dd ID_MATH_OR
        dd ID_MATH_NAND
        dd ID_MATH_NOR
        dd ID_MATH_XOR
        dd ID_MATH_LT
        dd ID_MATH_LTE
        dd ID_MATH_GT
        dd ID_MATH_GTE
        dd ID_MATH_E
        dd ID_MATH_NE


;// pin configuration

;//                 1       2       3
;// arrithmetic     auto    auto    auto
;// 0-2             x       y       =
;//
;// gate            logic   logic   logic
;// 3-7             a       b       +- or +0
;//
;// compare         auto    auto    logic
;// 8-D             x       y       +- or +0

    ;// these are replaced with shape pointers at the earliest convinience

    MATH_BOLD EQU 40000000h

    math_letters    dd  'x' ;// 0
                    dd  'y' ;// 1
                    dd  'a' ;// 2
                    dd  'b' ;// 3

                    dd  '='+ MATH_BOLD          ;// 4
                    dd  0B1h + MATH_BOLD        ;// 5   +/-
                    dd  80002DBAh + MATH_BOLD   ;// 6   0/-     build special

        NUM_MATH_LETTERS EQU 7

    PIN_CONFIG STRUCT

        letter  dd  0   ;// index to shape pointer for letter
        unit    dd  0   ;// desired unit, 0 for auto
        logic   dd  0   ;// desired logic shape

    PIN_CONFIG ENDS


    MATH_PIN_CONFIG STRUCT

        pin_x   PIN_CONFIG  {}
        pin_y   PIN_CONFIG  {}
        pin_z   PIN_CONFIG  {}

    MATH_PIN_CONFIG ENDS

    math_pin_config LABEL DWORD

        ;// bipolar
        dd  pin_config_0,   pin_config_0,   pin_config_0
        dd  pin_config_1,   pin_config_1,   pin_config_1,   pin_config_1,   pin_config_1
        dd  pin_config_2,   pin_config_2,   pin_config_2,   pin_config_2,   pin_config_2,   pin_config_2
        ;// digital
        dd  pin_config_3,   pin_config_3,   pin_config_3
        dd  pin_config_4,   pin_config_4,   pin_config_4,   pin_config_4,   pin_config_4
        dd  pin_config_5,   pin_config_5,   pin_config_5,   pin_config_5,   pin_config_5,   pin_config_5

    MATH_LOGIC  EQU UNIT_LOGIC
    MATH_AUTO   EQU UNIT_AUTO_UNIT
    MATH_GATE   EQU PIN_LOGIC_INPUT OR PIN_LOGIC_GATE OR PIN_LEVEL_NEG

    ;// bipolar                     X                        Y                        Z
    pin_config_0 MATH_PIN_CONFIG { {0,MATH_AUTO ,0        },{1,MATH_AUTO,0         },{4,MATH_AUTO } }
    pin_config_1 MATH_PIN_CONFIG { {2,MATH_LOGIC,MATH_GATE},{3,MATH_LOGIC,MATH_GATE},{5,MATH_LOGIC} }
    pin_config_2 MATH_PIN_CONFIG { {2,MATH_AUTO ,0        },{3,MATH_AUTO,0         },{5,MATH_LOGIC} }

    ;// digital
    pin_config_3 MATH_PIN_CONFIG { {0,MATH_AUTO , 0       },{1,MATH_AUTO, 0         },{4,MATH_AUTO } }
    pin_config_4 MATH_PIN_CONFIG { {2,MATH_LOGIC,MATH_GATE},{3,MATH_LOGIC,MATH_GATE },{6,MATH_LOGIC} }
    pin_config_5 MATH_PIN_CONFIG { {2,MATH_AUTO , 0       },{3,MATH_AUTO,0          },{6,MATH_LOGIC} }




;// osc map

    OSC_MAP STRUCT

        OSC_OBJECT {}
        pin_x   APIN    {}
        pin_y   APIN    {}
        pin_z   APIN    {}
        z_data  dd SAMARY_LENGTH dup (0)

    OSC_MAP ENDS



.CODE


ASSUME_AND_ALIGN
osc_Math_SyncPins PROC USES edi ebx

    ASSUME esi:PTR OSC_MAP
    ASSUME ebp:PTR LIST_CONTEXT

    ;// this makes sure that when operation is set to value
    ;// that the pins are set as logic fixed
    ;// otherwise they are set to un fixed
    ;// we also take care of the pin shapes

    ;// make sure the pin letters are built

        .IF math_letters == 'x'

        push esi

            lea esi, math_letters
            mov ebx, NUM_MATH_LETTERS

            .REPEAT

                lodsd

                btr eax, LOG2(MATH_BOLD)
                lea edi, font_pin_slist_head
                .IF CARRY?
                    lea edi, font_bus_slist_head
                .ENDIF

                invoke font_Locate
                dec ebx
                mov DWORD PTR [esi-4], edi

            .UNTIL ZERO?

        pop esi

        .ENDIF

    ;// determine which configuration table to use

        mov ecx, [esi].dwUser
        and ecx, MATH_OP_TEST OR MATH_OUT_DIGITAL
        BITR ecx, MATH_OUT_DIGITAL
        .IF CARRY?
            add ecx, NUM_MATH_OP
        .ENDIF

        OSC_TO_PIN_INDEX esi, ebx, 0    ;// ebx walks pins on object

        mov edi, math_pin_config[ecx*4] ;// edi eats pin configs
        ASSUME edi:PTR PIN_CONFIG

        mov eax, [edi].letter[0*(SIZEOF PIN_CONFIG)]
        invoke pin_SetNameAndUnit, math_letters[eax*4], 0, [edi].unit[0*(SIZEOF PIN_CONFIG)]
        mov eax, [edi].logic[0*(SIZEOF PIN_CONFIG)]
        invoke pin_SetInputShape

        add ebx, SIZEOF APIN

        mov eax, [edi].letter[1*(SIZEOF PIN_CONFIG)]
        invoke pin_SetNameAndUnit, math_letters[eax*4], 0, [edi].unit[1*(SIZEOF PIN_CONFIG)]
        mov eax, [edi].logic[1*(SIZEOF PIN_CONFIG)]
        invoke pin_SetInputShape

        add ebx, SIZEOF APIN

        mov eax, [edi].letter[2*(SIZEOF PIN_CONFIG)]
        invoke pin_SetNameAndUnit, math_letters[eax*4], 0, [edi].unit[2*(SIZEOF PIN_CONFIG)]

    ;// that's it

        ret

osc_Math_SyncPins ENDP









ASSUME_AND_ALIGN
osc_Math_SetShape PROC

    ASSUME esi:PTR OSC_OBJECT   ;// preserved
    ASSUME edi:PTR OSC_BASE

    DEBUG_IF <edi!!=[esi].pBase>    ;// must be so

    ;// get the pSource from dwUser

        mov ecx, [esi].dwUser
        and ecx, MATH_OP_TEST

        mov eax, math_pSource_list[ecx*4]
        mov [esi].pSource, eax

    ;// make sure the pins are synchronized

        invoke osc_Math_SyncPins

    ;// exit by calling the default

        jmp osc_SetShape

    ;// that's it !

osc_Math_SetShape ENDP



;///////////////////////////////////////////////////////////////////////////
;//
;//
;//     osc_Math__Command
;//
ASSUME_AND_ALIGN
osc_Math_Command PROC

    ASSUME esi:PTR OSC_OBJECT   ;// must preserve
    ASSUME edi:PTR OSC_BASE     ;// may destroy
    DEBUG_IF <edi!!=[esi].pBase>
    ;// must preserve ebx
    ;// eax has the command
    ;// exit by returning popup_flags in eax
    ;// or by jumping to osc_sommand


    ASSUME esi:PTR OSC_OBJECT   ;// preserved
    ASSUME edi:PTR OSC_BASE

    DEBUG_IF <edi!!=[esi].pBase>    ;// must be so

    ;// eax has the command id

    ;// scan through the command table

        push edi
        mov ecx, MATH_NUM_OPS
        lea edi, math_id_list
        repne scasd
        pop edi
        jnz @F

    ;// it's one them, so ecx is the index

        sub ecx, MATH_NUM_OPS
        and [esi].dwUser, MATH_OP_MASK      ;// strip out the old op
        neg ecx
        dec ecx
        or [esi].dwUser, ecx                ;// merge in new source
        mov edx, math_pSource_list[ecx*4]   ;// get the source pointer
        mov [esi].pSource, edx              ;// store the new source

        jmp all_done

    ;// command is not one of the ops

    @@: cmp eax, ID_MATH_DIGITAL
        jnz @F
        or [esi].dwUser, MATH_OUT_DIGITAL
        jmp all_done

    @@: cmp eax, ID_MATH_BIPOLAR
        jnz osc_Command
        and [esi].dwUser, MATH_OUT_MASK

all_done:

        invoke osc_Math_SyncPins    ;// make sure the pins are synchronized
        mov eax, POPUP_SET_DIRTY + POPUP_REDRAW_OBJECT + POPUP_INITMENU ;// set the return value

        ret         ;// exit


osc_Math_Command ENDP
;//
;//     osc_Math__Command
;//
;//
;///////////////////////////////////////////////////////////////////////////




ASSUME_AND_ALIGN
osc_Math_InitMenu PROC

    ASSUME esi:PTR OSC_OBJECT   ;// preserved
    ASSUME edi:PTR OSC_BASE

    DEBUG_IF <edi!!=[esi].pBase>    ;// must be so

    ;// set the corect operation item

        mov ebx, [esi].dwUser
        and ebx, MATH_OP_TEST
        mov ecx, math_id_list[ebx*4]
        invoke CheckDlgButton, popup_hWnd, ecx, BST_CHECKED

    ;// set the output type

        .IF ebx >= MATH_OP_AND

            .IF [esi].dwUser & MATH_OUT_DIGITAL
                mov ecx, ID_MATH_DIGITAL
            .ELSE
                mov ecx, ID_MATH_BIPOLAR
            .ENDIF
            invoke CheckDlgButton, popup_hWnd, ecx, BST_CHECKED

            mov ebx, 1

        .ELSE

            xor ebx, ebx

        .ENDIF

        ;// enable/disable both buttons

        invoke GetDlgItem, popup_hWnd, ID_MATH_DIGITAL
        invoke EnableWindow, eax, ebx

        invoke GetDlgItem, popup_hWnd, ID_MATH_BIPOLAR
        invoke EnableWindow, eax, ebx

    ;// that's it

        xor eax, eax    ;// return zero or popup intializer will think we want a resize

        ret

osc_Math_InitMenu ENDP







;////////////////////////////////////////////////////////////////////
;//
;//
;//     _LoadUndo
;//

ASSUME_AND_ALIGN
math_LoadUndo PROC

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

        and eax , MATH_OP_TEST      ;// strip out the old op
        mov edx, math_pSource_list[eax*4]   ;// get the source pointer
        mov [esi].pSource, edx              ;// store the new source

        invoke osc_Math_SyncPins    ;// make sure the pins are synchronized

        ret

math_LoadUndo ENDP

;//
;//
;//     _LoadUndo
;//
;////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
osc_Math_GetUnit PROC

    ;// ebx is the pin we try to get units for

        ASSUME esi:PTR OSC_MAP  ;// must preserve
        ASSUME ebx:PTR APIN     ;// must preserve
        ;// must preserve edi and ebp


        lea ecx, [esi].pin_z
        ASSUME ecx:PTR APIN
        cmp ecx, ebx
        je check_input_pins
        mov eax, [ecx].dwStatus
        BITT eax, UNIT_AUTOED

    all_done:

        ret

    check_input_pins:
    ;// we need to find a consensus of input pins
    ;// we can be certain that we are an arithmetic operation

        IFDEF DEBUGBUILD

            mov eax, [esi].dwUser   ;// get our mode
            and eax, MATH_OP_TEST   ;// strip out extra

            DEBUG_IF < eax !> MATH_OP_SUB > ;// guess we can't assume that ...

        ENDIF

        mov eax, [esi].pin_x.dwStatus
        mov edx, [esi].pin_y.dwStatus

comment ~ /*

    here's what we're doing

        .IF eax & UNIT_AUTOED && edx & UNIT_AUTOED

            ;// units must match

        .ELSEIF eax & UNIT_AUTOED

            ;// use eax units

        .ELSEIF edx & UNIT_AUTOED

            ;// use edx units

        .ELSE

            ;// don't know what we are

        .ENDIF

*/ comment ~

        test eax, UNIT_AUTOED
        jz try_edx
        ;// eax is autoed
        test edx, UNIT_AUTOED
        jz use_eax
        ;// both are autoed
        and eax, UNIT_TEST
        and edx, UNIT_TEST
        cmp eax, edx
        je use_eax
        ;// units don't match
        clc
        jmp all_done
    ;// eax is not autoed
    try_edx:
        test edx, UNIT_AUTOED
        jz all_done     ;// carry flag is cleared
    use_edx:
        mov eax, edx
    use_eax:
        stc
        jmp all_done


osc_Math_GetUnit ENDP





;///////////////////////////////////////////////////////////////////////////////
;//
;//     C A L C
;//
;//
comment ~ /*

    summary

        osc_Math_Calc PROC

            setup registers and input summary bits

            jump to handler (ie add, mul, compare, gate)

            handler_X: (one for each object mode)

                OSCMATH_CALC MACRO

                    examine summary bits and

                        OPER_3)    do a full frame calc
                        OPER_2,1)  look for shortcuts since one input is static
                            and exit to a 'quick exit' handler
                            or do a full frame calc if no shortcut is applicable
                        OPER_0)  do a single sample calc and exit to

            quick_exit_Q:

                shuffle ptrs, summon quick math_X routines,
                or, prefferably, do nothing

            exit:

    OSCMATH_CALC merely wraps the 3210 tests and OPER_X macros into a common framework
    OPER_X does the actual calculations, or exits to a quick exit

*/ comment ~




;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
;////
;////   OSCMATH_CALC
;////
;////  wrapper for all the styles of math calcs

;// enter:
;//   ebx is OSC_MAP
;//   esi is pin_x source data
;//   edx is pin_y source data
;//   edi points at our internal data
;//   ecx is a two bit summary of changing  x,y
;//        ecx==3 if both inputs are changing
;//     ecx==2 if esi changing, edx not changing
;//     ecx==1 if esi not changing, edx is changing
;//     ecx==0 if neither esi or edx are changing
;//  for oper that output boolean, fpu is loaded with false,true
;//
;//    oper_3
;//    oper_2_shortcut
;//    oper_1_shortcut
;//    oper_2        oper _2 and _1 may be unreachable due to shortcuts
;//    oper_1        OPER_ENTER and OPER_LEAVE are used to prevent needless code
;//    oper_0
;//
;//     each oper macro must either exit to a quick routine, or empty the fpu (for logical opers)
;//
;// for operations that are reversable (meaning: x op y == y op x)
;//        macros must define _3, _1 and _0
;//        outter macro will take care of swapping esi, edx
;//        must also define _2_shortcut wich can exit to one of the quick routines
;//
;// for non reversable operations
;//        macros must define all 4 of _3, _2, _1, _0
;//        and provide _2_shortcut and _1_shortcut
;//
;//    shortcuts are ordered as
;//
;//        identity    output values are same as input values
;//                    ex: x + 0 == x
;//                        x * 1 == x
;//                        x AND true == x
;//        constant    output values are constant regardless of input values
;//                    ex: x * 0 == 0
;//                        x AND false == false
;//        simple        output values are a 'simple' function of input values
;//                    ex:    0 - x == neg(x)
;//                        x < 0 == bool(x)
;//                        x XOR 1 == not(x)


OPER_ENTER MACRO
    mov [ebx].pin_z.pData, edi                ;// point at our own data
    or [ebx].pin_z.dwStatus, PIN_CHANGING    ;// output will be channging
    ENDM

OPER_LEAVE MACRO
    jmp calc_done
    ENDM


OSCMATH_CALC MACRO rev:req, oper:req

    LOCAL case_ss_0, case_sd_1, case_ds_2, case_dd_3

        ;// route to the correct handler with via flag register trickery
                        ;//     dd 3     ds 2     sd 1     ss 0
                        ;// 00000011 00000010 00000001 00000000    before subtract
        sub cl, 2        ;// 00000001 00000000 11111111 11111110    after subtract 2
                        ;//   ns nz     ns z    s nz    s nz p  flags
        jz case_ds_2    ;// first check -- there are two values with no sign, only one with zero
        jns case_dd_3    ;// not zero, so check the sign -- only one case remaining with no sign
        jp case_sd_1    ;// is negative and not zero -- all 1's is an even number of bits
                        ;// the only value left is ss_0
    case_ss_0:
        oper&_0
        DEBUG_IF<1> ;// oper 0 must exit to a quick exit

    ;// two versions of case_sd_1
    IFIDN <rev>,<REVERSABLE>

        ;// xchange pointers and fall into next section
        ALIGN 4
        case_sd_1:
            xchg esi, edx

    ELSEIFIDN <rev>,<NONREVERSABLE>

        ;// can't xchg pointers, so do full expand
        ALIGN 4
        case_sd_1:
            mov eax, [esi]
            oper&_1_shortcut
            ;// fallthrough is have to do
            ;// oper_1 must summon OPER_ENTER/OPER_LEAVE -- becuase it might have been optimized away
            oper&_1

    ELSE
    .ERR <must be REVERSABLE or NONREVERSABLE>
    ENDIF

    ALIGN 4
    case_ds_2:
        mov eax, [edx]
        oper&_2_shortcut
        ;// fallthrough is have to do
        ;// oper_2 must summon OPER_ENTER/OPER_LEAVE -- becuase it might have been optimized away
        oper&_2

    ALIGN 4
    case_dd_3:

        OPER_ENTER    ;// here we summon OPER_ENTER/OPER_LEAVE
        oper&_3
        OPER_LEAVE

    ENDM


;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;////               esi points at X data
;////               edx points at Y data
;////   OPER_X        edi points at Z data        see additional notes above



;////////////////////////////////////////////////////////////////////////////////
;////
;////   ADDITION
;////

ADDITION_3 MACRO            ;// both inputs are changing
    invoke math_add_dXdB
    ENDM

ADDITION_2_shortcut MACRO    ;// eax has the value we want to check
    ;// x + 0 == x
    TESTJMP eax, eax, jz store_identity_pointer
    ;// there is no such number that x + i == const
    ;// there is no such number that x + i == inv(x)
    ENDM

ADDITION_2 MACRO            ;// only one input is changing
    OPER_ENTER
    invoke math_add_dXsB
    OPER_LEAVE
    ENDM

ADDITION_0 MACRO            ;// neither input is changing
    fld [esi]
    fadd [edx]
    fstp calc_temp_1
    jmp store_constant
    ENDM

;////////////////////////////////////////////////////////////////////////////////
;////
;////   MULTIPLY
;////

MULTIPLY_3 MACRO            ;// both inputs are changing
    mov ebx, edx
    invoke math_mul_dXdA
    ENDM

MULTIPLY_2_shortcut MACRO    ;// eax has the value we want to check
    ;// x * 1 == x
    ;// 00000198 3F800000                math_1      REAL4 1.0e+0
     CMPJMP eax, 03F800000h,    je store_identity_pointer
    ;// x * 0 == 0
    TESTJMP eax, eax, je store_zero
    ;// x * -1 == neg(x)
    ;// 00000160 BF800000                math_neg_1  REAL4 -1.0e+0
    CMPJMP eax, 0BF800000h, je store_negate_esi
    ENDM

MULTIPLY_2 MACRO            ;// only one input is changing
    OPER_ENTER
    mov ebx, edx
    invoke math_mul_dXsA
    OPER_LEAVE
    ENDM

MULTIPLY_0 MACRO            ;// neither input is changing
    fld [esi]
    fmul [edx]
    fstp calc_temp_1
    jmp store_constant
    ENDM

;////////////////////////////////////////////////////////////////////////////////
;////
;////   SUBTRACT
;////

SUBTRACT_3 MACRO            ;// both inputs are changing
    invoke math_sub_dXdB
    ENDM

SUBTRACT_2_shortcut MACRO    ;// eax has the value we want to check
    ;// x - 0 == x
    TESTJMP eax, eax, je store_identity_pointer
    ;// there is no such number that x - i == constant
    ;// there is no such number that x - i == inv(x)
    ENDM

SUBTRACT_2 MACRO            ;// only one input is changing
    OPER_ENTER
    invoke math_sub_dXsB
    OPER_LEAVE
    ENDM

SUBTRACT_1_shortcut MACRO    ;// eax has the value we want to check
    ;// there is no such number that n - x == x
    ;// there is no such number that n - x == const
    ;// 0 - x == neg x
    TESTJMP eax, eax, jz store_negate_edx
    ENDM

SUBTRACT_1 MACRO
    OPER_ENTER
    invoke math_sub_sXdB
    OPER_LEAVE
    ENDM

SUBTRACT_0 MACRO            ;// neither input is changing
    fld [esi]
    fsub [edx]
    fstp calc_temp_1
    jmp store_constant
    ENDM

;////////////////////////////////////////////////////////////////////////////////
;////
;////   AND
;////

LOGICAL_AND_3 MACRO            ;// both inputs are changing
    invoke math_bool_and_dXdB_ft
    ENDM

LOGICAL_AND_2_shortcut MACRO    ;// eax has the value we want to check
    ;// x AND true == x
    TESTJMP eax, eax, js store_identity_logical_esi    ;// true == sign bit
    ;// x AND false == false
    jmp store_false
    ;// there is no such number that x AND n == not(X)
    ENDM

LOGICAL_AND_2 MACRO
    DEBUG_IF<1>    ;// this code should NEVER be hit !!!
    ENDM

LOGICAL_AND_0 MACRO
    mov eax, [esi]
    and eax, [edx]
    js store_true
    jmp store_false
    ENDM

;////////////////////////////////////////////////////////////////////////////////
;////
;////   OR
;////

LOGICAL_OR_3 MACRO
    invoke math_bool_or_dXdB_ft
    ENDM

LOGICAL_OR_2_shortcut MACRO            ;// eax has the value we want to check
    ;// x OR false == x
    TESTJMP eax, eax, jns store_identity_logical_esi    ;// true == sign bit
    ;// x OR true == true
    js store_true
    ;// there is no such number that x OR n == not(X)
    ENDM

LOGICAL_OR_2 MACRO
    DEBUG_IF<1>    ;// this code should NEVER be hit !!!
    ENDM

LOGICAL_OR_0 MACRO
    mov eax, [esi]
    or eax, [edx]
    js store_true
    jmp store_false
    ENDM

;////////////////////////////////////////////////////////////////////////////////
;////
;////   XOR
;////

LOGICAL_XOR_3 MACRO
    invoke math_bool_xor_dXdB_ft
    ENDM

LOGICAL_XOR_2_shortcut MACRO    ;// eax has the value we want to check
    ;// x XOR false == x
    TESTJMP eax, eax, jns store_identity_logical_esi    ;// false == no sign bit
    ;// no such number n where x XOR n = const
    ;// x XOR true == not(x)    and we know eax is true
    jmp store_identity_logical_not_esi
    ENDM

LOGICAL_XOR_2 MACRO
    DEBUG_IF<1>    ;// this code should NEVER be hit !!!
    ENDM

LOGICAL_XOR_0 MACRO

    mov eax, [esi]
    xor eax, [edx]
    js store_true
    jmp store_false
    ENDM

;////////////////////////////////////////////////////////////////////////////////
;////
;////   COMPARE_LessThan
;////

COMPARE_LT_3 MACRO
    invoke math_bool_lt_dXdB_ft
    ENDM

COMPARE_LT_2_shortcut MACRO        ;// eax has the value we want to check
    ;// no such number n such that x < n = x
    ;// no such number n such that x < n = const
    ;// x < 0 = bool(x)
    TESTJMP eax, eax, jz store_identity_logical_esi
    ENDM

COMPARE_LT_2 MACRO
    OPER_ENTER
    invoke math_bool_lt_dXsB_ft
    OPER_LEAVE
    ENDM

COMPARE_LT_1_shortcut MACRO
    ;// eax has the value we want to check
    ;// no such number n such that n < x = x
    ;// no such number n such that n < x = const
    ;// no such number n such that n < x = inv(x)
    ENDM

COMPARE_LT_1 MACRO
    OPER_ENTER
    invoke math_bool_lt_sXdB_ft
    OPER_LEAVE
    ENDM

COMPARE_LT_0 MACRO
    fld [edx]    ;// Y false true
    fld [esi]    ;// X Y false true
    fucompp        ;// false true
    fnstsw ax
    sahf
    jb store_true
    jmp store_false
    ENDM

;////////////////////////////////////////////////////////////////////////////////
;////
;////   COMPARE_Equal
;////

COMPARE_E_3 MACRO
    invoke math_bool_eq_dXdB_ft
    ENDM

COMPARE_E_2_shortcut MACRO
    ;// eax has the value we want to check
    ;// no such number n such that x == n = x
    ;// no such number n such that x == n = const
    ;//        well really there is ... x==x = true ...
    ;//        but since we're in a case where one input x is changing
    ;//        and the other input y is not changing
    ;//        it's unlikely that x and y are _always_ the same value ...
    ;// no such number n such that x == n = inv(x)
    ENDM

COMPARE_E_2 MACRO
    OPER_ENTER
    invoke math_bool_eq_dXsB_ft
    OPER_LEAVE
    ENDM

COMPARE_E_0 MACRO
    mov eax, [edx]
    cmp eax, [esi]
    je store_true
    jmp store_false
    ENDM


;////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////
;///
;///
;///    calc


.DATA

    ;// we store temp output values here
    ;// the quick exit routines require it
    ALIGN 8
        calc_temp_1    dd    0
    ALIGN 8
        calc_temp_2    dd    0

    ;// jump table
    ALIGN 8
    calc_table LABEL DWORD
        dd calc_op_add
        dd calc_op_mult
        dd calc_op_sub

        dd calc_op_and
        dd calc_op_or
        dd calc_op_nand
        dd calc_op_nor
        dd calc_op_xor

        dd calc_op_lt
        dd calc_op_lte
        dd calc_op_gt
        dd calc_op_gte
        dd calc_op_e
        dd calc_op_ne

        dd calc_table_overrun
        dd calc_table_overrun

    ;// when we swap inputs for compare operations
    ;// we also have to swap the changing/notchanging status
    ;// this table does that
    calc_gt_translate LABEL DWORD
        dd    00y        ;// 00 --> 00
        dd    10y        ;// 01 --> 10
        dd    01y        ;// 10 --> 01
        dd    11y        ;// 11 --> 11



.CODE

    ;// just a trap for errors that should never happen
    ALIGN 16
    calc_table_overrun:
    int 3 ;// not supposed to be here !!


ASSUME_AND_ALIGN
osc_Math_Calc PROC ;// uses esi

    push esi    ;// must preserve!!

        GET_OSC_FROM ebx, esi
        ASSUME ebx:PTR OSC_MAP

        DEBUG_IF< !![ebx].pin_z.pPin >    ;// supposed to be connected

        lea edi, [ebx].z_data    ;// most routines require a pointer to our own data

    ;// get the attached pins, build ecx as changing summary,
    ;// and further dereference esi,edx to point at input data

        xor esi, esi
        xor edx, edx
        xor ecx, ecx

        OR_GET_PIN [ebx].pin_x.pPin, esi    ;// note that OR resets the carry flag
        .IF !ZERO?
            bt [esi].dwStatus, LOG2(PIN_CHANGING)    ;// xfer pin_changing into carry flag
            mov esi, [esi].pData
        .ELSE
            mov esi, math_pNull                ;// no attached pin, and carry is clear == no changing
        .ENDIF
        adc ecx, ecx    ;// shift carry into summary

        OR_GET_PIN [ebx].pin_y.pPin, edx
        .IF !ZERO?
            bt [edx].dwStatus, LOG2(PIN_CHANGING)
            mov edx, [edx].pData
        .ELSE
            mov edx, math_pNull
        .ENDIF
        adc ecx, ecx

    ;// now we figure out what object we are

        mov eax, [ebx].dwUser
        and eax, MATH_OP_TEST    ;// extract just the oper number

        .IF eax >= MATH_OP_AND ;// boolean outputs, load them now
            fld1        ;// +1
            test [ebx].dwUser, MATH_OUT_DIGITAL    ;// ZF set if BIPOLAR
            fchs        ;// -1 == true
            fldz        ;// 0    true
            jnz @F        ;// false for DIGITAL is 0
            fsub st, st(1) ;// 0--1 == +1 == false for BIPOLAR
        @@:                ;// false   true
        .ENDIF

    ;// all is set up
    ;// now jump to the handler

        jmp calc_table[eax*4]
        ASSUME esi:PTR DWORD    ;// X input data
        ASSUME edx:PTR DWORD    ;// Y input data
        ASSUME edi:PTR DWORD    ;// our Z output data

    ALIGN 8
    calc_op_add::    OSCMATH_CALC REVERSABLE, ADDITION

    ALIGN 8
    calc_op_mult::  OSCMATH_CALC REVERSABLE, MULTIPLY

    ALIGN 8
    calc_op_sub::    OSCMATH_CALC NONREVERSABLE, SUBTRACT

    ALIGN 8
    calc_op_nand::    fxch            ;// swap output and fall into regular AND
    ALIGN 8
    calc_op_and::    OSCMATH_CALC REVERSABLE, LOGICAL_AND

    ALIGN 8
    calc_op_nor::    fxch            ;// swap output and fall into regular OR
    ALIGN 8
    calc_op_or::    OSCMATH_CALC REVERSABLE, LOGICAL_OR

    ALIGN 8
    calc_op_xor::    OSCMATH_CALC REVERSABLE, LOGICAL_XOR

    ALIGN 8
    calc_op_lte::    fxch            ;// swap output and fall into regular gt
    ALIGN 8
    calc_op_gt::    xchg esi, edx    ;// swap source fall into next case
                    fxch            ;// -- clumsy, but saves a jump
                    ;// since we've swapped inputs, we have to swap status
                    mov ecx, calc_gt_translate[ecx*4]
    ALIGN 8
    calc_op_gte::    fxch            ;// swap output and fall into regular lt
    ALIGN 8
    calc_op_lt::    OSCMATH_CALC NONREVERSABLE, COMPARE_LT


    ALIGN 8
    calc_op_ne::     fxch            ;// swap output and fall into regular eq
    ALIGN 8
    calc_op_e::        OSCMATH_CALC REVERSABLE, COMPARE_E

    ;/////////////////////////
    ;// all routes end up here
    ;/////////////////////////

    ALIGN 8
    calc_done:

    ;// that's it

    pop esi

        ret

    ;//////////////////////////////////
    ;// following are the 'quick exits'
    ;//////////////////////////////////


    ;// store esi by transfering the pointer to z.pData
    ;// esi must point at the data
    ;// implies changing output data
    ;// we assume the fpu is empty
    ALIGN 8
    store_identity_pointer:
        mov [ebx].pin_z.pData, esi
        or [ebx].pin_z.dwStatus, PIN_CHANGING
        jmp calc_done

    ;// look at data in esi or edx and store true,false
    ;// we assume the fpu has false,true stored in it
    ;// implies changing data
    ALIGN 8
    store_identity_logical_not_edx: ;// never happens but when it does, we're ready for it
        xchg esi, edx
    ALIGN 8
    store_identity_logical_not_esi:
        fxch                        ;// 'not' just swaps true and false
        xchg esi, edx                ;// clumsy, but prevents another jump
    ALIGN 8
    store_identity_logical_edx:
        xchg esi, edx
    ALIGN 8
    store_identity_logical_esi:

        mov [ebx].pin_z.pData, edi
        or [ebx].pin_z.dwStatus, PIN_CHANGING

        invoke math_bool_dX_ft

        jmp calc_done


    ;// are to store the negated value of the input
    ;// we assume the FPU is empty
    ;// implies changing data of our own
    ALIGN 8
    store_negate_edx:    ;// negate edx
        xchg esi, edx
    ALIGN 8
    store_negate_esi:    ;// negate esi

        mov [ebx].pin_z.pData, edi
        or [ebx].pin_z.dwStatus, PIN_CHANGING

        invoke math_neg_dX

        jmp calc_done


    ;// we are to store true or false
    ;// implies non changing data
    ;// FPU must have false,true stored in it
    ;// we will unload the fpu
    ;// then fall into store_constant
    ALIGN 8
    store_true:
        fxch
    ALIGN 8
    store_false:
        ;// we are to store false
        ;// implies non changing data
        fstp calc_temp_1    ;// false
        fstp calc_temp_2    ;// true
    ;// calc_temp_1 must have the value to store
    ;// implies non changing data
    ;// assume that edi points at our own data
    ;// fpu must be empty
    ALIGN 8
    store_constant:

        comment ~ /*

        the value in calc_temp_1 is deemed to be const for the entire output frame
        unless it is a 'special value' we are to store to our own data frame (edi)
        we are to make sure that we have filled with current value

        we look at pin_z prev changing (pc) for clues
            if pc was true -- previously changing
            then we have to fill
        otherwise, if the new value is not the same as the old
            then we fill
        we must also check if previous pin_z.pData points at ourself
            if it does not, then pc does not apply
            and we must fill to be safe

        */ comment ~

        ;// load the value we are to fill

        mov eax, calc_temp_1

        ;// look for 'special values'
        TESTJMP eax, eax,        jz store_zero
        CMPJMP eax, 03F800000h, je store_posone
         CMPJMP eax, 0BF800000h,    je store_negone

        ;// not special -- check if prev pData also pointed at ourselves
        CMPJMP  edi, [ebx].pin_z.pData, jne sc_must_fill_0

        ;// same pData -- see if it was changing
        TESTJMP [ebx].pin_z.dwStatus, PIN_CHANGING, jnz sc_must_fill_1

        ;// it was not changing -- see if it's the same value
        CMPJMP  eax, [edi], jne sc_must_fill_2
        jmp calc_done

        sc_must_fill_0:    mov [ebx].pin_z.pData, edi
        sc_must_fill_1:    and [ebx].pin_z.dwStatus, NOT PIN_CHANGING
        sc_must_fill_2:    mov ecx, SAMARY_LENGTH

            rep stosd
            jmp calc_done

    ;// data is to be zero
    ;// point at pNullData
    ;// implies non changing data
    ;// we assume the FPU is empty
    ALIGN 8
    store_zero:
        mov eax, math_pNull
        and [ebx].pin_z.dwStatus, NOT PIN_CHANGING
        mov [ebx].pin_z.pData, eax
        jmp calc_done

    ;// data is to be +1
    ;// implies non changing data
    ;// we assume the FPU is empty
    ALIGN 8
    store_posone:
        mov eax, math_pPosOne
        and [ebx].pin_z.dwStatus, NOT PIN_CHANGING
        mov [ebx].pin_z.pData, eax
        jmp calc_done

    ;// data is to be -1
    ;// implies non changing data
    ;// we assume the FPU is empty
    ALIGN 8
    store_negone:
        mov eax, math_pNegOne
        and [ebx].pin_z.dwStatus, NOT PIN_CHANGING
        mov [ebx].pin_z.pData, eax
        jmp calc_done



osc_Math_Calc ENDP




ASSUME_AND_ALIGN

ENDIF   ;// USE_THIS_FILE
END

