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
;//     QWORD.INC       macros for dealing with qwords
;//
IFNDEF _QWORD_INCLUDED_
_QWORD_INCLUDED_ EQU 1


comment ~ /*

    qwords are defined by two dwords with the same starting name
    _lo and _hi are appended to indicate which half

    like the point_ macro's, we use eax and edx as defaults

*/ comment ~


;/////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////
;///
;///
;///    declaration
;///

        _QWORD_ MACRO nm:REQ, init_hi:=<0>, init_lo:=<0>

            nm&_lo  dd  init_lo
            nm&_hi  dd  init_hi

            ENDM



;/////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////
;///
;///
;///    GET  SET    PUSH POP
;///


    qword_Get MACRO nm:req, lo_reg:=<eax>, hi_reg:=<edx>

        mov lo_reg, nm&_lo
        mov hi_reg, nm&_hi

        ENDM

    qword_Put MACRO nm:req, lo_reg:=<eax>, hi_reg:=<edx>

        mov nm&_lo, lo_reg
        mov nm&_hi, hi_reg

        ENDM

    qword_Push MACRO n1, n2

        IFNB <n1>

            IFNB <n2>       ;// two args, both better be pushable

                pushd n2
                pushd n1

            ELSE            ;// one arg, better be _lo _hi format

                pushd n1&_hi
                pushd n1&_lo

            ENDIF

        ELSEIFB <n2>        ;// assume eax and edx

            push edx
            push eax

        ELSE

            .ERR <first arg is empty !!>

        ENDIF

        ENDM


    qword_Pop MACRO n1, n2

        IFNB <n1>

            IFNB <n2>       ;// two args, both better be popable

                pop n1
                pop n2

            ELSE            ;// one arg, better be _lo _hi format

                pop n1&_lo
                pop n1&_hi

            ENDIF

        ELSEIFB <n2>        ;// assume eax and edx

            pop eax
            pop edx

        ELSE

            .ERR <first arg is empty !!>

        ENDIF

        ENDM




;/////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////
;///
;///                    all are in the form of:
;///    COMPARISON
;///                        if qword is OP NAME then GOTO


    if_qword_NZ MACRO jump:REQ, lo_reg:=<eax>, hi_reg:=<edx>

        ;// checks if qword = 0

        test lo_reg, lo_reg
        jnz jump
        test hi_reg, hi_reg
        jnz jump

        ENDM

    ;// this next performs comparisons with memory

    QWORD_CMP_LO MACRO
    %   EXITM <cmp lo_reg, nm&_lo>
        ENDM
    QWORD_CMP_HI MACRO
    %   EXITM <cmp hi_reg, nm&_hi>
        ENDM

    if_qword_NE MACRO nm:req, jump:req, lo_reg:=<eax>, hi_reg:=<edx>

        QWORD_CMP_LO
        jne jump
        QWORD_CMP_HI
        jne jump

        ENDM

    if_qword_EQ MACRO nm:req, jump:req, lo_reg:=<eax>, hi_reg:=<edx>

        LOCAL fall

            QWORD_CMP_LO
            jne fall
            QWORD_CMP_HI
            je jump

        fall:

        ENDM

    if_qword_LT MACRO nm:req, jump:req, lo_reg:=<eax>, hi_reg:=<edx>

        LOCAL fall

            QWORD_CMP_HI
            jb jump
            ja fall
            QWORD_CMP_LO
            jb jump

        fall:

        ENDM

    if_qword_LTE MACRO nm:req, jump:req, lo_reg:=<eax>, hi_reg:=<edx>

        LOCAL fall

            QWORD_CMP_HI
            jb jump
            ja fall
            QWORD_CMP_LO
            jbe jump

        fall:

        ENDM

    if_qword_GT MACRO nm:req, jump:req, lo_reg:=<eax>, hi_reg:=<edx>

        LOCAL fall

            QWORD_CMP_HI
            ja jump
            jb fall
            QWORD_CMP_LO
            ja jump

        fall:

        ENDM

    if_qword_GTE MACRO nm:req, jump:req, lo_reg:=<eax>, hi_reg:=<edx>

        LOCAL fall

            QWORD_CMP_HI
            ja jump
            jb fall
            QWORD_CMP_LO
            jae jump

        fall:

        ENDM


;/////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////
;///
;///
;///    ARITHMETIC
;///


    qword_Add MACRO nm:REQ, lo_reg:=<eax>, hi_reg:=<edx>

        add lo_reg, nm&_lo
        adc hi_reg, nm&_hi

        ENDM

    qword_AddTo MACRO nm:REQ, lo_reg:=<eax>, hi_reg:=<edx>

        add nm&_lo, lo_reg
        adc nm&_hi, hi_reg

        ENDM

    qword_Sub MACRO nm:REQ, lo_reg:=<eax>, hi_reg:=<edx>

        sub lo_reg, nm&_lo
        sbb hi_reg, nm&_hi

        ENDM

    qword_Add32 MACRO val:REQ, lo_reg:=<eax>, hi_reg:=<edx>

        add lo_reg, val
        adc hi_reg, 0

        ENDM

    qword_Shift MACRO num:REQ, lo_reg:=<eax>, hi_reg:=<edx>

        ;// POSITIVE is SHIFT LEFT (MAKE BIGGER)
        ;// NEGATIVE is SHIFT RIGHT (MAKE SMALLER)

        IF num LT 0

            shld hi_reg, lo_reg, num    ;// shift lo into high
            shl lo_reg, num             ;// shift lo

        ELSEIF num GT 0

            shrd lo_reg, hi_reg, num    ;// shift hi into lo
            sar hi_reg, num             ;// shift hi (preserve sign)

        ENDIF

        ENDM

    qword_Inc MACRO lo_reg:=<eax>, hi_reg:=<edx>

        inc lo_reg
        .IF ZERO?
            inc hi_reg
        .ENDIF

        ENDM

    qword_Dec MACRO lo_reg:=<eax>, hi_reg:=<edx>

        dec lo_reg
        .IF SIGN?
            dec hi_reg
        .ENDIF

        ENDM



ENDIF   ;// IFNDEF _QWORD_INCLUDED_