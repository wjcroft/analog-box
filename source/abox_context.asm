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
;// ABox_context.asm        routines that work with circuits at the context level
;//                         all function must have ebp set as the currect context
;//                         this file also includes the cut/copy/paste functions
;// TOC

;// context_New

;// context_GetFileSize
;// context_GetCopySize
;// context_Load
;// context_Save

;// context_PasteFile
;// context_Copy
;// context_Paste
;// context_Cut
;// context_Delete
;// context_MoveAll

;// context_UnselectAll

;// context_UpdateExtents



OPTION CASEMAP:NONE
.586
.MODEL FLAT

    .NOLIST
    INCLUDE <abox.inc>
    INCLUDE <groups.inc>
    INCLUDE <bus.inc>
    .LIST


.DATA

    ;// need this to make sure base id's do not get xlated

        context_bCopy   dd  0

    ;// group_recording

        context_group_recording dd 0
        ;// if this value is nonzero, context will check if any objects have id's
        ;// if so, an id table will stored with the file
        ;// this flag is managed by closed group
        ;// which is in turn enabled by unredo_BeginAction, unredo_EndAction


    ;// message for bad groups

        szBadGroup  db  'This Group contains a hardware device and can not be pasted.',0dh,0ah
                    db  '(Make sure the Group marker is not circled with red.)', 0
        szEmptyGroup db 'This Group is empty!',0dh,0ah
                    db  '(Make sure the Group marker touches another object.)',0

.CODE



PROLOGUE_OFF
ASSUME_AND_ALIGN
context_New PROC        ;// STDCALL uses esi edi

        ASSUME ebp:PTR LIST_CONTEXT ;// ebp must be the context we want to clear

        DEBUG_IF <!!(play_status & PLAY_GUI_SYNC)>  ;// supposed to be in play wait

        push esi
        push edi

    ;// set the doing new flag

        or [ebp].gFlags, GFLAG_DOING_NEW

    ;// destroy all oscs in this context

        dlist_GetHead oscZ, esi, [ebp]
        .WHILE esi

            dlist_GetNext oscZ, esi, edi    ;// get next first
            invoke osc_Dtor                 ;//(cause we're about to release the memory)
            mov esi, edi                    ;// use the next value to iterate with

        .ENDW

    ;// clear the list contexts

        xor eax, eax

        ;//dlist_Clear oscZ, [ebp]      ;// Z list
        ;//dlist_Clear oscI, [ebp]      ;// inval list
        mov dlist_Head(oscZ,[ebp]), eax
        mov dlist_Tail(oscZ,[ebp]), eax
        mov dlist_Head(oscI,[ebp]), eax
        mov dlist_Tail(oscI,[ebp]), eax


        mov slist_Head(oscC,[ebp]), eax ;//slist_SetHead oscC, eax, [ebp]   ;// calc list
        mov slist_Head(oscR,[ebp]), eax ;//slist_SetHead oscR, eax, [ebp]   ;// playable list
        clist_SetMRS  oscS, eax, [ebp]  ;// selected list
        clist_SetMRS  oscIC, eax, [ebp] ;// play thread playable list
        clist_SetMRS  oscL, eax, [ebp]  ;// lock list

        invoke bus_Clear                ;// clear the bus table

    ;// reset the doing new flag

        and [ebp].gFlags, NOT GFLAG_DOING_NEW
        or app_bFlags, APP_SYNC_EXTENTS

    ;// that's it

        pop edi
        pop esi

        ret

context_New ENDP
PROLOGUE_ON








ASSUME_AND_ALIGN
context_Load    PROC

    ;// this funtion is designed to APPEND new objects to the current context
    ;// it may be called recursively

    ASSUME edi:PTR FILE_HEADER
    ;// esi must be preserved
    ASSUME ebp:PTR LIST_CONTEXT

    invoke file_RealizeBuffer, edi,0,0  ;// realize the buffer, no ids, don't select
    invoke file_ConnectPins, edi        ;// connect all the pins

    ret

context_Load    ENDP







;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;//
;// utility and helper functions    context_GetLockTableSize
;//                                 context_GetBusTableSize
;//                                 context_GetFileSize
;//                                 context_GetCopySize





ASSUME_AND_ALIGN
context_GetFileSize PROC

    ASSUME ebp:PTR LIST_CONTEXT

    ;// task: determine the memory size needed to store this context to a file
    ;//
    ;//     ebx enters as a pointer to where to store this
    ;//     we ALWAYS ACUMULATE to this ptr
    ;//     return eax as the number of osc's in the circuit

    ;// destroys esi and edi

        ASSUME ebx:PTR DWORD

        pushd 0 ;// stack will be a pointer to the number oscs

    ;// stack looks like this:

    ;// numosc  ret ...
    ;// 00      04


    ;// iterate through all oscs in the circuit

        dlist_GetHead oscZ, esi, [ebp]
        .WHILE esi

            OSC_TO_BASE esi, edi                ;// load the base class
            inc DWORD PTR [esp]                 ;// update the osc count

            .IF [edi].gui.AddExtraSize          ;// class defined WSize ?
                invoke [edi].gui.AddExtraSize   ;// call it
            .ELSE                               ;// otherwise
                mov eax, [edi].data.numFileBytes;// add on the predetermined size
                add [ebx], eax                  ;// add it to the running total
            .ENDIF

            ;// add on the pins and the sizeof the FILE_OSC header

            mov eax, [edi].data.numPins         ;// get the number of the pins
            lea eax, [eax+eax*2]                ;// times 3
            lea eax, [eax*4+SIZEOF FILE_OSC]    ;// times 4 = size of the pin table
                                                ;// add the size of the osc file record
            add [ebx], eax                      ;// add it to the running total

            IFDEF WEBBBUILD
            ;// early out saves some time when counting
            ;// we need to check for ebp because this is called for closed groups
            .IF ebp == OFFSET master_context

                cmp ebx, 1024
                jae all_done

            .ENDIF
            ENDIF

            dlist_GetNext oscZ, esi             ;// iterate

        .ENDW

    ;// check for a lock table

        .IF [ebp].oscL_clist_MRS

            invoke locktable_GetSize_Z
            add [ebx], SIZEOF FILE_OSC  ;// locktable_ doesn't do this
            inc DWORD PTR [esp]     ;// adjust the osc count for the lock table

        .ENDIF

    ;// check for a bus string table

        .IF [ebp].pBusStrings || (bus_last_context == ebp && bus_table_is_dirty)

            invoke bus_AddExtraSize
            add [ebx], SIZEOF FILE_OSC  ;// bus_ doesn't do this
            inc DWORD PTR [esp]         ;// adjust the osc count for the bus table

        .ENDIF

    ;// check for a group id table

        .IF context_group_recording

            ;// the rule is: add 8 for any osc that has an id
            ;// then add FILE_OSC to that

            DEBUG_IF <ebp==OFFSET master_context>   ;// supposed to be inside a closed group !!

            dlist_GetHead oscZ, esi, [ebp]  ;// scan the z list
            xor eax, eax                    ;// count in eax
            .WHILE esi
                .IF [esi].id
                    inc eax
                .ENDIF
                dlist_GetNext oscZ, esi
            .ENDW
            .IF eax
                lea eax, [eax*8+SIZEOF FILE_OSC]
                add [ebx], eax
                inc DWORD PTR [esp]
            .ENDIF

        .ENDIF

    ;// retrieve the number of osc's and exit

;// all_done:

        pop eax

        ret

context_GetFileSize ENDP



ASSUME_AND_ALIGN
context_GetCopySize PROC uses ebp

        ASSUME ebp:PTR LIST_CONTEXT

    ;// task: determine the memory size needed to store the SELECTED OBJECTS
    ;//
    ;//     ebx enters as a pointer to where to store this
    ;//     return eax as the number of osc's in the circuit

        ASSUME ebx:PTR DWORD

        pushd 0     ;// stack will be a pointer to the number oscs

    ;// stack looks like this:

    ;// numosc  ret ...
    ;// 00      04


    ;// iterate through the select list for this context

        clist_GetMRS oscS, esi, [ebp]

        DEBUG_IF <!!esi>    ;// not suposed to call this is nothing is selected

        .REPEAT

            OSC_TO_BASE esi, edi        ;// load the base class
            inc DWORD PTR [esp]         ;// update the osc count

            .IF [edi].gui.AddExtraSize          ;// class defined WSize ?
                invoke [edi].gui.AddExtraSize   ;// call it
            .ELSE                               ;// otherwise
                mov eax, [edi].data.numFileBytes;// add on the predetermined size
                add [ebx], eax
            .ENDIF

            ;// add [ebx], eax              ;// add it to the running total

            mov eax, [edi].data.numPins ;// get the number of the pins
            lea eax, [eax+eax*2]        ;// times 3
            lea eax, [eax*4+SIZEOF FILE_OSC]    ;// times 4 = size of the pin table
                                        ;// times 4 = size of the pin table
                                        ;// add the size of the osc file record
            add [ebx], eax              ;// add it to the running total

            clist_GetNext oscS, esi

        .UNTIL esi == [ebp].oscS_clist_MRS

    ;// check for lock list

        .IF clist_MRS( oscL, [ebp] )

            invoke locktable_GetSize_S
            add DWORD PTR [esp], eax

        .ENDIF

    ;// get the osc count and return

        pop eax

        ret

context_GetCopySize ENDP

;//                                 context_GetLockTableSize
;//                                 context_GetBusTableSize
;//                                 context_GetFileSize
;// utility and helper functions    context_GetCopySize
;//
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////









ASSUME_AND_ALIGN
context_Save    PROC

    ;// edi enters as the start of block
    ;// edi exits as the end of the block

    ;// esi is preserved
    ;// ebx is destroyed

        ASSUME ebp:PTR LIST_CONTEXT
        ASSUME edi:PTR FILE_HEADER  ;// ITERATED

        push esi

        add edi, SIZEOF FILE_HEADER     ;// now edi iterates osc records

    ;// now we do all the osc's in this context

        dlist_GetHead oscZ, esi, [ebp]

        .IF !context_bCopy

            .REPEAT

                ;// store the osc in the buffer we just created

                    push edi            ;// save the start of this osc record
                                        ;// osc_Write will iterate edi
                    invoke osc_Write    ;// call the common write function

                ;// becuase we're storing to a file, we convert pBase to the ID

                    pop ebx                                 ;// retrieve osc record in ebx
                    mov edx, (FILE_OSC PTR [ebx]).pBase     ;// get the base class
                    mov edx, (OSC_BASE PTR [edx]).data.ID   ;// get the id
                    mov (FILE_OSC PTR [ebx]).id, edx        ;// store in file record

                ;// iterate to the next osc in the context

                    dlist_GetNext oscZ, esi

            .UNTIL !esi

        .ELSE   ;// we are copying/pasteing, so we DO NOT convert base class to ID

            .REPEAT

                ;// store the osc in the buffer we just created

                    invoke osc_Write    ;// call the common write function

                ;// iterate to the next osc in the context

                    dlist_GetNext oscZ, esi

            .UNTIL !esi

        .ENDIF

    ;// check if there's a lock table to save

        .IF clist_MRS(oscL, [ebp])

            call locktable_Save_Z

        .ENDIF

    ;// check if there's bus strings to save

        .IF [ebp].pBusStrings
            call bus_SaveFile
        .ENDIF

    ;// check if we need a group table

        .IF context_group_recording

            ;// sloppy, we have to check if this is nessesary, when we've already done so
            ;// this would be a case for a dirty flag in each context

            dlist_GetHead oscZ, esi, [ebp]  ;// scan the z list
            xor ecx, ecx                    ;// count in ecx
            .WHILE esi
                .IF [esi].id
                    inc ecx
                .ENDIF
                dlist_GetNext oscZ, esi
            .ENDW
            .IF ecx ;// ecx has the count of objects in the table

                ;// time to store the table

                mov eax, OFFSET osc_IdTable
                stosd           ;// pBase
                xor eax, eax
                stosd           ;// num pins
                stosd           ;// pos x
                stosd           ;// pos Y
                lea eax, [ecx*8]
                stosd           ;// extra size

                dlist_GetHead oscZ, esi, [ebp]
                xor ebx, ebx    ;// ebx indexes
                .REPEAT

                    .IF [esi].id
                        mov eax, ebx
                        stosd
                        mov eax, [esi].id
                        stosd
                    .ENDIF
                    inc ebx
                    dlist_GetNext oscZ, esi

                .UNTIL !esi

            .ENDIF

        .ENDIF

    ;// that's it

        pop esi

        ret

context_Save    ENDP







;////////////////////////////////////////////////////////////////////
;//
;//
;//     context paste file
;//
ASSUME_AND_ALIGN
context_PasteFile PROC uses ebx esi edi

    ;// get a buffer from the file

        invoke file_Load

    ;// make sure it got xlated ok

    .IF eax

        ;// set the valid copy and copy buffer

        mov file_bValidCopy, eax    ;// we're valid
        mov edi, eax
        xchg eax, file_pCopyBuffer  ;// swap with existing buffer
        .IF eax
            invoke memory_Free, eax ;// free previous buffer
        .ENDIF

        ASSUME edi:PTR FILE_HEADER  ;// edi is a file header

        ;// set the paste path

        mov ebx, filename_get_path      ;// get the new paste path
        xchg ebx, filename_paste_path   ;// swap new with old
        mov filename_get_path, 0        ;// erase the pointer
        .IF ebx
            DEBUG_IF <ebx==filename_paste_path>
            filename_PutUnused ebx      ;// free the old name
        .ENDIF

        ;// now we check if the open group flag is on
        ;// if so, then we have to rearrange this file and create the base class
        .IF [edi].settings & CIRCUIT_OPEN_GROUP

            ;// turn it off now !!
            xor [edi].settings, CIRCUIT_OPEN_GROUP

            ;// check the settings to make sure this isn't bad
            ;// the osc group had better be the first one
            ;// look at group.dwUser in the stored file
            .IF DWORD PTR [edi+SIZEOF FILE_HEADER+SIZEOF FILE_OSC] & GROUP_BAD

                mov edx, filename_paste_path
                mov edx, (FILENAME PTR [edx]).pName
                or app_DlgFlags, DLG_MESSAGE
                invoke MessageBoxA, 0, OFFSET szBadGroup, edx, MB_OK + MB_TASKMODAL + MB_SETFOREGROUND
                and app_DlgFlags, NOT DLG_MESSAGE
                xor eax, eax
                mov file_bValidCopy, eax
                jmp  all_done

            .ENDIF

            ;// ABOX239 have to check for empty groups
            cmp (CLOSED_GROUP_FILE_HEADER PTR [edi]).group_file.numPin, 0
            .IF ZERO?

                mov edx, filename_paste_path
                mov edx, (FILENAME PTR [edx]).pName
                or app_DlgFlags, DLG_MESSAGE
                invoke MessageBoxA, 0, OFFSET szEmptyGroup, edx, MB_OK + MB_TASKMODAL + MB_SETFOREGROUND
                and app_DlgFlags, NOT DLG_MESSAGE
                xor eax, eax
                mov file_bValidCopy, eax
                jmp  all_done

            .ENDIF

            ;// tell closed group to prepare this

            invoke closed_group_PrepareToLoad
            mov file_pCopyBuffer, edi

            ;// DEBUG_IF < DWORD PTR [edi+SIZEOF FILE_HEADER] != OFFSET opened_group >
            ;// mov DWORD PTR [edi+SIZEOF FILE_HEADER], OFFSET closed_group

        .ENDIF  ;// we're ok to paste

        unredo_BeginAction UNREDO_PASTE

        invoke context_Paste, file_pCopyBuffer, 0, 1    ;// no ids,

        ;// return what paste returned

    .ENDIF

    ;// that's it

all_done:

        ret

context_PasteFile   ENDP









;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;//
;//                                     context_Copy    context_Clone
;//     routines called from UI         context_Paste   context_Delete
;//     that use the COPY BUFFER        context_Cut
;//


ASSUME_AND_ALIGN
context_Copy  PROC uses ebx esi edi

    ;// action: selected objects --> file_pCopyBuffer

    ASSUME ebp:PTR LIST_CONTEXT

    ;// step one is to check if we need to rearrange the Zlist for an open group
    ;// this takes care of oscAry_Save and oscAry_copy

        .IF app_CircuitSettings & CIRCUIT_OPEN_GROUP && \
            !(app_bFlags & APP_MODE_IN_GROUP)

            ;// or should groups only be allowed paste from file
            invoke opened_group_PrepareToSave

        .ENDIF

    ;// this is called from a user event
    ;// we assume this is valid, or we wouldn't be here
    ;// what we're going to do, is build a memory file using the file_pCopy

    ;// make some local variables

        pushd SIZEOF FILE_HEADER    ;// file size, starts with the header

    ;// get the amount of memory we need

        mov ebx, esp                ;// get pointer to file size
        invoke context_GetCopySize  ;// call function to do the loop
        xor edi, edi                ;// clear for next section
        pop ebx                     ;// get the file size
        push eax                    ;// store the number of oscs

    ;// stack looks like this
    ;// num_osc ...
    ;// 00

    ;// then we check if the copy buffer is big enough

        push ebx    ;// sloppy

        add ebx, 3
        and ebx, -4

        or edi, file_pCopyBuffer        ;// edi iterates the copy buffer
        .IF ZERO?                       ;// new buffer ?
            invoke memory_Alloc, GPTR, ebx
            mov edi, eax                ;// store in edi
            mov file_pCopyBuffer,eax    ;// store as copy buffer
        .ELSE
            cmp ebx, MEMORY_SIZE(edi)   ;// big enough ?
            jbe @F
                invoke memory_Resize, edi, ebx  ;// resize the block
                mov edi, eax            ;// store in edi
                mov file_pCopyBuffer,eax;// store as copy buffer
            @@:
        .ENDIF

        pop ebx

    ;// set up the file header

        ASSUME edi:PTR FILE_HEADER

        mov eax, [esp]          ;// retrieve the number of oscs
        add ebx, edi            ;// add current pointer to size = pEOB
        mov [edi].numOsc, eax   ;// store number of oscs
        mov [edi].pEOB, ebx     ;// store as pEOB

    ;// stack
    ;// num oscs

    ;// set context_bCopy so closed groups save correctly

        dec context_bCopy
        DEBUG_IF <!!SIGN?>

    ;// define the file iterator

        add edi, SIZEOF FILE_HEADER

    ;// scan through the sellist and call the write function

        clist_GetMRS oscS, esi, [ebp]
        push esi

    ;// stack
    ;// oscS.MRS    num_osc

    J0: invoke osc_Write        ;// write this osc
        clist_GetNext oscS, esi ;// get the next osc
        dec DWORD PTR [esp+4]   ;// keep track of how many we store
        cmp esi, DWORD PTR [esp];// see if we're done yet
        jne J0

        pop esi ;// retrieve the MRS
        pop eax ;// retrive the number of oscs remaining

    ;// check for lock table

        dec eax     ;// decrease to account for oscL, but no lock table
        .IF ZERO? && clist_MRS(oscL,[ebp])
            invoke locktable_Save_S
        .ENDIF

    ;// set the bCopy valid flag and reset context_bCopy

        mov file_bValidCopy, 1

        inc context_bCopy
        DEBUG_IF <!!ZERO?>

    ;// that's it

        ret

context_Copy  ENDP







ASSUME_AND_ALIGN
PROLOGUE_OFF
context_Paste PROC STDCALL pBuffer:DWORD, pIds:DWORD, bSelect:DWORD

        push esi
        push edi
        push ebx

    ;// stack:
    ;// ebx edi esi ret pBuffer, bPins, bSelect
    ;// 00  04  08  0C  10       14     18

        st_buffer TEXTEQU <(DWORD PTR [esp+10h])>
        st_ids    TEXTEQU <(DWORD PTR [esp+14h])>
        st_select TEXTEQU <(DWORD PTR [esp+18h])>

    ;// this is called from the menu, paste file, and undo

        ASSUME ebp:PTR LIST_CONTEXT

    ;// clear out the slist, invalidate as we go

        invoke context_UnselectAll

    ;// search for bad objects
    ;// if pIds, we shouldn't need to do this

        .IF !st_ids

            mov esi, st_buffer              ;// load the copy buffer
            ASSUME esi:PTR FILE_HEADER
            mov edi, [esi].pEOB             ;// get where to stop
            FILE_HEADER_TO_FIRST_OSC esi    ;// start at first osc

            .WHILE esi < edi                ;// scan the file

                mov ecx, [esi].pBase        ;// get the base class
                .IF ecx                     ;// skip bad objects
                    ASSUME ecx:PTR OSC_BASE
                    .IF [ecx].data.dwFlags & BASE_HARDWARE  ;// are we hardware ??
                        invoke hardware_CanCreate, ecx, 0   ;// check if we can create this
                        .IF !eax                            ;// can we ?
                            mov [esi].pBase, eax            ;// clear this osc if not
                        .ENDIF
                    .ENDIF
                .ENDIF
                FILE_OSC_TO_NEXT_OSC esi

            .ENDW

        .ENDIF

    ;// finally, we get to create the file

        ENTER_PLAY_SYNC GUI

        mov esi, st_buffer  ;// file_pCopyBuffer        ;// load the copy buffer
        mov edx, st_ids

        invoke file_RealizeBuffer, esi, edx, st_select  ;// select as we go

        .IF !st_ids
            invoke file_CheckConnections, esi   ;// file_pCopyBuffer
            invoke file_ConnectPins, esi        ;// file_pCopyBuffer
        .ENDIF

        LEAVE_PLAY_SYNC GUI

    ;// make pasted objects follow the mouse

        or app_bFlags,  APP_SYNC_EXTENTS    OR  \
                        APP_SYNC_PLAYBUTTON OR  \
                        APP_SYNC_MOUSE

        .IF clist_MRS(oscS,[ebp]) && !st_ids;// make sure we selected something
                                            ;// and that we are not undoing

            dlist_GetHead oscZ, esi,[ebp]   ;// get new head of sel list
            mov osc_down, esi               ;// set app_OscDown as that object
            mov mouse_state, MK_LBUTTON     ;// trick mouse handler into ignoring r button


            or app_bFlags,  APP_MODE_MOVING_OSC
            point_GetTL [esi].rect
            point_Set mouse_now

        .ENDIF

    ;// return control to user

        invoke SetFocus, hMainWnd

    ;// return sucess

        mov eax, 1

    ;// that's it

        pop ebx
        pop edi
        pop esi

        ret 0Ch

context_Paste  ENDP
PROLOGUE_ON



ASSUME_AND_ALIGN
context_Cut  PROC   uses edi esi ebx

        invoke context_Copy
        invoke context_Delete_prescan
        .IF eax
            invoke context_Delete
        .ENDIF

    ;// that's it

        ret

context_Cut ENDP


ASSUME_AND_ALIGN
context_Delete_prescan PROC uses esi

    ;// purpose: remove pin iterfaces from the select list
    ;// returns: oscS.MRS for checking for emtpy list

        ASSUME ebp:PTR LIST_CONTEXT

    J0: clist_GetMRS oscS, esi, [ebp]
        .IF esi

            push esi

            .REPEAT

                .IF [esi].pBase == OFFSET osc_PinInterface  &&  \
                    app_bFlags & APP_MODE_IN_GROUP          &&  \
                    [esi].dwHintOsc & HINTOSC_STATE_HAS_GROUP

                ;// not supposed to delete this

                    clist_Remove oscS, esi,,[ebp]
                    GDI_INVALIDATE_OSC HINTI_OSC_LOST_SELECT
                    pop esi
                    jmp J0

                .ENDIF

                clist_GetNext oscS, esi

            .UNTIL esi == [esp]

            pop esi

        .ENDIF

    ;// return the head so we can see if there's anything left

        clist_GetMRS oscS, eax, [ebp]

        ret

context_Delete_prescan ENDP


ASSUME_AND_ALIGN
context_Delete PROC uses esi edi ebx

        ASSUME ebp:PTR LIST_CONTEXT

    ;// this deletes the selected objects

    invoke context_Delete_prescan
    .IF eax

    ;// if we were playing, we want to keep playing
    ;// so we tell the play system to hangon

    ENTER_PLAY_SYNC GUI

    ;// then we scan the list and Dtor everything in it

    J0: clist_GetMRS oscS, esi, [ebp]

        .IF esi

            DEBUG_IF < edi == OFFSET osc_PinInterface && app_bFlags & APP_MODE_IN_GROUP && [esi].dwHintOsc & HINTOSC_STATE_HAS_GROUP >
            ;// not supposed to delete this
            ;// should have called context_Delete_prescan first

            invoke osc_Dtor
            jmp J0

        .ENDIF

    ;// tell play to trace and resume playing

        or [ebp].pFlags, PFLAG_TRACE
        invoke context_SetAutoTrace         ;// schedule a unit trace

    LEAVE_PLAY_SYNC GUI

    ;// then we repaint and synchronize

        or app_bFlags, APP_SYNC_EXTENTS

    ;// that's it
    .ENDIF

        ret

context_Delete ENDP

;//
;//                                     context_Copy    context_Clone
;//     routines called from UI         context_Paste   context_Delete
;//     that use the COPY BUFFER        context_Cut
;//
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////






ASSUME_AND_ALIGN
context_MoveAll PROC uses esi edi

    ASSUME ebp:PTR LIST_CONTEXT

    ;// this moves all oscs in the context

    ;// esi is preserved
    ;// edi is preserved
    ;// ebx is preserved

    ;// scan backwards to get the zlist correct with I list

    dlist_GetTail oscZ, esi, [ebp]  ;// scan through every osc
    .WHILE esi

        OSC_TO_BASE esi, edi            ;// get the base class
        invoke [edi].gui.Move           ;// call the move function

        GDI_INVALIDATE_OSC HINTI_OSC_MOVE_SCREEN
        ;// invalidate, osc_Move is blocked from doing this

        dlist_GetPrev oscZ, esi         ;// iterate

    .ENDW

    ;// use the scroll command

        point_Get mouse_delta
        invoke ScrollWindowEx, hMainWnd, eax, edx, 0, 0, 0, 0, SW_INVALIDATE + SW_ERASE

    ;// update the scroll bars

        or app_bFlags, APP_SYNC_EXTENTS

    ;// that should be it

        ret

context_MoveAll ENDP






;////////////////////////////////////////////////////////////////////
;//
;//
;//     context_UnselectAll
;//
ASSUME_AND_ALIGN
context_UnselectAll PROC uses esi

    ASSUME ebp:PTR LIST_CONTEXT

    ;// uses eax, edx

    clist_GetMRS oscS, esi, [ebp]
    .WHILE esi

        GDI_INVALIDATE_OSC HINTI_OSC_LOST_SELECT
        clist_Remove oscS, esi,,[ebp]
        mov esi, eax

    .ENDW

    ret

context_UnselectAll ENDP


























;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;//
;//
;//     extents and scroll bars
;//

.DATA

    HScroll SCROLLINFO { ,SIF_RANGE + SIF_PAGE + SIF_POS,,,,GDI_GUTTER_X }
    VScroll SCROLLINFO { ,SIF_RANGE + SIF_PAGE + SIF_POS,,,,GDI_GUTTER_Y }

    ptr_extent  RECT {} ;// pointers to the oscs that caused the extent

    scroll_state    dd  HSCROLL_ON OR VSCROLL_ON


.CODE
;////////////////////////////////////////////////////////////////////
;//
;//                             ebp must be current list context
;//     oscAry_UpdateExtents    DESTROYS ALL OTHER REGISTERS
;//

ASSUME_AND_ALIGN
context_UpdateExtents PROC

        ASSUME ebp:PTR LIST_CONTEXT

    ;// scan the entire circuit and determine the new extents

        dlist_GetHead oscZ, esi, [ebp]

    ;// put the page size in dwMinMax
    ;// set the extents for the screen size

        xor edi, edi

        mov eax, GDI_GUTTER_X
        mov ebx, HScroll.dwPage
        mov edx, GDI_GUTTER_Y
        mov ecx, VScroll.dwPage

        mov HScroll.dwMin, eax
        lea ebx, [ebx+eax-1]
        mov VScroll.dwMin, edx
        lea ecx, [ecx+edx-1]

        mov HScroll.dwMax, ebx
        mov VScroll.dwMax, ecx

        mov ptr_extent.left, edi
        mov ptr_extent.top, edi
        mov ptr_extent.right, edi
        mov ptr_extent.bottom, edi

    ;// scan through the entire circuit context
    ;// keep track of the outside extents

        mov edi, NOT HINTOSC_STATE_SETS_EXTENTS

        .WHILE esi

            and [esi].dwHintOsc, edi    ;// make sure the extent bit is off

            cmp eax, [esi].rect.left
            jle @F
            mov eax, [esi].rect.left
            mov ptr_extent.left, esi
        @@:
            cmp edx, [esi].rect.top
            jle @F
            mov edx, [esi].rect.top
            mov ptr_extent.top, esi
        @@:
            cmp ebx, [esi].rect.right
            jge @F
            mov ebx, [esi].rect.right
            mov ptr_extent.right, esi
        @@:
            cmp ecx, [esi].rect.bottom
            jge @F
            mov ecx, [esi].rect.bottom
            mov ptr_extent.bottom, esi
        @@:
            dlist_GetNext oscZ, esi

        .ENDW

    ;// determine if the scroll bar state needs to change

        ;// if dwPage is less than dwMax-dwMin then the scroll should be ON
        ;// dwPage is the client size
        ;// dwMin is the TL extent
        ;// dwMax is the BR extent

    ;// tasks:  make sure the scroll.min/max is correct
    ;//         verify the correct page size
    ;//         verify the on off states are correct
    ;//     if any of these need changed, call update scroll bars


    ;// turn on the 4 extent oscs

        ASSUME edi:PTR OSC_OBJECT

        xor edi, edi
        or edi, ptr_extent.left
        jz @F
        or [edi].dwHintOsc, HINTOSC_STATE_SETS_EXTENTS
        xor edi, edi
    @@:
        or edi, ptr_extent.top
        jz @F
        or [edi].dwHintOsc, HINTOSC_STATE_SETS_EXTENTS
        xor edi, edi
    @@:
        or edi, ptr_extent.right
        jz @F
        or [edi].dwHintOsc, HINTOSC_STATE_SETS_EXTENTS
        xor edi, edi
    @@:
        or edi, ptr_extent.bottom
        jz @F
        or [edi].dwHintOsc, HINTOSC_STATE_SETS_EXTENTS
        xor edi, edi
    @@:

    ;// make sure that dwMinMax are correct

    ;// xor esi, esi    ;// esi already = 0

        cmp eax, HScroll.dwMin
        jg @F
        inc esi
        mov HScroll.dwMin, eax
    @@:
        cmp edx, VScroll.dwMin
        jg @F
        inc esi
        mov VScroll.dwMin, edx
    @@:
        cmp ebx, HScroll.dwMax
        jl @F
        inc esi
        mov HScroll.dwMax, ebx
    @@:
        cmp ecx, VScroll.dwMax
        jl @F
        inc esi
        mov VScroll.dwMax, ecx
    @@:

    ;// calculate page size and determine which scrolls should be on

        point_GetBR gdi_client_rect, ebx, ecx   ;// load client BR

        mov eax, HScroll.dwMax          ;// get scroll right
        mov edx, VScroll.dwMax          ;// get scroll bottom

        sub ebx, gdi_client_rect.left   ;// subtract to get client width
        sub ecx, gdi_client_rect.top    ;// subtract to get client height

        sub eax, HScroll.dwMin          ;// subtract to get scroll width
        sub edx, VScroll.dwMin          ;// subtract to get scroll height

        mov HScroll.dwPage, ebx         ;// store client width as page size
        mov VScroll.dwPage, ecx         ;// store client height as page size

        cmp eax, ebx    ;// HScroll.dwPage
        jg @01
            ;// HScroll should be off
            btr scroll_state, LOG2(HSCROLL_ON)
            jmp @02
            ;// HScroll should be on
    @01:    bts scroll_state, LOG2(HSCROLL_ON)
            cmc
    @02:adc esi, edi    ;// edi is zero from previous steps

        cmp edx, ecx    ;// VScroll.dwPage
        jg @03
            ;// VScroll should be off
            btr scroll_state, LOG2(VSCROLL_ON)
            jmp @04
            ;// VScroll should be on
    @03:    bts scroll_state, LOG2(VSCROLL_ON)
            cmc
    @04:adc esi, edi    ;// edi is zero from previous steps

    ;// now, esi has a flag of wheather or not we need to update the scrolls

    .IF esi

        invoke SetScrollInfo, hMainWnd, SB_HORZ, OFFSET HScroll, 1
        invoke SetScrollInfo, hMainWnd, SB_VERT, OFFSET VScroll, 1

    .ENDIF

    ;// turn off the flags

    and app_bFlags, NOT APP_SYNC_EXTENTS

    ret

context_UpdateExtents ENDP




ASSUME_AND_ALIGN
context_SetAutoTrace    PROC

    ;// this makes sure that all contexts are flaged for autotrace
    ;// use this function to set app_bFlags:APP_SYNC_AUTOUNITS

    ;// preserves all registers

    ASSUME ebp:PTR LIST_CONTEXT

        cmp ebp, OFFSET master_context
        jne have_to_backtrace
    all_done:
        or app_bFlags, APP_SYNC_AUTOUNITS
        ret

    have_to_backtrace:

        push eax
        push ebp

    top_of_backtrace:

        mov eax, [ebp].pGroup
        test eax, eax
        jz done_with_backtrace

        ASSUME eax:PTR OSC_OBJECT
        or [eax].dwUser, UNIT_AUTO_TRACE
        stack_PeekNext gui_context, ebp, ebp
        test ebp, ebp
        jnz top_of_backtrace

    done_with_backtrace:

        pop ebp
        pop eax
        jmp all_done

context_SetAutoTrace ENDP




















ASSUME_AND_ALIGN






END