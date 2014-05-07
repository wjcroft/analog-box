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

; AJT: The psuedo random number generator (prng) used here is not very good.
;      Regrettably, there are hundreds of existing melody circuits that rely on
;      particular sequences created by it. Different types of prng might implemented ...

;//
;// ABox_Rand.asm
;//
OPTION CASEMAP:NONE

.586
.MODEL FLAT

USE_THIS_FILE equ 1

IFDEF USE_THIS_FILE

        .NOLIST
        INCLUDE <Abox.inc>
        .LIST


;// BRAGGING_RIGHTS EQU 1   ;// turns on macro counting

;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;///
;///     R A N D O M   O B J E C T
;///
;///     a random numbers, makes for good white noise
;///


.DATA

;// GDI



;// general size

    NOISE_SIZE_X equ 42
    NOISE_SIZE_Y equ 40

;// OSC_BASE

osc_Rand OSC_CORE { rand_Ctor,,rand_PrePlay,rand_Calc}
           OSC_GUI  { ,,,,,rand_Command,rand_InitMenu,,,osc_SaveUndo,rand_LoadUndo,rand_GetUnit}
           OSC_HARD { }

    OSC_DATA_LAYOUT {NEXT_Rand,IDB_RAND,OFFSET popup_RAND,BASE_NEED_THREE_LINES,
        5,4,
        SIZEOF OSC_OBJECT + (SIZEOF APIN)*5,
        SIZEOF OSC_OBJECT + (SIZEOF APIN)*5 + SAMARY_SIZE,
        SIZEOF OSC_OBJECT + (SIZEOF APIN)*5 + SAMARY_SIZE }

    OSC_DISPLAY_LAYOUT { noise_container,NOISE_s562_PSOURCE,ICON_LAYOUT(2,1,2,1) }

    APIN_init {-0.5 ,sz_Amplitude,  'A',, UNIT_AUTO_UNIT }          ;// input
    APIN_init { 0.0 ,,              '=',, PIN_OUTPUT OR UNIT_AUTO_UNIT }  ;// output pin

    APIN_init { 0.5 ,sz_SeedValue,  'S',, UNIT_VALUE  }                     ;// seed input
    APIN_init { 0.9 ,sz_Restart,    's',, PIN_LOGIC_INPUT OR UNIT_LOGIC }   ;// reseed input
    APIN_init {-0.9 ,sz_NextValue,  'n',, PIN_LOGIC_INPUT OR UNIT_LOGIC }   ;// next value

    short_name  db  'Random',0
    description db  'Generates a random sequence beginning with a seed value. May be set as a white noise source, or be sequenced by using the trigger inputs.',0
    ALIGN 4


    ;// flags stored in object.dwUser

        RAND_SEED_POS  equ  00000001h  ;//
        RAND_SEED_NEG  equ  00000002h  ;//
        RAND_SEED_TEST equ 000000003h

        rand_seed_id_table LABEL DWORD

        dd  ID_RAND_SEED_BOTH_EDGE
        dd  ID_RAND_SEED_POS_EDGE
        dd  ID_RAND_SEED_NEG_EDGE

        RAND_NEXT_POS  equ  00000004h
        RAND_NEXT_NEG  equ  00000008h
        RAND_NEXT_TEST equ RAND_NEXT_POS OR RAND_NEXT_NEG

        RAND_NEXT_GATE equ  00000010h

        RAND_NEXT_SHIFT EQU LOG2(RAND_NEXT_POS)

        rand_next_id_table LABEL DWORD

        dd  ID_RAND_NEXT_BOTH_EDGE
        dd  ID_RAND_NEXT_POS_EDGE
        dd  ID_RAND_NEXT_NEG_EDGE
        dd  0, 0
        dd  ID_RAND_NEXT_POS_GATE
        dd  ID_RAND_NEXT_NEG_GATE

    ;// seed value is stored in S.dwUser
    ;// last restart trigger stored in R.dwUser
    ;// last next trigger stored in t.dwUser
    ;// last out value stored in X.dwUser

    ;// restart always grabs the value at the seed input


    ;// data    constants

        random_multRand dd  4961    ;// used to generate the next number
        random_scale    REAL4 4.656612873e-10

    ;// psource table

    rand_pSource LABEL DWORD

        dd  NOISE_s562_PSOURCE
        dd  NOISE_s512_PSOURCE
        dd  NOISE_s314_PSOURCE
        dd  NOISE_s215_PSOURCE
        dd  NOISE_s413_PSOURCE
        dd  NOISE_s126_PSOURCE
        dd  NOISE_s324_PSOURCE
        dd  NOISE_s621_PSOURCE
        dd  NOISE_s423_PSOURCE
        dd  NOISE_s265_PSOURCE
        dd  NOISE_s364_PSOURCE
        dd  NOISE_s463_PSOURCE
        dd  NOISE_s651_PSOURCE
        dd  NOISE_s354_PSOURCE
        dd  NOISE_s156_PSOURCE
        dd  NOISE_s453_PSOURCE
        dd  NOISE_s532_PSOURCE
        dd  NOISE_s631_PSOURCE
        dd  NOISE_s235_PSOURCE
        dd  NOISE_s136_PSOURCE
        dd  NOISE_s542_PSOURCE
        dd  NOISE_s146_PSOURCE
        dd  NOISE_s245_PSOURCE
        dd  NOISE_s641_PSOURCE


.CODE

ASSUME_AND_ALIGN
rand_GetUnit PROC

    ASSUME esi:PTR OSC_OBJECT
    ASSUME ebx:PTR APIN

    ;// xfer between A and output

    OSC_TO_PIN_INDEX esi, ecx, 0
    .IF ecx == ebx
        add ecx, SIZEOF APIN
    .ENDIF

    mov eax, [ecx].dwStatus
    BITT eax, UNIT_AUTOED

    ret

rand_GetUnit ENDP











ASSUME_AND_ALIGN
rand_SetTriggers PROC USES ebx

    ASSUME esi:PTR OSC_OBJECT

    ;// make sure the triggers on the pins match the triggers in dwUser

    mov eax, [esi].dwUser
    OSC_TO_PIN_INDEX esi, ebx, 3    ;// s input
    and eax, RAND_SEED_TEST
    shl eax, LOG2(PIN_LEVEL_POS)
    or eax, PIN_LOGIC_INPUT
    invoke pin_SetInputShape

    mov eax, [esi].dwUser
    OSC_TO_PIN_INDEX esi, ebx, 4    ;// s input
    and eax, RAND_NEXT_TEST OR RAND_NEXT_GATE
    shl eax, LOG2(PIN_LEVEL_POS)-LOG2(RAND_NEXT_POS)
    or eax, PIN_LOGIC_INPUT
    invoke pin_SetInputShape

    ret

rand_SetTriggers ENDP








ASSUME_AND_ALIGN
rand_Ctor PROC

    ;// dtermine how we are loading this from the file

        ;// register call
        ASSUME ebp:PTR LIST_CONTEXT ;// preserve
        ASSUME esi:PTR OSC_OBJECT   ;// preserve
        ASSUME edi:PTR OSC_BASE     ;// may_destroy
        ASSUME ebx:PTR FILE_OSC     ;// may destroy
        ASSUME edx:PTR FILE_HEADER  ;// may destroy

        invoke rand_SetTriggers

    ;// simple as that

        ret

rand_Ctor ENDP


ASSUME_AND_ALIGN
rand_InitMenu PROC

    ASSUME esi:PTR OSC_OBJECT

    ;// set the corect checkmarks

        mov eax, [esi].dwUser
        and eax, RAND_NEXT_TEST OR RAND_NEXT_GATE
        shr eax, RAND_NEXT_SHIFT
        mov ecx, rand_next_id_table[eax*4]
        invoke CheckDlgButton, popup_hWnd, ecx, BST_CHECKED

        mov eax, [esi].dwUser
        and eax, RAND_SEED_TEST
        mov ecx, rand_seed_id_table[eax*4]
        invoke CheckDlgButton, popup_hWnd, ecx, BST_CHECKED

    ;// that's it

        xor eax, eax

        ret

rand_InitMenu ENDP


ASSUME_AND_ALIGN
rand_Command PROC

    ASSUME esi:PTR OSC_OBJECT
    ;// eax has command ID

    cmp eax, ID_RAND_SEED_POS_EDGE
    jnz @F

        mov edx, RAND_SEED_POS
        jmp set_seed_trigger

@@: cmp eax, ID_RAND_SEED_NEG_EDGE
    jnz @F

        mov edx, RAND_SEED_NEG
        jmp set_seed_trigger

@@: cmp eax, ID_RAND_SEED_BOTH_EDGE
    jnz @F

        xor edx, edx

    set_seed_trigger:

        and [esi].dwUser, NOT( RAND_SEED_TEST )
        or  [esi].dwUser, edx

        jmp set_trigger_and_exit


@@: cmp eax, ID_RAND_NEXT_POS_EDGE
    jnz @F

        mov edx, RAND_NEXT_POS
        jmp set_next_trigger

@@: cmp eax, ID_RAND_NEXT_NEG_EDGE
    jnz @F

        mov edx, RAND_NEXT_NEG
        jmp set_next_trigger

@@: cmp eax, ID_RAND_NEXT_BOTH_EDGE
    jnz @F

        xor edx, edx
        jmp set_next_trigger

@@: cmp eax, ID_RAND_NEXT_POS_GATE
    jnz @F

        mov edx, RAND_NEXT_GATE OR RAND_NEXT_POS
        jmp set_next_trigger

@@: cmp eax, ID_RAND_NEXT_NEG_GATE
    jnz osc_Command

        mov edx, RAND_NEXT_GATE OR RAND_NEXT_NEG

    set_next_trigger:

        and [esi].dwUser, NOT(RAND_NEXT_TEST OR RAND_NEXT_GATE)
        or  [esi].dwUser, edx

set_trigger_and_exit:

    invoke rand_SetTriggers

    mov eax, POPUP_SET_DIRTY + POPUP_REDRAW_OBJECT
    ret


rand_Command ENDP





;////////////////////////////////////////////////////////////////////
;//
;//
;//     _LoadUndo
;//

ASSUME_AND_ALIGN
rand_LoadUndo PROC

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
        invoke rand_SetTriggers

        ret

rand_LoadUndo ENDP

;//
;//
;//     _LoadUndo
;//
;////////////////////////////////////////////////////////////////////





ASSUME_AND_ALIGN
rand_PrePlay PROC   ;//  STDCALL pObject:ptr OSC_OBJECT

    ;// here, we want to reset the triggers to zero

    ASSUME esi:PTR OSC_OBJECT

    xor eax, eax

    OSC_TO_PIN_INDEX esi, ecx, 1
    mov [ecx].dwUser, eax           ;// X output
    add ecx, SIZEOF APIN*2          ;// r input
    mov [ecx].dwUser, eax
    add ecx, SIZEOF APIN            ;// n input
    mov [ecx].dwUser, eax

    ;// eax is zero, so play_start will erase out data

    ret

rand_PrePlay ENDP




comment ~ /*


    rand_Calc

        pin descr               register        other registers
        --- ----------------    --------        ---------------------------
        S   Seed input          st_seed         edx counts
        r   Reseed input        ebp             ecx = last_reseed:last_next
        n   Next value input    ebx             st_seed pointer to S data
        A   amplitude input     esi             st_changing
        X   output              edi             st_lastvalue last value


    states: one from each column

    pin: S      r           n        A      the controlling pin
    ind: 2      3           4        0      it's index
    reg:       ebp         ebx      esi     iterator

      /                                 \
      | dS  / dr rp \  / dn np ng \  dA |   1458 combinations
      | sS  | sr rn |  | sn nn nb |  sA |   not all are meaningfull
      | nS  \ nr rb /  \ nn nb    /  nA |
      \                                 /


*/ comment ~


comment ~ /*

random number generation algorthimn

    is done in two parts
    xtra mixing is done by wrongful mixing of float and int

    integer part

        do in registers to get the mod operation without undo hassle

        eax = ((reg*multRand )+1) % 2^32

        mov eax, lastValue  ;// load as an integer
        mul random_multRand ;// constant integer
        inc eax             ;// add one
        mov temp_value, eax ;// store in a temp spot (as an integer)

    float part

        random number = temp_value * scale * (+/-) 1

        fld randomScale
        fimul temp_value;// load as an iteger
        inc st_change
        fstp lastValue  ;// store as a float

*/ comment ~



comment ~ /*


model of this object's algorithm:

    S       r           n               A       X

    seed[]  reseed()    last_value[]    gain()  output[]
                        next_value()

states we need to account for:

    yn  dn  ng  np  npos    yr  dr  rp  rpos    yS      yA  dA
    nn  sn  ne  nn  nneg    nr  sr  rn  rneg    nS      nA  sA
                nb                  rb

    total combinations = 9216


tools:  n_check_frame() checks for n trigger across frame
        s_check_frame() checks for r trigger across frame
        next_value()    calculate the next random number
        static_output()


arg!!   still too complicated
        let's try computing all the loops we'll need
        then figure out how to get to them


loop sets:  (sub labels not included)


    state   sets
    -----   ----------------

    dr_dn   rp_ne_np    rn_ne_np        each of these sets requires three different types
            rp_ne_nn    rn_ne_nn        one each for dA, sA, nA
            rp_ne_nb    rn_ne_nb        if sA and A=0, then skip entire thing (grab last triggers)

            rp_ng_np    rn_ng_np        reseed requires same for dS and sS,nS
            rp_ng_nn    rn_ng_nn        may be worthwhile to make reseed a seperate operation
                                        and count on the fact that it's not an oft' used operation
    dn (sr and nr)

            ne_np
            ne_nn
            ne_nb

            ng_np
            ng_nn

    dr_sn_ne    (sn_ne and nn_ne)

            rp_sn_ne    rn_sn_ne

    dr_sn_ng    (sn_ng, nn_ng)

            rp_sn_ng    rn_sn_ng


there are 19 sets for changing triggers
each set requies three output forumulas for dA,sA and nA
each also requires three reseed, for dS, sS and nS

most sets have four sub loops

for both triggers static and edge:
    check frame to get the current value
    then do the a_loop[]

next_value/output functions

    ne scans store output from eax, and iterate edi
        unless dA, then output is done from fpu
    ng scans store output from fpu, and do NOT iterate edi


*/ comment ~



comment ~ /*

loop sets

    loop sets with two triggers are set up as four loops
    jumping from one loop to another may also invlove reseed or calculating the next value

    ex: rn_ne_nn

        rn: reseed on negative edges
        ne: next is an edge
        nn: calulate next value on negative edges

        jump into loop at the proper spot
        as long as ch and cl are initialized correctly
        it will catch triggers across frames

        iterate comes in three flavours, dA, sA, and nA
        sA must also be prepared so we can skip if A=0
        exit must jump to proper clean up code

    condensed form:

    rn_ne_nn:   if      then        and jmp_to

        rnn_nnn:
                rpos                    05
        01      npos                    06
        02      iterate
                exit
        rnn_nnp:
                rpos                    07
        03      nneg    next_value      08
        04      iterate
                exit
        rnp_nnn:
                rneg    reseed          01
        05      npos                    02
        06      iterate
                exit
        rnp_nnp
                rneg    reseed          03
        07      nneg    next_value      04
        08      iterate
                exit


    expanded form (example assumes sA and dS)

                if      then        and jmp_to
    rn_ne_nn

        rnn_nnn:
                rpos                    05      and ch, BYTE PTR [ebp+edx*4]
                                                jns 05
        01      npos                    06      and cl, BYTE PTR [ebx+edx*4]
                                                jns 06
        02      iterate                         stosd
                                                inc edx
                                                cmp edx, max
                                                jb rnn_nnn
                                                jmp exit
        rnn_nnp:
                rpos                    07      and ch, BYTE PTR [ebp+edx*4]
                                                jns 07
        03      nneg    next_value      08      or cl, BYTE PTR [ebx+edx*4]
                                                jns next_value_08

        04      iterate                         stosd
                                                inc edx
                                                cmp edx, max
                                                jb rnn_nnp
                                                jmp exit

        rnp_nnn:
                rneg    reseed          01      or ch, BYTE PTR [ebp]
                                                js reseed_01
        05      npos                    02      and cl, BYTE PTR [ebx+edx*4]
                                                jns 02
        06      iterate                         stosd
                                                inc edx
                                                cmp edx, max
                                                jb rnp_nnn
                                                jmp exit
        rnp_nnp
                rneg    reseed          03      or ch, BYTE PTR [ebp+edx*4]
                                                js reseed_03
        07      nneg    next_value      04      or cl, BYTE PTR [ebx+edx*4]
                                                js next_value_04
        08      iterate                         stosd
                                                inc edx
                                                cmp edx, max
                                                jb rnp_nnn
                                                jmp exit
        next_value_08:

            NEXT_VALUE_NE_SA
            jmp 08

        next_value_04:

            NEXT_VALUE_NE_SA
            jmp 04

        reseed_01:

            RESEED_DS
            jmp 01

        reseed_03:

            RESEED_DS
            jmp 05



*/ comment ~


















comment ~ /*
dr_dn

    rp_ne_np    rp_ne_nn    rp_ne_nb
    rn_ne_np    rn_ne_nn    rn_ne_nb
    rb_ne_np    rb_ne_nn    rb_ne_nb

*/ comment ~




comment ~ /*

    accounting for gain

    if dA, then do not iterate edi, values are xfered via the fpu
    otherwise, the output value must be stored in eax and edi IS iterated

    for sA, gain mustt be loaded in FPU.st(2)

    registers:  esi is always the gain data

    nA      eax is seed and output                  edi iterates
    sA      eax is ouput, not seed                  edi iterate
    dA      eax not used except for temp storage    edi does NOT iterate

*/ comment ~





NE_OUTPUT MACRO A:req

    ;// purpose, load eax with the output value to store
    ;//          does NOT store the output

    ;// eax already has st_last
    ;// and we want to convert it to output

    IFIDN <A>,<nA>
        ;// eax already loaded
    ELSEIFIDN <A>,<sA>
        fld st_last         ;// V   scale   gain
        fmul st, st(2)
        fstp st_temp        ;// scale   gain
        mov eax, st_temp
    ELSEIFIDN <A>,<dA>
        ;// iterate will take care of this
    ELSEIFIDN <A>,<dA_gate>
        ;// iterate will take care of this
    ELSE
        .ERR <A not defined correctly>
    ENDIF

    ENDM



NE_ITERATE MACRO A:REQ, lab:REQ, exit:req

    ;// purpose:    fall through for each of the four loops
    ;//             generate the correct output (account for gain)

    ;// this builds the iterator for each of the four loops
    ;// used for loop fall through

    ;// this does NOT iterate the random sequence


    IFIDN <A>,<nA>

        ;// nothing special to do
        ;// eax must have the value to store

        inc edx     ;// iterate
        stosd       ;// store
        cmp edx, SAMARY_LENGTH
        jb lab
        jmp exit

    ELSEIFIDN <A>,<sA>

        ;// nothing special to do
        ;// eax must have the value to store

        inc edx     ;// iterate
        stosd       ;// store
        cmp edx, SAMARY_LENGTH
        jb lab
        jmp exit

    ELSEIFIDN <A>,<dA>

        ;// have to compute the value based on st_last

        fld DWORD PTR [esi+edx*4]   ;// gain
        fld st_last     ;// V   gain    scale
        fmul
        fstp DWORD PTR [edi+edx*4]
        inc edx         ;// iterate
        cmp edx, SAMARY_LENGTH
        jb lab
        jmp exit

    ELSEIFIDN <A>,<dA_gate>

        ;// have to compute the value based on st_last

        fld DWORD PTR [esi+edx*4]   ;// gain
        fild st_last        ;// V   gain    scale
        fmul st, st(2)
        fmul
        fstp DWORD PTR [edi+edx*4]
        inc edx         ;// iterate
        cmp edx, SAMARY_LENGTH
        jb lab
        jmp exit

    ELSE
        .ERR <A not defined correctly>
    ENDIF


    ENDM




NE_NEXT MACRO A:req, lab:req, exit:req

;// purpose:    compute the next random value, build output, and iterate


    mov st_temp, edx    ;// always preserve edx

    IFIDN <A>,<nA>

        ;// eax holds seed and last value

        mul random_multRand     ;// with out undo hassle
        inc eax
        mov st_last, eax        ;// store in last

        fild st_last        ;// load as an integer
        fmul st, st(1)      ;// multiply by random scale
        mov edx, st_temp        ;// done with edx
        or st_change, 80000001h ;// always set changing (in this case, set that we changed because of a trigger)
        fst st_last         ;// store as a float
        inc edx
        fstp DWORD PTR [edi]    ;// store in output
        mov eax, st_last;// reload output
        add edi, 4
        cmp edx, SAMARY_LENGTH
        jb lab
        jmp exit

    ELSEIFIDN <A>,<sA>

        ;// eax has output value, not the seed

        mov eax, st_last
        mul random_multRand     ;// with out undo hassle
        inc eax
        mov st_last, eax        ;// store in last (temp)

        fild st_last    ;// load as an integer
        fmul st, st(1)  ;// multiply by random scale
        mov edx, st_temp;// done with edx
        or st_change, 80000001h ;// always set changing (in this case, set that we changed because of a trigger)
        fst st_last     ;// store as a float
        fmul st, st(2)  ;// multiply to get gain
        fst st_temp     ;// store as temp
        inc edx
        fstp DWORD PTR [edi]    ;// store in output data
        mov eax, st_temp    ;// reload output
        add edi, 4
        cmp edx, SAMARY_LENGTH
        jb lab
        jmp exit

    ELSEIFIDN <A>,<dA>

        ;// eax means nothing, we do all in fpu

        mov eax, st_last
        mul random_multRand     ;// with out undo hassle
        inc eax
        mov st_last, eax        ;// store in last


        fild st_last    ;// load as an integer
        fmul st, st(1)  ;// multiply by random scale
        mov edx, st_temp;// done with edx
        or st_change, 80000001h ;// always set changing (in this case, set that we changed because of a trigger)
        fst st_last     ;// store as a float
        fmul DWORD PTR [esi+edx*4];// multiply to get gain
        fstp DWORD PTR [edi+edx*4]  ;// store in output

        inc edx
        cmp edx, SAMARY_LENGTH
        jb lab
        jmp exit

    ELSE
        .ERR <A not defined correctly>
    ENDIF



    ENDM














DR_DN_NE MACRO r:req, n:req, A:req, exit:req

    ;// purpose:    build the quad loops for drdn and any combination of S and A
    ;// acceptable states   (next on edge only)
    ;//
    ;// ne  np  rp  dA
    ;//     nn  rn  sA
    ;//     nb  rb  nA      27 states

    ;// entrance parser
    LOCAL neg_start, pos_start

    ;// there are four loops
    LOCAL neg_neg, neg_neg_01, neg_neg_02
    LOCAL neg_pos, neg_pos_01, neg_pos_02
    LOCAL pos_neg, pos_neg_01, pos_neg_02
    LOCAL pos_pos, pos_pos_01, pos_pos_02

    ;// jump label suffix is where we exit to
    LOCAL reseed_neg_neg, reseed_pos_pos, reseed_pos_neg, reseed_neg_pos
    LOCAL next_neg_neg, next_pos_pos, next_pos_neg, next_neg_pos

IFDEF BRAGGING_RIGHTS
ECHO DR_DN_NE
ENDIF

        xor edx, edx    ;// always clear the count

    ;// jump into the correct spot

        or ch, ch
        js neg_start
    pos_start:
        or cl, cl
        js pos_neg
        jmp pos_pos
    neg_start:
        or cl, cl
        jns neg_pos

neg_neg:        and ch, BYTE PTR [ebp+edx*4+3]  ;// if no sign, this is a pos edge
                IFIDN     <r>,<rp>  ;// reseed on pos edge
                    jns reseed_pos_neg
                ELSEIFIDN <r>,<rn>  ;// reseed on neg edge
                    jns pos_neg_01
                ELSEIFIDN <r>,<rb>  ;// reseed on any edge
                    jns reseed_pos_neg
                ELSE
                    .ERR <r not defined correctly>
                ENDIF
    neg_neg_01: and cl, BYTE PTR [ebx+edx*4+3]  ;// if no sign, this is a pos edge
                IFIDN     <n>,<np>  ;// next on pos edge
                    jns next_neg_pos
                ELSEIFIDN <n>,<nn>  ;// next on neg edge
                    jns neg_pos_02
                ELSEIFIDN <n>,<nb>  ;// next on any edge
                    jns next_neg_pos
                ELSE
                    .ERR <n not defined correctly>
                ENDIF
    neg_neg_02: NE_ITERATE A, neg_neg, exit


neg_pos:        and ch, BYTE PTR [ebp+edx*4+3]  ;// if no sign, this is a pos edge
                IFIDN     <r>,<rp>  ;// reseed on pos edge
                    jns reseed_pos_pos
                ELSEIFIDN <r>,<rn>  ;// reseed on neg edge
                    jns pos_pos_01
                ELSEIFIDN <r>,<rb>  ;// reseed on any edge
                    jns reseed_pos_pos
                ELSE
                    .ERR <r not defined correctly>
                ENDIF
    neg_pos_01: or cl, BYTE PTR [ebx+edx*4+3]   ;// if sign, this is a neg edge
                IFIDN     <n>,<np>  ;// next on pos edge
                    js  neg_neg_02
                ELSEIFIDN <n>,<nn>  ;// next on neg edge
                    js  next_neg_neg
                ELSEIFIDN <n>,<nb>  ;// next on any edge
                    js  next_neg_neg
                ELSE
                    .ERR <n not defined correctly>
                ENDIF
    neg_pos_02: NE_ITERATE A, neg_pos, exit


pos_neg:        or ch, BYTE PTR [ebp+edx*4+3]   ;// if sign, this is a neg edge
                IFIDN     <r>,<rp>  ;// reseed on pos edge
                    js  neg_pos_01
                ELSEIFIDN <r>,<rn>  ;// reseed on neg edge
                    js  reseed_neg_neg
                ELSEIFIDN <r>,<rb>  ;// reseed on any edge
                    js  reseed_neg_neg
                ELSE
                    .ERR <r not defined correctly>
                ENDIF
    pos_neg_01: and cl, BYTE PTR [ebx+edx*4+3]  ;// if no sign, this is a pos edge
                IFIDN     <n>,<np>  ;// next on pos edge
                    jns next_pos_pos
                ELSEIFIDN <n>,<nn>  ;// next on neg edge
                    jns pos_pos_02
                ELSEIFIDN <n>,<nb>  ;// next on any edge
                    jns next_pos_pos
                ELSE
                    .ERR <n not defined correctly>
                ENDIF
    pos_neg_02: NE_ITERATE A, pos_neg, exit


pos_pos:        or ch, BYTE PTR [ebp+edx*4+3]   ;// if sign, this is a neg edge
                IFIDN     <r>,<rp>  ;// reseed on pos edge
                    js  neg_pos_01
                ELSEIFIDN <r>,<rn>  ;// reseed on neg edge
                    js  reseed_neg_pos
                ELSEIFIDN <r>,<rb>  ;// reseed on any edge
                    js  reseed_neg_pos
                ELSE
                    .ERR <r not defined correctly>
                ENDIF
    pos_pos_01: or cl, BYTE PTR [ebx+edx*4+3]   ;// if sign, this is a neg edge
                IFIDN     <n>,<np>  ;// next on pos edge
                    js  pos_neg_02
                ELSEIFIDN <n>,<nn>  ;// next on neg edge
                    js  next_pos_neg
                ELSEIFIDN <n>,<nb>  ;// next on any edge
                    js  next_pos_neg
                ELSE
                    .ERR <n not defined correctly>
                ENDIF
    pos_pos_02: NE_ITERATE A, pos_pos, exit


    IFIDN <r>,<rp>
    reseed_pos_pos: call reseed
                    NE_OUTPUT   A
                    jmp pos_pos_01
    ENDIF
    IFIDN <r>,<rb>
    reseed_pos_pos: call reseed
                    NE_OUTPUT   A
                    jmp pos_pos_01
    ENDIF

    IFIDN <r>,<rp>
    reseed_pos_neg: call reseed
                    NE_OUTPUT   A
                    jmp pos_neg_01
    ENDIF
    IFIDN <r>,<rb>
    reseed_pos_neg: call reseed
                    NE_OUTPUT   A
                    jmp pos_neg_01
    ENDIF

    IFIDN <r>,<rn>
    reseed_neg_pos: call reseed
                    NE_OUTPUT   A
                    jmp neg_pos_01
    ENDIF
    IFIDN <r>,<rb>
    reseed_neg_pos: call reseed
                    NE_OUTPUT   A
                    jmp neg_pos_01
    ENDIF


    IFIDN <r>,<rn>
    reseed_neg_neg: call reseed
                    NE_OUTPUT   A
                    jmp neg_neg_01
    ENDIF
    IFIDN <r>,<rb>
    reseed_neg_neg: call reseed
                    NE_OUTPUT   A
                    jmp neg_neg_01
    ENDIF



    IFIDN <n>,<np>
    next_pos_pos:   NE_NEXT A, pos_pos, exit
    ENDIF
    IFIDN <n>,<nb>
    next_pos_pos:   NE_NEXT A, pos_pos, exit
    ENDIF

    IFIDN <n>,<nn>
    next_pos_neg:   NE_NEXT A, pos_neg, exit
    ENDIF
    IFIDN <n>,<nb>
    next_pos_neg:   NE_NEXT A, pos_neg, exit
    ENDIF

    IFIDN <n>,<np>
    next_neg_pos:   NE_NEXT A, neg_pos, exit
    ENDIF
    IFIDN <n>,<nb>
    next_neg_pos:   NE_NEXT A, neg_pos, exit
    ENDIF

    IFIDN <n>,<nn>
    next_neg_neg:   NE_NEXT A, neg_neg, exit
    ENDIF
    IFIDN <n>,<nb>
    next_neg_neg:   NE_NEXT A, neg_neg, exit
    ENDIF

    ENDM





comment ~ /*
dr_dn

    rp_ng_np    these all have the same sub label formats
    rn_ng_np
    rp_ng_nn
    rn_ng_nn

*/ comment ~


comment ~ /*



    example:    rp_ng_np

        rp: reseed on pos edge
        ng: next is a gate
        np: next value when n is positive

        neg_neg

            rpos ?  reseed  jmp pos_neg_01
        01  npos ?          jmp neg_pos_02
        02  iterate

        neg_pos

            rpos ?  reseed  jmp pos_pos_01
        01  nneg ?          jmp neg_pos_02
        02  next_value
            iterate

        pos_neg

            rneg ?          jmp neg_neg_01
        01  npos ?          jmp neg_pos_02
        02  iterate

        pos_pos

            rneg ?          jmp neg_pos_01
        01  nneg ?          jmp pos_neg_02
        02  next_value
            iterate


next_value

    for ng we always want to use the fpu to store with

*/ comment ~

NG_OUTPUT MACRO A:req

    ;// purpose: convert st_last into a proper output value
    ;// used after reseed

    fstp st     ;// dump whats in there now
    fld st_last ;// load the new seed

    IFIDN     <A>,<nA>
    ELSEIFIDN <A>,<sA>
        fmul st, st(2)
    ELSEIFIDN <A>,<dA>
        fmul DWORD PTR [esi+edx*4];// multiply to get gain
    ELSE
        .ERR <A not defined correctly>
    ENDIF

    ENDM





;// version that worked, why did we change this ??

NG_NEXT MACRO A:REQ

    ;// purpose: generate and store the next random value

        mov st_temp, edx    ;// always store edx

        fstp st             ;// dump old value

        mov eax, st_last
        mul random_multRand ;// with out undo hassle
        inc eax
        mov st_last, eax    ;// store in last

        fild st_last    ;// load as an integer
        fmul st, st(1)  ;// multiply by random scale
        mov edx, st_temp    ;// done with edx
        inc st_change   ;// always set changing
    ;   fst st_last     ;// store as a float    (bug ABox227: st_last must always be an integer)
                        ;// (bug ABox227: removed store instruction)

    IFIDN     <A>,<nA>
    ELSEIFIDN <A>,<sA>
        fmul st, st(2)
    ELSEIFIDN <A>,<dA>
        fmul DWORD PTR [esi+edx*4];// multiply to get gain
    ELSE
        .ERR <A not defined correctly>
    ENDIF

    ENDM



NG_ITERATE MACRO n:req, A:req, edge:req, lab:req, exit:req
;// problem with this
;// dA is not grabbing A when the values does not change

    ;// purpose: conditional code to generate the next value for gated next triggers
    ;// always the fall-through in the NG loops

    IFIDN     <n>, <np>
        IFIDN <edge>,<_pos>
            NG_NEXT A
        ENDIF
    ELSEIFIDN <n>,<nn>
        IFIDN <edge>,<_neg>
            NG_NEXT A
        ENDIF
    ELSE
        .ERR <n not specifed correctly>
    ENDIF

    fst DWORD PTR [edi+edx*4]   ;// store in output
    inc edx
    cmp edx, SAMARY_LENGTH
    jb lab
    jmp exit

    ENDM



DR_DN_NG MACRO r:req, n:req, A:req, exit:req

    ;// purpose:    build the quad loops for drdn and any combination of S and A

    ;// acceptable states   next gate (only)
    ;//
    ;// ng  np  rp  dA
    ;//     nn  rn  sA
    ;//         rb  nA      18 states

    ;// entrance parser
    LOCAL neg_start, pos_start

    ;// there are four loops
    LOCAL neg_neg, neg_neg_01, neg_neg_02
    LOCAL neg_pos, neg_pos_01, neg_pos_02
    LOCAL pos_neg, pos_neg_01, pos_neg_02
    LOCAL pos_pos, pos_pos_01, pos_pos_02

    ;// jump label suffix is where we exit to
    LOCAL reseed_neg_neg, reseed_pos_pos, reseed_pos_neg, reseed_neg_pos

IFDEF BRAGGING_RIGHTS
ECHO DR_DN_NG
ENDIF

    xor edx, edx    ;// always clear the count

    ;// jump into the correct spot

        or ch, ch
        js neg_start
    pos_start:
        or cl, cl
        js pos_neg
        jmp pos_pos
    neg_start:
        or cl, cl
        jns neg_pos


neg_neg:        and ch, BYTE PTR [ebp+edx*4+3]  ;// if no sign, this is a pos edge
                IFIDN     <r>,<rp>  ;// reseed on pos edge
                    jns reseed_pos_neg
                ELSEIFIDN <r>,<rn>  ;// reseed on neg edge
                    jns pos_neg_01
                ELSEIFIDN <r>,<rb>  ;// reseed on any edge
                    jns reseed_pos_neg
                ELSE
                    .ERR <r not defined correctly>
                ENDIF
    neg_neg_01: and cl, BYTE PTR [ebx+edx*4+3]  ;// if no sign, this is a pos level
                IFIDN     <n>,<np>  ;// next on pos level
                    jns neg_pos_02
                ELSEIFIDN <n>,<nn>  ;// next on neg level
                    jns neg_pos_02
                ELSEIFIDN <n>,<nb>
                    .ERR <both edge gate not allowed>
                ELSE
                    .ERR <n not defined correctly>
                ENDIF
    neg_neg_02: NG_ITERATE  n, A, _neg, neg_neg, exit



neg_pos:        and ch, BYTE PTR [ebp+edx*4+3]  ;// if no sign, this is a pos edge
                IFIDN     <r>,<rp>  ;// reseed on pos edge
                    jns reseed_pos_pos
                ELSEIFIDN <r>,<rn>  ;// reseed on neg edge
                    jns pos_pos_01
                ELSEIFIDN <r>,<rb>  ;// reseed on any edge
                    jns reseed_pos_pos
                ELSE
                    .ERR <r not defined correctly>
                ENDIF
    neg_pos_01: or cl, BYTE PTR [ebx+edx*4+3]   ;// if sign, this is a neg level
                IFIDN     <n>,<np>  ;// next on pos level
                    js  neg_neg_02
                ELSEIFIDN <n>,<nn>  ;// next on neg level
                    js  neg_neg_02
                ELSEIFIDN <n>,<nb>
                    .ERR <both edge gate not allowed>
                ELSE
                    .ERR <n not defined correctly>
                ENDIF
    neg_pos_02: NG_ITERATE  n, A, _pos, neg_pos, exit


pos_neg:        or ch, BYTE PTR [ebp+edx*4+3]   ;// if sign, this is a neg edge
                IFIDN     <r>,<rp>  ;// reseed on pos edge
                    js  neg_pos_01
                ELSEIFIDN <r>,<rn>  ;// reseed on neg edge
                    js  reseed_neg_neg
                ELSEIFIDN <r>,<rb>  ;// reseed on any edge
                    js  reseed_neg_neg
                ELSE
                    .ERR <r not defined correctly>
                ENDIF
    pos_neg_01: and cl, BYTE PTR [ebx+edx*4+3]  ;// if no sign, this is a pos level
                IFIDN     <n>,<np>  ;// next on pos level
                    jns pos_pos_02
                ELSEIFIDN <n>,<nn>  ;// next on neg level
                    jns pos_pos_02
                ELSEIFIDN <n>,<nb>
                    .ERR <both edge gate not allowed>
                ELSE
                    .ERR <n not defined correctly>
                ENDIF
    pos_neg_02: NG_ITERATE  n, A, _neg, pos_neg, exit


pos_pos:        or ch, BYTE PTR [ebp+edx*4+3]   ;// if sign, this is a neg edge
                IFIDN     <r>,<rp>  ;// reseed on pos edge
                    js  neg_pos_01
                ELSEIFIDN <r>,<rn>  ;// reseed on neg edge
                    js  reseed_neg_pos
                ELSEIFIDN <r>,<rb>  ;// reseed on any edge
                    js reseed_neg_pos
                ELSE
                    .ERR <r not defined correctly>
                ENDIF
    pos_pos_01: or cl, BYTE PTR [ebx+edx*4+3]   ;// if sign, this is a neg level
                IFIDN     <n>,<np>  ;// next on pos level
                    js  pos_neg_02
                ELSEIFIDN <n>,<nn>  ;// next on neg level
                    js  pos_neg_02
                ELSEIFIDN <n>,<nb>
                    .ERR <both edge gate not allowed>
                ELSE
                    .ERR <n not defined correctly>
                ENDIF
    pos_pos_02: NG_ITERATE  n, A, _pos, pos_pos, exit


    IFIDN <r>,<rp>
    reseed_pos_pos: call reseed
                    NG_OUTPUT A
                    jmp pos_pos_01
    ENDIF
    IFIDN <r>,<rb>
    reseed_pos_pos: call reseed
                    NG_OUTPUT A
                    jmp pos_pos_01
    ENDIF

    IFIDN <r>,<rp>
    reseed_pos_neg: call reseed
                    NG_OUTPUT A
                    jmp pos_neg_01
    ENDIF
    IFIDN <r>,<rb>
    reseed_pos_neg: call reseed
                    NG_OUTPUT A
                    jmp pos_neg_01
    ENDIF

    IFIDN <r>,<rn>
    reseed_neg_pos: call reseed
                    NG_OUTPUT A
                    jmp neg_pos_01
    ENDIF
    IFIDN <r>,<rb>
    reseed_neg_pos: call reseed
                    NG_OUTPUT A
                    jmp neg_pos_01
    ENDIF

    IFIDN <r>,<rn>
    reseed_neg_neg: call reseed
                    NG_OUTPUT A
                    jmp neg_neg_01
    ENDIF
    IFIDN <r>,<rb>
    reseed_neg_neg: call reseed
                    NG_OUTPUT A
                    jmp neg_neg_01
    ENDIF


    ENDM





comment ~ /*
dn (sr and nr)

    ne_np       these all have the same sub label format
    ne_nn
    ne_nb

*/ comment ~


SR_DN_NE    MACRO   n:req, A:req, exit:req

    ;// purpose: generate the loops for edge trigered next
    ;//          ignore reseed entirely

    ;// acceptable states   (next on edge only)
    ;//
    ;// ne  np  dA
    ;//     nn  sA
    ;//     nb  nA      9 states

    ;// there are two loops
    LOCAL neg_00, neg_01
    LOCAL pos_00, pos_01

    ;// jump label suffix is where we exit to
    LOCAL next_neg, next_pos

IFDEF BRAGGING_RIGHTS
ECHO SR_DN_NE
ENDIF

    xor edx, edx    ;// always clear the count

    ;// jump into the correct spot

    or cl, cl
    jns pos_00

neg_00:     and cl, BYTE PTR [ebx+edx*4+3]  ;// if no sign, this is a pos edge
            IFIDN     <n>,<np>  ;// next on pos edge
                jns next_pos
            ELSEIFIDN <n>,<nn>  ;// next on neg edge
                jns pos_01
            ELSEIFIDN <n>,<nb>  ;// next on any edge
                jns next_pos
            ELSE
                .ERR <n not defined correctly>
            ENDIF
    neg_01: NE_ITERATE A, neg_00, exit

pos_00:     or cl, BYTE PTR [ebx+edx*4+3]   ;// if sign, this is a neg edge
            IFIDN     <n>,<np>  ;// next on pos edge
                js  neg_01
            ELSEIFIDN <n>,<nn>  ;// next on neg edge
                js  next_neg
            ELSEIFIDN <n>,<nb>  ;// next on any edge
                js  next_neg
            ELSE
                .ERR <n not defined correctly>
            ENDIF
    pos_01: NE_ITERATE A, pos_00, exit


    IFIDN <n>,<np>
    next_pos:   NE_NEXT A, pos_00, exit
    ENDIF
    IFIDN <n>,<nb>
    next_pos:   NE_NEXT A, pos_00, exit
    ENDIF

    IFIDN <n>,<nn>
    next_neg:   NE_NEXT A, neg_00, exit
    ENDIF
    IFIDN <n>,<nb>
    next_neg:   NE_NEXT A, neg_00, exit
    ENDIF


    ENDM



comment ~ /*
dn (sr and nr)

    ng_np       these all have the same sub label format
    ng_nn

*/ comment ~

SR_DN_NG    MACRO n:req, A:req, exit:req

    ;// purpose:    build the dual loops for srdn and any combination of S and A

    ;// acceptable states   next gate (only)
    ;//
    ;// ng  np  dA
    ;//     nn  sA
    ;//         nA      6 states


    ;// there are two loops
    LOCAL neg_00, neg_01
    LOCAL pos_00, pos_01

IFDEF BRAGGING_RIGHTS
ECHO SR_DN_NG
ENDIF

    xor edx, edx    ;// always clear the count

    ;// jump into the correct spot

    or cl, cl
    jns pos_00


neg_00:     and cl, BYTE PTR [ebx+edx*4+3]  ;// if no sign, this is a pos edge
            IFIDN     <n>,<np>  ;// next on pos edge
                jns pos_01
            ELSEIFIDN <n>,<nn>  ;// next on neg edge
                jns pos_01
            ELSEIFIDN <n>,<nb>  ;// next on any edge
                .ERR <both edge gate not allowed>
            ELSE
                .ERR <n not defined correctly>
            ENDIF
    neg_01: NG_ITERATE  n, A, _neg, neg_00, exit


pos_00:     or cl, BYTE PTR [ebx+edx*4+3]   ;// if sign, this is a neg edge
            IFIDN     <n>,<np>  ;// next on pos edge
                js  neg_01
            ELSEIFIDN <n>,<nn>  ;// next on neg edge
                js  neg_01
            ELSEIFIDN <n>,<nb>  ;// next on any edge
                .ERR <both edge gate not allowed>
            ELSE
                .ERR <n not defined correctly>
            ENDIF
    pos_01: NG_ITERATE  n, A, _pos, pos_00, exit


    ENDM







comment ~ /*
dr_sn_ne    (sn_ne and nn_ne)

    rp_sn_ne    these all have the same sub label format
    rn_sn_ne

*/ comment ~

DR_SN_NE MACRO r:req, A:req, exit

    ;// purpose build to the dual loops for DR SN triggers

    ;// states

    ;//     rp  dA
    ;//     rn  sA
    ;//     rb  nA      9 states

    ;// also: rx and NG when it cannot generate new values

    ;// there are four loops
    LOCAL neg_00, neg_01
    LOCAL pos_00, pos_01

    ;// jump label suffix is where we exit to
    LOCAL reseed_neg, reseed_pos

IFDEF BRAGGING_RIGHTS
ECHO DR_SN_NE
ENDIF

    xor edx, edx    ;// always clear the count

    ;// jump into the correct spot

    or ch, ch
    jns pos_00

neg_00:     and ch, BYTE PTR [ebp+edx*4+3]  ;// if no sign, this is a pos edge
            IFIDN     <r>,<rp>  ;// reseed on pos edge
                jns reseed_pos
            ELSEIFIDN <r>,<rn>  ;// reseed on neg edge
                jns pos_01
            ELSEIFIDN <r>,<rb>  ;// reseed on any edge
                jns reseed_pos
            ELSE
                .ERR <r not defined correctly>
            ENDIF
    neg_01: NE_ITERATE A, neg_00, exit


pos_00:     or ch, BYTE PTR [ebp+edx*4+3]   ;// if sign, this is a neg edge
            IFIDN     <r>,<rp>  ;// reseed on pos edge
                js  neg_01
            ELSEIFIDN <r>,<rn>  ;// reseed on neg edge
                js  reseed_neg
            ELSEIFIDN <r>,<rb>  ;// reseed on any edge
                js  reseed_neg
            ELSE
                .ERR <r not defined correctly>
            ENDIF
    pos_01: NE_ITERATE A, pos_00, exit



    IFIDN <r>,<rp>
    reseed_pos: call reseed
                NE_OUTPUT   A
                jmp pos_01
    ENDIF
    IFIDN <r>,<rb>
    reseed_pos: call reseed
                NE_OUTPUT   A
                jmp pos_01
    ENDIF

    IFIDN <r>,<rn>
    reseed_neg: call reseed
                NE_OUTPUT   A
                jmp neg_01
    ENDIF
    IFIDN <r>,<rb>
    reseed_neg: call reseed
                NE_OUTPUT   A
                jmp neg_01
    ENDIF


    ENDM





comment ~ /*
dr_sn_ng    (sn_ng, nn_ng)

    rp_sn_ng    these all have the same sub label format
    rn_sn_ng

*/ comment ~


DR_SN_NG MACRO r:req, A:req, exit:req

    ;// purpose build to the dual loops for DR SN NG triggers

    ;// this should only be used when ALWAYS generating new values

    ;// states

    ;//     rp  dA
    ;//     rn  sA
    ;//     rb  nA      9 states


    ;// there are two loops
    LOCAL neg_00, neg_01
    LOCAL pos_00, pos_01

    ;// jump label suffix is where we exit to
    LOCAL reseed_neg, reseed_pos

IFDEF BRAGGING_RIGHTS
ECHO DR_SN_NG
ENDIF

    xor edx, edx    ;// always clear the count

    ;// jump into the correct spot

    or ch, ch
    jns pos_00


neg_00:     and ch, BYTE PTR [ebp+edx*4+3]  ;// if no sign, this is a pos edge
            IFIDN     <r>,<rp>  ;// reseed on pos edge
                jns reseed_pos
            ELSEIFIDN <r>,<rn>  ;// reseed on neg edge
                jns pos_01
            ELSEIFIDN <r>,<rb>  ;// reseed on any edge
                jns reseed_pos
            ELSE
                .ERR <r not defined correctly>
            ENDIF
    neg_01: NG_ITERATE  nn, A, _neg, neg_00, exit


pos_00:     or ch, BYTE PTR [ebp+edx*4+3]   ;// if sign, this is a neg edge
            IFIDN     <r>,<rp>  ;// reseed on pos edge
                js  neg_01
            ELSEIFIDN <r>,<rn>  ;// reseed on neg edge
                js  reseed_neg
            ELSEIFIDN <r>,<rb>  ;// reseed on any edge
                js  reseed_neg
            ELSE
                .ERR <r not defined correctly>
            ENDIF
    pos_01: NG_ITERATE  np, A, _pos, pos_00, exit


    IFIDN <r>,<rp>
    reseed_pos: call reseed
                NG_OUTPUT A
                jmp pos_01
    ENDIF
    IFIDN <r>,<rb>
    reseed_pos: call reseed
                NG_OUTPUT A
                jmp pos_01
    ENDIF

    IFIDN <r>,<rn>
    reseed_neg: call reseed
                NG_OUTPUT A
                jmp neg_01
    ENDIF
    IFIDN <r>,<rb>
    reseed_neg: call reseed
                NG_OUTPUT A
                jmp neg_01
    ENDIF

    ENDM



comment ~ /*
-----------------------------------------------------------------------------------

macro catalog for loop generators

    DR_DN_NE    27 states
    DR_DN_NG    18 states
    SR_DN_NE    9 states
    SR_DN_NG    6 states
    DR_SN_NE    9 states + special
    DR_SN_NG    9 states

----------------------------------------------------------------------------------
*/ comment ~





ASSUME_AND_ALIGN
rand_Calc   PROC

    ASSUME esi:PTR OSC_OBJECT

;// pretest A and skip this whole operation if it's zero and not changing

    OSC_TO_PIN_INDEX esi, edx, 0    ;// A pin
    OSC_TO_PIN_INDEX esi, edi,  1   ;// output pin
    DEBUG_IF <!![edi].pPin>         ;// supposed to be connected to schedule for calc
    mov edx, [edx].pPin             ;// get A's connection
    xor eax, eax                    ;// clear for future esting
    .IF edx && !([edx].dwStatus & PIN_CHANGING) ;// connected and not changing ?
        mov edx, [edx].pData        ;// get the data pointer
        or eax, DWORD PTR [edx]     ;// test for a value of zero
        .IF ZERO?                   ;// zero ?

            btr [edi].dwStatus, LOG2(PIN_CHANGING)  ;// reset and test the changing bit
            mov edi, [edi].pData    ;// get the data pointer
            .IF CARRY? || eax != DWORD PTR [edi]    ;// if previously changing or not equal now
                mov ecx, SAMARY_LENGTH  ;// fill the whole thing with zero
                rep stosd
            .ENDIF

            ret     ;// and exit exit exit !

        .ENDIF

    .ENDIF


;// enter this function for real

    push ebp
    push esi


;// DEBUG_IF <esi==00A137A0h>   ;// bug hunt


    call_depth = 0
    stack_size = 14h

    sub esp, stack_size

;// stack looks like this
;//
;// st_change   st_last st_seed st_bSeed    st_temp esi ebp     ret
;// 00          04      08       0C         10      14  18

    st_change   TEXTEQU <DWORD PTR [esp+00h+call_depth*4]>
    st_last     TEXTEQU <DWORD PTR [esp+04h+call_depth*4]>
    st_seed     TEXTEQU <DWORD PTR [esp+08h+call_depth*4]>
    st_bSeed    TEXTEQU <DWORD PTR [esp+0Ch+call_depth*4]>
    st_temp     TEXTEQU <DWORD PTR [esp+10h+call_depth*4]>
    st_esi      TEXTEQU <DWORD PTR [esp+14h+call_depth*4]>

    mov eax, [edi].dwUser   ;// get the last value (not the last output value)
    xor ECX, ECX            ;// ecx will be byte values for last triggers
    mov EDX, [esi].dwUser   ;// edx has dwUser until the loops start, then it counts
    mov st_last, eax        ;// store locally
    mov st_change, 0        ;// zero the changing (don't use ecx)

    ;// addendum:
    ;//
    ;//     if st_change has the sign bit set, a new graphic will be calulated
    ;//     based on the first value of the ouput
    ;//
    ;//     if any of the other bits are set, then the signal is set as changing







;////////////////////////////////////////////////////////////////////
;//
;//   SECTION 1     parse the object's state
;//                 end up at one of 8 locations in section 2
;//
;// how the labels work:
;//
;//     since the pins have three states d,s and n
;//     first determine if connected and apply a 'y' or 'n' prefix
;//     'n' prefix is one the states we're interstested in so we're done with that
;//     'y' prefix requires another test (PIN_CHANGING)
;//     after which the 'y' is replaced by 'd' or 's'
;//
;// immediately after a connected pin is tested for changing,
;// it's pointer is replaced by the data pointer
;//

;// here we go

;// start by examining the r trigger pin

    OSC_TO_PIN_INDEX esi, eax, 3    ;// reseed pin
    xor ebp, ebp
    mov ch, BYTE PTR [eax].dwUser   ;// load the last trigger
    OR_GET_PIN [eax].pPin, ebp      ;// get the pin
    jz r_not_connected

r_is_connected:

    ;// since r is connected, we have to determine the S state now

        OSC_TO_PIN_INDEX esi, eax, 2    ;// get the pin
        mov st_bSeed, 0                 ;// reset to default now
        mov eax, [eax].pPin             ;// get it's connection
        .IF eax                         ;// anything ?
            test [eax].dwStatus, PIN_CHANGING   ;// is it changing ?
            mov eax, [eax].pData                ;// load the source data pointer
            .IF !ZERO?                          ;// changing ?
                inc st_bSeed                    ;// tag bSeed as a pointer
            .ELSE
                mov eax, DWORD PTR [eax]        ;// load the value
            .ENDIF
        .ENDIF
        mov st_seed, eax                ;// store the value in st_Seed

    ;// then we continue on by parsing the n pin

        OSC_TO_PIN_INDEX esi, eax, 4    ;// next value pin
        xor ebx, ebx
        mov cl, BYTE PTR [eax].dwUser   ;// load the last trigger
        OR_GET_PIN [eax].pPin, ebx      ;// get the pin
        jz yr_nn


;// r and n are connected
;//
;//   /                          \      registers:
;//   | / dr rp \  / dn np ng \  |          edi = X out pin     esi = osc
;//   | | sr rn |  | sn nn nb |  |          ebx = n source pin  ecx = trig:trig
;//   | \    rb /  \    nb    /  |          ebp = r source pin  edx = dwUser
;//   \                          /
yr_yn:  test [ebx].dwStatus, PIN_CHANGING   ;// n source have changing data ?
        mov ebx, [ebx].pData                ;// load the data poiner
        jz yr_sn

    yr_dn:  test [ebp].dwStatus, PIN_CHANGING   ;// r source have changing data ?
            mov ebp, [ebp].pData                ;// load the data pointer
            jz sr_dn

        dr_dn:  bt edx, LOG2( RAND_NEXT_GATE )  ;// are we a gate ?
                jc  rand_DR_DN_NG               ;// jump if yes
                jmp rand_DR_DN_NE

        sr_dn:  call r_check_frame  ;// check for seed accross frame

                bt edx, LOG2( RAND_NEXT_GATE )  ;// are we a gate ?
                jc  rand_SR_DN_NG               ;// jump if yes
                jmp rand_SR_DN_NE

    yr_sn:  test [ebp].dwStatus, PIN_CHANGING   ;// n source have changing data ?
            mov ebp, [ebp].pData                ;// load the data pointer
            jz sr_sn

        dr_sn:  bt edx, LOG2(RAND_NEXT_GATE)    ;// are we a gate ?
                jc dr_sn_ng                     ;// jump if yes

            dr_sn_ne:

                call n_check_frame  ;// check for next accross frame
                jmp rand_DR_SN_NE

            dr_sn_ng:   ;// check if we can generate new values

                bt edx, LOG2(RAND_NEXT_NEG)     ;// check user flags
                mov cl, 0                       ;// reset cl for test
                jc dr_sn_ng_neg                 ;// jump if next on neg

                dr_sn_ng_pos:   ;// next value when pos

                    or cl, BYTE PTR [ebx+3]     ;// check the sign of first value
                    js rand_DR_SN_NE    ;bug ABox227 see sr_sn_ng_pos       ;// if not pos, we cannont gerenate new values
                    jmp rand_DR_SN_NG           ;// jump to full out routine

                dr_sn_ng_neg:   ;// next value when neg

                    or cl, BYTE PTR [ebx+3]     ;// check the sign of the first byte
                    js  rand_DR_SN_NG           ;// if neg, jmp to full out routine
                    jmp rand_DR_SN_NE           ;// if pos, we cannot generate new values


        sr_sn:  call r_check_frame

                bt edx, LOG2( RAND_NEXT_GATE )  ;// are we a gate ?
                jc sr_sn_ng                     ;// jump if yes

            sr_sn_ne:

                call n_check_frame
                jmp rand_SR_SN_NE

            sr_sn_ng:   ;// check if we can generate new values
                        ;// see dr_sn_ng: for notes

                bt edx, LOG2(RAND_NEXT_NEG)
                mov cl, 0
                jc sr_sn_ng_neg

                sr_sn_ng_pos:

                    or cl, BYTE PTR [ebx+3]
                    js rand_SR_SN_NE    ;// bug ABox227, was jns, this went undetected for 18 months !
                    jmp rand_SR_SN_NG

                sr_sn_ng_neg:

                    or cl, BYTE PTR [ebx+3]
                    js rand_SR_SN_NG
                    jmp rand_SR_SN_NE


;//   /                      \      registers:
;//   | / dr rp \  / np ng \  |         edi = X out pin     esi = osc
;//   | | sr rn |  | nn ne |  |         ebx = 0             ecx = trig:trig
;//   | \    rb /  \       /  |         ebp = r source pin  edx = dwUser
;//   \                      /
yr_nn:  test [ebp].dwStatus, PIN_CHANGING
        mov ebp, [ebp].pData     ;// load the data pointer
        jz sr_nn

    dr_nn:  bt edx, LOG2( RAND_NEXT_GATE )  ;// are we a gate ?
            jnc rand_DR_SN_NE               ;// jump if no

        dr_nn_ng:   ;// check if we can generate new values

            bt edx, LOG2( RAND_NEXT_POS )
            jc rand_DR_SN_NG        ;// yes we can (un connected n = 0)
            jmp rand_DR_SN_NE       ;// no we cant

    sr_nn:  call r_check_frame

            bt edx, LOG2(RAND_NEXT_GATE);// are we a gate ?
            jnc rand_SR_SN_NE           ;// jump if not

        sr_nn_ng:   ;// check if we can generate new values

            bt edx, LOG2( RAND_NEXT_POS )
            jc rand_SR_SN_NG        ;// yes we can (un connected n = 0)
            jmp rand_SR_SN_NE       ;// no we cant


;//   /          \  registers:
;//   | dn np ng |      edi = X out pin     esi = osc
;//   | sn nn nb |      ebx = n source pin  ecx = trig:trig
;//   |    nb    |      ebp =               edx = dwUser
;//   \          /
r_not_connected:

    OSC_TO_PIN_INDEX esi, eax, 4    ;// next value pin
    xor ebx, ebx
    mov cl, BYTE PTR [eax].dwUser   ;// load the last trigger
    OR_GET_PIN [eax].pPin, ebx      ;// get the pin
    jz nr_nn

nr_yn:  test [ebx].dwStatus, PIN_CHANGING
        mov ebx, [ebx].pData        ;// load the data pointer
        jz nr_sn

    nr_dn:  bt edx, LOG2( RAND_NEXT_GATE )  ;// are we a gate ?
            jc  rand_SR_DN_NG               ;// jump if yes
            jmp rand_SR_DN_NE

    nr_sn:  bt edx, LOG2(RAND_NEXT_GATE)    ;// are we a gate ?
            jc nr_sn_ng                     ;// jump if yes

        nr_sn_ne:

            call n_check_frame
            jmp rand_SR_SN_NE

        nr_sn_ng:   ;// check if we can generate new values
                    ;// see dr_sn_ng for notes

            bt edx, LOG2(RAND_NEXT_NEG)
            mov cl, 0
            jc nr_sn_ng_neg

            nr_sn_ng_pos:

                or cl, BYTE PTR [ebx+3]
                jns rand_SR_SN_NG
                jmp rand_SR_SN_NE

            nr_sn_ng_neg:

                or cl, BYTE PTR [ebx+3]
                js rand_SR_SN_NG
                jmp rand_SR_SN_NE


;//  / np ng \      registers:
;//  | nn ne |          edi = X out pin     esi = osc
;//  \      /           ebx = 0             ecx = trig:trig
;//                     ebp = 0             edx = dwUser

nr_nn:  bt edx, LOG2( RAND_NEXT_GATE )  ;// are we a gate ?
        jnc rand_SR_SN_NE               ;// jump if not

    nr_nn_ng:   ;// check if we can generate new values

        bt edx, LOG2( RAND_NEXT_POS )
        jc rand_SR_SN_NG        ;// yes we can (un connected n = 0)
        jmp rand_SR_SN_NE       ;// no we cant


;//
;//   SECTION 1     parse the object's state
;//                 end up at one of 8 locations in section 2
;//
;////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////////////
;//
;//   SECTION 2     there are 8 routines
;//
;//     rand_DR_DN_NE       rand_DR_DN_NG       for static sections
;//     rand_SR_DN_NE       rand_SR_DN_NG       assume that cross-frame triggering
;//     rand_DR_SN_NE       rand_DR_SN_NG       has already been acounted for
;//     rand_SR_SN_NE       rand_SR_SN_NG
;//
;// on entering any section, the following will be true
;//
;//     registers:                                          stack:
;//     -------------------------------------------         ----------------
;//     ecx = rTrig:nTrig       esi = osc                   st_last correct
;//     edx = dwUser            edi = X output pin          st_Seed correct
;//     ebx = n source data                                 st_bSeed correct
;//     ebp = r source data     FPU = empty
;//
;// A has not been fully parsed yet and will need to replace esi where required
;// A has already been checked for static zero, so we don't have to do that



;////////////////////////////////////////////////////////////////////
;//
;//     DR_DN_NE    states: dA  rp  np      27 states
;//                         sA  rn  nn      this is the most complicated
;//                         nA  rb  nb
;//
;//     NE loops use eax to iterate for nA and sA, and the FPU for dA
;//         nA  eax = st_last
;//         sA  eax = st_last*const gain (via fpu and st_temp)
;//         dA uses FPU and will load as required
;//
rand_DR_DN_NE:

    OSC_TO_PIN_INDEX esi, esi, 0;// get the A pin
    mov esi, [esi].pPin         ;// get it's connection
    or esi, esi                 ;// test for connected
    mov edi, [edi].pData    ;// get the data pointer
    jz DRDNNE_nA

DRDNNE_yA:

    test [esi].dwStatus, PIN_CHANGING   ;// see if it changing
    mov esi, [esi].pData                ;// load the data pointer
    jz DRDNNE_sA

DRDNNE_dA:

    fld random_scale

    test edx, RAND_SEED_TEST
    jz DRDNNE_dA_rb
    bt edx, LOG2(RAND_SEED_NEG)
    jc DRDNNE_dA_rn

    DRDNNE_dA_rp:

        test edx, RAND_NEXT_TEST
        jz DRDNNE_dA_rp_nb
        bt edx, LOG2(RAND_NEXT_NEG)
        jc DRDNNE_dA_rp_nn
        DRDNNE_dA_rp_np:    DR_DN_NE rp, np, dA, DRDNNE_dA_exit
        DRDNNE_dA_rp_nn:    DR_DN_NE rp, nn, dA, DRDNNE_dA_exit
        DRDNNE_dA_rp_nb:    DR_DN_NE rp, nb, dA, DRDNNE_dA_exit

    DRDNNE_dA_rn:

        test edx, RAND_NEXT_TEST
        jz DRDNNE_dA_rn_nb
        bt edx, LOG2(RAND_NEXT_NEG)
        jc DRDNNE_dA_rn_nn
        DRDNNE_dA_rn_np:    DR_DN_NE rn, np, dA, DRDNNE_dA_exit
        DRDNNE_dA_rn_nn:    DR_DN_NE rn, nn, dA, DRDNNE_dA_exit
        DRDNNE_dA_rn_nb:    DR_DN_NE rn, nb, dA, DRDNNE_dA_exit

    DRDNNE_dA_rb:

        test edx, RAND_NEXT_TEST
        jz DRDNNE_dA_rb_nb
        bt edx, LOG2(RAND_NEXT_NEG)
        jc DRDNNE_dA_rb_nn
        DRDNNE_dA_rb_np:    DR_DN_NE rb, np, dA, DRDNNE_dA_exit
        DRDNNE_dA_rb_nn:    DR_DN_NE rb, nn, dA, DRDNNE_dA_exit
        DRDNNE_dA_rb_nb:    DR_DN_NE rb, nb, dA, DRDNNE_dA_exit

    DRDNNE_dA_exit:

        fstp st

        jmp all_done


DRDNNE_sA:

    fld DWORD PTR [esi] ;// load the gain
    fld random_scale    ;// load the scale

    fld st_last         ;// load the random value
    fmul st, st(2)      ;// scale by gain
    fstp st_temp        ;// store in temp

    test edx, RAND_SEED_TEST
    mov eax, st_temp    ;// load the initial output value
    jz DRDNNE_sA_rb
    bt edx, LOG2(RAND_SEED_NEG)
    jc DRDNNE_sA_rn

    DRDNNE_sA_rp:

        test edx, RAND_NEXT_TEST
        jz DRDNNE_sA_rp_nb
        bt edx, LOG2(RAND_NEXT_NEG)
        jc DRDNNE_sA_rp_nn
        DRDNNE_sA_rp_np:    DR_DN_NE rp, np, sA, DRDNNE_sA_exit
        DRDNNE_sA_rp_nn:    DR_DN_NE rp, nn, sA, DRDNNE_sA_exit
        DRDNNE_sA_rp_nb:    DR_DN_NE rp, nb, sA, DRDNNE_sA_exit

    DRDNNE_sA_rn:

        test edx, RAND_NEXT_TEST
        jz DRDNNE_sA_rn_nb
        bt edx, LOG2(RAND_NEXT_NEG)
        jc DRDNNE_sA_rn_nn
        DRDNNE_sA_rn_np:    DR_DN_NE rn, np, sA, DRDNNE_sA_exit
        DRDNNE_sA_rn_nn:    DR_DN_NE rn, nn, sA, DRDNNE_sA_exit
        DRDNNE_sA_rn_nb:    DR_DN_NE rn, nb, sA, DRDNNE_sA_exit

    DRDNNE_sA_rb:

        test edx, RAND_NEXT_TEST
        jz DRDNNE_sA_rb_nb
        bt edx, LOG2(RAND_NEXT_NEG)
        jc DRDNNE_sA_rb_nn
        DRDNNE_sA_rb_np:    DR_DN_NE rb, np, sA, DRDNNE_sA_exit
        DRDNNE_sA_rb_nn:    DR_DN_NE rb, nn, sA, DRDNNE_sA_exit
        DRDNNE_sA_rb_nb:    DR_DN_NE rb, nb, sA, DRDNNE_sA_exit

    DRDNNE_sA_exit:

        fstp st
        fstp st

        jmp all_done

DRDNNE_nA:

    fld random_scale    ;// load the scale
    mov eax, st_last    ;// load the value to store

    test edx, RAND_SEED_TEST
    jz DRDNNE_nA_rb
    bt edx, LOG2(RAND_SEED_NEG)
    jc DRDNNE_nA_rn

    DRDNNE_nA_rp:

        test edx, RAND_NEXT_TEST
        jz DRDNNE_nA_rp_nb
        bt edx, LOG2(RAND_NEXT_NEG)
        jc DRDNNE_nA_rp_nn
        DRDNNE_nA_rp_np:    DR_DN_NE rp, np, nA, DRDNNE_nA_exit
        DRDNNE_nA_rp_nn:    DR_DN_NE rp, nn, nA, DRDNNE_nA_exit
        DRDNNE_nA_rp_nb:    DR_DN_NE rp, nb, nA, DRDNNE_nA_exit

    DRDNNE_nA_rn:

        test edx, RAND_NEXT_TEST
        jz DRDNNE_nA_rn_nb
        bt edx, LOG2(RAND_NEXT_NEG)
        jc DRDNNE_nA_rn_nn
        DRDNNE_nA_rn_np:    DR_DN_NE rn, np, nA, DRDNNE_nA_exit
        DRDNNE_nA_rn_nn:    DR_DN_NE rn, nn, nA, DRDNNE_nA_exit
        DRDNNE_nA_rn_nb:    DR_DN_NE rn, nb, nA, DRDNNE_nA_exit

    DRDNNE_nA_rb:

        test edx, RAND_NEXT_TEST
        jz DRDNNE_nA_rb_nb
        bt edx, LOG2(RAND_NEXT_NEG)
        jc DRDNNE_nA_rb_nn
        DRDNNE_nA_rb_np:    DR_DN_NE rb, np, nA, DRDNNE_nA_exit
        DRDNNE_nA_rb_nn:    DR_DN_NE rb, nn, nA, DRDNNE_nA_exit
        DRDNNE_nA_rb_nb:    DR_DN_NE rb, nb, nA, DRDNNE_nA_exit

    DRDNNE_nA_exit:

        fstp st

        jmp all_done


;//
;//     DR_DN_NE
;//
;//
;////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////
;//
;//     DR_DN_NG        states: dA  rp  np      18 states
;//                             sA  rn  nn
;//                             nA  rb
;//
;//     ng loops always use the FPU to store values
;//     so the first value needs preloaded
;//
rand_DR_DN_NG:

    OSC_TO_PIN_INDEX esi, esi, 0;// get the A pin
    mov esi, [esi].pPin         ;// get it's connection
    or esi, esi                 ;// test for connected
    mov edi, [edi].pData    ;// get the data pointer
    jz DRDNNG_nA

DRDNNG_yA:

    test [esi].dwStatus, PIN_CHANGING   ;// see if it changing
    mov esi, [esi].pData                ;// load the data pointer
    jz DRDNNG_sA

DRDNNG_dA:

    fld random_scale
    fild st_last            ;// load the initial output (bug ABox227, should load as int)
    fmul st, st(1)          ;// scale to normal range   (bug ABox227)
    fmul DWORD PTR [esi]    ;// scale by initial gain

    test edx, RAND_SEED_TEST
    jz DRDNNG_dA_rb
    bt edx, LOG2(RAND_SEED_NEG)
    jc DRDNNG_dA_rn

    DRDNNG_dA_rp:

        bt edx, LOG2(RAND_NEXT_NEG)
        jc DRDNNG_dA_rp_nn
        DRDNNG_dA_rp_np:    DR_DN_NG rp, np, dA, DRDNNG_dA_exit
        DRDNNG_dA_rp_nn:    DR_DN_NG rp, nn, dA, DRDNNG_dA_exit

    DRDNNG_dA_rn:

        bt edx, LOG2(RAND_NEXT_NEG)
        jc DRDNNG_dA_rn_nn
        DRDNNG_dA_rn_np:    DR_DN_NG rn, np, dA, DRDNNG_dA_exit
        DRDNNG_dA_rn_nn:    DR_DN_NG rn, nn, dA, DRDNNG_dA_exit

    DRDNNG_dA_rb:

        bt edx, LOG2(RAND_NEXT_NEG)
        jc DRDNNG_dA_rb_nn
        DRDNNG_dA_rb_np:    DR_DN_NG rb, np, dA, DRDNNG_dA_exit
        DRDNNG_dA_rb_nn:    DR_DN_NG rb, nn, dA, DRDNNG_dA_exit

    DRDNNG_dA_exit:

        fstp st
        fstp st

        jmp all_done


DRDNNG_sA:

    fld DWORD PTR [esi] ;// load the gain
    fld random_scale    ;// load the scale
    fild st_last            ;// load the initial output (bug ABox227, should load as int)
    fmul st, st(1)          ;// scale to normal range   (bug ABox227)
    fmul st, st(2)      ;// scale by constant gain

    test edx, RAND_SEED_TEST
    jz DRDNNG_sA_rb
    bt edx, LOG2(RAND_SEED_NEG)
    jc DRDNNG_sA_rn

    DRDNNG_sA_rp:

        bt edx, LOG2(RAND_NEXT_NEG)
        jc DRDNNG_sA_rp_nn
        DRDNNG_sA_rp_np:    DR_DN_NG rp, np, sA, DRDNNG_sA_exit
        DRDNNG_sA_rp_nn:    DR_DN_NG rp, nn, sA, DRDNNG_sA_exit

    DRDNNG_sA_rn:

        bt edx, LOG2(RAND_NEXT_NEG)
        jc DRDNNG_sA_rn_nn
        DRDNNG_sA_rn_np:    DR_DN_NG rn, np, sA, DRDNNG_sA_exit
        DRDNNG_sA_rn_nn:    DR_DN_NG rn, nn, sA, DRDNNG_sA_exit

    DRDNNG_sA_rb:

        bt edx, LOG2(RAND_NEXT_NEG)
        jc DRDNNG_sA_rb_nn
        DRDNNG_sA_rb_np:    DR_DN_NG rb, np, sA, DRDNNG_sA_exit
        DRDNNG_sA_rb_nn:    DR_DN_NG rb, nn, sA, DRDNNG_sA_exit

    DRDNNG_sA_exit:

        fstp st
        fstp st
        fstp st

        jmp all_done

DRDNNG_nA:

    fld random_scale    ;// load the scale
    fild st_last            ;// load the initial output (bug ABox227, should load as int)
    fmul st, st(1)          ;// scale to normal range   (bug ABox227)

    test edx, RAND_SEED_TEST
    jz DRDNNG_nA_rb
    bt edx, LOG2(RAND_SEED_NEG)
    jc DRDNNG_nA_rn

    DRDNNG_nA_rp:

        bt edx, LOG2(RAND_NEXT_NEG)
        jc DRDNNG_nA_rp_nn
        DRDNNG_nA_rp_np:    DR_DN_NG rp, np, nA, DRDNNG_nA_exit
        DRDNNG_nA_rp_nn:    DR_DN_NG rp, nn, nA, DRDNNG_nA_exit

    DRDNNG_nA_rn:

        bt edx, LOG2(RAND_NEXT_NEG)
        jc DRDNNG_nA_rn_nn
        DRDNNG_nA_rn_np:    DR_DN_NG rn, np, nA, DRDNNG_nA_exit
        DRDNNG_nA_rn_nn:    DR_DN_NG rn, nn, nA, DRDNNG_nA_exit

    DRDNNG_nA_rb:

        bt edx, LOG2(RAND_NEXT_NEG)
        jc DRDNNG_nA_rb_nn
        DRDNNG_nA_rb_np:    DR_DN_NG rb, np, nA, DRDNNG_nA_exit
        DRDNNG_nA_rb_nn:    DR_DN_NG rb, nn, nA, DRDNNG_nA_exit

    DRDNNG_nA_exit:

        fstp st
        fstp st

        jmp all_done


;//
;//     DR_DN_NG
;//
;//
;////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////
;//
;//     SR_DN_NE    states: dA  np      9 states
;//                         sA  nn
;//                         nA  nb
;//
;//     NE loops use eax to iterate for nA and sA, and the FPU for dA
;//         nA  eax = st_last
;//         sA  eax = st_last*const gain (via fpu and st_temp)
;//         dA uses FPU and will load as required
;//
rand_SR_DN_NE:

    OSC_TO_PIN_INDEX esi, esi, 0;// get the A pin
    mov esi, [esi].pPin         ;// get it's connection
    or esi, esi                 ;// test for connected
    mov edi, [edi].pData    ;// get the data pointer
    jz SRDNNE_nA

SRDNNE_yA:

    test [esi].dwStatus, PIN_CHANGING   ;// see if it changing
    mov esi, [esi].pData                ;// load the data pointer
    jz SRDNNE_sA

SRDNNE_dA:

    fld random_scale

    test edx, RAND_NEXT_TEST
    jz SRDNNE_dA_nb
    bt edx, LOG2(RAND_NEXT_NEG)
    jc SRDNNE_dA_nn
    SRDNNE_dA_np:   SR_DN_NE np, dA, SRDNNE_dA_exit
    SRDNNE_dA_nn:   SR_DN_NE nn, dA, SRDNNE_dA_exit
    SRDNNE_dA_nb:   SR_DN_NE nb, dA, SRDNNE_dA_exit

    SRDNNE_dA_exit:

        fstp st

        jmp all_done


SRDNNE_sA:

    fld DWORD PTR [esi] ;// load the gain
    fld random_scale    ;// load the scale

    fld st_last         ;// load the random value
    fmul st, st(2)      ;// scale by gain
    fstp st_temp        ;// store in temp
    mov eax, st_temp    ;// load the initial output value

    test edx, RAND_NEXT_TEST
    jz SRDNNE_sA_nb
    bt edx, LOG2(RAND_NEXT_NEG)
    jc SRDNNE_sA_nn
    SRDNNE_sA_np:   SR_DN_NE np, sA, SRDNNE_sA_exit
    SRDNNE_sA_nn:   SR_DN_NE nn, sA, SRDNNE_sA_exit
    SRDNNE_sA_nb:   SR_DN_NE nb, sA, SRDNNE_sA_exit

    SRDNNE_sA_exit:

        fstp st
        fstp st

        jmp all_done

SRDNNE_nA:

    fld random_scale    ;// load the scale
    mov eax, st_last    ;// load the value to store

    test edx, RAND_NEXT_TEST
    jz SRDNNE_nA_nb
    bt edx, LOG2(RAND_NEXT_NEG)
    jc SRDNNE_nA_nn
    SRDNNE_nA_np:   SR_DN_NE np, nA, SRDNNE_nA_exit
    SRDNNE_nA_nn:   SR_DN_NE nn, nA, SRDNNE_nA_exit
    SRDNNE_nA_nb:   SR_DN_NE nb, nA, SRDNNE_nA_exit

    SRDNNE_nA_exit:

        fstp st

        jmp all_done

;//
;//     SR_DN_NE
;//
;//
;////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////
;//
;//     SR_DN_NG    states: dA  np      6 states
;//                         sA  nn
;//                         nA
;//
;// ng loops always use the FPU to store values
;// so the first value needs preloaded
;//
rand_SR_DN_NG:

    OSC_TO_PIN_INDEX esi, esi, 0;// get the A pin
    mov esi, [esi].pPin         ;// get it's connection
    or esi, esi                 ;// test for connected
    mov edi, [edi].pData    ;// get the data pointer
    jz SRDNNG_nA

SRDNNG_yA:

    test [esi].dwStatus, PIN_CHANGING   ;// see if it changing
    mov esi, [esi].pData                ;// load the data pointer
    jz SRDNNG_sA

SRDNNG_dA:

    fld random_scale
    fild st_last            ;// load the initial output (bug ABox227, should load as int)
    fmul st, st(1)          ;// scale to normal range   (bug ABox227)
    fmul DWORD PTR [esi]    ;// scale by initial gain

    bt edx, LOG2(RAND_NEXT_NEG)
    jc SRDNNG_dA_nn
    SRDNNG_dA_np:   SR_DN_NG np, dA, SRDNNG_dA_exit
    SRDNNG_dA_nn:   SR_DN_NG nn, dA, SRDNNG_dA_exit

    SRDNNG_dA_exit:

        fstp st
        fstp st

        jmp all_done


SRDNNG_sA:

    fld DWORD PTR [esi] ;// load the gain
    fld random_scale    ;// load the scale
    fild st_last        ;// load the initial output (bug ABox227, should load as int)
    fmul st, st(1)      ;// scale to normal range   (bug ABox227)
    fmul st, st(2)      ;// scale by constant gain

    bt edx, LOG2(RAND_NEXT_NEG)
    jc SRDNNG_sA_nn
    SRDNNG_sA_np:   SR_DN_NG np, sA, SRDNNG_sA_exit
    SRDNNG_sA_nn:   SR_DN_NG nn, sA, SRDNNG_sA_exit

    SRDNNG_sA_exit:

        fstp st
        fstp st
        fstp st

        jmp all_done

SRDNNG_nA:

    fld random_scale    ;// load the scale
    fild st_last        ;// load the initial output (bug ABox227, should load as int)
    fmul st, st(1)      ;// scale to normal range   (bug ABox227)

    bt edx, LOG2(RAND_NEXT_NEG)
    jc SRDNNG_nA_nn
    SRDNNG_nA_np:   SR_DN_NG np, nA, SRDNNG_nA_exit
    SRDNNG_nA_nn:   SR_DN_NG nn, nA, SRDNNG_nA_exit

    SRDNNG_nA_exit:

        fstp st
        fstp st

        jmp all_done

;//
;//     SR_DN_NG
;//
;//
;////////////////////////////////////////////////////////////////////




;////////////////////////////////////////////////////////////////////
;//
;//     DR_SN_NE    states: dA  rp      9 states
;//                         sA  rn      this is also hit when sn ng cannot produce new values
;//                         nA  rb      AA nope, (ABox227)there is NO savings and the routines are not compatible
;//
;//     NE loops use eax to iterate for nA and sA, and the FPU for dA
;//     they do not produce new
;//         nA  eax = st_last
;//         sA  eax = st_last*const gain (via fpu and st_temp)
;//         dA uses FPU and will load as required
;//
rand_DR_SN_NE:

    OSC_TO_PIN_INDEX esi, esi, 0;// get the A pin
    mov esi, [esi].pPin         ;// get it's connection
    or esi, esi                 ;// test for connected
    mov edi, [edi].pData    ;// get the data pointer
    jz DRSNNE_nA

DRSNNE_yA:

    test [esi].dwStatus, PIN_CHANGING   ;// see if it changing
    mov esi, [esi].pData                ;// load the data pointer
    jz DRSNNE_sA

DRSNNE_dA:

    fld random_scale

    BITT edx, RAND_NEXT_GATE    ;// added ABox227: NE and NG modes not compatible
    jc DRSNNE_dA_gate

    test edx, RAND_SEED_TEST
    jz DRSNNE_dA_rb
    bt edx, LOG2(RAND_SEED_NEG)
    jc DRSNNE_dA_rn

    DRSNNE_dA_rp:   DR_SN_NE rp, dA, DRSNNE_dA_exit
    DRSNNE_dA_rn:   DR_SN_NE rn, dA, DRSNNE_dA_exit
    DRSNNE_dA_rb:   DR_SN_NE rb, dA, DRSNNE_dA_exit

DRSNNE_dA_gate: ;// added ABox227: NE and NG modes not compatible

    bt edx, LOG2(RAND_SEED_NEG)
    jc DRSNNE_dA_rn_gate
    DRSNNE_dA_rp_gate:  DR_SN_NE rp, dA_gate, DRSNNE_dA_exit
    DRSNNE_dA_rn_gate:  DR_SN_NE rn, dA_gate, DRSNNE_dA_exit

    DRSNNE_dA_exit:

        fstp st

        jmp all_done


DRSNNE_sA:

    fld DWORD PTR [esi] ;// load the gain
    fld random_scale    ;// load the scale

    .IF !(edx & RAND_NEXT_GATE) ;// added ABox227: NE and NG modes not compatible
        fld st_last         ;// load the random value
    .ELSE
        fild st_last            ;// load the random value
        fmul st, st(1)
    .ENDIF

    fmul st, st(2)      ;// scale by gain
    fstp st_temp        ;// store in temp

    test edx, RAND_SEED_TEST
    mov eax, st_temp    ;// load the initial output value
    jz DRSNNE_sA_rb
    bt edx, LOG2(RAND_SEED_NEG)
    jc DRSNNE_sA_rn

    DRSNNE_sA_rp:   DR_SN_NE rp, sA, DRSNNE_sA_exit
    DRSNNE_sA_rn:   DR_SN_NE rn, sA, DRSNNE_sA_exit
    DRSNNE_sA_rb:   DR_SN_NE rb, sA, DRSNNE_sA_exit

    DRSNNE_sA_exit:

        fstp st
        fstp st

        jmp all_done

DRSNNE_nA:

    fld random_scale    ;// load the scale
    .IF !(edx & RAND_NEXT_GATE) ;// added ABox227: NE and NG modes not compatible
        mov eax, st_last    ;// load the value to store
    .ELSE
        fild st_last
        fmul st, st(1)
        fstp st_temp
        mov eax, st_temp
    .ENDIF

    test edx, RAND_SEED_TEST
    jz DRSNNE_nA_rb
    bt edx, LOG2(RAND_SEED_NEG)
    jc DRSNNE_nA_rn

    DRSNNE_nA_rp:   DR_SN_NE rp, nA, DRSNNE_nA_exit
    DRSNNE_nA_rn:   DR_SN_NE rn, nA, DRSNNE_nA_exit
    DRSNNE_nA_rb:   DR_SN_NE rb, nA, DRSNNE_nA_exit

    DRSNNE_nA_exit:

        fstp st

        jmp all_done


;//
;//     DR_SN_NE
;//
;//
;////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////
;//
;//     DR_SN_NG        states: dA  rp  9 states
;//                             sA  rn
;//                             nA  rb  pre-parsing has determined that
;//                                     we can indeed propduce new values
;//
;//     ng loops always use the FPU to store values
;//     so the first value needs preloaded
;//
rand_DR_SN_NG:

    OSC_TO_PIN_INDEX esi, esi, 0    ;// get the A pin
    mov esi, [esi].pPin             ;// get it's connection
    or esi, esi                     ;// test for connected
    mov edi, [edi].pData    ;// get the data pointer
    jz DRSNNG_nA

DRSNNG_yA:

    test [esi].dwStatus, PIN_CHANGING   ;// see if it changing
    mov esi, [esi].pData                ;// load the data pointer
    jz DRSNNG_sA

DRSNNG_dA:

    fld random_scale
    fild st_last        ;// load the initial output (bug ABox227, should load as int)
    fmul st, st(1)      ;// scale to normal range   (bug ABox227)
    fmul DWORD PTR [esi]    ;// scale by initial gain

    test edx, RAND_SEED_TEST
    jz DRSNNG_dA_rb
    bt edx, LOG2(RAND_SEED_NEG)
    jc DRSNNG_dA_rn

    DRSNNG_dA_rp:   DR_SN_NG rp, dA, DRSNNG_dA_exit
    DRSNNG_dA_rn:   DR_SN_NG rn, dA, DRSNNG_dA_exit
    DRSNNG_dA_rb:   DR_SN_NG rb, dA, DRSNNG_dA_exit

    DRSNNG_dA_exit:

        fstp st
        fstp st

        jmp all_done


DRSNNG_sA:

    fld DWORD PTR [esi] ;// load the gain
    fld random_scale    ;// load the scale
    fild st_last        ;// load the initial output (bug ABox227, should load as int)
    fmul st, st(1)      ;// scale to normal range   (bug ABox227)
    fmul st, st(2)      ;// scale by constant gain

    test edx, RAND_SEED_TEST
    jz DRSNNG_sA_rb
    bt edx, LOG2(RAND_SEED_NEG)
    jc DRSNNG_sA_rn

    DRSNNG_sA_rp:   DR_SN_NG rp, sA, DRSNNG_sA_exit
    DRSNNG_sA_rn:   DR_SN_NG rn, sA, DRSNNG_sA_exit
    DRSNNG_sA_rb:   DR_SN_NG rb, sA, DRSNNG_sA_exit

    DRSNNG_sA_exit:

        fstp st
        fstp st
        fstp st

        jmp all_done

DRSNNG_nA:

    fld random_scale    ;// load the scale
    fild st_last        ;// load the initial output (bug ABox227, should load as int)
    fmul st, st(1)      ;// scale to normal range   (bug ABox227)

    test edx, RAND_SEED_TEST
    jz DRSNNG_nA_rb
    bt edx, LOG2(RAND_SEED_NEG)
    jc DRSNNG_nA_rn

    DRSNNG_nA_rp:   DR_SN_NG rp, nA, DRSNNG_nA_exit
    DRSNNG_nA_rn:   DR_SN_NG rn, nA, DRSNNG_nA_exit
    DRSNNG_nA_rb:   DR_SN_NG rb, nA, DRSNNG_nA_exit

    DRSNNG_nA_exit:

        fstp st
        fstp st

        jmp all_done


;//
;//     DR_SN_NG
;//
;//
;////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////
;//
;//     SR_SN_NE
;//
;//
rand_SR_SN_NE:

    IFDEF DEBUGBUILD
        cmp edx, (OSC_OBJECT PTR [esi]).dwUser
        je @F
            int 3
        @@:
    ENDIF

    OSC_TO_PIN_INDEX esi, esi, 0;// get the A pin
    mov esi, [esi].pPin         ;// get it's connection
    or esi, esi                 ;// test for connected
    jz SRSNNE_nA

    test [esi].dwStatus, PIN_CHANGING   ;// see if it changing
    mov esi, [esi].pData                ;// load the data pointer
    jz SRSNNE_sA

    SRSNNE_dA:

        ;// A input is changing
        ;// st_last will not

        mov edi, [edi].pData    ;// get the data pointer

        .IF !(edx & RAND_NEXT_GATE)
            fld st_last
        .ELSE
            fild st_last
            fmul random_scale
        .ENDIF

        inc st_change

        mov edx, SAMARY_LENGTH

        .REPEAT

            fld DWORD PTR [esi]     ;// x0  V
            fmul st, st(1)          ;// y0  V
            fld DWORD PTR [esi+4]   ;// x1  y0  V
            fmul st, st(2)          ;// y1  y0  V
            fld DWORD PTR [esi+8]   ;// x2  y1  y2  V
            fmul st, st(3)          ;// y2  y1  y0  V
            fld DWORD PTR [esi+0Ch] ;// x3  y2  y1  y0  V
            fmul st, st(4)          ;// y3  y2  y1  y0  V

            fxch st(3)              ;// y0  y2  y1  y3  V
            fstp DWORD PTR [edi]    ;// y2  y1  y3  V
            fxch                    ;// y1  y2  y3  V
            fstp DWORD PTR [edi+4]  ;// y2  y3  V
            add esi, 10h
            fstp DWORD PTR [edi+8]  ;// y3  V
            fstp DWORD PTR [edi+0Ch];// V
            add edi, 10h

            sub edx, 4

        .UNTIL ZERO?

        fstp st
        jmp all_done


    SRSNNE_sA:      ;// A is not changing, but needs applied

        .IF !(edx & RAND_NEXT_GATE)
            fld st_last
        .ELSE
            fild st_last
            fmul random_scale
        .ENDIF

        fld DWORD PTR [esi]
        fmul
        fstp st_temp
        mov eax, st_temp
        jmp check_static_output

    SRSNNE_nA:      ;// static ouput plain and simple

        .IF !(edx & RAND_NEXT_GATE)
            mov eax, st_last
        .ELSE
            fild st_last
            fmul random_scale
            fstp st_temp
            mov eax, st_temp
        .ENDIF

    check_static_output:

        test [edi].dwStatus, PIN_CHANGING
        mov edx, SAMARY_LENGTH
        mov edi, [edi].pData
        .IF !ZERO? || eax != DWORD PTR [edi]
            xchg ecx, edx
            rep stosd
            xchg ecx, edx
        .ENDIF

        jmp all_done

;//
;//
;//
;//
;////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////
;//
;//                     preparseing has determined that we are producing output
;//     SR_SN_NG
;//
;// these routines do not seam to produce repeating numbers !
rand_SR_SN_NG:

    OSC_TO_PIN_INDEX esi, esi, 0;// get the A pin
    mov st_temp, ecx        ;// store ecx
    mov esi, [esi].pPin     ;// get it's connection
    inc st_change           ;// set pin changing
    xor ecx, ecx        ;// ecx will be the counter
    test esi, esi           ;// test for connected
    mov edi, [edi].pData    ;// load the data pointer
    jz SRSNNG_nA

    test [esi].dwStatus, PIN_CHANGING   ;// see if it changing
    mov esi, [esi].pData                ;// load the data pointer
    jz SRSNNG_sA

    SRSNNG_dA:

        mov eax, st_last
        fld random_scale

        .REPEAT

            mul random_multRand ;// with out undo hassle
            inc eax
            mov st_last, eax    ;// store in last

            fild st_last            ;// load as an integer
            fmul st, st(1)          ;// multiply by random scale
            fmul DWORD PTR [esi+ecx*4]  ;// apply the gain
            fstp DWORD PTR [edi+ecx*4]  ;// store output value

            inc ecx

        .UNTIL ecx >= SAMARY_LENGTH

        mov ecx, st_temp    ;// reload the bit flags, they havent changed
        fstp st
        jmp all_done

    SRSNNG_sA:

        fld DWORD PTR [esi]     ;// load the gain
        mov eax, st_last        ;// start the last value
        fmul random_scale       ;// premultiply by random scale

        .REPEAT

            mul random_multRand     ;// with out undo hassle
            inc eax
            mov st_last, eax        ;// store in last as integer

            fild st_last            ;// load as an integer
            fmul st, st(1)          ;// multiply by random scale and gain
            fstp DWORD PTR [edi+ecx*4]  ;// store output value

            inc ecx

        .UNTIL ecx >= SAMARY_LENGTH

        fstp st
        mov ecx, st_temp

        jmp all_done

    SRSNNG_nA:

        mov eax, st_last
        fld random_scale

        .REPEAT

            mul random_multRand ;// with out undo hassle
            inc eax
            mov st_last, eax    ;// store in last

            fild st_last            ;// load as an integer
            fmul st, st(1)          ;// multiply by random scale
            fstp DWORD PTR [edi+ecx*4]  ;// store output value

            inc ecx

        .UNTIL ecx >= SAMARY_LENGTH

        fstp st
        mov ecx, st_temp
        jmp all_done

;//
;//     SR_SN_NG
;//
;//
;////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////
;//
;//     exit point      state   all registers are in unknown state
;//                             ecx has the last trigger values for r:n
;//                             st_last needs to be stored
;//                             st_changing is correct
all_done:

    mov esi, st_esi     ;// get the osc
    ASSUME esi:PTR OSC_OBJECT

    mov eax, st_last
    mov edx, st_change
    OSC_TO_PIN_INDEX esi, ebx, 1    ;// output pin
    mov edi, [ebx].dwStatus         ;// get the status
    mov [ebx].dwUser, eax           ;// store st_last

    ;// this w here we want to check if got a trigger
    ;// and set the graphic correctly
    or edx, edx                     ;// see if we were changing or need a new graphic
    jz not_changing
    jns no_graphic_change

        ;// do new graphic
        mov eax, [ebx].pData
        mov eax, DWORD PTR [eax]
        and eax, 31
        .IF eax > 23
            sub eax, 24
        .ENDIF
        xor edx, edx
        mov eax, rand_pSource[eax*4]
        or edx, [esi].dwHintOsc
        mov [esi].pSource, eax
        .IF SIGN?
        invoke play_Invalidate_osc
        .ENDIF

        ;// check if the signal is changing
        mov edx, st_change
        and edx, 7FFFFFFFh
        jz not_changing

    no_graphic_change:

        bts edi, LOG2(PIN_CHANGING) ;// yep, set changing
        jmp set_dwUser

    not_changing:

        btr edi, LOG2(PIN_CHANGING) ;// nope reset changing

set_dwUser:

    mov [ebx].dwStatus, edi         ;// store the flags back in the pin

    OSC_TO_PIN_INDEX esi, ebx, 3    ;// r pin
    mov BYTE PTR [ebx].dwUser, ch   ;// store last trigger
    OSC_TO_PIN_INDEX esi, ebx, 4    ;// n pin
    mov BYTE PTR [ebx].dwUser, cl   ;// store last trigger

    ;// clean up and go

    add esp, stack_size
    pop esi
    pop ebp
    ret


;////////////////////////////////////////////////////////////////////
;//
;//                     reseed()
;// local functions     s_check_frame()
;//                     n_check_frame()

ALIGN 16
reseed:

;// purpose:    get the seed value from wherever it comes from

;// operation:  S[] -> st_last

call_depth = 1

    cmp st_bSeed, 0
    mov eax, st_seed
    jz store_seed
    mov eax, DWORD PTR [eax+edx*4]
store_seed:
    mov st_last, eax
    or st_change, 80000001h ;// set changing and set that we have a new random value
    retn


ALIGN 16
r_check_frame:

;// purpose: checks for reseed trigger across sample frame
;// use only for sr

;// operation:  if(trigger) st_last = new_value ;
;//             sets new ch

;// registers:  ebp = r source data
;//             ch    previous trigger
;//             edx = osc.dwUser

;// conditions: st_seed and st_bSeed must be set up

call_depth = 1

    ;// determine the edge

    bt edx, LOG2( RAND_SEED_POS )
    jnc not_pos_reseed

    ;// reseed on pos edge
        or ch, ch   ;// neg then ?
        js neg_01   ;// jmp if yes
        mov ch, BYTE PTR [ebp+3] ;// load the new edge !!
        retn        ;// can;t get a pos edge

not_pos_reseed:

    bt edx, LOG2( RAND_SEED_NEG )
    jnc not_pos_or_neg_reseed

    ;// reseed on neg edge
        or ch, ch   ;// pos then ?
        jns pos_01  ;// jmp if yes
        mov ch, BYTE PTR [ebp+3] ;// load the new edge !!
        retn        ;// can;t get a neg edge

not_pos_or_neg_reseed:

    ;// reseed on either edge
        or ch, ch   ;// get the sign
        jns pos_01  ;// if pos, jump

    ;// ch is negative
    neg_01: and ch, BYTE PTR [ebp+3]
            jns reseed  ;// jump if pos edge
            retn        ;// no trigger

    ;// ch is positive
    pos_01: or ch, BYTE PTR [ebp+3]
            js reseed   ;// jmp if neg edge
            retn        ;// no retrigger















ALIGN 16
n_check_frame:

    call_depth = 1

;// purpose:    check for next_value accross frame
;//             use for NE with sN
;//
;// operation:  if(trigger) st_last = rand()
;//             always load current value for cl
;//
;// conditions: st_last must be valid

;// registers:
;//
;//     ebx = n pin's data
;//     ecx = rTrig:nTrig
;//     st_last is correct

    test edx, RAND_NEXT_TEST
    jz check_frame_b
    bt ecx, LOG2( RAND_NEXT_NEG )
    jc check_frame_n

    check_frame_p:  ;// next value on pos edge

        or cl, cl       ;// get the last sign
        jns no_new_value_load
        and cl, BYTE PTR [ebx+3]
        js no_new_value
        jmp check_frame_next

    check_frame_n:  ;// next value on neg edge

        or cl, cl
        js no_new_value_load
        or cl, BYTE PTR [ebx+3]
        jns no_new_value
        jmp check_frame_next

    check_frame_b:  ;// next value on both edges

        or cl, cl
        jns @F
            ;// last value was negative
            and cl, BYTE PTR [ebx+3]
            js no_new_value
            jmp check_frame_next
        @@:
            ;// last value was positive
            or cl, BYTE PTR [ebx+3]
            jns no_new_value

    check_frame_next:

        mov st_temp, edx    ;// store edx

        mov eax, st_last
        fld random_scale

        mul random_multRand ;// with out undo hassle
        inc eax
        mov st_last, eax    ;// store in last

        fild st_last        ;// load as an integer
        mov edx, st_temp    ;// retrieve edx
        fmul                ;// multiply by random scale
        or st_change, 80000000h
        fstp st_last        ;// store as a float

        retn

    no_new_value_load:

        mov cl, BYTE PTR [ebx+3]

    no_new_value:

        retn



rand_Calc ENDP

ASSUME_AND_ALIGN
ENDIF   ;// USE_THIS_FILE
END










