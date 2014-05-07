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
;// midiin_que.asm      implements device --> que --> portstream
;//                     includes all _H_ functions as well
;//
;// TOC
;//
;// midiin_H_Ctor
;// midiin_H_Dtor
;// midiin_Proc
;// midiin_H_Open
;// midiin_H_Close
;// midiin_H_Ready
;// midiin_H_Calc
;// midi_que_to_portstream


OPTION CASEMAP:NONE
.586
.MODEL FLAT

USE_THIS_FILE EQU 1
IFDEF USE_THIS_FILE

    .NOLIST
    INCLUDE <ABox.inc>
    INCLUDE <midi2.inc>
    INCLUDE <hardware_debug.inc>
    .LIST

.DATA

    midiin_que_stamp_scale  REAL4 22.05 ;// = 22050/1000

.CODE


ASSUME_AND_ALIGN
midiin_H_Ctor PROC

        invoke about_SetLoadStatus

    ;// here we fill in our dev blocks and allocate the headers and devices

        xor ebx, ebx
        invoke midiInGetNumDevs
        or ebx, eax
        jz all_done

    ;// make some temp storage

        sub esp, SIZEOF MIDIOUTCAPS
        st_micaps TEXTEQU <(MIDIOUTCAPS PTR [esp])>

    ;// loop through ebx, times

    top_of_loop:

        dec ebx
        js all_done_cleanup

        ;// got a new device

                H_LOG_TRACE <midiin_H_Ctor>

        ;// assume we can use this

            slist_AllocateHead hardwareL, edi, SIZEOF MIDIIN_HARDWARE_DEVICEBLOCK
            ASSUME edi:PTR MIDIIN_HARDWARE_DEVICEBLOCK

            mov [edi].ID, ebx
            mov [edi].pBase, OFFSET osc_MidiIn2
            or [edi].dwFlags, HARDWARE_SHARED

        ;// get and xfer the name

            lea eax, st_micaps
            invoke midiInGetDevCapsA, ebx, eax, SIZEOF MIDIINCAPS
            lea eax, st_micaps.szPname
            invoke lstrcpyA, ADDR [edi].szName, eax
            lea eax, st_micaps.szPname
            LISTBOX about_hWnd_device, LB_ADDSTRING, 0, eax

            lea eax, st_micaps.szPname
            WINDOW about_hWnd_load, WM_SETTEXT, 0, eax

        ;// iterate to the next device block

            jmp top_of_loop


    ;// that's it
    all_done_cleanup:

        st_micaps TEXTEQU <>
        add esp, SIZEOF MIDIOUTCAPS

all_done:

        ret

midiin_H_Ctor ENDP


ASSUME_AND_ALIGN
midiin_H_Dtor PROC ;// STDCALL pDevBlock:PTR HARDWARE_DEVICEBLOCK

    ;// we assume all the devices are stopped

            H_LOG_TRACE <midiin_H_Dtor>

    ;// nothing to do

        ret 4

midiin_H_Dtor ENDP







;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////


;// ABOX233: changed to MIDI_QUE_PORTSTREAM


ASSUME_AND_ALIGN
midiin_Proc PROC ;// STDCALL hMidiIn, dwMsg, dwInstance, dwParam1, dwParam2
                  ;// 00        04      08       0C         10        14

    ;// dwInstance is the device block pointer for this device
    ;// we can be assured that we never get duplicate time stamps

    cmp DWORD PTR [esp+8], MIM_DATA ;// make sure we are a data item
    jne all_done

    ;// dwInstance = pMIDI_QUE_PORTSTREAM
    ;// dwParam1 = dwMidiMessage
    ;// dwParam2 = dwTimestamp  ;// millisecond time stamps

        mov ecx, [esp+0Ch]          ;// get the device block
        ASSUME ecx:PTR MIDI_QUE_PORTSTREAM

    ;// advance last_write
    ;// determine where we place this in the que
    ;// convert and xfer the stamp
    ;// convert and xfer the event

        ASSUME edx:PTR MIDIIN_QUE   ;// forward reference

        mov edx, [ecx].last_write   ;// get last_write

        fild DWORD PTR [esp+14h]    ;// time stamp (milliseconds)

        lea eax, [edx+1]            ;// advance 1

        fmul midiin_que_stamp_scale ;// convert stamp to stream index (0-512)

        and eax, MIDIIN_QUE_LENGTH-1;// make last_write circular

        lea edx, [ecx+edx*8].que    ;// point edx at the que

        mov [ecx].last_write, eax   ;// store the new last_write index

        mov eax, [esp+10h]          ;// get midi event

        bswap eax                   ;// reverse the sequence

        fistp [edx].stamp           ;// store the slot index

        shr eax, 8                  ;// scoot event into place

        or eax, MIDI_FLOAT_BIAS     ;// merge on the float bias

        mov [edx].event, eax        ;// store the event

    ;// do the H_LOG stats

        H_LOG_CODE  <push ebx>
        H_LOG_CODE  <mov ebx, [edx].stamp>
        H_LOG_CODE  <mov edx, [ecx].last_write>
        H_LOG_CODE  <dec edx>
        H_LOG_CODE  <mov ecx, DWORD PTR [esp+18h]>
            H_LOG_TRACE <midiin_Proc__event>, ecx, ebx, eax, edx
        H_LOG_CODE  <pop ebx>


    ;// that should do it

    all_done:

        ret 14h

midiin_Proc ENDP





ASSUME_AND_ALIGN
midiin_H_Open PROC STDCALL uses esi edi pDevice:PTR HARDWARE_DEVICEBLOCK

    ;// we return non zero if we cannot open the device

        mov esi, pDevice
        ASSUME esi:PTR MIDIIN_HARDWARE_DEVICEBLOCK

    ;// check if we're already open

        DEBUG_IF <[esi].hDevice> ;// already opened !!

    ;// check for tracker or device

    ;// open the device
    ;// ABOX232 changed caller param to MIDI_QUE_PORTSTREAM

        ;// invoke midiInOpen, ADDR [esi].hDevice, [esi].ID, midiin_Proc, esi, CALLBACK_FUNCTION
        lea edx, [esi+SIZEOF HARDWARE_DEVICEBLOCK]
        invoke midiInOpen, ADDR [esi].hDevice, [esi].ID, midiin_Proc, edx, CALLBACK_FUNCTION

        .IF !eax

        ;// clear the data blocks

            mov [esi].last_write, eax
            mov [esi].last_read, eax
            mov [esi].frame_counter, eax
            mov [esi].portstream_ready, eax
            mov [esi].empty_frame, eax

        ;// start recording

            invoke midiInStart, [esi].hDevice   ;// start the device

                H_LOG_TRACE <midiin_H_Open__start_device>

        .ENDIF

    ;// that's it

        ret

midiin_H_Open ENDP



ASSUME_AND_ALIGN
midiin_H_Close PROC STDCALL uses edi pDevice:PTR HARDWARE_DEVICEBLOCK

            H_LOG_TRACE <midiin_H_Close>

    ;// here, we close the device

        mov edi, pDevice
        ASSUME edi:PTR MIDIIN_HARDWARE_DEVICEBLOCK

        ;//.IF !([edi].ID & MIDIIN_TRACKER_BIAS)    ;// don't close trackers

        invoke midiInStop, [edi].hDevice
        DEBUG_IF <eax>  ;// couldn't stop

        invoke midiInClose, [edi].hDevice
        DEBUG_IF <eax>  ;// couldn't close

        ;//.ENDIF

        mov [edi].hDevice, 0
        and [edi].dwFlags, NOT HARDWARE_BAD_DEVICE

    ;// that's it

        ret

midiin_H_Close ENDP







ASSUME_AND_ALIGN
midiin_H_Ready PROC ;//  STDCALL pDevBlock:PTR HARDWARE_DEVICEBLOCK

    ;// we're always ready

    mov eax, READY_TIMER

    ret 4

midiin_H_Ready ENDP




ASSUME_AND_ALIGN
midiin_H_Calc PROC ;// STDCALL pDevice:PTR HARDWARE_DEVICEBLOCK
                    ;// 00      04

    ;// this is called after all the midi objects have been calced
    ;// our only job is to turn off portstream_ready and advance the frame counter

        mov ecx, [esp+4]
        ASSUME ecx:PTR MIDIIN_HARDWARE_DEVICEBLOCK
        xor eax, eax

        mov [ecx].portstream_ready, eax
        inc [ecx].frame_counter
            H_LOG_TRACE <midiin_H_Calc__portstream>, [ecx].frame_counter

        retn 4

midiin_H_Calc ENDP



;// ABOX233 NEW VERSION, NEW NAME

ASSUME_AND_ALIGN
midi_que_to_portstream PROC

    ;// this called from an object
    ;// the task is to send all the data we can to the port stream
    ;// then set portstream ready


    ;// algorithm
    ;//
    ;// determine frame start and frame stop
    ;//
    ;// frame start = frame_counter * MIDI_STREAM_LENGTH
    ;// frame stop = frame start + MIDI_STREAM_LENGTH
    ;//
    ;// from last_read to last write
    ;//
    ;//     cmp que_stamp frame_start
    ;//     js adjust frame count
    ;//     cmp que_stamp, frame_stop
    ;//     jae done_with_loop
    ;//
    ;//     xfer the event

        ASSUME ebx:PTR MIDI_QUE_PORTSTREAM

    ;// reset portstream

        xor eax, eax
        midistream_Reset [ebx].portstream

H_LOG_TRACE <midi_que_to_portstream__ENTER>,[ebx].frame_counter,[ebx].last_read,[ebx].last_write

    ;// get last_read and determine if we got anything

        mov ecx, [ebx].last_read
        cmp ecx, [ebx].last_write       ;// ecx iterates the que
        je got_empty_frame

    ;// we have events and we need many registers

        push edi
        push esi
        push ebp

    ;// get the start and stop frame counters

        mov edi, [ebx].frame_counter        ;// get the frame counter
        shl edi, LOG2(MIDI_STREAM_LENGTH)   ;// edi = frame start
        lea ebp, [ebx].portstream           ;// point at destination stream
        lea esi, [edi+MIDI_STREAM_LENGTH]   ;// esi = frame stop

    ALIGN 16
    top_of_loop:

        mov eax, [ebx].que[ecx*8].stamp ;// get the que stamp
        sub eax, edi                    ;// index = eax - edi
        js adjust_frame_counter         ;// if behind, jump to adjuster
                                        ;//  not hit very often so we put code below
        cmp eax, MIDI_STREAM_LENGTH     ;// check if beyond frame start
        jae check_empty_frame           ;// jump to check frame adjust if so

            H_LOG_TRACE <midi_que_to_portstream__inserting>,eax,[ebx].que[ecx*8].event

        invoke midistream_Insert, ebp, eax, [ebx].que[ecx*8].event
        jc frame_is_full

            H_LOG_TRACE <midi_que_to_portstream__inserted>

        mov [ebx].empty_frame, 0    ;// this frame has events in it

    frame_is_full:
    next_que_event:

        inc ecx
        and ecx,MIDIIN_QUE_LENGTH-1 ;// mask to make circular
        cmp ecx, [ebx].last_write
        jne top_of_loop

    done_with_loop:

        mov [ebx].last_read, ecx
        pop ebp
        pop esi
        pop edi

    ;///////////////////////////////////////////////
    all_done:

        or [ebx].portstream_ready, 1

H_LOG_TRACE <midi_que_to_portstream__EXIT>,[ebx].last_read


        ret


    ;///////////////////////////////////////////////
    ALIGN 16
    got_empty_frame:

        H_LOG_TRACE <midi_que_to_portstream__got_empty_frame>
        inc [ebx].empty_frame
        jmp all_done

    ALIGN 16
    check_empty_frame:

        ;// we recieved an event beyond this frame
        ;// if we had no events in the last frame
        ;// then we adjust frame count forwards

        H_LOG_TRACE <midi_que_to_portstream__check_empty_frame>,[ebx].empty_frame,[ebx].midi_flags

        ;// ABOX231: DOH!! this test was 'cmp' when it should have been 'test'
        test [ebx].midi_flags, MIDIIN_LOWEST_LATENCY    ;// do we care ?
        jz done_with_loop

        cmp [ebx].empty_frame, 0
        je done_with_loop

        ;// now we adjust frame forwards
        ;// eax has the stamp we're looking for

        and eax, NOT(MIDI_STREAM_LENGTH-1)
        add edi, eax
        lea esi, [edi+MIDI_STREAM_LENGTH];// esi = frame stop
        shr eax, LOG2(MIDI_STREAM_LENGTH)
        add [ebx].frame_counter, eax
        mov [ebx].empty_frame, 0

            H_LOG_TRACE <midi_que_to_portstream__FrameAdjust_FORWARDS>, [ebx].frame_counter, edi, eax

        jmp top_of_loop


    ALIGN 16
    adjust_frame_counter:

    ;// this is hit when que.stamp is behind frame_counter
    ;// we want to adjust frame_counter so the event falls inside the current frame
    ;//
    ;// eax has the negative offset (in MIDI_STREAM's)

        and eax, NOT (MIDI_STREAM_LENGTH-1) ;// align to frame (still neagtive)

        add edi, eax                        ;// adjust frame start
        DEBUG_IF <SIGN?>    ;// subtracted at very start !!!
        lea esi, [edi+MIDI_STREAM_LENGTH]   ;// esi = frame stop
        sar eax, LOG2(MIDI_STREAM_LENGTH)   ;// turn into index adjust
        add [ebx].frame_counter, eax        ;// adjust the frame counter
        DEBUG_IF <SIGN?>    ;// subtracted at very start !!!

            H_LOG_TRACE <midi_que_to_portstream__FrameAdjust_BACKWARDS>, [ebx].frame_counter, edi, eax

        jmp top_of_loop     ;// back to top of loop




midi_que_to_portstream ENDP








ASSUME_AND_ALIGN




ENDIF ;// USE_THIS_FILE


END