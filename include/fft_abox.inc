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
;//                         fft's are always dual
;//     fft_abox.inc        call appropriate function with pointers
;//                         this is a stripped down version of fft.inc
;//                         don't get them confused


    ;// style of fft's, flags are in pairs (usually)
    ;// note: do not change the values of sizes

;// FFT_512         equ 00001000h   ;// data size
    FFT_1024        equ 00002000h   ;// of fft data

;// FFT_DATA_SIZE_TEST equ FFT_512 OR FFT_1024  ;// DO NOT CHANGE

;// FFT_INPLACE     equ 00004000h   ;// do operation in place
;// FFT_TRANSFER    equ 00008000h   ;// requires two xtra pointers

    FFT_FORWARD     equ 00000001h
    FFT_REVERSE     equ 00000002h

    FFT_WINDOW      equ 00000010h

;// FFT_REAL_IMAG   equ 00000100h   output is always real imag
;// FFT_MAG         equ 00000200h
;// FFT_MAG2        equ 00000400h
;// FFT_MAG_PHASE   equ 00000800h

;// FFT_OUTPUT_MASK equ NOT(FFT_REAL_IMAG OR FFT_MAG2 OR FFT_MAG OR FFT_MAG_PHASE)

;// FFT_CULL        equ 00010000h
;// FFT_HARMONICS   equ 00020000h


;// interface

    fft_Initialize PROTO
    fft_Destroy PROTO

    fft_Run PROTO   ;//  pData1:DWORD, pData2:DWORD, bOptions:DWORD

;// other fun stuff

;// fft_Cull PROTO
;// fft_HarmonicScan    PROTO


comment ~ /*

    notes:

    try to design this to use stack variables
    method:
            sincos and butter may persist through the first two stages

            use data_size as an iterator (decrease by appropriate amount)

            the create special variables for each function



num points:             512         1024

opt_TEST                1000h       2000h       = bOptions AND FFT_SIZE_TEST

LOADER( sep, count, butter, sincos, ...)

-   sincos step         40h         20h         = 40000h / opt_test
-   butter (A,B)        800h        1000h       = opt_TEST / 2

    data_count          100h        200h        = opt_TEST / 8

    input sep           400h        800h        = butter / 2
    window sep          400h        800h        = same as input sep

    edx points at window

MIDDLE( stages, groups, count, butter, sincos, ... )

-   sincos step         80h         40h         = twice previous
-   butter (A,B)        400h        800h        = half previous

    data_count          1000h       2000h       = butter * 2 (or previous butter)

    num_groups          80h         100h        = data_count / 20h
    num stages          5           6           = log2(groups) - 2

LAST

    data_count          800h        1000h       = opt_test / 2


OUTPUT

    use seperate bit reverse tables


;; on further inspection----
;;  intel's version are 10 to 20% faster, AFTER the first one is called
;;  hypothesis is that they're using some strange sequence oorder
;;  to minimize cache misses



*/ comment ~