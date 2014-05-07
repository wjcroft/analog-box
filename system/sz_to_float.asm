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
;// sz_to_float.asm     converts a string to a float
;//
OPTION CASEMAP:NONE
.586
.MODEL FLAT

    .NOLIST
    INCLUDE <utility.inc>   ;// debug helpers
    INCLUDE <testjump.inc>  ;// shortened form of testing intructions
    INCLUDE <szfloat.inc>   ;// include for these function
    .LIST

.CODE


comment ~ /*

    given a text pointer in esi
    determine if it points at a number

    [whitespace] [sign] [digits] [.digits] [ {d | D | e | E }[sign]digits]

    if it does,
        if the number is entirely valid
            return the number in the fpu
            clear the carry flag
            return esi as one passed the end of the number
        otherwise
            return eax as an error code
            leave esi where it was
            return edx at the character that ended the scan
            fpu is unchanged
            set carry flag
    if it does not,
        set the carry flag
        leave esi where it is
        return edx at character that aborted the scan

    we want the parser to be forgiving
    so the regular expression gets a little hairy

    whites sign zeros digits . digits eE +- digits

    note:   it is indeed worth the trouble to write this
            initial tests reveal the this is 5 to 10 times faster for integer numbers


*/ comment ~





.CODE


;// flags we store in ch

    INT_IS_NEG          EQU 00000001y
    INT_HAS_ZERO        EQU 00000010y   ;// integer has leading zeros, so we know at least that much
    MARKER_BEFORE_DECIMAL EQU 000100y   ;// helps us play catchup correctly
    EXP_IS_NEG          EQU 00001000y
    EXP_HAS_SIGN        EQU 00010000y   ;// so we can backup esi
    EXP_HAS_ZERO        EQU 00100000y

;// parameters for parseing

    MAX_PRECISION       EQU 8
    MAX_EXPONENT        EQU 37
    MIN_EXPONENT        EQU -37
    ULT_MAX_EXPONENT    EQU 100000  ;// let's be reasonable here

    comment ~ /*

        BAH! this routine took forever to write

        diagrams:

            we are parsing a string of tokens as follows

            wwww-zzziiizzziiizzz.zzziiizzziiizzzE-zzzziiiizzz##

            where:

                w --> white space
                - --> + - empty
                z --> zero
                i --> 1-9
                . --> decimal point
                E --> e E d D
                ##--> terminator

        to try and preserve the most presicion we use a catch_up mechanism
        that drops a marker after each digit,
            scans consecutive z's
            and catch's up when the input is 1-9

        in the process we maintain counts of the number significant digits
        and the exponent required to build the final numbers

        edx = catchup marker
        bl  = exponent
        bh  = amount to add to the exponent when scanning
              bh = 0 before decimal point, =-1 after decimal point
        cl  = count of significant digits
        ch  = flags about what found along the way

    */ comment ~


ASSUME_AND_ALIGN
sz_to_float PROC

comment ~ /*

input:  esi points at string

output:

    carry   eax     edx     esi     FPU
    -----   ----    ----    -----   ------
      0      x       x      NEXT    number
      1      0      LAST    START   empty   Not a Number
      1     ><+-    LAST    START   empty   out of range number

*/ comment ~

    ;// prepare

        push ebx
        push edi
        push esi

        ASSUME esi:PTR BYTE ;// iterated

        xor eax, eax
        sub ecx, ecx
        xor ebx, ebx
        sub edx, edx

    ;// leading white space

        .REPEAT
            lodsb
            TESTJMP  al,al, jz not_a_number_dec
        .UNTIL al > ' '

        xor edi, edi

    ;// sign

        CMPJMP al, '+', je  got_pos_sign
        CMPJMP al, '-', jne check_leading_zero
    got_neg_sign:
        or ch, INT_IS_NEG
    got_pos_sign:
        lodsb
        jmp check_leading_zero

    got_decimal_leading:

        TESTJMP bh, bh, jnz number_is_zero  ;// leading_extra_decimal   ;// see if we already have a decimal
        dec bh          ;// we have a decimal now

    ;// leading zeros

    loop_leading_zero:
        lodsb
        add bl, bh          ;// adds 0 before decimal, subtracts 1 after decimal
        or ch, INT_HAS_ZERO ;// so we know that we are at least equal to zero
    check_leading_zero:
        CMPJMP al, '.', je  got_decimal_leading
        CMPJMP al, '0', je  loop_leading_zero
                        jb  done_with_number
        CMPJMP al, '9', ja  check_exponent_no_catchup

    got_first_number:

        lea edi, [eax-'0']
        inc cl          ;// new digit
        mov edx, esi    ;// drop a marker
        xor eax, eax

    ;// number scan
    number_scan:

        lodsb
        CMPJMP al, '.', je  got_decimal
        CMPJMP al, '0', je  trailing_zero
                        jb  done_check_if_catchup
        CMPJMP al, '9', ja  check_exponent_catchup

    ;// have to check if we need to play ctach up
    ;// this happens when we hit a number immediately after the decimal

        inc edx
        CMPJMP edx, esi,    je accumulate_number

        dec edx ;// sloppy
        call catch_up
        jnz too_much_presicion

    ;// accumulate number

    accumulate_number:

        add bl, bh              ;// i adds 0 if before decimal, -1 if after decimal
        mov edx, esi            ;// drop a marker
        lea edi, [edi*4+edi]    ;// *5
        inc cl                  ;// increase digit count
        lea edi, [edi*2+eax-'0'];// *10 + new digit
        xor eax, eax
        CMPJMP cl, MAX_PRECISION,   jb  number_scan

    too_much_presicion:

    ;// if decimal, goto locate exponent
    ;// else locate decimal
    ;// goto locate exponent

        lodsb
        CMPJMP al, '.', je check_too_many_decimal
        CMPJMP al, '0', jb done_no_catchup
        CMPJMP al, '9', jbe too_much_presicion
        jmp check_exponent_no_catchup

    check_too_many_decimal:

        TESTJMP bh,bh,  jnz done_no_catchup
        dec bh
        jmp too_much_presicion

    got_decimal:

        TESTJMP bh,bh, jnz done_no_catchup  ;// see if we already have a decimal
        TESTJMP edx, edx, jnz D0    ;// see if marker already set
        mov edx, esi            ;// set marker at decimal if not
        jmp D1
    D0: or  ch, MARKER_BEFORE_DECIMAL   ;// otherwise the previous mark was before the decimal
    D1:
        dec bh                  ;// decimal sets bh = -1
        jmp number_scan         ;// then go to number scan

    ;// trailing zeros

    trailing_zero:

        add bl, bh      ;// z adds 1 if before decimal, 0 if after decimal
        lodsb
        inc bl
        CMPJMP al, '.', jb  done_no_catchup
                        je  got_decimal
        CMPJMP al, '0', je  trailing_zero
                        jb  done_no_catchup
        CMPJMP al, '9', ja  check_exponent_no_catchup

        ;// we have a new number, done with trailing zeros

        call catch_up       ;// catch_up advances edx until esi
        jnz  too_much_presicion
        xor  edx, edx       ;// reset the marker
        jmp  accumulate_number  ;// accumulate the new digit

    ;// check exponent
    ;// at this point we have SOME number in edi
    ;// and an exponent in bl
    ;// ch still has the sign of the number
    ;// bh is !0 if we got a decimal

    check_exponent_catchup:
        .IF edx
            call catch_up
        .ENDIF
    check_exponent_no_catchup:

    ;// check for exponent symbol

        and al, 0DFh    ;// upper case
        xor edx, edx    ;// must be zero this point
        CMPJMP al, 'E', ja  done_with_number
        CMPJMP al, 'D', jb  done_with_number

    ;// check for exponent sign

        lodsb
        CMPJMP al, '+', je  exp_is_pos
        CMPJMP al, '-', jb  trailing_E
                        jne exp_zeros_check
    exp_is_neg:
        or ch, EXP_IS_NEG
    exp_is_pos:
        or ch, EXP_HAS_SIGN ;// so we can backup esi
        jmp exp_zeros_enter

    ;// check for leading zeros

    exp_zeros_loop:
        or ch, EXP_HAS_ZERO ;// so we at least know the exponent is zero
    exp_zeros_enter:
        lodsb
    exp_zeros_check:
        CMPJMP al, '0', je  exp_zeros_loop
                        jb  exp_done
        CMPJMP al, '9', ja  exp_no_number

    ;// read exponent number, accumulate to edx
    accumulate_exp_digits:

        lea edx, [edx*4+edx]
        lea edx, [edx*2+eax]-'0'

        CMPJMP edx, ULT_MAX_EXPONENT, ja exp_way_too_big

        lodsb
        CMPJMP al, '0', jb  exp_done
        CMPJMP al, '9', jbe accumulate_exp_digits

    exp_done:

        TESTJMP  edx, edx,          jnz done_with_number
        TESTJMP  ch, EXP_HAS_ZERO,  jnz done_with_number

;// exponent errors

    exp_no_number:

        TESTJMP ch, EXP_HAS_SIGN, jz trailing_E
        dec esi     ;// back another one

    trailing_E:

        dec  esi    ;// back one
        jmp  done_with_number



;// exit points

    done_check_if_catchup:
        .IF edx
            call catch_up
    done_no_catchup:
            xor edx, edx
        .ENDIF
    done_with_number:

    ;// edx contains the exponent count
    ;// bl has the exponent so far
    ;// edi = int.dec
    ;// ch has pos neg flags
    ;// esi must be positioned at end of input

        dec esi             ;// esi must point at character that aborted the scan

    ;// check for zero first

        TESTJMP edi, edi,   jz  number_is_zero

    ;// deal with neg number

        .IF ch & INT_IS_NEG
            neg edi
        .ENDIF
        movsx ebx, bl       ;// destroys our knowledge of haveing a decimal point

    ;// determine the total exponent, and check for zero

        .IF ch & EXP_IS_NEG
            neg edx
        .ENDIF
        add ebx, edx        ;// total exponent
        jnz process_exponent;// if zero, then no sense doing the rest

    ;// only integer part, load it and go

        mov [esp], edi
        fild DWORD PTR [esp]
        jmp exit_sucess

    ;// check the limits of the exponent, have to roll in the digit count
    process_exponent:

        mov al, cl
        add eax, ebx
        CMPJMP eax, MIN_EXPONENT,       jle number_too_small
        CMPJMP eax, MAX_EXPONENT,       jge number_too_big

    ;// build the number

        mov [esp], edi
        fild DWORD PTR [esp]

        mov [esp], ebx

        fldl2t
        fimul DWORD PTR [esp]   ;// E       M
        fld1                    ;// 1       E       M
        fld st(1)               ;// E       1       E       M
        fprem                   ;// fE      1       E       M
        f2xm1                   ;// 2^fE    1       E       M
        fadd                    ;// 2^fE    E       M
        fscale                  ;// 2^iE * 2^fE     2^fE    M
        fmulp st(2), st         ;// 2^fE    number
        fstp st                 ;// number
        jmp exit_sucess


    number_is_zero:

        TESTJMP  ch, INT_HAS_ZERO, jz not_a_number_now
        fldz

    exit_sucess:

        add esp, 4      ;// also clears the carry flag

    all_done:

    ;// esi had better be correct
    ;// eax must have any return codes
    ;// stack must be cleaned up
    ;// carry flag must be set

        pop edi
        pop ebx

        ret


;////////////////////////////////////////////////////////////
;//
;// error exits

not_a_number_dec:
    dec esi
not_a_number_now:

    mov edx, esi    ;// edx must be number that aborted scan
    xor eax, eax    ;// no return code
    pop esi
    stc             ;// set carry for error
    jmp all_done


exp_way_too_big:

    ;// still have to locate end of number

    .REPEAT
        lodsb
    .UNTIL al < '0' || al > '9'
    dec esi
    TESTJMP ch,EXP_IS_NEG, jnz number_too_small
    ;// fall into next section

number_too_big:

    mov eax, NUMBER_TOO_LARGE
    ;// fall into next section

error_number_range:

    .IF ch & INT_IS_NEG
        or eax, NUMBER_RANGE_NEG
    .ENDIF
    mov edx, esi
    pop esi
    stc
    jmp all_done

number_too_small:

    mov eax, NUMBER_TOO_SMALL
    jmp error_number_range




;// error exits
;//
;////////////////////////////////////////////////////////////

;/////////////////////////////////////////////////////////////////////////
;//
;// local function
;//

    ALIGN 16
    catch_up:
    ;// returns zero flag if we did indeed mange to catchup
    ;// otherwise, we had too many digits
    ;// and what ever called this needs to deal with it

        DEBUG_IF < !!edx >  ;// supposed to be set !!

        inc edx
        .IF edx != esi  ;// returns zero if full catchup
            .IF ch & MARKER_BEFORE_DECIMAL
                inc edx
                and ch, NOT MARKER_BEFORE_DECIMAL
                CMPJMP edx, esi, je done_with_catchup ;// returns zero flag set
            .ENDIF
            .REPEAT
                lea edi, [edi*4+edi] ;// *5
                dec bl          ;// catch_up always decreases the decimal
                inc edx         ;// advance the marker
                inc cl          ;// increase the digit count
                shl edi, 1      ;// *10
            .BREAK .IF cl > MAX_PRECISION   ;// returns non zero if too many digits
            .UNTIL edx == esi               ;// returns zero if full catchup
        .ENDIF
    done_with_catchup:
        retn

;//
;// local function
;//
;/////////////////////////////////////////////////////////////////////////


sz_to_float ENDP






ASSUME_AND_ALIGN
END
