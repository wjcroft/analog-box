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
;//     ABOX242 AJT -- detabified + text adjustments for 'lines too long' errors
;//
;//##////////////////////////////////////////////////////////////////////////
;//
;// Gdi_invalidate.asm      routines for scheduling rendering
;//

;//
;// TOC:
;//
;// public
;//
;//     gdi_osc_BuildRenderFlags
;//     gdi_pin_BuildRenderFlags
;//     gdi_BlitSelRect
;//     gdi_EraseMouseConnect
;//
;// private
;//
;//     gdi_build_boundry_rect
;//     gdi_test_on_screen
;//     gdi_Erase_this_point
;//     gdi_Erase_rect
;//     gdi_Blit_point
;//     gdi_Blit_this_point
;//     gdi_Blit_rect
;//     gdi_pin_SetJIndex
;//
;// public
;//
;//     gdi_Invalidate

OPTION CASEMAP:NONE

.586
.MODEL FLAT

        .NOLIST
        include <Abox.inc>
        include <triangles.inc>
        include <gdi_pin.inc>
        .LIST

.DATA


    ;// MAIN WINDOW INVALIDATION

        gdi_erase_rect  RECT {} ;// erase rect
        gdi_blit_rect   RECT {} ;// blit rect

    ;// these tell us if either of the above rects has something in it
    ;// use gdi_Erase_rect  gdi_Blt_rect
    ;//     gdi_Erase_point gdi_Blit_point

        gdi_bEraseValid  db 0   ;// erase rect is valid
        gdi_bBlitValid   db 0   ;// blit rect is valid
        gdi_bErasePoint  db 0   ;// if on, the add bezier radius to the erase rect
        gdi_bBlitPoint   db 0   ;// if on, the add bezier radius to the blit rect


.CODE




;///////////////////////////////////////////////////////////////////////
;//
;//     public
;//     helper routines
;//                             gdi_pin_SetColor
;//                             gdi_osc_BuildRenderFlags
;//                             gdi_pin_BuildRenderFlags
;//                             gdi_EraseMouseConnect
;//

PROLOGUE_OFF
ASSUME_AND_ALIGN
gdi_pin_set_color PROC STDCALL dwHintI:DWORD

    ;// this function sets all the pin colors

    ;// eax must have a packed color or be zero

        DEBUG_IF < al !!= ah >  ;// eax is not packed !!

    ;// store the packed color in the pin,
    ;// then invalidate it

    ;// the dwHintI value may contain extra invalidate flags
    ;// the values will be applied to all pins in the chain
    ;// needed by the mouse for efficiency

    ;// uses eax, ecx, edx

        ASSUME ebx:PTR APIN
        ASSUME ebp:PTR LIST_CONTEXT

    ;// stack
    ;// ret dwHintI
    ;// 00  04

        st_hinti TEXTEQU <(DWORD PTR [esp+4])>

        xor edx, edx        ;// must be zero

        or edx, [ebx].pPin  ;// load and test the pin's connection
        mov ecx, eax        ;// xfer packed color to ecx
        jz not_connected    ;// jump to oher routine if not connected

    ;// update_all_connections:

        xchg esi, st_hinti  ;// save esi and get the passed flags from the stack

        push ebx

        or esi, HINTI_PIN_UPDATE_COLOR  ;// merge on the set color flag

        .IF !([ebx].dwStatus & PIN_OUTPUT)  ;// ebx must be the output pin
            mov ebx, edx
        .ENDIF

        mov [ebx].color, ecx        ;// set the color

        GDI_INVALIDATE_PIN esi      ;// schedule for redraw

        mov ebx, [ebx].pPin         ;// get first pin in chain

        .REPEAT
            mov [ebx].color, ecx    ;// set the color
            GDI_INVALIDATE_PIN esi  ;// schedule for update
            xor edx, edx            ;// clear for testing
            or edx, [ebx].pData     ;// get next pin in chain
            mov ebx, edx            ;// xfer pointers now
        .UNTIL ZERO?                ;// do until done

    pop ebx

    mov esi, st_hinti   ;// retieve esi

all_done:

        ret 4

    not_connected:

        mov eax, st_hinti
        mov [ebx].color, ecx    ;// set the color
        or eax, HINTI_PIN_UPDATE_COLOR
        GDI_INVALIDATE_PIN eax  ;// schedule for redraw
        jmp all_done

gdi_pin_set_color ENDP
PROLOGUE_ON


PROLOGUE_OFF
ASSUME_AND_ALIGN
gdi_pin_reset_color PROC STDCALL dwHintI:DWORD

    ;// this function resets all the pin colors

    ;// the dwHintI value may contain extra invalidate flags
    ;// the values will be applied to all pins in the chain
    ;// needed by the mouse for efficiency

    ;// uses eax, ecx, edx

        ASSUME ebx:PTR APIN
        ASSUME ebp:PTR LIST_CONTEXT

    ;// stack
    ;// ret dwHintI
    ;// 00  04

        st_hinti TEXTEQU <(DWORD PTR [esp+4])>

        xor edx, edx        ;// start with zero
        or edx, [ebx].pPin  ;// load and test the pin's connection
        jz not_connected    ;// jump to oher routine if not connected

    ;// update_all_connections:

        xchg esi, st_hinti  ;// save esi and get the passed flags from the stack

        push ebx

        or esi, HINTI_PIN_UPDATE_COLOR  ;// merge on the set color flag

        .IF !([ebx].dwStatus & PIN_OUTPUT)  ;// ebx must be the output pin
            mov ebx, edx
        .ENDIF

        PIN_TO_UNIT_COLOR ebx, eax
        mov [ebx].color, eax        ;// set the color

        GDI_INVALIDATE_PIN esi      ;// schedule for redraw

        mov ebx, [ebx].pPin         ;// get first pin in chain

        .REPEAT

            PIN_TO_UNIT_COLOR ebx, eax  ;// get the color
            mov [ebx].color, eax        ;// set the color

            GDI_INVALIDATE_PIN esi  ;// schedule for update
            xor edx, edx            ;// clear for testing
            or edx, [ebx].pData     ;// get next pin in chain
            mov ebx, edx            ;// xfer pointers now

        .UNTIL ZERO?                ;// do until done

    pop ebx

    mov esi, st_hinti   ;// retieve esi

all_done:

        ret 4

    not_connected:

        PIN_TO_UNIT_COLOR ebx, eax
        mov ecx, st_hinti
        mov [ebx].color, eax    ;// set the color
        or ecx, HINTI_PIN_UPDATE_COLOR
        GDI_INVALIDATE_PIN ecx  ;// schedule for redraw
        jmp all_done

gdi_pin_reset_color ENDP
PROLOGUE_ON









ASSUME_AND_ALIGN
gdi_osc_BuildRenderFlags    PROC

    ;// edi must have the dwHintOsc flags
    ;// this builds the render flags in edi
    ;// but does NOT store them

        xor eax, eax
        bt edi, LOG2(HINTOSC_RENDER_MASK)
        rcl eax, LOG2(HINTOSC_RENDER_CALL_BASE)+1
        or edi, eax

        xor eax, eax
        bt edi, LOG2(HINTOSC_STATE_HAS_HOVER)
        rcl eax, LOG2(HINTOSC_RENDER_OUT1)+1
        or edi, eax

        xor eax, eax
        bt edi, LOG2(HINTOSC_STATE_HAS_LOCK_HOVER)
        rcl eax, LOG2(HINTOSC_RENDER_OUT2)+1
        or edi, eax

        xor eax, eax
        bt edi, LOG2(HINTOSC_STATE_HAS_SELECT)
        rcl eax, LOG2(HINTOSC_RENDER_OUT2)+1
        or edi, eax

        xor eax, eax
        bt edi, LOG2(HINTOSC_STATE_HAS_BAD)
        rcl eax, LOG2(HINTOSC_RENDER_OUT3)+1
        or edi, eax

        xor eax, eax
        bt edi, LOG2(HINTOSC_STATE_HAS_GROUP)
        rcl eax, LOG2(HINTOSC_RENDER_OUT3)+1
        or edi, eax

        .IF app_settings.show & SHOW_CLOCKS &&  \
            play_status & PLAY_PLAYING

            ;// this is wrong!
            ;// we need to check if item is supposed to show clocks

            or edi, HINTOSC_RENDER_CLOCKS

        .ENDIF

    ret

gdi_osc_BuildRenderFlags    ENDP



ASSUME_AND_ALIGN
gdi_pin_BuildRenderFlags    PROC

    ;// this builds the render flags in ecx
    ;// but does NOT store them
    ;// ecx should enter as APIN.dwHintPin

    ;// uses eax

        ASSUME ebx:PTR APIN
        ASSUME esi:PTR OSC_OBJECT

        DEBUG_IF <( [ebx].pObject !!= esi )>    ;// esi:ebx are supposed to be osc:pin

    ;// DEBUG_IF <( ecx !!= [ebx].dwHintPin )>  ;// supposed enter as dwHintPin

    xor eax, eax
    or eax, [esi].dwHintOsc ;// test on screen
    .IF SIGN?

            mov eax, [ebx].j_index

            jmp hintpin_build_render_jump[eax*4]

        ALIGN 16
        hintpin_build_render_LF::   ;// unconnected logic input
        hintpin_build_render_TF::   ;// unconnected analog input
        hintpin_build_render_FT::   ;// unconnected output

            ;// not connected, not hidden
            ;// if showing_pins OR pin_down then render_assy

            test [esi].dwHintOsc, HINTOSC_STATE_SHOW_PINS
            jnz hintpin_build_render_FB
            cmp ebx, pin_down
            je hintpin_build_render_FB

            jmp hintpin_build_render_done

        ALIGN 16
        hintpin_build_render_TFS::  ;// connected analog input
        hintpin_build_render_LFS::  ;// connected logic input
        hintpin_build_render_FS::   ;// connected output

            or ecx, HINTPIN_RENDER_CONN

        hintpin_build_render_TFB::  ;// bussed analog input
        hintpin_build_render_LFB::  ;// bussed logic input
        hintpin_build_render_FB::   ;// bussed output

            or ecx, HINTPIN_RENDER_ASSY

        hintpin_build_render_done:: ;// or hidden pin (ignore)

            ;// then do the out1 bits
            xor eax, eax

            test ecx, HINTPIN_STATE_HAS_HOVER OR HINTPIN_STATE_HAS_DOWN
            .IF !ZERO?
                or ecx, HINTPIN_RENDER_OUT1
            .ENDIF

            bt ecx, LOG2(HINTPIN_STATE_HAS_BUS_HOVER)
            rcl eax, LOG2(HINTPIN_RENDER_OUT1_BUS)+1
            or ecx, eax

    .ELSE

        and ecx, NOT HINTPIN_RENDER_TEST

    .ENDIF

    ;// that's it

        ret

gdi_pin_BuildRenderFlags    ENDP


ASSUME_AND_ALIGN
gdi_BlitSelRect PROC

        gdi_Blit_rect PROTO ;// defined below
        gdi_Erase_rect PROTO    ;// defined below

        lea eax, mouse_selrect
        invoke gdi_Erase_rect
        ret

gdi_BlitSelRect ENDP



ASSUME_AND_ALIGN
gdi_EraseMouseConnect PROC

        gdi_Erase_this_point PROTO  ;// defined below

        point_Get mouse_now         ;// we need mouse now regardless where we end up
        invoke gdi_Erase_this_point
        point_Get mouse_prev        ;// we also need to clean up the previous display
        invoke gdi_Erase_this_point

    ;// then we need to erase all the t2 points
    ;// determine the connecting mode based on the j_index of pin down

        GET_PIN pin_down, ecx
        DEBUG_IF <!!ecx>            ;// supposed to be set

    ;// alway erase pin down

        point_Get [ecx].t1
        invoke gdi_Erase_this_point
        point_Get [ecx].t2
        invoke gdi_Erase_this_point

    ;// then we process the j_index to determine the mode

        mov eax, [ecx].j_index
        jmp mouse_connecting_jump[eax*4]

    ALIGN 16
    mouse_connecting_TFS::  ;// connected analog input
    mouse_connecting_LFS::  ;// connected logic input

        ;// we are MOVING an input connection
        ;// so we draw from the source pin to mouse now

        .IF ![ecx].pPin     ;// no source pin
                            ;// happens after we've moved it
            mov ecx, pin_hover

            point_Get [ecx].t1
            invoke gdi_Erase_this_point
            point_Get [ecx].t2
            invoke gdi_Erase_this_point

            test [ecx].dwStatus, PIN_OUTPUT ;// see if we are output
            jnz mouse_connecting_FS         ;// jump now if so
            mov ecx, [ecx].pPin             ;// load the source pin

            point_Get [ecx].t1
            invoke gdi_Erase_this_point
            point_Get [ecx].t2
            invoke gdi_Erase_this_point

            jmp mouse_connecting_FS         ;// jump to other routine

        .ENDIF

        mov ecx, [ecx].pPin     ;// get the source pin
        ;// fall into next section

    mouse_connecting_TF::   ;// unconnected analog input
    mouse_connecting_LF::   ;// unconnected logic input
    mouse_connecting_FT::   ;// unconnected output

        ;// are to CONNECT a pin
        ;// so we draw from pin.t1, t2 to mouse now

            point_Get [ecx].t1
            invoke gdi_Erase_this_point
            point_Get [ecx].t2
            invoke gdi_Erase_this_point

            jmp mouse_connecting_done

    ALIGN 16
    mouse_connecting_FS::   ;// connected output

        ;// we are MOVING an output
        ;// so we draw ALL the splines from each INPUT pin

            mov ecx, [ecx].pPin
            .WHILE ecx

                point_Get [ecx].t1
                invoke gdi_Erase_this_point
                point_Get [ecx].t2
                invoke gdi_Erase_this_point

                mov ecx, [ecx].pData

            .ENDW

            jmp mouse_connecting_done


    ALIGN 16
    mouse_connecting_hide:: ;// hidden
    mouse_connecting_TFB::  ;// bussed analog input
    mouse_connecting_LFB::  ;// bussed logic input
    mouse_connecting_FB::   ;// bussed output

        ;// we are MOVING a bus connection
        ;// so we want to show the bus circle ??

        point_Get mouse_now
        sub eax, PIN_BUS_RADIUS
        sub edx, PIN_BUS_RADIUS
        invoke gdi_Erase_this_point

        add eax, PIN_BUS_RADIUS * 2
        add edx, PIN_BUS_RADIUS * 2
        invoke gdi_Erase_this_point

        point_Get mouse_prev
        sub eax, PIN_BUS_RADIUS
        sub edx, PIN_BUS_RADIUS
        invoke gdi_Erase_this_point

        add eax, PIN_BUS_RADIUS * 2
        add edx, PIN_BUS_RADIUS * 2
        invoke gdi_Erase_this_point

        jmp mouse_connecting_done

    ALIGN 16
    mouse_connecting_done:

        rect_Inflate gdi_erase_rect     ;// add a small amount so things get erased ok

        ret


gdi_EraseMouseConnect ENDP


.DATA

    hintpin_build_render_jump   LABEL DWORD

        dd  OFFSET  hintpin_build_render_done;// hidden (ignore)
        dd  OFFSET  hintpin_build_render_TFB ;// bussed analog input
        dd  OFFSET  hintpin_build_render_TFS ;// connected analog input
        dd  OFFSET  hintpin_build_render_TF  ;// unconnected analog input
        dd  OFFSET  hintpin_build_render_LFB ;// bussed logic input
        dd  OFFSET  hintpin_build_render_LFS ;// connected logic input
        dd  OFFSET  hintpin_build_render_LF  ;// unconnected logic input
        dd  OFFSET  hintpin_build_render_FB  ;// bussed output
        dd  OFFSET  hintpin_build_render_FS  ;// connected output
        dd  OFFSET  hintpin_build_render_FT  ;// unconnected output

    mouse_connecting_jump   LABEL DWORD

        dd  OFFSET  mouse_connecting_hide;// hidden (ignore)
        dd  OFFSET  mouse_connecting_TFB ;// bussed analog input
        dd  OFFSET  mouse_connecting_TFS ;// connected analog input
        dd  OFFSET  mouse_connecting_TF  ;// unconnected analog input
        dd  OFFSET  mouse_connecting_LFB ;// bussed logic input
        dd  OFFSET  mouse_connecting_LFS ;// connected logic input
        dd  OFFSET  mouse_connecting_LF  ;// unconnected logic input
        dd  OFFSET  mouse_connecting_FB  ;// bussed output
        dd  OFFSET  mouse_connecting_FS  ;// connected output
        dd  OFFSET  mouse_connecting_FT  ;// unconnected output

.CODE


;//
;//     public
;//     helper routines
;//                             gdi_pin_SetColor
;//                             gdi_osc_BuildRenderFlags
;//                             gdi_pin_BuildRenderFlags
;//                             gdi_EraseMouseConnect
;//
;///////////////////////////////////////////////////////////////////////










;////////////////////////////////////////////////////////////////////
;//
;//                         gdi_build_boundry_rect
;//     private             gdi_test_on_screen
;//     helper routines     gdi_erase_point
;//                         gdi_erase_rect
;//                         gdi_blit_point
;//                         gdi_blit_rect
;//                         gdi_pin_SetJIndex


ASSUME_AND_ALIGN
gdi_build_boundry_rect PROC

    ;// uses eax, ebx, ecx, edx, edi

    ;// task, determine the outside most items
    ;// and set those as this object's boundry

    ;// to be able to do this,
    ;//     pin layout must have been called (all pins must have jump index and triangle)
    ;//     hint2 must have all the correct bits set as well


    ;// need 4 registers
    ;// eax, edx    TL      use min macros
    ;// ecx, edi    BR      use max macros

        ASSUME esi:PTR OSC_OBJECT

    ;// step 1
    ;//
    ;//     determine an osc boundry bassed on the osc.rect and what ever outline is showing

        point_GetTL [esi].rect
        mov ebx, [esi].dwHintOsc
        point_GetBR [esi].rect, ecx, edi

        and ebx,    HINTOSC_STATE_HAS_HOVER         OR  \
                    HINTOSC_STATE_HAS_CON_HOVER     OR  \
                    HINTOSC_STATE_HAS_LOCK_HOVER    OR  \
                    HINTOSC_STATE_HAS_SELECT        OR  \
                    HINTOSC_STATE_HAS_LOCK_SELECT   OR  \
                    HINTOSC_STATE_HAS_BAD           OR  \
                    HINTOSC_STATE_HAS_GROUP

        jz set_the_rect ;// use object rect if no outlines

        test ebx,   HINTOSC_STATE_HAS_BAD   OR  \
                    HINTOSC_STATE_HAS_GROUP
        jz J0
            mov ebx, 6
            jmp adjust_the_rect

    J0: test ebx,   HINTOSC_STATE_HAS_LOCK_SELECT   OR  \
                    HINTOSC_STATE_HAS_LOCK_HOVER    OR  \
                    HINTOSC_STATE_HAS_SELECT
        jz J1
            mov ebx, 3
            jmp adjust_the_rect

    J1: mov ebx, 1  ;// has to be HOVER or CON_HOVER

    adjust_the_rect:
    set_the_rect:

        inc ebx

        sub eax, ebx
        sub edx, ebx
        add ecx, ebx
        add edi, ebx


        .IF app_settings.show & SHOW_CLOCKS &&  \
            play_status & PLAY_PLAYING
            sub edx, CLOCKS_RECT_HEIGHT
        .ENDIF

        point_SetTL [esi].boundry
        point_SetBR [esi].boundry, ecx, edi

    ;// step two:
    ;//
    ;//     account for pins
    ;//

    scan_the_pins:

        xor eax, eax    ;// clear for testing

        .IF [esi].dwHintOsc & HINTOSC_STATE_SHOW_PINS

            ;// scan all the pins

            ITERATE_PINS

                ;// use the jump index to do this
                ;// we want to get a pointer to the rect to compare to

                    or eax, [ebx].j_index       ;// load and test the jump index
                    jz gdi_build_boundry1_hide  ;// skip if hidden

                ;// choose r1 or r2

                    PIN_TO_TSHAPE ebx, ecx

                    jmp gdi_build_boundry1_jump[eax*4]

                ALIGN 16
                gdi_build_boundry1_FT:: ;// unconnected output

                    ;// backwards

                    point_Get [ebx].t0
                    point_Sub [ecx].t3

                    dec edx ;// adjust 1 pixel ?

                    cmp eax, [esi].boundry.left
                    jge H1
                    mov [esi].boundry.left, eax
                H1: cmp edx, [esi].boundry.top
                    jge H2
                    mov [esi].boundry.top, edx
                H2: cmp eax, [esi].boundry.right
                    jle H3
                    mov [esi].boundry.right, eax
                H3: cmp edx, [esi].boundry.bottom
                    jle G8
                    mov [esi].boundry.bottom, edx
                    jmp G8

                gdi_build_boundry1_TFB::    ;// bussed analog input
                gdi_build_boundry1_LFB::    ;// bussed logic input
                gdi_build_boundry1_FB::     ;// bussed output

                    add ecx, SIZEOF RECT    ;// test with r2

                gdi_build_boundry1_TFS::    ;// connected analog input
                gdi_build_boundry1_TF::     ;// unconnected analog input
                gdi_build_boundry1_LFS::    ;// connected logic input
                gdi_build_boundry1_LF::     ;// unconnected logic input
                gdi_build_boundry1_FS::     ;// connected output

                    lea ecx, [ecx].r1
                    ASSUME ecx:PTR RECT

                    point_GetTL [ecx]
                    point_Add [ebx].t0

                    cmp eax, [esi].boundry.left
                    jge G5
                    mov [esi].boundry.left, eax
                G5: cmp edx, [esi].boundry.top
                    jge G6
                    mov [esi].boundry.top, edx

                G6: point_GetBR [ecx]
                    point_Add [ebx].t0

                    cmp eax, [esi].boundry.right
                    jle G7
                    mov [esi].boundry.right, eax
                G7: cmp edx, [esi].boundry.bottom
                    jle G8
                    mov [esi].boundry.bottom, edx

                G8: xor eax, eax    ;// clear for testing

                gdi_build_boundry1_hide::

            PINS_ITERATE

            inc [esi].boundry.bottom

        .ELSE

            xor eax, eax

            ITERATE_PINS

                ;// use the jump index to do this
                ;// we want to get a pointer to the rect to compare to

                or eax, [ebx].j_index       ;// load and test teh jump index
                jz gdi_build_boundry2_hide  ;// skip if hidden

                ;// choose r1 or r2

                PIN_TO_TSHAPE ebx, ecx
                lea ecx, [ecx].r1           ;// r1
                ASSUME ecx:PTR RECT

                jmp gdi_build_boundry2_jump[eax*4]

                gdi_build_boundry2_TFB::    ;// bussed analog input
                gdi_build_boundry2_LFB::    ;// bussed logic input
                gdi_build_boundry2_FB::     ;// bussed output

                    add ecx, SIZEOF RECT    ;// r2

                gdi_build_boundry2_TFS::    ;// connected analog input
                gdi_build_boundry2_LFS::    ;// connected logic input
                gdi_build_boundry2_FS::     ;// connected output

                    point_GetTL [ecx]
                    point_Add [ebx].t0

                    cmp eax, [esi].boundry.left
                    jge G1
                    mov [esi].boundry.left, eax
                G1: cmp edx, [esi].boundry.top
                    jge G2
                    mov [esi].boundry.top, edx
                G2: point_GetBR [ecx]
                    point_Add [ebx].t0
                    cmp eax, [esi].boundry.right
                    jle G3
                    mov [esi].boundry.right, eax
                G3: cmp edx, [esi].boundry.bottom
                    jle G4
                    mov [esi].boundry.bottom, edx
                G4:
                gdi_build_boundry2_FT:: ;// unconnected output
                gdi_build_boundry2_TF:: ;// unconnected analog input
                gdi_build_boundry2_LF:: ;// unconnected logic input

                    xor eax, eax        ;// clear for testing

                gdi_build_boundry2_hide::

            PINS_ITERATE

        .ENDIF

        ret

gdi_build_boundry_rect ENDP




.DATA

    gdi_build_boundry1_jump LABEL DWORD

        dd  OFFSET  gdi_build_boundry1_hide ;// time to set
        dd  OFFSET  gdi_build_boundry1_TFB  ;// bussed analog input
        dd  OFFSET  gdi_build_boundry1_TFS  ;// connected analog input
        dd  OFFSET  gdi_build_boundry1_TF   ;// unconnected analog input
        dd  OFFSET  gdi_build_boundry1_LFB  ;// bussed logic input
        dd  OFFSET  gdi_build_boundry1_LFS  ;// connected logic input
        dd  OFFSET  gdi_build_boundry1_LF   ;// unconnected logic input
        dd  OFFSET  gdi_build_boundry1_FB   ;// bussed output
        dd  OFFSET  gdi_build_boundry1_FS   ;// connected output
        dd  OFFSET  gdi_build_boundry1_FT   ;// unconnected output

    gdi_build_boundry2_jump LABEL DWORD

        dd  OFFSET  gdi_build_boundry2_hide ;// time to set
        dd  OFFSET  gdi_build_boundry2_TFB  ;// bussed analog input
        dd  OFFSET  gdi_build_boundry2_TFS  ;// connected analog input
        dd  OFFSET  gdi_build_boundry2_TF   ;// unconnected analog input
        dd  OFFSET  gdi_build_boundry2_LFB  ;// bussed logic input
        dd  OFFSET  gdi_build_boundry2_LFS  ;// connected logic input
        dd  OFFSET  gdi_build_boundry2_LF   ;// unconnected logic input
        dd  OFFSET  gdi_build_boundry2_FB   ;// bussed output
        dd  OFFSET  gdi_build_boundry2_FS   ;// connected output
        dd  OFFSET  gdi_build_boundry2_FT   ;// unconnected output

.CODE





MAX_OSC_BORDER_X    EQU 64
MAX_OSC_BORDER_Y    EQU 64



ASSUME_AND_ALIGN
gdi_test_on_screen PROC

        ;// this simply inflates the osc's rect by the maximum it can be
        ;// then determines if any part of that is on the screen

        ;// sets or clears the ONSCREEN BIT in EDI
        ;// returns results in the sign flag as well

        ASSUME esi:PTR OSC_OBJECT
        ;// uses eax, edx

        point_GetTL [esi].rect      ;// get the osc rect
        point_Sub MAX_OSC_BORDER    ;// scoot in by max border

        cmp eax, gdi_client_rect.right
        jg not_on_screen
        cmp edx, gdi_client_rect.bottom
        jg not_on_screen

        point_GetBR [esi].rect
        point_Add MAX_OSC_BORDER

        cmp eax, gdi_client_rect.left
        jl not_on_screen
        cmp edx, gdi_client_rect.top
        jl not_on_screen

    yes_on_screen:

        ;// very important that we build our pdest

        GDI_RECTTL_TO_GDI_ADDRESS [esi].rect, edx
        mov [esi].pDest, edx

        or edi, HINTOSC_STATE_ONSCREEN
        ret

    not_on_screen:

        and edi, NOT HINTOSC_STATE_ONSCREEN
        ret

gdi_test_on_screen ENDP





ASSUME_AND_ALIGN
gdi_Erase_this_point PROC

    ;// this adds the point to the erase rect
    ;// it does not actually erase it

    ;// call this version when eax and edx are already loaded

    DEBUG_IF <!!eax && !!edx>   ;// zero point !!

    cmp gdi_bEraseValid, 0
    je new_point

    old_point:  rect_UnionXY gdi_erase_rect

    all_done:   or gdi_bErasePoint, 1

                ret

    new_point:  point_SetTL gdi_erase_rect
                point_SetBR gdi_erase_rect
                inc gdi_bEraseValid
                jmp all_done

gdi_Erase_this_point ENDP





ASSUME_AND_ALIGN
gdi_Erase_rect PROC ;// PRIVATE

    ;// this adds the rect to the erase rect
    ;// it does not actually erase it

    ;// uses ecx and edx

    ASSUME eax:PTR RECT

    IFDEF DEBUGBUILD

        point_GetTL [eax], ecx, edx
        DEBUG_IF <!!ecx && !!edx>   ;// zero point !!

        point_GetBR [eax], ecx, edx
        DEBUG_IF <!!ecx && !!edx>   ;// zero point !!

    ENDIF


    cmp gdi_bEraseValid, 0
    je new_point

    old_point:  rect_UnionRect gdi_erase_rect, [eax], ecx, edx

    all_done:   ret

    new_point:  rect_CopyTo [eax], gdi_erase_rect, ecx, edx
                inc gdi_bEraseValid
                jmp all_done

gdi_Erase_rect ENDP





ASSUME_AND_ALIGN
gdi_Blit_this_point PROC

    ;// this adds the point to the blit rect
    ;// it does not actually blit it

    ;// call this version when eax and edx are already loaded

    DEBUG_IF <!!eax && !!edx>   ;// zero point !!

    cmp gdi_bBlitValid, 0
    je new_point

    old_point:  rect_UnionXY gdi_blit_rect

    all_done:   or gdi_bBlitPoint, 1

                ret

    new_point:  point_SetTL gdi_blit_rect
                point_SetBR gdi_blit_rect
                inc gdi_bBlitValid
                jmp all_done


gdi_Blit_this_point ENDP


ASSUME_AND_ALIGN
gdi_Blit_rect PROC

    ;// this adds the rect to the blit rect
    ;// it does not actually blit it

    ;// uses ecx and edx

    ASSUME eax:PTR RECT

    IFDEF DEBUGBUILD

        point_GetTL [eax], ecx, edx
        DEBUG_IF <!!ecx && !!edx>   ;// zero point !!

        point_GetBR [eax], ecx, edx
        DEBUG_IF <!!ecx && !!edx>   ;// zero point !!

    ENDIF

    cmp gdi_bBlitValid, 0
    je new_rect

    old_rect:   rect_UnionRect gdi_blit_rect, [eax], ecx, edx

    all_done:   ret

    new_rect:   rect_CopyTo [eax], gdi_blit_rect, ecx, edx
                inc gdi_bBlitValid
                jmp all_done

gdi_Blit_rect ENDP






;////////////////////////////////////////////////////////////////////
;//
;//                             ebx must point at pin
;//     gdi_pin_SetJIndex       sets [ebx].j_index and returns in eax
;//                             always returns a valid value
;//
;// determine the jump index for this pin
;// jump indexes range from 0 to 9 (nine total)
;// with zero always being a skip command (hidden pin)
;//
;//     order is always:
;//
;// 0   hidden  ---uses---
;// 1   TFB     bussed analog input
;// 2   TFS     connected analog input
;// 3   TF      unconnected analog (in or out)
;// 4   LFB     bussed logic input
;// 5   LFS     connected logic input
;// 6   LF      unconnected logic input
;// 7   FB      bussed output
;// 8   FS      connected output
;// 9   FT      unconnected output

comment ~ /*

    the following table states the valid assumptions for any of the nine states


                1       2       3       4       5       6       7       8       9
                TFB     TFS     TF      LFB     LFS     LF      FB      FS      FT
draw/hittest    -----   -----   -----   -----   -----   -----   -----   -----   -----

T   triangle    yes     yes     yes                                             yes(p8)
L   logic                               yes     yes     yes
B   bus         yes                     yes                     yes
S   spline              yes                     yes                     yes

    hit rect    r2      r1      r1      r2      r1      r1      r2      r1      r1

offset to use   -----   -----   -----   -----   -----   -----   -----   -----   -----

T                                                                               p8
L   dpLogic                             p1      p1      p1
F   dpFont      p4      p4      p4      p3      p3      p3      p2      p2      p4
B   dpBus       p7                      p6                      p5

spline points   -----   -----   -----   -----   -----   -----   -----   -----   -----

S   spline1             t3                      t2                      t1
S   spline2             t3+t4                   t2+t4                   t1+t4

assume that:    -----   -----   -----   -----   -----   -----   -----   -----   -----

B   pBShape     valid                   valid                   valid
L   pLShape                     valid   valid   valid   valid

    pPin        valid   valid   0       valid   valid   0       ???     valid
B   bus index   valid                   valid                   valid


code template, replace xxx with function name

xxx_hide::  ;// hidden pin (ignore)
xxx_TFB::   ;// bussed analog input
xxx_TFS::   ;// connected analog input
xxx_TF::    ;// unconnected analog input
xxx_LFB::   ;// bussed logic input
xxx_LFS::   ;// connected logic input
xxx_LF::    ;// unconnected logic input
xxx_FB::    ;// bussed output
xxx_FS::    ;// connected output
xxx_FT::    ;// unconnected output

data template, replace xxx with function name

.DATA

xxx_jump    LABEL DWORD

    dd  OFFSET  xxx_hide;// hidden (ignore)
    dd  OFFSET  xxx_TFB ;// bussed analog input
    dd  OFFSET  xxx_TFS ;// connected analog input
    dd  OFFSET  xxx_TF  ;// unconnected analog input
    dd  OFFSET  xxx_LFB ;// bussed logic input
    dd  OFFSET  xxx_LFS ;// connected logic input
    dd  OFFSET  xxx_LF  ;// unconnected logic input
    dd  OFFSET  xxx_FB  ;// bussed output
    dd  OFFSET  xxx_FS  ;// connected output
    dd  OFFSET  xxx_FT  ;// unconnected output

.CODE

*/ comment ~


.DATA

    pin_j_index_connected   LABEL BYTE  ;// table of yes no values

    pin_j_index_connected_hide  db  0   ;// EQU 0 hidden
    pin_j_index_connected_TFB   db  1   ;// EQU 1 bussed analog input
    pin_j_index_connected_TFS   db  1   ;// EQU 2 connected analog input
    pin_j_index_connected_TF    db  0   ;// EQU 3 unconnected analog (in or out)
    pin_j_index_connected_LFB   db  1   ;// EQU 4 bussed logic input
    pin_j_index_connected_LFS   db  1   ;// EQU 5 connected logic input
    pin_j_index_connected_LF    db  0   ;// EQU 6 unconnected logic input
    pin_j_index_connected_FB    db  1   ;// EQU 7 bussed output
    pin_j_index_connected_FS    db  1   ;// EQU 8 connected output
    pin_j_index_connected_FT    db  0   ;// EQU 9 unconnected output
    ALIGN 4

.CODE

;////////////////////////////////////////////////////////////////////
;//
;//
;//     gdi_pin_SetJIndex       uses eax, that's all
;//
ASSUME_AND_ALIGN
gdi_pin_SetJIndex PROC

        ASSUME ebx:PTR APIN

        mov eax, [ebx].dwStatus
        bt eax, LOG2(PIN_HIDDEN)        ;// hidden ?
        jc sj09

sj00:   test eax, PIN_BUS_TEST          ;// bussed ?
        jz sj03

        bt eax, LOG2(PIN_LOGIC_INPUT)   ;// bussed, logic input ?
        jnc sj01

            mov eax, 4                  ; bussed, logic input
            jmp sj10

sj01:   bt eax, LOG2(PIN_OUTPUT)        ;// bussed, output pin ?
        jnc sj02

            mov eax, 7                  ; bussed ouput
            jmp sj10

sj02:       mov eax, 1                  ; bussed analog input
            jmp sj10

ALIGN 16
sj03:   cmp [ebx].pPin, 0               ;// not bussed, connected ?
        jz sj06

        bt eax, LOG2(PIN_LOGIC_INPUT)   ;// not bussed, connected, logic input ?
        jnc sj04

            mov eax, 5                  ; connected, logic input
            jmp sj10

sj04:   bt eax, LOG2(PIN_OUTPUT)        ;// not bussed, not logic, connected, output pin ?
        jnc sj05

            mov eax, 8                  ; connected output pin
            jmp sj10

sj05:       mov eax, 2                  ; connected analog input pin
            jmp sj10

ALIGN 16
sj06:   bt eax, LOG2(PIN_LOGIC_INPUT)   ;// not connected, not bussed, logic input ?
        jnc sj07

            mov eax, 6                  ; unconnected logic input
            jmp sj10

sj07:   bt eax, LOG2(PIN_OUTPUT)        ;// not connected, not a logic input, output ?
        jc sj08

            mov eax, 3                  ; unconnected analog input
            jmp sj10

sj08:       mov eax, 9                  ; unconnected output
            jmp sj10

ALIGN 16
sj09:   xor eax, eax    ;// hidden
        jmp sj10


;// now we know what we are

ALIGN 16
sj10:   mov [ebx].j_index, eax

        ret

gdi_pin_SetJIndex ENDP

;//
;//
;//     gdi_pin_SetJIndex
;//
;////////////////////////////////////////////////////////////////////


;//
;//                         gdi_build_boundry_rect
;//     private             gdi_test_on_screen
;//     helper routines     gdi_Erase_point
;//                         gdi_Erase_rect
;//                         gdi_Blit_point
;//                         gdi_Blit_rect
;//                         gdi_pin_SetJIndex
;//
;////////////////////////////////////////////////////////////////////













comment ~ /*

    here we go again,

    the gdi render engine is composed of three parts

    an invalidator that queues commands

    a command flusher that converts the commands into render state and render commands

    a renderer that processes all the bits

    SO: use GDI_INVALIDATE_OSC flag to que an object for redisplay
        at the end of the WM handler, call gdi_Invalidate or app_Sync
        WM_PAINT will do the rest

*/ comment ~







comment ~ /*

    THIS TABLE IS NOT CORRECT
    USE ONLY FOR OVERVIEW


                    gdi_Invalidate actions                          gdi_Render actions
                    process in order (left to right)

                            call                                    locate  call
osc                 erase   gui.    update  do      update  blit    covered gui.    draw    draw
action              boundry SetShp  OnScrn  pins    boundry boundry erase   Render  shape   pins
------------------- ------- ------- ------- ------- ------- ------- ------- ------- ------- -------

create              no      yes     yes     yes     yes             no      yes     yes     yes

set shape           maybe   yes     no      maybe   maybe   yes     maybe   yes     yes     maybe

move                yes     no      yes     yes     yes             yes     yes     yes     yes

update clocks       no      no      no      no      no              no      no      no      no

show pins           no      no      no      yes     yes             no      no      no      yes

hide pins           yes     no      no      yes     yes     yes     yes     yes     yes     yes

got osc hover       no      no      no      no      yes     yes     no      no      no      no
lost osc hover      yes     no      no      yes     yes     yes     yes     yes     yes     yes

got control hover   no      no      no      no      no      yes     no      yes     yes     no
lost control hover  no      no      no      no      no      yes     no      yes     yes     no

got select          no      no      no      no      yes     yes     no      no      no      no
lost select         yes     no      no      yes     yes     yes     yes     yes     yes     yes

got lock            no      no      no      no      yes     yes     no      no      no      no
lost lock           yes     no      no      yes     yes     yes     yes     yes     yes     yes

got group           no      no      no      no      yes     yes     no      no      no      no
lost group          yes     no      no      yes     yes     yes     yes     yes     yes     yes

got bad             no      no      no      no      yes     yes     no      no      no      no
lost bad            yes     no      no      yes     yes     yes     yes     yes     yes     yes

pin connect         yes     no      no      yes     yes     yes     yes     no      no      yes
pin unconnect       yes     no      no      yes     yes     yes     yes     no      no      yes


    scan all the osc in the list
    process flags
    remove items from list if nessesary


inval command       gdi flag
------------------- -------------------------

update clocks
                    draw clocks

show pins
hide pins
                    showing pins

got osc hover
lost osc hover
                    show out1   hover color

got osc down
lost osc down

got control hover
lost control hover

got control down
lost control down


got select
lost select
                    show out2   select color or hover color

got lock
lost lock
                    show out2   lock color or select color or hover color

got group
lost group
                    show out3   group color

got bad
lost bad            show out3   bad color group color

pin connect
pin unconnect


    lock, select, and hover

    hover shows out 1, so it's ok
    if a locked osc is hovered, it's other items get out2 set as the hover color
    if a locked osc is selected, it's other items get out 2 set as the select color
    if a locked osc is moved (osc down), it's other out2's get the hover color

    we really need a central function to do these
    then they can do the invalidate's as well

    gdi_SetOscHover ptr or zero
    gdi_SetOscDown  ptr or zero
    gdi_SetPinHover ptr or zero
    gdi_SetPinDown  ptr or zero


OSC_MOVE must tell all connections that they've moved
OSC_MOVE_SCREEN does not have to tell connections


------------------------------------------------------------------------------------------------

                                                    draw
                    erase   erase   pin     why     pin     draw
pin action          boundry conect  layout          assy    connect


pin connected       no      no      yes     connect yes     yes
pin unconnected     yes     no      yes     default no      no

get pin hover       no      no      no              yes     yes
loose pin hover     yes     no      no              yes     yes

get pin down        no              no              yes     yes
loose pin down      yes             no              yes     yes

pin move (auto)     yes     yes     yes     pheta   yes     yes
pin move (osc)      no      yes     yes     o-move  yes     yes

redraw (changing)   no      maybe   no              no      yes
redraw (color)      no      no      no              yes     yes

make hidden                         no
hide
make unhidden                       no

*/ comment ~


;// INVAL_USE_TRACE EQU 1

IFDEF INVAL_USE_TRACE

.DATA

    INVAL_TRACE MACRO name:req

        pushad

        invoke wsprintfA, ADDR inval_buf, ADDR inval_fmt, ADDR sz_&name
        invoke OutputDebugStringA, ADDR inval_buf

        popad

        ENDM

    inval_buf db 128 dup (0)
    inval_fmt db "inval %s",0dh,0ah,0
    inval_rect db "inval %i,%i, %i,%i",0dh,0ah,0

    sz_LINEFEED                   db 0dh, 0ah, 0

    sz_HINTI_OSC_CREATED          db 'HINTI_OSC_CREATED',0
    sz_HINTI_OSC_SHAPE_CHANGED    db 'HINTI_OSC_SHAPE_CHANGED',0
    sz_HINTI_OSC_MOVED            db 'HINTI_OSC_MOVED',0
    sz_HINTI_OSC_MOVE_SCREEN      db 'HINTI_OSC_MOVE_SCREEN',0

    sz_HINTI_OSC_GOT_SELECT       db 'HINTI_OSC_GOT_SELECT',0
    sz_HINTI_OSC_LOST_SELECT      db 'HINTI_OSC_LOST_SELECT',0

    sz_HINTI_OSC_GOT_BAD      db 'HINTI_OSC_GOT_BAD',0
    sz_HINTI_OSC_LOST_BAD     db 'HINTI_OSC_LOST_BAD',0

    sz_HINTI_OSC_SHOW_PINS        db 'HINTI_OSC_SHOW_PINS',0
    sz_HINTI_OSC_HIDE_PINS        db 'HINTI_OSC_HIDE_PINS',0

    sz_HINTI_OSC_GOT_HOVER        db 'HINTI_OSC_GOT_HOVER',0
    sz_HINTI_OSC_LOST_HOVER       db 'HINTI_OSC_LOST_HOVER',0

    sz_HINTI_OSC_GOT_CON_HOVER    db 'HINTI_OSC_GOT_CON_HOVER',0
    sz_HINTI_OSC_LOST_CON_HOVER   db 'HINTI_OSC_LOST_CON_HOVER',0

    sz_HINTI_OSC_GOT_LOCK_HOVER   db 'HINTI_OSC_GOT_LOCK_HOVER',0
    sz_HINTI_OSC_LOST_LOCK_HOVER   db 'HINTI_OSC_LOST_LOCK_HOVER',0

    sz_HINTI_OSC_GOT_BUS_HOVER    db 'HINTI_OSC_GOT_BUS_HOVER',0
    sz_HINTI_OSC_LOST_BUS_HOVER   db 'HINTI_OSC_LOST_BUS_HOVER',0

    sz_HINTI_OSC_GOT_LOCK_SELECT      db 'HINTI_OSC_GOT_LOCK_SELECT',0
    sz_HINTI_OSC_LOST_LOCK_SELECT   db 'HINTI_OSC_LOST_LOCK_SELECT',0

    sz_HINTI_OSC_GOT_DOWN         db 'HINTI_OSC_GOT_DOWN',0
    sz_HINTI_OSC_LOST_DOWN        db 'HINTI_OSC_LOST_GROUP',0

    sz_HINTI_OSC_GOT_GROUP        db 'HINTI_OSC_GOT_GROUP',0
    sz_HINTI_OSC_LOST_GROUP       db 'HINTI_OSC_LOST_DOWN',0

    sz_HINTI_OSC_GOT_CON_DOWN     db 'HINTI_OSC_GOT_CON_DOWN',0
    sz_HINTI_OSC_LOST_CON_DOWN    db 'HINTI_OSC_LOST_CON_DOWN',0

    sz_HINTI_PIN_GOT_HOVER        db '  HINTI_PIN_GOT_HOVER',0
    sz_HINTI_PIN_LOST_HOVER       db '  HINTI_PIN_LOST_HOVER',0

    sz_HINTI_PIN_GOT_BUS_HOVER        db '  HINTI_PIN_GOT_BUS_HOVER',0
    sz_HINTI_PIN_LOST_BUS_HOVER       db '  HINTI_PIN_LOST_BUS_HOVER',0

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
    sz_HINTI_PIN_UPDATE_PROBE     db '  HINTI_PIN_UPDATE_PROBE',0
    sz_HINTI_PIN_CONNECTED        db '  HINTI_PIN_CONNECTED',0
    sz_HINTI_PIN_UNCONNECTED      db '  HINTI_PIN_UNCONNECTED',0

    sz_HINTOSC_INVAL_TEST_ONSCREEN      db 'HINTOSC_INVAL_TEST_ONSCREEN',0
    sz_HINTOSC_INVAL_UPDATE_BOUNDRY     db 'HINTOSC_INVAL_UPDATE_BOUNDRY',0
    sz_HINTOSC_INVAL_DO_PINS            db 'HINTOSC_INVAL_DO_PINS',0
;// sz_HINTOSC_INVAL_DO_PINS_LAYOUT     db 'HINTOSC_INVAL_DO_PINS_LAYOUT',0
;// sz_HINTOSC_INVAL_DO_PINS_SHOW       db 'HINTOSC_INVAL_DO_PINS_SHOW',0
;// sz_HINTOSC_INVAL_DO_PINS_UPDATE     db 'HINTOSC_INVAL_DO_PINS_UPDATE',0
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
    sz_HINTOSC_RENDER_OUT2              db 'HINTOSC_RENDER_OUT2',0
    sz_HINTOSC_STATE_HAS_LOCK           db 'HINTOSC_STATE_HAS_LOCK',0
    sz_HINTOSC_STATE_HAS_SELECT         db 'HINTOSC_STATE_HAS_SELECT',0
    sz_HINTOSC_RENDER_OUT3              db 'HINTOSC_RENDER_OUT3',0
    sz_HINTOSC_STATE_HAS_GROUP          db 'HINTOSC_STATE_HAS_GROUP',0
    sz_HINTOSC_STATE_HAS_BAD            db 'HINTOSC_STATE_HAS_BAD',0
    sz_HINTOSC_RENDER_CLOCKS            db 'HINTOSC_RENDER_CLOCKS',0
    sz_HINTOSC_STATE_SHOW_PINS          db 'HINTOSC_STATE_SHOW_PINS',0
    sz_HINTOSC_STATE_HAS_DOWN           db 'HINTOSC_STATE_HAS_DOWN',0

    sz_HINTOSC_INVAL_CREATED            db 'HINTOSC_INVAL_CREATED',0
    sz_HINTOSC_INVAL_REMOVE             db 'HINTOSC_INVAL_REMOVE',0

    sz_HINTOSC_STATE_SETS_EXTENTS       db 'HINTOSC_STATE_SETS_EXTENTS',0
    sz_HINTOSC_STATE_ONSCREEN           db 'HINTOSC_STATE_ONSCREEN',0

    sz_HINTPIN_RENDER_ASSY              db '  HINTPIN_RENDER_ASSY',0
    sz_HINTPIN_RENDER_OUT1              db '  HINTPIN_RENDER_OUT1',0
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



ELSE    ;// use inval tracing

    INVAL_TRACE MACRO name:req

        ENDM

ENDIF   ;// use inval tracing










;///////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////
;//                                                         public function
;//
;//     gdi_Invalidate
;//
;// the purpose of this function is to:
;//
;// 1) process all the accumulated bits in osc's and pins
;// 2) accumulate the erase and blit rect
;// 3) call win32.InvalidateRect
;//
;//
;// targets for gdi_Invalidate HINTI handlers:
;//
;//     gdi_blit_rect and gdi_erase_rect
;//     gdi_Render command bits
;//     dwHintOsc and dwHintPin state bits
;//
ASSUME_AND_ALIGN
gdi_Invalidate PROC


    ;// check for empty I list

    stack_Peek gui_context, ecx
    dlist_GetHead oscI, ecx, [ecx]

    .IF ecx     ;// anything to process ??

        ;// enter the function

        push ebp
        push esi
        push ebx
        push edi

        stack_Peek gui_context, ebp      ;// get the context
        dlist_GetHead oscI, esi, [ebp]   ;// get start of I list

;////////////////////////////////////////////////////////////////////
;//
;//
;//     process the I list
;//

    .REPEAT

    ;// part one:   process the accumulated commands
    ;//
    ;// the task of this section is to convert the passed commands into
    ;// commands for the next section

        mov edi, [esi].dwHintI      ;// edi is the command
        mov ecx, [esi].dwHintOsc    ;// ecx is the state we're maintaining



    ;// HINTI_OSC_CREATED                   ;// this osc has just been created

        btr edi, LOG2(HINTI_OSC_CREATED)
        .IF CARRY?

            INVAL_TRACE HINTI_OSC_CREATED

            or ecx, HINTOSC_INVAL_TEST_ONSCREEN     OR  \
                    HINTOSC_INVAL_UPDATE_BOUNDRY    OR  \
                    HINTOSC_INVAL_BLIT_BOUNDRY      OR  \
                    HINTOSC_RENDER_MASK             OR  \
                    HINTOSC_INVAL_DO_PINS_JUMP      OR  \
                    HINTOSC_INVAL_CREATED

            ;// we'll call set shape now
            ;// otherwise the osc.rect will not be correct

            mov [esi].dwHintI, edi  ;// store the hintI flags
            mov [esi].dwHintOsc, ecx;// store the hintOsc flags
            OSC_TO_BASE esi, edi
            invoke [edi].gui.SetShape
            mov ecx, [esi].dwHintOsc
            mov edi, [esi].dwHintI

            ;// then we have to layout all the pins

            mov eax, HINTPIN_INVAL_LAYOUT_SHAPE ;// tell all pins to layout
            ITERATE_PINS
            or [ebx].dwHintPin, eax
            PINS_ITERATE

        .ENDIF

    ;// HINTI_OSC_SHAPE_CHANGED             ;// call set_shape before rebuilding boundry

        btr edi, LOG2(HINTI_OSC_SHAPE_CHANGED)
        .IF CARRY?

            INVAL_TRACE HINTI_OSC_SHAPE_CHANGED

            OSC_TO_BASE esi, edx

            or ecx, HINTOSC_RENDER_MASK     OR \
                    HINTOSC_INVAL_BLIT_RECT OR \
                    HINTOSC_INVAL_BUILD_RENDER

            .IF [edx].data.dwFlags & BASE_SHAPE_EFFECTS_GEOMETRY

                or ecx, HINTOSC_INVAL_SET_SHAPE         OR \
                        HINTOSC_INVAL_UPDATE_BOUNDRY    OR \
                        HINTOSC_INVAL_TEST_ONSCREEN     OR \
                        HINTOSC_INVAL_BLIT_BOUNDRY      OR \
                        HINTOSC_INVAL_ERASE_BOUNDRY

                ;// then make suree all the pins get layed out

                mov eax, HINTPIN_INVAL_LAYOUT_SHAPE OR  \
                         HINTPIN_INVAL_ERASE_CONN   OR  \
                         HINTPIN_INVAL_BLIT_CONN
                ITERATE_PINS
                or [ebx].dwHintPin, eax
                PINS_ITERATE

                or app_bFlags, APP_SYNC_GROUP

            .ENDIF

        .ENDIF









    ;// HINTI_OSC_MOVED                     ;// the osc has moved

        btr edi, LOG2(HINTI_OSC_MOVED)
        .IF CARRY?

            INVAL_TRACE HINTI_OSC_MOVED

            or ecx, HINTOSC_INVAL_ERASE_BOUNDRY     OR  \
                    HINTOSC_INVAL_UPDATE_BOUNDRY    OR  \
                    HINTOSC_INVAL_BLIT_BOUNDRY      OR  \
                    HINTOSC_RENDER_MASK             OR  \
                    HINTOSC_INVAL_BUILD_RENDER      OR  \
                    HINTOSC_INVAL_TEST_ONSCREEN

            mov eax,HINTPIN_INVAL_BUILD_RENDER  OR  \
                    HINTPIN_INVAL_ERASE_CONN    OR  \
                    HINTPIN_INVAL_LAYOUT_POINTS OR  \
                    HINTPIN_INVAL_BLIT_CONN

            ITERATE_PINS
            or [ebx].dwHintPin, eax
            PINS_ITERATE

            or app_bFlags, APP_SYNC_GROUP

        .ENDIF


    ;// HINTI_OSC_MOVE_SCREEN               ;// all the oscs have moved

        btr edi, LOG2(HINTI_OSC_MOVE_SCREEN)
        .IF CARRY?

            INVAL_TRACE HINTI_OSC_MOVE_SCREEN

            or ecx, HINTOSC_INVAL_UPDATE_BOUNDRY    OR  \
                    HINTOSC_INVAL_TEST_ONSCREEN     OR  \
                    HINTOSC_RENDER_MASK             OR  \
                    HINTOSC_INVAL_BUILD_RENDER

        .ENDIF





    ;// HINTI_OSC_GOT_SELECT                ;// this osc has been selected

        btr edi, LOG2(HINTI_OSC_GOT_SELECT)
        .IF CARRY?

            INVAL_TRACE HINTI_OSC_GOT_SELECT

            or ecx, HINTOSC_STATE_HAS_SELECT        OR  \
                    HINTOSC_RENDER_MASK             OR  \
                    HINTOSC_INVAL_UPDATE_BOUNDRY    OR  \
                    HINTOSC_INVAL_BLIT_BOUNDRY      OR  \
                    HINTOSC_INVAL_BUILD_RENDER

            btr edi, LOG2(HINTI_OSC_LOST_SELECT)

        .ENDIF


    ;// HINTI_OSC_LOST_SELECT               ;// this osc is no longer selected

        btr edi, LOG2(HINTI_OSC_LOST_SELECT)
        .IF CARRY?

            INVAL_TRACE HINTI_OSC_LOST_SELECT

            and ecx, NOT HINTOSC_STATE_HAS_SELECT

            or ecx, HINTOSC_INVAL_ERASE_BOUNDRY     OR  \
                    HINTOSC_INVAL_UPDATE_BOUNDRY    OR  \
                    HINTOSC_RENDER_MASK             OR  \
                    HINTOSC_INVAL_BUILD_RENDER

        .ENDIF





    ;// HINTI_OSC_GOT_HOVER

        btr edi, LOG2(HINTI_OSC_GOT_HOVER)
        .IF CARRY?

            btr edi, LOG2(HINTI_OSC_LOST_HOVER)

            INVAL_TRACE HINTI_OSC_GOT_HOVER

            or ecx, HINTOSC_INVAL_BLIT_BOUNDRY      OR  \
                    HINTOSC_STATE_HAS_HOVER         OR  \
                    HINTOSC_INVAL_UPDATE_BOUNDRY    OR  \
                    HINTOSC_INVAL_BUILD_RENDER

            or edi, HINTI_OSC_SHOW_PINS ;// must also show pins

        .ENDIF


    ;// HINTI_OSC_LOST_HOVER

        btr edi, LOG2(HINTI_OSC_LOST_HOVER)
        .IF CARRY?

            INVAL_TRACE HINTI_OSC_LOST_HOVER

            and ecx, NOT HINTOSC_STATE_HAS_HOVER

            or ecx, HINTOSC_INVAL_BLIT_BOUNDRY      OR  \
                    HINTOSC_INVAL_ERASE_BOUNDRY     OR  \
                    HINTOSC_INVAL_UPDATE_BOUNDRY    OR  \
                    HINTOSC_RENDER_MASK             OR  \
                    HINTOSC_INVAL_BUILD_RENDER

        .ENDIF







    ;// HINTI_OSC_GOT_CON_HOVER

        btr edi, LOG2(HINTI_OSC_GOT_CON_HOVER)
        .IF CARRY?

            INVAL_TRACE HINTI_OSC_GOT_CON_HOVER

            btr edi, LOG2(HINTI_OSC_LOST_CON_HOVER)

            or ecx, HINTOSC_STATE_HAS_CON_HOVER     OR  \
                    HINTOSC_INVAL_UPDATE_BOUNDRY    OR  \
                    HINTOSC_INVAL_BLIT_BOUNDRY      OR  \
                    HINTOSC_RENDER_MASK             OR  \
                    HINTOSC_INVAL_BUILD_RENDER

        .ENDIF


    ;// HINTI_OSC_LOST_CON_HOVER

        btr edi, LOG2(HINTI_OSC_LOST_CON_HOVER)
        .IF CARRY?

            INVAL_TRACE HINTI_OSC_LOST_CON_HOVER

            and ecx, NOT HINTOSC_STATE_HAS_CON_HOVER

            or ecx, HINTOSC_INVAL_ERASE_BOUNDRY     OR  \
                    HINTOSC_INVAL_UPDATE_BOUNDRY    OR  \
                    HINTOSC_INVAL_BLIT_BOUNDRY      OR  \
                    HINTOSC_INVAL_BUILD_RENDER
        .ENDIF


    ;// HINTI_OSC_GOT_LOCK_HOVER

        btr edi, LOG2(HINTI_OSC_GOT_LOCK_HOVER)
        .IF CARRY?

            INVAL_TRACE HINTI_OSC_GOT_LOCK_HOVER

            or ecx, HINTOSC_STATE_HAS_LOCK_HOVER    OR  \
                    HINTOSC_INVAL_UPDATE_BOUNDRY    OR  \
                    HINTOSC_INVAL_BLIT_BOUNDRY      OR  \
                    HINTOSC_INVAL_BUILD_RENDER

        .ENDIF


    ;// HINTI_OSC_LOST_LOCK_HOVER

        btr edi, LOG2(HINTI_OSC_LOST_LOCK_HOVER)
        .IF CARRY?

            INVAL_TRACE HINTI_OSC_LOST_LOCK_HOVER

            and ecx, NOT HINTOSC_STATE_HAS_LOCK_HOVER
            or ecx, HINTOSC_INVAL_ERASE_BOUNDRY     OR  \
                    HINTOSC_INVAL_UPDATE_BOUNDRY    OR  \
                    HINTOSC_INVAL_BLIT_BOUNDRY      OR  \
                    HINTOSC_INVAL_BUILD_RENDER

        .ENDIF





    ;// HINTI_OSC_GOT_CON_DOWN

        btr edi, LOG2(HINTI_OSC_GOT_CON_DOWN)
        .IF CARRY?

            INVAL_TRACE HINTI_OSC_GOT_CON_DOWN

        .ENDIF


    ;// HINTI_OSC_LOST_CON_DOWN

        btr edi, LOG2(HINTI_OSC_LOST_CON_DOWN)
        .IF CARRY?

            INVAL_TRACE HINTI_OSC_LOST_CON_DOWN

            or ecx, HINTOSC_RENDER_MASK     OR  \
                    HINTOSC_INVAL_BLIT_RECT OR  \
                    HINTOSC_INVAL_BUILD_RENDER

        .ENDIF





    ;// HINTI_OSC_GOT_GROUP

        btr edi, LOG2(HINTI_OSC_GOT_GROUP)
        .IF CARRY?

            INVAL_TRACE HINTI_OSC_GOT_GROUP

            or ecx, HINTOSC_STATE_HAS_GROUP         OR  \
                    HINTOSC_INVAL_UPDATE_BOUNDRY    OR  \
                    HINTOSC_INVAL_BLIT_BOUNDRY      OR  \
                    HINTOSC_INVAL_BUILD_RENDER

            btr edi, LOG2(HINTI_OSC_LOST_GROUP)

        .ENDIF

    ;// HINTI_OSC_LOST_GROUP

        btr edi, LOG2(HINTI_OSC_LOST_GROUP)
        .IF CARRY?

            INVAL_TRACE HINTI_OSC_LOST_GROUP

            or ecx, HINTOSC_INVAL_UPDATE_BOUNDRY    OR  \
                    HINTOSC_INVAL_BLIT_BOUNDRY      OR  \
                    HINTOSC_INVAL_ERASE_BOUNDRY     OR  \
                    HINTOSC_INVAL_BUILD_RENDER

            and ecx, NOT HINTOSC_STATE_HAS_GROUP

        .ENDIF




    ;// HINTI_OSC_GOT_LOCK_SELECT

        btr edi, LOG2(HINTI_OSC_GOT_LOCK_SELECT)
        .IF CARRY?

            INVAL_TRACE HINTI_OSC_GOT_LOCK_SELECT

            or ecx, HINTOSC_STATE_HAS_LOCK_SELECT   OR  \
                    HINTOSC_INVAL_UPDATE_BOUNDRY    OR  \
                    HINTOSC_INVAL_BLIT_BOUNDRY      OR  \
                    HINTOSC_INVAL_BUILD_RENDER

            btr edi, LOG2(HINTI_OSC_LOST_LOCK_SELECT)

        .ENDIF

    ;// HINTI_OSC_LOST_LOCK_SELECT

        btr edi, LOG2(HINTI_OSC_LOST_LOCK_SELECT)
        .IF CARRY?

            INVAL_TRACE HINTI_OSC_LOST_LOCK_SELECT

            or ecx, HINTOSC_INVAL_UPDATE_BOUNDRY    OR  \
                    HINTOSC_INVAL_BLIT_BOUNDRY      OR  \
                    HINTOSC_INVAL_ERASE_BOUNDRY     OR  \
                    HINTOSC_INVAL_BUILD_RENDER

            btr ecx, LOG2(HINTOSC_STATE_HAS_LOCK_SELECT)

        .ENDIF



    ;// HINTI_OSC_GOT_BAD

        btr edi, LOG2(HINTI_OSC_GOT_BAD)
        .IF CARRY?

            INVAL_TRACE HINTI_OSC_GOT_BAD

            or ecx, HINTOSC_STATE_HAS_BAD           OR  \
                    HINTOSC_INVAL_UPDATE_BOUNDRY    OR  \
                    HINTOSC_INVAL_BLIT_BOUNDRY      OR  \
                    HINTOSC_INVAL_BUILD_RENDER

            btr edi, LOG2(HINTI_OSC_LOST_BAD)

        .ENDIF


    ;// HINTI_OSC_LOST_BAD

        btr edi, LOG2(HINTI_OSC_LOST_BAD)
        .IF CARRY?

            INVAL_TRACE HINTI_OSC_LOST_BAD

            or ecx, HINTOSC_INVAL_UPDATE_BOUNDRY    OR  \
                    HINTOSC_INVAL_BLIT_BOUNDRY      OR  \
                    HINTOSC_INVAL_ERASE_BOUNDRY     OR  \
                    HINTOSC_INVAL_BUILD_RENDER

            and ecx, NOT HINTOSC_STATE_HAS_BAD

        .ENDIF


    ;// HINTI_OSC_SHOW_PINS                 ;// this osc is to display it's unconnected pins

        btr edi, LOG2(HINTI_OSC_SHOW_PINS)
        .IF CARRY?

            INVAL_TRACE HINTI_OSC_SHOW_PINS

            ;// are we already showing our pins ?

            bts ecx, LOG2(HINTOSC_STATE_SHOW_PINS)
            .IF !CARRY?

                or ecx, HINTOSC_INVAL_UPDATE_BOUNDRY    OR  \
                        HINTOSC_INVAL_BLIT_BOUNDRY      OR  \
                        HINTOSC_INVAL_BUILD_RENDER      OR  \
                        HINTOSC_INVAL_DO_PINS

                mov eax,HINTPIN_INVAL_BUILD_RENDER

                ITERATE_PINS
                or [ebx].dwHintPin, eax
                PINS_ITERATE

            .ENDIF

        .ENDIF


    ;// HINTI_OSC_HIDE_PINS                 ;// this osc can hide it's un connected pins

        btr edi, LOG2(HINTI_OSC_HIDE_PINS)
        .IF CARRY?

            INVAL_TRACE HINTI_OSC_HIDE_PINS

            ;// are we showing our pins ?
            btr ecx, LOG2(HINTOSC_STATE_SHOW_PINS)
            .IF CARRY?

                or ecx, HINTOSC_INVAL_UPDATE_BOUNDRY    OR  \
                        HINTOSC_INVAL_ERASE_BOUNDRY     OR  \
                        HINTOSC_INVAL_BLIT_BOUNDRY      OR  \
                        HINTOSC_RENDER_MASK             OR  \
                        HINTOSC_INVAL_BUILD_RENDER
            .ENDIF

        .ENDIF






    ;// HINTI_OSC_UPDATE                    ;// the object need reblitted

        btr edi, LOG2(HINTI_OSC_UPDATE)
        .IF CARRY?

            INVAL_TRACE HINTI_OSC_UPDATE

            or ecx, HINTOSC_RENDER_MASK         OR  \
                    HINTOSC_INVAL_BLIT_RECT     OR  \
                    HINTOSC_RENDER_BLIT_RECT    OR  \
                    HINTOSC_INVAL_BUILD_RENDER

        .ENDIF


    ;// HINTI_OSC_UPDATE_CLOCKS             ;// the clocks display needs updated

        btr edi, LOG2(HINTI_OSC_UPDATE_CLOCKS)
        .IF CARRY?

            INVAL_TRACE HINTI_OSC_UPDATE_CLOCKS

            or ecx, HINTOSC_RENDER_CLOCKS       OR  \
                    HINTOSC_INVAL_BLIT_CLOCKS

        .ENDIF



    ;// store the results

        mov [esi].dwHintI, edi      ;// store the new hintI bits
        mov [esi].dwHintOsc, ecx    ;// store the new hint2 bits

        DEBUG_IF <edi>  ;// missed a spot


















    ;//////////////////////////////////////////////////
    ;//
    ;// part 2
    ;//         process the hintOsc INVAL commands
    ;//

        mov edi, ecx

    ;// HINTOSC_INVAL_ERASE_BOUNDRY

        btr edi, LOG2(HINTOSC_INVAL_ERASE_BOUNDRY)
        .IF CARRY?

            bt edi, LOG2(HINTOSC_STATE_BOUNDRY_VALID)
            .IF CARRY?

                INVAL_TRACE HINTOSC_INVAL_ERASE_BOUNDRY

                lea eax, [esi].boundry      ;// point at boundry
                invoke gdi_Erase_rect       ;// add to the erase rect

                ;// erase boundry means we have to render our pins
                ;// but not invalidate them

                or edi, HINTOSC_INVAL_DO_PINS
                mov eax, HINTPIN_INVAL_BUILD_RENDER

                ITERATE_PINS
                or [ebx].dwHintPin, eax
                PINS_ITERATE

            .ENDIF

        .ENDIF

    ;// HINTOSC_INVAL_TEST_ONSCREEN
    ;// HINTOSC_INVAL_CREATED

        btr edi, LOG2(HINTOSC_INVAL_TEST_ONSCREEN)
        .IF CARRY?

            INVAL_TRACE HINTOSC_INVAL_TEST_ONSCREEN

            invoke gdi_test_on_screen           ;// call test on screen

            btr edi, LOG2(HINTOSC_INVAL_CREATED);// test if created bit is on

            .IF !SIGN?                          ;// object is OFF screen

                jnc hintosc_remove_from_list    ;// jump to remover code if not created

                GDI_RECTTL_TO_GDI_ADDRESS [esi].rect, edx   ;// compute pDest
                mov [esi].pDest, edx                        ;// store
                or edi, HINTOSC_INVAL_REMOVE                ;// set the remove bit

            .ENDIF

        .ENDIF

    ;// HINTOSC_INVAL_SET_SHAPE

        btr edi, LOG2(HINTOSC_INVAL_SET_SHAPE)
        .IF CARRY?

            INVAL_TRACE HINTOSC_INVAL_SET_SHAPE

            mov [esi].dwHintOsc, edi    ;// store the flags
            OSC_TO_BASE esi, edi        ;// get the base class
            invoke [edi].gui.SetShape   ;// call it's set shape function
            mov edi, [esi].dwHintOsc    ;// retrieve the flags

        .ENDIF

    ;// HINTOSC_INVAL_BUILD_RENDER  skip if HINTOSC_INVAL_REMOVE

        btr edi, LOG2(HINTOSC_INVAL_BUILD_RENDER)
        .IF CARRY?

            bt edi, LOG2(HINTOSC_INVAL_REMOVE)
            .IF !CARRY?

                INVAL_TRACE HINTOSC_INVAL_BUILD_RENDER

                invoke gdi_osc_BuildRenderFlags

            .ENDIF

        .ENDIF

    ;// HINTOSC_INVAL_DO_PINS_JUMP

        btr edi,LOG2(HINTOSC_INVAL_DO_PINS_JUMP)
        .IF CARRY?

            INVAL_TRACE HINTOSC_INVAL_DO_PINS_JUMP

            or edi, HINTOSC_INVAL_DO_PINS       ;// set the inval do pins command
            mov eax, HINTPIN_INVAL_BUILD_JUMP   ;// tell all pins to build their jump index
            ITERATE_PINS
            or [ebx].dwHintPin, eax
            PINS_ITERATE

        .ENDIF







    ;// HINTOSC_INVAL_DO_PINS

        btr edi,LOG2(HINTOSC_INVAL_DO_PINS)
        .IF CARRY?

            INVAL_TRACE HINTOSC_INVAL_DO_PINS

            or edi, HINTOSC_RENDER_DO_PINS  ;// tell renderer to do the pins

            mov [esi].dwHintOsc, edi        ;// store the osc flags

        ITERATE_PINS

            mov edi, [ebx].dwHintI      ;// load the pin flags
            mov ecx, [ebx].dwHintPin    ;// load the hinti flags




            ;// HINTI_PIN_UPDATE_CHANGING   ;// the changing status has changed
                                            ;// sent from play IC
                btr edi, LOG2(HINTI_PIN_UPDATE_CHANGING)
                .IF CARRY?

                    INVAL_TRACE HINTI_PIN_UPDATE_CHANGING

                    ;// check the current state
                    ;// set the new state
                    ;// tell render to draw connection
                    ;// if a bus, then do out 1

                    mov eax, [ebx].dwStatus     ;// load the pin status

                    test eax, PIN_BUS_TEST      ;// check if we are a bus
                    jnz changing_yes_bus

                changing_not_bus:

                    bt eax, LOG2(PIN_CHANGING)  ;// if we are changing now
                    jnc Q00

                    or ecx, HINTPIN_STATE_THICK OR \
                            HINTPIN_RENDER_CONN OR  \
                            HINTPIN_INVAL_BLIT_CONN
                    jmp changing_done

                Q00:                            ;// else, we are not changing now

                    btr ecx, LOG2(HINTPIN_STATE_THICK);// reset thick and see if we need to erase
                    jnc changing_done           ;// jump if we were not thick

                    or ecx, HINTPIN_INVAL_ERASE_CONN    OR  \
                            HINTPIN_INVAL_BLIT_CONN     OR  \
                            HINTPIN_RENDER_CONN

                    jmp changing_done

                changing_yes_bus:


                changing_done:
                .ENDIF



            ;// HINTI_PIN_PHETA_CHANGED     ;// schedule for pin layout

                btr edi, LOG2(HINTI_PIN_PHETA_CHANGED)
                .IF CARRY?

                    INVAL_TRACE HINTI_PIN_PHETA_CHANGED


                    or [esi].dwHintOsc, HINTOSC_INVAL_UPDATE_BOUNDRY    OR  \
                                        HINTOSC_INVAL_BLIT_BOUNDRY

                    ;// schedule for layout becuase pheta changed
                    ;// redraw assy and conn

                    or ecx, HINTPIN_INVAL_LAYOUT_SHAPE  OR  \
                            HINTPIN_INVAL_BUILD_RENDER  OR  \
                            HINTPIN_INVAL_BLIT_RECT     OR  \
                            HINTPIN_INVAL_ERASE_CONN    OR  \
                            HINTPIN_INVAL_ERASE_RECT



                .ENDIF




            ;// HINTI_PIN_UPDATE_SHAPE      ;// the logic shape has changed

                btr edi, LOG2(HINTI_PIN_UPDATE_SHAPE)
                .IF CARRY?

                    INVAL_TRACE HINTI_PIN_UPDATE_SHAPE

                    or ecx, HINTPIN_INVAL_BUILD_RENDER  OR  \
                            HINTPIN_INVAL_BUILD_JUMP    OR  \
                            HINTPIN_INVAL_BLIT_CONN     OR  \
                            HINTPIN_INVAL_LAYOUT_SHAPE  OR  \
                            HINTPIN_INVAL_ERASE_RECT    OR  \
                            HINTPIN_INVAL_ERASE_CONN    OR  \
                            HINTPIN_INVAL_BLIT_RECT

                .ENDIF




            ;// HINTI_PIN_UPDATE_COLOR      ;// the color of this pin has changed

                btr edi, LOG2(HINTI_PIN_UPDATE_COLOR)
                .IF CARRY?

                    INVAL_TRACE HINTI_PIN_UPDATE_COLOR

                    ;// all attached pins must be redrawn
                    ;// this requires scanning the connections
                    ;// and adding any objects to the end of the inval list

                    ;// we'll set the appropriate flags in this loop
                    ;// and turn off the update color flag
                    ;// this will prevent scanning the list multiple times

                    or ecx, HINTPIN_INVAL_BUILD_RENDER  OR  \
                            HINTPIN_INVAL_BLIT_RECT     OR  \
                            HINTPIN_INVAL_BLIT_CONN

                .ENDIF


            ;// HINTI_PIN_UPDATE_PROBE      ;// the color of this pin has changed

                btr edi, LOG2(HINTI_PIN_UPDATE_PROBE)
                .IF CARRY?

                    INVAL_TRACE HINTI_PIN_UPDATE_PROBE

                    ;// the pin must be erased and redrawn

                    or ecx, HINTPIN_INVAL_BUILD_RENDER  OR  \
                            HINTPIN_INVAL_BLIT_RECT     OR  \
                            HINTPIN_INVAL_ERASE_RECT

                .ENDIF



            ;// HINTI_PIN_CONNECTED         ;// pin has been connected

                btr edi, LOG2(HINTI_PIN_CONNECTED)
                .IF CARRY?

                    INVAL_TRACE HINTI_PIN_CONNECTED

                    ;// add to blit rect

                    or ecx, HINTPIN_INVAL_BUILD_RENDER  OR  \
                            HINTPIN_INVAL_ERASE_RECT    OR  \
                            HINTPIN_INVAL_BLIT_RECT     OR  \
                            HINTPIN_INVAL_BLIT_CONN     OR  \
                            HINTPIN_INVAL_BUILD_JUMP    OR  \
                            HINTPIN_INVAL_LAYOUT_SHAPE

                    or app_bFlags, APP_SYNC_GROUP

                    ;// unredo steps are allows to connect hidden pins
                    ;// we have to account for that here

                    .IF [ebx].dwStatus & PIN_HIDDEN
                        or ecx, HINTPIN_STATE_HIDE      OR  \
                                HINTPIN_INVAL_BLIT_RECT OR  \
                                HINTPIN_INVAL_BUILD_RENDER
                        and [ebx].dwStatus, NOT PIN_HIDDEN
                    .ENDIF

                    ;// make sure all attached pins get hit as well ?

                .ENDIF



            ;// HINTI_PIN_UNCONNECTED       ;// pin has been unconnected

                btr edi, LOG2(HINTI_PIN_UNCONNECTED)
                .IF CARRY?

                    INVAL_TRACE HINTI_PIN_UNCONNECTED

                    ;// test and reset pin_hide

                    xor eax, eax
                    btr ecx, LOG2( HINTPIN_STATE_HIDE )
                    rcl eax, LOG2(PIN_HIDDEN)+1
                    or [ebx].dwStatus, eax

                    ;// schedule for pin_layout

                    or ecx, HINTPIN_INVAL_ERASE_RECT    OR  \
                            HINTPIN_INVAL_BUILD_JUMP    OR  \
                            HINTPIN_INVAL_LAYOUT_SHAPE

                    or app_bFlags, APP_SYNC_GROUP

                .ENDIF






            ;// HINTI_PIN_HIDE              ;// hide this pin, or try to

                btr edi, LOG2(HINTI_PIN_HIDE)
                .IF CARRY?

                    INVAL_TRACE HINTI_PIN_HIDE

                    bt ecx, LOG2(HINTPIN_INVAL_BUILD_JUMP)
                    .IF CARRY?

                        invoke gdi_pin_SetJIndex

                    .ENDIF

                    mov eax, [ebx].j_index
                    .IF pin_j_index_connected[eax]  ;// connected ?

                        ;// connected, all we can do is set the flag
                        or ecx, HINTPIN_STATE_HIDE      OR  \
                                HINTPIN_INVAL_BLIT_RECT OR  \
                                HINTPIN_INVAL_BUILD_RENDER

                    .ELSE

                        ;// not connected, now we can hide it
                        or [ebx].dwStatus, PIN_HIDDEN

                        or ecx, HINTPIN_INVAL_BUILD_JUMP    OR  \
                                HINTPIN_INVAL_ERASE_RECT

                        and ecx, NOT HINTPIN_STATE_HIDE

                    .ENDIF

                .ENDIF



            ;// HINTI_PIN_UNHIDE            ;// unhide this pin

                btr edi, LOG2(HINTI_PIN_UNHIDE)
                .IF CARRY?

                    INVAL_TRACE HINTI_PIN_UNHIDE

                    and ecx, NOT HINTPIN_STATE_HIDE     ;// update the state
                    and [ebx].dwStatus, NOT PIN_HIDDEN  ;// turn off the hidden bit

                    or ecx, HINTPIN_INVAL_BUILD_JUMP    OR  \
                            HINTPIN_INVAL_BLIT_RECT     OR  \
                            HINTPIN_INVAL_BUILD_RENDER

                .ENDIF










            ;// HINTI_PIN_GOT_HOVER

                btr edi, LOG2(HINTI_PIN_GOT_HOVER)
                .IF CARRY?

                    INVAL_TRACE HINTI_PIN_GOT_HOVER

                    btr edi, LOG2(HINTI_PIN_LOST_HOVER)

                    or ecx, HINTPIN_STATE_HAS_HOVER     OR  \
                            HINTPIN_INVAL_BUILD_RENDER  OR  \
                            HINTPIN_INVAL_BLIT_RECT     OR  \
                            HINTPIN_INVAL_BLIT_CONN

                .ENDIF



            ;// HINTI_PIN_LOST_HOVER

                btr edi, LOG2(HINTI_PIN_LOST_HOVER)
                .IF CARRY?

                    INVAL_TRACE HINTI_PIN_LOST_HOVER

                    btr ecx, LOG2(HINTPIN_STATE_HAS_HOVER)

                    or [esi].dwHintOsc, HINTOSC_RENDER_MASK         OR  \
                                        HINTOSC_INVAL_BUILD_RENDER

                    or ecx, HINTPIN_INVAL_BUILD_RENDER  OR  \
                            HINTPIN_INVAL_BLIT_RECT     OR  \
                            HINTPIN_INVAL_ERASE_RECT    OR  \
                            HINTPIN_INVAL_BLIT_CONN

                .ENDIF



            ;// HINTI_PIN_GOT_DOWN

                btr edi, LOG2(HINTI_PIN_GOT_DOWN)
                .IF CARRY?

                    INVAL_TRACE HINTI_PIN_GOT_DOWN

                    or ecx, HINTPIN_STATE_HAS_DOWN      OR  \
                            HINTPIN_INVAL_BUILD_RENDER  OR  \
                            HINTPIN_INVAL_BLIT_RECT     OR  \
                            HINTPIN_INVAL_BLIT_CONN
                .ENDIF



            ;// HINTI_PIN_LOST_DOWN

                btr edi, LOG2(HINTI_PIN_LOST_DOWN)
                .IF CARRY?

                    INVAL_TRACE HINTI_PIN_LOST_DOWN

                    btr ecx, LOG2(HINTPIN_STATE_HAS_DOWN)
                    or ecx, HINTPIN_INVAL_BUILD_RENDER  OR  \
                            HINTPIN_INVAL_BLIT_RECT     OR  \
                            HINTPIN_INVAL_ERASE_RECT    OR  \
                            HINTPIN_INVAL_BLIT_CONN

                .ENDIF


            ;// HINTI_PIN_GOT_BUS_HOVER

                btr edi, LOG2(HINTI_PIN_GOT_BUS_HOVER)
                .IF CARRY?

                    INVAL_TRACE HINTI_PIN_GOT_BUS_HOVER

                    btr edi, LOG2(HINTI_PIN_LOST_BUS_HOVER)

                    or ecx, HINTPIN_STATE_HAS_BUS_HOVER     OR  \
                            HINTPIN_INVAL_BUILD_RENDER  OR  \
                            HINTPIN_INVAL_BLIT_RECT     OR  \
                            HINTPIN_INVAL_BLIT_CONN


                .ENDIF



            ;// HINTI_PIN_LOST_HOVER

                btr edi, LOG2(HINTI_PIN_LOST_BUS_HOVER)
                .IF CARRY?

                    INVAL_TRACE HINTI_PIN_LOST_HOVER

                    btr ecx, LOG2(HINTPIN_STATE_HAS_BUS_HOVER)

                    or [esi].dwHintOsc, HINTOSC_RENDER_MASK         OR  \
                                        HINTOSC_INVAL_BUILD_RENDER

                    or ecx, HINTPIN_INVAL_BUILD_RENDER  OR  \
                            HINTPIN_INVAL_BLIT_RECT     OR  \
                            HINTPIN_INVAL_ERASE_RECT    OR  \
                            HINTPIN_INVAL_BLIT_CONN

                    ;// btr edi, LOG2(HINTI_PIN_GOT_BUS_HOVER)

                .ENDIF



            ;// store the current values

                mov [ebx].dwHintI, edi
                mov [ebx].dwHintPin, ecx

                DEBUG_IF <edi>  ;// missed a spot

            ;// then do any operations that are left over


            ;// make damn sure none of the render bits are on when the osc will be removed
            ;// this is needed because gdi_Render may add these back in

            .IF [esi].dwHintOsc & HINTOSC_INVAL_REMOVE

                and ecx, NOT( \
                    HINTPIN_RENDER_ASSY OR  \
                    HINTPIN_RENDER_CONN OR  \
                    HINTPIN_RENDER_OUT1 OR  \
                    HINTPIN_RENDER_OUT1_BUS OR \
                    HINTPIN_INVAL_BLIT_RECT OR  \
                    HINTPIN_INVAL_BLIT_CONN OR  \
                    HINTPIN_INVAL_ERASE_RECT OR  \
                    HINTPIN_INVAL_ERASE_CONN OR  \
                    HINTPIN_INVAL_BUILD_RENDER  )
            .ENDIF

                mov eax, [ebx].j_index  ;// always load the jump index

            ;// HINTPIN_INVAL_ERASE_RECT        eax must have j_index

                btr ecx, LOG2(HINTPIN_INVAL_ERASE_RECT)
                .IF CARRY?

                    INVAL_TRACE HINTPIN_INVAL_ERASE_RECT

                    bt ecx, LOG2(HINTPIN_STATE_VALID_TSHAPE)
                    .IF CARRY?

                        PIN_TO_TSHAPE ebx, edi
                        lea edi, [edi].r1
                        ASSUME edi:PTR RECT

                        jmp hintpin_erase_rect_jump[eax*4]

                        hintpin_erase_rect_FT:: ;// unconnected output

                            ;// this rect is drawn backwards, use r1

                            point_Get [ebx].t0
                            point_SubTL [edi]
                            add eax, 3  ;// kludge to make sure hover gets erased
                            add edx, 3

                            invoke gdi_Erase_this_point

                            point_Get [ebx].t0
                            sub eax, 3  ;// kludge to make sure hover gets erased
                            sub edx, 3

                            point_SubBR [edi]
                            invoke gdi_Erase_this_point

                            jmp hintpin_erase_rect_done

                        hintpin_erase_rect_FS:: ;// connected output

                            ;// this also requires special treatment
                            ;// because we are drawing a triangle, r1 is not correct
                            ;// so we use: tr = (t0 + t1) / 2
                            ;// then erase tr +/- font offset

                            point_Get [ebx].t0
                            point_Add [ebx].t1
                            shr eax, 1
                            shr edx, 1

                            sub eax, PIN_FONT_RADIUS+2
                            sub edx, PIN_FONT_RADIUS+2

                            invoke gdi_Erase_this_point

                            add eax, (PIN_FONT_RADIUS+2)*2
                            add edx, (PIN_FONT_RADIUS+2)*2

                            invoke gdi_Erase_this_point

                            jmp hintpin_erase_rect_done


                        ;////////////////////////////////////////////////////
                        ;//
                        ;// thes two need special treatment because the logic shapes
                        ;// often extends beyond what the tringale shape would

                        hintpin_erase_rect_LFB::    ;// bussed logic input

                            add edi, SIZEOF RECT

                        hintpin_erase_rect_LFS::    ;// connected logic input

                            point_Get [ebx].t0
                            point_AddTL [edi]
                            sub eax, PIN_FONT_RADIUS
                            sub edx, PIN_FONT_RADIUS
                            invoke gdi_Erase_this_point

                            point_Get [ebx].t0
                            add eax, PIN_FONT_RADIUS
                            add edx, PIN_FONT_RADIUS
                            jmp hintpin_erase_rect_second
                            ;// point_AddBR [edi]
                            ;// invoke gdi_Erase_this_point

                            ;// jmp hintpin_erase_rect_done

                        ;////////////////////////////////////////////////////

                        hintpin_erase_rect_LF::     ;// unconnected logic input

                            point_Get [ebx].t0
                            sub eax, 3
                            sub edx, 3
                            point_AddTL [edi]
                            invoke gdi_Erase_this_point

                            point_Get [ebx].t0
                            add eax, 3
                            add edx, 3
                            jmp hintpin_erase_rect_second

                        hintpin_erase_rect_FB::     ;// bussed output

                            ;// this also gets a special treatment

                            point_Get [ebx].t0
                            point_Add [ebx].t1
                            shr eax, 1
                            shr edx, 1

                            sub eax, PIN_FONT_RADIUS+2
                            sub edx, PIN_FONT_RADIUS+2

                            invoke gdi_Erase_this_point

                            add eax, (PIN_FONT_RADIUS+2)*2
                            add edx, (PIN_FONT_RADIUS+2)*2

                            invoke gdi_Erase_this_point

                            ;// then fall into next section to hit the bus circle

                        hintpin_erase_rect_TFB::    ;// bussed analog input

                            add edi, SIZEOF RECT

                        hintpin_erase_rect_TFS::    ;// connected analog input
                        hintpin_erase_rect_TF::     ;// unconnected analog input

                            point_Get [ebx].t0
                            point_AddTL [edi]
                            invoke gdi_Erase_this_point

                            point_Get [ebx].t0

                        hintpin_erase_rect_second:

                            point_AddBR [edi]
                            invoke gdi_Erase_this_point

                        hintpin_erase_rect_done:

                        ;// erasing a pin always requires reblitting the object

                            or [esi].dwHintOsc, HINTOSC_RENDER_MASK OR  \
                                                HINTOSC_RENDER_CALL_BASE

                        hintpin_erase_rect_hide::

                            mov eax, [ebx].j_index

                    .ENDIF

                .ENDIF


            ;// HINTPIN_INVAL_BUILD_JUMP

                xor eax, eax

                btr ecx, LOG2(HINTPIN_INVAL_BUILD_JUMP)
                .IF CARRY?

                    INVAL_TRACE HINTPIN_INVAL_BUILD_JUMP

                    invoke gdi_pin_SetJIndex
                    xor eax, eax

                .ENDIF

                ;// if jmp index is zero, we can skip the rest

                or eax, [ebx].j_index
                jz hintpin_next_pin



            ;// HINTPIN_INVAL_ERASE_CONN        eax must have j_index

                btr ecx, LOG2(HINTPIN_INVAL_ERASE_CONN)
                .IF CARRY?

                    ;// add all connections to erase rect (t1 and t2)

                    INVAL_TRACE HINTPIN_INVAL_ERASE_CONN

                    mov edx, ebx

                    jmp hintpin_erase_conn_jump[eax*4]

            ;// not certain this code needs implemented
            ;//
            ;// hintpin_erase_conn_TFB::    ;// bussed analog input
            ;// hintpin_erase_conn_LFB::    ;// bussed logic input
            ;//
            ;//     mov edx, [ebx].pPin     ;// get the source pin
            ;//
            ;// hintpin_erase_conn_FB::     ;// bussed output
            ;//
            ;//     int 3   ;// write for busses

                hintpin_erase_conn_TFS::    ;// connected analog input
                hintpin_erase_conn_LFS::    ;// connected logic input

                    mov edx, [ebx].pPin     ;// get the source pin

                hintpin_erase_conn_FS::     ;// connected output

                    mov [ebx].dwHintPin, ecx

                    GET_PIN edx, ecx        ;// xfer source pin to ecx

                    ;// add t1 and t2 to the invalidate rect
                    .IF [ecx].dwHintPin & HINTPIN_STATE_VALID_DEST
                        point_Get [ecx].t1
                        invoke gdi_Erase_this_point
                        point_Get [ecx].t2
                        invoke gdi_Erase_this_point
                    .ENDIF

                    mov ecx, [ecx].pPin
                    .REPEAT

                        .IF [ecx].dwHintPin & HINTPIN_STATE_VALID_DEST
                            point_Get [ecx].t1
                            invoke gdi_Erase_this_point
                            point_Get [ecx].t2
                            invoke gdi_Erase_this_point
                        .ENDIF
                        mov ecx, [ecx].pData

                    .UNTIL !ecx

                    mov ecx, [ebx].dwHintPin;// retrieve hint pin
                    mov eax, [ebx].j_index  ;// restore jump index

                hintpin_erase_conn_LF::     ;// unconnected logic input
                hintpin_erase_conn_TF::     ;// unconnected analog input
                hintpin_erase_conn_FT::     ;// unconnected output
                hintpin_erase_conn_hide::   ;// hidden

            ;// not certain this code needs implemented
            ;// see above
            ;//
                hintpin_erase_conn_TFB::    ;// bussed analog input
                hintpin_erase_conn_LFB::    ;// bussed logic input
            ;//
            ;//     mov edx, [ebx].pPin     ;// get the source pin
            ;//
                hintpin_erase_conn_FB::     ;// bussed output
            ;//
            ;//     int 3   ;// write for busses

                .ENDIF




            ;// HINTPIN_INVAL_LAYOUT_SHAPE      eax must have j_index

                btr ecx, LOG2(HINTPIN_INVAL_LAYOUT_SHAPE)
                .IF CARRY?

                    INVAL_TRACE HINTPIN_INVAL_LAYOUT_SHAPE

                    mov [ebx].dwHintPin, ecx    ;// store the flags
                    invoke pin_Layout_shape     ;// call the layout function
                    mov ecx, [ebx].dwHintPin    ;// retrieve the flags
                    DEBUG_IF <!![ebx].pTShape>  ;// a TShape wasn't set !!

                    mov eax, [ebx].j_index

                .ENDIF

            ;// HINTPIN_INVAL_LAYOUT_POINTS     eax must have j_index

                btr ecx, LOG2(HINTPIN_INVAL_LAYOUT_POINTS)
                .IF CARRY?

                    INVAL_TRACE HINTPIN_INVAL_LAYOUT_POINTS

                    DEBUG_IF <!![ebx].pTShape>  ;// a TShape wasn't set !!

                    mov [ebx].dwHintPin, ecx    ;// store the flags
                    invoke pin_Layout_points    ;// call the layout function
                    mov ecx, [ebx].dwHintPin    ;// retrieve the flags

                    mov eax, [ebx].j_index

                .ENDIF




            ;// HINTPIN_INVAL_BLIT_RECT         eax must have j_index

                btr ecx, LOG2(HINTPIN_INVAL_BLIT_RECT)
                .IF CARRY?

                    INVAL_TRACE HINTPIN_INVAL_BLIT_RECT

                    DEBUG_IF <!!(ecx & HINTPIN_STATE_VALID_TSHAPE)>

                    PIN_TO_TSHAPE ebx, edi
                    lea edi, [edi].r1
                    ASSUME edi:PTR RECT

                    jmp hintpin_blit_rect_jump[eax*4]

                    hintpin_blit_rect_FT::  ;// unconnected output

                        ;// this rect is drawn backwards, using r1

                        point_Get [ebx].t0
                        point_SubTL [edi]
                        invoke gdi_Blit_this_point

                        point_Get [ebx].t0
                        point_SubBR [edi]
                        invoke gdi_Blit_this_point

                        jmp hintpin_blit_rect_hide

                    hintpin_blit_rect_FS::  ;// connected output

                        ;// this also requires special treatment
                        ;// because we are drawing a triangle, r1 is not correct
                        ;// so we use: tr = (t0 + t1) / 2
                        ;// then erase tr +/- (pin_font_radius+1)

                        point_Get [ebx].t0
                        point_Add [ebx].t1
                        shr eax, 1
                        shr edx, 1

                        sub eax, PIN_FONT_RADIUS+1
                        sub edx, PIN_FONT_RADIUS+1

                        invoke gdi_Blit_this_point

                        add eax, (PIN_FONT_RADIUS+1)*2
                        add edx, (PIN_FONT_RADIUS+1)*2

                        jmp hintpin_blit_rect_second

                    hintpin_blit_rect_LFS:: ;// connected logic input
                    hintpin_blit_rect_LF::  ;// unconnected logic input, these get spical treatment

                        point_Get [ebx].t0
                        sub eax, 3
                        sub edx, 3
                        point_AddTL [edi]
                        invoke gdi_Blit_this_point

                        point_Get [ebx].t0
                        add eax, 3
                        add edx, 3

                        ;//point_AddBR [edi]
                        jmp hintpin_blit_rect_second

                    hintpin_blit_rect_TFB:: ;// bussed analog input
                    hintpin_blit_rect_LFB:: ;// bussed logic input
                    hintpin_blit_rect_FB::  ;// bussed output

                        add edi, SIZEOF RECT

                    hintpin_blit_rect_TFS:: ;// connected analog input
                    hintpin_blit_rect_TF::  ;// unconnected analog input

                        point_Get [ebx].t0
                        point_AddTL [edi]
                        invoke gdi_Blit_this_point

                        point_Get [ebx].t0
                    hintpin_blit_rect_second:

                        point_AddBR [edi]
                        invoke gdi_Blit_this_point

                    hintpin_blit_rect_hide::    ;// hidden

                        mov eax, [ebx].j_index

                .ENDIF



            ;// HINTPIN_INVAL_BLIT_CONN         eax must have j_index

                btr ecx, LOG2(HINTPIN_INVAL_BLIT_CONN)
                .IF CARRY?

                    ;// add all connections to blit rect (t1 and t2)

                    INVAL_TRACE HINTPIN_INVAL_BLIT_CONN

                    mov edx, ebx

                    jmp hintpin_blit_conn_jump[eax*4]

                hintpin_blit_conn_TFB::     ;// bussed analog input
                hintpin_blit_conn_LFB::     ;// bussed logic input

                    mov edx, [ebx].pPin     ;// get the source pin

                hintpin_blit_conn_FB::      ;// bussed output

                    mov [ebx].dwHintPin, ecx;// store the new flags

                    GET_PIN edx, ecx        ;// xfer source pin to ecx

                    ;// add r2 to the invalidate rect
                    ;// have to do seperate calls for TL and BR

                    .IF [ecx].dwHintPin & HINTPIN_STATE_VALID_TSHAPE

                        PIN_TO_TSHAPE ecx, edi

                        point_Get [ecx].t0
                        point_SubTL [edi].r2
                        invoke gdi_Blit_this_point
                        point_Get [ecx].t0
                        point_SubBR [edi].r2
                        invoke gdi_Blit_this_point

                    .ENDIF

                    mov ecx, [ecx].pPin ;// can have a bus that is not connected
                    .WHILE ecx          ;// so we do the test first

                        .IF [ecx].dwHintPin & HINTPIN_STATE_VALID_TSHAPE
                        xor eax, eax
                        PIN_TO_OSC ecx, edx
                        or eax, [edx].dwHintOsc ;// test if osc is on screen
                        .IF SIGN?
                        .IF [ecx].dwHintPin & HINTPIN_STATE_VALID_TSHAPE

                            PIN_TO_TSHAPE ecx, edi
                            point_Get [ecx].t0
                            point_AddTL [edi].r2
                            invoke gdi_Blit_this_point
                            point_Get [ecx].t0
                            point_AddBR [edi].r2
                            invoke gdi_Blit_this_point

                        .ENDIF
                        .ENDIF
                        .ENDIF

                        mov ecx, [ecx].pData

                    .ENDW

                    jmp hintpin_blit_conn_done

                hintpin_blit_conn_TFS::     ;// connected analog input
                hintpin_blit_conn_LFS::     ;// connected logic input

                    mov edx, [ebx].pPin     ;// get the source pin

                hintpin_blit_conn_FS::      ;// connected output

                    mov [ebx].dwHintPin, ecx

                    GET_PIN edx, ecx        ;// xfer source pin to ecx

                    ;// add t1 and t2 to the invalidate rect

                    .IF [ecx].dwHintPin & HINTPIN_STATE_VALID_DEST
                        point_Get [ecx].t1
                        invoke gdi_Blit_this_point
                        point_Get [ecx].t2
                        invoke gdi_Blit_this_point
                    .ENDIF

                    mov ecx, [ecx].pPin
                    .REPEAT
                        .IF [ecx].dwHintPin & HINTPIN_STATE_VALID_DEST
                            point_Get [ecx].t1
                            invoke gdi_Blit_this_point
                            point_Get [ecx].t2
                            invoke gdi_Blit_this_point
                        .ENDIF

                        mov ecx, [ecx].pData

                    .UNTIL !ecx

                hintpin_blit_conn_done:

                    mov ecx, [ebx].dwHintPin;// retrieve hint pin
                    mov eax, [ebx].j_index  ;// restore jump index

                hintpin_blit_conn_LF::      ;// unconnected logic input
                hintpin_blit_conn_TF::      ;// unconnected analog input
                hintpin_blit_conn_FT::      ;// unconnected output
                hintpin_blit_conn_hide::    ;// hidden


                .ENDIF


            ;// HINTPIN_INVAL_BUILD_RENDER          eax must have j_index

                btr ecx, LOG2(HINTPIN_INVAL_BUILD_RENDER)
                .IF CARRY?

                    INVAL_TRACE HINTPIN_INVAL_BUILD_RENDER

                    invoke gdi_pin_BuildRenderFlags

                .ENDIF

            ;// store and iterate

            hintpin_next_pin:

                mov [ebx].dwHintPin, ecx    ;// store the processed pin flags

        PINS_ITERATE

            mov edi, [esi].dwHintOsc        ;// retrieve the osc flags

        .ENDIF  ;// HINTOSC_INVAL_DO_PINS








    ;// HINTOSC_INVAL_UPDATE_BOUNDRY

        btr edi, LOG2(HINTOSC_INVAL_UPDATE_BOUNDRY)
        .IF CARRY?

            INVAL_TRACE HINTOSC_INVAL_UPDATE_BOUNDRY

            mov [esi].dwHintOsc, edi
            invoke gdi_build_boundry_rect
            mov edi, [esi].dwHintOsc
            or edi, HINTOSC_STATE_BOUNDRY_VALID

        .ENDIF



    ;// HINTOSC_INVAL_REMOVE and HINTOSC_INVAL_BLIT_xxx

    btr edi, LOG2(HINTOSC_INVAL_REMOVE)
    .IF !CARRY?

    ;// HINTOSC_INVAL_BLIT_BOUNDRY

        btr edi, LOG2(HINTOSC_INVAL_BLIT_BOUNDRY)
        .IF CARRY?

            INVAL_TRACE HINTOSC_INVAL_BLIT_BOUNDRY

            DEBUG_IF <!!(edi & HINTOSC_STATE_BOUNDRY_VALID)>

            lea eax, [esi].boundry
            invoke gdi_Blit_rect

            and edi, NOT (HINTOSC_INVAL_BLIT_RECT OR HINTOSC_INVAL_BLIT_CLOCKS )

        .ENDIF

    ;// HINTOSC_INVAL_BLIT_RECT

        btr edi, LOG2(HINTOSC_INVAL_BLIT_RECT)
        .IF CARRY?

            INVAL_TRACE HINTOSC_INVAL_BLIT_RECT

            lea eax, [esi].rect
            invoke gdi_Blit_rect

        .ENDIF

    ;// HINTOSC_INVAL_BLIT_CLOCKS

        btr edi, LOG2(HINTOSC_INVAL_BLIT_CLOCKS)
        .IF CARRY?

            INVAL_TRACE HINTOSC_INVAL_BLIT_CLOCKS

            point_GetTL [esi].rect
            invoke gdi_Blit_this_point
            add eax, CLOCKS_RECT_WIDTH
            sub edx, CLOCKS_RECT_HEIGHT
            invoke gdi_Blit_this_point

        .ENDIF

    .ELSE   ;// HINTOSC_INVAL_REMOVE

    hintosc_remove_from_list:

        INVAL_TRACE HINTOSC_INVAL_REMOVE

        dlist_GetNext oscI, esi, ecx    ;// get the next osc

        ;// make sure render bits are off
        and edi, NOT ( HINTOSC_RENDER_MASK OR HINTOSC_RENDER_DO_PINS )

        mov [esi].dwHintOsc, edi        ;// save remaining flags for next time
        dlist_Remove oscI, esi,,[ebp]   ;// remove from the I list
        mov esi, ecx
        jmp osc_loop_test               ;// jump to next osc

    .ENDIF

    ;// store the flags

        mov [esi].dwHintOsc, edi

    ;// iterate

        dlist_GetNext oscI, esi

    osc_loop_test:

    .UNTIL !esi


        pop edi
        pop ebx
        pop esi
        pop ebp

    .ENDIF



    ;// if we are connecting a pin, we have to add points to the blit rect

    .IF app_bFlags & APP_MODE_CONNECTING_PIN

            GET_PIN pin_down, ecx
            DEBUG_IF <!!ecx>            ;// supposed to be set

            point_Get mouse_now         ;// we need mouse now regardless where we end up
            invoke gdi_Blit_this_point
            point_Get mouse_prev        ;// we also need to clean up the previous display
            invoke gdi_Blit_this_point

    ;// determine the connecting mode based on the j_index of pin down

            mov eax, [ecx].j_index
            jmp inval_connecting_jump[eax*4]

        ALIGN 16
        inval_connecting_TFS::  ;// connected analog input
        inval_connecting_LFS::  ;// connected logic input

        ;// we are to MOVE an input connection
        ;// so we draw from the source pin to mouse now
        ;// unless we've reversed it

            cmp pin_connect_special_18, 0
            jne inval_connecting_FT
            mov ecx, [ecx].pPin     ;// get the source pin
            jmp inval_connecting_FT ;// jump to next section

        ;// fall into next section

        ALIGN 16
        inval_connecting_TF::   ;// unconnected analog input
        inval_connecting_LF::   ;// unconnected logic input
        inval_connecting_FT::   ;// unconnected output

        ;// are to CONNECT a pin
        ;// so we draw from pin.t1, t2 to mouse now

            point_Get [ecx].t1
            invoke gdi_Blit_this_point
            point_Get [ecx].t2
            invoke gdi_Blit_this_point

            jmp inval_connecting_done

        ALIGN 16
        inval_connecting_FS::   ;// connected output

        ;// we are MOVING an output
        ;// so we draw ALL the splines from each INPUT pin

            cmp pin_connect_special_18, 0   ;// check if we're reversed first
            jne inval_connecting_FT

            mov ecx, [ecx].pPin             ;// then scann all the inputs and invalidate them
            .WHILE ecx

                point_Get [ecx].t1
                invoke gdi_Blit_this_point
                point_Get [ecx].t2
                invoke gdi_Blit_this_point

                mov ecx, [ecx].pData

            .ENDW
            jmp inval_connecting_done


        inval_connecting_hide:: ;// hidden

            DEBUG_IF <1>

        ALIGN 16
        inval_connecting_TFB::  ;// bussed analog input
        inval_connecting_LFB::  ;// bussed logic input
        inval_connecting_FB::   ;// bussed output

        ;// we are MOVING a bus connection
        ;// so we want to show a bus circle ??

            point_Get mouse_prev
            add edx, PIN_BUS_RADIUS
            add eax, PIN_BUS_RADIUS
            invoke gdi_Blit_this_point

            sub edx, PIN_BUS_RADIUS * 2
            sub eax, PIN_BUS_RADIUS * 2
            invoke gdi_Blit_this_point

            point_Get mouse_now
            add edx, PIN_BUS_RADIUS
            add eax, PIN_BUS_RADIUS
            invoke gdi_Blit_this_point

            sub edx, PIN_BUS_RADIUS * 2
            sub eax, PIN_BUS_RADIUS * 2
            invoke gdi_Blit_this_point

        ALIGN 16
        inval_connecting_done:

        rect_Inflate gdi_blit_rect      ;// add a small amount so things get erased ok

    .ENDIF  ;// process connecting mode


    ;// if we are using the selrect, we have to add points to the blit rect

    .IF app_bFlags & APP_MODE_USING_SELRECT

        point_Get mouse_prev        ;// we also need to clean up the previous display
        invoke gdi_Blit_this_point

        lea eax, mouse_selrect
        invoke gdi_Blit_rect

    .ENDIF

    ;// build the invalidate rect for the main window
    ;// we only want to do this if any of the rects are built
    ;// we also have to clip both rects so they fall on the screen

    .IF DWORD PTR gdi_bEraseValid

        sub esp, SIZEOF RECT
        st_rect TEXTEQU <(RECT PTR [esp])>

        ;// check how we invalidate the window

        .IF (gdi_bEraseValid && gdi_bBlitValid )

            ;// make sure both are really valid
            IFDEF DEBUGBUILD

                .IF !gdi_bBlitPoint
                    point_GetTL gdi_blit_rect
                    DEBUG_IF <eax==gdi_blit_rect.right && edx==gdi_blit_rect.bottom>
                .ENDIF

                .IF !gdi_bErasePoint
                    point_GetTL gdi_erase_rect
                    DEBUG_IF <eax==gdi_erase_rect.right && edx==gdi_erase_rect.bottom>
                .ENDIF

            ENDIF

            ;// combine and xfer to what we're about to invalidtae

            point_GetTL gdi_erase_rect
            point_MinTL gdi_blit_rect
            point_MaxTL gdi_client_rect
            point_Sub   GDI_GUTTER
            point_SetTL st_rect

            point_GetBR gdi_erase_rect
            point_MaxBR gdi_blit_rect
            point_MinBR gdi_client_rect
            point_Sub GDI_GUTTER
            point_SetBR st_rect

        .ELSEIF gdi_bEraseValid

            ;// make sure its really valid
            IFDEF DEBUGBUILD

                .IF !gdi_bErasePoint
                    point_GetTL gdi_erase_rect
                    DEBUG_IF <eax==gdi_erase_rect.right && edx==gdi_erase_rect.bottom>
                .ENDIF

            ENDIF

            ;// xfer to what we're about to invalidtae

            point_GetTL gdi_erase_rect
            point_MaxTL gdi_client_rect
            point_Sub GDI_GUTTER
            point_SetTL st_rect

            point_GetBR gdi_erase_rect
            point_MinBR gdi_client_rect
            point_Sub GDI_GUTTER
            point_SetBR st_rect

        .ELSE ;//IF gdi_bBlitValid only

            ;// make sure its really valid
            IFDEF DEBUGBUILD

                .IF !gdi_bBlitPoint
                    point_GetTL gdi_blit_rect
                    DEBUG_IF <eax==gdi_blit_rect.right && edx==gdi_blit_rect.bottom>
                .ENDIF

            ENDIF

            ;// xfer to what we're about to invalidtae

            point_GetTL gdi_blit_rect
            point_MaxTL gdi_client_rect
            point_Sub GDI_GUTTER
            point_SetTL st_rect

            point_GetBR gdi_blit_rect
            point_MinBR gdi_client_rect
            point_Sub GDI_GUTTER
            point_SetBR st_rect

        .ENDIF


        INVAL_TRACE LINEFEED

        IFDEF INVAL_USE_TRACE

            mov ecx, esp
            ASSUME ecx:PTR RECT
            invoke wsprintfA, ADDR inval_buf, ADDR inval_rect, [ecx].left, [ecx].top, [ecx].right, [ecx].bottom
            invoke OutputDebugStringA, ADDR inval_buf

            lea ecx, gdi_erase_rect
            invoke wsprintfA, ADDR inval_buf, ADDR inval_rect, [ecx].left, [ecx].top, [ecx].right, [ecx].bottom
            invoke OutputDebugStringA, ADDR inval_buf

            lea ecx, gdi_blit_rect
            invoke wsprintfA, ADDR inval_buf, ADDR inval_rect, [ecx].left, [ecx].top, [ecx].right, [ecx].bottom
            invoke OutputDebugStringA, ADDR inval_buf

        ENDIF

        INVAL_TRACE LINEFEED

        mov eax, esp
        invoke InvalidateRect, hMainWnd, eax, 0
        DEBUG_IF <!!eax>

        add esp, SIZEOF RECT
        st_rect TEXTEQU <>

    .ENDIF  ;// valid erase or blit rect

    ;// finally, we put osc_hover or pin hover at the start of the I list

    xor eax, eax

    .IF pin_hover

    push esi
    push ebp

        GET_PIN pin_hover, esi
        PIN_TO_OSC esi, esi
        jmp osc_hover_move_to_head

    .ENDIF

    .IF osc_hover

    push esi
    push ebp

        GET_OSC_FROM esi, osc_hover

    osc_hover_move_to_head:

        stack_Peek gui_context, ebp
        dlist_MoveToHead oscI, esi,,[ebp]

        ;// this is safe to use whithout extra testing
        ;// MoveToHead first checks if pPrevI is non-zero
        ;// that means that there IS a prev item, AND the object is in the list

    pop ebp
    pop esi

    .ENDIF

    ret

gdi_Invalidate ENDP


ASSUME_AND_ALIGN



.DATA

    ;// inval jump tables

    hintpin_erase_rect_jump LABEL DWORD

        dd  OFFSET  hintpin_erase_rect_hide ;// hidden
        dd  OFFSET  hintpin_erase_rect_TFB  ;// bussed analog input
        dd  OFFSET  hintpin_erase_rect_TFS  ;// connected analog input
        dd  OFFSET  hintpin_erase_rect_TF   ;// unconnected analog input
        dd  OFFSET  hintpin_erase_rect_LFB  ;// bussed logic input
        dd  OFFSET  hintpin_erase_rect_LFS  ;// connected logic input
        dd  OFFSET  hintpin_erase_rect_LF   ;// unconnected logic input
        dd  OFFSET  hintpin_erase_rect_FB   ;// bussed output
        dd  OFFSET  hintpin_erase_rect_FS   ;// connected output
        dd  OFFSET  hintpin_erase_rect_FT   ;// unconnected output


    hintpin_erase_conn_jump LABEL DWORD

        dd  OFFSET  hintpin_erase_conn_hide ;// hidden
        dd  OFFSET  hintpin_erase_conn_TFB  ;// bussed analog input
        dd  OFFSET  hintpin_erase_conn_TFS  ;// connected analog input
        dd  OFFSET  hintpin_erase_conn_TF   ;// unconnected analog input
        dd  OFFSET  hintpin_erase_conn_LFB  ;// bussed logic input
        dd  OFFSET  hintpin_erase_conn_LFS  ;// connected logic input
        dd  OFFSET  hintpin_erase_conn_LF   ;// unconnected logic input
        dd  OFFSET  hintpin_erase_conn_FB   ;// bussed output
        dd  OFFSET  hintpin_erase_conn_FS   ;// connected output
        dd  OFFSET  hintpin_erase_conn_FT   ;// unconnected output


    hintpin_blit_rect_jump  LABEL DWORD

        dd  OFFSET  hintpin_blit_rect_hide  ;// hidden
        dd  OFFSET  hintpin_blit_rect_TFB   ;// bussed analog input
        dd  OFFSET  hintpin_blit_rect_TFS   ;// connected analog input
        dd  OFFSET  hintpin_blit_rect_TF    ;// unconnected analog input
        dd  OFFSET  hintpin_blit_rect_LFB   ;// bussed logic input
        dd  OFFSET  hintpin_blit_rect_LFS   ;// connected logic input
        dd  OFFSET  hintpin_blit_rect_LF    ;// unconnected logic input
        dd  OFFSET  hintpin_blit_rect_FB    ;// bussed output
        dd  OFFSET  hintpin_blit_rect_FS    ;// connected output
        dd  OFFSET  hintpin_blit_rect_FT    ;// unconnected output


    hintpin_blit_conn_jump  LABEL DWORD

        dd  OFFSET  hintpin_blit_conn_hide  ;// time to set
        dd  OFFSET  hintpin_blit_conn_TFB   ;// bussed analog input
        dd  OFFSET  hintpin_blit_conn_TFS   ;// connected analog input
        dd  OFFSET  hintpin_blit_conn_TF    ;// unconnected analog input
        dd  OFFSET  hintpin_blit_conn_LFB   ;// bussed logic input
        dd  OFFSET  hintpin_blit_conn_LFS   ;// connected logic input
        dd  OFFSET  hintpin_blit_conn_LF    ;// unconnected logic input
        dd  OFFSET  hintpin_blit_conn_FB    ;// bussed output
        dd  OFFSET  hintpin_blit_conn_FS    ;// connected output
        dd  OFFSET  hintpin_blit_conn_FT    ;// unconnected output


    inval_connecting_jump   LABEL DWORD

        dd  OFFSET  inval_connecting_hide   ;// hidden
        dd  OFFSET  inval_connecting_TFB    ;// bussed analog input
        dd  OFFSET  inval_connecting_TFS    ;// connected analog input
        dd  OFFSET  inval_connecting_TF     ;// unconnected analog input
        dd  OFFSET  inval_connecting_LFB    ;// bussed logic input
        dd  OFFSET  inval_connecting_LFS    ;// connected logic input
        dd  OFFSET  inval_connecting_LF     ;// unconnected logic input
        dd  OFFSET  inval_connecting_FB     ;// bussed output
        dd  OFFSET  inval_connecting_FS     ;// connected output
        dd  OFFSET  inval_connecting_FT     ;// unconnected output



END




