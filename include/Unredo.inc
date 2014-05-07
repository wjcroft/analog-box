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
;//     unredo.inc
;//

    IFNDEF HASHD_INCLUDED
    include <hashd3.inc>
    ENDIF

comment ~ /*

    this works on the concept of a chain of reversable action records

    new user actions are added to the end of the chain

    unredo_Undo traverses the chain backwards and performs the reversed action

    unredo_Redo traverses the chain forwards and performs the forward action


basic structure UNREDO_NODE

    NODE    action  data

    pNext
    -----   ACTION  action dependant record
    pPrev

    pNext/pRev are a dlist for traversing the nodes

    ACTION is an enumerator
    action data varies greatly and is described below

object pointers

    to allow deleteing and unconecting, osc object and apin pointers
    are stored as ID.INDEX. The ID is assigned by the ctor or by undo and will be
    valid for the lifetime of the application.

    id's are then mapped to pointers by a hashd container and it's associated overflow pool

    all of this is managed by hashd unredo_id

when to store records

    mouse-down and mouse-up
    scroll bars
    keyboard commands
    dialog display and hide, along with command's
    group view change

navigating and duplication

    ctrl-z, ctrl-y iterates on the node level

memory use

    a cache of empty action records should be available
    using the pool concept from other projects may work well here

memory model

    we want to store a large number of records
    so we allocate a fixed size block

    when the table is full, we scoot all the records back (not that expensive)

unredo record navigation

    there are three main pointers

    dlist_Head(unredo)  the oldest unredo record
    dlist_Tail(unredo)  the newest unedo record
    unredo_pCurrent     the current record

        pCurrent is always the record to record at
        so undo has to back up one
        redo does so the current record, then advances

detection

    undo is OK if unredo_pCurrent != dlist_Head(unredo)
    redo is OK if unredo_pCurrent != dlist_Tail(unredo)

app_IsDirty

    unredo can now manage this flag by incrementing and decrementing


access

    unredo_Undo and unredo_Redo do just that

    to record actions takes at most two steps:

    1) unredo_BeginAction ENUM

        starts the record process to a temporary buffer

    2) unredo_EndAction ENUM

        ends the record process
        transfers the temp buffer to the main list
        advances pCurrent

    -OR-

    1) unredo_BeginEndAction

        may be used in some situations


more notes in unredo.asm


*/ comment ~


;// tables, need to be declared so we can dtermine if we can undo or redo


    ;// the unredo node

        UNREDO_NODE STRUCT

            dlist_Declare_link unredo, UNREDO_NODE  ;// next and prev node
            dlist_Declare_alias_link unredo_screen, unredo  ;// , UNREDO_NODE, unredo

            action  dd  ?   ;// action code
            stamp   dd  ?   ;// time stamp for app_bDirty

        UNREDO_NODE ENDS
        ;// action data follows

    ;// data sizes
                                        ;// ABOX233 still not enough !!
        UNREDO_BUFFER_SIZE  EQU 100000h ;// 1 megabyte should be enough ABox233 changed to 1 MB
        UNREDO_TEMP_SIZE    EQU  10000h ;// 16K to start with,
                                        ;// ABOX232, changed from 1000 to 4000
                                        ;// ABOX233, changed to 8000 !
                                        ;// ABOX234, changed to 10000 !!!
        UNREDO_HASH_NUM_KEYS EQU 100h   ;// number of id's to expose in the hash table

        UNREDO_SCREEN_SIZE EQU ((SIZEOF action_UNREDO_MOVE_SCREEN) * 128)

    ;// the list and pointers

        dlist_Declare_external unredo   ;// , UNREDO_NODE, unredo
        hashd_Declare_external unredo_id, UNREDO_HASH_NUM_KEYS,GENERATE_ALLOCATOR, OSC_OBJECT

        EXTERNDEF unredo_pCurrent:DWORD     ;// pointer to the curent record for checking
                                            ;// if undo or redo is available

        EXTERNDEF unredo_pRecorder:DWORD    ;// used to record multiple actions

    ;// flag that enables groups to tell context to check for id table

        EXTERNDEF unredo_delete:DWORD       ;// see context_group_record

    ;// need to save detection

        EXTERNDEF unredo_action_count:DWORD
        EXTERNDEF unredo_last_save:DWORD
        EXTERNDEF unredo_last_action:DWORD
        EXTERNDEF unredo_we_are_dirty:DWORD

    ;// drop counter tells user how many steps were dropped

        EXTERNDEF unredo_drop_counter:DWORD
        EXTERNDEF sz_unredo_full:BYTE

    ;//
    ;//     S T R U C T S  stored in action structs
    ;//

    ;// id tables for oscs look like this

        UNREDO_OSC_ID STRUCT

            id      dd  0   ;// id of the osc
            lock_id dd  0   ;// zero or id of what this object is locked to

        UNREDO_OSC_ID ENDS

    ;// unredo pin is used to store pins

        UNREDO_PIN  STRUCT

            id  dd  0   ;// id of the osc
            pin dd  0   ;// offset of the pin from the osc

        UNREDO_PIN  ENDS

    ;// connecting, unconnecting deleteing and reinserting oscs requires a connect table

        UNREDO_PIN_CONNECT STRUCT

            num_pin dd  0       ;// number of pins (must not be zero)
            mode    dd  0       ;// see below
            con  UNREDO_PIN {}  ;// at least one pin

        UNREDO_PIN_CONNECT ENDS
            ;// UNREDO_PIN  more may folow

        ;// if PIN_CONNECT is part of an array
        ;// terminate the list by using the value of zero

        ;// mode    description                             data
        ;// -----   -----------------------------------     -------------------------------
        ;// -2      = input from output one connection,     1 output 1 input    UI_UO
        ;// -1      = input from output with many inputs    1 output 1 input    UI_CO
        ;//  0      = output, non bussed,                   1 output n inputs, n may not be zero
        ;// 1-255   = bussed output, b is bus number        1 output n inputs, n may be zero

        UNREDO_CON_CO_UO    EQU 256 ;//                     from output, to output
        UNREDO_CON_CI_UI    EQU 257 ;//                     from input, to input
        UNREDO_CON_CO_CO    EQU 258 ;//                     output output, input list
        UNREDO_CON_CI_UOCO  EQU 259 ;// special mode        from input to output, old output

        ;// private functions available to undo or redo

        ;// unredo_con_get_size PROC STDCALL pPin:DWORD
        ;// unredo_con_xlate_ids PROC STDCALL pPinConnect:DWORD
        ;// unredo_con_undo PROC STDCALL pPinConnect:DWORD
        ;// unredo_con_redo PROC STDCALL pPinConnect:DWORD

    ;// unredo pheta is required to save pheta before and after

        UNREDO_PHETA STRUCT

            POINT       {}  ;// x is before, y is after
            UNREDO_PIN  {}  ;// osc.pin

        UNREDO_PHETA ENDS


    ;// labels need to externs to be able to operate

        EXTERNDEF label_hWnd:DWORD
        EXTERNDEF label_pObject:DWORD

        label_set_size PROTO STDCALL pObject:DWORD, pRect:DWORD
        label_set_text PROTO STDCALL pObject:DWORD, pText:DWORD, len:DWORD

    ;// align needs some structs as well

        UNREDO_ALIGN_OSC    STRUCT

            id      dd  0
            delta   POINT   {}

        UNREDO_ALIGN_OSC    ENDS

        UNREDO_ALIGN_PIN    STRUCT

            pin     dd  0
            delta   REAL4   0.0

        UNREDO_ALIGN_PIN    ENDS


;// unredo actions

    UNREDO_EMPTY        EQU  0

    UNREDO_MOVE_SCREEN  EQU  1
    UNREDO_SCROLL       EQU  2
    UNREDO_MOVE_OSC     EQU  3
    UNREDO_MOVE_PIN     EQU  4

    UNREDO_CONTROL_OSC  EQU  5

    UNREDO_CONNECT_PIN  EQU  6  ;// pins connected by mouse dragging
    UNREDO_UNCONNECT    EQU  7

    UNREDO_BUS_CREATE   EQU   8
    UNREDO_BUS_RENAME   EQU   9
    UNREDO_BUS_TRANSFER EQU  10
    UNREDO_BUS_CONVERTTO EQU 11
    UNREDO_BUS_DIRECT   EQU  12
    UNREDO_BUS_PULL     EQU  13

    UNREDO_BUS_CATCAT   EQU  14
    UNREDO_BUS_CATDEL   EQU  15
    UNREDO_BUS_MEMCAT   EQU  16
    UNREDO_BUS_CATINS   EQU  17
    UNREDO_BUS_CATNAME  EQU  18
    UNREDO_BUS_MEMNAME  EQU  19

    UNREDO_BUS_MINIMUM  EQU UNREDO_UNCONNECT
    UNREDO_BUS_MAXIMUM  EQU UNREDO_BUS_MEMNAME

    UNREDO_NEW_OSC      EQU  20
    UNREDO_DEL_OSC      EQU  21
    UNREDO_PASTE        EQU  22
    UNREDO_CLONE_OSC    EQU  23

    UNREDO_COMMAND_OSC  EQU  24     ;// 0x16

    UNREDO_LOCK_OSC     EQU  25
    UNREDO_UNLOCK_OSC   EQU  26

    UNREDO_ENTER_GROUP  EQU  27
    UNREDO_LEAVE_GROUP  EQU  28

    UNREDO_EDIT_LABEL   EQU  29 ;// changing size, position or text

    UNREDO_SETTINGS     EQU  30 ;// circuit settings

    UNREDO_ALIGN        EQU  31 ;// aligning oscs

    UNREDO_MAX_ACTION   EQU  31 ;// for error checking
    UNREDO_MIN_ACTION   EQU   1 ;// for error checking





;// public functions


        unredo_Initialize   PROTO
        unredo_Reset        PROTO
        unredo_Destroy      PROTO

        unredo_Undo PROTO
        unredo_Redo PROTO

        unredo_GetUndoString PROTO STDCALL pStr:DWORD
        unredo_GetRedoString PROTO STDCALL pStr:DWORD

        unredo_assign_id PROTO

    ;// to allow for developemnt, these macros and definitions are used
    ;// later on, some functions may be turned into inline macros

    ;// begin starts the process of an undo step
    ;// end terminates the record

    ;// public access

        unredo_BeginAction MACRO action:REQ
            IF action EQ 0
            .ERR <BAD ACTION action >
            ENDIF
            invoke unredo_begin_action, action
            ENDM

        unredo_EndAction MACRO action:REQ
            invoke unredo_end_action    ;//, action
            ENDM

        unredo_BeginEndAction MACRO action:REQ
            IF action EQ 0
            .ERR <BAD ACTION action >
            ENDIF
            invoke unredo_beginend_action, action
            ENDM

    ;// private access

        unredo_begin_action PROTO STDCALL action:DWORD
        unredo_end_action PROTO
        unredo_beginend_action PROTO STDCALL action:DWORD





