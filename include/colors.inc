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
;// colors.inc      definitons of the system colors
;//
comment ~ /*

    purpose:    to be able to quickly rearrange and modify the color defintions
                while in the developement process

    this is a dual purpose file
    1) is to define all the system colors
    2) is to specify the gdi wrapper structures

    since the two functionalities are seriously intermingled
    it is very tedious to manage the files seperately

    so:

        include the file anywhere color defines are needed

        for the actual data initilialization
        define COLORS_ASM = YES before including
        this will create the space for the GDI WRAPPERS

        that way the same file can be included twice

*/ comment ~



;// we start with the system colors

color_index_macro = 0   ;// keeps track of the colors

COLOR_DEF MACRO name:req, resources, dependants

    IFDEF COLORS_ASM
    GDI_WRAPPER { resources, dependants }
    ;ELSE
    ENDIF

    name EQU color_index_macro

    F_&name EQU (color_index_macro)         +   \
                (color_index_macro SHL 8)   +   \
                (color_index_macro SHL 16)  +   \
                (color_index_macro SHL 24)

    color_index_macro = color_index_macro+1

    ENDM


;////////////////////////////////////////////////////////////////////
;//
;//                         these must always be arranged in groups
;//     color definitions   so that a constant offset can be added to get
;//                         from one group to another

;// group A, colors that test as hitting the desk

;//macro    index name          rsrcs to build                      dependant colors (use <> for multiple)
;//------   ----------------    --------------------------------    --------------------------------

;// system colors
; 0
COLOR_DEF   COLOR_DESK_BACK,    GDIW_PEN_3+GDIW_BRUSH,              <COLOR_PIN_BACK,COLOR_OSC_BACK>
COLOR_DEF   COLOR_DESK_TEXT,    GDIW_BRUSH,                         COLOR_PIN_TEXT
COLOR_DEF   COLOR_DESK_HOVER,   GDIW_BRUSH+GDIW_PEN_1+GDIW_PEN_3,   <COLOR_PIN_HOVER,COLOR_OSC_HOVER>
COLOR_DEF   COLOR_DESK_BAD,     GDIW_BRUSH+GDIW_PEN_1+GDIW_PEN_3,   <COLOR_PIN_BAD, COLOR_OSC_BAD>
COLOR_DEF   COLOR_DESK_GOOD,    GDIW_PEN_1+GDIW_PEN_3,              COLOR_PIN_GOOD
;// signal colors
; 5
COLOR_DEF   COLOR_DESK_DEFAULT, GDIW_BRUSH+GDIW_PEN_1+GDIW_PEN_3,   COLOR_PIN_DEFAULT
COLOR_DEF   COLOR_DESK_MIDI,    GDIW_BRUSH+GDIW_PEN_1+GDIW_PEN_3,   COLOR_PIN_MIDI
COLOR_DEF   COLOR_DESK_FREQUENCY,GDIW_BRUSH+GDIW_PEN_1+GDIW_PEN_3,  COLOR_PIN_FREQUENCY
COLOR_DEF   COLOR_DESK_LOGIC,   GDIW_BRUSH+GDIW_PEN_1+GDIW_PEN_3,   COLOR_PIN_LOGIC
COLOR_DEF   COLOR_DESK_SPECTRAL,GDIW_BRUSH+GDIW_PEN_1+GDIW_PEN_3,   COLOR_PIN_SPECTRAL
COLOR_DEF   COLOR_DESK_STREAM,  GDIW_BRUSH+GDIW_PEN_1+GDIW_PEN_3,   COLOR_PIN_STREAM    ;// added abox220

;// osc effects colors
; 11
COLOR_DEF   COLOR_DESK_SELECTED,GDIW_BRUSH
COLOR_DEF   COLOR_DESK_LOCKED,  GDIW_BRUSH
COLOR_DEF   COLOR_DESK_GROUPED, GDIW_PEN_1

;// group B, pin colors, these hit test as hitting a pin
;//         keep these in the same order that group A is in

;// system colors dependent
; 14
COLOR_DEF   COLOR_PIN_BACK,     GDIW_BRUSH+GDIW_FONT
COLOR_DEF   COLOR_PIN_TEXT,     GDIW_FONT
COLOR_DEF   COLOR_PIN_HOVER,    GDIW_FONT
COLOR_DEF   COLOR_PIN_BAD,      GDIW_FONT
COLOR_DEF   COLOR_PIN_GOOD,     GDIW_FONT
;// signal colors
COLOR_DEF   COLOR_PIN_DEFAULT,  GDIW_FONT
COLOR_DEF   COLOR_PIN_MIDI,     GDIW_FONT
COLOR_DEF   COLOR_PIN_FREQUENCY,GDIW_FONT
COLOR_DEF   COLOR_PIN_LOGIC,    GDIW_FONT
COLOR_DEF   COLOR_PIN_SPECTRAL, GDIW_FONT
COLOR_DEF   COLOR_PIN_STREAM,   GDIW_FONT   ;// added abox220
    COLOR_LOWEST_PIN    EQU COLOR_PIN_BACK
    COLOR_HIGHEST_PIN   EQU COLOR_PIN_STREAM

;// group C, osc colors, these hit test as hitting an osc
; 25
COLOR_DEF   COLOR_OSC_BACK,     GDIW_BRUSH
COLOR_DEF   COLOR_OSC_TEXT,     GDIW_BRUSH
COLOR_DEF   COLOR_OSC_1,        GDIW_BRUSH
COLOR_DEF   COLOR_OSC_2,        GDIW_BRUSH+GDIW_PEN_1
COLOR_DEF   COLOR_OSC_BAD,      GDIW_BRUSH
COLOR_DEF   COLOR_OSC_HOVER

    COLOR_LOWEST_OSC    EQU COLOR_OSC_BACK

    COLOR_SYSTEM_MAX    EQU color_index_macro


;// these are needed for hit testing and referencing signal colors
IFNDEF COLORS_ASM


ENDIF


;//
;//
;//
;//
;////////////////////////////////////////////////////////////////////



;// then cover the group colors

    ;// oBmp_palette is defined in object_bitmap.inc

    COLOR_GROUP_CONTROLS    equ 020h    ;// the first color in the controls
    COLOR_GROUP_GENERATORS  equ 040h    ;// the first color in the generators
    COLOR_GROUP_ROUTERS     equ 060h    ;// the first color in the routers
    COLOR_GROUP_PROCESSORS  equ 080h    ;// the first color in the processors
    COLOR_GROUP_DEVICES     equ 0A0h    ;// the first color in the devices
    COLOR_GROUP_DISPLAYS    equ 0C0h    ;// the first color in the displays


    F_COLOR_GROUP_CONTROLS      equ 020202020h  ;// the first color in the controls
    F_COLOR_GROUP_GENERATORS    equ 040404040h  ;// the first color in the generators
    F_COLOR_GROUP_ROUTERS       equ 060606060h  ;// the first color in the routers
    F_COLOR_GROUP_PROCESSORS    equ 080808080h  ;// the first color in the processors
    F_COLOR_GROUP_DEVICES       equ 0A0A0A0A0h  ;// the first color in the devices
    F_COLOR_GROUP_DISPLAYS      equ 0C0C0C0C0h  ;// the first color in the displays

    ;// add these to get he last color in the group

    COLOR_GROUP_LAST            equ     1Fh     ;// NOT A COLOR
    F_COLOR_GROUP_LAST          equ  1F1F1F1Fh  ;// NOT A COLOR,



