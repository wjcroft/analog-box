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
;//     ABox_mouse.asm      mouse handlers and data
;//
;//
;//
;// TOC
;//
;// mouse_find_hover
;//
;// mouse_wm_mousemove_proc
;//
;//     mouse_move_desktop
;//     mouse_select_osc
;//     mouse_unselect_osc
;//     mouse_move_osc
;//     mouse_control_osc
;//     mouse_connecting_pin
;//     mouse_moving_pin
;//     mouse_using_selrect
;//
;// mouse_wm_lbuttondown_proc
;//
;// mouse_wm_lbuttonup_proc
;//
;//     mouse_done_moving_screen
;//     mouse_done_moving_osc
;//     mouse_done_controlling_osc
;//     mouse_done_select_osc
;//     mouse_done_unselect_osc
;//     mouse_done_connecting_pin
;//     mouse_done_moving_pin
;//
;// mouse_wm_rbuttondown_proc
;//
;// mouse_wm_rbuttonup_proc
;//
;//     mouse_show_desk_popup
;//     mouse_show_pins_popup
;//     mouse_show_osc_popup
;//
;// mouse_set_osc_hover
;// mouse_set_con_hover
;// mouse_set_pin_hover
;//
;// mouse_reset_all_hovers
;//
;// mouse_set_osc_down
;// mouse_set_con_down
;// mouse_set_pin_down
;//
;// mouse_reset_osc_down
;// mouse_reset_pin_down
;//
;// mouse_reset_state
;//
;// mouse_set_pin_query
;//
;// mouse_hittest_all
;// mouse_hittest_osc
;// mouse_hittest_pin

OPTION CASEMAP:NONE

.586
.MODEL FLAT

        .NOLIST
        include <Abox.inc>
        include <triangles.inc>
        include <gdi_pin.inc>
        .LIST

.DATA


;//////////////////////////////////////////////////////////////////////////////
;//
;//                     most functions require at least mouse now
;// position tracking   and some require mouse delta
;//                     so we store the three points nessesary to track these
;//                     these are always in GDI coords

    mouse_now   POINT {}    ;// where the mouse is now
    mouse_delta POINT {}    ;// how far the mouse has moved
    mouse_prev  POINT {}    ;// previous known position

    mouse_selrect   RECT {} ;// used only for sel rect

    mouse_down      POINT{} ;// where mouse came down

;//
;// position tracking
;//
;//
;//////////////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////
;//
;//     M O U S E   H A N D L E R S
;//
;//

    ;// use this function to enter a mouse handler
    ;// it saves the registers and updates the current location

    ENTER_MOUSE_HANDLER MACRO

    push ebx                    ;// store ebx

        mov ecx, [esp+20]       ;// get the point ( extra 4 added to account for push )

    push ebp                    ;// store ebp

    push edi                    ;// store edi

        mov eax, mouse_now.x    ;// get the old mouse.x
        mov ebx, ecx            ;// xfer point to ebx
        mov edx, mouse_now.y    ;// get the old mouse.y
        sar ecx, 16             ;// make ecx=Y
        movsx ebx, bx           ;// extend bx into ebx=X

    push esi                    ;// store esi

        stack_Peek gui_context, ebp ;// always load the current context

        mov mouse_prev.x, eax   ;// store old mouse_now as new mouse_prev
        add ebx, GDI_GUTTER_X   ;// offset new mouse now by the gutter
        mov mouse_prev.y, edx   ;// store old mouse_now as new mouse_prev
        add ecx, GDI_GUTTER_Y   ;// offset new mouse now by the gutter

        neg eax
        neg edx

        add eax, ebx            ;// compute mouse delta
        add edx, ecx            ;// compute mouse delta

        mov mouse_now.x, ebx    ;// store new mouse now
        mov mouse_now.y, ecx    ;// store new mouse now

        mov mouse_delta.x, eax  ;// store mouse delta
        mov mouse_delta.y, edx  ;// store mouse delta

        ;// stack looks like this

        ;// esi edi ebp ebx ret hwnd    msg wparam  lparam
        ;// 00  04  08  0C  10  14      18  1C      20

        MOUSE_WP_MSG    TEXTEQU <[esp+18h]>

        ENDM

    ;// all handlers must exit to
    ;//
    ;//     mouse_proc_exit
    ;// or  set_head_and_exit
    ;//





    MOUSE_CHECK_IF_MOVED MACRO fail_jump:req

        LOCAL J1, J2

            point_Get mouse_down
            sub eax, mouse_now.x
            jns J1
            neg eax
        J1: sub edx, mouse_now.y
            jns J2
            neg edx
        J2: add eax, edx
            sub eax, mouse_move_limit
            jbe fail_jump   ;// mouse_proc_exit

        ENDM



;//
;//     M O U S E   H A N D L E R S
;//
;//
;////////////////////////////////////////////////////////////////////



;/////////////////////////////////////////////////////////////////////
;//
;//
;//     S T A T E   M A I N T A I N A N C E
;//
;//


    ;// hover

    osc_hover  dd  0 ;// which oscillator (if any) is hovered
    pin_hover  dd  0 ;// which pin (if any) is being hovered
                     ;// desk hover = both off

    ;// down         ;// if any are set, then assume hMainWnd has the capture

    pin_down   dd  0 ;// what pin (if any) the mouse fell down on
    osc_down   dd  0 ;// which osc (if any) the mouse fell down on

    ;// button interlock

    mouse_state         dd  0   ;// uses MK_RBUTTON and MK_LBUTTON

    ;// lower byte reserved for MK_BUTTON values

    PIN_HAS_MOVED EQU 100h  ;// interlock for moving a pin
    OSC_HAS_MOVED EQU 200h  ;// interlock for moving a single osc
    SEL_HAS_MOVED EQU 400h  ;// interlock for drawing a selrect

    ;// see app_bFlags for more information

    mouse_move_limit    dd  2   ;// limit for detecting motion

    ;// detection of pin_connect_special_18 mode

    mouse_pin_connect_is_swappable  dd 0

    ;// use these to manage the state

    mouse_set_osc_hover     PROTO
    mouse_set_con_hover     PROTO
    mouse_set_pin_hover     PROTO

    mouse_reset_all_hovers  PROTO

    mouse_set_pin_query     PROTO

    mouse_set_osc_down      PROTO
    mouse_set_con_down      PROTO
    mouse_set_pin_down      PROTO

;//
;//
;//     S T A T E   M A I N T A I N A N C E
;//
;//
;/////////////////////////////////////////////////////////////////////






;//////////////////////////////////////////////////////////////////////////////
;//
;//                                 is accomplished in two levels
;//     H I T   T E S T I N G       1) by color
;//                                 2) by geometry
;//
;//     previous scheme was far too bulky and difficult to debug
;//     this new scheme has just one function
;//     it returns flags and maybe a pointer
;//     use mouse_hittest_flags to tell the function what to ignore
;//
;//     mouse_hittest_all
;//
;//         return values (check in stated order)
;//
;//         flag    description         esi         ebx   required flag
;//         ----    --------------      ----------  ----  -------------
;//         zero    nothing is hit      ??          ??
;//         carry   control is hit      osc_object  ??    MHT_CONTROLS
;//         sign    a pin is hit        osc_object  apin  MHT_PINS
;//         none    osc is hit          osc_object
;//
;//         MHT_CLOSE returns nz if mouse is close to an osc

        mouse_hittest_all PROTO ;// use this function to hit test
        mouse_hittest_osc PROTO ;// called by hittest_all
        mouse_hittest_pin PROTO ;// called by hittest_osc

        mouse_hit_flags dd 0    ;// this flag allows us to hit test just osc,
        MHT_PINS        equ 1   ;// test pins
        MHT_CONTROLS    equ 2   ;// test controls
        MHT_CLOSE       equ 4   ;// update the show pins flags if nothing is hit


;//                     color testing just grabs the pixel's color index
;// 1) color testing    the color set has been carefully prepared to
;//                     account for this test
;//                     see gdi_resource for the list

        mouse_pDest dd  0   ;// pointer to where the mouse is on the gdi display surface

;//                         takes longer, and uses the shape functions
;// 2) geomtry testing      so pDest must be defined previously
;//                         there are two functions, hittest_osc and hittest_pin

    ;// mouse rect checks if we're close enough to an osc to bother testing further

    ;// ALIGN 16
    ;// mouse_rect  RECT  {}    ;// mouse rect is a rect for hit testing
                                ;// it is centered on the mouse
                                ;// and expanded to include any posible pin

    ;// mouse rect building

    ;// MOUSE_FULL_RECT_X equ 64    ;// full width of rect
    ;// MOUSE_FULL_RECT_Y equ MOUSE_FULL_RECT_X

    ;// MOUSE_HALF_RECT_X equ MOUSE_FULL_RECT_X / 2
    ;// MOUSE_HALF_RECT_Y equ MOUSE_FULL_RECT_Y / 2

;//
;//     H I T   T E S T I N G
;//
;//
;//////////////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////
;//
;//                             these are based on the jump index
;//     status string indexes   use SET_STATUS to schedule a display
;//

pin_status_index    LABEL DWORD

    dd  0                       ;// hidden
    dd  status_HOVER_PIN_BUS_IN ;// bussed analog input
    dd  status_HOVER_PIN_CON    ;// connected analog input
    dd  status_HOVER_PIN_UNCON  ;// unconnected analog input
    dd  status_HOVER_PIN_BUS_IN ;// bussed logic input
    dd  status_HOVER_PIN_CON    ;// connected logic input
    dd  status_HOVER_PIN_UNCON  ;// unconnected logic input
    dd  status_HOVER_PIN_BUS_OUT;// bussed output
    dd  status_HOVER_PIN_CON    ;// connected output
    dd  status_HOVER_PIN_UNCON  ;// unconnected output


;//
;//     status string indexes
;//                             these are based on the jump index
;//
;////////////////////////////////////////////////////////////////////





.CODE



;//////////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////////
;////
;////
;////   M O U S E   H A N D L E R S
;////
;////
;//////////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////////

;// commonly used functions



;////////////////////////////////////////////////////////////////////
;//
;//                         just find a hover
;//     mouse_find_hover
;//                         jumped to by mouse_wm_mousemove_proc, among others
;//
ASSUME_AND_ALIGN
mouse_find_hover PROC PRIVATE

    ;// unfortunately, we have to condition the points
    ;// this caused by task switching when abox2 gets the focus
    ;// but not all the time

    point_Get mouse_now
    cmp eax, GDI_GUTTER_X
    jle nothing_hit
    cmp edx, GDI_GUTTER_Y
    jle nothing_hit

    cmp eax, gdi_client_rect.right
    jge nothing_hit
    cmp edx, gdi_client_rect.bottom
    jge nothing_hit


    mov mouse_hit_flags, MHT_CLOSE + MHT_PINS + MHT_CONTROLS
    invoke mouse_hittest_all
    jz  nothing_hit
    jc  control_hit
    js  pin_hit

    osc_hit:

        cmp esi, osc_hover  ;// check if we're the hover
        jnz @F              ;// set new hover if not
        ;// we are the same as hover
        test app_bFlags, APP_MODE_CON_HOVER ;// check if we had control hover
        jz mouse_proc_exit                  ;// exit if not
    @@:
        ;// this is a new osc hover
        invoke mouse_set_osc_hover
        SET_STATUS status_HOVER_OSC
        jmp mouse_proc_exit_set_head

    ALIGN 16
    control_hit:

        cmp esi, osc_hover
        jnz @F
        test app_bFlags, APP_MODE_OSC_HOVER ;// check if we had osc hover
        jz mouse_proc_exit
    @@:
        ;// this is now con hover
        invoke mouse_set_con_hover
        SET_STATUS status_HOVER_CON
        jmp mouse_proc_exit_set_head

    ALIGN 16
    pin_hit:

        cmp ebx, pin_hover          ;// same as current pin hover ?
        jz mouse_proc_exit
        invoke mouse_set_pin_hover  ;// set the new pin hover
        jmp mouse_proc_exit_set_head

    ALIGN 16
    nothing_hit:

        ;// make sure all hovers are off and the status updated

        invoke mouse_reset_all_hovers
        SET_STATUS status_HOVER_DESK
        jmp mouse_proc_exit

mouse_find_hover ENDP
;//
;//                         just find a hover
;//     mouse_find_hover
;//                         jumped to by mouse_wm_mousemove_proc, among others
;//
;////////////////////////////////////////////////////////////////////
























;////////////////////////////////////////////////////////
;//
;//     MOUSE EXIT POINTS
;//                         all handlers exit here
;//                         this is at the top, so BTB defaults to predicted taken

    ;// function exit to set the new hover as the zlist head
    ASSUME_AND_ALIGN
    mouse_proc_exit_set_head::

        ;// esi MUST be the new hover
        ;// if a pin has the hover, esi must be it's owner

        ASSUME esi:PTR OSC_OBJECT
        ASSUME ebp:PTR LIST_CONTEXT
        dlist_MoveToHead oscZ, esi,,[ebp]
        jmp mouse_proc_exit


    ;// common exit point for all mouse handlers
    ASSUME_AND_ALIGN
    mouse_proc_exit::

        ;// here, we do a little clean up

        invoke app_Sync

        DEBUG_CLOCKER_END mouse

        UPDATE_DEBUG

        pop esi
        pop edi
        pop ebp
        pop ebx

        xor eax, eax

        ret 10h

;//
;//     MOUSE EXIT POINTS
;//                         all handlers exit here
;//
;////////////////////////////////////////////////////////




;//////////////////////////////////////////////////////////////
;//
;//     WM_MOUSEMOVE        is by far the most complicated
;//
;//
;// jumped to by mainWndProc
;// this block is a jump station to another proc

ASSUME_AND_ALIGN
mouse_wm_mousemove_proc PROC PUBLIC ;// STDCALL uses ebx esi edi hWnd:dword, msg:dword, keys:dword, spoint:dword

    DEBUG_CLOCKER_BEGIN mouse

    ENTER_MOUSE_HANDLER

    mov ecx, app_bFlags

    test ecx,   APP_MODE_USING_SELRECT  OR  \
                APP_MODE_MOVING_SCREEN  OR  \
                APP_MODE_SELECT_OSC     OR  \
                APP_MODE_UNSELECT_OSC   OR  \
                APP_MODE_MOVING_OSC     OR  \
                APP_MODE_MOVING_OSC_SINGLE  OR \
                APP_MODE_CONTROLLING_OSC OR \
                APP_MODE_CONNECTING_PIN OR  \
                APP_MODE_MOVING_PIN

    jz mouse_find_hover

    bt ecx, LOG2(APP_MODE_MOVING_SCREEN)
    jc mouse_move_desktop

    bt ecx, LOG2(APP_MODE_USING_SELRECT)    ;// put this before SELCECT and UNSELECT
    jc mouse_using_selrect

    bt ecx, LOG2(APP_MODE_SELECT_OSC)
    jc mouse_select_osc

    bt ecx, LOG2(APP_MODE_UNSELECT_OSC)
    jc mouse_unselect_osc

    bt ecx, LOG2(APP_MODE_MOVING_OSC)
    jc mouse_move_osc

    bt ecx, LOG2(APP_MODE_MOVING_OSC_SINGLE)
    jc mouse_move_osc_single

    bt ecx, LOG2(APP_MODE_CONTROLLING_OSC)
    jc mouse_control_osc

    bt ecx, LOG2(APP_MODE_CONNECTING_PIN)
    jc mouse_connecting_pin

    bt ecx, LOG2(APP_MODE_MOVING_PIN)
    jc mouse_moving_pin

    jmp mouse_find_hover    ;// we're not doing anything but checking the hover

mouse_wm_mousemove_proc ENDP
;//
;//  MOUSEMOVE
;//
;//
;//////////////////////////////////////////////////////////////




    ;////////////////////////////////////////////////////////////////////
    ;//
    ;//                             moving the desktop
    ;//     mouse_move_desktop
    ;//                             jumped to by mouse_wm_mousemove_proc
    ;//
    ASSUME_AND_ALIGN
    mouse_move_desktop   PROC PRIVATE

        or mouse_state, SCR_HAS_MOVED
        invoke context_MoveAll
        jmp mouse_proc_exit

    mouse_move_desktop   ENDP
    ;//
    ;//                             moving the desktop
    ;//     mouse_move_desktop
    ;//                             jumped to by mouse_wm_mousemove_proc
    ;//
    ;////////////////////////////////////////////////////////////////////



    ;////////////////////////////////////////////////////////////////////
    ;//
    ;//                         shift is down and we want to add osc's to current selection
    ;//     mouse_select_osc
    ;//                         jumped to by mouse_wm_mousemove_proc
    ASSUME_AND_ALIGN
    mouse_select_osc PROC PRIVATE

        mov mouse_hit_flags, 0      ;// just look for oscs
        invoke mouse_hittest_all    ;// hit test the surface
        jz mouse_proc_exit          ;// exit if nothing is hit

    osc_is_hit:

        ASSUME ebp:PTR LIST_CONTEXT
        ASSUME esi:PTR OSC_OBJECT

        OSC_TO_BASE esi, edi
        mov eax, VK_SHIFT   ;// COMMAND_SELECT
        invoke [edi].gui.Command

        jmp mouse_proc_exit_set_head            ;// exit to head setter


    mouse_select_osc ENDP
    ;//
    ;//                         shift is down and we want to add osc's to current selection
    ;//     mouse_select_osc
    ;//                         jumped to by mouse_wm_mousemove_proc
    ;////////////////////////////////////////////////////////////////////


    ;////////////////////////////////////////////////////////////////////
    ;//
    ;//                         shift is down and we want to remove osc's to current selection
    ;//     mouse_unselect_osc
    ;//                         jumped to by mouse_wm_mousemove_proc
    ASSUME_AND_ALIGN
    mouse_unselect_osc PROC PRIVATE

        mov mouse_hit_flags, 0  ;// just look for oscs
        invoke mouse_hittest_all
        jz mouse_proc_exit

    osc_is_hit:

        ASSUME ebp:PTR LIST_CONTEXT
        ASSUME esi:PTR OSC_OBJECT

        clist_Remove oscS, esi,,[ebp]               ;// remove from select list
        GDI_INVALIDATE_OSC HINTI_OSC_LOST_SELECT    ;// make it redisplay

        ;// if this osc had a lock, we have to unselect the lock as well

        jmp mouse_proc_exit_set_head


    mouse_unselect_osc ENDP
    ;//
    ;//                         shift is down and we want to add osc's to current selection
    ;//     mouse_unselect_osc
    ;//                         jumped to by mouse_wm_mousemove_proc
    ;////////////////////////////////////////////////////////////////////



    ;////////////////////////////////////////////////////////////////////
    ;//
    ;//                             button is down and we're moving osc_down only
    ;//     mouse_move_osc_single
    ;//                             jumped to by mouse_wm_mousemove_proc
    ASSUME_AND_ALIGN
    mouse_move_osc_single PROC

        ;// make sure we have actually moved first
        ;// we do this to prevent setting the flag

        test mouse_state, OSC_HAS_MOVED
        jnz mouse_move_osc

        MOUSE_CHECK_IF_MOVED mouse_proc_exit
        jmp mouse_move_osc

    mouse_move_osc_single ENDP
    ;//
    ;//                             button is down and we're moving osc_down only
    ;//     mouse_move_osc_single
    ;//                             jumped to by mouse_wm_mousemove_proc
    ;////////////////////////////////////////////////////////////////////








    ;////////////////////////////////////////////////////////////////////
    ;//
    ;//                         button is down and we're moving osc_down, plus it's dependants
    ;//     mouse_move_osc
    ;//                         jumped to by mouse_wm_mousemove_proc
    ASSUME_AND_ALIGN
    mouse_move_osc PROC PRIVATE

    ;// the logic for this is:
    ;// 1) move the osc, no matter what
    ;// 2) if osc_down is selected --
    ;//     move selection list
    ;//         if any items in selection list are locked
    ;//             move all of those
    ;//     set a has moved bit for everything moved
    ;//     do a second scan to clean up the bits
    ;// 3) else if osc is locked
    ;//     move items in lock list

        DEBUG_IF <!!osc_down>

        GET_OSC_FROM esi, osc_down

        OSC_TO_BASE esi, edi        ;// get the base class

    ;// important !!!
    ;// keep these adjacent !!      ;// keep adjacent !!
        EXTERNDEF mouse_move_osc_return_ptr:NEAR
        invoke [edi].gui.Move       ;// move the osc
        mouse_move_osc_return_ptr:: ;// needed by osc_label.asm
    ;// keep these adjacent !!      ;// keep adjacent !!
    ;// important !!!


        or mouse_state, OSC_HAS_MOVED   ;// set the state

        test app_bFlags, APP_MODE_MOVING_OSC_SINGLE
        jnz mouse_proc_exit

        xor eax, eax                ;// clear for testing

        cmp eax, clist_Next(oscS,esi) ;//[esi].pNextS       ;// selected ?
        jnz move_sel1_enter

        cmp eax, clist_Next(oscL,esi)   ;//[esi].pNextL     ;// locked
        jz mouse_proc_exit          ;// exit if not

    move_locked_top:    ;// move locked objects

        clist_GetNext oscL, esi ;// get the next osc
        cmp esi, osc_down       ;// done yet ?
        je mouse_proc_exit      ;// exit if so

        OSC_TO_BASE esi, edi    ;// get the base class
        invoke [edi].gui.Move   ;// move the osc

        jmp move_locked_top     ;// next osc


    ;// move selected items, this takes two scan
    ;// the first scan moves and sets a has_moved bit
    ;// the second cleans up the bit
    ;//
    ;// this is required if two selected items are on the same lock list
    ;// then the third item in the lock list will get moved twice

        ;// scan 1

        move_sel1_top:  ;// move selected and attached locked objects

            clist_GetNext oscS, esi     ;// clists iterate first
            cmp esi, osc_down           ;// done yet ?
            je move_sel2_enter          ;// goto next part if done

            test [esi].dwHintOsc, HINTOSC_STATE_PROCESSED
            jnz move_sel1_top           ;// already moved ?

            OSC_TO_BASE esi, edi        ;// get the base class
            invoke [edi].gui.Move       ;// move the osc

        move_sel1_enter:

            or [esi].dwHintOsc, HINTOSC_STATE_PROCESSED

            cmp clist_Next(oscL,esi),0  ;//[esi].pNextL, 0          ;// locked ?
            jz move_sel1_top            ;// next osc if not

            push esi                    ;// save so we know when to stop

        move_sel1_locked_top:           ;// top of the loop

            clist_GetNext oscL, esi     ;// get next locked item
            cmp esi, [esp]              ;// compare with where we started
            je move_sel1_locked_done    ;// done if same

            test [esi].dwHintOsc, HINTOSC_STATE_PROCESSED
            jnz move_sel1_locked_top    ;// already moved ?

            OSC_TO_BASE esi, edi        ;// get the base class
            or [esi].dwHintOsc, HINTOSC_STATE_PROCESSED
            invoke [edi].gui.Move       ;// move the osc

            jmp move_sel1_locked_top

        move_sel1_locked_done:          ;// done with move selected locked

            pop esi                     ;// retrive esi
            jmp move_sel1_top           ;// jmp to top of selected loop


        ;// scan 2  turn off the PROCESSED bits

        move_sel2_top:      ;// clean up from previous scan

            clist_GetNext oscS, esi     ;// clists iterate first
            cmp esi, osc_down           ;// done yet ?
            je mouse_proc_exit          ;// exit if done

            test [esi].dwHintOsc, HINTOSC_STATE_PROCESSED
            jz move_sel2_top            ;// already reset

        move_sel2_enter:

            and [esi].dwHintOsc, NOT HINTOSC_STATE_PROCESSED

            cmp clist_Next(oscL,esi),0  ;//[esi].pNextL, 0          ;// locked ?
            jz move_sel2_top            ;// next osc if not

        ;// reset the unselected lock list items

            push esi                    ;// save so we know when to stop

        move_sel2_locked_top:           ;// top of the loop

            clist_GetNext oscL, esi     ;// get next locked item
            cmp esi, [esp]              ;// compare with where we started
            je move_sel2_locked_done    ;// done if same

            and [esi].dwHintOsc, NOT HINTOSC_STATE_PROCESSED

            jmp move_sel2_locked_top

        move_sel2_locked_done:          ;// done with move selected locked

            pop esi                 ;// retrive esi
            jmp move_sel2_top       ;// jmp to top of selected loop


    mouse_move_osc ENDP
    ;//
    ;//                         button is down and we're moving osc_down, plus it's dependants
    ;//     mouse_move_osc
    ;//                         jumped to by mouse_wm_mousemove_proc
    ;////////////////////////////////////////////////////////////////////


    ;////////////////////////////////////////////////////////////////////
    ;//
    ;//
    ;//     mouse_control_osc       we're controlling osc_down
    ;//                             jumped to by mouse_wm_mousemove_proc
    ASSUME_AND_ALIGN
    mouse_control_osc PROC PRIVATE

        DEBUG_IF <!!osc_down>

        ;// controlling an osc
        mov eax, MOUSE_WP_MSG
        GET_OSC_FROM esi, osc_down
        OSC_TO_BASE esi, edi
        invoke [edi].gui.Control
        DEBUG_IF <eax & NOT CON_HAS_MOVED>  ;// return value is wrong
        or mouse_state, eax

        jmp mouse_proc_exit

    mouse_control_osc ENDP
    ;//
    ;//
    ;//     mouse_control_osc       we're controlling osc_down
    ;//                             jumped to by mouse_wm_mousemove_proc
    ;////////////////////////////////////////////////////////////////////




    ;////////////////////////////////////////////////////////////////////
    ;//
    ;//                             pin_down is being connected
    ;//     mouse_connecting_pin
    ;//                             jumped to by mouse_wm_mousemove_proc
    ASSUME_AND_ALIGN
    ;//
    mouse_connecting_pin PROC PRIVATE

        ASSUME ebp:PTR LIST_CONTEXT

        GET_PIN pin_down, ebx
        PIN_TO_OSC ebx, esi

        ;// see if we're hitting anything, dont test controls

        mov mouse_hit_flags, MHT_PINS + MHT_CLOSE
        invoke mouse_hittest_all
        jz hitting_nothing
        js hitting_pin

        hitting_osc:

            .IF !mouse_pin_connect_is_swappable
                SET_STATUS status_CONNECTING
            .ELSE
                SET_STATUS status_CONNECTING_swap
            .ENDIF
            SET_STATUS status_CONNECTING
            cmp esi, osc_hover
            jz mouse_proc_exit          ;// same osc ?
            invoke mouse_set_osc_hover
            jmp mouse_proc_exit_set_head

        hitting_pin:

            cmp ebx, pin_hover
            jz mouse_proc_exit          ;// same pin ?
            invoke mouse_set_pin_query  ;// will set the status
            jmp mouse_proc_exit_set_head

        hitting_nothing:

            invoke mouse_reset_all_hovers

            cmp mouse_pin_connect_is_swappable, 0
            jne @F
                SET_STATUS status_CONNECTING
                jmp mouse_proc_exit
            @@: SET_STATUS status_CONNECTING_swap
                jmp mouse_proc_exit

    mouse_connecting_pin ENDP
    ;//
    ;//                         pin_down is being connected
    ;//     mouse_connecting_pin
    ;//                         jumped to by mouse_wm_mousemove_proc
    ;////////////////////////////////////////////////////////////////////



    ;////////////////////////////////////////////////////////////////////
    ;//
    ;//                             pin_down is being connected
    ;//     mouse_moving_pin
    ;//                             jumped to by mouse_wm_mousemove_proc
    ASSUME_AND_ALIGN
    ;//
    mouse_moving_pin PROC PRIVATE

        ASSUME ebp:PTR LIST_CONTEXT

        ;// make sure we've moved a little bit

            .IF !(mouse_state & PIN_HAS_MOVED)  ;// do we already know this ?

                MOUSE_CHECK_IF_MOVED mouse_proc_exit

            ;// now we know the mouse has moved

                or mouse_state, PIN_HAS_MOVED

            .ENDIF

        ;// load the pin and the osc

            GET_PIN pin_down, ebx
            DEBUG_IF <!!ebx>
            PIN_TO_OSC ebx, esi

        ;// determine XY = mouse_now - osc.rectTL

            fild mouse_now.y
            fisub [esi].rect.top    ;// Y
            fild mouse_now.x
            fisub [esi].rect.left   ;// X   Y

        ;// approximate pheta and store

            invoke pin_ComputePhetaFromXY
            fstp [ebx].pheta

        ;// invalidate and split

            GDI_INVALIDATE_PIN HINTI_PIN_PHETA_CHANGED

            jmp mouse_proc_exit

    mouse_moving_pin ENDP
    ;//
    ;//                         pin_down is being connected
    ;//     mouse_moving_pin
    ;//                         jumped to by mouse_wm_mousemove_proc
    ;////////////////////////////////////////////////////////////////////


    ;////////////////////////////////////////////////////////////////////
    ;//
    ;//
    ;//     mouse_using_selrect
    ;//                             jumped to by mouse_wm_mousemove_proc
    ASSUME_AND_ALIGN
    ;//
    mouse_using_selrect PROC PRIVATE

        ASSUME ebp:PTR LIST_CONTEXT

        ;// only do this if mouse moves more than one pixel
        ;// and don't bother if we already know this

        .IF !(mouse_state & SEL_HAS_MOVED)

        ;// check the distance

            MOUSE_CHECK_IF_MOVED mouse_proc_exit

        ;// we're moving now

            or mouse_state, SEL_HAS_MOVED

        ;// NOW we erase the previous sel rect
        ;// undo any selection, unless the shift key is down

            .IF !(app_bFlags & (APP_MODE_SELECT_OSC OR APP_MODE_UNSELECT_OSC))

                invoke context_UnselectAll

            .ENDIF

        .ENDIF

        ;// update the sel list by checking osc boundries against mouse_down and mouse_now

        ;// build the sel rect
        ;// test all onscreen oscs against it
        ;// if an osc is in the rect, add it to the sel list

        ;// build the selrect in the correct order

            point_Get mouse_now
            point_Get mouse_down, ebx, ecx

            cmp ebx, eax
            jge R1
            xchg ebx, eax
        R1: cmp ecx, edx
            jge R2
            xchg ecx, edx
        R2: point_SetTL mouse_selrect
            point_SetBR mouse_selrect, ebx, ecx

        ;// now we add oscs to oscs

        selrect_selecting:

            dlist_GetHead oscZ, esi, [ebp]
            jmp S1

        S2: dlist_GetNext oscZ, esi ;// next osc
        S1: test esi, esi           ;// done yet ?
            jz mouse_proc_exit      ;// exit if done

            test [esi].dwHintOsc, -1    ;// on screen ?
            jns S2                      ;// don't bother if not

            cmp ebx, [esi].rect.left    ;// test the rect
            jl S2
            cmp ecx, [esi].rect.top
            jl S2
            cmp eax, [esi].rect.right
            jg S2
            cmp edx, [esi].rect.bottom
            jg S2

            .IF app_bFlags & APP_MODE_UNSELECT_OSC

                cmp clist_Next(oscS,esi),0  ;//[esi].pNextS, 0          ;// already unselected ?
                jz S2                       ;// don't bother if unselected

                OSC_TO_BASE esi, edi
                mov eax, VK_CONTROL ;// COMMAND_UNSELECT
                invoke [edi].gui.Command

            .ELSE

                cmp clist_Next(oscS,esi),0  ;//[esi].pNextS, 0          ;// already selected ?
                jnz S2                      ;// don't bother if selected

                OSC_TO_BASE esi, edi
                mov eax, VK_SHIFT   ;// COMMAND_SELECT
                invoke [edi].gui.Command

            .ENDIF

            point_GetTL mouse_selrect   ;// reload the points
            point_GetBR mouse_selrect, ebx, ecx

            jmp S2

    mouse_using_selrect ENDP
    ;//                             jumped to by mouse_wm_mousemove_proc
    ;//
    ;//     mouse_using_selrect
    ;//
    ;////////////////////////////////////////////////////////////////////










;//
;//     WM_MOUSEMOVE
;//
;//
;//////////////////////////////////////////////////////////////







;//////////////////////////////////////////////////////////////////////////////////////////////
;//
;//                             always grabs the capture
;//     WM_LBUTTONDOWN          sets hover as well for clarity
;//
;//
;// jumped to by mainWndProc
ASSUME_AND_ALIGN
mouse_wm_lbuttondown_proc PROC  PUBLIC ;// STDCALL uses ebx esi edi hWnd:dword, msg:dword, keys:dword, spoint:dword

    ;// interlock with right button

    test mouse_state, MK_RBUTTON
    jz ok_to_continue
    xor eax, eax
    ret 10h

ok_to_continue:

    DEBUG_CLOCKER_BEGIN mouse

    or mouse_state, MK_LBUTTON

    ENTER_MOUSE_HANDLER

    DEBUG_IF <pin_down> ;// how'd we loose track ??

    DEBUG_IF <osc_hover && pin_hover>   ;// not sposed to have both set

    ;// step one is to make sure the label editor gets shut off

        .IF app_DlgFlags & DLG_LABEL
            invoke SetFocus, hMainWnd
        .ENDIF

    ;// see if osc down is already set

        xor esi, esi            ;// need this test because osc create sets osc down
        or esi, osc_down        ;// even though the button isn't down
        jnz mouse_proc_exit

    ;// L button down ALWAYS sets the capture

        invoke SetCapture, hMainWnd

    ;//
    ;// is it safe to say that whatever is hovered is correct ?
    ;//

        mov eax, app_CircuitSettings
        xor esi, esi
        xor ebx, ebx

        OR_GET_OSC_FROM esi, osc_hover
        jz check_pin_hover

        test [esi].dwHintOsc, HINTOSC_STATE_HAS_CON_HOVER
        jnz hitting_control

    hitting_osc:

        test eax, CIRCUIT_NOMOVE OR CIRCUIT_NOEDIT
        jnz mouse_proc_exit

        invoke mouse_set_osc_down

        unredo_BeginAction UNREDO_MOVE_OSC

        jmp mouse_proc_exit_set_head

    hitting_control:

        test eax, CIRCUIT_NOEDIT
        jnz mouse_proc_exit

        invoke mouse_set_con_down

        unredo_BeginAction UNREDO_CONTROL_OSC

        ;// controlling an osc
        mov eax, MOUSE_WP_MSG       ;// get the message
        OSC_TO_BASE esi, edi        ;// get the object's base class
        invoke [edi].gui.Control    ;// call the object's control function
        DEBUG_IF <eax & NOT CON_HAS_MOVED>  ;// return value is wrong
        or mouse_state, eax

        jmp mouse_proc_exit_set_head

    check_pin_hover:

        OR_GET_PIN pin_hover, ebx
        jz hitting_nothing

    hitting_pin:

        test eax, CIRCUIT_NOEDIT
        jnz mouse_proc_exit

        invoke mouse_set_pin_down

        xor edx, edx                            ;// = 0
        mov pin_connect_special_18, edx         ;// reset this
        mov mouse_pin_connect_is_swappable, edx ;// assume we can't

        ;// detect if we can swap

        ;// ebx must be connected input pin
        ;// or connected output

        OR_GET_PIN [ebx].pPin, edx      ;// connected ?
        jz hp_send_to_head_and_exit     ;// if not, just exit

        test [ebx].dwStatus, PIN_BUS_TEST   ;// bussed ?
        jnz hp_send_to_head_and_exit        ;// if so, just exit

        inc mouse_pin_connect_is_swappable      ;// we can swap

    ;// unredo_BeginAction UNREDO_CONNECT_PIN   this is done elsewhere

        hp_send_to_head_and_exit:

            PIN_TO_OSC ebx, esi
            jmp mouse_proc_exit_set_head


    hitting_nothing:    ;// so we're moving the screen

        invoke mouse_reset_all_hovers

        or app_bFlags, APP_MODE_MOVING_SCREEN

        unredo_BeginAction UNREDO_MOVE_SCREEN

        jmp mouse_proc_exit



mouse_wm_lbuttondown_proc ENDP
;//
;//                             always grabs the capture
;//     WM_LBUTTONDOWN          sets hover as well for clarity
;//
;//
;//////////////////////////////////////////////////////////////////////////////////////////////





;//////////////////////////////////////////////////////////////////////////////////////////////
;//
;//
;//     WM_LBUTTONUP
;//
;//
;// jumped to by mainWndProc
ASSUME_AND_ALIGN
mouse_wm_lbuttonup_proc PROC PUBLIC ;//  STDCALL uses ebx esi edi hWnd:dword, msg:dword, keys:dword, spoint:dword

    ;// iterlock with right button

    test mouse_state, MK_RBUTTON
    jz ok_to_continue
    xor eax, eax
    ret 10h

ok_to_continue:

    DEBUG_CLOCKER_BEGIN mouse

    and mouse_state, NOT MK_LBUTTON

    ENTER_MOUSE_HANDLER

    invoke ReleaseCapture   ;// lbutton up always releases the capture

    ;// see what mode we're in

    mov ecx, app_bFlags     ;// what ever we jump to should store ecx

    btr ecx, LOG2(APP_MODE_MOVING_SCREEN)
    jc mouse_done_moving_screen

    btr ecx, LOG2(APP_MODE_MOVING_OSC)
    jc mouse_done_moving_osc

    btr ecx, LOG2(APP_MODE_CONTROLLING_OSC)
    jc mouse_done_controlling_osc

    btr ecx, LOG2(APP_MODE_SELECT_OSC)
    jc mouse_done_select_osc

    btr ecx, LOG2(APP_MODE_UNSELECT_OSC)
    jc mouse_done_unselect_osc

    btr ecx, LOG2(APP_MODE_CONNECTING_PIN)
    jc mouse_done_connecting_pin

;// btr ecx, LOG2(APP_MODE_MOVING_PIN)
;// jc mouse_done_moving_pin

    jmp mouse_find_hover
    ;// DEBUG_IF<eax>   ;// why are we here ??

mouse_wm_lbuttonup_proc ENDP


    ;////////////////////////////////////////////////////////////////////
    ;//
    ;//
    ;//     mouse_done_moving_screen
    ;//
    ASSUME_AND_ALIGN
    mouse_done_moving_screen PROC

        mov app_bFlags, ecx     ;// see wm_lbuttonup_proc
        invoke InvalidateRect, hMainWnd, 0, 1

        btr mouse_state, LOG2(SCR_HAS_MOVED)
        jnc mouse_find_hover

        unredo_EndAction UNREDO_MOVE_SCREEN

        jmp mouse_find_hover

    mouse_done_moving_screen ENDP
    ;//
    ;//
    ;//     mouse_done_moving_screen
    ;//
    ;////////////////////////////////////////////////////////////////////


    ;////////////////////////////////////////////////////////////////////
    ;//
    ;//
    ;//     mouse_done_moving_osc
    ;//
    ASSUME_AND_ALIGN
    mouse_done_moving_osc PROC

        mov app_bFlags, ecx     ;// see wm_lbuttonup_proc
        GET_OSC_FROM esi, osc_down
        OSC_TO_BASE esi, edi        ;// get the base class
    ;// keep adjacent !!!
        invoke [edi].gui.Move       ;// move the osc
    EXTERNDEF mouse_done_move_return_ptr:NEAR
    mouse_done_move_return_ptr::    ;// needed by osc_label.asm
    ;// keep adjacent

        btr mouse_state, LOG2(OSC_HAS_MOVED)
        .IF CARRY?

            unredo_EndAction UNREDO_MOVE_OSC

        .ENDIF

        invoke mouse_reset_osc_down
        jmp mouse_find_hover

    mouse_done_moving_osc ENDP
    ;//
    ;//     mouse_done_moving_osc
    ;//
    ;//
    ;////////////////////////////////////////////////////////////////////



    ;////////////////////////////////////////////////////////////////////
    ;//
    ;//
    ;//     mouse_done_controlling_osc
    ;//
    ASSUME_AND_ALIGN
    mouse_done_controlling_osc PROC

        GET_OSC_FROM esi, osc_down
        mov app_bFlags, ecx     ;// see wm_lbuttonup_proc
        mov eax, MOUSE_WP_MSG       ;// call control one last time
        OSC_TO_BASE esi, edi
        invoke [edi].gui.Control
        DEBUG_IF <eax & NOT CON_HAS_MOVED>  ;// return value is wrong
        or mouse_state, eax

        invoke mouse_reset_osc_down
        invoke mouse_reset_all_hovers

        btr mouse_state, LOG2(CON_HAS_MOVED)
        .IF CARRY?
            unredo_EndAction UNREDO_CONTROL_OBJECT
        .ENDIF

        jmp mouse_find_hover

    mouse_done_controlling_osc ENDP
    ;//
    ;//     mouse_done_controlling_osc
    ;//
    ;//
    ;////////////////////////////////////////////////////////////////////



    ;////////////////////////////////////////////////////////////////////
    ;//
    ;//
    ;//     mouse_done_select_osc
    ;//
    ASSUME_AND_ALIGN
    mouse_done_select_osc PROC

        mov app_bFlags, ecx     ;// see wm_lbuttonup_proc
        jmp mouse_find_hover

    mouse_done_select_osc ENDP
    ;//
    ;//     mouse_done_select_osc
    ;//
    ;//
    ;////////////////////////////////////////////////////////////////////


    ;////////////////////////////////////////////////////////////////////
    ;//
    ;//
    ;//     mouse_done_unselect_osc
    ;//
    ASSUME_AND_ALIGN
    mouse_done_unselect_osc PROC

        mov app_bFlags, ecx     ;// see wm_lbuttonup_proc
        jmp mouse_find_hover

    mouse_done_unselect_osc ENDP
    ;//
    ;//     mouse_done_select_osc
    ;//
    ;//
    ;////////////////////////////////////////////////////////////////////


    ;////////////////////////////////////////////////////////////////////
    ;//
    ;//
    ;//     mouse_done_connecting_pin
    ;//
    ASSUME_AND_ALIGN
    mouse_done_connecting_pin PROC

        ASSUME ebp:PTR LIST_CONTEXT

        GET_PIN pin_hover, ebx      ;// make sure there's a hover
        mov app_bFlags, ecx         ;// see wm_lbuttonup_proc

        or ebx, ebx
        jz cleanup_and_split        ;// make sure there's somthing to connect to

    ;// try to connect the pins

        mov edi, pin_down           ;// from must be edi
        invoke pin_connect_query    ;// query if connection is valid

        jz cleanup_and_split        ;// pin connect returns no in the zero flag

    ;// connect the pins

        mov esi, ecx                ;// ecx is about to be trashed

        unredo_BeginAction UNREDO_CONNECT_PIN

        ENTER_PLAY_SYNC GUI         ;// pause the play thread

        call esi                    ;// do the connect operation
        or [ebp].pFlags, PFLAG_TRACE;// schedule a trace
        invoke context_SetAutoTrace         ;// schedule a unit trace

        LEAVE_PLAY_SYNC GUI         ;// unblock the play thread

        unredo_EndAction UNREDO_CONNECT_PIN

    cleanup_and_split:
    ;// reset pin down and exit to mouse_find_hover

        invoke gdi_EraseMouseConnect
        invoke mouse_reset_pin_down
        jmp mouse_find_hover

    mouse_done_connecting_pin ENDP
    ;//
    ;//     mouse_done_connecting_pin
    ;//
    ;//
    ;////////////////////////////////////////////////////////////////////




;//
;//     WM_LBUTTONUP
;//
;//
;//////////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////////





;//////////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////////
;//
;//
;//     WM_RBUTTONDOWN
;//
;//
;// jumped to by mainWndProc
ASSUME_AND_ALIGN
mouse_wm_rbuttondown_proc PROC PUBLIC   ;// STDCALL uses ebx esi edi hWnd:dword, msg:dword, keys:dword, spoint:dword

    ;// interlock with left button

.IF !(mouse_state & MK_LBUTTON)

    or mouse_state, MK_RBUTTON

    point_Get mouse_now
    point_Set mouse_down

    ;// make sure the label editor gets shut off

    .IF app_DlgFlags & DLG_LABEL
        invoke SetFocus, hMainWnd
    .ENDIF

    ;// if we're in an editable mode
    ;// see if we're wanting to do any of the special move functions

    test app_CircuitSettings, CIRCUIT_NOEDIT
    jnz all_done

        xor eax, eax

        ;// moving a pin ?

        OR_GET_PIN pin_hover, eax
        .IF !ZERO?

            or app_bFlags, APP_MODE_MOVING_PIN  ;// update the app flags
            and mouse_state, NOT PIN_HAS_MOVED  ;// reset the mouse moved state

            mov pin_down, eax                   ;// set pin_down

            unredo_BeginAction UNREDO_MOVE_PIN

            invoke SetCapture, hMainWnd         ;// get the capture

            jmp all_done

        .ENDIF

        ;// moving ONE osc ?

        OR_GET_OSC_FROM eax, osc_hover
        .IF !ZERO?

            .IF !(app_CircuitSettings & CIRCUIT_NOMOVE)

                or app_bFlags, APP_MODE_MOVING_OSC_SINGLE
                and mouse_state, NOT OSC_HAS_MOVED
                mov osc_down, eax
                invoke SetCapture, hMainWnd         ;// get the capture

                unredo_BeginAction UNREDO_MOVE_OSC

            .ENDIF

            jmp all_done

        .ENDIF

        ;// we are not hitting anything, so we set drawing selrect

        ;// then start the sel rect

        point_Get mouse_now
        point_SetTL mouse_selrect
        point_SetBR mouse_selrect

        or app_bFlags, APP_MODE_USING_SELRECT
        and mouse_state, NOT SEL_HAS_MOVED

        invoke SetCapture, hMainWnd         ;// get the capture


.ELSEIF app_bFlags & APP_MODE_CONNECTING_PIN && mouse_pin_connect_is_swappable

    ;// pDown has the where we fell down

    IFDEF DEBUGBUILD
        GET_PIN pin_down, eax       ;// get pin down
        DEBUG_IF <!!eax>            ;// must have pin down
        DEBUG_IF <[eax].dwStatus & PIN_BUS_TEST>
        DEBUG_IF <!![eax].pPin >    ;// must be connected
    ENDIF

        xor ecx, ecx
        xor pin_connect_special_18, 18  ;// toggle the special mode flag
        OR_GET_PIN pin_hover, ecx
        .IF !ZERO?      ;// force the color to reset
            push ebp
            push ebx
            stack_Peek gui_context, ebp
            mov ebx, ecx
            invoke mouse_set_pin_query
            pop ebx
            pop ebp
        .ENDIF
        invoke InvalidateRect, hMainWnd, 0, -1

;//     jmp all_done


.ENDIF  ;// lbutton down

all_done:

    UPDATE_DEBUG

    ;// that's it
    xor eax, eax
    ret 10h

mouse_wm_rbuttondown_proc ENDP
;//
;//     WM_RBUTTONDOWN
;//
;//
;//////////////////////////////////////////////////////////////////////////////////////////////



;//////////////////////////////////////////////////////////////////////////////////////////////
;//
;//
;//     WM_RBUTTONUP
;//
;//
;// jumped to by mainWndProc
ASSUME_AND_ALIGN
mouse_wm_rbuttonup_proc PROC PUBLIC ;// STDCALL hWnd:dword, msg:dword, keys:dword, spoint:dword

    ;// iterlock with left button

        test mouse_state, MK_LBUTTON
        jz ok_to_continue
        xor eax, eax
        ret 10h

    ok_to_continue:

        DEBUG_CLOCKER_BEGIN mouse

        and mouse_state, NOT MK_RBUTTON

    ;// if we are in the menu loop, we have to xlate the points passed to this function
    ;// rather than take apart the enter handler function, we'll rebuild on the stack
    ;// perhaps more cycles ...

        .IF app_DlgFlags & DLG_MENU

            spoint_Get WP_LPARAM
            push edx
            push eax
            invoke ScreenToClient, hMainWnd, esp
            pop eax
            pop edx
            and eax, 0FFFFh
            shl edx, 16
            or eax, edx
            mov WP_LPARAM, eax

        .ENDIF

    ;// now we enter the handler

        ENTER_MOUSE_HANDLER

    ;// stop moving stuff, if we were

        mov eax, app_bFlags

        btr eax, LOG2(APP_MODE_MOVING_PIN)
        jc done_moving_pin

        btr eax, LOG2(APP_MODE_MOVING_OSC_SINGLE)
        jc done_moving_osc

        btr eax, LOG2(APP_MODE_USING_SELRECT)
        jc done_using_selrect

    summon_a_dialog:

        ;// see what we're hitting

        mov mouse_hit_flags, MHT_PINS + MHT_CLOSE
        invoke mouse_hittest_all
        jz mouse_show_desk_popup
        js mouse_show_pins_popup
        jmp mouse_show_osc_popup

    done_moving_pin:    ;// stop moving a pin

        mov pin_down, 0             ;// reset pin down
        mov app_bFlags, eax         ;// reset app flags
        invoke ReleaseCapture       ;// release the capture

        ;// check if the mouse moved

        test mouse_state, PIN_HAS_MOVED
        jz summon_a_dialog

        unredo_EndAction UNREDO_MOVE_PIN

        jmp mouse_find_hover

    done_moving_osc:    ;// stop moving an osc

        mov osc_down, 0             ;// reset pin down
        mov app_bFlags, eax         ;// reset app flags
        invoke ReleaseCapture       ;// release the capture

        ;// check if the mouse moved

        test mouse_state, OSC_HAS_MOVED
        jz summon_a_dialog

        unredo_EndAction UNREDO_MOVE_OBJECT

        jmp mouse_find_hover

    done_using_selrect:

        mov app_bFlags, eax         ;// reset app flags
        invoke ReleaseCapture       ;// release the capture

        test mouse_state, SEL_HAS_MOVED
        jz summon_a_dialog

        invoke gdi_BlitSelRect
        jmp mouse_find_hover



mouse_wm_rbuttonup_proc ENDP


    ;////////////////////////////////////////////////////////////////////
    ;//
    ;//
    ;//     mouse_show_desk_popup
    ;//
    ASSUME_AND_ALIGN
    mouse_show_desk_popup PROC

        test app_CircuitSettings, CIRCUIT_NOEDIT
        jnz mouse_proc_exit

        invoke create_Show
        jmp mouse_proc_exit

    mouse_show_desk_popup ENDP
    ;//
    ;//     mouse_show_desk_popup
    ;//
    ;//
    ;////////////////////////////////////////////////////////////////////

    ;////////////////////////////////////////////////////////////////////
    ;//
    ;//
    ;//     mouse_show_pins_popup
    ;//
    ASSUME_AND_ALIGN
    mouse_show_pins_popup PROC

        invoke mouse_set_pin_hover

        test app_CircuitSettings, CIRCUIT_NOEDIT
        jnz mouse_proc_exit

        invoke bus_Show

        jmp mouse_proc_exit

    mouse_show_pins_popup ENDP
    ;//
    ;//     mouse_show_pins_popup
    ;//
    ;//
    ;////////////////////////////////////////////////////////////////////

    ;////////////////////////////////////////////////////////////////////
    ;//
    ;//
    ;//     mouse_show_osc_popup
    ;//
    ASSUME_AND_ALIGN
    mouse_show_osc_popup PROC

        invoke mouse_set_osc_hover

        test app_CircuitSettings, CIRCUIT_NOEDIT
        jnz mouse_proc_exit

        invoke popup_Show, osc_hover
        jmp mouse_proc_exit

    mouse_show_osc_popup ENDP
    ;//
    ;//     mouse_show_osc_popup
    ;//
    ;//
    ;////////////////////////////////////////////////////////////////////


;//
;//     WM_RBUTTONUP
;//
;//
;//////////////////////////////////////////////////////////////////////////////////////////////































;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
;////
;////                                               set_osc_hover
;////   S T A T E    M A I N T A I N A N C E        set_con_hover
;////                                               set_pin_hover
;////                                               set_osc_down
;////                                               set_con_down
;////                                               set_pin_down
;////                                               set_pin_query
ASSUME_AND_ALIGN
mouse_set_osc_hover     PROC

    ASSUME esi:PTR OSC_OBJECT   ;// must be the hover to set
    ASSUME ebp:PTR LIST_CONTEXT

    invoke mouse_reset_all_hovers

    ;// set the new hover

        mov ecx, HINTI_OSC_GOT_HOVER
        mov osc_hover, esi                  ;// set new hover
        GDI_INVALIDATE_OSC ecx              ;// schedule for redraw
        or app_bFlags, APP_MODE_OSC_HOVER   ;// set the app mode

        ;// if the new hover is also locked, we have to tag the entire chain
        .IF clist_Next(oscL,esi)    ;//[esi].pNextL ;// locked ?

            GET_OSC_FROM ecx, esi

            .REPEAT

                GDI_INVALIDATE_OSC HINTI_OSC_GOT_LOCK_HOVER, ecx
                clist_GetNext oscL, ecx

            .UNTIL ecx == esi

        .ENDIF

    ;// that's it

        ret

mouse_set_osc_hover     ENDP




ASSUME_AND_ALIGN
mouse_set_con_hover     PROC

    ASSUME esi:PTR OSC_OBJECT   ;// must be the hover to set
    ASSUME ebp:PTR LIST_CONTEXT


    invoke mouse_reset_all_hovers

    ;// set the new con hover

        mov ecx, HINTI_OSC_GOT_CON_HOVER        ;// merge on the new invalidate flags
        mov osc_hover, esi                  ;// store the new hover
        GDI_INVALIDATE_OSC ecx              ;// schedule for redraw
        or app_bFlags, APP_MODE_CON_HOVER   ;// set the app mode

    ;// that's it

        ret

mouse_set_con_hover     ENDP




ASSUME_AND_ALIGN
mouse_set_pin_hover     PROC

    ASSUME ebx:PTR APIN         ;// ebx must be the hover to set
    ASSUME ebp:PTR LIST_CONTEXT


    push ebx
    invoke mouse_reset_all_hovers
    pop ebx

    ;// set the new hover

        mov eax, F_COLOR_PIN_HOVER      ;// use the pin hover color
        invoke gdi_pin_set_color, 0     ;// set the color (also invalidates)

        or [ebx].dwHintI, HINTI_PIN_GOT_HOVER ;// merge in the got hover command
        mov pin_hover, ebx              ;// store the new hover

        ;// if this pin was a bus, we have to tag all attached pins to get hover

        .IF [ebx].dwStatus & PIN_BUS_TEST

            test [ebx].dwStatus, PIN_OUTPUT ;// see if we've already done the head
            GET_PIN_FROM ecx, [ebx].pPin    ;// load either the head or the first pin
            jnz P2                          ;// jump if we're loading he first pin

                GDI_INVALIDATE_PIN HINTI_PIN_GOT_BUS_HOVER, ecx;// invalidate the head
                GET_PIN_FROM ecx, [ecx].pPin;// get the first pin
                jmp P2                      ;// jump to loop enter

            P0: cmp ecx, ebx                ;// check for pin we've already done
                je P1                       ;// jump if we've already invalidated this
                GDI_INVALIDATE_PIN HINTI_PIN_GOT_BUS_HOVER, ecx;// loose hover
            P1: GET_PIN_FROM ecx,[ecx].pData;// get the next pin
            P2: or ecx, ecx                 ;// make sure there is one
                jnz P0                      ;// continue on if so

        .ENDIF

    ;// set the status

        mov eax, [ebx].j_index
        mov eax, pin_status_index[eax*4]
        SET_STATUS eax, MANDATORY

    ;// that's it

        ret

mouse_set_pin_hover     ENDP





ASSUME_AND_ALIGN
mouse_reset_all_hovers  PROC

    ;// destroys ebx

        ASSUME ebp:PTR LIST_CONTEXT

        xor ebx, ebx

    ;// turn off previous pin hover

        OR_GET_PIN pin_hover, ebx
        .IF !ZERO?
            xor eax, eax            ;// clear to use default color
            mov pin_hover, eax      ;// reset the hover
            invoke gdi_pin_reset_color, HINTI_PIN_LOST_HOVER OR HINTI_PIN_LOST_BUS_HOVER    ;// call set color (also invalidates)
            xor ebx, ebx
        .ENDIF

    ;// turn off previous osc and con hover

        OR_GET_OSC_FROM ebx, osc_hover
        .IF !ZERO?

            ;// if the old hover was also locked, we have to tag the entire chain
            .IF [ebx].dwHintOsc & HINTOSC_STATE_HAS_HOVER   &&  \
                clist_Next(oscL,ebx);//[ebx].pNextL

                mov ecx, ebx

                .REPEAT

                    GDI_INVALIDATE_OSC HINTI_OSC_LOST_LOCK_HOVER, ebx
                    clist_GetNext oscL, ebx

                .UNTIL ecx == ebx

            .ENDIF

            ;// then invalidate the origonal hover

            GDI_INVALIDATE_OSC HINTI_OSC_LOST_HOVER OR HINTI_OSC_LOST_CON_HOVER, ebx
            mov osc_hover, 0
            and app_bFlags, NOT ( APP_MODE_OSC_HOVER OR APP_MODE_CON_HOVER )

        .ENDIF

    ;// that's it

        ret

mouse_reset_all_hovers  ENDP




ASSUME_AND_ALIGN
mouse_set_osc_down      PROC

    ASSUME esi:PTR OSC_OBJECT
    ASSUME ebp:PTR LIST_CONTEXT

    invoke mouse_reset_osc_down

    or app_bFlags, APP_MODE_MOVING_OSC
    mov osc_down, esi

    ret

mouse_set_osc_down      ENDP


ASSUME_AND_ALIGN
mouse_set_con_down      PROC

    ASSUME esi:PTR OSC_OBJECT
    ASSUME ebp:PTR LIST_CONTEXT

    invoke mouse_reset_osc_down

    or app_bFlags, APP_MODE_CONTROLLING_OSC
    mov osc_down, esi

    GDI_INVALIDATE_OSC HINTI_OSC_GOT_CON_DOWN

    ret

mouse_set_con_down      ENDP


ASSUME_AND_ALIGN
mouse_set_pin_down      PROC

    ;// if pin is connected, then set moving pin
    ;// if pin is not connected, then set connecting pin

    ASSUME ebx:PTR APIN
    ASSUME ebp:PTR LIST_CONTEXT

    invoke mouse_reset_pin_down
    mov pin_down, ebx
    or app_bFlags, APP_MODE_CONNECTING_PIN

    GDI_INVALIDATE_PIN HINTI_PIN_GOT_DOWN

    ret

mouse_set_pin_down      ENDP






ASSUME_AND_ALIGN
mouse_reset_osc_down    PROC

    ASSUME ebp:PTR LIST_CONTEXT

    .IF osc_down

    push esi

        GET_OSC_FROM esi, osc_down

        and app_bFlags, NOT ( APP_MODE_MOVING_OSC + APP_MODE_CONTROLLING_OSC )

    pop esi

        mov osc_down, 0

    .ENDIF

    ret

mouse_reset_osc_down    ENDP






ASSUME_AND_ALIGN
mouse_reset_pin_down    PROC

    ASSUME ebp:PTR LIST_CONTEXT
    ASSUME ebx:PTR APIN

    .IF pin_down

    push ebx

        and app_bFlags, NOT(APP_MODE_CONNECTING_PIN)

        mov ebx, pin_down

        ;// xor eax, eax
        invoke gdi_pin_reset_color, 0

        or [ebx].dwHintI, HINTI_PIN_LOST_DOWN

        mov pin_down, 0

    pop ebx

    .ENDIF

    ret

mouse_reset_pin_down    ENDP





;////////////////////////////////////////////////////////////////////
;//
;//                             determines if pins can be connected
;//     mouse_set_pin_query     uses pin_Hover and pin_Down
;//                             sets a new pin hover in the process
ASSUME_AND_ALIGN
mouse_set_pin_query     PROC

    ASSUME ebx:PTR APIN
    ASSUME ebp:PTR LIST_CONTEXT

    ;// turn off previous pin hover

        xor ecx, ecx
        OR_GET_PIN pin_hover, ecx
        .IF !ZERO?
            .IF ecx != ebx
            push ebx                ;// store ebx
                ;// xor eax, eax            ;// clear to use default color
                GET_PIN ecx, ebx        ;// xfer old hover to ebx
                invoke gdi_pin_reset_color, 0   ;// call set color (also invalidates)
                or [ebx].dwHintI, HINTI_PIN_LOST_HOVER  ;// merge on the lost hover flag
            pop ebx                 ;// retrieve ebx
            .ENDIF
            xor ecx, ecx
        .ENDIF

    ;// turn off previous osc and con hover

        OR_GET_OSC_FROM ecx, osc_hover
        .IF !ZERO?
            GDI_INVALIDATE_OSC HINTI_OSC_LOST_HOVER OR HINTI_OSC_LOST_CON_HOVER, ecx
            and app_bFlags, NOT ( APP_MODE_OSC_HOVER OR APP_MODE_CON_HOVER )
            mov osc_hover, 0
        .ENDIF

    ;// set the new pin hover and query what color to set it at

        mov pin_hover, ebx          ;// set the new pin hover first
        mov edi, pin_down           ;// edi must be the arg
        invoke pin_connect_query    ;// then call query connection

        ;// ... be careful to preserve the zero flag ...

        mov ecx, eax                ;// store the status return value

        mov eax, F_COLOR_PIN_BAD        ;// determine what color to piant the pin
        jz G1                       ;// valid ? (done with zero flag)
        mov eax, F_COLOR_PIN_GOOD
    G1: SET_STATUS  ecx             ;// set the status

        invoke gdi_pin_set_color, 0 ;// invalidate the pin color

        or [ebx].dwHintI, HINTI_PIN_GOT_HOVER   ;// merge in the got hover command

    ;// that's it

        ret

mouse_set_pin_query     ENDP





















;////
;////
;////   S T A T E    M A I N T A I N A C N E
;////
;////
;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////



















;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;////
;////
;////       H I T   T E S T I N G
;////
ASSUME_AND_ALIGN
mouse_hittest_all_exit: ;// we put this here to help out the BTB
                        ;// assume mouse usually hits nothing
                        ;// all backward BTBs are predicted taken
                        ;// so all failed tests are predicted taken
    ret                 ;// correct flags had better well be set at this point




ASSUME_AND_ALIGN
mouse_hittest_all PROC PRIVATE

        ASSUME ebp:PTR LIST_CONTEXT

        cmp dlist_Head(oscZ,[ebp]), 0   ;// sometimes we get here before the screen erases itself
        je mouse_hittest_all_exit       ;// so we abort now if oscZ is empty


    ;// uses all registers

    ;// be sure to set MFT flags for desired operation

    ;// returns a flag and a register
    ;//
    ;//     zero    if desk hit
    ;//     carry   if osc control hit  esi=osc that is hit
    ;//     sign    if pin hit          ebx=pin that is hit
    ;//     none    if osc is hit       esi=osc that is hit


    ;// set mouse_pDest

        GDI_POINT_TO_GDI_ADDRESS mouse_now, edx ;// build mouse pDest
        mov mouse_pDest, edx

    ;// test by color under pdest

        cmp BYTE PTR [edx], COLOR_LOWEST_PIN    ;// do the color test
        jae check_oscs                          ;// if greater, then we're hitting something

    ;// hitting the desk, see if we're s'posed to do close

        test mouse_hit_flags, MHT_CLOSE
        jz mouse_hittest_all_exit   ;// zero is already set, exit

    check_for_close:

    ;// the color under the mouse registered as the desk color
    ;// close test was on, so we do several checks
    ;//
    ;// if pin hover is set, we check it's rect first
    ;//     if inside, we return pin hit
    ;//
    ;// scan the Zlist and check if we are close to any osc's
    ;// if we are close, we want to tell it to show it's pins
    ;// if we are not close, and show pins is on, we want to tell it to hide pins

        xor ebx, ebx
        xor ecx, ecx                ;// clear for next tests
        OR_GET_PIN pin_hover, ebx   ;// check if there's a pin_hover
        jz pin_close_test_hide      ;// skip for no hover

        ;// there is a pin hover

            or ecx,  [ebx].j_index  ;// load and test the jump index
            jz pin_close_test_hide  ;// exit not if zero

            point_Get mouse_now     ;// get mouse now to test with
            PIN_TO_TSHAPE ebx, edi  ;// edi will point to the shape for a while
            point_Sub [ebx].t0      ;// subtract our position
            jmp pin_close_test_jump[ecx*4]  ;// jump to appropriate tester

        pin_close_test_TFB::    ;// bussed analog input
        pin_close_test_LFB::    ;// bussed logic input
        pin_close_test_FB::     ;// bussed output

            ;// test against r2
            add edi, SIZEOF RECT    ;// scoot to r2
            rect_IfXYNotInside [edi].r2,,,pin_close_test_hide
            jmp pin_close_test_FS   ;// jump to tester

        pin_close_test_FT::     ;// unconnected output
                                ;// test against r1
        ;// we're drawing the assembly backwards
        ;// so we move the point to account for this

            point_Add [edi].t3

        pin_close_test_TF::     ;// unconnected analog input
        pin_close_test_TFS::    ;// connected analog input
        pin_close_test_LFS::    ;// connected logic input
        pin_close_test_LF::     ;// unconnected logic input
        pin_close_test_FS::     ;// connected output

            rect_IfXYNotInside [edi].r1,,,pin_close_test_hide

        ;// rect is hit

            xor ecx, ecx                ;// set zero, clear carry
            dec ecx                     ;// set the sign flag
            jmp mouse_hittest_all_exit  ;// exit the routine

        ALIGN 16
        pin_close_test_hide::   ;// hidden pin (ignore)

    ;// osc_close_test rips through and turns on or off the show pins bit
    ;// we always return zero

    ;// to do this, we need to build a mouse rect to close test with

        comment ~ /*

            registers for the next block

            eax L   edi T
            ebx R   ecx B

            esi osc
            edx flag testing and invalidate temp variable

        */ comment ~

        ;// get top of Zlist and check for empty

            dlist_GetHead oscZ, esi, [ebp]  ;// get top of Z list
            or esi, esi                     ;// anything to do ?
            jz mouse_hittest_all_exit       ;// zero is set, exit now

        ;// build the rect points

            point_Get mouse_now, eax, edi

            MOUSE_CLOSE_RECT = 32

            sub eax, MOUSE_CLOSE_RECT   ;// subtract the rect offset
            sub edi, MOUSE_CLOSE_RECT   ;// subtract the rect offset

            lea ebx, [eax+MOUSE_CLOSE_RECT*2]   ;// load and add twice the rect offset
            xor edx, edx            ;// clear for testing
            lea ecx, [edi+MOUSE_CLOSE_RECT*2]   ;// load and add twice the rect offset

        ;// scan the Z list

        top_of_close_loop:

            or edx, [esi].dwHintOsc     ;// ONSCREEN is the sign bit
            jns close_loop_iterate      ;// skip if offscreen

            mov edx, [esi].dwHintOsc    ;// load the osc state

            ;// are we close to the osc ?
                                        ;// exit if:
            cmp ebx, [esi].rect.left    ;// mouse.right < rect.left
            jl nope_not_close
            cmp ecx, [esi].rect.top     ;// mouse.bottom < rect.top
            jl nope_not_close
            cmp eax, [esi].rect.right   ;// mouse.left > rect.right
            jg nope_not_close
            cmp edi, [esi].rect.bottom  ;// mouse.top > rect.bottom ?
            jg nope_not_close

        yep_are_close:

            bt edx, LOG2(HINTOSC_STATE_SHOW_PINS)   ;// check if we're already showing our pins
            jc close_loop_iterate                   ;// no need to be redundant
            GDI_INVALIDATE_OSC HINTI_OSC_SHOW_PINS

        close_loop_iterate:     ;// iterate here and now

            dlist_GetNext oscZ, esi     ;// get the next osc
            xor edx, edx                ;// clear for testing
            or esi, esi                 ;// end of list ?
            jnz top_of_close_loop       ;// keep going if not
            jmp mouse_hittest_all_exit  ;// zero flag is set, exit now

        nope_not_close:

            bt edx, LOG2(HINTOSC_STATE_SHOW_PINS)   ;// check if we are already showing our pins
            jnc close_loop_iterate                  ;// nope, so we don't have to hide them

            GDI_INVALIDATE_OSC HINTI_OSC_HIDE_PINS  ;// hide these pins

            jmp close_loop_iterate




    ALIGN 16
    check_oscs:     ;// we know we are hitting an osc or pin,
                    ;// so we scan until we find it

        dlist_GetHead oscZ, esi, [ebp]  ;// first osc is always the hover

        DEBUG_IF <!!esi>    ;// this should not be called unless we're hitting something

        xor edi, edi                ;// clear for testing
        point_Get mouse_now

    ;// scan through the zlist

        G0: or esi, esi                 ;// check for done
            jz mouse_hittest_all_exit   ;// exit if done with zero set

            or edi, [esi].dwHintOsc     ;// test the hintosc to check on screen
            jns G2                      ;// skip call if not on screen

            invoke mouse_hittest_osc    ;// do the hit test
            jnz mouse_hittest_all_exit  ;// flags are set, exit

        G2: dlist_GetNext oscZ, esi     ;// iterate
            xor edi, edi                ;// clear for testing the sign
            jmp G0                      ;// jmp to top

mouse_hittest_all ENDP







ASSUME_AND_ALIGN
mouse_hittest_osc PROC PRIVATE

    ASSUME esi:PTR OSC_OBJECT   ;// points at osc to test, preserved
    ;// edi may be destroyed
    ;// ebx may be cleared as required
    ;//
    ;// on entrance
    ;// mouse_hit_flags tells us what to test
    ;// MHT_PINS     is "test pins too"
    ;// MHT_CONTROLS is test osc's control
    ;//
    ;// eax is mouse.X  ;// PRESERVE unless hit
    ;// edx is mouse.Y  ;// PRESERVE unless hit
    ;//
    ;//     returns: three flags
    ;//     zero    if nothing owned by the osc is hit
    ;//     sign    if a pin owned by the osc is hit, ebx returns with the pin address
    ;//     carry   if the osc has a control, and it is hit
    ;//     no flags, the osc is hit
    ;//
    ;// we can skip all tests if we are simply not close to the osc

    ;// check if mouse is inside the osc's boundry

        rect_IfXYNotInside [esi].boundry,,,exit_zero

    ;// we are inside the osc.boundry
    ;// we can save some work if we determine wheather an osc or a pin is hit

        mov ecx, mouse_pDest

        cmp BYTE PTR [ecx], COLOR_LOWEST_OSC
        jb hitting_pin_color

    hitting_osc_color:

    ;// we are hitting an osc color
    ;// are we inside the osc rect ?

        rect_IfXYNotInside [esi].rect,,,exit_zero

    ;//
    ;// we are hitting inside the osc_rect
    ;//

    ;// test the osc shape

        push esi
        OSC_TO_CONTAINER esi, ebx   ;// get the container
        mov edi, mouse_pDest        ;// get the target
        OSC_TO_DEST esi, esi        ;// get our dest
        CONTAINER_TO_MASK ebx, ebx  ;// get the mask
        invoke shape_Test           ;// do the test
        pop esi
        jnc exit_zero_get_point     ;// jump if not hitting the shape

    ;// we are hitting inside the osc shape

        xor ecx, ecx                ;// clear for subsequent flag settings

        test mouse_hit_flags, MHT_CONTROLS  ;// do we need to check the osc's control ?
        jnz test_osc_control        ;// skip if not
    @7: inc ecx                     ;// clear the zero flag, we're hitting the osc
        jmp exit_now                ;// return with osc_hit (no flags are set)


    ALIGN 16
    test_osc_control:

        OSC_TO_BASE esi, edi        ;// get the base class
        or ecx, [edi].gui.HitTest   ;// ecx had better be zero
        jz  @7                      ;// exit if no test
        jmp ecx                     ;// gui hit test will exit for us



    ALIGN 16
    hitting_pin_color:  ;// color test thinks we are hitting a pin

        test mouse_hit_flags, MHT_PINS  ;// are we supposed to ?
        jz exit_now                     ;// skip pins test

        cmp BYTE PTR [ecx], COLOR_HIGHEST_PIN
        ja exit_zero

        test [esi].dwHintOsc, HINTOSC_STATE_SHOW_PINS
        jz not_showing_pins

    yes_showing_pins:

        ITERATE_PINS

            call mouse_hittest_pin  ;// hit test the pin
            js exit_now

        PINS_ITERATE

        jmp exit_zero

    ALIGN 16
    not_showing_pins:

        ITERATE_PINS

            mov ecx, [ebx].j_index
            .IF pin_j_index_connected[ecx]
                call mouse_hittest_pin  ;// hit test the pin
                js exit_now
            .ENDIF

        PINS_ITERATE

        jmp exit_zero

    exit_zero_get_point:    point_Get mouse_now
    exit_zero:              cmp eax, eax    ;// set the zero flag, we're hitting nothing
    exit_now:               ret             ;// done with loop

mouse_hittest_osc ENDP


;////////////////////////////////////////////////////////////////////
;//
;//                     1) hit test by rect
;//     hit test pin    2) hit test by shape
;//                     3) hit test by outline
ASSUME_AND_ALIGN
mouse_hittest_pin PROC PRIVATE

        ASSUME ebx:PTR APIN     ;// ebx has the pin pointer, preserved
                                ;// esi preserved
                                ;// edi DESTROYED

        ;// eax,edx have mouse now, and must be preserved

        ;// DEBUG_IF <esi!!=[ebx].pObject>          ;// must be so

    ;// hit test by rect

        xor ecx, ecx
        or ecx,  [ebx].j_index      ;// get the jump index
        jz hittest_pin_rect_hide    ;// exit not if zero

        PIN_TO_TSHAPE ebx, edi  ;// edi will point to the shape for a while
        point_Sub [ebx].t0      ;// subtract our position

        jmp hittest_pin_rect_jump[ecx*4]


    ALIGN 16
    hittest_pin_rect_TFB::  ;//     bussed analog input
    hittest_pin_rect_LFB::  ;//     bussed logic input
    hittest_pin_rect_FB::   ;//     bussed output

    ;// test against r2

        rect_IfXYNotInside [edi].r2,,,pin_not_hit   ;// eax,edx have not changed

    ;// jump to next section

        jmp hittest_pin_shape_jump[ecx*4]

    ALIGN 16
    hittest_pin_rect_FT::   ;//     unconnected output

    ;// we're drawing the assembly backwards
    ;// so we move the point to account for this

        ;// test against r1
        point_Add [edi].t3
        jmp hittest_pin_rect_FS

    ALIGN 16
    hittest_pin_rect_TFS::  ;//     connected analog input
    hittest_pin_rect_TF::   ;//     unconnected analog input
    hittest_pin_rect_LFS::  ;//     connected logic input
    hittest_pin_rect_LF::   ;//     unconnected logic input
    hittest_pin_rect_FS::   ;//     connected output

    ;// test against r1

        rect_IfXYNotInside [edi].r1,,,pin_not_hit

    ;// continue to next section

        jmp hittest_pin_shape_jump[ecx*4]




    ;// hittest by mask shape

    ALIGN 16
    hittest_pin_shape_TFB:: ;// bussed analog input

        ;// test the bus shape at p7

        push ebx            ;// always save

        mov esi, [ebx].pDest    ;// load our pDest
        add esi, [edi].p7       ;// add appropriate offset
        mov edi, mouse_pDest    ;// load mouse_pDest
        mov ebx, shape_bus.pMask;// get the bus mask
        invoke shape_Test

        pop ebx             ;// retrieve

        jc pin_is_hit           ;// carry is set if we are hit
        mov edi, [ebx].pTShape  ;// retrieve our shape
        jmp hittest_pin_shape_TF    ;// jump to next section

    ALIGN 16
    hittest_pin_shape_TFS:: ;// connected analog input
    hittest_pin_shape_TF::  ;// unconnected analog input

    ;// test the triangle at pDest

        push ebx

        mov esi, [ebx].pDest    ;// load our pDest(no adjustment)
        mov ebx, [edi].pMask    ;// load the masker from the triangle
        mov edi, mouse_pDest    ;// load the correct destination
        invoke shape_Test

        pop ebx

        jc pin_is_hit   ;// carry flag set if hit

        mov edi, [ebx].pTShape  ;// retrieve our shape

    ;// test the font shape at p4

        mov edx, [edi].p4       ;// load appropriate offset for font
        jmp pin_test_font       ;// jump to font test


    ALIGN 16
    hittest_pin_shape_FT::  ;// unconnected output

    ;// test the triangle at p8

        push ebx

        mov esi, [ebx].pDest    ;// load our pDest
        mov ebx, [edi].pMask    ;// load the masker from the triangle
        mov edx, [edi].p9       ;// load the offset
        mov edi, mouse_pDest    ;// load the correct destination
        add esi, edx            ;// add the offset to triangle
        invoke shape_Test

        pop ebx

        jc pin_is_hit   ;// carry flag set if hit

        mov edi, [ebx].pTShape  ;// retrieve our shape

    ;// test the font shape at p8

        mov edx, [edi].p8       ;// load appropriate offset for font
        jmp pin_test_font       ;// jump to font test



    ALIGN 16
    hittest_pin_shape_LFB:: ;// bussed logic input

    ;// test the bus shape at p6

        push ebx        ;// always save

        mov esi, [ebx].pDest    ;// load our pDest
        add esi, [edi].p6       ;// add appropriate offset
        mov edi, mouse_pDest    ;// load mouse_pDest
        mov ebx, shape_bus.pMask;// get the bus mask
        invoke shape_Test

        pop ebx         ;// retrieve

        jc pin_is_hit   ;// carry is set if we are hit

        mov edi, [ebx].pTShape      ;// retrieve our shape
        jmp hittest_pin_shape_LF    ;// fall into next section


    ALIGN 16
    hittest_pin_shape_LFS:: ;// connected logic input
    hittest_pin_shape_LF::  ;// unconnected logic input

    ;// test the logic shape at p1

        push ebx

        mov edx, [edi].p1       ;// load correct offset
        mov ecx, [ebx].pLShape  ;// get the desired logic shape
        mov edi, mouse_pDest    ;// load the target
        mov esi, [ebx].pDest    ;// load our pDest
        mov ebx, (GDI_SHAPE PTR [ecx]).pMask    ;// load masker from logic shape
        add esi, edx            ;// adjust dest appropriately
        invoke shape_Test

        pop ebx

        jc pin_is_hit

        mov edi, [ebx].pTShape  ;// retrieve the shape

    ;// test the font shape at p3

        mov edx, [edi].p3       ;// load the correct font offset
        jmp pin_test_font


    ALIGN 16
    hittest_pin_shape_FB::  ;// bussed output

    ;// test the bus shape at p5

        push ebx        ;// always save

        mov esi, [ebx].pDest    ;// load our pDest
        add esi, [edi].p5       ;// add appropriate offset
        mov edi, mouse_pDest    ;// load mouse_pDest
        mov ebx, shape_bus.pMask;// get the bus mask
        invoke shape_Test

        pop ebx         ;// retrieve

        jc pin_is_hit   ;// carry is set if we are hit
        mov edi, [ebx].pTShape  ;// retrieve our shape

        jmp hittest_pin_shape_FS    ;// fall into next section

    ALIGN 16
    hittest_pin_shape_FS::  ;// connected output

    ;// test the font shape at p2

        mov edx, [edi].p2
        jmp pin_test_font

    ALIGN 16
    pin_test_font:

        ;// edx had better have the offset we need

            push ebx

            mov esi, [ebx].pDest    ;// load our pDest
            mov edi, mouse_pDest    ;// load the target pDest
            mov ebx, shape_bus.pMask;// load the raster
            add esi, edx            ;// add appropriate offset
            invoke shape_Test

            pop ebx

            jc pin_is_hit       ;// carry is set if hit
            jmp pin_check_hover


    ;// since we fell through all the obvious ones
    ;// we check if we have hover
    ;// if so, we check that shape
    ALIGN 16
    pin_check_hover:

        test [ebx].dwHintPin, HINTPIN_STATE_HAS_HOVER
        jz pin_not_hit

    ;// hittest by out1 shape

    ALIGN 16
    hittest_pin_out1_TFB::  ;// bussed analog input

        ;// test the bus shape at p7

        push ebx            ;// always save

        mov esi, [ebx].pDest    ;// load our pDest
        add esi, [edi].p7       ;// add appropriate offset
        mov edi, mouse_pDest    ;// load mouse_pDest
        mov ebx, shape_bus.pOut1;// get the bus out1
        invoke shape_Test

        pop ebx             ;// retrieve

        jc pin_is_hit           ;// carry is set if we are hit
        mov edi, [ebx].pTShape  ;// retrieve our shape
        jmp hittest_pin_out1_TF ;// jump to next section

    ALIGN 16
    hittest_pin_out1_TFS::  ;// connected analog input
    hittest_pin_out1_TF::   ;// unconnected analog input

    ;// test the triangle at pDest

        push ebx

        mov esi, [ebx].pDest    ;// load our pDest(no adjustment)
        mov ebx, [edi].pOut1    ;// load the out1er from the triangle
        mov edi, mouse_pDest    ;// load the correct destination
        invoke shape_Test

        pop ebx

        jc pin_is_hit   ;// carry flag set if hit

        mov edi, [ebx].pTShape  ;// retrieve our shape

    ;// test the font shape at p4

        mov edx, [edi].p4       ;// load appropriate offset for font
        jmp pin_test_font_out1  ;// jump to font test

    ALIGN 16
    hittest_pin_out1_FT::   ;// unconnected output

    ;// test the triangle at p8

        push ebx

        mov esi, [ebx].pDest    ;// load our pDest
        mov ebx, [edi].pOut1    ;// load the out1er from the triangle
        mov edx, [edi].p9       ;// load the offset
        mov edi, mouse_pDest    ;// load the correct destination
        add esi, edx            ;// add the offset to triangle
        invoke shape_Test

        pop ebx

        jc pin_is_hit   ;// carry flag set if hit

        mov edi, [ebx].pTShape  ;// retrieve our shape

    ;// test the font shape at p8

        mov edx, [edi].p8       ;// load appropriate offset for font
        jmp pin_test_font_out1      ;// jump to font test

    ALIGN 16
    hittest_pin_out1_LFB::  ;// bussed logic input

    ;// test the bus shape at p6

        push ebx        ;// always save

        mov esi, [ebx].pDest    ;// load our pDest
        add esi, [edi].p6       ;// add appropriate offset
        mov edi, mouse_pDest    ;// load mouse_pDest
        mov ebx, shape_bus.pOut1;// get the bus out1
        invoke shape_Test

        pop ebx         ;// retrieve

        jc pin_is_hit   ;// carry is set if we are hit

        mov edi, [ebx].pTShape      ;// retrieve our shape
        jmp hittest_pin_out1_LF ;// fall into next section

    ALIGN 16
    hittest_pin_out1_LFS::  ;// connected logic input
    hittest_pin_out1_LF::   ;// unconnected logic input

    ;// test the logic shape at p1

        push ebx

        mov edx, [edi].p1       ;// load correct offset
        mov ecx, [ebx].pLShape  ;// get the desired logic shape
        mov edi, mouse_pDest    ;// load the target
        mov esi, [ebx].pDest    ;// load our pDest
        mov ebx, (GDI_SHAPE PTR [ecx]).pOut1    ;// load out1er from logic shape
        add esi, edx            ;// adjust dest appropriately
        invoke shape_Test

        pop ebx

        jc pin_is_hit

        mov edi, [ebx].pTShape  ;// retrieve the shape

    ;// test the font shape at p3

        mov edx, [edi].p3       ;// load the correct font offset
        jmp pin_test_font_out1


    ALIGN 16
    hittest_pin_out1_FB::   ;// bussed output

    ;// test the bus shape at p5

        push ebx        ;// always save

        mov esi, [ebx].pDest    ;// load our pDest
        add esi, [edi].p5       ;// add appropriate offset
        mov edi, mouse_pDest    ;// load mouse_pDest
        mov ebx, shape_bus.pOut1;// get the bus out1
        invoke shape_Test

        pop ebx         ;// retrieve

        jc pin_is_hit   ;// carry is set if we are hit
        mov edi, [ebx].pTShape  ;// retrieve our shape

        jmp hittest_pin_out1_FS ;// fall into next section

    ALIGN 16
    hittest_pin_out1_FS::   ;// connected output

    ;// test the font shape at p2

        mov edx, [edi].p2
        jmp pin_test_font_out1

    ALIGN 16
    pin_test_font_out1:

        ;// edx had better have the offset we need

            push ebx

            mov esi, [ebx].pDest    ;// load our pDest
            mov edi, mouse_pDest    ;// load the target pDest
            mov ebx, shape_bus.pOut1;// load the raster
            add esi, edx            ;// add appropriate offset
            invoke shape_Test

            pop ebx

            jc pin_is_hit       ;// carry is set if hit
            jmp pin_not_hit


    ALIGN 16
    hittest_pin_out1_hide::
    hittest_pin_shape_hide::
    hittest_pin_rect_hide::
    pin_not_hit:

        xor ecx, ecx            ;// sets the zero flag
        point_Get mouse_now     ;// retrieve the XY points
        mov esi, [ebx].pObject  ;// jic
        inc ecx                 ;// clear the zero flag
        ret         ;// no flags

    ALIGN 16
    pin_is_hit:

        xor eax, eax            ;// zero it
        mov esi, [ebx].pObject  ;// jic
        dec eax                 ;// set the sign flag
        ret         ;// sign flag

mouse_hittest_pin ENDP


.DATA

pin_close_test_jump LABEL DWORD

    dd  OFFSET  pin_close_test_hide ;// hidden (ignore)
    dd  OFFSET  pin_close_test_TFB  ;// bussed analog input
    dd  OFFSET  pin_close_test_TFS  ;// connected analog input
    dd  OFFSET  pin_close_test_TF   ;// unconnected analog input
    dd  OFFSET  pin_close_test_LFB  ;// bussed logic input
    dd  OFFSET  pin_close_test_LFS  ;// connected logic input
    dd  OFFSET  pin_close_test_LF   ;// unconnected logic input
    dd  OFFSET  pin_close_test_FB   ;// bussed output
    dd  OFFSET  pin_close_test_FS   ;// connected output
    dd  OFFSET  pin_close_test_FT   ;// unconnected output

hittest_pin_rect_jump   LABEL DWORD

    dd  OFFSET  hittest_pin_rect_hide   ;// hidden
    dd  OFFSET  hittest_pin_rect_TFB    ;// bussed analog input
    dd  OFFSET  hittest_pin_rect_TFS    ;// connected analog input
    dd  OFFSET  hittest_pin_rect_TF     ;// unconnected analog input
    dd  OFFSET  hittest_pin_rect_LFB    ;// bussed logic input
    dd  OFFSET  hittest_pin_rect_LFS    ;// connected logic input
    dd  OFFSET  hittest_pin_rect_LF     ;// unconnected logic input
    dd  OFFSET  hittest_pin_rect_FB     ;// bussed output
    dd  OFFSET  hittest_pin_rect_FS     ;// connected output
    dd  OFFSET  hittest_pin_rect_FT     ;// unconnected output

hittest_pin_shape_jump  LABEL DWORD

    dd  OFFSET  hittest_pin_shape_hide  ;// hidden
    dd  OFFSET  hittest_pin_shape_TFB   ;// bussed analog input
    dd  OFFSET  hittest_pin_shape_TFS   ;// connected analog input
    dd  OFFSET  hittest_pin_shape_TF    ;// unconnected analog input
    dd  OFFSET  hittest_pin_shape_LFB   ;// bussed logic input
    dd  OFFSET  hittest_pin_shape_LFS   ;// connected logic input
    dd  OFFSET  hittest_pin_shape_LF    ;// unconnected logic input
    dd  OFFSET  hittest_pin_shape_FB    ;// bussed output
    dd  OFFSET  hittest_pin_shape_FS    ;// connected output
    dd  OFFSET  hittest_pin_shape_FT    ;// unconnected output

hittest_pin_out1_jump   LABEL DWORD

    dd  OFFSET  hittest_pin_out1_hide   ;// hidden
    dd  OFFSET  hittest_pin_out1_TFB    ;// bussed analog input
    dd  OFFSET  hittest_pin_out1_TFS    ;// connected analog input
    dd  OFFSET  hittest_pin_out1_TF ;// unconnected analog input
    dd  OFFSET  hittest_pin_out1_LFB    ;// bussed logic input
    dd  OFFSET  hittest_pin_out1_LFS    ;// connected logic input
    dd  OFFSET  hittest_pin_out1_LF ;// unconnected logic input
    dd  OFFSET  hittest_pin_out1_FB ;// bussed output
    dd  OFFSET  hittest_pin_out1_FS ;// connected output
    dd  OFFSET  hittest_pin_out1_FT ;// unconnected output

ASSUME_AND_ALIGN

END