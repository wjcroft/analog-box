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
;//                  these are macros for simplifying working with POINTS
;//  Geometry.inc    RECTS, VECTORS, etc...
;//                  This file tries to allow for advances in CPU
IFNDEF _GEOMETRY_INCLUDED_
_GEOMETRY_INCLUDED_ EQU 1

;//
;//  N O T E S :
;//
;//     in general, the arguments passed to these macros be dot addressable
;//     ie passing '[esi].P0'  will expand as '[esi].P0.x'
;//

;// TOC

comment ~ /*

point_Clear MACRO p0:req, reg:=<eax>
point_Set MACRO p0:req, X:=<eax>, Y:=<edx>
fpoint_Set_int p:REQ
point_Set_X MACRO p0:req, X:=<eax>
point_Set_Y MACRO p0:req, Y:=<edx>
point_SetTL MACRO r0:req, X:=<eax>, Y:=<edx>
point_SetBR MACRO r0:req, X:=<eax>, Y:=<edx>

point_Get MACRO p0:req, X:=<eax>, Y:=<edx>
fpoint_Get MACRO p0:req
fpoint_Get_int MACRO p0:req
point_Get_X MACRO p0:req, X:=<eax>
point_Get_Y MACRO p0:req, Y:=<edx>

point_Neg MACRO X:=<eax>, Y:=<edx>

point_Swap MACRO p0:req, X:=<eax>, Y:=<edx>
point_SwapTL MACRO r0:req, X:=<eax>, Y:=<edx>
point_SwapBR MACRO r0:req, X:=<eax>, Y:=<edx>

point_Push MACRO xx
point_PushTL MACRO rr:req
point_PushBR MACRO rr:req

point_Pop MACRO xx
point_PopTL MACRO rr:req
point_PopBR MACRO rr:req

point_GetTL MACRO r0:req, X:=<eax>, Y:=<edx>
point_GetBR MACRO r0:req, X:=<eax>, Y:=<edx>

point_Add MACRO xx:req, yy
point_AddTL MACRO xx:req, yy
point_AddBR MACRO xx:req

point_Sub MACRO xx:req, yy
point_SubTL MACRO xx:req, yy
point_SubBR MACRO xx:req

point_XorTL MACRO xx:req, yy
point_XorBR MACRO xx:req

point_DecTL MACRO xx:req
point_DecBR MACRO xx:req

point_Shl MACRO val:req xx:=<eax>,yy:=<edx>
point_Shr MACRO val:req xx:=<eax>,yy:=<edx>
point_Sar MACRO val:req xx:=<eax>,yy:=<edx>
point_ShrTL MACRO xx:req, val:req
point_ShrBR MACRO xx:req, val:req
point_ShlTL MACRO xx:req, val:req
point_ShlBR MACRO xx:req, val:req


point_Min MACRO pnt:req, X:=<eax>, Y:=<edx>
point_MinTL MACRO rect:req, X:=<eax>, Y:=<edx>
point_MinBR MACRO rect:req, X:=<eax>, Y:=<edx>

point_Max MACRO pnt:req, X:=<eax>, Y:=<edx>
point_MaxTL MACRO rect:req, X:=<eax>, Y:=<edx>
point_MaxBR MACRO rect:req, X:=<eax>, Y:=<edx>

point_Clip MACRO rect:req

rect_IfNotIntersect MACRO rect1:req, rect2:req, then:req
rect_IfXYNotInside MACRO rect:req, X:=<eax>, Y:=<edx>, then:req

rect_UnionXY MACRO rect:req, X:=<eax>, Y:=<edx>
rect_UnionRect MACRO rect1:req, rect2:req, X:=<eax>, Y:=<edx>

point_CopyTo MACRO p1:req, p2:req, X:=<eax>, Y:=<edx>
spoint_Get MACRO short:req, X:=<eax>, Y:=<edx>

point_FromShort MACRO point:req, short:req, X:=<eax>, Y:=<edx>
point_ToShort MACRO point:req, short:req, reg1:=<eax>, reg2:=<edx>
point_FromPosOfs MACRO point:req, pos:req, ofs:req, tempReg1:=<eax>, tempReg2:=<edx>
point_Delta MACRO p1:req, p2:req, p3, X:=<eax>, Y:=<edx>

point_AddTo MACRO p1:req, p2, X:=<eax>, Y:=<edx>
point_SubTo MACRO p1:req, p2, X:=<eax>, Y:=<edx>
point_AddToTL MACRO p1:req, p2, X:=<eax>, Y:=<edx>
point_AddToBR MACRO p1:req, p2, X:=<eax>, Y:=<edx>
point_SubToTL MACRO p1:req, p2, X:=<eax>, Y:=<edx>
point_SubToBR MACRO p1:req, p2, X:=<eax>, Y:=<edx>

rect_Clear MACRO rect:req, reg:=<eax>
rect_CopyTo MACRO rect1:req, rect2:req, X:=<eax>, Y:=<edx>

rect_Swap MACRO r0:req, r1:req, X:=<eax>, Y:=<edx>

rect_FromCenRad MACRO rect:req, cen:req, rad:req, reg1:=<eax>, reg2:=<edx>
rect_FromCenOfsRad MACRO rect:req, cen:req, ofs:req, rad:req, reg1:=<eax>, reg2:=<edx>
rect_FromCenSizWid MACRO rect:req, cen:req, siz:req, wid:req, tempReg1:=<eax>, tempReg2:=<edx>
rect_FromOrgOfsSizWid MACRO rect:req, oorg:req, ofs:req, siz:req, wid:req, tempReg1:=<eax>, tempReg2:=<edx>
rect_FromPosSize MACRO rect:req, pos:req, siz:req, X:=<eax>, Y:=<edx>
rect_FromOrgOfsRad MACRO rect:req, oorg:req, ofs:req, rad:req, tempReg1:=<eax>, tempReg2:=<edx>
rect_FromOrgOfsSiz MACRO rect:req, oorg:req, ofs:req, siz:req, tempReg1:=<eax>, tempReg2:=<edx>
rect_FromOrgCenOfsRad MACRO rect:req, oorg:req, cen:req, ofs:req, rad:req, reg1:=<eax>, reg2:=<edx>
rect_FromPosSizOfs MACRO rect:req, pos:req, siz:req, ofs:req, X:=<eax>, Y:=<edx>
rect_FromRectOfs MACRO rect:req, r1:req, pos:req, reg1:=<eax>, reg2:=<edx>
rect_FromRectOfsExt MACRO rect:req, r1:req, pos:req, extx:req, exty:req, reg1:=<eax>, reg2:=<edx>

rect_Inflate MACRO rect:req, delta
rect_Deflate MACRO rect:req, delta
rect_Set MACRO rect:req, rl:req, rt:req, rr:req, rb:req

triangle_FromPosTableDir MACRO tri:req, point:req, table:req, dir:req, regX:=<eax>, regY:=<edx>
region_CombineRect MACRO hRgn:req, rect:req
region_CombinePolygon MACRO hRgn:req, pntList:req, numPoints:req, style:=<ALTERNATE>
opattrTest MACRO p1:req


*/ comment ~



;////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////
;//
;//
;//     D E F I N I T I O N S
;//

        POINT struct
            x  SDWORD ?
            y  SDWORD ?
        POINT endS

        sPOINT struct
            x  SWORD ?
            y  SWORD ?
        sPOINT endS

        fPOINT struct
            x  REAL4 0.0e+0
            y  REAL4 0.0e+0
        fPOINT endS

        dPOINT struct
            x  REAL8 0.0e+0
            y  REAL8 0.0e+0
        dPOINT endS

        RECT struct
            left    SDWORD  ?
            top     SDWORD  ?
            right   SDWORD  ?
            bottom  SDWORD  ?
        RECT endS

        fRECT   STRUCT
            left    REAL4   ?
            top     REAL4   ?
            right   REAL4   ?
            bottom  REAL4   ?
        fRECT   ENDS



    ;// two by two matrices

    ;//     / Aix Ajy \
    ;//     |         |
    ;//     \ Aiy Ajy /

        MAT22   STRUCT

            i   POINT   {}  ;// COLUMN 1
            j   POINT   {}  ;// COLUMN 2

        MAT22   ENDS

        fMAT22  STRUCT

            i   fPOINT  {}  ;// COLUMN 1
            j   fPOINT  {}  ;// COLUMN 2

        fMAT22  ENDS



;////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////
;//
;//
;//     P O I N T S
;//

;// many of these macros use eax,edx as X and Y
;// use caution and forsight


point_Clear MACRO p0:req, reg:=<eax>

    ;// sets point to 0,0
    xor reg, reg
    mov p0.x, reg
    mov p0.y, reg

ENDM

point_Set MACRO p0:req, X:=<eax>, Y:=<edx>

    ;// compute p0 = { X, Y }

    mov p0.x, X
    mov p0.y, Y

ENDM

fpoint_Set MACRO p:REQ

    fstp p.x
    fstp p.y

    ENDM

fpoint_Set_int MACRO p:REQ

    fistp p.x
    fistp p.y

    ENDM

point_Set_X MACRO p0:req, X:=<eax>

    ;// compute p0.x = { X }

    mov p0.x, X

ENDM

point_Set_Y MACRO p0:req, Y:=<edx>

    ;// compute p0.y = { Y }

    mov p0.y, Y

ENDM

point_SetTL MACRO r0:req, X:=<eax>, Y:=<edx>

    ;// compute p0 = { X, Y }

    mov r0.left, X
    mov r0.top, Y

ENDM

point_SetBR MACRO r0:req, X:=<eax>, Y:=<edx>

    ;// compute p0 = { X, Y }

    mov r0.right, X
    mov r0.bottom, Y

ENDM


point_Get MACRO p0:req, X:=<eax>, Y:=<edx>

    ;// compute { X, Y } = p0

    mov X, p0.x
    mov Y, p0.y

ENDM

fpoint_Get MACRO p:REQ

    fld p.y
    fld p.x

    ENDM

fpoint_Get_int MACRO p:REQ

    fild p.y
    fild p.x

    ENDM

fpoint_Pop MACRO q:REQ

    fstp q.x
    fstp q.y

    ENDM



point_Get_X MACRO p0:req, X:=<eax>

    ;// compute { X } = p0.x

    mov X, p0.x

ENDM

point_Get_Y MACRO p0:req, Y:=<edx>

    ;// compute { Y } = p0.y

    mov Y, p0.y

ENDM

point_Neg MACRO X:=<eax>, Y:=<edx>

    neg X
    neg Y

ENDM



point_Swap MACRO p0:req, X:=<eax>, Y:=<edx>

    ;// compute swaps regs, with point

    xchg X, p0.x
    xchg Y, p0.y

ENDM

point_SwapTL MACRO r0:req, X:=<eax>, Y:=<edx>

    ;// compute swaps regs, with rect left and top

    xchg X, r0.left
    xchg Y, r0.top

ENDM

point_SwapBR MACRO r0:req, X:=<eax>, Y:=<edx>

    ;// compute swaps regs, with rect bottom right

    xchg X, r0.right
    xchg Y, r0.bottom

ENDM


point_Push MACRO xx

    ;// push Y then X

    ;// caution !!
    ;// this assumes that eax, edx are X and Y
    ;// if xx is blank, edx and eax are pushed
    ;// otherwise xx.y and xx.x are pushed

    IFB <xx>

        push edx
        push eax

    ELSE

        push xx.y
        push xx.x

    ENDIF

    ENDM


point_PushTL MACRO rr:req

    push [rr].top
    push [rr].left

    ENDM

point_PushBR MACRO rr:req

    push [rr].bottom
    push [rr].right

    ENDM



point_Pop MACRO xx

    ;// pope Y then X

    ;// caution !!
    ;// this assumes that eax, edx are X and Y
    ;// if xx is blank, edx and eax are poped
    ;// otherwise xx.y and xx.x are poped

    IFB <xx>

        pop eax
        pop edx

    ELSE

        pop xx.x
        pop xx.y

    ENDIF

    ENDM


point_PopTL MACRO rr:req

    pop [rr].left
    pop [rr].top

    ENDM

point_PopBR MACRO rr:req

    pop [rr].right
    pop [rr].bottom

    ENDM








point_GetTL MACRO r0:req, X:=<eax>, Y:=<edx>

    ;// compute { X, Y } = r0

    mov X, r0.left
    mov Y, r0.top

ENDM

point_GetBR MACRO r0:req, X:=<eax>, Y:=<edx>

    ;// compute { X, Y } = r0

    mov X, r0.right
    mov Y, r0.bottom

ENDM


point_Add MACRO xx:req, yy

    ;// caution !!
    ;// this assumes that eax, edx are X and Y
    ;// this also checks for immediate values and skips zero
    ;// if xx is immediate and yy is blank
    ;//     then xx is treated as a name that can be suffixed with _X and _Y


    IF (OPATTR(xx) AND 4) OR ( ( OPATTR(xx) ) EQ 0 )

        ;// X is an immediate value
        ;// Y must also be an immediate value

        IFNB <yy>

            ;// X and Y are specied

            IF (OPATTR(yy) AND 4) OR ( ( OPATTR(yy) ) EQ 0 )
                IF xx
                    add eax, xx
                ENDIF
                IF yy
                    add edx, yy
                ENDIF
            ELSE
                .ERR <Since X is immediate, Y must also be immediate>
            ENDIF

        ELSE

            ;// X is immediate and Y is blank
            ;// so we assume _X and _Y suffixes

            IF xx&_X
                add eax, xx&_X
            ENDIF
            IF xx&_Y
                add edx, xx&_Y
            ENDIF

        ENDIF

    ELSE

        ;// X must be a pointer, and dot addressable as a point
        ;// Y must be blank

        IFNB <yy>
            .ERR <since X is a pointer, Y must be blank>
        ELSE

            add eax, xx.x
            add edx, xx.y

        ENDIF

    ENDIF

    ENDM



point_AddTL MACRO xx:req, yy

    ;// adds rect.left,top to x and y

    add eax, xx.left
    add edx, xx.top
    ENDM

point_AddBR MACRO xx:req

    ;// adds rect.right,bottom to x and y

    add eax, xx.right
    add edx, xx.bottom

    ENDM



point_Sub MACRO xx:req, yy

    ;// caution !!
    ;// this assumes that eax, edx are X and Y
    ;// this also checks for immediate values and skips zero
    ;// if xx is immediate and yy is blank
    ;//     then xx is treated as a name that can be suffixed with _X and _Y


    IF (OPATTR(xx) AND 4) OR ( ( OPATTR(xx) ) EQ 0 )

        ;// X is an immediate value
        ;// Y must also be an immediate value

        IFNB <yy>

            ;// X and Y are specified

            IF (OPATTR(yy) AND 4) OR ( ( OPATTR(yy) ) EQ 0 )
                IF xx
                    sub eax, xx
                ENDIF
                IF yy
                    sub edx, yy
                ENDIF
            ELSE
                .ERR <Since X is immediate, Y must also be immediate>
            ENDIF

        ELSE

            ;// X is immediate and Y is blank
            ;// so we assume _X and _Y suffixes

            IF xx&_X
                sub eax, xx&_X
            ENDIF
            IF xx&_Y
                sub edx, xx&_Y
            ENDIF

        ENDIF

    ELSE

        ;// X must be a pointer, and dot addressable as a point
        ;// Y must be blank

        IFNB <yy>
            .ERR <since X is a pointer, Y must be blank>
        ELSE

            sub eax, xx.x
            sub edx, xx.y

        ENDIF


    ENDIF

    ENDM

point_SubTL MACRO xx:req, yy

    ;// subtracts rect.left,top to x and y

    sub eax, xx.left
    sub edx, xx.top
    ENDM



point_SubBR MACRO xx:req

    ;// subtracts rect.right,bottom to x and y

    sub eax, xx.right
    sub edx, xx.bottom

    ENDM


point_XorTL MACRO xx:req, yy

    ;// xors rect.left,top to x and y

    xor eax, xx.left
    xor edx, xx.top
    ENDM

point_XorBR MACRO xx:req

    ;// xors rect.right,bottom to x and y

    xor eax, xx.right
    xor edx, xx.bottom

    ENDM

point_DecTL MACRO xx:req

    ;// decs rect.left,top to x and y

    dec xx.left
    dec xx.top
    ENDM

point_DecBR MACRO xx:req

    ;// decs rect.right,bottom to x and y

    dec xx.right
    dec xx.bottom

    ENDM


point_Shl MACRO val:req, xx:=<eax>,yy:=<edx>

    shl xx, val
    shl yy, val
    ENDM

point_Shr MACRO val:req, xx:=<eax>,yy:=<edx>

    shr xx, val
    shr yy, val
    ENDM

point_Sar MACRO val:req, xx:=<eax>,yy:=<edx>

    sar xx, val
    sar yy, val
    ENDM

point_ShrTL MACRO xx:req, val:req

    shr xx.left, val
    shr xx.top, val
    ENDM

point_ShrBR MACRO xx:req, val:req

    shr xx.right, val
    shr xx.bottom, val

    ENDM

point_ShlTL MACRO xx:req, val:req

    shl xx.left, val
    shl xx.top, val
    ENDM

point_ShlBR MACRO xx:req, val:req

    shl xx.right, val
    shl xx.bottom, val

    ENDM



;////////////////////////////////////////////////////////////////////
;//
;//                                 return eax, edx as the min or max
;// min max macros                  of the passed arg
;//
;//                                 eax, edx MUST BE THE POINT
;//                                 arg MUST BE DOT ADDRESSABLE
;//

point_Min MACRO pnt:req, X:=<eax>, Y:=<edx>

    LOCAL @01, @02

    cmp X, pnt.x
    jle @01
    mov X, pnt.x
@01:cmp Y, pnt.y
    jle @02
    mov Y, pnt.y
@02:

    ENDM

point_MinTL MACRO rect:req, X:=<eax>, Y:=<edx>

    LOCAL @01, @02

    cmp X, rect.left
    jle @01
    mov X, rect.left
@01:cmp Y, rect.top
    jle @02
    mov Y, rect.top
@02:

    ENDM

point_MinBR MACRO rect:req, X:=<eax>, Y:=<edx>

    LOCAL @01, @02

    cmp X, rect.right
    jle @01
    mov X, rect.right
@01:cmp Y, rect.bottom
    jle @02
    mov Y, rect.bottom
@02:

    ENDM



point_Max MACRO pnt:req, X:=<eax>, Y:=<edx>

    LOCAL @01, @02

    cmp X, pnt.x
    jge @01
    mov X, pnt.x
@01:cmp Y, pnt.y
    jge @02
    mov Y, pnt.y
@02:

    ENDM

point_MaxTL MACRO rect:req, X:=<eax>, Y:=<edx>

    LOCAL @01, @02

    cmp X, rect.left
    jge @01
    mov X, rect.left
@01:cmp Y, rect.top
    jge @02
    mov Y, rect.top
@02:

    ENDM

point_MaxBR MACRO rect:req, X:=<eax>, Y:=<edx>

    LOCAL @01, @02

    cmp X, rect.right
    jge @01
    mov X, rect.right
@01:cmp Y, rect.bottom
    jge @02
    mov Y, rect.bottom
@02:

    ENDM



point_Clip MACRO rect:req, X:=<eax>, Y:=<edx>

    LOCAL  _00, _01, _02, _03

            cmp X, rect.left
            jge _00
            mov X, rect.left
            jmp _01

    _00:    cmp X, rect.right
            jl  _01
            mov X, rect.right

    _01:    cmp Y, rect.top
            jge _02
            mov Y,rect.top
            jmp _03

    _02:    cmp Y, rect.bottom
            jl  _03
            mov Y, rect.bottom
    _03:


    ENDM











;//
;//
;// min max macros
;//
;//
;////////////////////////////////////////////////////////////////////




;////////////////////////////////////////////////////////////////////
;//
;//                     each use eax, and edx
;//     testing macros
;//



point_IfBeyondSize MACRO pt:req, then:req

    ;// assuming pt refers to the size of a rectangle
    ;// and that eax,edx is a point reletive to the top left
    ;// check if eax,edx is outside of the rect

    ;// use unsigned compare to catch both x<0 and x>=pr.x

        cmp eax, pt.x
        jae then
        cmp edx, pt.y
        jae then

    ;// fall through is point is inside the range

        ENDM





rect_IfNotIntersect MACRO rect1:req, rect2:req, then:req

    ;// eax, edx are used as X and Y

    point_GetBR rect1
    cmp eax, rect2.left
    jl then
    cmp edx, rect2.top
    jl then

    point_GetTL rect1
    cmp eax, rect2.right
    jg then
    cmp edx, rect2.bottom
    jg then

    ENDM


rect_IfXYNotInside MACRO rect:req, X:=<eax>, Y:=<edx>, then:req

    cmp X, rect.left
    jl then
    cmp Y, rect.top
    jl then
    cmp X, rect.right
    jg then
    cmp Y, rect.bottom
    jg then

    ENDM


rect_IfXYInside MACRO rect:req, X:=<eax>, Y:=<edx>, then:req

    LOCAL not_inside

    cmp X, rect.left
    jl not_inside
    cmp Y, rect.top
    jl not_inside
    cmp X, rect.right
    jg not_inside
    cmp Y, rect.bottom
    jle then

not_inside:

    ENDM







;////////////////////////////////////////////////////////////////////
;//
;//
;//     union macro
;//

    rect_UnionXY MACRO rect:req, X:=<eax>, Y:=<edx>

        ;// expands rect to include the passed point

        LOCAL @1, @2, @3, @4

        cmp X, rect.left
        jge @1
        mov rect.left, X
    @1:
        cmp Y, rect.top
        jge @2
        mov rect.top, Y
    @2:
        cmp X, rect.right
        jle @3
        mov rect.right, X
    @3:
        cmp Y, rect.bottom
        jle @4
        mov rect.bottom, Y
    @4:

        ENDM




    rect_UnionRect MACRO rect1:req, rect2:req, X:=<eax>, Y:=<edx>

        ;// expands rect1 to include rect2

        LOCAL @1, @2, @3, @4

        point_GetTL rect2, X, Y

        cmp X, rect1.left
        jge @1
        mov rect1.left, X
    @1:
        cmp Y, rect1.top
        jge @2
        mov rect1.top, Y
    @2:
        point_GetBR rect2, X, Y

        cmp X, rect1.right
        jle @3
        mov rect1.right, X
    @3:
        cmp Y, rect1.bottom
        jle @4
        mov rect1.bottom, Y
    @4:

        ENDM
























point_CopyTo MACRO p1:req, p2:req, X:=<eax>, Y:=<edx>

    ;// computes p2=p1
    ;// also loads [ X, Y ]

    point_Get p1, X, Y
    point_Set p2, X, Y

    ENDM





spoint_Get MACRO short:req, X:=<eax>, Y:=<edx>

    ;//
    ;// this loads X and Y from a two shorts
    ;//

    movsx X, WORD PTR [short]
    movsx Y, WORD PTR [short+2]

    ENDM


point_FromShort MACRO point:req, short:req, X:=<eax>, Y:=<edx>

    ;//
    ;// this translates a short point, to a normal POINT
    ;//

    spoint_Get short, X, Y
    point_Set point, X, Y

    ENDM


point_ToShort MACRO point:req, short:req, reg1:=<eax>, reg2:=<edx>
    ;//
    ;// this translates a normal POINT to a short point
    ;//

    mov reg2, point.y
    mov reg1, point.x
    and reg1, 0FFFFh
    shl reg2, 16
    or reg1, reg2
    mov short, reg1

    ENDM



point_FromPosOfs MACRO point:req, pos:req, ofs:req, tempReg1:=<eax>, tempReg2:=<edx>

    ;// computes point = pos + offset

    mov tempReg1, pos.x
    mov tempReg2, pos.y
    add tempReg1, ofs.x
    add tempReg2, ofs.y
    mov point.x, tempReg1
    mov point.y, tempReg2

    ENDM


point_Delta MACRO p1:req, p2:req, p3, X:=<eax>, Y:=<edx>

    ;// computes p3 = p2 - p1
    ;// if p3 is not specified, then just compute in registers

    mov X, p2.x
    mov Y, p2.y

    sub X, p1.x
    sub Y, p1.y

    IFNB <p3>
        mov p3.x, X
        mov p3.y, Y
    ENDIF


ENDM


point_AddTo MACRO p1:req, p2, X:=<eax>, Y:=<edx>

    ;// computes p2+=p1
    ;// if p2 is blank, then assume eax,edx are what we add to p1

    IFNB <p2>

    ECHO <point_AddTo, might want to make sure this what you intended>

        IF (OPATTR(p2) AND 4) OR ( ( OPATTR(p2) ) EQ 0 )

            ;// X is an immediate value
            ;// Y must also be an immediate value

            IF (OPATTR(X) AND 4) OR ( ( OPATTR(X) ) EQ 0 )
                IF p2
                    add p1.x, p2
                ENDIF
                IF X
                    add p1.y, X
                ENDIF
            ELSE
                .ERR <Since X is immediate, Y must also be immediate>
            ENDIF

        ELSE

            mov X, p1.x
            mov Y, p1.y
            add p2.x, X
            add p2.y, Y

        ENDIF

    ELSE

        add p1.x, X
        add p1.y, Y

    ENDIF


ENDM


point_SubTo MACRO p1:req, p2, X:=<eax>, Y:=<edx>

    ;// computes p2-=p1
    ;// if p2 is blank, then assume eax,edx are what we add to p1

    IFNB <p2>

        mov X, p1.x
        mov Y, p1.y
        sub p2.x, X
        sub p2.y, Y

    ELSE

        sub p1.x, X
        sub p1.y, Y

    ENDIF


ENDM




point_AddToTL MACRO p1:req, X:=<eax>, Y:=<edx>

    IFDIFI <X>,<eax>
    ECHO    <point_AddToTL this macro used to have p1,p2,x,y args, make sure it's what you want>
    ENDIF
    IFDIFI <Y>,<edx>
    ECHO    <point_AddToTL this macro used to have p1,p2,x,y args, make sure it's what you want>
    ENDIF

    add p1.left, X
    add p1.top, Y

ENDM

point_AddToBR MACRO p1:req, X:=<eax>, Y:=<edx>

    IFDIFI <X>,<eax>
    ECHO    <point_AddToTL this macro used to have p1,p2,x,y args, make sure it's what you want>
    ENDIF
    IFDIFI <Y>,<edx>
    ECHO    <point_AddToTL this macro used to have p1,p2,x,y args, make sure it's what you want>
    ENDIF

    add p1.right, X
    add p1.bottom, Y

ENDM







point_SubToTL MACRO p1:req, X:=<eax>, Y:=<edx>

    IFDIFI <X>,<eax>
    ECHO    <point_AddToTL this macro used to have p1,p2,x,y args, make sure it's what you want>
    ENDIF
    IFDIFI <Y>,<edx>
    ECHO    <point_AddToTL this macro used to have p1,p2,x,y args, make sure it's what you want>
    ENDIF

    sub p1.left, X
    sub p1.top, Y

ENDM

point_SubToBR MACRO p1:req, X:=<eax>, Y:=<edx>

    IFDIFI <X>,<eax>
    ECHO    <point_AddToTL this macro used to have p1,p2,x,y args, make sure it's what you want>
    ENDIF
    IFDIFI <Y>,<edx>
    ECHO    <point_AddToTL this macro used to have p1,p2,x,y args, make sure it's what you want>
    ENDIF

    sub p1.right, X
    sub p1.bottom, Y

ENDM






;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//
;//
;//     R E C T A N G L E S
;//

rect_Clear MACRO rect:req, reg:=<eax>

    ;// sets all values to zero
    xor reg, reg
    mov rect.left, reg
    mov rect.top, reg
    mov rect.right, reg
    mov rect.bottom, reg

    ENDM


rect_CopyTo MACRO rect1:req, rect2:req, X:=<eax>, Y:=<edx>

    ;// copies rect1 to rect2

    point_GetTL rect1, X, Y
    point_SetTL rect2, X, Y
    point_GetBR rect1, X, Y
    point_SetBR rect2, X, Y

    ENDM



rect_Swap MACRO r0:req, r1:req, X:=<eax>, Y:=<edx>

    ;// swaps the values in r0 and r1

    point_GetTL r0, X, Y
    point_SwapTL r1, X, Y
    point_SetTL r0, X, Y

    point_GetBR r0, X, Y
    point_SwapBR r1, X, Y
    point_SetBR r0, X, Y

    ENDM









rect_FromCenRad MACRO rect:req, cen:req, rad:req, reg1:=<eax>, reg2:=<edx>

    ;// computes top left  = cen - rad
    ;//          bottom right = topleft + 2*rad

    mov reg1, cen.x
    mov reg2, cen.y
    sub reg1, rad
    sub reg2, rad
    mov rect.left, reg1
    mov rect.top, reg2

    IF OPATTR(rad)
        add reg1, rad
        add reg2, rad
        add reg1, rad
        add reg2, rad
    ELSE
        add reg1, rad * 2
        add reg2, rad * 2
    ENDIF
    mov rect.right, reg1
    mov rect.bottom, reg2

    ENDM



rect_FromCenOfsRad MACRO rect:req, cen:req, ofs:req, rad:req, reg1:=<eax>, reg2:=<edx>

    ;// computes topLeft = (cen+ofs)-rad
    ;//          botRigt = topLeft + 2* rad

    mov reg1, cen.x
    mov reg2, cen.y
    add reg1, ofs.x
    add reg2, ofs.y
    sub reg1, rad
    sub reg2, rad
    mov rect.left, reg1
    mov rect.top, reg2
    add reg1, rad
    add reg2, rad
    add reg1, rad
    add reg2, rad
    mov rect.right, reg1
    mov rect.bottom, reg2

    ENDM





rect_FromCenSizWid MACRO rect:req, cen:req, siz:req, wid:req, tempReg1:=<eax>, tempReg2:=<edx>

    ;// computes topLeft = cen - siz
    ;// and bottomRight = topLeft + wid
    mov tempReg1, cen.x
    mov tempReg2, cen.y
    sub tempReg1, siz.x
    sub tempReg2, siz.y
    mov rect.left, tempReg1
    mov rect.top, tempReg2
    add tempReg1, wid.x
    add tempReg2, wid.y
    mov rect.right, tempReg1
    mov rect.bottom, tempReg2

    ENDM



rect_FromOrgOfsSizWid MACRO rect:req, oorg:req, ofs:req, siz:req, wid:req, tempReg1:=<eax>, tempReg2:=<edx>

    ;// ofs is an offset from oorg to the center of the rect
    ;// siz is usually half the width, but does need to be
    ;//
    ;// computes TopLeft = ( oorg + ofs ) - siz
    ;// and BottonRight = TopLeft + wid

        mov tempReg1, oorg.x
        mov tempReg2, oorg.y
        add tempReg1, ofs.x
        add tempReg2, ofs.y
        sub tempReg1, siz.x
        sub tempReg2, siz.y
        mov rect.left, tempReg1
        mov rect.top, tempReg2
        add tempReg1, wid.x
        add tempReg2, wid.y
        mov rect.right, tempReg1
        mov rect.bottom, tempReg2

        ENDM


rect_FromPosSize MACRO rect:req, pos:req, siz:req, X:=<eax>, Y:=<edx>

    ;// all of these parameters must be dot addressable

    mov X, pos.x
    mov Y, pos.y
    mov rect.left, X
    mov rect.top, Y
    add X, siz.x
    add Y, siz.y
    mov rect.right, X
    mov rect.bottom, Y

    ENDM



rect_FromOrgOfsRad MACRO rect:req, oorg:req, ofs:req, rad:req, tempReg1:=<eax>, tempReg2:=<edx>

    ;// rad must be a scalar
    ;// computes TopLeft = ( oorg + ofs ) - rad
    ;// and  BottomRight = TopLeft + rad + rad

    mov tempReg1, oorg.x
    mov tempReg2, oorg.y
    add tempReg1, ofs.x
    add tempReg2, ofs.y
    sub tempReg1, rad
    sub tempReg2, rad
    mov rect.left, tempReg1
    mov rect.top, tempReg2
    add tempReg1, rad
    add tempReg2, rad
    add tempReg1, rad
    add tempReg2, rad
    mov rect.right, tempReg1
    mov rect.bottom, tempReg2

    ENDM



rect_FromOrgOfsSiz MACRO rect:req, oorg:req, ofs:req, siz:req, tempReg1:=<eax>, tempReg2:=<edx>

    ;// computes TopLeft = ( oorg + ofs ) - siz
    ;// and  BottomRight = TopLeft + siz + siz

    mov tempReg1, oorg.x
    mov tempReg2, oorg.y
    add tempReg1, ofs.x
    add tempReg2, ofs.y
    sub tempReg1, siz.x
    sub tempReg2, siz.y
    mov rect.left, tempReg1
    mov rect.top, tempReg2
    add tempReg1, siz.x
    add tempReg2, siz.y
    add tempReg1, siz.x
    add tempReg2, siz.y
    mov rect.right, tempReg1
    mov rect.bottom, tempReg2

    ENDM



rect_FromOrgCenOfsRad MACRO rect:req, oorg:req, cen:req, ofs:req, rad:req, reg1:=<eax>, reg2:=<edx>

    ;// computes:
    ;// rect top left = oorg + cen + ofs - rad
    ;// rect bot rigt = top left + rad + rad

    mov reg1, oorg.x
    mov reg2, oorg.y
    add reg1, cen.x
    add reg2, cen.y
    add reg1, ofs.x
    add reg2, ofs.y
    sub reg1, rad
    sub reg2, rad
    mov rect.left, reg1
    mov rect.top, reg2

    add reg1, rad
    add reg2, rad
    add reg1, rad
    add reg2, rad
    mov rect.right, reg1
    mov rect.bottom, reg2

    ENDM


rect_FromPosSizOfs MACRO rect:req, pos:req, siz:req, ofs:req, X:=<eax>, Y:=<edx>

    ;// computes: topleft = pos + ofs
    ;//           bottom right = topleft + siz

    mov X, pos.x
    mov Y, pos.y
    IF OPATTR(ofs)
        add X, ofs.x
        add Y, ofs.y
    ELSE
        add X, ofs&_x
        add Y, ofs&_y
    ENDIF
    mov rect.left, X
    mov rect.top, Y
    add X, siz.x
    add Y, siz.y
    mov rect.right, X
    mov rect.bottom, Y

    ENDM







rect_FromRectOfs MACRO rect:req, r1:req, pos:req, reg1:=<eax>, reg2:=<edx>

    ;// computes rect.topleft = r1.topleft + pos
    ;// computes rect.bottomright = r1.bottomright + pos

    mov reg1, r1.left
    mov reg2, r1.top
    add reg1, pos.x
    add reg2, pos.y
    mov rect.left, reg1
    mov rect.top, reg2

    mov reg1, r1.right
    mov reg2, r1.bottom
    add reg1, pos.x
    add reg2, pos.y
    mov rect.right, reg1
    mov rect.bottom, reg2

    ENDM



rect_FromRectOfsExt MACRO rect:req, r1:req, pos:req, extx:req, exty:req, reg1:=<eax>, reg2:=<edx>

    ;// computes rect.topleft = r1.topleft + pos + ext(x,y)
    ;// computes rect.bottomright = r1.bottomright + pos + ext(x,y)

    mov reg1, r1.left
    mov reg2, r1.top
    add reg1, pos.x
    add reg2, pos.y
    add reg1, extx
    add reg2, exty
    mov rect.left, reg1
    mov rect.top, reg2

    mov reg1, r1.right
    mov reg2, r1.bottom
    add reg1, pos.x
    add reg2, pos.y
    add reg1, extx
    add reg2, exty
    mov rect.right, reg1
    mov rect.bottom, reg2

    ENDM



rect_Inflate MACRO rect:req, delta

    ;// inflates from center

    IFNB <delta>

        sub rect.left, delta
        sub rect.top, delta
        add rect.right, delta
        add rect.bottom, delta

    ELSE

        dec rect.left
        dec rect.top
        inc rect.right
        inc rect.bottom

    ENDIF

    ENDM


rect_Deflate MACRO rect:req, delta

    ;// deflates to  center

    IFNB <delta>

        add rect.left, delta
        add rect.top, delta
        sub rect.right, delta
        sub rect.bottom, delta

    ELSE

        inc rect.left
        inc rect.top
        dec rect.right
        dec rect.bottom

    ENDIF

    ENDM




rect_Set MACRO rect:req, rl:req, rt:req, rr:req, rb:req

    ;// this just sets all four points
    ;// rect must be dot addressable, the rest may be immediate or registers

    mov rect.left, rl
    mov rect.top, rt
    mov rect.right, rr
    mov rect.bottom, rb

    ENDM






























;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//
;//
;//     T R I A N G L E S
;//


triangle_FromPosTableDir MACRO tri:req, point:req, table:req, dir:req, regX:=<eax>, regY:=<edx>

    ;// tri must be an an adress to three points
    ;// point is a dot adressable item that represents where we start
    ;// table is an adress to three points that represent a sequence of point offsets
    ;//   that will walk around a triangle pointing UP, starting at the center
    ;// dir is a text item that tells how we should define the triangle

    assume tri:PTR POINT
    assume table:PTR POINT

    IFIDN <dir>, <UP>

        ; walk around the table
        mov regX, point.x
        mov regY, point.y

        add regX, [table].x
        add regY, [table].y
        mov [tri].x, regX
        mov [tri].y, regY

        add regX, [table+SIZEOF POINT].x
        add regY, [table+SIZEOF POINT].y
        mov [tri+SIZEOF POINT].x, regX
        mov [tri+SIZEOF POINT].y, regY

        add regX, [table+(SIZEOF POINT)*2].x
        add regY, [table+(SIZEOF POINT)*2].y
        mov [tri+(SIZEOF POINT)*2].x, regX
        mov [tri+(SIZEOF POINT)*2].y, regY

    ENDIF

    IFIDN <dir>, <DOWN>

        ; walk around the table , but subtract
        mov regX, point.x
        mov regY, point.y

        sub regX, [table].x
        sub regY, [table].y
        mov [tri].x, regX
        mov [tri].y, regY

        sub regX, [table+SIZEOF POINT].x
        sub regY, [table+SIZEOF POINT].y
        mov [tri+SIZEOF POINT].x, regX
        mov [tri+SIZEOF POINT].y, regY

        sub regX, [table+(SIZEOF POINT)*2].x
        sub regY, [table+(SIZEOF POINT)*2].y
        mov [tri+(SIZEOF POINT)*2].x, regX
        mov [tri+(SIZEOF POINT)*2].y, regY

    ENDIF

    IFIDN <dir>,<LEFT>

        ; walk around table, revrse x and y, add

        mov regX, point.x
        mov regY, point.y

        add regX, [table].y
        add regY, [table].x
        mov [tri].x, regX
        mov [tri].y, regY

        add regX, [table+SIZEOF POINT].y
        add regY, [table+SIZEOF POINT].x
        mov [tri+SIZEOF POINT].x, regX
        mov [tri+SIZEOF POINT].y, regY

        add regX, [table+(SIZEOF POINT)*2].y
        add regY, [table+(SIZEOF POINT)*2].x
        mov [tri+(SIZEOF POINT)*2].x, regX
        mov [tri+(SIZEOF POINT)*2].y, regY

    ENDIF

    IFIDN <dir>,<RIGHT>

        ; walk around table, revrse x and y, subtract

        mov regX, point.x
        mov regY, point.y

        sub regX, [table].y
        sub regY, [table].x
        mov [tri].x, regX
        mov [tri].y, regY

        sub regX, [table+SIZEOF POINT].y
        sub regY, [table+SIZEOF POINT].x
        mov [tri+SIZEOF POINT].x, regX
        mov [tri+SIZEOF POINT].y, regY

        sub regX, [table+(SIZEOF POINT)*2].y
        sub regY, [table+(SIZEOF POINT)*2].x
        mov [tri+(SIZEOF POINT)*2].x, regX
        mov [tri+(SIZEOF POINT)*2].y, regY

    ENDIF


ENDM










;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//
;//
;//     R E G I O N S
;//

region_CombineRect MACRO hRgn:req, rect:req

    ;// this adds a rectangle to a rgn

    invoke CreateRectRgnIndirect, ADDR rect
    push eax
    invoke CombineRgn, hRgn, hRgn, eax, RGN_OR
    pop eax
    invoke DeleteObject, eax

    ENDM



region_CombinePolygon MACRO hRgn:req, pntList:req, numPoints:req, style:=<ALTERNATE>

    ;// this adds a polygon region to the supplied region

    invoke CreatePolygonRgn, ADDR pntList, numPoints, style
    push eax
    invoke CombineRgn, hRgn, hRgn, eax, RGN_OR
    pop eax
    invoke DeleteObject, eax

    ENDM


ENDIF   ;// _GEOMETRY_INCLUDED_