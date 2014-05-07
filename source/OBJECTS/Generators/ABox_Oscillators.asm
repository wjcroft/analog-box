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
;// ABox_Oscillators.asm          more notes below
;//

;// TOC:
;//
;//
;// wrap_this PROC
;// osc_Oscillator_Calc_2 PROC uses ebp esi
;// osc_osc_SetInputLetter PROC USES ebx
;// osc_Oscillator_InitMenu PROC
;// osc_Oscillator_Command PROC
;// osc_Oscillator_LoadUndo PROC
;// osc_Oscillator_SetDisplay PROC
;// osc_Oscillator_SetShape PROC
;// osc_Oscillator_PrePlay PROC
;// osc_Oscillator_Ctor PROC
;// osc_Oscillator_GetUnit  PROC



OPTION CASEMAP:NONE
.586
.MODEL FLAT

USE_THIS_FILE equ 1

IFDEF USE_THIS_FILE

    .NOLIST
    include <ABox.inc>
    .LIST

comment ~ /*

    generic formula:

        Q[n] = Wrap( Q[n-1] + F[n] )    ;// internal Q
        Y[n] = W( Q[n] ) * A[n] + O[n]  ;// output

    clarifications: stored in osc.dwUser

        W( sine wave ) = LOOKUP table
        W( triangle )  = LOOKUP table
        W( ramp )      = Q[n]
        W( square )    = sign( Q[n] )

    recieve states: choose one from each column

        / dF dA dO sine     \
        | pF sA sO triangle |   192 states
        | mF zA nO ramp     |
        \ nF nA    square   /

    internal values:

        Q   X.dwUser    last phase angle


*/ comment ~


.DATA

;// core

    osc_Oscillator OSC_CORE {osc_Oscillator_Ctor,,osc_Oscillator_PrePlay,osc_Oscillator_Calc_2 }

;// gui

    OSC_GUI {,osc_Oscillator_SetShape,,,,
        osc_Oscillator_Command,osc_Oscillator_InitMenu,,,
        osc_SaveUndo,osc_Oscillator_LoadUndo,
        osc_Oscillator_GetUnit }

;// hardware

    OSC_HARD { }

;// data

    OSC_DATA_LAYOUT { NEXT_Oscillator,IDB_OSCILLATOR,OFFSET popup_OSCILLATOR,,
        4,4,
        SIZEOF OSC_OBJECT + (SIZEOF APIN) * 4,
        SIZEOF OSC_OBJECT + (SIZEOF APIN) * 4 + SAMARY_SIZE,
        SIZEOF OSC_OBJECT + (SIZEOF APIN) * 4 + SAMARY_SIZE  }

;// display

    OSC_DISPLAY_LAYOUT { r_rect_container,,ICON_LAYOUT( 0,1,2,0) }

;// pins

    APIN_init {-1.0 ,sz_Frequency   ,'F',,UNIT_HERTZ    } ;// frequency
    APIN_init { 0.66,sz_Amplitude   ,'A',,UNIT_AUTO_UNIT} ;// amplitude
    APIN_init { 0.33,sz_Offset      ,'O',,UNIT_AUTO_UNIT} ;// offset
    APIN_init { 0.0 ,               ,'=',,PIN_OUTPUT OR UNIT_AUTO_UNIT  } ;// output pin

    short_name  db  'Osc',0
    description db  'Generates one of eight periodic wave forms. Has Frequency/Phase, Amplitude and Offset inputs.',0
    ALIGN 4

;// GDI DATA

    ;// list of pSources

    oscillator_source_list  LABEL DWORD
        dd OSC_SINE_PSOURCE     ;// sine wave
        dd OSC_TRI_PSOURCE      ;// triangle wave
        dd OSC_RAMP_PSOURCE     ;// ramp wave
        dd OSC_SQUARE_PSOURCE   ;// square wave
        dd OSC_RAMP1_PSOURCE
        dd OSC_RAMP2_PSOURCE
        dd OSC_SQUARE1_PSOURCE
        dd OSC_SQUARE2_PSOURCE


    ;// shape template
    OSCILLATOR_SIZE_X equ 45
    OSCILLATOR_SIZE_Y equ 32


    ;// flags for object.dwUser

        OSC_OSC_SINE   equ  00000000h
        OSC_OSC_TRI    equ  00000001h
        OSC_OSC_RAMP   equ  00000002h
        OSC_OSC_SQUARE equ  00000003h

        OSC_OSC_RAMP1   equ 00000004h
        OSC_OSC_RAMP2   equ 00000005h
        OSC_OSC_SQUARE1 equ 00000006h
        OSC_OSC_SQUARE2 equ 00000007h

        OSC_OSC_MASK   equ 0FFFFFFF8h
        OSC_OSC_TEST   equ  00000007h

        OSC_OSC_PHASE   equ 00010000h

        OSC_RESET_ONE   EQU 00020000h   ;// added ABOX232: reset q at -1
        OSC_RESET_ZERO  EQU 00040000h   ;// added ABOX232: reset q at 0
        OSC_RESET_TEST  EQU OSC_RESET_ONE OR OSC_RESET_ZERO  ;// if neither is set, use old scheme

    ;// X.dwUser stores the last Q

    ;// we change the pin letters for phase mode
    ;// these point at the font_shape

        osc_osc_pFreq   dd  0
        osc_osc_pPhase  dd  0


;////////////////////////////////////////////////////////////////////
;//
;//
;//     CALC JUMP TABLES
;//
comment ~ /*

    after  much thought, and far too much work,
    the following system presents itself:

    adopt the concept of jump pointers to caclulate functions

    these are classified by the various combinations of:

        0   nP  pin is not connected
        1   sP  pin is connected, but the signal is not changing
        2   dP  pin is connected and the signal IS changing

    because there are three values for each pin
    we get a base three number system

*/ comment ~

;//
;//
;//
;//
;////////////////////////////////////////////////////////////////////

;////////////////////////////////////////////////////////////////////
;//
;//
;//     OSC_MAP for this file
;//

    OSC_MAP STRUCT

        OSC_OBJECT      {}  ;// osc object and osc map are at the same name level
        pin_F   APIN    {}  ;// F pin
        pin_A   APIN    {}  ;// A pin
        pin_O   APIN    {}  ;// O pin
        pin_X   APIN    {}  ;// X pin
        data_X  dd  SAMARY_LENGTH dup(0)

    OSC_MAP ENDS

;//
;//
;//
;//
;////////////////////////////////////////////////////////////////////






comment ~ /*

    for this osc we get the three pins plus the 2 columns of user settings

        F   A   O
    0   nF  nA  nO      freq    lookup
    1   sF  sA  sO      phase   ramp
    2   dF  dA  dO              square
        0   3   9       81      27
        esi ebx edx

*/ comment ~

    osc_calc_jump LABEL DWORD

    dd  freq_lookup_nFnAnO, freq_lookup_sFnAnO, freq_lookup_dFnAnO
    dd  freq_lookup_nFsAnO, freq_lookup_sFsAnO, freq_lookup_dFsAnO
    dd  freq_lookup_nFdAnO, freq_lookup_sFdAnO, freq_lookup_dFdAnO

    dd  freq_lookup_nFnAsO, freq_lookup_sFnAsO, freq_lookup_dFnAsO
    dd  freq_lookup_nFsAsO, freq_lookup_sFsAsO, freq_lookup_dFsAsO
    dd  freq_lookup_nFdAsO, freq_lookup_sFdAsO, freq_lookup_dFdAsO

    dd  freq_lookup_nFnAdO, freq_lookup_sFnAdO, freq_lookup_dFnAdO
    dd  freq_lookup_nFsAdO, freq_lookup_sFsAdO, freq_lookup_dFsAdO
    dd  freq_lookup_nFdAdO, freq_lookup_sFdAdO, freq_lookup_dFdAdO

    dd  freq_ramp_nFnAnO,   freq_ramp_sFnAnO,   freq_ramp_dFnAnO
    dd  freq_ramp_nFsAnO,   freq_ramp_sFsAnO,   freq_ramp_dFsAnO
    dd  freq_ramp_nFdAnO,   freq_ramp_sFdAnO,   freq_ramp_dFdAnO

    dd  freq_ramp_nFnAsO,   freq_ramp_sFnAsO,   freq_ramp_dFnAsO
    dd  freq_ramp_nFsAsO,   freq_ramp_sFsAsO,   freq_ramp_dFsAsO
    dd  freq_ramp_nFdAsO,   freq_ramp_sFdAsO,   freq_ramp_dFdAsO

    dd  freq_ramp_nFnAdO,   freq_ramp_sFnAdO,   freq_ramp_dFnAdO
    dd  freq_ramp_nFsAdO,   freq_ramp_sFsAdO,   freq_ramp_dFsAdO
    dd  freq_ramp_nFdAdO,   freq_ramp_sFdAdO,   freq_ramp_dFdAdO

    dd  freq_square_nFnAnO, freq_square_sFnAnO, freq_square_dFnAnO
    dd  freq_square_nFsAnO, freq_square_sFsAnO, freq_square_dFsAnO
    dd  freq_square_nFdAnO, freq_square_sFdAnO, freq_square_dFdAnO

    dd  freq_square_nFnAsO, freq_square_sFnAsO, freq_square_dFnAsO
    dd  freq_square_nFsAsO, freq_square_sFsAsO, freq_square_dFsAsO
    dd  freq_square_nFdAsO, freq_square_sFdAsO, freq_square_dFdAsO

    dd  freq_square_nFnAdO, freq_square_sFnAdO, freq_square_dFnAdO
    dd  freq_square_nFsAdO, freq_square_sFsAdO, freq_square_dFsAdO
    dd  freq_square_nFdAdO, freq_square_sFdAdO, freq_square_dFdAdO



    dd  phase_lookup_nFnAnO,    phase_lookup_sFnAnO,    phase_lookup_dFnAnO
    dd  phase_lookup_nFsAnO,    phase_lookup_sFsAnO,    phase_lookup_dFsAnO
    dd  phase_lookup_nFdAnO,    phase_lookup_sFdAnO,    phase_lookup_dFdAnO

    dd  phase_lookup_nFnAsO,    phase_lookup_sFnAsO,    phase_lookup_dFnAsO
    dd  phase_lookup_nFsAsO,    phase_lookup_sFsAsO,    phase_lookup_dFsAsO
    dd  phase_lookup_nFdAsO,    phase_lookup_sFdAsO,    phase_lookup_dFdAsO

    dd  phase_lookup_nFnAdO,    phase_lookup_sFnAdO,    phase_lookup_dFnAdO
    dd  phase_lookup_nFsAdO,    phase_lookup_sFsAdO,    phase_lookup_dFsAdO
    dd  phase_lookup_nFdAdO,    phase_lookup_sFdAdO,    phase_lookup_dFdAdO


    dd  phase_ramp_nFnAnO,  phase_ramp_sFnAnO,  phase_ramp_dFnAnO
    dd  phase_ramp_nFsAnO,  phase_ramp_sFsAnO,  phase_ramp_dFsAnO
    dd  phase_ramp_nFdAnO,  phase_ramp_sFdAnO,  phase_ramp_dFdAnO

    dd  phase_ramp_nFnAsO,  phase_ramp_sFnAsO,  phase_ramp_dFnAsO
    dd  phase_ramp_nFsAsO,  phase_ramp_sFsAsO,  phase_ramp_dFsAsO
    dd  phase_ramp_nFdAsO,  phase_ramp_sFdAsO,  phase_ramp_dFdAsO

    dd  phase_ramp_nFnAdO,  phase_ramp_sFnAdO,  phase_ramp_dFnAdO
    dd  phase_ramp_nFsAdO,  phase_ramp_sFsAdO,  phase_ramp_dFsAdO
    dd  phase_ramp_nFdAdO,  phase_ramp_sFdAdO,  phase_ramp_dFdAdO



    dd  phase_square_nFnAnO,    phase_square_sFnAnO,    phase_square_dFnAnO
    dd  phase_square_nFsAnO,    phase_square_sFsAnO,    phase_square_dFsAnO
    dd  phase_square_nFdAnO,    phase_square_sFdAnO,    phase_square_dFdAnO

    dd  phase_square_nFnAsO,    phase_square_sFnAsO,    phase_square_dFnAsO
    dd  phase_square_nFsAsO,    phase_square_sFsAsO,    phase_square_dFsAsO
    dd  phase_square_nFdAsO,    phase_square_sFdAsO,    phase_square_dFdAsO

    dd  phase_square_nFnAdO,    phase_square_sFnAdO,    phase_square_dFnAdO
    dd  phase_square_nFsAdO,    phase_square_sFsAdO,    phase_square_dFsAdO
    dd  phase_square_nFdAdO,    phase_square_sFdAdO,    phase_square_dFdAdO



.CODE

ASSUME_AND_ALIGN
wrap_this PROC

    ;// destroys eax
    ;// fpu must have number to wrap
    ;// requires 1 free register

    xor eax, eax
    ftst        ;// X
    fld1        ;// 1   X
    fnstsw ax   ;// get the sign bit
    sahf
    jnc @F
    fchs
@@: fxch        ;// X   1
    fprem
    fnstsw ax   ;// get the C1 bit
    fxch
    and ax, 200h
    .IF !ZERO?
        fsub
    .ELSE
        fstp st
    .ENDIF

    ret

wrap_this ENDP







.CODE



ASSUME_AND_ALIGN
osc_Oscillator_Calc_2 PROC uses ebp esi

    stack_size = 4
    call_depth = 0

    st_ptr  TEXTEQU <(DWORD PTR [esp+00h+call_depth*4])>    ;// pointer for lookup tables
    st_osc  TEXTEQU <(DWORD PTR [esp+04h+call_depth*4])>    ;// esi

    sub esp, stack_size     ;// make room for st_ptr temps

    mov ebp, esi
    ASSUME ebp:PTR OSC_MAP

    DEBUG_IF <!!([ebp].pin_X.pPin)>     ;// supposed to be connected

    xor ecx, ecx
    ASSUME ecx:PTR DWORD
    OSCMAP_TO_PIN_DATA ebp, esi, pin_F, 0
    OSCMAP_TO_PIN_DATA ebp, ebx, pin_A, 3
    OSCMAP_TO_PIN_DATA ebp, edx, pin_O, 9

    mov eax, [ebp].dwUser
    btr eax, LOG2(OSC_OSC_PHASE)    ;// test and turn off the bit
    .IF CARRY?
        add ecx, 81
    .ENDIF

    and eax, OSC_OSC_TEST   ;// ABOX232: bummer, this was missing, now we have to reassign the number

    lea edi, [ebp].data_X   ;// load the data pointer NOW
    ASSUME edi:PTR DWORD

    cmp eax, OSC_OSC_SINE
    jnz @F

        mov eax, math_pSin
        mov st_ptr, eax
        jmp osc_calc_jump[ecx*4]

@@: cmp eax, OSC_OSC_TRI
    jnz @F

        mov eax, math_pTri
        mov st_ptr, eax
        jmp osc_calc_jump[ecx*4]

@@: cmp eax, OSC_OSC_RAMP1
    jnz @F

        mov eax, math_pRamp1
        mov st_ptr, eax
        jmp osc_calc_jump[ecx*4]

@@: cmp eax, OSC_OSC_RAMP2
    jnz @F

        mov eax, math_pRamp2
        mov st_ptr, eax
        jmp osc_calc_jump[ecx*4]

@@: cmp eax, OSC_OSC_SQUARE1
    jnz @F

        mov eax, math_pSquare1
        mov st_ptr, eax
        jmp osc_calc_jump[ecx*4]

@@: cmp eax, OSC_OSC_SQUARE2
    jnz @F

        mov eax, math_pSquare2
        mov st_ptr, eax
        jmp osc_calc_jump[ecx*4]

@@: cmp eax, OSC_OSC_SQUARE
    jnz @F  ;// must be triangle

        add ecx, 27
@@:     add ecx, 27

    jmp osc_calc_jump[ecx*4]







;////////////////////////////////////////////////////////////////////
;//
;//
;//     freq lookup sF
;//

ALIGN 16
freq_lookup_sFnAnO::    test [esi], 7FFFFFFFh   ;// check for zero frequency first
                        jz freq_lookup_nFnAnO
                        call freq_lookup_sF     ;// good to go
                        jmp all_done
ALIGN 16
freq_lookup_sFsAnO::    test [esi], 7FFFFFFFh   ;// check for zero frequency first
                        jz freq_lookup_nFsAnO
                        test [ebx],7FFFFFFFh    ;// check for zero gain
                        jz freq_sFzAnO
                        call freq_lookup_sF     ;// good to go
                        jmp output_dXsAnO
ALIGN 16
freq_lookup_sFdAnO::    test [esi], 7FFFFFFFh   ;// check for zero frequency first
                        jz freq_lookup_nFdAnO
                        call freq_lookup_sF     ;// good to go
                        jmp output_dXdAnO
ALIGN 16
freq_lookup_sFnAsO::    test [edx], 7FFFFFFFh   ;// check for zero offset
                        jz freq_lookup_sFnAnO
                        test [esi], 7FFFFFFFh   ;// check for zero frequency next
                        jz freq_lookup_nFnAsO
                        call freq_lookup_sF     ;// good to go
                        jmp output_dXnAsO
ALIGN 16
freq_lookup_sFnAdO::    test [esi],7FFFFFFFh    ;// check for zero frequency
                        jz freq_lookup_nFnAdO
                        call freq_lookup_sF     ;// good to go
                        jmp output_dXnAdO
ALIGN 16
freq_lookup_sFdAdO::    test [esi],7FFFFFFFh    ;// check for zero frequency
                        jz freq_lookup_nFdAdO
                        call freq_lookup_sF     ;// good to go
                        jmp output_dXdAdO
ALIGN 16
freq_lookup_sFsAsO::    test [edx],7FFFFFFFh    ;// check for zero offset
                        jz freq_lookup_sFsAnO
                        test [esi],7FFFFFFFh    ;// check for zero frequency
                        jz freq_lookup_nFsAsO
                        test [ebx],7FFFFFFFh    ;// check for zero gain
                        jz freq_sFzAsO
                        call freq_lookup_sF     ;// good to go
                        jmp output_dXsAsO
ALIGN 16
freq_lookup_sFdAsO::    test [edx],7FFFFFFFh    ;// check for zero offset
                        jz freq_lookup_sFdAnO
                        test [esi],7FFFFFFFh    ;// check for zero frequency
                        jz freq_lookup_nFdAsO
                        call freq_lookup_sF     ;// good to go
                        jmp output_dXdAsO
ALIGN 16
freq_lookup_sFsAdO::    test [esi],7FFFFFFFh    ;// check for zero frequency
                        jz freq_lookup_nFsAdO
                        test [ebx],7FFFFFFFh    ;// check for zero gain
                        jz freq_sFzAdO
                        call freq_lookup_sF     ;// good to go
                        jmp output_dXsAdO

;//
;//     freq lookup sF
;//
;//
;////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////
;//
;//     freq lookup dF
;//
;//

ALIGN 16
freq_lookup_dFnAnO::    call freq_lookup_dF     ;// good to go
                        jmp all_done
ALIGN 16
freq_lookup_dFsAnO::    test [ebx],7FFFFFFFh    ;// check for zero gain
                        jz freq_dFzAnO
                        call freq_lookup_dF     ;// good to go
                        jmp output_dXsAnO
ALIGN 16
freq_lookup_dFdAnO::    call freq_lookup_dF     ;// good to go
                        jmp output_dXdAnO
ALIGN 16
freq_lookup_dFnAsO::    test [edx], 7FFFFFFFh   ;// check for zero offset
                        jz freq_lookup_dFnAnO
                        call freq_lookup_dF     ;// good to go
                        jmp output_dXnAsO
ALIGN 16
freq_lookup_dFsAsO::    test [ebx], 7FFFFFFFh   ;// check for zero gain
                        jz freq_dFzAsO
                        call freq_lookup_dF     ;// good to go
                        jmp output_dXsAsO
ALIGN 16
freq_lookup_dFdAsO::    test [edx], 07FFFFFFFh  ;// check for zero offset
                        jz freq_lookup_dFdAnO
                        call freq_lookup_dF     ;// good to go
                        jmp output_dXdAsO
ALIGN 16
freq_lookup_dFnAdO::    call freq_lookup_dF     ;// good to go
                        jmp output_dXnAdO
ALIGN 16
freq_lookup_dFsAdO::    test [ebx], 7FFFFFFFh   ;// check for zero gain
                        jz freq_dFzAdO
                        call freq_lookup_dF     ;// good to go
                        jmp output_dXsAdO
ALIGN 16
freq_lookup_dFdAdO::    call freq_lookup_dF
                        jmp output_dXdAdO

;//
;//     freq lookup dF
;//
;//
;////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////
;//
;//
;//     freq lookup nF
;//

ALIGN 16
freq_lookup_nFnAnO::    call phase_lookup_sF        ;// good to go
                        jmp store_static
ALIGN 16
freq_lookup_nFsAnO::    call phase_lookup_sF        ;// really no since checking all this stuff
                        mov st_ptr, eax
                        fld [ebx]
                        fmul st_ptr
                        fstp st_ptr
                        mov eax, st_ptr
                        jmp store_static
ALIGN 16
freq_lookup_nFdAnO::    call phase_lookup_sF        ;// check for zero Q
                        test eax, 7FFFFFFFh
                        jz store_static
                                            ;// good to go
                        mov st_ptr, eax     ;// store the lookedup value
                        mov esi, ebx        ;// use A as the X source
                        lea ebx, st_ptr     ;// point ebx at the static A
                        jmp output_dXsAnO_now   ;// call the now version
ALIGN 16
freq_lookup_nFnAsO::    call phase_lookup_sF        ;// no since checking anything
                        mov st_ptr, eax
                        fld [edx]
                        fadd st_ptr
                        fstp st_ptr
                        mov eax, st_ptr
                        jmp store_static
ALIGN 16
freq_lookup_nFsAsO::    call phase_lookup_sF        ;// no since checking anything
                        mov st_ptr, eax
                        fld [ebx]
                        fmul st_ptr
                        fadd [edx]
                        fstp st_ptr
                        mov eax, st_ptr
                        jmp store_static
ALIGN 16
freq_lookup_nFdAsO::    test [edx], 7FFFFFFFh   ;// check for zero offset
                        jz freq_lookup_nFdAnO
                        call phase_lookup_sF            ;// test for zero Q
                        test eax, 7FFFFFFFh
                        jz output_nXnAsO
                                            ;// good to go
                        mov esi, ebx        ;// use A as the X source
                        mov st_ptr, eax     ;// store the looked value
                        lea ebx, st_ptr     ;// use ptr as const A
                        jmp output_dXsAsO_now   ;// jump to the now version
ALIGN 16
freq_lookup_nFnAdO::    call phase_lookup_sF        ;// test for zero Q
                        test eax, 7FFFFFFFh
                        jz output_nXnAdO
                                            ;// good to go
                        mov st_ptr, eax ;// save the lookedup value
                        mov esi, edx    ;// use O as the C source
                        lea edx, st_ptr ;// use Q as the const offset
                        jmp output_dXnAsO_now   ;// jump to the now version
ALIGN 16
freq_lookup_nFsAdO::    test [ebx],7FFFFFFh ;// check for zero gain
                        jz output_nXnAdO
                        call phase_lookup_sF        ;// test for zero Q
                        test eax, 7FFFFFFFh
                        jz output_nXnAdO
                                            ;// good to go
                        mov st_ptr, eax ;// save the lookedup value
                        fld st_ptr      ;// load it into fpu
                        fmul [ebx]      ;// multiply by constant gain
                        fstp st_ptr     ;// store back in st_ptr
                        mov esi, edx    ;// use O as the data source

                        comment ~ /*
                        ABOX 234
                            jmp output_dXnAdO_now   ;// jump to the now version
                            this is the wrong place to jump to
                            we want to add a constant to O
                            since we are replacing X by O
                            we should be calling    dXnAsO
                            which calls math_add_dXsB
                            where esi must be X, edx must be B
                        */ comment ~
                        lea edx, st_ptr     ;// set edx as the constanst
                        jmp output_dXnAsO_now   ;// jump to the now version
ALIGN 16
freq_lookup_nFdAdO::    call phase_lookup_sF    ;// test for zero Q
                        test eax, 7FFFFFFFh
                        jz output_nXnAdO
                                            ;// good to go
                        mov esi, ebx        ;// send A to esi
                        mov st_ptr, eax     ;// store the returned value
                        lea ebx, st_ptr     ;// point ebx at static X
                        jmp output_dXsAdO_now   ;// jump to the now version

;//
;//
;//     freq lookup nF
;//
;////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////
;//
;//
;//  phase_lookup dF
;//

ALIGN 16
phase_lookup_dFnAnO::   call phase_lookup_dF    ;// good to go
                        jmp all_done
ALIGN 16
phase_lookup_dFsAnO::   test [ebx], 7FFFFFFFh   ;// check for zero gain
                        jz phase_dFzAnO
                        call phase_lookup_dF    ;// good to go
                        jmp output_dXsAnO
ALIGN 16
phase_lookup_dFdAnO::   call phase_lookup_dF    ;// good to go
                        jmp output_dXdAnO
ALIGN 16
phase_lookup_dFnAsO::   test [edx], 7FFFFFFFh   ;// check for zero offset
                        jz phase_lookup_dFnAnO
                        call phase_lookup_dF    ;// good to go
                        jmp output_dXnAsO
ALIGN 16
phase_lookup_dFsAsO::   test [edx], 7FFFFFFFh   ;// check for zero offset
                        jz phase_lookup_dFsAnO
                        test [ebx], 7FFFFFFFh   ;// check for zero gain
                        jz phase_dFzAsO
                        call phase_lookup_dF    ;// good to go
                        jmp output_dXsAsO
ALIGN 16
phase_lookup_dFdAsO::   test [edx], 7FFFFFFFh   ;// check for zero offset
                        jz phase_lookup_dFdAnO
                        call phase_lookup_dF    ;// good to go
                        jmp output_dXdAsO
ALIGN 16
phase_lookup_dFnAdO::   call phase_lookup_dF    ;// good to go
                        jmp output_dXnAdO
ALIGN 16
phase_lookup_dFsAdO::   test [ebx], 7FFFFFFFh   ;// check for zero gain
                        jz phase_dFzAdO
                        call phase_lookup_dF    ;// good to go
                        jmp output_dXsAdO
ALIGN 16
phase_lookup_dFdAdO::   call phase_lookup_dF    ;// good to go
                        jmp output_dXdAdO


;//
;//
;//  phase_lookup dF
;//
;////////////////////////////////////////////////////////////////////




;////////////////////////////////////////////////////////////////////
;//
;//
;//  phase_lookup sF
;//  phase_lookup nF
;//

ALIGN 16
phase_lookup_sFdAnO::   mov eax, [esi]  ;// always xfer the value from the input
                        mov [ebp].pin_X.dwUser, eax
phase_lookup_nFdAnO::   call phase_lookup_sF    ;// check for zero W
                        test eax, 7FFFFFFFh
                        jz store_static
                                        ;// good to go
                        mov st_ptr, eax         ;// store the looked up value
                        mov esi, ebx            ;// use A pin as the X input
                        lea ebx, st_ptr         ;// use ebx as the static A
                        jmp output_dXsAnO_now   ;// jump to the now version
ALIGN 16
phase_lookup_sFdAsO::   mov eax, [esi]  ;// always xfer the value from the input
                        mov [ebp].pin_X.dwUser, eax

phase_lookup_nFdAsO::   call phase_lookup_sF    ;// check for zero W
                        test eax, 7FFFFFFFh
                        jz phase_lookup_zFsO
                                                ;// good to go
                        mov st_ptr, eax         ;// store the looked up value
                        mov esi, ebx            ;// use A pin as the X input
                        lea ebx, st_ptr         ;// use ebx as the static A
                        jmp output_dXsAsO_now   ;// jump to the now version
ALIGN 16
phase_lookup_sFdAdO::   mov eax, [esi]  ;// always xfer the value from the input
                        mov [ebp].pin_X.dwUser, eax
phase_lookup_nFdAdO::   call phase_lookup_sF    ;// check for zero W
                        test eax, 7FFFFFFFh
                        jz output_nXnAdO
                                                ;// good to go
                        mov st_ptr, eax         ;// store the looked up value
                        mov esi, ebx            ;// use A pin as the X input
                        lea ebx, st_ptr         ;// use ebx as the static A
                        jmp output_dXsAdO_now   ;// jump to the now version
ALIGN 16
phase_lookup_sFsAnO::   mov eax, [esi]      ;// always xfer the value from the input
                        mov [ebp].pin_X.dwUser, eax

phase_lookup_nFsAnO::   call phase_lookup_sF        ;// no since testing the value
                        mov st_ptr, eax
                        fld [ebx]
                        fmul st_ptr
                        fstp st_ptr
                        mov eax, st_ptr
                        jmp store_static
ALIGN 16
phase_lookup_sFsAsO::   mov eax, [esi]  ;// always xfer the value from the input
                        mov [ebp].pin_X.dwUser, eax
phase_lookup_nFsAsO::   call phase_lookup_sF    ;// no since testing the value
                        mov st_ptr, eax
                        fld [ebx]
                        fmul st_ptr
                        fadd [edx]
                        fstp st_ptr
                        mov eax, st_ptr
                        jmp store_static
ALIGN 16
phase_lookup_sFnAsO::   mov eax, [esi]  ;// always xfer the value from the input
                        mov [ebp].pin_X.dwUser, eax
phase_lookup_nFnAsO::   call phase_lookup_sF    ;// no since testing the value
                        mov st_ptr, eax
                        fld [edx]
                        fadd st_ptr
                        fstp st_ptr
                        mov eax, st_ptr
                        jmp store_static
ALIGN 16
phase_lookup_sFnAnO::   mov eax, [esi]  ;// always xfer the value from the input
                        mov [ebp].pin_X.dwUser, eax
phase_lookup_nFnAnO::   call phase_lookup_sF    ;// good to go
                        jmp store_static
ALIGN 16
phase_lookup_sFnAdO::   mov eax, [esi]  ;// always xfer the value from the input
                        mov [ebp].pin_X.dwUser, eax
phase_lookup_nFnAdO::   call phase_lookup_sF    ;// good to go
                        mov st_ptr, eax     ;// store it here
                        mov esi, edx        ;// xfer O pin to esi
                        lea edx, st_ptr     ;// load the O pin with the stored value
                        jmp output_dXnAsO_now   ;// jump to the now version
ALIGN 16
phase_lookup_sFsAdO::   mov eax, [esi]  ;// always xfer the value from the input
                        mov [ebp].pin_X.dwUser, eax
phase_lookup_nFsAdO::   call phase_lookup_sF    ;// good to go
                        mov st_ptr, eax     ;// store it here
                        fld [ebx]
                        fmul st_ptr
                        fstp st_ptr
                        mov esi, edx        ;// xfer O pin to esi
                        lea edx, st_ptr     ;// load the O pin with the stored value
                        jmp output_dXnAsO_now   ;// jump to the now version
ALIGN 16
phase_lookup_zFsO:      mov eax, [edx]      ;// W = ZERO
                        jmp store_static


;//
;//
;//  phase_lookup nF
;//  phase_lookup sF
;//
;////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////
;//
;//
;//     freq_ramp_sF
;//

ALIGN 16
freq_ramp_sFnAnO::  test [esi], 7FFFFFFFh   ;// check for zero frequency
                    jz freq_ramp_nFnAnO
                    call freq_ramp_sF       ;// good to go
                    jmp all_done
ALIGN 16
freq_ramp_sFsAnO::  test [esi], 7FFFFFFFh   ;// check for zero frequency
                    jz freq_ramp_nFsAnO
                    test [ebx], 7FFFFFFFh   ;// check for zero gain
                    jz freq_sFzAnO
                    call freq_ramp_sF       ;// good to go
                    jmp output_dXsAnO
ALIGN 16
freq_ramp_sFdAnO::  test [esi], 7FFFFFFFh   ;// check for zero frequency
                    jz freq_ramp_nFdAnO
                    call freq_ramp_sF       ;// good to go
                    jmp output_dXdAnO
ALIGN 16
freq_ramp_sFsAsO::  test [esi], 7FFFFFFFh   ;// check for zero frequency
                    jz freq_ramp_nFsAsO
                    test [edx], 7FFFFFFFh   ;// check for zero offset
                    jz freq_ramp_sFsAnO
                    test [ebx], 7FFFFFFFh   ;// check for zero gain
                    jz freq_sFzAsO
                    call freq_ramp_sF       ;// good to go
                    jmp output_dXsAsO
ALIGN 16
freq_ramp_sFdAsO::  test [esi], 7FFFFFFFh   ;// check for zero frequency
                    jz freq_ramp_nFdAsO
                    test [edx], 7FFFFFFFh   ;// check for zero offset
                    jz freq_ramp_sFdAnO
                    call freq_ramp_sF       ;// good to go
                    jmp output_dXdAsO
ALIGN 16
freq_ramp_sFnAdO::  test [esi], 7FFFFFFFh   ;// check for zero frequency
                    jz freq_ramp_nFnAdO
                    call freq_ramp_sF       ;// good to go
                    jmp output_dXnAdO

ALIGN 16
freq_ramp_sFsAdO::  test [esi], 7FFFFFFFh   ;// check for zero frequency
                    jz freq_ramp_nFsAdO
                    test [ebx], 7FFFFFFFh   ;// check for zero gain
                    jz freq_sFzAdO
                    call freq_ramp_sF       ;// good to go
                    jmp output_dXsAdO

ALIGN 16
freq_ramp_sFdAdO::  test [esi], 7FFFFFFFh   ;// check for zero frequency
                    jz freq_ramp_nFdAdO
                    call freq_ramp_sF       ;// good to go
                    jmp output_dXdAdO

ALIGN 16
freq_ramp_sFnAsO::  test [edx], 7FFFFFFFh   ;// check for zero offset
                    jz freq_ramp_sFnAnO
                    test [esi], 7FFFFFFFh   ;// check for zero frequency
                    jz freq_ramp_nFnAsO
                    call freq_ramp_sF       ;// good to go
                    jmp output_dXnAsO

;//
;//     freq_ramp_sF
;//
;//
;////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////
;//
;//
;//     freq_ramp_dF
;//


ALIGN 16
freq_ramp_dFnAnO::  call freq_ramp_dF       ;// good to go
                    jmp all_done
ALIGN 16
freq_ramp_dFsAnO::  test [ebx], 7FFFFFFFh   ;// check for zero gain
                    jz freq_dFzAnO
                    call freq_ramp_dF       ;// good to go
                    jmp output_dXsAnO
ALIGN 16
freq_ramp_dFdAnO::  call freq_ramp_dF       ;// good to go
                    jmp output_dXdAnO
ALIGN 16
freq_ramp_dFnAsO::  test [edx], 7FFFFFFFh   ;// check for zero offset
                    jz freq_ramp_dFnAnO
                    call freq_ramp_dF       ;// good to go
                    jmp output_dXnAsO
ALIGN 16
freq_ramp_dFsAsO::  test [edx], 7FFFFFFFh   ;// check for zero offset
                    jz freq_ramp_dFsAnO
                    test [ebx], 7FFFFFFFh   ;// check for zero gain
                    jz freq_dFzAsO
ALIGN 16
freq_ramp_dFdAsO::  test [edx], 7FFFFFFFh   ;// check for zero offset
                    jz freq_ramp_dFdAnO
                    call freq_ramp_dF       ;// good to go
                    jmp output_dXdAsO
ALIGN 16
freq_ramp_dFnAdO::  call freq_ramp_dF       ;// good to go
                    jmp output_dXnAdO
ALIGN 16
freq_ramp_dFsAdO::  test [ebx], 7FFFFFFFh   ;// check for zero gain
                    jz freq_dFzAdO
                    call freq_ramp_dF       ;// good to go
                    jmp output_dXsAdO
ALIGN 16
freq_ramp_dFdAdO::  call freq_ramp_dF       ;// good to go
                    jmp output_dXdAdO
;//
;//
;//     freq_ramp_dF
;//
;////////////////////////////////////////////////////////////////////

;////////////////////////////////////////////////////////////////////
;//
;//
;//     freq_ramp_nF
;//
ALIGN 16
freq_ramp_nFnAnO::  mov eax, [ebp].pin_X.dwUser ;// load the Q value
                    jmp store_static            ;// store static
ALIGN 16
freq_ramp_nFsAnO::  fld [ebp].pin_X.dwUser
                    fmul [ebx]
                    fstp st_ptr
                    mov eax, st_ptr
                    jmp store_static
ALIGN 16
freq_ramp_nFdAnO::  mov eax, [ebp].pin_X.dwUser
                    test eax, 7FFFFFFFh
                    jz store_static
                    mov esi, ebx
                    mov st_ptr, eax
                    lea ebx, st_ptr
                    jmp output_dXsAnO_now
ALIGN 16
freq_ramp_nFnAsO::  fld [ebp].pin_X.dwUser
                    fadd [edx]
                    fstp st_ptr
                    mov eax, st_ptr
                    jmp store_static
ALIGN 16
freq_ramp_nFsAsO::  fld [ebp].pin_X.dwUser
                    fmul [ebx]
                    fadd [edx]
                    fstp st_ptr
                    mov eax, st_ptr
                    jmp store_static
ALIGN 16
freq_ramp_nFdAsO::  test [edx], 7FFFFFFFh
                    jz freq_ramp_nFdAnO
                    mov eax, [ebp].pin_X.dwUser
                    test eax, 7FFFFFFFh
                    jz store_static
                    mov st_ptr, eax
                    mov esi, ebx
                    lea ebx, st_ptr
                    jmp output_dXsAsO_now
ALIGN 16
freq_ramp_nFnAdO::  mov eax, [ebp].pin_X.dwUser
                    test eax, 7FFFFFFFh
                    jz output_nXnAdO
                    mov st_ptr, eax
                    mov esi, edx
                    lea edx, st_ptr
                    jmp output_dXnAsO_now
ALIGN 16
freq_ramp_nFsAdO::  test [ebx], 7FFFFFFFh
                    jz output_nXnAdO
                    mov eax, [ebp].pin_X.dwUser
                    test eax, 7FFFFFFFh
                    jz output_nXnAdO
                    fld [ebp].pin_X.dwUser
                    fmul [ebx]
                    fstp st_ptr
                    mov esi, edx
                    lea edx, st_ptr
                    jmp output_dXnAsO_now
ALIGN 16
freq_ramp_nFdAdO::  mov eax, [ebp].pin_X.dwUser
                    test eax, 7FFFFFFFh
                    jz output_nXnAdO
                    mov esi, ebx
                    mov st_ptr, eax
                    lea ebx, st_ptr
                    jmp output_dXsAdO_now
;//
;//     freq_ramp_nF
;//
;//
;////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////
;//
;//
;//  phase_ramp_sF
;//  phase_ramp_nF
;//

ALIGN 16
phase_ramp_sFdAnO:: mov eax, [esi]  ;// always xfer the value from the input
                    mov [ebp].pin_X.dwUser, eax
phase_ramp_nFdAnO:: call phase_ramp_sF  ;// check for zero W
                    test eax, 7FFFFFFFh
                    jz store_static
                                    ;// good to go
                    mov st_ptr, eax         ;// store the looked up value
                    mov esi, ebx            ;// use A pin as the X input
                    lea ebx, st_ptr         ;// use ebx as the static A
                    jmp output_dXsAnO_now   ;// jump to the now version
ALIGN 16
phase_ramp_sFdAsO:: mov eax, [esi]  ;// always xfer the value from the input
                    mov [ebp].pin_X.dwUser, eax

phase_ramp_nFdAsO:: call phase_ramp_sF  ;// check for zero W
                    test eax, 7FFFFFFFh
                    jz phase_ramp_zFsO
                                            ;// good to go
                    mov st_ptr, eax         ;// store the looked up value
                    mov esi, ebx            ;// use A pin as the X input
                    lea ebx, st_ptr         ;// use ebx as the static A
                    jmp output_dXsAsO_now   ;// jump to the now version
ALIGN 16
phase_ramp_sFdAdO:: mov eax, [esi]  ;// always xfer the value from the input
                    mov [ebp].pin_X.dwUser, eax
phase_ramp_nFdAdO:: call phase_ramp_sF  ;// check for zero W
                    test eax, 7FFFFFFFh
                    jz output_nXnAdO
                                            ;// good to go
                    mov st_ptr, eax         ;// store the looked up value
                    mov esi, ebx            ;// use A pin as the X input
                    lea ebx, st_ptr         ;// use ebx as the static A
                    jmp output_dXsAdO_now   ;// jump to the now version
ALIGN 16
phase_ramp_sFsAnO:: mov eax, [esi]      ;// always xfer the value from the input
                    mov [ebp].pin_X.dwUser, eax

phase_ramp_nFsAnO:: call phase_ramp_sF      ;// no since testing the value
                    mov st_ptr, eax
                    fld [ebx]
                    fmul st_ptr
                    fstp st_ptr
                    mov eax, st_ptr
                    jmp store_static
ALIGN 16
phase_ramp_sFsAsO:: mov eax, [esi]  ;// always xfer the value from the input
                    mov [ebp].pin_X.dwUser, eax
phase_ramp_nFsAsO:: call phase_ramp_sF  ;// no since testing the value
                    mov st_ptr, eax
                    fld [ebx]
                    fmul st_ptr
                    fadd [edx]
                    fstp st_ptr
                    mov eax, st_ptr
                    jmp store_static
ALIGN 16
phase_ramp_sFnAsO:: mov eax, [esi]  ;// always xfer the value from the input
                    mov [ebp].pin_X.dwUser, eax
phase_ramp_nFnAsO:: call phase_ramp_sF  ;// no since testing the value
                    mov st_ptr, eax
                    fld [edx]
                    fadd st_ptr
                    fstp st_ptr
                    mov eax, st_ptr
                    jmp store_static
ALIGN 16
phase_ramp_sFnAnO:: mov eax, [esi]  ;// always xfer the value from the input
                    mov [ebp].pin_X.dwUser, eax
phase_ramp_nFnAnO:: call phase_ramp_sF  ;// good to go
                    jmp store_static
ALIGN 16
phase_ramp_sFnAdO:: mov eax, [esi]  ;// always xfer the value from the input
                    mov [ebp].pin_X.dwUser, eax
phase_ramp_nFnAdO:: call phase_ramp_sF  ;// good to go
                    mov st_ptr, eax     ;// store it here
                    mov esi, edx        ;// xfer O pin to esi
                    lea edx, st_ptr     ;// load the O pin with the stored value
                    jmp output_dXnAsO_now   ;// jump to the now version
ALIGN 16
phase_ramp_sFsAdO:: mov eax, [esi]  ;// always xfer the value from the input
                    mov [ebp].pin_X.dwUser, eax
phase_ramp_nFsAdO:: call phase_ramp_sF  ;// good to go
                    mov st_ptr, eax     ;// store it here
                    fld [ebx]
                    fmul st_ptr
                    fstp st_ptr
                    mov esi, edx        ;// xfer O pin to esi
                    lea edx, st_ptr     ;// load the O pin with the stored value
                    jmp output_dXnAsO_now   ;// jump to the now version
ALIGN 16
phase_ramp_zFsO:    mov eax, [edx]      ;// W = ZERO
                    jmp store_static


;//
;//
;//  phase_ramp_sF
;//  phase_ramp_dF
;//
;////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////
;//
;//
;//     phase_ramp_dF
;//

ALIGN 16
phase_ramp_dFnAnO:: call phase_ramp_dF  ;// good to go
                    jmp all_done
ALIGN 16
phase_ramp_dFsAnO:: test [ebx], 7FFFFFFFh   ;// check for zero gain
                    jz phase_dFzAnO
                    call phase_ramp_dF  ;// good to go
                    jmp output_dXsAnO
ALIGN 16
phase_ramp_dFdAnO:: call phase_ramp_dF  ;// good to go
                    jmp output_dXdAnO
ALIGN 16
phase_ramp_dFnAsO:: test [edx], 7FFFFFFFh   ;// check for zero offset
                    jz phase_ramp_dFnAnO
                    call phase_ramp_dF  ;// good to go
                    jmp output_dXnAsO
ALIGN 16
phase_ramp_dFsAsO:: test [edx], 7FFFFFFFh   ;// check for zero offset
                    jz phase_ramp_dFsAnO
                    test [ebx], 7FFFFFFFh   ;// check for zero gain
                    jz phase_dFzAsO
                    call phase_ramp_dF  ;// good to go
                    jmp output_dXsAsO
ALIGN 16
phase_ramp_dFdAsO:: test [edx], 7FFFFFFFh   ;// check for zero offset
                    jz phase_ramp_dFdAnO
                    call phase_ramp_dF  ;// good to go
                    jmp output_dXdAsO
ALIGN 16
phase_ramp_dFnAdO:: call phase_ramp_dF  ;// good to go
                    jmp output_dXnAdO
ALIGN 16
phase_ramp_dFsAdO:: test [ebx], 7FFFFFFFh   ;// check for zero gain
                    jz phase_dFzAdO
                    call phase_ramp_dF  ;// good to go
                    jmp output_dXsAdO
ALIGN 16
phase_ramp_dFdAdO:: call phase_ramp_dF  ;// good to go
                    jmp output_dXdAdO

;//
;//     phase_ramp_dF
;//
;//
;////////////////////////////////////////////////////////////////////





















;////////////////////////////////////////////////////////////////////
;//
;//
;//     freq_square_sF
;//
ALIGN 16
freq_square_sFnAnO::test [esi], 7FFFFFFFh   ;// check for zero frequency
                    jz freq_square_nFnAnO
                    call freq_square_sF     ;// good to go
                    jmp all_done
ALIGN 16
freq_square_sFsAnO::test [esi], 7FFFFFFFh   ;// check for zero frequency
                    jz freq_square_nFsAnO
                    test [ebx], 7FFFFFFFh   ;// check for zero gain
                    jz freq_sFzAnO
                    call freq_square_sF     ;// good to go
                    jmp output_dXsAnO
ALIGN 16
freq_square_sFdAnO::test [esi], 7FFFFFFFh   ;// check for zero frequency
                    jz freq_square_nFdAnO
                    call freq_square_sF     ;// good to go
                    jmp output_dXdAnO
ALIGN 16
freq_square_sFsAsO::test [esi], 7FFFFFFFh   ;// check for zero frequency
                    jz freq_square_nFsAsO
                    test [edx], 7FFFFFFFh   ;// check for zero offset
                    jz freq_square_sFsAnO
                    test [ebx], 7FFFFFFFh   ;// check for zero gain
                    jz freq_sFzAsO
                    call freq_square_sF     ;// good to go
                    jmp output_dXsAsO
ALIGN 16
freq_square_sFdAsO::test [esi], 7FFFFFFFh   ;// check for zero frequency
                    jz freq_square_nFdAsO
                    test [edx], 7FFFFFFFh   ;// check for zero offset
                    jz freq_square_sFdAnO
                    call freq_square_sF     ;// good to go
                    jmp output_dXdAsO
ALIGN 16
freq_square_sFnAdO::test [esi], 7FFFFFFFh   ;// check for zero frequency
                    jz freq_square_nFnAdO
                    call freq_square_sF     ;// good to go
                    jmp output_dXnAdO

ALIGN 16
freq_square_sFsAdO::test [esi], 7FFFFFFFh   ;// check for zero frequency
                    jz freq_square_nFsAdO
                    test [ebx], 7FFFFFFFh   ;// check for zero gain
                    jz freq_sFzAdO
                    call freq_square_sF     ;// good to go
                    jmp output_dXsAdO

ALIGN 16
freq_square_sFdAdO::test [esi], 7FFFFFFFh   ;// check for zero frequency
                    jz freq_square_nFdAdO
                    call freq_square_sF     ;// good to go
                    jmp output_dXdAdO

ALIGN 16
freq_square_sFnAsO::test [edx], 7FFFFFFFh   ;// check for zero offset
                    jz freq_square_sFnAnO
                    test [esi], 7FFFFFFFh   ;// check for zero frequency
                    jz freq_square_nFnAsO
                    call freq_square_sF     ;// good to go
                    jmp output_dXnAsO
;//
;//     freq_square_sF
;//
;//
;////////////////////////////////////////////////////////////////////

;////////////////////////////////////////////////////////////////////
;//
;//
;//     freq_square_dF
;//
ALIGN 16
freq_square_dFnAnO::call freq_square_dF     ;// good to go
                    jmp all_done
ALIGN 16
freq_square_dFsAnO::test [ebx], 7FFFFFFFh   ;// check for zero gain
                    jz freq_dFzAnO
                    call freq_square_dF     ;// good to go
                    jmp output_dXsAnO
ALIGN 16
freq_square_dFdAnO::call freq_square_dF     ;// good to go
                    jmp output_dXdAnO
ALIGN 16
freq_square_dFnAsO::test [edx], 7FFFFFFFh   ;// check for zero offset
                    jz freq_square_dFnAnO
                    call freq_square_dF     ;// good to go
                    jmp output_dXnAsO
ALIGN 16
freq_square_dFsAsO::test [edx], 7FFFFFFFh   ;// check for zero offset
                    jz freq_square_dFsAnO
                    test [ebx], 7FFFFFFFh   ;// check for zero gain
                    jz freq_dFzAsO
ALIGN 16
freq_square_dFdAsO::test [edx], 7FFFFFFFh   ;// check for zero offset
                    jz freq_square_dFdAnO
                    call freq_square_dF     ;// good to go
                    jmp output_dXdAsO
ALIGN 16
freq_square_dFnAdO::call freq_square_dF     ;// good to go
                    jmp output_dXnAdO
ALIGN 16
freq_square_dFsAdO::test [ebx], 7FFFFFFFh   ;// check for zero gain
                    jz freq_dFzAdO
                    call freq_square_dF     ;// good to go
                    jmp output_dXsAdO
ALIGN 16
freq_square_dFdAdO::call freq_square_dF     ;// good to go
                    jmp output_dXdAdO
;//
;//     freq_square_dF
;//
;//
;////////////////////////////////////////////////////////////////////

;////////////////////////////////////////////////////////////////////
;//
;//
;//     freq_square_nF
;//
ALIGN 16
freq_square_nFnAnO::call freq_square_nF ;// get correct value
            ;//     mov eax, st_ptr
                    jmp store_static            ;// store static
ALIGN 16
freq_square_nFsAnO::call freq_square_nF ;// get correct value
                    mov st_ptr, eax
                    fld st_ptr
                    fmul [ebx]
                    fstp st_ptr
                    mov eax, st_ptr
                    jmp store_static
ALIGN 16
freq_square_nFdAnO::call freq_square_nF ;// get correct value
                    test eax, 7FFFFFFFh
                    jz store_static
                    mov esi, ebx
                    mov st_ptr, eax
                    lea ebx, st_ptr
                    jmp output_dXsAnO_now

ALIGN 16
freq_square_nFnAsO::call freq_square_nF ;// get correct value
                    mov st_ptr, eax
                    fld st_ptr
                    fadd [edx]
                    fstp st_ptr
                    mov eax, st_ptr
                    jmp store_static
ALIGN 16
freq_square_nFsAsO::call freq_square_nF ;// get correct value
                    mov st_ptr, eax
                    fld st_ptr
                    fmul [ebx]
                    fadd [edx]
                    fstp st_ptr
                    mov eax, st_ptr
                    jmp store_static
ALIGN 16
freq_square_nFdAsO::test [edx], 7FFFFFFFh
                    jz freq_square_nFdAnO
                    call freq_square_nF ;// get correct value
                    test eax, 7FFFFFFFh
                    jz store_static
                    mov st_ptr, eax
                    mov esi, ebx
                    lea ebx, st_ptr
                    jmp output_dXsAsO_now
ALIGN 16
freq_square_nFnAdO::call freq_square_nF ;// get correct value
                    test eax, 7FFFFFFFh
                    jz output_nXnAdO
                    mov st_ptr, eax
                    mov esi, edx
                    lea edx, st_ptr
                    jmp output_dXnAsO_now
ALIGN 16
freq_square_nFsAdO::test [ebx], 7FFFFFFFh
                    jz output_nXnAdO
                    call freq_square_nF ;// get correct value
                    test eax, 7FFFFFFFh
                    jz output_nXnAdO
                    mov st_ptr, eax
                    fld st_ptr
                    fmul [ebx]
                    fstp st_ptr
                    mov esi, edx
                    lea edx, st_ptr
                    jmp output_dXnAsO_now
ALIGN 16
freq_square_nFdAdO::call freq_square_nF ;// get correct value
                    test eax, 7FFFFFFFh
                    jz output_nXnAdO
                    mov esi, ebx
                    mov st_ptr, eax
                    lea ebx, st_ptr
                    jmp output_dXsAdO_now
;//
;//     freq_square_nF
;//
;//
;////////////////////////////////////////////////////////////////////














;////////////////////////////////////////////////////////////////////
;//
;//
;//  phase_square_sF
;//  phase_square_nF
;//

ALIGN 16
phase_square_sFdAnO::   mov eax, [esi]  ;// always xfer the value from the input
                        mov [ebp].pin_X.dwUser, eax
phase_square_nFdAnO::   call phase_square_sF    ;// check for zero W
                        test eax, 7FFFFFFFh
                        jz store_static
                                        ;// good to go
                        mov st_ptr, eax         ;// store the looked up value
                        mov esi, ebx            ;// use A pin as the X input
                        lea ebx, st_ptr         ;// use ebx as the static A
                        jmp output_dXsAnO_now   ;// jump to the now version
ALIGN 16
phase_square_sFdAsO::   mov eax, [esi]  ;// always xfer the value from the input
                        mov [ebp].pin_X.dwUser, eax

phase_square_nFdAsO::   call phase_square_sF    ;// check for zero W
                        test eax, 7FFFFFFFh
                        jz phase_square_zFsO
                                                ;// good to go
                        mov st_ptr, eax         ;// store the looked up value
                        mov esi, ebx            ;// use A pin as the X input
                        lea ebx, st_ptr         ;// use ebx as the static A
                        jmp output_dXsAsO_now   ;// jump to the now version
ALIGN 16
phase_square_sFdAdO::   mov eax, [esi]  ;// always xfer the value from the input
                        mov [ebp].pin_X.dwUser, eax
phase_square_nFdAdO::   call phase_square_sF    ;// check for zero W
                        test eax, 7FFFFFFFh
                        jz output_nXnAdO
                                                ;// good to go
                        mov st_ptr, eax         ;// store the looked up value
                        mov esi, ebx            ;// use A pin as the X input
                        lea ebx, st_ptr         ;// use ebx as the static A
                        jmp output_dXsAdO_now   ;// jump to the now version
ALIGN 16
phase_square_sFsAnO::   mov eax, [esi]      ;// always xfer the value from the input
                        mov [ebp].pin_X.dwUser, eax

phase_square_nFsAnO::   call phase_square_sF        ;// no since testing the value
                        mov st_ptr, eax
                        fld [ebx]
                        fmul st_ptr
                        fstp st_ptr
                        mov eax, st_ptr
                        jmp store_static
ALIGN 16
phase_square_sFsAsO::   mov eax, [esi]  ;// always xfer the value from the input
                        mov [ebp].pin_X.dwUser, eax
phase_square_nFsAsO::   call phase_square_sF    ;// no since testing the value
                        mov st_ptr, eax
                        fld [ebx]
                        fmul st_ptr
                        fadd [edx]
                        fstp st_ptr
                        mov eax, st_ptr
                        jmp store_static
ALIGN 16
phase_square_sFnAsO::   mov eax, [esi]  ;// always xfer the value from the input
                        mov [ebp].pin_X.dwUser, eax
phase_square_nFnAsO::   call phase_square_sF    ;// no since testing the value
                        mov st_ptr, eax
                        fld [edx]
                        fadd st_ptr
                        fstp st_ptr
                        mov eax, st_ptr
                        jmp store_static
ALIGN 16
phase_square_sFnAnO::   mov eax, [esi]  ;// always xfer the value from the input
                        mov [ebp].pin_X.dwUser, eax
phase_square_nFnAnO::   call phase_square_sF    ;// good to go
                        jmp store_static
ALIGN 16
phase_square_sFnAdO::   mov eax, [esi]  ;// always xfer the value from the input
                        mov [ebp].pin_X.dwUser, eax
phase_square_nFnAdO::   call phase_square_sF    ;// good to go
                        mov st_ptr, eax     ;// store it here
                        mov esi, edx        ;// xfer O pin to esi
                        lea edx, st_ptr     ;// load the O pin with the stored value
                        jmp output_dXnAsO_now   ;// jump to the now version
ALIGN 16
phase_square_sFsAdO::   mov eax, [esi]  ;// always xfer the value from the input
                        mov [ebp].pin_X.dwUser, eax
phase_square_nFsAdO::   call phase_square_sF    ;// good to go
                        mov st_ptr, eax     ;// store it here
                        fld [ebx]
                        fmul st_ptr
                        fstp st_ptr
                        mov esi, edx        ;// xfer O pin to esi
                        lea edx, st_ptr     ;// load the O pin with the stored value
                        jmp output_dXnAsO_now   ;// jump to the now version
ALIGN 16
phase_square_zFsO:      mov eax, [edx]      ;// W = ZERO
                        jmp store_static
;//
;//
;//  phase_square_sF
;//  phase_square_dF
;//
;////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////
;//
;//
;//     phase_square_dF
;//

ALIGN 16
phase_square_dFnAnO::   call phase_square_dF    ;// good to go
                        jmp all_done
ALIGN 16
phase_square_dFsAnO::   test [ebx], 7FFFFFFFh   ;// check for zero gain
                        jz phase_dFzAnO
                        call phase_square_dF    ;// good to go
                        jmp output_dXsAnO
ALIGN 16
phase_square_dFdAnO::   call phase_square_dF    ;// good to go
                        jmp output_dXdAnO
ALIGN 16
phase_square_dFnAsO::   test [edx], 7FFFFFFFh   ;// check for zero offset
                        jz phase_square_dFnAnO
                        call phase_square_dF    ;// good to go
                        jmp output_dXnAsO
ALIGN 16
phase_square_dFsAsO::   test [edx], 7FFFFFFFh   ;// check for zero offset
                        jz phase_square_dFsAnO
                        test [ebx], 7FFFFFFFh   ;// check for zero gain
                        jz phase_dFzAsO
                        call phase_square_dF    ;// good to go
                        jmp output_dXsAsO
ALIGN 16
phase_square_dFdAsO::   test [edx], 7FFFFFFFh   ;// check for zero offset
                        jz phase_square_dFdAnO
                        call phase_square_dF    ;// good to go
                        jmp output_dXdAsO
ALIGN 16
phase_square_dFnAdO::   call phase_square_dF    ;// good to go
                        jmp output_dXnAdO
ALIGN 16
phase_square_dFsAdO::   test [ebx], 7FFFFFFFh   ;// check for zero gain
                        jz phase_dFzAdO
                        call phase_square_dF    ;// good to go
                        jmp output_dXsAdO
ALIGN 16
phase_square_dFdAdO::   call phase_square_dF    ;// good to go
                        jmp output_dXdAdO
;//
;//     phase_square_dF
;//
;//
;////////////////////////////////////////////////////////////////////







;////////////////////////////////////////////////////////////////////
;//
;//
;//     freq_zA routines        jump to when gain is zero
;//                             and frequency is not zero

;// dF

ALIGN 16
freq_dFzAnO:    call accumulate_Q_dF
                xor eax, eax
                jmp store_static
ALIGN 16
freq_dFzAsO:    call accumulate_Q_dF            ;// keep the Q running
                mov eax, [ebp].pin_O.pPin       ;// reload the O pin's connection
                mov eax, (APIN PTR [eax]).pData ;// get it's data pointer
                mov eax, (DWORD PTR [eax])      ;// get the value therin
                jmp store_static                ;// store static
ALIGN 16
freq_dFzAdO:    call accumulate_Q_dF
                jmp output_nXnAdO

;// sF

ALIGN 16
freq_sFzAnO:    call accumulate_Q_sF
                xor eax, eax            ;// clear
                jmp store_static        ;// store static
ALIGN 16
freq_sFzAsO:    call accumulate_Q_sF
                mov eax, [edx]          ;// load the value from the O pin
                jmp store_static        ;// store static
ALIGN 16
freq_sFzAdO:    call accumulate_Q_sF
                jmp output_nXnAdO
;//
;//     freq_zA routines        jump to when gain is zero
;//
;//
;////////////////////////////////////////////////////////////////////





;////////////////////////////////////////////////////////////////////
;//
;//
;//     phase_zA routines
;//

;// GAIN = ZERO

ALIGN 16
phase_dFzAnO:   mov edx, [esi+LAST_SAMPLE]  ;// get the last Q input
                mov [ebp].pin_X.dwUser, edx ;// store in object
                xor eax, eax                ;// output will be zero
                jmp store_static
ALIGN 16
phase_dFzAsO:   mov ecx, [esi+LAST_SAMPLE]  ;// get the last Q input
                mov [ebp].pin_X.dwUser, ecx ;// store in object
                mov eax, [edx]              ;// output will value in O pin
                jmp store_static
ALIGN 16
phase_dFzAdO:   mov ecx, [esi+LAST_SAMPLE]  ;// get the last Q input
                mov [ebp].pin_X.dwUser, ecx ;// store in object
                jmp output_nXnAdO








;////////////////////////////////////////////////////////////////////
;//
;//                                         use these when X has changing data
;//     dX O U T P U T   R O U T I N E S    call the _now versions for fooling the routine
;//                                         using different data registers


ALIGN 16
output_dXsAnO:  mov ebx, [ebp].pin_A.pPin
                mov esi, [ebp].pin_X.pData
                mov ebx, (APIN PTR [ebx]).pData
                mov edi, esi
  output_dXsAnO_now:
                DEBUG_IF <!!([ebx]&7FFFFFFFh)>  ;// check for zero before calling this
                call math_mul_dXsA
                or [ebp].pin_X.dwStatus, PIN_CHANGING
                jmp all_done
ALIGN 16
output_dXdAnO:  mov ebx, [ebp].pin_A.pPin
                mov esi, [ebp].pin_X.pData
                mov ebx, (APIN PTR [ebx]).pData
                mov edi, esi
  output_dXdAnO_now:
                call math_mul_dXdA
                or [ebp].pin_X.dwStatus, PIN_CHANGING
                jmp all_done
ALIGN 16
output_dXnAsO:  mov edx, [ebp].pin_O.pPin
                mov esi, [ebp].pin_X.pData
                mov edx, (APIN PTR [edx]).pData
                mov edi, esi
                test [edx],7FFFFFFFh
                jz all_done
  output_dXnAsO_now:
                call math_add_dXsB
                or [ebp].pin_X.dwStatus, PIN_CHANGING   ;// bug abox 228: line was in wrong spot
                jmp all_done
ALIGN 16
output_dXnAdO:  mov edx, [ebp].pin_O.pPin
                mov esi, [ebp].pin_X.pData
                mov edx, (APIN PTR [edx]).pData
                mov edi, esi
  output_dXnAdO_now:
                call math_add_dXdB
                or [ebp].pin_X.dwStatus, PIN_CHANGING
                jmp all_done
ALIGN 16
output_dXdAdO:  mov edx, [ebp].pin_O.pPin
                mov ebx, [ebp].pin_A.pPin
                mov esi, [ebp].pin_X.pData
                mov edx, (APIN PTR [edx]).pData
                mov ebx, (APIN PTR [ebx]).pData
                mov edi, esi
                call math_muladd_dXdAdB
                or [ebp].pin_X.dwStatus, PIN_CHANGING
                jmp all_done
ALIGN 16
output_dXsAsO:  mov edx, [ebp].pin_O.pPin
                mov ebx, [ebp].pin_A.pPin
                mov esi, [ebp].pin_X.pData
                mov edx, (APIN PTR [edx]).pData
                mov ebx, (APIN PTR [ebx]).pData
                mov edi, esi
                test [edx],7FFFFFFFh
                jz output_dXsAnO_now
  output_dXsAsO_now:
                DEBUG_IF <!!([ebx]&7FFFFFFFh)>  ;// check for zero before calling this
                call math_muladd_dXsAsB
                or [ebp].pin_X.dwStatus, PIN_CHANGING
                jmp all_done
ALIGN 16
output_dXdAsO:  mov edx, [ebp].pin_O.pPin
                mov ebx, [ebp].pin_A.pPin
                mov esi, [ebp].pin_X.pData
                mov edx, (APIN PTR [edx]).pData
                mov ebx, (APIN PTR [ebx]).pData
                mov edi, esi
                test [edx],7FFFFFFFh
                jz output_dXdAnO_now
                call math_muladd_dXdAsB
                or [ebp].pin_X.dwStatus, PIN_CHANGING
                jmp all_done
ALIGN 16
output_dXsAdO:  mov edx, [ebp].pin_O.pPin
                mov ebx, [ebp].pin_A.pPin
                mov esi, [ebp].pin_X.pData
                mov edx, (APIN PTR [edx]).pData
                mov ebx, (APIN PTR [ebx]).pData
                mov edi, esi
  output_dXsAdO_now:
                DEBUG_IF <!!([ebx]&7FFFFFFFh)>  ;// check for zero before calling this
                call math_muladd_dXsAdB
                or [ebp].pin_X.dwStatus, PIN_CHANGING
                jmp all_done
;//
;//
;//  dX O U T P U T   R O U T I N E S
;//
;////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////
;//
;//                                         use these when X is zero
;//     nX O U T P U T   R O U T I N E S
;//


ALIGN 16
output_nXnAsO:  mov edx, [ebp].pin_O.pPin
                mov edx, (APIN PTR [edx]).pData
                mov eax, [edx]
                jmp store_static
ALIGN 16
output_nXnAdO:  mov esi, [ebp].pin_O.pPin
                mov ecx, SAMARY_LENGTH
                mov esi, (APIN PTR [esi]).pData
                rep movsd
                or [ebp].pin_X.dwStatus, PIN_CHANGING
                jmp all_done
;//
;//
;//  sX O U T P U T   R O U T I N E S
;//
;////////////////////////////////////////////////////////////////////







;////////////////////////////////////////////////////////////////////
;//
;//
;//     store static        use when the output is static
;//                         eax MUST HAVE VALUE TO STORE

ALIGN 16
store_static:   cmp eax, [edi]              ;// looking for the zero flag
                mov edx, [ebp].pin_X.dwStatus;// load the status
                mov ecx, SAMARY_LENGTH      ;// load for counting
                btr edx, LOG2(PIN_CHANGING) ;// test and reset the changing bit (does not effect zero flag)
                jnz @F          ;// do the store if values are not equal
                jnc all_done    ;// jump to aldone if previous was NOT changing

                @@: mov [ebp].pin_X.dwStatus, edx
                    rep stosd
                    jmp all_done

;//
;//     store static        use when the output is static
;//                         eax MUST HAVE VALUE TO STORE
;//
;////////////////////////////////////////////////////////////////////








;// local functions


;////////////////////////////////////////////////////////////////////
;//
;//
;//     freq_lookup_dF
;//
ALIGN 16
freq_lookup_dF:

    ;// ebp must point at map
    ;// destroys all other registers

call_depth = 1

    mov ecx, st_ptr         ;// ecx points at the lookup table

    st_dL   TEXTEQU <(DWORD PTR [esp])>
    st_L    TEXTEQU <(DWORD PTR [esp+4])>

;// set up the initial L value

    fld math_2_24           ;// 2^24
    fld [ebp].pin_X.dwUser  ;// Q       2^24
    fmul st, st(1)          ;// L       2^24

    sub esp, 8      ;// make room on the stack

    fistp st_L              ;// 2^24

;// set up the iteration

    or [ebp].pin_X.dwStatus, PIN_CHANGING   ;// set changinng now

    mov ebx, st_L           ;// get the initial value
    mov ebp, SAMARY_LENGTH  ;// ebp counts

;// do the loop (4x does provide lower cycles, 2x is a good compromise)

@@:
    fld [esi]           ;//0 dQ     2^24
    fmul st, st(1)      ;//1 dL     2^24
    add esi, 4          ;//2 iterate esi
    fistp st_dL         ;//3 store as integer
    add ebx, st_dL      ;//4 add dL
    shld eax, ebx, 20   ;//5 get the integer part
    and eax, 8192-1     ;//6 mask the address
    dec ebp             ;//7 decrease the count
    mov eax, [ecx+eax*4];//8 get the value
    stosd               ;//9 store the value

    fld [esi]           ;//0 dQ     2^24
    fmul st, st(1)      ;//1 dL     2^24
    add esi, 4          ;//2 iterate esi
    fistp st_dL         ;//3 store as integer
    add ebx, st_dL      ;//4 add dL
    shld eax, ebx, 20   ;//5 get the integer part
    and eax, 8192-1     ;//6 mask the address
    dec ebp             ;//7 decrease the count
    mov eax, [ecx+eax*4];//8 get the value
    stosd               ;//9 store the value

    fld [esi]           ;//0 dQ     2^24
    fmul st, st(1)      ;//1 dL     2^24
    add esi, 4          ;//2 iterate esi
    fistp st_dL         ;//3 store as integer
    add ebx, st_dL      ;//4 add dL
    shld eax, ebx, 20   ;//5 get the integer part
    and eax, 8192-1     ;//6 mask the address
    dec ebp             ;//7 decrease the count
    mov eax, [ecx+eax*4];//8 get the value
    stosd               ;//9 store the value

    fld [esi]           ;//0 dQ     2^24
    fmul st, st(1)      ;//1 dL     2^24
    add esi, 4          ;//2 iterate esi
    fistp st_dL         ;//3 store as integer
    add ebx, st_dL      ;//4 add dL
    shld eax, ebx, 20   ;//5 get the integer part
    and eax, 8192-1     ;//6 mask the address
    dec ebp             ;//7 decrease the count
    mov eax, [ecx+eax*4];//8 get the value
    stosd               ;//9 store the value

    jnz @B              ;// loop until done

;// store the last value

    mov st_dL, ebx
    fild st_dL
    fmul math_2_neg_24
    add esp, 8          ;// clean up the stack
    call wrap_this      ;// wrap the final value
    mov ebp, st_osc     ;// retreieve the osc pointer
    fstp [ebp].pin_X.dwUser

    fstp st

    retn

    st_dL   TEXTEQU <>
    st_L    TEXTEQU <>



;//
;//
;//     freq_lookup_dF
;//
;////////////////////////////////////////////////////////////////////








;////////////////////////////////////////////////////////////////////
;//
;//
;//     freq_lookup_sF
;//
ALIGN 16
freq_lookup_sF:

    ;// ebp must point at map
    ;// destroys all other registers

call_depth = 1

    mov ecx, st_ptr         ;// load the table pointer, before we screw up the stack

    st_dL   TEXTEQU <(DWORD PTR [esp])>
    st_L    TEXTEQU <(DWORD PTR [esp+4])>

;// set up the integer fractions

    fld [ebp].pin_X.dwUser  ;// Q
    fld math_2_24           ;// 2^24    Q
    fmul                    ;// L

    sub esp, 8      ;// make room on the stack

    fld [esi]               ;// dQ      L
    fld math_2_24           ;// 2^24    dQ      L
    fmul                    ;// dL      L

    fxch                    ;// L       dL

    fistp st_L              ;// dL

    or [ebp].pin_X.dwStatus, PIN_CHANGING

    fistp st_dL             ;//

;// set up the iteration


    mov ebx, st_L           ;// get the initial value
    mov edx, st_dL          ;// get the adjuster

    mov ebp, SAMARY_LENGTH  ;// ebp counts

;// do the loop (4x does provide lower cycles, 2x is a good compromise)

@@: add ebx, edx            ;// add dL
    shld eax, ebx, 20       ;// get the integer part
    and eax, 8192-1         ;// mask the address
    dec ebp                 ;// decrease the count
    mov eax, [ecx+eax*4]    ;// get the value
    add ebx, edx            ;// add dL
    stosd                   ;// store the value

    shld eax, ebx, 20       ;// get the integer part
    and eax, 8192-1         ;// mask the address
    dec ebp                 ;// decrease the count
    mov eax, [ecx+eax*4]    ;// get the value
    add ebx, edx            ;// add dL
    stosd                   ;// store the value

    shld eax, ebx, 20       ;// get the integer part
    and eax, 8192-1         ;// mask the address
    dec ebp                 ;// decrease the count
    mov eax, [ecx+eax*4]    ;// get the value
    add ebx, edx            ;// add dL
    stosd                   ;// store the value

    shld eax, ebx, 20       ;// get the integer part
    and eax, 8192-1         ;// mask the address
    dec ebp                 ;// decrease the count
    mov eax, [ecx+eax*4]    ;// get the value
    stosd                   ;// store the value

    jnz @B                  ;// loop until done

;// store the last Q

    mov st_L, ebx           ;// store for loading
    fild st_L               ;// load from stored
    fmul math_2_neg_24      ;// scale back to a float
    add esp, 8              ;// clean up the stack
    call wrap_this          ;// wrap the value
    mov ebp, st_osc         ;// retrieve the osc pointer
    fstp [ebp].pin_X.dwUser ;// store the final Q

    retn

    st_dL   TEXTEQU <>
    st_L    TEXTEQU <>



;//
;//
;//     freq_lookup_sF
;//
;////////////////////////////////////////////////////////////////////





;////////////////////////////////////////////////////////////////////
;//
;//                         use for dX when gain is zero
;//     accumulate Q
;//

ALIGN 16
accumulate_Q_dF:

call_depth = 1

    ;// ebp must point at map
    ;// destroys all other registers

    ;// this uses the integer version of accumulateing, the osccilators stay in sync

    mov ecx, st_ptr         ;// ecx points at the lookup table

    st_dL   TEXTEQU <(DWORD PTR [esp])>
    st_L    TEXTEQU <(DWORD PTR [esp+4])>

;// set up the initial L value

    fld math_2_24           ;// 2^24
    fld [ebp].pin_X.dwUser  ;// Q       2^24

    sub esp, 8      ;// make room on the stack

    fmul st, st(1)          ;// L       2^24
    mov edx, 10h    ;// edx is the iterate adjust
    fistp st_L              ;// 2^24

;// set up the iteration

    mov ebp, SAMARY_LENGTH*4;// ebp counts

    mov ebx, st_L           ;// get the initial value, ebx acculmulates

    jmp @F

    .REPEAT

        add ebx, st_dL
        add ebx, st_L

    @@: ; enter loop

        ;// load and scale 4 values

        fld [esi]           ;// dQ0     2^24
        fmul st, st(1)      ;// dL0     2^24
        fld [esi+4]         ;// dQ1     dL0     2^24
        fmul st, st(2)      ;// dL1     dL0     2^24
        fld [esi+8]         ;// dQ2     dL1     dL0     2^24
        fmul st, st(3)      ;// dL2     dL1     dL0     2^24
        fld [esi+0Ch]       ;// dQ3     dL2     dL1     dL0     2^24
        fmul st, st(4)      ;// dL3     dL2     dL1     dL0     2^24

        ;// reduce and accumulate

        fxch st(3)          ;// dL0     dL2     dL1     dL3     2^24

        fistp st_dL         ;// dL2     dL1     dL3     2^24
        add esi, edx    ;// iterate esi
        fxch                ;// dL1     dL2     dL3     2^24
        fistp st_L          ;// dL2     dL3     2^24
        add ebx, st_dL  ;// add dl0

        add ebx, st_L   ;// add dL1
        fistp st_dL         ;// dL3     2^24
        sub ebp, edx
        fistp st_L          ;// 2^24

    .UNTIL ZERO?        ;// loop until done

    add ebx, st_dL  ;// don't forget the last two
    add ebx, st_L

;// store the last value

    mov st_dL, ebx
    fild st_dL
    fmul math_2_neg_24
    add esp, 8          ;// clean up the stack
    call wrap_this      ;// wrap the final value
    mov ebp, st_osc     ;// retreieve the osc pointer
    fstp [ebp].pin_X.dwUser

    fstp st

    retn

    st_dL   TEXTEQU <>
    st_L    TEXTEQU <>





ALIGN 16
accumulate_Q_sF:

    fld [esi]               ;// load the frequency
    fmul math_1024          ;// scale to next frame
    fadd [ebp].pin_X.dwUser ;// add the previous value
    call wrap_this          ;// make sure it wraps
    fstp [ebp].pin_X.dwUser ;// store back in object

    retn


;//
;//     accumulate Q
;//                         use for dX when gain is zero
;//
;////////////////////////////////////////////////////////////////////




;////////////////////////////////////////////////////////////////////
;//
;//                         this is a lot like phase_lookup_sF in a loop
;//     phase_lookup_dF
;//
ALIGN 16
phase_lookup_dF:

call_depth = 1

    ;// ebp must point at map
    ;// destroys all other registers

    ;// this uses the integer version of accumulating, so the osccilators stay in sync

    mov ecx, st_ptr         ;// ecx points at the lookup table

    st_L0   TEXTEQU <(DWORD PTR [esp])>
    st_L1   TEXTEQU <(DWORD PTR [esp+4])>

    mov ebx, esi        ;// ebx will iterate inputs

    sub esp, 8          ;// make some room

    or [ebp].pin_X.dwStatus, PIN_CHANGING

    fld math_TableScale ;// load the table scale

    mov ebp, SAMARY_LENGTH*4    ;// ebp counts

        fld [ebx]           ;// Q0  scale
        fmul st, st(1)      ;// L0  scale
        fld [ebx+4]         ;//
        fmul st, st(2)      ;//

    jmp @F

    .REPEAT

        add ebx, 10h

        lea esi, [ecx+eax*4];// store y2
        fld [ebx]           ;// Q0  scale
        movsd
        fmul st, st(1)      ;// L0  scale

        lea esi, [ecx+edx*4];// store y3
        fld [ebx+4]         ;// Q1  L0  scale
        movsd
        fmul st, st(2)      ;// L1  L0  scale
    @@:
        fld [ebx+8]         ;// Q2  L1  L0  scale
        fmul st, st(3)      ;// L2  L1  L0  scale
        fld [ebx+0Ch]       ;// Q3  L2  L1  L0  scale
        fmul st, st(4)      ;// L3  L2  L1  L0  scale

        fxch st(3)          ;// L0  L2  L1  L3  scale
        fistp st_L0         ;// L2  L1  L3  scale
        fxch                ;// L1  L2  L3  scale
        fistp st_L1         ;// L2  L3  scale

        mov eax, st_L0
        mov edx, st_L1

        and eax, 8192-1
        and edx, 8192-1

        fistp st_L0         ;// L3  scale
        fistp st_L1         ;// scale

        lea esi, [ecx+eax*4];// store y0
        movsd

        mov eax, st_L0

        lea esi, [ecx+edx*4];// store y1
        movsd

        mov edx, st_L1

        and eax, 8192-1
        and edx, 8192-1

        sub ebp, 10h

    .UNTIL ZERO?

    ;// don't forget the last two

        lea esi, [ecx+eax*4];// store y2
        movsd

        lea esi, [ecx+edx*4];// store y3
        movsd

    ;// store the last Q

        sub ebx, 4
        fld [ebx]
        add esp, 8          ;// clean up the stack
        call wrap_this
        mov ebp, st_osc     ;// retreieve the osc pointer
        fstp [ebp].pin_X.dwUser

        fstp st ;// clean out the fpu

        retn

        st_L0   TEXTEQU <>
        st_L1   TEXTEQU <>


;//
;//     phase_lookup_dF
;//                         this is a lot like phase_lookup_sF in a loop
;//
;////////////////////////////////////////////////////////////////////

;////////////////////////////////////////////////////////////////////
;//
;//
;//     phase_lookup_sF
;//

ALIGN 16
phase_lookup_sF:

    call_depth = 1

    ;// look up the value in dwUser
    ;// using the table specifed by st_ptr
    ;// return the value in eax

    ;// uses eax, ecx and st_ptr

    fld [ebp].pin_X.dwUser  ;// load Q
    fmul math_TableScale    ;// turn into an index
    mov ecx, st_ptr         ;// load the table pointer
    fistp st_ptr            ;// store index in table ptr

    mov eax, st_ptr         ;// load the table pointer
    and eax, 8192-1         ;// strip out extra
    mov eax, [ecx+eax*4]    ;// load the looked up value

    retn

;//
;//
;//     phase_lookup_sF
;//
;////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////
;//
;//
;//     freq_ramp_dF
;//

ALIGN 16
freq_ramp_dF:

comment ~ /*

the routine is rather confusing to read and is a rolled up version of what follows

@@:
1)  fld   Q0        |   the algorithm does this:
2)  fmul  fScale    |   1)  get the value of dQ from the F pin  (in FPU as Q0)
3)  fistp L0        |   2)  scale it to an integer              (Q0*fScale)
4)  add   eax, L0   |   3)  then store it in L0                 (=L0)
5)  shl   eax, 7    |   4)  accumulate L0 into a 32bit register (eax)
6)  sar   eax, 7    |   5)  scoot over 7 bits to get the implied sign bit
7)  mov   L0, eax   |       positioned in place of the 32bit sign
8)  fild  L0        |   6)  shift back, extending the sign in the process
9)  fmul  rScale    |   7)  store this back to L0
10) fstp  Y0        |   8)  reload the L0 value
11) add   esi, 4    |   9)  scale back to a float
11) add   edi, 4    |   10) store in X output for further processing
12) dec   ecx       |   11) iterate the pointers
13) jnz   @B        |   12) decrease the loop count
                    |   13) do until done

    the loop below then does the forward scale of the next sample
    and the reverse scale of the current sample at the same time
    so there is substantial pre and post loop code

*/ comment ~


;// perhaps a faster version ?      about 14 cycles, roll up save about 10 cycles

    fld math_2_neg_24   ;// rS
    fld math_2_24       ;// fS  rS

    sub esp, 4

    st_L TEXTEQU <(DWORD PTR [esp])>

    fld [ebp].pin_X.dwUser  ;// Q0  fS  rS

    fmul st, st(1)  ;// L0  fS  rS
    fld [esi]       ;// Q   L0  fS  rS
    fmul st,st(2)   ;// L   L0
    fxch            ;// L0  L   fS  rS
    add esi, 4
    fistp st_L      ;// L   fS  rS
    mov ecx, SAMARY_LENGTH-1
    mov eax, st_L
    fistp st_L
    sub edi, 4
    or [ebp].pin_X.dwStatus, PIN_CHANGING   ;// set changinng now

    jmp @F

.REPEAT                 ;// L   Y   fS  rS

    fistp st_L      ;3  ;// Y   fS  rS
    add esi, 4      ;11

    fstp [edi]      ;10 ;// fS  rS
@@:
    add eax, st_L   ;4
    shl eax, 7      ;5

    fld [esi]       ;1  ;// Q   fS  rS
    sar eax, 7      ;6
    add edi, 4      ;11

    mov st_L, eax   ;7
    fmul st, st(1)  ;2  ;// L   fS  rS

    fild st_L       ;8  ;// M   L   fS  rS
    dec ecx         ;12
    fmul st, st(3)  ;9  ;// Y   L   fS  rS

    fxch                ;// L   Y   fS  rS

.UNTIL ZERO?        ;13

    fistp st_L      ;// L   Y   fS  rS
    fstp [edi]
    add edi, 4
    add eax, st_L
    shl eax, 7
    sar eax, 7
    mov st_L, eax
    fild st_L
    fmulp st(2), st
    fstp st
    fst [edi]
    add esp, 4
    fstp [ebp].pin_X.dwUser

    retn

    st_L TEXTEQU <>

;//
;//     freq_ramp_dF
;//
;//
;////////////////////////////////////////////////////////////////////






;////////////////////////////////////////////////////////////////////
;//
;//
;//     freq_ramp_sF
;//

ALIGN 16
freq_ramp_sF:

call_depth = 1

    ;// setup

        fld math_2_neg_24
        fld math_2_24
        sub esp, 4h
        st_dL0 TEXTEQU <(DWORD PTR [esp])>

        mov ecx, SAMARY_LENGTH

        fld [esi]               ;// dQ  scale   rev_scale
        fmul st, st(1)          ;// dL  scale   rev_scale
        fld [ebp].pin_X.dwUser  ;// Q   dL      scale   rev_scale
        fmulp st(2), st         ;// dL  L       rev_scale
        fistp st_dL0            ;// L   rev_scale
    or [ebp].pin_X.dwStatus, PIN_CHANGING   ;// set changinng now
        mov edx, st_dL0 ;// edx is the adjuster
        fistp st_dL0            ;// rev_scale
        mov eax, st_dL0 ;// eax is Q

        add eax, edx    ;// do the first one
        shl eax, 7
        sar eax, 7

        jmp @F

    .REPEAT ;// just not going to get under 8 cycles

        add eax, edx
        shl eax, 7
        fstp [edi]
        sar eax, 7
        add edi, 4
    @@:
        mov st_dL0, eax
        dec ecx
        fild st_dL0
        fmul st, st(1)

    .UNTIL ZERO?

    ;// store the last values

    fst [ebp].pin_X.dwUser
    add esp, 4
    fstp [edi]
    fstp st

    retn

    st_dL0 TEXTEQU <(DWORD PTR [esp])>

;//
;//     freq_ramp_sF
;//
;//
;////////////////////////////////////////////////////////////////////






;////////////////////////////////////////////////////////////////////
;//
;//
;//     phase_ramp_dF
;//

ALIGN 16
phase_ramp_dF:

    ;// same as freq_ramp_dF
    ;// but instead of "ADD eax, L0" , we "MOV eax, L0"
    ;// we also skip loading the initail Q value
    ;// see above for comments

    fld math_2_neg_24   ;// rS
    fld math_2_24       ;// fS  rS

    sub esp, 4

    st_L TEXTEQU <(DWORD PTR [esp])>

    fld [esi]       ;// Q   fS  rS
    fmul st,st(1)   ;// L
    add esi, 4
    sub edi, 4
    mov ecx, SAMARY_LENGTH-1
    fistp st_L      ;// fS  rS
    or [ebp].pin_X.dwStatus, PIN_CHANGING   ;// set changinng now

    jmp @F

.REPEAT                 ;// L   Y   fS  rS

    fistp st_L      ;3  ;// Y   fS  rS
    add esi, 4      ;11

    fstp [edi]      ;10 ;// fS  rS
@@:
    mov eax, st_L   ;4
    shl eax, 7      ;5

    fld [esi]       ;1  ;// Q   fS  rS
    sar eax, 7      ;6
    add edi, 4      ;11

    mov st_L, eax   ;7
    fmul st, st(1)  ;2  ;// L   fS  rS

    fild st_L       ;8  ;// M   L   fS  rS
    dec ecx         ;12
    fmul st, st(3)  ;9  ;// Y   L   fS  rS

    fxch                ;// L   Y   fS  rS

.UNTIL ZERO?        ;13

    fistp st_L      ;// L   Y   fS  rS
    fstp [edi]
    add edi, 4
    mov eax, st_L
    shl eax, 7
    sar eax, 7
    mov st_L, eax
    fild st_L
    fmulp st(2), st
    fstp st
    fst [edi]
    add esp, 4
    fstp [ebp].pin_X.dwUser

    retn

    st_L TEXTEQU <>

;//
;//     phase_ramp_dF
;//
;//
;////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////
;//
;//
;//     phase_ramp_sF
;//
ALIGN 16
phase_ramp_sF:

;// like phase_lookup_sF this returns the value in eax
;// destroys eax and st_ptr
;// this also stores the wrapped Q value in [ebp].dwUser

call_depth = 1

    fld [ebp].pin_X.dwUser  ;// load teh Q value
    fmul math_2_24          ;// scale to an int
    fistp st_ptr            ;// store in st_ptr
    mov eax, st_ptr         ;// get the integer
    shl eax, 7              ;// scoot implied sign into real sign
    sar eax, 7              ;// extend it back into place
    mov st_ptr, eax         ;// store back in st_ptr
    fild st_ptr             ;// load st_ptr
    fmul math_2_neg_24      ;// scale back to integer
    fstp [ebp].pin_X.dwUser ;// store as float in dwUser
    mov eax, [ebp].pin_X.dwUser;// load eax

    retn

;//
;//     phase_ramp_sF
;//
;//
;////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////
;//
;//
;//     freq_square_dF
;//

ALIGN 16
freq_square_dF:

call_depth = 1

;// for this routine, we build +- in the int registers
;// then store directly
;// this will save a rescale operation

    st_L TEXTEQU <(DWORD PTR [esp])>

    fld math_2_24       ;// fScale
    mov ebx, 7F000000h  ;// pos 1 * 2
    fld [ebp].pin_X.dwUser
    fmul st, st(1)
    sub esp, 4
    mov ecx, SAMARY_LENGTH
    or [ebp].pin_X.dwStatus, PIN_CHANGING
    fistp st_L
    mov edx, st_L   ;// edx accumulates

    .REPEAT

        fld [esi]           ;// Q0  fScale
        fmul st, st(1)      ;// L0  fScale

        fld [esi+4]         ;// Q1  L0  fScale
        fmul st, st(2)      ;// L1  L0  fScale

        fld [esi+8]         ;// Q2  L1  L0  fScale
        fmul st, st(3)      ;// L2  L1  L0  fScale

        fld [esi+0Ch]       ;// Q3  L2  L1  L0  fScale
        fmul st, st(4)      ;// L3  L2  L1  L0  fScale

        fxch st(3)          ;// L0  L2  L1  L3  fScale
        fistp st_L          ;// L2  L1  L3  fScale
        add esi, 10h

        add edx, st_L   ;l0 ;// accumulate dL
        mov eax, ebx    ;// pos one * 2
        bt edx, 24      ;l0 ;// test the implied sign bit

        fxch                ;// L1  L2  L3  fScale
        fistp st_L      ;L1 ;// L2  L3  fScale

        rcr eax, 1      ;l0 ;// shift in the sign bit and divide by two
        add edx, st_L   ;l1 ;// accumulate dL
        stosd           ;l0 ;// store the results

        bt edx, 24      ;l1 ;// test the implied sign bit
        fistp st_L      ;L2 ;// L3  fScale
        mov eax, ebx    ;// pos one * 2

        rcr eax, 1      ;l1 ;// shift in the sign bit and divide by two
        add edx, st_L   ;l2 ;// accumulate dL

        stosd           ;l1 ;// store the results

        bt edx, 24      ;l2 ;// test the implied sign bit
        fistp st_L      ;L3 ;// fScale
        mov eax, ebx    ;// pos one * 2

        rcr eax, 1      ;l2 ;// shift in the sign bit and divide by two
        add edx, st_L   ;l3 ;// accumulate dL

        stosd           ;l2 ;// store the results

        bt edx, 24      ;l3 ;// test the implied sign bit
        mov eax, ebx    ;// pos one * 2
        rcr eax, 1      ;l3 ;// shift in the sign bit and divide by two

        sub ecx, 4

        stosd           ;l3 ;// store the results

    .UNTIL ZERO?

    ;// get the final Q

        shl edx, 7
        sar edx, 7
        mov st_L, edx
        fild st_L
        fmul math_2_neg_24
        add esp, 4
        fstp [ebp].pin_X.dwUser
        fstp st

        retn

    st_L TEXTEQU <>

;//
;//     freq_square_dF
;//
;//
;////////////////////////////////////////////////////////////////////




;////////////////////////////////////////////////////////////////////
;//
;//
;//     freq_square_sF
;//

ALIGN 16
freq_square_sF:

call_depth = 1

;// for this routine, we build +- in the int registers
;// then store directly
;// this will save a rescale operation

    fld math_2_24       ;// fScale
    mov ebx, 7F000000h  ;// pos 1 * 2
    fld [ebp].pin_X.dwUser
    fmul st, st(1)
    mov ecx, SAMARY_LENGTH
    or [ebp].pin_X.dwStatus, PIN_CHANGING
    fistp st_ptr
    mov edx, st_ptr ;// edx accumulates

    fld [esi]       ;// get the static dQ
    fmul            ;// scale to integer
    fistp st_ptr    ;// store where we can get to it

    mov esi, st_ptr ;// esi holds the delta

    .REPEAT

        add edx, esi    ;// accumulate dL
        mov eax, ebx    ;// pos one * 2
        bt edx, 24      ;// test the implied sign bit

        rcr eax, 1      ;// shift in the sign bit and divide by two
        dec ecx
        stosd           ;// store the results

        add edx, esi    ;// accumulate dL
        mov eax, ebx    ;// pos one * 2
        bt edx, 24      ;// test the implied sign bit

        rcr eax, 1      ;// shift in the sign bit and divide by two
        dec ecx
        stosd           ;// store the results

    .UNTIL ZERO?

    ;// get the final Q

        shl edx, 7
        sar edx, 7
        mov st_ptr, edx
        fild st_ptr
        fmul math_2_neg_24
        fstp [ebp].pin_X.dwUser

        retn


;//
;//     freq_square_sF
;//
;//
;////////////////////////////////////////////////////////////////////




;////////////////////////////////////////////////////////////////////
;//
;//                         returns value in eax
;//     freq_square_nF      destroys st_ptr
;//

ALIGN 16
freq_square_nF:

call_depth = 1

    fld math_2_24       ;// fScale
    fld [ebp].pin_X.dwUser
    fmul
    mov eax, 7F000000h
    fistp st_ptr
    bt st_ptr, 24       ;// test the implied sign bit
    rcr eax, 1          ;// shift in the sign bit and divide by two

    retn

;//
;//     freq_square_nF
;//
;//
;////////////////////////////////////////////////////////////////////





;////////////////////////////////////////////////////////////////////
;//
;//
;//     phase_square_dF
;//

ALIGN 16
phase_square_dF:

call_depth = 1

    ;// same as freq_square_dF but we MOV instead of ADD

    st_L TEXTEQU <(DWORD PTR [esp])>

    fld math_2_24       ;// fScale
    mov ebx, 7F000000h  ;// pos 1 * 2

    sub esp, 4
    mov ecx, SAMARY_LENGTH
;// or [ebp].pin_X.dwUser, PIN_CHANGING     ;// abox227 OOPS!! should be dwStatus
    or [ebp].pin_X.dwStatus, PIN_CHANGING   ;// abox227 OOPS!! should be dwStatus


    .REPEAT

        fld [esi]           ;// Q0  fScale
        fmul st, st(1)      ;// L0  fScale

        fld [esi+4]         ;// Q1  L0  fScale
        fmul st, st(2)      ;// L1  L0  fScale

        fld [esi+8]         ;// Q2  L1  L0  fScale
        fmul st, st(3)      ;// L2  L1  L0  fScale

        fld [esi+0Ch]       ;// Q3  L2  L1  L0  fScale
        fmul st, st(4)      ;// L3  L2  L1  L0  fScale

        fxch st(3)          ;// L0  L2  L1  L3  fScale
        fistp st_L          ;// L2  L1  L3  fScale
        add esi, 10h

        mov edx, st_L   ;l0 ;// accumulate dL
        mov eax, ebx    ;// pos one * 2
        bt edx, 24      ;l0 ;// test the implied sign bit

        fxch                ;// L1  L2  L3  fScale
        fistp st_L      ;L1 ;// L2  L3  fScale

        rcr eax, 1      ;l0 ;// shift in the sign bit and divide by two
        mov edx, st_L   ;l1 ;// accumulate dL
        stosd           ;l0 ;// store the results

        bt edx, 24      ;l1 ;// test the implied sign bit
        fistp st_L      ;L2 ;// L3  fScale
        mov eax, ebx    ;// pos one * 2

        rcr eax, 1      ;l1 ;// shift in the sign bit and divide by two
        mov edx, st_L   ;l2 ;// accumulate dL

        stosd           ;l1 ;// store the results

        bt edx, 24      ;l2 ;// test the implied sign bit
        fistp st_L      ;L3 ;// fScale
        mov eax, ebx    ;// pos one * 2

        rcr eax, 1      ;l2 ;// shift in the sign bit and divide by two
        mov edx, st_L   ;l3 ;// accumulate dL

        stosd           ;l2 ;// store the results

        bt edx, 24      ;l3 ;// test the implied sign bit
        mov eax, ebx    ;// pos one * 2
        rcr eax, 1      ;l3 ;// shift in the sign bit and divide by two

        sub ecx, 4

        stosd           ;l3 ;// store the results

    .UNTIL ZERO?

    ;// get the final Q

        shl edx, 7
        sar edx, 7
        mov st_L, edx
        fild st_L
        fmul math_2_neg_24
        add esp, 4
        fstp [ebp].pin_X.dwUser
        fstp st

        retn

    st_L TEXTEQU <>

;//
;//     phase_square_dF
;//
;//
;////////////////////////////////////////////////////////////////////




;////////////////////////////////////////////////////////////////////
;//
;//
;//     phase_square_sF
;//

ALIGN 16
phase_square_sF:

call_depth = 1

    ;// do the square calc for the value in dwUser
    ;// return the results in eax
    ;// destroys st_ptr

        fld [ebp].pin_X.dwUser
        fmul math_2_24
        mov eax, 7F000000h
        fistp st_ptr
        bt st_ptr, 24
        rcr eax, 1

        retn


;//
;//     phase_square_sF
;//
;//
;////////////////////////////////////////////////////////////////////









;////////////////////////////////////////////////////////////////////
;//
;//
;//     E X I T
;//

ALIGN 16
all_done:

    call_depth = 0

    add esp, stack_size ;// clean up
    ret

    st_ptr TEXTEQU <>
    st_osc TEXTEQU <>

;//
;//
;//     E X I T
;//
;////////////////////////////////////////////////////////////////////








osc_Oscillator_Calc_2 ENDP















;////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////




ASSUME_AND_ALIGN
osc_osc_SetInputLetter PROC USES ebx

        ASSUME esi:PTR OSC_OBJECT
        ASSUME ebp:PTR LIST_CONTEXT

    ;// make sure the font table is setup

        .IF !osc_osc_pPhase

            push edi

            ;// time to find these
            mov eax, 'F'
            lea edi, font_pin_slist_head
            invoke font_Locate
            mov osc_osc_pFreq, edi

            mov eax, 'P'
            lea edi, font_pin_slist_head
            invoke font_Locate
            mov osc_osc_pPhase, edi

            pop edi

        .ENDIF

    ;// set the pin to the correct letter and signal type

        OSC_TO_PIN_INDEX esi, ebx, 0
        .IF !([esi].dwUser & OSC_OSC_PHASE)
            pushd UNIT_HERTZ        ;// unit
            push OFFSET sz_Frequency;// long name
            push osc_osc_pFreq      ;// short name
        .ELSE
            pushd UNIT_DEGREES      ;// unit
            push OFFSET sz_Phase    ;// long name
            push osc_osc_pPhase     ;// short name
        .ENDIF

        call pin_SetNameAndUnit

    ;// that should do it

        ret

osc_osc_SetInputLetter ENDP





;////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
osc_Oscillator_InitMenu PROC


    ASSUME esi:PTR OSC_OBJECT

    ;// set the corect shape

        mov ecx, [esi].dwUser
        and ecx, OSC_OSC_TEST

        .IF     ecx == OSC_OSC_TRI
            mov ecx, ID_O_TRIANGLE
        .ELSEIF ecx == OSC_OSC_RAMP
            mov ecx, ID_O_RAMP
        .ELSEIF ecx == OSC_OSC_SQUARE
            mov ecx, ID_O_SQUARE
        .ELSEIF ecx == OSC_OSC_RAMP1
            mov ecx, ID_O_RAMP1
        .ELSEIF ecx == OSC_OSC_SQUARE1
            mov ecx, ID_O_SQUARE1
        .ELSEIF ecx == OSC_OSC_RAMP2
            mov ecx, ID_O_RAMP2
        .ELSEIF ecx == OSC_OSC_SQUARE2
            mov ecx, ID_O_SQUARE2
        .ELSE;//ecx == OSC_OSC_SINE
            mov ecx, ID_O_SINEWAVE
        .ENDIF

        invoke CheckDlgButton, popup_hWnd, ecx, BST_CHECKED

    ;// set frequency or phase

        mov ecx, ID_O_FREQ
        .IF [esi].dwUser & OSC_OSC_PHASE
            mov ecx, ID_O_PHASE
        .ENDIF

        invoke CheckDlgButton, popup_hWnd, ecx, BST_CHECKED

    ;// set the reset button

        mov eax, [esi].dwUser
        .IF !(eax & OSC_RESET_TEST)
            ;// unpress both
            pushd BST_UNCHECKED ;// zero
            pushd BST_UNCHECKED ;// one
        .ELSEIF eax & OSC_RESET_ONE
            pushd BST_UNCHECKED ;// zero
            pushd BST_CHECKED   ;// one
        .ELSE
            pushd BST_CHECKED   ;// zero
            pushd BST_UNCHECKED ;// one
        .ENDIF

        pushd ID_O_RESET_ONE
        push  popup_hWnd
        call  CheckDlgButton

        pushd ID_O_RESET_ZERO
        push  popup_hWnd
        call  CheckDlgButton

    ;// that's it

    xor eax, eax    ;// return zero or popup thinks we want a new dialog size

    ret

osc_Oscillator_InitMenu ENDP





ASSUME_AND_ALIGN
osc_Oscillator_Command PROC

    ASSUME esi:PTR OSC_OBJECT
    ;// eax has the command to process

    xor edx, edx    ;// edx will be the new flag (if any)

    CMPJMP eax, ID_O_SINEWAVE,  jz set_new_osc

    CMPJMP eax, ID_O_TRIANGLE,  jnz @F
    MOVJMP edx, OSC_OSC_TRI,    jmp set_new_osc

@@: CMPJMP eax, ID_O_RAMP,      jnz @F
    MOVJMP edx, OSC_OSC_RAMP,   jmp set_new_osc

@@: CMPJMP eax, ID_O_SQUARE,    jnz @F
    MOVJMP edx, OSC_OSC_SQUARE, jmp set_new_osc

@@: CMPJMP eax, ID_O_RAMP1,     jnz @F
    MOVJMP edx, OSC_OSC_RAMP1,  jmp set_new_osc

@@: CMPJMP eax, ID_O_SQUARE1,   jnz @F
    MOVJMP edx, OSC_OSC_SQUARE1,jmp set_new_osc

@@: CMPJMP eax, ID_O_RAMP2,     jnz @F
    MOVJMP edx, OSC_OSC_RAMP2,  jmp set_new_osc

@@: CMPJMP eax, ID_O_SQUARE2,   jnz @F
    mov edx, OSC_OSC_SQUARE2

set_new_osc:

    and [esi].dwUser, OSC_OSC_MASK
    mov ecx, oscillator_source_list[edx*4]
    or [esi].dwUser, edx
    mov [esi].pSource, ecx
    jmp all_done

@@: CMPJMP eax, ID_O_FREQ,      jnz @F

    BITR [esi].dwUser, OSC_OSC_PHASE
    jnc all_done                ;// exit if already frequency
    jmp set_new_input_letter

@@: CMPJMP eax, ID_O_PHASE,     jnz @F
    BITS [esi].dwUser, OSC_OSC_PHASE
    jc all_done                 ;// exit if already phase

set_new_input_letter:

    invoke osc_osc_SetInputLetter

all_done:

    mov eax, POPUP_SET_DIRTY + POPUP_REDRAW_OBJECT

return_now:

    ret


@@: CMPJMP eax, ID_O_RESET_ONE,     jne @F
    MOVJMP edx, OSC_RESET_ONE,      jmp set_new_reset

@@: CMPJMP eax, ID_O_RESET_ZERO,    jne osc_Command
    mov edx, OSC_RESET_ZERO

set_new_reset:

    ;// if already on, then turn off
    .IF edx & [esi].dwUser
        xor edx, edx
    .ENDIF
    ;// merge in to current settings
    and [esi].dwUser, NOT OSC_RESET_TEST
    or [esi].dwUser, edx
    ;// and force reinit of menu
    mov eax, POPUP_SET_DIRTY OR POPUP_REDRAW_OBJECT OR POPUP_INITMENU
    jmp return_now

osc_Oscillator_Command ENDP



;////////////////////////////////////////////////////////////////////
;//
;//
;//     _LoadUndo
;//

ASSUME_AND_ALIGN
osc_Oscillator_LoadUndo PROC

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
        jmp osc_Oscillator_SetDisplay

osc_Oscillator_LoadUndo ENDP

;//
;//
;//     _LoadUndo
;//
;////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
osc_Oscillator_SetDisplay PROC

        ASSUME esi:PTR OSC_OBJECT

    ;// select the osc graphic correct one

        mov eax, [esi].dwUser
        and eax, OSC_OSC_TEST
        mov eax, oscillator_source_list[eax*4]
        mov [esi].pSource, eax

    ;// then set the pin letter
    ;// and we're outta here

        jmp osc_osc_SetInputLetter

osc_Oscillator_SetDisplay ENDP

ASSUME_AND_ALIGN
osc_Oscillator_SetShape PROC

    ;// register call
    ;//
    ASSUME esi:PTR OSC_OBJECT

    invoke osc_Oscillator_SetDisplay

    jmp osc_SetShape    ;// ret

osc_Oscillator_SetShape ENDP


;////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////

;// note: we MAY call this at the ctor as well

ASSUME_AND_ALIGN
osc_Oscillator_PrePlay PROC

    ;// here , we want to reset our Q, we'll force a wrap, for frequencies of one
    ;// ABOX232: cleaned this up alot
    ;// 1) user settable start of -1 or 0

        ASSUME esi:PTR OSC_OBJECT

        .IF [esi].dwUser & OSC_RESET_ZERO
            fldz
        .ELSE   ;// default
            fld1
        .ENDIF
        OSC_TO_PIN_INDEX esi, ecx, 3
        fstp [ecx].dwUser

        xor eax, eax    ;// so play start will erase our data

        ret

osc_Oscillator_PrePlay ENDP


;////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
osc_Oscillator_Ctor PROC

        ;// register call
        ASSUME ebp:PTR LIST_CONTEXT ;// preserve
        ASSUME esi:PTR OSC_OBJECT   ;// preserve
        ASSUME edi:PTR OSC_BASE     ;// may_destroy
        ASSUME ebx:PTR FILE_OSC     ;// may destroy
        ASSUME edx:PTR FILE_HEADER  ;// may destroy

    ;// if we're not loading from a file set the reset bit

        .IF !edx        ;// starting from scratch ?
            or [esi].dwUser, OSC_RESET_ONE
        .ENDIF

    ;// if the rest bit is set, make sure we call preplay

        .IF [esi].dwUser & OSC_RESET_TEST
            invoke osc_Oscillator_PrePlay
        .ENDIF

    ;// that's it

        ret

osc_Oscillator_Ctor ENDP







;////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
osc_Oscillator_GetUnit  PROC

        ASSUME esi:PTR OSC_MAP
        ASSUME ebx:PTR APIN

    ;// xfer out to in
    ;// or fail

        lea ecx, [esi].pin_X
        ASSUME ecx:PTR APIN
        cmp ecx, ebx
        je all_done     ;// carry is off

        mov eax, [ecx].dwStatus
        BITT eax, UNIT_AUTOED

    all_done:

        ret


osc_Oscillator_GetUnit ENDP

;////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////
















ASSUME_AND_ALIGN

ENDIF   ;// USE_THIS_FILE
END




