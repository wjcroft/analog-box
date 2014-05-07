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
;// locktable.asm       routines to work with lock tables
;//
;// locktable_Lock
;// locktable_Unlock
;//
;// locktable_GetSize_Z
;// locktable_Save_Z
;//
;// locktable_GetSize_S
;// locktable_Save_S
;//
;// locktable_Load


OPTION CASEMAP:NONE
.586
.MODEL FLAT

    .NOLIST
    INCLUDE <abox.inc>
    INCLUDE <groups.inc>
    INCLUDE <misc.inc>
    .LIST


.DATA

    ;// lock table needs a fake base class to be able to load it from a file
    ;// there is much wasted space here, too bad ?

        osc_LockTable   OSC_CORE { locktable_Load }
                        OSC_GUI     {}
                        OSC_HARD    {}
                        OSC_DATA_LAYOUT { ,,,BASE_ALLOCATES_MANUALLY }


.CODE



;////////////////////////////////////////////////////////////////////
;//
;//
;//     Lock and Unlock
;//


ASSUME_AND_ALIGN
locktable_Lock PROC uses esi

    ;// task, make sure all selected items are in the same lock list

    ASSUME ebp:PTR LIST_CONTEXT

    ;//         do not allow 1 item to be locked
    ;//         reset oscL.MRS
    ;//         scan oscS
    ;//         is this item locked ?
    ;// nL          add this item to oscL
    ;// yL      yes:is oSCL.MRS set yet ?
    ;// yLnM        no: set oscL.MRS = this
    ;// yLyM        yes:is this item in oscL ?
    ;// yLyMnL          no: splice this list into lock anchor
    ;// yLyMyL          yes:ok to ignore
    ;//
    ;//     always check if oscL.pNext = self


    ;// do not allow 1 item to be locked

        clist_GetMRS oscS, esi, [ebp]
        cmp esi, clist_Next(oscS,esi)   ;//[esi].pNextS
        je all_done

    ;// reset oscL.MRS

        xor eax, eax    ;// keep cleared for checking zero
        clist_SetMRS oscL, eax, [ebp]

    ;// scan oscS, using esi

        .REPEAT

            cmp eax, clist_Next(oscL,esi)   ;//[esi].pNextL         ;//     is this item locked ?
            jnz lock_yL

lock_nLyM:  clist_Insert oscL, esi,, [ebp]  ;// nLyM        yes:add this item to oscL
            GDI_INVALIDATE_OSC HINTI_OSC_GOT_LOCK_SELECT
            jmp lock_next

lock_yL:    cmp eax, clist_MRS(oscL,[ebp])  ;// yL      yes:is oscL.MRS set yet ?
            jnz lock_yLyM

lock_yLnM:  clist_SetMRS oscL, esi, [ebp]   ;// yLnM        no: set oscL.MRS = this
            jmp lock_next

lock_yLyM:                                  ;// yLyM        yes:is this item in oscL ?
            clist_IfInListGoto oscL, esi,lock_yLyMyL,,[ebp]

lock_yLyMnL:clist_Merge oscL,esi,,,[ebp]    ;// yLyMnL          no: splice this list into lock anchor
lock_yLyMyL:                                ;// yLyMyL          yes:ok to ignore

lock_next:  clist_GetNext oscS, esi         ;// next    get next osc in sel list
            xor eax, eax

        .UNTIL esi == clist_MRS(oscS,[ebp])

    ;// as a final touch, we clear the selection

        invoke context_UnselectAll




    all_done:

        ret


locktable_Lock ENDP


ASSUME_AND_ALIGN
locktable_Unlock PROC   uses esi

    ;// task:   remove all selected items from any lock list
    ;//         keep track of single lock list and don't allow them
    ;//         make sure MRS is valid

        ASSUME ebp:PTR LIST_CONTEXT

        clist_GetMRS oscS, esi, [ebp]   ;// get start of MRS

        DEBUG_IF <!!esi>    ;// empty sel list, why are we calling this ?

    sel_scan_top:

        ;// remove will check for existance for us
        clist_Remove oscL, esi,,[ebp], <GDI_INVALIDATE_OSC HINTI_OSC_LOST_LOCK_SELECT>
        ;// remove will also invalidate if it's removed

        clist_GetNext oscS, esi         ;// get next selected item
        cmp esi, clist_MRS(oscS,[ebp])  ;// same as first ?

        jne sel_scan_top                ;// done if same as first

    sel_scan_done:

        ;// now we walk the z list and make sure the oscL's are correct
        ;// we also verify that the MRS is correct

        dlist_GetHead oscZ, esi, [ebp]

        xor ecx, ecx                    ;// keep clear for testing
        mov clist_MRS(oscL,[ebp]), ecx  ;// reset the MRS

    clean_scan_top:

        or ecx, clist_Next(oscL,esi)    ;//[esi].pNextL ;// load and test the next item
        jz clean_iterate        ;// jump to next osc if not locked

        cmp esi, ecx            ;// point at self ?
        je  clean_unlock        ;// jump to unlock if yes

        mov clist_MRS(oscL,[ebp]), ecx  ;// set the MRS
        xor ecx, ecx            ;// keep clear for testing

    clean_iterate:

        dlist_GetNext oscZ, esi ;// get next osc
        cmp esi, ecx            ;// empty ??
        jne clean_scan_top      ;// jump to top if not empty

    clean_done:

        ret

    clean_unlock:

        xor ecx,ecx
        GDI_INVALIDATE_OSC HINTI_OSC_LOST_LOCK_SELECT
        mov clist_Next(oscL,esi), ecx   ;// [esi].pNextL, ecx
        jmp clean_iterate

locktable_Unlock ENDP



;////////////////////////////////////////////////////////////////////
;//
;//                                 context_GetLockTableSize
;//     L O C K   T A B L E         locktable_Save
;//                                 locktable_Load
comment ~ /*

    a lock table is arranged as a list of arrays of indexes
    each array of indexes specifies specifies a clist of locked items
    index are always in the z-order

    for saveing we count forwards from the head
    for loading we count backwards

    if using a copy operation, we use the S-list for saveing and loading

    so: we need to know how many objects have been loaded: use header num oscs
    then we have to count many time

    save format:
    FILE_OSC    ID      = ID_LOCKTABLE
                numPins = 0
                pos.X = 0
                pos.Y = 0
                extra = size of the table

    LOCK_ARRAY  numEntries  = number of dwords that follow
        entry = z-index of an object to lock
        entry
        entry


*/ comment ~


ASSUME_AND_ALIGN
locktable_GetSize_Z   PROC

    ASSUME ebp:PTR LIST_CONTEXT
    ASSUME ebx:PTR DWORD

    ;// scan through z_list
    ;//     look for locked items
    ;//     for each found
    ;//         add 4 for the count
    ;//         scan the chain
    ;//             add 4 for each item
    ;//             set the ALREADY_PROCESSED bit
    ;// rescan the z_list
    ;//     turn off ALREADY_PROCESSED


    ;// SCAN 1      look for locked chains and account

        dlist_GetHead oscZ, esi, [ebp]
        DEBUG_IF <!!esi>    ;// lock table with no z_list !!!

        .REPEAT

            .IF clist_Next(oscL,esi)    ;//[esi].pNextL

                bts [esi].dwHintOsc, LOG2(HINTOSC_STATE_PROCESSED)
                .IF !CARRY?     ;// new lock group

                    GET_OSC_FROM ecx, esi   ;// xfer to iterator
                    add [ebx], 8            ;// count + first item
                    jmp L1                  ;// jump to loop enter
                    .REPEAT
                        add [ebx], 4        ;// bump the count
                        or [ecx].dwHintOsc, HINTOSC_STATE_PROCESSED ;// set the flag
                L1:     clist_GetNext oscL, ecx ;// next locked item
                    .UNTIL ecx == esi
                .ENDIF
            .ENDIF
            dlist_GetNext oscZ, esi

        .UNTIL !esi

    ;// SCAN 2  reset the processed bit

        CLEAR_PROCESSED_BIT Z

    ;// that's it !

        ret

locktable_GetSize_Z   ENDP

ASSUME_AND_ALIGN
locktable_Save_Z PROC uses esi ebx

    ASSUME edi:PTR FILE_OSC
    ASSUME ebp:PTR LIST_CONTEXT

    ;// this involves a lot of searching

    ;// scan the Z list
    ;// look for locked items
    ;// for each group
    ;// remember the pointer to the count
    ;//     store zero
    ;//     for each pointer in the lock list
    ;//     scan Z list and determine where it is
    ;//     store that index and continue on


    ;// setup the FILEOSC header

        push edi    ;// store for cleanup
.IF !context_bCopy  ;// ABOX232 oops, we have to usurp this becuse we are in a closed group being copied
        mov eax, IDB_LOCKTABLE
.ELSE
        mov eax, OFFSET osc_LockTable
.ENDIF


        stosd           ;// id
        xor eax, eax
        mov ecx, 4
        rep stosd       ;// numpins
                        ;// X
                        ;// Y
                        ;// extra

    ;// store the lock table

        dlist_GetHead oscZ, esi, [ebp]

        ASSUME ebx:PTR DWORD        ;// counts lock table entries
        ASSUME edx:PTR OSC_OBJECT   ;// edx iterates l list
                                    ;// ecx iterates z list
    ;// eax must remain zero for testing

    locate_locked_chains:

        cmp eax, clist_Next(oscL,esi)   ;// [esi].pNextL    ;// locked ?
        jz L3           ;// jump if not locked

        bts [esi].dwHintOsc, LOG2(HINTOSC_STATE_PROCESSED)  ;// already hit ?
        jc L3           ;// skip if already hit

    ;// iterate through the locks list using edx

        mov ebx, edi    ;// remeber the count position
        stosd           ;// store zero for first count
        mov edx, esi    ;// xfer pointer to edx (will scan locked items)

    ;// find the z index of this locked item
    ;// iterate ecx until it equals edx

    L0: dlist_GetHead oscZ, ecx, [ebp]  ;// start at start of zlist
    L1: cmp ecx, edx    ;// target osc ?
        je L2           ;// exit if so
        inc eax         ;// increase the count
        dlist_GetNext oscZ, ecx
        DEBUG_IF <!!ecx>;// osc in l list is not in the zlist !!
        cmp ecx, edx    ;// target osc ?
        je L2           ;// exit if so
        inc eax         ;// increase the count
        dlist_GetNext oscZ, ecx
        DEBUG_IF <!!ecx>;// osc in l list is not in the zlist !!
        jmp L1          ;// do until found

    L2: or [ecx].dwHintOsc, HINTOSC_STATE_PROCESSED
        inc [ebx]       ;// increase the osc count
        stosd           ;// store the index

        clist_GetNext oscL, edx ;// get next lock item
        xor eax, eax    ;// zero
        cmp edx, esi    ;// same as first item in chain ?
        jne L0          ;// continue if more

    ;// next osc in the z list [esi]

    L3: dlist_GetNext oscZ, esi
        or esi, esi ;// done ?
        jnz locate_locked_chains    ;// continue on if not done

    ;// clean up

        ASSUME ebx:PTR FILE_OSC
        pop ebx                         ;// retireve FILEOSC pointer
        lea eax, [edi-SIZEOF FILE_OSC]  ;// end - sizeof table
        sub eax, ebx                    ;// - start = extra size
        mov [ebx].extra, eax            ;// store as extra

        CLEAR_PROCESSED_BIT Z

    ;// that should do it

        ret

locktable_Save_Z ENDP




ASSUME_AND_ALIGN
locktable_GetSize_S   PROC uses edi

    ASSUME ebp:PTR LIST_CONTEXT
    ASSUME ebx:PTR DWORD    ;// where we accumulate to

    ;// we return 1 if there would be a valid table
    ;// we return zero if the table would not be valid


    ;// this is a little different
    comment ~ /*

        since we are copying, we want the new lock to be private
        to the selected objects

        so instead of scanning the Z list, we scan the S list

        if a locked item is not also selected, then we skip it
        then we have to double back and make sure we never allow a single lock

    */ comment ~

    ;// SCAN 1      look for locked chains and account

        xor edi, edi        ;// edi will be the return value
        clist_GetMRS oscS, esi, [ebp]
        DEBUG_IF <!!esi>    ;// nothing selected ?!

        .REPEAT

            .IF clist_Next(oscL,esi)    ;// [esi].pNextL                ;// is this item locked ?

                BITS [esi].dwHintOsc, HINTOSC_STATE_PROCESSED;// set and test the processed bit
                .IF !CARRY?                 ;// new lock group ?

                    GET_OSC_FROM ecx, esi   ;// xfer current osc to iterator
                    xor edx, edx            ;// start counting
                    jmp L1                  ;// jump to entrance

                    .REPEAT     ;// scan this lock chain

                    .IF clist_Next(oscS,ecx)    ;// [ecx].pNextS    ;// is item selected ?
                        or [ecx].dwHintOsc, HINTOSC_STATE_PROCESSED ;// set the flag
                        inc edx         ;// increase the count
                    .ENDIF

                    L1: clist_GetNext oscL, ecx ;// next locked item

                    .UNTIL ecx == esi

                    .IF edx                 ;// do we have a valid lock, edx is the count

                        lea edi, [edi+edx*4+8]  ;// new array + first item + num items

                    .ENDIF

                .ENDIF

            .ENDIF

            clist_GetNext oscS, esi

        .UNTIL esi == clist_MRS( oscS, [ebp] )

    ;// SCAN 2      reset the processed bit

        CLEAR_PROCESSED_BIT S

    ;// clean up and return what we're supposed to

        xor eax, eax
        .IF edi ;// anything ?

            add edi, SIZEOF FILE_OSC    ;// add on the header size

            add [ebx], edi  ;// accumulate the size
            inc eax         ;// return 1

        .ENDIF

    ;// that's it !

        ret

locktable_GetSize_S   ENDP


ASSUME_AND_ALIGN
locktable_Save_S PROC uses esi ebx

    ASSUME edi:PTR FILE_OSC
    ASSUME ebp:PTR LIST_CONTEXT

    ;// this involves a lot of searching

    ;// scan the S list
    ;// look for locked items
    ;// for each group
    ;// remember the pointer to the count
    ;//     store zero
    ;//     for each pointer in the lock list
    ;//     scan S list and determine where it is
    ;//         if it's not found, keep track of that
    ;//         and be prepared to erase that group
    ;//     store that index and continue on

    ;// setup the FILEOSC header

        push edi        ;// store for cleanup

        mov eax, OFFSET osc_LockTable ;// IDB_LOCKTABLE
        stosd           ;// id
        xor eax, eax
        mov ecx, 4
        rep stosd       ;// numpins
                        ;// X
                        ;// Y
                        ;// extra

    ;// store the lock table

        clist_GetMRS oscS, esi, [ebp]
        DEBUG_IF <!!esi>    ;// nothing selected !!

comment ~ /*


    look for locked items
    trace the lock chain and locate selected items

    store each, maintain a count

*/ comment ~


    .REPEAT

        .IF clist_Next(oscL,esi)    ;// [esi].pNextL    ;// locked ?

            BITS [esi].dwHintOsc, HINTOSC_STATE_PROCESSED   ;// already hit ?
            .IF !CARRY?

                GET_OSC_FROM ecx, esi   ;// ecx iterates the lock chain

                xor eax, eax        ;// eax counts into the S list
                mov ebx, edi        ;// save so we can count or backup ebx,
                ASSUME ebx:PTR DWORD;// points at the number of entries in the array
                stosd               ;// save a default count of zero

                .REPEAT         ;// trace the lock chain

                    .IF clist_Next(oscS,ecx)    ;// [ecx].pNextS    ;// item must be selected

                        ;// locate the S index for this item

                        xor eax, eax                    ;// eax will count indexes
                        clist_GetMRS oscS, edx, [ebp]   ;// edx will iterate the S list
                        .WHILE edx != ecx           ;// scan until we find it
                            inc eax
                            clist_GetNext oscS, edx ;// will crash if not found
                        .ENDW

                        stosd       ;// store the index
                        inc [ebx]   ;// increase the count

                        or [ecx].dwHintOsc, HINTOSC_STATE_PROCESSED ;// set the processed bit

                    .ENDIF

                    clist_GetNext oscL, ecx ;// trace to next lock item

                .UNTIL ecx == esi

                ;// make sure we found something
                .IF [ebx] < 2       ;// nope, bad table
                    mov edi, ebx    ;// back up
                .ENDIF

            .ENDIF

        .ENDIF

        clist_GetNext oscS, esi

    .UNTIL esi == clist_MRS( oscS, [ebp] )


    ;// clean up

    pop ebx                         ;// retireve FILEOSC pointer
    ASSUME ebx:PTR FILE_OSC

    lea eax, [edi-SIZEOF FILE_OSC]  ;// end - sizeof table
    sub eax, ebx                    ;// - start = extra size
    mov [ebx].extra, eax            ;// store as extra

    CLEAR_PROCESSED_BIT S

    ;// that should do it

        ret

locktable_Save_S ENDP























;///////////////////////////////////////////////////////////
;//
;//     LOAD
;//



ASSUME_AND_ALIGN
locktable_Load  PROC

    ;// all the osc are loaded

        ASSUME ebp:PTR LIST_CONTEXT ;// preserve
        ASSUME ebx:PTR FILE_OSC     ;// may destroy
        ASSUME edx:PTR FILE_HEADER  ;// may destroy

    ;// PART 1

    ;// lock tables are z indexes at SAVE time
    ;// when loading, oscs are inserted at the head
    ;// so the lock table index now corresponds to a reversed index
    ;// so: we have to determine where to start counting backwards from
    ;// to do this we scan the zlist forwards for the number of osc's specified
    ;// by FILE_HEADER.numOsc
    ;// at the same time, we have to verify that osc's that didnt' load are NOT vounted


        ;// a) determine the number of objects
        ;//     FILE_HEADER.numOsc is telling us the number of records
        ;//     we know there is one extra for the lock table
        ;//     there may also be an extra for a bus table, and/or a group id table

        push clist_MRS( oscL, [ebp] )   ;// old_mrs -----------------------------------------

        lea eax, [ebx+SIZEOF FILE_OSC]  ;// get the adress of the first lock entry
        push eax                        ;// st_first_lock -----------------------------------

        mov ecx, [edx].numOsc           ;// get the number of records
        FILE_OSC_TO_NEXT_OSC ebx        ;// scoot to next record
        push ebx                        ;// st_last_lock ------------------------------------
        cmp ebx, [edx].pEOB             ;// see if at end (will set carry if not)
        dec ecx                         ;// account for lock table (carry not effected)
        jnc @F                          ;// skip if lock table is last record
        FILE_OSC_TO_NEXT_OSC ebx        ;// scoot to next record
        cmp ebx, [edx].pEOB             ;// are we at the end yet ?
        dec ecx                         ;// subtract one more for the next record
        jnc @F
        dec ecx
    @@:
        ;// ecx has the number of oscs in the file

        IFDEF DEBUGBUILD
        or ecx, ecx
        DEBUG_IF < SIGN? || ZERO? >     ;// the osc count cannot be correct !!
        ENDIF

        ;// b) count forward the number of oscs specified
        ;//     do not count bad file objects

        dlist_GetHead oscZ,esi,[ebp]
        FILE_HEADER_TO_FIRST_OSC edx, ebx
        push ebx                        ;// st_first_file -----------------------------------
        jmp L0

        .REPEAT
            .IF [ebx].pBase
                dlist_GetNext oscZ, esi
            .ENDIF
            FILE_OSC_TO_NEXT_OSC ebx
        L0: dec ecx
        .UNTIL ZERO?
        push esi                        ;// st_first_osc -------------------------------------

    ;// stack
    ;//
    ;// first_osc   first_file  last_lock   first_lock  old_mrs
    ;// 00          04          08          0C

        st_first_osc    TEXTEQU <(DWORD PTR [esp+00h])>
        st_first_file   TEXTEQU <(DWORD PTR [esp+04h])>
        st_last_lock    TEXTEQU <(DWORD PTR [esp+08h])>
        st_first_lock   TEXTEQU <(DWORD PTR [esp+0Ch])>
        stack_size = 10h

    ;// part 2
    ;//
    ;//     process the lock list

    ;// esi scans oscs
    ;// ebx scans the file

        mov ecx, st_first_lock  ;// get the start of the lock table

        .REPEAT     ;// scanning groups of lock lists

            mov edx, [ecx]              ;// get the count for this group
            clist_SetMRS oscL, 0, [ebp] ;// reset the MRS

            .REPEAT     ;// scan the lock group

                mov edi, [ecx+edx*4]    ;// get the z index we're to look for
                mov ebx, st_first_file  ;// start scanning the file from the start
                mov esi, st_first_osc   ;// start scanning the z_list from where we decided
                jmp L1                  ;// enter at the loop iteration
                .REPEAT
                    .IF [ebx].id                ;// don't stop on bad objects
                        dlist_GetPrev oscZ, esi ;// set esi as previous
                    .ENDIF
                    FILE_OSC_TO_NEXT_OSC ebx    ;// always advance the file
                L1: dec edi                     ;// have we counted enough ?
                .UNTIL SIGN?

            ;// now, esi is at an osc, we'll know if it's the right one if id is ok

                .IF [ebx].id    ;// this osc is the one
                    clist_Insert oscL, esi,, [ebp]      ;// insert into lock chain
                    or [esi].dwHintI, HINTI_OSC_GOT_LOCK_SELECT;// tell gdi to display correctly
                .ENDIF

            ;// now we continue with the next osc

                dec edx     ;// decrease the count remaining in this group

            .UNTIL ZERO?

        ;// we are done with a group
        ;// check that the osc does not have a single lock

            clist_GetMRS oscL, esi, [ebp]   ;// get the MRS
            .IF esi && esi == clist_Next(oscL,esi)  ;// [esi].pNextL    ;// check for 0 and 1 objects
                clist_SetMRS oscL, 0, [ebp] ;// remove this osc
                mov clist_Next(oscL,esi), 0 ;//[esi].pNextL, 0          ;// set mrs correctly
                and [esi].dwHintI, NOT HINTI_OSC_GOT_LOCK_SELECT;// turn off the gdi bit
            .ENDIF

        ;// now we iterate to the next lock group

            mov eax, [ecx]          ;// get the count of items
            lea ecx, [ecx+eax*4+4]  ;// advance to next group (cur + num_indexes + 1 dword

        .UNTIL ecx >= st_last_lock  ;// done when go passed last lock

    ;// we made it !!
    ;// now we clean up the stack and beat it

        add esp, stack_size

        pop edx ;// retrieve the MRS
        .IF edx
            mov clist_MRS( oscL, [ebp] ), edx   ;// reset the lock head
        .ENDIF

        xor eax, eax    ;// must return that we do NOT want to continue
        ret

locktable_Load  ENDP


;//
;//
;//
;//
;////////////////////////////////////////////////////////////////////



ASSUME_AND_ALIGN
END