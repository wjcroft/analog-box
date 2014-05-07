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
;//     ABOX242 AJT
;//         manually set operand size for masm 9
;//
;//##////////////////////////////////////////////////////////////////////////
;//
;// ABox_Slider.asm
;//
;//
;// TOC
;// slider_GetUnit
;// slider_PrePlay
;// slider_Ctor
;// slider_Calc
;// slider_Render
;// slider_InitRasters
;// slider_SetOrientation
;// slider_SetSource
;// slider_SyncPins
;// slider_SetValue
;// slider_SetShape
;// slider_HitTest
;// slider_Control
;// slider_InitMenu
;// slider_Command
;// slider_SaveUndo
;// slider_LoadUndo



OPTION CASEMAP:NONE

.586
.MODEL FLAT

USE_THIS_FILE equ 1

IFDEF USE_THIS_FILE

    .NOLIST
    include <Abox.inc>
    .LIST
    include <abox_knob.inc> ;// need access to the plus and multiply fonts

.DATA

;// the slider position is stored in dwUser (0-128)
;// the last value is in X.dwUser
;// a bCurrent flag is the next byte, and means 'value correct' if al==ah



comment ~ /*

    case        formula                             when to change  who changes it
    ----------  ----------------------------------  --------------- --------------
    horizontal  H0 = H_LEFT + H_TOP * bmp_width     (fixed)         InitRasters
                H1 = H_CENTER + H_TOP * bmp_width   (fixed)         InitRasters
                RH = (RH_HEIGHT-RH_TOP) * bmp_width (fixed)         InitRasters

    dwUser2     Rofs = RH * bmp_width               (orientation)   SetOrientation
    dwUser3     pShape                              (orientation)   SetOrientation
    dwUser4     P0 = H0 + val                       (value)         SetValue


    case        formula                             when to change  who changes it
    ----------  ----------------------------------  --------------- --------------
    vertical    V0 = V_LEFT + V_BOTTOM * bmp_width  (fixed)         InitRasters
                V1 = V_LEFT + V_MIDDLE * bmp_width  (fixed)         InitRasters
                RV = RV_WIDTH - RV_LEFT             (fixed)         InitRasters

    dwUser2     Rofs = RV                           (orientation)   SetOrientation
    dwUser3     pShape                              (orientation)   SetOrientation
    dwUser4     P0 = V0 + (val-128) * bmp_width     (value)         SetValue

*/ comment ~


SLIDER_DATA STRUCT

    R0      dd  0
    pShape  dd  0
    P0      dd  0

SLIDER_DATA ENDS



osc_Slider  OSC_CORE { slider_Ctor,,slider_PrePlay,slider_Calc }
            OSC_GUI  { slider_Render,slider_SetShape,
                        slider_HitTest,slider_Control,,
                        slider_Command,slider_InitMenu,,,
                        slider_SaveUndo,slider_LoadUndo,slider_GetUnit }
            OSC_HARD { }

    BASE_FLAGS = BASE_SHAPE_EFFECTS_GEOMETRY

    ;// don't make lines too long
    ofsPinData  = SIZEOF OSC_OBJECT + SIZEOF APIN * 2
    ofsOscData  = SIZEOF OSC_OBJECT + SIZEOF APIN * 2 + SAMARY_SIZE
    oscBytes    = SIZEOF OSC_OBJECT + SIZEOF APIN * 2 + SAMARY_SIZE + SIZEOF SLIDER_DATA

    OSC_DATA_LAYOUT { NEXT_Slider ,
        IDB_SLIDER,OFFSET popup_SLIDER,BASE_FLAGS,
        2, 4,
        ofsPinData,
        ofsOscData,
        oscBytes  }

    OSC_DISPLAY_LAYOUT {slider_container_h, SLIDER_PSOURCE_000, ICON_LAYOUT(2,0,2,1)}

    APIN_init { 0.0,,'=',, PIN_OUTPUT OR UNIT_AUTO_UNIT}
    APIN_init {-1.0,,'+',, UNIT_AUTO_UNIT }

    short_name  db  'Slider',0
    description db  'May be a slider, adder or multiplier. Use mouse and cursor keys to adjust. ',0
    ALIGN 4

    ;// values for dwUser:
    ;// lower byte is current
    ;// next byte is new position
    ;// upper WORD for options


        SLIDER_VERTICAL     equ     00010000h   ;// on = vertical
        SLIDER_RANGE1       equ     00020000h   ;// on = -1 to +1
        SLIDER_RANGE2       equ     00040000h   ;// on = +1 to -1
                            ;// note that range 1 and 2 are exclusive
                            ;// range bits and orientation must be sequential

        SLIDER_RANGE_TEST equ SLIDER_RANGE1 OR SLIDER_RANGE2

        SLIDER_OP_ADD       equ     00100000h   ;// add
        SLIDER_OP_MULT      equ     00200000h   ;// multiply

        SLIDER_OP_TEST      equ SLIDER_OP_ADD OR SLIDER_OP_MULT


    ;// there are 6 psources we keep track of
    ;// based on 3 bits of dwUser

        slider_psource LABEL DWORD

        dd  SLIDER_PSOURCE_000  ;// horz  0 to +1   0+0+0
        dd  SLIDER_PSOURCE_001  ;// vert  0 to +1   0+0+1
        dd  SLIDER_PSOURCE_100  ;// horz -1 to +1   0+2+0   reverse due to graphics mishap
        dd  SLIDER_PSOURCE_011  ;// vert -1 to +1   0+2+1
        dd  SLIDER_PSOURCE_010  ;// horz +1 to -1   4+0+0   reverse due to graphics mishap
        dd  SLIDER_PSOURCE_101  ;// vert +1 to -1   4+0+1
        ;// 110 and 111 are error and are not included here

        SLIDER_SOURCE_TEST  equ SLIDER_VERTICAL OR SLIDER_RANGE1 OR SLIDER_RANGE2
        SLIDER_SOURCE_SHIFT equ LOG2(SLIDER_VERTICAL)-2

    ;// added abox224
    ;// for keyboard control (1 and 0) we use a table to define where the position should be

        slider_keyboard_zero_table LABEL BYTE
                    ;//     orin 00 40 80
            db  0   ;// 000 horz 00 .5 +1
            db  80h ;// 001 vert +1 .5 00
            db  40h ;// 010 horz -1 00 +1
            db  40h ;// 011 vert +1 00 -1
            db  40h ;// 100 horz +1 00 -1
            db  40h ;// 101 vert -1 00 +1
            db  0h  ;// 110 err
            db  0h  ;// 111 err

        slider_keyboard_one_table LABEL BYTE
                    ;//     orin 00 40 80
            db  80h ;// 000 horz 00 .5 +1
            db  0h  ;// 001 vert +1 .5 00
            db  80h ;// 010 horz -1 00 +1
            db  0h  ;// 011 vert +1 00 -1
            db  0h  ;// 100 horz +1 00 -1
            db  80h ;// 101 vert -1 00 +1
            db  0h  ;// 110 err
            db  0h  ;// 111 err

comment ~ /*


the slider value

    the slider value is only 7 bits and ALWAYS represents the PIXEL distance
    from the CORNER of the value bar. Backwards compatabilty issues require this scheme.

    for the different ranges, an offset of 64 may be subtracted to get the signed offset

drawing the slider

    osc_Render will draw the background

    slider_Render must draw thw value bar and the slider
    given the value scheme, simply multiply bmp_width by al

    sequence:

        starting at pDest, add a cached offset to get to the reference point
        the cached offset is based on val and is set by ...

        the resulting value (P0) is either

            (vert)  (top or bottom) left
            (horz)  (top) (right or left)

            so there are four ways to draw the value bar

        P0 is then offset by a fixed value to get to R0
        R0 is the start point for drawing the slider

            shape_Fill can do the drawing from there



    table of offsets and where things are stored


    case        formula                             when to change  who changes it
    ----------  ----------------------------------  --------------- --------------
    horizontal  H0 = H_LEFT + H_TOP * bmp_width     (fixed)         InitRasters
                H1 = H_CENTER + H_TOP * bmp_width   (fixed)         InitRasters
                RH = (RH_HEIGHT-RH_TOP) * bmp_width (fixed)         InitRasters

    dwUser2     Rofs = RH * bmp_width               (orientation)   SetOrientation
    dwUser3     pShape                              (orientation)   SetOrientation
    dwUser4     P0 = H0 + val                       (value)         SetValue


    case        formula                             when to change  who changes it
    ----------  ----------------------------------  --------------- --------------
    vertical    V0 = V_LEFT + V_BOTTOM * bmp_width  (fixed)         InitRasters
                V1 = V_LEFT + V_MIDDLE * bmp_width  (fixed)         InitRasters
                RV = RV_WIDTH - RV_LEFT             (fixed)         InitRasters

    dwUser2     Rofs = RV                           (orientation)   SetOrientation
    dwUser3     pShape                              (orientation)   SetOrientation
    dwUser4     P0 = V0 + (val-128) * bmp_width     (value)         SetValue


*/ comment ~

    ;// equates to save some confusion

    ;// slider_R0 TEXTEQU <dwUser2>
    ;// slider_shape TEXTEQU <dwUser3>
    ;// slider_P0 TEXTEQU <dwUser4>

    ;// common layout values (based on the bitmaps)

        SLIDER_H_LEFT   equ 4
        SLIDER_H_CENTER equ 68  ;// from very left
        SLIDER_H_RIGHT  equ 132 ;// from very left

        SLIDER_H_TOP    equ 4
        SLIDER_RH_HEIGHT equ 8  ;// from very top

        SLIDER_V_LEFT   equ 4
        SLIDER_RV_WIDTH equ 8   ;// from very left

        SLIDER_V_TOP    equ 4
        SLIDER_V_MIDDLE equ 68  ;// from very top
        SLIDER_V_BOTTOM equ 132 ;// from very top

    ;// instance specific values

        slider_H0   dd  0
        slider_H1   dd  0
        slider_RH   dd  0

        slider_V0   dd  0
        slider_V1   dd  0
        slider_RV   dd  0

    ;// and here's where the mouse parameters live

        SLIDER_MIN_MOUSE equ 6  ;// must be closer than this
        slider_mouse_start dd 0 ;// used to track the mouse position


comment ~ /*

RECT drawing dib_FillRect_ptr_ptr_height
                                                        (always 6 rows)
    detail              start           stop            height
    ----------------    -----------     ---------       ------------------------
    000 horz,  0to+1    pDest+H0        start+val       6
    010 horz, -1to+1    pDest+[P0|H1]   pDest+[H1|P0]   6   (swap if start>stop)
    100 horz, +1to-1    pDest+[P0|H1]   pDest+[H1|P0]   6   (swap if start>stop)

                                        (always 6 wide)
    detail              start           stop        height
    ----------------    -----------     ---------   ------------------------
    001 vert,  0to+1    pDest+P0        start+6     128 - val
    010 vert, -1to+1    pDest+[V1|P0]   start+6      64 - val
    100 vert, +1to-1    pDest+[V1|P0]   start+6     val - 64


    slide:

        is always drawn at pDest + P0 + R0


*/ comment ~


;// the slider gets it's own pair of custom shapes
;// these are not used for hit testing, only for drawing
;// these get initialized in slider_InitRasters

    slider_horz_mask LABEL RASTER_LINE

        ;//        {jmp,wrp ,dw},{jmp,wrp ,dw}
        RASTER_LINE{  2,    ,0 }
        RASTER_LINE{  4, -3 ,0 }
        RASTER_LINE{  6, -5 ,0 }
        RASTER_LINE{  3, -7 ,0 },{ 3 , 2 , 0 }
        RASTER_LINE{  3, -9 ,0 },{ 3 , 4 , 0 }
        RASTER_LINE{  2, -10,0 },{ 2 , 6 , 0 }
        RASTER_LINE{  2, -10,0 },{ 2 , 6 , 0 }
        RASTER_LINE{  2, -10,0 },{ 2 , 6 , 0 }
        RASTER_LINE{  2, -10,0 },{ 2 , 6 , 0 }
        RASTER_LINE{  2, -10,0 },{ 2 , 6 , 0 }
        RASTER_LINE{  2, -10,0 },{ 2 , 6 , 0 }
        RASTER_LINE{ 10, -10,2 }
        RASTER_LINE{ 10, -10,2 }
        RASTER_LINE{ }  ;// exit record

        SLIDER_HORZ_MASK_COUNT equ 21

    slider_vert_mask LABEL RASTER_LINE

        ;//        {jmp,wrp ,dw},{jmp,wrp ,dw}
        RASTER_LINE{  9,    ,2 }
        RASTER_LINE{ 10, -10,2 }
        RASTER_LINE{  3, -11,0 },{ 2 , 6  ,0 }
        RASTER_LINE{  3, -12,0 },{ 2 , 7  ,0 }
        RASTER_LINE{  3, -13,0 },{ 2 , 8  ,0 }
        RASTER_LINE{  3, -13,0 },{ 2 , 8  ,0 }
        RASTER_LINE{  3, -12,0 },{ 2 , 7  ,0 }
        RASTER_LINE{  3, -11,0 },{ 2 , 6  ,0 }
        RASTER_LINE{ 10, -10,2 }
        RASTER_LINE{  9, -9 ,2 }
        RASTER_LINE{ }  ;// exit record

        SLIDER_VERT_MASK_COUNT equ 16

    ;// there are two pfonts we keep track of

    ;// slider_pfont_add    dd  0
    ;// slider_pfont_mul    dd  0

    ;// scaling values for calculating

    ;// slider_scale_00X    TEXTEQU <math_1_128>    ;// digital x scale for changing x from position to normalized
    ;// slider_scale_01X    TEXTEQU <math_1_64>     ;// bipolar x scale for changing x from position to normalized
    ;// slider_scale_10X    TEXTEQU <math_neg_1_64> ;// reverse bipolar scale

    ;// OSC_SLIDER_MAP for this object

        OSC_SLIDER_MAP STRUCT

                OSC_OBJECT  {}
            pin_X   APIN    {}
            pin_A   APIN    {}
            data_X  dd      SAMARY_LENGTH dup (0)
            slider  SLIDER_DATA {}

        OSC_SLIDER_MAP ENDS




;///////////////////////////////////////////////////////////////////////////////////////

.CODE

;///////////////////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
slider_GetUnit PROC

        ASSUME esi:PTR OSC_SLIDER_MAP
        ASSUME ebx:PTR APIN

        OSC_TO_PIN_INDEX esi, ecx, 0
        .IF ecx == ebx
            add ecx, SIZEOF APIN
        .ENDIF


        mov eax, [ecx].dwStatus
        BITT eax, UNIT_AUTOED

        ret

slider_GetUnit ENDP



;///////////////////////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
slider_PrePlay PROC

    ASSUME esi:PTR OSC_SLIDER_MAP

    ;// set our state as changing, so we force an update of the value

    xor eax, eax
    mov al, BYTE PTR [esi].dwUser   ;// load the position
    not al                          ;// set as need to calc
    mov BYTE PTR [esi+1].dwUser,al  ;// save in flag

    or [esi].pin_X.dwStatus, PIN_CHANGING   ;// set as pin changing
    xor eax, eax                    ;// so play_start will erase our data
    mov [esi].pin_X.dwUser, eax         ;// reset the last value

    ret     ;// return zero

slider_PrePlay ENDP






;///////////////////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
slider_Ctor PROC

        ;// register call
        ASSUME ebp:PTR LIST_CONTEXT ;// preserve
        ASSUME esi:PTR OSC_OBJECT   ;// preserve
        ASSUME edi:PTR OSC_BASE     ;// may destroy
        ASSUME ebx:PTR FILE_OSC     ;// may destroy
        ASSUME edx:PTR FILE_HEADER  ;// may destroy

    ;// make sure we reset the previous value

        invoke slider_PrePlay

    ;// that's it

        ret

slider_Ctor ENDP

;///////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////
;////
;////                   model: get from prev value (pin_X.dwUser)
;////     C A L C              to new value (dwUser)
;////
;////

comment ~ /*

    calc states

    M = mode    s slider
                a add
                m mul

    X = input   d changing                / sM dX dV \
                s static                  | aM sX sV |
                z zero                    | mM zX zV |
                n not connected           \    nX    /
                x don't care

    V = value   d different
                s same
                z zero


    sMxXdV      build_ramp
    sMxXsV      store_static

    aM dX dV    build_ramp  math_add_dXdA
    mM dX dV    build_ramp  math_mul_dXdA
    aM sX dV    build_ramp  math_add_dXsA
    mM sX dV    build_ramp  math_mul_dXsA
    aM nX dV    build_ramp
    mM nX dV    store_static(zero)

    aM dX sV
    mM dX sV
    aM sX sV
    mM sX sV
    aM nX sV
    mM nX sV

    build_ramp always builds to the X output
    fpu must be loaded with start and stop range
    the start and stop values may be scaled by the input if required

    a subsequenct call to math_mul_dX...
    may then do the appropriate math op



*/ comment ~

.DATA

    ;// ramp stop start builders
    slider_calc_1   dd  sc1_000, sc1_001, sc1_010, sc1_011, sc1_100, sc1_101

    ;// op with ramp
    slider_calc_2   dd  sc2_nXaMdV,sc2_sXaMdV,sc2_dXaMdV,sc2_nXmMdV,sc2_sXmMdV,sc2_dXmMdV

    ;// op with no ramp
    slider_calc_3   dd  sc3_nXaMsV,sc3_sXaMsV,sc3_dXaMsV,sc3_nXmMsV,sc3_sXmMsV,sc3_dXmMsV

.CODE


ASSUME_AND_ALIGN
slider_Calc PROC

    ASSUME esi:PTR OSC_SLIDER_MAP

    DEBUG_IF < !!( [esi].pin_X.pPin ) >     ;// supposed to be connected

    lea edi, [esi].data_X   ;// get the data pointer

    ;// build the ramp first

    xor eax, eax
    mov al, BYTE PTR [esi].dwUser
    mov ah, BYTE PTR [esi+1].dwUser
    cmp ah, al
    je dont_do_ramp


    ;////////////////////////////////////////////////////////////////////
    ;//
    ;//
    ;//     ramp
    ;//
    ;// have to build a ramp

        mov BYTE PTR [esi+1].dwUser, al ;// store new value
        xor ah, ah                      ;// clear ah
        fld [esi].pin_X.dwUser          ;// load the last slider value

    ;// set up for the jump

        mov ecx, [esi].dwUser       ;// load dwUser
        and ecx, SLIDER_SOURCE_TEST ;// strip out extra
        shr ecx, SLIDER_SOURCE_SHIFT;// scoot into place
        push eax
        jmp slider_calc_1[ecx]      ;// leap

    sc1_000::   ;// horz    0 to 1      ;// value = val/128

        fld math_1_128
        fimul DWORD PTR [esp]
        jmp do_the_ramp

    sc1_001::   ;// vert    0 to 1      ;// value = val/128 - 1

        fld math_1
        fld math_1_128
        fimul DWORD PTR [esp]
        fsub
        jmp do_the_ramp

    sc1_010::   ;// horz    -1 to +1    ;// value = val/64 - 1
    sc1_101::   ;// vert    +1 to -1    ;// value = val/64 - 1

        fld math_1
        fld math_1_64
        fimul DWORD PTR [esp]
        fsubr
        jmp do_the_ramp

    sc1_011::   ;// vert    -1 to +1    ;// value = 1-val/64
    sc1_100::   ;// horz    +1 to -1    ;// value = 1-val/64

        fld math_1
        fld math_1_64
        fimul DWORD PTR [esp]
        fsub

    do_the_ramp:

        pop eax                 ;// clean up the stack
        fst [esi].pin_X.dwUser  ;// always store the new slider value

    ;// now the ramp stop and start are built
    ;// now determine how we containue

        mov edx, [esi].dwUser
        and edx, SLIDER_OP_TEST ;// check for operation
        jz sc2_nXaMdV           ;// jump to just plain old ramp

            ;// dXaMdV  sXaMdV  nXaMdV
            ;// dXmMdV  sXmMdV  nXmMdV

            xor ecx, ecx
            .IF edx==SLIDER_OP_MULT
                mov ecx, 3
            .ENDIF
            OSCMAP_TO_PIN_DATA esi, ebx, pin_A, 0

            jmp slider_calc_2[ecx*4]

        sc2_dXaMdV::    ;// add mode with changing data

            mov edx, ebx
            invoke math_ramp_add_dB
            or [esi].pin_X.dwStatus, PIN_CHANGING
            jmp all_done

        sc2_sXaMdV::    ;// add mode, static input
                        ;// so we add the first value to both start and stop

            fld DWORD PTR [ebx]
            fadd st(2), st
            fadd

            ;// fall into next section

                        ;// no operation, or
        sc2_nXaMdV::    ;// add mode, but no pin
                        ;// so we call math_ramp

            invoke math_ramp
            or [esi].pin_X.dwStatus, PIN_CHANGING
            jmp all_done

        sc2_dXmMdV::    ;// mult mode with changing input

            invoke math_ramp_mul_dA
            or [esi].pin_X.dwStatus, PIN_CHANGING
            jmp all_done

        sc2_sXmMdV::    ;// mult mode with static input
                        ;// scale both start and stop

            test DWORD PTR [ebx], 7FFFFFFFh ;// check for zero
            jz sc2_nXmMdV                   ;// jump to store zero code

            fld DWORD PTR [ebx] ;// get the scale value
            fmul st(2), st
            fmul
            jmp sc2_nXaMdV  ;// jump to ramp call


        sc2_nXmMdV::    ;// mult mode with no input
                        ;// store zero
            fstp st
            fstp st
            xor eax, eax
            jmp store_static

    ;//
    ;//
    ;//     ramp
    ;//
    ;////////////////////////////////////////////////////////////////////



    ;////////////////////////////////////////////////////////////////////
    ;//
    ;//
    ;//     no ramp
    ;//


    dont_do_ramp:   ;// slider value hasn't changed

        mov edx, [esi].dwUser
        and edx, SLIDER_OP_TEST ;// check for operation
        jz sc3_nXaMsV           ;// jump to just plain old value

            ;// dXaMsV  sXaMsV  nXaMsV
            ;// dXmMsV  sXmMsV  nXmMsV

            xor ecx, ecx
            .IF edx==SLIDER_OP_MULT
                mov ecx, 3
            .ENDIF
            OSCMAP_TO_PIN_DATA esi, ebx, pin_A, 0

            jmp slider_calc_3[ecx*4]

        sc3_dXaMsV::    ;// add mode with changing data

            push esi
            lea edx, [esi].pin_X.dwUser ;// constant value
            mov esi, ebx                ;// source data
            invoke math_add_dXsB
            pop esi
            or [esi].pin_X.dwStatus, PIN_CHANGING
            jmp all_done

        sc3_sXaMsV::    ;// add mode, static input
                        ;// so we compute one value

            push eax
            fld DWORD PTR [ebx]
            fadd [esi].pin_X.dwUser
            fstp DWORD PTR [esp]
            pop eax
            jmp store_static

                        ;// no operation, or
        sc3_nXaMsV::    ;// add mode, but no pin

            mov eax, [esi].pin_X.dwUser
            jmp store_static

        sc3_dXmMsV::    ;// mult mode with changing input

            push esi
            lea edx, [esi].pin_X.dwUser ;// constant value
            mov esi, ebx                ;// source data
            mov ebx, edx
            invoke math_mul_dXsA
            pop esi
            or [esi].pin_X.dwStatus, PIN_CHANGING
            jmp all_done

        sc3_sXmMsV::    ;// mult mode with static input
                        ;// scale both start and stop

            test DWORD PTR [ebx], 7FFFFFFFh ;// check for zero
            jz sc3_nXmMsV                   ;// jump to store zero code

            push eax
            fld DWORD PTR [ebx]     ;// get the scale value
            fmul [esi].pin_X.dwUser
            fstp DWORD PTR [esp]
            pop eax
            jmp store_static

        sc3_nXmMsV::    ;// mult mode with no input
                        ;// store zero
            xor eax, eax
            jmp store_static

    ;//
    ;//
    ;//     no ramp
    ;//
    ;////////////////////////////////////////////////////////////////////

    ALIGN 16
    store_static:

        btr [esi].pin_X.dwStatus, LOG_PIN_CHANGING  ;// reset and check previous changing
        jc @F                       ;// have to store if was changing
        cmp eax, DWORD PTR [edi]    ;// compare new value old
        je all_done                 ;// if same, then no need to store
    @@: mov ecx, SAMARY_LENGTH  ;// have to fill
        rep stosd
        jmp all_done

    ALIGN 16
    all_done:

        ret

slider_Calc ENDP


;///////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////



.DATA

    ;// each of the branches represents a method of calculating the
    ;// start stop hieght values for a call to dib_FillRect_ptr_ptr_height

    slider_render_jump dd   sr_000, sr_001, sr_010, sr_011, sr_100, sr_101

.CODE

ASSUME_AND_ALIGN
slider_Render PROC  ;// STDCALL uses esi edi pObject:ptr OSC_OBJECT

        ASSUME esi:PTR OSC_SLIDER_MAP

    ;// blit the back ground

        invoke gdi_render_osc   ;// blit the background

    ;// draw the value bar

        mov ecx, [esi].dwUser
        mov ebx, gdi_pDib
        movzx edx, BYTE PTR [esi].dwUser

        and ecx, SLIDER_SOURCE_TEST
        mov eax, [esi].pDest
        shr ecx, SLIDER_SOURCE_SHIFT

        jmp slider_render_jump[ecx]

comment ~ /*                                            (always 6 rows)
    detail              start           stop            height
    ----------------    -----------     ---------       ------------------------
 sr_000 horz,  0to+1    pDest+H0        start+val       6
 sr_010 horz, -1to+1    pDest+[P0|H1]   pDest+[H1|P0]   6   (swap if start>stop)
 sr_100 horz, +1to-1    pDest+[P0|H1]   pDest+[H1|P0]   6   (swap if start>stop)
*/ comment ~

    ;// state: ecx has jump index
    ;//         edx has value
    ;//         eax is pDest
    ;//         ebx is the gdi_pDib

    sr_000::

        or edx, edx
        jz done_with_bar
        pushd 6             ;// store the height
        push edx            ;// store the offset for the end
        add eax, slider_H0  ;// add pDest with H0 = P0
        push eax            ;// store it
        add [esp+4], eax    ;// add the start to the offset
        jmp draw_the_bar    ;// jump to bar drawing code

    sr_010::
    sr_100::

        cmp edx, 64
        je done_with_bar
        mov ecx, [esi].slider.P0;// P0  start
        mov edx, slider_H1      ;// H1  stop
        .IF ecx > edx
            xchg ecx, edx
        .ENDIF
        add edx, eax
        add ecx, eax
        pushd 6             ;// height
        push edx            ;// stop
        push ecx            ;// start
        jmp draw_the_bar

comment ~ /*                            (always 6 wide)
    detail              start           stop        height
    ----------------    -----------     ---------   ------------------------
 sr_001 vert,  0to+1    pDest+P0        start+6     128 - val
 sr_010 vert, -1to+1    pDest+[V1|P0]   start+6      64 - val
 sr_100 vert, +1to-1    pDest+[V1|P0]   start+6     val - 64
*/ comment ~

    ;// state: ecx has jump index
    ;//         edx has value
    ;//         eax is pDest
    ;//         ebx is the gdi_pDib

    sr_001::

        sub edx, 128            ;// adjust to go up
        jz done_with_bar        ;// if zero, nothing to draw
        neg edx                 ;// make positive
        add eax, [esi].slider.P0;// P0
        push edx                ;// store the height
        pushd 6                 ;// store the width
        push eax                ;// store P0
        add [esp+4], eax        ;// add P0 to width (=stop)
        jmp draw_the_bar

    sr_011::
    sr_101::

        sub edx, 64
        jz done_with_bar
        .IF SIGN?           ;// val is ABOVE V1
            neg edx
            push edx            ;// store the height
            pushd 6             ;// store the width
            add eax, [esi].slider.P0;// offset pDest, by P0
        .ELSE               ;// val is BELOW V1
            push edx
            pushd 6
            add eax, slider_V1
        .ENDIF

        push eax            ;// store the start
        add [esp+4], eax    ;// add start to width (=stop)

    draw_the_bar:

        mov eax, COLOR_OSC_1 + COLOR_OSC_1 SHL 8 + COLOR_OSC_1 SHL 16 + COLOR_OSC_1 SHL 24
        invoke dib_FillRect_ptr_ptr_height

    done_with_bar:

    ;// draw the control

    ;// determine where to draw, and what color to draw with

        mov edi, [esi].pDest
        add edi, [esi].slider.R0        ;// R0
        mov ebx, [esi].slider.pShape    ;// pShape
        mov eax, COLOR_OSC_2 + COLOR_OSC_2 SHL 8 + COLOR_OSC_2 SHL 16 + COLOR_OSC_2 SHL 24
        add edi, [esi].slider.P0

        .IF esi == osc_hover && app_bFlags & APP_MODE_CON_HOVER
            mov eax, F_COLOR_OSC_HOVER
        .ENDIF
        ;// esi won't be destroyed by this
        ;// because we're drawing a non optimizable shape
        invoke shape_Fill


    ;// that's it

        ret

slider_Render ENDP


;///////////////////////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
slider_InitRasters PROC

    ;// this initialized the slider rasters
    ;// all it does is add the gdi_bmp.siz.y to the wrap values
    ;// then determines how to offset the first value

    ASSUME edx:PTR RASTER_LINE

;// do the rasters

    ;// HORZ
    ;//
    ;// fill in the table by adding the bmp width to the wraps

        lea edx, slider_horz_mask
        mov ecx, SLIDER_HORZ_MASK_COUNT
        mov eax, gdi_bitmap_size.x

        .REPEAT

            .IF [edx].dest_wrap & 80000000h ;// only do neg values
                add [edx].dest_wrap, eax
            .ENDIF

            add edx, SIZEOF RASTER_LINE
            dec ecx

        .UNTIL ZERO?

    ;// set the initial displacement

        mov slider_horz_mask.dest_wrap, -1

    ;// VERT
    ;//
    ;// fill in the table by adding the bmp width to the wraps

        lea edx, slider_vert_mask
        mov ecx, SLIDER_VERT_MASK_COUNT

        .REPEAT

            .IF [edx].dest_wrap & 80000000h ;// only do neg values
                add [edx].dest_wrap, eax
            .ENDIF
            add edx, SIZEOF RASTER_LINE
            dec ecx

        .UNTIL ZERO?

    ;// set the initial displacement

        imul eax, -5
        add eax, 5
        mov slider_vert_mask.dest_wrap, eax

;// locate the fonts we need

    .IF !pFont_add

        push edi

        lea edi, font_pin_slist_head
        mov eax, '+'
        invoke font_Locate
        mov pFont_add, edi

        lea edi, font_pin_slist_head
        mov eax, 'x'
        invoke font_Locate
        mov pFont_mul, edi

        pop edi

    .ENDIF

;// do the layout stuff

        mov ecx, gdi_bitmap_size.x

    ;// H0 = H_LEFT + H_TOP * bmp_width

        mov eax, SLIDER_H_TOP
        mul ecx
        add eax, SLIDER_H_LEFT
        mov slider_H0, eax

    ;// H1 = H_CENTER + H_TOP * bmp_width

        add eax, SLIDER_H_CENTER - SLIDER_H_LEFT
        mov slider_H1, eax

    ;// RH = (RH_HEIGHT-RH_TOP) * bmp_width

        mov eax, SLIDER_RH_HEIGHT - SLIDER_H_TOP
        mul ecx
        mov slider_RH, eax

    ;// V0 = V_LEFT + V_BOTTOM * bmp_width

        mov eax, SLIDER_V_BOTTOM
        mul ecx
        add eax, SLIDER_V_LEFT
        mov slider_V0, eax

    ;// V1 = V_LEFT + V_MIDDLE * bmp_width

        mov eax, SLIDER_V_MIDDLE
        mul ecx
        add eax, SLIDER_V_LEFT
        mov slider_V1, eax

    ;// RV = RV_WIDTH - RV_LEFT

        mov slider_RV, SLIDER_RV_WIDTH - SLIDER_V_LEFT

    ;// that should do it

        ret

slider_InitRasters ENDP


;///////////////////////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
slider_SetOrientation PROC

        ASSUME esi:PTR OSC_SLIDER_MAP

    ;// choose the correct shapes to draw with
    ;// and set Rofs

        mov ecx, [esi].dwUser               ;// get dwUser

        .IF ecx & SLIDER_VERTICAL   ;// vertical container

            mov [esi].pContainer, OFFSET slider_container_v ;// set the container
            mov [esi].slider.pShape, OFFSET slider_vert_mask    ;// set the slider shape
            mov eax, slider_RV                              ;// load R0

        .ELSE                       ;// horizontal container

            mov [esi].pContainer, OFFSET slider_container_h ;// set the container
            mov [esi].slider.pShape, OFFSET slider_horz_mask    ;// set the slider shape
            mov eax, slider_RH

        .ENDIF

        mov [esi].slider.R0, eax    ;// store R0

    ;// that should do it

        ret

slider_SetOrientation ENDP


;///////////////////////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
slider_SetSource PROC

        ASSUME esi:PTR OSC_SLIDER_MAP

    ;// choose the correct psource

        mov ecx, [esi].dwUser
        and ecx, SLIDER_SOURCE_TEST
        shr ecx, SLIDER_SOURCE_SHIFT
        mov eax, slider_psource[ecx]
        mov [esi].pSource, eax

    ;// that's it

        ret

slider_SetSource ENDP

;///////////////////////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
slider_SyncPins PROC uses ebx

    ;// this makes sure that the op pin is hidden or not

    ASSUME esi:PTR OSC_SLIDER_MAP
    ASSUME ebp:PTR LIST_CONTEXT

    mov ecx, [esi].dwUser
    lea ebx, [esi].pin_A

    ASSUME ebx:PTR APIN

    mov eax, ecx
    and eax, SLIDER_OP_TEST
    ;// and ecx, SLIDER_OP_TEST ;// check for an operation
    ;// mov eax, HINTI_PIN_HIDE ;// assume we hide
    .IF !ZERO?              ;// operation?

        ;// make sure the correct symbol is set

        test ecx, SLIDER_OP_MULT
        mov eax, pFont_add
        .IF !ZERO?
            mov eax, pFont_mul
        .ENDIF
        invoke pin_SetName

        or eax, 1   ;// unhide

        ;// mov [ebx].pFShape, eax

        ;// make sure it gets redrawn and unhidden
        ;// eax is already no zero for un hide
        ;// mov eax, HINTI_PIN_UPDATE_SHAPE OR HINTI_PIN_UNHIDE

    .ENDIF

    invoke pin_Show, eax    ;// GDI_INVALIDATE_PIN eax

;// all_done:

    ret

slider_SyncPins ENDP




;///////////////////////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
slider_SetValue PROC

    ASSUME esi:PTR OSC_SLIDER_MAP

    ;// our task here to to define P0 (dwUser4)

        mov ecx, [esi].dwUser
        movzx eax, cl

        .IF ecx & SLIDER_VERTICAL           ;// P0 = V0 + (val-128) * bmp_width

            sub eax, 128
            imul gdi_bitmap_size.x
            add eax, slider_V0

        .ELSE ;// ecx & SLIDER_HORZ         ;// P0 = H0 + val

            add eax, slider_H0

        .ENDIF

        mov [esi].slider.P0, eax

    ;// thatt's it

        ret

slider_SetValue ENDP


;///////////////////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
slider_SetShape PROC ;// STDCALL pObject:DWORD

        ASSUME esi:PTR OSC_SLIDER_MAP

    ;// make sure the raster tables are filled in

        .IF !slider_horz_mask.dest_wrap ;// dest wrap will be zero for not filled in
            invoke slider_InitRasters
        .ENDIF

    ;// set up the rest of the layout data

        invoke slider_SetOrientation
        invoke slider_SetSource
        invoke slider_SetValue
        invoke slider_SyncPins

    ;// exit by jumping to base class

        jmp osc_SetShape

slider_SetShape ENDP




;///////////////////////////////////////////////////////////////////////////////////////




ASSUME_AND_ALIGN
slider_HitTest PROC ;// STDCALL uses esi edi pObject:ptr OSC_OBJECT

    ;// return with carry flag set if hitting the control

    ;// hit test is by mouse position only
    ;// we already know that we're inside the osc
    ;// so all we have to do is determine if we're close enough to the control

    ASSUME esi:PTR OSC_SLIDER_MAP

    movzx eax, BYTE PTR [esi].dwUser    ;// get the current value
    add eax, 4  ;// offset to get the correct pixel

    .IF [esi].dwUser & SLIDER_VERTICAL  ;// test against y

        mov edx, [esi].rect.top         ;// load the offset
        sub eax, mouse_now.y            ;// subtract Y

    .ELSE   ;// SLIDER HORIZONTAL       ;// test against x

        mov edx, [esi].rect.left        ;// load the offset
        sub eax, mouse_now.x            ;// subtract X

    .ENDIF

    add eax, edx    ;// add the offset
    .IF SIGN?       ;// make sure it's positive
        neg eax
    .ENDIF

    cmp eax,SLIDER_MIN_MOUSE    ;// sets carry and sign, maybe zero
    inc eax                     ;// clear sign and zero, leave carry

    ret

slider_HitTest ENDP




;///////////////////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
slider_Control PROC ;// STDCALL uses esi edi pObject:ptr OSC_OBJECT

    ASSUME esi:PTR OSC_OBJECT
    ASSUME ebp:PTR LIST_CONTEXT
    ;// eax has the message

    ;// this only gets called if we are app osc down
    ;// and if we are being hit
    ;// task: make the slider follow the mouse

    .IF eax == WM_LBUTTONDOWN

        ;// we want to grab the current position
        ;// so the slider doesn't jump around so much

        .IF [esi].dwUser & SLIDER_VERTICAL  ;// val follows Y
            mov edx, mouse_now.y            ;// load mouse position
        .ELSE   ;// SLIDER HORIZONTAL       ;// val follows X
            mov edx, mouse_now.x        ;// load mouse position
        .ENDIF

        mov slider_mouse_start, edx ;// store for future use

        xor eax, eax                ;// we haven't moved yet

    .ELSEIF eax == WM_MOUSEMOVE

        ;// we want to track the mouse

        movzx eax, BYTE PTR [esi].dwUser;// get the current value
        mov edx, slider_mouse_start     ;// get where the mouse started

        test [esi].dwUser, SLIDER_VERTICAL
        jz is_horizontal
                                ;// SLIDER_VERTICAL val follows Y
            mov ecx, mouse_now.y
            jmp set_new_position

        is_horizontal:          ;// SLIDER HORIZONTAL   ;// val follows X

            mov ecx, mouse_now.x;// load mouse position

        set_new_position:

            sub edx, ecx
            sub eax, edx        ;// subtract to add to current value
            jns @F              ;// check for under range
            xor eax, eax        ;// clear if under range
            jmp set_the_value
        @@:
            cmp eax, 128        ;// check for over range
            jb store_the_new_mouse
            mov eax, 128        ;// set if over range
            jmp set_the_value

        store_the_new_mouse:

            mov slider_mouse_start, ecx     ;// store the new position

        set_the_value:

            mov BYTE PTR [esi].dwUser, al   ;// set the new value
            invoke slider_SetValue  ;// set the P0 value

            GDI_INVALIDATE_OSC HINTI_OSC_UPDATE

            mov eax, CON_HAS_MOVED  ;// we have changed

    .ELSE
        xor eax, eax
    .ENDIF

    ret

slider_Control ENDP


;///////////////////////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
slider_InitMenu PROC    ;// STDCALL uses esi edi pObject:ptr OSC_OBJECT

        ASSUME esi:PTR OSC_OBJECT

        mov ebx, [esi].dwUser

    ;// do  horz or vert

        mov ecx, ID_SLIDER_HORIZONTAL
        .IF ebx & SLIDER_VERTICAL
            mov ecx, ID_SLIDER_VERTICAL
        .ENDIF

        invoke CheckDlgButton, popup_hWnd, ecx, BST_CHECKED

    ;// select the correct range

        mov ecx, ID_SLIDER_RANGE0
        .IF ebx & SLIDER_RANGE2
            mov ecx, ID_SLIDER_RANGE2
        .ELSEIF ebx & SLIDER_RANGE1
            mov ecx, ID_SLIDER_RANGE1
        .ENDIF

        invoke CheckDlgButton, popup_hWnd, ecx, BST_CHECKED

    ;// select the correct operation

        mov ecx, ID_SLIDER_SLIDE
        .IF ebx & SLIDER_OP_ADD
            mov ecx, ID_SLIDER_ADD
        .ELSEIF ebx & SLIDER_OP_MULT
            mov ecx, ID_SLIDER_MULT
        .ENDIF
        invoke CheckDlgButton, popup_hWnd, ecx, BST_CHECKED

    ;// that's it

        xor eax, eax    ;// return zero or bad things happen

        ret

slider_InitMenu ENDP


;///////////////////////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
slider_Command PROC

    ASSUME esi:PTR OSC_SLIDER_MAP
    ASSUME ebp:PTR LIST_CONTEXT
    ;// eax has command ID


;// orientation commands

    cmp eax, ID_SLIDER_HORIZONTAL
    jne @F

        btr [esi].dwUser, LOG2( SLIDER_VERTICAL )   ;// reset the orientation bit
        jnc ignore_done                             ;// skip if already not set
        jmp set_new_orientation

@@: cmp eax, ID_SLIDER_VERTICAL
    jne @F

        bts [esi].dwUser, LOG2( SLIDER_VERTICAL )   ;// set the orientation bit
        jc ignore_done                              ;// skip if already set

    set_new_orientation:

        ;// flip the value around so the slider stays in the same spot

        movzx edx, BYTE PTR [esi].dwUser
        sub edx, 128
        neg edx
        mov BYTE PTR [esi].dwUser, dl

        ;// let gdi do the work of calling the orientation and value functions

        GDI_INVALIDATE_OSC HINTI_OSC_SHAPE_CHANGED

        jmp all_done

;// range commands

@@: cmp eax, ID_SLIDER_RANGE0
    jne @F

        and [esi].dwUser, NOT SLIDER_RANGE_TEST
        jmp set_new_source

@@: cmp eax, ID_SLIDER_RANGE1
    jne @F

        or [esi].dwUser, SLIDER_RANGE1
        btr [esi].dwUser, LOG2(SLIDER_RANGE2)
        jc flip_the_value
        jmp set_new_source

@@: cmp eax, ID_SLIDER_RANGE2
    jne @F

        or [esi].dwUser, SLIDER_RANGE2
        btr [esi].dwUser, LOG2(SLIDER_RANGE1)
        jnc set_new_source

    flip_the_value:

        xor eax, eax
        mov al, 128
        sub al, BYTE PTR [esi].dwUser

    set_new_position:

        mov BYTE PTR [esi].dwUser, al
        invoke slider_SetValue

    set_new_source:

        mov BYTE PTR [esi+1].dwUser, 0FFh   ;// force the value to reset
        invoke slider_SetSource         ;// set the source
        jmp all_done                    ;// that's it

;// keyboard control (added abox224)

@@: cmp eax, VK_LEFT
    jne @F

        test [esi].dwUser, SLIDER_VERTICAL
        jnz ignore_done

        jmp decrease_the_value

@@: cmp eax, VK_DOWN
    jne @F

        test [esi].dwUser, SLIDER_VERTICAL
        jz ignore_done

        jmp increase_the_value

@@: cmp eax, VK_RIGHT
    jne @F

        test [esi].dwUser, SLIDER_VERTICAL
        jnz ignore_done

    increase_the_value:

        mov al, BYTE PTR [esi].dwUser
        add al, 4
        jns set_new_position
        and al, 80h ;// mov al, 127
        jmp set_new_position

@@: cmp eax, VK_UP
    jne @F

        test [esi].dwUser, SLIDER_VERTICAL
        jz ignore_done

    decrease_the_value:

        mov al, BYTE PTR [esi].dwUser
        sub al, 4
        jnc set_new_position
        xor al, al
        jmp set_new_position

;// preset values

@@: cmp eax, ID_SLIDER_PRESET_1
    jne @F

        mov ecx, OFFSET slider_keyboard_one_table
        jmp set_keyboard_value

@@: cmp eax, ID_SLIDER_PRESET_0
    jne @F

        mov ecx, OFFSET slider_keyboard_zero_table

    set_keyboard_value:

        mov edx, [esi].dwUser
        xor eax, eax
        and edx, SLIDER_RANGE_TEST OR SLIDER_VERTICAL
        BITSHIFT edx, SLIDER_VERTICAL, 1
        mov al, BYTE PTR [ecx+edx]  ;// ABOX242 AJT
        jmp set_new_position

@@: cmp eax, ID_SLIDER_PRESET_NEG
    jne @F

        ;//     orin 00 40 80   neg?    new val
        ;// 000 horz 00 .5 +1   no
        ;// 001 vert +1 .5 00   no
        ;// 010 horz -1 00 +1   yes 80-val
        ;// 011 vert +1 00 -1   yes 80-val
        ;// 100 horz +1 00 -1   yes 80-val
        ;// 101 vert -1 00 +1   yes 80-val
        ;// 110 err
        ;// 111 err

        test [esi].dwUser, SLIDER_RANGE_TEST
        jz ignore_done

        mov al, 80h
        sub al, BYTE PTR [esi].dwUser
        jmp set_new_position

;// function commands

@@: cmp eax, ID_SLIDER_SLIDE
    jne @F

        xor edx, edx
        jmp set_new_op

@@: cmp eax, ID_SLIDER_ADD
    jne @F

        mov edx, SLIDER_OP_ADD
        jmp set_new_op

@@: cmp eax, ID_SLIDER_MULT
    jne osc_Command

        mov edx, SLIDER_OP_MULT

    set_new_op:

        and [esi].dwUser, NOT SLIDER_OP_TEST
        or [esi].dwUser, edx
        invoke slider_SyncPins

    all_done:

        mov eax, POPUP_REDRAW_OBJECT OR POPUP_SET_DIRTY
        ret

    ignore_done:

        mov eax, POPUP_IGNORE
        ret

slider_Command ENDP

;///////////////////////////////////////////////////////////////////////////////////////



ASSUME_AND_ALIGN
slider_SaveUndo PROC

        ASSUME esi:PTR OSC_OBJECT

        ;// edx enters as either UNREDO_CONTROL_OSC or UNREDO_COMMAND
        ;// edi enters as where to store
        ;//
        ;// task:   1) save nessary data
        ;//         2) iterate edi
        ;//
        ;// may use all registers except ebp

        mov eax, [esi].dwUser

        stosd

        ret

slider_SaveUndo ENDP




ASSUME_AND_ALIGN
slider_LoadUndo PROC

        ASSUME esi:PTR OSC_OBJECT       ;// preserve
        ASSUME ebp:PTR LIST_CONTEXT ;// preserve

        ;// edx enters as either UNREDO_CONTROL_OSC or UNREDO_COMMAND
        ;// edi enters as where to load
        ;//
        ;// task:   1) load nessary data
        ;//         2) do what it takes to initialize it
        ;//
        ;// may use all registers except ebp
        ;// return will invalidate HINTI_OSC_UPDATE

        mov eax, [edi]
        mov edx, [esi].dwUser

        and eax, 0FFFF00FFh ;// remove position from the new value
        and edx, 00000FF00h ;// keep position in old value
        or edx, eax         ;// merg the two together

        mov [esi].dwUser, edx   ;// store new value

        ;// initialize shape for the new data

        or [esi].dwHintI, HINTI_OSC_SHAPE_CHANGED

        ret

slider_LoadUndo ENDP
























ASSUME_AND_ALIGN

ENDIF   ;// USE_THIS_FILE
END