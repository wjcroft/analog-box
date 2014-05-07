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
;//                     this is a stripped down version of fft.asm
;// fft_abox.asm        don't get them confused
;//                     this ONLY works with dual 1024 point
;//                     the reverse xform is implemeted

; AJT: seems like every programmer goes through the trials of implementing an FFT
;      only to find the that results are no better than what's already available
;      oh well :-)


;// to do
comment ~ /*

    see ifft_01.mcd

1)  adjust output storers to do the dc level correctly
    the first bin of each output is :

    X[0] = real[0], real[N/2]
    Y[0] = imag[0], imag[N/2]

2)  the ifft requires a seperate loader, write this

    the output for the ifft is simply the bit reversed final stage
    this requires the full N point reverse table, not just the N/2 table

*/ comment ~


OPTION CASEMAP:NONE

.586
.MODEL FLAT


        USE_CACHE_ALIGNED_ALLOC equ 1   ;// need to define BEFORE win32A.inc
                                        ; AJT -- um, forgot what that means
        .NOLIST

            include <Abox.inc>
            include <fft_abox.inc>

        .LIST

        ;// configuration

        ;// FFT_TRACK_TIMING    EQU 1






.DATA

    ;// pointers to tables

        fft_pSinCos         dd  0   ;// 1024 point sincos table
        SIN_COS_MASK equ (1024*4)-8     ;// adrress mask for table
        SIN_TO_COS  equ 1024            ;// pSin + 1024 = pCos (1/4) of table

        fft_pWindow         dd  0   ;// 1024 point blackman window for forward
        fft_pBitReverse     dd  0   ;// 1024 point bit reverse table for forward

        ifft_pWindow        dd  0   ;// 1024 point blackman window for reverse
        ifft_pBitReverse    dd  0   ;// output 1024 point bit reverse table

        fft_pData           dd  0   ;// internal processing block

    ;// constants

        ;// w(n) = scale * ( 1 - (a0 + a1 * cos( 2*pi*n/N ) + a2 * cos( 4*pi*n/N ) )

        ;// blackman window coefficeints

        fft_blackman_A2 REAL4 0.076848e+0   ;// window coefficient
        fft_blackman_A1 REAL4 0.4965e+0     ;// window coefficient
        fft_blackman_A0 REAL4 0.42659e+0    ;// window coefficient

        ;// angle walking for 1024

        fft_blackman_dQ REAL4 6.135923152e-3    ;// 2pi/1024

        fft_dAngle  TEXTEQU <fft_blackman_dQ>   ;// REAL4 6.135923152e-3

        ;// input scale for all four, scales output to equal equivalent amplitude
                                            ;// sf=1/N
        fft_input_scale REAL4 9.765625e-4   ;// scales output to
                                            ;// equivalent amplitude

        ;// fft_blackman_sA ;// determined by T&E
                                            ;// this makes the peak level valid
        ;//fft_blackman_sA  REAL4 5.5997073e-4  ;// but not really accurate in terms of spectral
                                            ;// power (because of bin smearing)

        fft_blackman_sA TEXTEQU <fft_input_scale>   ;// bah! it's the same!

        ;// special W value for fft_stage_3

        fft_sqrt_half           REAL4 0.707106781e+0    ;// sqrt of 1/2

    ;// private functions

        fft_BuildWindow PROTO
        fft_BuildBitReverseTables PROTO
        fft_BuildSinCosTable PROTO

        fft_loader  PROTO
        fft_loader_win  PROTO
        ifft_loader PROTO

        fft_stage_3 PROTO

        fft_output PROTO

        ifft_output PROTO
        ifft_output_window PROTO

.CODE


;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;//
;//
;//     initialization code
;//

ASSUME_AND_ALIGN
fft_Initialize PROC

    ;//
    ;// allocate memory
    ;//

        DEBUG_IF <fft_pSinCos>      ;// already initialized


    ;// allocate all tables in one shot

        invoke memory_Alloc, GPTR, 1024 * 28

    ;// walk through and build all the pointers

        mov fft_pSinCos, eax            ;// sin cos table
        lea eax, [eax + 1024 * 4]

        mov fft_pData, eax              ;// internal data table
        lea eax, [eax + 1024 * 8]

        mov fft_pWindow, eax        ;// input blackman table
        lea eax, [eax + 1024 * 4]

        mov ifft_pWindow, eax       ;// output blackman table
        lea eax, [eax + 1024 * 4]

        mov fft_pBitReverse, eax    ;// input bit reverse table
        lea eax, [eax + 1024 * 4]

        mov ifft_pBitReverse, eax   ;// output bit reverse table
        lea eax, [eax + 1024 * 4]

    ;//
    ;// fill in all the tables
    ;//


    ;// sin cos table

        invoke fft_BuildSinCosTable

    ;// input blackman tables

        xor eax, eax ;// flag for forward table
        mov edi, fft_pWindow
        fld fft_blackman_sA
        mov ecx, 1024
        fld fft_blackman_dQ
        invoke fft_BuildWindow

    ;// output blackman tables

    ;// this should be done differently ?

        inc eax     ;// flag for reverse table

        mov edi, ifft_pWindow
        fld fft_blackman_sA
        mov ecx, 1024
        fld fft_blackman_dQ
        invoke fft_BuildWindow

    ;// bit reverse tables

        invoke fft_BuildBitReverseTables

    ;// that's it

        ret

fft_Initialize ENDP


ASSUME_AND_ALIGN
fft_Destroy PROC

    ;// this frees the tables

        invoke memory_Free, fft_pSinCos         ;// sin cos table

    ;// that's it

        ret

fft_Destroy ENDP


ASSUME_AND_ALIGN
fft_BuildWindow PROC PRIVATE

    ASSUME edi:PTR DWORD    ;// edi must point at the table to build
    ;// ecx must also be the table size
    ;// since the table is symetrical, we can decrease ecx

    ;// fpu must enter with dQ, sA

    ;// eax must be 0 for forward table
    ;// and non zero for reverse table

    ;// INPUT BLACKMAN WINDOW TABLE

    ;// w(n) = scale * ( 1 - (a1 + a2 * cos( 2*pi*n/N ) + a3 * cos( 4*pi*n/N ) )

    ;// OUTPUT BLACKMAN WINDOW TABLE

    ;// w(n) = scale / ( 1 - (a1 + a2 * cos( 2*pi*n/N ) + a3 * cos( 4*pi*n/N ) )

                            ;// dQ      sA
        fld fft_blackman_A1 ;// A1      dA      sA
        fld fft_blackman_A0 ;// A0      A1      dA      sA
        fld fft_blackman_A2 ;// A2      A0      A1      dA      sA
        fxch st(3)          ;// dA      A0      A1      A2      sA
        fldz                ;// q       dQ      A0      A1      A2      sA

    top_of_loop:

        fld st          ;// q       q       dQ      A0      A1      A2      sA
        fcos            ;// cosq    q       dQ      A0      A1      A2      sA
        fld st(1)       ;// q       cosq    q       dQ      A0      A1      A2      sA
        fadd st, st(2)  ;// 2q      cosq    q       dQ      A0      A1      A2      sA
        fcos            ;// cos2q   cosq    q       dQ      A0      A1      A2      sA
        fmul st, st(6)  ;// w2      cosq    q       dQ      A0      A1      A2      sA
        fxch            ;// cosq    w2      q       dQ      A0      A1      A2      sA
        fmul st, st(5)  ;// w1      w2      q       dQ      A0      A1      A2      sA
        fadd            ;// w1+w2   q       dQ      A0      A1      A2      sA
        fadd st, st(3)  ;// W       q       dQ      A0      A1      A2      sA
        fld1            ;// 1       W       q       dQ      A0      A1      A2      sA
        fsubr           ;// 1-W     q       dQ      A0      A1      A2      sA
        .IF eax
            fdivr st, st(6)
        .ELSE
            fmul st, st(6)  ;// win     q       dQ      A0      A1      A2      sA
        .ENDIF
        fstp [edi]      ;// q       dQ      A0      A1      A2      sA
        fadd st,st(1)   ;// q       dQ      A0      A1      A2      sA
        add edi, 4

        dec ecx

    jnz top_of_loop

    ;// clean up

        fstp st
        fstp st
        fstp st
        fstp st
        fstp st
        fstp st

        ret

fft_BuildWindow ENDP


;// bit reverse macros

    REVERSE_9 MACRO

        rcr eax, 1  ;// 1
        rcl ebx, 1
        rcr eax, 1  ;// 2
        rcl ebx, 1
        rcr eax, 1  ;// 3
        rcl ebx, 1
        rcr eax, 1  ;// 4
        rcl ebx, 1
        rcr eax, 1  ;// 5
        rcl ebx, 1
        rcr eax, 1  ;// 6
        rcl ebx, 1
        rcr eax, 1  ;// 7
        rcl ebx, 1
        rcr eax, 1  ;// 8
        rcl ebx, 1
        rcr eax, 1  ;// 9
        rcl ebx, 1

    ENDM


    REVERSE_10 MACRO

        REVERSE_9

        rcr eax, 1  ;// 10
        rcl ebx, 1

    ENDM


ASSUME_AND_ALIGN
fft_BuildBitReverseTables   PROC PRIVATE

    ;//
    ;// FORWARD BITREVERSE TABLE for real 1024
    ;//
        ;// 512 bit reverse pairs for (n and N-n)

        mov edi, fft_pBitReverse
        xor ecx, ecx
        .REPEAT

            mov eax, ecx
            xor ebx, ebx
            REVERSE_10
            shl ebx, 3      ;// then multiply by 8
            mov [edi], ebx  ;// and store
            add edi, 4      ;// iterate

            ;// then we do the mirror
            mov eax, 512*2
            sub eax, ecx
            xor ebx, ebx
            REVERSE_10
            and ebx, 1023   ;// better do this
            shl ebx, 3      ;// then multiply by 8
            mov [edi], ebx  ;// and store
            add edi, 4

            inc ecx

        .UNTIL ecx >= 512

    ;//
    ;// REVERSE BITREVERSE TABLE for real 1024
    ;//
        ;// just like the above, but accounts for 1024 seperate values

        mov edi, ifft_pBitReverse
        xor ecx, ecx
        .REPEAT

            mov eax, ecx
            xor ebx, ebx
            REVERSE_10
            shl ebx, 3      ;// then multiply by 8
            mov [edi], ebx  ;// and store
            add edi, 4      ;// iterate

            inc ecx

        .UNTIL ecx >= 1024

    ;// that's it

        ret


fft_BuildBitReverseTables   ENDP



ASSUME_AND_ALIGN
fft_BuildSinCosTable    PROC

    ASSUME edi:PTR DWORD

        mov edi, fft_pSinCos

    ;//
    ;// SINE TABLE
    ;//
    ;//  return the sin for Q in the range of [-1 to +1)
    ;//  format as REAL4
    ;//

        fld  fft_dAngle ;// for scanning
        fldz            ;// start the angle at zero
        mov  ecx, 1024

    @@: jecxz @F        ;// Ang dAng
        fld   st        ;// Ang Ang     dAng
        fsin            ;// Sine    Ang     dAng
        dec   ecx
        fstp  [edi]     ;// Ang dAng
        fadd  st, st(1) ;// Ang dAng
        add   edi, 4
        jmp   @B

       ;// clean up the FPU

    @@: fstp  st
        fstp st

        ret

fft_BuildSinCosTable    ENDP


;//
;//     initialization code
;//
;//
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////


IFDEF FFT_TRACK_TIMING
.DATA

    fft_0   dd  0   ;// enter
    fft_1   dd  0   ;// loader done
    fft_7   dd  0   ;// stage = 1 done
    fft_6   dd  0   ;// stage = 2
    fft_5   dd  0   ;// stage = 3
    fft_4   dd  0   ;// stage = 4
    fft_3   dd  0   ;// stage = 5
    fft_2   dd  0   ;// stage = 6
    fft_8   dd  0   ;// final 3 done
    fft_9   dd  0   ;// output

    sz_stage_01 db  'loader  %i',0

    sz_stage_12 db  'stage2  %i',0
    sz_stage_23 db  'stage3  %i',0
    sz_stage_34 db  'stage4  %i',0
    sz_stage_45 db  'stage5  %i',0
    sz_stage_56 db  'stage6  %i',0
    sz_stage_67 db  'stage7  %i',0

    sz_stage_78 db  'final3  %i',0
    sz_stage_89 db  'output  %i',0
    sz_stage_09 db  'total   %i',0

    fft_buf db 64 dup (0)

    TRACK_TIMING MACRO index:req

        rdtsc
        mov fft_&index, eax

        ENDM

    PRINT_DELTA MACRO ind_s:req, ind_t:req

        LOCAL L
        IFDEF FFT_TRACK_TIMING

        mov edx, fft_&ind_s
        sub edx, fft_&ind_t
        jns L
        neg edx
    L:  shr edx, LOG2(SAMARY_LENGTH)

        invoke wsprintfA, edi, ADDR sz_stage_&ind_s&ind_t, edx
        invoke TextOutA, ebx, 0,esi,edi, eax
        add esi, 12

        ENDIF

        ENDM

.CODE
ELSE

    TRACK_TIMING MACRO index:req
        ENDM
    PRINT_DELTA MACRO i:req, j:req
        ENDM

ENDIF



;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;//
;//
;//     interface           uses all registers except ebp
;//

ASSUME_AND_ALIGN
fft_Run PROC

;// ENTER: the stack looks like this
;// __________________________________________________
;// ret     pData1  pData2  bOptions    pData3  pData4
;// +00     +04     +08      +0C        +10     +14

TRACK_TIMING 0

;// preperation

    bOptions TEXTEQU <[esp+0Ch]>

    mov ecx, bOptions           ;// get the options

    mov ebx, bOptions

    and ecx, FFT_1024   ;// strip out extra bits to get data size
    mov eax, 40000h     ;// load this big number
    xor edx, edx        ;// clear for dividing
    div ecx             ;// now eax = sincos step
    shr ecx, 1          ;// and ecx = butter seperation

    shr eax, 3      ;// kludge for going to pSinCos from the generic math table

;// LOADER

    push eax            ;// store the sincos step
    push ecx            ;// store the butter step

    ;// butter  sincos  ret     p1      p2      options

    DEBUG_IF <!!(ebx & (FFT_FORWARD+FFT_REVERSE))>  ;// one of these must be specified

    .IF ebx & FFT_FORWARD

        .IF ebx & FFT_WINDOW

            lea ebx, fft_loader_win

        .ELSE

            lea ebx, fft_loader             ;// ebx is function to call

        .ENDIF

    .ELSE   ;// IF ebx & FFT_REVERSE


        lea ebx, ifft_loader

    .ENDIF

    mov eax, 512
    shr ecx, 1  ;// convert butter sep to data sep

    push eax    ;// store the count
    push ecx    ;// store the seperation

    call ebx    ;// call requested input function

    ;// sep     count   butter  sincos  ret     p1      p2      options ...

    add esp, 8

    ;// butter  sincos  ret     p1      p2      options ...
    ;// +00     +04     +08     +0C     +10     +14

TRACK_TIMING 1


;// MIDDLE STAGES       512         1024

;-  sincos step         10h           8h        = twice previous
;-  butter (A,B)        400h        800h        = half previous
;
;   data_count          1000h       2000h       = load from options
;
;   num_groups          80h         100h        = data_count / 10h
;   num stages          5           6           = log2(groups) - 2

    mov ecx, DWORD PTR [esp+14h];// load options
    shl DWORD PTR [esp+4], 1    ;// sincos is twice previous
    and ecx, FFT_1024           ;// ecx is data_count
    shr DWORD PTR [esp], 1      ;// butter is half previous
    mov edx, ecx                ;//

    shr edx, 5      ;// divide by 20h, edx is num groups
    mov eax, edx
    shr eax, 8
    add eax, 5      ;// eax is num stages

    ;// do the middle stages of the fft

    push ecx    ;// push count
    push edx    ;// push groups
    push eax    ;// push stages

;// STACK looks like this
;// stages, groups, count, butter, sincos, ... )

    call fft_middle_stages

    ;// do the special stage(last three)

    mov eax, bOptions
    and eax, FFT_1024
    shr eax, 6  ;// convert size to a number of pairs then to a number of blocks of eight
    push eax
    call fft_stage_3


;// 3) output stage

;//  the stack looks like this
;// ret     pData1  pData2  bOptions    pData3  pData4
;// +00     +04     +08      +0C        +10     +14

TRACK_TIMING 8

    mov edx, bOptions
    mov esi, [esp+10h]  ;// data 3
    mov edi, [esp+14h]  ;// data 4

    .IF edx & FFT_FORWARD

        call fft_output

    .ELSEIF edx & FFT_WINDOW

        call ifft_output_window

    .ELSE

        call ifft_output

    .ENDIF

TRACK_TIMING 9

IFDEF FFT_TRACK_TIMING

    invoke GetDC, hMainWnd
    mov ebx, eax

    xor esi, esi
    lea edi, fft_buf

    pushd 128
    pushd 64
    push esi
    push esi
    mov eax, esp
    invoke FillRect, ebx, eax, 3
    add esp, 16

    PRINT_DELTA 0, 1
    PRINT_DELTA 1, 2
    PRINT_DELTA 2, 3
    PRINT_DELTA 3, 4
    PRINT_DELTA 4, 5
    PRINT_DELTA 5, 6
    PRINT_DELTA 6, 7
    PRINT_DELTA 7, 8
    PRINT_DELTA 8, 9
    PRINT_DELTA 0, 9

    invoke ReleaseDC, hMainWnd, ebx

ENDIF

;// and that's about it

    ret 14h


fft_Run ENDP

;//
;//
;//     interface
;//
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////




;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;//
;//
;//     implementation
;//






;////////////////////////////////////////////////////////////////////
;//
;//     LOADERS
;//
;//         loaders are resposible for moving the data from the source
;//         windowing and or conditioning
;//         and doing the first butterfly
;//

    ;// formula
    ;//
    ;// Ar = ar*wA + br*wB
    ;// Ai = ai*wA + bi*wB
    ;//
    ;// Br = (ar*wA - br*wB)*WC - (ai*wA - bi*wB)*WS
    ;// Bi = (ar*wA - br*wB)*WS + (ai*wA - bi*wB)*WC

    ;// condensed

        ;// xr = ar*wA      yr = br*wB
        ;// xi = ai*wA      yi = bi*wB

        ;// xr+yr -> Ar
        ;// xi+yi -> Ai

        ;// zr = xr-yr
        ;// zi = xi-yi

        ;// zr*WC - zi*WS -> Br
        ;// zr*WS + zi*WC -> Bi

    ;// macros

    FFT_EXT_TOP MACRO ar:req, ai:req, br:req, bi:req, wA:req, wB:req, Ar:req, Ai:req

        ;// use this in place of FFT_DIF_LOADER to do the input stage

        ;// xr = ar*wA      yr = br*wB
        ;// xi = ai*wA      yi = bi*wB

        fld  ar
        fmul wA     ;// xr
        fld  ai
        fmul wA     ;// xi  xr
        fld  br
        fmul wB     ;// yr  xi  xr
        fld  bi
        fmul wB     ;// yi  yr  xi  xr

        ;// xr+yr -> Ar
        ;// xi+yi -> Ai

        fld st(3)       ;// xr  yi  yr  xi  xr
        fadd st, st(2)  ;// Ar  yi  yr  xi  xr

        fld st(3)       ;// xi  Ar  yi  yr  xi  xr
        fadd st, st(2)  ;// Ai  Ar  yi  yr  xi  xr
        fxch

        fstp Ar
        fstp Ai         ;// yi  yr  xi  xr

        ;// zr = xr-yr
        ;// zi = xi-yi

        fsubp st(2), st ;// yr  zi  xr
        fsubp st(2), st ;// zi  zr

    ENDM


    FFT_EXT_BOT MACRO Br:req, Bi:req, WC:req, WS:req

        ;// use this when WS and WC are external values

        ;// IN:     zi  zr
        ;// OUT:    empty

        ;// zr*WC - zi*WS -> Br
        ;// zr*WS + zi*WC -> Bi

        fld st          ;// zi      zi      zr
        fmul WS         ;// zi*WS   zi      zr

        fld st(2)       ;// zr      zi*WS   zi      zr
        fmul WC         ;// zr*WC   zi*WS   zi      zr

        fld WS          ;// WS      zr*WC   zi*WS   zi      zr
        fmulp st(4),st  ;// zr*WC   zi*WS   zi      zr*WS

        fld WC          ;// WC      zr*WC   zi*WS   zi      zr*WS
        fmulp st(3),st  ;// zr*WC   zi*WS   zi*WC   zr*WS

        fsubr           ;// Br      ziWC    zrWS
        fxch st(2)      ;// zrWS    ziWC    Br

        fadd            ;// Bi      Br
        fxch            ;// Br      Bi

        fstp Br         ;// Bi
        fstp Bi         ;//

    ENDM




;// LOADER( sep, count, butter, sincos, ...)

ASSUME_AND_ALIGN
fft_loader_win  PROC PRIVATE

    ;// ENTER:  stack looks like this:
    ;//                         _p_r_e_s_e_r_v_e_______________________________
    ;// ret     sep     count   butter  sincos  ret     p1      p2      options
    ;// +00     +04h    +08     +0C     +10     +14     +18     +1C     +20
    ;//
    ;// edx must enter with the window pointer
    ;//
    ;// need:
    ;//
    ;// ptr to source A     esi iterates by 4 seperate by sep
    ;// ptr to source B     edi iterates by 4 seperate by sep
    ;// ptr to sin/cos      ecx iterates by sincos
    ;// ptr to window       edx iterates by 4 seperate by sep
    ;// ptr to fft data     ebx iterates by 8 seperate by butter
    ;//
    ;// use count to count

    mov edx, fft_pWindow

    mov esi, [esp+18h]  ;// esi points at source1 (goes in real)
    mov edi, [esp+1Ch]  ;// edi points at source2 (goes in imag)
    mov ecx, fft_pSinCos;// ecx points at sincos table
    mov ebx, fft_pData  ;// destination
    xchg ebp, [esp+04h] ;// input seperation (preserve in stack)
    mov eax, [esp+0Ch]  ;// butter seperation

    ASSUME esi:PTR DWORD    ;// source 1
    ASSUME edi:PTR DWORD    ;// source 2
    ASSUME edx:PTR DWORD    ;// window values
    ASSUME ecx:PTR DWORD    ;// sin/cos
    ASSUME ebx:PTR DWORD    ;// destination

    ;// addressing

        count TEXTEQU <DWORD PTR [esp+08h]>

    ;// input values

        ar TEXTEQU <[esi]>
        ai TEXTEQU <[edi]>
        br TEXTEQU <[esi+ebp]>
        bi TEXTEQU <[edi+ebp]>

    ;// window values

        wA TEXTEQU <[edx]>
        wB TEXTEQU <[edx+ebp]>

    ;// sincos

        WS TEXTEQU <[ecx]>
        WC TEXTEQU <[ecx+SIN_TO_COS]>

    ;// output values

        Ar TEXTEQU <[ebx]>
        Ai TEXTEQU <[ebx+4]>
        Br TEXTEQU <[ebx+eax]>
        Bi TEXTEQU <[ebx+eax+4]>

    ;// the loop
    top_of_loader:

        FFT_EXT_TOP ar, ai, br, bi, wA, wB, Ar, Ai
        add esi, 4
        add edi, 4
        FFT_EXT_BOT Br, Bi, WC, WS
        add edx, 4
        add ecx, [esp+10h]
        add ebx, 8
        dec count

    jnz top_of_loader

        xchg ebp, [esp+4]

        ret

fft_loader_win ENDP


ASSUME_AND_ALIGN
fft_loader  PROC PRIVATE

    ;// ENTER:  stack looks like this:
    ;//                         _p_r_e_s_e_r_v_e_______________________________
    ;// ret     sep     count   butter  sincos  ret     p1      p2      options
    ;// +00     +04h    +08     +0C     +10     +14     +18     +1C     +20
    ;//
    ;// edx must point at the scale
    ;//
    ;// need:
    ;//
    ;// ptr to source A     esi iterates by 4 seperate by sep
    ;// ptr to source B     edi iterates by 4 seperate by sep
    ;// ptr to sin/cos      ecx iterates by sincos
    ;// ptr to window       edx iterates by 4 seperate by sep
    ;// ptr to fft data     ebx iterates by 8 seperate by butter
    ;//
    ;// use count to count

    lea edx, fft_input_scale

    mov esi, [esp+18h]  ;// esi points at source1 (goes in real)
    mov edi, [esp+1Ch]  ;// edi points at source2 (goes in imag)
    mov ecx, fft_pSinCos;// ecx points at sincos table
    mov ebx, fft_pData  ;// destination
    xchg ebp, [esp+04h] ;// input seperation (preserve in stack)
    mov eax, [esp+0Ch]  ;// butter seperation

    ASSUME esi:PTR DWORD    ;// source 1
    ASSUME edi:PTR DWORD    ;// source 2
    ASSUME edx:PTR DWORD    ;// window values
    ASSUME ecx:PTR DWORD    ;// sin/cos
    ASSUME ebx:PTR DWORD    ;// destination

    ;// addressing

    ;// input values

        ar TEXTEQU <[esi]>
        ai TEXTEQU <[edi]>
        br TEXTEQU <[esi+ebp]>
        bi TEXTEQU <[edi+ebp]>

    ;// window values

        wA TEXTEQU <[edx]>
        wB TEXTEQU <[edx]>

    ;// sincos

        WS TEXTEQU <[ecx]>
        WC TEXTEQU <[ecx+SIN_TO_COS]>

    ;// output values

        Ar TEXTEQU <[ebx]>
        Ai TEXTEQU <[ebx+4]>
        Br TEXTEQU <[ebx+eax]>
        Bi TEXTEQU <[ebx+eax+4]>

    ;// the loop
    top_of_loader:

        FFT_EXT_TOP ar, ai, br, bi, wA, wB, Ar, Ai
        add esi, 4
        add edi, 4
        FFT_EXT_BOT Br, Bi, WC, WS
        add ecx, [esp+10h]
        add ebx, 8
        dec count

    jnz top_of_loader

        xchg ebp, [esp+4]

        ret

fft_loader ENDP




ASSUME_AND_ALIGN
ifft_loader PROC PRIVATE

    ;// given our two data pointers
    ;// we recombine the passed spectrums, and do the first butterfly

    ;// ENTER:  stack looks like this:
    ;//                         _p_r_e_s_e_r_v_e_______________________________
    ;// ret     sep     count   butter  sincos  ret     p1      p2      options
    ;// +00     +04h    +08     +0C     +10     +14     +18     +1C     +20
    ;//
comment ~ /*

    formula:

    using x and y as the source data values
    we first recombine using:

        ar = ( xi[0] + yr[0] ) * 1/2        where P points at the end of the input data
        ai = ( yi[0] - xr[0] ) * 1/2        and counts backwards

        br = ( xi[P] - yr[P] ) * 1/2
        bi = ( yi[P] + xr[P] ) * 1/2

    then to do first butterfly

        Ar = ar + br
        Ai = ai + bi
        Br = (ar - br) * WC
        Bi = (ai - bi) * WS


addressing requires two fixed pointers and two index registers

    fixed pointers      index registers
    ----------------    --------------------------------------------
    esi for source 1    edx*8 scans forwards and is reffered to as O
    edi for source 2    ebp*8 scansbackwards and is reffered to as P


    iterated pointers
    -----------------
    ebx for fft_data    advances by 8, is also offset by eax
    ecx for sin/cos     advacnces by the passed sin/cos step value

    counter:    ebp can be the count

*/ comment ~

    ;// ifft loader, get the parameters

    mov esi, [esp+18h]  ;// esi points at source1 (goes in real)
    mov edi, [esp+1Ch]  ;// edi points at source2 (goes in imag)
    mov ecx, fft_pSinCos;// ecx points at sincos table
    xchg ebp, [esp+08h] ;// count (also preserves ebp in stack)
    mov ebx, fft_pData  ;// destination
    mov eax, [esp+0Ch]  ;// butter seperation

    xor edx, edx    ;// scans forwrds

    ;//ASSUME esi:PTR DWORD ;// source 1
    ;//ASSUME edi:PTR DWORD ;// source 2
    ;//ASSUME ecx:PTR DWORD ;// sin/cos
    ;//ASSUME ebx:PTR DWORD ;// destination

    ;// addressing

    ;// input values
;ABOX232 real/imag were reveresed
        xi0 TEXTEQU <DWORD PTR [esi+edx*8]>
        xr0 TEXTEQU <DWORD PTR [esi+edx*8+4]>
        yi0 TEXTEQU <DWORD PTR [edi+edx*8]>
        yr0 TEXTEQU <DWORD PTR [edi+edx*8+4]>

        xiP TEXTEQU <DWORD PTR [esi+ebp*8]>
        xrP TEXTEQU <DWORD PTR [esi+4+ebp*8]>
        yiP TEXTEQU <DWORD PTR [edi+ebp*8]>
        yrP TEXTEQU <DWORD PTR [edi+4+ebp*8]>

    ;// setup the loop

        fld math_1_2

    ;// the first pass is always special

    ;// A = 2*xr0 , 2*yr0
    ;// B = 2*xi0 , 2*yi0
;ABOX232 real/imag were reveresed
        fld xi0     ;// xr0
        fld yi0     ;// yr0 xr0
        fld xr0     ;// xi0 yr0 xr0
        fld yr0     ;// yi0 xi0 yr0 xr0

        fld st(3)       ;// xr0 yi0 xi0 yr0 xr0
        faddp st(4), st ;// yi0 xi0 yr0 ar
        fld st(2)       ;// yr0 yi0 xi0 yr0 ar
        faddp st(3), st ;// yi0 xi0 ai  ar
        fld st(1)       ;// xi0 yi0 xi0 ai  ar
        faddp st(2), st ;// yi0 br  ai  ar
        fld st          ;// yi0 yi0 br  ai  ar
        fadd            ;// bi  br  ai  ar

        jmp enter_the_loop

    ;// the loop
    top_of_loader:

        ;// ar = ( xi[0] + yr[0] ) * 1/2        where P is the seperation
        ;// ai = ( yi[0] - xr[0] ) * 1/2

        ;// br = ( xi[P] - yr[P] ) * 1/2
        ;// bi = ( yi[P] + xr[P] ) * 1/2

        ;// load the four values guaranteed to produce cache misses

        fld yr0         ;// yr0 1/2
        fld xr0         ;// xr0 yr0 1/2
        fld yrP         ;// yrP xr0 yr0 1/2
        fld xrP         ;// xrP yrP xr0 yr0 1/2

        ;// dervive the four input values
                        ;// 0   1   2   3   4   5
        fld xi0         ;// xi0 xrP yrP xr0 yr0 1/2
        faddP st(4), st ;// xrP yrP xr0 ar  1/2
        fld yi0         ;// yi0 xrP yrP xr0 ar  1/2
        fsubrp st(3), st;// xrP yrP ai  ar  1/2
        fld xiP         ;// xiP xrP yrP ai  ar  1/2
        fsubrp st(2), st;// xrP br  ai  ar  1/2
        fadd yiP        ;// bi  br  ai  ar  1/2

        ;// do the first butterfly and scale

        ;// Ar = (ar + br) * 1/2
        ;// Ai = (ai + bi) * 1/2

        ;// zr = (ar-br)*1/2
        ;// zi = (ai-bi)*1/2
        ;// FFT_EXT_BOT MACRO Br:req, Bi:req, WC:req, WS:req

    enter_the_loop:     ;// bi  br  ai  ar  1/2
                        ;// 0   1   2   3   4   5   6
        fld st(3)       ;// ar  bi  br  ai  ar  1/2
        fadd st, st(2)  ;// Ar  bi  br  ai  ar  1/2

        fld st(3)       ;// ai  Ar  bi  br  ai  ar  1/2
        fadd st, st(2)  ;// Ai  Ar  bi  br  ai  ar  1/2

        fxch st(2)      ;// bi  Ar  Ai  br  ai  ar  1/2
        fsubp st(4), st ;// Ar  Ai  br  ai-bi   ar  1/2
        fmul st, st(5)  ;// AR  Ai  br  ai-bi   ar  1/2
        fxch st(2)      ;// br  Ai  AR  ai-bi   ar  1/2
        fsubp st(4),st  ;// Ai  AR  ai-bi   ar-br   1/2
        fmul st, st(4)  ;// AI  AR  ai-bi   ar-br   1/2

        fld st(4)       ;// .5  AI  AR  ai-bi   ar-br   1/2
        fmulp st(3), st ;// AI  AR  zi  ar-br   1/2
        fld st(4)       ;// .5  AI  AR  zi  ar-br   1/2
        fmulp st(4),st  ;// AI  AR  zi  zr  1/2
        fxch            ;// AR  AI  zi  zr  1/2

        Ar TEXTEQU <DWORD PTR [ebx]>
        Ai TEXTEQU <DWORD PTR [ebx+4]>

        fstp Ar         ;// AI  zi  zr  1/2
        fstp Ai         ;// zi  zr  1/2

        WS TEXTEQU <DWORD PTR [ecx]>
        WC TEXTEQU <DWORD PTR [ecx+SIN_TO_COS]>
        Br TEXTEQU <DWORD PTR [ebx+eax]>
        Bi TEXTEQU <DWORD PTR [ebx+eax+4]>

        FFT_EXT_BOT Br, Bi, WC, WS

                        ;// 1/2

        ;// iterate
        add ebx, 8
        add ecx, [esp+10h]  ;// advance the sin/cos ptr
        inc edx
        dec ebp

    jnz top_of_loader

        xchg ebp, [esp+08h] ;// retrieve ebp

        fstp st ;// dump the scale

        ret


ifft_loader ENDP

;//
;//     LOADERS
;//
;//
;////////////////////////////////////////////////////////////////////





;////////////////////////////////////////////////////////////////////
;//
;//
;//     MIDDLE STAGES
;//
;// nomenclature:
;//
;// full_butterfly
;//
;// expanded form
;//
;//     Ar+Br   (Ar-Br)*WC - (Ai-Bi)*WS
;//     Ai+Bi   (Ar-Br)*WS + (Ai-Bi)*WC
;//
;// pipelined form
;//
;//     Ar+Br   Ar-Br=dr    dr*WC - di*WS
;//     Ai+Bi   Ai-Bi=di    dr*WS + di*WC
;//


    ;////////////////////////////////////////////////////////////////////
    ;//
    ;//
    ;//     FFT_DIF_LOADER
    ;//
    ;// use this as the upper half of a DIF butterfly
    ;//
    ;// this macro computes:
    ;//
    ;// IN:
    ;// OUT:    di      dr
    ;//
    ;//     Ar+Br   stored in place
    ;//     Ai+Bi   stored in place
    ;//     Ar-Br   loaded in fpu as dr
    ;//     Ai-Bi   loaded in fpu as di
    ;//
    FFT_DIF_LOADER  MACRO AA:req, BB:req

        ;// use this INSIDE the middle stages

        fld  AA     ;// Ar      ;// cache miss (grabs ai also)
        fadd BB     ;// Ar+Br   ;// cache miss (grabs bi also)

        fld  AA[4]  ;// Ai      Ar+Br
        fadd BB[4]  ;// Ai+Bi   Ar+Br

        fld  AA[4]  ;// Ai      Ai+Bi   Ar+Br
        fsub BB[4]  ;// di      Ai+Bi   Ar+Br

        fld  AA     ;// Ar      di      Ai+Bi   Ar+Br
        fsub BB     ;// dr      di      Ai+Bi   Ar+Br

        fxch st(3)  ;// Ar+Br   di      Ai+Bi   dr
        fstp AA     ;// di      Ai+Bi   dr

        fxch        ;// Ai+Bi   di      dr
        fstp AA[4]  ;// di      dr

        ENDM



comment ~ /*

    this function below performs the middle stages of a DIF FFT

    rather than scan down down each column linearly
    this routine scans the column by the W values

    the function uses stack based addressing (not ebp)
    caller must pass the data pointer, data size,
        three numbers describing the scan (below)
        and the number of stages to perform
    caller also has to clean up the args

    this function is designed to start at the SECOND stage of an fft

*/ comment ~


comment ~ /*

    formulas for determining groups, sin_cos, and butter for the SECOND stage

    butter is the byte distance between the A and B pairs in a stage
    butter must start at the appropriate value for the second stage

        butter = num_points / 2 * 8
        butter gets SMALLER each stage

    groups is the number of pairs in a stage that use the same W
    since we're starting at the second stage of the fft,
    the number of same_W items is always two
    so set the initial groups value to iterate twice through the column

        groups = num_points / 2
        groups gets SMALLER each stage

    sin_cos is angle increment for each W between groups, cast as a pointer adjuster
    W addresses the sin_cos lookup table, which is always 8192 values (2000h values)
    W iterates when the groups iterate, and must run once around the circle in each stage

        sin_cos = 2000h / num_points * 4
        sin_cos gets LARGER each stage

    here are some value sets:

    for a dual 512 point FFT

        data_size = 1000h   ;// 512 points * 2 values/point * 4 bytes/value
        stages = 8          ;// 8 stages remaining (same as a 256 point fft)
        groups = 0080h      ;// the first stage has 80h steps, in two groups(gets smaller)
        sin_cos = 0080h     ;// first stage sin_cos steps at 80h bytes      (gets larger)
        butter = 0400h      ;// there are 400h bytes between butterflies    (gets smaller)

    for a single 1024 point FFT

        data_size = 2000h   ;// 1024 points * 2 values/point * 4 bytes/value
        stages = 9          ;// 9 stages remaining
        groups = 0100h      ;// the first stage has 100h steps, in two groups(gets smaller)
        sin_cos = 0040h     ;// first stage sin_cos steps at 40h bytes      (gets larger)
        butter = 0800h      ;// there are 800h bytes between butterflies    (gets smaller)

*/ comment ~




;// MIDDLE( stages, groups, count, butter, sincos, ... )
ASSUME_AND_ALIGN
fft_middle_stages PROC PRIVATE

;// ENTER stack looks like this
;//
;// ret     stages  groups  count   butter  sincos
;//         +04     +08     +0C     +10     +14

    ;// these operations are ALAWYS performed on fft_pData
    ;// data_size ( on the stack is the only way to determine the size)

        assume ebx:PTR DWORD    ;// sin/cos iterator
        assume esi:PTR DWORD    ;// source iterator
        assume edi:PTR DWORD    ;// source iterator

        groups      TEXTEQU <DWORD PTR [esp+08h]>   ;// number of steps with unique X values
        butter      TEXTEQU <DWORD PTR [esp+10h]>   ;// initial byte seperation of butterflies AB
        stages      TEXTEQU <DWORD PTR [esp+04h]>   ;// number of stages to perform
        sin_cos     TEXTEQU <DWORD PTR [esp+14h]>   ;// initial sin/cos step bytes
        data_size   TEXTEQU <DWORD PTR [esp+0Ch]>   ;// byte size of data (needed for eol)

    ;// here we go

        mov eax, butter     ;// should this be aligned ??

    top_of_stage_loop:      ;// stage scan

        mov esi, fft_pData  ;// point at start of data array
        mov ebx, fft_pSinCos;// always start at 0 degrees
        mov ecx, groups     ;// load the number of groups for this stage

    top_of_group_loop:      ;// group scan

        fld [ebx+SIN_TO_COS];// wr (cosine, fixed table size)
        xor edx, edx        ;// reset the group scanner
        fld [ebx]           ;// wi  wr

ALIGN 4

    top_of_butterfly_loop:  ;// butterfly scan

        lea edi, [esi+eax]  ;// determine the B pointer

        fld  [esi+edx]      ;// Ar      ;// cache miss (grabs ai also)
        fadd [edi+edx]      ;// Ar+Br   ;// cache miss (grabs bi also)

        fld  [esi+edx+4]    ;// Ai      Ar+Br   wi      wr
        fadd [edi+edx+4]    ;// Ai+Bi   Ar+Br   wi      wr

        fld  [esi+edx+4]    ;// Ai      Ai+Bi   Ar+Br   wi      wr
        fsub [edi+edx+4]    ;// di      Ai+Bi   Ar+Br   wi      wr

        fld  [esi+edx]      ;// Ar      di      Ai+Bi   Ar+Br   wi      wr
        fsub [edi+edx]      ;// dr      di      Ai+Bi   Ar+Br

        fxch st(3)          ;// Ar+Br   di      Ai+Bi   dr      wi      wr
        fstp [esi+edx]      ;// di      Ai+Bi   dr      wi      wr

        fxch                ;// Ai+Bi   di      dr      wi      wr
        fstp [esi+edx+4]    ;// di      dr      wi      wr

        add edi, edx        ;// this prevents collision with iterating edx
                            ;// di      dr      wi      wr

        fld st              ;// di      di      dr      wi      wr
        fmul st, st(3)      ;// di*wi   di      dr      wi      wr

        fld st(2)           ;// dr      di*wi   di      dr      wi      wr
        fmul st, st(5)      ;// dr*wr   di*wi   di      dr      wi      wr

        lea edx, [edx+eax*2];// this takes a while, so we put it way up here

        fld st(4)           ;// wi      dr*wr   di*wi   di      dr      wi      wr
        fmulp st(4),st      ;// dr*wr   di*wi   di      dr*wi   wi      wr

        fld st(5)           ;// wr      dr*wr   di*wi   di      dr*wi   wi      wr
        fmulp st(3),st      ;// dr*wr   di*wi   di*wr   dr*wi   wi      wr

        cmp edx, data_size  ;// this also takes a while

        fsubr               ;// cr      iwr     rwi     wi      wr
        fxch st(2)          ;// rwi     iwr     cr      wi      wr

        fadd                ;// ci      cr      wi      wr
        fxch                ;// cr      ci      wi      wr

        fstp [edi]          ;// ci      wi      wr

        fstp [edi+4]        ;// wi      wr

    jb top_of_butterfly_loop

        ;// we've finished one group

        add esi, 8          ;// iterate esi (always 8)
        add ebx, sin_cos    ;// iterate sin cos pointer
        fstp st             ;// unload fpu
        dec ecx             ;// check if done with this stage
        fstp st             ;// unload fpu

    jnz top_of_group_loop

        ;// we've finished this stage

        shr groups, 1   ;// number of unique W's in each group is half previous
        shl sin_cos, 1  ;// sin_cos jump is twice previos
        shr eax, 1      ;// butterfly spacing is half previous

IFDEF FFT_TRACK_TIMING

    push eax
    push edx
    rdtsc
    mov edx, stages[8]
    mov fft_1[edx*4], eax
    pop edx
    pop eax

ENDIF

        dec stages      ;// iterate stages

    jnz top_of_stage_loop

    ret 14h

    sin_cos     TEXTEQU <>
    butter      TEXTEQU <>
    stages      TEXTEQU <>
    data_size   TEXTEQU <>

fft_middle_stages ENDP
;//
;//
;//     FFT MIDDLE STAGES
;//
;////////////////////////////////////////////////////////////////////




;////////////////////////////////////////////////////////////////////
;//
;//
;//     FFT FINAL STAGES    are done in two phases
;//

comment ~ /*

    substantial optimization is acomplished on the last three stages
    due to the fact that Wr and Wi are either 0,1 or sqr(0.5)
    this elimates many unneeded oprations


    ;// catalog of the final stage
    ;//
    ;// k=0/8   WC=1    WS=0
    ;//
    ;//     dr
    ;//     di
    ;//
    ;// k=1/8   WC=s2   WS=s2   WS=WC
    ;//
    ;//     (dr-di)*s2
    ;//     (dr+di)*s2
    ;//
    ;// k=2/8   WC=0    WS=1
    ;//
    ;//     -di
    ;//      dr
    ;//
    ;// k=3/8   WC=-s2  WS=s2   ==> WS=-WC
    ;//
    ;//     -(dr+di)*s2
    ;//     (dr-di)*s2
    ;//

*/ comment ~

    FFT_3_SUBLOADER MACRO

        ;// use after FFT_DIF_LOADER
        ;// assume S is loaded

        ;// this macro computes:
        ;//
        ;// IN:     di      dr      S
        ;// OUT:    dr+di   dr-di   S
        ;//

        fld st              ;// di      di      dr      S
        fadd st, st(2)      ;// dr+di   di      dr      S
        fxch st(2)          ;// dr      di      dr+di   S
        fsubr               ;// dr-di   dr+di   S
        fxch                ;// dr+di   dr-di   S

        ENDM


    ;// the last two butterflies may be done as part of the third

    ;// expanded form
    ;//
    ;//     stage 2             stage 1
    ;//     tr  tr+vr ==> Tr    Tr+Ur ==> tr+vr+ur+wr
    ;//     ti  ti+vi ==> Ti    Ti+Ui ==> ti+vi+ui+wi

    ;//     ur  ur+wr ==> Ur    Tr-Ur ==> tr+vr-ur-wr
    ;// 0/2 ui  ui+wi ==> Ui    Ti-Ui ==> ti+vi-ui-wi
    ;//
    ;//     vr  tr-vr ==> Vr    Vr+Wr ==> tr-vr+wi-ui
    ;//     vi  ti-vi ==> Vi    Vi+Wi ==> ti-vi-wr+ur

    ;//     wr  wi-ui ==> Wr    Vr-Wr ==> tr-vr-wi+ui
    ;// 1/2 wi  ur-wr ==> Wi    Vi-Wi ==> ti-vi-ur+wr


    ;// to keep the value from colliding, we do this in a staggered fashion
    ;// also: only 7 regs to work with (S value at the top of the stack)

    ;// algorithm:
    ;//
    ;//     tvr = tr+vr     dtvr = tr-vr
    ;//     uwr = ur+wr     duwr = ur-wr
    ;//
    ;// tvr + uwr -> TR
    ;// tvr - uwr -> UR : dump tvr uwr
    ;//
    ;//     tvi = ti+vi     dtvi = ti-vi
    ;//     uwi = ui+wi     duwi = ui-wi
    ;//
    ;// tvi + uwi -> TI
    ;// tvi - uwi -> UI : dump tvi uwi
    ;//
    ;// dtvr - duwi -> VR
    ;// dtvr + duwi -> WR : dump dtvr duwi
    ;// dtvi + duwr -> VI
    ;// dtvi - duwr -> WI : dump dtvi duwr

    FFT_LAST_STAGE MACRO

        LOCAL tr, ti, ur, ui, vr, vi, wr, wi

        tr TEXTEQU <[esi+00h]>
        ti TEXTEQU <[esi+04h]>
        ur TEXTEQU <[esi+08h]>
        ui TEXTEQU <[esi+0Ch]>
        vr TEXTEQU <[esi+10h]>
        vi TEXTEQU <[esi+14h]>
        wr TEXTEQU <[esi+18h]>
        wi TEXTEQU <[esi+1Ch]>

    ;// tvr = tr+vr
    ;// dtvr = tr-vr

        fld  tr
        fadd vr         ;// tvr
        fld  tr
        fsub vr         ;// dtvr    tvr

    ;// uwr = ur+wr
    ;// duwr = ur-wr

        fld  ur
        fadd wr         ;// uwr     dtvr    tvr
        fld  ur
        fsub wr         ;// duwr    uwr     dtvr    tvr
        fxch st(3)      ;// tvr     uwr     dtvr    duwr

    ;// tvr + uwr -> TR
    ;// tvr - uwr -> UR
    ;// : dump tvr uwr

        fld st(1)       ;// uwr     tvr     uwr     dtvr    duwr
        fadd st, st(1)  ;// TR      tvr     uwr     dtvr    duwr
        fxch st(2)      ;// uwr     tvr     TR      dtvr    duwr
        fsub            ;// UR      TR      dtvr    duwr
        fxch            ;// TR      UR      dtvr    duwr
        fstp tr         ;// UR      dtvr    duwr
        fstp ur         ;// dtvr    duwr

    ;// tvi = ti+vi
    ;// dtvi = ti-vi

        fld  ti
        fadd vi         ;// tvi     dtvr    duwr
        fld  ti
        fsub vi         ;// dtvi    tvi     dtvr    duwr

    ;// uwi = ui+wi
    ;// duwi = ui-wi

        fld  ui
        fadd wi         ;// uwi     dtvi    tvi     dtvr    duwr
        fld  ui
        fsub wi         ;// duwi    uwi     dtvi    tvi     dtvr    duwr
        fxch st(3)      ;// tvi     uwi     dtvi    duwi    dtvr    duwr

    ;// tvi + uwi -> TI
    ;// tvi - uwi -> UI
    ;// : dump tvi uwi

        fld st(1)       ;// uwi     tvi     uwi     dtvi    duwi    dtvr    duwr
        fadd st, st(1)  ;// TI      tvi     uwi     dtvi    duwi    dtvr    duwr
        fxch st(2)      ;// uwi     tvi     TI      dtvi    duwi    dtvr    duwr
        fsub            ;// UI      TI      dtvi    duwi    dtvr    duwr
        fxch            ;// TI      UI      dtvi    duwi    dtvr    duwr
        fstp ti         ;// UI      dtvi    duwi    dtvr    duwr
        fstp ui         ;// dtvi    duwi    dtvr    duwr

    ;// dtvr - duwi -> VR
    ;// dtvr + duwi -> WR
    ;// : dump dtvr duwi

        fxch st(2)      ;// dtvr    duwi    dtvi    duwr
        fld st(1)       ;// duwi    dtvr    duwi    dtvi    duwr
        fsubr st, st(1) ;// VR      dtvr    duwi    dtvi    duwr
        fxch st(2)      ;// duwi    dtvr    VR      dtvi    duwr
        fadd            ;// WR      VR      dtvi    duwr
        fxch            ;// VR      WR      dtvi    duwr
        fstp vr         ;// WR      dtvi    duwr
        fstp wr         ;// dtvi    duwr

    ;// dtvi + duwr -> VI
    ;// dtvi - duwr -> WI
    ;// : dump dtvi duwr

        fld st(1)       ;// duwr    dtvi    duwr
        fadd st, st(1)  ;// VI      dtvi    duwr
        fxch st(2)      ;// duwr    dtvi    VI
        fsub            ;// WI      VI
        fxch            ;// VI      WI
        fstp vi         ;// WI
        fstp wi         ;//

        ENDM





;// addressing for stage 3
;//
;// A           B
;// aar 00h     eer 20h
;// aai 04h     eei 24h
;// bbr 08h     ffr 28h
;// bbi 0Ch     ffi 2Ch
;// ccr 10h     ggr 30h
;// cci 14h     ggi 34h
;// ddr 18h     hhr 38h
;// ddi 1Ch     hhi 3Ch

ASSUME_AND_ALIGN
fft_stage_3 PROC PRIVATE    ;// count
                            ;// +04

    ;// this does blocks of stage 3 until count hits zero

    ;// uses esi, edi, ebx

    count TEXTEQU <DWORD PTR [esp+4]>

    fld fft_sqrt_half   ;// this will remain in the FPU
    mov esi, fft_pData

    ASSUME esi:PTR DWORD

    aar TEXTEQU <00h>
    eer TEXTEQU <20h>
    eei TEXTEQU <24h>

    bbr TEXTEQU <08h>
    ffr TEXTEQU <28h>
    ffi TEXTEQU <2Ch>

    ccr TEXTEQU <10h>
    ggr TEXTEQU <30h>
    ggi TEXTEQU <34h>

    ddr TEXTEQU <18h>
    hhr TEXTEQU <38h>
    hhi TEXTEQU <3Ch>

top_of_stage_3:

    ;// this function iterates esi
    ;// it performs ONE bock of stage 3 of a DIF
    ;// 8 inputs, 8 outputs (4 butterflies)
    ;// S MUST BE LOADED IN FPU

    ;// k=0/8

        FFT_DIF_LOADER <[esi+aar]>, <[esi+eer]> ;// di      dr
        fstp [esi+eei]
        fstp [esi+eer]

    ;// k=1/8

        FFT_DIF_LOADER <[esi+bbr]>, <[esi+ffr]> ;// di      dr      S
        FFT_3_SUBLOADER     ;// dr+di   dr-di   S
        fmul st, st(2)      ;// (r+i)S  dr-di   S
        fxch                ;// dr-di   (r+i)S  S
        fmul st, st(2)      ;// (r-i)S  (r+i)S  S
        fxch                ;// (r+i)S  (r-i)S  S
        fstp [esi+ffi]
        fstp [esi+ffr]

    ;// k=2/8

        FFT_DIF_LOADER <[esi+ccr]>, <[esi+ggr]> ;// di      dr
        fchs
        fstp [esi+ggr]
        fstp [esi+ggi]

    ;// k=3/8

        FFT_DIF_LOADER <[esi+ddr]>, <[esi+hhr]> ;// di      dr      S
        FFT_3_SUBLOADER     ;// dr+di   dr-di   S
        fmul st, st(2)      ;// (r+i)S  dr-di   S
        fxch                ;// dr-di   (r+i)S  S
        fmul st, st(2)      ;// (r-i)S  (r+i)S  S
        fxch                ;// (r+i)S  (r-i)S  S
        fchs
        fstp [esi+hhr]
        fstp [esi+hhi]

    ;// now we can do passes of the last stage

        FFT_LAST_STAGE
        add esi, 20h        ;// advance esi to next block
        FFT_LAST_STAGE
        add esi, 20h        ;// advance esi to next block

    ;// see if we're done

        dec count
        jnz top_of_stage_3

    ;// clean up our one register

        fstp st

    ;// that's it

    count TEXTEQU <>
    aar TEXTEQU <>
    eer TEXTEQU <>
    eei TEXTEQU <>

    bbr TEXTEQU <>
    ffr TEXTEQU <>
    ffi TEXTEQU <>

    ccr TEXTEQU <>
    ggr TEXTEQU <>
    ggi TEXTEQU <>

    ddr TEXTEQU <>
    hhr TEXTEQU <>
    hhi TEXTEQU <>

        ret 4

fft_stage_3 ENDP
;//
;//     FFT FINAL STAGES
;//
;//
;////////////////////////////////////////////////////////////////////







;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;//
;//                         tasks: uncombine each pair
;//     output stages              do the appropriate output function
;//

    ;// lifted from the fft2.cpp adventure
    ;// BR must point at a pair of bit reverse values
    ;// which should end up as expected

    ;// this then is the uncombine step
    ;// which works like this:
    ;//
    ;// AB points at the fft data
    ;// BR points at the desired bit revrese entry, which is arranged in (n, N-n) pairs
    ;// AA and BB are temp registers
    ;//
    ;//     ar = Ai - Bi
    ;//     ai = Ar + Br
    ;//     br = Br - Ar
    ;//     bi = Ai + Bi

    FFT_UNCOMBINE MACRO AB:req, BR:req, AA:=<eax>, BB:=<edx>

        ;// IN:     empty
        ;// OUT:    ai      ar      bi      br

        mov AA,[BR+0]   ;//     pA
        mov BB,[BR+4]   ;//     pB

        ;// br = Br - Ar
        fld  [AB+BB+0]
        fsub [AB+AA+0]  ;// br

        ;// bi = Ai + Bi
        fld  [AB+AA+4]
        fadd [AB+BB+4]  ;// bi      br

        ;// ar = Ai - Bi
        fld  [AB+AA+4]
        fsub [AB+BB+4]  ;// ar      bi      br

        ;// ai = Ar + Br
        fld  [AB+AA+0]
        fadd [AB+BB+0]  ;// ai      ar      bi      br

    ENDM



ASSUME_AND_ALIGN
fft_output  PROC PRIVATE

    ;// this stores real imag pairs

    ;// ENTER:  stack looks like this
    ;//
    ;// ret     ret     pData1  pData2  bOptions
    ;// +00     +08     +0C     +10     +14

    ;// esi must point at output 1
    ;// edi must point at output 2

    push ebp

    mov ebx, fft_pBitReverse
    mov ecx, fft_pData
    mov ebp, 512    ;// ebp will count pairs of values

    ASSUME ebx:PTR DWORD    ;// bit reverse pointer
    ASSUME ecx:PTR DWORD    ;// points at fft data
    ASSUME esi:PTR DWORD    ;// iterates data 1
    ASSUME edi:PTR DWORD    ;// iterates data 2

    ;// first item is special

    ;// xr = X0.real    yr = X0.imag
    ;// xi = X1.real    yi = X1.imag

    fld [ecx]       ;// xr
    fld [ecx+4]     ;// yr  xr
    fld [ecx+8]     ;// xi  yr  xr
    fld [ecx+0Ch]   ;// yi  xi  yr  xr

    fxch st(3)      ;// xr  xi  yr  yi
    fstp [esi]      ;// xi  yr  yi
    fstp [esi+4]    ;// yr  yi
    add esi, 8
    fstp [edi]      ;// yi
    fstp [edi+4]    ;//
    add edi, 8

    jmp enter_the_loop

    top_of_loop:

        FFT_UNCOMBINE ecx, ebx  ;// ai      ar      bi      br

;ABOX232 had sin/cos reversed !!
;or is the problem in the sincos table ?
;       fxch        ;// TR      TI      VI      VR
        fstp [esi]  ;// A2  B2  B1
        add esi, 4
        fstp [esi]  ;// B2  B1
        add esi, 4
;ABOX232 had sin/cos reversed !!
;or is the problem in the sincos table ?
;       fxch        ;// B1  B2
        fstp [edi]  ;// B2
        add edi, 4
        fstp [edi]  ;//
        add edi, 4

    enter_the_loop:

        add ebx, 8  ;// iterate the bit reverse pointer

        dec ebp ;// decrease the count

    jnz top_of_loop

    pop ebp

    ret

fft_output  ENDP



ASSUME_AND_ALIGN
ifft_output PROC

comment ~ /*

    this is done by grabbing the correct values from fft_pData
    via the ifft_BitReverse table

    x[n] = f[bitreverse(n)].real for n = 0 to 1023
    y[n] = f[bitreverse(n)].imag for n = 0 to 1023

*/ comment ~

    ;// esi must point at output 1
    ;// edi must point at output 2

    push ebp

    mov ebx, ifft_pBitReverse
    ASSUME ebx:PTR DWORD
    mov ecx, fft_pData
    ASSUME ecx:PTR DWORD

    xor ebp, ebp    ;// ebp counts and offsets
    mov edx, [ebx]  ;// get bit reverse offset

top_of_loop:

    mov edx, [ebx+ebp]      ;// get bit reverse offset
    mov eax, [ecx+edx]      ;// load real from the data table
    mov edx, [ecx+edx+4]    ;// load imag from data table
    mov [esi+ebp], eax      ;// store real in destination
    mov [edi+ebp], edx      ;// store imag in destination

    add ebp, 4              ;// iterate the counter

    cmp ebp, 1024*4
    jb top_of_loop

    pop ebp

    ret

ifft_output ENDP




ASSUME_AND_ALIGN
ifft_output_window PROC

comment ~ /*

    this is done by grabbing the correct values from fft_pData
    via the ifft_BitReverse table
    then multiplying it by the output window

    x[n] = f[bitreverse(n)].real for n = 0 to 1023
    y[n] = f[bitreverse(n)].imag for n = 0 to 1023

*/ comment ~

    ;// esi must point at output 1
    ;// edi must point at output 2

    push ebp

    mov ebx, ifft_pBitReverse
    ASSUME ebx:PTR DWORD
    mov ecx, fft_pData
    ASSUME ecx:PTR DWORD
    mov edx, ifft_pWindow
    ASSUME edx:PTR DWORD

    ASSUME esi:PTR DWORD
    ASSUME edi:PTR DWORD

    xor ebp, ebp
    mov eax, [ebx]  ;// get bit reverse offset

top_of_loop:

    mov eax, [ebx+ebp]      ;// get bit reverse offset
    fld [edx+ebp]   ;// window
    fld [ecx+eax]   ;// real    window
    fmul st, st(1)  ;// X       window
    fld [ecx+eax+4] ;// imag    X       window
    fmulp st(2), st ;// X       Y
    fstp [esi+ebp]  ;// Y
    fstp [edi+ebp]  ;// empty

    add ebp, 4              ;// iterate the counter

    cmp ebp, 1024*4
    jb top_of_loop

    pop ebp

    ret

ifft_output_window ENDP


;//
;//     output stages
;//
;//
;////////////////////////////////////////////////////////////////////




ASSUME_AND_ALIGN

END