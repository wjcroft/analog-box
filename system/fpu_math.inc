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
;//     fpu_MATH.INC        macros for the pentium fpu
;//

;// fpu_2X      2^x
;// fpu_TANH2   tanh2(x)
;// fpu_POWER   x^y

IFNDEF _FPU_MATH_INCLUDED_
_FPU_MATH_INCLUDED_ EQU 1


fpu_2X MACRO reg:req

    ;//
    ;// performs y = 2 ^ X      where X is st(0) and may be any range
    ;//                         reg indicates where to find the number 1
    ;//
    ;//     destroys eax
    ;//     requires 2 free fpu registers

    LOCAL reg1
    reg1 = reg+1
                    ;// X   ... 1
    fld st          ;// X   X   ... 1
    fabs
    fucomp st(reg1) ;// X   ... 1
    xor eax, eax
    fnstsw ax
    sahf
    .IF !CARRY? ;// have to do the hard way

        fld st(reg)     ;// 1       X   ... 1
        fld st(1)       ;// X       1   X   ... 1
        .REPEAT
            fprem
            xor eax, eax
            fnstsw ax
            sahf
        .UNTIL !PARITY? ;// fX      1   X   ... 1

        f2xm1           ;// 2^fX-1  1   X   ...
        fadd            ;// 2^fX    X
        fscale          ;// 2^X     X   ... 1
        fxch
        fstp st

    .ELSE       ;// can do the easy way

        f2xm1               ;// 2^X-1   ...     1
        fadd st, st(reg)    ;// 2^X     ...     1

    .ENDIF

    ENDM




fpu_TAN2H MACRO

    ;//                2^x - 1      A
    ;//     tan2h(x) = -------
    ;//                2^x + 1      B

            ;// X

    fld1
    fxch
    fpu_2X 1    ;// 2^x     1

    fld st          ;// 2^x     2^x     1
    fsub st, st(1)  ;// A       2^x     1
    fxch            ;// 2^x     A       1
    faddp st(2), st ;// A       B
    fdivr

    ENDM



fpu_POWER MACRO

    ;// in  X   Y   ...
    ;// out X^Y ...

    ;// perform z = x^y     x must be positive, or return 1
    ;//
    ;// z = 2^(y*log2(x))
    ;// if x=0 then return 0

    ;// destroys eax

    LOCAL is_ok, all_done

                ;// x   y   ..
    ftst
    fnstsw ax
    sahf
    ja is_ok

        fstp st
        fstp st
        fldz
        jmp all_done

    is_ok:

        fyl2x       ;// y*log2(x)   ..
        fld1
        fxch
        fpu_2X 1
        fxch
        fstp st

    all_done:


    ENDM






ENDIF ;// _FPU_MATH_INCLUDED_
