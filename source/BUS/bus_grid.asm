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
;// bus_grid.asm        the grid on the bus proc is subclassed
;//                     these are the functions that manage it
;//
;//
;// TOC:
;//
;// grid_Initialize
;// grid_Destroy
;// grid_Proc
;// grid_wm_nchittest_proc
;// grid_wm_capturechanged_proc
;// grid_wm_showwindow_proc
;// grid_wm_erasebkgnd_proc
;// grid_wm_paint_proc
;// grid_wm_lbuttondown_proc
;// grid_wm_mousemove_proc
;// grid_wm_lbuttonup_proc
;// grid_DrawFocus
;// grid_SetStatus
;// grid_ResetStatus
;// grid_Update
;// grid_ShowUnused
;// grid_ShowUsed
;// grid_HitTest
;//     grid_unconnect_proc
;//     grid_direct_proc
;//     grid_pull_proc
;// grid_action_connect
;// grid_action_create
;// grid_action_rename
;// grid_action_transfer
;// grid_action_convert


comment ~ /*

    this file would correspond to GRID VIEW functionality

    it owns:

    IDC_BUS_GRID        the grid static window (subclassed)
    IDC_BUS_CONNECT     the connect button
    IDC_BUS_UNCONNECT   the unconnect button

    it accesses the grid_action commands as well

    when initialized

        subclasses the IDC_BUS_GRID control
        sets up the rectangle values needed for the control
        creates a bitmap and dc to draw with

    when displayed,

        it will set the bus window's title
        show the buttons
        update the IDC_BUS_STATUS text



*/ comment ~

OPTION CASEMAP:NONE

.586
.MODEL FLAT

        .NOLIST
        include <Abox.inc>
        include <bus.inc>
        .LIST

.DATA
;// grid
;//
;//     to display the 240 buttons using windows can be time comsumming
;//     so we create a dc, bitmap, and positioning coords to do the job
;//     the dialog control IDC_BUS_GRID controls the geometry
;//
;//     performance is acheived by using the gridList to hit test
;//     grid_Update will build the list

        grid_hWnd       dd  0   ;// hWnd for the control
        grid_OldProc    dd  0   ;// we subclass the grid list

        grid_hDC    dd  0       ;// dc for graphics
        grid_hBmp   dd  0       ;// bitmap for that dc

        grid_rect   RECT {}     ;// size of the bitmap and static control
        grid_left_rect  RECT {} ;// for eraseing the left block
        grid_right_rect RECT {} ;// for eraseing the right block

    ;// this list determines what buttons are on and need testing
    ;// build by bus_ShowUsed or bus_ShowUnused

        slist_Declare gridList ;//, BUS_EDIT_RECORD, pNextRect

    ;// these keep track of which button is pressed

        grid_down       dd  0   ;// this is the address of the bus in question
        grid_down_flags dd  0   ;// tells if button is up or down
        grid_hover      dd  0   ;// use bus_HitTest to determine

    ;// handles "owned" by this control

        hWnd_Unconnect  dd  0
        hWnd_Direct     dd  0
        hWnd_Pull       dd  0

    ;// grid window layout

        NUM_BUS_COLS    equ 22
        GRID_COL_WIDTH  equ 12

        NUM_BUS_ROWS    equ 14
        GRID_ROW_HEIGHT equ 12

    ;// the grid_mode is set at grid_Update
    ;// and tells us what pressing one of the grids actually does

        grid_mode   dd 0    ;// flags for operational mode

        GRID_MODE_CREATE    equ 0   ;// create a new bus
        GRID_MODE_CONNECT   equ 1   ;// connect an input to a bus
        GRID_MODE_RENAME    equ 2   ;// rename a bus source
        GRID_MODE_TRANSFER  equ 3   ;// transfer input to another bus
        GRID_MODE_CONVERT   equ 4   ;// convert to a bus

        ;// jump table to get to the desired routine and the name to display

        grid_mode_table dd  grid_action_create, OFFSET sz_create
                        dd  grid_action_connect, OFFSET sz_connect
                        dd  grid_action_rename, OFFSET sz_rename
                        dd  grid_action_transfer,OFFSET sz_transfer
                        dd  grid_action_convert, OFFSET sz_convert

    ;// strings for building the status
    ;// these idicate actions caused by pressing one of the grid buttons

        sz_create   db  'Create ',0
        sz_connect  db  'Connect to ',0
        sz_rename   db  'Rename as ',0
        sz_transfer db  'Transfer to ',0
        sz_convert  db  'Convert to ', 0

    ;// private functions in this file

        grid_HitTest    PROTO

        grid_Update     PROTO
        grid_ShowUsed   PROTO
        grid_ShowUnused PROTO

        grid_DrawFocus  PROTO STDCALL pBus:DWORD
        grid_SetStatus  PROTO STDCALL pBus:DWORD
        grid_ResetStatus PROTO



.CODE

;////////////////////////////////////////////////////////////////////
;//
;//
;//     INITIALIZE AND DESTROY
;//

ASSUME_AND_ALIGN
grid_Initialize PROC STDCALL uses esi edi ebx

    ;// this is called from WM_CREATE when the bus dialog is first built

        LOCAL rect:RECT
        LOCAL char1:DWORD
        LOCAL char2:DWORD

    ;// get some handles and determine  size of the grid

        invoke GetDlgItem, bus_hWnd, IDC_BUS_UNCONNECT
        mov hWnd_Unconnect, eax
        invoke GetDlgItem, bus_hWnd, IDC_BUS_DIRECT
        mov hWnd_Direct, eax
        invoke GetDlgItem, bus_hWnd, IDC_BUS_PULL
        mov hWnd_Pull, eax
        invoke GetDlgItem, bus_hWnd, IDC_BUS_GRID
        lea edi, grid_rect
        mov grid_hWnd, eax
        invoke GetClientRect, eax, edi

    ;// initialize the grid bitmap and DC

        invoke GetDesktopWindow
        mov esi, eax
        invoke GetDC, eax
        mov ebx, eax
        invoke CreateCompatibleDC, ebx
        mov grid_hDC, eax
        invoke CreateCompatibleBitmap, ebx, grid_rect.right, grid_rect.bottom
        mov grid_hBmp, eax
        invoke ReleaseDC, esi, ebx
        invoke SelectObject, grid_hDC, grid_hBmp

        invoke SelectObject, grid_hDC, hFont_osc
        invoke SetBkMode, grid_hDC, TRANSPARENT
        invoke GetSysColor, COLOR_BTNTEXT
        invoke SetTextColor, grid_hDC, eax

    ;// fill it

        invoke FillRect, grid_hDC, OFFSET grid_rect, COLOR_BTNFACE+1

    ;// define the grid left and right rects for subsequent eraseing

        ;// top and bottom are the same for both

        mov eax, GRID_ROW_HEIGHT            ;// top row
        lea edx, [eax+GRID_ROW_HEIGHT*12]   ;// bottom of bottom row

        mov grid_left_rect.top, eax
        mov grid_right_rect.top, eax
        mov grid_left_rect.bottom, edx
        mov grid_right_rect.bottom, edx

        ;// left and right are iterated

        mov eax, GRID_COL_WIDTH             ;// first column
        lea edx, [eax+GRID_COL_WIDTH*10]    ;// right of first column

        mov grid_left_rect.left, eax
        mov grid_left_rect.right, edx

        add eax, GRID_COL_WIDTH * 11
        add edx, GRID_COL_WIDTH * 11

        mov grid_right_rect.left, eax
        mov grid_right_rect.right, edx

    ;// layout the number indexes, use rect as an iterator
    ;// there are two sets of these in one row
    ;//  "0 1 2 3 4 5 6 7 8 9      0 1 2 3 4 5 6 7 8 9"

        rect_Set rect, GRID_COL_WIDTH, 0, GRID_COL_WIDTH * 2, GRID_ROW_HEIGHT
        mov char1, '0'
        lea ebx, char1
        lea esi, rect

        .REPEAT

            invoke DrawTextA, grid_hDC, ebx, 1, esi, DT_NOCLIP + DT_CENTER + DT_VCENTER + DT_SINGLELINE

            add rect.left, GRID_COL_WIDTH * 11
            add rect.right, GRID_COL_WIDTH * 11

            invoke DrawTextA, grid_hDC, ebx, 1, esi, DT_NOCLIP + DT_CENTER + DT_VCENTER + DT_SINGLELINE

            sub rect.left, GRID_COL_WIDTH * 10
            sub rect.right, GRID_COL_WIDTH * 10

            inc char1

        .UNTIL char1 > '9'

    ;// layout the letter indexes
    ;// there are two columns of these
    ;// a b c d e f g h i j k m
    ;// n p q r s t u v w x y z

        rect_Set rect, 0, GRID_ROW_HEIGHT, GRID_COL_WIDTH, GRID_ROW_HEIGHT*2

        mov char1, 'a'
        mov char2, 'n'

        lea edi, char2

        .REPEAT

            invoke DrawTextA, grid_hDC, ebx, 1, esi, DT_NOCLIP + DT_CENTER + DT_VCENTER + DT_SINGLELINE

            add rect.left, GRID_COL_WIDTH * 11
            add rect.right, GRID_COL_WIDTH * 11

            invoke DrawTextA, grid_hDC, edi, 1, esi, DT_NOCLIP + DT_CENTER + DT_VCENTER + DT_SINGLELINE

            sub rect.left, GRID_COL_WIDTH * 11
            sub rect.right, GRID_COL_WIDTH * 11
            add rect.top, GRID_ROW_HEIGHT
            add rect.bottom, GRID_ROW_HEIGHT

            inc char1
            .IF char1=='l'
                inc char1
            .ENDIF
            inc char2
            .IF char2=='o'
                inc char2
            .ENDIF

        .UNTIL char1 == 'n'

    ;// initilize the rects of each item in the bus table

    comment ~ /*

        there are two 10x12 blocks of rectangles
        for each block we store 12 coordinates (3 rects)

        we will need three counters to do the job

        block   (0 and 1)
        row     (two scans of 12 each)
        col     (ten iterates per row)

        coords to set are


            hit_test.left       top_rect.left   = hit_rect.left     ax
            hit_test.right      top_rect.right  = hit_rect.right    bx
            hit_test.top        left_rect.top   = hit_rect.top      dl
            hit_test.bottom     left_rect.bottom= hit_rect.bottom   dh

            left_rect.left  = 0 or GRID_COL_WIDTH*10                cl
            left_rect.right = GRID_COL_WIDTH or GRID_COL_WIDTH*11   ch

            top_rect.top    = 0
            top_rect.bottom = GRID_ROW_HEIGHT

    */ comment ~

            ASSUME esi:PTR BUS_EDIT_RECORD

            push ebp            ;// ebp will count tens

            mov esi, bus_pTable ;// esi iterates bus records
            mov edi, bus_pEnd   ;// edi tells us when to stop

            xor eax, eax    ;// no stalls
            xor ebx, ebx    ;// no stalls
            xor ecx, ecx    ;// no stalls
            xor edx, edx    ;// no stalls

            mov ax, GRID_COL_WIDTH      ;// ax will set LEFT sides
            mov bx, GRID_COL_WIDTH*2    ;// bs will set RIGHT sides
            mov dl, GRID_ROW_HEIGHT     ;// dl will set TOP sides
            mov dh, GRID_ROW_HEIGHT*2   ;// dh will set BOTTOM sides
            mov ch, GRID_COL_WIDTH      ;// ch will set RIGHT sides of left_rect
                                        ;// cl will set LEFT sides of left_rect
            mov ebp, 10                 ;// ebp counts to 10

        @@: mov WORD PTR [esi].hit_rect.left, ax
            mov WORD PTR [esi].top_rect.left, ax
            mov WORD PTR [esi].hit_rect.right, bx
            mov WORD PTR [esi].top_rect.right,  bx
            mov BYTE PTR [esi].hit_rect.top, dl
            mov BYTE PTR [esi].left_rect.top, dl
            mov BYTE PTR [esi].hit_rect.bottom, dh
            mov BYTE PTR [esi].left_rect.bottom, dh
            mov BYTE PTR [esi].left_rect.left, cl
            mov BYTE PTR [esi].left_rect.right, ch
            mov BYTE PTR [esi].top_rect.bottom, GRID_ROW_HEIGHT

            add esi, SIZEOF BUS_EDIT_RECORD ;// advance the record pointer every time
            cmp esi, edi                ;// done yet ??
            jae rects_are_done
            mov ax, bx                  ;// go left
            add bx, GRID_COL_WIDTH      ;// go left
            dec ebp                     ;// decrease row counter
            jnz @B                      ;// jump if not zero
            mov ebp, 10                 ;// reset the row counter
            sub ax, GRID_COL_WIDTH*10   ;// scoot back to start column
            sub bx, GRID_COL_WIDTH*10   ;// scoot back to start column
            mov dl, dh                  ;// go down
            add dh, GRID_ROW_HEIGHT     ;// go down
            cmp dl, GRID_ROW_HEIGHT*12  ;// see if done with block
            jbe @B                      ;// jump if not done
            mov dl, GRID_ROW_HEIGHT     ;// back to top row
            mov dh, GRID_ROW_HEIGHT*2   ;// back to top row
            mov cl, GRID_COL_WIDTH*11   ;// next letter block
            mov ch, GRID_COL_WIDTH*12   ;// next letter block
            mov ax, GRID_COL_WIDTH*12   ;// first column of next grid block
            mov bx, GRID_COL_WIDTH*13   ;// first column of next grid block
            jmp @B                      ;// continue on

        rects_are_done:

            pop ebp

    ;// now we subclass this control

        lea edx, grid_Proc
        invoke SetWindowLongA, grid_hWnd, GWL_WNDPROC, edx
        mov grid_OldProc, eax

    ;// that's it

        ret


grid_Initialize ENDP



grid_Destroy PROC

    ;// un subclass
    ;// ditch the DC and bitmap


    invoke DeleteDC, grid_hDC       ;// free the dc
    invoke DeleteObject, grid_hBmp  ;// free the bitmap
    DEBUG_IF <!!eax>
    invoke SetWindowLongA, grid_hWnd, GWL_WNDPROC, grid_OldProc ;// un subclass

    ret

grid_Destroy ENDP
;//
;//
;//     INITIALIZE AND DESTROY
;//
;////////////////////////////////////////////////////////////////////









;////////////////////////////////////////////////////////////////////
;//
;//
;//     GRID WINDOW PROCEEDURE AND HANDLERS
;//
ASSUME_AND_ALIGN
grid_Proc   PROC PRIVATE ;// STDCALL hWnd,msg,wParam,lParam

        mov eax, WP_MSG

        HANDLE_WM WM_SHOWWINDOW, grid_wm_showwindow_proc    ;// activation

        HANDLE_WM WM_CAPTURECHANGED, grid_wm_capturechanged_proc
        HANDLE_WM WM_NCHITTEST, grid_wm_nchittest_proc      ;// mouseing

        HANDLE_WM WM_LBUTTONDOWN, grid_wm_lbuttondown_proc
        HANDLE_WM WM_LBUTTONUP, grid_wm_lbuttonup_proc
        HANDLE_WM WM_MOUSEMOVE, grid_wm_mousemove_proc

        HANDLE_WM WM_PAINT, grid_wm_paint_proc
        HANDLE_WM WM_ERASEBKGND, grid_wm_erasebkgnd_proc

    grid_call_def_wind::

        SUBCLASS_DEFPROC grid_OldProc

        ret 10h

grid_Proc   ENDP



;// WM_NCHITTEST
;// xPos = LOWORD(lParam);  // horizontal position of cursor
;// yPos = HIWORD(lParam);  // vertical position of cursor

ASSUME_AND_ALIGN
grid_wm_nchittest_proc PROC PRIVATE ;// STDCALL hWnd,msg,wParam,lParam

    ;// if this is hit, then we need to get the capture.

    invoke SetCapture, grid_hWnd
    mov eax, HTCLIENT
    ret 10h

grid_wm_nchittest_proc ENDP

ASSUME_AND_ALIGN
grid_wm_capturechanged_proc PROC PRIVATE ;// STDCALL hWnd,msg,wParam,lParam

    mov eax, WP_LPARAM
    cmp eax, grid_hWnd
    jne loosing_capture

    mov dlg_mode, DM_GRID_CAPTURE
    jmp @F

loosing_capture:

    xor edx, edx
    and dlg_mode, NOT DM_GRID_CAPTURE
    or edx, grid_hover
    jz @F
    invoke grid_DrawFocus, edx
    invoke grid_ResetStatus
    xor eax, eax
    mov grid_hover, eax

@@: invoke InvalidateRect, grid_hWnd, 0, 0
    xor eax, eax
    ret 10h

grid_wm_capturechanged_proc ENDP



;// WM_SHOWWINDOW
;// fShow = (BOOL) wParam;      // show/hide flag
;// fnStatus = (int) lParam;    // status flag

ASSUME_AND_ALIGN
grid_wm_showwindow_proc PROC PRIVATE ;// STDCALL hWnd,msg,wParam,lParam

    ;// are we showing or hiding ?
    xor eax, eax
    or eax, WP_WPARAM
    jnz showing_window

hiding_window:

    ;// hide the other control buttons as well

    invoke ShowWindow, hWnd_Unconnect, SW_HIDE
    invoke ShowWindow, hWnd_Direct, SW_HIDE
    invoke ShowWindow, hWnd_Pull, SW_HIDE

    ;// make sure we do NOT have the mouse cpature

    btr dlg_mode, LOG2(DM_GRID_CAPTURE)
    jnc grid_call_def_wind
    invoke ReleaseCapture
    jmp grid_call_def_wind

showing_window:

    ;// make sure we know what our mode is and setup the controls we need

    invoke ShowWindow, hWnd_Unconnect, SW_SHOW
    invoke ShowWindow, hWnd_Direct, SW_SHOW
    invoke ShowWindow, hWnd_Pull, SW_SHOW

    jmp grid_call_def_wind

grid_wm_showwindow_proc ENDP




ASSUME_AND_ALIGN
grid_wm_erasebkgnd_proc PROC PRIVATE ;// STDCALL hWnd,msg,wParam,lParam

    or eax, 1
    ret 10h

grid_wm_erasebkgnd_proc ENDP



ASSUME_AND_ALIGN
grid_wm_paint_proc PROC PRIVATE  ;// STDCALL hWnd,msg,wParam,lParam

    ;// always make sure we're initialized

        btr dlg_mode, LOG2(DM_GRID_INIT)
        jnc @F
        invoke grid_Update
@@:
    ;// blit the bitmap

        sub esp, SIZEOF PAINTSTRUCT
        invoke BeginPaint, grid_hWnd, esp
        invoke BitBlt, eax, 0,0,grid_rect.right, grid_rect.bottom,
                        grid_hDC, 0, 0, SRCCOPY
        invoke EndPaint, grid_hWnd, esp
        add esp, SIZEOF PAINTSTRUCT

    ;// then return zero

        xor eax, eax
        ret 10h

grid_wm_paint_proc ENDP



;////////////////////////////////////////////////////////////////////
;//
;//
;//     WM_LBUTTONDOWN
;//
ASSUME_AND_ALIGN
grid_wm_lbuttondown_proc PROC PRIVATE ;// STDCALL hWnd,msg,wParam,lParam

    ;// get our point and call hit test

        spoint_Get WP_LPARAM
        invoke grid_HitTest
        or ecx, ecx         ;// test that we got something
        mov grid_down, ecx  ;// set the grid down, regardless the value
        jz @F               ;// jump if not hit

            ;// we're pressing a button,
            ;// so we need to draw the button as pressing
            ;// the invalidate the rect

            mov grid_down_flags, DFCS_BUTTONPUSH + DFCS_PUSHED
            ASSUME ecx:PTR BUS_EDIT_RECORD
            invoke DrawFrameControl, grid_hDC, ADDR [ecx].hit_rect, DFC_BUTTON, DFCS_BUTTONPUSH + DFCS_PUSHED
            invoke RedrawWindow, grid_hWnd, 0,0, RDW_INVALIDATE
        @@:

    ;// return zero
        xor eax, eax
        ret 10h

grid_wm_lbuttondown_proc ENDP
;//
;//     WM_LBUTTONDOWN
;//
;//
;////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////
;//
;//                             jumped to from handler
;//     WM_MOUSEMOVE
;//     fwKeys = wParam;        // key flags
;//     xPos = LOWORD(lParam);  // horizontal position of cursor
;//     yPos = HIWORD(lParam);  // vertical position of cursor
;//
ASSUME_AND_ALIGN
grid_wm_mousemove_proc PROC PRIVATE     ;// STDCALL hWnd,msg,wParam,lParam

    ;// step one is to make sure we are supposed to have the capture

        spoint_Get WP_LPARAM

        cmp eax, grid_rect.right
        ja loose_this_capture
        cmp edx, grid_rect.bottom
        ja loose_this_capture

    ;// we have the capture, so we hit test and do what needs to be done

        push esi
        push edi

        invoke grid_HitTest

        mov edi, grid_hover     ;// load the old hover
        ASSUME edi:PTR BUS_EDIT_RECORD
        cmp ecx, grid_hover     ;// see if this is different
        mov grid_hover, ecx     ;// always set the hover
        mov esi, ecx            ;// esi will be the new hover
        ASSUME esi:PTR BUS_EDIT_RECORD

        je check_for_grid_down  ;// are hovers different ?

        or edi, edi             ;// was there an old hover ?
        jz @F
        invoke grid_DrawFocus, edi  ;// reset old focus
    @@:
        or esi, esi             ;// is there a new focus ??
        jz @F
        invoke grid_DrawFocus, esi  ;// set the new status text
        invoke grid_SetStatus, esi  ;// set the status text
        jmp done_with_hovers
    @@:
        invoke grid_ResetStatus ;// turn old line off

    done_with_hovers:

        invoke InvalidateRect, grid_hWnd, 0, 0

    check_for_grid_down:

        xor edx, edx
        or edx, grid_down       ;// see if there's a grid down
        .IF !ZERO?

            ASSUME edx:PTR BUS_EDIT_RECORD

            cmp edx, ecx        ;// see if grid down matches grid hover
            mov ecx, DFCS_BUTTONPUSH + DFCS_PUSHED  ;// load the most common value
            je @F               ;// it does, so we make sure to redraw in down state
            mov ecx, DFCS_BUTTONPUSH    ;// it doesn't, so we have to redraw the button in a raised state
         @@:
            .IF ecx != grid_down_flags  ;// then make sure we have to this at all

                mov grid_down_flags, ecx
                invoke DrawFrameControl, grid_hDC, ADDR [edx].hit_rect, DFC_BUTTON, ecx
                invoke RedrawWindow, grid_hWnd, 0,0, RDW_INVALIDATE

            .ENDIF

        .ENDIF

        pop edi
        pop esi

        jmp all_done

loose_this_capture:

    .IF !grid_down
        invoke ReleaseCapture
    .ENDIF

all_done:

    xor eax, eax
    ret 10h

grid_wm_mousemove_proc ENDP
;//
;//     WM_MOUSEMOVE
;//
;//
;////////////////////////////////////////////////////////////////////





;////////////////////////////////////////////////////////////////////
;//
;//
;//     WM_LBUTTONUP
;//
ASSUME_AND_ALIGN
grid_wm_lbuttonup_proc PROC PRIVATE ;// STDCALL hWnd,msg,wParam,lParam

    .IF grid_down   ;// see if we've a button pressed

        spoint_Get WP_LPARAM

        invoke grid_HitTest

        .IF ecx && ecx == grid_down

            ;// we just let up on a button
            ;// so we do the default action

            mov eax, grid_mode
            mov grid_down, 0    ;// always reset this
            mov eax, grid_mode_table[eax*8]
            jmp eax

        .ENDIF

        ;// if we hit this, then we have missed a point and need to reset the button

        mov ecx, grid_down
        ASSUME ecx:PTR BUS_EDIT_RECORD
        invoke DrawFrameControl, grid_hDC, ADDR [ecx].hit_rect, DFC_BUTTON, DFCS_BUTTONPUSH
        invoke RedrawWindow, grid_hWnd, 0,0, RDW_INVALIDATE

        mov grid_down, 0
        mov grid_down_flags, DFCS_BUTTONPUSH

    .ENDIF

    btr dlg_mode, LOG2(DM_GRID_CAPTURE)
    jnc @F
    invoke ReleaseCapture
@@: xor eax, eax

    ret 10h

grid_wm_lbuttonup_proc ENDP
;//
;//     WM_LBUTTONUP
;//
;//
;////////////////////////////////////////////////////////////////////


;//
;//     WINDOW PROCEEDURE AND HANDLERS
;//
;//
;////////////////////////////////////////////////////////////////////





;////////////////////////////////////////////////////////////////////
;//
;//
;//     PRIVATE HELPER FUNCTIONS
;//


PROLOGUE_OFF
ASSUME_AND_ALIGN
grid_DrawFocus PROC STDCALL PRIVATE pBus:DWORD

    ;// this draws the three focus rects for the grid control

    ;// stack looks like this
    ;// ret pBus....
    xchg ebx, [esp+4]   ;// save ebx and get the parameter
    ASSUME ebx:PTR BUS_EDIT_RECORD

    ;// turn off the old focus rects
    invoke DrawFocusRect, grid_hDC, ADDR [ebx].left_rect
    invoke DrawFocusRect, grid_hDC, ADDR [ebx].top_rect

    mov ecx, 2
    mov edx, [ebx].hit_rect.bottom
    mov eax, [ebx].hit_rect.right
    sub edx, ecx
    sub eax, ecx
    push edx
    push eax
    mov ecx, GRID_COL_WIDTH-4
    sub edx, ecx
    sub eax, ecx
    push edx
    push eax
    invoke DrawFocusRect, grid_hDC, esp
    add esp, SIZEOF RECT

    xchg ebx, [esp+4]
    ret 4

grid_DrawFocus ENDP
PROLOGUE_ON



;////////////////////////////////////////////////////////////////////
;//
;//
;//     grid_SetSttatus  builds the status line
;//
ASSUME_AND_ALIGN
PROLOGUE_OFF
grid_SetStatus PROC STDCALL PRIVATE pBus:DWORD

    xchg esi, [esp+4]       ;// save esi and get the parameter
    sub esp, 128            ;// make room for temp strings
    mov edx, esp            ;// edx must point at string space

    mov eax, grid_mode                          ;// get the mode
    mov ecx, grid_mode_table[eax*8+4]           ;// get the prefix string
    STRCPY edx, ecx                             ;// copy it
    invoke bus_GetNameFromRecord                ;// append the full name
    WINDOW hWnd_bus_status, WM_SETTEXT,0,esp    ;// set the text

    add esp, 128            ;// clean up the string space
    xchg esi, [esp+4]       ;// retrive esi
    ret 4

grid_SetStatus ENDP
PROLOGUE_ON


ASSUME_AND_ALIGN
grid_ResetStatus PROC

    pushd 0
    WINDOW hWnd_bus_status, WM_SETTEXT,0,esp    ;// set the text
    pop eax
    ret

grid_ResetStatus ENDP








;////////////////////////////////////////////////////////////////////
;//
;//                         updates the appropriate buttons
;//     grid_Update         uses bus_pPin
;//                         called from grid_wm_showwindow_proc
ASSUME_AND_ALIGN
grid_Update PROC PRIVATE uses ebx edi esi

    ;// this builds the grid bitmap
    ;// and sets grid_mode

        GET_PIN bus_pPin, ebx
        mov edi, [ebx].dwStatus
        xor esi, esi

    ;// blank out the local bitmap, takes two fills

        invoke FillRect, grid_hDC, OFFSET grid_left_rect, COLOR_BTNFACE+1
        invoke FillRect, grid_hDC, OFFSET grid_right_rect, COLOR_BTNFACE+1

    ;// decide what mode we're in and design the bitmap accordingly

        OR_GET_PIN [ebx].pPin, esi
        jz pin_not_connected

    pin_is_connected:       ;// connected (esi holds either the head or the next pin)

        invoke EnableWindow, hWnd_Unconnect, 1
        invoke EnableWindow, hWnd_Pull, 1

        test edi, PIN_BUS_TEST
        jz not_conected_to_bus  ;// connected and bus

        invoke EnableWindow, hWnd_Direct, 1

        bt edi, LOG2(PIN_OUTPUT)
        jnc is_bussed_input

    is_bussed_output:       ;// connected, bus, output pin

        mov edi, GRID_MODE_RENAME   ;// rename a bus source
        jmp show_unused

    is_bussed_input:        ;// connected, bus, input pin

        mov edi, GRID_MODE_TRANSFER ;// transfer input to another bus
        jmp show_used;// show used pins

    not_conected_to_bus:    ;// connected, not bus

        invoke EnableWindow, hWnd_Direct, 0 ;// can't direct connect nothing

        mov edi, GRID_MODE_CONVERT  ;// convert to a bus
        jmp show_unused             ;// show unused

    pin_not_connected:      ;// not connected

        invoke EnableWindow, hWnd_Direct, 0 ;// can't direct connect nothing

        test edi, PIN_BUS_TEST
        jz unbussed_input_or_output

    unconected_bus_source:  ;// not connected, and a bus, so we must be an output

        invoke EnableWindow, hWnd_Unconnect, 1  ;// allow unconnect
        invoke EnableWindow, hWnd_Pull, 0       ;// pull to what ?

        mov edi, GRID_MODE_RENAME   ;// transfer input to another bus
        jmp show_unused             ;// show unused

    unbussed_input_or_output:       ;// not connected, not a bus

        invoke EnableWindow, hWnd_Unconnect, 0  ;// disallow unconnect
        invoke EnableWindow, hWnd_Pull, 0       ;// pull to what ?

        bt edi, LOG2(PIN_OUTPUT)
        jnc unconnected_input

    unconnected_output:     ;// not connected, not bus, output pin

        mov edi, GRID_MODE_CREATE   ;// create a new bus
        jmp show_unused             ;// show unused

    unconnected_input:      ;// not connected, not bus, input pin

        mov edi, GRID_MODE_CONNECT  ;// connect an input to a bus

    show_used:

        invoke grid_ShowUsed        ;// show unused
        jmp all_done

    show_unused:

        invoke grid_ShowUnused      ;// show used

    all_done:

        mov grid_mode, edi  ;// store the grid mode
        mov grid_hover, 0   ;// move the grid hover with 0

        ret

grid_Update ENDP
;//
;//     grid_Update
;//
;//
;////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////
;//
;//
;//     grid_ShowUnused
;//
ASSUME_AND_ALIGN
grid_ShowUnused PROC PRIVATE    uses edi esi ebx

    ;// here we scan backwards through the busAry table
    ;// and build buttons for unused entries
    ;// each button is then added to the bus rect list

    ;//slist_Erase gridList ;// clear the grid list

        xor edx, edx
        xor ecx, ecx
        slist_OrGetHead gridList, edx           ;// check for empty list
        .IF !ZERO?
        .REPEAT                                 ;// erase all the items
            xor eax, eax
            slist_OrGetNext gridList, edx, eax  ;// or eax, [edx].gridList&_slist_next
            mov slist_Next(gridList,edx), ecx   ;// mov [edx].gridList&_slist_next, 0
            mov edx, eax
        .UNTIL ZERO?
        mov slist_Head(gridList), eax
        .ENDIF


    stack_Peek gui_context, edi         ;// get the latest context

    mov esi, bus_pEnd                       ;// start at end of table
    ASSUME esi:PTR BUS_EDIT_RECORD
    lea edi, [edi].bus_table[NUM_BUSSES*4]  ;// get the end of the context's bus table
    ASSUME edi:PTR DWORD
    xor ebx, ebx                            ;// clear for zeroing

@@: sub esi, SIZEOF BUS_EDIT_RECORD ;// iterate the bus edit record
    sub edi, 4                  ;// iterate the bus pointer
    cmp esi, bus_pTable         ;// done yet ?
    jb @F                       ;// jump if done
    cmp ebx, [edi]              ;// this used ?
    jne @B                      ;// jump if yes

    ;// this entry is not used
    invoke DrawFrameControl, grid_hDC, ADDR [esi].hit_rect, DFC_BUTTON, DFCS_BUTTONPUSH
    slist_InsertHead gridList, esi
    jmp @B

    ;// that's it

@@: ret

grid_ShowUnused ENDP
;//
;//
;//     grid_ShowUnused
;//
;////////////////////////////////////////////////////////////////////






;////////////////////////////////////////////////////////////////////
;//
;//                       called from bus_Update_Grid
;//     grid_ShowUsed
;//
ASSUME_AND_ALIGN
grid_ShowUsed PROC PRIVATE uses ebp edi esi ebx

    ;// task:   draw unpushed buttons on the grid bitmap
    ;//         assume that the drawing space is already cleared
    ;//         skip bus_pPin

    ;// scan backwards through the busAry table
    ;// and build buttons for unused entries
    ;// each button is then added to the bus rect list

    GET_PIN bus_pPin, ebp           ;// load the pin

;// slist_Erase gridList            ;// clear the grid list

        xor edx, edx
        xor ecx, ecx
        slist_OrGetHead gridList, edx           ;// check for empty list
        .IF !ZERO?
        .REPEAT                                 ;// erase all the items
            xor eax, eax
            slist_OrGetNext gridList, edx, eax  ;// or eax, [edx].gridList&_slist_next
            mov slist_Next(gridList,edx), ecx   ;// mov [edx].gridList&_slist_next, 0
            mov edx, eax
        .UNTIL ZERO?
        mov slist_Head(gridList), eax
        .ENDIF


    mov ebp, [ebp].dwStatus         ;// get the pin's status

    stack_Peek gui_context, edi ;// get the latest context

    and ebp, 0FFh                   ;// strip out extra from status

    mov esi, bus_pEnd               ;// start at end of table
    ASSUME esi:PTR BUS_EDIT_RECORD

    lea ebp, [edi].bus_table[ebp*4-4]   ;// get the bus table pointer

    xor ebx, ebx                    ;// clear for zeroing

    lea edi, [edi].bus_table[NUM_BUSSES*4]  ;// get the end of the context's bus table

    ASSUME edi:PTR DWORD


@@: sub esi, SIZEOF BUS_EDIT_RECORD ;// iterate the bus edit record
    sub edi, 4          ;// iterate the bus pointer
    cmp esi, bus_pTable ;// done yet ?
    jb @F               ;// jump if done
    cmp ebx, [edi]      ;// this used ?
    je @B               ;// jump if not used
    cmp edi, ebp        ;// is this us ?
    je @B               ;// skip ourselves

    ;// this entry is not used

    invoke DrawFrameControl, grid_hDC, ADDR [esi].hit_rect, DFC_BUTTON, DFCS_BUTTONPUSH
    slist_InsertHead gridList, esi

    jmp @B


    ;// that's it

@@: ret

grid_ShowUsed ENDP
;//
;//     grid_ShowUsed
;//
;//
;////////////////////////////////////////////////////////////////////














;///////////////////////////////////////////////////////////////////
;//
;//                         determines where the mouse is hit
;//     grid_HitTest
;//
ASSUME_AND_ALIGN
grid_HitTest PROC PRIVATE

    ;// eax,edx must be the point to test
    ;// only tests buttons that exist in the gridList
    ;//
    ;// returns ecx as the bus record pointer
    ;// or zero for nothing hit

    slist_GetHead gridList, ecx
    .WHILE ecx

        cmp eax, [ecx].hit_rect.left
        jb J0
        cmp edx, [ecx].hit_rect.top
        jb J0
        cmp eax, [ecx].hit_rect.right
        ja J0
        cmp edx, [ecx].hit_rect.bottom
        jbe J1

    J0: slist_GetNext gridList, ecx

    .ENDW

J1: ret

grid_HitTest ENDP
;//
;//
;//     grid_HitTest
;//
;///////////////////////////////////////////////////////////////////







;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////
;////
;////   bus_ActionCommands
;////


    ;////////////////////////////////////////////////////////////////////
    ;//
    ;//                                 jumped to by button_clicked_proc
    ;//     bus connection commands     stack frame has NOT been set yet
    ;//

    ASSUME_AND_ALIGN
    grid_unconnect_proc PROC    ;// STDCALL hWnd, msg, wParam, lParam

        push ebp
        push ebx

        stack_Peek gui_context, ebp

        invoke mouse_reset_all_hovers

        mov ebx, bus_pPin
        unredo_BeginAction UNREDO_UNCONNECT

    ENTER_PLAY_SYNC GUI
        invoke pin_Unconnect
    LEAVE_PLAY_SYNC GUI

        unredo_EndAction UNREDO_UNCONNECT

        pop ebx
        pop ebp

        ;// we can either close the dialog, or reinitialize it ....

        invoke ReleaseCapture

        invoke SetFocus, hMainWnd

        xor eax, eax
        ret 10h

    grid_unconnect_proc ENDP

    ASSUME_AND_ALIGN
    grid_direct_proc PROC   ;// STDCALL hWnd, msg, wParam, lParam

        push ebp
        push ebx

        stack_Peek gui_context, ebp

        invoke mouse_reset_all_hovers

        GET_PIN bus_pPin, ebx   ;// get one pin on the bus

        unredo_BeginEndAction UNREDO_BUS_DIRECT

        invoke bus_Direct

        pop ebx
        pop ebp

        invoke ReleaseCapture

        invoke SetFocus, hMainWnd

        xor eax, eax
        ret 10h

    grid_direct_proc ENDP

    ASSUME_AND_ALIGN
    grid_pull_proc  PROC

        ;// make a call to bus_Pull

        push ebp
        push ebx

        stack_Peek gui_context, ebp

        invoke mouse_reset_all_hovers

        mov ebx, bus_pPin

        unredo_BeginAction UNREDO_BUS_PULL

        invoke bus_Pull

        unredo_EndAction UNREDO_BUS_PULL

        pop ebx
        pop ebp

        ;// we can either close the dialog, or reinitialize it ....

        invoke ReleaseCapture

        invoke SetFocus, hMainWnd

        xor eax, eax
        ret 10h

    grid_pull_proc ENDP




    ;//
    ;//
    ;//     bus connection commands
    ;//
    ;////////////////////////////////////////////////////////////////////










;////////////////////////////////////////////////////////////////////
;//
;//                         all are jumped to by wm_lbuttonup
;//     grid_actions
;//                         stack frame has NOT been set yet
;//                         all these functions must exit the wm_handler
;//
;//         ecx enters as a bus record pointer


ASSUME_AND_ALIGN
grid_action_connect PROC PRIVATE    ;// stdcall hWnd, msg, wParam, lParam

    ;// connect an unconnected input pin to a bus source
    ;// ecx enters as a bus record pointer
    ;// stack frame has NOT been set yet
    ;// this will be a call to pin_connect_UI_CO

        ASSUME ecx:PTR BUS_EDIT_RECORD

        push ebp
        push edi
        push ebx

        stack_Peek gui_context, ebp

        push ecx

        invoke mouse_reset_all_hovers   ;// have to do this now, the pin is going to change states

        unredo_BeginAction UNREDO_CONNECT_PIN

        pop ecx
        mov ecx, [ecx].number   ;// load the index of the passed record
        mov edi, bus_pPin       ;// load the unconnected input pin

        mov ebx, BUS_TABLE(ecx) ;// load the head of specifed the bus
        ENTER_PLAY_SYNC GUI     ;// always enter play wait

            invoke pin_connect_UI_CO

            or [ebp].pFlags, PFLAG_TRACE
            ;//or [ebp].pFlags, GFLAG_AUTO_UNITS
            ;//or app_bFlags, APP_SYNC_UNITS
            invoke context_SetAutoTrace         ;// schedule a unit trace

        LEAVE_PLAY_SYNC GUI ;// exit play wait

        unredo_EndAction UNREDO_CONNECT_PIN

        pop ebx
        pop edi
        pop ebp

    ;// hide the dialog by setting the focus to main wnindow

        invoke ReleaseCapture
        invoke SetFocus, hMainWnd

        xor eax, eax
        ret 10h

grid_action_connect ENDP




ASSUME_AND_ALIGN
grid_action_create PROC PRIVATE ;// stdcall hWnd, msg, wParam, lParam

    ;// connect an output pin to a bus source
    ;// ecx enters as a bus record pointer
    ;// stack frame has NOT been set yet

        push edi
        push ebp
        push ebx

        mov edi, ecx
        stack_Peek gui_context, ebp

        invoke mouse_reset_all_hovers   ;// have to do this now, the pin is going to change states

        GET_PIN bus_pPin, ebx

        unredo_BeginEndAction UNREDO_BUS_CREATE

        mov ecx, edi
        invoke bus_Create

        pop ebx
        pop ebp
        pop edi

    ;// hide the dialog by setting the focus to main wnindow

        invoke ReleaseCapture
        invoke SetFocus, hMainWnd

        xor eax, eax
        ret 10h

grid_action_create ENDP





ASSUME_AND_ALIGN
grid_action_rename PROC PRIVATE ;// STDCALL hWnd, msg, wParam, lParam

    ;// ecx enters as a bus record pointer
    ;// stack frame has NOT been set yet

    ;// we need to change the bus number for all pins on the bus
    ;// no need for play_wait

    push edi
    push ebp
    push ebx

    mov edi, ecx
    stack_Peek gui_context, ebp

    GET_PIN bus_pPin, ebx       ;// get the pin we're looking at

    unredo_BeginEndAction UNREDO_BUS_RENAME

    mov ecx, edi
    invoke bus_Rename

;// invoke bus_UpdateUndoRedo

;// invoke grid_ShowUnused      ;// show unused
    ;// invoke InvalidateRect, bus_hWnd, 0, 1
    ;// invoke ReleaseCapture
    ;// invoke SetFocus, bus_hWnd

    pop ebx
    pop ebp
    pop edi

;// invoke app_Sync

    ;// hide the dialog by setting the focus to main wnindow

        invoke ReleaseCapture
        invoke SetFocus, hMainWnd



    xor eax, eax
    ret 10h

grid_action_rename ENDP




ASSUME_AND_ALIGN
grid_action_transfer PROC PRIVATE   ;// stdcall hWnd, msg, wParam, lParam

    ;// change an input to another bus

    ;// this would be a pin_connect_CI_CI operation
    ;// but we don't have such a function because for normally connected pins
    ;// it doesn't make since
    ;// so we make two calls to other pin functions

        push edi
        push ebp
        push ebx

        mov edi, ecx
        stack_Peek gui_context, ebp

        invoke mouse_reset_all_hovers   ;// have to do this now, the pin is going to change states

        mov ebx, bus_pPin

        unredo_BeginEndAction UNREDO_BUS_TRANSFER

        mov ecx, edi
        invoke bus_Transfer

        pop ebx
        pop ebp
        pop edi

    ;// hide the dialog by setting the focus to main wnindow

        invoke ReleaseCapture
        invoke SetFocus, hMainWnd

        xor eax, eax
        ret 10h

grid_action_transfer ENDP



ASSUME_AND_ALIGN
grid_action_convert PROC PRIVATE    ;// stdcall hWnd, msg, wParam, lParam

    ;// convert a direct connection to the stated bus (in ecx)

        ASSUME ecx:PTR BUS_EDIT_RECORD

    ;// ecx enters as a bus record pointer
    ;// stack frame has NOT been set yet

        push edi
        push ebp
        push ebx

        mov edi, ecx
        stack_Peek gui_context, ebp

        invoke mouse_reset_all_hovers   ;// have to do this now, the pin is going to change states

        GET_PIN bus_pPin, ebx

        unredo_BeginEndAction UNREDO_BUS_CONVERTTO

        mov ecx, edi
        invoke bus_ConvertTo

    ;// exit this function

        pop ebx
        pop ebp
        pop edi

    ;// hide the dialog by setting the focus to main wnindow

        invoke ReleaseCapture
        invoke SetFocus, hMainWnd

        xor eax, eax
        ret 10h

grid_action_convert ENDP

;//
;//
;//     grid_actions        all are jumped to by wm_lbuttondown
;//                         stack frame has NOT been set yet
;//
;////////////////////////////////////////////////////////////////////





ASSUME_AND_ALIGN


END

