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
;//     ABox_Divider.asm
;//
;// TOC
;// divider_Calc
;// divider_Ctor
;// divider_Reset
;// divider_InitMenu
;// divider_SyncPins
;// divider_Command
;// divider_SetShape
;// divider_LoadUndo

OPTION CASEMAP:NONE

.586
.MODEL FLAT

USE_THIS_FILE equ 1

IFDEF USE_THIS_FILE

        .NOLIST
        include <Abox.inc>
        .LIST


comment ~ /*

    where things are stored:

    t.dwUser    last received trigger sign
    r.dwUser    last received reset sign

*/ comment ~

.DATA

;// OSC_OBJECT

osc_Divider OSC_CORE {  divider_Ctor,,divider_Reset,divider_Calc }
            OSC_GUI  {  ,divider_SetShape,,,,divider_Command,divider_InitMenu,,,osc_SaveUndo,divider_LoadUndo}
            OSC_HARD { }

    OSC_DATA_LAYOUT {NEXT_Divider,IDB_DIVIDER,OFFSET popup_DIVIDER,,
        3,4,
        SIZEOF OSC_OBJECT + ( SIZEOF APIN ) * 3,
        SIZEOF OSC_OBJECT + ( SIZEOF APIN ) * 3 + SAMARY_SIZE,
        SIZEOF OSC_OBJECT + ( SIZEOF APIN ) * 3 + SAMARY_SIZE }

    OSC_DISPLAY_LAYOUT { r_rect_container,, ICON_LAYOUT(9,1,2,4) }


    APIN_init {-0.9,sz_Count,'t',,UNIT_LOGIC OR PIN_LOGIC_INPUT }
    APIN_init { 0.0,        ,0B1h,,UNIT_LOGIC OR PIN_OUTPUT   } ;// +/-
    APIN_init { 0.9,sz_Reset,'r',,UNIT_LOGIC OR PIN_LOGIC_INPUT }

    short_name  db  'Digital Divider',0
    description db  'Counts zero-crossing events and toggles its output when the count is reached.',0
    ALIGN 4


    ;// flags for object.user

        DIVIDER_COUNT_TEST   equ  0000000Fh  ;// user settable count
        DIVIDER_COUNT_MASK   equ 0FFFFFF00h

        DIVIDER_COUNTER_TEST equ  0000FF00h  ;// current count (sign indicates hold)
        DIVIDER_COUNTER_MASK equ 0FFFF00FFh

        DIVIDER_TRIGGER_POS  equ  10000000h  ;// count positive edges only
        DIVIDER_TRIGGER_NEG  equ  20000000h  ;// count negative edges only
        DIVIDER_TRIGGER_TEST equ  DIVIDER_TRIGGER_POS OR DIVIDER_TRIGGER_NEG


        DIVIDER_RESET_POS    equ  01000000h
        DIVIDER_RESET_NEG    equ  02000000h
        DIVIDER_RESET_TEST   equ  DIVIDER_RESET_POS OR DIVIDER_RESET_NEG
        DIVIDER_RESET_GATE   equ  04000000h

        DIVIDER_HOLD         equ  08000000h  ;// hold until reset

        DIVIDER_RESET_SHIFT  equ LOG2(DIVIDER_RESET_POS)

        DIVIDER_OUT_DIGITAL  equ  40000000h  ;// set if output is 0 or -1
        DIVIDER_OUT_MASK     equ 0BFFFFFFFh  ;// otherwise output is +1 -1

    ;// ID TABLE

        divider_reset_id_table  LABEL DWORD

            dd  ID_DIVIDER_RESET_BOTH_EDGE  ;// 000
            dd  ID_DIVIDER_RESET_POS_EDGE   ;// 001
            dd  ID_DIVIDER_RESET_NEG_EDGE   ;// 010
            dd  0
            dd  0
            dd  ID_DIVIDER_RESET_POS_GATE   ;// 101
            dd  ID_DIVIDER_RESET_NEG_GATE   ;// 110


    ;// shape source pointers

    divider_shape   dd  DIV_01_PSOURCE
                    dd  DIV_02_PSOURCE
                    dd  DIV_03_PSOURCE
                    dd  DIV_04_PSOURCE
                    dd  DIV_05_PSOURCE
                    dd  DIV_06_PSOURCE
                    dd  DIV_07_PSOURCE
                    dd  DIV_08_PSOURCE
                    dd  DIV_09_PSOURCE
                    dd  DIV_10_PSOURCE
                    dd  DIV_11_PSOURCE
                    dd  DIV_12_PSOURCE
                    dd  DIV_13_PSOURCE
                    dd  DIV_14_PSOURCE
                    dd  DIV_15_PSOURCE
                    dd  DIV_16_PSOURCE

    ;// private functions

        divider_Reset PROTO


    ;// command table
    DIVIDER_COMMAND_TABLE_LENGTH equ 16
    divider_command_table LABEL DWORD

        dd ID_DIVIDER_1
        dd ID_DIVIDER_2
        dd ID_DIVIDER_3
        dd ID_DIVIDER_4
        dd ID_DIVIDER_5
        dd ID_DIVIDER_6
        dd ID_DIVIDER_7
        dd ID_DIVIDER_8
        dd ID_DIVIDER_9
        dd ID_DIVIDER_10
        dd ID_DIVIDER_11
        dd ID_DIVIDER_12
        dd ID_DIVIDER_13
        dd ID_DIVIDER_14
        dd ID_DIVIDER_15
        dd ID_DIVIDER_16


    ;// then we get the digital font

        divider_output_font dd  0B1h        ;// +/- bipolar
                            dd  80002DBAh   ;// 0/- digital
        divider_font_t  dd  't' ;// normal divider mode
        divider_font_s  dd  's' ;// set reset mode

    ;// and we get an osc map for this object

    OSC_MAP STRUCT

                OSC_OBJECT  {}
        pin_t   APIN        {}
        pin_x   APIN        {}
        pin_r   APIN        {}
        data_x  dd  SAMARY_LENGTH DUP (0)

    OSC_MAP ENDS







comment ~ /*

    new divider calc (again)

ABox221

    the calcs work as state machines
    each node must enter with the correct state         legend
    each node exits with the correct state
    some nodes are labels, others are procs             t   trigger signal
                                                        r   reset signal
    there are 120 nodes for the following option set    h   hold option
                                                        d   changing signal
    /                           rme(0)         \        s   static signal
    |   dt(00)  tm(00)  dr(0)   rbe(2)  nh(0)   |       m   minus
    |   st(60)  tb(20)  sr(10)  rpe(4)  yh(1)   |       p   positive
    |           tp(40)          rmg(6)          |       b   both
    \                           rpg(8)         /        g   gate
                                                        e   edge
states  2       3       2       5       2   = 120       y   yes
cols   60      20      10       2       0               n   no

*/ comment ~

;// these save some logic when determining the trigger modes

div_trigger_calc_offset LABEL DWORD
    dd  20  ;// tb  both    00
    dd  40  ;// tp  pos     01
    dd  0   ;// tn  neg     10
    dd  0   ;// err         11

div_reset_calc_offset LABEL DWORD
    dd  2   ;// rbe both edge   000
    dd  4   ;// rpe pos edge    001
    dd  0   ;// rme neg edge    010
    dd  0   ;// err             011
    dd  0   ;// err             100
    dd  8   ;// rpg pos gate    101
    dd  6   ;// rmg neg gate    110
    dd  0   ;// err             111


;// here is the master calc table
;//
;// 10 per row

div_calc_jump_table LABEL DWORD

dd  dt_tm_dr_rme_nh, dt_tm_dr_rme_yh, dt_tm_dr_rbe_nh, dt_tm_dr_rbe_yh, dt_tm_dr_rpe_nh, dt_tm_dr_rpe_yh, dt_tm_dr_rmg_nh, dt_tm_dr_rmg_yh, dt_tm_dr_rpg_nh, dt_tm_dr_rpg_yh
dd  dt_tm_sr_rme_nh, dt_tm_sr_rme_yh, dt_tm_sr_rbe_nh, dt_tm_sr_rbe_yh, dt_tm_sr_rpe_nh, dt_tm_sr_rpe_yh, dt_tm_sr_rmg_nh, dt_tm_sr_rmg_yh, dt_tm_sr_rpg_nh, dt_tm_sr_rpg_yh
dd  dt_tb_dr_rme_nh, dt_tb_dr_rme_yh, dt_tb_dr_rbe_nh, dt_tb_dr_rbe_yh, dt_tb_dr_rpe_nh, dt_tb_dr_rpe_yh, dt_tb_dr_rmg_nh, dt_tb_dr_rmg_yh, dt_tb_dr_rpg_nh, dt_tb_dr_rpg_yh
dd  dt_tb_sr_rme_nh, dt_tb_sr_rme_yh, dt_tb_sr_rbe_nh, dt_tb_sr_rbe_yh, dt_tb_sr_rpe_nh, dt_tb_sr_rpe_yh, dt_tb_sr_rmg_nh, dt_tb_sr_rmg_yh, dt_tb_sr_rpg_nh, dt_tb_sr_rpg_yh
dd  dt_tp_dr_rme_nh, dt_tp_dr_rme_yh, dt_tp_dr_rbe_nh, dt_tp_dr_rbe_yh, dt_tp_dr_rpe_nh, dt_tp_dr_rpe_yh, dt_tp_dr_rmg_nh, dt_tp_dr_rmg_yh, dt_tp_dr_rpg_nh, dt_tp_dr_rpg_yh
dd  dt_tp_sr_rme_nh, dt_tp_sr_rme_yh, dt_tp_sr_rbe_nh, dt_tp_sr_rbe_yh, dt_tp_sr_rpe_nh, dt_tp_sr_rpe_yh, dt_tp_sr_rmg_nh, dt_tp_sr_rmg_yh, dt_tp_sr_rpg_nh, dt_tp_sr_rpg_yh
dd  st_tm_dr_rme_nh, st_tm_dr_rme_yh, st_tm_dr_rbe_nh, st_tm_dr_rbe_yh, st_tm_dr_rpe_nh, st_tm_dr_rpe_yh, st_tm_dr_rmg_nh, st_tm_dr_rmg_yh, st_tm_dr_rpg_nh, st_tm_dr_rpg_yh
dd  st_tm_sr_rme_nh, st_tm_sr_rme_yh, st_tm_sr_rbe_nh, st_tm_sr_rbe_yh, st_tm_sr_rpe_nh, st_tm_sr_rpe_yh, st_tm_sr_rmg_nh, st_tm_sr_rmg_yh, st_tm_sr_rpg_nh, st_tm_sr_rpg_yh
dd  st_tb_dr_rme_nh, st_tb_dr_rme_yh, st_tb_dr_rbe_nh, st_tb_dr_rbe_yh, st_tb_dr_rpe_nh, st_tb_dr_rpe_yh, st_tb_dr_rmg_nh, st_tb_dr_rmg_yh, st_tb_dr_rpg_nh, st_tb_dr_rpg_yh
dd  st_tb_sr_rme_nh, st_tb_sr_rme_yh, st_tb_sr_rbe_nh, st_tb_sr_rbe_yh, st_tb_sr_rpe_nh, st_tb_sr_rpe_yh, st_tb_sr_rmg_nh, st_tb_sr_rmg_yh, st_tb_sr_rpg_nh, st_tb_sr_rpg_yh
dd  st_tp_dr_rme_nh, st_tp_dr_rme_yh, st_tp_dr_rbe_nh, st_tp_dr_rbe_yh, st_tp_dr_rpe_nh, st_tp_dr_rpe_yh, st_tp_dr_rmg_nh, st_tp_dr_rmg_yh, st_tp_dr_rpg_nh, st_tp_dr_rpg_yh
dd  st_tp_sr_rme_nh, st_tp_sr_rme_yh, st_tp_sr_rbe_nh, st_tp_sr_rbe_yh, st_tp_sr_rpe_nh, st_tp_sr_rpe_yh, st_tp_sr_rmg_nh, st_tp_sr_rmg_yh, st_tp_sr_rpg_nh, st_tp_sr_rpg_yh


;// ECHO hey the debug_frame is on
;// debug_frame dd  0   ;





.CODE

ASSUME_AND_ALIGN
divider_Calc    PROC USES ebp

        ASSUME esi:PTR OSC_MAP

        sub ebx, ebx
        xor ecx, ecx
        sub ebp, ebp

        OR_GET_PIN [esi].pin_t.pPin, ebx
        .IF ZERO?
            mov ebx, math_pNullPin
        .ENDIF
        test [ebx].dwStatus, PIN_CHANGING
        .IF ZERO?
            add ecx, 60
        .ENDIF

        OR_GET_PIN [esi].pin_r.pPin, ebp
        .IF ZERO?
            mov ebp, math_pNullPin
        .ENDIF
        test [ebp].dwStatus, PIN_CHANGING
        .IF ZERO?
            add ecx, 10
        .ENDIF

        mov eax, [esi].dwUser

        mov ebx, [ebx].pData

        BITT eax, DIVIDER_HOLD  ;// carry=1 for hold, 0 for no hold

        mov ebp, [ebp].pData

        mov edx, eax

        adc ecx, 0

        and eax, DIVIDER_RESET_TEST OR DIVIDER_RESET_GATE
        and edx, DIVIDER_TRIGGER_TEST

        BITSHIFT eax, DIVIDER_RESET_POS, 4
        mov edi, [esi].data_x[LAST_SAMPLE]
        BITSHIFT edx, DIVIDER_TRIGGER_POS, 4


        add ecx, div_reset_calc_offset[eax]
        add ebx, 3  ;// so we look at bytes
        add ecx, div_trigger_calc_offset[edx]
        add ebp, 3  ;// so we look at bytes

        fld1
        mov edx, [esi].dwUser   ;// cur_count default count
        fchs        ;// true
        fld1    ;// false   true
        .IF edx & DIVIDER_OUT_DIGITAL
            fsub st, st ;// fldz    ;// false   true
        .ENDIF

        push div_calc_jump_table[ecx*4]

        xor eax, eax    ;// last edges

        and edi, 80000000h  ;// edi also stores pin_changing

        mov al, BYTE PTR [esi].pin_t.dwUser ;// last t trigger

        .IF SIGN?
            fxch    ;// true false
        .ENDIF

        xor ecx, ecx
        mov ah, BYTE PTR [esi].pin_r.dwUser ;// last r trigger

;// ECHO hey the debug_frame is on
;// DEBUG_IF <debug_frame == 1C8h >

        retn    ;// jump to correct node

        ASSUME ebx:PTR BYTE
        ASSUME ebp:PTR BYTE


    ALIGN 16
    calc_done::

        ;// esi     osc
        ;// ecx     unknon
        ;// ah:al   reset:trigger edge
        ;// dh:dl   current_count:default_count
        ;// ebp:ebx reset:trigger
        ;// edi     sign:changing

        and [esi].pin_x.dwStatus, NOT PIN_CHANGING
        mov BYTE PTR [esi].dwUser[1], dh    ;// store the current count
        fstp st                             ;// clear out fpu
        mov BYTE PTR [esi].pin_t.dwUser, al ;// store last trigger
        test edi, 7FFFFFFFh                 ;// check pin changing
        mov BYTE PTR [esi].pin_r.dwUser, ah ;// store last reset
        fstp st                             ;// clear out fpu
        jz @F
        or [esi].pin_x.dwStatus, PIN_CHANGING

    ;// that's it

    @@:

    ;// ECHO hey the debug_frame is on
    ;// inc debug_frame

        ret


divider_Calc    ENDP



comment ~ /*

algorithm no hold:          need:

    check for reset         pointer and last value

        reset the count     count to reset to
        skip trigger test

    check for trigger       pointer and last value

        dec count           edge counter

        check for zero

            reset count
            toggle output   value to output

    store output            pointer and sample counter

    esi     osc
    ;// dh:dl   current_count:default_count
    ;// ah:al   reset:trigger edge
    ;// ebp:ebx reset:trigger
    ;// edi     sign:changing

    store yes and no in fpu
    store the current sign in edi, and when toggling output
    be sure to toggle the sign

    assume that edi and fpu are always in sync


algorithm for hold

    detect hold state as ah=0, meaning count is completed

*/ comment ~





;/////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////
;///
;///                    IF_EDGE_GOTO
;///        MACROS      RESET_COUNT
;///                    COUNT_TOGGLE
;///                    NEXT_SAMPLE

LEGEND  EQU 1
comment ~ /*

    the macros use the above register declartions
    restated here for clarity:

    ;// esi     osc
    ;// ecx     zero
    ;// ah:al   reset:trigger edge
    ;// ebp:ebx reset:trigger
    ;// dh:dl   current_count:default_count
    ;// edi     sign:changing
    ;// fpu     state1  state2


    use these macros to perform the divider calc

    IF_EDGE     tests the input signal and exits to somewhere
    IF_NOT_EDGE tests the input signal and exits to somewhere
    RESET_COUNT used to reset the count and make sure that t trigger is loaded
                can load t trigger if LOAD_T (since we ignore it when r is received
                will reset the count
                may toggle fpu and set pin changing
    COUNT_TOGGLE
                counts and toggles the fpu:edi if required
                resets the count to default
                may set pin changing
    COUNT_WAIT
                also counts, toggles, sets changing
                but does not reset the count
                used in _yh modes
    NEXT_SAMPLE stores the fpu at the current sample
                iterates to next sample
                may exit is complete

    each of the macros requires parameters that tell it how to exit
    sometimes these may be left blank for fallthrough


*/ comment ~


;// IF_EDGE   GOTO
;//
;//     nam     =   input to test   { t | r | t0 | r0 }
;//     edge    =   current state and what to look for
;//             =   { BOTH POS_NEG NEG_POS }
;//     lab     =   label to jump to is test succeeds

    IF_EDGE MACRO nam:req, edge:req, lab:req

        ;// determine WHAT to test

            LOCAL PIN,MEM
            IFIDN <nam>,<r>
                PIN TEXTEQU <ah>
                MEM TEXTEQU <[ebp+ecx]>
            ELSEIFIDN <nam>,<t>
                PIN TEXTEQU <al>
                MEM TEXTEQU <[ebx+ecx]>
            ELSEIFIDN <nam>,<r0>
                PIN TEXTEQU <ah>
                MEM TEXTEQU <[ebp]>
            ELSEIFIDN <nam>,<t0>
                PIN TEXTEQU <al>
                MEM TEXTEQU <[ebx]>
            ELSE
                .ERR <NAME has wrong value>
            ENDIF

        ;// produce the correct test

            IFIDN     <POS_NEG>,<edge>      ;// value is pos now
                or PIN,MEM
                js lab
            ELSEIFIDN <NEG_POS>,<edge>      ;// value is neg now
                and PIN,MEM
                jns lab
            ELSEIFIDN <BOTH>,<edge>         ;// any edge will do
                xor PIN,MEM
                mov PIN,MEM
                js lab
            ELSE
                .ERR <EDGE has unknown value>
            ENDIF

        ;// thats it

            ENDM


;// IF_NOT_EDGE GOTO
;//
;//     nam     =   input to test   { t | r | t0 | r0 }
;//     edge    =   current state and what to look for
;//             =   { BOTH POS_NEG NEG_POS }
;//     lab     =   label to jump to if test succeeds

    IF_NOT_EDGE MACRO nam:req, edge:req, lab:req

        ;// determine WHAT to test

            LOCAL PIN,MEM
            IFIDN <nam>,<r>
                PIN TEXTEQU <ah>
                MEM TEXTEQU <[ebp+ecx]>
            ELSEIFIDN <nam>,<t>
                PIN TEXTEQU <al>
                MEM TEXTEQU <[ebx+ecx]>
            ELSEIFIDN <nam>,<r0>
                PIN TEXTEQU <ah>
                MEM TEXTEQU <[ebp]>
            ELSEIFIDN <nam>,<t0>
                PIN TEXTEQU <al>
                MEM TEXTEQU <[ebx]>
            ELSE
                .ERR <NAME has wrong value>
            ENDIF

        ;// produce the correct test

            IFIDN     <POS_NEG>,<edge>      ;// value is pos now
                or PIN,MEM
                jns lab
            ELSEIFIDN <NEG_POS>,<edge>      ;// value is neg now
                and PIN,MEM
                js lab
            ELSEIFIDN <BOTH>,<edge>         ;// any edge will do
                xor PIN,MEM
                mov PIN,MEM
                jns lab
            ELSE
                .ERR <EDGE has unknown value>
            ENDIF

        ;// thats it

            ENDM

    ;// IF_LEVEL is used in gate mode
    ;// we always assume that the pin is in the opposite state of what is being tested

    IF_LEVEL MACRO pin:req, lev:req,lab:req

            LOCAL MEM

            IFIDN <pin>,<r>
                MEM TEXTEQU <[ebp+ecx]>
            ELSEIFIDN <pin>,<r0>
                MEM TEXTEQU <[ebp]>
            ELSE
            .ERR <use r or r0>
            ENDIF

            IFIDN <lev>,<POS>
                ;// we assume that ah is neg
                and ah, MEM
                jns lab

            ELSEIFIDN <lev>,<NEG>
                ;// we assume that ah is pos
                or ah,MEM
                js lab

            ELSE
            .ERR <use POS or NEG>
            ENDIF

            ENDM




;// COUNT_TOGGLE        use only for _nh modes
;//
;//     use when a t trigger is received
;//     it will decrease dh
;//     if count NOT reached, exit to label
;//         --> label may be blank for fall through
;//     if count IS reached
;//         maybe reset count
;//         toggle the value
;//         maybe set pin changing
;//         exit to label
;//
;// use NODIRTY when appropriate
;//     DIRTY when appropriate
;//

    COUNT_TOGGLE MACRO dirty:req, lab

        LOCAL EXIT_JUMP_NO_COUNT,EXIT_JUMP_YES_COUNT,exit_jump

        ;;// define how to exit

            IFB <lab>
                ;;// exit is fallthrough
                EXIT_JUMP_NO_COUNT TEXTEQU <exit_jump>
                EXIT_JUMP_YES_COUNT TEXTEQU <>
            ELSE
                ;;// exit is a label
                EXIT_JUMP_NO_COUNT TEXTEQU <lab>
                EXIT_JUMP_YES_COUNT TEXTEQU <jmp lab>
            ENDIF

        ;;// here we go

            dec dh                  ;// decrease the count
            jns EXIT_JUMP_NO_COUNT  ;// exit if not hit

            IFIDN <dirty>,<DIRTY>
            ;// add edi, 80000001h
            lea edi, [edi+ecx+80000000h];// toggle sign, set changing if ecx != zero
            ELSEIFIDN <dirty>,<NODIRTY>
            btc edi, 31             ;// just toggle the sign
            ELSE
            .ERR <use DIRTY or NODIRTY>
            ENDIF
            fxch                    ;// swap fpu values
            mov dh, dl              ;// reset the count
            EXIT_JUMP_YES_COUNT     ;// exit to wherever

        exit_jump:

        ;;// that's it

        ENDM

;// COUNT_WAIT          use only for _yh modes
;//
;//     still_count is a label to jump to if the object can still count
;//     done_count is a label to jump to if the object cannot count
;//     one or both must be specified

    COUNT_WAIT MACRO dirty:REQ, still_count, done_count

        LOCAL   exit_jump, STILL_JUMP, DONE_JUMP


            IFB <still_count>

                IFB <done_count>
                    ;// neigther still or done is specifed
                    ;// so we assume fall through
                    ;// this should only be needed with no dirty
                    STILL_JUMP TEXTEQU <exit_jump>
                    DONE_JUMP  TEXTEQU <>
                ELSE
                ;// done is specified, still is not

                    ;// so still counting should look like fall through
                    STILL_JUMP TEXTEQU <exit_jump>
                    DONE_JUMP  TEXTEQU <jmp done_count>
                ENDIF

            ELSE

                IFNB <done_count>
                ;// still count AND done_count are specified

                    STILL_JUMP TEXTEQU <still_count>
                    DONE_JUMP  TEXTEQU <jmp done_count>

                ELSE
                ;// still_count is specified, don_count is not
                ;// so done count is fall through

                    STILL_JUMP TEXTEQU <still_count>
                    DONE_JUMP  TEXTEQU <>

                ENDIF

            ENDIF


            dec dh                  ;// decrease the count
            jns STILL_JUMP          ;// exit if not hit

            IFIDN <dirty>,<DIRTY>
            lea edi, [edi+ecx+80000000h];// toggle sign, set changing if ecx != zero
            ELSEIFIDN <dirty>,<NODIRTY>
            btc edi, 31             ;// just toggle the sign
            ELSE
            .ERR <use DIRTY or NODIRTY>
            ENDIF
            fxch                    ;// swap fpu values
            DONE_JUMP

        exit_jump:

        ENDM



;// RESET_COUNT
;//
;//     use to reset the count
;//     may also load the t trigger value so we can keep track
;//     lab tells how to exit, may be blank for fallthrough
;//
;// use NODIRTY when appropriate
;//     DIRTY when appropriate
;//
;// use LOAD to load the t edge, so we keep track
;//     NOLOAD if this is not nessesary (ie already done)
;//
;// use pos_exit and neg_exit to test al


    RESET_COUNT MACRO   dirty:req, load:req, pos_exit, neg_exit

        LOCAL _SET_DIRTY

        ;// _SET_DIRTY is condensed to 1 instruction
        IFIDN <dirty>,<DIRTY>
        _SET_DIRTY TEXTEQU <or edi, ecx>        ;// DIRTY set pin changing if ecx != zero
        ELSEIFIDN <dirty>,<NODIRTY>
        _SET_DIRTY TEXTEQU <>
        ELSE
        .ERR <use DIRTY or NODIRTY>
        ENDIF


        IFIDN <load>,<LOAD>

        ;/////////////////////////////////////
        ;// ver 1   exit to pos_exit or neg_exit
        ;//         LOAD, DIRTY ,, pos_exit,neg_exit

            mov al, [ebx+ecx]   ;// LOAD  make sure we load the trigger
            btr edi, 31         ;//       check if currently negative
            mov dh, dl          ;//       reset the count

            IFNB <neg_exit>
            IFNB <pos_exit>
            ;// neg and pos exit are specified
            ;// meaning we test al and exit to one of two places

                .IF CARRY?
                    fxch        ;//       false true
                    _SET_DIRTY  ;// DIRTY set pin changing if ecx != zero
                .ENDIF

                test al, al     ;// EXIT  make sure to jump back to correct spot
                js neg_exit
                jmp pos_exit

            ELSE
            ;// neg_exit is not blank, pos_exit is blank
            ;// this is not a valid conition
            .ERR <NEG_EXIT used with no POS_EXIT>
            ENDIF
            ELSEIFNB <pos_exit>
            ;// neg_exit is blank, pos_exit is not blank
            ;// meaning we do not test al, and exit to label

                jnc pos_exit
                fxch            ;//       false true
                _SET_DIRTY      ;// DIRTY set pin changing if ecx != zero
                jmp pos_exit

            ELSE
            ;// neg and pos exit are blank
            ;// meaning we fall through

                .IF CARRY?
                fxch            ;//       false true
                _SET_DIRTY      ;// DIRTY set pin changing if ecx != zero
                .ENDIF

            ENDIF

        ;//
        ;// ver 1
        ;//////////////////////////////////

        ELSEIFIDN <load>,<NOLOAD>

        ;/////////////////////////////////
        ;// ver2    fall through or exit
        ;//         DIRTY NOLOAD

            IFNB <neg_exit>
            .ERR <NOLOAD used with NEG_EXIT>
            ENDIF

            btr edi, 31         ;//       check if currently negative
            mov dh, dl          ;//       reset the count
            IFB <pos_exit>

                .IF CARRY?
                    fxch            ;//       false true
                    _SET_DIRTY
                .ENDIF

            ELSE

                jnc pos_exit
                fxch
                _SET_DIRTY
                jmp pos_exit

            ENDIF
        ;//
        ;// ver 2
        ;//////////////////////////////////

        ELSE
        .ERR <use LOAD or NOLOAD>
        ENDIF

        ENDM



;// NEXT_SAMPLE
;//
;//     stores the fpu value, iterates and maybe exits
;//
;//     lab may be blank to fall through
;//     or a label to jump to
;//     ending the loop always exits to calc_done

    NEXT_SAMPLE MACRO lab

        fst [esi+ecx].data_x    ;;// store the output value
        add ecx, 4              ;;// next output value
        cmp ecx, SAMARY_SIZE    ;;// see if we're done

        ;;// determine how to proceed

        IFB <lab>
            jae calc_done       ;;// fallthrough is pass, otherwise done
        ELSE
            jb lab              ;;// pass is jump to top of loop
            jmp calc_done       ;;// other wise were done
        ENDIF

        ENDM


    ;///////////////////////////////////////////////////////////////////////////
    ;//
    ;// ST_STATIC_TEST      exits to store_static if already reset
    ;//                     use for stdr states

        ALREADY_RESET MACRO

            .IF dh==dl          ;// see if count is started
            test edi, edi       ;// see if out level is correct, want pos
            jns store_static    ;// we want pos outlevel to skip the whole thing
            .ENDIF

            ENDM



;///
;///
;///        MACROS
;///
;///
;/////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////







;////////////////////////////////////////////////////
;//
;//     dt dt loops for _nh modes
;//

ALIGN 16
dt_tb_dr_rbe_nh PROC            ;// see LEGEND (F12)

    top_of:     IF_EDGE         r, BOTH, got_r
                IF_EDGE         t, BOTH, got_t
    next_s:     NEXT_SAMPLE     top_of

    got_r:      RESET_COUNT     DIRTY,LOAD, next_s

    got_t:      COUNT_TOGGLE    DIRTY,next_s

dt_tb_dr_rbe_nh ENDP

ALIGN 16
dt_tm_dr_rme_nh PROC        ;// see LEGEND (F12)

                test ah, ah
                jns pos_r
        neg_r:  test al, al
                js  mm_top
                jmp mp_top
        pos_r:  test al, al
                js  pm_top
                jmp pp_top

;// PM  ah is pos al is neg
    pm_next:    NEXT_SAMPLE
    pm_top:     IF_EDGE         r,POS_NEG,p_r
    pm_trig:    IF_NOT_EDGE     t,NEG_POS,pm_next
;// PP  ah is pos al is pos
    pp_next:    NEXT_SAMPLE
    pp_top:     IF_EDGE         r,POS_NEG,p_r
    pp_trig:    IF_NOT_EDGE     t,POS_NEG,pp_next
                COUNT_TOGGLE    DIRTY,pm_next

;// MM  ah is neg al is neg
    mm_next:    NEXT_SAMPLE
    mm_top:     IF_EDGE         r,NEG_POS,pm_trig
                IF_NOT_EDGE     t,NEG_POS,mm_next
;// MP  ah is neg al is pos
    mp_next:    NEXT_SAMPLE
    mp_top:     IF_EDGE         r,NEG_POS,pp_trig
                IF_NOT_EDGE     t,POS_NEG,mp_next
                COUNT_TOGGLE    DIRTY,mm_next
;// R   got reset ah is neg, al needs tested
    p_r:        RESET_COUNT     DIRTY,LOAD,mp_next,mm_next


dt_tm_dr_rme_nh ENDP

ALIGN 16
dt_tp_dr_rpe_nh PROC            ;// see LEGEND (F12)

    ;// reset mp mm
    ;// count pm mm

                test ah, ah
                jns pos_r
        neg_r:  test al, al
                js  mm_top
                jmp mp_top
        pos_r:  test al, al
                js  pm_top
                jmp pp_top

;// PP
    pp_next:    NEXT_SAMPLE
    pp_top:     IF_EDGE         r,POS_NEG,mp_trig
    pp_trig:    IF_NOT_EDGE     t,POS_NEG,pp_next
;// PM
    pm_next:    NEXT_SAMPLE
    pm_top:     IF_EDGE         r,POS_NEG,mm_trig
    pm_trig:    IF_NOT_EDGE     t,NEG_POS,pm_next
    pm_t:       COUNT_TOGGLE    DIRTY,pp_next


;// MP
    mp_next:    NEXT_SAMPLE
    mp_top:     IF_EDGE         r,NEG_POS,m_r
    mp_trig:    IF_NOT_EDGE     t,POS_NEG,mp_next
;// MM
    mm_next:    NEXT_SAMPLE
    mm_top:     IF_EDGE         r,NEG_POS,m_r
    mm_trig:    IF_NOT_EDGE     t,NEG_POS,mm_next
    mm_t:       COUNT_TOGGLE    DIRTY,mp_next

    m_r:        RESET_COUNT     DIRTY,LOAD,pp_next,pm_next

dt_tp_dr_rpe_nh ENDP

ALIGN 16
dt_tm_dr_rpe_nh PROC            ;// see LEGEND (F12)

    ;// reset mp,mm
    ;// count pp,mp

                test ah, ah
                jns pos_r
        neg_r:  test al, al
                js  mm_top
                jmp mp_top
        pos_r:  test al, al
                js  pm_top
                jmp pp_top

;// PM
    pm_next:    NEXT_SAMPLE
    pm_top:     IF_EDGE         r,POS_NEG,mm_trig
    pm_trig:    IF_NOT_EDGE     t,NEG_POS,pm_next
;// PP
    pp_next:    NEXT_SAMPLE
    pp_top:     IF_EDGE         r,POS_NEG,mp_trig
    pp_trig:    IF_NOT_EDGE     t,POS_NEG,pp_next
                COUNT_TOGGLE    DIRTY,pm_next

;// MM
    mm_next:    NEXT_SAMPLE
    mm_top:     IF_EDGE         r,NEG_POS,m_r
    mm_trig:    IF_NOT_EDGE     t,NEG_POS,mm_next
;// MP
    mp_next:    NEXT_SAMPLE
    mp_top:     IF_EDGE         r,NEG_POS,m_r
    mp_trig:    IF_NOT_EDGE     t,POS_NEG,mp_next
                COUNT_TOGGLE    DIRTY,mm_next

    m_r:        RESET_COUNT     DIRTY,LOAD,pp_next,pm_next

dt_tm_dr_rpe_nh ENDP

ALIGN 16
dt_tp_dr_rme_nh PROC            ;// see LEGEND (F12)

    ;// reset pp pm
    ;// count mp mm

                test ah, ah
                jns pos_r
        neg_r:  test al, al
                js  mm_top
                jmp mp_top
        pos_r:  test al, al
                js  pm_top
                jmp pp_top

;// PP
    pp_next:    NEXT_SAMPLE
    pp_top:     IF_EDGE         r,POS_NEG,p_r
    pp_trig:    IF_NOT_EDGE     t,POS_NEG,pp_next
;// PM
    pm_next:    NEXT_SAMPLE
    pm_top:     IF_EDGE         r,POS_NEG,p_r
    pm_trig:    IF_NOT_EDGE     t,NEG_POS,pm_next
                COUNT_TOGGLE    DIRTY,pp_next

;// MP
    mp_next:    NEXT_SAMPLE
    mp_top:     IF_EDGE         r,NEG_POS,pp_trig
    mp_trig:    IF_NOT_EDGE     t,POS_NEG,mp_next
;// MM
    mm_next:    NEXT_SAMPLE
    mm_top:     IF_EDGE         r,NEG_POS,pm_trig
    mm_trig:    IF_NOT_EDGE     t,NEG_POS,mm_next
                COUNT_TOGGLE    DIRTY,mp_next

    p_r:        RESET_COUNT     DIRTY,LOAD,mp_next,mm_next

dt_tp_dr_rme_nh ENDP

ALIGN 16
dt_tb_dr_rpe_nh PROC        ;// see LEGEND (F12)

                test ah, ah
                js m_top
                jmp p_top

    m_r:        RESET_COUNT     DIRTY,LOAD
;// P-
    p_next:     NEXT_SAMPLE
    p_top:      IF_EDGE         r,POS_NEG,m_trig
    p_trig:     IF_NOT_EDGE     t,BOTH,p_next
                COUNT_TOGGLE    DIRTY,p_next
;// M-
    m_next:     NEXT_SAMPLE
    m_top:      IF_EDGE         r,NEG_POS,m_r
    m_trig:     IF_NOT_EDGE     t,BOTH,m_next
                COUNT_TOGGLE    DIRTY,m_next

dt_tb_dr_rpe_nh ENDP

ALIGN 16
dt_tb_dr_rme_nh PROC        ;// see LEGEND (F12)

                test ah, ah
                js m_top
                jmp p_top

    p_r:        RESET_COUNT     DIRTY,LOAD
;// M-
    m_next:     NEXT_SAMPLE
    m_top:      IF_EDGE         r,NEG_POS,p_trig
    m_trig:     IF_NOT_EDGE     t,BOTH,m_next
                COUNT_TOGGLE    DIRTY,m_next
;// P-
    p_next:     NEXT_SAMPLE
    p_top:      IF_EDGE         r,POS_NEG,p_r
    p_trig:     IF_NOT_EDGE     t,BOTH,p_next
                COUNT_TOGGLE    DIRTY,p_next

dt_tb_dr_rme_nh ENDP

ALIGN 16
dt_tp_dr_rbe_nh PROC        ;// see LEGEND (F12)

                test al, al
                js m_top
                jmp p_top

;// -P
    p_next:     NEXT_SAMPLE
    p_top:      IF_EDGE         r,BOTH,got_r
                IF_NOT_EDGE     t,POS_NEG,p_next
;// -M
    m_next:     NEXT_SAMPLE
    m_top:      IF_EDGE         r,BOTH,got_r
                IF_NOT_EDGE     t,NEG_POS,m_next
                COUNT_TOGGLE    DIRTY,p_next

    got_r:      RESET_COUNT     DIRTY,LOAD,p_next,m_next



dt_tp_dr_rbe_nh ENDP

ALIGN 16
dt_tm_dr_rbe_nh PROC        ;// see LEGEND (F12)

                test al, al
                js m_top
                jmp p_top

;// -M
    m_next:     NEXT_SAMPLE
    m_top:      IF_EDGE         r,BOTH,got_r
                IF_NOT_EDGE     t,NEG_POS,m_next
;// -P
    p_next:     NEXT_SAMPLE
    p_top:      IF_EDGE         r,BOTH,got_r
                IF_NOT_EDGE     t,POS_NEG,p_next
                COUNT_TOGGLE    DIRTY,m_next

    got_r:      RESET_COUNT     DIRTY,LOAD,p_next,m_next

dt_tm_dr_rbe_nh ENDP

ALIGN 16
dt_tb_dr_rpg_nh PROC ;// LEGEND (F12)

            test ah, ah
            js  m_top
            jmp p_top

;// P   in reset state
    p_top:  IF_LEVEL        r,NEG,test_t
            mov al, [ebx+ecx]   ;// load the edge so we keep track
    next_p: NEXT_SAMPLE p_top   ;// iterate to next sample
    got_r:  RESET_COUNT     DIRTY,LOAD,next_p   ;// do we want LOAD ??

;// M   counting edges
    m_top:  IF_LEVEL        r,POS,got_r
    test_t: IF_EDGE         t,BOTH,got_t
    next_s: NEXT_SAMPLE m_top
    got_t:  COUNT_TOGGLE    DIRTY,next_s

dt_tb_dr_rpg_nh ENDP

ALIGN 16
dt_tb_dr_rmg_nh PROC ;// LEGEND (F12)

            test ah, ah
            js  m_top
            jmp p_top

;// M   in reset state

    m_top:  IF_LEVEL        r,POS,test_t
            mov al, [ebx+ecx]   ;// load the edge so we keep track
    next_m: NEXT_SAMPLE m_top   ;// iterate to next sample
    got_r:  RESET_COUNT     DIRTY,LOAD,next_m   ;// do we want LOAD ??

;// P   counting edges

    p_top:  IF_LEVEL        r,NEG,got_r
    test_t: IF_EDGE         t,BOTH,got_t
    next_s: NEXT_SAMPLE p_top
    got_t:  COUNT_TOGGLE    DIRTY,next_s

dt_tb_dr_rmg_nh ENDP

ALIGN 16
dt_tp_dr_rpg_nh PROC ;// LEGEND (F12)

                test ah, ah
                jns p_top
                test al, al
                js mm_top
                jmp mp_top

;// P   in reset state

    p_top:      IF_LEVEL        r,NEG,test_t
                mov al, [ebx+ecx]                   ;// load the edge so we keep track
    next_p:     NEXT_SAMPLE     p_top               ;// iterate to next sample
    got_r:      RESET_COUNT     DIRTY,LOAD,next_p   ;// do we want LOAD ??

    test_t:     test al, al
                js test_tm
                jmp test_tp

;// MP  counting edges, al currently Positive

    next_sp:    NEXT_SAMPLE
    mp_top:     IF_LEVEL        r,POS,got_r
    test_tp:    IF_NOT_EDGE     t,POS_NEG,next_sp

;// MM  counting edges, al_currently Negative

    next_sm:    NEXT_SAMPLE
    mm_top:     IF_LEVEL        r,POS,got_r
    test_tm:    IF_NOT_EDGE     t,NEG_POS,next_sm
                COUNT_TOGGLE    DIRTY,next_sp

dt_tp_dr_rpg_nh ENDP

ALIGN 16
dt_tp_dr_rmg_nh PROC ;// LEGEND (F12)

                test ah, ah
                js m_top
                test al, al
                js pm_top
                jmp pp_top

;// P   in reset state

    m_top:      IF_LEVEL        r,POS,test_t
                mov al, [ebx+ecx]                   ;// load the edge so we keep track
    next_m:     NEXT_SAMPLE     m_top               ;// iterate to next sample
    got_r:      RESET_COUNT     DIRTY,LOAD,next_m   ;// do we want LOAD ??

    test_t:     test al, al
                js test_tm
                jmp test_tp

;// PP  counting edges, al currently Positive

    next_sp:    NEXT_SAMPLE
    pp_top:     IF_LEVEL        r,NEG,got_r
    test_tp:    IF_NOT_EDGE     t,POS_NEG,next_sp

;// PM  counting edges, al_currently Negative

    next_sm:    NEXT_SAMPLE
    pm_top:     IF_LEVEL        r,NEG,got_r
    test_tm:    IF_NOT_EDGE     t,NEG_POS,next_sm
                COUNT_TOGGLE    DIRTY,next_sp

dt_tp_dr_rmg_nh ENDP

ALIGN 16
dt_tm_dr_rpg_nh PROC ;// LEGEND (F12)

                test ah, ah
                jns p_top

                test al, al
                js mm_top
                jmp mp_top

;// P   in reset state

    p_top:      IF_LEVEL        r,NEG,test_t
                mov al, [ebx+ecx]                   ;// load the edge so we keep track
    next_p:     NEXT_SAMPLE     p_top               ;// iterate to next sample
    got_r:      RESET_COUNT     DIRTY,LOAD,next_p   ;// do we want LOAD ??

    test_t:     test al, al
                js test_tm
                jmp test_tp

;// MM  counting edges, al_currently Negative

    next_sm:    NEXT_SAMPLE
    mm_top:     IF_LEVEL        r,POS,got_r
    test_tm:    IF_NOT_EDGE     t,NEG_POS,next_sm

;// MP  counting edges, al currently Positive

    next_sp:    NEXT_SAMPLE
    mp_top:     IF_LEVEL        r,POS,got_r
    test_tp:    IF_NOT_EDGE     t,POS_NEG,next_sp

                COUNT_TOGGLE    DIRTY,next_sm

dt_tm_dr_rpg_nh ENDP

ALIGN 16
dt_tm_dr_rmg_nh PROC ;// LEGEND (F12)

                test ah, ah
                js m_top
                test al, al
                js pm_top
                jmp pp_top

;// P   in reset state

    m_top:      IF_LEVEL        r,POS,test_t
                mov al, [ebx+ecx]                   ;// load the edge so we keep track
    next_m:     NEXT_SAMPLE     m_top               ;// iterate to next sample
    got_r:      RESET_COUNT     DIRTY,LOAD,next_m   ;// do we want LOAD ??

    test_t:     test al, al
                js test_tm
                jmp test_tp

;// PM  counting edges, al_currently Negative

    next_sm:    NEXT_SAMPLE
    pm_top:     IF_LEVEL        r,NEG,got_r
    test_tm:    IF_NOT_EDGE     t,NEG_POS,next_sm

;// PP  counting edges, al currently Positive

    next_sp:    NEXT_SAMPLE
    pp_top:     IF_LEVEL        r,NEG,got_r
    test_tp:    IF_NOT_EDGE     t,POS_NEG,next_sp
                COUNT_TOGGLE    DIRTY,next_sm

dt_tm_dr_rmg_nh ENDP

;//
;//     dt dt loops for _nh modes
;//
;////////////////////////////////////////////////////






;///////////////////////////////////////////////////////
;//
;//     dt_sr loops for _nh modes
;//
;// 1) if reset on first sample
;//     --> process accordingly
;//     --> always load al so it can be ignored
;// 2) jump to dtsr_xxx

;// DTSR loops are put above the entrance points so the BT static prdeiction is hit more often

;// TB loop
ALIGN 16
dtsr_tb:            mov ah, [ebp]   ;// always load ah
dtsr_tb_top_of:     IF_EDGE         t,BOTH,dtsr_tb_got_t
dtsr_tb_next_s:     NEXT_SAMPLE     dtsr_tb_top_of
dtsr_tb_got_t:      COUNT_TOGGLE    DIRTY,dtsr_tb_next_s

ALIGN 16
reset_dtsr_tb:

    RESET_COUNT     NODIRTY,LOAD,dtsr_tb_next_s

;// tb entrance points

ALIGN 16
dt_tb_sr_rbe_nh::   IF_NOT_EDGE r0,BOTH,dtsr_tb
                    jmp reset_dtsr_tb
ALIGN 16
dt_tb_sr_rpe_nh::   test ah, ah
                    jns dtsr_tb
                    IF_NOT_EDGE r0,NEG_POS,dtsr_tb
                    jmp reset_dtsr_tb
ALIGN 16
dt_tb_sr_rme_nh::   test ah, ah
                    js dtsr_tb
                    IF_NOT_EDGE r0,POS_NEG,dtsr_tb
                    jmp reset_dtsr_tb
ALIGN 16
dt_tb_sr_rpg_nh::   mov ah, [ebp]
                    test ah, ah
                    jns stst_got_r
                    jmp dtsr_tb
ALIGN 16
dt_tb_sr_rmg_nh::   mov ah, [ebp]
                    test ah, ah
                    js stst_got_r
                    jmp dtsr_tb



;// TP loop
ALIGN 16
dtsr_tp:        mov ah, [ebp]   ;// always load ah
                test al, al
                jns dtsr_tp_p_top
                jmp dtsr_tp_m_top
;// P
dtsr_tp_p_next: NEXT_SAMPLE
dtsr_tp_p_top:  IF_NOT_EDGE     t,POS_NEG,dtsr_tp_p_next
;// M
dtsr_tp_m_next: NEXT_SAMPLE
dtsr_tp_m_top:  IF_NOT_EDGE     t,NEG_POS,dtsr_tp_m_next
                COUNT_TOGGLE    DIRTY,dtsr_tp_p_next

ALIGN 16
reset_dtsr_tp:

    RESET_COUNT     NODIRTY,LOAD,dtsr_tp_p_next,dtsr_tp_m_next

;// tp entrance points

ALIGN 16
dt_tp_sr_rbe_nh::   IF_NOT_EDGE     r0,BOTH,dtsr_tp
                    jmp reset_dtsr_tp
ALIGN 16
dt_tp_sr_rpe_nh::   test ah, ah
                    jns dtsr_tp
                    IF_NOT_EDGE     r0,NEG_POS, dtsr_tp
                    jmp reset_dtsr_tp
ALIGN 16
dt_tp_sr_rme_nh::   test ah, ah
                    js dtsr_tp
                    IF_NOT_EDGE     r0,POS_NEG,dtsr_tp
                    jmp reset_dtsr_tp
ALIGN 16
dt_tp_sr_rpg_nh::   mov ah, [ebp]
                    test ah, ah
                    jns stst_got_r
                    jmp dtsr_tp
ALIGN 16
dt_tp_sr_rmg_nh::   mov ah, [ebp]
                    test ah, ah
                    js stst_got_r
                    jmp dtsr_tp



;// TM loop
ALIGN 16
dtsr_tm:        mov ah, [ebp]   ;// always load ah
                test al, al
                js  dtsr_tm_m_top
                jmp dtsr_tm_p_top
;// M counting al is negative
dtsr_tm_m_next: NEXT_SAMPLE
dtsr_tm_m_top:  IF_NOT_EDGE     t,NEG_POS,dtsr_tm_m_next
;// P counting al is positive
dtsr_tm_p_next: NEXT_SAMPLE
dtsr_tm_p_top:  IF_NOT_EDGE     t,POS_NEG,dtsr_tm_p_next
                COUNT_TOGGLE    DIRTY,dtsr_tm_m_next

ALIGN 16
reset_dtsr_tm:

    RESET_COUNT NODIRTY,LOAD,dtsr_tm_p_next,dtsr_tm_m_next

;// tm entrance points
ALIGN 16
dt_tm_sr_rme_nh::   test ah, ah
                    js dtsr_tm
                    IF_NOT_EDGE r0,POS_NEG,dtsr_tm
                    jmp reset_dtsr_tm
ALIGN 16
dt_tm_sr_rbe_nh::   IF_NOT_EDGE r0,BOTH,dtsr_tm
                    jmp reset_dtsr_tm
ALIGN 16
dt_tm_sr_rpe_nh::   test ah, ah
                    jns dtsr_tm
                    IF_NOT_EDGE r0,NEG_POS,dtsr_tm
                    jmp reset_dtsr_tm
ALIGN 16
dt_tm_sr_rpg_nh::   mov ah, [ebp]
                    test ah, ah
                    jns stst_got_r
                    jmp dtsr_tm
ALIGN 16
dt_tm_sr_rmg_nh::   mov ah, [ebp]
                    test ah, ah
                    js stst_got_r
                    jmp dtsr_tm





;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////




;////////////////////////////////////////////////////
;//
;//     dt dt loops for _yh modes
;//

ALIGN 16
dt_tb_dr_rbe_yh PROC            ;// see LEGEND (F12)

;// if we are waiting, then enter a wait_for_reset loop
;// this is much like gate mode

                test dh, dh
                js wait_r

;// in a count state

    top_of:     IF_EDGE         r, BOTH, got_r
                IF_EDGE         t, BOTH, got_t
    next_s:     NEXT_SAMPLE     top_of

    got_t:      COUNT_WAIT      DIRTY,next_s

;// in a wait state

    next_w:     NEXT_SAMPLE
    wait_r:     mov al, [ebx+ecx]
                IF_NOT_EDGE     r,BOTH, next_w

    got_r:      RESET_COUNT     DIRTY,LOAD,next_s

dt_tb_dr_rbe_yh ENDP

ALIGN 16
dt_tb_dr_rpe_yh PROC        ;// see LEGEND (F12)

;// to do this, we need a dual pair of loops

                test dh, dh
                js wait_r

;// in a count state
    count_t:    test ah,ah
                js test_cm
                jmp test_cp
    ;// count P ah is positive
    next_cp:    NEXT_SAMPLE
    test_cp:    IF_EDGE         r,POS_NEG, test_tm
    test_tp:    IF_NOT_EDGE     t,BOTH, next_cp
                COUNT_WAIT      DIRTY,next_cp,test_wp
    ;// count M ah is negative
    next_cm:    NEXT_SAMPLE
    test_cm:    IF_EDGE         r,NEG_POS, got_r
    test_tm:    IF_NOT_EDGE     t,BOTH, next_cm
                COUNT_WAIT      DIRTY,next_cm,test_wm
;// in a wait state
    wait_r:     test ah, ah
                js test_wm
                jmp test_wp
    ;// wait P  ah is postive
    next_wp:    NEXT_SAMPLE
    test_wp:    IF_NOT_EDGE     r,POS_NEG,next_wp
    ;// wait M  ah is eagative
    next_wm:    NEXT_SAMPLE
    test_wm:    IF_NOT_EDGE     r,NEG_POS,next_wm
;// got reset
    got_r:      RESET_COUNT     DIRTY,LOAD
                test ah, ah
                js next_cm
                jmp next_cp


dt_tb_dr_rpe_yh ENDP

ALIGN 16
dt_tb_dr_rme_yh PROC        ;// see LEGEND (F12)

;// to do this, we need a dual pair of loops

                test dh, dh
                js wait_r

;// in a count state
    count_t:    test ah,ah
                js test_cm
                jmp test_cp
    ;// count M ah is negative
    next_cm:    NEXT_SAMPLE
    test_cm:    IF_EDGE         r,NEG_POS, test_tp
    test_tm:    IF_NOT_EDGE     t,BOTH, next_cm
                COUNT_WAIT      DIRTY,next_cm,test_wm
    ;// count P ah is positive
    next_cp:    NEXT_SAMPLE
    test_cp:    IF_EDGE         r,POS_NEG, got_r
    test_tp:    IF_NOT_EDGE     t,BOTH, next_cp
                COUNT_WAIT      DIRTY,next_cp,test_wp
;// in a wait state
    wait_r:     test ah, ah
                js test_wm
                jmp test_wp
    ;// wait M  ah is eagative
    next_wm:    NEXT_SAMPLE
    test_wm:    IF_NOT_EDGE     r,NEG_POS,next_wm
    ;// wait P  ah is postive
    next_wp:    NEXT_SAMPLE
    test_wp:    IF_NOT_EDGE     r,POS_NEG,next_wp
;// got reset
    got_r:      RESET_COUNT     DIRTY,LOAD
                test ah, ah
                js next_cm
                jmp next_cp


dt_tb_dr_rme_yh ENDP

ALIGN 16
dt_tp_dr_rbe_yh PROC        ;// see LEGEND (F12)

                    test dh, dh
                    js test_w
;// in a count state
                    test al, al
                    js test_cm
                    jmp test_cp
    ;// CP count edge al is positive
        next_cp:    NEXT_SAMPLE
        test_cp:    IF_EDGE         r,BOTH, got_r
                    IF_NOT_EDGE     t,POS_NEG,next_cp
    ;// CM count edge al is negative
        next_cm:    NEXT_SAMPLE
        test_cm:    IF_EDGE         r,BOTH, got_r
                    IF_NOT_EDGE     t,NEG_POS,next_cm
                    COUNT_WAIT      DIRTY,next_cp
                    ;// now in a wait state
;// in a wait state
        next_w:     NEXT_SAMPLE
        test_w:     mov al, [ebx+ecx]
                    IF_NOT_EDGE     r,BOTH,next_w
                    ;// got reset
        got_r:      RESET_COUNT     DIRTY,LOAD
;// leaving wait state
                    test al,al
                    js next_cm
                    jmp next_cp

dt_tp_dr_rbe_yh ENDP

ALIGN 16
dt_tm_dr_rbe_yh PROC        ;// see LEGEND (F12)

                    test dh, dh
                    js test_w
;// into a count state
                    test al, al
                    js test_cm
                    jmp test_cp
    ;// CM count edge al is negative
        next_cm:    NEXT_SAMPLE
        test_cm:    IF_EDGE         r,BOTH, got_r
                    IF_NOT_EDGE     t,NEG_POS,next_cm
    ;// CP count edge al is positive
        next_cp:    NEXT_SAMPLE
        test_cp:    IF_EDGE         r,BOTH, got_r
                    IF_NOT_EDGE     t,POS_NEG,next_cp
                    COUNT_WAIT      DIRTY,next_cm
                    ;// now in a wait state
;// in a wait state
        next_w:     NEXT_SAMPLE
        test_w:     mov al, [ebx+ecx]
                    IF_NOT_EDGE     r,BOTH,next_w
                    ;// got reset
        got_r:      RESET_COUNT     DIRTY,LOAD
;// leaving wait state
                    test al,al
                    js next_cm
                    jmp next_cp


dt_tm_dr_rbe_yh ENDP

ALIGN 16
dt_tp_dr_rpe_yh PROC            ;// see LEGEND (F12)

;// this requires a total of 6 loops

                    test ah, ah
                    .IF SIGN?
                    test dh, dh
                    js test_wm
                    test al,al
                    js   tr_cmm
                    jmp  tr_cmp
                    .ENDIF
                    test dh, dh
                    js test_wp
                    test al, al
                    js   tr_cpm
                    jmp  tr_cpp

;// in a count state

    ;// CPP counting ah is pos al is pos

        next_cpp:   NEXT_SAMPLE
        tr_cpp:     IF_EDGE         r,POS_NEG,test_cmp
                    IF_NOT_EDGE     t,POS_NEG,next_cpp

    ;// CPM counting ah is pos al is neg

        next_cpm:   NEXT_SAMPLE
        tr_cpm:     IF_EDGE         r,POS_NEG,test_cmm
                    IF_NOT_EDGE     t,NEG_POS,next_cpm
            ;// got a count
                    COUNT_WAIT      DIRTY,next_cpp,next_wp

    ;// CMP counting ah is neg al is pos

        next_cmp:   NEXT_SAMPLE
        tr_cmp:     IF_EDGE         r,NEG_POS,got_r
        test_cmp:   IF_NOT_EDGE     t,POS_NEG,next_cmp

    ;// CMM counting ah is neg al is neg

        next_cmm:   NEXT_SAMPLE
        tr_cmm:     IF_EDGE         r,NEG_POS,got_r
        test_cmm:   IF_NOT_EDGE     t,NEG_POS,next_cmm
            ;// got a count
                    COUNT_WAIT      DIRTY,next_cmp,next_wm

;// in a wait state

    ;// WP  waiting ah is positive

        next_wp:    NEXT_SAMPLE
        test_wp:    mov al, [ebx+ecx]
                    IF_NOT_EDGE     r,POS_NEG,next_wp

    ;// WM  waiting ah is negative

        next_wm:    NEXT_SAMPLE
        test_wm:    mov al, [ebx+ecx]
                    IF_NOT_EDGE     r,NEG_POS,next_wm

    ;// got reset

        got_r:      RESET_COUNT     DIRTY,LOAD

                    test ah, ah
                    .IF SIGN?
                    test al, al
                    js   next_cmm
                    jmp  next_cmp
                    .ENDIF
                    test al, al
                    js   next_cpm
                    jmp  next_cpp

dt_tp_dr_rpe_yh ENDP

ALIGN 16
dt_tp_dr_rme_yh PROC            ;// see LEGEND (F12)

;// this requires a total of 6 loops

                    test ah, ah
                    .IF SIGN?
                    test dh, dh
                    js test_wm
                    test al,al
                    js   tr_cmm
                    jmp  tr_cmp
                    .ENDIF
                    test dh, dh
                    js test_wp
                    test al, al
                    js   tr_cpm
                    jmp  tr_cpp

;// in a count state

    ;// CPP counting ah is pos al is pos
        next_cpp:   NEXT_SAMPLE
        tr_cpp:     IF_EDGE         r,POS_NEG,got_r
        test_cpp:   IF_NOT_EDGE     t,POS_NEG,next_cpp
    ;// CPM counting ah is pos al is neg
        next_cpm:   NEXT_SAMPLE
        tr_cpm:     IF_EDGE         r,POS_NEG,got_r
        test_cpm:   IF_NOT_EDGE     t,NEG_POS,next_cpm
            ;// got a count
                    COUNT_WAIT      DIRTY,next_cpp,next_wp

    ;// CMP counting ah is neg al is pos
        next_cmp:   NEXT_SAMPLE
        tr_cmp:     IF_EDGE         r,NEG_POS,test_cpp
                    IF_NOT_EDGE     t,POS_NEG,next_cmp
    ;// CMM counting ah is neg al is neg
        next_cmm:   NEXT_SAMPLE
        tr_cmm:     IF_EDGE         r,NEG_POS,test_cpm
                    IF_NOT_EDGE     t,NEG_POS,next_cmm
            ;// got a count
                    COUNT_WAIT      DIRTY,next_cmp,next_wm

;// in a wait state

    ;// WM  waiting ah is negative
        next_wm:    NEXT_SAMPLE
        test_wm:    mov al, [ebx+ecx]
                    IF_NOT_EDGE     r,NEG_POS,next_wm
    ;// WP  waiting ah is positive
        next_wp:    NEXT_SAMPLE
        test_wp:    mov al, [ebx+ecx]
                    IF_NOT_EDGE     r,POS_NEG,next_wp
    ;// got reset

        got_r:      RESET_COUNT     DIRTY,LOAD

                    test ah, ah
                    .IF SIGN?
                    test al, al
                    js   next_cmm
                    jmp  next_cmp
                    .ENDIF
                    test al, al
                    js   next_cpm
                    jmp  next_cpp

dt_tp_dr_rme_yh ENDP

ALIGN 16
dt_tm_dr_rpe_yh PROC            ;// see LEGEND (F12)

;// this requires a total of 6 loops

                    test ah, ah
                    .IF SIGN?
                    test dh, dh
                    js test_wm
                    test al,al
                    js   tr_cmm
                    jmp  tr_cmp
                    .ENDIF
                    test dh, dh
                    js test_wp
                    test al, al
                    js   tr_cpm
                    jmp  tr_cpp

;// in a count state

    ;// CPM counting ah is pos al is neg
        next_cpm:   NEXT_SAMPLE
        tr_cpm:     IF_EDGE         r,POS_NEG,test_cmm
                    IF_NOT_EDGE     t,NEG_POS,next_cpm
    ;// CPP counting ah is pos al is pos
        next_cpp:   NEXT_SAMPLE
        tr_cpp:     IF_EDGE         r,POS_NEG,test_cmp
                    IF_NOT_EDGE     t,POS_NEG,next_cpp
            ;// got a count
                    COUNT_WAIT      DIRTY,next_cpm,next_wp

    ;// CMM counting ah is neg al is neg
        next_cmm:   NEXT_SAMPLE
        tr_cmm:     IF_EDGE         r,NEG_POS,got_r
        test_cmm:   IF_NOT_EDGE     t,NEG_POS,next_cmm
    ;// CMP counting ah is neg al is pos
        next_cmp:   NEXT_SAMPLE
        tr_cmp:     IF_EDGE         r,NEG_POS,got_r
        test_cmp:   IF_NOT_EDGE     t,POS_NEG,next_cmp
            ;// got a count
                    COUNT_WAIT      DIRTY,next_cmm,next_wm

;// in a wait state

    ;// WP  waiting ah is positive
        next_wp:    NEXT_SAMPLE
        test_wp:    mov al, [ebx+ecx]
                    IF_NOT_EDGE     r,POS_NEG,next_wp
    ;// WM  waiting ah is negative
        next_wm:    NEXT_SAMPLE
        test_wm:    mov al, [ebx+ecx]
                    IF_NOT_EDGE     r,NEG_POS,next_wm
    ;// got reset
        got_r:      RESET_COUNT     DIRTY,LOAD
    ;// leave wait state
                    test ah, ah
                    .IF SIGN?
                    test al, al
                    js   next_cmm
                    jmp  next_cmp
                    .ENDIF
                    test al, al
                    js   next_cpm
                    jmp  next_cpp

dt_tm_dr_rpe_yh ENDP

ALIGN 16
dt_tm_dr_rme_yh PROC            ;// see LEGEND (F12)

;// this requires a total of 6 loops

                    test ah, ah
                    .IF SIGN?
                    test dh, dh
                    js test_wm
                    test al,al
                    js   tr_cmm
                    jmp  tr_cmp
                    .ENDIF
                    test dh, dh
                    js test_wp
                    test al, al
                    js   tr_cpm
                    jmp  tr_cpp

;// in a count state

    ;// CPM counting ah is pos al is neg
        next_cpm:   NEXT_SAMPLE
        tr_cpm:     IF_EDGE         r,POS_NEG,got_r
        test_cpm:   IF_NOT_EDGE     t,NEG_POS,next_cpm
    ;// CPP counting ah is pos al is pos
        next_cpp:   NEXT_SAMPLE
        tr_cpp:     IF_EDGE         r,POS_NEG,got_r
        test_cpp:   IF_NOT_EDGE     t,POS_NEG,next_cpp
            ;// got a count
                    COUNT_WAIT      DIRTY,next_cpm,next_wp

    ;// CMM counting ah is neg al is neg
        next_cmm:   NEXT_SAMPLE
        tr_cmm:     IF_EDGE         r,NEG_POS,test_cpm
                    IF_NOT_EDGE     t,NEG_POS,next_cmm
    ;// CMP counting ah is neg al is pos
        next_cmp:   NEXT_SAMPLE
        tr_cmp:     IF_EDGE         r,NEG_POS,test_cpp
                    IF_NOT_EDGE     t,POS_NEG,next_cmp
            ;// got a count
                    COUNT_WAIT      DIRTY,next_cmm,next_wm

;// in a wait state

    ;// WM  waiting ah is negative
        next_wm:    NEXT_SAMPLE
        test_wm:    mov al, [ebx+ecx]
                    IF_NOT_EDGE     r,NEG_POS,next_wm
    ;// WP  waiting ah is positive
        next_wp:    NEXT_SAMPLE
        test_wp:    mov al, [ebx+ecx]
                    IF_NOT_EDGE     r,POS_NEG,next_wp
    ;// got reset
        got_r:      RESET_COUNT     DIRTY,LOAD
    ;// leave wait state
                    test ah, ah
                    .IF SIGN?
                    test al, al
                    js   next_cmm
                    jmp  next_cmp
                    .ENDIF
                    test al, al
                    js   next_cpm
                    jmp  next_cpp

dt_tm_dr_rme_yh ENDP

ALIGN 16
dt_tb_dr_rpg_yh PROC ;// LEGEND (F12)

                test dh, dh
                js w_top
                test ah, ah
                js  m_top
                jmp p_top

;// P   in reset state
    p_top:      IF_LEVEL        r,NEG,test_t
                mov al, [ebx+ecx]                   ;// load the edge so we keep track
    next_p:     NEXT_SAMPLE     p_top               ;// iterate to next sample
    got_r:      RESET_COUNT     DIRTY,LOAD,next_p   ;// do we want LOAD ??
;// M   counting edges
    m_top:      IF_LEVEL        r,POS,got_r
    test_t:     IF_EDGE         t,BOTH,got_t
    next_s:     NEXT_SAMPLE     m_top
    got_t:      COUNT_WAIT      DIRTY,next_s,next_w
;// W   wait for resest
    w_top:      IF_LEVEL        r,POS,got_r
                mov al, [ebx+ecx]                   ;// keep track
    next_w:     NEXT_SAMPLE     w_top

dt_tb_dr_rpg_yh ENDP

ALIGN 16
dt_tb_dr_rmg_yh PROC ;// LEGEND (F12)

                test dh, dh
                js w_top
                test ah, ah
                js  m_top
                jmp p_top

;// M   in reset state
    m_top:      IF_LEVEL        r,POS,test_t
                mov al, [ebx+ecx]                   ;// load the edge so we keep track
    next_m:     NEXT_SAMPLE     m_top               ;// iterate to next sample
    got_r:      RESET_COUNT     DIRTY,LOAD,next_m   ;// do we want LOAD ??
;// P   counting edges
    p_top:      IF_LEVEL        r,NEG,got_r
    test_t:     IF_EDGE         t,BOTH,got_t
    next_s:     NEXT_SAMPLE     p_top
    got_t:      COUNT_WAIT      DIRTY,next_s,next_w
;// W   wait for resest
    w_top:      IF_LEVEL        r,NEG,got_r
                mov al, [ebx+ecx]                   ;// keep track
    next_w:     NEXT_SAMPLE     w_top

dt_tb_dr_rmg_yh ENDP

ALIGN 16
dt_tp_dr_rpg_yh PROC ;// LEGEND (F12)

                test ah, ah     ;// reset now ?
                jns p_top

                test dh, dh     ;// waiting now ?
                js w_top

                test al, al     ;// counting now
                js mm_top
                jmp mp_top

;// P   in reset state
    p_top:      IF_LEVEL        r,NEG,test_t
                mov al, [ebx+ecx]                   ;// load the edge so we keep track
    next_p:     NEXT_SAMPLE     p_top               ;// iterate to next sample
    got_r:      RESET_COUNT     DIRTY,LOAD,next_p   ;// do we want LOAD ??
;// leave reset or wait state
    test_t:     test al, al
                js test_tm
                jmp test_tp
;// MP  counting edges, al currently Positive
    next_sp:    NEXT_SAMPLE
    mp_top:     IF_LEVEL        r,POS,got_r
    test_tp:    IF_NOT_EDGE     t,POS_NEG,next_sp
;// MM  counting edges, al_currently Negative
    next_sm:    NEXT_SAMPLE
    mm_top:     IF_LEVEL        r,POS,got_r
    test_tm:    IF_NOT_EDGE     t,NEG_POS,next_sm
                COUNT_WAIT      DIRTY,next_sp
;// W   waiting ah is negative
    w_top:      IF_LEVEL        r,POS,got_r
                mov al, [ebx+ecx]
                NEXT_SAMPLE     w_top

dt_tp_dr_rpg_yh ENDP

ALIGN 16
dt_tp_dr_rmg_yh PROC ;// LEGEND (F12)

                test ah, ah     ;// reset now ?
                js m_top

                test dh, dh     ;// waiting now ?
                js w_top

                test al, al     ;// counting now
                js mm_top
                jmp mp_top

;// M   in reset state
    m_top:      IF_LEVEL        r,POS,test_t
                mov al, [ebx+ecx]                   ;// load the edge so we keep track
    next_m:     NEXT_SAMPLE     m_top               ;// iterate to next sample
    got_r:      RESET_COUNT     DIRTY,LOAD,next_m   ;// do we want LOAD ??
;// leave reset or wait state
    test_t:     test al, al
                js test_tm
                jmp test_tp
;// PP  counting edges, ah is positive al currently Positive
    next_sp:    NEXT_SAMPLE
    mp_top:     IF_LEVEL        r,NEG,got_r
    test_tp:    IF_NOT_EDGE     t,POS_NEG,next_sp
;// PM  counting edges, ah is positive al_currently Negative
    next_sm:    NEXT_SAMPLE
    mm_top:     IF_LEVEL        r,NEG,got_r
    test_tm:    IF_NOT_EDGE     t,NEG_POS,next_sm
                COUNT_WAIT      DIRTY,next_sp
;// W   waiting ah is positive
    w_top:      IF_LEVEL        r,NEG,got_r
                mov al, [ebx+ecx]
                NEXT_SAMPLE     w_top

dt_tp_dr_rmg_yh ENDP

ALIGN 16
dt_tm_dr_rpg_yh PROC ;// LEGEND (F12)

                test ah, ah     ;// reset now ?
                jns p_top

                test dh, dh     ;// waiting now ?
                js w_top

                test al, al     ;// counting now
                js mm_top
                jmp mp_top

;// P   in reset state
    p_top:      IF_LEVEL        r,NEG,test_t
                mov al, [ebx+ecx]                   ;// load the edge so we keep track
    next_p:     NEXT_SAMPLE     p_top               ;// iterate to next sample
    got_r:      RESET_COUNT     DIRTY,LOAD,next_p   ;// do we want LOAD ??
;// leave reset or wait state
    test_t:     test al, al
                js test_tm
                jmp test_tp
;// MM  counting edges, al_currently Negative
    next_sm:    NEXT_SAMPLE
    mm_top:     IF_LEVEL        r,POS,got_r
    test_tm:    IF_NOT_EDGE     t,NEG_POS,next_sm
;// MP  counting edges, al currently Positive
    next_sp:    NEXT_SAMPLE
    mp_top:     IF_LEVEL        r,POS,got_r
    test_tp:    IF_NOT_EDGE     t,POS_NEG,next_sp
                COUNT_WAIT      DIRTY,next_sm
;// W   waiting ah is negative
    w_top:      IF_LEVEL        r,POS,got_r
                mov al, [ebx+ecx]
                NEXT_SAMPLE     w_top

dt_tm_dr_rpg_yh ENDP

ALIGN 16
dt_tm_dr_rmg_yh PROC ;// LEGEND (F12)

                test ah, ah     ;// reset now ?
                js m_top

                test dh, dh     ;// waiting now ?
                js w_top

                test al, al     ;// counting now
                js mm_top
                jmp mp_top

;// M   in reset state
    m_top:      IF_LEVEL        r,POS,test_t
                mov al, [ebx+ecx]                   ;// load the edge so we keep track
    next_m:     NEXT_SAMPLE     m_top               ;// iterate to next sample
    got_r:      RESET_COUNT     DIRTY,LOAD,next_m   ;// do we want LOAD ??
;// leave reset or wait state
    test_t:     test al, al
                js test_tm
                jmp test_tp
;// PM  counting edges, ah is positive al_currently Negative
    next_sm:    NEXT_SAMPLE
    mm_top:     IF_LEVEL        r,NEG,got_r
    test_tm:    IF_NOT_EDGE     t,NEG_POS,next_sm
;// PP  counting edges, ah is positive al currently Positive
    next_sp:    NEXT_SAMPLE
    mp_top:     IF_LEVEL        r,NEG,got_r
    test_tp:    IF_NOT_EDGE     t,POS_NEG,next_sp
                COUNT_WAIT      DIRTY,next_sm
;// W   waiting ah is positive
    w_top:      IF_LEVEL        r,NEG,got_r
                mov al, [ebx+ecx]
                NEXT_SAMPLE     w_top

dt_tm_dr_rmg_yh ENDP

;//
;//     dt dt loops for _yh modes
;//
;////////////////////////////////////////////////////



;////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////
;///
;///    DTSR loops for _yh modes
;///
;// once we enter a wait state
;// there is no way to get out because r is static
;//
;// 1) check for reset  --> edge enter loop if hit, gate exit to store static
;// 2) check if waiting --> exit to store static
;// 3) count, exit to fill remaining if count is hit

ALIGN 16
dtsr_yh_tb: mov ah, [ebp]   ;// load this just to be sure
            test dh, dh     ;// already waiting ?
            js store_static
yh_tb_top:  IF_EDGE         t,BOTH,yh_tb_got
yh_tb_next: NEXT_SAMPLE     yh_tb_top
yh_tb_got:  COUNT_WAIT      DIRTY,yh_tb_next,fill_remaining_now

ALIGN 16
reset_dtsr_yh_tb:

        RESET_COUNT     NODIRTY,LOAD,yh_tb_next

ALIGN 16
dt_tb_sr_rbe_yh::   IF_NOT_EDGE r0,BOTH,dtsr_yh_tb
                    jmp reset_dtsr_yh_tb
ALIGN 16
dt_tb_sr_rpe_yh:    test ah, ah
                    jns dtsr_yh_tb
                    IF_NOT_EDGE r0,NEG_POS,dtsr_yh_tb
                    jmp reset_dtsr_yh_tb
ALIGN 16
dt_tb_sr_rme_yh:    test ah, ah
                    js dtsr_yh_tb
                    IF_NOT_EDGE r0,POS_NEG,dtsr_yh_tb
                    jmp reset_dtsr_yh_tb
ALIGN 16
dt_tb_sr_rpg_yh:    mov ah, [ebp]
                    test ah, ah
                    jns stst_got_r
                    jmp dtsr_yh_tb
ALIGN 16
dt_tb_sr_rmg_yh:    mov ah, [ebp]
                    test ah, ah
                    js stst_got_r
                    jmp dtsr_yh_tb

;/////////////////////////////////////

ALIGN 16
dtsr_yh_tp:         test dh, dh
                    js   store_static
                    ;// enter the count loop
                    test al, al
                    js   dtsr_yh_tp_test_tm
                    jmp  dtsr_yh_tp_test_tp
;// CP counting al is positive
dtsr_yh_tp_next_tp: NEXT_SAMPLE
dtsr_yh_tp_test_tp: IF_NOT_EDGE     t,POS_NEG, dtsr_yh_tp_next_tp
;// CM counting al is negitive
dtsr_yh_tp_next_tm: NEXT_SAMPLE
dtsr_yh_tp_test_tm: IF_NOT_EDGE     t,NEG_POS, dtsr_yh_tp_next_tm
                    COUNT_WAIT      DIRTY,dtsr_yh_tp_next_tp,fill_remaining_now
ALIGN 16
reset_dtsr_yh_tp:

    RESET_COUNT NODIRTY,LOAD,dtsr_yh_tp_next_tp,dtsr_yh_tp_next_tm

ALIGN 16
dt_tp_sr_rbe_yh:    IF_NOT_EDGE     r0,BOTH,dtsr_yh_tp
                    jmp reset_dtsr_yh_tp
ALIGN 16
dt_tp_sr_rpe_yh:    test ah, ah
                    jns dtsr_yh_tp
                    IF_NOT_EDGE r0,NEG_POS,dtsr_yh_tp
                    jmp reset_dtsr_yh_tp
ALIGN 16
dt_tp_sr_rme_yh:    test ah, ah
                    js dtsr_yh_tp
                    IF_NOT_EDGE     r0,POS_NEG,dtsr_yh_tp
                    jmp reset_dtsr_yh_tp
ALIGN 16
dt_tp_sr_rpg_yh:    mov ah, [ebp]
                    test ah, ah
                    jns stst_got_r
                    jmp dtsr_yh_tp
ALIGN 16
dt_tp_sr_rmg_yh:    mov ah, [ebp]
                    test ah, ah
                    js stst_got_r
                    jmp dtsr_yh_tp

;/////////////////////////////////////

ALIGN 16
dtsr_yh_tm:         test dh, dh     ;// are we waiting now ?
                    js   store_static   ;// if yes, then there's nothing to do
                    ;// enter the count loop
                    test al, al
                    js   dtsr_yh_tm_test_tm
                    jmp  dtsr_yh_tm_test_tp
;// CM counting al is negitive
dtsr_yh_tm_next_tm: NEXT_SAMPLE
dtsr_yh_tm_test_tm: IF_NOT_EDGE     t,NEG_POS, dtsr_yh_tm_next_tm
;// CP counting al is positive
dtsr_yh_tm_next_tp: NEXT_SAMPLE
dtsr_yh_tm_test_tp: IF_NOT_EDGE     t,POS_NEG, dtsr_yh_tm_next_tp
                    COUNT_WAIT      DIRTY,dtsr_yh_tm_next_tm,fill_remaining_now
ALIGN 16
reset_dtsr_yh_tm:

    RESET_COUNT     NODIRTY,LOAD,dtsr_yh_tm_next_tp,dtsr_yh_tm_next_tm

ALIGN 16
dt_tm_sr_rbe_yh:    IF_NOT_EDGE     r0,BOTH,dtsr_yh_tm
                    jmp reset_dtsr_yh_tm
ALIGN 16
dt_tm_sr_rpe_yh:    test ah, ah
                    jns dtsr_yh_tm
                    IF_NOT_EDGE     r0,NEG_POS,dtsr_yh_tm
                    jmp reset_dtsr_yh_tm
ALIGN 16
dt_tm_sr_rme_yh:    test ah, ah
                    js dtsr_yh_tm
                    IF_NOT_EDGE     r0,POS_NEG,dtsr_yh_tm
                    jmp reset_dtsr_yh_tm
ALIGN 16
dt_tm_sr_rpg_yh:    mov ah, [ebp]
                    test ah, ah
                    jns stst_got_r
                    jmp dtsr_yh_tm
ALIGN 16
dt_tm_sr_rmg_yh:    mov ah, [ebp]
                    test ah, ah
                    js stst_got_r
                    jmp dtsr_yh_tm



;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
;///
;///    STORE STATIC
;///
;///        all of these node exit to store static
;///        we put them here to use common functionality
;///
;///

ALIGN 16
store_static::

    ;// esi     osc
    ;// ecx     zero
    ;// ah:al   reset:trigger edge
    ;// ebp:ebx reset:trigger
    ;// dh:dl   current_count:default_count
    ;// edi     sign:changing
    ;// fpu     state1  state2

        mov al, [ebx]
        mov ah, [ebp]

        fst [esi].data_x        ;// store the value we want
        test [esi].pin_x.dwStatus, PIN_CHANGING ;// see if changing last frame
        mov ecx, [esi].data_x   ;// load the value we just stored
        jnz have_to_fill        ;// if changing last frame, then have to fill
        cmp ecx, [esi].data_x[4];// is this value the same as last frame ?
        je calc_done            ;// way to split if nothing to do

    have_to_fill:

        mov ebx, eax            ;// must store the last triggers
        lea edi, [esi].data_x   ;// point at where to store
        mov eax, ecx            ;// load the value to store
        mov ecx, SAMARY_LENGTH  ;// set the count
        rep stosd               ;// fill
        mov eax, ebx            ;// retrieve the last triggers
        mov edi, ecx            ;// set the changing flags with zero
        jmp calc_done           ;// jump to exit





;/////////////////////////////////////////////////////////////////
;//
;//     nh  STORE STATIC        ;// LEGEND (F12)
;//
;// 1) check for reset on first sample
;// 2) exit to edge test for first sample
;//
ALIGN 16
stst_test_t_both:

        IF_NOT_EDGE     t0,BOTH,store_static
        COUNT_TOGGLE    NODIRTY,store_static

ALIGN 16
st_tb_sr_rbe_nh::   IF_EDGE     r0, BOTH, stst_got_r
                    jmp stst_test_t_both
ALIGN 16
st_tb_sr_rpe_nh::   test ah, ah
                    jns stst_test_t_both
                    IF_EDGE     r0,NEG_POS,stst_got_r
                    jmp stst_test_t_both
ALIGN 16
st_tb_sr_rme_nh::   test ah, ah
                    js stst_test_t_both
                    IF_EDGE     r0,POS_NEG,stst_got_r
                    jmp stst_test_t_both
ALIGN 16
st_tb_sr_rpg_nh::   mov ah, [ebp]
                    test ah, ah
                    jns stst_got_r
                    jmp stst_test_t_both
ALIGN 16
st_tb_sr_rmg_nh::   mov ah, [ebp]
                    test ah, ah
                    js stst_got_r
                    jmp stst_test_t_both

;//////////////////////////////////////////////
ALIGN 16
stst_test_t_neg_pos:

        test al, al
        jns store_static
        IF_NOT_EDGE     t0,NEG_POS,store_static
        COUNT_TOGGLE    NODIRTY,store_static

ALIGN 16
st_tp_sr_rbe_nh::   IF_EDGE r0,BOTH,stst_got_r
                    jmp stst_test_t_neg_pos
ALIGN 16
st_tp_sr_rpe_nh::   test ah, ah
                    jns stst_test_t_neg_pos
                    IF_EDGE r0,NEG_POS,stst_got_r
                    jmp stst_test_t_neg_pos
ALIGN 16
st_tp_sr_rme_nh::   test ah, ah
                    js stst_test_t_neg_pos
                    IF_EDGE     r0, POS_NEG, stst_got_r
                    jmp stst_test_t_neg_pos
ALIGN 16
st_tp_sr_rpg_nh::   mov ah, [ebp]
                    test ah, ah
                    jns stst_got_r
                    jmp stst_test_t_neg_pos

ALIGN 16
st_tp_sr_rmg_nh::   mov ah, [ebp]
                    test ah, ah
                    js stst_got_r
                    jmp stst_test_t_neg_pos

;//////////////////////////////////////////////
ALIGN 16
stst_test_t_pos_neg:

        test al, al
        js store_static
        IF_NOT_EDGE     t0,POS_NEG,store_static
        COUNT_TOGGLE    NODIRTY,store_static

ALIGN 16
st_tm_sr_rbe_nh::   IF_EDGE r0,BOTH,stst_got_r
                    jmp stst_test_t_pos_neg
ALIGN 16
st_tm_sr_rpe_nh::   test ah, ah
                    jns stst_test_t_pos_neg
                    IF_EDGE r0,NEG_POS,stst_got_r
                    jmp stst_test_t_pos_neg
ALIGN 16
st_tm_sr_rme_nh::   test ah, ah
                    js stst_test_t_pos_neg
                    IF_EDGE r0,POS_NEG,stst_got_r
                    jmp stst_test_t_pos_neg
ALIGN 16
st_tm_sr_rpg_nh::   mov ah, [ebp]
                    test ah, ah
                    jns stst_got_r
                    jmp stst_test_t_pos_neg
ALIGN 16
st_tm_sr_rmg_nh::   mov ah, [ebp]
                    test ah, ah
                    js stst_got_r
                    jmp stst_test_t_pos_neg

;//     nh  STORE STATIC        ;// LEGEND (F12)
;//
;/////////////////////////////////////////////////////////////////

;/////////////////////////////////////////////////////////////////
;//
;//     yh  STORE STATIC        ;// LEGEND (F12)
;//
;// 1) reset on first sample ?  --> stst_got_r
;// 2) exit to wait_test_xxx

;/////////////////////////////////////////////////
ALIGN 16
wait_test_t_both:

    test dh, dh
    js store_static
    IF_NOT_EDGE t0,BOTH,store_static
    COUNT_WAIT  NODIRTY,store_static,store_static

ALIGN 16
st_tb_sr_rbe_yh::   IF_EDGE r0, BOTH, stst_got_r
                    jmp wait_test_t_both
ALIGN 16
st_tb_sr_rpe_yh::   or ah, ah                       ;// can we reset on first sample ?
                    jns wait_test_t_both            ;// jump to wait test if not
                    IF_EDGE r0,NEG_POS,stst_got_r   ;// reset on first sample ?
                    jmp wait_test_t_both            ;// jump to common wait routine
ALIGN 16
st_tb_sr_rme_yh::   or ah, ah                       ;// can we reset on first sample ?
                    js wait_test_t_both             ;// jump to wait test if not
                    IF_EDGE r0,POS_NEG,stst_got_r   ;// reset on first sample ?
                    jmp wait_test_t_both            ;// jump to common wait routine
ALIGN 16
st_tb_sr_rmg_yh::   mov ah, [ebp]
                    test ah, ah
                    js  stst_got_r
                    jmp wait_test_t_both
ALIGN 16
st_tb_sr_rpg_yh::   mov ah, [ebp]
                    test ah, ah
                    jns stst_got_r
                    jmp wait_test_t_both

;/////////////////////////////////////////////////
ALIGN 16
wait_test_t_pos_neg:

    test dh, dh
    js store_static
    test al, al
    js store_static
    IF_NOT_EDGE t0,POS_NEG,store_static
    COUNT_WAIT  NODIRTY,store_static,store_static

ALIGN 16
st_tm_sr_rbe_yh::   IF_EDGE r0, BOTH, stst_got_r
                    jmp wait_test_t_pos_neg
ALIGN 16
st_tm_sr_rpe_yh::   or ah, ah                       ;// can we reset on first sample ?
                    jns wait_test_t_pos_neg
                    IF_EDGE r0,NEG_POS,stst_got_r   ;// reset on first sample ?
                    jmp wait_test_t_pos_neg
ALIGN 16
st_tm_sr_rme_yh::   or ah, ah                       ;// can we reset on first sample ?
                    js wait_test_t_pos_neg
                    IF_EDGE r0,POS_NEG,stst_got_r   ;// reset on first sample ?
                    jmp wait_test_t_pos_neg
ALIGN 16
st_tm_sr_rmg_yh::   mov ah, [ebp]
                    test ah, ah
                    js  stst_got_r
                    jmp wait_test_t_pos_neg
ALIGN 16
st_tm_sr_rpg_yh::   mov ah, [ebp]
                    test ah, ah
                    jns stst_got_r
                    jmp wait_test_t_pos_neg

;/////////////////////////////////////////////////
ALIGN 16
wait_test_t_neg_pos:

    test dh, dh
    js store_static
    test al, al
    jns store_static
    IF_NOT_EDGE t0,NEG_POS,store_static
    COUNT_WAIT  NODIRTY,store_static,store_static

ALIGN 16
st_tp_sr_rbe_yh::   IF_EDGE r0, BOTH, stst_got_r
                    jmp wait_test_t_neg_pos
ALIGN 16
st_tp_sr_rpe_yh::   or ah, ah                       ;// can we reset on first sample ?
                    jns wait_test_t_neg_pos
                    IF_EDGE r0,NEG_POS,stst_got_r   ;// reset on first sample ?
                    jmp wait_test_t_neg_pos
ALIGN 16
st_tp_sr_rme_yh::   or ah, ah                       ;// can we reset on first sample ?
                    js wait_test_t_neg_pos
                    IF_EDGE r0,POS_NEG,stst_got_r   ;// reset on first sample ?
                    jmp wait_test_t_neg_pos
ALIGN 16
st_tp_sr_rmg_yh::   mov ah, [ebp]
                    test ah, ah
                    js  stst_got_r
                    jmp wait_test_t_neg_pos
ALIGN 16
st_tp_sr_rpg_yh::   mov ah, [ebp]
                    test ah, ah
                    jns stst_got_r
                    jmp wait_test_t_neg_pos


;//     yh  STORE STATIC        ;// LEGEND (F12)
;//
;/////////////////////////////////////////////////////////////////


;// we assume got_r on first sample doesn't happen that often

ALIGN 16
stst_got_r::

        RESET_COUNT         NODIRTY,LOAD,store_static



;/////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;///
;///    FILL REMAINING
;///
;///        fill_remaining is always preceeded by a reset
;///        so we provide access points to do that

ALIGN 16
single_reset_and_fill:: ;// call to reset, store value and fill

        RESET_COUNT     DIRTY,NOLOAD

fill_remaining_now::    ;// call when no reset is nessesary

        mov ah, [ebp+LAST_SAMPLE]   ;// be sure to load this
        mov al, [ebx+LAST_SAMPLE]   ;// be sure to load this too

        NEXT_SAMPLE                 ;// cant fill last sample

    ;// esi     osc
    ;// ecx     offset
    ;// ah:al   reset:trigger edge
    ;// ebp:ebx reset:trigger
    ;// dh:dl   current_count:default_count
    ;// edi     sign:changing
    ;// fpu     state1  state2

    comment ~ /*
        in this case, we want to fill the remaining frame with whatever is in the fpu
        in all cases, the previous sample is what we want to store

        if pin changing
        OR !pin_hanging AND *[ecx] != *[ecx-4]
        we have to fill
    */ comment ~

        mov ebx, [esi].data_x[ecx-4]    ;// get the value before it's too late
        .IF !(edi & 7FFFFFFFh)          ;// already marked dirty ?
        .IF !([esi].pin_x.dwStatus & PIN_CHANGING)  ;// previous frame dirty ?
        cmp ebx, [esi].data_x[ecx];// have a different value ?
        je calc_done
        .ENDIF
        .ENDIF

    ;// need_to_fill:

        mov ebp, edi    ;// save edi
        xchg eax, ebx   ;// store eax, get the value to store
        lea edi, [esi].data_x[ecx]

        sub ecx, SAMARY_SIZE
        neg ecx
        shr ecx, 2

        rep stosd

        mov eax, ebx    ;// retrieve eax
        mov edi, ebp    ;// retrieve edi

        jmp calc_done   ;// exit








;/////////////////////////////////////////////////////////////
;//
;//     NH edge
;//
;// 1) check for reset on first sample  --> stst_got_r
;// 2) check for edge on first sample
;// 3) exit to single reset loop
;///////////////////////////////////////////////////////
;//
;// YH edge
;//
;// 1) reset on first sample    --> stst_got_r
;// 2) already waiting          --> edge_fill_xxx
;// 3) count on first sample    --> edge_fill_xxx


;////////////////////////////////////////////////////////////
ALIGN 16
edge_fill_both  PROC
                mov al, [ebx]   ;// always load the first al
                ALREADY_RESET   ;// then exit to store_static
    top_of:     IF_EDGE         r, BOTH, single_reset_and_fill
                NEXT_SAMPLE     top_of
edge_fill_both  ENDP

ALIGN 16
count_edge_fill_both:

    COUNT_TOGGLE    NODIRTY,edge_fill_both

ALIGN 16
st_tb_dr_rbe_nh::   IF_EDGE         r0,BOTH,stst_got_r
                    IF_NOT_EDGE     t0,BOTH,edge_fill_both
                    jmp count_edge_fill_both
ALIGN 16
st_tp_dr_rbe_nh::   IF_EDGE         r0,BOTH,stst_got_r
                    test al, al
                    jns edge_fill_both
                    IF_NOT_EDGE     t0,NEG_POS,edge_fill_both
                    jmp count_edge_fill_both
ALIGN 16
st_tm_dr_rbe_nh::   IF_EDGE         r0,BOTH,stst_got_r
                    test al, al
                    js edge_fill_both
                    IF_NOT_EDGE     t0,POS_NEG,edge_fill_both
                    jmp count_edge_fill_both
ALIGN 16
wait_edge_fill_both:

    COUNT_WAIT      NODIRTY,edge_fill_both,edge_fill_both

ALIGN 16
st_tb_dr_rbe_yh::   IF_EDGE         r0,BOTH,stst_got_r
                    test dh, dh
                    js edge_fill_both
                    IF_NOT_EDGE     t0,BOTH,edge_fill_both
                    jmp wait_edge_fill_both
ALIGN 16
st_tp_dr_rbe_yh::   IF_EDGE         r0,BOTH,stst_got_r  ;// exit to fill
                    test dh, dh     ;// are we waiting now ?
                    js edge_fill_both
                    test al, al     ;// can we get a count on the the first sample
                    jns edge_fill_both
                    IF_NOT_EDGE     t0,NEG_POS,edge_fill_both   ;// do we get a count on the first sample ?
                    jmp wait_edge_fill_both
ALIGN 16
st_tm_dr_rbe_yh::   IF_EDGE         r0,BOTH,stst_got_r  ;// exit to fill
                    test dh, dh     ;// are we waiting now ?
                    js edge_fill_both
                    test al, al     ;// can we get a count on the the first sample
                    js edge_fill_both
                    IF_NOT_EDGE     t0,POS_NEG,edge_fill_both   ;// do we get a count on the first sample ?
                    jmp wait_edge_fill_both

;////////////////////////////////////////////////////////////

ALIGN 16
edge_fill_pos   PROC
                mov al, [ebx]   ;// always load the first al
                ALREADY_RESET   ;// then exit to store_static
                test ah,ah
                jns p_top
                jmp m_top
;// P
    p_next:     NEXT_SAMPLE
    p_top:      IF_NOT_EDGE     r,POS_NEG,p_next
;// M
    m_next:     NEXT_SAMPLE
    m_top:      IF_NOT_EDGE     r,NEG_POS,m_next
                jmp single_reset_and_fill
edge_fill_pos   ENDP

ALIGN 16
count_edge_fill_pos:

    COUNT_TOGGLE    NODIRTY,edge_fill_pos

ALIGN 16
st_tb_dr_rpe_nh::   test ah,ah
                    .IF SIGN?
                    IF_EDGE         r0,NEG_POS,stst_got_r
                    .ENDIF
                    IF_NOT_EDGE     t0,BOTH,edge_fill_pos
                    jmp count_edge_fill_pos
ALIGN 16
st_tp_dr_rpe_nh::   test ah,ah
                    .IF SIGN?
                    IF_EDGE         r0,NEG_POS,stst_got_r
                    .ENDIF
                    test al, al
                    jns edge_fill_pos
                    IF_NOT_EDGE     t0,NEG_POS,edge_fill_pos
                    jmp count_edge_fill_pos
ALIGN 16
st_tm_dr_rpe_nh::   test ah,ah
                    .IF SIGN?
                    IF_EDGE         r0,NEG_POS,stst_got_r
                    .ENDIF
                    test al, al
                    js edge_fill_pos
                    IF_NOT_EDGE     t0,POS_NEG,edge_fill_pos
                    jmp count_edge_fill_pos

ALIGN 16
wait_edge_fill_pos:

    COUNT_WAIT      NODIRTY,edge_fill_pos,edge_fill_pos

ALIGN 16
st_tb_dr_rpe_yh::   test ah, ah
                    .IF SIGN?
                    IF_EDGE         r0,NEG_POS,stst_got_r
                    .ENDIF
                    test dh, dh
                    js edge_fill_pos
                    IF_NOT_EDGE     t0,BOTH, edge_fill_pos
                    jmp wait_edge_fill_pos
ALIGN 16
st_tp_dr_rpe_yh::   test ah, ah
                    .IF SIGN?
                    IF_EDGE         r0,NEG_POS,stst_got_r
                    .ENDIF
                    test dh, dh
                    js edge_fill_pos
                    test al, al
                    jns edge_fill_pos
                    IF_NOT_EDGE     t0,NEG_POS,edge_fill_pos
                    jmp wait_edge_fill_pos
ALIGN 16
st_tm_dr_rpe_yh::   test ah, ah
                    .IF SIGN?
                    IF_EDGE         r0,NEG_POS,stst_got_r
                    .ENDIF
                    test dh, dh
                    js edge_fill_pos
                    test al, al
                    js edge_fill_pos
                    IF_NOT_EDGE     t0,POS_NEG,edge_fill_pos
                    jmp wait_edge_fill_pos

;////////////////////////////////////////////////////////////
ALIGN 16
edge_fill_neg   PROC
                mov al, [ebx]   ;// always load the first al
                ALREADY_RESET   ;// if we're already reset then exit to store_static
                test ah,ah
                jns p_top
                jmp m_top
;// M
    m_next:     NEXT_SAMPLE
    m_top:      IF_NOT_EDGE     r,NEG_POS,m_next
;// P
    p_next:     NEXT_SAMPLE
    p_top:      IF_NOT_EDGE     r,POS_NEG,p_next
                jmp single_reset_and_fill
edge_fill_neg   ENDP

ALIGN 16
count_edge_fill_neg:

    COUNT_TOGGLE    NODIRTY,edge_fill_neg

ALIGN 16
st_tb_dr_rme_nh::   test ah,ah
                    .IF !SIGN?
                    IF_EDGE         r0,POS_NEG,stst_got_r
                    .ENDIF
                    IF_NOT_EDGE     t0,BOTH,edge_fill_neg
                    jmp count_edge_fill_neg
ALIGN 16
st_tp_dr_rme_nh::   test ah,ah
                    .IF !SIGN?
                    IF_EDGE         r0,POS_NEG,stst_got_r
                    .ENDIF
                    test al, al
                    jns edge_fill_neg
                    IF_NOT_EDGE     t0,NEG_POS,edge_fill_neg
                    jmp count_edge_fill_neg
ALIGN 16
st_tm_dr_rme_nh::   test ah,ah
                    .IF !SIGN?
                    IF_EDGE         r0,POS_NEG,stst_got_r
                    .ENDIF
                    test al, al
                    js edge_fill_neg
                    IF_NOT_EDGE     t0,POS_NEG,edge_fill_neg
                    jmp count_edge_fill_neg

ALIGN 16
wait_edge_fill_neg:

    COUNT_WAIT      NODIRTY,edge_fill_neg,edge_fill_neg

ALIGN 16
st_tb_dr_rme_yh::   test ah, ah
                    .IF !SIGN?
                    IF_EDGE         r0,POS_NEG,stst_got_r
                    .ENDIF
                    test dh, dh
                    js edge_fill_neg
                    IF_NOT_EDGE     t0,BOTH,edge_fill_neg
                    jmp wait_edge_fill_neg
ALIGN 16
st_tp_dr_rme_yh::   test ah, ah
                    .IF !SIGN?
                    IF_EDGE         r0,POS_NEG,stst_got_r
                    .ENDIF
                    test dh, dh
                    js edge_fill_neg
                    test al, al
                    jns edge_fill_neg
                    IF_NOT_EDGE     t0,NEG_POS,edge_fill_neg
                    jmp wait_edge_fill_neg
ALIGN 16
st_tm_dr_rme_yh::   test ah, ah
                    .IF !SIGN?
                    IF_EDGE         r0,POS_NEG,stst_got_r
                    .ENDIF
                    test dh, dh
                    js edge_fill_neg
                    test al, al
                    js edge_fill_neg
                    IF_NOT_EDGE     t0,POS_NEG,edge_fill_neg
                    jmp wait_edge_fill_neg


;////////////////////////////////////////////////////////////////////
;//
;//     NH gate
;//
;// 1) check if reset now   --> stst_got_r
;// 2) check for edge       --> gate_fill_xxx
;///////////////////////////////////////////////////////////
;//
;//     YH gate
;//
;// 1) check for reset now  --> stst_got_r
;// 2) check if waiting now --> gate_fill_xxx
;// 3) check for edge       --> gate_fill_xxx

ALIGN 16
gate_fill_pos   PROC
                DEBUG_IF <!!(ah & 80h)> ;// ah is supposed to be negative
                mov al, [ebx]
        top_of: IF_LEVEL    r,POS,single_reset_and_fill
                NEXT_SAMPLE top_of
gate_fill_pos   ENDP

ALIGN 16
count_gate_fill_pos:

    COUNT_TOGGLE    NODIRTY,gate_fill_pos

ALIGN 16
st_tb_dr_rpg_nh::   mov ah, [ebp]
                    test ah, ah
                    jns stst_got_r
                    IF_NOT_EDGE     t0,BOTH,gate_fill_pos
                    jmp count_gate_fill_pos
ALIGN 16
st_tp_dr_rpg_nh::   mov ah, [ebp]
                    test ah, ah
                    jns stst_got_r
                    test al, al
                    jns gate_fill_pos
                    IF_NOT_EDGE     t0,NEG_POS,gate_fill_pos
                    jmp count_gate_fill_pos
ALIGN 16
st_tm_dr_rpg_nh::   mov ah, [ebp]
                    test ah, ah
                    jns stst_got_r
                    test al, al
                    js gate_fill_pos
                    IF_NOT_EDGE     t0,POS_NEG,gate_fill_pos
                    jmp count_gate_fill_pos

ALIGN 16
wait_gate_fill_pos:

    COUNT_WAIT      NODIRTY,gate_fill_pos,gate_fill_pos

ALIGN 16
st_tb_dr_rpg_yh::   mov ah, [ebp]
                    test ah, ah
                    jns stst_got_r
                    test dh, dh
                    js gate_fill_pos
                    IF_NOT_EDGE     t0,BOTH,gate_fill_pos
                    jmp wait_gate_fill_pos
ALIGN 16
st_tp_dr_rpg_yh::   mov ah, [ebp]
                    test ah, ah
                    jns stst_got_r
                    test dh, dh
                    js gate_fill_pos
                    test al, al
                    jns gate_fill_pos
                    IF_NOT_EDGE     t0,NEG_POS,gate_fill_pos
                    jmp wait_gate_fill_pos
ALIGN 16
st_tm_dr_rpg_yh::   mov ah, [ebp]
                    test ah, ah
                    jns stst_got_r
                    test dh, dh
                    js gate_fill_pos
                    test al, al
                    js gate_fill_pos
                    IF_NOT_EDGE     t0,POS_NEG,gate_fill_pos
                    jmp wait_gate_fill_pos

;///////////////////////////////////////////////////////
ALIGN 16
gate_fill_neg   PROC
                DEBUG_IF <ah & 80h> ;// ah is supposed to be positive
                mov al, [ebx]
        top_of: IF_LEVEL    r,NEG,single_reset_and_fill
                NEXT_SAMPLE top_of
gate_fill_neg   ENDP

ALIGN 16
count_gate_fill_neg:

    COUNT_TOGGLE    NODIRTY,gate_fill_neg


ALIGN 16
st_tb_dr_rmg_nh::   mov ah, [ebp]
                    test ah, ah
                    js stst_got_r
                    IF_NOT_EDGE     t0,BOTH,gate_fill_neg
                    jmp count_gate_fill_neg
ALIGN 16
st_tp_dr_rmg_nh::   mov ah, [ebp]
                    test ah, ah
                    js stst_got_r
                    test al, al
                    jns gate_fill_neg
                    IF_NOT_EDGE     t0,NEG_POS,gate_fill_neg
                    jmp count_gate_fill_neg
ALIGN 16
st_tm_dr_rmg_nh::   mov ah, [ebp]
                    test ah, ah
                    js stst_got_r

                    test al, al     ;// already neg ?
                    js gate_fill_neg
                    IF_NOT_EDGE     t0,POS_NEG,gate_fill_neg
                    jmp count_gate_fill_neg

ALIGN 16
wait_gate_fill_neg:

    COUNT_WAIT      NODIRTY,gate_fill_neg,gate_fill_neg

ALIGN 16
st_tb_dr_rmg_yh::   mov ah, [ebp]   ;// reset on first sample ?
                    test ah, ah
                    js stst_got_r
                    test dh, dh     ;// waiting now ?
                    js gate_fill_neg
                    IF_NOT_EDGE     t0,BOTH,gate_fill_neg       ;// count on first sample ?
                    jmp wait_gate_fill_neg
ALIGN 16
st_tp_dr_rmg_yh::   mov ah, [ebp]   ;// reset on first sample ?
                    test ah, ah
                    js stst_got_r
                    test dh, dh     ;// waiting now ?
                    js gate_fill_neg
                    test al, al     ;// can we count on first sample ?
                    jns gate_fill_neg
                    IF_NOT_EDGE     t0,NEG_POS,gate_fill_neg    ;// check for count on first sample
                    jmp wait_gate_fill_neg
ALIGN 16
st_tm_dr_rmg_yh::   mov ah, [ebp]   ;// reset on first sample ?
                    test ah, ah
                    js stst_got_r
                    test dh, dh     ;// waiting now ?
                    js gate_fill_neg
                    test al, al     ;// can we count on first sample ?
                    js gate_fill_neg
                    IF_NOT_EDGE     t0,POS_NEG,gate_fill_neg    ;// check for count on first sample
                    jmp wait_gate_fill_neg






















ASSUME_AND_ALIGN
divider_Ctor PROC

        ;// register call
        ASSUME ebp:PTR LIST_CONTEXT ;// preserve
        ASSUME esi:PTR OSC_OBJECT   ;// preserve
        ASSUME edi:PTR OSC_BASE     ;// may destroy
        ASSUME ebx:PTR FILE_OSC     ;// may destroy
        ASSUME edx:PTR FILE_HEADER  ;// may destroy

    invoke divider_Reset

    ret

divider_Ctor ENDP



ASSUME_AND_ALIGN
divider_Reset PROC  ;// uses edi

    ASSUME esi:PTR OSC_MAP

    xor edx, edx
    xor eax, eax

    ;// reset the last trigger
    mov [esi].pin_t.dwUser, edx
    mov [esi].pin_r.dwUser, edx

    ;// set the ouput value correctly
    ;// since this is also called from the ctor, we reset our own data

    mov al, BYTE PTR [esi].dwUser   ;// get default count
    and al, DIVIDER_COUNT_TEST      ;// remove extra
    mov BYTE PTR [esi+1].dwUser, al ;// store as current counter

    mov edx, [esi].pin_x.pPin
    .IF edx && edx != math_pNull    ;// if pin_x is connected, clear the data
        xor eax, eax
        .IF !([esi].dwUser & DIVIDER_OUT_DIGITAL)
            mov eax, math_1
        .ENDIF
        lea edi, [esi].data_x
        mov ecx, SAMARY_LENGTH
        rep stosd

    .ENDIF


    ;// then make sure play doesn't erase anything

        inc eax

    ;// that's it

        ret

divider_Reset ENDP



;///////////////////////////////////////////////////////////////////////////
;//
;//
;//     InitMenu
;//
ASSUME_AND_ALIGN
divider_InitMenu PROC

    ASSUME esi:PTR OSC_OBJECT   ;// preserve
    ASSUME edi:PTR OSC_BASE     ;// preserve
    DEBUG_IF <edi!!=[esi].pBase>

    ;// set the current count checkmarks

        mov eax, [esi].dwUser
        and eax, DIVIDER_COUNT_TEST
        mov ecx, divider_command_table[eax*4]

        invoke CheckDlgButton, popup_hWnd, ecx, BST_CHECKED

    ;// set the current trigger type

        mov eax, [esi].dwUser
        mov ecx, ID_DIGITAL_BOTH        ;// most common
        .IF eax & DIVIDER_TRIGGER_POS
            mov ecx, ID_DIGITAL_POS
        .ELSEIF eax & DIVIDER_TRIGGER_NEG
            mov ecx, ID_DIGITAL_NEG
        .ENDIF

        invoke CheckDlgButton, popup_hWnd, ecx, BST_CHECKED

    ;// set the correct output type

        mov eax, [esi].dwUser
        mov ecx, ID_DIGITAL_BIPOLAR     ;// most common
        .IF eax & DIVIDER_OUT_DIGITAL
            mov ecx, ID_DIGITAL_DIGITAL
        .ENDIF

        invoke CheckDlgButton, popup_hWnd, ecx, BST_CHECKED

    ;// determine the reset mode

        mov eax, [esi].dwUser
        and eax, DIVIDER_RESET_TEST OR DIVIDER_RESET_GATE
        shr eax, DIVIDER_RESET_SHIFT
        mov ecx, divider_reset_id_table[eax*4]
        invoke CheckDlgButton, popup_hWnd, ecx, BST_CHECKED

    ;// show hold or not hold

        .IF [esi].dwUser & DIVIDER_HOLD
            invoke CheckDlgButton, popup_hWnd, ID_DIVIDER_HOLD, BST_CHECKED
        .ENDIF

    ;// that's it

        xor eax, eax    ;// return zero of popup build will resize

        ret

divider_InitMenu ENDP
;//
;//     InitMenu
;//
;//
;///////////////////////////////////////////////////////////////////////////



ASSUME_AND_ALIGN
divider_SyncPins PROC

    ASSUME esi:PTR OSC_MAP
    ASSUME ebp:PTR LIST_CONTEXT

    ;// destroys ebx

    ;// PIN_LEVEL_POS       equ  00001000h  ;// responds to positive level or edge \ both off is
    ;// PIN_LEVEL_NEG       equ  00002000h  ;// responds to negative level or edge / both levels
    ;// PIN_LOGIC_GATE      equ  00004000h  ;// is a gate input (off is trigger)
    ;// PIN_LOGIC_INPUT     equ  00008000h  ;// is a logic detecting input
    ;//
    ;// PIN_LEVEL_TEST  equ PIN_LOGIC_GATE OR PIN_LEVEL_POS OR PIN_LEVEL_NEG


    ;// DIVIDER_TRIGGER_POS  equ  10000000h  ;// count positive edges only
    ;// DIVIDER_TRIGGER_NEG  equ  20000000h  ;// count negative edges only

    ;// DIVIDER_TRIGGER_TEST equ  30000000h  ;// zero for count both edges
    ;// DIVIDER_TRIGGER_MASK equ 0CFFFFFFFh

        mov eax, [esi].dwUser           ;// get out settings
        and eax, DIVIDER_TRIGGER_TEST   ;// strip out extra flags
        lea ebx, [esi].pin_t            ;// point at the pin
        BITSHIFT eax, DIVIDER_TRIGGER_POS, PIN_LEVEL_POS;// scoot our setting into place
        or eax, PIN_LOGIC_INPUT
        invoke pin_SetInputShape        ;// call generic function

    ;// DIVIDER_RESET_POS    equ  01000000h
    ;// DIVIDER_RESET_NEG    equ  02000000h
    ;// DIVIDER_RESET_GATE   equ  04000000h
    ;// DIVIDER_RESET_TEST   equ  (DIVIDER_RESET_POS + DIVIDER_RESET_NEG )
    ;// DIVIDER_RESET_MASK   equ  NOT DIVIDER_RESET_TEST

        mov eax, [esi].dwUser           ;// get out settings
        and eax, DIVIDER_RESET_TEST OR DIVIDER_RESET_GATE   ;// strip out extra flags
        lea ebx, [esi].pin_r            ;// point at the pin
        BITSHIFT eax, DIVIDER_RESET_POS, PIN_LEVEL_POS  ;// scoot our setting into place
        or eax, PIN_LOGIC_INPUT
        invoke pin_SetInputShape        ;// call generic function

    ;// DIVIDER OUTPUT

        ;// make sure the fonts are built

        .IF divider_output_font == 0B1h

            push edi

            mov eax, divider_output_font
            lea edi, font_bus_slist_head
            invoke font_Locate
            mov divider_output_font, edi

            mov eax, divider_output_font[4]
            lea edi, font_bus_slist_head
            invoke font_Locate
            mov divider_output_font[4], edi

            mov eax, divider_font_t
            lea edi, font_pin_slist_head
            invoke font_Locate
            mov divider_font_t, edi

            mov eax, divider_font_s
            lea edi, font_pin_slist_head
            invoke font_Locate
            mov divider_font_s, edi

            pop edi

        .ENDIF

        mov eax, [esi].dwUser
        xor edx, edx
        BITT eax, DIVIDER_OUT_DIGITAL
        adc edx, edx
        mov eax, divider_output_font[edx*4]
        lea ebx, [esi].pin_x

        invoke pin_SetName

    ;// TRIGGER INPUT

        lea ebx, [esi].pin_t
        test [esi].dwUser, DIVIDER_HOLD
        mov eax, divider_font_t
        .IF !ZERO?
            mov eax, divider_font_s
        .ENDIF

        invoke pin_SetName

    ;// that's it

        ret

divider_SyncPins ENDP









;///////////////////////////////////////////////////////////////////////////
;//
;//
;//     Command
;//
ASSUME_AND_ALIGN
divider_Command PROC PRIVATE

    ASSUME esi:PTR OSC_OBJECT   ;// preserve
    ASSUME edi:PTR OSC_BASE
    DEBUG_IF <edi!!=[esi].pBase>

;//
;//     COUNT COMMANDS
;//
    ;// set a new count

    push edi
    lea edi, divider_command_table
    mov ecx, DIVIDER_COMMAND_TABLE_LENGTH
    repne scasd
    pop edi
    jnz @F      ;// jmp if not found

        sub ecx, DIVIDER_COMMAND_TABLE_LENGTH - 1
        and [esi].dwUser, DIVIDER_COUNT_MASK
        neg ecx
        mov eax, POPUP_REDRAW_OBJECT + POPUP_SET_DIRTY
        mov edx, divider_shape[ecx*4]
        or [esi].dwUser, ecx
        mov [esi].pSource, edx

        ret

;//
;//     OUTPUT COMMANDS
;//
@@: cmp eax, ID_DIGITAL_BIPOLAR
    jnz @F

        and [esi].dwUser, DIVIDER_OUT_MASK
        jmp set_new_output

@@: cmp eax, ID_DIGITAL_DIGITAL
    jnz @F

        or  [esi].dwUser, DIVIDER_OUT_DIGITAL

set_new_output:

        invoke divider_SyncPins ;// sync the pins

        mov eax, POPUP_SET_DIRTY OR POPUP_REDRAW_OBJECT
        ret


;//
;// TRIGGER COMMANDS    ecx ends up as new value for dwUser
;//

    ;// set a new count trigger
@@: mov ecx, [esi].dwUser       ;// load this now
    mov edi, POPUP_REDRAW_OBJECT + POPUP_SET_DIRTY  ;// default return value

    cmp eax, ID_DIGITAL_POS
    jnz @F

        BITS ecx, DIVIDER_TRIGGER_POS
        BITR ecx, DIVIDER_TRIGGER_NEG
        jmp set_new_trigger

@@: cmp eax, ID_DIGITAL_NEG
    jnz @F

        BITR ecx, DIVIDER_TRIGGER_POS
        BITS ecx, DIVIDER_TRIGGER_NEG
        jmp set_new_trigger

@@: cmp eax, ID_DIGITAL_BOTH
    jnz @F

        and ecx, NOT (DIVIDER_TRIGGER_TEST)
        jmp set_new_trigger

@@: cmp eax, ID_DIVIDER_RESET_POS_EDGE
    jnz @F

        BITR ecx, DIVIDER_RESET_GATE
        BITS ecx, DIVIDER_RESET_POS
        BITR ecx, DIVIDER_RESET_NEG

        jmp set_new_trigger

@@: cmp eax, ID_DIVIDER_RESET_NEG_EDGE
    jnz @F

        BITR ecx, DIVIDER_RESET_GATE
        BITR ecx, DIVIDER_RESET_POS
        BITS ecx, DIVIDER_RESET_NEG

    set_new_trigger:

        mov [esi].dwUser, ecx   ;// store the new dwUser
        invoke divider_SyncPins ;// sync the pins

        mov eax, edi            ;// set the return value
        ret

@@: cmp eax, ID_DIVIDER_RESET_BOTH_EDGE
    jnz @F

        BITR ecx, DIVIDER_RESET_GATE
        BITR ecx, DIVIDER_RESET_POS
        BITR ecx, DIVIDER_RESET_NEG

        jmp set_new_trigger

@@: cmp eax, ID_DIVIDER_RESET_POS_GATE
    jnz @F

        BITS ecx, DIVIDER_RESET_GATE
        BITS ecx, DIVIDER_RESET_POS
        BITR ecx, DIVIDER_RESET_NEG

        jmp set_new_trigger

@@: cmp eax, ID_DIVIDER_RESET_NEG_GATE
    jne @F

        BITS ecx, DIVIDER_RESET_GATE
        BITR ecx, DIVIDER_RESET_POS
        BITS ecx, DIVIDER_RESET_NEG

        jmp set_new_trigger

@@: cmp eax, ID_DIVIDER_HOLD
    jnz osc_Command

        BITC ecx, DIVIDER_HOLD
        jmp set_new_trigger

divider_Command ENDP
;//
;//     Command
;//
;//
;///////////////////////////////////////////////////////////////////////////




ASSUME_AND_ALIGN
divider_SetShape PROC

    ASSUME esi:PTR OSC_OBJECT

    mov eax, [esi].dwUser
    and eax, DIVIDER_COUNT_TEST
    mov eax, divider_shape[eax*4]
    mov [esi].pSource, eax

    invoke divider_SyncPins

    jmp osc_SetShape    ;// ret

divider_SetShape ENDP




;////////////////////////////////////////////////////////////////////
;//
;//
;//     _LoadUndo
;//

ASSUME_AND_ALIGN
divider_LoadUndo PROC

        ASSUME esi:PTR OSC_OBJECT   ;// preserve
        ASSUME ebp:PTR LIST_CONTEXT ;// preserve

    ;// edx enters as either UNREDO_CONTROL_OSC or UNREDO_COMMAND
    ;// edi enters as where to load
    ;//
    ;// task:   1) load nessary data
    ;//         2) do what it takes to initialize it
    ;//
    ;// may use all registers except ebp and esi
    ;// return will invalidate HINTI_OSC_UPDATE


        mov eax, [edi]
        mov [esi].dwUser, eax

        and eax, DIVIDER_COUNT_TEST
        mov eax, divider_shape[eax*4]
        mov [esi].pSource, eax

        invoke divider_SyncPins

        ret

divider_LoadUndo ENDP

;//
;//
;//     _LoadUndo
;//
;////////////////////////////////////////////////////////////////////





ASSUME_AND_ALIGN

ENDIF   ;// USE_THIS_FILE

END