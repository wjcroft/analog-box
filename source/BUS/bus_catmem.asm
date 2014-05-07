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
;//
;// bus_catmem.asm      handlers and rountines for the category and member lists
;//
;// TOC
;//
;// catmem_Initialize
;// catmem_Destroy
;//     cat_locate_cat_index
;//     mem_locate_mem_index
;// catmem_EditName
;// catmem_wm_dblclk_proc
;// catmem_wm_measureitem_proc
;// catmem_wm_drawitem_proc
;// catmem_wm_compareitem_proc
;// cat_LoadList
;// mem_SyncWithCat
;// catmem_Update
;// catmem_Proc
;// catmem_wm_showwindow_proc
;// catmem_LocateBusPin
;// catmem_wm_lbuttondown_proc
;// catmem_wm_mousemove_proc
;// catmem_wm_lbuttonup_proc
;// catmem_wm_setcursor_proc
;// catmem_wm_keydown_proc
;// catmem_AddCat
;// catmem_DelCat
;// catmem_CatCat
;// catmem_MemCat
;// catmem_SetCatName
;// catmem_SetMemName

OPTION CASEMAP:NONE


USE_THIS_FILE EQU 1

IFDEF USE_THIS_FILE


.586
.MODEL FLAT

        .NOLIST
        include <Abox.inc>
        include <bus.inc>
        .LIST


comment ~ /*

    this file implements the following functions

        launching of the editor

        selection control of categories

        insertion and removal of categories

        drag-drop of member names

*/ comment ~



.DATA

    ;// handles and procs

        cat_hWnd        dd  0   ;// handle of the category list
        mem_hWnd        dd  0   ;// handle of the members list

        catmem_OldProc  dd  0   ;// we subclass the cat and mem lists

        hWnd_add_cat    dd  0   ;// ins cat button
        hWnd_del_cat    dd  0   ;// del cat button
        hWnd_sort_name  dd  0   ;// mem sort names button
        hWnd_sort_number dd 0   ;// mem sort number button

        hWnd_cat_stat   dd  0   ;// static control
        hWnd_mem_stat   dd  0   ;// static control


    ;// current selection indexs

        cat_cursel      dd  0   ;// currently selected category index
                                ;// this value is used to synchronize the mem list

    ;// drag and drop points ( always in bus_hWnd coords )

        drag_rect  RECT  {} ;// tracks the rect (always in bus coords)
        drag_point POINT {} ;// tracks the mouse (always in bus coords)
        drop_rect   RECT {} ;// highlight rect for dropping on cat list

        DRAG_MIN_OFFSET equ 2   ;// min dist needed to launch the drag routines

    ;// drag and drop list indexes

        drag_index      dd  0   ;// list index of the item we are dragging
        drop_index      dd  0   ;// list index we are dropping on

    ;// forward references in this file

        catmem_Update   PROTO
        cat_LoadList    PROTO
        mem_SyncWithCat PROTO


.CODE

;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;////
;////
;////       initialize and destroy
;////

catmem_Initialize   PROC

;// category

    invoke GetDlgItem, bus_hWnd, IDC_BUS_ADD_CAT
    mov hWnd_add_cat, eax

    invoke GetDlgItem, bus_hWnd, IDC_BUS_DEL_CAT
    mov hWnd_del_cat, eax

    invoke GetDlgItem, bus_hWnd, IDC_BUS_SORT_NAME
    mov hWnd_sort_name, eax

    invoke GetDlgItem, bus_hWnd, IDC_BUS_SORT_NUMBER
    mov hWnd_sort_number, eax

    invoke GetDlgItem, bus_hWnd, IDC_BUS_CATEGORY_STATIC
    mov hWnd_cat_stat, eax

    invoke GetDlgItem, bus_hWnd, IDC_BUS_MEMBER_STATIC
    mov hWnd_mem_stat, eax

    invoke GetDlgItem, bus_hWnd, IDC_BUS_CAT
    mov cat_hWnd, eax

    lea edx, catmem_Proc
    invoke SetWindowLongA, eax, GWL_WNDPROC, edx
    mov catmem_OldProc, eax

;// member

    invoke GetDlgItem, bus_hWnd, IDC_BUS_MEM
    mov mem_hWnd, eax

    lea edx, catmem_Proc
    invoke SetWindowLongA, eax, GWL_WNDPROC, edx
    DEBUG_IF <eax!!=catmem_OldProc>     ;// oops !

    ret

catmem_Initialize   ENDP

catmem_Destroy  PROC

    invoke SetWindowLongA, cat_hWnd, GWL_WNDPROC, catmem_OldProc
    invoke SetWindowLongA, mem_hWnd, GWL_WNDPROC, catmem_OldProc

    ret

catmem_Destroy  ENDP

;////
;////
;////       initialize and destroy
;////
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////
;//
;// two helper functions locate list indexes from pointers
;//


    PROLOGUE_OFF
    ASSUME_AND_ALIGN
    cat_locate_cat_index PROC STDCALL pCat:DWORD

            push ebx

        ;// stack
        ;// ebx ret pCat
        ;// 00  04  08

            LISTBOX cat_hWnd, LB_GETCOUNT
            mov ebx, eax

        top_of_loop:

            dec ebx
            js all_done ;// DEBUG_IF <SIGN?>    ;// can't find it !!
            LISTBOX cat_hWnd, LB_GETITEMDATA, ebx
            cmp eax, [esp+8]
            jne top_of_loop

        all_done:

            mov eax, ebx
            pop ebx

            ret 4

    cat_locate_cat_index ENDP
    PROLOGUE_ON



    PROLOGUE_OFF
    ASSUME_AND_ALIGN
    mem_locate_mem_index PROC STDCALL pMem:DWORD

            push ebx

        ;// stack
        ;// ebx ret pMem
        ;// 00  04  08

            LISTBOX mem_hWnd, LB_GETCOUNT
            mov ebx, eax

        top_of_loop:

            dec ebx
            js all_done ;// DEBUG_IF <SIGN?>    ;// can't find it !!
            LISTBOX mem_hWnd, LB_GETITEMDATA, ebx
            cmp eax, [esp+8]
            jne top_of_loop

        all_done:

            mov eax, ebx
            pop ebx

            ret 4

    mem_locate_mem_index ENDP
    PROLOGUE_ON

;//
;// two helper functions locate list indexes from pointers
;//
;////////////////////////////////////////////////////////////////

















PROLOGUE_OFF
ASSUME_AND_ALIGN
catmem_EditName PROC STDCALL hWnd:DWORD

    ;// this common routine will take care of unredo and launch the lable editor

    ;// we assume were are always recording
    ;// to either action_UNREDO_CATNAME or action_UNREDO_MEMNAME

    ;// tasks:  get the BUS_EDIT_RECORD we're working with
    ;//         determine if we are cat or mem
    ;//         start the edit process
    ;//         store cat or mem number
    ;//         store the name

    xchg esi, [esp+4]    ;// store esi, get hWnd

    LISTBOX esi, LB_GETCURSEL       ;// get the list index
    LISTBOX esi, LB_GETITEMDATA, eax;// get the item data

    ASSUME eax:PTR BUS_EDIT_RECORD  ;// eax is now the bus edit record

    push esi            ;// save the hWnd
    push [eax].number   ;// need to store this for a moment

    .IF esi == cat_hWnd

        lea esi, [eax].cat_name     ;// point at cat name
        unredo_BeginAction UNREDO_BUS_CATNAME   ;// start the action

    .ELSE

        lea esi, [eax].mem_name     ;// point at member name
        unredo_BeginAction UNREDO_BUS_MEMNAME   ;// start the action

    .ENDIF


    xchg edi, unredo_pRecorder  ;// get the action recorder

    pop eax     ;// retrieve the bus edit record number

    stosd       ;// store the number, advance the recorder

    mov ecx, 8  ;// copy the origonal name
    rep movsd

    pop ecx             ;// retrieve the hWnd
    xchg esi, [esp+4]   ;// retrieve esi origonal value of esi
    xchg edi, unredo_pRecorder ;// restore edi and store the new iterator

    invoke edit_Launch

    ret 4

catmem_EditName ENDP
PROLOGUE_ON




;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;////
;////   bus_hWnd notify handlers        these are called from bus_proc
;////
;////
;////   category and member selection
;////   both lists are OWNERDRAW so we get to do a lot of extra work
;////

;////////////////////////////////////////////////////////////////////
;//
;//                         jumped to from bus_wm_command_proc
;//     LBN_DBLCLK
;//
;//     idListBox = (int) LOWORD(wParam);  // identifier of list box
;//     hwndListBox = (HWND) lParam;       // handle of list box
ASSUME_AND_ALIGN
catmem_wm_dblclk_proc PROC  ;// STDCALL hWnd, msg, wParam, lParam

    invoke catmem_EditName, WP_LPARAM
    xor eax, eax
    ret 10h

catmem_wm_dblclk_proc ENDP


;// WM_MEASUREITEM
;// idCtl = (UINT) wParam;                // control identifier
;// lpmis = (LPMEASUREITEMSTRUCT) lParam; // item-size information
ASSUME_AND_ALIGN
catmem_wm_measureitem_proc  PROC ;// STDCALL hWnd, msg, wParam, lParam

        mov ecx, WP_LPARAM
        ASSUME ecx:PTR MEASUREITEMSTRUCT

        sub esp, SIZEOF RECT

        cmp [ecx].CtlID, IDC_BUS_MEM
        je member_list

    category_list:

        mov ecx, cat_hWnd
        jmp set_the_values

    member_list:

        mov ecx, mem_hWnd

    set_the_values:

        invoke GetClientRect,ecx, esp
        add esp, 12
        pop edx

        mov ecx, WP_LPARAM
        xor eax, eax
        mov [ecx].itemHeight, FONT_POPUP
        mov [ecx].itemWidth, edx

    ;// return true

        inc eax
        ret 10h

catmem_wm_measureitem_proc  ENDP


;////////////////////////////////////////////////////////////////////
;//
;// WM_DRAWITEM
;//
;// idCtl = (UINT) wParam;             // control identifier
;// lpdis = (LPDRAWITEMSTRUCT) lParam; // item-drawing information
;//
ASSUME_AND_ALIGN
catmem_wm_drawitem_proc PROC ;// STDCALL hWnd, msg, wParam, lParam

    xchg ebx, WP_LPARAM ;// load and store
    ASSUME ebx:PTR DRAWITEMSTRUCT

    ;// skip is empty list

        cmp [ebx].dwItemID, -1
        je all_done_ebx

    ;// skip changing focus commands

    ;// cmp [ebx].dwItemAction, ODA_FOCUS
    ;// je all_done_ebx

        push esi    ;// store now
        push edi

    comment ~ /*

        here's what we have to do

        determine what string to draw
        this will be stored in esi

        check the item state and do the following

        (ODS_FOCUS)
        determine if we change the background color
        this also implies that we are selected

        (ODS_SELECTED)
        have to draw a focus rect

    */ comment ~

    ;// 1) dtermine what string to draw

        mov eax, [ebx].hWndItem     ;// load the hWnd
        mov esi, [ebx].dwItemData   ;// load the bus record pointer
        ASSUME esi:PTR BUS_EDIT_RECORD

        ;// determine which list

        cmp eax, cat_hWnd
        je drawing_category

    drawing_member:

        ;// build the member name

        mov ecx, [esi].pNameShape   ;// get the shape pointer
        ASSUME ecx:PTR GDI_SHAPE
        mov edx, bus_pString        ;// we'll temp the temp record to store strings
        mov ecx, [ecx].character    ;// get the characters of the desgnator
        mov DWORD PTR [edx], ecx    ;// store the charcters
        add edx, 2                  ;// advance edx
        ASSUME edx:PTR BYTE
        lea ecx, [esi].mem_name     ;// point at the member name
        ASSUME ecx:PTR BYTE

        cmp [ecx], 0                ;// is there a member name ?
        mov esi, bus_pString        ;// load the source string pointer
        je do_the_draw              ;// jmp if no member name

        mov [edx], 20h      ;// tack on a space
        inc edx             ;// advance edx
        STRCPY edx, ecx     ;// to the copy
        jmp do_the_draw     ;// continue on

    drawing_category:   ;// just point to the category name

        lea esi, [esi].cat_name


    ;// 2)  determine how to draw this
    ;//     at this point, esi must point at a string to draw
    ;//     ebx should still be the drawitem struct
    do_the_draw:


    ;// fill the background with the appropriate color
    ;// if text is selected, then set the background color

        lea edi, [ebx].rcItem
        test [ebx].dwItemState, ODS_SELECTED
        mov edx, COLOR_WINDOW+1
        jz @F

        invoke GetSysColor,COLOR_HIGHLIGHT
        invoke SetBkColor, [ebx].hDC, eax
        invoke GetSysColor, COLOR_HIGHLIGHTTEXT
        invoke SetTextColor, [ebx].hDC, eax
        mov edx, COLOR_HIGHLIGHT+1
    @@:
        invoke FillRect, [ebx].hDC, edi, edx

    ;// draw the text

        or edx, -1      ;// set as -1
        invoke DrawTextA, [ebx].hDC, esi, edx, edi, DT_NOCLIP OR DT_SINGLELINE OR DT_NOPREFIX

        ;// draw the focus rect

        .IF [ebx].dwItemState & ODS_FOCUS
            invoke DrawFocusRect, [ebx].hDC, edi
        .ENDIF

    ;// replace the background color

        .IF [ebx].dwItemState & ODS_SELECTED
            invoke GetSysColor, COLOR_WINDOW
            invoke SetBkColor, [ebx].hDC, eax
            invoke GetSysColor, COLOR_WINDOWTEXT
            invoke SetTextColor, [ebx].hDC, eax
        .ENDIF


    ;// 3) clean up and beat it

        pop edi
        pop esi

all_done_ebx:

        xchg ebx, WP_LPARAM
        mov eax, 1
        ret 10h

catmem_wm_drawitem_proc ENDP


;////////////////////////////////////////////////////////////////////
;//
;// WM_COMPAREITEM      jumped to from bus_proc
;//
;// idCtl = wParam;                       // control identifier
;// lpcis = (LPCOMPAREITEMSTRUCT) lParam; // structure with items
;//
;//
ASSUME_AND_ALIGN
catmem_wm_compareitem_proc  PROC ;// STDCALL hWnd, msg, wParam, lParam

    mov ecx, WP_LPARAM
    ASSUME ecx:PTR COMPAREITEMSTRUCT
    mov eax, [ecx].itemData1    ;// load item 1
    mov edx, [ecx].itemData2    ;// load item 2
    mov ecx, [ecx].hWndItem     ;// load the hwnd

    cmp ecx, cat_hWnd           ;// cat window ?
    je compare_category_strings

compare_members:            ;// member window

    test dlg_mode, DM_SORT_NAMES    ;// sort by names ?
    jnz compare_member_strings

compare_pointers:   ;// sort by number

    sub eax, edx    ;// compare the pointers
    je all_done
    sar eax, 31     ;// fill with sign
    or eax, 1       ;// make sure either 1 or -1
    jmp all_done

ASSUME eax:PTR BUS_EDIT_RECORD
ASSUME edx:PTR BUS_EDIT_RECORD

compare_category_strings:   ;// category strings are never blank

    push esi
    push edi

    lea esi, [eax].cat_name
    lea edi, [edx].cat_name

    jmp do_the_compare

compare_member_strings:     ;// member strings may be blank,
                            ;// we want blanks to appear AFTER not blanks
    cmp [eax].mem_name, 0   ;//
    jne item1_not_blank     ;// if item1 is blank
    cmp [edx].mem_name, 0   ;//     if item 2 is blank
    je compare_pointers     ;//         goto compare pointers
                            ;//     else
    or eax, -1              ;//         return item 1 follows item 2    = 1
    jmp all_done_neg        ;//     endif
item1_not_blank:            ;// else
    cmp [edx].mem_name, 0   ;//     if item 2 is not blank either
    jne neither_is_blank    ;//         goto compare strings
                            ;//     else
    or eax, -1              ;//         return item 1 preceeds items 2  = -1
    jmp all_done            ;//     endif
                            ;// endif
neither_is_blank:

    push esi
    push edi

    lea esi, [eax].mem_name
    lea edi, [edx].mem_name

do_the_compare:

    mov ecx, 32
    xor eax, eax
    repe cmpsb
    pop edi
    pop esi
    je all_done
    inc eax         ;// make sure we return one
    jnc all_done    ;// carry is still set from prev coparison
all_done_neg:
    neg eax         ;// make negative
all_done:
    ret 10h

catmem_wm_compareitem_proc  ENDP


;////   bus_hWnd notify handlers
;////
;////
;////   category and member selection
;////   both lists are OWNERDRAW so we get to do a lot of extra work
;////
;////
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////






























;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;///
;///    list synchronization and loading
;///
;///

;////////////////////////////////////////////////////////////////////
;//
;//                         used when changing contexts
;//     cat_LoadList        this will load the category list, list box is assumed to be empty
;//                         called from catmem_Update

ASSUME_AND_ALIGN
cat_LoadList PROC uses esi ebx

    mov esi, bus_pTable
    ASSUME esi:PTR BUS_EDIT_RECORD
    mov ebx, bus_pEnd
top_of_loop:
    cmp [esi].cat_name, 0
    je all_done
    LISTBOX cat_hWnd, LB_ADDSTRING, 0, esi
    add esi, SIZEOF BUS_EDIT_RECORD
    cmp esi, ebx
    jb top_of_loop
all_done:
    ret

cat_LoadList ENDP
;//
;//                         used when changing contexts
;//     cat_LoadList        this will load the category list
;//                         called from catmem_Update
;////////////////////////////////////////////////////////////////////




;////////////////////////////////////////////////////////////////////
;//
;//                         use this after changing the selection in
;//     mem_SyncWithCat     the IDC_BUS_CAT list
;//                         it loads the member list for that category
ASSUME_AND_ALIGN
mem_SyncWithCat PROC PRIVATE USES esi edi ebx

        mov edi, mem_hWnd           ;// load the hwnd pointer
        WINDOW edi, WM_SETREDRAW    ;// prevent flicker

    ;// prepare to build a new list

        LISTBOX edi, LB_RESETCONTENT    ;// flush the old member list

        LISTBOX cat_hWnd, LB_GETITEMDATA, cat_cursel    ;// get the pointer

        mov ebx, eax            ;// ebx will be what we're looking for
        mov esi, bus_pEnd       ;// start at end of list


        ASSUME esi:PTR BUS_EDIT_RECORD  ;// esi iterates backwards
        jmp enter_loop

    ;// iterate through the bus_pTable
    top_of_loop:
        .IF ebx == [esi].cat_pointer            ;// same category ?
            LISTBOX edi, LB_ADDSTRING ,0, esi   ;// add to list
        .ENDIF
    enter_loop:
        sub esi, SIZEOF BUS_EDIT_RECORD ;// iterate to previous
        cmp esi, bus_pTable         ;// done yet ??
        jae top_of_loop             ;// jump if not

    ;// then force a redraw

        WINDOW edi, WM_SETREDRAW, 1
        invoke InvalidateRect, edi, 0, 0

    ;// that's it

        ret

mem_SyncWithCat ENDP
;//
;//     mem_SyncWithCat
;//
;//
;////////////////////////////////////////////////////////////////////






;////////////////////////////////////////////////////////////////////
;//
;//                     makes sure the proper items are highlighted
;//     list_Update
;//                     set cat_cursel to -1 to force a reload of the mem list
ASSUME_AND_ALIGN
catmem_Update PROC

    ;// if cat_cursel is different from the current selection
    ;//
    ;//     flush the mem_list
    ;//     get the category id from cat_list
    ;//     rebuild the mem list
    ;//


    ;// time to reload the lists ?
    LISTBOX cat_hWnd, LB_GETCOUNT
    .IF !eax

        invoke cat_LoadList
        LISTBOX cat_hWnd, LB_SETCURSEL
        or cat_cursel, -1   ;// JIC

    .ENDIF

    ;// make sure mem matches the selected category
    LISTBOX cat_hWnd, LB_GETCURSEL

    .IF eax != cat_cursel

        mov cat_cursel, eax
        invoke mem_SyncWithCat
        mov eax, cat_cursel

    .ENDIF

    ;// make sure we can't delete the default

    LISTBOX cat_hWnd, LB_GETITEMDATA, eax
    sub eax, bus_pTable     ;// first item ?
    invoke EnableWindow, hWnd_del_cat, eax

    ;// make sure we can't add more than 240

    LISTBOX cat_hWnd, LB_GETCOUNT
    sub eax, 240
    invoke EnableWindow, hWnd_add_cat, eax

    ;// that's it
    ret

catmem_Update  ENDP
;//
;//     list_Update
;//                     set cat_cursel to -1 to force a reload of the mem list
;//
;////////////////////////////////////////////////////////////////////





;///
;///    list synchronization and loading
;///
;///
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////










;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////

;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;///
;///    catmem_Proc
;///
;///

;////////////////////////////////////////////////////////////
;//                                            sub class proc
;//     catmem_Proc
;//
ASSUME_AND_ALIGN
catmem_Proc PROC PRIVATE

    mov eax, WP_MSG

    HANDLE_WM WM_SHOWWINDOW,    catmem_wm_showwindow_proc

    HANDLE_WM WM_SETCURSOR,     catmem_wm_setcursor_proc

    HANDLE_WM WM_LBUTTONDOWN,   catmem_wm_lbuttondown_proc
    HANDLE_WM WM_MOUSEMOVE,     catmem_wm_mousemove_proc
    HANDLE_WM WM_LBUTTONUP,     catmem_wm_lbuttonup_proc

    HANDLE_WM WM_KEYDOWN,       catmem_wm_keydown_proc


    exit_via_catmem_defproc::

        SUBCLASS_DEFPROC catmem_OldProc
        ret 10h

catmem_Proc ENDP




;////////////////////////////////////////////////////////////////////
;//
;//                                 takes care of initializing the display
;//     cat_wm_showwindow_proc
;//
;// WM_SHOWWINDOW
;// fShow = (BOOL) wParam;      // show/hide flag
;// fnStatus = (int) lParam;    // status flag
;//
ASSUME_AND_ALIGN
catmem_wm_showwindow_proc PROC ;// STDCALL hWnd, msg, wParam, lParam

    ;// skip if mem_hWnd

    mov eax, WP_HWND
    cmp eax, mem_hWnd
    je exit_via_catmem_defproc

    push ebx

    ;// stack looks like this:
    ;// ebx ret hWnd msg wParam lParam
    ;// 00  04  08   0C  10h    14h

    xor ebx, ebx        ;// SW_HIDE = 0
    or ebx, [esp+10h]   ;// check the parameter
    jz J1               ;// jump if already zero
    mov ebx, SW_SHOW    ;// we are showing the window

    ;// check if we're supposed to initialize

        btr dlg_mode, LOG2(DM_CAT_INIT)
        jnc J1
        or cat_cursel, -1
        LISTBOX cat_hWnd, LB_RESETCONTENT
        invoke catmem_Update
    J1:

    ;// unhide the appropriate windows

        invoke ShowWindow, mem_hWnd, ebx
        invoke ShowWindow, hWnd_add_cat, ebx
        invoke ShowWindow, hWnd_del_cat, ebx
        invoke ShowWindow, hWnd_sort_name, ebx
        invoke ShowWindow, hWnd_sort_number, ebx
        invoke ShowWindow, hWnd_cat_stat, ebx
        invoke ShowWindow, hWnd_mem_stat, ebx

    ;// set the selection to the current pin

    .IF ebx ;// don't do this is we are hiding

        push ebp
        stack_Peek gui_context, ebp
        invoke catmem_LocateBusPin
        pop ebp

    .ENDIF  ;// set selection if not hiding

    ;// that's it

    all_done:

        pop ebx

        jmp exit_via_catmem_defproc

catmem_wm_showwindow_proc ENDP


ASSUME_AND_ALIGN
catmem_LocateBusPin PROC

    ASSUME ebp:PTR LIST_CONTEXT

    ;// destroys ebx

    ;// this function makes sure bus_pPin is displayed by the cat mem list

    ;// get this pin's bus record

        GET_PIN bus_pPin, ebx       ;// get the pin that launched us
        mov eax, [ebx].dwStatus     ;// get the status
        and eax, PIN_BUS_TEST       ;// mask out number
        je all_done                 ;// exit if not a bus

        push eax
        invoke bus_GetEditRecord
        pop ebx

        ASSUME ebx:PTR BUS_EDIT_RECORD

    ;// now ebx points at this pin's bus record

    ;// display the appropriate category

        mov eax, [ebx].cat_pointer
        mov eax, (BUS_EDIT_RECORD PTR [eax]).number
        dec eax
        .IF eax != cat_cursel

            ;// mov cat_cursel, eax
            LISTBOX cat_hWnd, LB_SETCURSEL, eax, 0
            invoke catmem_Update

        .ENDIF

    ;// select the appropriate member

        invoke mem_locate_mem_index, ebx
        LISTBOX mem_hWnd, LB_SETCURSEL, eax, 0

    ;// that's it

    all_done:

        ret

catmem_LocateBusPin ENDP










;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;////
;////
;////       D R A G  AND  D R O P     ver 2
;////

comment ~ /*

    there are three window players

        cat_list
        mem_list
        bus_window

    there is one drag_point

        it starts as where the mouse came down during wm_lbuttondown
        it turns into a delta while in wm_mousemove

    there is one drag_rect

        once we start dragging, this rect tells where the focus rect is
        this rect is always in bus coords

    there is one drag_index

        it tells us the LIST INDEX that caused the dragging to begin

    there is one drop_index

        it tells us the CATEGORY LIST INDEX that the lbutton up event caused

    there are two cursors:

        OK and bad

    while in drag mode we set the cat_list as the mouse capture
    this simplifies the handlers

    dlg_mode flags we care about are :

        DM_CAT_DOWN     a lbuttondown event occured on a draggable category
        DM_MEM_DOWN     a lbuttondown event occured on a draggable member

            either of these bieng on states that drag_index is valid
            and it states that drag_point has meaning

        DM_DRAG_CAT     it was determined that we are dragging a category
        DM_DRAG_MEM     it was determined that we are dragging a member

            either of these state that drag_point is used as a delta
            and thet drag_rect is the current location of the focus rectangle

        DM_BAD_CAT      states that the cursor is currently displayed as BAD
        DM_CAT_CAPTURE  states that the cat_list has the mouse capture

    rectangle updating functions :

        check_mouse_distance

            returns carry if the mouse has NOT moved far enough to start a drag

        update_drag_rect

            updates the location of the drag focus rectangle

        update_drop_rect

            update the highlight of the drop rectangle



*/ comment ~



;////////////////////////////////////////////////////////////
;//
;//     catmem_lbuttondown_proc     jumped to from catmem_Proc
;//

ASSUME_AND_ALIGN
catmem_wm_lbuttondown_proc PROC PRIVATE

    ;// DEBUG_IF <dlg_mode & DM_DOWN_TEST>  ;// flags got out of sync

        SUBCLASS_DEFPROC catmem_OldProc ;// do the default first
        invoke ReleaseCapture           ;// release the capture

        xchg ebx, WP_HWND   ;// load and store

        LISTBOX ebx, LB_GETCURSEL   ;// see if valid item
        cmp eax, LB_ERR             ;// anything selected ?
        je all_done

        mov ecx, DM_MEM_DOWN    ;// default to this

        .IF ebx==cat_hWnd

            push eax                ;// store current selection

            .IF eax!=cat_cursel     ;// check for different category
                invoke catmem_Update;// update the list
                mov eax, [esp]      ;// retrieve eax
            .ENDIF

            LISTBOX ebx, LB_GETITEMDATA, eax
            cmp eax, bus_pTable     ;// check for the default id
            pop eax                 ;// retreive eax
            je all_done             ;// exit if default category
            mov ecx, DM_CAT_DOWN    ;// replace default with cat down

        .ENDIF

    set_mouse_down: ;// action: drag_index, dlg_mode, drag_point

        mov drag_index, eax     ;// store the index
        or dlg_mode, ecx        ;// set the MOVE flag

        spoint_Get WP_LPARAM    ;// get, xlate and store the down point
        point_Set drag_point    ;// store in drag_point
        ;// remap to bus window coords
        invoke MapWindowPoints, ebx, bus_hWnd, OFFSET drag_point, 1

    all_done:

        xchg ebx, WP_HWND   ;// replace ebx
        xor eax, eax        ;// return zero
        ret 10h

catmem_wm_lbuttondown_proc ENDP





;////////////////////////////////////////////////////////////
;//                                 jumped to from catmem_Proc
;//     catmem_mousemove_proc
;//
comment ~ /*

if DM_DOWN_TEST                 ;// see if the either list has a button down status

    if !DM_MOVE_TEST            ;// see if we alredy know we're moving

        check_mouse distance    ;// if mouse has moved a little bit
        jz all_done

        if      CAT_DOWN    set cat move    ;// we had cat down
        else    MEM_DOWN    set mem move    ;// we had mem down

        ENTER_DRAG_MODE         ;// set up the drag rects
        set cature, cat_hWnd    ;// cat must handle the rest

    endif

    update_DragRect

    if moving cat       verify valid cat to cat
    else (moving mem)   verify valid mem to cat

endif
*/ comment ~

ASSUME_AND_ALIGN
catmem_wm_mousemove_proc PROC PRIVATE;// STDCALL hWnd msg wParam lParam
                                    ;//  00      04   08  0C     10

        mov edx, dlg_mode           ;// get the mode
        xor eax, eax                ;// defualt return value
        test edx, DM_CAT_DOWN OR DM_MEM_DOWN;// anything to do ??
        jz all_done_zero            ;// nope

        xchg ebx, WP_HWND   ;// load and save

        ;// regardless, we're going to need to xlate the points to bus coords

        spoint_Get WP_LPARAM    ;// get the point
        lea ecx, [esp-8]    ;// point at we're we will store them
        push edx            ;// store points
        push eax
        invoke MapWindowPoints, ebx, bus_hWnd, ecx, 1   ;// xlate to bus

    ;// stack
    ;// x   y   ret xxxx msg wParam lParam
    ;// 00  04  08  0C   10  14     18

        mov ecx, dlg_mode       ;// get the mode
        test ecx, DM_DRAG_CAT OR DM_DRAG_MEM;// do we already know if we are dragging ?
        jnz update_move_mode    ;// jump if we do

    not_already_moving:

            ;// check mouse distance

            point_Get drag_point

            sub eax, [esp]
            jns @F
            neg eax
        @@: sub edx, [esp+4]
            jns @F
            neg edx
        @@:
            or eax, edx     ;// merge together
            sub eax, DRAG_MIN_OFFSET
            ;// this will set the carry flag if eax was less than 4

            jnc prepare_to_drag         ;// see if we've far enough

            ;// not far enough

            add esp, 8
            jmp all_done_ebx

        prepare_to_drag:    ;// we now now we are ready to drag

            bt ecx, LOG2(DM_MEM_DOWN)   ;// CAT_DOWN ??
            mov edx, DM_DRAG_MEM OR DM_CAT_CAPTURE  ;// set the most common move flag
            jc set_the_move_mode
            mov edx, DM_DRAG_CAT OR DM_CAT_CAPTURE

        set_the_move_mode:

            or dlg_mode, edx        ;// set our flag
            LISTBOX ebx, LB_GETITEMRECT, drag_index, OFFSET drag_rect   ;// get the rect
            invoke MapWindowPoints, ebx, bus_hWnd, OFFSET drag_rect, 2  ;// map to bus winodw

            invoke SetCapture, cat_hWnd

    update_move_mode:
    ;// stack
    ;// X   Y   ret ebx msg wParam lParam
    ;// 00  04  08  0C  10  14     18

        ;// update the drag rect

        xchg esi, [esp+10h]     ;// swap with msg

            invoke GetDC, bus_hWnd
            mov esi, eax
            invoke DrawFocusRect, esi, OFFSET drag_rect

            pop eax
            pop edx
        ;// stack
        ;// ret ebx esi wParam lParam
        ;// 00  04  08  0C     10    14     18
            point_Swap drag_point
            point_Sub drag_point
            point_SubToTL drag_rect ;// move the rectangle
            point_SubToBR drag_rect ;// move the rest of the rectangle

            ;// draw the new drag rect

            invoke DrawFocusRect, esi, OFFSET drag_rect
            invoke ReleaseDC, bus_hWnd, esi

    validate_move:

            cmp ebx, cat_hWnd       ;// always validate against cat wnd
            je @F
                or esi, LB_ERR      ;// no way we can be valid (LB_ERR = -1 btw)
                jmp drop_is_not_valid
        @@:
            mov edx, WP_LPARAM                      ;// get the point
            LISTBOX ebx, LB_ITEMFROMPOINT, 0, edx   ;// get the item

            mov esi, eax    ;// store for safe keeping

            cmp eax, NUM_BUSSES     ;// cmp with max to see if we hit anything
            mov ecx, dlg_mode       ;// load the mode
            jae drop_is_not_valid

            bt ecx, LOG2(DM_DRAG_CAT)
            jc check_valid_cat_cat

        check_valid_mem_cat:    ;// eax is still the item under the cursor

            ;// a valid mem to cat is one that the member.cat_ptr does NOT equal the drop pointer

            LISTBOX cat_hWnd, LB_GETITEMDATA, eax       ;// get category ptr
            push eax                                    ;// save on the stack
            LISTBOX mem_hWnd, LB_GETITEMDATA,drag_index ;// get member item data
            pop edx                                     ;// retrive cat pointer

            cmp (BUS_EDIT_RECORD PTR [eax]).cat_pointer, edx    ;// compare

            je drop_is_not_valid            ;// bad if they match
            jmp drop_is_valid

        check_valid_cat_cat:    ;// eax is still the item under the cursor

            ;// a valid cat to cat is one were point != drag item

            cmp eax, drag_index
            je drop_is_not_valid

        drop_is_valid:

            btr dlg_mode, LOG2(DM_CAT_BAD)
            jnc update_drop_rect
            invoke SetCursor, hCursor_normal
            jmp update_drop_rect

        drop_is_not_valid:

            bts dlg_mode, LOG2(DM_CAT_BAD)
            or esi, -1
            jc update_drop_rect
            invoke SetCursor, hCursor_bad


    update_drop_rect:
    ;// stack
    ;// ret ebx esi wParam lParam
    ;// 00  04  08  0C     10    14     18

    ;// esi = current drop item

            cmp esi, drop_index     ;// compare with stored index
            je  all_done_esi        ;// skip work if they're the same

            mov drop_index, esi     ;// save the new drop_item

            xor esi, esi    ;// esi will be the DC, no since getting it until we need it

            ;// stack looks like this
            ;// ret     ebx     esi     wParam  lParam
            ;// +00     +04     +08     +0C     +10     +14     +18     +1C


        ;// turn off old drop rect

            btr dlg_mode, LOG2(DM_DROP_ON)      ;// see if drop rect was on
            jnc @1

                .IF !esi
                    invoke GetDC, cat_hWnd  ;// get dc of list box
                    mov esi, eax            ;// store in esi
                .ENDIF
                lea ecx, drop_rect
                invoke DrawFocusRect, esi, ecx  ;// shut it off

        ;// turn on new drop rect

            @1: xor eax, eax            ;// clear for testing
                or eax, drop_index      ;// load and test the drop_item
                js @2                   ;// skip work if drop_item was bad

                lea ecx, drop_rect
                LISTBOX cat_hWnd, LB_GETITEMRECT, eax, ecx  ;// get the new rect
                .IF !esi
                    invoke GetDC, cat_hWnd  ;// get dc of list box
                    mov esi, eax            ;// store in esi
                .ENDIF
                lea ecx, drop_rect
                invoke DrawFocusRect, esi, ecx              ;// turn it on
                or dlg_mode, DM_DROP_ON                     ;// set the flag

        ;// release the DC if we need to

            @2:
                .IF esi
                    invoke ReleaseDC, cat_hWnd, esi ;// release the dc
                .ENDIF

    ;// stack looks like this
    ;// ret     ebx     esi     wParam  lParam
    ;// +00     +04     +08     +0C     +10     +14     +18     +1C

all_done_esi:   xchg esi, WP_MSG
all_done_ebx:   xchg ebx, WP_HWND
all_done_zero:  xor eax, eax

                ret 10h

catmem_wm_mousemove_proc ENDP







;////////////////////////////////////////////////////////////
;//                                 jumped to from cat_Proc
;//     cat_lbuttonup_proc
;//
ASSUME_AND_ALIGN
catmem_wm_lbuttonup_proc PROC PRIVATE ;// STDCALL hWnd, msg, wParam, lParam

        mov edx, dlg_mode           ;// get the mode
        xor eax, eax                ;// default return value
                                    ;// anything to do ?
        test edx, DM_CAT_CLEANUP_TEST OR DM_CAT_DRAG_DROP_TEST
        jnz check_for_more_actions

    all_done:

        ret 10h

    check_for_more_actions:

        bt edx, LOG2(DM_CAT_BAD)
        jc check_clean_up

        bt edx, LOG2(DM_DRAG_CAT)   ;// are we moving cat ?
        jc was_moving_cat
        bt edx, LOG2(DM_DRAG_MEM)   ;// are we moving mem ?
        jnc check_clean_up

    was_moving_mem:

        unredo_BeginAction UNREDO_BUS_MEMCAT

        LISTBOX cat_hWnd, LB_GETITEMDATA, drop_index
        push eax
        LISTBOX mem_hWnd, LB_GETITEMDATA, drag_index
        push eax
        call catmem_MemCat

        unredo_EndAction UNREDO_BUS_MEMCAT

        invoke bus_UpdateUndoRedo

        jmp check_clean_up

    was_moving_cat:

        unredo_BeginAction UNREDO_BUS_CATCAT

        LISTBOX cat_hWnd, LB_GETITEMDATA, drop_index    ;// destination
        push eax
        LISTBOX cat_hWnd, LB_GETITEMDATA, drag_index    ;// source
        push eax
        call catmem_CatCat

        unredo_EndAction UNREDO_BUS_CATCAT

        invoke bus_UpdateUndoRedo


    check_clean_up:

        xchg ebx, WP_MSG    ;// preserve ebx
        mov ebx, dlg_mode

        btr ebx, LOG2(DM_CAT_CAPTURE)
        jnc @F
        invoke ReleaseCapture
    @@:
        btr ebx, LOG2(DM_CAT_BAD)
        jnc @F
        invoke SetCursor, hCursor_normal    ;// reset the cursor
    @@:
        ;// always invalidate to erase the drag and drop rects
        invoke InvalidateRect, bus_hWnd, 0, 0

        and ebx, NOT  ( DM_CAT_DRAG_DROP_TEST OR DM_CAT_CLEANUP_TEST )
        mov dlg_mode, ebx
        xchg ebx, WP_MSG
        xor eax, eax
        mov drop_index, -1
        jmp all_done

catmem_wm_lbuttonup_proc ENDP


;////////////////////////////////////////////////////////////
;//
;//     cat_setcursor_proc
;//
ASSUME_AND_ALIGN
catmem_wm_setcursor_proc PROC PRIVATE

    ;// if we are moving anything
    ;// then
    ;//     if we are in the mem window, then we have to be bad
    ;//     else, another function already set the bad cursor
    ;// else
    ;//     update the status text

    mov edx, dlg_mode
    xor eax, eax
    and edx, DM_DRAG_CAT OR DM_DRAG_MEM ;// if !MOVE_TEST
    jz set_the_status       ;//     jmp to set_the_status
                            ;// else
    mov ecx, WP_HWND        ;//
    mov edx, dlg_mode       ;//
    cmp ecx, mem_hWnd       ;//     if mem_hWnd
    jne return_true         ;//
                            ;//
    bts edx, LOG2(DM_CAT_BAD);// see if bad cursor is already on
    jc return_true          ;// skip if it is

    mov dlg_mode, edx               ;// save the flag
    invoke SetCursor, hCursor_bad   ;// set the cursor
    xor eax, eax                    ;// return true

return_true:    ;// halt processing

    inc eax

return_false:   ;// continue on

    ret 10h


set_the_status:

    ;// if the editor is on, we don't want to do this

        test dlg_mode, DM_EDITING_CAT
        jnz return_false
        test dlg_mode, DM_EDITING_MEM
        jnz return_false

    ;// determine what text to display

        mov eax, WP_HWND

        invoke GetWindowLongA, eax, GWL_USERDATA;// get the string pointer
        .IF eax

            .IF eax != bus_last_status

                mov bus_last_status, eax
                WINDOW hWnd_bus_status, WM_SETTEXT,0,eax    ;// set the text

            .ENDIF

        .ELSEIF eax != bus_last_status

            mov bus_last_status, eax
            pushd eax
            WINDOW hWnd_bus_status, WM_SETTEXT,0,esp    ;// reset the text
            add esp, 4

        .ENDIF



    xor eax, eax
    jmp return_false



catmem_wm_setcursor_proc ENDP








;////////////////////////////////////////////////////////////
;//
;//
;//     catmem_keydown_proc
;//
ASSUME_AND_ALIGN
catmem_wm_keydown_proc PROC PRIVATE

        invoke GetAsyncKeyState, VK_CONTROL
        mov edx, eax

        mov ecx, WP_HWND
        mov eax, WP_WPARAM

    ;// keys common to both that are always available

        cmp eax, VK_ESCAPE
        je got_escape

        cmp eax, 'Z'
        je got_Z

        cmp eax, 'Y'
        je got_Y

    ;// keys only available when NOT in drag mode

        .IF dlg_mode & (DM_CAT_DOWN OR DM_MEM_DOWN)
            xor eax, eax
            jmp all_done
        .ENDIF

        cmp eax, VK_RETURN
        jz got_return

        cmp eax, VK_TAB
        jz got_tab

        ;// cat only keys
        .IF ecx == cat_hWnd

            cmp eax, VK_INSERT
            jz got_insert
            cmp eax, VK_DELETE
            jz got_delete

        .ENDIF

    ;// pass the keystroke to the label

    do_def_window:

        SUBCLASS_DEFPROC catmem_OldProc

        mov ecx, WP_HWND        ;// check for a different category
        .IF ecx == cat_hWnd

            push eax
            LISTBOX ecx, LB_GETCURSEL
            .IF eax != cat_cursel
                invoke catmem_Update
            .ENDIF
            pop eax

        .ENDIF

    all_done:

        ret 10h




    ;// KEY HANDLERS

    got_tab:        ;// switch

        mov eax, cat_hWnd
        cmp ecx, eax
        push mem_hWnd
        je @F
        mov [esp], eax
    @@: call SetFocus
        xor eax, eax
        jmp all_done

    got_escape:     ;// escape

        invoke SetFocus, hMainWnd   ;// close the bus dialog
        xor eax, eax
        jmp all_done

    got_return:     ;// edit

        invoke catmem_EditName, ecx

        ;// invoke edit_Launch  ;// launch the label editor

        xor eax, eax
        jmp all_done

    got_insert:     ;// add category

        LISTBOX ecx, LB_GETCOUNT    ;// make sure we can insert
        cmp eax, 240                ;// too long ?
        jae @F                      ;// jump if so

        unredo_BeginAction UNREDO_BUS_CATINS

        invoke catmem_AddCat, 0, 0  ;// use default args

    @@: xor eax, eax
        jmp all_done

    got_delete:     ;// delete category

        LISTBOX ecx, LB_GETITEMDATA, cat_cursel
        cmp eax, bus_pTable     ;// don't delete the default category
        je all_done

        push eax
        unredo_BeginAction UNREDO_BUS_CATDEL

        call catmem_DelCat  ;// arg already pushed

        unredo_EndAction UNREDO_BUS_CATDEL

        invoke bus_UpdateUndoRedo

        xor eax, eax
        jmp all_done

    got_Z:

        test edx, 8000h
        jz do_def_window

        mov ecx, IDC_BUS_UNDO OR (BN_CLICKED SHL 16 )
        mov edx, hWnd_bus_undo
        jmp check_enabled

    got_Y:

        test edx, 8000h
        jz do_def_window

        mov ecx, IDC_BUS_REDO OR (BN_CLICKED SHL 16 )
        mov edx, hWnd_bus_redo

    check_enabled:

        ;// first make sure the said button is enabled

        push edx
        push ecx

        invoke IsWindowEnabled, edx
        .IF !eax

            add esp, 8
            jmp all_done

        .ENDIF

        pushd WM_COMMAND
        push bus_hWnd
        call PostMessageA

        jmp all_done


catmem_wm_keydown_proc ENDP

;///
;///    catmem_Proc
;///
;///
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////



;///
;///
;///        DRAG AND DROP
;///
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////////
comment ~ /*

    in the light of undo redo
    we need a different common interface

    these functions will also force the list to update

    all function assume that cat ptr and mem ptr are pointers to edit records


    catmem_AddCat( cat ptr, name ptr )

        if ptr=0, find unused
        if ptr != 0 && ptr is already assign, throw error

        if name = 0, build default, launch editor

        insert cat into list

        cat set = new cat
        mem sel = -1

    catmem_DelCat( cat ptr1 )

        move cat1 to cat 0

        remove cat1 from list

        cat sel = 0 (default cat)
        mem sel = -1

    catmem_CatCat( cat1, cat2 )

        mov items in cat1 to cat2

        remove cat1 from list

        cat sel = cat2
        mem sel = -1

    catmem_MemCat( mem, cat )

        mov mem to cat

        cat sel = no change

        if mem.cat == cat then mem sel = mem
        else mem sel = next item


    catmem_SetCatName( cat, name )

        set cat name
        make sure category is displayed
        set sel to cat


    catmem_SetMemName( mem, name )

        set member name
        make sure mem.cat is displayed
        cat sel = mem.cat
        mem sel = mem

*/ comment ~





.DATA

    szFmt_noname db 'NoName%3.3i',0

.CODE

ASSUME_AND_ALIGN
catmem_AddCat PROC STDCALL uses ebx esi edi pCat:DWORD, pName:DWORD

    ;// determine the category to use

        mov ebx, pCat
        ASSUME ebx:PTR BUS_EDIT_RECORD

        .IF !ebx    ;// find unused

            xor eax, eax                ;// clear for testing zero
            mov ecx, SIZEOF BUS_EDIT_RECORD;// use to advance
            mov ebx, bus_pTable         ;// ebx will iterate
            J0: add ebx, ecx            ;// first record is always used
                DEBUG_IF <ebx==bus_pEnd>;// no busses left, we weren't supposed to be able to do this
                cmp [ebx].cat_name, al  ;// unused ?
                je J1                   ;// done if unused

                add ebx, ecx            ;// first record is always used
                DEBUG_IF <ebx==bus_pEnd>;// no busses left, we weren't supposed to be able to do this
                cmp [ebx].cat_name, al
                jne J0
            J1:

        .ENDIF

        DEBUG_IF <[ebx].cat_name>   ;// already in use !!

    ;// determine how to set the name

        mov esi, pName
        lea edi, [ebx].cat_name
        .IF esi         ;// copy the name
            mov ecx, 8
            rep movsd
        .ELSE           ;// build the default name
            invoke wsprintfA, edi, OFFSET szFmt_noname, [ebx].number    ;// format the name using the index
        .ENDIF

    ;// take care of recording

        mov edi, unredo_pRecorder
        .IF edi

            DEBUG_IF <pName>    ;// this was supposed to be zero

            ;// edi points at action_UNREDO_BUS_CATINS
            ;// at the cat member

            mov eax, [ebx].number   ;// store the cat
            stosd
            mov unredo_pRecorder, edi

            ;// edit_wm_killfocus_proc will store the new name

        .ENDIF

    ;// add category to list box and set selection to new category

        LISTBOX cat_hWnd, LB_ADDSTRING, 0, ebx  ;// add the string
        LISTBOX cat_hWnd, LB_SETCURSEL, eax     ;// set the current selection

    ;// make sure the display is correct

        mov cat_cursel, -1      ;// force the lists to reload
        invoke catmem_Update    ;// call the reloader

    ;// make sure the name was set

        .IF !pName  ;// launch the editor

            mov ecx, cat_hWnd       ;// get the window
            invoke edit_Launch      ;// launch the editor

        .ENDIF

    ;// that should do it

        ret

catmem_AddCat ENDP



ASSUME_AND_ALIGN
catmem_DelCat PROC STDCALL pCat:DWORD

    ;// move cat1 to cat 0, that's it

        LISTBOX cat_hWnd, LB_GETITEMDATA, 0

        invoke catmem_CatCat, pCat, eax

    ;// that's all there is to it

        ret

catmem_DelCat ENDP

ASSUME_AND_ALIGN
catmem_CatCat PROC STDCALL uses esi ebx edi pCat1:DWORD, pCat2:DWORD

    ;// mov items in cat1 to cat2

        mov esi, pCat1
        mov ebx, pCat2

        ASSUME esi:PTR BUS_EDIT_RECORD  ;// source
        ASSUME ebx:PTR BUS_EDIT_RECORD  ;// destination

    ;// xfer all cat_pointers that match esi to eax
    ;// account for recording unredo in the process

        mov edi, unredo_pRecorder
        mov edx, bus_pTable
        ASSUME edx:PTR BUS_EDIT_RECORD

        or edi, edi
        jnz yes_recording

        mov ecx, bus_pEnd
        mov eax, SIZEOF BUS_EDIT_RECORD

    xfer_top_of_loop_no_record:

        cmp [edx].cat_pointer, esi  ;// is this it ?
        jne K0
        mov [edx].cat_pointer, ebx  ;// set new cat pointer
    K0: add edx, eax
        cmp edx, ecx                ;// done yet ?
        jb xfer_top_of_loop_no_record
        jmp done_with_xfer_no_record


    yes_recording:  ;// edi is a pointer to action_UNREDO_BUS_CATCAT
                    ;// and points at cat1

        mov eax, [ebx].number   ;// store cat1 (new cat)
        stosd
        mov eax, [esi].number   ;// store cat2 (old cat)
        stosd
        lea esi, [esi].cat_name ;// store cat1 name
        mov ecx, 8
        rep movsd
        mov esi, pCat1

        mov ecx, bus_pEnd   ;// need a when to stop pointer

    xfer_top_of_loop_yes_record:

        cmp [edx].cat_pointer, esi  ;// is this it ?
        jne L0
        mov eax, [edx].number       ;// get the number
        mov [edx].cat_pointer, ebx  ;// set new cat pointer
        stosd                       ;// store the number in the member list
    L0: add edx, SIZEOF BUS_EDIT_RECORD;// next record
        cmp edx, ecx                ;// done yet ?
        jb xfer_top_of_loop_yes_record

    done_with_xfer_yes_record:

        mov unredo_pRecorder, edi

    done_with_xfer_no_record:

    ;// remove the source string

        lea edi, [esi].cat_name
        mov ecx, 8
        xor eax, eax
        rep stosd

    ;// remove cat1 from list

        ;// we have to locate the cat item with this pointer

        invoke cat_locate_cat_index, pCat1
        LISTBOX cat_hWnd, LB_DELETESTRING, eax

    ;// cat sel = cat2

        ;// we have to locate the cat item with this pointer

        invoke cat_locate_cat_index, pCat2
        LISTBOX cat_hWnd, LB_SETCURSEL, eax

    ;// update the display

        mov cat_cursel, -1      ;// force the lists to reload
        invoke catmem_Update    ;// call the reloader

    ;// that should do

        ret

catmem_CatCat ENDP

ASSUME_AND_ALIGN
catmem_MemCat PROC STDCALL uses esi ebx edi pMem:DWORD, pCat:DWORD

    ;// mov mem to cat

    ;// cat sel = no change

    ;// if mem.cat == cat then mem sel = mem
    ;// else mem sel = next item
    ;// remove list items appropriately

        mov esi, pMem   ;// member pointer to move
        ASSUME esi:PTR BUS_EDIT_RECORD

        mov ebx, pCat   ;// destination category
        ASSUME ebx:PTR BUS_EDIT_RECORD

    ;// account for recording

        mov edi, unredo_pRecorder
        .IF edi ;// edi points at action_UNREDO_BUS_MEMCAT
                ;// at the cat1 member

            mov eax, [ebx].number       ;// store the new cat
            stosd
            mov eax, [esi].cat_pointer  ;// store the old cat
            mov eax, (BUS_EDIT_RECORD PTR [eax]).number
            stosd
            mov eax, [esi].number       ;// store the member
            stosd

            ;// no need to update the pointer

        .ENDIF

    ;// xfer the member's cat pointer

        mov [esi].cat_pointer, ebx

    ;// determine how to select

        LISTBOX cat_hWnd, LB_GETITEMDATA, cat_cursel
        mov ebx, eax

        .IF ebx == [esi].cat_pointer

            ;// we moved a member INTO the current category
            ;// so we add the listitem and select it

            LISTBOX mem_hWnd, LB_ADDSTRING, 0, esi
            LISTBOX mem_hWnd, LB_SETCURSEL, eax

        .ELSE

            ;// we moved a member OUT of the current category
            ;// so we remove the item and select the next item

            LISTBOX mem_hWnd, LB_GETCURSEL      ;// get the current sel so we can reset it
            mov ebx, eax                        ;// store in ebx for safe keeping
            ;//invoke mem_locate_mem_index, esi ;// locate the index of this item
            LISTBOX mem_hWnd, LB_DELETESTRING, eax  ;// delete the item
            .IF eax < ebx       ;// make sure there IS a next item to select
                mov ebx, eax    ;// nope, decrease the selection index, neg value is ok
            .ENDIF
            LISTBOX mem_hWnd, LB_SETCURSEL, ebx ;// tell listbox

        .ENDIF

    ;// that's it

        ret

catmem_MemCat ENDP


ASSUME_AND_ALIGN
catmem_SetCatName PROC STDCALL USES ebx edi esi pCat:DWORD, pName:DWORD

    ;// set cat name

        mov ebx, pCat
        ASSUME ebx:PTR BUS_EDIT_RECORD

        lea edi, [ebx].cat_name
        mov esi, pName
        mov ecx, 8

        rep movsd

    ;// make sure category is displayed
    ;// set sel to cat

        invoke cat_locate_cat_index, ebx
        mov cat_cursel, eax
        invoke catmem_Update

    ;// that should do it

        ret

catmem_SetCatName ENDP

ASSUME_AND_ALIGN
catmem_SetMemName PROC STDCALL USES ebx edi esi pMem:DWORD, pName:DWORD

    ;// set member name

        mov ebx, pMem
        ASSUME ebx:PTR BUS_EDIT_RECORD

        lea edi, [ebx].mem_name
        mov esi, pName
        mov ecx, 8
        rep movsd

    ;// make sure mem.cat is displayed
    ;// cat sel = mem.cat

        mov eax, [ebx].cat_pointer
        invoke cat_locate_cat_index, eax
        LISTBOX cat_hWnd, LB_SETCURSEL, eax
        mov cat_cursel, -1
        invoke catmem_Update

    ;// mem sel = mem

        invoke mem_locate_mem_index, ebx
        LISTBOX mem_hWnd, LB_SETCURSEL, eax

    ;// that should do it

        ret

catmem_SetMemName ENDP





ASSUME_AND_ALIGN


ENDIF   ;// USE_THIS_FILE


END







