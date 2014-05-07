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
;//     memory_buffer.asm
;//
;// gmap_Initialize
;// gmap_Destroy

;// gmap_create_new_mapping_and_view
;// gmap_duplicate_mapping_and_view
;// gmap_attach
;// gmap_detach
;// gmap_change_size
;// gmap_reattach

;// gmap_Open
;// gmap_Close
;// gmap_SetLength
;// gmap_CheckState

OPTION CASEMAP:NONE

.586
.MODEL FLAT

USE_THIS_FILE equ 1

IFDEF USE_THIS_FILE

    .NOLIST
    INCLUDE <Abox.inc>
    INCLUDE <ABox_OscFile.inc>
    .LIST


comment ~ /*

    Global Mapping synchronizes opening closing and resizing
    of the shared global file blocks

    gmap_Initialize system level function opens or creates the table
    gmap_Destroy    system level closes the table

    gmap_Open       attaches an object to an id or file name
    gmap_Close      detaches object from id or file name
    gmap_SetSize    tells gmap to resize the virtual file
    gmap_CheckState tells gmap to verify object and directory entry


to open and close:

    file objects request gmap to attach and detach their ID's
    gmap will set file.pView and file.hMap accordingly
    if object's size differse from existing size, existing size is used

resizing the global buffers:

    when user enters a new size, request gmap to change the size

responding to change size:

    before accessing data, file objects must verify that
    the actual size of the object matches their internal actual size
    use gmap_GetObjectData to do this

*/ comment ~

.DATA

    ;// somewhat arbitrary max size

        MAX_GMAP_MEMORY_LENGTH          EQU 40000h  ;// in samples

    ;// global mapping table entry

        GLOBAL_MAPPING_TABLE    STRUCT

            id db FILE_MAX_ID_LENGTH dup (?)    ;// id (not nessesarily null terminated)
                                    ;// must be first record
            hMap            dd  0   ;// hFileMapping (used to duplicate handle)
            pid             dd  0   ;// process identifier last adjusted (used for duplicate handle)

            instance        dd  0   ;// count of attached file objects

            file_size       dd  0   ;// apparent size of mapped file
            actual_size     dd  0   ;// actual size, prevents reallocation ??

        GLOBAL_MAPPING_TABLE    ENDS

    ;// global mapping structure

        NUM_GLOBAL_MAPPINGS EQU 128 ;// should be plenty ?

        GLOBAL_MAPPING_STRUCT STRUCT

        ;// header

            num_records     dd  0   ;// versioning helper states number of records

        ;// table

            table   GLOBAL_MAPPING_TABLE NUM_GLOBAL_MAPPINGS DUP ({})

        GLOBAL_MAPPING_STRUCT ENDS


    ;// synchronization, handles and pointers

        gmap_pid        dd  0   ;// our process identifier
        gmap_hMutex     dd  0   ;// our named synchronization object
        gmap_hMap       dd  0   ;// handle of FileMappingObject
        gmap_pView      dd  0   ;// ptr to memory of the view

        sz_ABoxGlobalFileMap    db 'abox_global_file_map',0
        sz_ABoxGlobalFileMutex  db 'abox_global_file_mutex',0
        ALIGN 4


.CODE

ASSUME_AND_ALIGN
gmap_Initialize PROC USES esi ebx

        DEBUG_IF <gmap_hMap>    ;// already opened !!
        DEBUG_IF <gmap_pView>   ;// already mapped !!
        DEBUG_IF <gmap_hMutex>  ;// already mutexed !!

    ;// set our process id

        invoke GetCurrentProcessId
        mov gmap_pid, eax

    ;// get our mutex

        invoke OpenMutexA, MUTEX_ALL_ACCESS, 0, OFFSET sz_ABoxGlobalFileMutex
        .IF !eax        ;// time to create

            invoke CreateMutexA, 0,0,OFFSET sz_ABoxGlobalFileMutex
            DEBUG_IF <!!eax>, GET_ERROR ;// couldn't create mutex !!

        .ENDIF
        mov gmap_hMutex, eax

    ;// try to open existing object first
    ;// if not open then create it

        invoke OpenFileMappingA, FILE_MAP_ALL_ACCESS,0,OFFSET sz_ABoxGlobalFileMap
        test eax, eax
        jz create_a_new_map

    ;// we opened the existing object

        mov gmap_hMap, eax

    ;// make a map of the whole thing

        invoke MapViewOfFile, eax, FILE_MAP_ALL_ACCESS,0,0,0
        mov gmap_pView, eax

        DEBUG_IF <!!eax>,GET_ERROR  ;// couldn't map;// disable ?

        mov ebx, eax
        jmp add_instance

    create_a_new_map:

        invoke CreateFileMappingA, 0FFFFFFFFh, 0, PAGE_READWRITE,0,SIZEOF GLOBAL_MAPPING_STRUCT,OFFSET sz_ABoxGlobalFileMap
        DEBUG_IF <!!eax>, GET_ERROR ;// couldn't create
        mov gmap_hMap, eax

        invoke MapViewOfFile, eax, FILE_MAP_ALL_ACCESS,0,0,0
        DEBUG_IF <!!eax>, GET_ERROR ;// couldn't map
        mov gmap_pView, eax
        mov ebx, eax
        ASSUME ebx:PTR GLOBAL_MAPPING_STRUCT

        ;// clear the data
        mov edi, eax
        mov ecx, (SIZEOF GLOBAL_MAPPING_STRUCT) / 4
        xor eax, eax
        rep stosd

        ;// fill in the header
        mov [ebx].num_records, NUM_GLOBAL_MAPPINGS

    ;// that should do it
    add_instance:

        xor eax, eax    ;// return sucess


        ret

gmap_Initialize ENDP



ASSUME_AND_ALIGN
gmap_Destroy PROC

        DEBUG_IF <!!gmap_hMap>      ;// not opened !!

        DEBUG_IF <!!gmap_pView>     ;// not mapped !!

        DEBUG_IF <!!gmap_pid>       ;// not have a proces !!

        DEBUG_IF <!!gmap_hMutex>    ;// not mutexed !!

    ;// release our handles

        invoke CloseHandle, gmap_hMutex
        DEBUG_IF<!!eax>, GET_ERROR
        mov gmap_hMutex, 0
        invoke UnmapViewOfFile, gmap_pView
        DEBUG_IF<!!eax>, GET_ERROR
        mov gmap_pView, 0
        invoke CloseHandle, gmap_hMap
        DEBUG_IF<!!eax>, GET_ERROR
        mov gmap_hMap, 0

    ;// that should do it

        ret

gmap_Destroy ENDP



comment ~ /*

    this is somewhat complicated
    we use four functions to inferface from file_ to gmap_

    assume that windows will correctly realease and maintain mapped memory

    gmap_Open --> attach

        look for matching name
        if found
            if hProcess != 0
                duplicate handle using global hProcess and hMap
            else if process == 0
                create new mapping using sizes stated by global
                set global hMap and process
            xfer global actual size to osc actual size
        if not found
            create a new map with osc actual size
            set global handle and process
            set global actual size
        increase instance
        map the file and stor pointer in buffer

    gmap_Close --> gmap_detach

        unmap osc's mapping
        if global hMap == osc hMap
            zero global hProcess and hMap
        close osc view and handle
        decrease global instance
        if zero
            completely erase table entry

    gmap_SetSize --> gmap_change_size

        Close mapping using local osc settings
        Create new mapping using actual size in osc
        replace global hMap, process, actualsize, and size
        map the file

    gmap_CheckState --> gmap_reattach

        if osc hMap == global hMap
            zero global hProcess and hMap
        close map using local osc settings
        if hprocess exists
            duplicate handle using global hMap,and process
        else if process doesn't exist
            the create new mapping using size specified in table
            set global hProcess and hMap
        get sizes from global
        map the file

*/ comment ~


ASSUME_AND_ALIGN
gmap_attach PROC

    ;// destroys ebx, edi

    ;// returns eax non-zero for sucess
    ;// returns ebx as the new mapping

        ASSUME esi:PTR OSC_FILE_MAP

    ;// get ownership of the table, get the view

        invoke WaitForSingleObject, gmap_hMutex, -1
        mov ebx, gmap_pView
        ASSUME ebx:PTR GLOBAL_MAPPING_STRUCT

    ;//////////////////////////////////////////
    ;// locate the name
    ;//////////////////////////////////////////

        xor eax, eax                ;// loads strings
        mov edx, [ebx].num_records  ;// counts records
        mov edi, [esi].file.filename_Memory
        DEBUG_IF <!!edi>            ;// don't have a file name !!
        add edi, FILENAME.szPath
        add ebx, GLOBAL_MAPPING_STRUCT.table    ;// scans the table
        ASSUME ebx:PTR BYTE     ;// ptr to gmap
        ASSUME edi:PTR BYTE     ;// ptr to our map

    top_of_match_loop:

        xor ecx, ecx                ;// counts characters

    top_of_char_loop:

        mov ah, [ebx+ecx]   ;// load from gmap
        mov al, [edi+ecx]   ;// load from our name
        cmp al, ah
        jne next_record

        or ah, al                   ;// zero terminator
        je found_matching_name

    next_char:

        inc ecx
        cmp ecx, FILE_MAX_ID_LENGTH
        jb top_of_char_loop
        je found_matching_name  ;// not nessesarily zero terminated

    next_record:

        add ebx, SIZEOF GLOBAL_MAPPING_TABLE
        dec edx
        jnz top_of_match_loop

    ;// if not found, create a new entry
    create_new_entry:

        ASSUME ebx:PTR GLOBAL_MAPPING_STRUCT

    ;// locate first blank entry

        mov ebx, gmap_pView
        ASSUME ebx:PTR GLOBAL_MAPPING_STRUCT

        mov edx, [ebx].num_records  ;// counts records
        add ebx, GLOBAL_MAPPING_STRUCT.table ;// scans the table
        ASSUME ebx:PTR BYTE

        .REPEAT
            xor eax, eax        ;// loads strings
            or al, [ebx]
            jz heres_a_blank_entry
            add ebx, SIZEOF GLOBAL_MAPPING_TABLE
            dec edx
        .UNTIL ZERO?

    ;// if we hit this, the table is full !!!

        ;// we're done with the table

        invoke ReleaseMutex, gmap_hMutex
        DEBUG_IF <!!eax>

        ;// wine and complain ?
        ;// to whom ?

        ;//invoke MessageBoxA, popup_hWndhWnd, pText, pCation, MB_OK | MB_ICONHAND | MB_APPLMODAL
        xor eax, eax    ;// return bad mode
        jmp all_done

    ALIGN 16
    heres_a_blank_entry:

    ;////////////////////////////////////////////
    ;// create the mapping entry for this record
    ;////////////////////////////////////////////

        ASSUME ebx:PTR GLOBAL_MAPPING_TABLE

        ;// copy the name

            mov edx, [esi].file.filename_Memory
            DEBUG_IF <!!edx>    ;// no filename !!!
            mov ecx, ebx
            add edx, FILENAME.szPath
            STRCPY ecx, edx

        ;// determine the size of the object to create
        ;// store in global struct as well as osc

            mov eax, [esi].file.file_length     ;// get desired size
            .IF !eax
                inc eax
                mov [esi].file.file_length, eax
            .ELSEIF eax > MAX_GMAP_MEMORY_LENGTH
                mov eax, MAX_GMAP_MEMORY_LENGTH
                mov [esi].file.file_length, eax
            .ENDIF
            shl eax, 2
            mov [esi].file.file_size, eax
            mov edx, app_AllocationGranularity
            mov [ebx].file_size, eax

            dec edx         ;// mask desired size to AllocationGranularity
            add eax, edx
            not edx
            and eax, edx
            mov [ebx].actual_size, eax              ;// store in global
            mov [esi].file.gmap.actual_size, eax    ;// store in osc

        ;// create the mapping for the data

            invoke CreateFileMappingA, 0FFFFFFFFh, 0, PAGE_READWRITE,
                0,eax,0
            DEBUG_IF<!!eax>, GET_ERROR  ;// couldn't create mapping !

        ;// xfer settings to global struct

            mov [ebx].hMap, eax         ;// store handle in gmap
            mov [esi].file.gmap.hMap, eax   ;// store handle in object
            mov eax, gmap_pid           ;// set it's process id
            mov [ebx].pid, eax

            jmp bump_instance_count

    ;///////////////////////////////////////////
    ;// found existing entry, duplicate handle
    ;///////////////////////////////////////////
    ALIGN 16
    found_matching_name:

        .IF [ebx].pid   ;// duplicate mapping

            invoke OpenProcess, PROCESS_DUP_HANDLE,0,[ebx].pid
            push eax    ;// save so we can close

            invoke GetCurrentProcess
            mov edx, [esp]
            lea ecx, [esi].file.gmap.hMap

            invoke DuplicateHandle, edx, [ebx].hMap,
                                    eax, ecx,
                                    0, 0, DUPLICATE_SAME_ACCESS
            DEBUG_IF <!!eax>, GET_ERROR ;// could not duplicate !!

            call CloseHandle    ;// arg already pushed
            DEBUG_IF <!!eax>, GET_ERROR ;// could not close handle !!

        .ELSE   ;// hProcess was zero
            ;// create new mapping using sizes specified by global

            invoke CreateFileMappingA, 0FFFFFFFFh, 0, PAGE_READWRITE,
                0,[ebx].actual_size,0
            DEBUG_IF <!!eax>, GET_ERROR ;// could not create mapping


            ;// set global hMap and process
            mov [ebx].hMap, eax
            mov [esi].file.gmap.hMap, eax

            mov eax, gmap_pid
            mov [ebx].pid, eax

        .ENDIF

        ;// xfer sizes from global struct to osc

        mov eax, [ebx].file_size
        mov edx, [ebx].actual_size
        mov [esi].file.file_size, eax
        mov [esi].file.gmap.actual_size, edx
        shr eax, 2
        mov [esi].file.file_length, eax

    bump_instance_count:

        mov [esi].file.gmap.pTable, ebx
        inc [ebx].instance

    ;// now we map the view

        invoke MapViewOfFile, [esi].file.gmap.hMap, FILE_MAP_ALL_ACCESS, 0,0,0
        DEBUG_IF <!!eax>    ;// no mapping
        mov [esi].file.buf.pointer, eax

    ;// we're done with the table

        invoke ReleaseMutex, gmap_hMutex
        DEBUG_IF <!!eax>
        ;// release mutex returns non zero for us

    all_done:

        ret

gmap_attach ENDP


ASSUME_AND_ALIGN
gmap_detach PROC

        ASSUME esi:PTR OSC_FILE_MAP

    ;// get ownership of the table and load table entry

        invoke WaitForSingleObject, gmap_hMutex, -1 ;// wait for ownership
        mov ebx, [esi].file.gmap.pTable
        ASSUME ebx:PTR GLOBAL_MAPPING_TABLE
        mov [esi].file.gmap.pTable, 0       ;// clear our table entry

    ;// unmap osc's entry

        invoke UnmapViewOfFile, [esi].file.buf.pointer
        DEBUG_IF <!!eax>, GET_ERROR
        mov [esi].file.buf.pointer, 0       ;// clear our buffer

    ;// close the osc's handle
    ;// if osc handle = table handle, then clear both

        mov eax, [esi].file.gmap.hMap       ;// get our map entry
        .IF eax == [ebx].hMap               ;// see if we are the global entry

            mov [ebx].hMap, 0               ;// clear if so
            mov [ebx].pid, 0

        .ENDIF
        invoke CloseHandle, eax             ;// close our mapping
        DEBUG_IF<!!eax>, GET_ERROR
        mov [esi].file.gmap.hMap, 0         ;// set our hMap to 0

    ;// decrease instance on the table

        dec [ebx].instance
        DEBUG_IF <SIGN?>
        .IF ZERO?
            ;// no one's using, time to clear this record
            push edi
            mov ecx, (SIZEOF GLOBAL_MAPPING_TABLE) / 4
            xor eax, eax
            mov edi, ebx
            rep stosd
            pop edi
        .ENDIF

    ;// release our hold on the table

        invoke ReleaseMutex, gmap_hMutex
        DEBUG_IF <!!eax>

    ;// that's it

        ret

gmap_detach ENDP

ASSUME_AND_ALIGN
gmap_change_size PROC

        ASSUME esi:PTR OSC_FILE_MAP

    ;// get ownership of the table and load table entry

        invoke WaitForSingleObject, gmap_hMutex, -1 ;// wait for ownership
        mov ebx, [esi].file.gmap.pTable
        ASSUME ebx:PTR GLOBAL_MAPPING_TABLE

    ;// see if we can just update global file size

        mov eax, [esi].file.file_length
        shl eax, 2
        mov [esi].file.file_size, eax
        cmp eax, [ebx].actual_size
        ja have_to_realloacte

    ;// we can use the same size

        mov [ebx].file_size, eax
        jmp done_with_table

    have_to_realloacte:

    ;// close mapping using local osc hMap
    ;// unmap osc's entry and close handle

        invoke UnmapViewOfFile, [esi].file.buf.pointer
        DEBUG_IF <!!eax>, GET_ERROR
        mov [esi].file.buf.pointer, 0       ;// clear our buffer

        invoke CloseHandle, [esi].file.gmap.hMap
        DEBUG_IF<!!eax>, GET_ERROR

    ;// create a new map with the desired size
    ;// determine the size of the object to create
    ;// store in global struct as well as osc

        mov eax, [esi].file.file_length     ;// get desired size
        .IF !eax
            inc eax
            mov [esi].file.file_length, eax
        .ENDIF
        shl eax, 2
        mov [esi].file.file_size, eax
        mov edx, app_AllocationGranularity
        mov [ebx].file_size, eax

        dec edx         ;// mask desired size to AllocationGranularity
        add eax, edx
        not edx
        and eax, edx
        mov [ebx].actual_size, eax              ;// store in global
        mov [esi].file.gmap.actual_size, eax    ;// store in osc

    ;// create the mapping for the data

        invoke CreateFileMappingA, 0FFFFFFFFh, 0, PAGE_READWRITE,
            0,eax,0
        DEBUG_IF<!!eax>, GET_ERROR  ;// couldn't create mapping !

    ;// replace global hMap
    ;// xfer settings to global struct

        mov [ebx].hMap, eax         ;// store handle in gmap
        mov [esi].file.gmap.hMap, eax   ;// store handle in object
        mov eax, gmap_pid               ;// set it's process id
        mov [ebx].pid, eax

    ;// now we map the view

        invoke MapViewOfFile, [esi].file.gmap.hMap, FILE_MAP_ALL_ACCESS, 0,0,0
        DEBUG_IF <!!eax>    ;// no mapping
        mov [esi].file.buf.pointer, eax

    ;// release our hold on the table
    done_with_table:

        invoke ReleaseMutex, gmap_hMutex
        DEBUG_IF <!!eax>

    ;// that's it

        ret

gmap_change_size ENDP

ASSUME_AND_ALIGN
gmap_reattach PROC

        ASSUME esi:PTR OSC_FILE_MAP

    ;// get ownership of the table and load table entry

        invoke WaitForSingleObject, gmap_hMutex, -1 ;// wait for ownership
        mov ebx, [esi].file.gmap.pTable
        ASSUME ebx:PTR GLOBAL_MAPPING_TABLE

    ;// if osc hMap == global hMap
    ;//     zero global hProcess and hMap

        mov eax, [ebx].hMap
        sub eax, [esi].file.gmap.hMap
        .IF ZERO?
            mov [ebx].hMap, eax
            mov [ebx].pid, eax
        .ENDIF

    ;// close map using local osc settings
    ;// unmap osc's entry and close handle

        invoke UnmapViewOfFile, [esi].file.buf.pointer
        DEBUG_IF <!!eax>, GET_ERROR
        mov [esi].file.buf.pointer, 0       ;// clear our buffer

        invoke CloseHandle, [esi].file.gmap.hMap
        DEBUG_IF<!!eax>, GET_ERROR

    ;// if hprocess exists

        .IF [ebx].pid   ;// duplicate mapping

            invoke OpenProcess, PROCESS_DUP_HANDLE,0,[ebx].pid
            push eax    ;// save so we can close

            invoke GetCurrentProcess
            mov edx, [esp]
            lea ecx, [esi].file.gmap.hMap

            invoke DuplicateHandle, edx, [ebx].hMap,
                                    eax, ecx,
                                    0, 0, DUPLICATE_SAME_ACCESS
            DEBUG_IF <!!eax>, GET_ERROR ;// could not duplicate !!

            call CloseHandle    ;// arg already pushed
            DEBUG_IF <!!eax>, GET_ERROR ;// could not close handle !!

        .ELSE   ;// hProcess was zero
            ;// create new mapping using sizes specified by global

            invoke CreateFileMappingA, 0FFFFFFFFh, 0, PAGE_READWRITE,
                0,[ebx].actual_size,0
            DEBUG_IF <!!eax>, GET_ERROR ;// could not create mapping

            ;// set global hMap and process
            mov [ebx].hMap, eax
            mov [esi].file.gmap.hMap, eax

            mov eax, gmap_pid
            mov [ebx].pid, eax

        .ENDIF

    ;// get sizes from global

        mov eax, [ebx].file_size
        mov edx, [ebx].actual_size
        mov [esi].file.file_size, eax
        mov [esi].file.gmap.actual_size, edx
        shr eax, 2
        mov [esi].file.file_length, eax

    ;// now we map the view

        invoke MapViewOfFile, [esi].file.gmap.hMap, FILE_MAP_ALL_ACCESS, 0,0,0
        DEBUG_IF <!!eax>    ;// no mapping
        mov [esi].file.buf.pointer, eax

    ;// release our hold on the table

        invoke ReleaseMutex, gmap_hMutex
        DEBUG_IF <!!eax>

    ;// that's it

        ret

gmap_reattach ENDP




ASSUME_AND_ALIGN
gmap_Open PROC USES ebx edi

    ;// AttachObject

    ;// verify that file can be opened
    ;// set the osc_object capability flags
    ;// open the file
    ;// set the osc_object capability flags
    ;// set the format variables
    ;// determine the maximum size
    ;// return zeero for sucess


        ASSUME ebp:PTR LIST_CONTEXT
        ASSUME esi:PTR OSC_FILE_MAP

        DEBUG_IF <!!gmap_pView>     ;// it's not opened !!

        DEBUG_IF <!!gmap_hMutex>    ;// there's no mutex !!

    ;// make sure mode is available

        test file_available_modes, FILE_AVAILABLE_MEMORY
        jz set_bad_mode

    ;// make sure we have a name

        cmp [esi].file.filename_Memory, 0
        je set_bad_mode

    ;// try to open the mapping

        invoke gmap_attach
        ASSUME ebx:PTR GLOBAL_MAPPING_TABLE ;// ebx returns with
        test eax, eax
        jz set_bad_mode

    ;// set all flags as ok

        or [esi].dwUser,FILE_MODE_IS_MOVEABLE OR    \
                        FILE_MODE_IS_READABLE OR    \
                        FILE_MODE_IS_WRITABLE OR    \
                        FILE_MODE_IS_SEEKABLE OR    \
                        FILE_MODE_IS_REVERSABLE OR  \
                        FILE_MODE_IS_SIZEABLE   OR  \
                        FILE_MODE_IS_RATEABLE   OR  \
                        FILE_MODE_IS_CALCABLE

    ;// setup the rest of the buffer values

        mov eax, [esi].file.file_length
        mov [esi].file.buf.stop, eax

        xor eax, eax
        mov [esi].file.buf.start, eax
        mov [esi].file.buf.remain, eax

        mov [esi].file.max_length,MAX_GMAP_MEMORY_LENGTH
        mov [esi].file.fmt_rate, 44100

    ;// return sucess (eax already zero)

    ;// that should do it
    time_to_go:

        ret

    set_bad_mode:

        mov eax, 1
        jmp time_to_go

gmap_Open ENDP

ASSUME_AND_ALIGN
gmap_Close PROC USES ebx edi

        ASSUME esi:PTR OSC_FILE_MAP

        DEBUG_IF <!!gmap_hMap>  ;// gmap is not opened

        DEBUG_IF <!!gmap_pView> ;// there is not view to manipulate

    ;// make sure we're open

        .IF [esi].file.buf.pointer

        ;// release our interface

            invoke gmap_detach

        ;// reset buffer

            xor eax, eax
            mov [esi].file.buf.start, eax
            mov [esi].file.buf.stop, eax
            mov [esi].file.file_position, eax

        .ENDIF

    ;// that's it

        and [esi].dwUser, NOT FILE_MODE_IS_CALCABLE

        ret

gmap_Close ENDP



ASSUME_AND_ALIGN
gmap_SetLength  PROC USES ebx edi

        invoke gmap_change_size
        ret

gmap_SetLength ENDP


ASSUME_AND_ALIGN
gmap_CheckState PROC

        ASSUME esi:PTR OSC_FILE_MAP

    ;// point at directory entry
    ;// verify file size
    ;// if different, do the resize operation
    ;// that's it

        mov ebx, [esi].file.gmap.pTable
        ASSUME ebx:PTR GLOBAL_MAPPING_TABLE
        DEBUG_IF <!!ebx>    ;// device is not opened yet !!

        mov eax, [ebx].file_size        ;// load file size from global table
        cmp eax, [esi].file.file_size
        jne have_to_resize              ;// see if it's different

    setup_buffer:

        xor edx, edx
        mov eax, [esi].file.file_length
        mov [esi].file.buf.start, edx
        mov [esi].file.buf.stop, eax
        mov [esi].file.buf.remain, edx

    ;// return sucess
    ;// no need to to check file position
    ;// we always have valid buffers

        ret

    ALIGN 16
    have_to_resize:

    ;// sizes are different
    ;// can we just bump the file size ?

        mov edx, [ebx].actual_size
        .IF edx != [esi].file.gmap.actual_size

            ;// have to reattach

            invoke gmap_reattach

        .ELSE   ;// we can simply adjust the file size

            mov [esi].file.file_size, eax
            shr eax, 2
            mov [esi].file.file_length, eax

        .ENDIF

    ;// make sure the position value is correct

        cmp eax, [esi].file.file_position
        ja setup_buffer

        dec eax
        mov [esi].file.file_position, eax
        jmp setup_buffer

gmap_CheckState ENDP

;///////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////




ENDIF ;// USE_THIS_FILE


ASSUME_AND_ALIGN

END


