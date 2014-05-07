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
;// ABox_CreateMenu.asm             the create popup menu
;//
;//
;// TOC:
;//
;// create_Show
;//
;// create_Proc
;// create_wm_setcursor_proc
;// create_wm_command_proc
;// create_wm_activate_proc
;// create_wm_drawitem_proc
;// create_wm_create_proc
;// create_wm_keydown_proc
;// create_wm_contextmenu_proc
;// create_wm_paint_proc



OPTION CASEMAP:NONE

.586
.MODEL FLAT

        .NOLIST
        include <Abox.inc>
        .LIST
        ;//.LISTALL
        ;//.LISTMACROALL

comment ~ /*

    NOTES:


    the create menu is divided into three three rows of control groups

    the top row CONTROL has various editing commands

    the second row STATUS shows user what is being hovered

    the bottom row has the grid of buttons

        each button window stores a pointer to the base in GWL_USERDATA
        from there, the buttons name, ID, and rect may be retrieved


    new in abox208

        a wide mode will display text labels and a description

*/ comment ~


.DATA

    ;// these get defined in InitializeWindows

        create_atom     dd  0   ;// atom for the context menu class
        create_hWnd     dd  0   ;// hWnd for the context menu
        create_szName   db 'a_c',0 ;//  name of the context menu class

        create_statusHover dd 0 ;// pointer to the base class of the currently hovered button

    ;//
    ;// context window layout   ;// other sizes are defined in abox.inc
    ;//


    ;// the button grid is below

        CREATE_BUTTON_WIDTH  equ 24 ;// width of a create button
        CREATE_BUTTON_HEIGHT equ 26 ;// height of a create button

    ;// control buttons are on the top

        CREATE_CONTROL_WIDTH  equ 32    ;// width of the control buttons on the top
        CREATE_CONTROL_HEIGHT equ CREATE_BUTTON_HEIGHT/2    ;// height of same

    ;// column layout for control buttons

        CREATE_COL_0    equ 2
        CREATE_COL_1    equ CREATE_CONTROL_WIDTH    + CREATE_COL_0
        CREATE_COL_2    equ CREATE_CONTROL_WIDTH*2  + CREATE_COL_0
        CREATE_COL_3    equ CREATE_CONTROL_WIDTH*3  + CREATE_COL_0
        CREATE_COL_4    equ CREATE_CONTROL_WIDTH*4  + CREATE_COL_0
        CREATE_COL_5    equ CREATE_CONTROL_WIDTH*5  + CREATE_COL_0
        CREATE_COL_6    equ CREATE_CONTROL_WIDTH*6  + CREATE_COL_0

        CREATE_ROW_0    equ 2
        CREATE_ROW_01   equ CREATE_ROW_0+CREATE_CONTROL_HEIGHT
        CREATE_ROW_1    equ CREATE_ROW_0 + CREATE_CONTROL_HEIGHT*2
        CREATE_ROW_2    equ CREATE_ROW_1 + CREATE_STATUS_HEIGHT

    ;// description window

        CREATE_DESC_X   equ CREATE_COL_6 + CREATE_STATUS_HEIGHT/2
        CREATE_DESC_WID equ CREATE_WIDTH_LARGE - CREATE_DESC_X - 4
        CREATE_DESC_HIG equ CREATE_ROW_2 - CREATE_ROW_0

    ;// control button window handles

        create_hWnd_status      dd  0   ;// status line in either mode
        create_hWnd_desc        dd  0   ;// description in large mode

    ;// sizes for large and small mode

        create_width_small  dd  0
        create_width_large  dd  0
        create_height       dd  0

    ;// strings

        create_szClone      db 'Clone',0
        create_szLock       db 'Lock',0
        create_szUnlock     db 'Unlock',0
        create_szCopy       db 'Copy',0
        create_szPaste      db 'Paste',0
        create_szCut        db 'Cut',0
        create_szDelete     db 'Del',0
        create_szEscape     db 'Esc',0
        create_szPasteFile  db 'PFile',0
        create_szUnsel      db 'UnSel',0

        create_szUndo       db 'Undo',0
        create_szRedo       db 'Redo',0

    szDesc_start LABEL BYTE
        create_szClone_desc     db 'Duplicate selection. (Ins)',0
        create_szLock_desc      db 'Lock selection together. (Ctrl+L)',0
        create_szUnlock_desc    db 'UnLock selection. (Ctrl+K)',0
        create_szCopy_desc      db 'Copy selection. (Crtl+C Ctrl+Ins)',0
        create_szPaste_desc     db 'Paste. (Ctrl+V Shift+Ins)',0
        create_szCut_desc       db 'Copy + Delete. (Ctrl+X Shift+Del)',0
        create_szUndo_desc      db 'Undo previous action. (Ctrl+Z)',0
        create_szRedo_desc      db 'Redo last Undo. (Ctrl+Y)',0
        create_szDelete_desc    db 'Delete selection. (Del)',0
        create_szEscape_desc    db 'Return to previous view. (Esc)',0
        create_szPasteFile_desc db 'Paste from file. (Ctrl+B)',0
        create_szUnsel_desc     db 'Unselect All Objects. (Tab)',0
    szDesc_end  LABEL BYTE
        create_szStatus         db 'Right Click to change width',0

    CREATE_BUTTON_STYLE EQU WS_VISIBLE OR WS_CHILD OR BS_PUSHBUTTON

    CREATE_BUTTON   STRUCT

        hWnd    dd  0   ;   // hwnd of created button
        ID      dd  0   ;   // control id
        pText   dd  0   ;   // pointer to button text
        pDesc   dd  0   ;   // pointer to description text
        pos POINT  {}   ;   // position

        style dd CREATE_BUTTON_STYLE

        height dd CREATE_CONTROL_HEIGHT

    CREATE_BUTTON   ENDS


    CREATE_BUTTON_EX_STYLE EQU WS_EX_NOPARENTNOTIFY

    ALIGN 4
    create_button_first LABEL CREATE_BUTTON

    create_clone    CREATE_BUTTON { ,COMMAND_CLONE_SELECTED, OFFSET create_szClone, OFFSET create_szClone_desc, { CREATE_COL_0, CREATE_ROW_0    }}
    create_escape   CREATE_BUTTON { ,COMMAND_ESCAPE,    OFFSET create_szEscape, OFFSET create_szEscape_desc,    { CREATE_COL_0, CREATE_ROW_01   }}

    create_copy     CREATE_BUTTON { ,COMMAND_COPY,      OFFSET create_szCopy,   OFFSET create_szCopy_desc,      { CREATE_COL_1, CREATE_ROW_0    }}
    create_paste    CREATE_BUTTON { ,COMMAND_PASTE,     OFFSET create_szPaste,  OFFSET create_szPaste_desc,     { CREATE_COL_1, CREATE_ROW_01   }}

    create_cut      CREATE_BUTTON { ,COMMAND_CUT,       OFFSET create_szCut,    OFFSET create_szCut_desc,       { CREATE_COL_2, CREATE_ROW_0    }}
    create_delete   CREATE_BUTTON { ,COMMAND_DELETE_SELECTED,   OFFSET create_szDelete, OFFSET create_szDelete_desc,{ CREATE_COL_2, CREATE_ROW_01   }}

    create_paste_file CREATE_BUTTON{ ,COMMAND_PASTEFILE,OFFSET create_szPasteFile,OFFSET create_szPasteFile_desc,{CREATE_COL_3, CREATE_ROW_0    }}
    create_unsel    CREATE_BUTTON{ ,COMMAND_SELECT_CLEAR,OFFSET create_szUnsel,OFFSET create_szUnsel_desc,      {CREATE_COL_3,  CREATE_ROW_01   }}

    create_lock     CREATE_BUTTON { ,COMMAND_LOCK,      OFFSET create_szLock,   OFFSET create_szLock_desc,      { CREATE_COL_4, CREATE_ROW_0    }}
    create_unlock   CREATE_BUTTON { ,COMMAND_UNLOCK,    OFFSET create_szUnlock, OFFSET create_szUnlock_desc,    { CREATE_COL_4, CREATE_ROW_01   }}

    create_undo     CREATE_BUTTON { ,COMMAND_UNDO,      OFFSET create_szUndo,   OFFSET create_szUndo_desc,      { CREATE_COL_5, CREATE_ROW_0    }}
    create_redo     CREATE_BUTTON { ,COMMAND_REDO,      OFFSET create_szRedo,   OFFSET create_szRedo_desc,      { CREATE_COL_5, CREATE_ROW_01   }}

    create_terminator   dd  0,0




.CODE



ASSUME_AND_ALIGN
create_Show PROC STDCALL uses esi edi

        LOCAL point:POINT

    ;// get the current mouse position

        point_Get mouse_now
        point_Sub GDI_GUTTER
        point_Set point
        invoke ClientToScreen, hMainWnd, ADDR point

    ;// now we set up the top control buttons as required

        ;// see if we're showing a group

        xor eax, eax
        bt app_bFlags, LOG2(APP_MODE_IN_GROUP)
        adc eax, eax
        invoke EnableWindow, create_escape.hWnd, eax

        ;// enable the paste button

        xor eax, eax
        .IF file_bValidCopy
            inc eax
        .ENDIF
        invoke EnableWindow, create_paste.hWnd, eax

        ;// enable commands tha depend on a select list

        xor edi, edi
        stack_Peek gui_context, ecx
        clist_OrGetMRS oscS, edi, [ecx]
        .IF !ZERO?
            inc edi     ;// make sure the lowest bit is set
        .ENDIF
        invoke EnableWindow, create_copy.hWnd, edi
        invoke EnableWindow, create_cut.hWnd, edi
        invoke EnableWindow, create_delete.hWnd, edi
        invoke EnableWindow, create_clone.hWnd, edi

        invoke EnableWindow, create_lock.hWnd, edi
        invoke EnableWindow, create_unsel.hWnd, edi

        ;// if no item is locked, we should disable this
        invoke EnableWindow, create_unlock.hWnd, edi

        ;// then we take care of the undo redo
        ;// pCurrent != pHead   ;// enable undo
        ;// pCurrent != pTail   ;// enable redo

        mov edi, unredo_pCurrent
        sub edi, dlist_Head(unredo)
        .IF !ZERO?
            inc edi
        .ENDIF
        invoke EnableWindow, create_undo.hWnd, edi

        mov edi, unredo_pCurrent
        sub edi, dlist_Tail(unredo)
        .IF !ZERO?
            inc edi
        .ENDIF
        invoke EnableWindow, create_redo.hWnd, edi

        ;// now we go through and set the button status
        ;// for all items that connect to hardware

        slist_GetHead baseB, esi
        .REPEAT

            .IF [esi].data.dwFlags & BASE_HARDWARE

                invoke hardware_CanCreate, esi, 0
                invoke EnableWindow, [esi].display.button_hWnd, eax

            .ENDIF

            slist_GetNext baseB, esi

        .UNTIL !esi

    ;// reset the status hover to zero

        mov create_statusHover, 0

    ;// now we display the menu

        .IF app_settings.show & SHOW_CREATE_LARGE
            mov ecx, create_width_large
        .ELSE
            mov ecx, create_width_small
        .ENDIF

        invoke SetWindowPos, create_hWnd, HWND_TOPMOST,
            point.x, point.y,ecx,create_height,
            SWP_SHOWWINDOW

        or app_DlgFlags, DLG_CREATE

    ;// and take care of xmouse

        .IF app_xmouse

            point_Get point
            add eax, 8
            add edx, 8
            invoke SetCursorPos, eax, edx

        .ENDIF

    ;// that's it

        ret

create_Show ENDP






;////////////////////////////////////////////////////////////////////
;//
;// c r e a t e _ P r o c
;//


ASSUME_AND_ALIGN
create_Proc PROC

    mov eax, WP_MSG

    HANDLE_WM WM_SETCURSOR, create_wm_setcursor_proc
    HANDLE_WM WM_COMMAND,   create_wm_command_proc
    HANDLE_WM WM_ACTIVATE,  create_wm_activate_proc
    HANDLE_WM WM_DRAWITEM,  create_wm_drawitem_proc
    HANDLE_WM WM_CREATE,    create_wm_create_proc
    HANDLE_WM WM_KEYDOWN,   create_wm_keydown_proc
    HANDLE_WM WM_CONTEXTMENU,create_wm_contextmenu_proc
    HANDLE_WM WM_PAINT,     create_wm_paint_proc


    jmp DefWindowProcA

create_Proc ENDP


;////////////////////////////////////////////////////////////////////
;//
;//
;//     WM_SETCURSOR    hwnd = (HWND) wParam        ;// handle of window with cursor lParam:dword
;//                     nHittest = LOWORD(lParam)   ;// hit-test code  of window with cursor
;//                     wMouseMsg = HIWORD(lParam)  ;// mouse-message identifier
;//
ASSUME_AND_ALIGN
create_wm_setcursor_proc PROC PRIVATE   ;// STDCALL uses esi edi

;// stack: hWnd:dword, msg:dword, wParam:dword, lParam:dword
;//         04          08          0C          10

    ;// this is where we update the status text and make sure we have the focus


    ;// first, get the focus

        invoke GetFocus
        .IF eax != create_hWnd
            invoke SetFocus, create_hWnd
        .ENDIF

    ;// then update the status text

        mov eax, WP_WPARAM

        invoke GetWindowLongA, eax, GWL_USERDATA    ;// get the base class pointer

    ;// is this a button with a message to display ?

        or eax, eax
        jz no_displayable_text

        cmp eax, create_statusHover     ;// same as previous ?
        je all_done

            mov create_statusHover, eax ;// set the new value

            ;// see if dwUserData is a base class pointer

            .IF eax < OFFSET szDesc_start   ||  \
                eax > OFFSET szDesc_end

                ;// yes it is a base class, show the description
                ;// then get the status text

                .IF app_settings.show & SHOW_CREATE_LARGE
                    push eax
                    invoke SetWindowTextA, create_hWnd_desc, (OSC_BASE PTR [eax]).display.pszDescription
                    pop eax
                .ENDIF

                ;// get the pointer to the poup text for the status line

                mov eax, (OSC_BASE PTR [eax]).data.pPopupHeader
                push (POPUP_HEADER PTR [eax]).pName

            .ELSE   ;// need to shut off the previous text

                push eax
                pushd 0
                invoke SetWindowTextA, create_hWnd_desc, esp
                pop edx

            .ENDIF

            ;// set the window text, ttext pointer already on the stack
            push create_hWnd_status
            call SetWindowTextA

            jmp all_done

    no_displayable_text:    ;// eax = 0

        cmp create_statusHover, eax ;// is there a button display already on ??
        je all_done

        ;// this is not a button with a message to display
        ;// so we clear the status window and set the pointer to zero

        ;// xor eax, eax
        pushd eax
        mov create_statusHover, eax
        invoke SetWindowTextA, create_hWnd_status, esp
        invoke SetWindowTextA, create_hWnd_desc, esp
        pop edx

    all_done:

        xor eax, eax    ;// return zero
        ret 10h         ;// exit

create_wm_setcursor_proc ENDP
;//
;//     WM_SETCURSOR
;//
;//
;////////////////////////////////////////////////////////////////////








;////////////////////////////////////////////////////////////////////
;//
;//
;//     WM_COMMAND
;//
ASSUME_AND_ALIGN
create_wm_command_proc PROC PRIVATE


    ;// we send these to the main window

    mov eax, WP_WPARAM
    and eax, 0FFFFh
    jz all_done_1
    invoke PostMessageA, hMainWnd, WM_COMMAND, eax, 0

    ;// this trys to prevent that annoying flicker when calling up the dialog

    mov eax, WP_WPARAM
    and eax, 0FFFFh
    .IF eax != COMMAND_PASTEFILE
        mov eax, WP_HWND
        invoke ShowWindow, eax, SW_HIDE
    .ENDIF

all_done:

    xor eax, eax

all_done_1:

    ret 10h

create_wm_command_proc ENDP
;//
;//
;//     WM_COMMAND
;//
;////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////
;//
;//
;//     WM_ACTIVATE
;//
ASSUME_AND_ALIGN
create_wm_activate_proc PROC PRIVATE    ;// STDCALL uses esi edi hWnd:dword, msg:dword, wParam:dword, lParam:dword

    mov eax, WP_WPARAM                      ;// show or hide ?
    and eax, 0FFFFh                         ;//
    .IF ZERO?
        mov eax, WP_HWND                    ;// hide
        invoke ShowWindow, eax, SW_HIDE
        and app_DlgFlags, NOT DLG_CREATE
    .ELSE                                   ;// show
        or app_DlgFlags, DLG_CREATE
    .ENDIF
    pushd 0                                 ;// reset status text
    invoke SetWindowTextA, create_hWnd_status, esp
    pop eax                                 ;// return zero
    ret 10h

create_wm_activate_proc ENDP
;//
;//
;//     WM_ACTIVATE
;//
;////////////////////////////////////////////////////////////////////




;////////////////////////////////////////////////////////////////////
;//
;//     WM_DRAWITEM
;//     wParam  control identifier
;//     lParam  pDRAWITEMSTRUCT item-drawing information
;//
ASSUME_AND_ALIGN
create_wm_drawitem_proc PROC PRIVATE    ;// STDCALL PRIVATE uses ebx

    ;// this code draws the buttons in their correct state

    ;// stack:  hWnd:dword, msg:dword, wParam:dword, lParam:dword
    ;//         04          08         0C            10

    xchg ebx, WP_LPARAM                 ;// get and store
    ASSUME ebx:PTR DRAWITEMSTRUCT

    ;// if disbaled, just blank it out
    .IF [ebx].dwItemState & ODS_DISABLED

        invoke FillRect, [ebx].hDC, ADDR [ebx].rcItem, hBRUSH(0)

    .ELSE

    ;// blit the special graphics

        invoke GetWindowLongA, [ebx].hWndItem, GWL_USERDATA
        mov ecx, eax
        ASSUME ecx:PTR OSC_BASE

        pushd DIB_RGB_COLORS    ;// dwFlags
        lea eax, oBmp_bmih
        lea edx, oBmp_bits
        pushd eax           ;// bitmap info header
        pushd edx           ;// where the bits are
        pushd oBmp_height   ;// height of source
        point_Get [ecx].display.create_pos_bmp  ;// load the icon's frame
        pushd 0             ;// first scan line
        pushd edx           ;// source Y
        pushd eax           ;// source X
        pushd 20            ;// source height
        point_GetTL [ebx].rcItem
        pushd [ecx].display.create_siz.x    ;// source width
        add edx, 2
        add eax, 2
        pushd edx           ;// dest Y
        pushd eax           ;// dest X
        pushd [ebx].hDC
        call SetDIBitsToDevice

    ;// draw the button in it's correct state

        mov edx, EDGE_RAISED

        .IF (   [ebx].dwItemAction & ODA_DRAWENTIRE && \
                [ebx].dwItemState & (ODS_CHECKED OR ODS_SELECTED ) ) || \
            (   [ebx].dwItemAction & ODA_SELECT && \
                [ebx].dwItemState & ODS_SELECTED )

                ;// add edx, 24     ;// pushed buttons are below
        ;//     or edx, DFCS_PUSHED

                mov edx, EDGE_SUNKEN

        .ENDIF

        invoke DrawEdge, [ebx].hDC, ADDR [ebx].rcItem, edx,  BF_TOP OR BF_LEFT OR BF_RIGHT OR BF_BOTTOM

    .ENDIF


    ;// that's it

    xchg ebx, WP_LPARAM     ;// retrieve
    inc eax                 ;// return true
    ret 10h                 ;// exit

create_wm_drawitem_proc ENDP
;//
;//     WM_DRAWITEM
;//
;//
;////////////////////////////////////////////////////////////////////








;////////////////////////////////////////////////////////////////////
;//
;//
;//     WM_CREATE
;//
ASSUME_AND_ALIGN
create_wm_create_proc PROC STDCALL PRIVATE uses ebx esi edi hWnd:dword, msg:dword, wParam:dword, lParam:dword

    LOCAL rect:RECT

    ;// first off, store the hWnd

        mov eax, hWnd
        mov create_hWnd, eax

    ;// step one is to create the window sizes

        xor ecx, ecx
        mov rect.left, ecx
        mov rect.top, ecx
        mov rect.right, CREATE_WIDTH
        mov rect.bottom, CREATE_HEIGHT

        invoke AdjustWindowRectEx, ADDR rect, CREATE_STYLE, 0, CREATE_STYLE_EX

        point_GetBR rect
        point_SubTL rect
        mov create_width_small, eax
        mov create_height, edx

        mov rect.left, 0
        mov rect.right, CREATE_WIDTH_LARGE

        invoke AdjustWindowRectEx, ADDR rect, CREATE_STYLE, 0, CREATE_STYLE_EX

        mov eax, rect.right
        sub eax, rect.left
        mov create_width_large, eax

    ;// create the buttons on the top row

        lea esi, create_button_first
        ASSUME esi:PTR CREATE_BUTTON
        lea ebx, szButton

        .REPEAT

            invoke CreateWindowExA, CREATE_BUTTON_EX_STYLE, ebx,
                [esi].pText,    [esi].style,
                [esi].pos.x, [esi].pos.y,
                CREATE_CONTROL_WIDTH, [esi].height,
                hWnd, [esi].ID, hInstance, 0

            mov [esi].hWnd, eax

            invoke PostMessageA, eax, WM_SETFONT, hFont_pin, 1

            invoke SetWindowLongA, [esi].hWnd, GWL_USERDATA, [esi].pDesc

            add esi, SIZEOF CREATE_BUTTON

        .UNTIL !([esi].ID)

    ;// create the status bar
                                ;WS_EX_NOPARENTNOTIFY
        invoke CreateWindowExA, 0, OFFSET szStatic,
            0,              WS_VISIBLE OR WS_CHILD OR SS_NOTIFY,
            CREATE_COL_0,   CREATE_ROW_1,   CREATE_COL_6,   CREATE_STATUS_HEIGHT,
            hWnd,   0,      hInstance, 0
        mov create_hWnd_status, eax
        invoke PostMessageA, eax, WM_SETFONT, hFont_popup, 1
        invoke SetWindowLongA, create_hWnd_status, GWL_USERDATA, OFFSET create_szStatus

    ;// create the description
                                ;//WS_EX_NOPARENTNOTIFY
        invoke CreateWindowExA, 0, OFFSET szStatic,
            0,              WS_VISIBLE + WS_CHILD OR SS_NOTIFY,
            CREATE_DESC_X,  0,      CREATE_DESC_WID,    CREATE_DESC_HIG,
            hWnd,   0,      hInstance, 0
        mov create_hWnd_desc, eax
        invoke PostMessageA, eax, WM_SETFONT, hFont_help, 1
        invoke SetWindowLongA, create_hWnd_desc, GWL_USERDATA, OFFSET create_szStatus


    ;// then create all the object insert buttons, define the text rects while we're at it

        invoke GetDC, create_hWnd
        mov ebx, eax
        invoke SelectObject, ebx, hFont_pin
        invoke SetBkMode, ebx, TRANSPARENT
        invoke GetSysColor, COLOR_WINDOWTEXT
        invoke SetTextColor, ebx, eax

        .IF app_settings.show & SHOW_CREATE_LARGE
            mov esi, OFFSET OSC_BASE.display.create_pos_large
        .ELSE
            mov esi, OFFSET OSC_BASE.display.create_pos_small
        .ENDIF
        ASSUME esi:PTR POINT

        slist_GetHead baseB, edi
        .REPEAT

        ;// create this button at the correct location

            invoke CreateWindowExA, WS_EX_NOPARENTNOTIFY, OFFSET szButton, 0,
                WS_VISIBLE + WS_CHILD + BS_OWNERDRAW,
                [edi+esi].x, [edi+esi].y,
                [edi].display.create_siz.x, [edi].display.create_siz.y,
                hWnd, [edi].data.ID, hInstance, 0

        ;// store the hWnd in OSC_BASE.icon.button_hWnd

            mov [edi].display.button_hWnd, eax

        ;// set the base class pointer in GWL_USER

            invoke SetWindowLongA, eax, GWL_USERDATA, edi

        ;// define the text rect
        ;// there are buttons that don't fall in the right place
        ;// we trap for them here

            .IF edi == OFFSET osc_Probe

                ;// move left and down
                ;// align top

                sub [edi].display.create_text_rect.left, CREATE_ICON_WID_UNIT * 2
                add [edi].display.create_text_rect.top, CREATE_ICON_HIG_UNIT
                sub [edi].display.create_text_rect.right, CREATE_ICON_WID_UNIT * 2
                add [edi].display.create_text_rect.bottom, CREATE_ICON_HIG_UNIT

                invoke DrawTextA, ebx, [edi].display.pszShortName,-1,ADDR [edi].display.create_text_rect, DT_CALCRECT OR DT_WORDBREAK OR DT_NOPREFIX

            .ELSEIF edi == OFFSET osc_PinInterface

                ;// move left and up
                ;// align bottom

                sub [edi].display.create_text_rect.left, CREATE_ICON_WID_UNIT * 3
                sub [edi].display.create_text_rect.top, CREATE_ICON_HIG_UNIT / 2
                sub [edi].display.create_text_rect.right, CREATE_ICON_WID_UNIT * 2
                sub [edi].display.create_text_rect.bottom, CREATE_ICON_HIG_UNIT

                invoke DrawTextA, ebx, [edi].display.pszShortName,-1,ADDR [edi].display.create_text_rect, DT_CALCRECT OR DT_NOPREFIX

            .ELSE


                invoke DrawTextA, ebx, [edi].display.pszShortName,-1,ADDR [edi].display.create_text_rect, DT_CALCRECT OR DT_WORDBREAK OR DT_NOPREFIX

                ;// then center it vertically
                ;// top and bottom need to be offset by (max_height - act_height)/2

                neg eax
                add eax, CREATE_BUTTON_HEIGHT
                shr eax, 1

                add [edi].display.create_text_rect.top, eax
                add [edi].display.create_text_rect.bottom, eax

            .ENDIF

        ;// iterate

            slist_GetNext baseB, edi

        .UNTIL !edi

        invoke ReleaseDC, create_hWnd, ebx

    ;// disable undo and redo

        invoke EnableWindow, create_undo.hWnd, 0
        invoke EnableWindow, create_redo.hWnd, 0

    ;// then call update positions to get the layout right

    ;// return true

        mov eax, 1

        ret

create_wm_create_proc ENDP




;/////////////////////////////////////////////////////////////////////////
;//
;//                     escape key is all we care about
;//     WM_KEYDOWN
;//
ASSUME_AND_ALIGN
create_wm_keydown_proc PROC PRIVATE

    mov eax, WP_WPARAM
    cmp eax, VK_ESCAPE
    jz @F
    jmp DefWindowProcA
@@: invoke SetFocus, hMainWnd

    xor eax, eax
    ret 10h

create_wm_keydown_proc ENDP
;//
;//     WM_KEYDOWN
;//                     escape key is all we care about
;//
;/////////////////////////////////////////////////////////////////////////









;/////////////////////////////////////////////////////////////////////////
;//
;//                     changes between small and wide mode
;//     WM_CONTEXTMENU
;//
ASSUME_AND_ALIGN
create_wm_contextmenu_proc PROC

    xor app_settings.show, SHOW_CREATE_LARGE

    push ebx
    push edi

    ;// our task here is:
    ;//
    ;//     define the window size
    ;//     define the locations of the buttons


    .IF app_settings.show & SHOW_CREATE_LARGE
        mov ebx, OFFSET OSC_BASE.display.create_pos_large
    .ELSE
        mov ebx, OFFSET OSC_BASE.display.create_pos_small
    .ENDIF

    ASSUME ebx:PTR POINT

    slist_GetHead baseB, edi
    .REPEAT

        invoke MoveWindow, [edi].display.button_hWnd,
            [edi+ebx].x,                [edi+ebx].y,
            [edi].display.create_siz.x, [edi].display.create_siz.y, 0

        slist_GetNext baseB, edi

    .UNTIL !edi

    .IF app_settings.show & SHOW_CREATE_LARGE
        mov ecx, create_width_large
    .ELSE
        mov ecx, create_width_small
    .ENDIF

    invoke SetWindowPos, create_hWnd, HWND_TOPMOST,
        0, 0,ecx,create_height,
        SWP_SHOWWINDOW OR SWP_NOMOVE OR SWP_NOCOPYBITS

    pop ebx
    pop edi

    xor eax, eax

    ret 10h

create_wm_contextmenu_proc ENDP
;//
;//     WM_CONTEXT
;//                     changes between small and wide mode
;//
;/////////////////////////////////////////////////////////////////////////


;/////////////////////////////////////////////////////////////////////////
;//
;//                     draws the labels if large mode
;//     WM_PAINT
;//
ASSUME_AND_ALIGN
create_wm_paint_proc PROC

        .IF !(app_settings.show & SHOW_CREATE_LARGE)
            jmp DefWindowProcA
        .ENDIF

        push edi
        push ebx

        sub esp, SIZEOF PAINTSTRUCT
        invoke BeginPaint, create_hWnd, esp
        mov ebx, eax

        slist_GetHead baseB, edi
        .REPEAT

            invoke DrawTextA, ebx, [edi].display.pszShortName,-1,
                ADDR [edi].display.create_text_rect, DT_WORDBREAK OR DT_NOPREFIX
            slist_GetNext baseB, edi

        .UNTIL !edi

    ;// push ebx
    ;// call SelectObject

        invoke EndPaint, create_hWnd, esp
        add esp, SIZEOF PAINTSTRUCT
        pop ebx
        pop edi

        xor eax, eax
        ret 10h

create_wm_paint_proc ENDP
;//
;//     WM_PAINT
;//                     draws the labels if large mode
;//
;/////////////////////////////////////////////////////////////////////////




















ASSUME_AND_ALIGN

END



