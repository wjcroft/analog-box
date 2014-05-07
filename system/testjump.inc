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
;// testjump.inc        these macros try to save code space
;//                     all are in the form of DO_TEST arg,arg
;//                                            JUMP COND label
IFNDEF _TESTJUMP_INCLUDED
_TESTJUMP_INCLUDED EQU 1

    INCLUDE <utility.inc>


    MOVJMP  MACRO arg1:req, arg2:req, cond:req
        mov arg1, arg2
        cond
        ENDM

    MOVSXJMP MACRO arg1:req, arg2:req, cond:req
        movsx arg1, arg2
        cond
        ENDM

    LEAJMP  MACRO arg1:req, arg2:req, cond:req
        lea arg1, arg2
        cond
        ENDM

    CMPJMP  MACRO arg1:req, arg2:req, cond:req
        cmp arg1, arg2
        cond
        ENDM

    CMPSBJMP MACRO cond:req
        cmpsb
        cond
        ENDM

    CMPSWJMP MACRO cond:req
        cmpsw
        cond
        ENDM

    CMPSDJMP MACRO cond:req
        cmpsd
        cond
        ENDM


    ADDJMP  MACRO arg1:req, arg2:req, cond:req
        add arg1, arg2
        cond
        ENDM

    SUBJMP  MACRO arg1:req, arg2:req, cond:req
        sub arg1, arg2
        cond
        ENDM

    MULJMP  MACRO arg1:req, cond:req
        mul arg1
        cond
        ENDM

    TESTJMP  MACRO arg1:req, arg2:req, cond:req
        test arg1, arg2
        cond
        ENDM

    DECJMP  MACRO arg:req, cond:req
        dec arg
        cond
        ENDM

    INCJMP  MACRO arg:req, cond:req
        inc arg
        cond
        ENDM

    NEGJMP  MACRO arg:req, cond:req
        neg arg
        cond
        ENDM

    SHRJMP  MACRO arg1:req, arg2:req, cond:req
        shr arg1, arg2
        cond
        ENDM

    ORJMP  MACRO arg1:req, arg2:req, cond:req
        or arg1, arg2
        cond
        ENDM

    XORJMP  MACRO arg1:req, arg2:req, cond:req
        xor arg1, arg2
        cond
        ENDM

    ANDJMP  MACRO arg1:req, arg2:req, cond:req
        and arg1, arg2
        cond
        ENDM



    ;// bt bts btr that use LOG2()
    BITTJMP MACRO arg1:req, arg2:req, cond:req
        BITT arg1, arg2
        cond
        ENDM
    BITRJMP MACRO arg1:req, arg2:req, cond:req
        BITR arg1, arg2
        cond
        ENDM
    BITSJMP MACRO arg1:req, arg2:req, cond:req
        BITS arg1, arg2
        cond
        ENDM

    ;// bt bts btr that use LOG2() and call if carry is set
    BITTCALL MACRO arg1:req, arg2:req, loc:req
        BITT arg1, arg2
        .IF CARRY?
        call loc
        .ENDIF
        ENDM
    BITSCALL MACRO arg1:req, arg2:req, loc:req
        BITS arg1, arg2
        .IF CARRY?
        call loc
        .ENDIF
        ENDM
    BITRCALL MACRO arg1:req, arg2:req, loc:req
        BITR arg1, arg2
        .IF CARRY?
        call loc
        .ENDIF
        ENDM


    ;// variation of BIT JMP that uses .IF .ENDIF
    IFBITT MACRO arg1:req, arg2:req
        BITT arg1, arg2
        .IF CARRY?
        ENDM
    IFBITS MACRO arg1:req, arg2:req
        BITS arg1, arg2
        .IF CARRY?
        ENDM
    IFBITR MACRO arg1:req, arg2:req
        BITR arg1, arg2
        .IF CARRY?
        ENDM

    ;// bt bts btr that do not use LOG2()
    BTJMP MACRO arg1:req, arg2:req, cond:req
        bt arg1, arg2
        cond
        ENDM
    BTRJMP MACRO arg1:req, arg2:req, cond:req
        btr arg1, arg2
        cond
        ENDM
    BTSJMP MACRO arg1:req, arg2:req, cond:req
        bts arg1, arg2
        cond
        ENDM

    CALLJMP MACRO arg:req, cond:req
        call arg
        cond
        ENDM

    PUSHJMP MACRO arg:req, cond:req
        pushd arg
        cond
        ENDM

    CALLC MACRO arg
        LOCAL no_call
        jnc no_call
        call arg
        no_call:
        ENDM





    FCOMIJMP MACRO arg1, arg2, cond

        fcomi arg1, arg2
        cond

        ENDM


    FCOMIPJMP MACRO arg1, arg2, cond

        fcomip arg1, arg2
        cond

        ENDM



















ENDIF ;// _TESTJUMP_INCLUDED