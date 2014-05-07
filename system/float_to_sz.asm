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
;//     ABOX242 AJT
;//         manually set 1 operand size for masm 9
;//
;//##////////////////////////////////////////////////////////////////////////
;//
;// float_to_sz.asm     converts a float to a nul terminated string
;//
OPTION CASEMAP:NONE
.586
.MODEL FLAT

    .NOLIST
    INCLUDE <utility.inc>   ;// debug helpers
    INCLUDE <testjump.inc>  ;// shortened form of testing intructions
    INCLUDE <szfloat.inc>   ;// include for these function
    INCLUDE <fpu_math.inc>
    .LIST



.DATA

    ALIGN 4
    floatsz_1_L210  REAL4   3.01029995664E-1    ;// 1/log2(10)
    floatsz_L210    REAL4   3.321928094887      ;// log2(10)
    floatsz_1       REAL4   1.0
    floatsz_almost_1    REAL4  0.999999
    floatsz_exp_kludge  REAL4   1.0e-6  ;// accounts for slop in real4 format


    eng_whole   db    0,'K','M','G','T'
    eng_fract   db  'm','u','n','p','f'
    ALIGN 4


;// this sets how the fpu rounds to zero
;// USE_PREM_ROUND appears to be about 20 cycles faster

    USE_PREM_ROUND EQU 1

IFNDEF USE_PREM_ROUND

    floatsz_cw      DWORD   02F7h OR fpu_ROUND_ZERO
    floatsz_cw1     DWORD   0

ENDIF



.CODE


ASSUME_AND_ALIGN
float_to_sz PROC

    ASSUME edi:PTR BYTE ;// ptr to output, iterated
    ;//
    ;// FPU must have number to convert, destroyed
    ;// edx must have format flags, see FLOATSZ_DIG_3
    ;// destroys eax, edx
    ;//
    ;// output: fpu:empty
    ;//         number in buffer


    push ecx    ;// many routines need this
    push ebx    ;// not all routines use this, but some do


;////////////////////////////////////////////////////////////
;//
;// 1) build the precision
;//


    ;// task:   fill in a BCD buff to the deisred precision
    ;//         return the exponent of the BCD
    ;//
    ;// input:  fpu = number to convert
    ;//         bcd = desired precision
    ;//
    ;// output: fpu = empty
    ;//         bcd = unsigned int to desired presicion
    ;//         ch  = sign of number
    ;//         cl  = origonal exponent
    ;//         carry = error
    ;//         if error, eax = dword to store (+Inf, -NAN, ???, etc)
    ;//
    ;// destroys:   eax ecx

    ;// make a buffer, store the precision

        sub esp, 8
        push edx
        and DWORD PTR [esp], 07h

    ;// always check the value first

        xor eax, eax
        fxam
        fstsw ax

    ;// C1 is always the sign, we can set that regardless
    ;// must work with unsigned numbers

        xor ecx, ecx
        .IF ah & 2  ;// negative ?
            fchs
            inc ch  ;// ch is pos neg flag
        .ENDIF

    ;// sw  C3  C2  C1  C0
    ;// ax  14  10  09  08
    ;// ah   6   2   1   0     Meaning
    ;//     64   4   2   1
    ;//     --  --  --  --     -----------

    ;// unsupported
    ;//     0   0   0   0      + Unnormal*
    ;//     0   0   1   0      - Unnormal*

        TESTJMP ah, 01000101y, jz err_unsupported   ;// wasteful ??

    ;// errors
    ;//     64   4   2   1
    ;//     0   0   0   1      + NAN
    ;//     0   0   1   1      - NAN
    ;//     0   1   0   1      + Infinity
    ;//     0   1   1   1      - Infinity

    ;//     1   0   0   1      Empty
    ;//     1   0   1   1      Empty
    ;//     1   1   0   1      Empty*
    ;//     1   1   1   1      Empty*

        TESTJMP ah, 1, jnz err_empty_nan_inf

    ;// zero or denormal
    ;//     64   4   2   1
    ;//     1   0   0   0      + 0
    ;//     1   0   1   0      - 0
    ;//     1   1   0   0      + Denormal
    ;//     1   1   1   0      - Denormal

        TESTJMP ah, 64, jnz err_zero_denormal

    ;// normal numbers
    ;//     64   4   2   1
    ;//     0   1   0   0      + Normal
    ;//     0   1   1   0      - Normal

    ;// now have a number to work with, determine the power of 10

    ;// e1 = floor( log2( n ) / log2(10) )

        fld floatsz_1_L210          ;// L210    num
        fld st(1)               ;// num     L210    num
        fyl2x                   ;// e1      num

        fadd floatsz_exp_kludge ;// account for slop in real4 exponent
        ;// we truncate towards 0, this handles numbers like .001


IFDEF USE_PREM_ROUND

;// version 2 use prem avoids changing the control word
;// faster, use this

        fld floatsz_1
        fld st(1)
        fprem
        fsubp st(2), st
        fstp st

ELSE

;// version 1 requires changing the control word
;//
        fnstcw WORD PTR floatsz_cw1
        fldcw  WORD PTR floatsz_cw
        frndint
        fldcw  WORD PTR floatsz_cw1

ENDIF

        xor eax, eax

        fist DWORD PTR [esp+4]  ;// store on stack
        .IF dh != FLOATSZ_INT SHR 8

            .IF dh != FLOATSZ_FIX SHR 8

                ;// fiddle with the exponent
                or eax, [esp+4]
                js FF1
                jnz FF2
                ;// exponent is either 0 or neg 1
                ;// check if number is less than 1
                ;// if so, decrease the exponet

                    fld floatsz_almost_1
                    xor eax, eax
                    fucomp st(2)
                    fnstsw ax
                    sahf
                    jbe FF2

            FF1:    fsub floatsz_1
                    dec DWORD PTR [esp+4]
            FF2:

            .ENDIF

        ;// subtract exponent and desired presicion

            fisubr DWORD PTR [esp]  ;// N       num

        ;// do 10^n = 2^(log2(10)*n)

            fmul floatsz_L210   ;// n   N   num
            fld floatsz_1       ;// 1   X
            fld st(1)           ;// X   1   X
            .REPEAT
                fprem
                xor eax, eax
                fnstsw ax
                sahf
            .UNTIL !PARITY? ;// fX      1   X
            f2xm1           ;// 2^fX-1  1   X
            fadd            ;// 2^fX    X
            fscale          ;// 2^X     X
            fxch            ;// X       2^X
            fstp st         ;// 2^X
            fmul            ;// NUM

        .ELSE

            fstp st         ;// NUM

        .ENDIF

        mov cl, [esp+4]         ;// cl = exponent

    store_the_number:

        fbstp TBYTE PTR [esp]   ;// empty   ;// ABOX242 AJT

;//
;// 1) build the precision
;//
;////////////////////////////////////////////////////////////





;////////////////////////////////////////////////////////////
;//
;// 2) format the number
;//

    ;// now we have a number
    ;// ch = sign of value

        .IF ch
            mov [edi],'-'
            inc edi
        .ELSEIF edx & FLOATSZ_LEADING_PLUS
            mov [edi],'+'
            inc edi
        .ENDIF

    ;// then we determine how to format

        CMPJMP dh, FLOATSZ_INT SHR 8, je int_point
        CMPJMP dh, FLOATSZ_FIX SHR 8, je fix_point
        CMPJMP dh, FLOATSZ_ENG SHR 8, je eng_point
        CMPJMP dh, FLOATSZ_SCI SHR 8, je sci_point

    ;//////////////////////////////////////////////////////////
    ;//
    ;// sci_point
    ;//


    sci_point:

            mov ch, 1       ;// SCI always uses one decimal
            call print_number

        ;// exponent

            TESTJMP cl,cl,  jnz have_exponent
            TESTJMP edx, FLOATSZ_WANT_0_EXP, jz all_done
            test cl, cl ;// need to have the sign flag

        have_exponent:

            mov al, 'e'
            stosb
            mov al, '+'
                            jns sci_exp_is_pos
        sci_exp_is_neg:

            neg cl
            mov al,'-'

        sci_exp_is_pos:

            stosb

            movzx ax, cl
            aam
            TESTJMP ah, ah, jnz sci_two_digits
            TESTJMP edx, FLOATSZ_2_DIGIT_EXP, jnz sci_two_digits

        sci_one_digit:

            add al, '0'
            stosb
            jmp all_done

        sci_two_digits:

            xchg ah, al
            add ax, '00'
            stosw

            jmp all_done

    ;//
    ;// sci_point
    ;//
    ;//////////////////////////////////////////////////////////


    ;// local function
    ALIGN 16
    print_number:
    ;//
    ;// ch must have digits before exponent
    ;// dl must have total number of digits
    ;//
        push edx    ;// save to account for FLOATSZ_SPACE and other flags

            and edx, 0Fh
            shr edx, 1      ;// edx counts BCD remaining to scan
            jnc lo_digit

        hi_digit:   mov al, [esp+edx+8]
                    shr al, 4
                    add al, '0'
                    dec ch
                    stosb
                    jnz lo_digit
                    mov al, '.'
                    stosb
        lo_digit:   mov al, [esp+edx+8]
                    and al, 0Fh
                    add al, '0'
                    dec ch
                    stosb
                    jnz next_bcd
                    mov al, '.'
                    stosb
        next_bcd:   dec edx
                    jns hi_digit

        pop edx

            .IF edx & FLOATSZ_SPACE
                mov al, ' '
                stosb
            .ENDIF

            retn

    ALIGN 16
    ;//////////////////////////////////////////////////////////
    ;//
    ;// eng_point
    ;//
    eng_point:

        ;// ch = sign, already taken care of
        ;// cl = exponent
        ;// dl = desired precision

        ;// task: determine the suffix
        ;//       determine where to print the decimal

        comment ~ /*
            N=4                 dec suf
            1.235e+ 4 --> 12.35  2   k
            1.235e+ 3 --> 1.235  1   k
            1.235e+ 2 --> 123.5  3
            1.235e+ 1 --> 12.35  2
            1.235   0 --> 1.235  1
            1.235e -1 --> 123.5  3   m
            1.235e -2 --> 12.35  2   m

            E/3   a     d
            ---   -     -
            6/3 = 2 rem 0   rem+1

            5/3 = 1 rem 2
            4/3 = 1 rem 1
            3/3 = 1 rem 0

            2/3 = 0 rem 2
            1/3 = 0 rem 1
            0/3 = 0 rem 0
                                    neg then dec al, divide, sub 3 with remainder
           -1/3 = 0 rem 1 ?   123.4     0/3 = 0 rem 0 --> 3
           -2/3 = 0 rem 2 ?   12.34     1/3 = 0 rem 1 --> 2
           -3/3 = 1 rem 0     1.234     2/3 = 0 rem 2 --> 1

           -4/3 = 1 rem 1     123.4     3/3 = 1 rem 0 --> 3
        */ comment ~

        mov ch, 3
        mov al, cl
        test cl, cl     ;// is exponent neg ?
        mov ah, 0
        .IF SIGN?
            neg al      ;// must be pos
            dec al
            div ch
            mov ebx, OFFSET eng_fract   ;// use other table
            sub ch, ah
        .ELSE
            div ch
            mov ebx, OFFSET eng_whole
            mov ch, ah  ;// decimal point
            inc ch
        .ENDIF

        cmp al, 5
        jae sci_point

        and eax, 0Fh
        add ebx, eax    ;// suffix

    ;// now we can store the number

        call print_number

    ;// and tack on the suffix

        mov al, [ebx]
        TESTJMP al, al, jz all_done
        stosb
        jmp all_done

    ;//
    ;// eng_point
    ;//
    ;//////////////////////////////////////////////////////////



    ALIGN 16
    ;//////////////////////////////////////////////////////////
    ;//
    ;// fix_point       rule: always display the decimal point
    ;//                       this there are N+1 characters plus sign
    fix_point:

    comment ~ /*

        N=5
                             cl  ch
        input       disply  exp dec
        ---------   ------  --- ---
        12345678.   ######   7   x
        1234567.8   ######   6   x
        123456.78   ######   5   x

        12345.678   12345.   4   5
        1234.5678   1234.5   3   4
        123.45678   123.45   2   3
        12.345678   12.234   1   2
        1.2345678   1.2345   0   1

        .12345678   .12345  -1   0
        .01234567   .01234  -2   0
        .00123456   .00123  -3   0
        .00012345   .00012  -4   0
        .00001234   .00001  -5   0

        .00000123   .00000  -6   0
        .00000012   .00000  -7   0

    */ comment ~

        ;// dl = desired precision
        ;// ch = sign, already taken care of
        ;// cl = exponent
        ;// dl = desired precision

            mov ch, cl
            CMPJMP  dl,cl, jl  fix_too_big  ;// used signed compare
            TESTJMP cl,cl, js  fix_less_one

        fix_just_right:

            inc ch
            call print_number
            jmp all_done

        fix_less_one:

            mov al, '.' ;// leading decimal
            stosb
        ;// leading zeros, don't do too many

            mov al, '0'
            mov ah, dl
        F1: inc cl
            jz F2
            stosb
            dec ah
            jns F1
            jmp all_done

        F2: ;// leading zeros are done
            ;// do we have anything left ?

            add ch, dl
            inc ch
            js all_done

        fix_print_number:   and edx, 0Fh
                            shr edx, 1      ;// edx counts BCD remaining to scan
                            jnc fix_lo_digit

        fix_hi_digit:       mov al, [esp+edx]
                            shr al, 4
                            add al, '0'
                            stosb
                            dec ch
                            js all_done

        fix_lo_digit:       mov al, [esp+edx]
                            and al, 0Fh
                            add al, '0'
                            stosb
                            dec ch
                            js all_done

        fix_next_bcd:       dec edx
                            jns fix_hi_digit

                            jmp all_done

        fix_too_big:

            add dl, 2   ;// 1 for zero based index, 1 for imposed decimal point
            mov al, '#'
            movzx ecx, dl
            rep stosb
            jmp all_done

    ;//
    ;// fix_point
    ;//
    ;//////////////////////////////////////////////////////////


    ;//////////////////////////////////////////////////////////
    ;//
    ;// int_point
    ;//
    ALIGN 16
    int_point:

            and edx, NOT FLOATSZ_SPACE  ;// no space after number ever

            CMPJMP cl, dl, ja int_is_too_big    ;// will trap neg as well

            mov dl, cl
            call print_number
            jmp all_done

        int_is_too_big:     ;// number is too big or neg

            TESTJMP cl, cl, js int_is_zero

            movzx ecx, dl
            mov al, '#'
            inc ecx
            rep stosb
            jmp all_done

        int_is_zero:

            mov al, '0'
            stosb
            jmp all_done



    ;//
    ;// int_point
    ;//
    ;//////////////////////////////////////////////////////////




;//
;// 2) format the number
;//
;////////////////////////////////////////////////////////////




    ALIGN 16
    all_done:

        add esp, 12     ;// clean up the stack
        mov [edi], 0    ;// terminate the string
        pop ebx
        pop ecx
        ret             ;// beat it




;///////////////////////////////////////////////////////////
;//
;// error code
;//

    ALIGN 16
    err_zero_denormal:

        fstp st
        fldz
        jmp store_the_number    ;// go back to the storer, zero is a valid number

    ALIGN 16
    err_empty_nan_inf:
    ;//     64   4   2   1
    ;//     0   0   0   1      + NAN
    ;//     0   0   1   1      - NAN
    ;//     0   1   0   1      + Infinity
    ;//     0   1   1   1      - Infinity

    ;//     1   0   0   1      Empty
    ;//     1   0   1   1      Empty
    ;//     1   1   0   1      Empty*
    ;//     1   1   1   1      Empty*

        TESTJMP ah, 64, jnz err_empty


        .IF ah & 4
            mov eax, 'fnI'
        .ELSE
            mov eax, 'NAN'
        .ENDIF

        fstp st

    return_fail:

        .IF ch
            or eax, '-' SHL 24
        .ELSE
            or eax, '+' SHL 24
        .ENDIF

        stosd
        stc     ;// set carry
        jmp all_done

    err_unsupported:

        fstp st

    err_empty:

        mov eax, '???'
        jmp return_fail

float_to_sz ENDP





ASSUME_AND_ALIGN
END
