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
;//   pin_layout.asm        routines that layout pins
;//
;//
;// TOC:
;//
;//     pin_compute_vectors     used by pin layout to build E, H, HH, and s_alpha
;//     pin_Layout_shape
;//     pin_Layout_points
;//     pin_SetJumpIndex        builds the jump index for any pin state
;//     pin_ComputePhetaFromXY  builds pheta given an XY coord
;//
;//     pin_SetTrigger          assigns logic trigger shapes to pins
;//     pin_Show                makes sure that pins are shown or hidden
;//     pin_SetNameAndUnit      sets the name, unit, and color
;//     pin_SetUnit             sets the unit and color
;//
;//     show_containers         debug function


OPTION CASEMAP:NONE

.586
.MODEL FLAT

        .NOLIST
        include <Abox.inc>
        include <triangles.inc>
        INCLUDE <gdi_pin.inc>
        .LIST

.DATA

    pin_temp    dd  0   ;// temp value for pin_layout

    ;// this is used for grabbing the pShape for logic inputs
    pin_logic_shape_table   dd  shape_trig_both
                            dd  shape_trig_pos  ;// PIN_LEVEL_POS
                            dd  shape_trig_neg  ;// PIN_LEVEL_NEG
                            dd  0   ;// error   = 3
                            dd  shape_gate_both
                            dd  shape_gate_pos
                            dd  shape_gate_neg
                            dd  0   ;// error


    ;// private functions

    pin_compute_vectors PROTO



;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;///
;///
;///
;///
;///        P I N _ L A Y O U T
;///
;///

comment ~ /*

APIN layout

    OSC_OBJECT owns a collection of APIN's

    each APIN is asigned a SHAPE_CONTAINER

        the SHAPE_CONTAINER assigned is ultimately controlled by the OSC_OBJECT
        it may be the same for all pins, or pins may be assigned seperate containers
        this allows for objects that are broken into pieces.

    the SHAPE_CONTAINER holds both a polygon boundry, and the parameters for a parametric curve
        containers manage a SHAPE_INTERSECTOR table to get from the curve to the object's boundry

    each APIN is then bounded to the curve using pheta as the master parameter point.

    from pheta, E can be derived using the parametric curve
        E is always referenced to (0,0)

    while calculating E, G is defined (temporary)

        G represents the direction of the curve, and at the same time,
        the perpendicular H at right angles to the curve, pointing 'out'
        the perpendicular is also referred to as 'H'

    from E and G, the SHAPE_INTERSECTOR can determine T0 and F0

    once T0 is defined, a TRIANGLE_SHAPE is assigned
    some extra shapes may also be assigned and cached

new model for layout:

    the whole process can be segmented thusly:

    define EH       pheta must be defined
    intersect       E and H must be defined
    locate Tri      E and H must be defined

FORMULAS:

    p comes from the pin
    a,b,s and q come from the pin's osc.container


    E(p) = ellipse(p) - s * ellipse_harmonic(q*p)

        ex = a * ( cos(p) - s*cos(q*p) )
        ey = b * ( sin(p) - s*sin(q*p) )

    G(p) = dE/dp = derivative of E(p), direction derivative

    H(p) = rotate G(p) 90 degrees

        Hx = Gy     Gx = -Hy    !!! left   !!!
        Hy = -Gx    Gy = Hx     !!! handed !!!

        hx =  b * ( cos(p) + s*q*cos(q*p) )
        hy = -a * ( sin(p) + s*q*sin(q*p) )

    s_alpha = 1/( G^2 + 1) = 1/(H^2 + 1)

        s_alpha = 1 / ( Hx*Hx + Hy*Hy )

        s_alpha is used by pin_dynamics to smooth moving around sharp corners
        it gets multiplied by G then stored as GA

    new way of doing s_alpha    see pin_dyn10.mcd for worksheets

                  k2            k1 = 1 / ( a^2 + b^2 )
    GA = ( k1 - ----- ) * G     k2 = sqrt( k1 )
                G^2+1
                                GA is then applied to all force vectors

*/ comment ~


.CODE







;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;//
;//                         defines:    E   G   t0  pTShape
;//     pin_Layout_shape    sets:       HINTPIN_STATE_VALID_TSHAPE
;//                         resets:     HINTPIN_STATE_VALID_DEST
ASSUME_AND_ALIGN
pin_Layout_shape PROC   uses ebp edi

        ASSUME esi:PTR OSC_OBJECT
        ASSUME ebx:PTR APIN

        DEBUG_IF <[ebx].dwStatus & PIN_HIDDEN>

        xor eax, eax
        OSC_TO_CONTAINER esi, ebp

        or eax, [ebx].j_index
        jz pin_layout_shape_hide

    ;// load current value of pheta

        fld [ebx].pheta

    ;// compute E H and dOmega

        invoke pin_compute_vectors

    ;// call intersector, if one exists

        .IF [ebp].pInter
            invoke shape_Intersect  ;// sl  ey  ex  hx  hy
        .ELSE
            fldz
        .ENDIF

    ;// scoot E to correct location
    ;// E += container.OC + osc.TL

        fld [ebp].shape.OC.x    ;// ocx sl  ey  ex  hx  hy
        faddp st(3), st         ;// sl  ey  Ex  hx  hy
        fild [esi].rect.left    ;// ox  sl  ey  Ex  hx  hy
        faddp st(3), st         ;// sl  ey  EX  hx  hy

        fld [ebp].shape.OC.y    ;// ocy sl  ey  EX  hx  hy
        faddp st(2), st         ;// sl  Ey  EX  hx  hy
        fild [esi].rect.top     ;// oy  sl  Ey  EX  hx  hy
        faddp st(2), st         ;// sl  EY  EX  hx  hy

    ;// compute dH = sl*H

        fld st                  ;// sl  sl  EY  EX  hx  hy
        fmul st,st(5)           ;// dhy sl  EY  EX  hx  hy
        fxch                    ;// sl  dhy EY  EX  hx  hy
        fmul st, st(4)          ;// dhx dhy EY  EX  hx  hy

    ;// store E and compute T0 = E+dH

        fxch st(3)              ;// EX  dhy EY  dhx hx  hy
        fst [ebx].E.x
        faddp st(3), st         ;// dhy EY  Tx  hx  hy

        fxch                    ;// EY  dhy Tx  hx  hy
        fst [ebx].E.y
        fadd                    ;// Ty  Tx  hx  hy

    ;// store and dump T0

        fxch                    ;// Tx  Ty  hx  hy
        fistp [ebx].t0.x        ;// Ty  hx  hy
        fistp [ebx].t0.y        ;// hx  hy

    ;// locate the triangle     ;// hx  hy

        .IF [ebx].j_index == 9  ;// unconnected outputs are backwards

            fchs
            fxch
            fchs
            fxch

        .ENDIF

        invoke triangle_Locate  ;// empty

    ;// store the triangle and set the flags

        mov ecx, [ebx].dwHintPin    ;// get the hint
        mov [ebx].pTShape, eax      ;// store shape in pin

        or ecx, HINTPIN_STATE_VALID_TSHAPE      ;// turn on valid tshape
        and ecx, NOT HINTPIN_STATE_VALID_DEST   ;// turn off valid dest
        mov [ebx].dwHintPin, ecx                ;// store back in object

pin_layout_shape_hide:: ;// hidden pin

    ret

pin_Layout_shape ENDP

;//                         defines:    E   G   t0  pTShape
;//     pin_Layout_shape    sets:       HINTPIN_STATE_VALID_TSHAPE
;//                         resets:     HINTPIN_STATE_VALID_DEST
;//
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////











.CODE

;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;//
;//                         defines:    t1, t2, pDest
;//     pin_Layout_points   sets:       HINTPIN_STATE_VALID_DEST
;//                                     HINTPIN_STATE_ON_SCREEN

ASSUME_AND_ALIGN
pin_Layout_points PROC

    ;// uses edi, ecx, eax, edx

    ASSUME ebx:PTR APIN

    DEBUG_IF <!!([ebx].dwHintPin & HINTPIN_STATE_VALID_TSHAPE)>
    ;// must have a valid shape before calling this

    ;// at this point, E G and t0 are calculated
    ;// we do not know: t1, t2, pDest or F


    ;// compute t1 and t2 using appropriate point offset

        PIN_TO_TSHAPE ebx, edi  ;// load the shape
        mov ecx, [ebx].j_index  ;// get the jump index
        point_Get [ebx].t0      ;// load our t0 location

        jmp pin_layout_points_jump[ecx*4]   ;// do what it sayeth

    ALIGN 16
    pin_layout_points_FT::  ;// unconnected output

            ;// we do this manually
            ;// because the triangles are pointing backwards

            point_Sub [edi].t3
            point_Set [ebx].t1  ;// store t1
            point_Sub [edi].t4
            point_Set [ebx].t2  ;// store t2

            jmp compute_pDest

    ALIGN 16
    pin_layout_points_TFB:: ;// bussed analog input
    pin_layout_points_TFS:: ;// connected analog input
    pin_layout_points_TF::  ;// unconnected analog input

            lea ecx, [edi].t3
            jmp pin_layout_points_compute_t1

    pin_layout_points_LFB:: ;// bussed logic input
    pin_layout_points_LFS:: ;// connected logic input
    pin_layout_points_LF::  ;// unconnected logic input

            lea ecx, [edi].t2
            jmp pin_layout_points_compute_t1

    pin_layout_points_FB::  ;// bussed output
    pin_layout_points_FS::  ;// connected output

            lea ecx, [edi].t1

    pin_layout_points_compute_t1:

            ASSUME ecx:PTR POINT
            point_Add [ecx]         ;// add the offset
            point_Set [ebx].t1      ;// store as t1

        ;// compute t2 for splines

            point_Add [edi].t4
            point_Set [ebx].t2

    compute_pDest:

        GDI_POINT_TO_GDI_ADDRESS [ebx].t0, edx
        mov [ebx].pDest, edx

        or [ebx].dwHintPin, HINTPIN_STATE_VALID_DEST

    ;// now is where we check if the pin is on screen

        ;// x points

        mov eax, [ebx].t0.x ;// get t0.x
        mov edx, [ebx].t2.x ;// get t2.x
        cmp eax, edx        ;// sort
        mov ecx, 16
        jle J1          ;// signed !
        xchg eax, edx
    J1: sub eax, ecx        ;// adjust a little bit
        add edx, ecx

        cmp eax, gdi_client_rect.right  ;// lowest x to the right of client rect ?
        jge pin_not_on_screen           ;// set off screen if so
        cmp edx, gdi_client_rect.left   ;// highest x to the left of client rect ?
        jle pin_not_on_screen           ;// set off screen if so

        ;// y points

        mov eax, [ebx].t0.y ;// get t0.y
        mov edx, [ebx].t2.y ;// get t2.y
        cmp eax, edx        ;// sort
        jle J2          ;// signed !
        xchg eax, edx
    J2: sub eax, ecx        ;// adjust a little bit
        add edx, ecx

        cmp eax, gdi_client_rect.bottom ;// lowest y below client rect ?
        jge pin_not_on_screen           ;// set off screen if so
        cmp edx, gdi_client_rect.top    ;// highest y abov client rect ?
        jle pin_not_on_screen           ;// set off screen if so

    pin_on_screen:

        or [ebx].dwHintPin, HINTPIN_STATE_ONSCREEN
        jmp all_done

    pin_not_on_screen:

        and [ebx].dwHintPin, NOT HINTPIN_STATE_ONSCREEN

pin_layout_points_hide::    ;// should never be hit
all_done:

    ret

pin_Layout_points ENDP


.DATA

pin_layout_points_jump  LABEL DWORD

    dd  OFFSET  pin_layout_points_hide  ;// hidden (ignore)
    dd  OFFSET  pin_layout_points_TFB   ;// bussed analog input
    dd  OFFSET  pin_layout_points_TFS   ;// connected analog input
    dd  OFFSET  pin_layout_points_TF    ;// unconnected analog input
    dd  OFFSET  pin_layout_points_LFB   ;// bussed logic input
    dd  OFFSET  pin_layout_points_LFS   ;// connected logic input
    dd  OFFSET  pin_layout_points_LF    ;// unconnected logic input
    dd  OFFSET  pin_layout_points_FB    ;// bussed output
    dd  OFFSET  pin_layout_points_FS    ;// connected output
    dd  OFFSET  pin_layout_points_FT    ;// unconnected output


;//                         defines:    t1, t2, pDest
;//     pin_Layout_points   sets:       HINTPIN_STATE_VALID_DEST
;//                                     HINTPIN_STATE_ON_SCREEN
;//
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////














.CODE

;////////////////////////////////////////////////////////////////////
;//                                                 private function
;//
;//                         esi is osc          (preserved)
;//     pin_compute_vectors ebx is pin          (preserved)
;//                         ebp is container    (preserved)
;//
;//                         destroys the rest
ASSUME_AND_ALIGN
pin_compute_vectors PROC

    ;// given pheta in the fpu
    ;// this computes E, H, HH, and s_alpha
    ;//
    ;// H is raw dG/dP
    ;// HH is normalized H neeed for further layout (refered to as hhx, hhy)

    ;// H is stored in the pin
    ;// HH is returned in the fpu
    ;// s_aplha is stored in the object
    ;//
    ;// fpu in:     pheta
    ;// fpu out:    ey  ex  hx  hy
    ;//
    ;// also note:
    ;//
    ;//     E will be relative to container center
    ;//     suiable for calling intersector in a future step

        ASSUME esi:PTR OSC_OBJECT
        ASSUME ebx:PTR APIN
        ASSUME ebp:PTR GDI_CONTAINER

    ;///////////////////////////////////////////////////////////////////////
    ;//
    ;//     formulas:
    ;//
    ;//         ex = a * ( cos(p) - s*cos(q*p) )
    ;//         ey = b * ( sin(p) + s*sin(q*p) )
    ;//
    ;//         hx = b * ( cos(p) + s*q*cos(q*p) )
    ;//         hy = -a * ( sin(p) + s*q*sin(q*p) )
    ;//
    ;//         hhx = normalized hx
    ;//         hhy = normalized hy
    ;//
    ;//                       k2
    ;//         GA = ( k1 - ----- ) * G
    ;//                     G^2+1
    ;//

    ;// convert pheta to offset into sin table

        fmul math_NormToOfs     ;// scale pheta to an offset
        mov edi, math_pSin      ;// edi points at sine table
        ASSUME edi:PTR DWORD

        fistp pin_temp          ;// store the newly rescaled pheta
        mov eax, math_AdrMask   ;// load the mask
        and eax, pin_temp       ;// eax is 1p

    ;// load the sin and cosine

        fld [edi+eax]           ;// sin

        add eax, math_OfsQuarter;// sin to cos
        and eax, math_AdrMask   ;// mask

        fld [edi+eax]           ;// cos     sin

        ;// eax points at the cos of p

    ;// determine how to continue

        ;// if Q=0, then H is simply based on E
        ;// if Q=2, then H and E use 2p
        ;// if Q=3, then H and E use 3p

        cmp [ebp].Q, 0  ;// is Q zero ?
        jnz q_not_zero

    ;// circle or ellipse

        ;// we aleady know we're a circle/ellipse,
        ;// so let's do the work and finish up right here
        ;// that means we can calculate E with no further ado
        ;// uh, that is unless an intersector is specified...

        ;// we use two formulas, one for circle, one for ellipse

        ;// eax points at the sin
        ;// must end up as      ;// ey      ex      hx      hy

    ;// check for circle or ellipse

        mov edx, [ebp].AB.x     ;// get ab.x
        cmp edx, [ebp].AB.y     ;// compare w/ab.y

        jnz is_ellipse

        ;// CIRCLE

            ;// hhx = cos(p)
            ;// hhy = sin(p)

            ;// hx = a*hhx(p)   ;// ex = hx
            ;// hy = a*hhy(p)   ;// ey = hy

            ;// s_alpha = 1/(a^2+1)

            ;// eax points at the sin
            ;// must end up as      ;// ey      ex      hhx     hhy

                                    ;// hhx     hhy
                fld [ebp].AB.x      ;// a       hhx     hhy
                fmul st, st(1)      ;// hx      hhx     hhy

                fld [ebp].AB.y      ;// b       hx      hhx     hhy
                fmul st, st(3)      ;// hy      hx      hhx     hhy

                jmp all_done        ;// that's it !


        ALIGN 16
        is_ellipse:
        ;// ELLIPSE


            ;// ex = a*cos(p)   hx = b*cos(p)
            ;// ey = b*sin(p)   hy = a*sin(p)

                            ;// cos     sin

                            ;//                 cos     sin         start
                            ;// ey      ex      hx      hy
                            ;// b*sin   a*cos   b*cos   a*sin       target

            fld [ebp].AB.x  ;// a       cos     sin
            fmul st, st(1)  ;// a*cos   cos     sin
            fld [ebp].AB.y  ;// b       a*cos   cos     sin
            fmul st, st(3)  ;// b*sin   a*cos   cos     sin
            fld [ebp].AB.x  ;// a       b*sin   a*cos   cos     sin
            fmulp st(4), st ;// b*sin   a*cos   cos     a*sin
            fld [ebp].AB.y  ;// b       b*sin   a*cos   cos     a*sin
            fmulp st(3), st ;// b*sin   a*cos   b*cos   a*sin

                            ;// ey      ex      hx      hy

            jmp compute_h_and_ga


        ALIGN 16
        q_not_zero:
        ;//////////////////////////////////////////////////////////////////////////////////
        ;//
        ;//             ex = A*( cos(p)-S*cos(Q*p) )    hx = B*( cos(p)+S*cos(Q*p)*Q )
        ;// polygon
        ;//             ey = B*( sin(p)+S*sin(Q*p) )    hy = A*( sin(p)-S*sin(Q*p)*Q )
        ;//
        ;//////////////////////////////////////////////////////////////////////////////////

            ;// current state           ;// cos(p)      sin(p)
            ;// eax points at the COSINE

        ;// determine Q, the angle multiplier

            sub eax, math_OfsQuarter    ;// kludge alert

            .IF [ebp].Q == 2            ;// triangularish
                fld math_2          ;// Q
                lea edx, [eax*2+math_OfsQuarter]        ;// edx is 2p
            .ELSE;// [esi].Q == 3.0     ;// squarish
                DEBUG_IF <[ebp].Q !!= 3>;// sposed to be 0, 2 or 3
                fld math_3          ;// Q
                lea edx, [eax+eax*2+math_OfsQuarter]    ;// edx is 3p
            .ENDIF

            and edx, math_AdrMask       ;// strip out extra

            ;// edx points at cos(Qp)

        ;// cosQp = S*cos( Q*p )
        ;// sinQp = S*sin( Q*p )

            fld [ebp].S         ;// S       Q       cos     sin
            fmul [edi+edx]      ;// cosQp   Q       cos     sin
            sub edx, math_OfsQuarter
            fld [ebp].S         ;// S       cosQp   Q       cos     sin
            and edx, math_AdrMask
            fmul [edi+edx]      ;// sinQp   cosQp   Q       cos     sin

        ;// cosQpQ = Q * cosQp
        ;// sinQpQ = Q * sinQp

                                ;// sinQp   cosQp   Q       cos     sin

            fld st(2)           ;// Q       sinQp   cosQp   Q       cos     sin
            fmul st, st(2)      ;// cosQpQ  sinQp   cosQp   Q       cos     sin

            fld st(1)           ;// sinQp   cosQpQ  sinQp   cosQp   Q       cos     sin
            fmulp st(4), st     ;// cosQpQ  sinQp   cosQp   sinQp   cos     sin

        ;// eex = cos - cosQp       hhx = cos + cosQpQ
        ;// eey = sin + sinQp       hhy = sin - sinQpQ

                                ;// cosQpQ  sinQp   cosQp   sinQp   cos     sin

            fxch st(5)          ;// sin     sinQp   cosQp   sinQp   cos     cosQpQ
            fadd st(1), st      ;// sin     eey     cosQp   sinQp   cos     cosQpQ
            fsubrp st(3), st    ;// eey     cosQp   hhy     cos     cosQpQ

            fxch st(3)          ;// cos     cosQp   hhy     eey     cosQpQ
            fsubr st(1), st     ;// cos     eex     hhy     eey     cosQpQ
            faddp st(4), st     ;// eex     hhy     eey     hhx

        ;// ex = A*eex      hx = B*hhx
        ;// ey = B*eey      hy = A*hhy

            fmul [ebp].AB.x     ;// ex      hhy     eey     hhx

            fxch                ;// hhy     ex      eey     hhx
            fmul [ebp].AB.x     ;// hy      ex      eey     hhx

            fxch st(3)          ;// hhx     ex      eey     hy
            fmul [ebp].AB.y     ;// hx      ex      eey     hy
            fxch st(2)          ;// eey     ex      hx      hy
            fmul [ebp].AB.y     ;// ey      ex      hx      hy


        compute_h_and_ga:       ;// ey      ex      hx      hy

        ;// formulas:
        ;//
        ;// hhx = normalized hx
        ;// hhy = normalized hy
        ;// GA = ( k1 - k2 / (G^2+1) ) * G

        ;// steps:
        ;//
        ;// h2 = hx^2 + hy^2        g2  = h2+1
        ;// h  = sqrt(h2)           gg  = k2 / g2
        ;// _h = 1/h                ga  = k1 - gg
        ;//
        ;// hhx = hx * _h           gax = - ga * hy
        ;// hhy = hy * _h           gay =   ga * hx

            fld st(3)           ;// hy      ey      ex      hx      hy

            fmul st, st         ;// hy^2    ey      ex      hx      hy

            fld st(3)           ;// hx      hy^2    ey      ex      hx      hy

            fmul st, st         ;// hx^2    hy^2    ey      ex      hx      hy

            fld1                ;// 1       hx^2    hy^2    ey      ex      hx      hy
            fxch st(2)          ;// hy^2    hx^2    1       ey      ex      hx      hy

            fadd                ;// h2      1       ey      ex      hx      hy

            fsqrt               ;// h       ey      ex      hx      hy
            fdiv                ;// _h      ey      ex      hx      hy

            fmul st(3), st      ;// _h      ey      ex      Hx      hy
            fmulp st(4), st     ;// ey      ex      Hx      Hy


    all_done:

        ret


pin_compute_vectors ENDP
;//
;//     pin_compute_vectors
;//
;//
;////////////////////////////////////////////////////////////////////




;//////
;//////
;//////     P I N _ L A Y O U T
;//////
;//////
;//////
;//////
;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
















;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;//
;//                                 given x and y in fpu
;//     pin_ComputePhetaFromXY      apporoximate pheta to point at it
;//
;//     calling:
;//         esi = osc   preserved
;//         FPU = X Y   relative to osc, NOT osc center
;//     returns:
;//         FPU = pheta in normalized form (-1 to +1) -> (-pi to + pi)
;//
;//     preserves ebx, esi, ebp
;//     destroys edi
;//     uses ALL fpu registers
;//
comment ~ /*

notes:

    this function has gone through 3 dev iterations

    see pheta_01.mcd through pheta_05.mcd

    goal:

        produce a value of pheta such that the perpendicular to E(pheta) intersects X

    problems:

        1) can't solve directly, have to use newtons approximation
        2) the initial guess value (atan(x,y)) may cause this to jump around

    solution:

        inspecting the formulas in the frequency domain reveals the correct
        derivations of the start s points (there are Q start points to test)
        see pheta_10, 11, and 12 mcd for work sheets

        then do newton

    steps:

        determine Q = 0, 2, 3
        determine quadrant

        for Q
            do two iterations for each start point
            save the ERR of the results
            determine the lowesest ERR1 value

        use that angle to do two more iterations

    function structure:

        main body

        build_perp_iterater

*/ comment ~







ASSUME_AND_ALIGN
pin_ComputePhetaFromXY  PROC

    ASSUME esi:PTR OSC_OBJECT   ;// preserved:  passed from caller

    push ebp

;// compute dx and dy

    OSC_TO_CONTAINER esi, ebp
                            ;// X   Y
    fsub [ebp].shape.OC.x   ;// dx  Y
    fxch                    ;// Y   dx
    fsub [ebp].shape.OC.y   ;// dy  dx
    fxch                    ;// dx  dy

;// check for circle

    cmp [ebp].Q, 0  ;// circle ?
    jne do_iterations

is_circle:

    fpatan                  ;// Q
    jmp all_done            ;// exit

do_iterations:

;// prepare the stack

    ;// stack looks like this
    ;//
    ;// p   q   dxB dyA ebp ret
    ;// 00  04  08  0C  10  14  18

    st_p    TEXTEQU <(DWORD PTR [esp+call_depth*4])>        ;// store integer value
    st_q    TEXTEQU <(DWORD PTR [esp+04h+call_depth*4])>    ;// stores iterated q (radians)
    st_x    TEXTEQU <(DWORD PTR [esp+08h+call_depth*4])>    ;// holds passed x value
    st_y    TEXTEQU <(DWORD PTR [esp+0Ch+call_depth*4])>    ;// holds passed y value
    st_dxB  TEXTEQU <(DWORD PTR [esp+10h+call_depth*4])>    ;// holds scaled dxB value
    st_dyA  TEXTEQU <(DWORD PTR [esp+14h+call_depth*4])>    ;// holds scaled dyA

    st_min_q    TEXTEQU <(DWORD PTR [esp+18h+call_depth*4])>    ;// holds radian angle with lowest err
    st_min_e    TEXTEQU <(DWORD PTR [esp+1Ch+call_depth*4])>    ;// holds lowest err

    st_q2   TEXTEQU <(DWORD PTR [esp+20h+call_depth*4])>    ;// second angle to test
    st_q3   TEXTEQU <(DWORD PTR [esp+24h+call_depth*4])>    ;// third angle to test (set to neg1 to ignore)

    stack_size = 28h
    call_depth=0


    sub esp, stack_size
    mov edi, math_pSin  ;// edi wil point at sine table for the duration
    ASSUME edi:PTR DWORD

;// scale, store dx, dy, dxB, dyA, load some registers

                            ;// dx  dy
    fst st_x
    fmul [ebp].AB.y
    fstp st_dxB

    fst st_y
    fmul [ebp].AB.x
    fstp st_dyA

    mov ecx, math_2_24
    mov st_min_e, ecx

    mov eax, st_x
    mov edx, st_y

    cmp [ebp].Q, 2


    ;// determine the quadrant and schedule the tests
    ;//
    ;// state ecx has -1 for terminating the search
    ;//
    ;// eax has st_x
    ;// edx has st_y

    ;// each branch exits with
    ;//
    ;//     eax = st_q
    ;//     fpu = st_q2
    ;//     ecx = st_q3

    jne Q_3

    ;// use the Q=2 method
    ;//
    ;//             eax     fpu     ecx
    ;//             ------  ------  ------
    ;// start       0       pi/3    -1
    ;//
    ;// x is pos
    ;//      neg    pi      2pi/3
    ;//
    ;// y is pos
    ;//      neg            chs

    Q_2:    or ecx, -1              ;// st_q3 will be terminated
            xor eax, [ebp].AB.x     ;// dx*A
            fld math_pi_3           ;// pi/3
            mov eax, 0              ;// zero by default
            jns Q_21                ;// jmp if quadrant 1 or 4
            ;// is is neg
            fadd st, st             ;// 2pi/3
            mov eax, math_pi        ;// use pi instead
    Q_21:   xor edx, [ebp].AB.y     ;// dy*B
            jns do_the_search       ;// jump if qudrant 2
            ;// y is neg
            fchs                    ;// use -2pi/3
            jmp do_the_search

    Q_3:

    ;// use the Q=3 method
    ;//             eax     edx     ecx
    ;//             ------  ------  ------
    ;// start               a24     pi/2
    ;//
    ;// x is pos    0
    ;//      neg    pi      pi-a24
    ;//
    ;// y is pos
    ;//      neg            chs     chs

            fld [ebp].a_24
            xor eax, [ebp].AB.x
            mov ecx, math_pi_2
            mov eax, 0
            jns Q_31
            ;// x is neg
            mov eax, math_pi
            fsubr math_pi

    Q_31:   xor edx, [ebp].AB.y
            jns do_the_search
            ;// y is neg
            fchs
            bts ecx, 31

    ;// now we do the seach
    ;// first we store registers
    ;// then do as many tests as we need to

    do_the_search:

    ;// store the scheduled angles

        mov st_q, eax
        fstp st_q2
        mov st_q3, ecx

    ;// first test

        call do_two_iterations
        fst st_min_q        ;// store now
        fmul math_RadToOfs      ;// p1
        fistp st_p              ;// empty
        call compute_err2   ;// compute the error
        fstp st_min_e

    ;// second test

        mov eax, st_q2
        mov st_q, eax
        call do_two_iterations
        fst st_q
        fmul math_RadToOfs      ;// p1
        fistp st_p              ;// empty
        call compute_err2   ;// compute the error

        ;// check if smaller
        fld st_min_e
        fucomp
        fnstsw ax
        sahf
        .IF !CARRY?

            mov edx, st_q
            fst st_min_e
            mov st_min_q, edx

        .ENDIF
        fstp st

    ;// third test

        mov eax, st_q3
        cmp eax, -1
        je done_with_search

        mov st_q, eax
        call do_two_iterations
        fst st_q
        fmul math_RadToOfs      ;// p1
        fistp st_p              ;// empty
        call compute_err2   ;// compute the error

        ;// check if smaller
        fld st_min_e
        fucomp
        fnstsw ax
        sahf
        .IF !CARRY?

            mov edx, st_q
            fst st_min_e
            mov st_min_q, edx

        .ENDIF
        fstp st

    ;// done with th search
    ;// do two more iterations
    done_with_search:

        mov eax, st_min_q
        mov st_q, eax
        call do_two_iterations

    ;// now we're completely done
    ;// 4) normalize and exit

        add esp, stack_size

    all_done:

        fmul math_RadToNorm     ;// p1
        pop ebp

        ret



;/////////////////////////////////////////////////////////////////////////

ALIGN 16
do_two_iterations:

    call_depth = 1

    ;// fpu must be empty
    ;// st_q must have angle in radians

        ;// first iteration

        fld st_q            ;// q0

        fmul math_RadToOfs  ;// p0
        fistp st_p          ;// empty

        call perp_iterater  ;// dq[0]

        fadd st_q           ;// q[1]

        ;// second iteration

        fst st_q            ;// q1
        fmul math_RadToOfs  ;// p1
        fistp st_p          ;// empty

        call perp_iterater  ;// dq[1]

        fadd st_q           ;// q[1]

        retn


ALIGN 16
comment ~ /*

perp_iterater:

    see pheta_01.mcd for worksheet and derivation

    formaula in vector format:
                                        where E = the etrack formula
            ( X - E(q) ) * G(q)               G is the first derivative
    q += --------------------------           J is the second derivative
         (X - E(q)) * J(q) - G(q)^2

    in seperate form:
                                        where dx,dy = X-E(q)
                - dx*gx - dy*gy
        q+= -------------------------
            dx*jx + dy*jy - gx^2+gy^2

    Ex = A * ( cos(q) - s * cos(Q*q) )      Ey = B * ( sin(q) + s * sin(Q*q) )

    Gx = A * ( -sin(q) + s*sin(Q*q)*Q )     Gy = B * ( cos(q) + s * cos(Q*q)*Q )

    Jx = A * ( -cos(q) - s*cos(Q*q)*Q*Q )   Jy = B * ( -sin(q) - s*sin(Q*q)*Q*Q )

    cq  ->  ScQ ->  ScQQ    ->  ScQQQ
    sq  ->  SsQ ->  SsQQ    ->  SsQQQ

    register set up :

    esi = osc
    ebx = pin
    edi = sin cos pointer
    ecx points at sin/cos of q
    edx points at sin/cos of Qq
    eax points at Q in real4 form
    ebp will point at container

*/ comment ~

perp_iterater:

    call_depth = 2

    ;// determine Q and set up sin cosine pointers

        xor eax, eax
        mov ecx, st_p
        or eax, [ebp].Q
        mov edx, ecx
        jpe perp_q_equals_3

    perp_q_equals_2:

        lea eax, math_2 ;// point at 2.0
        shl edx, 1          ;// edx * 2
        jmp perp_mask_the_address

    perp_q_equals_3:

        lea eax, math_3 ;// point at 3.0
        lea edx, [edx+edx*2];// edx * 3

    perp_mask_the_address:

        ASSUME eax:PTR DWORD

        and ecx, math_AdrMask
        and edx, math_AdrMask

    ;// build the sin/cos derivatives

    ;// sq  ->  SsQ ->  SsQQ    ->  SsQQQ
    ;// cq  ->  ScQ ->  ScQQ    ->  ScQQQ

        ;// ecx is sq
        ;// edx is sQ

        fld [edi+ecx]   ;// sq
        fld [eax]       ;// Q       sq
        fld [edi+edx]   ;// sQ      Q       sq
        fld [ebp].S     ;// S       sQ      Q       sq
        fmul            ;// SsQ     Q       sq
        add ecx, math_OfsQuarter
        add edx, math_OfsQuarter
        fld st(1)       ;// Q       SsQ     Q       sq
        fmul st, st(1)  ;// SsQQ    SsQ     Q       sq
        and ecx, math_AdrMask
        and edx, math_AdrMask
        fmul st(2), st  ;// SsQQ    SsQ     SsQQQ   sq

        ;// ecx is cq
        ;// edx is cQ

        fld [edi+ecx]   ;// cq  ...
        fld [eax]       ;// Q       cq  ...
        fld [edi+edx]   ;// cQ      Q       cq  ...
        fld [ebp].S     ;// S       cQ      Q       cq  ...
        fmul            ;// ScQ     Q       cq  ...
        fld st(1)       ;// Q       ScQ     Q       cq  ...
        fmul st, st(1)  ;// ScQQ    ScQ     Q       cq  ...
        fmul st(2), st  ;// ScQQ    ScQ     ScQQQ   cq  ...

                        ;// ScQQ    ScQ     ScQQQ   cq      SsQQ    SsQ     SsQQQ   sq

    ;// build the unscaled vector derivatives

    ;// ex =  cq - ScQ      ey =  sq + SsQ
    ;// gx = -sq + SsQQ     gy =  cq + ScQQ
    ;// jx = -cq + ScQQQ    jy = -sq - SsQQQ


                        ;// ScQQ    ScQ     ScQQQ   cq      SsQQ    SsQ     SsQQQ   sq

        fxch st(3)      ;// cq      ScQ     ScQQQ   ScQQ    SsQQ    SsQ     SsQQQ   sq
        fsubr st(1), st ;// cq      ex      ScQQQ   ScQQ    SsQQ    SsQ     SsQQQ   sq
        fadd st(3), st  ;// cq      ex      ScQQQ   -gy     SsQQ    SsQ     SsQQQ   sq
        fsubp st(2), st ;// ex      jx      gy      SsQQ    SsQ     SsQQQ   sq

        fxch st(6)      ;// sq      jx      gy      SsQQ    SsQ     SsQQQ   ex
        fadd st(4), st  ;// sq      jx      gy      SsQQ    ey      SsQQQ   ex
        fsub st(3), st  ;// sq      jx      gy      gx      ey      SsQQQ   ex
        faddp st(5), st ;// jx      gy      gx      ey      -jy     ex


    ;// scale

    ;// Ex = A * ex     Ey = B * ey
    ;// Gx = A * gx     Gy = B * gy
    ;// Jx = A * jx     Jy = B * jy

                        ;// jx      gy      gx      ey      -jy     ex

        fld [ebp].AB.x  ;// A       jx      gy      gx      ey      -jy     ex
        fmul st(1), st  ;// A       Jx      gy      gx      ey      -jy     ex
        fld [ebp].AB.y  ;// B       A       Jx      gy      gx      ey      -jy     ex
        fmul st(3), st  ;// B       A       Jx      Gy      gx      ey      -jy     ex
        fxch            ;// A       B       Jx      Gy      gx      ey      -jy     ex
        fmul st(4), st  ;// A       B       Jx      Gy      Gx      ey      -jy     ex
        fxch            ;// B       A       Jx      Gy      Gx      ey      -jy     ex
        fmul st(5), st  ;// B       A       Jx      Gy      Gx      Ey      -jy     ex
        fxch            ;// A       B       Jx      Gy      Gx      Ey      -jy     ex
        fmulp st(7), st ;// B       Jx      Gy      Gx      Ey      -jy     Ex
        fmulp st(5), st ;// Jx      Gy      Gx      Ey      -Jy     Ex


    ;// build the iterator

    ;// Dx = x-Ex       Dy = y-Ey

    ;//         - Dx*Gx - Dy*Gy
    ;// q+= -------------------------
    ;//     Dx*Jx + Dy*Jy - Gx^2+Gy^2

                        ;// Jx      Gy      Gx      Ey      -Jy     Ex
        fxch st(3)      ;// Ey      Gy      Gx      Jx      -Jy     Ex
        fsubr st_y      ;// Dy      Gy      Gx      Jx      -Jy     Ex
        fxch st(5)      ;// Ex      Gy      Gx      Jx      -Jy     Dy
        fsubr st_x      ;// Dx      Gy      Gx      Jx      -Jy     Dy

        fxch st(5)      ;// Dy      Gy      Gx      Jx      -Jy     Dx
        fmul st(4), st  ;// Dy      Gy      Gx      Jx      -DyJy   Dx
        fmul st, st(1)  ;// DyGy    Gy      Gx      Jx      -DyJy   Dx

        fxch st(5)      ;// Dx      Gy      Gx      Jx      -DyJy   DyGy
        fmul st(3), st  ;// Dx      Gy      Gx      DxJx    -DyJy   DyGy
        fmul st, st(2)  ;// DxGx    Gy      Gx      DxJx    -DyJy   DyGy

        fxch            ;// Gy      DxGx    Gx      DxJx    -DyJy   DyGy
        fmul st, st     ;// Gy^2    DxGx    Gx      DxJx    -DyJy   DyGy
        fxch st(2)      ;// Gx      DxGx    Gy^2    DxJx    -DyJy   DyGy
        fmul st, st     ;// Gx^2    DxGx    Gy^2    DxJx    -DyJy   DyGy

        fxch st(4)      ;// -DyJy   DxGx        Gy^2        DxJx    Gx^2    DyGy
        fsubp st(3), st ;// DxGx    Gy^2        DxJx+DyJy   Gx^2    DyGy
        faddp st(4), st ;// Gy^2    DxJx+DyJy   Gx^2        -top
        faddp st(2), st ;// DxJx+DyJy   G^2 -top
        fsub            ;// -bottom -top

        fdiv            ;// dPheta

        retn


ALIGN 16
comment ~ /*

    compute_err_2

        err2 is the distance squared between X and E

        formula:

            err2(p) = ( X - E(p) ) * ( X - E(p) )

            (x-ex) * (x-ex) + (y-ey) * (y-ey)

            ex =  cq - ScQ      ey =  sq + SsQ

*/ comment ~

compute_err2:

        call_depth = 1

    ;// determine Q and set up sin cosine pointers

        xor eax, eax
        mov ecx, st_p
        or eax, [ebp].Q
        mov edx, ecx
        jpe err2_q_equals_3

    err2_q_equals_2:

        shl edx, 1          ;// edx * 2
        jmp err2_mask_the_address

    err2_q_equals_3:

        lea edx, [edx+edx*2];// edx * 3

    err2_mask_the_address:

        ASSUME eax:PTR DWORD

        and ecx, math_AdrMask
        and edx, math_AdrMask

    ;// build the sin/cos derivatives

    ;// sq  ->  SsQ
    ;// cq  ->  ScQ

        ;// ecx is sq
        ;// edx is sQ

        fld [edi+ecx]   ;// sq
        fld [edi+edx]   ;// sQ      sq
        fmul [ebp].S    ;// SsQ     sq

        add ecx, math_OfsQuarter
        add edx, math_OfsQuarter

        and ecx, math_AdrMask
        and edx, math_AdrMask

        ;// ecx is cq
        ;// edx is cQ

        fld [edi+ecx]   ;// cq      ...
        fld [edi+edx]   ;// cQ      cq      ...
        fmul [ebp].S    ;// ScQ     cq      SsQ     sq

    ;// ex =  cq - ScQ      ey =  sq + SsQ


        fxch st(2)      ;// SsQ     cq      ScQ     sq
        faddp st(3), st ;// cp      ScQ     ey
        fsubr           ;// ex      ey

    ;// Ex = A * ex         Ey = B * ey

        fxch            ;// ey      ex
        fmul [ebp].AB.y ;// Ey      ex
        fxch            ;// ex      Ey
        fmul [ebp].AB.x ;// Ex      Ey

    ;// X = x - Ex      Y = y - Ey

        fxch
        fsub st_y
        fxch
        fsub st_x
        fxch
        fmul st, st
        fxch
        fmul st, st
        fxch
        fadd

        retn

pin_ComputePhetaFromXY  ENDP








ASSUME_AND_ALIGN
pin_SetInputShape PROC

    ASSUME ebp:PTR LIST_CONTEXT
    ASSUME esi:PTR OSC_OBJECT
    ASSUME ebx:PTR APIN

    ;// eax must have the new shape flags

    ;// destroys eax edx

    ;// NOTE: MUST PRESERVE ECX

    ;// check first if we need to chnage anything

        mov edx, [ebx].dwStatus
        and eax, PIN_LOGIC_TEST
        and edx, PIN_LOGIC_TEST

        cmp eax, edx
        jne have_to_set

    all_done:

        ret

    ALIGN 16
    have_to_set:

    ;// logic shape is different

        and [ebx].dwStatus, NOT PIN_LOGIC_TEST  ;// strip out previous flags
        or [ebx].dwStatus, eax              ;// mask on new flags

        BITR eax, PIN_LOGIC_INPUT
        mov edx, 0
        .IF CARRY?
            ;// need to get the correct logic shape
            BITSHIFT eax, PIN_LEVEL_POS, 4  ;// turn into a dword offset
            mov edx, pin_logic_shape_table[eax] ;// load address from table
        .ENDIF
        mov [ebx].pLShape, edx              ;// store as pin's logic shape

        or [ebx].dwHintI, HINTI_PIN_UPDATE_SHAPE        ;// add bits to pin
        or [esi].dwHintOsc, HINTOSC_INVAL_DO_PINS   ;// tell osc to call pins

        dlist_IfMember_jump oscI,esi,all_done,ebp

        dlist_InsertTail oscI, esi,,ebp ;// add the osc to the invalidate list

        jmp all_done

pin_SetInputShape ENDP











;/////////////////////////////////////////////////////////////////////////
;//
;//                 this is mainly called from a user action
;//     Show        so we'll be nice to ourselves and make it a function
;//
ASSUME_AND_ALIGN
PROLOGUE_OFF
pin_Show PROC STDCALL bShow:DWORD

    ;// bShow != 0, make sure pin is going to be shown
    ;// bShow == 0, make sure pin is going to be hidden

    ;// destroyes eax and edx

    ;// note: MUST PRESERVE ECX !!!

        ASSUME esi:PTR OSC_OBJECT
        ASSUME ebx:PTR APIN
        ASSUME ebp:PTR LIST_CONTEXT

    DEBUG_IF <[ebx].pObject !!= esi>    ;// supposed to be so

        mov eax, [esp+4]
        test eax, eax
        jz hide_the_pin

    show_the_pin:

        mov eax, HINTI_PIN_UNHIDE

        test [ebx].dwHintI, HINTI_PIN_UNHIDE    ;// have we already scheduled this ?
        jnz all_done

        test [ebx].dwHintPin, HINTPIN_STATE_HIDE;// is pin scheduled to be hidden ?
        jnz invalidate_the_pin

        test [ebx].dwStatus, PIN_HIDDEN         ;// is pin hidden now ?
        jnz invalidate_the_pin
        jmp all_done

    ALIGN 16
    hide_the_pin:

        mov eax, HINTI_PIN_HIDE

        test [ebx].dwStatus, PIN_HIDDEN         ;// is pin hidden now ?
        jnz all_done

        test [ebx].dwHintI, HINTI_PIN_HIDE      ;// have we already scheduled this ?
        jnz all_done

        test [ebx].dwHintPin, HINTPIN_STATE_HIDE;// is pin already scheduled to be hidden ?
        jnz all_done

    ALIGN 16
    invalidate_the_pin:

        or [ebx].dwHintI, eax                       ;// add bits to pin
        or [esi].dwHintOsc, HINTOSC_INVAL_DO_PINS   ;// tell osc to call pins

        dlist_IfMember_jump oscI,esi,all_done,ebp

        dlist_InsertTail oscI, esi,,ebp ;// add the osc to the invalidate list

    ALIGN 16
    all_done:

        ret 4

pin_Show ENDP
PROLOGUE_ON
;//
;//
;//     Show
;//
;/////////////////////////////////////////////////////////////////////////

;/////////////////////////////////////////////////////////////////////////
;//
;//                         pShortName --> pin.pFShape
;//     SetNameAndUnit      pLongName  --> pin.pLName
;//                         unit      --> pin.dwStatus
;//                                    --> color --> pin_color
;//                         gFlags GFLAG_AUTO_UNITS
;//                         pin invalidate color, shape
ASSUME_AND_ALIGN
PROLOGUE_OFF
pin_SetNameAndUnit  PROC STDCALL pShortName:DWORD, pLongName:DWORD, unit:DWORD
                    ;//     00      04              08              12

        ASSUME esi:PTR OSC_OBJECT
        ASSUME ebx:PTR APIN
        ASSUME ebp:PTR LIST_CONTEXT
        ;// destroys eax, edx
        ;// MUST PRESERVE ECX
        ;// this preserves UNIT_AUTOED

    DEBUG_IF <[ebx].pObject !!= esi>    ;// supposed to be so


    ;// check the short name
    ;// check the long name
    ;// check the unit
    ;// check the color

        ;// we'll use ecx as a 'need to invalidate flag

    ;// check the long name

        xchg ecx, [esp+8]       ;// get the long name, preserve ecx
        .IF ecx                 ;// make sure a long name was specified
            mov [ebx].pLName, ecx   ;// set the long name
            ;// ecx is non zero for need to invalidate
            xor ecx, ecx        ;// don't need to invalidate
        .ENDIF

    ;// check the short name

        mov eax, [esp+4]        ;// get the short name
        .IF eax != [ebx].pFShape;// same as current ?
            mov [ebx].pFShape, eax  ;// set the short name
            inc ecx             ;// need to invalidate
            or [ebx].dwHintI, HINTI_PIN_UPDATE_SHAPE
        .ENDIF


    ;// check the unit

        mov eax, [ebx].dwStatus ;// get the unit from pin
        mov edx, [esp+12]       ;// get the unit from user
        and eax, UNIT_TEST OR UNIT_AUTO_UNIT    ;// strip out extra stuff
        and edx, UNIT_TEST OR UNIT_AUTO_UNIT    ;// strip out extra stuff
        .IF eax != edx

            mov eax, edx                        ;// xfer user unit so we can set the color
            and [ebx].dwStatus, NOT (UNIT_TEST OR UNIT_AUTO_UNIT)   ;// remove the old units
            BITSHIFT eax, UNIT_INTERVAL, 1      ;// scoot unit to a color index
            or [ebx].dwStatus, edx              ;// store the new unit
            mov eax, unit_pin_color[eax*4]      ;// get the color

            invoke context_SetAutoTrace         ;// schedule a unit trace

    ;// check the color

            .IF eax != [ebx].color

                mov [ebx].color, eax        ;// store the color
                inc ecx                     ;// need to invalidate
                or [ebx].dwHintI, HINTI_PIN_UPDATE_COLOR

            .ENDIF

        .ENDIF

    ;// see if we need to invalidate

        dec ecx
        js all_done

        or [esi].dwHintOsc, HINTOSC_INVAL_DO_PINS   ;// tell osc to call pins
        or [esi].dwHintI, HINTI_OSC_UPDATE          ;// redraw the osc

        dlist_IfMember_jump oscI,esi,all_done,ebp   ;// make sure not already in list

        dlist_InsertTail oscI, esi,,ebp             ;// add the osc to the invalidate list

    all_done:

        xchg ecx, [esp+8]   ;// restore preserved ecx
        ret 12              ;// STDCALL 3 args

pin_SetNameAndUnit ENDP
PROLOGUE_ON


;/////////////////////////////////////////////////////////////////////////
;//
;//
;//     SetName
;//
ASSUME_AND_ALIGN
pin_SetName PROC


        ASSUME esi:PTR OSC_OBJECT
        ASSUME ebx:PTR APIN
        ASSUME ebp:PTR LIST_CONTEXT
        ;// destroys eax, edx
        ;// eax must have the new name
        ;// note: MUST PRESERVE ECX

    DEBUG_IF <[ebx].pObject !!= esi>    ;// supposed to be so

        cmp eax, [ebx].pFShape;// same as current ?
        je all_done

        mov [ebx].pFShape, eax  ;// set the short name
        or [ebx].dwHintI, HINTI_PIN_UPDATE_SHAPE
        or [esi].dwHintOsc, HINTOSC_INVAL_DO_PINS   ;// tell osc to call pins
        or [esi].dwHintI, HINTI_OSC_UPDATE          ;// redraw the osc

        dlist_IfMember_jump oscI,esi,all_done,ebp   ;// make sure not already in list

        dlist_InsertTail oscI, esi,,ebp             ;// add the osc to the invalidate list

    all_done:

        ret

pin_SetName ENDP



ASSUME_AND_ALIGN
pin_SetUnit PROC

        ASSUME ebp:PTR LIST_CONTEXT
        ASSUME esi:PTR OSC_OBJECT
        ASSUME ebx:PTR APIN

    ;// eax must have the new unit, extra bits will be removed
    ;// GFLAG_AUTO_TRACE is turned on
    ;// the pin is invalidated if the color changes

    ;// returns carry if a new unit was set

    ;// destroys eax, edx

    ;// this replaces UNIT_AUTOED

    ;// check first if new and old units are different

        mov edx, [ebx].dwStatus     ;// get old units
        and eax, UNIT_TEST OR UNIT_AUTO_UNIT OR UNIT_AUTOED ;// remove extra bits from new units
        and edx, UNIT_TEST OR UNIT_AUTO_UNIT OR UNIT_AUTOED

        cmp eax, edx
        jne have_to_set

    ;// zero !carry
    exit_now:

        ret

    ALIGN 16
    have_to_set:

        REMOVE_UNITS    EQU NOT (UNIT_TEST OR UNIT_AUTO_UNIT OR UNIT_AUTOED)

        and [ebx].dwStatus, REMOVE_UNITS        ;// remove old units
        invoke context_SetAutoTrace             ;// schedule a unit trace
        or [ebx].dwStatus, eax                  ;// merge in the new status
        or [esi].dwHintOsc, HINTOSC_INVAL_DO_PINS;// tell osc to call pins

        .IF (eax & UNIT_AUTO_UNIT) && (!(eax & UNIT_AUTOED))
            xor eax, eax
        .ELSE
            and eax, UNIT_TEST                  ;// remove all extra bits
        .ENDIF
        BITSHIFT eax, UNIT_INTERVAL, 4          ;// shift to a color index
        or [esi].dwHintI, HINTI_OSC_UPDATE      ;// tell osc to redraw
        mov eax, unit_pin_color[eax]            ;// get the color

        .IF eax != [ebx].color                  ;// new color ?

            mov [ebx].color, eax                ;// store the new color
            or [ebx].dwHintI, HINTI_PIN_UPDATE_COLOR;// invalidate color

        .ENDIF

    ;// invalidate

        dlist_IfMember_jump oscI,esi,all_done,ebp

        dlist_InsertTail oscI, esi,,ebp ;// add the osc to the invalidate list

    all_done:

        stc     ;// set that we did this
        jmp exit_now


pin_SetUnit ENDP








;////////////////////////////////////////////////////////////////////
;//
;//
;//     show containers         debug code
;//
IFDEF DEBUGBUILD

.DATA

    d_pheta_iter REAL4 0.09817477e+0    ;// 2*pi/64

.CODE


ASSUME_AND_ALIGN
show_containers PROC STDCALL PUBLIC uses esi edi ebx


    LOCAL point:POINT
    LOCAL d_pheta:DWORD
    LOCAL hDC:DWORD
    LOCAL old_pen:DWORD

    invoke GetDC, hMainWnd
    mov hDC, eax
    invoke GetStockObject, BLACK_PEN
    invoke SelectObject, hDC, eax
    mov old_pen, eax

    mov edi, math_pSin      ;// edi points at sine table
    ASSUME edi:PTR DWORD

    xor ebx, ebx    ;// zero for debugging

    stack_Peek gui_context, eax
    dlist_GetHead oscZ, esi, [eax]
    .WHILE esi

        .IF [esi].dwHintOsc & HINTOSC_STATE_ONSCREEN

            mov d_pheta, 0
            fld d_pheta

            .REPEAT

                push ebp
                mov ebp, [esi].pContainer
                ASSUME ebp:PTR GDI_CONTAINER

                invoke pin_compute_vectors

                fld1    ;// dummy value

        fld [ebp].shape.OC.x    ;// ocx sl  ey  ex  hx  hy
        faddp st(3), st         ;// sl  ey  Ex  hx  hy
        fild [esi].rect.left    ;// ox  sl  ey  Ex  hx  hy
        faddp st(3), st         ;// sl  ey  EX  hx  hy

        fld [ebp].shape.OC.y    ;// ocy sl  ey  EX  hx  hy
        faddp st(2), st         ;// sl  Ey  EX  hx  hy
        fild [esi].rect.top     ;// oy  sl  Ey  EX  hx  hy
        faddp st(2), st         ;// sl  EY  EX  hx  hy

                pop ebp

                fstp st

                fistp point.y
                fistp point.x
                fstp st
                fstp st

                sub point.x, GDI_GUTTER_X
                sub point.y, GDI_GUTTER_Y

                .IF d_pheta == 0
                    invoke MoveToEx, hDC, point.x, point.y, 0
                .ELSE
                    invoke LineTo, hDC, point.x, point.y
                .ENDIF

                fld d_pheta_iter
                fadd d_pheta
                fst d_pheta
                fldpi
                fldpi
                fadd
                fucomp
                fnstsw ax
                sahf

            .UNTIL CARRY?

            fstp st

            ;// lastly, we show the center point

            push ebp

            mov ebp, [esi].pContainer
            ASSUME ebp:PTR GDI_CONTAINER


            fild [esi].rect.left
            fadd [ebp].shape.OC.x
            fild [esi].rect.top
            fadd [ebp].shape.OC.y

            pop ebp

            fxch
            fistp point.x
            fistp point.y

            sub point.x, GDI_GUTTER_X
            sub point.y, GDI_GUTTER_Y

            invoke SetPixel, hDC, point.x, point.y, 0FFFFFFh

        .ENDIF

        dlist_GetNext oscZ, esi

    .ENDW

    invoke SelectObject, hDC, old_pen
    invoke ReleaseDC, hMainWnd, hDC

    ret

show_containers ENDP

ENDIF

;//
;//     show containers         debug code
;//
;//
;////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN


END
