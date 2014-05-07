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
;//     string.inc          nul terminated string macros
;//                         work a lot like C functions
;//
;//     d_iter and s_iter are destination and source pointers
;//     temp is always a single letter
;//     most functions return with iters at the end of the string
;//
IFNDEF _STRING_INCLUDED_
_STRING_INCLUDED_ EQU 1

;////////////////////////////////////////////////////////////////////
;//                                                             macro
;//
;//     STRCPY      returns with both iters set AT the nul end of string
;//                 if siz is specified, it will return the size
;//
;//
;//     d_iter  destination iterator    a valid pointer expression
;//     s_iter  source iterator         a valid pointer expression
;//     temp    temp register           a valid 8/32 bit register (ie 'a' uses eax)
;//     siz     size register           a 32 bit register
;//

    STRCPY MACRO d_iter:req, s_iter:req, temp:=<a>, siz

        LOCAL top_of_loop, enter_loop

            IFNB <siz>
            xor siz, siz
            ENDIF

            jmp enter_loop

        top_of_loop:
            inc s_iter
            inc d_iter
            IFNB <siz>
            inc siz
            ENDIF
        enter_loop:
            xor e&temp&x, e&temp&x
            or temp&l, BYTE PTR [s_iter]
            mov BYTE PTR [d_iter], temp&l
            jnz top_of_loop

            ENDM

;//
;//     STRCPY
;//
;//
;////////////////////////////////////////////////////////////////////





;////////////////////////////////////////////////////////////////////
;//
;//                     string copy using esi and edi
;//     STRCPY_SD       uses al as well
;//                     can count a length
;//

    STRCPY_SD   MACRO terminate:req, count_method, count_reg

    ;// regs:   esi must be the string source
    ;//         edi must be the destination
    ;//         eax should be cleared before using
    ;//
    ;// macro args
    ;//
    ;// terminate:      TERMINATE   copy and count trailing zero
    ;//                 NOTERMINATE do not copy or count trailing zero
    ;//
    ;// count_method:   LEN will clear the count register before starting
    ;//                 ADD will not clear the register
    ;//
    ;// count_reg:      a register to count with
    ;//                 must not be al, eax, esi, edi, si or di

        LOCAL SD1, SD2, SD3

    ;// take care of counting

        IFNB <count_reg>

            .ERRIDNI <count_reg>,<eax>,<eax can not be the count register>
            .ERRIDNI <count_reg>,<esi>,<esi can not be the count register>
            .ERRIDNI <count_reg>,<edi>,<edi can not be the count register>

            IFIDN       <count_method>,<ADD>
            ELSEIFIDN   <count_method>,<LEN>
                xor count_reg, count_reg
            ELSE
                .ERR <use ADD or LEN or leave blank>
            ENDIF

        ELSEIFNB <count_method>
            .ERR <leave blank or supply a register to count with>
        ENDIF

    ;// determine the desired mode

        IFIDN <terminate>,<TERMINATE>

                ;// TERMINATE

        SD1:    lodsb           ;// get the character
                IFNB <count_reg>
                inc count_reg   ;// increase the count
                ENDIF
                or al, al       ;// check for zero
                stosb           ;// store the character
                jnz SD1         ;// keep going if not terminator

        ELSEIFIDN <terminate>,<NOTERMINATE>

                ;// DO NOT TERMINATE

        SD2:    lodsb           ;// get the character
                or al, al       ;// check for zero
                jz SD3          ;// exit if terminator
                stosb           ;// store the character
                IFNB <count_reg>
                inc count_reg   ;// increase the count
                ENDIF
                jmp SD2         ;// continue on
        SD3:


        ELSE
            .ERR <use TERMINATE or NOTERMINATE>
        ENDIF

        ENDM

;//
;//                     string copy using esi and edi
;//     STRCPY_SD       uses al as well
;//                     can count a length
;//
;////////////////////////////////////////////////////////////////////











;////////////////////////////////////////////////////////////////////
;//
;//
;//     STRLEN      cheap and dirty
;//                 d_iter must be a pointer register
;//                 d_len will NOT be pre cleared
;//
;//     this is really  ACCULUMATE_STRLEN
;//     length does NOT include nul terminater

    STRLEN MACRO d_iter:req, d_len:=<eax>

        LOCAL loop_top, loop_done

        loop_top:
            cmp BYTE PTR [d_iter], 0
            jz loop_done
            inc d_iter
            inc d_len
            cmp BYTE PTR [d_iter], 0
            jz loop_done
            inc d_iter
            inc d_len
            jmp loop_top
        loop_done:

        ENDM

;//
;//
;//     STRLEN
;//
;////////////////////////////////////////////////////////////////////


STR_EATWHITE MACRO pString:REQ, iter:REQ, abort:REQ

        LOCAL top_of_loop, exit_loop

    top_of_loop:

        cmp BYTE PTR [pString+iter], 0
        je abort
        cmp BYTE PTR [pString+iter], ' '
        ja exit_loop
        inc iter
        jmp top_of_loop

    exit_loop:

        ENDM




STR2INT MACRO pString:REQ, accum:=<ecx>, iter:=<edx>, temp:=<a>

    ;// stops at first invalid char
    ;// leading white space is ignored

        LOCAL top_of_loop, done_with_string

    ;// iterate passed any white space

        xor iter, iter
        xor accum,accum

        STR_EATWHITE pString, iter, done_with_string

    ;// prepare to accumulate digits

        xor e&temp&x,e&temp&x

    top_of_loop:

        or temp&L, BYTE PTR [pString+iter]
        jz done_with_string

        sub temp&L, '0'
        jb done_with_string
        cmp temp&L, 9
        ja done_with_string

        lea accum, [accum*4+accum]      ;// *5
        inc iter
        lea accum, [accum*2+e&temp&x]   ;// *10 + iter
        xor e&temp&x,e&temp&x

        jmp top_of_loop

    done_with_string:

        ENDM


STR_FIND_CRLF_reverse MACRO pString:REQ, slen:REQ, abort:REQ, temp:=<a>

    ;// search for eol given a length

        LOCAL top_of_loop, done_with_loop
        LOCAL reg_x, reg_l

        reg_x CATSTR <e>,<temp>,<x>
        .ERRIDNI <reg_x>, <slen>, <tempoary register equal itterator>
        reg_l CATSTR <temp>,<L>

        test slen, slen
        jz abort
        xor reg_x, reg_x

    top_of_loop:

        mov reg_l, BYTE PTR [pString+slen]
        cmp reg_l, 0dh
        je done_with_loop
        cmp reg_l, 0ah
        je done_with_loop
        dec slen
        jnz top_of_loop
        jmp abort

    done_with_loop:

        ENDM


ENDIF   ;// _STRING_INCLUDED_