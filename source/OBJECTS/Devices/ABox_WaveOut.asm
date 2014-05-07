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
;// ABox_WaveOut.asm
;//
;//
;// TOC
;//
;// directSound_H_Callback
;// waveout_H_Ctor
;// osc_Wave_H_Dtor
;// waveout_H_Open
;// waveout_H_Close
;// waveout_H_Ready
;// osc_Wave_Ctor
;// waveout_Calc
;// stereo_float_to_stereo_16
;// waveout_H_Calc
;// waveout_Render
;// osc_Wave_InitMenu
;// osc_Wave_Command
;// wave_SaveUndo
;// wave_LoadUndo


OPTION CASEMAP:NONE

.586
.MODEL FLAT

USE_THIS_FILE equ 1

IFDEF USE_THIS_FILE

    .NOLIST
    INCLUDE <Abox.inc>
    DIRECTSOUND_NOLIB EQU 1
    INCLUDE <com.inc>
    INCLUDE <directsound.inc>
    INCLUDE <wave.inc>
    INCLUDE <hardware_debug.inc>
    .LIST


 H_LOG_TRACE_STATUS = 1
;// H_LOG_TRACE_STATUS = 2



.DATA

        BASE_FLAGS = BASE_HARDWARE OR BASE_PLAYABLE OR BASE_NO_GROUP

    ;// object definition

        osc_WaveOut OSC_CORE { osc_Wave_Ctor,hardware_DetachDevice,,waveout_Calc }
                    OSC_GUI  { waveout_Render,,,,,osc_Wave_Command,osc_Wave_InitMenu,,,wave_SaveUndo,wave_LoadUndo }
                    OSC_HARD { waveout_H_Ctor,osc_Wave_H_Dtor,waveout_H_Open,waveout_H_Close,waveout_H_Ready,waveout_H_Calc }

    ;// layout of the data

        OSC_DATA_LAYOUT {NEXT_WaveOut,IDB_WAVEOUT,popup_WAVEOUT,
            BASE_FLAGS,
            3,4,
            SIZEOF OSC_OBJECT + (SIZEOF APIN)*3,
            SIZEOF OSC_OBJECT + (SIZEOF APIN)*3,
            SIZEOF OSC_OBJECT + (SIZEOF APIN)*3 }

    ;// display block

        OSC_DISPLAY_LAYOUT{ devices_container, WAVEOUT_PSOURCE, ICON_LAYOUT( 0,4,2,0) }

    ;// pins

        waveout_L APIN_init {-0.85,sz_Left, 'L',,UNIT_DB }  ;// LeftIn
        waveout_R APIN_init {0.85,sz_Right, 'R',,UNIT_DB }  ;// RightIn
        waveout_A APIN_init {-1.0,sz_Amplitude, 'A',,UNIT_DB }  ;// Amplitude

        short_name  db  'Wave Out',0
        description db  'Sends data to the desired Wave device.',0
        ALIGN 4

    ;// flags stored on the top of dwUser, lower word reserved for driver id

        WAVE_BUFFER_1       equ  00010000h
        WAVE_BUFFER_TEST    equ  003F0000h  ;// max of 32
        WAVE_BUFFER_MASK    equ NOT WAVE_BUFFER_TEST

        WAVEOUT_CLIP        equ  10000000h  ;// clipping flag inidicator

    ;// private data

        Wave_Format WAVEFORMATEX { WAVE_FORMAT_PCM, 2, SAMPLE_RATE, SAMPLE_RATE*4, 4, 16, 0 }
        ALIGN 4

    ;// equates for buffer manipulation

        WAVEOUT_NUM_BUFFERS equ MAX_SAMPLE_BUFFERS

        WAVEOUT_LENGTH equ SAMARY_LENGTH * WAVEOUT_NUM_BUFFERS


    ;// this struct is pointed to by a hardware device block

        WAVEOUT_DATA STRUCT

            waveHdr WAVEHDR WAVEOUT_NUM_BUFFERS dup ({});// wave hdr array
            waveData    dd WAVEOUT_LENGTH dup (0)       ;// wave out data array
            pReady      dd  0                           ;// points at ready wave hdr

        WAVEOUT_DATA ENDS

    ;// DIRECT_SOUND_DATA   ;// defined in wave.inc


        directsound_latency_scale REAL4 5.66893424E-3   ;// 1000 / 4 / 44100 * 1000 = milliseconds / byte

    ;// functions

        waveout_Ctor PROTO

        waveout_Calc PROTO

        waveout_H_Ctor PROTO    ;// STDCALL
        waveout_H_Dtor PROTO STDCALL pDevBlock:PTR HARDWARE_DEVICEBLOCK

        waveout_H_Open  PROTO STDCALL pDevice:PTR HARDWARE_DEVICEBLOCK
        waveout_H_Ready PROTO STDCALL pDevice:PTR HARDWARE_DEVICEBLOCK
        waveout_H_Close PROTO STDCALL pDevice:PTR HARDWARE_DEVICEBLOCK

        sz_DSOUND_DLL               db 'DSOUND.DLL',0
        sz_DirectSoundEnumerateA    db 'DirectSoundEnumerateA',0
        sz_DirectSoundCreate        db 'DirectSoundCreate',0
        sz_primary                  db ' (primary)',0
        sz_shared                   db ' (shared)',0
        ALIGN 4

        pDirectSoundCreate      dd  0
        pDirectSoundEnumerateA  dd  0
        directSound_hLib        dd  0

    ;// osc_map for this object


        OSC_MAP STRUCT

            OSC_OBJECT  {}

            pin_L   APIN    {}
            pin_R   APIN    {}
            pin_A   APIN    {}

        OSC_MAP ENDS



.CODE




;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
ASSUME_AND_ALIGN
directSound_H_Callback  PROC STDCALL pGuid:DWORD, pszDescription:DWORD, psszModule:DWORD, pContext:DWORD

        LOCAL pDirectSound:DWORD
        LOCAL dsCaps:DSCAPS
        LOCAL pDirectSoundBuffer:DWORD
        LOCAL dsBufferDesc:DSBUFFERDESC
        LOCAL dsbCaps:DSBCAPS
        LOCAL wvFormat:WAVEFORMATEX
        LOCAL wPad:WORD
        LOCAL wvBytesWritten:DWORD

    ;// run the gaultlet

        cmp pGuid, 0
        je cant_use_period

        WINDOW about_hWnd_load, WM_SETTEXT,,pszDescription

    ;// try to create direct sound

        pushd 0
        lea eax, pDirectSound
        push eax
        push pGuid
        call pDirectSoundCreate
        test eax, eax
        jnz cant_use_period

    ;// direct sound is created
    ;// get the caps

        mov dsCaps.dwSize, SIZEOF DSCAPS
        com_invoke IDirectSound, GetCaps, pDirectSound, ADDR dsCaps
        test eax, eax
        jnz cant_use_directsound

    ;// skip emulated drivers

        mov eax, dsCaps.dwFlags
        test eax, DSCAPS_EMULDRIVER
        jnz cant_use_directsound

    ;// make sure we can do primary stereo 16

        and eax, DSCAPS_PRIMARYSTEREO OR DSCAPS_PRIMARY16BIT
        cmp eax, DSCAPS_PRIMARYSTEREO OR DSCAPS_PRIMARY16BIT
        jne cant_use_directsound

    ;// try to set the cooperative level
                                                                    ;// hMainWnd doesn't exist yet
        com_invoke IDirectSound, SetCooperativeLevel, pDirectSound, about_hWnd, DSSCL_WRITEPRIMARY
        or eax, eax
        jnz cant_use_directsound

    ;// make a buffer

        mov dsBufferDesc.dwSize, SIZEOF DSBUFFERDESC
        mov dsBufferDesc.dwFlags, DSBCAPS_PRIMARYBUFFER ;// OR DSBCAPS_STICKYFOCUS
        mov dsBufferDesc.dwBufferBytes,0
        mov dsBufferDesc.dwReserved,0
        mov dsBufferDesc.lpwfxFormat, 0 ;// OFFSET Wave_Format

    ;// try to create a buffer

        com_invoke IDirectSound, CreateSoundBuffer, pDirectSound, ADDR dsBufferDesc, ADDR pDirectSoundBuffer, 0
        or eax, eax
        jnz cant_use_directsound

    ;// buffer is created

    ;// try to set the format

        com_invoke IDirectSoundBuffer, SetFormat, pDirectSoundBuffer, OFFSET Wave_Format
        test eax, eax
        jnz cant_use_buffer

    ;// get the buffer capabilities

        mov dsbCaps.dwSize, SIZEOF DSBCAPS
        com_invoke IDirectSoundBuffer, GetCaps, pDirectSoundBuffer, ADDR dsbCaps
        test eax, eax
        jnz cant_use_buffer

    ;// make sure it's not too small

        mov eax, dsbCaps.dwBufferBytes
        shr eax, LOG2(SAMARY_LENGTH*4)
        test eax, eax
        jz cant_use_buffer

    ;// verify that we set to format

        com_invoke IDirectSoundBuffer, GetFormat, pDirectSoundBuffer, ADDR wvFormat, SIZEOF WAVEFORMATEX, ADDR wvBytesWritten
        test eax, eax
        jnz cant_use_buffer

    ;// make sure the format is correct

        .IF wvFormat.wChannels == 2 &&  \
            wvFormat.dwSamplesPerSec == SAMPLE_RATE && \
            wvFormat.wBitsPerSample == 16

    ;////////////////////////////////////////////////////////////////////////////////////////////

    ;// we may use this buffer

            push ebx
            push edi


        comment ~ /*

            we're going to create two devices from this one
            one will be a primary buffer
            the other a normal buffer

        */ comment ~

        ;// PRIMARY

            ;// allocate a new device block

                slist_AllocateHead hardwareL, edi   ;// HARDWARE_DEVICEBLOCK

            ;// set and iterate the id number

                mov ecx, pContext
                mov eax, DWORD PTR [ecx]
                mov [edi].ID, eax
                inc eax
                mov DWORD PTR [ecx], eax

            ;// set the base class and copy the name

                mov [edi].pBase, OFFSET osc_WaveOut

                mov ecx, pszDescription
                lea edx, [edi].szName
                STRCPY edx, ecx

            ;// tack on a primary label

                mov ecx, OFFSET sz_primary
                STRCPY edx, ecx

            ;// set the default number of buffers

                mov [edi].num_buffers, DIRECTSOUND_DEFAULT_BUFFERS

            ;// set the flags correctly

                or [edi].dwFlags, HARDWARE_IS_DIRECTSOUND

            ;// send device name to status list

                lea edx, [edi].szName
                LISTBOX about_hWnd_device, LB_ADDSTRING, 0, edx

            ;// allocate direct sound data for this device

                invoke memory_Alloc, GPTR, SIZEOF DIRECTSOUND_DATA
                mov [edi].pData, eax
                mov ebx, eax
                ASSUME ebx:PTR DIRECTSOUND_DATA

            ;// fill in important information from the caps stucts

                    or [ebx].dwFlags, DIRECTSOUND_IS_PRIMARY    ;// set so H_Ready will compute the laency

                ;// copy the guid

                    mov ecx, pGuid

                    mov eax, DWORD PTR [ecx+0]
                    mov edx, DWORD PTR [ecx+4]
                    mov DWORD PTR [ebx].guid[0], eax
                    mov DWORD PTR [ebx].guid[4], edx
                    mov eax, DWORD PTR [ecx+8]
                    mov edx, DWORD PTR [ecx+0Ch]
                    mov DWORD PTR [ebx].guid[8], eax
                    mov DWORD PTR [ebx].guid[0Ch], edx

                ;// determine the number of block

                    mov eax, dsbCaps.dwBufferBytes
                    shr eax, LOG2(SAMARY_LENGTH*4)
                    mov [ebx].num_blocks, eax

        ;// SECONDARY

            ;// allocate a new device block

                slist_AllocateHead hardwareL, edi

            ;// set and iterate the id number

                mov ecx, pContext
                mov eax, DWORD PTR [ecx]
                mov [edi].ID, eax
                inc eax
                mov DWORD PTR [ecx], eax

            ;// set the base class and copy the name

                mov [edi].pBase, OFFSET osc_WaveOut

                mov ecx, pszDescription
                lea edx, [edi].szName
                STRCPY edx, ecx

            ;// tack on a shared label

                mov ecx, OFFSET sz_shared
                STRCPY edx, ecx

            ;// set the default number of buffers

                mov [edi].num_buffers, DIRECTSOUND_DEFAULT_BUFFERS

            ;// set the flags correctly

                or [edi].dwFlags, HARDWARE_IS_DIRECTSOUND

            ;// send device name to status list

                lea edx, [edi].szName
                LISTBOX about_hWnd_device, LB_ADDSTRING, 0, edx

            ;// allocate direct sound data for this device

                invoke memory_Alloc, GPTR, SIZEOF DIRECTSOUND_DATA
                mov [edi].pData, eax
                mov ebx, eax
                ASSUME ebx:PTR DIRECTSOUND_DATA

            ;// fill in important information from the caps stucts

                ;// or [ebx].dwFlags, DIRECTSOUND_IS_PRIMARY    ;// set so H_Ready will compute the laency

                ;// copy the guid

                    mov ecx, pGuid

                    mov eax, DWORD PTR [ecx+0]
                    mov edx, DWORD PTR [ecx+4]
                    mov DWORD PTR [ebx].guid[0], eax
                    mov DWORD PTR [ebx].guid[4], edx
                    mov eax, DWORD PTR [ecx+8]
                    mov edx, DWORD PTR [ecx+0Ch]
                    mov DWORD PTR [ebx].guid[8], eax
                    mov DWORD PTR [ebx].guid[0Ch], edx

                ;// dset the number of block

                    mov [ebx].num_blocks, DIRECTSOUND_SECONDARY_BLOCKS


            ;// clean up and exit

            pop edi
            pop ebx

        .ENDIF

    ;////////////////////////////////////////////////////////////////////////////////////////////

    cant_use_buffer:        ;// free the buffer

        com_invoke IDirectSoundBuffer, Release, pDirectSoundBuffer

    cant_use_directsound:   ;// free direct sound

        com_invoke IDirectSound, Release, pDirectSound

    cant_use_period:

    mov eax, 1
    ret

directSound_H_Callback  ENDP


;/////////////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
waveout_H_Ctor PROC

    ;// here we fill in our dev blocks and allocate the headers and devices
    ;// must preserve esi

        xor ebx, ebx
        invoke waveOutGetNumDevs
        or ebx, eax
        jz all_done

        invoke about_SetLoadStatus

    ;// make some rome

        sub esp, SIZEOF WAVEOUTCAPS
        st_woCaps TEXTEQU <(WAVEOUTCAPS PTR [esp])>

    ;// loop through ebx times

        jmp enter_loop

        .REPEAT

            lea eax, st_woCaps
            invoke waveOutGetDevCapsA, ebx, eax, SIZEOF WAVEOUTCAPS

            ;// dwSupport & WAVECAPS_SYNC ? This will potentially freeze the computer ?

        ;// make sure we can use this device

            test st_woCaps.dwFormats, WAVE_FORMAT_4S16
            .IF !ZERO?

            ;// we can

                slist_AllocateHead hardwareL, edi
                mov [edi].ID, ebx

                mov [edi].num_buffers, WAVE_DEFAULT_BUFFERS

                lea edx, st_woCaps.szPname
                mov [edi].pBase, OFFSET osc_WaveOut
                invoke lstrcpyA, ADDR [edi].szName, edx

                lea edx, st_woCaps.szPname
                LISTBOX about_hWnd_device, LB_ADDSTRING, 0, edx

                lea edx, st_woCaps.szPname
                WINDOW about_hWnd_load, WM_SETTEXT, 0, edx

            ;// allocate one wavehdr and data block

                invoke memory_Alloc, GPTR, SIZEOF WAVEOUT_DATA
                mov [edi].pData, eax

            ;// fill in the the headers

                mov ecx, WAVEOUT_NUM_BUFFERS

                mov edi, eax
                ASSUME edi:PTR WAVEOUT_DATA

                lea edx, [edi].waveHdr
                ASSUME edx:PTR WAVEHDR

                lea edi, [edi].waveData

                .REPEAT

                    mov [edx].pData, edi                    ;// save the data pointer
                    mov [edx].dwBufferLength, SAMARY_SIZE   ;// set the buffer length

                    add edx, SIZEOF WAVEHDR
                    add edi, SAMARY_SIZE

                    dec ecx

                .UNTIL ZERO?

            .ENDIF

        enter_loop:

            dec ebx

        .UNTIL SIGN?

    ;// that's it

        add esp, SIZEOF WAVEOUTCAPS
        st_woCaps TEXTEQU <>

    all_done:

    ;// now we check direct sound

        invoke LoadLibraryA, OFFSET sz_DSOUND_DLL
        .IF eax

            mov directSound_hLib, eax
            mov ebx, eax

            invoke about_SetLoadStatus

            invoke GetProcAddress, ebx, OFFSET sz_DirectSoundCreate
            mov pDirectSoundCreate, eax

            invoke GetProcAddress, ebx, OFFSET sz_DirectSoundEnumerateA
            mov pDirectSoundEnumerateA, eax

            .IF pDirectSoundCreate && pDirectSoundEnumerateA

                invoke waveOutGetNumDevs
                push eax
                push esp
                push OFFSET directSound_H_Callback
                call pDirectSoundEnumerateA
                pop eax

            .ELSE

                invoke FreeLibrary, ebx
                mov directSound_hLib, 0

            .ENDIF

        .ENDIF

        ret

waveout_H_Ctor ENDP


ASSUME_AND_ALIGN
osc_Wave_H_Dtor PROC STDCALL pDevBlock:PTR HARDWARE_DEVICEBLOCK

    ;// we assume all the devices are stopped

    ;// fortunately all the data is in the same spot

        mov edx, pDevBlock
        assume edx:PTR HARDWARE_DEVICEBLOCK
        invoke memory_Free, [edx].pData

    ;// unload direct sound

        .IF directSound_hLib

            invoke FreeLibrary, directSound_hLib
            mov directSound_hLib, 0

        .ENDIF

    ;// that's it

        ret

osc_Wave_H_Dtor ENDP



ASSUME_AND_ALIGN
waveout_H_Open PROC STDCALL uses esi edi ebx pDevice:PTR HARDWARE_DEVICEBLOCK

        LOCAL dsBufferDesc:DSBUFFERDESC

        H_LOG_TRACE <waveout_H_Open>

    ;// we must return non zero if we cannot open the device

        mov edi, pDevice
        ASSUME edi:PTR HARDWARE_DEVICEBLOCK

    ;// check if we're already open

        DEBUG_IF<[edi].hDevice>

        .IF [edi].dwFlags & HARDWARE_IS_DIRECTSOUND

            mov esi, pDevice
            ASSUME esi:PTR HARDWARE_DEVICEBLOCK
            mov ebx, [esi].pData
            ASSUME ebx:PTR DIRECTSOUND_DATA

            pushd 0
            lea eax, [esi].hDevice
            push eax
            lea eax, [ebx].guid
            push eax
            call pDirectSoundCreate ;// , ADDR [ebx].guid, ADDR [esi].hDevice, 0
            .IF !eax

                mov dsBufferDesc.dwSize, SIZEOF DSBUFFERDESC
                mov dsBufferDesc.dwReserved,eax

                .IF [ebx].dwFlags & DIRECTSOUND_IS_PRIMARY

                    com_invoke IDirectSound, SetCooperativeLevel, [esi].hDevice, hMainWnd, DSSCL_WRITEPRIMARY
                    or eax, eax
                    jnz cant_set_coop_level

                    mov dsBufferDesc.dwFlags, DSBCAPS_PRIMARYBUFFER OR DSBCAPS_STICKYFOCUS
                    mov dsBufferDesc.dwBufferBytes,eax
                    mov dsBufferDesc.lpwfxFormat, eax

                .ELSE   ;// secondary buffer

                    com_invoke IDirectSound, SetCooperativeLevel, [esi].hDevice, hMainWnd, DSSCL_NORMAL
                    or eax, eax
                    jnz cant_set_coop_level

                    mov dsBufferDesc.dwFlags, DSBCAPS_STICKYFOCUS OR DSBCAPS_GLOBALFOCUS ;// global added abox225
                    mov dsBufferDesc.dwBufferBytes,8000h
                    mov dsBufferDesc.lpwfxFormat, OFFSET Wave_Format

                .ENDIF

                com_invoke IDirectSound, CreateSoundBuffer, [esi].hDevice, ADDR dsBufferDesc, ADDR [ebx].pDirectSoundBuffer, 0
                .IF !eax

                    .IF [ebx].dwFlags & DIRECTSOUND_IS_PRIMARY

                        com_invoke IDirectSoundBuffer, SetFormat, [ebx].pDirectSoundBuffer, OFFSET Wave_Format
                        or eax, eax
                        jnz cant_set_format

                    .ENDIF

                    ;// the device is now opened

                    ;// make sure the buffer is cleared and appropriate flags are set

                    mov [ebx].cur_block, eax
                    and [ebx].dwFlags, NOT DIRECTSOUND_IS_STARTED

                    lea edi, [ebx].wave_data
                    mov ecx, SAMARY_LENGTH
                    rep stosd

                    jmp all_done    ;// done, return 0

            cant_set_format:

                    com_invoke IDirectSoundBuffer, Release, [ebx].pDirectSoundBuffer
                    xor eax, eax
                    mov [ebx].pDirectSoundBuffer, eax

                .ENDIF

            cant_set_coop_level:    ;// or cant create buffer

                com_invoke IDirectSound, Release, [esi].hDevice
                xor eax, eax
                mov [esi].hDevice, eax

            .ENDIF

            ;// if we hit this, mark as bad

            ;// or [esi].dwFlags, HARDWARE_BAD_DEVICE

            ;// and return non_zero

            or eax, -1
            jmp all_done

        .ENDIF


        ;// mmsys device

            ASSUME edi:PTR HARDWARE_DEVICEBLOCK

            ;// open the device

            invoke waveOutOpen, ADDR [edi].hDevice, [edi].ID, OFFSET Wave_Format,
                                play_hEvent, edi, CALLBACK_EVENT
            test eax, eax
            jnz all_done

        ;// this is for real, so we want to zero the data,
        ;// prepare the hdr and start playing

        ;// get the waveHdr ptr

            mov esi, [edi].pData
            ASSUME esi:PTR WAVEOUT_DATA

        ;// zero the wave data

            lea edi, [esi].waveData
            mov ecx, WAVEOUT_LENGTH
            ;//xor eax, eax         ;// eax is already zero
            rep stosd

        ;// prepare enough headers and add them

            mov edi, pDevice
            ASSUME edi:PTR HARDWARE_DEVICEBLOCK

            lea esi, [esi].waveHdr
            ASSUME esi:PTR WAVEHDR
            mov ebx, [edi].num_buffers
            .REPEAT

                mov [esi].dwFlags, 0
                invoke waveOutPrepareHeader, [edi].hDevice, esi, SIZEOF WAVEHDR

                .IF !eax
                    invoke waveOutWrite, [edi].hDevice, esi, SIZEOF WAVEHDR
                    H_LOG_TRACE <waveout_H_Open_WRITE_MM>
                .ENDIF

                add esi, SIZEOF WAVEHDR
                dec ebx

            .UNTIL ZERO?

            mov eax, ebx
            ;// eax is zero
            ;// we just exit

    all_done:

        ret

waveout_H_Open ENDP



ASSUME_AND_ALIGN
waveout_H_Close PROC STDCALL uses esi edi ebx pDevice:PTR HARDWARE_DEVICEBLOCK

    LOCAL retry:DWORD

    mov retry, 0

    H_LOG_TRACE <waveout_H_Close>

    ;// check for direct sound first

        mov edi, pDevice
        ASSUME edi:PTR HARDWARE_DEVICEBLOCK

        .IF [edi].dwFlags & HARDWARE_IS_DIRECTSOUND

                and [edi].dwFlags, NOT HARDWARE_BAD_DEVICE

                .IF [edi].hDevice

                    mov ebx, [edi].pData
                    ASSUME ebx:PTR DIRECTSOUND_DATA

                    .IF [ebx].pDirectSoundBuffer

                        .IF [ebx].dwFlags & DIRECTSOUND_IS_STARTED

                            com_invoke IDirectSoundBuffer, Stop, [ebx].pDirectSoundBuffer
                            ;// no error check: sometimes we will get buffer lost messages

                        .ENDIF

                        com_invoke IDirectSoundBuffer, Release, [ebx].pDirectSoundBuffer
                        xor eax, eax
                        mov [ebx].pDirectSoundBuffer, eax

                        and [ebx].dwFlags, NOT DIRECTSOUND_IS_STARTED
                        mov [ebx].cur_block, eax

                    .ENDIF

                    com_invoke IDirectSound, Release, [edi].hDevice
                    xor eax, eax
                    mov [edi].hDevice, eax

                .ENDIF


        .ELSE

        ;// here, we close the device and unprepare all headers

        try_again:

        ;// reset the port

            invoke waveOutReset, [edi].hDevice
            DEBUG_IF <eax>  ;// couldn't reset

        ;// unprepare and reset our headers

            mov esi, [edi].pData
            ASSUME esi:PTR WAVEOUT_DATA

            lea esi, [esi].waveHdr
            ASSUME esi:PTR WAVEHDR
            mov ebx, WAVEOUT_NUM_BUFFERS
            @@:

                .IF [esi].dwFlags & WHDR_PREPARED
                    invoke waveOutUnprepareHeader, [edi].hDevice, esi, SIZEOF WAVEHDR
                    .IF eax
                        .IF eax == 21h
                            inc retry
                            .IF retry < 10
                                invoke Sleep, 10
                                jmp try_again
                            .ENDIF
                            mov edx, [esi].dwFlags
                        .ENDIF
                        BOMB_TRAP   ;// couldn't reset
                    .ENDIF
                .ENDIF

                mov [esi].dwFlags, 0
                add esi, SIZEOF WAVEHDR
                dec ebx

            jnz @B

        ;// close the port and null the handle

            invoke waveOutClose, [edi].hDevice
            DEBUG_IF <eax>  ;// couldn't close

            mov [edi].hDevice, 0
            and [edi].dwFlags, NOT HARDWARE_BAD_DEVICE

        .ENDIF  ;// direct sound


    ;// that's it

        ret

waveout_H_Close ENDP





ASSUME_AND_ALIGN
waveout_H_Ready PROC STDCALL uses esi edi pDevBlock:PTR HARDWARE_DEVICEBLOCK

    ;// here, we want to return the ready flags depending on our buffer state
    ;// this is called about every 5ms by the play_Proc via hardware_Ready
    ;// make sure there are enough/not-to-many prepared headers

        LOCAL play:DWORD
        LOCAL write:DWORD

    ;// this is called by the play proc very often

        mov edi, pDevBlock
        ASSUME edi:PTR HARDWARE_DEVICEBLOCK

    .IF [edi].dwFlags & HARDWARE_IS_DIRECTSOUND

        mov ebx, [edi].pData
        ASSUME ebx:PTR DIRECTSOUND_DATA

        .IF [ebx].dwFlags & DIRECTSOUND_IS_STARTED

            com_invoke IDirectSoundBuffer, GetCurrentPosition, [ebx].pDirectSoundBuffer, ADDR play, ADDR write
            .IF !eax

                mov edx, write                  ;// get the write position (bytes)
                mov eax, [ebx].cur_block        ;// get the current block
                shr edx, LOG2(SAMARY_LENGTH*4)  ;// convert to frames
                inc edx                         ;// align forward
                .IF edx >= [ebx].num_blocks     ;// wrap ?
                    sub edx, [ebx].num_blocks   ;// make sure in range
                .ENDIF

                sub eax, edx    ;// subtract to get the difference in frames
                .IF SIGN?       ;// want positive only
                    neg eax
                .ENDIF

                .IF eax <= [edi].num_buffers        ;// compare with desired latency

                    ;// make sure current block does not overlap the play cursor

                    mov edx, play
                    shr edx, LOG2(SAMARY_LENGTH*4)  ;// convert to frames(align back)
                    .IF eax != edx

                        .IF ![ebx].latency  ;// dwFlags & DIRECTSOUND_NEED_LATENCY

                            ;// may need a count down for this

                            ;// compute the latency

                            mov edx, write              ;// write
                            sub edx, play               ;// write-play = samples
                            .IF SIGN?
                                neg edx
                            .ENDIF
                            push edx                    ;// store on stack
                            fld directsound_latency_scale   ;// load the scale
                            fild DWORD PTR [esp]        ;// load the number of samples
                            fmul                        ;// scale to milliseconds
                            fistp DWORD PTR [esp]       ;// store back on stack
                            pop edx                     ;// retrieve in edx
                            mov [ebx].latency, edx      ;// store in object

                        .ENDIF

                        H_LOG_TRACE <waveout_H_Ready_directsound>

                        mov eax, READY_BUFFERS
                        jmp all_done

                    .ENDIF

                .ENDIF

                ;// not ready yet

                mov eax, READY_DO_NOT_CALC
                jmp all_done

            .ENDIF  ;// couldn't read position

            mov eax, READY_MARK_AS_BAD
            jmp all_done

        .ENDIF  ;// not started yet

        H_LOG_TRACE <waveout_H_Ready_directsound_not_started>
        mov eax, READY_BUFFERS

    .ELSE   ;// not direct sound

        mov esi, [edi].pData
        ASSUME esi:PTR WAVEOUT_DATA

        lea ebx, [esi].waveHdr
        ASSUME ebx:PTR WAVEHDR

        mov ecx, MAX_SAMPLE_BUFFERS
        push ebp            ;// save ebp
        xor edx, edx        ;// edx counts prepared
        xor ebp, ebp        ;// ebp will store the pointer to the ready buffer

        .REPEAT

            mov eax, [ebx].dwFlags
            .IF eax & WHDR_PREPARED ;// check if this buffer is prepared

                inc edx                         ;// update the count of prepared

                ;// check if this buffer is ok to write to
                .IF (!(eax & WHDR_INQUEUE) || (eax & WHDR_DONE)) && !ebp

                    mov ebp, ebx            ;// store the pointer

                .ENDIF

            .ENDIF

            add ebx, SIZEOF WAVEHDR

        .UNTILCXZ

        ;// now we check if there the correct amount of buffers in the stew

        sub edx, [edi].num_buffers
        .IF SIGN?

            ;// not enough buffers
            ;// edx has the negtive amount of buffers to add

            lea ebx, [esi].waveHdr
            mov ecx, MAX_SAMPLE_BUFFERS
            .WHILE edx && ecx

                .IF !([ebx].dwFlags & WHDR_PREPARED)

                    push edx
                    push ecx

                    mov [ebx].dwFlags, 0            ;// reset the flags
                    invoke waveOutPrepareHeader, [edi].hDevice, ebx, SIZEOF WAVEHDR
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

                .IF ([ebx].dwFlags & WHDR_PREPARED) && !([ebx].dwFlags & WHDR_INQUEUE) && ebx!=ebp

                    push edx
                    push ecx

                    invoke waveOutUnprepareHeader, [edi].hDevice, ebx, SIZEOF WAVEHDR
                    DEBUG_IF <eax>  ;// couldn't unprepare
                    xor eax, eax
                    mov [ebx].dwFlags, eax

                    pop ecx
                    pop edx

                    dec edx

                .ENDIF

                add ebx, SIZEOF WAVEHDR
                dec ecx

            .ENDW

            ;// double check    edx==0 ?
            ;// no, sometimes this will take a few frames to catch up
            ;// so edx might not be zero

        .ENDIF

    ;// now we determime what to return

        xor eax, eax
        test ebp, ebp
        .IF !ZERO?
            mov eax, READY_BUFFERS
            H_LOG_TRACE <waveout_H_Ready_mmsystem>
        .ELSE
            mov eax, READY_DO_NOT_CALC
        .ENDIF
        mov [esi].pReady, ebp
        pop ebp

    .ENDIF  ;// direct sound

all_done:

    ;// that's it

        ret

waveout_H_Ready ENDP



;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
osc_Wave_Ctor PROC

        ;// register call

        ASSUME ebp:PTR LIST_CONTEXT ;// preserve
        ASSUME esi:PTR OSC_OBJECT   ;// preserve
        ASSUME edi:PTR OSC_BASE     ;// may destroy
        ASSUME ebx:PTR FILE_OSC     ;// may destroy
        ASSUME edx:PTR FILE_HEADER  ;// may destroy

    ;// we've been created
    ;// any data we have is loaded
    ;// so now all we have to do is get a device

        .IF edx                     ;// loading from file ??
            and [esi].dwUser, NOT WAVEOUT_CLIP  ;// turn off the previously clipping flag
            mov edx, [esi].dwUser   ;// get dwUser
            and edx, 0FFFFh         ;// mask out the number of buffers (leaves us with dev id)
        .ELSE                       ;// not loading from file
            mov edx, 0FFFFh         ;// use the default device
        .ENDIF

        invoke hardware_AttachDevice

    ;// set the num buffers, set the device id

        .IF eax     ;// make sure we found something

            ASSUME eax:PTR HARDWARE_DEVICEBLOCK

            mov ecx, [esi].dwUser   ;// get dwUser from osc

            mov cx, WORD PTR [eax].ID   ;// get the id from the device

            .IF ecx & WAVE_BUFFER_TEST  ;// is there a num_buffer loaded from file ??

                ;// use it, send num buffers to the device

                mov edx, ecx
                shr edx, WAVE_BUFFER_SHIFT
                and edx, 03Fh   ;// mask out the rest
                mov [eax].num_buffers, edx  ;// store in object

            .ELSE   ;// use default number of buffers

                mov edx, [eax].num_buffers
                shl edx, WAVE_BUFFER_SHIFT
                or ecx, edx

            .ENDIF

            mov [esi].dwUser, ecx

        .ENDIF

    ;// that's it

        ret

osc_Wave_Ctor ENDP



;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
waveout_Calc PROC

        ASSUME esi:PTR OSC_MAP

    ;// check for a device, if none, make sure we are marked as bad

    ;// get the prescribed buffer

        mov edi, [esi].pDevice
        ASSUME edi:PTR HARDWARE_DEVICEBLOCK

    .IF edi ;// anything ?
    .IF !([edi].dwFlags & HARDWARE_BAD_DEVICE)  ;// device OK ?

        ;// locate the output buffer to use

            .IF [edi].dwFlags & HARDWARE_IS_DIRECTSOUND

                mov edi, [edi].pData
                add edi, OFFSET DIRECTSOUND_DATA.wave_data

            .ELSE

                mov edi, [edi].pData        ;// get the wave data block
                ASSUME edi:PTR WAVEOUT_DATA

                mov ebx, [edi].pReady       ;// get the wave hdr pointer
                ASSUME ebx:PTR WAVEHDR

                and [ebx].dwFlags, NOT WHDR_DONE    ;// reset the wave flag

                mov edi, [ebx].pData                ;// load the data pointer

            .ENDIF

        ASSUME edi:PTR WORD

        ;// setup the bclip flag

            push ebp
            xor ebp, ebp

        ;// get our data pointers

            xor edx, edx
            xor ebx, ebx

            OR_GET_PIN [esi].pin_L.pPin, edx    ;// left input
            .IF !ZERO?
                mov edx, [edx].pData
            .ELSE
                mov edx, math_pNull
            .ENDIF

            OR_GET_PIN [esi].pin_R.pPin, ebx    ;// right input

            .IF !ZERO?
                mov ebx, [ebx].pData
            .ELSE
                mov ebx, math_pNull
            .ENDIF

            ASSUME edx:PTR DWORD
            ASSUME ebx:PTR DWORD

        ;// set up the scale to integer factor

            xor eax, eax
            fld math_32767;//waveOut_scale      ;// S

        ;// see if A is connected and changing

            OR_GET_PIN [esi].pin_A.pPin, eax    ;// is A connected

            .IF !ZERO?
            .IF [eax].dwStatus & PIN_CHANGING

        ;// the A pin is changing

            push esi

                xor ecx, ecx
                mov esi, [eax].pData
                ASSUME esi:PTR DWORD

                fnclex  ;// all this code relies on the exeptions being cleared

                .REPEAT

                    fld [esi+ecx*4]     ;// A   S
                    fmul st, st(1)      ;// AS  S

                    fabs

                    fld [edx+ecx*4]     ;// r   AS  S
                    fmul st, st(1)      ;// R   AS  S

                    fld [ebx+ecx*4]     ;// l   R   AS  S
                    fmulp st(2), st     ;// R   L   S

                    fistp [edi+ecx*4]   ;// L   S

                    xor eax, eax

                    fistp [edi+ecx*4+2] ;// S

                    fnstsw ax
                    .IF ax & 1          ;// over flow
                        inc ebp
                        test [edx+ecx*4], 80000000h
                        fnclex
                        jnz @F
                        dec [edi+ecx*4]
                    @@:
                        test [ebx+ecx*4], 80000000h
                        jnz @F
                        dec [edi+ecx*4+2]
                    @@:
                    .ENDIF

                    inc ecx

                .UNTIL ecx>=SAMARY_LENGTH

            pop esi
            ASSUME esi:PTR OSC_MAP

                jmp check_for_clipping

            .ENDIF


        ;// the A pin is NOT changing
        ;// eax is still the A source pin pointer

            mov eax, [eax].pData    ;// A is not changing, but is connected
            fmul DWORD PTR [eax]
            fabs

            .ENDIF  ;// A is not connected

        ;// S is loaded and we are ready to go

            stereo_float_to_stereo_16 PROTO     ;// used by media_writer.asm
            invoke stereo_float_to_stereo_16

        check_for_clipping:

            xor eax, eax            ;// clear for testing
            fstp st                 ;// clean out fpu
            or eax, [esi].dwHintOsc ;// test for on screen
            mov ebx, [esi].dwUser   ;// probably going to need this
            jns done_with_calc      ;// onscreen is the sign bit

        ;// determine our current clip state

            or ebp, ebp
            jnz yes_clipping_now

        not_clipping_now:

            ;// determine our previous clip state
            ;// and RESET the clipping flag

            btr ebx, LOG2(WAVEOUT_CLIP)
            jnc done_with_calc

        store_and_invalidate:

            mov [esi].dwUser, ebx       ;// store the new clipping flags
            invoke play_Invalidate_osc  ;// tag for redisplay
            jmp done_with_calc          ;// we're done now

        yes_clipping_now:

            ;// determine our previous clip state
            ;// and SET the clipping flag

            bts ebx, LOG2(WAVEOUT_CLIP)
            jnc store_and_invalidate    ;// jump if we didn't know we were clipping

    done_with_calc:

        pop ebp

    .ENDIF ;// bad device
    .ENDIF  ;// no device

    ;// that's it

        ret

waveout_Calc ENDP


ASSUME_AND_ALIGN
stereo_float_to_stereo_16 PROC


    ;// ebp must be zero (used as a clipping indicator)
    ;// fpu must have scaling factor

        ASSUME edx:PTR DWORD    ;// edx must point at left data     (preserved)
        ASSUME ebx:PTR DWORD    ;// ebx must point at right data    (preserved)
        ASSUME edi:PTR WORD     ;// edi must point at dest buffer   (preserved)

    ;// all this code relies on the exeptions being cleared

        fnclex
        xor ecx, ecx

    ;// we'll do two at a time

        .REPEAT
                                ;// S
            fld [edx+ecx*4]     ;// r0  S
            fmul st, st(1)      ;// R0  S
            fld [ebx+ecx*4]     ;// l0  R0  S
            fmul st, st(2)      ;// L0  R0  S

            fld [edx+ecx*4+4]   ;// r1  L0  R0  S
            fmul st, st(3)      ;// R1  L0  R0  S
            fld [ebx+ecx*4+4]   ;// l1  R1  L0  R0  S
            fmul st, st(4)      ;// L1  R1  L0  R0  S

            fxch st(3)          ;// R0  R1  L0  L1  S

            fistp [edi+ecx*4]   ;// R1  L0  L1  S
            xor eax, eax
            fxch                ;// L0  R1  L1  S
            fistp [edi+ecx*4+2] ;// R1  L1  S

            fnstsw ax

            .IF ax & 1      ;// overflow
                inc ebp
                test [edx+ecx*4], 80000000h
                fnclex
                jnz @F
                dec [edi+ecx*4]
            @@:
                test [ebx+ecx*4], 80000000h
                jnz @F
                dec [edi+ecx*4+2]
            @@:
            .ENDIF

                                ;// R1  L1  S
            fistp [edi+ecx*4+4] ;// L1  S
            xor eax, eax
            fistp [edi+ecx*4+6] ;// S

            fnstsw ax

            .IF ax & 1      ;// overflow
                inc ebp
                test [edx+ecx*4+4], 80000000h
                fnclex
                jnz @F
                dec [edi+ecx*4+4]
            @@:
                test [ebx+ecx*4+4], 80000000h
                jnz @F
                dec [edi+ecx*4+6]
            @@:
            .ENDIF

            add ecx, 2

        .UNTIL ecx>=SAMARY_LENGTH

        ret

stereo_float_to_stereo_16 ENDP



;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////




ASSUME_AND_ALIGN
waveout_H_Calc PROC STDCALL uses esi edi pDevice:PTR HARDWARE_DEVICEBLOCK

        LOCAL pPlay1:DWORD
        LOCAL bytes1:DWORD
        LOCAL pPlay2:DWORD
        LOCAL bytes2:DWORD

    mov esi, pDevice
    ASSUME esi:PTR HARDWARE_DEVICEBLOCK

    .IF [esi].dwFlags & HARDWARE_IS_DIRECTSOUND

        ;// write the buffer
        ;// advance the index

        mov ebx, pDevice
        ASSUME ebx:PTR HARDWARE_DEVICEBLOCK

        mov ebx, [ebx].pData
        ASSUME ebx:PTR DIRECTSOUND_DATA

        ;// write the data

            mov esi, [ebx].cur_block
            shl esi, LOG2(SAMARY_LENGTH*4)  ;// start address

            com_invoke IDirectSoundBuffer, LockBuffer, [ebx].pDirectSoundBuffer, esi, SAMARY_LENGTH*4, ADDR pPlay1, ADDR bytes1, ADDR pPlay2, ADDR bytes2, 0
            or eax, eax
            jnz device_is_bad

        ready_to_go:

            mov ecx, bytes1
            lea esi, [ebx].wave_data
            mov edi, pPlay1
            shr ecx, 2
            rep movsd

            com_invoke IDirectSoundBuffer, Unlock, [ebx].pDirectSoundBuffer, pPlay1, bytes1, pPlay2, bytes2

        ;// advance the cur_block

            mov eax, [ebx].cur_block
            inc eax
            .IF eax >= [ebx].num_blocks
                xor eax, eax
            .ENDIF
            mov [ebx].cur_block, eax

        ;// make sure we start on time

            .IF !([ebx].dwFlags & DIRECTSOUND_IS_STARTED)

                mov ecx, pDevice
                ASSUME ecx:PTR HARDWARE_DEVICEBLOCK
                .IF eax >= [ecx].num_buffers

                    com_invoke IDirectSoundBuffer, Play, [ebx].pDirectSoundBuffer, 0,0,DSBPLAY_LOOPING
                    or [ebx].dwFlags, DIRECTSOUND_IS_STARTED

                .ENDIF

            .ENDIF

            H_LOG_TRACE <waveout_WRITE_directsound>

            jmp all_done

        ;// this is hit when we cant lock the buffer

    device_is_bad:

        cmp eax, DSERR_BUFFERLOST
        jne all_done

        com_invoke IDirectSoundBuffer, Restore, [ebx].pDirectSoundBuffer
        or eax, eax
        jnz all_done

        com_invoke IDirectSoundBuffer, LockBuffer, [ebx].pDirectSoundBuffer, esi, SAMARY_LENGTH*4, ADDR pPlay1, ADDR bytes1, ADDR pPlay2, ADDR bytes2, 0
        or eax, eax
        jz ready_to_go
        jmp all_done

    .ENDIF  ;// not direct sound

        ASSUME esi:PTR HARDWARE_DEVICEBLOCK

        mov edi, [esi].pData
        ASSUME edi:PTR WAVEOUT_DATA

        mov ebx, [edi].pReady
        ASSUME ebx:PTR WAVEHDR

        .IF [ebx].dwFlags & WHDR_PREPARED

            H_LOG_TRACE <waveout_WRITE_mmsystem>

            invoke waveOutWrite, [esi].hDevice, ebx, SIZEOF WAVEHDR
            DEBUG_IF<eax>

        .ENDIF

all_done:

    xor eax, eax

    ret

waveout_H_Calc ENDP


;////////////////////////////////////////////////////////////////////
;//
;//
;//     waveout_Render
;//
ASSUME_AND_ALIGN
waveout_Render PROC

    invoke gdi_render_osc

    ASSUME esi:PTR OSC_OBJECT

        .IF [esi].dwUser & WAVEOUT_CLIP

            push edi
            push ebx
            push esi

            mov eax, F_COLOR_OSC_BAD
            OSC_TO_CONTAINER esi, ebx
            OSC_TO_DEST esi, edi        ;// get the destination
            mov ebx, [ebx].shape.pMask
            invoke shape_Fill

            pop esi
            pop ebx
            pop edi

        .ENDIF

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

waveout_Render ENDP


.DATA

    latency_table   LABEL DWORD

    dd  23,     46,     70,     93,     116,    139,    162,    185
    dd  209,    232,    255,    278,    302,    325,    348,    371
    dd  394,    418,    441,    464,    487,    510,    534,    557
    dd  580,    603,    627,    650,    673,    696,    719,    743

    szf_buffers     db  '%i',0
    szf_latency_yes db  '%ims',0
    szf_latency_no  db  '%i+??ms',0

.CODE


;///////////////////////////////////////////////////////////////////////////
;//
;//     INIT_MENU
;//
;//
;// called from popup_Show
ASSUME_AND_ALIGN
osc_Wave_InitMenu PROC

        ASSUME esi:PTR OSC_OBJECT

        .IF [esi].pDevice

        ;// derive the number of buffers

            sub esp, 32                 ;// make some room for text

            mov ebx, [esi].dwUser
            and ebx, WAVE_BUFFER_TEST
            shr ebx, 16                 ;// ebx is number of buffers

            mov eax, esp
            mov edx, OFFSET szf_buffers
            invoke wsprintfA, eax, edx, ebx

            invoke GetDlgItem, popup_hWnd, ID_WAVE_BUFFERS
            WINDOW eax, WM_SETTEXT,0,esp

        ;// determine the maximum latency

            dec ebx                             ;// latency table is zero based
            mov ecx, [esi].pDevice              ;// get the device ptr
            mov ebx, latency_table[ebx*4]       ;// load the latency base
            mov edx, OFFSET szf_latency_yes ;// load most common format value

            ASSUME ecx:PTR HARDWARE_DEVICEBLOCK

            .IF [ecx].dwFlags & HARDWARE_IS_DIRECTSOUND         ;// direct sound must display more text
                mov ecx, [ecx].pData                            ;// get the DIRECTSOUND_DATA
                ASSUME ecx:PTR DIRECTSOUND_DATA
                .IF !([ecx].latency)    ;// dwFlags & DIRECTSOUND_HAS_LATENCY)  ;// see if we've measured this yet
                    mov edx, OFFSET szf_latency_no          ;// load other value if not
                .ENDIF
                add ebx, [ecx].latency
            .ENDIF

            mov eax, esp                        ;// need for next call
            invoke wsprintfA, eax, edx, ebx     ;// build the formatted text

            invoke GetDlgItem, popup_hWnd, ID_WAVE_LATENCY  ;// get the window handle
            WINDOW eax, WM_SETTEXT,0,esp                    ;// set the text

            add esp, 32     ;// clean up the stack

        ;// make sure we can not decrease to zero

            mov ebx, [esi].dwUser
            and ebx, WAVE_BUFFER_TEST
            shr ebx, 16                 ;// ebx is number of buffers

            invoke GetDlgItem, popup_hWnd, ID_WAVE_LESS
            cmp ebx, 1
            mov ecx, 1
            jne @F
                dec ecx
            @@:
            invoke EnableWindow, eax, ecx

        ;// make sure we cannot increase passed the maximum

            invoke GetDlgItem, popup_hWnd, ID_WAVE_MORE

            mov edx, [esi].pDevice
            ASSUME edx:PTR HARDWARE_DEVICEBLOCK
            .IF [edx].dwFlags & HARDWARE_IS_DIRECTSOUND

                mov edx, [edx].pData
                mov edx, (DIRECTSOUND_DATA PTR [edx]).num_blocks
                dec edx

            .ELSE

                mov edx, MAX_SAMPLE_BUFFERS

            .ENDIF

            cmp ebx, edx
            mov ecx, 1
            jne @F
                dec ecx
            @@:
            invoke EnableWindow, eax, ecx

        ;// set the title of the device

            invoke GetDlgItem, popup_hWnd, ID_WAVE_NAME
            mov edx, [esi].pDevice
            add edx, OFFSET HARDWARE_DEVICEBLOCK.szName
            WINDOW eax, WM_SETTEXT, 0, edx

        .ELSE   ;// no device

            invoke GetDlgItem, popup_hWnd, ID_WAVE_NAME
            mov edx, OFFSET sz_Not_space_Assigned
            WINDOW eax, WM_SETTEXT,0,edx

            invoke GetDlgItem, popup_hWnd, ID_WAVE_BUFFERS
            WINDOW eax, WM_SETTEXT,0,0

            invoke GetDlgItem, popup_hWnd, ID_WAVE_MORE
            invoke EnableWindow, eax, 0
            invoke GetDlgItem, popup_hWnd, ID_WAVE_LESS
            invoke EnableWindow, eax, 0

        .ENDIF  ;// have a device

    ;// add items and set their state

        invoke GetDlgItem, popup_hWnd, ID_WAVE_LIST
        mov ebx, eax
        invoke hardware_FillInDeviceList

    ;// that's it, return zero

        xor eax, eax

        ret

osc_Wave_InitMenu ENDP
;//
;//     INIT_MENU
;//
;//
;///////////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
wave_ChangeDevice PROC

    ASSUME esi:PTR OSC_OBJECT
    ASSUME ecx:PTR HARDWARE_DEVICEBLOCK

    ;// change the device using the hardware function

        invoke hardware_ReplaceDevice, ecx

    ;// now we need to get the number of buffers from the device

        mov ebx, [esi].pDevice      ;// get the device
        ASSUME ebx:PTR HARDWARE_DEVICEBLOCK

        .IF ebx ;// make sure we're dealing with a valid device

            mov ecx, [esi].dwUser       ;// get osc.dwuser
            mov eax, [ebx].num_buffers  ;// get the number of buffers
            and ecx, WAVE_BUFFER_MASK   ;// strip out old number of buffers
            shl eax, WAVE_BUFFER_SHIFT  ;// scoot new num buffers into place
            or ecx, eax                 ;// merge new on to old
            mov [esi].dwUser, ecx       ;// store back in object

        .ENDIF

    ;// that should do it

        ret

wave_ChangeDevice ENDP




;///////////////////////////////////////////////////////////////////////////
;//
;//
;//     osc_Wave_Command        shared by waveIn and waveOut
;//
ASSUME_AND_ALIGN
osc_Wave_Command PROC

    ASSUME esi:PTR OSC_OBJECT   ;// must preserve
    ASSUME edi:PTR OSC_BASE     ;// may destroy
    DEBUG_IF <edi!!=[esi].pBase>

    ;// eax has the command
    ;// exit by returning popup_flags in eax
    ;// or by jumping to osc_sommand

;////// num buffers

        cmp eax, ID_WAVE_MORE
        jne @F

        mov edx, [esi].dwUser
        and edx, WAVE_BUFFER_TEST
        add edx, WAVE_BUFFER_1
        jmp set_buffers

    @@: cmp eax, ID_WAVE_LESS
        jne @F

        mov edx, [esi].dwUser
        and edx, WAVE_BUFFER_TEST
        sub edx, WAVE_BUFFER_1
        DEBUG_IF <ZERO?>    ;// not supposed to happen

    set_buffers:

        ;// edx_hi has new number of buffers
        ;// we need to store in osc and in device

        mov ecx, [esi].dwUser
        and ecx, WAVE_BUFFER_MASK
        or ecx, edx
        mov [esi].dwUser, ecx

        mov edi, [esi].pDevice      ;// get the dev block pointer
        .IF edi

            shr edx, WAVE_BUFFER_SHIFT
            mov (HARDWARE_DEVICEBLOCK PTR [edi]).num_buffers, edx   ;// store the new number

        .ENDIF

        mov eax, POPUP_SET_DIRTY OR POPUP_INITMENU  ;// set the return flags

        ret                             ;// exit


;////// device change

    @@: cmp eax, OSC_COMMAND_LIST_DBLCLICK
        jne osc_Command

    ;// the currently selected item's private dword is passed in ecx

        invoke wave_ChangeDevice

    ;// and split

        mov eax, POPUP_SET_DIRTY OR POPUP_INITMENU OR POPUP_REDRAW_OBJECT OR POPUP_KILL_THIS_FOCUS
        ret



osc_Wave_Command ENDP
;//
;//     COMMAND
;//
;//
;///////////////////////////////////////////////////////////////////////////





;////////////////////////////////////////////////////////////////////
;//
;//
;//     _SaveUndo
;//

ASSUME_AND_ALIGN
wave_SaveUndo   PROC

        ASSUME esi:PTR OSC_OBJECT

    ;// edx enters as either UNREDO_CONTROL_OSC or UNREDO_COMMAND
    ;// edi enters as where to store
    ;//
    ;// task:   1) save nessary data
    ;//         2) iterate edi
    ;//
    ;// may use all registers except ebp


    ;// for devices, we save dwUser AND the device pointer

        mov eax, [esi].dwUser
        stosd
        mov eax, [esi].pDevice
        stosd

        ret

wave_SaveUndo ENDP
;//
;//
;//     _SaveUndo
;//
;////////////////////////////////////////////////////////////////////

;////////////////////////////////////////////////////////////////////
;//
;//
;//     _LoadUndo
;//

ASSUME_AND_ALIGN
wave_LoadUndo PROC

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
        btr eax, LOG2(WAVEOUT_CLIP)
        mov [esi].dwUser, eax
        .IF CARRY?
            or [esi].dwHintI, HINTI_OSC_LOST_BAD
        .ENDIF

        mov eax, [esi].pDevice  ;// get the device
        mov ecx, [edi+4]        ;// get the new device pointer

        .IF eax != ecx      ;// different device ??

            invoke wave_ChangeDevice

        .ENDIF

    ;// that should do it

        ret

wave_LoadUndo ENDP

;//
;//
;//     _LoadUndo
;//
;////////////////////////////////////////////////////////////////////






ASSUME_AND_ALIGN

ENDIF   ;// USE_THIS_FILE
END




