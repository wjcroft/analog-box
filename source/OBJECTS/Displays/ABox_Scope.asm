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
;// ABox_Scope.asm
;//
;//
;// TOC
;//
;// scope_H_Ctor
;// scope_H_Dtor
;// scope_sync_pins
;// scope_GetUnit
;// scope_render_labels
;// scope_set_default_labels
;// scope_Ctor
;// scope_Dtor
;// scope_build_container
;// scope_SetShape
;// scope_hide_oscilloscope
;// scope_hide_spectrum
;// scope_hide_sonograph
;// scope_init_sonograph_popup
;// scope_init_oscilloscope_popup
;// scope_init_spectrum_popup
;// scope_show_oscilloscope
;// scope_show_spectrum
;// scope_show_sonograph
;// scope_InitMenu
;// scope_Command
;// scope_LoadUndo
;// scope_Write
;//
;// draw_part_column
;// draw_these_lines
;// connect_min_max
;// draw_min_max_dual
;// scope_dib_shift
;// connect_the_dots
;// render_min_max
;// scope_Render_calc
;// scope_Render
;// scope_PrePlay
;// scope_fill_scan
;// scope_scan_quarter
;// scope_scan_full
;// scope_scan_external_Y
;// scope_scan_external_X
;// oscope_update_indexes
;// get_r_value
;// spec_Convert
;// sono_Convert
;// scope_Calc



OPTION CASEMAP:NONE

.586
.MODEL FLAT

USE_THIS_FILE equ 1

IFDEF USE_THIS_FILE


        .NOLIST
        INCLUDE <Abox.inc>
        INCLUDE <fft_abox.inc>
        INCLUDE <abox_knob.inc>
        ;//.LIST
        .LISTALL
        ;//.LISTMACROALL

comment ~ /*

THE NEW ABOX2 SCOPE:

    combines the oscilloscope, spectrum analyzer, and a songraph
    so there are three semi-interrelated operating modes

OVERVIEW:

    OSCILLOSCOPE:

        pins:   y1, y2  input data for channel 1 and 2
                r1, r2  vertical range for ch1 and ch2
                o1, o2  offset for ch1 and ch2
                X       optional for external sweep
                s       option external sweep (same as s)

        options:

            sweep   0   1   2   3   4   5   6   7
            scroll                  y   y   y
            trigger none|pos|neg & retrigger

    SCPECTRUM ANALYZER:

        pins:   y1      input data
                r1      vertical scale
                o1      frequency offset (optional for range)

        options:

            freq range  0   1   2   3
            ch2 = average magnitude

    SONOGRAPH:

        pins:   y1      input data
                r1      video gain
                o1      vertical offset (optional for vert range)

        options:

            horizontal range    0   1   2
            vertical range      0   1   2
            scroll is always on


IMPLEMENTATION OUTLINE:

    the picture (dib_container) is always 256 by 128
    the xfer of input signal to the dib happen in two stages, acquisition, and convertion

    data to be rendered is arranged in columns (1 per x for a total of 256)
    there are two arrays, one for each channel
    each column represents a top and a bottom to be drawn between
    keeping track of what needs updated, is N0 and N1
    a third variable, N, handles the sweep

    scope_Calc is then responsible for xferring input data to the Y array's
    it does this first by determining min max values for the desired input range
  data for this is stored in a shared array ?
    then scan agains again to determine the top and bottom, which is stored in the object

    spectrum mode (both analyzer and sonograph) require that the previous input be stored
    this is done in the object.pData
    fft's are then done as reqired to produce the desired display

  data sizes:

    the column arrays require 4 integer values per column, for a total 1024 elements
    none of the values will EVER be larger than 127,

    the min/max values are first stored as large integers,
    these can be stored in the same array as the columns,
    as long as they are converted before the render gets to them


    OSCILLOSCOPE:

        data can be xfered directly from input to min max arrays

        minimum internal storage: 0


    SPECTRUM MODE:

        for the spectrum, we need to take advantage of the dual 1024 point fft

        assume input of X0 from the current frame
        assume storage of Y0 and Y1

        calc    action

        0       copy X0 to Y0
                display Y1
        1       fft(Y0, X0) to Y1 and Y0
                display Y0
        repeat

        minimum internal storage: 2 blocks of 1024
        average and phase display require a second block of 1024
        one of the Y can be external, since it will displayed imediately

        addendum: phase display is vsiually messy and not very important anyways
                  status: removed


    SONGRAPH MODE:

        we need two blocks of contigous memory, call them Y0 and Y1
        we also need contigous blocks of input frames

        copy data0 to X1, X0 was filled previously

        fft(X0,X0+overlap) to Y0,Y1
            display colum Y0
            display colum Y1
        fft(X0+overlap*2, X0+overlap*3) to Y0, Y1
            display colum Y0
            display colum Y1
        until both frames are entirely used

        copy X1 to X0

        minimum internal storage:   2 blocks of 1024
        minimum external storage:   2 block of 1024


    MINIMUM STORAGE PER OBJECT

        X0, X1      2 blocks of 1024 dwords
        min/max     4 blocks of 256 dwords

        this will all be stored in osc data, and is the same as the object
        having 3 output pins

            size = 12K + 7 pins + osc_object

*/ comment ~


;////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////
;///
;///
;///        S C O P E
;///

.DATA

        SCOPE_WIDTH  EQU 256
        SCOPE_HEIGHT EQU 128

    ;// this struct hold the min max values for one channel
    ;// this can hold XY values as well

        SCOPE_MIN_MAX   STRUCT

            min dd  SCOPE_WIDTH dup (0)
            max dd  SCOPE_WIDTH dup (0)

        SCOPE_MIN_MAX   ENDS

    ;// as described above, we get some internal data storage

        OSCOPE STRUCT

            N   dd  0   ;// current index into the table
                        ;// or a yes no flag to indicate we need a new fft ?
            N0  dd  0   ;// start of the invalidate
            N1  dd  0   ;// end of the invalidate

            dwFlags     dd 0    ;// invalidating flags, see below

            NC          dd 0    ;// counter for overlapped modes (range1_5 and _6)
            dib_shift   dd 0    ;// tells render to shift the dib before rendering

            sono_offset dd 0    ;// storage for the offset
            remain      dd 0    ;// remaining samples in current block (for triggered)

            ;// column arrays (min max values)
            C0  SCOPE_MIN_MAX {}    ;// array of columns for our graphic
            C1  SCOPE_MIN_MAX {}    ;// array of columns for our graphic

            ;// previous data
            Y0  dd  SAMARY_LENGTH dup (0)   ;// input storage and manipulation
            Y1  dd  SAMARY_LENGTH dup (0)   ;//

            ;// labels and their values
            ;//                         oscope      spectrum        sono
            value_1 REAL4 0.0e+0    ;// ch1 max     min freq
            value_2 REAL4 0.0e+0    ;// ch2 max
            value_3 REAL4 0.0e+0    ;// ch1 min     max freq
            value_4 REAL4 0.0e+0    ;// ch2 min

            label_1 db 24 DUP(0)
            label_2 db 24 DUP(0)
            label_3 db 24 DUP(0)
            label_4 db 24 DUP(0)

            ;// units for chan 1 and 2 in oscope mode
            unit_1  dd  0
            unit_2  dd  0

            ;// lastly, the size of the display

            siz POINT {}

        OSCOPE ENDS


        ;// flag values are used to accumulate render operations
        ;// we do this because render is called by two threads

            C0_INVALID          equ 00000001h   ;// C1 is to be rendered
            C1_INVALID          equ 00000002h   ;// C2 is to be rendered

            INVALIDATE_C0       equ 00000010h   ;// interlock to prevent rendering
            INVALIDATE_C1       equ 00000020h   ;// until data is actually ready

            BUILD_LABEL_1       equ 00000100h   ;// rebuild this label with the value
            BUILD_LABEL_2       equ 00000200h   ;// set by calc, reset by render
            BUILD_LABEL_3       equ 00000400h   ;// may also be set by scope_Command
            BUILD_LABEL_4       equ 00000800h   ;// and set by scope_GetUnit
            BUILD_LABEL_TEST    equ 00000F00h

            INVALIDATE_LABEL_1  equ 00001000h   ;// reINVALIDATE this label with the value
            INVALIDATE_LABEL_2  equ 00002000h   ;// set by calc, reset by render
            INVALIDATE_LABEL_3  equ 00004000h   ;// may also be set by scope_Command
            INVALIDATE_LABEL_4  equ 00008000h   ;// and set by scope_GetUnit

            SCOPE_INVALIDATE_TEST equ 00F033h   ;// test if anything needs invalidated
            SCOPE_INVALIDATE_MASK equ NOT SCOPE_INVALIDATE_TEST
            SCOPE_INVALIDATE_SHIFT equ 4



;// OScope OSC_OBJECT definition

osc_Scope   OSC_CORE  { scope_Ctor,scope_Dtor,scope_PrePlay,scope_Calc }
            OSC_GUI { scope_Render,scope_SetShape,,,,
                      scope_Command,scope_InitMenu,,,
                      osc_SaveUndo, scope_LoadUndo, scope_GetUnit}
            OSC_HARD { scope_H_Ctor, scope_H_Dtor }

    BASE_FLAGS EQU BASE_PLAYABLE OR BASE_BUILDS_OWN_CONTAINER OR BASE_HAS_AUTO_UNITS

    OSC_DATA_LAYOUT { NEXT_Scope, IDB_SCOPE,OFFSET popup_SCOPE, BASE_FLAGS,
        7, 4,
        SIZEOF OSC_OBJECT + (SIZEOF APIN * 7),
        SIZEOF OSC_OBJECT + (SIZEOF APIN * 7),
        SIZEOF OSC_OBJECT + (SIZEOF APIN * 7) + SIZEOF OSCOPE }

    OSC_DISPLAY_LAYOUT {,,ICON_LAYOUT(13,1,3,6)}

    APIN_init {-0.95,           ,'1Y',,UNIT_AUTO_UNIT  }  ;// in 1
    APIN_init {-0.15,sz_Range   ,'1r',,UNIT_AUTO_UNIT  }  ;// A1
    APIN_init {-0.1 ,sz_Offset  ,'1o',,UNIT_AUTO_UNIT  }  ;// O1

    APIN_init { 0.95,           ,'2Y',,UNIT_AUTO_UNIT  }  ;// in 2
    APIN_init { 0.1 ,sz_Range   ,'2r',,UNIT_AUTO_UNIT  }  ;// A2
    APIN_init { 0.15,sz_Offset  ,'2o',,UNIT_AUTO_UNIT  }  ;// O2

    APIN_init { 0.85,sz_Sweep   ,'X' ,,UNIT_VALUE  }  ;// ext sweep or trigger

    short_name  db  'Scope',0
    description db  'Display may be set as an Oscilloscope, Spectrum analyzer, or Sonograph.',0
    ALIGN 4

    ;// heh heh, no sense trying to remember these...

        PIN_Y1 equ 0
        PIN_R1 equ 1
        PIN_O1 equ 2
        PIN_Y2 equ 3
        PIN_R2 equ 4
        PIN_O2 equ 5
        PIN_X  equ 6

    ;// settings are stored in object.dwUser

    ;// oscope settings

        ;// RANGE1                          sweep rates
        ;// SCOPE_RANGE1_0  equ 00000000h   ;// 1/4     1:1 sample per pixel
        SCOPE_RANGE1_1      equ 00000001h   ;// 1       4:1 samples per pixel
        SCOPE_RANGE1_2      equ 00000002h   ;// 4       16:1
        SCOPE_RANGE1_3      equ 00000003h   ;// 16      64:1
        SCOPE_RANGE1_4      equ 00000004h   ;// 64      256:1
        SCOPE_RANGE1_5      equ 00000005h   ;// 256     1024:1  new col every frame
        SCOPE_RANGE1_6      equ 00000006h   ;// 1024    4096:1  new col every 4th frame
        SCOPE_RANGE1_7      equ 00000007h   ;// external (x-y mode)
        SCOPE_RANGE1_TEST   equ 00000007h
        SCOPE_SCROLL        equ 00100000h   ;// only available for RANGE1_4 through 6

    ;//auto unit sync bits read and set by unit_AutoTrace

        SCOPE_UNIT_AUTO     equ 00000800h   ;// same as UNIT_AUTO  turned on by ctor
    ;// SCOPE_UNIT_TRACE    equ 10000000h   ;// pre abox221 same as UNIT_AUTO_TRACE set by unit_AutoTrace
    ;// UNIT_AUTO_TRACE     EQU 00040000h   ;// abox221+ osc only, tells osc it' time to figure it out

        ;//SCOPE_UNITS_VALUEequ 00000000h   ;// these bits exist in old versions
        ;//SCOPE_UNITS_HERTZequ 00010000h
        ;//SCOPE_UNITS_MIDI equ 00020000h
        ;//SCOPE_UNITS_TEST equ 00030000h
        ;//SCOPE_UNITS_MASK equ NOT SCOPE_UNITS_TEST

    ;// trigger levels

        SCOPE_TRIG_POS      equ 20000000h   ;// had to move these for auto units
        SCOPE_TRIG_NEG      equ 40000000h   ;// old bits were shifted right --> 1
        SCOPE_TRIG_TEST     equ 60000000h   ;// ctor does the conversion

    ;// spectrum settings

        ;// RANGE2                          spectral wdiths
        ;// SCOPE_RANGE2_0  equ 00000000h   ;// 4:1 eighth spectrum
        SCOPE_RANGE2_1      equ 00000010h   ;// 2:1 quarter spectrum
        SCOPE_RANGE2_2      equ 00000020h   ;// 1:1 half spectrum 1:1 pixel per bin
        SCOPE_RANGE2_3      equ 00000030h   ;// 1:2 full spectrum
        SCOPE_RANGE2_TEST   equ 00000030h
        SCOPE_AVERAGE       equ 00000040h   ;// show average trace

    ;// songraph settings

        ;// RANGE3                          horizontal rate
        ;// SCOPE_RANGE3_0  equ 00000000h   ;// 4 per frame
        SCOPE_RANGE3_1      equ 00000100h   ;// 2 per frame
        SCOPE_RANGE3_2      equ 00000200h   ;// 1 per frame
        SCOPE_RANGE3_TEST   equ 00000300h

        ;// RANGE4                          vertical scale
        ;// SCOPE_RANGE4_0  equ 00000000h   ;// 1 to 1  quarter spectrum (1 pixel per bin)
        SCOPE_RANGE4_1      equ 00001000h   ;// 2 to 1  half spectrum
        SCOPE_RANGE4_2      equ 00002000h   ;// 4 to 1  full spectrum

        SCOPE_RANGE4_TEST   equ 00003000h

    ;// display settings

        SCOPE_ON            equ 00200000h   ;// the scope is on
        SCOPE_LABELS        equ 00400000h   ;// show labels and ranges

    ;// scope mode

        SCOPE_OSCILLOSCOPE  equ 00000000h
        SCOPE_SPECTRUM      equ 01000000h
        SCOPE_SONOGRAPH     equ 02000000h

        SCOPE_MODE_TEST     equ 03000000h







    ;// global storage for spectrum settings
    ;// these are allocated and deallocated by the hardware ctor

        scope_Z0    dd  0   ;// allocated block of memory
        scope_Z1    dd  0   ;// points into Z0
        scope_max_video REAL4 992.25e+0 ;// 31.5^2

    ;// freq limits for spectrum offset input

    spectrum_freq_limit LABEL REAL4     ;// max input we allow
        REAL4 0.873046875   ;// 447/512
    sono_freq_limit LABEL REAL4
        REAL4 0.748046875   ;// 383/512
        REAL4 0.498046875   ;// 255/512
        REAL4 0.0

    spectrum_freq_offset LABEL REAL4    ;// offset to the end of the spectrum
        REAL4   0.125
    sono_freq_offset    LABEL REAL4
        REAL4   0.25
        REAL4   0.5
        REAL4   1.0

    ;// offset for blitting the legend for the songraph

        sono_legend_shift   dd  0

    ;// strings for labels

        sz_oscope_off   db  'O-Scope OFF',0
        ALIGN 4
        sz_oscope_on    db  'O-Scope ON',0
        ALIGN 4
        sz_spectrum_off db  'Spectrum OFF',0
        ALIGN 4
        sz_spectrum_on  db  'Spectrum ON',0
        ALIGN 4
        sz_sonograph_off db 'Sonograph OFF',0
        ALIGN 4
        sz_sonograph_on db  'Sonograph ON',0
        ALIGN 4


        sz_scope_time_label LABEL BYTE

            db  '5.80ms',0,0
            db  '23.2ms',0,0
            db  '92.8ms',0,0
            db  '371ms',0,0,0
            db  '1.48sec',0
            db  '5.94sec',0
            db  '23.7sec',0
            db  'extern',0,0

        sz_sono_span_label LABEL BYTE

            db  '1.48sec',0
            db  '2.97sec',0
            db  '5.94sec',0




    ;// display layout

        SCOPE_LABEL_HEIGHT equ 12
        ;//SCOPE_MODE_WIDTH   equ 64
        ;//SCOPE_TIME_WIDTH





    ;// OSC_MAP for this object

    OSCOPE_OSC_MAP  STRUCT

        OSC_OBJECT  {}

        pin_y1  APIN    {}
        pin_r1  APIN    {}
        pin_o1  APIN    {}

        pin_y2  APIN    {}
        pin_r2  APIN    {}
        pin_o2  APIN    {}

        pin_x   APIN    {}

        scope   OSCOPE  {}

    OSCOPE_OSC_MAP  ENDS




















.CODE

;////////////////////////////////////////////////////////////////////
;//
;//
;//     static structors
;//

ASSUME_AND_ALIGN
scope_H_Ctor    PROC

    invoke about_SetLoadStatus

    ;// allocate the Z0 and Z1 memory block

    invoke memory_Alloc, GPTR, 2048*4   ;// two blocks of 1024 DWORDS
    mov scope_Z0, eax
    add eax, 1024*4
    mov scope_Z1, eax

    ;// then we register ourseleves so we get dtored

    slist_AllocateHead hardwareL, ebx

    mov [ebx].ID, 0
    mov [ebx].pBase, OFFSET osc_Scope

    ret

scope_H_Ctor ENDP

ASSUME_AND_ALIGN
scope_H_Dtor    PROC    ;// pDevBlock:DWORD

    DEBUG_IF <!!scope_Z0>   ;// how'd this happen ??

    invoke memory_Free, scope_Z0

    ret 4

scope_H_Dtor    ENDP

;//
;//
;//     static structors
;//
;////////////////////////////////////////////////////////////////////










;////////////////////////////////////////////////////////////////////
;//
;//
;//     object helper functions
;//

ASSUME_AND_ALIGN
scope_sync_pins PROC uses edi ebx


    ASSUME ebp:PTR LIST_CONTEXT
    ASSUME esi:PTR OSCOPE_OSC_MAP

;// this makes sure that the pins are correct for our mode

    mov ebx, [esi].dwUser
    BITTJMP ebx, SCOPE_SPECTRUM, jnc @F

;//
;// SPECTRUM MODE
;//
    ;// hide the non spectrum related pins

        OSC_TO_PIN_INDEX esi, edi, PIN_Y2   ;// stop
        xor ecx, ecx
        OSC_TO_PIN_INDEX esi, ebx, PIN_X    ;// start
        .REPEAT
            invoke pin_Show, ecx    ;// GDI_INVALIDATE_PIN HINTI_PIN_HIDE
            sub ebx, SIZEOF APIN
        .UNTIL ebx < edi

    ;// then o0 is only valid if the range is not 3

        mov ecx, [esi].dwUser
        and ecx, SCOPE_RANGE2_TEST
        sub ecx, SCOPE_RANGE2_3
        invoke pin_Show, ecx

    ;// exit to setup the units

        jmp set_spectrum_units

;//////////////////////////////////////////////////////////////////

@@: BITTJMP ebx, SCOPE_SONOGRAPH, jnc @F


;//
;// SONOGRAPH MODE
;//
    ;// hide the non songraph related pins

        OSC_TO_PIN_INDEX esi, edi, PIN_Y2   ;// stop
        xor ecx, ecx
        OSC_TO_PIN_INDEX esi, ebx, PIN_X    ;// start
        .REPEAT
            invoke pin_Show, ecx    ;// GDI_INVALIDATE_PIN HINTI_PIN_HIDE
            sub ebx, SIZEOF APIN
        .UNTIL ebx < edi

    ;// then o0 is only valid if the range4 is not 3

        mov ecx, [esi].dwUser
        and ecx, SCOPE_RANGE4_TEST
        sub ecx, SCOPE_RANGE4_2
        invoke pin_Show, ecx


set_spectrum_units:

    ;// setup the units

        lea ebx, [esi].pin_y1
        mov eax, UNIT_AUTO_UNIT
        invoke pin_SetUnit

        lea ebx, [esi].pin_r1
        mov eax, UNIT_DB
        invoke pin_SetUnit

        lea ebx, [esi].pin_o1
        mov eax, UNIT_HERTZ
        invoke pin_SetUnit

    ;// that should do it

        jmp all_done

;//////////////////////////////////////////////////////////////////

@@:
;//
;// OSCILLOSCOPE MODE
;//

    ;// always reset the sweep

        ASSUME esi:PTR OSCOPE_OSC_MAP
        mov [esi].scope.N, 0
        mov [esi].scope.N0, 0
        mov [esi].scope.N1, 0

    ;// make sure all the appropriate pins are shown
    ;// while we scan, we'll set the units

        OSC_TO_PIN_INDEX esi, ebx, PIN_Y1   ;// start
        mov ecx, UNIT_AUTO_UNIT ;// unhide
        OSC_TO_PIN_INDEX esi, edi, PIN_X    ;// stop
        .REPEAT
            invoke pin_Show, ecx    ;// GDI_INVALIDATE_PIN HINTI_PIN_UNHIDE
            mov eax, ecx
            invoke pin_SetUnit
            add ebx, SIZEOF APIN    ;// iterate forwards
        .UNTIL ebx >= edi

    ;// X is only valid when in ext mode or if trigger is one

        ;// ebx is currently at the X pin

        mov ecx, [esi].dwUser
        and ecx, SCOPE_RANGE1_TEST

        .IF ecx == SCOPE_RANGE1_7

            ;// make sure the name and shape is corrrect
            PIN_TO_FSHAPE ebx, ecx
            .IF [ecx].character != 'X'

                ;// need a new letter and shape

                push edi

                mov eax, 'X'
                lea edi, font_pin_slist_head
                invoke font_Locate
                mov [ebx].pFShape, edi

                pop edi

                and [ebx].dwStatus, NOT PIN_LOGIC_INPUT

                xor eax, eax
                invoke pin_SetInputShape    ;// not trigger

            .ENDIF

            ;// some how we have to make sure the triangle shape is assigned, not the logic shape
            invoke pin_Show, 1

        .ELSEIF ([esi].dwUser & SCOPE_TRIG_TEST) && !([esi].dwUser & SCOPE_SCROLL)

            ;// make sure the name and shape are corrrect
            PIN_TO_FSHAPE ebx, ecx
            .IF [ecx].character == 'X'

                ;// need a new letter and shape

                push edi

                mov eax, 's'
                lea edi, font_pin_slist_head
                invoke font_Locate
                mov [ebx].pFShape, edi

                pop edi

            .ENDIF

            mov eax, [esi].dwUser
            and eax, SCOPE_TRIG_TEST
            BITSHIFT eax, SCOPE_TRIG_POS, PIN_LEVEL_POS
            or eax, PIN_LOGIC_INPUT

            invoke pin_SetInputShape    ;// Trigger
            invoke pin_Show, 1

        .ELSE

            invoke pin_Show, 0  ;// hide the pin

        .ENDIF


all_done:

    ;// reset the channel units

        mov [esi].scope.unit_1, UNIT_VALUE
        mov [esi].scope.unit_2, UNIT_VALUE

    ;// beat it

        ret

scope_sync_pins ENDP

;//
;//
;//     object helper functions
;//
;////////////////////////////////////////////////////////////////////

.DATA

    ALIGN 4
    get_unit_jump LABEL DWORD
    dd  guj_0   ;// edx and eax are not autoed
    dd  guj_1   ;// edx is autoed, eax is not
    dd  guj_2   ;// eax is autoed, edx is not
    dd  guj_3   ;// bothe are autoed, need to compare

.CODE


ASSUME_AND_ALIGN
scope_GetUnit PROC

        ASSUME esi:PTR OSCOPE_OSC_MAP
        ASSUME ebx:PTR APIN

        ;// must preserve edi and ebp


comment ~ /*

scheme:

    we are in a 'propegate auto unit' quest
    so if we have any pins with auto unit set, then we xfer them to the other pins
    in the process, if we end up with a different unit than what we store internally
    we set the 'update label' flag

details:

    two channels of Y input, o input, r input

    all three should have same unit
    any combination may have units set

    Y sould set the units for r and o
    if Y does not have a unit
        xfer unit from r or o to Y

*/ comment ~

;// determine the mode

    test [esi].dwUser, SCOPE_MODE_TEST
    jnz spectrum_or_sono_mode

;// figure out which pin we're looking at

gu_Y1:  lea ecx, [esi].pin_y1   ;// pin_y1
        cmp ecx, ebx
        jne gu_R1
        ;// we want units for Y1
        lea eax, [esi].pin_r1
        lea edx, [esi].pin_o1
        jmp check_channels

gu_R1:  add ecx, SIZEOF APIN    ;// pin_r1
        cmp ecx, ebx
        jne gu_O1
        ;// we want units for R1
        lea eax, [esi].pin_y1
        lea edx, [esi].pin_o1
        jmp check_channels

gu_O1:  add ecx, SIZEOF APIN    ;// pin_o1
        cmp ecx, ebx
        jne gu_Y2
        ;// we want units for O1
        lea eax, [esi].pin_y1
        lea edx, [esi].pin_r1
        jmp check_channels

gu_Y2:  add ecx, SIZEOF APIN    ;// pin_y2
        cmp ecx, ebx
        jne gu_R2
        ;// we want units for Y2
        lea eax, [esi].pin_r2
        lea edx, [esi].pin_o2
        jmp check_channels

gu_R2:  add ecx, SIZEOF APIN    ;// pin_r2
        cmp ecx, ebx
        jne gu_O2
        ;// we want units for R2
        lea eax, [esi].pin_y2
        lea edx, [esi].pin_o2
        jmp check_channels

gu_O2:  add ecx, SIZEOF APIN    ;// pin_o2
        cmp ecx, ebx
        jne return_fail
        ;// we want units for O2
        lea eax, [esi].pin_y2
        lea edx, [esi].pin_r2
        ;//jmp check_channels

check_channels:

        ASSUME eax:PTR APIN ;// eax points at one pin
        ASSUME edx:PTR APIN ;// edx points at other pin

        xor ecx, ecx    ;// clear for testing and building jmp

        cmp [eax].pPin, ecx     ;// is pin connected ?
        mov eax, [eax].dwStatus ;// load the status
        jnz @F
        mov eax, ecx            ;// clear if not connected
        @@:

        cmp [edx].pPin, ecx     ;// is pin connected ?
        mov edx, [edx].dwStatus ;// load the status
        jnz @F
        mov edx, ecx            ;// clear if not connected
        @@:

        ASSUME eax:NOTHING
        ASSUME edx:NOTHING

        BITT eax, UNIT_AUTOED
        adc ecx, ecx    ;// 1 or zero
        BITT edx, UNIT_AUTOED
        rcl ecx, 1
        jmp get_unit_jump[ecx*4]    ;// see get_unit_jump for details

guj_3:: and eax, UNIT_TEST
        and edx, UNIT_TEST
        cmp eax, edx
        jne return_fail
guj_1:: mov eax, edx        ;// edx has unit, eax does not
guj_2:: and eax, UNIT_TEST  ;// eax has unit, edx does not
        stc
guj_0::                     ;// carry flag already cleared
all_done:

        ret


spectrum_or_sono_mode:
return_fail:

    clc         ;// no carry for fail
    jmp all_done


scope_GetUnit ENDP




;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;//
;//                 these routines show the labels and or set default values
;//     LABELS      it always renders to gdi_bitmap
;//                 so scrolling and cleanup isn't a problem as long as
;//                 osc_Render was called BEFORE calling this
;//
ASSUME_AND_ALIGN
scope_render_labels PROC uses edi


    ASSUME esi:PTR OSCOPE_OSC_MAP       ;// presereved
    ;//ASSUME edi:PTR OSC_SCOPE ;// preserved

    ;// OSC_TO_DATA esi, edi, OSC_SCOPE

    sub esp, SIZEOF RECT
    st_rect TEXTEQU <(RECT PTR [esp])>

    ;// stack looks like this
    ;// rect    ret

    ;// set up the dc and define the rect for showing the mode

        GDI_DC_SET_COLOR COLOR_OSC_TEXT
        GDI_DC_SELECT_FONT hFont_osc

        point_GetTL [esi].rect
        add eax, 2          ;// border
        ;//add edx, 2
        point_SetTL st_rect
        point_GetBR [esi].rect
        sub eax, 2          ;// border
        ;//sub edx, 2
        point_SetBR st_rect
        mov ebx, esp    ;// ebx is the rect pointer

    ;// dtermine which mode

        mov ecx, [esi].dwUser
        bt ecx, LOG2(SCOPE_SPECTRUM)
        jc spectrum_mode
        bt ecx, LOG2(SCOPE_SONOGRAPH)
        jc sonograph_mode

oscilloscope_mode:

    ;// show the mode

        lea ecx, sz_oscope_on
        mov edx, (SIZEOF sz_oscope_on) - 1
        .IF !([esi].dwUser & SCOPE_ON)
            lea ecx, sz_oscope_off
            mov edx, (SIZEOF sz_oscope_off) - 1
        .ENDIF

        invoke DrawTextA, gdi_hDC, ecx, edx, ebx, DT_NOCLIP + DT_RIGHT + DT_TOP + DT_SINGLELINE

    ;// show the span

        mov ecx, [esi].dwUser
        and ecx, SCOPE_RANGE1_TEST
        lea ecx, sz_scope_time_label[ecx*8]
        invoke DrawTextA, gdi_hDC, ecx, -1, ebx, DT_NOCLIP + DT_RIGHT + DT_BOTTOM + DT_SINGLELINE

    ;// skip building labels if nothing is connected

    .IF [esi].pin_y1.pPin || [esi].pin_y2.pPin

    ;// determine if we need to build any labels, and build them

        BITR [esi].dwUser, UNIT_AUTO_TRACE
        mov ebx, [esi].scope.dwFlags        ;// get the flags
        .IF CARRY?

        ;// look for auto units on channel 1

            test [esi].pin_r1.dwStatus, UNIT_AUTOED
            mov eax, [esi].pin_r1.dwStatus
            jnz got_chan_1_unit

            test [esi].pin_o1.dwStatus, UNIT_AUTOED
            mov eax, [esi].pin_o1.dwStatus
            jnz got_chan_1_unit

            test [esi].pin_y1.dwStatus, UNIT_AUTOED
            mov eax, [esi].pin_y1.dwStatus
            jnz got_chan_1_unit

            xor eax, eax

        got_chan_1_unit:

            and eax, UNIT_TEST
            .IF eax != [esi].scope.unit_1
                mov [esi].scope.unit_1, eax
                or ebx, BUILD_LABEL_1 OR BUILD_LABEL_3
            .ENDIF

        ;// look for auto units on channel 2

            test [esi].pin_r2.dwStatus, UNIT_AUTOED
            mov eax, [esi].pin_r2.dwStatus
            jnz got_chan_2_unit

            test [esi].pin_o2.dwStatus, UNIT_AUTOED
            mov eax, [esi].pin_o2.dwStatus
            jnz got_chan_2_unit

            test [esi].pin_y2.dwStatus, UNIT_AUTOED
            mov eax, [esi].pin_y2.dwStatus
            jnz got_chan_2_unit

            xor eax, eax

        got_chan_2_unit:

            and eax, UNIT_TEST
            .IF eax != [esi].scope.unit_2
                mov [esi].scope.unit_2, eax
                or ebx, BUILD_LABEL_2 OR BUILD_LABEL_4
            .ENDIF

        .ENDIF

        .IF ebx & BUILD_LABEL_TEST

            ;// build appropriate items

                btr ebx, LOG2(BUILD_LABEL_1)    ;// max value for channel 1
                .IF CARRY?
                    mov DWORD PTR [esi].scope.label_1, ':1hc'
                    fld [esi].scope.value_1
                    invoke unit_BuildString, ADDR [esi].scope.label_1[4], [esi].scope.unit_1, 0
                .ENDIF

                btr ebx, LOG2(BUILD_LABEL_2)    ;// max value for channel 2
                .IF CARRY?
                    mov DWORD PTR [esi].scope.label_2, ':2hc'
                    fld [esi].scope.value_2
                    invoke unit_BuildString, ADDR [esi].scope.label_2[4], [esi].scope.unit_2, 0
                .ENDIF

                btr ebx, LOG2(BUILD_LABEL_3)    ;// min value for channel 1
                .IF CARRY?
                    mov DWORD PTR [esi].scope.label_3, ':1hc'
                    fld [esi].scope.value_3
                    invoke unit_BuildString, ADDR [esi].scope.label_3[4], [esi].scope.unit_1, 0
                .ENDIF

                btr ebx, LOG2(BUILD_LABEL_4)    ;// min value for channel 2
                .IF CARRY?
                    mov DWORD PTR [esi].scope.label_4, ':2hc'
                    fld [esi].scope.value_4
                    invoke unit_BuildString, ADDR [esi].scope.label_4[4], [esi].scope.unit_2, 0
                .ENDIF

            ;// store the flags

                mov [esi].scope.dwFlags, ebx

        .ENDIF

    ;// show the labels in the correct spot
    ;// to know which channels to show, look at the pin connections

    ;// start by building the top rect, then each channel will scan down

        OSC_TO_PIN_INDEX esi, ecx, PIN_Y1
        OSC_TO_PIN_INDEX esi, edx, PIN_Y2
        mov ecx, [ecx].pPin
        mov edx, [edx].pPin

        mov ebx, esp    ;// reload the rect pointer

        or ecx, ecx
        jz no_chan_1

        or edx, edx
        jz chan_1_only

    chan_1_and_2:

        sub st_rect.bottom, SCOPE_LABEL_HEIGHT

        GDI_DC_SET_COLOR COLOR_GROUP_DISPLAYS+31

        invoke DrawTextA, gdi_hDC, ADDR [esi].scope.label_1, -1, ebx, DT_NOCLIP + DT_LEFT + DT_TOP + DT_SINGLELINE
        invoke DrawTextA, gdi_hDC, ADDR [esi].scope.label_3, -1, ebx, DT_NOCLIP + DT_LEFT + DT_BOTTOM + DT_SINGLELINE

        GDI_DC_SET_COLOR COLOR_GROUP_DISPLAYS+25
        add st_rect.top, SCOPE_LABEL_HEIGHT
        add st_rect.bottom, SCOPE_LABEL_HEIGHT

        invoke DrawTextA, gdi_hDC, ADDR [esi].scope.label_2, -1, ebx, DT_NOCLIP + DT_LEFT + DT_TOP + DT_SINGLELINE
        invoke DrawTextA, gdi_hDC, ADDR [esi].scope.label_4, -1, ebx, DT_NOCLIP + DT_LEFT + DT_BOTTOM + DT_SINGLELINE

        jmp all_done

    chan_1_only:

        GDI_DC_SET_COLOR COLOR_GROUP_DISPLAYS+31

        invoke DrawTextA, gdi_hDC, ADDR [esi].scope.label_1, -1, ebx, DT_NOCLIP + DT_LEFT + DT_TOP + DT_SINGLELINE
        invoke DrawTextA, gdi_hDC, ADDR [esi].scope.label_3, -1, ebx, DT_NOCLIP + DT_LEFT + DT_BOTTOM + DT_SINGLELINE

        jmp all_done

    no_chan_1:

        or edx, edx
        jz all_done

    chan_2_only:

        GDI_DC_SET_COLOR COLOR_GROUP_DISPLAYS+23

        invoke DrawTextA, gdi_hDC, ADDR [esi].scope.label_2, -1, ebx, DT_NOCLIP + DT_LEFT + DT_TOP + DT_SINGLELINE
        invoke DrawTextA, gdi_hDC, ADDR [esi].scope.label_4, -1, ebx, DT_NOCLIP + DT_LEFT + DT_BOTTOM + DT_SINGLELINE


    .ENDIF ;// connected


        jmp all_done




spectrum_mode:

    ;// show the mode

        lea ecx, sz_spectrum_on
        mov edx, (SIZEOF sz_spectrum_on) - 1
        .IF !([esi].dwUser & SCOPE_ON)
            lea ecx, sz_spectrum_off
            mov edx, (SIZEOF sz_spectrum_off) - 1
        .ENDIF

        invoke DrawTextA, gdi_hDC, ecx, edx, ebx, DT_NOCLIP + DT_RIGHT + DT_TOP + DT_SINGLELINE

    ;// don't do if nothing connected
    ;//OSC_TO_PIN_INDEX esi, ecx, PIN_Y1
    .IF [esi].pin_y1.pPin

        ;// see if we need to build any of the labels

        mov ebx, [esi].scope.dwFlags
        BITRJMP ebx, BUILD_LABEL_1, jnc @F

            ;// build the range label

            fld [esi].scope.value_1
            invoke unit_BuildString, ADDR [esi].scope.label_1, UNIT_VALUE, 0

        @@:
        BITRJMP ebx, BUILD_LABEL_3, jnc @F

            ;// build the frequencies

            fld [esi].scope.value_3
            invoke unit_BuildString, ADDR [esi].scope.label_3, UNIT_HERTZ, 0

        @@:
        BITRJMP ebx, BUILD_LABEL_4, jnc @F

            ;// build the frequencies

            fld [esi].scope.value_4
            invoke unit_BuildString, ADDR [esi].scope.label_4, UNIT_HERTZ, 0
        @@:

        mov [esi].scope.dwFlags, ebx

    ;// show the range label

        GDI_DC_SET_COLOR COLOR_GROUP_DISPLAYS+31
        mov ebx, esp    ;// reload the rect pointer

        invoke DrawTextA, gdi_hDC, ADDR [esi].scope.label_1, -1, ebx, DT_NOCLIP + DT_LEFT + DT_TOP + DT_SINGLELINE

    ;// show the frequency span

        invoke DrawTextA, gdi_hDC, ADDR [esi].scope.label_3, -1, ebx, DT_NOCLIP + DT_LEFT + DT_BOTTOM + DT_SINGLELINE
        invoke DrawTextA, gdi_hDC, ADDR [esi].scope.label_4, -1, ebx, DT_NOCLIP + DT_RIGHT + DT_BOTTOM + DT_SINGLELINE

    .ENDIF  ;// connected

    ;// that's it

        jmp all_done




sonograph_mode:


    ;// show the mode

        lea ecx, sz_sonograph_on
        mov edx, (SIZEOF sz_sonograph_on) - 1
        .IF !([esi].dwUser & SCOPE_ON)
            lea ecx, sz_sonograph_off
            mov edx, (SIZEOF sz_sonograph_off) - 1
        .ENDIF

        invoke DrawTextA, gdi_hDC, ecx, edx, ebx, DT_NOCLIP + DT_RIGHT + DT_TOP + DT_SINGLELINE

    ;// show the time span

        mov ecx, [esi].dwUser
        and ecx, SCOPE_RANGE3_TEST
        shr ecx, LOG2(SCOPE_RANGE3_1)-3
        lea ecx, sz_sono_span_label[ecx]
        invoke DrawTextA, gdi_hDC, ecx, -1, ebx, DT_NOCLIP + DT_RIGHT + DT_BOTTOM + DT_SINGLELINE

    ;// don't show anything else if not connected

        ;// OSC_TO_PIN_INDEX esi, ecx, PIN_Y1
        .IF [esi].pin_y1.pPin

        ;// see if any labels need invalidated

            mov ebx, [esi].scope.dwFlags
            BITRJMP ebx, BUILD_LABEL_1, jnc @F
                fld [esi].scope.value_1
                invoke unit_BuildString, ADDR [esi].scope.label_1, UNIT_HERTZ, 0
        @@: BITRJMP ebx, BUILD_LABEL_2, jnc @F
                fld [esi].scope.value_2
                invoke unit_BuildString, ADDR [esi].scope.label_2, UNIT_HERTZ, 0
        @@: mov [esi].scope.dwFlags, ebx

        ;// then draw the labels

            mov ebx, esp

            GDI_DC_SET_COLOR COLOR_GROUP_DISPLAYS+31

            invoke DrawTextA, gdi_hDC, ADDR [esi].scope.label_1, -1, ebx, DT_NOCLIP + DT_LEFT + DT_TOP + DT_SINGLELINE
            invoke DrawTextA, gdi_hDC, ADDR [esi].scope.label_2, -1, ebx, DT_NOCLIP + DT_LEFT + DT_BOTTOM + DT_SINGLELINE

        ;// and blit the legend

            push esi

            mov edi, [esi].pDest
            mov esi, DISPLAY_PALETTE_PSOURCE
            mov ebx, display_palette.shape.pMask
            add edi, sono_legend_shift
            invoke shape_Move

            pop esi

        .ENDIF


all_done:

    add esp, SIZEOF RECT

    ret


scope_render_labels ENDP











ASSUME_AND_ALIGN
scope_set_default_labels PROC

    ;// the task: set the float values that are needed to build text labels

    ASSUME esi:PTR OSCOPE_OSC_MAP

    mov ecx, [esi].dwUser
    BITTJMP ecx, SCOPE_SPECTRUM,    jc spectrum_mode
    BITTJMP ecx, SCOPE_SONOGRAPH,   jc sonograph_mode

oscope_mode:

    ;// oscope needs a default min max range

    mov eax, math_1
    mov edx, math_neg_1
    mov [esi].scope.value_1, eax
    mov [esi].scope.value_2, eax
    mov [esi].scope.value_3, edx
    mov [esi].scope.value_4, edx

    or [esi].scope.dwFlags, BUILD_LABEL_TEST
    jmp all_done

spectrum_mode:

    ;// need a default frequency spectrum and range
    ;// frequency range depends on the scale

        xor edx, edx
        and ecx, SCOPE_RANGE2_TEST
        shr ecx, LOG2(SCOPE_RANGE2_1)-2
        mov eax, spectrum_freq_offset[ecx]
        mov [esi].scope.value_3, edx
        mov [esi].scope.value_4, eax

    ;// default range of 1

        mov edx, math_1
        mov [esi].scope.value_1, edx

        or [esi].scope.dwFlags, BUILD_LABEL_1 + BUILD_LABEL_3 + BUILD_LABEL_4

    jmp all_done

sonograph_mode:

    ;// sonograph mode needs a default height
    ;// this depends on the mode

        xor edx, edx
        and ecx, SCOPE_RANGE4_TEST
        shr ecx, LOG2(SCOPE_RANGE4_1)-2
        mov eax, sono_freq_offset[ecx]
        mov [esi].scope.value_2, edx
        mov [esi].scope.value_1, eax

        or [esi].scope.dwFlags, BUILD_LABEL_1 + BUILD_LABEL_2


all_done:

    ret

scope_set_default_labels ENDP

;//
;//
;//     LABELS
;//
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////

























;////////////////////////////////////////////////////////////////////
;//
;//
;//     CTOR DTOR and SETSHAPE
;//

ASSUME_AND_ALIGN
scope_Ctor PROC

        ;// register call
        ASSUME ebp:PTR LIST_CONTEXT ;// preserve
        ASSUME esi:PTR OSC_OBJECT   ;// preserve
        ASSUME edi:PTR OSC_BASE     ;// may destroy
        ASSUME ebx:PTR FILE_OSC     ;// may destroy
        ASSUME edx:PTR FILE_HEADER  ;// may destroy

        .IF !edx    ;// make sure to set helpful settings on the scope
            mov [esi].dwUser, SCOPE_LABELS
        .ELSE   ;// are loading from file

            ;// account for old versions (pre 219)

            mov eax, [esi].dwUser
            test eax, SCOPE_UNIT_AUTO   ;// old version does not have this set
            .IF ZERO?

                mov edx, eax            ;// xfer old flags to edx
                shl edx, 1              ;// put new trigger bits into place
                and eax, NOT (SCOPE_TRIG_POS OR UNIT_AUTO_TRACE)    ;// remove old trigger bits
                and edx, SCOPE_TRIG_TEST;// remove extra bits from new flags
                or eax, edx             ;// merge old flags into new
                mov [esi].dwUser, eax   ;// save in object

            .ENDIF

        .ENDIF

        or [esi].dwUser, SCOPE_UNIT_AUTO    ;// always turn this on

    ;// that should do it

        ret

scope_Ctor ENDP




ASSUME_AND_ALIGN
scope_Dtor PROC

    ;// here we want to destroy our gdi stuff

    ASSUME esi:PTR OSC_OBJECT

    mov eax, [esi].pContainer
    .IF eax
        invoke dib_Free, eax
    .ENDIF

    ;// that's it

        ret

scope_Dtor ENDP


ASSUME_AND_ALIGN
scope_build_container PROC

    ASSUME esi:PTR OSC_OBJECT

    ;// make sure we have a dib allocated

    .IF ![esi].pContainer

        push ebx

        invoke dib_Reallocate, DIB_ALLOCATE_INTER, SCOPE_WIDTH, SCOPE_HEIGHT
        mov [esi].pContainer, eax
        mov ebx, eax

        mov edx, (GDI_CONTAINER PTR [ebx]).shape.pSource
        mov [esi].pSource, edx

        mov eax, F_COLOR_GROUP_DISPLAYS
        mov edx, F_COLOR_OSC_TEXT
        invoke dib_FillAndFrame

        pop ebx

    .ENDIF

    ;// make sure legend shift is defined

    .IF !sono_legend_shift

        mov edx, SCOPE_LABEL_HEIGHT*2 + SCOPE_LABEL_HEIGHT/2
        mov eax, gdi_bitmap_size.x
        mul edx
        add eax, 4
        mov sono_legend_shift, eax

    .ENDIF

    invoke scope_set_default_labels

    ret

scope_build_container ENDP



ASSUME_AND_ALIGN
scope_SetShape PROC

    ASSUME esi:PTR OSC_OBJECT

    ;// make sure we have a dib allocated

    .IF ![esi].pContainer

        invoke scope_build_container

    .ENDIF

    ;// and call sync pins

    invoke scope_sync_pins

    ;// then exit to set shape

    jmp osc_SetShape

scope_SetShape ENDP

;//
;//
;//     CTOR and DTOR SETSHAPE
;//
;////////////////////////////////////////////////////////////////////






;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;//
;//
;// helpers for the popup panel
;//
;//     esi muse be osc
;//     edi must be popup_hWnd
;//     ebx must be dwUser

    ASSUME esi:PTR OSC_OBJECT

    HIDE_WINDOW MACRO ID:req

        invoke GetDlgItem, edi, ID
        invoke ShowWindow, eax, SW_HIDE

        ENDM

scope_hide_oscilloscope PROC
    HIDE_WINDOW IDC_SCOPE_RANGE1_0
    HIDE_WINDOW IDC_SCOPE_RANGE1_1
    HIDE_WINDOW IDC_SCOPE_RANGE1_2
    HIDE_WINDOW IDC_SCOPE_RANGE1_3
    HIDE_WINDOW IDC_SCOPE_RANGE1_4
    HIDE_WINDOW IDC_SCOPE_RANGE1_5
    HIDE_WINDOW IDC_SCOPE_RANGE1_6
    HIDE_WINDOW IDC_SCOPE_RANGE1_7
    HIDE_WINDOW IDC_SCOPE_SWEEP
    HIDE_WINDOW IDC_SCOPE_SCROLL
    HIDE_WINDOW IDC_SCOPE_TRIGGER
    HIDE_WINDOW IDC_SCOPE_TRIGGER_NONE
    HIDE_WINDOW IDC_SCOPE_TRIGGER_POS
    HIDE_WINDOW IDC_SCOPE_TRIGGER_NEG
;// HIDE_WINDOW IDC_SCOPE_UNITS_VALUE
;// HIDE_WINDOW IDC_SCOPE_UNITS_HERTZ
;// HIDE_WINDOW IDC_SCOPE_UNITS_MIDI
;// HIDE_WINDOW IDC_SCOPE_UNITS
    ret
scope_hide_oscilloscope ENDP

scope_hide_spectrum     PROC
    HIDE_WINDOW IDC_SCOPE_RANGE2_0
    HIDE_WINDOW IDC_SCOPE_RANGE2_1
    HIDE_WINDOW IDC_SCOPE_RANGE2_2
    HIDE_WINDOW IDC_SCOPE_RANGE2_3
    HIDE_WINDOW IDC_SCOPE_WIDTH
    HIDE_WINDOW IDC_SCOPE_AVERAGE
    ret
scope_hide_spectrum     ENDP

scope_hide_sonograph    PROC
    HIDE_WINDOW     IDC_SCOPE_RANGE3_0
    HIDE_WINDOW     IDC_SCOPE_RANGE3_1
    HIDE_WINDOW     IDC_SCOPE_RANGE3_2
    HIDE_WINDOW     IDC_SCOPE_RANGE4_0
    HIDE_WINDOW     IDC_SCOPE_RANGE4_1
    HIDE_WINDOW     IDC_SCOPE_RANGE4_2
    HIDE_WINDOW     IDC_SCOPE_RATE
    HIDE_WINDOW     IDC_SCOPE_HEIGHT
    ret
scope_hide_sonograph    ENDP


scope_init_sonograph_popup PROC

    ;// set the sweep range correctly

    mov ecx, ebx
    and ecx, SCOPE_RANGE3_TEST
    DEBUG_IF <ecx!>SCOPE_RANGE3_2>  ;// supposed to be taken care of elsewhere
    shr ecx, LOG2(SCOPE_RANGE3_1)
    add ecx, IDC_SCOPE_RANGE3_0
    invoke CheckDlgButton, edi, ecx, BST_CHECKED

    ;// set the column range correctly

    mov ecx, ebx
    and ecx, SCOPE_RANGE4_TEST
    DEBUG_IF <ecx!>SCOPE_RANGE4_2>  ;// supposed to be taken care of elsewhere
    shr ecx, LOG2(SCOPE_RANGE4_1)
    add ecx, IDC_SCOPE_RANGE4_0
    invoke CheckDlgButton, edi, ecx, BST_CHECKED

    ;// that's it

    ret

scope_init_sonograph_popup ENDP


scope_init_oscilloscope_popup PROC

    ;// set the correct range button

    mov ecx, ebx
    and ecx, SCOPE_RANGE1_TEST
    push ecx    ;// store on stack for a while
    add ecx, IDC_SCOPE_RANGE1_0
    invoke CheckDlgButton, edi, ecx, BST_CHECKED

    ;// set the scroll button correctly

    pop ecx
    .IF ecx < SCOPE_RANGE1_4 || ecx > SCOPE_RANGE1_6
        DEBUG_IF <ebx & SCOPE_SCROLL>   ;// supposed to be taken care of elswhere
        invoke CheckDlgButton, edi, IDC_SCOPE_SCROLL, BST_UNCHECKED
        ENABLE_CONTROL edi, IDC_SCOPE_SCROLL, 0
    .ELSE
        ENABLE_CONTROL edi, IDC_SCOPE_SCROLL, 1
        .IF ebx & SCOPE_SCROLL
            invoke CheckDlgButton, edi, IDC_SCOPE_SCROLL, BST_CHECKED
        .ENDIF
    .ENDIF

    ;// set the trigger options

    mov ecx, ebx
    and ecx, SCOPE_RANGE1_TEST

    .IF ebx & SCOPE_SCROLL || ecx == SCOPE_RANGE1_7

        ENABLE_CONTROL edi, IDC_SCOPE_TRIGGER_NONE, 0
        ENABLE_CONTROL edi, IDC_SCOPE_TRIGGER_POS, 0
        ENABLE_CONTROL edi, IDC_SCOPE_TRIGGER_NEG, 0

    .ELSE

        ENABLE_CONTROL edi, IDC_SCOPE_TRIGGER_NONE, 1
        ENABLE_CONTROL edi, IDC_SCOPE_TRIGGER_POS, 1
        ENABLE_CONTROL edi, IDC_SCOPE_TRIGGER_NEG, 1

        mov ecx, ebx
        and ecx, SCOPE_TRIG_TEST
        shr ecx, LOG2(SCOPE_TRIG_POS)
        add ecx, IDC_SCOPE_TRIGGER_NONE
        invoke CheckDlgButton, edi, ecx, BST_CHECKED

    .ENDIF


    ;// that's it

    ret

scope_init_oscilloscope_popup ENDP



scope_init_spectrum_popup PROC

    ;// set the range correctly

    mov ecx, ebx
    and ecx, SCOPE_RANGE2_TEST
    DEBUG_IF <ecx!>SCOPE_RANGE2_3>  ;// supposed to be taken care of elsewhere
    shr ecx, LOG2(SCOPE_RANGE2_1)
    add ecx, IDC_SCOPE_RANGE2_0
    invoke CheckDlgButton, edi, ecx, BST_CHECKED

    ;// set the trace2 values correctly

    .IF ebx & SCOPE_AVERAGE
        invoke CheckDlgButton, edi, IDC_SCOPE_AVERAGE, BST_CHECKED
    .ENDIF

    ret

scope_init_spectrum_popup ENDP


    SHOW_WINDOW MACRO ID:req

        invoke GetDlgItem, edi, ID
        invoke ShowWindow, eax, SW_SHOW

        ENDM


scope_show_oscilloscope PROC

    SHOW_WINDOW IDC_SCOPE_RANGE1_0
    SHOW_WINDOW IDC_SCOPE_RANGE1_1
    SHOW_WINDOW IDC_SCOPE_RANGE1_2
    SHOW_WINDOW IDC_SCOPE_RANGE1_3
    SHOW_WINDOW IDC_SCOPE_RANGE1_4
    SHOW_WINDOW IDC_SCOPE_RANGE1_5
    SHOW_WINDOW IDC_SCOPE_RANGE1_6
    SHOW_WINDOW IDC_SCOPE_RANGE1_7
    SHOW_WINDOW IDC_SCOPE_SWEEP
    SHOW_WINDOW IDC_SCOPE_SCROLL
    SHOW_WINDOW IDC_SCOPE_TRIGGER
    SHOW_WINDOW IDC_SCOPE_TRIGGER_NONE
    SHOW_WINDOW IDC_SCOPE_TRIGGER_POS
    SHOW_WINDOW IDC_SCOPE_TRIGGER_NEG
;// SHOW_WINDOW IDC_SCOPE_UNITS_VALUE
;// SHOW_WINDOW IDC_SCOPE_UNITS_HERTZ
;// SHOW_WINDOW IDC_SCOPE_UNITS_MIDI
;// SHOW_WINDOW IDC_SCOPE_UNITS

    invoke scope_init_oscilloscope_popup

    ret

scope_show_oscilloscope ENDP

scope_show_spectrum     PROC

    SHOW_WINDOW IDC_SCOPE_RANGE2_0
    SHOW_WINDOW IDC_SCOPE_RANGE2_1
    SHOW_WINDOW IDC_SCOPE_RANGE2_2
    SHOW_WINDOW IDC_SCOPE_RANGE2_3
    SHOW_WINDOW IDC_SCOPE_WIDTH
    SHOW_WINDOW IDC_SCOPE_AVERAGE

    invoke scope_init_spectrum_popup

    ret

scope_show_spectrum     ENDP

scope_show_sonograph    PROC

    SHOW_WINDOW IDC_SCOPE_RANGE3_0
    SHOW_WINDOW IDC_SCOPE_RANGE3_1
    SHOW_WINDOW IDC_SCOPE_RANGE3_2
    SHOW_WINDOW IDC_SCOPE_RANGE4_0
    SHOW_WINDOW IDC_SCOPE_RANGE4_1
    SHOW_WINDOW IDC_SCOPE_RANGE4_2
    SHOW_WINDOW IDC_SCOPE_RATE
    SHOW_WINDOW IDC_SCOPE_HEIGHT

    invoke scope_init_sonograph_popup

    ret

scope_show_sonograph    ENDP


;//
;// helpers for the popup panel
;//
;//     esi muse be osc
;//     edi must be popup_hWnd
;//     ebx must be dwUser
;//
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;//
;//     POPUP HANDLERS
;//
;//

ASSUME_AND_ALIGN
scope_InitMenu PROC uses edi

    ASSUME esi:PTR OSC_OBJECT

    mov ebx, [esi].dwUser
    mov edi, popup_hWnd

    ;// set the two items common to all panels

    bt ebx, LOG2(SCOPE_ON)
    .IF CARRY?
        invoke CheckDlgButton, edi, IDC_SCOPE_ON, BST_CHECKED
    .ENDIF

    bt ebx, LOG2(SCOPE_LABELS)
    .IF CARRY?
        invoke CheckDlgButton, edi, IDC_SCOPE_LABELS, BST_CHECKED
    .ENDIF

    ;// determine which mode we're in
    bt ebx, LOG2(SCOPE_SPECTRUM)
    jc spectrum_mode
    bt ebx, LOG2(SCOPE_SONOGRAPH)
    jc sonograph_mode


oscope_mode:

        ;// IDC_SCOPE_OSCOPE    VK_O
        invoke CheckDlgButton, edi, IDC_SCOPE_OSCOPE, BST_CHECKED

        invoke scope_hide_spectrum
        invoke scope_hide_sonograph
        invoke scope_show_oscilloscope

        jmp all_done

spectrum_mode:

        ;// IDC_SCOPE_SPECTRUM  VK_S
        invoke CheckDlgButton, edi, IDC_SCOPE_SPECTRUM, BST_CHECKED

        invoke scope_hide_sonograph
        invoke scope_hide_oscilloscope
        invoke scope_show_spectrum

        jmp all_done

sonograph_mode:

        ;// IDC_SCOPE_SONOGRAPH VK_G
        invoke CheckDlgButton, edi, IDC_SCOPE_SONOGRAPH, BST_CHECKED

        invoke scope_hide_oscilloscope
        invoke scope_hide_spectrum
        invoke scope_show_sonograph


all_done:

    xor eax, eax    ;// return zero or bad things will happen

    ret

scope_InitMenu ENDP




ASSUME_AND_ALIGN
scope_Command PROC

    ASSUME esi:PTR OSC_OBJECT
    ;// eax has the command ID

;// take care of buttons we don't hide

    cmp eax, IDC_SCOPE_ON           ;// on off
    jnz @F

        xor [esi].dwUser, SCOPE_ON
        mov eax, POPUP_REDRAW_OBJECT
        ret

@@: cmp eax, IDC_SCOPE_LABELS       ;// labels
    jnz @F

        xor [esi].dwUser, SCOPE_LABELS
        jmp set_new_mode


@@: cmp eax, IDC_SCOPE_OSCOPE       ;// VK_O
    jnz @F

        and [esi].dwUser, NOT SCOPE_MODE_TEST
        jmp set_new_mode

@@: cmp eax, IDC_SCOPE_SPECTRUM     ;// VK_S
    jnz @F

        and [esi].dwUser, NOT SCOPE_MODE_TEST
        or [esi].dwUser, SCOPE_SPECTRUM

        jmp set_new_mode

@@: cmp eax, IDC_SCOPE_SONOGRAPH    ;// VK_G
    jnz @F

        and [esi].dwUser, NOT SCOPE_MODE_TEST
        or [esi].dwUser, SCOPE_SONOGRAPH



    set_new_mode:       ;// exit point when we need to resync

        invoke scope_sync_pins
        invoke scope_set_default_labels
        mov eax, POPUP_SET_DIRTY + POPUP_INITMENU + POPUP_REDRAW_OBJECT
        ret



;// then we parse the rest depending on what mode we're in

@@: mov edx, [esi].dwUser
    bt edx, LOG2(SCOPE_SPECTRUM)
    jnc @1


;//
;// SPECTRUM MODE
;//

    cmp eax, IDC_SCOPE_AVERAGE  ;// VK_A
    jnz @F

        and [esi].dwUser, NOT ( SCOPE_AVERAGE )
        invoke IsDlgButtonChecked, popup_hWnd, eax
        or eax, eax
        jz set_new_mode
        or [esi].dwUser, SCOPE_AVERAGE
        mov eax, POPUP_SET_DIRTY + POPUP_INITMENU
        ret


@@: cmp eax, IDC_SCOPE_RANGE2_0 ;//  1610   // in order
    jb osc_Command
    cmp eax, IDC_SCOPE_RANGE2_3 ;// 1613
    ja osc_Command

        sub eax, IDC_SCOPE_RANGE2_0
        shl eax, LOG2(SCOPE_RANGE2_1)
        and [esi].dwUser, NOT SCOPE_RANGE2_TEST
        or [esi].dwUser, eax

        invoke scope_sync_pins
        invoke scope_set_default_labels
        mov eax, POPUP_SET_DIRTY + POPUP_REDRAW_OBJECT
        ret



@1: bt edx, LOG2(SCOPE_SONOGRAPH)
    jnc @2

;//
;// SONOGRAPH MODE
;//

    cmp eax, IDC_SCOPE_RANGE3_0 ;// 1620    // in order
    jb osc_Command
    cmp eax, IDC_SCOPE_RANGE3_2 ;// 1622
    ja @F

    sub eax, IDC_SCOPE_RANGE3_0
    shl eax, LOG2(SCOPE_RANGE3_1)
    and [esi].dwUser, NOT SCOPE_RANGE3_TEST ;// SCOPE_RANGE3_MASK
    or [esi].dwUser, eax
    invoke scope_set_default_labels
    mov eax, POPUP_SET_DIRTY + POPUP_REDRAW_OBJECT
    ret

@@: cmp eax, IDC_SCOPE_RANGE4_0 ;// 1630    // in order
    jb osc_Command
    cmp eax, IDC_SCOPE_RANGE4_2 ;// 1632
    ja osc_Command

    sub eax, IDC_SCOPE_RANGE4_0
    shl eax, LOG2(SCOPE_RANGE4_1)
    and [esi].dwUser, NOT SCOPE_RANGE4_TEST
    or [esi].dwUser, eax

    invoke scope_sync_pins
    invoke scope_set_default_labels

    mov eax, POPUP_SET_DIRTY + POPUP_REDRAW_OBJECT
    ret

@2: ;// oscope mode

;//
;// OSCILLOSCOPE MODE
;//

    cmp eax, IDC_SCOPE_SCROLL ;//   VK_L
    jnz @F

        invoke IsDlgButtonChecked, popup_hWnd, eax
        .IF eax
            or [esi].dwUser, SCOPE_SCROLL
        .ELSE
            and [esi].dwUser, NOT( SCOPE_SCROLL )
        .ENDIF
        jmp set_new_mode
        ;//mov eax, POPUP_SET_DIRTY
        ;//ret

@@: cmp eax, IDC_SCOPE_RANGE1_0  ;// 1600   // in order
    jb osc_Command

    cmp eax, IDC_SCOPE_RANGE1_3  ;// 1604
    ja @F

        ;// between 0 and 3

        and [esi].dwUser, NOT (SCOPE_RANGE1_TEST + SCOPE_SCROLL)
        sub eax, IDC_SCOPE_RANGE1_0
        or [esi].dwUser, eax
        jmp set_new_mode


@@: cmp eax, IDC_SCOPE_RANGE1_7
    ja @F
    .IF !ZERO?  ;// beteen 4 and 6

        and [esi].dwUser, NOT (SCOPE_RANGE1_TEST)
        sub eax, IDC_SCOPE_RANGE1_0
        or [esi].dwUser, eax
        jmp set_new_mode

    .ENDIF  ;// idc_scope_range_7

    ;// X-Y mode

        and [esi].dwUser, NOT (SCOPE_RANGE1_TEST + SCOPE_SCROLL)
        sub eax, IDC_SCOPE_RANGE1_0
        or [esi].dwUser, eax
        jmp set_new_mode


@@: cmp eax, IDC_SCOPE_TRIGGER_NONE
    jb osc_Command  ;// @F
    cmp eax, IDC_SCOPE_TRIGGER_NEG
    ja osc_Command  ;// @F

        ;// got a trigger mode

        and [esi].dwUser, NOT SCOPE_TRIG_TEST
        sub eax, IDC_SCOPE_TRIGGER_NONE
        shl eax, LOG2(SCOPE_TRIG_POS)
        or [esi].dwUser, eax
        jmp set_new_mode


scope_Command ENDP



;//
;//     POPUP HANDLERS
;//
;//
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////





;////////////////////////////////////////////////////////////////////
;//
;//
;//     _LoadUndo
;//

ASSUME_AND_ALIGN
scope_LoadUndo PROC

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

        invoke scope_sync_pins
        invoke scope_set_default_labels

        ret

scope_LoadUndo ENDP

;//
;//
;//     _LoadUndo
;//
;////////////////////////////////////////////////////////////////////







;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;//
;//
;//     DATA RENDERING
;//

comment ~ /*

OVERVIEW

    getting data from the pin to the dib is broken up into four seperate stages
    these stages are not nessesarily performed in the stated order

    1)  Aquire:

        modes that need to store data from previous frames do so with an aquire operation
        this involves copying data from the pin to internal storage
        sometimes not all the data needs to be coppied

    2)  Process:

        the goal is to transform the data into the desired form
        this may involve FFT's and/or average/phase calculations

    3)  Convert:

        the goal here is to convert the data into the min/max/column format
        so it can be rendered
        this usually involves min/max scans and may include line calculations

    4)  Render:

        The goal is transfer the min/max data to the dib, where it can be blitted
        an optional scroll operation may also be applied


    Decoupling the render operation from the rest allows the scope_Calc function
    to perform steps 1,2 and 3 in any manner it chooses to,
    then the render operaton can be performed later and be certain that the data is current


*/ comment ~




;// these macros are useful enough

    C0_MIN MACRO reg:req
        EXITM <(SCOPE_MIN_MAX PTR [reg]).min>
        ENDM
    C0_MAX MACRO reg:req
        EXITM <(SCOPE_MIN_MAX PTR [reg]).max>
        ENDM
    C1_MIN MACRO reg:req
        EXITM <(SCOPE_MIN_MAX PTR [reg+SIZEOF SCOPE_MIN_MAX]).min>
        ENDM
    C1_MAX MACRO reg:req
        EXITM <(SCOPE_MIN_MAX PTR [reg+SIZEOF SCOPE_MIN_MAX]).max>
        ENDM







;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;//
;//                                                 these draw to the dib
;//     renderers called by render routines
;//



ASSUME_AND_ALIGN
draw_part_column PROC

    ASSUME ebx:PTR BYTE ;// top of column output ptr, presereved

    ;// al must have the single color to store
    ;// ecx must have start coord, destroyed
    ;// edx must have stop coord, destroyed

    DEBUG_IF <edx!>SCOPE_HEIGHT-1>  ;// can't have anything bigger

    shl edx, LOG2(SCOPE_WIDTH)  ;// convert end to line offset
    shl ecx, LOG2(SCOPE_WIDTH)  ;// convert start to line offset

@@: mov [ebx+ecx],al    ;// store the color
    add ecx, SCOPE_WIDTH;// increase offset
    cmp ecx, edx        ;// see if done
    ja @F
    mov [ebx+ecx],al    ;// store the color
    add ecx, SCOPE_WIDTH;// next row
    cmp ecx, edx        ;// see if done
    jbe @B

@@: ret

draw_part_column ENDP



ASSUME_AND_ALIGN
draw_these_lines PROC uses ebp

    ;// this routine draws the points in the passed list
    ;// each point is assumed to be drawn to the next
    ;// the very last dot may or may not be drawn

    ;// this is used by the x y mode on the scope

    ASSUME ebx:PTR GDI_CONTAINER
    ASSUME esi:PTR DWORD;// X coord source data
    ASSUME edi:PTR DWORD;// Y coord source data
    ;// al must be the color to draw with

    mov ebp, SCOPE_WIDTH-1  ;// number of lines to draw

    sub esp, 10h    ;// make some room

    mov ecx, [esi+ebp*4+4]  ;// X
    mov edx, [edi+ebp*4+4]  ;// Y
    mov [esp+08h], ecx      ;// x
    mov [esp+0Ch], edx      ;// y

    @@: mov edx, [esi+ebp*4];// X
        mov ecx, [edi+ebp*4];// Y
        mov [esp+00h], edx  ;// x
        mov [esp+04h], ecx  ;// y
        invoke dib_DrawLine
        dec ebp
        jz @F

        mov edx, [esi+ebp*4];// X
        mov ecx, [edi+ebp*4];// Y
        mov [esp+08h], edx  ;// x
        mov [esp+0Ch], ecx  ;// y
        invoke dib_DrawLine
        dec ebp

        jmp @B

    @@: add esp, 10h

    ret

draw_these_lines ENDP

;//
;//
;//     renderers called by render routines
;//
;////////////////////////////////////////////////////////////////////






;////////////////////////////////////////////////////////////////////
;//
;//                         destroys esi
;//     connecting routine
;//

ASSUME_AND_ALIGN
connect_min_max PROC

    ;// this function will adjust the max/min values
    ;// by connecting them
    ;// always start with the previous value

    ASSUME edi:PTR SCOPE_MIN_MAX    ;// pointer to min/max values (iterated)
    ;// ecx must enter as start N0-1
    ;// edx must enter as end N1-1

    DEBUG_IF< edx !< ecx >  ;// varify that this is ever hit
                            ;// if so, use code below

    comment ~ /*

        int 3   ;// varify that this is ever hit

        push edx
        mov ecx, edx
        mov edx, SCOPE_WIDTH

        invoke connect_min_max

        pop edx
        xor ecx, ecx
        sub edi, SCOPE_WIDTH*4

    .ENDIF
    */ comment ~

    ;// determine esi

    mov esi, edx
    sub esi, ecx
    DEBUG_IF <ZERO?>    ;// ecx == edx

    ;// sub esi, 2  ;// never do the very last point, the data doesn't exists

;// min1 max1 are the current point
;// min2 max2 are the next point

;// determine if there is a gap between the two sucessive points
;// if so, adjust min/max to be the mid-point between the two

top_of_loop:

;// gap tests

    ;// max1 < min2
    mov edx, [edi+4].min;// min2
    mov ecx, [edi].max  ;// max1
    cmp ecx, edx
    jb  max1_min2

    ;// max2 < min1
;//@@:  ABOX232 why was this here ?
    mov edx, [edi].min  ;// min1
    mov ecx, [edi+4].max;// max2
    cmp ecx, edx
    jb max2_min1

iterate_loop:   ;// fallthrough is skip the point

    add edi, 4
    dec esi
    jnz top_of_loop

    ret

ALIGN 16
max1_min2:  ;// ecx = max1
            ;// edx = min2
    lea eax, [ecx+edx]  ;// add the two
    shr eax, 1          ;// divide by two to get midpoint
    .IF eax != ecx      ;// see if already correct
        DEBUG_IF <eax !> SCOPE_HEIGHT >
        mov [edi].max, eax  ;// set new max1
    .ENDIF
    cmp eax, edx        ;// see if already correct
    je iterate_loop     ;// jump if ok

    DEBUG_IF <eax !> SCOPE_HEIGHT >

    mov [edi+4].min, eax;// store new min2
    jmp iterate_loop

ALIGN 16
max2_min1:  ;// ecx = max2
            ;// edx = min1
    lea eax, [ecx+edx]  ;// add the two
    shr eax, 1          ;// divide by two to get midpoint
    .IF eax != ecx      ;// see if already correct
        DEBUG_IF <eax !> SCOPE_HEIGHT >
        mov [edi+4].max, eax;// set new max2
    .ENDIF

    inc eax
    cmp eax, edx        ;// see if already correct
    je iterate_loop     ;// jump if ok
    DEBUG_IF <eax !> SCOPE_HEIGHT >
    mov [edi].min, eax  ;// store new min1
    jmp iterate_loop

connect_min_max ENDP

;//
;//     connecting routine
;//
;//
;////////////////////////////////////////////////////////////////////




;////////////////////////////////////////////////////////////////////
;//
;//
;//     render routines
;//

comment ~ /*

draw_min_max_dual


;// states: 11, assuming that head, tail and center clearing are taken care of as required
;//
;// case    state                   from top to bottom
;// ------  -------------------     -----------------
;// case 0  min1 max1<min2 max2     0   1   0   2   0
;// case 1  min2 max2<min1 max1     0   2   0   1   0
;//
;// case 2  min1<min2<=max1<max2    0   1   3   2   0
;// case 3  min2<min1<=max2<max1    0   2   3   1   0
;//
;// case 4  min1<min2<=max2<max1    0   1   3   1   0
;// case 5  min2<min1<=max1<max2    0   2   3   2   0
;//
;// case 6  min1=min2 max1=max2     0   3   0
;//
;// case 7  min1=min2<=max2<max1    0   3   1   0
;// case 8  min1=min2<=max1<max2    0   3   2   0
;// case 9  min1<min2<=max1=max2    0   1   3   0
;// case 10 min2<min1<=max1=max2    0   2   3   0


*/ comment ~


ASSUME_AND_ALIGN
draw_min_max_dual PROC

    ;// this draws the overlapped columns
    ;// since we should already be erased, we don't bother to do it here

    ;// edi must point at the first min max record      (iterated)
    ;// esi must be the number of columns to draw       (iterated by decrementing)
    ;// ebx must be the top of the first column to draw (iterated by columns)

    ;// the reason for this function is that we want to overlapped as a third color

    ;// we have ecx and edx to play with

    .REPEAT

    ;// compare min1 and min2

        mov ecx, C0_MIN(edi);// min1
        mov edx, C1_MIN(edi)    ;// min2
        cmp ecx, edx
        ja case_135A
        je case_678

    case_2490:  ;// min1 < min2

        ;// case 2  min1<min2<=max1<max2    0   1   3   2   0
        ;// case 4  min1<min2<=max2<max1    0   1   3   1   0
        ;// case 9  min1<min2<=max1=max2    0   1   3   0
        ;// case 0  min1 max1<min2 max2     0   1   0   2   0

        ;// compare max1 and min 2

            mov ecx, C0_MAX(edi)    ;// max1
            mov edx, C1_MIN(edi)    ;// min2
            cmp ecx, edx
            jae case_249

        ;// case 0  max1<min2 max2      0   1   0   2   0
        case_0: ;// max1 < min2

            ;// draw color 1, min1 to max1

                mov edx, ecx            ;// max1
                mov ecx, C0_MIN(edi)    ;// min1
                mov al, COLOR_GROUP_DISPLAYS + 31
                call draw_part_column

            ;// draw color 2 min2 to max2

                mov ecx, C1_MIN(edi)    ;// min2
                mov edx, C1_MAX(edi)    ;// max2
                mov al, COLOR_GROUP_DISPLAYS + 23
                call draw_part_column

            jmp next_column ;// goto end state 2

        ALIGN 16
        case_249:   ;// min2 <= max1 .

            ;// case 2  min1<min2<=max1<max2    0   1   3   2   0
            ;// case 4  min1<min2<=max2<max1    0   1   3   1   0
            ;// case 9  min1<min2<=max1=max2    0   1   3   0

            ;// draw color 1, min1 to min2-1

                mov ecx, C0_MIN(edi)    ;// min1
                dec edx             ;// min2-1
                mov al, COLOR_GROUP_DISPLAYS + 31
                call draw_part_column

            ;// compare max1 and max2

                mov ecx, C0_MAX(edi)    ;// max1
                mov edx, C1_MAX(edi)    ;// max2
                cmp ecx, edx
                ja case_4
                jz case_9

            ;// case 2  min1<min2<=max1<max2    0   1   3   2   0
            case_2: ;// max1 < max2 ?

                ;// draw color 3 min2 to max1

                    mov edx, ecx        ;// max1
                    mov ecx, C1_MIN(edi)    ;// min2
                    mov al, COLOR_GROUP_DISPLAYS + 31
                    call draw_part_column

                ;// draw color 2 max1+1 to max2

                    mov ecx, C0_MAX(edi)    ;// max1
                    mov edx, C1_MAX(edi)    ;// max2
                    inc ecx
                    mov al, COLOR_GROUP_DISPLAYS + 23
                    call draw_part_column

                jmp next_column ;// goto end state 2

            ALIGN 16
            ;// case 9  min1<min2<=max1=max2    0   1   3   0
            case_9: ;// max1 = max2 ?

                ;//draw color 3 min2 to max1

                    mov edx, ecx        ;// max1
                    mov ecx, C1_MIN(edi)    ;// min2
                    mov al, COLOR_GROUP_DISPLAYS + 15
                    call draw_part_column

                jmp next_column ;//goto end state 1

            ALIGN 16
            ;// case 4  min1<min2<=max2<max1    0   1   3   1   0
            case_4: ;// max2 < max1 .

                ;// draw color 3 min2 to max2

                    mov ecx, C1_MIN(edi)    ;// min2
                    ;// mov edx, C1_MAX(edi)    ;// max2
                    mov al, COLOR_GROUP_DISPLAYS + 15
                    call draw_part_column

                ;// draw color 1 from max2+1 to max1

                    mov ecx, C1_MAX(edi)    ;// max2
                    mov edx, C0_MAX(edi)    ;// max1
                    inc ecx
                    mov al, COLOR_GROUP_DISPLAYS + 31
                    call draw_part_column

                jmp next_column ;// goto end state 1

    ALIGN 16
    case_678:   ;// min1 = min2

        ;// case 6  min1=min2<=max1=max2    0   3   0
        ;// case 7  min1=min2<=max2<max1    0   3   1   0
        ;// case 8  min1=min2<=max1<max2    0   3   2   0

        ;// compare max1 and max2

            mov ecx, C0_MAX(edi)    ;// max1
            mov edx, C1_MAX(edi)    ;// max2
            cmp ecx, edx
            ja case_7
            je case_6

        ;// case 8  min1=min2<=max1<max2    0   3   2   0
        case_8: ;//     max1 < max2 ?

            ;// draw color 3, min1 to max1

                mov edx, ecx
                mov ecx, C0_MIN(edi)    ;// min1
                mov al, COLOR_GROUP_DISPLAYS + 15
                call draw_part_column

            ;// draw color 2, max1+1 to max2

                mov ecx, C0_MAX(edi)    ;// max1
                mov edx, C1_MAX(edi)    ;// max2
                inc ecx
                mov al, COLOR_GROUP_DISPLAYS + 23
                call draw_part_column

            jmp next_column ;// goto end state 2

        ALIGN 16
        ;// case 6  min1=min2<=max1=max2    0   3   0
        case_6: ;//     max1 = max2 ?

            ;// draw color 3, min1 to max1

                mov edx, ecx            ;// max1
                mov ecx, C0_MIN(edi)    ;// min1
                mov al, COLOR_GROUP_DISPLAYS + 15
                call draw_part_column

            jmp next_column ;// goto end state 1

        ALIGN 16
        ;// case 7  min1=min2<=max2<max1    0   3   1   0
        case_7: ;// max2 < max1 .

            ;// draw color 3, min1 to max2

                mov ecx, C0_MIN(edi)    ;// min1
                ;// mov edx, C1_MAX(edi)    ;// max2
                mov al, COLOR_GROUP_DISPLAYS + 15
                call draw_part_column

            ;// draw color 1, max2+1 to max1
                mov ecx, C1_MAX(edi)    ;// max2
                mov edx, C0_MAX(edi)    ;// max1
                inc ecx
                mov al, COLOR_GROUP_DISPLAYS + 31
                call draw_part_column

            jmp next_column ;// goto end state 1

    ALIGN 16
    case_135A:  ;// min2 < min1 .

        ;// case 1  min2 max2<min1 max1     0   2   0   1   0
        ;// case A  min2<min1<=max1=max2    0   2   3   0
        ;// case 5  min2<min1<=max1<max2    0   2   3   2   0
        ;// case 3  min2<min1<=max2<max1    0   2   3   1   0

        ;// compare max2 and min1

            mov ecx, C1_MAX(edi)    ;// max2
            mov edx, C0_MIN(edi)    ;// min1
            cmp ecx, edx
            jae case_35A

        ;// case 1  min2 max2<min1 max1     0   2   0   1   0
        case_1: ;// max2 < min1 ?

            ;// draw color 2 from min2 to max2

                mov edx, ecx        ;// max2
                mov ecx, C1_MIN(edi)    ;// min2
                mov al, COLOR_GROUP_DISPLAYS + 23
                call draw_part_column

            ;// draw color 1 from min1 to max1

                mov ecx, C0_MIN(edi)    ;// min1
                mov edx, C0_MAX(edi)    ;// max1
                mov al, COLOR_GROUP_DISPLAYS + 31
                call draw_part_column

            jmp next_column ;// goto end state 1

        ALIGN 16
        case_35A:   ;// min1 <= max2 .

            ;// case 10 min2<min1<=max1=max2    0   2   3   0
            ;// case 5  min2<min1<=max1<max2    0   2   3   2   0
            ;// case 3  min2<min1<=max2<max1    0   2   3   1   0

            ;// draw color 2 from min2 to max1-1

            mov edx, C0_MAX(edi)    ;// max1
            mov ecx, C1_MIN(edi)    ;// min2
            dec edx
            .IF !SIGN?  ;// hey, some day figure out why i added this ??
            mov al, COLOR_GROUP_DISPLAYS + 23
            call draw_part_column
            .ENDIF

        ;// compare max2 and max1

            mov ecx, C1_MAX(edi)    ;// max2
            mov edx, C0_MAX(edi)    ;// max1
            cmp ecx, edx
            ja case_5
            je case_A

        ;// case 3  min2<min1<=max2<max1    0   2   3   1   0
        case_3: ;// max2 < max1 ?

            ;// draw color 3 from min1 to max2

                mov edx, ecx        ;// max2
                mov ecx, C0_MIN(edi)    ;// min1
                mov al, COLOR_GROUP_DISPLAYS + 15
                call draw_part_column

            ;// draw color 1 from max2+1 to max1

                mov ecx, C1_MAX(edi)    ;// max2
                mov edx, C0_MAX(edi)    ;// max1
                inc ecx
                mov al, COLOR_GROUP_DISPLAYS + 31
                call draw_part_column

            jmp next_column ;// goto end state 1


        ALIGN 16
        ;// case A  min2<min1<=max1=max2    0   2   3   0
        case_A: ;// max2 = max1 ?

            ;// draw color 3 from min1 to max1

                mov ecx, C0_MIN(edi)    ;// min1
                ;// mov edx, C0_MAX(edi)    ;// max1
                mov al, COLOR_GROUP_DISPLAYS + 15
                call draw_part_column

            jmp next_column ;// goto end state 1

        ALIGN 16
        ;// case 5  min2<min1<=max1<max2    0   2   3   2   0
        case_5: ;// max1 < max2 .

            ;// draw color 3 from min1 to max1

                mov ecx, C0_MIN(edi)    ;// min1
                ;// mov edx, C0_MAX(edi)    ;// max1
                mov al, COLOR_GROUP_DISPLAYS + 15
                call draw_part_column

            ;// draw color 2 from max1+1 to max2

                mov ecx, C0_MAX(edi)    ;// max1
                mov edx, C1_MAX(edi)    ;// max2
                inc ecx
                mov al, COLOR_GROUP_DISPLAYS + 23
                call draw_part_column

            jmp next_column         ;// goto end state 2

    ALIGN 16
    ;// next column
    next_column:

        add edi, 4  ;// iterate source data 1
        inc ebx     ;// iterate destination column
        dec esi     ;// decrease the lines count

    .UNTIL ZERO?

    ret

draw_min_max_dual ENDP








ASSUME_AND_ALIGN
scope_dib_shift PROC uses esi edi

    ;// this shifts the dib for scoll display

    ASSUME esi:PTR OSCOPE_OSC_MAP   ;// presereved

    OSC_TO_CONTAINER esi, ebx
    xor eax, eax
    mov edx, [esi].scope.dib_shift  ;// get amount to shift (bytes)
    DEBUG_IF <!!edx>                ;// don't call if not nessesary
    mov ecx, [ebx].shape.dword_size ;// load the dword_size of the dib
    mov [esi].scope.dib_shift, eax  ;// reset
    mov edi, [esi].pSource          ;// get destination
    lea esi, [edi+edx]              ;// set the source

    neg edx                 ;// flip for next command
    lea ecx, [ecx*4+edx]    ;// convert to a byte size (subtract the bytes we don't copy)
    rep movsb               ;// shift the image

    ret

scope_dib_shift ENDP

;//
;//
;//     render routines
;//
;////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////
;//
;//                             called from render
;//     connect the dots        destroys edi
;//
ASSUME_AND_ALIGN
connect_the_dots PROC   ;// edx should be scope dword flags

    push esi
    ASSUME esi:PTR OSCOPE_OSC_MAP   ;// presereved

    .IF edx & C0_INVALID

        mov ecx, [esi].scope.N0 ;// get start
        xor eax, eax        ;// clear for adding carry
        mov edx, [esi].scope.N1 ;// get end
        sub ecx, 1          ;// decrease start (and trap ==ed zero in carry flag)
        adc ecx, eax        ;// increase again if ==zero
        sub edx, 1          ;// decrease end
        adc edx, eax        ;// and trap zero
        .IF ecx != edx      ;// if they're not equal
            lea edi, [esi].scope.C0[ecx*4]  ;// load the first min/max record
            ;// ADDED ABOX232 somewhere we are not doing this correctly ....
            ASSUME edi:PTR SCOPE_MIN_MAX
            .IF [edi].min > SCOPE_HEIGHT || [edi].max > SCOPE_HEIGHT
                and [esi].scope.dwFlags, NOT C0_INVALID
            .ELSE
                invoke connect_min_max  ;// call the connect function
                mov esi, [esp]          ;// retrieve esi
            .ENDIF
        .ENDIF
        mov edx, [esi].scope.dwFlags    ;// load the flags as well

    .ENDIF

    .IF edx & C1_INVALID

        mov ecx, [esi].scope.N0
        xor eax, eax
        mov edx, [esi].scope.N1
        sub ecx, 1
        adc ecx, eax
        sub edx, 1
        adc edx, eax
        .IF ecx != edx
            lea edi, [esi].scope.C1[ecx*4]
            ;// ADDED ABOX232 somewhere we are not doing this correctly ....
            ASSUME edi:PTR SCOPE_MIN_MAX
            .IF [edi].min > SCOPE_HEIGHT || [edi].max > SCOPE_HEIGHT
                and [esi].scope.dwFlags, NOT C1_INVALID
            .ELSE
                invoke connect_min_max
                mov esi, [esp]          ;// retrieve esi
            .ENDIF
        .ENDIF
        mov edx, [esi].scope.dwFlags    ;// load the flags as well

    .ENDIF

    pop esi

    ret

connect_the_dots ENDP







ASSUME_AND_ALIGN
render_min_max PROC USES esi    ;// destroys edi

    ;// this will render a set of min max records
    ;// we assume they're already connected

    ASSUME esi:PTR OSCOPE_OSC_MAP

    ;// erase what was there

        mov eax, F_COLOR_GROUP_DISPLAYS
        mov ebx, [esi].pContainer
        mov ecx, [esi].scope.N1
        mov edx, [esi].scope.N0
        sub ecx, edx
        jbe all_done ;// DEBUG_IF <ZERO?>
        invoke dib_FillColumn

    ;// set up for the column scan

        mov edx, [esi].scope.dwFlags    ;// load the flags
        mov ebx, [esi].pSource  ;// load dib source
        mov ecx, [esi].scope.N0 ;// load start column
        and [esi].scope.dwFlags, NOT (C0_INVALID + C1_INVALID)  ;// reset the invalid flags
        add ebx, ecx            ;// set ebx as start column
        and edx, C0_INVALID + C1_INVALID

    ;// determine if dual or single mode

    .IF edx == (C0_INVALID OR C1_INVALID)

        ;// DUAL MODE
        lea edi, [esi].scope.C0[ecx*4]  ;// load ptr to trace 1 min/max data
        mov esi, [esi].scope.N1 ;// load dest column
        ASSUME esi:NOTHING
        sub esi, ecx        ;// now esi is a column count
        call draw_min_max_dual

    .ELSE   ;// SINGLE MODE

        ASSUME esi:PTR OSCOPE_OSC_MAP

        xor eax, eax

        ;// determine which channel

        .IF edx == C0_INVALID   ;// c0 only
            mov al, COLOR_GROUP_DISPLAYS + 31
            lea edi, [esi].scope.C0[ecx*4]
        .ELSE                   ;// C1 only
            mov al, COLOR_GROUP_DISPLAYS + 23
            lea edi, [esi].scope.C1[ecx*4]
        .ENDIF

        mov esi, [esi].scope.N1 ;// load dest column
        ASSUME esi:NOTHING
        sub esi, ecx        ;// now esi is a column count

        ;// render all the columns

        .REPEAT

        ;// get the min and max

            mov ecx, C0_MIN(edi)
            mov edx, C0_MAX(edi)
            shl ecx, LOG2(SCOPE_WIDTH)  ;// convert start to line offset
            shl edx, LOG2(SCOPE_WIDTH)  ;// convert end to line offset

        ;// fill the column

        @@: mov [ebx+ecx],al    ;// store the color
            add ecx, SCOPE_WIDTH;// increase offset
            cmp ecx, edx        ;// see if done
            ja @F
            mov [ebx+ecx],al    ;// store the color
            add ecx, SCOPE_WIDTH;// next row
            cmp ecx, edx        ;// see if done
            ja @F
            mov [ebx+ecx],al    ;// store the color
            add ecx, SCOPE_WIDTH;// next row
            cmp ecx, edx        ;// see if done
            jbe @B
        @@:

        ;// iterate to next column

            inc ebx
            add edi, 4
            dec esi

        .UNTIL ZERO?

    .ENDIF

all_done:

    ret


render_min_max ENDP

























;////////////////////////////////////////////////////////////////////
;//
;//
;//     s c o p e _ R e n d e r
;//
;// there are two versions
;//
;//     scope_Render
;//         called from gui thread
;//         calls osc render, then draws the labels
;//     scope_Render_calc
;//         called from play thread
;//         renders the traces and updates the positions
;//

comment ~ /*

    modes to account for

    oscope mode

        internal sweep: draw the lines between min max for bothe channels bewteen n0 and n1
        externel sweep: erase the points at min
                        draw points at max, xfer them to min

    spectrum mode

        draw the points for min max for channel 1 and 2

    sonogrpah

        assume data is correct as it stands

*/ comment ~


ASSUME_AND_ALIGN
scope_Render_calc PROC

        ASSUME esi:PTR OSCOPE_OSC_MAP

    ;// see ifthere's anything to do
    ;// make sure one of the channels is invalid

        mov edx,[esi].scope.dwFlags
        ANDJMP edx, C0_INVALID + C1_INVALID, jz all_done_now
        ;// edx is assumed to be the inavlidate flags

    ;// store registers

        push edi
        push esi

    ;// get dword user from the object

        mov ecx, [esi].dwUser

    ;// stack looks like this
    ;// esi     edi     ret


    ;// make sure we have a container

        .IF ![esi].pContainer
            invoke scope_build_container
            mov ecx, [esi].dwUser
            mov edx,[esi].scope.dwFlags
        .ENDIF


    ;// determine our mode

        BITTJMP ecx, SCOPE_SONOGRAPH,   jc render_sonograph
        BITTJMP ecx, SCOPE_SPECTRUM,    jc render_oscope_and_spectrum   ;// use same routine

;////////////////////////////////////////////////////////////////////
;//
;//                         shared by spectrum
;//     render oscope
;//

render_oscope:

    and ecx, SCOPE_RANGE1_TEST  ;// strip out extra to get the sweep rate
    cmp ecx, SCOPE_RANGE1_7     ;// external sweep ?
    je render_oscope_external   ;// do that

render_oscope_internal:         ;// internal sweep

    ;// see if we're supposed to shift

        .IF [esi].scope.dib_shift
            push edx
            push ecx
            call scope_dib_shift
            pop ecx
            pop edx
        .ENDIF

    ;// call connect the dots for the available channels

render_oscope_and_spectrum:

        invoke connect_the_dots

    ;// do the appropriate min max render routine

        invoke render_min_max

        pop esi ;// retrieve the osc

    ;// this is where we determine how to blit from what we just drew
    ;// to the gdi display surface
    ;// if we're being called from play_Render
    ;// then we only want to blit the invalid part (N0 to N1)


    ;// always update N0 by setting it equal to N1

        mov eax, [esi].scope.N1 ;// get N1
        mov [esi].scope.N0, eax ;// update N0

        pop edi ;// retrieve previous edi    ( nessesary ? )

        jmp all_done_now





ALIGN 16
render_oscope_external:

    ;// determine which chanels to render
    ;// scan through all 1024 points of data

    ;// esi = osc
    ;// edi = osc.scope
    ;// ecx = osc.dwUser
    ;// edx = scope.dwFlags (already tested for at least one invalid)

    mov ebx, [esi].pContainer
    mov eax, F_COLOR_GROUP_DISPLAYS
    invoke dib_Fill


    .IF edx & C0_INVALID

        and [esi].scope.dwFlags, NOT C0_INVALID

        lea edi, [esi].scope.Y0
        lea esi, [esi].scope.C0
        mov al, COLOR_GROUP_DISPLAYS+31
        invoke  draw_these_lines
        mov esi, [esp]
        ;//mov edi, [esi].pData ;// retrieve the data pointer
        mov edx, [esi].scope.dwFlags

    .ENDIF

    .IF edx & C1_INVALID

        and [esi].scope.dwFlags, NOT C1_INVALID

        lea edi, [esi].scope.Y1
        lea esi, [esi].scope.C0
        mov al, COLOR_GROUP_DISPLAYS+23
        invoke draw_these_lines

    .ENDIF

    pop esi
    pop edi

    jmp all_done_now

;//
;//
;//     render oscope
;//
;////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////
;//
;//
;//     render songraph
;//

ALIGN 16
render_sonograph:   ;// no need to do anything

;//
;//
;//     render songraph
;//
;////////////////////////////////////////////////////////////////////



all_done_now:

    ret


scope_Render_calc ENDP




ASSUME_AND_ALIGN
scope_Render PROC

    invoke gdi_render_osc

    ASSUME esi:PTR OSC_OBJECT

    .IF [esi].dwUser & SCOPE_LABELS

        invoke scope_render_labels

    .ENDIF

    ret

scope_Render ENDP








;////////////////////////////////////////////////////////////////////
;//
;//
;//     scope_PrePlay
;//

ASSUME_AND_ALIGN
scope_PrePlay PROC

    ASSUME esi:PTR OSCOPE_OSC_MAP

    xor eax, eax

    mov [esi].pin_x.dwUser, eax ;// clear the last scope trigger

    ;// erase all internal tables

    OSC_TO_DATA esi, edi, DWORD
    mov ecx, (OFFSET OSCOPE.value_1) / 4
    rep stosd

    inc eax ;// return true or bad things happen

    ret

scope_PrePlay ENDP

;//
;//
;//     scope_PrePlay
;//
;////////////////////////////////////////////////////////////////////










;////////////////////////////////////////////////////////////////////
;//
;//
;//     AQUIRE AND CONVERT ROUTINES     all used by calc
;//

comment ~ /*

    X0,X1   input data for the CURRENT FRAME
    Z0,Z1   global tempory storage, do not store anything ACROSS a frame
    Y0,Y1   private storage for the object
    N0,N1   min/max arrays for each trace

----------------------------------------------------------------------------------------

SPECTRUM MODE

    to take advantage of the dual fft
    the spectrum mode stores previous frame data and performs the FFT every second frame
    this requires flipping between two operations, A and B
    since there is no scroll mode, we use N as the A/B value

    the spectrum calc always assumes:

        X0              Z0  Z1      Y0          Y1          N0      N1
        ------------    --------    -----       ---------   -----   ---------
        input data      temp        spec/data   ave/phase   spec    ave/phase

    STAGE A

        input data                  spec(t-1)   ave/phase   spec    ave/phase

        <convert>   spec_Convert(Y0)
        <aquire>    copy X0 to Y0

        input data                  data(t)     ave/phase   spec    ave/phase


    STAGE B

        input data      temp        data(t-1)   ave/phase   spec    ave/phase

        <process>   dual fft X0 to Y0, Y0 to Z0

        input data      spec(t-1)   spec(t)     ave/phase   spec    ave/phase

        <convert>   spec_Convert(Z0)


    spec_convert may require that lines be generated
    model is:   trace1 one uses a fill model (min,max)
                trace2 uses an average model (one pixel)
    convert also takes into account the r1 and o1 values


----------------------------------------------------------------------------------------

SONOGRAPH MODE

    assumes that data is:

        X0              Z0      Z1      Y0          Y1          N0  N1
        ------------    --------------  ---------   ---------   --------
        input data      temp            data(t-1)   data(t)     not used

    there are three version of the aquire/process/convert operation
    these depend on the rate setting

    RANGE3_0:   4 columns per frame

        X0              Z0      Z1      Y0          Y1          N0  N1
        ------------    --------------  ---------   ---------   --------
        input data      temp            data(t-1)   data(t)     not used

        <aquire>    copy_frame X0 to Y1
        <process>   fft Y0[1/4] to Z0, Y0[1/2] to Z1
        <convert>   sono_convert Z0 to N+0, Z1 to N+1
        <process>   fft Y0[3/4] to Z0, Y1[0] to Z1
        <convert>   sono_convert Z0 to N+2, Z1 to N+3

        <aquire>    copy_frame Y1[1/4] to Y0[1/4]


    RANGE3_1:   2 columns per frame

        X0              Z0      Z1      Y0          Y1          N0  N1
        ------------    --------------  ---------   ---------   --------
        input data      temp            data(t-1)   data(t)     not used

        <aquire>    copy_frame X0 to Y1
        <process>   fft Y0[1/2] to Z0, Y1[0] to Z1
        <convert>   sono_convert Z0 to N+0, Z1 to N+1

        <aquire>    copy_frame Y1[1/2] to Y0[1/2]


    RANGE3_2:   1 colum per frame
                this is the same as the spectrum analyzer

        X0              Z0      Z1      Y0          Y1          N0  N1
        ------------    --------------  ---------   ---------   --------
        input data      temp            spec(t-1)   data(t)     not used

    STAGE A:

        <convert>   sono_Convert(Y0)
        <aquire>    copy X0 to Y0

    STAGE B

        <process>   dual fft X0 to Y0, Y0 to Z0
        <convert>   sono_Convert(Z0)

    convert does the rendering in this mode
    there are three flavours depending on the vertical scale

        RANGE4_0:   128 CONSECUTIVE points, offset by o1
                    simply determine the color, based on magnitude
                    and send to dib at desired column

        RANGE4_1:   128 PAIRS of points, offset by o1
                    determine the largest magnitude for the pair
                    and send to dib at desired column

        RANGE4_2:   128 QUADS of points, no offset
                    determine the largest of the 4
                    send that color to the screen


----------------------------------------------------------------------------------------

OSCILLOSCOPE MODE

    oscope does not need to store data
    instead it's concern is updating N correctly
    and generating the correct column information

    there are also requirements to generate lines beween points
    -- dev note: for now, skip the line routine --

    sweep modes:

        RANGE1_0 simply draws the dots, that's enough
        RANGE1_1 through RANGE1_6 must do a min/max scan of the input frame
            there are functions to do this
        RANGE1_7 external mode uses Y0 and Y1 as a list of points to draw
            this may need to be redone later, as the points are not connected

----------------------------------------------------------------------------------------

*/ comment ~


.DATA

    default_min REAL4 1.0e+18   ;// big big number
    default_max REAL4 -1.0e+18  ;// big big number

.CODE



;////////////////////////////////////////////////////////////////////
;//
;//     aquire routines for oscope mode
;//
;//
ASSUME_AND_ALIGN
scope_fill_scan PROC

;// use this for RANGE1_1 through RANGE1_4
;// it's purpose is to do the min/max scan
;// call this once per chanel per frame

    ;// assume  ebx has outer count         destroyed
    ;//         esi points at source data   destroyed
    ;//         edi points at min max data  destroyed
    ;//         ebp has inner count         presereved
    ;//     fpu is loaded as    ;// 1/r     ofset

    ASSUME edi:PTR SCOPE_MIN_MAX    ;// ptr to min max
    ASSUME esi:PTR DWORD            ;// input data

    IF OFFSET SCOPE_MIN_MAX.min NE 0
        .ERR <this routine requires that min be the first item>
    ENDIF

;// the counts are loaded from the above table

    outer_loop:         ;// scan input in blocks of ebp sample

            fld default_max ;// load the default max
            fld default_min ;// load the default min

            mov ecx, ebp
            xor eax, eax

        inner_loop:     ;// scan input 1:1 and store min/max

            fld [esi]       ;// X0      min     max     R       O

            fucom           ;// X0      min     max     R       O
            fnstsw ax
            sahf
            jae @01

                fxch        ;// min     X0      max     R       O
                fstp st     ;// X0      max     R       O
                fld st      ;// X0      min     max     R       O
        @01:
            fucom st(2)     ;// X0      min     max     R       O
            fnstsw ax
            sahf
            jbe @02

                fxch st(2)  ;// max     min     X0      R       O
        @02:
            add esi, 4
            fstp st         ;// min     max     R       O
            dec ecx
            jnz inner_loop

        determine_what_to_store:

            xor eax, eax
                            ;// min     max     R       O

            fadd st, st(3)  ;// min+O   max     R       O
            fxch
            fadd st, st(3)  ;// max+O   min+O   R       O
            fxch
            fmul st, st(2)  ;// Ymin    max+O   R       O
            fxch
            fmul st, st(2)  ;// Ymax    Ymin    R       O

        ;// store IN.min as OUT.max, and IN.max as OUT.min
        ;// this makes the axis easier

            fxch            ;// Ymin    Ymax    R       O
            fistp [edi].max ;// Ymax    R       O
            mov eax, 64 ;// eax will be the new C.min
            fistp [edi].min ;// R       O
            mov edx, 64 ;// edx will be the new C.max

            sub eax, [edi].min  ;// flip the axis
            .IF SIGN?
                xor eax, eax
            .ELSEIF eax > SCOPE_HEIGHT - 1
                mov eax, SCOPE_HEIGHT - 1
            .ENDIF

            sub edx, [edi].max  ;// flip the axis
            .IF SIGN?
                xor edx, edx
            .ELSEIF edx > SCOPE_HEIGHT - 1
                mov edx, SCOPE_HEIGHT - 1
            .ENDIF

            dec ebx ;// iterate the count
            mov [edi].max, edx  ;// store max value
            stosd   ;// store th min value and iterate edi

        jnz outer_loop

    ret

scope_fill_scan ENDP


ASSUME_AND_ALIGN
scope_scan_quarter PROC

;// use this for RANGE1_0
;// all it does is generate the 256 min max values

    ;// ebp points at source data
    ;// edi points at N     ;// offset as required for channel two
    ;// fpu is loaded as    ;// 1/r     ofset

    ASSUME edi:PTR SCOPE_MIN_MAX    ;// min max data to fill in
    ASSUME ebp:PTR DWORD            ;// input data

    IF OFFSET SCOPE_MIN_MAX.min NE 0
        .ERR <this routine requires that min be the first item>
    ENDIF

    mov ecx, SCOPE_WIDTH    ;// quarter scan is always 256 points

    .REPEAT
        fld [ebp]       ;// x1      R       O
        fadd st, st(2)  ;// x1+O    R       O
        fmul st, st(1)  ;// X1
        mov eax, 64     ;// preload eax
        add ebp, 4      ;// iterate source
        fistp [edi].max ;// store the y coord
        sub eax, [edi].max  ;// subtract it from eax
        .IF SIGN?       ;// out or range ?
            xor eax, eax;// zero
        .ELSEIF eax>SCOPE_HEIGHT-1  ;// out of range ?
            mov eax, SCOPE_HEIGHT-1 ;// saturate
        .ENDIF
        mov [edi].max, eax  ;// store our value in max
        dec ecx         ;// iterate the count
        stosd           ;// store our value in min, and iterate edi

    .UNTIL ZERO?        ;// done ?

    ret

scope_scan_quarter ENDP




ASSUME_AND_ALIGN
scope_scan_full PROC

;// use this for RANGE1_5 and 6
;// it scans the entire frame, and ACCUMULATES the min max at the desired N

    ;// ebp points at source data
    ;// edi points at N     ;// offset as required for channel two
    ;// fpu is loaded as    ;// 1/r     ofset

    ASSUME edi:PTR SCOPE_MIN_MAX
    ASSUME ebp:PTR DWORD            ;// input data

    mov ecx, SAMARY_LENGTH
    xor eax, eax

    fld default_min
    fld default_max

    .REPEAT

        fld [ebp]       ;// X   max min     R   O
        fucom st(1)
        fnstsw ax
        add ebp, 4
        sahf
        jbe @F
            fxch
            fstp st
            fld st
    @@: fucom st(2)
        fnstsw ax
        sahf
        jae @F
            fxch st(2)
    @@: fstp st
        dec ecx

    .UNTIL ZERO?
                        ;// max     min     R   O
    fadd st, st(3)      ;// max+O   min     R   O
    fxch
    fadd st, st(3)
    pushd ecx           ;// make some room
    fxch
    fmul st, st(2)
    pushd ecx           ;// make some room
    fxch
    fmul st, st(2)
    fxch

    fistp DWORD PTR [esp+4] ;// max
    mov eax, 64
    fistp DWORD PTR [esp]   ;// min
    mov edx, 64

    sub eax, [esp+4]    ;// max
    .IF SIGN?
        xor eax, eax
    .ELSEIF eax > SCOPE_HEIGHT-1
        mov eax, SCOPE_HEIGHT-1
    .ENDIF

    sub edx, [esp]      ;// min
    .IF SIGN?
        xor edx, edx
    .ELSEIF edx > SCOPE_HEIGHT-1
        mov edx, SCOPE_HEIGHT-1
    .ENDIF

    add esp, 8          ;// clean up the stack

    .IF eax < [edi].min ;// see if we need to replace the min value
        mov [edi].min, eax
    .ENDIF
    .IF edx > [edi].max ;// see if we need to replace the max value
        mov [edi].max, edx
    .ENDIF

    ret

scope_scan_full ENDP


ASSUME_AND_ALIGN
scope_scan_external_Y PROC

    ;// this is the external sweep mode
    ;// use once per channel

    ASSUME ebp:PTR DWORD    ;// Y input channel         (iterated)
    ASSUME edi:PTR DWORD    ;// destination data to fill (iterated)

    ;// fpu must be loaded as 1/r   offset

    mov ecx, SAMARY_LENGTH  ;// always scan the entire frame

    .REPEAT

        fld [ebp]           ;// y   R   O
        fadd st, st(2)      ;// X+O R   O
        fmul st, st(1)      ;// Y   R   O
        add ebp, 4
        mov eax, 64
        fistp DWORD PTR [edi]
        sub eax, [edi]
        .IF SIGN?
            xor eax, eax
        .ELSEIF eax > SCOPE_HEIGHT-1
            mov eax, SCOPE_HEIGHT-1
        .ENDIF
        dec ecx
        stosd

    .UNTIL ZERO?

    ret

scope_scan_external_Y ENDP


ASSUME_AND_ALIGN
scope_scan_external_X   PROC

    ;// this does the X data for the external sweep
    ;// use once per frame

    ASSUME ebp:PTR DWORD    ;// X input data    (iterated)
    ASSUME edi:PTR DWORD    ;// destination data to fill (C0)(iterated)

    fld math_128    ;// scale for X
    mov ecx, SAMARY_LENGTH  ;// always scan the entire frame

    .REPEAT

        fld [ebp]           ;// X   S
        fmul st, st(1)      ;// X   S
        mov eax, SCOPE_WIDTH / 2
        add ebp, 4
        fistp [edi]
        add eax, [edi]
        .IF SIGN?
            xor eax, eax
        .ELSEIF eax > SCOPE_WIDTH - 1
            mov eax, SCOPE_WIDTH - 1
        .ENDIF
        dec ecx
        stosd

    .UNTIL ZERO?

    fstp st

    ret

scope_scan_external_X   ENDP




comment ~ /*


UPDATE INDEXES OSCOPE MODE

    update N, N0, and N1

non scroll
    do these four steps:

    1)  if N0==width then N0=N1=N
    2)  N += outter
    3)  if N1 < N then N1 = N
    4)  if N = 128 then N = 0

scroll mode

    scroll mode requires a third stage be inserted
    to account for the fact that render may lag calc by several frames

    for range1_4, _5, and _6 in scroll mode

    1)  if N1==WIDTH && NC==0 && N >= N0
            shift C0 and C1 BACK by outter
        endif

    2)  do the normal aquire scan
        produce outter as required by the sweep rate

    3)  if N1 < WIDTH

            do the normal update_N0_N1

        else N1==WIDTH

            N0 -= outter
            shift += outter
            make sure that neigther N0 or shift are > WIDTH
            make sure that N <= WIDTH-outter

        endif


*/ comment ~

ASSUME_AND_ALIGN
oscope_update_indexes PROC

    ;// this is used in oscilloscope mode to update the the N, N0, and N1 indexes

    ASSUME esi:PTR OSCOPE_OSC_MAP

    ;// edx must enter as the number of columns to advance N

    ;// this routine also acounts for scroll mode

        test [esi].dwUser, SCOPE_SCROLL
        mov eax, [esi].scope.N  ;// eax is N
        mov ebx, [esi].scope.N0 ;// ebx is N0
        mov ecx, [esi].scope.N1 ;// ecx is N1
        jnz scroll_mode

    non_scroll_mode:

        ;// non scroll
        ;// do these four steps:
        ;//
        ;// 1)  if N0==width then N0=N1=N
        ;// 2)  N += outter
        ;// 3)  if N1 < N then N1 = N
        ;// 4)  if N = 128 then N = 0

        .IF ebx == SCOPE_WIDTH  ;// N0=256 ?
        DEBUG_IF<ebx!!=ecx> ;// shouldn't ever happen
            mov ebx, eax    ;// set N0
            mov ecx, eax    ;// set N1
        .ENDIF

        add eax, edx        ;// N + outter
        .IF eax > SCOPE_WIDTH   ;// happens when changing settings
            mov eax, SCOPE_WIDTH
        .ENDIF

        .IF ecx < eax       ;// N1 < N+outter?
            mov ecx, eax    ;// N1 = N+outter
        .ENDIF

        .IF eax == SCOPE_WIDTH      ;// N+outter = width ?
            xor eax, eax    ;// N = 0
        .ENDIF

        jmp update_store


    ALIGN 16
    scroll_mode:    ;// eax is N
                    ;// ebx is N0
                    ;// ecx is N1
    comment ~ /*
        3)  if N1 < WIDTH
                do the normal update_N0_N1
            else N1==WIDTH
                N0 -= outter
                shift += outter
                make sure that neigther N0 or shift are > WIDTH
                make sure that N <= WIDTH-outter
            endif
    */ comment ~

        cmp ecx, SCOPE_WIDTH    ;// N1 < WIDTH?
        jb non_scroll_mode      ;// do normal

        .IF edx             ;// if outter is not zero

            sub ebx, edx        ;// N0-=outter
            .IF SIGN?           ;// too small ?
                xor ebx, ebx    ;// no it's not
            .ENDIF
            add [esi].scope.dib_shift, edx          ;// advance dib shift
            .IF [esi].scope.dib_shift > SCOPE_WIDTH ;// make it's not too big
                mov [esi].scope.dib_shift, SCOPE_WIDTH
            .ENDIF

            mov eax, SCOPE_WIDTH        ;// set N as WIDTH-outter
            sub eax, edx

        .ENDIF

    ;// store the results

    update_store:

        mov [esi].scope.N, eax  ;// new N
        mov [esi].scope.N0, ebx ;// new N0
        mov [esi].scope.N1, ecx ;// new N1

    ret

oscope_update_indexes ENDP


;//
;//     aquire routines for oscope mode
;//
;//
;////////////////////////////////////////////////////////////////////









ALIGN 16
get_r_value PROC PRIVATE

    ASSUME ebx:PTR APIN

    ;// fpu must be the defaault value
    ;// ebx must point at the pin

    ;// returns value   scale
    ;// for use in label invalidateing

        mov ebx, [ebx].pPin
        .IF ebx
            mov ebx, [ebx].pData
            fld DWORD PTR [ebx]
            fabs
            fld math_Millionth
            fucom
            fnstsw ax
            sahf
            jb @F
                fxch
        @@: fstp st
            fld st  ;// value   value   default
            fdivp st(2), st
        .ELSE
            fld1
        .ENDIF

        retn

get_r_value ENDP









;////////////////////////////////////////////////////////////////////
;//
;//
;//     convert routines for spectrum mode
;//


comment ~ /*

    the passed pointer pSrc is always the result of an FFT
    so the values are arranged as 512 pairs of bins
    the spec_Convert function's job is to tranform this information into the desired format

types of scans, always produce 256 min/max values

    range      in:out   description
    --------   ------   ---------------------------------------------------------
    range2_3    2:1     min/max of 256 pairs of 2 bins each
    range2_2    1:1     min/max of 256 bins starting at o1*256
    range2_1    1:2     iterpolate between min/max of 128 bins starting at o1*256
    range2_0    1:4     iterpolate min/max for 64 bins starting at o1*256

types of destinations

    M   always mag(source) to C0
    MA  if average, then do that to C1 using Y1 as holder

    /   R0  M   \   8 states
    |   R1  MA  |
    |   R2      |
    \   R3      /


input range:

    the o1 pin specifies the range (ignored for R3)

    scaling is always: abs(o1[0])*512
    which is then clipped at:

    R3  ignore
    R2  100h-1  =   255
    R1  180h-1  =   383
    R0  1C0h-1  =   448

    these values are then added to the input pointer


two passes:

    the first pass will do any of the 8 states above
    it's job is to fill the appropriate C0,C1 and Y1 arrays with values
    the values are stored as int's at the appropriate scale

    the second pass will convert the int's to main/max coords
    by flipping them around the x axis
    saturation is also done at this point

*/ comment ~

ASSUME_AND_ALIGN
spec_Convert PROC   ;// STDCALL pSource:DWORD

    ;// our task here is to convert the data pointed at by pSource
    ;// into a renderable format
    ;// we must account for the o1 and r1 pins
    ;// as well as the desired scan mode and average setting

        ASSUME esi:PTR OSCOPE_OSC_MAP   ;// preserve
        push ebp    ;// must preserve
        push ebx    ;// must preserve
        pushd 0     ;// counter

    ;// destroys edi

    ;// stack:  st_start ebx ebp ret pSource ...
    ;//         00       04  08  0C  10

    st_start    TEXTEQU <(DWORD PTR [esp+00h])>
    st_source   TEXTEQU <(DWORD PTR [esp+10h])>

    ;// get our input scales, start pointers, and check if the label needs updated

        mov ecx, [esi].dwUser

    ;// build edx as a range table offset

        mov edx, ecx                    ;// load dwUser
        and edx, SCOPE_RANGE2_TEST      ;// mask out extra
        shr edx, LOG2(SCOPE_RANGE2_1)-2 ;// scoot into place

    ;// input offset pointer

        GET_PIN_FROM ebx, [esi].pin_o1.pPin ;// get the pin
        fldz                        ;// load the default ofset
        .IF ebx                     ;// see if connected
            mov ebx, [ebx].pData    ;// get data pointer
            fadd DWORD PTR [ebx]    ;// add first value to default offset
            fabs
            fld spectrum_freq_limit[edx];// load the freq limit
            fucom                       ;// fucompare
            fnstsw ax
            sahf
            ja @F       ;// smaller ?
                fxch    ;// clip
        @@: fstp st ;// dump the value we don't want

        .ENDIF

        ;// check if value is different
        .IF [esi].dwUser & SCOPE_LABELS

            fld [esi].scope.value_3 ;// load the last value
            fucomp              ;// compare and ditch it
            fnstsw ax
            sahf
            .IF !ZERO?  ;// different ?
                fst [esi].scope.value_3 ;// set up new values
                or [esi].scope.dwFlags, INVALIDATE_LABEL_3  ;// set the flag while that's busy
            .ENDIF

            fld st
            fadd spectrum_freq_offset[edx]  ;// add stated offset to end of spectrum

            fld [esi].scope.value_4 ;// load the last value
            fucomp              ;// compare and ditch it
            fnstsw ax
            sahf
            .IF !ZERO?  ;// different ?
                fstp [esi].scope.value_4            ;// store end in label 4
                or [esi].scope.dwFlags, INVALIDATE_LABEL_4  ;// set the flag while that's busy
            .ELSE
                fstp st
            .ENDIF

        .ENDIF

        fmul math_512   ;// finish building the frequency offset
        fistp st_start  ;// finish building the frequency offset

    ;// input scale

        OSC_TO_PIN_INDEX esi, ebx, PIN_R1   ;// get the pin
        fld math_128                ;// R   default is full range
        invoke get_r_value

        ;// see if we build a new label
        .IF [esi].dwUser & SCOPE_LABELS

            ;// see if they're different
            fld [esi].scope.value_1 ;// val1    scale
            fucomp              ;// scale
            fnstsw ax
            sahf
            .IF !ZERO?
                fstp [esi].scope.value_1
                or [esi].scope.dwFlags, INVALIDATE_LABEL_1
            .ELSE
                fstp st
            .ENDIF
        .ELSE
            fstp st
        .ENDIF

;// set up the pointers

    mov ecx, [esi].dwUser   ;// load this now
    mov ebp, st_source
    ASSUME ebp:PTR DWORD

;// determine how to do this

    bt ecx,LOG2(SCOPE_AVERAGE)
    jc average_routines

normal_routines:

    and ecx, SCOPE_RANGE2_TEST  ;// strip out extra bits
    jz R0_M                     ;// jmp if we already know the range
    cmp ecx, SCOPE_RANGE2_2     ;// compare with center of remaining
    jb R1_M                     ;// if below, it must be range 1
    jz R2_M                     ;// if equal ... duh

    R3_M:

        ;// average 256 pairs of inputs
        ;//
        ;// sqrt( max(r1*r1 + i1*i1) (r2*r2 + i2*i2) )

        mov ecx, 256
        lea edi, [esi].scope.C0

        R3_M_loop:

            fld [ebp+00h]
            fmul st, st     ;// xr0^2   R
            fld [ebp+04h]
            fmul st, st     ;// xi0^2   Xr0^2   R
            fld [ebp+08h]
            fmul st, st     ;// xr1^2   xi0^2   xr0^2   R
            fld [ebp+0Ch]
            fmul st, st     ;// xi1     xr1     xi0     xr0     R

            fxch st(2)      ;// xi0     xr1     xi1     xr0     R
            faddp st(3), st ;// xr1     xi1     x0      R
            fadd            ;// x1      x0      R
            fucom
            fnstsw ax
            sahf
            .IF !CARRY?
                fxch
            .ENDIF
            fstp st
            fsqrt
            add ebp, 10h
            fmul st, st(1)  ;// X
            fistp C0_MIN(edi)

            add edi, 4
            dec ecx         ;// decrease the count
            jnz R3_M_loop

        ;// clean up and go to convert min

            fstp st
            jmp spec_convert_min


    ALIGN 16
    R2_M:

        ;// convert 256 pairs starting at o1
        ;// sqrt( r1*r1 + i1*i1 )

        mov edx, st_start
        DEBUG_IF <edx !> 255>   ;// oops
        mov ecx, 256
        lea ebp, [ebp+edx*8]
        lea edi, [esi].scope.C0

        R2_M_loop:

            fld [ebp+00h]
            fmul st, st     ;// x0^2    R
            fld [ebp+04h]
            fmul st, st     ;// x1^2    X0^2    R
            fadd            ;// X^2     R
            fsqrt
            add ebp, 8h
            fmul st, st(1)  ;// X
            fistp C0_MIN(edi)

            add edi, 4
            dec ecx
            jnz R2_M_loop

        ;// clean up and go to convert min

            fstp st
            jmp spec_convert_min

    ALIGN 16
    R1_M:

        ;// convert 128 pairs starting at o1
        ;// and iterpolate 1 between point

        fld math_1_2

        mov edx, st_start
        DEBUG_IF <edx !> 383>   ;// oops
        lea ebp, [ebp+edx*8]

            ;// first point

            fld [ebp+00h]
            fmul st, st     ;// x0^2    1/2     R
            fld [ebp+04h]
            fmul st, st     ;// x1^2    X0^2    1/2     R
            fadd            ;// X^2     1/2     R
            fsqrt
        lea edi, [esi].scope.C0
        mov ecx, 128
            add ebp, 8h
            fmul st, st(2)  ;// X0      1/2     R

        R1_M_loop:

            fist C0_MIN(edi)
            add edi, 4

            ;// next point

            fld [ebp+00h]
            fmul st, st     ;// xr^2    X0      1/2     R
            fld [ebp+04h]
            fmul st, st     ;// xi^2    Xr^2    X0      1/2     R
            fadd            ;// x1^2    X0      1/2     R
            fsqrt
            add ebp, 8h     ;// x1      X0      1/2     R
            fmul st, st(3)  ;// X1      X0      1/2     R

            ;// iterpolate

            fxch            ;// X0      X1      1/2     R
            fadd st, st(1)  ;// X01     X1      1/2     R
            fmul st, st(2)  ;// av01    X0
            fistp C0_MIN(edi)
            add edi, 4

            ;// iterate

            dec ecx
            jnz R1_M_loop

        ;// clean up and go to convert min

            fstp st
            fstp st
            fstp st
            jmp spec_convert_min

    ALIGN 16
    R0_M:

        ;// convert 64 pairs starting at 01
        ;// and iterpolate the 3 between points


        mov edx, st_start
        DEBUG_IF <edx !> 447>   ;// oops
        fld math_1_4
        lea ebp, [ebp+edx*8]

        mov ecx, 64
        lea edi, [esi].scope.C0

            ;// first point

            fld [ebp+00h]
            fmul st, st     ;// x0^2    1/4     R
            fld [ebp+04h]
            fmul st, st     ;// x1^2    X0^2    1/4     R
            fadd            ;// X^2     1/4     R
            fsqrt
            add ebp, 8h
            fmul st, st(2)  ;// X0      1/4     R

        R0_M_loop:

            fist C0_MIN(edi)
            add edi, 4

            ;// next point

            fld [ebp+00h]
            fmul st, st     ;// xr^2    X0      1/4     R
            fld [ebp+04h]
            fmul st, st     ;// xi^2    Xr^2    X0      1/4     R
            fadd            ;// x1^2    X0      1/4     R
            fsqrt
            add ebp, 8h     ;// x1      X0      1/4     R
            fmul st, st(3)  ;// X1      X0      1/4     R

            ;// iterpolate

            fxch            ;// X0      X1      1/4     R
            fld st          ;// X0      X0      X1      1/4     R
            fsubr st, st(2) ;// dX      X0      X1      1/4     R
            fmul st, st(3)  ;// kX      X0      X1      1/4     R

            fxch            ;// X0      kX      X1      1/4     R
            fadd st, st(1)  ;// x1/4    kX      X1      1/4     R
            fist C0_MIN(edi)
            fadd st, st(1)  ;// x2/4    kX      X1      1/4     R
            add edi, 4
            fist C0_MIN(edi)
            fadd            ;// x3/4    X1      1/4     R
            add edi, 4
            fistp C0_MIN(edi)
            add edi, 4      ;// X1      1/4     R

            ;// iterate

            dec ecx
            jnz R0_M_loop

        ;// clean up and go to convert min

            fstp st
            fstp st
            fstp st

            jmp spec_convert_min





ALIGN 16
average_routines:

    fld math_average        ;// input scale
    lea ebx, [esi].scope.Y1     ;// load the averaging source
    fld math_decay          ;// D   A   R
    ASSUME ebx:PTR DWORD

    and ecx, SCOPE_RANGE2_TEST  ;// strip out extra bits
    jz R0_MA                    ;// jmp if we already know the range
    cmp ecx, SCOPE_RANGE2_2     ;// compare with center of remaining
    jb R1_MA                    ;// if below, it must be range 1
    jz R2_MA                    ;// if equal ... duh

    R3_MA:

        ;// average 256 pairs of inputs
        ;//
        ;// sqrt( max(r1*r1 + i1*i1) (r2*r2 + i2*i2) )

        mov ecx, 256
        lea edi, [esi].scope.C0

        R3_MA_loop:

            fld [ebp+00h]
            fmul st, st     ;// xr0^2   D       A       R
            fld [ebp+04h]
            fmul st, st     ;// xi0^2   Xr0^2   D       A       R
            fld [ebp+08h]
            fmul st, st     ;// xr1^2   xi0^2   xr0^2   D       A       R
            fld [ebp+0Ch]
            fmul st, st     ;// xi1     xr1     xi0     xr0     D       A       R

            fxch st(2)      ;// xi0     xr1     xi1     xr0     D       A       R
            faddp st(3), st ;// xr1     xi1     x0      D       A       R
            fadd            ;// x1      x0      D       A       R
            fucom
            fnstsw ax
            sahf
            .IF !CARRY?
                fxch
            .ENDIF
            fstp st
            fsqrt
            add ebp, 10h
            fmul st, st(3)  ;// X       D       A       R

            fld [ebx]       ;// ave     X       D       A       R
            fmul st, st(2)  ;// Dave    X       D       A       R
            fld st(1)       ;// X       Dave    X       D       A       R
            fmul st, st(4)  ;// xa      dave    X       D       A       R
            fadd
            fst [ebx]
            fistp C1_MIN(edi)
            fistp C0_MIN(edi)
            add edi, 4
            add ebx, 4

            dec ecx         ;// decrease the count
            jnz R3_MA_loop

        ;// clean up and go to convert min

            fstp st
            fstp st
            fstp st
            jmp spec_convert_min_dual



    ALIGN 16
    R2_MA:

        ;// convert 256 pairs starting at o1
        ;// sqrt( r1*r1 + i1*i1 )

        mov edx, st_start
        DEBUG_IF <edx !> 255>   ;// oops
        mov ecx, 256
        lea ebp, [ebp+edx*8]

        lea edi, [esi].scope.C0

        R2_MA_loop:
        ;// get the point
            fld [ebp+00h]
            fmul st, st     ;// x0^2    D       A       R
            fld [ebp+04h]
            fmul st, st     ;// x1^2    X0^2    D       A       R
            fadd            ;// X^2     D       A       R
            fsqrt
            add ebp, 8h
            fmul st, st(3)  ;// X       D       A       R
        ;// average trace
            fld [ebx]       ;// ave     X       D       A       R
            fmul st, st(2)  ;// Dave    X       D       A       R
            fld st(1)       ;// X       Dave    X       D       A       R
            fmul st, st(4)  ;// xa      dave    X       D       A       R
            fadd            ;// ave     X       D       A       R
        ;// store
            fst [ebx]
            fistp C1_MIN(edi)
            fistp C0_MIN(edi)
            add ebx, 4
            add edi, 4

            dec ecx
            jnz R2_MA_loop

        ;// clean up and go to convert min

            fstp st
            fstp st
            fstp st
            jmp spec_convert_min_dual


    ALIGN 16
    R1_MA:

        ;// convert 128 pairs starting at o1
        ;// and iterpolate 1 between point


        mov edx, st_start
        DEBUG_IF <edx !> 383>   ;// oops
        fld math_1_2
        lea ebp, [ebp+edx*8]

        ;// first point
            fld [ebp+00h]
            fmul st, st     ;// x0^2    1/2     D       A       R
            fld [ebp+04h]
            fmul st, st     ;// x1^2    X0^2    1/2     D       A       R
            fadd            ;// X^2     1/2     D       A       R
            fsqrt
        lea edi, [esi].scope.C0
        mov ecx, 128
            add ebp, 8h
            fmul st, st(4)  ;// X0      1/2     D       A       R
        R1_MA_loop:
        ;//average trace
            fld [ebx]       ;// ave     X       1/2     D       A       R
            fmul st, st(3)  ;// Dave    X       1/2     D       A       R
            fld st(1)       ;// X       Dave    X       1/2     D       A       R
            fmul st, st(5)  ;// xa      dave    X       1/2     D       A       R
            fadd            ;// xave    X       1/2     D       A       R
            fst [ebx]
            fistp C1_MIN(edi)
            fist C0_MIN(edi)
            add edi, 4
            add ebx, 4
        ;// next point
            fld [ebp+00h]
            fmul st, st     ;// xr^2    X0      1/2     D       A       R
            fld [ebp+04h]
            fmul st, st     ;// xi^2    Xr^2    X0      1/2     D       A       R
            fadd            ;// x1^2    X0      1/2     D       A       R
            fsqrt
            add ebp, 8h     ;// x1      X0      1/2     D       A       R
            fmul st, st(5)  ;// X1      X0      1/2     D       A       R
        ;// iterpolate
            fxch            ;// X0      X1      1/2     D       A       R
            fadd st, st(1)  ;// X01     X1      1/2     D       A       R
            fmul st, st(2)  ;// av01    X0      1/2     D       A       R
        ;// average
            fld [ebx]       ;// ave     av01    X0      1/2     D       A       R
            fmul st, st(4)  ;// Dave    av01    X0      1/2     D       A       R
            fld st(1)       ;// X       dAve    av01    X0      1/2     D       A       R
            fmul st, st(6)  ;// xa      dave    av01    X0      1/2     D       A       R
            fadd            ;// xave    av01    X0      1/2     D       A       R
        ;// store
            fst [ebx]
            fistp C1_MIN(edi)
            fistp C0_MIN(edi)
            add ebx, 4
            add edi, 4
        ;// iterate
            dec ecx
            jnz R1_MA_loop
        ;// clean up and go to convert min_dual
            fstp st
            fstp st
            fstp st
            fstp st
            fstp st
            jmp spec_convert_min_dual

    ALIGN 16
    R0_MA:

        ;// convert 64 pairs starting at 01
        ;// and iterpolate the 3 between points

        mov edx, st_start
        DEBUG_IF <edx !> 447>   ;// oops
        mov ecx, 64
        lea ebp, [ebp+edx*8]

        lea edi, [esi].scope.C0

        ;// first point
            fld [ebp+00h]
            fmul st, st     ;// x0^2    D       A       R
            fld [ebp+04h]
            fmul st, st     ;// x1^2    X0^2    D       A       R
            fadd            ;// X^2     D       A       R
            fsqrt
            add ebp, 8h
            fmul st, st(3)  ;// X0      D       A       R
        R0_MA_loop:
        ;// average
            fld [ebx]       ;// ave     X0      D       A       R
            fmul st, st(2)  ;// Dave    X0      D       A       R
            fld st(1)       ;// X       Dave    X0      D       A       R
            fmul st, st(4)  ;// xa      dave    X0      D       A       R
            fadd            ;// xave    X0      D       A       R
            fst [ebx]
            fistp C1_MIN(edi)
            fist C0_MIN(edi)
            add ebx, 4
            add edi, 4
        ;// next point
            fld [ebp+00h]
            fmul st, st     ;// xr^2    X0      D       A       R
            fld [ebp+04h]
            fmul st, st     ;// xi^2    Xr^2    X0      D       A       R
            fadd            ;// x1^2    X0      D       A       R
            fsqrt
            add ebp, 8h     ;// x1      X0      D       A       R
            fmul st, st(4)  ;// X1      X0      D       A       R
        ;// iterpolate
            fxch            ;// X0      X1      D       A       R
            fld st          ;// X0      X0      X1      D       A       R
            fsubr st, st(2) ;// dX      X0      X1      D       A       R
            fmul math_1_4   ;//kX       X0      X1      D       A       R

            fxch            ;// X0      kX      X1      D       A       R
            fadd st, st(1)  ;// x1/4    kX      X1      D       A       R
        ;//average
            fld [ebx]       ;// ave     x1/4    kX      X1      D       A       R
            fmul st, st(4)  ;// Dave    x1/4    kX      X1      D       A       R
            fld st(1)       ;// X       Dave    x1/4    kX      X1      D       A       R
            fmul st, st(6)  ;// xa      dave    X0      D       A       R
            fadd            ;// xave    X0      D       A       R
            fst [ebx]
            fistp C1_MIN(edi)
            fist C0_MIN(edi)
            add ebx, 4
            add edi, 4
        ;// interpolate
            fadd st, st(1)  ;// x2/4    kX      X1      D       A       R
        ;//average
            fld [ebx]       ;// ave     x1/4    kX      X1      D       A       R
            fmul st, st(4)  ;// Dave    x1/4    kX      X1      D       A       R
            fld st(1)       ;// X       Dave    x1/4    kX      X1      D       A       R
            fmul st, st(6)  ;// xa      dave    X0      D       A       R
            fadd            ;// xave    X0      D       A       R
            fst [ebx]
            fistp C1_MIN(edi)
            fist C0_MIN(edi)
            add ebx, 4
            add edi, 4
        ;// interpolate
            fadd            ;// x3/4    X1      D       A       R
        ;//average
            fld [ebx]       ;// ave     x1/4    X1      D       A       R
            fmul st, st(3)  ;// Dave    x1/4    X1      D       A       R
            fld st(1)       ;// X       Dave    x1/4    X1      D       A       R
            fmul st, st(5)  ;// xa      dave    x1/4    X1      D       A       R
            fadd            ;// xave    x1/4    X1      D       A       R
            fst [ebx]
            fistp C1_MIN(edi)
            fistp C0_MIN(edi)
            add ebx, 4
            add edi, 4      ;// X1      D       A       R
        ;// iterate
            dec ecx
            jnz R0_MA_loop
        ;// clean up and go to convert min
            fstp st
            fstp st
            fstp st
            fstp st
            jmp spec_convert_min_dual



ALIGN 16
spec_convert_min:

    ;// this does the xlation from int's to proper min data
    ;// this is the single version (C0 only)

    ;//mov edi, st_edi
    or [esi].scope.dwFlags, INVALIDATE_C0
    mov [esi].scope.N0, 0
    mov [esi].scope.N1, SCOPE_WIDTH
    lea edi, [esi].scope.C0

    mov ecx, 256

@@: mov eax, SCOPE_HEIGHT-1
    sub eax, C0_MIN(edi)
    .IF SIGN?
        xor eax, eax
    .ELSEIF eax > SCOPE_HEIGHT-1
        mov eax, SCOPE_HEIGHT-1
    .ENDIF
    mov C0_MAX(edi), eax
    dec ecx
    stosd
    jnz @B

    jmp all_done


ALIGN 16
spec_convert_min_dual:

    ;// this does the xlation from int's to proper min data
    ;// this is the dual version (C0 and C1)

    ;//mov edi, st_edi
    or [esi].scope.dwFlags, INVALIDATE_C0 + INVALIDATE_C1
    mov [esi].scope.N0, 0
    mov [esi].scope.N1, SCOPE_WIDTH
    lea edi, [esi].scope.C0

    mov ecx, 256

@@: mov eax, SCOPE_HEIGHT-1
    mov edx, SCOPE_HEIGHT-1
    sub eax, C0_MIN(edi)
    .IF SIGN?
        xor eax, eax
    .ELSEIF eax > SCOPE_HEIGHT-1
        mov eax, SCOPE_HEIGHT-1
    .ENDIF
    sub edx, C1_MIN(edi)
    .IF SIGN?
        xor edx, edx
    .ELSEIF edx > SCOPE_HEIGHT-1
        mov edx, SCOPE_HEIGHT-1
    .ENDIF
    mov C0_MIN(edi), eax
    mov C0_MAX(edi), eax
    mov C1_MIN(edi), edx
    mov C1_MAX(edi), edx
    add edi, 4
    dec ecx
    jnz @B

    jmp all_done




ALIGN 16
all_done:

    pop eax ;// counter
    pop ebx
    pop ebp
    ret 4   ;// STDCALL 1 arg

spec_Convert ENDP

;//
;//
;//     convert routines for spectrum mode
;////////////////////////////////////////////////////////////////////






;////////////////////////////////////////////////////////////////////
;//
;//
;//     S O N O G R A P H
;//
comment ~ /*

    convert does the rendering in this mode
    there are three flavours depending on the vertical scale

        RANGE4_0:   128 CONSECUTIVE points, offset by o1
                    simply determine the color, based on magnitude
                    and send to dib at desired column

        RANGE4_1:   128 PAIRS of points, offset by o1
                    determine the largest magnitude for the pair
                    and send to dib at desired column

        RANGE4_2:   128 QUADS of points, no offset
                    determine the largest of the 4
                    send that color to the screen



        convert needs to know

            the video gain          ;// get from PIN_R1 to FPU
            the vertical offset     ;// stored in scope data
            the desired vertical range  ;// get from osc.dwUser, pass in ecx
            the destination column  ;// ebx
            the source data         ;// esi

        vertical offset ranges

            RANGE4_0: 128 consecutive bins      0:512-128 = 384
            RANGE4_1: max of 128 pairs of bins  0:512-256 = 256
            RANGE4_2: max of 128 quads of bins  0:512 no offset

    we always render 128 points directly to the column

        using saturation, we want the color index of:

            Color = X[offset] * Gain


*/ comment ~


ASSUME_AND_ALIGN
sono_Convert PROC

    ASSUME esi:PTR OSCOPE_OSC_MAP   ;// preserved

    ASSUME ebp:PTR DWORD    ;// source ptr    (iterated)
    ASSUME ebx:PTR BYTE     ;// top of column (preserved)
    ;// ecx must be the osc.dwUser flags
    ;// edi is destroyed

    ;// FPU enters as ;// (gain squared)

        pushd 0 ;// make some room on the stack

    ;// max video value for saturation (squared to prevent sqrt's)
    ;// divide by gain to prevent extra work

        fld scope_max_video ;// mVid    G^2
        fdiv st, st(1)

    ;// parse the aquire mode

        and ecx, SCOPE_RANGE4_TEST
        jz range_0
        cmp ecx, SCOPE_RANGE4_1
        jz range_1

    range_2:
    ;// RANGE4_2:   128 QUADS of points, no offset
    ;//             determine the largest of the 4
    ;//             send that color to the screen

        ;// do the scan

            xor edx, edx
            mov ecx, 127*SCOPE_WIDTH    ;// start at the bottom and scan up
            mov dh, COLOR_GROUP_DISPLAYS + 31   ;// loudest color

        r2_top:

            fld [ebp]   ;// real    maxVid  G^2
            fmul st, st ;// r0^2
            fld [ebp+4] ;// imag    r0^2    maxVid  G^2
            fmul st, st ;// i0^2    r0^2    maxVid
            add ebp, 8
            fadd        ;// V0^2    maxVid  G^2

            fld [ebp]   ;// real    V0^2    maxVid  G^2
            fmul st, st ;// r1^2    V0^2    maxVid  G^2
            fld [ebp+4] ;// imag    r1^2    V0^2    maxVid  G^2
            fmul st, st ;// i1^2    r1^2    V0^2    maxVid  G^2
            add ebp, 8
            fadd        ;// V1^2    V0^2    maxVid  G^2

            fucom
            fnstsw ax
            sahf
            .IF !CARRY?
                fxch
            .ENDIF
            fstp st
            fld [ebp]   ;// real    V0^2    maxVid  G^2
            fmul st, st ;// r1^2    V0^2    maxVid  G^2
            fld [ebp+4] ;// imag    r1^2    V0^2    maxVid  G^2
            fmul st, st ;// i1^2    r1^2    V0^2    maxVid  G^2
            add ebp, 8
            fadd        ;// V1^2    V0^2    maxVid  G^2

            fucom
            fnstsw ax
            sahf
            .IF !CARRY?
                fxch
            .ENDIF
            fstp st
            fld [ebp]   ;// real    V0^2    maxVid  G^2
            fmul st, st ;// r1^2    V0^2    maxVid  G^2
            fld [ebp+4] ;// imag    r1^2    V0^2    maxVid  G^2
            fmul st, st ;// i1^2    r1^2    V0^2    maxVid  G^2
            add ebp, 8
            fadd        ;// V1^2    V0^2    maxVid  G^2

            fucom
            fnstsw ax
            sahf
            .IF !CARRY?
                fxch
            .ENDIF
            fstp st

            fucom       ;// see if in range
            fnstsw ax
            mov dl, COLOR_GROUP_DISPLAYS    ;// load the lowest color
            sahf
            jae @F      ;// skip if V^2 is more than maxVid

                fmul st, st(2)  ;// GV^2    maxVid  G^2
                fsqrt           ;// vid     maxVid  G^2
                fistp DWORD PTR [esp]
                add dl, BYTE PTR [esp]
                mov [ebx+ecx], dl
                sub ecx, SCOPE_WIDTH;// iterate the column
                jns r2_top
                jmp all_done

            @@: ; saturate
                mov [ebx+ecx], dh   ;// store the loudest
                sub ecx, SCOPE_WIDTH;// iterate the column
                fstp st             ;// dump the value
                jns r2_top
                jmp all_done



    ALIGN 16
    range_1:
    ;// RANGE4_1:   128 PAIRS of points, offset by o1
    ;//             determine the largest magnitude for the pair
    ;//             and send to dib at desired column

            ;// mov eax,
            DEBUG_IF <[esi].scope.sono_offset!>2040>    ;// (512-256-1)*8)> ;// oops
            add ebp, [esi].scope.sono_offset

        ;// do the scan

            xor edx, edx
            mov ecx, 127*SCOPE_WIDTH    ;// start at the bottom and scan up
            mov dh, COLOR_GROUP_DISPLAYS + 31   ;// loudest color

        r1_top:

            fld [ebp]   ;// real    maxVid  G^2
            fmul st, st ;// r0^2
            fld [ebp+4] ;// imag    r0^2    maxVid  G^2
            fmul st, st ;// i0^2    r0^2    maxVid
            add ebp, 8
            fadd        ;// V0^2    maxVid  G^2

            fld [ebp]   ;// real    V0^2    maxVid  G^2
            fmul st, st ;// r1^2    V0^2    maxVid  G^2
            fld [ebp+4] ;// imag    r1^2    V0^2    maxVid  G^2
            fmul st, st ;// i1^2    r1^2    V0^2    maxVid  G^2
            add ebp, 8
            fadd        ;// V1^2    V0^2    maxVid  G^2

            fucom
            fnstsw ax
            sahf
            .IF !CARRY?
                fxch
            .ENDIF
            fstp st

            fucom       ;// see if in range
            fnstsw ax
            mov dl, COLOR_GROUP_DISPLAYS    ;// load the lowest color
            sahf
            jae @F      ;// skip if V^2 is more than maxVid

                fmul st, st(2)  ;// GV^2    maxVid  G^2
                fsqrt           ;// vid     maxVid  G^2
                fistp DWORD PTR [esp]
                add dl, BYTE PTR [esp]
                mov [ebx+ecx], dl
                sub ecx, SCOPE_WIDTH;// iterate the column
                jns r1_top
                jmp all_done

            @@: ; saturate
                mov [ebx+ecx], dh   ;// store the loudest
                sub ecx, SCOPE_WIDTH;// iterate the column
                fstp st             ;// dump the value
                jns r1_top
                jmp all_done



    ALIGN 16
    range_0:
    ;// RANGE4_0:   128 CONSECUTIVE points, offset by o1
    ;//             simply determine the color, based on magnitude
    ;//             and send to dib at desired column

        ;// determine the ebp offset


            DEBUG_IF <[esi].scope.sono_offset !> 3064> ;//(512-128-1)*8> ;// oops
            add ebp, [esi].scope.sono_offset

        ;// do the scan

            xor edx, edx
            mov ecx, 127*SCOPE_WIDTH    ;// start at the bottom and scan up
            mov dh, COLOR_GROUP_DISPLAYS + 31   ;// loudest color

        r0_top:

            fld [ebp]   ;// real    maxVid  G^2
            fmul st, st ;// r^2
            fld [ebp+4] ;// imag    r^2     maxVid  G^2
            fmul st, st ;// i^2     r^2     maxVid
            add ebp, 8
            fadd        ;// V^2     maxVid  G^2

            fucom       ;// see if in range
            fnstsw ax
            mov dl, COLOR_GROUP_DISPLAYS    ;// load the lowest color
            sahf
            jae @F      ;// skip if V^2 is more than maxVid

                fmul st, st(2)  ;// GV^2    maxVid  G^2
                fsqrt           ;// vid     maxVid  G^2
                fistp DWORD PTR [esp]
                add dl, BYTE PTR [esp]
                mov [ebx+ecx], dl
                sub ecx, SCOPE_WIDTH;// iterate the column
                jns r0_top
                jmp all_done

            @@: ; saturate
                mov [ebx+ecx], dh   ;// store the loudest
                sub ecx, SCOPE_WIDTH;// iterate the column
                fstp st             ;// dump the value
                jns r0_top


all_done:

    fstp st
    add esp, 4

    ret

sono_Convert ENDP













;//
;//
;//     S O N O G R A P H
;//
;////////////////////////////////////////////////////////////////////




































;////////////////////////////////////////////////////////////////////
;//
;//
;//     C A L C
;//


ASSUME_AND_ALIGN
scope_Calc PROC USES ebp

    ASSUME esi:PTR OSCOPE_OSC_MAP

;// if we're not connected, don't do anything

    xor eax, eax
    CMPJMP eax, [esi].pin_y1.pPin, jnz @F       ;// x1 input
    CMPJMP eax, [esi].pin_y2.pPin, jz all_done  ;// x2 input

;// make sure we're on

@@: mov ecx, [esi].dwUser
    BITTJMP ecx, SCOPE_ON, jnc all_done

;// figure out what mode we're in

    BITTJMP ecx, SCOPE_SPECTRUM,    jc spectrum_mode    ;// spectrum mode ?
    BITTJMP ecx, SCOPE_SONOGRAPH,   jc sonograph_mode   ;// songraph mode ?

;////////////////////////////////////////////////////////////////////
;//
;//                         ecx = .dwUser
;//     OSCOPE MODE         esi = object
;//
oscope_mode:                        ;// oscope mode .

    mov eax, ecx                ;// jic
    and ecx, SCOPE_RANGE1_TEST  ;// range1_0 ?

    CMPJMP ecx, SCOPE_RANGE1_7, je oscope_external_scan ;// external ?

    .IF eax & SCOPE_TRIG_TEST
        BITTJMP eax, SCOPE_SCROLL,  jnc oscope_triggered_mode   ;// scroll mode ??
    .ENDIF

    TESTJMP ecx, ecx, jz oscope_quarter_scan

oscope_internal_scan:

    BITTJMP eax, SCOPE_SCROLL,  jnc oscope_done_with_scroll ;// scroll mode ??;// time to scroll ?

        ;// 1)  if N1==WIDTH && NC==0 && N >= N0 && N0 != 0
        ;//         shift C0 and C1 BACK by outter
        ;//     endif

        CMPJMP [esi].scope.N1, SCOPE_WIDTH,jne oscope_done_with_scroll  ;// N1==Width
        CMPJMP [esi].scope.NC, 0,jne oscope_done_with_scroll            ;// NC == 0 ?
        mov eax, [esi].scope.N                          ;// eax = N
        mov edx, [esi].scope.N0                     ;// edx = N0
        CMPJMP eax, edx, jb oscope_done_with_scroll     ;// N >= N0 ?
        TESTJMP edx, edx, jz oscope_done_with_scroll    ;// N0 != 0 ?

        ;// time to scroll  ;// ecx = range

        push ecx    ;// task: scoot C0 and C1 BACK by the desired range
        push esi    ;// this can be done in one block

                        ;// offset is either 1 or 4 (dwords)
                        ;// length is 256*4-offset

            lea edi, [esi].scope.C0.min ;// dest (edi) is always C0
            .IF ecx == SCOPE_RANGE1_4
                lea esi, [edi+4]    ;// source (esi) is always dest+offset
                mov ecx, 256*4-4    ;// total size - 4 dwords
            .ELSE
                lea esi, [edi+16]   ;//source (esi) is always dest+offset
                mov ecx, 256*4-1    ;// total size - 1 dword
            .ENDIF
            rep movsd   ;// mov it

        pop esi
        pop ecx

oscope_done_with_scroll:

    CMPJMP ecx, SCOPE_RANGE1_5, jb oscope_fill_scan ;// non overlapped ?

    oscope_overlaped:

    ;// we are in one of        ecx = range1 (already masked)
    ;// the overlapped modes    esi = object

    ;// calling convention for scope_scan_full
    ;//
    ;// ebp points at source data
    ;// edi points at N     ;// offset as required for channel two
    ;// fpu is loaded as    ;// 1/r     ofset

        ;// this mode requires that we clear C.min max manually
        ;// we do this when our counter = 0
        ;// NC is the counter

        GET_PIN_FROM edx, [esi].pin_y1.pPin
        .IF edx                             ;// see if channel 1 is connected

            or [esi].scope.dwFlags, INVALIDATE_C0   ;// schedule for being invalidated

            call get_input_scales_chan_1    ;// get the scales (destroys ebx)
            xor ecx, ecx
            mov ebp, [edx].pData            ;// input pointer
            mov edx, [esi].scope.N          ;// get our current N
            or  ecx, [esi].scope.NC         ;// load and test the count
            lea edi, [esi].scope.C0[edx*4]  ;// start of output pointer

            .IF ZERO?           ;// make sure to clear accumulate
                mov (SCOPE_MIN_MAX PTR [edi]).min, SCOPE_HEIGHT
                mov (SCOPE_MIN_MAX PTR [edi]).max, ecx
            .ENDIF

            invoke scope_scan_full      ;// call the scan function

            fstp st             ;// clean up
            fstp st

        .ENDIF

        GET_PIN_FROM edx, [esi].pin_y2.pPin
        .IF edx                             ;// see if channel 1 is connected

            or [esi].scope.dwFlags, INVALIDATE_C1   ;// schedule for being invalidated

            call get_input_scales_chan_2    ;// get the scales (destroys ebx)

            xor ecx, ecx
            mov ebp, [edx].pData            ;// input pointer
            mov edx, [esi].scope.N          ;// get our current N
            or ecx, [esi].scope.NC          ;// load and test the count
            lea edi, [esi].scope.C1[edx*4]  ;// start of output pointer

            .IF ZERO?           ;// make sure to clear accumulate
                mov (SCOPE_MIN_MAX PTR [edi]).min, SCOPE_HEIGHT
                mov (SCOPE_MIN_MAX PTR [edi]).max, ecx
            .ENDIF

            invoke scope_scan_full      ;// call the scan function

            fstp st             ;// clean up
            fstp st

        .ENDIF

        ;// determine how we update NC, and set up for advancing N

        mov eax, [esi].dwUser       ;// get the range
        and eax, SCOPE_RANGE1_TEST  ;// mask out the other stuff
        mov ecx, [esi].scope.NC     ;// get current value of NC
        mov edx, 1                  ;// set outter as 1
        .IF eax == SCOPE_RANGE1_6   ;// 4 frames per column mode ?
            inc ecx                     ;// increase NC
            .IF ecx < 4                 ;// time to advance ?
                mov [esi].scope.NC, ecx     ;// nope, store NC back in .scope
                and [esi].scope.dwFlags, NOT (INVALIDATE_C0+INVALIDATE_C1)
                jmp invalidate_and_done ;// and skip advancing N
            .ENDIF
            ;// yep, reset the count
        .ENDIF
        xor ecx,ecx         ;// yep, reset NC
        mov [esi].scope.NC, ecx ;// store NC back in .scope
        call oscope_update_indexes  ;// call the updater
        jmp invalidate_and_done



    ALIGN 16
    oscope_fill_scan:

    ;// we are in one of the filled scans   ecx = range1 (already masked)
    ;//                                     esi = object

    ;// calling convention for scope_fill_scan
    ;//
    ;//     ebx = outer count = 1024 >> ( range * 2 )   ;// range already in ecx
    ;//     ebp = inner count = 1 << ( range * 2 )
    ;//     esi = source data
    ;//     edi points at min/max
    ;//     fpu is loaded as    ;// 1/r     ofset

        shl ecx, 1      ;// range*2

        push esi    ;// presereve

        mov ebp, 1      ;// ebp will be inner count
        mov ebx, 1024   ;// ebx will be outter count

        shr ebx, cl     ;// 1024 >> ( range * 2 )
        shl ebp, cl     ;// 1 << ( range * 2 )

        push ebx    ;// save for later
                    ;// ebp is preserved in the call we're going to make

        ;// stack looks like this:
        ;// outter  osc     ret
        ;// 00      04
        ;// ebx     esi

        GET_PIN_FROM edx, [esi].pin_y1.pPin
        .IF edx                             ;// see if channel 1 is connected

            or [esi].scope.dwFlags, INVALIDATE_C0   ;// schedule for being invalidated

            call get_input_scales_chan_1    ;// get the scales (destroys ebx)

            mov eax, [edx].pData        ;// input pointer, must end up in esi

            mov edx, [esi].scope.N      ;// get our current N
            lea edi, [esi].scope.C0[edx*4];// start of output pointer
            mov ebx, [esp]              ;// reload outter count
            mov esi, eax

            invoke scope_fill_scan      ;// call the scan function

            fstp st             ;// clean up
            mov esi, [esp+04h]  ;// get the osc ptr
            fstp st


        .ENDIF

        GET_PIN_FROM edx, [esi].pin_y2.pPin
        .IF edx                             ;// see if channel 1 is connected

            or [esi].scope.dwFlags, INVALIDATE_C1   ;// schedule for being invalidated

            call get_input_scales_chan_2    ;// get the scales (destroys ebx)

            mov eax, [edx].pData        ;// input pointer, must end up in esi
            mov edx, [esi].scope.N      ;// get our current N
            lea edi, [esi].scope.C1[edx*4];// start of output pointer
            mov ebx, [esp]              ;// reload outer count
            mov esi, eax

            invoke scope_fill_scan      ;// call the scan function

            fstp st             ;// clean up
            fstp st

        .ENDIF


        ;// clean up the stack

        pop edx ;// edx = outter
        pop esi

        call oscope_update_indexes  ;// advance the indexes
        jmp invalidate_and_done     ;// that's it


    ALIGN 16
    oscope_quarter_scan:

        ;// we are in the quarter scan

        ;// set up for quarter scan
        ;// call quarter scan for channel one
        ;// call quarter scan for channel 2

        GET_PIN_FROM edx, [esi].pin_y1.pPin
        .IF edx                             ;// see if channel 1 is connected

            or [esi].scope.dwFlags, INVALIDATE_C0   ;// schedule for being invalidated

            call get_input_scales_chan_1    ;// get the scales (destroys ebx)

            mov ebp, [edx].pData            ;// set the input and output pointer
            lea edi, [esi].scope.C0

            invoke scope_scan_quarter       ;// call the scan function

            fstp st                 ;// clean up
            fstp st

        .ENDIF

        GET_PIN_FROM edx, [esi].pin_y2.pPin
        .IF edx                             ;// see if channel 2 is connected

            or [esi].scope.dwFlags, INVALIDATE_C1   ;// schedule for being invalidated

            call get_input_scales_chan_2    ;// get the scales (destroys ebx)

            mov ebp, [edx].pData            ;// set the input and output pointer
            lea edi, [esi].scope.C1

            invoke scope_scan_quarter       ;// call the scan function

            fstp st                         ;// clean up
            fstp st

        .ENDIF

        mov [esi].scope.N0, 0               ;// make sure that N0 and N1 are set correctly
        mov [esi].scope.N1, SCOPE_WIDTH

        jmp invalidate_and_done





    ALIGN 16
    oscope_external_scan:   ;// xy mode

        ;// external sweep mode

        ;// make sure X is connected
        ;// set up for scan
        ;// call for channel 1
        ;// call for channel 2

        ;// make sure the sweep is connected


            GET_PIN_FROM ecx, [esi].pin_x.pPin
            TESTJMP ecx, ecx, jz all_done

        ;// do the X scan

            mov ebp, [ecx].pData
            lea edi, [esi].scope.C0
            invoke scope_scan_external_X

        ;// do channel 1

            GET_PIN_FROM edx, [esi].pin_y1.pPin
            .IF edx

                or [esi].scope.dwFlags, INVALIDATE_C0   ;// schedule for being invalidated
                call get_input_scales_chan_1;// get the scales
                mov ebp, [edx].pData        ;// set the input and output pointer
                lea edi, [esi].scope.Y0
                invoke scope_scan_external_Y;// call the scan function
                fstp st                     ;// clean up
                fstp st

            .ENDIF

        ;// do channel 2

            GET_PIN_FROM edx, [esi].pin_y2.pPin
            .IF edx

                or [esi].scope.dwFlags, INVALIDATE_C1   ;// schedule for being invalidated
                call get_input_scales_chan_2;// get the scales
                mov ebp, [edx].pData        ;// set the input and output pointer
                lea edi, [esi].scope.Y1
                invoke scope_scan_external_Y;// call the scan function
                fstp st                     ;// clean up
                fstp st

            .ENDIF

        ;// that's it

            jmp invalidate_and_done





;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////

comment ~ /*

    N = column we are looking
    S = input sample we are looking at
    R = number of input samples remaining in the column

*/ comment ~

    ALIGN 16
    oscope_triggered_mode:

    ;// ecx = range1
    ;// esi = object

        ASSUME esi:PTR OSCOPE_OSC_MAP

            xor eax, eax    ;// eax is default sample counter

        ;// in sweep ?

            CMPJMP eax, [esi].scope.remain, jnz in_sweep
            CMPJMP eax, [esi].scope.N,      jnz in_sweep

        not_in_sweep:       ;// so we check for trigger

            push ecx                ;// must preserve
            call check_for_trigger  ;// ecx returns with sample number
            mov eax, ecx
            pop ecx
            jz invalidate_and_done  ;// and zero for no trigger

        ;// set the beginning remain count

            mov edx, 1      ;// default remain = 4^range
            shl edx, cl
            shl edx, cl
            mov [esi].scope.remain, edx ;// store in object

        ;// set up the first columns

            mov ebx, default_min
            mov edx, default_max

            mov [esi].scope.C0.min[0], ebx
            mov [esi].scope.C0.max[0], edx
            mov [esi].scope.C1.min[0], ebx
            mov [esi].scope.C1.max[0], edx

            mov [esi].scope.N0, 0
            mov [esi].scope.N1, 0

        in_sweep:

        ;// prepare local variables
        ;// these will remain on the stack to be used by do_triggered_sweep

            push esi                ;// have to preserve

            mov edx, 1              ;// edx ends up as 4^range
            push [esi].scope.N      ;// N
            shl edx, cl
            push eax                ;// S       store the sample start
            shl edx, cl
            push [esi].scope.remain ;// R
            push edx            ;// defR    default remain count

            st_osc  TEXTEQU <(DWORD PTR [esp+16+stack_depth*4])>
            st_N    TEXTEQU <(DWORD PTR [esp+12+stack_depth*4])>
            st_S    TEXTEQU <(DWORD PTR [esp+8+stack_depth*4])>
            st_R    TEXTEQU <(DWORD PTR [esp+4+stack_depth*4])>
            st_defR TEXTEQU <(DWORD PTR [esp+stack_depth*4])>
            stack_depth=0

        ;// do channel 1

            .IF [esi].pin_y1.pPin   ;// input y1 connected ?

                call get_input_scales_chan_1    ;// get the input scales

                lea edi, [esi].scope.C0         ;// point at column buffer
                GET_PIN [esi].pin_y1.pPin, esi  ;// point at input pin's connection
                mov esi, [esi].pData            ;// point at input data

                call do_triggered_sweep         ;// do the sweep

                mov esi, st_osc                 ;// retrieve the osc pointer
                ASSUME esi:PTR OSCOPE_OSC_MAP
                mov [esi].scope.remain, edx     ;// store the returned R
                mov [esi].scope.N, ebx          ;// store the returned N
                .IF ebp                         ;// was anything done ?
                    mov [esi].scope.N1, ebp     ;// store max column to update
                    or [esi].scope.dwFlags, INVALIDATE_C0   ;// schedule for being invalidated
                .ENDIF

            .ENDIF

        ;// second channel same as the first

            .IF [esi].pin_y2.pPin

                call get_input_scales_chan_2

                lea edi, [esi].scope.C1
                GET_PIN [esi].pin_y2.pPin, esi
                mov esi, [esi].pData

                call do_triggered_sweep

                mov esi, st_osc                 ;// retrieve the osc pointer
                ASSUME esi:PTR OSCOPE_OSC_MAP
                mov [esi].scope.remain, edx
                mov [esi].scope.N, ebx
                .IF ebp
                    mov [esi].scope.N1, ebp
                    or [esi].scope.dwFlags, INVALIDATE_C1
                .ENDIF

            .ENDIF

        ;// clean up stack and exit to display invalidator

            add esp, 20

            jmp invalidate_and_done

    ;/////////////////////////////////////////////////////////////////////////

    ALIGN 16
    do_triggered_sweep: ;// PROC C  defR R S N

        ;// returns edx and ebx as where we left off
        ;// returns ebp as the column we want to invalidate

            ASSUME edi:PTR SCOPE_MIN_MAX
            ASSUME esi:PTR DWORD

            stack_depth=1   ;// hooks in to macros defined in previous section

            mov edx, st_R   ;// edx counts remaining in each column
            mov ecx, st_S   ;// ecx indexes samples
            mov ebx, st_N   ;// ebx indexes column

            xor ebp, ebp

            .IF !edx    ;// previous scan was actually finished

                fld [edi+ebx*4].max ;// load min max from the column
                fld [edi+ebx*4].min
                jmp clip_and_store  ;// jump to preparation stage

            .ENDIF

        scan_the_column:

            fld [edi+ebx*4].max ;// load min max from the column
            fld [edi+ebx*4].min

        do_min_max:     ;// test for min max
                        ;// note that R inside the FPU is the input scalar, NOT the remain count

            fld [esi+ecx*4] ;// X0      min     max     R       O
            fucom           ;// X0      min     max     R       O
            fnstsw ax
            sahf
            jae j01
            fxch            ;// min     X0      max     R       O
            fstp st         ;// X0      max     R       O
            fld st          ;// X0      min     max     R       O
        j01:fucom st(2)     ;// X0      min     max     R       O
            fnstsw ax
            sahf
            jbe j02
            fxch st(2)      ;// max     min     X0      R       O
        j02:fstp st         ;// min     max     R       O

        ;// iterate S and R counters

            inc ecx             ;// advance S to next sample
            dec edx             ;// decrease R remaining now or we have to do it twice later

            cmp ecx, SAMARY_LENGTH      ;// see if the S frame is done (out of samples)
            jae triggered_frame_done    ;// jmp if so

            test edx,edx        ;// see if this R column is done (still samples remaining)
            jnz do_min_max      ;// jmp if column is not done

        ;// this column is done

        clip_and_store:

        ;// condition, clip and store the min max results

            fadd st, st(3)      ;// max+O   min     R   O
            fxch
            fadd st, st(3)      ;// min+O   max+O   R   O
            fxch
            fmul st, st(2)      ;// MAX     min+O   R   O
            fxch
            fmul st, st(2)      ;// MIN     MAX     R   O
            fxch

            fistp [edi+ebx*4].max   ;// MIN     R   O
            mov eax, 64
            fistp [edi+ebx*4].min   ;// R   O
            mov edx, 64

            sub eax, [edi+ebx*4].max
            .IF SIGN?
                xor eax, eax
            .ELSEIF eax > SCOPE_HEIGHT-1
                mov eax, SCOPE_HEIGHT-1
            .ENDIF
            mov [edi+ebx*4].max, eax

            sub edx, [edi+ebx*4].min
            .IF SIGN?
                xor edx, edx
            .ELSEIF edx > SCOPE_HEIGHT-1
                mov edx, SCOPE_HEIGHT-1
            .ENDIF
            mov [edi+ebx*4].min, edx

        ;// advance N to next column

            inc ebx                     ;// advance N to next column
            mov ebp, ebx                ;// store for return value
            cmp ebx, SCOPE_WIDTH        ;// see if we're done with the sweep
            jae triggered_sweep_done    ;// jmp if done with sweep

        ;// reset minmax of next column

            mov eax, default_min
            mov edx, default_max
            mov [edi+ebx*4].min, eax
            mov [edi+ebx*4].max, edx

        ;// start a new column

            mov edx, st_defR    ;// get the default remain
            jmp scan_the_column ;// jmp to top of loop

        ;// exit points

        ALIGN 16
        triggered_frame_done:

        ;// save the min max data for the next frame

            fstp [edi+ebx*4].min
            fstp [edi+ebx*4].max
            fstp st
            fstp st
            retn

        ALIGN 16
        triggered_sweep_done:

        ;// get the last trigger sample this frame

            mov esi, st_osc                 ;// get the osc
            ASSUME esi:PTR OSCOPE_OSC_MAP
            GET_PIN [esi].pin_x.pPin, ecx   ;// get the s pin
            ;//DEBUG_IF <!!ecx>             ;// supposed to be valid !!
            .IF ecx
            mov ecx, [ecx].pData            ;// get the s data
            mov ecx, DWORD PTR [ecx+1023*4] ;// get the last sample
            mov [esi].pin_x.dwUser, ecx     ;// store in s pin
            .ELSE
            neg [esi].pin_x.dwUser
            .ENDIF

        ;// clean out fpu, reset R and O and split

            fstp st
            xor ebx, ebx
            fstp st
            xor edx, edx

            retn

        ;// source code clean up local variables

            st_osc  TEXTEQU <>
            st_N    TEXTEQU <>
            st_S    TEXTEQU <>
            st_R    TEXTEQU <>
            st_defR TEXTEQU <>
            stack_depth=0




    ALIGN 16
    check_for_trigger:

    ;// return zero flag if no trigger
    ;// otherwise, return ecx as the sample number of the trigger
    ;// destroys eax, ebx, ecx, edx

        ASSUME esi:PTR OSCOPE_OSC_MAP

        xor ebx, ebx    ;// clear for next test
        xor ecx, ecx    ;// always start at sample zero

        OR_GET_PIN [esi].pin_x.pPin, ebx    ;// make sure 's' is connected

        .IF !ZERO?

            mov eax, [esi].pin_x.dwUser ;// get the last trigger
            mov ebx, [ebx].pData        ;// point at trigger data
            ASSUME ebx:PTR DWORD

            .WHILE ecx < SAMARY_LENGTH  ;// scan all samples in frame

                xor eax, [ebx+ecx*4]    ;// compare signs
                mov eax, [ebx+ecx*4]    ;// then load the full value
                js got_edge             ;// if signs are different ...
            back_at_it:
                inc ecx                 ;// next sample

            .ENDW                       ;// zero flag will be set here

        .ENDIF

    ready_to_go:

        mov [esi].pin_x.dwUser, eax ;// store the last recieved trigger

        retn

    ALIGN 16
    got_edge:               ;// an edge has been detected

        test eax, eax       ;// was it pos or neg ?
        jns got_pos_edge

    got_neg_edge:

        test [esi].dwUser, SCOPE_TRIG_NEG   ;// do we want the neg edge ?
        jz back_at_it                           ;// nope
        jmp ready_to_go                         ;// yep

    got_pos_edge:

        test [esi].dwUser, SCOPE_TRIG_POS   ;// do we want the pos edge ?
        jz back_at_it                           ;// nope
        jmp ready_to_go                         ;// yep




;//
;//
;//     OSCOPE MODE
;//
;////////////////////////////////////////////////////////////////////









;////////////////////////////////////////////////////////////////////
;//
;//                             ecx = dwUser
;//     SPECTRUM MODE           esi = object
;//                             edi = scope
ALIGN 16
spectrum_mode:

    ASSUME esi:PTR OSCOPE_OSC_MAP

    ;// all modes use the same routine

    GET_PIN_FROM ebx, [esi].pin_y1.pPin
    TESTJMP ebx, ebx, jz all_done           ;// make sure we're connected enough to do this

        push esi

        DECJMP [esi].scope.N,   jz spec_stage_B ;// update and see what stage we're in

    spec_stage_A:   ;// STAGE A

        ;// <convert>   spec_Convert(Y0)

            lea edx, [esi].scope.Y0 ;// get what we want to convert
            mov [esi].scope.N, 1    ;// set next for stage B
            push edx                ;// push param
            invoke spec_Convert     ;// call the convert routine

        ;// <aquire>    copy X0 to Y0

            lea edi, [esi].scope.Y0     ;// load this data pointer too
            mov esi, [ebx].pData    ;// load the data pointer
            mov ecx, SAMARY_LENGTH  ;// copy all of it
            rep movsd

        ;// that's it

        pop esi

            jmp invalidate_and_done

    ALIGN 16
    spec_stage_B:   ;// STAGE B

        ;// <process>   dual fft X0 to Y0, Y0 to Z0

            lea edx, [esi].scope.Y0 ;// get destination 1
            push scope_Z0       ;// push detination 2
            push edx            ;// push destination 1
            pushd FFT_FORWARD + FFT_WINDOW + FFT_1024   ;// set the fft flags
            push edx            ;// push source 2
            push [ebx].pData    ;// push source 1
            call fft_Run        ;// do it

            mov esi, [esp]

        ;// <convert>   spec_Convert(Z0)

            push scope_Z0       ;// push what we want to convert
            invoke spec_Convert ;// convert it

        ;// that's it

        pop esi

            jmp invalidate_and_done

;//
;// SPECTRUM MODE
;//
;//
;////////////////////////////////////////////////////////////////////






;////////////////////////////////////////////////////////////////////
;//
;//                             ecx = dwUser
;//     SONOGRAPH MODE          esi = object
;//                             edi = scope

ALIGN 16
sonograph_mode:

    GET_PIN_FROM ebx, [esi].pin_y1.pPin
    TESTJMP ebx, ebx,   jz all_done         ;// make sure we're connected enough to do this

DEBUG_IF <ecx !!= [esi].dwUser>

    push [ebx].pData

    push esi

    ;// make sure we have a container !!!!
    .IF ![esi].pContainer

        invoke scope_build_container
        mov ecx, [esi].dwUser

    .ENDIF



    ;// determine how we aquire

        BITTJMP ecx, SCOPE_RANGE3_1, jc sono_R1
        BITTJMP ecx, SCOPE_RANGE3_2, jc sono_R2

    ;// RANGE3_0:   4 columns per frame
    sono_R0:
    ;// stack looks like this
    ;// esi     pData   ret
    ;// 00      04

    ;//
    ;//     X0              Z0      Z1      Y0          Y1          N0  N1
    ;//     ------------    --------------  ---------   ---------   --------
    ;//     input data      temp            data(t-1)   data(t)     not used


        ;// <aquire>    copy_frame X0 to Y1

            lea edi, [esi].scope.Y1
            mov ecx, SAMARY_LENGTH
            mov esi, [ebx].pData
            rep movsd

        ;// <process>   fft Y0[1/4] to Z0, Y0[1/2] to Z1

            mov esi, [esp]

            push scope_Z1
            lea edx, [esi].scope.Y0[SAMARY_SIZE/2]
            push scope_Z0
            pushd FFT_1024 + FFT_WINDOW + FFT_FORWARD
            lea ecx, [esi].scope.Y0[SAMARY_SIZE/4]
            push edx
            push ecx
            invoke fft_Run

        ;// dib shift - 4

            mov esi, [esp]
            mov [esi].scope.dib_shift, 4
            invoke scope_dib_shift

        ;// <convert>   sono_convert Z0 to N+0, Z1 to N+1

            call get_sono_scales
            mov ebx, [esi].pSource
            mov ecx, [esi].dwUser
            mov ebp, scope_Z0
            add ebx, SCOPE_WIDTH - 4
            push ecx
            invoke sono_Convert

            inc ebx
            pop ecx
            mov ebp, scope_Z1
            invoke sono_Convert

            fstp st

        ;// <process>   fft Y0[3/4] to Z0, Y1[0] to Z1

            push scope_Z1
            lea edx, [esi].scope.Y1
            push scope_Z0
            pushd FFT_1024 + FFT_WINDOW + FFT_FORWARD
            lea ecx, [esi].scope.Y0[3*SAMARY_SIZE/4]
            push edx
            push ecx
            invoke fft_Run

        ;// <convert>   sono_convert Z0 to N+2, Z1 to N+3

            mov esi, [esp]
            call get_sono_scales
            mov ebx, [esi].pSource
            mov ecx, [esi].dwUser
            mov ebp, scope_Z0
            add ebx, SCOPE_WIDTH - 2
            push ecx
            invoke sono_Convert

            inc ebx
            mov ebp, scope_Z1
            pop ecx
            invoke sono_Convert

            fstp st

        ;// <aquire>    copy_frame Y1[1/4] to Y0[1/4]

            lea edi, [esi].scope.Y0[SAMARY_SIZE/4]
            lea esi, [esi].scope.Y1[SAMARY_SIZE/4]
            mov ecx, 3*SAMARY_LENGTH/4
            rep movsd

        ;// done

            jmp sono_done



    ;// RANGE3_1:   2 columns per frame
    ALIGN 16
    sono_R1:
    ;// stack looks like this
    ;// edi     esi     ret

    ;// X0              Z0      Z1      Y0          Y1          N0  N1
    ;// ------------    --------------  ---------   ---------   --------
    ;// input data      temp            data(t-1)   data(t)     not used


        ;// <aquire>    copy_frame X0 to Y1

            lea edi, [esi].scope.Y1
            mov ecx, SAMARY_LENGTH
            mov esi, [ebx].pData
            rep movsd

        ;// <process>   fft Y0[1/2] to Z0, Y1[0] to Z1

            mov esi, [esp]

            push scope_Z1
            lea ecx, [esi].scope.Y1
            push scope_Z0
            lea edx, [esi].scope.Y0[SAMARY_SIZE/2]
            pushd FFT_1024 + FFT_WINDOW + FFT_FORWARD
            push ecx
            push edx
            invoke fft_Run

        ;// dib shift - 2

            mov esi, [esp]
            mov [esi].scope.dib_shift, 2
            invoke scope_dib_shift

        ;// <convert>   sono_convert Z0 to N+0, Z1 to N+1

            call get_sono_scales
            mov ecx, [esi].dwUser
            mov ebx, [esi].pSource
            mov ebp, scope_Z0
            add ebx, SCOPE_WIDTH - 2
            push ecx
            invoke sono_Convert

            inc ebx
            mov ebp, scope_Z1
            pop ecx
            invoke sono_Convert

            fstp st

        ;// <aquire>    copy_frame Y1[1/2] to Y0[1/2]

            lea edi, [esi].scope.Y0[SAMARY_SIZE/2]
            lea esi, [esi].scope.Y1[SAMARY_SIZE/2]
            mov ecx, SAMARY_LENGTH/2
            rep movsd

        ;// done

            jmp sono_done





    ;// RANGE3_2:   1 colum per frame
    ALIGN 16
    sono_R2:
    ;// stack looks like this
    ;// edi     esi     ret

    ;// X0              Z0      Z1      Y0          Y1          N0  N1
    ;// ------------    --------------  ---------   ---------   --------
    ;// input data      temp            spec(t-1)   data(t)     not used

        DECJMP [esi].scope.N, jz sono_stage_B   ;// update and see what stage we're in

    sono_stage_A:   ;// STAGE A

            mov [esi].scope.N, 1        ;// set next for stage B

        ;// dib shift - 1

            mov esi, [esp]
            mov [esi].scope.dib_shift, 1
            invoke scope_dib_shift

        ;// <convert>   sono_Convert(Y0)

            call get_sono_scales
            mov ecx, [esi].dwUser
            mov ebx, [esi].pSource

            ;//mov esi, scope_Z0            ;// bug ABox229 <----, should be Y0
            lea ebp, [esi].scope.Y0

            add ebx, SCOPE_WIDTH - 1
            invoke sono_Convert

            fstp st

        ;// <aquire>    copy X0 to Y0

            lea edi, [esi].scope.Y0
            mov esi, [esp+4]    ;// retrieve the data pointer
            mov ecx, SAMARY_LENGTH
            rep movsd

            jmp sono_done

    ALIGN 16
    sono_stage_B:   ;// STAGE B

        ;// STAGE B
        ;//
        ;// <process>   dual fft X0 to Y0, Y0 to Z0

            lea ecx, [esi].scope.Y0
            mov edx, [ebx].pData

            push scope_Z0
            push ecx
            pushd FFT_1024 + FFT_WINDOW + FFT_FORWARD
            push ecx
            push edx
            invoke fft_Run

        ;// dib shift - 1

            mov esi, [esp]
            mov [esi].scope.dib_shift, 1
            invoke scope_dib_shift

        ;// <convert>   sono_Convert(Z0)

            call get_sono_scales
            mov edi, [esp]
            mov ecx, [esi].dwUser
            mov ebx, [esi].pSource
            mov ebp, scope_Z0
            add ebx, SCOPE_WIDTH - 1
            invoke sono_Convert

            fstp st

            jmp sono_done


ALIGN 16
sono_done:

    pop esi
    pop ebx


    ;// do this seperately
    xor eax, eax
    or eax, [esi].dwHintOsc ;// , INVAL_ONSCREEN
    jns all_done

    mov ecx, [esi].scope.dwFlags
    and ecx, SCOPE_INVALIDATE_TEST
    and [esi].scope.dwFlags, SCOPE_INVALIDATE_MASK
    shr ecx, SCOPE_INVALIDATE_SHIFT
    or [esi].scope.dwFlags, ecx

    invoke play_Invalidate_osc
    jmp all_done





;//
;//                             ecx = dwUser
;//     SONOGRAPH MODE          esi = object
;//
;////////////////////////////////////////////////////////////////////




ALIGN 16
invalidate_and_done:

;// DEBUG_IF < edi !!= [esi].pData >

    xor eax, eax
    or eax, [esi].dwHintOsc ;// & INVAL_ONSCREEN
    .IF SIGN?

        ;// check if the invalidate commands are on
        ;// shut them off if they are
        mov ecx, [esi].scope.dwFlags
        and ecx, SCOPE_INVALIDATE_TEST
        .IF !ZERO?

            and [esi].scope.dwFlags, SCOPE_INVALIDATE_MASK
            shr ecx, SCOPE_INVALIDATE_SHIFT
            or [esi].scope.dwFlags, ecx

            invoke play_Invalidate_osc

            invoke scope_Render_calc    ;// then we want to render the trace

        .ENDIF

    .ENDIF

all_done:

    ret







;// local functions

;// these retrieve the input values for the parameter pins
;// they also invalidate the label display as required

ALIGN 16
get_input_scales_chan_1:

    ;// (destroys ebx)

    ;// see if O is hooked up

        OSC_TO_PIN_INDEX esi, ebx, PIN_O1
        fldz
        call get_o_value

    ;// see if R is hooked up

        OSC_TO_PIN_INDEX esi, ebx, PIN_R1
        fld math_64             ;// 64      offset
        call get_r_value        ;// value   scale   offset

    ;// see if we build a new label
    .IF [esi].dwUser & SCOPE_LABELS
        ;// build new min max values

        fld st              ;// value   value   scale   offset
        fadd st, st(3)      ;// max     value   scale   offset
        fxch
        fsubr st, st(3)     ;// min     max     scale   offset
        fxch                ;// max     min     scale   offset
        ;// see if they're different
        fld [esi].scope.value_1 ;// val1    max     min     scale       offset
        fucomp              ;// max     min     scale   offset
        fnstsw ax
        sahf
        .IF !ZERO?
            fstp [esi].scope.value_1
            or [esi].scope.dwFlags, INVALIDATE_LABEL_1
        .ELSE
            fstp st
        .ENDIF

        fld [esi].scope.value_3 ;// val3    min     scale       offset
        fucomp              ;// min     scale   offset
        fnstsw ax
        sahf
        .IF !ZERO?
            fstp [esi].scope.value_3
            or [esi].scope.dwFlags, INVALIDATE_LABEL_3
        .ELSE
            fstp st
        .ENDIF

    .ELSE
        fstp st
    .ENDIF

    ;// that's it

        retn


ALIGN 16
get_input_scales_chan_2:

    ;// (destroys ebx)

    ;// see if O is hooked up

        OSC_TO_PIN_INDEX esi, ebx, PIN_O2
        fldz
        call get_o_value

    ;// see if R is hooked up

        OSC_TO_PIN_INDEX esi, ebx, PIN_R2
        fld math_64         ;// 64
        call get_r_value

    ;// see if we build a new label
    .IF [esi].dwUser & SCOPE_LABELS
        ;// build new min max values

        fld st              ;// value   value   scale   offset
        fadd st, st(3)      ;// max     value   scale   offset
        fxch
        fsubr st, st(3)     ;// min     max     scale   offset
        fxch                ;// max     min     scale   offset
        ;// see if they're different
        fld [esi].scope.value_2 ;// val1    max     min     scale       offset
        fucomp              ;// max     min     scale   offset
        fnstsw ax
        sahf
        .IF !ZERO?
            fstp [esi].scope.value_2
            or [esi].scope.dwFlags, INVALIDATE_LABEL_2
        .ELSE
            fstp st
        .ENDIF

        fld [esi].scope.value_4 ;// val3    min     scale       offset
        fucomp              ;// min     scale   offset
        fnstsw ax
        sahf
        .IF !ZERO?
            fstp [esi].scope.value_4
            or [esi].scope.dwFlags, INVALIDATE_LABEL_4
        .ELSE
            fstp st
        .ENDIF

    .ELSE
        fstp st
    .ENDIF



        ;//fstp st

    ;// that's it

        retn


ALIGN 16
get_sono_scales:

    ;// (destroys ebx)

    ;// see if O1 is hooked up

        OSC_TO_PIN_INDEX esi, ebx, PIN_O1
        fldz
        call get_o_value
        fabs

        ;// clip

        mov edx, [esi].dwUser
        and edx, SCOPE_RANGE4_TEST
        shr edx, LOG2(SCOPE_RANGE4_1)-2
        fld sono_freq_limit[edx]
        fucom
        fnstsw ax
        sahf
        ja @F
            fxch
    @@: fstp st     ;// ofset

    ;// see if we need to look at the label
    .IF [esi].dwUser & SCOPE_LABELS

        fld [esi].scope.value_2 ;// val2    offset
        fucomp              ;// offset
        fnstsw ax
        sahf
        .IF !ZERO?
            fst [esi].scope.value_2
            or [esi].scope.dwFlags, INVALIDATE_LABEL_2
        .ENDIF

        fld st                      ;// offset  offset
        fadd sono_freq_offset[edx]  ;// maxFreq offset
        fld [esi].scope.value_1         ;// val1    maxFreq offset
        fucomp                      ;// maxFreq offset
        fnstsw ax
        sahf
        .IF !ZERO?
            fstp [esi].scope.value_1
            or [esi].scope.dwFlags, INVALIDATE_LABEL_1
        .ELSE
            fstp st
        .ENDIF

    .ENDIF

    ;// scale to the proper offset

        fld math_512            ;// 512 offset
        fmul                    ;// offset
        fistp [esi].scope.sono_offset   ;// empty

    ;// load the video gain
    ;// see if R is hooked up

        OSC_TO_PIN_INDEX esi, ebx, PIN_R1
        fld math_32     ;// 32
        call get_r_value
        fstp st         ;// dump the extra
        fmul st, st     ;// always gain squared

    ;// scale the offset by 8

        shl [esi].scope.sono_offset, 3

    ;// that's it

        retn





ALIGN 16
get_o_value:

    ;// fpu must be the defaault value
    ;// ebx must point at the pin

        mov ebx, [ebx].pPin     ;// get the connection
        .IF ebx                 ;// anything ?
            mov ebx, [ebx].pData;// get pointer
            fadd DWORD PTR [ebx];// add to default
        .ENDIF

        retn


scope_Calc ENDP





ASSUME_AND_ALIGN



ENDIF   ;// USE_THIS_FILE
END

