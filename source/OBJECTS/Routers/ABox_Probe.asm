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
;// ABox_Probe.asm          the probe object
;//
;//
;// TOC:
;// probe_GetUnit
;// probe_Ctor
;// probe_FindTarget
;// probe_Move
;// probe_Render
;// probe_PrePlay
;// probe_Calc
;// probe_InitMenu
;// probe_Command
;// probe_SaveUndo
;// probe_LoadUndo




OPTION CASEMAP:NONE

.586
.MODEL FLAT

USE_THIS_FILE equ 1

IFDEF USE_THIS_FILE


        .NOLIST
        include <Abox.inc>
        include <gdi_pin.inc>
        .LIST

comment ~ /*

    notes:

        this object maintains a pointer to the closest pin (dwUser2)
        and from that, simply sets the output data pointer to that objects, data
        if the pin is an input, then it is traced back to it's source
        if the pin is not connected, the target is removed
        if the read pointer is invalid, the pointer is removed

        probe_FindTarget will locate the closest pin that is in range
        only the probe_Paint and probePreplay will call this function

        --> we're relying on IsBadReadPointer to work for us <--
        otherwise we get a big mess of logic to deal with when deleting pins

        osc dwUser2 stores the target pointer
        osc.pData points at our local data
        local data is simply the relative position between osc and the target pin's T0


*/ comment ~



.DATA

;// LOCAL DATA

OSC_PROBE STRUCT

    relPos POINT {} ;// relative position to our target
    pTarget dd  0   ;// ptr to the target

OSC_PROBE ENDS

;// OBJECT DEFINITION

osc_Probe OSC_CORE {probe_Ctor,,probe_PrePlay,probe_Calc}
          OSC_GUI  {probe_Render,,,,probe_Move,probe_Command,probe_InitMenu,,,osc_SaveUndo,probe_LoadUndo,probe_GetUnit }
          OSC_HARD {}

    OSC_DATA_LAYOUT {NEXT_Probe,IDB_PROBE,OFFSET popup_PROBE,,
        1,4,
        SIZEOF OSC_OBJECT + ( SIZEOF APIN ) ,
        SIZEOF OSC_OBJECT + ( SIZEOF APIN ) + SAMARY_SIZE ,
        SIZEOF OSC_OBJECT + ( SIZEOF APIN ) + SAMARY_SIZE + SIZEOF OSC_PROBE  }

    OSC_DISPLAY_LAYOUT { circle_container, PROBE_PSOURCE, ICON_LAYOUT( 14,2,2,7 ) }

    APIN_init { 0.0,,'=',, PIN_OUTPUT OR UNIT_AUTO_UNIT }    ;// output pin

    short_name  db  'Probe',0
    description db  'The probe monitors signals without actually connecting to them.',0
    ALIGN 4

    ;// dwuser values

    PROBE_STATUS            EQU 00000001h   ;// show the status, not the value
    PROBE_SETTING_CHANGED   EQU 80000000h   ;// so we know when to clear our output data

    ;// fields metrics

    PROBE_RADIUS        EQU 64  ;// probe has a sensing radius

    PROBE_RADIUS_X      EQU PROBE_RADIUS
    PROBE_RADIUS_Y      EQU PROBE_RADIUS

    PROBE_DIAMETER_X    EQU PROBE_RADIUS_X * 2
    PROBE_DIAMETER_Y    EQU PROBE_RADIUS_Y * 2

    PROBE_RADIUS_SQUARED    EQU PROBE_RADIUS * PROBE_RADIUS

;// OSC_MAP for this object


    OSC_MAP STRUCT

                    OSC_OBJECT  {}
        pin_X       APIN        {}
        x_data      dd  SAMARY_LENGTH dup (0)
        probe       OSC_PROBE   {}

    OSC_MAP ENDS



.CODE


;//////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
probe_GetUnit PROC

        ASSUME esi:PTR OSC_MAP  ;// must preserve
        ASSUME ebx:PTR APIN         ;// must preserve
        ;// must preserve edi and ebp

        xor eax, eax

        or eax, [esi].probe.pTarget ;// see if we have a target
        jz all_done                 ;// jump if not

        invoke IsBadReadPtr, eax, SIZEOF APIN   ;// see if the target is valid
        test eax, eax           ;// clears carry flag
        mov eax, 0
        jnz all_done            ;// jmp if not valid read pointer

        mov eax, [esi].probe.pTarget
        mov eax, (APIN PTR [eax]).dwStatus

    ;// see if the target knows what it is

        .IF eax & UNIT_AUTO_UNIT    ;// resets carry flag
            BITT eax, UNIT_AUTOED
        .ELSE
            stc ;// fixed unit, must be valid
        .ENDIF

    all_done:

        ret

probe_GetUnit ENDP



;/////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
probe_Ctor PROC

        ;// register call
        ASSUME ebp:PTR LIST_CONTEXT ;// preserve
        ASSUME esi:PTR OSC_MAP      ;// preserve
        ASSUME edi:PTR OSC_BASE     ;// may destroy
        ASSUME ebx:PTR FILE_OSC     ;// may destroy
        ASSUME edx:PTR FILE_HEADER  ;// may destroy

    ;// clear our dwUser so we find the target

        mov [esi].probe.pTarget, 0
        or [esi].dwUser, PROBE_SETTING_CHANGED

        ret

probe_Ctor ENDP


;/////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
probe_FindTarget PROC

    ASSUME esi:PTR OSC_MAP
    ASSUME ebp:PTR LIST_CONTEXT

    ;// all we do is put a value in osc.dwUser2

    ;// simply enough, we walk the C list (current or not)
    ;// and find the closest pin that's in range
    ;// we then store the reletive positions of our object

        push [esi].probe.pTarget    ;// need to store this

        push ebp    ;// save the passed context

        st_border   TEXTEQU <(RECT PTR [esp])>
        st_center   TEXTEQU <(POINT PTR [esp+(SIZEOF RECT)])>

        stack_size = (SIZEOF RECT)+(SIZEOF POINT)

        sub esp, stack_size

    ;// build our center point

        point_GetTL [esi].rect
        point_AddBR [esi].rect
        shr eax, 1
        shr edx, 1
        point_Set st_center

    ;// build our border rect

        point_Sub PROBE_RADIUS
        point_SetTL st_border
        point_Add PROBE_DIAMETER
        point_SetBR st_border

    ;// set up for scan

        mov [esi].probe.pTarget, 0              ;// just in case
        mov ecx, PROBE_RADIUS_SQUARED+1 ;// ecx will track min dist

    ;// walk cList, using whatever context was passed to us

    slist_GetHead oscC, edi, [ebp]
    .WHILE edi

        cmp edi, esi        ;// never test ourselves
        je next_osc

    ;// compare our border with the target rect

                                    ;// eax,edx = right,bottom

        cmp eax, [edi].rect.left    ;// border.right > target.left
        jl next_osc
        cmp edx, [edi].rect.top     ;// border.bottom > target.top
        jl next_osc

        point_GetTL st_border       ;// eax,edx = top,left

        cmp eax, [edi].rect.right   ;// border.left < target.right
        jg reload_border_br
        cmp edx, [edi].rect.bottom  ;// border.top < target.botom
        jg reload_border_br

    ;// if inside
    ;// walk targets pins

        OSC_TO_LAST_PIN edi, ebp
        .WHILE ebp > edi

            test [ebp].pPin, -1 ;// make sure it's connected
            jz next_pin

        ;// compare target t0 with our probe rect

                                    ;// eax,edx = top,left

            cmp eax, [ebp].t0.x     ;// border.left < t0.x
            jg next_pin
            cmp edx, [ebp].t0.y     ;// border.top < t0.y
            jg next_pin

            point_GetBR st_border   ;// eax,edx = right,bottom

            cmp eax, [ebp].t0.x     ;// border.right > t0.x
            jl reload_border_tl
            cmp edx, [ebp].t0.y     ;// border.bottom > t0.y
            jl reload_border_tl

        ;// if inside
        ;// compare squared reletive distance

            mov eax, st_center.x
            sub eax, [ebp].t0.x
            imul eax

            mov ebx, eax    ;// store temp sum

            mov eax, [ebp].t0.y
            sub eax, st_center.y
            imul eax

            add eax, ebx        ;// add with temp sum
            DEBUG_IF <SIGN?>    ;// not supposed to happen

        ;// if less, store appropriate data

            cmp eax, ecx

            ja reload_border_tl ;// jump if dist > min_dist

            mov ecx, eax            ;// store new min dist
            mov [esi].probe.pTarget, ebp    ;// store the pin it came from

        reload_border_tl:

            point_GetTL st_border

        next_pin:

            sub ebp, SIZEOF APIN

        .ENDW

    reload_border_br:

        point_GetBR st_border

    next_osc:

        slist_GetNext oscC, edi

    .ENDW

    ;///////////////////////////////////////////////////

    add esp, stack_size
    pop ebp
    ASSUME ebp:PTR LIST_CONTEXT

    pop ecx ;// retrieve the previous target

    ;///////////////////////////////////////////////////

    ;// now we've walked the list and located the closest pin

    ;// it may still be empty
    GET_PIN [esi].probe.pTarget, ebx
    .IF ebx

    ;// compute the delta distance

        point_GetTL [esi].rect
        point_Sub [ebx].t0
        point_Set [esi].probe.relPos

    ;// invalidate both objects and schedule for auto trace

        GDI_INVALIDATE_PIN HINTI_PIN_UPDATE_PROBE
        GDI_INVALIDATE_OSC HINTI_OSC_UPDATE

    .ENDIF

    .IF ecx != ebx

    ;// or [ebp].gFlags, GFLAG_AUTO_UNITS
    ;// or app_bFlags, APP_SYNC_UNITS
    invoke context_SetAutoTrace         ;// schedule a unit trace

    .ENDIF


    ret

probe_FindTarget ENDP

;/////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
probe_Move  PROC

    ;// all we want to do is invalidate our target
    ;// then exit to osc_Move

    ASSUME esi:PTR OSC_MAP
    ASSUME ebp:PTR LIST_CONTEXT

    mov eax, [esi].probe.pTarget
    or eax, eax
    jz osc_Move

    ASSUME eax:PTR APIN

    push esi
    PIN_TO_OSC eax, esi
    GDI_INVALIDATE_OSC HINTI_OSC_UPDATE
    pop esi

    jmp osc_Move


probe_Move  ENDP

;/////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
probe_Render    PROC

    ASSUME esi:PTR OSC_MAP

    ;// draw the line first

    ;// check for a target

        GET_PIN [esi].probe.pTarget, ebx
        or ebx, ebx
        jnz check_the_pointer

    dont_have_target:

        invoke probe_FindTarget
        jmp recheck_for_target

    check_the_pointer:

        invoke IsBadReadPtr, ebx, SIZEOF(APIN)
        or eax, eax
        jz verify_target

    ;//bad target

    bad_target:

        ENTER_PLAY_SYNC GUI

        mov eax, math_pNull             ;// load nul data pointer
        mov [esi].probe.pTarget, 0      ;// reset dwUser
        mov [esi].pin_X.pData, eax      ;// set data as pin null

        LEAVE_PLAY_SYNC GUI

        jmp gdi_render_osc

    ;// recheck for a target

    recheck_for_target:

        or ebx, ebx
        jz gdi_render_osc

    ;// verify it hasn't moved

    verify_target:

        point_GetTL [esi].rect
        point_Sub [ebx].t0

        sub eax, [esi].probe.relPos.x
        jne find_new_target
        sub edx, [esi].probe.relPos.y
        jne find_new_target

    ;// target has not moved, or was just created

    draw_the_line:

        point_GetTL [esi].rect
        point_AddBR [esi].rect
        shr eax, 1
        shr edx, 1

        push [ebx].t0.y ;// y1
        push [ebx].t0.x ;// x1
        push edx        ;// y0
        push eax        ;// x0

        mov ebx, gdi_pDib

        xor eax, eax
        mov al, COLOR_DESK_TEXT

        invoke dib_DrawLine
        add esp, SIZEOF RECT

        jmp gdi_render_osc

    ;// target has moved, have to find new one

    find_new_target:

        invoke probe_FindTarget

        or ebx, ebx
        jnz draw_the_line

    ;// that' it, exit to

        jmp gdi_render_osc

probe_Render ENDP

;/////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
probe_PrePlay PROC  ;// STDCALL pObject:PTR OSC_OBJECT

    ASSUME esi:PTR OSC_MAP

    .IF !([esi].probe.pTarget)
        invoke  probe_FindTarget
    .ENDIF

    mov eax, 1  ;// we don't want play_PrePlay to erase our target

    ret

probe_PrePlay ENDP

;/////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
probe_Calc PROC ;// uses edi esi

    ASSUME esi:PTR OSC_MAP

    ;// check for a status schange in dwUser

        mov edx, [esi].dwUser

        btr edx, LOG2(PROBE_SETTING_CHANGED)
        .IF CARRY?

            mov [esi].dwUser, edx       ;// store that we took care of this
            bt edx, LOG2(PROBE_STATUS)
            .IF CARRY?

                lea edi, [esi].x_data
                mov [esi].pin_X.pData, edi  ;// set the data pointer correctly
                and [esi].pin_X.dwStatus, NOT PIN_CHANGING  ;// we'll never be changing in this mode
                mov ecx, SAMARY_LENGTH
                xor eax, eax
                rep stosd

            .ENDIF

        .ENDIF

    ;// check for zero target

        GET_PIN [esi].probe.pTarget, ebx
        or ebx, ebx
        jz no_target

    ;// we have something in the target

        invoke IsBadReadPtr, ebx, SIZEOF( APIN )
        or eax, eax
        jnz no_target

    ;// target is correct in memory

        test [ebx].pPin, -1         ;// check if target is connected
        jz no_target

    ;// target pin is connected

        mov edi, [ebx].dwStatus     ;// get the pin status
        test edi, PIN_OUTPUT        ;// make sure it's an output pin
        jnz set_the_data_pointer

    ;// target pin is an input pin

        mov ebx, [ebx].pPin         ;// get the source pin
        mov edi, [ebx].dwStatus     ;// get the pin status

    set_the_data_pointer:

        ;// check the mode

        .IF [esi].dwUser & PROBE_STATUS

            ;// we want to output the status

            test [ebx].dwStatus, PIN_CHANGING
            mov eax, 0
            jz @F
            mov eax, math_neg_1
        @@:
            cmp eax, [esi].x_data[0]
            je all_done
            mov ecx, SAMARY_LENGTH
            lea edi, [esi].x_data[0]
            rep stosd
            jmp all_done

        .ELSE

            mov ebx, [ebx].pData        ;// get the data pointer

            ;// verify again
            invoke IsBadReadPtr, ebx, SAMARY_SIZE
            or eax, eax
            jnz no_target

            and edi, PIN_CHANGING       ;// test for changing status
            mov [esi].pin_X.pData, ebx  ;// store the data pointer
            jz set_not_changing         ;// jump if not changing

        ;// source is changing

            or [esi].pin_X.dwStatus, edi
            jmp all_done

        set_not_changing:

            and [esi].pin_X.dwStatus, NOT PIN_CHANGING
            jmp all_done

        .ENDIF

    ;// there is no target

    no_target:

        mov [esi].probe.pTarget, 0      ;// clear our dwUser

        .IF [esi].dwUser & PROBE_STATUS

            ;// set as not changing

            xor eax, eax
            cmp eax, [esi].x_data[0]
            je all_done
            mov ecx, SAMARY_LENGTH
            lea edi, [esi].x_data[0]
            rep stosd
            jmp all_done

        .ELSE

            mov ecx, math_pNull         ;// get the nul data poiner
            mov [esi].pin_X.pData, ecx  ;// set the new data pointer

        .ENDIF

    all_done:

        ret

probe_Calc ENDP

;/////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
probe_InitMenu PROC

    ASSUME esi:PTR OSC_MAP

        test [esi].dwUser, PROBE_STATUS
        mov ecx, IDC_PROBE_VALUE
        jz @F
        mov ecx, IDC_PROBE_STATUS
    @@:
        invoke CheckDlgButton, popup_hWnd, ecx, BST_CHECKED
        xor eax, eax
        ret

probe_InitMenu ENDP

ASSUME_AND_ALIGN
probe_Command PROC

    ASSUME esi:PTR OSC_MAP
    ;// eax has the id

    cmp eax, IDC_PROBE_VALUE
    jne @F

        and [esi].dwUser, NOT PROBE_STATUS
        or [esi].dwUser, PROBE_SETTING_CHANGED
        jmp all_done

@@: cmp eax, IDC_PROBE_STATUS
    jne osc_Command

        or [esi].dwUser, PROBE_STATUS OR PROBE_SETTING_CHANGED

all_done:

        mov eax, POPUP_SET_DIRTY
        ret

probe_Command ENDP

;/////////////////////////////////////////////////////////////////////




;////////////////////////////////////////////////////////////////////
;//
;//
;//     _LoadUndo
;//

ASSUME_AND_ALIGN
probe_LoadUndo PROC

        ASSUME esi:PTR OSC_OBJECT   ;// preserve
        ASSUME ebp:PTR LIST_CONTEXT ;// preserve

    ;// edx enters as either UNREDO_CONTROL_OSC or UNREDO_COMMAND
    ;// edi enters as where to load
    ;//
    ;// task:   1) load nessary data
    ;//         2) do what it takes to initialize it
    ;//
    ;// may use all registers except ebp and esi
    ;// return will invalidate HINTI_OSC_UPDATE


        mov eax, [edi]
        or eax, PROBE_SETTING_CHANGED
        mov [esi].dwUser, eax

        ret

probe_LoadUndo ENDP

;//
;//
;//     _LoadUndo
;//
;////////////////////////////////////////////////////////////////////




















ASSUME_AND_ALIGN

ENDIF   ;// USE_THIS_FILE

END
