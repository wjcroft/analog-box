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
;//                  app level bus functions
;// ABox_Bus.asm     top level dialog handlers
;//
;//
;// TOC:
;//
;// bus_Show
;// bus_GetEditRecord
;// bus_GetNameFromPin
;// bus_GetShape
;// bus_load_strings
;// bus_LoadFile
;// bus_SaveFile
;// bus_AddExtraSize
;// bus_Clear
;// bus_Pull
;// bus_Direct
;// bus_Create
;// bus_Rename
;// bus_Transfer
;// bus_ConvertTo
;// bus_ResetTable
;// bus_LoadContext
;// bus_CompactCategories
;// bus_SaveContext
;// bus_GetNameFromRecord
;// bus_UpdateUndoRedo
;// bus_Proc
;// bus_wm_setcursor_proc
;// bus_wm_activate_proc
;// bus_Activate
;// bus_wm_keydown_proc
;// bus_wm_command_proc
;// bus_wm_close_proc
;// bus_wm_create_proc
;// bus_wm_destroy_proc



OPTION CASEMAP:NONE

.586
.MODEL FLAT

        .NOLIST
        include <Abox.inc>
        include <gdi_pin.inc>
        .LIST
    ;// .LISTALL
    ;// .LISTMACROALL
        include <bus.inc>


.DATA


;////////////////////////////////////////////////////////////////////
;//
;//
;//     BUS DIALOG HELPERS
;//


        bus_pos POINT {}    ;// temp defined in wm_create, where we display on the screen
        bus_siz POINT {}    ;// defined in wm_create, size of the window

        bus_hWnd        dd  0   ;// hWnd for the context menu
        hWnd_bus_status dd  0   ;// handle of the status control
        hWnd_bus_undo   dd  0   ;// handle of the undo button
        hWnd_bus_redo   dd  0   ;// handle of the redo button

        dlg_mode    dd  DM_VIEWING_GRID ;// collection of flags

        bus_pPin    dd 0    ;// the pin that the user clicked on to launch the editor

        bus_pTable  dd  0   ;// allocated ptr to 240 BUS_EDIT_RECORDs plus one more for temp strings
        bus_pString dd  0   ;// allocated string holder acts as an xfer between lists and records
                            ;// this is limited to 128 bytes (2 records)

        bus_last_context dd 0   ;// last viewed context

        bus_table_is_dirty dd   0   ;// flag means we need to save the context when exiting
                                ;// this will over write the the context.pBusStrings pointer

    ;// bus helper strings,
    ;//     assigned by bus_wm_create_proc
    ;//     used by bus_wm_set_cursor_proc

        bus_last_status dd  0

    bus_status_table    LABEL DWORD

        ;// this table is in the format of pString,ID

        dd  sz_SHOWBUSSES   ,IDC_BUS_SHOWBUSSES
        dd  sz_SHOWNAMES    ,IDC_BUS_SHOWNAMES
        dd  sz_UNCONNECT    ,IDC_BUS_UNCONNECT
        dd  sz_DIRECT       ,IDC_BUS_DIRECT
        dd  sz_PULL         ,IDC_BUS_PULL
        dd  sz_MEM          ,IDC_BUS_MEM
        dd  sz_ADD_CAT      ,IDC_BUS_ADD_CAT
        dd  sz_DEL_CAT      ,IDC_BUS_DEL_CAT
        dd  sz_SORT_NUMBER  ,IDC_BUS_SORT_NUMBER
        dd  sz_SORT_NAME    ,IDC_BUS_SORT_NAME
        dd  sz_EDITOR       ,IDC_BUS_EDITOR
        dd  1               ,IDC_BUS_GRID
        dd  -1              ,IDC_BUS_UNDO
        dd  -2              ,IDC_BUS_REDO
        dd 0    ;// terminator

        sz_SHOWBUSSES   db  'Show bus control grid.',0
        sz_SHOWNAMES    db  'Show bus categories and names.',0
        sz_UNCONNECT    db  'Unconnect. (Del)',0
        sz_DIRECT       db  'Convert to a direct connection. (BackSpace)',0
        sz_PULL         db  'Pull connected pins together. (Enter)',0
        sz_MEM          db  'Click/Drag to move. Enter/DblClick to edit.',0
        sz_ADD_CAT      db  'Insert a new category. (Ins)',0
        sz_DEL_CAT      db  'Delete selected category. (Del)',0
        sz_SORT_NUMBER  db  'Sort by bus number.',0
        sz_SORT_NAME    db  'Sort by bus name.',0
        sz_EDITOR       db  'Edit this name. Esc or Enter to stop.',0

        ALIGN 16

;//
;//
;//     BUS DIALOG HELPERS
;//
;////////////////////////////////////////////////////////////////////

    ;// the bus table needs a fake base class to be able to load it from a file
    ;// there is much wasted space here, too bad ?

        osc_BusTable    OSC_CORE { bus_LoadFile }
                        OSC_GUI     {}
                        OSC_HARD    {}
                        OSC_DATA_LAYOUT { ,,,BASE_ALLOCATES_MANUALLY }



.CODE



;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////
;////
;////                       bus_Show        launches the dialog panel
;////   APP LEVEL           bus_GetName     builds the long name of the bus
;////   UTILTY FUNCTIONS    bus_GetShape    retrieves the gdi pointer for the bus
;////
;////                       bus_LoadFile    loads string from a file
;////                       bus_SaveFile    saves to a file
;////                       bus_AddExtraSize    determines the size of the bus string block
;////
;////                       bus_Clear       erases the bus table
;////



;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;//
;//                 call this to launch the dialog
;//     bus_Show    uses the current gdi_context
;//

ASSUME_AND_ALIGN
bus_Show PROC STDCALL uses esi edi ebx

        LOCAL point:POINT
        LOCAL rect:RECT

    ;// we alway use pin hover to initialize

        DEBUG_IF <!!pin_hover>  ;// pin_hover is supposed to be set

    ;// make sure we are in the current edit context

        stack_Peek gui_context, ecx
        .IF ecx != bus_last_context

            push ebp
            mov ebp, ecx
            invoke bus_LoadContext
            pop ebp

        .ENDIF

    ;// save the selected pin

        GET_PIN pin_hover, ebx  ;// get pin hover
        mov bus_pPin, ebx       ;// store here

    ;// determine where we show this window

        point_CopyTo mouse_now, point
        sub point.x, GDI_GUTTER_X
        sub point.y, GDI_GUTTER_Y
        invoke ClientToScreen, hMainWnd, ADDR point

    ;// do some checks to make sure it fits on the screen

        rect_FromPosSize rect, point, bus_siz

    ;// we know that the top left is on the screen
    ;// so we check that the bottom right is on the screen

        mov eax, rect.bottom
        sub eax, gdi_desk_size.y
        .IF !SIGN?

            ;// we must shift the bottom and top UP
            sub rect.top, eax
            sub rect.bottom, eax

        .ENDIF

        mov eax, rect.right
        sub eax, gdi_desk_size.x
        .IF !SIGN?

            ;// we must shift the rect LEFT
            sub rect.left, eax
            sub rect.right, eax

        .ENDIF

    ;// this may fix an annoying flaw

        or dlg_mode, DM_GRID_INIT OR DM_CAT_INIT

    ;// show the window

        invoke SetWindowPos, bus_hWnd, HWND_TOPMOST,
            rect.left, rect.top,
            bus_siz.x, bus_siz.y,
            SWP_SHOWWINDOW + SWP_DRAWFRAME

    ;// and take care of xmouse

        .IF app_xmouse

            point_GetTL rect

            add edx, 8
            add eax, 8

            invoke SetCursorPos, eax, edx

        .ENDIF

    ;// turn the pin hover back on
    ;// show window shut off via WM_ACTIVATE from hMainWnd

        push ebp
        stack_Peek gui_context, ebp
        mov ebx, bus_pPin
        invoke mouse_set_pin_hover
        pop ebp

    ;// that's it

        ret

bus_Show    ENDP
;//
;//     bus_Show
;//
;//
;////////////////////////////////////////////////////////////////////







;////////////////////////////////////////////////////////////////////
;//
;//     bus_GetEditRecord
;//
;//     usage:  push    reg_with_one_based_index
;//             invoke  bus_GetEditRecord
;//             pop     reg_that_is_now_a_pointer

ASSUME_AND_ALIGN
bus_GetEditRecord PROC

    ;// destroys eax

    ASSUME ebp:PTR LIST_CONTEXT

        cmp ebp, bus_last_context   ;// same context ?
        jne have_to_load

    we_are_current:

        mov eax, [esp+4]
        dec eax
        shl eax, BUS_EDIT_RECORD_SHIFT
        add eax, bus_pTable

        mov [esp+4], eax

        ret

    have_to_load:

        pushad  ;// lazy!
        invoke bus_LoadContext
        popad   ;// but effective

        jmp we_are_current

bus_GetEditRecord ENDP

;//
;//     bus_GetEditRecord
;//
;////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////
;//
;//
;//     bus_GetName_from_pin    builds designator [Class.][Member]
;//
ASSUME_AND_ALIGN
bus_GetNameFromPin PROC uses esi edi

    ASSUME ebp:PTR LIST_CONTEXT ;// preserved
    ASSUME ebx:PTR APIN ;// preserved, must point at pin
    ASSUME edx:PTR BYTE ;// edx must be a destination iterator for the string
                        ;// edx will end up at the end of the string (nul terminator)

    ;// get the edit record

        mov esi, [ebx].dwStatus
        and esi, PIN_BUS_TEST
        DEBUG_IF <ZERO?>    ;// this pin is NOT a bus

        push esi
        invoke bus_GetEditRecord
        pop esi

    ;// get the string from the current bus_edit_table

        invoke bus_GetNameFromRecord

        ret

bus_GetNameFromPin ENDP
;//
;//     bus_GetName
;//
;//
;////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////
;//
;//
;//     bus_GetShape        call this to get the pin gdi
;//
;//     the purpose is to seperate the bus_edit table from the rest of the program
;//     since the shapes are always fixed, the context doesn't matter
;//     uses only eax

ASSUME_AND_ALIGN
bus_GetShape PROC

    ASSUME ebx:PTR APIN         ;// pin to set

    mov eax, [ebx].dwStatus         ;// get the status
    and eax, PIN_BUS_TEST           ;// strip out extra
    dec eax                         ;// decrease to zero based index
    shl eax, BUS_EDIT_RECORD_SHIFT  ;// shift to an offet
    add eax, bus_pTable             ;// turn into a pointer
    ASSUME eax:PTR BUS_EDIT_RECORD
    mov eax, [eax].pNameShape       ;// load the name shape
    mov [ebx].pBShape, eax          ;// store in pin

    ret

bus_GetShape ENDP

;//
;//     bus_GetShape
;//
;//
;////////////////////////////////////////////////////////////////////

;//////////////////////////////////////////////////////////////////////////////
;//                                                         PRIVATE
;// bus_load_strings        ACTION  [esi] --> bus_pTable
;//                                 table must be correct
;//

ASSUME_AND_ALIGN
bus_load_strings PROC USES ebp

    ;// this called from bus_LoadContext
    ;//                  bus_LoadFile
    ;//
    ;// the task is to load the bus strings into bus_pTable
    ;// if an item already exists (non zero text)
    ;//     then skip the source

    ;// destroys edi, ebx

        ASSUME esi:NOTHING  ;// esi must point at the string source table
                            ;// in the file save format described in abox_bus.inc

    ;// step 4: load the categories

        mov ebx, bus_pTable ;// point at table
        ASSUME ebx:PTR BUS_EDIT_RECORD
        lodsd           ;// get the length of this section
        add ebx, SIZEOF BUS_EDIT_RECORD ;// point ebx at next record
        sub eax, 4      ;// subtract the size of what we just read
        DEBUG_IF <SIGN?>
        jz done_with_categories ;// done if it's zero

        lea ebp, [esi+eax]      ;// ebp is when to stop
        xor eax, eax

        .REPEAT
            lodsb                   ;// get the length
            xor ecx, ecx            ;// clear for big_small
            lea edi, [ebx].cat_name ;// point at cat name
            ASSUME edi:PTR BYTE
            .IF ![edi]  ;// is cat name available ?
                mov cl, al              ;// xfer count to cl
                rep movsb               ;// mov the data
                xor eax, eax    ;// zero eax so we don't adjust esi
            .ENDIF
            add esi, eax        ;// if string was in use, then add the length to esi to get to the next string
            add ebx, SIZEOF BUS_EDIT_RECORD ;// point ebx at next record
        .UNTIL esi >= ebp
        xor eax, eax

    done_with_categories:

    ;// step 5: load and initialize the members

        lodsd               ;// get the count
        sub eax, 4          ;// subtract to get block size
        DEBUG_IF <SIGN?>
        jz done_with_members;// done if no member strings

        lea ebp, [esi+eax]  ;// set the stop pointer
        mov ebx, bus_pTable ;// point at table
        xor eax, eax

        .REPEAT

            DEBUG_IF < eax & 0FFFFFF00h >   ;// high bits are supposed to be clear !!

            lodsb               ;// get the index we want to put this at
            mov edi, eax        ;// start converting to offset
            xor eax, eax

            lodsb               ;// get the cat index
            mov edx, eax        ;// start converting to offset
            xor eax, eax

            lodsb               ;// get the count
            mov ecx, eax        ;// mov count to cl

            shl edi, BUS_EDIT_RECORD_SHIFT
            shl edx, BUS_EDIT_RECORD_SHIFT

            add edi, ebx    ;// point edi at where we want to store
            add edx, ebx    ;// point at the category to assign

            ASSUME edi:PTR BUS_EDIT_RECORD
            .IF ![edi].mem_name     ;// make sure not in use

                mov [edi].cat_pointer, edx  ;// store the category
                add edi, OFFSET BUS_EDIT_RECORD.mem_name    ;// point edi at dest string
                rep movsb       ;// copy the string
                xor eax, eax    ;// eax is either zero, or the size of the string block

            .ENDIF
            add esi, eax

        .UNTIL esi >= ebp

    done_with_members:

        ret

bus_load_strings ENDP

;//                                                         PRIVATE
;// bus_load_strings        ACTION  [esi] --> bus_pTable
;//                                 table must be correct
;//
;//////////////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////
;//
;//
;//     bus_LoadFile
;//
ASSUME_AND_ALIGN
bus_LoadFile    PROC

    ;// this is called from osc_Ctor
    ;// we want to return zero so ctor knows not to continue

    ASSUME ebx:PTR FILE_OSC
    ASSUME ebp:PTR LIST_CONTEXT

    ;// check first if we already have strings
    ;// if so, we want to merge new strings into the old table

    .IF ![ebp].pBusStrings

        mov eax, [ebx].extra
        add eax, 3
        and eax, -4

        invoke memory_Alloc, GPTR, eax  ;// allocate the table
        mov [ebp].pBusStrings, eax      ;// save in context
        mov edi, eax                    ;// destination
        lea esi, [ebx+SIZEOF FILE_OSC]  ;// source
        mov ecx, [ebx].extra            ;// num to copy

        rep movsb   ;// move it

    .ELSE
    ;// need to merge strings

    push ebx    ;// must preserve ebx

    ;// make sure context is correct

        .IF ebp != bus_last_context
            invoke bus_LoadContext
            mov ebx, [esp]  ;// ebx still on stack
        .ENDIF

    ;// call bus_load_strings to merge

        lea esi, [ebx+SIZEOF FILE_OSC]  ;// source
        invoke bus_load_strings

    ;// clean up and that's it

    pop ebx

    .ENDIF

    ;// that's it !

        xor eax, eax
        ret

bus_LoadFile    ENDP
;//
;//     bus_LoadFile
;//
;//
;////////////////////////////////////////////////////////////////////

;////////////////////////////////////////////////////////////////////
;//
;//
;//     bus_SaveFile
;//
ASSUME_AND_ALIGN
bus_SaveFile    PROC

        ASSUME ebp:PTR LIST_CONTEXT

        DEBUG_IF <!![ebp].pBusStrings>  ;// no strings, why are we calling ?
        DEBUG_IF <bus_table_is_dirty>   ;// add extra size should have cleared this

    ;// build the file osc header
.IF !context_bCopy      ;// ABOX232 oops, have to usurp this so we can paste inside groups
        mov eax, IDB_BUSTABLE
.ELSE
        mov eax, OFFSET osc_BusTable
.ENDIF
        stosd           ;// id
        xor eax, eax
        mov ecx, 3      ;// numpin, pos.x, pos.y
        rep stosd
        mov ebx, edi    ;// save &FILE_OSC.extra so we can set the size
        ASSUME ebx:PTR DWORD

    ;// store the table and set extra

        mov esi, [ebp].pBusStrings  ;// point at strings
        mov eax, DWORD PTR [esi]    ;// get the sizeof the categoy table
        stosd           ;// save the cat count in extra
        mov ecx, eax    ;// xfer size to count
        rep movsb       ;// store the whole thing

        mov eax, DWORD PTR [esi]    ;// get the sizeof the member table
        add [ebx], eax  ;// add to extra length
        mov ecx, eax    ;// xfer size to count
        rep movsb       ;// store the whole thing

    ;// that's it !

        ret

bus_SaveFile    ENDP
;//
;//     bus_SaveFile
;//
;//
;////////////////////////////////////////////////////////////////////

;////////////////////////////////////////////////////////////////////
;//
;//
;//     bus_AddExtraSize
;//
ASSUME_AND_ALIGN
bus_AddExtraSize    PROC

    ;// tasks:  determine the size needed to store the table the table
    ;//         accumulate this to [ebx]

    ASSUME ebx:PTR DWORD
    ASSUME ebp:PTR LIST_CONTEXT


    ;// make sure we are counting the correct thing

        .IF ebp == bus_last_context && bus_table_is_dirty

            push ebx
            invoke bus_SaveContext
            pop ebx

        .ENDIF

        DEBUG_IF <!![ebp].pBusStrings>  ;// no bus table !

    ;// build the size

        ASSUME ecx:PTR DWORD

        mov ecx, [ebp].pBusStrings
        mov eax, [ecx]  ;// get the cat table size
        add ecx, eax    ;// advance to member list
        add eax, [ecx]  ;// add the mem table size
        add [ebx], eax  ;// accumulate to ebx

    ;// that's it

        ret


bus_AddExtraSize    ENDP





;//
;//     bus_AddExtraSize
;//
;//
;////////////////////////////////////////////////////////////////////

;////////////////////////////////////////////////////////////////////
;//
;//
;//     bus_Clear
;//

ASSUME_AND_ALIGN
bus_Clear PROC uses edi esi ebx

        ASSUME ebp:PTR LIST_CONTEXT

    ;// reset the bus head array

        xor eax, eax
        mov ecx, NUM_BUSSES
        lea edi, [ebp].bus_table
        rep stosd

    ;// reset the category and member names

        bus_ResetTable PROTO    ;// forward reference
        invoke bus_ResetTable

    ;// make sure last context = 0

        mov bus_last_context, 0

    ;// delete the strings

        .IF [ebp].pBusStrings           ;// deallocate the strings
            invoke memory_Free, [ebp].pBusStrings
            mov [ebp].pBusStrings, eax
        .ENDIF

    ;// that's it

        ret

bus_Clear   ENDP

;//
;//
;//     bus_Clear
;//
;////////////////////////////////////////////////////////////////////






;////////////////////////////////////////////////////////////////////
;//
;//
;//     bus_Pull
;//

ASSUME_AND_ALIGN
bus_Pull    PROC uses esi edi

    ASSUME ebp:PTR LIST_CONTEXT
    ASSUME ebx:PTR APIN         ;// pin to center (destroyed)

    .IF !([ebx].dwStatus & PIN_OUTPUT)
        mov ebx, [ebx].pPin     ;// make sure ebx is the source
    .ENDIF

    mov edi, [ebx].pPin ;// edi is the next pin to process
    DEBUG_IF <!!edi>        ;// not connected !!

    fldz    ;// Y
    fldz    ;// X
    fld1    ;// iterator
    fldz    ;// counter

    ;// do the chain
    ;// only do an osc once

    top_of_average:

        PIN_TO_OSC ebx, esi

        .IF !([esi].dwHintOsc & HINTOSC_STATE_PROCESSED)

            fild [esi].rect.left    ;// x   n   1   X   Y
            faddp st(3), st         ;// n   1   X   Y
            fild [esi].rect.top     ;// y   n   1   X   Y
            faddp st(4), st         ;// n   1   X   Y
            fadd st, st(1)          ;// n+1 1   X   Y

            fild [esi].rect.right   ;// x   n   1   X   Y
            faddp st(3), st         ;// n   1   X   Y
            fild [esi].rect.bottom  ;// y   n   1   X   Y
            faddp st(4), st         ;// n   1   X   Y
            fadd st, st(1)          ;// n+1 1   X   Y

            or [esi].dwHintOsc, HINTOSC_STATE_PROCESSED

        .ENDIF

        or edi, edi
        jz done_with_average

        mov ebx, edi            ;// xfer to next pin
        mov edi, [ebx].pData    ;// get the next pin
        jmp top_of_average

    done_with_average:

    ;// compute the center

        fdiv
        fmul st(2), st
        fmul

    ;// call pin_ComputePhetaFromXY for all pins in the chain

        sub esp, 8

        ;// stack
        ;// X   Y   ...

        fstp DWORD PTR [esp]
        fstp DWORD PTR [esp+4]

        mov ebx, [ebx].pPin ;// get back to the start
        cmp unredo_pRecorder,0
        mov edi, [ebx].pPin
        jnz top_of_pheta_yes_record

    top_of_pheta_no_record:

        PIN_TO_OSC ebx, esi
        .IF [esi].dwHintOsc & HINTOSC_STATE_PROCESSED
            fld DWORD PTR [esp+4]
            fisub [esi].rect.top
            fld DWORD PTR [esp]
            fisub [esi].rect.left
            push edi
            invoke pin_ComputePhetaFromXY
            fstp [ebx].pheta
            pop edi
            GDI_INVALIDATE_PIN HINTI_PIN_PHETA_CHANGED
            and [esi].dwHintOsc, NOT HINTOSC_STATE_PROCESSED
        .ENDIF

        or edi, edi
        jz done_with_pheta

        mov ebx, edi
        mov edi, [ebx].pData

        jmp top_of_pheta_no_record

    top_of_pheta_yes_record:

        PIN_TO_OSC ebx, esi
        .IF [esi].dwHintOsc & HINTOSC_STATE_PROCESSED

            fld DWORD PTR [esp+4]
            fisub [esi].rect.top
            fld DWORD PTR [esp]
            fisub [esi].rect.left
            push edi

            mov eax, [ebx].pheta
            mov ecx, unredo_pRecorder
            ASSUME ecx:PTR UNREDO_PHETA ;// ecx is a pointer to UNREDO_PHETA
            mov [ecx].x, eax
            mov [ecx].id, esi
            mov [ecx].pin, ebx

            invoke pin_ComputePhetaFromXY

            mov ecx, unredo_pRecorder
            fst [ecx].y
            add ecx, 10h
            fstp [ebx].pheta
            mov unredo_pRecorder, ecx

            pop edi
            GDI_INVALIDATE_PIN HINTI_PIN_PHETA_CHANGED
            and [esi].dwHintOsc, NOT HINTOSC_STATE_PROCESSED

        .ENDIF

        or edi, edi
        jz done_with_pheta

        mov ebx, edi
        mov edi, [ebx].pData

        jmp top_of_pheta_yes_record

    done_with_pheta:

        add esp, 8

        ret

bus_Pull ENDP

;//
;//
;//     bus_Pull
;//
;////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////
;//
;//
;//     bus_Direct
;//

ASSUME_AND_ALIGN
bus_Direct  PROC    uses edi ebx

    ASSUME ebp:PTR LIST_CONTEXT
    ASSUME ebx:PTR APIN     ;// ebx must have the bus to convert

        xor edi, edi            ;// edi will be zero

        .IF !([ebx].dwStatus & PIN_OUTPUT)
            mov ebx, [ebx].pPin     ;// make sure ebx is the source
        .ENDIF

        ;// all we have to do is clear the bus record
        ;// and zero the bus indexes

        mov ecx, [ebx].dwStatus     ;// load the status
        and ecx, 0FFh               ;// strip out extra
        mov BUS_TABLE(ecx), edi     ;// free the head


        mov ecx, NOT PIN_BUS_TEST   ;// for clearing the status
        and [ebx].dwStatus, ecx     ;// clear the bus index
        GDI_INVALIDATE_PIN HINTI_PIN_CONNECTED  ;// invalidate the pin

        mov ebx, [ebx].pPin     ;// xfer first data pin to ebx
        .WHILE ebx
            and [ebx].dwStatus, ecx     ;// clear the bus index
            GDI_INVALIDATE_PIN HINTI_PIN_CONNECTED  ;// invalidate the pin
            mov ebx, [ebx].pData        ;// get the next pin
        .ENDW

        ret

bus_Direct ENDP

;//
;//
;//     bus_Direct
;//
;////////////////////////////////////////////////////////////////////



ASSUME_AND_ALIGN
bus_Create  PROC

    ASSUME ebx:PTR APIN
    ASSUME ecx:PTR BUS_EDIT_RECORD
    ASSUME ebp:PTR LIST_CONTEXT

    mov edx, [ecx].number       ;// load the index
    mov eax, [ecx].pNameShape   ;// get the shape
    mov [ebp].bus_table[edx*4-4], ebx   ;// set the new head
    mov [ebx].pBShape, eax      ;// set the shape
    xor eax, eax                ;// zero for storing
    or [ebx].dwStatus, edx      ;// merge on to the status

    GDI_INVALIDATE_PIN HINTI_PIN_CONNECTED  ;// invalidate it

    ret

bus_Create  ENDP

ASSUME_AND_ALIGN
bus_Rename  PROC uses esi edi ebx

    ASSUME ebx:PTR APIN
    ASSUME ecx:PTR BUS_EDIT_RECORD
    ASSUME ebp:PTR LIST_CONTEXT

    xor eax, eax                ;// clear for zeroing

    mov edx, [ebx].dwStatus     ;// get the pin status
    mov esi, [ecx].pNameShape   ;// get the shape from the new head
    and edx, 0FFh               ;// mask out extra
    mov ecx, [ecx].number       ;// load the index from the table
    mov BUS_TABLE(edx), eax     ;// reset the old head
    mov edi, [ebx].pPin         ;// edi will iterate to the next pin
    mov BUS_TABLE(ecx), ebx     ;// set the new head

    jmp @F                      ;// jump into loop

;// setup the rest

    .REPEAT

        mov ebx, edi                ;// xfer next to now
        mov edi, [ebx].pData        ;// get next
    @@:
        GDI_INVALIDATE_PIN HINTI_PIN_CONNECTED  ;// invalidate this
        and [ebx].dwStatus, NOT PIN_BUS_TEST    ;// strip out old index
        mov [ebx].pBShape, esi      ;// set the new shape
        or [ebx].dwStatus, ecx      ;// set the new index

    .UNTIL !edi

    ret

bus_Rename  ENDP


ASSUME_AND_ALIGN
bus_Transfer PROC uses edi ebx

    ASSUME ebx:PTR APIN
    ASSUME ecx:PTR BUS_EDIT_RECORD
    ASSUME ebp:PTR LIST_CONTEXT

    mov edi, [ecx].number   ;// ecx  will be trashed shortly
    mov edi, BUS_TABLE(edi)

    ENTER_PLAY_SYNC GUI

    invoke pin_Unconnect
    xchg edi, ebx
    invoke pin_connect_UI_CO

    or [ebp].pFlags, PFLAG_TRACE

    invoke context_SetAutoTrace         ;// schedule a unit trace

    LEAVE_PLAY_SYNC GUI

    ret

bus_Transfer ENDP


ASSUME_AND_ALIGN
bus_ConvertTo PROC uses esi edi ebx

    ASSUME ebx:PTR APIN
    ASSUME ecx:PTR BUS_EDIT_RECORD
    ASSUME ebp:PTR LIST_CONTEXT


    ;// tasks:
    ;//     assign the bus head to the output pin
    ;//     for all pins in the chain
    ;//         set the bus index
    ;//         set the bus shape
    ;//         reset the jump index
    ;// play_wait is not required

    ;// get the source pin
    ;// build the index
    ;// get the name shape
    ;// attach the source to the bus head
    ;// setup the head of the list


        mov esi, [ecx].number           ;// esi is the bus index

        test [ebx].dwStatus, PIN_OUTPUT ;// check if output pin

        mov edi, [ecx].pNameShape       ;// load the name shape

        jnz @F
            mov ebx, [ebx].pPin         ;// get the real head
    @@:

        mov BUS_TABLE(esi), ebx     ;// set the bus head

        xor ecx, ecx                    ;// clear for zeroing

        mov [ebx].pBShape, edi          ;// store the bus shape

        or [ebx].dwStatus, esi          ;// mask in the index

        GDI_INVALIDATE_PIN HINTI_PIN_CONNECTED  ;// invalidate as connected

        mov edx, [ebx].pPin             ;// get the first pin in the chain

    ;// update all destination pins in the chain

        .WHILE edx

            mov ebx, edx                ;// iterate the pin pointer
            GDI_INVALIDATE_PIN HINTI_PIN_CONNECTED  ;// invalidate as connected
            or [ebx].dwStatus, esi      ;// mask in the index
            mov edx, [ebx].pData        ;// get the next in chain
            mov [ebx].pBShape, edi      ;// store the bus shape

        .ENDW

    ;// that should do it

        ret


bus_ConvertTo ENDP



;////
;////                       bus_Show        launches the dialog panel
;////   APP LEVEL           bus_GetName     builds the long name of the bus
;////   UTILTY FUNCTIONS    bus_GetShape    retrieves the gdi pointer for the bus
;////
;////                       bus_LoadFile    loads string from a file
;////                       bus_SaveFile    saves to a file
;////                       bus_AddExtraSize    determines the size of the bus string block
;////
;////                       bus_Clear       erases the bus table
;////
;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////









;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////
;////
;////
;////   LOCAL
;////   BUS UTILTY FUNCTIONS
;////



ASSUME_AND_ALIGN
bus_ResetTable  PROC

    ;// this makes sure that the bus_pTable is in it's default state
    ;// uses edi, ebx

    ;// clear the bus edit records

        mov edi, bus_pTable ;// get the bus table
        mov ebx, bus_pEnd   ;// ebx tells us when to stop

    ;// rip hrough the table and reset all the names

        xor eax, eax        ;// eax will clear the names
        mov edx, edi        ;// edx will be default category

        ASSUME edi:PTR BUS_EDIT_RECORD

    L1: mov [edi].cat_pointer, edx  ;// reset to default
        lea edi, [edi].mem_name     ;// point at member name
        mov ecx, (32*2)/4           ;// two 32 byte strings stored as dwords
        rep stosd                   ;// clear the strings
        cmp edi, ebx                ;// done yet ?
        jb L1           ;// mem and cat are the last items
                        ;// so iteration really is this simple

    ;// make sure the first record says dot

        mov edi, bus_pTable ;// get the bus table
        mov WORD PTR [edi].cat_name, '.'

    ;// set the flags so the list boxes get reinitialized

        or dlg_mode, DM_CAT_INIT
        ;// or cat_cursel, -1

    ;// that's it

        ret

bus_ResetTable ENDP





;////////////////////////////////////////////////////////////////////
;//
;//                         ACTION: bus_pString -> bus_pTable
;//     bus_LoadContext
;//
ASSUME_AND_ALIGN
bus_LoadContext PROC

    ASSUME ebp:PTR LIST_CONTEXT ;// ebp must point at the list context to load

    ;// destroyes esi, edi, ebx

;// task:   save the old context if this one is dirty
;//         load the new context by filling in the bus edit records
;//         at the very least, make sure all the records are initialized

    ;// step 1: check if this context is dirty

        .IF bus_table_is_dirty && ebp != bus_last_context && bus_last_context
            push ebp
            mov ebp, bus_last_context
            invoke bus_SaveContext
            pop ebp
        .ENDIF

    ;// step 2: clear the current context

        invoke bus_ResetTable

    ;// step 3: make sure there are strings to load

        xor esi, esi
        or esi, [ebp].pBusStrings   ;// load and test the strings pointer
        jz all_done

    ;// step 4,5: load the strings

        invoke bus_load_strings

    ;// step 6: store the new last context and make sure the selection is cleared
    all_done:

        or dlg_mode, DM_CAT_INIT    ;// make sure cat_list reinitializes
        mov bus_last_context, ebp   ;// store the context pointer

        ret

bus_LoadContext ENDP
;//
;//
;//     bus_LoadContext
;//
;////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////
;//
;//                                 action: compact bus_pTable.cat_names
;//     bus_CompactCategories
;//

ASSUME_AND_ALIGN
bus_CompactCategories PROC  uses ebp

    ;// uses esi, edi, ebx

    ;// we need to do this because the categories may not be adjacent in bus_pTable
    ;// this happens due to editing operations

    ;// we have to compact before we save a table
    ;// this also requires resetting the list boxes

    ;// tasks:  look for uncompacted entries
    ;//         when found
    ;//             xfer cat_name to adjacent category
    ;//             look for matching pointers and replace with new
    ;//             tag the dialog for init


    ;// 1) locate the first unused cat_name record

        ASSUME ebx:PTR BUS_EDIT_RECORD

        mov ebx, bus_pTable     ;// ebx tracks LastEmpty
        mov ebp, bus_pEnd       ;// ebp will be the stop pointer
        xor eax, eax

    J1: cmp [ebx].cat_name, al  ;// category used ?
        je J2                   ;// done if yes
        add ebx,SIZEOF BUS_EDIT_RECORD  ;// next edit record
        cmp ebx, ebp            ;// at end of table ?
        jae all_done            ;// nothing to compact
        jmp J1                  ;// continue on
    J2:

    ;// 2) scan and locate a used cat_name

        ASSUME edx:PTR BUS_EDIT_RECORD

        lea edx, [ebx+SIZEOF BUS_EDIT_RECORD]

    J3: cmp edx, ebp            ;// at end of table ?
        jae all_done            ;// done if so
    K3: cmp [edx].cat_name, al  ;// category used ?
        jne compact_this        ;// jmp to compactor if used
        add edx, SIZEOF BUS_EDIT_RECORD
        jmp J3

    compact_this:

        DEBUG_IF <1>    ;// not tested

        ;// make sure cat_list reinitializes

        or dlg_mode, DM_CAT_INIT

    ;// change the cat pointers

        ASSUME esi:PTR BUS_EDIT_RECORD

        mov esi, bus_pTable

    J4: cmp [esi].cat_pointer, edx  ;// is this about to be changed ?
        jne J5
        mov [esi].cat_pointer, ebx  ;// set as new cat_pointer
    J5: add esi, SIZEOF BUS_EDIT_RECORD
        cmp esi, ebp                ;// end of table ?
        jb J4                       ;// continue on if not

    ;// copy the string to new location

        lea esi, [edx].cat_name
        lea edi, [ebx].cat_name
        mov ecx, 32/4
        rep movsd       ;// edi is now at the next unused record

    ;// clear the name we just reset

        lea edi, [edx].cat_name
        xor eax, eax
        mov ecx, 32/4
        rep movsd       ;// esi at at he next record to test

    ;// update the iterators

        mov edx, esi    ;// next record to test
        mov ebx, edi    ;// LastUnused
        cmp edx, ebp    ;// at end of table ?
        jb K3           ;// done if so

    all_done:

        ret

bus_CompactCategories ENDP


;////////////////////////////////////////////////////////////////////
;//
;//                         ACTION: bus_pTable -> bus_pString
;//     bus_SaveContext             reset dirty
;//
ASSUME_AND_ALIGN
bus_SaveContext PROC

    ;// uses esi edi ebx

    ;// to make matters worse, we have to save to bus_last_context

    ASSUME ebp:PTR LIST_CONTEXT

    ;// tasks
    ;//
    ;// determine how much room we need
    ;// allocate that room
    ;// store all the category string in the list box
    ;// store all the defined member names
    ;// replace and deallocate the the context pointer
    ;// reset the dirty flag

    ;// we also have to compact the list
    ;// since we are about to save, this is the spot to do it

        invoke bus_CompactCategories

    ;// deallocate old table

        .IF [ebp].pBusStrings   ;// old memory ?
            invoke memory_Free, [ebp].pBusStrings   ;// clear it now
        .ENDIF

    ;// determine the memory needed to store the table

        mov ebx, 8          ;// use for size (will always have 2 dwords
        xor eax, eax        ;// clear for big small test

        ASSUME esi:PTR BUS_EDIT_RECORD

        ;// SIZEOF CATEGORY STRINGS

        mov esi,bus_pTable  ;// esi iterates the table
        add esi, SIZEOF BUS_EDIT_RECORD
        .REPEAT

            cmp [esi].cat_name[0],0 ;// cat assigned ?
            je S1                   ;// cat's are stored in adjacent order
                                    ;// so if empty, we're done

            lea edi, [esi].cat_name ;// point at string
            add ebx, 1 + 32         ;// length plus extra minus adjust for scasb
            mov ecx, 32             ;// ammount to count
            repne scasb             ;// strlen
            sub ebx, ecx            ;// subtract offset to get length we need

            add esi, SIZEOF BUS_EDIT_RECORD

        .UNTIL esi >= bus_pEnd

    S1:

        ;// SIZEOF MEMBER STRINGS

        mov esi,bus_pTable  ;// esi iterates the table
        mov edx, esi        ;// store default category for testing
        .REPEAT

            cmp [esi].mem_name[0], 0    ;// check if there's a string assigned
            jnz Q1                      ;// jump if character had something in it
            ;// the string is empty, let's see if the category is assigned
            cmp edx, [esi].cat_pointer  ;// is the category different ?
            je Q2                       ;// jump if theye're the same
            ;// have a unique string
        Q1:     lea edi, [esi].mem_name ;// point at string
                add ebx, 3 + 32         ;// length plus extra minus adjust for scasb
                mov ecx, 32             ;// ammount to count
                repne scasb             ;// strlen
                sub ebx, ecx            ;// subtract offset to get the string length we need

        Q2: add esi, SIZEOF BUS_EDIT_RECORD

        .UNTIL esi >= bus_pEnd


    ;// allocate the new table

        add ebx, 3
        and ebx, -4
        invoke memory_Alloc, GPTR, ebx
        mov [ebp].pBusStrings, eax  ;// store the new pointer

    ;// compact the table
    ;// since we can only store cat's as adjacent, we have to
    ;// scrunch all the categories together
    ;// the categories may have gotten un-adjacent due to editing opeartions
    comment ~ /*

        we have to set the pointer correctly
        and transfer the strings
        since we may be doing this via a file_save command
        we also have to tell the list boxes to update

    */ comment ~


    ;// FIRST SCAN: store the CATEGORY table

        lea edi, [eax+4]

        ;//xor eax, eax ;// start with zero size
        ;//stosd            ;// always store the size


        mov ebx, bus_pTable
        ASSUME ebx:PTR BUS_EDIT_RECORD  ;// ebx iterates bus edit records
        add ebx, SIZEOF BUS_EDIT_RECORD ;// start at second record

        .REPEAT ;// scan the BUS_EDIT_RECORD table

            cmp [ebx].cat_name[0], 0    ;// cat assigned ?
            je S2                       ;// cat's are stored in adjacent order
                                        ;// so if empty, we're done

            lea esi, [ebx].cat_name[0]  ;// point at string
            mov edx, edi                ;// store so we can set the size
            inc edi                     ;// store at next spot
            STRCPY_SD TERMINATE, LEN, ecx   ;// copy the string

            mov BYTE PTR [edx], cl  ;// store the string length

            add ebx, SIZEOF BUS_EDIT_RECORD

        .UNTIL ebx >= bus_pEnd

    S2:
        xor eax, eax
        mov eax, [ebp].pBusStrings  ;// get the source pointer
        mov edx, eax
        sub eax, edi                ;// neg length
        sub [edx],eax               ;// subtract from zero to make positive

    ;// SECOND SCAN: store the MEMBER table

        xor eax, eax
        push edi    ;// store on stack so we can set the size
        add edi, 4  ;// skip count for a moment
        ;// stosd   ;// always store the count
        mov ebx, bus_pTable

        .REPEAT

            mov edx, [ebx].cat_pointer  ;// get the category pointer

            cmp [ebx].mem_name[0], 0    ;// is there a member string ?
            jne R1                      ;// have to store if so
            cmp edx, bus_pTable         ;// no member string, see if category is assigned
            je R2                       ;// if category is same, then we skip

        R1:     ;// get and store the bus index

                mov al, BYTE PTR [ebx].number   ;// get the number
                dec al                  ;// turn number into index
                stosb                   ;// store the bus index

                ;// get and store the category index

                mov al, BYTE PTR (BUS_EDIT_RECORD PTR [edx]).number ;// get the cat number
                dec al                  ;// turn number into index
                stosb                   ;// store the cat_index

                ;// copy the name and set the length

                lea esi, [ebx].mem_name ;// point at string
                mov edx, edi            ;// store so we can set the size
                inc edi                 ;// store at next spot

                STRCPY_SD TERMINATE, LEN, ecx   ;// copy the string

                mov BYTE PTR [edx], cl  ;// store the length

        R2: add ebx, SIZEOF BUS_EDIT_RECORD

        .UNTIL ebx >= bus_pEnd

        pop eax     ;// retrieve the ofs end pointer

        mov edx, eax
        sub eax, edi    ;// neg length
        sub [edx],eax   ;// subtract from zero to make positive

    ;// that's it

        mov bus_table_is_dirty, 0

        ret

bus_SaveContext ENDP
;//
;//     bus_SaveContext
;//
;//
;////////////////////////////////////////////////////////////////////





ASSUME_AND_ALIGN
bus_GetNameFromRecord PROC PRIVATE

    ASSUME esi:PTR BUS_EDIT_RECORD  ;// esi must point at the bus record
    ASSUME edx:PTR BYTE             ;// edx must be a destination iterator for the string
                                    ;// edx will end up at the end of the string (nul terminator)

    ;// xfer the header and designator

        mov DWORD PTR [edx], ' sub' ;// store "Bus "
        mov ecx, [esi].pNameShape   ;// get the name shape from the bus
        ASSUME ecx:PTR GDI_SHAPE
        add edx, 4                  ;// advance edx
        mov eax, [ecx].character    ;// load the character from the shape
        or eax, 00200000h           ;// merge in a space
        xor ecx, ecx                ;// clear for next tests
        mov DWORD PTR [edx], eax    ;// store the designator
        add edx, 3                  ;// advance edx

    ;// xfer the category

        or ecx, [esi].cat_pointer   ;// load and test the category pointer
        jz done_with_category       ;// jump if no category is assigned

        ASSUME ecx:PTR BUS_EDIT_RECORD
        lea ecx, [ecx].cat_name     ;// load the name
        STRCPY edx, ecx             ;// copy the string
        mov [edx], '.'              ;// add a dot
        inc edx                     ;// advance edx

    done_with_category:

    ;// xfer the member name

        lea ecx, [esi].mem_name
        .IF (BYTE PTR [ecx])        ;// is there a string here ?

            STRCPY edx, ecx         ;// copy the string

        .ELSE                       ;// no string, tack on the bus name

            mov ecx, [esi].pNameShape   ;// get the name shape from the bus
            ASSUME ecx:PTR GDI_SHAPE
            mov eax, [ecx].character    ;// load the character from the shape
            mov DWORD PTR [edx], eax    ;// store the designator
            add edx, 2                  ;// advance edx

        .ENDIF


    ;// that's it

        ret

bus_GetNameFromRecord ENDP



;////
;////   LOCAL
;////   BUS UTILTY FUNCTIONS
;////
;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////




ASSUME_AND_ALIGN
bus_UpdateUndoRedo PROC

    mov eax, unredo_pCurrent
    sub eax, dlist_Head(unredo)
    setnz al    ;// make sure the lowest bit is set

    invoke EnableWindow,hWnd_bus_undo, eax

    mov eax, unredo_pCurrent
    sub eax, dlist_Tail(unredo)
    setnz al    ;// make sure the lowest bit is set

    invoke EnableWindow,hWnd_bus_redo, eax

    ret

bus_UpdateUndoRedo ENDP




;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////
;////                       this is the top level dialog proc
;////       bus_Proc
;////
ASSUME_AND_ALIGN
bus_Proc    PROC PRIVATE

    mov eax, WP_MSG

    HANDLE_WM WM_SETCURSOR,     bus_wm_setcursor_proc

    HANDLE_WM WM_DRAWITEM,      catmem_wm_drawitem_proc
    HANDLE_WM WM_MEASUREITEM,   catmem_wm_measureitem_proc
    HANDLE_WM WM_COMPAREITEM,   catmem_wm_compareitem_proc

    HANDLE_WM WM_COMMAND,       bus_wm_command_proc
    HANDLE_WM WM_KEYDOWN,       bus_wm_keydown_proc

    HANDLE_WM WM_ACTIVATE,      bus_wm_activate_proc
    HANDLE_WM WM_CLOSE,         bus_wm_close_proc
    HANDLE_WM WM_CREATE,        bus_wm_create_proc
    HANDLE_WM WM_DESTROY,       bus_wm_destroy_proc

    jmp DefWindowProcA

bus_Proc    ENDP

;//     exit points
;//
;//     these two exit points serves as both a btb helper
;//     and make sure that the bus hWnd maintains the focus
ASSUME_AND_ALIGN
bus_Proc_exit_focus::

    invoke SetFocus, bus_hWnd

bus_Proc_exit_zero::

    invoke app_Sync

    xor eax, eax

bus_Proc_exit_now::

    ret 10h

ASSUME_AND_ALIGN
bus_Proc_exit_loose_focus::

    invoke SetFocus, hMainWnd
    jmp bus_Proc_exit_zero

;////
;////       bus_Proc
;////
;////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
bus_wm_setcursor_proc PROC

    ;// this is where we set the status message for controls that are not the grid

    ;// the rule is:
    ;//
    ;//     if gwl_user is zero, we reset the status text
    ;//     if gwl_user is one, we do not reset, the status text (grid will do this)
    ;//     if gwl_user > one, we set a new status text and update
    ;//     if gwl_user == -1 then we want an undo string
    ;//     if gwl_user == -2 then we want a redo string

    mov eax, WP_WPARAM                      ;// load the hWnd with the cursor
    invoke GetWindowLongA, eax, GWL_USERDATA;// get the string pointer
    .IF eax

        DEBUG_IF <eax==1>   ;// is this ever hit ?

        .IF eax != bus_last_status

            mov bus_last_status, eax

            or eax, eax
            .IF !SIGN?
                WINDOW hWnd_bus_status, WM_SETTEXT,0,eax    ;// set the text
            .ELSE
                sub esp, 64
                inc eax
                .IF ZERO?       ;// undo string
                    invoke unredo_GetUndoString, esp
                .ELSE           ;// redo string
                    invoke unredo_GetRedoString, esp
                .ENDIF

                WINDOW hWnd_bus_status, WM_SETTEXT,0,esp    ;// set the text
                add esp, 64

            .ENDIF

        .ENDIF

    .ELSEIF eax != bus_last_status

        mov bus_last_status, eax
        pushd eax
        WINDOW hWnd_bus_status, WM_SETTEXT,0,esp    ;// reset the text
        add esp, 4

    .ENDIF

    jmp DefWindowProcA

bus_wm_setcursor_proc ENDP










;////////////////////////////////////////////////////////////////////
;//
;//     WM_ACTIVATE
;//
;//     fActive = LOWORD(wParam);           // activation flag
;//     fMinimized = (BOOL) HIWORD(wParam); // minimized flag
;//     hwndPrevious = (HWND) lParam;       // window handle
;//
ASSUME_AND_ALIGN
bus_wm_activate_proc PROC PRIVATE

    cmp WORD PTR WP_WPARAM, WA_INACTIVE ;// on or off ??
    jz bus_wm_close_proc                ;// off, jump to close proc

    mov eax, dlg_mode           ;// get the old mode
    shr al, 1                   ;// turn viewing into view

    or app_DlgFlags, DLG_BUS    ;// on, make sure the app knows it
    mov dlg_mode, eax           ;// store back in mode

    call bus_Activate           ;// call central function to activate

    jmp bus_Proc_exit_zero

bus_wm_activate_proc ENDP
;//
;//     WM_ACTIVATE
;//
;//
;////////////////////////////////////////////////////////////////////




;////////////////////////////////////////////////////////////////////
;//
;//                         makes sure the correct panel is displayed
;//     bus_Activate        called from WM_ACTIVE, and WM_COMMAND
;//

ASSUME_AND_ALIGN
bus_Activate PROC PRIVATE

    ;// first make the view and viewing flags match
    ;// if they already do, then exit

;// this handler must account for two classes of actions
;//
;// 1) initialization, where the dialog is being displayed
;// 2) changing from one view to another
;//
;// 1) activation, shuts off the viewing flag, and uses the view flag for a command
;// 2) changing just uses the view flag as a command

;// check for commands first

    btr dlg_mode, LOG2(DM_VIEW_LIST)        ;// test and rest the veiw list command bit
    .IF CARRY?

        btr dlg_mode, LOG2(DM_VIEWING_GRID) ;// were we viewing the grid ?
        .IF CARRY?
            invoke ShowWindow, grid_hWnd, SW_HIDE   ;// hide the grid
        .ENDIF

        bts dlg_mode, LOG2(DM_VIEWING_LIST) ;// was the list already on ?
        invoke ShowWindow, cat_hWnd, SW_SHOW    ;// show the list

        ;// check if we're supposed to initialize

        btr dlg_mode, LOG2(DM_CAT_INIT)
        jnc J1
        or cat_cursel, -1
        LISTBOX cat_hWnd, LB_RESETCONTENT
        invoke catmem_Update
        push ebp
        push ebx
        stack_Peek gui_context, ebp
        invoke catmem_LocateBusPin
        pop ebx
        pop ebp
    J1:
        jmp bus_UpdateUndoRedo
        ;// ret

    .ENDIF

    btr dlg_mode, LOG2( DM_VIEW_GRID )  ;// test and reset the view list command bit
    .IF CARRY?

        or dlg_mode, DM_GRID_INIT   ;// make sure grid knows it needs to be initialized

        btr dlg_mode, LOG2( DM_VIEWING_LIST )   ;// were we viewing the list ?
        .IF CARRY?
            invoke ShowWindow, cat_hWnd, SW_HIDE    ;// hide the list
        .ENDIF

        bts dlg_mode, LOG2( DM_VIEWING_GRID )   ;// were we already viewing the grid ?
        invoke ShowWindow, grid_hWnd, SW_SHOW   ;// show the grid

    .ENDIF

    mov bus_last_status, 7FFFFFFFh

    jmp bus_UpdateUndoRedo
    ;// ret

bus_Activate ENDP






;////////////////////////////////////////////////////////////////////
;//
;//     WM_KEYDOWN                      trap for the escape key
;//     nVirtKey = (int) wParam;        and undo redo
;//     lKeyData = lParam;
;//
ASSUME_AND_ALIGN
bus_wm_keydown_proc PROC PRIVATE


    cmp WP_WPARAM, VK_ESCAPE
    jnz @F  ;// bus_wm_close_proc

    invoke SetFocus, hMainWnd
    jmp DefWindowProcA

@@: invoke GetAsyncKeyState, VK_CONTROL
    test eax, 8000h
    jnz @F

    jmp DefWindowProcA

@@: cmp WP_WPARAM, 'Z'
    jne @F

    mov ecx, IDC_BUS_UNDO OR (BN_CLICKED SHL 16 )
    mov edx, hWnd_bus_undo
    jmp check_enabled

@@: cmp WP_WPARAM, 'Y'
    jne @F

    mov ecx, IDC_BUS_REDO OR (BN_CLICKED SHL 16 )
    mov edx, hWnd_bus_redo
    jmp check_enabled

@@: jmp DefWindowProcA


check_enabled:

    ;// first make sure the said button is enabled

    push edx
    push ecx

    invoke IsWindowEnabled, edx
    .IF !eax

        add esp, 8
        jmp DefWindowProcA

    .ENDIF

    pushd WM_COMMAND
    push bus_hWnd
    call PostMessageA

    jmp DefWindowProcA

bus_wm_keydown_proc ENDP
;//
;//     WM_KEYDOWN
;//
;//
;////////////////////////////////////////////////////////////////////





;////////////////////////////////////////////////////////////////////
;//
;//
;//     WM_COMMAND
;//     wNotifyCode = HIWORD(wParam); // notification code
;//     wID = LOWORD(wParam);         // item, control, or accelerator identifier
;//     hwndCtl = (HWND) lParam;      // handle of control
;//
ASSUME_AND_ALIGN
bus_wm_command_proc PROC PRIVATE    ;// STDCALL hWnd, msg, wParam, lParam

    ;// see if we want to handle this

        movzx edx, WP_WPARAM_HI     ;// get the command type

        cmp edx, BN_CLICKED         ;// button clicked ?
        jz bus_button_clicked_proc

        cmp edx, LBN_DBLCLK         ;// list dbl_click ??
        jz catmem_wm_dblclk_proc

        jmp bus_Proc_exit_zero      ;// ignore


    bus_button_clicked_proc:
    ;////////////////////////////////////////////////////////////////////
    ;//
    ;//     BN_CLICKED
    ;//     idButton = (int) LOWORD(wParam);    // identifier of button
    ;//     hwndButton = (HWND) lParam;         // handle of button
    ;//
        ;// which button ?

            movzx eax, WP_WPARAM_LO

        ;// view commands               ( handled below )

            cmp eax, IDC_BUS_SHOWBUSSES
            jz view_grid_proc
            cmp eax, IDC_BUS_SHOWNAMES
            jz view_list_proc

        ;// grid connection commands    (defined in bus_grid.asm)

            cmp eax, IDC_BUS_UNCONNECT
            jz grid_unconnect_proc
            cmp eax, IDC_BUS_DIRECT
            jz grid_direct_proc
            cmp eax, IDC_BUS_PULL
            jz grid_pull_proc

        ;// list managment              (defined in bus_catmem.asm)

            cmp eax, IDC_BUS_ADD_CAT
            jz cat_Insert_proc
            cmp eax, IDC_BUS_DEL_CAT
            jz cat_Delete_proc

            cmp eax, IDC_BUS_SORT_NAME
            jz mem_sortName_proc
            cmp eax, IDC_BUS_SORT_NUMBER
            jz mem_sortNumber_proc

        ;// undo redo

            cmp eax, IDC_BUS_UNDO
            je bus_Undo_proc
            cmp eax, IDC_BUS_REDO
            je bus_Redo_proc

        ;// bad

        ;// DEBUG_IF <1>        ;// unknown button ???!!!!

            jmp bus_Proc_exit_zero      ;// ignore


        ;///////////////////////////
        ;//     view selection
        ;//
        view_grid_proc:

            or dlg_mode, DM_VIEW_GRID
            invoke bus_Activate
            jmp bus_Proc_exit_focus

        view_list_proc:

            or dlg_mode, DM_VIEW_LIST
            invoke bus_Activate
            jmp bus_Proc_exit_focus
        ;//
        ;//     view selection
        ;///////////////////////////



        ;///////////////////////////
        ;//
        ;//
        ;//     list mangament
        ;//
        cat_Insert_proc:

            unredo_BeginAction UNREDO_BUS_CATINS    ;// edit kill focus will end the action

            invoke catmem_AddCat, 0, 0
            jmp bus_Proc_exit_zero

        cat_Delete_proc:

            unredo_BeginAction UNREDO_BUS_CATDEL

            LISTBOX cat_hWnd, LB_GETITEMDATA, cat_cursel
            invoke catmem_DelCat, eax

            unredo_EndAction UNREDO_BUS_CATDEL

            invoke bus_UpdateUndoRedo

            jmp bus_Proc_exit_zero

        mem_sortName_proc:

            bts dlg_mode, LOG2(DM_SORT_NAMES)
            jmp mem_sort_update_and_exit

        mem_sortNumber_proc:

            btr dlg_mode, LOG2(DM_SORT_NAMES)

        mem_sort_update_and_exit:

            or cat_cursel, -1
            invoke catmem_Update
            jmp bus_Proc_exit_focus
        ;//
        ;//
        ;//     list mangament
        ;//
        ;///////////////////////////


        ;///////////////////////////
        ;//
        ;//     undo redo
        ;//
        ;//
        bus_Undo_proc:

            invoke unredo_Undo
            mov ecx, unredo_pCurrent    ;// save action after undo
            jmp bus_unredo_update

        bus_Redo_proc:

            push unredo_pCurrent    ;// save action before redo
            invoke unredo_Redo
            pop ecx

        bus_unredo_update:

            ;// determine how to update by looking at the action we just did

            mov ecx, (UNREDO_NODE PTR [ecx]).action

            ;// make sure the actio involves a bus

            cmp ecx, UNREDO_BUS_MINIMUM
            jb bus_Proc_exit_loose_focus
            cmp ecx, UNREDO_BUS_MAXIMUM
            ja bus_Proc_exit_loose_focus

            .IF ecx < UNREDO_BUS_CATCAT

                ;// should be showing the grid view
                bts dlg_mode, LOG2(DM_VIEW_GRID)
                invoke CheckDlgButton, bus_hWnd, IDC_BUS_SHOWBUSSES, BST_CHECKED
                invoke CheckDlgButton, bus_hWnd, IDC_BUS_SHOWNAMES, BST_UNCHECKED

            .ELSE

                ;// should be showing the list view
                bts dlg_mode, LOG2(DM_VIEW_LIST)
                invoke CheckDlgButton, bus_hWnd, IDC_BUS_SHOWBUSSES, BST_UNCHECKED
                invoke CheckDlgButton, bus_hWnd, IDC_BUS_SHOWNAMES, BST_CHECKED

            .ENDIF

            invoke bus_Activate ;// cal the activater
            invoke InvalidateRect, bus_hWnd, 0, 0

            jmp bus_Proc_exit_focus

        ;//
        ;//     undo redo
        ;//
        ;//
        ;///////////////////////////

    ;//
    ;//
    ;// button clicked proc
    ;//
    ;////////////////////////////////////////////////////////////////////

bus_wm_command_proc ENDP
;//
;//     WM_COMMAND
;//
;//
;////////////////////////////////////////////////////////////////////








;////////////////////////////////////////////////////////////////////
;//
;//
;//     WM_CLOSE
;//
ASSUME_AND_ALIGN
bus_wm_close_proc PROC PRIVATE

    ;// always check if the cursor needs unclipped

    btr dlg_mode, LOG2(DM_CAT_CAPTURE)
    jnc @F
    invoke ReleaseCapture
    and dlg_mode, NOT ( DM_CAT_DRAG_DROP_TEST OR DM_CAT_CLEANUP_TEST )
@@:
    invoke ShowWindow, bus_hWnd, SW_HIDE
    and app_DlgFlags, NOT DLG_BUS

;// invoke SetFocus, hMainWnd   <-- don't do this !!! causes a stack fault

    jmp bus_Proc_exit_zero

bus_wm_close_proc ENDP
;//
;//     WM_CLOSE
;//
;//
;////////////////////////////////////////////////////////////////////








;////////////////////////////////////////////////////////////////////
;//
;//                     jumped to from bus_Proc
;//     WM_CREATE       this only gets called once, so we just return
;//
ASSUME_AND_ALIGN
bus_wm_create_proc PROC STDCALL PRIVATE uses esi edi ebx hWnd:DWORD, msg:DWORD, wParam:DWORD, lParam:DWORD

    ;// store the window handle

        mov eax, hWnd
        mov bus_hWnd, eax

    ;// call popup_Build

        invoke popup_BuildControls, hWnd, OFFSET popup_BUS, 0, 0    ;// no help

    ;// determine the proper non-client size

        xor ecx, ecx
        point_CopyTo popup_BUS.siz, bus_siz
        point_Set bus_pos, ecx, ecx
        invoke AdjustWindowRectEx, OFFSET bus_pos, POPUP_STYLE, 0, POPUP_STYLE_EX
        point_Get bus_siz
        point_Sub bus_pos
        point_Set bus_siz

    ;// allocate the bus table and temp string

        invoke memory_Alloc, GPTR, (NUM_BUSSES+1)*(SIZEOF BUS_EDIT_RECORD)
        mov bus_pTable, eax         ;// store the pointer
        lea edx, [eax+(NUM_BUSSES)*(SIZEOF BUS_EDIT_RECORD)]
        mov bus_pString, edx        ;// last records is used for temp strings

    ;// initialize the bus_numbers and bus_names

        ;// bus numbers first

            mov esi, bus_pEnd   ;// esi iterates backwards
            mov edi, bus_pTable ;// edi is when to stop
            mov ecx, NUM_BUSSES ;// ecx sets the bus number

            ASSUME esi:PTR BUS_EDIT_RECORD  ;// esi iterates bus records

        J1: sub esi, SIZEOF BUS_EDIT_RECORD
            mov [esi].number, ecx
            dec ecx
            sub esi, SIZEOF BUS_EDIT_RECORD
            mov [esi].number, ecx
            dec ecx
            cmp esi, edi
            ja J1

        ;// initilize the names and shapes of each item in the bus table

            mov ebx, '0a'   ;// ebx iterates the name
            jmp enter_loop

        top_of_loop:
            add esi, SIZEOF BUS_EDIT_RECORD
        enter_loop:
            mov eax, ebx                ;// load the name
            lea edi, font_bus_slist_head;// point at the bus font
            invoke font_Locate          ;// locate/build the character
            mov [esi].pNameShape, edi   ;// store in record
            ;// iterate the letter
            inc bh          ;// increase the number
            cmp bh, '9'     ;// check if this row is done
            jbe top_of_loop ;// jump if row is done
            mov bh, '0'     ;// reset the index
            inc bl          ;// increase the lettter
            cmp bl, 'l'     ;// skip l
            jnz G1
            inc bl
            jmp top_of_loop
        G1: cmp bl, 'o'     ;// skip o
            jnz G2
            inc bl
            jmp top_of_loop
        G2: cmp bl, 'z'     ;// see if we're done
            jbe top_of_loop

    ;// press the correct buttons

        invoke CheckDlgButton, bus_hWnd, IDC_BUS_SHOWBUSSES, BST_CHECKED
        invoke CheckDlgButton, bus_hWnd, IDC_BUS_SORT_NUMBER, BST_CHECKED

    ;// get miscellaneous handles

        invoke GetDlgItem, bus_hWnd, IDC_BUS_STATUS
        mov hWnd_bus_status, eax

        invoke GetDlgItem, bus_hWnd, IDC_BUS_UNDO
        mov hWnd_bus_undo, eax

        invoke GetDlgItem, bus_hWnd, IDC_BUS_REDO
        mov hWnd_bus_redo, eax

    ;// inialize and subclass the controld

        invoke grid_Initialize
        invoke catmem_Initialize
        invoke edit_Initialize

    ;// assign the status strings

        lea esi, bus_status_table   ;// point at status table

        H1: lodsd               ;// get the string pointer
            or eax, eax         ;// see if we're done (zero terminated list)
            jz done_asigning_status

            push eax            ;// SetWindowLong data parameter

            lodsd               ;// get the id
            invoke GetDlgItem, bus_hWnd, eax    ;// get the window handle

            pushd GWL_USERDATA  ;// SetWindowLong index parameter
            pushd eax           ;// hWnd of control
            call SetWindowLongA ;// set the value

            jmp H1

        done_asigning_status:

;//
;// that's it
;//

        mov eax, 1  ;// return one for the WM_CREATE function

        ret

bus_wm_create_proc ENDP
;//
;//     WM_CREATE
;//
;//
;////////////////////////////////////////////////////////////////////




;////////////////////////////////////////////////////////////////////
;//
;//
;//     WM_DESTROY
;//
ASSUME_AND_ALIGN
bus_wm_destroy_proc     PROC PRIVATE

    invoke memory_Free, bus_pTable      ;// free the table

    ;// call the dtors for the subclassed controls

    invoke grid_Destroy
    invoke catmem_Destroy
    invoke edit_Destroy

    jmp bus_Proc_exit_zero

bus_wm_destroy_proc     ENDP
;//
;//     bus_Destroy
;//
;//
;////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN

END







