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
;// ABox_WaveIn.asm
;//
;//
;// TOC:
;// wavein_H_Ctor
;// wavein_H_Open
;// wavein_H_Close
;// wavein_H_Ready
;// wavein_Ctor
;// wavein_Calc
;// wavein_H_Calc
;// wavein_Render


comment ~ /*

    back to the origonal scheme of polling for completed buffers
    this is the most compatible scheme amonst the plethoria of sound cards

    Every time a buffer is written,
        WAVEIN_DATA.dwWriteCounter must be incremented to keep the order correct
        _H_Open will reset the count

    _H_Ready polls for WHDR_DONE buffers and sets WAVEIN_DATA.pReady
        it also adjusts the number of buffers, leaving the done bit alone

    _Calc grabs pReady and does the appropriate xfer of data
        it must also rest the WHDR_DONE flag, very important

    _H_Calc adds the buffers back in the stew
        and increments the writeCounter

*/ comment ~

OPTION CASEMAP:NONE

.586
.MODEL FLAT

USE_THIS_FILE equ 1

IFDEF USE_THIS_FILE

    .NOLIST
    include <Abox.inc>
    DIRECTSOUND_NOLIB EQU 1
    INCLUDE <com.inc>
    INCLUDE <directsound.inc>
    include <wave.inc>
    .LIST

.DATA


BASE_FLAGS = BASE_HARDWARE OR BASE_PLAYABLE OR BASE_NO_GROUP

osc_WaveIn  OSC_CORE { osc_Wave_Ctor,hardware_DetachDevice,,wavein_Calc}
            OSC_GUI  { wavein_Render,,,,,osc_Wave_Command,osc_Wave_InitMenu,,,wave_SaveUndo, wave_LoadUndo }
            OSC_HARD { wavein_H_Ctor,osc_Wave_H_Dtor,wavein_H_Open,wavein_H_Close, wavein_H_Ready, wavein_H_Calc }

    OSC_DATA_LAYOUT {NEXT_WaveIn,IDB_WAVEIN, OFFSET popup_WAVEIN,
        BASE_FLAGS,
        2,4,
        SIZEOF OSC_OBJECT + (SIZEOF APIN)*2,
        SIZEOF OSC_OBJECT + (SIZEOF APIN)*2 + SAMARY_SIZE * 2,
        SIZEOF OSC_OBJECT + (SIZEOF APIN)*2 + SAMARY_SIZE * 2 }

    OSC_DISPLAY_LAYOUT { devices_container, WAVEIN_PSOURCE, ICON_LAYOUT(0,3,2,0)}

    APIN_init {-0.15,,'L',, PIN_OUTPUT OR UNIT_DB }  ;// LeftIn
    APIN_init { 0.15,,'R',, PIN_OUTPUT OR UNIT_DB }  ;// RightIn

    short_name  db  'Wave  In',0
    description db  'Reads data from the desired Wave device.',0
    ALIGN 4

    ;// flags stored on the top of dwUser

    ;// private data

        wavein_scale REAL4 3.051850948e-5  ;// this produces the REAL4 values

        WAVEIN_LENGTH equ SAMARY_LENGTH * MAX_SAMPLE_BUFFERS
        WAVEIN_SIZE equ WAVEIN_LENGTH * 4

    ;// this struct is pointed to by a hardware device block

        WAVEIN_DATA STRUCT

            dwWriteCounter  dd  0   ;// counts buffers as they're written
            pReady          dd  0   ;// points at the buffer that ready for calculation

            waveHdr     WAVEHDR MAX_SAMPLE_BUFFERS dup ({}) ;// wave hdrs
            waveData    dd WAVEIN_LENGTH dup (0) ;//    wave out data

        WAVEIN_DATA ENDS



.CODE


;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
wavein_H_Ctor PROC

    ;// here we fill in our dev blocks and allocate the headers and devices
    ;// must preserve esi

        xor ebx, ebx
        invoke waveInGetNumDevs
        or ebx, eax
        jz all_done

        invoke about_SetLoadStatus

    ;// make some room

        sub esp, SIZEOF WAVEINCAPS
        st_wiCaps TEXTEQU <(WAVEINCAPS PTR [esp])>

        jmp enter_loop

    ;// loop through ebx, times

        .REPEAT

            lea eax, st_wiCaps
            invoke waveInGetDevCapsA, ebx, eax, SIZEOF WAVEINCAPS

            ;// make sure we can use this device
            test st_wiCaps.dwFormats, WAVE_FORMAT_4S16
            .IF !ZERO?

            ;// we can

                slist_AllocateHead hardwareL, edi
                mov [edi].ID, ebx

                mov [edi].num_buffers, WAVE_DEFAULT_BUFFERS

                lea edx, st_wiCaps.szPname
                mov [edi].pBase, OFFSET osc_WaveIn
                invoke lstrcpyA, ADDR [edi].szName, edx

                lea edx, st_wiCaps.szPname
                LISTBOX about_hWnd_device, LB_ADDSTRING, 0, edx
                lea edx, st_wiCaps.szPname
                WINDOW about_hWnd_load, WM_SETTEXT, 0, edx

            ;// allocate the waveout data headers and their data

                invoke memory_Alloc, GPTR, SIZEOF WAVEIN_DATA
                mov [edi].pData, eax

            ;// fill in the the headers

                mov ecx, MAX_SAMPLE_BUFFERS

                mov edi, eax
                ASSUME edi:PTR WAVEIN_DATA
                lea edx, [edi].waveData
                lea edi, [edi].waveHdr
                ASSUME edi:PTR WAVEHDR

                .REPEAT

                    mov [edi].pData, edx                    ;// save the data pointer
                    mov [edi].dwBufferLength, SAMARY_SIZE   ;// set the buffer length
                    add edi, SIZEOF WAVEHDR
                    add edx, SAMARY_SIZE
                    dec ecx

                .UNTIL ZERO?

            .ENDIF

        enter_loop:

            dec ebx

        .UNTIL SIGN?

    ;// that's it

        add esp, SIZEOF WAVEINCAPS
        st_wiCaps TEXTEQU <>

    all_done:

        ret

wavein_H_Ctor ENDP



ASSUME_AND_ALIGN
wavein_H_Open PROC STDCALL uses esi edi pDevice:PTR HARDWARE_DEVICEBLOCK

    ;// we must return non zero if we cannot open the device

        mov edi, pDevice
        ASSUME edi:PTR HARDWARE_DEVICEBLOCK

        DEBUG_IF <[edi].hDevice> ;// we're already open !!

    ;// open the device

        invoke waveInOpen, ADDR [edi].hDevice, [edi].ID, OFFSET Wave_Format,
                            play_hEvent, edi, CALLBACK_EVENT
        test eax, eax
        jnz all_done

    ;// open the device for real

        mov esi, [edi].pData
        ASSUME esi:PTR WAVEIN_DATA

        mov [esi].dwWriteCounter, 0     ;// reset the sync counter

    ;// zero the data

        lea edi, [esi].waveData
        ;//xor eax, eax             ;// eax is already zero
        mov ecx, WAVEIN_LENGTH
        ;// cld                     ;// no need to do this
        rep stosd

    ;// prepare and add enough headers and set the count order

        mov edi, pDevice
        ASSUME edi:PTR HARDWARE_DEVICEBLOCK

        ;// esi is still WAVIN_DATA

        lea ebx, [esi].waveHdr
        ASSUME ebx:PTR WAVEHDR

        ;// get the number of buffers and add them all
        mov ecx, [edi].num_buffers
        .REPEAT

            mov [ebx].dwFlags, 0                    ;// reset the flags
            mov eax, [esi].dwWriteCounter           ;// get the write counter
            mov [ebx].dwUser, eax                   ;// store in dwUser
            inc [esi].dwWriteCounter                ;// increment

            push ecx

            invoke waveInPrepareHeader, [edi].hDevice, ebx, SIZEOF WAVEHDR

            .IF !eax
                invoke waveInAddBuffer, [edi].hDevice, ebx, SIZEOF WAVEHDR
            .ENDIF

            pop ecx

            add ebx, SIZEOF WAVEHDR

        .UNTILCXZ

    ;// start recording

        invoke waveInStart, [edi].hDevice
        DEBUG_IF <eax>  ;// could not start

    all_done:

    ;// that's it

        ret

wavein_H_Open ENDP



ASSUME_AND_ALIGN
wavein_H_Close PROC STDCALL uses esi edi pDevice:PTR HARDWARE_DEVICEBLOCK

    LOCAL retry:DWORD

    mov retry, 0

    ;// here, we close the device and unprepare the headers

        mov edi, pDevice
        assume edi:PTR HARDWARE_DEVICEBLOCK

tryagain:

    ;// reset the port

        invoke waveInReset, [edi].hDevice
        DEBUG_IF <eax>  ;// couldn't reset

    ;// unprepare the headers

        mov esi, [edi].pData
        assume esi:PTR WAVEIN_DATA

        lea esi, [esi].waveHdr
        ASSUME esi:PTR WAVEHDR

        mov ebx, MAX_SAMPLE_BUFFERS

        .REPEAT

            .IF [esi].dwFlags & WHDR_PREPARED

                invoke waveInUnprepareHeader, [edi].hDevice, esi, SIZEOF WAVEHDR
                .IF eax

                    .IF eax == 21h  ;// nt problem
                        inc retry
                        .IF retry < 10
                            invoke Sleep, 10
                            jmp tryagain
                        .ENDIF
                        mov edx, [esi].dwFlags
                    .ENDIF
                    BOMB_TRAP
                .ENDIF
                mov [esi].dwFlags, 0

            .ENDIF

            add esi, SIZEOF WAVEHDR
            dec ebx

        .UNTIL ZERO?

    ;// close the port and null the handle

        invoke waveInClose, [edi].hDevice
        DEBUG_IF <eax>
        mov [edi].hDevice, eax

    ;// that's it

        ret

wavein_H_Close ENDP




ASSUME_AND_ALIGN
wavein_H_Ready PROC STDCALL uses esi edi pDevice:PTR HARDWARE_DEVICEBLOCK

    ;// here, we poll all the headers and find the finished ones
    ;// we store the lowest dwUser and then use it to set the pReady pointer
    ;// we also count how many headers are prepared,
    ;// and adjust as required by osc.dwUser

    ;// this is called by the play proc very often

        mov edi, pDevice
        ASSUME edi:PTR HARDWARE_DEVICEBLOCK

        mov esi, [edi].pData
        ASSUME esi:PTR WAVEIN_DATA

        lea ebx, [esi].waveHdr
        ASSUME ebx:PTR WAVEHDR

        mov ecx, MAX_SAMPLE_BUFFERS
        mov eax, 7FFFFFFFh  ;// eax tracks the lowest dwUser
        push ebp            ;// save ebp
        xor edx, edx        ;// edx counts prepared
        xor ebp, ebp        ;// ebp will store the pointer to the ready buffer

        .REPEAT

            .IF [ebx].dwFlags & WHDR_PREPARED   ;// check if this buffer is prepared

                inc edx                         ;// update the count of prepared

            .ENDIF

            .IF [ebx].dwFlags & WHDR_DONE   ;// check if this buffer is done
                                            ;// _calc must reset this
                .IF eax > [ebx].dwUser      ;// check if it's lower

                    mov ebp, ebx            ;// store the pointer
                    mov eax, [ebx].dwUser   ;// store the new lowest

                .ENDIF

            .ENDIF

            add ebx, SIZEOF WAVEHDR

        .UNTILCXZ

        ;// now we check if there the correct amount of buffers in the stew

        sub edx, [edi].num_buffers
        .IF SIGN?

            ;// not enough buffers
            ;// edx has the neagtive amount of buffers to add

            lea ebx, [esi].waveHdr
            mov ecx, MAX_SAMPLE_BUFFERS
            .WHILE edx && ecx

                .IF !([ebx].dwFlags & WHDR_PREPARED)

                    push edx
                    push ecx

                    mov eax, [esi].dwWriteCounter   ;// get the write counter
                    mov [ebx].dwUser, eax           ;// store in header
                    inc [esi].dwWriteCounter        ;// increament the write counter
                    mov [ebx].dwFlags, 0            ;// reset the flags
                    invoke waveInPrepareHeader, [edi].hDevice, ebx, SIZEOF WAVEHDR
                    DEBUG_IF <eax>
                    invoke waveInAddBuffer, [edi].hDevice, ebx, SIZEOF WAVEHDR
                    DEBUG_IF <eax>

                    pop ecx
                    pop edx
                    inc edx

                .ENDIF

                add ebx, SIZEOF WAVEHDR
                dec ecx

            .ENDW

        .ELSEIF !SIGN? && !ZERO?

            ;// too many play buffers
            ;// edx has the number to remove

            lea ebx, [esi].waveHdr
            mov ecx, MAX_SAMPLE_BUFFERS
            .WHILE edx && ecx

                .IF ([ebx].dwFlags & WHDR_PREPARED) && ([ebx].dwFlags & WHDR_DONE)

                    push edx
                    push ecx

                    invoke waveInUnprepareHeader, [edi].hDevice, ebx, SIZEOF WAVEHDR
                    .IF eax
                        BOMB_TRAP
                    .ENDIF
                    and [ebx].dwFlags, NOT WHDR_PREPARED
                    ;// leave the done bit set so we use this buffer

                    pop ecx
                    pop edx
                    dec edx

                .ENDIF

                add ebx, SIZEOF WAVEHDR
                dec ecx

            .ENDW

        .ENDIF

    ;// now we deterime what to return

        xor eax, eax
        or ebp, ebp
        .IF !ZERO?
            mov eax, READY_BUFFERS
        .ELSE
            mov eax, READY_DO_NOT_CALC
        .ENDIF
        mov [esi].pReady, ebp
        pop ebp

    ;// that's it

        ret

wavein_H_Ready  ENDP


;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
wavein_Calc PROC uses esi

ASSUME esi:PTR OSC_OBJECT

        GET_OSC_FROM ebx, esi

    ;// make sure we reset the ready buffer by turning off the done bit

        mov esi, [ebx].pDevice
        .IF esi

            ASSUME esi:PTR HARDWARE_DEVICEBLOCK

            .IF !([esi].dwFlags & HARDWARE_BAD_DEVICE)

                mov esi, [esi].pData
                ASSUME esi:PTR WAVEIN_DATA
                mov esi, [esi].pReady           ;// esi is the ready buffer
                ASSUME esi:PTR WAVEHDR

                and [esi].dwFlags, NOT WHDR_DONE ;// shut off the done bit

                mov esi, [esi].pData            ;// esi points at the source data

                OSC_TO_PIN_INDEX ebx, edi, 0    ;// edi points at left out
                OSC_TO_PIN_INDEX ebx, edx, 1    ;// edx points at right out

                .IF [edi].pPin || [edx].pPin    ;// make sure something is connected

                    ;// we're connected

                    or [edi].dwStatus, PIN_CHANGING
                    or [edx].dwStatus, PIN_CHANGING

                    fld wavein_scale

                    .IF [edi].pPin      ;// left out is connected

                        mov edi, [edi].pData

                        xor ecx, ecx
                        .WHILE ecx < SAMARY_LENGTH

                            fIld WORD PTR [esi+ecx*4]       ;// x0  S
                            fmul st, st(1)
                            fIld WORD PTR [esi+ecx*4+4]     ;// x1  x0  S
                            fmul st, st(2)
                            fIld WORD PTR [esi+ecx*4+8]     ;// x2  x1  x0  S
                            fmul st, st(3)
                            fIld WORD PTR [esi+ecx*4+0Ch]   ;// x3  x2  x1  x0  S
                            fmul st, st(4)

                            fxch st(3)                  ;// x0  x2  x1  x3  S
                            fstp DWORD PTR [edi+ecx*4]  ;// x2  x1  x3
                            fxch                        ;// x1  x2  x3  S
                            fstp DWORD PTR [edi+ecx*4+4];// x2  x3  S
                            fstp DWORD PTR [edi+ecx*4+8];// x3  S
                            fstp DWORD PTR [edi+ecx*4+0Ch];//   S

                            add ecx, 4

                        .ENDW

                    .ENDIF

                    .IF [edx].pPin      ;// right out is connected

                        mov edx, [edx].pData

                        add esi, 2

                        xor ecx, ecx

                        .WHILE ecx < SAMARY_LENGTH

                            fIld WORD PTR [esi+ecx*4]       ;// x0  S
                            fmul st, st(1)
                            fIld WORD PTR [esi+ecx*4+4]     ;// x1  x0  S
                            fmul st, st(2)
                            fIld WORD PTR [esi+ecx*4+8]     ;// x2  x1  x0  S
                            fmul st, st(3)
                            fIld WORD PTR [esi+ecx*4+0Ch]   ;// x3  x2  x1  x0  S
                            fmul st, st(4)

                            fxch st(3)                  ;// x0  x2  x1  x3  S
                            fstp DWORD PTR [edx+ecx*4]  ;// x2  x1  x3
                            fxch                        ;// x1  x2  x3  S
                            fstp DWORD PTR [edx+ecx*4+4];// x2  x3  S
                            fstp DWORD PTR [edx+ecx*4+8];// x3  S
                            fstp DWORD PTR [edx+ecx*4+0Ch];//   S

                            add ecx, 4

                        .ENDW

                    .ENDIF

                    fstp st

                .ENDIF  ;// not connected

            .ENDIF  ;// bad device

        .ENDIF  ;// no device

    ;// that's it

        ret

wavein_Calc ENDP


ASSUME_AND_ALIGN
wavein_H_Calc PROC STDCALL uses esi edi pDevice:PTR HARDWARE_DEVICEBLOCK

    mov esi, pDevice
    ASSUME esi:PTR HARDWARE_DEVICEBLOCK

    mov edi, [esi].pData
    ASSUME edi:PTR WAVEIN_DATA

    mov ebx, [edi].pReady
    ASSUME ebx:PTR WAVEHDR

    .IF [ebx].dwFlags & WHDR_PREPARED

        mov eax, [edi].dwWriteCounter
        mov [ebx].dwUser, eax
        inc [edi].dwWriteCounter

        invoke waveInAddBuffer, [esi].hDevice, ebx, SIZEOF WAVEHDR
        DEBUG_IF <eax>  ;// couldn't write

    .ENDIF

    ret

wavein_H_Calc ENDP



ASSUME_AND_ALIGN
wavein_Render PROC

        invoke gdi_render_osc
        ASSUME esi:PTR OSC_OBJECT

    ;// display the device name

        .IF [esi].pDevice

            GDI_DC_SELECT_FONT hFont_pin
            GDI_DC_SET_COLOR COLOR_OSC_TEXT

            mov ecx, [esi].pDevice
            add ecx, OFFSET HARDWARE_DEVICEBLOCK.szName
            invoke DrawTextA, gdi_hDC, ecx, -1, ADDR [esi].rect, DT_CENTER OR DT_WORDBREAK

        .ENDIF

    ;// that's it

        ret

wavein_Render ENDP
















ASSUME_AND_ALIGN


ENDIF   ;// USE_THIS_FILE
END



