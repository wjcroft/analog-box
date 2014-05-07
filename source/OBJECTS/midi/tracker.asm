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
;// tracker.asm
;//
OPTION CASEMAP:NONE
.586
.MODEL FLAT

    .NOLIST
    INCLUDE <ABox.inc>
    INCLUDE <midi2.inc>
    .LIST

comment ~ /*

        trackers need to be juggled a little bit

        loading a file

            objects are not created in order
            dependants object WILL be created before the source is

        clone or paste

            object will need to create a new tracker table with a new ID

        delete source

            dependant objects will need to be updated

        ---------------------------------------------

        tracker_Locate

            scan LIST_CONTEXT.tracker looking for tracker with the same ID
            if the tracker is not found, then it is created

        if a dependant osc creates the tracker
        then it attaches it self

            no problem

        if a source osc creates the tracker
        then it attaches itself

            no problem

        if a source osc finds a tracker that is already sourced ...
        how can this happen ?
        clone or paste

        SO: source osc:

                tracker_Locate
                created_new ?   attach
                else already assigned a source ? bump ID and try again
                else attach

    interface

        tracker_AttachSource

            locates tracker using above algorithm
            allocates new tracker

        tracker_DetachSource

            detaches source
            if last osc, then deallocate tracker

        tracker_AttachDest

            adds object to tracker list using above method

        tracker_DetachDest

            removes tracker from object list
            if last osc, then deallocate tracker



*/ comment ~


.CODE

;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;///
;///    PRIVATE INTERFACE       Locate--Allocate
;///                            Destroy
;///
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////


IFDEF DEBUGBUILD

    ASSUME_AND_ALIGN
    tracker_debug_check PROC uses ecx ebx

        ;// task verify that the tracker is in only one list
        ;// edx must enter as the number we expect

            ASSUME ebp:PTR LIST_CONTEXT
            ASSUME esi:PTR MIDIIN_OSC_MAP

        ;// iterate the tracker list

            slist_GetHead tracker,ecx,ebp
            test ecx, ecx
            jz done_with_tracker

        top_of_tracker:

            .IF esi == [ecx].pSourceObject
                dec edx
            .ENDIF

            slist_GetHead tracker_dest,ebx,ecx
            test ebx, ebx
            jz done_with_dest

        top_of_dest:

            .IF esi==ebx
                dec edx
            .ENDIF

            slist_GetNext tracker_dest, ebx
            test ebx, ebx
            jnz top_of_dest

        done_with_dest:

            slist_GetNext tracker, ecx
            test ecx, ecx
            jnz top_of_tracker

        done_with_tracker:

            DEBUG_IF <edx>  ;// not the number we expected !!

            ret

    tracker_debug_check ENDP

    TRACKER_DEBUG_CHECK MACRO num:req

        mov edx, num
        invoke tracker_debug_check

        ENDM

ELSE

    TRACKER_DEBUG_CHECK MACRO num:req

        ENDM

ENDIF






.DATA

    sz_tracker_name_format  db 'track %i',0
    ALIGN 4

.CODE


ASSUME_AND_ALIGN
tracker_Locate PROC

    ;// look for tracker with matching ID
    ;// if not found, create it

        ASSUME esi:PTR MIDIIN_OSC_MAP
        ASSUME ebp:PTR LIST_CONTEXT

        ;// ecx must enter with the ID to create (preserved)
        ;// returns tracker in eax

    ;// we do not want to attach the device yet because it looks at
    ;// always check tracker.numDevices to see if device has been attached yet
    ;// newly allocated objects will have 0 for num devices

    ;// locate the tracker

        xor eax, eax
        slist_OrGetHead tracker,eax,ebp
        jz tracker_allocate         ;// empty list

    J0: cmp [eax].ID, ecx
        je all_done
        slist_GetNext tracker, eax
        test eax, eax
        jz tracker_allocate

        cmp [eax].ID, ecx
        je all_done
        slist_GetNext tracker, eax
        test eax, eax
        jnz J0

    tracker_allocate:

        ;// add a new node to tracker context
        ;// ecx has the id to create

        push ecx                                ;// preserve ID
        slist_AllocateHead tracker, eax,,[ebp]  ;// allocate a new device block
        pop ecx                                 ;// retrieve the id
        mov [eax].ID, ecx                       ;// assign the id

        push eax
        push ecx
        add eax, OFFSET MIDIIN_TRACKER_CONTEXT.szName
        invoke wsprintfA, eax, OFFSET sz_tracker_name_format, ecx
        pop ecx
        pop eax

        ;// that's it, return eax as the new device

    all_done:

        ret     ;// found it

tracker_Locate ENDP


ASSUME_AND_ALIGN
tracker_Destroy PROC

    ;// find the node, remove from context, reset the osc
    ;// ecx must point at device block (destroyed)

        ASSUME ebp:PTR LIST_CONTEXT
        ASSUME esi:PTR MIDIIN_OSC_MAP
        ASSUME ecx:PTR MIDIIN_TRACKER_CONTEXT

        DEBUG_IF <[ecx].pSourceObject>  ;// supposd to be detached

        DEBUG_IF <slist_Head(tracker_dest,ecx)> ;// list is supposed to be empty

        DEBUG_IF <[ecx].numDevices>     ;// instance count is messed up

        TRACKER_DEBUG_CHECK 0   ;// osc must not be in any list

        slist_Remove tracker, ecx,,,[ebp]
        invoke memory_Free, ecx

        ret

tracker_Destroy ENDP


;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;///
;///    PUBLIC INTERFACE
;///
;///
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
tracker_AttachSource PROC

        ASSUME esi:PTR MIDIIN_OSC_MAP
        ASSUME ebp:PTR LIST_CONTEXT

        DEBUG_IF < [esi].midiin.tracker.pTracker >  ;// already have device !!

        TRACKER_DEBUG_CHECK 0   ;// osc must not be in any list

        or [ebp].pFlags, PFLAG_TRACE    ;// schedule a trace

    ;// try to locate this tracker

        ;// setup ecx
        mov ecx, [esi].midiin.tracker_id    ;// get specified id

    ;// we'll do two passes
    ;// if we get an assigned and existing tracker on the first pass
    ;// we reassign tracker_id as zero and iterae until wee find the first empty slot
    ;// this correctly accounts for clone

        invoke tracker_Locate
        ASSUME eax:PTR MIDIIN_TRACKER_CONTEXT
        ;// returns tracker in eax
        ;// ecx is still ID

    ;// see if we created a new one

        cmp [eax].numDevices, 0     ;// devices will be zero if we created a new one
        je attach_source_device     ;// jump to attacher if new block

    ;// found an existing device

        cmp [eax].pSourceObject, 0  ;// is source already assigned ?
        je attach_source_device     ;// if not, then attach

    ;// tracker already has a source
    ;// this was the first pass, so reset index
    ;// and iterate to the first empty slot

        .IF ecx             ;// if ecx was already zero, no since doing it again
            xor ecx, ecx
        .ELSE
            inc ecx         ;// otherwise, just do the next id
        .ENDIF

    locate_tracker:

        invoke tracker_Locate
        ASSUME eax:PTR MIDIIN_TRACKER_CONTEXT
        ;// returns tracker in eax
        ;// ecx is still ID

    ;// see if we created a new one

        cmp [eax].numDevices, 0     ;// devices will be zero if we created a new one
        je attach_source_device     ;// jump to attacher if new block

    ;// found an existing device

        cmp [eax].pSourceObject, 0  ;// is source already assigned ?
        je attach_source_device     ;// if not, then attach

    ;// tracker already has a source

        inc ecx                     ;// next id, should be safe for a few thousand
        jmp locate_tracker          ;// try again

    ;// no we have an unassigned tracker in eax
    attach_source_device:

    ;// attach the device

        inc [eax].numDevices            ;// bump the instance count on the tracker
        mov [eax].pSourceObject, esi    ;// attach our object to tracker
        mov [esi].midiin.tracker.pTracker, eax  ;// atach tracker to our object
        mov [esi].midiin.tracker_id, ecx;// store the tracker id (in case it got changed)

        TRACKER_DEBUG_CHECK 1   ;// osc must be in one list

    ;// then we make sure our attached dests have their N/F units set correctly

        invoke tracker_UpdateDestPins

    ;// lastly, we make sure we aren't marked as bad

        .IF [esi].dwHintOsc & HINTOSC_STATE_HAS_BAD
            GDI_INVALIDATE_OSC HINTI_OSC_LOST_BAD
        .ENDIF

    ;// that's it

        ret

tracker_AttachSource ENDP


ASSUME_AND_ALIGN
tracker_DetachSource PROC

        ASSUME esi:PTR MIDIIN_OSC_MAP
        ASSUME ebp:PTR LIST_CONTEXT
        ASSUME ecx:PTR MIDIIN_TRACKER_CONTEXT
        DEBUG_IF <!!ecx>        ;// we don't have a tracker !!
        DEBUG_IF < ecx !!= [esi].midiin.tracker.pTracker >  ;// worong tracker

        TRACKER_DEBUG_CHECK 1   ;// osc must be in one list

        or [ebp].pFlags, PFLAG_TRACE    ;// schedule a trace

        DEBUG_IF < !! [esi].midiin.tracker.pTracker >   ;// nothing to detach !!

    ;// detaches source
    ;// if last osc, then deallocate tracker

        xor eax, eax                    ;// use for zeroing
        dec [ecx].numDevices            ;// decrease instance count
        mov [esi].midiin.tracker_id, eax;// zero the tracker id (so we find a new quicker)
        mov [ecx].pSourceObject, eax    ;// reset pSource
        mov [esi].midiin.tracker.pTracker, eax;// reset the tracker
        jz  tracker_Destroy

        TRACKER_DEBUG_CHECK 0

        ret

tracker_DetachSource ENDP


ASSUME_AND_ALIGN
tracker_AttachDest PROC

        ASSUME esi:PTR MIDIIN_OSC_MAP
        ASSUME ebp:PTR LIST_CONTEXT

        DEBUG_IF <[esi].midiin.tracker.pTracker>    ;// already have a tracker !!

        TRACKER_DEBUG_CHECK 0   ;// osc must not be in any lists !

        or [ebp].pFlags, PFLAG_TRACE    ;// schedule a trace

    ;// locate or create a device block

        mov ecx, [esi].midiin.tracker_id
        invoke tracker_Locate
        ASSUME eax:PTR MIDIIN_TRACKER_CONTEXT

    ;// attach and set our object.pDecive

        inc [eax].numDevices    ;// bump instance count on tracker
        mov [esi].midiin.tracker.pTracker, eax  ;// attatch tracker to our object

    ;// insert ourselves as head of the object list

        slist_InsertHead tracker_dest, esi,edx,eax

    ;// if we have a source, then make sure our N/F units are set correctly
    ;// eax is still the tracker device returned from tracker_Locate

        mov eax, [eax].pSourceObject
        .IF eax

        push ebx

            mov eax, (MIDIIN_OSC_MAP PTR [eax]).dwUser
            lea ebx, [esi].pin_N
            ASSUME ebx:PTR APIN

            mov edx, midi_font_N_out
            test eax, MIDIIN_NOTE_TRACKER_FREQ
            mov eax, UNIT_MIDI
            jz J1

            mov edx, midi_font_F
            mov eax, UNIT_HERTZ

        J1: invoke pin_SetNameAndUnit, edx, 0, eax

        pop ebx

        .ENDIF

        TRACKER_DEBUG_CHECK 1   ;// tracker must be in one list

    ;// lastly, we make sure we aren't marked as bad

        .IF [esi].dwHintOsc & HINTOSC_STATE_HAS_BAD
            GDI_INVALIDATE_OSC HINTI_OSC_LOST_BAD
        .ENDIF

    ;// that's it

        ret

tracker_AttachDest ENDP


ASSUME_AND_ALIGN
tracker_DetachDest PROC

        ASSUME esi:PTR MIDIIN_OSC_MAP
        ASSUME ebp:PTR LIST_CONTEXT
        ASSUME ecx:PTR MIDIIN_TRACKER_CONTEXT
        DEBUG_IF <!!ecx>        ;// we don't have a tracker !!
        DEBUG_IF < ecx !!= [esi].midiin.tracker.pTracker >  ;// worong tracker

        TRACKER_DEBUG_CHECK 1   ;// osc must be in one list

        or [ebp].pFlags, PFLAG_TRACE    ;// schedule a trace

    ;// removes tracker from object list
    ;// if last osc, then deallocate tracker


    ;// remove ourselves from the dest list

        slist_Remove tracker_dest,esi,,,ecx

    ;// we are detached from the object list
    ;// ecx points at context

        dec [ecx].numDevices        ;// decrease the device count
        mov [esi].midiin.tracker.pTracker, 0
        jz  tracker_Destroy         ;// if zero then we deallocate

        TRACKER_DEBUG_CHECK 0   ;// osc must not be in any list

        ret

tracker_DetachDest ENDP



ASSUME_AND_ALIGN
tracker_KillDest    PROC

        ASSUME ebp:PTR LIST_CONTEXT
        ASSUME esi:PTR MIDIIN_OSC_MAP
        ASSUME ecx:PTR MIDIIN_TRACKER_CONTEXT

    ;// task: verify that we are not a tracker dest

        DEBUG_IF <!!ecx>        ;// we don't have a tracker !!
        DEBUG_IF < ecx !!= [esi].midiin.tracker.pTracker >  ;// wrong tracker

        slist_GetHead tracker_dest, edx, ecx

        test edx, edx
        jz all_done

    top_of_loop:

        cmp edx, esi
        je tracker_DetachDest

        slist_GetNext tracker_dest, edx
        test edx, edx
        jnz top_of_loop

    all_done:

        ret

tracker_KillDest ENDP



ASSUME_AND_ALIGN
tracker_VerifyDest PROC

    ;// task: verify that we are in the correct destination list

        ASSUME ebp:PTR LIST_CONTEXT
        ASSUME esi:PTR MIDIIN_OSC_MAP
        ASSUME ecx:PTR MIDIIN_TRACKER_CONTEXT

        DEBUG_IF <!!ecx>        ;// we don't have a tracker !!
        DEBUG_IF < ecx !!= [esi].midiin.tracker.pTracker >  ;// wrong tracker

        mov eax, [ecx].ID
        cmp eax, [esi].midiin.tracker_id
        je all_done

        invoke tracker_KillDest
        invoke tracker_AttachDest

    all_done:

        ret

tracker_VerifyDest ENDP


ASSUME_AND_ALIGN
tracker_KillSource PROC

    ;// verify that we are not a tracker source

        ASSUME ebp:PTR LIST_CONTEXT
        ASSUME esi:PTR MIDIIN_OSC_MAP
        ASSUME ecx:PTR MIDIIN_TRACKER_CONTEXT

        DEBUG_IF <!!ecx>        ;// we don't have a tracker !!
        DEBUG_IF < ecx !!= [esi].midiin.tracker.pTracker >  ;// wrong tracker

        cmp [ecx].pSourceObject, esi
        je tracker_DetachSource

        ret

tracker_KillSource ENDP






ASSUME_AND_ALIGN
tracker_VerifySource PROC

    ;// task: verify that we are the correct source
    ;//         assign source if not

        ASSUME ebp:PTR LIST_CONTEXT
        ASSUME esi:PTR MIDIIN_OSC_MAP
        ASSUME ecx:PTR MIDIIN_TRACKER_CONTEXT

        DEBUG_IF <!!ecx>        ;// we don't have a tracker !!
        DEBUG_IF < ecx !!= [esi].midiin.tracker.pTracker >  ;// wrong tracker

    ;// id's must match

        mov eax, [ecx].ID
        cmp eax, [esi].midiin.tracker_id
        je all_done

        invoke tracker_DetachSource
        invoke tracker_AttachSource

    all_done:

        ret

tracker_VerifySource ENDP






ASSUME_AND_ALIGN
tracker_UpdateDestPins PROC uses esi

    ;// this is called to make sure attached tracker dests
    ;// are showing the correct N/F pin and that their units are set correctly

        ASSUME esi:PTR MIDIIN_OSC_MAP   ;// (preserved)
        ASSUME ebp:PTR LIST_CONTEXT
        ;// destroys ebx

        DEBUG_IF < !![esi].midiin.tracker.pTracker> ;// supposed to be a tracker source !!

        mov eax, [esi].dwUser   ;// get the setting now
        mov esi, [esi].midiin.tracker.pTracker
        DEBUG_IF <!!esi>    ;// source is supposed to be assigned !!
        ASSUME esi:PTR MIDIIN_TRACKER_CONTEXT
        slist_GetHead tracker_dest, esi,esi

        .IF esi     ;// make sure there is a dest list

            push edi

            .IF eax & MIDIIN_NOTE_TRACKER_FREQ
                mov edi, UNIT_HERTZ
                mov ecx, midi_font_F
            .ELSE
                mov edi, UNIT_MIDI
                mov ecx, midi_font_N_out
            .ENDIF

            ;// edi = unit
            ;// ecx = font

            .REPEAT

                lea ebx, [esi].pin_N        ;// get the pin
                ASSUME ebx:PTR APIN
                invoke pin_SetNameAndUnit, ecx, 0, edi
                slist_GetNext tracker_dest, esi

            .UNTIL !esi

            pop edi

        .ENDIF

        ret

tracker_UpdateDestPins ENDP

ASSUME_AND_ALIGN
tracker_FillInDeviceList PROC

    ASSUME esi:PTR MIDIIN_OSC_MAP
    ASSUME ebp:PTR LIST_CONTEXT
    ;// ebx is the handle to the list box
    ;// destroys edi

    LISTBOX ebx, LB_RESETCONTENT

    slist_GetHead tracker, edi, ebp

    .WHILE edi

        .IF edi != [esi].midiin.tracker.pTracker

            LISTBOX ebx, LB_ADDSTRING, 0, ADDR [edi].szName
            LISTBOX ebx, LB_SETITEMDATA, eax, edi

        .ENDIF

        slist_GetNext tracker, edi

    .ENDW

    ret


tracker_FillInDeviceList ENDP




;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;///
;///    CALC
;///
;///
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////




comment ~ /*

    this is the  calc for the source object

    the task is

        using the command stream for this object
        perform calc for all attached objects

    get the source stream
    iterate the source stream
    process each command

    there are four commands we react to
    we assume they have already been properly filtered
    pSourceObject will have the stream

        NOTE_ON && VALUE != 0
        NOTE_OFF || ( NOTE_ON && VALUE == 0 )
        NOTE_PRESS

    it looks like all we have to do is

    1) locate the device block to process
    2) locate and process the source stream filter
    3) call midiin_fill_Begin for attached objects
    4) iterate the source stream and route note commands to appropriate destinations
    5) call midiin)fill_End for attached objects


*/ comment ~


ASSUME_AND_ALIGN
tracker_Calc PROC USES ebp esi

            ASSUME esi:PTR MIDIIN_OSC_MAP
            ASSUME ebx:PTR MIDI_STREAM_ARRAY    ;// commands to process

            mov ebp, [esi].midiin.tracker.pTracker
            ASSUME ebp:PTR MIDIIN_TRACKER_CONTEXT

            DEBUG_IF <!!ebp>    ;// supposed to have source !!
            DEBUG_IF < esi !!= [ebp].pSourceObject >    ;// wrong tracker !!

        ;// ebp is the context for the rest of this function

        ;// now we have the source object

            DEBUG_IF < !![esi].midiin.f_stream >    ;// f_stream is supposed to be set !!

        ;// always xfer sat from source object to device

            mov eax, [esi].dwUser
            and eax, MIDIIN_NOTE_TRACKER_SAT OR MIDIIN_NOTE_TRACKER_FREQ
            mov [ebp].tracker_flags, eax

        ;// get its input stream and make sure it's been set

    ;// 3) call midiin_fill_Begin for attached objects
    ;//     early out as well, if we have no dest objects, just abort


            slist_GetHead tracker_dest,esi,ebp  ;// esi iterates dest objects
            test esi, esi                   ;// see if there are any objects
            je done_with_tracker            ;// do early out if not

            .REPEAT
                invoke midiin_fill_Begin
                slist_GetNext tracker_dest, esi
            .UNTIL !esi

    ;// 4) iterate the source stream and route note commands to appropriate dest stream


;// USE_TRACKER_DUMP EQU 1
IFDEF DEBUGBUILD
IFDEF USE_TRACKER_DUMP

    .DATA
    hTracker    dd  0
    sz_tracker_file db 'tracker.txt',0
    .CODE

    pushad
    invoke CreateFileA, OFFSET sz_tracker_file, GENERIC_WRITE, FILE_SHARE_READ OR FILE_SHARE_WRITE, 0, OPEN_ALWAYS, 0, 0
    mov hTracker, eax
    invoke SetFilePointer, eax, 0, 0, FILE_END
    popad

ENDIF
ENDIF


        ;// get to first slot and check for early out

            xor ecx, ecx    ;// need to set the xternally
            midistream_IterBegin [ebx], ecx, process_loop_done

        ;///////////////////////////////////////////////////////

        top_of_process_loop:

            ;// get the event
            mov edx, [ebx+ecx*8].evt    ;// get the event
            mov eax, edx                ;// store number in eax
            ;// check for no command
            and edx, MIDI_FLOAT_COMMAND_TEST
            jz process_next_event       ;// skip if no command

IFDEF USE_TRACKER_DUMP

.DATA
                ;//  hi    lo            idx   evt
sz_tracker_in   db  '%8.8X:%8.8X tracker %3.3X %8.8X  ',0
.CODE

    pushad

    sub esp, 64 ;// text buffer

    push eax                    ;// wsprintf.evt
    push ecx                    ;// wsprintf.idx
    rdtsc
    push eax                    ;// wsprintf.lo
    push edx                    ;// wsprintf.hi
    lea edx, [esp+16]
    push OFFSET sz_tracker_in   ;// wsprintf.fmt
    push edx                    ;// wsprintf.buffer
    call wsprintfA
    add esp, 6*4    ;// C call
    mov edx, esp
    invoke WriteFile, hTracker, edx, eax, esp, 0
    add esp, 64

    popad

ENDIF

            ;// route note on's to look for empty slot
            ;// route note off's and note press to look for existing
            ;// ignore all others

            ;// look for NOTE_ON
            cmp edx, MIDI_FLOAT_NOTEON AND MIDI_FLOAT_COMMAND_TEST
            jne process_locate_existing ;// if not note on, locate the note this applies to
            ;// have NOTE_ON, check for zero velocity
            test eax, MIDI_FLOAT_VALUE_TEST
            jz process_locate_existing  ;// got a note-off, locate the note this applies to

comment ~ /*
;// BEGIN of RESTART DUPLICATE NOTES

int 3
have to implement a depth to prevent first note from shuttin off note
use event to do this, then when note off is hit dec event and check for zero
to replace an event, reset the event_depth to 1

        ;// we have note on with velocity
        process_look_for_duplicate_and_unused:

        ;// this requires that we scan the whole table
        ;// we'll keep track of the first empty in edi
        ;// we'll exit to replace event at the first duplicate

            mov esi, [ebp].pFirstObject
            and eax, MIDI_FLOAT_NUMBER_TEST ;// mask off the extra (numbers are stored in shifted form)
            xor edi, edi    ;// edi will be the first empty slot
            xor edx, edx    ;// edx will zero edi whithout setting flags

            look_for_both:  ;// looking for both empties and duplicates

                or edi, [esi].midiin.tracker.event  ;// is this object on ?
                mov edi, edx                        ;// reset edi
                jz found_empty                      ;// if not, then we've found an empty slot
                ;// this slot is NOT empty
                cmp eax, [esi].midiin.tracker.number;// is this a duplicate number ?
                je process_replace_this_event       ;// jmp if so
                ;// it's not a duplicate either, next object
                mov esi, [esi].midiin.tracker.pNextObject
                test esi, esi                       ;// done ?
                jnz look_for_both                   ;// back to top if done

            ;// we have found neither a duplicate or an empty slot
            ;// so we have to process LRU mode

                jmp process_check_lru_mode

            found_empty:
            ;// we've found an empty slot, so there's no need to check anymore

                mov edi, esi    ;// store the empty in edi

            look_for_duplicate: ;// looking for used objects with duplicate numbers

                ;// iterate first
                mov esi, [esi].midiin.tracker.pNextObject
                test esi, esi                       ;// done ?
                jz have_empty_slot                  ;// if done, we have an empty slot to fill
                ;// look for used slots only
                cmp edx, [esi].midiin.tracker.event ;// if this object on ?
                jz  look_for_duplicate              ;// back to top if on
                ;// look for duplicate number
                cmp eax, [esi].midiin.tracker.number;// duplicate number ?
                jne look_for_duplicate
                ;// we have found a duplicate object
                jmp process_replace_this_event

            have_empty_slot:

                mov esi, edi
                jmp process_found_empty_object

;// END of RESTART DUPLICATE NOTES
*/ comment ~

;// BEGIN of PLAY NEW DUPLICATE NOTES

        process_look_for_empty:

IFDEF USE_TRACKER_DUMP

    .DATA
    sz_tracker_look db  'LOOKING FOR EMPTY  '
    .CODE

    pushad
    invoke WriteFile, hTracker, OFFSET sz_tracker_look, SIZEOF sz_tracker_look, esp, 0
    popad

ENDIF
            slist_GetHead tracker_dest, esi, ebp
            xor eax, eax    ;// eax checks for event = 0
            xor edx, edx    ;// edx is zero for this block

            ;// unused objects have event == 0
            .REPEAT
                or eax, [esi].midiin.tracker.event
                jz process_found_empty_object
                slist_GetNext tracker_dest, esi
                test esi, esi
                mov eax, edx
                .BREAK .IF ZERO?
                or eax, [esi].midiin.tracker.event
                jz process_found_empty_object
                slist_GetNext tracker_dest, esi
                test esi, esi
                mov eax, edx
            .UNTIL ZERO?

        ;// we did not find an empty slot
        ;// check the SAT mode and determine if we need to search for a replacer

;// END of PLAY NEW DUPLICATE NOTES (fall through mmust be process_check_lru_mode)


        process_check_lru_mode:

            test [ebp].tracker_flags, MIDIIN_NOTE_TRACKER_SAT
            jnz process_next_event

        process_look_for_lru:


IFDEF USE_TRACKER_DUMP

    .DATA
    sz_tracker_lru  db  'LOOKING FOR LRU  '
    .CODE

    pushad
    invoke WriteFile, hTracker, OFFSET sz_tracker_lru, SIZEOF sz_tracker_lru, esp, 0
    popad

ENDIF


        ;// now we look for the LRU object
        ;// it will have the lowest stamp

            slist_GetHead tracker_dest,esi,ebp
            or eax, -1          ;// big big number
            ;// xor edx, edx    ;// store the osc (already zero)

            .REPEAT
                .IF eax > [esi].midiin.tracker.stamp
                    mov eax, [esi].midiin.tracker.stamp
                    mov edx, esi
                .ENDIF
                slist_GetNext tracker_dest, esi
                .BREAK .IF !esi
                .IF eax > [esi].midiin.tracker.stamp
                    mov eax, [esi].midiin.tracker.stamp
                    mov edx, esi
                .ENDIF
                slist_GetNext tracker_dest, esi
            .UNTIL !esi

                mov esi, edx

                DEBUG_IF <!!esi>    ;// didn't find anything !!

        process_replace_this_event:
        ;// now we have esi as the object to replace

            ;// this is only hit for NOTE_ON
            ;// since the current note is already on, we have to toggle it off
            ;// then insert a new note on
            ;// we do this by:
            ;// 1) store note off
            ;// 2) call midiin fill
            ;// 3) store note on in the next SAMPLE (STREAMs are two samples)
            ;// 4) setting midifile_skew to non zeero,
            ;//     so the next fill or end will grab the correct value

            ;// store note off and call advance

            ;// we may have to store the old note number ???

IFDEF USE_TRACKER_DUMP

    .DATA
    sz_tracker_replace  db  '___REPLACING____'
    .CODE

    pushad
    invoke WriteFile, hTracker, OFFSET sz_tracker_replace, SIZEOF sz_tracker_replace, esp, 0
    popad

ENDIF


            mov [esi].data_V[ecx*8], 0  ;// zero velocity
            mov [esi].data_e[ecx*8], 0  ;// turn note off
            invoke midiin_fill_Advance

            ;// store note on in the NEXT sample

            mov eax, [ebx+ecx*8].evt        ;// get the new note on event
            mov edx, eax
            and eax, MIDI_FLOAT_NUMBER_TEST
            and edx, MIDI_FLOAT_VALUE_TEST

            push eax    ;// n
            push edx    ;// v n

            mov [esi].midiin.tracker.number, eax    ;// store the number

            fld math_1_128          ;// sV
            fild DWORD PTR [esp]    ;// V
            fmul

            .IF !([ebp].tracker_flags & MIDIIN_NOTE_TRACKER_FREQ)

                fld math_1_32768        ;// sN  V
                fild DWORD PTR [esp+4]  ;// iN  sN  V
                fmul                    ;// N

            .ELSE

                shr eax, 8-2    ;// make note number a dword offset
                add eax, math_pChromatic
                fld DWORD PTR [eax]

            .ENDIF

            mov edx, math_neg_1 ;// note is ON
            mov eax, [ebp].tracker_stamp    ;// get the stamp from tracker
            add esp, 8

            inc [ebp].tracker_stamp ;// bump the tracker stamp

            fxch                    ;// fV  fN
            mov [esi].midiin.tracker.stamp, eax ;// store this even'ts tracker stamp
            fstp [esi].data_V[ecx*8+4]      ;// store V in NEXT sample
            mov [esi].data_e[ecx*8+4], edx  ;// store e in NEXT SAMPLE
            mov eax, PIN_CHANGING
            fstp [esi].data_N[ecx*8+4]      ;// store N in NEXT sample
            inc [esi].midiin.fill_skew      ;// bump the skew value
            ;// this also requires that we set pin changing
            or [esi].pin_N.dwStatus, eax
            or [esi].pin_V.dwStatus, eax
            or [esi].pin_e.dwStatus, eax
            jmp process_next_event          ;// onward to next event


        ALIGN 16
        process_locate_existing:
        ;// hit for NOTE_ON(V=0) NOTE_OFF and NOTE_PRESS
        ;// eax = full event

IFDEF USE_TRACKER_DUMP

    .DATA
    sz_tracker_locate   db  'LOCATING EXISTING  '
    .CODE

    pushad
    invoke WriteFile, hTracker, OFFSET sz_tracker_locate, SIZEOF sz_tracker_locate, esp, 0
    popad

ENDIF

            ;// locate an osc with this note that is active
            ;// we'll do a 2X loop

            slist_GetHead tracker_dest, esi, ebp
            and eax, MIDI_FLOAT_NUMBER_TEST ;// mask off the extra (numbers are stored in shifted form)
            xor edx, edx                    ;// checks for event on
            .REPEAT
                .IF eax == [esi].midiin.tracker.number  ;// if this our number ?
                    cmp edx, [esi].midiin.tracker.event ;// see if there's an event here
                    jne process_found_existing          ;// if yes, then we found existing
                .ENDIF
                slist_GetNext tracker_dest, esi
                test esi, esi
                jz process_next_event   ;// ignore notes not in table
                .IF eax == [esi].midiin.tracker.number  ;// if this our number ?
                    cmp edx, [esi].midiin.tracker.event ;// see if there's an event here
                    jne process_found_existing          ;// if yes, then we found existing
                .ENDIF
                slist_GetNext tracker_dest, esi
            .UNTIL !esi
            jmp process_next_event  ;// ignore notes not in table



        ALIGN 16
        process_found_existing:
        ;// hit for NOTE_ON(V=0), NOTE_OFF and NOTE_PRESS
        ;//
        ;// state:
        ;//
        ;//     esi = osc
        ;//     eax = note number
        ;//     edx = 0

            ;// if NOTE_OFF, turn the note off
            ;// if NOTE_PRESS, update the velocity

            mov eax, [ebx+ecx*8].evt        ;// get the event from the stream
            mov edx, eax                    ;// store in edx too
            and eax, MIDI_FLOAT_COMMAND_TEST;// mask out all but the command
            ;// cmp with middle command value
            cmp eax, MIDI_FLOAT_NOTEON AND MIDI_FLOAT_COMMAND_TEST
            ja got_existing_note_press  ;// below, NOTE_OFF. equal, NOTE_ON(V=0)
                                        ;// above, NOTE_PRESS

        got_existing_note_off:  ;// fall through is most common event

IFDEF USE_TRACKER_DUMP

    .DATA
    sz_tracker_enote_off    db  '___EXISTING_NOTE_OFF'
    .CODE

    pushad
    invoke WriteFile, hTracker, OFFSET sz_tracker_enote_off, SIZEOF sz_tracker_enote_off, esp, 0
    popad

ENDIF


            ;// get the release velocity
            ;// also store the old note (fill advance won't catch the last one)
            ;// toggle e to 0

            ;// edx has the full event

            mov eax, [ebp].tracker_stamp    ;// get the stamp from tracker
            and edx, MIDI_FLOAT_VALUE_TEST  ;// mask value out of event
            push edx                        ;// store int value on the stack
            fld  math_1_128                 ;// load the scaling value
            inc [ebp].tracker_stamp         ;// increase the tracker stamp
            fild DWORD PTR [esp]            ;// load the number to scale
            mov [esi].midiin.tracker.stamp, eax ;// store this even'ts tracker stamp
            fmul                            ;// scale the velocity
            mov eax, [esi].midiin.last_fill ;//get the last filled index
            shl eax, 3                      ;// turn eax into an offset
            xor edx, edx                    ;// clear the event
            .IF [esi].midiin.fill_skew      ;// if we were skewed, the last event is plus 4
                add eax, 4
            .ENDIF
            mov eax, [esi].data_N[eax]      ;// get the last known note number
            add esp, 4                      ;// clean up the stack
            mov [esi].midiin.tracker.event,edx;// reset tracker event to zero
            mov [esi].data_e[ecx*8], edx    ;// store 0 in destination data
            fstp [esi].data_V[ecx*8]        ;// store scaled value to V data
            mov [esi].data_N[ecx*8], eax    ;// store the last known note number
            invoke midiin_fill_Advance      ;// call advance to do the fill
            jmp process_next_event          ;// onward to next event

        ALIGN 16
        got_existing_note_press:

IFDEF USE_TRACKER_DUMP

    .DATA
    sz_tracker_enote_press  db  '___EXISTING_NOTE_PRESSURE'
    .CODE

    pushad
    invoke WriteFile, hTracker, OFFSET sz_tracker_enote_press, SIZEOF sz_tracker_enote_press, esp, 0
    popad

ENDIF



            ;// store the new velocity
            ;// also store the old note (fill advance won't catch the last one)
            ;// edx has the full event

            mov eax, [ebp].tracker_stamp    ;// get the stamp from tracker
            and edx, MIDI_FLOAT_VALUE_TEST  ;// mask value out of event
            inc [ebp].tracker_stamp         ;// increase the tracker stamp
            push edx                        ;// store int value on the stack
            fld  math_1_128                 ;// load the scaling value
            fild DWORD PTR [esp]            ;// load the number to scale
            mov [esi].midiin.tracker.stamp, eax ;// store this even'ts tracker stamp
            fmul                            ;// scale it
            add esp, 4                      ;// clean up the stack
            mov eax, [esi].midiin.last_fill
            shl eax, 3                      ;// turn eax into an offset
            .IF [esi].midiin.fill_skew      ;// if fill skew is on, we have to add 4
                add eax, 4
            .ENDIF
            mov eax, [esi].data_N[eax]
            fstp [esi].data_V[ecx*8]        ;// store scaled value to V data
            mov [esi].data_N[ecx*8], eax
            invoke midiin_fill_Advance      ;// call advance to do the fill
            jmp process_next_event          ;// onward to next event

        ALIGN 16
        process_found_empty_object:
        ;// this is hit only for NOTE_ON

IFDEF USE_TRACKER_DUMP

    .DATA
    sz_tracker_mnote_on db  '___EMPTY_NOTE_ON'
    .CODE

    pushad
    invoke WriteFile, hTracker, OFFSET sz_tracker_mnote_on, SIZEOF sz_tracker_mnote_on, esp, 0
    popad

ENDIF

            mov eax, [ebx+ecx*8].evt
            mov edx, eax
            and eax, MIDI_FLOAT_NUMBER_TEST
            and edx, MIDI_FLOAT_VALUE_TEST

            push eax    ;// n
            push edx    ;// v n

            fld math_1_128          ;// sV
            fild DWORD PTR [esp]    ;// iV  sV
            fmul                    ;// V

            mov [esi].midiin.tracker.number, eax    ;// store the number

            .IF !([ebp].tracker_flags & MIDIIN_NOTE_TRACKER_FREQ)

                fld math_1_32768        ;// sN  V
                fild DWORD PTR [esp+4]  ;// iN  sN  V
                fmul                    ;// N

            .ELSE

                shr eax, 8-2    ;// make note number a dword offset
                add eax, math_pChromatic
                fld DWORD PTR [eax]

            .ENDIF

            mov edx, math_neg_1
            mov eax, [ebp].tracker_stamp    ;// get the stamp from tracker
            add esp, 8

            mov [esi].midiin.tracker.event, 1
            inc [ebp].tracker_stamp
            mov [esi].midiin.tracker.stamp, eax ;// store this even'ts tracker stamp
            fstp [esi].data_N[ecx*8]
            mov [esi].data_e[ecx*8], edx
            fstp [esi].data_V[ecx*8]
            invoke midiin_fill_Advance      ;// call advance to do the fill
        ;// jmp process_next_event          ;// onward to next event

        ALIGN 16
        process_next_event:

IFDEF USE_TRACKER_DUMP

    .DATA
    sz_tracker_crlf db  0dh,0ah
    .CODE

    pushad
    invoke WriteFile, hTracker, OFFSET sz_tracker_crlf, SIZEOF sz_tracker_crlf, esp, 0
    popad

ENDIF


            midistream_IterNext [ebx], ecx, top_of_process_loop

        ;//ALIGN 16 ( only hit at loop initialize, no need to align
        process_loop_done:

IFDEF USE_TRACKER_DUMP

    pushad
    invoke WriteFile, hTracker, OFFSET sz_tracker_crlf, SIZEOF sz_tracker_crlf, esp, 0
    invoke CloseHandle, hTracker
    popad

ENDIF

            ;// now we call fill_end for all attached objects

            slist_GetHead tracker_dest, esi, ebp
            .REPEAT
                invoke midiin_fill_End
                slist_GetNext tracker_dest, esi
            .UNTIL !esi

    ;//ALIGN 16
    done_with_tracker:  ;// only hit at pre loop, no need to align

        ret

tracker_Calc ENDP




ASSUME_AND_ALIGN
END





