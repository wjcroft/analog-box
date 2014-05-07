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
;// knob_parser.asm
;//
OPTION CASEMAP:NONE
.586
.MODEL FLAT



    .NOLIST
    INCLUDE <ABox.inc>
    INCLUDE <ABox_Knob.inc>
    INCLUDE <wordtree.inc>
    INCLUDE <szfloat.inc>
    .LIST


comment ~ /*

pre-process this file with wordtree.exe $filename

Units

    AUTO
    VALUE      VAL
    INTERVAL  INTERVAL INT
    DB DECIBEL
    HERTZ HZ KHZ
    MIDI
    SECONDS SEC MIN MS S US
    NOTE
    BPM TEMPO
    SAMPLES SAM
    LOGIC BOOL TRUE FALSE
    BINS BIN
    DEGREES DEG
    PANNER  LEFT RIGHT CENTER PAN PANNER
    PERCENT %

Taper

    AUDIO LINEAR
    AUD LIN LOG

Turns

    1 TURN 1X

Mode

    MUL MULTIPLY MULT *
    ADD +
    KNOB



examples with parseing

    knob 1   turn 0.0 auto linear
    MODE NUM TURN NUM UNIT TAPER
         NUM_TURN NUM_UNIT

    11.25 hz 64x * audio

    linear 64  turns midi 60
    TAPER  NUM TURN  UNIT NUM
    TAPER  NUM_TURN  UNIT VALUE

    pan 25% left

    multiply -45 degrees

    42.6 bins linear 1 turn


*/ comment ~

.CODE


    ;// number error codes returned in eax
    TOKEN_NUMBER_BAD            EQU NUMBER_RANGE_ERROR
    TOKEN_NUMBER_BAD_SMALL_POS  EQU NUMBER_TOO_SMALL
    TOKEN_NUMBER_BAD_SMALL_NEG  EQU NUMBER_TOO_SMALL_NEG
    TOKEN_NUMBER_BAD_BIG_POS    EQU NUMBER_TOO_LARGE
    TOKEN_NUMBER_BAD_BIG_NEG    EQU NUMBER_TOO_LARGE_NEG

    .ERRE (TOKEN_NUMBER_BAD AND 80000000h), <source code wants to use the sign bit>

                                ;// X
                                ;// 80000000h mask
                                ;// 80000000h
                                ;// 90000000h
                                ;// A0000000h
                                ;// B0000000h

    ;// error codes                   XX
    TOKEN_EOS                   EQU 00010000h   ;// End Of String
    TOKEN_NaT                   EQU 00020000h   ;// Not a Token or a number

    ;// good return codes                XXX
    TOKEN_NUMBER                EQU 00000001h   ;// fpu has number
    TOKEN_UNITS                 EQU 00000002h
    TOKEN_TURNS                 EQU 00000004h
    TOKEN_MODE                  EQU 00000008h
    TOKEN_TAPER                 EQU 00000010h
    TOKEN_BOOL                  EQU 00000020h   ;// true/false require special treatment
    TOKEN_PAN                   EQU 00000040h   ;// pan requires special treament
    TOKEN_NOTE                  EQU 00000080h   ;// note_parser builds the value
    TOKEN_NEG                   EQU 00000100h   ;// needed for db, note and interval

    ;// modifiers                       X
    TOKEN_GIGA                  EQU 00001000h
    TOKEN_MEGA                  EQU 00002000h
    TOKEN_KILO                  EQU 00003000h
    TOKEN_MILLI                 EQU 00004000h
    TOKEN_MICRO                 EQU 00005000h
    TOKEN_NANO                  EQU 00006000h

    TOKEN_ENG_TEST              EQU 00007000h



    ;// these positioning macros are convenient
    ;// they use no registers and only iterate esi
    ;// supply exit points or rely on fall through

    EAT_BLACK MACRO good, bad

        ;// eats non white until white or end

        .REPEAT
            IFB <bad>
                .BREAK .IF ![esi]
            ELSE
                CMPJMP [esi], 0, je bad
            ENDIF
            IFB <good>
                .BREAK .IF [esi] <= ' '
            ELSE
                CMPJMP [esi],' ',jbe good
            ENDIF
            inc esi
        .UNTIL 0

        ENDM

    EAT_WHITE MACRO good, bad

        ;// eats white until non white or end

        .REPEAT
            IFB <bad>
                .BREAK .IF ![esi]
            ELSE
                CMPJMP [esi], 0, je bad
            ENDIF
            IFB <good>
                .BREAK .IF [esi] > ' '
            ELSE
                CMPJMP [esi],' ',ja good
            ENDIF
            inc esi
        .UNTIL 0

        ENDM





















ASSUME_AND_ALIGN
get_token PROC

comment ~ /*

imput: esi points at string

output:

    carry   eax     edx     esi     FPU
      0     TOKEN   ATTRIB  NEXT    x
      0     NUMBER  x       NEXT    number

      1     EOS     x       x       x

      1     NaT     LAST    START   x

      1     ><+-    LAST    START   empty

*/ comment ~

        ASSUME esi:PTR BYTE

        EAT_WHITE ,token_eos    ;// eat whitespace, if any

        CALLJMP knob_parser ,   jnc  all_done
        CALLJMP sz_to_float ,   jnc  got_float
        TESTJMP eax, eax    ,   js   bad_float
        CALLJMP note_parser ,   jnc  all_done
        CALLJMP interval_parser,jnc  all_done

        mov eax, TOKEN_NaT

    all_done:

        ret

    ALIGN 16
    got_float:  ;// carry is already off

        mov eax, TOKEN_NUMBER
        jmp all_done

    bad_float:  ;// is a number, but is big or small, we return the error in eax
                ;// edx has last character
        or eax, TOKEN_NUMBER
        stc
        jmp all_done

    token_eos:  ;// we simply do not have anymore characters

        mov eax, TOKEN_EOS
        stc
        jmp all_done


get_token ENDP





comment ~ /*

UNIT            set_units
MODE            set_mode
TAPER           set_taper
TURNS           ignore
????            ignore

NUMBER UNIT     set_units and set_value
NUMBER TURNS    set_turns
NUMBER ????     set_value with default units

*/ comment ~


ASSUME_AND_ALIGN
knob_ProcessCommandString PROC STDCALL USES esi edi ebx pString:DWORD

        ASSUME esi:PTR OSC_KNOB_MAP
        mov ebx, esi
        ASSUME ebx:PTR OSC_KNOB_MAP
        mov esi, pString
        ASSUME esi:PTR BYTE

;// A:  GET TOKEN
node_A: call get_token
        jc A_token_error
;// B:
node_B: TESTJMP eax, TOKEN_NUMBER,  jnz NUMBER
        TESTJMP eax, TOKEN_UNITS,   jnz UNITS
        TESTJMP eax, TOKEN_MODE,    jnz MODE
        TESTJMP eax, TOKEN_TAPER,   jnz TAPER
        TESTJMP eax, TOKEN_BOOL,    jnz BOOL
        TESTJMP eax, TOKEN_PAN,     jnz PAN
        TESTJMP eax, TOKEN_NOTE,    jnz NOTE
        TESTJMP eax, TOKEN_NEG,     jnz _NEG
        ;// TESTJMP eax, TOKEN_TURNS,   jnz TURNS   ;// turns by itself doesn't mean anything
        jmp node_A  ;// just ignore

    ALIGN 16
    NUMBER: ;// NUMBER

            push eax                    ;// push the return code for the number
            call get_token              ;// GET TOKEN
            jc B_next_token_error

            TESTJMP eax, TOKEN_UNITS,   jnz NUMBER_UNITS
            TESTJMP eax, TOKEN_TURNS,   jnz NUMBER_TURNS
            TESTJMP eax, TOKEN_NUMBER,  jnz NUMBER_NUMBER

            NUMBER_OTHER:

                xchg eax, [esp]         ;// save the state
                push edx                ;// save the token attribute

                mov edx, [ebx].dwUser   ;// use default units
                and edx, UNIT_TEST
                call set_value          ;// set the value

                pop edx                 ;// retrieve token attributes
                pop eax                 ;// retrieve token type
                jmp node_B              ;// back to token handler with token we just got

            ALIGN 16
            NUMBER_UNITS:

            ;// state:  eax has toke plus eng modifiers
            ;//         edx has new unit
            ;//         stack has number attributes

                push eax    ;// need to save any eng modifiers we might have

            ;// if UNIT != AUTO set new unit

                .IF edx & UNIT_AUTO_UNIT        ;// use existing units

                    mov edx, [ebx].dwUser
                    .IF !(edx & UNIT_AUTO_UNIT) ;// now we are auto unit

                        or [ebx].dwUser, UNIT_AUTO_UNIT
                        or [ebx].knob.dwFlags, KNOB_NEW_AUTO OR KNOB_NEW_UNITS

                    .ENDIF
                    and edx, UNIT_TEST

                .ELSE                           ;// if new units are different than old, set them
                                                ;// if auto unit was one, set the trace flag
                    BITR [ebx].dwUser, UNIT_AUTO_UNIT
                    .IF CARRY?
                        or [ebx].knob.dwFlags, KNOB_NEW_AUTO OR KNOB_NEW_UNITS
                    .ENDIF
                    mov eax, [ebx].dwUser
                    and eax, UNIT_TEST
                    and edx, UNIT_TEST

                    .IF eax != edx              ;// have new units
                        mov eax, [ebx].dwUser
                        and eax, NOT (UNIT_TEST OR UNIT_AUTO_UNIT OR UNIT_AUTOED)
                        or eax, edx
                        mov [ebx].dwUser, eax
                        or [ebx].knob.dwFlags, KNOB_NEW_UNITS OR KNOB_NEW_AUTO
                    .ENDIF

                .ENDIF

            ;// now edx has the unit we set the value for
            ;// process the value modifiers, if any

                pop eax                 ;// retrieve eng modifier flags
                and eax, TOKEN_ENG_TEST ;// remove all else
                or eax, [esp]           ;// merge in number flags
                add esp, 4              ;// discard number flag from stack

                call set_value          ;// set value with new units

                jmp node_A              ;// back to top of parser

            ALIGN 16
            NUMBER_TURNS:

                pop eax                 ;// retrieve the number type
                TESTJMP eax, eax, js node_A ;// just ignore bad values

                ;// need to convert to log and stuff in dw user

                xor eax, eax

                fabs        ;// must be pos
                frndint     ;// must be integer
                ftst        ;// ignore 0, change to 1
                fnstsw ax
                sahf
                .IF ZERO?
                    fstp st
                    xor eax, eax
                .ELSE       ;// log turns = 16*log2(desired_turns)
                    push edx        ;// make temp space
                    fld  knob_turns_scale   ;// load the scalar
                    fxch
                    fyl2x           ;// 16*log2(desired_turns)
                    fistp DWORD PTR [esp]   ;// store as int
                    pop eax         ;// retrieve in eax
                    .IF eax >= 256  ;// not too many please
                        mov eax, 255
                    .ENDIF
                .ENDIF

                ;// eax has the new log turns
                ;// see if it is different than current

                mov edx, [ebx].dwUser       ;// D000
                shr edx, 24                 ;// 000D
                CMPJMP eax, edx, je node_A  ;// 000A == 000D ??

                shl  [ebx].dwUser, 8        ;// D000
                or   [ebx].knob.dwFlags, KNOB_NEW_TURNS
                shrd [ebx].dwUser, eax, 8   ;// A000

                jmp node_A


            ALIGN 16
            NUMBER_NUMBER:              ;// assume that we set the value using defaults
                                        ;// then use the new number as normal

                xchg eax, [esp]         ;// get the previous number type
                test eax, eax           ;// check if there's another number we use
                .IF !SIGN?
                    fxch
                .ENDIF

                mov edx, [ebx].dwUser   ;// use default units
                and edx, UNIT_TEST
                call set_value          ;// set the value

                pop eax                 ;// retrieve new number flags
                jmp node_B              ;// back to number scaner

            ALIGN 16
            B_next_token_error:

                ;// some sort of error

                TESTJMP eax, TOKEN_EOS, jnz B_end_of_string
                TESTJMP eax, eax, js NUMBER_NUMBER

                ;// the next token is un defined, so we ignore it
                B_advance_to_next:

                    mov esi, edx    ;// position to next token
                    EAT_BLACK

                ;// call set value with the previous number
                B_end_of_string:

                    pop eax                 ;// number type
                    mov edx, [ebx].dwUser   ;// load desired units
                    and edx, UNIT_TEST
                    call set_value          ;// call generic value setter
                    jmp node_A

    ;// TURNS:  ;// TURNS
    ;//     jmp node_A  ;// ignore, back to top

    ALIGN 16
    UNITS:  ;// UNITS

        .IF edx & UNIT_AUTO_UNIT

            BITSJMP [ebx].dwUser, UNIT_AUTO_UNIT, jc node_A ;// exit if already set
            or [ebx].knob.dwFlags, KNOB_NEW_UNITS
            and [ebx].dwUser, NOT UNIT_TEST
            jmp node_A

        .ENDIF

        ;// if new units are different than old, set them

        mov eax, [ebx].dwUser
        BITR eax, UNIT_AUTO_UNIT
        .IF CARRY?
            or [ebx].knob.dwFlags, KNOB_NEW_UNITS
            mov [ebx].dwUser, eax   ;// have to save that we are not now auto unit
        .ENDIF

        and eax, UNIT_TEST
        and edx, UNIT_TEST
        CMPJMP eax, edx, je node_A

        mov eax, [ebx].dwUser
        and eax, NOT (UNIT_TEST OR UNIT_AUTO_UNIT OR UNIT_AUTOED)
        or eax, edx
        mov [ebx].dwUser, eax
        or [ebx].knob.dwFlags, KNOB_NEW_UNITS

        jmp node_A              ;// back to top

    ALIGN 16
    MODE:   ;// MODE

        mov eax, [ebx].dwUser
        and eax, NOT KNOB_MODE_TEST
        or eax, edx
        mov [ebx].dwUser, eax
        or [ebx].knob.dwFlags, KNOB_NEW_MODE
        jmp node_A              ;// back to top

    ALIGN 16
    TAPER:  ;// TAPER

        mov eax, [ebx].dwUser
        and eax, NOT KNOB_TAPER_TEST
        or eax, edx
        mov [ebx].dwUser, eax
        or [ebx].knob.dwFlags, KNOB_NEW_TAPER
        jmp node_A              ;// back to top

    ALIGN 16
    BOOL:   ;// TRUE and FALSE


        mov eax, [ebx].dwUser
        and eax, NOT ( UNIT_TEST OR UNIT_AUTO_UNIT OR UNIT_AUTOED )
        or eax, UNIT_LOGIC
        mov [ebx].dwUser, eax
        or [ebx].knob.dwFlags, KNOB_NEW_UNITS

        mov eax, [ebx].knob.value2
        .IF edx ;// false
            or eax, 80000000h
        .ELSE
            and eax, 7FFFFFFFh
        .ENDIF
        CMPJMP eax, [ebx].knob.value2, je node_A

        mov [ebx].knob.value2, eax
        or [ebx].knob.dwFlags, KNOB_NEW_VALUE OR KNOB_NEW_CONTROL
        jmp node_A

    ALIGN 16
    PAN:

        ;// center  edx = 0
        ;// L20%    edx = +1    number and percent not read yet
        ;// R20%    edx = -1

        .IF edx ;// center or left right ?

            push edx
            push esi
            invoke sz_to_float
            jc PAN_not_a_pan

            ;// PAN_NUMBER:

            mov [esp], esi  ;// have a valid number, save it's end
            EAT_WHITE       ;// consume the percent sign, if any
            cmp [esi], '%'
            jne PAN_P2      ;// no percent, backup to esi after number

            ;// PAN_NUMBER_PERCENT:

            add esp, 4      ;// otherwise, have a valid percent, don't need saved esi
            inc esi         ;// advance past the percent sign
            jmp PAN_P3

        PAN_P2: pop esi     ;// retrieve
        PAN_P3: pop edx

            ;// now we have FPU = value
            ;// edx has +-
            test edx, edx
            .IF SIGN?
                fchs
            .ENDIF

        .ELSE

            fldz

        .ENDIF

        ;// set the unit to pan

        mov eax, [ebx].dwUser
        mov edx, UNIT_PANNER
        and eax, NOT (UNIT_TEST OR UNIT_AUTO_UNIT OR UNIT_AUTOED)
        or eax, edx
        mov [ebx].dwUser, eax
        xor eax, eax

        call set_value

        jmp node_A

    PAN_not_a_pan:

        pop esi
        pop edx
        jmp node_A  ;// just ignore this


    ALIGN 16
    NOTE:

        ;// the value is already in the fpu

        mov eax, [ebx].dwUser
        mov edx, UNIT_NOTE
        and eax, NOT(UNIT_TEST OR UNIT_AUTO_UNIT OR UNIT_AUTOED)
        or eax, edx
        mov [ebx].dwUser, eax

        call set_value  ;// so we get a range check

        jmp node_A

    ALIGN 16
    _NEG:

        fld [ebx].knob.value2
        fchs
        fstp [ebx].knob.value2
        or  [ebx].knob.dwFlags, KNOB_NEW_VALUE OR KNOB_NEW_CONTROL
        jmp node_A



ALIGN 16
A_token_error:

    ;// some sort of error

        TESTJMP eax, TOKEN_EOS, jnz all_done    ;// EOS

            mov esi, edx    ;// keep going
            EAT_BLACK       ;// eat black

        TESTJMP eax, eax,   jns node_A
                            jmp NUMBER      ;// TOKEN_NUMBER_BAD

    ;// must return eax as a return value for popup_Command

ALIGN 16
all_done:

        ret


knob_ProcessCommandString ENDP





















;// unit_BuildString


.DATA

    unit_to_value_table LABEL REAL4
        REAL4 1.0                       ;// VALUE       ;//EQU  00000000h
        REAL4 0.0   ;// INTERVAL        ;//EQU  00001000h   ;//*1
        REAL4 0.166096405   ;// DB      log2(10)/20
        REAL4 4.535147392E-5; 1/22050   ;// HERTZ       ;//EQU  00003000h
        REAL4 7.8125E-3     ; 1/128     ;// MIDI        ;//EQU  00004000h
        REAL4 4.535147392E-5; 1/22050   ;// SECONDS     ;//EQU  00005000h
        REAL4 1.0                       ;// NOTE        ;//EQU  00006000h
        REAL4 7.558578987E-7; 1/(sample rate/2 * 60 sec/minute) ;//  BPM
        REAL4 9.765625E-4   ; 1/1024    ;// SAMPLES     ;//EQU  00008000h
        REAL4 1.0                       ;// LOGIC       ;//EQU  00009000h
        REAL4 1.953125E-3   ; 1/512     ;// BINS        ;//EQU  0000A000h
        REAL4 5.555555556E-3; 1/180     ;// DEGREES     ;//EQU  0000B000h
        REAL4 0.01          ; 1/100     ;// PANNER      ;//EQU  0000C000h
        REAL4 0.01          ; 1/100     ;// PERCENT     ;//EQU  0000D000h
        REAL4 2.267573696E-5; 1/44100   ;// 2xHERTZ     ;//EQU  0000E000h
        REAL4 1.0                       ;// MIDI_STREAM ;//EQU  0000F000h
        REAL4 1.0                       ;// SPECTRUM    ;//EQU  00010000h
        dd 0    ;// 11h
        dd 0    ;// 12h
        dd 0    ;// 13h
        dd 0    ;// 14h
        dd 0    ;// 15h
        dd 0    ;// 16h
        dd 0    ;// 17h
        dd 0    ;// 18h
        dd 0    ;// 19h
        dd 0    ;// 1Ah
        dd 0    ;// 1Bh
        dd 0    ;// 1Ch
        dd 0    ;// 1Dh
        dd 0    ;// 1Eh
        dd 0    ;// 1Fh


        dd set_value_AUTO           ;//EQU  00000800h   ;// -1 must be before table !!
    set_value_table LABEL DWORD
        dd set_value_VALUE          ;//EQU  00000000h   ;// 0   osc and pin ;
        dd set_value_INTERVAL       ;//EQU  00001000h   ;//*1
        dd set_value_DB             ;//EQU  00002000h   ;//*2       indexes ....
        dd set_value_HERTZ          ;//EQU  00003000h   ;// 3       these are also stored in knob dwuser
        dd set_value_MIDI           ;//EQU  00004000h   ;//*4       DO NOT CHANGE
        dd set_value_SECONDS        ;//EQU  00005000h   ;// 5
        dd set_value_NOTE           ;//EQU  00006000h   ;// 6   * these are set so some units line up
        dd set_value_BPM            ;//EQU  00007000h   ;// 7     with the old units (shown above)
        dd set_value_SAMPLES        ;//EQU  00008000h   ;//*8
        dd set_value_LOGIC          ;//EQU  00009000h   ;// 9
        dd set_value_BINS           ;//EQU  0000A000h   ;// A
        dd set_value_DEGREES        ;//EQU  0000B000h   ;// B
        dd set_value_PANNER         ;//EQU  0000C000h   ;// C
        dd set_value_PERCENT        ;//EQU  0000D000h   ;// D
        dd set_value_2xHERTZ        ;//EQU  0000E000h   ;// E   ABox219, used by file object
        dd set_value_MIDI_STREAM    ;//EQU  0000F000h   ;// F   ABox 220, MIDI_STREAM
        dd set_value_SPECTRUM       ;//EQU  00010000h   ;// 10  ABox 221
        dd 0    ;// 11h
        dd 0    ;// 12h
        dd 0    ;// 13h
        dd 0    ;// 14h
        dd 0    ;// 15h
        dd 0    ;// 16h
        dd 0    ;// 17h
        dd 0    ;// 18h
        dd 0    ;// 19h
        dd 0    ;// 1Ah
        dd 0    ;// 1Bh
        dd 0    ;// 1Ch
        dd 0    ;// 1Dh
        dd 0    ;// 1Eh
        dd 0    ;// 1Fh



    eng_modifier_table LABEL REAL4

        REAL4   1.0     ;// 0 not used
        REAL4   1.0E+9  ;// indexed as TOKEN_ENG_TEST
        REAL4   1.0E+6
        REAL4   1.0E+3
        REAL4   1.0E-3
        REAL4   1.0E-6
        REAL4   1.0E-9












.CODE



ASSUME_AND_ALIGN
set_value PROC

        ASSUME ebx:PTR OSC_KNOB_MAP

    ;// FPU has the value if eax has no error
    ;// eax has the token type  (check for errors)
    ;// edx has the unit type

        and edx, UNIT_TEST OR UNIT_AUTO_UNIT
        BITSHIFT edx, UNIT_INTERVAL, 1
        .IF CARRY?
            ;// we were auto unit
            DEBUG_IF <!!ZERO?>
            dec edx
        .ENDIF

        .IF !(eax & TOKEN_NUMBER_BAD)
            jmp set_value_table[edx*4]
        .ENDIF

    ;// the value is bad, we set that here

            ;// NUMBER_TOO_SMALL        EQU 080000000h  ;// 1000
            ;// NUMBER_TOO_SMALL_NEG    EQU 090000000h  ;// 1001
            ;// NUMBER_TOO_LARGE        EQU 0A0000000h  ;// 1010
            ;// NUMBER_TOO_LARGE_NEG    EQU 0B0000000h  ;// 1011

        xor edx, edx
        BITT eax, NUMBER_ERR_BIG
        .IF CARRY?
            mov edx, math_1
        .ENDIF
        BITT eax, NUMBER_ERR_NEG
        .IF CARRY?
            or edx, 80000000h
        .ENDIF
        xchg [ebx].knob.value2, edx ;// edx must exit with previous value

        jmp all_done



    ;// LOGRITHMIC
    ALIGN 16
    set_value_DB::

        ;// db = scale * log2(val)
        ;// 2^(db/scale)

        fmul unit_to_value_table[edx*4]
        fld math_1
        fxch
        fpu_2X 1
        fxch
        jmp check_the_value_already_1


    ;// INVERSE LINEAR
    ALIGN 16
    set_value_SECONDS::

        ;// check for eng modifier
        and eax, TOKEN_ENG_TEST
        .IF !ZERO?
            BITSHIFT eax, TOKEN_ENG_TEST, 1
            fmul eng_modifier_table[eax*4]
        .ENDIF

        ;// check for zero
        xor eax, eax
        ftst
        fnstsw ax
        sahf
        jz check_the_value

        ;// normalize
        fdivr unit_to_value_table[edx*4]
        jmp check_the_value

    ;// LINEAR WITH ENG MODIFIER
    ALIGN 16
    set_value_HERTZ::

        ;// check for eng modifier
        ANDJMP eax, TOKEN_ENG_TEST, jz set_value_HERTZ_
        BITSHIFT eax, TOKEN_ENG_TEST, 1
        fmul eng_modifier_table[eax*4]
        jmp set_value_HERTZ_


    ;// LINEAR
    ALIGN 16
    set_value_HERTZ_:
    set_value_BPM::
    set_value_MIDI::
    set_value_SAMPLES::
    set_value_BINS::
    set_value_DEGREES::
    set_value_PERCENT::
    set_value_2xHERTZ::
    set_value_PANNER::

        fmul unit_to_value_table[edx*4]

    ;// NO SCALING
    set_value_INTERVAL::
    set_value_NOTE::
    set_value_VALUE::
    set_value_LOGIC::
    set_value_AUTO::

    ;// RANGE CHECK
    check_the_value:

    ;// check for high or low

        fld math_1      ;// 1   X

    check_the_value_already_1:

        fld st(1)       ;// X   1   X
        fabs
        fucomp          ;// 1   X
        fnstsw ax
        sahf
        jbe num_ok

        fxch        ;// X   1
        ftst
        fnstsw ax
        sahf
        jnc num_ok

        fxch
        fchs
        fxch

    num_ok:

        mov edx, [ebx].knob.value2  ;// edx must be previous value
        fstp st                     ;// dont need 1 anymore
        fstp [ebx].knob.value2      ;// store the new value

    all_done:   ;// edx MUST HAVE PREVIOUS VALUE

        .IF edx != [ebx].knob.value2
            or [ebx].knob.dwFlags, KNOB_NEW_VALUE OR KNOB_NEW_CONTROL
        .ENDIF

    now_all_done:

        ret



    ;// ERRORS
    set_value_MIDI_STREAM::
    set_value_SPECTRUM::

        fstp st
        jmp now_all_done

;// @MESSAGE fix this !!!


set_value ENDP




;//////////////////////////////////////////////////////////////////////////////////
;//
;// knob parser wordtree
;//

.DATA

    WORDTREE_MAKEUPPERTABLE

.CODE

;// extracts text tokens from the input string
;//
;// destroys eax and edx
;//
;// enter:  esi points at start of string
;// exit:   carry set for no match
;//             if set, edx points at char that ended the scan
;//         no carry
;//             edx has attributes of the token
;//             eax has the token class



ASSUME_AND_ALIGN
knob_parser PROC

comment ~ /*

input:  esi points at string
output:

    carry   eax     edx     esi
    -----   -----   ------  -----
      0     TOKEN   ATTRIB  NEXT
      1     NaT     LAST    START

*/ comment ~

;// wordtree.cpp builds the parser for us

    WORDTREE_BEGIN knob_parser_tree

;// we exit to one of the labels below

;// Units

    WORDTREE    AUTO

        mov edx, UNIT_AUTO_UNIT
        mov eax, TOKEN_UNITS
        jmp return_success

    WORDTREE    VALUE
    WORDTREE_t_DIGIT    VAL

        mov edx, UNIT_VALUE
        mov eax, TOKEN_UNITS
        jmp return_success

comment ~ /*
    W ORDTREE   INTERVAL
    W ORDTREE   INT

@MESSAGE Fix this !!!

        int 3   ;// have to parse the interval
        mov edx, UNIT_INTERVAL
        mov eax, TOKEN_UNITS
        jmp return_success
*/ comment ~

    WORDTREE    DB
    WORDTREE    DECIBEL
    WORDTREE    DECIBELS

        mov edx, UNIT_DB
        mov eax, TOKEN_UNITS
        jmp return_success

    WORDTREE    HERTZ
    WORDTREE    HZ

        mov edx, UNIT_HERTZ
        mov eax, TOKEN_UNITS
        jmp return_success

    WORDTREE    KHZ

        mov edx, UNIT_HERTZ
        mov eax, TOKEN_UNITS OR TOKEN_KILO
        jmp return_success

    WORDTREE    NHZ

        mov edx, UNIT_HERTZ
        mov eax, TOKEN_UNITS OR TOKEN_NANO
        jmp return_success

    WORDTREE    GHZ

        mov edx, UNIT_HERTZ
        mov eax, TOKEN_UNITS OR TOKEN_GIGA
        jmp return_success

    WORDTREE    MHZ

        mov edx, UNIT_HERTZ
        mov eax, TOKEN_UNITS OR TOKEN_MEGA
        CMPJMP [esi-4],'M', je return_success
        mov eax, TOKEN_UNITS OR TOKEN_MILLI
        jmp return_success

    WORDTREE_t_DIGIT    MIDI

        mov edx, UNIT_MIDI
        mov eax, TOKEN_UNITS
        jmp return_success

    WORDTREE    SECONDS
    WORDTREE    SECOND
    WORDTREE    SEC
    WORDTREE    S

        mov edx, UNIT_SECONDS
        mov eax, TOKEN_UNITS
        jmp return_success

    WORDTREE    MS

        mov edx, UNIT_SECONDS
        mov eax, TOKEN_UNITS OR TOKEN_MILLI
        CMPJMP [esi-3],'m', je return_success
        mov eax, TOKEN_UNITS OR TOKEN_MEGA
        jmp return_success

    WORDTREE    KS

        mov edx, UNIT_SECONDS
        mov eax, TOKEN_UNITS OR TOKEN_KILO
        jmp return_success

    WORDTREE    US

        mov edx, UNIT_SECONDS
        mov eax, TOKEN_UNITS OR TOKEN_MICRO
        jmp return_success

    WORDTREE    NS

        mov edx, UNIT_SECONDS
        mov eax, TOKEN_UNITS OR TOKEN_NANO
        jmp return_success

    WORDTREE    NOTE

        mov edx, UNIT_NOTE
        mov eax, TOKEN_UNITS
        jmp return_success

    WORDTREE    BPM
    WORDTREE    TEMPO

        mov edx, UNIT_BPM
        mov eax, TOKEN_UNITS
        jmp return_success

    WORDTREE    SAMPLES
    WORDTREE    SAMPLE
    WORDTREE_t_DIGIT    SAM

        mov edx, UNIT_SAMPLES
        mov eax, TOKEN_UNITS
        jmp return_success

    WORDTREE    LOGIC
    WORDTREE    BOOL

        mov edx, UNIT_LOGIC
        mov eax, TOKEN_UNITS
        jmp return_success

    ;// these are both a unit and a value
    WORDTREE    TRUE

        mov eax, TOKEN_BOOL
        or edx, -1
        jmp return_success

    WORDTREE    FALSE

        mov eax, TOKEN_BOOL
        xor edx, edx
        jmp return_success


    WORDTREE    BINS
    WORDTREE_t_DIGIT    BIN

        mov edx, UNIT_BINS
        mov eax, TOKEN_UNITS
        jmp return_success

    WORDTREE    PHASE
    WORDTREE    ANGLE
    WORDTREE    DEGREES
    WORDTREE    DEGREE
    WORDTREE    DEG

        mov edx, UNIT_DEGREES
        mov eax, TOKEN_UNITS
        jmp return_success

    WORDTREE    PANNER
    WORDTREE_t_DIGIT    PAN

        mov edx, UNIT_PANNER
        mov eax, TOKEN_UNITS
        jmp return_success

    ;// these are qualifiers for pan
    WORDTREE    LEFT
    WORDTREE_t_DIGIT    L

        mov eax, TOKEN_PAN
        mov edx, 1
        jmp return_success

    WORDTREE    RIGHT
    WORDTREE_t_DIGIT    R

        mov eax, TOKEN_PAN
        or  edx, -1
        jmp return_success

    WORDTREE    CENTER

        mov eax, TOKEN_PAN
        xor edx, edx
        jmp return_success



    WORDTREE    PERCENT
    WORDTREE    !%

        mov edx, UNIT_PERCENT
        mov eax, TOKEN_UNITS
        jmp return_success

;// Taper

    WORDTREE    AUDIO
    WORDTREE    AUD
    WORDTREE    LOG

        mov edx, KNOB_TAPER_AUDIO
        mov eax, TOKEN_TAPER
        jmp return_success

    WORDTREE    LINEAR
    WORDTREE    LIN

        mov edx, KNOB_TAPER_LINEAR
        mov eax, TOKEN_TAPER
        jmp return_success

;// Turns

    WORDTREE    TURNS
    WORDTREE    TURN
    WORDTREE    T

        mov eax, TOKEN_TURNS
        jmp return_success

;// Mode

    WORDTREE    MULTIPLY
    WORDTREE    MULT
    WORDTREE    MUL
    WORDTREE    *

        mov edx, KNOB_MODE_MULT
        mov eax, TOKEN_MODE
        jmp return_success

    WORDTREE    ADD
    WORDTREE    +

        mov edx, KNOB_MODE_ADD
        mov eax, TOKEN_MODE
        jmp return_success

    WORDTREE    KNOB

        mov edx, KNOB_MODE_KNOB
        mov eax, TOKEN_MODE
        jmp return_success

;// commands

    WORDTREE    NEG
    WORDTREE    -

        mov eax, TOKEN_NEG
        jmp return_success



;// parser terminator and exit

    WORDTREE_END



knob_parser ENDP



;/////////////////////////////////////////////////////////////////////////////
;//
;// note parser
;//                 NOTE [#b] OCT [DET]
;//
;//     F = 440/22050 *2^( ( NOTE+DET*0.01 + (OCT-4)*12 ) / 12 )
;//     F = 11/8820 * 2^ ( NOTE/12 + DET/1200 + OCT )
;//

.DATA
    ;//                 A A# B C C# D D# E F F# G  G#
    ;//                 0 1  2 3 4  5 6  7 8 9  10 11
    note_name_table db  0,   2,3,   5,   7,8,   10      ;// also unsed in interval_parser
    ALIGN 4

.CODE

ASSUME_AND_ALIGN
note_parser PROC

        push esi
        ASSUME esi:PTR BYTE

        xor eax, eax
        lodsb
        mov al, wordtree_UpperTable[eax]        ;// make upper
        SUBJMP al, 'A', jb return_fail
        CMPJMP al,  6 , ja return_fail

        ;// have a letter, convert to chromatic
        xor edx, edx
        mov dl, note_name_table[eax]

        ;// check for sharp or flat
        .IF [esi] == '#'
            inc esi
            inc edx
        .ELSEIF [esi]=='b'
            inc esi
            dec edx
        .ENDIF

        ;// of a number does not follow, we abort now
        CMPJMP [esi],'0',jb return_fail_no_dec
        CMPJMP [esi],'9',ja return_fail_no_dec

        push edx    ;// save chromatic on stack

        invoke sz_to_float
        jc no_octave_follows    ;// if error, we are not a note

        ;// check for detune
        invoke sz_to_float
        .IF !CARRY?
            ;// we have a detune
            fmul math_1_1200
            fadd
        .ENDIF

        ;// we have all the pieces we need
        fild DWORD PTR [esp];// NOTE    oct
        fmul math_1_12      ;// note    oct
        fld math_1          ;// 1       note    oct
        fxch st(2)          ;// oct     note    1
        fadd                ;// n       1

        fpu_2X 1

        fmul math_11_8820   ;// presto!

        fxch
        fstp st

    return_sucess:

        add esp, 8          ;// clears the carry flag
        mov eax, TOKEN_NOTE ;// return value

    all_done:

        ret

    ALIGN 16
    no_octave_follows:

        add esp, 4      ;// kill the stored octave
        mov esi, edx    ;// clumsy, but we must return how far we got
        inc esi

    return_fail:

        dec esi         ;// must point at char that ended scan

    return_fail_no_dec:

        mov edx, esi    ;// how far we got
        pop esi         ;// retrieve where we started
        xor eax, eax    ;// simply not a note

        stc             ;// return error code
        jmp all_done




note_parser ENDP




;/////////////////////////////////////////////////////////////////////////////
;//
;// interval parser
;//
;//     IVAL DET OCT
;//
;//         b2nd     #2nd      #3rd #4th      #5th      #6th
;//     oct      2nd      3rd  4th       5th       6th       7th
;//                  b3rd b4th      b5th      b6th      b7th
;//     0   1    2   3    4    5    6    7    8    9    10   11

comment ~ /*


    IVAL    #b  2       nd
                3       rd
                4567    th

    DET     +-  FLOAT
    OCT     +-  FLOAT

*/ comment ~

ASSUME_AND_ALIGN
interval_parser PROC



comment ~ /*
        push esi
        push ebx
        xor eax, eax

    ;// POS/NEG
        lodsb
        CMPJMP al, '+', jb  return_fail
                        je              ;// +2
        CMPJMP al, '-', jb  return_fail
                        jne         ;// +0

    add_two:    inc edx
    add_one:    inc edx

    ;// IVAL
        lodsb
        CMPJMP  al, '2', jb  return_fail
        CMPJMP  al, '7', jbe numeric_ival
        mov ebx, wordtree_UpperTable
        xlat
        CMPJMP  al, 'O', jne return_fail
        lodsb
        xlat
        CMPJMP  al, 'C', jne return_fail
        lodsb
        xlat
        CMPJMP  al, 'T', jne return_fail

    ;// got OCT

    number_is_1:
    numeric_ival:


    ;// DET


    ;// OCT

*/ comment ~




    stc ;// force error
    ret


interval_parser ENDP
















;/////////////////////////////////////////////////////////////////////////////
;//
;// knob_build_command_string
;//


PROLOGUE_OFF
ASSUME_AND_ALIGN
knob_BuildCommandString PROC STDCALL pString:DWORD, dwUser:DWORD, value:DWORD

    ;// builds a command string from the passed valuesknob.dwUser

    ;// stack
    ;// ret pString dwUser value
    ;// 00  04      08     0C

        st_string TEXTEQU <(DWORD PTR [esp+04h])>
        st_user   TEXTEQU <(DWORD PTR [esp+08h])>
        st_value  TEXTEQU <(DWORD PTR [esp+0Ch])>

;//     ASSUME esi:PTR OSC_KNOB_MAP ;// preserved

        xchg edi, st_string
        ASSUME edi:PTR BYTE         ;// preserved

        mov ecx, st_user

    ;// add 12345.6 Hz 23t linear
    ;// add 12.3456 KHz 23t log
    ;// mul 56uS 1024x log taper
    ;// pan 25% left 12turn audio taper


    ;// VALUE and UNIT

        fld st_value
        invoke unit_BuildString, edi, ecx, UBS_NO_SEP_EXP OR UBS_APPEND_NEG
        ;// ecx preserved
        ;// eax returns as endof string
        mov edi, eax

        .IF (ecx & UNIT_AUTO_UNIT) && (ecx & UNIT_TEST)

            mov eax, 'tua '
            stosd
            mov al, 'o'
            stosb

        .ENDIF

    ;// TURNS

        mov [edi], ' '
        inc edi

        xor eax, eax
        shld eax, ecx, 8
        invoke knob_log_turns_to_turns, eax
        mov edx, FLOATSZ_INT OR FLOATSZ_DIG_7
        invoke float_to_sz
        mov ax, ' t'
        stosw

    ;// TAPER

        mov eax, 'nil'
        .IF ecx & KNOB_TAPER_AUDIO
            mov eax, 'gol'
        .ENDIF
        stosd

    ;// MODE

        .IF ecx & KNOB_MODE_TEST
            mov [edi-1], ' '
            .IF     ecx & KNOB_MODE_ADD
                mov eax, 'dda'
            .ELSE   ;// ecx & KNOB_MODE_MULTIPLY
                mov eax, 'lum'
            .ENDIF
            stosd
        .ENDIF

    ;// DONE

        mov eax, edi
        mov edi, st_string
        dec eax

        retn 0Ch    ;// STDCALL 3 args

knob_BuildCommandString ENDP
PROLOGUE_ON













ASSUME_AND_ALIGN
END











