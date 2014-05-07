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
;//     ABOX242 AJT -- detabified + text adjustments for 'lines too long' errors
;//
;//##////////////////////////////////////////////////////////////////////////
;//                         the new file object
;// ABox_OscFile.asm
;//
;//
;// TOC
;//

;// file_locate_name
;// file_ask_retry

;// file_VerifyPins

;// file_InitializeModes
;// file_DestroyModes
;// file_OpenMode
;// file_CloseMode

;// file_InitMenu
;// file_parse_edit_size
;// file_parse_edit_id
;// file_Command
;// file_Render

;// file_Ctor
;// file_Dtor
;// file_AddExtraSize
;// file_Write
;// file_SaveUndo
;// file_LoadUndo

;// file_GetUnit

;// file_Calc and file_PrePlay are in file_calc.asm




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

;///////////////////////////////////////////////////////////////////////

;// osc base

osc_File    OSC_CORE { file_Ctor,file_Dtor,file_PrePlay,file_Calc }
            OSC_GUI  { file_Render,,,,,file_Command,file_InitMenu,file_Write,file_AddExtraSize,file_SaveUndo,file_LoadUndo, file_GetUnit}
            OSC_HARD { file_H_Ctor,file_H_Dtor,file_H_Open,file_H_Close, file_H_Ready, file_H_Calc }

    BASE_FLAGS = BASE_PLAYABLE OR BASE_NO_WAIT OR BASE_WANT_EDIT_FOCUS_MSG

    ;// don't make lines too long
    ofsPinData  = SIZEOF OSC_OBJECT + (SIZEOF APIN)*11
    ofsOscData  = SIZEOF OSC_OBJECT + (SIZEOF APIN)*11 + SAMARY_SIZE*4
    oscBytes    = SIZEOF OSC_OBJECT + (SIZEOF APIN)*11 + SAMARY_SIZE*4 + SIZEOF OSC_FILE_DATA
    
    OSC_DATA_LAYOUT {NEXT_File,IDB_FILE,OFFSET popup_FILE, BASE_FLAGS,
        11,4,
        ofsPinData,
        ofsOscData,
        oscBytes  }

    OSC_DISPLAY_LAYOUT { devices_container, DISK_PSOURCE, ICON_LAYOUT( 6,4,2,3)}

;// labels are needed by xlate_convert_file

        EXTERNDEF   osc_File_pin_Li:APIN_init
        EXTERNDEF   osc_File_pin_Ri:APIN_init
        EXTERNDEF   osc_File_pin_w:APIN_init
        EXTERNDEF   osc_File_pin_sr:APIN_init
        EXTERNDEF   osc_File_pin_m:APIN_init
        EXTERNDEF   osc_File_pin_s:APIN_init
        EXTERNDEF   osc_File_pin_P:APIN_init
        EXTERNDEF   osc_File_pin_Lo:APIN_init
        EXTERNDEF   osc_File_pin_Ro:APIN_init
        EXTERNDEF   osc_File_pin_Po:APIN_init   ;// ADDED ABOX232
        EXTERNDEF   osc_File_pin_So:APIN_init   ;// ADDED ABOX234

osc_File_pin_Li APIN_init {-0.85,OFFSET sz_Left     ,'L',,UNIT_AUTO_UNIT }
osc_File_pin_Ri APIN_init {-1.0 ,OFFSET sz_Right    ,'R',,UNIT_AUTO_UNIT }
osc_File_pin_w  APIN_init {+0.85,OFFSET sz_Write    ,'w',,PIN_LOGIC_INPUT OR UNIT_LOGIC }
osc_File_pin_sr APIN_init {-0.4 ,OFFSET sz_SampleRate,'rs',,UNIT_2xHERTZ }
osc_File_pin_m  APIN_init {-0.6 ,OFFSET sz_Move     ,'m',,PIN_LOGIC_INPUT OR UNIT_LOGIC }
osc_File_pin_s  APIN_init {+0.6 ,OFFSET sz_Seek     ,'s',,PIN_LOGIC_INPUT OR UNIT_LOGIC }
osc_File_pin_P  APIN_init {+0.4 ,OFFSET sz_SeekPosition ,'P',,UNIT_VALUE }
osc_File_pin_Lo APIN_init {-0.16,OFFSET sz_Left     ,'L',,PIN_OUTPUT OR UNIT_AUTO_UNIT }
osc_File_pin_Ro APIN_init {-0.06,OFFSET sz_Right    ,'R',,PIN_OUTPUT OR UNIT_AUTO_UNIT }
osc_File_pin_Po APIN_init { 0.06,OFFSET sz_CurrentPosition ,'P',,PIN_OUTPUT OR UNIT_AUTO_UNIT } ;//added ABOX232
osc_File_pin_So APIN_init { 0.16,OFFSET sz_FileSize ,'S',,PIN_OUTPUT OR UNIT_AUTO_UNIT } ;//added ABOX234

    short_name  db  'File',0
    description db  'This device can read and write files in a variety of formats, '
                db  'or can be used as a shared memory buffer.',0
    ALIGN 4

;// pin descriptions ... this object is diverse enough to warrant a general purpose table

    PIN_DESCRIPTOR STRUCT
        pShortName  dd  0
        pLongName   dd  0
        unit        dd  0
        dwFlags     dd  0
    PIN_DESCRIPTOR ENDS

    font_table_norm LABEL DWORD
    ;// first value converted to a font_shape ptr
    ;// second value used for the LName
    ;// third value is the units
    ;// fourth value is an optional test flag for dwUser
        fnt_A   dd  'A' ,   sz_Amplitude    ,UNIT_DB        ,0
        fnt_sr  dd  'rs',   sz_SampleRate   ,UNIT_2xHERTZ   ,0
        fnt_co  dd  'oc',   sz_Column       ,UNIT_VALUE     ,0
        fnt_ro  dd  'or',   sz_Row          ,UNIT_VALUE     ,0
        fnt_w   dd  'w' ,   sz_Write        ,UNIT_LOGIC     ,FILE_WRITE_TEST OR FILE_WRITE_GATE OR FILE_MODE_IS_WRITABLE
        fnt_m   dd  'm' ,   sz_Move         ,UNIT_LOGIC     ,FILE_MOVE_TEST OR FILE_MOVE_GATE
        fnt_s   dd  's' ,   sz_Seek         ,UNIT_LOGIC     ,FILE_SEEK_TEST OR FILE_SEEK_GATE
        fnt_P   dd  'P' ,   sz_SeekPosition ,UNIT_VALUE     ,0
        fnt_er  dd  're',   sz_Erase        ,UNIT_LOGIC     ,FILE_SEEK_TEST OR FILE_SEEK_GATE
        fnt_in  dd  'ni',   sz_Data         ,UNIT_AUTO_UNIT ,FILE_MODE_IS_WRITABLE
        fnt_L   dd  'L' ,   sz_Left         ,UNIT_AUTO_UNIT ,FILE_MODE_IS_WRITABLE
        fnt_R   dd  'R' ,   sz_Right        ,UNIT_AUTO_UNIT ,FILE_MODE_IS_WRITABLE
        fnt_nc  dd  'cn',   sz_NextColumn   ,UNIT_LOGIC     ,FILE_WRITE_TEST OR FILE_WRITE_GATE
        fnt_nr  dd  'rn',   sz_NextRow      ,UNIT_LOGIC     ,FILE_MOVE_TEST OR FILE_MOVE_GATE
        fnt_rr  dd  'rr',   sz_ReRead       ,UNIT_LOGIC     ,FILE_SEEK_TEST OR FILE_SEEK_GATE
        dd 0
    font_table_bold LABEL DWORD
        fnt_eq_ dd  '=',    sz_Data         ,UNIT_AUTO_UNIT ,0
        fnt_L_  dd  'L',    sz_Left         ,UNIT_AUTO_UNIT ,0
        fnt_R_  dd  'R',    sz_Right        ,UNIT_AUTO_UNIT ,FILE_MODE_IS_STEREO
        fnt_P_  dd  'P',    sz_CurrentPosition  ,UNIT_AUTO_UNIT ,0
        fnt_S_  dd  'S',    sz_FileSize     ,UNIT_VALUE     ,0
        fnt_co_ dd  'C',    sz_NumColumn    ,UNIT_VALUE     ,0
        fnt_ro_ dd  'R',    sz_NumRow       ,UNIT_VALUE     ,0
        dd  0   ;// end of list


NUM_PIN_MODES   EQU 11
;//             inputs                                                  outputs
;//             left    right   write   rate    move    seek    pos     left    right   pos     size
;// bad
pin_mode_0  dd  0,      0,      0,      0,      0,      0,      0,      0,      0,      0,      0
;// data file
pin_mode_1  dd  fnt_in, 0,      fnt_w,  fnt_sr, fnt_m,  fnt_s,  fnt_P,  fnt_eq_,0,      fnt_P_, fnt_S_
;// memory buffer
pin_mode_2  dd  fnt_in, 0,      fnt_w,  fnt_sr, fnt_m,  fnt_s,  fnt_P,  fnt_eq_,0,      fnt_P_, fnt_S_
;// media reader
pin_mode_3  dd  0,      0,      0,      fnt_sr, fnt_m,  fnt_s,  fnt_P,  fnt_L_, fnt_R_, fnt_P_, fnt_S_
;// wave writer
pin_mode_4  dd  fnt_L,  fnt_R,  fnt_w,  fnt_A,  0,      fnt_er, 0,      0,      0,      0,      fnt_S_
;// text reader
pin_mode_5  dd  fnt_co, fnt_ro, 0,      0,      0,      fnt_rr, 0,      fnt_eq_,0,      fnt_co_,fnt_ro_
;// text writer
pin_mode_6  dd  fnt_in, 0,      fnt_nc, 0,      fnt_nr, fnt_er, 0,      0,      0,      0,      fnt_S_


;///////////////////////////////////////////////////////////////////////

    ;// mode tables

        pin_mode_table LABEL DWORD
        dd  pin_mode_0
        dd  pin_mode_1
        dd  pin_mode_2
        dd  pin_mode_3
        dd  pin_mode_4
        dd  pin_mode_5
        dd  pin_mode_6

        close_mode_table LABEL DWORD
        dd  bad_Close
        dd  data_Close
        dd  gmap_Close
        dd  reader_Close
        dd  writer_Close
        dd  csvreader_Close
        dd  csvwriter_Close

        open_mode_table LABEL DWORD
        dd  open_file_mode_bad
        dd  data_Open
        dd  gmap_Open
        dd  reader_Open
        dd  writer_Open
        dd  csvreader_Open
        dd  csvwriter_Open

        set_length_table LABEL DWORD
        dd  set_length_bad
        dd  data_SetLength
        dd  gmap_SetLength
        dd  set_length_reader
        dd  set_length_writer
        dd  set_length_csvreader
        dd  set_length_csvwriter

        file_get_name_table LABEL DWORD
        dd file_get_name_bad
        dd file_get_name_data
        dd file_get_name_memory
        dd file_get_name_reader
        dd file_get_name_writer
        dd file_get_name_csvreader
        dd file_get_name_csvwriter


;///////////////////////////////////////////////////////////////////////

    ;// data

        file_dialog_busy    dd  0   ;// handshake to prevent edit messages
        file_changing_name  dd  0   ;// prevent popup mixups

        file_available_modes    dd  0   ;// flags tell us which modes we can access
                                        ;// init with neg value to force file_initialize_modes

        file_instance_count dd  0   ;// use to init and destroy modes

        file_szFmt      db '%i',0
        ALIGN 4


comment ~ /*

    there are two places where we specify a new file name

    1) from ctor (loaded with circuit file)
    2) from popup panel (user specifies name)

    1) from ctor via file_OpenMode

        file_changing_name = 0  --> ok to look else where
        if file exists where stated --> return 1
        move to circuit directory
        release origonal name
        return 2 if it exists there
        otherwise return 0
            assume we create the file in circuit directory

    2) from popup panel via file_OpenMode

        file_changing_name = 1  --> not ok to look elsewhere
        if file exists where stated --> return 1
        otherwise return 0
            assume we create file where user specified

*/ comment ~

.CODE

ASSUME_AND_ALIGN
file_locate_name PROC

    ;// locates the file with stated name
    ;//
    ;// ebx must enter with where to start looking
    ;//
    ;// eax must enter as
    ;//
    ;//     eax=0   ok to move ebx to circuit directory
    ;//     eax=1   for check only where specified
    ;//
    ;// returns
    ;//
    ;//     eax=0   file doesn't exist at stated location
    ;//             ebx has been adjusted to circuit directory
    ;//             file doesn't exist there either
    ;//             releases origonal name
    ;//
    ;//     eax=1   file exists at stated location
    ;//
    ;//     eax=2   file doesn't exist at origonal location
    ;//             ebx has been adjusted to circuit directory
    ;//             file DOES exist there
    ;//             releases origonal name

        ASSUME esi:PTR OSC_FILE_MAP ;// esi is the osc
        ASSUME ebx:PTR FILENAME     ;// desired file to locate (may be replaced with new name)

        DEBUG_IF < eax !!= 0 && eax !!= 1 >

        push eax

    ;// check if the file exists where we say it does

        invoke CreateFileA, ADDR [ebx].szPath,
            0,
            FILE_SHARE_READ OR FILE_SHARE_WRITE,
            0, OPEN_EXISTING,
            FILE_FLAG_SEQUENTIAL_SCAN, 0

            DEBUG_IF <!!eax>, GET_ERROR ;// could not verify existance ??!!

        .IF eax != INVALID_HANDLE_VALUE ;// is the file here ?

            invoke CloseHandle, eax
            pop edx     ;// don't need flag anymore
            mov eax, 1  ;// file exists at stated spot

        .ELSE   ;// file doesn't exist at stated spot
                ;// see if we are allowed to check elsewhere

            pop eax ;// get the passed flag
            dec eax
            .IF SIGN?   ;// are we allowed to check elsewhere ?

                ;// see if file name exists where we opened the circuit

                ;// have to be careful about this !!
                ;// one of the last paths may be useing this

                invoke filename_CopyNewDirectory, ebx, filename_circuit_path
                ;// returns a new name in eax

                filename_PutUnused ebx  ;// release the old name

                mov ebx, eax            ;// xfer to eax

                invoke CreateFileA, ADDR [ebx].szPath,
                    0,
                    FILE_SHARE_READ OR FILE_SHARE_WRITE,
                    0, OPEN_EXISTING,
                    FILE_FLAG_SEQUENTIAL_SCAN, 0

                    DEBUG_IF <!!eax>, GET_ERROR ;// could not verify existance ??!!

                .IF eax != INVALID_HANDLE_VALUE ;// is the file here ?

                    invoke CloseHandle, eax
                    mov eax, 2  ;// file exists at new location

                .ELSE   ;// file doesn't exist here

                    xor eax, eax    ;// file does not exist at [ebx].szPath

                .ENDIF

            .ENDIF  ;// not allowed to move (eax is zero)

        .ENDIF

        ret

file_locate_name ENDP





ASSUME_AND_ALIGN
PROLOGUE_OFF
file_ask_retry PROC STDCALL pObjectName:DWORD, pFILENAME:DWORD

    ;// do a message box, use the file name as the caption
    ;//
    ;// returns eax as one of IDRETRY, IDCANCEL
    ;//
    ;// object names can be found at
    ;//     sz_Data_space_File
    ;//     sz_Mem_space_Buffer
    ;//     sz_Media_space_Reader
    ;//     sz_Wave_space_Writer
    ;//     sz_Text_space_Reader
    ;//     sz_Text_space_Writer

    .DATA

    fmt_cant_open db 'A %s object is unable to open this file.',0dh,0ah
                 db 'It may be in use by another application or marked as read-only.',0dh,0ah
                 db 'Press "Retry" to try and open the file again.',0
                 ALIGN 4
    .CODE

        mov ecx, [esp+8]    ;// pFILENAME
        mov edx, [esp+4]    ;// pObjectName
        sub esp, 256        ;// make a text buffer
        add ecx, FILENAME.szPath
        mov eax, esp        ;// point at the buffer

        ;// build args for MessageBoxA
        MSG_FLAGS = MB_RETRYCANCEL OR MB_ICONQUESTION OR MB_SETFOREGROUND OR MB_TOPMOST
        pushd MSG_FLAGS     ;// MessageBoxA.uType
        pushd ecx           ;// MessageBoxA.pszCaption
        pushd eax           ;// MessageBoxA.pszText
        pushd hMainWnd      ;// MessageBoxA.hWnd

        ;// format the message
        invoke wsprintfA, eax, OFFSET fmt_cant_open, edx

        or app_DlgFlags, DLG_MESSAGE        ;// interlock to prevent stumbling
        call MessageBoxA                    ;// args already pushed, stdcall cleans them up
        and app_DlgFlags, NOT DLG_MESSAGE   ;// turn off interlock

        add esp, 256        ;// clean up text buffer, eax has the return value

        retn 8              ;// STDCALL 2 ARGS

file_ask_retry ENDP






;///////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////
;///
;///
;///    P I N   M O D E S
;///
.CODE


ASSUME_AND_ALIGN
file_VerifyPins PROC uses edi ebx

    ASSUME ebp:PTR LIST_CONTEXT
    ASSUME esi:PTR OSC_FILE_MAP

    ;// assume that any mode we have has been opened

        lea ebx, [esi].pin_Lin
        ASSUME ebx:PTR APIN     ;// ebx scans all the pins in order

        mov edi, [esi].dwUser   ;// get the mode number
        and edi, FILE_MODE_TEST ;// remove all but the mode number
        ;// account for bad modes
        .IF (edi > FILE_MODE_MAX)   || !([esi].dwUser & FILE_MODE_IS_CALCABLE)
            xor edi, edi
        .ENDIF
        mov edi, pin_mode_table[edi*4]  ;// load the pin_mode_table
        pushd NUM_PIN_MODES             ;// use this a for a counter
        .REPEAT
            mov ecx, [edi]              ;// get the pin descriptor
            ASSUME ecx:PTR PIN_DESCRIPTOR
            xor eax, eax                            ;// default show pin value is off
            TESTJMP ecx, ecx, jz pin_to_be_shown    ;// zero means turn the pin off regardless
            ;// some pins we don't show if a bit is not set
            mov eax, [ecx].dwFlags  ;// and strip out gate tests
            and eax, NOT (FILE_WRITE_TEST OR FILE_WRITE_GATE OR FILE_MOVE_TEST OR FILE_MOVE_GATE OR FILE_SEEK_TEST OR FILE_SEEK_GATE)
            .IF !ZERO?
                and eax, [esi].dwUser
                jz pin_to_be_shown
            .ENDIF
            invoke pin_Show, ecx
            invoke pin_SetNameAndUnit, [ecx].pShortName, [ecx].pLongName, [ecx].unit
            ;// take care of logic input shapes
            TESTJMP [ebx].dwStatus, PIN_LOGIC_INPUT, jz show_the_pin
            ;// set the logic input to the correct shape
            mov eax, [ecx].dwFlags  ;// load the mask from the pin descriptor
            ;// remove all but the pin mask we care about
            .IF !([esi].dwUser & FILE_MODE_NO_GATES)    ;// account for no gates
                and eax, FILE_WRITE_TEST OR FILE_WRITE_GATE OR FILE_MOVE_TEST OR FILE_MOVE_GATE OR FILE_SEEK_TEST OR FILE_SEEK_GATE
            .ELSE
                and eax, FILE_WRITE_TEST OR FILE_MOVE_TEST OR FILE_SEEK_TEST
            .ENDIF
            DEBUG_IF <ZERO?>;// need to set the mask flags in the descriptor
            xor edx, edx
            mov ecx, 20     ;// where we want the mask to end up destroys ecx see PIN_LEVEL_POS
            bsf edx,eax     ;// load edx with first set bit of the mask
            and eax, [esi].dwUser   ;// then mask in the logic bits
            sub ecx, edx    ;// it is that bit we want to shift UP to position 20
            shl eax, cl     ;// shift into place
            or eax, PIN_LOGIC_INPUT ;// put the logic flag on
            invoke pin_SetInputShape;// and call the pin function to do that
        show_the_pin:
            or eax, 1               ;// make sure the pin gets shown
        pin_to_be_shown:
            push eax    ;// arg for pin_Show
            ;// check for having to erase output data
            .IF !eax && [ebx].dwStatus & PIN_OUTPUT && [ebx].pPin && [ebx].pData
            ;// this output pin is hidden and connected
            ;// zero the data so connected object doesn't get confused
                and [ebx].dwStatus, NOT PIN_CHANGING
                mov edx, edi
                mov ecx, SAMARY_LENGTH
                mov edi, [ebx].pData
                rep stosd
                mov edi, edx
            .ENDIF
            call pin_Show   ;// arg already pushed
            add edi, 4              ;// next pin descriptor pointer
            add ebx, SIZEOF APIN    ;// next pin
            dec DWORD PTR [esp]     ;// decrease the count
        .UNTIL ZERO?
        add esp, 4                  ;// done with the counter

    ;// that should do it

        ret


file_VerifyPins ENDP

;///
;///
;///    P I N   M O D E S
;///
;///////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////



;///////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////
;///
;///
;///    MODE initialization
;///

ASSUME_AND_ALIGN
file_InitializeModes PROC

    mov file_available_modes, FILE_AVAILABLE_DATA

    invoke gmap_Initialize  ;// returns zero for sucess
    .IF !eax
        or file_available_modes, FILE_AVAILABLE_MEMORY
    .ENDIF

    invoke reader_Initialize    ;// returns zero for sucess
    .IF !eax
        or file_available_modes, FILE_AVAILABLE_READER
    .ENDIF

    invoke writer_Initialize    ;// returns zero for sucess
    .IF !eax
        or file_available_modes, FILE_AVAILABLE_WRITER
    .ENDIF

    invoke csvreader_Initialize ;// returns zero for sucess
    .IF !eax
        or file_available_modes, FILE_AVAILABLE_CSVREADER
    .ENDIF

    invoke csvwriter_Initialize ;// returns zero for sucess
    .IF !eax
        or file_available_modes, FILE_AVAILABLE_CSVWRITER
    .ENDIF


    .IF fnt_A == 'A'

        push edi
        push ebx
        push esi
        ASSUME ebx:PTR DWORD

        mov ebx, OFFSET font_table_norm
        mov esi, OFFSET font_pin_slist_head
        .REPEAT
            mov eax, [ebx]
            mov edi, esi
            invoke font_Locate
            mov [ebx], edi
            add ebx, 16
        .UNTIL ![ebx]
        mov ebx, OFFSET font_table_bold
        mov esi, OFFSET font_bus_slist_head
        .REPEAT
            mov eax, [ebx]
            mov edi, esi
            invoke font_Locate
            mov [ebx], edi
            add ebx, 16
        .UNTIL ![ebx]

        pop esi
        pop ebx
        pop edi

    .ENDIF

    ret

file_InitializeModes ENDP

ASSUME_AND_ALIGN
file_DestroyModes PROC

    BITR file_available_modes, FILE_AVAILABLE_MEMORY
    .IF CARRY?
        invoke gmap_Destroy
    .ENDIF

    BITR file_available_modes, FILE_AVAILABLE_READER
    .IF CARRY?
        invoke reader_Destroy
    .ENDIF

    BITR file_available_modes, FILE_AVAILABLE_WRITER
    .IF CARRY?
        invoke writer_Destroy
    .ENDIF

    BITR file_available_modes, FILE_AVAILABLE_CSVREADER
    .IF CARRY?
        invoke csvreader_Destroy
    .ENDIF

    BITR file_available_modes, FILE_AVAILABLE_CSVWRITER
    .IF CARRY?
        invoke csvwriter_Destroy
    .ENDIF


    ret

file_DestroyModes ENDP


;///////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////
;///
;///
;///    MODE CHANGING
;///
.CODE

ASSUME_AND_ALIGN
file_OpenMode PROC

        ASSUME ebp:PTR LIST_CONTEXT
        ASSUME esi:PTR OSC_FILE_MAP
        ;// eax has the new mode

    ;// note: eax must enter with pin states as well
    ;// this is due to unredo

        DEBUG_IF < [esi].dwUser & ( FILE_MODE_TEST OR FILE_MODE_IS_TEST ) > ;// mode is supposed to be empty

    ;// store dwUser

        and eax, NOT FILE_MODE_IS_TEST  ;// strip out bits, open will reset them
        mov [esi].dwUser, eax
        and eax, FILE_MODE_TEST

        DEBUG_IF < (eax !> FILE_MODE_MAX) > ;// supposed to catch this

    ;// call the open function for the device

        call open_mode_table[eax*4]

    ;// see if we suceeded and verify the pins

        test eax, eax
        mov eax, HINTI_OSC_LOST_BAD
        jz @F
    open_file_mode_bad::
        mov eax, HINTI_OSC_GOT_BAD
    @@: GDI_INVALIDATE_OSC eax
        invoke file_VerifyPins

    ;// that's it

        ret


file_OpenMode ENDP



ASSUME_AND_ALIGN
file_CloseMode PROC

        ASSUME ebp:PTR LIST_CONTEXT
        ASSUME esi:PTR OSC_FILE_MAP

    ;// closes file, resets MODE_IS flags
    ;// does NOT call verify pins

    ;// check and clear old mode setting in dwUser

        mov eax, [esi].dwUser
        and [esi].dwUser, NOT (FILE_MODE_TEST OR FILE_MODE_IS_TEST)

        and eax, FILE_MODE_TEST

        DEBUG_IF <(eax !> FILE_MODE_MAX ) > ;// supposed to catch this

        call close_mode_table[eax*4]

    bad_Close::

        ;// reset the buffer

        DEBUG_IF < [esi].file.buf.pointer > ;// close mode should have emptied this !

        xor eax, eax

        mov [esi].file.buf.start, eax
        mov [esi].file.buf.stop, eax

        mov [esi].file.fmt_rate, eax
        mov [esi].file.fmt_chan, eax
        mov [esi].file.fmt_bits, eax

        ret

file_CloseMode ENDP


;///
;///
;///    MODE CHANGING
;///
;///////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////




;///////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////
;///
;///
;///    M E N U   I N T E R F A C E
;///


.DATA

file_button_init_table  EQU 0

;// ABOX234 seek,write,move buttons have been moved to ABoxOscFile.asm
;// see file_button_init_table

BUTTON_DESCRIPTION_TEXT_LENGTH  EQU 84  ;// should be plenty for all

;// trigger help texts have a common format
;// that format is %verb when %pin does this
;// since the button id's are in order, we define format strings indexed 0 to 4

    sz_fmt_trigger_table LABEL DWORD
        dd  sz_fmt_both_edge
        dd  sz_fmt_pos_edge
        dd  sz_fmt_neg_edge
        dd  sz_fmt_pos_gate
        dd  sz_fmt_neg_gate
    ;//                     verb         pin
    sz_fmt_both_edge    db  '%s once when %s changes sign.',0
    sz_fmt_pos_edge     db  '%s once when %s goes from negative to positive.',0
    sz_fmt_neg_edge     db  '%s once when %s goes from positive to negative.',0
    sz_fmt_pos_gate     db  '%s continuously when %s is positive or zero.',0
    sz_fmt_neg_gate     db  '%s continuously when %s is negative.',0
    ALIGN 4


    ;// then this table converts trigger flags to an index
    index_table LABEL DWORD ;// translates trigger flags to an id
            dd  0   ;// 000 both edge
            dd  1   ;// 001 pos edge
            dd  2   ;// 010 neg edge
            dd  -1  ;// 011 error
            dd  -1  ;// 100 error
            dd  3   ;// 101 pos gate
            dd  4   ;// 110 neg gate
            dd  -1  ;// 111 error


;///////////////////////////////////////////////////////////////////////////////////////

;// we have three clusters of trigger buttons
;// each cluster has a label as well
;// we'll want to adjust the label text and help string
;// and adjust the trigger help strings
;// these two structs allow us to do that

    BUTTON_INIT STRUCT              ;// one struct per mode per button cluster
        label_text          dd  0   ;// one or two chars for the label, is also noun for trigger help
        help_description    dd  0   ;// address of long string for the label
        verb_string         dd  0   ;// pointer to teh verb for the trigger button help
    BUTTON_INIT ENDS

    BUTTON_INITIALIZER STRUCT       ;// one struct per button cluster
        label_id            dd  0
        trigger_mask        dd  0
        button_help_table   dd  0   ;// 5 text buffers where we build the help strings
        first_button_id     dd  0
        init_table          dd  8   DUP (0) ;// ptrs to BUTTON_INIT's, one for each mode
    BUTTON_INITIALIZER ENDS


;// then we define value for each of the three trigger inputs

;///////////////////////////////////////////////////////////////////////////////////////
seek_buttons    LABEL DWORD

    dd  ID_FILE_SEEK_STATIC                 ;// label_id
    dd  FILE_SEEK_TEST OR FILE_SEEK_GATE    ;// trigger_mask
    dd  sz_seek_button_help                 ;// pointer to button_help_table
    dd  ID_FILE_SEEK_BOTH_EDGE              ;// first_button_id
        dd  0           ;// bad mode
        dd  init_seek_0 ;// data mode ptr
        dd  init_seek_0 ;// mem mode ptr
        dd  init_seek_0 ;// reader mode ptr
        dd  init_seek_1 ;// writer mode ptr
        dd  init_seek_2 ;// cvsreader mode ptr
        dd  init_seek_1 ;// csvwriter mode ptr
        dd  0           ;// unknown mode

    ;// data
    ;// mem
    ;// reader
    ;//             label_text  help_description        verb_string
    init_seek_0 dd  sz_seek_s,  sz_seek_seek_desc,      sz_seek_seek
    ;// writer
    ;// csvwriter
    init_seek_1 dd  sz_seek_er, sz_seek_erase_desc,     sz_seek_erase
    ;// csvread
    init_seek_2 dd  sz_seek_rr, sz_seek_reread_desc,    sz_seek_reread

    ;// string for seek buttons
    sz_FILE_ID_FILE_SEEK_STATIC     LABEL BYTE  ;// default is the usuall seek
    sz_seek_seek_desc   db  'Seek to position P when triggered. Overrides the move trigger.',0
    sz_seek_erase_desc  db  'Erase the file and start over. Overides the write and move triggers.',0
    sz_seek_reread_desc db  'Re-Read the file and build a new table.',0

    sz_seek_s       db  's',0
    sz_seek_seek    db  'Seek',0
    sz_seek_er      db  'er',0
    sz_seek_erase   db  'Erase',0
    sz_seek_rr      db  'rr',0
    sz_seek_reread  db  'Re-Read',0
    ALIGN 4

    ;// and here is where we build the help strings for the buttons

    sz_seek_button_help LABEL BYTE

    sz_FILE_ID_FILE_SEEK_BOTH_EDGE  db BUTTON_DESCRIPTION_TEXT_LENGTH  DUP (0)
    sz_FILE_ID_FILE_SEEK_POS_EDGE   db BUTTON_DESCRIPTION_TEXT_LENGTH  DUP (0)
    sz_FILE_ID_FILE_SEEK_NEG_EDGE   db BUTTON_DESCRIPTION_TEXT_LENGTH  DUP (0)
    sz_FILE_ID_FILE_SEEK_POS_GATE   db BUTTON_DESCRIPTION_TEXT_LENGTH  DUP (0)
    sz_FILE_ID_FILE_SEEK_NEG_GATE   db BUTTON_DESCRIPTION_TEXT_LENGTH  DUP (0)


;///////////////////////////////////////////////////////////////////////////////////////////
write_buttons LABEL DWORD

    dd  ID_FILE_WRITE_STATIC                ;// label_id
    dd  FILE_WRITE_TEST OR FILE_WRITE_GATE  ;// trigger_mask
    dd  sz_write_button_help                ;// pointer to button_help_table
    dd  ID_FILE_WRITE_BOTH_EDGE             ;// first_button_id
        dd  0           ;// bad mode
        dd  init_write_0    ;// data mode ptr
        dd  init_write_0    ;// mem mode ptr
        dd  0               ;// reader mode ptr
        dd  init_write_1    ;// writer mode ptr
        dd  0               ;// cvsreader mode ptr
        dd  init_write_2    ;// csvwriter mode ptr
        dd  0           ;// bad mode

    ;// data
    ;// mem
    ;//             label_text  help_description        verb_string
    init_write_0 dd sz_write_w, sz_write_write_desc,    sz_write_write
    ;// writer
    init_write_1 dd sz_write_w, sz_write_write_desc_2,  sz_write_write
    ;// csvwriter
    init_write_2 dd sz_write_nc,sz_next_column_desc,    sz_next_column

    sz_FILE_ID_FILE_WRITE_STATIC    LABEL BYTE
    sz_write_write_desc     db  "Writes the data at the 'in' pin. Does not move the file pointer.",0
    sz_write_write_desc_2   db  "Writes the data at the L and R pins to the end of the file, then increase the size.",0
    sz_next_column_desc     db  "Writes the data at the 'in' pin and advances to the next column.",0

    sz_write_w      db  'w',0
    sz_write_write  db  'Write',0
    sz_write_nc     db  'nc',0
    sz_next_column  db  'Next Column',0
    ALIGN 4

    sz_write_button_help LABEL BYTE
    sz_FILE_ID_FILE_WRITE_BOTH_EDGE db BUTTON_DESCRIPTION_TEXT_LENGTH  DUP (0)
    sz_FILE_ID_FILE_WRITE_POS_EDGE  db BUTTON_DESCRIPTION_TEXT_LENGTH  DUP (0)
    sz_FILE_ID_FILE_WRITE_NEG_EDGE  db BUTTON_DESCRIPTION_TEXT_LENGTH  DUP (0)
    sz_FILE_ID_FILE_WRITE_POS_GATE  db BUTTON_DESCRIPTION_TEXT_LENGTH  DUP (0)
    sz_FILE_ID_FILE_WRITE_NEG_GATE  db BUTTON_DESCRIPTION_TEXT_LENGTH  DUP (0)


;///////////////////////////////////////////////////////////////////////////////////////////
move_buttons LABEL DWORD

    dd  ID_FILE_MOVE_STATIC                 ;// label_id
    dd  FILE_MOVE_TEST OR FILE_MOVE_GATE    ;// trigger_mask
    dd  sz_move_button_help                 ;// pointer to button_help_table
    dd  ID_FILE_MOVE_BOTH_EDGE              ;// first_button_id
        dd  0           ;// bad mode
        dd  init_move_0 ;// data mode ptr
        dd  init_move_0 ;// mem mode ptr
        dd  init_move_0 ;// reader mode ptr
        dd  0           ;// writer mode ptr
        dd  0           ;// cvsreader mode ptr
        dd  init_move_1 ;// csvwriter mode ptr
        dd  0           ;// bad mode


    ;//             label_text  help_description        verb_string
    init_move_0 dd  sz_move_m,  sz_move_move_desc,      sz_move_move
    init_move_1 dd  sz_move_nr, sz_next_row_desc,       sz_next_row


    sz_FILE_ID_FILE_MOVE_STATIC     LABEL BYTE
    sz_move_move_desc   db 'Move the file pointer to the next sample and read new data.',0
    sz_next_row_desc    db 'End the current row with a linefeed and start a new row. Does not write data',0

    sz_move_m           db  'm',0
    sz_move_move        db  'Move',0
    sz_move_nr          db  'nr',0
    sz_next_row         db  'Next Row',0
    ALIGN 4

    sz_move_button_help LABEL BYTE
    sz_FILE_ID_FILE_MOVE_BOTH_EDGE  db BUTTON_DESCRIPTION_TEXT_LENGTH  DUP (0)
    sz_FILE_ID_FILE_MOVE_POS_EDGE   db BUTTON_DESCRIPTION_TEXT_LENGTH  DUP (0)
    sz_FILE_ID_FILE_MOVE_NEG_EDGE   db BUTTON_DESCRIPTION_TEXT_LENGTH  DUP (0)
    sz_FILE_ID_FILE_MOVE_POS_GATE   db BUTTON_DESCRIPTION_TEXT_LENGTH  DUP (0)
    sz_FILE_ID_FILE_MOVE_NEG_GATE   db BUTTON_DESCRIPTION_TEXT_LENGTH  DUP (0)



.CODE

ASSUME_AND_ALIGN
file_InitMenu PROC

        ASSUME ebp:PTR LIST_CONTEXT
        ASSUME esi:PTR OSC_FILE_MAP

        push esi
        push ebp
        push edi

        mov ebp, esi
        ASSUME ebp:PTR OSC_FILE_MAP
        ASSUME esi:NOTHING

        inc file_dialog_busy    ;// handshake to prevent edit messages

    ;// this routine is a little complicated because we may be
    ;// re-initializing a good or bad mode and need to disable buttons
    ;// for radio buttons, we need to be cautious of showing a disabled pressed button

    ;// init mode buttons

        mov ebx, 1                  ;// mask
        mov esi, ID_FILE_MODE_DATA  ;// ID
        mov edi, 1                  ;// counter & mode

        .REPEAT

            ;// enable or disable
            invoke GetDlgItem, popup_hWnd, esi
            xor ecx, ecx
            test file_available_modes, ebx
            setnz cl
            invoke EnableWindow, eax, ecx
            ;// push or unpush
            mov eax, [ebp].dwUser
            and eax, FILE_MODE_TEST
            xor ecx, ecx
            cmp eax, edi
            setz cl
            invoke CheckDlgButton, popup_hWnd, esi, ecx

            ;// advance
            inc edi     ;// next mode
            shl ebx, 1  ;// next mask
            inc esi     ;// next ID

        .UNTIL edi > FILE_MODE_MAX

    ;// init name or id

        mov eax, [ebp].dwUser
        mov edi, popup_hWnd
        and eax, FILE_MODE_TEST
        .IF ZERO?   ;// bad mode

            SHOW_CONTROL edi, ID_FILE_ID_STATIC, 0  ;// hide id buttons
            SHOW_CONTROL edi, ID_FILE_ID_EDIT, 0
            SHOW_CONTROL edi, ID_FILE_NAME, 0       ;// show name button

        .ELSEIF eax != FILE_MODE_MEMORY

        ;// fill in name buttons

            SHOW_CONTROL edi, ID_FILE_ID_STATIC, 0  ;// hide id buttons
            SHOW_CONTROL edi, ID_FILE_ID_EDIT, 0
            SHOW_CONTROL edi, ID_FILE_NAME, 1, ecx  ;// show name button
            ;// name.hWnd returned in ecx

            mov eax, [ebp].dwUser
            and eax, FILE_MODE_TEST
            mov eax, [ebp].file.filename_table[eax*4]
            .IF eax
                add eax, FILENAME.szPath
                WINDOW ecx,WM_SETTEXT,0,eax
            .ELSE   ;// eax is zero
                pushd 'ema'
                pushd 'n oN'
                WINDOW ecx,WM_SETTEXT,0,esp
                add esp, 8
            .ENDIF

        .ELSE   ;// memory mode

        ;// fill in id button

            SHOW_CONTROL edi, ID_FILE_NAME, 0       ;// hide name button
            SHOW_CONTROL edi, ID_FILE_ID_STATIC, 1  ;// show id button
            SHOW_CONTROL edi, ID_FILE_ID_EDIT, 1, ecx

            ;// parameters for WM_SETTEXT
            mov edx, [ebp].file.filename_Memory
            pushd 0 ;// default to no text
            .IF edx
                add edx, FILENAME.szPath
                push edx    ;// WM_SETTEXT pText
            .ELSE
                push esp    ;// WM_SETTEXT pText
            .ENDIF
            pushd 0         ;// WM_SETTEXT wParam
            pushd WM_SETTEXT;// msg
            push ecx        ;// hWnd
            ;// set limit text
            WINDOW ecx, EM_SETLIMITTEXT, FILE_MAX_ID_LENGTH+3, 0
            call SendMessageA   ;// WM_SETTEXT
            pop eax

        .ENDIF

    ;// init size buttons

    sub esp, FILE_EDIT_LENGTH_BUFFER_LENGTH*3   ;// make a text buffer
    ;// this buffer will be used by the format also


        mov ebx, [ebp].dwUser
        and ebx, FILE_MODE_IS_SIZEABLE
        .IF !ZERO?  ;// ZERO = SW_HIDE

            invoke GetDlgItem, edi, ID_FILE_LENGTH_EDIT
            mov ecx, eax    ;// window handle of edit box

            mov edx, esp    ;// point at our text buffer
            ;// store parameters for WM_SETTEXT
            push edx            ;// SendMessage lParam
            pushd 0             ;// SendMessage wParam
            pushd WM_SETTEXT    ;// SendMessage msg
            push ecx            ;// SendMessage hWnd
            ;// store parameters for EM_SETLIMITTEXT
            pushd 0                                 ;// SendMessage lParam
            pushd FILE_EDIT_LENGTH_BUFFER_LENGTH    ;// SendMessage wParam
            pushd EM_SETLIMITTEXT                   ;// SendMessage msg
            push ecx                                ;// SendMessage hWnd
            ;// format the text
            invoke wsprintfA, edx, OFFSET file_szFmt, [ebp].file.file_length
            call SendMessageA   ;// EM_SETLIMITTEXT
            call SendMessageA   ;// WM_SETTEXT

            ;// setup the max length
            mov eax, esp
            invoke wsprintfA, eax, OFFSET file_szFmt, [ebp].file.max_length
            invoke GetDlgItem, edi, ID_FILE_MAXLENGTH_STATIC
            WINDOW eax, WM_SETTEXT,,esp

            mov ebx, SW_SHOW

        .ENDIF

        invoke GetDlgItem, edi, ID_FILE_LENGTH_STATIC
        invoke ShowWindow, eax, ebx

        invoke GetDlgItem, edi, ID_FILE_LENGTH_EDIT
        invoke ShowWindow, eax, ebx

        invoke GetDlgItem, edi, ID_FILE_MAXLENGTH_STATIC
        invoke ShowWindow, eax, ebx

    ;// build the format
    ;// we still have a buffer on the stack


    ;// edi is destroyed by the next block

        invoke GetDlgItem,popup_hWnd,ID_FILE_FMT_STATIC
        mov esi, eax

        xor ebx, ebx    ;// asume fail
        .IF [ebp].file.fmt_rate
            mov edi, esp    ;// point edi at text buffer
            .IF !([ebp].dwUser & FILE_MODE_IS_WRITABLE)
                ;// (REA D ON LY)
                mov eax, 'aer('
                stosd
                mov eax, 'no d'
                stosd
                mov eax, ' )yl'
                stosd
            .ENDIF
            .IF [ebp].file.fmt_rate != -1   ;// check for special csv format
                ;// rate
                invoke wsprintfA, edi, OFFSET file_szFmt, [ebp].file.fmt_rate
                add edi, eax
                mov eax, '  zH'
                stosd
                ;// format
                mov ebx, [ebp].dwUser
                and ebx, FILE_MODE_TEST
                .IF ZERO?       ;// bad mode
                    xor eax, eax    ;// no more text
                    ;//stosd
                    ;//xor ebx, ebx ;// disabled already zero
                .ELSE   ;// good mode
                    .IF ebx == FILE_MODE_DATA || ebx == FILE_MODE_MEMORY
                        mov eax, 'onom'
                        stosd
                        mov eax, 'olf '
                        stosd
                        mov eax, 'ta'
                        ;//stosd
                    .ELSE
                        mov ebx, [ebp].dwUser
                        .IF [ebp].file.fmt_bits == 16
                            mov eax, 'b 61'
                            stosd
                            mov eax, '  ti'
                            stosd
                        .ELSEIF [ebp].file.fmt_bits == 8
                            mov eax, 'ib 8'
                            stosd
                            mov eax, ' t'
                            stosw
                        .ELSE
                            mov eax, 'b 23'
                            stosd
                            mov eax, '  ti'
                            stosd
                        .ENDIF

                        .IF ebx & FILE_MODE_IS_STEREO
                            mov eax, 'rets'
                            stosd
                            mov eax, 'oe'

                        .ELSE
                            mov eax, 'onom'
                            stosd
                            xor eax, eax
                        .ENDIF
                    .ENDIF
                    mov ebx, SW_SHOW    ;// enabled
                .ENDIF  ;// bad/good mode
            .ELSE   ;// csv formats
                mov ebx, [ebp].dwUser
                and ebx, FILE_MODE_TEST
                .IF ebx != FILE_MODE_CSVWRITER &&  ebx != FILE_MODE_CSVREADER
                    ;// bad mode
                    xor eax, eax    ;// no more text
                    ;//stosd
                    xor ebx, ebx    ;// SW_HIDE
                .ELSE   ;// good mode
                    mov eax, 'txeT'
                    stosd
                    ;// mov eax, 'VSC '
                    ;// stosd
                    xor eax, eax
                    mov ebx, SW_SHOW    ;// enabled
                .ENDIF
            .ENDIF
            stosd   ;// eax has last bytes to store
            ;// esp has window text
            WINDOW esi,WM_SETTEXT,0,esp
        .ENDIF  ;// no rate

        ;// ebx has enabled/disabled
        invoke ShowWindow,esi,ebx


    add esp, FILE_EDIT_LENGTH_BUFFER_LENGTH * 3

    ;// init seek buttons

        mov edi, OFFSET seek_buttons
        call process_button_table

        ;// enable and push sync

        mov ebx, [ebp].dwUser
        and ebx, FILE_MODE_IS_SYNCABLE  ;// zero = SW_HIDE
        .IF !ZERO?
            xor ecx, ecx    ;// BST_UNCHECKED
            test [ebp].dwUser, FILE_SEEK_SYNC
            setnz cl        ;// BST_CHECKED
            invoke CheckDlgButton, popup_hWnd, ID_FILE_SEEK_SYNC, ecx
            mov ebx, SW_SHOW
        .ENDIF
        invoke GetDlgItem, popup_hWnd, ID_FILE_SEEK_SYNC
        invoke ShowWindow,eax,ebx

        ;// enable and push norm/percent
        mov ebx, [ebp].dwUser
        invoke GetDlgItem, popup_hWnd, ID_FILE_SEEK_PERCENT
        mov esi, eax
        invoke GetDlgItem, popup_hWnd, ID_FILE_SEEK_NORM
        mov edi, eax

        and ebx, FILE_MODE_IS_REWINDONLY
        .IF ZERO? && ([ebp].dwUser & FILE_MODE_IS_CALCABLE)
            mov ecx, ID_FILE_SEEK_PERCENT
            mov edx, ID_FILE_SEEK_NORM
            .IF [ebp].dwUser & FILE_SEEK_NORM
                xchg ecx, edx
            .ENDIF  ;// now ecx has the button to push, edx the one not to push
            pushd BST_UNCHECKED
            push  edx
            push  popup_hWnd
            pushd BST_CHECKED
            push  ecx
            push  popup_hWnd
            call  CheckDlgButton
            call  CheckDlgButton
            mov ebx, SW_SHOW
        .ELSE
            xor ebx, ebx
        .ENDIF
        invoke ShowWindow, esi, ebx
        invoke ShowWindow, edi, ebx

    ;// init write buttons

        mov edi, OFFSET write_buttons
        call process_button_table

    ;// init move buttons

        mov edi, OFFSET move_buttons
        call process_button_table

        ;// enable and push rewind
        mov ebx, [ebp].dwUser
        and ebx, FILE_MODE_IS_READABLE
        .IF !ZERO? && ([ebp].dwUser & FILE_MODE_IS_CALCABLE)
            xor edx, edx    ;// BST_UNCHECKED
            test [ebp].dwUser, FILE_MOVE_LOOP
            setnz dl        ;// BST_CHECKED
            CHECK_BUTTON popup_hWnd, ID_FILE_MOVE_REWIND, edx
            mov ebx, SW_SHOW
        .ELSE
            xor ebx, ebx    ;// SW_HIDE
        .ENDIF
        invoke GetDlgItem, popup_hWnd, ID_FILE_MOVE_REWIND
        invoke ShowWindow, eax, ebx

    ;// return zero or popup will resize

        dec file_dialog_busy    ;// handshake to prevent edit messages
        xor eax, eax

        pop edi
        pop ebp
        pop esi

        ret

;/////////////////////////////////////////////////////////////////////////

    ALIGN 16
    process_button_table:

    ;// uses esi,ebx
    ;// many things to do
    ASSUME edi:PTR BUTTON_INITIALIZER   ;// see seek_buttons for temple
    ;// if bad mode, hide the controls
    ;// otherwise
    ;//     set the label text
    ;//     set the label help text pointer
    ;//     define the button popup helps


        mov esi, [ebp].dwUser
        and esi, FILE_MODE_TEST
        mov esi, [edi].init_table[esi*4]
        invoke GetDlgItem, popup_hWnd, [edi].label_id
        mov ebx, eax
        .IF !esi || !([ebp].dwUser & FILE_MODE_IS_CALCABLE)
            ;// disable this button cluster
            invoke ShowWindow,ebx,SW_HIDE
            ;// and do the five buttons
            mov esi, [edi].first_button_id
            add esi, 4  ;// there are five buttons, we start on the last one
            .REPEAT
                invoke GetDlgItem,popup_hWnd,esi
                invoke ShowWindow,eax, SW_HIDE
                dec esi
            .UNTIL esi < [edi].first_button_id
        .ELSE   ;// have a valid button cluster group
            ASSUME esi:PTR BUTTON_INIT
            invoke SendMessageA,ebx,WM_SETTEXT,0,[esi].label_text
            invoke SetWindowLongA,ebx,GWL_USERDATA,[esi].help_description
            invoke ShowWindow,ebx,SW_SHOW
            ;// determine the index of the button we are to push
            mov eax, [edi].trigger_mask ;// load the mask from the pin descriptor
            ;// remove all but the pin mask we care about
            .IF !([ebp].dwUser & FILE_MODE_NO_GATES)    ;// account for no gates
                and eax, FILE_WRITE_TEST OR FILE_WRITE_GATE OR FILE_MOVE_TEST OR FILE_MOVE_GATE OR FILE_SEEK_TEST OR FILE_SEEK_GATE
            .ELSE
                and eax, FILE_WRITE_TEST OR FILE_MOVE_TEST OR FILE_SEEK_TEST
            .ENDIF
            DEBUG_IF <ZERO?>    ;// need to set the mask flags in the descriptor
            ;// determine the lowest bit that is set
            xor ecx, ecx
            bsf ecx,eax             ;// load edx with first set bit of the mask
            and eax, [ebp].dwUser   ;// then mask out the logic bits
            shr eax, cl             ;// shift into place
            mov eax, index_table[eax*4] ;// load the index we are to turn on
            push ebp
            ;// build the no gates flag and set a bit indicating which button to push
            test [ebp].dwUser, FILE_MODE_NO_GATES
            mov ebp, 0
            .IF !ZERO?
                or ebp, 80000000h   ;// use the sign bit to indicate no gates
            .ENDIF
            bts ebp,eax             ;// then turn on the bit for the button we are to push
            ;// scan all the buttons
            ;// to save registers, we'll push 5 sets of args
            ;// then call five sets of functions
            xor ebx, ebx            ;// ebx counts
            .REPEAT

                add ebx,[edi].first_button_id
                invoke GetDlgItem, popup_hWnd,ebx
                ;// eax has the button hWnd
                mov ecx, ebx    ;// ecx has the identifier
                sub ebx, [edi].first_button_id

                ;// wsprintfA
                push [esi].label_text               ;// 8   3 wsprintfA noun_string
                push [esi].verb_string              ;// 7   2 wsprintfA verb_string
                push sz_fmt_trigger_table[ebx*4]    ;// 6   1 wsprintfA fmt_ptr
                mov edx, ebx
                imul edx,BUTTON_DESCRIPTION_TEXT_LENGTH
                add edx, [edi].button_help_table
                push edx                            ;// 5   0 wsprintfA dest_ptr

                ;// CheckDlgButton
                bt ebp,ebx  ;// check if this button is to be pushed
                .IF CARRY?              ;// 4   2 CheckDlgButton BST_CHECKED
                    pushd BST_CHECKED
                .ELSE
                    pushd BST_UNCHECKED
                .ENDIF
                push ecx                ;// 3   1 CheckDlgButton ID
                push popup_hWnd         ;// 2   0 CheckDlgButton hWnd

                ;// ShowWindow
                test ebp, ebp   ;// check for no gates
                .IF SIGN? && ebx >= 3   ;// 1   1 ShowWindow.show
                    pushd SW_HIDE
                .ELSEIF
                    pushd SW_SHOW
                .ENDIF
                pushd eax               ;// 0   0 ShowWindow.hWnd

                inc ebx

            .UNTIL ebx >= 5
            .REPEAT
                call ShowWindow
                call CheckDlgButton
                call wsprintfA
                add esp, 4*4    ;// C call
                dec ebx
            .UNTIL ZERO?
            pop ebp

        .ENDIF

        retn    ;// that should do it



file_InitMenu ENDP








ASSUME_AND_ALIGN
file_parse_edit_size PROC ;// STDCALL char buffer[FILE_EDIT_LENGTH_BUFFER_LENGTH]

    ;// task:
    ;//
    ;//     convert passed buffer to an integer
    ;//     if size is not too big
    ;//         store size in object
    ;//         call file_SetSize
    ;//     else
    ;//         flag as error ??

        ASSUME ebp:PTR LIST_CONTEXT
        ASSUME esi:PTR OSC_FILE_MAP

        xor edx, edx    ;// accumulator
        mov ecx, 4      ;// stack addresser

    top_of_loop:

        xor eax, eax    ;// char getter
        mov al, [esp+ecx]
        inc ecx
        sub al, '0'
        jb done_with_text
        cmp al, '9'
        ja done_with_text

        lea edx, [edx+edx*4]    ;// * 5
        lea edx, [eax+edx*2]    ;// * 10 + new digit

        cmp ecx, FILE_EDIT_LENGTH_BUFFER_LENGTH + 4
        jb top_of_loop

    done_with_text:

        ;// edx has the desired number
        .IF edx && edx <= [esi].file.max_length

            ;// we can set the new size
            mov [esi].file.file_length, edx

            ;// call the set length function
            mov eax, [esi].dwUser
            and eax, FILE_MODE_TEST
            call set_length_table[eax*4]

    ;// .ELSE
    ;// show an error message ?

        .ENDIF

    set_length_bad::
    set_length_reader::
    set_length_writer::
    set_length_csvreader::
    set_length_csvwriter::

        ret FILE_EDIT_LENGTH_BUFFER_LENGTH

file_parse_edit_size ENDP

ASSUME_AND_ALIGN
file_parse_edit_id PROC ;// STDCALL char buffer[FILE_MAX_ID_LENGTH+4]

    ;// note the + 4 on the buffer


    ;// task:
    ;//
    ;//     format the passed string
    ;//     if valid format
    ;//         copy string to file
    ;//         call file_ChangeName
    ;//     otherwise
    ;//         flag as error ?

        ASSUME esi:PTR OSC_FILE_MAP

    ;// format the name
    ;// non ascii characters are converted to _
    ;// size is verified

    comment ~ /*
        0-9
        A-Z
        a-z
        convert all other characters to _
    */ comment ~

        mov ecx, 4  ;// counter
        xor eax, eax

        .REPEAT

            or al, BYTE PTR [esp+ecx]
            jz done_with_string

            cmp al, ' '
            jb done_with_string

            cmp al, '0'
            jb convert_to_underscore
            cmp al, '9'
            jbe char_is_ok

            cmp al, 'A'
            jb convert_to_underscore
            cmp al, 'Z'
            jbe convert_to_lower_case

            cmp al, 'a'
            jb convert_to_underscore
            cmp al, 'z'
            jbe char_is_ok

        convert_to_underscore:

            mov BYTE PTR [esp+ecx], '_'
            jmp char_is_ok

        convert_to_lower_case:

            or BYTE PTR [esp+ecx], 20h

        char_is_ok:

            inc ecx
            mov al, ah

        .UNTIL ecx >= FILE_MAX_ID_LENGTH + 4

    ;// if we hit this, the string is MAX long

    done_with_string:

        mov BYTE PTR [esp+ecx], 0   ;// terminate

        .IF ecx > 4     ;// make sure we got something

            push ebx
            push esi
            mov ebx, [esi].file.filename_Memory
            .IF !ebx
                invoke filename_GetUnused
                mov [esi].file.filename_Memory, ebx
            .ENDIF
            lea esi, [esp+12]
            invoke filename_InitFromString, 0
            pop esi
            pop ebx

            push [esi].dwUser       ;// need to store the mode
            invoke file_CloseMode
            pop eax                 ;// retrieve the mode
            invoke file_OpenMode

        .ENDIF  ;// valid name (if not, just ignore)

;// all_done:

        ret FILE_MAX_ID_LENGTH+4

file_parse_edit_id ENDP


ASSUME_AND_ALIGN
file_Command PROC

        ASSUME ebp:PTR LIST_CONTEXT
        ASSUME esi:PTR OSC_FILE_MAP
        ;// eax has command ID

;// check for edit messages

        cmp eax, OSC_COMMAND_EDIT_KILLFOCUS
        jne @F

        cmp file_dialog_busy, 0
        jne osc_Command

            push ecx
            invoke GetDlgItem, popup_hWnd, ecx
            mov ebx, eax
            WINDOW ebx, EM_GETMODIFY
            test eax, eax
            pop ecx
            jz ignore_and_done

        ;// text has been changed

            .IF ecx == ID_FILE_ID_EDIT

                sub esp, FILE_MAX_ID_LENGTH+4
                WINDOW ebx, WM_GETTEXT, FILE_MAX_ID_LENGTH+4, esp
                jmp id_got_enter_key

            .ENDIF

            .IF ecx == ID_FILE_LENGTH_EDIT

                sub esp, FILE_EDIT_LENGTH_BUFFER_LENGTH
                WINDOW ebx, WM_GETTEXT, FILE_EDIT_LENGTH_BUFFER_LENGTH, esp
                jmp size_got_enter_key

            .ENDIF

            jmp osc_Command


    @@: cmp eax, OSC_COMMAND_EDIT_CHANGE
        jne @F

    ;// EN_CHANGE
    ;// edit box control id is sent in ecx

        cmp file_dialog_busy, 0
        jne osc_Command

        .IF ecx == ID_FILE_ID_EDIT

            ;// file id name

            ;// detect if we got the enter key

            invoke GetDlgItem, popup_hWnd, ecx
            mov ebx, eax
            sub esp, FILE_MAX_ID_LENGTH+4
            WINDOW ebx, WM_GETTEXT, FILE_MAX_ID_LENGTH+4, esp
            ;// eax is number copied
            .IF eax ;// make sure there's something there
                cmp BYTE PTR [esp+eax-1], 0dh
                je id_got_enter_key
                cmp BYTE PTR [esp+eax-1], 0ah
                jne id_edit_done
            id_got_enter_key:
                invoke file_parse_edit_id
                jmp redraw_init_and_done
            id_edit_done:
            .ENDIF
            add esp, FILE_MAX_ID_LENGTH+4
            jmp ignore_and_done

        .ENDIF

        .IF ecx == ID_FILE_LENGTH_EDIT

            ;// edit buffer size

            ;// detect if we got the enter key

            invoke GetDlgItem, popup_hWnd, ecx
            mov ebx, eax
            sub esp, FILE_EDIT_LENGTH_BUFFER_LENGTH
            WINDOW ebx, WM_GETTEXT, FILE_EDIT_LENGTH_BUFFER_LENGTH, esp
            ;// eax is number copied
            .IF eax ;// make sure there's somthing there
                cmp BYTE PTR [esp+eax-1], 0dh
                je size_got_enter_key
                cmp BYTE PTR [esp+eax-1], 0ah
                jne size_edit_done
            size_got_enter_key:
                invoke file_parse_edit_size
                jmp redraw_init_and_done
            size_edit_done:
            .ENDIF
            add esp, FILE_EDIT_LENGTH_BUFFER_LENGTH
            jmp ignore_and_done

        .ENDIF


;// check general range

    @@: cmp eax, ID_FILE_FIRST
        jb osc_Command
        cmp eax, ID_FILE_LAST
        ja osc_Command

;// MOVE COMMANDS

    _MOVE_COMMANDS:

        cmp eax, ID_FILE_MOVE_BOTH_EDGE
        jb _SEEK_COMMANDS

        ;// mask and merge values
        mov edx, NOT(FILE_MOVE_TEST OR FILE_MOVE_GATE)
        xor ecx, ecx

    ;// move commands

        cmp eax, ID_FILE_MOVE_BOTH_EDGE
        jne @F

        jmp set_new_trigger

    @@: cmp eax, ID_FILE_MOVE_POS_EDGE
        jne @F

        or ecx, FILE_MOVE_POS
        jmp set_new_trigger

    @@: cmp eax, ID_FILE_MOVE_NEG_EDGE
        jne @F

        or ecx, FILE_MOVE_NEG
        jmp set_new_trigger

    @@: cmp eax, ID_FILE_MOVE_POS_GATE
        jne @F

        or ecx, FILE_MOVE_POS OR FILE_MOVE_GATE
        jmp set_new_trigger

    @@: cmp eax, ID_FILE_MOVE_NEG_GATE
        jne @F

        or ecx, FILE_MOVE_NEG OR FILE_MOVE_GATE
        jmp set_new_trigger

    @@: cmp eax, ID_FILE_MOVE_REWIND
        jne osc_Command

        xor [esi].dwUser, FILE_MOVE_LOOP
        jmp dirty_and_done

;// SEEK_COMMANDS

    _SEEK_COMMANDS:

        cmp eax, ID_FILE_SEEK_BOTH_EDGE
        jb _WRITE_COMMANDS

        ;// mask and merge values
        mov edx, NOT(FILE_SEEK_TEST OR FILE_SEEK_GATE)
        xor ecx, ecx

    ;// seek commands

        cmp eax, ID_FILE_SEEK_BOTH_EDGE
        jne @F

        jmp set_new_trigger

    @@: cmp eax, ID_FILE_SEEK_POS_EDGE
        jne @F

        or ecx, FILE_SEEK_POS
        jmp set_new_trigger

    @@: cmp eax, ID_FILE_SEEK_NEG_EDGE
        jne @F

        or ecx, FILE_SEEK_NEG
        jmp set_new_trigger

    @@: cmp eax, ID_FILE_SEEK_POS_GATE
        jne @F

        or ecx, FILE_SEEK_POS OR FILE_SEEK_GATE
        jmp set_new_trigger

    @@: cmp eax, ID_FILE_SEEK_NEG_GATE
        jne @F

        or ecx, FILE_SEEK_NEG OR FILE_SEEK_GATE
        jmp set_new_trigger

    @@: cmp eax, ID_FILE_SEEK_SYNC
        jne @F

        xor [esi].dwUser, FILE_SEEK_SYNC
        jmp dirty_and_done

    @@: cmp eax, ID_FILE_SEEK_NORM
        jne @F

        or [esi].dwUser, FILE_SEEK_NORM
        jmp dirty_and_done

    @@: cmp eax, ID_FILE_SEEK_PERCENT
        jne osc_Command

        and [esi].dwUser, NOT FILE_SEEK_NORM
        jmp dirty_and_done

;// WRITE_COMMANDS

    _WRITE_COMMANDS:

        cmp eax, ID_FILE_WRITE_BOTH_EDGE
        jb _NAME_COMMANDS

        ;// mask and merge values
        mov edx, NOT(FILE_WRITE_TEST OR FILE_WRITE_GATE)
        xor ecx, ecx

    ;// write commands

        cmp eax, ID_FILE_WRITE_BOTH_EDGE
        jne @F

        jmp set_new_trigger

    @@: cmp eax, ID_FILE_WRITE_POS_EDGE
        jne @F

        or ecx, FILE_WRITE_POS
        jmp set_new_trigger

    @@: cmp eax, ID_FILE_WRITE_NEG_EDGE
        jne @F

        or ecx, FILE_WRITE_NEG
        jmp set_new_trigger

    @@: cmp eax, ID_FILE_WRITE_POS_GATE
        jne @F

        or ecx, FILE_WRITE_POS OR FILE_WRITE_GATE
        jmp set_new_trigger

    @@: cmp eax, ID_FILE_WRITE_NEG_GATE
        jne osc_Command

        or ecx, FILE_WRITE_NEG OR FILE_WRITE_GATE
        jmp set_new_trigger

;// NAME SIZE COMMANDS

    _NAME_COMMANDS:

        cmp eax, ID_FILE_NAME
        jb _MODE_COMMANDS
        jne osc_Command

        ;////////////////////////////////////////////////////////////////////////////

            ;// we want to choose a new file
            ;// to do this we need to set up the filename_xxx_path that get open filename wants

            ;// the first stage will:
            ;// set edi to point at the last_path filename
            ;// set ecx to point at the filename we initialize and want to get
            ;// set edx as the open mode

            mov eax, [esi].dwUser
            and eax, FILE_MODE_TEST
            jmp file_get_name_table[eax*4]

        file_get_name_data::

            mov edi, OFFSET filename_data_path  ;// point at where we want the string to go
            lea ecx, [esi].file.filename_Data   ;// point at what we want to initialize it with
            mov edx, GETFILENAME_DATA           ;// set how we want to initialize it
            jmp try_to_get_the_name

        file_get_name_reader::

            mov edi, OFFSET filename_reader_path    ;// point at where we want the string to go
            lea ecx, [esi].file.filename_Reader     ;// point at what we want to initialize it with
            mov edx, GETFILENAME_READER             ;// set how we want to initialize it
            jmp try_to_get_the_name

        file_get_name_writer::

            mov edi, OFFSET filename_writer_path    ;// point at where we want the string to go
            lea ecx, [esi].file.filename_Writer     ;// point at what we want to initialize it with
            mov edx, GETFILENAME_WRITER             ;// set how we want to initialize it
            jmp try_to_get_the_name

        file_get_name_csvreader::

            mov edi, OFFSET filename_csvreader_path     ;// point at where we want the string to go
            lea ecx, [esi].file.filename_CSVReader      ;// point at what we want to initialize it with
            mov edx, GETFILENAME_CSVREADER              ;// set how we want to initialize it
            jmp try_to_get_the_name

        file_get_name_csvwriter::

            mov edi, OFFSET filename_csvwriter_path     ;// point at where we want the string to go
            lea ecx, [esi].file.filename_CSVWriter      ;// point at what we want to initialize it with
            mov edx, GETFILENAME_CSVWRITER              ;// set how we want to initialize it
            ;//jmp try_to_get_the_name


        try_to_get_the_name:

            ;// state:
            ;// edi points at where we want the file name to go
            ;// ecx points at what we want to initialize it with (and where we store the results)
            ;// edx has the open mode we want to use

            push ecx    ;// save where the filename will go
            push edx    ;// save the open mode as a parameter for the next call

            mov ebx, [edi]      ;// get the initializer
            mov ecx, [ecx]      ;// get our name
            .IF ebx && ecx      ;// see if we need to initialize the last path with out name
                push esi
                lea esi, (FILENAME PTR [ecx]).szPath
                invoke filename_InitFromString, FILENAME_FULL_PATH
                pop esi
            .ENDIF

        ;// call the app's file open dialog

            .IF play_status & PLAY_PLAYING
                LEAVE_PLAY_SYNC GUI
            .ENDIF

            call filename_GetFileName   ;// parameter already pushed

            .IF play_status & PLAY_PLAYING
                push eax
                ENTER_PLAY_SYNC GUI
                pop eax
            .ENDIF

            pop ecx             ;// ptr to filename ptr

            test eax, eax       ;// did we cancel ??
            jz init_and_done

        ;// got a new name, deal with it

            ;// edi points at where we initialized this
            ;// ecx points at where the file name goes
            ;// file_name_get_path points at our new name

        ;// get the return values and clear get_path

            mov ebx, filename_get_path  ;// get the returned path
            mov filename_get_path, 0    ;// always zero this

        ;// release and set our new name

            mov eax, [ecx]      ;// get our current name
            .IF eax             ;// is it valid ?
                DEBUG_IF <eax==ebx>     ;// returned filename == filename_last path ??!
                filename_PutUnused eax  ;// release our current name
            .ENDIF
            mov [ecx], ebx      ;// store our new name

        ;// set last path

            push esi
            lea esi, (FILENAME PTR [ebx]).szPath
            mov ebx, [edi]      ;// get last path
            .IF !ebx
                invoke filename_GetUnused   ;// get a new one
                mov [edi], ebx              ;// save it where it's spoosed to go
            .ENDIF
            invoke filename_InitFromString, FILENAME_FULL_PATH
            pop esi

        ;// cycle the filemode to initialize

            push [esi].dwUser       ;// need to save dwUser
            invoke file_CloseMode   ;// close existing mode
            pop eax                 ;// retrieve dwUser
            inc file_changing_name  ;// set this flag
            invoke file_OpenMode    ;// open new mode
            dec file_changing_name  ;// reset this flag

        ;// and we're outta here

            jmp redraw_init_and_done


        ;//////////////////////////////////////////////////////////////////////////////



;// MODE_COMMANDS

    _MODE_COMMANDS:

        cmp eax, ID_FILE_MODE_DATA  ;// redundant
        jb osc_Command

        ;// mask and merge values

        ;// these ids are consecutive
        ;// arithmetic will do the job

        cmp eax, ID_FILE_MODE_CSVWRITER
        ja osc_Command

        ;// prevent expensive duplicate button pushes
        mov edx, [esi].dwUser
        sub eax, (ID_FILE_MODE_DATA-1)  ;// turn command id into a mode index
        and edx, FILE_MODE_TEST
        cmp eax, edx
        je ignore_and_done

        .IF [esi].dwUser & FILE_MODE_TEST   ;// close any existing mode
            push eax
            invoke file_CloseMode
            pop eax
        .ENDIF

        or eax, [esi].dwUser    ;// must have the valid pin sates
        invoke file_OpenMode

;// EXIT POINTS

    redraw_init_and_done:

        mov eax, POPUP_SET_DIRTY OR POPUP_REDRAW_OBJECT OR POPUP_INITMENU OR POPUP_KILL_THIS_FOCUS
        jmp all_done

    set_new_trigger:

        and [esi].dwUser, edx
        or [esi].dwUser, ecx
        invoke file_VerifyPins

    dirty_redraw_and_done:

        mov eax, POPUP_SET_DIRTY OR POPUP_REDRAW_OBJECT
        jmp all_done

    init_and_done:

        mov eax, POPUP_INITMENU ;// OR POPUP_KILL_THIS_FOCUS
        jmp all_done

    file_get_name_bad::
    file_get_name_memory::
    ignore_and_done:

        mov eax, POPUP_IGNORE
        jmp all_done

    dirty_and_done:

        mov eax, POPUP_SET_DIRTY

    all_done:

        ret

file_Command ENDP


;///
;///    M E N U   I N T E R F A C E
;///
;///
;///////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////



;///////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////
;///
;///
;///    RENDER
;///
ASSUME_AND_ALIGN
file_Render PROC

        ASSUME esi:PTR OSC_FILE_MAP

    ;// render first

        invoke gdi_render_osc

    ;// show if we're clipping

        .IF play_status & PLAY_PLAYING
        .IF [esi].dwUser & FILE_MODE_IS_CLIPPING

            push edi
            push ebx
            push esi

            mov eax, F_COLOR_OSC_BAD
            OSC_TO_CONTAINER esi, ebx
            OSC_TO_DEST esi, edi        ;// get the destination
            mov ebx, [ebx].shape.pMask
            invoke shape_Fill

            pop esi
            pop ebx
            pop edi

        .ENDIF
        .ENDIF

    ;// print the file name, clip to the left
    ;// print the position

        GDI_DC_SELECT_FONT hFont_pin
        GDI_DC_SET_COLOR COLOR_OSC_TEXT

    ;// make some room for formatted text

        push [esi].rect.bottom
        push [esi].rect.right
        push [esi].rect.top
        push [esi].rect.left
        mov ebx, esp
        ASSUME ebx:PTR RECT

    ;// display the file name

        mov eax, [esi].dwUser
        and eax, FILE_MODE_TEST
        mov eax, [esi].file.filename_table[eax*4]
        .IF eax
            invoke DrawTextA, gdi_hDC, (FILENAME PTR [eax]).pName, -1, ebx, DT_SINGLELINE OR DT_BOTTOM OR DT_CENTER
        .ELSE
            pushd 'ema'
            pushd 'n on'
            mov eax, esp
            invoke DrawTextA, gdi_hDC, eax, 7, ebx, DT_SINGLELINE OR DT_BOTTOM OR DT_CENTER
            add esp, 8
        .ENDIF

        sub [ebx].bottom, 10

    ;// display the length

        sub esp, 16
        mov edx, esp
        invoke wsprintfA, edx, OFFSET file_szFmt, [esi].file.file_length
        mov edx, esp
        invoke DrawTextA, gdi_hDC, edx, eax, ebx, DT_SINGLELINE OR DT_BOTTOM OR DT_RIGHT
        sub [ebx].bottom, 10

    ;// display the position

        mov edx, esp
        invoke wsprintfA, edx, OFFSET file_szFmt, [esi].file.file_position
        mov edx, esp
        invoke DrawTextA, gdi_hDC, edx, eax, ebx, DT_SINGLELINE OR DT_BOTTOM OR DT_RIGHT

    ;// display the mode ?

    ;// clean up and split

        add esp, SIZEOF RECT + 16
        ret

file_Render ENDP

;///
;///    RENDER
;///
;///
;///////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////





;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;///
;///
;///    CTOR DTOR
;///

ASSUME_AND_ALIGN
file_Ctor PROC


        ;// register call
        ASSUME ebp:PTR LIST_CONTEXT ;// preserve
        ASSUME esi:PTR OSC_OBJECT   ;// preserve
        ASSUME edi:PTR OSC_BASE     ;// may_destroy
        ASSUME ebx:PTR FILE_OSC     ;// may destroy
        ASSUME edx:PTR FILE_HEADER  ;// may destroy

    ;// we've been created
    ;// dwUser has been loaded, but not the extra

        ASSUME esi:PTR OSC_FILE_MAP

        FILE_DEBUG_INITIALIZE

    ;// check if we're loading from a file or not

        .IF edx     ;// load the filename or id or nothing

            mov eax, [esi].dwUser
            and eax, FILE_MODE_TEST
            .IF !ZERO? && eax <= FILE_MODE_MAX

            ;// get the desired length

                mov edx, DWORD PTR [ebx+(SIZEOF FILE_OSC)+4]    ;// point at dwLength
                mov [esi].file.file_length, edx

            ;// initialize a filename for this object

                push esi    ;// have to preserve
                push eax    ;// save to simplify

                lea esi, [ebx+(SIZEOF FILE_OSC)+8]  ;// point at string source
                invoke filename_GetUnused           ;// returns in ebx
                invoke filename_InitFromString, 0   ;// accept bad paths (might be id
                test eax, eax
                pop eax
                pop esi

                .IF ZERO?   ;// got a bad filename
                    filename_PutUnused ebx  ;// release the name
                    xor ebx, ebx
                .ENDIF
                mov [esi].file.filename_table[eax*4], ebx

            .ELSE   ;// unknown mode

                mov [esi].dwUser, 0

            .ENDIF

        .ENDIF

    ;// make sure all modes are checked and initialized

        .IF !file_instance_count

            invoke file_InitializeModes

        .ENDIF
        inc file_instance_count

    ;// attach this object to the file hardware list

        ;// have hardware_ locate the correct device for us
        xor edx, edx
        invoke hardware_AttachDevice
        ;// then add this object to that devices list
        lea ecx, [esi].file
        ASSUME ecx:PTR OSC_FILE_DATA
        mov ebx, [esi].pDevice
        ASSUME ebx:PTR FILE_HARDWARE_DEVICEBLOCK
        dlist_InsertHead file_hardware,ecx,,ebx

    ;// open our mode, even if bad

        mov eax, [esi].dwUser   ;// must enter with pin states
        mov [esi].dwUser, 0     ;// have to clear
        invoke file_OpenMode    ;// calls file_VerifyPins

    ;// that's it

        ret

file_Ctor ENDP

;/////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
file_Dtor PROC

        ASSUME esi:PTR OSC_FILE_MAP

    ;// close any modes we might have

        invoke file_CloseMode

    ;// release filenames
    ;// there are a number of the these in consecutive order

        push esi
        mov ecx, FILE_MODE_MAX
        lea esi,[esi].file.filename_Data
        .REPEAT
            lodsd
            .IF eax
                filename_PutUnused eax
            .ENDIF
            dec ecx
        .UNTIL ZERO?
        pop esi

    ;// detatch ourselves from the hardware list

        ;// then add this object to that devices list
        lea ecx, [esi].file
        ASSUME ecx:PTR OSC_FILE_DATA
        mov ebx, [esi].pDevice
        ASSUME ebx:PTR FILE_HARDWARE_DEVICEBLOCK
        dlist_Remove file_hardware,ecx,,ebx
        ;// then have hardware detach this object from the device
        invoke hardware_DetachDevice

    ;// keep track of the instance count

        dec file_instance_count
        DEBUG_IF <SIGN?>
        .IF ZERO?

            invoke file_DestroyModes

        .ENDIF

    ;// that's it

        ret

file_Dtor ENDP


;///
;///
;///    CTOR DTOR
;///
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////






;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;///
;///
;///    LOAD SAVE      file and undo
;///
comment ~ /*

    file parameters are stored as dwUser,file_size,file_name
    if file mode or filename is bad, then 4 zero bytes are stored

*/ comment ~

ASSUME_AND_ALIGN
file_AddExtraSize PROC

    ASSUME esi:PTR OSC_FILE_MAP     ;// preserve
    ASSUME edi:PTR OSC_BASE     ;// preserve
    ASSUME ebx:PTR DWORD        ;// preserve
    DEBUG_IF <edi!!=[esi].pBase>

    ;// task: determine how many extra bytes this object needs
    ;//       ADD it to [ebx]

    ;// do NOT include anything but the extra count
    ;// meaning do not include the size of the common OSC_FILE header

    ;// add size of dwuser, and size

        add [ebx], 8        ;// sizeof(dwUser) + sizeofof(file_size)

    ;// determine the length of our filename

        mov eax, [esi].dwUser
        and eax, FILE_MODE_TEST
        jz no_name
        mov eax, [esi].file.filename_table[eax*4]
        test eax, eax
        jz no_name
        mov eax, (FILENAME PTR [eax]).dwLength
        inc eax         ;// add 1 for terminator
        test eax, 3     ;// dword align
        jz got_size
        add eax, 3
        and eax, -4
        jmp got_size
    no_name:
        mov eax, 4
    got_size:
        add [ebx], eax      ;// accumulate to ebx

    ;// that's it

        ret


file_AddExtraSize ENDP

ASSUME_AND_ALIGN
file_Write PROC

    ASSUME esi:PTR OSC_FILE_MAP     ;// preserve
    ASSUME edi:PTR FILE_OSC     ;// iterate as required

    ;// task:   iterate edi as required
    ;//         edi must end up at pin table
    ;//         set extra count, store dwUser, store filename

        push edi    ;// save for a moment

    ;// store dwUser

        add edi, SIZEOF FILE_OSC
        mov eax, [esi].dwUser
        stosd

    ;// store file_size

        mov eax, [esi].file.file_length
        stosd

    ;// store the file name, keep track of size

        mov eax, [esi].dwUser
        and eax, FILE_MODE_TEST
        jz no_name

        mov eax, [esi].file.filename_table[eax*4]
        test eax, eax
        jz no_name

        push esi        ;// must preserve
        mov ecx, (FILENAME PTR [eax]).dwLength
        lea esi, (FILENAME PTR [eax]).szPath
        inc ecx
        rep movsb
        pop esi         ;// must preserve
        mov ecx, (FILENAME PTR [eax]).dwLength
        add ecx, 9  ;// terminator + 2 dwords
        xor eax, eax
    @@:
        test ecx, 3 ;// dword align
        jz got_size
        inc ecx
        stosb
        jmp @B

    no_name:

        xor eax, eax
        stosd
        mov ecx, 12

    got_size:   ;// set extra count

        pop ebx
        mov (FILE_OSC PTR [ebx]).extra, ecx

    ;// simple as that

        ret

file_Write ENDP

ASSUME_AND_ALIGN
file_SaveUndo   PROC

        ASSUME esi:PTR OSC_FILE_MAP

    ;// edx enters as either UNREDO_CONTROL_OSC or UNREDO_COMMAND
    ;// edi enters as where to store
    ;//
    ;// task:   1) save nessary data
    ;//         2) iterate edi
    ;//
    ;// may use all registers except ebp

    ;// store dwuser

        mov eax, [esi].dwUser
        stosd

    ;// store the size (may be ignored

        mov eax, [esi].file.file_length
        stosd

    ;// store the name

        mov eax, [esi].dwUser
        and eax, FILE_MODE_TEST
        jz no_name

        mov eax, [esi].file.filename_table[eax*4]
        test eax, eax
        jz no_name

        mov ecx, (FILENAME PTR [eax]).dwLength
        lea esi, (FILENAME PTR [eax]).szPath
        inc ecx
        rep movsb

    ;// make sure edi is dword aligned
    @@: xor eax, eax
        test edi, 3
        jz all_done
        stosb
        jmp @B

    no_name:

        xor eax, eax
        stosd

    all_done:

        ret

file_SaveUndo ENDP



comment ~ /*

file_LoadUndo

    this routine was surprisingly complicated
    a state table helped

    general rule: can not undo size changes

    allowable mode name combinations

    name mode       note: the state of bad mode + good name
    good good           is not possible (there is no way to
     x    0     0       determine which name is bad)
     0    1     1
     1    1     3   it is possible to switch to a new mode that has an existing name
                    init_name must acount for this

 s |                     |
 t | INPUT STATES        | ACTIONS (in required order)
 a |                     |
 t | cur  new            | cls  init OpenMode (1)
 e | mode mode dif  dif  | cur  name  or
 s | name name mode name | mode  *** VerifyPins (0)
 -------3----3----2----2----------------------------
 4 |  0    0    x    x   |  0    0    0  <-- this should not happen (but will for size changes)
 4 |  0    1    x    x   |  0    1    1  <-- init_name will release any name at the new mode
 4 |  0    3    x    x   |  0    1    1
 4 |  1    0    x    x   |  1    0    0  <-- do not open bad mode if current mode is closed
 2 |  1    1    0    x   |  0    0    0  <-- modes are same, pins may be different ?
 2 |  1    1    1    x   |  1    1    1  <-- init_name will release any name at the new mode
 2 |  1    3    0    x   |  1    1    1  <-- clycle mode to force name change
 2 |  1    3    1    x   |  1    1    1
 4 |  3    0    x    x   |  1    0    0  <-- do not open bad mode if current mode is closed
 2 |  3    1    0    x   |  1    1    1  <-- init_name will release name, cycle mode force name change
 2 |  3    1    1    x   |  1    1    1  <-- init_name will release any name at the new mode
 1 |  3    3    0    0   |  0    0    0  <-- mode same, name same, must be pin change
 1 |  3    3    0    1   |  1    1    1  <-- cycle open close to force OS to change name
 2 |  3    3    1    x   |  1    1    1  <-- same name different mode is unlikely
----
=36

ACTION notes

    do not open for bad modes (assume that close mode has done it's job)
    call open mode with bad name to set the MODE_IS flags

*** init_name must either succeed with a new valid name
    or fail and release any existing name

    if new name is good
        if old name doesn't exist
            get unused name
            assign to correct filename
        end if
        init name
    elseif old name exists
        release old name
        reset correct filename
    end if

------------------------------------------------------------------------------------------

    the above table may be reduced by
        addition of equivalent x's
        adding !0 tests

 s |                     |
 t | INPUT STATES        | ACTIONS (in required order)
 a |                     |
 t | cur  new            | cls  init OpenMode (1)
 e | mode mode dif  dif  | cur  name  or
 s | name name mode name | mode  *** VerifyPins (0)
 -------3----3----2----2-|---------------|hex-------
 4 |  0    0    x    x   |  0    0    0  | 0    <-- this should not happen (but will for size changes)
 8 |  0   !0    x    x   |  0    1    1  | 3    <-- init_name will release any name at the new mode
 8 | !0    0    x    x   |  1    0    0  | 4    <-- do not open bad mode if current mode is closed
 2 |  1    1    0    x   |  0    0    0  | 0    <-- modes are same, pins may be different
 2 |  1    1    1    x   |  1    1    1  | 7    <-- init_name will release any name at the new mode
 4 |  1    3    x    x   |  1    1    1  | 7    <-- clycle mode to force name change
 4 |  3    1    x    x   |  1    1    1  | 7    <-- init_name will release name, cycle mode force name change
 2 |  3    3    1    x   |  1    1    1  | 7    <-- same name different mode is unlikely
 1 |  3    3    0    1   |  1    1    1  | 7    <-- cycle open close to force OS to change name
 1 |  3    3    0    0   |  0    0    0  | 0    <-- mode same, name same, must be pin change
----
=36

*/ comment ~


ASSUME_AND_ALIGN
file_LoadUndo PROC

        ASSUME esi:PTR OSC_FILE_MAP     ;// preserve
        ASSUME ebp:PTR LIST_CONTEXT ;// preserve

    ;// edx enters as either UNREDO_CONTROL_OSC or UNREDO_COMMAND
    ;// edi enters as where to load
    ;//
    ;// task:   1) load nessary data
    ;//         2) do what it takes to initialize it
    ;//
    ;// may use all registers except ebp and esi
    ;// return will invalidate HINTI_OSC_UPDATE

    ;// see notes above

    ;// PROCESS INPUT STATES
                        ;// cur  new            |
                        ;// mode mode dif  dif  |
                        ;// name name mode name |  state
        mov eax, [esi].dwUser
        mov edx, [edi]
        and eax, FILE_MODE_TEST
        jnz T0
    ;// 0    ?    ?    ?
        and edx, FILE_MODE_TEST
        jz state_0      ;//  0    0    x    x   |  0
        jmp state_3     ;//  0   !0    x    x   |  3
    T0:
    ;// !0  ?   ?   ?
        and edx, FILE_MODE_TEST
        jz state_4      ;// !0    0    x    x   |  4
    ;// !0  !0  ?   ?
        mov ebx, [esi].file.filename_table[eax*4]
        test ebx, ebx
        jnz T1
    ;// 1   !0  ?   ?
        cmp BYTE PTR [edi+8], 0
        jne state_7     ;//  1    3    x    x   |  7
    ;// 1    1  ?   ?
        cmp eax, edx
        jne state_7     ;//  1    1    1    x   |  7
        jmp state_0     ;//  1    1    0    x   |  0
    T1:
    ;// 3   !0  ?   ?
        cmp BYTE PTR [edi+8], 0
        je state_7      ;//  3    1    x    x   |  7
    ;// 3   3   ?   ?
        cmp eax, edx
        jne state_7     ;//  3    3    1    x   |  7
    ;// 3   3   0   ?
        lea eax, (FILENAME PTR [ebx]).szPath
        lea edx, [edi+8]
        invoke lstrcmpiA, eax, edx
        test eax, eax
        je state_0      ;//  3    3    0    0   |  0    0    0  | 0
        jmp state_7     ;//  3    3    0    1   |  1    1    1  | 7

    ;// PROCESS ACTION STATES

                ;// | cls  init OpenMode (1)
                ;// | cur  name  or
                ;// | mode  *** VerifyPins (0)

    state_4:    ;// |  1    0    0  | 4

        invoke file_CloseMode

    state_0:    ;// |  0    0    0  | 0

        mov eax, [edi]
        mov [esi].dwUser, eax
        invoke file_VerifyPins
        jmp all_done


    state_7:    ;// |  1    1    1  | 7

        invoke file_CloseMode

    state_3:    ;// |  0    1    1  | 3

    ;// init_new_name

        mov edx, [edi]
        and edx, FILE_MODE_TEST
        mov ebx, [esi].file.filename_table[edx*4]

        .IF BYTE PTR [edi+8]    ;// if new name is good
            push esi
            .IF !ebx            ;// if old doesn't exist
                invoke filename_GetUnused
                mov edx, [edi]
                and edx, FILE_MODE_TEST
                mov [esi].file.filename_table[edx*4], ebx
            .ENDIF
            lea esi, [edi+8]
            invoke filename_InitFromString, 0
            pop esi
        .ELSEIF ebx             ;// else if old name exists
            filename_PutUnused ebx
            mov [esi].file.filename_table[edx*4], 0
        .ENDIF

    ;// open mode

        mov edx, [edi+4]        ;// get the size
        mov eax, [edi]          ;// get the mode
        mov [esi].file.file_length, edx ;// store the size
        invoke file_OpenMode    ;// open the mode

    all_done:

        ret

file_LoadUndo ENDP


;///
;///
;///    LOAD SAVE      file and undo
;///
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////





ASSUME_AND_ALIGN
file_GetUnit PROC

        ASSUME esi:PTR OSC_FILE_MAP
        ASSUME ebx:PTR APIN

    comment ~ /*

        task: xfer LR in LR out units to other pins

    */ comment ~

        lea ecx, [esi].pin_Lin  ;// target pin
        xor eax, eax
        lea edx, [esi].pin_Lout ;// unit source pin
        cmp ecx, ebx            ;// Lin
        je check_the_pins
        add ecx, SIZEOF APIN    ;// Rin
        add edx, SIZEOF APIN    ;// Rout
        cmp ecx, ebx
        je check_the_pins
        xchg ecx, edx
        cmp ecx, ebx
        je check_the_pins
        sub ecx, SIZEOF APIN    ;// Lout
        sub edx, SIZEOF APIN    ;// Lin
        cmp ecx, ebx
        jne all_done

    check_the_pins:

        ASSUME edx:PTR APIN ;// source for units
        mov eax, [edx].dwStatus

    all_done:

        BITT eax, UNIT_AUTOED

        ret

file_GetUnit ENDP



ASSUME_AND_ALIGN

ENDIF   ;// USE_THIS_FILE

END

