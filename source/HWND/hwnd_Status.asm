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
;//     ABOX242 AJT
;//         manually set 1 operand size for masm 9
;//
;//##////////////////////////////////////////////////////////////////////////
;//                         this includes the handlers for the status
;//     ABox_Status.asm     code called from mainWndProc for the status rect
;//                         this module handles things having to with window size
;//                         this module also handles the unit legend
;//
;// TOC
;// status_Initialize
;// status_Destroy
;//
;// status_wm_nccalcsize_proc
;// status_wm_windowposchanged_proc
;// status_wm_ncpaint_proc
;// status_wm_nchittest_proc
;// status_wm_getminmaxinfo_proc
;// status_wm_sizing_proc
;// status_wm_syscommand_proc
;//
;// status_Update
;// status_BuildPinName
;// status_BuildOscName

;// use SET_STATUS to set to set the mode



OPTION CASEMAP:NONE

USE_THIS_FILE EQU 1

IFDEF USE_THIS_FILE

.586
.MODEL FLAT

        .NOLIST
        include <Abox.inc>
        include <groups.inc>
        .LIST


;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;//
;//
;//     the status bar
;//

.DATA

    status_hDC      dd  0   ;// dc for building
    status_hBmp     dd  0   ;// bitmap for blitting
    status_pBuffer  dd  0   ;// buffer for building strings

    STATUS_BUFFER_SIZE equ 512  ;// should be enough
    STATUS_HEIGHT EQU 42    ;// desired height of status window (about 3 lines)



;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;//
;//
;//     unit legend
;//



.DATA
;// layout parameters
;//
;// col0                   col1
;// |                      |
;// |    value   ====      |   logic    ====            layout notes:
;// freq/time    ====      |    midi    ====
;//  spectrum    ====      |  stream    ====            text is aligned right
;// |--------|--|-----|----|--------|--|-----|
;// |        |  |     |    |        |
;// |<------>|<>|<--->|    |        |
;//     |      |    |
;//     |      |    |
;//     |      |    LEGEND_RECT_WIDTH
;//     |      LEGEND_SEPERATE1_WIDTH
;//     label_width
;//
;//

;// fixed metrics

    LEGEND_SEPERATE1_WIDTH  EQU     2
    LEGEND_RECT_WIDTH       EQU     16
    LEGEND_LINE_SPACE       EQU     2

    MIN_LEGEND_X        EQU 384

    LEGEND_COL0 EQU 0
    LEGEND_COL1 EQU 66

    LEGEND_WID1 EQU 40
    LEGEND_WID2 EQU 16

;// derived values

    LEGEND_WIDTH        EQU     LEGEND_COL1 + LEGEND_WID2 + LEGEND_RECT_WIDTH + LEGEND_SEPERATE1_WIDTH
    LEGEND_HEIGHT       EQU     STATUS_HEIGHT
    LEGEND_ROW_HEIGHT   EQU     STATUS_HEIGHT / 3

    LEGEND_ROW0 EQU 0   + 2
    LEGEND_ROW1 EQU LEGEND_ROW_HEIGHT   + 2
    LEGEND_ROW2 EQU LEGEND_ROW_HEIGHT * 2   + 2



;// handles and positions

    legend_hDC  dd  0   ;// dc for blitting the legend
    legend_hBmp dd  0   ;// bitmap for the legend
;// legend_oldBmp   dd  0   ;// bitmap for the legend

;// legend_siz  POINT {LEGEND_WIDTH, LEGEND_HEIGHT} ;// size of the legend box

    LEGEND_ENTRY STRUCT

        sz_Name db 12 dup (0)
        pos   POINT {}
        wid     dd  0
        color   dd  0

    LEGEND_ENTRY ENDS


    legend_table LABEL LEGEND_ENTRY

        LEGEND_ENTRY {'value'       ,{LEGEND_COL0,LEGEND_ROW0},LEGEND_WID1,COLOR_DESK_DEFAULT*16 }
        LEGEND_ENTRY {'freq/time'   ,{LEGEND_COL0,LEGEND_ROW1},LEGEND_WID1,COLOR_DESK_FREQUENCY*16 }
        LEGEND_ENTRY {'spectrum'    ,{LEGEND_COL0,LEGEND_ROW2},LEGEND_WID1,COLOR_DESK_SPECTRAL*16 }
        LEGEND_ENTRY {'logic'       ,{LEGEND_COL1,LEGEND_ROW0},LEGEND_WID2,COLOR_DESK_LOGIC*16 }
        LEGEND_ENTRY {'midi'        ,{LEGEND_COL1,LEGEND_ROW1},LEGEND_WID2,COLOR_DESK_MIDI*16 }
        LEGEND_ENTRY {'strm'        ,{LEGEND_COL1,LEGEND_ROW2},LEGEND_WID2,COLOR_DESK_STREAM*16 }

        NUM_LEGEND_ENTRIES  EQU 6
;//
;//
;//     unit legend
;//
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////



.CODE


ASSUME_AND_ALIGN
legend_Update   PROC

    .IF legend_hDC

        push edi
        push esi
        push ebx

    ;// make a rect on the stack

        pushd LEGEND_HEIGHT
        pushd LEGEND_WIDTH
        pushd 0
        pushd 0

        st_rect TEXTEQU <(RECT PTR [esp])>

    ;// set up iterator, counters and erase the current picture

        mov edi, legend_hDC
        mov ebx, NUM_LEGEND_ENTRIES
        lea esi, legend_table
        ASSUME esi:PTR LEGEND_ENTRY

        mov edx, esp

        invoke FillRect, edi, edx, COLOR_BTNFACE+1 ;// COLOR_MENU+1     ;// erase the whole thing

    ;// build all the entries

        .REPEAT

        ;// draw the label

            point_Get [esi].pos
            point_SetTL st_rect

            add eax, [esi].wid
            add edx, LEGEND_ROW_HEIGHT

            point_SetBR st_rect

            mov ecx, esp

            invoke DrawTextA,edi ,ADDR [esi].sz_Name, -1, ecx, DT_NOCLIP OR DT_SINGLELINE OR DT_RIGHT

        ;// fill the rects background

            mov eax, st_rect.right
            add eax, LEGEND_SEPERATE1_WIDTH
            mov st_rect.left, eax
            add eax, LEGEND_RECT_WIDTH
            mov st_rect.right, eax

            mov edx, esp

            invoke FillRect, edi,edx, hBRUSH(0)

        ;// draw the color line

            mov ecx, [esi].color
            invoke SelectObject,edi,hPEN_3(ecx)

            mov eax, st_rect.top
            add eax, st_rect.bottom
            shr eax, 1

            mov edx, st_rect.left   ;// get the left side
            add edx, LEGEND_LINE_SPACE  ;// add a couple pixels to left side

            push eax    ;// save on stack

            invoke MoveToEx, edi, edx, eax, 0

            pop eax     ;// retrieve

            mov edx, st_rect.right
            sub edx, LEGEND_LINE_SPACE

            invoke LineTo, edi, edx, eax

        ;// iterate and loop

            add esi, SIZEOF LEGEND_ENTRY
            dec ebx

        .UNTIL ZERO?


        add esp, SIZEOF RECT
        st_rect TEXTEQU <>

        pop ebx
        pop esi
        pop edi

    .ENDIF

    ret

legend_Update   ENDP




ASSUME_AND_ALIGN
status_Initialize  PROC uses ebx edi

        DEBUG_IF <status_hDC>   ;// already set !!!

    ;// initialize the temp storage

        invoke memory_Alloc, GPTR, STATUS_BUFFER_SIZE
        mov status_pBuffer, eax

    ;// get the desktop dc

        invoke GetDesktopWindow
        push eax
        push eax
        invoke GetDC, eax
        mov [esp+4], eax
        mov edi, eax

    ;// create and initialize the status dc and bitmap

        invoke CreateCompatibleDC, 0
        mov status_hDC, eax
        mov ebx, eax

        invoke CreateCompatibleBitmap, edi, gdi_desk_size.x, STATUS_HEIGHT
        mov status_hBmp, eax
        invoke SelectObject, ebx, eax

        invoke SelectObject, ebx, hFont_help
        invoke GetSysColor, COLOR_MENUTEXT
        invoke SetTextColor, ebx, eax
        invoke SetBkMode, ebx, TRANSPARENT
        invoke GetSysColor, COLOR_BTNFACE   ;// MENU
        invoke SetBkColor, ebx, eax

    ;// create and initialize the legend bitmap

        invoke CreateCompatibleDC, 0
        mov legend_hDC, eax
        mov ebx, eax

        invoke CreateCompatibleBitmap, edi, LEGEND_WIDTH, LEGEND_HEIGHT ;// create the legend
        mov legend_hBmp, eax        ;// store in data
        invoke SelectObject, ebx, eax   ;// select in to new device context

        invoke GetSysColor, COLOR_MENUTEXT
        invoke SetTextColor, ebx, eax
        invoke SetBkMode, ebx, TRANSPARENT
        invoke SelectObject, ebx, hFont_pin

        invoke legend_Update

    ;// release the desk dc

        call ReleaseDC              ;// release the desk dc and clean up the stack in the process

    ;// that's it

        ret

status_Initialize   ENDP

ASSUME_AND_ALIGN
status_Destroy PROC

    .IF status_hDC

        invoke DeleteDC, status_hDC
        DEBUG_IF <!!eax>
        invoke DeleteObject, status_hBmp
        DEBUG_IF <!!eax>

    .ENDIF

    .IF legend_hDC

        invoke GetStockObject, NULL_PEN
        invoke SelectObject, legend_hDC, eax
        invoke GetStockObject, NULL_BRUSH
        invoke SelectObject, legend_hDC, eax


        invoke DeleteDC, legend_hDC
        DEBUG_IF <!!eax>
        invoke DeleteObject, legend_hBmp
        DEBUG_IF <!!eax>

    .ENDIF

    .IF status_pBuffer
        invoke memory_Free, status_pBuffer
    .ENDIF

    ret

status_Destroy ENDP



;////////////////////////////////////////////////////////////////////
;//
;//                         as usual, comctrl32 is a problem
;//     STATUS BAR          here's the code to build our own
;//
comment ~ /*

    there are several layout parameters we need to account for

    nomenclature

        nc_ coords are in window coords (reletive to TL of window)
        ht_ coords are in screen coords (for hit testing)

*/ comment ~

.DATA

    ;// sizes

    nc_frame_thick  POINT {}    ;// thickness of the frame
    nc_scroll_size  POINT {}    ;// width and height of the scroll bar

    ;// nc_ rects for drawing

    nc_status_rect RECT {}  ;// where the status rect is to be placed

    nc_scroll_grip RECT {}  ;// where the grip should NOT go when both scrolls are on

    ht_status_grip RECT {}  ;// where to hittest the status grip
    ht_scroll_grip RECT {}  ;// where the scroll grip should NOT be hit tested

    status_rect RECT {0,0,0,STATUS_HEIGHT}  ;// display size of the bitmap
    status_grip RECT {0,0,0,STATUS_HEIGHT}  ;// display location of the status grip

.CODE

ASSUME_AND_ALIGN
status_wm_nccalcsize_proc PROC PUBLIC   ;// STDCALL hWnd:dword, msg:dword, bValidRects:DWORD, pPARAMS:DWORD

    .IF app_settings.show & SHOW_STATUS

    ;// make sure that the system metrics are gotten

        .IF !nc_frame_thick.x

            invoke GetSystemMetrics, SM_CXFRAME
            mov nc_frame_thick.x, eax
            mov nc_status_rect.left, eax    ;// fixed
            invoke GetSystemMetrics, SM_CYFRAME
            mov nc_frame_thick.y, eax

            invoke GetSystemMetrics, SM_CXHSCROLL
            mov nc_scroll_size.x, eax
            invoke GetSystemMetrics, SM_CYVSCROLL
            mov nc_scroll_size.y, eax

            invoke status_Initialize

        .ENDIF

    ;// get the status coords and kludge the new window size

        mov ecx, WP_LPARAM  ;// window rect in screen coords
        ASSUME ecx:PTR RECT

        ;// tasks:
        ;//
        ;//     determine where the various rects are
        ;//     fake out windows to do a new cient size

        ;// do the right and left sides off all the rects

        mov eax, [ecx].right        ;// load the right side
        sub eax, nc_frame_thick.x   ;// subtract the thickness
        mov ht_scroll_grip.right, eax
        mov ht_status_grip.right, eax

        sub eax, nc_scroll_size.x   ;// mov to left side (still in screen coords)

        mov ht_scroll_grip.left, eax
        mov ht_status_grip.left, eax

        sub eax, [ecx].left     ;// subract to get into window coords

        mov nc_scroll_grip.left, eax

        add eax, nc_scroll_size.x   ;// mov to right side (still in window coords)

        mov nc_scroll_grip.right, eax
        mov nc_status_rect.right, eax

        sub eax, nc_status_rect.left
        mov status_rect.right, eax
        mov status_grip.right, eax
        sub eax, nc_scroll_size.x
        mov status_grip.left, eax

    ;// do the bottom and top of all the rects

        mov eax, [ecx].bottom       ;// load the bottom of the window
        sub eax, nc_frame_thick.y
        mov ht_status_grip.bottom, eax
        sub eax, nc_scroll_size.y
        mov ht_status_grip.top, eax

        mov eax, [ecx].bottom       ;// load the bottom of the window

        sub eax, STATUS_HEIGHT
        mov [ecx].bottom, eax       ;// new bottom of window

        sub eax, nc_frame_thick.y
        mov ht_scroll_grip.bottom, eax  ;// bot of scroll grip ?

        sub eax, nc_scroll_size.y
        mov ht_scroll_grip.top, eax

        sub eax, [ecx].top          ;// subtract top to get into window coords
        mov nc_scroll_grip.top, eax
        dec nc_scroll_grip.top      ;// kludge alert

        add eax, nc_scroll_size.y
        mov nc_scroll_grip.bottom, eax
        mov nc_status_rect.top, eax

        add eax, STATUS_HEIGHT

        mov nc_status_rect.bottom, eax

        sub eax, nc_scroll_size.y

        sub eax, nc_status_rect.top
        mov status_grip.top, eax

    ;// make sure the app cataches up

        or last_status_mode, -1
        or app_bFlags, APP_SYNC_STATUS

    .ENDIF

    ;// let windows do it's stuff

        push DWORD PTR [esp+10h]
        push DWORD PTR [esp+10h]
        push DWORD PTR [esp+10h]
        push DWORD PTR [esp+10h]
        call DefWindowProcA

    ;// store and invalidate the client area

        mov ecx, WP_LPARAM

    push eax

        point_GetBR [ecx]   ;// get the client BR
        point_SubTL [ecx]   ;// subtract TL to get size

        mov HScroll.dwPage, eax ;// store as new scroll ranges
        mov VScroll.dwPage, edx

        point_Add GDI_GUTTER            ;// offset to our gdi surface
        point_SetBR gdi_client_rect     ;// store in our struct

    pop eax


    ret 10h

status_wm_nccalcsize_proc ENDP



ASSUME_AND_ALIGN
status_wm_size_proc PROC PUBLIC
status_wm_sizing_proc PROC  PUBLIC


        or app_bFlags, APP_SYNC_EXTENTS OR APP_SYNC_MOUSE

        ;// make sure all the objects get redisplayed by adding them to the I list
        ;// wheather on screen or not

        push ebp
        push esi
            stack_Peek gui_context, ebp     ;// get the current context
            dlist_GetHead oscZ, esi, [ebp]  ;// start at the start
            mov eax, HINTI_OSC_MOVED;//_SCREEN  ;// tag all oscs as moved by the screen
            .WHILE esi
                GDI_INVALIDATE_OSC eax      ;// invalidate the osc
                dlist_GetNext oscZ, esi     ;// get the next osc
            .ENDW
            invoke app_Sync
        pop esi
        pop ebp



    jmp DefWindowProcA

status_wm_sizing_proc ENDP
status_wm_size_proc ENDP



ASSUME_AND_ALIGN
status_wm_ncpaint_proc PROC PUBLIC

    ;// don't do anything special if we are not showing the status

        .IF !(app_settings.show & SHOW_STATUS)
            jmp DefWindowProcA
        .ENDIF

    ;// let windows do it's stuff first

        push DWORD PTR [esp+10h]
        push DWORD PTR [esp+10h]
        push DWORD PTR [esp+10h]
        push DWORD PTR [esp+10h]
        call DefWindowProcA

    ;// update status

        .IF app_bFlags & APP_SYNC_STATUS

            invoke status_Update

        .ENDIF

    ;// get the window dc to draw with

        invoke GetWindowDC, WP_HWND
        push edi
        mov edi, eax

    ;// draw the status text

        DEBUG_IF <!!status_hDC>     ;// shouldn't this be set ?

        invoke BitBlt, edi,
            nc_status_rect.left, nc_status_rect.top,
            status_rect.right, status_rect.bottom,
            status_hDC, 0, 0, SRCCOPY

    ;// if both sroll bars are on, blank out the scroll grip

        .IF scroll_state == (HSCROLL_ON OR VSCROLL_ON)
            invoke FillRect, edi, OFFSET nc_scroll_grip, COLOR_ACTIVEBORDER+1
        .ENDIF

    ;// release the dc, clean up

        invoke ReleaseDC, WP_WPARAM, edi    ;// wparam because edi is on the stack twice
        pop edi

    ;// return zero

        xor eax, eax
        ret 10h

status_wm_ncpaint_proc ENDP


;// this does the fixup for hittesting
;// we disable the scroll size grip
;// enable the status size grip
;// and make sure the application is selected when clicking on the them
ASSUME_AND_ALIGN
status_wm_nchittest_proc PROC PUBLIC

    ;// if status is off we don't do anything special

        .IF !(app_settings.show & SHOW_STATUS)
            jmp DefWindowProcA
        .ENDIF

    ;// call windows first

        push DWORD PTR [esp+10h]
        push DWORD PTR [esp+10h]
        push DWORD PTR [esp+10h]
        push DWORD PTR [esp+10h]
        call DefWindowProcA

    ;// supperseed the scroll grip test

        .IF eax == HTBOTTOMRIGHT

            ;// if both scrolls are on

            .IF scroll_state == (HSCROLL_ON OR VSCROLL_ON)

                ;// are we inside the scroll grip ?

                spoint_Get WP_LPARAM
                .IF eax >= ht_scroll_grip.left &&   \
                    eax <= ht_scroll_grip.right &&  \
                    edx >= ht_scroll_grip.top &&    \
                    edx <= ht_scroll_grip.bottom

                    mov eax, HTCAPTION  ;// return caption
                    ;// so we can activate by clicking here

                    jmp all_done

                .ENDIF

                mov eax, HTBOTTOMRIGHT  ;// return bottom right
                ;// 'cause we really are at the bottom right

            .ENDIF

            jmp all_done

        .ENDIF

    ;// implement the status grip test

        .IF eax == HTNOWHERE

            ;// are we inside the status grip ?

            spoint_Get WP_LPARAM
            .IF eax >= ht_status_grip.left &&   \
                eax <= ht_status_grip.right &&  \
                edx >= ht_status_grip.top &&    \
                edx <= ht_status_grip.bottom

                mov eax, HTBOTTOMRIGHT
                jmp all_done

            .ENDIF

            mov eax, HTCAPTION  ;// return caption
            ;// so we can activate by clicking on the status bar

            jmp all_done

        .ENDIF

    all_done:

        ret 10h


status_wm_nchittest_proc ENDP

;// this enforces a min size

MIN_TRACK_SIZE_X EQU 256
MIN_TRACK_SIZE_Y EQU 256

ASSUME_AND_ALIGN
status_wm_getminmaxinfo_proc PROC PUBLIC

    mov ecx, WP_LPARAM
    ASSUME ecx:PTR MINMAXINFO
    point_Set [ecx].ptMinTrackSize, MIN_TRACK_SIZE_X, MIN_TRACK_SIZE_Y
    xor eax, eax
    ret 10h

status_wm_getminmaxinfo_proc ENDP



;//WM_SYSCOMMAND
;//uCmdType = wParam;        // type of system command requested
;//xPos = LOWORD(lParam);    // horizontal postion, in screen coordinates
;//yPos = HIWORD(lParam);    // vertical postion, in screen coordinates

ASSUME_AND_ALIGN
status_wm_syscommand_proc PROC PUBLIC

    mov eax, WP_WPARAM
    cmp eax, SC_MAXIMIZE
    je got_maximize
    cmp eax, SC_RESTORE
    je got_restore
    jmp DefWindowProcA


got_maximize:

        or app_bFlags, APP_MODE_MAXIMIZED OR APP_SYNC_EXTENTS

        ;// make sure all the objects get redisplayed by adding them to the I list
        ;// wheather on screen or not

        push ebp
        push esi
            stack_Peek gui_context, ebp     ;// get the current context
            dlist_GetHead oscZ, esi, [ebp]  ;// start at the start
            mov eax, HINTI_OSC_MOVED;//_SCREEN  ;// tag all oscs as moved by the screen
            .WHILE esi
                GDI_INVALIDATE_OSC eax      ;// invalidate the osc
                dlist_GetNext oscZ, esi     ;// get the next osc
            .ENDW
        pop esi
        pop ebp

        ;// clean up

        ;// jmp invalidate_the_window
        jmp DefWindowProcA

got_restore:

        and app_bFlags, NOT APP_MODE_MAXIMIZED
        or app_bFlags, APP_SYNC_EXTENTS

invalidate_the_window:

        push DWORD PTR [esp+10h]
        push DWORD PTR [esp+10h]
        push DWORD PTR [esp+10h]
        push DWORD PTR [esp+10h]
        call DefWindowProcA
        push eax

        invoke app_Sync

        pop eax

        ret 10h


status_wm_syscommand_proc ENDP
;//
;//                         as usual, comctrl32 is a problem
;//     STATUS BAR          this was the code to build our own
;//
;////////////////////////////////////////////////////////////////////








.DATA


;////////////////////////////////////////////////////////////////////
;//
;//
;//     sentences       use SET_STATUS to set
;//                     see status_HOVER_DESK for values


    status_mode         dd  0   ;// see abox.inc for definitions
    last_status_mode    dd  -1  ;// no sense wasting time


    CR_LF TEXTEQU <0Dh,0Ah>
    TAB   TEXTEQU <09h>

    ;// mode table goes to indexed strings

    status_mode_table   LABEL   DWORD

            dd  0
            dd  OFFSET sz_status_HOVER_DESK
            dd  OFFSET sz_status_HOVER_OSC
            dd  OFFSET sz_status_HOVER_CON
            dd  OFFSET sz_status_HOVER_PIN_UNCON
            dd  OFFSET sz_status_HOVER_PIN_CON

            dd  OFFSET sz_status_CONNECT_UI_UI
            dd  OFFSET sz_status_CONNECT_UO_UO
            dd  OFFSET sz_status_CONNECT_UO_CI
            dd  OFFSET sz_status_CONNECT_CO_UI
            dd  OFFSET sz_status_CONNECT_BO_BO
            dd  OFFSET sz_status_CONNECT_CO_CO
            dd  OFFSET sz_status_CONNECT_CI_UI
            dd  OFFSET sz_status_CONNECT_UI_CI
            dd  OFFSET sz_status_CONNECT_UO_UI
            dd  OFFSET sz_status_CONNECT_SAME

            dd  OFFSET sz_status_CONNECTING

sm_mainmenu dd  0   ;// tricky for main menu

            dd  OFFSET sz_status_HOVER_PIN_BUS_IN
            dd  OFFSET sz_status_HOVER_PIN_BUS_OUT
            dd  OFFSET sz_status_SAVING_BMP

            dd  OFFSET sz_status_HOVER_DESK_SEL
            dd  OFFSET sz_status_CONNECTING_swap




    ;// 1
    sz_status_HOVER_DESK    LABEL BYTE

        db  'LB: Move Screen', TAB,     'RB: Create/Select Objects', TAB, '~ Create Objects', 0

    ;// 21  handled as a replacement of above
    sz_status_HOVER_DESK_SEL    LABEL BYTE

        db  'LB: Move Screen',       TAB,'RB: Create/Select Objects',TAB,'Del: Delete Selection', CR_LF
        db  'Ctrl: Unselect Objects',TAB,'Tab: Unselect All',   TAB, TAB,'Ins: Clone Selection', CR_LF
        db  'NumPad 5: Align Objects.', TAB, '~ Create Objects', 0

    ;// 2
    sz_status_HOVER_OSC     LABEL BYTE

        db 'LB: Move Object ',TAB,      'RB: Object Move/Properties',TAB, '~ Object Properties', CR_LF
        db 'Shift: Select Objects',TAB, 'Del: Delete Object', TAB, 'Ins: Clone Object',0


    ;// 3
    sz_status_HOVER_CON     LABEL BYTE

        db 'LB: Control Object',TAB,    'RB: Object Move/Properties',TAB,'~ Object Properties',CR_LF
        db 'Shift: Select Objects',TAB, 'Del: Delete Object', TAB, 'Ins: Clone Object',0

    ;// 4
    sz_status_HOVER_PIN_UNCON       LABEL BYTE

        db  'LB: Start Connection',TAB, 'RB: Connection Properties', TAB, '~ Connection Properties', 0

    ;// 5
    sz_status_HOVER_PIN_CON     LABEL BYTE

        db  'LB: Move Connection',TAB,  'RB: Connection Move/Properties', CR_LF
        db  'Del: Unconnect', TAB, '~ Connection Properties', 0

    ;// connection values

    ;// 6
    sz_status_CONNECT_UI_UI db  "Can't connect inputs to inputs", 0

    ;// 7
    sz_status_CONNECT_UO_UO db  "Can't connect outputs to outputs",0

    ;// 8
    sz_status_CONNECT_UO_CI db  "Pin is already connected to a source",0

    ;// 9
    sz_status_CONNECT_CO_UI db  "Can't move an output to an input.",0

    ;// 10
    sz_status_CONNECT_BO_BO db  "Can't move bus source to another source.",0

    ;// 11
    sz_status_CONNECT_CO_CO db  "Move connection(s) to this output.",0

    ;// 12
    sz_status_CONNECT_CI_UI db  "Move connection to this input.",0

    ;// 13
    sz_status_CONNECT_UI_CI db  "Connect to this pin's source.",0

    ;// 14
    sz_status_CONNECT_UO_UI db  "Connect these pins together",0

    ;// 15
    sz_status_CONNECT_SAME  db  "Can't connect a pin to itself.",0

    ;// 16
    sz_status_CONNECTING    db  "Connecting pins",0

    ;// 22
    sz_status_CONNECTING_swap   db "Connecting pins",TAB,TAB,"RB: Swap ends", 0

    ;// 17
    ;// this is set directly by mainmenu_wm_menuselect_proc


    ;// 18
    sz_status_HOVER_PIN_BUS_IN  LABEL BYTE

        db  'LB: Move Connection',TAB,  'RB: Connection Move/Properties', TAB, 'Del: Unconnect', CR_LF
        db  'Home: Goto Source', TAB, 'PgUp: Goto Previous', TAB, 'PgDown: Goto Next', 0

    ;// 19
    sz_status_HOVER_PIN_BUS_OUT LABEL BYTE

        db  'LB: Move Connection',TAB,  'RB: Connection Move/Properties',TAB, 'Del: Unconnect', CR_LF
        db 'PgDown: Goto Next Bus', 0

    ;// 20
    sz_status_SAVING_BMP db 'Saving bitmap. Press ESCAPE to cancel.', 0




    ;// protos for string building

    status_BuildPinName PROTO
    status_BuildOscName PROTO


.CODE

;////////////////////////////////////////////////////////////////////
;//
;//
;//     status_Update
;//
ASSUME_AND_ALIGN
status_Update PROC USES ebx

    ;// see if there's anything to do

        mov ebx, status_mode
        cmp ebx, last_status_mode
        je all_done

        push edi

    ;// clear the bitmap and draw the resize grip
    ;// but not if we are maximized

        invoke FillRect, status_hDC, OFFSET status_rect, COLOR_BTNFACE+1    ;// COLOR_MENU+1
        .IF !(app_bFlags & APP_MODE_MAXIMIZED)
        invoke DrawFrameControl, status_hDC, OFFSET status_grip,DFC_SCROLL,DFCS_SCROLLSIZEGRIP
        .ENDIF

    ;// draw the legend text

        mov eax, status_grip.left
        xor edx, edx
        sub eax, LEGEND_WIDTH
        cmp eax, MIN_LEGEND_X
        jle @F

        invoke BitBlt, status_hDC,
            eax, edx,
            LEGEND_WIDTH, LEGEND_HEIGHT,
            legend_hDC, 0, 0, SRCCOPY
    @@:


    ;// check and reset the mode

        .IF ebx == status_HOVER_DESK

            stack_Peek gui_context, ecx
            .IF clist_MRS(oscS,[ecx])
                mov ebx, status_HOVER_DESK_SEL
            .ENDIF

        .ENDIF

        or ebx, ebx
        mov last_status_mode, ebx
        jz do_the_blit

    ;// render the text

        DEBUG_IF < ebx !> MAX_STATUS_MODE >     ;// mode is too big

        mov ebx, status_mode_table[ebx*4]       ;// load the string pointer

        .IF pin_hover

            invoke SelectObject, status_hDC, hFont_osc
            push eax

            mov edi, status_pBuffer
            invoke status_BuildPinName

            invoke DrawTextA, status_hDC, status_pBuffer, -1, OFFSET status_rect, DT_EXPANDTABS

            add status_rect.top, eax    ;// add the text height

            push status_hDC
            call SelectObject

        .ELSEIF osc_hover

            invoke SelectObject, status_hDC, hFont_osc
            push eax

            mov edi, status_pBuffer
            invoke status_BuildOscName

            invoke DrawTextA, status_hDC, status_pBuffer, -1, OFFSET status_rect, DT_EXPANDTABS

            add status_rect.top, eax    ;// add the text height

            push status_hDC
            call SelectObject

        ;// STRCPY edi, ebx
        ;// mov edi, status_pBuffer

        .ELSEIF last_status_mode == status_MAINMENU || last_status_mode == status_SAVING_BMP

            test ebx, ebx
            jz do_the_blit

            invoke SelectObject, status_hDC, hFont_osc
            push eax

            invoke DrawTextA, status_hDC, ebx, -1, OFFSET status_rect, DT_EXPANDTABS

            push status_hDC
            call SelectObject

            jmp do_the_blit

        .ENDIF

        EXTERNDEF mainmenu_last_hItem:DWORD ;// defined in hwnd_mainmenu.asm
        mov mainmenu_last_hItem, 0

        invoke DrawTextA, status_hDC, ebx, -1, OFFSET status_rect, DT_EXPANDTABS

        mov status_rect.top, 0  ;// reset the text height

    do_the_blit:

        invoke GetWindowDC, hMainWnd
        DEBUG_IF <!!eax>
        mov edi, eax
        invoke BitBlt, edi,
            nc_status_rect.left, nc_status_rect.top,
            status_rect.right, status_rect.bottom,
            status_hDC, 0, 0, SRCCOPY
        DEBUG_IF <!!eax>, GET_ERROR
        invoke ReleaseDC, hMainWnd, edi

        pop edi

    ;// that's it
    all_done:

        and app_bFlags, NOT APP_SYNC_STATUS ;// turn the flag off

        ret

status_Update ENDP

;//
;//     status_Update
;//
;//
;////////////////////////////////////////////////////////////////////




;////////////////////////////////////////////////////////////////////
;//
;//                         always uses the current hover
;//     build pin name
;//
comment ~ /*

    examples:

    Pin: F oscillator frequency input   Bus: a0 category.member

    Pin: Sample and Hold trigger input (pos gate) Bus: t6 tiplet.eigths

*/ comment ~

ASSUME_AND_ALIGN
status_BuildPinName PROC uses ebx

;// edi must enter as where to store
;// edi exits at the end of the string

    GET_PIN pin_hover, ebx
    DEBUG_IF <!!ebx>    ;// build what pin name ??
    mov ecx, [ebx].dwStatus

;// store the pin header "Pin: "

    mov eax, ' niP'
    stosd

;// store the designator of the pin
    mov eax, 7FFFFFFFh
    PIN_TO_FSHAPE ebx, edx
    and eax, [edx].character
    stosb
    shr eax, 8
    jz @F
    stosb
@@: mov eax, 20202020h
    stosd

;// store the osc name

    PIN_TO_OSC ebx, edx
    OSC_TO_BASE edx, edx
    xor eax, eax
    .IF [edx].data.ID != IDB_CLOSED_GROUP
        BASE_TO_POPUP edx, edx
        mov edx, [edx].pName
        STRCPY edi, edx
    .ELSE
        PIN_TO_OSC ebx, edx
        OSC_TO_DATA edx, edx, GROUP_DATA
        add edx, OFFSET GROUP_DATA.szName

    G0: mov al, BYTE PTR [edx]      ;// ABOX242 AJT
        cmp al, ah
        jz G2
        cmp al, 20h
        ja G1
        mov al, 20h
    G1: stosb
        inc edx
        jmp G0
    G2:

    .ENDIF

    mov al, 20h
    stosb

;// store the pins full name

    PIN_TO_LNAME ebx, edx
    or edx, edx
    jz @F
    STRCPY edi, edx
    mov al, 20h
    stosb
@@:

;// determine input or output

    bt ecx, LOG2(PIN_OUTPUT)
    lea edx, sz_Input   ;// load the most common value
    jnc @F
    lea edx, sz_Output
@@: STRCPY edi, edx

;// check for logic input

    bt ecx, LOG2(PIN_LOGIC_INPUT)
    jnc check_for_bus

;// parse the logic flags

        mov ax, '( '
        stosw

    ;// pos/neg/any edge trigger/gate

        test ecx, PIN_LEVEL_POS OR PIN_LEVEL_NEG
        lea edx, sz_Any     ;// load the most common value
        jz @F
        bt ecx, LOG2(PIN_LEVEL_POS)
        lea edx, sz_Positive    ;// load the most common value
        jc @F
        lea edx, sz_Negative
    @@: STRCPY edi, edx
        mov al, ' '
        stosb

        bt ecx, LOG2(PIN_LOGIC_GATE)
        lea edx, sz_EdgeTrigger ;// load the most common value
        jnc @F
        lea edx, sz_Gate
    @@: STRCPY edi, edx

        mov al, ')'
        stosb

;// check for bus
check_for_bus:

    test [ebx].dwStatus, PIN_BUS_TEST
    jz all_done

    mov ax, '( '
    stosw

    push ebp
    mov edx, edi
    stack_Peek gui_context, ebp
    invoke bus_GetNameFromPin
    mov edi, edx
    pop ebp

    mov al, ')'
    stosb


all_done:

    xor eax, eax    ;// always nul terminate
    mov [edi], al

    ret


status_BuildPinName ENDP


ASSUME_AND_ALIGN
status_BuildOscName PROC

;// edi must enter as where to store
;// edi exits at the end of the string

    GET_OSC_FROM edx, osc_hover
    OSC_TO_BASE edx, edx
    BASE_TO_POPUP edx, edx
    xor eax, eax
    mov edx, [edx].pName

    STRCPY edi, edx

    ret

status_BuildOscName ENDP






ASSUME_AND_ALIGN

ENDIF   ;// USE_THIS_FILE



END

