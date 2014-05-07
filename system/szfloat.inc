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
;//     szfloat.inc     rountines to xlate between floats and strings
;//
IFNDEF _SZFLOAT_INCLUDED_
_SZFLOAT_INCLUDED_ EQU 1


    sz_to_float PROTO   ;// defined in sz_to_float.asm

        ;// error return codes from sz_to_float
        ;// carry flag will be set

        NOT_A_NUMBER            EQU 00000000h   ;// there just wasn't a number there

        ;// these values indicate the FPU is empty and we did indeed
        ;// receive a parsable number.
        ;// edx points at the end of the string should we choose to continue

        NUMBER_RANGE_ERROR      EQU 080000000h  ;// 1000    mask
        NUMBER_RANGE_NEG        EQU 010000000h  ;// 0001

        NUMBER_ERR_BIG          EQU 010000000h  ;// other wise too samll
        NUMBER_ERR_NEG          EQU 020000000h  ;// otherwise pos

        NUMBER_TOO_SMALL        EQU 080000000h  ;// 1000
        NUMBER_TOO_SMALL_NEG    EQU 090000000h  ;// 1001
        NUMBER_TOO_LARGE        EQU 0A0000000h  ;// 1010
        NUMBER_TOO_LARGE_NEG    EQU 0B0000000h  ;// 1011


    float_to_sz PROTO   ;// defined in float_to_sz.asm




comment ~ /*

    float to sz

    formatting values must include 1 from each column

    FIX
    SCI  DIG1-8
    ENG
                    FIX         SCI             ENG
                    DIG=8       DIG=8           DIG=8
123456789.          #########   1.2345678e+8    123.45678M
12345678.9          12345678.   1.2345678e+7    12.345678M
1234567.89          1234567.8   1.2345678e+6    1.2345678M
123456.789          123456.78   1.2345678e+5    123.45678K
12345.6789          12345.678   1.2345678e+4    12.345678K
1234.56789          1234.5678   1.2345678e+3    1.2345678K
123.456789          123.45678   1.2345678e+2    123.45678
12.3456789          12.345678   1.2345678e+1    12.345678
1.23456789          1.2345678   1.2345678e+0    1.2345678
.123456789          0.1234567   1.2345678e-1    123.45678m
.0123456789         0.0123456   1.2345678e-2    12.345678m
.00123456789        0.0012345   1.2345678e-3    1.2345678m
.000123456789       0.0001234   1.2345678e-4    123.45678u
.0000123456789      0.0000123   1.2345678e-5    12.345678u
.00000123456789     0.0000012   1.2345678e-6    1.2345678u
.000000123456789    0.0000001   1.2345678e-7    123.45678n
.0000000123456789   0.0000000   1.2345678e-8    12.345678n

*/ comment ~

    ;//                         XXXXXXXX
    FLOATSZ_DIG_3   EQU 0000000000000010y   ;// cmp dl
    FLOATSZ_DIG_4   EQU 0000000000000011y
    FLOATSZ_DIG_5   EQU 0000000000000100y
    FLOATSZ_DIG_6   EQU 0000000000000101y
    FLOATSZ_DIG_7   EQU 0000000000000110y

    FLOATSZ_DIG_TEST EQU 000000000000111y

    FLOATSZ_FIX     EQU 0000000100000000y   ;// index 1 cmp dh
    FLOATSZ_SCI     EQU 0000001000000000y   ;// index 2 cmp dh
    FLOATSZ_ENG     EQU 0000001100000000y   ;// index 3 cmp dh
    FLOATSZ_INT     EQU 0000010000000000y   ;// index 4 cmp dh

    FLOATSZ_TEST    EQU 0000011100000000y   ;// must have a format flag

    FLOATSZ_SPACE   EQU 00010000h   ;// put a space between number and suffix
                                    ;// only effects ENG and SCI




    FLOATSZ_LEADING_PLUS    EQU 00020000h   ;// prefix with + if pos

    FLOATSZ_2_DIGIT_EXP     EQU 00040000h   ;// force exp to be 2 digits (applies only to sci)
    FLOATSZ_WANT_0_EXP      EQU 00080000h   ;// if exp is zero, display as 0.0e+0 (applies to sci only)




ENDIF ;// _SZFLOAT_INCLUDED_