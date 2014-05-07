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

; AJT: this file evolved over 14 years of ASM projects
;      as such, it contains many untouched macros ...


;//
;//     utility.inc         useful macros
;//

IFNDEF _UTILITY_INCLUDED_

    _UTILITY_INCLUDED_ EQU 1

    INCLUDE <testjump.inc>  ;// used often enough

comment ~ /*

    toc:

    source code helpers

        PUSHARGS                pushes a list of things
        POPARGS                 pops a list in reverse order

        @REAL4                  builds a real4 from an integer expression
        EQU_POINT               defines a POINT (see geometry.inc)
        @POINT_REAL()           defines an fPOINT (see geometry.inc)

        LOG2()                  computes the bit position from the value

        BITT, BITC, BITR, BITS  bt commands save some typing

        BITSHIFT                shifts one set of bits to another set of bits
        CARRYSHIFT              shifts carry flag to desired bit location

        CSTR()                  initializes a string using C escape sequences

        ASSUME_AND_ALIGN        use to align and detect invalid assumptions

        PROLOGUE_OFF            turns off automatic prologue and epilog
        PROLOGUE_ON             turns on automatic prologue and epilog

        WIDECHAR()              builds a null terminated wide character string

        BRACKET()               adds brackets to a macro operand

        DATA_STRING             use to define a string in data seg, but with declartion in code seg

    debug support (all are enabled with DEBUGBUILD )

        DEBUG_IF <>             asm equiv of the C assert macro

        DIRECTION_FLAG_TEST     fails if the direction flag is set

        DEBUG_MESSAGE msg       one arg message

    fpu helpers

        FPU_SW                  equates for the status word values

        FPU_INIT_REAL4          initializes the fpu to various modes

        fpu_SetRoundMode

    win32 helpers

        HANDLE_WM               use in a naked window procedure
        ENABLE_CONTROL
        SUBCLASS_DEF_PROC       use in a naked subclassed window procedure

        LISTBOX                 sends message to listbox
        EDITBOX                 sends message to editbox
        WINDOW                  sends message to window
        WINDOW_P                posts message to window

        see also

            win32A_stdout.inc
            win32A_file.inc
            win32A_helper.inc

    masm macros

        @ArgI   returns indexed arg for VARARG
        @ArgC   returns the number of args in VARARG

        @MESSAGE    @Line just doesn't work
                    use this istead

*/ comment ~







;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;///
;///                                                            macro
;///    PUSHARGS
;///    POPARGS
;///
;///    pushes or pops a variable length list of things
;///
;///    ex:     PUSHARGS esi, edi, ebx, ebp
;///            POPARGS  esi, edi, ebx, ebp
;///
;///    or, more useful
;///
;///        my_macro MACRO arg1, arg2, ..., preserve:VARARG
;///
;///            PUSHARGS preserve
;///            .... do work
;///            POPARGS preserve
;///
;///            ENDM
;///
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////



    ;// hmm, does this work ?
    ;// hah, works like a champ -- good candidate to add to ultity.inc
    PUSHARGS MACRO a, b:VARARG
        IFNB <a>
        pushd a
        PUSHARGS b
        ENDIF
        ENDM
    POPARGS MACRO a, b:VARARG
        IFNB <a>
        POPARGS b
        pop a
        ENDIF
        ENDM





;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;///
;///                                                            function
;///    @REAL()
;///
;///        this will build a REAL4 from an integer or some such expression
;///
;///    ex:     myFloat REAL4 @REAL( 17 + an_integer )
;///    builds: myFloat REAL4 'numericvalue'
;///
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////

    @REAL MACRO val:req

        local t0, t1, t2

        t0 = val                ;// build whatever user passed
        IF t0 AND 80000000h     ;// check for negative value
            t0 = -t0            ;// make positive
            t1 TEXTEQU %t0      ;// define the string
            t2 CATSTR <->, t1, <.0e+0>  ;// assign as a negative number
        ELSE                    ;// positive value
            t1 TEXTEQU %t0      ;// assign as string
            t2 CATSTR t1, <.0e+0>   ;// build the ouput
        ENDIF
        EXITM t2

        ENDM



;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;///
;///                                                            macro
;///    EQU_POINT
;///
;///        this will build equates for a point struct
;///        usefull with the point_ routines in geometry
;///
;///    ex:     EQU_POINT myPoint, 10, 35
;///    builds: myPoint_X equ 10
;///            myPoint_Y equ 35
;///
;///
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////

    EQU_POINT MACRO name:req, XX:req, YY:req

        name&_X equ XX
        name&_Y equ YY

        ENDM


;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;///
;///                                                        function
;///    @POINT_REAL()
;///
;///        given a point defined with the above
;///        this will emit text to define an fPoint
;///
;///    ex:     @POINT_REAL( myPoint )
;///    builds: { @REAL(myPoint_X), @REAL(myPoint_Y) }
;///
;///
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////


    @POINT_REAL MACRO name:req

        LOCAL t0

        t0 CATSTR <{>,@REAL(&name&_X),<,>,@REAL(&name&_Y),<}>

        EXITM t0

        ENDM





;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;///
;///                                                        macro function
;///    LOG2()
;///
;///        returns the lowest bit position of a bit
;///        useful for btr instructions
;///        exits at lowest bit
;///
;///    ex:     btr ecx, LOG2(MY_BIT_FLAG)
;///            jnc nope_its_not
;///
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////


    LOG2 MACRO exp:req

        LOCAL log

        log = 0

        IF exp AND 00000001h
        log = 0
        ELSEIF exp AND 00000002h
        log = 1
        ELSEIF exp AND 00000004h
        log = 2
        ELSEIF exp AND 00000008h
        log = 3
        ELSEIF exp AND 00000010h
        log = 4
        ELSEIF exp AND 00000020h
        log = 5
        ELSEIF exp AND 00000040h
        log = 6
        ELSEIF exp AND 00000080h
        log = 7
        ELSEIF exp AND 00000100h
        log = 8
        ELSEIF exp AND 00000200h
        log = 9
        ELSEIF exp AND 00000400h
        log = 10
        ELSEIF exp AND 00000800h
        log = 11
        ELSEIF exp AND 00001000h
        log = 12
        ELSEIF exp AND 00002000h
        log = 13
        ELSEIF exp AND 00004000h
        log = 14
        ELSEIF exp AND 00008000h
        log = 15
        ELSEIF exp AND 00010000h
        log = 16
        ELSEIF exp AND 00020000h
        log = 17
        ELSEIF exp AND 00040000h
        log = 18
        ELSEIF exp AND 00080000h
        log = 19
        ELSEIF exp AND 00100000h
        log = 20
        ELSEIF exp AND 00200000h
        log = 21
        ELSEIF exp AND 00400000h
        log = 22
        ELSEIF exp AND 00800000h
        log = 23
        ELSEIF exp AND 01000000h
        log = 24
        ELSEIF exp AND 02000000h
        log = 25
        ELSEIF exp AND 04000000h
        log = 26
        ELSEIF exp AND 08000000h
        log = 27
        ELSEIF exp AND 10000000h
        log = 28
        ELSEIF exp AND 20000000h
        log = 29
        ELSEIF exp AND 40000000h
        log = 30
        ELSEIF exp AND 80000000h
        log = 31
        ENDIF

        EXITM %log

        ENDM


comment ~ /*
        LOCAL log, cnt
        PUSHCONTEXT LISTING
        .NOLIST
        .NOLISTMACRO

        IF exp EQ 0
        .ERR <LOG2 got a zero value>
        ENDIF

        log = 0
        cnt = exp

        REPEAT 32

            IF cnt NE 1         ;;// found the bit
                cnt = cnt SHR 1 ;;// shift right
                log = log + 1   ;;// increase the log
            ENDIF

        ENDM

        IF cnt NE 1
        ;// should never hit this
            .ERR <LOG2: multiple bits were set !!>
        ENDIF
        POPCONTEXT LISTING
*/ comment ~

;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;///
;///                                                        macro
;///    BITT, BITC, BITS, BITR
;///
;///        performs bt operations using an EQU
;///        these are substitutes for bt, btr, btc and bts followed by LOG2()
;///
;///    ex:     BITR ecx, MY_BIT_FLAG
;///            jnc nope_it_was_not
;///
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////


    BITT MACRO val, bit_mask

        bt val, LOG2(bit_mask)

        ENDM

    BITC MACRO val, bit_mask

        btc val, LOG2(bit_mask)

        ENDM

    BITR MACRO val, bit_mask

        btr val, LOG2(bit_mask)

        ENDM

    BITS MACRO val, bit_mask

        bts val, LOG2(bit_mask)

        ENDM



;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;///
;///                                                        macro
;///    BITSHIFT
;///
;///        shifts one set of bits to another set of bits
;///
;///    ex:     BITSHIFT eax, FROM_BIT, TO_BIT
;///
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////

    BITSHIFT MACRO reg:req, from_bit:req, to_bit:req, nolog

        LOCAL b1,b2

        IFNB <nolog>
            IFDIF <NOLOG>,<nolog>
                .ERRDIFI <use NOLOG or leave blank>
            ELSE
                b1 = from_bit
                b2 = to_bit
            ENDIF
        ELSE    ;// use log
            b1 = LOG2(from_bit)
            b2 = LOG2(to_bit)
        ENDIF

        IF b1 LT b2

            shl reg, b2-b1

        ELSEIF b1 GT b2

            shr reg, b1-b2

        ELSE

            ;// do nothing

        ENDIF

        ENDM

;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;///
;///                                                        macro
;///    CARRYSHIFT
;///
;///        shifts the carry flag to the desired location
;//         !!!!!! reg MUST BE ZERO !!!!!!!!
;///
;///    ex:     CARRYSHIFT eax, TO_BIT
;///
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////

    CARRYSHIFT MACRO reg:req, to_bit:req

        rcl reg, LOG2(to_bit) + 1

        ENDM

;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;///
;///                                                        macro function
;///    CSTR()
;///
;///        returns an array of values
;///        uses the C style escape sequences
;///        should work with words as well
;///        always null terminates
;///
;///    ex:     CSTR('Hi\nThere')
;///    returns 'H','i',0Ah,'T','h','e','r','e',0
;///
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////

    CSTR MACRO str:req

        LOCAL bGotEsc   ;;// flag for got escape
        LOCAL d         ;;// character for excape sequence
        LOCAL bGotQuote ;;// toggle flag for quote
        LOCAL bFirstChar;;// set to prevent leading comma
        LOCAL string

        PUSHCONTEXT LISTING
        .NOLIST

        bGotEsc = 0     ;;// set to zero
        bGotQuote = 0   ;;// set to zero
        bFirstChar = 1  ;;// set for first character

        ;// string CATSTR < >   ;;// set first brace
        string CATSTR <>    ;;// set first char


        FORC c, <str>           ;;// iterate c through the string

            IF bGotEsc          ;;// process the escape

                bGotEsc = 0     ;;// turn off now

                ;;// deterimne which escape

                IFIDN       <c>,<n> ;;// new line (line feed)
                    d CATSTR <0Ah>
                ELSEIFIDN   <c>,<r> ;;// carriage return
                    d CATSTR <0Dh>
                ELSEIFIDN   <c>,<t> ;;// tab
                    d CATSTR <09h>
                ELSEIFIDN   <c>,<0> ;;// nul
                    d CATSTR <00h>
                ELSEIFIDN   <c>,<\> ;;// back slash
                    d CATSTR <'\'>
                ELSE
                %   .ERR <unknown escape: c>
                ENDIF

                ;;// add it to the string

                IF bFirstChar NE 1
                    string CATSTR string, <,> , <d>
                ELSE
                    bFirstChar = 0
                    string CATSTR string, <d>
                ENDIF

            ELSEIFIDN <c>,<\>   ;// escape now ??

                bGotEsc = 1

            ELSEIFIDN <c>,<'>

                IF bGotQuote EQ 1
                    bGotQuote = 0
                ELSE
                    bGotQuote = 1
                ENDIF

            ELSE

                IF bFirstChar NE 1
                    string CATSTR string, <,'> , <c> , <'>
                ELSE
                    bFirstChar = 0
                    string CATSTR string, <'> , <c> , <'>
                ENDIF

            ENDIF

        ENDM

        ;;// terminate

        IF bFirstChar NE 1
        ;// string CATSTR string, <,0}>
            string CATSTR string, <,0>
        ELSE
        ;// string CATSTR string, <0}>
            string CATSTR string, <0>
        ENDIF

        POPCONTEXT LISTING

        EXITM string


    ENDM


;//////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////
;///                                        macro
;///    ASSUME AND ALIGN
;///
;// this asumes all registers to nothing
;// and aligns to 16 bytes (should be 32, but MASM doen't provide for that)
;//
;// use this macro before starting a proc
;//
;// purpose is to prevent assumptions from other functions
;//
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////


    ASSUME_AND_ALIGN MACRO

        ASSUME eax:NOTHING
        ASSUME ebx:NOTHING
        ASSUME ecx:NOTHING
        ASSUME edx:NOTHING
        ASSUME edi:NOTHING
        ASSUME esi:NOTHING
        ASSUME ebp:NOTHING
        ALIGN 16

        ENDM


;//////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////
;///                                            macro
;///    PROLOGUE_OFF
;///    PROLOGUE_ON
;///
;//     turns off/on automatic prologue generation
;//     save a little typing
;//
;//     use this when doing implementations by hand
;//
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////

        PROLOGUE_OFF_COUNT = 0      ;// assign this so we can be smart about it

    PROLOGUE_OFF MACRO

        OPTION PROLOGUE:NONE
        OPTION EPILOGUE:NONE

        PROLOGUE_OFF_COUNT = PROLOGUE_OFF_COUNT + 1

        ENDM

    PROLOGUE_ON MACRO

        PROLOGUE_OFF_COUNT = PROLOGUE_OFF_COUNT - 1
        IF PROLOGUE_OFF_COUNT LE 0
            OPTION PROLOGUE:PrologueDef
            OPTION EPILOGUE:EpilogueDef
            PROLOGUE_OFF_COUNT = 0
        ENDIF

        ENDM





;//////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////
;///                                            macro function
;///    WIDECHAR()
;///
;//     generates a wide character string
;//     example:    WIDECHAR("List")
;//     generates:  dw 'L','i','s','t',0
;//
;//
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////

    WIDECHAR    MACRO   string:req

        LOCAL s, first_char

        PUSHCONTEXT LISTING
        .NOLIST

        first_char = 1
        s TEXTEQU <dw>

        FORC c,<string>
            IFDIF <c>,<">
            IFDIF <c>,<'>
            IF first_char EQ 1
                s CATSTR s, < '> , <c> , <'>
                first_char = 0
            ELSE
                s CATSTR s, <,'> , <c> , <'>
            ENDIF
            ENDIF
            ENDIF
        ENDM

        IF first_char EQ 1
            s CATSTR s,< 0>
        ELSE
            s CATSTR s,<,0>
        ENDIF

        POPCONTEXT LISTING

        EXITM s

        ENDM


;//////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////
;///                                            macro function
;///    BRACKET()
;///
;//     looks at the operand and surronds it with brackets if it is a register
;//     purpose is to convert an argument to a dot addressable symbol
;//
;//     example:    BRACKET(esi)
;//     generates:  [esi]
;//
;//     example:    BRACKET(myStruct)
;//     generates:  myStruct
;//
;//     use:    fld BRACKET(operand).member ; where operand may be a register or label
;//
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////



    BRACKET MACRO   op:req

        ;// BRACKET () enter
        LOCAL t, u
        u = OPATTR(op)
        IF (u AND 10000y)       ;// register
%           t CATSTR <[>,<op>,<]>
        ELSEIF (u AND 1010y)    ;// memory address or memory variable
%           t TEXTEQU <op>
        ELSE
            .ERR <op is an invalid operand type>
        ENDIF
        ;// BRACKET () exit
        EXITM t
        ENDM




;//////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////
;///
;///    DATA_STRING
;///
;//     given a name and string
;//     builds a data declartion
;//
;//     example:    DATA_STRING sz_test,"test"
;//                 mov eax, OFFSET sz_test, etc
;//
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////



        ;// data string helper for inline declartions
        DATA_STRING MACRO nam:REQ,val:REQ
            .DATA
            ALIGN 4
            nam db val , 0
            ALIGN 4
            .CODE
            ENDM





;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;///
;///                                                            debug MACRO
;///    DEBUG_IF
;///
;///        use this for quick and dirty assert style tests
;///        be sure to use the ! operator on the > and < and ! operators (confusing)
;///
;///    Will shut itself off if DEBUGBUILD is not defined
;///
;///    ex:     DEBUG_IF <eax || !!([ebx].yadayadayada & FOO_BAZ_CRUFT)>
;///
;///
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////

    DEBUG_IF MACRO criteria:req, bError
        IFDEF DEBUGBUILD
        .IF criteria
            IFNB <bError>
            IFIDN <bError>,<GET_ERROR>
                invoke GetLastError
            ELSE
                .ERR <bError is supposed to be blank, or GET_ERROR>
            ENDIF
            ENDIF
            int 3
        .ENDIF
        ENDIF
        ENDM



;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;///
;///                                                        debug MACRO
;///    DIRECTION_FLAG_TEST
;///
;///        this is a sanity check to verify that the direction flag is set properly
;///        use anywhere, destroys eax
;///
;///
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////

DIRECTION_FLAG_TEST MACRO

    IFDEF DEBUGBUILD

        pushfd
        pop eax
        .IF eax & 10000000000y
            int 3   ;// direction flag was set
        .ENDIF

    ENDIF

    ENDM


;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;///
;///                                                            debug MACRO
;///    DEBUG_MESSAGE   <msg>       output simple message to debugger
;///    DEBUG_MESSAGE_ON [STAMP turn on tracing and optionall time stamp every message
;///    DEBUG_MESSAGE_OFF           turn off tracing
;///    DEBUG_MESSAGE_LINEFEED  emit a line feed
;///    DEBUG_MESSAGE_CODE   one line of optional code if message status is on
;///
;///
;///    must use DEBUG_MESSAGE_ON or DEBUG_MESSAGE_OFF
;///
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////

DEBUG_TRACE_ON MACRO

    .ERR <this was changed to DEBUG_MESSAGE_ON>

    ENDM


DEBUG_TRACE_OFF MACRO

    .ERR <this was changed to DEBUG_MESSAGE_OFF>

    ENDM

DEBUG_TRACE MACRO

    .ERR <this was changed to DEBUG_MESSAGE>

    ENDM






    DEBUG_MESSAGE_ON MACRO arg
        IFDEF DEBUGBUILD
            @MESSAGE <debug messaging is ON>
            DEBUG_MESSAGE_STATUS = 2
            IFIDN <arg>,<STAMP>
            DEBUG_MESSAGE_USE_STAMP = 1
            ELSEIFB <arg>
            DEBUG_MESSAGE_USE_STAMP = 0
            ELSE
            .ERR <use STAMP or leave blank>
            ENDIF
        ENDIF
        ENDM

    DEBUG_MESSAGE_OFF MACRO
        DEBUG_MESSAGE_STATUS = 1
        ENDM

    DEBUG_MESSAGE MACRO msg:req, lf1, lf2

        LOCAL debug_message_msg_name
        LOCAL debug_message_msg

        IFDEF DEBUGBUILD

            IFNDEF DEBUG_MESSAGE_STATUS
            .ERR <use DEBUG_MESSAGE_ON or DEBUG_MESSAGE_OFF>
            ENDIF

            IF DEBUG_MESSAGE_STATUS EQ 2

                ;// build the msg name and text
                debug_message_msg_name CATSTR <_>, <msg>

                IFNB <lf1>
                    .ERRDIF <lf1>,<LINEFEED>,<use LINEFEED or leave blank.>
                    debug_message_msg CATSTR <0ah,0dh,'>, <msg>, <'>
                ELSE
                    debug_message_msg CATSTR <'>, <msg>, <'>
                ENDIF

                ;// declare it as data

                .DATA

                debug_message_msg_name db   debug_message_msg,0dh,0ah
                IFNB <lf2>
                    .ERRDIF <lf2>,<LINEFEED>,<use LINEFEED or leave blank.>
                    db 0ah,0dh,0
                ELSE
                    db 0
                ENDIF

                ALIGN 4

                ;// display a message

                .CODE

                pushad
                pushfd

                IF DEBUG_MESSAGE_USE_STAMP EQ 0

                    invoke OutputDebugStringA, OFFSET debug_message_msg_name

                ELSE

                    mov ebp, esp
                    sub esp, 128
                    mov esi, esp

                    ;// format string
                    ;// 't=%8.8X%8.8X %s'
                    pushd 's% '
                    pushd 'X8.8'
                    pushd '%X8.'
                    pushd '8%=t'
                    mov edi, esp

                    rdtsc
                    push OFFSET debug_message_msg_name
                    push eax
                    push edx

                    push edi
                    push esi
                    call wsprintfA
                    invoke OutputDebugStringA, esi
                    mov esp, ebp

                ENDIF

                popfd
                popad

            ENDIF

        ENDIF

    ENDM


    DEBUG_MESSAGE_REG MACRO reg:req

    ;// displays a register

        LOCAL debug_message_msg_name
        LOCAL debug_message_msg

        IFDEF DEBUGBUILD

            IFNDEF DEBUG_MESSAGE_STATUS
            .ERR <use DEBUG_MESSAGE_ON or DEBUG_MESSAGE_OFF>
            ENDIF

            IF DEBUG_MESSAGE_STATUS EQ 2

                pushad
                pushfd

                ;// format string  '  %8.8X',0dh,0ah,0     stack

                pushd 0ah               ;// ,0ah,0          04
                pushd 'X8.' + 0d000000h ;// '.8X',0dh       08
                pushd '8%  '            ;// '  %8'          0C

                sub  esp, 16            ;//                 1C  <- out buffer

                push reg                ;//                 20
                lea  reg, [esp+4+16]    ;//
                push reg                ;//                 24
                sub  reg, 16            ;//
                push reg                ;//                 28
                call wsprintfA          ;//                 28
                add esp, 0Ch            ;//                 1C

                invoke OutputDebugStringA, esp

                add esp, 16 + 3*4       ;//                 0

                popfd
                popad

            ENDIF

        ENDIF

    ENDM





    DEBUG_DUMP_THREAD MACRO

        IFDEF DEBUGBUILD

            IFNDEF DEBUG_MESSAGE_STATUS
            .ERR <use DEBUG_MESSAGE_ON or DEBUG_MESSAGE_OFF>
            ENDIF

            IF DEBUG_MESSAGE_STATUS EQ 2

                pushad
                pushfd

                invoke GetCurrentThreadId

                sub esp, 32     ;// output buffer
                mov ecx, esp

                pushd 0d0ah     ;// format string
                pushd 'X8.8'
                pushd '%=da'
                pushd 'erhT'
                mov edx, esp

                invoke wsprintfA, ecx, edx, eax
                add esp, 4*4

                invoke OutputDebugStringA, esp

                add esp, 32

                popfd
                popad


            ENDIF

        ENDIF

    ENDM


    DEBUG_MESSAGE_1Q    MACRO reg:req

        ;// reg must point at a qword to dump
        IFDEF DEBUGBUILD

            IFNDEF DEBUG_MESSAGE_STATUS
            .ERR <use DEBUG_MESSAGE_ON or DEBUG_MESSAGE_OFF>
            ENDIF

            IF DEBUG_MESSAGE_STATUS EQ 2

                .ERRIDNI <reg>,<esi>,<cant use reg as parameter>
                .ERRIDNI <reg>,<edi>,<cant use reg as parameter>
                .ERRIDNI <reg>,<ebp>,<cant use reg as parameter>

                pushad
                pushfd

                mov ebp, esp    ;// stack pointer

                ;// output buffer
                sub esp, 32
                mov esi, esp

                ;// format string
                ;// ' %8.8X:%8.8X',0000a0dh
                pushd 0000a0dh
                pushd 'X8.8'
                pushd '%:X8'
                pushd '.8% '
                mov edi, esp

                ;// parameters
                push DWORD PTR [reg+00] ;// q1 lo
                push DWORD PTR [reg+04] ;// q1 hi
                push edi
                push esi
                call wsprintfA
                invoke OutputDebugStringA, esi

                ;// clean up
                mov esp, ebp
                popfd
                popad

            ENDIF

        ENDIF

        ENDM

    DEBUG_MESSAGE_2Q    MACRO reg:req

        ;// reg must point at 2 qwords to dump
        IFDEF DEBUGBUILD

            IFNDEF DEBUG_MESSAGE_STATUS
            .ERR <use DEBUG_MESSAGE_ON or DEBUG_MESSAGE_OFF>
            ENDIF

            IF DEBUG_MESSAGE_STATUS EQ 2

                .ERRIDNI <reg>,<esi>,<cant use reg as parameter>
                .ERRIDNI <reg>,<edi>,<cant use reg as parameter>
                .ERRIDNI <reg>,<ebp>,<cant use reg as parameter>

                pushad
                pushfd

                mov ebp, esp    ;// stack pointer

                ;// output buffer
                sub esp, 64
                mov esi, esp

                ;// format string
                ;// %8.8X:%8.8X  %8.8:X%8.8X,0000a0dh
                pushd 0000a0dh
                pushd 'X8.8'
                pushd '%:X8'
                pushd '.8% '
                pushd ' X8.'
                pushd '8%:X'
                pushd '8.8%'
                mov edi, esp

                ;// parameters
                push DWORD PTR [reg+08] ;// q2 lo
                push DWORD PTR [reg+12] ;// q2 hi
                push DWORD PTR [reg+00] ;// q1 lo
                push DWORD PTR [reg+04] ;// q1 hi
                push edi
                push esi
                call wsprintfA
                invoke OutputDebugStringA, esi

                ;// clean up
                mov esp, ebp
                popfd
                popad

            ENDIF

        ENDIF

        ENDM


DEBUG_MESSAGE_CODE MACRO arg:req

        IFDEF DEBUGBUILD

            IFNDEF DEBUG_MESSAGE_STATUS
            .ERR <use DEBUG_MESSAGE_ON or DEBUG_MESSAGE_OFF>
            ENDIF

            IF DEBUG_MESSAGE_STATUS EQ 2

                arg

            ENDIF
        ENDIF

        ENDM




;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;///
;///                                                        debug MACRO
;///    FPU_INIT_REAL4
;///
;///        use this to set the FPU to real4 round closest
;///        optionally, pass one of the flags to unmask exceptions
;///
;///
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////

    ;// these define the values we want to execption test in the next macro

    FPU_EXCEPTION_STACK         equ 40h
    FPU_EXCEPTION_PRECISION     equ 20h
    FPU_EXCEPTION_UNDERFLOW     equ 10h
    FPU_EXCEPTION_OVERFLOW      equ 08h
    FPU_EXCEPTION_ZERO_DIVIDE   equ 04h
    FPU_EXCEPTION_DENORMAL      equ 02h
    FPU_EXCEPTION_INVALID       equ 01h

    ;// this itializes the fpu to real4 mode
    ;// and unmasks exception set by mask


    FPU_INIT_REAL4 MACRO mask:=<0>

        fninit
        fwait
        push edx
        fstcw WORD PTR [esp]
        fwait
        and WORD PTR [esp], ( (NOT (mask)) AND 1111000011111111y)
        fldcw WORD PTR [esp]
        add esp, 4

        ENDM


;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;//
;//                             constants
;//     FPU_SW
;//



    ;// equates for the 16 bit Status Word bits


    FPU_SW_C0   EQU  100h   ;// CARRY flag
    FPU_SW_C1   EQU  200h   ;//
    FPU_SW_C2   EQU  400h   ;// PARITY flag
    FPU_SW_C3   EQU 4000h   ;// ZERO flag







;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;//
;//                             macro
;//     fpu_SetRoundMode
;//
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////


    fpu_ROUND_NEAREST   EQU 0000000000000000y
    fpu_ROUND_DOWN      EQU 0000010000000000y
    fpu_ROUND_UP        EQU 0000100000000000y
    fpu_ROUND_ZERO      EQU 0000110000000000y

    fpu_SetRoundMode MACRO mode:req, frame

        IFIDN <frame>,<HAVESTACK>
            fnstcw WORD PTR [esp]
        ELSEIFB <frame>
            sub esp, 4
            fnstcw WORD PTR [esp]
        ELSE
            .ERR <use HAVESTACK or leave blank>
        ENDIF


        IFIDN <mode>,<ZERO>

            or WORD PTR [esp], fpu_ROUND_ZERO

        ELSE

            and WORD PTR [esp], NOT fpu_ROUND_ZERO

            IFIDN   <mode>,<UP>

                or WORD PTR [esp], fpu_ROUND_UP

            ELSEIFIDN   <mode>,<DOWN>

                or WORD PTR [esp], fpu_ROUND_DOWN

            ELSEIFIDN   <mode>,<NEAREST>

            ELSE
                .ERR <unknown rounding mode
            ENDIF

        ENDIF

        fldcw WORD PTR [esp]

        IFB <frame>
            add esp, 4
        ENDIF

        ENDM





;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;///
;///                                                        win32 MACRO
;///    HANDLE_WM
;///
;///        this saves many many clock cycles
;///        specify the windows proc as a label,
;///        then load eax with [esp+8]
;///        each handler then gets a message and a lower case handler jump
;///
;///        example:    HANDLE_WM  WM_PAINT, wm_paint_proc
;///
;///        generates:  cmp eax, WM_PAINT
;///                    jz wm_paint_proc
;//
;// this macro is particulary suited for the pentium 2 BTB
;// as long as the jump points are AFTER the handler
;// since the BTB is predicted to fall through, un handled messages
;// will be quickly ignored via speculative exectution
;//
;// the main reason for using this macro is to allow programmer
;// to quickly comment out a message handler
;//
;///
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////


    HANDLE_WM MACRO msg1:req, msg2:req

        cmp eax, msg1
        jz msg2

        ENDM

    ;// use these to get parameters off the stack
    ;// be careful about using invoke with these macros,
    ;// since pushing parameters invalidates these offsets

    WP_HWND         TEXTEQU <(DWORD PTR [esp+4])>
    WP_MSG          TEXTEQU <(DWORD PTR [esp+8])>

    WP_WPARAM       TEXTEQU <(DWORD PTR [esp+12])>
    WP_WPARAM_LO    TEXTEQU <( WORD PTR [esp+12])>
    WP_WPARAM_HI    TEXTEQU <( WORD PTR [esp+14])>

    WP_LPARAM       TEXTEQU <(DWORD PTR [esp+16])>
    WP_LPARAM_LO    TEXTEQU <( WORD PTR [esp+16])>
    WP_LPARAM_HI    TEXTEQU <( WORD PTR [esp+18])>





;//////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////
;///
;///                            saves some typing
;///    ENABLE CONTROL          make sure to include Win32A
;///
;///
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////

ENABLE_CONTROL MACRO hWnd:req, ID:req, onoff:REQ, reg

    ;// can optionaly return reg=hWnd of control

    IFNB <reg>
        push reg            ;// return value
        pushd onoff         ;// on off for enable window
        invoke GetDlgItem, hWnd, ID
        mov [esp+4], eax    ;// return value
        push eax
        call EnableWindow
        pop reg             ;// get return value
    ELSE
        pushd onoff
        invoke GetDlgItem, hWnd, ID
        push eax
        call EnableWindow
    ENDIF

    ENDM

SHOW_CONTROL MACRO hWnd:req, ID:req, onoff:REQ, reg

    ;// can return control hWnd in reg

    IFNB <reg>
        push reg            ;// return value
        pushd onoff         ;// on off for show window
        invoke GetDlgItem, hWnd, ID
        mov [esp+4], eax    ;// store return value
        push eax            ;// store hWnd
        call ShowWindow
        pop reg             ;// get return value
    ELSE
        pushd onoff
        invoke GetDlgItem, hWnd, ID
        push eax
        call ShowWindow
    ENDIF

    ENDM

CHECK_BUTTON MACRO hWnd:req, ID:req, onoff:REQ

    invoke CheckDlgButton, hWnd, ID, onoff

    ENDM

READONLY_CONTROL MACRO hWnd:req, ID:req, onoff:REQ, reg

    ;// can return control hWnd in reg

    IFNB <reg>
        push reg            ;// return value
        pushd 0         ;// lParam
        pushd onoff     ;// wParam on off for show window
        invoke GetDlgItem, hWnd, ID
        mov [esp+8], eax    ;// store return value
        push EM_SETREADONLY
        push eax        ;// hWnd
        call SendMessageA
        pop reg             ;// get return value
    ELSE
        pushd 0
        pushd onoff
        invoke GetDlgItem, hWnd, ID
        pushd EM_SETREADONLY
        push eax
        call SendMessageA
    ENDIF

    ENDM


;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;//                                                     macro
;//     SUBCLASS_DEFPROC
;//
;//     for a subclassed window,
;//         this will call the default window proc
;//     it's design to use ONLY when stack frame has NOT been set
;//
;//     pP is where to get the def proc
;//
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////

SUBCLASS_DEFPROC MACRO pP:req

    push DWORD PTR [esp+10h]
    push DWORD PTR [esp+10h]
    mov eax, pP
    push DWORD PTR [esp+10h]
    push DWORD PTR [esp+10h]
    push eax
    call CallWindowProcA

    ENDM


;////////////////////////////////////////////////////////////////



    ;//                 these are just synonyms for SendMessageA
    ;// message_macros  They do, however, make the code easier to read
    ;//

        LISTBOX MACRO hWnd:req, action:req, opt1:=<0>, opt2:=<0>
            invoke SendMessageA , hWnd , action , opt1 , opt2
            ENDM

        EDITBOX MACRO hWnd:req, action:req, opt1:=<0>, opt2:=<0>
            invoke SendMessageA , hWnd , action , opt1 , opt2
            ENDM

        WINDOW MACRO hWnd:req, action:req, opt1:=<0>, opt2:=<0>
            invoke SendMessageA , hWnd , action , opt1 , opt2
            ENDM

        WINDOW_P MACRO hWnd:req, action:req, opt1:=<0>, opt2:=<0>
            invoke PostMessageA , hWnd , action , opt1 , opt2
            ENDM





;////////////////////////////////////////////////////////////////////
;//
;//
;//     arg macros
;//


    @ArgCount MACRO parmlist:VARARG
        LOCAL count
        count = 0
        FOR parm, <parmlist>
            count = count + 1
        ENDM
        EXITM count
    ENDM


    @ArgI MACRO index:REQ, arglist:VARARG
        LOCAL count, retstr
        count = 0
        FOR arg, <arglist>
            count = count + 1
            IF count EQ index
                retstr TEXTEQU <arg>
            ENDIF
        ENDM
        EXITM retstr
    ENDM


;//
;//
;//     arg macros
;//
;////////////////////////////////////////////////////////////////////





;/////////////////////////////////////////////////////////////////////
;//
;//
;//     @MESSAGE        use inplace of ECHO @Line msg
;//
@MESSAGE MACRO msg

    LOCAL T
%   T TEXTEQU %@Line
%   ECHO line T: msg

    ENDM

;//
;//     @MESSAGE        use inplace of ECHO @Line msg
;//
;//
;/////////////////////////////////////////////////////////////////////





















ENDIF   ;// _UTILITY_INCLUDED_