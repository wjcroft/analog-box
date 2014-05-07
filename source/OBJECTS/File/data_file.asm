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
;//     data_file.asm
;//

;// TOC
;//
;// data_Open
;// data_CheckState
;// data_GetBuffer
;// data_Close
;// data_SetLength


OPTION CASEMAP:NONE

.586
.MODEL FLAT

USE_THIS_FILE equ 1

IFDEF USE_THIS_FILE

    .NOLIST
    INCLUDE <Abox.inc>
    INCLUDE <ABox_OscFile.inc>
    .LIST

.DATA

    NUM_FILE_SEEKS  EQU 32  ;// max number of seeks we allow
    file_seeks      dd  0   ;// prevents excessive seeking

.CODE




;///////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////
;///
;///
;///    data file
;///
;///

ASSUME_AND_ALIGN
data_Open PROC uses ebx

;// verify that fie can be opened
;// set the osc_object capability flags
;// open the file
;// set the osc_object capability flags
;// set the format variables
;// determine the maximum size
;// return zeero for sucess

        ASSUME esi:PTR OSC_FILE_MAP

    ;// make sure mode is available

        test file_available_modes, FILE_AVAILABLE_DATA
        jz set_bad_mode

    ;// make sure we have a file name

        cmp [esi].file.filename_Data, 0 ;// skip if no name
        je set_bad_mode

    ;// try to open the file

    ;// determine if the file exists

        mov ebx, [esi].file.filename_Data
        ASSUME ebx:PTR FILENAME
        mov eax, file_changing_name     ;// set by popup handler
        invoke file_locate_name         ;// see if file already exists
        mov [esi].file.filename_Data, ebx   ;// store new name
        add ebx, OFFSET FILENAME.szPath     ;// advance to text name
        ASSUME ebx:PTR BYTE                 ;// force error if used incorrectly
        dec eax                         ;// check the return value
        js file_doesnt_exist            ;// eax = 0 ?

    file_exists_at_location:

    ;// open it

        invoke CreateFileA, ebx,
            GENERIC_READ + GENERIC_WRITE,
            FILE_SHARE_READ + FILE_SHARE_WRITE,
            0, OPEN_EXISTING,
            FILE_FLAG_SEQUENTIAL_SCAN, 0

            DEBUG_IF <!!eax>, GET_ERROR

        .IF eax == INVALID_HANDLE_VALUE     ;// can't open in this mode

            ;// try read only
            invoke CreateFileA, ebx,
                GENERIC_READ,
                FILE_SHARE_READ + FILE_SHARE_WRITE,
                0, OPEN_EXISTING,
                FILE_FLAG_SEQUENTIAL_SCAN, 0

            cmp eax, INVALID_HANDLE_VALUE
            je set_bad_mode     ;// can't open this file !!

        .ENDIF

        mov [esi].file.datafile.hFile, eax  ;// store the handle

    ;// determine if we can write to it

        invoke GetFileAttributesA, ebx
        .IF !(eax & (FILE_ATTRIBUTE_READONLY OR FILE_ATTRIBUTE_SYSTEM))
            ;// can write to this
            or [esi].dwUser,FILE_MODE_IS_WRITABLE
        .ENDIF

    ;// get the size and set length
    ;// if we get a zero size, and we can't write to file, set as bad

        pushd 0
        invoke GetFileSize, [esi].file.datafile.hFile, esp
        pop edx
        .IF edx
            mov eax, 7FFFFFFFh  ;// max size
        .ENDIF
        mov [esi].file.file_size, eax
        shr eax, 2
        mov [esi].file.file_length, eax

        test eax, eax
        jnz rewind_the_file

    ;// got zero length

        test [esi].dwUser, FILE_MODE_IS_WRITABLE
        jnz size_the_file
        jmp set_bad_mode

    ;// file not found
    file_doesnt_exist:

    ;// create it where it's now specified

        invoke CreateFileA, ebx,
            GENERIC_READ + GENERIC_WRITE,
            FILE_SHARE_READ + FILE_SHARE_WRITE,
            0, CREATE_ALWAYS,
            FILE_FLAG_SEQUENTIAL_SCAN, 0

        cmp eax, INVALID_HANDLE_VALUE
        je set_bad_mode     ;// can't create this, might be a CD ROM

    ;// created new file just fine

        mov [esi].file.datafile.hFile, eax
        ;// CAN write to this
        or [esi].dwUser,FILE_MODE_IS_WRITABLE

    ;// if we have a size set it to that
    ;// otherwise make size = 1
    size_the_file:

        mov eax, [esi].file.file_length ;// length is the master
        .IF !eax    ;// length is zero
            inc eax
            mov [esi].file.file_length, eax
        .ENDIF
        shl eax, 2
        mov [esi].file.file_size, eax

        DEBUG_IF <!!([esi].dwUser & FILE_MODE_IS_WRITABLE)> ;// should have caught this

        invoke SetFilePointer, [esi].file.datafile.hFile, [esi].file.file_size, 0, FILE_BEGIN
        inc eax
        jz set_bad_mode ;// have an error value
        invoke SetEndOfFile,  [esi].file.datafile.hFile
        DEBUG_IF <!!eax>

    rewind_the_file:

    ;// set the rest of the flags

        or [esi].dwUser,FILE_MODE_IS_MOVEABLE OR    \
                        FILE_MODE_IS_READABLE OR    \
                        FILE_MODE_IS_SEEKABLE OR    \
                        FILE_MODE_IS_REVERSABLE OR  \
                        FILE_MODE_IS_RATEABLE OR    \
                        FILE_MODE_IS_CALCABLE

    ;// rewind to beginning

        invoke SetFilePointer, [esi].file.datafile.hFile, 0, 0, FILE_BEGIN
        mov [esi].file.file_position, 0

    ;// now we create the memory buffer needed to read and write from the file

        invoke memory_Alloc, GPTR, DATA_BUFFER_LENGTH * 4
        mov [esi].file.buf.pointer, eax

    ;// set buffers to force a data update

        mov edx, DATA_BUFFER_LENGTH
        xor eax, eax

        mov [esi].file.buf.remain, edx
        mov [esi].file.buf.start, eax
        mov [esi].file.buf.stop, edx

    ;// set the format values

        mov [esi].file.fmt_rate, 44100
        mov [esi].file.fmt_chan, 1

    ;// set the max size

        mov edx, [esi].file.file_length ;// default max length
        .IF [esi].dwUser & FILE_MODE_IS_WRITABLE
            mov edx, (7FFFFFFFh / 4)
            or [esi].dwUser, FILE_MODE_IS_SIZEABLE
        .ENDIF
        mov [esi].file.max_length, edx

    ;// that should do it, return sucess

        xor eax, eax

    all_done:

        ret

    ALIGN 16
    set_bad_mode:

        invoke data_Close

        mov eax, 1
        jmp all_done

data_Open ENDP


ASSUME_AND_ALIGN
data_CheckState PROC

        ASSUME esi:PTR OSC_FILE_MAP

    ;// we should do a size check here, even though it's very expensive
    ;// ABOX234 it is very expensive, let's see if somebody else hasn't done this already

        mov ebx, [esi].pDevice
        ASSUME ebx:PTR FILE_HARDWARE_DEVICEBLOCK
        dlist_GetHead file_hardware,ebx,ebx
        ASSUME ebx:PTR OSC_FILE_DATA
        .IF ebx
            .REPEAT
                sub ebx, OSC_FILE_MAP.file
                ASSUME ebx:PTR OSC_FILE_MAP
                .IF ebx != esi \
                && [ebx].file.datafile.hFile    \
                && [ebx].file.datafile.dwFlags & DATA_FILE_SIZE_READ
                    ;// make sure the names are the same
                    mov edx, [esi].file.filename_Data
                    mov ecx, [ebx].file.filename_Data
                    mov eax, (FILENAME PTR [edx]).dwLength
                    cmp eax, (FILENAME PTR [ecx]).dwLength
                    .IF ZERO?
                        add edx, FILENAME.szPath
                        add ecx, FILENAME.szPath
                        invoke lstrcmpiA,ecx,edx
                        .IF !eax
                            mov eax, [ebx].file.file_size
                            jmp have_the_file_size
                        .ENDIF
                    .ENDIF
                .ENDIF
                add ebx, OSC_FILE_MAP.file
                ASSUME ebx:PTR OSC_FILE_DATA
                dlist_GetNext file_hardware, ebx
            .UNTIL !ebx
        .ENDIF
    ;// have_to_read_size:
        invoke GetFileSize, [esi].file.datafile.hFile, 0
    have_the_file_size:
        or [esi].file.datafile.dwFlags, DATA_FILE_SIZE_READ
        and eax, NOT 3
        .IF eax != [esi].file.file_size
            shr eax, 2
            mov [esi].file.file_length, eax
            invoke data_SetLength
        .ENDIF

    ;// reset file_seeks

        mov file_seeks, NUM_FILE_SEEKS

    ;// detect if file pointer is outside of range
    ;// if not, get the desired data buffers

        mov eax, [esi].file.file_position
        cmp eax, [esi].file.file_length
        jb data_GetBuffer

    ;// otherwise return sucess
    ;// verify_file_position will take care of rewinding

        or eax, 1

        ret


data_CheckState ENDP


ASSUME_AND_ALIGN
data_GetBuffer  PROC uses ecx ebx

    ;// preserve ecx ebx edi ebp esp

    ;// if current buffer is dirty, write it to disk
    ;// set up new buffer based on file position
    ;// read new data from the file to the buffer

        ASSUME esi:PTR OSC_FILE_MAP

IFDEF DEBUG_BUILD
    mov eax, [esi].file_position
    DEBUG_IF < eax!>= [esi].file_length >   ;// not supposed to happen now !!!
ENDIF

    ;// prevent excessive seeking

        dec file_seeks
        js too_many_seeks

    ;// WRITE data if buffer is dirty

        BITR [esi].file.buf.dwFlags, DATA_BUFFER_DIRTY
        .IF CARRY?

            mov eax, [esi].file.buf.start
            shl eax, 2
            invoke SetFilePointer, [esi].file.datafile.hFile, eax, 0, FILE_BEGIN

            ;// make sure we don't write too many bytes

            mov ecx, [esi].file.buf.stop
            sub ecx, [esi].file.buf.start
            shl ecx, 2
            push edx
            mov edx, esp
            invoke WriteFile, [esi].file.datafile.hFile, [esi].file.buf.pointer, ecx, edx, 0
            pop edx

        .ENDIF

;// SETUP new buffer based on file_position
;// ABOX234: new version does account for file length

        mov eax, [esi].file.file_position   ;// get the desired position
        and eax, NOT(DATA_BUFFER_LENGTH-1)  ;// mask to multiple of buffer size

        lea edx, [eax+DATA_BUFFER_LENGTH]   ;// determine buffer stop
        .IF edx > [esi].file.file_length
            mov edx, [esi].file.file_length
            sub edx, eax
        .ENDIF
        mov [esi].file.buf.start, eax       ;// set as buffer start
        mov [esi].file.buf.stop, edx        ;// store buffer stop
        mov [esi].file.buf.remain, 0        ;// reset remain (un nessesary ?)

;// ABOX234: see if we can locate another buffer with these same settings
;// if we can, then just copy the data from there
;// otherwise we read

        mov ebx, [esi].pDevice
        ASSUME ebx:PTR FILE_HARDWARE_DEVICEBLOCK
        dlist_GetHead file_hardware,ebx,ebx
        ASSUME ebx:PTR OSC_FILE_DATA
        TESTJMP ebx, ebx, jz have_to_read

        mov edx, [esi].file.buf.start
        mov ecx, [esi].file.buf.stop
        .REPEAT
            ;// make sure it's a valid data file, and check the buffer boundaries
            sub ebx, OSC_FILE_MAP.file
            ASSUME ebx:PTR OSC_FILE_MAP
            .IF ebx != esi  \
            && [ebx].file.datafile.hFile \
            && [ebx].file.datafile.dwFlags & DATA_FILE_BUFFER_READY \
            && edx == [ebx].file.buf.start  \
            && ecx == [ebx].file.buf.stop
            ;// now we must check if the filenames are the same
                mov edx, [esi].file.filename_Data
                mov ecx, [ebx].file.filename_Data
                mov eax, (FILENAME PTR [edx]).dwLength
                cmp eax, (FILENAME PTR [ecx]).dwLength
                .IF ZERO?
                    add edx, FILENAME.szPath
                    add ecx, FILENAME.szPath
                    invoke lstrcmpiA, ecx, edx
                    .IF !eax
                        ;// now we have a duplicate buffer
                        push edi
                        push esi
                        mov ecx, [esi].file.buf.stop
                        mov edi, [esi].file.buf.pointer
                        sub ecx, [esi].file.buf.start
                        mov esi, [ebx].file.buf.pointer
                        rep movsd
                        pop esi
                        pop edi
                        or [esi].file.datafile.dwFlags, DATA_FILE_BUFFER_READY
                        or eax, 1       ;// return true to caller
                        jmp all_done
                    .ENDIF
                .ENDIF
                ;// keep searching after destroying edx and ecx
                mov edx, [esi].file.buf.start
                mov ecx, [esi].file.buf.stop
            .ENDIF
            add ebx, OSC_FILE_MAP.file
            ASSUME ebx:PTR OSC_FILE_DATA
            dlist_GetNext file_hardware, ebx
        .UNTIL !ebx

    have_to_read:

    ;// READ the data

        mov eax, [esi].file.buf.start   ;//eax = buf.start in dwords
        mov edx, [esi].file.buf.stop    ;//edx = buf.stop in dwords

        ;// we'll pre push args for the read

        sub edx, eax    ;// = length to read
        shl eax, 2      ;// turn into byte offset for seek
        shl edx, 2      ;// convert to bytes

        pushd 0     ;// bytes read
        mov ecx, esp
        pushd 0                     ;// ReadFile.pOverLapped
        push ecx                    ;// ReadFile.pBytesRead
        push edx                    ;// ReadFile.dwBytesToRead
        push [esi].file.buf.pointer ;// ReadFile.pBuffer
        push [esi].file.datafile.hFile  ;// ReadFile.hFile
        invoke SetFilePointer, [esi].file.datafile.hFile, eax, 0, FILE_BEGIN    ;// set the pointer
        call ReadFile   ;// args already pushed
        pop eax                 ;// retrieve bytes read

        or [esi].file.buf.dwFlags, DATA_FILE_BUFFER_READY

    ;// that's it
    all_done:

        ret

    ;// excessive seeks

    ALIGN 16
    too_many_seeks:

        xor eax, eax    ;// abort the calc
        mov [esi].file.buf.remain, DATA_BUFFER_LENGTH   ;// force a seek for the next frame
        jmp all_done

data_GetBuffer  ENDP




ASSUME_AND_ALIGN
data_Close PROC

    ASSUME esi:PTR OSC_FILE_MAP

    ;// close the file

        mov eax, [esi].file.datafile.hFile
        .IF eax
            invoke CloseHandle, eax
            mov [esi].file.datafile.hFile, 0
        .ENDIF

    ;// release buffer memory

        mov eax, [esi].file.buf.pointer
        .IF eax
            invoke memory_Free, eax
            mov [esi].file.buf.pointer, eax
        .ENDIF
        mov [esi].file.buf.start, eax
        mov [esi].file.buf.stop, eax
        mov [esi].file.buf.remain, eax

    ;// that should do it

        and [esi].dwUser, NOT FILE_MODE_IS_CALCABLE

        ret

data_Close ENDP


ASSUME_AND_ALIGN
data_SetLength PROC

    ;// try to set the length to what is stated

    ASSUME esi:PTR OSC_FILE_MAP

    DEBUG_IF <!!([esi].dwUser & FILE_MODE_IS_WRITABLE)> ;// popup should have disabled this

    invoke GetFileSize, [esi].file.datafile.hFile, 0
    push eax

    mov eax, [esi].file.file_length
    DEBUG_IF <!!eax>    ;// length is not supposed to be zero
    .IF eax <= [esi].file.file_position
        mov [esi].file.file_position, eax
        dec [esi].file.file_position
    .ENDIF
    shl eax, 2
    mov [esi].file.file_size, eax
    invoke SetFilePointer, [esi].file.datafile.hFile, eax, 0, FILE_BEGIN
    inc eax
    DEBUG_IF <ZERO?>    ;// set file pointer returned error
    invoke SetEndOfFile, [esi].file.datafile.hFile
    DEBUG_IF <!!eax>    ;// couldn't set size !!

    mov eax, [esi].file.file_size   ;// new size
    pop edx                         ;// old size
    .IF edx < eax

        ;// old size is less than new, so we need to initialize the data

        ;// what we'll do is write bytes until the file is full
        ;// we'll update the size display on popup as well

    ;// store registers and determine amount to add

        push ebx
        push edi

        mov ebx, edx    ;// old length

    ;// clear pin data

        lea edi, [esi].data_L
        mov ecx, SAMARY_LENGTH * 2
        xor eax, eax
        rep stosd
        sub edi, SAMARY_SIZE * 2    ;// put edi at start of save buffer

    ;// seek to old end of file

        invoke SetFilePointer, [esi].file.datafile.hFile, edx, 0, FILE_BEGIN

    ;// write bytes until done

        pushd 0     ;// progress counter
        pushd 0     ;// byte written

SS_1:   add ebx, SAMARY_SIZE*2
        cmp ebx, [esi].file.file_size
        ja SS_2

        dec DWORD PTR [esp+4]
        .IF SIGN?
        ;// show the new amount remaining
            mov DWORD PTR [esp+4], 32
            pushd 'i%'
            mov ecx, esp
            sub esp, 32
            mov edx, esp
            mov eax, ebx
            shr eax, 2
            invoke wsprintfA, edx, ecx, eax
            invoke GetDlgItem, popup_hWnd, ID_FILE_LENGTH_EDIT
            mov edx, esp
            push eax    ;// param for update window
            WINDOW eax, WM_SETTEXT, 0, edx
            call UpdateWindow
            add esp, 32+4
        .ENDIF

        mov edx, esp                ;// bytes written
        invoke WriteFile, [esi].file.datafile.hFile, edi, SAMARY_SIZE*2, edx, 0
        jmp SS_1                    ;// back to top


SS_2:   sub ebx, SAMARY_SIZE*2
        sub ebx, [esi].file.file_size
        je SS_3
        DEBUG_IF <!!SIGN?>
        neg ebx
        mov edx, esp                ;// write remaining bytes
        invoke WriteFile, [esi].file.datafile.hFile, edi, ebx, edx, 0

    ;// clean up and exit

SS_3:   pop edx     ;// bytes written
        pop eax     ;// counter
        pop edi
        pop ebx

    .ENDIF

    ret

data_SetLength ENDP



;///
;///
;///    data file
;///
;///
;///////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////





ENDIF   ;// USE_THIS_FILE




ASSUME_AND_ALIGN

END


