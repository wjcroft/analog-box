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
;// ABox_Knob.inc       common defintions for the knob
;//                     revised substatially in ABox228



;//////////////////////////////////////////////////////////////////
;//
;//                     these are somewhat dependant on the graphic
;//     MASTER SIZES
;//

        KNOB_SIZE_X             equ 44  ;// copy from vr\knob\knob.inc
        KNOB_SIZE_Y             equ 52  ;// copy from vr\knob\knob.inc

        KNOB_VALUE_HEIGHT       equ 10

        KNOB_HOVER_RADIUS_IN    equ 14  ;// radius of the inner hover
        KNOB_HOVER_RADIUS_OUT   equ 21  ;// radius of the outter hover

        KNOB_SIGN_MARGIN_X      equ 18  ;// offset from center
        KNOB_SIGN_MARGIN_Y      equ 6   ;// offset from center

        KNOB_PLUS_MINUS_THRESHOLD equ 6

        KNOB_TAPER_MARGIN_X     equ 4   ;// offset form outside edge to center
        KNOB_TAPER_MARGIN_Y     equ 6   ;// offset from bottom edge to ceneter


;//
;//     MASTER SIZES
;//
;//
;//////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////
;//
;//
;//     derived values
;//


        KNOB_OC_X           equ KNOB_SIZE_X / 2
        KNOB_OC_Y           equ KNOB_SIZE_Y - KNOB_OC_X

;//
;//     derived values
;//
;//
;////////////////////////////////////////////////////////////////////



    ;// extern def for the two font shapes, needed by the slider and the knob

        EXTERNDEF pFont_add:DWORD   ;// both defined in abox_knob.inc
        EXTERNDEF pFont_mul:DWORD

;// helpers

    knob_log_turns_to_turns PROTO STDCALL dwLogTurns:DWORD


;// string conversion routines

    ;// convert all settings a string
    knob_BuildCommandString PROTO STDCALL pString:DWORD, dwUser:DWORD, dwValue:DWORD

    ;// convert string to settings
    knob_ProcessCommandString PROTO STDCALL pString:DWORD



;//
;// OSC_OBJECT.dwUser
;//

                            ;//        X
        KNOB_TAPER_LINEAR   EQU 00000000h ;// included for clarity
        KNOB_TAPER_AUDIO    EQU 00000008h ;// set for audio taper
        KNOB_TAPER_TEST     EQU KNOB_TAPER_AUDIO

                            ;//       X
        KNOB_MODE_KNOB      EQU 00000000h   ;// included for clarity
        KNOB_MODE_MULT      EQU 00000010h   ;// used by the math control
        KNOB_MODE_ADD       EQU 00000020h
        KNOB_SMALL          EQU 00000040h   ;// display as small (no control)
        KNOB_WRAP           EQU 00000080h   ;// on for wrap around, otherwise we stop

        KNOB_MODE_TEST      EQU KNOB_MODE_MULT OR KNOB_MODE_ADD

                            ;//    XXX
        KNOB_UNIT_TEST      EQU 000FF800h   ;// DO NOT USE THESE BITS
                                            ;// same as UNIT_TEST OR UNIT_AUTO_UNIT
                            ;//   X
        KNOB_PRESET_TEST    EQU 00F00000h   ;// index or zero

                            ;// XX
        KNOB_TURNS_TEST    EQU 0FF000000h   ;// 1 byte 0-255

        knob_turns_scale    TEXTEQU <math_12>
        knob_1_turns_scale  TEXTEQU <math_1_12>




;//
;// the OSC_KNOB STRUCT
;//

    ;// to implement all this, knob objects use the following struct as the first item
    ;// of their data block.
    ;//
    ;// the first section is stored in the file

        KNOB_SETTINGS STRUCT

            dwUser          dd  0   ;// see below
            value2          dd  0

        KNOB_SETTINGS ENDS  ;// 8 bytes and there are 8 of them


        KNOB_DATA struct

        ;// values and behavior

        ;// STORED

            value2  REAL4 0.0e+0    ;// value at end of calc, this gets stored, [-1:+1]
                                    ;// this value is ALWAYS correct regardless of the taper
            config  KNOB_SETTINGS 8 DUP ({}) ;// preset configurations (indexed)

            not_used_228_0  dd  0   ;// added ABox228, pad for later,
            not_used_228_1  dd  0   ;// so we can quickly add pins and not waste time

        ;// NOT STORED

            value1  REAL4 0.0e+0    ;// value at start of a calc, previous value

            turns_scale     REAL4 0.0e+0    ;// scaling factor:
            turns_angle     REAL4 0.0e+0    ;// this is what gets controlled and displayed
            turns_current   dd  0           ;// current number of turns
            max_turns       dd  0           ;// current number of maximum turns, used to build text

        ;// flags

            dwFlags         dd  0   ;// display flags

            KNOB_OUTTER_HOVER   EQU 00000001h   ;// true if have outter hover
            KNOB_NEW_VALUE      EQU 00000002h   ;// value has been changed
            KNOB_NEW_TAPER      EQU 00000004h   ;// taper has been changed
            KNOB_NEW_TURNS      EQU 00000008h   ;// log turns has been changed
            KNOB_NEW_AUTO       EQU 00000010h   ;// auto units has been set
            KNOB_NEW_UNITS      EQU 00000020h   ;// units have changed
            KNOB_NEW_MODE       EQU 00000040h   ;// mode has changed
            KNOB_NEW_CONTROL    EQU 00000080h   ;// need a new control layout

            KNOB_NEW_TEST       EQU 000000FEh   ;// all of them

        ;// drawing positions

            middleArm       POINT {}    ;// center of the arms
            controlArm      POINT {}    ;// location of the END of the control arm
            displayArm      POINT {}    ;// location of the END of the display arm
            hoverRect_out   RECT  {}    ;// outer control rectangle, used to draw pie slice
            valueRect       RECT  {}    ;// rect to display the value in

            center_text     RECT  {}    ;// 0 height rect for drawing units and turns

        ;// text buffers

            text            db 32 dup (0)   ;// text of label

            lenTextValue    dd  0   ;// length of the value portion
            lenTextUnit     dd  0   ;// length of the unit portion

            max_turns_text  db 8 dup (0)    ;// %ix or %iK

        ;// shape pointers

            pTaperShape     dd  0   ;// shape to draw for taper
            pModeShape      dd  0   ;// plus, mult, or none

            pSignShape      dd  0   ;// shape for the sign
            pSignOffset     dd  0   ;// where to draw it, realitive to the osc

        KNOB_DATA ends

    ;// osc map for this object

        OSC_KNOB_MAP STRUCT

            OSC_OBJECT {}

            pin_X APIN {}
            pin_I APIN {}

            data_x dd SAMARY_LENGTH dup (0)

            knob KNOB_DATA {}

        OSC_KNOB_MAP ENDS

