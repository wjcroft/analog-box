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
;//                         tired of the clumsy menus, and dialog boxes don't cut it
;// ABox_popup.ASM          so here's code to manage all the osc_context functions
;//                         the window will stay on until it looses focus
;//                         or a menu item is hit
;//
;// TOC                     a couple years later: this has been complicated !!
;//
;// popup_Show
;// popup_BuildControls
;//
;// popup_call_base_class
;//
;// popup_Proc
;// popup_wm_command_proc
;// popup_wm_keydown_proc
;// popup_wm_close_proc
;// popup_wm_activate_proc
;// popup_wm_scroll_proc
;// popup_wm_setcursor_proc
;// popup_wm_ctlcolorlistbox_proc
;// popup_wm_drawitem_proc


comment ~ /*

    notes:

    COMMANDS

        popup passes command id's to the object->_Command function in eax
        object._Command should pass unhandled commands to the osc_Command function

    BUTTONS

        button control ID's should match their hot-key equivalent
        popup will send these to the osc_Control function specified in the
        the object's base class.

    SCROLL BARS

        popup assumes that all scrolls are to produce numbers between 0 and 255
        osc_InitMenu is resposible for setting up the scroll bar
        popup takes care manipulating the scroll bar display
        popup_object->osc_command will be called directly
        and popup will disregard the return value

        there is a designated range of scroll bar ID's that start at OSC_COMMAND_SCROLL
        and include the next 256 values. These are passed in eax and should be interperted
        as a SCROLL_VALUE_CHANGED command.
        ecx will contain the new current position, so be careful about that

    LISTBOXES

        popup will only respond to double clicks
        popup assumes that the desired command id is in the list item's private data
        and will call object.osc_command directly and respond to the return value

        popup passes OSC_COMMAND_LIST_DBLCLICK in eax
        and the currently selected item's ID in ecx

    EDITBOXES

        Objects that need editboxes (excluding the label object)
        may recieve any of these messages

        OSC_COMMAND_EDIT_CHANGE indicating the edit text has changed
        OSC_COMMAND_EDIT_FOCUS some panels need to make sure thatt edit boxes
        do not maintain the keyboard focus. Handling this command allows them
        to return a popup_return_value stating so
        OSC_COMMAND_EDIT_KILLFOCUS panels that need to no when an edit box
        looses focus can handle this command

        in all cases, the edit boxes control id is sent in ecx

    REGISTERS

        osc_Command overrides must preserve esi and ebp

    HELP STRINGS

        popup_Show will expand the dialog window
        popup_BuildControls will scoot all controls down
        and set GWL_DWUSER as the pointer from the popup header
        From there, WM_SETCURSOR will do the rest

        thus:

            WM_SETCURSOR assumes that GWL_DWUSER is a pointer to a text string


*/ comment ~

OPTION CASEMAP:NONE

.586
.MODEL FLAT

        .NOLIST
        INCLUDE <Abox.inc>
        INCLUDE <vst.inc>
        .LIST

.DATA

    popup_hWnd      dd  0
    popup_Object    dd  0   ;// ptr to the object we're working with
    popup_bDelete   dd  0   ;// set true if delete was hit
                            ;// needed to prevent checking if we route the deactivate
                            ;// to the object after it's been deleted

    popup_bShowing      dd  0   ;// interlock flag used when building the panel

    popup_hLastTopmost  dd  0   ;// if disabled, then set this so we can force it to the top

    popup_hFocus        dd  0   ;// if an object needs it's focus set, we do that here

    popup_status_ptext  dd  0   ;// last known help text pointer
    popup_status_hWnd   dd  0   ;// hWnd for the status, sometimes we need to remove this


    ;// combo and list box help tracking

    popup_ComboBox_sel  dd  -1  ;// index of previous list box selection, see popup_wm_ctlcolorlistbox_proc
    popup_ComboBox_hWnd dd  0   ;// hWnd of the combo bow we're supposed to use
    popup_ComboBox_ID   dd  0   ;// id of the combo box

    popup_EndActionAlreadyCalled    dd  0   ;// solves a problem with diff equation editor
                                            ;// looseing focus and storing unredo
                                ;// abox231: also used in opened_group_Command

    popup_no_undo   dd  0   ;// popup will call endaction when loosing focus
                            ;// this prevents that
    comment ~ /*

    NOTE: popup_no_undo has the following behavior

        if it's 'on' then when popup dlg looses focus,
            it will hide, but it will will NOT reset APP_DLG_POPUP
            if a routine that doesn't return to popup (like osc_Clone)
            is going to set popup_no_undo, it must reset APP_DLG_POPUP

        if it's off, the when  popup dlg looses focus,
            it will reset APP_DLG_POPUP
            and call unredo_EndAction

    */ comment ~


    ;// virtual focus   implemented ABox221

    popup_bVirtFocus    dd  0   ;// virt focus is on
    popup_hWndFocus     dd  0   ;// handle of the virtual focus

    VIRT_FOCUS_OFFSET   EQU 8   ;// mouse offset we move with


.CODE


;////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
popup_Show PROC STDCALL uses esi edi ebx pObject:PTR OSC_OBJECT

        LOCAL point:POINT
        LOCAL rect:RECT
        LOCAL rect2:RECT
        LOCAL showwnd_flags:DWORD
        LOCAL siz:POINT     ;// desired client size

DEBUG_IF <popup_bShowing>

inc popup_bShowing

MESSAGE_LOG_TEXT <popup_Show__ENTER>, INDENT

        DEBUG_IF < popup_no_undo >  ;// this will cause problems later on

        GET_OSC esi

    ;// determine how we show this window

        .IF popup_Object == esi
            ;// we're still initialized
            ;// meaning we don't want to move the dialog
            mov showwnd_flags, SWP_NOMOVE + SWP_SHOWWINDOW
        .ELSE
            mov showwnd_flags, SWP_SHOWWINDOW
            mov popup_Object, esi
        .ENDIF

    ;// set the title and create all the buttons and labels we'll need

        OSC_TO_BASE esi, edi
        invoke popup_BuildControls,
            popup_hWnd,
            [edi].data.pPopupHeader,
            [edi].display.pszDescription,
            [edi].data.dwFlags

    ;// check if we enable the delete and clone menus

        invoke GetMenu, popup_hWnd
        mov ebx, eax

        ;// if this object is a hardware device, we check if we can clone it

            mov ecx, MF_BYCOMMAND + MF_ENABLED
            .IF [edi].data.dwFlags & BASE_HARDWARE

                invoke hardware_CanCreate, edi, 0
                or eax, eax
                jnz @F
                mov ecx, MF_BYCOMMAND + MF_GRAYED
            @@:
            .ENDIF
            invoke EnableMenuItem, ebx, COMMAND_CLONE, ecx

        ;// if this osc is a pin interface, we check if we can delete it

            mov ecx, MF_BYCOMMAND + MF_ENABLED
            .IF edi == OFFSET osc_PinInterface  &&  \
                app_bFlags & APP_MODE_IN_GROUP

                test [esi].dwHintOsc, HINTOSC_STATE_HAS_GROUP
                jz @F
                mov ecx, MF_BYCOMMAND + MF_GRAYED
            @@:
            .ENDIF
            invoke EnableMenuItem, ebx, COMMAND_DELETE, ecx

    ;// call the init function for this object
    ;// if there isn't one, then use the default size
    ;// if the function returns eax != 0 then use eax, edx as the size

        xor eax, eax
        mov popup_hFocus, eax
        mov popup_hLastTopmost, eax

        .IF eax != [edi].gui.InitMenu

            push ebp
            stack_Peek gui_context, ebp
            MESSAGE_LOG_TEXT <popup_Show__guis_initmenu_ENTER>, INDENT
            invoke [edi].gui.InitMenu
            MESSAGE_LOG_TEXT <popup_Show__guis_initmenu_LEAVE>, UNINDENT
            pop ebp

            ;// init menu tells us if the size is changed
            ;// by setting eax and edx as the desired client sizes

        .ENDIF

    ;// determine the proper size and position

        .IF !eax

            mov ecx, [edi].data.pPopupHeader
            ASSUME ecx:PTR POPUP_HEADER
            point_Get [ecx].siz
            add edx, POPUP_HELP_HEIGHT
            .IF [edi].data.dwFlags & BASE_NEED_THREE_LINES
                add edx, POPUP_HELP_HEIGHT/2
            .ENDIF

        .ELSEIF popup_status_hWnd && !([edi].data.dwFlags & BASE_FORCE_DISPLAY_STATUS)

            ;// now we need to remove the status
            push eax
            push edx

            invoke DestroyWindow, popup_status_hWnd
            mov popup_status_hWnd, 0

            pop edx
            pop eax

        .ENDIF

        mov rect.left, 0
        mov rect.top, 0
        point_SetBR rect
        point_Set siz   ;// store to double check

    ;// then we condition the rect so we can use it to define the dialog size

        invoke AdjustWindowRectEx, ADDR rect, POPUP_STYLE, 1, POPUP_STYLE_EX

        ;// now the rectangle is the proper size
        ;// our next task is to put it where we can see it
        ;// and make it a (position, size) rectangle

        ;// first we'll convert rect to pos and size

        mov eax, rect.right
        mov edx, rect.bottom
        sub eax, rect.left
        sub edx, rect.top
        mov rect.right, eax
        mov rect.bottom, edx

        ;// then we set point as the desired position
        ;// that'll be at the bottom of the osc

        mov ecx, [esi].rect.bottom  ;// load the current position
        mov edi, [esi].rect.left
        sub ecx, GDI_GUTTER_Y
        sub edi, GDI_GUTTER_X
        mov point.x, edi
        mov point.y, ecx
        invoke ClientToScreen, hMainWnd, ADDR point

        ;// now we check the bottom left corner
        ;// and force it to be on the screen

        point_Get point
        add eax, rect.right
        add edx, rect.bottom

        sub eax, gdi_desk_size.x
        .IF !SIGN? && !ZERO?
            sub point.x, eax
            .IF SIGN?
                mov point.x, 0
            .ENDIF
        .ENDIF

        sub edx, gdi_desk_size.y
        .IF !SIGN? && !ZERO?
            sub point.y, edx
            .IF SIGN?
                mov point.y, 0
            .ENDIF
        .ENDIF

    ;// now we display the window
        MESSAGE_LOG_TEXT <popup_Show__SetWindowPos_1_display__BEGIN>, INDENT
        invoke SetWindowPos, popup_hWnd, HWND_TOP,
            point.x, point.y, rect.right, rect.bottom, showwnd_flags
        MESSAGE_LOG_TEXT <popup_Show__SetWindowPos_1_display__DONE>, UNINDENT

        ;// for some reason, we don't get any clue if the menu wraps
        ;// so we'll trick this routine to do that

        MESSAGE_LOG_TEXT <popup_Show__SetWindowPos_2_resize__BEGIN>, INDENT
        invoke SetWindowPos, popup_hWnd, HWND_TOP, point.x, point.y, rect.right, rect.bottom, showwnd_flags
        MESSAGE_LOG_TEXT <popup_Show__SetWindowPos_2_resize__END>, UNINDENT
        invoke GetClientRect, popup_hWnd, ADDR rect2

        mov eax, siz.x
        mov edx, siz.y
        sub eax, rect2.right
        sub edx, rect2.bottom
        .IF eax || edx

            ;// client rect is too small
            add rect.right, eax
            add rect.bottom, edx

            MESSAGE_LOG_TEXT <popup_Show__SetWindowPos_3_resize__BEGIN>, INDENT
            invoke SetWindowPos,
                popup_hWnd,
                HWND_TOP,
                point.x,
                point.y,
                rect.right,
                rect.bottom,
                showwnd_flags
            MESSAGE_LOG_TEXT <popup_Show__SetWindowPos_3_resize__END>, UNINDENT

        .ENDIF

    ;// then we set the focus if it was set

        mov eax, popup_hFocus
        .IF eax
            MESSAGE_LOG_TEXT <popup_Show__setting_focus_BEGIN>, INDENT
            invoke SetFocus, eax
            MESSAGE_LOG_TEXT <popup_Show__setting_focus_END>, UNINDENT
        .ENDIF

    ;// lastly, we do the xmouse test

        .IF app_xmouse
            point_Get point
            add eax, 8
            add edx, 8
            invoke SetCursorPos, eax, edx
        .ENDIF

    ;// that's it


    MESSAGE_LOG_TEXT <popup_Show__LEAVE>, UNINDENT

dec popup_bShowing
DEBUG_IF <!!ZERO?>  ;// lost sync with this


        ret

popup_Show ENDP



.DATA

    ;// jmp table for type handlers

    popup_type_jump LABEL   DWORD

    dd  popup_type_end      ;// 0
    dd  popup_type_label    ;// 1
    dd  popup_type_button   ;// 2
    dd  popup_type_edit     ;// 3
    dd  popup_type_scroll   ;// 4
    dd  popup_type_list     ;// 5
    dd  popup_type_combo    ;// 6


.CODE

;////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
popup_BuildControls PROC STDCALL USES esi edi ebx hWnd:DWORD, pPopup:DWORD, bUseHelp:DWORD, dwFlags:DWORD

    MESSAGE_LOG_TEXT <popup_BuildControls__ENTER>, INDENT
    ;// this builds and places controls in a window
    ;// uses popup_Header data to do so

    ;// note: bUseHelp must be a pointer to the popup desicription text
    ;// it is the text to be displayed while the status window is hovered

        mov esi, pPopup
        ASSUME esi:PTR POPUP_HEADER

    ;// set the title

        WINDOW hWnd, WM_SETTEXT,0,[esi].pName

    ;// set popup bHelp to be useful

        mov ebx, bUseHelp
        .IF ebx

            mov bUseHelp, POPUP_HELP_HEIGHT ;// set as generic status height
            .IF dwFlags & BASE_NEED_THREE_LINES
                add bUseHelp, POPUP_HELP_HEIGHT/2
            .ENDIF

        ;// define the status window

            invoke CreateWindowExA, 0, OFFSET szStatic,
                0,  WS_VISIBLE OR WS_CHILD OR SS_NOTIFY OR SS_OWNERDRAW,
                0,  0,  [esi].siz.x,    bUseHelp,
                hWnd,   ID_POPUP_HELP,      hInstance, 0

            mov popup_status_hWnd, eax  ;// store just in case
            invoke PostMessageA, eax, WM_SETFONT, hFont_help, 1

            mov popup_status_ptext, 0   ;// reset the text pointer

            invoke  SetWindowLongA, hWnd, GWL_USERDATA, popup_status_hWnd   ;// link in the control
            invoke  SetWindowLongA, popup_status_hWnd, GWL_USERDATA, ebx    ;// set the description

        .ENDIF

    ;// build all the controls

    add esi, SIZEOF POPUP_HEADER    ;// esi iterates each control in the dialog

    top_of_loop:

        mov eax, DWORD PTR [esi]    ;// get the type
        mov ecx, bUseHelp           ;// shove the top of the control down
        and eax, 0FFFFh             ;// strip out any extra
        DEBUG_IF <eax !> POPUP_LAST_TYPE>
        jmp popup_type_jump[eax*4]  ;// determine which type of control we're building


    ALIGN 16
    popup_type_label::  ;// POPUP_TYPE_LABEL

            ASSUME esi:PTR POPUP_ITEM_LABEL

            add ecx, [esi].rect.top

            invoke CreateWindowExA, WS_EX_NOPARENTNOTIFY, OFFSET szStatic, [esi].pText,
                [esi].dwStyle,
                [esi].rect.left, ecx, [esi].rect.right, [esi].rect.bottom,
                hWnd, [esi].cmdID, hInstance, 0
            DEBUG_IF<!!eax>
            mov ebx, [esi].pHelp
            mov edi, eax
            add esi, SIZEOF POPUP_ITEM_LABEL

            jmp popup_type_handled

    ALIGN 16
    popup_type_button:: ;// POPUP_TYPE_BUTTON

            ASSUME esi:PTR POPUP_ITEM_BUTTON

            add ecx, [esi].rect.top

            invoke CreateWindowExA, WS_EX_NOPARENTNOTIFY , OFFSET szButton, [esi].pText,
                [esi].dwStyle,
                [esi].rect.left, ecx, [esi].rect.right, [esi].rect.bottom,
                hWnd, [esi].cmdID, hInstance, 0
            DEBUG_IF<!!eax>
            mov edi, eax        ;// store the handle

            .IF [esi].dwStyle & BS_BITMAP   ;// check for bitmap

                mov eax, [esi].dwType
                shr eax, 16
                mov eax, button_bitmap_table[eax*4]

                WINDOW edi, BM_SETIMAGE, IMAGE_BITMAP, eax

                or eax, -1  ;// don't set font

            .ENDIF

            mov ebx, [esi].pHelp
            add esi, SIZEOF POPUP_ITEM_BUTTON

            jmp popup_type_handled

    ALIGN 16
    popup_type_edit::   ;// POPUP_TYPE_EDIT

            ASSUME esi:PTR POPUP_ITEM_EDIT

            add ecx, [esi].rect.top

            invoke CreateWindowExA, WS_EX_NOPARENTNOTIFY, OFFSET szEdit, 0,
                [esi].dwStyle,
                [esi].rect.left, ecx, [esi].rect.right, [esi].rect.bottom,
                hWnd, [esi].cmdID, hInstance, 0
            DEBUG_IF<!!eax>
            mov ebx, [esi].pHelp
            mov edi, eax
            add esi, SIZEOF POPUP_ITEM_EDIT
            or eax, -1      ;// don't set the font

            jmp popup_type_handled

    ALIGN 16
    popup_type_scroll::     ;// POPUP_TYPE_SCROLL

            ASSUME esi:PTR POPUP_ITEM_SCROLL

            add ecx, [esi].rect.top

            invoke CreateWindowExA, WS_EX_NOPARENTNOTIFY, OFFSET szScrollBar, 0,
                [esi].dwStyle,
                [esi].rect.left, ecx, [esi].rect.right, [esi].rect.bottom,
                hWnd, [esi].cmdID, hInstance, 0
            DEBUG_IF<!!eax>
            mov ebx, [esi].pHelp
            mov edi, eax
            add esi, SIZEOF POPUP_ITEM_SCROLL
            or eax, -1      ;// don't set the font

            jmp popup_type_handled

    ALIGN 16
    popup_type_list::   ;// POPUP_TYPE_LIST

            ASSUME esi:PTR POPUP_ITEM_LIST

            add ecx, [esi].rect.top

            invoke CreateWindowExA, WS_EX_NOPARENTNOTIFY, OFFSET szListBox, 0,
                [esi].dwStyle,
                [esi].rect.left, ecx, [esi].rect.right, [esi].rect.bottom,
                hWnd, [esi].cmdID, hInstance, 0
            DEBUG_IF<!!eax>
            mov ebx, [esi].pHelp
            mov edi, eax
            add esi, SIZEOF POPUP_ITEM_LIST

            jmp popup_type_handled


    ALIGN 16
    popup_type_combo::  ;// POPUP_TYPE_COMBO

            ASSUME esi:PTR POPUP_ITEM_COMBO

            add ecx, [esi].rect.top
            ;// combo boxes need a nudge to get the drop list height correct
            mov edx, [esi].rect.bottom
            shl edx, 3  ;// x8

            invoke CreateWindowExA, WS_EX_NOPARENTNOTIFY, OFFSET szComboBox, 0,
                [esi].dwStyle,
                [esi].rect.left, ecx, [esi].rect.right, edx,
                hWnd, [esi].cmdID, hInstance, 0
            DEBUG_IF<!!eax>
            mov ebx, [esi].pHelp
            mov edi, eax
            add esi, SIZEOF POPUP_ITEM_COMBO

            or popup_ComboBox_sel, -1   ;// reset this, see popup_wm_ctlcolorlistbox_proc
            mov popup_ComboBox_hWnd, 0
            mov popup_ComboBox_ID, 0

        ;// jmp popup_type_handled


    ALIGN 16
    popup_type_handled:

        DEBUG_IF <!!eax>, GET_ERROR ;// couldn't create a window

        ;// eax has the window handle, and we want to set the font
        .IF eax != -1
            invoke PostMessageA, eax, WM_SETFONT, hFont_popup, 1
        .ENDIF

        ;// edi also has the handle and ebx has the pointer to the help text

        invoke SetWindowLongA, edi, GWL_USERDATA, ebx

        jmp top_of_loop

    popup_type_end::

    ;// that's it

MESSAGE_LOG_TEXT <popup_BuildControls__END>, UNINDENT

    ret

popup_BuildControls ENDP






ASSUME_AND_ALIGN
popup_CleanupWindow PROC

MESSAGE_LOG_TEXT <popup_CleanupWindow_ENTER>, INDENT

    ;// destroy child windows

    W1: invoke GetWindow, popup_hWnd, GW_CHILD
        TESTJMP eax, eax, jz W2
        invoke DestroyWindow, eax
        jmp W1
    W2: mov popup_status_hWnd, eax  ;// we just destroyed it

    ;// remove extra menu items

    W3: invoke GetMenu, popup_hWnd
        invoke DeleteMenu, eax, 2, MF_BYPOSITION
        TESTJMP eax, eax, jnz W3

    ;// make sure popup and hMainWnd are enabled

        invoke GetWindowLongA, popup_hWnd, GWL_STYLE
        .IF eax & WS_DISABLED
            invoke EnableWindow, popup_hWnd, 1
        .ENDIF

        invoke GetWindowLongA,hMainWnd,GWL_STYLE
        .IF eax & WS_DISABLED
            invoke EnableWindow, hMainWnd, 1
        .ENDIF

        xor eax, eax    ;// ABOX237 bug, would cause tab system to crash

        mov popup_hLastTopmost, eax

    ;// reset the virtual focus messages

        mov popup_bVirtFocus, eax
        mov popup_hWndFocus, eax

    ;// that should do it

MESSAGE_LOG_TEXT <popup_CleanupWindow_LEAVE>, UNINDENT
        ret

popup_CleanupWindow ENDP
















;////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////
;///
;///                                use this to call osc command when nessesary
;///    popup call base class


ASSUME_AND_ALIGN
popup_call_base_class PROC

        ASSUME esi:PTR OSC_OBJECT   ;// must be passed by caller
        ASSUME edi:PTR OSC_BASE     ;// also passed by caller
        ;//    ebx should be a handle to the window to recieve the focus
        ;//    eax must have command id
        ;//    ecx must have extra value if nessesary

        push ebp

            stack_Peek gui_context, ebp

            push ebx                    ;// have to preserve
            push eax
            push ecx
            ENTER_PLAY_SYNC GUI
            pop ecx
            pop eax
            invoke [edi].gui.Command    ;// call it's command handler
            push eax
            LEAVE_PLAY_SYNC GUI

            FPU_STACK_TEST          ;// what ever just Commanded did not clean up the stack

            pop eax
            pop ebx                     ;// time to retrieve

            TESTJMP eax, POPUP_IGNORE, jnz all_done

        ;// process what gui.CommandReturned

        push eax    ;// store return value on the stack

            DEBUG_IF <!!( eax & POPUP_RETURN_TEST )>    ;// invalid popup return value


            .IF (eax & POPUP_REFRESH_STATUS) && (edx != popup_status_ptext) && popup_status_hWnd

            ;// must return pointer in edx

                IFDEF DEBUGBUILD
                    push edx
                    invoke IsBadReadPtr, edx, 8
                    DEBUG_IF <eax>
                    pop edx
                ENDIF

                mov popup_status_ptext, edx
                invoke SetWindowTextA,popup_status_hWnd,edx ;// set it's text

                mov eax, [esp]

            .ENDIF

            .IF eax & POPUP_REDRAW_OBJECT
                GDI_INVALIDATE_OSC HINTI_OSC_UPDATE
            .ENDIF

            .IF eax & POPUP_KILL_THIS_FOCUS ;// the command requires that we kill the focus
                mov ebx, popup_hWnd         ;// will be handled below
            .ENDIF

                            ;// do app sync before reinitializing
            invoke app_Sync ;// clean up, do this BEFORE set focus so we can delete grouped objects
            mov eax, [esp]  ;// some objects like the knob need auto traces

            .IF eax & POPUP_INITMENU

                ;// just call the object's reinitialize function

                invoke ShowWindow, popup_hWnd, SW_SHOW
                DEBUG_IF <esi!!=popup_Object>
                OSC_TO_BASE esi, edi
                push ebx
                invoke [edi].gui.InitMenu
                pop ebx
                mov eax, [esp]

            .ENDIF

            .IF eax & POPUP_REBUILD

                ;// destroy all the controls

                DEBUG_IF < popup_no_undo >  ;// this will cause problems later on

                inc popup_bShowing
                invoke popup_CleanupWindow
                dec popup_bShowing

                ;// call popup init, but leave pobject set

                mov popup_Object, esi
                invoke popup_Show, esi
                mov eax, [esp]

            .ENDIF

            .IF eax & POPUP_CLOSE
                mov ebx, hMainWnd   ;// set focus to main wnd
                ;// popup_wm_activate will take over from there
            .ENDIF

            mov eax, [esp]
            .IF !(eax & POPUP_DONOT_RESET_FOCUS) && ebx
                invoke SetFocus, ebx        ;// set the focus to the control or wnd that had it
            .ENDIF

            UPDATE_DEBUG

        pop eax ;// return what gui.Command returned

    all_done:

        pop ebp ;// clean up the stack

        ret


popup_call_base_class ENDP















;////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////
;///
;///
;///    popup_Proc
;///
;///

ASSUME_AND_ALIGN
popup_Proc PROC

;// MESSAGE_LOG_PROC STACK_4

    mov eax, WP_MSG

;// commands and keystrokes

    HANDLE_WM WM_COMMAND,   popup_wm_command_proc
    HANDLE_WM WM_KEYDOWN,   popup_wm_keydown_proc
    HANDLE_WM WM_HSCROLL,   popup_wm_scroll_proc

;// activation/deactivation

    HANDLE_WM WM_CLOSE,     popup_wm_close_proc
    HANDLE_WM WM_ACTIVATE,  popup_wm_activate_proc
    HANDLE_WM WM_WINDOWPOSCHANGING, popup_wm_windowposchanging_proc
    HANDLE_WM WM_ENABLE,    popup_wm_enable_proc

;// status help text

    HANDLE_WM WM_SETCURSOR,         popup_wm_setcursor_proc
    HANDLE_WM WM_CTLCOLORLISTBOX,   popup_wm_ctlcolorlistbox_proc
    HANDLE_WM WM_DRAWITEM,          popup_wm_drawitem_proc

;// nope

    jmp DefWindowProcA

popup_Proc ENDP

;///
;///
;///    popup_Proc
;///
;///
;////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////////////////////
;//
;//                     wNotifyCode = HIWORD(wParam); // notification code
;//     WM_COMMAND      wID = LOWORD(wParam);         // item, control, or accelerator identifier
;//                     hwndCtl = (HWND) lParam;      // handle of control
;//
ASSUME_AND_ALIGN
popup_wm_command_proc PROC STDCALL USES esi edi ebx hWnd:DWORD, msg:DWORD, wParam:DWORD, lParam:DWORD

    .IF !popup_bShowing

        GET_OSC_FROM esi, popup_Object  ;// load the osc
        DEBUG_IF <!!esi>

        mov eax, wParam             ;// check if we even want this

        .IF (eax & 0FFFF0000h)      ;// check notify message from a control

            shr eax, 16             ;// shift down to a correct value

            ;//
            ;// edit box messages
            ;//

            .IF !popup_bDelete

                OSC_TO_BASE esi, edi    ;// get the base

                .IF     eax == EN_CHANGE    ;// we must prevent edit box's from gaining the focus

                    invoke GetFocus         ;// get the focus so we can return to it
                    mov ebx, eax            ;// and save in ebx
                    mov ecx, wParam         ;// get the control ID
                    mov eax, OSC_COMMAND_EDIT_CHANGE
                    and ecx, 0FFFFh         ;// strip off the command message
                    jmp call_base_class

                .ELSEIF eax == EN_SETFOCUS || eax == EN_KILLFOCUS

                    ;// determine if we want to process this message
                    .IF [edi].data.dwFlags & BASE_WANT_EDIT_FOCUS_MSG

                        invoke GetFocus     ;// get the focus so we can return to it
                        mov ebx, eax        ;// and save in ebx
                        xor eax, eax
                        mov ecx, wParam     ;// get the command
                        shld eax, ecx, 16   ;// xfer command to eax
                        and ecx, 0FFFFh     ;// mask out command in ecx
                        add eax, WM_COMMAND SHL 16  ;// add on the origonal command
                        ;// see OSC_COMMAND_EDIT_SETFOCUS and OSC_COMMAND_EDIT_KILLFOCUS

                        jmp call_base_class_2

                    .ENDIF

                ;//
                ;// list box messages
                ;//

                .ELSEIF eax == LBN_SELCHANGE

                    .IF [edi].data.dwFlags & BASE_WANT_LIST_SELCHANGE

                        invoke SendMessageA, lParam, LB_GETCURSEL, 0, 0
                        invoke SendMessageA, lParam, LB_GETITEMDATA, eax, 0
                        mov ecx, eax
                        mov eax, OSC_COMMAND_LIST_SELCHANGE
                        jmp call_base_class

                    .ENDIF


                .ELSEIF eax == LBN_DBLCLK

                    ;// LBN_DBLCLK
                    ;// idListBox = (int) LOWORD(wParam);  // identifier of list box
                    ;// hwndListBox = (HWND) lParam;       // handle of list box

                    ;// get the id from the currently selected item

                    invoke SendMessageA, lParam, LB_GETCURSEL, 0, 0
                    invoke SendMessageA, lParam, LB_GETITEMDATA, eax, 0
                    mov ecx, eax
                    mov eax, OSC_COMMAND_LIST_DBLCLICK
                    jmp call_base_class

                ;//
                ;// combo box messages
                ;//

                .ELSEIF eax == CBN_KILLFOCUS

                .ELSEIF eax == CBN_EDITUPDATE

                    ;// determine if we want to process this message
                    .IF [edi].data.dwFlags & BASE_WANT_EDIT_FOCUS_MSG

                        invoke GetFocus     ;// get the focus so we can return to it
                        mov ebx, eax        ;// and save in ebx
                        xor eax, eax
                        mov ecx, wParam     ;// get the command
                        shld eax, ecx, 16   ;// xfer command to eax
                        and ecx, 0FFFFh     ;// mask out command in ecx
                        add eax, WM_COMMAND SHL 16 ;// add wm_command value
                        ;// see OSC_COMMAND_COMBO_EDITUPDATE

                        jmp call_base_class_2

                    .ENDIF

                .ELSEIF eax == CBN_DROPDOWN

                    mov eax, wParam
                    mov edx, lParam
                    and eax, 0FFFFh
                    mov popup_ComboBox_hWnd, edx
                    mov popup_ComboBox_ID, eax

                .ELSEIF eax == CBN_CLOSEUP

                    mov popup_ComboBox_hWnd, 0
                    mov popup_ComboBox_ID, 0
                    or  popup_ComboBox_sel, -1

                .ELSEIF eax == CBN_SELCHANGE

                    push eax    ;// OSC_COMMAND_COMBO_SELENDOK
                    CMPJMP popup_ComboBox_hWnd, 0, je SELOK1
                    mov eax, popup_ComboBox_sel
                    TESTJMP eax, eax, js SELOK1 ;// abox 229 handles keybord changes
                    jmp SELOK2

                .ELSEIF eax == CBN_SELENDOK

                    push eax
                SELOK1:
                    invoke SendMessageA, lParam, CB_GETCURSEL, 0, 0
                SELOK2:
                    invoke SendMessageA, lParam, CB_GETITEMDATA, eax, 0
                    mov ecx, eax

                    pop eax     ;// mov eax, OSC_COMMAND_COMBO_SELENDOK
                    add eax, WM_COMMAND SHL 16

                    jmp call_base_class

                .ENDIF

            .ENDIF

        .ELSE                       ;// not a notify message
                                    ;// either a menu command or button
            mov ebx, popup_hWnd     ;// get the focus
            and eax, 0FFFFh         ;// strip off top of cmd id

            .IF !ZERO?  ;// skip nul commands

                OSC_TO_BASE esi, edi    ;// get the base

            call_base_class:

            ;// GET_OSC_FROM esi, popup_Object  ;// load the current popup osc_object
            ;// OSC_TO_BASE esi, edi            ;// get the base class

            call_base_class_2:

                invoke popup_call_base_class

            .ENDIF

        .ENDIF

        ;//

    .ENDIF  ;// popup bBusy

    xor eax, eax

        ret

popup_wm_command_proc ENDP





ASSUME_AND_ALIGN
popup_handle_virtfocus_change   PROC USES ebx edi

    ;// must preserve ebx, edi esi

        mov eax, popup_bVirtFocus
        mov ebx, popup_hWndFocus

        DEBUG_IF <!!ebx && eax> ;// ABOX237 bug hunt

        test eax, eax
        jz focus_is_not_on

    focus_is_on:

        ;// virtual focus is currently on and needs to go to the next control

        DEBUG_IF <!!ebx>    ;// supposed to be on !!

        invoke GetAsyncKeyState, VK_SHIFT

        mov edi,ebx ;// edi is a tag along so we iterate

        test eax, 00008000h
        jnz prev_window

    next_window:    ;// forwards

        DEBUG_IF <!!edi>    ;// ABOX237 bug hunt

        invoke GetWindow, edi, GW_HWNDNEXT
        .IF !eax
            invoke GetWindow, edi, GW_HWNDFIRST
        .ENDIF

        cmp eax, ebx
        je all_done     ;// nothing to do

        ;// if window is not visible, we need to try again
        ;// we also need to check if there no windows to focus to

        mov edi, eax
        invoke GetWindowLongA, eax, GWL_STYLE
        test eax, WS_VISIBLE
        jz next_window
        test eax, WS_DISABLED
        jnz next_window

        mov popup_hWndFocus, edi
        jmp set_cursor_position

    prev_window:        ;// backwards

        invoke GetWindow, edi, GW_HWNDPREV
        .IF !eax
            invoke GetWindow, edi, GW_HWNDLAST
        .ENDIF

        cmp eax, ebx
        je all_done     ;// nothing to do

        ;// if window is not visible, we need to try again
        ;// we also need to check if there no windows to focus to

        mov edi, eax
        invoke GetWindowLongA, eax, GWL_STYLE
        test eax, WS_VISIBLE
        jz prev_window
        test eax, WS_DISABLED
        jnz prev_window

        mov popup_hWndFocus, edi
        jmp set_cursor_position

    focus_is_not_on:

        ;// virtual focus is off and has not been set yet

        invoke GetWindow, popup_hWnd, GW_CHILD
        mov popup_hWndFocus, eax

    ;// .ELSE
    ;// virtual focus is off and needs to be turned on at the previous hWnd

    ;// set the cursor position
    set_cursor_position:

        mov eax, popup_hWndFocus
        test eax, eax
        mov popup_bVirtFocus, eax
        jz all_done

        sub esp, SIZEOF RECT
        invoke GetWindowRect, eax, esp
        add esp, SIZEOF POINT
        sub DWORD PTR [esp], VIRT_FOCUS_OFFSET
        sub DWORD PTR [esp+4], VIRT_FOCUS_OFFSET
        call SetCursorPos   ;// stack cleaned up

    all_done:

        ret

popup_handle_virtfocus_change   ENDP











;////////////////////////////////////////////////////////////////////////////////////
;//
;//
;//     WM_KEYDOWN
;//
;//
ASSUME_AND_ALIGN
popup_wm_keydown_proc PROC PRIVATE

    ;// look for escape key and any other key that matches a command ID

    mov eax, WP_WPARAM          ;// get the key
    .IF eax == VK_ESCAPE

        mov eax, WP_HWND
        invoke ShowWindow, eax, SW_HIDE

    .ELSEIF eax == VK_TAB

        invoke popup_handle_virtfocus_change

    .ELSEIF eax == VK_TILDE || eax == VK_SPACE

        .IF popup_bVirtFocus

            DEBUG_IF <!!popup_hWndFocus>    ;// supposed to be on !!

            ;// make sure the control is enabled before we click on it
            invoke GetWindowLongA, popup_hWndFocus, GWL_STYLE
            .IF !(eax & WS_DISABLED)
                invoke PostMessageA, popup_hWndFocus, BM_CLICK, 0, 0
            .ENDIF

        .ENDIF

    .ELSE

    mov ecx, WP_HWND    ;// do this BEFORE pushing !!

    push ebx
    push esi

        ;// check if delete key, then see if we xlate it
        mov ebx, eax    ;// xfer the key to ebx
        .IF ebx == VK_DELETE
            GET_OSC_FROM edx, popup_Object
            OSC_TO_BASE edx, edx
            .IF [edx].data.dwFlags & BASE_XLATE_DELETE
                mov ebx, ID_XLATE_DELETE
            .ENDIF
        .ENDIF

        ;// scan through all the controls
        invoke GetWindow, ecx, GW_CHILD
        mov esi, eax
        .WHILE esi
            invoke GetWindowLongA, esi, GWL_ID
            .IF eax == ebx
                ;// make sure the control is enabled before we click on it
                invoke GetWindowLongA, esi, GWL_STYLE
                .IF !(eax & WS_DISABLED)
                    invoke PostMessageA, esi, BM_CLICK, 0, 0
                .ENDIF
                xor eax, eax
                .BREAK
            .ENDIF
            invoke GetWindow, esi, GW_HWNDNEXT
            mov esi, eax
        .ENDW

    pop esi ;// DOH !! ABox228 these were reversed !!
    pop ebx ;// DOH !! ABox228 these were reversed !!

    .ENDIF

    xor eax, eax
    ret 10h

popup_wm_keydown_proc ENDP



;////////////////////////////////////////////////////////////////////////////////////
;//
;//                     we do not destroy the window,
;//     WM_CLOSE        we clean up child windows
;//                     hide it
;//                     possibly call an object function
;//                     possibly call unredo_EndAction
ASSUME_AND_ALIGN
popup_wm_close_proc PROC PRIVATE    ;// STDCALL uses esi edi ebx hWnd:dword, msg:dword, wParam:dword, lParam:dword

MESSAGE_LOG_PROC STACK_4

MESSAGE_LOG_TEXT <popup_wm_close_proc_ENTER>, INDENT

;// .IF popup_Plugin
;//     invoke plugin_CloseEditor
;// .ENDIF

    MESSAGE_LOG_TEXT <popup_wm_close_proc_setfocus_BEGIN>, INDENT
    invoke SetFocus, hMainWnd
    MESSAGE_LOG_TEXT <popup_wm_close_proc_setfocus_END>, UNINDENT
    ;// if the return value is zero, then we need to close the popup
    .IF !eax || eax == hMainWnd
        mov WP_WPARAM, 0
        mov WP_LPARAM, 0
MESSAGE_LOG_TEXT <____jmp_popup_wm_activate_proc>,UNINDENT
        jmp popup_wm_activate_proc
    .ENDIF
    xor eax, eax

MESSAGE_LOG_TEXT <popup_wm_close_proc_EXIT>, UNINDENT

    ret 10h

popup_wm_close_proc ENDP


;//////////////////////////////////////////////////////////////////////////////////
;//
;// WM_ACTIVATE
;// fActive = LOWORD(wParam);           // activation flag
;// fMinimized = (BOOL) HIWORD(wParam); // minimized flag
;// hwndPrevious = (HWND) lParam;       // window handle loosing or gaining activation
;//

.DATA
    ALIGN 4
    popup_wm_activate_busy dd -1    ;// -1 = not busy, after INC, not zero = busy

.CODE

ASSUME_AND_ALIGN
popup_wm_activate_proc PROC ;// STDCALL hWnd:dword, msg:dword, wParam:dword, lParam:dword

        MESSAGE_LOG_PROC STACK_4

        ;// ABOX233 wm_activate is no longer re-entrant
        MESSAGE_LOG_TEXT <popup_wm_activate_proc_ENTER>, INDENT
        INCJMP popup_wm_activate_busy, jnz am_busy

        ;// ABOX233 ignore if disabled ...
        ;// may cause new window not to appear on top ...
        ;// appears to work, but must be careful
        invoke GetWindowLongA, popup_hWnd, GWL_STYLE
        TESTJMP eax, WS_DISABLED, jnz am_disabled

    ;// are we activating or deactivating ??

        TESTJMP  WP_WPARAM, 0000FFFFh,  jz popup_deactivating   ;// this window is being activated

    popup_activating:
    ;// the popup is being shown
    ;// if not already being shown, then start an unredo_Action

        MESSAGE_LOG_TEXT <____popup_activating>

        DEBUG_IF <!!popup_Object>   ;// how'd this happen ??

        GET_OSC_FROM ecx, popup_Object
        OSC_TO_BASE ecx, edx
        .IF [edx].data.dwFlags & BASE_WANT_POPUP_ACTIVATE

                push esi
                push edi
                push ebx

                mov esi, ecx    ;// xfer osc object
                mov edi, edx    ;// xer osc base

                ;// ebx edi esi ret hwnd msg wparam lparam
                ;// 00  04  08  0C  10   14  18     1C
                mov ecx, [esp+1Ch]  ;// load lParam as arg to gui.Command
                mov ebx, ecx        ;// load ebx as window to set focus to ...
                mov eax, OSC_COMMAND_POPUP_ACTIVATE ;// == WM_ACTIVATE SHL 16
                invoke popup_call_base_class
                pop ebx
                pop edi
                pop esi

            ;// and for now we ignore the return value

        .ENDIF

        ;// then if we are not already in popup mode,
        ;// then we don't have to start an unredo record

        BITSJMP app_DlgFlags, DLG_POPUP, jc all_done

        MESSAGE_LOG_TEXT <____unredo_BeginAction_UNREDO_COMMAND_OSC>

        unredo_BeginAction UNREDO_COMMAND_OSC

        jmp all_done

    ;/////////////////////////////////////////////////////////////////////////////////////

    popup_deactivating: ;// this window is being deactivated

        CMPJMP popup_Object, 0, je all_done     ;// is there an object to deactivate ?

        MESSAGE_LOG_TEXT <____popup_deactivating>

        TESTJMP app_DlgFlags, DLG_FILENAME, jz deactivate_and_destroy   ;// are we in a filename mode ?

        MESSAGE_LOG_TEXT <____ShowWindow_popup_hWnd_SW_HIDE>

        invoke ShowWindow, popup_hWnd, SW_HIDE  ;// lets'hope that dialog turns it back on

        jmp all_done


    deactivate_and_destroy:

        MESSAGE_LOG_TEXT <____deactivate_and_destroy>

    ;// check first is lost focus because of a message box
    ;// if yes, then we do not want to destroy the dialog

        TESTJMP app_DlgFlags, DLG_MESSAGE,  jnz all_done

    ;// at this point we're ok to destroy the dialog

        .IF !popup_bDelete  ;// check if we're supposed to route this to the object first

            GET_OSC_FROM ecx, popup_Object
            OSC_TO_BASE ecx, edx
            .IF [edx].data.dwFlags & BASE_WANT_POPUP_DEACTIVATE

                push esi
                push edi
                push ebx

                mov esi, ecx    ;// xfer osc object
                mov edi, edx    ;// xer osc base

                ;// ebx edi esi ret hwnd msg wparam lparam
                ;// 00  04  08  0C  10   14  18     1C
                mov ecx, [esp+1Ch]  ;// load lParam as arg to gui.Command
                mov ebx, ecx        ;// load ebx as window to set focus to ...
                mov eax, OSC_COMMAND_POPUP_DEACTIVATE   ;// == WM_ACTIVATE
                invoke popup_call_base_class
                pop ebx
                pop edi
                pop esi

                TESTJMP eax, POPUP_IGNORE,  jne all_done    ;// see if object wants us to close

            .ENDIF

        .ENDIF

        ;// then we want to destroy all our controls
        invoke popup_CleanupWindow

    ;// then take care of unredo_EndAAction

        .IF !popup_no_undo && !popup_EndActionAlreadyCalled

            ;// popup_EndActionAlreadyCalled fixes the problem
            ;// of closing the diff equation editor whith a mouse click on the main screen
            ;// the problem is one of begin_Action being called from wm mouse down
            ;// and this rountine being hit AFTER that

            MESSAGE_LOG_TEXT <____unredo_EndAction_UNREDO_COMMAND_OSC>

            unredo_EndAction UNREDO_COMMAND_OSC

        .ENDIF

        mov popup_EndActionAlreadyCalled, 0

        ;// then

        mov eax, WP_HWND
        mov popup_bDelete, 0
        mov popup_Object, 0     ;// do this BEFORE hide window !!
        MESSAGE_LOG_TEXT <____HideWindow_BEGIN>, INDENT
        invoke ShowWindow, eax, SW_HIDE
        MESSAGE_LOG_TEXT <____HideWindow_END>, UNINDENT

        .IF !popup_no_undo
            MESSAGE_LOG_TEXT <____app_DlgFlags_NOT_DLG_POPUP>
            and app_DlgFlags, NOT DLG_POPUP
        .ENDIF

    all_done:

        or popup_wm_activate_busy, -1   ;// reset

    return_now:

        MESSAGE_LOG_TEXT <popup_wm_activate_proc_LEAVE>, UNINDENT

        xor eax, eax
        ret 10h


    am_busy:
    MESSAGE_LOG_TEXT <popup_wm_activate_proc_AM_BUSY_>

        jmp return_now


    am_disabled:

    ;// ABOX233 ignore if disabled ...
    ;// may cause new window not to appear on top ...
    ;// so we try to fix now
    ;// seems to work ...

        MESSAGE_LOG_TEXT <popup_wm_activate_proc_AM_DISABLED_>

        ;// .IF !(WP_WPARAM & 0000FFFFh) ;// this window is being deactivated

            mov eax, WP_LPARAM
            TESTJMP eax, eax, jnz D0
            mov eax, popup_hLastTopmost
            TESTJMP eax, eax, jz D1
        D0: MESSAGE_LOG_PRINT_1 <__setting_as_topmost>,eax,<"__setting_as_topmost %8.8X">
            mov popup_hLastTopmost, eax
            invoke SetWindowPos,eax,HWND_TOPMOST,0,0,0,0,SWP_NOSIZE OR SWP_NOMOVE
        D1:


        ;// .ENDIF

        jmp all_done


popup_wm_activate_proc ENDP


;/////////////////////////////////////////////////////
;//
;// WM_WINDOWPOSCHANGING
;// lpwp = (LPWINDOWPOS) lParam; // points to size and position data
;//
.DATA

    popup_WndPos_busy   dd  0   ;// let's make this non-reentrant just in case

.CODE

ASSUME_AND_ALIGN
popup_wm_windowposchanging_proc PROC ;// STDCALL PRIVATE hWnd:DWORD, msg:DWORD, hParent:DWORD, lParam:DWORD

        .IF popup_WndPos_busy
            MESSAGE_LOG_TEXT <popup_wm_windowposchanging_proc_IS_BUSY>
        .ELSE
            inc popup_WndPos_busy

            GET_OSC_FROM eax, popup_Object
            .IF eax
                OSC_TO_BASE eax, edx
                .IF [edx].data.dwFlags & BASE_WANT_POPUP_WINDOWPOSCHANGING
                    mov ecx, WP_LPARAM
                    push ebx
                    push esi
                    push edi
                    push ebp
                    mov esi, eax
                    mov edi, edx
                    stack_Peek gui_context,ebp
                    mov eax, OSC_COMMAND_POPUP_WINDOWPOSCHANGING
                    MESSAGE_LOG_TEXT <popup_wm_windowposchanging_proc__calling_osc_Command__BEGIN>,INDENT
                    call [edx].gui.Command
                    MESSAGE_LOG_TEXT <popup_wm_windowposchanging_proc__calling_osc_Command__END>,UNINDENT
                    pop ebp
                    pop edi
                    pop esi
                    pop ebx
                .ENDIF
            .ENDIF

            dec popup_WndPos_busy

        .ENDIF  ;// popup_WndPos_busy

        jmp DefWindowProcA


popup_wm_windowposchanging_proc ENDP






;/////////////////////////////////////////////////////////////
;//
;// WM_ENABLE
;// fEnabled = (BOOL) wParam;   // enabled/disabled flag
;//
;// ABOX233 this code was added to allow vst plugins to display splash screens
;//         all we do is pass along this to hMainWnd
;//         in that way we hope to prevent mixups
;//         this is not really a yummy option as we rely on the plugin
;//         to turn us back on ...

ASSUME_AND_ALIGN
popup_wm_enable_proc PROC ;// STDCALL hWnd,msg,wParam,lParam

        mov eax, WP_WPARAM
    MESSAGE_LOG_PRINT_1 <popup_wm_enable_proc_ENTER>,eax,<"popup_wm_enable_proc_ENTER %8.8X">,INDENT
        .IF popup_Object    ;// are we on ?
            invoke EnableWindow,hMainWnd,eax
        .ENDIF
    MESSAGE_LOG_TEXT <popup_wm_enable_proc_LEAVE>,UNINDENT
        xor eax, eax
        ret 10h

popup_wm_enable_proc ENDP



















;////////////////////////////////////////////////////////////////////////////////////
;//
;//
;//     WM_SCROLL
;//
;//


ASSUME_AND_ALIGN
popup_wm_scroll_proc PROC STDCALL PRIVATE USES esi edi ebx hWnd:DWORD, msg:DWORD, wParam:DWORD, lParam:DWORD

    LOCAL scrollInfo:SCROLLINFO

;// popup generic scroll handler

    movzx ebx, WORD PTR wParam                          ;// get the scroll command
    .IF ebx < SB_ENDSCROLL && ebx != SB_THUMBPOSITION   ;// do we even care ?

;// get_info:

        mov scrollInfo.dwSize, SIZEOF SCROLLINFO;// set up the first part of the scroll
        lea edi, scrollInfo                     ;// point edi at the info
        mov scrollInfo.dwMask, SIF_POS OR SIF_RANGE OR SIF_PAGE
        ASSUME edi:PTR SCROLLINFO
        invoke GetScrollInfo, lParam, SB_CTL, edi

;// handle command

        mov eax, [edi].dwPos

        .IF     ebx == SB_LINEUP
            dec eax
        .ELSEIF ebx == SB_LINEDOWN
            inc eax
        .ELSEIF ebx == SB_PAGEUP
            sub eax, [edi].dwPage
        .ELSEIF ebx == SB_PAGEDOWN
            add eax, [edi].dwPage
        .ELSEIF ebx == SB_THUMBPOSITION || ebx == SB_THUMBTRACK
            movsx eax, WORD PTR wParam+2
        .ELSEIF ebx == SB_TOP
            mov eax, [edi].dwMin
        .ELSE ;// IF ebx == SB_BOTTOM
            mov eax, [edi].dwMax
        .ENDIF

;// range_check:

        ASSUME eax:SDWORD
        .IF eax < [edi].dwMin
            mov eax, [edi].dwMin
        .ELSEIF eax > [edi].dwMax
            mov eax, [edi].dwMax
        .ENDIF

;// set_info:

        mov [edi].dwPos, eax
        and [edi].dwMask, NOT(SIF_RANGE OR SIF_PAGE)
        invoke SetScrollInfo, lParam, SB_CTL, edi, 1

;// now we tell popup_object to do a new value

        invoke GetWindowLongA, lParam, GWL_ID   ;// get the id
        mov ecx, [edi].dwPos    ;// by convention we'll pass the current position in ecx

        GET_OSC_FROM esi, popup_Object  ;// get the popup object
        OSC_TO_BASE esi, edi            ;// get the base class
        xor ebx, ebx                    ;// no focus changes

        invoke popup_call_base_class

    .ENDIF  ;// SB_ENDSCROLL

    xor eax, eax

    ret

popup_wm_scroll_proc ENDP





ASSUME_AND_ALIGN
popup_wm_setcursor_proc PROC

        cmp popup_status_hWnd, 0    ;// make sure there is a status window to display
        je all_done

        mov eax, WP_WPARAM  ;// get handle of window with the cursor

        invoke GetWindowLongA, eax, GWL_USERDATA    ;// get the text pointer

    ;// is there a message to display ?

        or eax, eax
        jz no_displayable_text

        push eax                ;// some objects have to store window handles here
        invoke IsWindow, eax    ;// so we check that and don't display is is_window
        test eax, eax
        pop eax
        jnz no_displayable_text

        IFDEF DEBUGBUILD
            push eax
            invoke IsBadReadPtr, eax, 1
            test eax, eax
            pop eax
            DEBUG_IF <!!ZERO?>
        ENDIF

        cmp eax, popup_status_ptext ;// same as previous ?
        je all_done

            mov edx, WP_HWND
            mov popup_status_ptext, eax ;// set the new value
            invoke GetWindowLongA,edx,GWL_USERDATA          ;// get status hwnd
            invoke SetWindowTextA,eax,popup_status_ptext    ;// set it's text

            jmp all_done

    no_displayable_text:

        cmp popup_status_ptext, 0   ;// is there text already on ??
        je all_done

        xor eax, eax
        mov edx, WP_HWND;// get the hWnd with the text string
        pushd eax       ;// empty string
        mov popup_status_ptext, eax
        invoke GetWindowLongA,edx,GWL_USERDATA
        invoke SetWindowTextA, eax, esp
        pop edx

    all_done:

        xor eax, eax    ;// return zero
        ret 10h         ;// exit

popup_wm_setcursor_proc ENDP


ASSUME_AND_ALIGN
popup_wm_ctlcolorlistbox_proc PROC

    ;// stack:  ret hwnd msg hDC hWnd
    ;//         00  04   08  0C  10

    .IF !popup_bShowing && popup_Object && popup_ComboBox_hWnd

        GET_OSC_FROM ecx, popup_Object  ;// load the current popup osc_object
        OSC_TO_BASE ecx, edx            ;// get the base class
        .IF [edx].data.dwFlags & BASE_XLATE_CTLCOLORLISTBOX

        push ebx
        ;// stack:  ebx ret hwnd msg wparam lparam
        ;//         00  04  08   0C  10     14

            mov ebx, [esp+14h]

            ;// determine if selected item is different than previous
            ;// if yes, the post WM_COMMAND.CBN_SELCHANGE

            ;// determine the item that is highlighted
            ;// NOT the item that is selected
            ;// we have the added complexity of determining
            ;// if this message was caused by a key stroke

            sub esp, SIZEOF POINT
            invoke GetCursorPos, esp
            invoke ScreenToClient, ebx, esp
            pop eax ;// X
            pop edx ;// Y
            shl edx, 16
            and eax, 0FFFFh
            or eax, edx
            WINDOW ebx, LB_ITEMFROMPOINT, 0, eax
            .IF !(eax & 0FFFF0000h) && eax != popup_ComboBox_sel

                mov popup_ComboBox_sel, eax

            ;//WM_COMMAND
            ;//CBN_SELCHANGE
            ;// wNotifyCode = HIWORD(wParam);       // notification code
            ;// idComboBox = (int) LOWORD(wParam);  // identifier of combo box
            ;// hwndComboBox = (HWND) lParam;       // handle of combo box

                ;// note: the ID may NOT be the id of the control
                ;// this is because the combo box creates it's own window
                ;// there does not seem to be any way to get at the actual owner
                ;// so we track CBN_DROPDOWN

                mov edx, (CBN_SELCHANGE SHL 16)
                or edx, popup_ComboBox_ID

                WINDOW_P popup_hWnd, WM_COMMAND, edx, popup_ComboBox_hWnd

            .ENDIF

        pop ebx

        .ENDIF

    .ENDIF

all_done:

    jmp DefWindowProcA

popup_wm_ctlcolorlistbox_proc ENDP


;// WM_DRAWITEM
comment ~ /*
typedef struct tagDRAWITEMSTRUCT {  // dis
    UINT  CtlType;
    UINT  CtlID;
    UINT  itemID;
    UINT  itemAction;
    UINT  itemState;
    HWND  hwndItem;
    HDC   hDC;
    RECT  rcItem;
    DWORD itemData;
} DRAWITEMSTRUCT;
*/ comment ~


ASSUME_AND_ALIGN
popup_wm_drawitem_proc PROC ;// STDCALL hWnd, msg, ctlID, pDrawItem
                            ;// 00      04    08   0C     10

        mov eax, popup_status_ptext
        mov [esp+8], eax
        jmp display_popup_help_text

popup_wm_drawitem_proc ENDP


ASSUME_AND_ALIGN
display_popup_help_text PROC    ;// STDCALL hWnd, pText, ctlID, pDrawItem
                                ;// 00      04    08   0C     10

    ;// our task here is to draw the help text for the static control
    ;// we want main text aligned at top left
    ;// and any hotkeys to be shoved into the lower right

    mov ecx, [esp+10h]
    ASSUME ecx:PTR DRAWITEMSTRUCT

    .IF [ecx].dwCtlID == ID_POPUP_HELP

    ;// clear the existing contents

        invoke FillRect, [ecx].hDC, ADDR [ecx].rcItem, COLOR_BTNFACE+1  ;// COLOR_MENU+1

    ;// see if we have text to display

        .IF DWORD PTR [esp+8]

            mov ecx, [esp+10h]
            ASSUME ecx:PTR DRAWITEMSTRUCT

        ;// locate the bracket, if any

            mov edx, DWORD PTR [esp+8]
            ASSUME edx:PTR BYTE
            .REPEAT
                CMPJMP [edx],  0 ,  jz no_brackets
                CMPJMP [edx], '{',  je got_bracket
                inc edx
            .UNTIL 0

        no_brackets:    ;// just print the string and beat it

            mov edx, DWORD PTR [esp+8]
            invoke DrawTextA, [ecx].hDC, edx, -1, ADDR [ecx].rcItem, DT_WORDBREAK
            jmp all_done

        got_bracket:    ;// print the string in two parts, then beat it


            mov eax, DWORD PTR [esp+8]
            push edx
            sub edx, eax
            add ecx, DRAWITEMSTRUCT.rcItem
            dec edx
            pushd DT_WORDBREAK              ;// flags
            push ecx                        ;// ptr rect
            push edx                        ;// text length
            sub ecx, DRAWITEMSTRUCT.rcItem
            push eax                        ;// pText
            push [ecx].hDC                  ;// hDC
            call DrawTextA
        ;//     invoke DrawTextA, [ecx].hDC, DWORD PTR [esp+18h], edx, ADDR [ecx].rcItem, DT_WORDBREAK
            pop edx

            mov ecx, [esp+10h]
            ASSUME ecx:PTR DRAWITEMSTRUCT

            invoke DrawTextA, [ecx].hDC, edx, -1, ADDR [ecx].rcItem,
                DT_SINGLELINE OR DT_RIGHT OR DT_BOTTOM

        .ENDIF


    .ENDIF

all_done:

    or eax, 1
    ret 10h

display_popup_help_text ENDP



ASSUME_AND_ALIGN




END


