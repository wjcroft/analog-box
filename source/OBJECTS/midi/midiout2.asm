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
;// MidiOut.asm         _H_ functions are in midiout_device.asm
;//
;// TOC
;//
;// midiout_VerifyMode
;//
;// midiout_Ctor
;//
;// midiout_InitMenu
;// midiout_Command
;//
;// midiout_Render
;//
;// midiout_SaveUndo
;// midiout_LoadUndo
;//
;// midiout_PrePlay
;// midiout_Calc

OPTION CASEMAP:NONE
.586
.MODEL FLAT


USE_THIS_FILE equ 1

IFDEF USE_THIS_FILE

    .NOLIST
    INCLUDE <Abox.inc>
    INCLUDE <midi2.inc>
    .LIST

.DATA

BASE_FLAGS = BASE_HARDWARE OR BASE_PLAYABLE OR BASE_WANT_EDIT_FOCUS_MSG

osc_MidiOut2    OSC_CORE { midiout_Ctor,hardware_DetachDevice,midiout_PrePlay,midiout_Calc }
            OSC_GUI  { midiout_Render,,,,,midiout_Command,midiout_InitMenu,,,midiout_SaveUndo,midiout_LoadUndo}
            OSC_HARD { midiout_H_Ctor,midiout_H_Dtor,midiout_H_Open,midiout_H_Close,midiout_H_Ready,midiout_H_Calc }

    ;// don't make lines too long
    ofsPinData  = SIZEOF OSC_OBJECT + (SIZEOF APIN)*5
    ofsOscData  = SIZEOF OSC_OBJECT + (SIZEOF APIN)*5+SAMARY_SIZE
    oscBytes    = SIZEOF OSC_OBJECT + (SIZEOF APIN)*5+SAMARY_SIZE+SIZEOF MIDIOUT_DATA

    OSC_DATA_LAYOUT {NEXT_MidiOut2,IDB_MIDIOUT2,OFFSET popup_MIDIOUT2,
        BASE_FLAGS,5,4+MIDIOUT_SAVE_LENGTH*4,
        ofsPinData,
        ofsOscData,
        oscBytes  }

    OSC_DISPLAY_LAYOUT{ devices_container, MIDIOUT_PSOURCE, ICON_LAYOUT(2,4,2,1)}

;// these are needed for xlate

EXTERNDEF osc_MidiOut2_pin_si:APIN_init
EXTERNDEF osc_MidiOut2_pin_N:APIN_init
EXTERNDEF osc_MidiOut2_pin_V:APIN_init
EXTERNDEF osc_MidiOut2_pin_t:APIN_init
EXTERNDEF osc_MidiOut2_pin_so:APIN_init

osc_MidiOut2_pin_si APIN_init { -0.85,,'is',,UNIT_MIDI_STREAM } ;// Midi stream in put
osc_MidiOut2_pin_N  APIN_init { -0.95,,'N',, UNIT_MIDI } ;// Midi number
osc_MidiOut2_pin_V  APIN_init {  0.95,,'V',, UNIT_MIDI } ;// value
osc_MidiOut2_pin_t  APIN_init {  0.85,,'t',, PIN_LOGIC_INPUT OR UNIT_LOGIC }    ;// trigger input
osc_MidiOut2_pin_so APIN_init {  0.0 ,,'os',,PIN_OUTPUT OR UNIT_MIDI_STREAM }   ;// stream output

    short_name  db  'Midi  Out',0
    description db  'Sends midi commands to a midi port or stream. May also be used to mix midi streams.',0
    ALIGN 4

;// table for midiout_VerifyMode

    midiout_VerifyMode_table    LABEL DWORD

    ;// bits
    ;// 0   show N
    ;// 1   N is s1
    ;// 2   show V
    ;// 3   show t
    ;// 4   t is gate (off for t is edge)
    ;// 5   build the command template
    ;// 6   merge channel into command template


    ;// 6543210 ;//                           show  desc
    dd  0000011y    ;// MIDIOUT_PORT_STREAM  0 s1   mix si with s1
    dd  0001100y    ;// MIDIOUT_PORT_CLOCK   1 Vt   tick start stop continue
    dd  0101000y    ;// MIDIOUT_PORT_RESET   2 t    reset events
    dd  1101001y    ;// MIDIOUT_CHAN_PATCH_N 3 Nt   send patch changes when triggered
    dd  1101000y    ;// MIDIOUT_CHAN_PATCH   4 t    patch changes
    dd  1100100y    ;// MIDIOUT_CHAN_PRESS   5 V    channel pressure
    dd  1100100y    ;// MIDIOUT_CHAN_WHEEL   6 V    pitch wheel
    dd  1100100y    ;// MIDIOUT_CHAN_CTRLR   7 V    controller events (need to choose controller)
    dd  1101101y    ;// MIDIOUT_CHAN_CTRLR_N 8 NVt  controller N events
    dd  1101101y    ;// MIDIOUT_NOTE_PRESS   9 NVt  note pressure events
    dd  1101101y    ;// MIDIOUT_NOTE_ON      A NVt  note on events
    dd  1101101y    ;// MIDIOUT_NOTE_OFF     B NVt  note off events
    dd  1000101y    ;// MIDIOUT_NOTE_TRACK_N C NV   state of NV,
    dd  1011101y    ;// MIDIOUT_NOTE_TRACK_t D NVt  state of NVt,
    ;// 6543210 ;//                           show  desc
    dd 0    ;// E future mode
    dd 0    ;// F future mode


;// these tell command builder which MIDI_FLOAT to use as the command

    midiout_build_command_table LABEL DWORD
    dd  0
    dd  0
    dd  MIDI_FLOAT_PORT_RESET   ;// 2 t     reset events
    dd  MIDI_FLOAT_PROGRAM      ;// 3 Nt    MIDIOUT_CHAN_PATCH_N
    dd  MIDI_FLOAT_PROGRAM      ;// 4 t     patch changes
    dd  MIDI_FLOAT_AFTERTOUCH   ;// 5 V     channel pressure
    dd  MIDI_FLOAT_PITCHWHEEL   ;// 6 V     pitch wheel
    dd  MIDI_FLOAT_CONTROLLER   ;// 7 V     controller events (need to choose controller)
    dd  MIDI_FLOAT_CONTROLLER   ;// 8 NVt   MIDIOUT_CHAN_CTRLR_N
    dd  MIDI_FLOAT_PRESSURE     ;// 9 NVt   note pressure events
    dd  MIDI_FLOAT_NOTEON       ;// A NVt   note on events
    dd  MIDI_FLOAT_NOTEOFF      ;// B NVt   note off events
    dd 0    ;//MIDIOUT_NOTE_TRACK_N C NVt   state of NVt,
    dd 0    ;//MIDIOUT_NOTE_TRACK_t D NVt   state of NVt,
    dd 0    ;// E future mode
    dd 0    ;// F future mode


;// initmenu input table

    ;// 0   init trigger buttons
    ;// 1   init channel control
    ;// 2   init combo box
    ;// 3   init combo with controllers (off for patches)

    midiout_initmenu_table  LABEL DWORD

                    ;//   trigger   channel combo
        ;// 43210   ;//   buttons   control select
        dd  00000y  ;// 0 no        no      no              MIDIOUT_PORT_STREAM     s1
        dd  00000y  ;// 1 no        no      no              MIDIOUT_PORT_CLOCK      Vt
        dd  00001y  ;// 2 yes       no      no              MIDIOUT_PORT_RESET      t
        dd  00011y  ;// 3 yes       yes     no              MIDIOUT_CHAN_PATCH_N    NVt
        dd  00111y  ;// 4 yes       yes     gm patches      MIDIOUT_CHAN_PATCH      Vt
        dd  00010y  ;// 5 no        yes     no              MIDIOUT_CHAN_PRESS      V
        dd  00010y  ;// 6 no        yes     no              MIDIOUT_CHAN_WHEEL      V
        dd  01110y  ;// 7 no        yes     controllers     MIDIOUT_CHAN_CTRLR      V
        dd  00011y  ;// 8 yes       yes     no              MIDIOUT_CHAN_CTRLR_N    NVt
        dd  00011y  ;// 9 yes       yes     no              MIDIOUT_NOTE_PRESS      NVt
        dd  00011y  ;// A yes       yes     no              MIDIOUT_NOTE_ON         NVt
        dd  00011y  ;// B yes       yes     no              MIDIOUT_NOTE_OFF        NVt
        dd  00010y  ;// C no        yes     no              MIDIOUT_NOTE_TRACK_N    NV
        dd  00010y  ;// D no        yes     no              MIDIOUT_NOTE_TRACK_t    NVt
        dd  0   ;// E
        dd  0   ;// F

.CODE

ASSUME_AND_ALIGN
midiout_VerifyMode  PROC

    ;// destroys ebx

        ASSUME esi:PTR MIDIOUT_OSC_MAP

    ;// set device correctly

        ;// if we are stream out,
        ;//     makes sure we do not have a device
        ;//     make sure so is displayed
        ;// if we are device out
        ;//     make sure we have a device
        ;//     make sure so is NOT displayed

    check_output_mode:

        mov ecx, [esi].dwUser           ;// get dwUser so we can test the mode
        lea ebx, [esi].pin_so           ;// point ebx at so pin
        and ecx, MIDIOUT_OUTPUT_TEST    ;// strip out extra bits
        jz verify_mode_bad_maximum      ;// bad if no output mode is set

        cmp ecx, MIDIOUT_OUTPUT_MAXIMUM ;// make sure ecx is not beyond maximum
        ja verify_mode_bad

        cmp ecx, MIDIOUT_OUTPUT_DEVICE  ;// device or stream ?
        je verify_mode_device

    verify_mode_stream:

        invoke pin_Show, 1  ;// make sure stream out is shown
        cmp [esi].pDevice, 0
        jz verify_mode_input

            invoke hardware_DetachDevice    ;// if we have a device, release it

        jmp verify_mode_input

    ALIGN 16
    verify_mode_device:

        ;// cant't have midi devices inside of groups

        .IF ebp != OFFSET master_context

            ;// can't have devices inside groups
            ;// we'll set as default mode, then try again
            mov [esi].dwUser, MIDIOUT_OUTPUT_STREAM
            jmp check_output_mode

        .ENDIF

        invoke pin_Show, 0  ;// make sure stream is not shown
        cmp [esi].pDevice, 0;// make sure we have a device attached
        jnz verify_mode_input

            mov edx, [esi].dwUser
            and edx, 0FFFFh
            invoke hardware_AttachDevice

        jmp verify_mode_input

    verify_mode_bad_maximum:

        and [esi].dwUser, NOT MIDIOUT_OUTPUT_TEST   ;// remove the over flowing mode

    verify_mode_bad:

        invoke osc_SetBadMode, 1

        ;// hide all the pins

        ;// ebx is currently at so
        xor ecx, ecx                ;// ecx also doubles as the pin show flags
        invoke pin_Show, ecx
        lea ebx, [esi].pin_si
        invoke pin_Show, ecx
        add ebx, SIZEOF APIN
        jmp verify_mode_input_now

    ALIGN 16
    verify_mode_input:

        invoke osc_SetBadMode, 0

        ;// make sure si is on

        lea ebx, [esi].pin_si
        invoke pin_Show, 1

        ;// show and name input pins correcty

        mov eax, [esi].dwUser
        add ebx, SIZEOF APIN
        and eax, MIDIOUT_INPUT_TEST
        BITSHIFT eax, MIDIOUT_PORT_CLOCK, 1
        mov ecx, midiout_VerifyMode_table[eax*4]
    ;// ASSUME ebx:PTR APIN

    verify_mode_input_now:

    ;// bit 0   show N
    ;// bit 1   N is s1

        ;// ebx must point at N pin

        ;// if show N
        ;//     make sure N is shown
        ;//     if N is s1
        ;//         make sure N says s1
        ;//         make sure units are midi stream
        ;//     else
        ;//         make sure N says N
        ;//         make sure units are midi number
        ;//     endif

        shr ecx, 1
        .IF CARRY?
            invoke pin_Show, 1  ;// make sure N is shown
            shr ecx, 1
            .IF CARRY?
                ;// make sure N says s1 and that units are stream
                invoke pin_SetNameAndUnit, midi_font_s1_in, OFFSET sz_Stream, UNIT_MIDI_STREAM
            .ELSE
                ;// make sure N says N and that units are midi
                invoke pin_SetNameAndUnit, midi_font_N_in, OFFSET sz_Number, UNIT_MIDI
            .ENDIF
        .ELSE
            invoke pin_Show, 0  ;// make sure N is hidden
            shr ecx, 1
        .ENDIF

    ;// bit 2   show V

        ;// if show V
        ;//     make sure V is shown
        ;// else
        ;//     maje sure V is hidden
        ;// endif

        add ebx, SIZEOF APIN

        xor edx, edx
        shr ecx, 1
        adc edx, edx
        invoke pin_Show, edx

    ;// bit 3   show t
    ;// bit 4   t is gate

        ;// if show t
        ;//     make sure t is shown
        ;//     if t is gate
        ;//         make sure t is a gate
        ;//     else
        ;//         make sure t is correct logic level
        ;//     end if
        ;// else
        ;//     hide t
        ;// endif

        add ebx, SIZEOF APIN

        shr ecx, 1
        .IF CARRY?
            invoke pin_Show, 1  ;// make sure t is shown
            shr ecx, 1
            mov eax, PIN_LOGIC_GATE OR PIN_LEVEL_NEG OR PIN_LOGIC_INPUT
            .IF !CARRY?
                mov eax, [esi].dwUser
                and eax, MIDIOUT_TRIG_EDGE_TEST
                BITSHIFT eax,MIDIOUT_TRIG_EDGE_POS,PIN_LEVEL_POS
                or eax, PIN_LOGIC_INPUT
            .ENDIF
            invoke pin_SetInputShape
        .ELSE
            invoke pin_Show, 0  ;// make sure t is hidden
            shr ecx, 1          ;// keep track of bits
        .ENDIF

    ;// bit 5   build the command template
    ;// bit 6   merge channel into command template

        shr ecx, 1
        .IF CARRY?

            mov eax, [esi].dwUser                   ;// get our mode
            and eax, MIDIOUT_INPUT_TEST             ;// strip out extra

            xor edx, edx                            ;// edx may merge in the patch or controller
            .IF eax == MIDIOUT_CHAN_PATCH           ;// need the patch ?
                mov edx, [esi].midiout.patch        ;// get it
            .ELSEIF eax == MIDIOUT_CHAN_CTRLR       ;// need the controller ?
                mov edx, [esi].midiout.controller   ;// get it
            .ENDIF
            BITSHIFT edx, 1, MIDI_FLOAT_FIRST_NUMBER    ;// turn patch/controller into number

            BITSHIFT eax, MIDIOUT_PORT_CLOCK, 1     ;// turn mode into table index
            mov eax, midiout_build_command_table[eax*4] ;// get the command template
            or eax, edx                             ;// merge in patch, controller or zero

            shr ecx, 1  ;// merge in channel ?
            .IF CARRY?

                mov edx, [esi].midiout.channel      ;// get the channel
                BITSHIFT edx, 1, MIDI_FLOAT_FIRST_CHANNEL   ;// turn into channel
                or eax, edx                         ;// merge into command

            .ENDIF

            mov [esi].midiout.command, eax          ;// store the command

        .ELSE

            shr ecx, 1  ;// keep track of bits

        .ENDIF

    ;// since we (may have) changed modes, we need to reset the continous values

        mov eax, ecx
        DEBUG_IF <ecx>  ;// supposed to be zero !!

        mov [esi].pin_N.dwUser, ecx
        mov [esi].pin_V.dwUser, eax
        mov [esi].pin_t.dwUser, ecx
        mov [esi].midiout.last_N, eax
        mov [esi].midiout.last_V, ecx
        mov [esi].midiout.last_t, eax

    ;// all done

        ret

midiout_VerifyMode  ENDP


ASSUME_AND_ALIGN
midiout_Ctor    PROC

    ;// register call

        ASSUME ebp:PTR LIST_CONTEXT ;// preserve
        ASSUME esi:PTR OSC_OBJECT   ;// preserve
        ASSUME edi:PTR OSC_BASE     ;// may_destroy
        ASSUME ebx:PTR FILE_OSC     ;// may destroy
        ASSUME edx:PTR FILE_HEADER  ;// may destroy

    ;// we've been created
    ;// any data we have is loaded

        .IF !edx    ;// creating from pallette ?
            mov [esi].dwUser, MIDIOUT_PORT_STREAM OR MIDIOUT_OUTPUT_STREAM
        .ENDIF

    ;// make sure the fonts are set BEFORE we call verify mode

        .IF midi_font_N_in == 'N'
            invoke midistring_SetFonts
        .ENDIF

    ;// call verify mode

        invoke midiout_VerifyMode

    ;// that should do it

        ret

midiout_Ctor    ENDP






ASSUME_AND_ALIGN
midiout_InitMenu    PROC uses edi

        ASSUME ebp:PTR LIST_CONTEXT
        ASSUME esi:PTR MIDIOUT_OSC_MAP
        ;// destroys ebx

    ;// check if mode is bad

        mov eax, [esi].dwUser
        and eax, MIDIOUT_OUTPUT_TEST
        jz init_bad_mode

    ;// if we are in a group, we cannot adjust the input mode

        .IF ebp != OFFSET master_context
            ENABLE_CONTROL popup_hWnd, ID_MIDIOUT_OUTPUT_DEVICE, 0
            ENABLE_CONTROL popup_hWnd, ID_MIDIOUT_OUTPUT_STREAM, 0
        .ENDIF

    ;// determine if device or stream

        .IF eax == MIDIOUT_OUTPUT_DEVICE

            ;// push the button
            CHECK_BUTTON popup_hWnd, ID_MIDIOUT_OUTPUT_DEVICE, BST_CHECKED

            ;// enable and fill in the device list
            ENABLE_CONTROL popup_hWnd, ID_MIDIOUT_OUTPUT_LIST, 1, ebx
            invoke hardware_FillInDeviceList

            ;// show our device
            mov ecx, [esi].pDevice
            .IF ecx

                lea ebx, (HARDWARE_DEVICEBLOCK PTR [ecx]).szName
                invoke GetDlgItem, popup_hWnd, ID_MIDIOUT_OUTPUT_NAME_STATIC
                WINDOW eax, WM_SETTEXT,,ebx

            .ENDIF

        .ELSE   ;// output stream

            ;// push the button
            CHECK_BUTTON popup_hWnd, ID_MIDIOUT_OUTPUT_STREAM, BST_CHECKED

            ;// disable the device list
            ENABLE_CONTROL popup_hWnd, ID_MIDIOUT_OUTPUT_LIST, 0, ebx
            WINDOW ebx, LB_RESETCONTENT

            ;// show stream
            invoke GetDlgItem, popup_hWnd, ID_MIDIOUT_OUTPUT_NAME_STATIC
            WINDOW eax, WM_SETTEXT,,OFFSET sz_Stream

        .ENDIF

    init_good_mode:

    ;// enable the controls

        mov ebx, 1
        call x_able_all_controls

    ;// set up input mode, push the correct button as well

        mov ebx, [esi].dwUser
        and ebx, MIDIOUT_INPUT_TEST
        BITSHIFT ebx, MIDIOUT_PORT_CLOCK, 1

        lea ecx, [ebx+ID_MIDIOUT_PORT_STREAM]
        CHECK_BUTTON popup_hWnd, ecx, BST_CHECKED
        mov ebx, midiout_initmenu_table[ebx*4]

    ;// 0   init trigger buttons

        shr ebx, 1
        .IF CARRY?

            ;// enable the three buttons
            ENABLE_CONTROL popup_hWnd, ID_MIDIOUT_TRIG_EDGE_BOTH, 1
            ENABLE_CONTROL popup_hWnd, ID_MIDIOUT_TRIG_EDGE_POS, 1
            ENABLE_CONTROL popup_hWnd, ID_MIDIOUT_TRIG_EDGE_NEG, 1

            ;// push the correct one

            mov ecx,ID_MIDIOUT_TRIG_EDGE_BOTH
            mov eax, [esi].dwUser
            and eax, MIDIOUT_TRIG_EDGE_TEST
            BITSHIFT eax, MIDIOUT_TRIG_EDGE_POS, 1
            add ecx, eax
            CHECK_BUTTON popup_hWnd, ecx, BST_CHECKED

        .ELSE

            ;// disbale the three buttons
            ENABLE_CONTROL popup_hWnd, ID_MIDIOUT_TRIG_EDGE_BOTH, 0
            ENABLE_CONTROL popup_hWnd, ID_MIDIOUT_TRIG_EDGE_POS, 0
            ENABLE_CONTROL popup_hWnd, ID_MIDIOUT_TRIG_EDGE_NEG, 0

        .ENDIF

    ;// 1   init channel control

        shr ebx, 1
        .IF CARRY?

            ;// enable the control
            MIDIOUT_EDIT_LENGTH EQU 8
            MIDIOUT_EDIT_LIMITTEXT EQU MIDIOUT_EDIT_LENGTH - 1

            READONLY_CONTROL popup_hWnd, ID_MIDIOUT_CHAN_EDIT, 0, edi
            WINDOW edi, EM_SETLIMITTEXT, MIDIOUT_EDIT_LIMITTEXT

            ;// set with proper text
            pushd 'i%'      ;// format string
            mov edx, esp
            sub esp, 16     ;// dest buffer
            mov ecx, esp
            mov eax, [esi].midiout.channel  ;// get the channel
            inc eax                         ;// increase by one
            invoke wsprintfA, ecx, edx, eax ;// format the number
            WINDOW edi, WM_SETTEXT,,esp     ;// set the text
            add esp, 20     ;// clean up the stack

        .ELSE

            ;// disable the cntrol
            READONLY_CONTROL popup_hWnd, ID_MIDIOUT_CHAN_EDIT, 1, edi
            ;// zero the text
            pushd 0
            WINDOW edi, WM_SETTEXT,,esp     ;// set the text
            add esp, 4      ;// clean up the stack

        .ENDIF

    ;// 2   init combo box
    ;// 3   init combo with controllers (off for patches)

        shr ebx, 1
        .IF CARRY?

        push ebp    ;// ebp will be the combo box

        ;// enable and set up the combo box

            ENABLE_CONTROL popup_hWnd, ID_MIDIOUT_SELECT_COMBO, 1, ebp
            WINDOW ebp, WM_SETREDRAW, 0
            WINDOW ebp, CB_RESETCONTENT
            WINDOW ebp, CB_SETEXTENDEDUI, 1
            WINDOW ebp, CB_LIMITTEXT, MIDIOUT_EDIT_LIMITTEXT

        push esi    ;// esi will walk the list

            or edi, -1  ;// edi will be the index of the item we want to select

        ;// get the correct list and determine which item we want selected

            shr ebx, 1
            .IF CARRY?  ;// use controller list
                push [esi].midiout.controller
                mov esi, OFFSET midi_controller_table
            .ELSE       ;// use patch list
                push [esi].midiout.patch
                mov esi, OFFSET midi_patch_table
            .ENDIF
            ASSUME esi:PTR MIDI_COMBO_ITEM

        ;// add all the strings and set their number

            mov edx, [esi].psz_text
            .REPEAT

                WINDOW ebp,CB_ADDSTRING,,edx
                mov edx, [esi].number
                .IF edx == [esp]
                    mov edi, eax    ;// store the item number
                .ENDIF
                WINDOW ebp,CB_SETITEMDATA,eax,edx
                add esi, SIZEOF MIDI_COMBO_ITEM
                mov edx, [esi].psz_text

            .UNTIL !edx

        ;// determine which item we select

            pop ecx
            .IF edi != -1   ;// we found an item to select

                WINDOW ebp,CB_SETCURSEL,edi ;// set the desired item

            .ELSE   ;// we do not have an item, just a number (in ecx)
                    ;// so we set the edit text

                pushd 'i%'  ;// format
                mov edx, esp
                sub esp, 16 ;// text buffer
                mov eax, esp
                invoke wsprintfA, eax, edx, ecx
                WINDOW ebp,WM_SETTEXT,,esp
                add esp, 20

            .ENDIF

        pop esi
            ASSUME esi:PTR MIDIOUT_OSC_MAP
            WINDOW ebp, WM_SETREDRAW, 1
            invoke InvalidateRect, ebp, 0, 1
        pop ebp
            ASSUME ebp:PTR LIST_CONTEXT

        .ELSE

            ;// disable the combo box

            ENABLE_CONTROL popup_hWnd, ID_MIDIOUT_SELECT_COMBO, 0, eax
            WINDOW ebp, CB_RESETCONTENT

            shr ebx, 1  ;// extract the extra bit

        .ENDIF

        jmp all_done

    ALIGN 16
    init_bad_mode:

        ;// disable all controlls except the output buttons

        xor ebx, ebx
        call x_able_all_controls

    ALIGN 16
    all_done:

        xor eax, eax    ;// always clear eax or pop will resize dialog

        ret


;// local function


    ALIGN 16
    x_able_all_controls:

        ;// ebx must have yes no
        ;// destoys edi

        mov edi,ID_MIDIOUT_TRIG_EDGE_BOTH
        pushd 6
        call xable_these_controls

        inc edi
        mov DWORD PTR [esp], 4
        call xable_these_controls

        inc edi
        mov DWORD PTR [esp], 4
        call xable_these_controls
        pop eax

        ENABLE_CONTROL popup_hWnd, ID_MIDIOUT_OUTPUT_LIST, ebx
        xor edx, edx
        test ebx, ebx
        setz dl
        READONLY_CONTROL popup_hWnd, ID_MIDIOUT_CHAN_EDIT, edx  ;//     EQU     1040t
        ENABLE_CONTROL popup_hWnd,ID_MIDIOUT_SELECT_COMBO, ebx  ;//     EQU     1050t

        retn

    ALIGN 16
    xable_these_controls:

        ;// [esp+4] must have count
        ;// edi must have starting ID
        ;// ebxx is yes no

        .REPEAT
            ENABLE_CONTROL popup_hWnd, edi, ebx
            inc edi
            dec DWORD PTR [esp+4]
        .UNTIL ZERO?
        retn


midiout_InitMenu    ENDP










ASSUME_AND_ALIGN
midiout_Command PROC

        ASSUME esi:PTR MIDIOUT_OSC_MAP
        ;// eax has the command
        ;// ecx may have control id

;// EDIT COMMANDS

    ;// ID_MIDIOUT_CHAN_EDIT            1040

    cmp eax, OSC_COMMAND_EDIT_CHANGE
    jne @F

        ;// ecx has ctrl id
        ;// get the string
        ;// look for enter key, replace with zero
        ;// if found, try to parse number string
        ;// if valid, set new channel

        invoke GetDlgItem, popup_hWnd, ecx
        mov ebx, eax

        sub esp, MIDIOUT_EDIT_LENGTH
        WINDOW ebx, WM_GETTEXT, MIDIOUT_EDIT_LENGTH, esp
        ;// eax returns with text length

        ;// check for enter key
        STR_FIND_CRLF_reverse esp,eax,enter_key_not_found,c

    ;// enter key was found, make sure it's a valid number
    check_for_valid_channel_number:

        STR2INT esp                 ;// number returned in ecx
        add esp, MIDIOUT_EDIT_LENGTH;// clean up the stack

        cmp ecx, 16                 ;// number too big ?
        jae verify_mode_and_done    ;// exit if so
        dec ecx                     ;// we store channels as zero based
        js verify_mode_and_done     ;// if user entered zero, then abort
        ;// got a new channel
        mov [esi].midiout.channel, ecx  ;// store the new channel
        jmp verify_mode_and_done

    enter_key_not_found:

        add esp, MIDIOUT_EDIT_LENGTH
        jmp ignore_and_done


@@: cmp eax, OSC_COMMAND_EDIT_KILLFOCUS
    jne @F

        ;// ecx has ctrl id

        ;// see if changed
        ;// try to parse number string
        ;// if valid, set new channel

        invoke GetDlgItem, popup_hWnd, ecx
        mov ebx, eax
        WINDOW ebx, EM_GETMODIFY
        test eax, eax
        jz ignore_and_done

        sub esp, MIDIOUT_EDIT_LENGTH
        WINDOW ebx, WM_GETTEXT, MIDIOUT_EDIT_LENGTH, esp
        jmp check_for_valid_channel_number


;// LIST SELECTION

    ;// ID_MIDIOUT_OUTPUT_LIST          1030
@@: cmp eax, OSC_COMMAND_LIST_DBLCLICK
    jne @f

        ;// ecx has list item dword
        ASSUME ecx:PTR HARDWARE_DEVICEBLOCK
        cmp ecx, [esi].pDevice
        je ignore_and_done
        invoke hardware_ReplaceDevice, ecx
        jmp verify_mode_and_done


    ;// ID_MIDIOUT_SELECT_COMBO     1050
@@: cmp eax, OSC_COMMAND_COMBO_SELENDOK
    jne @F

        mov edi, OFFSET verify_mode_and_done

    set_patch_or_controller:
    ;// ecx has item data of selection
    ;// it is either a patch or a controller number
    ;// edi must have were to exit

        mov eax, [esi].dwUser
        and eax, MIDIOUT_INPUT_TEST
        cmp eax, MIDIOUT_CHAN_PATCH
        jne J1

            mov [esi].midiout.patch, ecx
            jmp edi

    J1: cmp eax, MIDIOUT_CHAN_CTRLR
        jne ignore_and_done

            mov [esi].midiout.controller, ecx
            jmp edi

    ignore_and_done:

        mov eax, POPUP_IGNORE
        jmp all_done

@@: cmp eax, OSC_COMMAND_COMBO_EDITUPDATE
    jne @F

        ;// the edit text has changed
        ;// get the string
        ;// look for enter key
        ;// if found, check for valid number (0-127)
        ;// if valid, set new number

        invoke GetDlgItem, popup_hWnd, ecx
        mov ebx, eax
        sub esp, MIDIOUT_EDIT_LENGTH
        WINDOW ebx, WM_GETTEXT, MIDIOUT_EDIT_LENGTH, esp

        ;// we do not get the enter
        ;// and there's no documented way to get it
        ;// so we'll parse it and hope for the best

        STR2INT esp
        add esp, MIDIOUT_EDIT_LENGTH
        cmp ecx, 127
        ja ignore_and_done

        mov edi, OFFSET ignore_and_done
        jmp set_patch_or_controller


;// OUTPUT MODES

    ;// ID_MIDIOUT_OUTPUT_STREAM        1010
    ;// ID_MIDIOUT_OUTPUT_DEVICE        1011
@@: cmp eax, ID_MIDIOUT_OUTPUT_STREAM
    jb osc_Command
    cmp eax, ID_MIDIOUT_OUTPUT_DEVICE
    ja @F

        sub eax, (ID_MIDIOUT_OUTPUT_STREAM-1)       ;// turn into zero based index
        and [esi].dwUser, NOT MIDIOUT_OUTPUT_TEST   ;// remove old mode
        BITSHIFT eax, 1, MIDIOUT_OUTPUT_STREAM      ;// turn into proper dwUser bits
        or [esi].dwUser, eax                        ;// place in dwUser
        jmp verify_mode_and_done

;// TRIGGER MODES

    ;// ID_MIDIOUT_TRIG_EDGE_BOTH       1012
    ;// ID_MIDIOUT_TRIG_EDGE_POS        1013
    ;// ID_MIDIOUT_TRIG_EDGE_NEG        1014
@@: cmp eax, ID_MIDIOUT_TRIG_EDGE_BOTH
    jb osc_Command
    cmp eax, ID_MIDIOUT_TRIG_EDGE_NEG
    ja @F

        sub eax, ID_MIDIOUT_TRIG_EDGE_BOTH
        and [esi].dwUser, NOT MIDIOUT_TRIG_EDGE_TEST
        BITSHIFT eax, 1, MIDIOUT_TRIG_EDGE_POS
        or [esi].dwUser, eax
        jmp verify_mode_and_done


;// INPUT MODES
@@:

    ;// ID_MIDIOUT_PORT_STREAM          1015
    ;// ...
    ;// ID_MIDIOUT_NOTE_TRACK_t         1028
    cmp eax, ID_MIDIOUT_PORT_STREAM
    jb osc_Command
    cmp eax, ID_MIDIOUT_NOTE_TRACK_t
    ja osc_Command

        sub eax, ID_MIDIOUT_PORT_STREAM
        and [esi].dwUser, NOT MIDIOUT_INPUT_TEST
        BITSHIFT eax, 1, MIDIOUT_PORT_CLOCK
        or [esi].dwUser, eax

    verify_mode_and_done:

        invoke midiout_VerifyMode
        mov eax, POPUP_SET_DIRTY OR POPUP_REDRAW_OBJECT OR POPUP_INITMENU

    all_done:

        ret

midiout_Command ENDP




ASSUME_AND_ALIGN
midiout_Render  PROC

    ASSUME esi:PTR MIDIOUT_OSC_MAP
    ASSUME edi:PTR OSC_BASE

    ;// render the osc first

        invoke gdi_render_osc   ;// render the background first

    ;// format
    ;//
    ;//     in: commands
    ;//     out: device number



    ;// don't display bad modes

        mov eax, [esi].dwUser
        and eax, MIDIOUT_OUTPUT_TEST
        jz all_done

    ;// make some room for formatting rect

        sub esp, SIZEOF RECT
        st_rect TEXTEQU <(RECT PTR [esp])>

    ;// set text color to osc text

        GDI_DC_SELECT_FONT hFont_pin
        GDI_DC_SET_COLOR COLOR_OSC_TEXT
        xor ebx, ebx    ;// make sure ebx does not equal esp

    ;// display the input mode at the top left

        ;// calculate the position

        point_GetTL [esi].rect
        point_Add MIDI_LABEL_BIAS
        point_SetTL st_rect

        point_GetBR [esi].rect
        point_Sub MIDI_LABEL_BIAS
        point_SetBR st_rect

        ;// get the string we want to display
        ;// if note track, point at a different string

        mov eax, [esi].dwUser
        and eax, MIDIOUT_INPUT_TEST
    ;// .IF eax == MIDIOUT_NOTE_TRACK
    ;//     mov edx, OFFSET sz_midiout_track
    ;// .ELSE
            BITSHIFT eax, MIDIOUT_PORT_CLOCK, 1         ;// turn into dword index
            mov edx, midiout_command_label_table[eax*4] ;// ptr to text
    ;// .ENDIF

        ;// display the text

        mov eax, esp
        invoke DrawTextA, gdi_hDC, edx, -1, eax, DT_LEFT

    ;// display the channel underneath

        mov edx, [esi].dwUser
        and edx, MIDIOUT_INPUT_TEST
        .IF edx > MIDIOUT_PORT_RESET

            add st_rect.top, eax    ;// scoot the top down
            mov ecx, esp            ;// points at rect

            mov eax, [esi].midiout.channel
            .IF eax < 9
                add eax, 63682031h  ;// '1' + 'ch '
            .ELSE
                add eax, 63683127h  ;// '0'-9 + 'ch1'
            .ENDIF

            bswap eax
            push eax
            mov edx, esp
            invoke DrawTextA, gdi_hDC, edx, 4, ecx, DT_LEFT
            pop eax

        .ENDIF

    ;// display the output device name
    ;// at the bottom right

        .IF [esi].pDevice

            mov ecx, [esi].pDevice
            add ecx, OFFSET HARDWARE_DEVICEBLOCK.szName

            mov eax, esp
            invoke DrawTextA, gdi_hDC, ecx, -1, eax, DT_SINGLELINE OR DT_LEFT OR DT_BOTTOM

        .ENDIF

    ;// clean up and split

        add esp, SIZEOF RECT
        st_rect TEXTEQU <>

    ;// that's it
    all_done:

        ret

midiout_Render  ENDP




ASSUME_AND_ALIGN
midiout_SaveUndo    PROC

        ASSUME esi:PTR MIDIOUT_OSC_MAP

    ;// edx enters as either UNREDO_CONTROL_OSC or UNREDO_COMMAND
    ;// edi enters as where to store
    ;//
    ;// task:   1) save nessary data
    ;//         2) iterate edi
    ;//
    ;// may use all registers except ebp

        mov eax, [esi].dwUser
        stosd
        mov eax, [esi].midiout.channel
        stosd
        mov eax, [esi].midiout.patch
        stosd
        mov eax, [esi].midiout.controller
        stosd

        ret

midiout_SaveUndo    ENDP




ASSUME_AND_ALIGN
midiout_LoadUndo    PROC

        ASSUME esi:PTR MIDIOUT_OSC_MAP  ;// preserve
        ASSUME ebp:PTR LIST_CONTEXT     ;// preserve

    ;// edx enters as either UNREDO_CONTROL_OSC or UNREDO_COMMAND
    ;// edi enters as where to load
    ;//
    ;// task:   1) load nessary data
    ;//         2) do what it takes to initialize it
    ;//
    ;// may use all registers except ebp and esi
    ;// return will invalidate HINTI_OSC_UPDATE

        mov eax, [edi]
        mov [esi].dwUser, eax
        mov eax, [edi+4]
        mov [esi].midiout.channel, eax
        mov eax, [edi+8]
        mov [esi].midiout.patch, eax
        mov eax, [edi+12]
        mov [esi].midiout.controller, eax

        invoke midiout_VerifyMode

        ret

midiout_LoadUndo    ENDP




ASSUME_AND_ALIGN
midiout_PrePlay PROC

        ASSUME esi:PTR MIDIOUT_OSC_MAP

        xor eax, eax    ;// so play preplay will erase our data

    ;// clear our previous trigger

        mov [esi].pin_N.dwUser, eax
        mov [esi].pin_V.dwUser, eax
        mov [esi].pin_t.dwUser, eax

    ;// clear our internal states

        mov [esi].midiout.last_N, eax
        mov [esi].midiout.last_V, eax
        mov [esi].midiout.last_t, eax

    ;// eax is zero, so play will erase our data (althought it doesn't need to)

        ret

midiout_PrePlay ENDP


;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////
;///
;///
;///    C A L C
;///
;///
;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////
comment ~ /*


    calc uses the following locations to store data


    pin.dwUser  always stores the SAMPLE VALUE
    last_V, last_N, last_t always stores the MIDI VALUE
    last_ is ALWAYS assumed to be correct (saturate)

*/ comment ~


.DATA


    ALIGN 16
    midiout_temp_V  dd  0   ;// temp storage for number convertion
    midiout_temp_N  dd  0   ;// temp storage for number convertion



    midiout_calc_jump_table LABEL DWORD

    dd  calc_MIDIOUT_PORT_STREAM    ;// 0 s1    mix si with s1
    dd  calc_MIDIOUT_PORT_CLOCK     ;// 1 Vt    tick start stop continue
    ;// triggered
    dd  calc_MIDIOUT_PORT_RESET     ;// 2 t     reset events
    dd  calc_MIDIOUT_CHAN_PATCH_N   ;// 3 Nt    patch changes from N
    dd  calc_MIDIOUT_CHAN_PATCH     ;// 4 t     patch changes   (need to chose patch)
    ;// contiuous
    dd  calc_MIDIOUT_CHAN_PRESS     ;// 5 V     channel pressure
    dd  calc_MIDIOUT_CHAN_WHEEL     ;// 6 V     pitch wheel
    dd  calc_MIDIOUT_CHAN_CTRLR     ;// 7 V     controller events (need to choose controller)
    ;// triggered note commands
    dd  calc_MIDIOUT_CHAN_CTRLR_N   ;// 8 NVt   controller events from N pin
    dd  calc_MIDIOUT_NOTE_PRESS     ;// 9 NVt   note pressure events
    dd  calc_MIDIOUT_NOTE_ON        ;// A NVt   note on events
    dd  calc_MIDIOUT_NOTE_OFF       ;// B NVt   note off events
    dd  calc_MIDIOUT_NOTE_TRACK_N   ;// C NV    state of NV,
    dd  calc_MIDIOUT_NOTE_TRACK_t   ;// D NVt   state of NVt,
    ;// not used yet
    dd  calc_mode_bad               ;// E
    dd  calc_mode_bad               ;// F

    ;// these are used for tracker commands
    TRACK_N_calc_jump   LABEL DWORD

    dd  TRACK_N_calc_sNsV   ;// 00
    dd  TRACK_N_calc_sNdV   ;// 01
    dd  TRACK_N_calc_dNsV   ;// 10
    dd  TRACK_N_calc_dNdV   ;// 11

    ;// these are used for tracker commands
    TRACK_t_calc_jump   LABEL DWORD

    dd  TRACK_t_calc_sVst   ;// 00
    dd  TRACK_t_calc_sVdt   ;// 01
    dd  TRACK_t_calc_dVst   ;// 10
    dd  TRACK_t_calc_dVdt   ;// 11



;// MACROS for CALC


;// use this for triggered commands with 0,1 or 2 parameters
;// if 1 parameter,
;//     [ebp+ecx*4] must point at where to get the value
;//     specify N or V to specify where to put it
;// if 2 parameters
;//     [ebp+ecx*4] must point at where to get the V value
;//     [ebx+ecx*4] must point at where to get the N value
;//     use N_V to specify two parameters
;// cmd specifies where to put the data (N V or NONE)
;// calls midiout_insert_command to inject into stream

MIDIOUT_BUILD_COMMAND MACRO cmd:REQ

    IFIDN <cmd>,<NONE>

        mov edx, ecx
        lea eax, [esi].stream
        shr edx, 1
        invoke midistream_Insert, eax, edx, [esi].midiout.command

    ELSEIFIDN <cmd>,<N_V>       ;// both N and V values

        fld [ebp+ecx*4] ;// V   ;// load the new source data
        fabs
        fmul math_128           ;// scale to midi number

        fld [ebx+ecx*4] ;// N
        fabs
        fmul math_128           ;// scale to midi number

        fxch
        fistp midiout_temp_V    ;// store new value in midiout_temp
        fistp midiout_temp_N

        mov eax, midiout_temp_N ;// get the new value
        mov edx, midiout_temp_V ;// get the new value

        .IF eax & 0FFFFFF80h    ;// check for overflow
            mov eax, 7Fh
        .ENDIF
        .IF edx & 0FFFFFF80h    ;// check for overflow
            mov edx, 7Fh
        .ENDIF

        shl eax, 8
        or eax, edx
        or eax, [esi].midiout.command

        mov edx, ecx
        shr edx, 1
        invoke midistream_Insert, ADDR [esi].stream, edx, eax   ;// inject into stream

    ELSE    ;// N or V

        fld [ebp+ecx*4]             ;// load the new V sample
        fabs
        fmul math_128               ;// scale to midi number
        mov eax, [esi].midiout.last_V;// get the last save value
        fistp midiout_temp_V        ;// store new value in midiout_temp
        mov edx, midiout_temp_V     ;// get the new value
        .IF edx & 0FFFFFF80h        ;// check for overflow
            mov edx,7Fh
        .ENDIF
        .IF eax != edx              ;// different ?
            mov [esi].midiout.last_V, edx   ;// store the new value
            mov eax, [esi].midiout.command  ;// get the command template
            IFIDN <cmd>,<N>
                shl edx, 8
            ELSE    ;// IFIDN <cmd>,<V>
            ENDIF

            or eax, edx     ;// merge parameter with command

            mov edx, ecx
            shr edx, 1
            invoke midistream_Insert, ADDR [esi].stream, edx, eax   ;// inject into stream

        .ENDIF
    ENDIF

    ENDM



;// these three look at [edi+ecx*4] for triggering
;// ecx is iterated until done
;// when trigger is hit, midiout_insert_command is called
;// ebp,ebx must point at parameter data (as required)
;// each half of the testt loop does two samples at a time

;// all three macros require that eax enter as the first sample
;// all three macros exit to the label all_done

MIDIOUT_TRIGGERED_POS   MACRO cmd:REQ

    LOCAL have_pos, have_neg, got_neg, got_pos

    test eax, eax
    jns have_pos

    have_neg:
        and eax, [edi+ecx*4]
        jns got_pos
    got_neg:
        inc ecx
        cmp ecx, SAMARY_LENGTH
        jae all_done
        and eax, [edi+ecx*4]
        jns got_pos
        inc ecx
        cmp ecx, SAMARY_LENGTH
        jb have_neg
        jmp all_done
    got_pos:    ;// build and emit the command
        MIDIOUT_BUILD_COMMAND cmd
        mov eax, [edi+ecx*4]
        inc ecx
        cmp ecx, SAMARY_LENGTH
        jae all_done
    have_pos:
        or eax, [edi+ecx*4]
        js got_neg
        inc ecx
        cmp ecx, SAMARY_LENGTH
        jae all_done
        or eax, [edi+ecx*4]
        js got_neg
        inc ecx
        cmp ecx, SAMARY_LENGTH
        jb have_pos
        jmp all_done

    ENDM


MIDIOUT_TRIGGERED_NEG   MACRO cmd:REQ

    LOCAL have_pos, have_neg, got_neg, got_pos

    test eax, eax
    js have_neg

    have_pos:
        or eax, [edi+ecx*4]
        js got_neg
    got_pos:
        inc ecx
        cmp ecx, SAMARY_LENGTH
        jae all_done
        or eax, [edi+ecx*4]
        js got_neg
        inc ecx
        cmp ecx, SAMARY_LENGTH
        jb have_pos
        jmp all_done
    got_neg:    ;// build the command
        MIDIOUT_BUILD_COMMAND cmd
        mov eax, [edi+ecx*4]
        inc ecx
        cmp ecx, SAMARY_LENGTH
        jae all_done
    have_neg:
        and eax, [edi+ecx*4]
        jns got_pos
        inc ecx
        cmp ecx, SAMARY_LENGTH
        jae all_done
        and eax, [edi+ecx*4]
        jns got_pos
        inc ecx
        cmp ecx, SAMARY_LENGTH
        jb have_neg
        jmp all_done

    ENDM


MIDIOUT_TRIGGERED_BOTH  MACRO cmd:REQ

    LOCAL top_of_loop, got_trigger

    top_of_loop:
        xor eax, [edi+ecx*4]
        js got_trigger
        mov eax, [edi+ecx*4]
        inc ecx
        cmp ecx, SAMARY_LENGTH
        jae all_done
        xor eax, [edi+ecx*4]
        js got_trigger
        mov eax, [edi+ecx*4]
        inc ecx
        cmp ecx, SAMARY_LENGTH
        jb top_of_loop
        jmp all_done
    got_trigger:
        MIDIOUT_BUILD_COMMAND cmd
        mov eax, [edi+ecx*4]
        inc ecx
        cmp ecx, SAMARY_LENGTH
        jb top_of_loop
        jmp all_done

    ENDM



;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////


.CODE

ASSUME_AND_ALIGN
midiout_Calc    PROC USES ebp

        ASSUME esi:PTR MIDIOUT_OSC_MAP

    ;// calc will build all commands and send to the s0 stream
    ;// if object has device output, then send that stream to the device

    ;// don't do bad modes

        mov eax, [esi].dwUser
        test eax, MIDIOUT_OUTPUT_TEST
        jz all_done_for_real

    ;// always xfer si to so
    ;// this resets the stream as well

        xor edx, edx
        midistream_Reset [esi].stream, edx  ;// reset the output stream
        xor edi, edi
        xor ecx, ecx

        OR_GET_PIN [esi].pin_si.pPin, edi   ;// see if we have an input stream
        .IF !ZERO?

            mov edi, [edi].pData    ;// point at it
            ASSUME edi:PTR MIDI_STREAM_ARRAY    ;// edi is source stream

            ;// start iterating the source stream
            midistream_IterBegin [edi], ecx, stream_copy_done
        stream_copy_top:

            ;// copy event from source to dest
            midistream_Append [esi].stream, ecx
            mov eax, [edi+ecx*8].evt            ;// get event from source
            mov [esi].stream[ecx*8].evt, eax    ;// put event in dest
            ;// next source event
            midistream_IterNext [edi], ecx, stream_copy_top
        stream_copy_done:
            ;// reset registers
            xor edi, edi
            xor ecx, ecx
            mov eax, [esi].dwUser
        .ENDIF

    ;// determine which operating mode we're in

        and eax, MIDIOUT_INPUT_TEST
        BITSHIFT eax, MIDIOUT_PORT_CLOCK, 1
        xor ebx, ebx    ;// ebx often points at pins
        mov eax, midiout_calc_jump_table[eax*4]
        xor ebp, ebp    ;// ebp often points at data
        jmp eax




;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////

ALIGN 16
calc_MIDIOUT_PORT_STREAM::  ;// 0 s1    mix si with s1


    ;// get the s1 stream, abort if not connected

        OR_GET_PIN [esi].pin_N.pPin, ebx
        jz all_done
        mov ebx, [ebx].pData
        ASSUME ebx:PTR MIDI_STREAM_ARRAY

    ;// start iterating the source stream

        midistream_IterBegin [ebx], ecx, all_done
        lea edi, [esi].stream

    stream_merge_top:

        ;// copy event from source to dest
        invoke midistream_Insert, edi, ecx, [ebx+ecx*8].evt ;// call common insert function
        ;// next source event
        midistream_IterNext [ebx], ecx, stream_merge_top

        jmp all_done

;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////

ALIGN 16
calc_MIDIOUT_PORT_CLOCK::   ;// 1 Vt    tick start stop continue

    ;// for this routine, we pre check the first sample as required
    ;// previous samples are stored in pin_V.dwUser and pin_t.dwUser
    ;// we transfer the previous samples while we test the first one
    ;// then jump into 1 of 3 routines that compare prev sample with current
    ;// ebp is V
    ;// edi is t
    ;//
    ;// pre test sequence:
    ;//
    ;// nV ?
    ;//         nt  ?   --> EXIT
    ;//         check_first_t
    ;//         st  ?   --> EXIT
    ;//         dt      --> CLOCK_dt
    ;//
    ;// check_first_V
    ;// nt ?
    ;//         sV ?    --> EXIT
    ;//         dV      --> CLOCK_dV
    ;// check_first_t
    ;// st ?
    ;//         sV  ?   --> EXIT
    ;//         dV      --> CLOCK dV
    ;// dt ?
    ;//         sV  ?   --> CLOCK_dt
    ;//         dV      --> CLOCK_dVdt

        mov ecx, 1  ;// when we jump, we'll start at the first sample

        ;// nV ?
        OR_GET_PIN [esi].pin_V.pPin, ebp
        .IF ZERO?

            OR_GET_PIN [esi].pin_t.pPin, ebx            ;// nt  ?   --> EXIT
            jz all_done
            ;// check_first_t
            mov edi, [ebx].pData
            ASSUME edi:PTR DWORD

                mov eax, [esi].pin_t.dwUser ;// get previous input
                mov edx, [edi+LAST_SAMPLE]  ;// get the new previous input
                xor eax, [edi]              ;// test the sign with the first sample
                mov [esi].pin_t.dwUser, edx ;// store the new previous input
                .IF SIGN?       ;// got a clock event
                    invoke midistream_Insert, ADDR [esi].stream, 0, MIDI_FLOAT_PORT_CLOCK
                .ENDIF

            test [ebx].dwStatus, PIN_CHANGING           ;// st  ?   --> EXIT
            jz all_done
            jmp CLOCK_dt                                ;// dt      --> CLOCK_dt

        .ENDIF
        ;// sV or dV
        ;// check_first_V (use edi for data)
        mov edi, [ebp].pData

            mov eax, [esi].pin_V.dwUser ;// get previous input
            mov edx, [edi+LAST_SAMPLE]  ;// get the new previous input
            xor eax, [edi]              ;// test the sign with the first sample
            mov [esi].pin_V.dwUser, edx ;// store the new previous input
            .IF SIGN?   ;// got a start or stop event

                and eax, [edi]  ;// sign bit is currently on
                mov eax, MIDI_FLOAT_PORT_STOP
                .IF SIGN?
                mov eax, MIDI_FLOAT_PORT_START
                .ENDIF
                invoke midistream_Insert, ADDR [esi].stream, 0, eax

            .ENDIF

        ;// nt ?
        OR_GET_PIN [esi].pin_t.pPin, ebx
        .IF ZERO?
            test [ebp].dwStatus, PIN_CHANGING   ;// sV ?    --> EXIT
            jz all_done
            mov ebp, [ebp].pData                ;// dV      --> CLOCK_dV
            jmp CLOCK_dV
        .ENDIF
        mov edi, [ebx].pData

        ;// check_first_t
        mov eax, [esi].pin_t.dwUser ;// get previous input
        mov edx, [edi+LAST_SAMPLE]  ;// get the new previous input
        xor eax, [edi]              ;// test the sign with the first sample
        mov [esi].pin_t.dwUser, edx ;// store the new previous input
        .IF SIGN?                   ;// got a clock event
            invoke midistream_Insert, ADDR [esi].stream, 0, MIDI_FLOAT_PORT_CLOCK
        .ENDIF

        test [ebx].dwStatus, PIN_CHANGING       ;// st ?
        .IF ZERO?
            test [ebp].dwStatus, PIN_CHANGING   ;// sV  ?   --> EXIT
            jz all_done
            mov ebp, [ebp].pData                ;// dV      --> CLOCK_dV
            jmp CLOCK_dV
        .ENDIF
        ;// dt
        test [ebp].dwStatus, PIN_CHANGING       ;// sV  ?   --> CLOCK_dt
        jz CLOCK_dt
        mov ebp, [ebp].pData                    ;// dV      --> CLOCK_dVdt
        jmp CLOCK_dVdt


    ;/////////////////////////////////////////////
    ALIGN 16
    CLOCK_dt:

        ;// check for t
        mov eax, [edi+ecx*4-4]      ;// get previous sample
        xor eax, [edi+ecx*4]        ;// test with current sample
        js CLOCK_dt_got_clock       ;// jump if trigger
    CLOCK_dt_next_input:
        ;// next sample
        inc ecx
        cmp ecx, SAMARY_LENGTH
        jb CLOCK_dt
        jmp all_done

    ALIGN 16
    CLOCK_dt_got_clock:

        mov edx, ecx
        shr edx, 1
        invoke midistream_Insert, ADDR [esi].stream, edx, MIDI_FLOAT_PORT_CLOCK
        jmp CLOCK_dt_next_input

    ;/////////////////////////////////////////////
    ALIGN 16
        ASSUME ebp:PTR DWORD
    CLOCK_dV:
        ;// check for V
        mov eax, [ebp+ecx*4-4]      ;// get previous sample
        xor eax, [ebp+ecx*4]        ;// test with current sample
        js CLOCK_dV_got_start_stop;// jump if trigger
    CLOCK_dV_next_input:
        ;// next sample
        inc ecx
        cmp ecx, SAMARY_LENGTH
        jb CLOCK_dV
        jmp all_done

    ALIGN 16
    CLOCK_dV_got_start_stop:

        mov eax, [ebp+ecx*4]        ;// get the V value
        test eax, eax               ;// check if pos or neg
        mov eax, MIDI_FLOAT_PORT_STOP
        mov edx, ecx
        .IF SIGN?
        mov eax, MIDI_FLOAT_PORT_START
        .ENDIF

        shr edx, 1
        invoke midistream_Insert, ADDR [esi].stream, edx, eax
        jmp CLOCK_dV_next_input


    ;/////////////////////////////////////////////
    ALIGN 16
        ASSUME ebp:PTR DWORD
    CLOCK_dVdt:
        ;// check for V
        mov eax, [ebp+ecx*4-4]      ;// get previous sample
        xor eax, [ebp+ecx*4]        ;// test with current sample
        js CLOCK_dVdt_got_start_stop;// jump if trigger

    CLOCK_dVdt_check_trigger:
        ;// check for t
        mov eax, [edi+ecx*4-4]      ;// get previous sample
        xor eax, [edi+ecx*4]        ;// test with current sample
        js CLOCK_dVdt_got_clock     ;// jump if trigger

    CLOCK_dVdt_next_input:
        ;// next sample
        inc ecx
        cmp ecx, SAMARY_LENGTH
        jb CLOCK_dVdt
        jmp all_done

    ALIGN 16
    CLOCK_dVdt_got_start_stop:

        mov eax, [ebp+ecx*4]        ;// get the V value
        test eax, eax               ;// check if pos or neg
        mov eax, MIDI_FLOAT_PORT_STOP
        mov edx, ecx
        .IF SIGN?
        mov eax, MIDI_FLOAT_PORT_START
        .ENDIF

        shr edx, 1
        invoke midistream_Insert, ADDR [esi].stream, edx, eax

        jmp CLOCK_dVdt_check_trigger

    ALIGN 16
    CLOCK_dVdt_got_clock:

        mov edx, ecx
        shr edx, 1
        invoke midistream_Insert, ADDR [esi].stream, edx, MIDI_FLOAT_PORT_CLOCK
        jmp CLOCK_dVdt_next_input


;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////

    MIDIOUT_TRIGGERED_SCAN  MACRO   mode:REQ

        ;// allowable modes are
        ;// NONE N V N_N
        ;// mode = N grabs N values from pin_N  ( in ebp )
        ;// mode = V grabs V values from pin_V  ( in ebp )
        ;// mode = N_V grabs both (ebx is N data)

    LOCAL emit_first_command
    LOCAL check_changing

        OR_GET_PIN [esi].pin_t.pPin, ebx
        jz all_done

        mov edi, [ebx].pData
        ASSUME edi:PTR DWORD    ;// t data

        IFDIF <mode>,<NONE>

            IFIDN <mode>,<N>
            GET_PIN [esi].pin_N.pPin, ebp
            ELSE
            GET_PIN [esi].pin_V.pPin, ebp
            ENDIF
            .IF ebp
                mov ebp,[ebp].pData
            .ELSE
                mov ebp, math_pNull
            .ENDIF
            ASSUME ebp:PTR DWORD    ;// V data

            IFIDN <mode>,<N_V>

                mov ebx, [esi].pin_N.pPin
                .IF ebx
                    mov ebx,[ebx].pData
                .ELSE
                    mov ebx, math_pNull
                .ENDIF
                ASSUME ebx:PTR DWORD    ;// N data

            ENDIF

        ENDIF

    ;// always check last frame value against new
    ;// store new last value while we're at it

        mov edx, [edi+LAST_SAMPLE]
        mov eax, [esi].pin_t.dwUser
        xor ecx, ecx
        mov [esi].pin_t.dwUser, edx
        .IF eax != [edi]

        ;// may need to emit a command on the first sample

            ;// there are three flavours of this trigger test
            ;// we account for them here

            .IF [esi].dwUser & MIDIOUT_TRIG_EDGE_POS

                test eax, eax                   ;// are we POS now ?
                jns check_changing
                and eax, [edi]                  ;// are we going to be POS ?
                js check_changing
                jmp emit_first_command

            .ENDIF

            .IF [esi].dwUser & MIDIOUT_TRIG_EDGE_NEG

                test eax, eax                   ;// are we NEG now ?
                js check_changing
                or eax, [edi]                   ;// are we going to be NEG ?
                jns check_changing
                jmp emit_first_command

            .ENDIF

            ; MIDIOUT_TRIG_EDGE_BOTH

                xor eax, [edi]      ;// get the sign
                jns check_changing

        emit_first_command:

            ;// got a trigger, emit the command

            MIDIOUT_BUILD_COMMAND mode

        .ENDIF

    ;// if trigger is not changing, then we're done

    check_changing:

        mov edx, [esi].pin_t.pPin
        test (APIN PTR [edx]).dwStatus, PIN_CHANGING
        jz all_done

    ;// otherwise we need to scan for trigger data

        mov eax, [edi]  ;// get the first sample
        inc ecx         ;// we;ve already checked the first sample

        ;// there are three flavours of this trigger test
        ;// we account for them here

        .IF [esi].dwUser & MIDIOUT_TRIG_EDGE_POS
            MIDIOUT_TRIGGERED_POS mode
        .ENDIF
        .IF [esi].dwUser & MIDIOUT_TRIG_EDGE_NEG
            MIDIOUT_TRIGGERED_NEG mode
        .ENDIF

        ; MIDIOUT_TRIG_EDGE_BOTH
            MIDIOUT_TRIGGERED_BOTH  mode

    ENDM



ALIGN 16
calc_MIDIOUT_PORT_RESET::   ;// 2 t     reset events
calc_MIDIOUT_CHAN_PATCH::   ;// 4 t patch changes(need to chose patch)

        MIDIOUT_TRIGGERED_SCAN  NONE

ALIGN 16
calc_MIDIOUT_CHAN_PATCH_N:: ;// 4 Nt    patch changes(need to chose patch)


        MIDIOUT_TRIGGERED_SCAN  N

ALIGN 16
calc_MIDIOUT_NOTE_ON::      ;// A NVt   note on events
calc_MIDIOUT_NOTE_OFF::     ;// B NVt   note off events
calc_MIDIOUT_NOTE_PRESS::   ;// 9 NVt   note pressure events
calc_MIDIOUT_CHAN_CTRLR_N:: ;// 8 NVt   controller events

        MIDIOUT_TRIGGERED_SCAN N_V



;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////


    ;// continous scan
    ;// we do not want to insert more than 16 events per frame

    MIDIOUT_CONTINOUS_EVENTS_PER_FRAME  EQU 16

    ;// now that we know that, we can iterate ecx so it will equal the STREAM index

    MIDIOUT_CONTINOUS_INCREMENT EQU SAMARY_LENGTH / MIDIOUT_CONTINOUS_EVENTS_PER_FRAME / 2
    MIDIOUT_CONTINOUS_LAST_SAMPLE EQU (MIDIOUT_CONTINOUS_EVENTS_PER_FRAME-1)*8*MIDIOUT_CONTINOUS_INCREMENT

    ;// this macro is used in the next three sections

    MIDIOUT_CONTINOUS_SCAN MACRO mode:req

        ;// mode states where the data will be placed in the command
        ;// it may be N V or WHEEL

        ;// since we only need one pin
        ;//     we can check changing every increment

        OR_GET_PIN [esi].pin_V.pPin, ebx    ;// get the input pin
        .IF ZERO?                   ;// if not connected, make sure
            mov ebx, math_pNullPin  ;// last_V gets zeroed (nice touch)
        .ENDIF
        mov edi, [ebx].pData        ;// point at data
        ASSUME edi:PTR DWORD

        mov edx, [edi+MIDIOUT_CONTINOUS_LAST_SAMPLE];// last sample we'll ever see
        mov eax, [esi].pin_V.dwUser ;// get last sample from previous frame
        xor ecx, ecx                ;// start at sample zero
        mov [esi].pin_V.dwUser, edx ;// store last sample

        mov ebx, [ebx].dwStatus     ;// get status for faster testing
        ASSUME ebx:NOTHING
        and ebx, PIN_CHANGING       ;// ebx is zero if not changing

        .REPEAT

            ;// eax has the previous value
            .IF eax != [edi+ecx*8]      ;// is the sample value different ?

                ;// scale the value to a midi number
                fld [edi+ecx*8]         ;// load the sample value
                IFDIF <mode>,<WHEEL>;// number is a 7 bit value
                    fabs                    ;// make sure positive
                    fmul math_128           ;// scale to midi
                    fistp midiout_temp_V    ;// store in temp

                    mov edx, midiout_temp_V ;// get the value
                    .IF edx & 0FFFFFF80h    ;// check for overflow
                        mov edx, 7Fh        ;// saturate
                    .ENDIF
                ELSE                 ;// number is a signed 14 bit value
                    fmul math_8192          ;// scale to midi (1/2 full range)
                    mov edx, 2000h          ;// load what to add now (while multiplier is busy)
                    fistp midiout_temp_V        ;// store scaled value
                    add edx, midiout_temp_V ;// add it to the center
                    .IF SIGN?           ;// underflow ?
                        xor edx, edx        ;// saturate
                    .ELSEIF edx > 4000h ;// overflow ?
                        mov edx, 3FFFh      ;// saturate
                    .ENDIF
                ENDIF

                ;// is the vale different from the old ?
                .IF edx != [esi].midiout.last_V

                    mov [esi].midiout.last_V, edx   ;// store for future testing
                    mov eax, [esi].midiout.command  ;// get the command

                    IFIDN <mode>,<V>
                    ELSEIFIDN <mode>,<N>
                        shl edx, 8                      ;// scoot edx into place
                    ELSEIFIDN <mode>,<WHEEL>
                        shl edx, 1
                        shr dl, 1
                        xchg dl, dh
                    ELSE
                        .ERR <bad MODE value!!!>
                    ENDIF
                    or eax, edx                     ;// build the full command
                    invoke midistream_Insert, ADDR [esi].stream, ecx, eax

                .ENDIF

            .ENDIF

            test ebx, ebx           ;// if ebx is not changing, we're done
            mov eax, [edi+ecx*8]    ;// get the sample to test in next iteration
            jz all_done             ;// exit if done
            add ecx, MIDIOUT_CONTINOUS_INCREMENT                ;// advance ecx

        .UNTIL ecx >= MIDI_STREAM_LENGTH

        jmp all_done

        ENDM



;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////

ALIGN 16
calc_MIDIOUT_CHAN_PRESS::   ;// 5 V channel pressure

        MIDIOUT_CONTINOUS_SCAN  N

ALIGN 16
calc_MIDIOUT_CHAN_WHEEL::   ;// 6 V pitch wheel

        MIDIOUT_CONTINOUS_SCAN  WHEEL

ALIGN 16
calc_MIDIOUT_CHAN_CTRLR::   ;// 7 V controller events (need to choose controller)

        MIDIOUT_CONTINOUS_SCAN  V

;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////


;///////////////////////////////////////////////
;//
;// MIDIOUT_TRACK
;//




comment ~ /*


    we have two tracker modes
    one relies on t
    the other relies on N

TRACK_N

    / dN dV \   4 modes
    \ sN sV /

    if N has changed enough to emit a new note
        turn off old note
        turn on new note
    else if note is on AND V has changed enough to emit a new pressure
        emit a pressure event
    endif


TRACK_t

    / dV dt \   4 modes
    \ sV st /

    if t has changed pos to neg
        store new N
        emit note on for new N
    else if t has changed from neg to pos
        if stored N
            emit note off for stored N
            zero stored N
        endif
    else if stored N AND V has changed enough to emit a pressure event
        emit a pressuer event for stored N
    endif

*/ comment ~



    MIDIOUT_TRACK_N MACRO   mode:REQ

    ;// jmp labels
    LOCAL   top_of_loop,check_V
    LOCAL   V_sample_changed,V_note_is_on,V_note_is_off
    LOCAL   N_sample_changed,N_emit_new_note
    ;// configuration values
    LOCAL   TEST_N, TEST_V
    LOCAL   EXIT_N, ALIGN_N

    ;// ebx = N input data
    ;// ebp = V input data
    ;// mode tells us what to look at

    ;// the next loop is designed for sparse changes
    ;// fall through assumes sample has not changed
    ;//
    ;//     loop
    ;//         test_N  jmp if different
    ;//         test_V  jmp if different
    ;//     repeat
    ;//     handle V
    ;//     handle N

        ;// to implement the modes, we need some configuration values

        IFIDN       <mode>,<N>
            TEST_N = 1
            TEST_V = 0
        ELSEIFIDN   <mode>,<V>
            TEST_N = 0
            TEST_V = 1
        ELSEIFIDN   <mode>,<NV>
            TEST_N = 1
            TEST_V = 1
        ELSE
        .ERR <invalid paramer>
        ENDIF

        ALIGN_N TEXTEQU <>

        IF TEST_V
            EXIT_N  TEXTEQU <check_V>   ;// exit to V if same
            ALIGN_N TEXTEQU <ALIGN 16>
        ELSE
            EXIT_N TEXTEQU <top_of_loop>;// exit to top if same number
        ENDIF

    ;/////////////////////////////////////////////////////////////////////

        DEBUG_IF <ecx>  ;// supposed to be zero !!

    top_of_loop:

        ;// iterate first   (already took care of first sample)

            inc ecx
            cmp ecx, SAMARY_LENGTH
            jae all_done

    IF TEST_N
            ;// test N
            ;// don't send too many events ???
            test ecx, 0Fh   ;// max of 16
            jnz top_of_loop

            mov eax, [ebx+ecx*4]        ;// load N sample value
            cmp eax, [esi].pin_N.dwUser ;// cmp with previous
        IF TEST_V
            jne N_sample_changed
        ELSE
            je top_of_loop  ;// no V, fall through is N_sample_changed
        ENDIF
    ENDIF

    ;//////////////////////////////////////////////////////////////////
    IF TEST_V

        check_V:    ;// test V

        ;// if note is off, we don't do anything

            test [esi].midiout.last_t, -1
            je top_of_loop

        ;// don't send too many pressure events

            test ecx, 0Fh   ;// max of 16
            jnz top_of_loop

        ;// check the new sample

            mov eax, [ebp+ecx*4]
            cmp eax, [esi].pin_V.dwUser
            je top_of_loop

    ;/////////////////////////////////////////

        V_sample_changed:

        ;// we MAY have a new value

            fld [ebp+ecx*4]             ;// load the new V sample
            fabs
            fmul math_128
            mov [esi].pin_V.dwUser, eax ;// store new V sample
            fistp midiout_temp_V        ;// store in temp_V
            mov eax, midiout_temp_V     ;// retrieve temp_V
            cmp eax, [esi].midiout.last_V;// see if different
            je top_of_loop              ;// exit of same

        ;// we MAY have a new value

            .IF eax & 0FFFFFF80h    ;// check for overflow
                mov eax, 7Fh
                cmp eax, [esi].midiout.last_V
                je top_of_loop
            .ENDIF

        ;// we DO have a new value
        ;// and we've already checked that we are on
        ;// eax has the new value

            mov edx, [esi].midiout.last_N   ;// get the number
            mov [esi].midiout.last_V, eax   ;// always store
            shl edx, 8
            or eax, edx
            mov edx, [esi].midiout.channel
            or eax, MIDI_FLOAT_PRESSURE
            shl edx, 16

            or eax, edx

            mov edx, ecx
            shr edx, 1

            invoke midistream_Insert, ADDR [esi].stream, edx, eax

            jmp top_of_loop


    ENDIF   ;// TEST_V

;//////////////////////////////////////////////////////////////////
    IF TEST_N

        ALIGN_N
        N_sample_changed:   ;// MAY have a new note
                            ;// eax has N sample value

            fld [ebx+ecx*4]             ;// load the N sample
            fabs                        ;// make sure positive
            fmul math_128               ;// scale to midi
            mov [esi].pin_N.dwUser, eax ;// store new sample N
            mov eax, [esi].midiout.last_N   ;// get last N
            fistp midiout_temp_N        ;// store new midi N in temp
            mov edx, midiout_temp_N
            cmp eax, midiout_temp_N     ;// same ??
            je EXIT_N                   ;// exit to next test if same

        ;// we MAY have a new number

            .IF edx & 0FFFFFF80h    ;// check for overflow in new sample
                mov edx, 7Fh
                mov midiout_temp_N, 7Fh
                cmp eax, edx        ;// same ??
                je EXIT_N
            .ENDIF

        ;// we DO have a new number

            ;// if we are on now, we want to emit note off
            ;// eax already has the previous number
            test [esi].midiout.last_t, -1
            jz N_emit_new_note

        ;// emit the old note off
        ;// use value 0 to do so

            mov eax, [esi].midiout.last_N
            shl eax, 8
            mov edx, [esi].midiout.channel
            or eax, MIDI_FLOAT_NOTEOFF
            shl edx, 16
            or eax, edx

            mov edx, ecx
            shr edx, 1
            invoke midistream_Insert, ADDR [esi].stream, edx, eax

        N_emit_new_note:

            ;// emit the new note on
            ;// use new V to do so
            ;// midiout_temp_N has the new N

            mov edx, [ebp+ecx*4]        ;// get the new V sample
            mov [esi].pin_V.dwUser, edx ;// store in V dwUser

            fld [ebp+ecx*4]             ;// load the new V sample
            fabs                        ;// make sure positive
            fmul math_128               ;// scale to midi
            fistp [esi].midiout.last_V  ;// store as last_V

            ;// xfer new N to last_N

            mov eax, midiout_temp_N
            mov [esi].midiout.last_N, eax

            ;// check for V overflow

            mov edx, [esi].midiout.last_V
            .IF edx & 0FFFFFF80h
                mov edx, 7Fh
                mov [esi].midiout.last_V, 7Fh
            .ENDIF

            ;// build the note on command
            ;// eax=N edx=V

            shl eax, 8
            or eax, edx
            mov edx, [esi].midiout.channel
            or eax, MIDI_FLOAT_NOTEON
            shl edx, 16

            or eax, edx

            mov edx, ecx
            shr edx, 1
            invoke midistream_Insert, ADDR [esi].stream, edx, eax

            mov [esi].midiout.last_t, -1    ;// set
            jmp top_of_loop

    ENDIF   ;// TEST_N


        ENDM






ALIGN 16
calc_MIDIOUT_NOTE_TRACK_N:: ;// C NV    state of NV

    ;// when the state changes
    ;// build and send appropriate command
    ;// see MIDIOUT_TRACK_N for details

    ;// determine connection state

        xor ecx, ecx    ;// build dN dV dt bits in ecx

    ;// N --> ebx

        xor eax, eax    ;// no big small stalls here
        OR_GET_PIN [esi].pin_N.pPin, ebx
        .IF ZERO?
            mov ebx, math_pNull
        .ELSE
            test [ebx].dwStatus, PIN_CHANGING
            mov ebx, [ebx].pData
            setnz al
        .ENDIF
        ASSUME ebx:PTR DWORD
        shr al, 1
        adc ecx, ecx

    ;// V --> ebp

        OR_GET_PIN [esi].pin_V.pPin, ebp
        .IF ZERO?
            mov ebp, math_pNull
        .ELSE
            test [ebp].dwStatus, PIN_CHANGING
            mov ebp, [ebp].pData
            setnz al
        .ENDIF
        ASSUME ebp:PTR DWORD
        shr al, 1
        adc ecx, ecx

    ;// t --> edi

        OR_GET_PIN [esi].pin_t.pPin, edi
        .IF ZERO?
            mov edi, math_pNull
        .ELSE
            test [edi].dwStatus, PIN_CHANGING
            mov edi, [edi].pData
            setnz al
        .ENDIF
        ASSUME edi:PTR DWORD

    ;// save the exit jump

        push TRACK_N_calc_jump[ecx*4]   ;// we can either ret or load from stack
        xor ecx, ecx        ;// ecx must be zero index

    ;// take care of the first samples
    ;// jump to appropriate handler

        ;// test N

            mov eax, [ebx]      ;// load N sample value
            cmp eax, [esi].pin_N.dwUser ;// cmp with previous
            jne track_N_N_sample_changed

        track_N_check_V:;// test V

        ;// if note is off, we don't do anything

            test [esi].midiout.last_t, -1
            jnz track_N_check_V_on

        track_N_first_sample_done:  ;// keep this above the rest to catch predicted taken
                            ;// should possibly align as well
            pop eax
            jmp eax

        ;// check the new V sample
        track_N_check_V_on:

            mov eax, [ebp]
            cmp eax, [esi].pin_V.dwUser
            je track_N_first_sample_done

        track_N_V_sample_changed:
        ;// we MAY have a new value

            fld [ebp]               ;// load the new V sample
            fabs
            fmul math_128
            mov [esi].pin_V.dwUser, eax ;// store new V sample
            fistp midiout_temp_V        ;// store in temp_V
            mov eax, midiout_temp_V     ;// retrieve temp_V
            cmp eax, [esi].midiout.last_V;// see if different
            je track_N_first_sample_done        ;// exit of same

        ;// we MAY have a new value

            .IF eax & 0FFFFFF80h    ;// check for overflow
                mov eax, 7Fh
                cmp eax, [esi].midiout.last_V
                je track_N_first_sample_done
            .ENDIF

        ;// we DO have a new value
        ;// and we've already checked that we are on
        ;// eax has the new value

            mov edx, [esi].midiout.last_N   ;// get the number
            mov [esi].midiout.last_V, eax   ;// always store
            shl edx, 8
            or eax, edx
            mov edx, [esi].midiout.channel
            or eax, MIDI_FLOAT_PRESSURE
            shl edx, 16

            or eax, edx

            invoke midistream_Insert, ADDR [esi].stream, 0, eax

            ;// jmp first_sample_done
            pop eax
            jmp eax

        ALIGN 16
        track_N_N_sample_changed:   ;// MAY have a new note
                            ;// eax has N sample value

            fld [ebx]               ;// load the N sample
            fabs                        ;// make sure positive
            fmul math_128               ;// scale to midi
            mov [esi].pin_N.dwUser, eax ;// store new sample N
            mov eax, [esi].midiout.last_N   ;// get last N
            fistp midiout_temp_N        ;// store new midi N in temp
            mov edx, midiout_temp_N
            cmp eax, midiout_temp_N     ;// same ??
            je track_N_check_V                  ;// exit to next test if same

        ;// we MAY have a new number

            .IF edx & 0FFFFFF80h    ;// check for overflow in new sample
                mov edx, 7Fh
                mov midiout_temp_N, 7Fh
                cmp eax, edx        ;// same ??
                je track_N_check_V
            .ENDIF

        ;// we DO have a new number

            ;// if we are on now, we want to emit note off
            ;// eax already has the previous number
            test [esi].midiout.last_t, -1
            jz track_N_N_emit_new_note

        ;// emit the old note off
        ;// use value 0 to do so

            mov eax, [esi].midiout.last_N
            shl eax, 8
            mov edx, [esi].midiout.channel
            or eax, MIDI_FLOAT_NOTEOFF
            shl edx, 16

            or eax, edx
            invoke midistream_Insert, ADDR [esi].stream, 0, eax

        track_N_N_emit_new_note:

            ;// emit the new note on
            ;// use new V to do so
            ;// midiout_temp_N has the new N

            mov edx, [ebp]      ;// get the new V sample
            mov [esi].pin_V.dwUser, edx ;// store in V dwUser

            fld [ebp]               ;// load the new V sample
            fabs                        ;// make sure positive
            fmul math_128               ;// scale to midi
            fistp [esi].midiout.last_V  ;// store as last_V

            ;// xfer new N to last_N

            mov eax, midiout_temp_N
            mov [esi].midiout.last_N, eax

            ;// check for V overflow

            mov edx, [esi].midiout.last_V
            .IF edx & 0FFFFFF80h
                mov edx, 7Fh
                mov [esi].midiout.last_V, 7Fh
            .ENDIF

            ;// build the note on command
            ;// eax=N edx=V

            shl eax, 8
            or eax, edx
            mov edx, [esi].midiout.channel
            or eax, MIDI_FLOAT_NOTEON
            shl edx, 16

            or eax, edx

            invoke midistream_Insert, ADDR [esi].stream, 0, eax

            mov [esi].midiout.last_t, -1    ;// set
            ;// jmp first_sample_done
            pop eax
            jmp eax


;/////////////////////////////////////////////////////

ALIGN 16
TRACK_N_calc_dNdV:: MIDIOUT_TRACK_N NV
ALIGN 16
TRACK_N_calc_dNsV:: MIDIOUT_TRACK_N N
ALIGN 16
TRACK_N_calc_sNdV:: MIDIOUT_TRACK_N V


















    MIDIOUT_TRACK_t MACRO   mode:REQ

    ;// jmp labels
    LOCAL   top_of_loop,check_t,check_V
    LOCAL   V_sample_changed,V_note_is_on,V_note_is_off
    LOCAL   t_sign_changed,t_went_on,t_emit_note_on,t_went_off
    ;// configuration values
    LOCAL   TEST_T, TEST_V
    LOCAL   ALIGN_t

    ;// ebx = N input data
    ;// ebp = V input data
    ;// edi = t input data
    ;// mode tells us what to look at

    ;// the next loop is designed for sparse changes
    ;// fall through assumes sample has not changed
    ;//
    ;//     loop
    ;//         test_t  jmp if different
    ;//         test_V  jmp if different
    ;//     repeat
    ;//     handle V
    ;//     handle t

        ;// to implement the 3 modes, we need some configuration values

        IFIDN       <mode>,<V>
            TEST_T = 0
            TEST_V = 1
        ELSEIFIDN   <mode>,<t>
            TEST_T = 1
            TEST_V = 0
        ELSEIFIDN   <mode>,<Vt>
            TEST_T = 1
            TEST_V = 1
        ELSE
        .ERR <invalid paramer>
        ENDIF

        ALIGN_t TEXTEQU <>

        IF TEST_V
            ALIGN_t TEXTEQU <ALIGN 16>
        ENDIF

    ;/////////////////////////////////////////////////////////////////////

        DEBUG_IF <ecx>  ;// supposed to be zero !!

    top_of_loop:

        ;// iterate first   (already took care of first sample)

            inc ecx
            cmp ecx, SAMARY_LENGTH
            jae all_done

    IF TEST_T
        check_t:    ;// test t

            mov eax, [esi].pin_t.dwUser
            xor eax, [edi+ecx*4]
        IF TEST_V
            js t_sign_changed
        ELSE
            jns top_of_loop ;// no V , fall through is t_sign_changed
        ENDIF
    ENDIF

    ;//////////////////////////////////////////////////////////////////
    IF TEST_V

        check_V:    ;// test V

        ;// if note is off, we don't do anything

            test [esi].midiout.last_t, -1
            je top_of_loop

        ;// don't send too many pressure events

            test ecx, 0Fh   ;// max of 16
            jnz top_of_loop

        ;// check the new sample

            mov eax, [ebp+ecx*4]
            cmp eax, [esi].pin_V.dwUser
            je top_of_loop

    ;/////////////////////////////////////////

        V_sample_changed:

        ;// we MAY have a new value

            fld [ebp+ecx*4]             ;// load the new V sample
            fabs
            fmul math_128
            mov [esi].pin_V.dwUser, eax ;// store new V sample
            fistp midiout_temp_V        ;// store in temp_V
            mov eax, midiout_temp_V     ;// retrieve temp_V
            cmp eax, [esi].midiout.last_V;// see if different
            je top_of_loop              ;// exit of same

        ;// we MAY have a new value

            .IF eax & 0FFFFFF80h    ;// check for overflow
                mov eax, 7Fh
                cmp eax, [esi].midiout.last_V
                je top_of_loop
            .ENDIF

        ;// we DO have a new value
        ;// and we've already checked that we are on
        ;// eax has the new value

            mov edx, [esi].midiout.last_N   ;// get the number
            mov [esi].midiout.last_V, eax   ;// always store
            shl edx, 8
            or eax, edx
            mov edx, [esi].midiout.channel
            or eax, MIDI_FLOAT_PRESSURE
            shl edx, 16

            or eax, edx

            mov edx, ecx
            shr edx, 1

            invoke midistream_Insert, ADDR [esi].stream, edx, eax

            jmp top_of_loop


    ENDIF   ;// TEST_V

    ;//////////////////////////////////////////////////////////////////

    IF TEST_T

        ALIGN_t
        t_sign_changed:     ;// t has changed signs

        ;// check on or off

            mov eax, [edi+ecx*4]        ;// get the new sample
            test eax, eax               ;// see if pos or neg
            mov [esi].pin_t.dwUser, eax ;// store the new last sample
            jns t_went_off

        t_went_on:

            ;// got a note on event

            test [esi].midiout.last_t, -1
            jz t_emit_note_on

        ;// have to emit a note off first, use zero for data
        ;// we build using the previous V value
        ;// in this macro, there will always be a previous t

            mov eax, [esi].midiout.last_N
            shl eax, 8
            mov edx, [esi].midiout.channel
            or eax, MIDI_FLOAT_NOTEOFF
            shl edx, 16

            or eax, edx

            mov edx, ecx
            shr edx, 1
            invoke midistream_Insert, ADDR [esi].stream, edx, eax

        t_emit_note_on:

            ;// emit a note on event
            ;// in the process, store new last_N, last_V, pin_N and pin_V values

            mov eax, [ebx+ecx*4]        ;// load sample N
            mov [esi].pin_N.dwUser, eax ;// store sample N in N.dwUser

            mov edx, [ebp+ecx*4]        ;// load sample V
            mov [esi].pin_V.dwUser, edx ;// store sample V in V.dwUser

            fld [ebx+ecx*4]             ;// get sample N
            fabs                        ;// make sure positive
            fmul math_128               ;// scale N to midi
            fistp [esi].midiout.last_N          ;// store N as last_N

            fld [ebp+ecx*4]             ;// get sample V
            fabs                        ;// make sure positive
            fmul math_128               ;// scale V to midi
            fistp [esi].midiout.last_V          ;// store V as last_V

            mov eax, [esi].midiout.last_N   ;// get the new midi number
            .IF eax & 0FFFFFF80h        ;// check for overflow
                mov eax, 07Fh
                mov [esi].midiout.last_N, eax
            .ENDIF

            mov edx, [esi].midiout.last_V   ;// get the new midi value
            .IF edx & 0FFFFFF80h            ;// check for overflow
                mov edx, 07Fh
                mov [esi].midiout.last_V, edx
            .ENDIF

            ;// build the command

            shl eax, 8
            or eax, edx
            mov edx, [esi].midiout.channel
            or eax, MIDI_FLOAT_NOTEON
            shl edx, 16

            or eax, edx

            mov edx, ecx
            shr edx, 1
            invoke midistream_Insert, ADDR [esi].stream, edx, eax

            mov [esi].midiout.last_t, -1    ;// set
            jmp top_of_loop

        t_went_off:

            ;// emit a note off event
            ;// store new values in the process

            mov eax, [ebx+ecx*4]        ;// load sample N
            mov [esi].pin_N.dwUser, eax ;// store sample N in N.dwUser

            mov edx, [ebp+ecx*4]        ;// load sample V
            mov [esi].pin_V.dwUser, edx ;// store sample V in V.dwUser

            fld [ebx+ecx*4]             ;// get sample N
            fabs                        ;// make sure positive
            fmul math_128               ;// scale N to midi
            fistp [esi].midiout.last_N          ;// store N as last_N

            fld [ebp+ecx*4]             ;// get sample V
            fabs                        ;// make sure positive
            fmul math_128               ;// scale V to midi
            fistp [esi].midiout.last_V          ;// store V as last_V

            mov eax, [esi].midiout.last_N   ;// get the new midi number
            .IF eax & 0FFFFFF80h        ;// check for overflow
                mov eax, 07Fh
                mov [esi].midiout.last_N, eax
            .ENDIF

            mov edx, [esi].midiout.last_V   ;// get the new midi value
            .IF edx & 0FFFFFF80h        ;// check for overflow
                mov edx, 07Fh
                mov [esi].midiout.last_V, edx
            .ENDIF

            ;// build the command

            shl eax, 8
            or eax, edx
            mov edx, [esi].midiout.channel
            or eax, MIDI_FLOAT_NOTEOFF
            shl edx, 16

            or eax, edx

            mov edx, ecx
            shr edx, 1
            invoke midistream_Insert, ADDR [esi].stream, edx, eax

            mov [esi].midiout.last_t, 0 ;// reset
            jmp top_of_loop


        ENDIF   ;// TEST_T

        ENDM








ALIGN 16
calc_MIDIOUT_NOTE_TRACK_t:: ;// C NVt   state of NVt,

    ;// when t changes
    ;// build and send appropriate command
    ;// see MIDIOUT_TRACK_t for details

    ;// determine connection state

        xor ecx, ecx    ;// build dV dt bits in ecx

    ;// N --> ebx

        OR_GET_PIN [esi].pin_N.pPin, ebx
        .IF ZERO?
            mov ebx, math_pNull
        .ELSE
            mov ebx, [ebx].pData
        .ENDIF
        ASSUME ebx:PTR DWORD

    ;// V --> ebp

        xor eax, eax    ;// no big-small stalls
        OR_GET_PIN [esi].pin_V.pPin, ebp
        .IF ZERO?
            mov ebp, math_pNull
        .ELSE
            test [ebp].dwStatus, PIN_CHANGING
            mov ebp, [ebp].pData
            setnz al
        .ENDIF
        ASSUME ebp:PTR DWORD
        shr al, 1
        adc ecx, ecx

    ;// t --> edi

        OR_GET_PIN [esi].pin_t.pPin, edi
        .IF ZERO?
            mov edi, math_pNull
        .ELSE
            test [edi].dwStatus, PIN_CHANGING
            mov edi, [edi].pData
            setnz al
        .ENDIF
        ASSUME edi:PTR DWORD
        shr al, 1
        adc ecx, ecx

    ;// save the exit jump

        push TRACK_t_calc_jump[ecx*4]   ;// we can either ret or load from stack
        xor ecx, ecx        ;// ecx must be zero index

    ;// take care of the first samples
    ;// jump to appropriate handler

        ;// test t

            mov eax, [esi].pin_t.dwUser
            xor eax, [edi]
            js track_t_t_sign_changed

        ;// test V

        ;// if note is off, we don't do anything

            test [esi].midiout.last_t, -1
            jnz track_t_check_V_on

        track_t_first_sample_done:  ;// keep this above the rest to catch predicted taken
                            ;// should possibly align as well
            pop eax
            jmp eax

        ;// check the new V sample
        track_t_check_V_on:

            mov eax, [ebp]
            cmp eax, [esi].pin_V.dwUser
            je track_t_first_sample_done

        track_t_V_sample_changed:
        ;// we MAY have a new value

            fld [ebp]               ;// load the new V sample
            fabs
            fmul math_128
            mov [esi].pin_V.dwUser, eax ;// store new V sample
            fistp midiout_temp_V        ;// store in temp_V
            mov eax, midiout_temp_V     ;// retrieve temp_V
            cmp eax, [esi].midiout.last_V;// see if different
            je track_t_first_sample_done        ;// exit of same

        ;// we MAY have a new value

            .IF eax & 0FFFFFF80h    ;// check for overflow
                mov eax, 7Fh
                cmp eax, [esi].midiout.last_V
                je track_t_first_sample_done
            .ENDIF

        ;// we DO have a new value
        ;// and we've already checked that we are on
        ;// eax has the new value

            mov edx, [esi].midiout.last_N   ;// get the number
            mov [esi].midiout.last_V, eax   ;// always store
            shl edx, 8
            or eax, edx
            mov edx, [esi].midiout.channel
            or eax, MIDI_FLOAT_PRESSURE
            shl edx, 16

            or eax, edx

            invoke midistream_Insert, ADDR [esi].stream, 0, eax

            ;// jmp first_sample_done
            pop eax
            jmp eax

        ALIGN 16
        track_t_t_sign_changed:     ;// t has changed signs

        ;// check on or off

            mov eax, [edi]      ;// get the new sample
            test eax, eax               ;// see if pos or neg
            mov [esi].pin_t.dwUser, eax ;// store the new last sample
            jns track_t_t_went_off

        track_t_t_went_on:

            ;// got a note on event

            test [esi].midiout.last_t, -1
            jz track_t_t_emit_note_on

        ;// have to emit a note off first, use zero for data
        ;// we build using the previous V value
        ;// in this macro, there will always be a previous t

            mov eax, [esi].midiout.last_N
            shl eax, 8
            mov edx, [esi].midiout.channel
            or eax, MIDI_FLOAT_NOTEOFF
            shl edx, 16

            or eax, edx
            invoke midistream_Insert, ADDR [esi].stream, 0, eax

        track_t_t_emit_note_on:

            ;// emit a note on event
            ;// in the process, store new last_N, last_V, pin_N and pin_V values

            mov eax, [ebx]      ;// load sample N
            mov [esi].pin_N.dwUser, eax ;// store sample N in N.dwUser

            mov edx, [ebp]      ;// load sample V
            mov [esi].pin_V.dwUser, edx ;// store sample V in V.dwUser

            fld [ebx]               ;// get sample N
            fabs                        ;// make sure positive
            fmul math_128               ;// scale N to midi
            fistp [esi].midiout.last_N          ;// store N as last_N

            fld [ebp]               ;// get sample V
            fabs                        ;// make sure positive
            fmul math_128               ;// scale V to midi
            fistp [esi].midiout.last_V          ;// store V as last_V

            mov eax, [esi].midiout.last_N   ;// get the new midi number
            .IF eax & 0FFFFFF80h        ;// check for overflow
                mov eax, 07Fh
                mov [esi].midiout.last_N, eax
            .ENDIF

            mov edx, [esi].midiout.last_V   ;// get the new midi value
            .IF edx & 0FFFFFF80h            ;// check for overflow
                mov edx, 07Fh
                mov [esi].midiout.last_N, edx
            .ENDIF

            ;// build the command

            shl eax, 8
            or eax, edx
            mov edx, [esi].midiout.channel
            or eax, MIDI_FLOAT_NOTEON
            shl edx, 16

            or eax, edx
            invoke midistream_Insert, ADDR [esi].stream, 0, eax

            mov [esi].midiout.last_t, -1    ;// set
            ;// jmp first_sample_done
            pop eax
            jmp eax

        track_t_t_went_off:

            ;// emit a note off event
            ;// store new values in the process

            mov eax, [ebx]      ;// load sample N
            mov [esi].pin_N.dwUser, eax ;// store sample N in N.dwUser

            mov edx, [ebp]      ;// load sample V
            mov [esi].pin_V.dwUser, edx ;// store sample V in V.dwUser

            fld [ebx]               ;// get sample N
            fabs                        ;// make sure positive
            fmul math_128               ;// scale N to midi
            fistp [esi].midiout.last_N          ;// store N as last_N

            fld [ebp]               ;// get sample V
            fabs                        ;// make sure positive
            fmul math_128               ;// scale V to midi
            fistp [esi].midiout.last_V          ;// store V as last_V

            mov eax, [esi].midiout.last_N   ;// get the new midi number
            .IF eax & 0FFFFFF80h        ;// check for overflow
                mov eax, 07Fh
                mov [esi].midiout.last_N, eax
            .ENDIF

            mov edx, [esi].midiout.last_V   ;// get the new midi value
            .IF edx & 0FFFFFF80h        ;// check for overflow
                mov edx, 07Fh
                mov [esi].midiout.last_N, edx
            .ENDIF

            ;// build the command

            shl eax, 8
            or eax, edx
            mov edx, [esi].midiout.channel
            or eax, MIDI_FLOAT_NOTEOFF
            shl edx, 16
            or eax, edx
            invoke midistream_Insert, ADDR [esi].stream, 0, eax

            mov [esi].midiout.last_t, 0 ;// reset

            pop eax
            jmp eax


;/////////////////////////////////////////////////////

ALIGN 16
TRACK_t_calc_dVdt:: MIDIOUT_TRACK_t Vt
ALIGN 16
TRACK_t_calc_dVst:: MIDIOUT_TRACK_t V
ALIGN 16
TRACK_t_calc_sVdt:: MIDIOUT_TRACK_t t




ALIGN 16
TRACK_t_calc_sVst::
TRACK_N_calc_sNsV::
all_done:

    ;// see if we have a device
    .IF [esi].pDevice
        invoke midiout_WriteInStream
    .ENDIF

calc_mode_bad::
all_done_for_real:

        ret

midiout_Calc    ENDP






ASSUME_AND_ALIGN


ENDIF   ;// USE_THIS_FILE
END



























