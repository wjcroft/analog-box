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
;///////////////////////////////////////////////////////////////////////////
;////
;////
;////   W A V E
;////

    ;// functions shared by both waveIn and waveOut

        osc_Wave_H_Dtor PROTO STDCALL pDevBlock:PTR HARDWARE_DEVICEBLOCK
        osc_Wave_Dtor PROTO STDCALL pObject:PTR OSC_OBJECT

        osc_Wave_Ctor PROTO

        osc_Wave_InitMenu PROTO ;//  STDCALL pObject:PTR OSC_OBJECT
        osc_Wave_Command PROTO ;// STDCALL pObject:PTR OSC_OBJECT, cmdID:DWORD

        wave_SaveUndo   PROTO
        wave_LoadUndo   PROTO


    WAVE_DEFAULT_BUFFERS            EQU 12
    DIRECTSOUND_DEFAULT_BUFFERS     EQU 1
    DIRECTSOUND_SECONDARY_BLOCKS    EQU 8   ;// make buffers 8 blocks

    WAVE_BUFFER_1       EQU  00010000h  ;// one wave buffer

    WAVE_BUFFER_SHIFT   EQU  16
    WAVE_BUFFER_TEST    EQU  003F0000h  ;// where num buffers is stored in osc.dwUser
    WAVE_BUFFER_MASK    EQU  NOT WAVE_BUFFER_TEST

    WAVE_ID_MASK        EQU 0FFFF0000h  ;// ID is stored in lower word

    EXTERNDEF Wave_Format:WAVEFORMATEX  ;// defined in ABox_WavOut.asm

    ;// pDirectSound is stored in hDevice

    DIRECTSOUND_DATA STRUCT

        pDirectSoundBuffer  dd  0
        guid    GUID    {}

        num_blocks  dd  0
        cur_block   dd  0
        dwFlags     dd  0   ;// see below
        latency     dd  0   ;// in samples ??

        wave_data   dd SAMARY_LENGTH DUP (0)

    DIRECTSOUND_DATA ENDS

    DIRECTSOUND_IS_STARTED      EQU 00000001h   ;// the device is started
    DIRECTSOUND_IS_PRIMARY      EQU 00000002h   ;// this is a primary buffer

