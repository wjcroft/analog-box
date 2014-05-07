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
;// ABox_Delta.asm              ABOX232 added derivative filter, notes at bottom
;//                                     also see differ01 and 02 .mcd

;// TOC:
;//
;// bessel_I0 PROC
;// delta_build_derivative PROC USES edi ebx
;// delta_build_stats PROC USES edi ebx
;//
;// delta_Ctor PROC
;// delta_GetUnit PROC
;//
;// delta_PrePlay PROC
;// delta_Calc PROC
;// derivitive_calc PROC
;//
;// delta_SetShape PROC ;// STDCALL pObject:PTR OSC_OBJECT
;// delta_InitMenu  PROC
;// delta_Command PROC
;// delta_LoadUndo PROC




OPTION CASEMAP:NONE

.586
.MODEL FLAT

USE_THIS_FILE equ 1

IFDEF USE_THIS_FILE

        .NOLIST
        INCLUDE <ABox.inc>
        INCLUDE <fft_abox.inc>
        INCLUDE <szfloat.inc>
        .LIST

.DATA

    ;////////////////////////////////////////////////////////////////////////////
    ;//
    ;//     derivative filter struct
    ;//
    ;// see notes at bottom for how these work
    ;// also see differ01 and 02 .mcd

        DELTA_MAX_POINTS EQU 33
        DELTA_MAX_FRAMES EQU (DELTA_MAX_POINTS-1)/2             ;// =  16 at MAX_POINTS = 33
        DELTA_MAX_DELAYS EQU (DELTA_MAX_POINTS*DELTA_MAX_POINTS-1)/4    ;// = 272 at MAX_POINTS = 33
        ;// totals to 2368 bytes, 592 dwords

        DELTA_DELAY STRUCT

            value   REAL4   0.0 ;// value for the delay
            clist_Declare_link delay, DELTA_DELAY   ;// implements a circular delya buffer

        DELTA_DELAY ENDS


        DELTA_FRAME STRUCT

            coeff       REAL4   0.0             ;// coefficient for this frame
            xfer_coeff  REAL4   0.0             ;// tranfser coefficient = this / prev
            clist_Declare_indirected delay  ;// MRS of the delay list
            slist_Declare_link frame, DELTA_FRAME

        DELTA_FRAME ENDS

        DELTA_DATA STRUCT

            num_points  dd  0       ;// saved, must be odd between 5 and 33
            alpha       REAL4 1.0   ;// saved, must be between 0 and some_max (4 works well)

            sz_peak_bandwidth db 32 DUP (0) ;// display string for peak freq and error therein
            sz_peak_error     db 32 DUP (0)

            sz_zero_bandwidth db 32 DUP (0) ;// display string for first zero crossing bandwidth
            sz_zero_error     db 32 DUP (0)

            align_pad   dd  0   ;// causes frame and delay to be eight byte aligned
                                ;// must be before frame_slist_Head


            slist_Declare_indirected frame  ;// list of frames

            frame   DELTA_FRAME DELTA_MAX_FRAMES DUP ({})   ;// slist of frames
            delay   DELTA_DELAY DELTA_MAX_DELAYS DUP ({})   ;// slist of delays

        DELTA_DATA ENDS

    ;//
    ;//     derivative filter struct
    ;//
    ;////////////////////////////////////////////////////////////////////////////

;////////////////////////////////////////////////////////////////////////////
;//
;//     osc object
;//

osc_Delta OSC_CORE { delta_Ctor,,delta_PrePlay,delta_Calc }
          OSC_GUI  { ,delta_SetShape,,,,delta_Command,delta_InitMenu,,,delta_SaveUndo,delta_LoadUndo,delta_GetUnit }
          OSC_HARD {}

    OSC_DATA_LAYOUT {NEXT_Delta,IDB_DELTA, OFFSET popup_DELTA,,2,12,
        SIZEOF OSC_OBJECT + ( SIZEOF APIN ) * 2,
        SIZEOF OSC_OBJECT + ( SIZEOF APIN ) * 2 + SAMARY_SIZE,
        SIZEOF OSC_OBJECT + ( SIZEOF APIN ) * 2 + SAMARY_SIZE + SIZEOF DELTA_DATA }

    OSC_DISPLAY_LAYOUT {circle_container, DEL_N_PSOURCE,ICON_LAYOUT(8,2,2,4)}

    APIN_init {-1.0,,'x',,   }  ;// input
    APIN_init { 0.0,,'=',,  PIN_OUTPUT   }  ;// output

    short_name  db  'Delta / Derivative',0
    description db  'Delta returns the difference between adjacent samples. Derivative approximates the time derivative of the input signal.',0
    ALIGN 4

    delta_source_list   dd  DEL_N_PSOURCE   ;// normal delta
                        dd  DEL_D_PSOURCE   ;// digital delta
                        dd  DEL_A_PSOURCE   ;// abs delta
                        dd  DEL_E_PSOURCE   ;// dErivative

    ;///////////////////////////////////////////////////////////////////////////////
    ;//
    ;// flags for dword user

        ;// user settings

        DELTA_NORMAL        EQU     00000000h
        DELTA_DIGITAL       EQU     00000001h
        DELTA_ABSOLUTE      EQU     00000002h
        DELTA_DERIVATIVE    EQU     00000003h

        DELTA_TEST          EQU DELTA_DIGITAL OR DELTA_ABSOLUTE OR DELTA_DERIVATIVE

        ;// internal flags

        DELTA_REBUILD_DERIVATIVE    EQU 80000000h   ;// need to recreate the filter
        DELTA_NEED_INTERPOLATE      EQU 40000000h   ;// true if derivitive was rebuilt
        DELTA_REBUILD_STATS         EQU 20000000h   ;// need to derive the filter stats
        DELTA_DERIVATIVE_CHANGING   EQU 10000000h   ;// true if last input frame had changing data

    ;// flags for dword user
    ;//
    ;///////////////////////////////////////////////////////////////////////////////

    ;// min/default/max values

        DELTA_MIN_POINTS EQU    5
        DELTA_MAX_POINTS EQU    DELTA_MAX_POINTS

        delta_max_alpha REAL4   4.0         ;// min is zero

        delta_scroll_from_alpha REAL4 64.0  ;// 3.75    ;// 28.333333   ;// 256 / (max-min)

        EXTERNDEF delta_def_points:DWORD;// needed by osc_Delta_xlate
        EXTERNDEF delta_def_alpha:REAL4 ;// needed by osc_Delta_xlate

        DELTA_DEF_POINTS    EQU     7
        delta_def_points    dd   DELTA_DEF_POINTS
        delta_def_alpha     REAL4   1.0

    ;// button_id_table makes setting up dialogs a little easier

        delta_button_id_table LABEL DWORD

            dd ID_DELTA_NORMAL
            dd ID_DELTA_DIGITAL
            dd ID_DELTA_ABSOLUTE
            dd ID_DELTA_DERIVATIVE

    ;// format of the stats window on the popup panel

        fmt_delta_stats db  'peak: %s %s',0dh,0ah
                        db  'zero: %s %s',0
        ALIGN 4

    ;// last input value stored in I dwUser
    ;// data maintains derivative filter

        DELTA_OSC_MAP   STRUCT

            OSC_OBJECT   {}
            pin_i   APIN {}
            pin_o   APIN {}
            data_o  dd  SAMARY_LENGTH dup (0)
            dat     DELTA_DATA {}

        DELTA_OSC_MAP ENDS



.CODE



;///////////////////////////////////////////////////////////////////////////////////////
;//
;//
;//     derivative support

ASSUME_AND_ALIGN
bessel_I0 PROC

    ;// computes I0(X) until add value is no longer significant
    ;// enter:  FPU = X
    ;//         NEED FIVE MORE FPU REGISTERS for a total of SIX
    ;// exit:   FPU = I0(X)
    ;//
    ;// destroys eax


    comment ~ /*
    see differ01.mcd for deriviation of this algorithm

        we have X on top
        we have P on bottom

        at each iteration n:    n += 2
                                X[n] *= X * X
                                P[n] *= n * n
                                S[n] += X[n] / P[n]


            start with  S[0] = 1
                        X[0] = 1
                        P[0] = 1
                        n = 0

            stop when S[n-1] - X[n]/P[n] is insignificant

            meaning dS / S < 2^24

    */ comment ~

                            ;// X

    ;// check for zero first !!

        fabs    ;// account for neg zero
        ftst    ;// check for zero
        fnstsw ax
        sahf
        jz got_zero

    ;// rather than fill up the fpu
    ;// we'll use a value on the stack

        pushd 2
        st_n TEXTEQU <(DWORD PTR [esp])>

        fmul st, st
        fld1            ;// S   X2
        fld1            ;// Pn  S   X2
        fld1            ;// Xn  Pn  S   X2

        top_of_loop:

            fmul st, st(3)  ;// XX  Pn  S   X2
            fild st_n       ;// n   XX  Pn  S   X2
            fmul st(2), st  ;// XX  Pnn S   X2
            fmulp st(2), st ;// Xn  Pn  S   X2

            fld st          ;// Xn  Xn  Pn  S   X2
            fdiv st, st(2)  ;// dS  Xn  Pn  S   X2

            fld st(3)       ;// S   dS  Xn  Pn  S   X2
            fxch            ;// dS  S   Xn  Pn  new X2
            fadd st(4), st  ;//
            fdiv            ;// sig Xn  Pn  new X2
            fabs
            fcomp math_2_24 ;// Xn  Pn  S   X2
            fnstsw ax
            add st_n, 2
            sahf
            jb top_of_loop

        add esp, 4  ;// Xn  Pn  S   X2
        fstp st     ;// Pn  S   X2
        fstp st     ;// S   X2
        fxch        ;// X2  S
        fstp st     ;// S

    ;// that's it !
    all_done:

        ret


    ALIGN 16
    got_zero:

        fstp st
        fld1
        jmp all_done

bessel_I0 ENDP

ASSUME_AND_ALIGN
delta_build_derivative PROC USES edi ebx

        ASSUME esi:PTR DELTA_OSC_MAP    ;// preserve
        ;// destroys eax ecx edx

    ;// num_points and alpha must be set
    ;// by the off chance that they are not, we do that here

        fld [esi].dat.alpha
        fldz    ;// fld delta_min_alpha
        fcom st(1)
        fnstsw ax
        sahf
        jbe A0
        fxch
        jmp A1
    A0: fstp st
        fld delta_max_alpha
        fcom st(1)
        fnstsw ax
        sahf
        jae A1
        fxch
    A1: fstp st
        fstp [esi].dat.alpha

        mov eax, [esi].dat.num_points
        mov edx, DELTA_MIN_POINTS
        or eax, 1   ;// must be an odd number
        mov ecx, DELTA_MAX_POINTS
        CMPJMP eax, edx, jge B0
        MOVJMP eax, edx, jmp B1
    B0: CMPJMP eax, ecx, jle B1
        mov eax, ecx
    B1: mov [esi].dat.num_points, eax

    ;// clear the existing data and lists

        DATA_CLEAR_SIZE EQU 4 + (SIZEOF DELTA_FRAME) * DELTA_MAX_FRAMES + (SIZEOF DELTA_DELAY) * DELTA_MAX_DELAYS

        lea edi, slist_Head(frame,[esi].dat)
        mov ecx, DATA_CLEAR_SIZE / 4
        xor eax, eax
        rep stosd

    ;// we'll need some constants, compute and store them now

        sub esp, 12
        st_pi_aC    TEXTEQU <(DWORD PTR [esp+12])>  ;// = pi * alpha / C
        st_Ipi      TEXTEQU <(QWORD PTR [esp])>     ;// = I0(pi*alpha)*pi

        fldpi
        fmul [esi].dat.alpha        ;// pi*a

        fld st
        fidiv [esi].dat.num_points  ;// pi*a/C  pi*a
        fstp st_pi_aC               ;// pi*a

        invoke bessel_I0            ;// I0(pi*alpha)
        fldpi
        fmul                        ;// I0(pi*alpha)*pi
        fstp st_Ipi                 ;// empty

    ;// create frames and assign data to them

        lea edi, [esi].dat.frame    ;// iterator of frames
        ASSUME edi:PTR DELTA_FRAME
        lea ebx, [esi].dat.delay    ;// iterator of delays
        ASSUME ebx:PTR DELTA_DELAY

        mov ecx, 1          ;// allocate the lowest size first
        lea edx, [ecx*2]    ;// which causes frames to end up in a time sequenced order
                            ;// meaning b4 b3 b2 b1 b0 ....
        .REPEAT

        ;// allocate a new frame

            slist_InsertHead frame, edi, ,[esi].dat ;// allocate this frame
            mov [edi].coeff, ecx    ;// store c as integer

        ;// allocate the data for the frame
        ;// edx defined at end of loop

            .REPEAT
                clist_Insert delay, ebx, ,edi   ;// link into list
                add ebx, SIZEOF DELTA_DELAY     ;// advance to next delay slot
                dec edx                         ;// decrease the count
            .UNTIL ZERO?

        ;// compute the coefficient
        ;// see differ022.mcd

        ;// even(c) = -c if c is even
        ;//         = +c if c is odd

        ;//         I0( pi_aC * sqrt ( C^2 - 4*c^2 ) )
        ;// coeff = -------------------------------------
        ;//                  even(c) * Ipi

            fild [esi].dat.num_points
            fmul st, st         ;// C^2
            fild [edi].coeff    ;// c       C^2
            fmul st, st         ;// c^2     C^2
            fadd st, st         ;// 2c^2    C^2
            fadd st, st         ;// 4c^2    C^2
            fsub                ;// C^2-4c^2
            fsqrt
            fmul st_pi_aC
            invoke bessel_I0;// I0

            test ecx, 1
            fild [edi].coeff
            .IF ZERO?   ;// is even
                fchs
            .ENDIF
            fmul st_Ipi         ;// cIpi    I0()
            fdiv                ;// I0/cIpi

            fstp [edi].coeff    ;// empty

        ;// advance to next frame

            add edi, SIZEOF DELTA_FRAME

        ;// increase the count and check if we're done

            inc ecx
            lea edx, [ecx*2]

        .UNTIL edx >= [esi].dat.num_points

    ;// now we are done !
    ;// clean up the stack

        add esp, 12
        st_pi_aC    TEXTEQU <>
        st_Ipi      TEXTEQU <>

    ;// now we run through the list forwards and build the transfer coefficients

        slist_GetHead frame, edi, [esi].dat
    C0: slist_GetNext frame, edi, ebx
        TESTJMP ebx, ebx, jz C1
        fld [ebx].coeff         ;// this
        fdiv [edi].coeff        ;// this / prev
        mov edi, ebx
        fstp [ebx].xfer_coeff   ;// store
        jmp C0

    C1:

    ;// that's it !! adjust flags and beat it

    ;// always set the rebuild stats flag

        and [esi].dwUser, NOT DELTA_REBUILD_DERIVATIVE
        or [esi].dwUser, DELTA_REBUILD_STATS OR DELTA_DERIVATIVE_CHANGING OR DELTA_NEED_INTERPOLATE

        ret

delta_build_derivative ENDP


ASSUME_AND_ALIGN
delta_build_stats PROC USES edi ebx

        ASSUME esi:PTR DELTA_OSC_MAP

    ;// this one's a mess
    ;// we have the filter coefficients
    ;// we need to do an inverse FFT on them, then scan the results
    ;// see differ02.mcd

    ;// allocate 1 array for the FFT's

    ;// put the filter parameters into the spectrum
    ;// each must be in the immaginary part

    ;// scan the resulting ifft starting at the middle
    ;// determine 1 of two possible bandwidth scemes

    ;// this function is only called from the gui thread
    ;// we must be careful to interlock with the fft

ENTER_PLAY_SYNC GUI

    ;// always check if we need to rebuild he filter

        .IF [esi].dwUser & DELTA_REBUILD_DERIVATIVE

            invoke delta_build_derivative

        .ENDIF

    ;// allocate the fft fram on the stack

        sub esp, SAMARY_SIZE    ;// make a full data frame
        mov edi, esp
        mov ecx, SAMARY_LENGTH
        xor eax, eax
        rep stosd

    ;// xfer the filter coefficients to the array
    ;// coefficents are accessed in reversed order
    ;// thus we reverse index

        slist_GetHead frame, edi, [esi].dat
        mov ecx, [esi].dat.num_points   ;// indexer
        shr ecx, 1  ;// 1/2

        .REPEAT
            mov eax, [edi].coeff
            ;//mov [esp+ecx*8], eax ;// store as imaginary part, oops, first bin doesn't have imaginary part
            mov [esp+ecx*8+4], eax  ;// store as imaginary part (now correct after fixing the fft)
            dec ecx
            DEBUG_IF <SIGN?>    ;// not supposed to happen !!
            slist_GetNext frame, edi
        .UNTIL !edi

    ;// call the ifft function, use the stack for both ins and outs

        mov eax, esp
        push esi        ;// fft will destroy this

        push eax        ;// push detination 2
        push eax        ;// push destination 1
        pushd FFT_REVERSE + FFT_1024    ;// set the fft flags
        push eax        ;// push source 2
        push eax        ;// push source 1
        call fft_Run    ;// do it

        pop esi         ;// retrieve esi

    ;// now we have the frequency response and we need to scan it
    ;// we start in the center and work down the stack
    comment ~ /*

        here is the algorithm we use

        1) find the peak of the response

            save this in edx
            also save and format as the peak error

        2) begin computing error responses, but do not track maximum yet

            we have two cases for the error response
            1) error response crosses zero

                in this case we track where it crosses zero
                this is the lowest possible bandwidth
                save in edx

                21a) then scan for the maximum error AFTER crossing zero

                21b) advance the first zero crossing up the responce
                    until it surpasses the max error
                    this then sets the bandwidth and max error

            2) error response does not cross zero

                in this case we use the error AT the peak of the response

    */ comment ~

    ;// 1)  find the peak of the response curve
    ;//     first peak will be highest absolute point

            lea ecx, [esp + (SAMARY_LENGTH/2-1)*4]  ;// half spectrum
            ASSUME ecx:PTR DWORD
            fldz            ;// max
        A0: fld [ecx]       ;// new max
            fucom st(1)
            fnstsw ax
            sahf
            jb A1   ;// exit if done
            fxch
            sub ecx, 4
            DEBUG_IF < ecx !<= esp >    ;// thought this wouldn't happen
            fstp st
            jmp A0
        A1: ;// ecx has one before the max index
            ;// fpu has one extra value and the max

            lea edx, [ecx+4]    ;// edx now points at the maximum
            ASSUME edx:PTR DWORD

            ;// FPU         ;// old     peak

    ;// 2)  determine where the error response crosses zero
    ;//     compute the error for this point err(ecx) = ideal(ecx) - value(ecx)
    ;//     this will be a positive number until it crosses zero

            fstp st
            fstp st         ;// empty

        ;// determine the ideal for edx

            mov eax, edx
            sub eax, esp
            shr eax, 2      ;// now an index
            push eax
            fild DWORD PTR [esp]
            add esp, 4
            fmul math_1_1024;// ideal(edx)

            fld st          ;// ideal   ideal_peak

        ;// compute and format the peak error

            push ecx
            push edx

            fld st
            fadd st, st     ;// freq
            invoke unit_BuildString, ADDR [esi].dat.sz_peak_bandwidth, UNIT_HERTZ, 0

            mov edx, [esp]
            fld [edx]
            fsubr st, st(1)
            fabs
            invoke unit_BuildString, ADDR [esi].dat.sz_peak_error, UNIT_DB, 0

            pop edx
            pop ecx

        ;// scan down the stack until ideal-[ecx] goes negative

        B0: fsub math_1_1024;// ideal   ideal_peak
            fld [ecx]       ;// val     ideal   ideal_peak
            fsubr st, st(1) ;// err     ideal   ideal_peak
            ftst            ;// err     ideal   ideal_peak
            fstp st         ;// ideal   ideal_peak
            fnstsw ax
            sahf
            jc got_neg_response
            ;// next values
            sub ecx, 4
            cmp ecx, esp
            ja B0

        no_neg_response:
        ;// we have no neg response
        ;// thus we edx to compute the err and the bandwidth
        ;// thus we have no sz_zero strings

            fstp st         ;// ideal_peak
            fstp st
            mov DWORD PTR [esi].dat.sz_zero_bandwidth, 'enon'
            mov DWORD PTR [esi].dat.sz_zero_bandwidth[4], 0
            mov DWORD PTR [esi].dat.sz_zero_error[0], 0

            jmp done_with_scans

    ;// we have a neg response

        got_neg_response:
        ;// ecx has the point that crossed zero
        ;// ideal is correct for the ecx value

            lea edx, [ecx+4];// new marker
    ;oops   fadd math_1_1024;// ideal0  ideal_peak
            fst st(1)       ;// ideal0  ideal0

            fldz            ;// max     ideal   ideal0
            fxch            ;// ideal   max     ideal0

        C0: sub ecx, 4
            fsub math_1_1024
            cmp ecx, esp
            jbe C2

            fld [ecx]       ;// val     ideal   max     ideal0
            fsubr st, st(1) ;// err     ideal   max     ideal0
            fabs
            fucom st(2)
            fnstsw ax
            sahf
            jbe C1
            fxch st(2)      ;// old     ideal   new     ideal0
        C1: fstp st         ;// ideal   max     ideal0
            jmp C0
        C2: ;// now we have fpu with max error

        ;// next task is to scan edx up until it surpasses max error
        ;// ideal0 is already correct for this purpose

            fstp st         ;// max     ideal0
            fxch            ;// ideal   max
            fadd math_1_1024;oops

            IFDEF DEBUGBUILD
            lea ecx, [esp + (SAMARY_LENGTH/2-1)*4]  ;// half spectrum
            ENDIF

        D0: add edx, 4
            DEBUG_IF < edx !>= ecx >    ;// not supposed to happen !!
            fadd math_1_1024;// iterate
            fld [edx]       ;// val     ideal   max
            fsubr st, st(1) ;// err     ideal   max
            fabs
            fucomp st(2)    ;// ideal   max
            fnstsw ax
            sahf
            jb D0

        ;// now we have edx as the one that surpassed the max

        ;oops   sub edx, 4
            fstp st         ;// max_error
            sub edx, esp
            shr edx, 2      ;// index of highest
            push edx
            fild DWORD PTR [esp]
            fmul math_1_512
            add esp, 4
            invoke unit_BuildString, ADDR [esi].dat.sz_zero_bandwidth, UNIT_HERTZ, 0

            invoke unit_BuildString, ADDR [esi].dat.sz_zero_error, UNIT_DB, 0

            ;// fpu is empty

    ;// we are done with the stack

    done_with_scans:

        add esp, SAMARY_SIZE

    ;// whew ! we are done,
    ;// exit interlock and turn the flag off

        and [esi].dwUser, NOT DELTA_REBUILD_STATS

LEAVE_PLAY_SYNC GUI

        ret

delta_build_stats ENDP





;//     derivative support
;//
;//
;///////////////////////////////////////////////////////////////////////////////////////





ASSUME_AND_ALIGN
delta_Ctor PROC

        ;// register call
        ASSUME ebp:PTR LIST_CONTEXT ;// preserve
        ASSUME esi:PTR DELTA_OSC_MAP    ;// preserve
        ASSUME edi:PTR OSC_BASE     ;// may destroy
        ASSUME ebx:PTR FILE_OSC     ;// may destroy
        ASSUME edx:PTR FILE_HEADER  ;// may destroy

    ;// make sure the coefficients get built

        or [esi].dwUser, DELTA_REBUILD_DERIVATIVE OR DELTA_REBUILD_STATS

    ;// if we're not loading from a file
    ;// initialize the derivative with defaults

        .IF !edx    ;// not loading from file

            mov eax, delta_def_alpha
            mov [esi].dat.alpha, eax
            mov [esi].dat.num_points, DELTA_DEF_POINTS

        .ENDIF

    ;// that should do it

        ret

delta_Ctor ENDP


;////////////////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
delta_GetUnit PROC

        ASSUME esi:PTR DELTA_OSC_MAP    ;// must preserve
        ASSUME ebx:PTR APIN     ;// must preserve

    ;// must preserve edi and ebp

        lea ecx, [esi].pin_i
        .IF ecx == ebx
            lea ecx, [esi].pin_o
        .ENDIF
        ASSUME ecx:PTR APIN

        mov eax, [ecx].dwStatus
        BITT eax, UNIT_AUTOED

        ret


delta_GetUnit ENDP




;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;///
;///
;///        delta calc


ASSUME_AND_ALIGN
delta_PrePlay PROC

    ASSUME esi:PTR DELTA_OSC_MAP

    ;// reset I.dwUser to 0

        xor eax, eax
        OSC_TO_PIN_INDEX esi, ecx, 0
        mov [ecx].dwUser, eax

    ;// eax is zero, so pre play will erase our data

        ret

delta_PrePlay ENDP




;// MACROS for calc in delta modes



DC_STORE MACRO mode:req, Y:req

    LOCAL J1

    IFIDN <mode>,<DIGITAL>
    ;////////////////// digital delta
        fabs
        ftst
        fnstsw ax
        fstp Y
        sahf
        jz J1
        or Y, neg_mask
    ;//////////////////
    ELSEIFIDN <mode>,<ABSOLUTE>
    ;////////////////// absolute delta
        fabs
        ftst
        fnstsw ax
        fstp Y
        sahf
        jnz J1
        or Y, neg_mask
    ;//////////////////
    ELSEIFIDN <mode>,<NORMAL>
    ;////////////////// normal delta
        fstp Y
    ;//////////////////
    ELSE
        .ERR <invalid mode parameter>
    ENDIF

    J1:

    ENDM

;// x0  x1  x2
;// y0  y1  y2
;//
;// y0 already done
;// y1 = x1-x0  ; can trash x0
;// y2 = x2-x1  ; y2 will be y0 for next loop


    DC_LOOP MACRO mode:req

        xor eax, eax

    .REPEAT

        fld [edx+ecx*4]     ;// x1      x0
        fxch                ;// x0      x1
        fsubr st, st(1)     ;// y1      x1
        fxch                ;// x1      y1
        fld [edx+ecx*4+4]   ;// x2      x1      y1

        fsubr st(1), st     ;// x2      y2      y1

        fxch st(2)          ;// y1      y2      x2

        DC_STORE mode, [edi+ecx*4]  ;// y1      y2      x2

        inc ecx

        DC_STORE mode, [edi+ecx*4];// x2

        inc ecx

    .UNTIL ecx >= SAMARY_LENGTH

        fstp [esi].pin_i.dwUser

        ENDM








ASSUME_AND_ALIGN
delta_Calc PROC

        ASSUME esi:PTR DELTA_OSC_MAP

        DEBUG_IF <!![esi].pin_o.pPin>   ;// output is supposed to be connected

        mov eax, [esi].dwUser       ;// get the object settings
        and eax, DELTA_TEST         ;// remove all but idex
        cmp eax, DELTA_DERIVATIVE
        je derivitive_calc          ;// jump if we are the derivitive

        mov ebx, [esi].pin_i.pPin   ;// get the input connection
        ASSUME ebx:PTR APIN
        lea edi, [esi].data_o       ;// point at output data
        or ebx, ebx                 ;// input connected ?
        ASSUME edi:PTR DWORD
        jz delta_nX

    delta_sX_or_dX:

        fld [esi].pin_i.dwUser      ;// get the previous value
        mov edx, [ebx].pData        ;// get the data pointer
        ASSUME edx:PTR DWORD
        xor ecx, ecx                ;// reset the scan length
        test [ebx].dwStatus, PIN_CHANGING
        mov ebx, 80000000h          ;// load the neg mask

        neg_mask TEXTEQU <ebx>

        jz delta_sX

    ;////////////////////////////////////////////////

    delta_dX:

        and eax, DELTA_DIGITAL OR DELTA_ABSOLUTE
        jz delta_dX_normal
        and eax, DELTA_DIGITAL
        jz delta_dX_absolute

    delta_dX_digital:

        DC_LOOP DIGITAL
        or [esi].pin_o.dwStatus, PIN_CHANGING
        jmp all_done

    delta_dX_absolute:

        DC_LOOP ABSOLUTE
        or [esi].pin_o.dwStatus, PIN_CHANGING
        jmp all_done

    delta_dX_normal:

        DC_LOOP NORMAL
        or [esi].pin_o.dwStatus, PIN_CHANGING
        jmp all_done

    ;////////////////////////////////////////////////


    delta_sX:

        fld [edx]
        fxch
        fsubr st, st(1)

        and eax, DELTA_DIGITAL OR DELTA_ABSOLUTE
        jz delta_sX_normal
        and eax, DELTA_DIGITAL
        jz delta_sX_absolute

    delta_sX_digital:

        DC_STORE DIGITAL, [edi]
        xor ebx, ebx        ;// the rest of the frame
        jmp delta_sX_done

    delta_sX_absolute:

        DC_STORE ABSOLUTE, [edi]
        ;// ebx is already neg zero
        jmp delta_sX_done

    delta_sX_normal:

        DC_STORE NORMAL, [edi]
        xor ebx, ebx        ;// the rest of the frame

    delta_sX_done:

        fstp [esi].pin_i.dwUser

        ;// prev        1st =
        ;// changing    zero
        ;//  no         no      fill the rest       set changing
        ;//  yes        no      fill the rest       set changing
        ;//  no         yes     done
        ;//  yes        yes     fill the rest       reset changing

        cmp ebx, [edi]  ;// 1st = zero ?
        je @F           ;// jump forward if yes
        or [esi].pin_o.dwStatus, PIN_CHANGING   ;// set changing
        jmp delta_sX_fill                       ;// jump to fill
    @@: btr [esi].pin_o.dwStatus, LOG2(PIN_CHANGING)    ;// prev changing ?
        jnc all_done    ;// done if prev was not changing

    delta_sX_fill:

        mov ecx, SAMARY_LENGTH - 1
        add edi, 4
        jmp delta_fill

    ;////////////////////////////////////////////////

    delta_nX:

        and eax, DELTA_ABSOLUTE
        jnz delta_nX_fill

    delta_nX_digital:
    delta_nX_normal:

        xor ebx, ebx    ;// fill with zero

    delta_nX_absolute:  ;// ebx is already correct

    delta_nX_fill:

        btr [esi].pin_o.dwStatus, LOG2(PIN_CHANGING)
        mov ecx, SAMARY_LENGTH - 1
        jc delta_fill
        cmp ebx, [edi]
        je all_done


    delta_fill:

        mov eax, ebx
        rep stosd

    all_done:

        ret

delta_Calc ENDP



comment ~ /*
debugging code, can be ignored, or reused later

;/////////////////////////////////////////////////////////
;//
IFDEF USE_DEBUGING_CODE
ECHO BUG HUNT CODE !!!

;// declare counter interate counter and open the file

    .DATA
    debug_counter   dd  -1
    debug_file      dd  0
    sz_delta_bug_hunt db 'delta_bug_hunt.txt',0
    ALIGN 4
    .CODE
    inc debug_counter
    .IF !debug_counter
        invoke CreateFileA, OFFSET sz_delta_bug_hunt, GENERIC_WRITE, FILE_SHARE_READ, 0, CREATE_ALWAYS, 0, 0
        mov debug_file, eax
    .ENDIF

ECHO BUG HUNT CODE !!!
ENDIF ;// USE_DEBUGING_CODE
;//
;/////////////////////////////////////////////////////////

;/////////////////////////////////////////////////////////
;//
IFDEF USE_DEBUGING_CODE
ECHO BUG HUNT CODE !!!

;// dump the frames and their delays
;// can be used every sample

    .IF debug_file
    pushad

        sub esp, 256

    ;// input sample

        fld [ebp+ecx*4-4]
        mov edi, esp
        mov edx, FLOATSZ_DIG_3 OR FLOATSZ_FIX
        invoke float_to_sz
        ;// edi iterated to end of text
        mov eax, 0a0dh
        stosw
        sub edi, esp    ;// length
        mov ecx, esp
        invoke WriteFile, debug_file, ecx, edi, esp, 0

    ;// iterate the frames

        slist_GetHead frame, ebp, [esi].dat
        .REPEAT
            ;// "frame: coeff %s delay:"
            .DATA
            fmt_frame_1 dd 'marf','=b e'
            fmt_frame_2 dd '=bx '
            fmt_frame_3 dd 'ed  ','  :l'
            .CODE
            mov edi, esp
            mov eax, fmt_frame_1
            stosd
            mov eax, fmt_frame_1[4]
            stosd
            fld [ebp].coeff
            mov edx, FLOATSZ_DIG_3 OR FLOATSZ_SCI
            invoke float_to_sz
            .WHILE edi & 7
                mov al, ' '
                stosb
            .ENDW
            mov eax, fmt_frame_2
            stosd
            fld [ebp].xfer_coeff
            mov edx, FLOATSZ_DIG_3 OR FLOATSZ_SCI
            invoke float_to_sz
            .WHILE edi & 7
                mov al, ' '
                stosb
            .ENDW
            mov eax, fmt_frame_3
            stosd
            mov eax, fmt_frame_3[4]
            stosd

            clist_GetMRS delay, ebx, ebp
            .REPEAT
                ;// value
                fld [ebx].value
                mov edx, FLOATSZ_DIG_3 OR FLOATSZ_SCI
                invoke float_to_sz
                mov eax, '    '
                stosb
                .WHILE edi & 7
                    mov al, ' '
                    stosb
                .ENDW
                clist_GetNext delay, ebx
            .UNTIL ebx == clist_MRS(delay,ebp)
            ;// line feed and print
            mov eax, 0a0dh
            stosw
            sub edi, esp
            mov ecx, esp
            invoke WriteFile, debug_file, ecx, edi, esp, 0

            slist_GetNext frame, ebp
        .UNTIL !ebp
        ;// linefeed
        mov edi, esp
        mov eax, 0a0dh
        stosw
        sub edi, esp
        mov ecx, esp
        invoke WriteFile, debug_file, ecx, edi, esp, 0

        add esp, 256

    popad
    .ENDIF

ECHO BUG HUNT CODE !!!
ENDIF   ;// USE_DEBUGING_CODE
;//
;/////////////////////////////////////////////////////////

;/////////////////////////////////////////////////////////
;//
IFDEF USE_DEBUGING_CODE
ECHO BUG HUNT CODE !!!

;// close the file if it's opened

    .IF debug_file
        invoke CloseHandle, debug_file
        mov debug_file, 0
    .ENDIF

ECHO BUG HUNT CODE !!!
ENDIF ;// USE_DEBUGING_CODE
;//
;/////////////////////////////////////////////////////////


*/ comment ~



ASSUME_AND_ALIGN
derivitive_calc PROC USES ebp

        ASSUME esi:PTR DELTA_OSC_MAP    ;// preserve

    ;// registers

    ;// edi:edx = fNow delay
    ;// ebx:eax = fPrev delay
    ;// ecx sample counter
    ;// ebp input data ptr
    ;// esi DELTA_OSC_MAP

    ;// get the input source

        xor ecx, ecx
        OR_GET_PIN_FROM ecx, [esi].pin_i.pPin
        .IF ZERO?
            mov ecx, math_pNullPin
        .ENDIF
        mov ebp, [ecx].pData
        ASSUME ebp:PTR DWORD

    ;// get and xfer the last values now

        mov eax, [ebp]              ;// get the first value in the frame
        mov edx, [esi].pin_i.dwUser ;// get the last value
        mov [esi].pin_i.dwUser, eax ;// save it now

    ;// check if we need to rebuild

        TESTJMP [esi].dwUser, DELTA_REBUILD_DERIVATIVE OR DELTA_NEED_INTERPOLATE, jnz interpolate_between_frames

    ;// we can skip the calc
    ;// IF  this value and the last value are the same number
    ;// AND this input and the last were not changing

        .IF !([ecx].dwStatus & PIN_CHANGING)
            .IF eax == edx              ;// don't turn off our changing if values not same
                BITR [esi].dwUser, DELTA_DERIVATIVE_CHANGING    ;// test and resetlast frame was not changing
                .IF !CARRY?
                    and [esi].pin_o.dwStatus, NOT PIN_CHANGING
                    jmp all_done
                .ENDIF
            .ENDIF
        .ELSE
            or [esi].dwUser, DELTA_DERIVATIVE_CHANGING  ;// last frame is changing
        .ENDIF

    ;// here we go with the full derivitive calc

        xor ecx, ecx        ;// iterate through all the sample

        full_derivative_calc:   ;// iterate through remaining samples

        ;// first element in delay has no previous frame

            ASSUME ebx:PTR DELTA_FRAME  ;// forward ref

            slist_GetHead frame, edi, [esi].dat

            clist_GetMRS  delay, edx, edi    ;// edx is fNow.delay_now
            clist_GetNext delay, edx         ;// edx if fNow.delay_most_past
            ;// instructions            FPU INT
            fld   [edx].value           ;// load the stored value
            fld   [ebp+ecx*4]           ;// load the input sample
            fmul  [edi].coeff           ;// multiply by the coeff
            mov ebx, edi                    ;// advance fPrev to fNow
            slist_GetNext frame, edi        ;// advance fNow to fNext
            fst   [edx].value           ;// store the value in the delay
            fsubr                       ;// subtract to get the running total
            ;// the next elements in the delay do have a previous
            full_derivitive_inner:      ;// iterate through the frames
                ;// instructions            FPU INT
                clist_GetMRS  delay, edx, edi    ;// edx is fNow.delay_now
                clist_GetNext delay, edx         ;// edx if fNow.delay_most_past
                clist_GetMRS  delay, eax, ebx    ;// eax is fPrev.pData
                fsub  [edx].value           ;// subtract fNow.most_past from running total
                fld   [eax].value           ;// load fPrev.one_past
                fmul  [edi].xfer_coeff      ;// multiply by fNow.xfer_coeff
                clist_GetNext delay, eax        ;// advance fPrev
                clist_SetMRS  delay, eax, ebx   ;// iterate fPrev
                fst   [edx].value           ;// store results in fNow.next_sample
                mov ebx, edi                    ;// advance fPrev to fNow
                slist_GetNext frame, edi        ;// advance fNow to fNext
                test edi, edi                   ;// see if end of list
                fadd                        ;// add to running total
                jnz full_derivitive_inner       ;// back to top of inner
            ;// end of frame list
            clist_GetMRS  delay, eax, ebx   ;// iterate the previous frame
            clist_GetNext delay, eax        ;// advance previous delay
            fstp [esi].data_o[ecx*4]        ;// store the output data
            clist_SetMRS  delay, eax, ebx   ;// iterate the previous frame
            inc ecx                         ;// next sample
            cmp ecx, SAMARY_LENGTH
            jb full_derivative_calc

    ;// done with full derivative calc

    ;// set pin changing

        or [esi].pin_o.dwStatus, PIN_CHANGING


    ;// that's it
    all_done:

        ret

    ALIGN 16
    interpolate_between_frames:
    ;// state: ebp has input data
    ;//
    ;// this requires a special interpolation
    ;// we will multiplex the last sample with the first N samples of the new
    ;// then jump back into main derivative calc

        .IF [esi].dwUser & DELTA_REBUILD_DERIVATIVE

            invoke delta_build_derivative   ;// turns on DELTA_DERIVATIVE_CHANGING

        .ENDIF

        and [esi].dwUser, NOT DELTA_NEED_INTERPOLATE

    ;// L = value of last output sample
    ;// n = counter for this scan
    ;// N = number of points to smooth
    ;//
    ;// store = Y[n] * n/N + L * (N-n)/N
    ;// --or--
    ;// dL = -L/N
    ;// dM = 1/N
    ;// store[n] = Y[n] * M + L
    ;//     M += dM
    ;//     L += dL

        fld [esi].data_o[LAST_SAMPLE]   ;// L

        DELTA_INTERPOLATE_LENGTH EQU 64 ;// make sure to load the correct scaling factor
        fld math_1_64           ;// dM  L   ;// make sure to load the correct scaling factor

        fld st(1)               ;// L   dM  L
        fmul st, st(1)          ;// -dL dM  L
        fchs                    ;// dL  dM  L
        fldz                    ;// M   dL  dM  L

        xor ecx, ecx
        ;// see full_derivative_calc for better commentary
        part_derivative_calc:   ;// iterate through remaining samples
            slist_GetHead frame, edi, [esi].dat
            clist_GetMRS  delay, edx, edi    ;// edx is fNow.delay_now
            clist_GetNext delay, edx         ;// edx if fNow.delay_most_past
            fld   [edx].value           ;// load the stored value
            fld   [ebp+ecx*4]           ;// load the input sample
            fmul  [edi].coeff           ;// multiply by the coeff
            mov ebx, edi                    ;// advance fPrev to fNow
            slist_GetNext frame, edi        ;// advance fNow to fNext
            fst   [edx].value           ;// store the value in the delay
            fsubr                       ;// subtract to get the running total
            part_derivitive_inner:      ;// iterate through the frames
                clist_GetMRS  delay, edx, edi    ;// edx is fNow.delay_now
                clist_GetNext delay, edx         ;// edx if fNow.delay_most_past
                clist_GetMRS  delay, eax, ebx    ;// eax is fPrev.pData
                fsub  [edx].value           ;// subtract fNow.most_past from running total
                fld   [eax].value           ;// load fPrev.one_past
                fmul  [edi].xfer_coeff      ;// multiply by fNow.xfer_coeff
                clist_GetNext delay, eax        ;// advance fPrev
                clist_SetMRS  delay, eax, ebx   ;// iterate fPrev
                fst   [edx].value           ;// store results in fNow.next_sample
                mov ebx, edi                    ;// advance fPrev to fNow
                slist_GetNext frame, edi        ;// advance fNow to fNext
                test edi, edi                   ;// see if end of list
                fadd                        ;// add to running total
                jnz part_derivitive_inner       ;// back to top of inner
            ;// end of frame list
            clist_GetMRS  delay, eax, ebx   ;// iterate the previous frame
            clist_GetNext delay, eax        ;// advance previous delay
            clist_SetMRS  delay, eax, ebx   ;// iterate the previous frame
            ;// interpolate             ;// Y   M   dL  dM  L
            ;// store[n] = Y[n] * M + L
            ;//     M += dM
            ;//     L += dL
                fmul st, st(1)
                fadd st, st(4)
                fstp [esi].data_o[ecx*4]    ;// store the output data
                ;// advance             ;// M   dL  dM  L
                fadd st, st(2)          ;// M+dM
                fxch                    ;// dL  M   dM  L
                fadd st(3), st          ;// dL  M   dM  L+dL
                fxch                    ;// M   dL  dM  L
            ;// back to normal
            inc ecx                         ;// next sample
            cmp ecx, DELTA_INTERPOLATE_LENGTH
            jb part_derivative_calc

        ;// now we clean out the fpu and jump back to normal full_calc

            fstp st
            fstp st
            fstp st
            fstp st

            jmp full_derivative_calc




derivitive_calc ENDP






















;///        delta calc
;///
;///
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////





ASSUME_AND_ALIGN
delta_SetShape PROC ;// STDCALL pObject:PTR OSC_OBJECT

    ASSUME esi:PTR OSC_OBJECT   ;// esi is object, PRESERVE

    mov ecx, [esi].dwUser
    and ecx, DELTA_TEST
    mov eax, delta_source_list[ecx*4]
    mov [esi].pSource, eax

    jmp osc_SetShape


delta_SetShape ENDP


ASSUME_AND_ALIGN
delta_InitMenu  PROC USES edi ebx

        ASSUME esi:PTR DELTA_OSC_MAP    ;// esi is object, PRESERVE

        mov ebx, [esi].dwUser
        and ebx, DELTA_TEST

    ;// set the corect mode button

        invoke CheckDlgButton, popup_hWnd, delta_button_id_table[ebx*4], BST_CHECKED

    ;// enable or disable the derivative buttons

        .IF ebx == DELTA_DERIVATIVE

        ;// make sure the filter is set up

            .IF [esi].dwUser & DELTA_REBUILD_STATS
                invoke delta_build_stats
            .ENDIF

        ;// IDC_DELTA_SCROLL_NUMPOINTS

            ENABLE_CONTROL popup_hWnd, IDC_DELTA_SCROLL_NUMPOINTS, 1, ebx

            ;// SCROLLINFO STRUCT
            pushd 0                     ;// 6   dwTrackPos  dd      0
            mov eax, [esi].dat.num_points
            shr eax, 1
            pushd eax                   ;// 5   dwPos       SDWORD  0
            pushd 1                     ;// 4   dwPage      dd      0
            pushd DELTA_MAX_POINTS/2    ;// 3   dwMax       SDWORD  0
            pushd DELTA_MIN_POINTS/2    ;// 2   dwMin       SDWORD  0
            pushd SIF_RANGE OR SIF_PAGE OR SIF_POS;//   1   dwMask      dd      0
            pushd SIZEOF SCROLLINFO ;// 0   dwSize      dd
            mov edx, esp
            invoke SetScrollInfo, ebx, SB_CTL,edx, 1
            add esp, SIZEOF SCROLLINFO

        ;// IDC_DELTA_SCROLL_ALPHA

            ENABLE_CONTROL popup_hWnd, IDC_DELTA_SCROLL_ALPHA,1,ebx

            ;// SCROLLINFO STRUCT
            pushd 0                 ;// 6   dwTrackPos  dd      0

            fld [esi].dat.alpha
        ;// fsub delta_min_alpha
            fmul delta_scroll_from_alpha
            sub esp, 4
            fistp DWORD PTR [esp]   ;// 5   dwPos       SDWORD  0
            pushd 16                ;// 4   dwPage      dd      0
            pushd 255               ;// 3   dwMax       SDWORD  0
            pushd 0                 ;// 2   dwMin       SDWORD  0
            pushd SIF_RANGE OR SIF_PAGE OR SIF_POS;//   1   dwMask      dd      0
            pushd SIZEOF SCROLLINFO ;// 0   dwSize      dd
            mov edx, esp
            invoke SetScrollInfo, ebx, SB_CTL,edx, 1
            add esp, SIZEOF SCROLLINFO

        ;// IDC_DELTA_STATIC_NUM_POINTS

            ENABLE_CONTROL popup_hWnd, IDC_DELTA_STATIC_NUM_POINTS, 1

        ;// IDC_DELTA_STATIC_ALPHA

            ENABLE_CONTROL popup_hWnd, IDC_DELTA_STATIC_ALPHA, 1

        ;// IDC_DELTA_STATIC_NUM_POINTS_VALUE

            ENABLE_CONTROL popup_hWnd, IDC_DELTA_STATIC_NUM_POINTS_VALUE, 1, ebx

        sub esp, 128

            mov edi, esp    ;// text buffer
            pushd 'i%'      ;// arg
            mov edx, esp
            invoke wsprintfA, edi, edx, [esi].dat.num_points
            add esp, 4
            invoke SetWindowTextA, ebx, esp

        ;// IDC_DELTA_STATIC_ALPHA_VALUE

            ENABLE_CONTROL popup_hWnd, IDC_DELTA_STATIC_ALPHA_VALUE, 1, ebx

            mov edx, FLOATSZ_FIX OR FLOATSZ_DIG_4
            fld [esi].dat.alpha
            invoke float_to_sz      ;// destroys edi
            invoke SetWindowTextA, ebx, esp

        ;// IDC_DELTA_STATIC_STATS

            ENABLE_CONTROL popup_hWnd, IDC_DELTA_STATIC_STATS, 1, ebx

            mov edi, esp

            invoke wsprintfA, edi, OFFSET fmt_delta_stats,
                ADDR [esi].dat.sz_peak_bandwidth, ADDR [esi].dat.sz_peak_error,
                ADDR [esi].dat.sz_zero_bandwidth, ADDR [esi].dat.sz_zero_error

            invoke SetWindowTextA, ebx, esp

        add esp, 128


        .ELSE   ;// ebx is not DELTA_DERIVATIVE

        ;// disable the controls

            ENABLE_CONTROL popup_hWnd, IDC_DELTA_SCROLL_NUMPOINTS, 0
            ENABLE_CONTROL popup_hWnd, IDC_DELTA_SCROLL_ALPHA, 0
            ENABLE_CONTROL popup_hWnd, IDC_DELTA_STATIC_NUM_POINTS, 0
            ENABLE_CONTROL popup_hWnd, IDC_DELTA_STATIC_ALPHA, 0
            ENABLE_CONTROL popup_hWnd, IDC_DELTA_STATIC_NUM_POINTS_VALUE, 0
            ENABLE_CONTROL popup_hWnd, IDC_DELTA_STATIC_ALPHA_VALUE, 0
            ENABLE_CONTROL popup_hWnd, IDC_DELTA_STATIC_STATS, 0

        .ENDIF

    ;// that's it

        xor eax, eax    ;// return zero of build popup will try to adjust our size

        ret

delta_InitMenu ENDP




ASSUME_AND_ALIGN
delta_Command PROC

        ASSUME esi:PTR DELTA_OSC_MAP    ;// must preserve
        ASSUME edi:PTR OSC_BASE     ;// may destroy
        DEBUG_IF <edi!!=[esi].pBase>
        ;// must preserve ebx
        ;// eax has the command
        ;// exit by returning popup_flags in eax
        ;// or by jumping to osc_sommand

        xor edx, edx    ;// new value to insert into dword user

        CMPJMP eax, ID_DELTA_NORMAL, jnz @F

            mov ecx, delta_source_list
            jmp set_and_return

    @@: CMPJMP eax, ID_DELTA_DIGITAL, jnz @F

            mov edx, DELTA_DIGITAL
            mov ecx, delta_source_list[4]
            jmp set_and_return

    @@: CMPJMP eax, ID_DELTA_ABSOLUTE, jnz @F

            mov ecx, delta_source_list[8]
            mov edx, DELTA_ABSOLUTE
            jmp set_and_return

    @@: CMPJMP eax, ID_DELTA_DERIVATIVE, jnz @F

            mov ecx, delta_source_list[12]
            mov edx, DELTA_DERIVATIVE

    set_and_return:

            and [esi].dwUser, NOT DELTA_TEST
            mov [esi].pSource, ecx

    merge_and_return:

            or [esi].dwUser, edx
            mov eax, POPUP_REDRAW_OBJECT OR POPUP_SET_DIRTY OR POPUP_INITMENU OR POPUP_KILL_THIS_FOCUS
            ret

    @@: CMPJMP eax, IDC_DELTA_SCROLL_NUMPOINTS, jne @F

    ;// ecx has the position of the scroll

        shl ecx, 1
        or ecx, 1
        mov [esi].dat.num_points, ecx
        mov edx, DELTA_REBUILD_DERIVATIVE OR DELTA_REBUILD_STATS
        jmp merge_and_return

    @@: CMPJMP eax, IDC_DELTA_SCROLL_ALPHA, jne osc_Command

    ;// ecx has the position of the scroll

        pushd ecx
        fild DWORD PTR [esp]
        fdiv delta_scroll_from_alpha
        add esp, 4
        mov edx, DELTA_REBUILD_DERIVATIVE OR DELTA_REBUILD_STATS
    ;// fadd delta_min_alpha
        fstp [esi].dat.alpha
        jmp merge_and_return



delta_Command ENDP









ASSUME_AND_ALIGN
delta_SaveUndo  PROC

    ASSUME esi:PTR DELTA_OSC_MAP

    ;// edx enters as either UNREDO_CONTROL_OSC or UNREDO_COMMAND
    ;// edi enters as where to store
    ;//
    ;// task:   1) save nessary data
    ;//         2) iterate edi
    ;//
    ;// may use all registers except ebp

    ;// use this function when all that is required is to save dwUser

        mov eax, [esi].dwUser
        stosd
        mov eax, [esi].dat.num_points
        stosd
        mov eax, [esi].dat.alpha
        stosd

        ret


delta_SaveUndo ENDP





;////////////////////////////////////////////////////////////////////
;//
;//
;//     _LoadUndo
;//

ASSUME_AND_ALIGN
delta_LoadUndo PROC

        ASSUME esi:PTR DELTA_OSC_MAP    ;// preserve
        ASSUME ebp:PTR LIST_CONTEXT     ;// preserve

    ;// edx enters as either UNREDO_CONTROL_OSC or UNREDO_COMMAND
    ;// edi enters as where to load
    ;//
    ;// task:   1) load nessary data
    ;//         2) do what it takes to initialize it
    ;//
    ;// may use all registers except ebp and esi
    ;// return will invalidate HINTI_OSC_UPDATE

        mov eax, [edi]
        or eax, DELTA_REBUILD_DERIVATIVE OR DELTA_REBUILD_STATS
        mov [esi].dwUser, eax

        and eax, DELTA_TEST
        mov eax, delta_source_list[eax*4]
        mov [esi].pSource, eax

        mov edx, [edi+4]    ;// num points
        mov eax, [edi+8]    ;// alpha

        mov [esi].dat.num_points, edx
        mov [esi].dat.alpha, eax

        ret

delta_LoadUndo ENDP

;//
;//
;//     _LoadUndo
;//
;////////////////////////////////////////////////////////////////////



ASSUME_AND_ALIGN

ENDIF   ;// USE_THIS_FILE
END




comment ~ /*


    differentiator

    FIR filter
    odd number of params
    symetrical set of parameters with 0 as the center

    since the parameters are symetrical we only have to multiply them one per input
    we can also stack the multiplies

Z = unit delay
bz  filter coefficients
X = input signal
Y = output signal



traditional form N=7

    X --> Z --> Z --> Z --> Z --> Z --> Z           N-1     mul
    *     *     *     *     *     *     *           N-2     add
    b3   -b2    b1    0    -b1    b2   -b3          1       del     assume a rotating ptr
      --> + --> + --> + --> + --> + --> + --> Y


modifed form

   X-*   Vn+-------------------------------> - --> V3       1/2(N-1)    mul
      \   /                                  |              N-2         add
       b34 --> Z --> Z --> Z --> Z --> Z --> Z              1/2(N-1)    del
                \
                 *  V3-+-------------------> - --> V2
                  \   /                      |              we get 1/2 the mulitiplies
 b23 = b2/b3       b23 --> Z --> Z --> Z --> Z              at the cost of more delay access
                            \
                             *  V2+--------> - ----> Y
                              \  /           |
 b12 = b1/b2                   b12 --> Z --> Z


    the delay lines are not powers of two, and thus not easily maskable
    we could make them powers of two then suply an offset and a mask
    we could implement this in stages

    input V          Vin
    input X     Xin   \
                 *     +-------------------> - --> Vout
                  \   /                      |
    delay Z        b23 --> Z --> Z --> Z --> Z
    Z              [0]    [1]   [2]   [3]   [4]
                            \
                             Xout

        Z[4] = Z[3]                 advance the delay, old Z[4] is destroyed
        Z[3] = Z[2]
        Z[2] = Z[1]
        Z[1] = Z[0]
        Z[0] = b23 * Xin            insert new input
        Vout = Vin + Z[0] - Z[4]
        Xout = Z[1]                  for next stage

 rearrange this so we can retreat a pointer and replace the oldest with the newest
 {} indicates value that has changed in previous stage

BEFORE      Z[0] --> Z[1] -->{Z[2]}--> Z[3] --> Z[4] --> Z[5]   mask = 5
                             iprev    jprev

            Z[0] --> Z[1] --> Z[2] --> Z[3]                     mask = 3
            inow     jnow

        V += Znow[inow]
        Znow[inow] = Zprev[jprev] * b
        V += Znow[inow]
        jprev = iprev               next stage iterates the previous stage
        iprev = (iprev-1)&mask


AFTER       Z[0] --> Z[1] --> Z[2] --> Z[3] --> Z[4] --> Z[5]   mask = 5
                     iprev    jprev

            Z[0] -->{Z[1]}--> Z[2] --> Z[3]                     mask = 3
            inow     jnow

    sample_top
        stage_count = num_stages
    stage_top
        get now
        get inow
        get jprev

        fadd Znow[inow]
        fld Zprev[jprev]
        fmul Bnow
        fst Znow[inow]      <-- stall
        fadd                <-- stall

        get iprev
        store as jprev
        dec iprev
        and mask
        store as iprev

        dec stage_count
        jnz stage_top
        store Yout
        dec sample_count
        jnz sample_top

----------------------------------------------

    here is a data struct we can use

FRAME   pNextFrame
        coeff
        idx
        jdx
        bitmask
        data    bitmask+1 DUP (?)

    then let fNow and fPrev be available

    manage the pointers

        mov k, fPrev.idx        ;// get iprev
        mov j, fPrev.jdx        ;// get jprev
        mov i, fNow.idx         ;// get inow


        mov fPrev.jdx, k        ;// ptr 1: iterate previous stage jprev = iprev
        dec k                   ;// ptr 2: retreat iprev
        jns @f                  ;// ptr 3: jump if no wrap
        and k, fPrev.bitmask    ;// ptr 4: yes wrap, and with array size mask
    @@:                         ;// ptr 5:
        mov fPrev.idx, k        ;// ptr 6: store the new iprev

    do the formula

        fsub fPrev.data[j*4]    ;// alg 1:
        fld  fNow.data[i*4]     ;// alg 2:
        fmul fNow.coeff         ;// alg 3:
        fst  fNow.data[i*4]     ;// alg 4:
        fadd                    ;// alg 5:


-----------------------------------------------------------

at the cost of more setup work, we could build a linked list for the data

    DELAY   value        stored value
            delay clist MRS

    FRAME   pNextFrame   slist
            pData        clist MRS
            coeff
            delay   DELAY N DUP {}



        fsub fNow->pData.pNext->value   ;// work with the next data value
        fld  fPrev->pData->value
        fmul fNow->coef
        fst  fNow->pData.pNext->value
        fadd
        fPrev->pData = fPrev->pData.pNext

    to do it right

        edi:edx = fNow delay
        ebx:eax = fPrev delay
        ecx sample counter
        ebp input data ptr
        esi osc_object

        xor ecx, ecx

        .REPEAT ;// iterate through the samples

        ;// first element in delay has no previous

            slist_GetHead frame, edi, [esi].frame

            clist_GetMRS  delay, edx, edi    ;// edx is fNow.delay_now
            clist_GetNext delay, edx         ;// edx if fNow.delay_most_past

            fld   [edx].value   ;// load the stored value
            fld   [ebp+ecx*4]   ;// load the input sample
            fmul  [edi].coeff   ;// multiply by the coeff
            fst   [edx].value   ;// store in the delay
            fsubr               ;// subtract to get the running total

            mov ebx, edi                    ;// advance fPrev to fNow
            slist_GetNext frame, edi        ;// advance fNow to fNext

        ;// the next elements in the delay do have a previous

            .REPEAT ;// iterate through the delay

                clist_GetMRS  delay, edx, edi    ;// edx is fNow.delay_now
                clist_GetMRS  delay, eax, ebx    ;// eax is fPrev.pData
                clist_GetNext delay, edx         ;// edx if fNow.delay_most_past

                fsub  [edx].value
                fld   [eax].value
                fmul  [edi].coeff
                fst   [edx].value
                fadd
                clist_GetNext delay.[eax]       ;// advance previous delay
                clist_SetMRS data, eax, ebx     ;// iterate the previous frame

                mov ebx, edi                    ;// advance fPrev to fNow
                slist_GetNext frame, edi        ;// advance fNow to fNext

            .UNTIL !edi

            fstp [esi].data_o[ecx*4]    ;// store the output data
            inc ecx                     ;// next sample

        .UNTIL ecx >= SAMARY_LENGTH

----------------------------------------------------------------------------------

now then, after a day at mathcad

we can indeed allow a slider to control alpha and num points
from that we can derive the usable bandwidth and error
we'll need functions to compute the bessel equations
and we'll need a search through an IFFT




*/ comment ~












