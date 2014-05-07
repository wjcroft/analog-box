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
;//         added texts for alpha,debug, and release versions
;//         fix for signed/unsigned system parameter display
;//             now using float_to_sz for nicer eng unit display
;//
;//##////////////////////////////////////////////////////////////////////////
;//
;// ABox_About.asm      this displays the opening screens and the about panel
;//
;//
;//
;// TOC:
;//
;// about_BuildStats
;// about_ThreadProc
;// about_Show
;// about_Proc
;// about_activate_proc
;// about_close_proc
;// about_timer_proc
;// about_ctlcolorlistbox_proc
;// about_keydown_proc

;// about_SetLoadStatus





OPTION CASEMAP:NONE
.586
.MODEL FLAT

        .NOLIST
        include <Abox.inc>
        include <szfloat.inc>
        .LIST

.DATA

    ABOUT_STYLE     equ WS_POPUP OR WS_VISIBLE OR WS_CAPTION OR WS_SYSMENU
    ABOUT_STYLE_EX  equ WS_EX_DLGMODALFRAME OR WS_EX_TOPMOST OR WS_EX_WINDOWEDGE OR WS_EX_TOOLWINDOW

    about_hWnd          dd 0    ;// hWnd of the about box
    about_hWnd_device   dd 0    ;// handle for filling in devices
    about_hWnd_stats    dd 0    ;// handle of the memory use
    about_hWnd_load     dd 0    ;// used to indicate the load status
    about_szName        dd "t_a";// class name of the about panel
    about_atom          dd 0    ;// atom of creation
    about_threadID      dd 0    ;// about runs on another thread
    about_back_brush    dd 0    ;// brush for filling

    about_position  POINT {}    ;// where we display this

;// texts for the about panel

    sz_App_Title    db ' Analog Box '

    IFDEF ALPHABUILD
        IFDEF DEBUGBUILD
                sz_App_Version  db 'DEBUG',0dh,0ah,'ALPHA ', ABOX_VERSION_STRING, 0
        ELSE   ;// release build
                sz_App_Version  db 'RELEASE',0dh,0ah,'ALPHA ', ABOX_VERSION_STRING, 0
        ENDIF
    ELSEIFDEF DEBUGBUILD
                sz_App_Version  db 'DEBUG ',0dh,0ah,'BETA ', ABOX_VERSION_STRING, 0
    ELSE ;// release build
                sz_App_Version  db ABOX_VERSION_STRING, 0
    ENDIF
    
    sz_stats_1      db 'CPU Speed %sHz.', 0dh, 0ah
    sz_stats_2      db 'RAM: %sB.', 0dh, 0ah
                    db 'Available: %sB.', 0dh, 0ah
                    db 'In use: %sB.', 0

    sz_Copyright    db 'Copyright 1999-2011 Andy J Turner', 0dh, 0ah
                    db '<http://code.google.com/p/analog-box/>',0dh,0ah
                    db 'This program comes with ABSOLUTELY NO WARRANTY.', 0

    IFDEF ALPHABUILD
        sz_Trade    db 'THIS SOFTWARE IS NOT LICENSED FOR DISTRIBUTION.',0dh,0ah
                    db 0dh,0ah
                    db 'THIS IS AN ALPHA BUILD OF A PROGRAM CURRENTLY IN DEVELOPMENT.',0dh,0ah
                    db 'WHEN IT CRASHES, PLEASE REPORT IT TO THE ADDRESS ABOVE.',0dh,0ah
                    db 'IF IT FIXES AN OPEN ISSUE, PLEASE REPORT IT.',0dh,0ah
                    db 0dh,0ah
    ELSEIFDEF DEBUGBUILD
        sz_Trade    db 'THIS SOFTWARE IS NOT LICENESD FOR DISTRIBUTION.',0dh,0ah
                    db 0dh,0ah
                    db 'THIS IS A DEBUG BUILD INTENDED FOR DEVELOPERS AND BETA TESTERS.',0dh,0ah
                    db 'IF IT CRASHES, PLEASE REPORT IT TO THE ADDRESS ABOVE.',0dh,0ah
                    db 0dh,0ah
                    db 0dh,0ah
    ELSE
        sz_Trade    db 'This is free software. You are welcome to redistribute it under the terms '
                    db 'of the GNU General Public License as published by the Free Software Foundation, '
                    db 'either version 3 of the License, or (at your option) any later version. '
                    db 'You should have received a copy of the GNU General Public License along with '
                    db 'this program. If not, see <http://www.gnu.org/licenses/>.',0dh,0ah
                    db 0dh,0ah
    ENDIF
                    db 'Pentium is a trademark of Intel Corporation. '
                    db 'Windows is a trademark of Microsoft Corporation. '
                    db 'VST is a trademark of Steinberg Soft und Hardware GmbH.', 0

    ALIGN 4

.CODE


ASSUME_AND_ALIGN
about_BuildStats PROC PRIVATE

.IF about_hWnd_stats

        push ebp
        push edi
        push esi

    ;// this sets the text of the IDC_STATS window
    ;// we're going to push all the parameters manually, so pay attention

        buffer_size = 128        ;// size of the format buffer for wsprintf

        sub esp, buffer_size*2  ;// buffer -- double sized so we can store formatted string too
        mov ebp, esp            ;// store buffer pointer

    ;// get the memory use -- ABOX242 AJT
    ;// changed from wsprint num convertion to float_to_sz convertion
    ;// ALSO: user's machine may have morethan 4GB ... 
    ;//    since we are a 32bit process, we can't access extra any ways?

        comment ~ /*
        MEMORYSTATUS struct
            dwLength        dd SIZEOF MEMORYSTATUS
            dwMemoryLoad    dd 0    ;//  percent of memory in use
            dwTotalPhys     dd 0    ;//  bytes of physical memory
            dwAvailPhys     dd 0    ;//  free physical memory bytes
            dwTotalPageFile dd 0    ;//  bytes of paging file
            dwAvailPageFile dd 0    ;//  free bytes of paging file
            dwTotalVirtual  dd 0    ;//  user bytes of address space
            dwAvailVirtual  dd 0    ;//  free user bytes }
        MEMORYSTATUS ENDS
        */ comment ~

        mov eax, SIZEOF MEMORYSTATUS    ;// load the size of the struct
        sub esp, eax                    ;// make space on the stack
        mov [esp], eax                  ;// store the size of the struct
        invoke GlobalMemoryStatus, esp  ;// call function to get stats
        add esp, 8                      ;// back up two dwords
                                        ;// this puts total, and available as two parameters
        ;// totphys availphys ...                               
        ;// 00      04        08
                                        
        mov eax, memory_GlobalSize
        mov [esp+8], eax

        ;// totphys availphys in_use
        ;// 00      04        08
        
        ;// now we want to convert the numbers to text, and point at that
        ;// this where we use our extra stack space
        
        lea edi, [ebp+buffer_size]  ;// point at the text buffer
        mov esi, esp        ;// point at the three args we want to replace
        call convert_me     ;// local func declared below
        call convert_me     ;// local func declared below
        call convert_me     ;// local func declared below
        
    ;// clock speed -- revamp to display eng unitsABOX242 AJT

        .IF app_CPUFeatures & 10h && osc_Clock_Speed_string
            pushd OFFSET osc_Clock_Speed_string
            push OFFSET sz_stats_1      ;// use the full format string
        .ELSE
            push OFFSET sz_stats_2      ;// use the partial format string
        .ENDIF

    ;// format the text and set the text

        push ebp
        call wsprintfA

        invoke SetWindowTextA, about_hWnd_stats, ebp

    ;// clean up and split

        lea esp, [ebp+buffer_size*2]    ;// free both local buffers

        pop esi
        pop edi
        pop ebp

.ENDIF

    ret

    ;// local function to format args on the stack
    ALIGN 16
    convert_me:
        pushd 0                 ;// convert DWORD [esi] to QWORD [esp] -- do NOT sign extend
        pushd DWORD PTR [esi]
        fild QWORD PTR [esp]    ;// load the arg to convert
        add esp, 8              ;// clean up the stack
        mov [esi], edi          ;// replace the arg with a pointer to a string we're about to build
        add esi, 4              ;// advance esi to next dword to get
        mov edx, FLOATSZ_DIG_4 OR FLOATSZ_ENG OR FLOATSZ_SPACE
        call float_to_sz        ;// convert to a string
        mov al, 0               ;// load the terminator
        stosb                   ;// terminate, and edi is at next buffer
        retn    ;// local return to caller

about_BuildStats ENDP




ASSUME_AND_ALIGN
about_ThreadProc PROC STDCALL bSplash:DWORD

    ;// need to run the about message on another thread

        LOCAL msg:tagMSG

    ;// create the window

        DEBUG_IF <!!about_atom> ;// class hasn't been registered yet

        invoke CreateWindowExA,
            ABOUT_STYLE_EX,
            about_atom,
            OFFSET popup_ABOUT,
            ABOUT_STYLE,
            0,0,10,10,  ;// dummy args
            0, 0, hInstance, 0

        MESSAGE_LOG_PRINT_1 sz_about_hWnd_is, eax, <"about_hWnd = %8.8X">

    ;// don't store hWnd in memory just yet
    ;// we'll use it to flag the other thread that we're ready

        mov esi, eax

    ;// call build popup to initialize the controls

        invoke popup_BuildControls, esi, OFFSET popup_ABOUT, 0, 0   ;// don't use help

    ;// fill in the fixed strings and set the special fonts

        invoke GetDlgItem, esi, IDC_ANALOGBOX
        WINDOW_P eax, WM_SETFONT, hFont_huge, 1
        DEBUG_IF <!!eax>, GET_ERROR

        invoke GetDlgItem, esi, IDC_VERSION
        mov edi, eax
        WINDOW edi, WM_SETTEXT,0,OFFSET sz_App_Version
        WINDOW_P edi, WM_SETFONT, hFont_osc, 1

        invoke GetDlgItem, esi, IDC_COPYRIGHT
        mov edi, eax
        WINDOW edi, WM_SETTEXT,0,OFFSET sz_Copyright
        WINDOW_P edi, WM_SETFONT, hFont_osc, 1

        invoke GetDlgItem, esi, IDC_TRADEMARKS
        mov edi, eax
        WINDOW edi, WM_SETTEXT, 0,OFFSET sz_Trade
        WINDOW_P edi, WM_SETFONT, hFont_pin, 1

        invoke GetDlgItem, esi, IDC_STATUS
        mov about_hWnd_stats, eax
        WINDOW_P eax, WM_SETFONT, hFont_popup, 1
        invoke about_BuildStats

        invoke GetDlgItem, esi, IDC_LOAD_STATUS
        mov about_hWnd_load, eax
        WINDOW_P eax, WM_SETFONT, hFont_pin, 1

    ;// determine the position

        point_Get gdi_desk_size, ecx, ebx
        point_Get popup_ABOUT.siz

        shr eax, 1
        shr ecx, 1
        shr ebx, 1
        shr edx, 1

        sub ecx, eax
        sub ebx, edx

        point_Set about_position, ecx, ebx

    ;// device list fills in itself, as long as we have the public handle available

        invoke GetDlgItem, esi, IDC_DEVICES
        DEBUG_IF <!!eax>
        mov about_hWnd_device, eax

    ;// tell other thread it's ok to continue

        mov about_hWnd, esi

    ;// pump messages until done

        lea ebx, msg

    @1: invoke GetMessageA, ebx, esi, 0, 0
        or eax, eax
        jz @2
        invoke DispatchMessageA, ebx
        jmp @1

    ;// exit this thread

    @2: invoke DestroyWindow, esi
        invoke ExitThread, 0


about_ThreadProc ENDP




ASSUME_AND_ALIGN
about_Show PROC STDCALL bSplash:DWORD

    LOCAL wndclass:WNDCLASSEXA

    .IF !about_atom     ;// hasn't been created yet

        DEBUG_IF <!!hFont_popup>    ;// fonts not created yet

        ;// register the class

            xor eax, eax
            mov wndclass.cbSize, SIZEOF WNDCLASSEXA
            mov wndclass.style, CS_PARENTDC + CS_HREDRAW + CS_VREDRAW
            mov wndclass.lpfnWndProc, OFFSET about_Proc
            mov esi, hInstance
            mov wndclass.cbClsExtra, eax
            mov wndclass.cbWndExtra, eax
            mov wndclass.hInstance, esi
            mov wndclass.hIcon, eax
            mov wndclass.hIconSm, eax
            mov wndclass.hCursor, eax
            mov wndclass.lpszMenuName, eax
            invoke GetSysColor, COLOR_BTNFACE
            invoke CreateSolidBrush, eax
            mov about_back_brush, eax
            mov wndclass.hbrBackground, eax
            mov wndclass.lpszClassName, OFFSET about_szName

            invoke RegisterClassExA, ADDR wndclass
            and eax, 0FFFFh ;// atoms are words
            mov about_atom, eax

        ;// launch the message pump thread

            invoke CreateThread, 0, 0, OFFSET about_ThreadProc, bSplash, 0, OFFSET about_threadID

        ;// wait for window to be created

            .WHILE !about_hWnd
                invoke Sleep, 5
            .ENDW

    .ENDIF

    invoke SetWindowPos, about_hWnd, HWND_TOPMOST,
        about_position.x, about_position.y,
        popup_ABOUT.siz.x, popup_ABOUT.siz.y,
        SWP_SHOWWINDOW

    ;// and take care of xmouse

        .IF app_xmouse

            point_Get about_position

            add edx, 8
            add eax, 8

            invoke SetCursorPos, eax, edx

        .ENDIF

    ;// that's it

        ret

about_Show ENDP








ASSUME_AND_ALIGN
about_Proc PROC PRIVATE

;// MESSAGE_LOG_PROC STACK_4

    mov eax, WP_MSG
    HANDLE_WM WM_CTLCOLORLISTBOX, about_ctlcolorlistbox_proc
    HANDLE_WM WM_ACTIVATE, about_activate_proc
    HANDLE_WM WM_CLOSE, about_close_proc
    HANDLE_WM WM_KEYDOWN, about_keydown_proc

    jmp DefWindowProcA

about_Proc ENDP

ASSUME_AND_ALIGN
about_proc_exit:

    xor eax, eax

about_proc_exit_now:

    ret 10h


ASSUME_AND_ALIGN
about_keydown_proc PROC

    cmp WP_WPARAM, VK_ESCAPE
    je try_to_close_window

    jmp DefWindowProcA


about_keydown_proc ENDP


ASSUME_AND_ALIGN
about_activate_proc PROC PRIVATE

    cmp WP_WPARAM_LO, 0 ;// show or hide
    jz try_to_close_window

    ;// this window is being activated

    ;// DEBUG_IF <(app_bFlags & APP_DLG_ABOUT)> ;// lost sync
    or app_DlgFlags, DLG_ABOUT
    invoke about_BuildStats
    jmp DefWindowProcA

try_to_close_window::

    ;// this window is being deactivated
    ;// but we won't unless hMainWnd is set

    cmp hMainWnd, 0 ;// about_timer, 0      ;// if timer is off, we just deactivate
    jnz about_close_proc

timer_still_on::

    ;// timer on, do not deactivate
    or app_DlgFlags, DLG_ABOUT
    invoke SetForegroundWindow, about_hWnd
    jmp about_proc_exit

about_activate_proc ENDP

ASSUME_AND_ALIGN
about_close_proc PROC PRIVATE

    ;// deactivate the window

    ;// DEBUG_IF <!!(app_bFlags & APP_DLG_ABOUT)>   ;// lost sync

    ;// don't close if timer is still on

    cmp hMainWnd, 0     ;// about_timer, 0      ;// if timer is off, we just deactivate
    je timer_still_on

    ;// clear the load status

    pushd 0
    WINDOW about_hWnd_load, WM_SETTEXT,,esp
    pop eax

    ;// turn off the panel

    and app_DlgFlags, NOT DLG_ABOUT         ;// turn off app flags
    invoke ShowWindow, about_hWnd, SW_HIDE      ;// hide the window
    invoke EnableWindow, hMainWnd, 1            ;// enable the main window
    invoke SetForegroundWindow, hMainWnd        ;// force main wnd to foreground
    jmp about_proc_exit                         ;// jump to exit

about_close_proc ENDP


ASSUME_AND_ALIGN
about_ctlcolorlistbox_proc PROC PRIVATE

    invoke GetSysColor, COLOR_BTNTEXT
    mov edx, WP_WPARAM
    invoke SetTextColor, edx, eax
    invoke GetSysColor, COLOR_BTNFACE
    mov edx, WP_WPARAM
    invoke SetBkColor, edx, eax
    mov eax, about_back_brush
    jmp about_proc_exit_now

about_ctlcolorlistbox_proc ENDP


ASSUME_AND_ALIGN
about_SetLoadStatus PROC

    ;// all this does is set the about_hWnd_load text
    ;// to the return address of this function

    mov edx, [esp]  ;// get the return address

    pushd 'X'       ;// store the format value
    pushd '8.8%'

    mov eax, esp

    sub esp, 12     ;// make room for temp string
    mov ecx, esp

    invoke wsprintfA, ecx, eax, edx

    WINDOW about_hWnd_load, WM_SETTEXT,,esp

    add esp, 20 ;// clean up the stack

    ret

about_SetLoadStatus ENDP










ASSUME_AND_ALIGN

END
