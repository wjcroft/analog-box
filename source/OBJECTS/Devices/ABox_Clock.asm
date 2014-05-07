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
;//         changed to osc_Clock_Speed_string for about panel
;//
;//##////////////////////////////////////////////////////////////////////////
;//
;// ABox_Clock.asm
;//


comment ~ /*

    this allows monitoring of clock cycles as a fraction of a whole sample frame
    it is a hardware device, but is not playable, and has one pin suitable for connecting to a scope

*/ comment ~

OPTION CASEMAP:NONE

.586
.MODEL FLAT

    .NOLIST
    include <Abox.inc>
    include <szfloat.inc>
    .LIST

.DATA

    ;// global data

        ;osc_Clock_Speed_int  dd 0  ABOX242 AJT
        ;osc_Clock_Speed_frac dd 0
        osc_Clock_Speed_string db 16 DUP (0)   ;// formatted with eng suffix for reporting to About panel

USE_THIS_FILE equ 1
IFDEF USE_THIS_FILE

.DATA

BASE_FLAGS = BASE_HARDWARE OR BASE_NO_KEYBOARD OR BASE_NO_GROUP

osc_Clock   OSC_CORE { osc_Clock_Ctor,hardware_DetachDevice,,osc_Clock_Calc }
            OSC_GUI  {,,,,,,,,,osc_SaveUndo,clock_LoadUndo}
            OSC_HARD { osc_Clock_H_Ctor,osc_Clock_H_Dtor,osc_Clock_H_Open,osc_Clock_H_Close, osc_Clock_H_Ready }

    OSC_DATA_LAYOUT {NEXT_Clock,IDB_CLOCK,OFFSET popup_CLOCK,
        BASE_FLAGS,
        1,4,
        SIZEOF OSC_OBJECT + (SIZEOF APIN),
        SIZEOF OSC_OBJECT + (SIZEOF APIN) + SAMARY_SIZE ,
        SIZEOF OSC_OBJECT + (SIZEOF APIN) + SAMARY_SIZE }

    OSC_DISPLAY_LAYOUT { circle_container, CLOCK_PSOURCE, ICON_LAYOUT(10,4,2,5)}

    APIN_init {0.0,,'C',, PIN_OUTPUT OR UNIT_PERCENT }  ;// clock cycles

    short_name  db  'CPU clocks',0
    description db  'Derives the percentage of CPU time being used to calculate the circuit.',0
    ALIGN 4

    ;// private data

        osc_ClockScale  dd 0            ;// set by clock_EndMeasure

        ;//clock_factor REAL4 23219.95465  ;// 1000000*1024/44100   ABOX242 AJT
        clock_factor REAL4 0.02321995465  ;// 1024/44100

        clock_clock_start_lo    dd  0
        clock_clock_start_hi    dd  0
        clock_time_start    dd  0

    ;// clock scale * num cycles = percentage of use in 23.2 ms



.CODE



ASSUME_AND_ALIGN
clock_BeginMeasure PROC

    invoke timeGetTime
    mov clock_time_start, eax
    rdtsc
    mov clock_clock_start_lo, eax
    mov clock_clock_start_hi, edx

    ret

clock_BeginMeasure ENDP

.DATA

    sz_timer_problems db 'ABox2 has to shut down.',0ah,0dh,'Problems with the '
    sz_timer_caption  db 'system timer.',0
    ALIGN 4

.CODE

ASSUME_AND_ALIGN
clock_EndMeasure PROC

    invoke timeGetTime
    sub eax, clock_time_start
    .IF SIGN?
    neg eax
    .ENDIF
    .IF ZERO?

        invoke MessageBoxA, hMainWnd, OFFSET sz_timer_problems, OFFSET sz_timer_caption,MB_ICONEXCLAMATION OR MB_OK OR MB_TASKMODAL
        jmp ExitProcess

    .ENDIF
    push eax


    rdtsc
    sub edx, clock_clock_start_hi
    sub eax, clock_clock_start_lo
    push edx
    jnc J0
    dec DWORD PTR [esp]
J0: push eax

    fild DWORD PTR [esp+8]  ;// et
    fild QWORD PTR [esp]    ;// ec      et
    fdivr                   ;// ec/et(KHz)
    fmul math_1000          ;// Hz              <-- ABOX242 AJT
    
    ;// build the string for the about panel
    push edi
    fld st
    mov edx , FLOATSZ_DIG_4 OR FLOATSZ_ENG OR FLOATSZ_SPACE
    mov edi, OFFSET osc_Clock_Speed_string    
    call float_to_sz
    mov al, 0           ;// will terminate the string
    .IF CARRY?          ;// had an error!
        mov edi, OFFSET osc_Clock_Speed_string  ;// reset to empty string
    .ENDIF
    stosb               ;// terminate
    pop edi
    
    ;// build the factor for the clock object calc
    fmul clock_factor
    fld math_1
    fdivr

    add esp, 12

    fstp osc_ClockScale

    ret

clock_EndMeasure ENDP


;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
clock_LoadUndo PROC
    ret
clock_LoadUndo ENDP

;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////



ASSUME_AND_ALIGN
osc_Clock_Ctor PROC

        ;// register call
        ASSUME ebp:PTR LIST_CONTEXT ;// preserve
        ASSUME esi:PTR OSC_OBJECT   ;// preserve
        ASSUME edi:PTR OSC_BASE     ;// may destroy
        ASSUME ebx:PTR FILE_OSC     ;// may destroy
        ASSUME edx:PTR FILE_HEADER  ;// may destroy

    ;// we've been created
    ;// any data we have is loaded
    ;// so now all we have to do is get a device

        ;// strip out extra stuff if loading from file
        mov ecx, 0FFFFh
        .IF edx
            and ecx, [esi].dwUser
        .ENDIF

        mov edx, ecx
        invoke hardware_AttachDevice

    ;// that's it

        ret

osc_Clock_Ctor ENDP





ASSUME_AND_ALIGN
osc_Clock_H_Ctor PROC   ;// STDCALL uses esi edi


    .IF app_CPUFeatures & 10h

    ;// fill in the required device block stuff

        push edi
        slist_AllocateHead hardwareL, edi
        mov [edi].pBase, OFFSET osc_Clock
        pop edi

    .ENDIF

    ret

osc_Clock_H_Ctor ENDP


ASSUME_AND_ALIGN
osc_Clock_H_Dtor PROC;// STDCALL pDevBlock:PTR HARDWARE_DEVICEBLOCK

    ret 4

osc_Clock_H_Dtor ENDP










ASSUME_AND_ALIGN
osc_Clock_H_Open PROC STDCALL uses esi edi pDevice:PTR HARDWARE_DEVICEBLOCK

        mov edi, pDevice
        assume edi:PTR HARDWARE_DEVICEBLOCK

        DEBUG_IF <[edi].hDevice>    ;// opening an open device, not good

        mov eax, 1
        mov [edi].hDevice, eax      ;// open the device by setting 1 in the device ptr
        mov play_ClockMonitor, eax  ;// then flag the play thread to monitor for us

        xor eax, eax    ;// we can open

    ;// that's it

        ret

osc_Clock_H_Open ENDP



ASSUME_AND_ALIGN
osc_Clock_H_Close PROC STDCALL uses esi edi pDevice:PTR HARDWARE_DEVICEBLOCK

    ;// here, we close the device and unprepare the headers

        mov edi, pDevice
        assume edi:PTR HARDWARE_DEVICEBLOCK

        xor eax, eax

        mov [edi].hDevice, eax
        mov play_ClockMonitor, eax

    ;// that's it

        ret

osc_Clock_H_Close ENDP



ASSUME_AND_ALIGN
osc_Clock_H_Ready PROC  ;// STDCALL uses esi edi pDevice:PTR HARDWARE_DEVICEBLOCK

    ;// we're always ready
    mov eax, READY_TIMER;// treat this as a display device

    ret 4

osc_Clock_H_Ready   ENDP






ASSUME_AND_ALIGN
osc_Clock_Calc PROC

    ASSUME esi:PTR OSC_OBJECT

    .IF [esi].pDevice   ;// skip if we don't have a clock

        ;// make sure that play knows we're using clock cycles
        .IF !play_ClockMonitor

            .IF app_CPUFeatures & 10h
                mov play_ClockMonitor, 1
            .ELSE
                mov play_ClockMonitor, 0
            .ENDIF

        .ELSE

            OSC_TO_PIN_INDEX esi, edi, 0

            .IF [edi].pPin  ;// connected ?

                fild play_LastClock
                fmul osc_ClockScale
                push eax
                and [edi].dwStatus, NOT PIN_CHANGING
                mov ecx, SAMARY_LENGTH
                fstp DWORD PTR [esp]
                mov edi, [edi].pData
                pop eax
                rep stosd

            .ENDIF

        .ENDIF
    .ENDIF

;// that's it

    ret

osc_Clock_Calc ENDP

ASSUME_AND_ALIGN

ENDIF   ;// USE_THIS_FILE
END



