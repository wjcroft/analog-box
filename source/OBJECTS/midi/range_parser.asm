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
;// range_parser.asm
;//
;//
;// TOC
;//
;// midi_szrange_to_bits PROC STDCALL pStr:DWORD, pBits:DWORD, num_bits:DWORD
;// midi_bits_to_szrange PROC STDCALL pBits:DWORD, num_bits:DWORD, pStr:DWORD
;//
comment ~ /*

    these two functions are designed to translate between
    lists of numbers and bits

    bit positions start with zero, always

    format of the string is fairly loose list representation
    EX: "0, 2 4 - 10 11" will get correctly translated

    garbage is ignored and treated as a separator
    multiple - operators are combined
    EX: " 17 - 10 - junk we ignore - 19 29 more junk 27 29" ==> "10-19 27-29"

    maximum allowable number is 253, but this hasn't been tested
    system was designed for 128 and 16 bit midi fields

    out-of-range numbers are saturated by the passed num_bits value

    bits are segmented into dwords, which works out correctly for byte memory

    string values are expected to be zero terminated

    when converting from bits to string, allow for a maximum of expected length
    the longest text pattern will represent 11011011011011...
    so 2/3 of the bits are on, and if each bit takes 4 chars (on average)
    4 * 2/3 ==> 2.667 char per bit, so 3X should acount for any and all

    as a general rule, a reconverted string will NEVER be longer than the source string
    this makes it useful to re-interperet a passed string so as to display what actually happened

    finally: for range = 16 we display as one based index
            for range = 127 we display as 0-127

*/ comment ~

OPTION CASEMAP:NONE

.586
.MODEL FLAT

    .NOLIST
    INCLUDE <utility.inc>
    .LIST

.CODE


ASSUME_AND_ALIGN
PROLOGUE_OFF
midi_szrange_to_bits PROC STDCALL USES ebp esi edi ebx ptr_str:DWORD, ptr_bits:DWORD, number_bits:DWORD
                ;//     00                                04               08              0C

    ;// to do this expeditiously we'll need two scans
    ;// 1) prepare the string (destroys it)
    ;// 2) process the commands

    ;// assume that bits are already cleared

    ;// load and save important registers

            xchg ebp,[esp+0Ch]  ;// ebp holds number of bis
            xchg edi,[esp+08h]  ;// edi holds output ptr
            xchg esi,[esp+04h]  ;// esi scans input string
            push ebx            ;// ebx holds one extent for ranges
            dec ebp             ;// num bits - 1
            DEBUG_IF <SIGN?>    ;// must have passed zero

            ASSUME esi:PTR BYTE
            ASSUME edi:PTR DWORD

;// first scan
;//
;//     prepare the string by
;//     1) turn consecutive digits into a binary number, assume max number 127
;//     1a) account for base 1, 0 is replaced with NON_DIGIT
;//     2) leave '-' as is
;//     3) turn non digits into NON_DIGIT
;//     4) turn terminator into TERM_DIGIT
;//     5) saturate bad values

                TERM_DIGIT      EQU 0FFh
                NON_DIGIT       EQU 0FEh

                mov ecx, esi
                ASSUME ecx:PTR BYTE

top_of_1:       xor eax, eax
                mov  al, [ecx]      ;// get the char
                test al, al         ;// terminator ?
                jz   end_of_1
                cmp  al, '-'        ;// range char ?
                je   next_char_1
                sub  al, '0'        ;// digit ?
                jb   non_digit_1
                cmp  al, 9
                jbe  got_digit_1
non_digit_1:    mov  [ecx], NON_DIGIT   ;// non digit
next_char_1:    inc  ecx
                jmp  top_of_1
ALIGN 16    ;// got digit
got_digit_1:    mov ebx, ecx            ;// ebx remembers where we started
                mov edx, eax            ;// edx is the number we're building
next_digit_1:   inc ecx                 ;// next char
                mov al, [ecx]           ;// look at it
                sub al, '0'             ;// digit ?
                jb  digit_done_1
                cmp al, 9
                ja  digit_done_1
            ;// build digit
                lea edx, [edx+edx*4]    ;// = number*5
                lea edx, [eax+edx*2]    ;// = (number*5)*2+digit
                jmp next_digit_1
ALIGN 16    ;// done with consecutive, edx hold the
                ASSUME ebx:PTR BYTE
digit_done_1:   cmp ebp, 15
                mov al, NON_DIGIT       ;// fill with NON_DIGIT
                jne use_128_bit

                test dl, dl             ;// check for zero
                jne digit_not_zero
                mov dl, al              ;// use non digit to fill zero
                jmp number_ok_1
digit_not_zero: dec edx     ;// one based

use_128_bit:    cmp edx, ebp            ;// make sure number is not too big
                jbe number_ok_1
                mov edx, ebp            ;// saturate
number_ok_1:    mov [ebx], dl           ;// save xformed number in in_iter
            ;// fill useless bytes with non digit
digit_fill_1:   inc ebx                 ;// advance in_iter
                cmp ebx, ecx            ;// done yet ?
                jae  top_of_1           ;// go back to main loop if done
                mov [ebx], al           ;// fill with character
                jmp digit_fill_1        ;// keep filling characters
ALIGN 16    ;// done with input string
end_of_1:       mov [ecx], TERM_DIGIT

    ;// now we have a prepared string

            ASSUME ecx:NOTHING
            ASSUME ebx:NOTHING

    ;// scan two
    ;// process the commands

comment ~ /*

    algorithm:

        let state be a number from 0 to 2

            0 = have a valid number in ebx
            1 = have a valid number in ebx and have recieved a range command
            2 = have a valid number in ebx and just finished processing a range
                ebx = end of previous range

    1) prescan to find first valid digit
        load ebx
        set state = 0

    2)  process rest of string

                    in   proc proc  load  out
        event      state ebx  range ebx  state
        ---------  ----- ---- ----- ---- -----

        non_digit   x     0     0    0    same

        got_digit   0     1     0    1    0
                    1     0     1    1    2
                    2     1     0    1    0

        got_range   x     0     0    0    1

        got_term    0     1
                    1     1
                    2     0

*/ comment ~

        ;// ecx is start range
        ;// ebx is stop rage

    ;// 1) prescan

                xor eax, eax

                .REPEAT
                    lodsb
                    cmp al, TERM_DIGIT
                    je all_done
                .UNTIL al != NON_DIGIT

                mov ebx, eax    ;// prev num
                mov edx, 0      ;// state = 0

    ;// 2) scan the rest

top_of_scan_2:  xor eax, eax        ;// clear always
                mov al, [esi]       ;// load the char
                cmp al, NON_DIGIT   ;// not digit ?
                je  next_char_2
                cmp al, '-'         ;// range command ?
                je  got_range
                cmp al, TERM_DIGIT  ;// terminator ?
                je  got_term
            ;// got_digit
                mov ecx, eax        ;// store
                cmp edx, 1          ;// state 1 ?
                je process_range    ;// else state = 0 or 2
            ;// process ebx
                mov edx, ebx        ;// xfer bit position to edx
                mov eax, ebx        ;// xfer bit position to eax
                shr edx, 5          ;// turn edx into a dword index
                and eax, 11111y     ;// turn ecx into a bit index
                bts [edi+edx*4], eax;// set the bit
            ;// load ebx
                mov ebx, ecx        ;// load ebx with char
                xor edx, edx        ;// exit state 0
next_char_2:    inc esi             ;// advance esi
                jmp top_of_scan_2   ;// continue on

got_range:      mov edx, 1          ;// exit state is always 1
                jmp next_char_2     ;// continue on
ALIGN 16
process_range:  cmp ecx, ebx        ;// make sure start is below stop
                jbe P0
                xchg ecx, ebx
            ;// scan ecx until ebx
            P0: mov edx, ecx        ;// xfer bit position to edx
                mov eax, ecx        ;// xfer bit position to eax
                shr edx, 5          ;// turn edx into a dword index
                and eax, 11111y     ;// turn ecx into a bit index
                bts [edi+edx*4], eax;// set the bit
            ;// next bit
                inc ecx             ;// increase the start count
                cmp ecx, ebx        ;// check if done
                jbe P0              ;// loop if still bits remaining
            ;// load ebx with new digit
                mov bl, [esi]       ;// load ebx
                mov edx, 2          ;// exit with state 2
                jmp next_char_2

ALIGN 16
got_term:       cmp edx, 2          ;// state we care about ?
                je all_done         ;// exit if not
            ;// process ebx
                mov edx, ebx        ;// xfer bit position to edx
                mov eax, ebx        ;// xfer bit position to eax
                shr edx, 5          ;// turn edx into a dword index
                and eax, 11111y     ;// turn ecx into a bit index
                bts [edi+edx*4], eax;// set the bit

            ;// that's it

all_done:       pop ebx
                xchg esi,[esp+04h]
                xchg edi,[esp+08h]
                xchg ebp,[esp+0Ch]

                ret 0Ch


midi_szrange_to_bits ENDP
PROLOGUE_ON




;// this is the opposite of the above
;// assume that
;//     if we just built bits from a string
;//     then we will never generate a longer string

;// rules:
;//
;//     look for minimum of THREE consecutive bits
;//     this eliminates strings like 1-2 which is not shorter and wastes processing
;//
;// scheme:
;//
;//     maintain numerical counters and flags as required
;//     advance a string called stop_bit
;//     when nessesary, xfer it to start bit
;//
;//     ebx stop_bit        string represents the current bit position
;//     ebp start_bit       string represens the first on bit we saw
;//     esp last_bit        ptr to string represents the last on bit we saw
;//
;//     esi source ptr      ptr to the source bits, arranged as dwords
;//     edi dest ptr        ptr to the output string
;//
;//     eax temp storage
;//
;//     dl  con_bit         counter of consecutive on bits
;//     dh  need_space      flag says we emit a space before emiting a string
;//     cl  total_bits      counter of total bits
;//     ch  bit_counter     counter of bits in the source dword
;//
ASSUME_AND_ALIGN
PROLOGUE_OFF
midi_bits_to_szrange PROC STDCALL pBits:DWORD, num_bits:DWORD, pStr:DWORD
                        ;// 00      04          08              0C

            xchg esi,[esp+04h]  ;// esi scans input bits
            ASSUME esi:PTR DWORD
            xchg edi,[esp+0Ch]  ;// edi is the dest string
            ASSUME edi:PTR BYTE
            xchg ebp,[esp+08h]  ;// need to store, loads num_bits
            push ebx            ;// ebx holds one extent for ranges

            xor ecx, ecx
            xchg ecx, ebp   ;// cl is total_bits, clears bit_counter and start_bit as well
            xor edx, edx    ;// reset  con_bit and need space

            cmp ecx, 16
            mov ebx, '0'    ;// start at zero (usually)
            push edx        ;// last on bit (start at zero)
            jne get_bit     ;// start at one (for one based display)
            inc ebx         ;// one based, start at 1

            jmp get_bit     ;// enter the loop


    con_bit     TEXTEQU <dl>    ;// counter of consecutive bits
    need_space  TEXTEQU <dh>    ;// flag says we emit a space before emiting a string
    total_bits  TEXTEQU <cl>    ;// counter of total bits
    bit_counter TEXTEQU <ch>    ;// counter of bits in the source dword

    stop_bit    TEXTEQU <ebx>   ;// string represents the last on bit we saw
    start_bit   TEXTEQU <ebp>   ;// string represens the first on bit we saw
    last_bit    TEXTEQU <(DWORD PTR [esp])>

ALIGN 16
top_of_bit_scan:

            dec total_bits      ;// done yet ?
            jz done_with_bits

get_bit:    xor eax, eax
            cmp bit_counter, 32 ;// are there any bits left in input dword ?
            jb  GB1
            mov bit_counter, 0  ;// reset the counter
            add esi, 4          ;// advance the pointer
    GB1:    mov al, bit_counter ;// put bit position in eax
            bt  [esi], eax      ;// copy bit to carry flag
            inc bit_counter     ;// increase AFTER (doesn't effect carry)
            jnc bit_not_set     ;// if set

bit_is_set: inc  con_bit
            mov  last_bit, stop_bit
            test start_bit, start_bit   ;// have we set start bit yet ?
            jnz  advance_stop_bit
            mov  start_bit, stop_bit    ;// time to set start bit
            jmp  advance_stop_bit

bit_not_set:test con_bit, con_bit   ;// if con_bit ?
            jz   advance_stop_bit

            mov  eax, start_bit ;// emit start_bit
            call emit_eax

            sub  con_bit, 2
            je   P1 ;// con_bit = 2
            jb   P2 ;// con_bit = 1
                    ;// con_bit > 2
            mov al, '-'         ;//emit "-"
            stosb
            mov need_space, 0   ;// reset need_space
        P1: mov eax, last_bit   ;// emit stop_bit
            call emit_eax
        P2: and start_bit, 0    ;// reset start_bit
            and con_bit, 0  ;// reset con_bit

advance_stop_bit:

            inc bl          ;// advance the ones digit
            cmp bl, '9'     ;// check for overflow
            jbe top_of_bit_scan
            mov bl, '0'     ;// reset ones bit
            test bh, bh     ;// see if we've ever hit 10
            mov al, 1
            jnz AS3
            mov al, '1'
        AS3:add bh, al      ;// advance the tens digit
            cmp bh, '9'     ;// check for overflow
            jbe top_of_bit_scan
            mov bh, '0'     ;// reset the tens digit
            mov eax, 10000h
            test ebx, 000FF0000h    ;// check if we've gotten to 100 yet
            jnz AS1
            mov eax, 310000h        ;// set as 100 if so
        AS1:add ebx, eax
            jmp top_of_bit_scan

ALIGN 16
emit_eax:

    ;// emits characters in eax
    ;// takes care of need space
    ;// always exits with need space on

        bswap eax       ;// reverse the digits, assume that al will be zero

        test need_space, need_space
        jz EA1

        or eax, 20h
        stosb
    ;// shift eax until we get a digit
EA1:    shr eax, 8
        test eax, 0FFh
        jz EA1
    ;// store digit and shift eax until empty
EA2:    stosb
        shr eax, 8
        jnz EA2
    ;// exit and set need_space
        mov need_space, 1
        retn


ALIGN 16
done_with_bits:

            test con_bit, con_bit   ;// if con_bit ?
            jz   term_string

            mov  eax, start_bit     ;// emit start_bit
            call emit_eax

            sub  con_bit, 2
            je   Q1                 ;// con_bit = 2
            jb   term_string        ;// con_bit = 1
                                    ;// con_bit > 2
            mov al, '-'             ;//emit "-"
            stosb
            mov need_space, 0       ;// reset need_space
        Q1: mov eax, last_bit       ;// emit stop_bit
            call emit_eax

        term_string:

            xor eax, eax    ;// terminate the string
            stosb

            pop edx
            pop ebx
            xchg esi,[esp+04h]
            xchg ebp,[esp+08h]
            xchg edi,[esp+0Ch]
            ret 12


midi_bits_to_szrange ENDP
PROLOGUE_ON



ASSUME_AND_ALIGN
END


