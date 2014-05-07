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
;//     ABOX242 AJT -- detabified + text adjustments for 'lines too long' errors
;//
;//##////////////////////////////////////////////////////////////////////////
;//
;//     unredo.asm              lot's to see and do
;//

;// TOC
;//
;// unredo_Initialize PROC
;// unredo_Reset PROC
;// unredo_Destroy PROC
;//
;// unredo_GetUndoString PROC STDCALL pStr:DWORD
;// unredo_GetRedoString PROC STDCALL pStr:DWORD
;//
;// unredo_assign_id PROC
;//
;// unredo_store_record PROC uses ebp
;//
;// unredo_begin_action PROC STDCALL uses ebx esi edi action:DWORD
;// unredo_end_action PROC uses ebx esi edi
;// unredo_beginend_action  PROC STDCALL uses ebx esi edi action:DWORD
;//
;// unredo_Undo PROC uses ebp esi ebx edi
;// undo_action_UNREDO_EMPTY::
;// unredo_Redo PROC uses ebp esi edi ebx
;// unredo_redo_action_all_done::
;//
;// redo_action_UNREDO_EMPTY::
;// begin_action_UNREDO_MOVE_SCREEN::
;// begin_action_UNREDO_SCROLL::
;// end_action_UNREDO_MOVE_OSC::
;// end_action_UNREDO_MOVE_SCREEN::
;// end_action_UNREDO_SCROLL::
;// undo_action_UNREDO_SCROLL::
;// undo_action_UNREDO_MOVE_SCREEN::
;// redo_action_UNREDO_SCROLL::
;// redo_action_UNREDO_MOVE_SCREEN::
;// begin_action_UNREDO_MOVE_OSC::
;// undo_action_UNREDO_MOVE_OSC::
;// redo_action_UNREDO_MOVE_OSC::
;// begin_action_UNREDO_MOVE_PIN::
;// end_action_UNREDO_MOVE_PIN::
;// undo_action_UNREDO_MOVE_PIN::
;// redo_action_UNREDO_MOVE_PIN::
;// begin_action_UNREDO_COMMAND_OSC::
;// begin_action_UNREDO_CONTROL_OSC::
;// end_action_UNREDO_COMMAND_OSC::
;// end_action_UNREDO_CONTROL_OSC::
;// undo_action_UNREDO_CONTROL_OSC::
;// redo_action_UNREDO_CONTROL_OSC::
;// undo_action_UNREDO_COMMAND_OSC::
;// redo_action_UNREDO_COMMAND_OSC::
;//
;// unredo_con_get_size PROC STDCALL pPin:DWORD
;// unredo_con_xlate_ids PROC STDCALL pPinConnect:DWORD
;// unredo_con_undo PROC STDCALL pPinConnect:DWORD
;// unredo_con_redo PROC STDCALL pPinConnect:DWORD
;//
;// begin_action_UNREDO_UNCONNECT::
;// begin_action_UNREDO_CONNECT_PIN::
;// end_action_UNREDO_UNCONNECT::
;// end_action_UNREDO_CONNECT_PIN::
;// redo_action_UNREDO_UNCONNECT::
;// undo_action_UNREDO_CONNECT_PIN::
;// undo_action_UNREDO_UNCONNECT::
;// redo_action_UNREDO_CONNECT_PIN::
;//
;// beginend_action_UNREDO_BUS_CONVERTTO::
;// beginend_action_UNREDO_BUS_CREATE::
;// undo_action_UNREDO_BUS_CREATE::
;// redo_action_UNREDO_BUS_CREATE::
;// beginend_action_UNREDO_BUS_RENAME::
;// undo_action_UNREDO_BUS_RENAME::
;// redo_action_UNREDO_BUS_RENAME::
;// beginend_action_UNREDO_BUS_TRANSFER::
;// undo_action_UNREDO_BUS_TRANSFER::
;// redo_action_UNREDO_BUS_TRANSFER::
;// redo_action_UNREDO_BUS_DIRECT::
;// undo_action_UNREDO_BUS_CONVERTTO::
;// undo_action_UNREDO_BUS_DIRECT::
;// redo_action_UNREDO_BUS_CONVERTTO::
;// beginend_action_UNREDO_BUS_DIRECT::
;// begin_action_UNREDO_BUS_PULL::
;// end_action_UNREDO_BUS_PULL::
;// undo_action_UNREDO_BUS_PULL::
;// redo_action_UNREDO_BUS_PULL::
;// begin_action_UNREDO_BUS_CATDEL::
;// begin_action_UNREDO_BUS_CATCAT::
;// end_action_UNREDO_BUS_CATDEL::
;// end_action_UNREDO_BUS_CATCAT::
;// undo_action_UNREDO_BUS_CATDEL::
;// undo_action_UNREDO_BUS_CATCAT::
;// redo_action_UNREDO_BUS_CATCAT::
;// redo_action_UNREDO_BUS_CATDEL::
;// undo_action_UNREDO_BUS_MEMCAT::
;// redo_action_UNREDO_BUS_MEMCAT::
;// begin_action_UNREDO_BUS_MEMCAT::
;// begin_action_UNREDO_BUS_MEMNAME::
;// begin_action_UNREDO_BUS_CATNAME::
;// begin_action_UNREDO_BUS_CATINS::
;// end_action_UNREDO_BUS_MEMCAT::
;// end_action_UNREDO_BUS_MEMNAME::
;// end_action_UNREDO_BUS_CATNAME::
;// end_action_UNREDO_BUS_CATINS::
;// undo_action_UNREDO_BUS_CATINS::
;// redo_action_UNREDO_BUS_CATINS::
;// undo_action_UNREDO_BUS_CATNAME::
;// redo_action_UNREDO_BUS_CATNAME::
;// undo_action_UNREDO_BUS_MEMNAME::
;// redo_action_UNREDO_BUS_MEMNAME::
;// begin_action_UNREDO_DEL_OSC::
;// end_action_UNREDO_DEL_OSC::
;// undo_action_UNREDO_DEL_OSC::
;// redo_action_UNREDO_DEL_OSC::
;// begin_action_UNREDO_NEW_OSC::
;// end_action_UNREDO_NEW_OSC::
;// undo_action_UNREDO_NEW_OSC::
;// redo_action_UNREDO_NEW_OSC::
;// begin_action_UNREDO_CLONE_OSC::
;// begin_action_UNREDO_PASTE::
;// end_action_UNREDO_CLONE_OSC::
;// end_action_UNREDO_PASTE::
;// undo_action_UNREDO_CLONE_OSC::
;// undo_action_UNREDO_PASTE::
;// redo_action_UNREDO_CLONE_OSC::
;// redo_action_UNREDO_PASTE::
;// beginend_action_UNREDO_UNLOCK_OSC::
;// beginend_action_UNREDO_LOCK_OSC::
;// redo_action_UNREDO_UNLOCK_OSC::
;// undo_action_UNREDO_LOCK_OSC::
;// undo_action_UNREDO_UNLOCK_OSC::
;// redo_action_UNREDO_LOCK_OSC::
;// beginend_action_UNREDO_ENTER_GROUP::
;// beginend_action_UNREDO_LEAVE_GROUP::
;// redo_action_UNREDO_LEAVE_GROUP::
;// undo_action_UNREDO_ENTER_GROUP::
;// undo_action_UNREDO_LEAVE_GROUP::
;// redo_action_UNREDO_ENTER_GROUP::
;// begin_action_UNREDO_EDIT_LABEL::
;// end_action_UNREDO_EDIT_LABEL::
;// undo_action_UNREDO_EDIT_LABEL::
;// redo_action_UNREDO_EDIT_LABEL::
;// begin_action_UNREDO_SETTINGS::
;// end_action_UNREDO_SETTINGS::
;// undo_action_UNREDO_SETTINGS::
;// redo_action_UNREDO_SETTINGS::
;// begin_action_UNREDO_ALIGN::
;// end_action_UNREDO_ALIGN::
;// undo_action_UNREDO_ALIGN::
;// redo_action_UNREDO_ALIGN::


 USETHISFILE EQU 1

IFDEF USETHISFILE

OPTION CASEMAP:NONE
.586
.MODEL FLAT

        .NOLIST
        include <abox.inc>
        include <bus.inc>
        include <groups.inc>
        include <gdi_pin.inc>
        .LIST
        .LISTALL
        .LISTMACROALL


;// DEBUG_MESSAGE_ON
    DEBUG_MESSAGE_OFF


.DATA

    ;// list anchors and pointers

        ;// unredo list proper

        dlist_Declare unredo    ;// dlist of records

        unredo_pCurrent dd  0   ;// where we are now in the stack
        unredo_table    dd  0   ;// the entire allocated block
        unredo_temp     dd  0   ;// allocated temp buffer (holds one record)
        unredo_global_id dd 0   ;// ever increasing id

        ;// ptr conversion

        hashd_Declare_internal unredo_id

    ;// the temp buffer gets a special header to make life easier
    ;// its the same as the UNREDO_NODE, but the dlist is replaced with size

        UNREDO_TEMP STRUCT

            dwSize  dd  ?   ;// size of the data in this block
            pad     dd  ?   ;// makes copying easier
            action  dd  ?
            stamp   dd  ?

        UNREDO_TEMP ENDS
        ;// action data follows

    ;// ptr to the location at which to record
    ;// behavior is action specific

        unredo_pRecorder    dd  0

    ;// flag that enables groups to tell context to check for id table

        unredo_delete       dd  0

    ;// need to save detection

        unredo_action_count dd  0   ;// counter of actions
        unredo_last_save    dd  0   ;// action number of last save
        unredo_last_action  dd  0   ;// last action we worked with
        unredo_we_are_dirty dd  0   ;// flag
        unredo_drop_counter dd  0   ;// counts dropped records

    ;// then we get to a mechanism to let the user move the screen
    ;// without trashing the redo
    comment ~ /*

    here's how this works:

        there are 4 commands that should not trash REDO

        MOVE_SCREEN, SCROLL, ENTER_GROUP, LEAVE_GROUP

        the goal is to allow user to UNDO a step, move the screen, then redo a step

        this requires a seperate stack of move screens

        when the stack is valid

            UNDO
                undo one stack
                if bottom is hit, invalidate the stack

            REDO
                undo the entire stack
                invalidate it
                then redo the next command

            ACTION
                condense the stack,
                insert the condensed stack into the unredo list,
                store the action
                invalidate the stack

        triggering:

            when unredo_store record is hit

                if the action is NOT storable (set_dirty == 0)
                if a REDO step is available
                    if the stack is not valid
                        start and validate a new stack
                    store the action to the stack

                if the action IS storable (set_dirty = 1)
                if the stack is valid

                    condense the stack
                        add move screens and scrolls together
                        enter and exit groups
                    store records as required
                    invalidate the stack

            in all cases: if the stack fills up, then force the record to trash the unredo


        details

            detecting if a REDO step is available
            pCurrent != dlist_Tail(unredo)

            detecting if the stack is valid

            pCurrentScreen != dlist_Head(unredo_screen)


    */ comment ~

        dlist_Declare unredo_screen     ;//, UNREDO_NODE, unredo
        unredo_screen_table     dd  0   ;// allocated ptr for screen stack
        unredo_pCurrentScreen   dd  0   ;// where we are in the screen stack
        unredo_unwinding        dd  0   ;// ptr and flag tells action_Undo how to proceed




;////////////////////////////////////////////////
;////////////////////////////////////////////////
;//
;//     S T R U C T   T A B L E and S I Z E S
;//



    ;// ACTION_RECORD contains information about how to proceed

        ACTION_RECORD   STRUCT

            dwSize      dd  0   ;// size of the extra data needed for the struct
            p_begin     dd  0   ;// ptr to the begin recording implementation
            p_end       dd  0   ;// ptr to the end recording implementation
            p_undo      dd  0   ;// ptr to the undo implementation
            p_redo      dd  0   ;// ptr to the redo implementation
            p_beginend  dd  0   ;// ptr to unified begin and end (use BEGINEND to set)
            pString     dd  0   ;// ptr to text
            set_dirty   dd  0   ;// flag updates unredo_last_action_time

        ACTION_RECORD   ENDS

        ACTION_TO_DW MACRO reg:req, reg1    ;// be sure to define this
            ;// given the action number
            ;// this will return the dword offset into the action table
            ;//
            ;//     ex: mov eax, action
            ;//         ACTION_TO_DW eax
            ;//         jmp action_table[eax*4].p_begin

            IFNB <reg1>
                lea reg1, [reg*8]       ;// * 8
            ELSE
                shl reg, 3
            ENDIF

            ENDM


    ;// these two macros define and initialize ACTION_RECORDS and strings

    ;// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    ;// !!!
    ;// !!!  DO NOT DEFINE DATA ITEMS BETWEEN ACTION_STRUCT
    ;// !!!
    ;// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

        action_sequence_check = -1  ;// used to make sure the sequence matches the index

        ACTION_STRUCT MACRO name:req, dirt:req, beginend

            ;// quick and dirty error check

            .ERRNDEF name, <name is not recognized !!>

            IF (action_sequence_check+1) NE (name)
            .ERR <name is out of sequence>
            ENDIF
            action_sequence_check = action_sequence_check + 1

            IFNB <beginend>
                action_&name&_has_begin_end = 1
            ELSE
                action_&name&_has_begin_end = 0
            ENDIF

            action_dirty_&name = dirt


            ;// start the structure

            action_&name    STRUCT      ;// declare the struct

                UNREDO_NODE {}          ;// all structs have a node

            ENDM

;// need to shift the source code left to prevent lines being too long
ACTION_ENDS MACRO   name:req

    ;;// quick and dirty error check
    .ERRNDEF name, <name is not recognized !!>

    ;;// end the structure

    action_&name    ENDS        ;// end the struct

    ;;// define the table values

    IF  action_&name&_has_begin_end EQ 1

        ACTION_RECORD { SIZEOF(action_&name),,,
            undo_action_&name, redo_action_&name,
            beginend_action_&name,
            OFFSET sz_&name, action_dirty_&name }

    ELSE

    ACTION_RECORD { SIZEOF(action_&name),
    begin_action_&name, end_action_&name,
    undo_action_&name, redo_action_&name,,
    OFFSET sz_&name, action_dirty_&name }

    ENDIF

    ENDM

;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;///
;///                                    definitions of action structs
;///    A C T I O N   T A B L E         also builds the jump tables
;///
;///                                    DO NOT DEFINE DATA IN THIS SECTION


    action_table LABEL ACTION_RECORD

        ACTION_STRUCT   UNREDO_EMPTY,0
        ACTION_ENDS     UNREDO_EMPTY


        ACTION_STRUCT   UNREDO_MOVE_SCREEN,0

            delta   POINT   {}

        ACTION_ENDS     UNREDO_MOVE_SCREEN


        ACTION_STRUCT   UNREDO_SCROLL,0

            delta   POINT   {}
            osc_ptr dd  0   ;// ptr to an osc to serve as a reference point (not stored)

        ACTION_ENDS     UNREDO_SCROLL


        ACTION_STRUCT   UNREDO_MOVE_OSC,1

            delta   POINT   {}
            num_id  dd  ?   ;// number of id's that follow
            id      dd  ?   ;// first id, others may follow

        ACTION_ENDS     UNREDO_MOVE_OSC


        ACTION_STRUCT   UNREDO_MOVE_PIN,1

            UNREDO_PHETA    {}

        ACTION_ENDS     UNREDO_MOVE_PIN


        ACTION_STRUCT   UNREDO_CONTROL_OSC,1

            id          dd  0   ;// id of the osc
            size_1      dd  0   ;// size of the first block
            size_2      dd  0   ;// size of the second block

            ;// two equal sized sections follow
            block_1 dd  0   ;// 1) the state before the action
                            ;// 2) the state after the action

        ACTION_ENDS     UNREDO_CONTROL_OSC


        ACTION_STRUCT   UNREDO_CONNECT_PIN,1

            UNREDO_PIN_CONNECT  {}

        ACTION_ENDS     UNREDO_CONNECT_PIN


        ACTION_STRUCT   UNREDO_UNCONNECT,1

            UNREDO_PIN_CONNECT {}

        ACTION_ENDS     UNREDO_UNCONNECT

    ;// BUS COMMANDS

        ACTION_STRUCT   UNREDO_BUS_CREATE,1, BEGINEND

            UNREDO_PIN  {}      ;// output pin for the bus
            bus dd  0           ;// bus number to create

        ACTION_ENDS     UNREDO_BUS_CREATE

        ACTION_STRUCT   UNREDO_BUS_RENAME,1, BEGINEND

            UNREDO_PIN  {}  ;// output pin
            bus1    dd  0   ;// new bus number
            bus2    dd  0   ;// origonal bus number

        ACTION_ENDS     UNREDO_BUS_RENAME

        ACTION_STRUCT   UNREDO_BUS_TRANSFER,1, BEGINEND

            UNREDO_PIN  {}  ;// input pin
            bus1    dd  0   ;// new bus number
            bus2    dd  0   ;// origonal number

        ACTION_ENDS     UNREDO_BUS_TRANSFER

        ACTION_STRUCT   UNREDO_BUS_CONVERTTO,1, BEGINEND

            UNREDO_PIN  {}  ;// output pin for the chain
            bus     dd  0   ;// bus number to convert to

        ACTION_ENDS     UNREDO_BUS_CONVERTTO

        ACTION_STRUCT   UNREDO_BUS_DIRECT,1, BEGINEND

            UNREDO_PIN  {}  ;// output pin for the chain
            bus     dd  0   ;// bus that was converted from

        ACTION_ENDS     UNREDO_BUS_DIRECT

        ACTION_STRUCT   UNREDO_BUS_PULL,1

            num_pins    dd  0   ;// number of pins that follow
            pin1 UNREDO_PHETA {}    ;// first of a list

        ACTION_ENDS     UNREDO_BUS_PULL


    ;// BUS NAME COMMANDS

        ACTION_STRUCT   UNREDO_BUS_CATCAT,1 ;// move cat to cat

            num_members dd  0   ;// number of members
            cat1        dd  0   ;// new category number
            cat2        dd  0   ;// old category number
            cat_name db 32 dup (0)  ;// name of old category
            member      dd  0   ;// [] member list

        ACTION_ENDS     UNREDO_BUS_CATCAT

        ACTION_STRUCT   UNREDO_BUS_CATDEL,1

            num_members dd  0   ;// number of members
            dummy_arg   dd  0   ;// needed to be compatible with CATCAT
            cat         dd  0   ;// old category number
            cat_name db 32 dup (0)  ;// name of old category
            member      dd  0   ;// [] member list of old cat

        ACTION_ENDS     UNREDO_BUS_CATDEL

        ACTION_STRUCT   UNREDO_BUS_MEMCAT,1

            cat1        dd  0   ;// new category number
            cat2        dd  0   ;// old category number
            member      dd  0   ;// member

        ACTION_ENDS     UNREDO_BUS_MEMCAT

        ACTION_STRUCT   UNREDO_BUS_CATINS,1

            cat         dd  0   ;// new category number
            cat_name db 32 dup (0)  ;// name of new category

        ACTION_ENDS     UNREDO_BUS_CATINS

        ACTION_STRUCT   UNREDO_BUS_CATNAME,1

            cat         dd  0   ;// category to work with
            name1 db 32 dup (0) ;// name of old category
            name2 db 32 dup (0) ;// name of new category

        ACTION_ENDS     UNREDO_BUS_CATNAME

        ACTION_STRUCT   UNREDO_BUS_MEMNAME,1

            member      dd  0   ;// number of member in question
            name1 db 32 dup (0) ;// old name
            name2 db 32 dup (0) ;// new name

        ACTION_ENDS     UNREDO_BUS_MEMNAME

    ;// OSC INSERT DELETE (see copious notes way below)
    ;//
    ;//     the structs in these sections
    ;//     use the following implied structure
    ;//     the order will be different for various actions
    ;//
    ;//     ID_TABLE        stores object id AND 1 lock id
    ;//     FILE_HEADER     a complete copy of a createable file
    ;//     CONNECT_TABLE   list of UNREDO_PIN_UNCON records, must be handled in reverse order

        ACTION_STRUCT   UNREDO_NEW_OSC,1

            base_id     dd  0   ;// base id we're creating
            osc_id      dd  0   ;// id of created osc
            pos      POINT {}   ;// position of the obejct

        ACTION_ENDS     UNREDO_NEW_OSC


        ACTION_STRUCT   UNREDO_DEL_OSC,1

            id_count    dd  0   ;// number of id's in the table
            file_ofs    dd  0   ;// offset from this struct to the file block
            con_ofs     dd  0   ;// offset from this struct to the connect table

        ACTION_ENDS     UNREDO_DEL_OSC
            ;// ID_TABLE
            ;// FILE_HEADER
            ;// CONNECT_TABLE



        ;// paste and clone are the same

        ACTION_STRUCT   UNREDO_PASTE,1

            id_count    dd  0   ;// number of items in the id table
            con_size    dd  0   ;// size of the connect table
            file_size   dd  0   ;// size of the file block

        ACTION_ENDS     UNREDO_PASTE
            ;// ID_TABLE
            ;// CONNECT_TABLE
            ;// FILE_HEADER


        ;// paste and clone are the same

        ACTION_STRUCT   UNREDO_CLONE_OSC,1

            id_count    dd  0   ;// number of items in the id table
            con_size    dd  0   ;// size of the connect table
            file_size   dd  0   ;// size of the file block

        ACTION_ENDS     UNREDO_CLONE_OSC
            ;// ID_TABLE
            ;// CONNECT_TABLE
            ;// FILE_HEADER


    ;// OSC COMMANDS

        ACTION_STRUCT   UNREDO_COMMAND_OSC,1

            ;// this should  be exactly like UNREDO_CONTROL_OSC

            id          dd  0   ;// id of the osc
            size_1      dd  0   ;// size of the first block
            size_2      dd  0   ;// size of the second block

            ;// two sections follow
            block_1 dd  0   ;// 1) the state before the action
                            ;// 2) the state after the action

        ACTION_ENDS     UNREDO_COMMAND_OSC
            ;// block_2

    ;// LOCK UNLOCK

        ACTION_STRUCT   UNREDO_LOCK_OSC,1, BEGINEND

            osc_count   dd  0   ;// number of oscs in list
            osc_id      dd  0   ;// first osc in list

        ACTION_ENDS     UNREDO_LOCK_OSC

        ACTION_STRUCT   UNREDO_UNLOCK_OSC,1, BEGINEND

            osc_count   dd  0   ;// number of oscs in list
            osc_id      dd  0   ;// first osc in list

        ACTION_ENDS     UNREDO_UNLOCK_OSC


    ;// VIEW GROUP

        ACTION_STRUCT   UNREDO_ENTER_GROUP,1    ;// , BEGINEND

            osc_id  dd  0   ;// store the osc that is the group
            num_id  dd  0   ;// number of id records that follow
                            ;// only the FIRST enter group will assign the id's

        ACTION_ENDS     UNREDO_ENTER_GROUP
            ;// a list of ID's follows


        ACTION_STRUCT   UNREDO_LEAVE_GROUP,1, BEGINEND

            osc_id  dd  0   ;// just store the osc that is the group

        ACTION_ENDS     UNREDO_LEAVE_GROUP

    ;// EDIT LABEL

        ACTION_STRUCT   UNREDO_EDIT_LABEL,1

            osc_id      dd  0   ;// id of the osc
            flags       dd  0   ;// edit flags, see below

            rect1   RECT    {}  ;// origonal position
            rect2   RECT    {}  ;// new position

            text_len1   dd  0   ;// length of first string
            text_len2   dd  0   ;// length of second string

        ACTION_ENDS     UNREDO_EDIT_LABEL
            ;// two strings may follow

            UNREDO_LABEL_SIZE_CHANGED       equ 1
            UNREDO_LABEL_TEXT_CHANGED       equ 2

    ;// CIRCUIT SETTINGS


        ACTION_STRUCT   UNREDO_SETTINGS,1

            old_settings    dd  0
            new_settings    dd  0

        ACTION_ENDS     UNREDO_SETTINGS


    ;// ALIGN OSCS

        ACTION_STRUCT   UNREDO_ALIGN,1
            ;// see notes below
        ACTION_ENDS     UNREDO_ALIGN




;///
;///                                    definitions of action structs
;///    A C T I O N   T A B L E         also builds the jump tables
;///
;///                                    DO NOT DEFINE DATA IN THIS SECTION
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////



;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;///
;///
;///    S T R I N G S
;///
;///

    sz_UNREDO_EMPTY         db  0
    sz_UNREDO_SCROLL        LABEL BYTE
    sz_UNREDO_MOVE_SCREEN   db  ' move screen.',0
    sz_UNREDO_MOVE_OSC      db  ' move object.',0
    sz_UNREDO_MOVE_PIN      db  ' move pin.',0
    sz_UNREDO_CONTROL_OSC   db  ' control object.',0
    sz_UNREDO_CONNECT_PIN   db  ' connect pins.',0
    sz_UNREDO_UNCONNECT     db  ' unconnect pins.',0
    sz_UNREDO_BUS_CREATE    db  ' create bus.',0
    sz_UNREDO_BUS_RENAME    db  ' rename bus.',0
    sz_UNREDO_BUS_TRANSFER  db  ' bus transfer.',0
    sz_UNREDO_BUS_CONVERTTO db  ' convert to bus.',0
    sz_UNREDO_BUS_DIRECT    db  ' convert to direct connection.',0
    sz_UNREDO_BUS_PULL      db  ' pull pins together.',0
    sz_UNREDO_BUS_CATCAT    db  ' move bus category.',0
    sz_UNREDO_BUS_CATDEL    db  ' delete bus category.',0
    sz_UNREDO_BUS_MEMCAT    db  ' move bus member.',0
    sz_UNREDO_BUS_CATINS    db  ' insert bus category.',0
    sz_UNREDO_BUS_CATNAME   db  ' change bus category name.',0
    sz_UNREDO_BUS_MEMNAME   db  ' change bus member name.',0

    sz_UNREDO_NEW_OSC       db  ' create object.',0
    sz_UNREDO_CLONE_OSC     db  ' clone object.',0
    sz_UNREDO_DEL_OSC       db  ' delete object.',0
    sz_UNREDO_PASTE         db  ' paste object.',0
    sz_UNREDO_COMMAND_OSC   db  ' object property.',0
    sz_UNREDO_LOCK_OSC      db  ' lock object.',0
    sz_UNREDO_UNLOCK_OSC    db  ' unlock object.',0
    sz_UNREDO_ENTER_GROUP   db  ' enter view group.',0
    sz_UNREDO_LEAVE_GROUP   db  ' leave view group.',0

    sz_UNREDO_EDIT_LABEL    db  ' edit label.',0

    sz_UNREDO_SETTINGS      db  ' circuit setting.',0

    sz_UNREDO_ALIGN         db  ' align objects.',0

    sz_cantundo db 'This operation is too big to undo.'
    sz_cantundotitle db 0

    sz_unredo_full  db  0ah,'The undo buffer is FULL!. Reload the circuit to reset it.',0

    ALIGN 16

;///
;///
;///    S T R I N G S
;///
;///
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////





;///////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////
;///
;///    H E L P E R   M A C R O S
;///
;///////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////


    ;// get current
    ;//
    ;//     grabs and assumes pCurrent

    unredo_GetCurrent MACRO reg:req

        mov reg, unredo_pCurrent
        ASSUME reg:PTR UNREDO_NODE

        ENDM

    ;// get temp
    ;//
    ;//     grabs and assumes temp buffer

    unredo_GetTemp MACRO reg:req

        mov reg, unredo_temp
        ASSUME reg:PTR UNREDO_TEMP

        ENDM

    ;// verify id
    ;//
    ;//     makes suret that an object has an id assigned

    unredo_VerifyId MACRO

        mov eax, [esi].id
        .IF !eax
            invoke unredo_assign_id
        .ENDIF

        ENDM


    ;// UPin to Osc Pin
    ;//
    ;//     retrieves pin pointer from UNREDO_PIN record
    ;//     destroys eax, edx

    unredo_UPinToPin MACRO UPIN:REQ, PIN:REQ

        .ERRIDNI <PIN>,<UPIN>

        .ERRIDNI <UPIN>,<eax>
        .ERRIDNI <PIN>,<eax>

        ;//.ERRIDNI <UPIN>,<edx>
        ;//.ERRIDNI <PIN>,<edx>

        ;// UPIN must be dot addressable

        mov eax, UPIN.id        ;// get the osc id
        hashd_Get unredo_id, eax, PIN   ;// turn into osc ptr
        add PIN, UPIN.pin       ;// ebx is output pin
        ASSUME PIN:PTR APIN

        ENDM




;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;///
;///
;///    A C T I O N   H A N D L E R S
;///
;///

    ;// to define the jumps, use one of these
    ;// reg can be passed to assume a register to the action struct


    comment ~ /*


        ACTION HANDLERS

            these get pretty involved
            to simplfy developement and navigation,
            we place specific action handlers in the same area
            there will be 4 parts, each sepcified by one of the macros below
            handlers may be shared if it is known that the action structures are compatible

            typical use


                BEGIN_ACTION_HANDLER UNREDO_MOVE_OBJECT

                    do work to record the action

                    ACTION_EXIT

                END_ACTION_HANDLER  UNREDO_MOVE_OBJECT

                    do work to finalize the action

                    ACTION_EXIT

                UNDO_ACTION_HANDLER UNREDO_MOVE_OBJECT

                    do work to undo the action

                    ACTION_EXIT

                REDO_ACTION_HANDLER UNREDO_MOVE_OBJECT

                    do work to redo the action

                    ACTION_EXIT

        */ comment ~

        BEGIN_ACTION_HANDLER MACRO name:req

            .ERRNDEF name, <name is not recognized !!>
            begin_action_&name::
            ASSUME ecx:PTR action_&name
            unredo_action_handler_exit TEXTEQU <unredo_begin_action_all_done>

            ENDM

        END_ACTION_HANDLER MACRO name:req

            .ERRNDEF name, <name is not recognized !!>
            end_action_&name::
            ASSUME ecx:PTR action_&name
            unredo_action_handler_exit TEXTEQU <unredo_end_action_all_done>

            ENDM

        BEGINEND_ACTION_HANDLER MACRO name:req

            .ERRNDEF name, <name is not recognized !!>
            beginend_action_&name::
            ASSUME ecx:PTR action_&name
            unredo_action_handler_exit TEXTEQU <unredo_beginend_action_all_done>

            ENDM


        UNDO_ACTION_HANDLER MACRO name:req

            .ERRNDEF name, <name is not recognized !!>
            undo_action_&name::
                ASSUME ecx:PTR action_&name
                ASSUME ebp:PTR LIST_CONTEXT
            unredo_action_handler_exit TEXTEQU <unredo_undo_action_all_done>

            ENDM

        REDO_ACTION_HANDLER MACRO name:req

            .ERRNDEF name, <name is not recognized !!>
            redo_action_&name::
                ASSUME ecx:PTR action_&name
                ASSUME ebp:PTR LIST_CONTEXT
            unredo_action_handler_exit TEXTEQU <unredo_redo_action_all_done>

            ENDM


        ACTION_EXIT MACRO

            jmp unredo_action_handler_exit
            unredo_action_handler_exit TEXTEQU <>

            ENDM





.CODE

;///////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////
;///
;///    initialize/destroy
;///


ASSUME_AND_ALIGN
unredo_Initialize PROC

    ;// allocate the main buffer and initialize the pointers

        DEBUG_IF <unredo_table> ;// already assigned !!

        invoke memory_Alloc, GPTR, UNREDO_BUFFER_SIZE
        mov unredo_table, eax

        mov dlist_Head(unredo), eax
        mov dlist_Tail(unredo), eax
        mov unredo_pCurrent, eax

    ;// allocate the temp buffer, this is wasteful ??

        invoke memory_Alloc, GPTR, UNREDO_TEMP_SIZE
        mov unredo_temp, eax

    ;// allocate the screen stack

        invoke memory_Alloc, GPTR, UNREDO_SCREEN_SIZE
        mov unredo_screen_table, eax
        mov dlist_Head(unredo_screen), eax
        mov dlist_Tail(unredo_screen), eax
        mov unredo_pCurrentScreen, eax

    ;// allocate the id hash table

        hashd_Initialize unredo_id

    ;// set the counters

        xor eax, eax
        mov unredo_global_id, eax
        mov unredo_last_save, eax
        mov unredo_last_action, eax
        mov unredo_we_are_dirty, eax
        mov unredo_action_count, eax
        mov unredo_drop_counter, eax

    ;// that should do it

        ret

unredo_Initialize ENDP

ASSUME_AND_ALIGN
unredo_Reset PROC


    ;// reset the main buffer pointers

        DEBUG_IF <!!unredo_table> ;// not assigned !!

        mov eax, unredo_table
        mov dlist_Head(unredo), eax
        mov dlist_Tail(unredo), eax
        mov unredo_pCurrent, eax

    ;// reset the screen stack

        mov eax, unredo_screen_table
        mov dlist_Head(unredo_screen), eax
        mov dlist_Tail(unredo_screen), eax
        mov unredo_pCurrentScreen, eax

    ;// reset the hashd table and it's pool

        hashd_Clear unredo_id

    ;// set the counters

        xor eax, eax
        mov unredo_global_id, eax
        mov unredo_last_save, eax
        mov unredo_last_action, eax
        mov unredo_we_are_dirty, eax
        mov unredo_action_count, eax
        mov unredo_drop_counter, eax
        mov unredo_unwinding, eax               ;// turn the interlock off

    ;// that should do it

        ret

unredo_Reset ENDP


ASSUME_AND_ALIGN
unredo_Destroy PROC

    mov eax, unredo_table
    .IF eax
        invoke memory_Free, eax
        mov unredo_table, eax
        mov dlist_Head(unredo), eax
        mov dlist_Tail(unredo), eax
        mov unredo_pCurrent, eax
    .ENDIF

    mov eax, unredo_temp
    .IF eax
        invoke memory_Free, eax
        mov unredo_temp, eax
    .ENDIF

    mov eax, unredo_screen_table
    .IF eax
        invoke memory_Free, eax
        mov unredo_screen_table, eax
        mov dlist_Head(unredo_screen), eax
        mov dlist_Tail(unredo_screen), eax
        mov unredo_pCurrentScreen, eax
    .ENDIF

    hashd_Destroy unredo_id

    ret

unredo_Destroy ENDP

;///
;///    initialize/destroy
;///
;///////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////



;///////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////
;///
;///    string getting      these store the string in the said buffer
;///                        returns eax as the END of the string
;///                        both presereve all registers excep eax

PROLOGUE_OFF
ASSUME_AND_ALIGN
unredo_GetUndoString PROC STDCALL pStr:DWORD

        push esi
        push edi

    ;// stack
    ;// esi edi ret pStr
    ;// 00  04  08  0C

        mov esi, unredo_pCurrentScreen      ;// check for screen stack first
    DEBUG_IF <!!esi>
        cmp esi, dlist_Head(unredo_screen)  ;// are we in a screen stack ?
        jne J0                              ;// ready to go if not

        unredo_GetCurrent esi       ;// not in a screen stack, use the current record
    DEBUG_IF <!!esi>
    J0: mov eax, 'odnU'             ;// load the prefix
        dlist_GetPrev unredo, esi   ;// point at previous record
    DEBUG_IF <!!esi>
        jmp unredo_store_the_string ;// jump to common storer

unredo_GetUndoString ENDP
PROLOGUE_ON

PROLOGUE_OFF
ASSUME_AND_ALIGN
unredo_GetRedoString PROC STDCALL pStr:DWORD

        push esi
        push edi

    ;// stack
    ;// esi edi ret pStr
    ;// 00  04  08  0C

        mov esi, unredo_pCurrentScreen      ;// check screen stack first
    DEBUG_IF <!!esi>
        mov eax, 'odeR'                     ;// load the common prefix
        cmp esi, dlist_Head(unredo_screen)  ;// are we in a screen stack ?
        je J0                               ;// get the current unredo record if not
        cmp esi, dlist_Tail(unredo_screen)  ;// are we at the last screen stack ?
        jne J1                              ;// use this record if we are not
    J0: unredo_GetCurrent esi               ;// otherwise use the current
    DEBUG_IF <!!esi>
    J1:
    unredo_store_the_string::

        ;// esi must point at the action record to use
        ;// eax must have the prefix

    DEBUG_IF <!!esi>

        mov edi, [esp+0Ch]
        mov esi, [esi].action

        stosd               ;// store the prefix

        ACTION_TO_DW esi
        mov esi, action_table[esi*4].pString

    top_of_loop:

        lodsb
        or al, al
        stosb
        je all_done
        lodsb
        or al, al
        stosb
        jnz top_of_loop

    all_done:

        mov eax, edi

        pop edi
        pop esi

        ret 4


unredo_GetRedoString ENDP
PROLOGUE_ON






;///////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////
;///
;///    O B J E C T   I D   H A N D E L E R
;///



ASSUME_AND_ALIGN
unredo_assign_id PROC

    ;// use this function to assign a new id to an object
    ;// returns the new id in eax

    ;// destroys edx

    ASSUME esi:PTR OSC_OBJECT
    DEBUG_IF <[esi].id> ;// this osc already has an ID, check first

    mov eax, unredo_global_id   ;// get the global id counter
    inc eax                     ;// increase it
    mov [esi].id, eax           ;// assign to osc
    mov unredo_global_id, eax   ;// store back in table

    ;// store osc pointer in the hash table
    ;// this expands to many many lines of code

    hashd_Insert unredo_id, eax, esi, edx

    ret

unredo_assign_id ENDP



;///
;///    O B J E C T   I D   H A N D E L E R
;///
;///////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////


    comment ~ /*

        it was too much of a chore to make the unredo_table a circular buffer
        at 1/4 meg with 4000 undo steps, scooting the table should only take 1ms at 400mhz
        so we'll scoot all the time

    algorithm details:

        p = table pointer
        T = table size
            used space      ___
        S = required size   ssssss
        h = head
        c = current
        A = space remaining ---

        0)  determine required size

            S = dwSize + SIZEOF UNREDO_NODE

        1)  check if record is too big

            S > T ? error, too big for table

            S==T ?  flush_table

        1)  compute available space

            A = T - (c-p)

            A >= S ?    jmp ready to store

        2)  need to make room

            a) advance h
            b)  h >= c ? flush table
            c) compute new space

                B = h-p

            d)  see if enough room

                A+B >= S  ?  ready_to_scoot

            e)  goto a

        3) ready_to_store:

            now that c is where we want to store
            and we know we have enough room
            things are simple

            1) xfer temp to c
            2) set pTail as c.next

            done

    */ comment ~


ASSUME_AND_ALIGN
PROLOGUE_OFF
unredo_store_this_record PROC STDCALL pUnredo:DWORD

    ;// destroys all registers except ebp

        push ebp

        ;// stack
        ;//
        ;// ebp ret pUnredo
        ;// 00  04  08

        st_unredo TEXTEQU <(DWORD PTR [esp+8])>

        mov esi, st_unredo
        ASSUME esi:PTR UNREDO_TEMP

    ;// state:
    ;//
    ;//     esi points a record

    ;// 0)  determine required size
    ;//
    ;//     S = dwSize + SIZEOF UNREDO_NODE

        mov ebx, [esi].dwSize
        add ebx, SIZEOF UNREDO_NODE ;// S

    ;// 1)  check if record is too big
    ;//
    ;//     S > T ? error, too big for table
    ;//
    ;//     S==T ?  flush_table

        cmp ebx, UNREDO_BUFFER_SIZE
        ja cant_undo
        je flush_table

    ;// 1)  compute available space
    ;//
    ;//     A = T - (c-p)
    ;//
    ;//     A > S ? jmp ready to store

        mov ecx, unredo_table       ;// p
        mov ebp, UNREDO_BUFFER_SIZE ;// T
        unredo_GetCurrent edi       ;// c
        add ebp, ecx                ;// T+p
        sub ebp, edi                ;// A = T - (c-p)

        cmp ebp, ebx        ;// A >= S ?
        jae ready_to_store

    ;// 2)  need to make room
    ;//
    ;// a) advance h

        ASSUME ecx:PTR UNREDO_NODE  ;// h

    make_some_room:

        dlist_GetNext unredo, ecx   ;// a) advance h
        inc unredo_drop_counter

    ;// b)  h >= c ? flush table

        cmp ecx, edi    ;// h>=c ?
        jae flush_table
        or ecx, ecx
        jz flush_table

    ;// c) compute new space B = h-p

        mov eax, ecx            ;// h
        sub eax, unredo_table   ;// p-h = B

    ;// d)  see if enough room  A+B < S  ?  ready_to_scoot

        add eax, ebp            ;// B+A
        cmp eax, ebx            ;// B+A >= S ?
        jb make_some_room

    ready_to_scoot:

        ;// state:
        ;// ecx is at the record we want to scoot back

    ;// a) move all the data

        mov edi, unredo_table   ;// dest data
        mov esi, ecx        ;// source data
        mov eax, edi
        sub eax, esi    ;// neg offset
        lea ecx, [eax+UNREDO_BUFFER_SIZE]   ;// amount to move
        shr ecx, 2
        rep movsd

    ;// b) adjust all the pointers

        ;//unredo_GetTemp esi       ;// esi must be set for ready_to_store

        mov esi, st_unredo
        ASSUME esi:PTR UNREDO_TEMP

        unredo_GetCurrent edi
        add edi, eax            ;// edi is where we want to store the new record

        mov ebx, unredo_table   ;// ebx will iterate the table
        ASSUME ebx:PTR UNREDO_NODE
        xor ecx, ecx            ;// ecx will be the prev iterator

    top_of_adjuster:

        mov edx, dlist_Next(unredo,ebx) ;// n2 = n1.next
        mov dlist_Prev(unredo,ebx), ecx ;// n1.prev = p
        add edx, eax                    ;// n2 -= offset
        cmp ebx, edi                    ;// n1 == C ?
        mov dlist_Next(unredo,ebx), edx ;// n1.next = n2
        je ready_to_store   ;// edi must be where to store

        mov ecx, ebx            ;// p = n1
        mov ebx, edx            ;// n1 = n2
        jmp top_of_adjuster


    cant_undo:

        ;// note: this should be safe to call from condense_records
        ;// as long as SCREEN_SIZE is LESS than UNREDO_SIZE

        IF UNREDO_SCREEN_SIZE GT UNREDO_BUFFER_SIZE
        .ERR
        ENDIF

        mov eax, unredo_table
        xor edx, edx

        mov unredo_pCurrent, eax
        mov dlist_Head(unredo), eax
        mov dlist_Tail(unredo), eax

        unredo_GetCurrent edi
        mov dlist_Next(unredo,edi), edx
        mov dlist_Prev(unredo,edi), edx

        ;// unredo_GetTemp ecx
        mov ecx, st_unredo
        ASSUME ecx:PTR UNREDO_TEMP

        inc unredo_drop_counter

        mov [ecx].action, edx
        mov unredo_pRecorder, edx

        or app_DlgFlags, DLG_MESSAGE
        invoke MessageBoxA, hMainWnd, OFFSET sz_cantundo, OFFSET sz_cantundotitle, MB_OK OR MB_APPLMODAL
        and app_DlgFlags, NOT DLG_MESSAGE

        pop ebp
        ret 4


    flush_table:

        mov eax, unredo_table
        xor edx, edx

        mov unredo_pCurrent, eax
        mov dlist_Head(unredo), eax
        mov dlist_Tail(unredo), eax

        unredo_GetCurrent edi
        mov dlist_Next(unredo,edi), edx
        mov dlist_Prev(unredo,edi), edx

        dlist_GetHead unredo, ecx
        ;// unredo_GetTemp esi
        mov esi, st_unredo
        ASSUME esi:PTR UNREDO_TEMP

        ;// jmp ready_to_store

    ready_to_store:
    ;//
    ;//     now that c is where we want to store
    ;//     and we know we have enough room
    ;//     things are simple
    ;//
    ;//     1) xfer temp to c
    ;//     2) set pTail as c.next
    ;//         done

        ;// state
        ;//
        ;//     esi = temp
        ;// c   edi = pCurrent

        mov ebx, edi                    ;// need to save for a moment
        dlist_GetPrev unredo, edi, edx  ;// save this as well
        ASSUME ebx:PTR UNREDO_NODE

        mov ecx, [esi].dwSize
        shr ecx, 2
        rep movsd

    ;// now we set the new tail and current

        ;// now edi is the new pCurrent
        ;// ebx is the previous pCurrent
        ;// edx is the previous previous

        mov dlist_Next(unredo,ebx), edi
        mov dlist_Prev(unredo,ebx), edx
        mov dlist_Next(unredo,edi), ecx ;// ecx is zero
        mov dlist_Prev(unredo,edi), ebx

    ;// if we were not already aware of it, tell the app to sync the option buttons

        .IF ebx != dlist_Tail(unredo) || !edx
            or app_bFlags, APP_SYNC_OPTIONBUTTONS
        .ENDIF

    ;// finish up setting the tail

        mov dlist_Tail(unredo), edi ;// set as tail
        mov unredo_pCurrent, edi    ;// set as current

    ;// that's it !

        pop ebp
        ret 4

unredo_store_this_record    ENDP
PROLOGUE_ON




;// condense screen stack

comment ~ /*

    ABox226 new version removes condensation of enter leav groups
            this should fix the mystery bug

*/ comment ~


    ;// developer error checks

    IF UNREDO_MOVE_SCREEN GT UNREDO_SCROLL
        .ERR < code assume move is less than scroll >
    ENDIF



ASSUME_AND_ALIGN
unredo_condense_screen_stack    PROC

    ;// destroys all regs except ebp

    ;// task:
    ;// walk the screen forwards and inject records into the unredo_list
    ;// combine all move screens and scrolls

        dlist_GetHead unredo_screen, esi
        xor ebx, ebx

        ASSUME ebx:PTR action_UNREDO_MOVE_SCREEN    ;// will be a 'last move processed flag'
        ASSUME esi:PTR action_UNREDO_MOVE_SCREEN

    top_of_condense_loop:

        mov eax, [esi].action           ;// get the action

        cmp eax, UNREDO_SCROLL          ;// MOVE || SCROLL ??
        ja have_to_store

            .IF ebx                     ;// do we have a point to combine ?
                point_Get [ebx].delta   ;// combine it
                point_AddTo [esi].delta
            .ENDIF

            mov ebx, esi                ;// set the new last point
            jmp next_node


        have_to_store:

            ;// flush the current record
            ;// store the command

            push dlist_Next(unredo_screen,esi)      ;// save the NEXT iterator
                                                    ;// we're going to overwrite it shortly
            .IF ebx         ;// check for previous record

                mov eax, dlist_Next(unredo_screen,ebx)
                sub eax, ebx
                DEBUG_IF <SIGN? || ZERO?>
                mov (UNREDO_TEMP PTR [ebx]).dwSize, eax
                invoke unredo_store_this_record, ebx    ;// store it
                mov esi, [esp]  ;// retrieve esi
            .ENDIF

            mov eax, dlist_Next(unredo_screen,esi)
            sub eax, esi
            DEBUG_IF <SIGN? || ZERO?>
            mov (UNREDO_TEMP PTR [esi]).dwSize, eax
            invoke unredo_store_this_record, esi    ;// store this record

            pop esi         ;// retrieve esi
            xor ebx, ebx    ;// clear the current point
            jmp got_next_node

    next_node:

        dlist_GetNext unredo_screen, esi

    got_next_node:

        cmp esi, dlist_Tail(unredo_screen)
        jne top_of_condense_loop

    ;// now we've scanned the buffer, check for anything left over

        .IF ebx
            mov eax, dlist_Next(unredo_screen,ebx)
            sub eax, ebx
            DEBUG_IF <SIGN? || ZERO?>
            mov (UNREDO_TEMP PTR [ebx]).dwSize, eax
            invoke unredo_store_this_record, ebx    ;// store it
        .ENDIF

    ;// then clear the unredo screen stack

        dlist_GetHead unredo_screen, esi        ;// get the head
        xor eax, eax
        mov dlist_Next(unredo_screen,esi), eax  ;// zero pNext
        mov dlist_Prev(unredo_screen,esi), eax  ;// zero pPrev
        mov unredo_pCurrentScreen, esi          ;// set current at head
        mov dlist_Tail(unredo_screen), esi      ;// set tail as head
        mov unredo_unwinding, eax               ;// turn the interlock off

    ;// that should do

        ret

unredo_condense_screen_stack    ENDP





;// condense screen stack






ASSUME_AND_ALIGN
unredo_add_record_to_screen_stack   PROC

    ;// action: unredo_temp -> unredo_screen_table

    ;// destroys esi, edi

    ;// Q: why don't we save some work and condense this as we go?
    ;// A: because it would confuse the user by removing undo steps

        ASSUME esi:PTR UNREDO_TEMP
        ASSUME edi:PTR UNREDO_NODE
        ASSUME edx:PTR UNREDO_NODE

        mov ecx, [esi].dwSize                   ;// get the size
        DEBUG_IF < ecx&3 >  ;// supposed to be dword size !!
        mov edi, unredo_pCurrentScreen          ;// get where to store it
        shr ecx, 2                              ;// make dword count
        mov eax, dlist_Prev(unredo_screen,edi)  ;// we're about to erase this
        mov edx, edi                            ;// save the previous record
        rep movsd                               ;// move the data

        mov dlist_Next(unredo_screen,edx), edi  ;// set the previous's next
        mov dlist_Prev(unredo_screen,edx), eax  ;// reset the previous's prev pointer

        mov dlist_Next(unredo_screen,edi), ecx  ;// zero
        mov dlist_Prev(unredo_screen,edi), edx  ;// set the new prev record

        mov dlist_Tail(unredo_screen), edi      ;// set the new tail
        mov unredo_pCurrentScreen, edi          ;// set the new current

        ret

unredo_add_record_to_screen_stack   ENDP



;// new version ABox226
;// we've removed enter leave groups


ASSUME_AND_ALIGN
unredo_unwind_screen_stack  PROC

    ;// in this step, we UNDO all records in the screen stack
    ;// this called from unredo_Redo

    ;// we'll work like condense does
    ;// then call undo in like fashion

    ;// scan the screen stack

        dlist_GetTail unredo_screen, esi
        xor ebx, ebx
        jmp next_node   ;// the tail is always invalid

        ASSUME ebx:PTR action_UNREDO_MOVE_SCREEN    ;// will be a 'last move processed flag'
        ASSUME esi:PTR action_UNREDO_MOVE_SCREEN

    top_of_unwind_loop:

        mov eax, [esi].action           ;// get the action

        cmp eax, UNREDO_SCROLL          ;// MOVE || SCROLL ??
        ja have_to_undo

            .IF ebx                     ;// do we have a point to combine ?
                point_Get [ebx].delta   ;// combine it
                point_AddTo [esi].delta
            .ENDIF

            mov ebx, esi                ;// set the new last point
            jmp next_node


        have_to_undo:

            ;// flush the current record
            ;// store the command

            .IF ebx         ;// check for previous record

                mov unredo_unwinding, ebx
                invoke unredo_Undo

            .ENDIF

            mov unredo_unwinding, esi
            invoke unredo_Undo

            xor ebx, ebx    ;// clear the current point

    next_node:

        dlist_GetPrev unredo_screen, esi
        test esi, esi
        jne top_of_unwind_loop

    ;// now we've scanned the buffer, check for anything left over

        .IF ebx
            mov unredo_unwinding, ebx
            invoke unredo_Undo
        .ENDIF

    ;// then clear the unredo_screen stack

        dlist_GetHead unredo_screen, esi        ;// get the head
        xor eax, eax
        mov dlist_Next(unredo_screen,esi), eax  ;// zero pNext
        mov dlist_Prev(unredo_screen,esi), eax  ;// zero pPrev
        mov unredo_pCurrentScreen, esi          ;// set current at head
        mov dlist_Tail(unredo_screen), esi      ;// set tail as head
        mov unredo_unwinding, eax               ;// turn the interlock off

    ;// that should do it

        ret

unredo_unwind_screen_stack ENDP








;///////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////
;//
;//     store_record    action: unredo_temp -> unredo_table
;//                             unredo_we_are_dirty
;//                             unredo_screen_table

.DATA
    ALIGN 4
    previous_oscZ_head  dd  0   ;// kludge fix, see kf01 below

.CODE




ASSUME_AND_ALIGN
unredo_store_record PROC

    ;// all registers are destroyed (except ebp)

        unredo_GetTemp esi  ;// xfer temp to esi

        DEBUG_IF <[esi].dwSize & 3>         ;// size is supposed to be dword aligned !!

    ;// 00) take care of stamp, dirty and screen stack

        mov eax, [esi].action
        ACTION_TO_DW eax
        .IF action_table[eax*4].set_dirty

            mov eax, unredo_action_count    ;// getthe global action counter
            inc eax                         ;// increase it
            mov [esi].stamp, eax            ;// save as this record's stamp
            mov unredo_last_action, eax     ;// save as last_action stamp
            mov unredo_action_count, eax    ;// save as newly updated action count

            .IF !unredo_we_are_dirty        ;// do we already know we are dirty ?
                dec unredo_we_are_dirty     ;// we are now
                or app_bFlags, APP_SYNC_TITLE OR APP_SYNC_SAVEBUTTONS
            .ENDIF

            ;// kf01
            ;// there is a case when we will be dirty, but need to sync the save buttons
            ;// this happens when all objects are deleted and a new one is added on
            ;// by not calling SyncSaveButtons, we will never be able to save the circuit

            ;// so we have to track the previous state and this state
            mov eax, master_context.oscZ_dlist_head ;// anchor.pHead

            .IF !previous_oscZ_head || !eax
                or app_bFlags, APP_SYNC_SAVEBUTTONS
            .ENDIF

            mov previous_oscZ_head, eax

        ;// check if the screen stack is on

            mov ecx, unredo_pCurrentScreen
            .IF ecx != dlist_Head(unredo_screen)

                ;// condense the screen stack into the master list

                invoke unredo_condense_screen_stack

            .ENDIF

        .ELSE   ;// action is not recordable

            unredo_GetCurrent edi           ;// are there redo steps available ?
            .IF edi != dlist_Tail(unredo)

                ;// add this record to the screen stack, then exit
                ;// check the size first

                mov eax, unredo_pCurrentScreen
                sub eax, unredo_screen_table

                KLUDGE_SIZE = (UNREDO_SCREEN_SIZE - (SIZEOF action_UNREDO_MOVE_SCREEN) )

                .IF eax < KLUDGE_SIZE   ;// add this record on the stack, then exit

                    invoke unredo_add_record_to_screen_stack
                    jmp all_done

                .ENDIF  ;// new record would overrun the table
                        ;// condense the stack, then add this like normal

                invoke unredo_condense_screen_stack

            .ENDIF

        .ENDIF

    ;// add the new record to the stack

        invoke unredo_store_this_record, unredo_temp

    all_done:

        ret

unredo_store_record ENDP

;//
;//     store_record    action: unredo_temp -> unredo_table
;//
;///////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////













;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//
;//     B E G I N   A C T I O N
;//

ASSUME_AND_ALIGN
unredo_begin_action PROC STDCALL USES ebx esi edi action:DWORD

IFDEF DEBUGBUILD
DEBUG_MESSAGE <unredo_begin_action>
mov eax, action
DEBUG_MESSAGE_REG eax
ENDIF

    ;// call begin action to reserve space and start recording

    ;// action --> temp buffer

        DEBUG_IF <action !> UNREDO_MAX_ACTION>
        DEBUG_IF <action !< UNREDO_MIN_ACTION>

        .IF unredo_pRecorder
            invoke unredo_end_action
        .ENDIF
        DEBUG_IF <unredo_pRecorder> ;// this was supposed to be shut off !!

        unredo_GetTemp ecx      ;// get the temp buffer

        mov eax, action         ;// get the action
        mov [ecx].action, eax   ;// store the action in the temp buffer

        ACTION_TO_DW eax        ;// convert to dw index

        mov edx, action_table[eax*4].dwSize ;// get the recommended size
        mov [ecx].dwSize, edx               ;// store in temp (action may redo this)

        jmp action_table[eax*4].p_begin ;// jump to the action starter

    BEGIN_ACTION_HANDLER UNREDO_EMPTY
    unredo_begin_action_all_done::

        ret

unredo_begin_action ENDP


;//
;//     B E G I N   A C T I O N
;//
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////









;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//
;//     E N D   A C T I O N
;//

ASSUME_AND_ALIGN
unredo_end_action PROC USES ebx esi edi

DEBUG_MESSAGE <unredo_end_action>


    ;// call this to finalize the action
    ;//
    ;// temp buffer --> unredo record

    ;// end_action handlers must:
    ;//
    ;//     assign object id.s
    ;//     set the size of the action correctly
    ;//     take care of the dirty value

        unredo_GetTemp ecx      ;// get ecx as the temp buffer

        mov eax, [ecx].action   ;// get the action code
        ACTION_TO_DW eax, eax   ;// convert to dw index

        jmp action_table[eax*4].p_end   ;// go

        ;// state:
        ;//
        ;//     ecx points at temp record

    unredo_end_action_all_done::

        invoke unredo_store_record

    END_ACTION_HANDLER UNREDO_EMPTY
    cancel_end_action::
    ;// then we want to reset the action in temp, in case we forgot something

        xor eax, eax
        mov ecx, unredo_temp    ;// get the temp buffer
        mov [ecx].action, eax   ;// eax is already zero
        mov unredo_pRecorder, eax   ;// reset incase someone forgot

        ret

unredo_end_action ENDP

;//
;//     E N D   A C T I O N
;//
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////





;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//
;//     B E G I N   E N D   A C T I O N
;//
comment ~ /*

    this function is not a standard proceedure

    it makes a call to unredo_end_action_all_done
    which will pop several registers from the stack

*/ comment ~

ASSUME_AND_ALIGN
unredo_beginend_action  PROC STDCALL USES ebx esi edi action:DWORD

    ;// BEGIN

        DEBUG_IF <unredo_pRecorder> ;// we are still recording !!!

        ;// mov unredo_pRecorder, 0;// clear this just in case

        mov eax, action     ;// get the action

        DEBUG_IF <eax !> UNREDO_MAX_ACTION>
        DEBUG_IF <eax !< UNREDO_MIN_ACTION>

        unredo_GetTemp ecx      ;// get the temp buffer

        mov [ecx].action, eax   ;// store the action in the temp buffer

        ACTION_TO_DW eax        ;// convert to dw index

        mov edx, action_table[eax*4].dwSize ;// get the recommended size
        mov [ecx].dwSize, edx               ;// store in temp (action may redo this)

        jmp action_table[eax*4].p_beginend  ;// jump to the unified action recorder


    ;// END

    unredo_beginend_action_all_done::

        invoke unredo_store_record

    ;// then we want to rest the action in temp, in case we forgot something

        xor eax, eax
        mov ecx, unredo_temp    ;// get the temp buffer
        mov [ecx].action, eax
        mov unredo_pRecorder, eax

        ret

unredo_beginend_action  ENDP


;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////

    ;// UNREDO_SIGNAL_DIRTY
    ;//
    ;//     if last action s are different, and we don't know we are dirty or not
    ;//     then signal the app to rebuild the title and save menus

    UNREDO_SIGNAL_DIRTY MACRO reg:req

        sub reg, unredo_last_save
        jne times_are_different

    times_are_same: ;// app is not dirty

        or reg, unredo_we_are_dirty
        jz done_with_signal

        or app_bFlags, APP_SYNC_SAVEBUTTONS OR APP_SYNC_TITLE
        inc unredo_we_are_dirty
        DEBUG_IF <!!ZERO?>
        jmp done_with_signal

    times_are_different:    ;// app is dirty

        cmp unredo_we_are_dirty, 0
        jne done_with_signal

        or app_bFlags, APP_SYNC_SAVEBUTTONS OR APP_SYNC_TITLE
        dec unredo_we_are_dirty
        DEBUG_IF <!!SIGN?>

    done_with_signal:

        ENDM





;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//
;//     U N D O     A C T I O N
;//
comment ~ /*


    undo is called from mainmenu_wm_command_proc

    undo actions must:

    1) back up pCurrent to the previouse record
    2) perform the desired undo step

*/ comment ~


ASSUME_AND_ALIGN
unredo_Undo PROC USES ebp esi ebx edi

    ;// if we are recording an action then we have to finish it
    ;// this may be a little on the UI

        DEBUG_IF <unredo_pRecorder> ;// this was supposed to be shut off !!

    ;// get the gui context

        stack_Peek gui_context, ebp
        xor ecx, ecx

    ;// return will call app_sync

    ;// account for unwinding

        or ecx, unredo_unwinding
        .IF !ZERO?

            ASSUME ecx:PTR UNREDO_NODE

            mov eax, [ecx].action       ;// getthe action
            ACTION_TO_DW eax                ;// convert action to dw index

            jmp action_table[eax*4].p_undo ;// jump to the undo handler

        .ENDIF

    ;// account for screen stack

        mov edx, unredo_pCurrentScreen
        cmp edx, dlist_Head(unredo_screen)  ;// are we in a screen stack ??
        je normal_undo_step                 ;// do normal undo is we are not

    screen_stack_undo_step: ;// we are in a screen stack

        ASSUME edx:PTR UNREDO_NODE

        dlist_GetPrev unredo_screen, edx, ecx   ;// backup one record
        mov eax, [ecx].action       ;// getthe action
        mov unredo_pCurrentScreen, ecx  ;// store the new pcurrentScreen
        ACTION_TO_DW eax                ;// convert action to dw index

        jmp action_table[eax*4].p_undo ;// jump to the undo handler

    normal_undo_step:
    ;// back up

        unredo_GetCurrent edx       ;// get the current action

        dlist_GetPrev unredo, edx, ecx  ;// backup one record
        mov eax, [ecx].action       ;// getthe action
        mov unredo_pCurrent, ecx    ;// store the new pcurrent
        ACTION_TO_DW eax            ;// convert action to dw index

    ;// take care of the menu

        .IF ecx == dlist_Head(unredo) || edx == dlist_Tail(unredo)
            or app_bFlags, APP_SYNC_OPTIONBUTTONS
        .ENDIF

    ;// take care of the time stamp

        .IF action_table[eax*4].set_dirty

            dlist_GetPrev unredo, ecx, edx
            .IF edx
                mov edx, [edx].stamp
            .ELSE
                sub edx, unredo_drop_counter
            .ENDIF

            mov unredo_last_action, edx

            UNREDO_SIGNAL_DIRTY edx

        .ENDIF

    ;//  and jmp to handler

        jmp action_table[eax*4].p_undo ;// jump to the undo handler

    unredo_undo_action_all_done::

        ;// see kf01 for details
        mov eax, master_context.oscZ_dlist_head ;// anchor.pHead
        .IF !previous_oscZ_head || !eax
            or app_bFlags, APP_SYNC_SAVEBUTTONS
        .ENDIF
        mov previous_oscZ_head, eax

    UNDO_ACTION_HANDLER UNREDO_EMPTY

        ret

unredo_Undo ENDP
;//
;//     U N D O   A C T I O N
;//
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////


;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//
;//     R E D O     A C T I O N
;//

comment ~ /*

    Redo must:

    1) do the action at pCurrent
    2) move forward one record

*/ comment ~

ASSUME_AND_ALIGN
unredo_Redo PROC USES ebp esi edi ebx

    ;// if we are recording, then we really don't know what to redo
    ;// this is prblematic

        DEBUG_IF <unredo_pRecorder> ;// this was supposed to be shut off !!

        stack_Peek gui_context, ebp

    ;// account for screen stack

        mov ecx, unredo_pCurrentScreen
        cmp ecx, dlist_Head(unredo_screen)  ;// are we in a screen stack ?
        je normal_redo_step                 ;// do normal if not

    screen_stack_redo_step:     ;// we ARE in a screen step

        ASSUME ecx:PTR UNREDO_NODE

        cmp ecx, dlist_Tail(unredo_screen)  ;// are we at the last step ?
        je screen_unwind_then_normal        ;// if so, we unwind

    screen_redo_step:       ;// we are in a normal screen step

        dlist_GetNext unredo_screen, ecx, edx   ;// get the next step
        mov eax, [ecx].action                   ;// get the action
        mov unredo_pCurrentScreen, edx          ;// store the newly advanced iterator
        ACTION_TO_DW eax                        ;// convert action to dw index
        jmp action_table[eax*4].p_redo          ;// jump to the redo handler

    screen_unwind_then_normal:  ;// have to unwind first

        invoke unredo_unwind_screen_stack

    normal_redo_step:
    ;// return will call app_sync

        unredo_GetCurrent ecx       ;// get the current action
        mov eax, [ecx].action       ;// get the action
        dlist_GetNext unredo, ecx, edx  ;// get the next record
        ACTION_TO_DW eax            ;// convert action to dw index
        mov unredo_pCurrent, edx    ;// save the new record

    ;// take care of the menu


        .IF ecx == dlist_Head(unredo) || edx == dlist_Tail(unredo)
            or app_bFlags, APP_SYNC_OPTIONBUTTONS
        .ENDIF

    ;// take care of time stamp

        .IF action_table[eax*4].set_dirty

            mov edx, [ecx].stamp
            mov unredo_last_action, edx

            UNREDO_SIGNAL_DIRTY edx

        .ENDIF

    ;// jmp to action handler

        jmp action_table[eax*4].p_redo ;// jump to the redo handler

    unredo_redo_action_all_done::

        ;// see kf01 for details
        mov eax, master_context.oscZ_dlist_head
        .IF !previous_oscZ_head || !eax
            or app_bFlags, APP_SYNC_SAVEBUTTONS
        .ENDIF
        mov previous_oscZ_head, eax

    REDO_ACTION_HANDLER UNREDO_EMPTY

        ret

unredo_Redo ENDP
;//
;//     R E D O     A C T I O N
;//
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////





















;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//
;//     H A N D L E R S
;//
;//     assume ecx points at the desired action struct
;//     assume esi, ebx and edi are what they were when the function was called
;//     undo and redo can assume ebp:PTR LIST_CONTEXT

;// handlers may use all of the registers except ebp


    ;////////////////////////////////////////////////////////////////////////////////////////////
    ;//
    ;//  MOVE_SCREEN, amoung others
    ;//  SCROLL
    ;//


    BEGIN_ACTION_HANDLER UNREDO_MOVE_SCREEN

        point_Get mouse_now

    begin_move_screen:

        point_Set [ecx].delta

        ACTION_EXIT

    BEGIN_ACTION_HANDLER UNREDO_SCROLL

        stack_Peek gui_context, ebx
        dlist_GetHead oscZ, ebx, [ebx]
        mov [ecx].osc_ptr, ebx

        point_GetTL [ebx].rect

        jmp begin_move_screen


    END_ACTION_HANDLER UNREDO_MOVE_OSC      ;// same code, why waste space
    END_ACTION_HANDLER UNREDO_MOVE_SCREEN

        point_Get mouse_now

    end_move_screen:

        point_SubTo [ecx].delta

        ;// check for zero move
        point_Get [ecx].delta
        or eax, edx
        jz cancel_end_action

        ACTION_EXIT


    END_ACTION_HANDLER  UNREDO_SCROLL

        GET_OSC_FROM ebx, [ecx].osc_ptr
        point_GetTL [ebx].rect
        ;// adjust size so we don't store the pointer osc
        sub (UNREDO_TEMP PTR [ecx]).dwSize, 4

        jmp end_move_screen ;// exit to common


    UNDO_ACTION_HANDLER UNREDO_SCROLL
    UNDO_ACTION_HANDLER UNREDO_MOVE_SCREEN

        point_Get [ecx].delta

        jmp unredo_move_screen

    REDO_ACTION_HANDLER UNREDO_SCROLL
    REDO_ACTION_HANDLER UNREDO_MOVE_SCREEN

        point_Get [ecx].delta
        point_Neg

    unredo_move_screen:

        point_Set mouse_delta
        or app_bFlags, APP_MODE_MOVING_SCREEN
        invoke context_MoveAll
        and app_bFlags, NOT APP_MODE_MOVING_SCREEN

        ACTION_EXIT


    ;//
    ;//  MOVE_SCREEN
    ;//  SCROLL
    ;//
    ;////////////////////////////////////////////////////////////////////////////////////////////

    ;////////////////////////////////////////////////////////////////////////////////////////////
    ;//
    ;//  MOVE_OSC       uses osc_down to initialize
    ;//                 app_bFlags.MOVING_SINGLE must be valid
    ;//                 accounts for locked and selected items

    MOVE_OSC_ADD_TO_TEMP    MACRO

        ;// this macro is used in three spots below

        ;// esi is the osc to add
        ;// ecx points at temp
        ;// uses edx, eax

        unredo_VerifyId         ;// make sure it has id
        mov edx, [ecx].num_id   ;// get the count
        add (UNREDO_TEMP PTR [ecx]).dwSize, 4       ;// bump the size
        mov [ecx+edx*4].id, eax ;// add the id at the end of the list
        inc edx                 ;// increase the id count
        mov eax, (UNREDO_TEMP PTR [ecx]).dwSize
        mov [ecx].num_id, edx   ;// store the number

        .IF eax >= MEMORY_SIZE(ecx)

            lea eax, [eax+eax*2]
            shr eax, 1
            and eax, -4
            invoke memory_Expand, ecx, eax
            mov ecx, eax
            mov unredo_temp, eax

        .ENDIF

        ENDM

    BEGIN_ACTION_HANDLER UNREDO_MOVE_OSC

        ;// set the begin point

            point_Get mouse_now
            point_Set [ecx].delta

        ;// now we have to go to the trouble of adding all attached
        ;// oscs to the undo list

        ;// the logic for this is:
        ;// 1) move the osc, no matter what
        ;// 2) if osc_down is selected --
        ;//     move selection list
        ;//         if any items in selection list are locked
        ;//             move all of those
        ;//     set a has moved bit for everything moved
        ;//     do a second scan to clean up the bits
        ;// 3) else if osc is locked
        ;//     move items in lock list

            DEBUG_IF <!!osc_down>

            GET_OSC_FROM esi, osc_down

        ;// add selected osc to temp buffer

            unredo_VerifyId         ;// make sure it has an id
            mov [ecx].id, eax       ;// store the id
            mov [ecx].num_id, 1     ;// set num_id to 1

        ;// if we're in single mode, then don't bother searching

            test app_bFlags, APP_MODE_MOVING_OSC_SINGLE
            jnz unredo_action_handler_exit

            xor eax, eax                ;// clear for testing

        ;// cmp eax, [esi].pNextS       ;// selected ?
            cmp eax, clist_Next(oscS,esi);// selected ?
            jnz move_sel1_enter

        ;// cmp eax, [esi].pNextL       ;// locked
            cmp eax, clist_Next(oscL,esi);// locked
            jz unredo_action_handler_exit;// exit if not

        move_locked_top:    ;// move locked objects

            clist_GetNext oscL, esi ;// get the next osc
            cmp esi, osc_down       ;// done yet ?
            je unredo_action_handler_exit   ;// exit if so

        ;// add osc to temp

            MOVE_OSC_ADD_TO_TEMP    ;// add osc to temp

            jmp move_locked_top     ;// next osc

        ;// move selected items, this takes two scan
        ;// the first scan moves and sets a has_moved bit
        ;// the second cleans up the bit
        ;//
        ;// this is required if two selected items are on the same lock list
        ;// then the third item in the lock list will get moved twice

            ;// scan 1

            move_sel1_top:  ;// move selected and attached locked objects

                clist_GetNext oscS, esi     ;// clists iterate first
                cmp esi, osc_down           ;// done yet ?
                je move_sel2_enter          ;// goto next part if done

                test [esi].dwHintOsc, HINTOSC_STATE_PROCESSED
                jnz move_sel1_top           ;// already moved ?

                MOVE_OSC_ADD_TO_TEMP    ;// add osc to temp

            move_sel1_enter:

                or [esi].dwHintOsc, HINTOSC_STATE_PROCESSED

            ;// cmp [esi].pNextL, 0         ;// locked ?
                cmp clist_Next(oscL,esi), 0 ;// locked ?
                jz move_sel1_top            ;// next osc if not

                push esi                    ;// save so we know when to stop

            move_sel1_locked_top:           ;// top of the loop

                clist_GetNext oscL, esi     ;// get next locked item
                cmp esi, [esp]              ;// compare with where we started
                je move_sel1_locked_done    ;// done if same

                test [esi].dwHintOsc, HINTOSC_STATE_PROCESSED
                jnz move_sel1_locked_top    ;// already moved ?

                or [esi].dwHintOsc, HINTOSC_STATE_PROCESSED

                MOVE_OSC_ADD_TO_TEMP    ;// add osc to temp

                jmp move_sel1_locked_top

            move_sel1_locked_done:          ;// done with move selected locked

                pop esi                     ;// retrive esi
                jmp move_sel1_top           ;// jmp to top of selected loop

            ;// scan 2  turn off the PROCESSED bits

            move_sel2_top:      ;// clean up from previous scan

                clist_GetNext oscS, esi     ;// clists iterate first
                cmp esi, osc_down           ;// done yet ?
                je unredo_action_handler_exit           ;// exit if done

                test [esi].dwHintOsc, HINTOSC_STATE_PROCESSED
                jz move_sel2_top            ;// already reset

            move_sel2_enter:

                and [esi].dwHintOsc, NOT HINTOSC_STATE_PROCESSED

            ;// cmp [esi].pNextL, 0         ;// locked ?
                cmp clist_Next(oscL,esi),0  ;// locked ?
                jz move_sel2_top            ;// next osc if not

            ;// reset the unselected lock list items

                push esi                    ;// save so we know when to stop

            move_sel2_locked_top:           ;// top of the loop

                clist_GetNext oscL, esi     ;// get next locked item
                cmp esi, [esp]              ;// compare with where we started
                je move_sel2_locked_done    ;// done if same

                and [esi].dwHintOsc, NOT HINTOSC_STATE_PROCESSED

                jmp move_sel2_locked_top

            move_sel2_locked_done:          ;// done with move selected locked

                pop esi                 ;// retrive esi
                jmp move_sel2_top       ;// jmp to top of selected loop


        ;// ACTION_EXIT

    ;// END_ACTION_HANDLER UNREDO_MOVE_OSC

        ; defined above under move screen

    ;// point_Get mouse_now
    ;// point_SubTo [ecx].delta

    ;// ACTION_EXIT

    UNDO_ACTION_HANDLER UNREDO_MOVE_OSC

        ;// set the delta

            point_Get [ecx].delta
            point_Set mouse_delta

        ;// process all items in the list

        ;// determine when stop. cant use pNext because the list may wrap
        ;// we'll use esi as an id iterator

        move_selected_oscs:

            mov edx, [ecx].num_id   ;// get the number of id's
            lea esi, [ecx].id       ;// point at first id
            lea edx, [esi+edx*4]    ;// point at one passed end
            push edx                ;// store one passed end

        undo_move_osc_top:          ;// top of loop

            lodsd       ;// load the ptr id, advance esi
            push esi    ;// store id iterator back on stack

            hashd_Get unredo_id, eax, esi ;// get the ptr
            OSC_TO_BASE esi, edi        ;// get the base class
            invoke [edi].gui.Move       ;// move the osc

            pop esi         ;// retieve the id iterator
            cmp esi, [esp]  ;// check if we're done
            jb undo_move_osc_top

            pop eax     ;// clean up the stack

        ACTION_EXIT

    REDO_ACTION_HANDLER UNREDO_MOVE_OSC

        point_Get [ecx].delta
        point_Neg
        point_Set mouse_delta

        jmp move_selected_oscs  ;// jump to routine above



    ;//  MOVE_OSC       uses osc_down to initialize
    ;//                 accounts for locked and selected items
    ;//
    ;////////////////////////////////////////////////////////////////////////////////////////////




    ;////////////////////////////////////////////////////////////////////////////////////////////
    ;//
    ;//  MOVE_PIN       assumes that pin_down is the cirrect object
    ;//

    BEGIN_ACTION_HANDLER UNREDO_MOVE_PIN

        GET_PIN pin_down, ebx
        PIN_TO_OSC ebx, esi
        unredo_VerifyId
        mov [ecx].id, eax

        mov eax, [ebx].pheta        ;// get the beginning pheta
        mov [ecx].x, eax        ;// store in object

        sub ebx, esi
        mov [ecx].pin, ebx

        ACTION_EXIT

    END_ACTION_HANDLER UNREDO_MOVE_PIN

        unredo_UPinToPin [ecx], ebx

        mov eax, [ebx].pheta        ;// get the ending pheta
        mov [ecx].y, eax        ;// save in record

        ACTION_EXIT

    UNDO_ACTION_HANDLER UNREDO_MOVE_PIN

        unredo_UPinToPin [ecx], ebx

        mov eax, [ecx].x

    move_pin_common:

        mov [ebx].pheta, eax

        GDI_INVALIDATE_PIN HINTI_PIN_PHETA_CHANGED

        ACTION_EXIT

    REDO_ACTION_HANDLER UNREDO_MOVE_PIN

        unredo_UPinToPin [ecx], ebx

        mov eax, [ecx].y

        jmp move_pin_common

    ;//
    ;//  MOVE_PIN       assumes that pin_down is the cirrect object
    ;//
    ;////////////////////////////////////////////////////////////////////////////////////////////


    ;////////////////////////////////////////////////////////////////////////////////////////////
    ;//
    ;//  CONTROL_OSC    uses osc_down to initialize
    ;//  COMMAND_OSC
    ;//
    comment ~ /*

        control commands rely on the osc's SaveUndo and LoadUndo functions

        all oscs with controls must handle these functions

    */ comment ~

    BEGIN_ACTION_HANDLER    UNREDO_COMMAND_OSC

        mov esi, popup_Object
        or esi, esi
        jnz begin_osc_command

        or esi, osc_hover
        jnz begin_osc_command

        mov [ecx].action, 0 ;// this action must be canceled !!
        ACTION_EXIT         ;// may never happen outside a debugging context


    BEGIN_ACTION_HANDLER    UNREDO_CONTROL_OSC

        GET_OSC_FROM esi, osc_down  ;// get the osc in question
        DEBUG_IF <!!esi>    ;// osc_down is zero !!

    begin_osc_command:

        ;// 1) make a call to save undo

            OSC_TO_BASE esi, ebx        ;// get the base class
            mov ebx, [ebx].gui.SaveUndo ;// load the save undo functiom

            DEBUG_IF <!!ebx>    ;// controlls need an undo pair

            unredo_VerifyId         ;// make sure it has an id
            mov [ecx].id, eax       ;// save the id
            lea edi, [ecx].block_1  ;// point at where to record
            mov edx, [ecx].action   ;// load the save code
        push edi                ;// save the start point

            call ebx                ;// call osc.SaveUndo
            DEBUG_IF < edi & 3>     ;// supposed to be dword aligned !!

        ;// 2) determine the resultant size

        pop eax                 ;// retrieve where we started to save
            mov ecx, unredo_temp    ;// reload the temp buffer (not always nessesary)
            sub edi, eax            ;// subtract to get size
            mov [ecx].size_1, edi   ;// save the block 1 size

            ACTION_EXIT

    END_ACTION_HANDLER  UNREDO_COMMAND_OSC
    END_ACTION_HANDLER  UNREDO_CONTROL_OSC

        ;// 1) make a call to save undo

            mov eax, [ecx].id       ;// load the id from the action record
            hashd_Get unredo_id, eax, esi       ;// get the osc in question
            DEBUG_IF <!!esi>        ;// no osc was stored !!

            OSC_TO_BASE esi, ebx    ;// get the base class
            mov ebx, [ebx].gui.SaveUndo ;// load the save undo functiom
            DEBUG_IF <!!ebx>        ;// this was supposed to be valid !!

            lea edi, [ecx].block_1  ;// get the block_1 address
            mov edx, [ecx].action   ;// load the save code
            add edi, [ecx].size_1   ;// scoot to where we put this data

        push edi    ;// save for the next part

            call ebx                ;// call osc.SaveUndo
            DEBUG_IF < edi & 3>     ;// supposed to be dword aligned !!

        ;// 2) determine the resultant block_2 size and the total size

            mov eax, [esp]          ;// retrive start of block 2
            mov ecx, unredo_temp    ;// reload the temp buffer (not always nessesary)
            sub eax, edi            ;// neg size block_2
            sub edi, ecx            ;// total size
            neg eax

            mov [ecx].size_2, eax
            mov (UNREDO_TEMP PTR [ecx]).dwSize, edi

        ;// 3) check for nul actions

        pop esi                 ;// retrieve the block 2 pointer

            lea edi, [ecx].block_1  ;// get the block 1 pointer

            mov eax, [ecx].size_1
            .IF eax == [ecx].size_2

                mov ecx, eax        ;// get the begin size
                shr ecx, 2          ;// compare in dwords
                repe cmpsd          ;// compare all the dwords
                je cancel_end_action;// if same, exit to cancel

            .ENDIF

            ACTION_EXIT             ;// otherwise exit to common storage routine


    UNDO_ACTION_HANDLER UNREDO_CONTROL_OSC

        lea edi, [ecx].block_1      ;// point at where to load
        jmp unredo_control_common

    REDO_ACTION_HANDLER UNREDO_CONTROL_OSC

        mov eax, [ecx].size_1
        lea edi, [ecx+eax].block_1

    unredo_control_common:

        mov eax, [ecx].id       ;// load the id from the action record
        hashd_Get unredo_id, eax, esi   ;// get the osc in question
        DEBUG_IF <!!esi>        ;// no osc was stored !!

        OSC_TO_BASE esi, ebx    ;// get the base class
        mov ebx, [ebx].gui.LoadUndo ;// load the save undo functiom
        DEBUG_IF <!!ebx>        ;// this was supposed to be valid !!

        mov edx, [ecx].action    ;// load the save code

        call ebx    ;// call osc.LoadUndo

        GDI_INVALIDATE_OSC HINTI_OSC_UPDATE

        ACTION_EXIT


    UNDO_ACTION_HANDLER UNREDO_COMMAND_OSC

        lea edi, [ecx].block_1  ;// point at where to load
        jmp unredo_command_common

    REDO_ACTION_HANDLER UNREDO_COMMAND_OSC

        mov eax, [ecx].size_1
        lea edi, [ecx+eax].block_1

    unredo_command_common:

        mov eax, [ecx].id       ;// load the id from the action record
        hashd_Get unredo_id, eax, esi   ;// get the osc in question
        DEBUG_IF <!!esi>        ;// no osc was stored !!

        OSC_TO_BASE esi, ebx    ;// get the base class
        mov ebx, [ebx].gui.LoadUndo ;// load the save undo functiom
        DEBUG_IF <!!ebx>        ;// this was supposed to be valid !!

        ENTER_PLAY_SYNC GUI

        mov edx, UNREDO_COMMAND_OSC ;// load the save code
        call ebx                    ;// call osc.LoadUndo

        GDI_INVALIDATE_OSC HINTI_OSC_UPDATE

        jmp unredo_play_sync_done

    ;//
    ;//  CONTROL_OSC
    ;//  COMMAND_OSC
    ;//
    ;////////////////////////////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////////
;//
;//     connect and unconnect helpers
;//

ASSUME_AND_ALIGN
PROLOGUE_OFF
unredo_con_get_size PROC STDCALL pPin:DWORD

        xchg ebx, [esp+4]

        ASSUME ebx:PTR APIN

    ;// uses eax, edx

    ;// task: determine the size of the UNREDO_PIN_CONNECT record
    ;//         if this pin were to be unconnected
    ;//         used in an array, the accumulated size may be more than is required
    ;// method:
    ;//
    ;//     if( !connected ) 0
    ;//     if( input pin ) sizeof() + 2 UNREDO_PIN records = 2
    ;//     else(output pin) sizeof() + 1 + number of pins UNREDO_RECORDS

        mov edx, [ebx].pPin ;// get the other pin
        ASSUME edx:PTR APIN
        xor eax, eax        ;// default size is zero

    ;// connected ?

        or edx, edx         ;// is pin connected ?
        jnz in_or_out       ;// jump if yes
        test [ebx].dwStatus, PIN_BUS_TEST   ;// maybe it's a bus ?
        jz all_done         ;// if not, then size = 0

    in_or_out:              ;// we are connected
    ;// input pin ?

        test [ebx].dwStatus, PIN_OUTPUT
        mov eax, SIZEOF UNREDO_PIN_CONNECT + SIZEOF UNREDO_PIN  ;// inputs have two pins
        jz all_done         ;// if we were input, we're good to go

    ;// output pin

        sub eax, SIZEOF UNREDO_PIN  ;// ouputs have minum of 1 pin

        or edx, edx     ;// were we connected ?
        jz all_done     ;// good to go if not

    ;// we were connected, count the pins

    J0: mov edx, [edx].pData
        add eax, SIZEOF UNREDO_PIN

        or edx, edx
        jz all_done

        mov edx, [edx].pData
        add eax, SIZEOF UNREDO_PIN

        or edx, edx
        jnz J0

    all_done:

        xchg ebx, [esp+4]
        ret 4

unredo_con_get_size ENDP
PROLOGUE_ON

ASSUME_AND_ALIGN
PROLOGUE_OFF
unredo_con_xlate_ids PROC STDCALL pPinConnect:DWORD

    ;// task:   xlate all the pin pointers in this record
    ;//         to UNREDO_PIN records
    ;//         num_pins must be correct

    ;// destroys edi, esi, ebx, edx, eax

    ;// preserves ecx

    ;// returns ebx as the end of the block

        xchg ecx, [esp+4]
        ASSUME ecx:PTR UNREDO_PIN_CONNECT

        mov edi, [ecx].num_pin
        DEBUG_IF <!!edi>    ;// no pins !! don't call this

        lea ebx, [ecx].con  ;// point at first pin
        ASSUME ebx:PTR UNREDO_PIN

        .REPEAT

            GET_PIN [ebx].pin, eax  ;// get the ptr in eax
            PIN_TO_OSC eax, esi     ;// get it's osc

            unredo_VerifyId         ;// make sure osc has an id

            mov [ebx].id, eax       ;// save the id in UNREDO_PIN
            sub [ebx].pin, esi      ;// subtract the osc ptr to make a pin offset
            add ebx, SIZEOF UNREDO_PIN  ;// advance to next UNREDO_PIN record
            dec edi                 ;// decrease the pin count

        .UNTIL ZERO?

        xchg ecx, [esp+4]
        ret 4

unredo_con_xlate_ids ENDP
PROLOGUE_ON


ASSUME_AND_ALIGN
PROLOGUE_OFF
unredo_con_undo PROC STDCALL pPinConnect:DWORD

    ;// UNREDO_PIN_CONNECT assumes the pins were connected to create the record
    ;// so we want to reverse the action

    ;// destroys edi esi ebx edx eax
    ;// preserves ecx

        xchg ecx, [esp+4]
        ASSUME ecx:PTR UNREDO_PIN_CONNECT

        DEBUG_IF <!![ecx].num_pin>  ;// no pins !! don't call this

    ;// for all of the these, we'll need a pointer to the pin
    ;// and the value of the first pin

        lea esi, [ecx].con          ;// esi will always walk UNREDO_PIN records
        ASSUME esi:PTR UNREDO_PIN

    ;// set ebx as the first pin in the UNREDO_PIN_CONNECT list

        mov eax, [esi].id
        hashd_Get unredo_id, eax, ebx
        xor edx, edx
        add ebx, [esi].pin
        ASSUME ebx:PTR APIN         ;// ebx is now the first pin

    ;// set esi to points at SECOND record in list

        add esi, SIZEOF UNREDO_PIN

    ;// jump to the correct mode

        or edx, [ecx].mode      ;// load and test the mode
        js undo_is_input

    undo_is_output_or_special:

        jz undo_is_mode_0

    ;// UNREDO_CON_CO_UO    EQU 256 ;//                     from output, to output
        cmp edx, UNREDO_CON_CO_UO
        je undo_is_mode_CO_UO
        ja undo_is_mode_CI_UI_or_CO_CO_or_CI_UOCO

    undo_is_mode_b: ;// edx is bus number

    undo_is_mode_0: ;// output list follows

        ;// all we have to do is unconnect

        invoke pin_Unconnect

        jmp all_done


    undo_is_mode_CO_UO:
                                    ;// ebx is old output (now connected)
        unredo_UPinToPin [esi], edi ;// edi is new output (now connected)
        ;//xchg ebx, edi
        invoke pin_connect_CO_UO

        jmp all_done


    undo_is_mode_CI_UI_or_CO_CO_or_CI_UOCO:

        ;// UNREDO_CON_CI_UI    EQU 257 ;//                     from input, to input
        ;// UNREDO_CON_CO_CO    EQU 258 ;//                     output output, input list
        ;// UNREDO_CON_CI_UOCO  EQU 259 ;// special mode        from input to output, old output

        cmp edx, UNREDO_CON_CO_CO   ;// 258
        je undo_is_mode_CO_CO
        ja undo_is_mode_CI_UOCO

    undo_is_mode_CI_UI:

        unredo_UPinToPin [esi], edi
        invoke pin_connect_CI_UI
        jmp all_done

    undo_is_mode_CI_UOCO:   ;// is hit from special mode

        ;// ebx = CI
        ;// esi -> out new, out old
        ;// we want to connect CI to out old

        unredo_UPinToPin [esi+SIZEOF UNREDO_PIN], edi ;// get the pin pointer from the second record
        xchg ebx, edi
        invoke pin_connect_CI_UOCO_special  ;// reconnect it
        jmp all_done

    undo_is_mode_CO_CO:

        ;// takes two steps
        ;// 1) unconnect the input pin
        ;// 2) connect input to the old source

        ;// state: esi is at the new output pin
        ;//         ebx is the old output pin

            mov eax, [ecx].num_pin  ;// get the number of pins
            mov edi, ebx    ;// edi will be the new ouput pin
            sub eax, 2      ;// number of input pins

            DEBUG_IF <ZERO? || SIGN?>   ;// its not connected !!

            add esi, SIZEOF UNREDO_PIN  ;// skip the output pin (bug found in 2.15)
            push eax    ;// use stack as a counter

        ;// the first xfer requires special attension

            unredo_UPinToPin [esi], ebx ;// get the input pin
            invoke pin_Unconnect        ;// unconnect it
            invoke pin_connect_UI_UO    ;// reconnect to old output
            dec DWORD PTR [esp]         ;// any pins left ?
            jz co_co_done

            .REPEAT

                add esi, SIZEOF UNREDO_PIN  ;// next record
                unredo_UPinToPin [esi], ebx ;// get the input pin
                invoke pin_Unconnect        ;// unconnect it
                xchg ebx, edi               ;// swap, edi must be input pin
                invoke pin_connect_UI_CO    ;// connect
                dec DWORD PTR [esp]         ;// any records left ?
                xchg ebx, edi               ;// swap back

            .UNTIL ZERO?

        co_co_done:

            pop eax         ;// clean up the counter
            jmp all_done    ;// beat it

    undo_is_input:

        ;// all we have to do is unconnect

        invoke pin_Unconnect

        jmp all_done


    all_done:

        xchg ecx, [esp+4]
        ret 4

unredo_con_undo ENDP
PROLOGUE_ON

ASSUME_AND_ALIGN
PROLOGUE_OFF
unredo_con_redo PROC STDCALL pPinConnect:DWORD

    ;// UNREDO_PIN_CONNECT assumes the pins were connected to create the record
    ;// so we want to do the action again

    ;// destroys edi esi ebx edx eax
    ;// preserves ecx

        xchg ecx, [esp+4]
        ASSUME ecx:PTR UNREDO_PIN_CONNECT

        DEBUG_IF <!![ecx].num_pin>  ;// no pins !! don't call this

    ;// for all of the these, we'll need a pointer to the pin
    ;// and the value of the first pin

        lea esi, [ecx].con          ;// esi will always walk UNREDO_PIN records
        ASSUME esi:PTR UNREDO_PIN

        mov eax, [esi].id
        hashd_Get unredo_id, eax, ebx
        xor edx, edx                ;// clear for future tests
        add ebx, [esi].pin
        ASSUME ebx:PTR APIN         ;// ebx is now the first pin

        add esi, SIZEOF UNREDO_PIN  ;// set esi as second pin

    ;// jump to the correct mode

        or edx, [ecx].mode      ;// load and test the mode
        js redo_is_input

    redo_is_output_or_special:

        jz redo_is_mode_0

        cmp edx, 256
        je redo_is_mode_CO_UO
        ja redo_is_mode_CI_UI_or_CO_CO_or_CI_UOCO


    redo_is_mode_b: ;// edx is bus number

            push ecx            ;// need to save
            push edx            ;// push the bus index
            invoke bus_GetEditRecord    ;// get the edit record
            pop ecx             ;// retrive the edit record
            invoke bus_Create   ;// create the bus
            pop ecx             ;// retrieve the undo node

            mov eax, [ecx].num_pin
            dec eax
            jz all_done

            push eax
            jmp connect_these

    redo_is_mode_0: ;// input list follows

        ;// ebx is the output we are connecting to
        ;// esi is at the first input pin

            mov eax, [ecx].num_pin
            dec eax
            jz all_done

            push eax    ;// use as a counter

        ;// the first pin gets special attention

            unredo_UPinToPin [esi], edi
            invoke pin_connect_UI_UO

            dec DWORD PTR [esp]
            jz mode_0_done

            .REPEAT
                add esi, SIZEOF UNREDO_PIN  ;// next record
            connect_these:                  ;// entrance from mode_b
                unredo_UPinToPin [esi], edi ;// get the input pin
                invoke pin_connect_UI_CO    ;// connect it
                dec DWORD PTR [esp]         ;// anything left ?
            .UNTIL ZERO?

        mode_0_done:

            pop eax
            jmp all_done

    redo_is_mode_CO_UO:

        unredo_UPinToPin [esi], edi
        xchg ebx, edi
        invoke pin_connect_CO_UO
        jmp all_done

    redo_is_mode_CI_UI_or_CO_CO_or_CI_UOCO:

        cmp edx, UNREDO_CON_CO_CO   ;// 258
        je redo_is_mode_CO_CO
        ja redo_is_mode_CI_UOCO

    redo_is_mode_CI_UI:

        unredo_UPinToPin [esi], edi
        xchg ebx, edi
        invoke pin_connect_CI_UI
        jmp all_done

    redo_is_mode_CI_UOCO:   ;// hit for special modes
                            ;// see undo_is_mode_CI_UOCO

        unredo_UPinToPin [esi], edi
        xchg ebx, edi
        invoke pin_connect_CI_UOCO_special
        jmp all_done

    redo_is_mode_CO_CO:

        unredo_UPinToPin [esi], edi
        xchg ebx, edi
        invoke pin_connect_CO_CO

        jmp all_done


    redo_is_input:

        unredo_UPinToPin [esi], edi ;// output pin
        xchg edi, ebx

        ;// edx is still the mode
        inc edx
        jz redo_is_mode_m1

    redo_is_mode_m2:

        ;// from time to time, we'll get pins that are already connected
        ;// this happens when a bus source is created before any pins are attached
        ;// so we check that here

        DEBUG_IF <[edi].pPin>   ;// already connected ?!!
        .IF !([ebx].dwStatus & PIN_BUS_TEST)
            invoke pin_connect_UI_UO
            jmp all_done
        .ENDIF

    redo_is_mode_m1:

        invoke pin_connect_UI_CO
;//     jmp all_done

    all_done:

        xchg ecx, [esp+4]
        ret 4


unredo_con_redo ENDP
PROLOGUE_ON

;//
;//     connect and unconnect helpers
;//
;////////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////////





    ;////////////////////////////////////////////////////////////////////////////////////////////
    ;//
    ;//  CONNECT_PIN        pins connected by mouse dragging
    ;//
    ;////////////////////////////////////////////////////////////////////////////////////////////
    ;//
    ;//  UNCONNECT_PIN      pins unconnected by user action
    ;//

    comment ~ /*

        connect pin relies on the pin_connect functions being able to record their pointers

        BEGIN will set up the iterator
            unredo_pRecording always begins at mode

        pin_connect will record the actions
        END will xlate the pin pointers to osc and id

    */ comment ~

    BEGIN_ACTION_HANDLER    UNREDO_UNCONNECT
    BEGIN_ACTION_HANDLER    UNREDO_CONNECT_PIN

        ;// set up the header
        ;// setup the ConnectRecording flag

        add ecx, OFFSET action_UNREDO_UNCONNECT.num_pin ;// point at the mode
        mov unredo_pRecorder, ecx   ;// set recording pointer to the mode

        ACTION_EXIT


    END_ACTION_HANDLER  UNREDO_UNCONNECT
    END_ACTION_HANDLER  UNREDO_CONNECT_PIN

        ;// translate the ids

            invoke unredo_con_xlate_ids, ADDR [ecx].num_pin

        ;// set the size correctly

            mov eax, unredo_pRecorder
            sub eax, ecx    ;// subtract start of UNREDO action to get the size
            mov (UNREDO_TEMP PTR [ecx]).dwSize, eax ;// store in temp

            mov unredo_pRecorder, 0 ;// reset the ptr

            ACTION_EXIT


    REDO_ACTION_HANDLER UNREDO_UNCONNECT
    UNDO_ACTION_HANDLER UNREDO_CONNECT_PIN

        add ecx, OFFSET action_UNREDO_CONNECT_PIN.num_pin
        push ecx
        ENTER_PLAY_SYNC GUI

        call unredo_con_undo

        jmp unredo_play_sync_done

    UNDO_ACTION_HANDLER UNREDO_UNCONNECT
    REDO_ACTION_HANDLER UNREDO_CONNECT_PIN

        add ecx, OFFSET action_UNREDO_CONNECT_PIN.num_pin
        push ecx
        ENTER_PLAY_SYNC GUI

        call unredo_con_redo

    unredo_play_sync_done:

        or [ebp].pFlags, PFLAG_TRACE        ;// schedule a trace
        ;//or [ebp].gFlags, GFLAG_AUTO_UNITS    ;// tell auto units to get to work
        invoke context_SetAutoTrace     ;//or app_bFlags, APP_SYNC_UNITS

        LEAVE_PLAY_SYNC GUI

        ACTION_EXIT


    ;//
    ;//  CONNECT_PIN        pins connected by mouse dragging
    ;//
    ;////////////////////////////////////////////////////////////////////////////////////////////
    ;//
    ;//  UNCONNECT_PIN      pins unconnected by user action
    ;//
    ;////////////////////////////////////////////////////////////////////////////////////////////





    ;////////////////////////////////////////////////////////////////////////////////////////////
    ;//
    ;//  BUS_COMMANDS       for the BEGIN END, we use esi as the bus pointer
    ;//
    BEGINEND_ACTION_HANDLER UNREDO_BUS_CONVERTTO
    BEGINEND_ACTION_HANDLER UNREDO_BUS_CREATE

            ASSUME ebx:PTR APIN             ;// ebx is the pin
            ASSUME edi:PTR BUS_EDIT_RECORD  ;// edi is the bus edi record

        unredo_bus_beginend:    ;// store pin and bus

            mov edx, [edi].number   ;// get the bus number
            mov [ecx].bus, edx  ;// store bus number in temp record

        unredo_bus_beginend_osc:;// only do the osc

            PIN_TO_OSC ebx, esi ;// get the osc
            unredo_VerifyId     ;// make sure it has an id
            mov [ecx].id, eax   ;// store in temp buffer
            sub ebx, esi        ;// convert pin pointer to offset
            mov [ecx].pin, ebx  ;// store in temp record

            ACTION_EXIT

    UNDO_ACTION_HANDLER     UNREDO_BUS_CREATE

        ;// unconnect the pin

            unredo_UPinToPin [ecx], ebx
            ENTER_PLAY_SYNC GUI
            invoke pin_Unconnect

            jmp unredo_play_sync_done

    REDO_ACTION_HANDLER     UNREDO_BUS_CREATE

        ;// call bus_Create

            unredo_UPinToPin [ecx], ebx
            push [ecx].bus
            invoke bus_GetEditRecord
            pop ecx
            invoke bus_Create

            ACTION_EXIT



    BEGINEND_ACTION_HANDLER UNREDO_BUS_RENAME

        ASSUME ebx:PTR APIN             ;// ebx is the pin
        ASSUME edi:PTR BUS_EDIT_RECORD  ;// edi is the bus edi record

            ;// extract the origonal bus number
            ;// make sure we store the output pin

            mov eax, [ebx].dwStatus     ;// get the pin status
            bt eax, LOG2(PIN_OUTPUT)    ;// check for output
            .IF !CARRY?                 ;// input pin ?
                mov ebx, [ebx].pPin     ;// get the source pin, always an output
                mov eax, [ebx].dwStatus ;// get it's status
            .ENDIF

            and eax, PIN_BUS_TEST       ;// mask out all but the bus number
            DEBUG_IF <ZERO?>            ;// this pin is not a bus !!

            mov [ecx].bus2, eax         ;// store origonal number

            jmp unredo_bus_beginend     ;// jump to common exit to store pin and new bus number



    UNDO_ACTION_HANDLER     UNREDO_BUS_RENAME

        ;// put name back to the origonal

            push [ecx].bus2
            jmp unredo_bus_rename

    REDO_ACTION_HANDLER     UNREDO_BUS_RENAME

        ;// put name back to new

            push [ecx].bus1

        unredo_bus_rename:

            unredo_UPinToPin [ecx], ebx ;// get the output pin
            invoke bus_GetEditRecord    ;// get edit record, arg already pushed
            pop ecx                     ;// retrieve the bus edit record
            invoke bus_Rename

            ACTION_EXIT



    BEGINEND_ACTION_HANDLER UNREDO_BUS_TRANSFER

        ASSUME ebx:PTR APIN             ;// ebx is the pin
        ASSUME edi:PTR BUS_EDIT_RECORD  ;// edi is the bus edi record

            mov eax, [ebx].dwStatus     ;// get the pin status
            DEBUG_IF <eax & PIN_OUTPUT> ;// only supposed to be able to xfer bus inputs

            and eax, PIN_BUS_TEST       ;// mask out all but the bus number
            DEBUG_IF <ZERO?>            ;// this pin is not a bus !!

            mov [ecx].bus2, eax         ;// store origonal number

            jmp unredo_bus_beginend     ;// jump to common exit to store pin and new bus number

    UNDO_ACTION_HANDLER     UNREDO_BUS_TRANSFER

        ;// transfer back to bus2

            push [ecx].bus2
            jmp unredo_bus_transfer

    REDO_ACTION_HANDLER     UNREDO_BUS_TRANSFER

        ;// transfer back to bus1

            push [ecx].bus1

        unredo_bus_transfer:

            unredo_UPinToPin [ecx], ebx ;// get the output pin
            invoke bus_GetEditRecord    ;// get edit record, arg already pushed
            pop ecx                     ;// retrieve the bus edit record
            invoke bus_Transfer

            ACTION_EXIT


    REDO_ACTION_HANDLER     UNREDO_BUS_DIRECT
    UNDO_ACTION_HANDLER     UNREDO_BUS_CONVERTTO

        ;// call direct connect
        unredo_UPinToPin [ecx], ebx ;// get the output pin
        invoke bus_Direct

        ACTION_EXIT

    UNDO_ACTION_HANDLER     UNREDO_BUS_DIRECT
    REDO_ACTION_HANDLER     UNREDO_BUS_CONVERTTO

        ;// call convert to

            push [ecx].bus
            unredo_UPinToPin [ecx], ebx ;// get the output pin
            invoke bus_GetEditRecord    ;// get edit record, arg already pushed
            pop ecx                     ;// retrieve the bus edit record
            invoke bus_ConvertTo

            ACTION_EXIT


    BEGINEND_ACTION_HANDLER UNREDO_BUS_DIRECT

        ASSUME ebx:PTR APIN             ;// ebx is the pin
        ASSUME edi:PTR BUS_EDIT_RECORD  ;// edi is the bus edi record

        mov eax, [ebx].dwStatus
        bt eax, LOG2(PIN_OUTPUT)
        .IF !CARRY?
            mov ebx, [ebx].pPin
            mov eax, [ebx].dwStatus
        .ENDIF

        and eax, PIN_BUS_TEST
        mov [ecx].bus, eax

        jmp unredo_bus_beginend_osc ;// jump to common exit to store the pin


    BEGIN_ACTION_HANDLER    UNREDO_BUS_PULL

        ASSUME ebx:PTR APIN             ;// ebx is the pin
        ASSUME edi:PTR BUS_EDIT_RECORD  ;// edi is the bus edi record

        ;// store all the before and after pheta values
        ;// we do this by setting up unredu_pRecordingPin

        lea eax, [ecx].pin1
        mov [ecx].num_pins, 0
        mov unredo_pRecorder, eax

        ACTION_EXIT

    END_ACTION_HANDLER      UNREDO_BUS_PULL

        ;// now we convert all the pin to osc.index and set the size and pin count

        ASSUME edi:PTR UNREDO_PHETA     ;// edi is the bus record to process
        ASSUME ebx:PTR APIN             ;// ebx is a pin
        ASSUME esi:PTR OSC_OBJECT       ;// esi is an osc

        lea edi, [ecx].pin1
        .WHILE edi < unredo_pRecorder

            mov esi, [edi].id   ;// get the osc (currently an osc_object ptr)
            mov ebx, [edi].pin  ;// get the pin ptr
            unredo_VerifyId     ;// make sure it has an id
            mov [edi].id, eax   ;// store the id
            sub ebx, esi        ;// convert pin ptr to an offset
            inc [ecx].num_pins  ;// bump the number of pins
            mov [edi].pin, ebx  ;// store the pin offset

            add edi, SIZEOF UNREDO_PHETA

        .ENDW

        sub edi, ecx                            ;// turn iterator into a size
        mov (UNREDO_TEMP PTR [ecx]).dwSize, edi ;// store in temp record
        mov unredo_pRecorder, 0                 ;// reset the pointer

        ACTION_EXIT


    UNDO_ACTION_HANDLER     UNREDO_BUS_PULL

        ;// set pheta as unredo.x for all pins

        mov esi, [ecx].num_pins
        lea edi, [ecx].pin1
        .WHILE esi

            unredo_UPinToPin [edi], ebx
            mov eax, [edi].x
            dec esi
            mov [ebx].pheta, eax
            GDI_INVALIDATE_PIN HINTI_PIN_PHETA_CHANGED
            add edi, SIZEOF UNREDO_PHETA

        .ENDW

        ACTION_EXIT

    REDO_ACTION_HANDLER     UNREDO_BUS_PULL

        ;// set pheta as unredo.y for all pins

        mov esi, [ecx].num_pins
        lea edi, [ecx].pin1
        .WHILE esi

            unredo_UPinToPin [edi], ebx
            mov eax, [edi].y
            dec esi
            mov [ebx].pheta, eax
            GDI_INVALIDATE_PIN HINTI_PIN_PHETA_CHANGED
            add edi, SIZEOF UNREDO_PHETA

        .ENDW

        ACTION_EXIT


    ;//
    ;//  BUS_COMMANDS       for the BEGIN END, we use esi as the bus pointer
    ;//
    ;////////////////////////////////////////////////////////////////////////////////////////////


    ;////////////////////////////////////////////////////////////////////////////////////////////
    ;//
    ;//  BUS NAME COMMANDS          have the added task of updating bus_table_is_dirty
    ;//                             this must be done AFTER the handler is executed
    ;//                             otherwise bus_GetEditRecord may screw up the sequence

    ;// CATCAT //////////////////////////////////////////////////////

    BEGIN_ACTION_HANDLER    UNREDO_BUS_CATDEL
    BEGIN_ACTION_HANDLER    UNREDO_BUS_CATCAT

        ;// catmem_CatCat will record   cat1, cat2, old name, member list
        ;// set pRecording

        lea eax, [ecx].cat1         ;// where to record
        mov unredo_pRecorder, eax   ;// set the pointer

        ACTION_EXIT

    END_ACTION_HANDLER      UNREDO_BUS_CATDEL
    END_ACTION_HANDLER      UNREDO_BUS_CATCAT

        ;// set the number of members
        ;// set the size of the record
        ;// reset recording

        mov ebx, unredo_pRecorder   ;// get the recording pointer
        lea eax, [ecx].member       ;// point at the first member
        sub eax, ebx                ;// - offset
        neg eax                     ;// + offset
        sub ebx, ecx                ;// convert recording to a size
        shr eax, 2                  ;// conver offset to a count
        mov (UNREDO_TEMP PTR [ecx]).dwSize, ebx ;// store the size
        mov [ecx].num_members, eax  ;// store the count

        mov unredo_pRecorder, 0     ;// reset recording pointer

        inc bus_table_is_dirty

        ACTION_EXIT

    UNDO_ACTION_HANDLER     UNREDO_BUS_CATDEL
    UNDO_ACTION_HANDLER     UNREDO_BUS_CATCAT

        ;// create cat2
        ;// assign name
        ;// move members to cat2

        mov ebx, ecx
        ASSUME ebx:PTR action_UNREDO_BUS_CATCAT

        mov edi, [ebx].num_members  ;// get the number of members
        lea esi, [ebx].member       ;// point at first member

        lea eax, [ebx].cat_name
        push eax                    ;// push the name pointer
        push [ebx].cat2             ;// push the old cat number
        invoke bus_GetEditRecord    ;// convert it in place to an edit record
        mov ebx, [esp]              ;// retrieve the value in ebx
        call catmem_AddCat          ;// call the add cat function

        ;// state
        ;//
        ;//     ebx is category ptr to move to
        ;//     esi points at first member index
        ;//     edi holds the count

        .WHILE edi

            dec edi
            lodsd       ;// get the member index
            push ebx    ;// push the cat parameter
            push eax    ;// push the member index
            invoke bus_GetEditRecord    ;// convert in place to an edit record
            call catmem_MemCat  ;// move it

        .ENDW

        dec bus_table_is_dirty

        ACTION_EXIT

    REDO_ACTION_HANDLER     UNREDO_BUS_CATCAT

        ;// move cat2 to cat1

        push [ecx].cat1             ;// destination
        invoke bus_GetEditRecord    ;// convert in place
        push [ecx].cat2             ;// source
        invoke bus_GetEditRecord    ;// convert in place

        call catmem_CatCat  ;// move the whole thing

        inc bus_table_is_dirty

        ACTION_EXIT

    ;// CATDEL //////////////////////////////////////////////////////

        ;// begin, end and undo are the same as CATCAT

    REDO_ACTION_HANDLER     UNREDO_BUS_CATDEL


        push [ecx].cat
        invoke bus_GetEditRecord
        call catmem_DelCat

        inc bus_table_is_dirty

        ACTION_EXIT

    ;// MEMCAT //////////////////////////////////////////////////////


        ;// catmem_MemCat will store cat1, cat2 and member


    UNDO_ACTION_HANDLER     UNREDO_BUS_MEMCAT

        ;// move member to cat2

            push [ecx].cat2
            invoke bus_GetEditRecord
            push [ecx].member
            invoke bus_GetEditRecord

            call catmem_MemCat

            dec bus_table_is_dirty

            ACTION_EXIT

    REDO_ACTION_HANDLER     UNREDO_BUS_MEMCAT

        ;// move member to cat1

            push [ecx].cat1
            invoke bus_GetEditRecord
            push [ecx].member
            invoke bus_GetEditRecord

            call catmem_MemCat

            inc bus_table_is_dirty

            ACTION_EXIT



    ;// CATINS //////////////////////////////////////////////////////

    BEGIN_ACTION_HANDLER    UNREDO_BUS_MEMCAT
    BEGIN_ACTION_HANDLER    UNREDO_BUS_MEMNAME
    BEGIN_ACTION_HANDLER    UNREDO_BUS_CATNAME
    BEGIN_ACTION_HANDLER    UNREDO_BUS_CATINS

        ;// catmem_AddCat will store the cat that was inserted
        ;// edit_wm_loosefocus will store the name
        ;// set pRecording

        lea eax, [ecx].cat
        mov unredo_pRecorder, eax

        ACTION_EXIT

    END_ACTION_HANDLER      UNREDO_BUS_MEMCAT
    END_ACTION_HANDLER      UNREDO_BUS_MEMNAME
    END_ACTION_HANDLER      UNREDO_BUS_CATNAME
    END_ACTION_HANDLER      UNREDO_BUS_CATINS

        mov unredo_pRecorder, 0     ;// reset pRecording
        inc bus_table_is_dirty

        ACTION_EXIT

    UNDO_ACTION_HANDLER     UNREDO_BUS_CATINS

        push [ecx].cat  ;// delete cat
        invoke bus_GetEditRecord
        call catmem_DelCat

        dec bus_table_is_dirty

        ACTION_EXIT

    REDO_ACTION_HANDLER     UNREDO_BUS_CATINS

        ;// insert cat
        ;// set name

        lea eax, [ecx].cat_name
        push eax
        push [ecx].cat
        invoke bus_GetEditRecord
        call catmem_AddCat

        inc bus_table_is_dirty

        ACTION_EXIT




    ;// CATNAME //////////////////////////////////////////////////////


        ;// catmem_EditName will store cat and old name1
        ;// edit_wm_killfocus_proc will store name2 and call action end

        ;// begin and end are covered under CATINS

    UNDO_ACTION_HANDLER     UNREDO_BUS_CATNAME

        ;// set cat name as name1

            lea eax, [ecx].name1    ;// point at old name
            push eax    ;// store the name pointer
            push [ecx].cat
            invoke bus_GetEditRecord

            call catmem_SetCatName

            dec bus_table_is_dirty

            ACTION_EXIT

    REDO_ACTION_HANDLER     UNREDO_BUS_CATNAME

        ;// set cat name as name 2

            lea eax, [ecx].name2

            push eax    ;// store the name pointer
            push [ecx].cat
            invoke bus_GetEditRecord
            call catmem_SetCatName

            inc bus_table_is_dirty

            ACTION_EXIT


    ;// MEMNAME //////////////////////////////////////////////////////


        ;// catmem_EditName will store mem and old name1
        ;// edit_wm_killfocus_proc will store name2 and call action end

        ;// begin and end are covered under CATINS

    UNDO_ACTION_HANDLER     UNREDO_BUS_MEMNAME

        ;// set mem name as name1

            lea eax, [ecx].name1
            push eax
            push [ecx].member
            invoke bus_GetEditRecord
            call catmem_SetMemName

            dec bus_table_is_dirty

            ACTION_EXIT

    REDO_ACTION_HANDLER     UNREDO_BUS_MEMNAME

        ;// set mem name as name2

            lea eax, [ecx].name2
            push eax
            push [ecx].member
            invoke bus_GetEditRecord
            call catmem_SetMemName

            inc bus_table_is_dirty

            ACTION_EXIT



    ;//
    ;//  BUS NAME COMMANDS
    ;//
    ;////////////////////////////////////////////////////////////////////////////////////////////

    ;////////////////////////////////////////////////////////////////////////////////////////////
    ;//
    ;//  OSC  INSERT DELETE
    ;//

    comment ~ /*

        these are complicated
        the safest route is to use already existing file load and save operations

        we'll need to create three tables

            CONNECT_TABLE   list of connection for the oscs in question
            FILE_HEADER     the usual storage of oscs
            ID_TABLE        ordered array of id's for each osc in file, and it's lock item

        to delete oscs

            1) unconnect all connections, record them
            2) save the state of each osc, just like a copy operation

        to undo delete oscs

            2) create all the oscs, update their hashd_id value
            1) connect all the connections

        to redo delete osc

            2) delete each osc using the id table

        id_table        after osc are created, we need to assign their id's
        connect table   deleting oscs requires that we unconnect first
        file_osc_table  should operate exactly like a FILE_HEADER and FILE_OSC

        data implementation:

            the UNREDO record will have three sections:

            dwOfsConnectTable   ;// offset to connect table
            dwOfsFileHeader     ;// offset to the file header

            1) ID_TABLE     ordered array of id values

            2) CONNECT_TABLE

                when undoing, we have to scan this backwards

            3) FILE_HEADER
                FILE_OSC
                FILE_PIN        use a NO_PINS flags to save time

                an ID table must be assigned to each context !!
                otherwise we cannot redo subsequent actions
                this should be implemented as a new ID, like lock table and bus table

        procedure sequence:

            DEL and CUT are similar
            with the diference that we can use the copy buffer for part 3

            unredo_BeginAction UNREDO_DEL_OSC

                1) set up unredo_temp

                    count objects to be deleted
                    check for and remove pin_interface while inside closed groups
                    accumulate their save size
                    accumulate their connection size

                    make sure unredo_temp is big enough

                2) store the ID table

                    assign ID's
                    store id's in unredo_temp
                    if object is locked, store that id

                3) call context_SaveSelected with pRecording

                    context_SaveSelected will save all the objects

                        must be able to save a private ID table for the group

                    store offset to connect table

                4) return

            context_Delete

                scans the sel list and calls osc_Dtor

                osc_Dtor

                    scans pins on the osc
                    calls pin_Unconnect for each
                        pin_Unconnect detects pRecording and stores the connection data
                    osc_Dtor must set the size of the block before calling the next pin_Unconnect

            unredo_EndAction UNREDO_DEL_OSC

                now has a complete list

                the total size must be set

                then exit to the usuall transfer of unredo_temp to unredo_table

        UNDO DELETE OSC

            recreate all the objects
            re connect all the objects, in reverse order!!

            store many many pointers on the stack
            then pop them off and do the actions

        REDO DELETE OSC

            should be able to simply call the normal destructor for each id in the table

    */ comment ~





    BEGIN_ACTION_HANDLER    UNREDO_DEL_OSC

        ;// ecx = unredo temp
        ;// assume the sel list is correct
        ;// assume that ebp is NOT the current context

            push ebp
            xor eax, eax
            stack_Peek gui_context, ebp

        ;//1) set up unredo_temp
        ;//
        ;// count objects to be deleted
        ;// check for and remove pin_interface while inside closed groups
        ;// accumulate their save size
        ;// accumulate their connection size

        ;// make sure unredo_temp is big enough

            mov [ecx].id_count, eax
            mov [ecx].file_ofs, SIZEOF FILE_HEADER
            mov [ecx].con_ofs, eax

            clist_GetMRS oscS,esi,[ebp]
            DEBUG_IF <!!esi>    ;// nothing is selected !
            push esi            ;// save a a stop pointer
                                ;// this will remain on the stack until step 4
            inc unredo_delete   ;// turn on the flag

            .REPEAT

                OSC_TO_BASE esi, edi        ;// load the base class

                DEBUG_IF < edi == OFFSET osc_PinInterface && app_bFlags & APP_MODE_IN_GROUP && [esi].dwHintOsc & HINTOSC_STATE_HAS_GROUP >
                ;// not supposed to delete this, should have called context_Delete_prescan

                inc [ecx].id_count                  ;// update the id count

                .IF [edi].gui.AddExtraSize          ;// class defined WSize ?
                    lea ebx, [ecx].file_ofs         ;// need to point at file size
                    push ecx
                    invoke [edi].gui.AddExtraSize   ;// call it
                    pop ecx
                .ELSE                               ;// otherwise
                    mov eax, [edi].data.numFileBytes;// get the predetermined size
                    add [ecx].file_ofs, eax             ;// add to running total
                .ENDIF

                mov eax, [edi].data.numPins         ;// get the number of the pins
                lea eax, [eax+eax*2]                ;// times 3
                lea eax, [eax*4+SIZEOF FILE_OSC]    ;// times 4 = size of the pin table
                                                    ;// then add the size of the osc file record
                add [ecx].file_ofs, eax                 ;// add it to the running total

                ITERATE_PINS                        ;// scan all the pins

                    invoke unredo_con_get_size, ebx ;// get the connect size
                                                    ;// (may be larger than actually needed)
                    add [ecx].con_ofs, eax          ;// add to id table size

                PINS_ITERATE

                clist_GetNext oscS, esi             ;// get the next selected osc

            .UNTIL esi == [esp]                     ;// stop when we get back to MRS

        ;// now we have counts and may determine the required size of the table
        ;// at the same time, we may set the offsets

            ;// file    = sizeof UNREDO_DEL_OSC + id_count * 4
            ;// connect = sizeof UNREDO_DEL_OSC + id_count * 4 + file_size
            ;// total   = sizeof UNREDO_DEL_OSC + id_count * 4 + file_size + connect_size

            mov eax, [ecx].id_count ;// get the count
            mov ebx, [ecx].file_ofs ;// need to store the file size
            mov edx, [ecx].con_ofs

            .ERRNZ ((SIZEOF UNREDO_OSC_ID) - 8), <code requires an 8 byte struct>

            lea eax, [eax*8 + SIZEOF action_UNREDO_DEL_OSC];// = file offset
            mov [ecx].file_ofs, eax
            add eax, ebx            ;// = connect offset
            mov [ecx].con_ofs, eax
            add eax, edx            ;// = total size

            .IF eax > MEMORY_SIZE(ecx)  ;// verify the size

                add eax, 3          ;// must dword align
                and eax, -4
                invoke memory_Expand, ecx, eax  ;// resize and copy
                mov ecx, eax            ;// set as new temp pointer
                mov unredo_temp, eax    ;// store as new unredo_temp

            .ENDIF

        ;// 2) store the ID table       esi is at oscS MRS
        ;//                             MRS is also on teh stack
        ;// assign ID's
        ;// store id's in unredo_temp
        ;// if locked, store those too

            lea edi, [ecx+SIZEOF action_UNREDO_DEL_OSC] ;// point at the id table

            .REPEAT

                unredo_VerifyId ;// verify and or create the id
                stosd           ;// store and advance the iterater

                mov eax, clist_Next(oscL,esi)   ;// locked ?
                .IF eax
                    push esi        ;// store or die
                    mov esi, eax    ;// set osc as eax
                    unredo_VerifyId ;// make sure it has id
                    pop esi         ;// retrieve osc
                .ENDIF
                stosd               ;// store lock id or zero

                clist_GetNext oscS, esi ;// get next

            .UNTIL esi == [esp]

        ;// 3) save all the selected objects
        ;//     there's no sense to writting a context function to do this
        ;//     it would just get in the way
        ;// esi still equal MRS
        ;// MRS is still on the stack
        ;// edi is not at the file header

            ;// set up the file header

                ASSUME edi:PTR FILE_HEADER
                mov [edi].header, 'xoBA'
                mov eax, [ecx].id_count     ;// get the osc count
                add ebx, edi                ;// add current pointer to size = pEOB
                mov [edi].numOsc, eax       ;// retrieve the number of oscs

                dec context_bCopy           ;// set context_bCopy so closed groups save correctly
                DEBUG_IF <!!SIGN?>

                add edi, SIZEOF FILE_HEADER ;// define the file iterator

            ;// scan through the sellist and call the write function
            ;// esi still equal MRS
            ;// MRS is still on the stack

                .REPEAT
                    invoke osc_Write
                    clist_GetNext oscS, esi
                .UNTIL esi == [esp]

                pop esi                     ;// clean up the stack

                inc context_bCopy           ;// clear this for future use
                DEBUG_IF <!!ZERO?>

                dec unredo_delete   ;// turn off the flag


        ;// 4) set precording, retrieve ebp and return

            mov unredo_pRecorder, edi

            pop ebp
            ACTION_EXIT


    END_ACTION_HANDLER      UNREDO_DEL_OSC

        ;// now, all the pins have been unconnected,
        ;// all we have to do is determine the actual final size

            xor eax, eax
            mov edi, unredo_pRecorder   ;// get end of connection list
            stosd                       ;// terminate the list
            mov unredo_pRecorder, eax   ;// reset pRecording
            sub edi, ecx    ;// = total size
            add edi, 3
            and edi, -4
            mov (UNREDO_TEMP PTR [ecx]).dwSize, edi

            ACTION_EXIT


    UNDO_ACTION_HANDLER     UNREDO_DEL_OSC

        ;// create the oscs, assign id's, update the pointer values


        ;// set up the file header

            mov eax, [ecx].file_ofs ;// get the file pointer
            mov edx, [ecx].con_ofs  ;// point at connect table
            add eax, ecx            ;// eax points at file header
            add edx, ecx            ;// edx points at pEOB
            mov (FILE_HEADER PTR [eax]).pEOB, edx   ;// store pEob

        ;// point at the id list and create

            lea edx, [ecx+SIZEOF action_UNREDO_DEL_OSC] ;// point at id table
            push ecx    ;// save for safe keeping

            invoke context_Paste, eax, edx, 1   ;// use ids, yes select

        ;// scan the id list and check for locked objects

            mov ecx, [esp]
            mov edi, [ecx].id_count
            xor eax, eax
            lea esi, [ecx+SIZEOF action_UNREDO_DEL_OSC]
            ASSUME esi:PTR UNREDO_OSC_ID

        top_of_lock_loop:

            or eax, [esi].lock_id
            jnz got_lock
            add esi, SIZEOF UNREDO_OSC_ID
            dec edi
            jnz top_of_lock_loop
            jmp done_with_lock

        got_lock:

            hashd_Get unredo_id, eax, ebx
            mov eax, [esi].id
            hashd_Get unredo_id, eax, ecx

            DEBUG_IF <ebx == ecx>

            clist_Insert oscL, ecx, ebx, [ebp]

            add esi, SIZEOF UNREDO_OSC_ID
            xor eax, eax
            dec edi
            jnz top_of_lock_loop

        done_with_lock:
        ASSUME ecx:PTR action_UNREDO_DEL_OSC

        ;// connect the oscs in reverse list oreder
        ;// push all the UNREDO_PIN_UNCON pointers on the stack
        ;// pay attention, we'll use STDCALL to pop args off the stack

            pop ecx                 ;// retrieve the action pointer
            mov esi, esp            ;// save the top of the stack

            add ecx, [ecx].con_ofs  ;// scoot to the connect table
            ASSUME ecx:PTR UNREDO_PIN_CONNECT

        @@: mov eax, [ecx].num_pin  ;// get num pins from UNREDO_PIN_UNCON
            or eax, eax             ;// check if there were any
            jz @F                   ;// if not, ready to connect
            push ecx                ;// push the arg for connect this
            .ERRNZ ((SIZEOF UNREDO_PIN)-8), <code requires 8 byte struct>
            lea ecx, [ecx+eax*8].con;// iterate size(pin)*num_pin + size(header)
            jmp @B                  ;// next UNREDO_PIN_UNCON record

        ;// ready to connect ?
        @@: cmp esi, esp            ;// check for empty list
            jne @F
            ACTION_EXIT

        @@: ENTER_PLAY_SYNC GUI     ;// connect functions need play sync
            mov ecx, esi            ;// esi will be destroyed, so ecx will be the done pointer
        ;// reconnect loop
        @@: call unredo_con_redo    ;// connect the pins
            cmp ecx, esp            ;// see if we're done
            ja @B                   ;// next UNREDO_PIN_CONNECT record

            jmp unredo_play_sync_done

        ;// done



    REDO_ACTION_HANDLER     UNREDO_DEL_OSC

        ;// delete the osc's in the id table

            push ecx
            ENTER_PLAY_SYNC GUI     ;// connect functions need play sync
            pop ecx

            lea edi, [ecx+SIZEOF action_UNREDO_DEL_OSC] ;// point at id table
            ASSUME edi:PTR UNREDO_OSC_ID
            mov ebx, [ecx].id_count ;// getthe count
            DEBUG_IF <!!ebx>    ;// nothing was deleted !!

            .REPEAT
                mov eax, [edi].id   ;// get the id
                hashd_Get unredo_id, eax, esi
                add edi, SIZEOF UNREDO_OSC_ID
                invoke osc_Dtor
                dec ebx
            .UNTIL ZERO?

            jmp unredo_play_sync_done

    ;/// NEW OSC ///////////////////////////////////////////////////////////////////////

    BEGIN_ACTION_HANDLER    UNREDO_NEW_OSC

        ;// this is called after the osc is created
        ;// but before it has been put down
        ;// osc_down is the osc in question

        GET_OSC_FROM esi, osc_down
        unredo_VerifyId
        mov [ecx].osc_id, eax
        OSC_TO_BASE esi, esi
        mov eax, [esi].data.ID
        mov [ecx].base_id, eax

        ACTION_EXIT

    END_ACTION_HANDLER      UNREDO_NEW_OSC

        ;// now that the osc has been put down
        ;// we have to store it's position

        mov eax, [ecx].osc_id
        hashd_Get unredo_id, eax, esi
        point_GetTL [esi].rect
        point_Set [ecx].pos

        ACTION_EXIT

    UNDO_ACTION_HANDLER     UNREDO_NEW_OSC

        mov eax, [ecx].osc_id
        hashd_Get unredo_id, eax, esi
        ENTER_PLAY_SYNC GUI
        invoke osc_Dtor
        jmp unredo_play_sync_done

    REDO_ACTION_HANDLER     UNREDO_NEW_OSC

        ;// recreate the osc at the desired coordinates

        mov eax, [ecx].base_id
        lea edx, [ecx].pos
        invoke app_CreateOsc, edx, [ecx].osc_id
        invoke InvalidateRect, hMainWnd, 0,1

        ACTION_EXIT

    ;/// PASTE AND CLONE //////////////////////////////////////////////////////////////////////////

    comment ~ /*

    implied tables after the action_STRUCT

        ID_TABLE
        CONNECT_TABLE
        FILE_HEADER

    sequence outline

        BEGIN

            guess that the size reuired is 3 times the size of file_pCopyBuffer

                this is safe, because all connections inside the block
                will be 1 or two pin connections

            set pRecorder, which will be the ID table

        osc_CTor via file_RealizeBuffer will record the IDs of each created object

        pin_connect_xx via file_ConnectPins will reord the connect table

        mouse_up will trigger the end of the action

        END

            1) determine the size of the id table by looking at file_pCopyBuffer
            2) determine teh size of the connect table by looking at pRecorder
            3) copy the now processed file_pCopyBuffer to the temp buffer
            4) scan the file buffer and id table in tandem
                xfer the positions from actual object to file block
                set the lock status from actual object to id table

            5) done

    */ comment ~

    BEGIN_ACTION_HANDLER    UNREDO_CLONE_OSC
    BEGIN_ACTION_HANDLER    UNREDO_PASTE

            DEBUG_IF <!!file_bValidCopy>

        ;// guess at the size of the buffer and reallocate if nessesary

            mov esi, file_pCopyBuffer   ;// start of copy buffer
            ASSUME esi:PTR FILE_HEADER
            mov ebx, [esi].pEOB         ;// get stated eob
            sub ebx, esi                ;// ebx is now copy buffer size
            lea eax, [ebx*2+ebx]        ;// allocate three times the size

            add eax, 3
            and eax, -4

            .IF eax > MEMORY_SIZE(ecx)

                invoke memory_Expand, ecx, eax
                mov unredo_temp, eax
                mov ecx, eax

            .ENDIF

        ;// set pRecording as the end of the stored copy buffer
        ;// then set file in the action header

            lea edi, [ecx+SIZEOF action_UNREDO_PASTE]
            mov unredo_pRecorder, edi

        ;// done

            ACTION_EXIT


    END_ACTION_HANDLER      UNREDO_CLONE_OSC
    END_ACTION_HANDLER      UNREDO_PASTE

        ;// 1) terminate the connect_table

            mov edi, unredo_pRecorder
            xor eax, eax
            stosd

        ;// 2) determine the sizes of the id con and table

            ;// id_size = file_pCopyBuffer->num_osc * 8
            ;// con_size = edi - ( unredo_temp + sizeof() + id_size )
            ;// file_size = esi->pEob - esi

            mov esi, file_pCopyBuffer
            ASSUME esi:PTR FILE_HEADER

            mov eax, [esi].numOsc
            mov [ecx].id_count, eax

            lea eax, [ecx+eax*8+SIZEOF( action_UNREDO_PASTE )]
            sub eax,edi
            neg eax
            DEBUG_IF < ZERO? || SIGN? >
            mov [ecx].con_size, eax

            mov eax, [esi].pEOB
            sub eax, esi
            mov [ecx].file_size, eax

        ;// 3) copy the now processed file_pCopyBuffer to the temp buffer

            mov ebx, edi    ;// save start of file block for part 4
            push ecx        ;// save the unredo pointer
            mov ecx, eax
            shr ecx, 2
            rep movsd
            and eax, 3
            jz @F
            mov ecx, eax
            rep movsb
        @@: pop ecx

        ;// 4) scan the file buffer and id table in tandem
        ;//     xfer the positions from actual object to file block
        ;//     set the lock status from actual object to id table

            ASSUME ebx:PTR FILE_HEADER
            push edi    ;// save as end of scan value

            lea edi, [ecx+SIZEOF action_UNREDO_PASTE]
            ASSUME edi:PTR UNREDO_OSC_ID

            FILE_HEADER_TO_FIRST_OSC ebx

            .REPEAT

                mov eax, [edi].id       ;// get id from ID TABLE
                .IF eax                 ;// skip bad objects

                    hashd_Get unredo_id, eax, esi   ;// lookup the osc

                    point_GetTL [esi].rect          ;// xfer the position
                    point_Set [ebx].pos
                    xor eax, eax

                .ENDIF

                mov [edi].lock_id, eax  ;// store zero

                FILE_OSC_TO_NEXT_OSC ebx        ;// iterate
                add edi, SIZEOF UNREDO_OSC_ID

            .UNTIL ebx >= [esp]

        ;// 5) set the total size of the record

            pop ebx
            sub ebx, ecx
            add ebx, 3
            and ebx, -4
            ;//DEBUG_IF <ebx & 3>   ;// supposed to be dword aligned !!
            mov (UNREDO_TEMP PTR [ecx]).dwSize, ebx

        ;// 6) convert connections to osc.pin

            mov eax, [ecx].id_count
            lea ecx, [ecx+eax*8+SIZEOF action_UNREDO_PASTE]
            ASSUME ecx:PTR UNREDO_PIN_CONNECT

            .WHILE [ecx].num_pin

                invoke  unredo_con_xlate_ids, ecx
                mov ecx, ebx

            .ENDW

        ;// 7) turn off popup_no_undo

            mov popup_no_undo, 0

        ;// 8) done

            ACTION_EXIT


    UNDO_ACTION_HANDLER     UNREDO_CLONE_OSC
    UNDO_ACTION_HANDLER     UNREDO_PASTE

        ;// delete all id's

        lea ebx, [ecx+SIZEOF action_UNREDO_PASTE]
        ASSUME ebx:PTR UNREDO_OSC_ID

        push [ecx].id_count

        ENTER_PLAY_SYNC GUI

        .REPEAT

            mov eax, [ebx].id
            .IF eax     ;// skip bad objects
                hashd_Get unredo_id, eax, esi
                invoke osc_Dtor
            .ENDIF

            add ebx, SIZEOF UNREDO_OSC_ID

            dec DWORD PTR [esp]

        .UNTIL ZERO?

        pop eax

        jmp unredo_play_sync_done

    REDO_ACTION_HANDLER     UNREDO_CLONE_OSC
    REDO_ACTION_HANDLER     UNREDO_PASTE

        ;// recreate all the oscs by calling file_RealizeBuffer

        ;// point at id table and file block, set the pEOB

            mov eax, [ecx].id_count
            lea edi, [ecx+SIZEOF action_UNREDO_PASTE]
            ASSUME edi:PTR UNREDO_OSC_ID

            mov edx, [ecx].file_size
            .ERRNZ ((SIZEOF UNREDO_OSC_ID) - 8 ), <code requires 8 byte struct>
            lea ebx, [edi+eax*8]
            add ebx, [ecx].con_size
            ASSUME ebx:PTR FILE_HEADER
            add edx, ebx
            mov [ebx].pEOB, edx

        ;// paste the buffer

            push ecx            ;// save for later

            invoke context_UnselectAll

            ENTER_PLAY_SYNC GUI

            invoke file_RealizeBuffer, ebx, edi, 1

            pop ecx

        ;// may need to relock objects
        ;// but this shouldn't be nessesary

        ;// reconnect all the oscs

            mov ecx, [ecx].id_count
            .ERRNZ ((SIZEOF UNREDO_PIN)-8), <code requires 8 byte struct>
            lea ecx, [ecx*8+edi]
            ASSUME ecx:PTR UNREDO_PIN_CONNECT

        redo_paste_top:

            cmp [ecx].num_pin, 0
            je unredo_play_sync_done

            invoke unredo_con_redo, ecx

            mov eax, [ecx].num_pin
            lea ecx, [ecx+eax*8+8]
            jmp redo_paste_top


    ;//
    ;//  OSC  INSERT DELETE
    ;//
    ;////////////////////////////////////////////////////////////////////////////////////////////


    ;////////////////////////////////////////////////////////////////////////////////////////////
    ;//
    ;//  OSC  COMMANDS
    ;//


    ;/// LOCK UNLOCK ///////////////////////////////////////////////////////////////////////////

    BEGINEND_ACTION_HANDLER UNREDO_UNLOCK_OSC
    BEGINEND_ACTION_HANDLER UNREDO_LOCK_OSC

        ;// lock simply needs to store a list of selected items

            push ebp
            stack_Peek gui_context, ebp

        ;// step 1 is to verify the size of the temp buffer

            clist_GetMRS oscS, esi, [ebp]
            push esi

            mov [ecx].osc_count, 0

            .REPEAT

                inc [ecx].osc_count
                clist_GetNext oscS, esi

            .UNTIL esi == [esp]

            mov eax, [ecx].osc_count
            lea eax, [eax*4+SIZEOF action_UNREDO_LOCK_OSC]

            .IF eax > MEMORY_SIZE(ecx)

                invoke memory_Expand, ecx, eax
                mov unredo_temp, eax
                mov ecx, eax

            .ENDIF

        ;// step 2 is to add the sel list to the temp buffer

            ;// esi already equals sel MRS, as does [esp]

            lea edi, [ecx].osc_id

            .REPEAT

                unredo_VerifyId
                clist_GetNext oscS, esi
                stosd

            .UNTIL esi == [esp]

            pop esi ;// clean up the stack
            pop ebp ;// retrieve ebp

        ;// then set the size of the struct

            sub edi, ecx
            mov (UNREDO_TEMP PTR [ecx]).dwSize, edi

        ;// that's it

            ACTION_EXIT

    REDO_ACTION_HANDLER     UNREDO_UNLOCK_OSC
    UNDO_ACTION_HANDLER     UNREDO_LOCK_OSC

        ;// select the items, the call unlock

            invoke context_UnselectAll

            mov ebx, [ecx].osc_count
            lea edi, [ecx].osc_id
            ASSUME edi:PTR DWORD

            .REPEAT

                mov eax, [edi]
                hashd_Get unredo_id, eax, esi

                clist_Insert oscS, esi,, [ebp]
                GDI_INVALIDATE_OSC HINTI_OSC_GOT_SELECT

                add edi, 4
                dec ebx

            .UNTIL ZERO?

            invoke locktable_Unlock

        ;// that's it

            ACTION_EXIT


    UNDO_ACTION_HANDLER     UNREDO_UNLOCK_OSC
    REDO_ACTION_HANDLER     UNREDO_LOCK_OSC

        ;// select the items, the call lock

            invoke context_UnselectAll

            mov ebx, [ecx].osc_count
            lea edi, [ecx].osc_id
            ASSUME edi:PTR DWORD

            .REPEAT

                mov eax, [edi]
                hashd_Get unredo_id, eax, esi

                clist_Insert oscS, esi,, [ebp]

                add edi, 4
                dec ebx

            .UNTIL ZERO?

            invoke locktable_Lock

        ;// that's it

            ACTION_EXIT



    ;/// ENTER LEAVE GROUP /////////////////////////////////////////////////////////////////////


comment ~ /*

    new version ABox226
    we now create an id table and enforce it

*/ comment ~

    BEGIN_ACTION_HANDLER    UNREDO_ENTER_GROUP

        ;// this is hit from osc_command
        ;// so we want to use osc_hover

            mov esi, popup_Object
            .IF !esi
                mov esi, osc_hover
                DEBUG_IF <!!esi>
            .ENDIF

        ;// assign or retrieve an id for the group

            unredo_VerifyId
            mov [ecx].osc_id, eax
            mov [ecx].num_id, 0     ;// reset the count

        ;// continue on to enter displaying the group

            ACTION_EXIT



    END_ACTION_HANDLER      UNREDO_ENTER_GROUP

        ;// we are now in a new context
        ;// we must record all the id's inside the group

        ;// 1) determine if we need to assign id's to the objects inside the group
        ;// 2) if yes, determine the size of the unredo record needed to store the id's
        ;// 3) assign id's for every object in the group

        push ebp        ;// must preserve

        ;// 1) determine if we need to assign id's to the objects inside the group

            xor eax, eax    ;// counter of objects without id's
            xor edx, edx    ;// use for zero
            stack_Peek gui_context, ebp
            dlist_GetHead oscZ, esi, ebp
            .WHILE esi
                .IF [esi].id != edx ;// this object already has an id
                                    ;// so we do not need to store any at all
                    xor eax, eax    ;// reset any count we may have
                    .BREAK          ;// exit the counting loop
                .ENDIF
                dlist_GetNext oscZ, esi
                inc eax ;// one more osc to store
            .ENDW

        ;// 2) if yes, determine the size of the unredo record needed to store the id's
        ;//     now eax is the number of objects we need to assign id's for

            mov [ecx].num_id, eax   ;// store the number of id's
            test eax, eax           ;// test if there are any
            lea eax, [eax*4+SIZEOF(action_UNREDO_ENTER_GROUP)]  ;// determine the total record size
            mov (UNREDO_TEMP PTR [ecx]).dwSize, eax             ;// store the size, will be dword aligned

            .IF !ZERO? ;// if num_id's was zero, there's nothing to store

                ;// make sure we have a big enough struct

                .IF eax > MEMORY_SIZE(ecx)

                    invoke memory_Expand, ecx, eax
                    mov unredo_temp, eax
                    mov ecx, eax

                .ENDIF

            ;// 3) assign id's for every object in the group
            ;// assign id's for every object in the context

                dlist_GetHead oscZ, esi, ebp
                lea edi, [ecx+SIZEOF(action_UNREDO_ENTER_GROUP)]
                .REPEAT ;// we will have at least one osc

                    invoke unredo_assign_id
                    dlist_GetNext oscZ, esi
                    stosd

                .UNTIL !esi

            .ENDIF

        pop ebp     ;// retrieve ebp

        ACTION_EXIT ;// that's it




    REDO_ACTION_HANDLER     UNREDO_ENTER_GROUP

        mov eax, [ecx].osc_id
        push ecx    ;// need to preserve for next test
        hashd_Get unredo_id, eax, esi
        invoke closed_group_EnterView

        ;// now we must enforce all the id's

        pop ecx

        .IF [ecx].num_id    ;// num_id is non zero, so we have id's and we have oscs

        push ebp

            stack_Peek gui_context, ebp

        ;// 1) detect first if we need to do this
        ;//     we do if none of the objects have id's
        ;// --> we assume that if ANY id exists, then ALL id's exist
        ;// --> this may not be safe

            xor eax, eax
            dlist_GetHead oscZ, edi, ebp
            .IF eax == [edi].id

                ;// this osc has no id
                ;// so we have to assign all the ids in the next list

                ;// we assume that the oscZ list is in exactlt the same order
                ;// think about this, it appears to be a correct assumtion
                ;//   the zlist was defined by creating the closed group
                ;//   which was defined by paste file
                ;//   which was sourced by a copy buffer
                ;//   which is still inside an unredo record some where

                lea esi, [ecx+SIZEOF(action_UNREDO_ENTER_GROUP)]

                .REPEAT

                    lodsd               ;// eax has the id
                    mov [edi].id, eax   ;// store in object
                    hashd_Set unredo_id, eax, edi, edx
                    ;// _Set should always work
                    ;// it will fail if id does not exist
                    ;// but we assume that it does exist

                    dlist_GetNext oscZ, edi

                .UNTIL !edi

            .ENDIF

        pop ebp

        .ENDIF

        ;// then tell app to redraw everything

        invoke InvalidateRect, hMainWnd, 0, 1

        ACTION_EXIT







    BEGINEND_ACTION_HANDLER UNREDO_LEAVE_GROUP

        ;// the current context has the osc

            push ebp
            stack_Peek gui_context, ebp

            GET_OSC_FROM esi, [ebp].pGroup
            DEBUG_IF <!!esi>    ;// not supposed to be empty

            pop ebp

            unredo_VerifyId
            mov [ecx].osc_id, eax

            ACTION_EXIT

    REDO_ACTION_HANDLER     UNREDO_LEAVE_GROUP
    UNDO_ACTION_HANDLER     UNREDO_ENTER_GROUP

        invoke closed_group_ReturnFromView
        invoke InvalidateRect, hMainWnd, 0, 1
        ACTION_EXIT


    UNDO_ACTION_HANDLER     UNREDO_LEAVE_GROUP

        mov eax, [ecx].osc_id
        hashd_Get unredo_id, eax, esi
        invoke closed_group_EnterView
        invoke InvalidateRect, hMainWnd, 0, 1
        ACTION_EXIT




    ;//
    ;//  OSC  COMMANDS
    ;//
    ;////////////////////////////////////////////////////////////////////////////////////////////



    ;////////////////////////////////////////////////////////////////////////////////////////////
    ;//
    ;// EDIT LABEL
    ;//

    BEGIN_ACTION_HANDLER    UNREDO_EDIT_LABEL


        ;// use lable_pOsc as the object

            GET_OSC_FROM esi, label_pObject
            DEBUG_IF <!!esi>    ;// no object !!

            unredo_VerifyId
            mov [ecx].osc_id, eax

        ;// reset the edit flags

            mov [ecx].flags, 0

        ;// save rect 1

            rect_CopyTo [esi].rect, [ecx].rect1

        ;// save the text

            mov ebx, ecx
            ASSUME ebx:PTR action_UNREDO_EDIT_LABEL

            invoke GetWindowTextLengthA, label_hWnd
            inc eax
            mov [ebx].text_len1, eax

            add eax, SIZEOF action_UNREDO_EDIT_LABEL
            .IF eax > MEMORY_SIZE(ebx)

                add eax, 3
                and eax, -4
                invoke memory_Expand, ebx, eax
                mov unredo_temp, eax
                mov ebx, eax

            .ENDIF

            lea edi, [ebx+SIZEOF action_UNREDO_EDIT_LABEL]
            mov eax, [ebx].text_len1
            invoke GetWindowTextA, label_hWnd, edi, eax

            ACTION_EXIT


    END_ACTION_HANDLER      UNREDO_EDIT_LABEL

        mov eax, [ecx].osc_id
        hashd_Get unredo_id, eax, esi

        mov ebx, ecx
        ASSUME ebx:PTR action_UNREDO_EDIT_LABEL

        rect_CopyTo [esi].rect, [ecx].rect2

        point_GetTL [ebx].rect1
        point_XorTL [ecx].rect2
        point_XorBR [ecx].rect1
        point_XorBR [ecx].rect2
        or eax, edx
        .IF !ZERO?

            ;// size has changed
            or [ebx].flags, UNREDO_LABEL_SIZE_CHANGED

        .ENDIF

        EDITBOX label_hWnd, EM_GETMODIFY
        .IF eax

            ;// set the text changed flag

                or [ebx].flags, UNREDO_LABEL_TEXT_CHANGED

            ;// get new text length

                invoke GetWindowTextLengthA, label_hWnd

                inc eax
                push eax    ;// will be popped in call to GetWindowTextA
                mov [ebx].text_len2, eax

            ;// add to current struct length

                add eax, [ebx].text_len1
                add eax, SIZEOF action_UNREDO_EDIT_LABEL

            ;// see if we have to expand, save the size

                add eax, 3
                and eax, -4
                mov (UNREDO_TEMP PTR [ebx]).dwSize, eax
                .IF eax > MEMORY_SIZE(ebx)

                    invoke memory_Expand, ebx, eax
                    mov unredo_temp, eax
                    mov ebx, eax

                .ENDIF

            ;// determine where to store the new text

                mov eax, [ebx].text_len1
                lea eax, [eax+ebx+SIZEOF action_UNREDO_EDIT_LABEL]
                push eax

            ;// store the new text

                push label_hWnd
                call GetWindowTextA

        .ENDIF

        ;// check if anything happened

        mov eax, [ebx].flags
        or eax, eax
        jz cancel_end_action

        ACTION_EXIT


    UNDO_ACTION_HANDLER     UNREDO_EDIT_LABEL

        mov eax, [ecx].osc_id
        hashd_Get unredo_id, eax, esi
        mov ebx, ecx
        ASSUME ebx:PTR action_UNREDO_EDIT_LABEL

        .IF [ebx].flags & UNREDO_LABEL_SIZE_CHANGED

            ;// set position and size as rect 1

            invoke label_set_size, esi, ADDR [ebx].rect1

        .ENDIF

        .IF [ebx].flags & UNREDO_LABEL_TEXT_CHANGED

            ;// set text as text 1

            invoke label_set_text, esi, ADDR [ebx+SIZEOF action_UNREDO_EDIT_LABEL], [ebx].text_len1

        .ENDIF

        GDI_INVALIDATE_OSC HINTI_OSC_UPDATE

        ACTION_EXIT




    REDO_ACTION_HANDLER     UNREDO_EDIT_LABEL

        mov eax, [ecx].osc_id
        hashd_Get unredo_id, eax, esi
        mov ebx, ecx
        ASSUME ebx:PTR action_UNREDO_EDIT_LABEL

        .IF [ebx].flags & UNREDO_LABEL_SIZE_CHANGED

            ;// set position and size as rect 2

            invoke label_set_size, esi, ADDR [ebx].rect2

        .ENDIF

        .IF [ebx].flags & UNREDO_LABEL_TEXT_CHANGED

            ;// set text as text 2

            lea edx, [ebx+SIZEOF action_UNREDO_EDIT_LABEL]
            add edx, [ebx].text_len1

            invoke label_set_text, esi, edx , [ebx].text_len2

        .ENDIF

        GDI_INVALIDATE_OSC HINTI_OSC_UPDATE

        ACTION_EXIT

    ;//
    ;// EDIT LABEL
    ;//
    ;////////////////////////////////////////////////////////////////////////////////////////////


    ;////////////////////////////////////////////////////////////////////////////////////////////
    ;//
    ;//     UNREDO_SETTINGS
    ;//


    BEGIN_ACTION_HANDLER    UNREDO_SETTINGS

        mov eax, app_CircuitSettings
        mov [ecx].old_settings, eax

        ACTION_EXIT

    END_ACTION_HANDLER      UNREDO_SETTINGS

        mov eax, app_CircuitSettings
        mov [ecx].new_settings, eax

        ACTION_EXIT

    UNDO_ACTION_HANDLER     UNREDO_SETTINGS

        mov eax, [ecx].old_settings
        jmp unredo_circuit_settings

    REDO_ACTION_HANDLER     UNREDO_SETTINGS

        mov eax, [ecx].new_settings

    unredo_circuit_settings:

        and app_CircuitSettings, NOT CIRCUIT_TEST
        and eax, CIRCUIT_TEST
        or app_CircuitSettings, eax

        or app_bFlags, APP_SYNC_OPTIONBUTTONS

        ACTION_EXIT

    ;//
    ;//     UNREDO_SETTINGS
    ;//
    ;////////////////////////////////////////////////////////////////////////////////////////////

    ;////////////////////////////////////////////////////////////////////////////////////////////
    ;//
    ;//     UNREDO_ALIGN
    ;//
    comment ~ /*

        align commands are stored as the following table

        zero terminated list of oscs

            osc_id
            delta x,y

            zero terminated list of pin deltas

                pin offset
                delta pheta

        so, it might look like this:

            {osc_id,{dx,dy},{pin_offset,delta},{pin_offset,delta},0},
            {osc_id,{dx,dy},0},0

        to guess at the size, we'll use the miximum number

        some instances of recording will result in zero size change
        ie: the desired align command is not possible (like left aligning 1 object)
        these are detected in end action

    */ comment ~

    BEGIN_ACTION_HANDLER    UNREDO_ALIGN

        ;// 1) make sure there is enough room
        ;// 2) set precording

        push ebp
        stack_Peek gui_context, ebp

        clist_GetMRS oscS, esi, [ebp]
        mov ebx, esi                                ;// when to stop
        mov edx, SIZEOF action_UNREDO_ALIGN         ;// accumulated size
        DEBUG_IF <!!esi> ;// supposed to be an osc selected
        .REPEAT

            OSC_TO_BASE esi, edi                    ;// get the base class
            add edx, SIZEOF UNREDO_ALIGN_OSC        ;// accumulate the osc size
            mov eax, [edi].data.numPins             ;// load num pins
            shl eax, LOG2(SIZEOF UNREDO_ALIGN_PIN)  ;// turn into a size
            .IF !ZERO?
                add eax, 4                          ;// for pin terminator
            .ENDIF
            add edx, eax                            ;// accumulate

            clist_GetNext oscS, esi

        .UNTIL esi == ebx


        .IF edx > MEMORY_SIZE(ecx)

            invoke memory_Expand, ecx, edx
            mov unredo_temp, eax
            mov ecx, eax

        .ENDIF

        lea edx, [ecx+SIZEOF action_UNREDO_ALIGN]
        mov unredo_pRecorder, edx

        pop ebp

        ACTION_EXIT



    END_ACTION_HANDLER      UNREDO_ALIGN

        ;// 1) check for zero size change and exit if so
        ;// 2) set the total size of the record

        mov edi, unredo_pRecorder
        sub edi, ecx
        cmp edi, SIZEOF action_UNREDO_ALIGN
        je cancel_end_action
        mov (UNREDO_TEMP PTR [ecx]).dwSize, edi
        ACTION_EXIT

    UNDO_ACTION_HANDLER     UNREDO_ALIGN

        lea edi, [ecx+SIZEOF action_UNREDO_ALIGN]
        ASSUME edi:PTR UNREDO_ALIGN_OSC

        invoke context_UnselectAll

        .REPEAT

            mov eax, [edi].id
            hashd_Get unredo_id, eax, esi
            point_Get [edi].delta
            point_Neg
            point_Set mouse_delta

            clist_Insert oscS, esi,, [ebp]
            or [esi].dwHintI, HINTI_OSC_GOT_SELECT

            OSC_TO_BASE esi, ebx
            invoke [ebx].gui.Move

            add edi, SIZEOF UNREDO_ALIGN_OSC
            .IF [edi].id

                ASSUME edi:PTR UNREDO_ALIGN_PIN
                or [esi].dwHintOsc, HINTOSC_INVAL_DO_PINS

                .REPEAT

                    mov ebx, [edi].pin
                    fld [edi].delta
                    add ebx, esi
                    ASSUME ebx:PTR APIN
                    fsubr [ebx].pheta
                    or [ebx].dwHintI, HINTI_PIN_PHETA_CHANGED
                    fstp [ebx].pheta

                    add edi, SIZEOF UNREDO_ALIGN_PIN

                .UNTIL ![edi].pin

                ;//add edi, 4
                ASSUME edi:PTR UNREDO_ALIGN_OSC

            .ENDIF
            add edi, 4

        .UNTIL ![edi].id

        ACTION_EXIT


    REDO_ACTION_HANDLER     UNREDO_ALIGN

        lea edi, [ecx+SIZEOF action_UNREDO_ALIGN]
        ASSUME edi:PTR UNREDO_ALIGN_OSC

        invoke context_UnselectAll

        .REPEAT

            mov eax, [edi].id
            hashd_Get unredo_id, eax, esi
            point_Get [edi].delta
            point_Set mouse_delta

            clist_Insert oscS, esi,, [ebp]
            or [esi].dwHintI, HINTI_OSC_GOT_SELECT

            OSC_TO_BASE esi, ebx
            invoke [ebx].gui.Move

            add edi, SIZEOF UNREDO_ALIGN_OSC
            .IF [edi].id

                ASSUME edi:PTR UNREDO_ALIGN_PIN
                or [esi].dwHintOsc, HINTOSC_INVAL_DO_PINS

                .REPEAT

                    mov ebx, [edi].pin
                    fld [edi].delta
                    add ebx, esi
                    ASSUME ebx:PTR APIN
                    fadd [ebx].pheta
                    or [ebx].dwHintI, HINTI_PIN_PHETA_CHANGED
                    fstp [ebx].pheta

                    add edi, SIZEOF UNREDO_ALIGN_PIN

                .UNTIL ![edi].pin

                ;//add edi, 4
                ASSUME edi:PTR UNREDO_ALIGN_OSC

            .ENDIF
            add edi, 4

        .UNTIL ![edi].id

        ACTION_EXIT





    ;//
    ;//     UNREDO_ALIGN
    ;//
    ;////////////////////////////////////////////////////////////////////////////////////////////







ASSUME_AND_ALIGN

ENDIF   ;// USETHISFILE

END
