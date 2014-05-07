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
;//  xlate.asm      routines to parse files loaded from disk
;//                 the goal if this file is translate object ID's
;//                 into base class pointers
;//
;// TOC:
;//
;// xlate_ABox2File PROC
;//
;// xlate_RotatePins PROC
;// xlate_InsertPins PROC
;//
;// osc_delay_xlate PROC
;// osc_sh_xlate
;// osc_readout_xlate PROC
;// osc_Knob_xlate PROC
;// osc_Slider_xlate PROC
;// osc_MathCon_xlate PROC
;// osc_Button_xlate PROC
;// osc_Random_xlate PROC
;// osc_Rands_xlate PROC
;// osc_Divider_xlate PROC
;// osc_Func1_xlate PROC
;// osc_OScope_xlate PROC
;// osc_Spectrum_xlate PROC
;// osc_Plugin_xlate PROC
;// xlate_adsr PROC
;// xlate_probe PROC
;// xlate_splitter PROC
;// pinint_xlate PROC
;// group_xlate PROC
;// file_xlate PROC
;// midiin_xlate
;// midiout_xlate
;//
;// xlate_ABox1File PROC uses ebp



OPTION CASEMAP:NONE
.586
.MODEL FLAT

    .NOLIST
    INCLUDE <Abox.inc>
    INCLUDE <groups.inc>
    .LIST
;// .LISTALL
;// .LISTMACROALL


comment ~ /*

    for this entire section the following are assumed to be true:

    edi is a pointer to start of the file block
        meaning that edi comes in as a ptr to a FILE_HEADER
        for groups, this may be replaced with a pointer to the group block

        when descending into closed groups, a count (depth) must be maintained
        this can be done using ebp,

    esi is a pointer to the EndOfBlock (pEOB)
        rather than counting, we use this
        iterations that PASS this pointer are to assume that the file data is invalid
        iterations that EQUAL this pointer are assumed to be done

        if a function changes the size of the file, it must adjust all higher
        level pEOB values

*/ comment ~


;// see GROUP_FILE_old and GROUP_FILE for how we navigate through group stacks
;// since we store the descend structs on the stack, we get this struct as well (always local)

    FILE_GROUP_STACK STRUCT

        pOsc    dd  0   ;// pointer to osc header that caused the descend
        pEOB    dd  0   ;// pointer of the pEOB at that time

    FILE_GROUP_STACK ENDS



.DATA

        ;// xlateing abox 2 files requires a specific stack frame
        ;// since we cannot use the stack to to call xlate1 functions,
        ;// we have to store the nessesary registers here

        stored_ebx  dd  0
        stored_ecx  dd  0


;////////////////////////////////////////////////////////////////////
;//
;//                             task is to convert the id's into base pointers
;// ABOX2 FILE TRANSLATOR       functions will return ebx as:
;//                             a bad count
;//                             -1 for corrupted files


    ;// adding pins to the file may corrupt memory
    ;// this table allows us to pre check

        XLATE_RECORD2 STRUCT

            ID  dd  0
            pins_added  dd  0

        XLATE_RECORD2 ENDS


        xlate_table_2 LABEL XLATE_RECORD2
        ;//                                 pins
        ;//             osc ID              ADDED
        ;//             ----------------    ----

        XLATE_RECORD2    {IDB_KNOB_227,     6   }
        XLATE_RECORD2    {IDB_KNOB_220,     6   }
        XLATE_RECORD2    {IDB_KNOB_BETA,    6   }
        XLATE_RECORD2    {IDB_DELAY_old,    3   }
        XLATE_RECORD2    {IDB_SAMHOLD_old,  1   }
        XLATE_RECORD2    {IDB_FILE_old,     7   }
        XLATE_RECORD2    {IDB_FILE_232,     2   }
        XLATE_RECORD2    {IDB_FILE_233,     1   }
        XLATE_RECORD2    {IDB_MIDIIN_old,   7   }
        XLATE_RECORD2    {IDB_MIDIOUT_old,  3   }
        XLATE_RECORD2    {IDB_PLUGIN_219,   2   }
        XLATE_RECORD2    {IDB_DECAY,        1   }
        XLATE_RECORD2    {IDB_DELTA_232,    1   }
        ;//XLATE_RECORD2    {IDB_OSCILLATOR_232, 0 } ;// renumbered in ABOX232
        XLATE_RECORD2    {} ;// terminator




.CODE
ASSUME_AND_ALIGN
xlate_ABox2File PROC

    ASSUME edi:PTR FILE_HEADER  ;// may be replaced
    ;// esi is pEOB             ;// may be replaced



;// part 1  determine if we have enough space

    ;// must return ebx as the bad count
    ;// set ebx negative to indicate corrupted file

        push edi        ;// save file iterator
        push ebp        ;// save whatever ebp was

        xor ebx, ebx    ;// ebx will count pins added
        xor ecx, ecx    ;// 0 for testing
        xor ebp, ebp    ;// ebp will count the depth

        ;// or ecx, [edi].numOsc            ;// get the count
        FILE_HEADER_TO_FIRST_OSC edi    ;// edi will scan the file

        jmp xlate_1_enter_loop

    xlate_1_top_of_loop:

    ;// see if this id is in the xlate table

        mov eax, [edi].id       ;// get the id
        mov edx, OFFSET xlate_table_2
        ASSUME edx:PTR XLATE_RECORD2

    x1_look_top:
        cmp eax, [edx].ID
        je x1_got_it
        add edx, SIZEOF XLATE_RECORD2   ;// next xlate
        cmp ecx, [edx].ID
        jne x1_look_top

    x1_got_it:

        add ebx, [edx].pins_added
        ;// closed group ?
        cmp eax, IDB_CLOSED_GROUP
        je xlate_1_descend_into_group   ;// descend if so

    xlate_1_next_object:

        FILE_OSC_TO_NEXT_OSC edi;// get the next osc

    xlate_1_enter_loop:

        cmp edi, esi            ;// check for passed end of file
        jb xlate_1_top_of_loop  ;// jmp if still oscs left
        ja xlate_corrupted_file ;// jump to our exit if so
        dec ebp                 ;// decrease the depth counter
        js xlate_1_done         ;// if sign, then we're all done

    xlate_1_ascend_outof_group:

        pop esi         ;// retrive pEOB
        pop edi         ;// retrieve the osc pointer
        jmp xlate_1_next_object

    xlate_1_descend_into_group:

        push edi        ;// store the pointer
        push esi        ;// store current pEOB
        inc ebp         ;// increase the depth

        FILE_OSC_TO_FIRST_PIN edi, esi      ;// set the new eob
        lea edi, [edi+SIZEOF GROUP_FILE]    ;// point at first object in group

        jmp xlate_1_enter_loop

    xlate_1_done:

        pop ebp                 ;// retrieve ebp
        pop edi                 ;// retrive edi

    ;// now we have ebx as the number of pins that will be added
    ;// esi points at end of file

        lea ebx, [ebx+ebx*2]    ;// *3 = dwords added
        lea ecx, [esi+ebx*4]    ;// ecx is now the end of memory we need
        sub ecx, edi            ;// ecx is now the number of bytes we need

        .IF ecx >= MEMORY_SIZE(edi)
            ;// have to reallocate

        IFDEF DEBUGBUILD
        .DATA
        abox2_resize_message db 'xlate_ABox2File memory resize hit !!!',0dh,0ah,0
        .CODE
        push ecx
        invoke OutputDebugStringA, OFFSET abox2_resize_message
        pop ecx
        ENDIF

            lea ecx, [ecx+ecx*2]    ;// add half again as much
            shr ecx, 1
            sub esi, edi            ;// old size
            and ecx, -4             ;// dword align
            invoke memory_Expand, edi, ecx
            mov edi, eax
            add esi, edi

        .ENDIF

;// part 2  translate all the ids

    ASSUME edi:PTR FILE_HEADER  ;// now preserved
    ;// esi is pEOB             ;// now preserved

    ;// must return ebx as the bad count
    ;// set ebx negative to indicate corrupted file

        push edi        ;// save
        push ebp        ;// save

        xor ebx, ebx    ;// ebx is the bad count/return code
        xor ecx, ecx    ;// ecx will count oscs
        xor ebp, ebp    ;// ebp will count the depth

        or ecx, [edi].numOsc            ;// get the count
        FILE_HEADER_TO_FIRST_OSC edi    ;// edi will scan the file

        jmp xlate_enter_loop

    xlate_top_of_loop:

        mov eax, [edi].id       ;// get the id
        FILE_ID_TO_BASE eax, edx, got_it    ;// get the base pointer

    not_it:                     ;// ID wasn't found

        cmp eax, IDB_CLOSED_GROUP   ;// closed group ?
        je xlate_descend_into_group ;// descend if so

        CMPJMP eax, IDB_KNOB_227,       je xlate_convert_knob_227
        CMPJMP eax, IDB_KNOB_BETA,      je xlate_convert_knob_beta
        CMPJMP eax, IDB_KNOB_220,       je xlate_convert_knob_220
        CMPJMP eax, IDB_READOUT_BETA,   je xlate_convert_readout
        CMPJMP eax, IDB_DELAY_old,      je xlate_convert_delay
        CMPJMP eax, IDB_SAMHOLD_old,    je xlate_convert_sh
        CMPJMP eax, IDB_FILE_old,       je xlate_convert_file
        CMPJMP eax, IDB_FILE_232,       je xlate_convert_file_232
        CMPJMP eax, IDB_FILE_233,       je xlate_convert_file_233
        CMPJMP eax, IDB_MIDIIN_old,     je xlate_convert_midiin
        CMPJMP eax, IDB_MIDIOUT_old,    je xlate_convert_midiout
        CMPJMP eax, IDB_PLUGIN_219,     je xlate_convert_plugin
        CMPJMP eax, IDB_DECAY,          je xlate_convert_decay
        CMPJMP eax, IDB_DELTA_232,      je xlate_convert_delta
        CMPJMP eax, IDB_OSCILLATOR_232, je xlate_convert_oscillator

        cmp eax, IDB_LOCKTABLE  ;// lock table ??
        jne not_lock            ;// jmp if no
        lea edx, osc_LockTable  ;// load the fake base pointer
        jmp got_it              ;// jump to got it

    not_lock:

        cmp eax, IDB_BUSTABLE   ;// Bus Table ??
        jne got_it              ;// jmp if not, must be a bad object
        lea edx, osc_BusTable   ;// load the fake bus table

    got_it:

        mov [edi].pBase, edx    ;// store the pointer

        or edx, edx             ;// check for nothing found
        jne xlate_next_object   ;// jmp forward if good

    xlate_got_bad_record:

        inc ebx                 ;// increase the bad count

    xlate_next_object:

        FILE_OSC_TO_NEXT_OSC edi;// get the next osc

    xlate_enter_loop:

        cmp edi, esi            ;// check for passed end of file
        jb xlate_top_of_loop    ;// jmp if still oscs left
        ja xlate_corrupted_file ;// jump to our exit if so
        dec ebp                 ;// decrease the depth counter
        js xlate_done           ;// if sign, then we're all done

    xlate_ascend_outof_group:

        pop esi         ;// retrive pEOB
        pop edi         ;// retrieve the osc pointer
        jmp xlate_next_object

    xlate_descend_into_group:

        push edi        ;// store the pointer
        push esi        ;// store current pEOB
        lea edx, closed_Group   ;// load the correct base class
        inc ebp         ;// increase the depth

        mov [edi].pBase, edx    ;// store the base class in the FILE_OSC record
        FILE_OSC_TO_FIRST_PIN edi, esi      ;// set the new eob
        lea edi, [edi+SIZEOF GROUP_FILE]    ;// point at first object in group

        jmp xlate_enter_loop

    xlate_corrupted_file:

        lea esp, [esp+ebp*8]    ;// reset any depth's we might be in
        or ebx, -1              ;// set as corrupted

    xlate_done:

        pop ebp                 ;// retrieve ebp
        pop edi                 ;// retrive edi

        ret


;// local functions

    xlate_knob_turns_221 PROTO  ;// defined in ABox_Knob.asm
    xlate_knob_turns_228 PROTO  ;// defined in ABox_Knob.asm

    xlate_convert_knob_227:

        mov eax, DWORD PTR [edi+SIZEOF FILE_OSC]
        call xlate_knob_turns_228

        jmp xlate_convert_knob_common

    xlate_convert_knob_220:

        ;// xlate the turns

        mov eax, DWORD PTR [edi+SIZEOF FILE_OSC]
        call xlate_knob_turns_221                   ;// will call xlate_knob_turns_228

    xlate_convert_knob_common:

        mov DWORD PTR [edi+SIZEOF FILE_OSC], eax

        mov stored_ebx, ebx
        mov stored_ecx, ecx

        mov ebx, edi

        call osc_knob_convert

        mov ebx, stored_ebx
        mov ecx, stored_ecx

        mov edx, OFFSET osc_Knob
        jmp got_it

    xlate_convert_knob_beta:

        mov eax, DWORD PTR [edi+SIZEOF FILE_OSC]
        call xlate_knob_turns_221               ;// will call xlate_knob_turns_228
        mov DWORD PTR [edi+SIZEOF FILE_OSC], eax

        mov stored_ebx, ebx
        mov stored_ecx, ecx

        mov ebx, edi

        call osc_knob_convert

        mov ebx, stored_ebx
        mov ecx, stored_ecx

        push OFFSET osc_Knob
        jmp xlate_convert_units

    xlate_convert_readout:

        push OFFSET osc_Readout

    xlate_convert_units:

        mov eax, DWORD PTR [edi+SIZEOF FILE_OSC]
        .IF eax & UNIT_OLD_TEST
            invoke unit_ConvertOld
            mov DWORD PTR [edi+SIZEOF FILE_OSC], eax
        .ENDIF

        pop edx
        jmp got_it

    xlate_convert_delay:

    ;// edi is file pointer
    ;// must preserve ecx
    ;// must preserve ebp
    ;// must preserve ebx (file pointer)

        mov stored_ebx, ebx
        mov stored_ecx, ecx

        mov ebx, edi
        call osc_delay_xlate

        EXTERNDEF delay_apin_init_r:APIN_init
        mov eax, delay_apin_init_r.def_pheta
        mov (FILE_PIN PTR [ebx+(SIZEOF FILE_OSC)+4+(SIZEOF FILE_PIN)*2]).pheta, eax

        mov edx, OFFSET osc_Delay

        mov ebx, stored_ebx
        mov ecx, stored_ecx
        jmp got_it

    xlate_convert_sh:
    ;// edi is file pointer
    ;// must preserve ecx
    ;// must preserve ebp
    ;// must preserve ebx (file pointer)

        mov stored_ebx, ebx
        mov stored_ecx, ecx

        mov ebx, edi
        call osc_sh_xlate

        mov edx, OFFSET osc_SamHold

        mov ebx, stored_ebx
        mov ecx, stored_ecx

        jmp got_it



    xlate_convert_file:     ;// does not do file 232
    ;// edi is file pointer
    ;// must preserve ecx
    ;// must preserve ebp
    ;// must preserve ebx (file pointer)

        mov stored_ebx, ebx
        mov stored_ecx, ecx

        mov ebx, edi
        call file_xlate

    ;// set the new pheta values

        EXTERNDEF   osc_File_pin_Li:APIN_init
        EXTERNDEF   osc_File_pin_Ri:APIN_init

        EXTERNDEF   osc_File_pin_w:APIN_init
        EXTERNDEF   osc_File_pin_sr:APIN_init

        EXTERNDEF   osc_File_pin_m:APIN_init
        EXTERNDEF   osc_File_pin_s:APIN_init

        EXTERNDEF   osc_File_pin_P:APIN_init
        EXTERNDEF   osc_File_pin_Lo:APIN_init

        EXTERNDEF   osc_File_pin_Ro:APIN_init
        EXTERNDEF   osc_File_pin_Po:APIN_init

        EXTERNDEF   osc_File_pin_So:APIN_init

        mov ecx, (FILE_OSC PTR [ebx]).extra
        lea ecx, [ebx+ecx+SIZEOF FILE_OSC]
        ASSUME ecx:PTR FILE_PIN

        mov eax, osc_File_pin_Li.def_pheta
        mov edx, osc_File_pin_Ri.def_pheta
        mov [ecx+(SIZEOF FILE_PIN)*0].pheta, eax
        mov [ecx+(SIZEOF FILE_PIN)*1].pheta, edx

        mov eax, osc_File_pin_w.def_pheta
        mov edx, osc_File_pin_sr.def_pheta
        mov [ecx+(SIZEOF FILE_PIN)*2].pheta, eax
        mov [ecx+(SIZEOF FILE_PIN)*3].pheta, edx

        mov eax, osc_File_pin_m.def_pheta
        mov edx, osc_File_pin_s.def_pheta
        mov [ecx+(SIZEOF FILE_PIN)*4].pheta, eax
        mov [ecx+(SIZEOF FILE_PIN)*5].pheta, edx

        mov eax, osc_File_pin_P.def_pheta
        mov edx, osc_File_pin_Lo.def_pheta
        mov [ecx+(SIZEOF FILE_PIN)*6].pheta, eax
        mov [ecx+(SIZEOF FILE_PIN)*7].pheta, edx

        mov eax, osc_File_pin_Ro.def_pheta
        mov edx, osc_File_pin_Po.def_pheta
        mov [ecx+(SIZEOF FILE_PIN)*8].pheta, eax
        mov [ecx+(SIZEOF FILE_PIN)*9].pheta, edx

        mov eax, osc_File_pin_So.def_pheta
        mov [ecx+(SIZEOF FILE_PIN)*10].pheta, eax

        ASSUME ecx:NOTHING

    ;// retreive registers and exit

        mov edx, OFFSET osc_File

        mov ebx, stored_ebx
        mov ecx, stored_ecx

        jmp got_it


    xlate_convert_file_232:

        ;// we are assuming a double call
        ;// otherwise we crash inside groups
        ;// thus we call the next routine

        call xlate_convert_file_232_sub
        jmp got_it


    xlate_convert_file_232_sub:


        ;// add 2 pins, then set their phetas

    ;// edi is file pointer
    ;// must preserve ecx
    ;// must preserve ebp
    ;// must preserve ebx (file pointer)

        mov stored_ebx, ebx
        mov stored_ecx, ecx

        mov ebx, edi

    ;//     0   1   2   3   4   5   6   7   8   9   10
    ;// 232 Li  Ri  w   rs  m   s   P   Lo  Ro
    ;// new Li  Ri  w   rs  m   s   P   Lo  Ro  Po  So

        mov edx, 2
        mov ecx, 9
        call xlate_InsertPins

        mov ecx, (FILE_OSC PTR [ebx]).extra
        lea ecx, [ebx+ecx+SIZEOF FILE_OSC]
        ASSUME ecx:PTR FILE_PIN

        mov eax, osc_File_pin_Po.def_pheta
        mov edx, osc_File_pin_So.def_pheta
        mov [ecx+(SIZEOF FILE_PIN)*9].pheta, eax
        mov [ecx+(SIZEOF FILE_PIN)*10].pheta, edx

        ASSUME ecx:NOTHING

    ;// retreive registers and exit

        mov edx, OFFSET osc_File

        mov ebx, stored_ebx
        mov ecx, stored_ecx

        retn




    xlate_convert_file_233:

        ;// we are assuming a double call
        ;// otherwise we crash inside groups
        ;// thus we call the next routine

        call xlate_convert_file_233_sub
        jmp got_it


    xlate_convert_file_233_sub:


        ;// add 1 pin, then set phetas

    ;// edi is file pointer
    ;// must preserve ecx
    ;// must preserve ebp
    ;// must preserve ebx (file pointer)

        mov stored_ebx, ebx
        mov stored_ecx, ecx

        mov ebx, edi

    ;//     0   1   2   3   4   5   6   7   8   9   10
    ;// 233 Li  Ri  w   rs  m   s   P   Lo  Ro  Po
    ;// new Li  Ri  w   rs  m   s   P   Lo  Ro  Po  So

        mov edx, 1
        mov ecx, 10
        call xlate_InsertPins

        mov ecx, (FILE_OSC PTR [ebx]).extra
        lea ecx, [ebx+ecx+SIZEOF FILE_OSC]
        ASSUME ecx:PTR FILE_PIN

        mov edx, osc_File_pin_So.def_pheta
        mov [ecx+(SIZEOF FILE_PIN)*10].pheta, edx

        ASSUME ecx:NOTHING

    ;// retreive registers and exit

        mov edx, OFFSET osc_File

        mov ebx, stored_ebx
        mov ecx, stored_ecx

        retn























    xlate_convert_midiin:
    ;// edi is file pointer
    ;// must preserve ecx
    ;// must preserve ebp
    ;// must preserve ebx (file pointer)

        mov stored_ebx, ebx
        mov stored_ecx, ecx

        mov ebx, edi
        call midiin_xlate

    ;// translate pin positions

        EXTERNDEF osc_MidiIn2_pin_si:APIN_init
        EXTERNDEF osc_MidiIn2_pin_so:APIN_init
        EXTERNDEF osc_MidiIn2_pin_N:APIN_init
        EXTERNDEF osc_MidiIn2_pin_V:APIN_init
        EXTERNDEF osc_MidiIn2_pin_t:APIN_init

        mov ecx, (FILE_OSC PTR [ebx]).extra
        lea ecx, [ebx+ecx+SIZEOF FILE_OSC]
        ASSUME ecx:PTR FILE_PIN

        mov eax, osc_MidiIn2_pin_si.def_pheta
        mov edx, osc_MidiIn2_pin_so.def_pheta
        mov [ecx+(SIZEOF FILE_PIN)*0].pheta, eax
        mov [ecx+(SIZEOF FILE_PIN)*1].pheta, edx

        mov eax, osc_MidiIn2_pin_N.def_pheta
        mov edx, osc_MidiIn2_pin_V.def_pheta
        mov [ecx+(SIZEOF FILE_PIN)*2].pheta, eax
        mov [ecx+(SIZEOF FILE_PIN)*3].pheta, edx

        mov eax, osc_MidiIn2_pin_t.def_pheta
        mov [ecx+(SIZEOF FILE_PIN)*4].pheta, eax

    ;// retreive registers and exit

        mov edx, OFFSET osc_MidiIn2

        mov ebx, stored_ebx
        mov ecx, stored_ecx

        jmp got_it


    xlate_convert_midiout:

    ;// edi is file pointer
    ;// must preserve ecx
    ;// must preserve ebp
    ;// must preserve ebx (file pointer)

        mov stored_ebx, ebx
        mov stored_ecx, ecx

        mov ebx, edi
        call midiout_xlate

    ;// translate pin positions

        EXTERNDEF osc_MidiOut2_pin_si:APIN_init
        EXTERNDEF osc_MidiOut2_pin_N:APIN_init
        EXTERNDEF osc_MidiOut2_pin_V:APIN_init
        EXTERNDEF osc_MidiOut2_pin_t:APIN_init
        EXTERNDEF osc_MidiOut2_pin_so:APIN_init

        mov ecx, (FILE_OSC PTR [ebx]).extra
        lea ecx, [ebx+ecx+SIZEOF FILE_OSC]
        ASSUME ecx:PTR FILE_PIN

        mov eax, osc_MidiOut2_pin_si.def_pheta
        mov edx, osc_MidiOut2_pin_N.def_pheta
        mov [ecx+(SIZEOF FILE_PIN)*0].pheta, eax
        mov [ecx+(SIZEOF FILE_PIN)*1].pheta, edx

        mov eax, osc_MidiOut2_pin_V.def_pheta
        mov edx, osc_MidiOut2_pin_t.def_pheta
        mov [ecx+(SIZEOF FILE_PIN)*2].pheta, eax
        mov [ecx+(SIZEOF FILE_PIN)*3].pheta, edx

        mov eax, osc_MidiOut2_pin_so.def_pheta
        mov [ecx+(SIZEOF FILE_PIN)*4].pheta, eax

    ;// retreive registers and exit

        mov edx, OFFSET osc_MidiOut2

        mov ebx, stored_ebx
        mov ecx, stored_ecx

        jmp got_it



    xlate_convert_plugin:

    ;// edi is file pointer
    ;// must preserve ecx
    ;// must preserve ebp
    ;// must preserve ebx (file pointer)

        mov stored_ebx, ebx
        mov stored_ecx, ecx
        mov ebx, edi

        mov edx, 2  ;// insert 2 pins
        mov ecx, 17 ;// before what was the last pin
        call xlate_InsertPins

        EXTERNDEF osc_Plugin_pin_si:APIN_init
        EXTERNDEF osc_Plugin_pin_so:APIN_init

        mov ecx, (FILE_OSC PTR [ebx]).extra
        lea ecx, [ebx+ecx+SIZEOF FILE_OSC]
        ASSUME ecx:PTR FILE_PIN

        mov eax, osc_Plugin_pin_si.def_pheta
        mov edx, osc_Plugin_pin_so.def_pheta
        mov [ecx+(SIZEOF FILE_PIN)*17].pheta, eax
        mov [ecx+(SIZEOF FILE_PIN)*18].pheta, edx

        mov ebx, stored_ebx
        mov ecx, stored_ecx

        mov edx, OFFSET osc_Plugin

        jmp got_it



    xlate_convert_decay:

    ;// edi is file pointer
    ;// must preserve ecx
    ;// must preserve ebp
    ;// must preserve ebx (file pointer)

        mov stored_ebx, ebx
        mov stored_ecx, ecx

        ;// call abox 1 handler to do all the work
        mov ebx, edi
        call osc_decay_xlate

        ;// then we xfer default pheta
        EXTERNDEF osc_1cP_pin_r:APIN_init
        mov ecx, (FILE_OSC PTR [ebx]).extra
        lea ecx, [ebx+ecx+SIZEOF FILE_OSC]
        ASSUME ecx:PTR FILE_PIN
        mov eax, osc_1cP_pin_r.def_pheta
        mov [ecx+(SIZEOF FILE_PIN)*2].pheta, eax

        ;// set base class, restore registers, beat it

        mov edx, OFFSET osc_1cP
        mov ebx, stored_ebx
        mov ecx, stored_ecx

        jmp got_it



    xlate_convert_delta:

    ;// edi is file pointer
    ;// must preserve ecx
    ;// must preserve ebp
    ;// must preserve ebx (file pointer)

        mov stored_ebx, ebx
        mov stored_ecx, ecx

        ;// call abox 1 handler to do all the work

        mov ebx, edi
        call osc_delta_xlate

        ;// set base class, restore registers, beat it

        mov edx, OFFSET osc_Delta
        mov ebx, stored_ebx
        mov ecx, stored_ecx

        jmp got_it



    xlate_convert_oscillator:   ;// ABOX232 had to renumber

        mov edx, OFFSET osc_Oscillator  ;// that's all
        jmp got_it





xlate_ABox2File ENDP




;//
;//
;// ABOX2 FILE TRANSLATOR
;//
;////////////////////////////////////////////////////////////////////








;////////////////////////////////////////////////////////////////////
;//
;//                             task is to convert the id's into base pointers
;// ABOX1 FILE TRANSLATOR       function will return a bad count or -1 error code for
;//                             corrupted files
;// this differs from the above function in that we handle all the file convertions here
;// in the process, we may reallocate edi. the following tables are used

comment ~ /*

    section outline:

    two functions to manipulate the pin records in a file
    both are register calls

        xlate_RotatePins( pH, n )

            edi points at file header
            ebp contains a count of previous objects
            esi is end of block
            ebx = pH is pointer to file block header

            ecx = n is number to rotate

        xlate_InsertPins( pH, n, i )

            edi points at file header
            ebp contains a count of previous objects
            esi is end of block
            ebx = pH is pointer to file block header

            ecx = n is number to insert
            edx = i is index to insert in FRONT of

        xlate_ReplaceConnection(searcher, replacer)

            used for splitter removal
            this will search the file block for the connection
            then replace it with the replacer

    a data table of translateable objects

        xlate_table

    a function to do the translation

        xlate_ABox1File( pHeader, file_size )

*/ comment ~



.CODE

;////////////////////////////////////////////////////////////////////
;//
;//
;//     xlate_RotatePins( pH, n )
;//
;//     edi points at file header                   preseve
;//     ebp contains a count of previous objects
;//     esi is end of block
;//
;//     ebx = pH is pointer to file osc
;//     ecx = n is number to rotate
;//
ASSUME_AND_ALIGN
xlate_RotatePins PROC

    ASSUME ebx:PTR FILE_OSC     ;// preserved
    ;// ecx must be the number to rotate, destroyed


comment ~ /*

here's how this works:

    suffixes indicate what the variable is counting
    ie: t_dw means t is a number dwords
    E_dw is Element size in dwords (=3 for file pins)
    yyy indicated things that are to be left alone

    determine the size of the rotate in dwords

        n_dw = n*E_dw

    determine how much temp space we need

        T_dw = ( pH->numPins - n ) * E_dw

    make that space on the stack

        lea esp, [esp-T_dw*4]   now esp is the start of a temp buffer

    in memory we have:

        H  yyyyy    A   B   C   D   E   yyyyy
        pH          p0      pn  pt

        p0 = pH + pH->extra + sizeof FILE_OSC
        pn = p0 + n_dw*4    ; pn is not actually needed, see below
        pt = p0 + t_dw*4    ; pt is not actually needed, see below
                                                                example uses: rotate 2
    do three copy operations:                                   n = 2
    using the c memcpy(dst, src, siz) nomenclature              t_dw = 3*3
    and displaying the actual asm registers using rep movsd     n_dw = 2*3

    memcpy                      pin memory                  temp
    ----------------------      -----------------------     --------------------
                                p0      pn  pt              esp
                                A   B   C   D   E   yyy
    ----------------------      -----------------------     --------------------
                    ecx=edx     esi                         edi
1)  copy( temp, p0, t_dw )      A   B   C   D   E   yyy     A   B   C  yyy
                                            esi                        edi
    ----------------------      -----------------------     --------------------
                  ecx=eax       edi         esi
2)  copy( p0, pt, n_dw )        D   E   C   D   E   yyy     A   B   C   yyy
                                        edi         esi
    ----------------------      -----------------------     --------------------
                    ecx=edx             edi                 esi
3)  copy( pn, temp, t_dw )      D   E   A   B   C   yyy     A   B   C   yyy
                                                    edi                 esi
    ----------------------      -----------------------     --------------------

    so pn and pt do not need to be calculated, only po

*/ comment ~


    mov edx, [ebx].numPins  ;// edx = numPins

    push edi                ;// presere edi
    push esi                ;// presere esi

    lea eax, [ecx+ecx*2]    ;// eax = n_dw

    push ebp                ;// preserev ebp
    mov ebp, esp            ;// ebp stores the old stack pointer

    sub ecx, edx            ;// ecx = n - numPins

    lea ecx, [ecx+ecx*2]    ;// ecx = -t_dw
    lea esp, [esp+ecx*4]    ;// now esp is the temp buffer (same as sub esp, ecx*4

    mov esi, [ebx].extra    ;// get the extra count

    mov edi, esp       ;// load first destination

    lea esi, [esi+ebx+SIZEOF FILE_OSC]  ;// esi = p0

    push esi                ;// save it

    ;// copy #1

        neg ecx         ;// ecx = t_dw
        mov edx, ecx    ;// edx stores it
        rep movsd       ;// copy

    ;// copy #2

        pop edi         ;// retrieve p0
        mov ecx, eax    ;// load n_dw
        rep movsd       ;// copy

    ;// copy #3

        mov esi, esp    ;// point at temp space
        mov ecx, edx    ;// retrieve t_dw
        rep movsd       ;// copy

    ;// clean up and exit

        mov esp, ebp    ;// restore stack pointer
        pop ebp         ;// restore ebp
        pop esi
        pop edi

        ret

xlate_RotatePins ENDP
;//
;//
;//     xlate_RotatePins
;//
;////////////////////////////////////////////////////////////////////








;////////////////////////////////////////////////////////////////////
;//
;//
;//     xlate_InsertPins(pH, ind, num)
;//
;//     edi points at file header       ;// preseve
;//     ebp count of previous objects   ;// preserve
;//     esi is end of block             ;// adjust all
;//
;//     ebx = pH is pointer to file osc
;//     edx = n is number to add
;//     ecx = INDEX of the pin to insert IN FRONT OF ( BEFORE )
;//
ASSUME_AND_ALIGN
xlate_InsertPins PROC

    ASSUME ebx:PTR FILE_OSC     ;// preserved
    ;// esi is the file size and may be updated

    ;// edx must be the number of pins to add
    ;// ecx must be the INDEX of the pin to insert IN FRONT OF


comment ~ /*

    tasks:  assume that we will NEVER have to resize the file buffer (already checked)

    1)  insert the pins
        move everything after the target
        zero the newly inserted pins

    2)  adjust the numpins field of the file block header
        this may also involve adjusting all container sizes as well

    suffixes indicate what the variable is counting
    ie: t_dw means t is a number dwords
    E_dw is Element size in dwords (=3 for file pins)
    yyy indicated things that are to be left alone


task 1) insert the pins n=number to insert
                        i=index to insert in front of

    before  F   yyyyyy  H   yyy A   B   C   D   yyyyyyyy
            pF          pH      p0      pT              p1      p2

    n_b = n*E_b
    p0 = pH + pH.extra  + sizeof FILE_OSC
    pT = p0 + i*E_b
    p1 = last_byte_in_file
    p2 = p1 + n_b
    b1 = p1 - pT

    1)  backwards_copy( p2, p1, b1 )
    2)  zero( pT, i*E )

    after   F   yyyyyy  H   yyy A   B   0   0   C   D   yyyyyyyy
            pF          pH      p0      pT              p1      p2



                                example: insert 2 @ 2

                                pF          pH      p0      pT              p1      p2
                                -------------------------------------------------------
                                                                           esi      edi
                                F   yyyyyy  H   yyy A   B   C   D   yyyyyyyy
backwards_copy( p2, p1, b1 )    F   yyyyyy  H   yyy A   B   C   D   C   D   yyyyyyyy
                                                           esi      edi

                                                            esi
zero( pT, n*E )                 F   yyyyyy  H   yyy A   B   0   0   C   D   yyyyyyyy
                                                                    esi


;// optimizing:

    b1 = p1 - pT
    b1 = p1 - ( p0 + i*E_b )
    b1 = last_byte_in_file - ( p0 + i*E_b )

    esi p1 = last_byte_in_file
    edx n_b = n*E_b
    edi p2 = p1 + n_b
    ecx b1 = last_byte_in_file - ( pH + pH.extra + sizeof(FILE_OSC) + i*E_b )
                                   ebx

*/ comment ~

    push esi    ;// store pEOB
    push edi    ;// store the file header

    add [ebx].numPins, edx  ;// adjust our pin count

;// stack looks like this::
;//
;// st_edi  st_esi  ret     ret     pEOB    pOsc    ...
;// 00      04      08      0C      10      14  ...
;// pHeader pEOB                    stack of outsides

    stack_offset = 08h      ;// use stack offset to get to ebp one indexed record
                            ;// record size = 8

    ;// get the end of the file
    ;// if ebp is not zero, retrieve it from the stack
    .IF ebp
        mov esi, [esp+ebp*8+stack_offset]
    .ENDIF
    ;// now esi points at one passed end of file

    lea ecx, [ecx+ecx*2]    ;// i*3 = i_dw = number of dwords to insert
    lea edx, [edx+edx*2]    ;// n*3 = n_dw = number of dwords into pin records
    lea ecx, [ecx*4+SIZEOF FILE_OSC+ebx]    ;// i_dw*4 + sizeof(FILE_OSC) + pFileOsc
    add ecx, [ebx].extra    ;// pFileOsc + pFileOsc.extra
                            ;// ecx points at one past first value to move
    sub ecx, esi            ;// -b1 = neg amount to move
    jz @F                   ;// skip if last pin in file
    DEBUG_IF <!!SIGN?>      ;// not supposed to happen
    dec esi                 ;// scoot from one_passed_end to last_byte
    lea edi, [esi+edx*4]    ;// p2 = p1 + num_bytes
    std                     ;// backwards
    neg ecx                 ;// b1
    rep movsb       ;// use bytes to save some confusion
    cld             ;// forwards
    inc esi         ;// set destination advanced one byte
                    ;// now esi is at first dword to clear
@@: mov edi, esi    ;// set the destination
    mov ecx, edx    ;// = num_dwords to clear
    xor eax, eax    ;// clear
    rep stosd       ;// zero the memory

comment ~ /*

task 2) adjust the file

        adjust all higher level pEOB's
        adjust all extra counts for enclosing groups

    if ebp is zero, the scan is not nessesary, only adding the new size to esi

*/ comment ~

    pop edi             ;// retrive the file header
    pop esi             ;// retrieve the current pEOB

;// stack looks like this::
;//
;// ret     ret     st_addr pEOB    pOsc    ...
;// 00      04      08      0C      10      ...
;//                         stack of outsides

    stack_offset = 00h  ;// adjust for the pops

    shl edx, 2      ;// amount to add to each value
    xor eax, eax    ;// clear for testing
    add esi, edx    ;// add the amount we just added to the file

    or eax, ebp     ;// xfer depth to eax and test
    .IF !ZERO?      ;// we are an enclosed object

        ASSUME ecx:PTR GROUP_FILE

        .REPEAT

            mov ecx, [esp+eax*8+4+stack_offset] ;// get the pointer to the group
            add [esp+eax*8+stack_offset], edx   ;// add to existing pEof
            add [ecx].extra, edx                ;// add to extra count
            dec eax                             ;// dercrease the depth

        .UNTIL ZERO?

    .ENDIF


;// that's it

    ret

xlate_InsertPins ENDP
;//
;//
;//     xlate_InsertPins
;//
;////////////////////////////////////////////////////////////////////







;////////////////////////////////////////////////////////////////////
;//
;//
;//     xlate_table
;//

.DATA

    ;// if an id cannot be found in the usual base list
    ;// we scan a second list called xlate_table
    ;// if we find a match we jump to the appropriate xlate handler
    ;// otherwise we increase the error count

    ;// to determine the number of pins in the file, the table also contains
    ;// the actual number of pins to be found on the object

    XLATE_RECORD STRUCT

        id      dd  0   ;// id value to look for
        pXlate  dd  0   ;// pointer to the xlate function
        numPins dd  0   ;// actual number of pins for the new object
                        ;// used only to estimate the file size
                        ;// xlate functions must manually insert pins
                        ;// set to -1 to force the same number
        pBase   dd  0   ;// pointer to the new base class
                        ;// set to zero to have the object removed (ignored)

    XLATE_RECORD ENDS


    xlate_table LABEL XLATE_RECORD
    ;//                                                    actual
    ;//             osc ID              xlate_function      pins  base class
    ;//             ----------------    -----------------   ----  --------------
    XLATE_RECORD    {IDB_DELAY_old,     osc_delay_xlate     ,  6 , osc_Delay    }
    XLATE_RECORD    {IDB_DECAY,         osc_decay_xlate     ,  4 , osc_1cP      }   ;// ABOX232 moved to 1cP
    XLATE_RECORD    {IDB_DELTA_232,     osc_delta_xlate     ,  3 , osc_Delta    }   ;// ABOX232 added derivitive filter, needs 1 pin to store data
    XLATE_RECORD    {IDB_OSCILLATOR_232,osc_oscillator_xlate,  4 , osc_Oscillator}  ;// ABOX232 renumbered
    XLATE_RECORD    {IDB_SAMHOLD_old,   osc_sh_xlate        ,  4 , osc_SamHold  }

    XLATE_RECORD    {IDB_READOUT_BETA,  osc_readout_xlate   , -1 , osc_Readout  }
    XLATE_RECORD    {IDB_KNOB_old,      osc_Knob_xlate      ,  8 , osc_Knob     }   ;// 228: add 6 pins for presets
    XLATE_RECORD    {IDB_KNOB_BETA,     osc_MathCon_xlate   ,  8 , osc_Knob     }   ;// 228: add 6 pins for presets

    XLATE_RECORD    {IDB_BUTTON_old,    osc_Button_xlate    , -1 , osc_Button   }

    XLATE_RECORD    {IDB_SLIDER_old,    osc_Slider_xlate    ,  2 , osc_Slider   }

    XLATE_RECORD    {IDB_RANDOM,        osc_Random_xlate    ,  5 , osc_Rand     }
    XLATE_RECORD    {IDB_RANDS,         osc_Rands_xlate     ,  5 , osc_Rand     }

    XLATE_RECORD    {IDB_DIVIDER_OLD,   osc_Divider_xlate   ,  3 , osc_Divider  }

    XLATE_RECORD    {IDB_FUNC1,         osc_Func1_xlate     ,  9 , osc_Equation }

    XLATE_RECORD    {IDB_DIFFERENCE,    osc_diff_xlate      , -1 , osc_Difference}

    XLATE_RECORD    {IDB_OSCOPE,        osc_OScope_xlate    ,  7 , osc_Scope    }
    XLATE_RECORD    {IDB_SPECTRUM,      osc_Spectrum_xlate  ,  7 , osc_Scope    }

    XLATE_RECORD    {IDB_PLUGIN_old,    osc_Plugin_xlate    , 19 , osc_Plugin   }

    XLATE_RECORD    {IDB_ADSR,          xlate_adsr          , -1 , osc_ADSR     }

    XLATE_RECORD    {IDB_PROBE,         xlate_probe         , -1 , osc_Probe    }

    XLATE_RECORD    {IDB_SPLITTER2,     xlate_splitter      , -1 ,  }   ;// no base class
    XLATE_RECORD    {IDB_SPLITTER3,     xlate_splitter      , -1 ,  }   ;// no base class
    XLATE_RECORD    {IDB_SPLITTER,      xlate_splitter      , -1 ,  }   ;// no base class

    XLATE_RECORD    {IDB_PININT_old,    pinint_xlate        ,  4 , osc_PinInterface };// see function for notes on new number of pins
    XLATE_RECORD    {IDB_GROUP_old,     group_xlate         , -1 , opened_Group }

    XLATE_RECORD    {IDB_FILE_old,      file_xlate          , 10 , osc_File }   ;// add one more pin to account for adding a dword
                                                            ;// do this to make sure xlated file's size is calculated correctly

    XLATE_RECORD    {IDB_MIDIIN_old,    midiin_xlate        , 5+4  , osc_MidiIn2 }  ;// +4 means we expand file data
    XLATE_RECORD    {IDB_MIDIOUT_old,   midiout_xlate       , 5+1  , osc_MidiOut2 } ;// +1 means we expand file data

    XLATE_RECORD    {0,0}   ;// terminator


;//////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////
;////
;////                       state: ebx must be a pointer to the FILE_OSC record
;////   xlate handlers
;////                       these functions then add and adjust pins as required
;////                       or they may adjust dwUser to indicate new values
;////
;//
;//     abox1 xlate_handler
;//     function must preserve:     ebx, edi and ebp
;//     function must update:       esi, the pEOF pointer
;//     ASSUME ebx:PTR FILE_OSC     preserve, recast as required
;//     ASSUME edi:PTR FILE_HEADER  preserve
;//     ebp is the stack depth for  groups, descending index*8+esp to FILE_GROUP_STACK
.CODE


osc_delay_xlate PROC

    ;// we need to add three pins

    ;// old X T Y
    ;// new X T R h h Y

    mov edx, 3  ;// add three pins
    mov ecx, 2  ;// in front of  pin 2 (Y)
    invoke xlate_InsertPins

    ret

osc_delay_xlate ENDP

osc_sh_xlate PROC

    ;// add 1 pin
    ;//
    ;// old x s y
    ;// new x s y z

    mov edx, 1  ;// add one pin
    mov ecx, 3  ;// in front of  pin 3 (z)
    invoke xlate_InsertPins

    ret

osc_sh_xlate ENDP

osc_decay_xlate PROC

    ;// add 1 pin
    ;//
    ;// old x d y
    ;// new x f r y

    mov edx, 1  ;// add one pin
    mov ecx, 2  ;// in front of  pin 2
    invoke xlate_InsertPins

    ;// condition dw user
    ;// see IIR_DECAY_BOTH

    and DWORD PTR [ebx+SIZEOF FILE_OSC], 3  ;// dwUser, remove extra
    or DWORD PTR [ebx+SIZEOF FILE_OSC], 8   ;// dwUser, add one bit

    ret

osc_decay_xlate ENDP




;///////////////////////////////////////////////////////////////
;//
;//     abox1 xlate_handler
;//     function must preserve:     ebx, edi and ebp
;//     function must update:       esi, the pEOF pointer
;//     ASSUME ebx:PTR FILE_OSC     preserve, recast as required
;//     ASSUME edi:PTR FILE_HEADER  preserve
;//     ebp is the stack depth for groups
osc_delta_xlate PROC

        ;// ABox232: add 1 pin for new data

            ;// add 1 pin to make room for the new settings
            mov ecx, 0  ;// add before
            mov edx, 1  ;// num to insert
            invoke xlate_InsertPins
            dec [ebx].numPins                   ;// subtract 1 from numPins
            add [ebx].extra,SIZEOF FILE_PIN     ;// add 1 pin to data size

        EXTERNDEF delta_def_points:DWORD    ;// defined in ABox_Delta.asm
        EXTERNDEF delta_def_alpha:REAL4     ;// defined in ABox_Delta.asm

            mov eax, delta_def_points           ;// get default values
            mov edx, delta_def_alpha            ;// get default values
            mov DWORD PTR [ebx+(SIZEOF FILE_OSC)+4], eax    ;// set default values
            mov DWORD PTR [ebx+(SIZEOF FILE_OSC)+8], edx    ;// set default values

        ;// that's it

            ret

osc_delta_xlate ENDP



;///////////////////////////////////////////////////////////////
;//
;//     abox1 xlate_handler
;//     function must preserve:     ebx, edi and ebp
;//     function must update:       esi, the pEOF pointer
;//     ASSUME ebx:PTR FILE_OSC     preserve, recast as required
;//     ASSUME edi:PTR FILE_HEADER  preserve
;//     ebp is the stack depth for groups
osc_oscillator_xlate PROC

    ;// ABOX232 had to renumber
    ;// nothing else to do

        ret

osc_oscillator_xlate ENDP













;///////////////////////////////////////////////////////////////
;//
;//     abox1 xlate_handler
;//     function must preserve:     ebx, edi and ebp
;//     function must update:       esi, the pEOF pointer
;//     ASSUME ebx:PTR FILE_OSC     preserve, recast as required
;//     ASSUME edi:PTR FILE_HEADER  preserve
;//     ebp is the stack depth for groups
osc_readout_xlate PROC

    ;// use READOUT_METER for KNOB_UNIT_METER

        KNOB_UNIT_METER     equ 04000000h   ;// used by the readout
        READOUT_METER       equ 02h

        mov eax, DWORD PTR [ebx+SIZEOF FILE_OSC]    ;// get dwUser
        btr eax, LOG2(KNOB_UNIT_METER)
        .IF CARRY?
            or eax, READOUT_METER
            mov DWORD PTR [ebx+SIZEOF FILE_OSC] ,eax
        .ENDIF

    ;// finally, we convert the old units to new units

        mov eax, DWORD PTR [ebx+SIZEOF FILE_OSC]
        .IF eax & UNIT_OLD_TEST
            invoke unit_ConvertOld
            mov DWORD PTR [ebx+SIZEOF FILE_OSC], eax
        .ENDIF

    ;// that's it

        ret

osc_readout_xlate ENDP



;///////////////////////////////////////////////////////////////
;//
;//     abox1 xlate_handler
;//     function must preserve:     ebx, edi and ebp
;//     function must update:       esi, the pEOF pointer
;//     ASSUME ebx:PTR FILE_OSC     preserve, recast as required
;//     ASSUME edi:PTR FILE_HEADER  preserve
;//     ebp is the stack depth for groups
osc_Knob_xlate PROC

    ;// new knob stores value differently for audio taper

        KNOB_TAPER_AUDIO   equ  00000008h ;// set for audio taper;// copied from knob.inc

        mov eax, DWORD PTR [ebx+SIZEOF FILE_OSC]    ;// get dwUser
        .IF eax & KNOB_TAPER_AUDIO
            fld DWORD PTR [ebx+SIZEOF FILE_OSC+4]
            invoke math_log_lin
            fstp DWORD PTR [ebx+SIZEOF FILE_OSC+4]
        .ENDIF

    ;// check if we adjust the knob for the new midi scale
    ;// this is an ANCIENT fix !!

        KNOB_UNIT_MIDI_OLD  equ 00004000h
        KNOB_UNIT_MIDI_NEW  equ 02004000h

        and eax, KNOB_UNIT_MIDI_NEW
        .IF eax == KNOB_UNIT_MIDI_OLD
            fld DWORD PTR [ebx+SIZEOF FILE_OSC+4]
            fmul knob_new_midi_scale
            fstp DWORD PTR [ebx+SIZEOF FILE_OSC+4]
            or DWORD PTR [ebx+SIZEOF FILE_OSC], KNOB_UNIT_MIDI_NEW
        .ENDIF

    ;// convert the old units to new units

        mov eax, DWORD PTR [ebx+SIZEOF FILE_OSC]
        .IF eax & UNIT_OLD_TEST
            invoke unit_ConvertOld
            mov DWORD PTR [ebx+SIZEOF FILE_OSC], eax
        .ENDIF

    ;// convert the turns to an index

        mov eax, DWORD PTR [ebx+SIZEOF FILE_OSC]
        call xlate_knob_turns_221               ;// will call xlate_knob_turns_228
        mov DWORD PTR [ebx+SIZEOF FILE_OSC], eax

    ;// ABox228: add 6 pins for presets

        ;// ABox228:
        ;// knobs store presets with their data
        ;// this functions adds the data

            ;// add 6 pins to make room for the presets
            mov ecx, 0  ;// add before
            mov edx, 6  ;// num to insert
            invoke xlate_InsertPins
            sub [ebx].numPins, 6                    ;// subtract 6 from numPins
            add [ebx].extra, 6*(SIZEOF FILE_PIN)    ;// add 6 pins to data size
            push esi                                ;// fill data with values from table
            push edi
            KNOB_SETTINGS STRUCT
                dd  0
                dd  0
            KNOB_SETTINGS ENDS
            EXTERNDEF knob_preset_table:KNOB_SETTINGS   ;// defined in ABox_Knob.asm
            mov esi, OFFSET knob_preset_table
            lea edi, [ebx+(SIZEOF FILE_OSC)+8]  ;// point at new data
            mov ecx, (6*(SIZEOF FILE_PIN))/4
            rep movsd
            pop edi
            pop esi


    ;// fall into next function

osc_Knob_xlate ENDP
;///////////////////////////////////////////////////////////////
;//
;//     abox1 xlate_handler
;//     function must preserve:     ebx, edi and ebp
;//     function must update:       esi, the pEOF pointer
;//     ASSUME ebx:PTR FILE_OSC     preserve, recast as required
;//     ASSUME edi:PTR FILE_HEADER  preserve
;//     ebp is the stack depth for groups
osc_Slider_xlate PROC

    ;// abox1 did not have the optional input pin
    ;// we add that here
    ;// need to add a pin

    mov ecx, 1  ;// add before
    mov edx, 1  ;// num to insert
    invoke xlate_InsertPins

    ret

osc_Slider_xlate ENDP

;///////////////////////////////////////////////////////////////
;//
;//     abox1 xlate_handler
;//     function must preserve:     ebx, edi and ebp
;//     function must update:       esi, the pEOF pointer
;//     ASSUME ebx:PTR FILE_OSC     preserve, recast as required
;//     ASSUME edi:PTR FILE_HEADER  preserve
;//     ebp is the stack depth for groups
osc_MathCon_xlate PROC

    ;// all we need to do is make sure the 'add' bit is set

    ;// copied from abox_knob.inc
        KNOB_MODE_KNOB     EQU  00000000h   ;// included for clarity
        KNOB_MODE_MULT     equ  00000010h   ;// used by the math control
        KNOB_MODE_ADD      equ  00000020h

    mov eax, DWORD PTR [ebx+SIZEOF FILE_OSC]    ;// get dwUser
    .IF !(eax & KNOB_MODE_MULT)
        or eax, KNOB_MODE_ADD
        mov DWORD PTR [ebx+SIZEOF FILE_OSC], eax
    .ENDIF

    .IF eax & KNOB_TAPER_AUDIO
        fld DWORD PTR [ebx+SIZEOF FILE_OSC+4]
        invoke math_log_lin
        fstp DWORD PTR [ebx+SIZEOF FILE_OSC+4]
    .ENDIF

    ;// check if we adjust the knob for the new midi scale
    ;// this is an ANCIENT fix !!

    ;// KNOB_UNIT_MIDI_OLD  equ 00004000h
    ;// KNOB_UNIT_MIDI_NEW  equ 02004000h

        and eax, KNOB_UNIT_MIDI_NEW
        .IF eax == KNOB_UNIT_MIDI_OLD
            fld DWORD PTR [ebx+SIZEOF FILE_OSC+4]
            fmul knob_new_midi_scale
            fstp DWORD PTR [ebx+SIZEOF FILE_OSC+4]
            or DWORD PTR [ebx+SIZEOF FILE_OSC], KNOB_UNIT_MIDI_NEW
        .ENDIF

    ;// convert the old units to new units

        mov eax, DWORD PTR [ebx+SIZEOF FILE_OSC]
        .IF eax & UNIT_OLD_TEST
            invoke unit_ConvertOld
            mov DWORD PTR [ebx+SIZEOF FILE_OSC], eax
        .ENDIF

    ;// then, ancient math knobs stored the value in dwuser
    ;// we'll try to fix that here

    comment ~ /*
        KNOB_TAPER_AUDIO   equ  00000008h ;// set for audio taper
        KNOB_MODE_MULT     equ  00000010h ;// used by the math control
        KNOB_MODE_ADD      equ  00000020h
    ;// units                   0000F000h turn off auto
    turns is replaced by index in 221
        KNOB_TURNS_1       equ  00010000h
        KNOB_TURNS_4       equ  00020000h
        KNOB_TURNS_16      equ  00040000h
        KNOB_TURNS_64      equ  00080000h
        KNOB_TURNS_256     equ  00100000h
        KNOB_TURNS_1K      equ  00200000h
        KNOB_TURNS_4K      equ  00400000h
        KNOB_TURNS_16K     equ  00800000h
        KNOB_TURNS_64K     equ  01000000h
        UNIT_FIXED         equ  00010000h
                                01FFF038h

    */ comment ~

        and DWORD PTR [ebx+SIZEOF FILE_OSC], 01FFF038h

    ;// convert the turns to an index

        mov eax, DWORD PTR [ebx+SIZEOF FILE_OSC]
        call xlate_knob_turns_221                   ;// will call xlate_knob_turns_228
        mov DWORD PTR [ebx+SIZEOF FILE_OSC], eax


    osc_knob_convert::


    ;// ABox228: add 6 pins for presets

        ;// ABox228:
        ;// knobs store presets with their data
        ;// this functions adds the data

            ;// add 6 pins to make room for the presets
            mov ecx, 0  ;// add before
            mov edx, 6  ;// num to insert
            invoke xlate_InsertPins
            sub [ebx].numPins, 6                    ;// subtract 6 from numPins
            add [ebx].extra, 6*(SIZEOF FILE_PIN)    ;// add 6 pins to data size
            push esi                                ;// fill data with values from table
            push edi
            mov esi, OFFSET knob_preset_table
            lea edi, [ebx+(SIZEOF FILE_OSC)+8]  ;// point at new data
            mov ecx, (6*(SIZEOF FILE_PIN))/4
            rep movsd
            pop edi
            pop esi

    ;// that's it

        ret


osc_MathCon_xlate ENDP


;///////////////////////////////////////////////////////////////
;//
;//     abox1 xlate_handler
;//     function must preserve:     ebx, edi and ebp
;//     function must update:       esi, the pEOF pointer
;//     ASSUME ebx:PTR FILE_OSC     preserve, recast as required
;//     ASSUME edi:PTR FILE_HEADER  preserve
;//     ebp is the stack depth for groups
osc_Button_xlate PROC

    ;// all abox1 files stored the button state backwards

    ;// copied from abox_button.asm
    BUTTON_STATE        equ 00000002h   ;// set true if button is down now
    xor (DWORD PTR [ebx+SIZEOF FILE_OSC]), BUTTON_STATE

    ret

osc_Button_xlate ENDP


;///////////////////////////////////////////////////////////////
;//
;//     abox1 xlate_handler
;//     function must preserve:     ebx, edi and ebp
;//     function must update:       esi, the pEOF pointer
;//     ASSUME ebx:PTR FILE_OSC     preserve, recast as required
;//     ASSUME edi:PTR FILE_HEADER  preserve
;//     ebp is the stack depth for groups
osc_Random_xlate PROC

    ;// abox1 had a seperate random noise object
    ;// this is converted to the new rands object

    ;// old object      A   X
    ;// new object      A   X   S   r   n

    ;// insert 3,@2     A   X   S   r   n

    mov edx, 3
    mov ecx, 2
    invoke xlate_InsertPins

    ;// adjust dwUSer to duplicate the behavior of a white noise generator

    ;// copied from ABox_rand.asm
    RAND_NEXT_GATE equ  00000010h
    RAND_NEXT_POS  equ  00000004h
    mov DWORD PTR [ebx+SIZEOF FILE_OSC], RAND_NEXT_GATE + RAND_NEXT_POS

    ret

osc_Random_xlate ENDP

;///////////////////////////////////////////////////////////////
;//
;//     abox1 xlate_handler
;//     function must preserve:     ebx, edi and ebp
;//     function must update:       esi, the pEOF pointer
;//     ASSUME ebx:PTR FILE_OSC     preserve, recast as required
;//     ASSUME edi:PTR FILE_HEADER  preserve
;//     ebp is the stack depth for groups
osc_Rands_xlate PROC

    ;// abox1's rands did not have an amplitude input
    ;// we add that here

    ;// old object      S   r   n   X
    ;// new object      A   X   S   r   n

    ;// rotate  1       X   S   r   n
    mov ecx, 1
    invoke xlate_RotatePins

    ;// insert 1,@0     A   X   S   r   n
    mov edx, 1
    xor ecx, ecx
    invoke xlate_InsertPins


    ret

osc_Rands_xlate ENDP


;///////////////////////////////////////////////////////////////
;//
;//     abox1 xlate_handler
;//     function must preserve:     ebx, edi and ebp
;//     function must update:       esi, the pEOF pointer
;//     ASSUME ebx:PTR FILE_OSC     preserve, recast as required
;//     ASSUME edi:PTR FILE_HEADER  preserve
;//     ebp is the stack depth for groups
osc_Divider_xlate PROC

    ;// very early version of abox1 did not have the reset input
    ;// we add that here

    ;// have to add another pin

    ;// divider old     t   X
    ;// divider new     t   X   r
    ;//                 0   1   2

    mov edx, 1  ;// add one pin
    mov ecx, 2  ;// before pin 2
    invoke xlate_InsertPins

    ret

osc_Divider_xlate ENDP

;///////////////////////////////////////////////////////////////
;//
;//     abox1 xlate_handler
;//     function must preserve:     ebx, edi and ebp
;//     function must update:       esi, the pEOF pointer
;//     ASSUME ebx:PTR FILE_OSC     preserve, recast as required
;//     ASSUME edi:PTR FILE_HEADER  preserve
;//     ebp is the stack depth for groups
osc_Func1_xlate PROC

    ;// we are loading an old func 1 object from the days of yester year
    ;// all we can do at this point is make sure that OSC_EQU_IS_EQUATION
    ;// is NOT set, then add five pins

    ;// copied from abox_equation.asm
    OSC_EQU_IS_EQUATION equ 80000000h   ;// must be set to load correctly
    and DWORD PTR [ebx+SIZEOF FILE_OSC], NOT OSC_EQU_IS_EQUATION

    ;// func 1      X   =
    ;// equation    a   b   X   Y   Z   U   V   W   =
    ;//             0   1   2   3   4   5   6   7   8

    ;// takes two steps

        ;// 1) insert 5 pins before pin 2

        ;//     X   =
        ;//     0   1   2   3   4   5   6   7   8

        mov edx, 5      ;// add five pins
        mov ecx, 1      ;// before pin 1
        invoke xlate_InsertPins

        ;//     X   Y   Z   U   V   W   =
        ;//     0   1   2   3   4   5   6   7   8

        ;// 2) insert 2 pins before pin 0

        mov edx, 2      ;// add two pins
        xor ecx, ecx    ;// before pin 1
        invoke xlate_InsertPins

        ;//     a   b   X   Y   Z   U   V   W   =
        ;//     0   1   2   3   4   5   6   7   8

    ret

osc_Func1_xlate ENDP




osc_diff_xlate PROC

    ;// all we do is set the DIFF_LAYOUT_CON bit


    ;// copied from ABox_Difference.asm
    DIFF_LAYOUT_CON equ  00100000h

    or DWORD PTR [ebx+SIZEOF FILE_OSC], DIFF_LAYOUT_CON

    ret

osc_diff_xlate ENDP
















;///////////////////////////////////////////////////////////////
;//
;//     abox1 xlate_handler
;//     function must preserve:     ebx, edi and ebp
;//     function must update:       esi, the pEOF pointer
;//     ASSUME ebx:PTR FILE_OSC     preserve, recast as required
;//     ASSUME edi:PTR FILE_HEADER  preserve
;//     ebp is the stack depth for groups
osc_OScope_xlate PROC

        ;// this is an oscope object
        ;// we add one pin at the end

        ;// old     1   r1  o1  2   r2  o2
        ;// new     y1  r1  o1  y2  r2  o2  X

        mov edx, 1
        mov ecx, 6
        invoke xlate_InsertPins

        ;// then xlate the sweep to the new setting

        ;// copied from version 1 abox_scope.asm
        ;// old settings to xlate       ;//    old     new
        OSCOPE_RANGE_1   equ  00000001h ;//    1:1     1:1  1_0
        OSCOPE_RANGE_2   equ  00000002h ;//    4:1     4:1  1_1
        OSCOPE_RANGE_4   equ  00000004h ;//    8:1    16:1  1_2
        OSCOPE_RANGE_8   equ  00000008h ;//   16:1    16:1  1_2
        OSCOPE_RANGE_16  equ  00000010h ;//   32:1    64:1  1_3
        OSCOPE_RANGE_32  equ  00000020h ;//   64:1    64:1  1_3
        OSCOPE_RANGE_64  equ  00000040h ;//  128:1   256:1  1_4
        OSCOPE_RANGE_128 equ  00000080h ;//  256:1   256:1  1_4
        OSCOPE_RANGE_256 equ  00000100h ;//  512:1  1024:1  1_5

        ;// new settings
        SCOPE_RANGE1_1  equ 00000001h   ;// 1       4:1 samples per pixel
        SCOPE_RANGE1_2  equ 00000002h   ;// 4       16:1
        SCOPE_RANGE1_3  equ 00000003h   ;// 16      64:1
        SCOPE_RANGE1_4  equ 00000004h   ;// 64      256:1
        SCOPE_RANGE1_5  equ 00000005h   ;// 256     1024:1  new col every frame
        SCOPE_RANGE1_6  equ 00000006h   ;// 1024    4096:1  new col every 4th frame
        SCOPE_RANGE1_7  equ 00000007h   ;// external

        mov ecx, DWORD PTR [ebx+SIZEOF FILE_OSC];// .dwUser
        xor edx, edx

        ;// convert the ranges

        .IF     ecx & OSCOPE_RANGE_2
                or edx, SCOPE_RANGE1_1
        .ELSEIF ecx & (OSCOPE_RANGE_4 OR OSCOPE_RANGE_8)
                or edx, SCOPE_RANGE1_2
        .ELSEIF ecx & (OSCOPE_RANGE_16 OR OSCOPE_RANGE_32)
                or edx, SCOPE_RANGE1_3
        .ELSEIF ecx & (OSCOPE_RANGE_64 OR OSCOPE_RANGE_128)
                or edx, SCOPE_RANGE1_4
        .ELSEIF ecx & (OSCOPE_RANGE_256)
                or edx, SCOPE_RANGE1_5
        .ENDIF

        ;// disallow scroll for certain ranges

        SCOPE_SCROLL    equ 00100000h   ;// only available for RANGE1_4 through 6
        SCOPE_ON        equ 00200000h   ;// the scope is on
        SCOPE_LABELS    equ 00400000h   ;// show the labels

        .IF (ecx & SCOPE_SCROLL) && (edx >= SCOPE_RANGE1_4)
            or edx, SCOPE_SCROLL
        .ENDIF
        .IF ecx & SCOPE_ON
            or edx, SCOPE_ON
        .ENDIF
        or edx, SCOPE_LABELS                ;// default settings

        mov DWORD PTR [ebx+SIZEOF FILE_OSC], edx

        ret

osc_OScope_xlate ENDP


;///////////////////////////////////////////////////////////////
;//
;//     abox1 xlate_handler
;//     function must preserve:     ebx, edi and ebp
;//     function must update:       esi, the pEOF pointer
;//     ASSUME ebx:PTR FILE_OSC     preserve, recast as required
;//     ASSUME edi:PTR FILE_HEADER  preserve
;//     ebp is the stack depth for groups
osc_Spectrum_xlate PROC

    ;// this was a spectrum analyzer

        ;// old x   r
        ;// new x0  r0  o0  x1  r1  o1  Y

        mov edx, 5
        mov ecx, 2
        invoke xlate_InsertPins

        ;// copied from abox_scope.asm

        ;// copied fron ver 1 abox_sectrum.asm
        SPEC_RANGE_4    equ 00000002h
        SPEC_RANGE_16   equ 00000004h

        ;// copied from abox_scope.asm
        SCOPE_RANGE2_1  equ 00000010h   ;// 2:1 quarter spectrum
        SCOPE_RANGE2_2  equ 00000020h   ;// 1:1 half spectrum 1:1 pixel per bin
        SCOPE_RANGE2_3  equ 00000030h   ;// 1:2 full spectrum

        SPEC_ON         equ 00000001h
        SCOPE_SPECTRUM  equ 01000000h
        SCOPE_AVERAGE   equ 00000040h   ;// show average trace


        ;// then we xfer the settings

        mov ecx, DWORD PTR [ebx+SIZEOF FILE_OSC];//.dwUser
        mov edx, SCOPE_SPECTRUM + SCOPE_AVERAGE + SCOPE_LABELS  ;// default settings

        .IF ecx & SPEC_RANGE_16
            or edx, SCOPE_RANGE2_1
        .ELSEIF ecx & SPEC_RANGE_4
            or edx, SCOPE_RANGE2_2
        .ELSE
            or edx, SCOPE_RANGE2_3
        .ENDIF

        .IF ecx & SPEC_ON
            or edx, SCOPE_ON
        .ENDIF

        mov DWORD PTR [ebx+SIZEOF FILE_OSC], edx

        ret


osc_Spectrum_xlate ENDP


;///////////////////////////////////////////////////////////////
;//
;//     abox1 xlate_handler
;//     function must preserve:     ebx, edi and ebp
;//     function must update:       esi, the pEOF pointer
;//     ASSUME ebx:PTR FILE_OSC     preserve, recast as required
;//     ASSUME edi:PTR FILE_HEADER  preserve
;//     ebp is the stack depth for groups
osc_Plugin_xlate PROC

    ;// need to insert three new pins in the file
    ;// there might be some other things to adjust as well

    mov edx, 3
    mov ecx, 16
    invoke xlate_InsertPins

    ret

osc_Plugin_xlate ENDP


;///////////////////////////////////////////////////////////////
;//
;//     abox1 xlate_handler
;//     function must preserve:     ebx, edi and ebp
;//     function must update:       esi, the pEOF pointer
;//     ASSUME ebx:PTR FILE_OSC     preserve, recast as required
;//     ASSUME edi:PTR FILE_HEADER  preserve
;//     ebp is the stack depth for groups
FILE_ADSR STRUCT

    FILE_OSC {}

    dwUser  dd  0

    ;// the four control points, relative to top left

    P0 POINT {}   ;// saved
    P1 POINT {}   ;// saved
    P2 POINT {}   ;// saved
    P3 POINT {}   ;// saved

FILE_ADSR ENDS

xlate_adsr PROC

        ASSUME ebx:PTR FILE_ADSR

        ;// copied from ver2 abox_adsr.asm
        ADSR_START_POS   equ 00004000h  ;// if both are off then this is the old version
        ADSR_START_NEG   equ 00008000h  ;// (ver<1.37), so we set to pos
        ADSR_START_TEST  equ 0000C000h

        .IF !([ebx].dwUser & ADSR_START_TEST)
            or [ebx].dwUser, ADSR_START_POS
        .ENDIF


    ret

xlate_adsr ENDP

;//
;//
;//     xlate_adsr      adjusts and checks the data
;//
;////////////////////////////////////////////////////////////////////



;///////////////////////////////////////////////////////////////
;//
;//     abox1 xlate_handler
;//     function must preserve:     ebx, edi and ebp
;//     function must update:       esi, the pEOF pointer
;//     ASSUME ebx:PTR FILE_OSC     preserve, recast as required
;//     ASSUME edi:PTR FILE_HEADER  preserve
;//     ebp is the stack depth for groups
;//
;//     xlate_probe     all we do is clear dwUser
xlate_probe PROC

    mov DWORD PTR [ebx+SIZEOF FILE_OSC], 0
    ret


xlate_probe ENDP






















;//////////////////////////////////////////////////////
;//
;//     remove splitter
;//
;//
comment ~ /*

    this on is tricky, we have to reassign every pin on this level
    then remove the object from the file

    the task is

        1) locate a suitible connection to replace with
            either the first bus that's located
            or the input connection to the first connected output

        then replace each connection with the replacer we located in step one

    this scheme is complicated by the fact that there are
    three styles of splitters to deal with

    IDB_SPLITTER2
        00000072
        00000003 000002a2 000001da 00000000

        00510c1c 004f7984 00000000
        00510c94 004f8a60 00000000
        00510d0c 005173ec 00000000

    IDB_SPLITTER3
        00000083
        00000004 000003a5 000002b6 00000000


        0056f680 004fcd00 00000000
        0056f700 0056aa80 00000000
        0056f780 0055d400 00000000
        0056f800 004f17e0 00000000

    IDB_SPLITTER
        000000cd
        00000004 0000007f 0000005e 00000004

        00000002

        00501020 004fff00 00000000
        005010a0 005012a0 00000000
        00501120 005013a0 00000000
        005011a0 00000000 00000000


*/ comment ~



;///////////////////////////////////////////////////////////////
;//
;//     abox1 xlate_handler
;//     function must preserve:     ebx, edi and ebp
;//     function must update:       esi, the pEOF pointer
        ASSUME ebx:PTR FILE_OSC     ;// preserve, recast as required
;//     ASSUME edi:PTR FILE_HEADER  preserve
;//     ebp is the stack depth for groups
xlate_splitter PROC

        push ebp
        push ebx

        FILE_OSC_BUILD_PIN_ITERATORS ebx, ebp

        push ebx

    ;// stack looks like this
    ;// st_first    st_osc  st_ebp  ret
    ;// 00          04      08      0C

        st_first    TEXTEQU <(DWORD PTR [esp])>
        st_osc      TEXTEQU <(DWORD PTR [esp+4])>

    ;// 1) determine the replacer

    ;// 1.1)    look for a bus connection on any of the pins

        ;// test pin_0 first and seperately

        xor edx, edx                ;// clear for testing
        or edx, [ebx].pPin          ;// load and test the first pin
        jz ready_to_replace         ;// ready if not connected
        cmp edx, PIN_BUS_TEST       ;// check if bus
        jbe ready_to_replace        ;// ready to replace if bus

        ;// then scan the outputs for a bus

        jmp enter_bus_scan

    top_of_bus_scan:

        or edx, [ebx].pPin          ;// check if connected
        jz next_bus_scan            ;// skip if not connected
        cmp edx, PIN_BUS_TEST       ;// see if this is a bus
        jbe ready_to_replace        ;// we're ready to go if we're a bus

    enter_bus_scan:

        xor edx, edx                ;// clear for testing

    next_bus_scan:

        add ebx, SIZEOF FILE_PIN    ;// try next pin
        cmp ebx, ebp                ;// done yet ?
        jb top_of_bus_scan          ;// jump if not done

    done_with_bus_scan:

    ;// 1.2)    if we get here, the splitter was connected normally on all accounts
    ;//         so we do an extra step that connects our source to our first output

        mov ebx, st_first           ;// reload the first pin
        xor edx, edx                ;// clear for future tests
        mov ecx, [ebx].pSave        ;// load our input connection source

        ;// locate the first connection
        add ebx, SIZEOF FILE_PIN    ;// pin 1 ?
        or edx, [ebx].pPin          ;// load what may be a replacer
        jnz replace_first_connection;// ready to replace if not zero
        add ebx, SIZEOF FILE_PIN    ;// pin 2 ?
        or edx, [ebx].pPin          ;// load what may be a replacer
        jnz replace_first_connection;// ready to replace if not zero
        add ebx, SIZEOF FILE_PIN    ;// pin 3 ? (if there is one)
        cmp ebx, ebp                ;// check if done
        jae replace_first_connection;// ready to go if done
        or edx, [ebx].pPin          ;// load the pPin value
        ;// doesn't matter if this is zero (no outputs were connected)

    replace_first_connection:

        call replace_connections    ;// do the replace operation

        ;// then we load the replacer, which is our input source

        mov ebx, st_first           ;// reload the first pin
        mov edx, [ebx].pPin         ;// load the new replacer
        add ebx, SIZEOF FILE_PIN    ;// jump to next pin
        jmp replacing_pin_1         ;// pin_0 is already taken care of

    ready_to_replace:

    ;// 2)  replace all the connection with e replacer
    ;//
    ;// state: edx is the value we want to replace with
    ;//
    ;// task:   determine all the targets
    ;//
    ;//     if connected (pPin != 0)
    ;//         if not a bus, load the pSave value
    ;//         if edx!=ecx, do the replace

        mov ebx, st_first       ;// start at first pin

    replacing_pin_1:

        xor ecx, ecx            ;// always clear for testing

    top_of_replace_loop:

        or ecx, [ebx].pPin      ;// load and test the connection
        jz next_replace         ;// skip if zero (not connected)

        cmp ecx, PIN_BUS_TEST   ;// is the connection a bus ?
        jbe check_for_same      ;// use bus if so
        mov ecx, [ebx].pSave    ;// load the pSave value as the searcher

    check_for_same:

        cmp ecx, edx            ;// searcher == replacer ??
        je replace_is_done
        call replace_connections;// do the replace operation

    replace_is_done:

        xor ecx, ecx            ;// always clear for testing

    next_replace:

        add ebx, SIZEOF FILE_PIN;// advance to next pin
        cmp ebx, ebp            ;// done yet ??
        jb top_of_replace_loop  ;// continue if not done

    ;// that's it

        add esp, 4  ;// skip passed st_first

        st_first    TEXTEQU <>
        st_osc      TEXTEQU <>

        pop ebx
        pop ebp

        ret

;//////////////////////////////////////////////////////////////
;// local function
;//

    ASSUME_AND_ALIGN
    replace_connections:

        push ebx

    ;// stack looks like this (only called from xlate splitter)
    ;// ebx     ret     st_1st  st_osc  st_ebp  ret {pEob,posc},{pEob,pOsc},...
    ;// 00      04      08      0C      10      14  18          20          28

        .IF DWORD PTR [esp+10h] ;// are we calling in a recursive context ?

            mov ebx, [esp+18h+4]        ;// get the group header from the stack
            add ebx, SIZEOF GROUP_FILE  ;// scoot to first osc

        .ELSE                   ;// we are calling from the top, so edi is the correct file header

            FILE_HEADER_TO_FIRST_OSC edi, ebx

        .ENDIF

    top_of_osc_scan:    ;// scanning FILE_OSC's

        .IF ![ebx].pBase

            FILE_OSC_TO_NEXT_OSC ebx    ;// skip bad objects

            DEBUG_IF < ebx !> esi > ;// corrupt file ??

            jmp check_if_done

        .ENDIF

        FILE_OSC_BUILD_PIN_ITERATORS ebx, eax

        DEBUG_IF < ebx !> esi > ;// corrupt file ??

    top_of_pin_scan:    ;// scanning FILE_PIN's

        cmp ebx, eax                ;// are we done yet ?
        je check_if_done            ;// jump if so

        DEBUG_IF < ebx !> eax >     ;// not supposed to happen

        .IF [ebx].pPin == ecx       ;// is this our search pin ?
            mov [ebx].pPin, edx     ;// replace it
        .ENDIF

        add ebx, SIZEOF FILE_PIN    ;// advance to next pin
        jmp top_of_pin_scan         ;// jump to top

    check_if_done:      ;// scanning FILE_OSC's

        cmp ebx, esi                ;// done yet ?
        jb top_of_osc_scan          ;// loop if not

    ;// all_done:

        pop ebx

        retn



xlate_splitter ENDP













;///////////////////////////////////////////////////////////////
;//
;//     abox1 xlate_handler
;//     function must preserve:     ebx, edi and ebp
;//     function must update:       esi, the pEOF pointer
        ASSUME ebx:PTR FILE_OSC     ;// preserve, recast as required
;//     ASSUME edi:PTR FILE_HEADER  ;// preserve
;//     ebp is the stack depth for groups
pinint_xlate PROC

    ;// the new pin interface has 40 bytes of user data
    ;// the old version had 12
    ;//
    ;// so we insert 2 pins,
    ;// then adjust file_osc numpins and extra
    ;// then move the old sz name field to the new position

    ;// 1) add two pins

        mov edx, 2      ;// add 2 pins
        xor ecx, ecx    ;// in front of first pin
        invoke xlate_InsertPins

    ;// 2) adjust numPins and extra back to normal

        sub [ebx].numPins, 2    ;// subtract the two pins we added
        add [ebx].extra, 24     ;// add on to extra count


    ;// 3) move the name and approximate pheta for the pin
    ;//     to approximate pheta correctly, we need to know what the object size is
    ;//     the size of the object is in the header still, but only if the context is pushed
    ;//     here's what we have

        ;// old storage:    pos.x   pos.y   szName  dwStatus
        ;// new storage:    s_name  pheta   l_name

        ASSUME ebx:PTR PININT_FILE_old

    ;// or ebp, ebp                 ;// test the stack depth
        mov eax, [ebx].szName       ;// load the old short name

    comment ~ /*

        use def_pheta instead

        jz G1                       ;// was the context context pushed ?? (!=0)
        mov ecx, [ebx].dwUser       ;// load dwUser from our pin interface file
        test ecx, PININT_IO_TEST    ;// are we an io pin ?
        je G1                       ;// jump if not io pin

            ;// we ARE a pin interface inside this clesd group
            ;// so we need to approximate pheta for the GROUP's pin

            ;// here's a map
            ;//
            ;// FILE_OSC GROUP_DATA FILE_HEADER ... FILE_OSC PININT_FILE ... FILE_PIN  FILE_PIN
            ;// |<---- our enclosing group --->|...|<----- our pin ---->|   |group_pin|group_pin|...
            ;// |                                  |                        |
            ;// [esp+8]                            ebx                      esi

            mov edx, [esp+8]
            ASSUME edx:PTR GROUP_FILE   ;// preserve

            and ecx, PININT_INDEX_TEST
            jz G0
            shr ecx, 16 - 2         ;// leaves us with index * 4
            lea ecx, [ecx+ecx*2]    ;// index * 12 (size of file pin records)
        G0:
            fild [ebx].position.y   ;// y
            fild [edx].header.settings      ;// sy      y
            fmul math_Half          ;// sy/2    y
            fsub                    ;// sy/2-y

            fild [ebx].position.x   ;// x       y-sy/2
            fild [edx].header.header;// sx      x       y-sy/2
            fmul math_Half          ;// sx/2    x       y-sy/2
            fsub                    ;// sx/2-x  sy/2-y

            fpatan                  ;// pheta*pi
            fmul math_RadToNorm ;// pheta

            fstp (FILE_PIN PTR [esi+ecx]).pheta ;// store pheta in the file
        G1:

    */ comment ~

        ASSUME ebx:PTR PININT_FILE
        xor ecx, ecx
        mov [ebx].s_name, eax           ;// new s_name
        mov DWORD PTR [ebx].l_name, ecx ;// lz

        ret

pinint_xlate ENDP

comment ~ /*
    PININT_FILE STRUCT

        FILE_OSC {}

        dwUser  dd  0

        PININT_DATA {}

    PININT_FILE ENDS
*/ comment ~


comment ~ /*

    xlateing groups
    there are four xformations that can take place
    there are two sets of transforms

        OLD struct      NEW struct              XFORM list

        FILE_OSC        FILE_OSC                xform A mov dword OLD.numOsc to NEW.numOsc
        dwUser          dwUser                  xform B mov block OLD.numPin-szName[7]
        pCalc           pDevice/ingore                      to NEW.numPin-szName[7]
edi ->  numOsc          numPin                  xform C set NEW.fileSize = OLD.fileSize
esi ->  numPin          szName[0]               xform D set NEW.pEOB =
        szName[0]           [1]                             ADDR NEW.header + OLD.filesize
            [1]             [2]
            [2]             [3]
            [3]             [4]
            [4]             [5]
            [5]             [6]
            [6]             [7]
            [7]         header      will have size.X, must have Abox
        size.x          numOsc
        size.y          settings    will retain size.y
        fileSize        pEOB

*/ comment ~



;///////////////////////////////////////////////////////////////
;//
;//     abox1 xlate_handler
;//     function must preserve:     ebx, edi and ebp
;//     function must update:       esi, the pEOF pointer
;//     ASSUME ebx:PTR FILE_OSC     preserve, recast as required
;//     ASSUME edi:PTR FILE_HEADER  preserve
;//     ebp is the stack depth for groups
group_xlate PROC

    ;// this does parts A B C and D listed above
    ;// it goes quickly, pay attention

    ASSUME ebx:PTR GROUP_FILE_old

    or [ebx].dwUser, GROUP_LAYOUT_CON

    push esi        ;// must preserve
    push edi        ;// must preserve

    lea esi, [ebx].numOsc   ;// load start of xfer
    mov edi, esi    ;// set destination
    mov ecx, 10     ;// need to xfer 10 dwords (put's size.x in header)

    lodsd           ;// A.1 get OLD.numOsc, esi now points at OLD.numPin
    rep movsd       ;// B   move the block edi now points at the NEW.fileSize
    mov DWORD PTR [edi-4],'xobA'    ;// got's to store this
    stosd           ;// C store the number of oscs

    pop edi         ;// restore edi
    pop esi         ;// restore esi

    ret

group_xlate ENDP






;///////////////////////////////////////////////////////////////
;//
;//     abox1 xlate_handler
;//     function must preserve:     ebx, edi and ebp
;//     function must update:       esi, the pEOF pointer
        ASSUME ebx:PTR FILE_OSC ;//     preserve, recast as required
;//     ASSUME edi:PTR FILE_HEADER  preserve
;//     ebp is the stack depth for groups
file_xlate PROC

    ;// this one's tricky as we have to insert a dword for the file size

    ;// ABOX232 added one more pin
    ;// ABOX234 added another pin

    ;//     ebx = pH is pointer to file osc
    ;//     edx = n is number to add
    ;//     ecx = INDEX of the pin to insert IN FRONT OF ( BEFORE )

    ;//     0   1   2   3   4   5   6   7   8   9   10
    ;// old X   s   =   m   r
    ;// new Li  Ri  w   rs  m   s   P   Lo  Ro  Po  So

        mov edx, 1
        mov ecx, 1
        invoke xlate_InsertPins

    ;//     0   1   2   3   4   5   6   7   8   9   10
    ;// old X   _   s   =   m   r
    ;// new Li  Ri  w   rs  m   s   P   Lo  Ro  Po  So

        ;//mov edx, 4   ;// ABOX232 from 3 to 4
        mov edx, 5  ;// ABOX234 from 4 to 5
        mov ecx, 6
        invoke xlate_InsertPins

    ;//     0   1   2   3   4   5   6   7   8   9   10
    ;// old X   _   s   =   m   r   _   _   _   _   _
    ;// new Li  Ri  w   rs  m   s   P   Lo  Ro  Po  So

    ;// move old = to new Lo

        mov ecx, [ebx].extra
        lea ecx, [ebx+SIZEOF FILE_OSC+ecx]
        ASSUME ecx:PTR FILE_PIN

        mov eax, [ecx+(SIZEOF FILE_PIN)*3].pSave
        mov edx, [ecx+(SIZEOF FILE_PIN)*3].pPin

        mov [ecx+(SIZEOF FILE_PIN)*7].pSave, eax
        mov [ecx+(SIZEOF FILE_PIN)*7].pPin, edx

        mov eax, [ecx+(SIZEOF FILE_PIN)*3].pheta    ;// need to do this because this also does ABox2 files
        xor edx, edx
        mov [ecx+(SIZEOF FILE_PIN)*7].pheta, eax

        mov [ecx+(SIZEOF FILE_PIN)*3].pSave, edx
        mov [ecx+(SIZEOF FILE_PIN)*3].pPin, edx
        mov [ecx+(SIZEOF FILE_PIN)*3].pheta, edx

    ;// insert another pin to make up for adding a dword

        inc edx
        xor ecx, ecx
        invoke xlate_InsertPins

    ;// shift the text back 1 dword

        push edi
        push esi

    ;// osc  extra         p0 p1
    ;// |----|U-----------0|--|
    ;//                   sd
    ;// |----|US-----------0--|
    ;//       sd

        mov ecx, [ebx].extra
        lea edi, [ebx+ecx+SIZEOF FILE_OSC+4]    ;// point at p0 (first pin)
        lea esi, [edi-4]    ;// 4 bytes before
        ;//sub ecx, 4
        std                 ;// scan backwards
        rep movsb           ;// mov as bytes (ecx might not be dword aligned)
        cld                 ;// reset the direction flag

        pop esi
        pop edi

    ;// set the new size as 1 and update the pin and extra count

        mov DWORD PTR [ebx+SIZEOF FILE_OSC+4], 1
        add [ebx].extra, 12
        dec [ebx].numPins

    ;// that will do it for the pins

    comment ~ /*

    ;// old user settings

        FILE_SET_POS      equ   00000001h   ;// zero = both
        FILE_SET_NEG      equ   00000002h

        FILE_MOVE_POS     equ   00000004h   ;// zero = both
        FILE_MOVE_NEG     equ   00000008h

        FILE_REWIND_POS   equ   00000010h   ;// zero = both
        FILE_REWIND_NEG   equ   00000020h

        FILE_CIRCULAR     equ   00000040h   ;// true for wraparound
    */ comment ~

    ;// new settings ( copied from ABox_OscFile.inc )

        _FILE_MODE_DATA     EQU 00000000000000000000000000000001y
        _FILE_WRITE_POS     EQU 00000000000000000000000000001000y   ;// off for both edge
        _FILE_MOVE_POS      EQU 00000000000000000000000001000000y   ;// off for both edge
        _FILE_SEEK_POS      EQU 00000000000000000000010000000000y   ;// off for both edge
        _FILE_MOVE_REWIND   EQU 00000000000000000000001000000000y

    ;// now we do dwUser

        mov ecx, DWORD PTR [ebx+SIZEOF FILE_OSC]
        mov edx, _FILE_MODE_DATA

        mov eax, 03h
        and eax, ecx
        BITSHIFT eax, 1, _FILE_WRITE_POS
        or edx, eax

        mov eax, 0Ch
        and eax, ecx
        BITSHIFT eax, 4, _FILE_MOVE_POS
        or edx, eax

        mov eax, 30h
        and eax, ecx
        BITSHIFT eax, 10h, _FILE_SEEK_POS
        or edx, eax

        .IF ecx & 40
            or edx, _FILE_MOVE_REWIND
        .ENDIF

        mov DWORD PTR [ebx+SIZEOF FILE_OSC], edx

    ;// and that just might do it !

        ret

file_xlate ENDP



;///////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////
;////
;////   MIDI IN OUT XLATE
;////

    ;// this struct is used for both midiin and midiout

        MIDI_FILE_OSC   STRUCT

            FILE_OSC    {}
            dwUser  dd  0   ;// osc.dwUser
            channel dd  0   ;// user_filter_chan dd 0

            ;// there are more, but we don't need them

        MIDI_FILE_OSC   ENDS

    ;// xlate table to get new command index

.DATA
    midiin_xlate_command    LABEL DWORD
    ;//             idx NEW                 OLD
    dd 00B00000h ;// 0  MIDIIN_NOTE_OFF     MIDI_STATUS_1   08000000h   ;// note off
    dd 00A00000h ;// 1  MIDIIN_NOTE_ON      MIDI_STATUS_2   09000000h   ;// note on
    dd 00900000h ;// 2  MIDIIN_NOTE_PRESS   MIDI_STATUS_3   0A000000h   ;// note pressure
    dd 00700000h ;// 3  MIDIIN_CHAN_CTRLR   MIDI_STATUS_4   0B000000h   ;// controller
    dd 00400000h ;// 4  MIDIIN_CHAN_PATCH   MIDI_STATUS_5   0C000000h   ;// program change
    dd 00500000h ;// 5  MIDIIN_CHAN_PRESS   MIDI_STATUS_6   0D000000h   ;// chan pressure
    dd 00600000h ;// 6  MIDIIN_CHAN_WHEEL   MIDI_STATUS_7   0E000000h   ;// pitch wheel
    dd 00100000h ;// 7  MIDIIN_PORT_CLOCK   MIDI_STATUS_88  0F800000h   ;// clock
    ;// the port commands have to be replaced with new PORT_CLOCK mode

    midiout_xlate_command   LABEL DWORD
    ;//             idx NEW                 OLD
    dd 00B00000h ;// 0  MIDIOUT_NOTE_OFF    MIDI_STATUS_1   08000000h   ;// note off
    dd 00A00000h ;// 1  MIDIOUT_NOTE_ON     MIDI_STATUS_2   09000000h   ;// note on
    dd 00900000h ;// 2  MIDIOUT_NOTE_PRESS  MIDI_STATUS_3   0A000000h   ;// note aftertouch
    dd 00800000h ;// 3  MIDIOUT_CHAN_CTRLR_N IDI_STATUS_4   0B000000h   ;// controller
    dd 00300000h ;// 4  MIDIOUT_CHAN_PATCH_N IDI_STATUS_5   0C000000h   ;// program change
    dd 00500000h ;// 5  MIDIOUT_CHAN_PRESS  MIDI_STATUS_6   0D000000h   ;// channel aftertouch
    dd 00600000h ;// 6  MIDIOUT_CHAN_WHEEL  MIDI_STATUS_7   0E000000h   ;// pitch wheel
    dd 00100000h ;// 7  MIDIOUT_PORT_CLOCK  MIDI_STATUS_88  0F800000h   ;// clock
    ;// the port commands have to be replaced with new PORT_CLOCK mode


.CODE

;///////////////////////////////////////////////////////////////
;//
;//     abox1 xlate_handler
;//     function must preserve:     ebx, edi and ebp
;//     function must update:       esi, the pEOF pointer
    ;// ASSUME ebx:PTR FILE_OSC     ;// preserve, recast as required
        ASSUME ebx:PTR MIDI_FILE_OSC
;//     ASSUME edi:PTR FILE_HEADER  ;// preserve
;//     ebp is the stack depth for groups
midiin_xlate PROC

    ;//     ebx = pH is pointer to file osc
    ;//     edx = n is number to add
    ;//     ecx = INDEX of the pin to insert IN FRONT OF ( BEFORE )

    ;//         0   1   2   3   4   5   6   7   8
    ;// OLD:    N   V
    ;// NEW:    +10 dwords      si  so  N   V   t

        mov edx, 2+4    ;// add two pins at start + 12 dwords
        mov ecx, 0
        invoke xlate_InsertPins

    ;//         0   1   2   3   4   5   6   7   8
    ;// NOW:    + 12 dwords     si  so  N   V
    ;// NEW:    + 10 dowrds     si  so  N   V   t

        mov edx, 1  ;// add one pin
        mov ecx, 8  ;// (extra two end up overwritting filter)
        invoke xlate_InsertPins

    ;//         0   1   2   3   4   5   6   7   8
    ;// NOW:    + 12 dwords     si  so  N   V   t
    ;// NEW:    + 10 dwords     si  so  N   V   t
    ;//                         0   1   2   3   4

        sub [ebx].numPins, 4                    ;// adjust pin count
        add [ebx].extra, 4*(SIZEOF FILE_PIN)    ;// skip 4 pins (12 dwords)

    ;// build the new dwUser in edx
    ;// start with the device id

        mov edx, [ebx].dwUser   ;// old value
        mov eax, edx
        and edx, 0FFFFh         ;// device ID
        ;// MIDIIN_INPUT_DEVICE EQU 00010000h   ;// or tracker
        or edx, 00010000h       ;// all old midiins were devices

    ;// determine indixes for command and channel

        and eax, 0FF00000h  ;// remove extra bits from old mode
        shr eax, 5*4        ;// scoot bits over for indexing

        mov ecx, eax        ;// ecx will be the channel or port command
        shr eax, 4          ;// command index
        and ecx, 0Fh        ;// channel index
        sub eax, 8          ;// lowest command was 8

    ;// get the correct command and maybe channel

        or edx, midiin_xlate_command[eax*4] ;// add command to new dwUser

        .IF eax < 07h   ;// port commands don't have channels

            mov eax, 1      ;// bit to shift
            shl eax, cl     ;// shift over by channel bit
            mov [ebx].channel, eax  ;// store the channel bit

        .ENDIF

    ;// store the new dwUser

        mov [ebx].dwUser, edx

    ;// that's it

        ret

midiin_xlate ENDP




;///////////////////////////////////////////////////////////////
;//
;//     abox1 xlate_handler
;//     function must preserve:     ebx, edi and ebp
;//     function must update:       esi, the pEOF pointer
    ;// ASSUME ebx:PTR FILE_OSC ;//     preserve, recast as required

        ASSUME ebx:PTR MIDI_FILE_OSC    ;// defined above


;//     ASSUME edi:PTR FILE_HEADER  preserve
;//     ebp is the stack depth for groups
midiout_xlate PROC

    ;//     ebx = pH is pointer to file osc
    ;//     edx = n is number to add
    ;//     ecx = INDEX of the pin to insert IN FRONT OF ( BEFORE )

    ;//         0   1   2   3   4   5
    ;// OLD:    N   V   t
    ;// NEW:    +3  si  N   V   t   so

        mov edx, 2  ;// add two pins
        mov ecx, 0  ;// at very start
        invoke xlate_InsertPins

    ;//         0   1   2   3   4   5
    ;// NOW:    +3  si  N   V   t
    ;// NEW:    +3  si  N   V   t   so

        mov edx, 1  ;// add one pin
        mov ecx, 5  ;// at end
        invoke xlate_InsertPins

    ;//         0   1   2   3   4   5
    ;// NOW:    +3  si  N   V   t   so
    ;// NEW:    +3  si  N   V   t   so
    ;//             0   1   2   3   4

        dec [ebx].numPins
        add [ebx].extra, (SIZEOF FILE_PIN)

    ;// adjust dwUser

        mov edx, [ebx].dwUser
        mov eax, edx
        and edx, 0FFFFh         ;// device ID
        ;// MIDIOUT_OUTPUT_DEVICE   EQU 00020000h
        or edx, 00020000h   ;// all old midiout's were devices

        and eax, 0FF00000h      ;// remove extra bits
        shr eax, 5*4            ;// shift into index
        mov ecx, eax            ;// channel index
        shr eax, 4              ;// command index
        and ecx, 0Fh
        sub eax, 8              ;// lowest command was 8
        or edx, midiout_xlate_command[eax*4]
        mov [ebx].channel, ecx

        ;// old MIDI_TRIGGER_POS        equ  10000000h
        ;// old MIDI_TRIGGER_NEG        equ  20000000h
        ;// new MIDIOUT_TRIG_EDGE_TEST  EQU  03000000h

        mov eax, [ebx].dwUser
        and eax, 30000000h
        shr eax, 4
        or edx, eax

    ;// store the new dwUser

        mov [ebx].dwUser, edx

    ;// that's it

        ret

midiout_xlate ENDP












;//
;//
;//     xlate handlers
;//
;////////////////////////////////////////////////////////////////////








;////////////////////////////////////////////////////////////////////
;//
;//                         task is:    convert the id's into base pointers
;//                                     add gdi gutter to every position
;// ABOX1 FILE TRANSLATOR   functions will return a bad count or -1 error code for
;//                         corrupted files
;//
;//     ebx will be the return value


ASSUME_AND_ALIGN
xlate_ABox1File PROC uses ebp

    ASSUME edi:PTR FILE_HEADER  ;// preserve or reallocate as required
    ;// esi is pEOB             ;// preserve or adjust as required

;// part 1  determine the number of pins that will be added to the file
;//         initialize the bad counter in [edi].pEOB
;//         preserve edi
;//         add gdi gutter to every position
;//         remove the bus source bit from all connections

    ;// xor ebx, ebx            ;// ebx will count excess pins

    xor ebp, ebp            ;// ebp will count stack depth for groups
    mov [edi].pEOB, ebx     ;// clear the bad counter
    push edi                ;// save the file header
    FILE_HEADER_TO_FIRST_OSC edi, edi;// start at first osc
    push edi                ;// this will tell if we're before the beginnning

    ;// stack looks like this
    ;// pFirst  pFile   ebp     ret


    ;// xlate_1 loop
    ;//
    ;//   look for matches in the xlate table

    xlate_1_top_of_loop:        ;// scanning oscs in the file

        ;// adjust position

        add [edi].pos.x, GDI_GUTTER_X
        add [edi].pos.y, GDI_GUTTER_Y

        ;// scan the pins and strip out that damn bus source bit

        mov ecx, edi
        ASSUME ecx:PTR FILE_OSC
        FILE_OSC_BUILD_PIN_ITERATORS ecx, edx

    x1_pin_scan_top:    ;// removing the pin_out bit

        cmp ecx, edx                ;// done yet ?
        jae x1_pin_scan_done        ;// exit if done

        cmp [ecx].pPin, BUS_SOURCE_TEST ;// bus source ?
        ja @F                           ;// skip if not
        and [ecx].pPin, PIN_BUS_TEST    ;// turn off the bit
    @@:
        add ecx, SIZEOF FILE_PIN    ;// advance the file pin iterator
        jmp x1_pin_scan_top         ;// jump back to top

    x1_pin_scan_done:

        xor ecx, ecx                ;// clear for future testing
        mov edx, OFFSET xlate_table ;// start scanning the xlate table
        ASSUME edx:PTR XLATE_RECORD ;// edx will iterate the xlate tables

        ;// check for closed group

        mov eax, [edi].id           ;// get the id from the file

        cmp eax, IDB_CLOSED_GROUP   ;// have to descend into closed groups
        je xlate_1_descend_into_group

    ;// scan xlate_table

    xlate_1_inner_loop_top:     ;// looking for xlate records

        or ecx, [edx].id            ;// load and test the xlate.id
        jz xlate_1_next_osc         ;// if zero, file.id is not in the xlate list (so ignore)
        cmp eax, ecx                ;// check for match bewteen xlate and file id
        je xlate_1_found_match      ;// jmp if equal
        add edx, SIZEOF XLATE_RECORD;// advance the xlate iterator
        xor ecx, ecx                ;// clear for next test
        jmp xlate_1_inner_loop_top  ;// jump to top of inner loop

    xlate_1_found_match:

        xor ecx, ecx
        or ecx, [edx].numPins       ;// check for ignore value in xlate struct
        js xlate_1_next_osc         ;// jump if negative

        sub ebx, [edi].numPins      ;// subtract num file pins
        add ebx, ecx                ;// add num actual pins from xlate record
                                    ;// == difference we have to add
    xlate_1_next_osc:

        FILE_OSC_TO_NEXT_OSC edi    ;// scoot edi to next osc

    xlate_1_check_for_done:

        cmp edi, DWORD PTR [esp+ebp*8]  ;// make sure we're not before the first osc
        jb xlate_1_corrupt_file_2   ;// if below, then file is corrupted
        cmp edi, esi                ;// at end of block yet ?
        jb xlate_1_top_of_loop      ;// if not, then do the next osc
        ja xlate_1_corrupt_file_2   ;// if above, then file is corrupted
                                    ;// block is done
        dec ebp                     ;// decrease the stack counter
        js xlate_1_done             ;// jump if done

    xlate_1_ascend_outof_group:     ;// not done, have to ascend out of

        pop esi                     ;// retreive old pEOB
        pop edi                     ;// retrieve old pOsc
        ;//dec ebp                      ;// update the stack count
        ;//DEBUG_IF <SIGN?>         ;// lost track
        jmp xlate_1_next_osc        ;// jump to next osc

    xlate_1_descend_into_group:

        ;// need to call xlate_group
        push ebx            ;// preserve the pin count
        mov ebx, edi        ;// ebx needs to point at the file osc
        invoke group_xlate  ;// call the group_xlate function
        pop ebx             ;// retrieve the bad count

        push edi                    ;// store current osc
        push esi                    ;// store current pEOB
        FILE_OSC_TO_FIRST_PIN edi, esi  ;// determine the new pEOB
        add edi,SIZEOF GROUP_FILE   ;// determine the new pOsc
        inc ebp                     ;// update the stack counter
        jmp xlate_1_check_for_done  ;// jump to check for done so we detect empty groups

    xlate_1_done:   ;// now ebx has the number of pins extra pins we want

        pop eax     ;// clean up pFirst
        pop edi     ;// retrieve stored file header

        ASSUME edi:PTR FILE_HEADER








;// part 2  determine if buffer is large enough
;//         usually it will be, but we check again, just in case

    or ebx, ebx         ;// test the number of pins
    DEBUG_IF <SIGN?>    ;// removing pins ?? not s'posed to happen
    jz xlate_2_done     ;// skip if pin count matches

        ;// determine the amount of extra memory we need

        lea ebx, [ebx+ebx*2]    ;// number of dwords to add = new pins * 3
        lea ebx, [esi+ebx*4]    ;// actual end of file we need
        sub ebx, edi            ;// length of the buffer we need

        cmp ebx, MEMORY_SIZE(edi)
        jbe xlate_2_done

        ;// have to resize inplace
    IFDEF DEBUGBUILD
    .DATA
    abox1_resize_message db 'xlate_ABox1File memory resize hit !!!',0dh,0ah,0
    .CODE
    invoke OutputDebugStringA, OFFSET abox1_resize_message
    ENDIF

        lea ebx, [ebx+ebx*2]    ;// allocate half again as much
        shr ebx, 1
        and ebx, -4             ;// must dword align

        sub esi, edi    ;// need to preserve the pEob
        invoke memory_Expand, edi, ebx
        mov edi, eax
        add esi, eax    ;// restore as a new pEob

    xlate_2_done:





;// part 3
;//         look again for xlate records
;//             call if found
;//         if xlate record not found
;//             look for IDB in baseB list
;//             convert id to base class pointers
;//             if id is not found in usuall list
;//                 increase the bad count

        FILE_HEADER_TO_FIRST_OSC edi, ebx   ;// ebx will iterate oscs
        xor ebp, ebp                        ;// reset the stack counter
        xor ecx, ecx    ;// ecx has to be zero
        push ebx        ;// store for testing

        jmp xlate_3_check_if_done

    ;// xlate_3 loop
    ;//
    ;//   call all the specified xlate functions
    ;//   set the base pointers for all id's
    ;//   increase the bad count for those not found


    xlate_3_top_of_loop:    ;// scanning file oscs, looking for xlate records

        mov eax, [ebx].id           ;// load id from file

        DEBUG_IF <ecx>              ;// supposed to be zero
        mov edx, OFFSET xlate_table ;// start scanning the xlate table

    xlate_3_inner_loop_top: ;// scanning xlate table, looking for a match

        or ecx, [edx].id            ;// load and test the xlate.id
        jz xlate_3_match_with_base  ;// if zero, object is not in xlate list
        cmp eax, ecx                ;// check for match bewteen xlate and file id
        je xlate_3_found_match      ;// jmp if equal
        add edx, SIZEOF XLATE_RECORD;// advance the xlate iterator
        xor ecx, ecx                ;// clear for next test
        jmp xlate_3_inner_loop_top  ;// jump to top of inner loop

    xlate_3_found_match:    ;// found a match in the xlate table

        mov ecx, [edx].pBase        ;// load the base pointer
        mov [ebx].pBase, ecx        ;// store base pointer to the class
        call [edx].pXlate           ;// call the convert routine
        xor ecx, ecx                ;// clear for next test
        jmp xlate_3_next_osc        ;// continue on

    xlate_3_match_with_base:;// try to locate the id in baseB

        FILE_ID_TO_BASE eax, ecx, xlate_3_matched_base  ;// see if in big list

    xlate_3_match_not_found:    ;// macro didn't find a match

        cmp eax, IDB_CLOSED_GROUP   ;// closed group ?
        je xlate_3_descend_into_group;// jump to descender if closed group

    xlate_3_unknown_osc:    ;// don't know what this is!

        mov [ebx].pBase, ecx        ;// store zero in the file's base class
        inc [edi].pEOB              ;// increase the bad count
        jmp xlate_3_next_osc        ;// jump to the next item

    xlate_3_matched_base:   ;// found a match in baseB

        mov [ebx].pBase, ecx        ;// store the base class
        xor ecx, ecx                ;// always keep clear

    xlate_3_next_osc:        ;// ready for the next osc in the file

        FILE_OSC_TO_NEXT_OSC ebx    ;// next osc

    xlate_3_check_if_done:

        cmp ebx, [esp+ebp*8]        ;// check if we're before the beginning
        jb xlate_3_corrupt_file_1   ;// jump if corrupt

        cmp ebx, esi                ;// check if done
        jb xlate_3_top_of_loop      ;// jump if not done
        ja xlate_3_corrupt_file_1   ;// jump if corrupt
        dec ebp                     ;// decrease the stack counter
        js xlate_3_done

    xlate_3_ascend_outof_group:

        ;// now that all the pins are xlated, we have to set he header to abox1
        ;// otherwise the file_pin.pheta won't get loaded

        pop esi     ;// retrieve the pEOF
        pop ebx     ;// retrieve previous osc

        mov (GROUP_FILE PTR [ebx]).header.header, ABOX1_FILE_HEADER

        jmp xlate_3_next_osc

    xlate_3_descend_into_group:

        mov [ebx].pBase, OFFSET closed_Group    ;// have to store the base pointer

        push ebx    ;// store old pFileOsc
        push esi    ;// store old pEOB
        inc ebp     ;// increasethe depth count
        FILE_OSC_TO_FIRST_PIN ebx, esi  ;// set new pEOB
        add ebx, SIZEOF GROUP_FILE      ;// set new pOsc

        jmp xlate_3_check_if_done       ;// jump to done checking routine

    xlate_3_done:

    add esp, 4  ;// clean up the stack

;// part 4 clean up and split

    mov ebx, [edi].pEOB     ;// retreive bad count
    IFDEF DEBUGBUILD
    mov [edi].pEOB, 0       ;// force error if we screw this up
    ENDIF
    ret                     ;// return





;// part 5  corrupted file

xlate_3_corrupt_file_1:

    lea esp, [esp+ebp*8+4]  ;// clean up the stack (including the pFirst osc value)
    IFDEF DEBUGBUILD
    mov [edi].pEOB, 0       ;// force error if we screw this up
    ENDIF
    or ebx, -1              ;// set a bad return value
    ret                     ;// exit


xlate_1_corrupt_file_2:

    ;// there are two values on the stack we need to retrieve


    lea esp, [esp+ebp*8+4]  ;// ascend outof all groups and skip passed the first osc pointer
    pop edi                 ;// load the start of the file
    IFDEF DEBUGBUILD
    mov [edi].pEOB, 0       ;// force error if we screw this up
    ENDIF
    or ebx, -1              ;// set a bad return value
    ret                     ;// exit

xlate_ABox1File ENDP

ASSUME_AND_ALIGN
END

