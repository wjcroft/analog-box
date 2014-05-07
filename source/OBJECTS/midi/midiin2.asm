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
;//                 -- changed from math_temp_1 and math_temp_2 to midiin_temp_x
;//
;//##////////////////////////////////////////////////////////////////////////
;//
;//     midiin2.asm
;//
;// TOC
;//
;// midiin_VerifyMode
;//
;// midiin_Ctor
;// midiin_Dtor
;// midiin_Render
;//
;// midiin_SaveUndo
;// midiin_LoadUndo
;//
;// midiin_InitMenu
;// midiin_Command
;//
;// midiin_PrePlay
;// midiin_Calc
;//
;// midiin_fill_Begin
;// midiin_fill_Advance
;// midiin_fill_End


OPTION CASEMAP:NONE
.586
.MODEL FLAT

    .NOLIST
    INCLUDE <ABox.inc>
    INCLUDE <midi2.inc>
    .LIST

.DATA

BASE_FLAGS = BASE_HARDWARE OR BASE_PLAYABLE OR BASE_WANT_EDIT_FOCUS_MSG


osc_MidiIn2 OSC_CORE { midiin_Ctor,midiin_Dtor,midiin_PrePlay,midiin_Calc }
            OSC_GUI  { midiin_Render,,,,,midiin_Command,midiin_InitMenu,,,midiin_SaveUndo,midiin_LoadUndo}
            OSC_HARD { midiin_H_Ctor,midiin_H_Dtor,midiin_H_Open,midiin_H_Close,midiin_H_Ready,midiin_H_Calc }

    ;// don't make lines too long
    ofsPinData  = SIZEOF OSC_OBJECT + (SIZEOF APIN)*5
    ofsOscData  = SIZEOF OSC_OBJECT + (SIZEOF APIN)*5+SAMARY_SIZE*4
    oscBytes    = SIZEOF OSC_OBJECT + (SIZEOF APIN)*5+SAMARY_SIZE*4+SIZEOF MIDIIN_DATA

    OSC_DATA_LAYOUT {NEXT_MidiIn2,IDB_MIDIIN2,OFFSET popup_MIDIIN2,
        BASE_FLAGS,5,4+MIDIIN_SAVE_LENGTH*4,
        ofsPinData,
        ofsOscData,
        oscBytes  }

    OSC_DISPLAY_LAYOUT{ devices_container, MIDIIN_PSOURCE, ICON_LAYOUT( 2,3,2,1 ) }

;// PINS

;// these are needed for xlate

EXTERNDEF osc_MidiIn2_pin_si:APIN_init
EXTERNDEF osc_MidiIn2_pin_so:APIN_init
EXTERNDEF osc_MidiIn2_pin_N:APIN_init
EXTERNDEF osc_MidiIn2_pin_V:APIN_init
EXTERNDEF osc_MidiIn2_pin_t:APIN_init

osc_MidiIn2_pin_si  APIN_init { -1.0 ,OFFSET sz_Stream,'is',, UNIT_MIDI_STREAM }    ;// stream in
osc_MidiIn2_pin_so  APIN_init { -0.16,OFFSET sz_Stream,'os',, PIN_OUTPUT OR UNIT_MIDI_STREAM } ;// stream out
osc_MidiIn2_pin_N   APIN_init { -0.06,OFFSET sz_Number,'N',, PIN_OUTPUT OR UNIT_MIDI } ;// Midi number
osc_MidiIn2_pin_V   APIN_init {  0.06,OFFSET sz_Value,'V',, PIN_OUTPUT OR UNIT_MIDI } ;// Midi value
osc_MidiIn2_pin_t   APIN_init {  0.16,OFFSET sz_Event,0B1h,, PIN_OUTPUT OR UNIT_LOGIC } ;// midi event +/-

    short_name  db  'Midi     In',0
    description db  'Input, filter, and track MIDI events from a port or another object.',0
    ALIGN 4

;// values

    midiin_dialog_busy dd   0   ;// prevents edit message mixups

    MIDI_EDIT_BUFFER_SIZE EQU 128   ;// (84 should be enough)


;// jump tables

    verify_input_jump LABEL DWORD
    dd  verify_input_bad
    dd  verify_input_device
    dd  verify_input_stream
    dd  verify_input_tracker


    verify_mode_table   LABEL DWORD
    ;// this table applies only to output modes
    ;// pairs of dwords
    ;// the first is the status mask
    ;// the second is an array of bits
    ;//
    ;// 0   use_channels    true for merge filter_channel into filter.status
    ;// 1   use_notes       true for copy filter_notes to filter.number
    ;// 2   use_ctrl        true for copy filter_ctrl to filter.number
    ;// 3   use_all         true for set all filter.number as 1
    ;// 4   show_N          true for show N pin
    ;// 5   N_is_s1         true to make N an s1 pin, false for make N an N (ignored if 3 is off)
    ;// 6   show_V          true for show the V pin
    ;// 7   show_e          true for show he e pin
    ;// 8   f_stream N      true for N is the f_stream
    ;// 9   f_stream intern true if f_stream is device.f_stream
    ;// 10  tracker source  true if this object must be tracker source (off for detach)

                                            ;// config      filters show    hide f_stream
    ;// filter                  09876543210 ;// ----------- ------- -----   ---- --------
    dd  0,                      00000000000y;// PORT_STREAM none    so      NVe   none
                                            ;//
    dd  MIDI_FILTER_TIMING,     00111000000y;// PORT_CLOCK          so,Ve   N   N
                                            ;//
    dd  MIDI_FILTER_RESET,      00110000000y;// PORT_RESET          so,e    NV  N
                                            ;//
    dd  MIDI_FILTER_CHANNELS,   00100111001y;// CHAN_STREAM channel so,s1   Ve  s1
                                            ;//             all numbers
    dd  MIDI_FILTER_PROGRAM,    00111000001y;// CHAN_PATCH  channel so,Ve   N   N
                                            ;//
    dd  MIDI_FILTER_AFTERTOUCH, 00111000001y;// CHAN_PRESS  channel so,Ve   N   N
                                            ;//
    dd  MIDI_FILTER_PITCHWHEEL, 00111000001y;// CHAN_WHEEL  channel so,Ve   N   N
                                            ;//
    dd  MIDI_FILTER_CONTROLLER, 01011010101y;// CHAN_CTRLR  channel so,NVe      internal
                                            ;//             stat_ctrl
    dd  MIDI_FILTER_NOTES,      00100110011y;// NOTE_STREAM channel so, s1  Ve  s1
                                            ;//             note_filter
    dd  MIDI_FILTER_PRESSURE,   01011010011y;// NOTE_PRESS  channel so,NVe      internal
                                            ;//             note_filter
    dd  MIDI_FILTER_NOTEON,     01011010011y;// NOTE_ON     channel so,NVe      internal
                                            ;//             note_filter
    dd  MIDI_FILTER_NOTEOFF,    01011010011y;// NOTE_OFF    channel so,NVe      internal
                                            ;//             note_filter
    dd  MIDI_FILTER_NOTES,      11000000011y;// TRACKER     channel so      NVe tracker table
                                            ;//             note_filter

.CODE



ASSUME_AND_ALIGN
midiin_VerifyMode PROC uses ebx

    ;// this function makes sure that devices are attached
    ;// hides and displays appropriate pins
    ;// builds appropriate filters

        ASSUME esi:PTR MIDIIN_OSC_MAP
        ASSUME ebp:PTR LIST_CONTEXT

    ;// verifies that the correct pins are being displayed

    check_input_mode:

        mov eax, [esi].dwUser           ;// get dwUser
        and eax, MIDIIN_INPUT_TEST      ;// strip out extra
        cmp eax, MIDIIN_INPUT_MAXIMUM
        ja verify_mode_bad
        mov ebx, [esi].pDevice
        ASSUME ebx:PTR MIDIIN_HARDWARE_DEVICEBLOCK
        BITSHIFT eax, MIDIIN_INPUT_DEVICE, 1
        mov ecx, [esi].midiin.tracker.pTracker
        ASSUME ecx:PTR MIDIIN_TRACKER_CONTEXT
        jmp verify_input_jump[eax*4]

    ALIGN 16
    verify_input_device::

        ;// ebx has the device
        ;// ecx has the tracker

    ;// if we are in a group, set bad now

        .IF ebp != OFFSET master_context
        ;// can't have devices inside groups
        ;// we'll reset the mode to default, then try again

            mov [esi].dwUser, MIDIIN_INPUT_STREAM
            jmp check_input_mode

        .ENDIF

    ;// make sure we are not a tracker dest

        .IF ecx
            invoke tracker_KillDest
        ;// mov ecx, [esi].midiin.tracker.pTracker
        .ENDIF

    ;// make sure we have a device

        .IF !ebx
            mov edx, [esi].dwUser
            and edx, 0FFFFh
            invoke hardware_AttachDevice
            mov ebx, [esi].pDevice
        .ENDIF

    ;// set the lowest latency mode correctly
    ;// if we are the first device assigned, we set the flag in the device
    ;// otherwise, we get the flag from the device

        .IF ebx ;// always make sure we exist

            .IF [ebx].numDevices == 1
                mov ecx, [esi].dwUser       ;// write to device
                mov [ebx].midi_flags, ecx
            .ELSE
                mov eax, [ebx].midi_flags
                ASSUME eax:NOTHING
                and eax, MIDIIN_LOWEST_LATENCY
                and [esi].dwUser, NOT MIDIIN_LOWEST_LATENCY
                or [esi].dwUser, eax        ;// read from device
            .ENDIF

        .ENDIF

    ;// continue on setting up the pins

        ;// si so N V e
        ;// N  Y  ? ? ?

        pushd 0  ;// hide
        pushd 1  ;// unhide
        jmp verfy_mode_filter

    ALIGN 16
    verify_input_tracker::

        ;// ebx has the device
        ;// ecx has the tracker

        ;// make sure we are not a tracker source

        .IF ecx
            invoke tracker_KillSource
            mov ecx, [esi].midiin.tracker.pTracker
        .ENDIF

        ;// make sure we are in the correct dest list

        .IF ecx
            invoke tracker_VerifyDest
        .ELSE
            invoke tracker_AttachDest
        .ENDIF

        ;// make sure we do not have a device

        .IF ebx
            invoke hardware_DetachDevice
        .ENDIF

        ;// make sure e says +/0

        mov eax, midi_font_plus_zero
        mov [esi].pin_e.pFShape, eax

        ;// continue on setting up the pins

        ;// si so N V e
        ;// N  N  Y Y Y

        pushd 0  ;// hide
        pushd 0  ;// hide
        pushd 1  ;// unhide
        pushd 1  ;// unhide
        pushd 1  ;// unhide

        jmp x_hide_the_pins

    ALIGN 16
    verify_input_stream::

        ;// ebx has the device
        ;// ecx has the tracker

        ;// we have a stream for an input
        ;// make sure we do not have a device or tracker for input

        .IF ecx
            invoke tracker_KillDest
        .ENDIF

        .IF ebx
            invoke hardware_DetachDevice
        .ENDIF

        ;// continue on setting up the pins

        ;// si so N V e
        ;// Y  Y  ? ? ?

        pushd 1  ;// unhide
        pushd 1  ;// unhide

    ALIGN 16
    verfy_mode_filter:

    ;// make sure e says +/-

        mov eax, midi_font_plus_minus
        mov [esi].pin_e.pFShape, eax

    ;// not bad if we got this far

        mov ecx, [esi].dwUser

        or [esi].dwHintI, HINTI_OSC_LOST_BAD

    ;// then hide/unhide values for si and so are already set

        and ecx, MIDIIN_OUTPUT_TEST
        BITSHIFT ecx,MIDIIN_PORT_CLOCK,1
        mov eax, verify_mode_table[ecx*8]   ;// get the starting status filter bits
        mov ecx, verify_mode_table[ecx*8]+4 ;// get the command bits

    ;// 0 use_channels  true for merge filter_channel into filter.status

        sar ecx, 1
        .IF CARRY?
            ;// make sure channel bits are set
            .IF !([esi].midiin.user_filter_chan & 0FFFFh)
                or [esi].midiin.user_filter_chan, 0FFFFh
            .ENDIF
            or eax, [esi].midiin.user_filter_chan
        .ENDIF
        mov [esi].midiin.filter.status, eax

    ;// 1 use_notes     true for copy filter_notes to filter.number

        sar ecx, 1
        .IF CARRY?

            ;// make sure at least one bit is set
            ;// if not, then set them all

            xor eax, eax
            or eax, [esi].midiin.user_filter_note[0]
            or eax, [esi].midiin.user_filter_note[4]
            or eax, [esi].midiin.user_filter_note[8]
            or eax, [esi].midiin.user_filter_note[12]
            .IF ZERO?
                dec eax ;// make -1
                mov [esi].midiin.user_filter_note[0], eax
                mov [esi].midiin.user_filter_note[4], eax
                mov [esi].midiin.user_filter_note[8], eax
                mov [esi].midiin.user_filter_note[12], eax
                mov [esi].midiin.filter.number[0], eax
                mov [esi].midiin.filter.number[4], eax
                mov [esi].midiin.filter.number[8], eax
                mov [esi].midiin.filter.number[12], eax
            .ELSE
                mov eax, [esi].midiin.user_filter_note[0]
                mov edx, [esi].midiin.user_filter_note[4]
                mov [esi].midiin.filter.number[0], eax
                mov [esi].midiin.filter.number[4], edx
                mov eax, [esi].midiin.user_filter_note[8]
                mov edx, [esi].midiin.user_filter_note[12]
                mov [esi].midiin.filter.number[8], eax
                mov [esi].midiin.filter.number[12], edx
            .ENDIF
        .ENDIF

    ;// 2 use_ctrl      true for copy filter_ctrl to filter.number

        sar ecx, 1
        .IF CARRY?
            xor eax, eax
            or eax, [esi].midiin.user_filter_ctrl[0]
            or eax, [esi].midiin.user_filter_ctrl[4]
            or eax, [esi].midiin.user_filter_ctrl[8]
            or eax, [esi].midiin.user_filter_ctrl[12]
            .IF ZERO?
                dec eax ;// make -1
                mov [esi].midiin.user_filter_ctrl[0], eax
                mov [esi].midiin.user_filter_ctrl[4], eax
                mov [esi].midiin.user_filter_ctrl[8], eax
                mov [esi].midiin.user_filter_ctrl[12], eax
                mov [esi].midiin.filter.number[0], eax
                mov [esi].midiin.filter.number[4], eax
                mov [esi].midiin.filter.number[8], eax
                mov [esi].midiin.filter.number[12], eax
            .ELSE
                mov eax, [esi].midiin.user_filter_ctrl[0]
                mov edx, [esi].midiin.user_filter_ctrl[4]
                mov [esi].midiin.filter.number[0], eax
                mov [esi].midiin.filter.number[4], edx
                mov eax, [esi].midiin.user_filter_ctrl[8]
                mov edx, [esi].midiin.user_filter_ctrl[12]
                mov [esi].midiin.filter.number[8], eax
                mov [esi].midiin.filter.number[12], edx
            .ENDIF
        .ENDIF

    ;// 3 use all numbers

        sar ecx, 1
        .IF CARRY?
            or eax,-1
            mov [esi].midiin.filter.number[0], eax
            mov [esi].midiin.filter.number[4], eax
            mov [esi].midiin.filter.number[8], eax
            mov [esi].midiin.filter.number[12], eax
        .ENDIF

    ;// 4 5 show_N, N's name

        sar ecx, 1
        .IF CARRY?
        ;// 4 N_is_s1       true to make N an s1 pin, false for make N an N
            sar ecx, 1
            push ecx    ;// have to preserve

            mov edx, OFFSET sz_Number   ;// assume we want LName to say midi number
            mov eax, midi_font_N_out    ;// assume it's font should be N
            mov ecx, UNIT_MIDI          ;// and tht it's unit should be midi
            .IF CARRY?                  ;// did we assume correctly ?
                mov edx, OFFSET sz_Stream   ;// LName should say stream
                mov eax, midi_font_s1_out   ;// font should be s1
                mov ecx, UNIT_MIDI_STREAM   ;// unit should be stream
            .ENDIF

            lea ebx, [esi].pin_N        ;// point at pin_N
            invoke pin_SetNameAndUnit, eax, edx, ecx

            pop ecx
            pushd 1     ;// unhide
        .ELSE
            sar ecx, 1  ;// 4 N_is_s1   ignore if hide
            pushd 0     ;// hide
        .ENDIF

    ;// 6 show_V        true for show the V pin

        xor edx, edx    ;// hide
        sar ecx, 1
        adc edx, edx    ;// unhide ?
        push edx

    ;// 7 show_e        true for show he e pin

        xor edx, edx    ;// hide
        sar ecx, 1
        adc edx, edx    ;// unhide ?
        push edx

    ;// 8 9 f_stream N  true for N is the f_stream
    ;// 9 f_stream int  true if f_stream is device.f_stream

        xor eax, eax    ;// assume no filter for now

        sar ecx, 1
        .IF CARRY?
            lea eax, [esi].data_N
        .ENDIF
        sar ecx, 1
        .IF CARRY?
            lea eax, [esi].midiin.t_stream
        .ENDIF
        mov [esi].midiin.f_stream, eax

    ;// 10 verify tracker source

        sar ecx, 1
        push ecx
        mov ecx, [esi].midiin.tracker.pTracker
        .IF CARRY?
            .IF ecx
                invoke tracker_VerifySource
            .ELSE
                invoke tracker_AttachSource
            .ENDIF
        .ELSEIF ecx
            invoke tracker_KillSource
        .ENDIF
        pop ecx

        jmp x_hide_the_pins

    verify_input_bad::
    verify_mode_bad::

        ;// make sure all devices are detached

        xor ecx, ecx
        or ecx, [esi].midiin.tracker.pTracker
        .IF !ZERO?
            invoke tracker_KillDest
            xor ecx, ecx
        .ENDIF
        or ecx, [esi].midiin.tracker.pTracker
        .IF !ZERO?
            invoke tracker_KillSource
            xor ecx, ecx
        .ENDIF

        mov ebx, [esi].pDevice
        ASSUME ebx:PTR HARDWARE_DEVICEBLOCK
        .IF ebx
            invoke hardware_DetachDevice
        .ENDIF

        ;// continue on with the pins
        ;// no si so N V e

        or [esi].dwHintI, HINTI_OSC_GOT_BAD

        pushd 0  ;// hide
        pushd 0  ;// hide
        pushd 0  ;// hide
        pushd 0  ;// hide
        pushd 0  ;// hide

    x_hide_the_pins:

        lea ebx, [esi].pin_e    ;// start at last pin
        .REPEAT
            call pin_Show       ;// STDCALL, arg already pushed
            sub ebx, SIZEOF APIN;// previous pin
        .UNTIL ebx <= esi

;// all_done:

        ret

midiin_VerifyMode ENDP






ASSUME_AND_ALIGN
midiin_Ctor PROC

        ;// register call
        ASSUME ebp:PTR LIST_CONTEXT ;// preserve
        ASSUME esi:PTR OSC_OBJECT   ;// preserve
        ASSUME edi:PTR OSC_BASE     ;// may_destroy
        ASSUME ebx:PTR FILE_OSC     ;// may destroy
        ASSUME edx:PTR FILE_HEADER  ;// may destroy

    ;// we've been created
    ;// any data we have is loaded
    ;// so now all we have to do is get a device

        .IF !edx    ;// not loading from file ??
            ;// default to port stream from stream
            mov [esi].dwUser, MIDIIN_PORT_STREAM OR MIDIIN_INPUT_STREAM
        .ENDIF

    ;// make sure the fonts are set

        .IF midi_font_N_in == 'N'
            invoke midistring_SetFonts
        .ENDIF

    ;// verify the mode

        invoke midiin_VerifyMode

    ;// that's it

        ret

midiin_Ctor ENDP





ASSUME_AND_ALIGN
midiin_Dtor PROC

    ;// make sure our devices are detached

        ASSUME esi:PTR MIDIIN_OSC_MAP

        xor ecx, ecx
        or ecx, [esi].midiin.tracker.pTracker
        .IF !ZERO?
            invoke tracker_KillDest
            xor ecx, ecx
        .ENDIF
        or ecx, [esi].midiin.tracker.pTracker
        .IF !ZERO?
            invoke tracker_KillSource
        .ENDIF

        .IF [esi].pDevice
            invoke hardware_DetachDevice
        .ENDIF

        ret

midiin_Dtor ENDP






ASSUME_AND_ALIGN
midiin_Render PROC

    ASSUME esi:PTR MIDIIN_OSC_MAP
    ASSUME edi:PTR OSC_BASE

    ;// render the osc first

        invoke gdi_render_osc   ;// render the background first

    ;// format
    ;//
    ;//     in: device
    ;//     out: command

    ;// don't display bad devices

        mov eax, [esi].dwUser
        and eax, MIDIIN_INPUT_TEST
        jz all_done

    ;// set text color to osc text

        GDI_DC_SELECT_FONT hFont_pin
        GDI_DC_SET_COLOR COLOR_OSC_TEXT

    ;// make some room for a rectangle

        sub esp, SIZEOF RECT

        point_GetTL [esi].rect
        point_Add MIDI_LABEL_BIAS
        point_SetTL (RECT PTR [esp])
        point_GetBR [esi].rect
        point_Sub MIDI_LABEL_BIAS
        point_SetBR (RECT PTR [esp])


    ;// display the input text at the top left

        mov eax, [esi].dwUser
        and eax, MIDIIN_INPUT_TEST

        cmp eax, MIDIIN_INPUT_STREAM
        jb input_is_device
        je done_with_input_display ;// input_is_stream

    input_is_tracker:

        mov ebx, [esi].midiin.tracker.pTracker
        test ebx,ebx
        jz done_with_input_display

        add ebx, OFFSET MIDIIN_TRACKER_CONTEXT.szName
        mov eax, esp
        invoke DrawTextA, gdi_hDC, ebx, -1, eax, 0 ;// DT_SINGLELINE

        jmp all_done_esp    ;// nothing else to display

    input_is_device:

        ;// pDevice.sz_name
        ;// HARDWARE_DEVICEBLOCK.szName

        mov ebx, [esi].pDevice
        test ebx, ebx
        jz done_with_input_display
        add ebx, OFFSET HARDWARE_DEVICEBLOCK.szName

        mov eax, esp
        invoke DrawTextA, gdi_hDC, ebx, -1, eax, DT_SINGLELINE

    done_with_input_display:

    ;// display the output text
    ;// get the string we want to display

        mov eax, [esi].dwUser
        and eax, MIDIIN_OUTPUT_TEST
        .IF eax != MIDIIN_NOTE_TRACKER
            BITSHIFT eax, MIDIIN_PORT_CLOCK, 1
            mov ebx, midiin_command_label_table[eax*4]
        .ELSE
            mov ebx, [esi].midiin.tracker.pTracker
            add ebx, OFFSET MIDIIN_TRACKER_CONTEXT.szName
        .ENDIF

        point_GetTL [esi].rect
        point_Add MIDI_LABEL_BIAS
        point_SetTL (RECT PTR [esp])
        point_GetBR [esi].rect
        point_Sub MIDI_LABEL_BIAS
        point_SetBR (RECT PTR [esp])

    ;// draw the text

        mov eax, esp
        invoke DrawTextA, gdi_hDC, ebx, -1, eax, DT_CALCRECT

        ;// reposition the text

        point_GetBR [esi].rect
        point_Sub MIDI_LABEL_BIAS
        point_SubBR (RECT PTR [esp])
        point_AddToTL (RECT PTR [esp])
        point_AddToBR (RECT PTR [esp])

        mov eax, esp
        invoke DrawTextA, gdi_hDC, ebx, -1, eax, 0

    ;// clean up and split
    all_done_esp:

        add esp, SIZEOF RECT

    all_done:

        ret

midiin_Render ENDP





ASSUME_AND_ALIGN
midiin_SaveUndo PROC

        ASSUME esi:PTR MIDIIN_OSC_MAP

    ;// edx enters as either UNREDO_CONTROL_OSC or UNREDO_COMMAND
    ;// edi enters as where to store
    ;//
    ;// task:   1) save nessary data
    ;//         2) iterate edi
    ;//
    ;// may use all registers except ebp

        mov eax, [esi].dwUser
        stosd
        mov esi, [esi].pData    ;// add esi, MIDIIN_OSC_MAP.midiin.filter_chan
        mov ecx, MIDIIN_SAVE_LENGTH ;// length of save data
        rep movsd
        ret

midiin_SaveUndo ENDP






ASSUME_AND_ALIGN
midiin_LoadUndo PROC

        ASSUME esi:PTR MIDIIN_OSC_MAP   ;// preserve
        ASSUME ebp:PTR LIST_CONTEXT     ;// preserve

    ;// edx enters as either UNREDO_CONTROL_OSC or UNREDO_COMMAND
    ;// edi enters as where to load
    ;//
    ;// task:   1) load nessary data
    ;//         2) do what it takes to initialize it
    ;//
    ;// may use all registers except ebp and esi
    ;// return will invalidate HINTI_OSC_UPDATE

        push esi
        xchg esi, edi
        ASSUME edi:PTR MIDIIN_OSC_MAP   ;// preserve

        lodsd
        mov [edi].dwUser, eax
        mov edi, [edi].pData
        mov ecx, MIDIIN_SAVE_LENGTH
        rep movsd
        pop esi

    ;// initialize for the new data

        invoke midiin_VerifyMode

        ret

midiin_LoadUndo ENDP
















ASSUME_AND_ALIGN
midiin_InitMenu PROC USES ebp esi edi

        mov eax, ebp    ;// store the list context
        mov ebp, esi
        ASSUME ebp:PTR MIDIIN_OSC_MAP   ;// preserve

        inc midiin_dialog_busy ;// handshake to prevent edit messages

    ;// mode buttons

        mov ebx, [ebp].dwUser
        and ebx, MIDIIN_INPUT_TEST
        jz init_bad_mode

    ;// if we are in a group, we cannot set the mode to device

        .IF eax != OFFSET master_context
            DEBUG_IF < ebx==MIDIIN_INPUT_DEVICE >   ;// not supposed to happen !!
            ENABLE_CONTROL popup_hWnd, ID_MIDIIN_INPUT_DEVICE, 0
        .ENDIF

    ;// push correct buttton

        BITSHIFT ebx, MIDIIN_INPUT_DEVICE, 1 ;// 1 for device, 2 for stream
        lea eax, [ebx+ID_MIDIIN_INPUT_DEVICE-1]
        CHECK_BUTTON popup_hWnd, eax, BST_PUSHED

    ;// determine which mode

        ;// ebx = 1 for device, 2 for stream, 3 for tracker
        sub ebx, 2
        jz init_stream_mode
        ja init_tracker_mode

    init_device_mode:

        call init_device_list           ;// enable device list

    ;// check tracker or device

        ENABLE_CONTROL popup_hWnd, ID_MIDIIN_LOWEST_LATENCY, 1
        mov ebx, [ebp].pDevice
        test ebx, ebx
        jz init_filter
        and [ebp].dwUser, NOT MIDIIN_LOWEST_LATENCY
        test (MIDIIN_HARDWARE_DEVICEBLOCK PTR [ebx]).midi_flags, MIDIIN_LOWEST_LATENCY
        jz init_filter
        invoke CheckDlgButton, popup_hWnd, ID_MIDIIN_LOWEST_LATENCY, BST_CHECKED
        or [ebp].dwUser, MIDIIN_LOWEST_LATENCY
        jmp init_filter                 ;// otherwise init the filter

    init_tracker_mode:

        ;// enable the device list
        ;// fill in with trackers

        call init_tracker_list

        jmp disable_all_buttons         ;// there are no more controls

    init_stream_mode:

        ENABLE_CONTROL popup_hWnd, ID_MIDIIN_LOWEST_LATENCY, 0

        call disable_device_list        ;// disable device list
        jmp init_filter                 ;// init the filter

    ;///////////////////////////////////////////

    init_bad_mode:

            call disable_device_list    ;// disable device list

        disable_all_buttons:            ;// disable all buttons

            xor ebx, ebx
            mov esi, ID_MIDIIN_PORT_STREAM
            mov edi, ID_MIDIIN_LOWEST_LATENCY
            call xable_buttons

        init_port_boxes:    ;// disable the edit boxes

            mov ebx, 1  ;// reead_only
            mov esi, ID_MIDIIN_CHAN_EDIT
            mov edi, ID_MIDIIN_NOTE_EDIT
            call xable_readonly

            jmp all_done

    ;///////////////////////////////////////////

    init_filter:

        ;// enable all the controls

            mov ebx, 1
            mov esi, ID_MIDIIN_PORT_STREAM
            mov edi, ID_MIDIIN_NOTE_TRACKER
            call xable_buttons

        ;// press the correct filter button (check for tracker in the prcess)

            mov ebx, [ebp].dwUser
            and ebx, MIDIIN_OUTPUT_TEST
            push ebx
            mov esi, ID_MIDIIN_NOTE_TRACKER_SAT
            cmp ebx, MIDIIN_NOTE_TRACKER
            mov edi, ID_MIDIIN_NOTE_TRACKER_FREQ
            mov ebx, 0  ;// assume disabled
            .IF ZERO?   ;// we are note tracker
                        ;// and we will show these bottons shortly

                xor ecx, ecx    ;// BST_UNCHECKED
                .IF [ebp].dwUser & MIDIIN_NOTE_TRACKER_SAT
                    inc ecx     ;// BST_SCHECKED
                .ENDIF
                CHECK_BUTTON popup_hWnd, esi, ecx
                xor ecx, ecx    ;// BST_UNCHECKED
                .IF [ebp].dwUser & MIDIIN_NOTE_TRACKER_FREQ
                    inc ecx     ;// BST_SCHECKED
                .ENDIF
                CHECK_BUTTON popup_hWnd, edi, ecx

                inc ebx ;// enable the buttons

            .ENDIF
            call xable_buttons
            pop ebx
            BITSHIFT ebx, MIDIIN_PORT_CLOCK, 1
            add ebx, ID_MIDIIN_PORT_STREAM
            CHECK_BUTTON popup_hWnd, ebx, BST_CHECKED

        ;// determine which edit boxes need filled in

            cmp ebx, ID_MIDIIN_CHAN_STREAM
            jb init_port_boxes

            sub esp, MIDI_EDIT_BUFFER_SIZE  ;// make a text buffer on the stack

            cmp ebx, ID_MIDIIN_CHAN_CTRLR
            je init_ctrl_boxes
            cmp ebx, ID_MIDIIN_NOTE_STREAM
            jb init_chan_boxes

    init_note_boxes:

        ;// disable CTRL

            mov esi, ID_MIDIIN_CTRL_EDIT
            mov ebx, 1  ;// read_only
            mov edi, esi
            call xable_readonly

        ;// enable NOTE

            inc edi     ;// = NOTE
            dec ebx     ;// = not read_only
            mov esi, edi
            call xable_readonly

        ;// fill in text for NOTE

            lea eax, [ebp].midiin.user_filter_note
            invoke midi_bits_to_szrange, eax, 128, esp
            invoke GetDlgItem, popup_hWnd, ID_MIDIIN_NOTE_EDIT
            WINDOW eax, WM_SETTEXT, 0, esp

        ;// continue on to channel filter

            jmp setup_chan_boxes

    init_ctrl_boxes:

        ;// disable NOTE

            mov esi, ID_MIDIIN_NOTE_EDIT
            mov ebx, 1  ;// read_only
            mov edi, esi
            call xable_readonly

        ;// enable CTRL

            dec edi     ;// = CTRL
            dec ebx     ;// = not read_only
            mov esi, edi
            call xable_readonly

        ;// fill in text for CTRL

            lea eax, [ebp].midiin.user_filter_ctrl
            invoke midi_bits_to_szrange, eax, 128, esp
            invoke GetDlgItem, popup_hWnd, ID_MIDIIN_CTRL_EDIT
            WINDOW eax, WM_SETTEXT, 0, esp

        ;// continue on to channel filter

            jmp setup_chan_boxes

    init_chan_boxes:

        ;// disable NOTE CTRL

            mov esi, ID_MIDIIN_CTRL_EDIT
            mov ebx, 1          ;// read_only
            lea edi, [esi+1]    ;// = NOTE
            call xable_readonly

        ;// fall into init channel boxes

    setup_chan_boxes:

        ;// enable CHAN

            mov esi, ID_MIDIIN_CHAN_EDIT
            xor ebx, ebx        ;// not read_only
            mov edi, esi
            call xable_readonly

        ;// fill in ctrlr values



        ;// fill in text for chan

            lea eax, [ebp].midiin.user_filter_chan
            invoke midi_bits_to_szrange, eax, 16, esp
            invoke GetDlgItem, popup_hWnd, ID_MIDIIN_CHAN_EDIT
            WINDOW eax, WM_SETTEXT, 0, esp

        ;// clean up stack and exit

            add esp, MIDI_EDIT_BUFFER_SIZE

    all_done:

        dec midiin_dialog_busy ;// handshake to prevent edit messages
        xor eax,eax             ;// return zero or popup will resize

        ret


;// local functions

    xable_buttons:

        ;// ebx has yes no
        ;// esi has iterator
        ;// edi has last iterator
        .REPEAT
            ENABLE_CONTROL popup_hWnd, esi, ebx
            inc esi
        .UNTIL esi > edi

        retn


    xable_readonly:

        ;// ebx has yes no
        ;// esi has iterator
        ;// edi has last iterator

        .REPEAT

            invoke GetDlgItem, popup_hWnd, esi
            pushd 0     ;// EM_SETREADONLY.reserved
            pushd ebx   ;// EM_SETREADONLY.yes/no
            pushd EM_SETREADONLY
            push eax    ;// EM_SETREADONLY.hWnd
            .IF ebx;// ebx!=0 read only, set text to 0
                pushd 0     ;// WM_SETTEXT string
                push esp    ;// WM_SETTEXT.pString
                pushd 0 ;// WM_SETTEXT.reserved
                pushd WM_SETTEXT
                push eax    ;// WM_SETTEXT.hWnd
                call SendMessageA
                pop eax     ;// clean up stack
            .ELSE   ;// ebx=0 not read only, set limit text
                WINDOW eax, EM_SETLIMITTEXT, MIDI_EDIT_BUFFER_SIZE-1, ebx
            .ENDIF
            call SendMessageA

            inc esi

        .UNTIL esi > edi

        retn


    disable_device_list:

    ;// reset and disable list

        ENABLE_CONTROL popup_hWnd, ID_MIDIIN_INPUT_LIST, 0, eax
        WINDOW eax, LB_RESETCONTENT

    ;// reset the assigned text

        invoke GetDlgItem, popup_hWnd, ID_MIDIIN_INPUT_NAME_STATIC
        pushd 0
        WINDOW eax, WM_SETTEXT, 0, esp
        pop eax

        retn

    init_device_list:

    ;// have hardware fill the list

        ENABLE_CONTROL popup_hWnd, ID_MIDIIN_INPUT_LIST, 1, ebx
        mov esi, ebp
        invoke hardware_FillInDeviceList

    ;// show the current device

        invoke GetDlgItem, popup_hWnd, ID_MIDIIN_INPUT_NAME_STATIC
        mov ecx, [ebp].pDevice
        .IF ecx
            add ecx, OFFSET HARDWARE_DEVICEBLOCK.szName
        .ELSE
            mov ecx, OFFSET sz_Not_space_Assigned
        .ENDIF
        WINDOW eax, WM_SETTEXT, 0, ecx

        retn

    init_tracker_list:

        ENABLE_CONTROL popup_hWnd, ID_MIDIIN_INPUT_LIST, 1, ebx
        mov esi, ebp        ;// xfer osc to esi
        mov ebp, [esp+12]   ;// get the list context
        invoke tracker_FillInDeviceList
        mov ebp, [esp+8]    ;// get the osc

    ;// show the current device

        invoke GetDlgItem, popup_hWnd, ID_MIDIIN_INPUT_NAME_STATIC
        mov ecx, [ebp].midiin.tracker.pTracker
        .IF ecx
            add ecx, OFFSET MIDIIN_TRACKER_CONTEXT.szName
        .ELSE
            mov ecx, OFFSET sz_Not_space_Assigned
        .ENDIF
        WINDOW eax, WM_SETTEXT, 0, ecx

        retn


midiin_InitMenu ENDP











ASSUME_AND_ALIGN
midiin_Command PROC

    ASSUME ebp:PTR LIST_CONTEXT
    ASSUME esi:PTR MIDIIN_OSC_MAP
    ;// eax has cmd id
    ;// ecx has edit control id

    cmp midiin_dialog_busy, 0
    jne osc_Command

;// device list

    cmp eax, OSC_COMMAND_LIST_DBLCLICK  ;// equ LBN_DBLCLK      ;// windows = 2
    jne @F

    ;// the currently selected item's ptr to hardware device block is passed in ecx

        ASSUME ecx:PTR HARDWARE_DEVICEBLOCK

        mov eax, [esi].dwUser
        and eax, MIDIIN_INPUT_TEST

        cmp eax, MIDIIN_INPUT_DEVICE
        jne J0
            ;// we're choosing from the device list

            mov ebx, [esi].pDevice
            ASSUME ebx:PTR HARDWARE_DEVICEBLOCK
            cmp ecx, ebx
            je ignore_and_exit

            xchg ecx, ebx
            .IF ecx
                invoke hardware_DetachDevice
            .ENDIF

            mov edx, [ebx].ID
            and [esi].dwUser, 0FFFF0000h
            or [esi].dwUser, edx

            invoke hardware_AttachDevice

            jmp verify_and_done

        J0:
        cmp eax, MIDIIN_INPUT_TRACKER
        jne ignore_and_exit

            ;// we're choosing from the tracker list

            mov ebx, [esi].midiin.tracker.pTracker
            ASSUME ebx:PTR MIDIIN_TRACKER_CONTEXT
            cmp ecx, ebx
            je ignore_and_exit

            xchg ecx, ebx
            .IF ecx
                invoke tracker_DetachDest
            .ENDIF

            mov eax, [ebx].ID
            mov [esi].midiin.tracker_id, eax
            invoke tracker_AttachDest

            jmp verify_and_done


;// EDIT CONTROLS

@@: cmp eax, OSC_COMMAND_EDIT_KILLFOCUS
    jne @F

        push ecx
        invoke GetDlgItem, popup_hWnd, ecx
        mov ebx, eax

        WINDOW ebx, EM_GETMODIFY
        test eax, eax
        jz ignore_and_exit_pop_ecx

    ;// get the text

        sub esp, MIDI_EDIT_BUFFER_SIZE
        WINDOW ebx, WM_GETTEXT, MIDI_EDIT_BUFFER_SIZE, esp
        ;// eax returns with text length

        jmp figure_out_which_edit


@@: cmp eax, OSC_COMMAND_EDIT_CHANGE
    jne try_input_mode_buttons
    ;// ecx has the edit control id

    ;// get the handle, save the id

        push ecx
        invoke GetDlgItem, popup_hWnd, ecx
        mov ebx, eax

    ;// get the text

        sub esp, MIDI_EDIT_BUFFER_SIZE
        WINDOW ebx, WM_GETTEXT, MIDI_EDIT_BUFFER_SIZE, esp
        ;// eax returns with text length

    ;// check for enter key

        STR_FIND_CRLF_reverse esp,eax,enter_key_not_found,c

    ;// enter key was found, then figure out which edit box

    figure_out_which_edit:  ;// fall through is ignore

        mov ecx, DWORD PTR [esp+MIDI_EDIT_BUFFER_SIZE]  ;// get the ctrl id

        .IF ecx == ID_MIDIIN_CTRL_EDIT

            lea edx, [esi].midiin.user_filter_ctrl
            and [esi].midiin.user_filter_ctrl[0], 0
            and [esi].midiin.user_filter_ctrl[4], 0
            and [esi].midiin.user_filter_ctrl[8], 0
            and [esi].midiin.user_filter_ctrl[12], 0
            mov eax, 128
            jmp T3

        .ENDIF

        .IF ecx == ID_MIDIIN_NOTE_EDIT

            lea edx, [esi].midiin.user_filter_note
            and [esi].midiin.user_filter_note[0], 0
            and [esi].midiin.user_filter_note[4], 0
            and [esi].midiin.user_filter_note[8], 0
            and [esi].midiin.user_filter_note[12], 0
            mov eax, 128
            jmp T3

        .ENDIF

        .IF ecx == ID_MIDIIN_CHAN_EDIT

            lea edx, [esi].midiin.user_filter_chan
            and [esi].midiin.user_filter_chan, 0
            mov eax, 16
            jmp T3

        .ENDIF

    enter_key_not_found:    ;// enter key was not found

        add esp, MIDI_EDIT_BUFFER_SIZE

    ignore_and_exit_pop_ecx:

        pop ecx

    ignore_and_exit:    ;// jumped to from duplicate key test

        mov eax, POPUP_IGNORE
        jmp all_done

    T3: ;// ready to process the list
        ;//
        ;// state:
        ;//
        ;//     eax = num bits
        ;//     edx = ptr to bits
        ;//     ecx = control id
        ;//     ebx = hWnd control

        ;// we do two calls then set the window text
        mov ecx, esp    ;// pBits

        push esp    ;// bits_to_range pStr
        push eax    ;// bits_to_range num bits
        push edx    ;// bits_to_range pBits
        push eax    ;// range_to_bits num_bits
        push edx    ;// range_to_bits pBits
        push ecx    ;// range_to_bits pStr
        call midi_szrange_to_bits
        call midi_bits_to_szrange
        WINDOW ebx, WM_SETTEXT, 0, esp
        add esp, MIDI_EDIT_BUFFER_SIZE
        pop ecx
        jmp verify_and_done

;// modes
try_input_mode_buttons:

    ;// see if command is in the range

        cmp eax, ID_MIDIIN_INPUT_DEVICE
        jb osc_Command
        cmp eax, ID_MIDIIN_INPUT_TRACKER
        ja try_filter_mode_buttons

    ;// determine the new mode, get the old omode

        sub eax, ID_MIDIIN_INPUT_DEVICE-1       ;// turn command into a mode
        mov edx, [esi].dwUser                   ;// get old mode
        BITSHIFT eax, 1, MIDIIN_INPUT_DEVICE    ;// scoot mode into place
        and edx, MIDIIN_INPUT_TEST              ;// remove extra bits from old mode
        cmp eax, edx                            ;// make sure not the same mode
        je ignore_and_exit

    ;// set the new input mode

        and [esi].dwUser, NOT MIDIIN_INPUT_TEST ;// reset old mode
        or [esi].dwUser, eax                    ;// set new mode

        jmp verify_and_done

;// filter

try_filter_mode_buttons:


    cmp eax, ID_MIDIIN_PORT_STREAM
    jb osc_Command
    cmp eax, ID_MIDIIN_NOTE_TRACKER
    ja try_tracker_mode_buttons

        .IF ZERO?   ;// got_make_tracker
            mov [esi].midiin.tracker_id, 0
        .ENDIF

        sub eax, ID_MIDIIN_PORT_STREAM
        and [esi].dwUser, NOT MIDIIN_OUTPUT_TEST
        BITSHIFT eax, 1, MIDIIN_PORT_CLOCK
        or [esi].dwUser, eax
        jmp verify_and_done


try_tracker_mode_buttons:

;// these two commands are xor'ed

@@: cmp eax, ID_MIDIIN_NOTE_TRACKER_SAT
    jb osc_Command
    ja @F

        xor [esi].dwUser, MIDIIN_NOTE_TRACKER_SAT
        jmp verify_and_done

@@: cmp eax, ID_MIDIIN_NOTE_TRACKER_FREQ
    jne @F

        xor [esi].dwUser, MIDIIN_NOTE_TRACKER_FREQ
        ;// since we are a source object
        ;// we need to invalidate all our dest objects so
        ;// that midiin_Render will set their pins and units
        invoke tracker_UpdateDestPins
        jmp verify_and_done

@@: cmp eax, ID_MIDIIN_LOWEST_LATENCY
    jne osc_Command

        mov ecx, [esi].pDevice
        test ecx, ecx
        jz ignore_and_exit

        ASSUME ecx:PTR MIDIIN_HARDWARE_DEVICEBLOCK

        xor [ecx].midi_flags, MIDIIN_LOWEST_LATENCY

        mov eax, [ecx].midi_flags
        and eax, MIDIIN_LOWEST_LATENCY
        and [esi].dwUser, NOT MIDIIN_LOWEST_LATENCY
        or [esi].dwUser, eax

;//     jmp verify_and_done


verify_and_done:

        invoke midiin_VerifyMode

dirty_and_done:

    mov eax, POPUP_INITMENU OR POPUP_SET_DIRTY OR POPUP_REDRAW_OBJECT

all_done:

    ret



midiin_Command ENDP






ASSUME_AND_ALIGN
midiin_PrePlay PROC

    ASSUME esi:PTR MIDIIN_OSC_MAP

    xor eax, eax
    ret

midiin_PrePlay ENDP

.DATA

    ;// AJT ABOX242 changed from math_temp_1 and math_temp_2
    ALIGN 8
        midiin_temp_1 dd 0
    ALIGN 8
        midiin_temp_2 dd 0
    ALIGN 8

    midiin_filter_jump LABEL DWORD

    dd  midiin_filter_port_stream   ;// 0
    dd  midiin_filter_port_clock    ;// 1
    dd  midiin_filter_port_reset    ;// 2
    dd  midiin_filter_chan_stream   ;// 3
    dd  midiin_filter_chan_patch    ;// 4
    dd  midiin_filter_chan_press    ;// 5
    dd  midiin_filter_chan_wheel    ;// 6
    dd  midiin_filter_chan_ctrlr    ;// 7
    dd  midiin_filter_note_stream   ;// 8
    dd  midiin_filter_note_press    ;// 9
    dd  midiin_filter_note_on       ;// A
    dd  midiin_filter_note_off  ;// B
    dd  midiin_filter_note_tracker ;// C
    dd  midiin_filter_not_used  ;// D
    dd  midiin_filter_not_used  ;// E
    dd  midiin_filter_not_used  ;// F

.CODE



ASSUME_AND_ALIGN
midiin_Calc PROC

        ASSUME esi:PTR MIDIIN_OSC_MAP

    ;// for stream and device input
    ;//
    ;// 1) get the input source (device portstream and connected input pin)
    ;// 2) use the filter (if nessesary for selected mode)
    ;// 3) command handler (port channel note)
    ;// 4) 7/14 bit, numbered, etc processors

;///////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////
;///
;///    1) get the input source (device portstream and connected input pin)
;///
;///////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////

    ;// we should save some hassle by prechecking for trackers
    ;// this will prevent tracker source filter from being
    ;// calculated twice (also saves a messy flag toggling expedition)

        mov eax, [esi].dwUser
        mov edx, eax
        and eax, MIDIIN_INPUT_TEST
        jz all_done             ;// skip bad objects

    ;// cmp eax, MIDIIN_INPUT_MAXIMUM
    ;// ja all_done

        cmp eax, MIDIIN_INPUT_STREAM
        je get_input_stream
        ja all_done ;// must be a tracker dest !

    get_portstream:     ;// see if the device has processed this yet

        mov ebx, [esi].pDevice
        ASSUME ebx:PTR MIDIIN_HARDWARE_DEVICEBLOCK
        TESTJMP ebx, ebx, jz all_done

        ;// test [esi].dwUser, MIDIIN_TRACKER_BIAS
        ;// jnz process_tracker_dest    ;// this branch takes care of tracker dests

        ;// ABOX233 account for change in MIDI_QUE_PORTSTREAM

        add ebx, SIZEOF HARDWARE_DEVICEBLOCK    ;// advance to MIDI_QUE_PORTSTREAM
        ASSUME ebx:PTR MIDI_QUE_PORTSTREAM
        .IF ![ebx].portstream_ready             ;// is portsteam ready ?
            invoke midi_que_to_portstream       ;// make it ready
        .ENDIF
        add ebx, OFFSET MIDI_QUE_PORTSTREAM.portstream  ;// advance to the actual stream
        ASSUME ebx:PTR MIDI_STREAM_ARRAY
        jmp check_for_filter



    get_input_stream:

        GET_PIN [esi].pin_si.pPin, ebx
        .IF !ebx                    ;// is it connected ??
            mov ebx, math_pNullPin  ;// use null array if not
        .ENDIF
        mov ebx, [ebx].pData
        ASSUME ebx:PTR MIDI_STREAM_ARRAY

    ;// jmp check_for_filter



;///////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////
;///
;///    2) use the filter ( if nessesary for selected mode )
;///
;///////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////

;// ALIGN 16

    check_for_filter:

        mov eax, [esi].midiin.f_stream
        .IF eax
            lea edx, [esi].data_so
            lea ecx, [esi].midiin.filter
            invoke stream_filter, ebx, edx, eax, ecx
            mov ebx, [esi].midiin.f_stream      ;// load the command stream
        .ENDIF
        ASSUME ebx:PTR MIDI_STREAM_ARRAY

    ;// we have assumed that if there is no filter,
    ;// that we keep ebx at input stream

        mov eax, [esi].dwUser
        mov edx, eax
        and eax, MIDIIN_OUTPUT_TEST
        xor ecx, ecx
        shr eax, LOG2(MIDIIN_PORT_CLOCK)
        jmp midiin_filter_jump[eax*4]

;///////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////
;///
;///    3) command handler (port channel note)
;///
;///////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////

    ASSUME ebx:PTR MIDI_STREAM_ARRAY

ALIGN 16
midiin_filter_port_stream::

    ;// ebx has i_stream
    ;// edx has dwUser
    ;// ecx is zero
    ;// esi is osc map

    ;// just copy portstream to the output

        lea edi, [esi].data_so
        ASSUME edi:PTR MIDI_STREAM_ARRAY

        DEBUG_IF <ecx>  ;// ecx is supposed to be zero !!

        midistream_Reset [edi], ecx ;// clear the destination stream

        midistream_IterBegin [ebx], ecx, all_done   ;// start iterating the source stream

    port_stream_copy:

        midistream_Append [edi], ecx
        mov eax, [ebx+ecx*8].evt
        mov [edi+ecx*8].evt, eax

        midistream_IterNext [ebx], ecx, port_stream_copy

        jmp all_done



ALIGN 16
midiin_filter_port_clock::

    ;// ebx has f_stream
    ;// edx has dwUser
    ;// ecx is zero
    ;// esi is osc map

    ;// in this mode,
    ;//     we set N as neg if we recieved start or continue
    ;//     set n as pause if we get stop
    ;//     toggle e every clock event we get


    invoke midiin_fill_Begin
    jz all_done

    ;// do work

    xor ecx, ecx

    midistream_IterBegin [ebx], ecx, midiin_filter_done

    scan_events_port_clock:

        mov eax, [ebx+ecx*8].evt
        and eax, MIDI_FLOAT_CHANNEL_TEST    ;// command is stored in the channel

    ;// MIDI_FILTER_CLOCK       F8h     80000h
    ;// F9  MIDI TICK (EVERY 10M DAtA)
    ;// MIDI_FILTER_START       FAh     A0000h
    ;// MIDI_FILTER_CONTINUE    FBh     B0000h
    ;// MIDI_FILTER_STOP        FCh     C0000h

        cmp eax, 080000h    ;// clock
        je port_clock_got_clock
        cmp eax, 0A0000h    ;// start
        je port_clock_got_start
        cmp eax, 0B0000h    ;// continue
        je port_clock_got_continue
        cmp eax, 0C0000h    ;// stop
        jne port_clock_next_event

    port_clock_got_stop:

        mov edx, [esi].midiin.last_fill
        xor eax, eax
        mov edx, [esi].data_e[edx*8]    ;// get the previous value of e
        mov [esi].data_V[ecx*8], eax
        mov [esi].data_e[ecx*8], edx
        invoke midiin_fill_Advance
        jmp port_clock_next_event

    ALIGN 16
    port_clock_got_continue:
    port_clock_got_start:

        ;// to do this correctly, we need to set all three pins
        ;// otherwise, fill_advance will erase data

        mov edx, [esi].midiin.last_fill
        mov eax, math_neg_1
        mov edx, [esi].data_e[edx*8]    ;// get the previous value of e
        mov [esi].data_V[ecx*8], eax
        mov [esi].data_e[ecx*8], edx

        invoke midiin_fill_Advance
        jmp port_clock_next_event

    ALIGN 16
    port_clock_got_clock:

        mov eax, math_1     ;// off value
        mov edx, [esi].midiin.last_fill
        xor [esi].midiin.tracker.event, 1   ;// flip the event bit
        mov edx, [esi].data_V[edx*8]    ;// get the previous value of V
        .IF !ZERO?
            or eax, 80000000h
        .ENDIF
        mov [esi].data_e[ecx*8], eax
        mov [esi].data_V[ecx*8], edx

        invoke midiin_fill_Advance

    ALIGN 16
    port_clock_next_event:

    midistream_IterNext [ebx], ecx, scan_events_port_clock
    jmp midiin_filter_done


ALIGN 16
midiin_filter_port_reset::

    ;// ebx has f_stream
    ;// edx has dwUser
    ;// ecx is zero
    ;// esi is osc map

    invoke midiin_fill_Begin
    jz all_done
    xor ecx, ecx
    midistream_IterBegin [ebx], ecx, midiin_filter_done

    ;// do work

    scan_events_reset:

        mov eax, math_1     ;// off value
        xor [esi].midiin.tracker.event, 1   ;// flip the tevent bit
        .IF !ZERO?
            or eax, 80000000h
        .ENDIF
        mov [esi].data_e[ecx*8], eax
        invoke midiin_fill_Advance

    midistream_IterNext [ebx], ecx, scan_events_reset
    jmp midiin_filter_done



;///////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////
;///
;///    4) 7/14 bit, numbered, etc processors
;///
;///////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////

ALIGN 16
midiin_filter_chan_ctrlr::
midiin_filter_note_press::
midiin_filter_note_on::
midiin_filter_note_off::

    ;// ebx has f_stream
    ;// edx has dwUser
    ;// ecx is zero
    ;// esi is osc map

    ;// route 7bit numbers to N
    ;// route 7bit values to V
    ;// route edges to e

    invoke midiin_fill_Begin
    jz all_done

    ;// do work

    xor ecx, ecx

    midistream_IterBegin [ebx], ecx, midiin_filter_done

    scan_events_7_bit_numbered:

        mov eax, [ebx+ecx*8].evt    ;// get event from stream
        mov edx, eax
        and eax, MIDI_FLOAT_NUMBER_TEST ;// iN
        and edx, MIDI_FLOAT_VALUE_TEST  ;// iV

        mov midiin_temp_1, eax        ;// iN
        mov midiin_temp_2, edx        ;// iV

        fld math_1_32768    ;// sN
        fild midiin_temp_1    ;// iN
        fmul                ;// N

        fld math_1_128      ;// sV  N
        fild midiin_temp_2    ;// iV  N
        fmul                ;// V   N

        mov eax, math_1     ;// off value
        xor [esi].midiin.tracker.event, 1   ;// flip the tevent bit
        .IF !ZERO?
            or eax, 80000000h
        .ENDIF

        fxch                ;// N   V

        fstp [esi].data_N[ecx*8]
        mov [esi].data_e[ecx*8], eax
        fstp [esi].data_V[ecx*8]

        invoke midiin_fill_Advance

    midistream_IterNext [ebx], ecx, scan_events_7_bit_numbered
    jmp midiin_filter_done


ALIGN 16
midiin_filter_chan_wheel::

    ;// ebx has f_stream
    ;// edx has dwUser
    ;// ecx is zero
    ;// esi is osc map

    ;// route 14bit values to V
    ;// route edges to e

    invoke midiin_fill_Begin
    jz all_done

    ;// do work

    xor ecx, ecx

    midistream_IterBegin [ebx], ecx, midiin_filter_done

    scan_events_14_bit:

        mov eax, [ebx+ecx*8].evt    ;// get event from stream
        mov edx, eax
        and eax, MIDI_FLOAT_NUMBER_TEST ;// lower bits (need to shift 1)
        and edx, MIDI_FLOAT_VALUE_TEST  ;// upper bits
        shl edx, 8
        shr eax, 7

        lea eax, [eax+edx-4000h]    ;// use 2X center (center=2000h)

        mov midiin_temp_1, eax

        fld math_1_16384    ;// sV
        fild midiin_temp_1    ;// iV
        fmul

        mov eax, math_1     ;// off value
        xor [esi].midiin.tracker.event, 1   ;// flip the tevent bit
        .IF !ZERO?
            or eax, 80000000h
        .ENDIF
        mov [esi].data_e[ecx*8], eax

        fstp [esi].data_V[ecx*8]

        invoke midiin_fill_Advance

    midistream_IterNext [ebx], ecx, scan_events_14_bit
    jmp midiin_filter_done


ALIGN 16
midiin_filter_chan_patch::
midiin_filter_chan_press::

    ;// ebx has f_stream
    ;// edx has dwUser
    ;// ecx is zero
    ;// esi is osc map

    ;// route 7bit values to V
    ;// route edges to e

    invoke midiin_fill_Begin
    jz all_done

    ;// do work

    xor ecx, ecx

    midistream_IterBegin [ebx], ecx, midiin_filter_done

    scan_events_7_bit:

        mov eax, [ebx+ecx*8].evt    ;// get event from stream
        and eax, MIDI_FLOAT_NUMBER_TEST ;// value should be zero

        mov midiin_temp_1, eax

        fld math_1_32768    ;// sV
        fild midiin_temp_1    ;// iN
        fmul

        mov eax, math_1     ;// off value
        xor [esi].midiin.tracker.event, 1   ;// flip the event bit
        .IF !ZERO?
            or eax, 80000000h
        .ENDIF
        mov [esi].data_e[ecx*8], eax

        fstp [esi].data_V[ecx*8]

        invoke midiin_fill_Advance

    midistream_IterNext [ebx], ecx, scan_events_7_bit
    jmp midiin_filter_done



ALIGN 16
midiin_filter_note_tracker::

    ;// we are a tracker source

    invoke tracker_Calc
    jmp all_done


;///////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////
;///
;///    6) all_done         and early outs
;///
;///////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////

ALIGN 16
midiin_filter_done:

    invoke midiin_fill_End

ALIGN 16
all_done:
midiin_filter_not_used::
midiin_bad_calc::
midiin_filter_chan_stream::
midiin_filter_note_stream::

    ret

midiin_Calc ENDP








;////////////////////////////////////////////////////////////////////////////////////////
;//
;//  midi in fill
;//
;//
;/////////////////////////////////////////////////////////////////////////////////////////






comment ~ /*

    the concept is to have a central function to fill midiin output data
    this may lower the complication
    it MAY be faster although it's not likely to
    it will be called from dozens of locations, so it will remain in the instruction cache

    1) call midiin_fill_Begin
        reset last_fill
        determine the fill function to call (look at pins)
    2) for each new event
        write the event to output
        call midiin_fill_Advance
            fills data from last_fill to current position
            updates pin_changing
    3) when done with frame
        call midiin_fill_End
            fills data to end of frame

    pin.dwUser stores last_fill
    osc.midiin.fill_advance stores address of filling routine
    osc_midiin.fill_end stores address of ending routine

    all three of these are setup by midiin_fill_Begin

*/ comment ~


;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;///
;///    B E G I N
;///
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////

    ;// tasks
    ;//
    ;//     if pin is connected
    ;//
    ;//         set appropriate bit in command
    ;//         reset last_fill
    ;//         xfer last sample to first
    ;//         turn off PIN_CHANGING
    ;//         turn on PIN_WAS_CHANGING (if pin changing was on)



    MIDIIN_FILL_BEGIN MACRO letter:req, number:req

        DEBUG_IF <edx>  ;// edx must = 0

        .IF edx != [esi].pin_&letter&.pPin

            .IF !([esi].pin_&letter&.dwHintPin & HINTPIN_STATE_HIDE)

                add ecx, number                     ;// set the command bit

                mov eax, [esi].data_&letter&[LAST_SAMPLE]   ;// get the last value
                mov [esi].data_&letter&, eax                ;// store the first value

                mov eax, [esi].pin_&letter&.dwStatus;// get dwStatus
                and eax, NOT PIN_WAS_CHANGING       ;// turn off pin-was-changing
                BITR eax, PIN_CHANGING              ;// test and turn off pin_changing
                rcr edx, 32-LOG2(PIN_WAS_CHANGING)  ;// put carry into pin_was_changing
                or eax, edx
                mov [esi].pin_&letter&.dwStatus, eax;// store the new status
                xor edx, edx

            .ENDIF

        .ENDIF

        ENDM





ASSUME_AND_ALIGN
midiin_fill_Begin PROC

        ASSUME esi:PTR MIDIIN_OSC_MAP

    ;// determine fill_command for the osc
    ;// prepare all connected pins for filling
    ;// return zero flag set if no pins are connected

        xor edx, edx    ;// use for zeroing
        xor ecx, ecx    ;// use to build command

        MIDIIN_FILL_BEGIN N, 4

        MIDIIN_FILL_BEGIN V, 2

        MIDIIN_FILL_BEGIN e, 1

    ;// store the fill state (edx is still zero

        mov [esi].midiin.fill_index, ecx    ;// store the fill index
        mov [esi].midiin.fill_skew, edx     ;// reset just in case
        mov [esi].midiin.last_fill, edx     ;// reset last_fill

    ;// that should do it

        DEBUG_IF <edx !!= 0>

        test ecx, ecx   ;// see if ecx is zero (return value to caller)

        ret

midiin_fill_Begin ENDP




;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;///
;///    A D V A N C E
;///
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////

comment ~ /*

    REMEMBER:   last_fill IS A MIDI_STREAM INDEX
                ALWAYS USE *8 TO GET TO THE ADRESS

    algorithm for one pin:

        enter with:
            pPin
            new_index

        get last_fill from pPin.dwUser
        store new last_fill
        determine fill length
        dtermine where to fill
        determine what to fill with
        fill the data
        check new data against old  --> re/set pin changing

        this is small enough to put in a macro
        which also frees up a register (pPin)

        ---------------------------------------

        the indexing is tricky
        here's how it works
                        last            ecx
        8x INDEX        3               5
        4x INDEX        6               10
                --------|---|---|---|---|-------
        ADDR            24  28  32  36  40
                            |           |
                            |<--------->| length
                            start


    calculate fill length
    calculate start address
    calculate value to fill with

        start address

            no_skew     ( last_fill * 2 + 1 ) * 4 = last_fill * 8 + 4
            skew        ( last_fill * 2 + 2 ) * 4 = last_fill * 8 + 8

        fill length

            no_skew     ((new_fill-last_fill)* 2 - 1 ) * 4 = new_fill-last_fill * 8 - 4
            skew        ((new_fill-last_fill)* 2 - 2 ) * 4 = new_fill-last_fill * 8 - 8

        value to store always = [edi-4]

    if ecx is at first sample (ecx==0)

        do not fill
        no_skew , do not check changing
        yes_skew, do check changing

    if ecx = edx+1, do not fill, do check changing (lengh will equal zero)

    if ecx < last_fill, debug

*/ comment ~


    FILL_ADVANCE_PIN MACRO letter:req, count:req

        ;// edx has the start offset

        lea edi, [esi].data_&letter&[edx]
        IFDIFI <count>,<ecx>
        mov ecx, count
        ENDIF
        mov eax, [edi-4]
        rep stosd
        ;// edi is at the current sample
        ;// check for xhanging data
        .IF eax != [edi]
            or [esi].pin_&letter&.dwStatus, PIN_CHANGING
        .ENDIF

        ENDM


.DATA

    midiin_fill_advance_jump LABEL DWORD

    dd  fill_advance_
    dd  fill_advance_e
    dd  fill_advance_V
    dd  fill_advance_Ve
    dd  fill_advance_N
    dd  fill_advance_Ne
    dd  fill_advance_NV
    dd  fill_advance_NVe

    midiin_fill_advance_single_jump LABEL DWORD

    dd  fill_advance_single_
    dd  fill_advance_single_e
    dd  fill_advance_single_V
    dd  fill_advance_single_Ve
    dd  fill_advance_single_N
    dd  fill_advance_single_Ne
    dd  fill_advance_single_NV
    dd  fill_advance_single_NVe

    midiin_fill_end_jump LABEL DWORD

    dd  fill_end_
    dd  fill_end_e
    dd  fill_end_V
    dd  fill_end_Ve
    dd  fill_end_N
    dd  fill_end_Ne
    dd  fill_end_NV
    dd  fill_end_NVe

    midiin_fill_end_full_jump LABEL DWORD

    dd  fill_end_full_
    dd  fill_end_full_e
    dd  fill_end_full_V
    dd  fill_end_full_Ve
    dd  fill_end_full_N
    dd  fill_end_full_Ne
    dd  fill_end_full_NV
    dd  fill_end_full_NVe

.CODE



ASSUME_AND_ALIGN
midiin_fill_Advance PROC

    ;// destroys edi
    ;// preserves ecx, ebx, esi, ebp

        ASSUME esi:PTR MIDIIN_OSC_MAP

        test ecx, ecx   ;// do not fill index zero
        jz all_done     ;// requires that fill skew has set pin changing

        mov edx, [esi].midiin.last_fill ;// get last_fill
        xor edi, edi                    ;// use for zero
        mov eax, [esi].midiin.fill_index;// get the fill_index
        mov [esi].midiin.last_fill, ecx ;// store the new last_fill

        DEBUG_IF <ecx !< edx>   ;// can't fill backwards !!

        mov eax, midiin_fill_advance_jump[eax*4]
        sub ecx, edx                    ;// 8x total length (1 sample too long)
        cmp [esi].midiin.fill_skew, edi ;// fall through is most common state
        lea ecx, [ecx*2-1]  ;// compute usuall dword length
        lea edx, [edx*8+4]  ;// compute usual start offset

        jne use_fill_skew   ;// if skew was on, apply it

        cmp ecx, edi        ;// always check for zero fill
        je use_single_fill
        DEBUG_IF< ecx !>= SAMARY_LENGTH >   ;// ecx is too big !!
        DEBUG_IF <edx !>= SAMARY_SIZE>  ;// edx is passed end of frame !!
        jmp eax

    use_fill_skew:

        ;// use skew
        dec ecx     ;// dword length
        add edx, 4  ;// start offset
        cmp ecx, edi
        mov [esi].midiin.fill_skew, edi ;// reset use_skew
        jbe use_single_fill
        DEBUG_IF< ecx !>= SAMARY_LENGTH >   ;// ecx is too big !!
        DEBUG_IF <edx !>= SAMARY_SIZE>  ;// edx is passed end of frame !!
        jmp eax

    use_single_fill:

        mov eax, [esi].midiin.fill_index;// get the fill_index
        mov eax, midiin_fill_advance_single_jump[eax*4]

        DEBUG_IF <!!edx>    ;// edx must not equal 0 !!!
        DEBUG_IF <edx !>= SAMARY_SIZE>  ;// edx is passed end of frame !!

        jmp eax

    ;///////////////////////////////////////////////////////////////////////
    ;//
    ;//     fillers
    ;//

    ALIGN 16
    fill_advance_NVe::  ;// edx has the start offset
                        ;// ecx has the dword length
        push ebx
        mov ebx, ecx
        FILL_ADVANCE_PIN N, ecx
        FILL_ADVANCE_PIN V, ebx
        FILL_ADVANCE_PIN e, ebx
        pop ebx
        jmp all_done


    ALIGN 16
    fill_advance_NV::   ;// edx has the start offset
                        ;// ecx has the dword length
        push ebx
        mov ebx, ecx
        FILL_ADVANCE_PIN N, ecx
        FILL_ADVANCE_PIN V, ebx
        pop ebx
        jmp all_done


    ALIGN 16
    fill_advance_Ne::   ;// edx has the start offset
                        ;// ecx has the dword length
        push ebx
        mov ebx, ecx
        FILL_ADVANCE_PIN N, ecx
        FILL_ADVANCE_PIN e, ebx
        pop ebx
        jmp all_done


    ALIGN 16
    fill_advance_Ve::   ;// edx has the start offset
                        ;// ecx has the dword length
        push ebx
        mov ebx, ecx
        FILL_ADVANCE_PIN V, ecx
        FILL_ADVANCE_PIN e, ebx
        pop ebx
        jmp all_done


    ALIGN 16
    fill_advance_N::    ;// edx has the start offset
                        ;// ecx has the dword length
        FILL_ADVANCE_PIN N, ecx
        jmp all_done


    ALIGN 16
    fill_advance_V::    ;// edx has the start offset
                        ;// ecx has the dword length
        FILL_ADVANCE_PIN V, ecx
        jmp all_done


    ALIGN 16
    fill_advance_e::    ;// edx has the start offset
                        ;// ecx has the dword length
        FILL_ADVANCE_PIN e, ecx
        jmp all_done


    ;///////////////////////////////////////////////////////
    ;//
    ;//     single value tests
    ;//

    fill_advance_single_NVe::

        mov eax, [esi+edx].data_N
        cmp eax, [esi+edx-4].data_N
        je fill_advance_single_Ve
        or [esi].pin_N.dwStatus, PIN_CHANGING

    fill_advance_single_Ve::

        mov eax, [esi+edx].data_V
        cmp eax, [esi+edx-4].data_V
        je fill_advance_single_e
        or [esi].pin_V.dwStatus, PIN_CHANGING

    fill_advance_single_e::

        mov eax, [esi+edx].data_e
        cmp eax, [esi+edx-4].data_e
        je all_done
        or [esi].pin_e.dwStatus, PIN_CHANGING
        jmp all_done

    fill_advance_single_N::

        mov eax, [esi+edx].data_N
        cmp eax, [esi+edx-4].data_N
        je all_done
        or [esi].pin_N.dwStatus, PIN_CHANGING
        je all_done

    fill_advance_single_NV::

        mov eax, [esi+edx].data_N
        cmp eax, [esi+edx-4].data_N
        je fill_advance_single_V
        or [esi].pin_N.dwStatus, PIN_CHANGING

    fill_advance_single_V::

        mov eax, [esi+edx].data_V
        cmp eax, [esi+edx-4].data_V
        je all_done
        or [esi].pin_V.dwStatus, PIN_CHANGING
        jmp all_done

    fill_advance_single_Ne::

        mov eax, [esi+edx].data_N
        cmp eax, [esi+edx-4].data_N
        je fill_advance_single_e
        or [esi].pin_N.dwStatus, PIN_CHANGING
        jmp fill_advance_single_e

    ;///////////////////////////////////////////////

    ALIGN 16
    fill_advance_::
    fill_advance_single_::
    all_done:

        mov ecx, [esi].midiin.last_fill ;// retreive the index

        ret

midiin_fill_Advance ENDP









    MIDIIN_FILL_END MACRO letter:req, count:req

        ;// edx always has the start offset

        mov eax, [esi].data_&letter&[edx-4]
        lea edi, [esi].data_&letter&[edx]
        IFDIFI <count>,<ecx>
        mov ecx, count
        ENDIF
        rep stosd

        ENDM


    MIDIIN_FILL_END_FULL MACRO letter:req, exit:req

        mov eax, [esi].data_&letter&        ;// get the first sample
        .IF eax == [esi].data_&letter&[4]   ;// compare with next sample
            test [esi].pin_&letter&.dwStatus, PIN_WAS_CHANGING
            jz exit
        .ENDIF
        lea edi, [esi].data_&letter&
        mov ecx, SAMARY_LENGTH
        rep stosd

        ENDM





ASSUME_AND_ALIGN
midiin_fill_End PROC

        ASSUME esi:PTR MIDIIN_OSC_MAP

        mov edx, [esi].midiin.last_fill ;// get last_fill
        test edx, edx                   ;// check for full fill
        mov eax, [esi].midiin.fill_index
        jz use_full_end ;// requires that fill skew has set pin changing

        mov eax, midiin_fill_end_jump[eax*4]
        xor edi, edi

        mov ecx, MIDI_STREAM_LENGTH
        sub ecx, edx
        DEBUG_IF <ZERO?>    ;// not supposed to happen !!
        DEBUG_IF <CARRY?>   ;// not supposed to happen !!


        lea edx, [edx*8+4]  ;// next sample
        cmp edi, [esi].midiin.fill_skew
        lea ecx, [ecx*2-1]  ;// one less dword
        jne use_end_skew
        jmp eax

    use_end_skew:

        dec ecx
        add edx, 4
        jmp eax

    use_full_end:

        mov eax, midiin_fill_end_full_jump[eax*4]
        jmp eax

    ;///////////////////////////////////////////////

    ALIGN 16
    fill_end_NVe::  ;// ecx has dword count
                            ;// edx has offset
        push ebx
        mov ebx, ecx
        MIDIIN_FILL_END N, ecx
        MIDIIN_FILL_END V, ebx
        MIDIIN_FILL_END e, ebx
        pop ebx
        jmp all_done

    ALIGN 16
    fill_end_NV::   ;// ecx has dword count
                            ;// edx has offset
        push ebx
        mov ebx, ecx
        MIDIIN_FILL_END N, ecx
        MIDIIN_FILL_END V, ebx
        pop ebx
        jmp all_done

    ALIGN 16
    fill_end_Ne::   ;// ecx has dword count
                            ;// edx has offset
        push ebx
        mov ebx, ecx
        MIDIIN_FILL_END N, ecx
        MIDIIN_FILL_END e, ebx
        pop ebx
        jmp all_done

    ALIGN 16
    fill_end_Ve::   ;// ecx has dword count
                            ;// edx has offset
        push ebx
        mov ebx, ecx
        MIDIIN_FILL_END V, ecx
        MIDIIN_FILL_END e, ebx
        pop ebx
        jmp all_done

    ALIGN 16
    fill_end_N::        ;// ecx has dword count
                            ;// edx has offset
        MIDIIN_FILL_END N, ecx
        jmp all_done

    ALIGN 16
    fill_end_V::        ;// ecx has dword count
                            ;// edx has offset
        MIDIIN_FILL_END V, ecx
        jmp all_done

    ALIGN 16
    fill_end_e::        ;// ecx has dword count
                            ;// edx has offset
        MIDIIN_FILL_END e, ecx
        jmp all_done

    ;///////////////////////////////////////////////


    fill_end_full_NVe::

        MIDIIN_FILL_END_FULL N, fill_end_full_Ve

    fill_end_full_Ve::

        MIDIIN_FILL_END_FULL V, fill_end_full_e

    fill_end_full_e::

        MIDIIN_FILL_END_FULL e, all_done
        jmp all_done

    fill_end_full_Ne::

        MIDIIN_FILL_END_FULL N, fill_end_full_e
        jmp fill_end_full_e

    fill_end_full_NV::

        MIDIIN_FILL_END_FULL N, fill_end_full_V

    fill_end_full_V::

        MIDIIN_FILL_END_FULL V, all_done
        jmp all_done

    fill_end_full_N::

        MIDIIN_FILL_END_FULL N, all_done

    ALIGN 16
    fill_end_::
    fill_end_full_::
    all_done:

        ret

midiin_fill_End ENDP


















ASSUME_AND_ALIGN

END

