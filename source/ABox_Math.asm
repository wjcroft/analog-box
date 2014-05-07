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
;//                 -- added math_bool_X functions
;//                 -- removed math_temp_1 and math_temp_2
;//                 -- enhanced math_pNull with additional math_pPosOne and pNegOne
;//
;//##////////////////////////////////////////////////////////////////////////
;//
;//  ABox_math.asm   creation of math lookup tables and various vector functions
;//
;// TOC
;//
;// build_ramp_wave
;// build_square_wave
;// math_Initialize
;// math_Destroy
;//
;// math_log_lin
;// math_lin_log
;//
;// math_neg_dX
;//
;// math_add_dXdB
;// math_add_dXsB
;// math_sub_dXdB
;// math_sub_dXsB
;// math_sub_sXdB
;// math_mul_dXdA
;// math_mul_dXdA_neg
;// math_mul_dXsA
;// math_mul_dXsA_neg
;//
;// math_muladd_dXdAdB
;// math_muladd_dXdAsB
;// math_muladd_dXsAdB
;// math_muladd_dXsAsB
;//
;// math_ramp
;// math_ramp_add_dB
;// math_ramp_mul_dA
;//
;// math_bool_dX_ft
;// math_bool_and_dXdB_ft
;// math_bool_or_dXdB_ft
;// math_bool_xor_dXdB_ft
;// math_bool_lt_dXdB_ft
;// math_bool_lt_dXsB_ft
;// math_bool_lt_sXdB_ft
;// math_bool_eq_dXdB_ft
;// math_bool_eq_dXsB_ft

OPTION CASEMAP:NONE

.586
.MODEL FLAT

        .NOLIST
        include <Abox.inc>
        include <ABox_Knob.inc>
        include <fft_abox.inc>
        .LIST

;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;///
;///
;///  M A T H E M A T I C A L   F U N C T I O N S
;///
;///     We'll use look-up for all the big functions( sin, exp, log, etc ).
;///     Each function will represent one 'cycle'.
;///     The size of each table is fixed by MATH_TABLE_LENGTH,
;///     representing the number DWORDS, not the number bytes.
;///     See 'Number format:' in the 'N O T E S' section
;///
;///     Each Math Function TABLE gets a pointer.
;///     To help with performance, the allocated memory is 32 byte aligned
;///

;///     addendum: we're going to real4 representation, didn't want to,
;///     but the low frequency resoultion of the 1:0.15 format is unacceptable.
;///        addendum: (heh, the previous addendum is from 1997 -- remove??)

.DATA

;////////////////////////////////////////////////////////////////////
;//
;//
;//     T A B L E S
;//

  ;//
  ;// the tables    all are allocated at math_pSin, then pointers assigned as required
  ;//
  ;// name                    length
  ;// -------------           ------

    math_pSin       dd  0   ; 8192  // pointer to sine table [ 0 : 2pi )
    math_pTri       dd  0   ; 8192  // pointer to triangle table table [ 0 : 2pi )

    math_pRamp1     dd  0   ; 8192  // 24 smooth ramp wave      |
    math_pSquare1   dd  0   ; 8192  // 24 smooth square wave    /
    math_pRamp2     dd  0   ; 8192  // 24 ramp wave         \   coefficients below
    math_pSquare2   dd  0   ; 8192  // 24 square wave       |

    math_pChromatic dd  0   ;  128  // pointer to the chromatic note table (128 values)
    math_pMidiNote  dd  0   ;  128  // pointer to the MidiNote values (128 values)

    math_pNullPin   dd 0    ;   32  // fake APIN pin, useful for adding optional pins
    math_pNull      dd 0    ; 1024  // this is how we terminate pin data to a zero value
    math_pPosOne    dd 0    ; 1024  // used for terminating to +1
    math_pNegOne    dd 0    ; 1024  // this is how we terminate pins

    MATH_TABLE_LENGTH       equ 02000h  ;// = 8192 values
    MATH_TABLE_SIZE         equ MATH_TABLE_LENGTH * 4
    NUMBER_MATH_FUNCTIONS   equ 7 ;// add 1 to encompass all trhe smaller tables after the 6 large tables
    MATH_TABLE_TOTAL_SIZE   equ MATH_TABLE_SIZE * NUMBER_MATH_FUNCTIONS


    ;// coefficients for the 24 harmonic waveforms
    ;// see wave_rms.mcd for derivation
    ;//
    ;// tables are orginazed as size, delta, array of values
    ;// use build_harmonic_wave to process, passing the table pointer in esi

    k2_ramp REAL4   0.559,      0.2795,     0.1863,     0.1398,     0.1118,     0.09317
            REAL4   0.07986,    0.06988,    0.06211,    0.0559,     0.05082,    0.04658
            REAL4   0.043,      0.03993,    0.03727,    0.03494,    0.03288,    0.03106
            REAL4   0.02942,    0.02795,    0.02662,    0.02541,    0.0243,     0.02329

    k1_ramp REAL4   0.7183,     0.3485,     0.2243,     0.1614,     0.1231,     0.09703
            REAL4   0.07805,    0.06354,    0.05207,    0.04281,    0.03521,    0.02892
            REAL4   0.02371,    0.01937,    0.01578,    0.01281,    0.01037,    0.00837
            REAL4   0.006738,   0.005412,   0.00434,    0.003475,   0.002779,   0.002221

    k2_square   REAL4   1.079,      0.3597,     0.2158,     0.1541,     0.1199,     0.09809
                REAL4   0.083,      0.07193,    0.06347,    0.05679,    0.05138,    0.04691

    k1_square   REAL4   1.257,      0.3926,     0.2154,     0.1366,     0.09113,    0.06162
                REAL4   0.04149,    0.02762,    0.01815,    0.01179,    0.007595,   0.004864



;//
;//     T A B L E S
;//
;//
;////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////
;//
;//
;//     C O N S T A N T S
;//


    math_AdrMask2   equ MATH_TABLE_SIZE-1   ;// chops an address

    math_AdrMask    equ MATH_TABLE_SIZE-4   ;// chops and masks to DWORD boundry

    math_NormToOfs  REAL4 16384.0e+0        ;// this scales a number [-1, 1)
                                            ;// to an offset - to pos, the sign bit
                                            ;// automatically wraps for us
    math_OfsToNorm  REAL4 6.103515625e-5    ;// 1/norm_to_ofs

    math_RadToNorm  REAL4 0.318309886e+0    ;// 1/pi, scales a radian [-pi,+pi] to a range of [-1, +1]
    math_RadToOfs   REAL4   5215.189176     ;// 16384/pi multipy radians to get table offset
                                            ;// remember to AND the results with math_AdrMask

    math_NormToOfsPi REAL4 1.917475985E-4   ;// pi/NormToOffset

    ;// normalized value to index conversion

        MATH_INDEX_MASK equ MATH_TABLE_LENGTH-1   ;// chops to an index
        math_TableScale REAL4 4096.000e+0       ;// multiply by [-1,+1) to get an index
                                                ;// AND offset with AdrMask2 to get wrapped index
    ;//
    ;// miscellaneous constants
    ;//
        math_neg_1  REAL4 -1.0e+0
        math_0      REAL4 0.0e+0
        math_neg_1_64   REAL4 -0.015625e+0  ;// 1/64
        math_1_64   REAL4 0.015625e+0   ;// 1/64
        math_1_10   REAL4 0.100000e+0   ;// 1/10
        math_1_4    REAL4 0.25e+0
        math_1_8    REAL4 0.125         ;// 1/8
        math_neg_1_8    REAL4 -0.125         ;// -1/8
        math_1_16   REAL4 0.0625        ;// 1/16

        math_1_2    REAL4 0.5e+0        ;// one half
        math_neg_1_2    REAL4 -0.5e+0       ;// one half
        math_1_6    REAL4 0.166666666e+0;// 1/6
        math_1_3    REAL4 0.333333333e+0;// 1/3
        math_5_6    REAL4 0.833333333e+0;// 5/6
        math_1      REAL4 1.0e+0
        math_2      REAL4 2.0e+0
        math_3      REAL4 3.00e+0
        math_4      REAL4 4.0e+0
        math_10     REAL4 10.0e+0
        math_16     REAL4 16.0e+0
        math_neg_16 REAL4 -16.0
        math_32     REAL4 32.0e+0
        math_1_32   REAL4 0.03125         ;// 1/32
        math_64     REAL4 64.0e+0
        math_100    REAL4 100.0e+0
        math_1000   REAL4 1000.0e+0
        math_1_1000 REAL4 1.0E-3        ;// 1/1000

        math_2_24       REAL4 16777216.0e+0 ;// 2^24 used to convert float to a fraction table pointer
                                            ;// also used to detect when bessel is no longer significant
        math_2_neg_24   REAL4 5.960464478e-8;// 2^-24

        math_44100  REAL4 44100.0e+0
        math_1_44100 REAL4 2.267573696e-5

        math_1_44100_2_24   REAL4   380.435737  ;// 2^24/44100

        math_1_256  REAL4 3.90625E-3    ;// 1/256
        math_1_512  REAL4 1.953125E-3   ;// 1/512
        math_255    REAL4 255.0e+0      ;// 255
        math_256    REAL4 256.0e+0      ;// 256
        math_511    REAL4 511.0e+0
        math_512    REAL4 512.0e+0

        math_65536  REAL4 65536.0   ;// used to get at fractions for fft_op

        math_4_3    REAL4 1.333333333e+0 ;// 4/3

        math_42_2_3 REAL4 42.6666666666666666e+0
        math_6_256  REAL4 0.0234375e+0

        math_1_pi   REAL4 0.318309886E+0    ;// 1/pi
        math_pi     REAL4 3.141592653       ;// pi
        math_pi_2   REAL4 1.570796327       ;// pi / 2
        math_pi_3   REAL4 1.047197551       ;// pi / 3

        math_1_2_1_2 REAL4 0.70710678   ;// 1/sqrt2

    ;//
    ;// constants for accessing normalized lookup tables
    ;//

        math_Million    REAL4 1.0e+6   ;// for scaling fractions to text
        math_Millionth  REAL4 1.0e-6   ;// for preventing underflow -- also used by clock cycle display

        math_OfsQuarter equ MATH_TABLE_LENGTH
        math_OfsHalf    equ MATH_TABLE_LENGTH * 2


        ;//math_dAngle  REAL4 7.669903939e-4  ;// 2*pi/table length
                                              ;// used to iterate around a circle
        math_dAngle REAL8 7.669903939428206E-4  ;// use double presicion to increase accuracy

        math_2dQ        REAL4 4.8828125e-4      ;// iterates from -1 to 1 in TABLE_LENGTH / 2 steps

        math_neg1024    REAL4 -1024.0e+0        ;// used in the delay this is actually -SAMARY_LENGTH
        math_1024       REAL4 1024.0e+0         ;// used for advancing Q
        math_1_1024     REAL4 9.765625e-4       ;// 1/1024

    ;//
    ;// numeric constants for midi
    ;//
        ;// these are used for midiIn and Out, and the slider

        math_128        REAL4 128.0e+0      ;// note scale
        math_1_128      REAL4 7.8125e-3     ;// 1/128, digital slider scale, and delta interpolate
        math_8192       REAL4 8192.0e+0     ;// pitch wheel scale
        math_1_32768    REAL4 3.051757813e-5;// 1/32768
        math_32767      REAL4 32767.0       ;// waveOut_scale REAL4 32767.0e+0  ;// this produces the WORD value samples that
                                            ;// gets stored in a WAVEHDR.pData block of memory
        math_1_16384    REAL4 6.103515625e-5;// 1/16384 used for pitch wheel
        math_2_neg_31   REAL4 4.656612873e-10   ;// 2^-31

        ;// these are used in the pitch quantizer

        math_12     REAL4 12.0e+0               ;// there are 12 notes per octavce
        math_10_2_3 REAL4 10.666666666666e+0    ;// there are 10 and 2/3 octaves
        math_1_10_2_3 REAL4 0.09375e+0          ;// 1/(10&2/3)

        ;// used to generate chromatic table
        ;// and the midi table

        math_cQ2a  REAL4 8.333333333E-2 ;// 1/12

        ;// used to convert dQ to note number

        math_cQ1   REAL4 6.776557586169103E+1   ;// scales frequency and dQ and 440hz

        math_cQ2   REAL4 12.0e+0   ;// = notes per scale
        math_cQ3   REAL4 52.0e+0   ;// = min note offset
        math_cQ7   REAL4 128.0e+0  ;// = range of chromatic notes

        math_INTcQ7  equ 128       ;// = integer for range for checking

    ;//
    ;// used by i to f and f to i
    ;//
        math_if_k1  REAL4 2696.984139104641e+0  ;// = 1/k2
        ;// I = 1/10.66 * log2( F * k1 )

        math_if_k2  REAL4 3.707845313217101E-4  ;// = 440*(2^-69/12)/22050
        ;// F = k2 * 2 ^ ( I * k1 )

    ;// used by tanh

        math_tanh_k REAL4 2.885390082e+0    ;// 2/ln(2)

        math_linear_decay   REAL4   0.023219954 ;// 1024/44100 = 1 range / per second

        math_decay REAL4 0.99e+0    ;// common decay rate for any averaging traces
        math_average REAL4 0.01+0   ;// input scale for any averaging trace

        math_reader_media_scale REAL8   1.844674407370955E+12   ;// 2^64 / 10^7
        math_reader_sample_scale REAL8  4.294967296E+16         ;// 10^7 * 2^32


        math_1_12       REAL4 8.333333333E-2    ;// 1/12
        math_1_1200     REAL4 8.333333333E-4    ;// 1/1200
        math_11_8820    REAL4 1.247165533E-3    ;// 11/8820

;//
;//     C O N S T A N T S
;//
;//
;////////////////////////////////////////////////////////////////////



comment ~ /*
    ;//                 many functions need some temp storage AND the
    ;//  tempStorage    ebp register, so they can't use locals.
    ;//                 use these instead

    AJT ABOX242 -- recipe for disaster to do this with multiple threads
        status: removed

ALIGN 8
    math_temp_1     dd  0

ALIGN 8
    math_temp_2     dd  0
*/ comment ~

  ;//
  ;// functions
  ;//

    math_FormatFloat7Chars PROTO STDCALL pText:dword



.CODE






;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
build_ramp_wave PROC PRIVATE uses ebp

    ;// entering we get

    ASSUME edi:PTR DWORD    ;// edi = where to store                interated
    ASSUME esi:PTR DWORD    ;// esi = ptr to coeeficient table      preserevd
                            ;// the rest are deroyed (except ebp)
    ;// algorithm:
    ;//
    ;// for q = 0 to 2pi in 8192 steps
    ;//     y=0
    ;//     for n = 0 to 23
    ;//
    ;//         qn = n+1
    ;//         y -= k0[n]*sin(q*qn)        minus to get the sign to come out right
    ;//
    ;//     next n
    ;//     store y
    ;// next q

    ;// setup

        mov ebp, math_pSin
        ASSUME ebp:PTR DWORD

        mov ecx, -4096      ;// q_reg, counts table entries
        ASSUME ecx:SDWORD

    .REPEAT     ;// outter loop

        mov ebx, 0  ;// counts coefficient
        fldz        ;// start with zero

        .REPEAT     ;// inner_loop:

            ;// cos of q*n

            lea eax, [ebx+1]    ;// n
            imul ecx                ;// q*n
            and eax, MATH_INDEX_MASK

            ;// y += k0*sin(q*n)

            fld [ebp+eax*4]     ;// sin(qm)
            fmul [esi+ebx*4]    ;// esi
            inc ebx
            fsub

        .UNTIL ebx >= 24    ;// inner loop

        fstp [edi]  ;// store the value
        inc ecx ;// increase q
        add edi, 4  ;// iterate edi

    .UNTIL ecx >= 4096  ;// outter loop

    ret


build_ramp_wave ENDP

ASSUME_AND_ALIGN
build_square_wave PROC PRIVATE uses ebp

    ;// entering we get

    ASSUME edi:PTR DWORD    ;// edi = where to store                interated
    ASSUME esi:PTR DWORD    ;// esi = ptr to coeeficient table      preserevd
                            ;// the rest are deroyed (except ebp)
    ;// algorithm:
    ;//
    ;// for q = 0 to 2pi in 8192 steps
    ;//     y=0
    ;//     for n = 0 to 11
    ;//
    ;//         qn = (n+1)*2 - 1
    ;//         y += k0[n]*sin(q*n)
    ;//
    ;//     next n
    ;//     store y
    ;// next q

    ;// setup

        mov ebp, math_pSin
        ASSUME ebp:PTR DWORD

        xor ecx, ecx    ;// q_reg, counts table entries

    .REPEAT     ;// outter loop

        mov ebx, 0  ;// counts coefficient
        fldz        ;// start with zero

        .REPEAT     ;// inner_loop:

            ;// cos of q*n

            lea eax, [ebx+1]    ;// n+1
            shl eax, 1          ;// 2*(n+1)
            dec eax             ;// 2*(n+1)-1
            mul ecx             ;// q*n
            and eax, MATH_INDEX_MASK

            ;// y += k0*sin(q*n)

            fld [ebp+eax*4]     ;// sin(qm)
            fmul [esi+ebx*4]    ;// esi
            inc ebx
            fadd

        .UNTIL ebx >= 12    ;// inner loop

        fstp [edi]  ;// store the value
        inc ecx ;// increase q
        add edi, 4  ;// iterate edi

    .UNTIL ecx >= MATH_TABLE_LENGTH ;// outter loop

    ret


build_square_wave ENDP








ASSUME_AND_ALIGN
math_Initialize PROC uses esi edi ebx

    ;// fft is initialized seperately

        fninit

        invoke about_SetLoadStatus

        invoke fft_Initialize

    ;// allocate all the tables in one shot

        DEBUG_IF <math_pSin>    ;// already initialized
        invoke memory_Alloc, GPTR, MATH_TABLE_TOTAL_SIZE
        mov edi, eax

        invoke about_SetLoadStatus

    ;// initialize each table section, use edi as an iterator

        ASSUME edi:PTR DWORD

    ;//
    ;// SINE TABLE
    ;//
    ;//  return the sin for Q in the range of [-1 to +1)
    ;//  format as REAL4
    ;//
            mov math_pSin, edi  ;// store

            fld  math_dAngle    ;// for scanning
            fldz                ;// start the angle at zero
            mov  ecx, MATH_TABLE_LENGTH/4

          @@:
            jecxz @F        ;// Ang dAng
            fld   st        ;// Ang Ang     dAng
            fsincos         ;// Sin cos Ang     dAng
            dec   ecx

        ;// DEBUG_IF <ecx==0>

            fst  [edi+MATH_TABLE_LENGTH]    ;// cos sin
            fchs
            fstp  [edi+MATH_TABLE_LENGTH*3] ;// sin
            fst  [edi]
            fchs
            fstp [edi+MATH_TABLE_LENGTH*2]  ;// Q   dQ

            fadd  st, st(1) ;// Ang dAng
            add   edi, 4
            jmp   @B
          @@:

           ;// clean up the FPU
            fstp  st
            fstp st

            add edi, MATH_TABLE_LENGTH*3


    ;//
    ;// TRIANGLE TABLE
    ;//
    ;//  returns a triangle wave for Q in the range of [-1 to +1)
    ;//  format as REAL4
    ;//
        invoke about_SetLoadStatus

            mov math_pTri, edi  ;// store

        ;// ABOX232 adjusted to start at -1/2

            fld math_2dQ    ;// for scanning
            fldz            ;// start the Q at neg 1/2
            mov  ecx, MATH_TABLE_LENGTH
          @@:
            jecxz @F        ;// Q   2dQ
            dec   ecx
            fst  [edi]      ;// Q   2dQ
            fadd  st, st(1) ;// Q   2dQ

            fld st          ;// Q   Q   2dQ
            fabs            ;// |Q| Q   2dQ
            fcom math_1     ;// |Q| Q   2dQ

            fnstsw ax
            sahf
            .IF !CARRY?
                fdiv        ;// +-1 2dQ
                fxch        ;// 2dQ Q
                fchs        ;// -2dQ    Q
                fxch        ;// Q 2dQ
            .ELSE
                fstp st
            .ENDIF
            add   edi, 4
            jmp   @B
          @@:      ;// clean up the FPU
            fstp st
            fstp st

    ;//
    ;// RAMP TABLES
    ;//
    ;//
    ;// two tables to do
    ;//

        invoke about_SetLoadStatus

        mov math_pRamp1, edi
        lea esi, k1_ramp
        call build_ramp_wave

        mov math_pRamp2, edi
        lea esi, k2_ramp
        call build_ramp_wave

    ;//
    ;// SQUARE TABLES
    ;//
    ;//
    ;// two tables to do
    ;//

        invoke about_SetLoadStatus

        mov math_pSquare1, edi
        lea esi, k1_square
        call build_square_wave

        mov math_pSquare2, edi
        lea esi, k2_square
        call build_square_wave

    ;//
    ;// CHROMATIC TABLE
    ;//
    ;//    table is indexed by note number [0:128] or [C-1:G#9]
    ;//    dQ(n) = cQ6 * 2 toThe ( cQ2 * n )
    ;//    it returns the dQ required to get the midi note
    ;//
    ;// initialize the chromatic table
    ;// see Key_02.mcd for details

        invoke about_SetLoadStatus

        mov math_pChromatic, edi

        fld1                ;// 1
        fld math_cQ2a       ;// cQ2 1
        fld math_if_k2      ;// cQ6 cQ2   1
        fldz                ;// n   cQ6   cQ2   1
        xor ecx, ecx

        .WHILE ecx < 128

            fld st          ;// n   n     cQ6   cQ2   1
            fmul st, st(3)  ;// cQ6n    n     cQ6   cQ2
            fld st          ;// cQ6n    cQ6n  n     cQ6   cQ2   1
            fsub math_1_2
            frndint         ;// int cQ6n  n     cQ6   cQ2   1
            fxch            ;// cQ6n    int   n     cQ6   cQ2   1
            fsub st, st(1)  ;// frac    int   n     cQ6   cQ2   1
            f2xm1           ;// 2^f-1 int   n   cQ6   cQ2   1
            fadd st, st(5)  ;// 2^f int   n     cQ6   cQ2   1
            fscale          ;// dq  int   n     cQ6   cQ2   1
            fmul st, st(3)  ;// dQ  int   n     cQ6   cQ2   1
            fstp [edi]      ;// int n     cQ6   cQ2   1
            fstp st         ;// n   cQ6   cQ2   1
            fadd st, st(3)  ;// n   cQ6   cQ2   1

            inc ecx
            add edi, 4

        .ENDW

        fstp st
        fstp st
        fstp st
        fstp st

    ;//
    ;// MIDI NOTE TABLE
    ;//
    ;//    table is indexed by note number [0:128] or [C-1:G#9]
    ;//    it returns the midi note for a given index
    ;//    uses index * midiNoteScale
    ;//

        invoke about_SetLoadStatus

        mov math_pMidiNote, edi

        fld math_1_128      ;// 1/128
        fldz                ;// iter    cQ2
        xor ecx, ecx
        .WHILE ecx < 128

            fst [edi]
            fadd st, st(1)
            inc ecx
            add edi, 4

        .ENDW

        fstp st
        fstp st

    ;//
    ;// NULL PIN
    ;//    NULL DATA
    ;//             used to terminate unconnected inputs

        mov math_pNullPin, edi
        lea edx, [edi+SIZEOF APIN]
        mov math_pNull, edx
        mov (APIN PTR [edi]).pData, edx ;// set data to point at math_pNull, dwstautus is always zero

        ;// pNull was zeroes when it was allocated -- so we don't rezero it here
        lea edi, [edx+SAMARY_SIZE]  ;// iterate to next section

    ;//                        -- ABOX242
    ;//    pPosOne, pNegOne    -- these help with const true/false values
    ;//
        fld1        ;// +1

        mov math_pPosOne, edi
        fst [edi]    ;// +1
        mov ecx, SAMARY_LENGTH
        mov eax, [edi]
        rep stosd

        fchs        ;// -1

        mov math_pNegOne, edi
        fstp [edi]    ;// empty
        mov ecx, SAMARY_LENGTH
        mov eax, [edi]
        rep stosd

    ;// edi is now at end of table

    ;// that's it

    fldcw WORD PTR app_fpu_control


    ret

math_Initialize ENDP


ASSUME_AND_ALIGN
math_Destroy PROC

    invoke fft_Destroy
    invoke memory_Free, math_pSin

    ret

math_Destroy ENDP





;////////////////////////////////////////////////////////////////////
;//
;//
;//     convertion functions
;//



ASSUME_AND_ALIGN
math_log_lin PROC

    ;// this assumes tha fpu is loaded with the value to convert
    ;// the value is assumed to be on a logrithmic surface
    ;// this then converts it to a linear surface
    ;// the scale is always 0=0 and 1=1

    ;// fpu must have the value to convert
    ;//
    ;// in:     fpu=X   requires two extra fpu registers
    ;// out:    fpu=x

    ;// returns with audio tapered value in fpu (replaces)
    ;// and the sign bit set if negative

    ;// formula:  Y = 2^( (|X|-1)*A ) - K
    ;//
    ;// implementation: b=(x-1)*A  X=2^int(b) * 2^fract(b)
    ;//
    ;// this is expensive, don't use very often

        pushd 0
        fst DWORD PTR [esp]

        fabs

        fld1            ;// 1    X
        fxch            ;// X   1
        fsub st, st(1)  ;// X-1 1
        fmul math_10    ;// b   1
        fld  st         ;// b   b   1
        frndint         ;// ib  b   1
        fsub st(1), st  ;// ib   fb 1
        fxch            ;// fb   ib  1
        f2xm1           ;// 2^fb
        or DWORD PTR [esp], 0   ;// check the sign
        faddp st(2), st ;// ib  2^fb
        fxch
        fscale
        fxch
        fstp st
        fsub math_1_1024    ;// nudge back to zero

    ;// check if we were negative

        .IF SIGN?
            fchs
        .ENDIF

        add esp, 4

        ret

math_log_lin ENDP


ASSUME_AND_ALIGN
math_lin_log PROC

    ;// this does the opposite of the above
    ;//
    ;// formula:    X = 1/A * log2( Y+K ) + 1
    ;//             retains the sign of the origonal value

    ;// fpu must have the value to convert
    ;//
    ;// in:     fpu=Y   requires one extra fpu register
    ;// out:    fpu=X

    ;// the scale is always 0=0 and 1=1

    pushd 0
    fst DWORD PTR [esp] ;// store so we can ccheck the sign

    fabs                ;// Y
    fadd math_1_1024    ;// Y+k
    fld math_1_10       ;// 1/10    Y+k
    fxch                ;// Y+k     1/10
    fyl2x               ;// X-1
    or DWORD PTR [esp], 0   ;// check the sign
    fadd math_1     ;// X

    .IF SIGN?
        fchs
    .ENDIF

    add esp, 4          ;// clean up temp

    ret

math_lin_log ENDP




;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////

comment ~ /*

    A R I T M E T I C   F U N C T I O N S

    template            name    function performed
    ------------------  ------  ------------------
    math_add_dXxB       dXdB    Y[] = X[]+B[]
                        dXsB    Y[] = X[]+B
    ------------------  ------  ------------------
    math_sub_xXxB       dXdB    Y[] = X[]-B[]
                        dXsB    Y[] = X[]-B
                        sXdB    Y[] = X - B[]
    ------------------  ------  ------------------
    math_mul_dXxA       dXdA    Y[] = X[]*A[]
                        dXsA    Y[] = X[]*A
    ------------------  ------  ------------------
    math_muladd_dXxAxB  dXdAdB  Y[] = X[]*A[]+B[]
                        dXdAsB  Y[] = X[]*A[]+B
                        dXsAdB  Y[] = X[]*A+B[]
                        dXsAsB  Y[] = X[]*A+B
    ------------------  ------  ------------------
    math_ramp           see implementation way below
    math_ramp_add_dB
    math_ramp_mul_dA

*/ comment ~

;// register calling convetion

    ASSUME esi:PTR DWORD    ;// esi is always X
    ASSUME ebx:PTR DWORD    ;// ebx is always A
    ASSUME edx:PTR DWORD    ;// edx is always B
    ASSUME edi:PTR DWORD    ;// edi is always Y
    ASSUME ebp:PTR DWORD    ;// for routines that need it -- ebp MUST BE PRESERVED !!

    ;// all are always destroyed -- except ebp
    ;// fpu must always be empty (except for ramps, see below)
    ;//
    ;// registers may point to the same memory for inplace operations
    ;// iterative functions (ie esi=0, edi=1) will not work

ALIGN 16
math_neg_dX PROC

    push ebp
    pushd SAMARY_LENGTH / 4

    mov ebp, 80000000h

    jmp enter_loop

    ;// often 3 cycles -- doesn't seem worth it ... when mul by -1 does so well
    .REPEAT
;// control    PIPE0    PIPE4    PIPE8    PIPEC
    add esi, 10h
    add edi, 10h
enter_loop:
            mov eax, [esi+00h]
                    mov ebx, [esi+04h]
            xor eax, ebp
                            mov ecx, [esi+08h]
                    xor ebx, ebp
            mov [edi+00h], eax
                                    mov edx, [esi+0Ch]
                            xor ecx, ebp
                    mov [edi+04h], ebx
                                    xor edx, ebp
    sub DWORD PTR [esp], 1
                            mov [edi+08h], ecx
                                    mov [edi+0Ch], edx
    .UNTIL ZERO?

    add esp, 4
    pop ebp
    retn

math_neg_dX ENDP


ALIGN 16
math_add_dXdB   PROC

    mov ecx, SAMARY_LENGTH*4
    mov eax, 10h
    jmp enter_loop

    .REPEAT

        add edi, eax

    enter_loop:

    ;// load

        fld  [esi]      ;// x0
        fld  [edx]      ;// b0  x0

        fld  [esi+04h]  ;// x1  b0  x0
        fld  [edx+04h]  ;// b1  x1  b0  x0

        fld  [esi+08h]  ;// x2  b1  x1  b0  x0
        fld  [edx+08h]  ;// b2  x2  b1  x1  b0  x0

        fld  [esi+0Ch]  ;// x3  b2  x2  b1  x1  b0  x0
        fld  [edx+0Ch]  ;// b3  x3  b2  x2  b1  x1  b0  x0

    ;// reduce

        fxch st(7)      ;// x0  x3  b2  x2  b1  x1  b0  b3
        faddp st(6),st  ;// x3  b2  x2  b1  x1  y0  b3
        faddp st(6),st  ;// b2  x2  b1  x1  y0  y3
        fadd            ;// y2  b1  x1  y0  y3

        fxch st(2)      ;// x1  b1  y2  y0  y3
        fadd            ;// y1  y2  y0  y3
        fxch st(2)      ;// y0  y2  y1  y3

    ;// store and iterate

        fstp [edi]      ;// y2  y1  y3
        add  esi, eax
        fstp [edi+8]    ;// y1  y3
        add  edx, eax
        fxch            ;// y3  y1
        fstp [edi+0Ch]  ;// y1
        sub  ecx, eax
        fstp [edi+4]    ;//

    .UNTIL ZERO?

    ret

math_add_dXdB   ENDP

ALIGN 16
math_add_dXsB   PROC

    fld [edx]           ;// B
    mov ecx, SAMARY_LENGTH*4
    mov eax, 10h
    jmp enter_loop

    .REPEAT

        add edi, eax

    enter_loop:

    ;// load

        fld  [esi]      ;// x0  B
        fld  [esi+04h]  ;// x1  x0  B
        fld  [esi+08h]  ;// x2  x1  x0  B
        fld  [esi+0Ch]  ;// x3  x2  x1  x0  B

    ;// reduce

        fxch st(4)      ;// B   x2  x1  x0  x3
        fadd st(3), st  ;// B   x2  x1  y0  x3
        fadd st(2), st  ;// B   x2  y1  y0  x3
        fadd st(1), st  ;// B   y2  y1  y0  x3
        fadd st(4), st  ;// B   y2  y1  y0  y3

    ;// store and iterate

        fxch st(3)      ;// y0  y2  y1  B   y3

        fstp [edi]      ;// y2  y1  B   y3
        fstp [edi+8]    ;// y1  B   y3
        add  esi, eax
        fstp [edi+4]    ;// y1  B   y3
        sub  ecx, eax
        fxch            ;// y3  B
        fstp [edi+0Ch]  ;// B

    .UNTIL ZERO?

        fstp st

        ret

math_add_dXsB   ENDP



ALIGN 16
math_sub_dXdB   PROC

    mov ecx, SAMARY_LENGTH*4
    mov eax, 10h
    jmp enter_loop

    .REPEAT

        add edi, eax

    enter_loop:

    ;// load

        fld  [esi]      ;// x0
        fsub [edx]      ;// y0
        fld  [esi+04h]  ;// x1  y0
        fsub [edx+04h]  ;// y1  y0
        fld  [esi+08h]  ;//
        fsub [edx+08h]  ;// y2  y1  y0
        fld  [esi+0Ch]  ;//
        fsub [edx+0Ch]  ;// y3  y2  y1  y0

    ;// store and iterate

        fxch st(3)
        fstp [edi]      ;// y2  y1  y3
        add  esi, eax
        fxch
        fstp [edi+4]    ;// y2  y3
        add  edx, eax
        fstp [edi+08h]  ;// y3
        sub  ecx, eax
        fstp [edi+0Ch]  ;//

    .UNTIL ZERO?

        ret

math_sub_dXdB   ENDP






ALIGN 16
math_sub_dXsB   PROC

    fld [edx]           ;// B
    mov ecx, SAMARY_LENGTH*4
    mov eax, 10h
    jmp enter_loop

    .REPEAT

        add edi, eax

    enter_loop:

    ;// load

        fld  [esi]      ;// x0  B
        fld  [esi+04h]  ;// x1  x0  B
        fld  [esi+08h]  ;// x2  x1  x0  B
        fld  [esi+0Ch]  ;// x3  x2  x1  x0  B

    ;// reduce

        fxch st(4)      ;// B   x2  x1  x0  x3
        fsub st(3), st  ;// B   x2  x1  y0  x3
        fsub st(2), st  ;// B   x2  y1  y0  x3
        fsub st(1), st  ;// B   y2  y1  y0  x3
        fsub st(4), st  ;// B   y2  y1  y0  y3

    ;// store and iterate

        fxch st(3)      ;// y0  y2  y1  B   y3

        fstp [edi]      ;// y2  y1  B   y3
        fstp [edi+8]    ;// y1  B   y3
        add  esi, eax
        fstp [edi+4]    ;// y1  B   y3
        sub  ecx, eax
        fxch            ;// y3  B
        fstp [edi+0Ch]  ;// B

    .UNTIL ZERO?

        fstp st

        ret

math_sub_dXsB   ENDP

ALIGN 16
math_sub_sXdB   PROC

    fld [esi]           ;// X
    mov ecx, SAMARY_LENGTH*4
    mov eax, 10h
    jmp enter_loop

    .REPEAT

        add edi, eax

    enter_loop:

    ;// load

        fld  [edx]      ;// b0  X
        fld  [edx+04h]  ;// b1  b0  X
        fld  [edx+08h]  ;// b2  b1  b0  X
        fld  [edx+0Ch]  ;// b3  b2  b1  b0  X

    ;// reduce

        fxch st(4)      ;// X   b2  b1  b0  b3
        fsubr st(3), st ;// X   b2  b1  y0  b3
        fsubr st(2), st ;// X   b2  y1  y0  b3
        fsubr st(1), st ;// X   y2  y1  y0  b3
        fsubr st(4), st ;// X   y2  y1  y0  y3

    ;// store and iterate

        fxch st(3)      ;// y0  y2  y1  X   y3

        fstp [edi]      ;// y2  y1  X   y3
        fstp [edi+8]    ;// y1  X   y3
        add  edx, eax
        fstp [edi+4]    ;// y1  X   y3
        sub  ecx, eax
        fxch            ;// y3  X
        fstp [edi+0Ch]  ;// X

    .UNTIL ZERO?

        fstp st

        ret

math_sub_sXdB   ENDP

ALIGN 16
math_mul_dXdA   PROC

    mov ecx, SAMARY_LENGTH*4
    mov eax, 10h
    jmp enter_loop

    .REPEAT

        add edi, eax

    enter_loop:

    ;// load and multiply

        fld  [esi]      ;// x0
        ;//fld  [ebx]       ;// a0  x0
        ;//fmul         ;// y0
        fmul [ebx]

        fld  [esi+4]    ;// x1  y0
        ;//fld  [ebx+4] ;// a1  x1  y0
        ;//fmul         ;// y1  y0
        fmul [ebx+4]

        fld  [esi+8]    ;// x2  y1  y0
        ;//fld  [ebx+8] ;// a2  x2  y1  y0
        ;//fmul         ;// y2  y1  y0
        fmul [ebx+8]

        fld  [esi+0Ch]  ;// x3  y2  y1  y0
        ;//fld  [ebx+0Ch]   ;// a3  x3  y2  y1  y0
        ;//fmul         ;// y3  y2  y1  y0
        fmul [ebx+0Ch]

    ;// store and itterate

        fxch st(3)      ;// y0  y2  y1  y3
        fstp [edi]      ;// y2  y1  y3
        add esi, eax
        fxch            ;// y1  y2  y3
        fstp [edi+4]    ;// y2  y3
        add ebx, eax
        fstp [edi+8]    ;// y3
        sub ecx, eax
        fstp [edi+0Ch]  ;//

    .UNTIL ZERO?

    ret

math_mul_dXdA   ENDP

ALIGN 16
math_mul_dXdA_neg   PROC

    mov ecx, SAMARY_LENGTH*4
    mov eax, 10h
    jmp enter_loop

    .REPEAT

        add edi, eax

    enter_loop:

    ;// load and multiply

        fld  [esi]      ;// x0
        ;//fld  [ebx]       ;// a0  x0
        ;//fmul         ;// y0
        fmul [ebx]

        fld  [esi+4]    ;// x1  y0
        ;//fld  [ebx+4] ;// a1  x1  y0
        ;//fmul         ;// y1  y0
        fmul [ebx+4]

        fld  [esi+8]    ;// x2  y1  y0
        ;//fld  [ebx+8] ;// a2  x2  y1  y0
        ;//fmul         ;// y2  y1  y0
        fmul [ebx+8]

        fld  [esi+0Ch]  ;// x3  y2  y1  y0
        ;//fld  [ebx+0Ch]   ;// a3  x3  y2  y1  y0
        ;//fmul         ;// y3  y2  y1  y0
        fmul [ebx+0Ch]

    ;// store and itterate

        fxch st(3)      ;// y0  y2  y1  y3
        fchs
        fstp [edi]      ;// y2  y1  y3
        add esi, eax
        fxch            ;// y1  y2  y3
        fchs
        fstp [edi+4]    ;// y2  y3
        add ebx, eax
        fchs
        fstp [edi+8]    ;// y3
        sub ecx, eax
        fchs
        fstp [edi+0Ch]  ;//

    .UNTIL ZERO?

    ret

math_mul_dXdA_neg   ENDP

ALIGN 16
math_mul_dXsA   PROC

    fld [ebx]           ;// A
    mov ecx, SAMARY_LENGTH*4
    mov eax, 10h
    jmp enter_loop

    .REPEAT

        add edi, eax

    enter_loop:

    ;// load and multiply

        fld  [esi]      ;// x0  A
        fmul st, st(1)  ;// y0  A
        fld  [esi+4]    ;// x1  y0  A
        fmul st, st(2)  ;// y1  y0  A
        fld  [esi+8]    ;// x2  y1  y0  A
        fmul st, st(3)  ;// y2  y1  y0  A
        fld  [esi+0Ch]  ;// x3  y2  y1  y0  A
        fmul st, st(4)  ;// y3  y2  y1  y0  A

    ;// store and itterate

        fxch st(3)      ;// y0  y2  y1  y3  A
        fstp [edi]      ;// y2  y1  y3  A
        fxch            ;// y1  y2  y3  A
        fstp [edi+4]    ;// y2  y3  A
        add esi, eax
        fstp [edi+8]    ;// y3  A
        sub ecx, eax
        fstp [edi+0Ch]  ;//

    .UNTIL ZERO?

        fstp st

        ret


math_mul_dXsA   ENDP

ALIGN 16
math_mul_dXsA_neg   PROC

    fld [ebx]           ;// A
    mov ecx, SAMARY_LENGTH*4
    mov eax, 10h
    fchs
    jmp enter_loop

    .REPEAT

        add edi, eax

    enter_loop:

    ;// load and multiply

        fld  [esi]      ;// x0  A
        fmul st, st(1)  ;// y0  A
        fld  [esi+4]    ;// x1  y0  A
        fmul st, st(2)  ;// y1  y0  A
        fld  [esi+8]    ;// x2  y1  y0  A
        fmul st, st(3)  ;// y2  y1  y0  A
        fld  [esi+0Ch]  ;// x3  y2  y1  y0  A
        fmul st, st(4)  ;// y3  y2  y1  y0  A

    ;// store and itterate

        fxch st(3)      ;// y0  y2  y1  y3  A
        fstp [edi]      ;// y2  y1  y3  A
        fxch            ;// y1  y2  y3  A
        fstp [edi+4]    ;// y2  y3  A
        add esi, eax
        fstp [edi+8]    ;// y3  A
        sub ecx, eax
        fstp [edi+0Ch]  ;//

    .UNTIL ZERO?

        fstp st

        ret


math_mul_dXsA_neg   ENDP








ALIGN 16
math_muladd_dXdAdB  PROC

        mov ecx, SAMARY_LENGTH*4
        mov eax, 10h
        jmp enter_loop

    .REPEAT

        add edi, eax

    enter_loop:

    ;// three cache misses

        fld   [esi]     ;// x0
        fld   [ebx]     ;// a0  x0
        fld   [edx]     ;// b0  a0  x0
        fxch  st(2)     ;// x0  a0  b0
        fmul            ;// ax0 b0

    ;// three in the cache

        fld   [esi+04h] ;// x1  ax0 b0
        fld   [ebx+04h] ;// a1  x1  ax0 b0
        fld   [edx+04h] ;// b1  a1  x1  ax0 b0
        fxch  st(2)     ;// x1  a1  b1  ax0 b0
        fmul            ;// ax1 b1  ax0 b0

    ;// three more in the cache

        fld   [esi+08h] ;// x2  ax1 b1  ax0 b0
        fld   [ebx+08h] ;// a2  x2  ax1 b1  ax0 b0
        fld   [edx+08h] ;// b2  a2  x2  ax1 b1  ax0 b0
        fxch  st(2)     ;// x2  a2  b2  ax1 b1  ax0 b0
        fmul            ;// ax2 b2  ax1 b1  ax0 b0

    ;// three more in the cache and reduce

        fld   [esi+0Ch] ;// x3  ax2 b2  ax1 b1  ax0 b0
        fxch  st(6)     ;// b0  ax2 b2  ax1 b1  ax0 x3
        faddp st(5), st ;// ax2 b2  ax1 b1  y0  x3

        fld   [edx+0Ch] ;// b3  ax2 b2  ax1 b1  y0  x3
        fxch  st(3)     ;// ax1 ax2 b2  b3  b1  y0  x3
        faddp st(4), st ;// ax2 b2  b3  y1  y0  x3
        fld   [ebx+0Ch] ;// a3  ax2 b2  b3  y1  y0  x3
        fxch            ;// ax2 a3  b2  b3  y1  y0  x3
        faddp st(2), st ;// a3  y2  b3  y1  y0  x3
        fmulp st(5), st ;// y2  b3  y1  y0  ax3
        fxch  st(3)     ;// y0  b3  y1  y2  ax3

    ;// store and iterate

        fstp [edi]      ;// b3  y1  y2  ax3
        add esi, eax
        fxch            ;// y1  b3  y2  ax3
        fstp [edi+04h]  ;// b3  y2  ax3
        add ebx, eax
        faddp st(2), st ;// y2  y3
        add edx, eax
        fstp [edi+08h]  ;// y3
        sub ecx, eax
        fstp [edi+0Ch]

    .UNTIL ZERO?

        ret

math_muladd_dXdAdB  ENDP


ALIGN 16
math_muladd_dXdAsB  PROC

        fld [edx]       ;// B
        mov ecx, SAMARY_LENGTH*4
        mov eax, 10h
        jmp enter_loop

    .REPEAT

        add edi, eax

    enter_loop:

    ;// two cache misses

        fld   [esi]     ;// x0  B
        fld   [eBx]     ;// a0  x0  B
        fmul            ;// ax0 B

    ;// two in the cache

        fld   [esi+04h] ;// x1  ax0 B
        fld   [eBx+04h] ;// a1  x1  ax0 B
        fmul            ;// ax1 ax0 B

    ;// two more in the cache

        fld   [esi+08h] ;// x2  ax1 ax0 B
        fld   [eBx+08h] ;// a2  x2  ax1 ax0 B
        fmul            ;// ax2 ax1 ax0 B

    ;// two mBre in the cache

        fld   [esi+0Ch] ;// x3  ax2 ax1 ax0 B
        fld   [eBx+0Ch] ;// a3  x3  ax2 ax1 ax0 B
        fmul            ;// ax3 ax2 ax1 ax0 Bfx

    ;// reduce

        fxch st(4)      ;// B   ax2 ax1 ax0 ax3
        fadd st(3), st  ;// B   ax2 ax1 y0  ax3
        fadd st(2), st  ;// B   ax2 y1  y0  ax3
        fadd st(1), st  ;// B   y2  y1  y0  ax3
        fadd st(4), st  ;// B   y2  y1  y0  y3

    ;// stBre and iterate

        fxch st(3)      ;// y0  y2  y1  B   y3
        fstp [edi]      ;// y2  y1  B   y3
        add esi, eax
        fxch            ;// y1  y2  B   y3
        fstp [edi+04h]  ;// y2  B   y3
        add eBx, eax    ;// y2  B   y3
        fstp [edi+08h]  ;// B   y3
        suB ecx, eax
        fxch
        fstp [edi+0Ch]

    .UNTIL ZERO?

        fstp st

        ret

math_muladd_dXdAsB  ENDP


ALIGN 16
math_muladd_dXsAdB  PROC

        fld [ebx]       ;// A
        mov ecx, SAMARY_LENGTH*4
        mov eax, 10h
        jmp enter_loop

    .REPEAT

        add edi, eax

    enter_loop:

    ;// two cache misses

        fld   [esi]     ;// x0  A
        fld   [edx]     ;// b0  x0  A
        fxch            ;// x0  b0  A
        fmul st, st(2)  ;// ax0 b0  A

    ;// two in the cache

        fld   [esi+04h] ;// x1  ax0 b0  A
        fld   [edx+04h] ;// b1  x1  ax0 b0  A
        fxch            ;// x1  b1  ax0 b0  A
        fmul st, st(4)  ;// ax1 b1  ax0 b0  A

    ;// two more in the cache

        fld   [esi+08h] ;// x2  ax1 b1  ax0 b0  A
        fld   [edx+08h] ;// b2  x2  ax1 b1  ax0 b0  A
        fxch            ;// x2  b2  ax1 b1  ax0 b0  A
        fmul st, st(6)  ;// ax2 b2  ax1 b1  ax0 b0  A

    ;// two more in cahe and reduce

        fxch st(5)      ;// b0  b2  ax1 b1  ax0 ax2 A
        faddp st(4), st ;// b2  ax1 b1  y0  ax2 A

        fld [esi+0Ch]   ;// x3  b2  ax1 b1  y0  ax2 A
        fld [edx+0ch]   ;// b3  x3  b2  ax1 b1  y0  ax2 A
        fxch            ;// x3  b3  b2  ax1 b1  y0  ax2 A
        fmul st, st(7)  ;// ax3 b3  b2  ax1 b1  y0  ax2 A
        fxch st(3)      ;// ax1 b3  b2  ax3 b1  y0  ax2 A
        faddp st(4), st ;// b3  b2  ax3 y1  y0  ax2 A
        fxch            ;// b2  b3  ax3 y1  y0  ax2 A
        faddp st(5), st ;// b3  ax3 y1  y0  y2  A
        fadd            ;// y3  y1  y0  y2  A
        fxch st(2)      ;// y0  y1  y3  y2  A

    ;// store and iterate

        fstp [edi]      ;// y1  y3  y2  A
        add esi, eax
        fstp [edi+04h]  ;// y3  y2  A
        add edx, eax
        fxch
        fstp [edi+08h]  ;// y3  A
        sub ecx, eax
        fstp [edi+0Ch]

    .UNTIL ZERO?

        fstp st

        ret

math_muladd_dXsAdB  ENDP

ALIGN 16
math_muladd_dXsAsB  PROC

        fld [edx]       ;// B
        mov ecx, SAMARY_LENGTH*4
        fld [ebx]       ;// A   B
        mov eax, 10h
        jmp enter_loop

    .REPEAT

        add edi, eax

    enter_loop:

        fld  [esi]      ;// x0  A   B
        fld  [esi+04h]  ;// x1  x0  A   B
        fld  [esi+08h]  ;// x2  x1  x0  A   B
        fld  [esi+0Ch]  ;// x3  x2  x1  x0  A   B

        fxch st(4)      ;// A   x2  x1  x0  x3  B
        fmul st(3), st  ;// A   x2  x1  ax0 x3  B
        fmul st(2), st  ;// A   x2  ax1 ax0 x3  B
        fmul st(1), st  ;// A   ax2 ax1 ax0 x3  B
        fmul st(4), st  ;// A   ax2 ax1 ax0 ax3 B

        fxch st(5)      ;// B ax2 ax1 ax0 ax3 A
        fadd st(3), st  ;// B ax2 ax1 y0    ax3 A
        fadd st(2), st  ;// B ax2 y1    y0  ax3 A
        fadd st(1), st  ;// B y2    y1  y0  ax3 A
        fadd st(4), st  ;// B y2    y1  y0  y3  A

        fxch st(3)      ;// y0  y2  y1  B y3    A
        fstp [edi]      ;// y2  y1  B y3    A
        fxch            ;// y1  y2  B y3    A
        fstp [edi+4]    ;// y2  B y3    A

        add esi, eax

        fstp [edi+8]    ;// B y3    A
        fxch
        sub ecx, eax
        fstp [edi+0Ch]  ;// B A
        fxch

    .UNTIL ZERO?

        fstp st
        fstp st

        ret


math_muladd_dXsAsB  ENDP



comment ~ /*

    ramp function

    FPU must be load as ;// stop    start

    edi must be destination pointer

    iterates four values at a time

*/ comment ~





ALIGN 16
math_ramp PROC

                            ;// stop    start
        fsub st, st(1)      ;// delta   start
        fmul math_1_1024    ;// dR  start
        fxch                ;// start   dR
        fadd st, st(1)      ;// r0  dr
        fld st              ;// r0  r0  dr
        fadd st, st(2)      ;// r1  r0  dr

        fld st              ;// r1  r1  r0  dr
        fadd st, st(3)      ;// r2  r1  r0  dr

        fxch                ;// r1  r2  r0
        fld st(1)           ;// r2  r1  r2  r0  dr
        fadd st, st(4)      ;// r3  r1  r2  r0  dr
        fxch st(3)          ;// r0  r1  r2  r3  dr

        fld math_4          ;// 4   r0  r1  r2  r3  dr
        fmulp st(5), st     ;// r0  r1  r2  r3  4dr

        mov ecx, SAMARY_LENGTH/4-1
        mov eax, 10h

    top_of_pump:
                            ;// r0  r1  r2  r3  4dr
        fst [edi]
        fadd st, st(4)      ;// R0  r1  r2  r3  4dr
        fxch                ;// r1  R0  r2  r3  4dr

        fst [edi+4]
        fadd st, st(4)      ;// R1  R0  r2  r3  4dr
        fxch st(2)          ;// r2  R0  R1  r3  4dr

        fst [edi+8]
        fadd st, st(4)      ;// R2  R0  R1  r3  4dr
        fxch st(3)          ;// r3  R0  R1  R2  4dr

        fst [edi+12]
        fadd st, st(4)      ;// R3  R0  R1  R2  4dr

        fxch st(3)          ;// R2  R0  R1  R3  4dr
        add edi, eax
        fxch st(2)          ;// R1  R0  R2  R3  4dr
        dec ecx
        fxch                ;// R0  R1  R2  R3  4dr

        jnz top_of_pump

    ;// exit_pump:

        fstp [edi]
        fstp [edi+4]
        fstp [edi+8]
        fstp [edi+12]
        fstp st

        ret

math_ramp ENDP



ALIGN 16
math_ramp_add_dB PROC

                            ;// stop    start
        fsub st, st(1)      ;// delta   start
        fmul math_1_1024;// dR  start
        fxch            ;// start   dR
        fadd st, st(1)  ;// r0  dr
        fld st          ;// r0  r0  dr
        fadd st, st(2)  ;// r1  r0  dr

        fld st          ;// r1  r1  r0  dr
        fadd st, st(3)  ;// r2  r1  r0  dr

        fxch            ;// r1  r2  r0
        fld st(1)       ;// r2  r1  r2  r0  dr
        fadd st, st(4)  ;// r3  r1  r2  r0  dr
        fxch st(3)      ;// r0  r1  r2  r3  dr

        fld math_4  ;// 4   r0  r1  r2  r3  dr
        fmulp st(5), st ;// r0  r1  r2  r3  4dr

        mov ecx, SAMARY_LENGTH/4
        mov eax, 10h

    top_of_pump:

        fld [edx]       ;// b0  r0  r1  r2  r3  4dr
        fadd st, st(1)  ;// B0  r0  r1  r2  r3  4dr

        fld st(5)       ;// 4dr B0  r0  r1  r2  r3  4dr
        faddp st(2), st ;// B0  R0  r1  r2  r3  4dr

        fld [edx+4]     ;// b1  B0  R0  r1  r2  r3  4dr
        fadd st, st(3)  ;// B1  B0  R0  r1  r2  r3  4dr

        fld st(6)       ;// 4dr B1  B0  R0  r1  r2  r3  4dr
        faddp st(4), st ;// B1  B0  R0  R1  r2  r3  4dr

        fld [edx+8]     ;// b2  B1  B0  R0  R1  r2  r3  4dr
        fadd st, st(5)  ;// B2  B1  B0  R0  R1  r2  r3  4dr
        fxch st(2)      ;// B0  B1  B2  R0  R1  r2  r3  4dr
        fstp [edi]      ;// B1  B2  R0  R1  r2  r3  4dr

        fld st(6)       ;// 4dr B1  B2  R0  R1  r2  r3  4dr
        faddp st(5), st ;// B1  B2  R0  R1  R2  r3  4dr

        fld [edx+12]    ;// b3  B1  B2  R0  R1  R2  r3  4dr
        fadd st, st(6)  ;// B3  B1  B2  R0  R1  R2  r3  4dr
        fxch            ;// B1  B3  B2  R0  R1  R2  r3  4dr
        fstp [edi+4]    ;// B3  B2  R0  R1  R2  r3  4dr

        fld st(6)       ;// 4dr B3  B2  R0  R1  R2  r3  4dr
        faddp st(6), st ;// B3  B2  R0  R1  R2  R3  4dr

        fxch            ;// B2  B3  R0  R1  R2  R3  4dr
        fstp [edi+8]    ;// B3  R0  R1  R2  R3  4dr
        fstp [edi+12]   ;// R0  R1  R2  R3  4dr

        add edx, 10h
        add edi, 10h
        dec ecx
        jnz top_of_pump

    ;//exit_pump

        fstp st
        fstp st
        fstp st
        fstp st
        fstp st

        ret

math_ramp_add_dB ENDP

ALIGN 16
math_ramp_mul_dA PROC


                            ;// stop    start
        fsub st, st(1)      ;// delta   start
        fmul math_1_1024;// dR  start
        fxch            ;// start   dR
        fadd st, st(1)  ;// r0  dr
        fld st          ;// r0  r0  dr
        fadd st, st(2)  ;// r1  r0  dr

        fld st          ;// r1  r1  r0  dr
        fadd st, st(3)  ;// r2  r1  r0  dr

        fxch            ;// r1  r2  r0
        fld st(1)       ;// r2  r1  r2  r0  dr
        fadd st, st(4)  ;// r3  r1  r2  r0  dr
        fxch st(3)      ;// r0  r1  r2  r3  dr

        fld math_4  ;// 4   r0  r1  r2  r3  dr
        fmulp st(5), st ;// r0  r1  r2  r3  4dr

        mov ecx, SAMARY_LENGTH/4
        mov eax, 10h

    top_of_pump:

        fld [ebx]       ;// b0  r0  r1  r2  r3  4dr
        fmul st, st(1)  ;// B0  r0  r1  r2  r3  4dr

        fld st(5)       ;// 4dr B0  r0  r1  r2  r3  4dr
        faddp st(2), st ;// B0  R0  r1  r2  r3  4dr

        fld [ebx+4]     ;// b1  B0  R0  r1  r2  r3  4dr
        fmul st, st(3)  ;// B1  B0  R0  r1  r2  r3  4dr

        fld st(6)       ;// 4dr B1  B0  R0  r1  r2  r3  4dr
        faddp st(4), st ;// B1  B0  R0  R1  r2  r3  4dr

        fld [ebx+8]     ;// b2  B1  B0  R0  R1  r2  r3  4dr
        fmul st, st(5)  ;// B2  B1  B0  R0  R1  r2  r3  4dr
        fxch st(2)      ;// B0  B1  B2  R0  R1  r2  r3  4dr
        fstp [edi]      ;// B1  B2  R0  R1  r2  r3  4dr

        fld st(6)       ;// 4dr B1  B2  R0  R1  r2  r3  4dr
        faddp st(5), st ;// B1  B2  R0  R1  R2  r3  4dr

        fld [ebx+12]    ;// b3  B1  B2  R0  R1  R2  r3  4dr
        fmul st, st(6)  ;// B3  B1  B2  R0  R1  R2  r3  4dr
        fxch            ;// B1  B3  B2  R0  R1  R2  r3  4dr
        fstp [edi+4]    ;// B3  B2  R0  R1  R2  r3  4dr

        fld st(6)       ;// 4dr B3  B2  R0  R1  R2  r3  4dr
        faddp st(6), st ;// B3  B2  R0  R1  R2  R3  4dr

        fxch            ;// B2  B3  R0  R1  R2  R3  4dr
        fstp [edi+8]    ;// B3  R0  R1  R2  R3  4dr
        fstp [edi+12]   ;// R0  R1  R2  R3  4dr

        add ebx, 10h
        add edi, 10h
        dec ecx
        jnz top_of_pump

    ;//exit_pump

        fstp st
        fstp st
        fstp st
        fstp st
        fstp st

        ret

math_ramp_mul_dA ENDP




;////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////
;//
;//        boolean functions
;//        FPU MUST HOLD false,true -- will be destroyed



ALIGN 16
math_bool_dX_ft PROC

    push ebp

    mov eax, esp

    and esp, NOT 7    ;// 8 byte align
    sub esp, 8
    fxch                    ;// true false
    fstp DWORD PTR [esp]    ;// false
    sub esp, 8
    fstp DWORD PTR [esp]    ;// empty
    push eax    ;// save orig esp


    ;//stack    esp false true ... ebp ret
    ;//            00  04    0C

    st_table TEXTEQU <(DWORD PTR [esp+04h])>

    ;// a value is 'true' iff the sign bit is set
    ;// all other values are false

        xor ecx, ecx

    .REPEAT

        mov eax, [esi+ecx*4+00h]
        mov edx, [esi+ecx*4+04h]
        mov ebx, [esi+ecx*4+08h]
        mov ebp, [esi+ecx*4+0Ch]

        shr eax,31
        shr edx,31
        shr ebx,31
        shr ebp,31

        mov eax, st_table[eax*8]
        mov edx, st_table[edx*8]
        mov ebx, st_table[ebx*8]
        mov ebp, st_table[ebp*8]

        mov [edi+ecx*4+00h], eax
        mov [edi+ecx*4+04h], edx
        mov [edi+ecx*4+08h], ebx
        mov [edi+ecx*4+0Ch], ebp

        add ecx, 4
        cmp ecx, SAMARY_LENGTH

    .UNTIL !CARRY?

    mov esp, DWORD PTR [esp]
    pop ebp
    retn

    st_table TEXTEQU <>

math_bool_dX_ft ENDP


ALIGN 16
math_bool_and_dXdB_ft PROC

    push ebp

    mov eax, esp

    and esp, NOT 7    ;// 8 byte align
    sub esp, 8
    fxch                    ;// true false
    fstp DWORD PTR [esp]    ;// false
    sub esp, 8
    fstp DWORD PTR [esp]    ;// empty

    pushd SAMARY_LENGTH / 4        ;// number of loop iterations
    push eax    ;// save orig esp

    ;//stack    esp count false true ... ebp ret
    ;//            00  04    08    10

    st_count TEXTEQU <(DWORD PTR [esp+04h])>
    st_table TEXTEQU <(DWORD PTR [esp+08h])>

    mov  ebp, edx    ;// edx is B input

    ;// a value is 'true' iff the sign bit is set
    ;// all other values are false

    jmp enter_loop

    .REPEAT

        add esi, 10h
        add ebp, 10h
        add edi, 10h

    enter_loop:

        mov eax, [esi+00h]
        mov ebx, [esi+04h]
        mov ecx, [esi+08h]
        mov edx, [esi+0Ch]

        and eax, [ebp+00h]
        and ebx, [ebp+04h]
        and ecx, [ebp+08h]
        and edx, [ebp+0Ch]

        shr eax, 31
        shr ebx, 31
        shr ecx, 31
        shr edx, 31

        mov eax, st_table[eax*8]
        mov ebx, st_table[ebx*8]
        mov ecx, st_table[ecx*8]
        mov edx, st_table[edx*8]

        sub st_count, 1

        mov [edi+00h], eax
        mov [edi+04h], ebx
        mov [edi+08h], ecx
        mov [edi+0Ch], edx

    .UNTIL ZERO?

    mov esp, DWORD PTR [esp]
    pop ebp        ;// restore ebp
    retn

    st_count TEXTEQU <>
    st_table TEXTEQU <>

math_bool_and_dXdB_ft ENDP

ALIGN 16
math_bool_or_dXdB_ft PROC

    push ebp

    mov eax, esp

    and esp, NOT 7    ;// 8 byte align
    sub esp, 8
    fxch                    ;// true false
    fstp DWORD PTR [esp]    ;// false
    sub esp, 8
    fstp DWORD PTR [esp]    ;// empty

    pushd SAMARY_LENGTH / 4        ;// number of loop iterations
    push eax    ;// save orig esp

    ;//stack    esp count false true ... ebp ret
    ;//            00  04    08    10

    st_count TEXTEQU <(DWORD PTR [esp+04h])>
    st_table TEXTEQU <(DWORD PTR [esp+08h])>

    mov  ebp, edx    ;// edx is B input
    ;// a value is 'true' iff the sign bit is set
    ;// all other values are false

    jmp enter_loop

    .REPEAT

        add esi, 10h
        add ebp, 10h
        add edi, 10h

    enter_loop:

        mov eax, [esi+00h]
        mov ebx, [esi+04h]
        mov ecx, [esi+08h]
        mov edx, [esi+0Ch]

        or eax, [ebp+00h]
        or ebx, [ebp+04h]
        or ecx, [ebp+08h]
        or edx, [ebp+0Ch]

        shr eax, 31
        shr ebx, 31
        shr ecx, 31
        shr edx, 31

        mov eax, st_table[eax*8]
        mov ebx, st_table[ebx*8]
        mov ecx, st_table[ecx*8]
        mov edx, st_table[edx*8]

        sub st_count, 1

        mov [edi+00h], eax
        mov [edi+04h], ebx
        mov [edi+08h], ecx
        mov [edi+0Ch], edx

    .UNTIL ZERO?

    mov esp, DWORD PTR [esp]
    pop ebp        ;// restore ebp
    retn

    st_count TEXTEQU <>
    st_table TEXTEQU <>

math_bool_or_dXdB_ft ENDP

ALIGN 16
math_bool_xor_dXdB_ft PROC

    push ebp

    mov eax, esp

    and esp, NOT 7    ;// 8 byte align
    sub esp, 8
    fxch                    ;// true false
    fstp DWORD PTR [esp]    ;// false
    sub esp, 8
    fstp DWORD PTR [esp]    ;// empty

    pushd SAMARY_LENGTH / 4        ;// number of loop iterations
    push eax    ;// save orig esp

    ;//stack    esp count false true ... ebp ret
    ;//            00  04    08    10

    st_count TEXTEQU <(DWORD PTR [esp+04h])>
    st_table TEXTEQU <(DWORD PTR [esp+08h])>

    mov  ebp, edx    ;// edx is B input

    ;// a value is 'true' iff the sign bit is set
    ;// all other values are false

    jmp enter_loop

    .REPEAT

        add esi, 10h
        add ebp, 10h
        add edi, 10h

    enter_loop:

        mov eax, [esi+00h]
        mov ebx, [esi+04h]
        mov ecx, [esi+08h]
        mov edx, [esi+0Ch]

        xor eax, [ebp+00h]
        xor ebx, [ebp+04h]
        xor ecx, [ebp+08h]
        xor edx, [ebp+0Ch]

        shr eax, 31
        shr ebx, 31
        shr ecx, 31
        shr edx, 31

        mov eax, st_table[eax*8]
        mov ebx, st_table[ebx*8]
        mov ecx, st_table[ecx*8]
        mov edx, st_table[edx*8]

        sub st_count, 1

        mov [edi+00h], eax
        mov [edi+04h], ebx
        mov [edi+08h], ecx
        mov [edi+0Ch], edx

    .UNTIL ZERO?

    mov esp, DWORD PTR [esp]
    pop ebp        ;// restore ebp
    retn

    st_count TEXTEQU <>
    st_table TEXTEQU <>

math_bool_xor_dXdB_ft ENDP



ALIGN 16
math_bool_lt_dXdB_ft PROC

    push ebp
    mov eax, esp
    and esp, NOT 7    ;// 8 byte align
    sub esp, 8
    ;// for this table we store false at the top
    fstp DWORD PTR [esp]    ;// true
    sub esp, 8
    fstp DWORD PTR [esp]    ;// empty
    pushd SAMARY_LENGTH / 4        ;// number of loop iterations
    push eax    ;// save orig esp
    ;//stack    esp count false true ... ebp ret
    ;//            00  04    08    10
    st_count TEXTEQU <(DWORD PTR [esp+04h])>
    st_table TEXTEQU <(DWORD PTR [esp+08h])>

    mov  ebp, edx    ;// edx is B input

    jmp enter_loop

;// with this scheduling, time is as low as 12-13 cycles on P4

    .REPEAT
;// ctrl    PIPE0        PIPE4        PIPE8        PIPEC
    add ebp, 10h
    add esi, 10h
    add edi, 10h
enter_loop:
            fld [ebp+00h]
            fld [esi+00h]
            xor eax, eax
            fucompp
            fnstsw ax
                        fld [ebp+04h]
                        fld [esi+04h]
            sahf
                        fucompp
            sbb edx, edx
                        xor eax, eax
                        fnstsw ax
                                    fld [ebp+08h]
                                    fld [esi+08h]
                        sahf
                                    fucompp
                        sbb ecx, ecx
                                    xor eax, eax
                                    fnstsw ax
                                                fld [ebp+0Ch]
                                                fld [esi+0Ch]
                                    sahf
                                                fucompp
                                    sbb ebx, ebx
                                                xor eax, eax
                                                fnstsw ax

                                                sahf
                                                sbb eax, eax
            mov edx, st_table[8+edx*8]
                        mov ecx, st_table[8+ecx*8]
                                    mov ebx, st_table[8+ebx*8]
                                                mov eax, st_table[8+eax*8]
    sub st_count, 1
            mov [edi+00h], edx
                        mov [edi+04h], ecx
                                    mov [edi+08h], ebx
                                                mov [edi+0Ch], eax
;// ctrl    PIPE0        PIPE4        PIPE8        PIPEC
    .UNTIL ZERO?

    mov esp, DWORD PTR [esp]
    pop ebp
    retn

    st_count TEXTEQU <>
    st_table TEXTEQU <>

math_bool_lt_dXdB_ft ENDP

ALIGN 16
math_bool_lt_dXsB_ft PROC

    push ebp
    mov eax, esp
    and esp, NOT 7    ;// 8 byte align
    sub esp, 8
    ;// for this table we store false at the top
    fstp DWORD PTR [esp]    ;// true
    sub esp, 8
    fstp DWORD PTR [esp]    ;// empty
    push eax    ;// save orig esp
    ;//stack    esp false true ... ebp ret
    ;//            00  04    0C
    st_table TEXTEQU <(DWORD PTR [esp+04h])>
    mov ebp, SAMARY_LENGTH / 4        ;// number of loop iterations
    fld [edx]    ;// ld the static value
    jmp enter_loop

;// with this scheduling, time is as low as 11-12 cycles on P4
;// almost doesn't seem worth the extra fuss -- but the high range is lower ...

    .REPEAT
;// ctrl    PIPE0        PIPE4        PIPE8        PIPEC
    add esi, 10h
    add edi, 10h
enter_loop:
            fld [esi+00h]
            xor eax, eax
            fucomp
            fnstsw ax
                        fld [esi+04h]
            sahf
                        fucomp
            sbb edx, edx
                        xor eax, eax
                        fnstsw ax
                                    fld [esi+08h]
                        sahf
            mov edx, st_table[8+edx*8]
                                    fucomp
                        sbb ecx, ecx
                                    xor eax, eax
                                    fnstsw ax
                                                fld [esi+0Ch]
                                    sahf
            mov [edi+00h], edx
                        mov ecx, st_table[8+ecx*8]
                                                fucomp
                                    sbb ebx, ebx
                                                xor eax, eax
                                                fnstsw ax
                        mov [edi+04h], ecx
                                                sahf
                                                sbb eax, eax
                                    mov ebx, st_table[8+ebx*8]
    sub ebp, 1
                                                mov eax, st_table[8+eax*8]
                                    mov [edi+08h], ebx
                                                mov [edi+0Ch], eax
;// ctrl    PIPE0        PIPE4        PIPE8        PIPEC
    .UNTIL ZERO?

    mov esp, DWORD PTR [esp]
    fstp st
    pop ebp
    retn

    st_table TEXTEQU <>

math_bool_lt_dXsB_ft ENDP

ALIGN 16
math_bool_lt_sXdB_ft PROC

    push ebp
    mov eax, esp
    and esp, NOT 7    ;// 8 byte align
    sub esp, 8
    ;// for this table we store false at the top
    fstp DWORD PTR [esp]    ;// true
    sub esp, 8
    fstp DWORD PTR [esp]    ;// empty
    push eax    ;// save orig esp
    ;//stack    esp false true ... ebp ret
    ;//            00  04    0C
    st_table TEXTEQU <(DWORD PTR [esp+04h])>

    fld [esi]    ;// ld the static value

    mov ebp, SAMARY_LENGTH / 4        ;// number of loop iterations

    mov esi, edx    ;// esi has to scan the other value

    jmp enter_loop

;// with this scheduling, time is as low as 11-12 cycles on P4
;// almost doesn't seem worth the extra fuss -- but the high range is lower ...

    .REPEAT
;// ctrl    PIPE0        PIPE4        PIPE8        PIPEC
    add esi, 10h
    add edi, 10h
enter_loop:
            fld [esi+00h]
            fld st(1)
            xor eax, eax
            fucompp
            fnstsw ax
                        fld [esi+04h]
                        fld st(1)
            sahf
                        fucompp
            sbb edx, edx
                        xor eax, eax
                        fnstsw ax
                                    fld [esi+08h]
                                    fld st(1)
                        sahf
            mov edx, st_table[8+edx*8]
                                    fucompp
                        sbb ecx, ecx
                                    xor eax, eax
                                    fnstsw ax
                                                fld [esi+0Ch]
                                                fld st(1)
                                    sahf
            mov [edi+00h], edx
                        mov ecx, st_table[8+ecx*8]
                                                fucompp
                                    sbb ebx, ebx
                                                xor eax, eax
                                                fnstsw ax
                        mov [edi+04h], ecx
                                                sahf
                                                sbb eax, eax
                                    mov ebx, st_table[8+ebx*8]
    sub ebp, 1
                                                mov eax, st_table[8+eax*8]
                                    mov [edi+08h], ebx
                                                mov [edi+0Ch], eax
;// ctrl    PIPE0        PIPE4        PIPE8        PIPEC
    .UNTIL ZERO?

    mov esp, DWORD PTR [esp]
    fstp st
    pop ebp
    retn

    st_table TEXTEQU <>

math_bool_lt_sXdB_ft ENDP


ALIGN 16
math_bool_eq_dXdB_ft PROC

    push ebp
    mov eax, esp
    and esp, NOT 7    ;// 8 byte align
    sub esp, 8
    ;// for this table we store true at the top
    fxch
    fstp DWORD PTR [esp]    ;// false
    sub esp, 8
    fstp DWORD PTR [esp]    ;// empty
    pushd SAMARY_LENGTH / 4    ;// number of loop iterations
    push eax    ;// save orig esp
    ;//stack    esp count false true ... ebp ret
    ;//            00  04    08    10
    st_count TEXTEQU <(DWORD PTR [esp+04h])>
    st_table TEXTEQU <(DWORD PTR [esp+08h])>

    mov  ebp, edx    ;// edx is B input

    jmp enter_loop

    ;// min 6 - 7 cyles
    .REPEAT

    add esi,10h
    add ebp,10h
    add edi,10h

enter_loop:

            mov eax, [esi+00h]
            xor edx, edx
            cmp eax, [ebp+00h]
            setz dl
                    mov eax, [esi+04h]
                    xor ecx, ecx
                    cmp eax, [ebp+04h]
                    setz cl
            mov edx, st_table[edx*8]
                            mov eax, [esi+08h]
                            xor ebx, ebx
                            cmp eax, [ebp+08h]
                            setz bl
                    mov ecx, st_table[ecx*8]
                                    mov eax, [esi+0Ch]
                                    cmp eax, [ebp+0Ch]
            mov [edi+00h], edx
                                    setz al
                            mov ebx, st_table[ebx*8]
                                    and eax, 1 ;// make sure mask out -- should use another register
    sub st_count, 1
                    mov [edi+04h], ecx
                                    mov eax, st_table[eax*8]
                            mov [edi+08h], ebx
                                    mov [edi+0Ch], eax

    .UNTIL ZERO?

    mov esp, DWORD PTR [esp]
    pop ebp

    ret

math_bool_eq_dXdB_ft ENDP

ALIGN 16
math_bool_eq_dXsB_ft PROC

    push ebp
    mov eax, esp
    and esp, NOT 7    ;// 8 byte align
    sub esp, 8
    ;// for this table we store true at the top
    fxch
    fstp DWORD PTR [esp]    ;// false
    sub esp, 8
    fstp DWORD PTR [esp]    ;// empty
    pushd SAMARY_LENGTH / 4    ;// number of loop iterations
    push eax    ;// save orig esp
    ;//stack    esp count false true ... ebp ret
    ;//            00  04    08    10
    st_count TEXTEQU <(DWORD PTR [esp+04h])>
    st_table TEXTEQU <(DWORD PTR [esp+08h])>

    mov  ebp, [edx]    ;// edx is B input -- we treat as constt

    jmp enter_loop

    ;// min 4 - 5 cyles
    .REPEAT

    add esi,10h
    add edi,10h

enter_loop:
            xor edx, edx

            cmp ebp, [esi+00h]
            setz dl
                    xor ecx, ecx
                    cmp ebp, [esi+04h]
                    setz cl
                            xor ebx, ebx
            mov edx, st_table[edx*8]
                            cmp ebp, [esi+08h]
                            setz bl
                                    xor eax, eax
                    mov ecx, st_table[ecx*8]
                                    cmp ebp, [esi+0Ch]
                                    setz al
                            mov ebx, st_table[ebx*8]
            mov [edi+00h], edx
    sub st_count, 1
                                    mov eax, st_table[eax*8]
                    mov [edi+04h], ecx
                            mov [edi+08h], ebx
                                    mov [edi+0Ch], eax


    .UNTIL ZERO?

    mov esp, DWORD PTR [esp]
    pop ebp

    ret


math_bool_eq_dXsB_ft ENDP



;//
;//        boolean functions    -- done
;//
;////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN

END



