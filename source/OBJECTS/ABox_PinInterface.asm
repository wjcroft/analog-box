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
;//                 -- revamped pinint_Calc for far faster bad data test
;//                    and to check for changing AFTER bad data test
;//
;//##////////////////////////////////////////////////////////////////////////
;//                             pin interface for group's
;// ABox_PinInterface.asm       conceptually this is a splitter1 that does nothing but act as a placeholder
;//                             there are several interfaces with closed groups however
;//                             most are implemented in osc_Command
;// TOC
;// pinint_Ctor
;// pinint_Calc
;// pinint_Render
;// pinint_InitMenu
;// pinint_Command
;// pinint_GetUnit
;// pinint_SaveUndo
;// pinint_LoadUndo


comment ~ /*

    inside closed groups, pin interfaces are assigned connections to the
    group container via the container itself.

    if pinint is an input interface pin, it's pin_i.pPin will actually point at the
    groups equivalent pin. the pin intreface must not change this, and should be set
    as PIN_HIDDEN to prevent user interaction.

    inside groups, pin interfaces that are connected to groups, must not be deleted

    pin_int.dwUser can point at the closed group (set by

*/ comment ~

OPTION CASEMAP:NONE

.586
.MODEL FLAT

USE_THIS_FILE equ 1

IFDEF USE_THIS_FILE

    .NOLIST
    INCLUDE <Abox.inc>
    INCLUDE <groups.inc>
    .LIST

.DATA


osc_PinInterface OSC_CORE { pinint_Ctor,,,pinint_Calc}
                 OSC_GUI  { pinint_Render,,,,,
                    pinint_Command,pinint_InitMenu,,,
                    pinint_SaveUndo,pinint_LoadUndo,pinint_GetUnit}
                 OSC_HARD { }

    OSC_DATA_LAYOUT {NEXT_PinInterface,IDB_PININT,OFFSET popup_PININT,
        ,2,4+SIZEOF PININT_DATA,
        SIZEOF OSC_OBJECT + ( SIZEOF APIN ) * 2,
        SIZEOF OSC_OBJECT + ( SIZEOF APIN ) * 2,
        SIZEOF OSC_OBJECT + ( SIZEOF APIN ) * 2 + SIZEOF PININT_DATA }

    OSC_DISPLAY_LAYOUT {pinint_container, pinint_PSOURCE,ICON_LAYOUT(14,4,2,7 ) }

    APIN_init {-1.0 ,,'I',, UNIT_AUTO_UNIT }                            ;// input
    APIN_init { 0.0 ,,'O',, PIN_OUTPUT OR PIN_NULL OR UNIT_AUTO_UNIT }  ;// output

    short_name  db  'Pin Interface',0
    description db  'Marker to indicate the border of a group. Can also test for changing data and remove bad data values.',0
    ALIGN 4


    ;// flags for dwUser are defined in groups.inc

    ;// maximum name lengths

        PININT_MAX_S_NAME equ 2
        PININT_MAX_L_NAME equ 31



.CODE

ASSUME_AND_ALIGN
pinint_Ctor PROC

        ;// register call
        ;// ASSUME ebp:PTR LIST_CONTEXT ;// preserve
        ;// ASSUME esi:PTR OSC_OBJECT   ;// preserve
        ;// ASSUME edi:PTR OSC_BASE     ;// may destroy
        ;// ASSUME ebx:PTR FILE_OSC     ;// may destroy
        ;// ASSUME edx:PTR FILE_HEADER  ;// may destroy

        ASSUME esi:PTR PININT_OSC_MAP

    ;// we're being called from the constructor
    ;// all file data has already been loaded, if any
    ;// we want to make sure we have a lable

        .IF ![esi].pinint.s_name
            mov [esi].pinint.s_name, 'X'
        .ENDIF

    ;// that's it

        ret

pinint_Ctor ENDP

;// see notes in groups.inc for how this works in the big picture



ASSUME_AND_ALIGN
pinint_Calc PROC

    ASSUME esi:PTR PININT_OSC_MAP

    ASSUME ebx:PTR APIN
    ASSUME edx:PTR APIN
    ASSUME edi:PTR DWORD

;//     type            source pin          dest pin
;//                     where to get data   where to set data   edi
;//     -------------   -----------------   -----------------
;//     CLOSED  INPUT   pin_I.dwUser.pPin   pin_O
;//     CLOSED OUTPUT   pin_I.pPin          pin_O.dwUser
;//     OPENED          pin_I.pPin          pin_O
;//     -------------   -----------------   -----------------
;//                     ebx                 edx


        .IF [esi].pin_I.dwStatus & PIN_HIDDEN

        ;// CLOSED INPUT

            mov ebx, [esi].pin_I.dwUser ;// get the group assigned pin
            lea edx, [esi].pin_O        ;// point at our output pin
            mov ebx, [ebx].pPin         ;// point at group's source pin

        .ELSEIF [esi].pin_O.dwStatus & PIN_HIDDEN

        ;// CLOSED OUTPUT

            mov edx, [esi].pin_O.dwUser ;// get group assigned output pin
            mov ebx, [esi].pin_I.pPin   ;// get our input's data source

        .ELSE

        ;// OPENED

            lea edx, [esi].pin_O        ;// get our output pin
            mov ebx, [esi].pin_I.pPin   ;// get our input's data source

        .ENDIF

        ;// edx points at our output APIN
        ;// ebx points at the APIN that feeds our input pin

        ;// assume for a moment that our data is not changing
        and [edx].dwStatus, NOT PIN_CHANGING    ;// our output is not changing

        ;// make sure input pin exists
        .IF !ebx    ;// input does not exist

            mov edi, math_pNull     ;// load the zero array
            mov [edx].pData, edi    ;// set the data pointer

        .ELSE ;// input does exist

            ;// we have a valid source pin, set our output data pointer

            mov edi, [ebx].pData    ;// get the data from supplied source
            mov [edx].pData, edi    ;// store the data pointer to supplied destination

            ;// check for bad data before checking for changing
            ;// ABOX242: oops! we are inadvertantly writing to another object's data ....
            ;//        is that a bad thing ?? dare we fix it after 10 years ??
            ;//        or do we go even further and set its changing bit too ???
            ;//        'order of calculation' issues are a concern ...

            .IF [esi].dwUser & PININT_TEST_DATA

                ;// we'll check the entire frame regardless of changing or not
                ;// ... somewhat inconsistant ...
                push edx    ;// have to save
                    xor ecx, ecx            ;// use for counting
                    mov edx, 0FF000000h    ;// high byte
                    xor eax, eax
                    .REPEAT
                        DEBUG_IF <eax>    ;// we thought eax was zero !!!
                        or eax, [edi+ecx*4]    ;// load and test for pos zero
                        jz loop_next        ;// skip if pos zero
                        shl eax,1            ;// not pos zero, shift out sign, and put exp in top 8 bits
                        jz is_zero            ;// found a neg zero, replace with pos zero
                        and eax, edx;//0FF000000h  ;// mask out all but exp
                        jz is_denormal        ;// exp is all 0's, but lower 3 bytes are not zero
                        cmp eax, edx;//0FF000000h    ;// now check for all 1 in exp
                        jne loop_next        ;// not all one's so don't bother storing
                    is_zero:
                    is_denormal:    ;// flush to zero is acceptable
                    is_infinity:    ;// what to do with infinity ??, could also be NAN ... i guess just flush to zero ..
                        DEBUG_IF <eax>    ;// we thought eax was zero !!!
                        mov [edi+ecx*4], eax    ;// store pos zero -- TO SOME OTHER OBJECT'S DATA ...
                    ;// value is ok -- assume most common case
                    loop_next:
                        add ecx, 1
                        xor eax, eax    ;// must be zero!!
                    .UNTIL ecx >= SAMARY_LENGTH

                pop edx
            .ENDIF

            ;// now copy input pin's changing to ourselves
            mov eax, [ebx].dwStatus
            and eax, PIN_CHANGING    ;// mask out all but PIN_CHANGING
            .IF !ZERO?    ;// input claims it is not changing
                ;// are we supposed to verify that?
                .IF !( [esi].dwUser & PININT_TEST_CHANGE )    ;// no we are not supposed to check
                    or [edx].dwStatus, eax    ;// our data is/was changing
                .ELSE                    ;// yes we are supposed to verify input data
                    mov eax, [edi]          ;// get the first data item
                    mov ecx, SAMARY_LENGTH  ;// count this many
                    repe scasd              ;// scan until first non_match
                    .IF !ZERO?    ;// did we detect a different value ??
                        or [edx].dwStatus, PIN_CHANGING ;// or data is/was changing
                    ;//.ELSE
                        ;// input data is really not changing
                        ;// dare we tell write to it's dwStatus ...
                        ;// doesn't seem proper ...
                        ;// ... 'order of calculation' issues come to mind
                        ;//and [ebx].dwStatus, NOT PIN_CHANGING    ;// our output is not changing
                    .ENDIF
                .ENDIF
            .ENDIF
        .ENDIF

    all_done:   ;// that's it

        ret

pinint_Calc ENDP













ASSUME_AND_ALIGN
pinint_Render PROC

    ;// all we need to do is print our s_name

    call gdi_render_osc

    ASSUME esi:PTR PININT_OSC_MAP

    GDI_DC_SELECT_FONT hFont_huge
    GDI_DC_SET_COLOR COLOR_OSC_TEXT

    invoke DrawTextA, gdi_hDC, ADDR [esi].pinint.s_name, -1, ADDR [esi].rect, DT_SINGLELINE OR DT_VCENTER OR DT_CENTER

    ret

pinint_Render ENDP


ASSUME_AND_ALIGN
pinint_InitMenu PROC

        ASSUME esi:PTR PININT_OSC_MAP

    ;// press the required buttons

        .IF [esi].dwUser & PININT_TEST_CHANGE
            invoke CheckDlgButton, popup_hWnd, ID_PININT_TEST_CHANGE, 1
        .ENDIF
        .IF [esi].dwUser & PININT_TEST_DATA
            invoke CheckDlgButton, popup_hWnd, ID_PININT_TEST_DATA, 1
        .ENDIF

    ;// set the window texts and limit the text length

        invoke GetDlgItem, popup_hWnd, ID_PININT_S_NAME
        mov ebx, eax
        WINDOW ebx, WM_SETTEXT,0,ADDR [esi].pinint.s_name
        EDITBOX ebx, EM_SETLIMITTEXT, PININT_MAX_S_NAME, 0

        invoke GetDlgItem, popup_hWnd, ID_PININT_L_NAME
        mov ebx, eax
        WINDOW ebx, WM_SETTEXT,0,ADDR [esi].pinint.l_name
        EDITBOX ebx, EM_SETLIMITTEXT, PININT_MAX_L_NAME, 0

    ;// that's it

        xor eax, eax    ;// return zero or popup_init will erase data that musn't be erased
        ret

pinint_InitMenu ENDP

;////////////////////////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
pinint_check_if_need_group_sync PROC

    ;// call this when the short name changes

        ASSUME esi:PTR PININT_OSC_MAP

    ;// if we are in a closed group, we have to
    ;// set the new font shape on the outside

        mov edx, PIN_HIDDEN

        test [esi].pin_I.dwStatus, edx
        jz G1

            mov ebx, [esi].pin_I.dwUser
            jmp G2

    G1: test [esi].pin_O.dwStatus, edx
        jz G3

            mov ebx, [esi].pin_O.dwUser

    G2: DEBUG_IF <!!ebx>    ;// ecx is supposed to be the group pin

        DEBUG_IF <!!(app_bFlags & APP_MODE_IN_GROUP)>

        ASSUME ebx:PTR APIN

        push ebp

        PIN_TO_OSC ebx, ebx

        stack_Peek gui_context, ebp
        stack_PeekNext gui_context, ebp

        GDI_INVALIDATE_OSC HINTI_OSC_SHAPE_CHANGED, ebx

        or [ebx].dwUser, GROUP_SCAN_PINS

        pop ebp

    G3: ret

pinint_check_if_need_group_sync ENDP

;///////////////////////////////////////////////////////////////////////////////



ASSUME_AND_ALIGN
pinint_Command PROC

    ASSUME ebp:PTR LIST_CONTEXT
    ASSUME esi:PTR PININT_OSC_MAP
    ;// eax has the command ID

;// hijak the delete command
;// and make sure we aren't closed

    cmp eax, COMMAND_DELETE
    jne @F

    J0: test app_bFlags, APP_MODE_IN_GROUP
        jz osc_Command

        test [esi].pin_I.dwStatus, PIN_HIDDEN
        jnz J1
        test [esi].pin_O.dwStatus, PIN_HIDDEN
        jz osc_Command

    J1: mov eax, POPUP_IGNORE
        ret

;// hijak the cut command
;// and make sure we aren't closed

@@: cmp eax, COMMAND_CUT
    je J0

;// data testing

@@: cmp eax, ID_PININT_TEST_CHANGE
    jne @F

        xor [esi].dwUser, PININT_TEST_CHANGE
        jmp all_done

@@: cmp eax, ID_PININT_TEST_DATA
    jne @F

        xor [esi].dwUser, PININT_TEST_DATA
        jmp all_done


;// edit change
@@: cmp eax, OSC_COMMAND_EDIT_CHANGE
    jnz osc_Command

    ;// ecx has the control ID

        cmp ecx, ID_PININT_S_NAME
        je changed_s_name

        cmp ecx, ID_PININT_L_NAME
        jne osc_Command

    changed_l_name:

        push ecx    ;// need to save this
        lea edx, [esi].pinint.l_name
        push edx
        pushd 32
        jmp get_the_text

    changed_s_name:

        push ecx    ;// need to save this
        lea edx, [esi].pinint.s_name
        push edx
        pushd 3
        mov DWORD PTR [edx], 0  ;// must clear all four bytes or searching won't work

    get_the_text:

        pushd WM_GETTEXT
        invoke GetDlgItem, popup_hWnd, ecx
        push eax
        call SendMessageA

        pop ecx     ;// retrive control id

    .IF ecx == ID_PININT_S_NAME

        ;// editing the short name

        xor eax, eax

        ;// check if name was empty
        or eax, [esi].pinint.s_name
        .IF ZERO?
            mov eax, 'X'
            mov [esi].pinint.s_name, eax
        .ENDIF

    .ENDIF

    invoke pinint_check_if_need_group_sync

all_done:

    mov eax, POPUP_REDRAW_OBJECT OR POPUP_SET_DIRTY

    ret

pinint_Command ENDP



;////////////////////////////////////////////////////////////////////////////////
comment ~ /*


    inside  I   have_a_unit     return that unit
                                return unit from outside
            O   have_a_unit     return that unit
                                return unit from outside

    outside IO  return that unit







*/ comment ~
ASSUME_AND_ALIGN
pinint_GetUnit PROC

        ASSUME ebp:PTR LIST_CONTEXT     ;// preserve
        ASSUME esi:PTR PININT_OSC_MAP   ;// must preserve
        ASSUME ebx:PTR APIN             ;// must preserve

    ;// must preserve edi and ebp

    ;// determine the pin we want to grab the unit from
    ;// if we are inside a group, we get the pin unit from up there

        .IF [ebx].dwStatus & PIN_OUTPUT && [esi].pin_I.dwStatus & PIN_HIDDEN

            ;// ebx is an output pin
            ;// and the pin interface is inside group

            mov ecx, [esi].pin_I.dwUser ;// get the pin from outside using pin_I

        .ELSEIF [esi].pin_O.dwStatus & PIN_HIDDEN

            ;// ebx is an input pin
            ;// and pin interface is inside a group

            mov ecx, [esi].pin_O.dwUser ;// get the pin from outside using pin_O

        .ELSE

            ;// pin input is not inside a group

            lea ecx, [esi].pin_I
            .IF ecx == ebx
                lea ecx, [esi].pin_O
            .ENDIF

        .ENDIF

        ASSUME ecx:PTR APIN

        mov eax, [ecx].dwStatus

        BITT eax, UNIT_AUTOED
        ret

pinint_GetUnit ENDP


;////////////////////////////////////////////////////////////////////////////////






;////////////////////////////////////////////////////////////////////
;//
;//
;//     _SaveUndo
;//

ASSUME_AND_ALIGN
pinint_SaveUndo PROC

        ASSUME esi:PTR PININT_OSC_MAP

    ;// edx enters as either UNREDO_CONTROL_OSC or UNREDO_COMMAND
    ;// edi enters as where to store
    ;//
    ;// task:   1) save nessary data
    ;//         2) iterate edi
    ;//
    ;// may use all registers except ebp

    ;// store dwUser

        mov eax, [esi].dwUser
        stosd

    ;// store the pin label and long name

        add esi, OFFSET PININT_OSC_MAP.pinint
        mov ecx, SIZEOF PININT_DATA / 4
        rep movsd

    ;// that's it

        ret

pinint_SaveUndo ENDP
;//
;//
;//     _SaveUndo
;//
;////////////////////////////////////////////////////////////////////

;////////////////////////////////////////////////////////////////////
;//
;//
;//     _LoadUndo
;//

ASSUME_AND_ALIGN
pinint_LoadUndo PROC

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


    ;// get dwuser

        mov eax, [edi]
        and [esi].dwUser, NOT PININT_TEST_TEST
        add edi, 4
        and eax, PININT_TEST_TEST   ;// remove anything extra
        or [esi].dwUser, eax

    ;// get the short and long name

        push esi

        add esi, OFFSET PININT_OSC_MAP.pinint
        mov ecx, SIZEOF PININT_DATA / 4
        xchg esi, edi
        rep movsd

        pop esi

    ;// initialize for the new data

        invoke pinint_check_if_need_group_sync

    ;// that should do it

        ret

pinint_LoadUndo ENDP

;//
;//
;//     _LoadUndo
;//
;////////////////////////////////////////////////////////////////////




















ASSUME_AND_ALIGN

ENDIF   ;// USE_THIS_FILE
END

