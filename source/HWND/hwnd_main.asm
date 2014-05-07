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
;// hWnd_main.asm           mainWndProc and it's direct handlers
;//                         and app_Sync
;//
;// TOC:
;//
;// app_Sync PROC
;//
;// mainWndProc PROC
;//
;// mainwnd_wm_lbuttondblclk_proc
;// mainwnd_wm_nclbuttondown_proc
;// mainwnd_wm_ncrbuttondown_proc
;// mainwnd_wm_keydown_proc
;// mainwnd_wm_keyup_proc

;// mainwnd_wm_scroll_proc
;// mainwnd_wm_activate_proc
;// mainwnd_wm_mouseactivate_proc
;// mainwnd_wm_close_proc
;// mainwnd_wm_destroy_proc
;// mainwnd_wm_create_proc
;// mainwnd_wm_dropfiles_proc




OPTION CASEMAP:NONE
.586
.MODEL FLAT

        .NOLIST
        include <Abox.inc>
        include <groups.inc>
        .LIST

.DATA


;// external wm handlers

    ;// gdi_asm

        gdi_wm_erasebkgnd_proc  PROTO
        gdi_wm_paint_proc       PROTO

    ;// hwnd_mouse.asm

        mouse_wm_mousemove_proc     PROTO
        mouse_wm_lbuttondown_proc   PROTO
        mouse_wm_lbuttonup_proc     PROTO
        mouse_wm_rbuttondown_proc   PROTO
        mouse_wm_rbuttonup_proc     PROTO

    ;// hwnd_status.asm

        status_wm_nccalcsize_proc       PROTO
        ;//status_wm_windowposchanged_proc  PROTO
        status_wm_sizing_proc           PROTO
        status_wm_size_proc             PROTO
        status_wm_ncpaint_proc          PROTO
        status_wm_nchittest_proc        PROTO
        status_wm_getminmaxinfo_proc    PROTO
        status_wm_syscommand_proc       PROTO

    ;// hwnd_mainmenu.asm

        mainmenu_wm_create_proc         PROTO STDCALL hWnd:DWORD, msg:DWORD, wParam:DWORD, lParam:DWORD
        mainmenu_wm_initmenupopup_proc  PROTO
        mainmenu_wm_command_proc        PROTO
        mainmenu_wm_drawitem_proc       PROTO
        mainmenu_wm_measureitem_proc    PROTO
        mainmenu_wm_setcursor_proc      PROTO
        mainmenu_wm_menuselect_proc     PROTO
        mainmenu_wm_entermenuloop_proc  PROTO
        mainmenu_wm_exitmenuloop_proc       PROTO




.CODE



;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
app_Sync PROC

    ;// this function serves as the general puropse synchronizing routine
    ;// it will handle any and all APP_SYNC flags

    ;// each of the sync handlers must shut their flag off
    ;// some handlers rely on play_wait

    ;// must preseve ebx esi edi ebp


    ;// abort if we are showing a message box
    ;// this fixes rendering before things are ready to be rendered

        test app_DlgFlags, DLG_MESSAGE
        jnz all_done

    ;// check the app flags and see what we need to do

        bt app_bFlags, LOG2(APP_SYNC_PLAYBUTTON)
        .IF CARRY?
            mainmenu_SyncPlayButton PROTO
            invoke mainmenu_SyncPlayButton
        .ENDIF

        bt app_bFlags, LOG2(APP_SYNC_OPTIONBUTTONS)
        .IF CARRY?
            mainmenu_SyncOptionButtons PROTO
            invoke mainmenu_SyncOptionButtons
        .ENDIF

        bt app_bFlags, LOG2(APP_SYNC_TITLE)
        .IF CARRY?
            invoke filename_SyncAppTitle
        .ENDIF

        bt app_bFlags, LOG2(APP_SYNC_MRU)
        .IF CARRY?
            invoke filename_SyncMRU
        .ENDIF

        bt app_bFlags, LOG2(APP_SYNC_SAVEBUTTONS)
        .IF CARRY?
            mainmenu_SyncSaveButtons PROTO
            invoke mainmenu_SyncSaveButtons
        .ENDIF

        bt app_settings.show, LOG2(SHOW_STATUS)
        .IF CARRY?
            bt app_bFlags, LOG2(APP_SYNC_STATUS)
            .IF CARRY?
                invoke status_Update
            .ENDIF
        .ENDIF

        invoke gdi_Invalidate

        bt app_bFlags, LOG2(APP_SYNC_EXTENTS)
        .IF CARRY?
            push ebp
            push edi
            push esi
            push ebx
            stack_Peek gui_context, ebp
            invoke context_UpdateExtents
            pop ebx
            pop esi
            pop edi
            pop ebp
        .ENDIF

        btr app_bFlags, LOG2(APP_SYNC_GROUP)
        .IF CARRY?
            .IF pGroupObject
                invoke opened_group_DefineG
                invoke gdi_Invalidate
            .ENDIF
        .ENDIF

        BITR app_bFlags, APP_SYNC_AUTOUNITS
        .IF CARRY?
            push ebp
            stack_Peek gui_context, ebp
            invoke unit_AutoTrace
            pop ebp
            invoke gdi_Invalidate
        .ENDIF

        btr app_bFlags, LOG2(APP_SYNC_LOCK)
        .IF CARRY?

            ;// locate any locked item and set that as MRS

            stack_Peek gui_context, edx     ;// get this context
            xor ecx, ecx                    ;// will scan z list
            xor eax, eax                    ;// keep clear for testing

            dlist_OrGetHead oscZ,ecx,[edx]  ;// scan the z list
            jz J1                           ;// skip if empty list

        J0: or eax, clist_Next(oscL,ecx)    ;// is there a next lock ?
            jnz J1                          ;// done if there is
            dlist_GetNext oscZ, ecx         ;// get the next z list
            or ecx, ecx                     ;// anything there ?
            jnz J0                          ;// continue on if so

        J1: mov clist_MRS(oscL,[edx]), eax  ;// store the new oscL.MRS

        .ENDIF

all_done:

    IFDEF DEBUGBUILD

        invoke memory_VerifyAll

    ENDIF


    ret

app_Sync ENDP








;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;///
;///                    mainWndProc is simply a "jump station"
;///    mainWndProc     as such, it's a naked function, defaulting to the
;///                    def window proc
;///                    do not do any processing in this block


ASSUME_AND_ALIGN
mainWndProc PROC

;// MESSAGE_LOG_PROC STACK_4

    mov eax, WP_MSG

;// gdi handlers, defined in gdi.asm

    HANDLE_WM   WM_PAINT,           gdi_wm_paint_proc       ;// gdi.asm
    HANDLE_WM   WM_ERASEBKGND,      gdi_wm_erasebkgnd_proc  ;// gdi.asm

;// play gdi handler

    HANDLE_WM   WM_ABOX_XFER_IC_TO_I, play_wm_abox_xfer_ic_to_i_proc;// abox_play.asm

;// mouse handlers, all defined in hwnd_mouse.asm

    HANDLE_WM   WM_MOUSEMOVE,       mouse_wm_mousemove_proc     ;// mouse.asm
    HANDLE_WM   WM_LBUTTONDOWN,     mouse_wm_lbuttondown_proc   ;// mouse.asm
    HANDLE_WM   WM_LBUTTONUP,       mouse_wm_lbuttonup_proc     ;// mouse.asm
    HANDLE_WM   WM_RBUTTONDOWN,     mouse_wm_rbuttondown_proc   ;// mouse.asm
    HANDLE_WM   WM_RBUTTONUP,       mouse_wm_rbuttonup_proc     ;// mouse.asm

    HANDLE_WM   WM_LBUTTONDBLCLK,   mainwnd_wm_lbuttondblclk_proc   ;// in house

    HANDLE_WM   WM_NCLBUTTONDOWN,   mainwnd_wm_nclbuttondown_proc   ;// in house
    HANDLE_WM   WM_NCRBUTTONDOWN,   mainwnd_wm_ncrbuttondown_proc   ;// in house


    HANDLE_WM   WM_MOUSEACTIVATE,   mainwnd_wm_mouseactivate_proc       ;// in house

    HANDLE_WM   WM_KEYDOWN,         mainwnd_wm_keydown_proc     ;// in house
    HANDLE_WM   WM_KEYUP,           mainwnd_wm_keyup_proc       ;// in house

    HANDLE_WM   WM_DESTROY,         mainwnd_wm_destroy_proc         ;// in house
    HANDLE_WM   WM_CLOSE,           mainwnd_wm_close_proc

    HANDLE_WM   WM_VSCROLL,         mainwnd_wm_scroll_proc
    HANDLE_WM   WM_HSCROLL,         mainwnd_wm_scroll_proc

;// app size and status window functions, defined in hwnd_status.asm

    HANDLE_WM   WM_NCCALCSIZE,      status_wm_nccalcsize_proc
    HANDLE_WM   WM_SIZING,          status_wm_sizing_proc
    HANDLE_WM   WM_SIZE,            status_wm_size_proc
    HANDLE_WM   WM_NCPAINT,         status_wm_ncpaint_proc
    HANDLE_WM   WM_NCHITTEST,       status_wm_nchittest_proc
    HANDLE_WM   WM_GETMINMAXINFO,   status_wm_getminmaxinfo_proc
    HANDLE_WM   WM_SYSCOMMAND,      status_wm_syscommand_proc

    HANDLE_WM   WM_DROPFILES,       mainwnd_wm_dropfiles_proc
    HANDLE_WM   WM_ACTIVATE,        mainwnd_wm_activate_proc

    ;// main menu bar defined in hwnd_mainmenu.asm

    HANDLE_WM   WM_INITMENUPOPUP,   mainmenu_wm_initmenupopup_proc
    HANDLE_WM   WM_DRAWITEM,        mainmenu_wm_drawitem_proc
    HANDLE_WM   WM_MEASUREITEM,     mainmenu_wm_measureitem_proc

    HANDLE_WM   WM_SETCURSOR,       mainmenu_wm_setcursor_proc
    HANDLE_WM   WM_MENUSELECT,      mainmenu_wm_menuselect_proc

    HANDLE_WM   WM_ENTERMENULOOP,   mainmenu_wm_entermenuloop_proc
    HANDLE_WM   WM_EXITMENULOOP,    mainmenu_wm_exitmenuloop_proc



    HANDLE_WM   WM_CREATE,          mainmenu_wm_create_proc

    HANDLE_WM   WM_COMMAND,         mainmenu_wm_command_proc

;// fall through is always do the default

    jmp DefWindowProcA

mainWndProc ENDP

;///
;///    mainWndProc
;///
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////


;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;///
;///
;///    in house message handlers
;///
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
mainwnd_wm_lbuttondblclk_proc PROC PRIVATE

    ;// if we have osc_hover, send a command to it

    mov eax, VK_TAB
    .IF osc_hover
        ;//unredo_BeginAction UNREDO_COMMAND_OSC
        mov eax, VK_RETURN
    .ENDIF
    invoke PostMessageA, hMainWnd, WM_KEYDOWN, eax, 0

    jmp DefWindowProcA

mainwnd_wm_lbuttondblclk_proc ENDP


;// make sure the labels get shut off

ASSUME_AND_ALIGN
mainwnd_wm_nclbuttondown_proc PROC PRIVATE
mainwnd_wm_nclbuttondown_proc ENDP
mainwnd_wm_ncrbuttondown_proc PROC PRIVATE

    .IF app_DlgFlags & DLG_LABEL
        invoke SetFocus, hMainWnd
    .ENDIF

    jmp DefWindowProcA

mainwnd_wm_ncrbuttondown_proc ENDP




;///////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////
;////
;////
;////   K E Y B O A R D
;////



;////////////////////////////////////////////////////////////////////
;//
;//     WM_KEYDOWN
;//     nVirtKey = (int) wParam ;// virtual-key code
;//     lKeyData = lParam       ;// key data
;//
ASSUME_AND_ALIGN
mainwnd_wm_keydown_proc PROC    ;// STDCALL PRIVATE hWnd:dword, msg:dword, dwKey:dword, dwKeyData:dword

    ;// make sure pin down is NOT set
    ;// better to check app_bFlags for a mode

        mov eax, WP_WPARAM  ;// get the key

    ;// space has priority over all others

        cmp eax, VK_SPACE
        je got_space

    ;// check for tilde

        cmp eax, VK_TILDE
        je got_tilde

    ;// route keystroke to selected osc ?

        xor edx, edx        ;// use edx for pointer testing

        or edx, osc_down
        jnz call_osc
        or edx, osc_hover
        jnz call_osc

    ;// see if this is a pin command

        or edx, pin_hover
        .IF !ZERO? && !pin_down

            cmp eax, VK_RETURN
            je got_pin_pull
            cmp eax, VK_BACK
            je got_pin_direct

        .ENDIF

    ;// any other keys we care about ?

        cmp eax, VK_CONTROL
        je got_control
        cmp eax, VK_SHIFT
        je got_shift

    ;// how about align commands ?

        cmp eax, IDC_ALIGN_LAUNCH
        je got_align

    ;// that's it

        jmp all_done

    ;///////////////////////////////////////////
    ;//
    ;//     got_shift       set mode to selecting osc
    ;//
    got_shift:

        and app_bFlags, NOT (APP_MODE_UNSELECT_OSC)
        or app_bFlags, APP_MODE_SELECT_OSC
        jmp all_done

    ;///////////////////////////////////////////
    ;//
    ;//     got_control
    ;//
    got_control:

        and app_bFlags, NOT (APP_MODE_SELECT_OSC)
        or app_bFlags, APP_MODE_UNSELECT_OSC
        jmp all_done

    ;///////////////////////////////////////////
    ;//
    ;//     got_space
    ;//
    got_space:

        invoke PostMessageA, hMainWnd, WM_COMMAND, COMMAND_PLAY, 0
        jmp all_done

    ;///////////////////////////////////////////
    ;//
    ;//     got_tilde
    ;//
    got_tilde:

        ;// get the mouse coords
        ;// map to window
        ;// send an r button down then an r button up

            sub esp, SIZEOF POINT

            invoke GetCursorPos, esp
            invoke ScreenToClient, hMainWnd, esp

            mov ecx, DWORD PTR [esp+4]  ;// Y
            shl ecx, 16
            mov cx, WORD PTR [esp]      ;// X
            invoke PostMessageA, hMainWnd, WM_RBUTTONDOWN, 0, ecx
            mov ecx, DWORD PTR [esp+4]  ;// Y
            shl ecx, 16
            mov cx, WORD PTR [esp]      ;// X
            invoke PostMessageA, hMainWnd, WM_RBUTTONUP, 0, ecx
            add esp, SIZEOF POINT

        jmp all_done

    ;///////////////////////////////////////////
    ;//
    ;//     got_pin_pull
    ;//
    got_pin_pull:

        ;// make sure this pin is connected

        cmp (APIN PTR [edx]).pPin, 0
        je all_done

        push ebp
        push ebx
        stack_Peek gui_context, ebp
        mov ebx, edx
        unredo_BeginAction UNREDO_BUS_PULL
        invoke bus_Pull
        unredo_EndAction UNREDO_BUS_PULL
        pop ebx
        pop ebp
        jmp all_done


    ;///////////////////////////////////////////
    ;//
    ;//     got_pin_direct
    ;//
    got_pin_direct:

        test (APIN PTR [edx]).dwStatus, PIN_BUS_TEST
        jz all_done

        push ebp
        push ebx
        stack_Peek gui_context, ebp
        mov ebx, edx
        unredo_BeginEndAction UNREDO_BUS_DIRECT
        invoke bus_Direct
        pop ebx
        pop ebp
        jmp all_done



    ;///////////////////////////////////////////
    ;//
    ;//     call_osc                pass keystroke to the osc handler
    ;//
    call_osc:

        push ebp
        push ebx    ;// store these registers
        push esi
        push edi

        stack_Peek gui_context, ebp

        GET_OSC_FROM esi, edx
        OSC_TO_BASE esi, edi

        push eax
        unredo_BeginAction UNREDO_COMMAND_OSC
        pop eax

        .IF !([edi].data.dwFlags & BASE_NO_KEYBOARD)
            invoke [edi].gui.Command    ;// call the osc
        .ELSE
            invoke osc_Command          ;// call default directly
        .ENDIF

        push eax
        unredo_EndAction UNREDO_COMMAND_OSC
        pop eax

        DEBUG_IF <!!(eax & POPUP_RETURN_TEST)>

        .IF !(eax & POPUP_IGNORE)

            ;// check for others here
            .IF eax & POPUP_REDRAW_OBJECT

                GDI_INVALIDATE_OSC HINTI_OSC_UPDATE

            .ENDIF

        .ENDIF

        pop edi
        pop esi
        pop ebx
        pop ebp
        jmp all_done


    ;///////////////////////////////////////////
    ;//
    ;//     got_align
    ;//
    got_align:

        ;// make sure something is selected

        stack_Peek gui_context, ecx
        clist_GetMRS oscS, edx, [ecx]
        .IF edx

            invoke align_Show

        .ENDIF

    ;///////////////////////////////////////////
    ;//
    ;//     all_done
    ;//
    all_done:           ;// return with zero for windows

        invoke app_Sync ;// always clean up

        UPDATE_DEBUG

        xor eax, eax
        ret 10h

mainwnd_wm_keydown_proc ENDP



;////////////////////////////////////////////////////////////////////
;//
;//     WM_KEYUP
;//     nVirtKey = (int) wParam ;// virtual-key code
;//     lKeyData = lParam       ;// key data
;//
ASSUME_AND_ALIGN
mainwnd_wm_keyup_proc   PROC    ;// STDCALL PRIVATE hWnd:dword, msg:dword, dwKey:dword, dwKeyData:dword

    ;// all we want to do here is reset app_ mode flags

        mov eax, WP_WPARAM

        cmp eax, VK_SHIFT
        jz select_done
        cmp eax, VK_CONTROL
        jz unselect_done

    all_done:

        xor eax, eax
        ret 10h

    select_done:
    unselect_done:

        and app_bFlags, NOT ( APP_MODE_SELECT_OSC OR APP_MODE_UNSELECT_OSC )
        UPDATE_DEBUG
        jmp all_done

mainwnd_wm_keyup_proc   ENDP



;////
;////
;////   K E Y B O A R D
;////
;///////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////













;///////////////////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////////////////
;////
;////                  the scroll bar works by keeping the position fixed at GDI_GUTTER
;////   SCROLL BARS    dwMin/Max are adjusted to make it appear as if the scrolls are moving
;////                  so all we do here is get the amount the scroll moved (nPos or a fixed size)
;////                  then send that to osc
;//
;//     scroll bar rates and display are manged by context_UpdateExtents
;//

;// WM_VSCROLL
;// nScrollCode = (int) LOWORD(wParam)  ; // scroll bar value
;// nPos = (short int) HIWORD(wParam)   ; // scroll box position
;// hwndScrollBar = (HWND) lParam       ; // handle of scroll bar

.DATA

    scroll_last_pos dd  0           ;// needed for NT cumulative positive
    scroll_knows_about_undo dd  0   ;// needed to sync with undo

.CODE


ASSUME_AND_ALIGN
mainwnd_wm_scroll_proc  PROC    ;// STDCALL PRIVATE hWnd:DWORD, msg:DWORD, wParam:DWORD, hScroll:DWORD

    ;// the scrollbars work by determining what mouseDelta should be
    ;// then calling osc_Ary move all to do the rest

    mov ecx, WP_WPARAM
    and ecx, 0FFFFh

    .IF ecx == SB_THUMBPOSITION ;// for NT we have to reset the accumulated position

        mov scroll_last_pos, 0

    .ELSEIF (ecx < SB_TOP)

        ;// note: look at the values of the SB_ codes to see how this works

        ;// we can only move X or Y so we set up eax and edx as ajusters
        ;// eax is the offset, we'll determine which later
        ;// edx is the 0 offset, we'll determine which later

        xor eax, eax
        xor edx, edx

        .IF ecx == SB_THUMBTRACK    ;// user is scrolling now
                                    ;// position is in nPos
            mov eax, WP_WPARAM      ;// nPos is the offset we want to use
            sar eax, 16             ;// scoot into place
            sub eax, GDI_GUTTER_X   ;// offet by gutter

            .IF app_dwPlatformID >= VER_PLATFORM_WIN32_NT

                ;// NT moves the scroll bar position
                ;// win 9x does not
                ;// so we have to keep track where the scroll bar was

                xchg scroll_last_pos, eax
                sub eax, scroll_last_pos
                neg eax

            .ENDIF

        comment ~ /*
            pushad
            pushd 'i%'
            mov edx, esp
            sub esp, 32
            mov ecx, esp
            invoke wsprintfA, ecx, edx, eax
            invoke OutputDebugStringA, esp
            add esp, 36
            popad
        */ comment ~

        .ELSEIF ecx == SB_LINEUP        ;// this also catches LINELEFT

            or eax, -8              ;// one line

        .ELSEIF ecx == SB_LINEDOWN  ;// this also catches LINERIGHT

            or eax, 8               ;// one line

        .ELSE ;// PAGE UP or DOWN

            sub esp, SIZEOF RECT    ;// make some room

        ;// stack looks like this
        ;// left    top     right   bottom  ret     hWnd    msg     lParam  wParam
        ;// 00      04      08      0C      10      14      18      1C      20

            invoke GetClientRect, hMainWnd, esp
            xor edx, edx

            .IF DWORD PTR [esp+18h] == WM_HSCROLL   ;// msg
                mov eax, [esp+8]    ;// rect.right
            .ELSE
                mov eax, [esp+0Ch]  ;// rect.bottom
            .ENDIF

            add esp, SIZEOF RECT    ;// stack is back to normal

            lea eax, [eax+eax*2]    ;// eax * 3
            mov ecx, WP_WPARAM
            shr eax, 2              ;// 3/4
            and ecx, 0FFFFh

            .IF ecx == SB_PAGEUP    ;// also catches SB_PAGELEFT
                neg eax
            .ENDIF

        .ENDIF

    check_hv_scroll:    ;// now it's later

        neg eax
        .IF WP_MSG == WM_VSCROLL
            xchg eax, edx
        .ENDIF

    push ebp

        point_Set mouse_delta

        .IF !scroll_knows_about_undo
            inc scroll_knows_about_undo
            unredo_BeginAction UNREDO_SCROLL
        .ENDIF

        stack_Peek gui_context, ebp
        or app_bFlags, APP_MODE_MOVING_SCREEN
        invoke context_MoveAll
        and app_bFlags, NOT APP_MODE_MOVING_SCREEN
        invoke InvalidateRect, hMainWnd, 0, 0

    pop ebp

    .ELSEIF ecx == SB_ENDSCROLL

        .IF scroll_knows_about_undo

            mov scroll_knows_about_undo, 0
            unredo_EndAction UNREDO_SCROLL

        .ENDIF

    .ENDIF


    invoke app_Sync     ;// call the central sync function

    ;// that's it
    xor eax, eax

    ret 10h

mainwnd_wm_scroll_proc  ENDP



;////
;////
;////   S C R O L L   B A R S       and messages the need to update the scroll bars
;////
;///////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////





;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////

;// WM_ACTIVATE fActive = LOWORD(wParam);   // activation flag
;// fMinimized = (BOOL) HIWORD(wParam);     // minimized flag
;// hwndPrevious = (HWND) lParam;           // window handle

ASSUME_AND_ALIGN
mainwnd_wm_activate_proc PROC   ;// STDCALL PRIVATE hWnd:dword, msg:dword, wParam:DWORD, hWndPrev:DWORD

;// MESSAGE_LOG_TEXT <mainwnd_wm_activate_proc_ENTER>, INDENT
    cmp WP_WPARAM_LO, WA_INACTIVE
    push esi
    .IF ZERO?

        ;// esi is pushed
        ;// we are being deactivated

    ;// our task here is to reset all things having to do with the mouse
    ;// we do this when loosing focus

        push ebp
        push ebx

        stack_Peek gui_context, ebp

        invoke ReleaseCapture   ;// lbutton up always releases the capture
        invoke mouse_reset_all_hovers

        mov eax, app_bFlags
        and mouse_state, NOT ( MK_LBUTTON OR MK_RBUTTON )   ;// turn off button flags
        and eax, APP_MODE_MOVING_PIN OR     APP_MODE_MOVING_OSC_SINGLE OR   \
                APP_MODE_USING_SELRECT OR   APP_MODE_MOVING_SCREEN OR       \
                APP_MODE_MOVING_OSC OR      APP_MODE_CONTROLLING_OSC OR     \
                APP_MODE_SELECT_OSC OR      APP_MODE_UNSELECT_OSC OR        \
                APP_MODE_CONNECTING_PIN

        EXTERNDEF mainmenu_last_hItem:DWORD ;// defined in hwnd_mainmenu.asm
        mov mainmenu_last_hItem, 0

        .IF !ZERO?

            xor app_bFlags, eax

            push edi

            invoke mouse_reset_pin_down
            invoke mouse_reset_osc_down
            invoke InvalidateRect, hMainWnd, 0, 1
            unredo_EndAction UNREDO_EMPTY

            pop edi

        .ENDIF

        pop ebx
        pop ebp

    .ELSE   ;// we are in fact, being activated


        SET_STATUS REFRESH

        ;// somehow we have to make the mouse set the hover correctly

        or app_bFlags, APP_SYNC_MOUSE   ;// this seams to work in many cases, although it didn't previously !!

    .ENDIF

    invoke app_Sync

    pop esi
    xor eax, eax
;// MESSAGE_LOG_TEXT <mainwnd_wm_activate_proc_LEAVE>, UNINDENT
    ret 10h


mainwnd_wm_activate_proc ENDP


;// WM_MOUSEACTIVATE
;// hwndTopLevel = (HWND) wParam;       // handle of top-level parent
;// nHittest = (INT) LOWORD(lParam);    // hit-test value
;// uMsg =    (UINT) HIWORD(lParam);    // mouse message

ASSUME_AND_ALIGN
mainwnd_wm_mouseactivate_proc PROC PRIVATE ;// STDCALL PRIVATE hWnd:DWORD, msg:DWORD, hParent:DWORD, lParam:DWORD

    ;// is there a dialog on ?

        test app_DlgFlags, DLG_TEST
        jz all_done

    ;// would this be a non client message ?

        cmp WP_LPARAM_LO, HTCLIENT
        jl all_done     ;// use signed compare for the two error values
        je hit_client

    hit_non_client:

    ;// we're clicking on this window when the popup or context window is there
    ;// we want to post a message so after all the hullabalew of shutting off
    ;// the other window is over, the main wnd gets the correct message
    ;// this is supposed to allow user to press menu buttons when dialogs are on

    ;// determine the mouse position

        point_Get app_msg.pt

        and eax, 0FFFFh ;// X
        shl edx, 16     ;// Y
        or eax, edx     ;// spoint

    ;// determine the message to send and the hittest value

        mov edx, WP_LPARAM
        mov ecx, edx
        shr edx, 16
        and ecx, 0FFFFh
        sub edx, WM_MOUSEMOVE - WM_NCMOUSEMOVE  ;// change mouse message to non client message

    ;// post the message

        invoke PostMessageA, hMainWnd, edx, ecx, eax    ;// post the message

        jmp DefWindowProcA

    hit_client: ;// we are activating by hitting the client

    ;// same as above, but condintioned for a client message

        push app_msg.pt.y
        push app_msg.pt.x
        invoke ScreenToClient, hMainWnd, esp
        pop eax
        pop edx
        and eax, 0FFFFh
        and edx, 0FFFFh
        shl edx, 16
        mov ecx, WP_LPARAM
        or edx, eax
        shr ecx, 16
        invoke PostMessageA, hMainWnd, ecx, 0, edx

    all_done:

        jmp DefWindowProcA

mainwnd_wm_mouseactivate_proc ENDP




;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
mainwnd_wm_close_proc PROC PRIVATE ;// STDCALL PRIVATE hWnd:dword, msg:dword, wParam:dword, lParam:dword

    ;// this our last chance to make sure we save the dirty file
    ;// and read the window settings

        .IF unredo_we_are_dirty && !( app_CircuitSettings & CIRCUIT_NOSAVE )

            invoke filename_QueryAndSave
            .IF eax == IDCANCEL
                xor eax, eax
                ret 10h
            .ENDIF
        .ENDIF

    ;// stop playing

        .IF play_status & PLAY_PLAYING

            invoke play_Stop

        .ENDIF

    ;// destroy the circuit (needed so we close all the files and devices)

        ENTER_PLAY_SYNC GUI

            invoke circuit_New

        LEAVE_PLAY_SYNC GUI

    ;// get the final window settings

        invoke app_GetWindowSettings

    ;// continue on

        jmp DefWindowProcA


mainwnd_wm_close_proc ENDP

;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
mainwnd_wm_destroy_proc PROC PRIVATE    ;// STDCALL hWnd:dword, msg:dword, wParam:dword, lParam:dword

    invoke PostQuitMessage, 0
    xor eax, eax
    ret 10h

mainwnd_wm_destroy_proc ENDP









;///////////////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////////////
;///
;///        D R A G n D R O P
;///
;///

ASSUME_AND_ALIGN
mainwnd_wm_dropfiles_proc PROC STDCALL PRIVATE uses esi edi ebx hWnd:DWORD, msg:DWORD, hDrop:DWORD, lParam:DWORD

        LOCAL szName[280]:BYTE

    ;// get the file name and release hDrop

        lea esi, szName ;// point esi at the name of the file
        invoke DragQueryFileA, hDrop, 0, esi, 279
        invoke DragFinish, hDrop

    ;// xfer the dropped name to filename_load_path

        DEBUG_IF <filename_get_path>    ;// supposed to be clear !!

        invoke filename_GetUnused   ;// name returned in ebx
        mov filename_get_path, ebx  ;// store for future use
        ASSUME ebx:PTR FILENAME
        invoke filename_InitFromString, FILENAME_FULL_PATH
        .IF !eax                    ;// make sure it's valid
            filename_PutUnused ebx
            mov filename_get_path, 0
            jmp all_done
        .ENDIF

        mov ecx, [ebx].pExt
        mov eax, DWORD PTR [ecx]
        or eax, 20202020h
        .IF eax != 'xoba'
            filename_PutUnused ebx
            mov filename_get_path, 0
            jmp all_done
        .ENDIF

    ;// do we want to load or paste ?
    ;// no way to tell

        push ebp
        stack_Peek gui_context, ebp
        invoke context_PasteFile
        pop ebp

        .IF !eax
            xchg eax, filename_get_path
            .IF eax                     ;// ABOX239
                filename_PutUnused eax  ;// context paste will free paste path if it needs too
            .ENDIF                      ;// ABOX239
        .ENDIF

    all_done:

    ;// sync the app

        invoke app_Sync

    ;// return zero

        xor eax, eax
        ret

mainwnd_wm_dropfiles_proc ENDP

;///
;///        D R A G n D R O P
;///
;///
;///////////////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////////////












ASSUME_AND_ALIGN





END

