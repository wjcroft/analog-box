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
;// opened_Group.asm    The grouping object
;//                     see copious note in groups.inc
;//
;// TOC
;//
;// opened_group_Ctor
;// opened_group_EraseOscG
;// opened_group_Dtor
;// opened_group_Render
;// opened_group_Move
;// opened_group_InitMenu
;// opened_group_Command
;// opened_group_SaveUndo
;// opened_group_LoadUndo
;//
;// opened_group_Calc
;//
;// opened_group_PrepareToSave
;// opened_group_DefineG
;//
;// opened_group_H_Ctor
;// opened_group_H_Dtor
;// opened_group_H_Open
;// opened_group_H_Close
;// opened_group_H_Ready


OPTION CASEMAP:NONE
.586
.MODEL FLAT

USE_THIS_FILE equ 1

IFDEF USE_THIS_FILE

    .NOLIST
    INCLUDE <Abox.inc>
    INCLUDE <groups.inc>
    .LIST

.DATA



;// this struct is only to be used for opened groups

opened_Group OSC_CORE { opened_group_Ctor,
                opened_group_Dtor,,
                opened_group_Calc }

    OSC_GUI  {  opened_group_Render,,,,
                opened_group_Move,
                opened_group_Command,opened_group_InitMenu,,,
                opened_group_SaveUndo, opened_group_LoadUndo }

    OSC_HARD {  opened_group_H_Ctor,
                opened_group_H_Dtor,
                opened_group_H_Open,
                opened_group_H_Close,
                opened_group_H_Ready }

    OSC_DATA_LAYOUT { NEXT_opened_Group, IDB_GROUP,OFFSET popup_GROUP,
        BASE_HARDWARE OR BASE_NO_GROUP, 0, 4 + SIZEOF GROUP_DATA,
        SIZEOF OSC_OBJECT ,SIZEOF OSC_OBJECT , SIZEOF OSC_OBJECT + SIZEOF GROUP_DATA }

    OSC_DISPLAY_LAYOUT { circle_container,group_PSOURCE,ICON_LAYOUT(12,4,2,6) }

    short_name  db  'Group',0
    description db  'Marker to indicate the inside of a group.',0
    ALIGN 4

    ;// open groups do not have pins


    ;// private data

        slist_Declare oscG      ;// head of the open group list
                                ;// osc_Dtor needs access to this

        pGroupObject    dd  0   ;// this points to the group object in the circuit
                                ;// saves having to search for it
                                ;// app_Sync uses this to avoid calling opened_group_DefineG
    ;// field size

        OGROUP_RAD          EQU 32  ;// radius of the field

        OGROUP_RAD_SQUARED  EQU OGROUP_RAD * OGROUP_RAD

        OGROUP_CEN_TO_BR_X  EQU OGROUP_RAD
        OGROUP_CEN_TO_BR_Y  EQU OGROUP_RAD

        OGROUP_BR_TO_TL_X   EQU OGROUP_RAD * 2
        OGROUP_BR_TO_TL_Y   EQU OGROUP_RAD * 2

    ;// default name

        group_szNoName      db 'No Name',0


.CODE





;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;///
;///    OSC_OBJECT interface
;///
ASSUME_AND_ALIGN
opened_group_Ctor PROC

        ;// register call
    ;// ASSUME ebp:PTR LIST_CONTEXT ;// preserve
    ;// ASSUME esi:PTR OSC_OBJECT   ;// preserve
    ;// ASSUME edi:PTR OSC_BASE     ;// may destroy
    ;// ASSUME ebx:PTR FILE_OSC     ;// may destroy
    ;// ASSUME edx:PTR FILE_HEADER  ;// may destroy

        ASSUME esi:PTR OPENED_GROUP_MAP

    ;// set the circuit settings

        or app_CircuitSettings, CIRCUIT_OPEN_GROUP

    ;// tell the app we need to scan this group

        or app_bFlags, APP_SYNC_GROUP

    ;// set the group object

        DEBUG_IF <pGroupObject>     ;// not supposed to be set !!
        mov pGroupObject, esi

    ;// set the name if loading from file

        .IF !edx    ;// loading from file ?

            ;// xfer default name
            point_Get (POINT PTR group_szNoName)
            point_Set (POINT PTR [esi].szName)

        .ENDIF

    ;// take up the device slot for this object

        xor edx, edx
        invoke hardware_AttachDevice

    ;// that's it

        ret

opened_group_Ctor ENDP




ASSUME_AND_ALIGN
opened_group_EraseOscG PROC

    ;// utility function
    ;// called from: opened_group_DefineG
    ;//              opened_group_Dtor

    ;// tasks:
    ;//
    ;//     for each object in the g list
    ;//     remove from list
    ;//     reset HINTOSC_STATE_HAS_GROUP
    ;//     reset HINTOSC_STATE_HAS_BAD

    ASSUME ebp:PTR LIST_CONTEXT

    slist_GetHead oscG, ebx
    xor eax, eax
    .WHILE ebx
        slist_GetNext oscG, ebx, ecx
        mov slist_Next(oscG,ebx),eax;//[ebx].pNextG, eax
        GDI_INVALIDATE_OSC HINTI_OSC_LOST_GROUP OR HINTI_OSC_LOST_BAD, ebx
        mov ebx, ecx
    .ENDW

    ret

opened_group_EraseOscG ENDP





ASSUME_AND_ALIGN
opened_group_Dtor PROC

    ;// if we are opened then we simply release our hold on the device
    ;// if were are closed, we have to dtor all our contained objects
    ;// play_status

        ASSUME esi:PTR OPENED_GROUP_MAP
        ASSUME ebp:PTR LIST_CONTEXT

    ;// we tell the device block that we no longer exist
    ;// the hardware system will take care of closing the device

        mov ebx, [esi].pDevice
        ASSUME ebx:ptr HARDWARE_DEVICEBLOCK
        dec [ebx].numDevices
        DEBUG_IF <SIGN?>    ;// some how we lost count

    ;// then tell oscG that it's free to go

        .IF !([ebp].gFlags & GFLAG_DOING_NEW)

            invoke opened_group_EraseOscG

        .ENDIF

    ;// reset the group object and oscG list

        xor eax, eax

        mov pGroupObject, eax
        mov slist_Head(oscG), eax;//slist_SetHead oscG, eax

    ;// turn off the open group

        DEBUG_IF <!!(app_CircuitSettings & CIRCUIT_OPEN_GROUP)>
        xor app_CircuitSettings, CIRCUIT_OPEN_GROUP

    ;// that's it

        ret

opened_group_Dtor ENDP




ASSUME_AND_ALIGN
opened_group_Render PROC

        ASSUME esi:PTR OPENED_GROUP_MAP

        invoke gdi_render_osc

    ;// then we draw our field rect

        GDI_DC_SELECT_RESOURCE hPen_1, COLOR_DESK_GROUPED

        mov eax, hBrush_null
        .IF eax != gdi_current_brush
            mov gdi_current_brush, eax
            invoke SelectObject, gdi_hDC, eax
        .ENDIF

        OSC_TO_CONTAINER esi, ebx

        point_Get [ebx].shape.siz
        shr eax, 1
        shr edx, 1
        point_AddTL [esi].rect

        point_Add OGROUP_CEN_TO_BR
        push edx
        push eax
        point_Sub OGROUP_BR_TO_TL
        push edx
        push eax
        push gdi_hDC
        call Ellipse

    ;// that's it

        ret

opened_group_Render ENDP


ASSUME_AND_ALIGN
opened_group_Move PROC

    ;// our task here is make sure the feild rect gets reblitted


    ;// 1) use default if we are moving the screen

        test app_bFlags, APP_MODE_MOVING_SCREEN
        jnz osc_Move

    ;// 2) determine the invalidate portion and erase it

        ;// call osc_Move   ;// call default first

        ASSUME esi:PTR OPENED_GROUP_MAP

        OSC_TO_CONTAINER esi, ebx

        point_Get [ebx].shape.siz
        shr eax, 1
        shr edx, 1
        point_AddTL [esi].rect

        gdi_Erase_this_point PROTO  ;// defined in gdi_invalidate.asm

        point_Add OGROUP_CEN_TO_BR
        invoke gdi_Erase_this_point
        point_Sub OGROUP_BR_TO_TL
        invoke gdi_Erase_this_point

    ;// then call the defualt function

        call osc_Move

    ;// and blit the new rect

        OSC_TO_CONTAINER esi, ebx

        point_Get [ebx].shape.siz
        shr eax, 1
        shr edx, 1
        point_AddTL [esi].rect

        gdi_Blit_this_point PROTO   ;// defined in gdi_invalidate.asm

        point_Add OGROUP_CEN_TO_BR
        invoke gdi_Blit_this_point
        point_Sub OGROUP_BR_TO_TL
        invoke gdi_Blit_this_point

    ;// that's it

        ret


opened_group_Move ENDP






ASSUME_AND_ALIGN
opened_group_InitMenu PROC  ;// STDCALL uses esi edi pObject:ptr OSC_OBJECT

        ASSUME esi:PTR OPENED_GROUP_MAP

    ;// set the window text and limit the length

        invoke GetDlgItem, popup_hWnd, ID_GROUP_NAME
        lea edx, [esi].szName

        pushd 0
        pushd GROUP_NAME_SIZE-1
        pushd EM_SETLIMITTEXT
        push eax

        EDITBOX eax, WM_SETTEXT,0,edx

        call SendMessageA

    ;// en/disable the CreateNow button

        invoke GetDlgItem, popup_hWnd, ID_GROUP_CREATE_CLOSED
        xor ecx, ecx
        .IF !([esi].dwUser & GROUP_BAD)
            slist_GetHead oscG,edx
            .IF slist_Next(oscG,edx)    ;// must have at least two objects
                inc ecx
            .ENDIF
        .ENDIF
        invoke EnableWindow, eax, ecx

    ;// that's it

        xor eax, eax    ;// return zero or popup will resize

        ret

opened_group_InitMenu ENDP



ASSUME_AND_ALIGN
opened_group_Command PROC

        ASSUME esi:PTR OPENED_GROUP_MAP
        ;// eax has the command ID
        ASSUME ebp:PTR LIST_CONTEXT

    cmp eax, OSC_COMMAND_EDIT_CHANGE
    jne @F

        invoke GetDlgItem, popup_hWnd, ID_GROUP_NAME
        lea edx, [esi].szName
        invoke SendMessageA, eax, WM_GETTEXT, GROUP_NAME_SIZE-1, edx

        .IF !eax    ;// check for empty

            point_Get (POINT PTR group_szNoName)
            point_Set (POINT PTR [esi].szName)

        .ENDIF

        mov eax, POPUP_SET_DIRTY
        ret

    ALIGN 16
@@: cmp eax, ID_GROUP_CREATE_CLOSED
    jne osc_Command

        ;// clear the selection
        ;// xfer all items in the group list to the selection
        ;// invoke copy
        ;// invoke paste_group


        invoke context_UnselectAll

        slist_GetHead oscG,ebx
        .REPEAT
            clist_Insert oscS,ebx,,[ebp]
            slist_GetNext oscG,ebx
        .UNTIL !ebx

        invoke context_Copy

        mov edi, file_pCopyBuffer
        ASSUME edi:PTR FILE_HEADER  ;// edi is a file header

        ;// see context_PasteFile for details of this code

            xor [edi].settings, CIRCUIT_OPEN_GROUP
            DEBUG_IF < DWORD PTR [edi+SIZEOF FILE_HEADER+SIZEOF FILE_OSC] & GROUP_BAD >
            invoke closed_group_PrepareToLoad
            mov file_pCopyBuffer, edi

            unredo_BeginAction UNREDO_PASTE
            inc popup_EndActionAlreadyCalled    ;// so we get the redo correct

            invoke context_Paste, file_pCopyBuffer, 0, 1    ;// no ids,

        mov eax, POPUP_DONOT_RESET_FOCUS
        ret

opened_group_Command ENDP


;////////////////////////////////////////////////////////////////////
;//
;//
;//     _SaveUndo
;//

ASSUME_AND_ALIGN
opened_group_SaveUndo   PROC

        ASSUME esi:PTR OPENED_GROUP_MAP

    ;// edx enters as either UNREDO_CONTROL_OSC or UNREDO_COMMAND
    ;// edi enters as where to store
    ;//
    ;// task:   1) save nessary data
    ;//         2) iterate edi
    ;//
    ;// may use all registers except ebp

        ;// opened group does not need dwUser
        ;// save    szName db GROUP_NAME_SIZE dup(0)    ;// name of this object

            add esi, OFFSET OPENED_GROUP_MAP.szName
            mov ecx, GROUP_NAME_SIZE / 4
            rep movsd

            ret

opened_group_SaveUndo ENDP
;//
;//
;//     _SaveUndo
;//
;////////////////////////////////////////////////////////////////////

;////////////////////////////////////////////////////////////////////
;//
;//
;//     _LoadUndo
;//

ASSUME_AND_ALIGN
opened_group_LoadUndo PROC

        ASSUME esi:PTR OSC_OBJECT   ;// preserve
        ASSUME ebp:PTR LIST_CONTEXT ;// preserve

    ;// edx enters as either UNREDO_CONTROL_OSC or UNREDO_COMMAND
    ;// edi enters as where to load
    ;//
    ;// task:   1) load nessary data
    ;//         2) do what it takes to initialize it
    ;//
    ;// may use all registers except ebp and esi
    ;// return will invalidate HINTI_OSC_UPDATE

        push esi

        add esi, OFFSET OPENED_GROUP_MAP.szName
        mov ecx, GROUP_NAME_SIZE / 4
        xchg esi, edi
        rep movsd

        pop esi

        ret

opened_group_LoadUndo ENDP

;//
;//
;//     _LoadUndo
;//
;////////////////////////////////////////////////////////////////////





;/////////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
opened_group_Calc PROC ;// STDCALL USES esi edi pObject:PTR OSC_OBJECT

    ret     ;// nothing to do

opened_group_Calc ENDP







;/////////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////////
comment ~ /*

    opened_group_PrepareToSave

        this function rearranges the zlist to make sure that the circuit can be
        rebuilt as a closed group. It is called as the first step to saving a file.

*/ comment ~

    ;// task:
    ;//
    ;// sort the z list
    ;//
    ;// put all IO pins at the start of the z-list (sorted vertically)
    ;// set the IO bits appropriately and keep track of numbers of
    ;// put all oscs after the pins
    ;// put the group object at the start of the circuit

.DATA

    pinint_flags    LABEL DWORD

    comment ~ /*

        to build the pin interface flags,
        we use the pinint_flags table
        this requires building an index to the table

        nomenclature:

            abr description         test                indx
            --- -----------------   ---------------     I--O
            nc  not connected       !pPin               0  0
            co  connected outside   pPin && !pNextG     3  1
            ci  connected inside    pPin && pNextG      6  2

            I   input side
            O   output side

    */ comment ~

    ;// flags                         index states  descr      picture
    ;// ----------------------------- ----- ------- -------  ------------
    dd  PININT_INPUT OR PININT_OUTPUT ;// 0 ncI ncO through  I-|-----|->O
    dd  PININT_OUTPUT                 ;// 1 ncI coO output     |   I-|->O
    dd  PININT_INPUT                  ;// 2 ncI ciO input    I-|->O  |
    dd  PININT_INPUT                  ;// 3 coI ncO input    I-|->O  |
                                      ;//                      |     |
    dd  PININT_INPUT OR PININT_OUTPUT ;// 4 coI coO through  I-|-----|->O
                                      ;//                      |     |
    dd  PININT_INPUT                  ;// 5 coI ciO input    I-|->O  |
    dd  PININT_OUTPUT                 ;// 6 ciI ncO output     |   I-|->O
    dd  PININT_OUTPUT                 ;// 7 ciI coO output     |   I-|->O
    dd  0                             ;// 8 ciI ciO internal   |I-->O|

.CODE

ASSUME_AND_ALIGN
opened_group_PrepareToSave PROC USES edi ebp esi ebx

        GET_OSC_FROM edi, pGroupObject  ;// get the group object
        ASSUME edi:PTR OPENED_GROUP_MAP

        ;// see note001 (do a text search in closed_group.asm)
        ;// this is the last chance we ever get to set this

        mov [edi].header.header, ABOX2_FILE_HEADER


        xor ecx, ecx    ;// use for clearing

        lea ebp, master_context         ;// always use master context
        ASSUME ebp:PTR LIST_CONTEXT

    ;// we keep track of a pLastPin iterator
    ;// pLastPin means the last pin interface we inserted in the zlist

        pushd ecx
        st_last TEXTEQU <(DWORD PTR [esp])>

    ;// reset the number of osc's and the number of pins

        mov [edi].numPin, ecx
        mov [edi].header.numOsc, ecx

    ;// scan the zlist
    ;// remove each item, put it back where it belongs

        slist_GetHead oscG, esi
        .WHILE esi != edi   ;// group object is always at the end of the glist

            dlist_Remove oscZ, esi,,[ebp]   ;// remove this item

            OSC_TO_BASE esi, ebx    ;// get the base class in ebx
            xor edx, edx            ;// used for testing zero
            cmp ebx, OFFSET osc_PinInterface    ;// pin ??
            jne insert_as_osc       ;// jump if not pin

        insert_as_pin:  ;// build the pin interface io flags

            DEBUG_IF <edx>  ;// supposed to be zero !!

            ASSUME esi:PTR PININT_OSC_MAP   ;// esi is the pin interface object

            xor ecx, ecx    ;// zero for testing
            xor eax, eax    ;// flags to build

            ;// INPUT SIDE
            OR_GET_PIN [esi].pin_I.pPin, ecx    ;// get and test the pin
            jz II                   ;// jump now if ecx is zero
            PIN_TO_OSC ecx, ecx     ;// get the osc
            inc eax                 ;// add 1 to index
            cmp edx, slist_Next(oscG,ecx);//[ecx].pNextG    ;// check pNextG for zero
            mov ecx, edx            ;// clear ecx
            je II                   ;// jump if ecx is outside
            inc eax                 ;// add another to index
        II: lea eax, [eax+eax*2]    ;// multiply by three

            ;// OUTPUT SIDE
            OR_GET_PIN [esi].pin_O.pPin, ecx    ;// get and test the pin
            jz OO                   ;// jump now if ecx is zero
            PIN_TO_OSC ecx, ecx     ;// get the osc
            inc eax                 ;// add 1 to index
            cmp edx, slist_Next(oscG,ecx);//[ecx].pNextG    ;// check pNextG for zero
            jz OO                   ;// jump if ecx is outside
            inc eax                 ;// add another to index
        OO: mov eax, pinint_flags[eax*4];// load the flags

        ;// determine if and where we move this

            and [esi].dwUser, PININT_TEST_TEST  ;// need to keep the test flags
            or [esi].dwUser, eax    ;// store as object dwUser
            or eax, eax             ;// test the new flags
            jz insert_as_osc

        insert_as_pin__really:

            ;// keep track of last pin and set the pin's index

            ;//and [esi].dwUser, NOT PININT_INDEX_TEST  ;// remove old index (just in case)
            ;//mov eax, [edi].numPin    ;// get numer of pins
            inc [edi].numPin        ;// keep track of number of pins
            ;//shl eax, 16              ;// change to an index (high word)
            ;//or [esi].dwUser, eax ;// merge in new index

            ;// get ready to insert

            OR_GET_OSC_FROM edx, st_last    ;// edx tells us when to stop
            jnz do_sorted_insert            ;// if it's not zero

            mov st_last, esi    ;// set the new last
            jmp insert_as_head  ;// jmp head setter

        do_sorted_insert:   ;// we need a sorted insert for this

            mov eax, [esi].rect.top             ;// eax is the sort value
            dlist_GetHead oscZ, ebx, [ebp]      ;// ebx iterates oscs in the z list

            ;// DEBUG_IF <edx==ebx> ;// new object = last object, not sposed to happen

            J1: cmp eax, [ebx].rect.top                 ;// compare top corners
                jge J2                                  ;// jump if esi is beneath iter
                DEBUG_IF <esi==ebx> ;// can't insert before self
                dlist_InsertBefore oscZ,esi,ebx,,[ebp]  ;// insert esi BEFORE iter
                jmp next_osc                            ;// do the next loop

            J2: cmp ebx, edx                            ;// are we done yet
                je J3                                   ;// jump to insert after if we are
                dlist_GetNext oscZ, ebx                 ;// get next osc
                jmp J1                                  ;// jump up to top

            J3: mov st_last, esi                        ;// set the new last item
                jmp insert_after_edx    ;// insert this after last


        insert_as_osc:  ;// insert this into z list as an osc
                        ;// edx is still zero
            OR_GET_OSC_FROM edx, st_last        ;// load and test the end of the pin insert list
            jnz insert_after_edx

        insert_as_head:
            ;// since we removed this osc, there's no way it can be in the Z list
            dlist_InsertHead oscZ, esi,,[ebp]
            jmp next_osc

        insert_after_edx:

            DEBUG_IF <esi==edx> ;// can't insert after self
            dlist_InsertAfter oscZ, esi,edx,,[ebp]

        next_osc:

            inc [edi].header.numOsc ;// always keep track

            slist_GetNext oscG, esi

        .ENDW   ;// esi != edi

    ;// now we set the pin indexes

        GET_OSC_FROM ebx, st_last   ;// get the last pin interface we inserted
        .IF ebx                     ;// make sure there was one

            dlist_GetHead oscZ, esi, [ebp]  ;// get head of the now sorted z_list
            xor eax, eax                    ;// eax will iterate indexes

        K0: or [esi].dwUser, eax    ;// merge in new index
            add eax, 10000h         ;// increase the index
            cmp esi, st_last        ;// are we done yet
            je K1                   ;// jump if were done
            dlist_GetNext oscZ, esi ;// get next osc
            jmp K0                  ;// jmp to top of loop
        K1:
        .ENDIF

    ;// 2)  move the group to the head of the zlist

        dlist_MoveToHead oscZ, edi,,[ebp]

    ;// that's it !

        pop eax
        st_last TEXTEQU <>

        ret

opened_group_PrepareToSave ENDP










ASSUME_AND_ALIGN
opened_group_DefineG PROC


DEBUG_IF <!!pGroupObject>   ;// why call this ?

stack_Peek gui_context, eax
cmp eax, OFFSET master_context
je @F

    ret

@@: push ebp
    push esi
    push edi
    push ebx


    ;// our job is to locate all the objects in the group

    ;// 1) clear the old list, insert our selves as the head
    ;//
    ;//     invalidate as we go

    ;// 2) determine objects that intersect the group field
    ;//
    ;//     build a field rect, test all z list objects against it
    ;//     add intersecting objects at the head
    ;//     membership is then determined by pNextG != 0

    ;// 3) trace the oscG list, looking for pin interfaces
    ;//
    ;//     add new objects AFTER the current object
    ;//     invalidate as we go
    ;//     if a hardware device is found, mark group as bad

    ;// 4) scan the z list and look for labels with the KEEP_GROUP flag set
    ;//
    ;//     add these items to the glist, if not already in the list

        stack_Peek gui_context, ebp

    ;// 1) clear the old list, insert our selves as the head

        invoke opened_group_EraseOscG

        GET_OSC_FROM edi, pGroupObject
        mov slist_Head(oscG), edi;//slist_SetHead oscG, edi

        and [edi].dwUser, NOT GROUP_BAD

        ;// for the rest of this function, edi = pGroupObject


    ;// 2) determine objects that intersect the group field

        ;// build a field rect

        OSC_TO_CONTAINER edi, ebx

        point_Get [ebx].shape.siz
        shr eax, 1
        shr edx, 1
        point_AddTL [edi].rect
        push edx
        push eax

        point_Add OGROUP_CEN_TO_BR
        push edx
        push eax
        point_Sub OGROUP_BR_TO_TL
        push edx
        push eax

        st_point TEXTEQU <(POINT PTR [esp+SIZEOF RECT])>
        st_rect TEXTEQU <(RECT PTR [esp])>

        ;// scan the z_list and look for items that intersect

        dlist_GetHead oscZ, esi, master_context
        point_GetBR st_rect
        .WHILE esi
        .IF esi != edi  ;// skip the group object

            OSC_TO_BASE esi, ecx
            .IF ecx != OFFSET osc_Label ;// don't add labels

                ;// eax,edx must be st_rect.BR

                cmp eax, [esi].rect.left
                jl zscan_next
                cmp edx, [esi].rect.top
                jl zscan_next

                point_GetTL st_rect

                cmp eax, [esi].rect.right
                jg zscan_next_reload
                cmp edx, [esi].rect.bottom
                jg zscan_next_reload

                slist_InsertHead oscG, esi

            zscan_next_reload:

                point_GetBR st_rect

            .ENDIF

        .ENDIF
        zscan_next:

            dlist_GetNext oscZ, esi

        .ENDW

        add esp, (SIZEOF RECT) + (SIZEOF POINT)
        st_rect TEXTEQU <>
        st_point TEXTEQU <>

    ;// 3) trace the lists connections, all of them
    ;//     mark hardware as bad group

        slist_GetHead oscG, esi
        .WHILE esi != edi

            ;// set the group bit

            GDI_INVALIDATE_OSC HINTI_OSC_GOT_GROUP

            ;// check for pin interfaces and hardware

            OSC_TO_BASE esi, ecx
            .IF [ecx].data.dwFlags & BASE_NO_GROUP

                GDI_INVALIDATE_OSC HINTI_OSC_GOT_BAD, esi
                GDI_INVALIDATE_OSC HINTI_OSC_GOT_BAD, edi
                or [edi].dwUser, GROUP_BAD

            .ENDIF

            ;// don't trace interface pins

            .IF ecx != OFFSET osc_PinInterface

            xor ecx, ecx    ;// keep clear for testing

            ITERATE_PINS

                OR_GET_PIN [ebx].pPin, ecx      ;// connected ? (bussed or no)
                .IF !ZERO?

                    DEBUG_IF <[ebx].dwStatus & PIN_HIDDEN>  ;// not supposed be connected

                    ;// if this pin is an output, start with it
                    ;// otherwise start with ecx, the output

                    .IF [ebx].dwStatus & PIN_OUTPUT
                        mov ecx, ebx
                    .ENDIF

                    ;// add the output pin's object

                    PIN_TO_OSC ecx, edx                 ;// get the object
                    .IF !slist_Next(oscG,edx);//[edx].pNextG                    ;// already in list ?
                        slist_InsertNext oscG, esi, edx ;// add it now
                    .ENDIF

                    mov ecx, [ecx].pPin     ;// get first input, already checked to exist

                    .REPEAT                     ;// scanning input pins

                        PIN_TO_OSC ecx, edx     ;// get the object
                        .IF !slist_Next(oscG,edx);//[edx].pNextG        ;// already in list ?
                            slist_InsertNext oscG, esi, edx ;// add it now
                        .ENDIF
                        GET_PIN [ecx].pData, ecx    ;// get the next input

                    .UNTIL !ecx ;// done yet ?

                    ;// ecx will now be zero

                .ENDIF

            PINS_ITERATE

            .ENDIF  ;// interface pin

            slist_GetNext oscG, esi

        .ENDW

    ;// 4) scan the z list and look for labels with the KEEP_GROUP flag set

        dlist_GetHead oscZ, esi, master_context
        .WHILE esi

            .IF [esi].pBase == OFFSET osc_Label

                .IF [esi].dwUser & LABEL_KEEP_GROUP

                ;// add to list

                    slist_InsertHead oscG, esi

                ;// set the group bit

                    GDI_INVALIDATE_OSC HINTI_OSC_GOT_GROUP

                .ENDIF

            .ENDIF

            dlist_GetNext oscZ, esi

        .ENDW

    ;// that should do it

    pop ebx
    pop edi
    pop esi
    pop ebp

    ;// that's it !!    reset the app flags and we're out of here
    ;// and app_bFlags, NOT APP_SYNC_GROUP
    ;// nope, app_sync will do this for us

        ret


opened_group_DefineG ENDP








;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;///
;///    Hardware interface, allows only one open group
;///


ASSUME_AND_ALIGN
opened_group_H_Ctor PROC

        invoke about_SetLoadStatus

    ;// fill in the rquired device block stuff

        slist_AllocateHead hardwareL, ebx

        mov [ebx].ID, 0
        mov [ebx].pBase, OFFSET opened_Group
        mov [ebx].szName, 0

    ;// that's it

        ret

opened_group_H_Ctor ENDP


PROLOGUE_OFF
ASSUME_AND_ALIGN
opened_group_H_Dtor PROC STDCALL pDevBlock:PTR HARDWARE_DEVICEBLOCK

    ;// nothing to do

    ret 4

opened_group_H_Dtor ENDP
PROLOGUE_ON

PROLOGUE_OFF
ASSUME_AND_ALIGN
opened_group_H_Open PROC STDCALL pDevice:PTR HARDWARE_DEVICEBLOCK

        mov ecx, DWORD PTR [esp+4]
        ASSUME ecx:PTR HARDWARE_DEVICEBLOCK

    ;// check if we're already open

        mov eax, [ecx].hDevice      ;// get the device handle
        .IF !eax                    ;// if closed now (eax==0)

            mov [ecx].hDevice, 1    ;// open the device by setting 1 in the device ptr

        .ENDIF                      ;// eax is still zero

    ;// that's it

        ret 4

opened_group_H_Open ENDP
PROLOGUE_ON


PROLOGUE_OFF
ASSUME_AND_ALIGN
opened_group_H_Close PROC STDCALL pDevice:PTR HARDWARE_DEVICEBLOCK

    ;// here, we close the device

        mov ecx, DWORD PTR [esp+4]
        ASSUME ecx:PTR HARDWARE_DEVICEBLOCK

        mov [ecx].hDevice, 0


    ;// that's it

        ret 4

opened_group_H_Close ENDP
PROLOGUE_ON

ASSUME_AND_ALIGN
opened_group_H_Ready PROC   ;// STDCALL uses esi edi pDevice:PTR HARDWARE_DEVICEBLOCK

    ;// we're always ready

    mov eax, READY_TIMER ;// treat this as a display device
    ret 4

opened_group_H_Ready    ENDP


;///
;///    Hardware interface, allows only one open group
;///
;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////























ASSUME_AND_ALIGN



ENDIF   ;// USE_THIS_FILE


END


;//////////////////////////////////////////////////////////////////////////////////////
comment ~ /*    example of closed group file storage ( 2 pins for example )

The goal is that closed groups should need no futher reconditioning once they are pasted

    FILE_OSC                ;// .extra will include all the osc's in the group
        dwUser              ;// dw User flags
        OSC_GROUP           ;// data needed for the new base class
        APIN_init           ;// for example
        APIN_init           ;// for example
        All the osc's       ;// each osc must be able to load via osc_Ctor
    FILE_PIN                ;// connection for first pin
    FILE_PIN                ;// connection for second pin

    when an open group is pasted, group_ConvertToClosed will reformat the pasted memory
    to conform to this standard.

    when Ctor is then called for a closed group, it will:
        1) build a fake base class
        2) load, and create all the internal objects, including other closed groups
        3) connect the internal objects
        the internal oscC will be the calc order


    problem 1) if the group is closed
            file_CheckForUnknown objects will miss the internal objects
            and at the same time will miss converting the object ID's to base pointers

    for the first paste from file, id's will get converted correctly
    so on subsequent pastes we don't have to check for unknowns, only convert the bases
    file_CheckForUnknown objects must also be fooled into checking inside the closed group

;///////////////////////////////////////////////////////////////////////////

    reusing a group's virtual base class

    we can reuse the base if:

        same number of pins
        same object size
        same pin locations

        it shouldn't matter if the internal circuits are not the same
        we only care about drawing and UI stuff

*/ comment ~ ;/////////////////////////////////////////////////////////////////////////////

