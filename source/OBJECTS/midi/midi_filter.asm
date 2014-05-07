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
;// midi_filter.asm
;//
OPTION CASEMAP:NONE
.586
.MODEL FLAT

    .NOLIST
    INCLUDE <ABox.inc>
    INCLUDE <midi2.inc>
    .LIST


.DATA

.CODE

ASSUME_AND_ALIGN
PROLOGUE_OFF
stream_filter PROC STDCALL USES esi edi ebx ebp pIStream:DWORD, pOStream:DWORD, pFStream:DWORD, pFilter:DWORD
                ;// 00                             04               08              0C              10h

    ;// always clear the passed streams

        mov ecx, [esp+8]    ;// get the o stream
        xor eax, eax
        mov edx, [esp+12]   ;// get the f stream

        midistream_Reset (MIDI_STREAM PTR [ecx])
        midistream_Reset (MIDI_STREAM PTR [edx])

    ;// get the input stream and check if it's empty, eax is still zero

        xchg esi, [esp+4]       ;// get the input stream
        ASSUME esi:PTR MIDI_STREAM  ;// input stream

        midistream_IterBegin [esi], eax, all_done_esi

    ;// prepare the stack

        xchg ebp, [esp+10h] ;// get the filter, store ebp
        ASSUME ebp:PTR MIDI_FILTER  ;// midi filter

        push ebx    ;// preserve
        push edi    ;// preserve

        ;// edi ebx ret pIStream pOStream pFStream pFilter
        ;//              esi                        ebp
        ;// 00   04  08  0C      10h      14h      18h

        st_o_stream TEXTEQU <(DWORD PTR [esp+10h])>
        st_f_stream TEXTEQU <(DWORD PTR [esp+14h])>

        mov ebx, eax    ;// index of first event
        xor ecx, ecx    ;// ecx will be byte register

    top_of_filter:  ;// assume it's ok to be here

    ;// this filter works by pointing edi at which array to store
    ;// accepted commands go to st_f_stream
    ;// rejected commands go to st_o_stream
    ;// abort at first error

    ;// make sure this is an event

        cmp [esi+ebx*8].bias, MIDI_BIAS
        jne done_with_filter    ;// abort at first error

    ;// check the status + channel values

        xor eax, eax            ;// no stalls here
        mov cl, [esi+ebx*8].status  ;// get the staus byte
        mov edx, [ebp].status   ;// get the status filter

        ;// channel bits

        mov edi, st_o_stream    ;// assume rejected for now
        mov al,cl               ;// get the status plus channel
        and eax, 0Fh            ;// max channel is 15
        bt  edx, eax            ;// test the status bit
        jnc store_command       ;// reject if not set

        ;// status bits

        xor eax, eax
        mov al, cl              ;// get the status plus channel
        shr eax, 4              ;// scoot high to lo
        add eax, 8              ;// converts 09h into 11h
        test eax, 10h           ;// check for bad status bytes
        jz  done_with_filter    ;// abort at first error
        bt  edx, eax            ;// test the filter bit
        jnc store_command       ;// reject if not set

        ;// check for note and controller tests
        mov edi, st_f_stream    ;// assume accepted for now
        cmp eax, 13h            ;// 10 = note off, 11=note on, 12=pressure, 13=controller
        ja store_command        ;// accept if not note or channel command

        ;// test the number filter
        xor eax, eax
        mov al, [esi+ebx*8].number  ;// get number from source
        mov edx, eax            ;// xfer to edx
        and eax, 11111y         ;// max 32 bits
        shr edx, 5              ;// edx is now a dword index
        bt  [ebp].number[edx*4], eax    ;// test the filter
        jc  store_command       ;// accept if bit is on

        ;// rejected
        mov edi, st_o_stream

    store_command:

        ASSUME edi:PTR MIDI_STREAM
        ;// edi points at destination array
        ;// ebx has index

    ;// add a new event

        midistream_Append [edi], ebx

    ;// xfer the event

        mov eax, [esi+ebx*8].evt
        mov [edi+ebx*8].evt, eax

    next_input_event:

        midistream_IterNext [esi], ebx, top_of_filter

    done_with_filter:

        pop edi ;// preserve
        pop ebx ;// preserve
        xchg ebp, [esp+10h] ;// get the filter, store ebp

    all_done_esi:

        xchg esi, [esp+4]       ;// get the input stream

        ret 10h

stream_filter ENDP
PROLOGUE_ON





ASSUME_AND_ALIGN
END