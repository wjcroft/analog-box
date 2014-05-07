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
;// Gdi_display.asm     routines for rendering and the display
;//

;// TOC:
;//
;//     gdi_wm_paint_proc           ;// paint handler for main window
;//     gdi_wm_erasebkgnd_proc      ;// erase background handler for main window
        gdi_Render          PROTO   ;// processes the I list and sends to screen
;//     gdi_render_osc              ;// function to render an osc
        gdi_render_spline   PROTO   ;// draws spline's in the proper fashion


OPTION CASEMAP:NONE

.586
.MODEL FLAT

        .NOLIST
        include <Abox.inc>
        include <triangles.inc>
        include <gdi_pin.inc>
        .LIST

.DATA

    ;// SIZING RECTANGLES

        gdi_client_rect RECT {} ;// current gdi location of the client rect
                                ;// set as (gutterXY,gutterXY+client size)

        gdi_desk_size   POINT {};// size of the users desktop

    ;// DISPLAY SURFACES

        gdi_pDib        dd 0    ;// a DIB_CONTAINER is allocated by dib_Reallocate
        gdi_hDC         dd 0    ;// dc for that bitmap

        ;// derived

        gdi_pBmpBits        dd  0   ;// address of (0,0) on the display surface
        gdi_pBitsGutter     dd  0   ;// address on the display corresponding to (0,0) on the screen
        gdi_pBmpBits_bottom dd  0   ;// address corrsponding to the bottom displayable line (needed by shape fill)
        gdi_bitmap_size POINT {}    ;// width and height of the gdi display surface
        gdi_bitmap_object_delta dd 0    ;// needed to rasterize correctly
                                    ;// this is the difference bewteen the size.x and oBmp_width
        gdi_bHasRendered    dd  0   ;// set true at the first call to gdi_Render
                                    ;// also set true if an osc, pin or bezier is rendered

    ;// PAINTSTRUCT

        gdi_paint PAINTSTRUCT {};// app global paint struct

    ;// spline points need to be coagulated in one spot before being rendered
    ;// these are where it happens

        ALIGN 16
        spline_point_1  POINT   {}
        spline_point_2  POINT   {}
        spline_point_3  POINT   {}
        spline_point_4  POINT   {}

    ;// erase splines get's processed by gdi_render

        slist_Declare pinBez    ;//, APIN, pNextBez

    ;// if erase_rect is zero and nopins are rendered we update the screen
    ;// by blitting only objects with the HINTOSC_RENDER_BLIT_RECT set
    ;// this value let's that happen

        gdi_bBlitFull   dd  0



    ;// debug helpers

    IFDEF DEBUGBUILD

        gdi_debug_rect1 RECT {} ;// inavlidate rect black
        gdi_debug_rect2 RECT {} ;// erase rect      gray
        gdi_debug_rect3 RECT {} ;// blit rect       white

        EXTERNDEF gdi_erase_rect:RECT
        EXTERNDEF gdi_blit_rect:RECT

        prev_gdi_bEraseValid db 0   ;// erase rect is valid
        prev_gdi_bBlitValid  db 0   ;// blit rect is valid
        prev_gdi_bErasePoint db 0   ;// if on, the add bezier radius to the erase rect
        prev_gdi_bBlitPoint  db 0   ;// if on, the add bezier radius to the blit rect


    ENDIF



.CODE



;/////////////////////////////////////////////////////////////////////
;//
;//     WM_PAINT
;//
ASSUME_AND_ALIGN
gdi_wm_paint_proc   PROC PUBLIC ;//  STDCALL hWnd:DWORD, msg:DWORD, wParam:DWORD, lParam:DWORD

;// invoke SendMessageA, hMainWnd, WM_APP, 1 ,0

    invoke app_Sync

    mov eax, WP_HWND
    invoke GetUpdateRect, eax, 0, 0
    .IF eax

    ;// erase the previous blit and erase rect
    ;// get and the new blit and erase rects before render clears them

        IFDEF USE_DEBUG_PANEL
        .IF debug_bShowInvalidRect || debug_bShowInvalidBlit || debug_bShowInvalidErase

            ;// turn off the previous invalidate rect

            push esi
            invoke GetDC, hMainWnd
            mov esi, eax
            .IF debug_bShowInvalidRect
                invoke FrameRect, esi, ADDR gdi_debug_rect1, hBRUSH(0)
            .ENDIF
            .IF debug_bShowInvalidErase
                .IF prev_gdi_bEraseValid
                    invoke FrameRect, esi, ADDR gdi_debug_rect2, hBRUSH(0)
                .ENDIF
            .ENDIF
            .IF debug_bShowInvalidBlit
                .IF prev_gdi_bBlitValid
                    invoke FrameRect, esi, ADDR gdi_debug_rect3, hBRUSH(0)
                .ENDIF
            .ENDIF
            invoke ReleaseDC, hMainWnd, esi
            pop esi

            ;// set the new boundry rects

            rect_CopyTo gdi_paint.rcPaint, gdi_debug_rect1

            point_GetTL gdi_erase_rect
            point_Sub GDI_GUTTER
            point_SetTL gdi_debug_rect2

            point_GetBR gdi_erase_rect
            point_Sub GDI_GUTTER
            point_SetBR gdi_debug_rect2

            point_GetTL gdi_blit_rect
            point_Sub GDI_GUTTER
            point_SetTL gdi_debug_rect3

            point_GetBR gdi_blit_rect
            point_Sub GDI_GUTTER
            point_SetBR gdi_debug_rect3

            ;// xfer the valid flags

            mov eax, DWORD PTR gdi_bEraseValid
            mov DWORD PTR prev_gdi_bEraseValid, eax

        .ENDIF
        ENDIF

    ;// begin paint
    ;//
    ;//     do this now so that wm_erase background gets processed

        mov edx, WP_HWND
        invoke BeginPaint, edx, OFFSET gdi_paint

    ;// make sure the I list gets processed
    ;// don't bother to call if there's nothing to do

        DEBUG_CLOCKER_BEGIN render

        mov eax, app_bFlags
        and eax, APP_MODE_CONNECTING_PIN OR APP_MODE_USING_SELRECT
        mov gdi_bBlitFull, eax  ;// reset the 'drew an osc flag'

        .IF DWORD PTR gdi_bEraseValid           ;// check all four flags
            invoke gdi_Render                   ;// call render
            mov DWORD PTR gdi_bEraseValid, 0    ;// clear all 4 bits
        .ENDIF

        DEBUG_CLOCKER_END render

    ;// start the painting process

        DEBUG_CLOCKER_BEGIN paint

    ;// there two ways to do this
    ;// if bBlitFull is OFF, we scan the Ilist and blit all the rects directly
    ;// otherwise we blit the entire rect

        push ebp
        push esi
        push ebx

        stack_Peek gui_context, ebp

        cmp gdi_bBlitFull, 0    ;// check blit full
        je partial_iterate      ;// jmp to partial loop entrance

    ;// blt what we're supposed to blit
    ;// push manually to streamline some code

        push SRCCOPY                        ;// blt command

        mov edx, gdi_paint.rcPaint.top      ;// load the paint rect
        mov eax, gdi_paint.rcPaint.left
        add edx, GDI_GUTTER_WIDTH           ;// add the gutter width
        add eax, GDI_GUTTER_WIDTH

        push edx                            ;// save as source location
        push eax

        mov ecx, gdi_paint.rcPaint.bottom   ;// load the bottom of the source rect
        mov ebx, gdi_paint.rcPaint.right

        push gdi_hDC                        ;// store the source dc

        sub ecx, gdi_paint.rcPaint.top      ;// subtract to get the size
        sub ebx, gdi_paint.rcPaint.left

        push ecx                            ;// save the size
        push ebx

        push gdi_paint.rcPaint.top          ;// push the destination point
        push gdi_paint.rcPaint.left

        push gdi_paint.hDC                  ;// push the destination dc

        call BitBlt                         ;// call bit blit

    ;// clear the I list, and reset some flags

        dlist_GetHead oscI, esi, [ebp]
        mov edx, NOT (HINTOSC_RENDER_BLIT_RECT OR HINTOSC_RENDER_CLOCKS)
        xor eax, eax
        .WHILE esi
            lea edi, dlist_Next(oscI,esi);//[esi].pNextI
            and [esi].dwHintOsc, edx
            dlist_GetNext oscI, esi
            stosd
            stosd
        .ENDW
        ;//dlist_Clear oscI, [ebp]
        mov dlist_Head(oscI,[ebp]), 0
        mov dlist_Tail(oscI,[ebp]), 0

        jmp done_with_blit


    ;// PARTIAL
    ;//
    ;// no erase, no pins. We'll do all the blits serpately
    ;//
    ;// loop entrance is partial_iterate

        ALIGN 16
        partial_top:    ;// ecx must equal [esi].dwHintOsc

            and ecx, HINTOSC_RENDER_BLIT_RECT OR HINTOSC_RENDER_CLOCKS
            jz partial_iterate      ;// nothing to do here

            not ecx                 ;// store the new flags
            and [esi].dwHintOsc,ecx ;// mask on

            push SRCCOPY            ;// blt command

            mov edx, [esi].rect.top ;// load these points now
            mov eax, [esi].rect.left;// load these points now

            jpe partial_rect_clock  ;// both bits are on, so render both

            and ecx, HINTOSC_RENDER_CLOCKS
            jz partial_rect     ;// clocks was not on (ecx is inverted)

        partial_clocks:     ;// eax, edx are [esi].rect.TL
                            ;// render the clocks only

                sub edx, CLOCKS_RECT_HEIGHT

                push edx    ;// src Y
                push eax    ;// src X

                push gdi_hDC;// src dc

                mov ecx, CLOCKS_RECT_HEIGHT;// dest height
                mov ebx, CLOCKS_RECT_WIDTH  ;// dest width

                jmp partial_do_blit

        ALIGN 16
        partial_rect_clock: ;// eax, edx are [esi].rect.TL
                            ;// render both rect and clocks

                sub edx, CLOCKS_RECT_HEIGHT ;// adjust the src and destination

        partial_rect:       ;// eax, edx are [esi].rect.TL
                            ;// render the rect only

                push edx    ;// src Y
                push eax    ;// src X

                mov ecx, [esi].rect.bottom  ;// load the bottom of the source rect
                mov ebx, [esi].rect.right

                push gdi_hDC;// src DC              ;// store the source dc

                sub ecx, edx;// determine height                ;// subtract to get the size
                sub ebx, eax;// determine width

        partial_do_blit:    ;// copy command must be pushed
                            ;// src x and Y must be pushed
                            ;// src dc must be pushed
                            ;// ebx,ecx must be wdith and height
                            ;// eax,edx must be the destiation in gdi coords

                push ecx    ;// dest height                         ;// save the size
                push ebx    ;// dest width

                sub edx, GDI_GUTTER_WIDTH   ;// subtract to get the destination
                sub eax, GDI_GUTTER_WIDTH   ;// subtract to get the destination

                push edx    ;// dest Y
                push eax    ;// dest X

                push gdi_paint.hDC                  ;// push the destination dc

                call BitBlt                         ;// call bit blit

        partial_iterate:

            dlist_RemoveTail oscI, esi,, [ebp]
            jz done_with_blit
            mov ecx, [esi].dwHintOsc
            jmp partial_top


    ALIGN 16
    done_with_blit:

    ;// draw the 'connecting mode' splines, if any

        .IF app_bFlags & APP_MODE_CONNECTING_PIN

            GET_PIN pin_down, ebx
            DEBUG_IF <!!ebx>                ;// supposed to be set

            invoke SelectObject, gdi_paint.hDC, hPen_dot

            mov eax, [ebx].j_index
            jmp gdir_connecting_jump[eax*4]

        ALIGN 16
        gdir_connecting_TFB::   ;// bussed analog input
        gdir_connecting_LFB::   ;// bussed logic input
        gdir_connecting_FB::    ;// bussed output

            ;// we are MOVING a bus connection
            ;// so we want to show the bus circle ??
            ;// can't really do this because we want to draw on the screen, not the GDI surface

            invoke SelectObject, gdi_paint.hDC, hBrush_null

            point_Get mouse_now
            sub edx, GDI_GUTTER_X - PIN_BUS_RADIUS
            sub eax, GDI_GUTTER_Y - PIN_BUS_RADIUS
            push edx
            push eax
            sub edx, PIN_BUS_RADIUS * 2
            sub eax, PIN_BUS_RADIUS * 2
            push edx
            push eax
            push gdi_paint.hDC
            call Ellipse

            jmp gdir_connecting_done

        gdir_connecting_TFS::   ;// connected analog input
        gdir_connecting_LFS::   ;// connected logic input

            ;// we are to MOVE an input connection
            ;// so we draw from the source pin to mouse now

                .IF !pin_connect_special_18
                    mov ebx, [ebx].pPin
                .ENDIF

            ;// fall into next section

        gdir_connecting_TF::    ;// unconnected analog input
        gdir_connecting_LF::    ;// unconnected logic input
        gdir_connecting_FT::    ;// unconnected output

            ;// are to CONNECT a pin
            ;// so we draw from pin.t1, t2 to mouse now

            point_Get mouse_now         ;// we need mouse now regardless where we end up
            point_Sub GDI_GUTTER        ;// so we'll xfer the points now
            point_Set spline_point_1    ;// what ever get's called can use _3 and _4
            point_Set spline_point_2    ;// for seperate splines

                point_Get [ebx].t1
                point_Sub GDI_GUTTER
                point_Set spline_point_4

                point_Get [ebx].t2
                point_Sub GDI_GUTTER
                point_Set spline_point_3

                invoke PolyBezier, gdi_paint.hDC, OFFSET spline_point_1, 4

            jmp gdir_connecting_done

        ALIGN 16
        gdir_connecting_FS::    ;// connected output

            ;// we are MOVING an output
            ;// so we draw ALL the splines from each INPUT pin

            cmp pin_connect_special_18, 0
            jnz gdir_connecting_FT

            point_Get mouse_now         ;// we need mouse now regardless where we end up
            point_Sub GDI_GUTTER        ;// so we'll xfer the points now
            point_Set spline_point_1    ;// what ever get's called can use _3 and _4
            point_Set spline_point_2    ;// for seperate splines

                mov ebx, [ebx].pPin
                .WHILE ebx

                    point_Get [ebx].t1
                    point_Sub GDI_GUTTER
                    point_Set spline_point_4

                    point_Get [ebx].t2
                    point_Sub GDI_GUTTER
                    point_Set spline_point_3

                    invoke PolyBezier, gdi_paint.hDC, OFFSET spline_point_1, 4

                    mov ebx, [ebx].pData

                .ENDW
                jmp gdir_connecting_done


        gdir_connecting_hide::  ;// time to set

            DEBUG_IF <1>

        ALIGN 16
        gdir_connecting_done:

        .ENDIF

    ;// draw the selrect

        .IF app_bFlags & APP_MODE_USING_SELRECT

            invoke SelectObject, gdi_paint.hDC, hPen_dot
            push eax            ;// store so we can reselect the old pen
            push gdi_paint.hDC  ;// store the hdc too
            invoke SelectObject, gdi_paint.hDC, hBrush_null

            point_GetBR mouse_selrect
            point_Sub GDI_GUTTER
            push edx
            push eax
            point_GetTL mouse_selrect
            point_Sub GDI_GUTTER
            push edx
            push eax
            push gdi_paint.hDC
            call Rectangle

            call SelectObject   ;// parameters already pushed

        .ENDIF

    ;// draw any aligner rects we need to

        EXTERNDEF align_list:DWORD      ;// these are defined in abox_align.asm
        EXTERNDEF align_lock_mode:DWORD
        align_draw_group_rects PROTO STDCALL hDC:DWORD

        .IF align_lock_mode && align_list
            invoke align_draw_group_rects, gdi_paint.hDC
        .ENDIF

    ;// lastly, if we're in a group, we show the heirarycy

    .IF app_bFlags & APP_MODE_IN_GROUP

        push edi
        mov edi, gdi_paint.hDC
        closed_group_DisplayHeirarchy PROTO     ;// defined in groups.inc
        invoke closed_group_DisplayHeirarchy
        pop edi

    .ENDIF

    pop ebx
    pop esi
    pop ebp

    ;// end the paint process

        mov edx, WP_HWND
        invoke EndPaint, edx, OFFSET gdi_paint

        DEBUG_CLOCKER_END paint

    ;// ..one more, now that we've rendered, we have to process APP_SYNC_MOUSE

        btr app_bFlags, LOG2(APP_SYNC_MOUSE)
        .IF CARRY?

            sub esp, 8
            invoke GetCursorPos, esp
            invoke ScreenToClient, hMainWnd, esp
            pop eax ;// x
            pop edx ;// y
            and eax, 0FFFFh
            shl edx, 16
            or eax, edx
            WINDOW hMainWnd, WM_MOUSEMOVE, 0, eax

            invoke gdi_Invalidate

        .ENDIF

    ;// update the rect with new

        IFDEF USE_DEBUG_PANEL
        .IF debug_bShowInvalidRect || debug_bShowInvalidBlit || debug_bShowInvalidErase

            ;// display the new rects
            push esi
            invoke GetDC, hMainWnd
            mov esi, eax
            .IF debug_bShowInvalidRect
                invoke GetStockObject, BLACK_BRUSH
                invoke FrameRect, esi, ADDR gdi_debug_rect1, eax
            .ENDIF
            .IF debug_bShowInvalidErase
                .IF prev_gdi_bEraseValid
                    invoke GetStockObject, LTGRAY_BRUSH
                    invoke FrameRect, esi, ADDR gdi_debug_rect2, eax
                .ENDIF
            .ENDIF
            .IF debug_bShowInvalidBlit
                .IF prev_gdi_bBlitValid
                    invoke GetStockObject, WHITE_BRUSH
                    invoke FrameRect, esi, ADDR gdi_debug_rect3, eax
                .ENDIF
            .ENDIF
            invoke ReleaseDC, hMainWnd, esi
            pop esi

        .ENDIF
        ENDIF


        UPDATE_DEBUG

    ;// return zero

        xor eax, eax

    .ENDIF


;// invoke SendMessageA, hMainWnd, WM_APP, 2 ,0

;// that's it

    ret 10h

gdi_wm_paint_proc ENDP
;//
;//     WM_PAINT
;//
;/////////////////////////////////////////////////////////////////////

.DATA

gdir_connecting_jump    LABEL DWORD

    dd  OFFSET  gdir_connecting_hide;// time to set
    dd  OFFSET  gdir_connecting_TFB ;// bussed analog input
    dd  OFFSET  gdir_connecting_TFS ;// connected analog input
    dd  OFFSET  gdir_connecting_TF  ;// unconnected analog input
    dd  OFFSET  gdir_connecting_LFB ;// bussed logic input
    dd  OFFSET  gdir_connecting_LFS ;// connected logic input
    dd  OFFSET  gdir_connecting_LF  ;// unconnected logic input
    dd  OFFSET  gdir_connecting_FB  ;// bussed output
    dd  OFFSET  gdir_connecting_FS  ;// connected output
    dd  OFFSET  gdir_connecting_FT  ;// unconnected output

.CODE



;/////////////////////////////////////////////////////////////////////
;//
;//     WM_ERASEBKGND
;//
ASSUME_AND_ALIGN
gdi_wm_erasebkgnd_proc PROC PUBLIC

    rect_CopyTo gdi_client_rect, gdi_erase_rect
    or gdi_bEraseValid, 1
    mov eax, 1
    ret 10h

gdi_wm_erasebkgnd_proc ENDP
;//
;//     WM_ERASEBKGND
;//
;/////////////////////////////////////////////////////////////////////











;// this was useful during development
;// RENDER_USE_TRACE EQU 1

IFDEF RENDER_USE_TRACE

ECHO <hey!!!! RENDER_USE_TRACE_IS_ON>

.DATA

    RENDER_TRACE MACRO name:req

        pushad

        invoke wsprintfA, ADDR render_buf, ADDR render_fmt, ADDR sz_&name
        invoke OutputDebugStringA, ADDR render_buf

        popad

        ENDM

    render_buf db 128 dup (0)
    render_fmt db "render %s",0dh,0ah,0

    sz_LINEFEED                   db 0dh, 0ah, 0

    sz_HINTI_OSC_CREATED          db 'HINTI_OSC_CREATED',0
    sz_HINTI_OSC_SHAPE_CHANGED    db 'HINTI_OSC_SHAPE_CHANGED',0
    sz_HINTI_OSC_MOVED            db 'HINTI_OSC_MOVED',0
    sz_HINTI_OSC_MOVE_SCREEN      db 'HINTI_OSC_MOVE_SCREEN',0
    sz_HINTI_OSC_GOT_SELECT       db 'HINTI_OSC_GOT_SELECT',0
    sz_HINTI_OSC_LOST_SELECT      db 'HINTI_OSC_LOST_SELECT',0
    sz_HINTI_OSC_SHOW_PINS        db 'HINTI_OSC_SHOW_PINS',0
    sz_HINTI_OSC_HIDE_PINS        db 'HINTI_OSC_HIDE_PINS',0
    sz_HINTI_OSC_GOT_HOVER        db 'HINTI_OSC_GOT_HOVER',0
    sz_HINTI_OSC_LOST_HOVER       db 'HINTI_OSC_LOST_HOVER',0
    sz_HINTI_OSC_GOT_CON_HOVER    db 'HINTI_OSC_GOT_CON_HOVER',0
    sz_HINTI_OSC_LOST_CON_HOVER   db 'HINTI_OSC_LOST_CON_HOVER',0
    sz_HINTI_OSC_GOT_DOWN         db 'HINTI_OSC_GOT_DOWN',0
    sz_HINTI_OSC_LOST_DOWN        db 'HINTI_OSC_LOST_DOWN',0
    sz_HINTI_OSC_GOT_CON_DOWN     db 'HINTI_OSC_GOT_CON_DOWN',0
    sz_HINTI_OSC_LOST_CON_DOWN    db 'HINTI_OSC_LOST_CON_DOWN',0
    sz_HINTI_PIN_GOT_HOVER        db '  HINTI_PIN_GOT_HOVER',0
    sz_HINTI_PIN_LOST_HOVER       db '  HINTI_PIN_LOST_HOVER',0
    sz_HINTI_PIN_GOT_DOWN         db '  HINTI_PIN_GOT_DOWN',0
    sz_HINTI_PIN_LOST_DOWN        db '  HINTI_PIN_LOST_DOWN',0
    sz_HINTI_OSC_UPDATE_CLOCKS    db 'HINTI_OSC_UPDATE_CLOCKS',0
    sz_HINTI_PIN_UPDATE_CHANGING  db '  HINTI_PIN_UPDATE_CHANGING',0
    sz_HINTI_PIN_PHETA_CHANGED    db '  HINTI_PIN_PHETA_CHANGED',0
    sz_HINTI_PIN_HIDE             db '  HINTI_PIN_HIDE',0
    sz_HINTI_PIN_UNHIDE           db '  HINTI_PIN_UNHIDE',0
    sz_HINTI_OSC_UPDATE           db 'HINTI_OSC_UPDATE',0
    sz_HINTI_PIN_UPDATE_SHAPE     db '  HINTI_PIN_UPDATE_SHAPE',0
    sz_HINTI_PIN_UPDATE_COLOR     db '  HINTI_PIN_UPDATE_COLOR',0
    sz_HINTI_PIN_CONNECTED        db '  HINTI_PIN_CONNECTED',0
    sz_HINTI_PIN_UNCONNECTED      db '  HINTI_PIN_UNCONNECTED',0
    sz_HINTI_SETS_EXTENTS         db 'HINTI_SETS_EXTENTS',0
    sz_HINTI_ONSCREEN             db 'HINTI_ONSCREEN',0

    sz_HINTOSC_INVAL_TEST_ONSCREEN      db 'HINTOSC_INVAL_TEST_ONSCREEN',0
    sz_HINTOSC_INVAL_UPDATE_BOUNDRY     db 'HINTOSC_INVAL_UPDATE_BOUNDRY',0
    sz_HINTOSC_INVAL_DO_PINS            db 'HINTOSC_INVAL_DO_PINS',0
    sz_HINTOSC_INVAL_DO_PINS_LAYOUT     db 'HINTOSC_INVAL_DO_PINS_LAYOUT',0
    sz_HINTOSC_INVAL_DO_PINS_SHOW       db 'HINTOSC_INVAL_DO_PINS_SHOW',0
    sz_HINTOSC_INVAL_DO_PINS_UPDATE     db 'HINTOSC_INVAL_DO_PINS_UPDATE',0
    sz_HINTOSC_INVAL_DO_PINS_JUMP       db 'HINTOSC_INVAL_DO_PINS_JUMP',0
    sz_HINTOSC_RENDER_DO_PINS           db 'HINTOSC_RENDER_DO_PINS',0
    sz_HINTOSC_INVAL_BLIT_RECT          db 'HINTOSC_INVAL_BLIT_RECT',0
    sz_HINTOSC_INVAL_BLIT_BOUNDRY       db 'HINTOSC_INVAL_BLIT_BOUNDRY',0
    sz_HINTOSC_INVAL_ERASE_BOUNDRY      db 'HINTOSC_INVAL_ERASE_BOUNDRY',0
    sz_HINTOSC_INVAL_SET_SHAPE          db 'HINTOSC_INVAL_SET_SHAPE',0
    sz_HINTOSC_INVAL_BUILD_RENDER       db 'HINTOSC_INVAL_BUILD_RENDER',0
    sz_HINTOSC_STATE_BOUNDRY_VALID      db 'HINTOSC_STATE_BOUNDRY_VALID',0
    sz_HINTOSC_RENDER_CALL_BASE         db 'HINTOSC_RENDER_CALL_BASE',0
    sz_HINTOSC_RENDER_MASK              db 'HINTOSC_RENDER_MASK',0
    sz_HINTOSC_RENDER_OUT1              db 'HINTOSC_RENDER_OUT1',0
    sz_HINTOSC_STATE_HAS_HOVER          db 'HINTOSC_STATE_HAS_HOVER',0
    sz_HINTOSC_STATE_HAS_CON_HOVER      db 'HINTOSC_STATE_HAS_CON_HOVER',0
    sz_HINTOSC_RENDER_OUT2              db 'HINTOSC_RENDER_OUT2',0
    sz_HINTOSC_STATE_HAS_LOCK           db 'HINTOSC_STATE_HAS_LOCK',0
    sz_HINTOSC_STATE_HAS_SELECT         db 'HINTOSC_STATE_HAS_SELECT',0
    sz_HINTOSC_RENDER_OUT3              db 'HINTOSC_RENDER_OUT3',0
    sz_HINTOSC_STATE_HAS_GROUP          db 'HINTOSC_STATE_HAS_GROUP',0
    sz_HINTOSC_STATE_HAS_BAD            db 'HINTOSC_STATE_HAS_BAD',0
    sz_HINTOSC_RENDER_CLOCKS            db 'HINTOSC_RENDER_CLOCKS',0
    sz_HINTOSC_STATE_SHOW_PINS          db 'HINTOSC_STATE_SHOW_PINS',0
    sz_HINTOSC_STATE_HAS_DOWN           db 'HINTOSC_STATE_HAS_DOWN',0
    sz_HINTPIN_RENDER_ASSY              db '  HINTPIN_RENDER_ASSY',0
    sz_HINTPIN_RENDER_OUT1              db '  HINTPIN_RENDER_OUT1',0
    sz_HINTPIN_RENDER_OUT1_BUS          db '  HINTPIN_RENDER_OUT1_BUS',0
    sz_HINTPIN_RENDER_CONN              db '  HINTPIN_RENDER_CONN',0
    sz_HINTPIN_STATE_THICK              db '  HINTPIN_STATE_THICK',0
    sz_HINTPIN_STATE_HAS_HOVER          db '  HINTPIN_STATE_HAS_HOVER',0
    sz_HINTPIN_STATE_HAS_DOWN           db '  HINTPIN_STATE_HAS_DOWN',0
    sz_HINTPIN_STATE_HIDE               db '  HINTPIN_STATE_HIDE',0
    sz_HINTPIN_INVAL_LAYOUT_SHAPE       db '  HINTPIN_INVAL_LAYOUT_SHAPE',0
    sz_HINTPIN_INVAL_LAYOUT_POINTS      db '  HINTPIN_INVAL_LAYOUT_POINTS',0
    sz_HINTPIN_STATE_VALID_TSHAPE       db '  HINTPIN_STATE_VALID_TSHAPE',0
    sz_HINTPIN_STATE_VALID_DEST         db '  HINTPIN_STATE_VALID_DEST',0
    sz_HINTPIN_INVAL_BUILD_JUMP         db '  HINTPIN_INVAL_BUILD_JUMP',0
    sz_HINTPIN_INVAL_BUILD_RENDER       db '  HINTPIN_INVAL_BUILD_RENDER',0
    sz_HINTPIN_INVAL_ERASE_CONN         db '  HINTPIN_INVAL_ERASE_CONN',0
    sz_HINTPIN_INVAL_ERASE_RECT         db '  HINTPIN_INVAL_ERASE_RECT',0
    sz_HINTPIN_INVAL_BLIT_RECT          db '  HINTPIN_INVAL_BLIT_RECT',0
    sz_HINTPIN_INVAL_BLIT_CONN          db '  HINTPIN_INVAL_BLIT_CONN',0

    ALIGN 4

.CODE



ELSE    ;// use render tracing

    RENDER_TRACE MACRO name:req

        ENDM

ENDIF   ;// use render tracing

















;///////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////
;//
;//
;//     G D I _ R E N D E R
;//
;//     spaghetti code
;//
;//
;//
;// this rips through oscI and does all the rendering
;// this is during the wm_paint message, before blitting gdi_hBitmap
;// we'll need to double scan
;// once to check the update region
;// a second time to draw the objects
;//
ASSUME_AND_ALIGN
gdi_Render  PROC PRIVATE uses ebp esi edi ebx

    or gdi_bHasRendered, 1      ;// always set this, shape build may turn it off

    stack_Peek gui_context, ebp     ;// get the current context

    ;// this first scan takes care of erasing everything


    ;////////////////////////////////////////////////////////////////////
    ;//
    ;//     ERASE THE ERASE RECT
    ;//
    ;//
    .IF gdi_bEraseValid     ;// skip if nothing to erase

        inc gdi_bBlitFull

        ;// clip the erase rect so it falls on the screen
        ;// at the same time we'll align the boundries on a dword and check if empty

            mov edi, 0FFFFFFFCh     ;// dword aligner

            point_GetTL gdi_erase_rect          ;// (eax, edx)
            point_GetBR gdi_erase_rect, ebx, ecx;// (ebx, ecx)

            cmp eax, ebx    ;// check if left is greater or equal to right
            jge erasing_done
            cmp edx, ecx    ;// check if bottom is less than top
            jge erasing_done

            .IF eax < gdi_client_rect.left
                mov eax, gdi_client_rect.left
            .ENDIF
            and eax, edi    ;// align to previous

            .IF ebx > gdi_client_rect.right
                mov ebx, gdi_client_rect.right
            .ENDIF
            add ebx, 4      ;// align to next dword
            and ebx, edi

            cmp eax, ebx    ;// check if empty
            jge erasing_done;// jump if empty

            .IF edx < gdi_client_rect.top
                mov edx, gdi_client_rect.top
            .ELSE
                and edx, edi
            .ENDIF

            .IF ecx > gdi_client_rect.bottom
                mov ecx, gdi_client_rect.bottom
            .ENDIF

            cmp edx, ecx    ;// check if empty
            jge erasing_done;// jump if empty

            ;// store the newly aligned coordinates

            point_SetTL gdi_erase_rect
            point_SetBR gdi_erase_rect, ebx, ecx

        ;// 2) erase it

            ;// compute the start address

            GDI_RECTTL_TO_GDI_ADDRESS gdi_erase_rect, edi

            ;// compute the height

            mov edx, gdi_erase_rect.bottom  ;// get bottom
            sub edx, gdi_erase_rect.top     ;// subtract top to get height

            DEBUG_IF <CARRY? || ZERO?>      ;// erase rect is still invalid ??!!

            mov esi, gdi_erase_rect.right   ;// load right side
            mov ebx, gdi_bitmap_size.x      ;// load scan line width

            sub esi, gdi_erase_rect.left    ;// subtract to get byte width
            xor eax, eax                    ;// erase always stores color zero
            sub ebx, esi                    ;// subtract byte width to get raster adjust
            shr esi, 2                      ;// make esi, a dword count

        ;// erase the rectangle

            jmp @2                          ;// jump into entrance

        @1: add edi, ebx    ;// add the raster adjust
        @2: mov ecx, esi    ;// load the count
            rep stosd       ;// fill it
            dec edx         ;// decrease the line count
            jnz @1          ;// loop until done

        erasing_done:       ;// done or early out
    ;//
    ;//     ERASE RECTANGLE
    ;//
    ;//
    ;////////////////////////////////////////////////////////////////////


    ;////////////////////////////////////////////////////////////////////
    ;//
    ;//
    ;//     LOCATE PARTIALLY ERASED ITEMS
    ;//

    comment ~ /*

        this part is somewhat time consuming

        tasks are:

            locate osc.boundries that are inside or intersect the erase rect
            that's the easy part

            the next task involves locating connections that cross the erase rect
            if an osc.boundry is not in the rect, then we scan it's outputs to determine
            if any connections intersect the rect

        lastly:

            for any object we have to add, it gets put at the tail,
            since it must be on the bottom

        for determining if a connection crosses the rect
        the test is: if any part of the connection intersectes the erase rect

            since we have splines that do not always fall 'inside' the t0 point
            we have to build a rectangle that guarantees it will include all of the spline
            this can be done by finding the min/max of the t1,and t2 points from the triangle

            from there we have four coords that may be quickly tested

            we know we are NOT in the rect IF :
                min.x > erase.rect.right
                min.y > erase.rect.bottom
                max.x < erase rect.left
                max.y < erase.rect.top

            S = Source pin
            D = dest pin

        */ comment ~


        dlist_GetHead oscZ, esi, [ebp]  ;// get the head of the Z list
        or esi, esi                     ;// skip empty lists
        jz erase_osc_complete

    erase_osc_top:

        ;// look for partially erased oscs

        xor ecx, ecx    ;// use for testing

        ;// always check onscreen first

            or ecx, [esi].dwHintOsc ;// load and test the ONSCREEN bit
            jns erase_pins_top      ;// jump to pin scanner

        ;// this object is on screen

        ;// test the boundry, jump to test pins if not in erase rect

            rect_IfNotIntersect [esi].boundry, gdi_erase_rect, erase_pins_top

        ;// add this osc to the list

            dlist_IfMember_jump oscI,esi,already_in_list,[ebp]
            dlist_InsertTail oscI, esi,,[ebp]

        already_in_list:

            mov edi, [esi].dwHintOsc
            or edi, HINTOSC_RENDER_MASK OR HINTOSC_RENDER_DO_PINS
            invoke gdi_osc_BuildRenderFlags
            mov [esi].dwHintOsc, edi

            ;// now we need to force the pins to redisplay

            .IF edi & HINTOSC_STATE_SHOW_PINS   ;// showing pins ?

                ITERATE_PINS
                    mov ecx, [ebx].dwHintPin
                    invoke gdi_pin_BuildRenderFlags
                    mov [ebx].dwHintPin, ecx
                PINS_ITERATE

            .ELSE                               ;// not showing pins

                ITERATE_PINS
                    mov eax, [ebx].j_index
                    .IF pin_j_index_connected[eax]
                        mov ecx, [ebx].dwHintPin
                        invoke gdi_pin_BuildRenderFlags
                        mov [ebx].dwHintPin, ecx
                    .ENDIF
                PINS_ITERATE

            .ENDIF


        erase_osc_next:

            dlist_GetNext oscZ, esi
            or esi, esi
            jnz erase_osc_top

            jmp erase_osc_complete

            IF (PIN_HIDDEN NE 200h)
            .ERR <PIN_HIDDEN must equal 200h>
            ENDIF
            IF (PIN_OUTPUT NE 100h)
            .ERR <PIN_OUTPUT must equal 100h>
            ENDIF




        erase_pins_top:

        ;// TESTJMP app_CircuitSettings, CIRCUIT_NOPINS, jnz erase_osc_next ;// added ABox231

        ;// check for partially erased pins

            ITERATE_PINS

            ;// only check connected, un-hidden, un-bussed, output pins

                cmp [ebx].j_index, PIN_J_INDEX_FS
                jne erase_pins_next

            ;// now we do a scan of this chain
            ;// we'll use edi to do this

                GET_PIN [ebx].pPin, edi ;// get first input pin

                erase_con_top:

                ;// check if it's osc is already in I list
                ;// PIN_TO_OSC edi, ecx
                ;// xor eax, eax
                ;// dlist_IfMember_jumpto oscI, ecx, erase_con_next, eax, [ebp]

                ;// check if the connection intersectes the erase rect

                ;// determine min.xy of:
                ;// S.t1, S.t2, D.t1, D.t2

                    point_Get [ebx].t1
                    point_Min [ebx].t2
                    point_Min [edi].t1
                    point_Min [edi].t2

                ;// test against erase BR

                    cmp eax, gdi_erase_rect.right
                    jg  erase_con_next
                    cmp edx, gdi_erase_rect.bottom
                    jg  erase_con_next

                ;// determine max.xy of:
                ;// S.t1, S.t2, D.t1, D.t2

                    point_Get [ebx].t1
                    point_Max [ebx].t2
                    point_Max [edi].t1
                    point_Max [edi].t2

                ;// test against erase TL

                    cmp eax, gdi_erase_rect.left
                    jl  erase_con_next
                    cmp edx, gdi_erase_rect.top
                    jl  erase_con_next

                ;// fall through is add to pinBez list

                    slist_InsertHead pinBez, edi

                erase_con_next:

                    mov edi, [edi].pData    ;// get next pin in chain
                    or edi, edi             ;// test for zero
                    jnz erase_con_top       ;// jump if not done

        erase_pins_next:

            PINS_ITERATE

            jmp erase_osc_next





        erase_osc_complete:

            ;// clear the erase rect

            xor eax, eax

            mov gdi_erase_rect.left, eax
            mov gdi_erase_rect.top, eax
            mov gdi_erase_rect.right, eax
            mov gdi_erase_rect.bottom, eax

        ;//
        ;//
        ;//     LOCATE PARTIALLY ERASED ITEMS
        ;//
        ;////////////////////////////////////////////////////////////////////

    .ENDIF  ;// erase valid
    ;//
    ;//
    ;//     E R A S E
    ;//
    ;////////////////////////////////////////////////////////////////////








    ;/////////////////////////////////////////////////////////////////////
    ;//
    ;//     R E N D E R         three scans     1) labels           I list
    ;//                                         2) erased beziers   pinBez list
    ;//                                         3) the rest of the  I list

    ;// 1) labels, so it looks like oscs are always on top of them

        dlist_GetTail oscI, esi, [ebp]

        .WHILE esi

            .IF [esi].pBase == OFFSET osc_Label

                OSC_TO_BASE esi, edi
                invoke [edi].gui.Render
                dlist_GetPrev oscI, esi, ecx
                dlist_Remove oscI, esi,,[ebp]
                mov esi, ecx

            .ELSE

                dlist_GetPrev oscI, esi

            .ENDIF

        .ENDW


    ;// 2) draw partialy erase splines


            slist_GetHead pinBez, esi
            .WHILE esi

                DEBUG_IF <[esi].dwStatus & PIN_OUTPUT>  ;// supposed to be an input pin

                DEBUG_IF <[esi].dwStatus & PIN_BUS_TEST>;// NOT supposed to be a bus


                GET_PIN [esi].pPin, ebx     ;// get the output pin

                ;// make sure it has a valid dest

                .IF !([ebx].dwHintPin & HINTPIN_STATE_VALID_DEST)
                    invoke pin_Layout_points
                .ENDIF

                ;// build sp1 and sp2

                point_CopyTo [ebx].t1, spline_point_1
                point_CopyTo [ebx].t2, spline_point_2

                ;// reset our render command and draw the spline

                and [esi].dwHintPin, NOT HINTPIN_RENDER_CONN    ;// reset the RENDER_CONN bit
        .IF !(app_CircuitSettings & CIRCUIT_NOPINS) ;// Added ABox231
                invoke gdi_render_spline
        .ENDIF  ;// Added ABox231

                ;// iterate and flush

                slist_GetNext pinBez, esi
                mov slist_Head(pinBez), esi;//slist_SetHead pinBez, esi

            .ENDW



    ;// 3) the rest of the objects

        xor eax, eax            ;// clear for testing
        push eax
        st_osc TEXTEQU <(DWORD PTR [esp])>

        dlist_GetTail oscI, esi, [ebp]

    ;// scan the list

    .WHILE esi

        xor eax, eax
        or  eax, [esi].dwHintOsc        ;// load and test get the render flags
        .IF SIGN?                       ;// skip if osc is offscreen
        test eax, HINTOSC_RENDER_TEST   ;// see if anything is set
        .IF !ZERO?                      ;// render bits are set

            btr eax, LOG2(HINTOSC_RENDER_CALL_BASE) ;// check if we're supposed to call the base
            .IF CARRY?

                RENDER_TRACE HINTOSC_RENDER_CALL_BASE

                ;// xfer HAS_CON_HOVER to HINTOSC_RENDER_BLIT_RECT
                ;// otherwise we'll skip blitting during gdi_wm_paint_proc.partial_top
                mov edx, eax
                and edx, HINTOSC_STATE_HAS_CON_HOVER
                BITSHIFT edx, HINTOSC_STATE_HAS_CON_HOVER, HINTOSC_RENDER_BLIT_RECT
                or eax, edx

                OSC_TO_BASE esi, edi        ;// get the base class
                mov [esi].dwHintOsc, eax    ;// store the adjusted flags
                invoke [edi].gui.Render     ;// call the base class

            .ELSE

                invoke gdi_render_osc       ;// call render directly

            .ENDIF

        .ENDIF  ;// nothing to do
        .ENDIF  ;// on screen

        ;// the osc is now rendered
        ;// the next task is to check the pins

            btr [esi].dwHintOsc, LOG2(HINTOSC_RENDER_DO_PINS);// display shuts this off
            .IF CARRY?

                RENDER_TRACE HINTOSC_RENDER_DO_PINS

                ;// pin scan
                ;//
                ;//     these blocks jump to other blocks down below
                ;//     there are a lot of them
                ;//     which function gets jumped to depends on the jump index
                ;//     we assume the jump index is completely correct
                ;//     all jumps come back to the same block
                ;//
                ;// there are three parts to the render
                ;//
                ;//     assy    assembly    the triangle or logic shape and the font
                ;//     out1    ouline 1    if hover, we draw the outline for the gdi shape
                ;//     conn    draw the connection, always a bezier
                ;//
                ITERATE_PINS    ;// scan the pins

                    mov edi, [ebx].dwHintPin    ;// load pin flags

                    .IF edi & HINTPIN_RENDER_TEST   ;// make sure there's something to do

                        push ebx    ;// save the pin
                        st_pin  TEXTEQU <(DWORD PTR [esp+call_depth*4])>
                        call_depth=0

                    ;// make sure pDest is valid

                        bt edi, LOG2(HINTPIN_STATE_VALID_DEST)
                        .IF !CARRY?
                            invoke pin_Layout_points
                            mov edi, [ebx].dwHintPin
                        .ENDIF

                    ;// always check that pin is on the screen

                        or edi, edi
                        jns check_render_pin_con    ;// may need to draw a bezier

                    ;// assy

                        btr edi, LOG2(HINTPIN_RENDER_ASSY)
                        .IF CARRY?

                            RENDER_TRACE HINTPIN_RENDER_ASSY

                            mov eax, [ebx].j_index
                            mov [ebx].dwHintPin, edi    ;// save the flags
        .IF !(app_CircuitSettings & CIRCUIT_NOPINS) ;// added ABox231
                            jmp gdi_render_pin_assy_jump[eax*4]

                        gdi_render_pin_assy_done::
        .ENDIF ;// CIRCUIT_NOPINS

                            mov ebx, st_pin             ;// retrieve the pin
                            mov edi, [ebx].dwHintPin    ;// load pin flags

                            inc gdi_bBlitFull           ;// set the 'drew a pin flag'
                            or gdi_bHasRendered, 1

                        .ENDIF

                    ;// out1

                        btr edi, LOG2(HINTPIN_RENDER_OUT1)
                        .IF CARRY?

                            RENDER_TRACE HINTPIN_RENDER_OUT1

                            mov eax, [ebx].j_index
                            mov [ebx].dwHintPin, edi    ;// save the flags
        .IF !(app_CircuitSettings & CIRCUIT_NOPINS) ;// added ABox231
                            jmp gdi_render_pin_out1_jump[eax*4]

                        gdi_render_pin_out1_done::
        .ENDIF ;// CIRCUIT_NOPINS

                            mov ebx, st_pin             ;// retrieve the pin
                            mov edi, [ebx].dwHintPin    ;// load pin flags

                            inc gdi_bBlitFull           ;// set the 'drew a pin flag'
                            or gdi_bHasRendered, 1

                        .ENDIF

                    ;// out1 bus

                        btr edi, LOG2(HINTPIN_RENDER_OUT1_BUS)
                        .IF CARRY?

                            RENDER_TRACE HINTPIN_RENDER_OUT1_BUS

                            mov eax, [ebx].j_index
                            mov [ebx].dwHintPin, edi    ;// save the flags
        .IF !(app_CircuitSettings & CIRCUIT_NOPINS) ;// added ABox231
                            jmp gdi_render_pin_out1_bus_jump[eax*4]

                        gdi_render_pin_out1_bus_done::
        .ENDIF ;// CIRCUIT_NOPINS

                            mov ebx, st_pin             ;// retrieve the pin
                            mov edi, [ebx].dwHintPin    ;// load pin flags

                            inc gdi_bBlitFull           ;// set the 'drew a pin flag'
                            or gdi_bHasRendered, 1

                        .ENDIF

                    ;// conn

                    check_render_pin_con:

                        btr edi, LOG2(HINTPIN_RENDER_CONN)
                        .IF CARRY?

                            RENDER_TRACE HINTPIN_RENDER_CONN

                            mov [ebx].dwHintPin, edi        ;// save the flags

        .IF !(app_CircuitSettings & CIRCUIT_NOPINS) ;// added ABox231
                                jmp gdi_render_pin_conn     ;// there's only one way to render these

                            gdi_render_pin_conn_done::
        .ENDIF ;// CIRCUIT_NOPINS

                                mov ebx, st_pin             ;// retrieve the pin
                                mov edi, [ebx].dwHintPin    ;// load pin flags

                                inc gdi_bBlitFull           ;// set the 'drew a pin flag'
                                or gdi_bHasRendered, 1

                        .ENDIF

                    ;// done

                        pop ebx                 ;// reload the pin
                        mov esi, [ebx].pObject  ;// reload the osc

                    .ENDIF  ;// RENDER_PIN_TEST

                PINS_ITERATE

            .ENDIF  ;// HINTOSC_RENDER_DO_PINS

    render_osc_next:

        RENDER_TRACE LINEFEED

        dlist_GetPrev oscI, esi

    .ENDW
    ;//
    ;//     RENDER THE LIST
    ;//
    ;/////////////////////////////////////////////////////////////////////

    ;// that's it

        pop eax

        ret




;////////////////////////////////////////////////////////////////////
;//
;//                                 have the luxury of trashing
;//     gdi_render_pin functions    all registers except ebp
;//



    ;// TFB     triangle    font    bus
    ALIGN 16
    gdi_render_pin_assy_TFB::

            DEBUG_IF < app_CircuitSettings & CIRCUIT_NOPINS >   ;// added ABox231

        ;// fill bus back ground

            PIN_TO_TSHAPE ebx, ecx      ;// get our triangle shape
            PIN_TO_DEST ebx, edi        ;// get our dest
            mov eax, F_COLOR_PIN_BACK   ;// load the back color
            add edi, [ecx].p7           ;// add the offset from t0
            SHAPE_TO_MASK shape_bus, ebx;// load the mask from the shape
            invoke shape_Fill

        ;// draw the font

            GET_PIN st_pin, ebx         ;// get the pin
            PIN_TO_TSHAPE ebx, ecx          ;// get our triangle shape
            mov edi, [ecx].p4               ;// load appropriate offset
            call gdi_render_pin_assy_font   ;// call function to do this

        ;// fill bus font

            GET_PIN st_pin, ebx         ;// get the pin
            mov eax, [ebx].color    ;// use the pin's color
            PIN_TO_TSHAPE ebx, ecx      ;// get our triangle shape
            PIN_TO_DEST ebx, edi        ;// get our dest
            add edi, [ecx].p7           ;// add the offset from t0
            PIN_TO_BSHAPE ebx, esi      ;// load the desired bus shape
            SHAPE_TO_MASK esi, ebx      ;// load the mask from the shape
            invoke shape_Fill

        ;// fill triangle (eax still has the color)

            GET_PIN st_pin, ebx     ;// reload the pin
            PIN_TO_DEST ebx, edi    ;// determine the destination
            PIN_TO_TSHAPE ebx, ecx  ;// get the triangle shape
            SHAPE_TO_MASK ecx, ebx  ;// load the mask from shape
            invoke shape_Fill

            jmp gdi_render_pin_assy_done    ;// exit


    ;// LFB     logic   font    bus
    ALIGN 16
    gdi_render_pin_assy_LFB::

            DEBUG_IF < app_CircuitSettings & CIRCUIT_NOPINS >   ;// added ABox231

        ;// fill bus back ground

            PIN_TO_TSHAPE ebx, ecx      ;// get our triangle shape
            PIN_TO_DEST ebx, edi        ;// get out dest
            mov eax, F_COLOR_PIN_BACK   ;// load the back color
            add edi, [ecx].p6           ;// add appropriate offset
            SHAPE_TO_MASK shape_bus, ebx;// load the mask from the shape
            invoke shape_Fill

        ;// draw the font

            GET_PIN st_pin, ebx         ;// get the pin
            PIN_TO_TSHAPE ebx, ecx          ;// get our triangle shape
            mov edi, [ecx].p3               ;// load appropriate offset
            call gdi_render_pin_assy_font   ;// draw the font

        ;// fill bus font

            GET_PIN st_pin, ebx         ;// get the pin
            PIN_TO_TSHAPE ebx, ecx      ;// get our triangle shape
            mov eax, [ebx].color        ;// use the pin's color
            PIN_TO_BSHAPE ebx, esi      ;// load the desired bus shape
            PIN_TO_DEST ebx, edi        ;// get out dest
            SHAPE_TO_MASK esi, ebx      ;// load the busses masker
            add edi, [ecx].p6           ;// add appropriate offset

            invoke shape_Fill

        ;// draw the logic shape

            GET_PIN st_pin, ebx     ;// load our pin
            PIN_TO_TSHAPE ebx, ecx  ;// load our triangle shape
            PIN_TO_DEST ebx, edi    ;// load our dest
            PIN_TO_LSHAPE ebx, esi  ;// load the logic shape
            add edi, [ecx].p1       ;// add appropriate offset (always p1)
            SHAPE_TO_MASK esi, ebx  ;// load the logic shape's masker
            SHAPE_TO_SOURCE esi, esi;// load the fixed source

            invoke shape_Move       ;// blit the logic shape

            jmp gdi_render_pin_assy_done    ;// exit


    ;// FB      font    bus
    ALIGN 16
    gdi_render_pin_assy_FB::

            DEBUG_IF < app_CircuitSettings & CIRCUIT_NOPINS >   ;// added ABox231

        ;// fill bus back ground

;//         GET_PIN st_pin, ebx
            PIN_TO_TSHAPE ebx, ecx      ;// get our triangle shape
            PIN_TO_DEST ebx, edi        ;// get out dest
            mov eax, F_COLOR_PIN_BACK   ;// load the back color
            add edi, [ecx].p5           ;// add appropriate offset
            SHAPE_TO_MASK shape_bus, ebx;// load the mask from the shape
            invoke shape_Fill

        ;// draw the font

            GET_PIN st_pin, ebx         ;// get the pin
            PIN_TO_TSHAPE ebx, ecx          ;// get our triangle shape
            mov edi, [ecx].p2               ;// load appropriate offset
            call gdi_render_pin_assy_font

        ;// fill bus font

            GET_PIN st_pin, ebx         ;// get the pin

            PIN_TO_TSHAPE ebx, ecx      ;// get our triangle shape
            PIN_TO_DEST ebx, edi        ;// get out dest
            add edi, [ecx].p5           ;// add appropriate offset

            mov eax, [ebx].color        ;// use the pin's color
            PIN_TO_BSHAPE ebx, esi      ;// load the desired bus shape
            SHAPE_TO_MASK esi, ebx      ;// load the busses masker
            invoke shape_Fill

            jmp gdi_render_pin_assy_done    ;// exit



    ;// TF      triangle    font
    ;// TFS     triangle    font    spline
    ALIGN 16
    gdi_render_pin_assy_TFS::
    gdi_render_pin_assy_TF::

            DEBUG_IF < app_CircuitSettings & CIRCUIT_NOPINS >   ;// added ABox231

        ;// draw the font first

            PIN_TO_TSHAPE ebx, ecx          ;// get our triangle shape
            mov edi, [ecx].p4               ;// load appropriate offset
            call gdi_render_pin_assy_font   ;// call function to do this

        ;// fill triangle (eax still has the color)

            GET_PIN st_pin, ebx     ;// reload the pin
            PIN_TO_DEST ebx, edi    ;// determine the destination
            PIN_TO_TSHAPE ebx, ecx  ;// get the triangle shape
            SHAPE_TO_MASK ecx, ebx  ;// load the mask from shape
            invoke shape_Fill

            jmp gdi_render_pin_assy_done    ;// exit


    ;// FT      font    triangle
    ALIGN 16
    gdi_render_pin_assy_FT::

            DEBUG_IF < app_CircuitSettings & CIRCUIT_NOPINS >   ;// added ABox231

        ;// draw the font first

            PIN_TO_TSHAPE ebx, ecx          ;// get our triangle shape
            mov edi, [ecx].p8               ;// load appropriate offset
            call gdi_render_pin_assy_font   ;// call draw font function

        ;// fill triangle (eax still has the color)

            GET_PIN st_pin, ebx     ;// reload the pin
            PIN_TO_TSHAPE ebx, ecx  ;// get our triangle shape
            PIN_TO_DEST ebx, edi    ;// load the destination
            add edi, [ecx].p9       ;// add appropriate offset
            SHAPE_TO_MASK ecx, ebx  ;// load the mask from shape
            invoke shape_Fill       ;// draw the triangle

        ;// exit

            jmp gdi_render_pin_assy_done



    ;// LFS     logic   font    spline
    ;// LF      logic   font
    ALIGN 16
    gdi_render_pin_assy_LFS::
    gdi_render_pin_assy_LF::

            DEBUG_IF < app_CircuitSettings & CIRCUIT_NOPINS >   ;// added ABox231

        ;// draw the font

            PIN_TO_TSHAPE ebx, ecx          ;// get our triangle shape
            mov edi, [ecx].p3               ;// load appropriate offset
            call gdi_render_pin_assy_font   ;// draw the font

        ;// draw the logic shape

            GET_PIN st_pin, ebx     ;// load our pin
            PIN_TO_TSHAPE ebx, ecx  ;// load our triangle shape
            PIN_TO_DEST ebx, edi    ;// load our dest
            PIN_TO_LSHAPE ebx, esi  ;// load the logic shape
            add edi, [ecx].p1       ;// add appropriate offset (always p1)
            SHAPE_TO_MASK esi, ebx  ;// load the logic shape's masker
            SHAPE_TO_SOURCE esi, esi;// load the fixed source

            invoke shape_Move       ;// blit the logic shape

            jmp gdi_render_pin_assy_done    ;// exit



    ;// FS      font    connection line
    ALIGN 16
    gdi_render_pin_assy_FS::

            DEBUG_IF < app_CircuitSettings & CIRCUIT_NOPINS >   ;// added ABox231

        ;// draw the font

            PIN_TO_TSHAPE ebx, ecx          ;// get our triangle shape
            mov edi, [ecx].p2               ;// load appropriate offset

            call gdi_render_pin_assy_font

            jmp gdi_render_pin_assy_done    ;// exit






    ;// gdi_render_pin_assy_font
    ALIGN 16
    gdi_render_pin_assy_font:

            DEBUG_IF < app_CircuitSettings & CIRCUIT_NOPINS >   ;// added ABox231

        ;// mask and draw the font
        ;// returns with color in eax
        ;// accounts for pins that will be hidden

            ;// edi must have the appropriate offset to the font's center
            ASSUME ebx:PTR APIN ;// ebx must enter as the osc

            call_depth = 1      ;// needed for st_pin to work correctly

        ;// fill font back ground and account for pins that want to be hidden

            DEBUG_IF <!![ebx].pDest>    ;// pdest is not set !!
            add edi, [ebx].pDest                ;// determine the destination
            test [ebx].dwHintPin, HINTPIN_STATE_HIDE    ;// if pin is going to be hidden
            mov eax, F_COLOR_PIN_BACK           ;// load most common color
            jz @F                               ;// use if not being hidden
            mov eax, F_COLOR_PIN_BAD            ;// else fill w bad back color
        @@: push edi                            ;// save, we'll need this again
            SHAPE_TO_MASK shape_pin_font, ebx   ;// get the mask from the back ground shape
            invoke shape_Fill
            pop edi                 ;// retrieve the correct pDest

        ;// fill font text

            GET_PIN st_pin, ebx     ;// retreieve the pin
            PIN_TO_FSHAPE ebx, esi  ;// get the font shape from the pin
            mov eax, [ebx].color    ;// get the color from the pin
            SHAPE_TO_MASK esi, ebx  ;// load the mask from font
            invoke shape_Fill

        ;// that's it
            call_depth = 0

            retn








    ;// TFB     triangle    font    bus
    ALIGN 16
    gdi_render_pin_out1_TFB::

            DEBUG_IF < app_CircuitSettings & CIRCUIT_NOPINS >   ;// added ABox231

        ;// outline the bus

            PIN_TO_TSHAPE ebx, ecx  ;// get the shape
            PIN_TO_DEST ebx, edi    ;// get the destination
            mov eax, [ebx].color    ;// use pin's color
            add edi, [ecx].p7       ;// add the offset from t0
            SHAPE_TO_OUT1 shape_bus, ebx ;// load the outliner
            invoke shape_Fill
            GET_PIN st_pin, ebx

        ;// exit to TF routine

            jmp gdi_render_pin_out1_TF      ;// jump to TF


    ;// LFB     logic   font    bus
    ALIGN 16
    gdi_render_pin_out1_LFB::

            DEBUG_IF < app_CircuitSettings & CIRCUIT_NOPINS >   ;// added ABox231

        ;// outline the bus

            PIN_TO_TSHAPE ebx, ecx  ;// get the shape
            PIN_TO_DEST ebx, edi    ;// load the destination
            mov eax, [ebx].color    ;// use pin's color
            add edi, [ecx].p6       ;// add the desired offset
            SHAPE_TO_OUT1 shape_bus, ebx    ;// load the outliner

            invoke shape_Fill
            GET_PIN st_pin, ebx

        ;// exit to LF

            jmp gdi_render_pin_out1_LF



    ;// FB      font    bus
    ALIGN 16
    gdi_render_pin_out1_FB::

            DEBUG_IF < app_CircuitSettings & CIRCUIT_NOPINS >   ;// added ABox231

        ;// outline the bus

            PIN_TO_TSHAPE ebx, ecx      ;// get the shape
            PIN_TO_DEST ebx, edi        ;// load the destination
            mov eax, [ebx].color        ;// use pin's color
            add edi, [ecx].p5           ;// add the desired offset
            SHAPE_TO_OUT1 shape_bus, ebx;// load the outliner
            invoke shape_Fill
            GET_PIN st_pin, ebx

        ;// exit to FS

            jmp gdi_render_pin_out1_FS




    ;// TF      triangle    font
    ;// TFS     triangle    font    spline
    ALIGN 16
    gdi_render_pin_out1_TFS::
    gdi_render_pin_out1_TF::

            DEBUG_IF < app_CircuitSettings & CIRCUIT_NOPINS >   ;// added ABox231

        ;// outline the font

            PIN_TO_TSHAPE ebx, ecx  ;// get our triangle shape
            PIN_TO_DEST ebx, edi    ;// load the destination
            mov eax, [ebx].color    ;// use pin's color
            add edi, [ecx].p4       ;// add appropriate offset
            SHAPE_TO_OUT1 shape_pin_font, ebx   ;// load the outliner
            invoke shape_Fill
            GET_PIN st_pin, ebx     ;// reload the pin

        ;// outline the triangle

            PIN_TO_TSHAPE ebx, ecx  ;// get our triangle shape
            mov eax, [ebx].color    ;// use the pins color
            PIN_TO_DEST ebx, edi    ;// get our_dest
            SHAPE_TO_OUT1 ecx, ebx  ;// load out1 from triangle
            invoke shape_Fill

        ;// done

            jmp gdi_render_pin_out1_done


    ;// FT      font    triangle
    ALIGN 16
    gdi_render_pin_out1_FT::

            DEBUG_IF < app_CircuitSettings & CIRCUIT_NOPINS >   ;// added ABox231

        ;// outline the font

            PIN_TO_TSHAPE ebx, ecx  ;// get our triangle shape
            PIN_TO_DEST ebx, edi    ;// load the destination
            mov eax, [ebx].color    ;// use pin's color
            add edi, [ecx].p8       ;// add appropriate offset
            SHAPE_TO_OUT1 shape_pin_font, ebx   ;// load the outliner
            invoke shape_Fill

            GET_PIN st_pin, ebx     ;// reload the pin

        ;// outline the triangle

            PIN_TO_TSHAPE ebx, ecx  ;// load the riangle shape
            PIN_TO_DEST ebx, edi    ;// load the destination
            mov eax, [ebx].color    ;// use the pins color
            add edi, [ecx].p9       ;// add the desired offset
            SHAPE_TO_OUT1 ecx, ebx  ;// load out1 from triangle
            invoke shape_Fill

        ;// exit

            jmp gdi_render_pin_out1_done







    ;// LFS     logic   font    spline
    ;// LF      logic   font
    ALIGN 16
    gdi_render_pin_out1_LF::
    gdi_render_pin_out1_LFS::

            DEBUG_IF < app_CircuitSettings & CIRCUIT_NOPINS >   ;// added ABox231

        ;// outline the font

            PIN_TO_TSHAPE ebx, ecx  ;// load our triangle's shape
            PIN_TO_DEST ebx, edi    ;// load the destination
            mov eax, [ebx].color    ;// use pin's color
            add edi, [ecx].p3       ;// add appropriate offset
            SHAPE_TO_OUT1 shape_pin_font, ebx   ;// load the outliner
            invoke shape_Fill
            GET_PIN st_pin, ebx     ;// reload the pin

        ;// outline the logic shape

            PIN_TO_TSHAPE ebx, ecx  ;// get our triangle shape
            PIN_TO_DEST ebx, edi    ;// load our dest
            PIN_TO_LSHAPE ebx, esi  ;// load the logic shape
            add edi, [ecx].p1       ;// add appropriate offset (always p1)
            mov eax, [ebx].color    ;// load correct color
            SHAPE_TO_OUT1 esi, ebx  ;// load the outliner
            invoke shape_Fill

        ;// that's it

            jmp gdi_render_pin_out1_done



    ;// FS      font    connection line
    ALIGN 16
    gdi_render_pin_out1_FS::

            DEBUG_IF < app_CircuitSettings & CIRCUIT_NOPINS >   ;// added ABox231

        ;// outline the font

            PIN_TO_TSHAPE ebx, ecx  ;// get our triangle shape
            PIN_TO_DEST ebx, edi    ;// load the destination
            mov eax, [ebx].color    ;// use pin's color
            add edi, [ecx].p2       ;// add appropriate offset
            SHAPE_TO_OUT1 shape_pin_font, ebx   ;// load the outliner

            invoke shape_Fill

        ;// exit

            jmp gdi_render_pin_out1_done










    ;// TFB     triangle    font    bus
    ALIGN 16
    gdi_render_pin_out1_bus_TFB::

            DEBUG_IF < app_CircuitSettings & CIRCUIT_NOPINS >   ;// added ABox231

        ;// outline the bus

            PIN_TO_TSHAPE ebx, ecx  ;// get the shape
            PIN_TO_DEST ebx, edi    ;// get the destination
            mov eax, [ebx].color    ;// use pin's color
            add edi, [ecx].p7       ;// add the offset from t0
            SHAPE_TO_OUT1 shape_bus, ebx ;// load the outliner
            invoke shape_Fill

        ;// exit

            jmp gdi_render_pin_out1_bus_done


    ;// LFB     logic   font    bus
    ALIGN 16
    gdi_render_pin_out1_bus_LFB::

            DEBUG_IF < app_CircuitSettings & CIRCUIT_NOPINS >   ;// added ABox231

        ;// outline the bus

            PIN_TO_TSHAPE ebx, ecx  ;// get the shape
            PIN_TO_DEST ebx, edi    ;// load the destination
            mov eax, [ebx].color    ;// use pin's color
            add edi, [ecx].p6       ;// add the desired offset
            SHAPE_TO_OUT1 shape_bus, ebx    ;// load the outliner

            invoke shape_Fill

        ;// exit

            jmp gdi_render_pin_out1_bus_done



    ;// FB      font    bus
    ALIGN 16
    gdi_render_pin_out1_bus_FB::

            DEBUG_IF < app_CircuitSettings & CIRCUIT_NOPINS >   ;// added ABox231

        ;// outline the bus

            PIN_TO_TSHAPE ebx, ecx      ;// get the shape
            PIN_TO_DEST ebx, edi        ;// load the destination
            mov eax, [ebx].color        ;// use pin's color
            add edi, [ecx].p5           ;// add the desired offset
            SHAPE_TO_OUT1 shape_bus, ebx;// load the outliner
            invoke shape_Fill

        ;// exit

            jmp gdi_render_pin_out1_bus_done




































;////////////////////////////////////////////////////////////////////
;//
;//     gdi_render_pin_conn
;//
;// if input pin:
;//     make sure that our output isn't going to draw us anyways
;//     then draw the spline
;// if output pin:
;//     draw all splines
;//     turn off the render bits in the input pins
;//
ALIGN 16
gdi_render_pin_conn:

        DEBUG_IF < app_CircuitSettings & CIRCUIT_NOPINS >   ;// added ABox231

        ASSUME ebx:PTR APIN

    ;// get the first connection
    ;// if we are an input pin
        GET_PIN [ebx].pPin, esi
        or esi, esi
        jz gdi_render_pin_conn_done ;// it happens, even though it's not supposed to

        test [ebx].dwStatus, PIN_OUTPUT
        jnz ebx_is_output

    ebx_is_input:

        ;// if our outpin pin has RENDER_CONN set
        ;// AND if our output pin is in the I list
        ;// the SKIP

        .IF [esi].dwHintPin & HINTPIN_RENDER_CONN

            PIN_TO_OSC esi, ecx
            xor eax, eax
            dlist_IfMember_jump oscI, ecx, gdi_render_pin_conn_done, [ebp]

        .ENDIF

        xchg esi, ebx

        .IF !([ebx].dwHintPin & HINTPIN_STATE_VALID_DEST)

            invoke pin_Layout_points

        .ENDIF


        ;// determine sp_1 and sp_2

        point_CopyTo [ebx].t1, spline_point_1
        point_CopyTo [ebx].t2, spline_point_2

        invoke gdi_render_spline
        jmp gdi_render_pin_conn_done

    ALIGN 16
    ebx_is_output:      ;// scan the input pins

    ;// determine sp_1 and sp_2

        point_CopyTo [ebx].t1, spline_point_1
        point_CopyTo [ebx].t2, spline_point_2

    B1: or esi, esi
        jz gdi_render_pin_conn_done

        and [esi].dwHintPin, NOT HINTPIN_RENDER_CONN    ;// reset the RENDER_CONN bit
        invoke gdi_render_spline
        mov esi, [esi].pData

        jmp B1

;//
;////////////////////////////////////////////////////////////////////



gdi_Render ENDP
;///
;///    G D I _ R E N D E R
;///
;///
;////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////


;// jump tables

.DATA

    gdi_render_pin_assy_jump LABEL DWORD

    dd  OFFSET  gdi_render_pin_assy_done;// error
    dd  OFFSET  gdi_render_pin_assy_TFB ;// bussed analog input
    dd  OFFSET  gdi_render_pin_assy_TFS ;// connected analog input
    dd  OFFSET  gdi_render_pin_assy_TF  ;// unconnected analog input
    dd  OFFSET  gdi_render_pin_assy_LFB ;// bussed logic input
    dd  OFFSET  gdi_render_pin_assy_LFS ;// connected logic input
    dd  OFFSET  gdi_render_pin_assy_LF  ;// unconnected logic input
    dd  OFFSET  gdi_render_pin_assy_FB  ;// bussed output
    dd  OFFSET  gdi_render_pin_assy_FS  ;// connected output
    dd  OFFSET  gdi_render_pin_assy_FT  ;// unconnected output

    gdi_render_pin_out1_jump LABEL DWORD

    dd  OFFSET  gdi_render_pin_out1_done;// error
    dd  OFFSET  gdi_render_pin_out1_TFB ;// bussed analog input
    dd  OFFSET  gdi_render_pin_out1_TFS ;// connected analog input
    dd  OFFSET  gdi_render_pin_out1_TF  ;// unconnected analog input
    dd  OFFSET  gdi_render_pin_out1_LFB ;// bussed logic input
    dd  OFFSET  gdi_render_pin_out1_LFS ;// connected logic input
    dd  OFFSET  gdi_render_pin_out1_LF  ;// unconnected logic input
    dd  OFFSET  gdi_render_pin_out1_FB  ;// bussed output
    dd  OFFSET  gdi_render_pin_out1_FS  ;// connected output
    dd  OFFSET  gdi_render_pin_out1_FT  ;// unconnected output

    gdi_render_pin_out1_bus_jump LABEL DWORD

    dd  OFFSET  gdi_render_pin_out1_bus_done;// error
    dd  OFFSET  gdi_render_pin_out1_bus_TFB ;// bussed analog input
    dd  OFFSET  gdi_render_pin_out1_bus_done;// connected analog input
    dd  OFFSET  gdi_render_pin_out1_bus_done;// unconnected analog input
    dd  OFFSET  gdi_render_pin_out1_bus_LFB ;// bussed logic input
    dd  OFFSET  gdi_render_pin_out1_bus_done;// connected logic input
    dd  OFFSET  gdi_render_pin_out1_bus_done;// unconnected logic input
    dd  OFFSET  gdi_render_pin_out1_bus_FB  ;// bussed output
    dd  OFFSET  gdi_render_pin_out1_bus_done;// connected output
    dd  OFFSET  gdi_render_pin_out1_bus_done;// unconnected output



.CODE






;////////////////////////////////////////////////////////////////////
;//
;//
;//     gdi_render_osc          default OSC_BASE member function
;//


ASSUME_AND_ALIGN
gdi_render_osc PROC

        ASSUME esi:PTR OSC_OBJECT
        ASSUME edi:PTR OSC_BASE

    ;// process the render bits for this osc

    push esi

        mov ebx, [esi].dwHintOsc

        st_osc  TEXTEQU <(DWORD PTR [esp])>

        DEBUG_IF <!!(ebx & HINTOSC_STATE_ONSCREEN)> ;// not spoosed to be here

    ;// HINTOSC_RENDER_MASK

        btr ebx, LOG2(HINTOSC_RENDER_MASK)
        .IF CARRY?

            RENDER_TRACE HINTOSC_RENDER_MASK

            mov [esi].dwHintOsc, ebx    ;// store the flags

            OSC_TO_DEST esi, edi        ;// get the destination
            OSC_TO_CONTAINER esi, ebx   ;// get the container
            CONTAINER_TO_MASK ebx, ebx  ;// get the mask
            OSC_TO_SOURCE esi, esi      ;// get the blit source
            invoke shape_Move

            mov esi, st_osc             ;// retrieve esi
            mov ebx, [esi].dwHintOsc    ;// retrieve hint2

        .ENDIF

    ;// HINTOSC_RENDER_OUT1     HOVER

        btr ebx, LOG2(HINTOSC_RENDER_OUT1)
        .IF CARRY?

            RENDER_TRACE HINTOSC_RENDER_OUT1

            mov [esi].dwHintOsc, ebx    ;// store the flags
            mov eax, F_COLOR_OSC_HOVER  ;// use the osc hover color

            OSC_TO_CONTAINER esi, ebx   ;// get the container
            OSC_TO_DEST esi, edi        ;// get the destination
            CONTAINER_TO_OUT1 ebx, ebx  ;// get the outliner

            invoke shape_Fill

            mov esi, st_osc             ;// retrieve esi
            mov ebx, [esi].dwHintOsc    ;// retrieve hint2

            inc gdi_bBlitFull           ;// set the 'drew an osc flag'

        .ENDIF

    ;// HINTOSC_RENDER_OUT2         SELECT and LOCK

        btr ebx, LOG2(HINTOSC_RENDER_OUT2)
        .IF CARRY?

            RENDER_TRACE HINTOSC_RENDER_OUT2

            ;// determine the correct color
            ;// select takes priority over lock

            bt ebx, LOG2(HINTOSC_STATE_HAS_SELECT)
            .IF CARRY?
                mov eax, F_COLOR_DESK_SELECTED
            .ELSE
                mov eax, F_COLOR_DESK_LOCKED
            .ENDIF

            mov [esi].dwHintOsc, ebx    ;// store the flags

            OSC_TO_CONTAINER esi, ebx   ;// get the container
            OSC_TO_DEST esi, edi        ;// get the destination
            CONTAINER_TO_OUT2 ebx, ebx  ;// get the outliner
            invoke shape_Fill

            mov esi, st_osc             ;// retrieve esi
            mov ebx, [esi].dwHintOsc    ;// retrieve hint2

            inc gdi_bBlitFull           ;// set the 'drew an osc flag'

        .ENDIF

    ;// HINTOSC_RENDER_OUT3

        btr ebx, LOG2(HINTOSC_RENDER_OUT3)
        .IF CARRY?

            RENDER_TRACE HINTOSC_RENDER_OUT3

            mov [esi].dwHintOsc, ebx    ;// store the flags

            ;// determine color
            bt ebx, LOG2(HINTOSC_STATE_HAS_BAD)
            mov eax, F_COLOR_DESK_GROUPED
            .IF CARRY?
            mov eax, F_COLOR_DESK_BAD
            .ENDIF

            OSC_TO_CONTAINER esi, ebx   ;// get the container
            OSC_TO_DEST esi, edi        ;// get the destination
            CONTAINER_TO_OUT3 ebx, ebx  ;// get the outliner
            invoke shape_Fill

            mov esi, st_osc             ;// retrieve esi
            mov ebx, [esi].dwHintOsc    ;// retrieve hint2

            inc gdi_bBlitFull           ;// set the 'drew an osc flag'

        .ENDIF

    ;// HINTOSC_RENDER_CLOCKS

        bt ebx, LOG2(HINTOSC_RENDER_CLOCKS)
        .IF CARRY?

            RENDER_TRACE HINTOSC_RENDER_CLOCKS

            mov [esi].dwHintOsc, ebx    ;// store the flags
            invoke clocks_Render        ;// call the render function
            mov ebx, [esi].dwHintOsc    ;// retrieve hint2

        ;// inc gdi_bBlitFull           ;// set the 'drew an osc flag'

        .ENDIF

    ;// that's it

    pop esi

        OSC_TO_BASE esi, edi

        or gdi_bHasRendered, 1  ;// objects may allocate fonts while rendering
                                ;// so we need to set this flag
        ret

gdi_render_osc  ENDP




ASSUME_AND_ALIGN
gdi_render_spline PROC

        ASSUME ebx:PTR APIN ;// must be OUTPUT pin  preserved
        ASSUME esi:PTR APIN ;// must be INPUT pin   preserved

        DEBUG_IF <[esi].pPin !!= ebx>   ;// supposed to be connected

        DEBUG_IF < app_CircuitSettings & CIRCUIT_NOPINS >   ;// added ABox231

    ;// sp1 and sp2 must already be set

        or gdi_bHasRendered, 1  ;// an osc.render that allocates shapes may have turned this off

    ;// make sure the destination is valid

        .IF !([esi].dwHintPin & HINTPIN_STATE_VALID_DEST)
            xchg esi, ebx
            push edi
            invoke pin_Layout_points
            pop edi
            xchg esi, ebx
        .ENDIF

    ;// build sp_4

        point_CopyTo [esi].t1, spline_point_4, eax, ecx

    ;// check if t1 is too closed to t4

        sub eax, spline_point_1.x
        sub ecx, spline_point_1.y

        mul eax
        xchg eax, ecx
        mul eax
        add ecx, eax

        .IF ecx > pin_min_line      ;// less than min line ?

        ;// have to draw something

            point_CopyTo [esi].t2, spline_point_3, edx, ecx ;// finish building the points

        ;// determine the color, using the source pin's color

            mov eax, [ebx].color        ;// load the pin color
            and eax, 0FFh               ;// strip out the rest
            sub eax, COLOR_LOWEST_PIN   ;// move back to an index

        ;// determine if we draw a thick or a thin line

            .IF app_settings.show & SHOW_CHANGING   && \
                [ebx].dwHintPin & HINTPIN_STATE_THICK

                GDI_DC_SELECT_RESOURCE hPen_3, eax

            .ELSE

                GDI_DC_SELECT_RESOURCE hPen_1, eax

            .ENDIF

        ;// draw the spline

            invoke PolyBezier, gdi_hDC, OFFSET spline_point_1, 4

        .ENDIF

        ret

gdi_render_spline ENDP


ASSUME_AND_ALIGN


END




