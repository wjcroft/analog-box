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
;// ABox_IIR.asm
;//
;//
;// TOC
;//
;// iir_rotate
;// iir_log_lin
;// iir_lin_log
;// iir_mode_switch
;// iir_CalcCoeff
;//
;// iir_build_pole_curve
;// iir_build_zero_curve
;// iir_build_gain_curve
;//
;// iir_Calc
;// iir_PrePlay
;//
;// iir_CalcDests
;// iir_Ctor
;//
;// iir_Render
;// iir_SetShape
;//
;// iir_HitTest
;// iir_Control
;// iir_Move
;//
;// iir_InitMenu
;// iir_Command
;//
;// iir_SaveUndo
;// iir_LoadUndo
;//
;// iir_GetUnit



comment ~ /*

    abox2

    addition of log display mode
    uses the knob_log_lin function to compute the frequency
    addition of small display mode

    pole and zero use o and x font shape

*/ comment ~

OPTION CASEMAP:NONE

.586
.MODEL FLAT

USE_THIS_FILE equ 1

IFDEF USE_THIS_FILE

    .NOLIST
    include <Abox.inc>
    include <ABox_Knob.inc>
    .LIST

.DATA

    ;// IIR specific data
    ;// this is allocated with the constructor

    OSC_IIR STRUCT

        ;// pole and zero controls, coords relative to center
        ;// these are stored

        ;// POLE
            b12     fPOINT  {}  ;// filter coefficients
            PXY     POINT   {}  ;// current location rel to object  ( stored )
        ;// ZERO
            a12     fPOINT  {}  ;// filter coefficients
            ZXY     POINT   {}  ;// current location rel to object  ( stored )

        ;// previous signal values

            x1  REAL4   ?   ;// previous input 1
            x2  REAL4   ?   ;// previous input 2
            y1  REAL4   ?   ;// previous output 1
            y2  REAL4   ?   ;// previous output 2

        ;// real time adjusting ( computed by CalcCoeff )

            a12_prev    fPOINT  {}
            b12_prev    fPOINT  {}
            da12        fPOINT  {}
            db12        fPOINT  {}

        ;// pdests for controls

            pDest_pole dd 0
            pDest_zero dd 0

        ;// tables for displaying the gain curves

            NUM_IIR_POINTS  EQU 33

            pole_curve  REAL4 NUM_IIR_POINTS dup (0.0)
            zero_curve  REAL4 NUM_IIR_POINTS dup (0.0)
            gain_curve  REAL4 NUM_IIR_POINTS dup (0.0)
            gain_points POINT NUM_IIR_POINTS dup ({})

        ;// pole_value  REAL4   0.0 ;// frequency of pole
        ;// zero_value  REAL4   0.0 ;// frequency of zero
        ;// gain_value  REAL4   0.0 ;// gain at peak (linear)

            pole_string db  16 dup (0)  ;// string (hz)
            zero_string db  24 dup (0)  ;// string (hz)
            gain_string db  24 dup (0)  ;// string (db)

    OSC_IIR ENDS


;// OSC_BASE definition


osc_IIR OSC_CORE {  iir_Ctor,,
                    iir_PrePlay,iir_Calc }
        OSC_GUI  {  iir_Render, iir_SetShape,
                    iir_HitTest,iir_Control,    iir_Move,
                    iir_Command,iir_InitMenu,
                    ,,iir_SaveUndo,iir_LoadUndo,iir_GetUnit }
        OSC_HARD {}

        KLUDGE_VALUE = SIZEOF OSC_OBJECT + ( SIZEOF APIN ) * 3

        OSC_DATA_LAYOUT {NEXT_IIR,IDB_IIR,OFFSET popup_IIR,BASE_SHAPE_EFFECTS_GEOMETRY,
            3,(SIZEOF POINT)*4 + 4,
            KLUDGE_VALUE,
            KLUDGE_VALUE + SAMARY_SIZE,
            KLUDGE_VALUE + SAMARY_SIZE + SIZEOF OSC_IIR }

        OSC_DISPLAY_LAYOUT {iir_container, IIR_LIN_PSOURCE, ICON_LAYOUT( 13,3,3,5 ) }

        APIN_init {-1.0,,'X',, UNIT_AUTO_UNIT }     ;// input
        APIN_init { 0.5,,'A',, UNIT_DB      }       ;// attenuation
        APIN_init { 0.0,,'=',, PIN_OUTPUT OR UNIT_AUTO_UNIT }   ;// output

        short_name  db  'IIR zPlane',0
        description db  'This filter allows pole and zero control of a biquad filter. May be set to low/band/high pass and display detailed information about the filter.',0
        ALIGN 4

    ;// value  for dwUser

        IIR_HOVER_POLE      equ 00000001h   ;// hover flag for pole
        IIR_HOVER_ZERO      equ 00000002h   ;// hover flag for zero
        IIR_HOVER_TEST      equ 00000003h
        IIR_HOVER_MASK      equ NOT IIR_HOVER_TEST ;// used to zero the hover bits

        IIR_POLE_CHANGED    equ 00000004h   ;// set if user moves the pole reset by calc or render
        IIR_ZERO_CHANGED    equ 00000008h   ;// set if user moves the zero reset by calc or render
        IIR_CHANGED_TEST    equ 0000000Ch
        IIR_CHANGED_MASK    equ NOT IIR_CHANGED_TEST    ;// turns off both changed bits

        IIR_OSC_MOVED       equ 00000010h   ;// tells us that we need to calculate the pDests for the shapes

        IIR_LIN             equ 00000000h   ;// use normal polar coords
        IIR_LOG             equ 00001000h   ;// use log scale for angle

    ;// IIR_SHOW_CLIPPING   equ 00002000h   ;// show when signal is clipped
        IIR_IS_CLIPPING     equ 00004000h   ;// tracks that signal is clipped

        IIR_LP              equ 00020000h   ;// use low pass formula
        IIR_BP              equ 00010000h   ;// use band pass formula
        IIR_HP              equ 00000000h   ;// use highpass formula

        IIR_PASS_TEST       equ 00030000h
        IIR_PASS_MASK       equ NOT IIR_PASS_TEST

        IIR_SMALL           equ 00040000h   ;// show using small icon (no control)
        IIR_DETAILED        equ 00080000h   ;// show gain curves and frequencies

        IIR_BUILD_POLE_CURVE equ 0100000h   ;// need to build the pole curve
        IIR_BUILD_ZERO_CURVE equ 0200000h   ;// need to build the zero curve
        IIR_BUILD_GAIN_CURVE equ 0400000h   ;// need to build the gain curve
        IIR_BUILD_CURVE_TEST equ 0700000h


    ;// layout

        IIR_WIDTH  equ 90
        IIR_HEIGHT equ 90
        IIR_RADIUS_ADJUST equ 6 ;// inner board for center of control
        IIR_MAX_RADIUS equ IIR_WIDTH/2-IIR_RADIUS_ADJUST
        IIR_MAX_RADIUS_SQUARED equ IIR_MAX_RADIUS*IIR_MAX_RADIUS

        IIR_BIG_SMALL_X equ 20  ;// used to adjust the position of the object
        IIR_BIG_SMALL_Y equ 33  ;// when the shape changes

        IIR_DETAIL_TEXT_X equ 16    ;// X offset for text printing
        IIR_DETAIL_TEXT_Y equ 20    ;// Y offset for text printing
        IIR_DETAIL_SPACE  equ 4     ;// adjust for line height

    ;// IIR gdi

        iir_scale REAL4 3.125e-2 ;// scale from screen offset to real
        iir_max_radius REAL4 @REAL( IIR_MAX_RADIUS )
        iir_radius REAL4 45.0

        iir_pole_mask   dd  0   ;// ptr to the mask for the X shape
        iir_zero_mask   dd  0   ;// ptr to the mask for the 0 shape

        iir_lp_mask     dd  0   ;// ptr to 'LP' font
        iir_bp_mask     dd  0   ;// ptr to 'BP' font
        iir_hp_mask     dd  0   ;// ptr to 'HP' font

;/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
;//
;// display table for gain curves
;// copied from iirdisp.prn
;// built by iirdisp.mcd
;//
;// these hold various values needed to quickly derive and plot the various curves

    IIR_DISPLAY STRUCT

        x       REAL4   0.0 ;// x radial reletive to center
        y       REAL4   0.0 ;// y radial reletive to center
        x24_lin REAL4   0.0
        x_lin   REAL4   0.0
        x24_log REAL4   0.0
        x_log   REAL4   0.0

    IIR_DISPLAY ENDS


    iir_display_table LABEL IIR_DISPLAY

    ;//             X               Y               x24_lin         x_lin             x24_log           x_log
    IIR_DISPLAY{             1.0,             0.0,            4.0,             1.0 ,            4.0,            1.0  }
    IIR_DISPLAY{  0.995184726672,  0.098017140329,  3.96157056081,  0.995184726672 ,  3.99999779768,  0.999999724710 }
    IIR_DISPLAY{  0.980785280403,  0.195090322016,  3.84775906502,  0.980785280403 ,  3.99998893132,  0.999998616414 }
    IIR_DISPLAY{  0.956940335732,  0.290284677254,  3.66293922461,  0.956940335732 ,  3.99996846470,  0.999996058080 }
    IIR_DISPLAY{  0.923879532511,  0.382683432365,  3.41421356237,  0.923879532511 ,  3.99992846530,  0.999991058123 }
    IIR_DISPLAY{  0.881921264348,  0.471396736826,  3.11114046604,  0.881921264348 ,  3.99985630252,  0.999982037653 }
    IIR_DISPLAY{  0.831469612303,   0.55557023302,  2.76536686473,  0.831469612303 ,  3.99973200479,  0.999966500037 }
    IIR_DISPLAY{  0.773010453363,  0.634393284164,  2.39018064403,  0.773010453363 ,  3.99952416151,  0.999940518420 }
    IIR_DISPLAY{  0.707106781187,  0.707106781187,            2.0,  0.707106781187 ,  3.99918357637,  0.999897941839 }
    IIR_DISPLAY{  0.634393284164,  0.773010453363,  1.60981935597,  0.634393284164 ,  3.99863344943,  0.999829166586 }
    IIR_DISPLAY{   0.55557023302,  0.831469612303,  1.23463313527,  0.55557023302  ,  3.99775420549,  0.999719236272 }
    IIR_DISPLAY{  0.471396736826,  0.881921264348,  0.88885953396,  0.471396736826 ,  3.99636007552,  0.999544905884 }
    IIR_DISPLAY{  0.382683432365,  0.923879532511,  0.58578643762,  0.382683432365 ,  3.99416299478,  0.999270107976 }
    IIR_DISPLAY{  0.290284677254,  0.956940335732,  0.33706077539,  0.290284677254 ,  3.99071704165,  0.998838956195 }
    IIR_DISPLAY{  0.195090322016,  0.980785280403,  0.15224093497,  0.195090322016 ,  3.98533312623,  0.998164957087 }
    IIR_DISPLAY{  0.098017140329,  0.995184726672,  0.03842943919,  0.098017140329 ,  3.97694844408,  0.997114392143 }
    IIR_DISPLAY{             0.0,             1.0,  0.0          ,  0.0            ,  3.96392773822,  0.995480755492 }
    IIR_DISPLAY{ -0.098017140329,  0.995184726672,  0.03842943919,  -0.098017140326,  3.94376316492,  0.992945512719 }
    IIR_DISPLAY{ -0.195090322016,  0.980785280403,  0.15224093497,  -0.195090322016,  3.91262676601,  0.989018044073 }
    IIR_DISPLAY{ -0.290284677254,  0.956940335732,  0.33706077539,  -0.290284677254,  3.86471687797,  0.982944158888 }
    IIR_DISPLAY{ -0.382683432365,  0.923879532511,  0.58578643762,  -0.382683432365,  3.79133663348,  0.973567747190 }
    IIR_DISPLAY{ -0.471396736826,  0.881921264348,  0.88885953396,  -0.471396736826,  3.67967519359,  0.959123974467 }
    IIR_DISPLAY{  -0.55557023302,  0.831469612303,  1.23463313527,  -0.555570233020,  3.51139562642,  0.936935913820 }
    IIR_DISPLAY{ -0.634393284164,  0.773010453363,  1.60981935597,  -0.634393284164,  3.26151614541,  0.902983408681 }
    IIR_DISPLAY{ -0.707106781187,  0.707106781187,            2.0,  -0.707106781187,  2.89901070138,  0.851324071869 }
    IIR_DISPLAY{ -0.773010453363,  0.634393284164,  2.39018064403,  -0.773010453363,  2.39258423138,  0.773399028863 }
    IIR_DISPLAY{ -0.831469612303,  0.555570233020,  2.76536686473,  -0.831469612303,  1.72877174346,  0.657413823908 }
    IIR_DISPLAY{ -0.881921264348,  0.471396736826,  3.11114046604,  -0.881921264348,  0.95406738434,  0.488381865025 }
    IIR_DISPLAY{ -0.923879532511,  0.382683432365,  3.41421356237,  -0.923879532511,  0.25059489662,  0.250297271571 }
    IIR_DISPLAY{ -0.956940335732,  0.290284677254,  3.66293922461,  -0.956940335732,  0.01765081309,  -0.066428181325 }
    IIR_DISPLAY{ -0.980785280403,  0.195090322016,  3.84775906502,  -0.980785280403,  0.79858898397,  -0.446819030475 }
    IIR_DISPLAY{ -0.995184726672,  0.098017140329,  3.96157056081,  -0.995184726672,  2.66882108230,  -0.816826340525 }
    IIR_DISPLAY{            -1.0,  0.0           ,  4.0          ,  -1.0           ,  3.99996235057,  -0.99999529381  }


;/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


;// to show clipping, we keep a private dword

    ALIGN 16

    iir_clipping    dd  0




;// then we get an osc map

    OSC_MAP STRUCT

        OSC_OBJECT  {}
        pin_x   APIN {}
        pin_a   APIN {}
        pin_y   APIN {}
        data_y  dd SAMARY_LENGTH DUP (0)
        iir     OSC_IIR {}

    OSC_MAP ENDS

.CODE



;////////////////////////////////////////////////////////////////////
;//
;//
;//     CONVERTION FUNCTIONS
;//
comment ~ /*

    these functions mange the convertion between vaious mappings
    ALL coords are reletive to the osc center

  NOMENCLATURE:

    POLE        ZERO
    P.X,P.Y     Z.X,Z.Y     location of the pole and zero in screen space
    bx,by       ax,ay       location of the pole and zero in Z-plane space
    b1,b2       a1,a2       filter coefficients for the pole and zero
    db1,db2     da1,da2     how to adjust the coefficients during a move

    log/lin convertion is always from_to

    axy and bxy are tempory, stored in FPU

  OPERATIONS:

    not changed             changed
    PXY -> bxy -> b12   or  b12 -> b12_prev, PXY -> bxy -> b12, (b12_prev,p12) -> db12
    ZXY -> axy -> a12       a12 -> a12_prev, ZXY -> axy -> a12, (a12_prev,a12) -> da12

  SUBSTEPS: PXY -> bxy  ZXY -> axy

    lin mode:   bx,by = (P1.X,P1.Y)*iir_scale
                ax,ay = (Z1.X,Z1.Y)*iir_scale

    log mode:   bx,by = iir_log_lin(P1.X,P1.Y)
                ax,ay = iir_log_lin(Z1.X,Z1.Y)

    not changed:                changed:

        a1 = -2*ax              a1_prev = a1    a1=-2ax     da1 = a1-a1_prev / SAMARY_LENGTH
        a2 = ax^2 + ay^2        a2_prev = a1    a2= mag2(a) da2 = a2-a2_prev / SAMARY_LENGTH
        b1 = 2*bx               same for b12
        b2 = -( bx^2 + by^2 )   this makes a1 correct for the next calc
                                iir_calc must be sure to load a1_prev

*/ comment ~





ASSUME_AND_ALIGN
iir_rotate PROC PRIVATE

    ;// given an angle in radians
    ;// this will rotate the xy coords appropriately


    ;// IN:     angle   x       y
    ;// OUT:    X       Y

    fsincos         ;// cos     sin     x       y

    fld st          ;// cos     cos     sin     x       y
    fmul st, st(3)  ;// x*cos   cos     sin     x       y
    fxch            ;// cos     x*cos   sin     x       y
    fmul st, st(4)  ;// y*cos   x*cos   sin     x       y
    fxch st(2)      ;// sin     x*cos   y*cos   x       y
    fmul st(4), st  ;// sin     x*cos   y*cos   x       y*sin
    fmulp st(3), st ;// x*cos   y*cos   x*sin   y*sin

    fxch            ;// y*cos   x*cos   x*sin   y*sin
    faddp st(2), st ;// x*cos   Y       y*sin
    fsubrp st(2), st;// Y       X
    fxch

    ret

iir_rotate ENDP



ASSUME_AND_ALIGN
iir_log_lin PROC

    ;// fpu must enter as:  x   y       where the points are assumed to be on the log scale
    ;// fpu exits as:       X   Y       points are now on the linear scale
    ;//                                 this is accomplished by rotating
    ;// requires 3 free registers

    ;// formula: < rotate by the difference in angles >
    ;//
    ;//     pheta = 1/pi * fpatan( ax,ay )
    ;//     theta = math_log_to_lin( pheta )
    ;//     dA = (theta - pheta) * pi
    ;//     ax = ax*cos(dA)-ay*sin(dA)
    ;//     ay = ax*sin(dA)+ay*cos(dA)

    fld math_1_pi   ;// 1/pi    x       y
    fld st(2)       ;// y       1/pi    x       y
    fld st(2)       ;// x       y       1/pi    x       y
    fpatan          ;// fpatan  1/pi    x       y
    fmul            ;// pheta   x       y
    fld st          ;// pheta   pheta   x       y
    call math_log_lin;//theta   pheta   x       y
    fsubr           ;// dangle  x       y
    fldpi
    fmul

    invoke iir_rotate


    ret

iir_log_lin ENDP



ASSUME_AND_ALIGN
iir_lin_log PROC

    ;// fpu must enter as:  x   y       where the points are assumed to be on the lin scale
    ;// fpu exits as:       X   Y       points are now on the log scale
    ;//                                 this is accomplished by rotating
    ;// requires 3 free registers

    ;// formula: < rotate by the difference in angles >
    ;//
    ;//     pheta = 1/pi * fpatan( ax,ay )
    ;//     theta = math_lin_to_log( pheta )
    ;//     dA = (theta - pheta) * pi
    ;//     ax = ax*cos(dA)-ay*sin(dA)  \ iir rotate
    ;//     ay = ax*sin(dA)+ay*cos(dA)  /

    fld math_1_pi   ;// 1/pi    x       y
    fld st(2)       ;// y       1/pi    x       y
    fld st(2)       ;// x       y       1/pi    x       y
    fpatan          ;// fpatan  1/pi    x       y
    fmul            ;// pheta   x       y
    fld st          ;// pheta   pheta   x       y
    call math_lin_log;//theta   pheta   x       y
    fsubr           ;// dangle  x       y
    fldpi
    fmul

    invoke iir_rotate

    ret

iir_lin_log ENDP








ASSUME_AND_ALIGN
iir_mode_switch PROC PRIVATE

    ASSUME esi:PTR OSC_OBJECT

    OSC_TO_DATA esi, ebx, OSC_IIR

    .IF [esi].dwUser & IIR_LOG

        ;// we are switching lin to log

        fild [ebx].PXY.y
        fild [ebx].PXY.x
        invoke iir_lin_log
        fistp [ebx].PXY.x
        fistp [ebx].PXY.y

        fild [ebx].ZXY.y
        fild [ebx].ZXY.x
        invoke iir_lin_log
        fistp [ebx].ZXY.x
        fistp [ebx].ZXY.y

    .ELSE

        ;// we are switching log to lin

        fild [ebx].PXY.y
        fild [ebx].PXY.x
        invoke iir_log_lin
        fistp [ebx].PXY.x
        fistp [ebx].PXY.y

        fild [ebx].ZXY.y
        fild [ebx].ZXY.x
        invoke iir_log_lin
        fistp [ebx].ZXY.x
        fistp [ebx].ZXY.y

    .ENDIF

    or [esi].dwUser, IIR_OSC_MOVED + IIR_BUILD_GAIN_CURVE + IIR_BUILD_POLE_CURVE + IIR_BUILD_ZERO_CURVE
    ;// make sure the dests and curves get rebuilt

    ret


iir_mode_switch ENDP




ASSUME_AND_ALIGN
iir_CalcCoeff PROC PRIVATE

        ASSUME esi:PTR OSC_MAP

    ;// to simplify the calc, and because this doesn't get called very often
    ;// we simply always do the changing stuff
    ;// so instead of 27 states, we're down to six

    ;// this where we calculate the coefficients from the screen
    ;// assume pole1 and zero1 are the current points
    ;// assume that the points are relative to the center of box

    ;// we also compute any adjusts we may need
    ;// we reset the changed bits in the process

    ;// controls have moved
    ;// so we calculate dPX and dPY


    ;// POLE
    ;// b1 = 2*PX
    ;// b2 = -(PX^2 + PY^2)

        ;// xfer b12 to b12_prev

        point_Get [esi].iir.b12
        fld iir_scale
        point_Set [esi].iir.b12_prev

        ;// load PXY and do convertion common to both modes

        fild [esi].iir.PXY.x
        fild [esi].iir.PXY.y    ;// py      px      scale

        fld st(2)           ;// scale   py      px      scale
        fmulp st(2), st     ;// py      bx      scale
        test [esi].dwUser, IIR_LOG  ;// check log mode now
        fmulp st(2), st     ;// bx      by
        .IF !ZERO?
            invoke iir_log_lin
        .ENDIF              ;// bx      by

        ;// b1 = 2*bx
        ;// b2 = -( bx^2 + by^2 )   this makes a1 correct for the next calc

        fld st          ;// bx      bx      by
        fadd st(1), st  ;// bx      2bx     by

        fmul st, st     ;// bx^2    2bx     by

        fld st(2)       ;// by      bx^2    2bx     by
        fmulp st(3), st ;// bx^2    2bx     by^2
        fxch            ;// 2bx     bx^2    by^2
        fst [esi].iir.b12.x ;// 2bx     bx^2    by^2
        fsub [esi].iir.b12_prev.x;Db1   bx^2    by^2
        fxch            ;// bx^2    Db1     by^2
        faddp st(2), st ;// Db1     -b2
        fld math_1_1024 ;// 1/1024  Db1     -b2
        fmul st(1), st  ;// 1/1024  db1     -b2
        fxch st(2)      ;// -b2     db1     1/1024
        fchs            ;// b2      db1     1/1024
        fst [esi].iir.b12.y ;// b2      db1     1/1024
        fsub [esi].iir.b12_prev.y; DB2  db1     1/1024
        fxch            ;// db1     DB2     1/1024
        fstp [esi].iir.db12.x;//DB2     1/1024
        fmul            ;// db2
        fstp [esi].iir.db12.y   ;// empty

    ;// ZERO
    ;// a1 = -2*ZX
    ;// a2 = ZX^2 + ZY^2

        ;// xfer a12 to a12_prev

        point_Get [esi].iir.a12
        fld iir_scale
        point_Set [esi].iir.a12_prev

        ;// load ZXY and do convertion common to both modes

        fild [esi].iir.ZXY.x
        fild [esi].iir.ZXY.y    ;// zy  zx  scale

        fld st(2)           ;// scale   zy      zx      scale
        fmulp st(2), st     ;// zy      ax      scale
        test [esi].dwUser, IIR_LOG;// check log mode now
        fmulp st(2), st     ;// ax      ay
        .IF !ZERO?
            invoke iir_log_lin
        .ENDIF              ;// ax      ay

        ;// a1 = -2*ax
        ;// a2 = ax^2 + ay^2    this makes a1 correct for the next calc

        fld st          ;// ax      ax      ay
        fadd st(1), st  ;// ax      2ax     ay
        fmul st, st     ;// ax^2    2ax     ay
        fld st(2)       ;// ay      ax^2    2ax     ay
        fmulp st(3), st ;// ax^2    2ax     ay^2
        fxch            ;// 2ax     ax^2    ay^2
        fchs            ;// -2ax    ax^2    ay^2
        fst [esi].iir.a12.x ;// 2ax     ax^2    ay^2
        fsub [esi].iir.a12_prev.x;Da1   ax^2    ay^2
        fxch            ;// ax^2    Da1     ay^2
        faddp st(2), st ;// Da1     a2
        fld math_1_1024 ;// 1/1024  Da1     a2
        fmul st(1), st  ;// 1/1024  da1     a2
        fxch st(2)      ;// a2      da1     1/1024
        fst [esi].iir.a12.y ;// a2      da1     1/1024
        fsub [esi].iir.a12_prev.y; DB2  da1     1/1024
        fxch            ;// da1     DB2     1/1024
        fstp [esi].iir.da12.x;//DB2     1/1024
        fmul            ;// da2
        fstp [esi].iir.da12.y   ;// empty

    ;// that should do it

        and [esi].dwUser, IIR_CHANGED_MASK  ;// turn off the changed bits

        ret

iir_CalcCoeff ENDP






;////////////////////////////////////////////////////////////////////
;//
;//
;//     display generation
;//

ASSUME_AND_ALIGN
iir_build_pole_curve    PROC

    ASSUME esi:PTR OSC_MAP

    ;// uses ebx and edi

    ;// 1) point ebx at the lin or log column and build iterators
    ;// 2) build B1 and B2 and load b2
    ;// 3) do the loop
    ;// 4) reset the need to build flag, store the gain
    ;//
    ;// formulas:
    ;//
    ;// B1 = 2*b1*b2-2*b1           B2 = 1+b1*b1 + 2*b2 + b2*b2
    ;//
    ;// p[n] = -x24[n]*b2 + x[n]*B1 + B2

    ;// make sure the b1 and b2 parameters are built

        .IF [esi].dwUser & IIR_POLE_CHANGED
        ENTER_PLAY_SYNC GUI
        .IF [esi].dwUser & IIR_POLE_CHANGED
            OSC_TO_DATA esi, ebx, OSC_IIR   ;// get our data pointer
            invoke iir_CalcCoeff
        .ENDIF
        LEAVE_PLAY_SYNC GUI
        .ENDIF

    ;// 1) point ebx at the lin or log column and build iterators

        test [esi].dwUser, IIR_LOG
        lea ebx, iir_display_table.x24_lin
        jz @F
        lea ebx, iir_display_table.x24_log
    @@:
        ASSUME ebx:PTR DWORD
        ASSUME edi:PTR DWORD

        lea edi, [esi].iir.pole_curve
        xor ecx, ecx

    ;// 2) build B1 and B2 and load b2
    ;//
    ;//     B1 = 2*(b2-1)*b1    B2 = 1 + 2*b2 + b2*b2 + b1*b1
    ;//            ( B121  )                    (   B1212   )

        fld [esi].iir.b12.y ;// b2
        fld [esi].iir.b12.x ;// b1      b2

        fld st(1)       ;// b2      b1      b2
        fmul st, st     ;// b2*b2   b1      b2
        fld st(1)       ;// b1      b2      b1      b2
        fmul st, st     ;// b1*b1   b2*b2   b1      b2

        fld1            ;// 1       b1*b1   b2*b2   b1      b2
        fsubr st, st(4) ;// b2-1    b1*b1   b2*b2   b1      b2

        fxch st(2)      ;// b2*b2   b1*b1   b2-1    b1      b2
        fadd            ;// B1212   b2-1    b1      b2

        fld1            ;// 1       B1212   b2-1    b1      b2
        fadd st, st(4)  ;// 1+b2    B1212   b2-1    b1      b2

        fxch st(2)      ;// b2-1    B1212   1+b2    b1      b2

        fmulp st(3), st ;// B1212   1+b2    B121    b2

        fxch            ;// 1+b2    B1212   B121    b2
        fadd st, st(3)  ;// 1+2b2   B1212   B121    b2

        fxch st(2)      ;// B121    B1212   1+2b2   b2
        fadd st, st     ;// B1      B1212   1+2b2   b2

        fxch            ;// B1212   B1      1+2b2   b2
        faddp st(2), st ;// B1      B2      b2

    ;// 3) do the loop

        .REPEAT

        ;// p[n] = x[n]  *  B1 + B2 - x24[n] * b2
        ;//       [ebx+4]             [ebx]

            fld [ebx]       ;// x24     B1      B2      b2
            fmul st, st(3)  ;// x24b2   B1      B2      b2

            fld [ebx+4]     ;// x       x24b2   B1      B2      b2
            fmul st, st(2)  ;// xB1     x24b2   B1      B2      b2

            fxch            ;// x24b2   xB1     B1      B2      b2
            fsubr st, st(3) ;// B2-x24  xB1     B1      B2      b2
            fadd            ;// P[n]    B1      B2      b2


            fld math_Millionth
            fld st(1)
            fabs
            fucompp
            fnstsw ax
            sahf
            ja P1

            ftst
            fstp st
            fnstsw ax
            fld math_Million
            sahf
            jnc P2
            fchs
            jmp P2

        P1:
            fld1            ;// 1       P[n]    B1      B2      b2
            fdivr           ;// 1/P[n]  B1      B2      b2

        P2: fstp [edi+ecx*4]

            inc ecx
            add ebx, SIZEOF IIR_DISPLAY

        .UNTIL ecx >= NUM_IIR_POINTS

        fstp st
        fstp st
        fstp st

    ;// 3a while were here, let's build the frequency string

        ;// b1 = 2*PX   b2 = -( PY^2 +PY^2 )
        ;//
        ;// x = b1/2    r^2 = -b2
        ;//
        ;// x^2+y^2 = r^2   -->  y = sqrt( abs(b2-x^2) )
        ;//
        ;// then f = 1/pi * patan( x, y )

        fld [esi].iir.b12.x ;// b1
        fmul math_1_2               ;// x
        fld [esi].iir.b12.y ;// -r^2    x
        fabs                        ;// r^2     x
        fld st(1)                   ;// x       r^2     x
        fmul st, st                 ;// x^2     r^2     x
        fsub                        ;// x^2-r^2 x
        fabs                        ;// y^2     x
        fsqrt                       ;// y       x
        fxch                        ;// x       y
        fpatan                      ;// theta
        fmul math_1_pi              ;// f

        lea edx, [esi].iir.pole_string
        mov DWORD PTR [edx], '=X'
        add edx, 2

        invoke unit_BuildString, edx, UNIT_HERTZ, 0

    ;// 4) reset the need to build flag

        and [esi].dwUser, NOT IIR_BUILD_POLE_CURVE

        ret

iir_build_pole_curve    ENDP




ASSUME_AND_ALIGN
iir_build_zero_curve    PROC

    ASSUME esi:PTR OSC_MAP

    ;// uses ebx and edi

    ;// 1) point ebx at the lin or log column and build iterators
    ;// 2) build B1 and B2 and load b2
    ;// 3) do the loop
    ;// 4) reset the need to build flag, store the gain
    ;//
    ;// formulas:
    ;//
    ;// HP: A1 = 2*a1 + 2*a1*a2     A2 = -2*a2 + a2*a2 + a1*a1 + 1
    ;//
    ;//     z[n] = x24[n]*a2 + A1*x[n] + A2
    ;//
    ;// BP: A1 = 2*a1               A2 = a1*a1 + 1
    ;//
    ;//     z[n] = A1*x[n] + A2
    ;//
    ;// LP: z[n] = 1


    ;// 1) point ebx at the lin or log column and build iterators
    ;//     skip if lowpass mode

        test [esi].dwUser, IIR_LP
        jz @F

        ;// lowpass only has to store 1

            lea edi, [esi].iir.zero_curve
            mov eax, math_1
            mov ecx, NUM_IIR_POINTS
            rep stosd
            jmp all_done

    @@:

    ;// make sure the a1 and a2 parameters are built

        .IF [esi].dwUser & IIR_ZERO_CHANGED
        ENTER_PLAY_SYNC GUI
        .IF [esi].dwUser & IIR_ZERO_CHANGED
            OSC_TO_DATA esi, ebx, OSC_IIR   ;// get our data pointer
            invoke iir_CalcCoeff
        .ENDIF
        LEAVE_PLAY_SYNC GUI
        .ENDIF

    ;// point at correct column and build the iterator

        test [esi].dwUser, IIR_LOG
        lea ebx, iir_display_table.x24_lin
        jz @F
        lea ebx, iir_display_table.x24_log
    @@:
        ASSUME ebx:PTR DWORD
        ASSUME edi:PTR DWORD

        xor ecx, ecx
        lea edi, [esi].iir.zero_curve


    ;// do the correct version for BP and HP

        test [esi].dwUser, IIR_BP
        jz high_pass

    band_pass:
    ;// 2) build the A1 and A2 values
    ;//
    ;// BP: A1 = 2*a1               A2 = a1*a1 + 1


        fld1            ;// 1
        fld [esi].iir.a12.x ;// a1
        fld st          ;// a1      a1      1
        fmul st(1), st  ;// a1      a1*a1   1
        fadd st, st     ;// 2*a1    a1*a1   1
        fxch            ;// a1*a1   2*a1    1
        faddp st(2), st ;// A1      A2

    ;// 3) do the loop
    ;//
    ;// BP: z[n] = A1*x[n] + A2

        add ebx, 4

        .REPEAT

            fld [ebx]   ;// x   A1      A2
            fmul st, st(1)
            fadd st, st(2)
            fstp [edi+ecx*4]

            inc ecx
            add ebx, SIZEOF IIR_DISPLAY

        .UNTIL ecx >= NUM_IIR_POINTS

        fstp st
        fstp st


    ;// 3a) build the frequency string
    ;//     see build_pole_curve section 3a for this derivation

        fld [esi].iir.a12.x ;// a1
        fmul math_neg_1_2           ;// x
        fld1                        ;// r^2 x
        jmp finish_the_zero_string

    high_pass:
    ;// 2) build the A1 and A2 points, load a2
    ;//
    ;// HP: A1 = 2*(a2+1)*a1        A2 = 1 - 2*a2 + a2*a2 + a1*a1
    ;//            ( A121  )                        (   A1212   )


        fld [esi].iir.a12.y ;// a2
        fld [esi].iir.a12.x ;// a1      a2

        fld st(1)       ;// a2      a1      a2
        fmul st, st     ;// a2*a2   a1      a2
        fld st(1)       ;// a1      a2      a1      a2
        fmul st, st     ;// a1*a1   a2*a2   a1      a2

        fld1            ;// 1       a1*a1   a2*a2   a1      a2
        fadd st, st(4)  ;// a2+1    a1*a1   a2*a2   a1      a2

        fxch st(2)      ;// a2*a2   a1*a1   a2+1    a1      a2
        fadd            ;// A1212   a2+1    a1      a2

        fld1            ;// 1       A1212   a2+1    a1      a2
        fsub st, st(4)  ;// 1-a2    A1212   a2+1    a1      a2

        fxch st(2)      ;// a2+1    A1212   1-a2    a1      a2
        fmulp st(3), st ;// A1212   1-a2    A121    a2

        fxch            ;// 1-a2    A1212   A121    a2
        fsub st, st(3)  ;// 1-2a2   A1212   A121    a2

        fxch st(2)      ;// A121    A1212   1-2a2   a2
        fadd st, st     ;// A1      A1212   1-2a2   a2

        fxch            ;// A1212   A1      1-2a2   a2
        faddp st(2), st ;// A1      A2      a2


    ;// 3) do the loop
    ;//
    ;//     z[n] = x24[n]*a2 + A1*x[n] + A2
    ;//            [ebx+4]       [ebx]

        .REPEAT

            fld [ebx]       ;// x24     A1      A2      a2
            fmul st, st(3)  ;// x24a2   A1      A2      a2

            fld [ebx+4]     ;// x       x24a2   A1      A2      a2
            fmul st, st(2)  ;// xA1     x24a2   A1      A2      a2

            fxch            ;// x24a2   xA1     A1      A2      a2
            fadd st, st(3)  ;// A2+x24  xA1     A1      A2      a2
            fadd            ;// Z[n]    A1      A2      a2

            fstp [edi+ecx*4]

            inc ecx
            add ebx, SIZEOF IIR_DISPLAY

        .UNTIL ecx >= NUM_IIR_POINTS

        fstp st
        fstp st
        fstp st

    ;// 3a) build the frequency string
    ;//     see build_pole_curve section 3a for this derivation

        fld [esi].iir.a12.x ;// a1
        fmul math_neg_1_2           ;// x
        fld [esi].iir.a12.y ;// r^2 x

    finish_the_zero_string:

        fld st(1)                   ;// x       r^2     x
        fmul st, st                 ;// x^2     r^2     x
        fsub                        ;// x^2-r^2 x
        fabs                        ;// y^2     x
        fsqrt                       ;// y       x
        fxch                        ;// x       y
        fpatan                      ;// theta
        fmul math_1_pi              ;// f

        lea edx, [esi].iir.zero_string
        mov DWORD PTR [edx], '=O'
        add edx, 2

        invoke unit_BuildString, edx, UNIT_HERTZ, 0

    ;// 4) reset the need to build flag

    all_done:


        and [esi].dwUser, NOT IIR_BUILD_ZERO_CURVE

        ret

iir_build_zero_curve    ENDP




ASSUME_AND_ALIGN
iir_build_gain_curve    PROC

    ASSUME esi:PTR OSC_MAP

;// formula:    H[n] = sqrt( z[n] * p[n] )
;//             keep track of max value ??

    ;// make sure the points are built

        .IF [esi].dwUser & IIR_BUILD_POLE_CURVE
            invoke iir_build_pole_curve
        .ENDIF
        .IF [esi].dwUser & IIR_BUILD_ZERO_CURVE
            invoke iir_build_zero_curve
        .ENDIF

    ;// build the curve and track the largest value

        fldz    ;// gain
        xor ecx, ecx

        .REPEAT

            fld [esi+ecx*4].iir.pole_curve
            fmul [esi+ecx*4].iir.zero_curve
            fabs
            fsqrt

            fucom
            fnstsw ax
            sahf
            jbe @F
                ;// new max
                fxch
                fstp st
                fld st
            @@:
            fstp [esi+ecx*4].iir.gain_curve

            inc ecx

        .UNTIL ecx >= NUM_IIR_POINTS

    ;// build the gain string

        fld st  ;// copy the gain value
        invoke unit_BuildString, ADDR [esi].iir.gain_string, UNIT_DB, 0

    ;// build the scalar

    ;// gain * scale = iir_max_radius
    ;// scale = iir_max_radius / gain

        fld math_Millionth
        fld st(1)
        fabs
        fucompp
        fnstsw ax
        sahf
        ja G0

        ftst
        fstp st
        fnstsw ax
        fld math_Million
        sahf
        jnc G0
        fchs

    G0: fdivr iir_max_radius

    ;// do the loop

        lea ebx, iir_display_table
        ASSUME ebx:PTR DWORD
        xor ecx, ecx

        fld iir_radius

        .REPEAT

            fld [esi+ecx*4].iir.gain_curve
            fmul st, st(2)  ;// R   rad gain

            fld [ebx]       ;// cx  R   rad gain
            fld [ebx+4]     ;// cy  cx  R   rad gain

            fxch st(2)      ;// R   cx  cy  rad gain
            fmul st(2), st  ;// R   cx  Y   rad gain
            fmul            ;// X   Y   rad gain

            fxch            ;// Y   X   rad gain
            fadd st, st(2)  ;// YY  X   rad gain
            fxch            ;// X   YY  rad gain
            fadd st, st(2)  ;// XX  YY  rad gain

            fistp [esi+ecx*8].iir.gain_points.x
            fistp [esi+ecx*8].iir.gain_points.y

            ;// check the ranges
            point_Get [esi+ecx*8].iir.gain_points
            .IF eax >= IIR_WIDTH
                mov eax, IIR_WIDTH/2
                mov [esi+ecx*8].iir.gain_points.x, eax
            .ENDIF
            .IF edx >= IIR_HEIGHT
                mov edx, IIR_HEIGHT/2
                mov [esi+ecx*8].iir.gain_points.y, edx
            .ENDIF
            inc ecx
            add ebx, SIZEOF IIR_DISPLAY

        .UNTIL ecx >= NUM_IIR_POINTS

        fstp st
        fstp st

    ;// shut the flag off

        and [esi].dwUser, NOT IIR_BUILD_GAIN_CURVE

        ret

iir_build_gain_curve    ENDP




;//////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////



comment ~ /*

    the calc function


    states

    nX  nA  sP  sZ  ;// 36 states
    sX  sA  dP  dZ
    dX  dA          treat nX as sX

    -------------------------------

        nA  sP  sZ  ;// 24 states
    sX  sA  dP  dZ
    dX  dA

    -------------------------------

    break into                  and

    GROUP 1                     GROUP 2

        nA  sPsZ                    nA  dPdZ
    sX  sA                      sX  sA
    dX  dA  6 states            dX  dA  6 states

    --------------------------------------------

    for now, ignore sX


*/ comment ~




;///////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////
;//
;// IIR MACRO's     iir_filter                  top level macro
;//                     iir_filter_loop         does appropriate loop for filter type
;//                         iir_XX_loader       loader for filter and mode
;//                         iir_XX              doeas the calculation loop
;//                         iir_XX_unloader     unloads the fpu


;//// LOW PASS ////////////////////////////////////
;//// LOW PASS ////////////////////////////////////
;//// LOW PASS ////////////////////////////////////

iir_lp_loader MACRO update:req

    ;// ebx points at OSC_IIR

    IFIDN <update>,<UPDATE>
        fld [ebx].db12.y
        fld [ebx].db12.x
        fld [ebx].b12_prev.y;// b2      db1     db2     A
        fld [ebx].b12_prev.x;// b1      b2      db1     db2     A
    ELSE
        fld [ebx].b12.y     ;// b2      db1     db2     A
        fld [ebx].b12.x     ;// b1      b2      db1     db2     A
    ENDIF

    fld [ebx].y1            ;// y1      b1      b2      db1     db2     A
    fld [ebx].y2            ;// y2      y1      b2      b1      db1     db2     A

    ENDM


iir_lp  MACRO update:req, gain:req

    LOCAL J01, J02

    ;// ignore a1 and a2

    ;// FORMULA:    y0 = A*x0 + b1*y1 + b2*y2
    ;// INPUT:      y2      y1
    ;// OUTPUT:     y1      y0

    ;// esi must point at input
    ;// ebx must point at OSC_IIR
    ;// edi must point at output
    ;// edx must point at gain

    ;// check the update parameter
    IFDIF <update>,<UPDATE>
    IFDIF <update>,<NOUPDATE>
        .ERR <Update not specified correctly>
    ENDIF
    ENDIF

    ;// get to work
    .REPEAT

    IFIDN <update>,<UPDATE> ;// y2      y1      b1      b2      db1     db2     A
        fld st(5)           ;// db2     y2      y1      b1      b2      db1     db2     A
        faddp st(4), st     ;// y2      y1      b1      b2      db1     db2     A
        fld st(4)           ;// db1     y2      y1      b1      b2      db1     db2     A
        faddp st(3), st     ;// y2      y1      b1      b2      db1     db2     A
    ENDIF

    fmul st, st(3)          ;// y2b2    y1      b1      b2      db1     db2     A
    fld st(1)               ;// y1      y2b2    y1      b1      b2      db1     db2     A

    fmul st, st(3)          ;// y1b1    y2b1    y1      b1      b2      db1     db2     A
    fadd                    ;// BY      y1      b1      b2      db1     db2     A
    fld DWORD PTR [esi+ecx*4];  X       BY      y1      b1      b2      db1     db2     A

    ;// account for gain
    IFIDN <gain>,<NOGAIN>
    ELSEIFIDN <gain>,<INTGAIN>
        IFIDN <update>,<UPDATE>
            fmul st, st(7)  ;  A*X      BY      y1      b1      b2      db1     db2     A
        ELSE
            fmul st, st(5)  ;  A*X      BY      y1      b1      b2      A
        ENDIF
    ELSEIFIDN <gain>,<EXTGAIN>
        fmul DWORD PTR [edx+ecx*4]
    ELSE
        .ERR < Gain no specified correctly >
    ENDIF

    fadd                    ;// Y0      y1      b1      b2      db1     db2     A

    IFIDN <update>,<UPDATE>
    IFIDN <gain>,<INTGAIN>

        ;// CLIPTEST needs two registers, we only have one

        ;// check pos side

        fld1        ;// load the test value
        fucom       ;// cmpare
        fnstsw ax
        sahf
        jb J01      ;// jmp if 1 < st(1)

        ;// check neg side

        fchs
        fucom
        fnstsw ax
        sahf
        jb J02

        ;// we clipped

    J01:fxch
        inc iir_clipping    ;// set our private flag

    J02:fstp st     ;// dump the value we don't want

    ELSE
        CLIPTEST_ONE iir_clipping
    ENDIF
    ELSE
        CLIPTEST_ONE iir_clipping
    ENDIF

    fst DWORD PTR [edi+ecx*4]
    inc ecx
    fxch                ;// y1      y0      b1      b2      db1     db2     A

    .UNTIL ecx >= SAMARY_LENGTH


    ENDM

iir_lp_unloader MACRO update:REQ

    fstp [ebx].y2
    fstp [ebx].y1
    fstp st
    fstp st
    IFIDN <update>,<UPDATE>
        fstp st
        fstp st
    ENDIF

    ENDM



;//// BAND PASS ////////////////////////////////////
;//// BAND PASS ////////////////////////////////////
;//// BAND PASS ////////////////////////////////////


iir_bp_loader MACRO update:REQ

                    ;// y2      y1      x1      A
    fld [ebx].x1
    fld [ebx].y1
    fld [ebx].y2

    ENDM


iir_bp  MACRO update:req, gain:req

    ;// ignore a2

    ;// y0 = x0 + a1*x1 + b1*y1 + b2*y2

    ;// FORMULA:    y0 = A*(x0 + a1*x1) + b1*y1 + b2*y2
    ;// INPUT:      y2      y1      x1
    ;// OUTPUT:     y0      y1      x0

    ;// esi must point at input
    ;// ebx must point at parameters
    ;// edi must point at output
    ;// edx must point at gain

    ;// check the update parameter
    IFDIF <update>,<UPDATE>
    IFDIF <update>,<NOUPDATE>
        .ERR <Update not specified correctly>
    ENDIF
    ENDIF

    ;// get to work
    .REPEAT
                            ;// y2      y1      x1      A
    IFIDN <update>,<UPDATE>
        fld [ebx].b12_prev.y;// b2      y2      y1      x1      A
        fadd [ebx].db12.y
        fst [ebx].b12_prev.y
    ELSE
        fld [ebx].b12.y     ;// b2      y2      y1      x1      A
    ENDIF
    fmul                    ;// b2y2    y1      x1      A

    IFIDN <update>,<UPDATE>
        fld  [ebx].b12_prev.x;// b1     b2y2    y1      x1      A
        fadd [ebx].db12.x
        fst [ebx].b12_prev.x
    ELSE
        fld  [ebx].b12.x;// b1      b2y2    y1      x1      A
    ENDIF
    fmul st, st(2)      ;// b1y1    b2y2    y1      x1      A

    IFIDN <update>,<UPDATE>
        fld  [ebx].a12_prev.x;// a1 b1y1    b2y2    y1      x1      A
        fadd [ebx].da12.x
        fst [ebx].a12_prev.x
    ELSE
        fld  [ebx].a12.x;// a1      b1y1    b2y2    y1      x1      A
    ENDIF
    fmulp st(4), st     ;// b1y1    b2y2    y1      a1x1    A

    fadd                ;// b12y12  y1      a1x1    A

    fld DWORD PTR [esi+ecx*4];// x0 b12y12  y1      a1x1    A

    fxch st(3)          ;// a1x1    b12y12  y1      x0      A
    fadd st, st(3)      ;// xa1x1   b12y12  y1      x0      A

    ;// account for gain
    IFIDN <gain>,<NOGAIN>
    ELSEIFIDN <gain>,<INTGAIN>
        fmul st, st(4)
    ELSEIFIDN <gain>,<EXTGAIN>
        fld DWORD PTR [edx+ecx*4]
        fmul
    ELSE
        .ERR < Gain not specified correctly >
    ENDIF

    fadd                ;// y0      y1      x0      A

    CLIPTEST_ONE iir_clipping
    fst DWORD PTR [edi+ecx*4]
    inc ecx
    fxch                ;// y1      y0      x0      A

    .UNTIL ecx >= SAMARY_LENGTH

    ENDM

iir_bp_unloader MACRO update:REQ

                    ;// y2      y1      x1      A
    fstp [ebx].y2
    fstp [ebx].y1
    fstp [ebx].x1

    ENDM


;//// HIGH PASS ////////////////////////////////////
;//// HIGH PASS ////////////////////////////////////
;//// HIGH PASS ////////////////////////////////////

iir_hp_loader MACRO update:REQ


    ;// y2      y1      x2      x1

    fld [ebx].x1
    fld [ebx].x2
    fld [ebx].y1
    fld [ebx].y2

    ENDM

iir_hp  MACRO update:req, gain:req

    ;// FORMULA:    y0 = A*(x0 + a1*x1 + a2*x2) + b1*y1 + b2*y2
    ;// INPUT:      y2      y1      x2      x1
    ;// OUTPUT:     y0      y1      x1      x0

    ;// esi must point at input
    ;// ebx must point at parameters
    ;// edi must point at output
    ;// edx must point at gain

    ;// check the update parameter
    IFDIF <update>,<UPDATE>
    IFDIF <update>,<NOUPDATE>
        .ERR <Update not specified correctly>
    ENDIF
    ENDIF

    ;// get to work
    .REPEAT
                        ;// y2      y1      x2      x1      A
    IFIDN <update>,<UPDATE>
        fld [ebx].b12_prev.y;// b2  y2      y1      x2      x1      A
        fadd [ebx].db12.y
        fst [ebx].b12_prev.y
    ELSE
        fld [ebx].b12.y ;// b2      y2      y1      x2      x1      A
    ENDIF
    fmul                ;// b2y2    y1      x2      x1      A

    IFIDN <update>,<UPDATE>
        fld  [ebx].b12_prev.x;// b1 b2y2    y1      x2      x1      A
        fadd [ebx].db12.x
        fst [ebx].b12_prev.x
    ELSE
        fld  [ebx].b12.x;// b1      b2y2    y1      x2      x1      A
    ENDIF
    fmul st, st(2)      ;// b1y1    b2y2    y1      x2      x1      A

    IFIDN <update>,<UPDATE>
        fld  [ebx].a12_prev.y;// a2 b1y1    b2y2    y1      x2      x1      A
        fadd [ebx].da12.y
        fst [ebx].a12_prev.y
    ELSE
        fld  [ebx].a12.y;// a2      b1y1    b2y2    y1      x2      x1      A
    ENDIF
    fmulp st(4), st     ;// b1y1    b2y2    y1      a2x2    x1      A

    IFIDN <update>,<UPDATE>
        fld  [ebx].a12_prev.x;// a1 b1y1    b2y2    y1      a2x2    x1      A
        fadd [ebx].da12.x
        fst [ebx].a12_prev.x
    ELSE
        fld  [ebx].a12.x;// a1      b1y1    b2y2    y1      a2x2    x1      A
    ENDIF
    fmul st, st(5)      ;// a1x1    b1y1    b2y2    y1      a2x2    x1      A

    fld  DWORD PTR [esi+ecx*4];// x0 a1x1   b1y1    b2y2    y1      a2x2    x1      A
    fxch st(6)          ;// x1      a1x1    b1y1    b2y2    y1      a2x2    x0      A
    fxch st(5)          ;// a2x2    a1x1    b1y1    b2y2    y1      x1      x0      A

    fadd                ;// a2x2+a1x1 b1y1  b2y2    y1      x1      x0      A
    fxch                ;// b1y1    a2x2+a1x1 b2y2  y1      x1      x0      A
    faddp st(2), st     ;// a2x2+a1x1 b2y2+b1y1 y1  x1      x0      A
    fadd st, st(4)      ;// AX      b2y2+b1y1 y1    x1      x0      A

    ;// account for gain
    IFIDN <gain>,<NOGAIN>
    ELSEIFIDN <gain>,<INTGAIN>
        fmul st, st(5)
    ELSEIFIDN <gain>,<EXTGAIN>
        fld DWORD PTR [edx+ecx*4]
        fmul
    ELSE
        .ERR < Gain no specified correctly >
    ENDIF

    fadd                ;// y0      y1      x1      x0      A

    CLIPTEST_ONE iir_clipping
    fst DWORD PTR [edi+ecx*4]
    inc ecx
    fxch                ;// y1      y0      x1      x0      A

    .UNTIL ecx >= SAMARY_LENGTH


    ENDM


iir_hp_unloader MACRO update:REQ

    fstp [ebx].y2
    fstp [ebx].y1
    fstp [ebx].x2
    fstp [ebx].x1

    ENDM




;//// FILTER LOOP //////////////////////////////////////////////////


iir_filter_loop MACRO type:req, update:req, gain:req

    ;// at this point,
    ;// edi is the output pin
    ;// esi is the input source pin
    ;// edx is the gain source pin

    IFIDN <gain>,<INTGAIN>
        mov edx, [edx].pData
        fld DWORD PTR [edx]
    ELSEIFIDN <gain>,<EXTGAIN>
        mov edx, [edx].pData
    ENDIF

    xor ecx, ecx
    mov esi, [esi].pData
    mov edi, [edi].pData

    iir_&type&_loader update

    iir_&type update, gain

    iir_&type&_unloader update

    IFIDN <gain>,<INTGAIN>
        fstp st
    ENDIF

    ENDM


;//// FILTER //////////////////////////////////////////////////

iir_filter MACRO update:req, gain:req, exit:req

    LOCAL lowpass, bandpass, highpass

    ;// at this point,
    ;// edi is the output pin
    ;// esi is the input source pin
    ;// edx is the gain source pin
    ;// ecx is stil dwUser

    bt ecx, LOG2( IIR_LP )
    jc lowpass
    bt ecx, LOG2( IIR_BP )
    jc bandpass

highpass:   iir_filter_loop hp, update, gain
            jmp exit
ALIGN 16
bandpass:   iir_filter_loop bp, update, gain
            jmp exit
ALIGN 16
lowpass:    iir_filter_loop lp, update, gain
            jmp exit

    ENDM






;////////////////////////////////////////////////////////////////////
;//
;//
;//     CALC
;//


ASSUME_AND_ALIGN
iir_Calc PROC

    ASSUME esi:PTR OSC_OBJECT

    OSC_TO_DATA esi, ebx, OSC_IIR   ;// get our data pointer
    OSC_TO_PIN_INDEX esi, edi, 2    ;// get the ouput pin
    DEBUG_IF <!![edi].pPin>         ;// not supposed to be calced if not connected

    push esi                        ;// always store
    mov ecx, [esi].dwUser           ;// get dwUser

    or [edi].dwStatus, PIN_CHANGING

    mov iir_clipping, 0

    test ecx, IIR_CHANGED_TEST
    jz GROUP_1

    ;// GROUP 2
    GROUP_2:

        invoke iir_CalcCoeff        ;// caclulate the changes

        OSC_TO_PIN_INDEX esi, edx, 1    ;// get the amplitude pin
        OSC_TO_PIN_INDEX esi, esi, 0    ;// esi is input data

        mov edx, [edx].pPin
        mov esi, [esi].pPin

        or esi, esi
        .IF ZERO?
            mov esi, math_pNullPin
        .ENDIF

        or edx, edx
        jz group_2_dX_nA
        test [edx].dwStatus, PIN_CHANGING
        jz group_2_dX_sA

        group_2_dX_dA:  iir_filter UPDATE, EXTGAIN, all_done
        ALIGN 16
        group_2_dX_sA:  iir_filter UPDATE, INTGAIN, all_done
        ALIGN 16
        group_2_dX_nA:  iir_filter UPDATE, NOGAIN, all_done


    ;// GROUP 1
    ALIGN 16
    GROUP_1:

        OSC_TO_PIN_INDEX esi, edx, 1    ;// get the amplitude pin
        OSC_TO_PIN_INDEX esi, esi, 0    ;// esi is input data
        mov edx, [edx].pPin
        mov esi, [esi].pPin

        or esi, esi
        .IF ZERO?
            mov esi, math_pNullPin
        .ENDIF

        or edx, edx
        jz group_1_dX_nA
        test [edx].dwStatus, PIN_CHANGING
        jz group_1_dX_sA

        group_1_dX_dA:  iir_filter NOUPDATE, EXTGAIN, all_done
        ALIGN 16
        group_1_dX_sA:  iir_filter NOUPDATE, INTGAIN, all_done
        ALIGN 16
        group_1_dX_nA:  iir_filter NOUPDATE, NOGAIN, all_done


    ALIGN 16
    all_done:

        pop esi
        ASSUME esi:PTR OSC_OBJECT

        ;// check the clipping

        mov ecx, [esi].dwUser

        .IF iir_clipping    ;// we are clipping now

            bts ecx, LOG2(IIR_IS_CLIPPING)
            jc clipping_done

            mov eax, HINTI_OSC_GOT_BAD

        .ELSE               ;// we are not clipping

            btr ecx, LOG2(IIR_IS_CLIPPING)
            jnc clipping_done

            mov eax, HINTI_OSC_LOST_BAD

        .ENDIF

        mov [esi].dwUser, ecx       ;// stor the new state
        or [esi].dwHintI, eax   ;// set appropriate gdi commands
        .IF [esi].dwHintOsc & HINTOSC_STATE_ONSCREEN

            invoke play_Invalidate_osc  ;// send to IC list

        .ENDIF


    clipping_done:

        ret


iir_Calc ENDP




ASSUME_AND_ALIGN
iir_PrePlay PROC

    ;// zero the previous values

    ASSUME esi:PTR OSC_OBJECT

    OSC_TO_DATA esi, ecx, OSC_IIR
    xor eax, eax

    mov  [ecx].x1, eax
    mov  [ecx].x2, eax
    mov  [ecx].y1, eax
    mov  [ecx].y2, eax

    ;// eax is zero, so play_start will erase the rest of the data

    ret

iir_PrePlay ENDP


ASSUME_AND_ALIGN
iir_CalcDests PROC

    ASSUME esi:PTR OSC_OBJECT
    ASSUME ebx:PTR OSC_IIR

    DEBUG_IF < ebx !!= [esi].pData >

    ;// make sure we have shapes
    .IF !iir_pole_mask

        push ebx
        push edi
        push esi

        mov eax, 'x'
        lea edi, font_bus_slist_head
        invoke font_Locate
        mov eax, (GDI_SHAPE PTR [edi]).pMask
        mov iir_pole_mask, eax

        mov eax, 'o'
        lea edi, font_bus_slist_head
        invoke font_Locate
        mov eax, (GDI_SHAPE PTR [edi]).pMask
        mov iir_zero_mask, eax

        mov eax, 'PH'
        lea edi, font_bus_slist_head
        invoke font_Locate
        mov eax, (GDI_SHAPE PTR [edi]).pMask
        mov iir_hp_mask, eax

        mov eax, 'PB'
        lea edi, font_bus_slist_head
        invoke font_Locate
        mov eax, (GDI_SHAPE PTR [edi]).pMask
        mov iir_bp_mask, eax

        mov eax, 'PL'
        lea edi, font_bus_slist_head
        invoke font_Locate
        mov eax, (GDI_SHAPE PTR [edi]).pMask
        mov iir_lp_mask, eax

        pop esi
        pop edi
        pop ebx

    .ENDIF

    ;// then set the pdests for the pole and zero

        mov eax, [ebx].PXY.y    ;// load Y
        add eax, IIR_HEIGHT / 2 ;// offset to center Y
        imul gdi_bitmap_size.x  ;// multiply to get lines
        mov ecx, [esi].pDest    ;// load osc dest
        add ecx, IIR_WIDTH/2    ;// offset to center X
        add ecx, [ebx].PXY.x    ;// add current location
        add ecx, eax            ;// add offset into gdi surface
        mov [ebx].pDest_pole, ecx   ;// store in iir data

        mov eax, [ebx].ZXY.y    ;// load Y
        add eax, IIR_HEIGHT / 2 ;// offset to center Y
        imul gdi_bitmap_size.x  ;// multiply to get lines
        mov ecx, [esi].pDest    ;// load osc dest
        add ecx, IIR_WIDTH/2    ;// offset to center X
        add ecx, [ebx].ZXY.x    ;// add current location
        add ecx, eax            ;// add offset into gdi surface
        mov [ebx].pDest_zero, ecx   ;// store in iir data

    ;// and turn the flags off

        and [esi].dwUser, NOT IIR_OSC_MOVED

    ;// that should do it

        ret

iir_CalcDests ENDP




ASSUME_AND_ALIGN
iir_Ctor PROC

        ;// register call
        ASSUME ebp:PTR LIST_CONTEXT ;// preserve
        ASSUME esi:PTR OSC_OBJECT   ;// preserve
        ASSUME edi:PTR OSC_BASE     ;// may destroy
        ASSUME ebx:PTR FILE_OSC     ;// may destroy
        ASSUME edx:PTR FILE_HEADER  ;// may destroy

    OSC_TO_DATA esi, ebx, OSC_IIR

    ;// make sure the coefficients and curves get built
    or [esi].dwUser, IIR_OSC_MOVED + IIR_CHANGED_TEST + IIR_BUILD_GAIN_CURVE + IIR_BUILD_POLE_CURVE + IIR_BUILD_ZERO_CURVE

    ;// make sure the user bits are in a valid state
    and [esi].dwUser, IIR_HOVER_MASK

    ;// if we're not loading from a file
    ;// initialize the iir data with default

    .IF !edx    ;// not loading from file

        point_Set [ebx].PXY, 16,16
        point_Set [ebx].ZXY, 0,0

    ;// or [esi].dwUser, IIR_SHOW_CLIPPING

    .ELSE

        ;// make sure the filter coefficients get set up

        point_Set [ebx].a12, 0, 0
        point_Set [ebx].b12, 0, 0

        ;// make sure the points are inside the allowed range

        mov eax, [ebx].PXY.x
        imul eax
        mov ecx, eax
        mov eax, [ebx].PXY.y
        imul eax
        add eax, ecx
        .IF eax > IIR_MAX_RADIUS_SQUARED

        ;// DEBUG_IF <1>    ;// not tested

            ;// adjust
            push eax
            fild DWORD PTR [esp]
            fabs
            fsqrt                   ;// r
            pop eax
            fdivr iir_max_radius    ;// rs
            fild [ebx].PXY.x        ;// x   rs
            fmul st, st(1)          ;// X   rs
            fild [ebx].PXY.y        ;// y   X   rs
            fmulp st(2), st         ;// X   Y

            fistp [ebx].PXY.x
            fistp [ebx].PXY.y

        .ENDIF

        mov eax, [ebx].ZXY.x
        imul eax
        mov ecx, eax
        mov eax, [ebx].ZXY.y
        imul eax
        add eax, ecx
        .IF eax > IIR_MAX_RADIUS_SQUARED

        ;// DEBUG_IF <1>    ;// not tested

            ;// adjust
            push eax
            fild DWORD PTR [esp]
            fabs
            fsqrt                   ;// r
            pop eax
            fdivr iir_max_radius    ;// rs
            fild [ebx].ZXY.x        ;// x   rs
            fmul st, st(1)          ;// X   rs
            fild [ebx].ZXY.y        ;// y   X   rs
            fmulp st(2), st         ;// X   Y

            fistp [ebx].ZXY.x
            fistp [ebx].ZXY.y

        .ENDIF

    .ENDIF

    ;// force an update of the coefficients

    ;// invoke iir_CalcCoeff

    ;// that should do it

        ret

iir_Ctor ENDP




ASSUME_AND_ALIGN
iir_Render PROC uses esi

    ASSUME esi:PTR OSC_MAP

    ;// call base class first

        invoke gdi_render_osc

    ;// make sure we have proper pDests

        OSC_TO_DATA esi, ebx, OSC_IIR
        .IF [esi].dwUser & ( IIR_OSC_MOVED )
            invoke iir_CalcDests
        .ENDIF

    ;// draw correctly for big and small

    .IF !([esi].dwUser & IIR_SMALL)

    ;// double check that we have control hover

        .IF !(app_bFlags & APP_MODE_CONTROLLING_OSC OR APP_MODE_CON_HOVER)

            and [esi].dwUser, IIR_HOVER_MASK

        .ENDIF

    ;// draw the pole and zero shape

        ;// pole
        mov eax, F_COLOR_OSC_TEXT   ;// F_COLOR_GROUP_PROCESSORS    ;// + 1F1F1F1Fh
        .IF [esi].dwUser & IIR_HOVER_POLE
            mov eax, F_COLOR_OSC_HOVER
        .ENDIF
        OSC_TO_DATA esi, ebx, OSC_IIR
        mov edi, [ebx].pDest_pole
        mov ebx, iir_pole_mask
        invoke shape_Fill
        mov esi, [esp]

        .IF eax == F_COLOR_OSC_HOVER    ;// hover ?

            OSC_TO_DATA esi, ebx, OSC_IIR
            mov edi, [ebx].pDest_pole
            mov ebx, shape_pin_font.pOut1
            invoke shape_Fill
            mov esi, [esp]

        .ENDIF


        ;// zero
        .IF !([esi].dwUser & IIR_LP)    ;// don't draw zero for lowpass

            OSC_TO_DATA esi, ebx, OSC_IIR
            mov edi, [ebx].pDest_zero

            mov eax, F_COLOR_OSC_TEXT ;// F_COLOR_GROUP_PROCESSORS  ;// + 1F1F1F1Fh
            .IF [esi].dwUser & IIR_HOVER_ZERO
                mov eax, F_COLOR_OSC_HOVER
            .ENDIF

            mov ebx, iir_zero_mask
            invoke shape_Fill
            mov esi, [esp]

            .IF eax == F_COLOR_OSC_HOVER    ;// hover ?

                OSC_TO_DATA esi, ebx, OSC_IIR
                mov edi, [ebx].pDest_zero
                mov ebx, shape_pin_font.pOut1
                invoke shape_Fill
                mov esi, [esp]

            .ENDIF

        .ENDIF

    ;// see if we show the detailed veiw

        .IF [esi].dwUser & IIR_DETAILED

            ;// make sure the values are current

            .IF [esi].dwUser & IIR_BUILD_CURVE_TEST

                invoke iir_build_gain_curve

            .ENDIF


            ;// draw the gain curve

            sub esp, 16
            st_1 TEXTEQU <(POINT PTR [esp])>
            st_2 TEXTEQU <(POINT PTR [esp+8])>

                mov eax, F_COLOR_OSC_TEXT ;// F_COLOR_GROUP_PROCESSORS  ;// + 1F1F1F1Fh

                xor edi, edi    ;// edi counts points

                point_GetTL [esi].rect, edx, ecx
                add edx, [esi+edi*8].iir.gain_points.x
                add ecx, [esi+edi*8].iir.gain_points.y
                point_Set st_2, edx, ecx

                mov ebx, gdi_pDib   ;// points at the display container

                .REPEAT

                    inc edi
                    point_GetTL [esi].rect, edx, ecx
                    add edx, [esi+edi*8].iir.gain_points.x
                    add ecx, [esi+edi*8].iir.gain_points.y
                    point_Set st_1, edx, ecx

                    invoke dib_DrawLine

                    inc edi
                    point_GetTL [esi].rect, edx, ecx
                    add edx, [esi+edi*8].iir.gain_points.x
                    add ecx, [esi+edi*8].iir.gain_points.y
                    point_Set st_2, edx, ecx

                    invoke dib_DrawLine

                .UNTIL edi == NUM_IIR_POINTS - 1

            ;// print the texts

                point_GetTL [esi].rect
                point_Add IIR_DETAIL_TEXT
                point_Set st_1
                point_Set st_2

                GDI_DC_SET_COLOR COLOR_OSC_TEXT ;// COLOR_GROUP_PROCESSORS + 10h
                GDI_DC_SELECT_FONT hFont_pin

                ;// pole frequency

                mov edx, esp
                invoke DrawTextA, gdi_hDC, ADDR [esi].iir.pole_string, -1, edx, DT_NOCLIP
                sub eax, IIR_DETAIL_SPACE
                add st_1.y, eax
                add st_2.y, eax
                mov edx, esp

                ;// zero frequency

                .IF !([esi].dwUser & IIR_LP)    ;// don't show zero for LP
                    invoke DrawTextA, gdi_hDC, ADDR [esi].iir.zero_string, -1, edx, DT_NOCLIP
                    sub eax, IIR_DETAIL_SPACE
                    add st_1.y, eax
                    add st_2.y, eax
                    mov edx, esp
                .ENDIF

                ;// approx gain

                invoke DrawTextA, gdi_hDC, ADDR [esi].iir.gain_string, -1, edx, DT_NOCLIP

            ;// clean up, we're done

            add esp, 16
            st_1 TEXTEQU <>
            st_2 TEXTEQU <>

        .ENDIF

        ;// then define the line count for the label display

        mov edx, gdi_bitmap_size.x
        shl edx, 4  ;// 16 lines

    .ELSE   ;// no controls

        mov edx, gdi_bitmap_size.x
        lea edx, [edx+edx*2]    ;// *3
        shl edx, 2              ;// *4 = 12 lines

    .ENDIF  ;// IIR_SMALL

    ;// draw our label

        mov eax, F_COLOR_OSC_TEXT ;// F_COLOR_GROUP_PROCESSORS  ;// + 1E1E1E1Eh
        mov edi, [esi].pDest

        .IF [esi].dwUser & IIR_LP
            mov ebx, iir_lp_mask
        .ELSEIF [esi].dwUser & IIR_BP
            mov ebx, iir_bp_mask
        .ELSE
            mov ebx, iir_hp_mask
        .ENDIF

        lea edi, [edi+edx+IIR_WIDTH/4]

        invoke shape_Fill

    ;// that't it
    all_done:

        ret

iir_Render ENDP


ASSUME_AND_ALIGN
iir_SetShape PROC

    ASSUME esi:PTR OSC_OBJECT

    ;// make sure the correct pSource is set

    .IF [esi].dwUser & IIR_SMALL
        mov edx, IIR_SM_PSOURCE
        lea eax, filter_container
    .ELSEIF [esi].dwUser & IIR_LOG
        mov edx, IIR_LOG_PSOURCE
        lea eax, iir_container
    .ELSE
        mov edx, IIR_LIN_PSOURCE
        lea eax, iir_container
    .ENDIF
    mov [esi].pSource, edx
    mov [esi].pContainer, eax

    ;// exit to osc_SetShape

    jmp osc_SetShape


iir_SetShape ENDP





ASSUME_AND_ALIGN
iir_HitTest PROC uses esi

    ;// return carry flag if one of the controls is hit
    ;// otherwise return no flags (szc)

    ASSUME esi:PTR OSC_OBJECT
    ASSUME ebp:PTR LIST_CONTEXT


    test [esi].dwUser, IIR_SMALL
    jnz exit_no_hit

;// and [esi].dwUser, IIR_HOVER_MASK    ;// turn off the hovers

    OSC_TO_DATA esi, ebx, OSC_IIR
    mov esi, [ebx].pDest_pole
    mov ebx, shape_pin_font.pMask
    mov edi, mouse_pDest

    invoke shape_Test
    mov esi, [esp]

    jnc @F

        btr [esi].dwUser, LOG2(IIR_HOVER_ZERO)  ;// reset the previous hover
        .IF CARRY?                              ;// was it on ?
            GDI_INVALIDATE_OSC HINTI_OSC_UPDATE ;// force a redraw
        .ENDIF
        or [esi].dwUser, IIR_HOVER_POLE

    exit_hit:

        xor eax, eax
        inc eax
        stc
        ret
@@:
    .IF !([esi].dwUser & IIR_LP)

        OSC_TO_DATA esi, ebx, OSC_IIR
        mov esi, [ebx].pDest_zero
        mov ebx, shape_pin_font.pMask
        mov edi, mouse_pDest

        invoke shape_Test
        mov esi, [esp]

        jnc @F

            btr [esi].dwUser, LOG2(IIR_HOVER_POLE)  ;// reset the previous hover
            .IF CARRY?                              ;// was it on ?
                GDI_INVALIDATE_OSC HINTI_OSC_UPDATE ;// force a redraw
            .ENDIF
            or [esi].dwUser, IIR_HOVER_ZERO

            jmp exit_hit
    .ENDIF

exit_no_hit:
@@:
    and [esi].dwUser, IIR_HOVER_MASK
    xor eax, eax
    inc eax
    ret

iir_HitTest ENDP


ASSUME_AND_ALIGN
iir_Control PROC

    ;// should only be called if we're moving a control
    ;// do appropriate move

    ASSUME esi:PTR OSC_OBJECT
    ASSUME ebp:PTR LIST_CONTEXT

    ;// eax has the mouse message indicating why this is being called

    cmp eax, WM_MOUSEMOVE
    mov eax, 0
    jnz all_done

    ;// determine which control we're working with
    ;// get a pointer to the pair of points (ecx)
    ;// and set the correct hover bit       (edx)

        OSC_TO_DATA esi, ebx, OSC_IIR

        .IF [esi].dwUser & IIR_HOVER_POLE
            lea ecx, [ebx].PXY
            mov edx, IIR_POLE_CHANGED + IIR_OSC_MOVED + IIR_BUILD_POLE_CURVE + IIR_BUILD_GAIN_CURVE
        .ELSE
            DEBUG_IF <!!([esi].dwUser & IIR_HOVER_ZERO ) >
            lea ecx, [ebx].ZXY
            mov edx, IIR_ZERO_CHANGED + IIR_OSC_MOVED + IIR_BUILD_ZERO_CURVE + IIR_BUILD_GAIN_CURVE
        .ENDIF
        ASSUME ecx:PTR POINT    ;// ecx is the point to set
        or [esi].dwUser, edx    ;// set the bits

    ;// xfer mouse coord to new

        point_Get mouse_now
        point_SubTL [esi].rect
        sub eax, IIR_WIDTH / 2
        sub edx, IIR_HEIGHT / 2
        point_Set [ecx]

    ;// make sure we remain inside the circle

        mov ebx, edx
        imul eax
        xchg ebx, eax
        imul eax

        add eax, ebx
        .IF eax >= IIR_MAX_RADIUS_SQUARED

            ;// need to clip this
            ;// formula: x = max_rad*x/sqrt(rad2)   we already know rad 2 (in eax)
            ;//          y = max_rad*y/sqrt(rad2)

            push eax    ;// make some room
            fild [ecx].x    ;// x
            fild [ecx].y    ;// y   x
            fild DWORD PTR [esp]    ;// rad2
            fabs
            fsqrt           ;// rad     y   x
            fld iir_max_radius
            fdivr           ;// scale   y   x
            fmul st(2), st  ;// scale   y   X
            fmul            ;// Y   X
            fxch
            fistp [ecx].x
            pop eax     ;// clean up the stack
            fistp [ecx].y

        .ENDIF

    ;// invalidate the osc

        GDI_INVALIDATE_OSC HINTI_OSC_UPDATE OR HINTI_OSC_MOVED

    ;// return that we have a new value

        mov eax, CON_HAS_MOVED

    ;// that's it

all_done: ret


iir_Control ENDP




ASSUME_AND_ALIGN
iir_Move PROC

    ;// make sure the shapes get moved

    ASSUME esi:PTR OSC_OBJECT

    or [esi].dwUser, IIR_OSC_MOVED
    jmp osc_Move

iir_Move ENDP




ASSUME_AND_ALIGN
iir_InitMenu PROC

    ASSUME esi:PTR OSC_OBJECT

    ;// press the correct buttons

    mov ecx, IDC_IIR_LIN
    .IF [esi].dwUser & IIR_LOG
        mov ecx, IDC_IIR_LOG
    .ENDIF

    invoke CheckDlgButton, popup_hWnd, ecx, BST_CHECKED

    .IF [esi].dwUser & IIR_LP
        mov ecx, IDC_IIR_LP
    .ELSEIF [esi].dwUser & IIR_BP
        mov ecx, IDC_IIR_BP
    .ELSE   ;// IF [esi].dwUser & IIR_HP
        mov ecx, IDC_IIR_HP
    .ENDIF
    invoke CheckDlgButton, popup_hWnd, ecx, BST_CHECKED

    .IF [esi].dwUser & IIR_DETAILED
        invoke CheckDlgButton, popup_hWnd, IDC_IIR_DETAILED, BST_CHECKED
    .ENDIF

    .IF [esi].dwUser & IIR_SMALL

        invoke CheckDlgButton, popup_hWnd, IDC_IIR_SMALL, BST_CHECKED

        invoke GetDlgItem, popup_hWnd, IDC_IIR_DETAILED
        invoke EnableWindow, eax, 0

    .ELSE

        invoke GetDlgItem, popup_hWnd, IDC_IIR_DETAILED
        invoke EnableWindow, eax, 1

    .ENDIF

;// .IF [esi].dwUser & IIR_SHOW_CLIPPING
;//
;//     invoke CheckDlgButton, popup_hWnd, IDC_IIR_CLIPPING, BST_CHECKED
;//
;// .ENDIF

    ;// return zero

    xor eax, eax

    ret

iir_InitMenu ENDP

ASSUME_AND_ALIGN
iir_Command PROC

    ASSUME ebp:PTR LIST_CONTEXT
    ASSUME esi:PTR OSC_OBJECT
    ;// eax has the command ID

    mov ecx, [esi].dwUser

    cmp eax, IDC_IIR_LIN
    jnz @F

        btr ecx, LOG2(IIR_LOG)
        jnc exit_ignore

    set_new_mode:

        mov [esi].dwUser, ecx
        invoke iir_mode_switch

    exit_with_shape_change:

        or [esi].dwHintI, HINTI_OSC_SHAPE_CHANGED

    exit_with_dirty:

        mov eax, POPUP_SET_DIRTY + POPUP_REDRAW_OBJECT
        ret

    exit_ignore:

        mov eax, POPUP_IGNORE
        ret

@@: cmp eax, IDC_IIR_LOG
    jnz @F

        bts ecx, LOG2(IIR_LOG)
        jc exit_ignore
        jmp set_new_mode

@@: cmp eax, IDC_IIR_HP
    jnz @F

        and [esi].dwUser, IIR_PASS_MASK
        or [esi].dwUser, IIR_BUILD_ZERO_CURVE + IIR_BUILD_GAIN_CURVE
        jmp exit_with_dirty

@@: cmp eax, IDC_IIR_BP
    jnz @F

        and [esi].dwUser, IIR_PASS_MASK
        or [esi].dwUser, IIR_BP + IIR_BUILD_ZERO_CURVE + IIR_BUILD_GAIN_CURVE
        jmp exit_with_dirty

@@: cmp eax, IDC_IIR_LP
    jnz @F

        and [esi].dwUser, IIR_PASS_MASK
        or [esi].dwUser, IIR_LP + IIR_BUILD_ZERO_CURVE + IIR_BUILD_GAIN_CURVE
        jmp exit_with_dirty

@@: cmp eax, IDC_IIR_SMALL
    jnz @F

        BITC [esi].dwUser, IIR_SMALL

        mov eax, IIR_BIG_SMALL_X
        mov edx, IIR_BIG_SMALL_Y
        .IF CARRY?      ;// we were small, so we soot left and up
            neg eax
            neg edx
        .ENDIF

        point_AddToTL [esi].rect
        or [esi].dwUser, IIR_OSC_MOVED

        jmp exit_with_shape_change

@@: cmp eax, IDC_IIR_DETAILED
    jnz osc_Command ;// @F

        xor [esi].dwUser, IIR_DETAILED
        or [esi].dwUser, IIR_BUILD_CURVE_TEST
        jmp exit_with_dirty


iir_Command ENDP

;////////////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
iir_SaveUndo    PROC

        ASSUME esi:PTR OSC_MAP

        ;// edx enters as either UNREDO_CONTROL_OSC or UNREDO_COMMAND
        ;// edi enters as where to store
        ;//
        ;// task:   1) save nessary data
        ;//         2) iterate edi
        ;//
        ;// may use all registers except ebp

        .IF edx == UNREDO_CONTROL_OSC

            ;// save the control points

            lea esi, [esi].iir.b12
            mov ecx, ( SIZEOF POINT * 4 ) / 4
            rep movsd

        .ELSE

            ;// save object settings

            mov eax, [esi].dwUser
            stosd
            point_GetTL [esi].rect
            stosd
            mov eax, edx
            stosd

        .ENDIF

        ret

iir_SaveUndo ENDP



ASSUME_AND_ALIGN
iir_LoadUndo PROC

        ASSUME esi:PTR OSC_MAP      ;// preserve
        ASSUME ebp:PTR LIST_CONTEXT ;// preserve

        ;// edx enters as either UNREDO_CONTROL_OSC or UNREDO_COMMAND
        ;// edi enters as where to load
        ;//
        ;// task:   1) load nessary data
        ;//         2) do what it takes to initialize it
        ;//
        ;// may use all registers except ebp and esi
        ;// return will invalidate HINTI_OSC_UPDATE

        .IF edx == UNREDO_CONTROL_OSC

            ;// load control points

            push esi

            lea esi, [esi].iir.b12
            mov ecx, ( SIZEOF POINT * 4 ) / 4
            xchg esi, edi
            rep movsd

            pop esi

        .ELSE

            ;// load object settings

            mov eax, [edi]
            mov [esi].dwUser, eax
            add edi, 4
            ASSUME edi:PTR POINT
            point_Get [edi]
            point_SetTL [esi].rect
            or [esi].dwHintI, HINTI_OSC_SHAPE_CHANGED
            BITR [esi].dwUser, IIR_IS_CLIPPING
            .IF CARRY?
            or [esi].dwHintI, HINTI_OSC_LOST_BAD
            .ENDIF

        .ENDIF

        ;// initialize for the new data

        ;// make sure the coefficients and curves get built
        or [esi].dwUser, IIR_OSC_MOVED + IIR_CHANGED_TEST + IIR_BUILD_GAIN_CURVE + IIR_BUILD_POLE_CURVE + IIR_BUILD_ZERO_CURVE


        ret

iir_LoadUndo ENDP




;////////////////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
iir_GetUnit PROC

        ASSUME esi:PTR OSC_MAP  ;// must preserve
        ASSUME ebx:PTR APIN     ;// must preserve

        ;// must preserve edi and ebp


        lea ecx, [esi].pin_x
        ASSUME ecx:PTR APIN
        .IF ecx == ebx
            lea ecx, [esi].pin_y
        .ENDIF
        mov eax, [ecx].dwStatus
        BITT eax, UNIT_AUTOED

        ret


iir_GetUnit ENDP


;////////////////////////////////////////////////////////////////////////////////




















ASSUME_AND_ALIGN



ENDIF   ;// USE_THIS_FILE
END
