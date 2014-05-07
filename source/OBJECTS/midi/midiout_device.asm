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
;// midiout_device.asm      H functions for MidiOut object
;//                         new for ABox 220
;// TOC
;//
;// midiout_H_Ctor
;// midiout_H_Dtor
;// midiout_H_Open
;// midiout_H_Close
;// midiout_H_Ready
;// midiout_H_Calc

;// midiout_WriteInStream

OPTION CASEMAP:NONE
.586
.MODEL FLAT

    .NOLIST
    INCLUDE <abox.inc>
    INCLUDE <midi2.inc>

.DATA


    ;///////////////////////////////////////////////////////////////////////////////////////////////////


    ;// H_ready simply queries the dwFlags of midiHdr and looks for done

    ;// abox225 we'll double that with a callback that resets the bit


;// bug hunt

;//USE_MLOG EQU 1   ;// REM this to shut off log

    IFDEF USE_MLOG
    ECHO Hey! USE_MLOG is on !!

            mlog    dd  0   ;// file handle

            sz_mlog                 db 'c:\windows\desktop\mlog.txt',0
            sz_mlog_write_header    db 'write_stream--------------',0dh, 0ah, 0
            sz_mlog_in_header       db 'in_stream-----------------',0dh, 0ah, 0
            sz_mlog_out_header      db 'out_stream----------------',0dh, 0ah, 0
            sz_mlog_format          db '    %3.3X %i %8.8X',0dh, 0ah, 0 ;// i should always be zero
            mlog_buffer     db 64 DUP (0) ;// text buffer
            ALIGN 4

        dump_OpenMLog   PROTO
        dump_CloseMLog  PROTO
        dump_InStream   PROTO   STDCALL pDevice:DWORD
        dump_OutStream  PROTO   STDCALL pDevice:DWORD
        dump_WriteStream PROTO

    ENDIF




.CODE


;/////////////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////////////
;////
;////
;////   _H_ stuff
;////


ASSUME_AND_ALIGN
midiout_H_Ctor PROC

    ;// here we fill in our dev blocks and allocate the headers and devices

        invoke about_SetLoadStatus

    ;// get the number of devices

        xor ebx, ebx
        invoke midiOutGetNumDevs
        or ebx, eax     ;// ebx now holds the device count
        jz all_done

    ;// prepare a place to store device capabilities

        push esi    ;// need to preserve
        sub esp, SIZEOF MIDIOUTCAPS
        st_moCaps TEXTEQU <(MIDIOUTCAPS PTR [esp])>

    ;// loop through each device

        top_of_device_loop:

            dec ebx
            js done_with_devices

        ;// assume we can use this

            slist_AllocateHead hardwareL, edi, SIZEOF MIDIOUT_HARDWARE_DEVICEBLOCK
            ASSUME edi:PTR MIDIOUT_HARDWARE_DEVICEBLOCK

            mov [edi].ID, ebx                   ;// store the ID
            mov [edi].pBase, OFFSET osc_MidiOut2;// set the base class
            or [edi].dwFlags, HARDWARE_SHARED   ;// set as shared

        ;// get and xfer the name

            mov edx, esp
            invoke midiOutGetDevCapsA, ebx, edx, SIZEOF MIDIOUTCAPS

            invoke lstrcpyA, ADDR [edi].szName, ADDR st_moCaps.szPname
            lea eax, st_moCaps.szPname
            LISTBOX about_hWnd_device, LB_ADDSTRING, 0, eax
            lea eax, st_moCaps.szPname
            WINDOW about_hWnd_load, WM_SETTEXT, 0, eax

        ;// fill in the midi headers

            lea esi, [edi].frame
            ASSUME esi:PTR MIDIOUT_FRAME

            mov ecx, MIDIOUT_NUM_BUFFERS
            .REPEAT

                lea edx, [esi].hdr      ;// get the header
                ASSUME edx:PTR MIDIHDR

                lea eax, [esi].out_stream   ;// get the stream data
                add esi, SIZEOF MIDIOUT_FRAME   ;// iterate
                mov [edx].dwUser, edi           ;// point at device block
                dec ecx
                mov [edx].pData, eax            ;// save in the header

            .UNTIL ZERO?

            jmp top_of_device_loop  ;// iterate to the next device block

    done_with_devices:

        add esp, SIZEOF MIDIOUTCAPS
        st_moCaps TEXTEQU <>
        pop esi

    ;// bug hunt ///////
    IFDEF USE_MLOG
        invoke dump_OpenMLog
    ENDIF
    ;// bug hunt ///////


    all_done:

    ;// that's it


        ret

midiout_H_Ctor ENDP


ASSUME_AND_ALIGN
midiout_H_Dtor PROC ;// STDCALL pDevBlock:PTR MIDIOUT_HARDWARE_DEVICEBLOCK

    ;// nothing to do

    ;// bug hunt ///////
    IFDEF USE_MLOG
        invoke dump_CloseMLog
    ENDIF
    ;// bug hunt ///////


        ret 4   ;// STDCALL 1 arg

midiout_H_Dtor ENDP



ASSUME_AND_ALIGN
midiout_H_Open PROC STDCALL uses esi edi pDevice:PTR MIDIOUT_HARDWARE_DEVICEBLOCK

        LOCAL midiProp:MIDIPROPTIMEDIV

    ;// as per the hardware device spec, we return non zero if we can not open this
    ;// and zero if we can

        mov edi, pDevice
        ASSUME edi:PTR MIDIOUT_HARDWARE_DEVICEBLOCK

        DEBUG_IF <[edi].hDevice>    ;// already opened !!

    ;// open the stream

        invoke midiStreamOpen, ADDR [edi].hDevice, ADDR [edi].ID, 1, 0, edi, CALLBACK_NULL
        test eax, eax
        jnz all_done

    ;// opened just fine

    ;// we're not playing yet, so this is a good time to set the properties

        mov midiProp.dwSize, SIZEOF MIDIPROPTIMEDIV

        mov midiProp.dwTimeDiv, MIDI_DIVI
        invoke midiStreamProperty, [edi].hDevice, ADDR midiProp, MIDIPROP_SET + MIDIPROP_TIMEDIV
        test eax, eax
        jnz bad_device_stream

        mov midiProp.dwTimeDiv, MIDI_TICK
        invoke midiStreamProperty, [edi].hDevice, ADDR midiProp, MIDIPROP_SET + MIDIPROP_TEMPO
        test eax, eax
        jnz bad_device_stream

    ;// prepare our local header flags

        mov [edi].pReady, 0     ;// reset the ready pointer

    ;// get the first midi frame

        lea esi, [edi].frame
        ASSUME esi:PTR MIDIOUT_FRAME

    ;// prepare enough headers
    ;// ther's only two

            .ERRNZ MIDIOUT_NUM_BUFFERS-2, <code assume there are only two>

        ;// buffer 1

            lea edx, [esi].hdr  ;// hdr
            ASSUME edx:PTR MIDIHDR

            mov [edx].dwFlags, MHDR_ISSTRM
            mov [edx].dwBufferLength, SIZEOF MIDIOUT_FRAME.out_stream
            invoke midiOutPrepareHeader, [edi].hDevice, edx, SIZEOF MIDIHDR
            test eax, eax
            jnz bad_device_stream       ;// could not prepare

        ;// buffer 2

            add esi, SIZEOF MIDIOUT_FRAME

            lea edx, [esi].hdr

            mov [edx].dwFlags, MHDR_ISSTRM
            mov [edx].dwBufferLength, SIZEOF MIDIOUT_FRAME.out_stream
            invoke midiOutPrepareHeader, [edi].hDevice, edx, SIZEOF MIDIHDR
            or eax, eax
            jnz bad_device_prepare      ;// could not prepare

    ;// start playing

        invoke midiStreamRestart, [edi].hDevice
        test eax, eax
        jz all_done

    bad_device_play:

        ;// need to unprepare buffer 2

        lea edx, [esi].hdr
        invoke midiOutUnprepareHeader, [edi].hDevice, edx, SIZEOF MIDIHDR
        sub esi, SIZEOF MIDIOUT_FRAME

    bad_device_prepare:

        ;// need to unprepare 1

        lea edx, [esi].hdr
        invoke midiOutUnprepareHeader, [edi].hDevice, edx, SIZEOF MIDIHDR
        DEBUG_IF <eax>  ;// couldn't unprepare

    bad_device_stream:

        ;// need to close the stream

        invoke midiStreamClose, [edi].hDevice
        DEBUG_IF <eax>  ;// couldn't close
        not eax         ;// return bad

    all_done:

    ;// that's it

        ret

midiout_H_Open ENDP



ASSUME_AND_ALIGN
midiout_H_Close PROC STDCALL uses esi edi pDevice:PTR MIDIOUT_HARDWARE_DEVICEBLOCK

    ;// here, we close the device, and unprepare all the headers

        mov edi, pDevice
        ASSUME edi:PTR MIDIOUT_HARDWARE_DEVICEBLOCK

        invoke midiOutReset, [edi].hDevice
        DEBUG_IF <eax>  ;// couldn't reset

        mov [edi].pReady, 0

        lea esi, [edi].frame
        ASSUME esi:PTR MIDIOUT_FRAME

        mov ebx, MIDIOUT_NUM_BUFFERS
        .REPEAT

            lea edx, [esi].hdr
            ASSUME edx:PTR MIDIHDR
            .IF [edx].dwFlags & WHDR_PREPARED

                invoke midiOutUnprepareHeader, [edi].hDevice, edx, SIZEOF MIDIHDR
                DEBUG_IF <eax>  ;// couldn't unprepare

            .ENDIF
            lea edx, [esi].hdr
            mov [edx].dwFlags, 0

            add esi, SIZEOF MIDIOUT_FRAME
            dec ebx

        .UNTIL ZERO?

    ;// then we close the device

        invoke midiStreamClose, [edi].hDevice
        DEBUG_IF <eax>  ;// couldn't close

        mov [edi].hDevice, eax
        and [edi].dwFlags, NOT HARDWARE_BAD_DEVICE

    ;// that's it

        ret

midiout_H_Close ENDP


ASSUME_AND_ALIGN
midiout_H_Ready PROC ;// STDCALL uses esi edi ebx pDevBlock:PTR MIDIOUT_HARDWARE_DEVICEBLOCK

    ;// for this incarnation, we poll the done status of each frame
    ;// and set pReady to the first one we find
    ;// we're looking for empty, or done, but not in_que
    ;// we'll check the previous frame first

        xchg edi, [esp+4]   ;// pDevBlock
        ASSUME edi:PTR MIDIOUT_HARDWARE_DEVICEBLOCK

        .IF [edi].pReady                    ;// we're ready now from the previous frame
            mov eax, READY_BUFFERS
        .ELSE
            lea edx, [edi].frame            ;// load the start of the frames
            ASSUME edx:PTR MIDIOUT_FRAME
            mov ecx, MIDIOUT_NUM_BUFFERS    ;// load the number of buffers
            .REPEAT

                lea ebx, [edx].hdr  ;// get the hdr
                ASSUME ebx:PTR MIDIHDR

                .IF !([ebx].dwFlags & MHDR_INQUEUE) || ([ebx].dwFlags & MHDR_DONE)  ;// is it in the que
                                                        ;// added ABox225, attempt to unstick WinNT
                    mov [ebx].dwFlags, MHDR_ISSTRM + MHDR_PREPARED  ;// reset the flags
                    mov [edi].pReady, edx   ;// set the pReady pointer with this frame

                    mov eax, READY_BUFFERS  ;// return true
                    jmp all_done

                .ENDIF

                add edx, SIZEOF MIDIOUT_FRAME
                dec ecx

            .UNTIL ZERO?

        ;// if we get here, we found nothing that was ready

            mov eax, READY_DO_NOT_CALC

        .ENDIF

    all_done:   ;// that's it

        xchg edi, [esp+4]   ;// pDevBlock

        ret 4   ;// STDCALL 1 arg

midiout_H_Ready ENDP





ASSUME_AND_ALIGN
midiout_H_Calc PROC ;// STDCALL uses esi edi pDevice:PTR MIDIOUT_HARDWARE_DEVICEBLOCK

    ;// may use all registers except esi ebp

    ;// tasks:

    ;// get output stream
    ;// reset bytes recorded
    ;// pack in_stream into out_stream
    ;// advance bytes recorded
    ;// insert a timming nop as the last event
    ;// reset in_stream

    ;// get pointers

        xchg esi, [esp+4]           ;// get the device block and preserve esi
        ASSUME esi:PTR MIDIOUT_HARDWARE_DEVICEBLOCK

    ;// bug hunt
    IFDEF USE_MLOG
        invoke dump_InStream, esi
    ENDIF
    ;// bug hunt

        push ebp                    ;// preserve ebp

        mov edi, [esi].pReady       ;// get the destination frame
        ASSUME edi:PTR MIDIOUT_FRAME
        DEBUG_IF <!!edi>            ;// supposed to work !!

        lea ebp, [edi].out_stream   ;// iterator for the out stream
        ASSUME ebp:PTR MIDISHORTEVENT

    ;// helpful text equates

        in_strm     TEXTEQU <[esi].in_stream>
        out_header  TEXTEQU <[edi].hdr>
        ptr_out     TEXTEQU <ebp>
        out_strm    TEXTEQU <[ptr_out]>

    ;// last_event  ebx     ;// index of last stored event, sets the delta

        or ebx, -1      ;// start at previous sample
        xor ecx, ecx    ;// ecx iterates the stream
        mov out_header.dwBytesRecorded, ecx ;// reset
        ;// we'll use bytes recorded first as a counter
        ;// then multiply by 3 when we're done

    ;// rip through the stream

        midistream_IterBegin in_strm, ecx, done_with_in_stream

    IFDEF DEBUGBUILD
        pushd 512
    ENDIF

    top_of_in_stream:

    IFDEF DEBUGBUILD
        dec DWORD PTR [esp]
        DEBUG_IF <SIGN?>    ;// too many events in stream ??
    ENDIF

    ;// determine the delta

        mov edx, ecx    ;// this index
        sub edx, ebx    ;// - last index = delta
        mov ebx, ecx    ;// set new last index

        DEBUG_IF <ZERO?>    ;// got zero delta !!

        DEBUG_IF <SIGN?>    ;// got negative delta !!

    ;// build the event

        mov eax, in_strm[ecx*8].evt     ;// bs  cmd N   V
        bswap eax                       ;// V   N   cmd bs
        shr eax, 8                      ;// 0   V   N   cmd
        ;// or eax, MEVT_SHORTMSG   ;// == 0, don't bother

    ;// store results in object, advance out_stream

        mov out_strm.dwDeltaTime, edx
        mov out_strm.dwEvent, eax
        add ptr_out, SIZEOF MIDISHORTEVENT
        inc out_header.dwBytesRecorded

    ;// iterate to next input event

        midistream_IterNext in_strm, ecx, top_of_in_stream

    IFDEF DEBUGBUILD
        pop eax
    ENDIF

    ;// now we've xferred the stream
    done_with_in_stream:

    ;// store the final NOP

        ;// ebx has the index of the last event we stored
        ;// we want the delta required to get to the last sample
        ;// 511-ebx

        sub ebx, MIDIEVENTS_PER_FRAME-1
        .IF !ZERO?  ;// we get zero if the frame was full

            DEBUG_IF <!!SIGN?>  ;// supposed to be a negative value !!

            ;// need to store this nop
            neg ebx
            DEBUG_IF <ebx !> MIDIEVENTS_PER_FRAME>  ;// delta is too big !!
            mov out_strm.dwEvent, MEVT_NOP
            mov out_strm.dwDeltaTime, ebx
            inc out_header.dwBytesRecorded

        .ENDIF

    ;// finally, we set bytes recorded correctly

        .ERRNZ ((SIZEOF MIDISHORTEVENT) - 12), <code assumes that MIDISHORTEVENT is 12 bytes>

        mov eax, out_header.dwBytesRecorded
        DEBUG_IF <eax !> MIDIEVENTS_PER_FRAME>  ;// too many events !!
        lea eax, [eax+eax*2]    ;// *3
        shl eax, 2              ;// *4 = 12
        mov out_header.dwBytesRecorded, eax

    ;// bug hunt //////////////////////////////////////////////////////////////////////
    ;// bug hunt //////////////////////////////////////////////////////////////////////
    IFDEF USE_MLOG
        invoke dump_OutStream, esi
    ENDIF
    ;// bug hunt //////////////////////////////////////////////////////////////////////
    ;// bug hunt //////////////////////////////////////////////////////////////////////



    ;// now the stream is packed, let's send it to the device

        invoke midiStreamOut, [esi].hDevice, edi, SIZEOF MIDIHDR
        DEBUG_IF <eax>  ;// couldn't write this

    ;// then reset in_stream and pready for next use

        xor eax, eax
        midistream_Reset [esi].in_stream
        mov [esi].pReady, eax

    ;// and we're done, clean up stack and exit

        pop ebp
        xchg esi, [esp+4]
        ret 4   ;// SDTCALL 1 arg

midiout_H_Calc ENDP




ASSUME_AND_ALIGN
midiout_WriteInStream PROC

        ASSUME esi:PTR MIDIOUT_OSC_MAP
        ;// destroys ebx

    ;// bug hunt ///////
    IFDEF USE_MLOG
        invoke dump_WriteStream
    ENDIF
    ;// bug hunt ///////

    ;// all this does is merge object.stream into device.in_stream

        mov edi, [esi].pDevice
        ASSUME edi:PTR MIDIOUT_HARDWARE_DEVICEBLOCK

    ;// start the merge
        xor ecx, ecx
        midistream_IterBegin [esi].stream, ecx, done_with_merge

        lea ebx, [edi].in_stream    ;// point at stream we insert into

    top_of_merge:

        invoke midistream_Insert, ebx, ecx, [esi].stream[ecx*8].evt
        jc merge_completely_full

        midistream_IterNext [esi].stream, ecx, top_of_merge

    done_with_merge:
    merge_completely_full:  ;// just abort

        ret


midiout_WriteInStream ENDP


;////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////
;//
;//     DEBUG FUNCTIONS
;//

IFDEF USE_MLOG

    ASSUME_AND_ALIGN
    dump_OpenMLog   PROC
        .IF !mlog
            invoke CreateFileA, OFFSET sz_mlog, GENERIC_WRITE, FILE_SHARE_READ OR FILE_SHARE_WRITE, 0, CREATE_ALWAYS, 0, 0
            mov mlog, eax
        .ENDIF
        ret
    dump_OpenMLog   ENDP

    ASSUME_AND_ALIGN
    dump_CloseMLog  PROC
        .IF mlog
            invoke CloseHandle, mlog
            mov mlog, 0
        .ENDIF
        ret
    dump_CloseMLog  ENDP



    ASSUME_AND_ALIGN
    dump_WriteStream PROC

        ;// called at end of midiout_Calc

            ASSUME esi:PTR MIDIOUT_OSC_MAP
            ;// destroys ebx

        ;// write the section header

            pushd 0
            mov edx, esp
            invoke WriteFile, mlog, OFFSET sz_mlog_write_header, (SIZEOF sz_mlog_write_header)-1, edx, 0
            pop eax

        ;// dump so_stream

            xor ebx, ebx
            midistream_IterBegin [esi].stream, ebx, done_with_so_stream

        top_of_so_stream:

            invoke wsprintfA, OFFSET mlog_buffer, OFFSET sz_mlog_format,
                ebx, 0, [esi].stream[ebx*8].evt

            pushd 0
            mov edx, esp
            invoke WriteFile, mlog, OFFSET mlog_buffer, eax, edx, 0
            pop eax

            midistream_IterNext [esi].stream, ebx, top_of_so_stream

        done_with_so_stream:


        ;// that's it

            ret

    dump_WriteStream ENDP


    ASSUME_AND_ALIGN
    PROLOGUE_OFF
    dump_InStream   PROC    STDCALL pDevice:DWORD

        ;// called before moving in stream to out stream

        ;// write the section header

            pushd 0
            mov edx, esp
            invoke WriteFile, mlog, OFFSET sz_mlog_in_header, (SIZEOF sz_mlog_in_header)-1, edx, 0
            pop eax

        ;// get some pointers

            xchg esi, [esp+4]
            ASSUME esi:PTR MIDIOUT_HARDWARE_DEVICEBLOCK
            push ebx

        ;// dump in_stream

            xor ebx, ebx

            midistream_IterBegin [esi].in_stream, ebx, done_with_in_stream

        top_of_in_stream:

            invoke wsprintfA, OFFSET mlog_buffer, OFFSET sz_mlog_format,
                ebx, 0, [esi].in_stream[ebx*8].evt

            pushd 0
            mov edx, esp
            invoke WriteFile, mlog, OFFSET mlog_buffer, eax, edx, 0
            pop eax

            midistream_IterNext [esi].in_stream, ebx, top_of_in_stream

        done_with_in_stream:


        ;// that's it

            pop ebx
            xchg esi, [esp+4]
            ret 4   ;// STDCALL 1 arg

    dump_InStream   ENDP
    PROLOGUE_ON


    ASSUME_AND_ALIGN
    PROLOGUE_OFF
    dump_OutStream  PROC    STDCALL pDevice:DWORD

        ;// called before sending out stream to midi device

        ;// write the section header

            pushd 0
            mov edx, esp
            invoke WriteFile, mlog, OFFSET sz_mlog_out_header, (SIZEOF sz_mlog_out_header)-1, edx, 0
            pop eax

        ;// dump out_stream

            ;// prepare to dump the buffer

                xchg esi, [esp+4]
                ASSUME esi:PTR MIDIOUT_HARDWARE_DEVICEBLOCK
                push edi
                push ebp

                mov edi, [esi].pReady
                ASSUME edi:PTR MIDIOUT_FRAME

                lea ebp,[edi].out_stream            ;// ebp iterates the stream
                ASSUME ebp:PTR MIDISHORTEVENT
                mov edi, [edi].hdr.dwBytesRecorded  ;// edi counts bytes
                ASSUME edi:NOTHING

            ;// iterate through all the records

            top_of_mlog:

                sub edi, SIZEOF MIDISHORTEVENT
                jc done_with_mlog

                invoke wsprintfA, OFFSET mlog_buffer, OFFSET sz_mlog_format, [ebp].dwDeltaTime, [ebp].dwStreamID, [ebp].dwEvent

                pushd 0
                mov edx, esp
                invoke WriteFile, mlog, OFFSET mlog_buffer, eax, edx, 0
                pop eax

                add ebp, SIZEOF MIDISHORTEVENT
                jmp top_of_mlog

            done_with_mlog:

            pop ebp
            pop edi
            xchg esi, [esp+4]

        ;// that's it

            ret 4   ;// STDCALL 1 arg

    dump_OutStream  ENDP
    PROLOGUE_ON

ENDIF   ;// USE_MLOG

;//
;//     DEBUG FUNCTIONS
;//
;////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////





ASSUME_AND_ALIGN

END