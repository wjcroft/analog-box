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
;//     containers.asm
;//

OPTION CASEMAP:NONE
.586
.MODEL FLAT
    .NOLIST
    INCLUDE <Abox.inc>
    INCLUDE <triangles.inc>
    .LIST

;/////////////////////////////////////////////////////////////////////////////
;//
;//
;//     PREDEFINED SHAPES AND CONTAINERS
;//

.DATA

    ;// point list for gate shape

    gate_radius     TEXTEQU <4.5>
    gate_radius_1   TEXTEQU <4.6>

    gate_shape_points LABEL fPOINT

        fPOINT { gate_radius, -3.141592653e+0 }
        fPOINT { gate_radius_1, -1.570796327e+0 }
        fPOINT { gate_radius_1, 0.0e+0 }
        fPOINT { gate_radius_1,  1.570796327e+0 }

    ;// shape definitions for all six logic shapes

    shape_trig_both GDI_SHAPE { \
        SHAPE_IS_CIRCLE OR SHAPE_MOVE_DST_OC OR SHAPE_MOVE_SRC_OC OR SHAPE_BUILD_OUT1 OR SHAPE_NO_ROUND_ADJUST,
        {},
        {@REAL(PIN_LOGIC_RADIUS),@REAL(PIN_LOGIC_RADIUS)},
        shape_trig_pos, TRIG_BOTH_PSOURCE }

    shape_trig_pos  GDI_SHAPE { \
        SHAPE_IS_CIRCLE OR SHAPE_MOVE_DST_OC OR SHAPE_MOVE_SRC_OC OR SHAPE_BUILD_OUT1 OR SHAPE_NO_ROUND_ADJUST,
        {},
        {@REAL(PIN_LOGIC_RADIUS),@REAL(PIN_LOGIC_RADIUS)},
        shape_trig_neg, TRIG_POS_PSOURCE }

    shape_trig_neg  GDI_SHAPE { \
        SHAPE_IS_CIRCLE OR SHAPE_MOVE_DST_OC OR SHAPE_MOVE_SRC_OC OR SHAPE_BUILD_OUT1 OR SHAPE_NO_ROUND_ADJUST,
        {},
        {@REAL(PIN_LOGIC_RADIUS),@REAL(PIN_LOGIC_RADIUS)},
        shape_gate_both, TRIG_NEG_PSOURCE }

    shape_gate_both GDI_SHAPE { \
        SHAPE_IS_POLYGON OR 4 OR SHAPE_MOVE_DST_OC OR SHAPE_MOVE_SRC_OC OR SHAPE_BUILD_OUT1,
        {OFFSET gate_shape_points},
        {gate_radius,gate_radius},
        shape_gate_pos, GATE_POS_PSOURCE }

    shape_gate_pos  GDI_SHAPE { \
        SHAPE_IS_POLYGON OR 4 OR SHAPE_MOVE_DST_OC OR SHAPE_MOVE_SRC_OC OR SHAPE_BUILD_OUT1,
        {OFFSET gate_shape_points},
        {gate_radius,gate_radius},
        shape_gate_neg, GATE_POS_PSOURCE }

    shape_gate_neg  GDI_SHAPE { \
        SHAPE_IS_POLYGON OR 4 OR SHAPE_MOVE_DST_OC OR SHAPE_MOVE_SRC_OC OR SHAPE_BUILD_OUT1,
        {OFFSET gate_shape_points},
        {gate_radius,gate_radius},
        shape_pin_font, GATE_NEG_PSOURCE }

    ;// pin font background shape

    shape_pin_font  GDI_SHAPE { \
        SHAPE_IS_CIRCLE OR SHAPE_MOVE_DST_OC OR SHAPE_BUILD_OUT1,
        {},
        {@REAL(PIN_FONT_RADIUS),@REAL(PIN_FONT_RADIUS)},
        shape_bus }

    ;// bus

    shape_bus   GDI_SHAPE { \
        SHAPE_IS_CIRCLE OR SHAPE_MOVE_DST_OC OR SHAPE_BUILD_OUT1,
        {},
        { @REAL(PIN_BUS_RADIUS), @REAL(PIN_BUS_RADIUS) },
        button_control }


    ;// this is the shape for the button

    BUTTON_CONTROL_points LABEL fPOINT
        fPOINT {1.493783e+001,-2.522640e+000}
        fPOINT {1.400397e+001,-6.673061e-001}
        fPOINT {1.269296e+001,5.224034e-001}
        fPOINT {1.371637e+001,2.661642e+000}

    button_control GDI_SHAPE { SHAPE_RGN_OFS_OC OR SHAPE_IS_POLYGON OR 4 OR SHAPE_BUILD_OUT1,
        {OFFSET BUTTON_CONTROL_points},
        {1.216667e+001,8.666667e+000},knob_shape_hover_in}


    ;// these are the graphics needed to display the knob


    ;// shape for the control

    INCLUDE <ABox_knob.inc>

    ;// this draws the hover circle
    ;// a mask is not needed.....

    KNOB_SHAPE_HOVER_FLAGS EQU SHAPE_IS_CIRCLE OR SHAPE_RGN_OFS_OC OR SHAPE_MOVE_DST_SIZ OR SHAPE_BUILD_OUT1 OR SHAPE_NO_ROUND_ADJUST


    knob_shape_hover_in GDI_SHAPE {KNOB_SHAPE_HOVER_FLAGS ,{},
                {@REAL(KNOB_HOVER_RADIUS_IN), @REAL(KNOB_HOVER_RADIUS_IN) },
                knob_shape_hover_out,,{{@REAL(KNOB_HOVER_RADIUS_IN-KNOB_OC_X), @REAL(KNOB_HOVER_RADIUS_IN-KNOB_OC_Y) }} }

    knob_shape_hover_out GDI_SHAPE {KNOB_SHAPE_HOVER_FLAGS ,{},
                {@REAL(KNOB_HOVER_RADIUS_OUT), @REAL(KNOB_HOVER_RADIUS_OUT) },
                knob_shape_mask,,{{@REAL(KNOB_HOVER_RADIUS_OUT-KNOB_OC_X), @REAL(KNOB_HOVER_RADIUS_OUT-KNOB_OC_Y) }} }

    ;// for filling the center to leave blank space for the label

    KNOB_MASK_RADIUS EQU KNOB_HOVER_RADIUS_IN+3

    knob_shape_mask GDI_SHAPE { SHAPE_IS_CIRCLE OR SHAPE_RGN_OFS_OC OR SHAPE_MOVE_DST_SIZ,
                {}, {@REAL(KNOB_MASK_RADIUS), @REAL(KNOB_MASK_RADIUS+2) },
                first_container,,{{@REAL(-(KNOB_OC_X-KNOB_MASK_RADIUS)), @REAL(KNOB_MASK_RADIUS-KNOB_OC_Y+1) }} }

comment ~ /*
    knob_shape_hover_in GDI_SHAPE {KNOB_SHAPE_HOVER_FLAGS ,{},
                {@REAL(KNOB_HOVER_RADIUS_IN), @REAL(KNOB_HOVER_RADIUS_IN) },
                knob_shape_hover_out,,{{@REAL(KNOB_HOVER_RADIUS_IN-KNOB_OC_X), @REAL(KNOB_HOVER_RADIUS_IN-KNOB_OC_Y) }} }

    knob_shape_hover_out GDI_SHAPE {KNOB_SHAPE_HOVER_FLAGS ,{},
                {@REAL(KNOB_HOVER_RADIUS_OUT), @REAL(KNOB_HOVER_RADIUS_OUT) },
                knob_shape_mask,,{{@REAL(KNOB_HOVER_RADIUS_OUT-KNOB_OC_X), @REAL(KNOB_HOVER_RADIUS_OUT-KNOB_OC_Y) }} }

    ;// for filling the center to leave blank space for the label
    knob_shape_mask GDI_SHAPE { SHAPE_IS_CIRCLE OR SHAPE_RGN_OFS_OC OR SHAPE_MOVE_DST_SIZ, ;// OR SHAPE_BUILD_OUT1,
                {}, {@REAL(KNOB_MASK_RADIUS), @REAL(KNOB_MASK_RADIUS) },
                first_container,,{{@REAL(-(KNOB_OC_X-KNOB_MASK_RADIUS+1)), @REAL(KNOB_MASK_RADIUS-KNOB_OC_Y) }} }
*/ comment ~


;//
;//     PREDEFINED SHAPES AND CONTAINERS
;//
;//
;/////////////////////////////////////////////////////////////////////////////

;/////////////////////////////////////////////////////////////////////////////
;//
;//
;//     the rest of the containers
;//

include <knob\knob.asm>
include <noise\noise.asm>
include <r_rect\r_rect.asm>
include <circle\circle.asm>
include <t_left\dplex.asm>

include <t_rite\mplex.asm>
include <devices\devices.asm>
include <oval\filter\filter.asm>
include <prism\prism.asm>
include <prism\fftop.asm>

include <button\button.asm>

include <display_palette.asm>

include <iir\iir.asm>

include <qkey\qkey.asm>

include <sh\sh.asm>
include <mixer\mixer.asm>

include <slider\slider_h.asm>
include <slider\slider_v.asm>

include <group\pinint.asm>



;//
;//
;//     the rest of the containers
;//
;/////////////////////////////////////////////////////////////////////////////

.CODE

ASSUME_AND_ALIGN


END