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
;//     ABOX242 AJT -- some op sizes needed for newer masm
;//
;//##////////////////////////////////////////////////////////////////////////
;//
;// ABox_debug.asm      various functions for abox2
;//
;//
;// TOC
;// debug_Initialize
;// debug_WndProc
;// debug_timer_proc
;// wm_close_proc
;// wm_size_proc
;// wm_destroy_proc
;// wm_paint_proc
;// debug_VerifyOsc
;// debug_ShowStructs
;// wm_keydown_proc


OPTION CASEMAP:NONE


.586
.MODEL FLAT
IFDEF DEBUGBUILD

    .NOLIST
    include <Abox.inc>
    include <groups.inc>
    include <gdi_pin.inc>
    .LIST

IFDEF USE_DEBUG_PANEL



;////////////////////////////////////////////////////////////////////
;//
;//
;//     layout parameters
;//

    DEBUG_INIT_WIDTH    equ 512
    DEBUG_INIT_HEIGHT   equ 664
    DEBUG_LINE_HEIGHT   equ 13

    DEBUG_COL_1     equ 8
    DEBUG_COL_2     equ 148+12
    DEBUG_COL_3     equ 256+24

    DEBUG_STRUCT_TOP    equ DEBUG_LINE_HEIGHT * 13  ;// top of the lower display

;//
;//
;//     layout parameters
;//
;////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////
;//
;//
;//     option flags
;//

.DATA


    debug_bShowInvalidRect  dd 0    ;// F5 set true to turn invalid on
    debug_bShowInvalidBlit  dd 0    ;// F6 set true to turn invalid on
    debug_bShowInvalidErase dd 0    ;// F7 set true to turn invalid on
    debug_bShowGDIBmp       dd  0   ;// F8 set true to show gdi surface instead of structs

    debug_Enabled           dd  -1  ;// set to zero to prevent redraw


;//////////////////////////////////////////////////////////////////////////////
;//
;//
;//     D E B U G   hWnd  initialize
;//

.DATA

    debug_hWnd  dd  0
    debug_atom  dd  0
    debug_timer dd  0


    sz_WndTitle     db 'debug',0
    sz_WndClassName db 'debug_window', 0

    ;// no flicker !!
    ALIGN 16
    debug_hDC   dd  0
    debug_hBmp  dd  0
    debug_old_hBmp  dd 0
    debug_fill_rect POINT {}    ;// top left of fill is always 0,0
    debug_bmp_size  POINT {}    ;// bottom right, or size of client (identical)

    ;// tick tock display
    tick_tock   dd  0       ;// uses lowest bit to choose
    sz_tick db  'TICK',0
    sz_tock db  'TOCK',0

.CODE


ASSUME_AND_ALIGN
debug_Initialize PROC STDCALL

        LOCAL rect:RECT
        LOCAL wndClass:WNDCLASSEXA

    ;// set up the wndClass struct

        xor eax, eax
        mov wndClass.cbSize, SIZEOF WNDCLASSEXA
        mov wndClass.style, CS_OWNDC + CS_HREDRAW + CS_VREDRAW
        mov wndClass.lpfnWndProc, OFFSET debug_WndProc
        mov wndClass.cbClsExtra, eax
        mov wndClass.cbWndExtra, eax
        mov esi, hInstance
        mov wndClass.hInstance, esi
        mov  wndClass.hIcon, eax
        mov  wndClass.hIconSm, eax
        mov  wndClass.lpszMenuName, eax
        invoke LoadCursorA, eax, IDC_ARROW
        mov  wndClass.hCursor, eax
        ; invoke GetStockObject, BLACK_BRUSH
        ; mov  wndClass.hbrBackground, eax
        mov  wndClass.hbrBackground, 0

        mov  wndClass.lpszClassName, OFFSET sz_WndClassName

        invoke RegisterClassExA, ADDR wndClass
        and eax, 0FFFFh ;// atoms are words
        mov debug_atom, eax

    ;// determine where to put it

        invoke GetWindowRect, hMainWnd, ADDR rect

    ;// create the window

        invoke CreateWindowExA, WS_EX_APPWINDOW, debug_atom, ADDR sz_WndTitle,
            WS_CLIPCHILDREN + WS_THICKFRAME + WS_MINIMIZEBOX + WS_SYSMENU + WS_VISIBLE,
            rect.right, rect.top,
            DEBUG_INIT_WIDTH, DEBUG_INIT_HEIGHT,
            0, 0, hInstance, 0
        mov debug_hWnd, eax

    ;// start the timer

        invoke SetTimer, debug_hWnd, debug_hWnd, 500, 0
        mov debug_timer, eax

    ;// that should do it

        ret


debug_Initialize ENDP

;//
;//
;//     S T A T U S  hWnd  initialize
;//
;//////////////////////////////////////////////////////////////////////////////





;////////////////////////////////////////////////////////////////////
;//
;//
;//     debug wnd proc
;//
ASSUME_AND_ALIGN
debug_WndProc PROC

    mov eax, WP_MSG

    HANDLE_WM WM_TIMER,     debug_timer_proc
    HANDLE_WM WM_KEYDOWN,   wm_keydown_proc
    HANDLE_WM WM_PAINT,     wm_paint_proc
    HANDLE_WM WM_CLOSE,     wm_close_proc
    HANDLE_WM WM_SIZE,      wm_size_proc
    HANDLE_WM WM_DESTROY,   wm_destroy_proc

    jmp DefWindowProcA

debug_WndProc ENDP
;//
;//
;//     debug wnd proc
;//
;////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
debug_timer_proc PROC PRIVATE

    inc tick_tock

    UPDATE_DEBUG



    ;// verify all the memory blocks

    push ebx
    slist_GetHead memory_Global, ebx
    .WHILE ebx

        invoke memory_VerifyBlock
        DEBUG_IF <eax>  ;// this block is corrupted !!

        slist_GetNext memory_Global, ebx

    .ENDW
    pop ebx

    ;// verify all the shapes

    invoke gdi_VerifyShapes
    invoke dib_VerifyDibs
    invoke font_VerifyFonts

    ;// that's it

    xor eax, eax
    ret 10h

debug_timer_proc ENDP





ASSUME_AND_ALIGN
wm_close_proc PROC PRIVATE

    ;// don't allow this window to close
    xor eax, eax
    ret 10h

wm_close_proc ENDP



;////////////////////////////////////////////////////////////////////
;//
;//
;//     WM_SIZE
;//     fwSizeType = wParam;      // resizing flag
;//     nWidth = LOWORD(lParam);  // width of client area
;//     nHeight = HIWORD(lParam); // height of client area
;//
ASSUME_AND_ALIGN
wm_size_proc PROC PRIVATE ;// STDCALL PRIVATE uses esi edi ebx hWnd:DWORD, msg:DWORD, wParam:DWORD, lParam:DWORD

    .IF ![WP_WPARAM]    ;// ignore if not resized

        .IF debug_hBmp
            ;// delete the old bitmap
            DEBUG_IF <!!debug_hDC>  ;// huh??
            invoke SelectObject, debug_hDC, debug_old_hBmp
            invoke DeleteObject, debug_hBmp
            DEBUG_IF <!!eax>
        .ELSE
            ;// create new dc

            invoke CreateCompatibleDC, 0
            mov debug_hDC, eax

            ;// set up the dc for a pleasing display

            push edi

            mov edi, eax

            invoke SetBkColor, edi, 00000000h   ;// black
            invoke SetTextColor, edi, 0000FF00h ;// green
            invoke SelectObject, edi, hFont_osc

            pop edi

        .ENDIF

        lea ecx, WP_LPARAM      ;// get a pointer to the new size
        push esi
        push edi
        push ebx    ;// enter the function

        mov ebx, ecx

        invoke GetDesktopWindow
        mov esi, eax
        invoke GetDC, esi
        mov edi, eax

        spoint_Get [ebx]
        point_Set debug_bmp_size
        invoke CreateCompatibleBitmap, edi, eax, edx
        mov debug_hBmp, eax

        invoke SelectObject, debug_hDC, eax
        mov debug_old_hBmp, eax

        invoke ReleaseDC, esi, edi

        pop ebx
        pop edi
        pop esi

    .ENDIF

    jmp DefWindowProcA

wm_size_proc ENDP
;//
;//     WM_SIZE
;//
;////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////
;//
;//
;//     WM_DESTROY
;//
ASSUME_AND_ALIGN
wm_destroy_proc PROC PRIVATE

    .IF debug_hDC

        invoke DeleteDC, debug_hDC
        DEBUG_IF <!!eax>
        invoke DeleteObject, debug_hBmp
        DEBUG_IF <!!eax>

    .ENDIF

    .IF debug_timer
        invoke KillTimer, debug_hWnd, debug_hWnd
        mov debug_timer, 0
    .ENDIF

    jmp DefWindowProcA

wm_destroy_proc ENDP
;//
;//     WM_DESTROY
;//
;//
;////////////////////////////////////////////////////////////////////









;////////////////////////////////////////////////////////////////////
;//
;//
;//     WM_PAINT
;//
.DATA

    debug_paint PAINTSTRUCT {}

    ;// strings

    ;// buffer for strings
    ss_buf db 128 dup (0)


    sz_osc_down   db 'osc_down  %8.8X    ',0
    sz_pin_down   db 'pin_down  %8.8X    ',0

    sz_osc_hover  db 'osc_hover  %8.8X   ',0
    sz_pin_hover  db 'pin_hover  %8.8X   ',0

    sz_popup_Object db 'popup_Object %8.8X',0
    sz_popup_Plugin db 'popup_Plugin %8.8X',0

    sz_mouse_now    db 'mouse_now( %i, %i )',0
    sz_mouse_pDest  db 'mouse_pdest %8.8X     ',0

    sz_gdi_erase_rect   db 'erase_rect( {%i,%i}, {%i,%i})',0
    sz_gdi_blit_rect    db 'blit_rect( {%i,%i}, {%i,%i})',0

    sz_filename_stats   db 'filenames unused:%i used:%i',0
    sz_gdi_valid    db 'bErase=%i : bBlit=%i',0

    sz_trace_stats  db  'trace: called=%i numObj=%i recurse=%i clocks(M/4)=%i',0

    szColorIndex db 'MouseColor %2.2X   ',0

    sz_DLG_ABOUT             db    'DLG_ABOUT', 0
    sz_DLG_COLORS            db    'DLG_COLORS', 0
    sz_DLG_FILENAME          db    'DLG_FILENAME', 0
    sz_DLG_CREATE            db    'DLG_CREATE', 0
    sz_DLG_POPUP             db    'DLG_POPUP', 0
    sz_DLG_BUS               db    'DLG_BUS', 0
    sz_DLG_MENU              db    'DLG_MENU', 0
    sz_DLG_LABEL             db    'DLG_LABEL', 0
    sz_DLG_TEST              db    'DLG_TEST', 0

    sz_APP_SYNC_GROUP            db    'APP_SYNC_GROUP', 0
    sz_APP_SYNC_PLAYBUTTON       db    'APP_SYNC_PLAYBUTTON', 0
    sz_APP_SYNC_OPTIONBUTTONS    db    'APP_SYNC_OPTIONBUTTONS', 0
    sz_APP_SYNC_EXTENTS          db    'APP_SYNC_EXTENTS', 0
    sz_APP_SYNC_TITLE            db    'APP_SYNC_TITLE', 0
    sz_APP_SYNC_MOUSE            db    'APP_SYNC_MOUSE', 0
    sz_APP_SYNC_STATUS           db    'APP_SYNC_STATUS', 0
    sz_APP_SYNC_MRU              db    'APP_SYNC_MRU', 0
    sz_APP_SYNC_SAVEBUTTONS      db    'APP_SYNC_SAVEBUTTONS', 0

    sz_APP_MODE_USING_SELRECT    db    'APP_MODE_USING_SELRECT',0
    sz_APP_MODE_MOVING_SCREEN    db    'APP_MODE_MOVING_SCREEN', 0
    sz_APP_MODE_SELECT_OSC       db    'APP_MODE_SELECT_OSC', 0
    sz_APP_MODE_UNSELECT_OSC     db    'APP_MODE_UNSELECT_OSC', 0
    sz_APP_MODE_CONNECTING_PIN   db    'APP_MODE_CONNECTING_PIN', 0
    sz_APP_MODE_MOVING_PIN       db    'APP_MODE_MOVING_PIN', 0
    sz_APP_MODE_MOVING_OSC       db    'APP_MODE_MOVING_OSC', 0
    sz_APP_MODE_MOVING_OSC_SINGLE db   'APP_MODE_MOVING_OSC_SINGLE', 0
    sz_APP_MODE_CONTROLLING_OSC  db    'APP_MODE_CONTROLLING_OSC', 0
    sz_APP_MODE_OSC_HOVER        db    'APP_MODE_OSC_HOVER', 0
    sz_APP_MODE_CON_HOVER        db    'APP_MODE_CON_HOVER', 0
    sz_APP_MODE_IN_GROUP         db    'APP_MODE_IN_GROUP', 0

;// mouse mode flags


    sz_OSC_HAS_MOVED  db 'OSC_HAS_MOVED',0
    sz_SEL_HAS_MOVED  db 'SEL_HAS_MOVED',0
    sz_PIN_HAS_MOVED  db 'PIN_HAS_MOVED',0
    sz_CON_HAS_MOVED  db 'CON_HAS_MOVED',0
    sz_SCR_HAS_MOVED  db 'SCR_HAS_MOVED',0





;// clocking

    render_debug_clocker_t0 dd  0           ;// start time
    render_debug_clocker_t1 dd  0           ;// end time
    sz_render db 'render %i',0  ;// format buffer
    ALIGN 4

    paint_debug_clocker_t0  dd  0           ;// start time
    paint_debug_clocker_t1  dd  0           ;// end time
    sz_paint db 'paint  %i',0   ;// format buffer
    ALIGN 4

    mouse_debug_clocker_t0  dd  0           ;// start time
    mouse_debug_clocker_t1  dd  0           ;// end time
    sz_mouse db 'mouse  %i',0   ;// format buffer
    ALIGN 4

    play_render_debug_clocker_t0    dd  0
    play_render_debug_clocker_t1    dd  0
    sz_play_render  db  'p render %i',0
    ALIGN 4

    play_blit_debug_clocker_t0  dd  0
    play_blit_debug_clocker_t1  dd  0
    sz_play_blit    db  'p blit   %i',0
    ALIGN 4


    ;// this displays a pointer

    S_POINTER MACRO name:req, X:REQ

        invoke wsprintfA, ADDR ss_buf, ADDR sz_&name, name
        invoke TextOutA, edi, X,esi, ADDR ss_buf, eax
        add esi, ebx

        ENDM


    ;// this displays a point

    S_POINT MACRO name:req, X:req

        invoke wsprintfA, ADDR ss_buf, ADDR sz_&name, name&.x, name&.y
        invoke TextOutA, edi, X,esi, ADDR ss_buf, eax
        add esi, ebx

        ENDM


    ;// this displays a rect

    S_RECT MACRO name:req, X:req

        invoke wsprintfA, ADDR ss_buf, ADDR sz_&name, name&.left, name&.top, name&.right, name&.bottom
        invoke TextOutA, edi, X,esi, ADDR ss_buf, eax
        add esi, ebx

        ENDM




    ;// this parses ONE app flag

    S_APP_FLAGS MACRO name:req, X:req

        LOCAL @1

        test app_bFlags, name
        jz @1

            invoke TextOutA, edi, X, esi, ADDR sz_&name, SIZEOF sz_&name-1
            add esi, ebx

        @1:

        ENDM

    ;// this parses ONE dlg flag

    S_DLG_FLAGS MACRO name:req, X:req

        LOCAL @1

        test app_DlgFlags, name
        jz @1

            invoke TextOutA, edi, X, esi, ADDR sz_&name, SIZEOF sz_&name-1
            add esi, ebx

        @1:

        ENDM


    ;// this parses ONE mouse state flag

    S_MOUSE_STATE MACRO name:req, X:req

        LOCAL @1

        test mouse_state, name
        jz @1

            invoke TextOutA, edi, X, esi, ADDR sz_&name, SIZEOF sz_&name-1
            add esi, ebx

        @1:

        ENDM


    ;// this manages the clocker

    S_CLOCKER MACRO name:req, X:req

        mov eax, name&_debug_clocker_t1
        sub eax, name&_debug_clocker_t0
        .IF SIGN?
            neg eax
        .ENDIF
        mov name&_debug_clocker_t0, 0
        mov name&_debug_clocker_t1, 0

        lea edx, sz_&name
        lea ecx, ss_buf
        invoke wsprintfA, ecx, edx, eax
        invoke TextOutA, edi, X,esi,ADDR ss_buf, eax
        add esi, ebx

        ENDM


    EXTERNDEF   gdi_erase_rect:RECT ;// erase rect
    EXTERNDEF   gdi_blit_rect:RECT  ;// blit rect
    EXTERNDEF   gdi_bEraseValid:BYTE
    EXTERNDEF   gdi_bBlitValid:BYTE



    sz_Disabled db '  D I S P L A Y   D I S A B L E D   use F9  ', 0


    ALIGN 4
    debug_prev_play_time dd 0



.CODE


debug_ShowStructs PROTO STDCALL hDC:DWORD













;////////////////////////////////////////////////////////////////////
;//
;//
;//     WM_PAINT
;//
ASSUME_AND_ALIGN
wm_paint_proc PROC PRIVATE

.IF !debug_Enabled

    invoke timeGetTime
    mov edx, eax
    sub eax, debug_prev_play_time
    .IF eax < 500

        invoke BeginPaint, debug_hWnd, ADDR debug_paint
        ;//invoke TextOutA, debug_paint.hDC, 0,0,ADDR sz_Disabled, (SIZEOF sz_Disabled)-1
        invoke EndPaint, debug_hWnd, ADDR debug_paint
        jmp all_done

    .ENDIF

    mov debug_prev_play_time, edx

.ENDIF


    push esi
    push edi
    push ebx

    mov edi, debug_hDC  ;// edi will be the bitmap dc for the entire function

    ;// fill the rect

    invoke GetStockObject, BLACK_BRUSH
    lea edx, debug_fill_rect
    invoke FillRect, edi, edx, eax

    ;// determine the mode we display

    .IF !debug_bShowGDIBmp

        ;// setup the line counter

            mov esi, 0  ;// esi is the Y coord for text
            mov ebx, DEBUG_LINE_HEIGHT

        ;// show the hover and down pointers

                S_POINTER osc_down, DEBUG_COL_1
                S_POINTER pin_down, DEBUG_COL_1

                S_POINTER osc_hover, DEBUG_COL_1
                S_POINTER pin_hover, DEBUG_COL_1

                S_POINTER popup_Object, DEBUG_COL_1

        ;// show the mouse point and rect

        ;//     add esi, ebx    ;// skip a line
        ;//     add esi, ebx    ;// skip a line

                S_POINT mouse_now, DEBUG_COL_1
        ;//     S_RECT mouse_rect, DEBUG_COL_1
                S_POINTER mouse_pDest, DEBUG_COL_1

        ;// determine the color under the mouse

                xor esi, esi    ;// start back at top
                mov edx, mouse_pDest
                .IF edx
                    movzx edx, BYTE PTR [edx]
                .ELSE
                    dec edx
                .ENDIF

                invoke wsprintfA, ADDR ss_buf, ADDR szColorIndex, edx
                invoke TextOutA, edi, DEBUG_COL_2,esi, ADDR ss_buf, eax
                add esi, ebx

        ;// show clocks

            S_CLOCKER render, DEBUG_COL_2
            S_CLOCKER paint, DEBUG_COL_2
            S_CLOCKER mouse, DEBUG_COL_2
            S_CLOCKER play_render, DEBUG_COL_2
            S_CLOCKER play_blit, DEBUG_COL_2

        ;// show tick_tock

            .IF tick_tock & 1
                lea ecx, sz_tock
            .ELSE
                lea ecx, sz_tick
            .ENDIF
            invoke TextOutA, edi, DEBUG_COL_2,esi, ecx, 4

            add esi, ebx

        ;// show the number of filenames in use

            filename_GetDebugStats PROTO    ;// defines in filenames.asm

            invoke filename_GetDebugStats
            ;// ecx num used
            ;// edx num unused

            invoke wsprintfA, ADDR ss_buf, ADDR sz_filename_stats, edx, ecx
            invoke TextOutA, edi, DEBUG_COL_2,esi, ADDR ss_buf, eax

        ;// show the last trace stats

            add esi, ebx

            EXTERNDEF play_trace_1_count:DWORD
            EXTERNDEF play_trace_2_count:DWORD
            EXTERNDEF play_trace_4_count:DWORD
            EXTERNDEF play_trace_clocks:DWORD

            invoke wsprintfA, ADDR ss_buf, ADDR sz_trace_stats, play_trace_1_count,  play_trace_4_count, play_trace_2_count, play_trace_clocks
            invoke TextOutA, edi, DEBUG_COL_1,esi, ADDR ss_buf, eax

            add esi, ebx

        ;// show the gdi erase and blit rects
        ;// and their bValid values

            S_RECT gdi_erase_rect, DEBUG_COL_1
            S_RECT gdi_blit_rect, DEBUG_COL_1

            movzx edx, gdi_bEraseValid
            movzx ecx, gdi_bBlitValid
            invoke wsprintfA, ADDR ss_buf, ADDR sz_gdi_valid, ecx, edx
            invoke TextOutA, edi, DEBUG_COL_1,esi, ADDR ss_buf, eax
            add esi, ebx

        ;// parse the mode flags

            xor esi, esi    ;// start back at top

                S_DLG_FLAGS DLG_ABOUT, DEBUG_COL_3
                S_DLG_FLAGS DLG_COLORS, DEBUG_COL_3
                S_DLG_FLAGS DLG_FILENAME, DEBUG_COL_3
                S_DLG_FLAGS DLG_CREATE, DEBUG_COL_3
                S_DLG_FLAGS DLG_POPUP, DEBUG_COL_3
                S_DLG_FLAGS DLG_BUS, DEBUG_COL_3
                S_DLG_FLAGS DLG_MENU, DEBUG_COL_3
                S_DLG_FLAGS DLG_LABEL, DEBUG_COL_3

                S_APP_FLAGS APP_SYNC_GROUP, DEBUG_COL_3
                S_APP_FLAGS APP_SYNC_PLAYBUTTON, DEBUG_COL_3
                S_APP_FLAGS APP_SYNC_OPTIONBUTTONS, DEBUG_COL_3
                S_APP_FLAGS APP_SYNC_EXTENTS, DEBUG_COL_3
                S_APP_FLAGS APP_SYNC_TITLE, DEBUG_COL_3
                S_APP_FLAGS APP_SYNC_MOUSE, DEBUG_COL_3
                S_APP_FLAGS APP_SYNC_STATUS, DEBUG_COL_3
                S_APP_FLAGS APP_SYNC_MRU, DEBUG_COL_3
                S_APP_FLAGS APP_SYNC_SAVEBUTTONS, DEBUG_COL_3

                S_APP_FLAGS APP_MODE_USING_SELRECT, DEBUG_COL_3
                S_APP_FLAGS APP_MODE_MOVING_SCREEN, DEBUG_COL_3
                S_APP_FLAGS APP_MODE_SELECT_OSC, DEBUG_COL_3
                S_APP_FLAGS APP_MODE_UNSELECT_OSC, DEBUG_COL_3
                S_APP_FLAGS APP_MODE_CONNECTING_PIN, DEBUG_COL_3
                S_APP_FLAGS APP_MODE_MOVING_PIN, DEBUG_COL_3
                S_APP_FLAGS APP_MODE_MOVING_OSC, DEBUG_COL_3
                S_APP_FLAGS APP_MODE_MOVING_OSC_SINGLE, DEBUG_COL_3
                S_APP_FLAGS APP_MODE_CONTROLLING_OSC, DEBUG_COL_3
                S_APP_FLAGS APP_MODE_OSC_HOVER, DEBUG_COL_3
                S_APP_FLAGS APP_MODE_CON_HOVER, DEBUG_COL_3
                S_APP_FLAGS APP_MODE_IN_GROUP, DEBUG_COL_3

                add esi, ebx

                S_MOUSE_STATE OSC_HAS_MOVED, DEBUG_COL_3
                S_MOUSE_STATE SEL_HAS_MOVED, DEBUG_COL_3
                S_MOUSE_STATE PIN_HAS_MOVED, DEBUG_COL_3
                S_MOUSE_STATE CON_HAS_MOVED, DEBUG_COL_3
                S_MOUSE_STATE SCR_HAS_MOVED, DEBUG_COL_3


        ;// show the current osc and pin

            invoke debug_ShowStructs, edi


    .ELSE

        ;// display the gdi bmp

        ;// determine the correct aspect ratio
        ;// x1,y1 are                               gdi_bitmap_size
        ;// x2,y2 are the size need to display at
        ;// client rect is                          debug_bmp_size

        ;// aspect a = x1/y1
        ;// then x2/y2 = a
        ;//
        ;// x2 = a * client.y
        ;// if x2 > client.x
        ;//     y2 = client.x / a
        ;//     x2 = client.x
        ;// else
        ;//     x2 = x2  (a * client.y)
        ;//     y2 = client.y
        ;// endif

            sub esp, SIZEOF STRETCHBLT_STACK
            st_stretch TEXTEQU <(STRETCHBLT_STACK PTR [esp])>

            point_Get debug_bmp_size

            fild gdi_bitmap_size.x  ;// x1
            fidiv gdi_bitmap_size.y ;// a
            fild debug_bmp_size.y   ;// cy  a
            fmul st, st(1)          ;// x2  a
            fistp st_stretch.dest_Width ;// a

            cmp eax, st_stretch.dest_Width
            jae G1

                fidivr debug_bmp_size.x
                mov st_stretch.dest_Width, eax
                fistp st_stretch.dest_Height
                jmp G2

            G1:

                fstp st
                mov st_stretch.dest_Height, edx

            G2:

        ;// finish filling in the struct

            point_Get gdi_bitmap_size
            xor ecx, ecx
            mov ebx, gdi_hDC

            mov st_stretch.dest_hDC, edi

            mov st_stretch.dest_X, ecx
            mov st_stretch.dest_Y, ecx
            ;//mov st_stretch.dest_Width
            ;//mov st_stretch.dest_Height

            mov st_stretch.src_hDC, ebx

            mov st_stretch.src_X, ecx
            mov st_stretch.src_Y, ecx
            mov st_stretch.src_Width, eax
            mov st_stretch.src_Height, edx

            mov st_stretch.dwRop, SRCCOPY

        ;// call StretchBlit

            call StretchBlt         ;// StretchBlt will clean up the stack
            st_stretch TEXTEQU <>

        .ENDIF

;// start the actual paint process, blit the bitmap, end the paint process

    invoke BeginPaint, debug_hWnd, ADDR debug_paint
    invoke BitBlt, eax, 0,0,debug_bmp_size.x, debug_bmp_size.y, edi, 0,0, SRCCOPY
    invoke EndPaint, debug_hWnd, ADDR debug_paint

;// that's it

    pop ebx
    pop edi
    pop esi

;// .ENDIF  ;// disbaled

all_done:

    xor eax, eax
    ret 10h

wm_paint_proc ENDP
;//
;//
;//     WM_PAINT
;//
;////////////////////////////////////////////////////////////////////




comment ~ /*

;// ;// OSC_OBJECT DISPLAYER
;//
;//     keys for navigating lists:
;//
;//         letter is next
;//         shift+letter is prev
;//         ctrl+letter is head of list
;//
;//     Z   Zlist
;//     I   invalidate
;//     S   sel list
;//     L   lock list
;//     C   Calc list
;//     R   playable
;//     G   group
;//
;//         pBase:      POINTER and string, (grab title from base)
;//
;//     lists:
;//         display as: <Z> <I>  S> L>  C>  R>  G>
;//         arrows indicate available keys
;//
;//         pNextZ  pPrevZ      pNextI  pPrevI
;//         pNextS  pNextL  pNextC  pNextR  pNextG
;//
;//     gdi and hintI:
;//
;//         dwHintI:    PARSE HINTI
;//         pDest:      POINTER
;//         pShape:     POINTER possible display
;//         pSource:    POINTER
;//         rect:       RECT
;//
;//     other:  display to double check
;//
;//         dwUser:     VALUE
;//         pData:      POINTER
;//         pad1:       VALUE (should be zero)
;//         dx_count:   VALUE
;//         pDXTable:   POINTER, possible display
;//         depth:      VALUE
;//         wClocks:    VALUE
;//         wPad:       VALUE
;//         temp1:      VALUE
;//
;//     pins:   show the pointer, then another list BELOW
;//         pLastPin dd 0   ;// points at one past end, is also first pin data if needed
;//         (current pin display number)
;//         use brackets to manuver
;//
;//
;//
;// ;// PIN DISPLAYER
;//
;//         pObject:    POINTER auto display ABOVE
;//         pPin:       POINTER     jump key: P
;//
;//
;//         pData:      POINTER, or JUMP KEY B
;//         dwStatus:   PARSE PIN_DEBUG
;//         dwHintI:    PARSE HINTI
;//
;//         dwUser: VALUE
;//
;//         pContainer: POINTER, possible display
;//         pheta:      fVALUE
;//
;//         pShape:     POINTER, possible display
;//         pDest:      POINTER
;//
;//         pFShape:    POINTER, string (grab from font), possible display
;//         pFDest:     POINTER
;//
;//         E:          fPOINT
;//         F:          fPOINT
;//
;//         PF:         POINT
;//         pBDest:     POINTER
;//         pad:VALUE
;//
;//         T0:         POINT
;//         T1:         POINT
;//
;//         UNION
;//             T2 POINT {} ;// output pins, second control point to target (targ T1)   (client coords)
;//             dE POINT {} ;// input pins, delta position between E's (real4)
;//         ENDS            ;// we store these to cache them
;//         UNION
;//             T3 POINT  {};// output pins, last point in the spline (targ T0)         (client coords)
;//             fE fPOINT {};// input pins, calcluated attractive force (real4)
;//         ENDS            ;// we store these to cache them
;//         dT0   POINT {}  ;// cached delta between T0 and osc.rect.TL,
;//         defX0 POINT {}  ;// the default center point, assigned by the oscillator init
;//
;//
;//

*/ comment ~


.DATA

;////////////////////////////////////////////////////////////////////
;//
;//
;//     current display values
;//

    debug_pOsc  dd  0   ;// current osc we're displaying
    debug_pPin  dd  0   ;// current pin we're displaying

;//
;//     current display values
;//
;//
;////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////
;//
;//
;//     parsing lists
;//

    ;// dwHintOsc

    sz_HINTOSC_INVAL_TEST_ONSCREEN      db 'HINTOSC_INVAL_TEST_ONSCREEN',0
    sz_HINTOSC_INVAL_UPDATE_BOUNDRY     db 'HINTOSC_INVAL_UPDATE_BOUNDRY',0
    sz_HINTOSC_INVAL_DO_PINS            db 'HINTOSC_INVAL_DO_PINS',0
    sz_HINTOSC_INVAL_DO_PINS_JUMP       db 'HINTOSC_INVAL_DO_PINS_JUMP',0
    sz_HINTOSC_RENDER_DO_PINS           db 'HINTOSC_RENDER_DO_PINS',0

    sz_HINTOSC_INVAL_ERASE_BOUNDRY      db 'HINTOSC_INVAL_ERASE_BOUNDRY',0
    sz_HINTOSC_INVAL_BLIT_RECT          db 'HINTOSC_INVAL_BLIT_RECT',0
    sz_HINTOSC_INVAL_BLIT_BOUNDRY       db 'HINTOSC_INVAL_BLIT_BOUNDRY',0
    sz_HINTOSC_INVAL_BLIT_CLOCKS        db 'HINTOSC_INVAL_BLIT_CLOCKS',0

    sz_HINTOSC_INVAL_SET_SHAPE          db 'HINTOSC_INVAL_SET_SHAPE',0
    sz_HINTOSC_INVAL_BUILD_RENDER       db 'HINTOSC_INVAL_BUILD_RENDER',0
    sz_HINTOSC_STATE_BOUNDRY_VALID      db 'HINTOSC_STATE_BOUNDRY_VALID',0
    sz_HINTOSC_RENDER_CALL_BASE         db 'HINTOSC_RENDER_CALL_BASE',0
    sz_HINTOSC_RENDER_MASK              db 'HINTOSC_RENDER_MASK',0
    sz_HINTOSC_RENDER_OUT1              db 'HINTOSC_RENDER_OUT1',0
    sz_HINTOSC_STATE_HAS_HOVER          db 'HINTOSC_STATE_HAS_HOVER',0
    sz_HINTOSC_STATE_HAS_CON_HOVER      db 'HINTOSC_STATE_HAS_CON_HOVER',0
    sz_HINTOSC_STATE_HAS_LOCK_HOVER     db 'HINTOSC_STATE_HAS_LOCK_HOVER',0
    sz_HINTOSC_RENDER_OUT2              db 'HINTOSC_RENDER_OUT2',0
    sz_HINTOSC_STATE_HAS_LOCK_SELECT    db 'HINTOSC_STATE_HAS_LOCK_SELECT',0
    sz_HINTOSC_STATE_HAS_SELECT         db 'HINTOSC_STATE_HAS_SELECT',0
    sz_HINTOSC_RENDER_OUT3              db 'HINTOSC_RENDER_OUT3',0
    sz_HINTOSC_STATE_HAS_GROUP          db 'HINTOSC_STATE_HAS_GROUP',0
    sz_HINTOSC_STATE_HAS_BAD            db 'HINTOSC_STATE_HAS_BAD',0
    sz_HINTOSC_RENDER_CLOCKS            db 'HINTOSC_RENDER_CLOCKS',0
    sz_HINTOSC_RENDER_BLIT_RECT         db 'HINTOSC_RENDER_BLIT_RECT',0
    sz_HINTOSC_STATE_SHOW_PINS          db 'HINTOSC_STATE_SHOW_PINS',0

    sz_HINTOSC_INVAL_CREATED            db 'HINTOSC_INVAL_CREATED',0
    sz_HINTOSC_INVAL_REMOVE             db 'HINTOSC_INVAL_REMOVE',0

    sz_HINTOSC_STATE_ONSCREEN           db 'HINTOSC_STATE_ONSCREEN',0
    sz_HINTOSC_STATE_SETS_EXTENTS       db 'HINTOSC_STATE_SETS_EXTENTS',0

    sz_HINTOSC_STATE_PROCESSED          db 'HINTOSC_STATE_PROCESSED',0


    ;// APIN.dwHintPin

    sz_HINTPIN_RENDER_ASSY          db 'HINTPIN_RENDER_ASSY',0
    sz_HINTPIN_RENDER_OUT1          db 'HINTPIN_RENDER_OUT1',0
    sz_HINTPIN_RENDER_OUT1_BUS      db 'HINTPIN_RENDER_OUT1_BUS',0
    sz_HINTPIN_RENDER_CONN          db 'HINTPIN_RENDER_CONN',0
    sz_HINTPIN_STATE_THICK          db 'HINTPIN_STATE_THICK',0
    sz_HINTPIN_STATE_HAS_HOVER      db 'HINTPIN_STATE_HAS_HOVER',0
    sz_HINTPIN_STATE_HAS_DOWN       db 'HINTPIN_STATE_HAS_DOWN',0
    sz_HINTPIN_STATE_HAS_BUS_HOVER  db 'HINTPIN_STATE_HAS_BUS_HOVER',0
    sz_HINTPIN_STATE_HIDE           db 'HINTPIN_STATE_HIDE',0

    sz_HINTPIN_INVAL_LAYOUT         db 'HINTPIN_INVAL_LAYOUT',0
    sz_HINTPIN_STATE_TSHAPE_VALID   db 'HINTPIN_STATE_TSHAPE_VALID',0

    sz_HINTPIN_INVAL_LAYOUT_SHAPE   db 'HINTPIN_INVAL_LAYOUT_SHAPE',0
    sz_HINTPIN_INVAL_LAYOUT_POINTS  db 'HINTPIN_INVAL_LAYOUT_POINTS',0
    sz_HINTPIN_STATE_VALID_TSHAPE   db 'HINTPIN_STATE_VALID_TSHAPE',0
    sz_HINTPIN_STATE_VALID_DEST     db 'HINTPIN_STATE_VALID_DEST',0

    sz_HINTPIN_INVAL_BUILD_JUMP     db 'HINTPIN_INVAL_BUILD_JUMP',0
    sz_HINTPIN_INVAL_BUILD_RENDER   db 'HINTPIN_INVAL_BUILD_RENDER',0

    sz_HINTPIN_INVAL_ERASE_CONN     db 'HINTPIN_INVAL_ERASE_CONN',0
    sz_HINTPIN_INVAL_ERASE_RECT     db 'HINTPIN_INVAL_ERASE_RECT',0
    sz_HINTPIN_INVAL_BLIT_RECT      db 'HINTPIN_INVAL_BLIT_RECT',0
    sz_HINTPIN_INVAL_BLIT_CONN      db 'HINTPIN_INVAL_BLIT_CONN',0

    sz_HINTPIN_STATE_ONSCREEN       db 'HINTPIN_STATE_ON_SCREEN',0

    ;// APIN.dwHintI    ??





    ;// APIN.dwStatus

    sz_PIN_BUS_TEST          db 'PIN_BUS_TEST',0
    sz_PIN_OUTPUT            db 'PIN_OUTPUT',0
    sz_PIN_HIDDEN            db 'PIN_HIDDEN',0
    sz_PIN_NULL              db 'PIN_NULL',0

    sz_PIN_LOGIC_INPUT       db 'PIN_LOGIC_INPUT',0
    sz_PIN_LOGIC_GATE        db 'PIN_LOGIC_GATE',0
    sz_PIN_LEVEL_POS         db 'PIN_LEVEL_POS',0
    sz_PIN_LEVEL_NEG         db 'PIN_LEVEL_NEG',0

    sz_UNIT_AUTO_UNIT       db 'UNIT_AUTO_UNIT',0
    sz_UNIT_AUTOED          db 'UNIT_AUTOED',0

    sz_PIN_CHANGING          db 'PIN_CHANGING',0
    sz_PIN_PREV_CHANGING     db 'PIN_PREV_CHANGING',0



    ;// this parses ONE app flag

    S_EDI_FLAGS MACRO name:req

        ;// edi must be the flag to test
        ;// X and Y must be correct

        LOCAL @1

        test edi, name
        jz @1

            invoke TextOutA, hDC, X, Y, ADDR sz_&name, SIZEOF sz_&name-1
            add Y, DEBUG_LINE_HEIGHT

        @1:

        ENDM









.DATA


ALIGN 8
float_scale REAL4   1.0E+0
            REAL4   1.0E+1
            REAL4   1.0E+2
            REAL4   1.0E+3
            REAL4   1.0E+4
            REAL4   1.0E+5
one_million REAL4   1.0E+6

almost_half DWORD 3EfffffCh


comment ~ /*

    redoing this proved to be very difficult ...


    number      mult    dword         chars
    as          by                     to   decimal
    displayed            5 4 3 2 1 0  scan  before
    -------     ----    --------------  ----  ------
    100000.     1e+0     1 0 0 0 0 0    6     -1
    10000.0     1e+1     1 0 0 0 0.0    6     0
    1000.00     1e+2     1 0 0 0.0 0    6     1
    100.000     1e+3     1 0 0.0 0 0    6     2
    10.0000     1e+4     1 0.0 0 0 0    6     3
    1.00000     1e+5     1.0 0 0 0 0    6     4

    .100000     1e+6    .1 0 0 0 0 0    6     5
    .010000     1e+6    .0 1 0 0 0 0    6     5
    .001000     1e+6    .0 0 1 0 0 0    6     5

    -0
     0

    -.00100     1e+6    .0 0 1 0 0 0    5     5
    -.01000     1e+6    .0 1 0 0 0 0    5     5
    -.10000     1e+6    .1 0 0 0 0 0    5     5

    -1.0000     1e+5     1.0 0 0 0 0    5     4
    -10.000     1e+4     1 0.0 0 0 0    5     3
    -100.00     1e+3     1 0 0.0 0 0    5     2
    -1000.0     1e+2     1 0 0 0.0 0    5     1
    -10000.     1e+1     1 0 0 0 0.0    5     0

    SO: we keep track of:

    ah  the position
    cl  where the decimal goes
    ch  the characters to scan
    edx index the stack

*/ comment ~



.CODE

ASSUME_AND_ALIGN
FormatFloat7 PROC

    ;// check for zero

        ftst
        lea edx, one_million
        xor eax, eax
        fnstsw ax
        xor ecx, ecx
        sahf
        jz got_zero

    ;// check for negative

        mov ch, 7
        .IF CARRY?      ;// value is negative

            sub edx, 4
            mov al, '-'
            fabs
            dec ch
            stosb

        .ENDIF

    ;// check for too big

        fld DWORD PTR [edx]
        fucomp
        fnstsw ax
        sahf
        jb too_big

    ;// determine where the decimal goes

        sub esp, 12
        xor eax, eax

        fld st
        fsub almost_half
        mov ah, 6
        fbstp TBYTE PTR [esp]   ;// ABOX242 AJT -- need to specify op size
        mov edx, [esp]
        bsr edx, edx
        .IF ZERO?
            or edx, -1
        .ENDIF
        add edx, 4
        shr edx, 2
        sub edx, 6
        jns too_big_pop
        neg edx

    ;// scale the value to our range

        fmul float_scale[edx*4]

        mov cl, dl

        xor edx, edx

        fbstp TBYTE PTR [esp]     ;// ABOX242 AJT -- need to specify op size

        mov edx, 2

    ;// here's the state
    ;//
    ;//     ch has the number of characters to print
    ;//     we exit when ch hits zero
    ;//
    ;//     ah tracks the position we're looking at, this is a nibble index
    ;//     cl has the nibble index that we put the decimal BEFORE
    ;//

    top_of_loop:

        .IF ah == cl        ;// are we at the decimal ?

            mov al, '.'     ;// load the decimal
            dec ch          ;// decrease the char count
            stosb           ;// store the decimal
            jz all_done     ;// exit if last characer

        .ENDIF
        dec ah              ;// decrease the position

        mov al, [esp+edx]   ;// get the char from the stack
        shr al, 4           ;// we're on high nibble
        add al, '0'         ;// make ascii
        stosb               ;// store teh character
        dec ch              ;// decrease the char count
        jz all_done

        .IF ah == cl        ;// are we at the decimal ?

            mov al, '.'     ;// load the decimal
            dec ch          ;// decrease the char count
            stosb           ;// store the decimal
            jz all_done     ;// exit if last characer

        .ENDIF
        dec ah              ;// decrease the position

        mov al, [esp+edx]   ;// get the byte from the stack
        and al, 0Fh         ;// we're at low nibble
        add al, '0'         ;// make ascii
        dec ch              ;// decrease char count
        stosb               ;// store the charcter
        jz all_done         ;// exit if done

        dec edx             ;// decrease the stack pointer
        jns top_of_loop

    all_done:

        add esp, 12

    all_done_now:

        ret


    got_zero:

        push eax
        fstp DWORD PTR [esp]
        pop edx
        xor eax, eax
        or edx, edx
        .IF SIGN?
            mov ax, '0-'
            stosw
            jmp all_done_now
        .ENDIF

        mov al, '0'
        stosb
        jmp all_done_now

    too_big_pop:

        add esp, 12

    too_big:

        movzx ecx, ch
        mov al, '#'
        fstp st
        rep stosb
        jmp all_done_now


        ret


FormatFloat7 ENDP




    FORMAT7 MACRO buf:req
    ;// wrapper for call to unit format float 7

        push edi
        lea edi, buf
        call FormatFloat7
        pop edi
        ENDM












;//
;//
;//     parsing lists
;//
;////////////////////////////////////////////////////////////////////


.DATA

;// more format strings

    ;// osc

    sz_osc_base     db  'OSC %8.8X %s',0    ;// shows pointer and name
    sz_osc_hintI    db  'dwHintI %8.8X ', 0
    sz_osc_hintosc  db  'dwHintOsc %8.8X --->', 0
    sz_osc_rect     db  'rect{%i,%i},{%i,%i}',0
    sz_osc_boundry  db  'boun{%i,%i},{%i,%i}',0
    sz_osc_gdi_container db 'pContainer:%8.8X',0
    sz_osc_gdi_source   db  'pSource:%8.8X',0
    sz_osc_gdi_dest     db  'pDest:%8.8X',0

    sz_osc_user     db  'dwUser: %8.8X',0
    sz_osc_data     db  'pData: %8.8X',0
    sz_osc_depth    db  'depth: %i',0
    sz_osc_id       db  'id: %i',0

    ;// pin

    sz_pin_name         db '[]PIN:%8.8X  #%i  %s', 0
    sz_pin_no_fshape    db 'no_f_shape',0
    sz_pin_status       db 'dwStatus:%8.8X ---->',0
    sz_pin_pin          db  'pPin:%8.8X',0
    sz_pin_data         db  'pData:%8.8X',0
    sz_pin_user         db  'dwUser:%8.8X',0

    sz_pin_jump_index   db  'jump: %1.1x',0

    sz_pin_dest         db  'pDest:%8.8X',0

    sz_pin_tshape       db  'pTShape:%8.8X',0
    sz_pin_fshape       db  'pFShape:%8.8X',0
    sz_pin_lshape       db  'pLShape:%8.8X',0
    sz_pin_bshape       db  'pBShape:%8.8X',0

    sz_pin_color        db  'color:%8.8X',0

    sz_pin_hinti    db 'dwHintI:%8.8X',0

    sz_pin_hintpin  db 'dwHintPin:%8.8X --->',0

    sz_pin_pheta        db 'pheta:%s',0
    sz_pin_def_pheta    db 'def_pheta:%s',0
    sz_pin_e        db 'E:{%s,%s}',0

    sz_pin_t0       db 't0:{%i,%i}',0
    sz_pin_t1       db 't1:{%i,%i}',0
    sz_pin_t2       db 't2:{%i,%i}',0


.CODE

ASSUME_AND_ALIGN
debug_VerifyOsc PROC

    ;// this returns with the carry flag set if the osc in esi is NOT in the current Z list

    stack_Peek gui_context, ecx
    dlist_GetHead oscZ, ecx, [ecx]
    .WHILE ecx && ecx != esi

        dlist_GetNext oscZ, ecx

    .ENDW

    sub ecx, 1  ;// if ecx is zero this will set the carry flag
    inc ecx     ;// restore ecx to the correct address

    ret

debug_VerifyOsc ENDP




ASSUME_AND_ALIGN
debug_ShowStructs PROC STDCALL uses esi edi ebx, hDC:DWORD

    ;// this shows the currectly selected structs
    ;// see formatting template for more details

    LOCAL X:DWORD
    LOCAL Y:DWORD
    LOCAL buf[128]:BYTE
    LOCAL buf2[16]:BYTE
    LOCAL buf3[16]:BYTE

    mov X, DEBUG_COL_1
    mov Y, DEBUG_STRUCT_TOP

    GET_OSC_FROM esi, debug_pOsc
    invoke debug_VerifyOsc  ;// always make sure debug_pOsc is in the Z list
    .IF CARRY?
        stack_Peek gui_context, ecx
        dlist_GetHead oscZ, esi, [ecx]
        mov ecx, esi
    .ENDIF
    mov debug_pOsc, ecx     ;// set it to what ever the function returns

    or ecx, ecx ;// make sure we fond something
    .IF !ZERO?

;//     pBase:      POINTER and string, (grab title from base)

        ;// GET_OSC_FROM esi, debug_pOsc
        OSC_TO_BASE esi, edi
        mov edi, [edi].data.pPopupHeader
        mov edi, (POPUP_HEADER PTR [edi]).pName

        invoke wsprintfA, ADDR buf, ADDR sz_osc_base, esi, edi
        invoke TextOutA, hDC, X, Y, ADDR buf, eax
        add Y, DEBUG_LINE_HEIGHT

;// lists:  display as: <Z> <I>  S> L>  C>  R>  G>

        lea edi, buf    ;// edi will build the buffer

    ;// oscZ

        .IF dlist_Prev(oscZ,esi)    ;//[esi].pPrevZ
            mov eax, '<'
            stosb
        .ENDIF
        mov eax, 'Z'
        stosb
        .IF dlist_Next(oscZ,esi);//[esi].pNextZ
            mov eax, '>'
            stosb
        .ENDIF
        mov eax, '    '
        stosd

    ;// oscI

        .IF dlist_Prev(oscI,esi);//[esi].pPrevI
            mov eax, '<'
            stosb
        .ENDIF
        mov eax, 'I'
        stosb
        .IF dlist_Next(oscI,esi);//[esi].pNextI
            mov eax, '>'
            stosb
        .ENDIF
        mov eax, '    '
        stosd

    ;// oscS

        mov eax, 'S'
        stosb
        .IF clist_Next(oscS,esi);//[esi].pNextS
            mov eax, '>'
            stosb
        .ENDIF
        mov eax, '    '
        stosd

    ;// oscL

        mov eax, 'L'
        stosb
        .IF clist_Next(oscL,esi);//[esi].pNextL
            mov eax, '>'
            stosb
        .ENDIF
        mov eax, '    '
        stosd

    ;// oscC

        mov eax, 'C'
        stosb
        .IF slist_Next(oscC,esi);//[esi].pNextC
            mov eax, '>'
            stosb
        .ENDIF
        mov eax, '    '
        stosd

    ;// oscR

        mov eax, 'R'
        stosb
        .IF slist_Next(oscR,esi);//[esi].pNextR
            mov eax, '>'
            stosb
        .ENDIF
        mov eax, '    '
        stosd

    ;// oscG

        mov eax, 'G'
        stosb
        .IF slist_Next(oscG,esi);//[esi].pNextG
            mov eax, '>'
            stosb
        .ENDIF
        mov eax, '    '
        stosd

        xor eax, eax
        stosd

        lea ecx, buf
        sub edi, ecx
        sub edi, 4

        invoke TextOutA, hDC, X, Y, ADDR buf, edi
        add Y, DEBUG_LINE_HEIGHT

;//         dwHintI:    VALUE:

        invoke wsprintfA, ADDR buf, ADDR sz_osc_hintI, [esi].dwHintI
        invoke TextOutA, hDC, X, Y, ADDR buf, eax
        add Y, DEBUG_LINE_HEIGHT

;//         dwHintOsc:  VALUE:  PARSE HINTOSC to the right

        invoke wsprintfA, ADDR buf, ADDR sz_osc_hintosc, [esi].dwHintOsc
        invoke TextOutA, hDC, X, Y, ADDR buf, eax

        push X
        push Y

            mov X, DEBUG_COL_2
            mov edi, [esi].dwHintOsc

            S_EDI_FLAGS HINTOSC_INVAL_TEST_ONSCREEN
            S_EDI_FLAGS HINTOSC_INVAL_UPDATE_BOUNDRY
            S_EDI_FLAGS HINTOSC_INVAL_DO_PINS
            S_EDI_FLAGS HINTOSC_INVAL_DO_PINS_JUMP
            S_EDI_FLAGS HINTOSC_RENDER_DO_PINS

            S_EDI_FLAGS HINTOSC_INVAL_ERASE_BOUNDRY
            S_EDI_FLAGS HINTOSC_INVAL_BLIT_RECT
            S_EDI_FLAGS HINTOSC_INVAL_BLIT_BOUNDRY
            S_EDI_FLAGS HINTOSC_INVAL_BLIT_CLOCKS
            S_EDI_FLAGS HINTOSC_INVAL_SET_SHAPE
            S_EDI_FLAGS HINTOSC_INVAL_BUILD_RENDER
            S_EDI_FLAGS HINTOSC_STATE_BOUNDRY_VALID
            S_EDI_FLAGS HINTOSC_RENDER_CALL_BASE
            S_EDI_FLAGS HINTOSC_RENDER_MASK
            S_EDI_FLAGS HINTOSC_RENDER_OUT1
            S_EDI_FLAGS HINTOSC_STATE_HAS_HOVER
            S_EDI_FLAGS HINTOSC_STATE_HAS_CON_HOVER
            S_EDI_FLAGS HINTOSC_STATE_HAS_LOCK_HOVER
            S_EDI_FLAGS HINTOSC_RENDER_OUT2
            S_EDI_FLAGS HINTOSC_STATE_HAS_LOCK_SELECT
            S_EDI_FLAGS HINTOSC_STATE_HAS_SELECT
            S_EDI_FLAGS HINTOSC_RENDER_OUT3
            S_EDI_FLAGS HINTOSC_STATE_HAS_GROUP
            S_EDI_FLAGS HINTOSC_STATE_HAS_BAD
            S_EDI_FLAGS HINTOSC_RENDER_CLOCKS
            S_EDI_FLAGS HINTOSC_RENDER_BLIT_RECT
            S_EDI_FLAGS HINTOSC_STATE_SHOW_PINS

            S_EDI_FLAGS HINTOSC_INVAL_CREATED
            S_EDI_FLAGS HINTOSC_INVAL_REMOVE

            S_EDI_FLAGS HINTOSC_STATE_ONSCREEN
            S_EDI_FLAGS HINTOSC_STATE_SETS_EXTENTS

            S_EDI_FLAGS HINTOSC_STATE_PROCESSED


        pop Y
        pop X

        add Y, DEBUG_LINE_HEIGHT

;//         rect:       RECT

        invoke wsprintfA, ADDR buf, ADDR sz_osc_rect, [esi].rect.left, [esi].rect.top, [esi].rect.right, [esi].rect.bottom
        invoke TextOutA, hDC, X, Y, ADDR buf, eax
        add Y, DEBUG_LINE_HEIGHT

;//         boundry:        RECT

        invoke wsprintfA, ADDR buf, ADDR sz_osc_boundry, [esi].boundry.left, [esi].boundry.top, [esi].boundry.right, [esi].boundry.bottom
        invoke TextOutA, hDC, X, Y, ADDR buf, eax
        add Y, DEBUG_LINE_HEIGHT

;//         pShape:     POINTER possible display
;//         pDest:      POINTER
;//         pSource:    POINTER

        invoke wsprintfA, ADDR buf, ADDR sz_osc_gdi_container, [esi].pContainer
        invoke TextOutA, hDC, X, Y, ADDR buf, eax
        add Y, DEBUG_LINE_HEIGHT

        invoke wsprintfA, ADDR buf, ADDR sz_osc_gdi_source, [esi].pSource
        invoke TextOutA, hDC, X, Y, ADDR buf, eax
        add Y, DEBUG_LINE_HEIGHT

        invoke wsprintfA, ADDR buf, ADDR sz_osc_gdi_dest, [esi].pDest
        invoke TextOutA, hDC, X, Y, ADDR buf, eax
        add Y, DEBUG_LINE_HEIGHT

;//         dwUser:     VALUE

        invoke wsprintfA, ADDR buf, ADDR sz_osc_user, [esi].dwUser
        invoke TextOutA, hDC, X, Y, ADDR buf, eax
        add Y, DEBUG_LINE_HEIGHT

;//         pData:      POINTER

        invoke wsprintfA, ADDR buf, ADDR sz_osc_data, [esi].pData
        invoke TextOutA, hDC, X, Y, ADDR buf, eax
        add Y, DEBUG_LINE_HEIGHT

;//         depth:      INT VALUE

        invoke wsprintfA, ADDR buf, ADDR sz_osc_depth, [esi].depth
        invoke TextOutA, hDC, X, Y, ADDR buf, eax
        add Y, DEBUG_LINE_HEIGHT


;//         id:         INT VALUE

        invoke wsprintfA, ADDR buf, ADDR sz_osc_id, [esi].id
        invoke TextOutA, hDC, X, Y, ADDR buf, eax
        add Y, DEBUG_LINE_HEIGHT


;//         pad1:       VALUE (should be zero)
;//         depth:      VALUE
;//         wClocks:    VALUE
;//         wPad:       VALUE
;//         temp1:      VALUE
;//
;//     pins:   show the pointer, then another list BELOW
;//         pLastPin dd 0   ;// points at one past end, is also first pin data if needed
;//         (current pin display number)


    ;// if the object has no pins, then we can't display can we


OSC_TO_BASE esi, eax

.IF [eax].data.numPins          ;// make sure object has pins

    ;// walk the pins until we hit this

        mov ecx, debug_pPin
        ITERATE_PINS
            cmp ecx, ebx
            je found_the_pin
        PINS_ITERATE

        ;// this pin is NOT on the osc, grab the first pin
        OSC_TO_PIN_INDEX esi, ebx, 0
        mov debug_pPin, ebx

    found_the_pin:

        add Y, DEBUG_LINE_HEIGHT

        ;// PIN:ptr number name
;//         pObject:    POINTER auto display ABOVE

        mov ecx, ebx
        sub ecx, esi
        sub ecx, SIZEOF OSC_OBJECT
        shr ecx, APIN_SHIFT

        mov edx, [ebx].pFShape
        .IF edx
            lea edx, (GDI_SHAPE PTR [edx]).character
        .ELSE
            lea edx, sz_pin_no_fshape
        .ENDIF

        invoke wsprintfA, ADDR buf, ADDR sz_pin_name, ebx, ecx, edx
        invoke TextOutA, hDC, X, Y, ADDR buf, eax
        add Y, DEBUG_LINE_HEIGHT

;//         dwStatus:   PARSE PIN_DEBUG

        invoke wsprintfA, ADDR buf, ADDR sz_pin_status, [ebx].dwStatus
        invoke TextOutA, hDC, X, Y, ADDR buf, eax

        push X
        push Y

            mov X, DEBUG_COL_2
            mov edi, [ebx].dwStatus

            S_EDI_FLAGS PIN_BUS_TEST
            S_EDI_FLAGS PIN_OUTPUT
            S_EDI_FLAGS PIN_HIDDEN
            S_EDI_FLAGS PIN_NULL
            S_EDI_FLAGS PIN_LOGIC_INPUT
            S_EDI_FLAGS PIN_LOGIC_GATE
            S_EDI_FLAGS PIN_LEVEL_POS
            S_EDI_FLAGS PIN_LEVEL_NEG

    ;// take care of the units

            S_EDI_FLAGS UNIT_AUTO_UNIT
            S_EDI_FLAGS UNIT_AUTOED

            mov eax, edi
            and eax, UNIT_TEST
            BITSHIFT eax, UNIT_INTERVAL, 4
            add eax, OFFSET unit_label

            invoke TextOutA, hDC, X, Y, eax, 4
            add Y, DEBUG_LINE_HEIGHT


            ;// continue on

            S_EDI_FLAGS PIN_CHANGING
            S_EDI_FLAGS PIN_PREV_CHANGING

        pop Y
        pop X

        add Y, DEBUG_LINE_HEIGHT

;//         pPin:       POINTER     jump key: P
;//         pData:      POINTER, or JUMP KEY B, display ??

        invoke wsprintfA, ADDR buf, ADDR sz_pin_pin, [ebx].pPin
        invoke TextOutA, hDC, X, Y, ADDR buf, eax
        add Y, DEBUG_LINE_HEIGHT

        invoke wsprintfA, ADDR buf, ADDR sz_pin_data, [ebx].pData
        invoke TextOutA, hDC, X, Y, ADDR buf, eax
        add Y, DEBUG_LINE_HEIGHT

;//         dwUser: VALUE

        invoke wsprintfA, ADDR buf, ADDR sz_pin_user, [ebx].dwUser
        invoke TextOutA, hDC, X, Y, ADDR buf, eax
        add Y, DEBUG_LINE_HEIGHT



;// sz_pin_jump_index   db  'jump: %1.1x',0

;// sz_pin_dest         db  'pDest:%8.8X',0

;// sz_pin_shape        db  'pShape:%8.8X',0
;// sz_pin_fshape       db  'pFShape:%8.8X',0
;// sz_pin_lshape       db  'pLShape:%8.8X',0
;// sz_pin_bshape       db  'pBShape:%8.8X',0


        mov edx, [ebx].j_index
        invoke wsprintfA, ADDR buf, ADDR sz_pin_jump_index, edx
        invoke TextOutA, hDC, X, Y, ADDR buf, eax
        add Y, DEBUG_LINE_HEIGHT

        invoke wsprintfA, ADDR buf, ADDR sz_pin_dest, [ebx].pDest
        invoke TextOutA, hDC, X, Y, ADDR buf, eax
        add Y, DEBUG_LINE_HEIGHT

        invoke wsprintfA, ADDR buf, ADDR sz_pin_tshape, [ebx].pTShape
        invoke TextOutA, hDC, X, Y, ADDR buf, eax
        add Y, DEBUG_LINE_HEIGHT

        invoke wsprintfA, ADDR buf, ADDR sz_pin_fshape, [ebx].pFShape
        invoke TextOutA, hDC, X, Y, ADDR buf, eax
        add Y, DEBUG_LINE_HEIGHT

        invoke wsprintfA, ADDR buf, ADDR sz_pin_lshape, [ebx].pLShape
        invoke TextOutA, hDC, X, Y, ADDR buf, eax
        add Y, DEBUG_LINE_HEIGHT

        invoke wsprintfA, ADDR buf, ADDR sz_pin_bshape, [ebx].pBShape
        invoke TextOutA, hDC, X, Y, ADDR buf, eax
        add Y, DEBUG_LINE_HEIGHT


;// color

        invoke wsprintfA, ADDR buf, ADDR sz_pin_color, [ebx].color
        invoke TextOutA, hDC, X, Y, ADDR buf, eax
        add Y, DEBUG_LINE_HEIGHT



;//         dwHintI

        invoke wsprintfA, ADDR buf, ADDR sz_pin_hinti, [ebx].dwHintI
        invoke TextOutA, hDC, X, Y, ADDR buf, eax
        add Y, DEBUG_LINE_HEIGHT


;//         dwHintPin:  PARSE HINTI

        invoke wsprintfA, ADDR buf, ADDR sz_pin_hintpin, [ebx].dwHintPin
        invoke TextOutA, hDC, X, Y, ADDR buf, eax

        push X
        push Y

            mov X, DEBUG_COL_2
            mov edi, [ebx].dwHintPin

            S_EDI_FLAGS HINTPIN_RENDER_ASSY
            S_EDI_FLAGS HINTPIN_RENDER_OUT1
            S_EDI_FLAGS HINTPIN_RENDER_OUT1_BUS
            S_EDI_FLAGS HINTPIN_RENDER_CONN
            S_EDI_FLAGS HINTPIN_STATE_THICK
            S_EDI_FLAGS HINTPIN_STATE_HAS_HOVER
            S_EDI_FLAGS HINTPIN_STATE_HAS_DOWN
            S_EDI_FLAGS HINTPIN_STATE_HAS_BUS_HOVER
            S_EDI_FLAGS HINTPIN_STATE_HIDE

            S_EDI_FLAGS HINTPIN_INVAL_LAYOUT_SHAPE
            S_EDI_FLAGS HINTPIN_INVAL_LAYOUT_POINTS
            S_EDI_FLAGS HINTPIN_STATE_VALID_TSHAPE
            S_EDI_FLAGS HINTPIN_STATE_VALID_DEST

            S_EDI_FLAGS HINTPIN_INVAL_BUILD_JUMP
            S_EDI_FLAGS HINTPIN_INVAL_BUILD_RENDER

            S_EDI_FLAGS HINTPIN_INVAL_ERASE_CONN
            S_EDI_FLAGS HINTPIN_INVAL_ERASE_RECT
            S_EDI_FLAGS HINTPIN_INVAL_BLIT_RECT
            S_EDI_FLAGS HINTPIN_INVAL_BLIT_CONN

            S_EDI_FLAGS HINTPIN_STATE_ONSCREEN



        pop Y
        pop X

        add Y, DEBUG_LINE_HEIGHT

;//         pheta:      fVALUE

        fld [ebx].pheta
        mov DWORD PTR buf2[6], 0
        FORMAT7 buf2
        invoke wsprintfA, ADDR buf, ADDR sz_pin_pheta, ADDR buf2
        invoke TextOutA, hDC, X, Y, ADDR buf, eax
        add Y, DEBUG_LINE_HEIGHT

;//         def pheta:      fVALUE

        fld [ebx].def_pheta
        mov DWORD PTR buf2[6], 0
        FORMAT7 buf2
        invoke wsprintfA, ADDR buf, ADDR sz_pin_def_pheta, ADDR buf2
        invoke TextOutA, hDC, X, Y, ADDR buf, eax
        add Y, DEBUG_LINE_HEIGHT


;//         E:          fPOINT

        fld [ebx].E.x
        mov DWORD PTR buf2[6], 0
        FORMAT7 buf2

        fld [ebx].E.y
        mov DWORD PTR buf3[6], 0
        FORMAT7 buf3

        invoke wsprintfA, ADDR buf, ADDR sz_pin_e, ADDR buf2, ADDR buf3
        invoke TextOutA, hDC, X, Y, ADDR buf, eax
        add Y, DEBUG_LINE_HEIGHT

;//         T0:         POINT

        invoke wsprintfA, ADDR buf, ADDR sz_pin_t0, [ebx].t0.x, [ebx].t0.y
        invoke TextOutA, hDC, X, Y, ADDR buf, eax
        add Y, DEBUG_LINE_HEIGHT

;//         T1:         POINT

        invoke wsprintfA, ADDR buf, ADDR sz_pin_t1, [ebx].t1.x, [ebx].t1.y
        invoke TextOutA, hDC, X, Y, ADDR buf, eax
        add Y, DEBUG_LINE_HEIGHT

;//         PF:         POINT

        invoke wsprintfA, ADDR buf, ADDR sz_pin_t2, [ebx].t2.x, [ebx].t2.y
        invoke TextOutA, hDC, X, Y, ADDR buf, eax
        add Y, DEBUG_LINE_HEIGHT


;//         F:          fPOINT

;//         pBDest:     POINTER
;//         pad:VALUE

;//         UNION
;//             T2 POINT {} ;// output pins, second control point to target (targ T1)   (client coords)
;//             dE POINT {} ;// input pins, delta position between E's (real4)
;//         ENDS            ;// we store these to cache them
;//         UNION
;//             T3 POINT  {};// output pins, last point in the spline (targ T0)         (client coords)
;//             fE fPOINT {};// input pins, calcluated attractive force (real4)
;//         ENDS            ;// we store these to cache them
;//         dT0   POINT {}  ;// cached delta between T0 and osc.rect.TL,
;//         defX0 POINT {}  ;// the default center point, assigned by the oscillator init




;//.ENDIF   ;// pPin

;//.ELSE    ;// no pins

;// mov debug_pPin, 0

.ENDIF  ;// no pins

.ENDIF  ;// pOsc


    ret

debug_ShowStructs ENDP





;////////////////////////////////////////////////////////////////////
;//
;//     WM_KEYDOWN
;//     nVirtKey = (int) wParam;    // virtual-key code
;//     lKeyData = lParam;          // key data
;//
.DATA

    debug_rect  RECT {}

.CODE

ASSUME_AND_ALIGN
wm_keydown_proc PROC PRIVATE


    mov eax, WP_WPARAM  ;// get the key

    .IF eax==VK_F2

        show_containers PROTO STDCALL   ;// defined in ABox_pins.asm
        invoke show_containers

    .ELSEIF eax==VK_F3

        show_intersectors PROTO STDCALL
        invoke show_intersectors        ;// defined in ABox_shapes.asm

    .ELSEIF eax==VK_F5

        not debug_bShowInvalidRect

    .ELSEIF eax==VK_F6

        not debug_bShowInvalidBlit

    .ELSEIF eax==VK_F7

        not debug_bShowInvalidErase

    .ELSEIF eax==VK_F8

        not debug_bShowGDIBmp

    .ELSEIF eax==VK_F9

        not debug_Enabled

    .ELSEIF debug_pOsc

        invoke GetAsyncKeyState, VK_SHIFT
        mov edx, WP_WPARAM      ;// these are always upper case
                                ;// use GetAsyncKeyState to read the shift and control
        push esi
        push edi
        push ebx

        GET_OSC_FROM esi, debug_pOsc

        .IF edx == ' '

            ;// show the osc

            invoke GetDC, hMainWnd
            mov edi, eax
            rect_CopyTo [esi].rect, debug_rect
            sub debug_rect.left, GDI_GUTTER_X
            sub debug_rect.top, GDI_GUTTER_Y
            sub debug_rect.right, GDI_GUTTER_X
            sub debug_rect.bottom, GDI_GUTTER_Y

            invoke InvertRect, edi, ADDR debug_rect

            invoke ReleaseDC, hMainWnd, edi

        .ELSEIF edx == 'Z'  ;// walk Z list

            .IF eax & 8000h
                dlist_GetPrev oscZ, esi
            .ELSE
                dlist_GetNext oscZ, esi
            .ENDIF

        .ELSEIF edx == 'I'  ;// walk I list

            .IF eax & 8000h
                dlist_GetPrev oscI, esi
            .ELSE
                dlist_GetNext oscI, esi
            .ENDIF

        .ELSEIF edx == 'C'  ;// walk C list

            .IF eax & 8000h
                stack_Peek gui_context, ecx
                slist_GetHead oscC, esi, [ecx]
            .ELSE
                slist_GetNext oscC, esi
            .ENDIF

        .ELSEIF edx == 'S'  ;// walk S list

            clist_GetNext oscS, esi

        .ELSEIF edx == 'L'  ;// walk L list

            clist_GetNext oscL, esi

        .ELSEIF edx == 'R'  ;// walk R list

            .IF eax & 8000h
                stack_Peek gui_context, ecx
                slist_GetHead oscR, esi, [ecx]
            .ELSE
                slist_GetNext oscR, esi
            .ENDIF

        .ELSEIF edx == 'H'  ;// set hover as current

            .IF osc_hover

                mov eax, osc_hover
                mov debug_pOsc, eax
                mov esi, eax

            .ENDIF

        .ELSE

            GET_PIN debug_pPin, ebx

            .IF     edx == 'P'  ;// move through connection

                .IF [ebx].pPin
                    mov ebx, [ebx].pPin
                    mov esi, [ebx].pObject
                .ENDIF

            .ELSEIF edx == 'B'  ;// move to next buss

                .IF [ebx].dwStatus & PIN_BUS_TEST &&    \
                    !([ebx].dwStatus & PIN_OUTPUT) &&   \
                    [ebx].pData

                    mov ebx, [ebx].pData
                    mov esi, [ebx].pObject

                .ENDIF

            .ELSEIF edx == VK_LBRACKET  ;// previous pin

                sub ebx, SIZEOF APIN

            .ELSEIF edx == VK_RBRACKET  ;// next pin

                add ebx, SIZEOF APIN

            .ENDIF

        .ENDIF

        .IF esi != debug_pOsc
            mov debug_pOsc, esi
        .ENDIF

        .IF !debug_pOsc
            stack_Peek gui_context, ecx
            dlist_GetHead oscZ, esi, [ecx]
            mov debug_pOsc, esi
        .ENDIF

        .IF debug_pOsc

            .IF ebx == [esi].pLastPin
                sub ebx, SIZEOF APIN
            .ENDIF

            .IF ebx <= esi || ebx >= [esi].pLastPin

                OSC_TO_PIN_INDEX esi, ebx, 0

            .ENDIF

            mov debug_pPin, ebx

        .ENDIF

        UPDATE_DEBUG

        pop ebx
        pop edi
        pop esi

    .ENDIF

    xor eax, eax
    ret 10h

wm_keydown_proc ENDP
;//
;//     WM_KEYDOWN
;//
;//
;////////////////////////////////////////////////////////////////////

ENDIF ;// USE_DEBUG_PANEL
ASSUME_AND_ALIGN
ENDIF ;// DEBUGBUILD
END