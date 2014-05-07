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
;// abox_triangles  this file includes:
;//                 the triangle implemtation


OPTION CASEMAP:NONE
.586
.MODEL FLAT

    .NOLIST
    include <ABox.inc>
    include <triangles.inc>
    .LIST

.DATA

;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;///
;///    TRIANGLES
;///

    ;// triangles are drawn with their point at APIN.t0
    ;//
    ;// the triangle shape is based on two numbers
    ;//     PIN_TRIANGLE_RADIUS     ;// distance from T0 to base
    ;//     PIN_TRIANGLE_HEIGHT     ;// height of each side
    ;// both are defined in triangles.inc

    ;// to generate triangles we need to specify all three central angles
    ;// so that the triangles expand correctly

    ;// algorithm to derive the three master parameters
    ;// all angles are in radians, see tri_gen.mcd for a worksheet
    ;//
    ;//
    ;// th = PIN_TRIANGLE_HEIGHT    defined in triangles.inc
    ;// tr = PIN_TRIANGLE_RADIUS    defined in triangles.inc
    ;//
    ;// alpha = angle( th,tr )
    ;// beta = 0.5 * (90deg-alpha)
    ;// gamma = 180deg - alpha - beta
    ;//
    ;// tr0 = hypot( tr,th )
    ;//
    ;// tr1 = tr0 * sin(beta) / sin( gamma )
    ;// tr2 = tr0 * sin(alpha) / sin( gamma )
    ;//
    ;// gamma is then the plus minus angle to offset Q
    ;//
    ;// the three master parameters are then defined as:
    ;//
    ;// t_g = gamma
    ;// tr1 is radius of the point
    ;// tr2 is radius of the other two corners

    comment ~ /*
    ;// for th=4, tr=10 use:

        t_g REAL4   2.1659413e+0
        tr1 REAL4   7.292e+0
        tr2 REAL4   4.83052565e+0


    ;// for th=4, tr=8 use:

        t_g REAL4   2.124
        tr1 REAL4   5.528
        tr2 REAL4   4.702

    */ comment ~

    ;// for th=3, tr=8 use:

        t_g REAL4   2.177
        tr1 REAL4   5.921
        tr2 REAL4   3.65


    NUM_TRIANGLES equ 128
    tri_dQ REAL4 0.049087385e+0 ;// 2pi / num triangles

comment ~ /*

    NUM_TRIANGLES equ 192
    tri_dQ REAL4 0.032724923e+0

*/ comment ~

;// there is a btree to locate the triangles
;// see notes way below


    triangle_shape_table    dd  0           ;// pointer to block of shapes
    triangle_locater_start  dd  8 dup (0)   ;// addresses of the starts for searches
                                            ;// these are frame centers for 8 btreees

    triangle_sort_key_delta REAL4 785.3981634e-3    ;// = pi/4
;// triangle_sort_key_start REAL4 -3.141592653e+0   ;// = -pi


;// CONSTANTS, see TRIANGLE_SHAPE, see gdi_pin_SetJIndex

;// p1
tri_logic_radius            REAL4   @REAL(PIN_LOGIC_RADIUS)

;// p2
tri_font_radius             REAL4   @REAL(PIN_FONT_RADIUS)

;// p3
tri_2logic_font_radius      REAL4   @REAL(2*PIN_LOGIC_RADIUS+PIN_FONT_RADIUS)

;// p4
tri_triangle_font_radius    REAL4   @REAL(PIN_TRIANGLE_RADIUS+PIN_FONT_RADIUS)

;// p5
tri_2font_bus_radius        REAL4   @REAL(2*PIN_FONT_RADIUS+PIN_BUS_RADIUS-PIN_BUS_ADJUST)

;// p6
tri_2logic_2font_bus_radius REAL4   @REAL(2*(PIN_LOGIC_RADIUS+PIN_FONT_RADIUS)+PIN_BUS_RADIUS-PIN_BUS_ADJUST)

;// p7
tri_triangle_2font_bus_radius REAL4 @REAL(PIN_TRIANGLE_RADIUS+2*PIN_FONT_RADIUS+PIN_BUS_RADIUS-PIN_BUS_ADJUST)

;// p8
tri_neg_font_radius         REAL4   @REAL(-PIN_FONT_RADIUS)

;// p9
tri_neg_triangle_2font_radius REAL4 @REAL(-PIN_TRIANGLE_RADIUS-2*PIN_FONT_RADIUS)



;// t1
tri_2font_radius            REAL4   @REAL(2*PIN_FONT_RADIUS)

;// t2
tri_2font_logic_radius      REAL4   @REAL(2*(PIN_LOGIC_RADIUS+PIN_FONT_RADIUS))

;// t3
tri_triangle_2font_radius   REAL4   @REAL(PIN_TRIANGLE_RADIUS+2*PIN_FONT_RADIUS)

;// t4
tri_spline_radius           REAL4   @REAL(PIN_SPLINE_RADIUS)


IF (2*PIN_LOGIC_RADIUS) GT PIN_TRIANGLE_RADIUS

    ;// logics are bigger than triangles

    ;// ECHO using logic radius

    ;// r1
    tri_r1_radius   REAL4   @REAL(2*PIN_LOGIC_RADIUS+PIN_FONT_RADIUS)

    ;// r2
    tri_r2_radius   REAL4   @REAL(2*PIN_LOGIC_RADIUS+2*PIN_FONT_RADIUS+PIN_BUS_RADIUS)

ELSE

    ;// triangles are bigger than logics

    ;// ECHO using triangle radius

    ;// r1
    tri_r1_radius   REAL4   @REAL(PIN_TRIANGLE_RADIUS+PIN_FONT_RADIUS)

    ;// r2
    tri_r2_radius   REAL4   @REAL(PIN_TRIANGLE_RADIUS+2*PIN_FONT_RADIUS+PIN_BUS_RADIUS)


ENDIF











.CODE

;////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////
;///
;///    P I N S  and   T R I A N G L E S
;///
comment ~ /*

    pin triangles are cached, one per each unique pin.
    the are a couple hundred of them
    each pin is always referened by it's T0 coord, which is then converted into
    a memory address on the destination surface

    pins need the masker and one oultiner

    when a triangle needs drawn, we simply call gdi_filler for the pin's template.

    to generate all the pins:

        define T0 as (0,0)
        scan through the angles, using tri_dQ as the increment
        build the corner coords (T1 and T2) at that angle
        call gdi_search_for_non_zero


*/ comment ~



.CODE


ASSUME_AND_ALIGN
triangle_BuildTable PROC STDCALL

    ;// for this new version
    ;// we build polygon points
    ;// use a shape template
    ;// call shape_BuildShape to do all the work
    ;// we're using a temporary GDI_SHAPE struct, built here on the stack

    LOCAL fP2:fPOINT        ;// neg edge (rad,-angle)
    LOCAL fP1:fPOINT        ;// pos edge (rad,+angle)
    LOCAL fP0:fPOINT        ;// point of the triangle (0,0)

    LOCAL bSinCos:DWORD     ;// flag for sin cos in the btree
    LOCAL pLocStart:DWORD   ;// array of start points

    LOCAL gdi_shape:GDI_SHAPE   ;// temporary gdi shape

    LOCAL temp_point:POINT  ;// temp values for building the offsets

    LOCAL count:DWORD   ;// counts points

    ;// initialize the shape

        lea edi, gdi_shape
        mov ecx, SIZEOF GDI_SHAPE / 4
        xor eax, eax
        rep stosd

        mov edx, tr1    ;// radius at point
        mov eax, tr2    ;// radius of two other points

        mov fP0.x, edx  ;// point
        mov fP1.x, eax  ;// plus edge
        mov fP2.x, eax  ;// minus edge

        lea eax, fP0
        mov gdi_shape.pPoints, eax

    ;// allocate memory for the entire table

        mov eax, SIZEOF TRIANGLE_SHAPE * NUM_TRIANGLES
        invoke memory_Alloc, GPTR, eax
        mov triangle_shape_table, eax
        mov edi, eax
        ASSUME edi:PTR TRIANGLE_SHAPE

    ;// build all the shapes

        mov count, NUM_TRIANGLES    ;// triangle_count
        fldz    ;// Q increments around the circle

        .REPEAT

        ;// compute the two triangle corners

            fst  fP0.y
            fld  st         ;// Q       Q
            fadd t_g        ;// Q+t_f   Q
            fld  st(1)
            fsub t_g        ;// Q-t_f   Q+t_f   Q
            fxch
            fstp fP1.y
            fstp fP2.y

        ;// compute the set up this shape
        ;// offset by the center so the outline comes out correctly

            fld st
            fsincos
            fmul tr1
            fxch
            fmul tr1
            fxch
            fchs
            fstp gdi_shape.OC.x
            fchs
            fstp gdi_shape.OC.y

        ;// build the shape

            push edi
            lea ebx, gdi_shape
            mov gdi_shape.dwFlags, SHAPE_IS_POLYGON + 3 + SHAPE_BUILD_OUT1 + SHAPE_RGN_OFS_OC
            invoke shape_Build
            pop edi

        ;// get the data we need

            mov eax, gdi_shape.pMask
            mov edx, gdi_shape.pOut1
            mov [edi].pMask, eax
            mov [edi].pOut1, edx

        ;// build the geometry we need

                        ;// Q
            fld st      ;// Q   Q
            fsincos     ;// Hx  Hy  Q

            fchs
            fxch
            fchs
            fxch

            ;// p1 = gdi_offset(H*LOGIC_RADIUS)

                lea ebx, [edi].p1
                fld tri_logic_radius
                call tri_build_offset

            ;// p2 = gdi_offset(H*FONT_RADIUS)

                lea ebx, [edi].p2
                fld tri_font_radius
                call tri_build_offset

            ;// p3 = gdi_offset(H*(2*LOGIC_RADIUS+FONT_RADIUS))

                lea ebx, [edi].p3
                fld tri_2logic_font_radius
                call tri_build_offset

            ;// p4 = gdi_offset(H*(TRIANGLE_RADIUS+FONT_RADIUS))

                lea ebx, [edi].p4
                fld tri_triangle_font_radius
                call tri_build_offset

            ;// p5 = gdi_offset(H*(2*FONT_RADIUS+BUS_RADIUS))

                lea ebx, [edi].p5
                fld tri_2font_bus_radius
                call tri_build_offset

            ;// p6 = gdi_offset(H*(2*(LOGIC_RADIUS+FONT_RADIUS)+BUS_RADIUS)

                lea ebx, [edi].p6
                fld tri_2logic_2font_bus_radius
                call tri_build_offset

            ;// p7 = gdi_offset(H*( TRIANGLE_RADIUS+2*FONT_RADIUS+BUS_RADIUS)

                lea ebx, [edi].p7
                fld tri_triangle_2font_bus_radius
                call tri_build_offset

            ;// p8 = gdi_offset(H*(-FONT_RADIUS)

                lea ebx, [edi].p8
                fld tri_neg_font_radius
                call tri_build_offset

            ;// p9 = gdi_offset(H*( -TRIANGLE_RADIUS-2*FONT_RADIUS)

                lea ebx, [edi].p9
                fld tri_neg_triangle_2font_radius
                call tri_build_offset

            ;// t1 = H*(2*FONT_RADIUS)

                lea ebx, [edi].t1
                fld tri_2font_radius
                call tri_build_point

            ;// t2 = H*(2*(LOGIC_RADIUS+FONT_RADIUS))

                lea ebx, [edi].t2
                fld tri_2font_logic_radius
                call tri_build_point

            ;// t3 = H*(TRIANGLE_RADIUS+2*(FONT_RADIUS))

                lea ebx, [edi].t3
                fld tri_triangle_2font_radius
                call tri_build_point

            ;// t4 = H*SPLINE_RADIUS

                lea ebx, [edi].t4
                fld tri_spline_radius
                call tri_build_point

        ;// bounding rects
        ;// r1  = boundry of triangle+font  ( largest non bussed )

                lea ebx, [edi].r1
                fld tri_r1_radius
                mov ecx, PIN_FONT_RADIUS+1
                call tri_build_boundrect

        ;// r2  = boundry of triangle+font+bus( largest bussed )

                lea ebx, [edi].r2
                fld tri_r2_radius
                mov ecx, PIN_BUS_RADIUS+3
                call tri_build_boundrect

        ;// clear out fpu

            fstp st
            fstp st

        ;// iterate

            fadd tri_dQ
            add edi, SIZEOF TRIANGLE_SHAPE  ;// iterate the shape table
            dec count                       ;// decrease the count

        .UNTIL ZERO?

        fstp st     ;// clear out the fpu






;//
;// build btree
;//
    ;// now we build the btree
    ;// see the notes below for details (gdi_LocateTriangle)

        ;// rescan the angles, keeping track of the key angles
        ;// -pi, -3pi/4, -pi/2, -pi/4, 0, pi/4, pi/2, 3pi/4, pi
        ;// we'll do a total of eight sections
        ;// and generate the tree shown below

        mov edi, triangle_shape_table   ;// edi holds the start of the table
        ASSUME edi:PTR TRIANGLE_SHAPE   ;// edi will walk the table

        fldpi       ;// Q increments around the circle
        fchs

        fld triangle_sort_key_delta ;// = pi/4  Q
        ;//fld  triangle_sort_key_start ;// = -pi   pi/4    Q
        fldpi
        fchs

        mov ecx, NUM_TRIANGLES  ;// triangle_count

        mov bSinCos, 9  ;// if bit1 is set, then we want the cosine of the angle
                        ;// else we want the sine

        lea eax, triangle_locater_start
        mov pLocStart, eax

    outter_loop:        ;// = -pi   pi/4    Q

        fadd st, st(1)  ;// update the key

        xor ebx, ebx    ;// ebx will count frame size by counting them
        mov edx, edi    ;// edx holds the start of the frame

        dec bSinCos     ;// bit two is the key

    inner_loop:

        fld st(2)       ;// load the angle
        fadd tri_dQ     ;// increment it now
        xor eax, eax    ;// clear to prevent partial stall
        fxch st(3)      ;// xchg with previous
        fucom           ;// compare with search key
        fnstsw ax

        ;// always store either the sine or the cosine

        .IF bSinCos & 2 ;// check the sincos bit
            fcos
        .ELSE
            fsin
        .ENDIF
        fmul math_Million
        fistp [edi].sort_key

        sahf
        jb next_value

            ;// we just hit one of the key's we're looking for
            ;// so we call build_btree

            ;// so:
            ;//
                push ecx    ;// store the triangle count
                push edi    ;// store the record we;re working on

                mov ecx, ebx        ;// ebx is count of records in this frame
                shr ecx, 1          ;// ecx will be the start index (center of frame)
                                    ;// edx is R, the refence for the entire frame

                ;// very important that we store this first address
                mov eax, ecx        ;// xfer frame center index to eax
                shl eax, LOG2( SIZEOF TRIANGLE_SHAPE )  ;// convert to a byte size
                add eax, edx        ;// add on the reference (start of frame)
                mov edi, pLocStart  ;// get our current slot
                stosd               ;// store the frame start
                mov pLocStart, edi  ;// store the iterator

                call generate_node  ;// recursively scan

                pop edi
                pop ecx

            ;// iterate the inner loop

                add edi, SIZEOF TRIANGLE_SHAPE  ;// always advance the triangle pointer
                dec ecx                         ;// decrease the triangle count

            ;// then reset the frame size, and go to the next key

                jmp outter_loop

    next_value:

        add edi, SIZEOF TRIANGLE_SHAPE  ;// always advance the triangle shape
        inc ebx                         ;// increase the count
        dec ecx                         ;// decrease the triangle count

        jnz inner_loop                  ;// all the triangle done ?

    ;// then we have to hit the last frame

        mov ecx, ebx        ;// ebx is W
        shr ecx, 1          ;// ecx will be N
                            ;// edx is R
        ;// very important that we store this first address
        mov eax, ecx
        shl eax, LOG2( SIZEOF TRIANGLE_SHAPE )
        add eax, edx
        mov edi, pLocStart
        stosd
        mov pLocStart, edi

        call generate_node  ;// recursively scan

    ;// dump the fpu

        fstp st
        fstp st
        fstp st

    ;// that's it

        ret

;// local functions
ALIGN 16
tri_build_offset:

    ;// computes:
    ;// gdi_offset( radius*H )
    ;// radius must already be loaded
    ;// uses eax, edx, ecx
    ;// temp_point must exist
    ;//
    ;// stores results in [ebx]

        fld  st         ;// rad rad Hx  Hy  Q
        fmul st, st(3)  ;// y   rad Hx  Hy  Q

        fxch            ;// rad y   Hx  Hy  Q
        fmul st, st(2)  ;// x   y   Hx  Hy  Q
        fxch            ;// y   x   Hx  Hy  Q
        fistp temp_point.y  ;// x   Hx  Hy  Q
        mov eax, gdi_bitmap_size.x
        fistp temp_point.x
        mul temp_point.y
        mov ecx, temp_point.x
        add ecx, eax

        mov [ebx], ecx

        retn

ALIGN 16
tri_build_point:

    ;// computes:
    ;// H*radius
    ;// radius must already be loaded
    ;// stores to a point at ebx

        ASSUME ebx:PTR POINT

        fld  st         ;// rad rad Hx  Hy  Q
        fmul st, st(2)  ;// x   rad Hx  Hy  Q

        fxch            ;// rad x   Hx  Hy  Q
        fmul st, st(3)  ;// y   x   Hx  Hy  Q
        fxch            ;// x   y   Hx  Hy  Q
        fistp [ebx].x   ;// y   Hx  Hy  Q
        fistp [ebx].y   ;// Hx  Hy  Q

        retn


ALIGN 16
tri_build_boundrect:

    ;// ecx has the offset
    ;// radius already loaded
    ;// ebx points at the rect to bound

    ;// compute the point H*radius
    ;// then determines if that point +- irad is
    ;// outside of the bounding rect
    ;// always leaves 0,0 as the lowest_maximum and highest_minimum


        fld  st         ;// rad rad Hx  Hy  Q
        fmul st, st(2)  ;// x   rad Hx  Hy  Q

        fxch            ;// rad x   Hx  Hy  Q
        fmul st, st(3)  ;// y   x   Hx  Hy  Q
        fxch            ;// x   y   Hx  Hy  Q
        fistp temp_point.x  ;// y   Hx  Hy  Q
        fistp temp_point.y  ;// Hx  Hy  Q

    ASSUME ebx:PTR RECT

        point_Get temp_point
        sub eax, ecx
        .IF eax < [ebx].left
            mov [ebx].left, eax
        .ENDIF
        sub edx, ecx
        .IF edx < [ebx].top
            mov [ebx].top, edx
        .ENDIF
        shl ecx, 1      ;// * 2
        add eax, ecx
        .IF eax > [ebx].right
            mov [ebx].right, eax
        .ENDIF
        add edx, ecx
        .IF edx > [ebx].bottom
            mov [ebx].bottom, edx
        .ENDIF


    ;// then we inflate to account for the out 1

        rect_Inflate [ebx]

    ;// that's it


        retn



triangle_BuildTable ENDP






comment ~ /*

    there are two classes of sort key
    one assumes that LEFT is when value < sort_key
    other assumes that LEFT is when value > sort_key

    to be accurate, we choose which of the two trig values is changing the most
    and generate the table accordingly

    we also want to be sure that LEFT includes the lower value, and excludes the higher value

;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//
;// summary of search algorithm and generator mechanism

                                   no <--   --> yes

test1                    Hy<0                          Hy>=0

test2             Hx<0          Hx>=0           Hx>0            Hx<=0

test3        Hx<Hy   Hx>=Hy Hx<-Hy  Hx>=-Hy Hy<Hx   Hy>=Hx  -Hy<Hx  -Hy>=Hx

build stop  -3pi/4  -pi/2   -pi/4   0       pi/4    pi/2    3pi/4   pi(end)
--------------------------------------------------------------------------
generator   1000    0111    0110    0101    0100    0011    0010    0001
sort key    sin     cos     cos     sin     sin     cos     cos     sin
sort by     Hy      Hx      Hx      Hy      Hy      Hx      Hx      Hy
left if     Hy>key  Hx<key  Hx<key  Hy<key  Hy<key  Hx>key  Hx>key  Hy>key
--------------------------------------------------------------------------

;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////

    to generate the left right table requires a recursive algorithm
    there are two states to store

        W = the width of the segment in indexes
        N = the current index

    then a reference to the etire segment

        R = reference addres ( R[N*size] )      start of block

    given a start location that must be the truncated half index of the segemnt
    the following method seams to work

    if LEFT

        w>>=1
        V=W>>1
        if ZERO
            left = N - 1
            DONE
        else !ZERO
            left = N-=V-carry
            NOT DONE
        endif

    else RIGHT

        W>>=1 + carry
        V=W>>1
        if ZERO
            right = N
            DONE
        else !ZERO
            right = N+=V
            NOT DONE
        endif

    endif

    this will produce a balanced addressing struct for the range

    now, how do we create it ?

;// this should do the trick

    generate_node:  W,N

        generate Left

            if !DONE    generate node

            undo changes

        generate Right

            if !DONE    generate node

            undo changes

    return

    ;// this will then recursively scan the whole thing, always doing left first
    ;// then diving into the right side
    ;// when the entire tree is built, we're all done



;// combining the previous two sections //////////////////

*/ comment ~

ASSUME_AND_ALIGN
generate_node PROC  ;//(W,N)

    ;// registers

    R TEXTEQU <edx> ;// must be set on entrance     preserved
    N TEXTEQU <ecx> ;// must be set on entracnce    destroyed
    W TEXTEQU <ebx> ;// must be set on entrance     destroyed

    S TEXTEQU <edi> ;// temorary                    destroyed
    V TEXTEQU <eax> ;// temp value                  destroyed

    ASSUME R:PTR TRIANGLE_SHAPE ;// R is the refence to the entire segment
    ASSUME S:PTR TRIANGLE_SHAPE ;// S is the frame we're working with, R[N*size]

        push N          ;// store state
        push W

    ;// LEFT


        mov S,N         ;// calclulate S, the byte offset of the current index
        shl S, LOG2(SIZEOF TRIANGLE_SHAPE)  ;// ( size=128 )
        add S, R

        shr W, 1            ;// w>>=1       ;// adjust frame size to 1/2
        mov V, W            ;// adjust the adjuster
        shr V, 1            ;// V=W>>1

        jnz @1              ;// is adjuster at bottom ?

                        ;// yes, store the

        dec N               ;// left = N - 1

        mov V,N         ;// convert current index to a pointer
        shl V, LOG2(SIZEOF TRIANGLE_SHAPE)
        add V, R

        mov [S].go_left, V  ;// store in record
        jmp @2              ;// leave jump_left blank (terminator)

                        ;// no, adjust N and recurse

    @1: sbb N, V            ;// N-=V

        mov V, N        ;// convert current index to a pointer
        shl V, LOG2(SIZEOF TRIANGLE_SHAPE)
        add V, R

        mov [S].go_left, V  ;// store in record

        mov [S].jmp_left, TRIANGLE_LOCATOR_DO_AGAIN ;// backwards jump

        call generate_node  ;// call recursively

    @2: mov W, [esp]        ;// restore state
        mov N, [esp+4]

    ;// RIGHT

        xor V, V

        mov S, N                ;// caclulate S, address of current index
        shl S, LOG2(SIZEOF TRIANGLE_SHAPE)
        add S, R

        shr W, 1            ;// W>>=1 + carry   ;// adjust the frame size
        adc W, V

        mov V, W            ;// V=W>>1          ;// adjust the adjuster
        shr V, 1
        jnz @3              ;// adjuster at bottom ?
                        ;// yes, store as right

        mov V,N         ;// calculate current index
        shl V, LOG2(SIZEOF TRIANGLE_SHAPE)
        add V, R

        mov [S].go_right,V  ;// right = N
        jmp @4              ;// leave jump_right as zero (terminator)

                    ;// no, adjust N, and recurse
    @3: add N, V            ;// N+=V

        mov V,N     ;// caclulate current frame address
        shl V, LOG2(SIZEOF TRIANGLE_SHAPE)
        add V, R

        mov [S].go_right,V  ;// store as go right
        mov [S].jmp_right, TRIANGLE_LOCATOR_DO_AGAIN    ;// backwards jump

        call generate_node  ;// call recursively

    ;// DONE

    @4: pop W   ;// restore state
        pop N

        ret         ;// return

generate_node ENDP




ASSUME_AND_ALIGN
triangle_Destroy PROC

    mov ebx, triangle_shape_table
    ASSUME ebx:PTR TRIANGLE_SHAPE
    mov esi, NUM_TRIANGLES  ;// triangle_count

    .REPEAT

        DEBUG_IF <!![ebx].pMask>    ;// mask was never built

        invoke memory_Free, [ebx].pMask

        add ebx, SIZEOF TRIANGLE_SHAPE
        dec esi

    .UNTIL ZERO?

    invoke memory_Free, triangle_shape_table

    ret

triangle_Destroy ENDP









ASSUME_AND_ALIGN
triangle_Locate PROC STDCALL uses ebx

    LOCAL HX:DWORD  ;// sort key
    LOCAL HY:DWORD  ;// sort key

comment ~ /*

    we have an array of triangles
    all we know is the sine and cosine of the angle
    we want to return the pointer to the shape that closest matches the angle

    this is best done by a binary search

    we'll get to the octant quickly with the following three tests:

     Hy  <  0   1/2
     Hx  <  0   1/4
    |Hx| < |Hy| 1/8

    from there we still have about 100 items to search
    so we need a blist tree for each of the eight sections
    it would be best to multiply the appropriate sine or cosine by a million,
    then use integer comarisons

    from there, we either go left or right, or we're done

    ;// since this is only called from pin_layout
    ;// the fpu registers will be set like this:

        ;// H.x     H.y

    ;// we also have the luxury that we can trash them

;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
                                   no <--   --> yes

test1                   Hy<0                            Hy>=0

label                   0123                            4567
test2           Hx<0            Hx>=0           Hx>0            Hx<=0

label           01              23              45              67
test3       Hx<Hy   Hx>=Hy  Hx<-Hy  Hx>=-Hy Hy<Hx   Hy>=Hx  -Hy<Hx  -Hy>=Hx

label       0       1       2       3       4       5       6       7
--------------------------------------------------------------------------
sort by     Hy      Hx      Hx      Hy      Hy      Hx      Hx      Hy
left if     Hy>key  Hx<key  Hx<key  Hy<key  Hy<key  Hx>key  Hx>key  Hy>key
--------------------------------------------------------------------------

;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
*/ comment ~ ;/////////////////////////////////////////////////////////////


        fld math_Million    ;// e+6     Hx      Hy
        fmul st(2), st      ;// e+6     Hx      MHy
        xor eax, eax
        xor ebx, ebx        ;// ebx will turn into an index in a moment
        fmul                ;// MHx     MHy
        fxch                ;// MHy     MHx
        ftst
        fnstsw ax
        sahf
        fistp   HY          ;// MHx

    ;// test 1
    jb @0123

    ;// test 2
    @4567:

        fistp   HX          ;// empty !

        xor eax, eax
        mov edx, HY
        or eax, HX
        jz @67
        jns @45

        @67:    neg edx
                cmp edx, eax
                jl @6

                @7: mov eax, edx
                    or ebx, 7
                    neg eax
                ;// jmp search_greater

                @6: or ebx, 6
                    jmp search_greater


        @45:    cmp edx, eax
                jl @4

                @5: or ebx, 5
                    jmp search_greater

                @4: or ebx, 4
                    mov eax, edx
                    jmp search_less


    ;// test 2
    @0123:

        fistp   HX          ;// T0.x    T0.y    H.x     H.y
        xor eax, eax
        mov edx, HY
        or eax, HX
        js  @01

        @23:    neg edx
                cmp eax, edx
                jl @2

            @3: mov eax, edx
                or ebx, 3
                neg eax
            ;// jmp search_less

            @2: or ebx, 2
                jmp search_less

        @01:    cmp eax, edx
                jl @0

                @1: inc ebx
                    jmp search_less

                @0: mov eax, edx
                ;// jmp search_greater


search_greater:

    ;// eax has the sort_by value

    ;// load the start address  (ebx has the index of the record)
    mov ebx, triangle_locater_start[ebx*4]
    ASSUME ebx:PTR TRIANGLE_SHAPE

    ;// this would be a left is greater than sort

    g_again::xor ecx, ecx                   ;// clear ecx, no partial stalls
            cmp eax, [ebx].sort_key         ;// compare with key
            setle cl                        ;// store results
            mov edx, [ebx+ecx*4].jmp_left   ;// load jump address
            mov ebx, [ebx+ecx*4].go_left    ;// left or right
            lea edx, [edx+g_done]
            jmp edx                         ;// do again or exit

    g_done::    ;// now ebx will point at the traingle shape for this
        ;// sub ebx, triangle_locater_table ;// ebx now counts dwords into the locator table
        ;// shl ebx, 2      ;// gdi shapes are 16 dwords each, locaters are 4 dwords
            ;// fix: triangle are 128 bytes each
        ;// add ebx, triangle_shape_table
            jmp AllDone



search_less:

    ;// eax has the sort_by value

    ;// load the start address
    mov ebx, triangle_locater_start[ebx*4]
    ASSUME ebx:PTR TRIANGLE_SHAPE

    ;// this would be a left is less than sort
    l_again:xor ecx, ecx                    ;// clear ecx, no partial stalls
            cmp eax, [ebx].sort_key         ;// compare with key
            setge cl                        ;// store results
            mov edx, [ebx+ecx*4].jmp_left   ;// load jump address
            mov ebx, [ebx+ecx*4].go_left    ;// left or right
            lea edx, [edx+l_done]
            jmp DWORD PTR edx               ;// do again or exit

    l_done: ;// now ebx will point at the locator record for this
        ;// sub ebx, triangle_locater_table ;// ebx now counts dwords into the locator table
        ;// shl ebx, 2      ;// gdi shapes are 16 dwords each, locaters are 4 dwords
            ;// fix: triangle are 128 bytes each
        ;// add ebx, triangle_shape_table
AllDone:
            mov eax, ebx
            ret

triangle_Locate ENDP


TRIANGLE_LOCATOR_DO_AGAIN equ OFFSET g_again - OFFSET g_done

ASSUME_AND_ALIGN

END