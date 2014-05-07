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
;//     triangles.inc       definition of the pin connection assembly mechanism
;//

;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;//
;//     GENERAL PIN LAYOUT PARAMETERS
;//
;//

        PIN_TRIANGLE_RADIUS EQU 8   ;// distance from T0 to base
        PIN_TRIANGLE_HEIGHT EQU 3   ;// height of each side

        PIN_LOGIC_RADIUS    EQU 5   ;// radius of logic shapes
        PIN_FONT_RADIUS     EQU 6   ;// drawing radius of the label
        PIN_BUS_RADIUS      EQU 8   ;// radius of bus circles
        PIN_SPLINE_RADIUS   EQU 16  ;// length of bezier control arms

        PIN_BUS_ADJUST      EQU 2   ;// overlap font and bus circles by this much


;//
;//
;//     then we derive many more values in ABox_Pin.asm
;//
;//
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////


comment ~ /*
;////////////////////////////////////////////////////////////////////////////
;//
;//                         extra layout geomemtry is stored in these records
;//     TRIANGLE_SHAPE      simplifies and streamlines rendering, hit testing
;//                         and auto layout


pieces: relative sizes approximate

    L   logic shape     |-log-|             LOGIC_RADIUS
    T   triangle        |--tri--|           TRIANGLE_RADIUS
    F   font            |--font--|          FONT_RADIUS
    B   bus shape       |---bus---|         BUS_RADIUS
    S   spline          |-----spline-----|  SPLINE_RADIUS


configuarations we will see:

    TFS analog input connection     |--tri--||--font--||-----spline-----|
    LFS logic input connection      |-log-||--font--||-----spline-----|
    TFB analog input bussed         |--tri--||--font--||---bus---|
    LFB logic input bussed          |-log-||--font--||---bus---|

    FS  output connection           |--font--||-----spline-----|
    FB  output bussed               |--font--||---bus---|

    TF  analog input unconnect      |--tri--||--font--|
    LF  logic input unconnect       |-log-||--font--|
    FT  output unconnect            |--font--||--tri--| <<-- points backwards, use negative offset

geometry needed (sorted list)
                        t0
                        |                  t3---------------dt      dt always the same
    TFS                 |--tri--||--font--||-----spline-----|
    TFB                 |--tri--||--font--||---bus---|
    TF                  |--tri--||--font--|
                        |            p4---------p7
                        |
                        |                t2---------------dt        dt always the same
    LFS                 |-log-||--font--||-----spline-----|
    LFB                 |-log-||--font--||---bus---|
    LF                  |-log-||--font--|
                        |  p1      p3---------p6
                        |
                        |         t1---------------dt               dt always the same
    FS                  |--font--||-----spline-----|
    FB                  |--font--||---bus---|
                        |   p2---------p5
    TF|--tri--||--font--|
      p9            p8



here's how we'll do this

    define TRIANGLE_SHAPE thusly:

        put TRIANGLE_LOCATER at start, needed for the search routine
        then assign the rest
        pad extra to get a composite number (power of 2)

    initialize

        allocate the entire block (num triangles)
        iterate through and build the shape for each block
        copy the two returned pointers( mask and out1 ) to our struct
            may be good to free the allocated memory ??
        assign the fixed geometry for each block
        then build the nodes as we go

        done

    pin_layout

        determine the E track
        intersect (to get T0)
        call triangle locate

        done

    gdi_render

        use a bounding rect to determine if a shape interesects the erase rect

    pin_render

        given a proper pDest for T0
        use the jump table
        use the data from the shape pointer to fill the appropriate structs
        draw line or bezier as required

        done

    pin hit test

        test the bounding rect first
        then test each shape component

        done

    auto layout

        use the jump index
        if F is needed, calculate based on appropriate t value



*/ comment ~

;///
;///    TRIANGLES
;///
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////


    TRIANGLE_SHAPE  STRUCT

    ;// 0
        ;// locator records, left/right must always be consecutive

        sort_key    dd  0   ;// int( trig * 1 million )
        go_left     dd  0   ;// offset to left record
        go_right    dd  0   ;// offset to right record
        jmp_left    dd  0   ;// again or done (signed jump)

    ;// 1

        jmp_right   dd  0   ;// again or done (signed jump)
                            ;// in the middle of nowhere, we get p9
        p9          dd  0   ;// = gdi_offset(H*(-TRIANGLE_RADIUS-2*FONT_RADIUS)

        ;// gdi shape fields

        pMask   dd  0
        pOut1   dd  0

    ;// 2

        ;// pointer displacements

        p1      dd  0   ;// = gdi_offset(H*LOGIC_RADIUS)
        p2      dd  0   ;// = gdi_offset(H*FONT_RADIUS)
        p3      dd  0   ;// = gdi_offset(H*(LOGIC_RADIUS+FONT_RADIUS)
        p4      dd  0   ;// = gdi_offset(H*(TRIANGLE_RADIUS+FONT_RADIUS)

    ;// 3

        p5      dd  0   ;// = gdi_offset(H*(2*FONT_RADIUS+BUS_RADIUS))
        p6      dd  0   ;// = gdi_offset(H*(2*(LOGIC_RADIUS+FONT_RADIUS)+BUS_RADIUS)
        p7      dd  0   ;// = gdi_offset(H*(TRIANGLE_RADIUS+2*FONT_RADIUS+BUS_RADIUS)
        p8      dd  0   ;// = gdi_offset(H*(-FONT_RADIUS)

    ;// 4

        ;// point displacements (always relative to T0)(always start of spline)

        t1  POINT {}    ;// = H*(2*FONT_RADIUS)
        t2  POINT {}    ;// = H*(2*(LOGIC_RADIUS+FONT_RADIUS))

    ;// 5

        t3  POINT {}    ;// = H*(TRIANGLE_RADIUS+2*(FONT_RADIUS))
        t4  POINT {}    ;// = H*SPLINE_RADIUS

    ;// 6
        ;// bounding rects

        r1  RECT    {}  ;// boundry of triangle+font    ( largest non bussed )

    ;// 7

        r2  RECT    {}  ;// boundry of triangle+font+bus( largest bussed )

    ;// 8

    TRIANGLE_SHAPE  ENDS

    ;// size is 32 dwords, 128 bytes
    ;// say there's 256 triangles, size = 32768

