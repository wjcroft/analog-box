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
;//     csv_writer.asm
;//
OPTION CASEMAP:NONE
.586
.MODEL FLAT


;// TOC
;// csvwriter_Initialize PROC
;// csvwriter_Destroy PROC
;// csvwriter_Open PROC
;// csvwriter_Close PROC USES ebx edi
;// csvwriter_CheckState PROC
;// csvwriter_GetBuffer PROC USES ecx ebx edi
;// csvwriter_Calc PROC STDCALL


USE_THIS_FILE equ 1

IFDEF USE_THIS_FILE

    .NOLIST
    INCLUDE <Abox.inc>
    INCLUDE <ABox_OscFile.inc>
    INCLUDE <szfloat.inc>
    .LIST


comment ~ /*

see CSV_WRITER_CALC for format description

    CSV comma separated variable

    inputs only

        old new description
        --- --- ----------------------
        L   V   data to written
        w   w   when to write the data
        s   r   rewind and truncate
        m   n   new line

    fairly straightforward operation
    we do not allow col row access, only serial

    we need to maintain a past value or two
    open the file as a normal windows file
    no need to buffer
        meaning there's no need to flush or prepare either
    do need text storage
    store values as 7 digit presicion scientific format
    try to align columns
    no gates on triggers


    number,number,number lf
    number,number,number lf etc


    how to calc this
    we have a w trigger to produce a new value
    we have a m trigger to create line feed

    we have no way of telling which m or w was triggered ....
    unless we replace the written value with some other value

    we can tell if both were triggered, file position will be +2

    we DO need a buffer because that's where calc writes to

    .....

    we'll need to do some xpiraments to determine the correct sequence of events




CSV_WRITER_CALC

we wish to store data in this format

        000000000011111         15 chars per value
        012345678901234          1 buffer for float values
        +#.######e+##,_         +4 buffers for max rendered text
        -         -  cl         =5 buffers to allocate for the DATA_BUFFER


*/ comment ~

    CSVWRITER_NUMBER_FORMAT EQU FLOATSZ_SCI \
                            OR FLOATSZ_DIG_7 \
                            OR FLOATSZ_LEADING_PLUS \
                            OR FLOATSZ_2_DIGIT_EXP \
                            OR FLOATSZ_WANT_0_EXP

.CODE

ASSUME_AND_ALIGN
csvwriter_Initialize PROC
csvwriter_Destroy PROC
        xor eax, eax    ;// mov eax, E_NOTIMPL
        ret
csvwriter_Destroy ENDP
csvwriter_Initialize ENDP







;////////////////////////////////////////////////////////////////////////////////////////
;//
;//
;//     csvwriter_Open


ASSUME_AND_ALIGN
csvwriter_Open PROC

;// verify that fie can be opened
;// set the osc_object capability flags
;// open the file
;// set the osc_object capability flags
;// set the format variables
;// determine the maximum size
;// return zero for sucess


        ASSUME esi:PTR OSC_FILE_MAP

    ;// make sure mode is available

        TESTJMP file_available_modes, FILE_AVAILABLE_CSVWRITER, jz set_bad_mode

    ;// make sure we have a name

        CMPJMP [esi].file.filename_CSVWriter, 0, je set_bad_mode    ;// skip if no name

    ;// open the writer

FILE_DEBUG_MESSAGE <"csvwriter_Open\n">

        ;// locate the name, allow look elsewhere

        ;// set max size as available disk space
        ;// or 7FFFFFFFh, which ever is smaller


        mov ebx, [esi].file.filename_CSVWriter
        ;//ASSUME ebx:PTR FILENAME  ;// ebx must point at filename for subsequent functions
        mov eax, file_changing_name ;//
        invoke file_locate_name
        mov [esi].file.filename_CSVWriter, ebx ;// store the (posibly) new name
        add ebx, FILENAME.szPath    ;// now it points at the filename we're about to access
        test eax, eax               ;// test the return value
        mov ecx, CREATE_ALWAYS      ;// load the default create flags
        .IF !ZERO?                  ;// file already exists at said location
            mov ecx, OPEN_EXISTING  ;// so we open the existing and leave it alone
        .ENDIF

    try_again:
        push ecx                    ;// need to preserve
        invoke CreateFileA,ebx,GENERIC_READ OR GENERIC_WRITE,FILE_SHARE_READ,0,ecx,0,0
        .IF eax == INVALID_HANDLE_VALUE

            invoke file_ask_retry, OFFSET sz_Text_space_Writer, [esi].file.filename_CSVWriter
            ;// returns one of IDRETRY, IDCANCEL
            pop ecx                 ;// retreive stored ecx
            CMPJMP eax, IDRETRY, je try_again
            jmp set_bad_mode        ;// otherwise we have an error

        .ENDIF
        pop ecx
        mov ebx, eax                        ;// now ebx is the file handle
        mov [esi].file.csvwriter.hFile, eax ;// and store in the object

    ;// set up the file position and length

        invoke csvreader_preparse, ebx  ;// gets eax=num_cols and edx=num_rows
        mul edx
        mov [esi].file.file_length, eax
        mov [esi].file.file_position, eax

        or [esi].file.csvwriter.dwFlags, FIRST_ON_LINE
ECHO <-- not nessesarily true !!

    ;// seek to the end

        invoke SetFilePointer, ebx, 0, 0, FILE_END

    ;// set all flags as ok

        or [esi].dwUser,FILE_MODE_IS_WRITABLE   OR  \
                        FILE_MODE_IS_REWINDONLY OR  \
                        FILE_MODE_IS_CALCABLE   OR  \
                        FILE_MODE_IS_MOVEABLE   OR  \
                        FILE_MODE_NO_GATES      OR  \
                        FILE_MODE_IS_NOREWIND

    ;// setup the format and length stuff

        mov [esi].file.fmt_rate, -1 ;// special flag for text
        ;//mov [esi].file.fmt_bits, 16
        ;//mov [esi].file.fmt_chan, 2
        mov [esi].file.max_length, 3FFFFFFFh

        ;//mov [esi].file.file_length, DATA_BUFFER_LENGTH

    ;// exit with good

        xor eax, eax

    all_done:

        ret

    ALIGN 16
    set_bad_mode:

        mov eax, 1
        jmp all_done

csvwriter_Open ENDP


;////////////////////////////////////////////////////////////////////////////////////////
;//
;//
;//     csvwriter_Close


ASSUME_AND_ALIGN
csvwriter_Close PROC USES ebx edi

        ASSUME esi:PTR OSC_FILE_MAP

        mov eax, [esi].file.csvwriter.hFile
        .IF eax

            invoke CloseHandle, eax
            mov [esi].file.csvwriter.hFile, 0
            mov [esi].file.file_position, eax
            mov [esi].file.file_length, eax

        .ENDIF  ;// eax is zero

        and [esi].dwUser, NOT FILE_MODE_IS_CALCABLE

        ret

csvwriter_Close ENDP


;////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////




ASSUME_AND_ALIGN
csvwriter_Calc PROC STDCALL

        ASSUME esi:PTR OSC_FILE_MAP

    ;// data pointers, buffers, and text equates

        LOCAL s_trigger_pointer:DWORD   ;// ptr to seek input data
        LOCAL w_trigger_pointer:DWORD   ;// ptr to write trigger input data
        LOCAL m_trigger_pointer:DWORD   ;// ptr to move trigger input data
        LOCAL l_data_pointer:DWORD      ;// ptr to left input data
        LOCAL text_buffer[32]:BYTE      ;// where we build text

        LOCAL int_s_prev:DWORD  ;// TEXTEQU <[esi].pin_s.dwUser>
        int_s_now   TEXTEQU <[esi].file.file_length>
        flt_s_prev  TEXTEQU <[esi].pin_Sout.dwUser>

        LOCAL seek_counter

;// pre checks

        CMPJMP [esi].file.csvwriter.hFile, 0, je all_done

;//  CONFIGURE

    ;// dwUser and changing flags

        mov edi, [esi].dwUser
        mov ebx, [esi].dwUser
        and edi, CALC_TEST

    ;// set up the file size output mechanism

        and [esi].pin_Sout.dwStatus, NOT PIN_CHANGING   ;// turn this off
        mov eax, int_s_now  ;// load the current file length
        fld1                ;// one is the default float length
        .IF eax             ;// if not zero
            fidiv int_s_now ;// then do the division
        .ENDIF
        mov int_s_prev, eax ;// store the current size as the old
        fstp flt_s_prev     ;// store the prev value as prev

    ;// set up the seek counter

        FILE_MAX_CSVWRITER_SEEKS EQU 16

        mov seek_counter, FILE_MAX_CSVWRITER_SEEKS

    ;// SEEK
    ;//
    ;//     p_trigger_pointer

        xor eax, eax

                OR_GET_PIN [esi].pin_s.pPin, eax
                jz SS_4                     ;// connected ?
                test [eax].dwStatus, PIN_CHANGING;// s is connected, changing?
                mov eax, [eax].pData        ;// s is connected, get the data pointer
                jz SS_1                     ;// changing ?
                or edi, CALC_YES_SEEK       ;// s is changing and connected
                jmp SS_6
        SS_4:   mov eax, math_pNull         ;// s is not connected
        SS_1:   or edi, CALC_ONE_SEEK OR CALC_YES_SEEK ;// not gate mode
        SS_6:   mov s_trigger_pointer, eax

    ;// WRITE
    ;//
    ;//     w_trigger_pointer

        xor eax, eax

                OR_GET_PIN [esi].pin_w.pPin, eax
                jz WW_4                     ;// connected ?
                test [eax].dwStatus, PIN_CHANGING;// w is connected, changing?
                mov eax, [eax].pData        ;// w is connected, get the data pointer
                jz WW_1                     ;// changing ?
                or edi, CALC_YES_WRITE      ;// w is changing and connected
                jmp WW_6
        WW_4:   mov eax, math_pNull         ;// w is not connected
        WW_1:   or edi, CALC_ONE_WRITE OR CALC_YES_WRITE ;// not gate mode
        WW_6:   mov w_trigger_pointer, eax

            mov ecx, [esi].pin_Lin.pPin
            .IF ecx
                mov ecx, (APIN PTR [ecx]).pData
            .ELSE
                mov ecx, math_pNull         ;// we know at this point that we have no input data
            .ENDIF
            mov l_data_pointer, ecx


    ;// MOVE
    ;//
    ;//     m_trigger_pointer

        xor eax, eax

                OR_GET_PIN [esi].pin_m.pPin, eax
                jz MM_4                     ;// connected ?
                test [eax].dwStatus, PIN_CHANGING;// m is connected, changing?
                mov eax, [eax].pData        ;// m is connected, get the data pointer
                jz MM_1                     ;// changing ?
                or edi, CALC_YES_MOVE       ;// m is changing and connected
                jmp MM_6
        MM_4:   mov eax, math_pNull         ;// m is not connected
        MM_1:   or edi, CALC_ONE_MOVE OR CALC_YES_MOVE ;// not gate mode
        MM_6:   mov m_trigger_pointer, eax

;//
;//
;//  CONFIGURE
;//
;///////////////////////////////////////////////////////////////////////////////////



                        ;// esi is osc map
        mov ebx, edi    ;// ebx is calc flags
                        ;// edi will be used as temp


;///////////////////////////////////////////////////////////////////////////////////
;//
;// CALC LOOP
;//


        xor ecx, ecx    ;// ecx counts,indexes

    .REPEAT


    ;//////////////////////////////////////////////////////////////////////////////////
    ;//         this section must be hit to ensure that trigger input values are updated correctly
    ;// SEEK    task: seek if triggered
    ;//
    ;//////////////////////////////////////////////////////////////////////////////////

    ;// ecx must enter as sample index
    ;// ebx must enter as dwUser
    ;// uses eax, edx

        BITTJMP ebx, CALC_YES_SEEK,     jnc s_not_triggered
        BITRJMP ebx, CALC_ONE_SEEK,     jnc s_not_one_seek
        BITR ebx, CALC_YES_SEEK

    s_not_one_seek:     mov eax, s_trigger_pointer
                        ASSUME eax:PTR DWORD
                        mov edx, [esi].pin_s.dwUser ;// last_s_data_pointer
                        mov eax, [eax+ecx*4]
                        mov [esi].pin_s.dwUser, eax ;// last_s_data_pointer, eax

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

        ;// REWIND,   close the file, delete it, recreate it, setup the buffers

            or ebx, CALC_HAVE_SEEKED    ;// seek cancels write and move
            CMPJMP [esi].file.file_length, 0, je done_with_s_test
            DECJMP seek_counter, js done_with_s_test

        push ecx
        push ebx

            invoke csvwriter_Close
            mov edi, [esi].file.filename_CSVWriter
            add edi, FILENAME.szPath
            invoke DeleteFileA, edi
            invoke csvwriter_Open

        pop ebx
        pop ecx

            TESTJMP eax, eax, jnz all_done  ;// abort if reopen failed

    ALIGN 16
    s_not_triggered:
    done_with_s_test:


    ;//////////////////////////////////////////////////////////////////////////////////
    ;//         this section must be hit to ensure that trigger input values are updated correctly
    ;// WRITE   task: if triggered, write data to file
    ;//
    ;//////////////////////////////////////////////////////////////////////////////////

    ;// ecx must enter as sample index
    ;// ebx must enter as dwUser
    ;// uses eax, edx, edi

        BITTJMP ebx, CALC_YES_WRITE,        jnc w_not_triggered
        BITRJMP ebx, CALC_ONE_WRITE,        jnc w_not_one_write
        BITR ebx, CALC_YES_WRITE

    w_not_one_write:

        mov eax, w_trigger_pointer
        mov edx, [esi].pin_w.dwUser ;// last_w_data_iterator
        mov eax, [eax+ecx*4]
        mov [esi].pin_w.dwUser, eax ;// last_w_data_iterator, eax

    w_not_gate: TESTJMP ebx, FILE_WRITE_POS OR FILE_WRITE_NEG,jnz w_are_edge
    w_both_edge:XORJMP eax, edx, js w_are_triggered
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

        TESTJMP ebx, CALC_HAVE_SEEKED, jnz w_not_triggered

        push ecx

            mov edx, l_data_pointer     ;// get the input pin pointer
            lea edi, text_buffer        ;// point at local text buffer
            fld DWORD PTR [edx+ecx*4]   ;// load the value to write

            BITR [esi].file.csvwriter.dwFlags, FIRST_ON_LINE
            .IF !CARRY?
                mov DWORD PTR [edi],' ,'
                add edi, 2
            .ENDIF

            mov edx, CSVWRITER_NUMBER_FORMAT
            invoke float_to_sz          ;// convert to text
            lea ecx, text_buffer        ;// outut buffer
            sub edi, ecx                ;// length
            invoke WriteFile, [esi].file.csvwriter.hFile, ecx, edi, esp, 0

        pop ecx

            inc [esi].file.file_position
            inc [esi].file.file_length

    ALIGN 16
    w_not_triggered:
    done_with_w_test:

    ;/////////////////////////////////////////////////////////////////////////////
    ;//         this section must be hit to ensure that trigger input values are updated correctly
    ;// MOVE    this is the linefeed trigger
    ;//
    ;/////////////////////////////////////////////////////////////////////////////

    ;// ecx must enter as sample index
    ;// ebx must enter as dwUser
    ;// uses eax, edx

        BITTJMP ebx, CALC_YES_MOVE,     jnc m_not_triggered
        BITRJMP ebx, CALC_ONE_MOVE,     jnc m_not_one_move
        BITR ebx, CALC_YES_MOVE

    m_not_one_move:

        mov eax, m_trigger_pointer
        mov edx, [esi].pin_m.dwUser ;// last_m_data_iterator
        mov eax, [eax+ecx*4]
        mov [esi].pin_m.dwUser, eax ;// last_m_data_iterator, eax

    m_not_gate:     TESTJMP ebx, FILE_MOVE_POS OR FILE_MOVE_NEG,jnz m_are_edge
    m_both_edge:    XORJMP eax, edx,        js m_are_triggered
                    jmp m_not_triggered
    ALIGN 16
    m_are_edge:     TESTJMP ebx, FILE_MOVE_POS,     jz m_neg_edge
    m_pos_edge:     TESTJMP edx, edx,       jns m_not_triggered
                    TESTJMP eax, eax,       jns m_are_triggered
                    jmp m_not_triggered
    ALIGN 16
    m_neg_edge:     TESTJMP edx, edx,       js m_not_triggered
                    TESTJMP eax, eax,       js m_are_triggered
                    jmp m_not_triggered
    ALIGN 16
    m_are_triggered:

        TESTJMP ebx, CALC_HAVE_SEEKED, jnz m_not_triggered

        mov edi, ecx    ;// must preserve

            pushd 0a0dh
            mov edx, esp
            invoke WriteFile,[esi].file.csvwriter.hFile,edx,2,esp,0
            add esp, 4

        mov ecx, edi

            or [esi].file.csvwriter.dwFlags, FIRST_ON_LINE

    ALIGN 16
    done_with_m_test:
    m_not_triggered:

    ;/////////////////////////////////////////////////////////////////////////////
    ;//
    ;// FILE SIZE
    ;//
    ;/////////////////////////////////////////////////////////////////////////////

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

    ;// ITERATE and check for one pass

            BITR ebx, CALC_HAVE_SEEKED  ;// turn this off

            inc ecx
            test ebx, CALC_YES_SEEK OR CALC_YES_WRITE OR CALC_YES_MOVE
            jz early_out

    .UNTIL ecx >= SAMARY_LENGTH

;//
;// CALC LOOP
;//
;///////////////////////////////////////////////////////////////////////////////////

    all_done:

        ret

    ALIGN 16
    early_out:

        ;// we only had to do one pass

        ;// copy the last trigger values

        mov eax, s_trigger_pointer
        mov edx, w_trigger_pointer
        mov ecx, m_trigger_pointer

        mov eax, [eax+LAST_SAMPLE]
        mov edx, [edx+LAST_SAMPLE]
        mov ecx, [ecx+LAST_SAMPLE]

        mov [esi].pin_s.dwUser, eax
        mov [esi].pin_w.dwUser, edx
        mov [esi].pin_m.dwUser, ecx

        ;// fill the remaining items in the S frame

        lea edi, [esi].data_S
        mov eax, [edi]
        BITRJMP [esi].pin_Sout.dwStatus, PIN_CHANGING, jc need_to_fill
        CMPJMP eax, [edi+4], je all_done
    need_to_fill:
        mov ecx, SAMARY_LENGTH-1
        add edi, 4
        rep stosd
        and [esi].pin_Sout.dwStatus, NOT PIN_CHANGING
        jmp all_done


csvwriter_Calc ENDP



ENDIF   ;// USE_THIS_FILE


ASSUME_AND_ALIGN

END



