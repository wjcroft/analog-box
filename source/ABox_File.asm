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
;// ABox_File.asm
;//
;// TOC:

;//     file_Load PROC              pFileName:DWORD
;//     file_RealizeBuffer PROC     pFileHeader:PTR FILE_HEADER, bSelect
;//     file_ConnectPins PROC       pFileHeader:PTR FILE_HEADER
;//     file_CheckConnections PROC  pFileHeader:PTR FILE_HEADER

;// see file_notes.txt for flow charts and proceedural overviews

OPTION CASEMAP:NONE
.586
.MODEL FLAT

        .NOLIST
        include <Abox.inc>
        include <gdi_pin.inc>
        .LIST

comment ~ /*

    see ABox.inc -- FILES for declarations of the structs

    this file holds the stuff needed to work with stored buffers
    either the copy buffer, or a file being loaded

*/ comment ~


.DATA

    ;// file_mode helps save/saveas menus
    ;// need another def bacause we don't want to get mixed up if file is bad

        file_mode   dd  0


    ;// this is the copy buffer
    ;// copy memory is identical in structure to file memory
    ;// with the assumption that all id's have already been converted

        file_pCopyBuffer dd 0   ;// pointer to copy memory
        file_bValidCopy dd 0    ;// set true if pCopy has valid info

        file_szNotOpenFile db 'Could not open the file ',0
        file_szCantReadFile db 'Could not read the file ',0
        file_szNotAboxFile db ' is not an ABox file.',0
        file_szBadRecords  db 'This file contains %i object(s) that cannot be loaded.', 0ah, 0dh,'Please check for a new version of Analog Box GPL', 0ah, 0dh,'Do you want to continue ?',0
        file_szCorrupted   db ' appears to be corrupted', 0
        file_szNoBusses    db 'There are no more busses available.', 0Ah, 0Dh,'Paste Aborted.',0

        ALIGN 4

.CODE


;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;//////
;//////
;//////
;//////     EXTERNAL FILE LOADING AND TRANSLATION
;//////

;////////////////////////////////////////////////////////////////////
;//
;//                     returns eax = allocated buffer
;//     file_Load                   = zero for abort
;//                             edx = pEOF
;//                                 = ??? for abort
;// PROLOGUE_OFF
ASSUME_AND_ALIGN
file_Load PROC uses ebx esi edi

    comment ~ /*

        file_Load filename_get_path

        always returns a new buffer, or zero for abort

        automatically xlates from abox1 to abox2

        xlates all id's to base pointers

        returned buffer is then ready to be realized

    */ comment ~

    ;// this is called from a couple spots
    ;//
    ;// tasks
    ;//
    ;// open the file       --> error if can't open
    ;// look at the header  --> error if not abox file
    ;// check the size and allocate a buffer
    ;// read the entire file to the buffer
    ;// check for ABox1
    ;//     call xlate_ABox1File
    ;// else
    ;//     call xlate_ABox2File
    ;// endif
    ;//
    ;// if translation went bad, ask user abort, continue
    ;//
    ;// return  the passed pointer for sucess
    ;//         zero for error or abort

    ;// the results on sucess will be a completly valid buffer ready to be
    ;// sent to realize buffer for open or paste commands

    ;// !!!very important!!!:
    ;//
    ;// edi is to be the file buffer
    ;// esi is to be the pEOF pointer
    ;//
    ;// in this function these MUST BE PRESERVED AND ACCURATE

        xor edi, edi    ;// have to clear this in case of problems

    ;// try to open the file

        mov edx, filename_get_path
        ASSUME edx:PTR FILENAME

        DEBUG_IF <!!edx>    ;// load path was not set !!

        DEBUG_IF <!!([edx].pName || [edx].pExt || [edx].dwLength)>  ;// what ever called this should have checked first

        add edx, FILENAME.szPath    ;// lea edx, [edx].szPath

        invoke CreateFileA, edx, GENERIC_READ, FILE_SHARE_READ,
            0, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0

        cmp eax, INVALID_HANDLE_VALUE
        mov ebx, eax                ;// ebx is the file handle
        je error_cant_open_file     ;// jump if error

    ;// read the first dword and make sure we can do even that

        xor eax, eax

        push eax        ;// return value
        mov edx, esp
        push eax        ;// bytes read
        mov ecx, esp

        mov edi, eax    ;// very important that we clear edi

        invoke ReadFile, ebx, edx, 4, ecx, eax
        or eax, eax     ;// check the read file return vaalue
        pop eax         ;// retrieve bytes read
        pop ecx         ;// retrive the header value
        jz error_cant_read_file ;// couldn't read
        cmp eax, 4      ;// check the bytes read value
        jne error_cant_read_file    ;// didn't read

    ;// make sure this is an ABox file, ecx has the header

        cmp ecx, ABOX2_FILE_HEADER
        je file_type_ok
        cmp ecx, ABOX1_FILE_HEADER
        jne error_not_abox_file

    file_type_ok:

    ;// get the size and allocate a buffer

        invoke GetFileSize, ebx, 0
        mov esi, eax            ;// esi is the actual file size
        lea eax, [eax+eax*2]    ;// adjust file size (3x)
        shr eax, 1              ;// adjust again (1.5x)
        and eax, -4             ;// have to align the size
        invoke memory_Alloc, GMEM_FIXED, eax
        mov edi, eax            ;// edi will be the buffer

    ;// rewind, read entire file, close the handle

        invoke SetFilePointer, ebx, 0,0, FILE_BEGIN

        xor eax,eax
        push eax                    ;// bytes read
        mov edx, esp
        invoke ReadFile, ebx, edi, esi, edx, eax
        or eax, eax                 ;// test result
        pop eax                     ;// retrieve bytes read
        jz error_cant_read_file     ;// didn't read
        cmp eax, esi                ;// check if we read all of it
        jne error_cant_read_file    ;// didn't read all of it

        invoke CloseHandle, ebx     ;// esi still has the file size

    ;// now the file is read to memory
    ;// edi points at the start of file buffer
    ;// before we go too far, we'll walk the file to determine the actual end
    ;// old abox files had extra stuff at the end

        ASSUME edi:PTR FILE_HEADER  ;// edi is our file buffer

        lea edx, [edi+esi]  ;// end what we read
        FILE_HEADER_TO_FIRST_OSC edi, esi   ;// esi will iterate
        mov ebx, [edi].numOsc               ;// ebx will count oscs
        mov ecx, esi                        ;// ecx will check before start
        or ebx, ebx
        .WHILE !ZERO?
            cmp esi, edx        ;// passed end
            ja error_corrupted_file
            cmp esi, ecx        ;// before begin ?
            jb error_corrupted_file
            FILE_OSC_TO_NEXT_OSC esi
            dec ebx
        .ENDW

    ;// now esi is at the actual end of the block

    ;// translate the file
    ;// xlate routine may very well replace edi and esi
    ;// so we don't store them yet

        mov eax, [edi].header   ;// load the header
        mov file_mode, 0
        cmp eax, ABOX1_FILE_HEADER
        lea ecx, xlate_ABox2File    ;// load the most common value
        jne @F
            inc file_mode
            lea ecx, xlate_ABox1File
        @@:
            call ecx            ;// call the xlation routine

IFDEF DEBUGBUILD

    invoke memory_VerifyAll

ENDIF

    ;// check the return value
    ;// -1 is corrupted file
    ;// 0 is OK
    ;// >0 is bad objects

        or ebx, ebx             ;// xfer the results and test
        js error_corrupted_file ;// file is corrupted
        mov eax, edi            ;// xfer the buffer pointer as a return value
        mov [edi].pEOB, esi     ;// set the pEOB value

        jz all_done ;// if ebx is zero, the file is aok

    ;// objects were bad
    ;// we ask what user wants to do

objects_were_bad:

        sub esp, 280            ;// make room for message string
        mov edx, esp            ;// store address
        invoke wsprintfA, edx, OFFSET file_szBadRecords, ebx
        mov edx, esp
        or app_DlgFlags, DLG_MESSAGE
        invoke MessageBoxA, 0, edx, 0, MB_YESNO + MB_TASKMODAL + MB_SETFOREGROUND
        and app_DlgFlags, NOT DLG_MESSAGE
        add esp, 280            ;// clean up the stack

        .IF eax == IDYES        ;// user wants to remove records
            mov eax, edi        ;// return sucess
        .ELSE                       ;// user wants to abort
            invoke memory_Free, edi ;// clear out or memory
            mov edi, eax            ;// memory_Free returns zero
        .ENDIF      ;// bad count was not zero

    ;// that's it, return the FILE_BUFFER pointer and the pEOF

all_done:

        ret



;///////////////////////////
;//
;// local error functions

error_cant_open_file:   ;// couldn't open the file

    mov edx, filename_get_path  ;// st_pFileName
    lea ecx, file_szNotOpenFile
    add edx, OFFSET FILENAME.szPath

    jmp show_error_and_leave

error_cant_read_file:

    invoke CloseHandle, ebx ;// close the file

    mov edx, filename_get_path  ;// st_pFileName
    lea ecx, file_szCantReadFile
    add edx, OFFSET FILENAME.szPath

    jmp show_error_and_leave

error_not_abox_file:

    invoke CloseHandle, ebx ;// close the file

    mov ecx, filename_get_path  ;// st_pFileName
    lea edx, file_szNotAboxFile
    add ecx, OFFSET FILENAME.szPath

    jmp show_error_and_leave

error_corrupted_file:

    mov ecx, filename_get_path  ;// st_pFileName
    lea edx, file_szCorrupted
    add ecx, OFFSET FILENAME.szPath

show_error_and_leave:

    ;// ecx and edx must point at error messages
    ;// ecx will be displayed first

    ;// build the string on the stack

    sub esp, 256
    mov ebx, esp
    STRCPY ebx, ecx
    STRCPY ebx, edx
    mov ebx, esp

    ;// show the message
    or app_DlgFlags, DLG_MESSAGE
    invoke MessageBoxA, 0, ebx, 0, MB_OK + MB_TASKMODAL + MB_SETFOREGROUND
    and app_DlgFlags, NOT DLG_MESSAGE
    add esp, 256

    .IF edi
        invoke memory_Free, edi
    .ENDIF

    xor eax, eax    ;// return failure
    jmp all_done

file_Load ENDP
;// PROLOGUE_ON


;//////
;//////
;//////     EXTERNAL FILE LOADING AND TRANSLATION
;//////
;//////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////











;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;//////
;//////
;//////     INTERNAL FILE LOADING
;//////
;//////


PROLOGUE_OFF
ASSUME_AND_ALIGN
file_RealizeBuffer PROC STDCALL uses esi edi pFileHeader:PTR FILE_HEADER, pIds:DWORD, bSelect:DWORD

    ;// this is called by context_Load and context paste
    ;// we assume by this point that supplied buffer is valid
    ;// so our job is to:
    ;//     iterate through the buffer and create all the objects
    ;//     we optionaly select and assign ids

        push esi
        push edi
        ASSUME ebp:PTR LIST_CONTEXT

    ;// stack looks like this
    ;// edi     esi     ret     pFileHeader pIds    bSelect
    ;// 00      04      08      0C          10      14

        st_pFileHeader  TEXTEQU <(DWORD PTR [esp+0Ch])>
        st_ids          TEXTEQU <(DWORD PTR [esp+10h])>
        st_bSelect      TEXTEQU <(DWORD PTR [esp+14h])>

        DEBUG_IF <!!(play_status & PLAY_GUI_SYNC)>  ;// supposed to be in play wait

        mov pin_connect_special_18, 0       ;// must turn this off


    ;// step ONE, flip all the pin bits,
    ;// this eliminates wrong connections due to pSave,pNow collisions

        .IF !st_ids     ;// don't do if we are calling from an undo step

            GET_FILE_HEADER esi, st_pFileHeader ;// get the passed file header
            mov edi, [esi].pEOB             ;// load the number of oscs
            FILE_HEADER_TO_FIRST_OSC esi    ;// advance to first osc

            .WHILE esi < edi

                .IF [esi].pBase ;// skip bad objects

                    FILE_OSC_BUILD_PIN_ITERATORS esi, ecx

                    .WHILE esi < ecx

                        cmp [esi].pPin, NUM_BUSSES
                        jle @F                      ;// don't flip twice, dont' flip busses
                        not [esi].pPin
                        not [esi].pSave
                    @@: add esi, SIZEOF FILE_PIN

                    .ENDW

                .ELSE   ;// skip bad objects

                    ASSUME esi:PTR FILE_OSC
                    FILE_OSC_TO_NEXT_OSC esi

                .ENDIF

            .ENDW

        .ENDIF

    ;// step TWO is to create all the objects

        GET_FILE_HEADER esi, st_pFileHeader ;// get the passed file header
        mov edi, [esi].pEOB             ;// load the stop pointer
        FILE_HEADER_TO_FIRST_OSC esi    ;// advance to first osc
        xor ecx, ecx                    ;// ecx needs to test
        ASSUME ecx:PTR OSC_BASE

        .WHILE esi < edi    ;// do until done

            or ecx, [esi].pBase     ;// get the base class
            jz got_bad_object       ;// skip bad objects

            mov eax, st_ids     ;// st_ids works as a no pins flag
            mov edx, st_pFileHeader
            invoke osc_Ctor, esi, edx, eax  ;// create the object

            mov ecx, eax
            or eax, eax
            jz got_bad_object

            ASSUME eax:PTR OSC_OBJECT

            .IF st_bSelect      ;// are we supposed to select ?

                or [eax].dwHintI, HINTI_OSC_GOT_SELECT
                clist_Insert oscS, eax,,[ebp]

            .ENDIF

        ;// are we supposed to assign an id from the supllied table ?

            xor ecx, ecx                ;// keep ecx clear for testing

            or ecx, st_ids  ;// get pointer to UNREDO_OSC_ID
            jz next_osc
            ASSUME ecx:PTR UNREDO_OSC_ID


            mov edx, [ecx].id   ;// get the id
            mov [eax].id, edx   ;// put in osc
            add st_ids, SIZEOF UNREDO_OSC_ID;// advance the id iterator
            mov ecx, eax                    ;// xfer osc to ecx

            hashd_Set unredo_id, edx, ecx   ;// tell hashd to update the value

            xor ecx, ecx
            jmp next_osc

        got_bad_object:

            .IF st_ids
                add st_ids, SIZEOF UNREDO_OSC_ID
            .ENDIF
            mov edx, unredo_pRecorder
            .IF edx
                ASSUME edx:PTR UNREDO_OSC_ID
                mov [edx].id, ecx
                mov [edx].lock_id, ecx
                add unredo_pRecorder, SIZEOF UNREDO_OSC_ID
            .ENDIF

        next_osc:

            FILE_OSC_TO_NEXT_OSC esi        ;// iterate

        .ENDW

    ;// that's it

    AllDone:

        pop edi
        pop esi

        ret 12

file_RealizeBuffer  ENDP
PROLOGUE_ON





PROLOGUE_OFF
ASSUME_AND_ALIGN
file_ConnectPins PROC STDCALL uses esi edi p_FileHeader:PTR FILE_HEADER

    DEBUG_IF <!!(play_status & PLAY_GUI_SYNC)>  ;// supposed to be in play wait

    ASSUME ebp:PTR LIST_CONTEXT

        push esi
        push edi

        GET_FILE_HEADER esi, (DWORD PTR [esp+0Ch])  ;// load the header
        xor edi, edi
        push [esi].pEOB     ;// save when to stop
        push edi            ;// dummy value

    ;// stack:
    ;// posc    pEOB    edi     esi     ret     pHeader
    ;// 00      04      08      0C      10h     14h

    st_file_header  TEXTEQU <(DWORD PTR [esp+14h])>
    st_file_end     TEXTEQU <(DWORD PTR [esp+04h])>
    st_next_osc     TEXTEQU <(DWORD PTR [esp])>

    ;// this processes the connections in a file buffer
    ;// the objects must already have been created

    ;// this new scheme for ABox2 is quite simple
    ;//
    ;// since osc_ctor has graciously xlated all the pin pointers
    ;// all we have to do is this:
    ;//
    ;//     Connect( pSave, pPin )
    ;//
    ;// naturally it's not quite that simple
    ;//
    ;// if pPin is a bus connection, we have more work to do
    ;//
    ;// so we do two scans:
    ;//
    ;//     1) scan the file and connect the bus sources
    ;//     2) scan the file and connect everything else

    ASSUME ebx:PTR APIN

;// scan 1) ///////////////////////////////////////////////////////////////////
;//         connect bus sources

        FILE_HEADER_TO_FIRST_OSC esi    ;// scoot to the first osc
        mov edx, st_file_end            ;// edx will be when to stop scanning the file
        xor ecx, ecx                    ;// always clear

    top_of_bus_osc_scan:        ;// esi is scanning FILE_OSCS

        cmp esi, edx            ;// done with file yet ?
        jae done_with_bus_scan  ;// exit if done

        .IF ![esi].pBase        ;// skip bad objects
            FILE_OSC_TO_NEXT_OSC esi
            jmp top_of_bus_osc_scan
        .ENDIF

        FILE_OSC_BUILD_PIN_ITERATORS esi, eax   ;// build the pin iterators

    top_of_bus_pin_scan:        ;// esi is scanning FILE_PINS

        cmp esi, eax            ;// done with pin block ?
        jae top_of_bus_osc_scan ;// jump to top of file scan

        or ecx, [esi].pPin      ;// connected ?
        jz iterate_bus_scan     ;// skip if not
        cmp ecx, NUM_BUSSES     ;// bus ??
        ja iterate_bus_scan_1   ;// skip if not

        mov ebx, [esi].pSave    ;// get the pin pointer
        test [ebx].dwStatus, PIN_OUTPUT ;// output pin ?
        jz iterate_bus_scan_1   ;// can't be source if not an output

    ;// create a new bus source

        mov st_next_osc, eax                ;// have to save

        or [ebx].dwStatus, ecx              ;// mask in the bus index

        ;// take care of unredo

        mov edx, unredo_pRecorder
        .IF edx
            ASSUME edx:PTR UNREDO_PIN_CONNECT
            mov [edx].num_pin, 1    ;// check this, should it be 1 ?
            mov [edx].mode, ecx     ;// mode is the bus number
            mov [edx].con.pin, ebx  ;// then storet he pin
            add unredo_pRecorder, SIZEOF UNREDO_PIN_CONNECT
        .ENDIF
        ASSUME edx:NOTHING

        ;// finish creating the bus source

        lea ecx, [ebp].bus_table[ecx*4-4]   ;// determine the bus record pointer
        DEBUG_IF < ((DWORD PTR [ecx])!!=0) && ((DWORD PTR [ecx])!!=-1) >
        mov DWORD PTR [ecx], ebx            ;// set the new source

        invoke bus_GetShape             ;// we also have to get the bus shape

        GDI_INVALIDATE_PIN HINTI_PIN_CONNECTED  ;// and make sure the object gets drawn

        mov eax, st_next_osc
        mov edx, st_file_end

    iterate_bus_scan_1:

        xor ecx, ecx            ;// clear for testing

    iterate_bus_scan:

        add esi, SIZEOF FILE_PIN    ;// iterate esi to next file pin
        jmp top_of_bus_pin_scan

    done_with_bus_scan:

;// scan 2) ///////////////////////////////////////////////////////////////////

    GET_FILE_HEADER esi, st_file_header ;// load the header
    FILE_HEADER_TO_FIRST_OSC esi        ;// scoot to the first osc

    top_of_con_osc_scan:        ;// esi is scanning FILE_OSC's

        cmp esi, st_file_end    ;// done yet ?
        jae done_con_osc_scan

        .IF ![esi].pBase        ;// skip bad objects
            FILE_OSC_TO_NEXT_OSC esi
            jmp top_of_con_osc_scan
        .ENDIF

        FILE_OSC_BUILD_PIN_ITERATORS esi, eax   ;// build the iterators
        mov st_next_osc, eax        ;// always store

    top_of_con_pin_scan:        ;// esi is scanning FILE_PINS

        cmp esi, eax            ;// done with pin's yet ?
        jae top_of_con_osc_scan ;// jump to next osc

        or edi, [esi].pPin      ;// load and test the pin's connection poitner
        jz no_pin_connect       ;// skip if not connected (edi is still zero)
        js no_pin_connect       ;// skip if still negative, connection to bad object
    ;// pin is to be connected
        mov ebx, [esi].pSave    ;// load the pin pointer
        cmp edi, NUM_BUSSES     ;// check if this is a bus
        mov eax, [ebx].dwStatus ;// load the status, we're going to need it twice
        ja check_ebx_output     ;// jump if edi is not a bus
    ;// edi is a bus
        bt eax, LOG2(PIN_OUTPUT);// see if ebx was already connected in scan#1 (bus source)
        xchg edi, ebx           ;// ebx has to be the output pin, fall through makes this work
        jc no_pin_connect_1     ;// skip if we did this in scan #1
                                ;// ebx has the bus number, edi points at the input
        mov ebx, [ebp].bus_table[ebx*4-4];// load the bus source
        or ebx, ebx             ;// check if it's connected (happens when bad objects are loaded
        jz no_pin_connect_1     ;// skip if bus source is not available
        jmp ready_to_query      ;// no need to test again

    check_ebx_output:

        bt eax, LOG2(PIN_OUTPUT);// make sure that: ebx is the output pin
        jc ready_to_query
        xchg edi, ebx

    ready_to_query:

        invoke pin_connect_query;// determine which connect function to call
        jz no_pin_connect_1     ;// jump if can't connect, this detects duplicate connections
        call ecx                ;// connect the pins

    no_pin_connect_1:

        mov eax, st_next_osc    ;// always make sure this is correct
        xor edi, edi            ;// always clear for testing

    no_pin_connect:

        add esi, SIZEOF FILE_PIN    ;// iterate to next pin in the file
        jmp top_of_con_pin_scan

    done_con_osc_scan:

    ;// that's it !!!

        or [ebp].pFlags, PFLAG_TRACE ;// make sure this block gets traced
    ;// or [ebp].gFlags, GFLAG_AUTO_UNITS   ;// tell auto units to get to work
    ;// or app_bFlags, APP_SYNC_UNITS
        invoke context_SetAutoTrace         ;// schedule a unit trace

        add esp , 8 ;// clean up iterators
        pop edi
        pop esi

        ret 4

file_ConnectPins ENDP
PROLOGUE_ON


;////////////////////////////////////////////////////////////////////
;//
;//                             called AFTER file_RealizeBuffer
;//     file_CheckConnections   and BEFORE file_ConnectPins
;//
;// we've a job ahead of us
;//
;// we assume that whatever is in the circuit now is to remain unchanged
;// the copy buffer, however may contain bad items
;//
;// these are:  1) bus destinations that don't have a bus source
;//             2) direct connections to items outside of the copy buffer
;//             3) bus sources that collide with current bus sources
;//
;// if a bus source in the copy buffer collides with a bus source in the circuit
;// we adjust the bus inside the copy buffer by adding one until it doesn't collide
;//
;// we also assume that all the items in the passed buffer are correct
;// that means that the id field in the FILE_OSC record is really the pBase pointer
;// id==0 means that we are supposed to skip the object
;//
;// the multiple scans cause the potential for alot of extra work
;// so we play a little trick on pin pheta
;//
;//     a) reset the lsb of each value
;//     b) when adjusting a value, or a top level check, set the lsb
;//     c) subsequent scans should check this bit
;//

comment ~ /*

    account for

    bus outputs that are already assigned inside the context

        adjust the source number
        adjust all matching bus inputs

    bus inputs from sources that are not inside the block
    bus inputs from sources that are not inside the context

    pin connections that do not exist inside the block

    many of these will require a scan whithin a scan
    so we need two levels of iterators

    iterators:

        start           iterator            stop
        -----------     ---------           --------
        st_pFileHeader                      st_pEOB         stack

                        reg_pOsc1       reg_pNextOsc1       2 regs
                        reg_pPin1

                        reg_pOsc2       reg_pNextOsc2       2 reg
                        reg_pPin2

            GET_FILE_OSC reg_p1, st_pFirstOsc

            .WHILE reg_p1 < st_pEOB

                FILE_OSC_BUILD_PIN_ITERATORS reg_p1, reg_pNextOsc

                .WHILE reg_p1 != reg_pNextOsc1

                    ..... do work

                    add reg_p1, SIZEOF FILE_PIN

                .ENDW

                mov reg_p1, reg_pNextOsc1

            .ENDW


        so: it will take four regs to double iterate the circuit

            esi,edi, ebx,edx that leaves eax to test with

        not enough for a 'search for this, replace with that' operation

            so we'll have to use ebp from time to time


*/ comment ~



PROLOGUE_OFF
ASSUME_AND_ALIGN
file_CheckConnections PROC STDCALL pFileHeader:PTR FILE_HEADER

    ASSUME ebp:PTR LIST_CONTEXT

    push edi
    push esi
    push ebx

    ;// stack
    ;// ebx esi edi ret pFileHeader
    ;// 00  04  08  0C  10

    st_pFileHeader TEXTEQU <(DWORD PTR [esp+10h])>

    ;// setup the file level iterators and the first scan

        GET_FILE_HEADER edi, st_pFileHeader
        mov esi, [edi].pEOB
        FILE_HEADER_TO_FIRST_OSC edi, edi

        push edi
        push esi

    ;// stack
    ;// pEOB    pFirstOsc   ebx esi edi ret pFileHeader
    ;// 00      04          08  0C  10  14  18

    st_pEOB        TEXTEQU <(DWORD PTR [esp])>
    st_pFirstOsc   TEXTEQU <(DWORD PTR [esp+04h])>
    st_pFileHeader TEXTEQU <(DWORD PTR [esp+18h])>

    ;// 1) prepare pheta

        xor eax, eax        ;// eax must equal zero
        mov edx, -2         ;// masker for lsb

    prepare_osc_top:            ;// top of scan osc loop, outter loop

        cmp edi, esi                ;// check if pCurrentOsc is beyond the end
        jae prepare_osc_done        ;// exit if so

        cmp [edi].pBase, eax        ;// check for bad object
        je prepare_osc_bad_osc      ;// jump to next osc if this one is bad

        FILE_OSC_BUILD_PIN_ITERATORS edi, ebx   ;// ebx is now the end of the osc block
                                                ;// edi is the first pin
    prepare_pin_top:        ;// top of file pin scan

        cmp edi, ebx            ;// check if at end of pins
        jae prepare_osc_top     ;// jump if at the end of his pin block

        cmp [edi].pPin, eax     ;// check if connected
        jz prepare_pin_next     ;// jump if pin is not connected

        and [edi].pheta, edx    ;// reset the pheta bit

    prepare_pin_next:

        add edi, SIZEOF FILE_PIN
        jmp prepare_pin_top

    prepare_osc_bad_osc:    ;// jump to next osc if it was bad

        ASSUME edi:PTR FILE_OSC
        FILE_OSC_TO_NEXT_OSC edi,ecx;// need to get the next osc
        jmp prepare_osc_top

    prepare_osc_done:       ;// we are done scanning the file



    ;// 2)  scan all the connections

        GET_FILE_OSC edi, st_pFirstOsc  ;// rewind back to start

        ;// eax still equals zero

    scan_osc_top:       ;// top of scan osc loop, outter loop
                        ;// esi must be pEOb
        cmp edi, esi            ;// check if pCurrentOsc is beyond the end
        jae scan_osc_done       ;// exit if so

        cmp [edi].pBase, eax    ;// check for bad object
        je scan_osc_bad_osc     ;// jump to next osc if it was bad

        FILE_OSC_BUILD_PIN_ITERATORS edi, esi   ;// esi is now the end of the osc block
                                                ;// edi is the first pin
    scan_pin_top:       ;// top of file pin scan, outter loop
                        ;// determine which of the four branches we take
        cmp edi, esi            ;// check if at end of pins
        jae scan_osc_next       ;// jump if at the end of his pin block

        or eax, [edi].pPin      ;// load and test the pin
        jz scan_pin_next        ;// jump if pin is not connected

        bts [edi].pheta, 0      ;// test and set the pheta bit
        jc scan_pin_next        ;// skip the brancher if we've already hit this

        cmp eax, NUM_BUSSES     ;// check for a bus connection
        jae scan_normal_conn    ;// jump if normal connection

        GET_PIN [edi].pSave, ebx;// get the pin

        test [ebx].dwStatus, PIN_OUTPUT ;// output pin ?
        jnz scan_bus_source     ;// jmp to source scanner

        jmp scan_bus_dest       ;// must be a bus destination

    scan_pin_next:      ;// all four branches endup here

        xor eax, eax        ;// clear for testing
        add edi, SIZEOF FILE_PIN
        jmp scan_pin_top

    scan_osc_next:      ;// edi is already at the next osc

        xor eax, eax        ;// eax needs to be cleared
        mov esi, st_pEOB    ;// esi must be the end of the file block
        jmp scan_osc_top

    scan_osc_bad_osc:   ;// this osc is bad

        ASSUME edi:PTR FILE_OSC
        FILE_OSC_TO_NEXT_OSC edi, ecx
        jmp scan_osc_top



    scan_osc_done:      ;// we are done scanning the file

        add esp, 8  ;// clean up the iterators
        pop ebx
        pop esi
        pop edi
        retn 4

;// ---------------------------------------------------------


ASSUME_AND_ALIGN
scan_normal_conn:   ;// edi points at a normal connection

    ASSUME ebp:PTR LIST_CONTEXT ;// preserve
    ASSUME edi:PTR FILE_PIN     ;// preserve
    ;// esi points at the last pin in this block    ;// preserve
    ;// eax enters as [edi].pPin

    ;// task: verify that all connections exist INSDIE the file block
    ;//     scan file from start to stop, skip self (edi)
    ;//         search for [iter].pSave == [edi].pPin
    ;//         if found, then we're ok
    ;//         if not found, zero the connection
    ;//
    ;// while we search, we check pPin and set the pheta bit for all
    ;//                 then we keep track if we found the source

        GET_FILE_OSC ebx, st_pFirstOsc
        xor edx, edx        ;// edx will be a found_the_source flag

    scan_normal_osc_top:    ;// scan the oscs in the file

        cmp ebx, st_pEOB            ;// done scanning oscs ?
        jae scan_normal_done        ;// jmp to replace if yes (didn't find the source)

        cmp [ebx].pBase, 0          ;// is this a bad object ?
        je scan_normal_bad_osc      ;// jump if bad osc

        FILE_OSC_BUILD_PIN_ITERATORS ebx, ecx   ;// ecx is end of pin

    scan_normal_pin_top:    ;// scan the pins in the osc

        cmp ebx, ecx                ;// done scanning pins ?
        jae scan_normal_osc_top     ;// jump to top if yes, ebx already equals next osc

        cmp ebx, edi                ;// is this us ??
        je scan_normal_pin_next     ;// skip ourselves

    normal_conn_check_save: ;// check if pSave = us

        cmp eax, [ebx].pSave        ;// cmp pSave w/pPin
        jne normal_conn_check_pin   ;// jump if not a match

    normal_conn_found_save: ;// found a match in the save side

        or [ebx].pheta, 1           ;// set the already checked bit
        inc edx                     ;// increase the found source flag

    normal_conn_check_pin:  ;// check if the pin matches

        cmp eax, [ebx].pPin         ;// cmp with pin
        jne scan_normal_pin_next

    normal_conn_found_pin:  ;// pPin matches us

        or [ebx].pheta, 1           ;// set the already checked bit

    scan_normal_pin_next:

        add ebx, SIZEOF FILE_PIN    ;// next pin
        jmp scan_normal_pin_top     ;// jump to top

    scan_normal_bad_osc:    ;// this osc is bad

        ASSUME ebx:PTR FILE_OSC
        push edx                    ;// must preserve edx
        FILE_OSC_TO_NEXT_OSC ebx, edx   ;// zip to next osc
        pop edx                     ;// retrieve edx
        jmp scan_normal_osc_top     ;// jump to top ofthis loop

    scan_normal_done:

        or edx, edx         ;// check if we found the source
        jnz scan_pin_next   ;// exit back to outside scan

    scan_normal_replace:    ;// if we hit this, the connection was not found

        xor ecx, ecx                ;// clear the value
        jmp replace_all_connections ;// defined below



ASSUME_AND_ALIGN
scan_bus_source:    ;// edi points at a bus source

    ASSUME ebp:PTR LIST_CONTEXT
    ASSUME edi:PTR FILE_PIN
    ;// esi points at the last pin in this block    ;// preserve
    ;// eax enters as [edi].pPin    (bus index)
    ;// ebx enters as the pin itself


    ;// check if bus exists in the context
    ;// if yes
    ;//
    ;//     locate another bus to use
    ;//         find empty slot in bus table
    ;//         check that bus is not used in circuit
    ;//     reserve the bus for our use
    ;//     replace all file internal bus connections with that bus
    ;//     if a bus was not found
    ;//     replace all internal connections with direct connections
    ;//

    ;// check if bus is already assigned in the context


        cmp BUS_TABLE(eax), 0       ;// bus in use ??
        je scan_pin_next            ;// good to go

    locate_another_bus:

        lea ecx, [eax+1]            ;// ecx will index the busses

    locate_bus_scan_top:    ;// looking for busses with zero

        cmp ecx, NUM_BUSSES         ;// check for wrap around
        jbe LB                      ;// skip if no wrap
        sub ecx, NUM_BUSSES         ;// subtract numbuses (=1)
    LB: cmp BUS_TABLE(ecx), 0       ;// bus used ?
        jz double_check_file_bus    ;// jump to double_checker if not used

    locate_bus_scan_next:   ;// iterate to the next bus

        inc ecx                     ;// next index
        cmp ecx, eax                ;// done yet ?
        jne locate_bus_scan_top     ;// loop if not done

    ;// if we hit this, we have replace all the connections with a direct connection
    replace_with_direct_connection:

        mov ecx, [edi].pSave        ;// load the direct saver
        jmp replace_all_connections ;// jump to the replacer

    ;// task, make sure our intended bus index is not already scheduled for use
    ;// ecx is the intended index
    double_check_file_bus:

        GET_FILE_OSC ebx, st_pFirstOsc

    bus_scan_osc_top:       ;// scan through all the oscs

        cmp ebx, st_pEOB            ;// done with file
        jae replace_bus_file        ;// exit to replacer, bus is not used

        cmp [ebx].pBase, 0          ;// check for bad osc
        je bus_scan_bad_osc         ;// jump if osc is bad

        FILE_OSC_BUILD_PIN_ITERATORS ebx, edx   ;// build the pin scanner

    bus_scan_pin_top:       ;// scan pins of this block

        cmp ebx, edx                ;// done scanning pins ?
        jae bus_scan_osc_top        ;// jump to osc rop if so

        cmp ebx, edi                ;// are we pointing at ourselves ?
        je bus_scan_pin_next        ;// skip ourselves

        cmp [ebx].pPin, ecx         ;// is this a match for the bus we want to use ?
        jne bus_scan_pin_next       ;// jump if it's not

    cant_use_this_bus:      ;// can't use this bus

        mov ebx, [edi].pSave        ;// reload the pin
        jmp locate_bus_scan_next    ;// jump back to bus locater

    bus_scan_pin_next:      ;// get the next file pin

        add ebx, SIZEOF FILE_PIN    ;// next pin
        jmp bus_scan_pin_top        ;// jump to top of loop

    bus_scan_bad_osc:       ;// this osc is bad

        ASSUME ebx:PTR FILE_OSC
        FILE_OSC_TO_NEXT_OSC ebx, edx;// next osc
        jmp bus_scan_osc_top        ;// jump back to top of loop

    replace_bus_file:       ;// replace bus connections with a new bus

        ;// ecx is the bus index we want to use
        ;// eax is the bus we want to replace

        dec BUS_TABLE(ecx)          ;// reserve this bus entry
        jmp replace_all_connections



ASSUME_AND_ALIGN
scan_bus_dest:      ;// edi points at a bus destination

    ASSUME ebp:PTR LIST_CONTEXT
    ASSUME edi:PTR FILE_PIN
    ;// esi points at the last pin in this block    ;// preserve
    ;// eax enters as [edi].pPin (bus index)
    ;// ebx enters as the pin itself

    ;// check if bus exists in the context
    ;// if yes, we're ok
    ;// check if the source exists inside the file
    ;// if no, we have to zero all the busses that use this
    ;// check all other connections as we go
    ;// this very much like scan_normal_con
    ;// except we have check all the pin.dwStatus for output connection

    ;// we can assume that once we find the output, it will be caught later
    ;// other wise we shouldn't even be here

    ;// check if bus is already assigned in the context

        cmp BUS_TABLE(eax), 0       ;// bus in use ??
        jne scan_pin_next           ;// good to go

    ;// task, locate the source in the file
    ;// ecx is the intended index

        GET_FILE_OSC ebx, st_pFirstOsc

    source_scan_osc_top:        ;// scan through all the oscs

        cmp ebx, st_pEOB            ;// done with file
        jae replace_source_file     ;// exit to replacer, bus is not used

        cmp [ebx].pBase, 0          ;// check for bad osc
        je source_scan_bad_osc      ;// jump if osc is bad

        FILE_OSC_BUILD_PIN_ITERATORS ebx, edx   ;// build the pin scanner

    source_scan_pin_top:        ;// scan pins of this block

        cmp ebx, edx                ;// done scanning pins ?
        jae source_scan_osc_top     ;// jump to osc rop if so

        cmp ebx, edi                ;// are we pointing at ourselves ?
        je source_scan_pin_next     ;// skip ourselves

        cmp [ebx].pPin, eax         ;// is this a match for the bus we want to use ?
        jne source_scan_pin_next    ;// jump if it's not

        GET_PIN [ebx].pSave, ecx    ;// get the pin
        test [ecx].dwStatus, PIN_OUTPUT ;// see if it's the output
        jnz scan_pin_next           ;// exit if we found the output pin

    source_scan_pin_next:       ;// get the next file pin

        add ebx, SIZEOF FILE_PIN    ;// next pin
        jmp source_scan_pin_top     ;// jump to top of loop

    source_scan_bad_osc:        ;// this osc is bad

        ASSUME ebx:PTR FILE_OSC
        FILE_OSC_TO_NEXT_OSC ebx, edx   ;// next osc
        jmp source_scan_osc_top         ;// jump back to top of loop

    replace_source_file:        ;// replace all connections with zero

        ;// ecx is the bus index we want to use
        ;// eax is the bus we want to replace

        xor ecx, ecx
        jmp replace_all_connections


ASSUME_AND_ALIGN
replace_all_connections:

        ;// eax is the pPin we want to replace
        ;// ecx is the pPin we want to replace with

        GET_FILE_OSC ebx, st_pFirstOsc

    replace_all_osc_top:        ;// scan all oscs in file

        cmp ebx, st_pEOB            ;// done scanning file ?
        jae scan_pin_next           ;// jump back to main scan if so

        cmp [ebx].pBase, 0          ;// check for bad osc
        je replace_all_bad_osc      ;// jump if osc is bad

        FILE_OSC_BUILD_PIN_ITERATORS ebx, edx

    replace_all_pin_top:        ;// scan all pins in the osc

        cmp ebx, edx                ;// done scanning pins?
        jae replace_all_osc_top     ;// jump to osc top if so

        cmp [ebx].pPin, eax         ;// is this what we want to replace ?
        jne replace_all_pin_next    ;// jump if not

        mov [ebx].pPin, ecx     ;// replace
        or [ebx].pheta, 1       ;// set the already done bit

    replace_all_pin_next:

        add ebx, SIZEOF FILE_PIN
        jmp replace_all_pin_top

    replace_all_bad_osc:        ;// this osc is bad

        ASSUME ebx:PTR FILE_OSC
        FILE_OSC_TO_NEXT_OSC ebx, edx   ;// get the next osc
        jmp replace_all_osc_top         ;// jump to top of this loop


file_CheckConnections ENDP
PROLOGUE_ON

;//////
;//////
;//////     INTERNAL FILE LOADING
;//////
;//////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////





ASSUME_AND_ALIGN





END
