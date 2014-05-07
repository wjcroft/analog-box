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
;// auto_unit.inc       definition for all things that apply to units
;//
comment ~ /*

    Knobs and readout should have an auto unit mode

    pin_color   units

    default     Value   Sample  dB      Interval
    logic       logic
    frequency   Hertz   Seconds Note    BPM
    spectrum    Bin
    midi        Midi


    units       pin color

    Value       default
    Hertz       frequency
    Seconds     frequency
    Note        frequency
    Sample      default
    Bin         spectrum
    Midi        midi
    Logic       logic
    BPM         frequency
    dB          default
    Note        frequency
    Interval    default



    there are 12 bits available for use

    pin color needs 4 of them   0-4 for the color, 1 for fixed

    then there are 8 more not being used


---------------------------------------------------------------------

    goal:       knobs and readouts should be able to determine what unit to display
                connections should be able to determine what colors they are

    solution:   A trace operation is required to do this

    obsticals:  when to trace
                how to signal the trace
                how to do the trace

--------------------------------------------------------------------

Facts:

    There are 6 signal colors

        these are indexed by GDI_COLOR_ values

    There are 12+ units plus one bit for auto

        these are defined by KNOB_UNIT_ value
        and indexed by an implied order

Tasks:

    To set a pin color from a unit, we need an xlate table
    To do a trace to determine the unit, pin's must be assigned trace flags


UNIT TRACING

    unit tracing is triggered on a per context bassis
    unit_AutoTrace does the work of trannsferring units from pin to pin
    each osc must help out by telling unit_AutoTrace wheather or not
    a unit can be transferring THROUGH an osc


PIECES (per osc)

    osc.display_params  display data revelant to the osc

    osc.base.data.dwFlags   BASE_HAS_AUTO_UNITS

    osc.dwUser          AUTO_UNIT_TRACE
                        UNIT_AUTO_UNIT
                        UNIT_XXXX

    osc.pin_1.dwStatus  UNIT_AUTO_UNIT
    ...                 UNIT_XXXX
    osc.pin_N.dwStatus  UNIT_AUTOED

HELPER FUNCTIONS

    pin_SetUnit
    pin_SetNameAndUnit

DATA ACCESS POINTS AND HANDLERS

    osc.Ctor
    osc.Command
    osc.LoadUndo

        set dwUser with desired unit
        use pin_SetUnit the set pins as either AUTO_UNIT or a UNIT_XXXX
            pin_SetUnit will invalidate the pin
            pin_SetUnit will schedule an auto trace
        if dwUser is a FIXED unit,
            osc must build display parameters
            or set a flag to be handled during osc.Render
        if dwUser is AUTO_UNIT
            unit_AutoTrace will set the units
            if osc.base is BASE_HAS_AUTO_UNITS
                osc must not rely on display parameters yet
                unit_AutoTrace will set osc.dwUser with UNIT_AUTO_TRACE
                osc must then respond at osc.Render by setting display parameters

    osc.Render

        if osc.base is BASE_HAS_AUTO_UNITS
        unit_AutoTrace will set osc.dwUser with UNIT_AUTO_TRACE
        if osc.dwUser has UNIT_AUTO_UNIT
            osc must respond by setting display parameters
            if UNIT_AUTO_TRACE is NOT set
                osc must display 'auto'
            if UNIT_AUTO_TRACE IS set
                osc must look at units on pins
                if UNIT_AUTOED is ON
                    osc can use that pin's unit for it's display
                if no UNIT_AUTOED's are on
                    osc must display 'auto'

    osc.GetUnit

        only called from unit_AutoTrace
        this will only be called IF
            UNIT_AUTO_UNIT is set
            UNIT_AUTOED is not set

        the osc must determine what the unit for that pin should be
        if it succeeds
            return unit in eax (extra bits are acceptable)
            set the carry flag to indicate success
        if it fails
            reset the carry flag, eax will be ignored

        if osc.GetUnit succeeds
            it will set the pin's units
            if osc.base is BASE_HAS_AUTO_UNITS
                unit_AutoTrace will set osc.dwUser with UNIT_AUTO_TRACE
                osc must then respond at osc.Render by setting display parameters

*/ comment ~

    ;// OLD VERSION taking up too much bit space

        UNIT_OLD_VALUE      EQU 00000000h   ;// just for clarity
        UNIT_OLD_HERTZ      EQU 00000100h
        UNIT_OLD_SECONDS    EQU 00000200h
        UNIT_OLD_NOTE       EQU 00000400h
        UNIT_OLD_TEMPO      EQU 00000800h
        UNIT_OLD_INTERVAL   EQU 00001000h
        UNIT_OLD_DB         EQU 00002000h
        UNIT_OLD_MIDI_OLD   EQU 00004000h
        UNIT_OLD_MIDI_NEW   EQU 02004000h
        UNIT_OLD_SAMPLES    EQU 00008000h
        UNIT_OLD_METER      EQU 04000000h   ;// used by the readout
        UNIT_OLD_LOGIC      EQU 08000000h

        UNIT_OLD_BINS       EQU 10000000h
        UNIT_OLD_AUTO       EQU 20000000h

        UNIT_OLD_MASK      EQU 0C1FF00FFh
        UNIT_OLD_TEST       EQU 3E00FF00h   ;// use to determine if unit needs changed

    ;// new version
    ;// NOTE these apply to the knob, readout, AND THE APIN
    ;// again, BEWARE OF CHANGING THESE

        UNIT_AUTO_UNIT      EQU 00000800h   ;// osc and pin ;
        ;// DON'T MOVE THIS (UNIT_TO_ID requires that bit be below other units

        ;// if AUTO is off, the stated unit is not to be changed
        ;// if AUTO is on, the unit may be changed as long as AUTOED is off
        ;// if the unit is changed, turn AUTOED on

        UNIT_VALUE          EQU 00000000h   ;// 0   osc and pin ;
        UNIT_INTERVAL       EQU 00001000h   ;//*1
        UNIT_DB             EQU 00002000h   ;//*2       indexes ....
        UNIT_HERTZ          EQU 00003000h   ;// 3       these are also stored in knob dwuser
        UNIT_MIDI           EQU 00004000h   ;//*4       DO NOT CHANGE
        UNIT_SECONDS        EQU 00005000h   ;// 5
        UNIT_NOTE           EQU 00006000h   ;// 6   * these are set so some units line up
        UNIT_BPM            EQU 00007000h   ;// 7     with the old units (shown above)
        UNIT_SAMPLES        EQU 00008000h   ;//*8
        UNIT_LOGIC          EQU 00009000h   ;// 9
        UNIT_BINS           EQU 0000A000h   ;// A
        UNIT_DEGREES        EQU 0000B000h   ;// B
        UNIT_PANNER         EQU 0000C000h   ;// C
        UNIT_PERCENT        EQU 0000D000h   ;// D
        UNIT_2xHERTZ        EQU 0000E000h   ;// E   ABox219, used by file object
        UNIT_MIDI_STREAM    EQU 0000F000h   ;// F   ABox 220, MIDI_STREAM
        UNIT_SPECTRUM       EQU 00010000h   ;// 10  ABox 221

        UNIT_TEST           EQU 0001F000h   ;// there is another bit available if needed

        UNIT_AUTOED         EQU 00020000h   ;// osc and pin - indicates that a unit is known for this pin

        UNIT_AUTO_TRACE     EQU 00040000h   ;// osc only, tells osc it' time to figure it out
                            ;// this flag tells the osc that one of its pin's units has been
                            ;// changed and that the object should update it's display
                            ;// only valid if BASE_HAS_AUTO_UNITS is set

        MAX_NUM_UNITS   EQU 32

    comment ~ /*

        some UI details of AUTO_UNIT

        a unit has three parts

            AUTO    1 bit   <-- set by user
            AUTOED  1 bit   <-- set by app
            UNIT    5 bits  <-- set by ???

        unit display:

            if AUTO
                if AUTOED
                    use UNIT
                else
                    locate a unit to use
                endif
            else
                use supplied UNIT
            endif

        unit manipulation from parser:

            NUMBER

                use available UNIT

            NUMBER UNIT

                if UNIT != AUTO
                    set new UNIT
                else
                    use available unit
                endif

            NUMBER UNIT AUTO

                process as NUMBER UNIT
                set units to AUTO

    */ comment ~





    ;// this table helps out from time to time

        UNIT_INDEX_VALUE        EQU 00h
        UNIT_INDEX_INTERVAL     EQU 01h
        UNIT_INDEX_DB           EQU 02h
        UNIT_INDEX_HERTZ        EQU 03h
        UNIT_INDEX_MIDI         EQU 04h
        UNIT_INDEX_SECONDS      EQU 05h
        UNIT_INDEX_NOTE         EQU 06h
        UNIT_INDEX_BPM          EQU 07h
        UNIT_INDEX_SAMPLES      EQU 08h
        UNIT_INDEX_LOGIC        EQU 09h
        UNIT_INDEX_BINS         EQU 0Ah
        UNIT_INDEX_DEGREES      EQU 0Bh
        UNIT_INDEX_PANNER       EQU 0Ch
        UNIT_INDEX_PERCENT      EQU 0Dh
        UNIT_INDEX_2xHERTZ      EQU 0Eh
        UNIT_INDEX_MIDI_STREAM  EQU 0Fh
        UNIT_INDEX_SPECTRUM     EQU 10h

        UNIT_MAXIMUM_INDEX      EQU 10h ;// max index


;////////////////////////////////////////////////////////////////////
;//
;//
;//     external data   defined in auto_unit.asm
;//

        EXTERNDEF unit_pin_color:DWORD  ;// translate unit indexes to pin colors
        EXTERNDEF unit_to_id:DWORD      ;// xlates a unit to it's control id
        EXTERNDEF unit_from_id:DWORD    ;// retieves a unit from its id
        EXTERNDEF unit_label:DWORD      ;// table of text labels
        EXTERNDEF knob_new_midi_scale:REAL4 ;// used by xlate

    ;// functions

        unit_BuildString PROTO STDCALL pBuffer:DWORD, dwUnits:DWORD, dwFmtFlags:DWORD

            UBS_NO_SEP_EXP      EQU 00000001h   ;// do not put a space between value and exp
            UBS_APPEND_NEG      EQU 00000002h   ;// for db int and note, add a neg suffix
                                                ;// if raw value is negative

        unit_UpdateComboBox PROTO STDCALL dwID:DWORD, bIsKnob:DWORD
                                ;// initializes a combo box on the popup panel

        unit_HandleComboSelChange PROTO STDCALL dwID:DWORD, dwUnit:DWORD, bIsKnob:DWORD
                                ;// updates help text on combo box

        unit_FromKeystroke PROTO;// returns a unit in edx, or carry flag

        unit_ConvertOld PROTO   ;// generic routine to update units in new version

        unit_AutoTrace PROTO    ;// shove units around the circuit



;////////////////////////////////////////////////////////////////////
;//
;//                 UNIT_TO_COLOR
;//     MACROS      PIN_TO_COLOR
;//


    UNIT_TO_PIN_COLOR MACRO reg:req

        ;// convert unit to filled color
        ;// note that the color is a desk color

        BITSHIFT reg, UNIT_INTERVAL, 4
        mov reg, unit_pin_color[reg]

        ENDM


    PIN_TO_UNIT_COLOR MACRO pin:req, reg:req

        ;// convert the pins dwStatus.unit to the filled color
        ;// pin must be assumed as an APIN

        mov reg, [ebx].dwStatus
        and reg, UNIT_TEST

        UNIT_TO_PIN_COLOR reg

        ENDM






