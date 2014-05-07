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
;// ABox_FFT.asm                this is the osc wrapper for the FFT
;//                             see fft_abox for calc implementation
OPTION CASEMAP:NONE

.586
.MODEL FLAT

USE_THIS_FILE equ 1

IFDEF USE_THIS_FILE

        .NOLIST
        include <Abox.inc>
        include <fft_abox.inc>
        .LIST

.DATA


osc_FFT OSC_CORE {,,fft_PrePlay,fft_Calc }
          OSC_GUI  {,fft_SetShape,,,,fft_Command,fft_InitMenu,,,osc_SaveUndo,fft_LoadUndo,fft_GetUnit}
          OSC_HARD {  }

    OSC_DATA_LAYOUT {NEXT_FFT,IDB_FFT,OFFSET popup_FFT,,
        4,4,SIZEOF OSC_OBJECT + SIZEOF APIN * 4,
        SIZEOF OSC_OBJECT + SIZEOF APIN * 4 + SAMARY_SIZE*2,
        SIZEOF OSC_OBJECT + SIZEOF APIN * 4 + SAMARY_SIZE*2 }

    OSC_DISPLAY_LAYOUT {prism_container, FFT_FORWARD_PSOURCE, ICON_LAYOUT(10,2,2,5)}

    APIN_init{ -0.9,,'x',,UNIT_AUTO_UNIT }  ;// input pin
    APIN_init{  0.9,,'y',,UNIT_AUTO_UNIT }  ;// input pin
    APIN_init{ -0.1,,'X',,PIN_OUTPUT OR UNIT_SPECTRUM } ;// output pin
    APIN_init{  0.1,,'Y',,PIN_OUTPUT OR UNIT_SPECTRUM } ;// output pin

    short_name  db  'FFT',0
    description db  'Transforms time-domain signals into frequency spectrums and vice versa.',0
    ALIGN 4

    ;// values for dwuser

    OSC_FFT_FORWARD equ 00000000h
    OSC_FFT_REVERSE equ 00000001h

    OSC_FFT_WINDOW  equ 00000002h   ;// on or off


    ;// OSCMAP  new in ABOX232

    FFT_OSCMAP STRUCT

        OSC_OBJECT  {}
        pin_x   APIN    {}  ;// x input
        pin_y   APIN    {}  ;// y input
        pin_X   APIN    {}  ;// X output
        pin_Y   APIN    {}  ;// Y output
        data_X  dd SAMARY_LENGTH DUP (0)    ;// X output data
        data_Y  dd SAMARY_LENGTH DUP (0)    ;// Y output data

    FFT_OSCMAP ENDS









.CODE

ASSUME_AND_ALIGN
fft_SyncPins    PROC

    ASSUME ebp:PTR LIST_CONTEXT
    ASSUME esi:PTR OSC_OBJECT
    ;// destroys ebx

    .IF [esi].dwUser & OSC_FFT_REVERSE

        pushd UNIT_SPECTRUM
        pushd UNIT_SPECTRUM
        pushd UNIT_AUTO_UNIT
        pushd UNIT_AUTO_UNIT

    .ELSE
        pushd UNIT_AUTO_UNIT
        pushd UNIT_AUTO_UNIT
        pushd UNIT_SPECTRUM
        pushd UNIT_SPECTRUM
    .ENDIF

    ITERATE_PINS
        pop eax
        invoke pin_SetUnit
    PINS_ITERATE

    ret

fft_SyncPins    ENDP

ASSUME_AND_ALIGN
fft_GetUnit PROC

    clc ;// we never know !!
    ret

fft_GetUnit ENDP


ASSUME_AND_ALIGN
fft_PrePlay PROC

    xor eax, eax    ;// nothing to do
    ret

fft_PrePlay ENDP


ASSUME_AND_ALIGN
fft_Calc PROC

        ASSUME esi:PTR FFT_OSCMAP

    ;// for now, assume we always calc
    ;// ABOX232: now we check the inputs and skip if both are zero

        GET_PIN_FROM eax, [esi].pin_x.pPin  ;// eax = pin x
        GET_PIN_FROM edx, [esi].pin_y.pPin  ;// edx = pin y

        TESTJMP eax, eax, jnz F0    ;// reassign eax if not connected
        mov eax, math_pNullPin
    F0: TESTJMP edx, edx, jnz F1    ;// reassign edx if not connected
        mov edx, math_pNullPin
    F1: mov ecx, [eax].pData        ;// ecx = x input data
        mov ebx, [edx].pData        ;// ebx = y input data
        ;// check if either pin is changing
        CMPJMP ecx, ebx,  jne F2            ;// if different then at least one is valid
        CMPJMP ecx, math_pNull, je no_calc  ;// if both are null, then we don't calc

    F2: TESTJMP [eax].dwStatus, PIN_CHANGING, jnz yes_calc  ;// have to calc if pin is changing
        TESTJMP [edx].dwStatus, PIN_CHANGING, jnz yes_calc  ;// have to calc if pin is changing
        ;// neither pin is changing
        or eax, -1
        TESTJMP eax, DWORD PTR [ecx], jnz yes_calc  ;// if not zero then have to calc
        TESTJMP eax, DWORD PTR [ebx], jz no_calc    ;// if this is zero also, then we do not calc


    yes_calc:   ;// we do have to run the FFT
                ;// ecx = x_input data
                ;// ebx = y_input data

push esi    ;// have to save !!
    ;// push our two output pointers

        push [esi].pin_Y.pData
        push [esi].pin_X.pData

    ;// build our flags

        mov eax, [esi].dwUser
        mov edx, FFT_1024
        .IF eax & OSC_FFT_REVERSE
            or edx, FFT_REVERSE
        .ELSE
            or edx, FFT_FORWARD
        .ENDIF

        .IF eax & OSC_FFT_WINDOW
            or edx, FFT_WINDOW
        .ENDIF

        push edx

    ;// set up the input pointers

        push ebx    ;// y input data
        push ecx    ;// x input data

    ;// call the fft function

        invoke fft_Run
pop esi ;// have to save !!
    ;// then check the results

        lea edi, [esi].data_X
        or [esi].pin_X.dwStatus, PIN_CHANGING
        mov eax, [edi]
        mov ecx, SAMARY_LENGTH
        repe scasd
        jne G1
        and [esi].pin_X.dwStatus, NOT PIN_CHANGING
    G1: lea edi, [edi+ecx*4]
        or [esi].pin_Y.dwStatus, PIN_CHANGING
        mov eax, [edi]
        mov ecx, SAMARY_LENGTH-1
        repe scasd
        jne G2
        and [esi].pin_Y.dwStatus, NOT PIN_CHANGING
    G2:

    ;// that' it
    all_done:

        ret


    ALIGN 16
    no_calc:

    ;// we have determined that we do not need to calc
    ;// and we know for sure that we must have zero output values
    ;// so we check the status of previous frames
    ;// and zero if nessesary

        xor eax, eax
        TESTJMP [esi].pin_X.dwStatus, PIN_CHANGING, jnz have_to_fill
        TESTJMP [esi].pin_Y.dwStatus, PIN_CHANGING, jnz have_to_fill
        ;// neither output is changing, check if both are zero
        ORJMP eax, [esi].data_X, jnz have_to_fill
        ORJMP eax, [esi].data_Y, jz all_done

    have_to_fill:

        ;// turn the flags off

        and [esi].pin_X.dwStatus, NOT PIN_CHANGING
        and [esi].pin_Y.dwStatus, NOT PIN_CHANGING

        ;// fill the frames with zero

        lea edi, [esi].data_X
        mov ecx, SAMARY_LENGTH * 2
        xor eax, eax
        rep stosd

        ;// and that's it

        jmp all_done

fft_Calc ENDP




ASSUME_AND_ALIGN
fft_SetShape PROC

    ASSUME esi:PTR OSC_OBJECT

    .IF [esi].dwUser & OSC_FFT_REVERSE
        mov [esi].pSource, FFT_REVERSE_PSOURCE
    .ELSE
        mov [esi].pSource, FFT_FORWARD_PSOURCE
    .ENDIF

    invoke fft_SyncPins

    jmp osc_SetShape

fft_SetShape ENDP




ASSUME_AND_ALIGN
fft_InitMenu PROC

    ASSUME esi:PTR OSC_OBJECT

    .IF [esi].dwUser & OSC_FFT_REVERSE
        mov ecx, IDC_FFT_REVERSE
    .ELSE
        mov ecx, IDC_FFT_FORWARD
    .ENDIF

    invoke CheckDlgButton, popup_hWnd, ecx, BST_CHECKED

    .IF [esi].dwUser & OSC_FFT_WINDOW
        invoke CheckDlgButton, popup_hWnd, IDC_FFT_WINDOW, BST_CHECKED
    .ENDIF

    xor eax, eax    ;// always return zero or popup will resize

    ret

fft_InitMenu ENDP

ASSUME_AND_ALIGN
fft_Command PROC

    ASSUME esi:PTR OSC_OBJECT
    ;// eax has command ID

    cmp eax, IDC_FFT_FORWARD
    jnz @F

    and [esi].dwUser, NOT OSC_FFT_REVERSE
    mov [esi].pSource, FFT_FORWARD_PSOURCE
    jmp all_done

@@: cmp eax, IDC_FFT_REVERSE
    jnz @F

    or [esi].dwUser, OSC_FFT_REVERSE
    mov [esi].pSource, FFT_REVERSE_PSOURCE
    jmp all_done

@@: cmp eax, IDC_FFT_WINDOW
    jnz osc_Command

    xor [esi].dwUser, OSC_FFT_WINDOW

all_done:

    invoke fft_SyncPins
    mov eax, POPUP_SET_DIRTY + POPUP_REDRAW_OBJECT
    ret

fft_Command ENDP




;////////////////////////////////////////////////////////////////////
;//
;//
;//     _LoadUndo
;//

ASSUME_AND_ALIGN
fft_LoadUndo PROC

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

        .IF eax & OSC_FFT_REVERSE
            mov [esi].pSource, FFT_REVERSE_PSOURCE
        .ELSE
            mov [esi].pSource, FFT_FORWARD_PSOURCE
        .ENDIF

        ret

fft_LoadUndo ENDP

;//
;//
;//     _LoadUndo
;//
;////////////////////////////////////////////////////////////////////



ASSUME_AND_ALIGN


ENDIF   ;// USE_THIS_FILE
END
