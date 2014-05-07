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
;//  ABox_Button.asm
;//
;//
;// TOC
;//
;// button_SetState
;// button_Up
;// button_Down
;// button_Render
;// button_SetShape
;// button_HitTest
;// button_Control
;// button_InitMenu
;// button_Command
;// button_SaveUndo
;// button_LoadUndo
;// button_Calc


OPTION CASEMAP:NONE

.586
.MODEL FLAT

USE_THIS_FILE equ 1

IFDEF USE_THIS_FILE

    .NOLIST
    include <Abox.inc>
    .LIST


.DATA

    BUTTON_DATA STRUCT

        pSource dd  0   ;// where to draw the control shape

    BUTTON_DATA ENDS



osc_Button OSC_CORE { ,,,button_Calc }
           OSC_GUI  { button_Render,button_SetShape,
                    button_HitTest,button_Control,
                    ,
                    button_Command,button_InitMenu,,,
                    button_SaveUndo, button_LoadUndo }
           OSC_HARD { }

    OSC_DATA_LAYOUT {NEXT_Button,IDB_BUTTON,OFFSET popup_BUTTON,,
        1,4,
        SIZEOF OSC_OBJECT + SIZEOF APIN,
        SIZEOF OSC_OBJECT + SIZEOF APIN + SAMARY_SIZE,
        SIZEOF OSC_OBJECT + SIZEOF APIN + SAMARY_SIZE + SIZEOF(BUTTON_DATA) }

    OSC_DISPLAY_LAYOUT {button_container, button_PSOURCE, ICON_LAYOUT( 0,0,2,0)}

    APIN_init {0.0,,'0',, PIN_OUTPUT OR UNIT_LOGIC }

    short_name  db  'Button',0
    description db  'Use the button produce logical true/false values. May be set as momentary or push-on/push-off',0
    ALIGN 4


    ;// button.pSource is the pSource for the button

        control_pSource TEXTEQU <button.pSource>

        ;// use:    BUTTON_DOWN_PSOURCE
        ;//         BUTTON_UP_PSOURCE
        ;//         BUTTON_PUSH_PSOURCE

        ;// use button_control as the shape

        button_control_offset   dd  0   ;// use this to position the control shape


    ;// there are three possible buttons we display

        ;// Up
        ;// Down
        ;// Pushed

    ;// flags stored in object.dwUser

        ;// state flags

            BUTTON_STATE        equ 00000002h   ;// set true if button is down now
            BUTTON_NEXT_STATE   equ 00000001h   ;// used to track toggle buttons
            BUTTON_PUSHED       equ 00000010h   ;// button is pushed by the user

        ;// user setting

            BUTTON_TOGGLE       equ 00000004h   ;// set true if push on push off
            BUTTON_DIGITAL      equ 00000008h   ;// set true if digital output

    ;// we display the output value as the pin label

        button_pFont_Plus   dd  0
        button_pFont_Zero   dd  0
        button_pFont_Minus  dd  0


    ;// osc map for this object

        OSC_MAP STRUCT

            OSC_OBJECT  {}
            pin_x   APIN {}
            data_x  dd SAMARY_LENGTH dup (0)
            button  BUTTON_DATA {}

        OSC_MAP ENDS


.CODE


;////////////////////////////////////////////////////////////////////
;//
;//                             button_SetState
;//     helper functions        button_Up
;//                             button_Down

ASSUME_AND_ALIGN
button_SetState PROC USES ebx

    ;// this functions makes sure that the button shape and
    ;// the output pin are displying the correct values

    ASSUME esi:PTR OSC_MAP

    mov ecx, [esi].dwUser

    ;// determmine which button control to display

    bt ecx, LOG2( BUTTON_PUSHED )
    jnc not_pushed

        mov eax, BUTTON_PUSH_PSOURCE
        jmp set_control_shape

    not_pushed:

        bt ecx, LOG2( BUTTON_STATE )
        jnc button_is_up

        mov eax, BUTTON_DOWN_PSOURCE
        jmp set_control_shape

    button_is_up:

        mov eax, BUTTON_UP_PSOURCE

    set_control_shape:

        mov [esi].control_pSource, eax

    ;// determine what value the pin should display

        bt ecx, LOG2( BUTTON_STATE )
        OSC_TO_PIN_INDEX esi, ebx, 0
        jnc pin_is_up

    pin_is_down:

        mov eax, button_pFont_Minus
        jmp set_the_pin

    pin_is_up:

        bt ecx, LOG2( BUTTON_DIGITAL )
        jc pin_is_digital

        pin_is_bipolar:

            mov eax, button_pFont_Plus
            jmp set_the_pin

        pin_is_digital:

            mov eax, button_pFont_Zero

    set_the_pin:

        invoke pin_SetName

    ;// that's it

        ret

button_SetState ENDP


ASSUME_AND_ALIGN
button_Up   PROC

    ;// the button is to set as up
    ASSUME esi:PTR OSC_OBJECT
    and [esi].dwUser, NOT BUTTON_STATE
    call button_SetState
    ret

button_Up   ENDP

ASSUME_AND_ALIGN
button_Down PROC

    ;// the button is to be set as down
    ASSUME esi:PTR OSC_OBJECT
    or [esi].dwUser, BUTTON_STATE
    call button_SetState
    ret

button_Down ENDP


;//
;//                             button_SetState
;//     helper functions        button_Up
;//                             button_Down
;////////////////////////////////////////////////////////////////////




ASSUME_AND_ALIGN
button_Render PROC

    ASSUME esi:PTR OSC_MAP

    ;// draw the background shape

        invoke gdi_render_osc

    ;// draw the correct button

        push esi

        mov ebx, button_control.pMask
        mov edi, [esi].pDest
        mov esi, [esi].control_pSource
        add edi, button_control_offset

        invoke shape_Move

    ;// if we'r the hover, draw the outline

        mov esi, [esp]
        .IF esi == osc_hover && app_bFlags & (APP_MODE_CONTROLLING_OSC OR APP_MODE_CON_HOVER)

            mov eax, F_COLOR_OSC_HOVER
            mov edi, [esi].pDest
            mov ebx, button_control.pOut1
            add edi, button_control_offset
            invoke shape_Fill

        .ENDIF

    ;// that's it

        pop esi

        ret

button_Render ENDP




ASSUME_AND_ALIGN
button_SetShape PROC

    ASSUME esi:PTR OSC_OBJECT

    ;// make sure the pFonts have been set
    .IF !button_pFont_Plus

        push edi

        lea edi, font_pin_slist_head
        mov eax, '1+'
        invoke font_Locate
        mov button_pFont_Plus, edi

        lea edi, font_pin_slist_head
        mov eax, '0'
        invoke font_Locate
        mov button_pFont_Zero, edi

        lea edi, font_pin_slist_head
        mov eax, '1-'
        invoke font_Locate
        mov button_pFont_Minus, edi

        pop edi

    .ENDIF

    .IF !button_control_offset

        mov eax, gdi_bitmap_size.x
        lea eax, [eax+eax*2+4]
        mov button_control_offset, eax

    .ENDIF

    ;// make sure the state is synchronized

        call button_SetState

    ;// that's it, exit to osc_SetShape

        jmp osc_SetShape

button_SetShape ENDP


ASSUME_AND_ALIGN
button_HitTest  PROC uses esi

    ASSUME esi:PTR OSC_OBJECT

    ;// we are being hit inside our shape
    ;// see if we're hitting the control
    ;// is yes, then return carry flag
    ;// if no, return no flags

    mov esi, [esi].pDest
    mov ebx, button_control.pMask
    add esi, button_control_offset
    mov edi, mouse_pDest

    invoke shape_Test

    .IF CARRY?

        xor eax, eax
        inc eax
        stc
        ret

    .ENDIF

    xor eax, eax
    inc eax
    ret

button_HitTest  ENDP


ASSUME_AND_ALIGN
button_Control  PROC

    ASSUME esi:PTR OSC_OBJECT
    ASSUME ebp:PTR LIST_CONTEXT

    ;// eax has the mouse message indicating why this is being called
    ;// we respond to up/down messages and that's it

    ;// edx will be dwuser
    ;// which will store back if we handle this

    mov edx, [esi].dwUser
    xor ecx, ecx            ;// ecx may be needed to xfer bits

    cmp eax, WM_LBUTTONDOWN
    jnz J1

;// WM_LBUTTON_DOWN

    ;// we always push the button down for this
    ;// this inturn set's the button as on

    bt edx, LOG2(BUTTON_TOGGLE)
    jnc J0

        bts edx, LOG2(BUTTON_STATE)         ;// xfer state to carry flag and set it
        cmc                                 ;// complement the carry flag
        rcl ecx, LOG2(BUTTON_NEXT_STATE)+1  ;// shift into next state
        or edx, ecx                         ;// merge back into dwUser
    J0: or edx, BUTTON_STATE + BUTTON_PUSHED;// always set the button as on and pushed
        xor eax, eax    ;// return no change
        jmp all_done

J1: cmp eax, WM_LBUTTONUP
    mov eax, 0  ;// default return value
    jnz J2

;// WM_LBUTTON_UP

        ;// the button gets let up
        ;// if we're toggle, then
        ;//     if we were off, we're

    and edx, NOT ( BUTTON_PUSHED+BUTTON_STATE)  ;// always turn off pushed and down
    bt edx, LOG2(BUTTON_TOGGLE)                 ;// see if we;re a togle
    jnc all_done

        ;// we are a toggle button, so our state has changed
        mov eax, CON_HAS_MOVED  ;// set that we changed

        btr edx, LOG2(BUTTON_NEXT_STATE)    ;// get the desired next state
        rcl ecx, LOG2(BUTTON_STATE)+1       ;// xfer into new state
        or edx, ecx                         ;// merge back into dwUser

all_done:

    mov [esi].dwUser, edx       ;// store the new dwUser
    push eax                    ;// save the return value
    invoke button_SetState      ;// synchronize our state

    pop eax ;// retrieve the return value

J2: ret     ;// that's it


button_Control  ENDP













ASSUME_AND_ALIGN
button_InitMenu PROC    ;// STDCALL uses esi edi pObject:ptr OSC_OBJECT

        ASSUME esi:PTR OSC_OBJECT

    ;// set the corect item

        .IF [esi].dwUser & BUTTON_TOGGLE
            mov ecx, ID_BUTTON_TOGGLE
        .ELSE
            mov ecx, ID_BUTTON_MOMENTARY
        .ENDIF

        invoke CheckDlgButton, popup_hWnd, ecx, BST_CHECKED

        .IF [esi].dwUser & BUTTON_DIGITAL
            mov ecx, ID_DIGITAL_DIGITAL
        .ELSE
            mov ecx, ID_DIGITAL_BIPOLAR
        .ENDIF

        invoke CheckDlgButton, popup_hWnd, ecx, BST_CHECKED

        xor eax, eax    ;// always return zero

    ;// that's it

        ret

button_InitMenu ENDP


ASSUME_AND_ALIGN
button_Command PROC


        ASSUME esi:PTR OSC_OBJECT
        ;// eax has the command id

    cmp eax, ID_BUTTON_TOGGLE
    jnz @F

        or [esi].dwUser, BUTTON_TOGGLE
        jmp all_done

@@: cmp eax, ID_BUTTON_MOMENTARY
    jnz @F

        and [esi].dwUser, NOT BUTTON_TOGGLE
        call button_Up
        jmp all_done

@@: cmp eax, ID_DIGITAL_DIGITAL
    jnz @F

        or [esi].dwUser, BUTTON_DIGITAL
        call button_SetState
        jmp all_done

@@: cmp eax, ID_DIGITAL_BIPOLAR
    jnz osc_Command

        and [esi].dwUser, NOT BUTTON_DIGITAL
        call button_SetState

all_done:

    mov eax, POPUP_REDRAW_OBJECT + POPUP_SET_DIRTY
    ret


button_Command ENDP





ASSUME_AND_ALIGN
button_SaveUndo PROC

        ASSUME esi:PTR OSC_OBJECT

        ;// edx enters as either UNREDO_CONTROL_OSC or UNREDO_COMMAND
        ;// edi enters as where to store
        ;//
        ;// task:   1) save nessary data
        ;//         2) iterate edi
        ;//
        ;// may use all registers except ebp

        mov eax, [esi].dwUser
        stosd

        ret

button_SaveUndo ENDP

ASSUME_AND_ALIGN
button_LoadUndo PROC

        ASSUME esi:PTR OSC_OBJECT       ;// preserve
        ASSUME ebp:PTR LIST_CONTEXT ;// preserve

        ;// edx enters as either UNREDO_CONTROL_OSC or UNREDO_COMMAND
        ;// edi enters as where to load
        ;//
        ;// task:   1) load nessary data
        ;//         2) do what it takes to initialize it
        ;//
        ;// may use all registers except ebp
        ;// return will invalidate HINTI_OSC_UPDATE


        mov eax, [edi]
        mov [esi].dwUser, eax
        call button_SetState

        ret

button_LoadUndo ENDP











ASSUME_AND_ALIGN
button_Calc PROC

        ASSUME esi:PTR OSC_OBJECT

    ;// this is the simplest calc of the lot

        OSC_TO_PIN_INDEX esi, ebx, 0    ;// get out put pin
        DEBUG_IF <!![ebx].pPin>     ;// supposed to be connected

        mov edi, [ebx].pData        ;// get destination pointer
        mov ecx, [esi].dwUser       ;// get dwUser
        mov eax, math_neg_1     ;// load on value now
        and [ebx].dwStatus, NOT PIN_CHANGING    ;// pin changing is never on

    ;// determine what value to store

        bt ecx, LOG2(BUTTON_STATE)  ;// on now ?
        jc check_if_store           ;// jump if yes
                                ;// off now
            xor eax, eax            ;// clear
            bt ecx, LOG2(BUTTON_DIGITAL);// digital button ?
            jc check_if_store       ;// jump if yes
            mov eax, math_1     ;// bipolar button

    ;// see if w need to store it

    check_if_store:

        cmp eax, DWORD PTR [edi];// value already correct ?
        jnz have_to_store       ;// jump if not
        ret                     ;// that's it

    have_to_store:

        mov ecx, SAMARY_LENGTH  ;// load the count
        rep stosd               ;// storeit
        ret             ;// that's it

button_Calc ENDP



ASSUME_AND_ALIGN

ENDIF   ;// USE_THIS_FILE
END
