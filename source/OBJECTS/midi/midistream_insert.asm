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
;//     midistream_insert.asm
;//
OPTION CASEMAP:NONE
.586
.MODEL FLAT

    .NOLIST
    INCLUDE <abox.inc>
    INCLUDE <midi2.inc>
    .LIST



;// massive bug hunt


IFDEF DEBUGBUILD
VERIFY_INSERT EQU 1     ;// rem this to turn off insert checking
IFDEF VERIFY_INSERT
.DATA
    verify_count    dd  0
ENDIF
ENDIF


midiinsert_VERIFY_FIRST MACRO

    LOCAL top_of_count, done_with_count

    ;// destroys eax, edx

    IFDEF VERIFY_INSERT
    ;// count events before insert

        mov verify_count, 1
        xor edx, edx

        midistream_IterBegin [esi], edx, done_with_count

    top_of_count:
        inc verify_count
        midistream_IterNext [esi], edx, top_of_count
    done_with_count:

    ENDIF

    ENDM

midiinsert_VERIFY_LAST MACRO

    LOCAL top_of_count, done_with_count

    ;// destroys eax, edx

    IFDEF VERIFY_INSERT
    ;// count events before insert

    .IF ecx ;// don't bother if we'e inserting at first sample

        xor edx, edx
        midistream_IterBegin [esi], edx, done_with_count

    top_of_count:
        dec verify_count
        midistream_IterNext [esi], edx, top_of_count
    done_with_count:

        DEBUG_IF <verify_count>

    .ENDIF

    ENDIF

    ENDM








.CODE

ASSUME_AND_ALIGN
PROLOGUE_OFF
midistream_Insert PROC STDCALL stream:DWORD, index:DWORD, event:DWORD
                    ;// 00      04          08          12

    ;// return no carry if stream is not full
    ;// return carry if stream is full

    ;// destroys eax, edx
    ;// preserves the rest

        xchg esi, [esp+4]   ;// ptr to stream
        xchg ecx, [esp+8]   ;// index to insert at

        ASSUME esi:PTR MIDI_STREAM_ARRAY

    ;/////////////////////////////////////////////////////////////////////////

        midistream_VERIFY [esi], eax, edx   ;// must have valid input [esi]

    ;/////////////////////////////////////////////////////////////////////////

        midiinsert_VERIFY_FIRST

    ;/////////////////////////////////////////////////////////////////////////

        DEBUG_IF <ecx !>= MIDI_STREAM_LENGTH>   ;// can't insert passed end!!

        mov edx, [esi+LAST_STREAM].nxt      ;// get the last event

        test edx, edx                       ;// check for empty [esi]   ( edx is zero )
        jnz stream_has_events

        DEBUG_IF <[esi].nxt>            ;// bad [esi] (last is zero, but [0].nxt is set)

        cmp edx, ecx                    ;// (edx=0) check if we're inserting at the first event
        je check_if_first_event         ;// if we are, then make sure we aren't overwritting it

    insert_at_index:    ;// ok to insert at ecx

        lea eax, [ecx+MIDI_FLOAT_BIAS]  ;// turn into MIDI_FLOAT
        mov [esi+ecx*8].nxt, 0      ;// set the new nxt (do BEFORE setting last_event)
        mov [esi].nxt, eax              ;// set the new next for first item
        mov [esi+LAST_STREAM].nxt, eax  ;// set the new last( do AFTER setting ecx.nxt)

        midiinsert_VERIFY_LAST

        jmp do_the_insert   ;// exit

    check_if_first_event:   ;// edx = 0, ecx = 0

        cmp edx, [esi].evt  ;// see if there's an event at [0]
        je do_the_insert    ;// if not, then the [esi] is empty, we can exit now

        inc ecx             ;// otherwise, we insert at the next slot
        jmp insert_at_index

    ;/////////////////////////////////////////////////////////////////////////

    stream_has_events:  ;// [esi] has events in it

        ;// edx has the MIDI_FLOAT of LAST_STREAM

        sub edx, MIDI_FLOAT_BIAS                    ;// remove the bias
        DEBUG_IF < edx !>= MIDI_STREAM_LENGTH>  ;// last_event is not valid !!

        ;// edx = ecx of last event

        cmp ecx, edx            ;// see if we can append as the last event
        ja insert_after_last    ;// if ecx is greater, we can insert
        jb insert_before_last   ;// if less, then we have to scan
                                ;// if equal then ...
    ;// we equal last

        cmp ecx, MIDI_STREAM_LENGTH - 1
        ;// we're inserting at the last event
        ;// and the last event is full
        ;// have to find the last nxt that is not equal to 1
        ;// the scoot those back
        je scoot_records_back

        ;// otherwise, just bump the record forwards

        inc ecx

    insert_after_last:

        ;// edx indexes the last item

        lea eax, [ecx+MIDI_FLOAT_BIAS]  ;// add the bias
        mov [esi+ecx*8].nxt, 0          ;// set the new nxt (do BEFORE setting last_event)
        mov [esi+LAST_STREAM].nxt, eax  ;// set the new last(do AFTER setting ecx.nxt)
        sub eax, edx                    ;// subtract edx to get new next
        mov [esi+edx*8].nxt, eax        ;// set the new next

        midiinsert_VERIFY_LAST

        jmp do_the_insert   ;// exit

    insert_before_last:

        ;// [esi] has event(s)
        ;// ecx if before the last event

        xor edx, edx
        cmp edx, ecx                ;// check if we're inserting the first record
        jne not_the_first_record

    ;// we are trying to insert at the first record

        cmp edx, [esi].evt          ;// check if event is in use (edx=0)
        je do_the_insert_test       ;// exit if evnt can be used

    ;////////////////////////////////////////////////////////////////

        ;// we want to insert as the first event
        ;// the first event is in use
        ;// iterate forwards untill we find an empty slot
        ;//
        ;// this is hit from two locations
        ;// edx must be where we want to start skidding
        ;// ecx is presereved
        ;//
        ;// looking for first occurance of .nxt != 1
        ;// if we can't find it, the (rest of the) [esi] is full
        ;// if we find the end, or a non adjacent gap
        ;//     insert, update ecx, exit

    skid_forwards:

        mov eax, [esi+edx*8].nxt                    ;// get the nxt value
        test eax, eax                       ;// check for zero
        jz insert_after_r2_last         ;// if zero, then insert as next record

        sub eax, MIDI_FLOAT_BIAS+1      ;// turn into ecx offset
        DEBUG_IF <SIGN?>    ;// should have got caught earlier
        jnz insert_after_r2_not_last    ;// there is space AFTER this record
        ;// jz still have to increase (eax equaled 1)
        inc edx                         ;// next record
        cmp edx, MIDI_STREAM_LENGTH-1   ;// alwsy check for end
        je stream_is_full               ;// if hit, the entire frame is full

        jmp skid_forwards

    insert_after_r2_last:

        ;// edx is at the last record in the [esi]
        ;// we can insert ecx as the next record

        lea ecx, [edx+1]                ;// ecx is now next record
        mov [esi+edx*8].nxt, MIDI_FLOAT_BIAS + 1    ;// store the new next
        lea eax, [ecx+MIDI_FLOAT_BIAS]  ;// determine the new last ecx
        mov [esi+ecx*8].nxt, 0          ;// set our record as end of [esi]( do BEFORE setting last event)
        mov [esi+LAST_STREAM].nxt, eax  ;// store the previous record's next(do AFTER setting last_event)

        midiinsert_VERIFY_LAST

        jmp do_the_insert   ;// exit

    insert_after_r2_not_last:

        ;// edx is at the end of a chain
        ;// there are more records after the chain
        ;// we can insrt ecx as the next record
        ;// eax is one minus the offset to the next record
        ;//     which means it IS the next record for ecx

        DEBUG_IF <eax !>= MIDI_STREAM_LENGTH>   ;// bad [esi]

        lea ecx, [edx+1]                ;// ecx is now next record
        add eax, MIDI_FLOAT_BIAS            ;// determine the new next
        mov [esi+edx*8].nxt, MIDI_FLOAT_BIAS + 1    ;// store the new next
        mov [esi+ecx*8].nxt, eax        ;// set our record as eax

        midiinsert_VERIFY_LAST

        jmp do_the_insert           ;// exit

    ;////////////////////////////////////////////////////////////////

    ;// now we know that:
    ;//     we have events
    ;//     ecx is not zero
    ;//     ecx is before last_event

    not_the_first_record:

        DEBUG_IF <!!ecx>    ;// we thought ecx was not zero

    top_of_search:

        DEBUG_IF <edx !>= MIDI_STREAM_LENGTH-1> ;// not supposed to happen !!

        mov eax, [esi+edx*8].nxt
        lea eax, [edx+eax-MIDI_FLOAT_BIAS]          ;// advance to next ecx
        DEBUG_IF <eax !>= MIDI_STREAM_LENGTH>   ;// invalid [esi] !!

        cmp ecx, eax
        jb got_the_previous_item
        je index_is_the_next_item
        mov edx, eax
        jmp top_of_search

    index_is_the_next_item:

        ;// we are trying to insert on top of a previous item
        ;// eax indexes the next item
        ;// we want to skid forwrds

        mov edx, eax
        jmp skid_forwards

    stream_is_full:     ;// all records AFTER ecx are in use
                        ;// we abort now if ecx is at the start
        test ecx, ecx
        jz return_fail

    ;//////////////////////////////////////

    ;// now we have to scoot records back
    scoot_records_back:

        ;// we are going to scoot a portion of the [esi] back
        ;// then insert at LAST_STREAM
        ;// this means we have ecx, eax, edx to play with
        ;// we must preserve esi, edi and ecx

        ;// 1) locate P, the last non 1 record BEFORE ecx
        ;//     test with ecx to save a few iterations
        ;//     the assumption is that ecx has not changed
        ;// 2) scoot records from P.nxt to end back one MIDI_STREAM
        ;// 3) adjust P.nxt -= SIZEOF MIDI_STREAM
        ;// 4) set ecx as MIDI_STREAM - 1

        pushd 0     ;// need a storage location and we must preserve ecx
        xor edx, edx

    scoot_search_top:

        DEBUG_IF <edx !>= MIDI_STREAM_LENGTH>   ;// not supposed to happen !!

        cmp edx, ecx            ;// see if we're done (safe if ecx points at last_event)
        mov eax, [esi+edx*8].nxt            ;// load the next
        jae scoot_search_done   ;// done if edx >= ecx

        DEBUG_IF <!!eax>    ;// this is not supposed to happen

        .IF eax != MIDI_FLOAT_BIAS+1        ;// not equal 1 ?
            mov [esp], edx                  ;// store edx
        .ENDIF
        lea edx, [edx+eax-MIDI_FLOAT_BIAS]  ;// advance to next record
        cmp edx, ecx                ;// see if we're done (safe if ecx points at last_event)
        jb scoot_search_top         ;// and go back to top

    scoot_search_done:

        pop ecx             ;// now ecx is the last non1 record
        ;// we can be assured that ecx will NEVER equal last event
        DEBUG_IF <ecx==MIDI_STREAM_LENGTH-1>


    ;// ecx = last non 1 record
    ;//            ecx   ecx.nxt        end
    ;//------------|-----^---|---------------|
    ;//                  edi esi
    ;//         length = (STREAM_LENGTH - ecx) * 2
    ;//         source = ecx.nxt

        push esi
        push edi

        ;// assume that ecx does NOT = last ???

        dec [esi+ecx*8].nxt     ;// move previous back one record
        mov eax, [esi+ecx*8].nxt
        lea edx, [ecx+eax-MIDI_FLOAT_BIAS]  ;// edx is now ecx of record to move back
        lea edi, [esi+edx*8]    ;// edx ponts at the destination
        lea ecx, [edx*2-(MIDI_STREAM_LENGTH-1)*2]   ;// = -length
        lea esi, [edi+8]        ;// source is always the next record
        neg ecx
        DEBUG_IF <ZERO?>
        DEBUG_IF <SIGN?>

        rep movsd

        mov (MIDI_STREAM PTR [edi-8]).nxt, MIDI_FLOAT_BIAS + 1

        pop edi
        pop esi

        mov ecx, MIDI_STREAM_LENGTH - 1

        midiinsert_VERIFY_LAST

        jmp do_the_insert   ;// exit


    ;//////////////////////////////////////

    got_the_previous_item:

        ;// [esi+edx*8].next = ecx - edx
        ;// ecx.next = eax - ecx

        sub eax, ecx
        add eax, MIDI_FLOAT_BIAS
        mov [esi+ecx*8].nxt, eax

        lea eax, [ecx+MIDI_FLOAT_BIAS]
        sub eax, edx
        mov [esi+edx*8].nxt, eax

    do_the_insert_test:

        midiinsert_VERIFY_LAST

    do_the_insert:

        ;// ecx must be correct
        mov eax, [esp+12]
        DEBUG_IF <!!(eax & 00FFFFFFh)>  ;// not a valid command !!
        mov [esi+ecx*8].evt, eax

        midistream_VERIFY [esi], eax, edx;// check the results

        xchg esi, [esp+4]   ;// retrieve esi
        xchg ecx, [esp+8]   ;// retrieve ecx
        clc                 ;// return sucess
        ret 12  ;// STDCALL 3 args

    return_fail:

        stc
        ret 12  ;// STDCALL 3 args


midistream_Insert ENDP
PROLOGUE_ON


ASSUME_AND_ALIGN
END


