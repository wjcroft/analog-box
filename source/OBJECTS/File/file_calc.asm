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
;//                         the new file object
;// file_calc.asm
;//
;//
;// TOC
;//
;// file_Calc
;// file_PrePlay

OPTION CASEMAP:NONE

.586
.MODEL FLAT

USE_THIS_FILE equ 1

IFDEF USE_THIS_FILE

    .NOLIST
    INCLUDE <Abox.inc>
    INCLUDE <ABox_OscFile.inc>
    .LIST
    ;//.LISTALL




;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//
;//
;//     file_Calc
.DATA

        file_calc_table LABEL DWORD
        dd  bad_Calc
        dd  data_Calc
        dd  gmap_Calc
        dd  reader_Calc
        dd  writer_Calc
        dd  csvreader_Calc
        dd  csvwriter_Calc

.CODE

ASSUME_AND_ALIGN
file_Calc PROC STDCALL

        ASSUME esi:PTR OSC_FILE_MAP

        mov eax, [esi].dwUser
        and [esi].dwUser, NOT FILE_MODE_IS_CLIPPING ;// turn the flag off
        TESTJMP eax, FILE_MODE_IS_CALCABLE, jz all_done

        ANDJMP eax, FILE_MODE_TEST, jz bad_Calc
        CMPJMP eax, FILE_MODE_MAX, ja bad_Calc

        call file_calc_table[eax*4]

        ;// check dwUser for update and clipping
        ;// invalidate is we're on the screen

        xor ebx, ebx    ;// use for flag

        dec [esi].file.play_update_count
        .IF SIGN?
            inc ebx
            mov [esi].file.play_update_count, FILE_PLAY_UPDATE_COUNT
        .ENDIF

        mov eax, [esi].dwUser
        BITT eax, FILE_MODE_IS_CLIPPING         ;// test the new value
        .IF CARRY?                              ;// are clipping now
            BITS eax, FILE_MODE_WAS_CLIPPING    ;// check if were clipping
            cmc                                 ;// flip carry so we update ebx correctly
        .ELSE                                   ;// not clipping now
            BITR eax, FILE_MODE_WAS_CLIPPING    ;// test and reset if were clipping
        .ENDIF
        adc ebx, ebx            ;// add the carry to ebx
        mov [esi].dwUser, eax   ;// put the now conditioned eax back in dwUser

        .IF ebx && ([esi].dwHintOsc & HINTOSC_STATE_ONSCREEN)
            invoke play_Invalidate_osc
        .ENDIF

    bad_Calc::
    all_done:

        ret

file_Calc ENDP






















comment ~ /*

strategy:

    this algorithm is complicated
    to get it working, write the simplest version

calc has a huge front end

        seb         meb         web
    ds  sep dP  dm  mep dF  dw  wep dLiRi
    ss  sen sP  sm  men sF  sw  wen sLiRi
    zs  sgp zP  zm  mgp     nw  wgp
        sgn         mgn         wgn
    --  --- --  --  --- --  --  --- -----
    3   5   3   2   5   2   3   5   2       = 27000

    there is no simple way to optomize this like the rest of the objects
    instead, we we'll try to account for the no brainers



ALL_MODES

    NO  LiRi NO  LoRo   no calc
    NO  LiRi YES LoRo   no write    DO_WRITE
    YES LiRi NO  LoRo   no read     DO_READ

    if !DO_WRITE && !DO_READ then NO_CALC

DO_WRITE

    /     web \
    | dw  wep |     10 states
    | sw  wem |     determine which states tell us that we do not have to write
    |     wgp |     determine which states tell us that we only check once
    \     wgm /

    YES_WRITE   ds
    ONE_WRITE   sw && (web,wep,wem)
    ALL_WRITE   sw && ( (w<0 && wgm) || (w>=0 && wgp) )


DO_READ

    /    seb    meb dF \    400 states
    | ds sep dm mep sF |
    | ss sem sm mem nF |
    |    sgp    mgp zF |
    \    sgm    mgm    /

    transform into

        YES_SEEK, ONE_SEEK, ALL_SEEK, YES_MOVE, ONE_MOVE, ALL_MOVE

        ONE_SEEK shuts off YES_SEEK

        ALL_MOVE can skip the trigger test
        YES_MOVE means do the trigger test
        ONE_MOVE shuts off YES_MOVE, checked by BTR

    YES_SEEK    ds
    ONE_SEEK    ss && seb,sep,sem
    ALL_SEEK    ss && ( ( sgp && s>=0 ) || ( sgp && s<0 ) )     <-- NO_MOVE

    YES_MOVE    ds
    ONE_MOVE    sm && meb,mep,mem
    ALL_MOVE    sm && ( ( mgp && m>=0 ) || ( mgp && m<0 ) )

    / YES_SEEK YES_MOVE \   9 states
    | ONE_SEEK ONE_MOVE |   ALL_SEEK disables xxx_MOVE
    \ ALL_SEEK ALL_MOVE /

    if ALL_MOVE && zF       --> store static
    if sF, cache the fraction
    if ONE_SEEK && ONE_MOVE --> store static

;///////////////////////////////////////////////////////////////////////////

    so: we need a bit carrier register
        ebp is the logical choice
        this means we need to move the local values to another location

        1) put in object
            thread safe
            takes up more memory
            acces is via [esi+]
        2) put in data seg
            precludes multi threading
            less memory
            acces via absolute address

    we are already using ebx as a flag holder for dwUser
        it does not have enough extra bits for our needs
    if we strip out uneeded bits, we may have enough

bits we need

    abort_calc      DO_WRITE    YES_SEEK    YES_WRITE   YES_MOVE
    have_seeked     DO_READ     ONE_SEEK    ONE_WRITE   ONE_MOVE
                                ALL_SEEK    ALL_WRITE   ALL_MOVE

    we'll have to keep the trigger bits, but can remove the MODE_IS bits
    and replace with CALC_

    need to keep

        FILE_MODE_IS_WRITEMOVE
        FILE_MODE_IS_STEREO
        FILE_MODE_IS_REVERSABLE


*/ comment ~


;// see CALC_TEST for definitions of flags

.DATA

        check_state_table LABEL DWORD
        dd  check_state_bad
        dd  data_CheckState
        dd  gmap_CheckState
        dd  reader_CheckState
        dd  check_state_bad ;// writer_CheckState
        dd  check_state_bad ;// csvreader_CheckState
        dd  check_state_bad ;// csvwriter_CheckState

        get_buffer_table LABEL DWORD
        dd  get_buffer_bad
        dd  data_GetBuffer
        dd  get_buffer_memory
        dd  reader_GetBuffer
        dd  get_buffer_bad  ;// writer_GetBuffer
        dd  get_buffer_bad  ;// csvreader_GetBuffer
        dd  get_buffer_bad  ;// csvwriter_GetBuffer


.CODE

ASSUME_AND_ALIGN
data_Calc::
gmap_Calc::
reader_Calc::
file_Calc_general PROC STDCALL

    ;// data pointers

        LOCAL s_trigger_pointer:DWORD   ;// ptr to seek input data
        LOCAL p_data_pointer:DWORD      ;// ptr to position input data
        LOCAL w_trigger_pointer:DWORD   ;// ptr to write trigger input data
        LOCAL m_trigger_pointer:DWORD   ;// ptr to move trigger input data
        LOCAL sr_data_pointer:DWORD     ;// ptr to sample rate input data

        LOCAL l_data_pointer:DWORD      ;// ptr to left input data
        LOCAL r_data_pointer:DWORD      ;// ptr to right input data

        LOCAL fract_sample_rate:REAL4   ;// cached or calculated
        LOCAL seek_position:REAL4       ;// where we store seek

        LOCAL int_s_prev:DWORD
        int_s_now   TEXTEQU <[esi].file.file_length>
        flt_s_prev  TEXTEQU <[esi].pin_Sout.dwUser>

        LOCAL int_p_prev:DWORD
        int_p_now   TEXTEQU <[esi].file.file_position>
        flt_p_prev  TEXTEQU <[esi].pin_Pout.dwUser>


        ASSUME esi:PTR OSC_FILE_MAP

;// debug tag

        FILE_DEBUG_MESSAGE <"file_Calc ENTER-----------------------------\n">

;// CHECK STATE

        mov eax, [esi].dwUser
        and eax, FILE_MODE_TEST

        call check_state_table[eax*4]
        TESTJMP eax, eax, jz all_done       ;// don't do bad states

;///////////////////////////////////////////////////////////////////////////////////
;//
;//
;//  CONFIGURE
;//

    ;// dwUser and changing flags

        mov edi, [esi].dwUser
        mov ebx, [esi].dwUser
        and edi, CALC_TEST
        ;// none of these modes have a no gates setting

    ;// initialize the position output mechanism

        .IF [esi].pin_Pout.pPin ;// only if connected
            and [esi].pin_Pout.dwStatus, NOT PIN_CHANGING   ;// turn this off
            mov eax, int_p_now      ;// get the current file position
            .IF [esi].file.file_length
                fild [esi].file.file_position
                fidiv [esi].file.file_length
                .IF ebx & FILE_SEEK_NORM
                    fadd st, st
                    fsub math_1
                .ENDIF
            .ELSE   ;// zero length
                fldz
            .ENDIF
            fstp flt_p_prev         ;// store the p_prev
            mov int_p_prev, eax     ;// store as previous position
        .ENDIF

    ;// initialize the size output mechanism

        .IF [esi].pin_Sout.pPin ;// only if connected
            and [esi].pin_Sout.dwStatus, NOT PIN_CHANGING   ;// turn this off
            mov eax, int_s_now  ;// load the current file length
            fld1                ;// one is the default float length
            .IF eax             ;// if not zero
                fidiv int_s_now ;// then do the division
            .ENDIF
            mov int_s_prev, eax ;// store the current size as the old
            fstp flt_s_prev     ;// store the prev value as prev
        .ENDIF

    ;// SEEK
    ;//
    ;//     p_trigger_pointer
    ;//     p_data_pointer

        xor ecx, ecx
        xor eax, eax
        xor edx, edx

        ;// all three modes are seekable
        ;// don't bother to check FILE_MODE_IS_SEEKABLE

                OR_GET_PIN [esi].pin_s.pPin, eax
                jz SS_4                     ;// connected ?
                test [eax].dwStatus, PIN_CHANGING;// s is connected, changing?
                mov eax, [eax].pData        ;// s is connected, get the data pointer
                jz SS_1                     ;// changing ?
                or edi, CALC_YES_SEEK       ;// s is changing and connected
                jmp SS_6
        SS_4:   mov eax, math_pNull         ;// s is not connected
        SS_1:   test ebx, FILE_SEEK_GATE    ;// s is not changing
                jnz SS_2
                or edi, CALC_ONE_SEEK OR CALC_YES_SEEK ;// not gate mode
                jmp SS_6
        SS_2:   or edx, DWORD PTR [eax]     ;// gate mode, input not changing
                jns SS_3                    ;// gate mode, input is always negative
                test ebx, FILE_SEEK_NEG     ;// .IF ebx & FILE_SEEK_NEG
                jmp SS_8
        SS_3:   test ebx, FILE_SEEK_POS;//  .ELSEIF ebx & FILE_SEEK_POS ;// gate mode, input always positive
        SS_8:   jz SS_6
        SS_7:   or edi, CALC_ALL_SEEK
        SS_6:   mov s_trigger_pointer, eax

        ;// load and check the P input pin

                OR_GET_PIN [esi].pin_P.pPin, ecx    ;// load and test the pin
                jz PP_0                             ;// if not connected, bail
                test [ecx].dwStatus, PIN_CHANGING   ;// check for changing data
                mov ecx, [ecx].pData                ;// load the data pointer
                jz PP_1                             ;// if not changing, set the same seek flag
                jmp PP_2                            ;// otherwise just store the pointer
        PP_0:   mov ecx, math_pNull
        PP_1:   or edi, CALC_SAME_SEEK          ;// here we also have an opurtunity for early out
                ;// since we're stuck, determine the position
                fild [esi].file.file_length     ;// S       always positive
                fld DWORD PTR [ecx]             ;// P   S
                .IF ebx & FILE_SEEK_NORM        ;//         normalized = (P+1)*length*0.5
                    fld math_1_2                ;// 1/2 P   S
                    fmulp st(2), st             ;// P   S/2
                    fadd math_1                 ;// P+1 S/2
                .ELSE                           ;//         percentage = abs(P*length)
                    fabs                        ;// P   S   percent is always positive
                .ENDIF
                fmul                            ;// multiply to get new position
                fistp seek_position             ;// store results
        PP_2:   mov p_data_pointer, ecx


    ;// WRITE
    ;//
    ;//     w_trigger_pointer

        xor eax, eax
        xor edx, edx
        xor ecx, ecx

                OR_GET_PIN [esi].pin_w.pPin, eax
                jz WW_4                     ;// connected ?
                test [eax].dwStatus, PIN_CHANGING;// w is connected, changing?
                mov eax, [eax].pData        ;// w is connected, get the data pointer
                jz WW_1                     ;// changing ?
                or edi, CALC_YES_WRITE      ;// w is changing and connected
                jmp WW_6
        WW_4:   mov eax, math_pNull         ;// w is not connected
        WW_1:   test ebx, FILE_WRITE_GATE   ;// w is not changing
                jnz WW_2
                or edi, CALC_ONE_WRITE OR CALC_YES_WRITE ;// not gate mode
                jmp WW_6
        WW_2:   or edx, DWORD PTR [eax]     ;// gate mode, input not changing
                jns WW_3                    ;// gate mode, input is always negative
                test ebx, FILE_WRITE_NEG        ;// .IF ebx & FILE_WRITE_NEG
                jmp WW_8
        WW_3:   test ebx, FILE_WRITE_POS;//     .ELSEIF ebx & FILE_WRITE_POS    ;// gate mode, input always positive
        WW_8:   jz WW_6
        WW_7:   or edi, CALC_ALL_WRITE
        WW_6:   mov w_trigger_pointer, eax

            mov ecx, [esi].pin_Lin.pPin
            .IF ecx
                mov ecx, [ecx].pData
            .ELSE
                mov ecx, math_pNull         ;// we know at this point that we have no input data
            .ENDIF
            mov l_data_pointer, ecx

            .IF ebx & FILE_MODE_IS_STEREO

                mov ecx, [esi].pin_Rin.pPin
                .IF ecx
                    mov ecx, [ecx].pData
                .ELSE
                    mov ecx, math_pNull ;// we know at this point that we have no input data
                .ENDIF
                mov r_data_pointer, ecx

            .ENDIF


    ;// MOVE
    ;//
    ;//     m_trigger_pointer
    ;//     sr_data_pointer
    ;//     F sample rate

        xor eax, eax
        xor edx, edx
        xor ecx, ecx

        ;// all three modes are moveable
        ;// so don't bother to check FILE_MODE_IS_MOVEABLE

                OR_GET_PIN [esi].pin_m.pPin, eax
                jz MM_4                     ;// connected ?
                test [eax].dwStatus, PIN_CHANGING;// m is connected, changing?
                mov eax, [eax].pData        ;// m is connected, get the data pointer
                jz MM_1                     ;// changing ?
                or edi, CALC_YES_MOVE       ;// m is changing and connected
                jmp MM_6
        MM_4:   mov eax, math_pNull         ;// m is not connected
        MM_1:   test ebx, FILE_MOVE_GATE    ;// m is not changing
                jnz MM_2
                or edi, CALC_ONE_MOVE OR CALC_YES_MOVE ;// not gate mode
                jmp MM_6
        MM_2:   or edx, DWORD PTR [eax]     ;// gate mode, input not changing
                jns MM_3                    ;// gate mode, input is always negative
                test ebx, FILE_MOVE_NEG     ;// .IF ebx & FILE_MOVE_NEG
                jmp MM_8
        MM_3:   test ebx, FILE_MOVE_POS;//  .ELSEIF ebx & FILE_MOVE_POS ;// gate mode, input always positive
        MM_8:   jz MM_6
        MM_7:   or edi, CALC_ALL_MOVE
        MM_6:   mov m_trigger_pointer, eax

        ;// check now for CALC_ALL_SEEK, which always overrides move

            .IF edi & CALC_ALL_SEEK

                and edi, NOT ( CALC_ALL_MOVE OR CALC_YES_MOVE OR CALC_ONE_MOVE )
                ;// eax has the trigger pointer
                mov eax, DWORD PTR [eax+LAST_SAMPLE]        ;// get the last trigger in this frame
                mov [esi].pin_m.dwUser, eax     ;// store as first trigger for next frame

            .ELSE   ;// CALC_ALL_SEEK is off

            ;// do the sample rate

                mov ecx, [esi].pin_sr.pPin  ;// get the sample rate pin
                test ecx, ecx               ;// make sure it's connected
                jz use_default_sample_rate  ;// if not conneceted, use the default rate

            ;// sr pin is connected, see if it's changing

                test [ecx].dwStatus, PIN_CHANGING
                mov ecx, [ecx].pData    ;// get the data pointer now
                jnz have_sr_pointer     ;// if changing, then we have m and sr pointers

            ;// static data, cache the fraction

                fld DWORD PTR [ecx] ;// load rate from input data
                fmul math_2_24      ;// scale to fraction
                xor ecx, ecx        ;// clear so mover knows
                jmp determine_fixed_fraction ;// jump to conditioner

            ;// not connected, use default rate
            use_default_sample_rate:

                .IF [esi].file.fmt_rate != -1
                    fild [esi].file.fmt_rate
                .ELSE
                    fld math_44100
                .ENDIF
                fmul math_1_44100_2_24

            determine_fixed_fraction:

                .IF !(ebx & FILE_MODE_IS_REVERSABLE)
                    fabs
                .ENDIF
                fistp fract_sample_rate
                mov edx, fract_sample_rate
                shl edx, 6              ;// shift implied sign bit into real sign bit
                sar edx, 6              ;// sign extend back into place
                mov fract_sample_rate, edx

            have_sr_pointer:

                mov sr_data_pointer, ecx

            .ENDIF


    ;// EARLY OUT TESTS ?
        ;// SEEK     WRITE
        ;// ALL SAME ALL YES ONE
        ;// 0   x    x   x   x      NO
        ;// 0   0    x   x   x      NO
        ;// 0   0    1   x   x      NO
        ;// 1   1    0   0   0      YES
        ;// 1   1    0   1   0      NO
        ;// 1   1    0   1   1      YES
        ;// ----------

        mov eax, edi
        and eax, CALC_ALL_SEEK OR CALC_SAME_SEEK OR CALC_ALL_WRITE OR CALC_YES_WRITE OR CALC_ONE_WRITE
        .IF eax == CALC_ALL_SEEK OR CALC_SAME_SEEK || eax == CALC_ALL_SEEK OR CALC_SAME_SEEK OR CALC_YES_WRITE OR CALC_ONE_WRITE
            or edi, CALC_EARLY_OUT  ;// ??
        .ENDIF


;//
;//
;//  CONFIGURE
;//
;///////////////////////////////////////////////////////////////////////////////////



                        ;// esi is osc map
        mov ebx, edi    ;// ebx is calc flags
                        ;// edi will hold file_position

;///////////////////////////////////////////////////////////////////////////////////
;//
;// CALC LOOP
;//

        xor ecx, ecx    ;// ecx counts,indexes

    ;// always call verify_file_position

        mov edi, [esi].file.file_position
        call verify_file_position
        TESTJMP eax, eax, jz have_to_abort

    ALIGN 16
    .REPEAT

    ;// SEQUENCE    edi is file_position at start of loop
    ;//
    ;//     seek    may update edi
    ;//     write   verify_file_position
    ;//     move    unless seeked, may update edi
    ;//     read    verify_file_position
    ;//     position store the current position
    ;//     size    store the current size

    ;//////////////////////////////////////////////////////////////////////////////////
    ;//         this section must be hit to ensure that trigger input values are updated correctly
    ;// SEEK    task: seek if triggered, exit with edi=file_position
    ;//
    ;//////////////////////////////////////////////////////////////////////////////////

    ;// ecx must enter as sample index
    ;// ebx must enter as dwUser
    ;// uses eax, edx

        and ebx, NOT CALC_HAVE_SEEKED       ;// need to turn this off
        mov edi, [esi].file.file_position   ;// load this now, we may replace it if we are seeked

        TESTJMP ebx, CALC_ALL_SEEK,     jnz s_are_triggered
        TESTJMP ebx, CALC_YES_SEEK,     jz  s_not_triggered
        BITRJMP ebx, CALC_ONE_SEEK,     jnc s_not_one_seek
        BITR    ebx, CALC_YES_SEEK      ;// turn off bit

    s_not_one_seek: mov eax, s_trigger_pointer
                    ASSUME eax:PTR DWORD

                    mov edx, [esi].pin_s.dwUser ;// last_s_data_pointer
                    mov eax, [eax+ecx*4]
                    mov [esi].pin_s.dwUser, eax ;// last_s_data_pointer, eax

                    TESTJMP ebx, FILE_SEEK_GATE,jz s_not_gate

    s_are_gate:     TESTJMP ebx, FILE_SEEK_POS, jz s_neg_gate
    s_pos_gate:     TESTJMP eax, eax,           js s_not_triggered
                    jmp s_are_triggered
    ALIGN 16
    s_neg_gate:     TESTJMP eax, eax,           jns s_not_triggered
                    jmp s_are_triggered
    ALIGN 16
    s_not_gate:     TESTJMP ebx, FILE_SEEK_POS OR FILE_SEEK_NEG,        jnz s_are_edge
    s_both_edge:    XORJMP eax, edx,            js s_are_triggered
                    jmp s_not_triggered
    ALIGN 16
    s_are_edge:     TESTJMP ebx, FILE_SEEK_POS, jz s_neg_edge
    s_pos_edge:     TESTJMP edx, edx,           jns s_not_triggered
                    TESTJMP eax, eax,           jns s_are_triggered
                    jmp s_not_triggered
    ALIGN 16
    s_neg_edge:     TESTJMP edx, edx,           js s_not_triggered
                    TESTJMP eax, eax,           js s_are_triggered
                    jmp s_not_triggered
    ALIGN 16
    s_are_triggered:
    ;// note that we DO NOT set the file_position
    ;// we leave that to verify_position
    ;// only edi is set with the desired file position

            .IF !(ebx & CALC_SAME_SEEK)
                mov eax, p_data_pointer         ;// load the data pointer
                xor edx, edx                    ;// clear for testing
                fild [esi].file.file_length     ;// S       always positive
                fld DWORD PTR [eax+ecx*4]       ;// P   S
                .IF ebx & FILE_SEEK_NORM        ;//         normalized = (P+1)*length*0.5
                    fld math_1_2                ;// 1/2 P   S
                    fmulp st(2), st             ;// P   S/2
                    fadd math_1                 ;// P+1 S/2
                .ELSE                           ;//         percentage = abs(P*length)
                    fabs                        ;// P   S   percent is always positive
                .ENDIF
                fmul                            ;// multiply to get new position
                mov [esi].file.position_accumulator, 0  ;// reset the position acumulator
                fistp seek_position             ;// store results
            .ENDIF
            BITS ebx, CALC_HAVE_SEEKED      ;// we have seeked
            mov eax, seek_position          ;// retrieve results as new position
            mov edi, eax                    ;// set edi as the new position (note that it is not stored)

    ALIGN 16
    s_not_triggered:
    done_with_s_test:


    ;//////////////////////////////////////////////////////////////////////////////////
    ;//         this section must be hit to ensure that trigger input values are updated correctly
    ;// WRITE   task: if triggered, write data at file_position edi
    ;//               call verify position if nessesary
    ;//////////////////////////////////////////////////////////////////////////////////

    ;// ecx must enter as sample index
    ;// ebx must enter as dwUser
    ;// uses eax, edx

        TESTJMP ebx, CALC_ALL_WRITE,        jnz w_are_triggered
        TESTJMP ebx, CALC_YES_WRITE,        jz  w_not_triggered
        BITRJMP ebx, CALC_ONE_WRITE,        jnc w_not_one_write
        BITR    ebx, CALC_YES_WRITE         ;// turn the bit off

    w_not_one_write:

        mov eax, w_trigger_pointer
        mov edx, [esi].pin_w.dwUser ;// last_w_data_iterator
        mov eax, [eax+ecx*4]
        mov [esi].pin_w.dwUser, eax ;// last_w_data_iterator, eax

        TESTJMP ebx, FILE_WRITE_GATE,   jz w_not_gate

    w_are_gate: TESTJMP ebx, FILE_WRITE_POS, jz w_neg_gate
    w_pos_gate: TESTJMP eax, eax,       js w_not_triggered
                jmp w_are_triggered
    ALIGN 16
    w_neg_gate: TESTJMP eax, eax,       jns w_not_triggered
                jmp w_are_triggered
    ALIGN 16
    w_not_gate: TESTJMP ebx, FILE_WRITE_POS OR FILE_WRITE_NEG,jnz w_are_edge
    w_both_edge:XORJMP eax, edx,        js w_are_triggered
                jmp w_not_triggered
    ALIGN 16
    w_are_edge: TESTJMP ebx, FILE_WRITE_POS, jz w_neg_edge
    w_pos_edge: TESTJMP edx, edx,       jns w_not_triggered
                TESTJMP eax, eax,       jns w_are_triggered
                jmp w_not_triggered
    ALIGN 16
    w_neg_edge: TESTJMP edx, edx,       js w_not_triggered
                TESTJMP eax, eax,       js w_are_triggered
                jmp w_not_triggered

    ALIGN 16
    w_are_triggered:

            TESTJMP ebx, CALC_POSITION_STUCK, jnz done_with_w_test  ;// if we are stuck, do not write

            ;// check if we've moved
            .IF edi != [esi].file.file_position
                call verify_file_position
                TESTJMP eax, eax, jz have_to_abort
            .ENDIF

            ;// ABOX232: must also check if dirty >= buffer_stop
            .IF edi >= [esi].file.buf.stop
                call load_new_buffers
            .ENDIF

            or [esi].file.buf.dwFlags, DATA_BUFFER_DIRTY

            ;// LEFT

                mov edx, edi                ;// xfer file position to edx
                sub edx, [esi].file.buf.start;// subtract start of buffer
                shl edx, 2                  ;// convert to dword index
                add edx, [esi].file.buf.pointer;// add the memory buffer address

                mov eax, l_data_pointer     ;// get the start of the input data frame
                mov eax, [eax+ecx*4]        ;// load the indexed dword from input frame
                mov [edx], eax              ;// store the data

            ;// RIGHT

                TESTJMP ebx, FILE_MODE_IS_STEREO, jz done_with_w_test

                ;// edx is already set up at left channel
                add edx, DATA_BUFFER_LENGTH * 4 ;// right channel

                mov eax, r_data_pointer     ;// get the start of the input data frame
                mov eax, [eax+ecx*4]        ;// load the index dword from input frame
                mov [edx], eax              ;// store the data

        ;// jmp done_with_w_test

    ALIGN 16
    w_not_triggered:
    done_with_w_test:

    ;/////////////////////////////////////////////////////////////////////////////
    ;//         this section must be hit to ensure that trigger input values are updated correctly
    ;// MOVE
    ;//
    ;/////////////////////////////////////////////////////////////////////////////

    ;// ecx must enter as sample index
    ;// ebx must enter as dwUser
    ;// uses eax, edx

        TESTJMP ebx, CALC_ALL_MOVE,     jnz m_are_triggered
        TESTJMP ebx, CALC_YES_MOVE,     jz  m_not_triggered
        BITRJMP ebx, CALC_ONE_MOVE,     jnc m_not_one_move
        BITR    ebx, CALC_YES_MOVE      ;// turn the bit off

    m_not_one_move:

        mov eax, m_trigger_pointer
        mov edx, [esi].pin_m.dwUser ;// last_m_data_iterator
        mov eax, [eax+ecx*4]
        mov [esi].pin_m.dwUser, eax ;// last_m_data_iterator, eax

                    TESTJMP ebx, FILE_MOVE_GATE,jz m_not_gate

    m_are_gate_mode:TESTJMP ebx, FILE_MOVE_POS, jz m_neg_gate
    m_pos_gate:     TESTJMP eax, eax,           js m_not_triggered
                    jmp m_are_triggered
    ALIGN 16
    m_neg_gate:     TESTJMP eax, eax,           jns m_not_triggered
                    jmp m_are_triggered
    ALIGN 16
    m_not_gate:     TESTJMP ebx, FILE_MOVE_TEST,jnz m_are_edge
    m_both_edge:    XORJMP eax, edx,            js m_are_triggered
                    jmp m_not_triggered
    ALIGN 16
    m_are_edge:     TESTJMP ebx, FILE_MOVE_POS, jz m_neg_edge
    m_pos_edge:     TESTJMP edx, edx,           jns m_not_triggered
                    TESTJMP eax, eax,           jns m_are_triggered
                    jmp m_not_triggered
    ALIGN 16
    m_neg_edge:     TESTJMP edx, edx,           js m_not_triggered
                    TESTJMP eax, eax,           js m_are_triggered
                    jmp m_not_triggered
    ALIGN 16
    m_are_triggered:

        TESTJMP ebx, CALC_HAVE_SEEKED, jnz done_with_m_test ;// don't bother testing already seeked

            xor eax, eax            ;// clear for testing
            xor edx, edx            ;// clear as overflow indicator

        ;// advance or retreat

            or eax, sr_data_pointer     ;// test the data pointer
            jnz M_11                    ;// have external connection ?

        ;// sr not connected or static, use fixed rate

            or eax, fract_sample_rate   ;// load and test static rate
            js M_20                     ;// if neg, jump to backwards

        ;// counting forwards

    M_10:   add eax, [esi].file.position_accumulator
            test eax, 0FF000000h    ;// overflow ?
            jz  M_23                ;// jump if not (edx is zero, no need to add)
            ;// got overflow
            shld edx, eax, 8        ;// scoot overflow into edx
            and eax, 000FFFFFFh     ;// mask out integer part
            ;// advance accumulator
    M_21:   add edi, edx            ;// advance edi with overflow
            ;// ready to store accumulator
    M_23:   mov [esi].file.position_accumulator, eax    ;// save accumulated fraction
            jmp done_with_m_test

        ;// have an external data pointer

    M_11:   fld DWORD PTR [eax+ecx*4]   ;// load the sample rate
            fmul math_2_24              ;// scale to 8:24 fraction
            .IF !(ebx & FILE_MODE_IS_REVERSABLE)
                fabs
            .ENDIF
            fistp fract_sample_rate
            mov eax, fract_sample_rate
            shl eax, 6              ;// shift implied sign bit into real sign bit
            sar eax, 6              ;// sign extend back into place
            jns M_10                ;// counting forwards ?

    ;// counting backwards

    M_20:   add eax, [esi].file.position_accumulator
            test eax, 0FF000000h    ;// over flow ?
            jz  M_23                ;// jmp if no overflow (no need to add edx to edi)
            ;// got overflow
            shld edx, eax, 8        ;// scoot overflow into edx
            and eax, 000FFFFFFh     ;// mask out integer part
            movsx edx, dl
            jmp M_21

    ALIGN 16
    done_with_m_test:
    m_not_triggered:


    ;/////////////////////////////////////////////////////////////////////////////
    ;//
    ;//     READ
    ;//
    ;/////////////////////////////////////////////////////////////////////////////


        .IF edi != [esi].file.file_position
            call verify_file_position
            TESTJMP eax, eax, jz have_to_abort
        .ENDIF

        ;// we have 4 states plus not first sample and yes first sample
        ;// read_not_stuck_mono
        ;// read_yes_stuck_mono
        ;// read_not_stuck_stereo
        ;// read_yes_stuck_stereo

            xor eax, eax
            xor edx, edx

            TESTJMP ebx, CALC_POSITION_STUCK, jnz read_yes_stuck
        read_not_stuck:
            mov edx, edi
            sub edx, [esi].file.buf.start
            shl edx, 2
            add edx, [esi].file.buf.pointer
            test ebx, FILE_MODE_IS_STEREO
            mov eax, [edx]
            jz read_store_mono
            mov edx, [edx+DATA_BUFFER_LENGTH*4]
        read_store_stereo:
            mov [esi].data_R[ecx*4], edx
            .IF ecx && edx != [esi].data_R[ecx*4-4]
                or ebx, CALC_ROUT_CHANGING
            .ENDIF
        read_store_mono:
            mov [esi].data_L[ecx*4], eax
            .IF ecx && eax != [esi].data_L[ecx*4-4]
                or ebx, CALC_LOUT_CHANGING
            .ENDIF
            jmp read_done

        ALIGN 16
        read_yes_stuck:
            test ebx, FILE_MODE_IS_STEREO
            jnz read_store_stereo
            jmp read_store_mono

        ALIGN 16
        read_done:

            mov [esi].file.file_position, edi   ;// now we have a new file posirion


    ;// POSITION

            .IF [esi].pin_Pout.pPin ;// only if connected
                mov eax, int_p_now      ;// get the current file position
                cmp eax, int_p_prev     ;// compare with old
                mov edx, flt_p_prev     ;// load float prev position
                .IF !ZERO?              ;// if new and old are different
                    .IF [esi].file.file_length
                        fild [esi].file.file_position
                        fidiv [esi].file.file_length
                        .IF ebx & FILE_SEEK_NORM
                            fadd st, st
                            fsub math_1
                        .ENDIF
                    .ELSE   ;// zero length
                        fldz
                    .ENDIF
                    fstp flt_p_prev     ;// edx stil has previous
                .ENDIF
                mov eax, flt_p_prev     ;// load the now correct flt prev position
                cmp edx, eax            ;// compare with previous flt prev position
                mov [esi].data_P[ecx*4], eax    ;// store the new value, always
                .IF !ZERO?              ;// if float value are different
                    or [esi].pin_Pout.dwStatus, PIN_CHANGING
                .ENDIF
            .ENDIF

        ;// SIZE

            .IF [esi].pin_Sout.pPin ;// only if connected
                mov eax, int_s_now      ;// get the current file length
                cmp eax, int_s_prev     ;// compare with old
                mov edx, flt_s_prev     ;// load float prev length
                .IF !ZERO?              ;// if new and old are different
                    mov int_s_prev, eax ;// store the new integer file length
                    test eax, eax       ;// check for zero length
                    fld1                ;// calculate the flt_file_length
                    .IF !ZERO?
                        fidiv [esi].file.file_length
                    .ENDIF
                    fstp flt_s_prev     ;// edx stil has previous
                .ENDIF
                mov edi, flt_s_prev     ;// load the now correct flt prev length
                cmp edx, edi            ;// compare with previous flt prev length
                mov [esi].data_S[ecx*4], edi    ;// store the new value, always
                .IF !ZERO?              ;// if float value are different
                    or [esi].pin_Sout.dwStatus, PIN_CHANGING
                .ENDIF
            .ENDIF


        ;// ITERATE and EARLY OUT

            inc ecx

            test ebx, CALC_ALL_SEEK OR CALC_YES_SEEK OR CALC_ALL_WRITE OR CALC_YES_WRITE OR CALC_ALL_MOVE OR CALC_YES_MOVE
            jz early_out
            test ebx, CALC_EARLY_OUT
            jnz early_out

    .UNTIL ecx >= SAMARY_LENGTH

;//
;// CALC LOOP
;//
;///////////////////////////////////////////////////////////////////////////////////


;// CLEANUP

    ;// see if we should redraw

    check_update:

        .IF ebx & CALC_LOUT_CHANGING
            or [esi].pin_Lout.dwStatus, PIN_CHANGING
        .ELSE
            and [esi].pin_Lout.dwStatus, NOT PIN_CHANGING
        .ENDIF

        .IF ebx & CALC_ROUT_CHANGING
            or [esi].pin_Rout.dwStatus, PIN_CHANGING
        .ELSE
            and [esi].pin_Rout.dwStatus, NOT PIN_CHANGING
        .ENDIF

    all_done:

;// debug tag

        FILE_DEBUG_MESSAGE <"file_Calc EXIT  -----------------------------\n\n">


        ret


ALIGN 16
early_out:

    ;// it has been determined that we have do not need to finish the calc

    ;// copy all the last trigger values

        mov eax, s_trigger_pointer
        mov edx, w_trigger_pointer
        mov ecx, m_trigger_pointer

        mov eax, DWORD PTR [eax+LAST_SAMPLE]
        mov edx, DWORD PTR [edx+LAST_SAMPLE]
        mov ecx, DWORD PTR [ecx+LAST_SAMPLE]

        mov [esi].pin_s.dwUser, eax
        mov [esi].pin_w.dwUser, edx
        mov [esi].pin_m.dwUser, ecx

    ;// fill the reamaining samples
    ;// to do that we'll we'll summon a function

        lea edi, [esi].pin_Lout
        call early_out_proc
        lea edi, [esi].pin_Rout
        call early_out_proc
        lea edi, [esi].pin_Pout
        call early_out_proc
        lea edi, [esi].pin_Sout
        call early_out_proc

        jmp all_done

ALIGN 16
early_out_proc:

    ;// edi enters as the APIN to test
    ;// the data for edi has only the first value set

        CMPJMP (APIN PTR [edi]).pPin, 0, jz early_out_proc_done
        BITR (APIN PTR [edi]).dwStatus, PIN_CHANGING
        mov edi, (APIN PTR [edi]).pData
        mov eax, [edi]
        jc early_out_to_fill
        cmp eax, [edi+4]
        je early_out_proc_done
    early_out_to_fill:
        mov ecx, SAMARY_LENGTH-1
        add edi, 4
        rep stosd
    early_out_proc_done:
        retn





;//////////////////////////////////////////////////////////////////////////////////


;// local functions

ALIGN 16
have_to_abort:

    ;// task
    ;//
    ;//     fill remaining data with 0

    mov edx, ecx
    sub ecx, SAMARY_LENGTH
    xor eax, eax
    neg ecx

    push ecx

    .IF ebx & FILE_MODE_IS_READABLE

    ;// LEFT

        lea edi, [esi].data_L[edx*4]
        .IF edx
            cmp eax, DWORD PTR [edi-4]
            .IF !ZERO?
                or [esi].pin_Lout.dwStatus, PIN_CHANGING
            .ENDIF
        .ENDIF
        rep stosd

    ;// RIGHT

        ;// RIGHT
        .IF ebx & FILE_MODE_IS_STEREO

            lea edi, [esi].data_R[edx*4]
            .IF edx
                cmp eax, DWORD PTR [edi-4]
                .IF !ZERO?
                    or [esi].pin_Rout.dwStatus, PIN_CHANGING
                .ENDIF
            .ENDIF
            mov ecx, [esp]
            rep stosd
        .ENDIF


    .ENDIF

    ;// POSITION
    .IF [esi].pin_Pout.pPin

        lea edi, [esi].data_P[edx*4]
        .IF edx
            cmp eax, DWORD PTR [edi-4]
            .IF !ZERO?
                or [esi].pin_Pout.dwStatus, PIN_CHANGING
            .ENDIF
        .ENDIF
        mov ecx, [esp]
        rep stosd
    .ENDIF

    ;// SIZE

    .IF [esi].pin_Sout.pPin

        lea edi, [esi].data_S[edx*4]
        .IF edx
            cmp eax, DWORD PTR [edi-4]
            .IF !ZERO?
                or [esi].pin_Sout.dwStatus, PIN_CHANGING
            .ENDIF
        .ENDIF
        mov ecx, [esp]
        rep stosd
    .ENDIF

    ;// that's it

    pop ecx

    jmp check_update










ALIGN 16
verify_file_position:

    ;// determine if we need to rewind, load buffer, and save buffer
    ;// also determine if we are stuck at one end or the other

    ;// edi has the new position
    ;// ebx has dwUser
    ;// preserve ecx

    ;// return eax as non-zero to indicate that calc should continue

        mov eax, [esi].file.file_length                 ;// load eax with the length
        TESTJMP edi, edi, js file_position_before_start ;// signed
        CMPJMP edi, eax, jae file_position_passed_end   ;// unsigned

    check_buffer_position:  ;// position should be OK

        mov [esi].file.file_position, edi   ;// store updated position
        and ebx, NOT CALC_POSITION_STUCK        ;// turn this off

        CMPJMP edi, [esi].file.buf.stop, jae    load_new_buffers    ;// see if data is in memory
        CMPJMP edi, [esi].file.buf.start, jb load_new_buffers       ;// see if data is in memory

    verify_file_position_done:
    check_state_bad::   ;// eax is already zero, so we just return
    get_buffer_bad::    ;// eax is zero for bad
    get_buffer_memory:: ;// eax is not zero for good

        retn


    ALIGN 16
    file_position_before_start:

        TESTJMP ebx, FILE_MOVE_LOOP, jnz do_modulo_position
        or edi, -1      ;// set as before start so a move can get us out of this
        or ebx, CALC_POSITION_STUCK     ;// set the is stuck flag
        or eax, 1   ;// we are still good
        mov [esi].file.file_position, edi   ;// store updated position
        jmp verify_file_position_done

    ALIGN 16
    file_position_passed_end:

        TESTJMP ebx, FILE_MOVE_LOOP, jnz do_modulo_position
        ;// therefore we are stuck passed the end
        mov edi, eax    ;// set as file length
        or ebx, CALC_POSITION_STUCK     ;// set the is stuck flag
        or eax, 1   ;// we are still good
        mov [esi].file.file_position, edi   ;// store updated position
        jmp verify_file_position_done

    ALIGN 16
    do_modulo_position:

    ;// edi has the desired poisition
    ;// eax has the current file size
    ;// we are to wrap edi around eax
    ;// edi may be negative

        xchg eax, edi       ;// want to divide position by length
        cdq                 ;// always sign extend
        idiv edi            ;// edx has the remainder, which may be negative
        test edx, edx
        .IF SIGN?
            add edx, edi    ;// add the length to get into the file
        .ENDIF
        mov edi, edx
        or eax, 1           ;// have to return good
        jmp check_buffer_position   ;// and jump to the buffer checker

   ;// example of above
   ;// eax = -3
   ;// edi = 4
   ;// rem -3 / 4 = -3
   ;// then -3 + 4 = +1, the correct position


    ALIGN 16
    load_new_buffers:

    ;// file_position has the buffer to get

        mov eax, ebx    ;// dwUser
        and eax, FILE_MODE_TEST
        call get_buffer_table[eax*4]
        ;// eax has the return value
        test eax, eax
        jz verify_file_position_done

    ;// do another check for bad buffers

        cmp edi, [esi].file.buf.stop    ;// see if data is in memory
        jae enter_seek_only

        cmp edi, [esi].file.buf.start   ;// see if data is in memory
        jae verify_file_position_done

    enter_seek_only:

        ;// we did not read where we wanted to !!

        or ebx, CALC_POSITION_STUCK
        jmp verify_file_position_done


file_Calc_general ENDP

;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
file_PrePlay PROC

        ASSUME esi:PTR OSC_FILE_MAP

        xor eax, eax

    ;// reset triggers

        mov [esi].pin_m.dwUser, eax
        mov [esi].pin_s.dwUser, eax
        mov [esi].pin_w.dwUser, eax

    ;// reset last  position

        mov [esi].pin_Pout.dwUser, eax

    ;// rewind .... only if it is ok to do so

        .IF !([esi].dwUser & FILE_MODE_IS_NOREWIND)

            mov [esi].file.file_position, eax
            mov [esi].file.position_accumulator, eax

        .ENDIF

    ;// eax is zero, play preplay will clear our data

        ret

file_PrePlay ENDP

;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////





ASSUME_AND_ALIGN

ENDIF   ;// USE_THIS_FILE

END



comment ~ /*


    this can be reduced by determining when operations need done

    test_s  ONCE ALL    2
    test_m  ONCE ALL    2           seek blocks move
    test_w  ONCE ALL    2
    move    ONCE ALL    2   = 128
    read    ONCE ALL    2
    seek    ONCE ALL    2
    write   ONCE ALL    2

    ONCE means do the operation before main loop, apply results as required
    ALL means that the operation must be performed every sample

    test_x can be implemeted with a call pointer, or perhaps SMC

    SEEK    yes,no  16 paths
    WRITE   yes,no
    MOVE    yes,no
    READ    yes,no

    another option is to maintain a flag dword
    some values might be
        abort calc
        fill static
        no more seeks

    seek_write_move_read:
    SEEK_write_move_read:

    seek_WRITE_move_read:
    SEEK_WRITE_move_read:

    seek_write_MOVE_read:
    SEEK_write_MOVE_read:

    seek_WRITE_MOVE_read:
    SEEK_WRITE_MOVE_read:

    seek_write_move_READ:
    SEEK_write_move_READ:

    seek_WRITE_move_READ:
    SEEK_WRITE_move_READ:

    seek_write_MOVE_READ:
    SEEK_write_MOVE_READ:

    seek_WRITE_MOVE_READ:
    SEEK_WRITE_MOVE_READ:


*/ comment ~
