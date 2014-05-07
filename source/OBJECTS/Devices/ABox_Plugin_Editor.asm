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
;//     ABox_Plugin_Editor.asm          separate file for hosting GUI VST Plugins
;//
;//
;// TOC
;//
;// editor_WndProc PROC ;// STDCALL hWnd, msg, wParam, lParam

;// editor_WindowPosChanging PROC
;// editor_Activating PROC
;// editor_Deactivating PROC

;// plugin_LaunchEditor PROC
;// plugin_CloseEditor PROC

comment ~ /*


    slowly this begins to make sense ?

    nope. this whole thing is FUCKED !!

*/ comment ~



OPTION CASEMAP:NONE
.586
.MODEL FLAT

        .NOLIST
        INCLUDE ABox_Plugin.inc
        .LIST


.DATA


    sz_p_c  db  'p_c'   ;// plugin cage
    plugin_atom dd  0   ;// atom for creating the window

    editor_bOpening dd  0   ;// non zero to indicate that we are in a call to effEditOpen
    ;// this is ONE way we determine what our owned editor is


    editor_hWnd_Cage    dd  0   ;// C   handle of our plugin cage window
    editor_hWnd_Animal  dd  0   ;// A   somehow we determine this

    editor_ProcessID    dd  0   ;// process ID of ABOX via popup_hWnd

    editor_hWnd_Disabler    dd  0   ;// window that caused hMain to disable

    editor_App69_bBusy  dd  0   ;// very important that we prevent reentrance


.CODE



IF USE_MESSAGE_LOG EQ 2
ASSUME_AND_ALIGN
PROLOGUE_OFF
show_hWnd_stats PROC STDCALL hWnd:DWORD

        xchg ebx, [esp+4]
        pushad

    ;// show child parent relationships going up

        mov esi, ebx    ;// trailer

        .REPEAT
            invoke GetParent, esi       ;// get the parent
            mov edi, eax
            MESSAGE_LOG_PRINT_2 __child_parent_,esi,edi,<"__child_parent_ %8.8X %8.8X">  ;// parent
            mov esi, edi
        .UNTIL !esi

    ;// style


    ;// that's it

        popad
        mov ebx, [esp+4]
        retn 4  ;// STDCALL 1 ARG


show_hWnd_stats ENDP
PROLOGUE_ON
ENDIF   ;// USE_MESSAGE_LOG EQ 2



;////////////////////////////////////////////////////////////////////////////////////
;//
;//
;//     editor_WndProc
;//


ASSUME_AND_ALIGN
editor_WndProc PROC ;// STDCALL hWnd, msg, wParam, lParam
                    ;// 00      04    08   0C      10

;// MESSAGE_LOG_PROC STACK_4

    IF USE_MESSAGE_LOG EQ 2
        ;// detect if we've been subclassed
        mov eax, WP_HWND
        invoke GetWindowLongA,eax,GWL_WNDPROC
        .IF eax != editor_WndProc
        MESSAGE_LOG_TEXT <editor_WndProc_has_been_SUBCLASSED_>
        .ENDIF
    ENDIF

        mov eax, WP_MSG
        HANDLE_WM   WM_PARENTNOTIFY,        editor_wm_parentnotify_proc
        HANDLE_WM   WM_ACTIVATE,            editor_wm_activate_proc
        HANDLE_WM   WM_APP+69h,             editor_wm_app69_proc

        jmp DefWindowProcA



    ;/////////////////////////////////////////////////////////
    ;//
    ;// WM_PARENTNOTIFY
    ;// fwEvent = LOWORD(wParam);  // event flags
    ;// idChild = HIWORD(wParam);  // identifier of child window
    ;// lValue = lParam;           // child handle, or cursor coordinates
    ALIGN 16
    editor_wm_parentnotify_proc:

    MESSAGE_LOG_PROC STACK_4

        ;// parent notify must take priority over wm activate
        .IF editor_bOpening && WP_WPARAM_LO == WM_CREATE
            mov eax, WP_LPARAM
            .IF eax
                mov editor_hWnd_Animal, eax
                MESSAGE_LOG_PRINT_1 <editor_wm_parentnotify_proc_>,ebx,<"editor_wm_parentnotify_proc editor_hWnd_Animal = %8.8X">
            .ENDIF
        .ENDIF
        jmp DefWindowProcA

    ;////////////////////////////////////////////////////////
    ;//
    ;// WM_ACTIVATE
    ;// fActive = LOWORD(wParam);           // activation flag
    ;// fMinimized = (BOOL) HIWORD(wParam); // minimized flag
    ;// hwndPrevious = (HWND) lParam;       // window handle
    ALIGN 16
    editor_wm_activate_proc:

    MESSAGE_LOG_PROC STACK_4

        ;// parent notify takes priority over activate
        .IF editor_bOpening && !editor_hWnd_Animal && !WP_WPARAM_LO ;// deactivate
            mov eax, WP_LPARAM
            .IF eax
                mov editor_hWnd_Animal, eax
                MESSAGE_LOG_PRINT_1 <editor_wm_activate_proc_>,ebx,<"editor_wm_activate_proc editor_hWnd_Animal = %8.8X">
            .ENDIF
        .ENDIF
        jmp DefWindowProcA


    ALIGN 16
    editor_wm_app69_proc:   ;// hWnd,msg,wParam,lParam

    ;// we are being passed a window handle that we need to put at the top

    MESSAGE_LOG_PROC STACK_4
    MESSAGE_LOG_TEXT <editor_wm_app69_proc__ENTER>,INDENT
        mov eax, WP_WPARAM
        invoke GetWindowLongA,eax,GWL_STYLE
        .IF eax & WS_VISIBLE
            mov eax, WP_WPARAM
            inc editor_App69_bBusy  ;// very important that we prevent reentrance
            invoke SetWindowPos,eax,HWND_TOPMOST,0,0,0,0,SWP_NOSIZE OR SWP_NOMOVE
            dec editor_App69_bBusy
        .ENDIF
        xor eax, eax
    MESSAGE_LOG_TEXT <editor_wm_app69_proc__LEAVE>,UNINDENT
        retn 10h


editor_WndProc ENDP

;//
;//     editor_WndProc
;//
;//
;////////////////////////////////////////////////////////////////////////////////////


IF USE_MESSAGE_LOG EQ 2

ASSUME_AND_ALIGN
editor_PrintWindowPos PROC

    ASSUME ebx:PTR WINDOWPOS

        MESSAGE_LOG_PRINT_2 sz_windowpos, [ebx].hwnd, [ebx].hwndInsertAfter, <"WINDOWPOS hWnd %8.8X  hWndAfter %8.8X">
        mov ecx, [ebx].dwFlags
        .IF ecx & SWP_NOMOVE
            MESSAGE_LOG_TEXT <_editor_SWP_NOMOVE>
        .ELSE
            point_Get [ebx].pos
            MESSAGE_LOG_PRINT_2 _editor_SWP_yes_MOVE, eax, edx, <"_editor_SWP_yes_MOVE (%i,%i)">
        .ENDIF
        .IF ecx & SWP_NOSIZE
            MESSAGE_LOG_TEXT <_editor_SWP_NOSIZE>
        .ELSE
            point_Get [ebx].siz
            MESSAGE_LOG_PRINT_2 _editor_SWP_yes_SIZE, eax, edx, <"_editor_SWP_yes_SIZE (%i,%i)">
        .ENDIF
        .IF ecx & SWP_NOZORDER
            MESSAGE_LOG_TEXT <_editor_SWP_NOZORDER>
        .ELSE
            MESSAGE_LOG_TEXT <_editor_SWP_yes_ZORDER>
        .ENDIF
        .IF ecx & SWP_NOREDRAW
            MESSAGE_LOG_TEXT <_editor_SWP_NOREDRAW>
        .ELSE
            MESSAGE_LOG_TEXT <_editor_SWP_yes_REDRAW>
        .ENDIF
        .IF ecx & SWP_NOACTIVATE
            MESSAGE_LOG_TEXT <_editor_SWP_NOACTIVATE>
        .ELSE
            MESSAGE_LOG_TEXT <_editor_SWP_yes_ACTIVATE>
        .ENDIF
        .IF ecx & SWP_FRAMECHANGED
            MESSAGE_LOG_TEXT <_editor_SWP_FRAMECHANGED>
        .ELSE
            MESSAGE_LOG_TEXT <_editor_SWP_no_FRAMECHANGED>
        .ENDIF
        .IF ecx & SWP_SHOWWINDOW
            MESSAGE_LOG_TEXT <_editor_SWP_SHOWWINDOW>
        .ELSE
            MESSAGE_LOG_TEXT <_editor_SWP_no_SHOWWINDOW>
        .ENDIF
        .IF ecx & SWP_HIDEWINDOW
            MESSAGE_LOG_TEXT <_editor_SWP_HIDEWINDOW>
        .ELSE
            MESSAGE_LOG_TEXT <_editor_SWP_no_HIDEWINDOW>
        .ENDIF
        .IF ecx & SWP_NOCOPYBITS
            MESSAGE_LOG_TEXT <_editor_SWP_NOCOPYBITS>
        .ELSE
            MESSAGE_LOG_TEXT <_editor_SWP_yes_COPYBITS>
        .ENDIF
        .IF ecx & SWP_NOOWNERZORDER
            MESSAGE_LOG_TEXT <_editor_SWP_NOOWNERZORDER>
        .ELSE
            MESSAGE_LOG_TEXT <_editor_SWP_yes_OWNERZORDER>
        .ENDIF
        .IF ecx & SWP_NOSENDCHANGING
            MESSAGE_LOG_TEXT <_editor_SWP_NOSENDCHANGING>
        .ELSE
            MESSAGE_LOG_TEXT <_editor_SWP_yes_SENDCHANGING>
        .ENDIF
        .IF ecx & SWP_DEFERERASE
            MESSAGE_LOG_TEXT <_editor_SWP_DEFERERASE>
        .ELSE
            MESSAGE_LOG_TEXT <_editor_SWP_no_DEFERERASE>
        .ENDIF
        .IF ecx & SWP_ASYNCWINDOWPOS
            MESSAGE_LOG_TEXT <_editor_SWP_ASYNCWINDOWPOS>
        .ELSE
            MESSAGE_LOG_TEXT <_editor_SWP_no_ASYNCWINDOWPOS>
        .ENDIF

        retn

editor_PrintWindowPos ENDP



ASSUME_AND_ALIGN
editor_PrintProcID  PROC

        push ecx

        pushd 0
        invoke GetWindowThreadProcessId,ecx,esp
        pop eax
        MESSAGE_LOG_PRINT_2 _editor_identifiers, editor_ProcessID,eax, <"_editor_identifiers our_procID %8.8X ecx_procID %8.8X">

        pop ecx

        retn

editor_PrintProcID ENDP


ENDIF






ASSUME_AND_ALIGN
editor_WindowPosChanging PROC

    ;// OSC_COMMAND_POPUP_WINDOWPOSCHANGING
    ASSUME esi:PTR PLUGIN_OSC_MAP
    ;// preserve ebp,edi,ebx
    ;// ecx has ptr to WINDOWPOS
    ;// if we choose to, send an app69 message to the cage window

        .IF !editor_App69_bBusy && !popup_bShowing && editor_hWnd_Animal

            push ecx
            xchg ebx, [esp]

            ASSUME ebx:PTR WINDOWPOS

            IF USE_MESSAGE_LOG EQ 2
            invoke editor_PrintWindowPos
            ENDIF

            TESTJMP [ebx].dwFlags, SWP_NOZORDER, jnz done_now

            mov eax, [ebx].hwnd
            CMPJMP eax, popup_hWnd, jne done_now

            mov eax, [ebx].hwndInsertAfter
            CMPJMP eax, editor_hWnd_Disabler, je done_now

            invoke misc_IsChild, popup_hWnd, [ebx].hwndInsertAfter
            TESTJMP eax,eax,jnz done_now

            invoke misc_IsChild, editor_hWnd_Animal, [ebx].hwndInsertAfter
            TESTJMP eax, eax, jz done_now

            pushd 0
            invoke GetWindowThreadProcessId, [ebx].hwndInsertAfter, esp
            pop eax
            CMPJMP eax, editor_ProcessID, jne done_now

            invoke GetWindowLongA,[ebx].hwndInsertAfter,GWL_STYLE
            TESTJMP eax, WS_VISIBLE, jnz done_now

            MESSAGE_LOG_TEXT <_posting__app69_>

            invoke PostMessageA, editor_hWnd_Cage, WM_APP+69h, [ebx].hwndInsertAfter, 0

        done_now:

            pop ebx

        .ENDIF



        retn

editor_WindowPosChanging ENDP



ASSUME_AND_ALIGN
editor_Activating PROC

    ;// OSC_COMMAND_POPUP_ACTIVATE
    ASSUME esi:PTR PLUGIN_OSC_MAP
    ;// preserve ebp,edi,ebx
    ;// ecx has handle of window loosing activation
    ;// must return eax as POPUP_RETURN_TEST


;// MESSAGE_LOG_TEXT <editor_Activating_ENTER>, INDENT

        DEBUG_IF <!!editor_hWnd_Cage>   ;//supposed to be set !!

    .IF !popup_bShowing

        DEBUG_IF <!!editor_hWnd_Animal> ;//supposed to be set !!

    ;// if disabler is still on, then make it on top

        .IF editor_hWnd_Disabler

            invoke IsWindow,editor_hWnd_Disabler
            TESTJMP eax, eax, jz A0
            invoke GetWindowLongA,editor_hWnd_Disabler,GWL_STYLE
            TESTJMP eax, WS_VISIBLE, jz A0

            MESSAGE_LOG_TEXT <editor_Activating_setting_disabler_as_topmost>
            invoke SetWindowPos,editor_hWnd_Disabler,HWND_TOPMOST,0,0,0,0,SWP_NOSIZE OR SWP_NOMOVE
            jmp all_done

        A0: mov editor_hWnd_Disabler, 0 ;// otherwise shut it off

        .ENDIF

    ;// otherwise enable the main window

        invoke GetWindowLongA,hMainWnd,GWL_STYLE
        .IF eax & WS_DISABLED
            MESSAGE_LOG_TEXT <editor_Activating_enabling_main_window>
            invoke EnableWindow, hMainWnd, 1
        .ENDIF

    .ELSE   ;// popup_bShowing is ON

        .IF !editor_hWnd_Animal

            push ecx
            pushd 0
            invoke GetWindowThreadProcessId,ecx, esp
            pop eax
            pop ecx
            .IF eax == editor_ProcessID

                ;// OK so now we have an errant plugin ?
                mov editor_hWnd_Animal, ecx
                MESSAGE_LOG_PRINT_1 editor_Activating_, ecx, <"editor_Activating_ editor_hWnd_Animal = %8.8X">

            .ENDIF

        .ENDIF

    .ENDIF

    ;// and we always return IGNORE

    all_done:

        mov eax, POPUP_IGNORE

;// MESSAGE_LOG_TEXT <editor_Activating_LEAVE>, UNINDENT

        retn

editor_Activating ENDP



ASSUME_AND_ALIGN
editor_Deactivating PROC

    ;// OSC_COMMAND_POPUP_DEACTIVATE
    ASSUME esi:PTR PLUGIN_OSC_MAP
    ;// preserve ebp,edi,ebx
    ;// ecx has handle of window gaining activation
    ;// must return eax as POPUP_RETURN_TEST

    MESSAGE_LOG_TEXT <editor_Deactivating__ENTER>, INDENT

    DEBUG_IF <!!editor_hWnd_Cage>   ;//supposed to be set !!

    .IF !popup_bShowing     ;// normal behavior

        DEBUG_IF <!!editor_hWnd_Animal> ;//supposed to be set !!

    ;// if the window we are deactivating to is part of our process
    ;// but NOT part of ABox, then ignore

        push ecx
        pushd 0
        invoke GetWindowThreadProcessId,ecx, esp
        pop eax
        pop ecx
        .IF eax != editor_ProcessID

            invoke plugin_CloseEditor
            mov eax, POPUP_CLOSE

        ;// window IS a part of our process
        .ELSEIF ecx == hMainWnd ;// ok to close

            invoke plugin_CloseEditor
            mov eax, POPUP_CLOSE

        .ELSE
        ;// window IS a part of our process
        ;// window IS NOT part of ABox

            push ecx
            mov editor_hWnd_Disabler, ecx       ;// set the disabler
            MESSAGE_LOG_TEXT <editor_Deactivating_disabling_main_window>
            invoke EnableWindow,hMainWnd, 0     ;// disable main window
            pop ecx                             ;// set new window at the top
            MESSAGE_LOG_TEXT <editor_Deactivating_setting_as_topmost>
            invoke SetWindowPos,ecx, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE OR SWP_NOSIZE
            mov eax, POPUP_IGNORE               ;// tell popup to ignore

        .ENDIF

    .ELSE   ;// popup_bShowing is on

        .IF !editor_hWnd_Animal

            push ecx
            pushd 0
            invoke GetWindowThreadProcessId,ecx, esp
            pop eax
            pop ecx
            .IF eax == editor_ProcessID

                mov editor_hWnd_Animal, ecx
                MESSAGE_LOG_PRINT_1 editor_Deactivating_, ecx, <"editor_Deactivating_ editor_hWnd_Animal = %8.8X">

            .ENDIF

        .ENDIF

        mov eax, POPUP_IGNORE

    .ENDIF

    MESSAGE_LOG_TEXT <editor_Deactivating__LEAVE>, UNINDENT

        retn

editor_Deactivating ENDP














ASSUME_AND_ALIGN
plugin_LaunchEditor PROC

    ;// tell popup to handle as a plugin
    ;// ABox233 -- trying various strategies ...

    MESSAGE_LOG_TEXT <plugin_LaunchEditor_ENTER>, INDENT

        .IF !plugin_atom    ;// register the editor window

            xor eax, eax

            pushd eax       ;// 11  WNDCLASSEX.hIconSm
            pushd OFFSET sz_p_c ;// 10  WNDCLASSEX.lpszClassName
            pushd eax           ;// 9   WNDCLASSEX.lpszMenuName
            pushd eax           ;// 8   WNDCLASSEX.hbrBackground
            invoke LoadCursorA, hInstance, IDC_ARROW
            xor edx, edx
            push eax            ;// 7   WNDCLASSEX.hCursor
            pushd edx           ;// 6   WNDCLASSEX.hIcon
            pushd hInstance     ;// 5   WNDCLASSEX.hInstance
            pushd edx           ;// 4   WNDCLASSEX.dwWndExtra
            pushd edx           ;// 3   WNDCLASSEX.dwClsExtra
            pushd editor_WndProc    ;// 2   WNDCLASSEX.pWndProc
            pushd CS_VREDRAW OR CS_HREDRAW OR CS_DBLCLKS OR CS_OWNDC;// 1   WNDCLASSEX.style
            pushd SIZEOF WNDCLASSEXA    ;// 0   WNDCLASSEX.

            push esp
            call RegisterClassExA
            and eax, 0FFFFh ;// atoms are WORDS !!

            add esp, SIZEOF WNDCLASSEXA

            mov plugin_atom, eax

            invoke GetWindowThreadProcessId,popup_hWnd,OFFSET editor_ProcessID

        .ENDIF


        ASSUME esi:PTR PLUGIN_OSC_MAP
        DEBUG_IF <[esi].plug.pAEffect !!= ebx>  ;// supposed to be equal

        ASSUME ebx:PTR vst_AEffect
        DEBUG_IF <!!ebx>    ;// and not equal to zero

        DEBUG_IF <editor_hWnd_Cage> ;// not supposed to be set !!

        DEBUG_IF <editor_hWnd_Animal>   ;// not supposed to be set !!

        ;//ABox233 a cage for plugin editors ?

        MESSAGE_LOG_TEXT <_create_cage_window_1__BEGIN>, INDENT

            xor eax, eax

            pushd esi           ;// 11  lpParam:ptr == PLUGIN_OSC_MAP
            pushd hInstance     ;// 10  hInstance:DWORD,
            pushd eax           ;// 9   hMenu:DWORD,
            pushd popup_hWnd    ;// 8   hWndParent:DWORD,

        ;// initial size is at top left of screen ...
        ;// we'll move this shortly

            push eax
            push eax
            push eax
            push eax

        ;// then continue on pushing parameters

            ;// styles compatible for attaching to popup hWnd
            PLUGIN_EDIT_STYLE    EQU WS_CHILD OR WS_CLIPSIBLINGS OR WS_CLIPCHILDREN OR WS_CHILD ;// OR WS_VISIBLE
            PLUGIN_EDIT_STYLE_EX EQU WS_EX_TOPMOST OR WS_EX_NOPARENTNOTIFY  ;// OR WS_EX_TOOLWINDOW

            lea edx, [esi].plug.szDisplayName
            pushd PLUGIN_EDIT_STYLE ;// 3   dwStyle:DWORD,
            pushd edx               ;// 2   lpWindowName:ptr,
            pushd plugin_atom       ;// 1   lpClassName:ptr,
            pushd PLUGIN_EDIT_STYLE_EX  ;// 0   dwExStyle:DWORD,
            call CreateWindowExA
            mov editor_hWnd_Cage, eax
            MESSAGE_LOG_PRINT_1 sz_editor_hWnd_Cage_is, editor_hWnd_Cage, <"editor_hWnd_Cage = %8.8X">

        MESSAGE_LOG_TEXT <_create_cage_window_1__END>, UNINDENT

    ;// launch the plugin editor in the supplied window

        MESSAGE_LOG_TEXT <_effEditOpen_BEGIN>, INDENT

            ;//effEditOpen      equ 14;// system dependant Window pointer in ptr
            ;// invoke [ebx].pDispatcher, ebx, effEditOpen, 0, 0, popup_hWnd, 0
            push eax
            inc editor_bOpening
                invoke [ebx].pDispatcher, ebx, effEditOpen, 0, 0, eax, 0
            dec editor_bOpening
            pop eax

        MESSAGE_LOG_TEXT <_effEditOpen_END>, UNINDENT

    ;// determine the actual size the plugin should be

        pushd 0     ;// make a fake pointer
        mov edx, esp

        ;//effEditGetRect   equ 13;// stuff rect (top, left, bottom, right) into ptr
        invoke [ebx].pDispatcher, ebx, effEditGetRect, 0,0,edx, 0
        ;// this returns a pointer to an ERect,
        ;// which is four shorts, top, left, bottom, right
        ;//                       00   02    04      06

        pop ecx             ;// retrieve the pointer
        DEBUG_IF <!!ecx>    ;// now what ??!, no pointer was returned
        ASSUME ecx:PTR WORD

        xor edx, edx    ;// no stalls here
        xor eax, eax    ;// or here

        movzx edx, [ecx+4]  ;// = bottom
        movzx eax, [ecx+6]  ;// = right
        sub dx, [ecx]       ;// - top
        sub ax, [ecx+2]     ;// - left


    ;// and resize the window we just created

        push edx
        push eax

    MESSAGE_LOG_TEXT <_resizing_hWndEditor_Cage_BEGIN>, INDENT
        pushd SWP_NOZORDER OR SWP_SHOWWINDOW
        push edx
        push eax
        pushd 0
        pushd 0
        pushd HWND_TOPMOST
        pushd editor_hWnd_Cage
        call SetWindowPos
    MESSAGE_LOG_TEXT <_resizing_hWndEditor_Cage_LEAVE>, UNINDENT

        pop eax
        pop edx

    MESSAGE_LOG_TEXT <plugin_LaunchEditor_LEAVE>, UNINDENT

        retn

plugin_LaunchEditor ENDP



ASSUME_AND_ALIGN
plugin_CloseEditor PROC

    MESSAGE_LOG_TEXT <plugin_CloseEditor_ENTER>, INDENT

        ASSUME esi:PTR PLUGIN_OSC_MAP

    ;// call close on the plugin

        mov ecx, [esi].plug.pAEffect
        ASSUME ecx:PTR vst_AEffect

        MESSAGE_LOG_TEXT <_effEditClose__BEGIN>, INDENT

            invoke [ecx].pDispatcher, ecx, effEditClose, 0, 0, 0, 0

        MESSAGE_LOG_TEXT <_effEditClose__END>, UNINDENT

    ;// destroy the editor window

        MESSAGE_LOG_TEXT <_DestroyWindow_Cage__BEGIN>, INDENT

            invoke DestroyWindow,editor_hWnd_Cage
            mov editor_hWnd_Cage, 0
            mov editor_hWnd_Animal, 0
            mov editor_hWnd_Disabler, 0

        MESSAGE_LOG_TEXT <_DestroyWindow_Cage__END>, UNINDENT

    ;// make sure all descendants of editor_hWnd_Animal are gone
    ;// erase the editor stack

;//     invoke editor_DestroyStack

    ;// and read the parameters

        invoke plugin_ReadParameters, esi

    ;// and what do we return ?

    ;// that should do

MESSAGE_LOG_TEXT <plugin_CloseEditor_LEAVE>, UNINDENT
        ret

plugin_CloseEditor ENDP

















ASSUME_AND_ALIGN
END