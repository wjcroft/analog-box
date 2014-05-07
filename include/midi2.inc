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
;// midi2.inc
;//

;//////////////////////////////////////////////////////////////////////////////////////////////
comment ~ /*

OVERVIEW

    the new midiin objects have the following pins

                      /----\--> so filtered stream out
    stream input si-->|    |--> N number or s1 filter stream out
                      |    |--> V value
                      \----/--> e got event (edge)

    the system implements MIDI_STREAM to transport data
    >>> this is NOT the same as the Windows midi streams <<<
    MIDI_STREAMS allows quick manipulation of midi events
    without haveing to fill samples with redundant data
    only when data is exported as N V e values does it need to be filled
    in general, we can assume that MIDI_STREAM will be empty

    midi streams can be filtered with a MIDI_FILTER
    filters ALWAYS output two new streams
    1) o_stream, new stream with filtered elements reomoved
    2) f_stream, new stream with ONLY filtered elements

    midi streams can be merged

    midi streams can source a TRACKER_TABLE
    a tracker table is a midi note filter with an slist of destination objects
    objects attach to the tracker table and export N V e events

*/ comment ~
;//////////////////////////////////////////////////////////////////////////////////////////////



;//////////////////////////////////////////////////////////////////////////////////////////////
comment ~ /*

MIDI_FLOAT
STORING MIDI DATA AS FLOATS

    all MIDI_STREAM data is stored as MIDI_FLOAT

    benefits:

        compact format, 4 bytes per command message, 1 command per sample
        audio safe, values may be conditioned so they aren't too loud

    drawback:

        decoding requires at little work
        possible bytes acesess and some shift and add


details:
            |---------------|---------------|---------------|---------------|
    DWORD   |3 3 2 2 2 2 2 2|2 2 2 2 1 1 1 1|1 1 1 1 1 1 0 0|0 0 0 0 0 0 0 0|
    BITS    |1 0 9 8 7 6 5 4|3 2 1 0 9 8 7 6|5 4 3 2 1 0 9 8|7 6 5 4 3 2 1 0|
            |---------------|---------------|---------------|---------------|

            |s /   biased    \ /                                           \
    REAL4   |g|   exponent    |       significand      1 assumed MSB        |
            |n \   8 bits    / \       23 bits                             /

    INPUT   |                                                               |
    MIDI    |0 0 0 0 0 0 0 0|0 v v v v v v v|0 n n n n n n n|1 m m m c c c c|
            |    not used   |  value        |  number       |command channel|

    .CODE   mov eax, INPUT_MIDI
            bswap eax
            shr eax, 8
            or eax, MIDI_FLOAT_BIAS
            mov MIDI_FLOAT, eax

    FLOAT   |                                                               |
    MIDI    |0 0 1 1 1 1 1 0|1 m m m c c c c|0 n n n n n n n|0 v v v v v v v|
            |  fixed bias   |command channel|  number       |  value        |

    notes:

        the top bit of command is alway 1 (see MIDI_S_NOTEOFF)
        this effects the resultant fraction
        MIDI_BIAS = 3E000000h ==> 3E800000h = 1/4

             !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        NOTE !! --> BIAS is changed to 38
             !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

    */ comment ~

;// tables:

        MIDI_FLOAT_BIAS EQU 38000000h   ;// apply to floats
        MIDI_BIAS       EQU 38h         ;// apply to bytes

    ;// event                   midifloat         val f r a c t i o n a l   e q u i v
    ;// ----------              ---------         --- -------------------------------
        MIDI_FLOAT_NOTEOFF      EQU 00800000h + MIDI_FLOAT_BIAS ;// 80h 1/4                     =  8/32
        MIDI_FLOAT_NOTEON       EQU 00900000h + MIDI_FLOAT_BIAS ;// 90h 1/4              + 1/32 =  9/32
        MIDI_FLOAT_PRESSURE     EQU 00A00000h + MIDI_FLOAT_BIAS ;// A0h 1/4       + 1/16        = 10/32
        MIDI_FLOAT_CONTROLLER   EQU 00B00000h + MIDI_FLOAT_BIAS ;// B0h 1/4       + 1/16 + 1/32 = 11/32
        MIDI_FLOAT_PROGRAM      EQU 00C00000h + MIDI_FLOAT_BIAS ;// C0h 1/4 + 1/8               = 12/32
        MIDI_FLOAT_AFTERTOUCH   EQU 00D00000h + MIDI_FLOAT_BIAS ;// D0h 1/4 + 1/8        + 1/32 = 13/32
        MIDI_FLOAT_PITCHWHEEL   EQU 00E00000h + MIDI_FLOAT_BIAS ;// E0h 1/4 + 1/8 + 1/16        = 14/32
        MIDI_FLOAT_PORT         EQU 00F00000h + MIDI_FLOAT_BIAS ;// FXh 1/4 + 1/8 + 1/16 + 1/32 = 15/32

        MIDI_FLOAT_PORT_SYSX        equ 00F00000h + MIDI_FLOAT_BIAS ;// no params
        MIDI_FLOAT_PORT_SYSX_END    equ 00F70000h + MIDI_FLOAT_BIAS ;// end sysx
        MIDI_FLOAT_PORT_CLOCK       equ 00F80000h + MIDI_FLOAT_BIAS
        MIDI_FLOAT_PORT_START       equ 00FA0000h + MIDI_FLOAT_BIAS
        MIDI_FLOAT_PORT_STOP        equ 00FB0000h + MIDI_FLOAT_BIAS
        MIDI_FLOAT_PORT_CONTINUE    equ 00FC0000h + MIDI_FLOAT_BIAS
        MIDI_FLOAT_PORT_ACTIVE      equ 00FE0000h + MIDI_FLOAT_BIAS ;// keep alive, 1 every 3--ms
        MIDI_FLOAT_PORT_RESET       equ 00FF0000h + MIDI_FLOAT_BIAS ;// FF  reset (aka panic)

        MIDI_FLOAT_STATUS_TEST  EQU 00FF0000h   ;// masks out all but status
        MIDI_FLOAT_COMMAND_TEST EQU 00F00000h   ;// masks out all but command
        MIDI_FLOAT_CHANNEL_TEST EQU 000F0000h
        MIDI_FLOAT_NUMBER_TEST  EQU 00007F00h   ;// masks out all but number
        MIDI_FLOAT_VALUE_TEST   EQU 0000007Fh   ;// masks out all but value

        MIDI_FLOAT_FIRST_CHANNEL EQU 0010000h   ;// so we can use BITSHIFT
        MIDI_FLOAT_FIRST_NUMBER  EQU 0000100h   ;// so we can use BITSHIFT

        MIDI_FLOAT STRUCT   ;// 1 dword

            value   db  0   ;// value byte
            number  db  0   ;// number byte
            status  db  0   ;// command + channel
            bias    db  0   ;// fixed float bias (MIDI_BIAS)

        MIDI_FLOAT ENDS


;//////////////////////////////////////////////////////////////////////////////////////////////



;//////////////////////////////////////////////////////////////////////////////////////////////
comment ~ /*

MIDI_STREAM

        stream data is a loose container for midi events
        it is what is passed between objects in the circuit

        loose means that the full contents of the sample frame are not all used
        instead it is an offset linked list of events

    ORGANIZATION

        a MIDI_STREAM_ARRAY is divided into 512 pairs of dwords
        each pair is called a MIDI_STREAM

        the first dword of each pair represents the INDEX OFFSET to get to the next event

            the offset is ALWAYS stored in MIDI_FLOAT format

                use: sub reg, MIDI_FLOAT_BIAS to get the offset
                if the offset is zero, end of the stream

            the offset always applies to an accumulated index

                using a pointer is deadly
                ex: stream --> delay
                offset must be encoded in a REAL4

            this makes it safe to apply processing to the stream
            processing may very well destroy the stream, but will not crash the program

        the second dword represents the event in standard MIDI_FLOAT format

        position in the sample frame defines its time stamp

        */ comment ~

        MIDI_STREAM STRUCT      ;// 2 dwords

            nxt dd  0           ;// index offset to next event (always a MIDI_FLOAT or zero)
            UNION
                evt     dd  0   ;// dword event for this element
                MIDI_FLOAT  {}  ;// access as bytes
            ENDS

        MIDI_STREAM ENDS


        comment ~ /*

    MIDI_STREAM_ARRAY

        a sample frame is then packed with MIDI_STREAM records
        this is called MIDI_STREAM_ARRAY
        the last MIDI_STREAM in the array is used by Append and Insert
        to help prevent having to walk the stream

        */ comment ~

        MIDI_STREAM_LENGTH EQU SAMARY_LENGTH / 2



        MIDI_STREAM_ARRAY STRUCT

            MIDI_STREAM MIDI_STREAM_LENGTH dup ({})

        MIDI_STREAM_ARRAY ENDS



        LAST_STREAM EQU ((SIZEOF MIDI_STREAM_ARRAY) - (SIZEOF MIDI_STREAM))

        comment ~ /*

    iterating a stream

        MIDI_STREAM_ARRAY uses the first record as a positioning device

            nxt evt
            --- ---
            ==0 ==0 frame is empty                      (assume last_event = 0)
            ==0 !=0 valid command, last command in list (assume last_event = 0)
            !=0 ==0 no command, first event is at nxt
            !=0 !=0 valid command, more commands follow

    behavior of last_event

        last_event is defined as the .nxt field of the last MIDI_STREAM in the array
        last_event always indexes the highest index with a valid event

        that record will have next=0 UNLESS last_event == LAST_STREAM
            in which case last_event.nxt == MIDI_STREAM_LENGTH-1

        this complicates iterators because the last event record points at itself
        iterators must check if iter == last event BEFORE iterating and AFTER DO_WORK

    general rules:

        .nxt is ALWAYS positive, meaning that stream is always iterated forwards
        to enforce this
        , always check the value of .nxt BEFORE adding it to index
        , always use sub .nxt, MIDI_FLOAT_BIAS, then check the results

        if a MIDI_STREAM is hit by a .nxt value, it's event is assumed valid (in use)
        otherwise it's event is undefined (not in use)
        that is to say,
        1) all events IN the chain are valid and must not be changed
        2) all events OUTSIDE the chain are invalid and free for use
        .) spin offs
        , if last_event is invalid, the entire stream is invalid
        , if any .nxt results in invalid index, the rest of the stream is invalid


    checking for empty stream

        this takes two tests

        if last_event == 0
            if [0].event
                            ;// the stream has one record at [0]
            else
                            ;// the stream is empty
            endif
        else                ;// last_event!= 0
                            ;// there is AT LEAST one event in the stream
        endif


    iterating a stream

        midistream_IterBegin to check for empty streams and get to the first event
        DO_WORK
        midistream_IterNext to get to the next record or abort the loop

    Append and Insert

        these are somewhat complicated to do efficiently
        the midistream_Insert and midistream_Append macros will prepare the desired
        MIDI_STREAM record by inserting it into the chain
        the event values must be transered OUTSIDE of the macros

    Insert

        the goal is to ALWAYS succeed UNLESS the stream is full

        the rule is that we insert AT or AFTER index, never before
        this means we'll have to skid passed consecutive records
        in some cases, we'll have to MOVE portions of the stream
        if the stream is completely full, we are forced to drop the event

        insert may require that we adjust index
            this will raise hell for stream to stream transfers
            in that case, use append and iterate the stream in order

        several cases:

        inserting into empty stream
        inserting as the last_event
        inserting into a stream on an empty record
        inserting into a stream on a non empty record


    EXAMPLES    . = empty slot, number = some index, # = end of array

        EX: ..123...#   insert x at 2
            ..123x..#   2 is full, 3 is full, next slot is empty

        EX: .....123#   insert x at 2
            ....123x#   had to slide 123 back one slot


    Append

        the goal is to ALWAYS succeed

        there is the case of stream to stream transfer
        in this case, we must iterate the stream in order
        and use the midistream_Append macro
        this function will fail at the first error

        -->assume that the input stream is valid<--

        to enforce this, use midistream_Reset before the first append operation

    */ comment ~












    ;////////////////////////////////////////////////////////////////////
    ;//
    ;//             midistream_VERIFY       debug macro checks that stream is valid
    ;//             midistream_Reset        resets the stream to be empty
    ;// MACROS      midistream_Append       add an event to the end of the stream
    ;//      function --> midistream_Insert     tries to insert at stated position
    ;//             midistream_IterBegin    start iterating a stream
    ;//             midistream_IterEnd      advance to the next event in the stream

        midistream_VERIFY MACRO stream:req, r1:=<eax>, r2:=<edx>

            LOCAL top_of_loop, check_last_event

            IFDEF DEBUGBUILD

                xor r2, r2          ;// start at the start

            top_of_loop:

                mov r1, stream[r2*8].nxt        ;// get the next
                test r1, r1                     ;// check for zero
                je check_last_event

                cmp r2, MIDI_STREAM_LENGTH - 1  ;// see if r2 is done
                je check_last_event

                sub r1, MIDI_FLOAT_BIAS         ;// mask out the bias
                DEBUG_IF <r1 !>= MIDI_STREAM_LENGTH>
                DEBUG_IF <!!r1>                 ;// not supposed to use float 0, use int 0
                add r2, r1                      ;// advance r2
                jmp top_of_loop                 ;// do again

            check_last_event:

                ;// last_event must equal r2

                mov r1, stream[LAST_STREAM].nxt
                .IF r1
                    sub r1, MIDI_FLOAT_BIAS
                .ENDIF
                DEBUG_IF < r1 !!= r2 >

            ENDIF

            ENDM


        ;// comment this to use the faster reset rouine
        ;// turning it on zeros all values in the stream
        IFDEF DEBUGBUILD
        STREAMERASE_DEBUGBUILD EQU 1
        ENDIF

        midistream_Reset MACRO stream:req, reg:=<eax>

            ;// makes the stream empty
            ;// REG MUST BE ZERO !!
            ;// stream must be dot addressable as MIDI_STREAM

            IFDEF STREAMERASE_DEBUGBUILD
                pushad
                lea edi, stream
                mov ecx, SAMARY_LENGTH
                xor eax, eax
                rep stosd
                popad
            ELSE
                DEBUG_IF <reg>  ;// REG MUST BE ZERO !!
                mov stream.nxt, reg
                mov stream.evt, reg
                mov stream[LAST_STREAM].nxt, reg
            ENDIF


            ENDM



        midistream_Append MACRO stream:req, index:req, r1:=<eax>, r2:=<edx>

            ;// use this macro to append a new event at the end of the stream frame
            ;// THE EVENT IS NOT STORED

            ;// stream must be dot addressable as MIDI_STREAM
            ;// index is index of MIDI_STREAM to insert at (ecx is preffered)
            ;// r1 and r2 are destroyed

            ;// do not use append if there is a risk of overwrites
            ;// use insert instead

            midistream_VERIFY stream, r1, r2    ;// verify at start

            xor r1, r1                          ;// clear for testing
            or r1, stream[LAST_STREAM].nxt      ;// get the last event we stored

            .IF ZERO?   ;// first command in this frame

                .IF index   ;// make sure to append a valid float, NOT float zero
                    lea r1, [index+MIDI_FLOAT_BIAS] ;// prepare r1 as the offset to the next event
                .ENDIF
                mov stream.nxt, r1              ;// store as first event

            .ELSE       ;// not the first command in this frame

                sub r1, MIDI_FLOAT_BIAS         ;// turn into index of last event
                DEBUG_IF <ZERO?>        ;// not supposed to use float zero, use int 0
                mov r2, index                   ;// preserve the index
                sub r2, r1                      ;// offset to next event
                .IF !ZERO?              ;// don't store float zero, store int zero
                    add r2, MIDI_FLOAT_BIAS     ;// turn into float
                .ENDIF
                mov stream[r1*8].nxt, r2        ;// store offset next
                lea r1, [index+MIDI_FLOAT_BIAS] ;// determine this index

            .ENDIF
            mov stream[LAST_STREAM].nxt, r1 ;// set the new last event
            .IF index != MIDI_STREAM_LENGTH-1   ;// make sure we don't zero the last event
                mov stream[index*8].nxt, 0      ;// set THIS as the last event
            .ENDIF

            midistream_VERIFY stream, r1, r2    ;// verify at end

            ENDM


        ;// this is big enough to warrent it's own function
        ;// defined in midistream_Insert.asm
        midistream_Insert PROTO STDCALL strm:DWORD, index:DWORD, event:DWORD



        ;///////////////////////////////////////////////////////////////
        ;//
        ;//     IterBegin
        ;//     IterNext
        ;//
        ;//     these next two macros are used to iterate streams
        ;//     'stream' must be a MIDI_STREAM dot addressable register
        ;//     'index' must be a register (ecx is preffered)

        midistream_IterBegin MACRO stream:req, index:req, abort:req

            ;// place this before the top of the loop
            ;// fall through is the top of the loop
            ;// stream must be dot addressable as MIDI_STREAM

            DEBUG_IF <index>    ;// index is supposed to be zero !!

            cmp index, stream.evt       ;// see if there's an event in the first record
            .IF ZERO?

                or index, stream.nxt    ;// if not (usually the case), load and test the next
                je abort                ;// if zero, empty frame abort the iteration

                sub index, MIDI_FLOAT_BIAS      ;// mask our the float bias
                cmp index, MIDI_STREAM_LENGTH   ;// make sure we're still in the frame
                jae abort                       ;// abort if not

            .ENDIF

            ;// fall through is DO_WORK

            ENDM


        midistream_IterNext MACRO stream:req, index:req, top:req, reg:=<eax>

            ;// place this at the end of the loop
            ;// loop_finished is fall through
            ;// destroys eax

            .IF index != MIDI_STREAM_LENGTH-1   ;// always check for last event

                xor reg, reg
                or reg, stream[index*8].nxt     ;// any more events in this frame ?
                .IF !ZERO?                          ;// exit if not
                    lea index, [index+reg-MIDI_FLOAT_BIAS]  ;// get to the next event
                    cmp index, MIDI_STREAM_LENGTH   ;// make sure we did
                    jb top
                .ENDIF

            .ENDIF

            ;// fall through is LOOP_DONE

            ENDM


    ;//
    ;//             midistream_Reset        resets the stream to be empty
    ;// MACROS      midistream_Append       add an event to the end of the stream
    ;//             midistream_Insert       tries to insert at stated position
    ;//             midistream_IterBegin    start iterating a stream
    ;//             midistream_IterNext     advance to the next event in the stream
    ;//
    ;////////////////////////////////////////////////////////////////////





;//////////////////////////////////////////////////////////////////////////////////////////////




;//////////////////////////////////////////////////////////////////////////////////////////////
comment ~ /*


MIDIIN_QUE MIDIIN_HARDWARE_DEVICEBLOCK portstream

        to get data into the sytem, midiin_Proc first places items in a que
        the que is arranged as a circular array 512 MIDIIN_QUE elemnets
        each new event is placed adjacent to the previous event
        a last_write field is updated each time

            512 events at no less than 1ms per event works out to 1/2 second of data
            usually this is enough

        MIDIIN_QUE elements consist of the time stamp as recieved by windows
        and the event, translated into MIDI_FLOAT format

    ---> there will be a problem:

        if user creates a midiin object, attached it to device, then connects it later
        there will be a delay in the midi stream
        this must be accounted for
        see midiin_que_to_portstream for the solution

    */ comment ~

        MIDIIN_QUE STRUCT

            stamp   dd  0   ;// stamp is stored as absolute MIDI_STREAM index
            event   dd  0   ;// the event for this que item

        MIDIIN_QUE ENDS

        MIDIIN_QUE_LENGTH   EQU SAMARY_LENGTH / 2

        MIDIIN_QUE_ARRAY STRUCT

            MIDIIN_QUE MIDIIN_QUE_LENGTH DUP ({})

        MIDIIN_QUE_ARRAY ENDS


    comment ~ /*

    for objects to access the midi data,
    it must first be translated into MIDI_STREAM format

    a portstream is defined to do this

        many objects may share the same portstream
        midiin_que_to_portstream does the translation
        portstream is identical to MIDI_STREAM_ARRAY
        we call it portstream to indicate that is unique to the device
        as oppossed to a regular input signal


    when an object needs data from the portstream

        it first checks portstream_ready
        if not ready, call midiin_que_to_portstream

        from there, the object can use the stream functions

    MIDIIN_HARDWARE_DEVICEBLOCK

        the midi in device data holds two items

        the que of recieved data
        the portstream to be used by all subsequent operations

        data_flow:

                 midiin_Proc    midiin_que_to_portstream
                      |                  |
            device ------>  q u e  ---------------->   portstream
                    last_write  last_read            portstream_ready

    */ comment ~


    comment ~ /*

        ABOX233 : ADJUSTED

        MIDIIN_HARDWARE_DEVICEBLOCK STRUCT

            HARDWARE_DEVICEBLOCK    {}

            que         MIDIIN_QUE_ARRAY    {}  ;// circular que of events
            portstream  MIDI_STREAM_ARRAY   {}  ;// data ectracted from the que

            last_write      dd  0   ;// last MIDIIN_QUE index we write to
            last_read       dd  0   ;// last MIDIIN_QUE index we looked at
            frame_counter   dd  0   ;// number of times H_calc has been hit
            empty_frame     dd  0   ;// counts the number of cosecutive empty frames
            portstream_ready dd 0   ;// flag tells us that the input que has been xfered to the stream

            midi_flags      dd  0   ;// xferred from osc.dwUser

        MIDIIN_HARDWARE_DEVICEBLOCK ENDS

    */ comment ~


        MIDI_QUE_PORTSTREAM STRUCT

            que         MIDIIN_QUE_ARRAY    {}  ;// circular que of events
            portstream  MIDI_STREAM_ARRAY   {}  ;// data ectracted from the que

            last_write      dd  0   ;// last MIDIIN_QUE index we write to
            last_read       dd  0   ;// last MIDIIN_QUE index we looked at
            frame_counter   dd  0   ;// number of times H_calc has been hit
            empty_frame     dd  0   ;// counts the number of cosecutive empty frames
            portstream_ready dd 0   ;// flag tells us that the input que has been xfered to the stream

            midi_flags      dd  0   ;// xferred from osc.dwUser

        MIDI_QUE_PORTSTREAM ENDS


        MIDIIN_HARDWARE_DEVICEBLOCK STRUCT  ;// new struct is identical !!

            HARDWARE_DEVICEBLOCK    {}

            MIDI_QUE_PORTSTREAM     {}

        MIDIIN_HARDWARE_DEVICEBLOCK ENDS








    comment ~ /*

    midiin_Proc

        inserts new events in the que
        updates last_write, always an index

    midiin_H_Calc

        resets portstream_ready

    midiin_que_to_portstream
    ABOX233: changed to midi_que_to_portstream

        moves appropriate que entries to the portstream
        sets portstream_ready
        updates last_read

        the first osc that needs the portstream can call midi_que_to_portstream
        use portstream_ready to detect


    */ comment ~

    ;// these are defined in midiin_que.asm

        midi_que_to_portstream PROTO    ;// ebx=MIDI_QUE_PORTSTREAM

        midiin_H_Ctor   PROTO
        midiin_H_Dtor   PROTO
        midiin_H_Open   PROTO STDCALL pDevice:PTR HARDWARE_DEVICEBLOCK
        midiin_H_Close  PROTO STDCALL pDevice:PTR HARDWARE_DEVICEBLOCK
        midiin_H_Ready  PROTO
        midiin_H_Calc   PROTO


;//////////////////////////////////////////////////////////////////////////////////



;//////////////////////////////////////////////////////////////////////////////////
comment ~ /*

GENERAL SIGNAL FLOW

        device --> que --> portstream


                          /--> o_stream
        stream --> filter
                          \--> f_stream
                           \--> f_stream --> N V e
                            \--> tracker table


        filters always output two new streams
        neither stream needs to be directly output
        N V e output filling is described below

*/ comment ~
;//////////////////////////////////////////////////////////////////////////////////


;//////////////////////////////////////////////////////////////////////////////////
comment ~ /*

FILTERING

        MIDI_FILTERS are implementd as bit fields
        at most there are two sets of bits in a MIDI_FILTER
        if the all required bits are on, the event is accepted, routed to f_stream
        if the event is rejected, it is routed to o_stream

        use stream_filter() to perform the filtering for a MIDI_STREAM_ARRAY

    1) status bits  1 dword

        24 bits that represent status and channel

        there are 8 status events defined in midi 8-F
        8-E have a channel value encoded
            8-10 assume there is a set of note bits to check as well
            11 assumes there is a set of controller bits
        F has 8 more events which get encoded in the channel field

        there are 16 channels

        DWORD   |---------------|---------------|---------------|---------------|
        BITS    |3 3 2 2 2 2 2 2|2 2 2 2 1 1 1 1|1 1 1 1 1 1 0 0|0 0 0 0 0 0 0 0|
                |1 0 9 8 7 6 5 4|3 2 1 0 9 8 7 6|5 4 3 2 1 0 9 8|7 6 5 4 3 2 1 0|
                |---------------|---------------|---------------|---------------|

        STATUS  | i g n o r e d |  status bits  |    c h a n n e l   b i t s    |
        FILTER  |               |F E D C B A 9 8|F E D C B A 9 8 7 6 5 4 3 2 1 0|

    2) number bits  4 dwords

        128 bits representing note numbers or controller numbers
        the 4 dwords are indexed by bit position
        identical to byte[0-15]:bit[0-7]
        identical to dword[0-3]:bit[0-31]

        user can setup the bits using midi_szrange_to_bits
        and view the bits using midi_bits_to_szrange
        these function are descibed below

    */ comment ~

        MIDI_FILTER STRUCT

            status  dd  0           ;// cmd plus channel
            number  dd  4 DUP (0)   ;// note or ctroller filters

        MIDI_FILTER ENDS

        stream_filter PROTO STDCALL pI_stream:DWORD, pO_stream:DWORD, pF_stream:DWORD, pFilter:DWORD


        ;// useful bit values for status
        ;//                         status  c h a n n e l
        ;//                         FEDCBA98FEDCBA9876543210
        MIDI_FILTER_NOTEOFF     EQU 000000010000000000000000y   ;// 80h
        MIDI_FILTER_NOTEON      EQU 000000100000000000000000y   ;// 90h
        MIDI_FILTER_PRESSURE    EQU 000001000000000000000000y   ;// A0h
        MIDI_FILTER_CONTROLLER  EQU 000010000000000000000000y   ;// B0h
        MIDI_FILTER_PROGRAM     EQU 000100000000000000000000y   ;// C0h
        MIDI_FILTER_AFTERTOUCH  EQU 001000000000000000000000y   ;// D0h
        MIDI_FILTER_PITCHWHEEL  EQU 010000000000000000000000y   ;// E0h
        MIDI_FILTER_SYSX        EQU 100000000000000000000001y   ;// F0h
        ;// F1h QUARTER FRAME, 1 BYTE FOLLOWS (0-127)
        ;// F2h SPP N+V = NUMBER OF 16THS SINCE SONG START (1/16 IS 6 CLOCKS)
        ;// F3h SONG SELECT
        ;// F4h NOT USED
        ;// F5h NOT USED
        ;// F6h TUNING REQUEST
        MIDI_FILTER_SYSX_END    EQU 100000000000000010000000y   ;// F7h ;// END SYSX
        MIDI_FILTER_CLOCK       EQU 100000000000000100000000y   ;// F8h
        ;// F9  MIDI TICK (EVERY 10M DAtA)
        MIDI_FILTER_START       EQU 100000000000010000000000y   ;// FAh
        MIDI_FILTER_CONTINUE    EQU 100000000000100000000000y   ;// FBh
        MIDI_FILTER_STOP        EQU 100000000001000000000000y   ;// FCh
        ;// FD  NOT USED
        MIDI_FILTER_ACTIVE      EQU 100000000100000000000000y   ;// FEh ;// keep alive, 1 every 300ms
        MIDI_FILTER_RESET       EQU 100000001000000000000000y   ;// FF  RESET (AKA PANIC)

    ;// composite commands

        MIDI_FILTER_TIMING      EQU 100000000001110100000000y   ;// clck start stop continue
        MIDI_FILTER_CHANNELS    EQU 011111110000000000000000y   ;// all channel related messages
        MIDI_FILTER_NOTES       EQU 000001110000000000000000y   ;// all note commands


;/////////////////////////////////////////////////////////////////////////////////




;/////////////////////////////////////////////////////////////////////////////////
comment ~ /*


RANGE EDIT BOXES

        simple list formats are parsed by two functions
        see range_parser.asm for implementation

        ex: "3 - 7 9 27 25 26 27 6 2"
        translates to: "3-7 25-27"

    */ comment ~

        midi_szrange_to_bits PROTO STDCALL pStr:DWORD, pBits:DWORD, num_bits:DWORD
        midi_bits_to_szrange PROTO STDCALL pBits:DWORD, num_bits:DWORD, pStr:DWORD

;/////////////////////////////////////////////////////////////////////////////////





;/////////////////////////////////////////////////////////////////////////////////
comment ~ /*


TRACKER TABLES

    the general concept is that midi in objects attach to tracker tables
    the first attached object to use a tracker calls tracker_Calc
    the table keeps track of who gets what note and when they got it

    trackers are appended to the LIST_CONTEXT
    we do this to allow trackers inside of closed groups
    there are nodes called MIDIIN_TRACKER_CONTEXT
    the head of the list is pointed to by LIST_CONTEXT.pTracker

    tracker ID's must be automatically assigned
    ID's above 1000h are reserved for the tracker
    closing a tracker table must remove it from the list

    one midi object is responsible for sourcing the table
    tracker table must know how to get the data
    this is accomplished in play_Trace by forcing the source object
    to be at the first object calculated
    tracker_Calc then does ALL attached objects

    the tracker context owns an slist of attached objects
    each dest object keeps track of it's note and velocity

    */ comment ~

        ;// MIDIIN_TRACKER is declared in ABox.inc
        ;// MIDIIN_TRACKER_CONTEXT is declared in ABox.inc



    ;// MIDIIN_TRACKER_START_BIAS   EQU 1000h

    comment ~ /*

    NOTE vs FREQ output

        makeing sure that the correct pins and units are set works like this

        tracker_AttachDest will do each object individualy
        tracker_AttachSource calls tracker_UpdateDestPins

        so: if dest does not have a source, Attach source will catch it later

    EVENT HANDLING, read from stream

        note_on && vel != 0

            find attached object that is not busy
            if no attached devices are ready
                find the least recently used

                tell it that it got a note_on

        note_on && vel == 0
        note_off

            find object that holds this note
            tell it to shut it off

        note_pressure

            find attached object with this note
            tell it to adjust it's velocity

    */ comment ~

        ;// public functions defined in tracker.asm

        tracker_AttachSource    PROTO
        tracker_DetachSource    PROTO
        tracker_KillSource      PROTO
        tracker_VerifySource    PROTO

        tracker_AttachDest      PROTO
        tracker_DetachDest      PROTO
        tracker_KillDest        PROTO
        tracker_VerifyDest      PROTO

        tracker_UpdateDestPins  PROTO
        tracker_FillInDeviceList PROTO
        tracker_Calc            PROTO

    comment ~ /*

    CONFIGURATIONS

                            dwUser  osc     dwUser  dwUser              tracker
             /--\           .ID     pDevice .input  .output pTracker    .id
    tracker->|  |
             \--/-->filter   T#     tracker DEVICE  n/a     0           0


             /--\-->stream  D#      device  DEVICE  TRACKER tracker     T#
    device-->|  |
             \--/-->tracker


             /--\-->stream  n/a     0       STREAM  TRACKER tracker     T#
    stream-->|  |
             \--/-->tracker


             /--\-->stream  D#      device  DEVICE  !track  0           n/a
    device-->|  |
             \--/-->filter


             /--\-->stream  n/a     0       STREAM  !track  0           n/a
    stream-->|  |
             \--/-->filter


        if output_mode == tracker

            pTracker must be set
            tracker ID must be assigned
            pDevice must NOT point at a tracker

        if input_mode == stream

            pDevice must be 0
            device_id should be reset ??

    */ comment ~


;/////////////////////////////////////////////////////////////////////////////////






;/////////////////////////////////////////////////////////////////////////////////
comment ~ /*

MIDI IN OBJECT

    1) incorporate MIDI_STREAM signal type as stream of MIDI_FLOAT
    2) allow MidiIn objects to accept MIDI_STREAM, MIDI_DEVICE, or NOTE_TRACKER
    3) allow MidiIn output mode to be stream, filter, tracker
    4) filter modes should allow the removing of events from the stream
    5) implement range values for all filters
    6) provide useful input output modes

                      /----\--> SO filtered stream out
    stream input SI-->|    |--> N number    S1 filter stream out
                      |    |--> V value
                      \----/--> e got event (edge)

    INPUT MODES

        midi device     no input pin
        midi stream     yes input pin
        note tracker    no input pin    output forced to N V e


    FILTER MODES, organized by application

    port    stream                          --> so
            clock start stop cont           --> so N V e
            channel [RANGE_EDIT_16]
                    stream                  --> so s1
                    pitchwheel              --> so V e
                    pressure                --> so V e
                    program                 --> so V e
                    controller  [RANGE_EDIT_128]
                                stream      --> so s1
                                range       --> so N V e    \ automatic
                                single      --> so V e      / depends on list
                    note        [RANGE_EDIT_128]
                                stream      --> so s1
                                tracker     --> so      declare a tracker table
                                pressure    --> so N V e    \
                                on          --> so N V e     | automatic ??
                                off         --> so N V e    /

    */ comment ~

    ;// USER CONFIGURATION stored in osc.dwUser

                            ;// ----XXXXh
        MIDIIN_INPUT_ID     EQU 0000FFFFh   ;// leave these alone

    ;// input mode: only one    (4 bits)
    ;// (leave this as an INDEX for future expansion)

                            ;// ---X----h
        MIDIIN_INPUT_NONE   EQU 00000000h
        MIDIIN_INPUT_DEVICE EQU 00010000h   ;// or tracker
        MIDIIN_INPUT_STREAM EQU 00020000h
        MIDIIN_INPUT_TRACKER EQU 0030000h

        MIDIIN_INPUT_TEST   EQU 00030000h
        MIDIIN_INPUT_MAXIMUM EQU 0030000h   ;// for version 220

    ;// filter: index (4 bits)

                            ;// --X-----h
        MIDIIN_PORT_STREAM  EQU 00000000h ;// default output all events
        MIDIIN_PORT_CLOCK   EQU 00100000h ;// output tick start stop continue
        MIDIIN_PORT_RESET   EQU 00200000h ;// output reset events
        MIDIIN_CHAN_STREAM  EQU 00300000h ;// output events from selected channels
        MIDIIN_CHAN_PATCH   EQU 00400000h ;// output only patch changes
        MIDIIN_CHAN_PRESS   EQU 00500000h ;// output channel pressure
        MIDIIN_CHAN_WHEEL   EQU 00600000h ;// output pitch wheel
        MIDIIN_CHAN_CTRLR   EQU 00700000h ;// output selected controllers
        MIDIIN_NOTE_STREAM  EQU 00800000h ;// output all note events
        MIDIIN_NOTE_PRESS   EQU 00900000h ;// output only note pressure events
        MIDIIN_NOTE_ON      EQU 00A00000h ;// output only note on events
        MIDIIN_NOTE_OFF     EQU 00B00000h ;// output only note off events
        MIDIIN_NOTE_TRACKER EQU 00C00000h ;// no output

        MIDIIN_OUTPUT_TEST  EQU 00F00000h

        MIDIIN_NOTE_TRACKER_SAT EQU 01000000h   ;// OFF for LRU
        MIDIIN_NOTE_TRACKER_FREQ    EQU 02000000h   ;// OFF for output N
        MIDIIN_LOWEST_LATENCY   EQU 04000000h   ;// allow frame adjust forwards

    comment ~ /*

    OUTPUT CONFIGURATIONS

        these are tableized in verify_mode_table


    config      filters         show        hide        f_stream
    ----------- -------------   ------      ------      --------
    PORT_STREAM none            so          NVe         none

    PORT_CLOCK  FILTER_TIMING   so,NVe                  internal

    CHAN_STREAM channel         so,s1       Ve          s1
                FILTER_CHANNELS

    CHAN_PATCH  channel         so,Ve       N           N
                FILTER_PROGRAM

    CHAN_PRESS  channel         so,Ve       N           N
                FILTER_AFTERTOUCH

    CHAN_WHEEL  channel         so,Ve       N           N
                FILTER_PITCHWHEEL

    CHAN_CTRLR  channel         so,NVe                  internal
                FILTER_CTRL
                stat_ctrl

    NOTE_STREAM channel         so, s1      Ve          s1
                FILTER_NOTES
                note_filter

    NOTE_PRESS  channel         so,NVe                  internal
                FILTER_PRESSURE
                note_filter

    NOTE_ON     channel         so,NVe                  internal
                FILTER_NOTEON
                note_filter

    NOTE_OFF    channel         so,NVe                  internal
                FILTER_NOTEOFF
                note_filter

    TRACKER     channel         so          NVe         tracker table
                FILTER_NOTES
                note_filter



    FILTER DATA and ranges

        the midi object stores seperate copies of note number filters and controller filters
        this allows user to switch between modes and keep the previous settings

        several bit tables will need implemented

        channel filter      16 bits
        controller filter   128 bits
        note filter         128 bits

    */ comment ~


        MIDIIN_DATA STRUCT

        ;// secondary copies of midi filter and the tracker id (loaded with circuit)
        ;// NOTE !!! DO NOT REARRANGE THESE VALUES !!!
        ;//      !!! DOING SO REQUIRES SAVE_FILE TRANSLATION !!!
            user_filter_chan dd 0           ;// user supplied channel list
            user_filter_note dd 4 DUP (0)   ;// user supplied note list
            user_filter_ctrl dd 4 DUP (0)   ;// user supplied controller list
            tracker_id       dd 0           ;// trackers store the id here

            MIDIIN_SAVE_LENGTH EQU 10   ;// we store 10 dwords from dwUser

            ;// end of file save area

        ;// actual midi filter used when playing

            filter MIDI_FILTER  {}  ;// midi filter

        ;// ptr to which data slot is the f_stream

            f_stream    dd  0
            t_stream    MIDI_STREAM_ARRAY   {}  ;// temp stream

        ;// midiin fill support

            last_fill   dd  0   ;// last fill index we used
            fill_skew   dd  0   ;// used by tracker to allow inserting note off
            fill_index  dd  0   ;// index of which functions to use

        ;// tracker state

            tracker MIDIIN_TRACKER  {}

        MIDIIN_DATA ENDS

        MIDIIN_OSC_MAP  STRUCT

            OSC_OBJECT  {}

            pin_si  APIN    {}
            pin_so  APIN    {}
            pin_N   APIN    {}
            pin_V   APIN    {}
            pin_e   APIN    {}

            data_so dd SAMARY_LENGTH DUP (0)
            data_N  dd SAMARY_LENGTH DUP (0)
            data_V  dd SAMARY_LENGTH DUP (0)
            data_e  dd SAMARY_LENGTH DUP (0)

            midiin MIDIIN_DATA  {}

        MIDIIN_OSC_MAP  ENDS

;//////////////////////////////////////////////////////////////////////////////////////////



;//////////////////////////////////////////////////////////////////////////////////////////
comment ~ /*


EVENT FILLING

        after an object has a filtered f_stream to work with
        a generic mechanism for filling data is needed

        object sets first value to fill
        generic fill routines do the rest

        to do this, we'll need a previous_state last_fill

        generic fill plays a catch-up game, filling old data until it collides with new data
        generic fill can also detect pin_changing

        midiin_fill_Advance does all of this

        we'll try a centralized function for starters

        */ comment ~


            midiin_fill_Begin PROTO
            midiin_fill_Advance PROTO
            midiin_fill_End PROTO


;//////////////////////////////////////////////////////////////////////////////////////////




;//////////////////////////////////////////////////////////////////////////////////////////
comment ~ /*

MIDI OUT


    pieces:

        object.stream       holds data we want to send to the device
        device.in_stream    were oscs xfer their data
        device.out_stream   windows midi stream that gets sent to the device

    multiple objects are attached to a device
    multiple objects objects write to device.in_stream

    there are 2 out_streams per devive. One is busy, the other is waiting for data



        object.stream                          device.out_stream
                     \                        /
      object.stream -->-- device.in_stream --<  pReady points at one or the other
                     /                        \
        object.stream                          device.out_stream
                   /                            \
                  /                              \
              via midiout_WriteInStream       via midiout_H_calc



    now that we have midi streams we would like a simple convertion method
    the first mechanism we'll try is a 1:1 interleave with windows midi stream

    that means 1 tick must be 1/22050 seconds

    using   T for tempo in uSec.Quarter
            D for division in ticks per quarter

            T    10^6       1:1 ratio
            - = -----       we'll set D as a common number
            D   22050       then define T

    thus:   T = D * 10^6 / 22050

*/ comment ~

        MIDI_DIVI   EQU 384     ;// = 96 * 4
        MIDI_TICK   EQU 17415   ;// rounded



        MIDIOUT_NUM_BUFFERS equ 2
        MIDIEVENTS_PER_FRAME EQU 512


    ;// this struct is included in the hardware device block
    ;// objects xfer their stream to in_stream by calling midiout_WriteOutStream
    ;// play calls H_Calc to build out_stream, then send it

        MIDIOUT_FRAME STRUCT

            hdr         MIDIHDR {}
            out_stream  MIDISHORTEVENT ( MIDIEVENTS_PER_FRAME ) dup ({})
                        ;// note: a midishortevent is three dwords, for some reason
        MIDIOUT_FRAME ENDS


        MIDIOUT_HARDWARE_DEVICEBLOCK STRUCT

            HARDWARE_DEVICEBLOCK    {}

            pReady      dd  0 ;// this points at the MIDIOUT_FRAME to use
            ;// lastDelta   dd  0 ;// stores the last dwDeltaTime for sychronizing across frames
            in_stream   MIDI_STREAM_ARRAY   {}
            frame       MIDIOUT_FRAME MIDIOUT_NUM_BUFFERS dup ({})

        MIDIOUT_HARDWARE_DEVICEBLOCK ENDS

comment ~ /*

MIDIOUT_OSC_MAP


    stream in   si-->/----\
    N/s1 input   N-->|    |
    V input      V-->|    |--> so   stream out
    t input      t-->\----/


    OUTPUT MODES

        device  send all commands to a device
                NVt may be mixed with si as required

        stream  inject NVt commands into si stream
                output to so stream

    TRIGGERED,TRACKED and CONTINUOUS

        some commands should only be send when triggered
        others should be sent when the input changed
        others are a blend of the two

        triggered
            event is only sent when t is triggered
        continous
            events are sent when X changes enough to emit a different midi number
        tracked
            inputs are monitored, events are sent when it makes sense to do so


    INPUT MODES

        stream input

            merge two streams by inserting s1 into si

        clock

            tracked     V = play/not play
                        t = tick

        reset

            triggered   t = send event

        patch           [chan]

                        V = patch number
            need to choose patch number from popup

        press           [chan]

            continuous  V = pressure

        wheel           [chan]

            continous   V = wheel position

        controller      [chan]

            continous   V = value
            need to choose controller number from popup

        note on         [chan]

                        N = number
                        V = velocity
            triggered   t = trigger

        note off        [chan]

                        N = number
                        V = velocity
            triggered   t = trigger

        note press      [chan]

                        N = number
                        V = pressure
            triggered   t = trigger

        track 1 note    [chan]

            tracked     N = note number
                        V = velocity or pressure
                        t = on off state


*/ comment ~
;//////////////////////////////////////////////////////////////////////////////////////////

    ;// USER CONFIGURATION stored in osc.dwUser

        MIDIOUT_INPUT_ID        EQU 0000FFFFh   ;// leave these alone

    ;// input mode: only one    (4 bits)
    ;// (leave this as an INDEX for future expansion)

        MIDIOUT_OUTPUT_NONE     EQU 00000000h
        MIDIOUT_OUTPUT_STREAM   EQU 00010000h
        MIDIOUT_OUTPUT_DEVICE   EQU 00020000h

        MIDIOUT_OUTPUT_TEST     EQU 00030000h
        MIDIOUT_OUTPUT_MAXIMUM  EQU 00020000h ;// for version 220

    ;// input mode: index (4 bits)
                                              ;// show  desc
        MIDIOUT_PORT_STREAM     EQU 00000000h ;// s1    mix si with s1
        MIDIOUT_PORT_CLOCK      EQU 00100000h ;// Vt    tick start stop continue
        MIDIOUT_PORT_RESET      EQU 00200000h ;// t     reset events
        MIDIOUT_CHAN_PATCH_N    EQU 00300000h ;// Nt    send patch N
        MIDIOUT_CHAN_PATCH      EQU 00400000h ;// t     patch changes   (need to chose patch)
        MIDIOUT_CHAN_PRESS      EQU 00500000h ;// V     channel pressure
        MIDIOUT_CHAN_WHEEL      EQU 00600000h ;// V     pitch wheel
        MIDIOUT_CHAN_CTRLR      EQU 00700000h ;// V     controller events (need to choose controller)
        MIDIOUT_CHAN_CTRLR_N    EQU 00800000h ;// NVt   send controller N
        MIDIOUT_NOTE_PRESS      EQU 00900000h ;// NVt   note pressure events
        MIDIOUT_NOTE_ON         EQU 00A00000h ;// NVt   note on events
        MIDIOUT_NOTE_OFF        EQU 00B00000h ;// NVt   note off events
        MIDIOUT_NOTE_TRACK_N    EQU 00C00000h ;// NV    state of NV,
        MIDIOUT_NOTE_TRACK_t    EQU 00D00000h ;// NVt   state of NVt,

        MIDIOUT_INPUT_TEST      EQU 00F00000h

    ;// trigger mode

        MIDIOUT_TRIG_EDGE_BOTH  EQU 00000000h
        MIDIOUT_TRIG_EDGE_POS   EQU 01000000h
        MIDIOUT_TRIG_EDGE_NEG   EQU 02000000h

        MIDIOUT_TRIG_EDGE_TEST  EQU 03000000h


    MIDIOUT_DATA STRUCT

        channel     dd  0   ;// user specified channel to send commands on
        patch       dd  0   ;// user specified patch
        controller  dd  0   ;// user specified controller number

        MIDIOUT_SAVE_LENGTH EQU 3   ;// number of extra dwords we save and load

        command     dd  0   ;// bias plus command plus channel plus ....
                            ;// built by verify mode

        last_N      dd  0   ;// midi integer last number we used (always correct)
        last_V      dd  0   ;// midi integer last value we used (always correct)
        last_t      dd  0   ;// midi integer last trigger we saw
        ;// don't confuse these with actual float values
        ;// these are the midi scaled versions of the floats

    MIDIOUT_DATA ENDS


    MIDIOUT_OSC_MAP STRUCT

        OSC_OBJECT  {}
        pin_si  APIN    {}  ;// stream input
        pin_N   APIN    {}  ;// N input or stream 2
        pin_V   APIN    {}  ;// V input
        pin_t   APIN    {}  ;// trigger input
        pin_so  APIN    {}  ;// stream out
        stream  MIDI_STREAM_ARRAY {}    ;// data for pin_so

        midiout MIDIOUT_DATA {}

    MIDIOUT_OSC_MAP ENDS

    ;// defined in midiout_device.asm

        midiout_H_Ctor  PROTO
        midiout_H_Dtor  PROTO
        midiout_H_Open  PROTO STDCALL pDevice:PTR MIDIOUT_HARDWARE_DEVICEBLOCK
        midiout_H_Close PROTO STDCALL pDevice:PTR MIDIOUT_HARDWARE_DEVICEBLOCK
        midiout_H_Ready PROTO
        midiout_H_Calc  PROTO
        midiout_WriteInStream PROTO


;///////////////////////////////////////////////////////////////////////////////

;// MIDI STRINGS

    midistring_SetFonts PROTO

    ;// common to both, defined in midi_strings.asm

    EXTERNDEF midi_font_N_out:DWORD
    EXTERNDEF midi_font_s1_out:DWORD
    EXTERNDEF midi_font_N_in:DWORD
    EXTERNDEF midi_font_s1_in:DWORD
    EXTERNDEF midi_font_F:DWORD
    EXTERNDEF midi_font_plus_minus:DWORD
    EXTERNDEF midi_font_plus_zero:DWORD

    ;// mode text is defined by two tables

    EXTERNDEF midiin_command_label_table:DWORD
    EXTERNDEF midiout_command_label_table:DWORD
    EXTERNDEF sz_midiin_tracker:BYTE
    EXTERNDEF sz_midiout_track:BYTE

    ;// combo items are used to load combo boxes in an efficient manner

    MIDI_COMBO_ITEM STRUCT

        psz_text    dd  0   ;// ptr to text item
        number      dd  0   ;// number to apply to item

    MIDI_COMBO_ITEM ENDS

    EXTERNDEF midi_controller_table:MIDI_COMBO_ITEM
    EXTERNDEF midi_patch_table:MIDI_COMBO_ITEM

;///////////////////////////////////////////////////////////////////////////////

;// graphics layout parameters
;// these are used in render commands

    ;// use a border of this many pixels

        MIDI_LABEL_BIAS_X EQU 2
        MIDI_LABEL_BIAS_Y EQU MIDI_LABEL_BIAS_X


