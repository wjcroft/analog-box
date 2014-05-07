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
;// bus_edit.asm        handlers and rountines for the floating edit box
;//
;//
;// TOC
;//
;// edit_Initialize PROC
;// edit_Destroy PROC
;// edit_Launch PROC
;//
;// edit_Proc   PROC PRIVATE
;// edit_wm_killfocus_proc PROC PRIVATE




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

        editing category or member names

*/ comment ~



.DATA

    ;// handles and procs

        edit_hWnd       dd  0   ;// handle of the edit control
        edit_OldProc    dd  0   ;// we subclass the editor

.CODE



edit_Initialize PROC

    invoke GetDlgItem, bus_hWnd, IDC_BUS_EDITOR
    mov edit_hWnd, eax

    EDITBOX eax, EM_SETLIMITTEXT, 31

    lea edx, edit_Proc
    invoke SetWindowLongA, edit_hWnd, GWL_WNDPROC, edx
    mov edit_OldProc, eax

    ret

edit_Initialize ENDP

edit_Destroy PROC

    mov edx, edit_OldProc
    invoke SetWindowLongA, edit_hWnd, GWL_WNDPROC, edx
    ret

edit_Destroy ENDP










;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;///
;///    edit_Proc   these functions manage the editing of category
;///                or member names
;///

;// FUNCTIONS THAT TURN THE EDITOR ON
;//
;//     list_dblclk_proc
;//     mem_keydown_proc
;//     cat_keydown_proc
;//     catmem_AddCat

;// FUNCTIONS THAT TURN THE EDITOR OFF
;//
;//     edit_proc
;//     edit_wm_killfocus_proc
;//


;////////////////////////////////////////////////////////////////////
;//
;//                         called from cat_Proc or mem_Proc as the case may be
;//     edit_Launch         no stack frame yet
;//                         return to calling proc

ASSUME_AND_ALIGN
edit_Launch PROC

    push esi

    ;// ecx must have the hWnd to launch at
    DEBUG_IF <ecx!!=cat_hWnd && ecx!!=mem_hWnd>

    mov esi, ecx                ;// store the listbox hWnd
    LISTBOX esi, LB_GETCURSEL   ;// get the current selection
    .IF eax != LB_ERR           ;// make sure there is a selection

        push ebx
        mov ebx, eax            ;// store the index

        LISTBOX esi, LB_GETITEMDATA, ebx    ;// get the bus edit pointer

        ;// make sure it's not the defualt
        .IF (esi != cat_hWnd) || (eax != bus_pTable)

            push ebp
            push edi

            mov ebp, eax                ;// store the bus record pointer
            ASSUME ebp:PTR BUS_EDIT_RECORD

            mov edi, edit_hWnd          ;// get the edit handle
            invoke SetParent, edi, esi  ;// make sure editor knows what it's about

            ;// set the new position of the editor, pay attention

                pushd   0                       ;// this will be the redraw flag
                sub esp, SIZEOF RECT            ;// make some room
                LISTBOX esi, LB_GETITEMRECT, ebx, esp   ;// get the item rect

                ;// adjust the location and compute the size
                ;// scoot the edit rect over a little bit to show the bus number
                ;// compute the size in the process

                mov eax, (RECT PTR [esp]).left
                cmp esi, cat_hWnd                   ;// dont adjust left side of cat window
                mov edx, (RECT PTR [esp]).bottom
                je @F
                add eax, 12                         ;// do adjust left side on mem window
            @@: sub edx, (RECT PTR [esp]).top
                mov (RECT PTR [esp]).left, eax
                mov (RECT PTR [esp]).bottom, edx
                sub eax, (RECT PTR [esp]).right
                neg eax
                mov (RECT PTR [esp]).right, eax

                push edi                        ;// push the edit pointer

                call MoveWindow                 ;// call the move window

                ;// now the stack is all cleaned up as well

            ;// determine where we got text from and set the dlg mode

                .IF esi == cat_hWnd
                    lea edx, [ebp].cat_name
                    or dlg_mode, DM_EDITING_CAT ;// turn our flag on
                .ELSE
                    lea edx, [ebp].mem_name
                    or dlg_mode, DM_EDITING_MEM ;// turn our flag on
                .ENDIF

            ;// set and select the edit windows text

                WINDOW edi, WM_SETTEXT, 0, edx  ;// set the text
                EDITBOX edi, EM_SETSEL, 0, -1   ;// select all of it

                invoke ShowWindow, edi, SW_SHOW ;// un hide the window
                invoke SetFocus, edi            ;// set the edit focus
                WINDOW edi, WM_SETFONT, hFont_popup, 1  ;// finally!, we set the font here

            ;// set the status text

                invoke GetWindowLongA, edi, GWL_USERDATA
                DEBUG_IF <!!eax>    ;// string pointer was not set !
                mov bus_last_status, eax
                WINDOW hWnd_bus_status, WM_SETTEXT,0,eax    ;// set the text

            ;// clean up

            pop edi
            pop ebp

        .ENDIF  ;// default item

        pop ebx

    .ENDIF  ;// empty list

    pop esi

    ret

edit_Launch ENDP





;////////////////////////////////////////////////////////
;//                                     sub class proc
;//
;//     edit_Proc       this is where we trap keystrokes
;//                     that we want to end editing
;//
ASSUME_AND_ALIGN
edit_Proc   PROC PRIVATE

        mov eax, WP_MSG
        HANDLE_WM WM_KEYDOWN, got_keystroke
        HANDLE_WM WM_KILLFOCUS, edit_wm_killfocus_proc

edit_call_def_wind::

        SUBCLASS_DEFPROC edit_OldProc

    just_exit:

        ret 10h

    got_keystroke:

        mov eax, WP_WPARAM

        cmp eax, VK_ESCAPE
        jz close_and_ignore

        cmp eax, VK_RETURN
        jz close_and_ignore

        cmp eax, VK_UP
        jz post_and_ignore

        cmp eax, VK_DOWN
        jz post_and_ignore

        cmp eax, VK_TAB
        jnz edit_call_def_wind

    switch_and_ignore:

        .IF dlg_mode & DM_EDITING_CAT
            mov ecx, mem_hWnd
        .ELSE
            DEBUG_IF <!!(dlg_mode & DM_EDITING_MEM)>
            mov ecx, cat_hWnd
        .ENDIF

        jmp just_ignore

    post_and_ignore:

        .IF dlg_mode & DM_EDITING_CAT
            mov ecx, cat_hWnd
        .ELSE
            DEBUG_IF <!!(dlg_mode & DM_EDITING_MEM)>
            mov ecx, mem_hWnd
        .ENDIF

        mov edx, WP_LPARAM
        push ecx
        invoke PostMessageA, ecx, WM_KEYDOWN, eax, edx
        pop ecx

        jmp just_ignore

    close_and_ignore:

        .IF dlg_mode & DM_EDITING_CAT
            mov ecx, cat_hWnd
        .ELSE
            DEBUG_IF <!!(dlg_mode & DM_EDITING_MEM)>
            mov ecx, mem_hWnd
        .ENDIF

    just_ignore:

        invoke SetFocus, ecx

        xor eax, eax
        jmp just_exit

edit_Proc   ENDP

;////////////////////////////////////////////////////////////////////
;//
;//     WM_KILLFOCUS        jumped to from edit_Proc
;//                         hitting this means we are done editing
;//     idEditCtrl = (int) LOWORD(wParam); // identifier of edit control
;//     wNotifyCode = HIWORD(wParam);      // notification code
;//     hwndEditCtrl = (HWND) lParam;      // handle of edit control
;//
ASSUME_AND_ALIGN
edit_wm_killfocus_proc PROC PRIVATE

    ;// check if mode is ok
    ;// get the text to the correct spot

    push ebx
    push edi
    push esi

    mov ebx, dlg_mode       ;// get the dlg mode

    invoke ShowWindow, edit_hWnd, SW_HIDE       ;// hide the editor
    invoke SetCursor, hCursor_normal            ;// make sure we get a cursor

    btr ebx, LOG2(DM_EDITING_CAT)
    jnc editing_member

editing_category:   ;// was editing a category name

        mov esi, cat_hWnd
        mov edi, OFFSET BUS_EDIT_RECORD.cat_name
        jmp get_the_text

editing_member:     ;// was esiting a member name

        btr ebx, LOG2(DM_EDITING_MEM)
        DEBUG_IF <!!CARRY?>
        mov esi, mem_hWnd
        mov edi, OFFSET BUS_EDIT_RECORD.mem_name

    get_the_text:

        mov dlg_mode, ebx       ;// save the flags

        ;// esi is the list window
        ;// edi is the offset to the appropriate string

        mov ebx, edit_hWnd                  ;// get the new name from the editor
        LISTBOX esi, LB_GETCURSEL           ;// get index of selection
        LISTBOX esi, LB_GETITEMDATA, eax    ;// get the edit_record pointer

        ;// now we need to clear and get the text
        add edi, eax        ;// add pointer to edi to get the text pointer
        mov ecx, 32         ;// need to clear 32 bytes
        push edi            ;// pointer ends up as lParam
        push ecx            ;// ends up as wParam   (text length)
        xor eax, eax        ;// clear for zeroing
        shr ecx, 2          ;// divide by 4
        rep stosd           ;// clear the text (edi is now +32)
        pushd WM_GETTEXT    ;// push the msg
        push ebx            ;// push the edit window
        call SendMessageA   ;// get the text
        ;// that got the text and cleaned up the stack

    ;// inc bus_table_dirty     ;// set the dirty flag

    ;// force a rebuild the member list

        ;// or cat_cursel, -1
        invoke catmem_Update

    ;// now we account for recording

        lea esi, [edi-32]           ;// scoot esi back to start of string
        mov edi, unredo_pRecorder   ;// get the recording pointer
        .IF edi

            mov ecx, 8  ;// move 8 dwords
            rep movsd
            unredo_EndAction dummy_arg  ;// end action, but we aren;t sure which
            invoke bus_UpdateUndoRedo

        .ENDIF

    ;// clean up and split

        pop esi
        pop edi
        pop ebx

        jmp edit_call_def_wind

edit_wm_killfocus_proc ENDP

;///
;///    edit_Proc
;///
;///
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN

ENDIF   ;// USE_THIS_FILE


END







