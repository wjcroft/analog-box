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
;//     ABOX242 AJT -- detabified -- and code adjustments for lines that are too long
;//                 -- added 'first sample' fix to IIR_sX_sF_LP1 and IIR_sX_sF_HP1
;//
;//##////////////////////////////////////////////////////////////////////////
;//
;// ABox_1cP.asm            Version 3 introduced in ABox227
;//                         Absorbed Decay filter in ABox232
OPTION CASEMAP:NONE

.586
.MODEL FLAT

USE_THIS_FILE equ 1

IFDEF USE_THIS_FILE

        .NOLIST
        INCLUDE <ABox.inc>
        .LIST


comment ~ /*

    These filters took a long time to figure out

    some research is to be noted at:

        filt_04.mcd:    A hodgepodeg of formulas and test platforms for filters
        filt_05.mcd:    A correct derivation of the 6 types of filters using the bilinear xform
        filt_06b.mcd:   A study of how to apply the frequency warping correctly
                        of note is that this version and the standard texts DO NOT MATCH

        filt_20.mcd:    A correct account of how to construct the filters under various conditions
                        This file should be the master reference

    an attempt was made to develope a filter algoithm that pre defined the values for
    the next iteration while the current in-out values were still in the FPU. After
    several attempts it turned out that it did not save any cycles. These files have
    been deleted.

    addition to the previous iir filter

    idx name descr     ord  inputs  gain
    --- --- ---------- ---  ------  ----
     2  LP1 low pass    1   F                   F = Frequency, normalized as always
     3  HP1 high pass   1   F                   L = log2Q, Q=2^L, always valid
     4  LP2 low pass    2   F   L   A           A = Auto Gain, produces a G value
     5  HP2 high pass   2   F   L   A
     6  BP2 band pass   2   F   L   A
     7  BR2 band reject 2   F   L   A

     additions by combining decay filter

     8  decay both
     9  decay above
     10 decay below


    Each filter type may require as many as 32 operating modes.
    These are defined by the following state matrix

        X = input value
        F = normalized frequency
        L = log2(Q)
        G = auto gain

                              1CP 1CZ
            / dX dF dL aG \   LP1 HP1
            \ sX sF sR nG /   LP2 HP2        times 8 filter types = 128 calcs
                              BP2 BR2
              -- -- -- --     -------
        bit   6  5  4  3      (2 1 0)
        ofs/4 12864 32  16    8

    LP1 and HP1 do not have L or G inputs, thus they may be combined
    tracking sF or sX in dL modes is not worth the trouble

    1CP and 1CZ modes use exactly the same formulation as pre 2.27 versions

    Decay filters use exactly the same algorithm as pre ABox232
    Decay filter calc is stored in abox_Decay_2.asm

    Many filters share a common algorithm for the sX state
    The difference will be in how they load the fpu with their values
    The general scheme is to detect when the output stops changing (Y0-Y1 < small number)
    then store the same value for the rest of the frame

    if the presence of sX in dF or dL, most routines will use the same loops

    when changing filter types, care must be taken to interpolate the coefficients
    otherwise a VERY l;arge transient will result
    the function iir_interpolate_fram does this for all filters

    increased frequency accuracy is obtained by useing interpolation of sin cos
    1CP and 1CZ do NOT do do this (for backwards compatibility)


    we also have a detail mode that plots the basic filter shape in a 48x24 picture
    to do this quickly we stash several sets of fixed points
    see filter_Render for details

*/ comment ~



.DATA


        IIR_DATA STRUCT
        ;// stashed filter params
            b0  REAL4   0.0     ;// fixed filter coefficients
            b1  REAL4   0.0
            b2  REAL4   0.0
            a1  REAL4   0.0
            a2  REAL4   0.0
        ;// prev x input values
            x2  REAL4   0.0
            x1  REAL4   0.0
        ;// temp paramters for some calcs
            Q   REAL4   0.0     ;// stashed Q value     access by Q0 macro
            Q_2 REAL4   0.0     ;// stashed 2*Q         access by Q2 macro
            G   REAL4   0.0     ;// stashed G           access by G0 macro
        ;// when interpolating, this tells what to interpolate from
            old_filter  dd  0   ;// stored so we can build parameters correctly
                                ;// used when changing filter types
        ;// for detail mode, these track states
            dib                 dd  0   ;// dib we use when in detail mode
            last_render_state   dd  0   ;// last filter type
            last_render_L       dd  0   ;// last L value we saw
            last_render_F       dd  0   ;// last F value we saw

        IIR_DATA    ENDS

    ;// note that pin_f and pin_r store previous input values in dwUser


        ;// this limits S(F) lookup entries to about 22Khz
        IIR_MAX_ANGLE_OFFSET    EQU 32

        ;// really small is used for sX input states
        ;// this allows to check if non-changing signals have changed between frames
        ;// it tries to stop the filter when the change in output gets below this value

        iir_small_1 REAL4 1.86264E-9    ;// use for 1st order
        iir_small_2 REAL4 6.31E-8       ;// use for 2nd order

        decay_default_D REAL4 0.01e+0   ;// used in decay mode


;////////////////////////////////////////////////////////////////////
;//
;// OBJECT DEFINITION


osc_1cP OSC_CORE { filter_Ctor,filter_Dtor,filter_PrePlay,filter_Calc }
        OSC_GUI  { filter_Render,filter_SetShape,,,,filter_Command,filter_InitMenu,,,osc_SaveUndo,filter_LoadUndo,filter_GetUnit }
        OSC_HARD { }

    ;// don't make the lines too long
    ofsPinData  = SIZEOF OSC_OBJECT + ( SIZEOF APIN ) * 4
    ofsOscData  = SIZEOF OSC_OBJECT + ( SIZEOF APIN ) * 4 + SAMARY_SIZE
    oscBytes    = SIZEOF OSC_OBJECT + ( SIZEOF APIN ) * 4 + SAMARY_SIZE + SIZEOF IIR_DATA

    ;// define the layout
    OSC_DATA_LAYOUT {NEXT_1cP,IDB_1cP,OFFSET popup_1CP,BASE_SHAPE_EFFECTS_GEOMETRY,
        4,4,
        ofsPinData,
        ofsOscData,
        oscBytes   }

    OSC_DISPLAY_LAYOUT {filter_container, FILT_1CP_PSOURCE, ICON_LAYOUT(10,3,3,4) }

EXTERNDEF osc_1cP_pin_r:APIN_init   ;// needed by xlate_convert_decay

                APIN_init {-1.0,,'X',, UNIT_AUTO_UNIT }             ;// input
                APIN_init { 0.6,sz_Frequency,'F',, UNIT_HERTZ }     ;// dQ or decay D
osc_1cP_pin_r   APIN_init { 0.4,sz_iir_R_input,'R',, UNIT_VALUE }   ;// radius or L
            APIN_init { 0.0,,'=',,PIN_OUTPUT OR UNIT_AUTO_UNIT }  ;// output

    short_name  db  'IIR Filter',0
    description db  '11 analog style filters. Adjust frequency and damping to create the desired filter shape.',0
    ALIGN 4


    iir_psource_table LABEL DWORD
    dd  FILT_1CP_PSOURCE
    dd  FILT_1CZ_PSOURCE
    dd  FILT_LP1_PSOURCE
    dd  FILT_HP1_PSOURCE
    dd  FILT_LP2_PSOURCE
    dd  FILT_HP2_PSOURCE
    dd  FILT_BP2_PSOURCE
    dd  FILT_BR2_PSOURCE
    dd  DECAY_PSOURCE
    dd  DECAY_ABOVE_PSOURCE
    dd  DECAY_BELOW_PSOURCE

    iir_shape_R dd  'R'
    iir_shape_L dd  'L'
    iir_shape_D dd  'T'
    iir_shape_F dd  'F'
    ;//                 01234567
    sz_iir_R_input  db 'Radius',0,0
    sz_iir_L_input  db 'Log2(Q)',0
    sz_iir_D_input  db 'RC time constant',0
    ALIGN 4

    ;// setting for dwUser
    IIR_1CP             equ 00000000h   ;// use 1 conjugate pole (pre abox 227)
    IIR_1CZ             equ 00000001h   ;// use 1 conjugate zero (pre abox 227)
    IIR_LP1             equ 00000002h
    IIR_HP1             equ 00000003h
    IIR_LP2             equ 00000004h
    IIR_HP2             equ 00000005h
    IIR_BP2             equ 00000006h
    IIR_BR2             equ 00000007h
    IIR_LAST_TABLE_FILTER equ 000007h   ;// highest filter before the decay filter
    ;// ABox232: moved in from decay, these values must not be changed
    IIR_DECAY_BOTH      equ 00000008h   ;// old=0
    IIR_DECAY_ABOVE     equ 00000009h   ;// old=1  accumulate if above current
    IIR_DECAY_BELOW     equ 0000000Ah   ;// old=2  accumulate if below current

    NUM_FILTERS equ 11
    ;// ABox232 can't use this anymore
    ;// IIR_TEST    equ NUM_FILTERS - 1
    IIR_TYPE_TEST       equ 0000000Fh   ;// careful how this is used ...



    IIR_AUTO_GAIN       equ 00000010h   ;// force unity gain

;// IIR_CLIPPING        equ 00000100h   ;// show clipping (not used anymore)
    IIR_CLIP_NOW        equ 00000200h   ;// we are clipping now

    IIR_NEED_UPDATE     EQU 00000400h   ;// need to rebuild the filter parameters
    IIR_NEED_INTERP     EQU 00000800h   ;// need to interpolate from old filter to new

    IIR_SHOW_DETAIL     EQU 00001000h   ;// use detail mode for rendering
    IIR_DETAIL_CHANGED  EQU 00002000h   ;// tag for play thread

    IIR_OLD_CRAP    EQU    0FFFF0000h

        IIR_NORMAL_WIDTH    EQU 48
        IIR_NORMAL_HEIGHT   EQU 24

        IIR_DETAIL_WIDTH    EQU 64  ;// if width changes, must adjust the tables below
        IIR_DETAIL_HEIGHT   EQU 32

        IIR_DETAIL_ADJUST_X = (IIR_NORMAL_WIDTH -IIR_DETAIL_WIDTH ) / 2
        IIR_DETAIL_ADJUST_Y = (IIR_NORMAL_HEIGHT-IIR_DETAIL_HEIGHT) / 2

        IIR_NUM_DETAIL_POINTS EQU IIR_DETAIL_WIDTH - 4

        IIR_MIN_DISPLAY_Y EQU 2
        IIR_MAX_DISPLAY_Y EQU IIR_DETAIL_HEIGHT-2

        IIR_DETAIL_LABEL_X  EQU 14
        IIR_DETAIL_LABEL_Y  EQU 8

;// private clipping flag

    iir_clip    dd  0


;// OSC_MAP for this object


    IIR_OSC_MAP STRUCT

        OSC_OBJECT  {}
        pin_x   APIN    {}
        pin_f   APIN    {}
        pin_r   APIN    {}
        pin_y   APIN    {}
        data_y  dd SAMARY_LENGTH DUP (0)
        iir IIR_DATA {}

    IIR_OSC_MAP ENDS





;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;///
;///
;///    C A L C
;///
comment ~ /*


*/ comment ~


iir_calc_table LABEL DWORD

dd  IIR_sX_sF_sL_nG_1CP, IIR_sX_sF_sL_nG_1CZ, IIR_sX_sF_LP1, IIR_sX_sF_HP1, IIR_sX_sF_sL_nG_LP2, IIR_sX_sF_sL_nG_HP2, IIR_sX_sF_sL_nG_BP2, IIR_sX_sF_sL_nG_BR2
dd  IIR_sX_sF_sL_aG_1CP, IIR_sX_sF_sL_aG_1CZ, IIR_sX_sF_LP1, IIR_sX_sF_HP1, IIR_sX_sF_sL_aG_LP2, IIR_sX_sF_sL_aG_HP2, IIR_sX_sF_sL_aG_BP2, IIR_sX_sF_sL_aG_BR2
dd  IIR_sX_sF_dL_nG_1CP, IIR_sX_sF_dL_nG_1CZ, IIR_sX_sF_LP1, IIR_sX_sF_HP1, IIR_sX_sF_dL_nG_LP2, IIR_sX_sF_dL_nG_HP2, IIR_sX_sF_dL_nG_BP2, IIR_sX_sF_dL_nG_BR2
dd  IIR_sX_sF_dL_aG_1CP, IIR_sX_sF_dL_aG_1CZ, IIR_sX_sF_LP1, IIR_sX_sF_HP1, IIR_sX_sF_dL_aG_LP2, IIR_sX_sF_dL_aG_HP2, IIR_sX_sF_dL_aG_BP2, IIR_sX_sF_dL_aG_BR2

dd  IIR_sX_dF_sL_nG_1CP, IIR_sX_dF_sL_nG_1CZ, IIR_sX_dF_LP1, IIR_sX_dF_HP1, IIR_sX_dF_sL_nG_LP2, IIR_sX_dF_sL_nG_HP2, IIR_sX_dF_sL_nG_BP2, IIR_sX_dF_sL_nG_BR2
dd  IIR_sX_dF_sL_aG_1CP, IIR_sX_dF_sL_aG_1CZ, IIR_sX_dF_LP1, IIR_sX_dF_HP1, IIR_sX_dF_sL_aG_LP2, IIR_sX_dF_sL_aG_HP2, IIR_sX_dF_sL_aG_BP2, IIR_sX_dF_sL_aG_BR2
dd  IIR_sX_dF_dL_nG_1CP, IIR_sX_dF_dL_nG_1CZ, IIR_sX_dF_LP1, IIR_sX_dF_HP1, IIR_sX_dF_dL_nG_LP2, IIR_sX_dF_dL_nG_HP2, IIR_sX_dF_dL_nG_BP2, IIR_sX_dF_dL_nG_BR2
dd  IIR_sX_dF_dL_aG_1CP, IIR_sX_dF_dL_aG_1CZ, IIR_sX_dF_LP1, IIR_sX_dF_HP1, IIR_sX_dF_dL_aG_LP2, IIR_sX_dF_dL_aG_HP2, IIR_sX_dF_dL_aG_BP2, IIR_sX_dF_dL_aG_BR2

dd  IIR_dX_sF_sL_nG_1CP, IIR_dX_sF_sL_nG_1CZ, IIR_dX_sF_LP1, IIR_dX_sF_HP1, IIR_dX_sF_sL_nG_LP2, IIR_dX_sF_sL_nG_HP2, IIR_dX_sF_sL_nG_BP2, IIR_dX_sF_sL_nG_BR2
dd  IIR_dX_sF_sL_aG_1CP, IIR_dX_sF_sL_aG_1CZ, IIR_dX_sF_LP1, IIR_dX_sF_HP1, IIR_dX_sF_sL_aG_LP2, IIR_dX_sF_sL_aG_HP2, IIR_dX_sF_sL_aG_BP2, IIR_dX_sF_sL_aG_BR2
dd  IIR_dX_sF_dL_nG_1CP, IIR_dX_sF_dL_nG_1CZ, IIR_dX_sF_LP1, IIR_dX_sF_HP1, IIR_dX_sF_dL_nG_LP2, IIR_dX_sF_dL_nG_HP2, IIR_dX_sF_dL_nG_BP2, IIR_dX_sF_dL_nG_BR2
dd  IIR_dX_sF_dL_aG_1CP, IIR_dX_sF_dL_aG_1CZ, IIR_dX_sF_LP1, IIR_dX_sF_HP1, IIR_dX_sF_dL_aG_LP2, IIR_dX_sF_dL_aG_HP2, IIR_dX_sF_dL_aG_BP2, IIR_dX_sF_dL_aG_BR2

dd  IIR_dX_dF_sL_nG_1CP, IIR_dX_dF_sL_nG_1CZ, IIR_dX_dF_LP1, IIR_dX_dF_HP1, IIR_dX_dF_sL_nG_LP2, IIR_dX_dF_sL_nG_HP2, IIR_dX_dF_sL_nG_BP2, IIR_dX_dF_sL_nG_BR2
dd  IIR_dX_dF_sL_aG_1CP, IIR_dX_dF_sL_aG_1CZ, IIR_dX_dF_LP1, IIR_dX_dF_HP1, IIR_dX_dF_sL_aG_LP2, IIR_dX_dF_sL_aG_HP2, IIR_dX_dF_sL_aG_BP2, IIR_dX_dF_sL_aG_BR2
dd  IIR_dX_dF_dL_nG_1CP, IIR_dX_dF_dL_nG_1CZ, IIR_dX_dF_LP1, IIR_dX_dF_HP1, IIR_dX_dF_dL_nG_LP2, IIR_dX_dF_dL_nG_HP2, IIR_dX_dF_dL_nG_BP2, IIR_dX_dF_dL_nG_BR2
dd  IIR_dX_dF_dL_aG_1CP, IIR_dX_dF_dL_aG_1CZ, IIR_dX_dF_LP1, IIR_dX_dF_HP1, IIR_dX_dF_dL_aG_LP2, IIR_dX_dF_dL_aG_HP2, IIR_dX_dF_dL_aG_BP2, IIR_dX_dF_dL_aG_BR2


;////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////
;///
;///    variables
;///
;///    these macros help save a lot of code space
;///
;///

    F0 TEXTEQU <[edx+ecx*4]>    ;// current F value
    L0 TEXTEQU <[edi+ecx*4]>    ;// current L value

    B0 TEXTEQU <[esi].iir.b0>
    B1 TEXTEQU <[esi].iir.b1>
    B2 TEXTEQU <[esi].iir.b2>
    A1 TEXTEQU <[esi].iir.a1>
    A2 TEXTEQU <[esi].iir.a2>

    G0 TEXTEQU <[esi].iir.G>
    Q0 TEXTEQU <[esi].iir.Q>
    Q2 TEXTEQU <[esi].iir.Q_2>

    XX0 TEXTEQU <[ebx+ecx*4]>           ;// input
    XX1 TEXTEQU <[ebx+ecx*4-4]>         ;// prev input IN CURRENT FRAME
    XX2 TEXTEQU <[ebx+ecx*4-8]>         ;// prev input IN CURRENT FRAME

    X0 TEXTEQU <[ebx+ecx*4]>            ;// input
    X1 TEXTEQU <[esi].iir.x1>           ;// prev input  FROM PREVIOUS FRAME
    X2 TEXTEQU <[esi].iir.x2>           ;// prev input  FROM PREVIOUS FRAME
    XLAST  TEXTEQU <[ebx+LAST_SAMPLE]>  ;// last input value
    XLAST1 TEXTEQU <[ebx+LAST_SAMPLE-4]>;// next to last input value

    Y0 TEXTEQU <[esi].data_y[ecx*4]>            ;// current output

    Y1 TEXTEQU <[esi].data_y[LAST_SAMPLE]>      ;// prev output FROM PREVIOUS FRAME
    Y2 TEXTEQU <[esi].data_y[LAST_SAMPLE-4]>    ;// prev output FROM PREVIOUS FRAME

;///
;///    variables
;///
;///    these macros help save a lot of code space
;///
;///
;////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////


.CODE

ASSUME_AND_ALIGN
filter_Calc PROC

        ASSUME esi:PTR IIR_OSC_MAP

    ;// ABox232 jump to correct routine, this one or decay_Calc

        mov edx, [esi].dwUser
        and edx, IIR_TYPE_TEST
        cmp edx, IIR_DECAY_BOTH
        jae decay_Calc

    ;// regular IIR calc

        sub eax, eax
        xor ecx, ecx    ;// ecx will be the jump code

        OR_GET_PIN_FROM eax, [esi].pin_x.pPin   ;// X
        mov ebx, math_pNull
        .IF !ZERO?
            BITT [eax].dwStatus, PIN_CHANGING
            mov ebx, [eax].pData
            ASSUME ebx:PTR DWORD    ;// access with X0 macro
        .ENDIF
        rcl ecx, 1

        sub eax, eax
        OR_GET_PIN_FROM eax, [esi].pin_f.pPin   ;// F
        mov edx, math_pNull
        .IF !ZERO?
            BITT [eax].dwStatus, PIN_CHANGING
            mov edx, [eax].pData
            ASSUME edx:PTR DWORD    ;// access with F0 macro
        .ENDIF
        rcl ecx, 1

        xor eax, eax
        OR_GET_PIN_FROM eax, [esi].pin_r.pPin   ;// L
        mov edi, math_pNull
        .IF !ZERO?
            BITT [eax].dwStatus, PIN_CHANGING
            mov edi, [eax].pData
            ASSUME edi:PTR DWORD    ;// access with L0 macro
        .ENDIF
        rcl ecx, 1

    ;// now is our last chance to check if we need a new display

        .IF [esi].dwHintOsc & HINTOSC_STATE_ONSCREEN

            .IF [esi].dwUser & IIR_SHOW_DETAIL
                mov eax, L0
                cmp eax, [esi].iir.last_render_L
                jne need_invalidate
                mov eax, F0
                cmp eax, [esi].iir.last_render_F
                je no_need_invalidate
            need_invalidate:
                or [esi].dwUser, IIR_DETAIL_CHANGED
            no_need_invalidate:
            .ENDIF

        .ENDIF


        mov eax, [esi].dwUser
        BITT eax, IIR_AUTO_GAIN
        rcl ecx, 4                  ;// merge in auto_gain and make room for filter type

        and eax, IIR_TYPE_TEST
        DEBUG_IF < eax !> IIR_LAST_TABLE_FILTER > ;// somehow this snuck through
        or ecx, eax
        mov eax, iir_calc_table[ecx*4]

        xor ecx, ecx
        BITR [esi].dwUser, IIR_NEED_INTERP
        mov iir_clip, ecx
        jc iir_interpolate_frame

        jmp eax


    ;// all branches return here
    ALIGN 16
    iir_calc_done::

    ;// check if we clipped
    ;// then check if we need to update becuse of a parameter change

        mov ecx, [esi].dwUser
        .IF iir_clip    ;// we are clipping now
            BITS ecx, IIR_CLIP_NOW
            jc clip_done
            mov edx, HINTI_OSC_GOT_BAD
        .ELSE           ;// we are not clipping now
            BITR ecx, IIR_CLIP_NOW  ;// turn the flag off
            jc cd0                  ;// if was on, then turn off
            test [esi].dwHintOsc, HINTOSC_STATE_HAS_BAD ;// prevent getting stuck on bad
            jz clip_done
            ;// jnc clip_done
        cd0:mov edx, HINTI_OSC_LOST_BAD
        .ENDIF
        BITR ecx, IIR_DETAIL_CHANGED    ;// turn this off
        or [esi].dwHintI, edx
        jmp invalidate_this_object

    clip_done:

        BITR ecx, IIR_DETAIL_CHANGED
        .IF CARRY?
        invalidate_this_object:
            mov [esi].dwUser, ecx
            .IF [esi].dwHintOsc & HINTOSC_STATE_ONSCREEN
                invoke play_Invalidate_osc
            .ENDIF
        .ENDIF

    ;// that's it

        ret

filter_Calc ENDP


;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////


;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////

    ;// macro to get the sine and cosine without breaking anything
    ;// specifically geared to S(F) function

    ;// assume that F0 is the angle to use
    ;// assume that eax can be used
    ;// this version does the inerpolation between points


    iir_LookupSinCos MACRO

        ;// uses eax

        ;// sin(F*pi) ~ sin[F] + frac * cos[F]
        ;// cos(F*pi) ~ cos[F] - frac * sin[F]

            fld F0
            fabs                    ;// we want positive in these cases
            fmul  math_NormToOfs    ;// scale the real4 angle to an integer adress
            fist  _1cp_temp_1       ;// store to common location

            mov eax, _1cp_temp_1    ;// get the integer
            and  eax, math_AdrMask  ;// mask to dword

            ;// make sure not too close to 1
            .IF eax >= math_OfsHalf-IIR_MAX_ANGLE_OFFSET

                ;// need to flush the internal values
                ;// and load the proper maximum
                fstp st
                mov eax, math_OfsHalf-IIR_MAX_ANGLE_OFFSET
                add eax, math_pSin
                fld REAL4 PTR [eax]
                add eax, math_OfsQuarter
                fld REAL4 PTR [eax]

            .ELSE   ;// value is in range, do the interpolation

                mov _1cp_temp_1, eax    ;// store the truncated version !

                fild  _1cp_temp_1
                fsub
                fmul  math_NormToOfsPi  ;// frac
                add  eax, math_pSin     ;// add the table offset

                fld st
                fmul REAL4 PTR [eax]    ;// s*frac  frac
                fxch
                fmul REAL4 PTR [eax+math_OfsQuarter]
                                        ;// c*frac  s*frac
                fxch                    ;// sf      cf
                fsubr REAL4 PTR [eax+math_OfsQuarter]
                                        ;// CF      sf
                fxch
                fadd REAL4 PTR [eax]
                fxch                    ;// C   S

            .ENDIF


        ENDM


;// L to Q is put in a function
;// this routine takes 100's of cycles
;// making the space saved worth more than inline savings
;// use iir_build_Q macro as a common access point


    iir_build_Q MACRO
        invoke iir_L_to_Q
        ENDM



ALIGN 16
iir_L_to_Q PROC

    ;// requires 3 free registers
    ;// returns Q in st(0)
    ;// we assume that L0 is the value we use

        fld math_1      ;// 1   ...
        fld L0          ;// L   1   ...

iir_L_to_Q_special::    ;// called from filter render

        ;// add invalid param check here

        fld st          ;// L   L   1
        fabs
        fucomp st(2)    ;// L   1
        xor eax, eax
        fnstsw ax
        sahf
        .IF !CARRY? ;// have to do the hard way

            fxch            ;// 1   L   ...
            fld st(1)       ;// L   1   L   ...
            .REPEAT
                fprem
                xor eax, eax
                fnstsw ax
                sahf
            .UNTIL !PARITY? ;// fL      1   L
            f2xm1           ;// 2^fL-1  1   L
            fadd            ;// 2^fL    L
            fscale          ;// Q       L
            fxch
            fstp st         ;// Q

        .ELSE       ;// can do the easy way

            f2xm1           ;// Q-1 1
            fadd            ;// 2^X

        .ENDIF

        ret

iir_L_to_Q ENDP


    ;// these macros build GQ and Q2


    iir_build_aG MACRO

        call iir_Q_to_G

        ENDM

ALIGN 16
iir_Q_to_G PROC

        ;// G = sqrt( 4*Q*Q-1 ) / 2Q
        ;// if Q < 1/sqrt(2) then G = 1

        ;// in  FPU =  Q    ...
        ;// out FPU =  GQ   Q2     ...

        fld math_1_2_1_2
        fucomp
        xor eax, eax
        fnstsw ax
        fadd st, st         ;// Q2  ...
        sahf
        fld st              ;// Q   Q2  ...
        jnc use_minimum
        ;// .IF CARRY?
            fmul st, st     ;// QQ  Q2  ...
            fsub math_1
            fsqrt
            fdiv st, st(1)  ;// GQ  Q2  ...
        all_done:
            ret

        use_minimum:
            fmul math_1_2   ;// GQ  Q2
            jmp all_done


iir_Q_to_G ENDP


    iir_build_nG MACRO

        ;// in  FPU =  Q    ...
        ;// out FPU =  GQ   Q2     ...

        ;// G = Q
        ;// if Q < 1/sqrt(2) then G = 1

            fld st
            fadd st(1), st

        ENDM







;//////////////////////////////////////////////////////////////
;//
;//     iir_check_remaining     can be jumped to finish up a calc
;//


ALIGN 16
iir_check_remaining PROC

    ;// the FPU must have the value to fill with
    ;// the FPU must have the small value to compare with
    ;// those must be the ONLY values in the FPU

    ;// small Y0

    ;// ecx must have the index of the current sample
    ;// if it is zero, we will reset PIN CHANGING
    ;// otherwise will SET pin changing

        test ecx, ecx       ;// if ecx is not zero then we fill and set changing
        jnz fill_changing

        BITR [esi].pin_y.dwStatus, PIN_CHANGING
        jc fill_this        ;// previous frame was changing so we have to fill
                            ;// otherwise we check if the new value
                            ;// is significantly different
        fld Y0          ;// get current value
        fsub st, st(2)  ;// subtract new value
        fxch st(2)      ;// Y0 small dY
        fstp Y0         ;// small dY
        fxch            ;// dY    small
        fabs
        fucompp         ;// empty
        xor eax, eax
        fnstsw ax
        sahf
        ja have_to_fill

    ;// the difference value is to small to deal with
    ;// the previous frame was not changing
    ;// so we just exit

        jmp iir_calc_done

    fill_changing:

        or [esi].pin_y.dwStatus, PIN_CHANGING

    fill_this:

        fstp st
        fstp Y0

    have_to_fill:

        lea edi, [esi].data_y[ecx*4]
        mov eax, Y0
        sub ecx, SAMARY_LENGTH
        neg ecx
        rep stosd
        jmp iir_calc_done



iir_check_remaining ENDP

;//
;//     iir_check_remaining     can be jumped to finish up a calc
;//
;//////////////////////////////////////////////////////////////































;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
;///
;///
;///    C A L C S
;///
;///
;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////

.DATA
    ALIGN 8
        _1cp_temp_1    dd    0
    ALIGN 8
        _1cp_temp_2    dd    0
    ALIGN 8
.CODE

;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//
;//
;//     old 1cp and 1cz         note that the nomenclature is often WRONG
;//
;//


;// 1 POLE                  note:   b's are actually a's
;//                                 A is actually B0
;//
;// y = x*A + b1 * y1 + b2 * y2
;// b1 = 2 * R * cos( F )
;// b2 = - R * R
;// gain A = sqrt ( r * ( r - 4c2 + 2 ) + 1 ) * r-1

ALIGN 16
iir_build_params_1CP PROC

    ;// kludge for older version
    ;// load dumy params to avoid rewritting this section
    ;// we'll use these as parameters as required

        fld1    ;// Y1
        fldz    ;// Y2  Y1

    ;// caclulate the frequency

        math_Cos F0, _1cp_temp_1
        fld st
        fadd                    ;// 2c  y2      y1
        fxch                    ;// y2  2c      y1

    ;// auto gain or not

        .IF [esi].dwUser & IIR_AUTO_GAIN

            ;// uniy gain
            ;// A = sqrt ( r * ( r - (4c2-2) ) + 1 ) * r-1
            ;// b1 = 2*c*r
            ;// b2 = - r * r
            ;// y0 = A*x + b1*y1 + b2*y2

            fld L0              ;// R           y2      2c      y1
            fabs                ;// r           y2      2c      y1

            fld st              ;// r           r       y2      2c      y1
            fmul st(1), st      ;// r           r2      y2      2c      y1
            fld st(3)           ;// 2c      r       r2      y2      2c      y1
            fmul st, st(4)      ;// 4c2     r       r2      y2      2c      y1
            fsub math_2         ;// 4c2-2       r       r2      y2      2c      y1
            fsubr st, st(1)     ;// r-4c2+2 r       r2      y2      2c      y1
            fmul st, st(1)      ;// r(r-4c2+2   r       r2      y2      2c      y1
            fld1
            fadd
            fsqrt               ;// AA  r       r2      y2      2c      y1
            fxch                ;// r       AA      r2      y2      2c      y1
            fmul st(4), st      ;// r       AA      r2      y2      b1      y1
            fld1                ;// 1       r       AA      r2      y2      b1      y1
            fsub                ;// r-1 AA      r2      y2      b1      y1
            fmul                ;// A       r2      y2      b1      y1
            fchs
            fxch                ;// r2  A       y2      b1      y1
            fchs                ;// b2  A       y2      b1      y1
            fxch st(2)          ;// y2  A       b2      b1      y1

            ;// store parameters
            fst  B2 ;// = 0
            fstp B1 ;// = 0
            fstp B0 ;// = A
            fstp A2 ;// = b2
            fstp A1 ;// = b1
            fstp st ;// dont need

        .ELSE
            ;// no gain adjust      ;// y2  2c      y11

            fld L0                  ;// R       y2      2c      y1
            fabs                    ;// r       y2      2c      y1
            fmul st(2), st          ;// r       y2      b1      y1
            fld st                  ;// r       r       y2      b1      y1
            fmul                    ;// r2  y2      b1      y1
            fchs
            fxch                    ;// y2  b2      b1      y1

            fst  B2 ;// = 0
            fstp B1 ;// = 0
            fstp A2 ;// = b2
            fstp A1 ;// = b1
            fstp B0 ;// = 1

        .ENDIF


        ret

iir_build_params_1CP ENDP


ALIGN 16
IIR_dX_dF_sL_aG_1CP:
IIR_sX_dF_sL_aG_1CP:

        or [esi].pin_y.dwStatus, PIN_CHANGING

        ;// use unity gain
        ;// A = sqrt ( r * ( r - 4c2 + 2 ) + 1 ) * r-1
        ;// b1 = 2*r*c
        ;// b2 = -r*r   y0 = A*x + b1*y1 + b2*y2
        ;//
        ;// constants   trans           formula
        ;//  r          2c = 2*cos(F)   A = sqrt ( r * ( r - 4c2 + 2 ) + 1 ) * r-1
        ;//  r1 = r-1   4c2 = (2c)^2    y0 = A*X + r * ( y1 * 2c - r * y2 )

            fld Y1
            fld Y2

        ;// setup

            fld L0              ;// R       y2      y1
            fabs                ;// r       y2      y1
            fld1                ;// 1     r     y2      y1
            fsubr st, st(1)     ;// r1  r       y2      y1
            fxch st(2)          ;// y2  r       r1      y1

        .REPEAT

            math_Cos F0, _1cp_temp_1

            fld st              ;// c       c       y2      r       r1      y1
            fadd                ;// 2c  y2      r       r1      y1

            fxch                ;// y2  2c      r       r1      y1

            fmul st, st(2)      ;// y2r 2c      r       r1      y1

            fld math_2          ;// 2       y2r     2c      r       r1      y1
            fld st(2)           ;// 2c  2       y2r     2c      r       r1      y1

            fmul st, st(3)      ;// 4c2 2       y2r     2c      r       r1      y1
            fsubr               ;// 4c2-2   y2r     2c      r       r1      y1

            fxch st(2)          ;// 2c  y2r     4c2-2   r       r1      y1

            fmul st, st(5)      ;// 2cy1    y2r     4c2-2   r       r1      y1
            fld st(3)           ;// r       2cy1    y2r     4c2-2   r       r1      y1
            fsubrp st(3), st    ;// 2cy1    y2r     r-4c2+2 r       r1      y1

            fsubr               ;// 2cy1-y2r    r-4c2+2 r   r1      y1

            fxch                ;// r-4c2+2 2cy1-y2r    r       r1      y1

            fmul st, st(2)      ;// (a-1)   2cy1-y2r    r   r1      y1
            fld1                ;// 1       (a-1)   2cy1-y2r    r   r1      y1
            fxch st(3)          ;// 2cy1-y2r        (a-1)   1   r   r1      y1
            fmul st, st(3)      ;// YY  (a-1)   1       r       r1      y1
            fxch st(3)          ;// 1       (a-1)   YY      r       r1      y1
            fadd                ;// a       YY      r       r1      y1
            fsqrt               ;// aa  YY      r       r1      y1
            fmul st, st(3)      ;// A     YY      r       r1        y1
            fxch                ;// YY  A       r       r1      y1
            fmul st, st(2)      ;// yy  A       r       r1      y1
            fxch                ;// A       yy      r       r1      y1
            fchs
            fmul X0             ;// AX  yy      r       r1      y1
            fadd                ;// Y0  r       r1      y1

            CLIPTEST_ONE iir_clip

            fst  Y0             ;// y0  r       r1      y1
            inc ecx
            fxch st(3)          ;// y1  r       r1      y0

        .UNTIL ecx >= SAMARY_LENGTH

        fxch st(2)              ;// r1  r       y1      y0

        fstp st
        fstp st
        fstp st
        fstp st
        jmp iir_calc_done


ALIGN 16
IIR_dX_dF_sL_nG_1CP:
IIR_sX_dF_sL_nG_1CP:

        or [esi].pin_y.dwStatus, PIN_CHANGING

        fld Y1
        fld Y2

        ;// no gain adjust
        ;//

        fld  L0
        fabs
        fld  st
        fmul st, st(1)          ;// r2  r       y2      y1
        fchs                    ;// -r2 r       y2      y1

        .REPEAT

            math_Cos F0, _1cp_temp_1
            fld st
            fadd                ;// 2c  -r2     r       y2      y1
            fmul st, st(2)      ;// 2cR -r2     r       y2      y1

            fxch                ;// -r2 2cR     r       y2      y1
            fmul st(3), st      ;// -r2 2cR     r       y2cR    y1
            fld X0              ;// X       -r2     2cr     R       y2cR    y1
            fxch st(2)          ;// 2cR -r2     X       R       y2cR    y1
            fmul st, st(5)      ;// y12cR   -r2     X       R       y2cR    y1
            fxch st(2)          ;// X       -r2     y12cr   R       y2cR    y1
            faddp st(4), st     ;// -r2 y12cR   r       Xy2cr   y1
            fxch                ;// y12cR   -r2     r       Xy2cr   y1
            faddp st(3), st     ;// -r2 r       y0      y1
            fxch st(2)          ;// y0  r       -r2     y1

            CLIPTEST_ONE iir_clip

            fst Y0              ;// y0  R       -r2     y1

            inc ecx             ;// -r2   R       y2      y1

            fxch st(3)          ;// y1    R       -r2     y0
            fxch st(2)          ;// -r2 R       y1      y0


        .UNTIL ecx >= SAMARY_LENGTH

        fstp st
        fstp st
        fstp st
        fstp st
        jmp iir_calc_done

ALIGN 16
IIR_dX_dF_dL_aG_1CP:
IIR_sX_dF_dL_aG_1CP:

        or [esi].pin_y.dwStatus, PIN_CHANGING

        fld Y1
        fld Y2

        ;// use unity gain
        ;// A = sqrt ( r^2 - r*(4c^2-2) + 1  ) * (r-1)
        ;// b1 = 2*r*c
        ;// b2 = - r*r

        .REPEAT

            math_Cos F0, _1cp_temp_1
            fld st
            fadd                ;// 2c  y2      y1
            fld st              ;// 2c  2c      y2      y1
            fmul st(1), st      ;// 2c  4c^2    y2      y1

            fld  L0             ;// R       2c      4c^2    y2      y1
            fabs                ;// r       2c      4c^2    y2      y1
            fld st              ;// r       r       2c      4c^2    y2      y1

            fmul st(1), st      ;// r       r^2     2c      4c^2    y2      y1
            fxch st(3)          ;// 4c^2    r^2     2c      r       y2      y1
            fsub math_2         ;// 4c2-1   r^2     2c      r       y2      y1
            fxch st(2)          ;// 2c  r^2     4c2-2   r       y2      y1
            fmul st, st(3)      ;// 2cr r^2     4c2-2   r       y2      y1
            fld st(5)           ;// y1  2cr r^2 4c2-2   r       y2      y1
            fmul                ;// 2cry1   r^2     4c2-2   r       y2      y1
            fxch                ;// r^2 2cry1   4c2-2   r       y2      y1
            fmul st(4), st      ;// r^2 2cry1   4c2-2   r       y2r^2   y1
            fxch st(3)          ;// r   2cry1   4c2-2   r^2     y2r^2   y1
            fabs                ;// R       2cry1   4c2-2   r^2     y2r^2   y1
            fmul st(2), st      ;// R       2cry1   4c2-2)R r^2     y2r^2   y1
            fsub math_1         ;// R-1 2cry1   4c2-2)R r^2     y2r^2   y1
            fxch                ;// 2cry1   R-1     4c2-2)R r^2     y2r^2   y1
            fsubrp st(4), st    ;// R-1 4c2-2)R r^2     by1by2  y1
            fxch st(2)          ;// r^2 4c2-2)R R-1     by1by2  y1
            fsubr               ;// r^2-4c2+2)R R-1     by1by2  y1
            fadd math_1
            fsqrt
            fmul                ;// A       by1by2  y1
            fchs
            fmul X0             ;// AX
            fadd                ;// y0  y1

            CLIPTEST_ONE iir_clip

            fst Y0              ;// y0  y1
            inc ecx             ;// y2      y1
            fxch                ;// y1    y0

        .UNTIL ecx >= SAMARY_LENGTH

        fstp st
        fstp st
        jmp iir_calc_done


ALIGN 16
IIR_dX_dF_dL_nG_1CP:
IIR_sX_dF_dL_nG_1CP:

        or [esi].pin_y.dwStatus, PIN_CHANGING

    ;//y = x + b1 * y1 + b2 * y2
    ;// b1 = 2 * R * cos( F )
    ;// b2 = - R * R

        fld Y1
        fld Y2

        ;// no gain adjust
        ;// y0 = x + r * ( 2c * y1 - r * y2 )

        .REPEAT

            math_Cos F0, _1cp_temp_1
            fld st
            fadd                ;// 2c  y2      y1

            fld L0              ;// R       2c      y2      y1
            fabs                ;// r       2c      y2      y1
            fxch                ;// 2c  r       y2      y1
            fmul st, st(3)      ;// 2cy1    r       y2      y1
            fxch st(2)          ;// y2  r       2cy1    y1
            fmul st, st(1)      ;// ry2 r       2cy1    y1
            fsubp st(2), st     ;// r     yy        y1
            fmul                ;// YY  y1
            fadd X0             ;// y0  y1

            ;// now we clip this at +,- 1

            CLIPTEST_ONE iir_clip

            fst Y0              ;// y0  y1
            inc ecx             ;// y2    y1
            fxch                ;// y1    y0

        .UNTIL ecx >= SAMARY_LENGTH

        fstp st
        fstp st
        jmp iir_calc_done


ALIGN 16
IIR_dX_sF_sL_aG_1CP:
IIR_sX_sF_sL_aG_1CP:

        or [esi].pin_y.dwStatus, PIN_CHANGING

        ;// use uniy gain
        ;// A = sqrt ( r * ( r - (4c2-2) ) + 1 ) * r-1
        ;// b1 = 2*c*r
        ;// b2 = - r * r
        ;// y0 = A*x + b1*y1 + b2*y2

            fld Y1
            fld Y2

            math_Cos F0, _1cp_temp_1
            fld st
            fadd                    ;// 2c  y2      y1
            fxch                    ;// y2  2c      y1

        ;// setup               ;// y2      2c      y12

            fld L0              ;// R           y2      2c      y1
            fabs                ;// r           y2      2c      y1

            fld st              ;// r           r       y2      2c      y1
            fmul st(1), st      ;// r           r2      y2      2c      y1
            fld st(3)           ;// 2c      r       r2      y2      2c      y1
            fmul st, st(4)      ;// 4c2     r       r2      y2      2c      y1
            fsub math_2         ;// 4c2-2       r       r2      y2      2c      y1
            fsubr st, st(1)     ;// r-4c2+2 r       r2      y2      2c      y1
            fmul st, st(1)      ;// r(r-4c2+2   r       r2      y2      2c      y1
            fld1
            fadd
            fsqrt               ;// AA  r       r2      y2      2c      y1
            fxch                ;// r       AA      r2      y2      2c      y1
            fmul st(4), st      ;// r       AA      r2      y2      b1      y1
            fld1                ;// 1       r       AA      r2      y2      b1      y1
            fsub                ;// r-1 AA      r2      y2      b1      y1
            fmul                ;// A       r2      y2      b1      y1
            fchs
            fxch                ;// r2  A       y2      b1      y1
            fchs                ;// b2  A       y2      b1      y1
            fxch st(2)          ;// y2  A       b2      b1      y1


        .REPEAT                 ;// y2  A       b2      b1      y1

            fmul st, st(2)      ;// b2y2    A       b2      b1      y1
            fld st(4)           ;// y1      b2y2    A       b2      b1      y1
            fmul st, st(4)      ;// b1y1    b2y2    A       b2      b1      y1
            fld X0              ;// X   b1y1    b2y2    A       b2      b1      y1
            fmul st, st(3)      ;// AX      b1y1    b2y2    A       b2      b1      y1
            fxch st(2)          ;// b2y2    b1y1    AX      A       b2      b1      y1
            fadd                ;// YY      AX      A       b2      b1      y1
            fadd                ;// y0      A       b2      b1      y1

            CLIPTEST_ONE iir_clip

            fst Y0              ;// y0  A       b2      b1      y1

            inc ecx             ;// y2  A       b2      b1      y1
            fxch st(4)          ;// y1  A       b2      b1      y0

        .UNTIL ecx >= SAMARY_LENGTH

        fxch st(3)          ;// b1  A       b2      y2      y1
        fstp st             ;// A       b2      y2      y1

        fstp st
        fstp st

        fstp st
        fstp st
        jmp iir_calc_done



ALIGN 16
IIR_dX_sF_sL_nG_1CP:
IIR_sX_sF_sL_nG_1CP:

        or [esi].pin_y.dwStatus, PIN_CHANGING

        fld Y1
        fld Y2

        math_Cos F0, _1cp_temp_1
        fld st
        fadd                    ;// 2c  y2      y1
        fxch                    ;// y2  2c      y1

        ;// no gain adjust      ;// y2  2c      y11

        fld L0                  ;// R       y2      2c      y1
        fabs                    ;// r       y2      2c      y1
        fmul st(2), st          ;// r       y2      b1      y1
        fld st                  ;// r       r       y2      b1      y1
        fmul                    ;// r2  y2      b1      y1
        fchs
        fxch                    ;// y2  b2      b1      y1

        .REPEAT                 ;// y2  b2      b1      y1

            fmul st, st(1)      ;// b2y2    b2      b1      y1
            fld st(3)           ;// y1  b2y2    b2      b1      y1
            fmul st, st(3)      ;// b1y1    b2y2    b2      b1      y1
            fxch                ;// b2y2    b1y1    b2      b1      y1
            fadd X0             ;// b2y2+x  b1y1    b2      b1      y1
            fadd                ;// y0  b2      b1      y1

            CLIPTEST_ONE iir_clip

            fst Y0              ;// y0  b2      b1      y1

            inc ecx             ;// y2  b2      b1      y1
            fxch st(3)          ;// y1  b2      b1      y0

        .UNTIL ecx >= SAMARY_LENGTH

        fxch st(2)          ;// b1  b2      y2      y1

        fstp st
        fstp st

        fstp st
        fstp st
        jmp iir_calc_done



ALIGN 16
IIR_dX_sF_dL_aG_1CP:
IIR_sX_sF_dL_aG_1CP:

        or [esi].pin_y.dwStatus, PIN_CHANGING

            fld Y1
            fld Y2

            math_Cos F0, _1cp_temp_1
            fld st
            fadd                    ;// 2c  y2      y1
            fxch                    ;// y2  2c      y1

        ;// use unity gain
        ;// A = sqrt ( r * ( r - (4c2-2) ) + 1 ) * r-1
        ;// y0 = A*x + r * ( 2c*y1 - r*y2 )

        ;// set up          ;// y2  2c      y1 - r*y2 )

            fld st(1)       ;// 2c  y2      2c      y1
            fmul st, st(2)  ;// 4c2 y2      2c      y1
            fsub math_2     ;// 4c22    y2      2c      y1
            fxch            ;// y2  4c22    2c      y1

        .REPEAT

            fld L0          ;// R       y2      4c22    2c      y1
            fabs            ;// r       y2      4c22    2c      y1
            fmul st(1), st  ;// r       ry2     4c22    2c      y1
            fld1            ;// 1     r     ry2     4c22    2c      y1
            fsubr st, st(1) ;// r1  r       ry2     4c22    2c      y1
            fld1            ;// 1     r1        r       ry2     4c22    2c      y1
            fld st(5)       ;// 2c  1       r1      r       ry2     4c22    2c      y1
            fmul st,st(7)   ;// 2cy1    1       r1      r       ry2     4c22    2c      y1
            fsubrp st(4), st;// 1       r1      r       yy      4c22    2c      y1
            fld st(2)       ;// r       1       r1      r       yy      4c22    2c      y1
            fmul st(4), st  ;// r       1       r1      r       YY      4c22    2c      y1
            fsub st, st(5)  ;// r-4c    1       r1      r       YY      4c22    2c      y1
            fmulp st(3), st ;// 1       r1      aa      YY      4c22    2c      y1
            faddp st(2), st ;// r1  AA      YY      4c22    2c      y1
            fxch            ;// AA  r1      YY      4c22    2c      y1
            fsqrt           ;//
            fmul            ;// A       YY      4c22    2c      y1
            fchs
            fmul X0         ;// AX
            fadd            ;// y0  4c22    2c      y1

            CLIPTEST_ONE iir_clip

            fst Y0          ;// y0  4c22    2c      y1
            fxch st(3)      ;// y1  4c22    2c      y2

            inc ecx         ;// y2  4c22    2c      y1

        .UNTIL ecx >= SAMARY_LENGTH

        fxch st(2)      ;// 2c  4c22    y2      y1
        fstp st
        fstp st
        fstp st
        fstp st
        jmp iir_calc_done


ALIGN 16
IIR_dX_sF_dL_nG_1CP:
IIR_sX_sF_dL_nG_1CP:

        or [esi].pin_y.dwStatus, PIN_CHANGING

            fld Y1
            fld Y2

            math_Cos F0, _1cp_temp_1
            fld st
            fadd                    ;// 2c  y2      y1
            fxch                    ;// y2  2c      y1

        ;// no gain adjust
        ;// y0 = x + r * ( 2c*y1 - r * y2 )

        .REPEAT                 ;// y2  2c      y1

            fld L0              ;// R       y2      2c      y1
            fabs                ;// r       y2      2c      y1

            fmul st(1), st      ;// r       ry2     2c      y1

            fld st(3)           ;// y1  r       ry2     2c      y1
            fmul st, st(3)      ;// 2cy1    r       ry2     2c      y1
            fsubrp st(2), st    ;// r       yy      2c      y1
            fmul
            fadd X0             ;// y0  2c      y1

            CLIPTEST_ONE iir_clip

            fst Y0              ;// y0  2c      y1

            inc ecx             ;// y2  2c      y1
            fxch st(2)          ;// y1  2c      y0

        .UNTIL ecx >= SAMARY_LENGTH

        fxch                ;// 2c  y2      y1
        fstp st
        fstp st
        fstp st
        jmp iir_calc_done









;// 1 ZERO                          note: old nomenclature is wrong
;//                                       a's should be B's
;//  y = A( x0 + b1*x1 + b2*x2 )
;//   a1 = - 2 * r * cos( F )
;//   a2 = r * r
;//
;// unity gain
;// A = 1 / ( |a1| + a2 + 1 )


ALIGN 16
iir_build_params_1CZ PROC

    ;// load dummy params to prevent rewrite
    ;// we'll use these as store parameters as well

        fld1    ;//  X1
        fldz    ;//  X2


            math_Cos F0, _1cp_temp_1
            fadd st, st             ;// 2c  x2      x1
            fxch                    ;// x2  2c      x1

            fld L0                  ;// R       x2      2c      x1
            fabs                    ;// r       x2      2c      x1
            fmul st(2), st          ;// r       x2      2cr     x1
            fld st
            fmul                    ;// a2  x2      2cr     x1
            fxch st(2)              ;// 2cr x2      a2      x1
            fchs                    ;// a1  x2      a2      x1
            fxch                    ;// x2  a1      a2      x1


        .IF [esi].dwUser & IIR_AUTO_GAIN
        ;// use gain adjust

        ;// setup           ;// x2  a1      a2      x1

            fld st(1)       ;// a1  x2      a1      a2      x1
            fabs
            fld1            ;// 1       a1      x2      a1      a2      x1
            fxch            ;// a1  1       x2      a1      a2      x1
            fadd st, st(4)  ;// a1+b1   1       x2      a1      a2      x1
            fadd st, st(1)  ;// 1/A 1       x2      a1      a2      x1
            fdiv            ;// A       x2      a1      a2      x1
            fxch            ;// x2  A       a1      a2      x1

            fst  A1 ;// = 0
            fstp A2 ;// = 0     ;// A       a1      a2      x1
            fmul st(1), st
            fmul st(2), st
            fstp B0
            fstp B1
            fstp B2
            fstp st

        .ELSE

            ;// no gain adjust      ;// x2  a1      a2      x1

            fst  A1 ;// = 0
            fstp A2 ;// = 0
            fstp B1 ;// = a1
            fstp B2 ;// = a2
            fstp B0 ;// = 1

        .ENDIF

        ret

iir_build_params_1CZ ENDP




ALIGN 16
IIR_dX_dF_sL_aG_1CZ:
IIR_sX_dF_sL_aG_1CZ:

        or [esi].pin_y.dwStatus, PIN_CHANGING

        fld X2
        fld X1

        fld L0              ;// R       x2      x1
        fabs                ;// r       x2      x1
        fxch                ;// x2    r     x1

        .REPEAT                     ;// ( x0 + r * ( x1*2c - x2*r ) )
                                    ;// -----------------------------
                                    ;//    ( r * ( |2c| + r ) + 1 )

            fmul st, st(1)          ;// rx2 x2      r       x1

            math_Cos F0, _1cp_temp_1
            fld st
            fadd                    ;// 2c  rx2     r       x1

            fld st                  ;// 2c  2c      rx2     r       x1
            fmul st, st(4)          ;// 2cx1    2c      rx2     r       x1

            fld X0                  ;// x0  2cx1    2c      rx2     r       x1
            fxch st(3)              ;// rx2 2cx1    2c      x0      r       x1
            fsubr                   ;// rx2-2cx1    2c  x0      r       x1
            fxch                    ;// 2c  rx2-2cx1 x0     r       x1
            fabs
            fadd st, st(3)          ;// 2c+r    rx2-2cx1 x0     r       x1
            fxch                    ;// rx2-2cx1 2c+r   x0      r       x1
            fmul st, st(3)          ;// xx  2c+r    x0      r       x1
            fld1                    ;// 1       xx      2c+r    x0      r       x1
            fxch st(2)              ;// 2c+r    xx      1       x0      r       x1
            fmul st, st(4)          ;// aa  xx      1       x0      r       x1
            fxch                    ;// xx  aa      1       x0      r       x1
            fadd st, st(3)          ;// Y0  aa      1       x0      r       x1
            fxch st(2)              ;// 1       aa      Y0      x0      r       x1
            fadd                    ;// 1/A Y0      X0      r       x1
            fdiv                    ;// y0  X0      r       x1

            CLIPTEST_ONE iir_clip

            fstp Y0                 ;// x0  r       x1
            inc ecx                 ;// x2  r       x1
            fxch st(2)              ;// x1  r       x0

        .UNTIL ecx >= SAMARY_LENGTH

        fstp X2
        fstp st
        fstp X1
        jmp iir_calc_done

ALIGN 16
IIR_dX_dF_sL_nG_1CZ:
IIR_sX_dF_sL_nG_1CZ:

        or [esi].pin_y.dwStatus, PIN_CHANGING

        fld X2
        fld X1

        fld L0              ;// R       x2      x1
        fabs                ;// r       x2      x1
        fxch                ;// x2    r     x1

        ;// no gain adjust          ;// x2  r       x1  r       x1

        .REPEAT                     ;// x0 + r * ( x1*2c - x2*r )

            math_Cos F0, _1cp_temp_1
            fld st
            fadd                    ;// 2c  x2      r       x1

            fxch                    ;// x2    2c        r       x1
            fmul st, st(2)          ;// rx2 2c      r       x1
            fld X0                  ;// x0  rx2     2c      r       x1
            fxch st(2)              ;// 2c  rx2     x0      r       x1
            fmul st, st(4)          ;// 2cx1    rx2     x0      r       x1
            fsub                    ;// rx2-2cx1    x0  r       x1
            fmul st, st(2)
            fadd st, st(1)          ;// y0  x0      r       x1

            CLIPTEST_ONE iir_clip

            fstp Y0                 ;// x0  r       x1
            inc ecx                 ;// x2  r       x1
            fxch st(2)              ;// x1  r       x0

        .UNTIL ecx >= SAMARY_LENGTH

        fstp X2
        fstp st
        fstp X1
        jmp iir_calc_done


ALIGN 16
IIR_dX_dF_dL_aG_1CZ:
IIR_sX_dF_dL_aG_1CZ:

        or [esi].pin_y.dwStatus, PIN_CHANGING

        fld X2
        fld X1

        .REPEAT                     ;// ( x0 + r * ( x1*2c - x2*r ) )
                                    ;// -----------------------------
                                    ;//    ( r * ( 2c + r ) + 1 )

                                    ;// x2      x1

            math_Cos F0, _1cp_temp_1
            fld st
            fadd                    ;// 2c  x2      x1

            fld L0                  ;// R       2c      x2      x1
            fabs                    ;// r     2c        x2      x1

            fmul st(2), st          ;// r     2c        x2r     x1
            fld st(1)               ;// 2c  r       2c      x2r     x1
            fabs
            fadd st, st(1)          ;// 2c+r    r       2c      x2r     x1
            fxch st(2)              ;// 2c    r     2c+r    x2r     x1
            fmul st, st(4)          ;// 2cx1  r     2c+r    x2r     x1
            fld X0                  ;// x0  2cx1    r       2c+r    x2r     x1
            fxch st(4)              ;// x2r 2cx1    r       2c+r    x0      x1
            fsubr                   ;// x2r-2cx1    r   2c+r    x0      x1
            fxch                    ;// r       x2r-2cx1    2c+r    x0      x1
            fmul st(2), st          ;// r       x2r-2cx1    aa-1    x0      x1
            fld1                    ;// 1       r       x2r-2cx1    aa-1    x0      x1
            fxch                    ;// r       1       x2r-2cx1    aa-1    x0      x1
            fmulp st(2), st         ;// 1       xx      aa-1    x0      x1
            faddp st(2), st         ;// xx    1/A       x0      x1
            fadd st, st(2)          ;// Y0  1/A     x0      x1
            fdivr                   ;// y0  x0      x1

            CLIPTEST_ONE iir_clip

            fstp Y0                 ;// x0  x1
            inc ecx                 ;// x2  x1
            fxch                    ;// x1  x0

        .UNTIL ecx >= SAMARY_LENGTH


        fstp X2
        fstp X1
        jmp iir_calc_done

ALIGN 16
IIR_dX_dF_dL_nG_1CZ:
IIR_sX_dF_dL_nG_1CZ:

        or [esi].pin_y.dwStatus, PIN_CHANGING

        fld X2
        fld X1

        .REPEAT                     ;// x0 + r * ( x1*2c - x2*r )

            math_Cos F0, _1cp_temp_1
            fadd st, st             ;// 2c  x2      x1

            fld L0                  ;// R       2c      x2      x1
            fxch                    ;// 2c  R       x2      x1

            fmul st, st(3)          ;// 2cx1    R       x2      x1
            fxch                    ;// R       2cx1    x2      x1
            fabs                    ;// r       2cx1    x2      x1
            fmul st(2), st          ;// r     2cx1  rx2     x1

            fld X0                  ;// x0  r       2cx1    rx2     x1
            fxch st(3)              ;// rx2 r       2cx1    x0      x1
            fsubrp st(2), st        ;// r       rx2-2cx1    x1      x1
            fmul
            fadd st, st(1)          ;// y0  x0      x1

            CLIPTEST_ONE iir_clip

            fstp Y0                 ;// x0  x1
            inc ecx                 ;// x2  x1
            fxch                    ;// x1  x0

        .UNTIL ecx >= SAMARY_LENGTH

        fstp X2
        fstp X1
        jmp iir_calc_done






ALIGN 16
IIR_dX_sF_sL_aG_1CZ:
IIR_sX_sF_sL_aG_1CZ:

        or [esi].pin_y.dwStatus, PIN_CHANGING

        fld X2
        fld X1

            math_Cos F0, _1cp_temp_1
            fadd st, st             ;// 2c  x2      x1
            fxch                    ;// x2  2c      x1

            fld L0                  ;// R       x2      2c      x1
            fabs                    ;// r       x2      2c      x1
            fmul st(2), st          ;// r       x2      2cr     x1
            fld st
            fmul                    ;// a2  x2      2cr     x1
            fxch st(2)              ;// 2cr x2      a2      x1
            fchs                    ;// a1  x2      a2      x1
            fxch                    ;// x2  a1      a2      x1
        ;// use gain adjust

        ;// setup           ;// x2  a1      a2      x1x1

            fld st(1)       ;// a1  x2      a1      a2      x1
            fabs
            fld1            ;// 1       a1      x2      a1      a2      x1
            fxch            ;// a1  1       x2      a1      a2      x1
            fadd st, st(4)  ;// a1+b1   1       x2      a1      a2      x1
            fadd st, st(1)  ;// 1/A 1       x2      a1      a2      x1
            fdiv            ;// A       x2      a1      a2      x1
            fxch            ;// x2  A       a1      a2      x1

        .REPEAT

            fmul st, st(3)  ;// a2x2    A       a1      a2      x1
            fld X0          ;// x0  a2x2    A       a1      a2      x1
            fld st(5)       ;// x1  x0      a2x2    A       a1      a2      x1
            fmul st, st(4)  ;// a1x1    x0      a2x2    A       a1      a2      x1

            fxch            ;// x0  a1x1    a2x2    A       a1      a2      x1
            fadd st(2), st  ;// x0  a1x1    a2x2+x0 A       a1      a2      x1
            fxch st(2)
            fadd            ;// Y       x0      A       a1      a2      x1
            fmul st, st(2)  ;// y0  x0      A       a1      a2      x1

            CLIPTEST_ONE iir_clip

            fstp Y0         ;// x0  A       a1      a2      x1
            inc ecx         ;// x2  A       a1      a2      x1
            fxch st(4)      ;// x1  A       a1      a2      x0

        .UNTIL ecx >= SAMARY_LENGTH

        fstp X2
        fstp st
        fstp st
        fstp st
        fstp X1
        jmp iir_calc_done


ALIGN 16
IIR_dX_sF_sL_nG_1CZ:
IIR_sX_sF_sL_nG_1CZ:

        or [esi].pin_y.dwStatus, PIN_CHANGING

        fld X2
        fld X1

        ;// no gain adjust      ;// x2  a1      a2      x1x1

        math_Cos F0, _1cp_temp_1
        fld st
        fadd                    ;// 2c  x2      x1
        fxch                    ;// x2  2c      x1

        fld L0                  ;// R       x2      2c      x1
        fabs                    ;// r       x2      2c      x1
        fmul st(2), st          ;// r       x2      2cr     x1
        fld st
        fmul                    ;// a2  x2      2cr     x1
        fxch st(2)              ;// 2cr x2      a2      x1
        fchs                    ;// a1  x2      a2      x1
        fxch                    ;// x2  a1      a2      x1
        .REPEAT

            fmul st, st(2)          ;// a2x2    a1      a2      x1
            fld X0                  ;// x0  a2x2    a1      a2      x1
            fld st(4)               ;// x1  x0      a2x2    a1      a2      x1
            fmul st, st(3)          ;// a1x1    x0      a2x2    a1      a2      x1

            fxch                    ;// x0  a1x1    a2x2    a1      a2      x1
            fadd st(2), st          ;// x0  a1x1    a2x2+x0 a1      a2      x1
            fxch st(2)
            fadd                    ;// Y       x0      a1      a2      x1

            CLIPTEST_ONE iir_clip

            fstp Y0              ;// x0 a1      a2      x1
            inc ecx             ;// x2  a1      a2      x1
            fxch st(3)          ;// x1  a1      a2      x0

        .UNTIL ecx >= SAMARY_LENGTH

        fstp X2
        fstp st
        fstp st
        fstp X1
        jmp iir_calc_done


ALIGN 16
IIR_sX_sF_dL_aG_1CZ:
IIR_dX_sF_dL_aG_1CZ:

        or [esi].pin_y.dwStatus, PIN_CHANGING

        fld X2
        fld X1

        math_Cos F0, _1cp_temp_1
        fld st
        fadd                    ;// 2c  x2      x1
        fxch                    ;// x2  2c      x1

        .REPEAT                     ;// ( x0 + r * ( x1*2c - x2*r ) )
                                    ;// -----------------------------
                                    ;//    ( r * ( |2c| + r ) + 1 )

            fld L0                  ;// R       x2      2c      x1
            fabs                    ;// r       x2      2c      x1

            fmul st(1), st          ;// r       x2r     2c      x1

            fld st(3)               ;// x1  r       x2r     2c      x1
            fmul st, st(3)          ;// 2cx1    r       x2r     2c      x1
            fsubp st(2), st         ;// r       2cx1-x2r 2c     x1
            fmul st(1), st          ;// r       xx      2c      x1
            fld st(2)               ;// 2c  r       xx      2c      x1
            fabs
            fadd st, st(1)          ;// 2c+r    r       xx      2c      x1
            fld1                    ;// 1       2c+r    r       xx      2c      x1
            fxch st(2)              ;// r       2c+r    1       xx      2c      x1
            fmul                    ;// 2crr2   1       xx      2c      x1
            fld X0                  ;// x0  2crr2   1       xx      2c      x1
            fadd st(3), st          ;// x0  2crr2   1       Y0      2c      x1
            fxch st(3)              ;// Y0  2crr2   1       x0      2c      x1
            fxch st(2)              ;// 1       2crr2   Y0      x0      2c      x1
            fadd                    ;// 1/A Y0      x0      2c      x1
            fdiv                    ;// y0  x0      2c      x1

            CLIPTEST_ONE iir_clip

            fstp Y0                 ;// x0  2c      x1
            inc ecx                 ;// x2  2c      x1
            fxch st(2)              ;// x1  2c      x0

        .UNTIL ecx >= SAMARY_LENGTH

        fstp X2
        fstp st
        fstp X1
        jmp iir_calc_done

ALIGN 16
IIR_sX_sF_dL_nG_1CZ:
IIR_dX_sF_dL_nG_1CZ:

        or [esi].pin_y.dwStatus, PIN_CHANGING

        fld X2
        fld X1

        math_Cos F0, _1cp_temp_1
        fadd st, st         ;// 2c  x2      x1
        fxch                ;// x2  2c      x1
        .REPEAT             ;// x0 + r * ( x1*2c - x2*r )

            fld L0          ;// R       x2      2c      x1
            fabs            ;// r       x2      2c      x1

            fmul st(1), st  ;// r       x2r     2c      x1

            fld st(3)       ;// x1  r       x2r     2c      x1
            fmul st, st(3)  ;// 2cx1    r       x2r     2c      x1
            fsubp st(2), st ;// r       2cx1-x2r 2c     x1
            fmul            ;// xx  2c      x1
            fld X0          ;// x0  xx      2c      x1
            fxch            ;// xx    x0        2c      x1
            fadd st, st(1)  ;// y0  x0      2c      x1

            CLIPTEST_ONE iir_clip

            fstp Y0         ;// x0  2c      x1
            inc ecx         ;// x2  2c      x1
            fxch st(2)      ;// x1  2c      x0

        .UNTIL ecx >= SAMARY_LENGTH

        fstp X2
        fstp st
        fstp X1
        jmp iir_calc_done





;//
;//
;//     old 1cp and 1cz
;//
;//
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////





;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//
;//
;//
;//     1st order filters
;//


;// parameter building

ALIGN 16
iir_build_params_LP1 PROC

    ;// A0 = 1+cos+sin
    ;// A1 = 1+cos-sin / A0
    ;// B0 = sin / A0

        iir_LookupSinCos;// cf      sf
        fadd math_1     ;// cf+1    sf

        fld st(1)       ;// sf      cf+1    sf
        fadd st, st(1)  ;// A0

        fxch st(2)      ;// sf      cf+1    A0
        fsub st(1), st  ;// sf      a1      A0

        fld math_1      ;// 1       sf      a1      A0
        fdivrp st(3), st;// sf      a1      _A0

        fmul st, st(2)  ;// B0
        fxch
        fmulp st(2), st ;// B0      A1

        fst B0
        fstp B1
        fstp A1

        xor eax, eax
        mov A2, eax
        mov B2, eax

        ret

iir_build_params_LP1 ENDP

ALIGN 16
iir_build_params_HP1 PROC

    ;// A0 = 1+cos+sin
    ;// A1 = 1+cos-sin / A0
    ;// B0 = 1+cos / A0

        iir_LookupSinCos;// cf  sf
        fadd math_1     ;// cf+1    sf
        fld st(1)       ;// sf      cf+1    sf
        fadd st, st(1)  ;// A0      cf+1    sf
        fxch st(2)      ;// sf      cf+1    A0
        fsubr st,st(1)  ;// a1      cf+1    A0
        fld math_1      ;// 1       a1      cf+1    A0
        fdivrp st(3),st ;// a1      cf+1    _A0
        fmul st, st(2)  ;// A1      cf+1    _A0
        fxch            ;// cf+1    A1      _A0
        fmulp st(2), st ;// A1      B0
        fstp A1
        fst B0
        fchs
        fstp B1

        xor eax, eax
        mov A2, eax
        mov B2, eax

        ret

iir_build_params_HP1 ENDP



    ;// this macro checks the static params
    ;// fall through is have to build
    ;// label jumps to don_have_to_build

    IIR_CHECK_PARAMS_1 MACRO label:req

            LOCAL have_to_build

            BITR [esi].dwUser, IIR_NEED_UPDATE      ;// carry flag set if flag was on
            mov eax, F0
            jc have_to_build
            cmp eax, [esi].pin_f.dwUser
            je label

        have_to_build:

            mov [esi].pin_f.dwUser, eax

        ENDM



    ;// these two macros define a test block for cliptesting


    IIR_1_CLIPTEST MACRO

        ;// fpu must be set as  Y0 1

            fld st          ;// y0  1
            fabs
            fucomp st(2)    ;// do the test, flush both values
            xor eax, eax
            fnstsw  ax  ;// xfer results to ax
            sahf        ;// xfer results to flags

            ja we_clipped

        clip_done:

        ENDM


    IIR_1_CLIPTEST_FIX MACRO

        ALIGN 16
        we_clipped:

            ;// we clipped  ;// Y0 1

            ftst        ;// check the sign
            xor eax, eax
            fnstsw ax   ;// xfer to ax
            fstp st     ;// dump the value
            sahf        ;// xfer results to flags
            fld st      ;// load the staturate value
            inc iir_clip    ;// set it
            jnc clip_done
            fchs        ;// make it pos
            jmp clip_done

        ENDM


.CODE



ALIGN 16
IIR_sX_sF_LP1 PROC

    ;// make sure we have current parameters

        IIR_CHECK_PARAMS_1 params_ok

            invoke iir_build_params_LP1

        params_ok:

    ;// if the first two values are different we do extra work
    ;// but we want to assume they are the same
        mov eax, X1        ;// X1 = last input from previous frame
            fld X0        ;// X0
            fadd st, st        ;// 2X0
        cmp eax, X0        ;// X1 same value as first input of this frame ?
            fmul B0         ;// X00
            fld math_1      ;// 1   X00
        .IF ZERO?        ;// same value:: therefore same output Y1
            fld Y1          ;// Y1  1   X00
            jmp IIR_sX_sF_LP1_enter
        .ENDIF
    ;// otherwise build the first value by hand

        fld X1              ;// X1  1   X00
        fadd X0
        fmul B0
        fld Y1
        fmul A1
        fadd                ;// Y0  1   X00
        ;// jmp IIR_sX_sF_LP1_top -- fall into next section

        ;//ABOX242 -- bug here
        ;// if the first sample (ecx=0) it too small we will never be able to fill the entire frame
        ;// so we have to jump to a test that checks the first sample .....
        ;// AND we should check all other filter incarnations that use a similar scheme
        ;//        only HP1 ... 1CP and 1CZ still need help ...
        ;// try to fix thusly -- don't fall into _top, instead, jmp to the test
        ;// seems to work ....
        fld Y1                ;// Y1    Y0    1    X00
        jmp IIR_sX_sF_LP1_enter_0

    ;//
    ;// iir_sX_sF_LP1.asm      generated by FpuOpt3 from iir_sX_sF_LP1.txt
    ;//
    ALIGN 16
    IIR_sX_sF_LP1_top:

        IIR_1_CLIPTEST

        fst Y0       ;//

        inc ecx
        cmp ecx, SAMARY_LENGTH
        jae IIR_sX_sF_LP1_done

    IIR_sX_sF_LP1_enter:    ;// Y1  1   X00
    ;
    ; X00 = (X0+X0)*B0
    ; Y0 = A1*Y1 + X00
    ; do until Y0 = Y1

        fld st          ;// Y1  Y1  1   X00
        fmul A1
        fadd st, st(3)  ;// Y0  Y1  1   X00
        fxch            ;// Y1  Y0  1   X00

    IIR_sX_sF_LP1_enter_0:    ;// ABOX242 -- see above

        fsub st, st(1)  ;// determine the delta
        fabs            ;// must be pos
        fld iir_small_1 ;// compare with 'really_small'
        fucompp         ;// Y0  1   X00
        xor eax, eax
        fnstsw ax
        sahf
        jb IIR_sX_sF_LP1_top    ;// if too big, continue on

    ;// now we have close to the same value

        fxch st(2)          ;// X00 1   Y0
        mov edx, XLAST      ;// get last input value
        fstp st             ;// 1   Y0
        mov X1, edx         ;// save last input value
        fstp st             ;// Y0

        fld iir_small_1

        jmp iir_check_remaining ;// fill remaining will do the rest

    ALIGN 16
    IIR_sX_sF_LP1_done:

        mov eax, [ebx+LAST_SAMPLE]
        fstp st
        mov X1, eax
        fstp st
        or [esi].pin_y.dwStatus, PIN_CHANGING
        fstp st

        jmp iir_calc_done

        ;/////////////////
        IIR_1_CLIPTEST_FIX

IIR_sX_sF_LP1 ENDP


ALIGN 16
IIR_sX_sF_HP1   PROC

    ;// make sure we have current parameters

    ;// make sure we have current parameters

        IIR_CHECK_PARAMS_1 params_ok

            invoke iir_build_params_HP1

        params_ok:

    ;// if the first two values are different we do extra work
    ;// but we want to assume they are the same
        mov eax, X1
        cmp eax, X0
            fld math_1      ;// 1
        .IF ZERO?
            fld Y1          ;// Y1  1
            jmp IIR_sX_sF_HP1_enter
        .ENDIF
    ;// otherwise build the first value by hand

        fld X0              ;// X1  1
        fsub X1
        fmul B0
        fld Y1
        fmul A1
        fadd        ;// Y0  1
        ;// jmp IIR_sX_sF_HP1_top

        ;//ABOX242 -- bug here
        ;//see above in IIR_sX_sF_LP1
        jmp IIR_sX_sF_HP1_enter_0

    ALIGN 16
    IIR_sX_sF_HP1_top:

        IIR_1_CLIPTEST

        fst Y0       ;//

        inc ecx
        cmp ecx, SAMARY_LENGTH
        jae IIR_sX_sF_HP1_done

    IIR_sX_sF_HP1_enter:    ;// Y1  1
    ; Y0 = A1*Y1
    ; do until Y0 = Y1
    ;// since we are a highpass filter, we will gravitate to zero
    ;// so we should be able to skip the subtraction

        fmul A1         ;// Y0  1
    IIR_sX_sF_HP1_enter_0:    ;// ABOX242 -- see above
        fld st            ;// Y0    Y0    1
        fabs            ;// must be pos
        fld iir_small_1 ;// compare with 'really_small'
        fucompp         ;// Y0  1
        xor eax, eax
        fnstsw ax
        sahf
        jb IIR_sX_sF_HP1_top    ;// if too big, continue on

    ;// now we have close to the same value

        fxch                ;// 1   Y0
        mov edx, XLAST      ;// get last input value
        fstp st             ;// Y0
        mov X1, edx         ;// save last input value

        fld iir_small_1

        jmp iir_check_remaining ;// fill remaining will do the rest

    ALIGN 16
    IIR_sX_sF_HP1_done:

        mov eax, XLAST
        fstp st
        mov X1, eax
        fstp st
        or [esi].pin_y.dwStatus, PIN_CHANGING

        jmp iir_calc_done

        ;/////////////////
        IIR_1_CLIPTEST_FIX

IIR_sX_sF_HP1   ENDP










ALIGN 16
IIR_dX_sF_LP1 PROC

    ;// make sure we have current parameters

        IIR_CHECK_PARAMS_1 params_ok

            invoke iir_build_params_LP1

        params_ok:


        fld math_1      ;// for clip tests
        fld Y1
        fld X1
        jmp IIR_dX_sF_LP1_enter

    ;//
    ;// iir_dX_sF_LP1.asm      generated by FpuOpt3 from iir_dX_sF_LP1.txt
    ;//
    ; iir dX sF LP1
    ;
    ; Y0 = A1*Y1 + (X0+X1)*B0
    ;

    ALIGN 16
    IIR_dX_sF_LP1_top:

        IIR_1_CLIPTEST

        fst Y0       ;//
        fld X0
        inc ecx
        cmp ecx, SAMARY_LENGTH
        jae IIR_dX_sF_LP1_done


    IIR_dX_sF_LP1_enter:;// X1     Y1
    ;// a1y1 = A1*Y1
        fxch   st(1)    ;// Y1     X1
        fmul   A1       ;// a1y1   X1
    ;// x01 = X0+X1
        fxch   st(1)    ;// X1     a1y1
        fadd   X0       ;// x01    a1y1
    ;// bx01 = B0*x01
        fmul   B0       ;// bx01   a1y1
    ;// Y0 # a1y1+bx01
        faddp  st(1),st ;// Y0

        jmp IIR_dX_sF_LP1_top

        ;/////////////////
        IIR_1_CLIPTEST_FIX

IIR_dX_sF_LP1 ENDP




ALIGN 16
IIR_dX_sF_HP1 PROC

    ;// make sure we have current parameters

        IIR_CHECK_PARAMS_1 params_ok

            invoke iir_build_params_HP1

        params_ok:


        fld math_1      ;// for clip tests
        fld Y1
        fld X1
        jmp IIR_dX_sF_HP1_enter

    ;//
    ;// iir_dX_sF_HP1.asm      generated by FpuOpt3 from iir_dX_sF_HP1.txt
    ;//
    ; iir dX sF LP1
    ;
    ; Y0 = A1*Y1 + (X0-X1)*B0
    ;

    ALIGN 16
    IIR_dX_sF_HP1_top:

        IIR_1_CLIPTEST

        fst Y0       ;//
        fld X0
        inc ecx
        cmp ecx, SAMARY_LENGTH
        jae IIR_dX_sF_HP1_done

    IIR_dX_sF_HP1_enter:
    ;// a1y1 = A1*Y1
        fxch   st(1)    ;// Y1     X1
        fmul   A1       ;// a1y1   X1
    ;// x01 = X0-X1
        fxch   st(1)    ;// X1     a1y1
        fsubr  X0       ;// x01    a1y1
    ;// bx01 = B0*x01
        fmul   B0       ;// bx01   a1y1
    ;// Y0 # a1y1+bx01
        faddp  st(1),st ;// Y0
        jmp IIR_dX_sF_HP1_top


        ;/////////////////
        IIR_1_CLIPTEST_FIX

IIR_dX_sF_HP1 ENDP



;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////


ALIGN 16
IIR_sX_dF_LP1:
IIR_dX_dF_LP1 PROC

        fld math_1      ;// for clip tests
        fld Y1
        fld X1
        jmp IIR_dX_dF_LP1_enter

    ALIGN 16
    IIR_dX_dF_LP1_top:
    ;// clip test here

        IIR_1_CLIPTEST

    ;// store and load for next iteration

        fst   Y0       ;// Y0
        fld X0
        inc ecx
        cmp ecx, SAMARY_LENGTH
        jae IIR_dX_dF_LP1_done  ;// common exit point after HP1

    ;//
    ;// iir_dX_dF_LP1.asm      generated by FpuOpt3 from iir_dX_dF_LP1.txt
    ;//
    ; iir dX dF LP1
    ;      (1+cos(F*pi)-sin(F*pi))*Y1 + (X1+X0)*sin(F*pi)
    ; Y0 = ----------------------------------------------
    ;                1+cos(F*pi)+sin(F*pi)
    ;// FPU X1 Y1      ;// X1     Y1
    IIR_dX_dF_LP1_enter:

        iir_LookupSinCos;// cf     sf     X1     Y1    1

    ;// c1 = cf+math_one
        fadd   math_1   ;// c1     sf     X1     Y1
    ;// x01 = X0+X1
        fxch   st(2)    ;// X1     sf     c1     Y1
        fadd   X0       ;// x01    sf     c1     Y1
    ;// a1 = c1-sf
        fld    st(2)    ;// c1     x01    sf     c1     Y1
        fsub   st,st(2) ;// a1     x01    sf     c1     Y1
    ;// a0 = c1+sf
        fxch   st(3)    ;// c1     x01    sf     a1     Y1
        fadd   st,st(2) ;// a0     x01    sf     a1     Y1
    ;// b0x = sf*x01
        fxch   st(2)    ;// sf     x01    a0     a1     Y1
        fmulp  st(1),st ;// b0x    a0     a1     Y1
    ;// a1y = a1*Y1
        fxch   st(2)    ;// a1     a0     b0x    Y1
        fmulp  st(3),st ;// a0     b0x    a1y
    ;// num = a1y+b0x
        fxch   st(2)    ;// a1y    b0x    a0
        faddp  st(1),st ;// num    a0
    ;// Y0 # num/a0
        fdivrp st(1),st ;// Y0
        jmp IIR_dX_dF_LP1_top

        ;/////////////////
        IIR_1_CLIPTEST_FIX

IIR_dX_dF_LP1 ENDP

ALIGN 16
IIR_sX_dF_HP1:
IIR_dX_dF_HP1 PROC

        fld math_1      ;// for clip tests
        fld Y1
        fld X1
        jmp IIR_dX_dF_HP1_enter

    ALIGN 16
    IIR_dX_dF_HP1_top:
    ;// clip test here

        IIR_1_CLIPTEST

    ;// <<Y0
        fst Y0       ;// Y0
        fld X0
        inc ecx
        cmp ecx, SAMARY_LENGTH
        jae IIR_dX_dF_HP1_done

    ;//
    ;// iir_dX_dF_HP1.asm      generated by FpuOpt3 from iir_dX_dF_HP1.txt
    ;//
    ; iir dX dF HP1
    ;      (1+cos(F*pi)-sin(F*pi))*Y1 + (X0-X1)*(1+cos(F*pi))
    ; Y0 = --------------------------------------------------
    ;                1+cos(F*pi)+sin(F*pi)
    IIR_dX_dF_HP1_enter:

        iir_LookupSinCos;// cf     sf     X1     Y1    1

    ;// c1 = cf+math_1
        fadd   st, st(4);// c1     sf     X1     Y1    1
    ;// x01 = X0-X1
        fxch   st(2)    ;// X1     sf     c1     Y1
        fsubr  X0       ;// x01    sf     c1     Y1
    ;// a1 = c1-sf
        fld    st(2)    ;// c1     x01    sf     c1     Y1
        fsub   st,st(2) ;// a1     x01    sf     c1     Y1
    ;// a0 = c1+sf
        fxch   st(2)    ;// sf     x01    a1     c1     Y1
        fadd   st,st(3) ;// a0     x01    a1     c1     Y1
    ;// b0x = c1*x01
        fxch   st(3)    ;// c1     x01    a1     a0     Y1
        fmulp  st(1),st ;// b0x    a1     a0     Y1
    ;// a1y = a1*Y1
        fxch   st(1)    ;// a1     b0x    a0     Y1
        fmulp  st(3),st ;// b0x    a0     a1y
    ;// num = a1y+b0x
        faddp  st(2),st ;// a0     num
    ; BUG!! FPUOPT should emit FDIV not FDIVR, fixed manually here
    ;// Y0 # num/a0
        fdiv             ;// Y0
        jmp IIR_dX_dF_HP1_top


        ;/////////////////
        IIR_1_CLIPTEST_FIX

IIR_dX_dF_HP1 ENDP




    ;// common exit point

    ALIGN 16
    IIR_dX_sF_LP1_done:
    IIR_dX_sF_HP1_done:
    IIR_dX_dF_LP1_done:
    IIR_dX_dF_HP1_done:

                        ;// X1 Y1 1
        fstp X1
        or [esi].pin_y.dwStatus, PIN_CHANGING
        fstp st
        fstp st

        jmp iir_calc_done


;///
;///    1st order filters
;///
;///
;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////
;//
;//
;//     2nd order filters
;//
;//


    IIR_CHECK_PARAMS_2 MACRO label:REQ

    ;// this check if we need to calculate the static filter params accross a frame
    ;// it does NOT store the new values
    ;// fall through is assumed to be needs_new_coeff

        mov eax, F0
        cmp eax, [esi].pin_f.dwUser
        setne cl
        mov eax, L0
        cmp eax, [esi].pin_r.dwUser
        setne ch
        BITT [esi].dwUser, IIR_NEED_UPDATE  ;// do NOT turn off bit yet
        adc cl, ch
        jz label
        xor ecx, ecx

        ENDM

ALIGN 16
iir_load_params_P2 PROC

    ;// calculates A1 and A2
    ;// sets up the FPU for determining the B coeff
    ;// stores new tracked parameters as well

        mov eax, F0
        mov [esi].pin_f.dwUser, eax

        iir_LookupSinCos    ;// cf  sf

        BITR [esi].dwUser, IIR_NEED_UPDATE
        mov eax, L0
        jc have_to_build
        cmp eax, [esi].pin_r.dwUser
        je use_existing_Q
    have_to_build:
            mov [esi].pin_r.dwUser, eax
            ;// build the new Q
            iir_build_Q
            fst Q0
            fadd st, st
            fst Q2      ;// Q2  cf  sf
            jmp done_with_Q
    use_existing_Q:
            fld Q2
    done_with_Q:        ;// Q2  cf  sf

    ;// now we have the fpu loaded
    ;// lets calculate _A00, A1 and A2

    ;//
    ;// p2_params.asm      generated by FpuOpt3 from p2_params.txt
    ;//
    ;// P2_params
    ;
    ; A0 = Q2+sf
    ;_A0 = 1/A0
    ; A1 = 2*Q2*cf*_A0
    ; A2 = (sf-Q2) * _A0


    ;// FPU Q2 cf sf    ;// Q2     cf     sf

    ;// Q4=Q2+Q2
        fld    st(0)    ;// Q2     Q2     cf     sf
        fadd   st,st(0) ;// Q4     Q2     cf     sf
    ;// A0 = Q2+sf
        fld    st(1)    ;// Q2     Q4     Q2     cf     sf
        fadd   st,st(4) ;// A0     Q4     Q2     cf     sf
    ;// sfm=sf-Q2
        fxch   st(2)    ;// Q2     Q4     A0     cf     sf
        fsubr  st,st(4) ;// sfm    Q4     A0     cf     sf
    ;// a1=Q4*cf
        fxch   st(1)    ;// Q4     sfm    A0     cf     sf
        fmul   st,st(3) ;// a1     sfm    A0     cf     sf
    ;// _A0 = math_1 / A0
        fxch   st(2)    ;// A0     sfm    a1     cf     sf
        fdivr  math_1   ;// _A0    sfm    a1     cf     sf
    ;// A1#a1*_A0
        fmul   st(2),st ;// _A0    sfm    A1     cf     sf
    ;// A2#sfm*_A0
        fmul   st(1),st ;// _A0    A2     A1     cf     sf
    ;// <<A1
        fxch   st(2)    ;// A1     A2     _A0    cf     sf
        fstp   A1       ;// A2     _A0    cf     sf
    ;// <<A2
        fstp   A2       ;// _A0    cf     sf

        fld    Q0           ;// Q      _A0    cf     sf

    ;// and we return to caller

        ret

iir_load_params_P2 ENDP


ALIGN 16
iir_build_params_LP2 PROC

        invoke iir_load_params_P2   ;// Q       _A0    cf     sf

        .IF [esi].dwUser & IIR_AUTO_GAIN
            iir_build_aG
        .ELSE
            iir_build_nG            ;// GQ      Q2      _A0     cf      sf
        .ENDIF

    ;// B0 = GQ*(1-cf) * _A0
    ;// B1 = 2*B0
    ;// B2 = B0

        fld math_1      ;// 1       GQ      Q2      _A0     cf      sf
        fsubrp st(4),st ;// GQ      Q2      _A0     1-cf        sf
        fmulp st(3), st ;// Q2      _A0     1-cf    sf
        fstp st         ;// _A0     1-cf    sf
        fmul            ;// B0      sf
        fst B0
        fst B2
        fadd st, st
        fxch
        fstp st
        fstp B1

        ret

iir_build_params_LP2 ENDP

ALIGN 16
iir_build_params_HP2 PROC

        invoke iir_load_params_P2   ;// Q       _A0    cf     sf

        .IF [esi].dwUser & IIR_AUTO_GAIN
            iir_build_aG
        .ELSE
            iir_build_nG            ;// GQ      Q2      _A0     cf      sf
        .ENDIF

    ;// B0 = GQ*(1+cf) * _A0
    ;// B1 = -2*B0
    ;// B2 = B0

        fld math_1      ;// 1       GQ      Q2      _A0     cf      sf
        faddp st(4),st  ;// GQ      Q2      _A0     1+cf        sf
        fmulp st(3), st ;// Q2      _A0     1+cf    sf
        fstp st         ;// _A0     1+cf    sf
        fmul            ;// B0      sf
        fst B0
        fst B2
        fadd st, st
        fxch
        fstp st
        fchs
        fstp B1

        ret

iir_build_params_HP2 ENDP

ALIGN 16
iir_build_params_BP2 PROC

        invoke iir_load_params_P2   ;// Q       _A0    cf     sf

        .IF [esi].dwUser & IIR_AUTO_GAIN
            fadd st, st
            fld math_1
        .ELSE
            iir_build_nG            ;// GQ      Q2      _A0     cf      sf
        .ENDIF

    ;// B0 = GQ * sf * _A0
    ;// B1 = 0
    ;// B2 = -B0

        fmulp st(4), st ;// Q2  _A0 cf  sf*GQ
        fstp st         ;// _A0 cf  sf*GQ
        fmulp st(2), st ;// cf  B0
        fstp st
        fst B0
        fchs
        fstp B2
        mov B1, 0

        ret

iir_build_params_BP2 ENDP

ALIGN 16
iir_build_params_BR2 PROC

        invoke iir_load_params_P2   ;// Q       _A0    cf     sf

        .IF [esi].dwUser & IIR_AUTO_GAIN
            fadd st, st
            fld math_1
        .ELSE
            iir_build_nG            ;// GQ      Q2      _A0     cf      sf
        .ENDIF

    ;// B0 = 1-sf*GQ*_A0
    ;// B1 = -A1
    ;// B2 = sf*GQ*_A0 - A2

        fmulp st(4), st ;// Q2      _A0     cf      sf*GQ
        fstp st         ;// _A0     cf      sf*GQ
        fmulp st(2), st ;// cf      sf*GQ*_A0
        fstp st         ;// sf*GQ*_A0

        fld math_1
        fsub st, st(1)  ;// B0

        fld A2
        fsubp st(2), st ;// B0  B2

        fstp B0
        mov eax, A1
        btc eax, 31
        mov B1, eax
        fstp B2

        ret


iir_build_params_BR2 ENDP




ALIGN 16
IIR_dX_sF_sL_nG_LP2::
IIR_dX_sF_sL_aG_LP2::   IIR_CHECK_PARAMS_2  iir_2_static_param
                        invoke iir_build_params_LP2
                        jmp iir_2_static_param
ALIGN 16
IIR_dX_sF_sL_nG_HP2::
IIR_dX_sF_sL_aG_HP2::   IIR_CHECK_PARAMS_2  iir_2_static_param
                        invoke iir_build_params_HP2
                        jmp iir_2_static_param
ALIGN 16
IIR_dX_sF_sL_nG_BP2::
IIR_dX_sF_sL_aG_BP2::   IIR_CHECK_PARAMS_2  iir_2_static_param
                        invoke iir_build_params_BP2
                        jmp iir_2_static_param
ALIGN 16
IIR_dX_sF_sL_nG_BR2::
IIR_dX_sF_sL_aG_BR2::   IIR_CHECK_PARAMS_2  iir_2_static_param
                        invoke iir_build_params_BR2
                        jmp iir_2_static_param

ALIGN 16
iir_2_static_param PROC

    ;// not so efficient version, about 26 cycles per sample

        or [esi].pin_y.dwStatus, PIN_CHANGING

        fld Y2
        fld Y1
        fld X2
        fld X1
        ALIGN 16
        .REPEAT             ;// X1  X2  Y1  Y2

            fld X0          ;// X0  X1  X2  Y1  Y2
            fld B0          ;// B0  X0  X1  X2  Y1  Y2
            fmul st,st(1)   ;// bX0 X0  X1  X2  Y1  Y2

            fld st(2)       ;// X1  bX0 X0  X1  X2  Y1  Y2
            fmul B1         ;// bX1 bX0 X0  X1  X2  Y1  Y2
            fld B2          ;// B2  bX1 bX0 X0  X1  X2  Y1  Y2
            fmulp st(5), st ;// bX1 bX0 X0  X1  bX2 Y1  Y2

            fld st(5)       ;// Y1  bX1 bX0 X0  X1  bX2 Y1  Y2
            fmul A1         ;// aY1 bX1 bX0 X0  X1  bX2 Y1  Y2

            fxch            ;// bX1 aY1 bX0 X0  X1  bX2 Y1  Y2
            faddp st(2), st ;// aY1 b12 X0  X1  bX2 Y1  Y2
            fld A2          ;// A2  aY1 b12 X0  X1  bX2 Y1  Y2
            fmulp st(7), st ;// aY1 b12 X0  X1  bX2 Y1  aY2

            faddp st(4), st ;// b12 X0  X1  ab  Y1  aY2
            faddp st(5), st ;// X0  X1  ab  Y1  abc
            fxch st(2)      ;// ab  X1  X0  Y1  abc
            faddp st(4), st ;// X1  X0  Y1  Y0

            fxch st(2)      ;// Y1  X0  X1  Y0
            fxch st(3)      ;// Y0  X0  X1  Y1

        ;// CLIPTEST_ONE iir_clip   ;// Y0  X0  X1  Y1

            fld math_1          ;// 1   y0  .....
            fld st(1)           ;// y0  1   y0
            fabs
            fucompp     ;// do the test, flush both values
            xor eax, eax
            fnstsw  ax  ;// xfer results to ax
            sahf        ;// xfer results to flags

            ja we_clipped

        clip_done:

            fst Y0
            inc ecx
            fxch st(2)      ;// X1  X0  Y0  Y1
            fxch            ;// X0  X1  Y0  Y1

        .UNTIL ecx>=SAMARY_LENGTH

        fstp X1
        fstp X2
        fstp st
        fstp st

        jmp iir_calc_done

    ALIGN 16
    we_clipped:

        ;// we clipped

        ftst        ;// check the sign
        xor eax, eax
        fnstsw ax   ;// xfer to ax
        fstp st     ;// dump the value
        sahf        ;// xfer results to flags
        fld math_1      ;// load the staturate value
        inc iir_clip    ;// set it
        jnc clip_done
        fchs    ;// make it pos
        jmp clip_done



iir_2_static_param ENDP







;////////////////////////////////////////////////
;////////////////////////////////////////////////
;//
;//     2nd order
;//     clip test macro pair
;//




    IIR_2_CLIPTEST MACRO

        ;// fpu must be set as  Y1  Y0

            fld math_1  ;// 1   Y1  Y0
            fld st(2)   ;// Y0  1   Y1  Y0
            fabs
            fucompp     ;// do the test, flush both values
            xor eax, eax
            fnstsw  ax  ;// xfer results to ax
            sahf        ;// xfer results to flags
            fxch        ;// Y0  Y1
            ja we_clipped

        clip_done:

        ENDM


    IIR_2_CLIPTEST_FIX MACRO

        ALIGN 16
        we_clipped:

            ;// we clipped  ;// Y0  Y1

            ftst        ;// check the sign
            xor eax, eax
            fnstsw ax   ;// xfer to ax
            fstp st     ;// dump the value
            sahf        ;// xfer results to flags
            fld math_1  ;// load the staturate value
            inc iir_clip    ;// set it
            jnc clip_done
            fchs        ;// make it pos
            jmp clip_done

        ENDM


    IIR_2_CLIPTEST_INLINE MACRO

        LOCAL clip_done_internal

        ;// fpu must be set as  Y1  Y0

            fld math_1  ;// 1   Y1  Y0
            fld st(2)   ;// Y0  1   Y1  Y0
            fabs
            fucompp     ;// do the test, flush both values
            xor eax, eax
            fnstsw  ax  ;// xfer results to ax
            sahf        ;// xfer results to flags
            fxch        ;// Y0  Y1
            jbe clip_done_internal

            ftst        ;// check the sign
            xor eax, eax
            fnstsw ax   ;// xfer to ax
            fstp st     ;// dump the value
            sahf        ;// xfer results to flags
            fld math_1  ;// load the staturate value
            inc iir_clip    ;// set it
            jnc clip_done_internal
            fchs        ;// make it pos

        clip_done_internal:

        ENDM


;//
;//     2nd order
;//     clip test macro pair
;//
;////////////////////////////////////////////////
;////////////////////////////////////////////////




ALIGN 16
IIR_sX_sF_sL_nG_LP2::
IIR_sX_sF_sL_aG_LP2::   IIR_CHECK_PARAMS_2  iir_sX_static_param_LP2
                        invoke iir_build_params_LP2
iir_sX_static_param_LP2:fld X2
                        fadd X1
                        fld X1
                        fadd X0
                        fadd
                        fmul B0     ;// X012
                        fld X0
                        fmul math_3
                        fadd X1
                        fmul B0     ;// Xa01    X012
                        fld X0
                        fmul math_4
                        fmul B0     ;// Xba0    Xa01    X012
                        jmp IIR_2_sX_sF_sL_COMMON

ALIGN 16
IIR_sX_sF_sL_nG_HP2::
IIR_sX_sF_sL_aG_HP2::   IIR_CHECK_PARAMS_2  iir_sX_static_param_HP2
                        invoke iir_build_params_HP2
iir_sX_static_param_HP2:fld X2  ;// X0 - 2*X1 + X2
                        fsub X1
                        fsub X1
                        fadd X0
                        fmul B0 ;// x012
                        fld X1
                        fsub X0
                        fmul B0 ;// Xa01    X012
                        fldz    ;// Xba0    Xa01    X012
                        jmp IIR_2_sX_sF_sL_COMMON

ALIGN 16
IIR_sX_sF_sL_nG_BP2::
IIR_sX_sF_sL_aG_BP2::   IIR_CHECK_PARAMS_2  iir_sX_static_param_BP2
                        invoke iir_build_params_BP2
iir_sX_static_param_BP2:fld X2  ;// X1-X2
                        fsub X0
                        fmul B0 ;// X012
                        fld X0
                        fsub X1
                        fmul B0 ;// Xa01    X012
                        fldz    ;// Xba0    Xa01    X012
                        jmp IIR_2_sX_sF_sL_COMMON

ALIGN 16
IIR_sX_sF_sL_nG_BR2::
IIR_sX_sF_sL_aG_BR2::   IIR_CHECK_PARAMS_2  iir_sX_static_param_BR2
                        invoke iir_build_params_BR2
iir_sX_static_param_BR2:

    ;// x012 = (1-A2-B0)*X2 - A1*X1 + X0*B0
    ;// xa01 = (1-A2-B0)*X1 - A1*X0 + X0*B0
    ;// xba0 = (1-A2-B0)*X0 - A1*X0 + X0*B0

    ;//
    ;// sx_br2.asm      generated by FpuOpt3 from sx_br2.txt
    ;//
    ;// x012 = (1-A2-B0)*X2 - A1*X1 + X0*B0   T0+U0
    ;// xa01 = (1-A2-B0)*X1 - A1*X0 + X0*B0   T1+U1
    ;// xba0 = (1-A2-B0)*X0 - A1*X0 + X0*B0   T2+U1

    ;// x0b0 = X0*B0
        fld    X0       ;// X0
        fmul   B0       ;// x0b0
    ;// a21=math_1-A2
        fld    math_1   ;// math_1 x0b0
        fsub   A2       ;// a21    x0b0
    ;// ff=a21-B0
        fsub   B0       ;// ff     x0b0
    ;// a1x1=A1*X1
        fld    A1       ;// A1     ff     x0b0
        fmul   X1       ;// a1x1   ff     x0b0
    ;// a1x0=A1*X0
        fld    A1       ;// A1     a1x1   ff     x0b0
        fmul   X0       ;// a1x0   a1x1   ff     x0b0

    ;// T0=X2*ff
        fld    X2       ;// X2     a1x0   a1x1   ff     x0b0
        fmul   st,st(3) ;// T0     a1x0   a1x1   ff     x0b0
    ;// T1=X1*ff
        fld    X1       ;// X1     T0     a1x0   a1x1   ff     x0b0
        fmul   st,st(4) ;// T1     T0     a1x0   a1x1   ff     x0b0
    ;// T2=X0*ff
        fxch   st(4)    ;// ff     T0     a1x0   a1x1   T1     x0b0
        fmul   X0       ;// T2     T0     a1x0   a1x1   T1     x0b0

    ;// U0=x0b0-a1x1
        fxch   st(3)    ;// a1x1   T0     a1x0   T2     T1     x0b0
        fsubr  st,st(5) ;// U0     T0     a1x0   T2     T1     x0b0
    ;// U1=x0b0-a1x0
        fxch   st(5)    ;// x0b0   T0     a1x0   T2     T1     U0
        fsubrp st(2),st ;// T0     U1     T2     T1     U0

    ;// Xa01=T1+U1
        fxch   st(3)    ;// T1     U1     T2     T0     U0
        fadd   st,st(1) ;// Xa01   U1     T2     T0     U0
    ;// X012=T0+U0
        fxch   st(3)    ;// T0     U1     T2     Xa01   U0
        faddp  st(4),st ;// U1     T2     Xa01   X012
    ;// Xba0=T2+U1
        faddp  st(1),st ;// Xba0   Xa01   X012


                        ;// Xba0    Xa01    X012
                        jmp IIR_2_sX_sF_sL_COMMON


    ;// macro used only in next section

    IIR_COMPARE MACRO reg1:req, reg2:req

        fld st(reg1)
        fabs
        fucomp st(reg2+1)
        xor eax, eax
        fnstsw ax
        sahf

        ENDM



ALIGN 16
IIR_2_sX_sF_sL_COMMON PROC  ;// Xba0    Xa01    X012

        ;// like the 1st order, we will track when Y stops changing

    ;//
    ;// iir_2_sX_sF_sL_COMMON.asm      generated by FpuOpt3 from iir_2_sX_sF_sL_COMMON.txt
    ;//
    ;//
    ;// 0) Y0 = A1*Y1 + A2*Y2 + X012  exit if Y0==Y1==Y2
    ;// 1) Ya = A1*Y0 + A2*Y1 + Xa01  exit if Ya==Y0==Y1
    ;// L) yb = A1*Ya + A2*Y0 + Xba0  exit if Yb==Ya==Y0
    ;// loop must maintain Yb Ya Xba0

    ;// >> small
    ;// >> one
        fld    iir_small_2   ;// small  Xba0   Xa01   X012
        fld    math_1   ;// one    small  Xba0   Xa01   X012

    ;// 0 //////////////////////////////////////////////////

    ;// a1y1=A1*Y1
        fld    A1       ;// A1     one    small  Xba0   Xa01   X012
        fmul   Y1       ;// a1y1   one    small  Xba0   Xa01   X012
    ;// a2y2=A2*Y2
        fld    A2       ;// A2     a1y1   one    small  Xba0   Xa01   X012
        fmul   Y2       ;// a2y2   a1y1   one    small  Xba0   Xa01   X012
    ;// ay00=a1y1+a2y2
        faddp  st(1),st ;// ay00   one    small  Xba0   Xa01   X012
    ;// Y0#ay00+X012
        faddp  st(5),st ;// one    small  Xba0   Xa01   Y0
     IIR_COMPARE 4,0 ;// CLIPTEST Y0
     jbe no_clip_0
        fld st(4)
        ftst
        xor eax, eax
        fnstsw ax
        fstp st
        fld st
        sahf
        jae not_neg_0
        fchs
     not_neg_0:
        fxch st(5)
        fstp st
     no_clip_0:
    ;// d12 = Y2-Y1
        fld    Y2       ;// Y2     one    small  Xba0   Xa01   Y0
        fsub   Y1       ;// d12    one    small  Xba0   Xa01   Y0
    ;// d01 = Y1-Y0
        fld    Y1       ;// Y1     d12    one    small  Xba0   Xa01   Y0
        fsub   st,st(6) ;// d01    d12    one    small  Xba0   Xa01   Y0
    ;// dy12# abs d12
        fxch   st(1)    ;// d12    d01    one    small  Xba0   Xa01   Y0
        fabs            ;// dy12   d01    one    small  Xba0   Xa01   Y0
    ;// dy01# abs d01
        fxch   st(1)    ;// d01    dy12   one    small  Xba0   Xa01   Y0
        fabs            ;// dy01   dy12   one    small  Xba0   Xa01   Y0
     IIR_COMPARE 1,3 ;// dy12
    ;// <<dy12
        fxch   st(1)    ;// dy12   dy01   one    small  Xba0   Xa01   Y0
        fstp   st       ;// dy01   one    small  Xba0   Xa01   Y0
     ja iir_2_sX_sF_sL_COMMON_1
     IIR_COMPARE 0,2 ;// dy01
     jbe iir_2_sX_sF_sL_COMMON_fill_0

    ;// 1 //////////////////////////////////////////////////
     iir_2_sX_sF_sL_COMMON_1:

    ;// <<Y0
        fxch   st(5)    ;// Y0     one    small  Xba0   Xa01   dy01
        fst    Y0       ;// Y0     one    small  Xba0   Xa01   dy01
     inc ecx

    ;// a1y0=A1*Y0
        fld    A1       ;// A1     Y0     one    small  Xba0   Xa01   dy01
        fmul   st,st(1) ;// a1y0   Y0     one    small  Xba0   Xa01   dy01
    ;// a2y1=A2*Y1
        fld    A2       ;// A2     a1y0   Y0     one    small  Xba0   Xa01   dy01
        fmul   Y1       ;// a2y1   a1y0   Y0     one    small  Xba0   Xa01   dy01
    ;// ay11=a1y0+a2y1
        faddp  st(1),st ;// ay11   Y0     one    small  Xba0   Xa01   dy01
    ;// Ya#ay11+Xa01
        faddp  st(5),st ;// Y0     one    small  Xba0   Ya     dy01
     IIR_COMPARE 4,1 ;// CLIPTEST Ya
     jbe no_clip_1
        fld st(4)
        ftst
        xor eax, eax
        fnstsw ax
        fstp st
        sahf
        fld st(1)
        jae not_neg_1
        fchs
     not_neg_1:
        fxch st(6)
        fstp st
     no_clip_1:
    ;// da0 = Ya-Y0
        fld    st(0)    ;// Y0     Y0     one    small  Xba0   Ya     dy01
        fsubr  st,st(5) ;// da0    Y0     one    small  Xba0   Ya     dy01
    ;// dya0# abs da0
        fabs            ;// dya0   Y0     one    small  Xba0   Ya     dy01
     IIR_COMPARE 6,3 ;// dy01
    ;// <<dy01
        fxch   st(6)    ;// dy01   Y0     one    small  Xba0   Ya     dya0
        fstp   st       ;// Y0     one    small  Xba0   Ya     dya0
        fxch   st(4)    ;// Ya     one    small  Xba0   Y0     dya0
     ja iir_2_sX_sF_sL_COMMON_top
     IIR_COMPARE 5,2 ;// dya0
     jbe iir_2_sX_sF_sL_COMMON_fill_1

    ;// LOOP ///////////////////////////////////////////////

     iir_2_sX_sF_sL_COMMON_top:

    ;// <<Ya
        fst    Y0       ;// Ya     one    small  Xba0   Y0     dya0

     inc ecx
     cmp ecx, SAMARY_LENGTH
     jae iir_2_sX_sF_sL_COMMON_done

    ;// a1ya=A1*Ya
        fld    A1       ;// A1     Ya     one    small  Xba0   Y0     dya0
        fmul   st,st(1) ;// a1ya   Ya     one    small  Xba0   Y0     dya0
    ;// a2y0=A2*Y0
        fxch   st(5)    ;// Y0     Ya     one    small  Xba0   a1ya   dya0
        fmul   A2       ;// a2y0   Ya     one    small  Xba0   a1ya   dya0
    ;// ay22=a1ya+a2y0
        faddp  st(5),st ;// Ya     one    small  Xba0   ay22   dya0
    ;// Yb#ay22+Xba0
        fxch   st(4)    ;// ay22   one    small  Xba0   Ya     dya0
        fadd   st,st(3) ;// Yb     one    small  Xba0   Ya     dya0
     IIR_COMPARE 0,1 ;// CLIPTEST Yb
     jbe no_clip_2
        ftst
        xor eax, eax
        fnstsw ax
        fstp st
        sahf
        fld st
        jae not_neg_2
        fchs
     not_neg_2:
     no_clip_2:
    ;// dab =Yb-Ya
        fld    st(0)    ;// Yb     Yb     one    small  Xba0   Ya     dya0
        fsub   st,st(5) ;// dab    Yb     one    small  Xba0   Ya     dya0
    ;// dyab=abs dab
        fabs            ;// dyab   Yb     one    small  Xba0   Ya     dya0
     IIR_COMPARE 6,3 ;// dya0
    ;// <<dya0
        fxch   st(6)    ;// dya0   Yb     one    small  Xba0   Ya     dyab
        fstp   st       ;// Yb     one    small  Xba0   Ya     dyab

     ja iir_2_sX_sF_sL_COMMON_top
     IIR_COMPARE 5,2 ;// dy1b
     ja iir_2_sX_sF_sL_COMMON_top

    ;// if this is hit then the two value were equal
    ;// and we can fill for the rest of the frame

     iir_2_sX_sF_sL_COMMON_fill_2:  ;// Y0     one    small  Xba0   Y1     dyab
     iir_2_sX_sF_sL_COMMON_fill_1:  ;// Y0     one    small  Xba0   Y1     dya0

        fxch st(5)

     iir_2_sX_sF_sL_COMMON_fill_0:  ;// ----   ----   small  ----   ----   Y0

        fstp st         ;// ----   small  ----   ----   Y0
        mov eax, XLAST1
        fstp st         ;// small  ----   ----   Y0
        mov edx, XLAST
        fxch st(2)      ;// -----  ----   small  Y0
        fstp st         ;// ----   small  Y0
        mov X2, eax
        fstp st         ;// small  Y0
        mov X1, edx

        jmp iir_check_remaining

    ALIGN 16
     iir_2_sX_sF_sL_COMMON_done:    ;// Y1     one    small  Xba0   Y2     dya0

        fstp st
        or [esi].pin_y.dwStatus, PIN_CHANGING
        fstp st
        mov eax, XLAST1
        fstp st
        mov edx, XLAST
        fstp st
        mov X2, eax
        fstp st
        mov X1, edx
        fstp st

        jmp iir_calc_done


IIR_2_sX_sF_sL_COMMON ENDP








;// iir dX dF sL LP2
;//
;// (sin(F*pi)-Q2)*Y2 + (1-cos(F*pi))*(X0+2*X1+X2)*G + 2*Q2*Y1*cos(F*pi)
;// ----------------------------------------------------------------------
;//                           Q2+sin(F*pi)

ALIGN 16
IIR_sX_dF_sL_nG_LP2:
IIR_dX_dF_sL_nG_LP2:    iir_build_Q     ;// Q
                        iir_build_nG    ;// G      Q2
                        fstp G0
                        fstp Q2
                        jmp IIR_dX_dF_sL_LP2
ALIGN 16
IIR_sX_dF_sL_aG_LP2:
IIR_dX_dF_sL_aG_LP2:    iir_build_Q     ;// Q
                        iir_build_aG    ;// G      Q2
                        fstp G0
                        fstp Q2
IIR_dX_dF_sL_LP2 PROC

        fld Y2
        fld Y1

;// 0 //////////////////////////////////////////////////////////////

        iir_LookupSinCos;// cf     sf     Y1     Y2

    ;// cf1 = math_1-cf
        fld    math_1   ;// math_1 cf     sf     Y1     Y2
        fsub   st,st(1) ;// cf1    cf     sf     Y1     Y2
    ;// a1  = Q2*cf
        fxch   st(1)    ;// cf     cf1    sf     Y1     Y2
        fmul   Q2       ;// a1     cf1    sf     Y1     Y2
    ;// a0  = sf+Q2
        fld    Q2       ;// Q2     a1     cf1    sf     Y1     Y2
        fadd   st,st(3) ;// a0     a1     cf1    sf     Y1     Y2
    ;// b0  = G*cf1
        fxch   st(2)    ;// cf1    a1     a0     sf     Y1     Y2
        fmul   G0       ;// b0     a1     a0     sf     Y1     Y2
    ;// a11 = a1+a1
        fxch   st(1)    ;// a1     b0     a0     sf     Y1     Y2
        fadd   st,st(0) ;// a11    b0     a0     sf     Y1     Y2
    ;// a2  = sf-Q2
        fxch   st(3)    ;// sf     b0     a0     a11    Y1     Y2
        fsub   Q2       ;// a2     b0     a0     a11    Y1     Y2
    ;// a1y1= Y1*a11
        fxch   st(3)    ;// a11    b0     a0     a2     Y1     Y2
        fmul   st,st(4) ;// a1y1   b0     a0     a2     Y1     Y2
    ;pay attention to ADDRESSES of X
    ;// x01 = XX0+XX1
        fld    X0      ;// XX0    a1y1   b0     a0     a2     Y1     Y2
        fadd   X1      ;// x01    a1y1   b0     a0     a2     Y1     Y2
    ;// x12 = XX1+XX2
        fld    X1      ;// XX1    x01    a1y1   b0     a0     a2     Y1     Y2
        fadd   X2      ;// x12    x01    a1y1   b0     a0     a2     Y1     Y2
    ;// a2y2= Y2*a2
        fxch   st(7)    ;// Y2     x01    a1y1   b0     a0     a2     Y1     x12
        fmulp  st(5),st ;// x01    a1y1   b0     a0     a2y2   Y1     x12
    ;// x012= x01+x12
        faddp  st(6),st ;// a1y1   b0     a0     a2y2   Y1     x012
    ;// t1  = a2y2+a1y1
        faddp  st(3),st ;// b0     a0     t1     Y1     x012
    ;// bx  = b0*x012
        fmulp  st(4),st ;// a0     t1     Y1     bx
    ;// t2  = t1+bx
        fxch   st(1)    ;// t1     a0     Y1     bx
        faddp  st(3),st ;// a0     Y1     t2
    ;// BUG!! should produce DIVP not DIVRP
    ;// Y0  = t2/a0
        fdivp st(2),st ;// Y1     Y0

;// 1 //////////////////////////////////////////////////////////////


        IIR_2_CLIPTEST_INLINE

        fst Y0
        inc ecx

        iir_LookupSinCos;// cf     sf     Y1     Y2
    ;// cf1 = math_1-cf
        fld    math_1   ;// math_1 cf     sf     Y1     Y2
        fsub   st,st(1) ;// cf1    cf     sf     Y1     Y2
    ;// a1  = Q2*cf
        fxch   st(1)    ;// cf     cf1    sf     Y1     Y2
        fmul   Q2       ;// a1     cf1    sf     Y1     Y2
    ;// a0  = sf+Q2
        fld    Q2       ;// Q2     a1     cf1    sf     Y1     Y2
        fadd   st,st(3) ;// a0     a1     cf1    sf     Y1     Y2
    ;// b0  = G*cf1
        fxch   st(2)    ;// cf1    a1     a0     sf     Y1     Y2
        fmul   G0        ;// b0     a1     a0     sf     Y1     Y2
    ;// a11 = a1+a1
        fxch   st(1)    ;// a1     b0     a0     sf     Y1     Y2
        fadd   st,st(0) ;// a11    b0     a0     sf     Y1     Y2
    ;// a2  = sf-Q2
        fxch   st(3)    ;// sf     b0     a0     a11    Y1     Y2
        fsub   Q2       ;// a2     b0     a0     a11    Y1     Y2
    ;// a1y1= Y1*a11
        fxch   st(3)    ;// a11    b0     a0     a2     Y1     Y2
        fmul   st,st(4) ;// a1y1   b0     a0     a2     Y1     Y2
    ;pay attention to ADDRESSES of X
    ;// x01 = XX0+XX1
        fld    X0      ;// XX0    a1y1   b0     a0     a2     Y1     Y2
        fadd   XX1      ;// x01    a1y1   b0     a0     a2     Y1     Y2
    ;// x12 = XX1+XX2
        fld    XX1      ;// XX1    x01    a1y1   b0     a0     a2     Y1     Y2
        fadd   X1      ;// x12    x01    a1y1   b0     a0     a2     Y1     Y2
    ;// a2y2= Y2*a2
        fxch   st(7)    ;// Y2     x01    a1y1   b0     a0     a2     Y1     x12
        fmulp  st(5),st ;// x01    a1y1   b0     a0     a2y2   Y1     x12
    ;// x012= x01+x12
        faddp  st(6),st ;// a1y1   b0     a0     a2y2   Y1     x012
    ;// t1  = a2y2+a1y1
        faddp  st(3),st ;// b0     a0     t1     Y1     x012
    ;// bx  = b0*x012
        fmulp  st(4),st ;// a0     t1     Y1     bx
    ;// t2  = t1+bx
        fxch   st(1)    ;// t1     a0     Y1     bx
        faddp  st(3),st ;// a0     Y1     t2
    ;// BUG!! should produce DIVP not DIVRP
    ;// Y0  = t2/a0
        fdivp st(2),st ;// Y1     Y0

;// loop ///////////////////////////////////////////////////////////

    IIR_dX_dF_sL_LP2_top:

        IIR_2_CLIPTEST  ;// Y0  Y1

        fst Y0
        inc ecx
        cmp ecx, SAMARY_LENGTH
        jae IIR_dX_dF_sL_LP2_done

        iir_LookupSinCos;// cf     sf     Y1     Y2
    ;// cf1 = math_1-cf
        fld    math_1   ;// math_1 cf     sf     Y1     Y2
        fsub   st,st(1) ;// cf1    cf     sf     Y1     Y2
    ;// a1  = Q2*cf
        fxch   st(1)    ;// cf     cf1    sf     Y1     Y2
        fmul   Q2       ;// a1     cf1    sf     Y1     Y2
    ;// a0  = sf+Q2
        fld    Q2       ;// Q2     a1     cf1    sf     Y1     Y2
        fadd   st,st(3) ;// a0     a1     cf1    sf     Y1     Y2
    ;// b0  = G*cf1
        fxch   st(2)    ;// cf1    a1     a0     sf     Y1     Y2
        fmul   G0        ;// b0     a1     a0     sf     Y1     Y2
    ;// a11 = a1+a1
        fxch   st(1)    ;// a1     b0     a0     sf     Y1     Y2
        fadd   st,st(0) ;// a11    b0     a0     sf     Y1     Y2
    ;// a2  = sf-Q2
        fxch   st(3)    ;// sf     b0     a0     a11    Y1     Y2
        fsub   Q2       ;// a2     b0     a0     a11    Y1     Y2
    ;// a1y1= Y1*a11
        fxch   st(3)    ;// a11    b0     a0     a2     Y1     Y2
        fmul   st,st(4) ;// a1y1   b0     a0     a2     Y1     Y2
    ;pay attention to ADDRESSES of X
    ;// x01 = XX0+XX1
        fld    XX0      ;// XX0    a1y1   b0     a0     a2     Y1     Y2
        fadd   XX1      ;// x01    a1y1   b0     a0     a2     Y1     Y2
    ;// x12 = XX1+XX2
        fld    XX1      ;// XX1    x01    a1y1   b0     a0     a2     Y1     Y2
        fadd   XX2      ;// x12    x01    a1y1   b0     a0     a2     Y1     Y2
    ;// a2y2= Y2*a2
        fxch   st(7)    ;// Y2     x01    a1y1   b0     a0     a2     Y1     x12
        fmulp  st(5),st ;// x01    a1y1   b0     a0     a2y2   Y1     x12
    ;// x012= x01+x12
        faddp  st(6),st ;// a1y1   b0     a0     a2y2   Y1     x012
    ;// t1  = a2y2+a1y1
        faddp  st(3),st ;// b0     a0     t1     Y1     x012
    ;// bx  = b0*x012
        fmulp  st(4),st ;// a0     t1     Y1     bx
    ;// t2  = t1+bx
        fxch   st(1)    ;// t1     a0     Y1     bx
        faddp  st(3),st ;// a0     Y1     t2
    ;// BUG!! should produce DIVP not DIVRP
    ;// Y0  = t2/a0
        fdivp st(2),st ;// Y1     Y0

        jmp IIR_dX_dF_sL_LP2_top

    ;/////////////////
    IIR_2_CLIPTEST_FIX


IIR_dX_dF_sL_LP2 ENDP




;// iir dX dF sL HP2    xformed from LP2
;//                       v              v
;// (sin(F*pi)-Q2)*Y2 + (1+cos(F*pi))*(X0-2*X1+X2)*G + 2*Q2*Y1*cos(F*pi)
;// ----------------------------------------------------------------------
;//                           Q2+sin(F*pi)
ALIGN 16
IIR_sX_dF_sL_nG_HP2:
IIR_dX_dF_sL_nG_HP2:    iir_build_Q     ;// Q
                        iir_build_nG    ;// G      Q2
                        fstp G0
                        fstp Q2
                        jmp IIR_dX_dF_sL_HP2
ALIGN 16
IIR_sX_dF_sL_aG_HP2:
IIR_dX_dF_sL_aG_HP2:    iir_build_Q     ;// Q
                        iir_build_aG    ;// G      Q2
                        fstp G0
                        fstp Q2
IIR_dX_dF_sL_HP2 PROC

        fld Y2
        fld Y1

;// 0 //////////////////////////////////////////////////////////////

        iir_LookupSinCos;// cf     sf     Y1     Y2

    ;// cf1 = math_1+cf
        fld    math_1   ;// math_1 cf     sf     Y1     Y2
        fadd   st,st(1);<-- ;// cf1    cf     sf     Y1     Y2
    ;// a1  = Q2*cf
        fxch   st(1)    ;// cf     cf1    sf     Y1     Y2
        fmul   Q2       ;// a1     cf1    sf     Y1     Y2
    ;// a0  = sf+Q2
        fld    Q2       ;// Q2     a1     cf1    sf     Y1     Y2
        fadd   st,st(3) ;// a0     a1     cf1    sf     Y1     Y2
    ;// b0  = G*cf1
        fxch   st(2)    ;// cf1    a1     a0     sf     Y1     Y2
        fmul   G0       ;// b0     a1     a0     sf     Y1     Y2
    ;// a11 = a1+a1
        fxch   st(1)    ;// a1     b0     a0     sf     Y1     Y2
        fadd   st,st(0) ;// a11    b0     a0     sf     Y1     Y2
    ;// a2  = sf-Q2
        fxch   st(3)    ;// sf     b0     a0     a11    Y1     Y2
        fsub   Q2       ;// a2     b0     a0     a11    Y1     Y2
    ;// a1y1= Y1*a11
        fxch   st(3)    ;// a11    b0     a0     a2     Y1     Y2
        fmul   st,st(4) ;// a1y1   b0     a0     a2     Y1     Y2
    ;pay attention to ADDRESSES of X
    ;// x01 = XX0-XX1
        fld    X0      ;// XX0    a1y1   b0     a0     a2     Y1     Y2
        fsub   X1 ;<-- ;// x01    a1y1   b0     a0     a2     Y1     Y2
    ;// x12 =-XX1+XX2
        fld    X1      ;// XX1    x01    a1y1   b0     a0     a2     Y1     Y2
        fsubr  X2 ;<-- ;// x12    x01    a1y1   b0     a0     a2     Y1     Y2
    ;// a2y2= Y2*a2
        fxch   st(7)    ;// Y2     x01    a1y1   b0     a0     a2     Y1     x12
        fmulp  st(5),st ;// x01    a1y1   b0     a0     a2y2   Y1     x12
    ;// x012= x01+x12
        faddp  st(6),st ;// a1y1   b0     a0     a2y2   Y1     x012
    ;// t1  = a2y2+a1y1
        faddp  st(3),st ;// b0     a0     t1     Y1     x012
    ;// bx  = b0*x012
        fmulp  st(4),st ;// a0     t1     Y1     bx
    ;// t2  = t1+bx
        fxch   st(1)    ;// t1     a0     Y1     bx
        faddp  st(3),st ;// a0     Y1     t2
    ;// BUG!! should produce DIVP not DIVRP
    ;// Y0  = t2/a0
        fdivp st(2),st ;// Y1     Y0

;// 1 //////////////////////////////////////////////////////////////

        IIR_2_CLIPTEST_INLINE

        fst Y0
        inc ecx

        iir_LookupSinCos;// cf     sf     Y1     Y2
    ;// cf1 = math_1+cf
        fld    math_1   ;// math_1 cf     sf     Y1     Y2
        fadd   st,st(1);<--;// cf1    cf     sf     Y1     Y2
    ;// a1  = Q2*cf
        fxch   st(1)    ;// cf     cf1    sf     Y1     Y2
        fmul   Q2       ;// a1     cf1    sf     Y1     Y2
    ;// a0  = sf+Q2
        fld    Q2       ;// Q2     a1     cf1    sf     Y1     Y2
        fadd   st,st(3) ;// a0     a1     cf1    sf     Y1     Y2
    ;// b0  = G*cf1
        fxch   st(2)    ;// cf1    a1     a0     sf     Y1     Y2
        fmul   G0        ;// b0     a1     a0     sf     Y1     Y2
    ;// a11 = a1+a1
        fxch   st(1)    ;// a1     b0     a0     sf     Y1     Y2
        fadd   st,st(0) ;// a11    b0     a0     sf     Y1     Y2
    ;// a2  = sf-Q2
        fxch   st(3)    ;// sf     b0     a0     a11    Y1     Y2
        fsub   Q2       ;// a2     b0     a0     a11    Y1     Y2
    ;// a1y1= Y1*a11
        fxch   st(3)    ;// a11    b0     a0     a2     Y1     Y2
        fmul   st,st(4) ;// a1y1   b0     a0     a2     Y1     Y2
    ;pay attention to ADDRESSES of X
    ;// x01 = XX0-XX1
        fld    X0       ;// XX0    a1y1   b0     a0     a2     Y1     Y2
        fsub   XX1 ;<-- ;// x01    a1y1   b0     a0     a2     Y1     Y2
    ;// x12 =-XX1+XX2
        fld    XX1      ;// XX1    x01    a1y1   b0     a0     a2     Y1     Y2
        fsubr  X1  ;<-- ;// x12    x01    a1y1   b0     a0     a2     Y1     Y2
    ;// a2y2= Y2*a2
        fxch   st(7)    ;// Y2     x01    a1y1   b0     a0     a2     Y1     x12
        fmulp  st(5),st ;// x01    a1y1   b0     a0     a2y2   Y1     x12
    ;// x012= x01+x12
        faddp  st(6),st ;// a1y1   b0     a0     a2y2   Y1     x012
    ;// t1  = a2y2+a1y1
        faddp  st(3),st ;// b0     a0     t1     Y1     x012
    ;// bx  = b0*x012
        fmulp  st(4),st ;// a0     t1     Y1     bx
    ;// t2  = t1+bx
        fxch   st(1)    ;// t1     a0     Y1     bx
        faddp  st(3),st ;// a0     Y1     t2
    ;// BUG!! should produce DIVP not DIVRP
    ;// Y0  = t2/a0
        fdivp st(2),st ;// Y1     Y0

;// loop ///////////////////////////////////////////////////////////

    IIR_dX_dF_sL_HP2_top:

        IIR_2_CLIPTEST  ;// Y0  Y1

        fst Y0
        inc ecx
        cmp ecx, SAMARY_LENGTH
        jae IIR_dX_dF_sL_HP2_done

        iir_LookupSinCos;// cf     sf     Y1     Y2
    ;// cf1 = math_1+cf
        fld    math_1   ;// math_1 cf     sf     Y1     Y2
        fadd   st,st(1);<--;// cf1    cf     sf     Y1     Y2
    ;// a1  = Q2*cf
        fxch   st(1)    ;// cf     cf1    sf     Y1     Y2
        fmul   Q2       ;// a1     cf1    sf     Y1     Y2
    ;// a0  = sf+Q2
        fld    Q2       ;// Q2     a1     cf1    sf     Y1     Y2
        fadd   st,st(3) ;// a0     a1     cf1    sf     Y1     Y2
    ;// b0  = G*cf1
        fxch   st(2)    ;// cf1    a1     a0     sf     Y1     Y2
        fmul   G0        ;// b0     a1     a0     sf     Y1     Y2
    ;// a11 = a1+a1
        fxch   st(1)    ;// a1     b0     a0     sf     Y1     Y2
        fadd   st,st(0) ;// a11    b0     a0     sf     Y1     Y2
    ;// a2  = sf-Q2
        fxch   st(3)    ;// sf     b0     a0     a11    Y1     Y2
        fsub   Q2       ;// a2     b0     a0     a11    Y1     Y2
    ;// a1y1= Y1*a11
        fxch   st(3)    ;// a11    b0     a0     a2     Y1     Y2
        fmul   st,st(4) ;// a1y1   b0     a0     a2     Y1     Y2
    ;pay attention to ADDRESSES of X
    ;// x01 = XX0-XX1
        fld    XX0      ;// XX0    a1y1   b0     a0     a2     Y1     Y2
        fsub   XX1 ;<-- ;// x01    a1y1   b0     a0     a2     Y1     Y2
    ;// x12 =-XX1+XX2
        fld    XX1      ;// XX1    x01    a1y1   b0     a0     a2     Y1     Y2
        fsubr  XX2 ;<-- ;// x12    x01    a1y1   b0     a0     a2     Y1     Y2
    ;// a2y2= Y2*a2
        fxch   st(7)    ;// Y2     x01    a1y1   b0     a0     a2     Y1     x12
        fmulp  st(5),st ;// x01    a1y1   b0     a0     a2y2   Y1     x12
    ;// x012= x01+x12
        faddp  st(6),st ;// a1y1   b0     a0     a2y2   Y1     x012
    ;// t1  = a2y2+a1y1
        faddp  st(3),st ;// b0     a0     t1     Y1     x012
    ;// bx  = b0*x012
        fmulp  st(4),st ;// a0     t1     Y1     bx
    ;// t2  = t1+bx
        fxch   st(1)    ;// t1     a0     Y1     bx
        faddp  st(3),st ;// a0     Y1     t2
    ;// BUG!! should produce DIVP not DIVRP
    ;// Y0  = t2/a0
        fdivp st(2),st ;// Y1     Y0

        jmp IIR_dX_dF_sL_HP2_top

    ;/////////////////
    IIR_2_CLIPTEST_FIX


IIR_dX_dF_sL_HP2 ENDP


;//
;// iir_dX_dF_sL_BP2.asm      generated by FpuOpt3 from iir_dX_dF_sL_BP2.txt
;//
;// iir dX dF dL nG BP2                     GG=1 for auto gain
;//                                         GG=Q for noauto
;// (sin(F*pi)-2*Q)*Y2 + (sin(F*pi))*(X0-X2)*GG + 4*Q*Y1*cos(F*pi)
;// ------------------------------------------------------------
;//                          2*Q+sin(F*pi)

ALIGN 16
IIR_sX_dF_sL_nG_BP2:
IIR_dX_dF_sL_nG_BP2:    iir_build_Q
                        fst G0
                        fadd st, st
                        fstp Q2
                        jmp IIR_dX_dF_sL_BP2

ALIGN 16
IIR_sX_dF_sL_aG_BP2:
IIR_dX_dF_sL_aG_BP2:    iir_build_Q
                        fadd st, st
                        mov eax, math_1
                        fstp Q2
                        mov G0, eax
IIR_dX_dF_sL_BP2 PROC

        fld Y2
        fld Y1

    ;// 0 ///////////////////////////////////////////////////////////////////////////////

        iir_LookupSinCos;// cf     sf     Y1     Y2

    ;pay attention to ADDRESSES of X
    ;// x02 = XX0-XX2
        fld    X0      ;// XX0    cf     sf     Y1     Y2
        fsub   X2      ;// x02    cf     sf     Y1     Y2
    ;// a1  = Q2*cf
        fxch   st(1)    ;// cf     x02    sf     Y1     Y2
        fmul   Q2       ;// a1     x02    sf     Y1     Y2
    ;// a0  = sf+Q2
        fld    Q2       ;// Q2     a1     x02    sf     Y1     Y2
        fadd   st,st(3) ;// a0     a1     x02    sf     Y1     Y2
    ;// bx  = sf*x02
        fxch   st(2)    ;// x02    a1     a0     sf     Y1     Y2
        fmul   st,st(3) ;// bx     a1     a0     sf     Y1     Y2
    ;// a11 = a1+a1
        fxch   st(1)    ;// a1     bx     a0     sf     Y1     Y2
        fadd   st,st(0) ;// a11    bx     a0     sf     Y1     Y2
    ;// a2  = sf-Q2
        fxch   st(3)    ;// sf     bx     a0     a11    Y1     Y2
        fsub   Q2       ;// a2     bx     a0     a11    Y1     Y2
    ;// bxg = bx*G0
        fxch   st(1)    ;// bx     a2     a0     a11    Y1     Y2
        fmul   G0       ;// bxg    a2     a0     a11    Y1     Y2
    ;// a1y1= Y1*a11
        fxch   st(3)    ;// a11    a2     a0     bxg    Y1     Y2
        fmul   st,st(4) ;// a1y1   a2     a0     bxg    Y1     Y2
    ;// a2y2= Y2*a2
        fxch   st(5)    ;// Y2     a2     a0     bxg    Y1     a1y1
        fmulp  st(1),st ;// a2y2   a0     bxg    Y1     a1y1
    ;// t1  = a2y2+a1y1
        faddp  st(4),st ;// a0     bxg    Y1     t1
    ;// t2  = t1+bxg
        fxch   st(3)    ;// t1     bxg    Y1     a0
        faddp  st(1),st ;// t2     Y1     a0

    ;// Y0  = t2/a0
        fdivrp st(2),st ;// Y1     Y0

    ;// 1 ///////////////////////////////////////////////////////////////////////////////

        IIR_2_CLIPTEST_INLINE

        fst Y0
        inc ecx

        iir_LookupSinCos;// cf     sf     Y1     Y2

    ;pay attention to ADDRESSES of X
    ;// x02 = XX0-XX2
        fld    X0      ;// XX0    cf     sf     Y1     Y2
        fsub   X1      ;// x02    cf     sf     Y1     Y2
    ;// a1  = Q2*cf
        fxch   st(1)    ;// cf     x02    sf     Y1     Y2
        fmul   Q2       ;// a1     x02    sf     Y1     Y2
    ;// a0  = sf+Q2
        fld    Q2       ;// Q2     a1     x02    sf     Y1     Y2
        fadd   st,st(3) ;// a0     a1     x02    sf     Y1     Y2
    ;// bx  = sf*x02
        fxch   st(2)    ;// x02    a1     a0     sf     Y1     Y2
        fmul   st,st(3) ;// bx     a1     a0     sf     Y1     Y2
    ;// a11 = a1+a1
        fxch   st(1)    ;// a1     bx     a0     sf     Y1     Y2
        fadd   st,st(0) ;// a11    bx     a0     sf     Y1     Y2
    ;// a2  = sf-Q2
        fxch   st(3)    ;// sf     bx     a0     a11    Y1     Y2
        fsub   Q2       ;// a2     bx     a0     a11    Y1     Y2
    ;// bxg = bx*G0
        fxch   st(1)    ;// bx     a2     a0     a11    Y1     Y2
        fmul   G0       ;// bxg    a2     a0     a11    Y1     Y2
    ;// a1y1= Y1*a11
        fxch   st(3)    ;// a11    a2     a0     bxg    Y1     Y2
        fmul   st,st(4) ;// a1y1   a2     a0     bxg    Y1     Y2
    ;// a2y2= Y2*a2
        fxch   st(5)    ;// Y2     a2     a0     bxg    Y1     a1y1
        fmulp  st(1),st ;// a2y2   a0     bxg    Y1     a1y1
    ;// t1  = a2y2+a1y1
        faddp  st(4),st ;// a0     bxg    Y1     t1
    ;// t2  = t1+bxg
        fxch   st(3)    ;// t1     bxg    Y1     a0
        faddp  st(1),st ;// t2     Y1     a0

    ;// Y0  = t2/a0
        fdivrp st(2),st ;// Y1     Y0

    ;// LOOP ///////////////////////////////////////////////////////////////////////////////
    iir_dX_dF_sL_BP2_top:

        IIR_2_CLIPTEST  ;// Y0  Y1

        fst Y0
        inc ecx
        cmp ecx, SAMARY_LENGTH
        jae IIR_dX_dF_sL_BP2_done

        iir_LookupSinCos;// cf     sf     Y1     Y2

    ;pay attention to ADDRESSES of X
    ;// x02 = XX0-XX2
        fld    X0      ;// XX0    cf     sf     Y1     Y2
        fsub   XX2      ;// x02    cf     sf     Y1     Y2
    ;// a1  = Q2*cf
        fxch   st(1)    ;// cf     x02    sf     Y1     Y2
        fmul   Q2       ;// a1     x02    sf     Y1     Y2
    ;// a0  = sf+Q2
        fld    Q2       ;// Q2     a1     x02    sf     Y1     Y2
        fadd   st,st(3) ;// a0     a1     x02    sf     Y1     Y2
    ;// bx  = sf*x02
        fxch   st(2)    ;// x02    a1     a0     sf     Y1     Y2
        fmul   st,st(3) ;// bx     a1     a0     sf     Y1     Y2
    ;// a11 = a1+a1
        fxch   st(1)    ;// a1     bx     a0     sf     Y1     Y2
        fadd   st,st(0) ;// a11    bx     a0     sf     Y1     Y2
    ;// a2  = sf-Q2
        fxch   st(3)    ;// sf     bx     a0     a11    Y1     Y2
        fsub   Q2       ;// a2     bx     a0     a11    Y1     Y2
    ;// bxg = bx*G0
        fxch   st(1)    ;// bx     a2     a0     a11    Y1     Y2
        fmul   G0       ;// bxg    a2     a0     a11    Y1     Y2
    ;// a1y1= Y1*a11
        fxch   st(3)    ;// a11    a2     a0     bxg    Y1     Y2
        fmul   st,st(4) ;// a1y1   a2     a0     bxg    Y1     Y2
    ;// a2y2= Y2*a2
        fxch   st(5)    ;// Y2     a2     a0     bxg    Y1     a1y1
        fmulp  st(1),st ;// a2y2   a0     bxg    Y1     a1y1
    ;// t1  = a2y2+a1y1
        faddp  st(4),st ;// a0     bxg    Y1     t1
    ;// t2  = t1+bxg
        fxch   st(3)    ;// t1     bxg    Y1     a0
        faddp  st(1),st ;// t2     Y1     a0

    ;// Y0  = t2/a0
        fdivrp st(2),st ;// Y1     Y0

        jmp iir_dX_dF_sL_BP2_top

    ;/////////////////
    IIR_2_CLIPTEST_FIX

IIR_dX_dF_sL_BP2 ENDP




;//
;// iir dX dF sL BR2              G=1 for auto gain
;//                               G=Q otherwise
;// (X2-Y2)*(2*Q-sf) + (Y1-X1)*2*Q2*cf + sf*(X2-X0)*G
;// ------------------------------------------------- + X0
;//           2*Q+sin(F*pi)

ALIGN 16
IIR_sX_dF_sL_nG_BR2:
IIR_dX_dF_sL_nG_BR2:    iir_build_Q
                        fst G0
                        fadd st, st
                        fstp Q2
                        jmp IIR_dX_dF_sL_BR2

ALIGN 16
IIR_sX_dF_sL_aG_BR2:
IIR_dX_dF_sL_aG_BR2:    iir_build_Q
                        fadd st, st
                        fstp Q2
                        mov eax, math_1
                        mov G0, eax

IIR_dX_dF_sL_BR2 PROC

        fld Y2
        fld Y1

    ;// 0 //////////////////////////////////////////////////////////////////////
;// iir_dX_dF_sL_BR2.asm      generated by FpuOpt3 from iir_dX_dF_sL_BR2.txt

        iir_LookupSinCos;// cf     sf     Y1     Y2

    ;ADDRESS XX1
    ;// x1y1 = Y1-XX1
        fld    X1      ;// XX1    cf     sf     Y1     Y2
        fsubr  st,st(3) ;// x1y1   cf     sf     Y1     Y2
    ;// cf2 = Q2*cf
        fxch   st(1)    ;// cf     x1y1   sf     Y1     Y2
        fmul   Q2       ;// cf2    x1y1   sf     Y1     Y2
    ;// sf2 = Q2-sf
        fld    Q2       ;// Q2     cf2    x1y1   sf     Y1     Y2
        fsub   st,st(3) ;// sf2    cf2    x1y1   sf     Y1     Y2
    ;// sf1 = Q2+sf
        fld    Q2       ;// Q2     sf2    cf2    x1y1   sf     Y1     Y2
        fadd   st,st(4) ;// sf1    sf2    cf2    x1y1   sf     Y1     Y2
    ;// cf22 = cf2+cf2
        fxch   st(2)    ;// cf2    sf2    sf1    x1y1   sf     Y1     Y2
        fadd   st,st(0) ;// cf22   sf2    sf1    x1y1   sf     Y1     Y2
    ;ADDRESS XX2
    ;// x2x0 = XX2-X0
        fld    X2      ;// XX2    cf22   sf2    sf1    x1y1   sf     Y1     Y2
        fsub   X0       ;// x2x0   cf22   sf2    sf1    x1y1   sf     Y1     Y2
    ;// x2y2 = XX2-Y2
        fxch   st(7)    ;// Y2     cf22   sf2    sf1    x1y1   sf     Y1     x2x0
        fsubr  X2      ;// x2y2   cf22   sf2    sf1    x1y1   sf     Y1     x2x0
    ;// T2 = cf22*x1y1
        fxch   st(1)    ;// cf22   x2y2   sf2    sf1    x1y1   sf     Y1     x2x0
        fmulp  st(4),st ;// x2y2   sf2    sf1    T2     sf     Y1     x2x0
    ;// sx2=sf*G0
        fxch   st(4)    ;// sf     sf2    sf1    T2     x2y2   Y1     x2x0
        fmul   G0       ;// sx2    sf2    sf1    T2     x2y2   Y1     x2x0
    ;// T1 = sf2*x2y2
        fxch   st(1)    ;// sf2    sx2    sf1    T2     x2y2   Y1     x2x0
        fmulp  st(4),st ;// sx2    sf1    T2     T1     Y1     x2x0
    ;// T0 = X0*sf1
        fld    X0       ;// X0     sx2    sf1    T2     T1     Y1     x2x0
        fmul   st,st(2) ;// T0     sx2    sf1    T2     T1     Y1     x2x0
    ;// T3 = sx2*x2x0
        fxch   st(1)    ;// sx2    T0     sf1    T2     T1     Y1     x2x0
        fmulp  st(6),st ;// T0     sf1    T2     T1     Y1     T3
    ;// S0 = T1+T2
        fxch   st(3)    ;// T1     sf1    T2     T0     Y1     T3
        faddp  st(2),st ;// sf1    S0     T0     Y1     T3
    ;// S1 = T0+T3
        fxch   st(2)    ;// T0     S0     sf1    Y1     T3
        faddp  st(4),st ;// S0     sf1    Y1     S1
    ;// S2 = S0+S1
        faddp  st(3),st ;// sf1    Y1     S2
    ;BUG!!! should emit FDIV not FDIVR
    ;// Y0 = S2/sf1
        fdivp st(2),st ;// Y1     Y0

        IIR_2_CLIPTEST_INLINE

        fst Y0
        inc ecx

    ;// 1 //////////////////////////////////////////////////////////////////////

        iir_LookupSinCos;// cf     sf     Y1     Y2

    ;ADDRESS XX1
    ;// x1y1 = Y1-XX1
        fld    XX1      ;// XX1    cf     sf     Y1     Y2
        fsubr  st,st(3) ;// x1y1   cf     sf     Y1     Y2
    ;// cf2 = Q2*cf
        fxch   st(1)    ;// cf     x1y1   sf     Y1     Y2
        fmul   Q2       ;// cf2    x1y1   sf     Y1     Y2
    ;// sf2 = Q2-sf
        fld    Q2       ;// Q2     cf2    x1y1   sf     Y1     Y2
        fsub   st,st(3) ;// sf2    cf2    x1y1   sf     Y1     Y2
    ;// sf1 = Q2+sf
        fld    Q2       ;// Q2     sf2    cf2    x1y1   sf     Y1     Y2
        fadd   st,st(4) ;// sf1    sf2    cf2    x1y1   sf     Y1     Y2
    ;// cf22 = cf2+cf2
        fxch   st(2)    ;// cf2    sf2    sf1    x1y1   sf     Y1     Y2
        fadd   st,st(0) ;// cf22   sf2    sf1    x1y1   sf     Y1     Y2
    ;ADDRESS XX2
    ;// x2x0 = XX2-X0
        fld    X1      ;// XX2    cf22   sf2    sf1    x1y1   sf     Y1     Y2
        fsub   X0       ;// x2x0   cf22   sf2    sf1    x1y1   sf     Y1     Y2
    ;// x2y2 = XX2-Y2
        fxch   st(7)    ;// Y2     cf22   sf2    sf1    x1y1   sf     Y1     x2x0
        fsubr  X1      ;// x2y2   cf22   sf2    sf1    x1y1   sf     Y1     x2x0
    ;// T2 = cf22*x1y1
        fxch   st(1)    ;// cf22   x2y2   sf2    sf1    x1y1   sf     Y1     x2x0
        fmulp  st(4),st ;// x2y2   sf2    sf1    T2     sf     Y1     x2x0
    ;// sx2=sf*G0
        fxch   st(4)    ;// sf     sf2    sf1    T2     x2y2   Y1     x2x0
        fmul   G0       ;// sx2    sf2    sf1    T2     x2y2   Y1     x2x0
    ;// T1 = sf2*x2y2
        fxch   st(1)    ;// sf2    sx2    sf1    T2     x2y2   Y1     x2x0
        fmulp  st(4),st ;// sx2    sf1    T2     T1     Y1     x2x0
    ;// T0 = X0*sf1
        fld    X0       ;// X0     sx2    sf1    T2     T1     Y1     x2x0
        fmul   st,st(2) ;// T0     sx2    sf1    T2     T1     Y1     x2x0
    ;// T3 = sx2*x2x0
        fxch   st(1)    ;// sx2    T0     sf1    T2     T1     Y1     x2x0
        fmulp  st(6),st ;// T0     sf1    T2     T1     Y1     T3
    ;// S0 = T1+T2
        fxch   st(3)    ;// T1     sf1    T2     T0     Y1     T3
        faddp  st(2),st ;// sf1    S0     T0     Y1     T3
    ;// S1 = T0+T3
        fxch   st(2)    ;// T0     S0     sf1    Y1     T3
        faddp  st(4),st ;// S0     sf1    Y1     S1
    ;// S2 = S0+S1
        faddp  st(3),st ;// sf1    Y1     S2
    ;BUG!!! should emit FDIV not FDIVR
    ;// Y0 = S2/sf1
        fdivp st(2),st ;// Y1     Y0

    ;// LOOP //////////////////////////////////////////////////////////////////////

    IIR_dX_dF_sL_BR2_top:

        IIR_2_CLIPTEST  ;// Y0  Y1

        fst Y0
        inc ecx
        cmp ecx, SAMARY_LENGTH
        jae IIR_dX_dF_sL_BR2_done

        iir_LookupSinCos;// cf     sf     Y1     Y2

    ;ADDRESS XX1
    ;// x1y1 = Y1-XX1
        fld    XX1      ;// XX1    cf     sf     Y1     Y2
        fsubr  st,st(3) ;// x1y1   cf     sf     Y1     Y2
    ;// cf2 = Q2*cf
        fxch   st(1)    ;// cf     x1y1   sf     Y1     Y2
        fmul   Q2       ;// cf2    x1y1   sf     Y1     Y2
    ;// sf2 = Q2-sf
        fld    Q2       ;// Q2     cf2    x1y1   sf     Y1     Y2
        fsub   st,st(3) ;// sf2    cf2    x1y1   sf     Y1     Y2
    ;// sf1 = Q2+sf
        fld    Q2       ;// Q2     sf2    cf2    x1y1   sf     Y1     Y2
        fadd   st,st(4) ;// sf1    sf2    cf2    x1y1   sf     Y1     Y2
    ;// cf22 = cf2+cf2
        fxch   st(2)    ;// cf2    sf2    sf1    x1y1   sf     Y1     Y2
        fadd   st,st(0) ;// cf22   sf2    sf1    x1y1   sf     Y1     Y2
    ;ADDRESS XX2
    ;// x2x0 = XX2-X0
        fld    XX2      ;// XX2    cf22   sf2    sf1    x1y1   sf     Y1     Y2
        fsub   X0       ;// x2x0   cf22   sf2    sf1    x1y1   sf     Y1     Y2
    ;// x2y2 = XX2-Y2
        fxch   st(7)    ;// Y2     cf22   sf2    sf1    x1y1   sf     Y1     x2x0
        fsubr  XX2      ;// x2y2   cf22   sf2    sf1    x1y1   sf     Y1     x2x0
    ;// T2 = cf22*x1y1
        fxch   st(1)    ;// cf22   x2y2   sf2    sf1    x1y1   sf     Y1     x2x0
        fmulp  st(4),st ;// x2y2   sf2    sf1    T2     sf     Y1     x2x0
    ;// sx2=sf*G0
        fxch   st(4)    ;// sf     sf2    sf1    T2     x2y2   Y1     x2x0
        fmul   G0       ;// sx2    sf2    sf1    T2     x2y2   Y1     x2x0
    ;// T1 = sf2*x2y2
        fxch   st(1)    ;// sf2    sx2    sf1    T2     x2y2   Y1     x2x0
        fmulp  st(4),st ;// sx2    sf1    T2     T1     Y1     x2x0
    ;// T0 = X0*sf1
        fld    X0       ;// X0     sx2    sf1    T2     T1     Y1     x2x0
        fmul   st,st(2) ;// T0     sx2    sf1    T2     T1     Y1     x2x0
    ;// T3 = sx2*x2x0
        fxch   st(1)    ;// sx2    T0     sf1    T2     T1     Y1     x2x0
        fmulp  st(6),st ;// T0     sf1    T2     T1     Y1     T3
    ;// S0 = T1+T2
        fxch   st(3)    ;// T1     sf1    T2     T0     Y1     T3
        faddp  st(2),st ;// sf1    S0     T0     Y1     T3
    ;// S1 = T0+T3
        fxch   st(2)    ;// T0     S0     sf1    Y1     T3
        faddp  st(4),st ;// S0     sf1    Y1     S1
    ;// S2 = S0+S1
        faddp  st(3),st ;// sf1    Y1     S2
    ;BUG!!! should emit FDIV not FDIVR
    ;// Y0 = S2/sf1
        fdivp st(2),st ;// Y1     Y0

        jmp IIR_dX_dF_sL_BR2_top

    ;/////////////////
    IIR_2_CLIPTEST_FIX



IIR_dX_dF_sL_BR2 ENDP







ALIGN 16
IIR_sX_sF_dL_nG_LP2:
IIR_sX_dF_dL_nG_LP2:
IIR_dX_sF_dL_nG_LP2:
IIR_dX_dF_dL_nG_LP2:
IIR_sX_sF_dL_aG_LP2:
IIR_sX_dF_dL_aG_LP2:
IIR_dX_sF_dL_aG_LP2:        ;// sF only 8 cycles out of 200 are saved, not worth the code space
IIR_dX_dF_dL_aG_LP2:

IIR_dX_dF_dL_LP2 PROC

    ;// iir dX dF dL LP2      generated by FpuOpt3 from iir_dX_dF_dL_LP2.txt
    ;//
    ;// (sin(F*pi)-2*Q)*Y2 + (1-cos(F*pi))*(X0+2*X1+X2)*GG+4*Q*Y1*cos(F*pi)
    ;// ----------------------------------------------------------------------
    ;//                        2*Q+sin(F*pi)

    ;// we do two iteartions to get to the loop

        fld Y2
        fld Y1

;// 0 ///////////////////////////////////////////////////////////////////////////

        iir_LookupSinCos;// cf     sf     Y1     Y2
        iir_build_Q     ;// Q      cf     sf     Y1     Y2
        .IF [esi].dwUser & IIR_AUTO_GAIN
            iir_build_aG;// G      Q2     cf     sf     Y1     Y2
        .ELSE
            iir_build_nG
        .ENDIF
    ;// cf1 = one-cf
        fld    math_1      ;// one    G      Q2     cf     sf     Y1     Y2
        fsub   st,st(3) ;// cf1    G      Q2     cf     sf     Y1     Y2
    ;// a1  = Q2*cf
        fxch   st(3)    ;// cf     G      Q2     cf1    sf     Y1     Y2
        fmul   st,st(2) ;// a1     G      Q2     cf1    sf     Y1     Y2
    ;// a0  = sf+Q2
        fld    st(4)    ;// sf     a1     G      Q2     cf1    sf     Y1     Y2
        fadd   st,st(3) ;// a0     a1     G      Q2     cf1    sf     Y1     Y2
    ;// b0  = G*cf1
        fxch   st(2)    ;// G      a1     a0     Q2     cf1    sf     Y1     Y2
        fmulp  st(4),st ;// a1     a0     Q2     b0     sf     Y1     Y2
    ;// a11 = a1+a1
        fadd   st,st(0) ;// a11    a0     Q2     b0     sf     Y1     Y2
    ;// a2  = sf-Q2
        fxch   st(4)    ;// sf     a0     Q2     b0     a11    Y1     Y2
        fsubrp st(2),st ;// a0     a2     b0     a11    Y1     Y2
    ;// a1y1= Y1*a11
        fxch   st(3)    ;// a11    a2     b0     a0     Y1     Y2
        fmul   st,st(4) ;// a1y1   a2     b0     a0     Y1     Y2
    ;// x01 = X0+X1
; pay attention to addresses of X
        fld    X0      ;// X0     a1y1   a2     b0     a0     Y1     Y2
        fadd   X1      ;// x01    a1y1   a2     b0     a0     Y1     Y2
    ;// x12 = X1+X2
        fld    X1      ;// X1     x01    a1y1   a2     b0     a0     Y1     Y2
        fadd   X2      ;// x12    x01    a1y1   a2     b0     a0     Y1     Y2
    ;// a2y2= Y2*a2
        fxch   st(7)    ;// Y2     x01    a1y1   a2     b0     a0     Y1     x12
        fmulp  st(3),st ;// x01    a1y1   a2y2   b0     a0     Y1     x12
    ;// x012= x01+x12
        faddp  st(6),st ;// a1y1   a2y2   b0     a0     Y1     x012
    ;// t1  = a2y2+a1y1
        faddp  st(1),st ;// t1     b0     a0     Y1     x012
    ;// bx  = b0*x012
        fxch   st(1)    ;// b0     t1     a0     Y1     x012
        fmulp  st(4),st ;// t1     a0     Y1     bx
    ;// t2  = t1+bx
        faddp  st(3),st ;// a0     Y1     t2
    ;// Y0  = t2/a0
        fdivp st(2),st ;// Y1     Y0

;// 1 ///////////////////////////////////////////////////////////////////////////

        IIR_2_CLIPTEST_INLINE

        fst Y0
        inc ecx

        iir_LookupSinCos;// cf     sf     Y1     Y2
        iir_build_Q     ;// Q      cf     sf     Y1     Y2
        .IF [esi].dwUser & IIR_AUTO_GAIN
            iir_build_aG;// G      Q2     cf     sf     Y1     Y2
        .ELSE
            iir_build_nG
        .ENDIF
    ;// cf1 = one-cf
        fld    math_1   ;// one    G      Q2     cf     sf     Y1     Y2
        fsub   st,st(3) ;// cf1    G      Q2     cf     sf     Y1     Y2
    ;// a1  = Q2*cf
        fxch   st(3)    ;// cf     G      Q2     cf1    sf     Y1     Y2
        fmul   st,st(2) ;// a1     G      Q2     cf1    sf     Y1     Y2
    ;// a0  = sf+Q2
        fld    st(4)    ;// sf     a1     G      Q2     cf1    sf     Y1     Y2
        fadd   st,st(3) ;// a0     a1     G      Q2     cf1    sf     Y1     Y2
    ;// b0  = G*cf1
        fxch   st(2)    ;// G      a1     a0     Q2     cf1    sf     Y1     Y2
        fmulp  st(4),st ;// a1     a0     Q2     b0     sf     Y1     Y2
    ;// a11 = a1+a1
        fadd   st,st(0) ;// a11    a0     Q2     b0     sf     Y1     Y2
    ;// a2  = sf-Q2
        fxch   st(4)    ;// sf     a0     Q2     b0     a11    Y1     Y2
        fsubrp st(2),st ;// a0     a2     b0     a11    Y1     Y2
    ;// a1y1= Y1*a11
        fxch   st(3)    ;// a11    a2     b0     a0     Y1     Y2
        fmul   st,st(4) ;// a1y1   a2     b0     a0     Y1     Y2
    ;// x01 = X0+X1
; pay attention to addresses of X
        fld    X0       ;// X0     a1y1   a2     b0     a0     Y1     Y2
        fadd   XX1      ;// x01    a1y1   a2     b0     a0     Y1     Y2
    ;// x12 = X1+X2
        fld    XX1      ;// X1     x01    a1y1   a2     b0     a0     Y1     Y2
        fadd   X1       ;// x12    x01    a1y1   a2     b0     a0     Y1     Y2
    ;// a2y2= Y2*a2
        fxch   st(7)    ;// Y2     x01    a1y1   a2     b0     a0     Y1     x12
        fmulp  st(3),st ;// x01    a1y1   a2y2   b0     a0     Y1     x12
    ;// x012= x01+x12
        faddp  st(6),st ;// a1y1   a2y2   b0     a0     Y1     x012
    ;// t1  = a2y2+a1y1
        faddp  st(1),st ;// t1     b0     a0     Y1     x012
    ;// bx  = b0*x012
        fxch   st(1)    ;// b0     t1     a0     Y1     x012
        fmulp  st(4),st ;// t1     a0     Y1     bx
    ;// t2  = t1+bx
        faddp  st(3),st ;// a0     Y1     t2
    ;// Y0  = t2/a0
        fdivp st(2),st ;// Y1     Y0

;// LOOP

    IIR_dX_dF_dL_LP2_top:

        IIR_2_CLIPTEST  ;// Y0  Y1

        fst Y0
        inc ecx
        cmp ecx, SAMARY_LENGTH
        jae IIR_dX_dF_dL_LP2_done

        iir_LookupSinCos;// cf     sf     Y1     Y2
        iir_build_Q     ;// Q      cf     sf     Y1     Y2
        .IF [esi].dwUser & IIR_AUTO_GAIN
            iir_build_aG;// G      Q2     cf     sf     Y1     Y2
        .ELSE
            iir_build_nG
        .ENDIF
    ;// cf1 = one-cf
        fld    math_1   ;// one    G      Q2     cf     sf     Y1     Y2
        fsub   st,st(3) ;// cf1    G      Q2     cf     sf     Y1     Y2
    ;// a1  = Q2*cf
        fxch   st(3)    ;// cf     G      Q2     cf1    sf     Y1     Y2
        fmul   st,st(2) ;// a1     G      Q2     cf1    sf     Y1     Y2
    ;// a0  = sf+Q2
        fld    st(4)    ;// sf     a1     G      Q2     cf1    sf     Y1     Y2
        fadd   st,st(3) ;// a0     a1     G      Q2     cf1    sf     Y1     Y2
    ;// b0  = G*cf1
        fxch   st(2)    ;// G      a1     a0     Q2     cf1    sf     Y1     Y2
        fmulp  st(4),st ;// a1     a0     Q2     b0     sf     Y1     Y2
    ;// a11 = a1+a1
        fadd   st,st(0) ;// a11    a0     Q2     b0     sf     Y1     Y2
    ;// a2  = sf-Q2
        fxch   st(4)    ;// sf     a0     Q2     b0     a11    Y1     Y2
        fsubrp st(2),st ;// a0     a2     b0     a11    Y1     Y2
    ;// a1y1= Y1*a11
        fxch   st(3)    ;// a11    a2     b0     a0     Y1     Y2
        fmul   st,st(4) ;// a1y1   a2     b0     a0     Y1     Y2
    ;// x01 = X0+X1
; pay attention to addresses of X
        fld    XX0      ;// X0     a1y1   a2     b0     a0     Y1     Y2
        fadd   XX1      ;// x01    a1y1   a2     b0     a0     Y1     Y2
    ;// x12 = X1+X2
        fld    XX1      ;// X1     x01    a1y1   a2     b0     a0     Y1     Y2
        fadd   XX2      ;// x12    x01    a1y1   a2     b0     a0     Y1     Y2
    ;// a2y2= Y2*a2
        fxch   st(7)    ;// Y2     x01    a1y1   a2     b0     a0     Y1     x12
        fmulp  st(3),st ;// x01    a1y1   a2y2   b0     a0     Y1     x12
    ;// x012= x01+x12
        faddp  st(6),st ;// a1y1   a2y2   b0     a0     Y1     x012
    ;// t1  = a2y2+a1y1
        faddp  st(1),st ;// t1     b0     a0     Y1     x012
    ;// bx  = b0*x012
        fxch   st(1)    ;// b0     t1     a0     Y1     x012
        fmulp  st(4),st ;// t1     a0     Y1     bx
    ;// t2  = t1+bx
        faddp  st(3),st ;// a0     Y1     t2
    ;// Y0  = t2/a0
        fdivp st(2),st ;// Y1     Y0

        jmp IIR_dX_dF_dL_LP2_top


        ;/////////////////
        IIR_2_CLIPTEST_FIX

IIR_dX_dF_dL_LP2 ENDP




ALIGN 16
IIR_sX_sF_dL_nG_HP2:
IIR_sX_dF_dL_nG_HP2:
IIR_dX_sF_dL_nG_HP2:
IIR_dX_dF_dL_nG_HP2:
IIR_sX_sF_dL_aG_HP2:
IIR_sX_dF_dL_aG_HP2:
IIR_dX_sF_dL_aG_HP2:
IIR_dX_dF_dL_aG_HP2:

IIR_dX_dF_dL_HP2 PROC

    ;// xformmed from LP2
    ;//                        v              v
    ;// (sin(F*pi)-2*Q)*Y2 + (1+cos(F*pi))*(X0-2*X1+X2)*GG+4*Q*Y1*cos(F*pi)
    ;// ----------------------------------------------------------------------
    ;//                        2*Q+sin(F*pi)

    ;// we do two iteartions to get to the loop

        fld Y2
        fld Y1

;// 0 ///////////////////////////////////////////////////////////////////////////

        iir_LookupSinCos;// cf     sf     Y1     Y2
        iir_build_Q     ;// Q      cf     sf     Y1     Y2
        .IF [esi].dwUser & IIR_AUTO_GAIN
            iir_build_aG;// G      Q2     cf     sf     Y1     Y2
        .ELSE
            iir_build_nG
        .ENDIF
    ;// cf1 = one+cf
        fld    math_1   ;// one    G      Q2     cf     sf     Y1     Y2
        fadd   st,st(3) ;<-- ;// cf1    G      Q2     cf     sf     Y1     Y2
    ;// a1  = Q2*cf
        fxch   st(3)    ;// cf     G      Q2     cf1    sf     Y1     Y2
        fmul   st,st(2) ;// a1     G      Q2     cf1    sf     Y1     Y2
    ;// a0  = sf+Q2
        fld    st(4)    ;// sf     a1     G      Q2     cf1    sf     Y1     Y2
        fadd   st,st(3) ;// a0     a1     G      Q2     cf1    sf     Y1     Y2
    ;// b0  = G*cf1
        fxch   st(2)    ;// G      a1     a0     Q2     cf1    sf     Y1     Y2
        fmulp  st(4),st ;// a1     a0     Q2     b0     sf     Y1     Y2
    ;// a11 = a1+a1
        fadd   st,st(0) ;// a11    a0     Q2     b0     sf     Y1     Y2
    ;// a2  = sf-Q2
        fxch   st(4)    ;// sf     a0     Q2     b0     a11    Y1     Y2
        fsubrp st(2),st ;// a0     a2     b0     a11    Y1     Y2
    ;// a1y1= Y1*a11
        fxch   st(3)    ;// a11    a2     b0     a0     Y1     Y2
        fmul   st,st(4) ;// a1y1   a2     b0     a0     Y1     Y2
    ;// x01 = X0+X1
; pay attention to addresses of X
        fld    X0      ;// X0     a1y1   a2     b0     a0     Y1     Y2
        fsub   X1 ;<-- ;// x01    a1y1   a2     b0     a0     Y1     Y2
    ;// x12 = -X1+X2
        fld    X1      ;// X1     x01    a1y1   a2     b0     a0     Y1     Y2
        fsubr  X2 ;<-- ;// x12    x01    a1y1   a2     b0     a0     Y1     Y2
    ;// a2y2= Y2*a2
        fxch   st(7)    ;// Y2     x01    a1y1   a2     b0     a0     Y1     x12
        fmulp  st(3),st ;// x01    a1y1   a2y2   b0     a0     Y1     x12
    ;// x012= x01+x12
        faddp  st(6),st ;// a1y1   a2y2   b0     a0     Y1     x012
    ;// t1  = a2y2+a1y1
        faddp  st(1),st ;// t1     b0     a0     Y1     x012
    ;// bx  = b0*x012
        fxch   st(1)    ;// b0     t1     a0     Y1     x012
        fmulp  st(4),st ;// t1     a0     Y1     bx
    ;// t2  = t1+bx
        faddp  st(3),st ;// a0     Y1     t2
    ;// Y0  = t2/a0
        fdivp st(2),st ;// Y1     Y0

;// 1 ///////////////////////////////////////////////////////////////////////////

        IIR_2_CLIPTEST_INLINE

        fst Y0
        inc ecx

        iir_LookupSinCos;// cf     sf     Y1     Y2
        iir_build_Q     ;// Q      cf     sf     Y1     Y2
        .IF [esi].dwUser & IIR_AUTO_GAIN
            iir_build_aG;// G      Q2     cf     sf     Y1     Y2
        .ELSE
            iir_build_nG
        .ENDIF
    ;// cf1 = one+cf ;<--
        fld    math_1   ;// one    G      Q2     cf     sf     Y1     Y2
        fadd   st,st(3);<-- ;// cf1    G      Q2     cf     sf     Y1     Y2
    ;// a1  = Q2*cf
        fxch   st(3)    ;// cf     G      Q2     cf1    sf     Y1     Y2
        fmul   st,st(2) ;// a1     G      Q2     cf1    sf     Y1     Y2
    ;// a0  = sf+Q2
        fld    st(4)    ;// sf     a1     G      Q2     cf1    sf     Y1     Y2
        fadd   st,st(3) ;// a0     a1     G      Q2     cf1    sf     Y1     Y2
    ;// b0  = G*cf1
        fxch   st(2)    ;// G      a1     a0     Q2     cf1    sf     Y1     Y2
        fmulp  st(4),st ;// a1     a0     Q2     b0     sf     Y1     Y2
    ;// a11 = a1+a1
        fadd   st,st(0) ;// a11    a0     Q2     b0     sf     Y1     Y2
    ;// a2  = sf-Q2
        fxch   st(4)    ;// sf     a0     Q2     b0     a11    Y1     Y2
        fsubrp st(2),st ;// a0     a2     b0     a11    Y1     Y2
    ;// a1y1= Y1*a11
        fxch   st(3)    ;// a11    a2     b0     a0     Y1     Y2
        fmul   st,st(4) ;// a1y1   a2     b0     a0     Y1     Y2
; pay attention to addresses of X
    ;// x01 = X0-X1
        fld    X0       ;// X0     a1y1   a2     b0     a0     Y1     Y2
        fsub   XX1 ;<-- ;// x01    a1y1   a2     b0     a0     Y1     Y2
    ;// x12 =-X1+X2
        fld    XX1      ;// X1     x01    a1y1   a2     b0     a0     Y1     Y2
        fsubr  X1  ;<-- ;// x12    x01    a1y1   a2     b0     a0     Y1     Y2
    ;// a2y2= Y2*a2
        fxch   st(7)    ;// Y2     x01    a1y1   a2     b0     a0     Y1     x12
        fmulp  st(3),st ;// x01    a1y1   a2y2   b0     a0     Y1     x12
    ;// x012= x01+x12
        faddp  st(6),st ;// a1y1   a2y2   b0     a0     Y1     x012
    ;// t1  = a2y2+a1y1
        faddp  st(1),st ;// t1     b0     a0     Y1     x012
    ;// bx  = b0*x012
        fxch   st(1)    ;// b0     t1     a0     Y1     x012
        fmulp  st(4),st ;// t1     a0     Y1     bx
    ;// t2  = t1+bx
        faddp  st(3),st ;// a0     Y1     t2
    ;// Y0  = t2/a0
        fdivp st(2),st ;// Y1     Y0

;// LOOP

    IIR_dX_dF_dL_HP2_top:

        IIR_2_CLIPTEST  ;// Y0  Y1

        fst Y0
        inc ecx
        cmp ecx, SAMARY_LENGTH
        jae IIR_dX_dF_dL_HP2_done

        iir_LookupSinCos;// cf     sf     Y1     Y2
        iir_build_Q     ;// Q      cf     sf     Y1     Y2
        .IF [esi].dwUser & IIR_AUTO_GAIN
            iir_build_aG;// G      Q2     cf     sf     Y1     Y2
        .ELSE
            iir_build_nG
        .ENDIF
    ;// cf1 = one+cf
        fld    math_1   ;// one    G      Q2     cf     sf     Y1     Y2
        fadd   st,st(3);<-- ;// cf1    G      Q2     cf     sf     Y1     Y2
    ;// a1  = Q2*cf
        fxch   st(3)    ;// cf     G      Q2     cf1    sf     Y1     Y2
        fmul   st,st(2) ;// a1     G      Q2     cf1    sf     Y1     Y2
    ;// a0  = sf+Q2
        fld    st(4)    ;// sf     a1     G      Q2     cf1    sf     Y1     Y2
        fadd   st,st(3) ;// a0     a1     G      Q2     cf1    sf     Y1     Y2
    ;// b0  = G*cf1
        fxch   st(2)    ;// G      a1     a0     Q2     cf1    sf     Y1     Y2
        fmulp  st(4),st ;// a1     a0     Q2     b0     sf     Y1     Y2
    ;// a11 = a1+a1
        fadd   st,st(0) ;// a11    a0     Q2     b0     sf     Y1     Y2
    ;// a2  = sf-Q2
        fxch   st(4)    ;// sf     a0     Q2     b0     a11    Y1     Y2
        fsubrp st(2),st ;// a0     a2     b0     a11    Y1     Y2
    ;// a1y1= Y1*a11
        fxch   st(3)    ;// a11    a2     b0     a0     Y1     Y2
        fmul   st,st(4) ;// a1y1   a2     b0     a0     Y1     Y2
; pay attention to addresses of X
    ;// x01 = X0-X1
        fld    XX0      ;// X0     a1y1   a2     b0     a0     Y1     Y2
        fsub   XX1 ;<-- ;// x01    a1y1   a2     b0     a0     Y1     Y2
    ;// x12 =-X1+X2
        fld    XX1      ;// X1     x01    a1y1   a2     b0     a0     Y1     Y2
        fsubr  XX2 ;<-- ;// x12    x01    a1y1   a2     b0     a0     Y1     Y2
    ;// a2y2= Y2*a2
        fxch   st(7)    ;// Y2     x01    a1y1   a2     b0     a0     Y1     x12
        fmulp  st(3),st ;// x01    a1y1   a2y2   b0     a0     Y1     x12
    ;// x012= x01+x12
        faddp  st(6),st ;// a1y1   a2y2   b0     a0     Y1     x012
    ;// t1  = a2y2+a1y1
        faddp  st(1),st ;// t1     b0     a0     Y1     x012
    ;// bx  = b0*x012
        fxch   st(1)    ;// b0     t1     a0     Y1     x012
        fmulp  st(4),st ;// t1     a0     Y1     bx
    ;// t2  = t1+bx
        faddp  st(3),st ;// a0     Y1     t2
    ;// Y0  = t2/a0
        fdivp st(2),st ;// Y1     Y0

        jmp IIR_dX_dF_dL_HP2_top


        ;/////////////////
        IIR_2_CLIPTEST_FIX

IIR_dX_dF_dL_HP2 ENDP




ALIGN 16
IIR_sX_sF_dL_nG_BP2:
IIR_dX_sF_dL_nG_BP2:
IIR_sX_dF_dL_nG_BP2:
IIR_dX_dF_dL_nG_BP2:
IIR_sX_sF_dL_aG_BP2:
IIR_sX_dF_dL_aG_BP2:
IIR_dX_sF_dL_aG_BP2:
IIR_dX_dF_dL_aG_BP2:
IIR_dX_dF_dL_BP2 PROC

    ;//
    ;// iir_dX_dF_dL_nG_BP2.asm      generated by FpuOpt3 from iir_dX_dF_dL_nG_BP2.txt
    ;//
    ;// iir dX dF dL BP2 nG                     GG=1 for auto gain
    ;//                                         GG=Q for noauto
    ;// (sin(F*pi)-2*Q)*Y2 + (sin(F*pi))*(X0-X2)*GG + 4*Q*Y1*cos(F*pi)
    ;// ------------------------------------------------------------
    ;//                          2*Q+sin(F*pi)
        fld Y2
        fld Y1

    ;// 0 ////////////////////////////////////////////////////////////////

        iir_LookupSinCos
        iir_build_Q     ;// Q      cf     sf     Y1     Y2
    ;// Q2=Q+Q
    ;// G = 1 or Q
        .IF [esi].dwUser & IIR_AUTO_GAIN
            fadd st, st
            fld math_1
            fxch
        .ELSE
            fld    st(0)    ;// Q      Q      cf     sf     Y1     Y2
            fadd   st,st(0) ;// Q2     Q      cf     sf     Y1     Y2
        .ENDIF
    ;pay attention to ADDRESSES of X
    ;// x02 = XX0-XX2
        fld    X0      ;// XX0    Q2     Q      cf     sf     Y1     Y2
        fsub   X2      ;// x02    Q2     Q      cf     sf     Y1     Y2
    ;// a1  = Q2*cf
        fxch   st(3)    ;// cf     Q2     Q      x02    sf     Y1     Y2
        fmul   st,st(1) ;// a1     Q2     Q      x02    sf     Y1     Y2
    ;// a0  = sf+Q2
        fld    st(4)    ;// sf     a1     Q2     Q      x02    sf     Y1     Y2
        fadd   st,st(2) ;// a0     a1     Q2     Q      x02    sf     Y1     Y2
    ;// bx  = sf*x02
        fxch   st(4)    ;// x02    a1     Q2     Q      a0     sf     Y1     Y2
        fmul   st,st(5) ;// bx     a1     Q2     Q      a0     sf     Y1     Y2
    ;// a11 = a1+a1
        fxch   st(1)    ;// a1     bx     Q2     Q      a0     sf     Y1     Y2
        fadd   st,st(0) ;// a11    bx     Q2     Q      a0     sf     Y1     Y2
    ;// a2  = sf-Q2
        fxch   st(5)    ;// sf     bx     Q2     Q      a0     a11    Y1     Y2
        fsubrp st(2),st ;// bx     a2     Q      a0     a11    Y1     Y2
    ;// bxg = bx*Q
        fmulp  st(2),st ;// a2     bxg    a0     a11    Y1     Y2
    ;// a1y1= Y1*a11
        fxch   st(3)    ;// a11    bxg    a0     a2     Y1     Y2
        fmul   st,st(4) ;// a1y1   bxg    a0     a2     Y1     Y2
    ;// a2y2= Y2*a2
        fxch   st(5)    ;// Y2     bxg    a0     a2     Y1     a1y1
        fmulp  st(3),st ;// bxg    a0     a2y2   Y1     a1y1
    ;// t1  = a2y2+a1y1
        fxch   st(2)    ;// a2y2   a0     bxg    Y1     a1y1
        faddp  st(4),st ;// a0     bxg    Y1     t1
    ;// t2  = t1+bxg
        fxch   st(3)    ;// t1     bxg    Y1     a0
        faddp  st(1),st ;// t2     Y1     a0
    ;// Y0  = t2/a0
        fdivrp st(2),st ;// Y1     Y0

    ;// 1 ////////////////////////////////////////////////////////////////

        IIR_2_CLIPTEST_INLINE

        fst Y0
        inc ecx

        iir_LookupSinCos
        iir_build_Q     ;// Q      cf     sf     Y1     Y2
    ;// Q2=Q+Q
    ;// G = 1 or Q
        .IF [esi].dwUser & IIR_AUTO_GAIN
            fadd st, st
            fld math_1
            fxch
        .ELSE
            fld    st(0)    ;// Q      Q      cf     sf     Y1     Y2
            fadd   st,st(0) ;// Q2     Q      cf     sf     Y1     Y2
        .ENDIF
    ;pay attention to ADDRESSES of X
    ;// x02 = XX0-XX2
        fld    X0      ;// XX0    Q2     Q      cf     sf     Y1     Y2
        fsub   X1      ;// x02    Q2     Q      cf     sf     Y1     Y2
    ;// a1  = Q2*cf
        fxch   st(3)    ;// cf     Q2     Q      x02    sf     Y1     Y2
        fmul   st,st(1) ;// a1     Q2     Q      x02    sf     Y1     Y2
    ;// a0  = sf+Q2
        fld    st(4)    ;// sf     a1     Q2     Q      x02    sf     Y1     Y2
        fadd   st,st(2) ;// a0     a1     Q2     Q      x02    sf     Y1     Y2
    ;// bx  = sf*x02
        fxch   st(4)    ;// x02    a1     Q2     Q      a0     sf     Y1     Y2
        fmul   st,st(5) ;// bx     a1     Q2     Q      a0     sf     Y1     Y2
    ;// a11 = a1+a1
        fxch   st(1)    ;// a1     bx     Q2     Q      a0     sf     Y1     Y2
        fadd   st,st(0) ;// a11    bx     Q2     Q      a0     sf     Y1     Y2
    ;// a2  = sf-Q2
        fxch   st(5)    ;// sf     bx     Q2     Q      a0     a11    Y1     Y2
        fsubrp st(2),st ;// bx     a2     Q      a0     a11    Y1     Y2
    ;// bxg = bx*Q
        fmulp  st(2),st ;// a2     bxg    a0     a11    Y1     Y2
    ;// a1y1= Y1*a11
        fxch   st(3)    ;// a11    bxg    a0     a2     Y1     Y2
        fmul   st,st(4) ;// a1y1   bxg    a0     a2     Y1     Y2
    ;// a2y2= Y2*a2
        fxch   st(5)    ;// Y2     bxg    a0     a2     Y1     a1y1
        fmulp  st(3),st ;// bxg    a0     a2y2   Y1     a1y1
    ;// t1  = a2y2+a1y1
        fxch   st(2)    ;// a2y2   a0     bxg    Y1     a1y1
        faddp  st(4),st ;// a0     bxg    Y1     t1
    ;// t2  = t1+bxg
        fxch   st(3)    ;// t1     bxg    Y1     a0
        faddp  st(1),st ;// t2     Y1     a0

    ;// Y0  = t2/a0
        fdivrp st(2),st ;// Y1     Y0

    ;// dum1 = Y1


    ;// LOOP ////////////////////////////////////////////////////////////////
    iir_dX_dF_dL_BP2_top:

        IIR_2_CLIPTEST  ;// Y0  Y1

        fst Y0
        inc ecx
        cmp ecx, SAMARY_LENGTH
        jae IIR_dX_dF_dL_BP2_done

        iir_LookupSinCos
        iir_build_Q     ;// Q      cf     sf     Y1     Y2
    ;// Q2=Q+Q
    ;// G = 1 or Q
        .IF [esi].dwUser & IIR_AUTO_GAIN
            fadd st, st
            fld math_1
            fxch
        .ELSE
            fld    st(0)    ;// Q      Q      cf     sf     Y1     Y2
            fadd   st,st(0) ;// Q2     Q      cf     sf     Y1     Y2
        .ENDIF
    ;pay attention to ADDRESSES of X
    ;// x02 = XX0-XX2
        fld    X0      ;// XX0    Q2     Q      cf     sf     Y1     Y2
        fsub   XX2      ;// x02    Q2     Q      cf     sf     Y1     Y2
    ;// a1  = Q2*cf
        fxch   st(3)    ;// cf     Q2     Q      x02    sf     Y1     Y2
        fmul   st,st(1) ;// a1     Q2     Q      x02    sf     Y1     Y2
    ;// a0  = sf+Q2
        fld    st(4)    ;// sf     a1     Q2     Q      x02    sf     Y1     Y2
        fadd   st,st(2) ;// a0     a1     Q2     Q      x02    sf     Y1     Y2
    ;// bx  = sf*x02
        fxch   st(4)    ;// x02    a1     Q2     Q      a0     sf     Y1     Y2
        fmul   st,st(5) ;// bx     a1     Q2     Q      a0     sf     Y1     Y2
    ;// a11 = a1+a1
        fxch   st(1)    ;// a1     bx     Q2     Q      a0     sf     Y1     Y2
        fadd   st,st(0) ;// a11    bx     Q2     Q      a0     sf     Y1     Y2
    ;// a2  = sf-Q2
        fxch   st(5)    ;// sf     bx     Q2     Q      a0     a11    Y1     Y2
        fsubrp st(2),st ;// bx     a2     Q      a0     a11    Y1     Y2
    ;// bxg = bx*Q
        fmulp  st(2),st ;// a2     bxg    a0     a11    Y1     Y2
    ;// a1y1= Y1*a11
        fxch   st(3)    ;// a11    bxg    a0     a2     Y1     Y2
        fmul   st,st(4) ;// a1y1   bxg    a0     a2     Y1     Y2
    ;// a2y2= Y2*a2
        fxch   st(5)    ;// Y2     bxg    a0     a2     Y1     a1y1
        fmulp  st(3),st ;// bxg    a0     a2y2   Y1     a1y1
    ;// t1  = a2y2+a1y1
        fxch   st(2)    ;// a2y2   a0     bxg    Y1     a1y1
        faddp  st(4),st ;// a0     bxg    Y1     t1
    ;// t2  = t1+bxg
        fxch   st(3)    ;// t1     bxg    Y1     a0
        faddp  st(1),st ;// t2     Y1     a0

    ;// Y0  = t2/a0
        fdivrp st(2),st ;// Y1     Y0

        jmp iir_dX_dF_dL_BP2_top

        ;/////////////////
        IIR_2_CLIPTEST_FIX

IIR_dX_dF_dL_BP2 ENDP






ALIGN 16
IIR_sX_sF_dL_nG_BR2:
IIR_sX_dF_dL_nG_BR2:
IIR_dX_sF_dL_nG_BR2:
IIR_dX_dF_dL_nG_BR2:
IIR_sX_sF_dL_aG_BR2:
IIR_sX_dF_dL_aG_BR2:
IIR_dX_sF_dL_aG_BR2:
IIR_dX_dF_dL_aG_BR2:

IIR_dX_dF_dL_BR2 PROC

    ;//
    ;// iir_dX_dF_dL_nG_BR2.asm    generated by FpuOpt3 from iir_dX_dF_dL_BR2.txt
    ;//                            G = 1 for auto gain
    ;// iir dX dF dL nG BR2        G = Q otherwise
    ;//
    ;// (X2-Y2)*(2*Q-sf) + (Y1-X1)*2*Q2*cf + sf*(X2-X0)*G
    ;// ------------------------------------------------- + X0
    ;//           2*Q+sin(F*pi)

        fld Y2
        fld Y1

    ;// 0 ///////////////////////////////////////////////////////////////////

        iir_LookupSinCos
        iir_build_Q     ;// Q      cf     sf     Y1     Y2
    ;// Q2=Q+Q
    ;// G = 1 or Q
        .IF [esi].dwUser & IIR_AUTO_GAIN
            fadd st, st
            fld math_1
            fxch
        .ELSE
            fld    st(0)    ;// Q      Q      cf     sf     Y1     Y2
            fadd   st,st(0) ;// Q2     Q      cf     sf     Y1     Y2
        .ENDIF
    ;ADDRESS XX1
    ;// x1y1 = Y1-XX1
        fld    X1      ;// XX1    Q2     Q      cf     sf     Y1     Y2
        fsubr  st,st(5) ;// x1y1   Q2     Q      cf     sf     Y1     Y2
    ;// cf2 = Q2*cf
        fxch   st(3)    ;// cf     Q2     Q      x1y1   sf     Y1     Y2
        fmul   st,st(1) ;// cf2    Q2     Q      x1y1   sf     Y1     Y2
    ;// sf2 = Q2-sf
        fld    st(1)    ;// Q2     cf2    Q2     Q      x1y1   sf     Y1     Y2
        fsub   st,st(5) ;// sf2    cf2    Q2     Q      x1y1   sf     Y1     Y2
    ;// sf1 = Q2+sf
        fxch   st(2)    ;// Q2     cf2    sf2    Q      x1y1   sf     Y1     Y2
        fadd   st,st(5) ;// sf1    cf2    sf2    Q      x1y1   sf     Y1     Y2
    ;// sfq = sf*Q
        fxch   st(5)    ;// sf     cf2    sf2    Q      x1y1   sf1    Y1     Y2
        fmulp  st(3),st ;// cf2    sf2    sfq    x1y1   sf1    Y1     Y2
    ;// cf22 = cf2+cf2
        fadd   st,st(0) ;// cf22   sf2    sfq    x1y1   sf1    Y1     Y2
    ;ADDRESS XX2
    ;// x2x0 = XX2-X0
        fld    X2      ;// XX2    cf22   sf2    sfq    x1y1   sf1    Y1     Y2
        fsub   X0       ;// x2x0   cf22   sf2    sfq    x1y1   sf1    Y1     Y2
    ;// x2y2 = XX2-Y2
        fxch   st(7)    ;// Y2     cf22   sf2    sfq    x1y1   sf1    Y1     x2x0
        fsubr  X2      ;// x2y2   cf22   sf2    sfq    x1y1   sf1    Y1     x2x0
    ;// T2 = cf22*x1y1
        fxch   st(1)    ;// cf22   x2y2   sf2    sfq    x1y1   sf1    Y1     x2x0
        fmulp  st(4),st ;// x2y2   sf2    sfq    T2     sf1    Y1     x2x0
    ;// T1 = sf2*x2y2
        fmulp  st(1),st ;// T1     sfq    T2     sf1    Y1     x2x0
    ;// T0 = X0*sf1
        fld    X0       ;// X0     T1     sfq    T2     sf1    Y1     x2x0
        fmul   st,st(4) ;// T0     T1     sfq    T2     sf1    Y1     x2x0
    ;// T3 = sfq*x2x0
        fxch   st(2)    ;// sfq    T1     T0     T2     sf1    Y1     x2x0
        fmulp  st(6),st ;// T1     T0     T2     sf1    Y1     T3
    ;// S0 = T1+T2
        faddp  st(2),st ;// T0     S0     sf1    Y1     T3
    ;// S1 = T0+T3
        faddp  st(4),st ;// S0     sf1    Y1     S1
    ;// S2 = S0+S1
        faddp  st(3),st ;// sf1    Y1     S2
    ;BUG!!! should emit FDIV not FDIVR
    ;// Y0 = S2/sf1
        fdivp st(2),st ;// Y1     Y0

    ;// 1 ///////////////////////////////////////////////////////////////////

        IIR_2_CLIPTEST_INLINE

        fst Y0
        inc ecx

        iir_LookupSinCos
        iir_build_Q     ;// Q      cf     sf     Y1     Y2
    ;// Q2=Q+Q
    ;// G = 1 or Q
        .IF [esi].dwUser & IIR_AUTO_GAIN
            fadd st, st
            fld math_1
            fxch
        .ELSE
            fld    st(0)    ;// Q      Q      cf     sf     Y1     Y2
            fadd   st,st(0) ;// Q2     Q      cf     sf     Y1     Y2
        .ENDIF
    ;ADDRESS XX1
    ;// x1y1 = Y1-XX1
        fld    XX1      ;// XX1    Q2     Q      cf     sf     Y1     Y2
        fsubr  st,st(5) ;// x1y1   Q2     Q      cf     sf     Y1     Y2
    ;// cf2 = Q2*cf
        fxch   st(3)    ;// cf     Q2     Q      x1y1   sf     Y1     Y2
        fmul   st,st(1) ;// cf2    Q2     Q      x1y1   sf     Y1     Y2
    ;// sf2 = Q2-sf
        fld    st(1)    ;// Q2     cf2    Q2     Q      x1y1   sf     Y1     Y2
        fsub   st,st(5) ;// sf2    cf2    Q2     Q      x1y1   sf     Y1     Y2
    ;// sf1 = Q2+sf
        fxch   st(2)    ;// Q2     cf2    sf2    Q      x1y1   sf     Y1     Y2
        fadd   st,st(5) ;// sf1    cf2    sf2    Q      x1y1   sf     Y1     Y2
    ;// sfq = sf*Q
        fxch   st(5)    ;// sf     cf2    sf2    Q      x1y1   sf1    Y1     Y2
        fmulp  st(3),st ;// cf2    sf2    sfq    x1y1   sf1    Y1     Y2
    ;// cf22 = cf2+cf2
        fadd   st,st(0) ;// cf22   sf2    sfq    x1y1   sf1    Y1     Y2
    ;ADDRESS XX2
    ;// x2x0 = XX2-X0
        fld    X1      ;// XX2    cf22   sf2    sfq    x1y1   sf1    Y1     Y2
        fsub   X0       ;// x2x0   cf22   sf2    sfq    x1y1   sf1    Y1     Y2
    ;// x2y2 = XX2-Y2
        fxch   st(7)    ;// Y2     cf22   sf2    sfq    x1y1   sf1    Y1     x2x0
        fsubr  X1      ;// x2y2   cf22   sf2    sfq    x1y1   sf1    Y1     x2x0
    ;// T2 = cf22*x1y1
        fxch   st(1)    ;// cf22   x2y2   sf2    sfq    x1y1   sf1    Y1     x2x0
        fmulp  st(4),st ;// x2y2   sf2    sfq    T2     sf1    Y1     x2x0
    ;// T1 = sf2*x2y2
        fmulp  st(1),st ;// T1     sfq    T2     sf1    Y1     x2x0
    ;// T0 = X0*sf1
        fld    X0       ;// X0     T1     sfq    T2     sf1    Y1     x2x0
        fmul   st,st(4) ;// T0     T1     sfq    T2     sf1    Y1     x2x0
    ;// T3 = sfq*x2x0
        fxch   st(2)    ;// sfq    T1     T0     T2     sf1    Y1     x2x0
        fmulp  st(6),st ;// T1     T0     T2     sf1    Y1     T3
    ;// S0 = T1+T2
        faddp  st(2),st ;// T0     S0     sf1    Y1     T3
    ;// S1 = T0+T3
        faddp  st(4),st ;// S0     sf1    Y1     S1
    ;// S2 = S0+S1
        faddp  st(3),st ;// sf1    Y1     S2
    ;BUG!!! should emit FDIV not FDIVR
    ;// Y0 = S2/sf1
        fdivp st(2),st ;// Y1     Y0


    ;// LOOP ///////////////////////////////////////////////////////////////////
    iir_dX_dF_dL_BR2_top:

        IIR_2_CLIPTEST  ;// Y0  Y1

        fst Y0
        inc ecx
        cmp ecx, SAMARY_LENGTH
        jae IIR_dX_dF_dL_BR2_done

        iir_LookupSinCos
        iir_build_Q     ;// Q      cf     sf     Y1     Y2
    ;// Q2=Q+Q
    ;// G = 1 or Q
        .IF [esi].dwUser & IIR_AUTO_GAIN
            fadd st, st
            fld math_1
            fxch
        .ELSE
            fld    st(0)    ;// Q      Q      cf     sf     Y1     Y2
            fadd   st,st(0) ;// Q2     Q      cf     sf     Y1     Y2
        .ENDIF
    ;ADDRESS XX1
    ;// x1y1 = Y1-XX1
        fld    XX1      ;// XX1    Q2     Q      cf     sf     Y1     Y2
        fsubr  st,st(5) ;// x1y1   Q2     Q      cf     sf     Y1     Y2
    ;// cf2 = Q2*cf
        fxch   st(3)    ;// cf     Q2     Q      x1y1   sf     Y1     Y2
        fmul   st,st(1) ;// cf2    Q2     Q      x1y1   sf     Y1     Y2
    ;// sf2 = Q2-sf
        fld    st(1)    ;// Q2     cf2    Q2     Q      x1y1   sf     Y1     Y2
        fsub   st,st(5) ;// sf2    cf2    Q2     Q      x1y1   sf     Y1     Y2
    ;// sf1 = Q2+sf
        fxch   st(2)    ;// Q2     cf2    sf2    Q      x1y1   sf     Y1     Y2
        fadd   st,st(5) ;// sf1    cf2    sf2    Q      x1y1   sf     Y1     Y2
    ;// sfq = sf*Q
        fxch   st(5)    ;// sf     cf2    sf2    Q      x1y1   sf1    Y1     Y2
        fmulp  st(3),st ;// cf2    sf2    sfq    x1y1   sf1    Y1     Y2
    ;// cf22 = cf2+cf2
        fadd   st,st(0) ;// cf22   sf2    sfq    x1y1   sf1    Y1     Y2
    ;ADDRESS XX2
    ;// x2x0 = XX2-X0
        fld    XX2      ;// XX2    cf22   sf2    sfq    x1y1   sf1    Y1     Y2
        fsub   X0       ;// x2x0   cf22   sf2    sfq    x1y1   sf1    Y1     Y2
    ;// x2y2 = XX2-Y2
        fxch   st(7)    ;// Y2     cf22   sf2    sfq    x1y1   sf1    Y1     x2x0
        fsubr  XX2      ;// x2y2   cf22   sf2    sfq    x1y1   sf1    Y1     x2x0
    ;// T2 = cf22*x1y1
        fxch   st(1)    ;// cf22   x2y2   sf2    sfq    x1y1   sf1    Y1     x2x0
        fmulp  st(4),st ;// x2y2   sf2    sfq    T2     sf1    Y1     x2x0
    ;// T1 = sf2*x2y2
        fmulp  st(1),st ;// T1     sfq    T2     sf1    Y1     x2x0
    ;// T0 = X0*sf1
        fld    X0       ;// X0     T1     sfq    T2     sf1    Y1     x2x0
        fmul   st,st(4) ;// T0     T1     sfq    T2     sf1    Y1     x2x0
    ;// T3 = sfq*x2x0
        fxch   st(2)    ;// sfq    T1     T0     T2     sf1    Y1     x2x0
        fmulp  st(6),st ;// T1     T0     T2     sf1    Y1     T3
    ;// S0 = T1+T2
        faddp  st(2),st ;// T0     S0     sf1    Y1     T3
    ;// S1 = T0+T3
        faddp  st(4),st ;// S0     sf1    Y1     S1
    ;// S2 = S0+S1
        faddp  st(3),st ;// sf1    Y1     S2
    ;BUG!!! should emit FDIV not FDIVR
    ;// Y0 = S2/sf1
        fdivp st(2),st ;// Y1     Y0

        jmp iir_dX_dF_dL_BR2_top

    ;///////////////////////////////////////////
    IIR_2_CLIPTEST_FIX


IIR_dX_dF_dL_BR2 ENDP




;// common exit points

    ALIGN 16
    IIR_dX_dF_sL_LP2_done:
    IIR_dX_dF_dL_LP2_done:

    IIR_dX_dF_sL_HP2_done:
    IIR_dX_dF_dL_HP2_done:

    IIR_dX_dF_sL_BP2_done:
    IIR_dX_dF_dL_BP2_done:

    IIR_dX_dF_sL_BR2_done:
    IIR_dX_dF_dL_BR2_done:

        mov eax, XLAST1     ;// Y0  Y1
        fstp Y1
        mov X2,eax
        fstp Y2
        or [esi].pin_y.dwStatus, PIN_CHANGING
        mov edx, XLAST
        mov X1, edx
        jmp iir_calc_done



;//
;//
;//     2nd order filters
;//
;//
;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////
;//
;//                             hit when changing second order modes
;//     interpolate frame
;//
;//
comment ~ /*

    steps:

        1)  define old parameters for old filter type
            use the first value in the sample frames
        2)  define the new values for new filter types
            use the last value in the sample frames
        3)  build the iterpolators
        4)  use a special scan that updates the coefficients every iteration


*/ comment ~

.DATA

    interpolate_params_table LABEL DWORD

    dd  iir_build_params_1CP, iir_build_params_1CZ
    dd  iir_build_params_LP1, iir_build_params_HP1
    dd  iir_build_params_LP2, iir_build_params_HP2
    dd  iir_build_params_BP2, iir_build_params_BR2

.CODE

ALIGN 16
iir_interpolate_frame PROC


    ;// 1)  build the old parameters
    ;//     to do this we need to to usurp dwUser, we assume this is safe

            mov eax, [esi].iir.old_filter
            push [esi].dwUser       ;// save dwUser
            mov [esi].dwUser, eax   ;// replace dwUser
            and eax, IIR_LAST_TABLE_FILTER
            DEBUG_IF < eax !> IIR_LAST_TABLE_FILTER > ;// somehow this snuck through
            call interpolate_params_table[eax*4]
            pop [esi].dwUser        ;// restore dwUser

        ;// we use these as the starting values for our scan
        ;// so we xfer the settings to our stack frame

            push A1 ;// AA1
            push A2 ;// AA2
            push B0 ;// BB0
            push B1 ;// BB1
            push B2 ;// BB2

            sub esp, 4*5

        AA1 TEXTEQU <(DWORD PTR [esp+24h])>
        AA2 TEXTEQU <(DWORD PTR [esp+20h])>
        BB0 TEXTEQU <(DWORD PTR [esp+1Ch])>
        BB1 TEXTEQU <(DWORD PTR [esp+18h])>
        BB2 TEXTEQU <(DWORD PTR [esp+14h])>

        dA1 TEXTEQU <(DWORD PTR [esp+10h])>
        dA2 TEXTEQU <(DWORD PTR [esp+0Ch])>
        dB0 TEXTEQU <(DWORD PTR [esp+08h])>
        dB1 TEXTEQU <(DWORD PTR [esp+04h])>
        dB2 TEXTEQU <(DWORD PTR [esp+00h])>

    ;// 2) build the new values

        mov eax, [esi].dwUser
        mov ecx, SAMARY_LENGTH-1    ;// fool builders to useing the last value in the frame
        and eax, IIR_TYPE_TEST
        DEBUG_IF < eax !> IIR_LAST_TABLE_FILTER > ;// somehow this snuck through
        call interpolate_params_table[eax*4]

    ;// build the interpolator

            fld A1
            fsub AA1        ;// dA1
            fld A2
            fsub AA2        ;// dA2 dA1
            fld B0
            fsub BB0        ;// dB0 dA2 dA1
            fld B1
            fsub BB1        ;// dB1 dB0 dA2 dA1
            fld B2
            fsub BB2        ;// dB2 dB1 dB0 dA2 dA1

            fld math_1_1024 ;// S   dB2 dB1 dB0 dA2 dA1
            fmul st(5), st
            fmul st(4), st
            fmul st(3), st
            fmul st(2), st
            fmul            ;// dB2 dB1 dB0 dA2 dA1

            fxch st(4)      ;// dA1 dB1 dB0 dA2 dB2
            fstp dA1        ;// dB1 dB0 dA2 dB2
            fxch st(2)      ;// dA2 dB0 dB1 dB2
            fstp dA2        ;// dB0 dB1 dB2
            fstp dB0        ;// dB1 dB2
            fstp dB1        ;// dB2
            fstp dB2        ;//

    ;// now we can run the routine

        xor ecx, ecx        ;// reset to first sample

        or [esi].pin_y.dwStatus, PIN_CHANGING

        fld Y2
        fld Y1
        fld X2
        fld X1

        ALIGN 16
        .REPEAT             ;// X1  X2  Y1  Y2

            fld X0          ;// X0  X1  X2  Y1  Y2
            fld BB0         ;// B0  X0  X1  X2  Y1  Y2
            fmul st,st(1)   ;// bX0 X0  X1  X2  Y1  Y2

            fld st(2)       ;// X1  bX0 X0  X1  X2  Y1  Y2
            fmul BB1        ;// bX1 bX0 X0  X1  X2  Y1  Y2
            fld BB2         ;// B2  bX1 bX0 X0  X1  X2  Y1  Y2
            fmulp st(5), st ;// bX1 bX0 X0  X1  bX2 Y1  Y2

            fld st(5)       ;// Y1  bX1 bX0 X0  X1  bX2 Y1  Y2
            fmul AA1        ;// aY1 bX1 bX0 X0  X1  bX2 Y1  Y2

            fxch            ;// bX1 aY1 bX0 X0  X1  bX2 Y1  Y2
            faddp st(2), st ;// aY1 b12 X0  X1  bX2 Y1  Y2
            fld AA2         ;// A2  aY1 b12 X0  X1  bX2 Y1  Y2
            fmulp st(7), st ;// aY1 b12 X0  X1  bX2 Y1  aY2

            faddp st(4), st ;// b12 X0  X1  ab  Y1  aY2
            faddp st(5), st ;// X0  X1  ab  Y1  abc
            fxch st(2)      ;// ab  X1  X0  Y1  abc
            faddp st(4), st ;// X1  X0  Y1  Y0

            fxch st(2)      ;// Y1  X0  X1  Y0
            fxch st(3)      ;// Y0  X0  X1  Y1

        ;// CLIPTEST_ONE iir_clip   ;// Y0  X0  X1  Y1

            fld math_1          ;// 1   y0  .....
            fld st(1)           ;// y0  1   y0
            fabs
            fucompp     ;// do the test, flush both values
            xor eax, eax
            fnstsw  ax  ;// xfer results to ax
            sahf        ;// xfer results to flags

            ja we_clipped

        clip_done:

            fst Y0
            inc ecx
            fxch st(2)      ;// X1  X0  Y0  Y1
            fxch            ;// X0  X1  Y0  Y1

            .BREAK .IF ecx>=SAMARY_LENGTH

        ;// build the new parameters

            fld BB0
            fadd dB0
            fld BB1
            fadd dB1
            fld BB2
            fadd dB2
            fxch st(2)
            fstp BB0
            fstp BB1
            fstp BB2

            fld AA1
            fadd dA1
            fld AA2
            fadd dA2
            fxch
            fstp AA1
            fstp AA2

        .UNTIL 0

    ;// that's it !

        fstp X1
        fstp X2
        fstp st
        fstp st

        add esp, 4*5*2

        jmp iir_calc_done

    ALIGN 16
    we_clipped:

        ;// we clipped

        ftst            ;// check the sign
        xor eax, eax
        fnstsw ax       ;// xfer to ax
        fstp st         ;// dump the value
        sahf            ;// xfer results to flags
        fld math_1      ;// load the staturate value
        inc iir_clip    ;// set it
        jnc clip_done
        fchs            ;// make it pos
        jmp clip_done


iir_interpolate_frame ENDP


ASSUME_AND_ALIGN
filter_PrePlay PROC

    ASSUME esi:PTR IIR_OSC_MAP

    ;// our job here is to reset the previous values

        xor eax, eax

        mov [esi].iir.x1, eax
        mov [esi].iir.x2, eax

        mov [esi].pin_f.dwUser, eax
        mov [esi].pin_r.dwUser, eax

        or [esi].dwUser, IIR_NEED_UPDATE

    ;// that's it, eax is false so we'll erase the data

        ret

filter_PrePlay ENDP



;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//
;//     filter_Render
;//
comment ~ /*

    we are ging to render some number of points from the filter response curve
    we use several preset tables since the frequency axis will not change

    see plot_1.mcd for derivation

    nomenclature

        w   iterator, index, frequency value, rescaled appropriately
        wc  fixed center frequency of filter
        Q   current Q value of the filter
        G   current gain value of the filter

*/ comment ~

.DATA

    ;// fixed array for w
    ;// these tables are copied from the associated .prn file

    .ERRNZ (IIR_NUM_DETAIL_POINTS-60), <have to have 60 points>

    iir_w   REAL4 0.0028495171,0.0031972108,0.0035873295,0.00402505,0.0045161803,0.0050672377,0.0056855342,0.0063792743
            REAL4 0.0071576635,0.0080310305,0.0090109644,0.010110468,0.011344132,0.012728326,0.014281416,0.016024012
            REAL4 0.017979238,0.020173037,0.022634519,0.025396348,0.028495171,0.031972108,0.035873295,0.0402505
            REAL4 0.045161803,0.050672377,0.056855342,0.063792743,0.071576635,0.080310305,0.090109644,0.10110468
            REAL4 0.11344132,0.12728326,0.14281416,0.16024012,0.17979238,0.20173037,0.22634519,0.25396348,0.28495171
            REAL4 0.31972108,0.35873295,0.402505,0.45161803,0.50672377,0.56855342,0.63792743,0.71576635,0.80310305
            REAL4 0.90109644,1.0110468,1.1344132,1.2728326,1.4281416,1.6024012,1.7979238,2.0173037,2.2634519,2.5396348

    ;// Y = K1*y+K2 put's curve on display
    iir_K1  TEXTEQU <math_neg_16>
    iir_K2  TEXTEQU <math_32>
    .ERRNZ (32-IIR_DETAIL_HEIGHT), <need to change these values for different height>


    iir_build_curve LABEL DWORD

        dd  iir_build_curve_1CP_nG,iir_build_curve_1CP_aG
        dd  iir_build_curve_1CZ_nG,iir_build_curve_1CZ_aG
        dd  iir_build_curve_LP1_nG,iir_build_curve_LP1_aG
        dd  iir_build_curve_HP1_nG,iir_build_curve_HP1_aG
        dd  iir_build_curve_LP2_nG,iir_build_curve_LP2_aG
        dd  iir_build_curve_HP2_nG,iir_build_curve_HP2_aG
        dd  iir_build_curve_BP2_nG,iir_build_curve_BP2_aG
        dd  iir_build_curve_BR2_nG,iir_build_curve_BR2_aG
        dd  iir_build_curve_DECAY_both_nG, iir_build_curve_DECAY_both_aG
        dd  iir_build_curve_DECAY_above_nG, iir_build_curve_DECAY_above_aG
        dd  iir_build_curve_DECAY_below_nG, iir_build_curve_DECAY_below_aG

    iir_detail_label LABEL DWORD

        dd  'PC1'
        dd  'ZC1'
        dd  '1PL'
        dd  '1PH'
        dd  '2PL'
        dd  '2PH'
        dd  '2PB'
        dd  '2RB'
        dd  'CR'
        dd  '+CR'
        dd  '-CR'

    iir_detail_label_offset dd 0    ;// dependant on gdi_bmp


.CODE

ASSUME_AND_ALIGN
filter_Render PROC

        ASSUME esi:PTR IIR_OSC_MAP
        ASSUME ebp:PTR LIST_CONTEXT

        test [esi].dwUser, IIR_SHOW_DETAIL
        jz gdi_render_osc

    ;// determine if we have to display a new value
    ;// if the filter shape has changed
    ;// if auto gain has changed
    ;// if the Q value has changed
    ;// if we have not been set up yet

    ;// in case we have to determine Q, setup edi now

        xor eax, eax
        OR_GET_PIN [esi].pin_r.pPin, eax
        mov edi, math_pNull
        .IF !ZERO?
            mov edi, [eax].pData
            ASSUME edi:PTR DWORD
        .ENDIF

        xor eax, eax
        OR_GET_PIN [esi].pin_f.pPin, eax
        mov edx, math_pNull
        .IF !ZERO?
            mov edx, [eax].pData
            ASSUME edx:PTR DWORD
        .ELSEIF [esi].dwUser & IIR_DECAY_BOTH   ;// pin was not connected
            mov edx, OFFSET decay_default_D     ;// if decay then point at default value
        .ENDIF

    ;// check if filter type or L, or F has changed

        mov eax, [esi].dwUser
        mov ebx, [edi]  ;// L0
        mov ecx, [edx]  ;// F0
        and eax, IIR_TYPE_TEST OR IIR_AUTO_GAIN
        xchg ebx,[esi].iir.last_render_L
        xchg ecx,[esi].iir.last_render_F
        xchg eax,[esi].iir.last_render_state

        cmp ebx, [esi].iir.last_render_L
        jne have_to_render
        cmp ecx, [esi].iir.last_render_F
        jne have_to_render
        cmp eax, [esi].iir.last_render_state
        je render_detail_label

    have_to_render:

    ;// build a stack frame for the points

        sub esp, IIR_NUM_DETAIL_POINTS * 8

        Xn TEXTEQU <(SDWORD PTR [esp+ecx*8])>
        Yn TEXTEQU <(SDWORD PTR [esp+ecx*8+4])>

        xor ecx, ecx    ;// must be zero

    ;// determine the curve to draw, caclulate wc and w in the process

        mov eax, [esi].dwUser
        and eax, IIR_TYPE_TEST
        DEBUG_IF < eax !>= NUM_FILTERS > ;// some how we lost track !!

        fld [esi].iir.last_render_F
        fmul math_pi

        BITT [esi].dwUser, IIR_AUTO_GAIN
        adc eax, eax
        xor ecx, ecx

        fabs            ;// wc
        fld st
        fmul st(1), st  ;// wc  wc2

        jmp iir_build_curve[eax*4]










    ;// 1CP see iir_build_params_1CP for full version
    ;//
    ;// B0 A1 A2


    ALIGN 16
    iir_build_curve_1CP_nG::    ;// wc  wc2

        fstp st
        fstp st

            fld1    ;// Y1
            fldz    ;// Y2  Y1
            math_Cos [esi].iir.last_render_F, _1cp_temp_1
            fld st
            fadd                    ;// 2c  y2      y1
            fxch                    ;// y2  2c      y1

            ;// no gain adjust      ;// y2  2c      y11

            fld [esi].iir.last_render_L ;// R       y2      2c      y1
            fabs                    ;// r       y2      2c      y1
            fmul st(2), st          ;// r       y2      b1      y1
            fld st                  ;// r       r       y2      b1      y1
            fmul                    ;// r2  y2      b1      y1
            fchs
            fxch                    ;// y2  b2      b1      y1

            ;// rearrange for build_1cp_curve
            ;// jmp to build 1CP curve

            fstp st ;// A2  A1  B0
            jmp build_1CP_points


    ALIGN 16
    iir_build_curve_1CP_aG::    ;// wc  wc2

        fstp st
        fstp st

            fld1    ;// Y1
            fldz    ;// Y2  Y1
            math_Cos [esi].iir.last_render_F, _1cp_temp_1
            fld st
            fadd                ;// 2c  y2      y1
            fxch                ;// y2  2c      y1

            ;// uniy gain
            ;// A = sqrt ( r * ( r - (4c2-2) ) + 1 ) * r-1
            ;// b1 = 2*c*r
            ;// b2 = - r * r
            ;// y0 = A*x + b1*y1 + b2*y2

            fld [esi].iir.last_render_L     ;// R           y2      2c      y1
            fabs                ;// r           y2      2c      y1

            fld st              ;// r           r       y2      2c      y1
            fmul st(1), st      ;// r           r2      y2      2c      y1
            fld st(3)           ;// 2c      r       r2      y2      2c      y1
            fmul st, st(4)      ;// 4c2     r       r2      y2      2c      y1
            fsub math_2         ;// 4c2-2       r       r2      y2      2c      y1
            fsubr st, st(1)     ;// r-4c2+2 r       r2      y2      2c      y1
            fmul st, st(1)      ;// r(r-4c2+2   r       r2      y2      2c      y1
            fld1
            fadd
            fsqrt               ;// AA  r       r2      y2      2c      y1
            fxch                ;// r       AA      r2      y2      2c      y1
            fmul st(4), st      ;// r       AA      r2      y2      b1      y1
            fld1                ;// 1       r       AA      r2      y2      b1      y1
            fsub                ;// r-1 AA      r2      y2      b1      y1
            fmul                ;// A       r2      y2      b1      y1
            fchs
            fxch                ;// r2  A       y2      b1      y1
            fchs                ;// b2  A       y2      b1      y1
            fxch st(2)          ;// y2  A       b2      b1      y1
                                ;//     B0      A2      A1

            ;// rearrange for build_1cp_curve

            fstp st         ;// B0      A2      A1      y1
            fxch st(3)      ;// y1      A2      A1      B0
            fstp st         ;// A2      A1      B0

            ;// jmp to build 1CP curve

        build_1CP_points:

            ;// step 1 is to xform the parameters into C2 C1 C0
            ;// see plot_1.mcd for details
            ;//ABOX233 added test for negative

            ;// A2      A1      B0
            ;// C0 = 1 + 2*A2 + A1*A1 + A2*A2
            ;// C1 = 2*A1*(A2-1)
            ;// C2 = -4*A2

            ;// Xn = B0
            ;// then Yn = C2*cos(w)^2 + C1*cos(w) + C0

            ;//
            ;// plot_1cp.asm      generated by FpuOpt3 from plot_1cp.txt
            ;//
            ;// plot_1cp
            ;// FPU A2        A1        B0
                                ;// A2     A1     B0
            ;// C0 = 1 + 2*A2 + A1*A1 + A2*A2
            ;// C1 = 2*A1*(A2-1)
            ;// C2 = -4*A2

            ;// Xn = B0
            ;// then Yn = C2*cos(w)^2 + C1*cos(w) + C0


            ;// A22=A2*A2
                fld    st(0)    ;// A2     A2     A1     B0
                fmul   st,st(0) ;// A22    A2     A1     B0
            ;// A11=A1*A1
                fld    st(2)    ;// A1     A22    A2     A1     B0
                fmul   st,st(3) ;// A11    A22    A2     A1     B0
            ;// A2_2=A2+A2
                fld    st(2)    ;// A2     A11    A22    A2     A1     B0
                fadd   st,st(3) ;// A2_2   A11    A22    A2     A1     B0
            ;// A1_2=A1+A1
                fxch   st(4)    ;// A1     A11    A22    A2     A2_2   B0
                fadd   st,st(0) ;// A1_2   A11    A22    A2     A2_2   B0
            ;// A2m1=A2-math_one
                fxch   st(3)    ;// A2     A11    A22    A1_2   A2_2   B0
                fsub   math_1   ;// A2m1   A11    A22    A1_2   A2_2   B0

            ;// A1122=A11+A22
                fxch   st(1)    ;// A11    A2m1   A22    A1_2   A2_2   B0
                faddp  st(2),st ;// A2m1   A1122  A1_2   A2_2   B0
            ;// A2_21=A2_2+math_one
                fld    math_1   ;// math_oneA2m1   A1122  A1_2   A2_2   B0
                fadd   st,st(4) ;// A2_21  A2m1   A1122  A1_2   A2_2   B0
            ;// C0 = A1122+A2_21
                faddp  st(2),st ;// A2m1   C0     A1_2   A2_2   B0
            ;// C1 = A1_2*A2m1
                fmulp  st(2),st ;// C0     C1     A2_2   B0
            ;// A2_4 = A2_2+A2_2
                fxch   st(2)    ;// A2_2   C1     C0     B0
                fadd   st,st(0) ;// A2_4   C1     C0     B0
            ;// C2 = -A2_4
                fchs            ;// C2     C1     C0     B0

             .REPEAT

            ;// >> cw
                fld iir_w[ecx*4]
                fcos
                                ;// cw     C2     C1     C0     B0
            ;// cw2=cw*cw
                fld    st(0)    ;// cw     cw     C2     C1     C0     B0
                fmul   st,st(0) ;// cw2    cw     C2     C1     C0     B0
            ;// T1 = C1*cw
                fxch   st(1)    ;// cw     cw2    C2     C1     C0     B0
                fmul   st,st(3) ;// T1     cw2    C2     C1     C0     B0
            ;// T2 = C2*cw2
                fxch   st(1)    ;// cw2    T1     C2     C1     C0     B0
                fmul   st,st(2) ;// T2     T1     C2     C1     C0     B0
            ;// T3 = T1+C0
                fxch   st(1)    ;// T1     T2     C2     C1     C0     B0
                fadd   st,st(4) ;// T3     T2     C2     C1     C0     B0
            ;// yy = T3+T2
                faddp  st(1),st ;// yy     C2     C1     C0     B0
            ;// Yn # sqrt yy
    ;//ABOX233 this does go negative
    ftst
    xor eax, eax
    fnstsw ax
    and eax, FPU_SW_C3 OR FPU_SW_C2 OR FPU_SW_C0
    jnz N00
                fsqrt           ;// Yn     C2     C1     C0     B0
            ;// <<Yn
                fstp   Yn       ;// C2     C1     C0     B0
                jmp N01
    N00:    xor eax, eax
            fstp st
            mov Yn, eax
    N01:
            ;// Xn # B0
            ;// <<Xn
                fxch   st(3)    ;// B0     C1     C0     C2
                fst    Xn       ;// B0     C1     C0     C2
                fxch   st(3)    ;// C2     C1     C0     B0

                inc ecx

            .UNTIL ecx >= IIR_NUM_DETAIL_POINTS

            fstp st
            fstp st
            fstp st
            fstp st

            jmp build_the_points


    ALIGN 16
    iir_build_curve_1CZ_nG::    ;// wc  wc2
    ;// ABOX233 do not clear the fpu !!
    ;// fstp st
    ;// fstp st

            math_Cos [esi].iir.last_render_F, _1cp_temp_1
            fadd st, st             ;// 2c  x2      x1
            fxch                    ;// x2  2c      x1

            fld [esi].iir.last_render_L ;// R       x2      2c      x1
            fabs                    ;// r       x2      2c      x1
            fmul st(2), st          ;// r       x2      2cr     x1
            fld st
            fmul                    ;// a2  x2      2cr     x1
            fxch st(2)              ;// 2cr x2      a2      x1
            fchs                    ;// a1  x2      a2      x1
            fxch                    ;// x2  a1      a2      x1

            ;// no gain adjust      ;// x2  a1      a2      x1
            ;//                     ;//     B1      B2      B0
            fstp st
            jmp build_1cz_points


    ALIGN 16
    iir_build_curve_1CZ_aG::    ;// wc  wc2

        fstp st
        fstp st

    ;// load dummy params to prevent rewrite
    ;// we'll use these as store parameters as well

        fld1    ;//  X1
        fldz    ;//  X2

        ;// use gain adjust

            math_Cos [esi].iir.last_render_F, _1cp_temp_1
            fadd st, st             ;// 2c  x2      x1
            fxch                    ;// x2  2c      x1

            fld [esi].iir.last_render_L                 ;// R       x2      2c      x1
            fabs                    ;// r       x2      2c      x1
            fmul st(2), st          ;// r       x2      2cr     x1
            fld st
            fmul                    ;// a2  x2      2cr     x1
            fxch st(2)              ;// 2cr x2      a2      x1
            fchs                    ;// a1  x2      a2      x1
            fxch                    ;// x2  a1      a2      x1

        ;// setup           ;// x2  a1      a2      x1

            fld st(1)       ;// a1  x2      a1      a2      x1
            fabs
            fld1            ;// 1       a1      x2      a1      a2      x1
            fxch            ;// a1  1       x2      a1      a2      x1
            fadd st, st(4)  ;// a1+b1   1       x2      a1      a2      x1
            fadd st, st(1)  ;// 1/A 1       x2      a1      a2      x1
            fdiv            ;// A       x2      a1      a2      x1
            fxch            ;// x2  A       a1      a2      x1

                            ;//     B1      B2      x1

            fstp st
            fmul st(1), st
            fmul st(2), st
            fmulp st(3), st

        build_1cz_points:

            ;// C2 = 4*B0*B2
            ;// C1 = 2*B1*(B0+B2)
            ;// C0 = B1^2 * (B0-B2)^2

                            ;// B1      B2      B0
            fld st
            fadd st(1), st
            fmul st, st     ;// B1^2    2B1     B2      B0
            fxch st(2)      ;// B2      2B1     B1^2    B0
            fld st          ;// B2      B2      2B1     B1^2    B0
            fmul st, st(4)  ;// B2B0    B2      2B1     B1^2    B0
            fld st(1)       ;// B2      B2B0    B2      2B1     B1^2    B0
            fsubr st, st(5) ;// B0-B2   B2B0    B2      2B1     B1^2    B0
            fxch st(2)      ;// B2      B2B0    B0-B2   2B1     B1^2    B0
            faddp st(5), st ;// B2B0    B0-B2   2B1     B1^2    B0+B2

            fmul math_4     ;// C2      B0-B2   2B1     B1^2    B0+B2
            fxch            ;// B0-B2   C2      2B1     B1^2    B0+B2
            fmul st, st     ;// B0-B2^2 C2      2B1     B1^2    B0+B2
            fxch st(2)      ;// 2B1     C2      B0-B2^2 B1^2    B0+B2
            fmulp st(4),st  ;// C2      B0-B2^2 B1^2    C1
            fxch st(2)      ;// B1^2    B0-B2^2 C2      C1
            fadd            ;// C0      C2      C1
            mov edx, math_1

            .REPEAT

                fld iir_w[ecx*4];// cw  C0      C2      C1
                fcos
                fld st
                fmul st(1), st  ;// cw  cw^2    C0      C2      C1
                fmul st, st(4)
                fxch
                fmul st, st(3)
                fadd
                fadd st, st(1)
;// ABOX233 this does go negative
ftst
fnstsw ax
and eax, FPU_SW_C3 OR FPU_SW_C2 OR FPU_SW_C0
jnz N10
                fsqrt
                fstp Xn
                jmp N11
N10:    xor eax, eax
        fstp st
        mov Xn, eax
N11:
                mov Yn, edx

                inc ecx

            .UNTIL ecx >= IIR_NUM_DETAIL_POINTS

            fstp st
            fstp st
            fstp st

            jmp build_the_points



    ALIGN 16
    iir_build_curve_DECAY_both_nG::
    iir_build_curve_DECAY_both_aG::
    iir_build_curve_DECAY_above_nG::
    iir_build_curve_DECAY_above_aG::
    iir_build_curve_DECAY_below_nG::
    iir_build_curve_DECAY_below_aG::
    iir_build_curve_LP1_nG::
    iir_build_curve_LP1_aG::    ;// wc  wc2

    ;// Xn = wc

        .REPEAT
            fst Xn
            inc ecx
        .UNTIL ecx >= IIR_NUM_DETAIL_POINTS
        fstp st
        jmp build_bottom_curve_1

    ALIGN 16
    iir_build_curve_HP1_nG::
    iir_build_curve_HP1_aG::    ;// wc  wc2

    ;// Xn = w

        .REPEAT
            mov eax, iir_w[ecx*4]
            mov Xn, eax
            inc ecx
        .UNTIL ecx >= IIR_NUM_DETAIL_POINTS
        fstp st
        jmp build_bottom_curve_1


    ALIGN 16
    iir_build_curve_LP2_nG::    ;// wc  wc2

        ;// determine Q, G

            fld math_1
            fld [esi].iir.last_render_L
            call iir_L_to_Q_special
                                ;// Q   wc  wc2
            fld st              ;// Q   Q   wc  wc2
            iir_build_nG        ;// GQ  2Q  Q   wc  wc2

            jmp build_LP2_points

    ALIGN 16
    iir_build_curve_LP2_aG::

        ;// determine Q, G and wc

            fld math_1
            fld [esi].iir.last_render_L
            call iir_L_to_Q_special
                                ;// Q   wc  wc2
            fld st              ;// Q   Q   wc  wc2
            iir_build_aG        ;// GQ  2Q  Q   wc  wc2

    build_LP2_points:           ;// GQ  2Q  Q   wc  wc2

        ;// Xn = wc^2 * GQ const

            fmul st, st(4)      ;// num2
            fxch
            fstp st             ;// num2    Q   wc  wc2

            .REPEAT
                fst Xn
                inc ecx
            .UNTIL ecx >= IIR_NUM_DETAIL_POINTS

        ;// calculate X at wc and Q^2

            fxch
            fmul st, st         ;// Q2  GX  wc  wc2

        ;// exit to bottom curve drawer

            jmp build_bottom_curve_2

    ALIGN 16
    iir_build_curve_HP2_nG::

        ;// determine Q, G and wc

            fld math_1
            fld [esi].iir.last_render_L
            call iir_L_to_Q_special
                                ;// Q   wc  wc2
            fld st              ;// Q   Q   wc  wc2
            iir_build_nG        ;// GQ  2Q  Q   wc  wc2

            jmp build_HP2_points

    ALIGN 16
    iir_build_curve_HP2_aG::

        ;// determine Q, G and wc

            fld math_1
            fld [esi].iir.last_render_L
            call iir_L_to_Q_special
                                ;// Q   wc  wc2
            fld st              ;// Q   Q   wc  wc2
            iir_build_aG        ;// GQ  2Q  Q   wc  wc2

        build_HP2_points:

        ;// Xn = w^2 * GQ

            .REPEAT
                fld iir_w[ecx*4]
                fmul st, st
                fmul st, st(1)
                fstp Xn
                inc ecx
            .UNTIL ecx >= IIR_NUM_DETAIL_POINTS

        ;// calculate X at wc and Q^2

            fmul st, st(4)  ;// GX  2Q  Q   wc  wc2
            fxch st(2)      ;// Q   2Q  GX  wc  wc2
            fmul st, st
            fxch
            fstp st         ;// Q^2 GX  wc  wc2

        ;// jump to common curve builder

            jmp build_bottom_curve_2


    ALIGN 16
    iir_build_curve_BP2_nG::

        ;// determine Q, G and wc

            fld math_1
            fld [esi].iir.last_render_L
            call iir_L_to_Q_special
                                ;// Q   wc  wc2
            fld st              ;// Q   Q   wc  wc2
            iir_build_nG        ;// GQ  2Q  Q   wc  wc2

            jmp build_BP2_points

    ALIGN 16
    iir_build_curve_BP2_aG::

        ;// determine Q, G and wc

            fld math_1
            fld [esi].iir.last_render_L
            call iir_L_to_Q_special
                                ;// Q   wc  wc2
            fld st              ;// Q   Q   wc  wc2
            fadd st, st
            fld math_1          ;// GQ  2Q  Q   wc  wc2

        build_BP2_points:

        ;// Xn = w*wc * GQ

            .REPEAT
                fld iir_w[ecx*4];// w   GQ  2Q  Q   wc  wc2
                fmul st, st(4)  ;// wwc GQ  2Q  Q   wc  wc2
                fmul st, st(1)
                fstp Xn         ;// GQ  2Q  Q   wc  wc2
                inc ecx
            .UNTIL ecx >= IIR_NUM_DETAIL_POINTS

        ;// calculate X at wc and Q^2
        ;// GX = wc2* GQ

            fmul st, st(4)      ;// GX  2Q  Q   wc  wc2
            fxch st(2)          ;// Q   2Q  GX  wc  wc2
            fmul st, st
            fxch
            fstp st

        ;// exit to curve builder

            jmp build_bottom_curve_2



    ALIGN 16
    iir_build_curve_BR2_nG::

        ;// determine Q, G and wc

            fld math_1
            fld [esi].iir.last_render_L
            call iir_L_to_Q_special
                                ;// Q   wc  wc2
            fld st              ;// Q   Q   wc  wc2
            iir_build_nG        ;// GQ  2Q  Q   wc  wc2

            jmp build_BR2_points

    ALIGN 16
    iir_build_curve_BR2_aG::

        ;// determine Q, G and wc

            fld math_1
            fld [esi].iir.last_render_L
            call iir_L_to_Q_special
                                ;// Q   wc  wc2
            fld st              ;// Q   Q   wc  wc2
            fadd st, st
            fld math_1          ;// GQ  2Q  Q   wc  wc2

        build_BR2_points:

        ;// this one's a mess

        ;//
        ;// top_curve_bp.asm      generated by FpuOpt3 from top_curve_bp.txt
        ;//
        ;// top curve bp
        ;// Xn = sqrt ( (w-wc)^2 * (w+wc)^2 * Q^2 + (wc*w)^2 * (GQ-1)^2 )

            fxch
            fstp st             ;// GQ  Q   wc  wc2

        ;// FPU                 ;// GQ     Q      wc     wc2
            ;// GQ1=GQ-math_1
                fsub   math_1   ;// GQ1    Q      wc     wc2
            ;// Q2=Q*Q
                fxch   st(1)    ;// Q      GQ1    wc     wc2
                fmul   st,st(0) ;// Q2     GQ1    wc     wc2
            ;// GQ12=GQ1*GQ1
                fxch   st(1)    ;// GQ1    Q2     wc     wc2
                fmul   st,st(0) ;// GQ12   Q2     wc     wc2

            .REPEAT

            ;// wm = iir_w-wc
                fld    iir_w[ecx*4]    ;// iir_w  GQ12   Q2     wc     wc2
                fsub   st,st(3) ;// wm     GQ12   Q2     wc     wc2
            ;// wp = iir_w+wc
                fld    iir_w[ecx*4]    ;// iir_w  wm     GQ12   Q2     wc     wc2
                fadd   st,st(4) ;// wp     wm     GQ12   Q2     wc     wc2
            ;// w2= iir_w*iir_w
                fld    iir_w[ecx*4]    ;// iir_w  wp     wm     GQ12   Q2     wc     wc2
                fmul   st,st(0) ;// w2     wp     wm     GQ12   Q2     wc     wc2
            ;// wm2=wm*wm
                fxch   st(2)    ;// wm     wp     w2     GQ12   Q2     wc     wc2
                fmul   st,st(0) ;// wm2    wp     w2     GQ12   Q2     wc     wc2
            ;// wp2=wp*wp
                fxch   st(1)    ;// wp     wm2    w2     GQ12   Q2     wc     wc2
                fmul   st,st(0) ;// wp2    wm2    w2     GQ12   Q2     wc     wc2
            ;// wwc2=w2*wc2
                fxch   st(2)    ;// w2     wm2    wp2    GQ12   Q2     wc     wc2
                fmul   st,st(6) ;// wwc2   wm2    wp2    GQ12   Q2     wc     wc2
            ;// wpm2=wm2*wp2
                fxch   st(1)    ;// wm2    wwc2   wp2    GQ12   Q2     wc     wc2
                fmulp  st(2),st ;// wwc2   wpm2   GQ12   Q2     wc     wc2
            ;// T2=wwc2*GQ12
                fmul   st,st(2) ;// T2     wpm2   GQ12   Q2     wc     wc2
            ;// T1=wpm2*Q2
                fxch   st(1)    ;// wpm2   T2     GQ12   Q2     wc     wc2
                fmul   st,st(3) ;// T1     T2     GQ12   Q2     wc     wc2
            ;// xx=T1+T2
                faddp  st(1),st ;// xx     GQ12   Q2     wc     wc2
            ;// Xn#sqrt xx
                fsqrt           ;// Yn     GQ12   Q2     wc     wc2
            ;// <<Xn
                fstp   Xn       ;// GQ12   Q2     wc     wc2

            inc ecx

        .UNTIL ecx >=  IIR_NUM_DETAIL_POINTS

        ;// calculate the gain at wc

            fsqrt
            fmul st, st(3)
            fxch

            jmp build_bottom_curve_2



    ALIGN 16
    build_bottom_curve_1:   ;// wc2
    ;// Yn = sqrt(wc2+w2)

        xor ecx, ecx
        .REPEAT
            fld iir_w[ecx*4]
            fmul st, st
            fadd st, st(1)
            fsqrt
            fstp Yn
            inc ecx
        .UNTIL ecx >= IIR_NUM_DETAIL_POINTS
        fstp st
        jmp build_the_points



    ALIGN 16
    build_bottom_curve_2:

    ;// tasks:  1) build Yn for all the points
    ;//         2) replace equivalent wc point with GX

    ;// FPU:    Q2  GX  wc  wc2

    ;// Yn = sqrt( ( (w-wc)^2 * (w+wc)^2 ) * Q^2 + wc^2 * w^2 )

        xor ecx, ecx
        xor edx, edx    ;// edx traps for storing GX

        .REPEAT
        ;// get the chart point
            fld iir_w[ecx*4]    ;// w   Q2  GX  wc  wc2

            .IF !edx
            ;// trap for first chart point PASSED wc
            ;// w >= wc
                fucom st(3) ;// cmp w with wc
                xor eax, eax
                fnstsw ax
                sahf
                .IF !CARRY?     ;// if w >= wc
                    inc edx     ;// set the flag so we don't do this again
                    fstp st     ;// Q2  GX  wc  wc2
                    fld st(1)   ;// GX  Q2  GX  wc  wc2
                    fstp Xn     ;// Q2  GX  wc  wc2
                    fld st(2)   ;// w   Q2  GX  wc  wc2
                .ENDIF
            .ENDIF

        ;// bot_curve.asm      generated by FpuOpt3 from bot_curve.txt
        ;//
        ;// bot curve
        ;// Yn = sqrt( ( (w-wc)^2 * (w+wc)^2 ) * Q^2 + wc^2 * w^2 )
        ;// after we locate closest w, we can reuse this

        ;// wc = F * pi
        ;// wc2 = wc*wc
        ;// calculate Q2 from previous stage as Q*Q

        ;// FPU             ;// w      Q2     GX     wc     wc2
        ;// wpc = w+wc
            fld    st(0)    ;// w      w      Q2     GX     wc     wc2
            fadd   st,st(4) ;// wpc    w      Q2     GX     wc     wc2
        ;// wmc = w-wc
            fld    st(1)    ;// w      wpc    w      Q2     GX     wc     wc2
            fsub   st,st(5) ;// wmc    wpc    w      Q2     GX     wc     wc2
        ;// w2=w*w
            fxch   st(2)    ;// w      wpc    wmc    Q2     GX     wc     wc2
            fmul   st,st(0) ;// w2     wpc    wmc    Q2     GX     wc     wc2
        ;// wpc2 = wpc*wpc
            fxch   st(1)    ;// wpc    w2     wmc    Q2     GX     wc     wc2
            fmul   st,st(0) ;// wpc2   w2     wmc    Q2     GX     wc     wc2
        ;// wmc2 = wmc*wmc
            fxch   st(2)    ;// wmc    w2     wpc2   Q2     GX     wc     wc2
            fmul   st,st(0) ;// wmc2   w2     wpc2   Q2     GX     wc     wc2
        ;// t2 = wc2*w2
            fxch   st(1)    ;// w2     wmc2   wpc2   Q2     GX     wc     wc2
            fmul   st,st(6) ;// t2     wmc2   wpc2   Q2     GX     wc     wc2
        ;// pm = wpc2*wmc2
            fxch   st(2)    ;// wpc2   wmc2   t2     Q2     GX     wc     wc2
            fmulp  st(1),st ;// pm     t2     Q2     GX     wc     wc2
        ;// t1 = pm*Q2
            fmul   st,st(2) ;// t1     t2     Q2     GX     wc     wc2
        ;// t3 = t1+t2
            faddp  st(1),st ;// t3     Q2     GX     wc     wc2
        ;// Yn # sqrt t3
            fsqrt           ;// Yn     Q2     GX     wc     wc2
        ;// <<Yn
            fstp   Yn       ;// Q2     GX     wc     wc2

            inc ecx

        .UNTIL ecx >= IIR_NUM_DETAIL_POINTS

        fstp st
        fstp st
        fstp st
        fstp st

    ;// do the division and check the results
    ;// we also fill in the X values

    ALIGN 16
    build_the_points:   ;// FPU empty

        xor ecx, ecx
        mov eax, 2
        .REPEAT         ;// Y = K1 * Xn/Yn + K2
            .IF Yn
                fld Xn
                fdiv Yn
            .ELSE
                fld math_0
            .ENDIF
            fmul iir_K1
            fadd iir_K2
            fistp Yn
            mov Xn, eax
            .IF Yn < IIR_MIN_DISPLAY_Y
                mov Yn, IIR_MIN_DISPLAY_Y
            .ELSEIF Yn >= IIR_MAX_DISPLAY_Y
                mov Yn, IIR_MAX_DISPLAY_Y
            .ENDIF
            inc ecx
            inc eax
        .UNTIL ecx >= IIR_NUM_DETAIL_POINTS

    ;// draw the curve
    render_the_curve:

    ;// erase previous display

        OSC_TO_CONTAINER esi, ebx
        mov eax, F_COLOR_GROUP_PROCESSORS   ;// back color
        mov edx, F_COLOR_GROUP_PROCESSORS + F_COLOR_GROUP_LAST - 02020202h  ;// border color
        invoke dib_FillAndFrame

    ;// draw grid lines

        mov eax, F_COLOR_GROUP_PROCESSORS + F_COLOR_GROUP_LAST - 11
        pushd 16
        pushd 62
        pushd 16
        pushd 2
        call dib_DrawLine
        add esp, 16

    ;// draw all the points on the stack

        mov edi, IIR_NUM_DETAIL_POINTS-1
        mov ebx, [esi].pContainer
        mov al, COLOR_GROUP_PROCESSORS + COLOR_GROUP_LAST - 2
        .REPEAT
            call dib_DrawLine
            add esp, 8  ;// consume x and y
            dec edi
        .UNTIL ZERO?

        add esp, 8  ;// don't need the last two points anymore

    render_detail_label:

    ;// call gdi to blit stuff for us

        call gdi_render_osc

    ;// then show what filter we are

        mov eax, [esi].dwUser
        and eax, IIR_TYPE_TEST
        DEBUG_IF < eax !>= NUM_FILTERS > ;// some how we lost track !!
        mov ebx, iir_detail_label[eax*4]
        OSC_TO_DEST esi, edi        ;// get the destination
        add edi, iir_detail_label_offset
        push esi
        mov eax, F_COLOR_GROUP_PROCESSORS + F_COLOR_GROUP_LAST - 02020202h
        invoke shape_Fill
        pop esi

        ret



filter_Render ENDP





ASSUME_AND_ALIGN
filter_SetShape PROC

        ASSUME esi:PTR IIR_OSC_MAP

        push ebx    ;// have to preserve

    ;// set the psource for the shape

        mov eax, [esi].dwUser

        .IF eax & IIR_SHOW_DETAIL

            ;// make sure we have a dib container
            ;// we store it in iir.dib so we have a backup

            mov eax, [esi].iir.dib
            .IF !eax

                invoke dib_Reallocate, DIB_ALLOCATE_INTER, IIR_DETAIL_WIDTH, IIR_DETAIL_HEIGHT
                mov [esi].iir.dib, eax  ;// always store for a backup !!!!

            .ENDIF

            mov [esi].pContainer, eax   ;// store in object
            mov eax, (DIB_CONTAINER PTR [eax]).shape.pSource
            mov [esi].pSource, eax

        .ELSE   ;// we are a normal icon

            lea edx, filter_container
            mov [esi].pContainer, edx

            and eax, IIR_TYPE_TEST
            mov edx, iir_psource_table[eax*4]
            DEBUG_IF < eax !>= NUM_FILTERS > ;// some how we lost track !!
            mov [esi].pSource, edx

        .ENDIF

    ;// make sure our two fonts are built

        .IF iir_shape_R == 'R'
        push edi

            mov edi, OFFSET font_pin_slist_head
            mov eax, iir_shape_R
            invoke font_Locate
            mov iir_shape_R, edi

            mov edi, OFFSET font_pin_slist_head
            mov eax, iir_shape_L
            invoke font_Locate
            mov iir_shape_L, edi

            mov edi, OFFSET font_pin_slist_head
            mov eax, iir_shape_D
            invoke font_Locate
            mov iir_shape_D, edi

            mov edi, OFFSET font_pin_slist_head
            mov eax, iir_shape_F
            invoke font_Locate
            mov iir_shape_F, edi

        pop edi
        .ENDIF

    ;// make sure our detail labels are built

        .IF !iir_detail_label_offset
        push edi

            mov ebx, OFFSET iir_detail_label

            .REPEAT
                mov edi, OFFSET font_bus_slist_head
                mov eax, [ebx]
                invoke font_Locate
                mov eax, (GDI_SHAPE PTR [edi]).pMask
                mov [ebx], eax
                add ebx, 4
            .UNTIL ebx >= OFFSET iir_detail_label_offset

            mov eax, IIR_DETAIL_LABEL_Y
            mul gdi_bitmap_size.x
            add eax, IIR_DETAIL_LABEL_X
            mov iir_detail_label_offset, eax

        pop edi
        .ENDIF

    ;// determine the pins we want to show

        mov eax, [esi].dwUser
        lea ebx, [esi].pin_r
        ASSUME ebx:PTR APIN
        and eax, IIR_TYPE_TEST

        .IF eax == IIR_1CP || eax == IIR_1CZ
            ;// show R pin

            invoke pin_Show, 1
            invoke pin_SetNameAndUnit, iir_shape_R, OFFSET sz_iir_R_input, [ebx].dwStatus

            lea ebx, [esi].pin_f
            invoke pin_SetNameAndUnit, iir_shape_F, OFFSET sz_Frequency, UNIT_HERTZ

        .ELSEIF eax == IIR_LP1 || eax == IIR_HP1
            ;// hide LR pin

            invoke pin_Show, 0

            lea ebx, [esi].pin_f
            invoke pin_SetNameAndUnit, iir_shape_F, OFFSET sz_Frequency, [ebx].dwStatus

        .ELSEIF eax == IIR_DECAY_BOTH || eax == IIR_DECAY_ABOVE || eax == IIR_DECAY_BELOW

            invoke pin_Show, 0
            lea ebx, [esi].pin_f
            invoke pin_SetNameAndUnit, iir_shape_D, OFFSET sz_iir_D_input, UNIT_SECONDS

        .ELSE
            ;// show L pin

            invoke pin_Show, 1
            invoke pin_SetNameAndUnit, iir_shape_L, OFFSET sz_iir_L_input, [ebx].dwStatus

            lea ebx, [esi].pin_f
            invoke pin_SetNameAndUnit, iir_shape_F, OFFSET sz_Frequency, UNIT_HERTZ

        .ENDIF

    ;// that should do it

        pop ebx

        jmp osc_SetShape

filter_SetShape ENDP



.DATA
    ;// given an index, retrieve the command
    iir_command_id_table LABEL DWORD
        dd  ID_IIR_1CP  ;// IIR_1CP 0   "1C&P 2 poles",
        dd  ID_IIR_1CZ  ;// IIR_1CZ 1   "1C&Z 2 zeros",
        dd  ID_IIR_LP1  ;// IIR_LP1 2   "LP1 l&ow pass 1",
        dd  ID_IIR_HP1  ;// IIR_HP1 3   "HP1 h&igh pass 1",
        dd  ID_IIR_LP2  ;// IIR_LP2 4   "&LP2 low pass 2",
        dd  ID_IIR_HP2  ;// IIR_HP2 5   "&HP2 high pass 2",
        dd  ID_IIR_BP2  ;// IIR_BP2 6   "&BP2 band pass 2",
        dd  ID_IIR_BR2  ;// IIR_BR2 7   "B&R2 band reject 2",
        dd  ID_DECAY_BOTH
        dd  ID_DECAY_ABOVE
        dd  ID_DECAY_BELOW

.CODE



ASSUME_AND_ALIGN
filter_InitMenu PROC

        ASSUME esi:PTR IIR_OSC_MAP

    ;// check the correct filter function

        mov eax, [esi].dwUser
        and eax, IIR_TYPE_TEST
        DEBUG_IF < eax !>= NUM_FILTERS > ;// some how we lost track !!
        mov ecx, iir_command_id_table[eax*4]
        invoke CheckDlgButton, popup_hWnd, ecx, BST_CHECKED

    ;// check the auto gain or turn it off

        mov eax, [esi].dwUser
        and eax, IIR_TYPE_TEST
        .IF eax == IIR_LP1 || eax == IIR_HP1 || eax == IIR_DECAY_BOTH || eax == IIR_DECAY_ABOVE || eax == IIR_DECAY_BELOW
            invoke CheckDlgButton, popup_hWnd, ID_IIR_UNITY, BST_UNCHECKED
            ENABLE_CONTROL popup_hWnd, ID_IIR_UNITY, 0
        .ELSE
            ENABLE_CONTROL popup_hWnd, ID_IIR_UNITY, 1
            mov eax, [esi].dwUser
            .IF eax & IIR_AUTO_GAIN
                invoke CheckDlgButton, popup_hWnd, ID_IIR_UNITY, BST_CHECKED
            .ENDIF
        .ENDIF

    ;// press detail if it's on

        xor ecx, ecx
        .IF [esi].dwUser & IIR_SHOW_DETAIL
            inc ecx
        .ENDIF
        invoke CheckDlgButton, popup_hWnd, ID_IIR_DETAIL, ecx

    ;// return zero or build popup will try to resize

        xor eax, eax

    ;// that's it

        ret

filter_InitMenu ENDP


ASSUME_AND_ALIGN
filter_Command PROC

        ASSUME esi:PTR IIR_OSC_MAP
        ASSUME ebp:PTR LIST_CONTEXT
        ;// eax has the command id

    ;// check if we are a filter command
    ;// we'll scan backwards looking for an id match

        mov edx, NUM_FILTERS - 1    ;// edx is the resultant filter index
        .REPEAT
            .IF eax == iir_command_id_table[edx*4]

                mov eax, [esi].dwUser           ;// getthe current settings
                mov [esi].iir.old_filter, eax   ;// store in old settings
                and eax, NOT(IIR_TYPE_TEST)     ;// remove old filter index
                or eax, edx                     ;// put in new filter index
                or eax, IIR_NEED_INTERP         ;// set this too, old_filter already stored
                mov [esi].dwUser, eax           ;// store the new settings
                jmp force_redraw

            .ENDIF
            dec edx
        .UNTIL SIGN?

    ;// nope, check if we are auto gain

    cmp eax, ID_IIR_UNITY
        jne @F

    ;// toggle the auto gain bit

        mov eax, [esi].dwUser
        mov [esi].iir.old_filter, eax   ;// store the old filter setting
        or eax, IIR_NEED_INTERP ;// turn on the need interp for new setting
        xor eax, IIR_AUTO_GAIN          ;// flip the auto gain bit
        mov [esi].dwUser, eax           ;// store new settings

        mov eax, POPUP_SET_DIRTY
        jmp force_redraw

@@: cmp eax, ID_IIR_DETAIL
    jne osc_Command ;// @F

        mov eax, IIR_DETAIL_ADJUST_X
        mov edx, IIR_DETAIL_ADJUST_Y

        BITC [esi].dwUser, IIR_SHOW_DETAIL
        .IF CARRY?
            neg eax
            neg edx
        .ENDIF
        point_AddToTL [esi].rect

    force_redraw:

        GDI_INVALIDATE_OSC HINTI_OSC_MOVED OR HINTI_OSC_SHAPE_CHANGED ;// force a call to set shape
        mov eax, POPUP_SET_DIRTY OR POPUP_REDRAW_OBJECT OR POPUP_INITMENU
        or [esi].dwUser, IIR_NEED_UPDATE    ;// make sure we update the filter params

        ret

filter_Command ENDP




;////////////////////////////////////////////////////////////////////
;//
;//
;//     _LoadUndo
;//

ASSUME_AND_ALIGN
filter_LoadUndo PROC

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
        or eax, IIR_NEED_UPDATE OR IIR_NEED_INTERP
        or [esi].dwHintI, HINTI_OSC_MOVED OR HINTI_OSC_SHAPE_CHANGED    ;// force a call to set shape
        and eax, NOT IIR_CLIP_NOW
        mov [esi].dwUser, eax

        ret

filter_LoadUndo ENDP

;//
;//
;//     _LoadUndo
;//
;////////////////////////////////////////////////////////////////////








;////////////////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
filter_GetUnit PROC

        ASSUME esi:PTR IIR_OSC_MAP  ;// must preserve
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


filter_GetUnit ENDP


;////////////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
filter_Ctor PROC

        ;// register call
        ASSUME ebp:PTR LIST_CONTEXT ;// preserve
        ASSUME esi:PTR IIR_OSC_MAP  ;// preserve
        ASSUME edi:PTR OSC_BASE     ;// may destroy
        ASSUME ebx:PTR FILE_OSC     ;// may destroy
        ASSUME edx:PTR FILE_HEADER  ;// may destroy

        mov eax, [esi].dwUser
        .IF eax & IIR_OLD_CRAP
            and eax, 1
        .ENDIF
        .IF !edx
            mov eax, IIR_LP2 OR IIR_AUTO_GAIN
        .ENDIF
        ;// make certain we have a useful value
        mov edx, eax
        and edx, IIR_TYPE_TEST
        .IF edx >= NUM_FILTERS
            mov eax, IIR_LP1
        .ENDIF
        ;// set up the object with what we just did
        or [esi].iir.last_render_state, -1  ;// force a redisplay
        or eax, IIR_NEED_UPDATE OR IIR_NEED_INTERP
        and eax, NOT IIR_CLIP_NOW

        mov [esi].dwUser, eax

        ret

filter_Ctor ENDP


ASSUME_AND_ALIGN
filter_Dtor PROC

    ASSUME esi:PTR IIR_OSC_MAP

    xor eax, eax
    or  eax, [esi].iir.dib
    .IF !ZERO?

        invoke dib_Free,    eax

    .ENDIF

    ret

filter_Dtor ENDP






















;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
;//
;// ABox_Decay_2.asm
;//
;//
;//     ABOX232: revamped from ABox_Decay.asm to operate in the osc_1cp filter




;//////////////////////////////////////////////////////////////////////////
comment ~ /*

    generic formula:

        Y[n] = Y[n-1] * ( 1-D[n] ) + OPT() *  X[n] * D[n]

    clarifications: stored in osc.dwUser

        OPT( above ) =  X[n] >= Y[n-1] ? 1 : 0
        OPT( below ) =  X[n] =< Y[n-1] ? 1 : 0
        OPT( either) =  1

    recieve states: choose one from each column

        / dX dD above  \                  nX is also zX
        | sD sD below  |  27 states       nD is also zD
        \ nX nD either /

    default values if not connected:

        X=S small number
        D=1 millionth

    internal values:

        I   X.dwUser    last output value

    gotcha's:

        when I is close to X,
        we set I equal to X resulting in a small nonlinearity

*/ comment ~
;////////////////////////////////////////////////////////////////////////////////////


    ;// old settings
    ;// new can use the similar bit maps

    ;// settings stored in object.user

        DECAY_ABOVE equ   00000001h ;// accumulate if above current
        DECAY_BELOW equ   00000002h ;// accumulate if below current

        DECAY_TEST  equ   00000003h ;// off for both
    ;// DECAY_MASK  equ  0FFFFFFFCh

    ;// for preventing denormals and wasted cycles
    ;// we test when I stops changing with this

        ;// IIR_DECAY_TEST EQU 000y ;//

        DECAY_I_TEST    equ 007Fh   ;// works out to 8 tests per frame

comment ~ /*

OLD ;// OSC_MAP for this object

    OSC_MAP STRUCT

        OSC_OBJECT  {}
        pin_x   APIN    {}  0
        pin_d   APIN    {}  1
        pin_y   APIN    {}  2
        data_y  dd SAMARY_LENGTH DUP (0)

    OSC_MAP ENDS

*/ comment ~


.CODE


;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////






;//////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////
;//////
;//////
;//////     D E C A Y   M A C R O S
;//////
;//////


    X_mem   TEXTEQU <DWORD PTR [esi+ecx*4]>
    D_mem   TEXTEQU <DWORD PTR [ebx+ecx*4]>


comment ~ /*

    these macros are categorized first by dD, sD, nD
    then sub catororized by dX, sX, and nZ
    then sub sub catagorized by above, below and either

    the top level router is the first macro of the group
    then the sub and sub-sub macros are listed

    blocking pin-changing requires at most two hits (over two frames)
    to store_remaining, with the second have ecx=0

    preventing denormals:

    for sX or nX, we only test a few times per frame
    and call store-remaining when I stops changing

    for dX:

    for the case of X=0 or X=very_small we rely on IF_NOT_TINY_NUMBER
    which will eventually stop the signal before generating denormals.

    but not soon enough.
    future versions will have to account for this

*/ comment ~


;///////////////////////////////////////////////////////////////////////////////////
;//
;//   DECAY_CALC_dXdD--!diode?--dXdD_either
;//                         \
;//                            above?--dXdD_above
;//                                \
;//                                 dXdD_below
;//
;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;////
;////   dXdD        DECAY_CALC_dXdD ;// I         top level router///////////////////////////////
;////
DECAY_CALC_dXdD MACRO

    LOCAL diode, WereDone

    fld1    ;// 1   I
    fxch    ;// I   1
    xor ecx, ecx

        test ebp, DECAY_TEST
        jnz diode
        jmp dXdD_either_EnterLoop

        dXdD_either ;// MACRO

        jmp WereDone

    diode:

        test ebp, DECAY_ABOVE
        jz  dXdD_below_EnterLoop
        jmp dXdD_above_EnterLoop

        dXdD_above  ;// MACRO
        jmp WereDone

        dXdD_below  ;// MACRO

    WereDone:

    fxch        ;// 1   I
    mov ebp, PIN_CHANGING
    fstp st     ;// I
    jmp AllDone

    ENDM


;//////////////////////////////////////////////////////////////////////////////////

dXdD_either MACRO

    LOCAL TopOfLoop

ALIGN 16
TopOfLoop:          ;// I   1

    fadd            ;// I   1
    fst DWORD PTR [edi]
    add edi, 4

dXdD_either_EnterLoop:

    fld D_mem       ;//  D  I   1
    fabs            ;// D   I   1
    fld X_mem       ;// X   D   I   1
    fxch            ;//  D  X   I   1
    fmul st(1), st  ;//  D  XD  I   1
    fsubr st, st(3) ;// 1-D XD  I   1

    inc ecx
    cmp ecx, SAMARY_LENGTH
    fmulp st(2), st ;//  XD I(1-D)  1
    jnz TopOfLoop

    fadd            ;// I   1
    fst DWORD PTR [edi]

    ENDM

;///////////////////////////////////////////////////////////////////////////////////

dXdD_above MACRO

    LOCAL TopOfLoop_1, TopOfLoop_2, NoX, NoDecay, WereDone

ALIGN 16
TopOfLoop_1:        ;// XD  I   1

    fadd            ;// I   1

TopOfLoop_2:        ;// I   1

    fst DWORD PTR [edi]
    add edi, 4

dXdD_above_EnterLoop:

    ;// load and test
    fld X_mem       ;// X   I   1
    fucom
    fnstsw ax
    inc ecx
    sahf
    jz NoDecay
    fld D_mem       ;// D   X   I   1
    fabs
    jb NoX

        fmul st(1), st  ;// D   XD  I   1
        fsubr st, st(3) ;// 1-D XD  I   1

        cmp ecx, SAMARY_LENGTH

        fmulp st(2), st
        jnz TopOfLoop_1

        fadd
        jmp WereDone

    NoX:
                        ;// D   X   I   1
        fsubr st, st(3) ;// 1-D X   I   1
        fxch            ;// X   1-D I   1
        fstp st         ;// 1-D I   1

        cmp ecx, SAMARY_LENGTH
        fmul            ;// I   1
        jnz TopOfLoop_2
        jmp WereDone

    NoDecay:
                        ;// X   I   1
        fstp st         ;// I   1
        cmp ecx, SAMARY_LENGTH
        jb TopOfLoop_2

WereDone:

    fst DWORD PTR [edi]

    ENDM

;///////////////////////////////////////////////////////////////////////////////////


dXdD_below MACRO

    LOCAL TopOfLoop_1, TopOfLoop_2, NoX, NoDecay, WereDone

ALIGN 16
TopOfLoop_1:        ;// XD  I   1

    fadd            ;// I   1

TopOfLoop_2:        ;// I   1

    fst DWORD PTR [edi]
    add edi, 4

dXdD_below_EnterLoop:

    ;// load and test
    fld X_mem       ;// X   I   1
    fucom
    fnstsw ax
    inc ecx
    sahf
    jz NoDecay
    fld D_mem       ;// D   X   I   1
    fabs
    ja NoX

        fmul st(1), st  ;// D   XD  I   1
        fsubr st, st(3) ;// 1-D XD  I   1

        cmp ecx, SAMARY_LENGTH

        fmulp st(2), st
        jnz TopOfLoop_1

        fadd
        jmp WereDone

    NoX:
                        ;// D   X   I   1
        fsubr st, st(3) ;// 1-D X   I   1
        fxch            ;// X   1-D I   1
        fstp st         ;// 1-D I   1

        cmp ecx, SAMARY_LENGTH
        fmul            ;// I   1
        jnz TopOfLoop_2
        jmp WereDone

    NoDecay:
                        ;// X   I   1
        fstp st         ;// I   1
        cmp ecx, SAMARY_LENGTH
        jb TopOfLoop_2

WereDone:

    fst DWORD PTR [edi]

    ENDM



;///////////////////////////////////////////////////////////////////////////////////
;//
;//                            sXdD_until_noI--store_remaining
;//                           /
;//    DECAY_CALC_sXdD--doide?--above?--I<X?--sXdD_until_noI--store_remaining
;//                                  |      \
;//                                  |       X>0?--dD_until_I_below_X--store_remaining
;//                                  |           \
;//                                  |            dD_until_zero
;//                                |
;//                            (below)--I>X?--sXdD_until_noI--store_remaining
;//                                         \
;//                                          X<0?--dD_until_I_above_X--store_remaining
;//                                              \
;//                                               dD_until_zero
;//
;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;////
;////   sXdD    ;// X   I//////////////////////////////////////////////////////////////////
;////

DECAY_CALC_sXdD MACRO

    LOCAL setup_dD_until_noI, setup_store_remaining, setup_dD_until_zero

    rcr eax, 1  ;// mov carry back into eax
    .IF ebp & DECAY_TEST

        fucom       ;// X   I
        fnstsw ax   ;// eax has both sign of X, and X comp I

        .IF ebp & DECAY_ABOVE

            sahf
            ja setup_dD_until_noI       ;// is X below I
            jz setup_store_remaining

            or eax, eax
            js setup_dD_until_zero

            fxch        ;// I   X
            fld1        ;// 1   I   X
            fxch        ;// I   1   X
            jmp dD_until_I_below_X_EnterLoop

        .ELSE   ;// DECAY BELOW

            sahf
            jb setup_dD_until_noI
            jz setup_store_remaining

            or eax, eax
            jns setup_dD_until_zero

            fxch        ;// I   X
            fld1        ;// 1   I   X
            fxch        ;// I   1   X
            jmp dD_until_I_above_X_EnterLoop

        .ENDIF

    setup_dD_until_zero:

        fstp st     ;// I
        fld1        ;// 1   I
        fxch        ;// I   1

        jmp dD_until_zero_EnterLoop

    .ENDIF

setup_dD_until_noI:

    fxch        ;// I   X
    fld1        ;// 1   I   X
    fxch        ;// I   1   X
    jmp sXdD_until_noI_EnterLoop

setup_store_remaining:

    fstp st
    jmp store_remaining

    ;// macros expand here

    sXdD_until_noI

    dD_until_I_below_X

    dD_until_I_above_X

    dD_until_zero


    ENDM


;//////////////////////////////////////////////////////////////////////////////////

sXdD_until_noI MACRO

    LOCAL TopOfLoop, do_test, WereDone

ALIGN 16
TopOfLoop:

    fst DWORD PTR [edi]
    add edi, 4

sXdD_until_noI_EnterLoop:

                    ;// I   1   X
    fld D_mem       ;// D   I   1   X
    fabs
    test ecx, DECAY_I_TEST
    fsubr st, st(2) ;//  1-D    I   1   X

    jz do_test
                        ;// don't need to preserve i
        fmul            ;// i   1   X
        fld D_mem       ;// D   i   1   X
        fabs
        fmul st, st(3)  ;// XD  i   1   X
        inc ecx
        cmp ecx, SAMARY_LENGTH
        fadd            ;// I   1   X
        jb TopOfLoop
        jmp WereDone

    do_test:            ;// have to preserve I
                        ;//  1-D    I   1   X
        fmul st, st(1)  ;// i   I   1   X
        fld D_mem       ;// D   i   I   1   X
        fabs
        fmul st, st(4)  ;//  XD i   I   1   X
        fadd            ;// i   I   1   X
        fxch            ;// I   i   1   X
        fsub st, st(1)  ;// z?  i   1   X
        fstp _1cp_temp_1

        IF_NOT_TINY_NUMBER _1cp_temp_1

            inc ecx
            cmp ecx, SAMARY_LENGTH
            jb TopOfLoop

        .ELSE

            fxch st(2)  ;// store I
            ;// STORE X
            fstp st
            fstp st
            jmp store_remaining

        .ENDIF

WereDone:

    fst DWORD PTR [edi]
    fxch st(2)
    fstp st
    fstp st
    mov ebp, PIN_CHANGING
    jmp AllDone

    ENDM

;//////////////////////////////////////////////////////////////////////////////////

dD_until_I_below_X MACRO

    LOCAL TopOfLoop, no_more_decay, WereDone

TopOfLoop:

    fst DWORD PTR [edi]
    add edi, 4

dD_until_I_below_X_EnterLoop:

                    ;// I   1   X
    fucom st(2)     ;//
    fnstsw ax
    sahf
    jbe no_more_decay

    fld D_mem       ;// D   I   1   X
    fabs
    fsubr st, st(2) ;// 1-D I   1   X
    inc ecx
    cmp ecx, SAMARY_LENGTH
    fmul            ;// i   1   X
    jb TopOfLoop
    jmp WereDone

no_more_decay:      ;// i   1   X

    fxch st(2)  ;// store I
    ;// STORE X !!!
    fstp st
    fstp st
    jmp store_remaining

WereDone:

    fxch st(2)
    fstp st
    fstp st
    fst DWORD PTR [edi]
    mov ebp, PIN_CHANGING
    jmp AllDone

    ENDM


;///////////////////////////////////////////////////////////////////////////////////

dD_until_I_above_X MACRO

    LOCAL TopOfLoop, no_more_decay, WereDone

TopOfLoop:

    fst DWORD PTR [edi]
    add edi, 4

dD_until_I_above_X_EnterLoop:

    fld D_mem       ;// D   I   1   X
    fabs
    fsubr st, st(2) ;// 1-D I   1   X
    fmul            ;// i   1   X

                    ;// I   1   X
    fucom st(2)     ;//
    fnstsw ax
    sahf
    jae no_more_decay

    inc ecx
    cmp ecx, SAMARY_LENGTH
    jb TopOfLoop
    jmp WereDone

no_more_decay:      ;// i   1   X

    fxch st(2)      ;// store I
    ;// STORE X !!!
    fstp st
    fstp st
    jmp store_remaining

WereDone:

    fxch st(2)
    fstp st
    fstp st
    fst DWORD PTR [edi]
    mov ebp, PIN_CHANGING
    jmp AllDone

    ENDM

;//////////////////////////////////////////////////////////////////////////////////

dD_until_zero MACRO

    LOCAL TopOfLoop, do_test, WereDone

TopOfLoop:

    fst DWORD PTR [edi]
    add edi, 4

dD_until_zero_EnterLoop:

    fld D_mem       ;// D   I   1
    fabs
    fsubr st, st(2) ;// 1-D I   1

    test ecx, DECAY_I_TEST

    fmul            ;// i   1

    jz do_test

    inc ecx
    cmp ecx, SAMARY_LENGTH
    jb TopOfLoop
    jmp WereDone

do_test:

    fst _1cp_temp_1
    IF_NOT_TINY_NUMBER _1cp_temp_1

        inc ecx
        cmp ecx, SAMARY_LENGTH
        jb TopOfLoop
        jmp WereDone

    .ENDIF

    fstp st     ;// store zero
    fstp st
    fldz
    jmp store_remaining

WereDone:

    fxch
    fstp st
    mov ebp, PIN_CHANGING
    fst DWORD PTR [edi]
    jmp AllDone

    ENDM


;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;////

DECAY_CALC_nXdD MACRO   ;// I

    ;// X is either not connected, or is very small

    fldz
    clc
    jmp sXdD

    ENDM





;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;////
;////   dXsD    ;// DA  D   I///////////////////////////////////////////////////////////////
;////

DECAY_CALC_dXsD MACRO   ;// DA  D   I

LOCAL diode, WereDone

    fxch st(2)      ;// I   D   DA

    test ebp, DECAY_TEST
    jnz diode
    jmp dXsD_either_EnterLoop

    dXsD_either ;// MACRO
    jmp WereDone

    diode:

        test ebp, DECAY_ABOVE
        jz  dXsD_below_EnterLoop
        jmp dXsD_above_EnterLoop

        dXsD_above  ;// MACRO

        jmp WereDone

        dXsD_below  ;// MACRO

WereDone:       ;// I D DA

    fxch        ;// D I DA
    fstp st     ;// I DA
    fxch        ;// DA I
    fstp st     ;// I

    mov ebp, PIN_CHANGING

    jmp AllDone

    ENDM

;/////////////////////////////////////////////////////////////////////////////////

dXsD_either MACRO

    LOCAL TopOfLoop

TopOfLoop:

    fst DWORD PTR [edi]
    add edi, 4

dXsD_either_EnterLoop:
                    ;// I   D   DA
    fmul st, st(2)  ;// i   D   DA
    fld X_mem       ;//  X  i   D   DA
    fmul st, st(2)  ;// DX  i   D   DA

    inc ecx
    cmp ecx, SAMARY_LENGTH
    fadd            ;//  I  D   DA
    jnz TopOfLoop
    fst DWORD PTR [edi]

    ENDM

;/////////////////////////////////////////////////////////////////////////////


dXsD_above MACRO

    LOCAL TopOfLoop, NoX, WereDone

ALIGN 16
TopOfLoop:

    fst DWORD PTR [edi]
    add edi, 4

dXsD_above_EnterLoop:
                    ;// I   D   DA
    fld st(2)       ;// DA  I   D   DA
    fmul st, st(1)  ;// i   I   D   DA
    fld X_mem       ;//  X  i   I   D   DA
    fucom st(2)
    fnstsw ax
    inc ecx
    sahf
    jb NoX

        fmul st, st(3)  ;// XD  i   I   D   DA
        fxch st(2)      ;//  I   i   XD  D   DA
        fstp st         ;//  i  XD  D   DA

        cmp ecx, SAMARY_LENGTH
        fadd            ;//  I  D   DA
        jnz TopOfLoop
        jmp WereDone

    NoX:

        fstp st         ;//  i  I   D   DA
        fxch            ;//  I  i   D   DA
        cmp ecx, SAMARY_LENGTH
        fstp st         ;// i   D   DA
        jnz TopOfLoop

WereDone:

    fst DWORD PTR [edi]

    ENDM



;/////////////////////////////////////////////////////////////////////////////


dXsD_below MACRO

    LOCAL TopOfLoop, NoX, WereDone

ALIGN 16
TopOfLoop:

    fst DWORD PTR [edi]
    add edi, 4

dXsD_below_EnterLoop:
                    ;// I   D   DA
    fld st(2)       ;// DA  I   D   DA
    fmul st, st(1)  ;// i   I   D   DA
    fld X_mem       ;//  X  i   I   D   DA
    fucom st(2)
    fnstsw ax
    inc ecx
    sahf
    ja NoX

        fmul st, st(3)  ;// XD  i   I   D   DA
        fxch st(2)      ;//  I   i   XD  D   DA
        fstp st         ;//  i  XD  D   DA

        cmp ecx, SAMARY_LENGTH
        fadd            ;//  I  D   DA
        jnz TopOfLoop
        jmp WereDone

    NoX:

        fstp st         ;//  i  I   D   DA
        fxch            ;//  I  i   D   DA

        cmp ecx, SAMARY_LENGTH
        fstp st         ;// i   D   DA
        jnz TopOfLoop

WereDone:

    fst DWORD PTR [edi]

    ENDM

;//////////////////////////////////////////////
;//////////////////////////////////////////////
;//////////////////////////////////////////////



;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;//
;//                            sXsD_until_noI--store_remaining
;//                           /
;//    DECAY_CALC_sXsD--doide?--above?--I<X?--sXsD_until_noI--store_remaining
;//                                  |      \
;//                                  |       X>0?--sD_until_I_below_X--store_remaining
;//                                  |           \
;//                                  |            sD_until_zero
;//                                |
;//                            (below)--I>X?--sXsD_until_noI--store_remaining
;//                                         \
;//                                          X<0?--sD_until_I_above_X--store_remaining
;//                                              \
;//                                               sD_until_zero
;//
;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;////
;////   sXsD    ;// X   DA  D   I/////////////////////////////////////////////////////////////
;////

DECAY_CALC_sXsD MACRO

    LOCAL setup_sD_until_noI, setup_store_remaining, setup_sD_until_zero

    rcr eax, 1  ;// mov carry back into eax (sign of X)
    .IF ebp & DECAY_TEST

        fucom st(3) ;// X   DA  D   I
        fnstsw ax   ;// eax has both sign of X, and X comp I

        .IF ebp & DECAY_ABOVE

            sahf
            ja setup_sD_until_noI
            jz setup_store_remaining

            or eax, eax
            js setup_sD_until_zero

                            ;// X   DA  D   I
            fxch st(2)      ;// D   DA  X   I
            fstp st         ;// DA  X   I
            fxch            ;// X   DA  I
            fxch st(2)      ;// I   DA  X

            jmp sD_until_I_below_X_EnterLoop

        .ELSE   ;// DECAY BELOW

            sahf
            jb setup_sD_until_noI
            jz setup_store_remaining

            or eax, eax
            jns setup_sD_until_zero

                            ;// X   DA  D   I
            fxch st(2)      ;// D   DA  X   I
            fstp st         ;// DA  X   I
            fxch            ;// X   DA  I
            fxch st(2)      ;// I   DA  X

            jmp sD_until_I_above_X_EnterLoop

        .ENDIF

    setup_sD_until_zero:
                    ;// X   DA  D   I
        fstp st     ;// DA  D   I
        fxch        ;// D   DA  I
        fstp st     ;// DA  I
        fxch        ;// I   DA

        jmp sD_until_zero_EnterLoop

    .ENDIF

setup_sD_until_noI:
                    ;// X   DA  D   I
    fmulp st(2),st  ;// DA  XD  I
    fxch            ;// XD  DA  I
    fxch st(2)      ;// I   DA  XD
    jmp sXsD_until_noI_EnterLoop

setup_store_remaining:
                ;// X   DA  D   I
    fstp st     ;// DA  D   I
    fstp st     ;// D   I
    fstp st     ;// I
    jmp store_remaining

    ;// macros expand here

    sXsD_until_noI

    sD_until_I_below_X

    sD_until_I_above_X

    sD_until_zero

    ENDM


;//////////////////////////////////////////////////////////////////////////////////

sXsD_until_noI MACRO    ;// I   DA

    LOCAL TopOfLoop, do_test, WereDone

ALIGN 16
TopOfLoop:

    fst DWORD PTR [edi]
    add edi, 4

sXsD_until_noI_EnterLoop:

                        ;// I   DA  XD
    test ecx, DECAY_I_TEST
    jz do_test
                        ;// don't need to preserve i
        fmul st, st(1)  ;// i   DA  XD
        inc ecx
        cmp ecx, SAMARY_LENGTH
        fadd st, st(2)
        jb TopOfLoop
        jmp WereDone

    do_test:            ;// have to preserve I
                        ;// I   DA  XD
        fld st          ;// I   I   DA  XD
        fmul st, st(2)  ;// i   I   DA  XD
        fadd st, st(3)
        fxch            ;// I   i   DA  XD
        fsub st, st(1)  ;// z?  i   DA  XD
        fstp _1cp_temp_1;// i   DA  XD

        IF_NOT_TINY_NUMBER _1cp_temp_1

            inc ecx
            cmp ecx, SAMARY_LENGTH
            jb TopOfLoop

        .ELSE
                        ;// i   DA  XD
            fxch st(2)  ;// XD  DA  i
            fstp st
            fstp st

            jmp store_remaining

        .ENDIF

WereDone:

    fst DWORD PTR [edi]
    fxch st(2)  ;// XD  DA  i
    fstp st     ;// DA  i
    fstp st     ;// i
    mov ebp, PIN_CHANGING
    jmp AllDone


    ENDM

;//////////////////////////////////////////////////////////////////////////////////

sD_until_I_below_X MACRO    ;// I   DA  XD  X

    LOCAL TopOfLoop, no_more_decay, WereDone

TopOfLoop:

    fst DWORD PTR [edi]
    add edi, 4

sD_until_I_below_X_EnterLoop:

                    ;// I   DA  X
    fucom st(2)     ;//
    fnstsw ax
    sahf
    jbe no_more_decay

    inc ecx
    cmp ecx, SAMARY_LENGTH
    fmul st, st(1)  ;// i   DA  X
    jb TopOfLoop
    jmp WereDone

no_more_decay:      ;// i   DA  X

    fxch st(2)  ;// store I
    fstp st     ;// DA  I
    fstp st     ;// I
    jmp store_remaining

WereDone:

    fxch st(2)  ;// X   DA  I
    fstp st     ;// DA  I
    fstp st     ;// I
    fst DWORD PTR [edi]
    mov ebp, PIN_CHANGING
    jmp AllDone

    ENDM


;///////////////////////////////////////////////////////////////////////////////////

sD_until_I_above_X MACRO    ;// I   DA  XD  X

    LOCAL TopOfLoop, no_more_decay, WereDone

TopOfLoop:

    fst DWORD PTR [edi]
    add edi, 4

sD_until_I_above_X_EnterLoop:

                    ;// I   DA  X
    fucom st(2)     ;//
    fnstsw ax
    sahf
    jae no_more_decay

    inc ecx
    cmp ecx, SAMARY_LENGTH
    fmul st, st(1)  ;// i   DA  X
    jb TopOfLoop
    jmp WereDone

no_more_decay:      ;// i   DA  X

    fxch st(2)  ;// store I
    fstp st     ;// DA  I
    fstp st     ;// I
    jmp store_remaining

WereDone:

    fxch st(2)  ;// X   DA  I
    fstp st     ;// DA  I
    fstp st     ;// I
    fst DWORD PTR [edi]
    mov ebp, PIN_CHANGING
    jmp AllDone

    ENDM


;//////////////////////////////////////////////////////////////////////////////////

sD_until_zero MACRO     ;// I   DA

    LOCAL TopOfLoop, do_test, WereDone

TopOfLoop:

    fst DWORD PTR [edi]
    add edi, 4

sD_until_zero_EnterLoop:

    test ecx, DECAY_I_TEST
    fmul st, st(1)  ;// i   DA
    jz do_test

        inc ecx
        cmp ecx, SAMARY_LENGTH
        jb TopOfLoop
        jmp WereDone

do_test:

    fst _1cp_temp_1
    IF_NOT_TINY_NUMBER _1cp_temp_1

        inc ecx
        cmp ecx, SAMARY_LENGTH
        jb TopOfLoop
        jmp WereDone

    .ENDIF

    fstp st     ;// store zero
    fstp st
    fldz
    jmp store_remaining

WereDone:

    fxch
    fstp st
    mov ebp, PIN_CHANGING
    fst DWORD PTR [edi]
    jmp AllDone

    ENDM



;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////
;//////             old conventions:    new conventions:
;//////                       X esi     X0 TEXTEQU <[ebx+ecx*4]>            ;// input
;//////                       D ebx     F0 TEXTEQU <[edx+ecx*4]>            ;// current F value
;////// decay_Calc            Y edi     Y0 TEXTEQU <[esi].data_y[ecx*4]>    ;// current output
;//////                   stats ebp     must return to iir_calc_done
;//////                                 XLAST  TEXTEQU <[ebx+LAST_SAMPLE]>  ;// last input value
;//                                     Y1 TEXTEQU <[esi].data_y[LAST_SAMPLE]>      ;// prev output FROM PREVIOUS FRAME
;//
;//
.CODE
ASSUME_AND_ALIGN
decay_Calc PROC

    push ebp
    push esi

GET_OSC_FROM ecx, esi           ;// xfer the osc to ecx
OSC_TO_PIN_INDEX ecx, edi, 3    ;// get pin_y

DEBUG_IF <!![edi].pPin> ;// supposed to be connected to calc

    ;// set up for the rest

    mov eax, [edi].dwStatus     ;// load previous X output status
    mov edi, [edi].pData        ;// edi is Y data
    and eax, PIN_CHANGING       ;// mask off all but X pin changing
    OSC_TO_PIN_INDEX ecx,esi, 0 ;// esi is X


    lea edx, [edi+LAST_SAMPLE]  ;// point edx at I
    IF_NOT_TINY_NUMBER edx      ;// check that I was not a denaormal
        fld DWORD PTR [edx]     ;// I, was not a denormal
    .ELSE
        fldz                    ;// I was a denormal, use zero instead
    .ENDIF


    mov ebp, [ecx].dwUser           ;// load ebp with our options
    OSC_TO_PIN_INDEX ecx, ebx, 1    ;// ebx is D
    xor ecx, ecx                    ;// clear out ecx now
    or ebp, eax                     ;// ebp has both options and pin changing

    mov iir_clip, ecx   ;// turn this off !

    IF_CONNECTED ebx

        .IF eax & PIN_CHANGING                  ;// dD

            or ebp, IIR_DETAIL_CHANGED  ;// need to set

            IF_CONNECTED esi

                .IF eax & PIN_CHANGING          ;// dXdD

                    DECAY_CALC_dXdD         ;// I

                .ELSE                           ;// sX

                    IF_NOT_TINY_NUMBER esi

                        fld DWORD PTR [esi] ;// X   I

sXdD:                   DECAY_CALC_sXdD         ;// sXdD  carry flag still has sign

                    .ENDIF

                .ENDIF

            .ENDIF                              ;// nXdD

            DECAY_CALC_nXdD                 ;// I

        .ELSE                           ;// sD

            fld DWORD PTR [ebx]         ;// D   I
            fabs
            fld1                        ;// 1   D   I
            fsub st, st(1)              ;// DA  D   I
            fabs

        D_not_connected:    ;// jmped from above

            IF_CONNECTED esi

                .IF eax & PIN_CHANGING      ;// dXsD

                decay_calc_dXsD:            ;// accessed by dXnD macro

                    DECAY_CALC_dXsD

                .ELSE                       ;// sX

                    IF_NOT_TINY_NUMBER esi  ;// sXsD

                        fld DWORD PTR [esi] ;// X   DA  D   I

                    X_not_connected_sD:     ;// jmped from below

                        DECAY_CALC_sXsD     ;// sXsD     ;// carry flag still has signn

                    .ENDIF

                .ENDIF

            .ENDIF                          ;// nX

            fldz                    ;// zero is the default
            jmp X_not_connected_sD

        .ENDIF

    .ELSE   ;// D not connected or zero

        fld decay_default_D     ;// D   I
        fld1                    ;// 1   D   I
        fsub st, st(1)          ;// DA  D   I
        jmp D_not_connected

    .ENDIF

    DEBUG_IF<1> ;/// this should NEVER be hit

;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;///
;///    special end points for the above mess
;///
;/// these can be called from several of the above routines
;/// so make sure things are set up right

store_remaining:
;//
;// hit from many many places, may also cover store_all
;// ecx must be the number already stored
;// edi must be correct X data
;// fpu must be ;// Ict X data
;// if ecx is !zero, then we set PIN_CHANGING
;// else if ebp has PIN changing set, then we fill Y with st(0)
;// else if X != Y, then we fill Y with st(0)

;// this is the ONLY way we can block the PIN_CHANGING

    fst _1cp_temp_1     ;// I

    .IF !ecx    ;// check if ecx is zero

        mov eax, _1cp_temp_1
        and ebp, PIN_CHANGING
        jnz store_remaining_2

        cmp eax, DWORD PTR [edi]
        jz store_remaining_1

    store_remaining_2:

        ;// have to store
        mov ecx, SAMARY_LENGTH
        rep stosd

    store_remaining_1:

        xor ebp, ebp

    .ELSE ;// ecx was not zero

        sub ecx, SAMARY_LENGTH
        neg ecx
        mov eax, _1cp_temp_1    ;// load the X value
        rep stosd               ;// fill the rest of the frame

        mov ebp, PIN_CHANGING

    .ENDIF


AllDone:

    ;// this cleans up every thing
    ;// ebp must be the new X status
    ;// st(0) must be final value for Y

    mov ecx, ebp
    DEBUG_IF <ecx & NOT PIN_CHANGING>   ;// ah ha !

pop esi
pop ebp

    OSC_TO_PIN_INDEX esi, edx, 3
    and [edx].dwStatus, NOT PIN_CHANGING
    fstp st ;// [edx].dwUser
    or [edx].dwStatus, ecx

    jmp iir_calc_done




decay_Calc ENDP









ASSUME_AND_ALIGN

ENDIF   ;// USE_THIS_FILE
END
