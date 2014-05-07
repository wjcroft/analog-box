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
;// abox_align.asm      routines to align selected objects
;//                     upgraded abox225, more align options, locked group as single unit
;//
;// TOC
;//
;// align_enable_keyboard_swap PROC
;// align_draw_group_rects PROC STDCALL hDC:DWORD
;// align_build_list PROC USES ebp esi edi ebx
;// align_sort_list PROC STDCALL key_off:DWORD, order:DWORD
;// align_move_item_no_pin PROC
;//
;// align_5A PROC
;// align_5B PROC
;// align_4A PROC
;// align_8A PROC
;// align_6A PROC
;// align_2A PROC
;// align_1A PROC
;// align_7A PROC
;// align_4B PROC
;// align_8B PROC
;// align_6B PROC
;// align_2B PROC
;// align_1B PROC
;// align_7B PROC
;// align_9B PROC
;// align_3B PROC
;// align_3A PROC
;// align_9A PROC
;//
;// align_Show  PROC    USES ebx esi
;//
;// align_Proc PROC                 ;// STDCALL hWnd,msg,wParam,lParam
;// align_handle_command    PROC
;// align_wm_command_proc   PROC    ;// STDCALL hWnd,msg,wParam,lParam
;// align_wm_keydown_proc   PROC    ;// STDCALL hWnd,msg,wParam,lParam
;// align_wm_setcursor_proc PROC    ;// STDCALL hWnd,msg,wParam,lParam
;// align_wm_activate_proc  PROC    ;// STDCALL hWnd,msg,wParam,lParam
;// align_wm_close_proc     PROC    ;// STDCALL hWnd,msg,wParam,lParam
;// align_wm_create_proc    PROC    ;// STDCALL hWnd,msg,wParam,lParam



OPTION CASEMAP:NONE
.586
.MODEL FLAT


    .NOLIST
    INCLUDE <abox.inc>
    INCLUDE <gdi_pin.inc>
    INCLUDE <misc.inc>
    .LIST


.DATA

    align_hWnd  dd  0           ;// hwnd of align panel
    align_atom  dd  'a_l'       ;// atom to build the panel

    align_size  POINT   {}      ;// desired size of the panel

    align_status    dd  0       ;// hwnd of status
    align_last_status   dd  0   ;// text pointer to last status

    align_jump_table LABEL DWORD

        dd  align_1A, align_2A, align_3A, align_4A, align_5A, align_6A, align_7A, align_8A, align_9A
        dd  align_1B, align_2B, align_3B, align_4B, align_5B, align_6B, align_7B, align_8B, align_9B


    ALIGN_SPACING       EQU 6   ;// default spacing is this far apart
    ALIGN_GROUP_RADIUS  EQU 6   ;// we show pleasently rounded corners for mixed select mode

    sz_align_help   db  'Use these commands to align selected objects',0
    ALIGN 4

    ;// abox225
    ;// this struct is used to implement aligning groups as a whole unit
    ;// the list is allocated at align_Show
    ;// and deallocated at align_wm_activate_proc

    ALIGN_LIST  STRUCT

        rect    RECT    {}
        pointer dd      ?

    ALIGN_LIST  ENDS

    EXTERNDEF align_list:DWORD      ;// needed by gdi_wm_paint_proc
    EXTERNDEF align_lock_mode:DWORD ;// needed by gdi_wm_paint_proc
    align_draw_group_rects PROTO STDCALL hDC:DWORD ;// needed by gdi_wm_paint_proc

    align_list      dd  0   ;// ptr to allocated array of ALIGN_LIST
    align_lock_mode dd  0   ;// non zero for treat locked groups as units

    align_num_items dd  0   ;// number of elements in the array
                            ;// not really needed ...

    align_extent_ptr RECT {}    ;// these are POINTERS into the align list
                                ;// each side is actually a poiter to an ALIGN_LIST

    ;// we display icons for buttons
    ;// see ALIGN_ICON_1A_PSOURCE and button_bitmap_table

    align_keyboard_swap dd  0   ;// set to 9 to enable the second panel on the dialog
                                ;// this also adjusts the numpad controls to the actual id we want



.CODE



ASSUME_AND_ALIGN
align_enable_keyboard_swap PROC

    ;// shows the appropriate button on the align panel

        mov eax, SW_HIDE
        cmp align_keyboard_swap, 0
        mov edx, SW_SHOW OR SW_SHOWNOACTIVATE
        jz @F
        xchg eax, edx
    @@:
    ;// both args are pushed,

        push eax
        push edx

    ;// then we get the hWnds and call ShowWindow

        invoke GetDlgItem, align_hWnd, IDC_ALIGN_MODE_5A
        push eax
        call ShowWindow
        invoke GetDlgItem, align_hWnd, IDC_ALIGN_MODE_5B
        push eax
        call ShowWindow

        ret

align_enable_keyboard_swap ENDP



ASSUME_AND_ALIGN
align_draw_group_rects PROC STDCALL hDC:DWORD

    ;// task: draw the group rectangles on the screen

    ;// destroys ebx

        mov ebx, align_list
        ASSUME ebx:PTR ALIGN_LIST

    ;// select the appropriate colors

        invoke SelectObject, hDC, hBrush_null
        push eax    ;// save so we can retrieve it
        invoke SelectObject, hDC, hPen_dot
        push eax    ;// save so we can retrieve it

    ;// scan the align_list

        .REPEAT

            GET_OSC_FROM ecx, [ebx].pointer
            .IF clist_Next( oscL, ecx )     ;// make sure we're locked

                pushd ALIGN_GROUP_RADIUS;// 6   int nHeight // height of ellipse used to draw rounded corners
                pushd ALIGN_GROUP_RADIUS;// 5   int nWidth,  // width of ellipse used to draw rounded corners

                mov edx, [ebx].rect.bottom
                mov eax, [ebx].rect.right
                sub edx, GDI_GUTTER_Y - ALIGN_GROUP_RADIUS
                sub eax, GDI_GUTTER_X - ALIGN_GROUP_RADIUS
                push edx                ;// 4   int nBottomRect, // y-coord. of bounding rectangle’s lower-right corner
                push eax                ;// 3   int nRightRect, // x-coord. of bounding rectangle’s lower-right corner

                mov edx, [ebx].rect.top
                mov eax, [ebx].rect.left
                sub edx, GDI_GUTTER_Y + ALIGN_GROUP_RADIUS
                sub eax, GDI_GUTTER_X + ALIGN_GROUP_RADIUS
                push edx                ;// 2   int nTopRect, // y-coord. of bounding rectangle’s upper-left corner
                push eax                ;// 1   int nLeftRect, // x-coord. of bounding rectangle’s upper-left corner

                push hDC                ;// 0   HDC hdc,  // handle of device context

                call RoundRect

            .ENDIF

            add ebx, SIZEOF ALIGN_LIST

        .UNTIL ![ebx].pointer

    ;// restore hDC to what is was when we got here

        push hDC
        call SelectObject
        push hDC
        call SelectObject

    ;// that should do it

        ret


align_draw_group_rects ENDP







;///////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////
;//
;//     ALIGN LIST
;//
comment ~ /*

    the align list is an array of RECT,ptr pairs
    the align_mode indicates whether or not to treat the alignment as a whole group

*/ comment ~


ASSUME_AND_ALIGN
align_build_list PROC USES ebp esi edi ebx

        DEBUG_IF <align_list>   ;// list is supposed to be deallocated and empty !!

        stack_Peek gui_context, ebp ;// get the context

    ;// 1)  determine the mode we are working with
    ;//     mode = true indivates that locked items are grouped together
    ;//     we determine the mode by looking for selection containing
    ;//     a) mixed locked and unlocked
    ;//     b) more than one locked set (need to use the ALREADY_PROCESSED bit)

    ;// scan S
    ;//     if locked
    ;//         if not already processed
    ;//             increase num_locked_group
    ;//             set processed for each
    ;//     else
    ;//         increase num_unlocked
    ;// if ( (num_unlocked && num_locked) || num_locked > 1 ) then mode=mixed

        xor eax, eax                ;// eax is be num_unlocked
        sub ebx, ebx                ;// ebx is used for an iterator and tester
        clist_GetMRS oscS, esi, [ebp]   ;// scan the select list
        xor edx, edx                ;// edx is num_locked_groups
        sub ecx, ecx                ;// ecx is the total number of selected items

        mov align_lock_mode, eax    ;// reset the lock flag

        DEBUG_IF <!!esi>    ;// nothing selected ?!

        .REPEAT ;// scanning oscS

            inc ecx                 ;// increase the total number of selected items
            clist_OrGetNext oscL, esi, ebx
            .IF !ZERO?

                ;// this item is locked
                ;// ebx is now a valid pointer to next locked item
                BITS [esi].dwHintOsc, HINTOSC_STATE_PROCESSED
                .IF !CARRY? ;// have we already seean this locked group ?

                    inc edx             ;// new locked group
                    .REPEAT             ;// set processed bit for all
                        or [ebx].dwHintOsc, HINTOSC_STATE_PROCESSED
                        clist_GetNext oscL, ebx
                    .UNTIL ebx==esi

                .ENDIF

                xor ebx,ebx         ;// ebx must be zero

            .ELSE   ;// this item is not locked

                inc eax

            .ENDIF

            clist_GetNext oscS, esi

        .UNTIL esi== clist_MRS( oscS, ebp )

    ;// now we have eax=num_not_locked and edx=num_locked_groups
    ;// from this we can determine the align mode
    ;// and the mem size required for the align_list

        .IF ( eax && edx ) || edx > 1

            ;// we are in a mixed mode
            ;// number of items == num_not_locked + num_locked_groups

            add eax, edx
            inc align_lock_mode

        .ELSE

            ;// we are in a normal mode
            ;// number of align items = total_num_selected

            mov eax, ecx

        .ENDIF

        mov align_num_items, eax

        ;// each item is 5 dwords

        lea eax, [eax+eax*4]                ;// *5
        lea eax, [eax*4 + SIZEOF ALIGN_LIST];// *4 + 1 record

        invoke memory_Alloc, GMEM_FIXED, eax

        mov align_list, eax
        mov edi, eax            ;// edi will iterate the align_list
        ASSUME edi:PTR ALIGN_LIST

    ;// now we can clean up the processed bits
    ;// we may be setting it again in the next section

        CLEAR_PROCESSED_BIT Z

    ;// 2)  now that we know the size and have allocated memory for the align list
    ;//     we fill in the list and build the rectangles
    ;//     for locked items, we build .rect as the union of all rects in the group
    ;//     then fill them in according to the mode
    ;//     as an added helper, we build align_extent_rect and align_extent_ptr

    ;// scan the select list and assign records

        clist_GetMRS oscS, esi, ebp
        xor ebx, ebx                        ;// ebx must be zero for testing

        mov align_extent_ptr.left, ebx      ;// reset the extent rect
        mov align_extent_ptr.top, ebx
        mov align_extent_ptr.right, ebx
        mov align_extent_ptr.bottom, ebx

        .REPEAT ;// scanning oscS with esi

            BITS [esi].dwHintOsc, HINTOSC_STATE_PROCESSED
            .IF !CARRY?     ;// already processed ?

                rect_CopyTo [esi].rect, [edi].rect  ;// set the this rect in the align list
                mov [edi].pointer, esi              ;// store the pointer in the align listt

                .IF align_lock_mode                 ;// check for locked ?

                    clist_OrGetNext oscL, esi, ebx  ;// ebx was zero
                    .IF !ZERO?                      ;// here is locked group we have processed yet

                        .REPEAT ;// scanning the locked group with ebx

                            or [ebx].dwHintOsc, HINTOSC_STATE_PROCESSED

                        ;// extend the boundaries of the ALIGN_LIST record

                            point_GetTL [ebx].rect
                            cmp eax, [edi].rect.left
                            jge @F
                            mov [edi].rect.left, eax
                        @@:
                            cmp edx, [edi].rect.top
                            jge @F
                            mov [edi].rect.top, edx
                        @@:
                            point_GetBR [ebx].rect
                            cmp eax, [edi].rect.right
                            jle @F
                            mov [edi].rect.right, eax
                        @@:
                            cmp edx, [edi].rect.bottom
                            jle @F
                            mov [edi].rect.bottom, edx
                        @@:

                            clist_GetNext oscL, ebx

                        .UNTIL ebx==esi

                        xor ebx, ebx    ;// ebx must be zero for testing

                    .ENDIF  ;// locked group

                .ENDIF  ;// align_lock_mode

            ;// check the align extents
            ;// we'll use ecx to do this

                ASSUME ecx:PTR ALIGN_LIST

            ;// LEFT
                mov ecx, align_extent_ptr.left  ;// get the current pointer
                test ecx, ecx                   ;// if not set yet, then jump to setter
                jz K1
                mov eax, [edi].rect.left        ;// get the left side of the rect we just built
                cmp eax, [ecx].rect.left        ;// see if it's lefter
                jge K2
            K1: mov align_extent_ptr.left, edi  ;// set the new extent
            K2:
            ;// TOP
                mov ecx, align_extent_ptr.top   ;// get the current pointer
                test ecx, ecx                   ;// if not set yet, then jump to setter
                jz K3
                mov eax, [edi].rect.top         ;// get the top side of the rect we just built
                cmp eax, [ecx].rect.top         ;// see if it's topper
                jge K4
            K3: mov align_extent_ptr.top, edi   ;// set the new extent
            K4:
            ;// RIGHT
                mov ecx, align_extent_ptr.right ;// get the current pointer
                test ecx, ecx                   ;// if not set yet, then jump to setter
                jz K5
                mov eax, [edi].rect.right       ;// get the right side of the rect we just built
                cmp eax, [ecx].rect.right       ;// see if it's righter
                jle K6
            K5: mov align_extent_ptr.right, edi ;// set the new extent
            K6:
            ;// BOTTOM
                mov ecx, align_extent_ptr.bottom;// get the current pointer
                test ecx, ecx                   ;// if not set yet, then jump to setter
                jz K7
                mov eax, [edi].rect.bottom      ;// get the bottom side of the rect we just built
                cmp eax, [ecx].rect.bottom      ;// see if it's bottomer
                jle K8
            K7: mov align_extent_ptr.bottom, edi;// set the new extent
            K8:

            ;// iterate the align_list pointer

                add edi, SIZEOF ALIGN_LIST

            .ENDIF  ;// record already processed

            clist_GetNext oscS,esi

        .UNTIL esi == clist_MRS( oscS, ebp )

    ;// edi is now at last record, we need to zero the pointer

        mov [edi].pointer, 0

    ;// then we clean up our processed bit mess

        CLEAR_PROCESSED_BIT Z

    ;// that should do it !!!

        ret

align_build_list ENDP





ASSUME_AND_ALIGN
PROLOGUE_OFF
align_sort_list PROC STDCALL key_off:DWORD, order:DWORD

    ;// swap sort of align_list using key_off as the sort key
    ;// key_off must be byte offset into .rect
    ;// sort order is passed by caller, non zero is descending
    ;// equal keys use the 'other' key as the second number
    ;// left <--> top  and  right <--> bottom

        push edi    ;// must preserve

    ;// stack
    ;// edi ret     key_off order
    ;// 00  04      08      0C

        st_key_off TEXTEQU <(DWORD PTR [esp+08h])>
        st_order   TEXTEQU <(DWORD PTR [esp+0Ch])>

    ;// setup

        mov ecx, st_key_off         ;// key off for sort

        ASSUME ecx:PTR DWORD
        ASSUME edx:PTR DWORD
        ASSUME esi:PTR ALIGN_LIST   ;// iter 1
        ASSUME edi:PTR ALIGN_LIST   ;// iter 2

        mov esi, align_list

        cmp st_order, 0
        jnz loop_outer_descend
        jmp loop_outer_ascend


;// ascending sort

next_outer_ascend:  add esi, SIZEOF ALIGN_LIST  ;// esi to next ALIGN_LIST record
                    cmp [esi].pointer, 0        ;// end of list ?
                    je all_done                 ;// done with sort if so
loop_outer_ascend:  mov eax, [esi].rect[ecx]    ;// comparitor
                    mov edi, esi                ;// initialize iter 2
next_inner_ascend:  add edi, SIZEOF ALIGN_LIST  ;// next iter 2
                    cmp [edi].pointer, 0        ;// see if done
                    je next_outer_ascend        ;// next outer if done with inner
loop_inner_ascend:  cmp eax, [edi].rect[ecx]    ;// do the compare
                    jl next_inner_ascend        ;// if greater, then next inner
                    jne swap_items_ascend       ;// if not same, do other test
equal_item_ascend:  mov edx, ecx                ;// they are the same, get the offet
                    xor edx, 4                  ;// xor to get the 'other' pointer
                    cmp eax, [edi].rect[edx]    ;// do the compare
                    jle next_inner_ascend       ;// if greater, then continue loop
swap_items_ascend:  call swap_items             ;// call the common swapper
                    jmp next_inner_ascend       ;// back to inner loop

;// descending sort

next_outer_descend: add esi, SIZEOF ALIGN_LIST  ;// esi to next ALIGN_LIST record
                    cmp [esi].pointer, 0        ;// end of list ?
                    je all_done                 ;// done with sort if so
loop_outer_descend: mov eax, [esi].rect[ecx]    ;// comparitor
                    mov edi, esi                ;// initialize iter 2
next_inner_descend: add edi, SIZEOF ALIGN_LIST  ;// next iter 2
                    cmp [edi].pointer, 0        ;// see if done
                    je next_outer_descend       ;// next outer if done with inner
loop_inner_descend: cmp eax, [edi].rect[ecx]    ;// do the compare
                    jg next_inner_descend       ;// if greater, then next inner
                    jne swap_items_descend      ;// if not same, do other test
equal_item_descend: mov edx, ecx                ;// they are the same, get the offet
                    xor edx, 4                  ;// xor to get the 'other' pointer
                    cmp eax, [edi].rect[edx]    ;// do the compare
                    jge next_inner_descend      ;// if greater, then continue loop
swap_items_descend: call swap_items             ;// call the common swapper
                    jmp next_inner_descend      ;// back to inner loop


;// and that's it



all_done:           pop edi
                    ret 8




    ;// local function swap_items


swap_items:

    ;// swap the rectangles

        rect_Swap [esi].rect, [edi].rect

    ;// swap the pointers

        mov eax, [edi].pointer
        xchg eax, [esi].pointer
        mov [edi].pointer, eax

    ;// take care of extents

        .IF esi == align_extent_ptr.left
            mov align_extent_ptr.left, edi
        .ELSEIF edi == align_extent_ptr.left
            mov align_extent_ptr.left, esi
        .ENDIF
        .IF esi == align_extent_ptr.top
            mov align_extent_ptr.top, edi
        .ELSEIF edi == align_extent_ptr.top
            mov align_extent_ptr.top, esi
        .ENDIF
        .IF esi == align_extent_ptr.right
            mov align_extent_ptr.right, edi
        .ELSEIF edi == align_extent_ptr.right
            mov align_extent_ptr.right, esi
        .ENDIF
        .IF esi == align_extent_ptr.bottom
            mov align_extent_ptr.bottom, edi
        .ELSEIF edi == align_extent_ptr.bottom
            mov align_extent_ptr.bottom, esi
        .ENDIF

    ;// reload the sort key for new value

        mov eax, [esi].rect[ecx]        ;// reload comparitor

    ;// jump back to inner loop

        retn




    ;// macro clean up

        st_key_off TEXTEQU <>
        st_order   TEXTEQU <>



align_sort_list ENDP
PROLOGUE_ON








ASSUME_AND_ALIGN
align_move_item_no_pin PROC

        ASSUME ebx:PTR ALIGN_LIST   ;// passed by caller

    ;// destroys esi
    ;// mouse_delta must have the offset to use
    ;// edi (unredo recorder) is advanced,
    ;// DOES terminate the pin record
    ;// does NOT terminate the final osc record

    ;// this routine moves one item from the align list
    ;// it takes care of undo and accounts for locked groups

        GET_OSC_FROM esi, [ebx].pointer ;// get the first osc

        push ebx    ;// must preserve

    move_the_osc:

        mov eax, [esi].id       ;// store unredo osc id
        .IF !eax
            invoke unredo_assign_id
        .ENDIF
        stosd

        point_Get mouse_delta   ;// store the unredo delta x y values
        stosd
        mov eax, edx
        stosd

        xor eax, eax
        stosd

        OSC_TO_BASE esi, ebx    ;// move the osc by calling base class
        invoke [ebx].gui.Move   ;//  (takes care of invalidate)

        cmp align_lock_mode, 0  ;// check if we care about locked groups
        je all_done

        clist_GetNext oscL, esi ;// see if we are locked
        test esi, esi
        jz all_done

        mov ebx, [esp]
        ASSUME ebx:PTR ALIGN_LIST
        cmp esi, [ebx].pointer  ;// see if we are done with the locked group
        jne move_the_osc        ;// continue on if still processing locked items

    all_done:

        pop ebx

        ret

align_move_item_no_pin ENDP













;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;///
;///    A L I G N   M O D E S
;///



;/////////////////////////////////////////////////////////////////////////
;//
;// ALIGN_MODE_5A       swap keyboard focus
;// ALIGN_MODE_5B
;//

ASSUME_AND_ALIGN
align_5A PROC

        ASSUME ebp:PTR LIST_CONTEXT     ;// preserve ebp
    ;// may destroy esi ebx
    ;// edi is unredo_pRecorder

        mov align_keyboard_swap, 9
        invoke align_enable_keyboard_swap

        ret

align_5A ENDP

ASSUME_AND_ALIGN
align_5B PROC

        ASSUME ebp:PTR LIST_CONTEXT     ;// preserve ebp
    ;// may destroy esi ebx
    ;// edi is unredo_pRecorder

        mov align_keyboard_swap, 0
        invoke align_enable_keyboard_swap

        ret

align_5B ENDP

;//
;// ALIGN_MODE_5A       swap keyboard focus
;// ALIGN_MODE_5B
;//
;/////////////////////////////////////////////////////////////////////////













;/////////////////////////////////////////////////////////////////////////
;//
;// ALIGN_MODE_4A  Align objects so their left sides are equal. (NumPad 4)
;//

ASSUME_AND_ALIGN
align_4A PROC

    ASSUME ebp:PTR LIST_CONTEXT     ;// preserve ebp
    ;// may destroy esi ebx
    ;// edi is unredo_pRecorder

        mov ebx, align_list
        ASSUME ebx:PTR ALIGN_LIST

        mov mouse_delta.y, 0

        .REPEAT

            mov ecx, align_extent_ptr.left
            ASSUME ecx:PTR ALIGN_LIST

            mov eax, [ecx].rect.left
            sub eax, [ebx].rect.left
            mov mouse_delta.x, eax
            invoke align_move_item_no_pin   ;// move and terminate the unredo record

            add ebx, SIZEOF ALIGN_LIST

        .UNTIL ![ebx].pointer

        ret

align_4A ENDP

;//
;// ALIGN_MODE_4A  Align objects so their left sides are equal. (NumPad 4)
;//
;/////////////////////////////////////////////////////////////////////////

;/////////////////////////////////////////////////////////////////////////
;//
;// ALIGN_MODE_8A  Align objects so their tops are equal.       (NumPad 8)
;//

ASSUME_AND_ALIGN
align_8A PROC

    ASSUME ebp:PTR LIST_CONTEXT     ;// preserve ebp
    ;// may destroy esi ebx
    ;// edi is unredo_pRecorder

        mov ebx, align_list
        ASSUME ebx:PTR ALIGN_LIST

        mov mouse_delta.x, 0

        .REPEAT

            mov ecx, align_extent_ptr.top
            ASSUME ecx:PTR ALIGN_LIST

            mov eax, [ecx].rect.top
            sub eax, [ebx].rect.top
            mov mouse_delta.y, eax
            invoke align_move_item_no_pin   ;// move and terminate the unredo record

            add ebx, SIZEOF ALIGN_LIST

        .UNTIL ![ebx].pointer

        ret

align_8A ENDP

;//
;// ALIGN_MODE_8A  Align objects so their tops are equal.       (NumPad 8)
;//
;/////////////////////////////////////////////////////////////////////////

;/////////////////////////////////////////////////////////////////////////
;//
;// ALIGN_MODE_6A  Align objects so their right sides are equal.(NumPad 6)
;//

ASSUME_AND_ALIGN
align_6A PROC

    ASSUME ebp:PTR LIST_CONTEXT     ;// preserve ebp
    ;// may destroy esi ebx
    ;// edi is unredo_pRecorder

        mov ebx, align_list
        ASSUME ebx:PTR ALIGN_LIST

        mov mouse_delta.y, 0

        .REPEAT

            mov ecx, align_extent_ptr.right
            ASSUME ecx:PTR ALIGN_LIST

            mov eax, [ecx].rect.right
            sub eax, [ebx].rect.right
            mov mouse_delta.x, eax
            invoke align_move_item_no_pin   ;// move and terminate the unredo record

            add ebx, SIZEOF ALIGN_LIST

        .UNTIL ![ebx].pointer

        ret

align_6A ENDP

;//
;// ALIGN_MODE_6A  Align objects so their right sides are equal.(NumPad 6)
;//
;/////////////////////////////////////////////////////////////////////////

;/////////////////////////////////////////////////////////////////////////
;//
;// ALIGN_MODE_2A  Align objects so their bottoms are equal.    (NumPad 2)
;//

ASSUME_AND_ALIGN
align_2A PROC

    ASSUME ebp:PTR LIST_CONTEXT     ;// preserve ebp
    ;// may destroy esi ebx
    ;// edi is unredo_pRecorder

        mov ebx, align_list
        ASSUME ebx:PTR ALIGN_LIST

        mov mouse_delta.x, 0

        .REPEAT

            mov ecx, align_extent_ptr.bottom
            ASSUME ecx:PTR ALIGN_LIST

            mov eax, [ecx].rect.bottom
            sub eax, [ebx].rect.bottom
            mov mouse_delta.y, eax
            invoke align_move_item_no_pin   ;// move and terminate the unredo record

            add ebx, SIZEOF ALIGN_LIST

        .UNTIL ![ebx].pointer

        ret

align_2A ENDP

;//
;// ALIGN_MODE_2A  Align objects so their bottoms are equal.    (NumPad 2)
;//
;/////////////////////////////////////////////////////////////////////////














;/////////////////////////////////////////////////////////////////////////
;//
;// ALIGN_MODE_1A  Align objects so their middles are equal.    (NumPad 1)
;//

ASSUME_AND_ALIGN
align_1A PROC

    ASSUME ebp:PTR LIST_CONTEXT     ;// preserve ebp
    ;// may destroy esi ebx
    ;// edi is unredo_pRecorder

    ;// determine the middle line and store on the stack

        mov eax, align_extent_ptr.top
        mov edx, align_extent_ptr.bottom

        mov eax, (ALIGN_LIST PTR [eax]).rect.top
        add eax, (ALIGN_LIST PTR [edx]).rect.bottom

        push eax    ;// [esp] is now the 2 * middle line

    ;// move all the objects

        mov ebx, align_list
        ASSUME ebx:PTR ALIGN_LIST

        mov mouse_delta.x, 0

        .REPEAT

            mov eax, [esp]
            sub eax, [ebx].rect.top
            sub eax, [ebx].rect.bottom
            sar eax, 1
            mov mouse_delta.y, eax

            invoke align_move_item_no_pin   ;// move and terminate the unredo record

            add ebx, SIZEOF ALIGN_LIST

        .UNTIL ![ebx].pointer

    ;// clean up the stack and split

        pop eax

        ret

align_1A ENDP

;//
;// ALIGN_MODE_1A  Align objects so their middles are equal.    (NumPad 1)
;//
;/////////////////////////////////////////////////////////////////////////

;/////////////////////////////////////////////////////////////////////////
;//
;// ALIGN_MODE_7A  Align objects so their centers are equal.    (NumPad 7)
;//

ASSUME_AND_ALIGN
align_7A PROC

    ASSUME ebp:PTR LIST_CONTEXT     ;// preserve ebp
    ;// may destroy esi ebx
    ;// edi is unredo_pRecorder

    ;// determine the center line and store on the stack

        mov eax, align_extent_ptr.left
        mov edx, align_extent_ptr.right

        mov eax, (ALIGN_LIST PTR [eax]).rect.left
        add eax, (ALIGN_LIST PTR [edx]).rect.right

        push eax    ;// [esp] is now the 2 * center line

    ;// move all the objects

        mov ebx, align_list
        ASSUME ebx:PTR ALIGN_LIST

        mov mouse_delta.y, 0

        .REPEAT

            mov eax, [esp]
            sub eax, [ebx].rect.left
            sub eax, [ebx].rect.right
            sar eax, 1
            mov mouse_delta.x, eax

            invoke align_move_item_no_pin   ;// move and terminate the unredo record

            add ebx, SIZEOF ALIGN_LIST

        .UNTIL ![ebx].pointer

    ;// clean up the stack and split

        pop eax

        ret

align_7A ENDP

;//
;// ALIGN_MODE_7A  Align objects so their centers are equal.    (NumPad 7)
;//
;/////////////////////////////////////////////////////////////////////////
















;/////////////////////////////////////////////////////////////////////////
;//
;// ALIGN_MODE_4B  Equally space objects towards the left. (NumPad 4)
;//

ASSUME_AND_ALIGN
align_4B PROC

    ASSUME ebp:PTR LIST_CONTEXT     ;// preserve ebp
    ;// may destroy esi ebx
    ;// edi is unredo_pRecorder

        invoke align_sort_list, OFFSET RECT.left, 0

        mov ebx, align_list
        ASSUME ebx:PTR ALIGN_LIST

        mov eax, [ebx].rect.left

    align_push_to_the_left::    ;// jumped to by align_7B

        mov mouse_delta.y, 0
        push eax                ;// accumulator

        .REPEAT

            sub eax, [ebx].rect.left    ;// eax is the absolute offset of where we are now
            mov mouse_delta.x, eax

            invoke align_move_item_no_pin   ;// move and terminate the unredo record

            mov eax, [esp]              ;// get the accumulator
            add eax, [ebx].rect.right   ;// add right
            sub eax, [ebx].rect.left    ;// subsubtract left to accumulate width
            add eax, ALIGN_SPACING      ;// add the spacing adjustment
            add ebx, SIZEOF ALIGN_LIST  ;// iterate the source pointer
            mov [esp], eax              ;// store the new accumulator

        .UNTIL ![ebx].pointer

        pop eax

    ;// that's it

        ret

align_4B ENDP

;//
;// ALIGN_MODE_4B  Equally space objects towards the left. (NumPad 4)
;//
;/////////////////////////////////////////////////////////////////////////

;/////////////////////////////////////////////////////////////////////////
;//
;// ALIGN_MODE_8B  Equally space objects towards the top. (NumPad 8)
;//

ASSUME_AND_ALIGN
align_8B PROC

    ASSUME ebp:PTR LIST_CONTEXT     ;// preserve ebp
    ;// may destroy esi ebx
    ;// edi is unredo_pRecorder

        invoke align_sort_list, OFFSET RECT.top, 0

        mov ebx, align_list
        ASSUME ebx:PTR ALIGN_LIST

        mov eax, [ebx].rect.top

align_push_to_the_top:: ;// jumped to by align_1B

        mov mouse_delta.x, 0
        push eax    ;// accumulator

        .REPEAT

            sub eax, [ebx].rect.top ;// eax is the absolute offset of where we are now
            mov mouse_delta.y, eax

            invoke align_move_item_no_pin   ;// move and terminate the unredo record

            mov eax, [esp]              ;// get the accumulator
            add eax, [ebx].rect.bottom  ;// add bottom
            sub eax, [ebx].rect.top     ;// subtract top to accumulate height
            add eax, ALIGN_SPACING      ;// add the spacing adjustment
            add ebx, SIZEOF ALIGN_LIST  ;// iterate the source pointer
            mov [esp], eax              ;// store the new accumulator

        .UNTIL ![ebx].pointer

        pop eax


        ret

align_8B ENDP

;//
;// ALIGN_MODE_8B  Equally space objects towards the top. (NumPad 8)
;//
;/////////////////////////////////////////////////////////////////////////

;/////////////////////////////////////////////////////////////////////////
;//
;// ALIGN_MODE_6B  Equally space objects towards the right. (NumPad 6)
;//

ASSUME_AND_ALIGN
align_6B PROC

    ASSUME ebp:PTR LIST_CONTEXT     ;// preserve ebp
    ;// may destroy esi ebx
    ;// edi is unredo_pRecorder

        invoke align_sort_list, OFFSET RECT.right, 1

        mov ebx, align_list
        ASSUME ebx:PTR ALIGN_LIST

        mov mouse_delta.y, 0

        mov eax, [ebx].rect.right
        push eax    ;// accumulator

        .REPEAT

            sub eax, [ebx].rect.right   ;// eax is the absolute offset of where we are now
            mov mouse_delta.x, eax

            invoke align_move_item_no_pin   ;// move and terminate the unredo record

            mov eax, [esp]              ;// get the accumulator
            add eax, [ebx].rect.left    ;// add left
            sub eax, [ebx].rect.right   ;// subtract right to accumulate width
            sub eax, ALIGN_SPACING      ;// add the spacing adjustment
            add ebx, SIZEOF ALIGN_LIST  ;// iterate the source pointer
            mov [esp], eax              ;// store the new accumulator

        .UNTIL ![ebx].pointer

        pop eax

        ret

align_6B ENDP

;//
;// ALIGN_MODE_6B  Equally space objects towards the right. (NumPad 6)
;//
;/////////////////////////////////////////////////////////////////////////

;/////////////////////////////////////////////////////////////////////////
;//
;// ALIGN_MODE_2B  Equally space objects towards the bottom. (NumPad 2)
;//

ASSUME_AND_ALIGN
align_2B PROC

    ASSUME ebp:PTR LIST_CONTEXT     ;// preserve ebp
    ;// may destroy esi ebx
    ;// edi is unredo_pRecorder

        invoke align_sort_list, OFFSET RECT.bottom, 1

        mov ebx, align_list
        ASSUME ebx:PTR ALIGN_LIST

        mov mouse_delta.x, 0

        mov eax, [ebx].rect.bottom
        push eax    ;// accumulator

        .REPEAT

            sub eax, [ebx].rect.bottom  ;// eax is the absolute offset of where we are now
            mov mouse_delta.y, eax

            invoke align_move_item_no_pin   ;// move and terminate the unredo record

            mov eax, [esp]              ;// get the accumulator
            add eax, [ebx].rect.top     ;// add top
            sub eax, [ebx].rect.bottom  ;// subtract bottom to accumulate height
            sub eax, ALIGN_SPACING      ;// add the spacing adjustment
            add ebx, SIZEOF ALIGN_LIST  ;// iterate the source pointer
            mov [esp], eax              ;// store the new accumulator

        .UNTIL ![ebx].pointer

        pop eax

        ret

align_2B ENDP

;//
;// ALIGN_MODE_2B  Equally space objects towards the bottom. (NumPad 2)
;//
;/////////////////////////////////////////////////////////////////////////





;/////////////////////////////////////////////////////////////////////////
;//
;// ALIGN_MODE_1B  Equally space objects up and down towards the middle. (NumPad 1)
;//

ASSUME_AND_ALIGN
align_1B PROC

    ASSUME ebp:PTR LIST_CONTEXT     ;// preserve ebp
    ;// may destroy esi ebx
    ;// edi is unredo_pRecorder


    ;// sort top to bottom

        invoke align_sort_list, OFFSET RECT.top, 0

    ;// determine the negative of the total desired height of the results

        mov ebx, align_list
        ASSUME ebx:PTR ALIGN_LIST
        mov eax, ALIGN_SPACING  ;// start at neg to skip adding 1 space
        .REPEAT

            sub eax, [ebx].rect.bottom
            add eax, [ebx].rect.top
            add ebx, SIZEOF ALIGN_LIST
            sub eax, ALIGN_SPACING

        .UNTIL ![ebx].pointer

    ;// determine the start point for push_to_the_top
    ;// eax is now -T
    ;// we want C-T/2 = (top+bottom-T)/2

        mov ebx, align_extent_ptr.top
        add eax, [ebx].rect.top     ;// top-T
        mov ebx, align_extent_ptr.bottom
        add eax, [ebx].rect.bottom  ;// bottom+top-T

        sar eax, 1                  ;// (bottom+top-T)/2

    ;// exit to align_push_to_the_top

        mov ebx, align_list
        jmp align_push_to_the_top

align_1B ENDP

;//
;// ALIGN_MODE_1B  Equally space objects up and down towards the middle. (NumPad 1)
;//
;/////////////////////////////////////////////////////////////////////////

;/////////////////////////////////////////////////////////////////////////
;//
;// ALIGN_MODE_7B  Equally space objects left and right towards the center. (NumPad 7)
;//

ASSUME_AND_ALIGN
align_7B PROC

    ASSUME ebp:PTR LIST_CONTEXT     ;// preserve ebp
    ;// may destroy esi ebx
    ;// edi is unredo_pRecorder

    ;// sort left to right

        invoke align_sort_list, OFFSET RECT.left, 0

    ;// determine the negative of the total desired width of the results

        mov ebx, align_list
        ASSUME ebx:PTR ALIGN_LIST
        mov eax, ALIGN_SPACING  ;// start at neg to skip adding 1 space
        .REPEAT

            sub eax, [ebx].rect.right
            add eax, [ebx].rect.left
            add ebx, SIZEOF ALIGN_LIST
            sub eax, ALIGN_SPACING

        .UNTIL ![ebx].pointer

    ;// determine the start point for push_to_the_left
    ;// eax is now -T
    ;// we want C-T/2 = (R+L-T)/2

        mov ebx, align_extent_ptr.left
        add eax, [ebx].rect.left        ;// L-T
        mov ebx, align_extent_ptr.right
        add eax, [ebx].rect.right       ;// R+L-T

        sar eax, 1                      ;// (R+L-T)/2

    ;// exit to align_push_to_the_left

        mov ebx, align_list
        jmp align_push_to_the_left


align_7B ENDP

;//
;// ALIGN_MODE_7B  Equally space objects left and right towards the center. (NumPad 7)
;//
;/////////////////////////////////////////////////////////////////////////





comment ~ /*

EXPAND

    to account for wildly verying sizes we do the following algorithm
    which is the same for left/right an dtop bottom
    draw pictures to get a better idea of what we're doing

        sort from left to right

        define a line segement TL to TR

            TL = max( extent.left->right, extent.right->left )
            TR = min( extent.right->left, extent.left->right )

        define T as TR-TL

        determine the sum of the widths W of all objects that do not set the extent
        keep track of N as the number of non-extent objects

        spacing amount h = (T-W) / (N+1)

        do a left spacing using L0 = TL + h
        do not move the extent objects


    example

    A   |--------------------|
    B     |-------|
    C                  |----------|

                       |<----|
                       TL    TR

*/ comment ~

;/////////////////////////////////////////////////////////////////////////
;//
;// ALIGN_MODE_9B  Expand objects left and right away from the center. (NumPad 9)
;//


ASSUME_AND_ALIGN
align_9B PROC

    ASSUME ebp:PTR LIST_CONTEXT     ;// preserve ebp
    ;// may destroy esi ebx
    ;// edi is unredo_pRecorder

    ;// sort from left to right

        invoke align_sort_list, OFFSET RECT.left, 0

    ;// determine the sum of the widths W of all objects that do not set the extent
    ;// keep track of negative N as the number of non-extent objects
    ;// we do this to prevent a register mixup later on

        ASSUME ebx:PTR ALIGN_LIST

        xor eax, eax                ;// eax accumulates width
        mov ebx, align_list         ;// ebx scan the list
        sub ecx, ecx                ;// ecx counts non-extent objects

        .REPEAT

            .IF ebx != align_extent_ptr.left && ebx != align_extent_ptr.right

                dec ecx
                add eax, [ebx].rect.right
                sub eax, [ebx].rect.left

            .ENDIF

            add ebx, SIZEOF ALIGN_LIST

        .UNTIL ![ebx].pointer

    ;// now eax = W

    ;// if non-extent is zero, then exit

        test ecx, ecx
        jz all_done

    ;// determine the TL, TR and T
    ;// TL = max( extent.left->right, extent.right->left )
    ;// TR = min( extent.right->left, extent.left->right )
    ;// this is just sort, we can push and load as required

        ASSUME esi:PTR ALIGN_LIST

        mov esi, align_extent_ptr.left  ;// left
        mov ebx, align_extent_ptr.right ;// right

        mov edx, [esi].rect.right
        cmp edx, [ebx].rect.left
        jle J1
        push [ebx].rect.left    ;// save TL, TR already loaded
        jmp J2
    J1:
        push edx                ;// save TL
        mov edx, [ebx].rect.left;// load the correct TR
    J2:
        sub edx, [esp]  ;// TR-TL = T
        sub eax, edx    ;// W-T
        dec ecx         ;// -N-1
        cdq
        idiv ecx        ;// eax = h

        xchg eax, [esp] ;// stack = h, eax = TL
        add eax, [esp]  ;// eax = TL+h
        push eax        ;// stack = accumulater, h

    ;// now we do left push

        mov ebx, align_list
        mov mouse_delta.y, 0

        .REPEAT

            .IF ebx != align_extent_ptr.left && ebx != align_extent_ptr.right

                ;// eax has the target

                sub eax, [ebx].rect.left
                mov mouse_delta.x, eax

                invoke align_move_item_no_pin

                mov eax, [esp]              ;// get the accumulator
                add eax, [ebx].rect.right   ;// add right
                sub eax, [ebx].rect.left    ;// subsubtract left to accumulate width
                add eax, [esp+4]            ;// add the spacing adjustment
                mov [esp], eax              ;// store the new accumulator

            .ELSE   ;// pretend to move so we maintain the selection state when undoing

                mov mouse_delta.x, 0
                invoke align_move_item_no_pin
                mov eax, [esp]  ;// reload the desired x location

            .ENDIF

            add ebx, SIZEOF ALIGN_LIST

        .UNTIL ![ebx].pointer

    ;// clean up the stack and split

        add esp, 8

    all_done:

        ret

align_9B ENDP

;//
;// ALIGN_MODE_9B  Expand objects left and right away from the center. (NumPad 9)
;//
;/////////////////////////////////////////////////////////////////////////

;/////////////////////////////////////////////////////////////////////////
;//
;// ALIGN_MODE_3B  Expand objects up and down away from the middle. (NumPad 3)
;//

ASSUME_AND_ALIGN
align_3B PROC

    ASSUME ebp:PTR LIST_CONTEXT     ;// preserve ebp
    ;// may destroy esi ebx
    ;// edi is unredo_pRecorder

    ;// sort from top to bottom

        invoke align_sort_list, OFFSET RECT.top, 0

    ;// determine the sum of the widths W of all objects that do not set the extent
    ;// keep track of negative N as the number of non-extent objects
    ;// we do this to prevent a register mixup later on

        ASSUME ebx:PTR ALIGN_LIST

        xor eax, eax                ;// eax accumulates width
        mov ebx, align_list         ;// ebx scan the list
        sub ecx, ecx                ;// ecx counts non-extent objects

        .REPEAT

            .IF ebx != align_extent_ptr.top && ebx != align_extent_ptr.bottom

                dec ecx
                add eax, [ebx].rect.bottom
                sub eax, [ebx].rect.top

            .ENDIF

            add ebx, SIZEOF ALIGN_LIST

        .UNTIL ![ebx].pointer

    ;// now eax = W

    ;// if non-extent is zero, then exit

        test ecx, ecx
        jz all_done

    ;// determine the TL, TR and T
    ;// TL = max( extent.top->bottom, extent.bottom->top )
    ;// TR = min( extent.bottom->top, extent.top->bottom )
    ;// this is just sort, we can push and load as required

        ASSUME esi:PTR ALIGN_LIST

        mov esi, align_extent_ptr.top       ;// top
        mov ebx, align_extent_ptr.bottom    ;// bottom

        mov edx, [esi].rect.bottom
        cmp edx, [ebx].rect.top
        jle J1
        push [ebx].rect.top ;// save TL, TR already loaded
        jmp J2
    J1:
        push edx                ;// save TL
        mov edx, [ebx].rect.top;// load the correct TR
    J2:
        sub edx, [esp]  ;// TR-TL = T
        sub eax, edx    ;// W-T
        dec ecx         ;// -N-1
        cdq
        idiv ecx        ;// eax = h

        xchg eax, [esp] ;// stack = h, eax = TL
        add eax, [esp]  ;// eax = TL+h
        push eax        ;// stack = accumulater, h

    ;// now we do top push

        mov ebx, align_list
        mov mouse_delta.x, 0

        .REPEAT

            .IF ebx != align_extent_ptr.top && ebx != align_extent_ptr.bottom

                ;// eax has the target

                sub eax, [ebx].rect.top
                mov mouse_delta.y, eax

                invoke align_move_item_no_pin

                mov eax, [esp]              ;// get the accumulator
                add eax, [ebx].rect.bottom  ;// add bottom
                sub eax, [ebx].rect.top     ;// subsubtract top to accumulate height
                add eax, [esp+4]            ;// add the spacing adjustment
                mov [esp], eax              ;// store the new accumulator

            .ELSE   ;// pretend to move so we maintain the selection state when undoing

                mov mouse_delta.y, 0
                invoke align_move_item_no_pin
                mov eax, [esp]  ;// reload the desired y location

            .ENDIF

            add ebx, SIZEOF ALIGN_LIST

        .UNTIL ![ebx].pointer

    ;// clean up the stack and split

        add esp, 8

    all_done:

        ret

align_3B ENDP

;//
;// ALIGN_MODE_3B  Expand objects up and down away from the middle. (NumPad 3)
;//
;/////////////////////////////////////////////////////////////////////////


























;/////////////////////////////////////////////////////////////////////////
;//
;// ALIGN_MODE_3A  Mirror objects top to bottom.                (NumPad 3)
;//

ASSUME_AND_ALIGN
align_3A PROC

    ASSUME ebp:PTR LIST_CONTEXT     ;// preserve ebp
    ;// may destroy esi ebx
    ASSUME edi:PTR DWORD    ;// edi is unredo_pRecorder


    ;// determine common center
    ;// determine how to move the osc
    ;// negate all the deltas

    ;// 1) determine the common center

        mov eax, align_extent_ptr.bottom
        mov edx, align_extent_ptr.top

        mov eax, (ALIGN_LIST PTR [eax]).rect.bottom
        add eax, (ALIGN_LIST PTR [edx]).rect.top

    ;// do the flip     dy = 2C - T - B
    ;//                 p = -p
    ;//                 dp = 2*p

        ;// shl eax, 1
        push eax    ;// save on stack

        mov mouse_delta.x, 0

        mov ebx, align_list
        ASSUME ebx:PTR ALIGN_LIST

        .REPEAT

            GET_OSC_FROM esi, [ebx].pointer

        flip_this_osc:  ;// jumped to by locked group test down below

        ;// store the osc in unredo

            mov eax, [esi].id
            .IF !eax
                invoke unredo_assign_id
            .ENDIF
            stosd

        ;// determine how to move

            xor eax, eax
            stosd           ;// X

            mov eax, [esp]              ;// 2C
            sub eax, [esi].rect.top     ;// 2C-T
            sub eax, [esi].rect.bottom  ;// 2C-T-B

            stosd           ;// Y

        ;// move the osc

        push ebx    ;// we're about to destroy ebx

            mov mouse_delta.y, eax

            OSC_TO_BASE esi, ebx
            invoke [ebx].gui.Move

        ;// take care of pins


            ITERATE_PINS

                or [esi].dwHintOsc, HINTOSC_INVAL_DO_PINS
                or [ebx].dwHintI, HINTI_PIN_PHETA_CHANGED

                mov eax, ebx    ;// turn ptr to pin offset
                sub eax, esi
                stosd           ;// store in unredo table

                fld [ebx].pheta ;// get current pheta
                fchs            ;// mirror about x axis
                fst [ebx].pheta ;// store back in pin
                fadd st, st     ;// 2p = amount to undo
                fstp [edi]      ;// store in unredo record
                add edi, 4      ;// iterate edi

            PINS_ITERATE

            ;// terminate the osc/pin record

            xor eax, eax
            stosd

        pop ebx                 ;// retrieve ebx
        ASSUME ebx:PTR ALIGN_LIST

        ;// determine if we care about locked groups

            cmp align_lock_mode, 0  ;// do we care ?
            jz next_aligner

            clist_GetNext oscL, esi ;// are we locked ?
            test esi, esi
            jz next_aligner

            cmp esi, [ebx].pointer  ;// are we done with this set ?
            jne flip_this_osc       ;// if not, continue with next osc

        ;// iterate

        next_aligner:

            add ebx, SIZEOF ALIGN_LIST

        .UNTIL ![ebx].pointer

    ;// thats it, clean up and split

        pop eax ;// clean out the stack

        ret

align_3A ENDP

;//
;// ALIGN_MODE_3A  Mirror objects top to bottom.                (NumPad 3)
;//
;/////////////////////////////////////////////////////////////////////////


;/////////////////////////////////////////////////////////////////////////
;//
;// ALIGN_MODE_9A  Mirror objects left to right.                (NumPad 9)
;//

ASSUME_AND_ALIGN
align_9A PROC

    ASSUME ebp:PTR LIST_CONTEXT     ;// preserve ebp
    ;// may destroy esi ebx
    ASSUME edi:PTR DWORD    ;// edi is unredo_pRecorder



    ;// determine common center
    ;// determine how to move the osc
    ;// negate all the deltas

    ;// 1) determine the common center

        mov eax, align_extent_ptr.right
        mov edx, align_extent_ptr.left

        mov eax, (ALIGN_LIST PTR [eax]).rect.right
        add eax, (ALIGN_LIST PTR [edx]).rect.left

    ;// do the flip     dy = 2C - T - B
    ;//                 p = -p
    ;//                 dp = 2*p

        push eax    ;// save on stack

        mov mouse_delta.y, 0

        mov ebx, align_list
        ASSUME ebx:PTR ALIGN_LIST

        .REPEAT

            GET_OSC_FROM esi, [ebx].pointer

        flip_this_osc:  ;// jumped to by locked group test down below

        ;// store the osc in unredo

            mov eax, [esi].id
            .IF !eax
                invoke unredo_assign_id
            .ENDIF
            stosd

        ;// determine how to move

            mov eax, [esp]              ;// 2C
            sub eax, [esi].rect.left    ;// 2C-L
            sub eax, [esi].rect.right   ;// 2C-L-R

        ;// move the osc
        push ebx    ;// we're about to destroy ebx

            stosd           ;// X
            mov mouse_delta.x, eax

            xor eax, eax
            stosd           ;// Y

            OSC_TO_BASE esi, ebx
            invoke [ebx].gui.Move

        ;// take care of pins

            ITERATE_PINS


                or [esi].dwHintOsc, HINTOSC_INVAL_DO_PINS
                or [ebx].dwHintI, HINTI_PIN_PHETA_CHANGED

                mov eax, ebx    ;// turn ptr to pin offset
                sub eax, esi
                stosd           ;// store in unredo table

                fld [ebx].pheta ;// get current pheta
                xor eax, eax
                fld math_1      ;// 1   p
                or eax, [ebx].pheta
                .IF SIGN?
                    fchs
                .ENDIF
                fsub st, st(1)  ;// 1-p p

                fst [ebx].pheta
                fsubr
                fstp [edi]      ;// store in unredo record
                add edi, 4      ;// iterate edi

            PINS_ITERATE

            ;// terminate the osc/pin record

            xor eax, eax
            stosd

        pop ebx                 ;// retrieve ebx
        ASSUME ebx:PTR ALIGN_LIST

        ;// determine if we care about locked groups

            cmp align_lock_mode, 0  ;// do we care ?
            jz next_aligner

            clist_GetNext oscL, esi ;// are we locked ?
            test esi, esi
            jz next_aligner

            cmp esi, [ebx].pointer  ;// are we done with this set ?
            jne flip_this_osc       ;// if not, continue with next osc

        ;// iterate

        next_aligner:

            add ebx, SIZEOF ALIGN_LIST

        .UNTIL ![ebx].pointer

    ;// thats it, clean up and split

        pop eax ;// clean out the stack

        ret

align_9A ENDP

;//
;// ALIGN_MODE_9A  Mirror objects left to right.                (NumPad 9)
;//
;/////////////////////////////////////////////////////////////////////////






;///////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////
;///
;///
;///    ALIGN PANEL         align_Show and message handlers
;///


ASSUME_AND_ALIGN
align_Show  PROC    USES ebx esi

    ;// confugure the buttons

        stack_Peek gui_context, ecx
        clist_GetMRS oscS, ecx, [ecx]

        DEBUG_IF <!!ecx>    ;// nothing selected !!

        xor ebx, ebx
        .IF ecx != clist_Next(oscS, ecx)
            inc ebx
        .ENDIF

        mov esi, IDC_ALIGN_LOWEST
        .REPEAT
            ENABLE_CONTROL align_hWnd, esi, ebx
            inc esi
        .UNTIL esi > IDC_ALIGN_HIGHEST

    ;// take care of the keyboard swap

        .IF ebx
            invoke align_enable_keyboard_swap
        .ENDIF

    ;// reset the status text

        WINDOW align_status, WM_SETTEXT
        mov align_last_status, 0

    ;// lauch at the mouse

        pushd SWP_SHOWWINDOW OR SWP_DRAWFRAME
        pushd align_size.y
        pushd align_size.x

        sub esp, SIZEOF POINT

        invoke GetCursorPos, esp

        ;// make sure is on screen

        pushd HWND_TOP
        push align_hWnd
        call SetWindowPos

    ;// lastly, we do the xmouse test

        .IF app_xmouse

            mov ebx, 8
            sub esp, ebx
            invoke GetCursorPos, esp
            add [esp], ebx
            add [esp+4], ebx
            call SetCursorPos

        .ENDIF

    ;// that should do it

        ret

align_Show  ENDP


ASSUME_AND_ALIGN
align_Proc PROC ;// STDCALL hWnd,msg,wParam,lParam

        mov eax, WP_MSG
        HANDLE_WM   WM_COMMAND,     align_wm_command_proc
        HANDLE_WM   WM_SETCURSOR,   align_wm_setcursor_proc
        HANDLE_WM   WM_DRAWITEM,    align_wm_drawitem_proc
        HANDLE_WM   WM_ACTIVATE,    align_wm_activate_proc
        HANDLE_WM   WM_KEYDOWN,     align_wm_keydown_proc
        HANDLE_WM   WM_CLOSE,       align_wm_close_proc
        HANDLE_WM   WM_CREATE,      align_wm_create_proc

        jmp DefWindowProcA

align_Proc ENDP

ASSUME_AND_ALIGN
align_handle_command    PROC

    ;// eax must have the command

        DEBUG_IF < eax !< IDC_ALIGN_LOWEST || eax !> IDC_ALIGN_HIGHEST >

    ;// got a bad command somehow

        push ebp

        stack_Peek gui_context, ebp

        clist_GetMRS oscS, ecx, [ebp]
        .IF ecx

            push edi                        ;// preserve registers
            push esi
            push ebx

            push eax                        ;// start the unredo recorder
            unredo_BeginAction UNREDO_ALIGN
            pop eax

            sub eax, IDC_ALIGN_LOWEST       ;// get to a command index
            mov edi, unredo_pRecorder       ;// edi is unredo recorder for all functions
            call align_jump_table[eax*4]    ;// do it

            .IF edi != unredo_pRecorder     ;// terminate the unredo records
                xor eax, eax
                stosd
                mov unredo_pRecorder, edi
            .ENDIF

            unredo_EndAction UNREDO_ALIGN   ;// finalize the unredo action

            pop ebx                         ;// restore registers
            pop esi
            pop edi

            invoke app_Sync                 ;// redraw

        .ENDIF

        pop ebp

        ret

align_handle_command    ENDP



ASSUME_AND_ALIGN
align_wm_command_proc   PROC    ;// STDCALL hWnd,msg,wParam,lParam

    mov eax, WP_WPARAM
    shr eax, 16
    .IF eax == BN_CLICKED

        mov eax, WP_WPARAM
        and eax, 0FFFFh

    ;// make sure we got a command (ignore clicks on status windows

        .IF eax >= IDC_ALIGN_LOWEST && eax <= IDC_ALIGN_HIGHEST

            invoke align_handle_command

            ;// check if we need to close the window

            mov eax, WP_WPARAM
            and eax, 0FFFFh
            .IF eax != IDC_ALIGN_MODE_5A && eax != IDC_ALIGN_MODE_5B

                invoke SetFocus, hMainWnd

            .ENDIF

        .ENDIF

    .ENDIF

    xor eax, eax
    ret 10h

align_wm_command_proc   ENDP



ASSUME_AND_ALIGN
align_wm_keydown_proc   PROC    ;// STDCALL hWnd,msg,wParam,lParam

        mov eax, WP_WPARAM
        cmp eax, VK_ESCAPE
        je close_the_window

        cmp eax, VK_NUMPAD9
        ja all_done
        cmp eax, VK_NUMPAD1
        jb all_done

    ;// adjust the command to be in the proper range
    ;// then do the command

        add eax, IDC_ALIGN_LOWEST - VK_NUMPAD1
        add eax, align_keyboard_swap
        invoke align_handle_command

    ;// check for VK_NUMPAD5 and don't close if so

        mov eax, WP_WPARAM
        cmp eax, VK_NUMPAD5
        je all_done

    close_the_window:

        invoke SetFocus, hMainWnd

    all_done:

        xor eax, eax
        ret 10h

align_wm_keydown_proc   ENDP


ASSUME_AND_ALIGN
align_wm_setcursor_proc PROC    ;// STDCALL hWnd,msg,wParam,lParam

    ;// this is were we set the staus text for the align panel

    ;// check if we are hitting a new control

        mov ecx, WP_WPARAM  ;// wnd handle with cursor
        invoke GetWindowLongA, ecx, GWL_USERDATA
        cmp eax, align_last_status
        je return_zero

    ;// make we have a valid pointer

        or eax, eax
        jz all_done

    ;// make sure we are not getting the hwnd (NT problem)

        push eax
        invoke IsWindow, eax
        test eax, eax
        pop eax
        jnz return_zero

    ;// ok, we can set the text

        mov align_last_status, eax
        WINDOW align_status, WM_SETTEXT, 0, eax

    return_zero:

        xor eax, eax

    all_done:

        ret 10h

align_wm_setcursor_proc ENDP



ASSUME_AND_ALIGN
align_wm_drawitem_proc PROC ;// STDCALL hWnd, msg, ctlID, pDrawItem
                            ;// 00      04    08   0C     10

;// we want special formatting for hotkeys
        mov eax, align_last_status
        mov [esp+8], eax
        jmp display_popup_help_text

align_wm_drawitem_proc ENDP



ASSUME_AND_ALIGN
align_wm_activate_proc  PROC    ;// STDCALL hWnd,msg,wParam,lParam

    mov eax, WP_WPARAM
    and eax, 0FFFFh
    .IF ZERO?

        ;// being deactivated
        invoke ShowWindow, align_hWnd, SW_HIDE
        mov eax, align_list
        and app_DlgFlags, NOT DLG_CREATE

        .IF eax
            invoke memory_Free, eax
            mov align_list, eax
        .ENDIF

    .ELSE

        ;// being activated
        or app_DlgFlags, DLG_CREATE
        invoke align_build_list
        ;// make sure we show the new selection
        .IF align_lock_mode && align_list
            invoke InvalidateRect, hMainWnd, 0, 0
        .ENDIF


    .ENDIF

    xor eax, eax
    ret 10h

align_wm_activate_proc  ENDP


ASSUME_AND_ALIGN
align_wm_close_proc     PROC    ;// STDCALL hWnd,msg,wParam,lParam

    invoke SetFocus, hMainWnd
    xor eax, eax
    ret 10h

align_wm_close_proc     ENDP

ASSUME_AND_ALIGN
align_wm_create_proc    PROC    ;// STDCALL hWnd,msg,wParam,lParam


    ;// store hwnd

        mov eax, WP_HWND
        mov align_hWnd, eax

    ;// build the sys menu ?

    ;// build the controls

        lea edx, popup_ALIGN
        invoke popup_BuildControls, eax, edx, OFFSET sz_align_help, 0

    ;// get the status window handle

        mov eax, popup_status_hWnd
        mov align_status, eax

    ;// set the window size

        point_Get popup_ALIGN.siz
        add edx, POPUP_HELP_HEIGHT

        pushd edx
        pushd eax
        pushd 0
        pushd 0
        mov ecx, esp

        invoke AdjustWindowRectEx, ecx, ALIGN_STYLE, 0, ALIGN_STYLE_EX

        pop eax
        pop edx
        sub eax, [esp]
        sub edx, [esp+4]
        add esp, 8

        point_Neg

        point_Set   align_size

    ;// continue on

        jmp DefWindowProcA

align_wm_create_proc    ENDP


;//
;//     ALIGN PANEL
;//
;///////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////




ASSUME_AND_ALIGN


END



