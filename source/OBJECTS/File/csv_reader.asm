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
;//     csv_reader.asm
;//
OPTION CASEMAP:NONE
.586
.MODEL FLAT

;// TOC
;// csvreader_Initialize PROC
;// csvreader_Destroy PROC
;// csvreader_init_parse_buffer PROC
;// csvreader_get_next_buffer PROC
;// csvreader_consume PROC
;// csvreader_get_byte PROC
;// csvreader_preparse  PROC STDCALL hFile:DWORD
;// csvreader_loadparse PROC STDCALL hFile:DWORD, dwCols:DWORD, dwRows:DWORD
;// csvreader_ReadInputFile PROC
;// csvreader_Open PROC
;// csvreader_Close PROC USES ebx edi
;// csvreader_UpdateCRPins PROC STDCALL dwStart:DWORD
;// csvreader_Calc PROC




USE_THIS_FILE EQU 1

IFDEF USE_THIS_FILE


    .NOLIST
    INCLUDE <Abox.inc>
    INCLUDE <ABox_OscFile.inc>
    INCLUDE <szfloat.inc>
    .LIST



.CODE

ASSUME_AND_ALIGN
csvreader_Initialize PROC
csvreader_Destroy PROC
        xor eax, eax    ;// mov eax, E_NOTIMPL
        ret
csvreader_Destroy ENDP
csvreader_Initialize ENDP





;////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////
;//
;//
;//     PARSE BUFFER mechanism
;//
comment ~ /*

    we can share some common functionality
    between preparse and full parse
    to do that, we assign a PARSE_BUFFER and point ebp at it

    esi is the input pointer to the temporary input buffer
    eax is the input character at the buffer
    ebx is the input token code (described below)

    callers should preserve ebx between calls

    get_byte    -> eax  get the byte at esi
                -> ebx  determine thh input code
                does not advance anything

    consume     -> esi is advanced or rewound so that the next get_byte suceeds correctly
                does not read input data
                may call get_next_buffer and load from the file

    get_next_buffer

                -> caller can pre call this to intialize the input reader
                sets up esi as pointer to buffer
                may set end_of_file in PARSE_BUFFER

*/ comment ~

        PARSE_BUFFER_SIZE EQU 1024  ;// size in bytes

        PARSE_BUFFER STRUCT

            hFile           dd  0   ;// file handle, set by caller
            buffer_end      dd  0   ;// pointer to one passed end
            end_of_input    dd  0   ;// flag states that we have read the whole thing
            bytes_not_read  dd  0   ;// used by get_next_buffer to determine if last call was finished

            buffer  db PARSE_BUFFER_SIZE DUP (0)    ;// the buffer

        PARSE_BUFFER ENDS   ;// callers must point ebp at this struct

ASSUME_AND_ALIGN
csvreader_init_parse_buffer PROC

        ASSUME ebp:PTR PARSE_BUFFER
        ;// ebx must bethe file handle  (destroyed, stored in buffer)
        ;// calls get first buffer as well
        ;// returns esi as input buffer

        mov [ebp].hFile, ebx            ;// store the handle
        invoke SetFilePointer,ebx,0,0,FILE_BEGIN    ;// rewind to start

        xor eax, eax
        xor ebx, ebx

        mov [ebp].end_of_input, eax     ;// zero
        mov [ebp].bytes_not_read, ebx   ;// zero
        jmp csvreader_get_next_buffer   ;// go right to get next buffer

csvreader_init_parse_buffer ENDP


ASSUME_AND_ALIGN
csvreader_get_next_buffer PROC

        ASSUME ebp:PTR PARSE_BUFFER

        .IF ![ebp].bytes_not_read       ;// was last read sucessful ?

            lea esi, [ebp].buffer       ;// set up esi
            lea edx, [ebp].bytes_not_read
            invoke ReadFile,[ebp].hFile,esi,PARSE_BUFFER_SIZE, edx, 0

            mov eax, [ebp].bytes_not_read   ;// is actually bytes read
            sub [ebp].bytes_not_read, PARSE_BUFFER_SIZE ;// non zero for incomplete read
            add eax, esi    ;// end of buffer
            mov [ebp].buffer_end, eax

        all_done:

            retn

        ALIGN 16
        .ENDIF

        or [ebp].end_of_input, 1
        jmp all_done

csvreader_get_next_buffer ENDP


ASSUME_AND_ALIGN
csvreader_consume PROC

        ASSUME ebp:PTR PARSE_BUFFER

        ;// ebx must have the code from get byte

        inc esi     ;// advance

        CMPJMP esi, [ebp].buffer_end, jb buffer_ok
        invoke csvreader_get_next_buffer
        CMPJMP [ebp].end_of_input, 0, jne consume_done

    buffer_ok:

        CMPJMP ebx, 1, je consume_linefeed  ;// account for two character line feeds

    consume_done:

        retn

    ALIGN 16
    consume_linefeed:   ;// if char is 0Ah, then advance again

        CMPJMP BYTE PTR [esi], 0Ah, jne consume_done
        xor ebx, ebx            ;// clear ebx so we can jump to consume
        jmp csvreader_consume   ;// go back to start to consume the 0Ah

csvreader_consume ENDP

ASSUME_AND_ALIGN
csvreader_get_byte PROC

        ASSUME ebp:PTR PARSE_BUFFER

        xor eax, eax        ;// character
        xor ebx, ebx        ;// token code
        .IF ![ebp].end_of_input
            mov al, [esi]   ;// read the byte
            cmp al, ','
            ja ebx_is_4
            je ebx_is_3
            cmp al, 20h
            ja ebx_is_4
            je ebx_is_2
            cmp al, 09h
            jb ebx_is_4
            je ebx_is_2
            cmp al, 0Dh
            je ebx_is_1

        ebx_is_4:   inc ebx
        ebx_is_3:   inc ebx
        ebx_is_2:   inc ebx
        ebx_is_1:   inc ebx

        .ENDIF
        retn

csvreader_get_byte ENDP

;//
;//
;//     PARSE BUFFER mechanism
;//
;////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////









;////////////////////////////////////////////////////////////////////////////////////////
;//
;//                             given an open file handle
;//     csvreader_preparse      return the number of columns and rows
;//

    comment ~ /*

    tokens

        EOI     end of input        stated by GET_BYTE
        EOL     end of line         0Dh (0Ah)?              always inc num_rows
        SEP     a comma             ','
        WHT     space or tab        20h | 09h
        NUM     any other chars

    grammar

        table-> row (EOL row )* EOI     ;// a table consists of rows

        row  -> WHT* (fnum lnum*)?      ;// a row can be all white, empty, or contain numbers

        fnum -> NUM                     ;// first number can be a number (num_col=1)
             |  SEP WHT* NUM?           ;// or a separator (sets num_col to 2)

        lnum -> WHT+ NUM                ;// last numbers can be separated by white
             |  WHT* SEP WHT* NUM?      ;// or be separated by commas

    autonomaton nodes
    terminal nodes are capitalized, on enter they always consume the input
    rules are lower case and do not consume the input
    * indicates 'any other character'
    pass returns the carry flag set
    fail returns the carry flag clear

        fnum --S--> F1      F1 --N--> F2        F2 --N--> F2
             --N--> F2         --W--> F1           --*--> pass
             --*--> fail       --*--> pass


        lnum --W--> L1      L1 --W--> L1        L2 --W--> L2        L3 --N--> L3
             --S--> L2         --S--> L2           --N--> L3           --*--> pass
             --*--> fail       --N--> L3           --*--> pass
                               --*--> fail

    from the above, we see that F2==L3 and then F1=L2
    then we can rename them

        fnum --S--> S1                          N1 --N--> N1
             --N--> N1                             --*--> pass
             --*--> fail

        lnum --W--> L1      L1 --W--> L1        S1 --N--> N1
             --S--> S1         --S--> S1           --W--> S1
             --*--> fail       --N--> N1           --*--> pass
                               --*--> fail

    to get the 'row' rule working we create a wht W1 node
    and we create an eol rule

        wht --W--> W1       W1 --W--> W1
            --*--> pass        --*--> pass

        eol --0D-> E1       E1 --0A-> E2        E2 --*--> pass
            --*--> fail        --*--> pass


    now we should be able to implement the preparser

    we can do the above using jump tables
    if we assign token values
    here is our scheme
        0   EOI
        1   EOL
        2   WHT
        3   SEP
        4   NUM

    then a table is

        table_name, EOI, EOL, WHT, SEP, NUM

    */ comment ~

    ;// parser macros consume and get_byte

        CONSUME MACRO
            invoke csvreader_consume
            ENDM
        GET_BYTE MACRO
            invoke csvreader_get_byte
            ENDM

    ;// define a named jump table in the data segment

        JMP_TABLE MACRO name:REQ, EOI:REQ, EOL:REQ, WHT:REQ, SEP:REQ, NUM:REQ
            .DATA
            name&_jump_table dd EOI,EOL,WHT,SEP,NUM
            .CODE
            ENDM

    ;// autonomaton macros define jump tables and do the jump

        GET_AND_JUMP MACRO name:REQ, EOI:REQ, EOL:REQ, WHT:REQ, SEP:REQ, NUM:REQ
            JMP_TABLE name, EOI, EOL, WHT, SEP, NUM
            GET_BYTE
            jmp name&_jump_table[ebx*4]
            ENDM

        CONGET_AND_JUMP MACRO name:REQ, EOI:REQ, EOL:REQ, WHT:REQ, SEP:REQ, NUM:REQ
            JMP_TABLE name, EOI, EOL, WHT, SEP, NUM
            CONSUME
            GET_BYTE
            jmp name&_jump_table[ebx*4]
            ENDM





ASSUME_AND_ALIGN
PROLOGUE_OFF
csvreader_preparse  PROC STDCALL hFile:DWORD

    ;// returns eax=num_cols
    ;//         edx=num_rows

        xchg ebx, [esp+4]   ;// save and load
        push ebp    ;// must preserve
        push esi    ;// must preserve
        push edi    ;// must preserve

        xor eax, eax
        xor edx, edx

        push eax    ;// max_cols we've seen while parseing rows
        push edx    ;// num_rows so far in the table
        push eax    ;// num_cols in the row we're reading

        sub esp, SIZEOF PARSE_BUFFER

        mov ebp, esp

        st_num_cols     TEXTEQU <(DWORD PTR [ebp+00h+SIZEOF PARSE_BUFFER])>
        st_num_rows     TEXTEQU <(DWORD PTR [ebp+04h+SIZEOF PARSE_BUFFER])>
        st_max_cols     TEXTEQU <(DWORD PTR [ebp+08h+SIZEOF PARSE_BUFFER])>

        invoke csvreader_init_parse_buffer

        call pre_table              ;// do the parse

        add esp, SIZEOF PARSE_BUFFER + 4
        pop edx ;// num_rows
        pop eax ;// max_cols

        pop edi
        pop esi
        pop ebp
        mov ebx, [esp+4]
        retn 4  ;// STDCALL 1 ARG

    ;////////////////////////////////////////////////////

        pre_table:  call pre_row
                    adc st_num_rows, 0
                    mov eax, st_num_cols
                    .IF eax > st_max_cols
                        mov st_max_cols, eax
                    .ENDIF
                    mov st_num_cols, 0
                    CALLJMP pre_eol, jc pre_table   ;// if eol, read another row
                    jmp pre_pass

        pre_row:    call    pre_wht                 ;// consume leading white
                    CALLJMP pre_fnum,jnc pre_done   ;// must have fnum to be a row
        pre_R1:     inc st_num_cols                 ;// otherwise we increase the col count
                    CALLJMP pre_lnum,jc pre_R1      ;// if we pass, bump the count and go again
                    jmp pre_pass                    ;// otherwise we pass


        ;///////////////////////////////////////////////////////////////////
        ;// jmp tables and autonomaton

        pre_W1:     CONSUME
        ;//                         name    EOI      EOL      WHT    SEP      NUM
        pre_wht:    GET_AND_JUMP    pre_wht,pre_pass,pre_pass,pre_W1,pre_pass,pre_pass

        ;//                         name    EOI      EOL    WHT      SEP      NUM
        pre_eol:    GET_AND_JUMP    pre_eol,pre_fail,pre_E1,pre_fail,pre_fail,pre_fail
        pre_E1:     CONSUME
                    jmp pre_pass

        ;//                         name     EOI      EOL      WHT      SEP        NUM
        pre_fnum:   GET_AND_JUMP    pre_fnum,pre_fail,pre_fail,pre_fail,pre_S1_inc,pre_N1

        pre_S1_inc: inc st_num_cols
        ;//                         name   EOI      EOL      WHT    SEP      NUM
        pre_S1:     CONGET_AND_JUMP pre_S1,pre_pass,pre_pass,pre_S1,pre_pass,pre_N1

        ;//                         name   EOI      EOL      WHT      SEP      NUM
        pre_N1:     CONGET_AND_JUMP pre_N1,pre_pass,pre_pass,pre_pass,pre_pass,pre_N1

        ;//                         name     EOI      EOL      WHT    SEP    NUM
        pre_lnum:   GET_AND_JUMP    pre_lnum,pre_fail,pre_fail,pre_L1,pre_S1,pre_fail

        ;//                         name   EOI      EOL      WHT    SEP    NUM
        pre_L1:     CONGET_AND_JUMP pre_L1,pre_fail,pre_fail,pre_L1,pre_S1,pre_N1

        pre_pass:   stc
        pre_done:   retn
        pre_fail:   clc
                    jmp pre_done


csvreader_preparse  ENDP
PROLOGUE_ON


;//
;//     csvreader_preparse
;//
;////////////////////////////////////////////////////////////////////////////////////////




;////////////////////////////////////////////////////////////////////////////////////////
;//
;//                             uses same grammar as csvreader_preparse
;//     csvreader_loadparse     but with different actions
;//
comment ~ /*

    given
        a file handle,
        the number of columns
        the number of rows

    allocate the table data
    read and convert all the data from the csv file
    return the table ptr

*/ comment ~

ASSUME_AND_ALIGN
PROLOGUE_OFF
csvreader_loadparse PROC STDCALL hFile:DWORD, dwCols:DWORD, dwRows:DWORD

        xchg ebx, [esp+04h] ;// hFile
        xchg esi, [esp+08h] ;// num cols
        xchg edi, [esp+0Ch] ;// num rows
        push ebp            ;// must preserve

        NUM_BUFFER_SIZE EQU 64  ;// numbers loger than 63 chars are kludged

        mov eax, esi
        mul edi
        shl eax, 2  ;// number of dwords to allocate
        invoke memory_Alloc,GPTR,eax
        push eax    ;// data pointer
        xor edx, edx
        push esi    ;// num_cols
        push edi    ;// num_rows
        push edx    ;// cur_row
        push edx    ;// cur_col
        lea ecx, [esp-5]
        push ecx    ;// num_buffer_end points at last char
        sub esp, SIZEOF PARSE_BUFFER + NUM_BUFFER_SIZE
        mov ebp, esp

        st_data_pointer TEXTEQU <(DWORD PTR [ebp+14h+(SIZEOF PARSE_BUFFER)+NUM_BUFFER_SIZE])>
        st_num_cols     TEXTEQU <(DWORD PTR [ebp+10h+(SIZEOF PARSE_BUFFER)+NUM_BUFFER_SIZE])>
        st_num_rows     TEXTEQU <(DWORD PTR [ebp+0Ch+(SIZEOF PARSE_BUFFER)+NUM_BUFFER_SIZE])>
        st_cur_row      TEXTEQU <(DWORD PTR [ebp+08h+(SIZEOF PARSE_BUFFER)+NUM_BUFFER_SIZE])>
        st_cur_col      TEXTEQU <(DWORD PTR [ebp+04h+(SIZEOF PARSE_BUFFER)+NUM_BUFFER_SIZE])>
        st_num_buf_end  TEXTEQU <(DWORD PTR [ebp+00h+(SIZEOF PARSE_BUFFER)+NUM_BUFFER_SIZE])>
        st_num_buf      TEXTEQU <(BYTE PTR [ebp+(SIZEOF PARSE_BUFFER)])>
        st_parse_buf    TEXTEQU <(PARSE_BUFFER PTR [ebp])>

        ;// do the work

        invoke csvreader_init_parse_buffer

        lea edi, st_num_buf ;// edi must start at num buffer

        call lod_table

        ;// clean up and return

        add esp, (SIZEOF PARSE_BUFFER)+NUM_BUFFER_SIZE + 5*4
        pop eax ;// return value is the table pointer
        pop ebp
        mov ebx, [esp+04h]
        mov esi, [esp+08h]
        mov edi, [esp+0Ch]

        retn 3*4    ;// STDCALL 3 ARGS


    ;/////////////////////////////////////////////////////////////////////////////////////

        lod_table:  call lod_row
                    adc st_cur_row, 0       ;// advance current row
                    mov st_cur_col, 0       ;// reset cur column
                    CALLJMP lod_eol, jc lod_table   ;// if eol, read another row
                    jmp lod_pass

        lod_row:    call    lod_wht                 ;// consume leading white
                    CALLJMP lod_fnum,jnc lod_done   ;// must have fnum to be a row
        lod_R1:     inc     st_cur_col              ;// otherwise we increase the col count
                    CALLJMP lod_lnum,jc lod_R1      ;// if we pass, bump the count and go again
                    jmp     lod_pass                ;// otherwise we pass


        ;///////////////////////////////////////////////////////////////////
        ;// jmp tables and autonomaton

        ;//                         name    EOI      EOL      WHT    SEP      NUM
        lod_W1:     CONSUME
        lod_wht:    GET_AND_JUMP    lod_wht,lod_pass,lod_pass,lod_W1,lod_pass,lod_pass

        ;//                         name    EOI      EOL    WHT      SEP      NUM
        lod_eol:    GET_AND_JUMP    lod_eol,lod_fail,lod_E1,lod_fail,lod_fail,lod_fail
        lod_E1:     CONSUME
                    jmp lod_pass

        ;//                         name     EOI      EOL      WHT      SEP        NUM
        lod_fnum:   GET_AND_JUMP    lod_fnum,lod_fail,lod_fail,lod_fail,lod_S1_inc,lod_N1_cont

        lod_S1_inc: inc st_cur_col
        ;//                         name   EOI      EOL      WHT    SEP      NUM
        lod_S1:     CONGET_AND_JUMP lod_S1,lod_pass,lod_pass,lod_S1,lod_pass,lod_N1_cont


        lod_N1_cont:.IF edi < st_num_buf_end ;// check if the numb buffer pointer is beyond the end
                        stosb
                    .ENDIF
        ;//                         name        EOI         EOL         WHT         SEP         NUM
                    CONGET_AND_JUMP lod_N1_cont,lod_N1_done,lod_N1_done,lod_N1_done,lod_N1_done,lod_N1_cont

        lod_N1_done:
            ;// edi points past the last char, which is a valid store location
            ;// so we terminate it, then build the number
            xor eax, eax
            stosb                   ;// terminte with zero
            push esi                ;// have to preserve
            lea edi, st_num_buf     ;// reset for next go around
            mov esi, edi            ;// point at start of buffer
            invoke sz_to_float      ;// convert it
            pop esi                 ;// retrieve esi
            jc lod_pass             ;// sz_float returns carry as error, which we ignore
            ;// we have a value in the fpu
            ;// determine where to store it
            mov eax, st_cur_row
            mov ecx, st_cur_col
            .IF eax < st_num_rows && ecx < st_num_cols
                mul st_num_cols ;// row * cols
                add eax, ecx    ;// + col
                mov edx, st_data_pointer
                fstp DWORD PTR [edx+eax*4]
                jmp lod_pass
            .ENDIF
            fstp st ;// ignore values that fall out of table, have to empty the fpu
            jmp lod_pass

        ;//                         name     EOI      EOL      WHT    SEP    NUM
        lod_lnum:   GET_AND_JUMP    lod_lnum,lod_fail,lod_fail,lod_L1,lod_S1,lod_fail

        ;//                         name   EOI      EOL      WHT    SEP    NUM
        lod_L1:     CONGET_AND_JUMP lod_L1,lod_fail,lod_fail,lod_L1,lod_S1,lod_N1_cont

        lod_pass:   stc
        lod_done:   retn
        lod_fail:   clc
                    jmp lod_done

csvreader_loadparse ENDP
PROLOGUE_ON




ASSUME_AND_ALIGN
csvreader_ReadInputFile PROC

        ASSUME esi:PTR OSC_FILE_MAP

        push ebx    ;// should preserve

    ;// deallocate old first

        mov eax, [esi].file.csvreader.pData
        .IF eax
            invoke memory_Free, eax
            mov [esi].file.csvreader.pData, eax
        .ENDIF

    ;// open the file, allocate and load the table, close the file

        mov ebx, [esi].file.filename_CSVReader
        add ebx, FILENAME.szPath
        invoke CreateFileA,ebx,GENERIC_READ,FILE_SHARE_READ OR FILE_SHARE_WRITE, 0, OPEN_EXISTING, 0, 0
        CMPJMP eax, INVALID_HANDLE_VALUE, je set_bad_mode
        mov ebx, eax    ;// now ebx is a file handle

        invoke csvreader_preparse, ebx
        TESTJMP eax, eax, jz set_bad_mode_file  ;// must have a column
        TESTJMP edx, edx, jz set_bad_mode_file  ;// must have a row

        mov [esi].file.csvreader.num_cols, eax
        mov [esi].file.csvreader.num_rows, edx

        invoke csvreader_loadparse, ebx, eax, edx
        mov [esi].file.csvreader.pData, eax ;// store the data pointer

        invoke CloseHandle, ebx     ;// close the file, we're done with it

    ;// state that we need new values for the CR pins and exit with good

        or [esi].file.csvreader.dwFlags, CSVREADER_UPDATE_CR_PINS

        xor eax, eax

    all_done:

        pop ebx

        retn

    ALIGN 16
    set_bad_mode_file:
        invoke CloseHandle, ebx
    set_bad_mode:
        or eax, 1
        jmp all_done


csvreader_ReadInputFile ENDP



;////////////////////////////////////////////////////////////////////////////////////////
;//
;//
;//     csvreader_Open


ASSUME_AND_ALIGN
csvreader_Open PROC USES ebx

;// verify that fie can be opened
;// set the osc_object capability flags
;// open the file
;// set the osc_object capability flags
;// set the format variables
;// determine the number of columns and rows
;// allocate the buffers
;// load the data
;// return zero for sucess

        ASSUME esi:PTR OSC_FILE_MAP

    ;// make sure mode is available

        TESTJMP file_available_modes, FILE_AVAILABLE_WRITER, jz set_bad_mode

    ;// make sure we have a name

        CMPJMP [esi].file.filename_CSVReader, 0, je set_bad_mode    ;// skip if no name

    ;// open the writer

FILE_DEBUG_MESSAGE <"csvreader_Open\n">

        ;// locate the name, allow look elsewhere

        mov ebx, [esi].file.filename_CSVReader
        ASSUME ebx:PTR FILENAME     ;// ebx must point at filename for subsequent functions
        mov eax, file_changing_name ;//
        invoke file_locate_name
        mov [esi].file.filename_CSVReader, ebx  ;// store the (posibly) new name
        TESTJMP eax, eax, jz set_bad_mode       ;// can't read nothing

    ;// file exists at said location, read and load the table

        invoke csvreader_ReadInputFile
        TESTJMP eax, eax, jnz set_bad_mode

    ;// set all flags as ok

        or [esi].dwUser,FILE_MODE_IS_CALCABLE   OR  \
                        FILE_MODE_IS_READABLE   OR  \
                        FILE_MODE_IS_SEEKABLE   OR  \
                        FILE_MODE_IS_STEREO     OR  \
                        FILE_MODE_NO_GATES      OR  \
                        FILE_MODE_IS_NOREWIND

    ;// setup the format and length stuff

        mov [esi].file.fmt_rate, -1 ;// text
        ;//mov [esi].file.fmt_bits, 16
        ;//mov [esi].file.fmt_chan, 2
        mov [esi].file.max_length, 3FFFFFFFh


        mov eax, [esi].file.csvreader.num_cols
        imul eax, [esi].file.csvreader.num_rows
        mov [esi].file.file_length, eax

    ;// for this mode we do not allocate a sample buffer
    ;// instead we allocate allocate an address buffer

        invoke memory_Alloc, GMEM_FIXED, SAMARY_SIZE * 2
        mov [esi].file.csvreader.pAdressBuffer, eax

    ;// exit with good

        xor eax, eax

    all_done:

        ret

    ALIGN 16
    set_bad_mode:

        mov eax, 1
        jmp all_done


csvreader_Open ENDP


;////////////////////////////////////////////////////////////////////////////////////////
;//
;//
;//     csvreader_Close


ASSUME_AND_ALIGN
csvreader_Close PROC USES ebx edi

        ASSUME esi:PTR OSC_FILE_MAP

        mov eax, [esi].file.csvreader.pData
        .IF eax

FILE_DEBUG_MESSAGE <"csvreader_Close\n">

            invoke memory_Free, eax
            mov [esi].file.csvreader.pData, eax
            mov [esi].file.csvreader.num_rows, eax
            mov [esi].file.csvreader.num_cols, eax
            mov [esi].file.file_position, eax

        .ENDIF  ;// eax is zero
        mov eax, [esi].file.csvreader.pAdressBuffer
        .IF eax
            invoke memory_Free, eax
        .ENDIF
        and [esi].dwUser, NOT FILE_MODE_IS_CALCABLE
        ret

csvreader_Close ENDP




ASSUME_AND_ALIGN
PROLOGUE_OFF
csvreader_UpdateCRPins PROC STDCALL dwStart:DWORD

        ASSUME esi:PTR OSC_FILE_MAP

    ;// task: dwStart tells us where the new size was
    ;// we fill with new size until the end of the frame
    ;// if start is zero, then we are not changing
    ;// otherwise we scan for changing manually

        push edi    ;// must preserve
        sub esp, 4  ;// temp space

    ;// stack:  tmp edi ret start
    ;//         00  04  08  0Ch

    ;// data_P --> num columns

        fld1                    ;// 1
        .IF [esi].file.csvreader.num_cols       ;// make sure not zero
            fidiv [esi].file.csvreader.num_cols ;// divide to get what we store
        .ENDIF
        mov edx, [esp+0Ch]      ;// get the start index
        mov ecx, SAMARY_LENGTH  ;// max length
        sub ecx, edx            ;// subtract to get remaining
        lea edi, [esi].data_P[edx*4]    ;// point edi at start of store
        fstp DWORD PTR [esp]    ;// store in temp spot
        mov eax, [esp]          ;// load value to store
        rep stosd               ;// store it
        .IF edx                 ;// if we're not starting at zero
            mov ecx, edx        ;// load the number of dwords to check
            lea edi, [esi].data_P   ;// point at start of buffer
            repe scasd          ;// cmp until different
            je P_not_changing   ;// if last compare was equal, then we are not changing
            or [esi].pin_Pout.dwStatus, PIN_CHANGING    ;// otherwise we are changing
        .ELSE
        P_not_changing:
            and [esi].pin_Pout.dwStatus, NOT PIN_CHANGING
        .ENDIF

    ;// data_S --> num rows

        fld1                    ;// 1
        .IF [esi].file.csvreader.num_rows       ;// make sure not zero
            fidiv [esi].file.csvreader.num_rows ;// divide to get what we store
        .ENDIF
        mov edx, [esp+0Ch]      ;// get the start index
        mov ecx, SAMARY_LENGTH  ;// max length
        sub ecx, edx            ;// subtract to get remaining
        lea edi, [esi].data_S[edx*4]    ;// point edi at start of store
        fstp DWORD PTR [esp]    ;// store in temp spot
        mov eax, [esp]          ;// load value to store
        rep stosd               ;// store it
        .IF edx                 ;// if we're not starting at zero
            mov ecx, edx        ;// load the number of dwords to check
            lea edi, [esi].data_S   ;// point at start of buffer
            repe scasd          ;// cmp until different
            je S_not_changing   ;// if last compare was equal, then we are not changing
            or [esi].pin_Sout.dwStatus, PIN_CHANGING    ;// otherwise we are changing
        .ELSE
        S_not_changing:
            and [esi].pin_Sout.dwStatus, NOT PIN_CHANGING
        .ENDIF

    ;// and that's it

        add esp, 4  ;// done with temp value
        pop edi     ;// retrieve saved
        and [esi].file.csvreader.dwFlags, NOT CSVREADER_UPDATE_CR_PINS
        retn 4  ;// STDCALL 1 ARG

csvreader_UpdateCRPins ENDP
PROLOGUE_ON


comment ~ /*


full state

    dC  dR  dr  per  perc
    sC  sR  sr  ner  norm       48 modes
                ber

which we can reduce if we treat the re-read as a different beast

address calculation

    perc    adr = int( abs( C * num_cols ) ) + int( abs( R * num_rows ) ) * num_cols
    norm    adr = int( (C+1)/2 * num_cols ) + int( (R+1)/2 * num_rows ) * num_cols

    clip col and row to table boundaries
    can set clipping when they are hit

    so we should use two passes
    1) generate addresses
    2) get data and clip

    have to use a separate calc if rr is expected to be triggered

*/ comment ~


    ;// clip testing takes up a lot of space
    ;// here is a macro that does the job

    ;// oops -- old version not quite work -- removed

    ;// here is another version of clip test that checks the loop mode and wraps accordingly
    ;// we have also removed the clipping flag

    ;// reg has the value to test
    ;// src has the value to clip against
    ;// we assume that esi is pointing at OSC_FILE_MAP

    ;// CLIP_TEST is hit first
    ;// LOOP_TEST is hit from CLIP_TEST

    LOOP_JUMP_STYLE EQU 1   ;// 1= use a js command
                            ;// 2= use setns,dec,and,add
        ;// test reveal that the js version is faster !


    LOOP_TEST MACRO reg:REQ, src:REQ

            IFIDNI <eax>,<reg>
                push edx
            ELSEIFIDNI  <edx>,<reg>
                push eax
                mov eax, edx
            ELSE
                push eax
                push edx
                mov eax, reg
            ENDIF

                cdq                 ;// always sign extend
                idiv src            ;// divide position by length

            ;// check the sign of the results and wrap accordingly

            IF LOOP_JUMP_STYLE EQ 1
                test edx, edx       ;// check the sign
                .IF SIGN?           ;// jump if not neg
                    add edx, src    ;// otherwise add the length
                .ENDIF
            ELSEIF LOOP_JUMP_STYLE EQ 2
                ;// jumpless version of above
                xor eax, eax        ;// clear for setting
                test edx, edx       ;// check the sign
                setns al            ;// if positive, set eax=1
                dec eax             ;// if was neg, then eax now equals -1
                and eax, src        ;// and with the size, neg = size, pos = 0
                add edx, eax        ;// add to edx
            ELSE
                .ERR <LOOP_JUMP_STYLE not specified>
            ENDIF

            IFIDNI <eax>,<reg>
                mov eax, edx
                pop edx
            ELSEIFIDNI <edx>,<reg>
                pop eax
            ELSE
                mov reg, edx
                pop edx
                pop eax
            ENDIF

            ENDM



    CLIP_TEST MACRO reg:REQ, src:REQ, typ:REQ

        LOCAL _ready, _above, _loop

            IFIDNI <typ>,<NORM>

                    CMPJMP reg, src, jb _ready      ;// unsigned jump catches both over and under range
                    TESTJMP [esi].dwUser, FILE_MOVE_LOOP, jnz _loop
                    TESTJMP reg,reg, jns _above     ;// no sign goes to above
                    xor reg, reg        ;// yes sign floors at zero
                    jmp _ready
            _above: mov reg, src        ;// max+1
                    dec reg             ;// max
                    jmp _ready
            _loop:  LOOP_TEST reg,src   ;// we use another macro for this
            _ready:

            ELSEIFIDNI <typ>,<PERC>

                    CMPJMP reg, src, jb _ready
                    TESTJMP [esi].dwUser, FILE_MOVE_LOOP, jnz _loop
                    mov reg, src
                    dec reg
                    jmp _ready
            _loop:  LOOP_TEST reg,src   ;// we use another macro for this
            _ready:

            ELSE
                .ERR <use NORM or PERC>
            ENDIF

            ENDM









ASSUME_AND_ALIGN
csvreader_Calc PROC

        ASSUME esi:PTR OSC_FILE_MAP
        push ebp    ;// must preserve

        mov ebx, [esi].pin_Lin.pPin ;// col
        mov edi, [esi].pin_Rin.pPin ;// row
        mov ebp, [esi].pin_s.pPin   ;// rewind

        TESTJMP ebp, ebp, jz no_reread
        ASSUME ebp:PTR APIN
        test [ebp].dwStatus, PIN_CHANGING
        mov ebp, [ebp].pData        ;// get the data pointer
        ASSUME ebp:PTR DWORD
        jnz reread_                 ;// if changing then we do a full scan

    ;// we have a reread, but it is not changing
    ;// check for trigger accros frame

        mov eax, [esi].pin_s.dwUser ;// get the last trigger value
        mov ebp, [ebp]              ;// get the first value
        ASSUME ebp:NOTHING
        mov [esi].pin_s.dwUser, ebp ;// store back in pin

        TESTJMP [esi].dwUser, FILE_SEEK_POS, jnz sing_pos
        TESTJMP [esi].dwUser, FILE_SEEK_NEG, jnz sing_neg

    sing_both:  XORJMP eax, ebp, jns no_reread  ;// no trigger if signs are the same
                jmp sing_reread
    sing_pos:   TESTJMP eax, eax, jns no_reread ;// can't trigger if already pos
                TESTJMP ebp, ebp, js no_reread  ;// jump if didn't get a trigger
                jmp sing_reread
    sing_neg:   TESTJMP eax, eax, js no_reread  ;// can't trigger if already neg
                TESTJMP ebp, ebp, jns no_reread ;// jump if didn't get a trigger
    sing_reread:invoke csvreader_Close
                invoke csvreader_Open
                TESTJMP eax, eax, jnz set_bad_mode
                jmp no_reread

    ALIGN 16
    ASSUME ebp:PTR DWORD    ;// s input data
    ASSUME ebx:PTR APIN ;// C input, not checked yet
    ASSUME edi:PTR APIN ;// R input, not checked yet
    reread_:    ;// we have to do scans that account for rereading the table


            .IF [esi].file.csvreader.dwFlags & CSVREADER_UPDATE_CR_PINS \
            || [esi].pin_Pout.dwStatus & PIN_CHANGING   \
            || [esi].pin_Sout.dwStatus & PIN_CHANGING
                invoke csvreader_UpdateCRPins, 0
            .ENDIF

            .IF ebx
                mov ebx, [ebx].pData
            .ELSE
                mov ebx, math_pNull
            .ENDIF
            ASSUME ebx:PTR DWORD    ;// s input data
            .IF edi
                mov edi, [edi].pData
            .ELSE
                mov edi, math_pNull
            .ENDIF
            ASSUME edi:PTR DWORD

            fild [esi].file.csvreader.num_rows
            fild [esi].file.csvreader.num_cols  ;// cols    rows
            .IF [esi].dwUser & FILE_SEEK_NORM
                fld math_1_2
                fmul st(2), st
                fmul
            .ENDIF
            fld1        ;// one     cols/2  rows/2
            FILE_MAX_CSVREADER_SEEK EQU 16
            pushd FILE_MAX_CSVREADER_SEEK
            pushd -1    ;// to check prev value
            sub esp, 8  ;// make some temp space, row col prev seeks

            xor ecx, ecx
            .REPEAT

            ;// check the trigger
                mov eax, [ebp+ecx*4]        ;// load new value
                mov edx, [esi].pin_s.dwUser ;// load old value
                mov [esi].pin_s.dwUser, eax ;// store new value
                TESTJMP [esi].dwUser, FILE_SEEK_TEST, jnz reread_pos_neg
            reread_both:
                XORJMP eax, edx, js reread_got_trigger  ;// trigger if different sign
                jmp reread_process_input                ;// otherwise just skip
            reread_pos_neg:
                TESTJMP [esi].dwUser, FILE_SEEK_NEG, jz reread_pos
            reread_neg:
                TESTJMP eax, eax, js reread_process_input   ;// no trigger if already neg
                TESTJMP edx, edx, jns reread_process_input  ;// no trigger if still neg
                jmp reread_got_trigger                      ;// otherwise we have a trigger
            reread_pos:
                TESTJMP eax, eax, jns reread_process_input  ;// no trigger if already pos
                TESTJMP edx, edx, js reread_process_input   ;// no trigger if neg
            reread_got_trigger:

                dec DWORD PTR [esp+0Ch] ;// decrease the seek counter
                js reread_process_input ;// and do not seek if too many

                ;// do the re read

                fstp st
                push [esi].file.csvreader.num_cols
                fstp st
                push [esi].file.csvreader.num_rows
                fstp st
                push ecx
                invoke csvreader_Close
                invoke csvreader_Open
                test eax, eax   ;// check for now bad mode
                pop ecx
                pop edx ;// old num rows
                pop eax ;// old num cols
                jnz set_bad_mode_stack_16   ;// if reader could n't read, we are now bad
                .IF (eax != [esi].file.csvreader.num_cols) || (edx != [esi].file.csvreader.num_rows)
                    ;// one of the dimensions has changed
                    ;// so we have to update the CR pins
                    push ecx
                    invoke csvreader_UpdateCRPins, ecx
                    pop ecx
                .ENDIF
                fild [esi].file.csvreader.num_rows
                fild [esi].file.csvreader.num_cols  ;// cols    rows
                .IF [esi].dwUser & FILE_SEEK_NORM
                    fld math_1_2
                    fmul st(2), st
                    fmul
                .ENDIF
                fld1    ;// one     cols/2  rows/2
                and [esi].file.csvreader.dwFlags, NOT CSVREADER_UPDATE_CR_PINS

            ALIGN 16
            reread_process_input:
            ;// now we have valid num_col and num_row data

                fld [ebx+ecx*4]
                fld [edi+ecx*4]     ;// r       c       one     cols    rows
                .IF !([esi].dwUser & FILE_SEEK_NORM)
                    fabs            ;// r       c       one     cols    rows
                    fmul st, st(4)  ;// R       c       one     cols    rows
                    fxch            ;// c       R       one     cols    rows
                    fabs            ;// c       R       one     cols    rows
                    fmul st, st(3)  ;// C       R       one     cols    rows
                .ELSE
                    fadd st, st(2)  ;// r+1     C       one     cols    rows
                    fxch            ;// C       r+1     one     cols    rows
                    fadd st, st(2)  ;// c+1     r+1     one     cols    rows
                    fxch            ;// r+1     c+1     one     cols    rows
                    fmul st, st(4)  ;// R       c+1     one     cols    rows
                    fxch            ;// c+1     R       one     cols    rows
                    fmul st, st(3)  ;// C       R       one     cols    rows
                .ENDIF
                fxch            ;// R       C       one     cols    rows
                fistp DWORD PTR [esp]
                fistp DWORD PTR [esp+4]
                ;// stack   row col
                ;//         00  04
                mov eax, [esp]      ;// row
                mov edx, [esp+4]    ;// col
            ;// check the bounds of the row
                CLIP_TEST eax, [esi].file.csvreader.num_rows, NORM
            ;// multiply by num cols to get offset
                imul eax, [esi].file.csvreader.num_cols
            ;// check the bounds of the col
                CLIP_TEST edx, [esi].file.csvreader.num_cols, NORM
            ;// build the address and xfer the value
                add eax, edx
                mov [esi].file.file_position, eax
                shl eax, 2
                add eax, [esi].file.csvreader.pData
                mov eax, [eax]
                mov [esi].data_L[ecx*4], eax
            ;// check value against previous
                .IF eax != [esp+0Ch]
                    .IF DWORD PTR [esp+8] != -1
                        or [esi].pin_Lout.dwStatus, PIN_CHANGING
                    .ENDIF
                    mov [esp+8], eax
                .ENDIF

                inc ecx

            .UNTIL ecx >= SAMARY_LENGTH

            ;// complete success

            add esp, 16
            fstp st
            fstp st
            fstp st

            jmp all_done

        ALIGN 16
        set_bad_mode_stack_16:

            ;// we could not reread the file and we have 16 bytes on the stack
            add esp, 16

        set_bad_mode:

            invoke csvreader_Close
            jmp all_done


    ;//////////////////////////////////////////////////////////////////////////

    ALIGN 16
    no_reread:

        .IF [esi].file.csvreader.dwFlags & CSVREADER_UPDATE_CR_PINS \
        || [esi].pin_Pout.dwStatus & PIN_CHANGING   \
        || [esi].pin_Sout.dwStatus & PIN_CHANGING
            invoke csvreader_UpdateCRPins, 0
        .ENDIF
        mov edx, [esi].file.csvreader.pAdressBuffer ;// address buffer
        ASSUME edx:PTR DWORD
        xor ecx, ecx    ;// counter for pass one
        TESTJMP [esi].dwUser, FILE_SEEK_NORM, jnz norm_

    ;//////////////////////////////////////////////////////////////////////////

    ASSUME ebx:PTR APIN ;// C input
    ASSUME edi:PTR APIN ;// R input

    perc_:      TESTJMP ebx, ebx, jz perc_zC
    perc_yC:    test [ebx].dwStatus, PIN_CHANGING
                fild [esi].file.csvreader.num_cols
                mov ebx, [ebx].pData
                ASSUME ebx:PTR DWORD
                jnz perc_dC
    perc_sC:    fld [ebx]
                fabs
                fmul
                fistp [edx]
                mov ebx, [edx]
                ASSUME ebx:NOTHING
                CLIP_TEST ebx, [esi].file.csvreader.num_cols, PERC
    perc_zC:    TESTJMP edi, edi, jz perc_sC_zR ;// edi is already zero
    perc_sC_yR: test [edi].dwStatus, PIN_CHANGING
                fild [esi].file.csvreader.num_rows
                mov edi, [edi].pData
                ASSUME edi:PTR DWORD
                jnz perc_sC_dR
    perc_sC_sR: fld DWORD PTR [edi]
                fabs
                fmul
                fistp [edx]
                mov edi, [edx]
                ASSUME edi:NOTHING
                CLIP_TEST edi, [esi].file.csvreader.num_rows, PERC
    ;// ebx = C index
    ;// edi = R index
    ;// FPU = empty
    perc_sC_zR: ;// ebx and edi are set to the correct indexes and have been checked
    perc_sC_sR_loop:

                jmp pass2_sC_sR


    ALIGN 16
    ASSUME ebx:NOTHING      ;// ebx = C index
    ASSUME edi:PTR DWORD    ;// edi = R input data
    ;// FPU = num_rows
    perc_sC_dR:
    perc_sC_dR_loop:

            .REPEAT
                fld [edi+ecx*4]     ;// R   num_rows
                fabs
                fmul st, st(1)
                fistp [edx+ecx*4]
                inc ecx
            .UNTIL ecx >= SAMARY_LENGTH
            fstp st ;// empty
            jmp pass2_sC_dR


    ;// ebx = R input data, FPU = num_cols
    ALIGN 16
    ASSUME edi:PTR APIN ;// R input pin
    perc_dC:    TESTJMP edi, edi, jz perc_dC_zR
    perc_dC_yR: fild [esi].file.csvreader.num_rows
                test [edi].dwStatus, PIN_CHANGING
                mov edi, [edi].pData
                ASSUME edi:PTR DWORD
                jnz perc_dC_dR
    perc_dC_sR: fld DWORD PTR [edi]
                fabs
                fmul
                fistp [edx]
                mov edi, [edx]
                CLIP_TEST edi, [esi].file.csvreader.num_rows, PERC

    ASSUME ebx:PTR DWORD    ;// ebx = C input data
    ASSUME edi:NOTHING      ;// edi = R index
    ;// fpu = num_cols
    perc_dC_zR:
    perc_dC_sR_loop:

            .REPEAT
                fld [ebx+ecx*4]     ;// C   num_cols
                fabs
                fmul st, st(1)
                fistp [edx+ecx*4]
                inc ecx
            .UNTIL ecx >= SAMARY_LENGTH
            fstp st ;// empty
            jmp pass2_dC_sR

    ALIGN 16
    ASSUME ebx:PTR DWORD    ;// ebx = C input data
    ASSUME edi:PTR DWORD    ;// edi = R input data
    ;// FPU = num_rows num_cols
    perc_dC_dR:
    perc_dC_dR_loop:
            .REPEAT

                fld [ebx+ecx*4]     ;// C   num_rows    num_cols
                fabs
                fmul st, st(2)      ;// cc  num_rows    num_cols
                fld [edi+ecx*4]     ;// R   cc          num_rows    num_cols
                fabs
                fmul st, st(2)      ;// rr  cc          num_rows    num_cols

                fxch
                fistp [edx+ecx*8]
                fistp [edx+ecx*8+4]

                inc ecx

            .UNTIL ecx >= SAMARY_LENGTH
            fstp st
            fstp st
            jmp pass2_dC_dR


    ;//////////////////////////////////////////////////////////////////////////
    ALIGN 16
    ASSUME ebx:PTR APIN ;// C input
    ASSUME edi:PTR APIN ;// R input

    norm_:      TESTJMP ebx, ebx, jz norm_zC
    norm_yC:    test [ebx].dwStatus, PIN_CHANGING
                fild [esi].file.csvreader.num_cols
                mov ebx, [ebx].pData
                ASSUME ebx:PTR DWORD
                fmul math_1_2
                fld1
                jnz norm_dC
    norm_sC:    fadd DWORD PTR [ebx]
                fmul
                fistp [edx]
                mov ebx, [edx]
                CLIP_TEST ebx, [esi].file.csvreader.num_cols, NORM
    norm_zC:    TESTJMP edi, edi, jz norm_sC_zR ;// edi is already zero
    norm_sC_yR: test [edi].dwStatus, PIN_CHANGING
                fild [esi].file.csvreader.num_rows
                mov edi, [edi].pData
                ASSUME edi:PTR DWORD
                fmul math_1_2
                fld1
                jnz norm_sC_dR
    norm_sC_sR: fadd [edi]
                fmul
                fistp [edx]
                mov edi, [edx]
                ASSUME edi:NOTHING
                CLIP_TEST edi, [esi].file.csvreader.num_rows, NORM

    ASSUME ebx:NOTHING  ;// ebx = C index
    ASSUME edi:NOTHING  ;// edi = R index
    ;// FPU = empty
    norm_sC_zR: ;// ebx and edi are set to the correct indexes and have been checked
    norm_sC_sR_loop:

                jmp pass2_sC_sR


    ALIGN 16
    ASSUME ebx:NOTHING      ;// ebx = C index
    ASSUME edi:PTR DWORD    ;// edi = R input data
    ;// FPU = one   num_rows/2
    norm_sC_dR:
    norm_sC_dR_loop:

            .REPEAT
                fld [edi+ecx*4]     ;// R   one     num_rows/2
                fadd st, st(1)
                fmul st, st(2)
                fistp [edx+ecx*4]
                inc ecx
            .UNTIL ecx >= SAMARY_LENGTH
            fstp st
            fstp st
            jmp pass2_sC_dR

    ALIGN 16
    ASSUME ebx:PTR DWORD;// ebx = R input data, FPU = num_cols
    ASSUME edi:PTR APIN ;// R input pin
    norm_dC:    TESTJMP edi, edi, jz norm_dC_zR
    norm_dC_yR: fild [esi].file.csvreader.num_rows
                test [edi].dwStatus, PIN_CHANGING
                mov edi, [edi].pData
                ASSUME edi:PTR DWORD
                fmul math_1_2
                fld1
                jnz norm_dC_dR
    norm_dC_sR: fadd DWORD PTR [edi]
                fmul
                fistp [edx]
                mov edi, [edx]
                CLIP_TEST edi, [esi].file.csvreader.num_rows, NORM

    ASSUME ebx:PTR DWORD    ;// ebx = C input data
    ASSUME edi:NOTHING      ;// edi = R index
    ;// fpu = one   num_cols/2
    norm_dC_zR:
    norm_dC_sR_loop:

            .REPEAT
                fld [ebx+ecx*4]     ;// C   one     num_cols/2
                fadd st, st(1)
                fmul st, st(2)
                fistp [edx+ecx*4]
                inc ecx
            .UNTIL ecx >= SAMARY_LENGTH
            fstp st
            fstp st
            jmp pass2_dC_sR


    ALIGN 16
    ASSUME ebx:PTR DWORD    ;// ebx = C input data
    ASSUME edi:PTR DWORD    ;// edi = R input data
    ;// FPU = one   num_rows/2 one  num_cols/2
    norm_dC_dR:
    norm_dC_dR_loop:

            .REPEAT
                fld [ebx+ecx*4]     ;// C   one num_rows/2 one  num_cols/2
                fadd st, st(3)
                fld [edi+ecx*4]     ;// R   C+1 one num_rows/2 one  num_cols/2
                fadd st, st(2)
                fxch                ;// C+1 R+1 one num_rows/2 one  num_cols/2
                fmul st, st(5)      ;// cc  R+1 one num_rows/2 one  num_cols/2
                fxch                ;// R+1 cc  one num_rows/2 one  num_cols/2
                fmul st, st(3)      ;// rr  cc  one num_rows/2 one  num_cols/2
                fxch                ;// cc  rr  ...

                fistp [edx+ecx*8]
                fistp [edx+ecx*8+4]

                inc ecx

            .UNTIL ECX >= SAMARY_LENGTH
            fstp st
            fstp st
            fstp st
            fstp st
            jmp pass2_dC_dR


    ;//////////////////////////////////////////////////////////////////////////


    ALIGN 16
    pass2_sC_sR:
    ;// ebx = C index
    ;// edi = R index

            imul edi, [esi].file.csvreader.num_cols
            mov edx, [esi].file.csvreader.pData
            add ebx, edi
            mov eax, [edx+ebx*4]    ;// get the data
            mov [esi].file.file_position, ebx
            .IF eax != [esi].data_L || [esi].pin_Lout.dwStatus & PIN_CHANGING
                lea edi, [esi].data_L
                mov ecx, SAMARY_LENGTH
                rep stosd
                and [esi].pin_Lout.dwStatus, NOT PIN_CHANGING
            .ENDIF
            jmp all_done


    ALIGN 16
    pass2_sC_dR:
    ;// ebx = C index
    ;// edx points at R indexes

        mov edi, [esi].file.csvreader.pData
        ASSUME edi:PTR DWORD
        pushd -1    ;// use as a changing data tracker
        xor ecx, ecx
        .REPEAT
            mov eax, [edx+ecx*4]
            CLIP_TEST eax, [esi].file.csvreader.num_rows, NORM
            imul eax, [esi].file.csvreader.num_cols
            add eax, ebx
            mov [esi].file.file_position, eax
            mov eax, [edi+eax*4]            ;// get the data
            mov [esi].data_L[ecx*4], eax    ;// storeteh data
            .IF eax != [esp]        ;// compare with previously stored
                .IF DWORD PTR [esp] != -1
                    or [esi].pin_Lout.dwStatus, PIN_CHANGING
                .ENDIF
                mov [esp], eax
            .ENDIF
            inc ecx
        .UNTIL ecx>=SAMARY_LENGTH
        add esp, 4
        jmp all_done

    ALIGN 16
    pass2_dC_sR:
    ;// edi = R index
    ;// edx points at C indexes

        mov ebx, [esi].file.csvreader.pData
        ASSUME ebx:PTR DWORD
        pushd -1    ;// use as a changing data tracker
        xor ecx, ecx
        imul edi, [esi].file.csvreader.num_cols
        .REPEAT
            mov eax, [edx+ecx*4]
            CLIP_TEST eax, [esi].file.csvreader.num_cols, NORM
            add eax, edi
            mov [esi].file.file_position, eax
            mov eax, [ebx+eax*4]            ;// get the data
            mov [esi].data_L[ecx*4], eax    ;// store the data
            .IF eax != [esp]        ;// compare with previously stored
                .IF DWORD PTR [esp] != -1
                    or [esi].pin_Lout.dwStatus, PIN_CHANGING
                .ENDIF
                mov [esp], eax
            .ENDIF
            inc ecx
        .UNTIL ecx>=SAMARY_LENGTH
        add esp, 4
        jmp all_done

    ALIGN 16
    pass2_dC_dR:
    ;// edx points at C,R indexes

        mov ebx, [esi].file.csvreader.pData
        ASSUME ebx:PTR DWORD
        pushd -1    ;// use as a changing data tracker
        xor ecx, ecx
        .REPEAT
            mov eax, [edx+ecx*8]    ;// col
            CLIP_TEST eax, [esi].file.csvreader.num_cols, NORM
            mov edi, [edx+ecx*8+4]  ;// row
            CLIP_TEST edi, [esi].file.csvreader.num_rows, NORM
            imul edi, [esi].file.csvreader.num_cols

            add eax, edi
            mov [esi].file.file_position, eax
            mov eax, [ebx+eax*4]            ;// get the data
            mov [esi].data_L[ecx*4], eax    ;// store the data
            .IF eax != [esp]        ;// compare with previously stored
                .IF DWORD PTR [esp] != -1
                    or [esi].pin_Lout.dwStatus, PIN_CHANGING
                .ENDIF
                mov [esp], eax
            .ENDIF
            inc ecx
        .UNTIL ecx>=SAMARY_LENGTH
        add esp, 4
        jmp all_done


    ALIGN 16
    all_done:

        pop ebp

        ret


csvreader_Calc ENDP


ENDIF   ;// USE_THIS_FILE


ASSUME_AND_ALIGN

END



