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
;// ABox_Readout.asm
;//
;//
;// TOC
;// readout_Ctor
;// readout_Dtor
;// readout_GetUnit
;// readout_SetPin
;// readout_SetShape
;// readout_Render
;// readout_Calc
;// readout_InitMenu
;// readout_Command
;// readout_LoadUndo



OPTION CASEMAP:NONE

.586
.MODEL FLAT

USE_THIS_FILE equ 1

IFDEF USE_THIS_FILE

        .NOLIST
        INCLUDE <Abox.inc>
        INCLUDE <ABox_Knob.inc>
        .LIST

.DATA

;// each readout allocates it's own dib
;// READOUT_DIRTY means that the dib needs rebuilt
;// otherwise, render can just blit what ever is there

;// osc.dwUser is then the KNOB_UNIT flags, plus the KNOB_UNIT_METER value

READOUT_DATA    STRUCT

    pmax    REAL4 0.0e+0    ;// decaying value of the peak
    max     REAL4 0.0e+0    ;// last read value of the peak

    pmin    REAL4 0.0e+0    ;// decaying value of min peak
    min     REAL4 0.0e+0    ;// last read min peak

    aver    REAL4 0.0e+0    ;// average value for last frame
    rms     REAL4 0.0e+0    ;// rms value for last frame

    last    REAL4 0.0e+0    ;// last value (first number of last frame)

READOUT_DATA    ENDS


osc_Readout OSC_CORE { readout_Ctor,readout_Dtor,,readout_Calc}
            OSC_GUI  { readout_Render,readout_SetShape,,,,readout_Command,readout_InitMenu,,,osc_SaveUndo,readout_LoadUndo,readout_GetUnit }
            OSC_HARD { }

    BASE_FLAGS= BASE_PLAYABLE OR \
                BASE_BUILDS_OWN_CONTAINER OR \
                BASE_XLATE_CTLCOLORLISTBOX  OR \
                BASE_HAS_AUTO_UNITS OR \
                BASE_SHAPE_EFFECTS_GEOMETRY

    OSC_DATA_LAYOUT { NEXT_Readout , IDB_READOUT,OFFSET popup_READOUT,
        BASE_FLAGS,
        1,4,
        SIZEOF OSC_OBJECT + SIZEOF APIN,
        SIZEOF OSC_OBJECT + SIZEOF APIN,
        SIZEOF OSC_OBJECT + SIZEOF APIN + SIZEOF READOUT_DATA }

    OSC_DISPLAY_LAYOUT { ,, ICON_LAYOUT (13,0,3,6) }

    APIN_init { 1.0,,'X',, UNIT_AUTO_UNIT  }

    short_name  db  'Read- out',0
    description db  'Display numerical values or VU meter with peak average and RMS.',0
    ALIGN 4

;// layout parameters

    READOUT_WIDTH_BIG       EQU 128
    READOUT_HEIGHT_BIG      EQU 28

    READOUT_WIDTH_SMALL     EQU 64
    READOUT_HEIGHT_SMALL    EQU 18

    READOUT_SMALL_ADJUST_X  EQU 32
    READOUT_SMALL_ADJUST_Y  EQU 5

    READOUT_BORDER          EQU 2

;// scale for building graphics

    readout_scale_big   REAL4 @REAL( READOUT_WIDTH_BIG )
    readout_scale_small REAL4 @REAL( READOUT_WIDTH_SMALL )

;// flags stored in dwUser

    READOUT_DIRTY       equ 00000001h   ;// true if we need to rebuild the display

    READOUT_METER1      equ 00000002h   ;// basic vu meter
    READOUT_METER2      equ 00000004h   ;// basic vu meter

    READOUT_METER_TEST  EQU 00000006h

    READOUT_CLIPPING    equ 00000008h   ;// one of the values clipped

    READOUT_SMALL       EQU 00000010h   ;// smaller size

    ;// do not use      EQU 000FF800h   reserved for auto units

;// osc map for this object

    READOUT_OSC_MAP STRUCT

        OSC_OBJECT      {}

        pin_x   APIN    {}

        readout READOUT_DATA {}

    READOUT_OSC_MAP ENDS



    readout_decay   TEXTEQU <math_linear_decay>












.CODE

ASSUME_AND_ALIGN
readout_Ctor PROC

        ;// register call
        ASSUME ebp:PTR LIST_CONTEXT ;// preserve
        ASSUME esi:PTR OSC_OBJECT   ;// preserve
        ASSUME edi:PTR OSC_BASE     ;// may destroy
        ASSUME ebx:PTR FILE_OSC     ;// may destroy
        ASSUME edx:PTR FILE_HEADER  ;// may destroy

    ;// we're being called from the constructor
    ;// all file data has already been loaded

    ;// set to defaults

        .IF !edx    ;// we are newly created from a menu
            mov [esi].dwUser, UNIT_AUTO_UNIT    ;// set straight to unit auto
        .ENDIF

    ;// that's it

        ret

readout_Ctor ENDP




ASSUME_AND_ALIGN
readout_Dtor PROC

    ;// task, release our dib

    ASSUME esi:PTR OSC_OBJECT

    mov eax, [esi].pContainer

    .IF eax
        invoke dib_Free, eax
    .ENDIF

    ret

readout_Dtor ENDP

ASSUME_AND_ALIGN
readout_GetUnit PROC

        ASSUME esi:PTR OSC_OBJECT
        ASSUME ebx:PTR APIN

    ;// if we are auto unit, then we don't know what our units are
    ;// if we are a meter, we don't know what our units are

        mov eax, [esi].dwUser
        test eax, READOUT_METER_TEST
        jnz all_done                ;// carry flag is clear
        BITT eax, UNIT_AUTO_UNIT    ;// see if we're set to auto unit
        cmc                         ;// if on, then we return off (don't know)
    all_done:
        ret

readout_GetUnit ENDP

ASSUME_AND_ALIGN
readout_SetPin PROC

        ASSUME esi:PTR READOUT_OSC_MAP
        ASSUME ebp:PTR LIST_CONTEXT

        ;// destroys ebx

    ;// task: make sure pin matches desired osc unit

        mov eax, [esi].dwUser       ;// eax is dwUser
        lea ebx,[esi].pin_x         ;// ecx is pin x
        ASSUME ebx:PTR APIN

        .IF eax & READOUT_METER_TEST;// are we a meter ?
            mov eax, UNIT_AUTO_UNIT ;// use auto units
        .ELSEIF eax & UNIT_AUTO_UNIT;// auto unit ?
            and eax, NOT UNIT_TEST  ;// remove old units, leave auto unit intact
        .ELSE                       ;// a fixed unit
            and eax, UNIT_TEST      ;// strip out UNIT_AUTO_UNIT
        .ENDIF

        invoke pin_SetUnit          ;// set the pin, causes auto trace, will set UNIT_AUTO_TRACE

    ;// always set dirty so we get a new display

        or [esi].dwUser, READOUT_DIRTY

    ;// that's it

        ret

readout_SetPin ENDP





ASSUME_AND_ALIGN
readout_SetShape PROC

    ASSUME esi:PTR OSC_OBJECT
    ASSUME edi:PTR OSC_BASE

    push ebx

    ;// make sure the correct dib is allocated
    OSC_TO_CONTAINER esi, ebx, NOERROR

    TESTJMP [esi].dwUser, READOUT_SMALL, jnz should_be_small

    should_be_big:

        TESTJMP ebx, ebx, jz reallocate_big
        CMPJMP  [ebx].shape.siz.y, READOUT_HEIGHT_BIG, je allocate_done

    reallocate_big:

        pushd hFont_huge            ;// push the font we want
        pushd READOUT_HEIGHT_BIG    ;// and the size
        pushd READOUT_WIDTH_BIG

        jmp reallocate_dib

    should_be_small:

        TESTJMP ebx, ebx, jz reallocate_small
        CMPJMP  [ebx].shape.siz.y, READOUT_HEIGHT_SMALL, je allocate_done

    reallocate_small:

        pushd hFont_pin             ;// push the font we want
        pushd READOUT_HEIGHT_SMALL  ;// and the size
        pushd READOUT_WIDTH_SMALL

    reallocate_dib:

        .IF !ebx                    ;// check if we'ree allocating for the first time
            mov ebx, DIB_ALLOCATE_INTER
        .ENDIF
        pushd ebx
        call dib_Reallocate

        mov ebx, eax
        mov edx, [ebx].shape.pSource

        mov [esi].pContainer, ebx
        mov [esi].pSource, edx

        push [ebx].shape.hDC
        call SelectObject
        invoke SetBkMode, [ebx].shape.hDC, TRANSPARENT

    allocate_done:

    ;// since this is also in responce to color changes
    ;// we reset the text color

        mov eax, oBmp_palette[(COLOR_GROUP_DISPLAYS+31)*4]
        RGB_TO_BGR eax

        invoke SetTextColor, [ebx].shape.hDC, eax

    ;// then set the pin for the correct units

        invoke readout_SetPin

    ;// exit by jumping to osc_SetShape

        pop ebx
        jmp osc_SetShape


readout_SetShape ENDP



comment ~ /*

    there are several things we want to darw and particular order we want to draw them in
    not all are drawn in all modes
                        mode1
    zero line   mode 2   x
    fill rect   always  border * 4 to width - border 4  rms * scale
    rms line    mode 2  rms * scale
    aver line   always
    pmax line   always
    pmin line   mode 2

    we're going to draw some of several indicators in the order specified

        zero
            mode 2
            2 pixel line at center
            top = border-1
            bottom = height - border

        fill rect
            mode 2
            left  = pmin*scale2 + 1/2 width
            right = pmax*scale2 + 1/2 width
            limit border*2 < left < right < width - border*2
            top = border * 4
            bottom = top * height - border * 8

        fill rect
            mode 1
            filled rect
            left = border, right = rms * scale1 + border
            top = border, bottom = height - border
            range check for right > scale 1

        ave
            all modes
            2 pixel wide vertical line
            top = border - 1
            bottom = height - border + 1
            X = ave * scale + border - 2

        pmax
            all modes
            2 pixel wide vertical line
            top = border - 1
            bottom = height - border + 1
            X = peak * 124 + border

        pmin
            mode 2
            2 pixel wide vertical line
            top = border - 1
            bottom = height - border + 1
            X = peak * 124 + border

*/ comment ~

.DATA

    ALIGN 4
    render_fill_table LABEL DWORD
    ;// big
        dd  READOUT_WIDTH_BIG - READOUT_BORDER - 1  ;// 120 ;// x limit
        dd  READOUT_HEIGHT_BIG - READOUT_BORDER*3   ;// line count
        dd  READOUT_WIDTH_BIG                       ;// width of the whole object
        dd  READOUT_WIDTH_BIG*3                     ;// start of rect
    ;// small
        dd  READOUT_WIDTH_SMALL - READOUT_BORDER - 1;// 120 ;// x limit
        dd  READOUT_HEIGHT_SMALL - READOUT_BORDER*3 ;// line count
        dd  READOUT_WIDTH_SMALL         ;// width of the whole object
        dd  READOUT_WIDTH_SMALL*3       ;// start of rect



;///////////////////////////////////////////////////////////////////////
;//
;//     render build line tables
;//

comment ~ /*

    this function draws a 2 pixel wide line
    the line is centered on the deisred value, which is passed in the FPU
    the function accounts for meter1 and meter2 modes

    the tables have the following format

    00  hi limit in pixels
    04  lo limit in pixels
    08  height of line in pixels
    0C  raster spane = total width - line thinckness
    10  start offset as y coord * width

*/ comment ~

    render_aver_table LABEL DWORD
    ;// big
        dd  READOUT_WIDTH_BIG - READOUT_BORDER  ;// hi limit
        dd  READOUT_BORDER                          ;// x lo limit
        dd  READOUT_HEIGHT_BIG - 4 - READOUT_BORDER * 4 ;// line count
        dd  READOUT_WIDTH_BIG - 2                   ;// raster span
        dd  READOUT_WIDTH_BIG*6                 ;// start address
    ;// small
        dd  READOUT_WIDTH_SMALL - READOUT_BORDER    ;// limit
        dd  READOUT_BORDER          ;// x lo limit
        dd  READOUT_HEIGHT_SMALL - 4 - READOUT_BORDER * 4;// line count
        dd  READOUT_WIDTH_SMALL - 2                     ;// raster span
        dd  READOUT_WIDTH_SMALL*6                       ;// start address

    render_peak_table LABEL DWORD
    ;// big
        dd  READOUT_WIDTH_BIG-1                     ;// x limit
        dd  1                       ;// x lo limit
        dd  READOUT_HEIGHT_BIG - READOUT_BORDER * 3 ;// line count
        dd  READOUT_WIDTH_BIG - 2                   ;// raster span
        dd  READOUT_WIDTH_BIG*3                     ;// start position
    ;// small
        dd  READOUT_WIDTH_SMALL-1   ;// x limit
        dd  1                       ;// x lo limit
        dd  READOUT_HEIGHT_SMALL - READOUT_BORDER * 3   ;// line count
        dd  READOUT_WIDTH_SMALL - 2                     ;// raster span
        dd  READOUT_WIDTH_SMALL*3                       ;// start position


.CODE




ASSUME_AND_ALIGN
readout_Render PROC

    ;// call osc render AFTER building the dib

    ASSUME esi:PTR READOUT_OSC_MAP

    mov ecx, [esi].dwUser       ;// get dwUser
    BITR ecx, UNIT_AUTO_TRACE   ;// auto trace ?
    .IF CARRY?

        ;// time to retrieve units from pin

        mov eax, [esi].pin_x.dwStatus
        and ecx, NOT (UNIT_TEST OR UNIT_AUTOED OR UNIT_AUTO_UNIT)   ;// remove old units
        and eax, UNIT_TEST OR UNIT_AUTOED OR UNIT_AUTO_UNIT         ;// leave the auto bit on
        or ecx, eax
        or ecx, READOUT_DIRTY
        mov [esi].dwUser, ecx

    .ENDIF
    BITRJMP ecx, READOUT_DIRTY, jnc gdi_render_osc      ;// skip the whole affair if not dirty
    mov [esi].dwUser, ecx


    ;// we have to render before we exit to gdi_render_osc

    push edi

    ;// fill and frame the bitmap, account for clipping
    ;// fill and frame the bitmap

        OSC_TO_CONTAINER esi, ebx
        mov eax, F_COLOR_GROUP_DISPLAYS
        test ecx, READOUT_CLIPPING
        mov edx, F_COLOR_OSC_BAD
        .IF ZERO?
            mov edx, F_COLOR_GROUP_DISPLAYS + F_COLOR_GROUP_LAST
        .ENDIF
        invoke dib_FillAndFrame

        mov ecx, [esi].dwUser       ;// get dwUser

    TESTJMP ecx, READOUT_METER_TEST,    jz readout_render_text

    ;// RENDER METER

        sub esp, 4      ;// make some room on the stack

        st_temp TEXTEQU <(DWORD PTR [esp+call_depth*4])>
        call_depth = 0

    ;// load the scalars we'll need

        .IF ecx & READOUT_SMALL
            fld readout_scale_small ;// K
        .ELSE
            fld readout_scale_big   ;// K
        .ENDIF

    ;// fill rect ////////////////////////////////////////////////////////////////

        TESTJMP ecx, READOUT_METER1, jz fill_meter2

            fld  [esi].readout.rms
            fmul st, st(1)      ;// rms     K
            xor eax, eax
            fistp st_temp

            ;// make sure there's something to draw
            ORJMP eax, st_temp, jz no_fill_the_band

            mov edi, OFFSET render_fill_table
            .IF ecx & READOUT_SMALL
                add edi, 16
            .ENDIF

            .IF eax > [edi]     ;// x limit     ;// make sure it's not too big
                mov eax, [edi]
            .ENDIF
            mov ecx, READOUT_BORDER+1       ;// start position
            SUBJMP eax, ecx, ja fill_the_band

            jmp dont_fill_the_band

        ALIGN 16
        fill_meter2: ;// METER 2 ////////////////////////////////////////////////////

            ;// lines from min to max
            ;// from top to bottom
            ;// left < min < max < right


            fld [esi].readout.min
            fmul math_1_2
            fld [esi].readout.max
            fmul math_1_2
            fxch
            fadd math_1_2
            fxch
            fadd math_1_2
            fxch
            fmul st, st(2)
            fxch
            fmul st, st(2)
            fxch

            fistp st_temp
            mov edx, st_temp    ;// start
            ASSUME edx:SDWORD

            fistp st_temp
            mov eax, st_temp    ;// stop
            ASSUME eax:SDWORD

            mov edi, OFFSET render_fill_table
            .IF ecx & READOUT_SMALL
                add edi, 16
            .ENDIF

            .IF edx < READOUT_BORDER
                mov edx, READOUT_BORDER
                .IF eax <= edx
                    mov eax, edx
                    dec edx
                    jmp points_are_ready
                .ENDIF
            .ELSEIF edx > [edi]
                mov edx, [edi]
                .IF eax <= edx
                    mov eax, edx
                    inc eax
                    jmp points_are_ready
                .ENDIF
            .ENDIF

            .IF eax <= READOUT_BORDER
                mov eax, READOUT_BORDER
                .IF eax <= edx
                    mov edx, eax
                    inc eax
                    jmp points_are_ready
                .ENDIF
            .ELSEIF edx > [edi]
                mov eax, [edi]
                .IF eax <= edx
                    mov edx, eax
                    dec edx
                    jmp points_are_ready
                .ENDIF
            .ENDIF

            ASSUME eax:NOTHING
            ASSUME edx:NOTHING

            cmp eax, edx
            jg points_are_ready
            jl swap_points
            inc eax
            dec eax
            jmp points_are_ready

        swap_points:

            xchg eax, edx

        points_are_ready:

        ;// edx = start
        ;// eax = stop

            mov ecx, edx        ;// save start here

            sub eax, edx        ;// width of band
            jbe dont_fill_the_band

        fill_the_band:
        ;// ecx must have start offset
        ;// edi must point at table
        ;// eax must have width of band

            mov st_temp, eax    ;// store the width
            DEBUG_IF < eax !> 128 >
            mov edx, [edi+4]    ;// line count
            mov ebx, [edi+8]    ;// width of object
            mov edi, [edi+12]   ;// start position

            add edi, ecx        ;// add start offset
            sub ebx, eax        ;// subtract width to get wrap
            add edi, [esi].pSource
            mov eax, F_COLOR_OSC_1
            .REPEAT
                mov ecx, st_temp
                rep stosb
                add edi, ebx
                dec edx
            .UNTIL ZERO?

    dont_fill_the_band:
    no_fill_the_band:

        mov ecx, [esi].dwUser


    ;// average line ////////////////////////////////////////////////////////////////

        fld [esi].readout.aver
        mov edi, OFFSET render_aver_table

        call render_build_line

    ;// pmax ////////////////////////////////////////////////////////////////

        fld [esi].readout.pmax
        mov edi, OFFSET render_peak_table
        call render_build_line

    ;// pmin ////////////////////////////////////////////////////////////////

        .IF ecx & READOUT_METER2

            fld [esi].readout.pmin
            mov edi, OFFSET render_peak_table
            call render_build_line

        .ENDIF

    ;// that's it ////////////////////////////////////////////////////////////////

        add esp, 4  ;// clean up st_temp
        fstp st
        pop edi
        jmp gdi_render_osc

    ;/////////////////////////////////////////////////////////////////////////////
    ;//
    ;//     render_build line                   local function
    ;//

    ALIGN 16
    render_build_line:

    ;// edi must point at the table to use
    ;// fpu must have the value to use
    ;// fpu must also have correct scalar
    ;// ecx must = [esi].dwUser
    ;// color is always osc 2

        call_depth = 1


            ;// make sure ecx has the appropriate configuration flags
            IFDEF DEBUGBUILD
                mov eax, ecx
                xor eax, [esi].dwUser
                and eax, 0FFFFFFFEh ;// the lower bit may be set, that's ok
                DEBUG_IF <!!ZERO?>  ;// will completely crash computer if not true
            ENDIF

            .IF ecx & READOUT_METER2
                fmul math_1_2
                fadd math_1_2
            .ENDIF
            fmul st, st(1)
            test ecx, READOUT_SMALL
            fistp st_temp
            .IF !ZERO?
                add edi, 20
            .ENDIF
            mov eax, st_temp
            .IF eax > [edi]
                mov eax, [edi]
            .ELSEIF eax < [edi+4]
                mov eax, [edi+4]
            .ENDIF
            dec eax ;// so that line is centered on pixel

            mov ecx, [edi+8]    ;// line count
            mov edx, [edi+12]   ;// raster span
            mov edi, [edi+16]   ;// start address

            add edi, eax
            add edi, [esi].pSource
            mov eax, F_COLOR_OSC_2
            .REPEAT

        IFDEF DEBUGBUILD
            pushad  ;// EDI, ESI, EBP, ESP, EBX, EDX, ECX, EAX

            mov ecx, [esi].pContainer
            mov eax, (GDI_CONTAINER PTR [ecx]).shape.pSource
            DEBUG_IF <eax !!= [esi].pSource>

            add eax, (GDI_CONTAINER PTR [ecx]).shape.dword_size
            add eax, (GDI_CONTAINER PTR [ecx]).shape.dword_size
            add eax, (GDI_CONTAINER PTR [ecx]).shape.dword_size
            add eax, (GDI_CONTAINER PTR [ecx]).shape.dword_size
            cmp eax, edi
            ja @F
                int 3
            @@:
            popad

        ENDIF

                stosw
                add edi, edx
                dec ecx
            .UNTIL ZERO?
            mov ecx, [esi].dwUser       ;// get dwUser

            retn

        call_depth = 0
        st_temp TEXTEQU <>


    ;//
    ;//     render_build line                   local function
    ;//
    ;/////////////////////////////////////////////////////////////////////////////




    ALIGN 16
    readout_render_text:

    ;// readout mode

    ;// format and draw the text

        sub esp, 32             ;// local text buffer

        mov ecx, [esi].dwUser   ;// get the units
        mov eax, esp            ;// point to buffer here
        fld [esi].readout.last  ;// get the value to display
        invoke unit_BuildString, eax, ecx, 0    ;// format the text

        mov ecx, esp            ;// get the buffer pointer

        .IF [esi].dwUser & READOUT_SMALL

            pushd READOUT_HEIGHT_SMALL- READOUT_BORDER  ;// push the height
            pushd READOUT_WIDTH_SMALL - READOUT_BORDER  ;// push the width

        .ELSE

            pushd READOUT_HEIGHT_BIG- READOUT_BORDER    ;// push the height
            pushd READOUT_WIDTH_BIG - READOUT_BORDER    ;// push the width

        .ENDIF

        pushd READOUT_BORDER    ;// push the top boundry
        pushd READOUT_BORDER    ;// push the left boundry

        OSC_TO_CONTAINER esi, edx   ;// get our container
        mov eax, esp                ;// get the rect pointer

        invoke DrawTextA, [edx].shape.hDC, ecx, -1, eax,
            DT_CENTER OR DT_NOCLIP OR DT_VCENTER OR DT_SINGLELINE

        DEBUG_IF<!!eax>, GET_ERROR

        add esp, 32 + SIZEOF RECT       ;// clean up the stack
        pop edi
        jmp gdi_render_osc

readout_Render ENDP

















    comment ~ /*


        readout calc now works like this:

        if in meter mode, on screen

            determine the new peak, rms, and average values

        set READOUT_DIRTY
        if on screen, invalidate

            ;// throught this routine, edx will hold flags
            ;// the clip flag, and the need_to_invalidate flag



    if input data is changing
        compute rms, average and scan for peak
    if not changing
        rms = average = last_value = [edi]
        if peak != average
            decay and invalidate

        if all of these are the same a previous, do nothing

    formulas:

        ave = sum(I[])/num_samples
        rms = sqrt( I[]^2 / num_samples )
        peak is simply check the abs value against a stored peak

        peak decay = peak value * spectrum decay

    */ comment ~




ASSUME_AND_ALIGN
readout_Calc PROC

    ASSUME esi:PTR READOUT_OSC_MAP

        xor eax, eax
        sub edi, edi
        or eax, [esi].dwHintOsc ;// & INVAL_ONSCREEN    ;// skip if we're not
        jns not_on_screen
        OR_GET_PIN_FROM edi, [esi].pin_x.pPin
        jz not_connected

        mov eax, [esi].dwUser

        xor edx, edx    ;// = 1 for dirty, >1 for clip
        sub ecx, ecx    ;// counter

        TESTJMP eax, READOUT_METER_TEST, jz not_a_meter
        TESTJMP eax, READOUT_METER1, jz calc_meter_2

    calc_meter_1:   ;///// METER 1 //////////////////////////////////////////////////////////

        test [edi].dwStatus, PIN_CHANGING
        mov edi, [edi].pData
        jz calc_1_no_change
        ASSUME edi:PTR DWORD

        ;// edi has changing data

        fldz            ;// ave
        fld st          ;// rms     ave
        fld math_2_24
        fchs            ;// MAX     rms     ave

        .REPEAT

            fld [edi+ecx*4] ;// I       max     sum2    sum
            fadd st(3), st  ;// I       max     sum2    sum
            fld st
            fmul st(1), st  ;// X       X^2     max     sum2    sum
            fabs            ;// X       X^2     max     sum2    sum
            xor eax, eax
            fucom st(2)
            fnstsw ax
            sahf
            jbe M0
            fxch st(2)
        M0: fstp st         ;// X2      max     sum2    sum
            inc ecx
            faddp st(2), st ;// max     sum2    sum

        .UNTIL ecx >= SAMARY_LENGTH

        ;// rms
        fxch                ;// sum2    max     sum
        fmul math_1_1024    ;// ms      max     sum
        fsqrt               ;// rms     max     sum
        CLIPTEST_ONE edx
        fstp [esi].readout.rms      ;// max     sum

        ;// average must be positive
        fxch
        fabs
        fxch

        jmp update_max

    ALIGN 16
    calc_1_no_change:

        mov eax, [edi]
        CMPJMP eax, [esi].readout.pmax,jne do_calc_1_no_change
        CMPJMP eax, [esi].readout.max, jne do_calc_1_no_change
        CMPJMP eax, [esi].readout.aver, jne do_calc_1_no_change
        CMPJMP eax, [esi].readout.rms, je check_clipping

    do_calc_1_no_change:

        fld [edi]
        fabs
        fld st
        xor edi, edi    ;// must set to 0 as a flag
        fst [esi].readout.rms
        jmp update_max

    ALIGN 16
    calc_meter_2:   ;///// METER 2 //////////////////////////////////////////////////////////

        ASSUME edi:PTR APIN
        test [edi].dwStatus, PIN_CHANGING
        mov edi, [edi].pData
        jz calc_2_no_change
        ASSUME edi:PTR DWORD

        ;// have changing data

        fldz                ;// sum
        fld math_2_24       ;// min
        fld st
        fchs                ;// max     min
        fxch                ;// min     max     sum
        .REPEAT

            fld [edi+ecx*4] ;// X       min     max     sum

            xor eax, eax
            fucom st(1)     ;// X       min     max     sum
            fnstsw ax
            sahf
            jae M1
            fst st(1)

        M1: xor eax, eax
            fucom st(2)     ;// X       min     max     sum
            fnstsw ax
            sahf
            jbe M2
            fst st(2)

        M2: inc ecx
            faddp st(3),st  ;// min     max     sum

        .UNTIL ecx >= SAMARY_LENGTH

        jmp update_min

    ALIGN 16
    calc_2_no_change:

        mov eax, [edi]
        CMPJMP eax, [esi].readout.pmax,jne do_calc_2_no_change
        CMPJMP eax, [esi].readout.pmin,jne do_calc_2_no_change
        CMPJMP eax, [esi].readout.max, jne do_calc_2_no_change
        CMPJMP eax, [esi].readout.min, jne do_calc_2_no_change
        CMPJMP eax, [esi].readout.aver,je check_clipping

    do_calc_2_no_change:

        fld [edi]       ;// sum
        fld st          ;// max     sum
        fld st          ;// min     max     sum
        xor edi, edi    ;// must set to 0 as a flag
    ;   jmp update_min

    update_min: ;///// METER 1 and 2 //////////////////////////////////////////////////////////

        CLIPTEST_ONE edx
        fld [esi].readout.pmin
        fadd readout_decay
        fxch                ;// min     pmin    max     sum
        xor eax, eax
        fucom
        fnstsw ax
        sahf
        jae M3
        fst st(1)
    M3: fstp [esi].readout.min
        fstp [esi].readout.pmin

    update_max:

        CLIPTEST_ONE edx
        fld [esi].readout.pmax
        fsub readout_decay
        fxch                ;// max     pmax    sum
        xor eax, eax
        fucom
        fnstsw ax
        sahf
        jbe M4
        fst st(1)
    M4: fstp [esi].readout.max
        fstp [esi].readout.pmax

    update_rms_and_average:

        .IF edi                 ;// sum

            fmul math_1_1024    ;// AVE

        .ENDIF

        CLIPTEST_ONE edx
        fstp [esi].readout.aver

        inc edx ;// dirty

        jmp done_with_calc


    ALIGN 16
    not_a_meter:    ;///// TEXT //////////////////////////////////////////////////////

        ASSUME edi:PTR APIN
        mov edi, [edi].pData    ;// get source data pointer

        ASSUME edi:PTR DWORD
        mov eax, [edi]          ;// get the first value

        .IF eax != [esi].readout.last   ;// different ?
            mov [esi].readout.last, eax ;// store new value
            inc edx
        .ENDIF
        jmp done_with_calc

    ALIGN 16
    done_with_calc: ;///// CLIPPING ///////////////////////////////////////////////////
    check_clipping:

comment ~ /*
    was     now     now
    clip    clip    dirty
    0       0       0       exit
    1       1       0       exit
    0       0       1       DIRTY   inavlidate
    0       1       0       DIRTY   CLIPPING    invalidate
    0       1       1       DIRTY   CLIPPING    invalidate
    1       0       0       DIRTY   !CLIP       invalidate
    1       0       1       DIRTY   !CLIP       inavlidate
    1       1       1       DIRTY   CLIPPING    invalidate
*/ comment ~

        mov eax, [esi].dwUser
        TESTJMP edx, edx, jnz now_dirty

        BITR eax, READOUT_CLIPPING
        jc store_and_inval
        jmp all_done

    now_dirty:      DECJMP edx,                 jz not_clipping
    now_clipping:   or eax, READOUT_CLIPPING
                    jmp store_and_inval
    not_clipping:   and eax, NOT READOUT_CLIPPING
    store_and_inval:or eax, READOUT_DIRTY
                    mov [esi].dwUser, eax
                    invoke play_Invalidate_osc

not_connected:
not_on_screen:
all_done:

    ret

readout_Calc ENDP















ASSUME_AND_ALIGN
readout_InitMenu PROC   ;// STDCALL pObject:PTR OSC_OBJECT

        ASSUME esi:PTR OSC_OBJECT

        ;// set the correct unit type

        mov eax, [esi].dwUser
        .IF eax & READOUT_METER_TEST
            .IF eax & READOUT_METER1
                pushd   BST_CHECKED     ;// vu 1
                pushd   BST_UNCHECKED   ;// vu 2
            .ELSE
                pushd   BST_UNCHECKED   ;// vu 1
                pushd   BST_CHECKED     ;// vu 2
            .ENDIF
        .ELSE
            pushd   BST_UNCHECKED       ;// vu 1
            pushd   BST_UNCHECKED       ;// vu 2
        .ENDIF
        invoke unit_UpdateComboBox, IDC_READOUT_UNITS, 0    ;// not knob

        pushd ID_READOUT_METER2 ;// vu 2
        pushd popup_hWnd
        call CheckDlgButton

        pushd ID_READOUT_METER1 ;// vu 1
        pushd popup_hWnd
        call CheckDlgButton

        mov ecx, BST_UNCHECKED
        .IF [esi].dwUser & READOUT_SMALL
            mov ecx, BST_CHECKED
        .ENDIF
        invoke CheckDlgButton, popup_hWnd, ID_READOUT_SMALL, ecx

        xor eax, eax    ;// return zero or popup build will try to resize the object

        ret

readout_InitMenu ENDP


ASSUME_AND_ALIGN
readout_Command PROC

    ASSUME esi:PTR READOUT_OSC_MAP
    ASSUME ebp:PTR LIST_CONTEXT

    invoke unit_FromKeystroke
    jc set_new_units


;// UNITS from combo box

@@: cmp eax, OSC_COMMAND_COMBO_SELENDOK
    jne @F

    ;// ecx has the private dword for the units
    ;// ecx is now a unit

        mov edx, ecx
        jmp set_new_units

;// help text from combo box

@@: cmp eax, OSC_COMMAND_COMBO_SELCHANGE
    jne @F

    ;// this is our chance to update the help text
    ;// ecx has the unit id of the text
    ;// the new unit has NOT been selected yet

        ;// mov eax, POPUP_IGNORE

        invoke unit_HandleComboSelChange, IDC_READOUT_UNITS, ecx, 0 ;// not knob
        ;// returns values in eax and edx
        jmp all_done


@@: cmp eax, ID_READOUT_METER1
    jne @F

        mov edx, READOUT_METER1
        jmp set_new_units

@@: cmp eax, ID_READOUT_METER2
    jne @F

        mov edx, READOUT_METER2
        jmp set_new_units

@@: cmp eax, ID_READOUT_SMALL
    jne osc_Command

        BITC [esi].dwUser, READOUT_SMALL
        mov eax, READOUT_SMALL_ADJUST_X
        mov edx, READOUT_SMALL_ADJUST_Y
        .IF CARRY?
            neg eax
            neg edx
        .ENDIF
        point_AddToTL [esi].rect
        GDI_INVALIDATE_OSC HINTI_OSC_SHAPE_CHANGED OR HINTI_OSC_MOVED
        mov eax, POPUP_SET_DIRTY OR POPUP_REDRAW_OBJECT
        jmp all_done

ALIGN 16
set_new_units:

    or edx, READOUT_DIRTY
    and [esi].dwUser, NOT (UNIT_TEST OR UNIT_AUTO_UNIT OR READOUT_METER_TEST)
    or [esi].dwUser, edx

    invoke readout_SetPin

    mov eax, POPUP_SET_DIRTY OR POPUP_REDRAW_OBJECT OR POPUP_INITMENU

all_done:

    ret

readout_Command ENDP



;////////////////////////////////////////////////////////////////////
;//
;//
;//     _LoadUndo
;//

ASSUME_AND_ALIGN
readout_LoadUndo PROC

        ASSUME esi:PTR OSC_OBJECT   ;// preserve
        ASSUME ebp:PTR LIST_CONTEXT ;// preserve


        mov eax, [edi]
        or eax, READOUT_DIRTY

        xchg [esi].dwUser, eax
        xor eax, [esi].dwUser

        .IF eax & READOUT_SMALL ;// did small change ?

            mov eax, READOUT_SMALL_ADJUST_X
            mov edx, READOUT_SMALL_ADJUST_Y
            BITT [esi].dwUser, READOUT_SMALL
            .IF !CARRY?
                neg eax
                neg edx
            .ENDIF
            point_AddToTL [esi].rect

            or [esi].dwHintI, (HINTI_OSC_SHAPE_CHANGED OR HINTI_OSC_MOVED)

        .ENDIF

        invoke readout_SetPin

        ret

readout_LoadUndo ENDP

;//
;//
;//     _LoadUndo
;//
;////////////////////////////////////////////////////////////////////










ASSUME_AND_ALIGN


ENDIF   ;// USE_THIS_FILE
END












