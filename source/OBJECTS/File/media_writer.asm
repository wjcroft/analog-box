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

; AJT: this code is still flaky ... maybe the model is just wrong ...

;//
;//     media_writer.asm
;//
OPTION CASEMAP:NONE
.586
.MODEL FLAT

;// TOC
;//
;// writer_Initialize PROC
;// writer_Destroy PROC
;//
;// writer_CreateNew PROC USES ebx edi
;// writer_OpenExisting PROC USES ebp ebx edi
;//
;// writer_Prepare PROC USES ebx edi
;// writer_Rewind PROC
;// writer_Open PROC
;// writer_Close PROC USES ebx edi

;// writer_Calc

USE_THIS_FILE equ 1

IFDEF USE_THIS_FILE

    .NOLIST
    INCLUDE <Abox.inc>
    INCLUDE <ABox_OscFile.inc>
    .LIST


comment ~ /*

RIFF

    we'll use the mmio functions to save some code writing hassles

    each file will has the following riff struct


                            ;Open
    RIFF size WAVE          ;mmioCreateChunk        MMIO_CREATERIFF
                            ;
        LIST size INFO      ;   mmioCreateChunk     MMIO_CREATELIST
                            ;
            ISFT size       ;       mmioCreateChunk
                            ;
                app_name    ;           mmioWrite
                            ;           mmioAscend
                            ;       mmioAscend
        fmt size            ;   mmioCreateChunk
                            ;
            wave format     ;       mmioWrite
                            ;       mmioAscend
        data size           ;   mmioCreateChunk
                            ;
            recorded data   ;       mmioWrite,mmioWrite,....
                            ;       mmioAscend
                            ;   mmioAscend
                            ;mmioClose


    mmioCreateChunk
    can create the chunk without a size
    mmioAscend will set the chunk size




ABOX234

    couple things we want to adjust

1)  if the file already exists
    we would like to _not_ automatically erase it

        one option is to always append data at the current position
        may need a mode to do this

        the worst of the problem is when the file is first opened

2)  there appears to be a minimum commit size
    this may need to be xplored in more detail
    a) is it only the first chunk ? < 2048 bytes
    b) is it always the last cunk ?
    c) is there a problem with the is_dirty value ?

to accomplish #2 we have implemented the file as a hardware device
hardware_H_Close after play stop will finalize it




to accomplish #1 we are changing the alogorithm

    1) opening an existing file always advances to the end
    2) only a rewind signal can erase and reset the file

    to accomplish this:

    writer_Open
        if file exists
            _OpenExisting
        otherwise
            _CreateNew
        allocate data buffers
        _Prepare

    writer_OpenExisting
        make sure all is ok in the wave file
        if not, ask user if we can change it
        can cancel and set bad mode

    writer_CreateNew
        build a new wave file complete with an info section
        the info is never used ... too bad for us

    writer_Close
        assume we are already flushed
        mmio close
        deallocate data

    writer_Prepare
        must not already be prepared
        descend into data chunk
        determine frame aligned write position
            read some data if nessesary
        seek to frame aligned end of data chunk
        set the file position
        set the prepared flag

    writer_Flush
        must be prepared
        possibly write remaining data
        ascend out of chuncks to finalize them
        reset the prepared flag

    writer_Rewind
        _Close
        _Delete
        _CreateNew
        _Prepare

*/ comment ~

.CODE

ASSUME_AND_ALIGN
writer_Initialize PROC
writer_Destroy PROC
        xor eax, eax    ;// mov eax, E_NOTIMPL
        ret
writer_Destroy ENDP
writer_Initialize ENDP



ASSUME_AND_ALIGN
writer_CreateNew PROC USES ebx edi

        ASSUME esi:PTR OSC_FILE_MAP
        DEBUG_IF <[esi].file.writer.hmmio>  ;// already opened !!
        DEBUG_IF <([esi].file.writer.dwFlags & WRITER_PREPARED)>    ;// not supposed to be prepared !!

    comment ~ /*

        we build the headers and prepare for writing data
        when we exit, we will be ready to begin streaming
        we assume that the file is empty

    */ comment ~

FILE_DEBUG_MESSAGE <"writer_CreateNew\n">

    ;// open the file

        mov ecx, [esi].file.filename_Writer
        add ecx, OFFSET FILENAME.szPath
        invoke mmioOpenA, ecx, 0, MMIO_READWRITE OR MMIO_CREATE OR MMIO_DENYWRITE
        DEBUG_IF <!!eax>    ;// supposed to be able to open the file

        mov [esi].file.writer.hmmio, eax
        mov ebx, eax    ;// ebx is now the file handle


        xor eax, eax
        lea edi, [esi].file.writer.chunk_riff
        ASSUME edi:PTR MMCKINFO

    ;// write the main chunk

        mov [edi].fccID, eax    ;// 'FFIR'
        mov [edi].dwSize, eax
        mov [edi].fccType, 'EVAW'
        mov [edi].dwDataOffset, eax
        mov [edi].dwFlags, 0

        invoke mmioCreateChunk, ebx, edi, MMIO_CREATERIFF
        DEBUG_IF <eax>

    ;// create the info chunk

            add edi, SIZEOF MMCKINFO
            ;//xor eax, eax

            mov [edi].fccID, eax
            mov [edi].dwSize, eax
            mov [edi].fccType, 'OFNI'
            mov [edi].dwDataOffset, eax
            mov [edi].dwFlags, 0

            invoke mmioCreateChunk, ebx, edi, MMIO_CREATELIST
            DEBUG_IF <eax>

            ;// the next chunk is built on the stack

                sub esp, SIZEOF MMCKINFO

            ;// build the isft sub chunk

                ;//xor eax, eax
                mov (MMCKINFO PTR [esp]).fccID, 'TFSI'  ;// 'TSIL'
                mov (MMCKINFO PTR [esp]).dwSize, eax
                mov (MMCKINFO PTR [esp]).fccType, eax
                mov (MMCKINFO PTR [esp]).dwDataOffset, eax
                mov (MMCKINFO PTR [esp]).dwFlags, 0
                mov ecx, esp

                invoke mmioCreateChunk, ebx, ecx, eax
                DEBUG_IF <eax>

                    pushd 0                         ;// terminator and pad
                    push ABOX_VERSION_STRING_REVERSE;// version
                    push 'xoBA'                     ;// app name
                    mov ecx, esp                    ;// point at stack
                    invoke mmioWrite, ebx, ecx, 12  ;// write the data
                    DEBUG_IF <eax==-1>
                    add esp, 12                     ;// clean up the stack

                    mov ecx, esp
                    invoke mmioAscend, ebx, ecx, 0
                    DEBUG_IF <eax>

            ;// clean up the stack and ascend back to LIST chunk

                    add esp, SIZEOF MMCKINFO

                invoke mmioAscend, ebx, edi, 0
                DEBUG_IF <eax>

    ;// write the wave format chunk

            ;//xor eax, eax

            mov [edi].fccID, ' tmf'
            mov [edi].dwSize, eax
            mov [edi].fccType, eax
            mov [edi].dwDataOffset, eax
            mov [edi].dwFlags, 0

            invoke mmioCreateChunk, ebx, edi, 0
            DEBUG_IF <eax>

                EXTERNDEF Wave_Format:WAVEFORMATEX  ;// defined in ABox_WaveOut.asm
                invoke mmioWrite, ebx, OFFSET Wave_Format, SIZEOF WAVEFORMATEX + 2
                DEBUG_IF <eax==-1>

                invoke mmioAscend, ebx, edi, 0
                DEBUG_IF <eax>

    ;// setup the data chunk

            ;//xor eax, eax

            mov [edi].fccID, 'atad'
            mov [edi].dwSize, eax
            mov [edi].fccType, eax
            mov [edi].dwDataOffset, eax
            mov [edi].dwFlags, 0

            invoke mmioCreateChunk, ebx, edi, 0
            DEBUG_IF <eax>

    ;// and we have to finalize by ascending out

        invoke mmioAscend,ebx,edi,0
        DEBUG_IF <eax>
        sub edi, SIZEOF MMCKINFO
        invoke mmioAscend,ebx,edi,0
        DEBUG_IF <eax>

    ;// and that should do
    ;// eax exits as zero, sucess

        ret

writer_CreateNew ENDP




;///////////////////////////////////////////////////////////////////////////////////
;//
;//
;//     writer_OpenExisting


ASSUME_AND_ALIGN
writer_OpenExisting PROC USES ebp ebx edi

comment ~ /*

    existing file must be
        proper wave file
        preferrably abox generated
        and the correct bit depth

*/ comment ~

FILE_DEBUG_MESSAGE <"writer_OpenExisting\n">

    ;// return eax==0 for ok
    ;// and eax!=0 if error

        ASSUME esi:PTR OSC_FILE_MAP

        DEBUG_IF <[esi].file.writer.hmmio>  ;// already opened !!
        DEBUG_IF <([esi].file.writer.dwFlags & WRITER_PREPARED)>    ;// not supposed to be prepared !!

    ;// prepare a couple of stack structs and some running flags

        sub esp, SIZEOF WAVEFORMATEX + 2 + SIZEOF MMCKINFO
        st_info    TEXTEQU <(MMCKINFO PTR [esp])>
        st_wavefmt TEXTEQU <(WAVEFORMATEX PTR [esp+SIZEOF MMCKINFO])>

    try_again:  ;// try again from the very beggining

        xor ebx, ebx    ;// file handle
        xor ebp, ebp    ;// collection of bits


        HAS_RIFF_WAVE_CHUNK EQU     1000h

        HAS_INFO_CHUNK      EQU      400h
        HAS_ISFT_CHUNK      EQU      200h
        IS_ABOX_GENERATED   EQU      100h

        HAS_FORMAT_CHUNK    EQU       20h
        IS_WAVEFORMATEX     EQU       10h
        IS_BLOCKALIGN       EQU        8h
        IS_16BIT            EQU        4h
        IS_STEREO           EQU        2h
        IS_PCM              EQU        1h

        IS_ACCEPTABLE       EQU 0000103Fh   ;// and, then equate

    ;// try to open the existing file

        mov ecx, [esi].file.filename_Writer     ;// get the FILENAME
        add ecx, OFFSET FILENAME.szPath         ;// advance to the text portion
        invoke mmioOpenA, ecx, 0, MMIO_READWRITE OR MMIO_DENYWRITE  ;// try to open it
        .IF !eax                    ;// check for errors

            invoke file_ask_retry, OFFSET sz_Wave_space_Writer, [esi].file.filename_Writer
            ;// returns one of IDRETRY, IDCANCEL

            CMPJMP eax, IDRETRY, je try_again
            jmp set_as_bad      ;// otherwise we have an error

        .ENDIF
        mov ebx, eax    ;// ebx is now the open file handle

    ;// locate the RIFF WAVE chunk

        xor eax, eax
        lea edi, [esi].file.writer.chunk_riff
        ASSUME edi:PTR MMCKINFO     ;// edi will point at the RIFF.WAVE chunck

        mov [edi].fccID, 'FFIR'
        mov [edi].dwSize, eax
        mov [edi].fccType, 'EVAW'
        mov [edi].dwDataOffset, eax
        mov [edi].dwFlags, 0

        invoke mmioDescend, ebx, edi, 0, MMIO_FINDRIFF
        TESTJMP eax, eax, jnz wave_file_done

        ;// so we know now that we are a wave file ?

        or ebp, HAS_RIFF_WAVE_CHUNK

;// RIFF.WAVE

    ;// locate the LIST INFO chunk

        mov eax, [edi].dwDataOffset
        add eax, 4  ;// dumb
        invoke mmioSeek, ebx, eax, SEEK_SET ;// must be in parent chunk

        lea ecx, [edi+SIZEOF MMCKINFO]  ;// use our second chunk as a new one
        ASSUME ecx:PTR MMCKINFO
        xor eax, eax

        mov [ecx].fccID, 'TSIL'
        mov [ecx].dwSize, eax
        mov [ecx].fccType, 'OFNI'
        mov [ecx].dwDataOffset, eax
        mov [ecx].dwFlags, eax

        invoke mmioDescend, ebx, ecx, edi, MMIO_FINDLIST
        TESTJMP eax, eax, jnz info_chunk_done

        or ebp, HAS_INFO_CHUNK

;// RIFF.WAVE : LIST.INFO

    ;// locate ISFT chunk

        mov st_info.fccID, 'TFSI'
        mov st_info.dwSize, eax
        mov st_info.fccType, eax
        mov st_info.dwDataOffset, eax
        mov st_info.dwFlags, 0
        lea ecx, [edi+SIZEOF MMCKINFO]  ;// use our second chunk as the parent
        mov edx, esp

        invoke mmioDescend, ebx, edx, ecx, MMIO_FINDCHUNK
        TESTJMP eax, eax, jnz info_chunk_done

        or ebp, HAS_ISFT_CHUNK

;// RIFF.WAVE : LIST.INFO : ISFT.___

    ;// read the first 4 characters

        mov edx, st_info.dwSize
        CMPJMP edx, 4, jbe info_chunk_done

        push edx        ;// make 4 byte text area
        mov ecx, esp    ;// point at where to store

        invoke mmioRead, ebx, ecx, 4
        pop edx
        CMPJMP eax, 4, jne info_chunk_done
        CMPJMP edx, 'xoBA', jne info_chunk_done

        or ebp, IS_ABOX_GENERATED

    info_chunk_done:

;// now we need to verify the format ... or should we even mess with this ?
;// yes we should, we have to have the same bit depth and number of channels
;// the sample rate needn't be messed with
;// we still have an MMCKINFO struct on the stack


    ;// locate the fmt chunk
        mov eax, [edi].dwDataOffset
        add eax, 4  ;// dumb
        invoke mmioSeek, ebx, eax, SEEK_SET ;// must be in parent chunk
        xor eax, eax

        mov st_info.fccID, ' tmf'   ;// fmt
        mov st_info.dwSize, eax
        mov st_info.fccType, eax
        mov st_info.dwDataOffset, eax
        mov st_info.dwFlags, eax
        mov edx, esp

        invoke mmioDescend, ebx, edx, edi, MMIO_FINDCHUNK
        TESTJMP eax, eax, jnz format_chunk_done

        or ebp, HAS_FORMAT_CHUNK

    ;// try to read the format data

        lea ecx, st_wavefmt
        ;// unfortunately there are several sizes we could be reading
        ;// so we will read only the size we need
        ;// we can determine if the size is too small however
        mov edx, SIZEOF WAVEFORMATEX - 2 ;// we subtract 2, don't need the end of it
        CMPJMP edx, st_info.dwSize, ja format_chunk_done

        or ebp, IS_WAVEFORMATEX

        invoke mmioRead, ebx, ecx, edx
        CMPJMP eax, SIZEOF WAVEFORMATEX - 2, jne format_chunk_done

    ;// make sure the bit depths are the same

        xor eax, eax

        cmp st_wavefmt.wFormatTag, WAVE_FORMAT_PCM
        sete ah
        ;// shl ah, 3
        or al, ah   ;// IS_PCM

        cmp st_wavefmt.wChannels, 2
        sete ah
        shl ah, 1
        or al, ah   ;// IS_STEREO

        cmp st_wavefmt.wBitsPerSample, 16
        sete ah
        shl ah, 2
        or al, ah   ;// IS_16BIT

        cmp st_wavefmt.wBlockAlign, 4
        sete ah
        shl ah, 3
        or al, ah

        and ah, 0
        or ebp, eax ;// IS_BLOCKALIGN

    format_chunk_done:

    wave_file_done:

    ;// now we've run the guantlet and can peruse our results

        mov [esi].file.writer.hmmio, ebx    ;// store the file handle

        and ebp, IS_ACCEPTABLE
        .IF ebp != IS_ACCEPTABLE

            ;// format and display a warning message

            .DATA
            sz_warning  db 'A Wave Writer object cannot use this file.',0dh,0ah
                        db 'It is not a 16 bit stereo wave file.',0dh,0ah
                        db 'ABox will erase and reformat it if you choose "Yes"',0dh,0ah
                        db 0dh,0ah
                        db 'Are you sure you want to erase it ?',0
                        ALIGN 4
            .CODE

            ;// close the file, we can't use it
            .IF ebx
                invoke mmioClose, ebx, 0
                xor ebx, ebx
                mov [esi].file.writer.hmmio, ebx    ;// store the file handle
            .ENDIF

            ;// do a message box, use the file name as the caption
            mov ecx, [esi].file.filename_Writer
            ;//mov ecx, (FILENAME PTR [ecx]).pName
            add ecx, FILENAME.szPath

            or app_DlgFlags, DLG_MESSAGE
            invoke MessageBoxA, hMainWnd, OFFSET sz_warning, ecx, MB_YESNO OR MB_ICONQUESTION OR MB_SETFOREGROUND OR MB_TOPMOST
            and app_DlgFlags, NOT DLG_MESSAGE

            .IF eax == IDYES    ;// user said yes, go ahead and rebuild it

                mov ecx, [esi].file.filename_Writer     ;// get the FILENAME
                add ecx, OFFSET FILENAME.szPath         ;// advance to the text portion
                invoke DeleteFileA, ecx
                invoke writer_CreateNew ;// will set hmmio and return the proper value

            .ELSE ;// user said no
            set_as_bad:
                mov eax, 1  ;// error value
            .ENDIF

        .ELSE   ;// is acceptable
            xor eax, eax    ;// return complete and total sucess
        .ENDIF


    ;// all_done:

        add esp, SIZEOF WAVEFORMATEX + 2 + SIZEOF MMCKINFO

        ret

writer_OpenExisting ENDP





;////////////////////////////////////////////////////////////////////////////////////////
;//
;//
;//     writer_Prepare




ASSUME_AND_ALIGN
writer_Prepare PROC USES ebx edi

        ASSUME esi:PTR OSC_FILE_MAP
        DEBUG_IF <!![esi].file.writer.hmmio>    ;// not already opened !!
        DEBUG_IF <([esi].file.writer.dwFlags & WRITER_PREPARED)>    ;// not supposed to be prepared !!

FILE_DEBUG_MESSAGE <"writer_Prepare\n">


    ;// tasks
    ;// 1) descend into the data chunk
    ;// 2) determine the frame aligned data buffer boundaries and seek to said location
    ;// 3) if not on a frame, then read data into the buffers from the file

        ;// 1) seek to begin, then descend into the data chunk

            mov ebx, [esi].file.writer.hmmio
            lea edi, [esi].file.writer.chunk_riff
            ASSUME edi:PTR MMCKINFO

            invoke mmioSeek, ebx, 0, 0  ;// rewind to beginning
            DEBUG_IF <eax>

            ;// descend into the riff chunck
            ;// edi still points at it

            mov [edi].fccID, 'FFIR'
            mov [edi].dwSize, eax
            mov [edi].fccType, 'EVAW'
            mov [edi].dwDataOffset, eax
            mov [edi].dwFlags, 0

            invoke mmioDescend, ebx, edi, 0, MMIO_FINDRIFF
            DEBUG_IF <eax>  ;// MMIOERR_CHUNKNOTFOUND

            mov ecx, edi
            ASSUME ecx:PTR MMCKINFO
            add edi, SIZEOF MMCKINFO

            mov [edi].fccID, 'atad'
            mov [edi].dwSize, eax
            mov [edi].fccType, eax
            mov [edi].dwDataOffset, eax ;// should put this at the end ?
            mov [edi].dwFlags, 0

            invoke mmioDescend, ebx, edi, ecx, MMIO_FINDCHUNK
            DEBUG_IF <eax>

        ;// 2) now we know our size

            mov eax, [edi].dwSize               ;// size in bytes
            shr eax, 2                          ;// size in stereo words, samples
            mov [esi].file.file_position, eax   ;// is our now current file_position
            mov [esi].file.file_length, eax     ;// and set the file length
            shl eax, 2                          ;//
            add eax, [edi].dwDataOffset         ;// offset by file chunk position
            invoke mmioSeek,ebx,eax,SEEK_SET    ;// do the seek

        ;// and we should be ready now

            or [esi].file.writer.dwFlags, WRITER_PREPARED
            xor eax, eax    ;// return 0 for all is ok

        all_done:

            ret

writer_Prepare ENDP





;////////////////////////////////////////////////////////////////////////////////////////
;//
;//
;//     writer_Rewind


ASSUME_AND_ALIGN
writer_Rewind PROC

        ASSUME esi:PTR OSC_FILE_MAP

        DEBUG_IF <!![esi].file.writer.hmmio>    ;// not opened !!
        DEBUG_IF <!!([esi].file.writer.dwFlags & WRITER_PREPARED)>  ;// supposed to be prepared !!

FILE_DEBUG_MESSAGE <"writer_Rewind\n">

        invoke mmioClose, [esi].file.writer.hmmio, 0
        mov [esi].file.writer.hmmio, eax
        TESTJMP eax, eax, jnz bad_mode

        and [esi].file.writer.dwFlags, NOT WRITER_PREPARED
        mov ecx, [esi].file.filename_Writer
        add ecx, FILENAME.szPath    ;// advance to the sz portion
        invoke DeleteFileA, ecx     ;// delete from disk
        TESTJMP eax, eax, jz bad_mode
        invoke writer_CreateNew     ;// open and create a new file
        TESTJMP eax, eax, jnz bad_mode
        invoke writer_Prepare       ;// prepare for writting
        ;// has our return value
    all_done:
        ret
    bad_mode:
        mov eax, 1  ;// bad
        jmp all_done

writer_Rewind ENDP








;////////////////////////////////////////////////////////////////////////////////////////
;//
;//
;//     writer_Open


ASSUME_AND_ALIGN
writer_Open PROC

;// verify that fie can be opened
;// set the osc_object capability flags
;// open the file
;// set the osc_object capability flags
;// set the format variables
;// determine the maximum size
;// return zero for sucess

        ASSUME esi:PTR OSC_FILE_MAP

    ;// make sure mode is available

        TESTJMP file_available_modes, FILE_AVAILABLE_WRITER, jz set_bad_mode

    ;// make sure we have a name

        CMPJMP [esi].file.filename_Writer, 0, je set_bad_mode   ;// skip if no name

    ;// open the writer

FILE_DEBUG_MESSAGE <"writer_Open\n">

        ;// locate the name, allow look elsewhere

        ;// if creating new file
        ;//     call build header
        ;//     set user data as ABox + version
        ;// open as not shareable
        ;// if can't open
        ;//     tell user some other process is using
        ;//     abort
        ;// if version is not ABox + version
        ;//     warn user that data will be overwritten
        ;//     if user says ok,
        ;//     build header
        ;//     otherwise, abort

        ;// set max size as available disk space
        ;// or 7FFFFFFFh, which ever is smaller


        mov ebx, [esi].file.filename_Writer
        ASSUME ebx:PTR FILENAME     ;// ebx must point at filename for subsequent functions
        mov eax, file_changing_name ;//
        invoke file_locate_name
        mov [esi].file.filename_Writer, ebx ;// store the (posibly) new name
        .IF eax ;// file already exists at said location

            invoke writer_OpenExisting  ;// and make sure we're allowed to mess with it
            TESTJMP eax, eax, jnz set_bad_mode

        .ELSE   ;// file doesn't exist

            invoke writer_CreateNew
            TESTJMP eax, eax, jnz set_bad_mode

        .ENDIF

    ;// set all flags as ok

        or [esi].dwUser,FILE_MODE_IS_WRITABLE   OR  \
                        FILE_MODE_IS_STEREO     OR  \
                        FILE_MODE_IS_REWINDONLY OR  \
                        FILE_MODE_IS_CALCABLE   OR  \
                        FILE_MODE_IS_NOREWIND

    ;// setup the format and length stuff

        mov [esi].file.fmt_rate, 44100
        mov [esi].file.fmt_bits, 16
        mov [esi].file.fmt_chan, 2
        mov [esi].file.max_length, 3FFFFFFFh

    comment ~ /*    no need to allocate buffers
    ;// allocate a buffer for storing prepared sample data
    ;// and a buffer for reading data
    ;// thats 2 for reading, 1 for preparing

        invoke memory_Alloc, GPTR, DATA_BUFFER_LENGTH*4 * 3
        mov [esi].file.buf.pointer, eax
    */ comment ~

    ;// then prepare for writting, also sets the length and position

        invoke writer_Prepare
        ;// has a return value
        DEBUG_IF <!!([esi].file.writer.dwFlags & WRITER_PREPARED)>  ;// supposed to be prepared !!

    ;// exit with good
    all_done:

        ret

    ALIGN 16
    set_bad_mode:

        mov eax, 1
        jmp all_done

writer_Open ENDP


;////////////////////////////////////////////////////////////////////////////////////////
;//
;//
;//     writer_Close


ASSUME_AND_ALIGN
writer_Close PROC USES ebx edi

    ;// ascend out of chunks
    ;// close the file
    ;// done

        ASSUME esi:PTR OSC_FILE_MAP

        mov eax, [esi].file.writer.hmmio
        .IF eax

        ;// invoke writer_Flush
        ;// do not flush at close, play stop does that for us

FILE_DEBUG_MESSAGE <"writer_Close\n">

            invoke mmioClose, [esi].file.writer.hmmio, 0
            mov [esi].file.writer.hmmio, 0

        ;// invoke memory_Free, [esi].file.buf.pointer
        ;// mov [esi].file.buf.pointer, eax

            mov [esi].file.file_position, eax
            and [esi].file.writer.dwFlags, NOT WRITER_PREPARED

        .ENDIF  ;// eax is zero

        and [esi].dwUser, NOT FILE_MODE_IS_CALCABLE

        ret

writer_Close ENDP



;////////////////////////////////////////////////////////////////////////////////////////
;//
;//
;//     writer_Flush

ASSUME_AND_ALIGN
writer_Flush PROC   USES ebx edi

    ;// we are to
    ;// ascend out of chuncks
    ;// and turn off the prepared bit

        ASSUME esi:PTR OSC_FILE_MAP                 ;// preserve

        DEBUG_IF <!![esi].file.writer.hmmio>    ;// not opened !!
        DEBUG_IF <!!([esi].file.writer.dwFlags & WRITER_PREPARED)>  ;// supposed to be prepared !!

FILE_DEBUG_MESSAGE <"writer_Flush\n">

        mov ebx, [esi].file.writer.hmmio    ;// file handle

        ;// finalize the file by ascending out of the chunks

        lea edi, [esi].file.writer.chunk_wave
        ASSUME edi:PTR MMCKINFO

        or [edi].dwFlags ,MMIO_DIRTY    ;// must set dirty of chunk size will be wrong
        invoke mmioAscend, ebx, edi, 0
        DEBUG_IF <eax>

        sub edi, SIZEOF MMCKINFO
        or [edi].dwFlags ,MMIO_DIRTY    ;// must sett dirty of chunk size will be wrong
        invoke mmioAscend, ebx, edi, 0
        DEBUG_IF <eax>

    ;// and turn off the prepared flag

        and [esi].file.writer.dwFlags, NOT WRITER_PREPARED

    ;// and we are done here

        ret

writer_Flush ENDP



;/////////////////////////////////////////////////////////////////////////////
;//
;//
;//     writer_Calc


ASSUME_AND_ALIGN
writer_Calc PROC STDCALL

;// trimmed down version of file_Calc_general

    ;// data pointers

        LOCAL s_trigger_pointer:DWORD   ;// ptr to seek input data
        LOCAL w_trigger_pointer:DWORD   ;// ptr to write trigger input data
        LOCAL A_data_pointer:DWORD      ;// ptr to sample rate input data

        LOCAL l_data_pointer:DWORD      ;// ptr to left input data
        LOCAL r_data_pointer:DWORD      ;// ptr to right input data

        LOCAL num_to_write:DWORD        ;// number of samples to write at end of calc

        LOCAL rewind_counter:DWORD      ;// prevent excessive seeking

        LOCAL int_s_prev:DWORD
        int_s_now   TEXTEQU <[esi].file.file_length>
        flt_s_prev  TEXTEQU <[esi].pin_Sout.dwUser>


        ASSUME esi:PTR OSC_FILE_MAP

    ;///////////////////////////////////////////////////////////////////////////////////
    ;//
    ;//
    ;//  CONFIGURE
    ;//

    ;// dwUser and changing flags

        mov edi, [esi].dwUser
        mov ebx, [esi].dwUser
        and edi, CALC_TEST

    ;// set up the file size output mechanism
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

    ;// load the rewind counter with the maximum

        FILE_MAX_WRITER_REWINDS EQU 16

        mov rewind_counter, FILE_MAX_WRITER_REWINDS

    ;// SEEK
    ;//
    ;//     p_trigger_pointer
    ;//     p_data_pointer

        xor eax, eax
        xor edx, edx

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

    ;// WRITE
    ;//
    ;//     w_trigger_pointer

        xor eax, eax
        xor edx, edx

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
            ASSUME ecx:PTR APIN
            .IF ecx
                mov ecx, [ecx].pData
            .ELSE
                mov ecx, math_pNull         ;// we know at this point that we have no input data
            .ENDIF
            mov l_data_pointer, ecx

            mov ecx, [esi].pin_Rin.pPin
            .IF ecx
                mov ecx, [ecx].pData
            .ELSE
                mov ecx, math_pNull ;// we know at this point that we have no input data
            .ENDIF
            mov r_data_pointer, ecx
            ASSUME ecx:NOTHING

    ;// A_data_pointer

        mov eax, [esi].pin_sr.pPin  ;// actually the A pin
        .IF eax
            mov eax, [eax].pData
        .ENDIF

        mov A_data_pointer, eax

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
        and num_to_write, ecx

    .REPEAT

    ;//////////////////////////////////////////////////////////////////////////////////
    ;//         this section must be hit to ensure that trigger input values are updated correctly
    ;// SEEK    task: rewind if seek trigger
    ;//
    ;//////////////////////////////////////////////////////////////////////////////////

    ;// ecx must enter as sample index
    ;// ebx must enter as dwUser
    ;// uses eax, edx

        BITTJMP ebx, CALC_ALL_SEEK,     jc s_are_triggered
        BITTJMP ebx, CALC_YES_SEEK,     jnc s_not_triggered
        BITRJMP ebx, CALC_ONE_SEEK,     jnc s_not_one_seek
        BITR ebx, CALC_YES_SEEK

    s_not_one_seek:     mov eax, s_trigger_pointer
                        DEBUG_IF <!!eax>    ;// supposed to be set to something
                        ASSUME eax:PTR DWORD

                        mov edx, [esi].pin_s.dwUser ;// last_s_data_pointer
                        mov eax, [eax+ecx*4]
                        mov [esi].pin_s.dwUser, eax ;// last_s_data_pointer, eax

        TESTJMP ebx, FILE_SEEK_GATE,        jz s_not_gate

    s_are_gate:     TESTJMP ebx, FILE_SEEK_POS,     jz s_neg_gate
    s_pos_gate:     TESTJMP eax, eax,       js s_not_triggered
                    jmp s_are_triggered
    ALIGN 16
    s_neg_gate:     TESTJMP eax, eax,       jns s_not_triggered
                    jmp s_are_triggered
    ALIGN 16
    s_not_gate:     TESTJMP ebx, FILE_SEEK_POS OR FILE_SEEK_NEG,jnz s_are_edge
    s_both_edge:    XORJMP eax, edx,        js s_are_triggered
                    jmp s_not_triggered
    ALIGN 16
    s_are_edge:     TESTJMP ebx, FILE_SEEK_POS,     jz s_neg_edge
    s_pos_edge:     TESTJMP edx, edx,       jns s_not_triggered
                    TESTJMP eax, eax,       jns s_are_triggered
                    jmp s_not_triggered
    ALIGN 16
    s_neg_edge:     TESTJMP edx, edx,       js s_not_triggered
                    TESTJMP eax, eax,       js s_are_triggered
                    jmp s_not_triggered
    ALIGN 16
    s_are_triggered:

        ;// we have a rewind trigger
        ;// if the file length is zero, don't bother

        or ebx, CALC_HAVE_SEEKED    ;// seek cancels write
        CMPJMP [esi].file.file_length, 0, je done_with_s_test
        DECJMP rewind_counter, js done_with_s_test
        push ecx
            invoke writer_Rewind
            mov num_to_write, 0
        pop ecx
        TESTJMP eax, eax, jnz bad_mode


    ALIGN 16
    s_not_triggered:
    done_with_s_test:


    ;//////////////////////////////////////////////////////////////////////////////////
    ;//         this section must be hit to ensure that trigger input values are updated correctly
    ;// WRITE   task: if triggered, move data from input to out temp buffers
    ;//
    ;//////////////////////////////////////////////////////////////////////////////////

    ;// ecx must enter as sample index
    ;// ebx must enter as dwUser
    ;// uses eax, edx

        BITRJMP ebx, CALC_HAVE_SEEKED,      jc w_seek_cancels_write
        BITTJMP ebx, CALC_ALL_WRITE,        jc w_are_triggered
        BITTJMP ebx, CALC_YES_WRITE,        jnc w_not_triggered
        BITRJMP ebx, CALC_ONE_WRITE,        jnc w_not_one_write
        BITR ebx, CALC_YES_WRITE

    w_not_one_write:

        mov eax, w_trigger_pointer
        DEBUG_IF <!!eax>    ;// supposed to be set to something

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
    w_seek_cancels_write:

        .IF ebx & CALC_ONE_WRITE
            and ebx, NOT (CALC_YES_WRITE OR CALC_ONE_WRITE)
        .ENDIF

        mov eax, w_trigger_pointer
        mov eax, [eax+ecx*4]
        mov [esi].pin_w.dwUser, eax ;// last_w_data_iterator, eax

        jmp w_not_triggered


    ALIGN 16
    w_are_triggered:

            mov edi, A_data_pointer
            mov eax, l_data_pointer
            mov edx, r_data_pointer
            .IF edi     ;// have an amplitude input

                fld DWORD PTR [edi]
                fld DWORD PTR [eax+ecx*4]   ;// L   A
                fmul st, st(1)
                fld DWORD PTR [edx+ecx*4]   ;// R   L   A
                fmulp st(2), st             ;// L   R

                mov edi, num_to_write

                fstp [esi].data_L[edi*4]
                fstp [esi].data_R[edi*4]

            .ELSE       ;// no amplitude input

                mov edi, num_to_write
                mov eax, [eax+ecx*4]
                mov edx, [edx+ecx*4]
                mov [esi].data_L[edi*4], eax
                mov [esi].data_R[edi*4], edx

            .ENDIF

            inc num_to_write
            inc [esi].file.file_length


    ALIGN 16
    w_not_triggered:
    done_with_w_test:

    ;/////////////////////////////////////////////////////////////////////////////
    ;//
    ;// FILE SIZE
    ;//
    ;/////////////////////////////////////////////////////////////////////////////

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
            test ebx, CALC_ALL_SEEK OR CALC_YES_SEEK OR CALC_ALL_WRITE OR CALC_YES_WRITE
            jz early_out

    .UNTIL ecx >= SAMARY_LENGTH

;////////////////////////////////////////////////////////////////////////////////////

;// CLEANUP

    ;// if we have samples to write, then write them
    calc_cleanup:

        .IF num_to_write

        ;// convert the stored data in L and R to words
        ;// bassed on stereo_float_to_stereo_16

            lea edi, [esi].data_P       ;// where we stored the values

            fld math_32767              ;// fpu must have scaling factor
            fnclex                      ;// must clear exceptions before we do this
            xor ecx, ecx
            .REPEAT
                                                ;// S
                fld [esi].data_L[ecx*4]         ;// L   S
                fmul st, st(1)                  ;// L   S
                fld [esi].data_R[ecx*4]         ;// R   L   S
                fmul st, st(2)                  ;// R   L   S
                fxch                            ;// L   R   S
                fistp WORD PTR [edi+ecx*4]      ;// R   S
                xor eax, eax
                fistp WORD PTR [edi+ecx*4+2]    ;// S
                fnstsw ax

                .IF ax & 1      ;// overflow
                    or [esi].dwUser, FILE_MODE_IS_CLIPPING
                    test [esi].data_L[ecx*4], 80000000h
                    fnclex
                    jnz @F
                    dec WORD PTR [edi+ecx*4]
                @@:
                    test [esi].data_R[ecx*4], 80000000h
                    jnz @F
                    dec WORD PTR [edi+ecx*4+2]
                @@:
                .ENDIF

                inc ecx

            .UNTIL ecx>=num_to_write

            fstp st

            ;// then write the now formatted data
            ;// ecx has the number of stereo samples
            ;// edi is where we stored it

            shl ecx, 2  ;// convert samples to stereo words
            invoke mmioWrite, [esi].file.writer.hmmio, edi, ecx

        .ENDIF

    ;// then make sure the position is correct
    ;// and we are done
    all_done:

        mov eax, [esi].file.file_length
        mov [esi].file.file_position, eax

        ret


    ALIGN 16
    bad_mode:

        ;// we could not reopen the file after a reset
        and [esi].dwUser, NOT FILE_MODE_IS_CALCABLE
        jmp all_done

    ALIGN 16
    early_out:

        ;// we have taken care of one input state
        ;// and determined we can abort early
        ;// we must copy the triggers for the next go around
        ;// and setup the file position

        mov eax, s_trigger_pointer
        mov edx, w_trigger_pointer
        mov eax, [eax+LAST_SAMPLE]
        mov edx, [edx+LAST_SAMPLE]
        mov [esi].pin_s.dwUser, eax
        mov [esi].pin_w.dwUser, edx

        lea edi, [esi].data_S
        mov eax, [edi]
        add edi, 4
        .IF [esi].pin_Sout.dwStatus & PIN_CHANGING || eax != [edi]
            and [esi].pin_Sout.dwStatus, NOT PIN_CHANGING
            mov ecx, SAMARY_LENGTH-1
            rep stosd
        .ENDIF

        jmp calc_cleanup




writer_Calc ENDP



ENDIF   ;// USE_THIS_FILE


ASSUME_AND_ALIGN

END



