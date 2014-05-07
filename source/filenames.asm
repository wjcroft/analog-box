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
;//     filenames.asm           data and routines to work with file names
;//                             fileopen/save dialog
;//                             name conversion routines
;//                             app title
;//                             circuit and group strings
;// 
;// TOC
;//

;// filename_GetUnused
;//
;// filename_InitFromString
;// filename_ChangeDirectoryTo
;//
;// filename_Initialize
;// filename_Destroy

;// filename_BuildDefaultCircuitPath
;// filename_SyncAppTitle
;//
;// filename_ONF2Proc
;// filename_OFNHookProc
;// filename_GetFileName
;//
;// filename_QueryAndSave
;//
;// filename_PackMRU
;// filename_SyncMRU




OPTION CASEMAP:NONE
.586
.MODEL FLAT

    .NOLIST
    INCLUDE <abox.inc>
    .LIST

.DATA


comment ~ /*

FILENAME

    file names are wrapped in a FILENAME struct
    it contains
        full path 
        pointer to name
        pointer to extension
        length

    there is then a pool of filenames

    the app then uses pointers to the cache


use filename_GetUnused to obtain a non intialized FILENAME
use filename_InitFromString to initialize it
use filename_PutUnused to release the name


*/ comment ~


    pool_Declare_internal filename ;//, FILENAME, 16 

    filename_circuit_path   dd  0   ;// points at current circuit name  

    filename_app_path       dd  0   ;// points at the app path
    filename_plugin_path    dd  0   ;// last registerde plugin
    filename_data_path      dd  0   ;// last file object we used
    filename_reader_path    dd  0   ;// last media file we opened
    filename_writer_path    dd  0   ;// last media file we opened
    filename_csvreader_path dd  0   ;// last csv file we opened
    filename_csvwriter_path dd  0   ;// last csv file we opened
    filename_bitmap_path    dd  0   ;// last bitmap we saved

    filename_mru1_path      dd  0
    filename_mru2_path      dd  0
    filename_mru3_path      dd  0
    filename_mru4_path      dd  0
    filename_mru5_path      dd  0   ;// external load
    filename_paste_path     dd  0   ;// aka mru6, don't move this

    filename_get_path       dd  0   ;// transfer area for getting filenames

    szUntitled  db  'Untitled_00',0 ;// default file name
    ALIGN 4
    

.CODE





;////////////////////////////////////////////////////////////////////
;//
;//
;//     filename    utility functions
;//


ASSUME_AND_ALIGN
filename_GetUnused  PROC

    ;// returns an unused entry in ebx

    ;//  uses eax, edx, ecx and ebx

    pool_GetUnused filename, ebx

    xor eax, eax
    mov [ebx].pName, eax
    mov [ebx].pExt, eax
    mov [ebx].dwLength, eax

    ret

filename_GetUnused  ENDP



ASSUME_AND_ALIGN
filename_InitFromString PROC STDCALL USES edi bFull:DWORD

    ;// FILENAME_SPACE_TERMINATED   EQU 1   ;// unquoted spaces terminate the name
    ;// FILENAME_FULL_PATH          EQU 2   ;// expand entry to a full path

    ;// this function transfers a space or zero terminated string to filename
    ;// then verifies that it is a full path name
    ;// removes quotes
    ;// sets pName
    ;// sets pExt
    ;// set dwLength
    ;// 
    ;// returns:
    ;//
    ;//     eax = 1 if all went well
    ;//     eax = 0 for error
    ;//     esi at one passed whatever terminated the string

        ASSUME ebx:PTR FILENAME ;// FILENAME to be intialized (presereved)
    ;// ASSUME esi:PTR BYTE     ;// location of string, iterated

        ;// stack 
        ;// esi edi ret bFull
        ;// 0   4   8   12

        mov edi, ebx    ;// edi has to point at the destination
        
        call parse_and_xfer
        ;// edx returns with flags
        ;// esi is at end of string
        ;//     dl 1 if tilde was found     indicates a dos 8.3 path name
        ;//     dl 2 if colon was found     indicates a drive letter
        ;//     dl 4 if slash was found     indicates a full path
        ;//     dl 8 if dot was found       indicates a file extension

        mov eax, 1  ;// assume we passed

        .IF (bFull & FILENAME_FULL_PATH) && ( (dl != 0Eh) || (dl & 1) )

        ;// ABOX233 - if the input string was surrounded by quotes
        ;// we have to remove them, or GetFullPath fails
        ;// so we want to point get path at [ebx]
        ;// and store to the stack

            push esi                ;// save the end of the origonal source string          
            sub esp, 280            ;// max path buffer on the stack
            lea esi, [ebx].szPath   ;// point at the new source
            mov edx, esp            
            invoke GetFullPathNameA, esi, 280, edx, 0           
            mov edi, ebx            ;// point edi at the destination
            mov esi, esp            ;// point esi at the source         
            call parse_and_xfer
            add esp, 280
            pop esi

            and dl, NOT 1   ;// turn off the tilde bit
            mov eax, 1      ;// assume we passed
            .IF (dl != 0Eh)
                dec eax ;// fail
            .ENDIF

        .ENDIF

    ;// double check that we passed, dwLength must be no zero
    ;// eax already has the assumed pass/fail flag

        .IF [ebx].dwLength == 0
            xor eax, eax
        .ENDIF

    ;// that should do it

        ret               


    ASSUME_AND_ALIGN
    parse_and_xfer:

        ASSUME ebx:PTR FILENAME
    
    ;// edi must point at destination
    ;// esi must point at source    

    ;// xfers esi to edi
    ;// removes quotes
    ;// sets
    ;//     dl 1 if tilde was found     indicates a dos 8.3 path name
    ;//     dl 2 if colon was found     indicates a drive letter
    ;//     dl 4 if slash was found     indicates a full path
    ;//     dl 8 if dot was found       indicates a file extension

        xor eax, eax
        sub ecx, ecx
        mov edx, eax    

        stosd       ;// zero pName
        stosd       ;// zero pExt
        stosd       ;// zero dwLength

        mov [ebx].pName, edi;// set the pName(make sure it points to something)

    ;// ABOX232
    ;// special test to check for network drives
    ;// see if name begins with a double slash
    ;// if yes, the state that we have a colon
        .IF (WORD PTR [esi]) == '\\'
            or dl, 2            ;// set the got colon flag
        .ENDIF
    ;// ABOX232

    top_of_loop:

        lodsb

        CMPJMP al, '"',     je got_quote        ;// got quote flag  
        CMPJMP al, '/',     je got_slash
        CMPJMP al, 5Ch,     je got_backslash    ;// got slash flag
        CMPJMP al, '~',     je got_tilde        ;// got tilde flag
        CMPJMP al, ' ',     je got_space
        CMPJMP al, ':',     je got_colon        ;// got colon flag
        CMPJMP al, '.',     je got_dot          ;// got dot ??
        CMPJMP al, ah,      je done_with_string ;// nul terminated

    store_character:

        stosb
        inc [ebx].dwLength
        jmp top_of_loop

    got_quote:
    
        xor cl, -1          ;// flip the in quote flag
        jnz top_of_loop     ;// continue if setting
        jmp done_with_string;// otherwise we're done
        
    got_slash:  
        
        mov al, '\'         ;// convert to back slash

    got_backslash:
        
        stosb               ;// store character
        inc [ebx].dwLength  ;// bump the length
        mov [ebx].pName, edi;// set the pName
        or dl, 4            ;// set the got slash flag
        jmp top_of_loop     ;// continue on

    got_tilde:              

        or dl, 1            ;// set the got tilde flag
        jmp store_character

    got_space:

        test cl, cl         ;// in quote ?
        jnz store_character ;// continue if so
        test bFull, FILENAME_SPACE_TERMINATED   ;// supposed to stop at unquted spaces ?
        jnz done_with_string;// were don if yes
        jmp store_character ;// otherwise contiune on

    got_colon:

        or dl, 2            ;// set the got colon flag
        jmp store_character

    got_dot:

        stosb               ;// store the char
        inc [ebx].dwLength  ;// bump the length
        mov [ebx].pExt, edi ;// save the extension pointer
        or dl, 8            ;// set the got dot flag
        jmp top_of_loop     ;// continue on

    done_with_string:
    
        mov al, ah          ;// ah = 0
        stosb               ;// terminate

        retn

filename_InitFromString ENDP

ASSUME_AND_ALIGN
filename_CopyNewDirectory PROC STDCALL uses esi edi ebx pName:DWORD, pDir:DWORD

    ;// returns a new FILENAME with pName changed to the directory stated by pDir

    ;// get an unused FILENAME

        invoke filename_GetUnused
        ASSUME ebx:PTR FILENAME

        ASSUME edx:PTR FILENAME ;// used below

        DEBUG_IF <!!pDir>       ;// bad parameter
        DEBUG_IF <!!pName>      ;// bad parameter

    ;// copy directory

        mov edx, pDir           ;// get the directory

        mov ecx, [edx].pName    ;// point at name portion
        DEBUG_IF <!!ecx>        ;// bad filename
        sub ecx, edx            ;// bytes from start to name
        sub ecx, FILENAME.szPath;// remove header bytes

        lea esi, [edx].szPath   ;// point at source string
        
        mov edi, ebx            ;// point at dest string
        xor eax, eax            ;// clear for zeroing
        stosd           ;// clear pName
        stosd           ;// clear pExt
        stosd           ;// clear length

        mov [ebx].dwLength, ecx ;// start of dwLength

        rep movsb               ;// copy up to the directy
        mov [ebx].pName, edi    ;// store the name

    ;// copy the name

        mov edx, pName
        mov esi, [edx].pName
        DEBUG_IF <!!esi>        ;// bad name

        S1: lodsb               ;// get the char
            cmp al, '.'         ;// check for a dot
            stosb               ;// store the char
            jne S2              
            mov [ebx].pExt, edi ;// set the extension
        S2: test al, al         ;// check for done
            jz S3               
            inc [ebx].dwLength  ;// bump the length
            jmp S1

        S3: ;// done with string

    ;// that should do

        mov eax, ebx
        ret

filename_CopyNewDirectory ENDP


;//
;//     filename    utility functions
;//
;//
;////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////
;//
;//
;//     filename public interface
;//


ASSUME_AND_ALIGN
filename_Initialize PROC

    ;// task:   define filename_app_path
    ;//         define filename_get_path as the commmand line arg
    ;//
    ;// returns ebx as the command line (or zero for none)
    ;// rely on filename_get_path to load the circuit
    
    ;// get the command line
    
        invoke GetCommandLineA
        mov esi, eax
        ASSUME esi:PTR BYTE

;//ECHO TESTING ERASEME
;//invoke MessageBoxA, 0, esi, 0, IDOK

    ;// get an unused filename

        invoke filename_GetUnused
        ASSUME ebx:PTR FILENAME
        mov filename_app_path, ebx  ;// store it now
        invoke filename_InitFromString, FILENAME_SPACE_TERMINATED OR FILENAME_FULL_PATH
        DEBUG_IF <!!eax>    ;// couldn't parse the app name ?!! this is bad

    ;// now we check for a command line
    ;// esi returns at one passed the character that terminated the previous string

        ;// check if a zero terminated it
        cmp [esi-1], 0
        je got_no_command_name

        .REPEAT
            lodsb
            cmp al, 0
            je got_no_command_name
            cmp al, ' '
        .UNTIL !ZERO?
        dec esi
    
    ;// esi is at the beginning of a new string
        
    ;// we may have an arg ???
    
    ;// must have a command line

        invoke filename_GetUnused   ;// locate unused slot      
        invoke filename_InitFromString, FILENAME_SPACE_TERMINATED OR FILENAME_FULL_PATH
        test eax, eax               ;// see if we succeeded     
        jnz got_good_command_name

    got_bad_command_name:

        filename_PutUnused ebx ;// release this

    got_no_command_name:

        xor ebx, ebx

    got_good_command_name:

        mov filename_get_path, ebx  ;// store the name

        ret


filename_Initialize ENDP

ASSUME_AND_ALIGN
filename_Destroy PROC

    pool_Destroy filename
    ret

filename_Destroy ENDP








ASSUME_AND_ALIGN
filename_BuildDefaultCircuitPath    PROC

    ;// action directory --> unused FILE_NAME --> filename_circuit_path
    ;//                  --> bIsUntitled

    ;// uses esi edi ebx

    ;// return the new FILE_NAME in ebx 
    ;// this will be the new circuit_path
    ;// the old one is released if there is one

    ;// Untitled_00.ABox2
    ;// use directory of the last loaded path
    ;// if there is none, use the path of the executable

    ;// get a directory to work with
    ;// return the filename in ebx to use as a directory

        ASSUME ebx:PTR FILENAME

        xor ebx, ebx
        or ebx, filename_circuit_path   ;// is there already a circuit path ?
        jz S1

    S0: ;// this is hit from COMMAND_NEW

        mov ebx, filename_circuit_path  ;// useit       
        jmp S4
                
    S1: ;// this is hit at app start
    
        or ebx, filename_mru1_path      ;// try the mru list
        jnz S3
    
    S2: ;// this is hit at the very first install
    
        mov ebx, filename_app_path      ;// build from filename_app_path
            
    S3: ;// ebx points at the filename of the directory to use
        
        lea esi, [ebx].szPath           ;// point at the path
        invoke filename_GetUnused       ;// locate a new record
        invoke filename_InitFromString, FILENAME_FULL_PATH  ;// initialize from the path
        mov filename_circuit_path, ebx  ;// store as new circuit path
    
    S4: ;// now ebx points at the FILENAME to base the new name on

    ;// build the default untitled name

        mov edi, [ebx].pName            ;// point at the name for next section
        lea esi, szUntitled
        mov ecx, (SIZEOF szUntitled)
        rep movsb
        mov [ebx].pExt, edi ;// store the exension (one passed dot)
        dec edi             ;// because we copied the terminator
        mov eax, 'oBA.'     ;// load first bytes of extension
        stosd
        mov eax, '2x'       ;// load next bytes of extension
        stosd

    ;// determine the new length of the name

        lea edi, [ebx].szPath
        xor eax, eax 
        STRLEN edi
        mov [ebx].dwLength, eax

    ;// now we iterate until we dont find the file

        lea edi, [ebx].szPath   ;// point edi at full path
        mov esi, [ebx].pName    ;// point esi at Untitled_XX
        ASSUME esi:PTR BYTE

        sub esp, SIZEOF WIN32_FIND_DATA
    
    top_of_verify:  ;// iterate until we get invalid handle

        invoke FindFirstFileA, edi, esp
        inc eax         ;// INVALID_HANDLE_VALUE = -1       
        jz verify_done
                
        dec eax                 ;// this file exists
        invoke FindClose, eax   ;// close the find handle

        inc [esi+10]            ;// increase the lower digit

        cmp [esi+10], ':'       ;// check for wrap
        jne top_of_verify       ;// loop if no wrap
    
        mov [esi+10], '0'       ;// reset to zero
        inc [esi+9]             ;// increase the higher digit

        cmp [esi+9], ':'        ;// check for wrap
        jne top_of_verify       ;// loop if no wrap

        mov [esi+9], 'A'        ;// set to A (lot's of file)
        jmp top_of_verify       ;// jmp to top

        ;// max names 100 + 26 * 10 = 360

    verify_done:

        add esp, SIZEOF WIN32_FIND_DATA

    ;// set the is untitled flag

        or mainmenu_mode, MAINMENU_UNTITLED

    ;// and we are done !

        ret

filename_BuildDefaultCircuitPath    ENDP



ASSUME_AND_ALIGN
filename_SyncAppTitle   PROC uses esi edi ebx

    ;// task: format and set the app title

;// app_title "jambot_31 ABox 2.0 "
    
        xor ebx, ebx
        or ebx, filename_circuit_path

    ;// make sure we have a deafult name

        jnz @F
            invoke filename_BuildDefaultCircuitPath
        @@:
        ASSUME ebx:PTR FILENAME
    
    ;// get pointer to the app title
    ;// the append circuit name and app string
            
        sub esp, 280
        mov edi, esp

        mov esi, [ebx].pName        

        xor eax, eax    ;// clear for byte copy
        push edi        ;// store the new app title

    ;// store the dirty indicater

        xor eax, eax
        .IF unredo_we_are_dirty
            mov ax, ' *'
            stosw
            xor eax, eax
        .ENDIF
        
    ;// store the circuit name

    @@: 
        lodsb       ;// string copy the name
        cmp al, '.' ;// don't store the dot
        jz @F
        test al, al ;// just incase things are really screwed up
        jz @F       
        stosb
        jmp @B
    @@: 

    ;// store the app title
    
        mov eax, 'oBA '
        stosd
        mov al,'x'
        stosb
        mov eax, ABOX_VERSION_STRING_REVERSE
        stosd
        
    ;// ABOX242 AJT -- we'll get a little sophisticated for the various versions

        IFDEF ALPHABUILD
            IFDEF DEBUGBUILD
                ;//' DEBUG ALPHA'
                mov eax, 'BED '
                stosd
                mov eax, 'A GU'
                stosd
                mov eax, 'AHPL'
                stosd
            ELSE
                ;//' RELEASE ALPHA'
                mov eax, 'LER '
                stosd
                mov eax, 'ESAE'
                stosd
                mov eax, 'PLA '
                stosd
                mov eax, 'AH'
                stosw
            ENDIF
        ELSEIFDEF DEBUGBUILD
                ;//' DEBUG BETA'
                mov eax, 'BED '
                stosd
                mov eax, 'B GU'
                stosd
                mov eax, 'ATE'
                stosd
        ENDIF
    
    ;//  then terminate it
    
        xor eax, eax
        stosd
        
    ;// set the window title

        push hMainWnd

        call SetWindowTextA

        add esp, 280

    ;// shut the flag off

        and app_bFlags, NOT APP_SYNC_TITLE

        ret

filename_SyncAppTitle ENDP



;//
;//
;//     filename public interface
;//
;////////////////////////////////////////////////////////////////////










;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;///
;///
;///
;///    G E T   F I L E N A M E 
;///
;///



.DATA

    ofnKludgeProc    dd 0 ;//
    getfilename_mode dd 0 ;//

;// 
;// parameter table for filename_GetFilename
;// 

    ;// algorithm
    ;//
    ;//     if initializer is given
    ;//         use that for both init directory and init name
    ;//     else
    ;//         use filename_circuit_path or filename_app_path
    ;//         if defname is given
    ;//             append that to initializer
    ;//         else
    ;//             append defext to circuit name
    
    ;// GETFILENAME_OPEN        equ 0   ;// retreives a new file to load
    ;// GETFILENAME_SAVEAS      equ 1   ;// retrieves the save name
    ;// GETFILENAME_PASTEFROM   equ 2   ;// retrieves a file to paste
    ;// GETFILENAME_SAVEBMP     equ 3   ;// save as a bitmap

    ;// GETFILENAME_PLUGIN      equ 4   ;// find a plugin

    ;// GETFILENAME_DATA        equ 5   ;// retrieves a name for an osc_File object
    ;// GETFILENAME_READER      equ 6   ;// media reader
    ;// GETFILENAME_WRITER      equ 7   ;// media writer

    ;// GETFILENAME_CSVWRITER   equ 8   ;// csv writer
    ;// GETFILENAME_CAVREADER   equ 9   ;// csv reader


    GETFILENAME_TABLE   STRUCT

        opfn_flags      dd  0   ;// flags for open filename
        psz_title       dd  0   ;// title string for the dialog
        psz_filter      dd  0   ;// pointer to the filter strinng
        psz_defext      dd  0   ;// default extention for the dialog
        
        psz_defname     dd  0   ;// pointer to initial name if a default initilaizer is used
        psz_button      dd  0   ;// desired button text
        initializer     dd  0   ;// pointer to pointer to filename used to initializethe dialog
        dwFlags         dd  0   ;// things we want to do
    
    GETFILENAME_TABLE ENDS      

    GETFILENAME_FORCE_DEFNAME   EQU 00000001h   ;// force the use of default name from table
    GETFILENAME_USE_SUBHOOK     EQU 00000002h   ;// use the sub hook


;//
;// string resources for filename_GetFilename
;//

    ;// format
    ;//
    ;//     sz_ACTION_  filter      displayed in the file type box
    ;//                 defname     name to use as initializer is one is not specified
    ;//                 defext      forced extension
    ;//
    ;//     strings may be (and are) overlapped



;// open save paste

    sz_paste_filter         LABEL BYTE  
    sz_open_filter          db  'ABox files (*.abox2;*.abox)',0,'*.ABox2;*.ABox',0,0
    sz_paste_title          db  'Paste from File',0
    sz_paste_button         db 'Paste',0

    sz_saveas_filter        db  'ABox2 files (*.abox2)',0       ;// single terminator
    sz_paste_defname        LABEL BYTE
    sz_open_defname         db  '*.'                            ;// no terminator
    sz_saveas_defext        LABEL BYTE
    sz_paste_defext         LABEL BYTE
    sz_open_defext          db  'ABox2',0,0                     ;// double terminator

    GETFILENAME_OPEN_FLAGS  EQU OFN_FILEMUSTEXIST OR OFN_PATHMUSTEXIST OR OFN_HIDEREADONLY OR OFN_LONGNAMES OR OFN_EXPLORER
    GETNAME_FLAGS_OPEN      EQU 0

    sz_open_title           EQU 0
    sz_open_button          EQU 0
    getfilename_path_open   TEXTEQU <filename_circuit_path>

    GETFILENAME_SAVEAS_FLAGS EQU OFN_OVERWRITEPROMPT OR OFN_HIDEREADONLY OR OFN_LONGNAMES OR OFN_EXPLORER OR OFN_ENABLEHOOK
    GETNAME_FLAGS_SAVEAS    EQU GETFILENAME_USE_SUBHOOK
    sz_saveas_title         EQU 0
    sz_saveas_defname       EQU 0   ;// builds circuit name + .abox2
    sz_saveas_button        EQU 0
    getfilename_path_saveas TEXTEQU <filename_circuit_path>

    GETFILENAME_PASTE_FLAGS EQU OFN_FILEMUSTEXIST OR OFN_PATHMUSTEXIST OR OFN_HIDEREADONLY OR OFN_LONGNAMES OR OFN_EXPLORER OR OFN_ENABLEHOOK
    GETNAME_FLAGS_PASTE     EQU 0
    getfilename_path_paste  TEXTEQU <filename_paste_path>

;// bitmap
    
    GETFILENAME_BITMAP_FLAGS EQU OFN_OVERWRITEPROMPT OR OFN_HIDEREADONLY OR OFN_LONGNAMES OR OFN_EXPLORER
    sz_bitmap_title         db  'Save As a Bitmap',0
    sz_bitmap_filter        db  'Bitmap files (*.bmp)',0,'*.'   ;// no terminator
    sz_bitmap_defext        db  'bmp',0,0                       ;// double terminator

    sz_bitmap_defname       EQU 0       ;// builds circuit name + .bmp
    sz_bitmap_button        EQU 0
    getfilename_path_bitmap TEXTEQU <filename_bitmap_path>
    GETNAME_FLAGS_BITMAP    EQU 0

;// plugin 

    GETFILENAME_PLUGIN_FLAGS EQU OFN_HIDEREADONLY OR OFN_FILEMUSTEXIST OR OFN_PATHMUSTEXIST OR OFN_LONGNAMES OR OFN_EXPLORER OR OFN_ENABLEHOOK OR OFN_ALLOWMULTISELECT
    sz_plugin_title         db  'Register VST plugins', 0
    sz_plugin_filter        db  'VST Plugin Files (*.dll)',0    ;// single terminator
    sz_plugin_defname       db  '*.'                            ;// no terminator
    sz_plugin_defext        db  'dll',0,0                       ;// double terminator
    sz_plugin_button        db  'Register',0
    
    getfilename_path_plugin TEXTEQU <filename_plugin_path>
    GETNAME_FLAGS_PLUGIN EQU GETFILENAME_FORCE_DEFNAME

;// data reader writer

    ;// data file
        
    GETFILENAME_DATA_FLAGS  EQU OFN_HIDEREADONLY OR OFN_LONGNAMES OR OFN_EXPLORER OR OFN_ENABLEHOOK
    sz_data_title           db  'Open or Create a .DAT File',0
    sz_data_filter          db  'ABox Data files (*.dat)',0     ;// single terminator
    sz_data_defname         db  '*.'                            ;// no terminator
    sz_data_defext          db  'dat',0,0                       ;// double terminator
    
    sz_data_button          EQU 0
    getfilename_path_data   TEXTEQU <filename_data_path>
    GETNAME_FLAGS_DATA      EQU 0

    ;// media reader 

    GETFILENAME_READER_FLAGS EQU OFN_HIDEREADONLY OR OFN_LONGNAMES OR OFN_FILEMUSTEXIST OR OFN_PATHMUSTEXIST OR OFN_EXPLORER OR OFN_ENABLEHOOK
    sz_reader_title         db  'Open Media File',0
    sz_reader_filter        db  'Media Files (*.*)',0           ;// single terminator
    ;//"Video files (*.mpg; *.mpeg; *.avi; *.mov; *.qt)\0*.mpg; *.mpeg; *.avi; *.mov; *.qt\0\0";
    sz_reader_defname       db  '*.*',0                         ;// single terminator
    sz_reader_defext        db  0                               ;// double terminator
    
    sz_reader_button        EQU 0
    getfilename_path_reader TEXTEQU <filename_reader_path>
    GETNAME_FLAGS_READER    EQU 0

    ;// wave writer

    GETFILENAME_WRITER_FLAGS EQU OFN_HIDEREADONLY OR OFN_LONGNAMES OR OFN_PATHMUSTEXIST OR OFN_EXPLORER OR OFN_ENABLEHOOK
    sz_writer_title         db  'Open or Create a .WAV file',0
    sz_writer_filter        db  'Wave Files (*.wav)',0,'*.'     ;// no terminator
    sz_writer_defext        db  'wav',0,0

    sz_writer_defname       EQU 0   ;// builds circuit name + .wav
    sz_writer_button        EQU 0
    getfilename_path_writer TEXTEQU <filename_writer_path>
    GETNAME_FLAGS_WRITER    EQU 0

    ;// csv reader 

    GETFILENAME_CSVREADER_FLAGS EQU OFN_HIDEREADONLY OR OFN_LONGNAMES OR OFN_FILEMUSTEXIST OR OFN_PATHMUSTEXIST OR OFN_EXPLORER OR OFN_ENABLEHOOK
    sz_csvreader_title      db  'Open a text File',0
    sz_csvreader_filter     db  'Text files (*.txt, *.csv, *.prn)',0,'*.txt;*.csv;*.prn',0
                            db  'All files (*.*)',0,'*.*',0,0
    sz_csvreader_defname    db  0
    sz_csvreader_defext     db  0
    
    sz_csvreader_button     EQU 0
    getfilename_path_csvreader  TEXTEQU <filename_csvreader_path>
    GETNAME_FLAGS_CSVREADER EQU 0

    ;// csv writer

    GETFILENAME_CSVWRITER_FLAGS EQU OFN_HIDEREADONLY OR OFN_LONGNAMES OR OFN_EXPLORER OR OFN_ENABLEHOOK
    sz_csvwriter_title      db  'Open or Create a text file',0
    sz_csvwriter_filter     db  'Text files (*.txt, *.csv, *.prn)',0,'*.txt;*.csv;*.prn',0
                            db  'All files (*.*)',0,'*.*',0,0
    sz_csvwriter_defext     db  'txt',0,0

    sz_csvwriter_defname    EQU 0   ;// builds circuit name + .txt
    sz_csvwriter_button     EQU 0
    getfilename_path_csvwriter  TEXTEQU <filename_csvwriter_path>
    GETNAME_FLAGS_CSVWRITER EQU 0




    ALIGN 4

;// getfilename_table

    getfilename_table   LABEL GETFILENAME_TABLE

        GETFILENAME_TABLE { GETFILENAME_OPEN_FLAGS,sz_open_title,sz_open_filter,sz_open_defext,sz_open_defname,sz_open_button,getfilename_path_open,GETNAME_FLAGS_OPEN }
        GETFILENAME_TABLE { GETFILENAME_SAVEAS_FLAGS,sz_saveas_title,sz_saveas_filter,sz_saveas_defext,sz_saveas_defname,sz_saveas_button,getfilename_path_saveas,GETNAME_FLAGS_SAVEAS }
        GETFILENAME_TABLE { GETFILENAME_PASTE_FLAGS,sz_paste_title,sz_paste_filter,sz_paste_defext,sz_paste_defname,sz_paste_button,getfilename_path_paste,GETNAME_FLAGS_PASTE }
        GETFILENAME_TABLE { GETFILENAME_BITMAP_FLAGS,sz_bitmap_title,sz_bitmap_filter,sz_bitmap_defext,sz_bitmap_defname,sz_bitmap_button,getfilename_path_bitmap,GETNAME_FLAGS_BITMAP }
        GETFILENAME_TABLE { GETFILENAME_PLUGIN_FLAGS,sz_plugin_title,sz_plugin_filter,sz_plugin_defext,sz_plugin_defname,sz_plugin_button,getfilename_path_plugin,GETNAME_FLAGS_PLUGIN }
        GETFILENAME_TABLE { GETFILENAME_DATA_FLAGS,sz_data_title,sz_data_filter,sz_data_defext,sz_data_defname,sz_data_button,getfilename_path_data,GETNAME_FLAGS_DATA }
        GETFILENAME_TABLE { GETFILENAME_READER_FLAGS,sz_reader_title,sz_reader_filter,sz_reader_defext,sz_reader_defname,sz_reader_button,getfilename_path_reader,GETNAME_FLAGS_READER }
        GETFILENAME_TABLE { GETFILENAME_WRITER_FLAGS,sz_writer_title,sz_writer_filter,sz_writer_defext,sz_writer_defname,sz_writer_button,getfilename_path_writer,GETNAME_FLAGS_WRITER }
        GETFILENAME_TABLE { GETFILENAME_CSVREADER_FLAGS,sz_csvreader_title,sz_csvreader_filter,sz_csvreader_defext,sz_csvreader_defname,sz_csvreader_button,getfilename_path_csvreader,GETNAME_FLAGS_CSVREADER }
        GETFILENAME_TABLE { GETFILENAME_CSVWRITER_FLAGS,sz_csvwriter_title,sz_csvwriter_filter,sz_csvwriter_defext,sz_csvwriter_defname,sz_csvwriter_button,getfilename_path_csvwriter,GETNAME_FLAGS_CSVWRITER }

.CODE


;//________________________________________________________________________
;//
;//  filename_GetFileName
;//
;//   returns zero for cancel
;//   returns 1 for filename_get_path is valid
;//   except for choose plugin, which returns a list
;//
;//________________________________________________________________________
;// returns:    eax = 0 for cancel  
;//
;//     if ( mode == ABOX_PLUGIN )
;//
;//         filename_load_path is the single file name the user choose
;// 
;//     if ( mode == ABOX_PLUGIN )
;//
;//         eax is a memory block containing the list of selected files
;//         caller must parse these correctly
;//         and memory_Free the returned pointer
;//         filename_load_path is NOT effected

PROLOGUE_OFF
ASSUME_AND_ALIGN
filename_GetFileName PROC STDCALL uses esi edi ebx mode:dword

    ;// stack 
    ;// ret mode
    ;// 00  04

    ;// check some parameters
        
        DEBUG_IF <filename_get_path>        ;// this is supposed to be cleared !!
        
        DEBUG_IF <!!filename_circuit_path>  ;// supposed to be set by now

    ;// save some registers

        push ebp
        push esi
        push ebx
        push edi

    ;// stack 
    ;// edi ebx esi ebp ret mode
    ;// 00  04  08  0C  10  14

    ;// setup internal registers and set busy flags for any popup panels

        mov ebp, [esp+14h]              ;// get the mode
        mov getfilename_mode, ebp       ;// makes sure that hooks do the correct thing
        .IF app_DlgFlags & DLG_POPUP    ;// turn on the no undo flag
            inc popup_no_undo
        .ENDIF
        and app_bFlags, NOT APP_MODE_UNSELECT_OSC   ;// turn off the ctrl key
        BITSHIFT ebp, 1, SIZEOF GETFILENAME_TABLE   ;// turn into offset
        add ebp, OFFSET getfilename_table           ;// point at table
        ASSUME ebp:PTR GETFILENAME_TABLE

    ;// we're going to need 
    ;//     filename to set the initial directory
    ;//         we have to initialize this so as to provide a terminated directory name
    ;//     filename or memory block to set the return value
    ;//         this also needs to be initialized so we get the name extension correct

    ;// start with the directory

        mov esi, [ebp].initializer      ;// have initializer ?
        mov esi, [esi]
        .IF !esi
        mov esi, filename_circuit_path  ;// is circuit path set yet ?
        .ENDIF
        ASSUME esi:PTR FILENAME

    ;// now we have a source directory
    ;// we need to copy the path to a temporary location
    
        invoke filename_GetUnused       
        ASSUME ebx:PTR FILENAME     ;// this is just used for string space
        push ebx                    ;// save so we can release it

        lea edi, [ebx].szPath   ;// point at the destination
        mov ecx, [esi].pName    
        DEBUG_IF <!!ecx>    ;// pName was never initialized
        add esi, FILENAME.szPath    ;// point at the source
        sub ecx, esi        ;// number of bytes to name
        rep movsb           ;// copy them
        xor eax, eax        ;// terminate
        stosb   

    ;// get either an unused filename
    ;// or a block of memory for multiple selections

        .IF !([ebp].opfn_flags & OFN_ALLOWMULTISELECT)

            invoke filename_GetUnused   ;// get another temp string
            lea edi, [ebx].szPath       ;// edi is going to build a string
            push ebx                    ;// save on stack so we can free it

        .ELSE

            invoke memory_Alloc, GPTR, 16384
            mov edi, eax
            push eax

        .ENDIF

    ;// we've stored several things on the stack
    ;//
    ;// name dir edi ebx esi ebp ret mode
    ;// 00   04  08  0C  10  14  18  1C
        
    ;// now we setup the initial name
    
        mov esi, [ebp].initializer
        mov esi, DWORD PTR [esi]
        xor eax, eax
        .IF esi         ;// we are being passed a name to initialize with


            .IF [ebp].dwFlags & GETFILENAME_FORCE_DEFNAME
                ;// have to initialize the name as directory+filter
                
            ;// STRCPY_SD NOTERMINATE

                mov esi, [ebp].psz_defname
                DEBUG_IF <!!esi>    ;// this is supposed to be valid!           

                ;// fall in to next section

            .ELSE
                mov esi, [esi].pName
                DEBUG_IF <!!esi>    ;// name wasn't initialized
            .ENDIF

            ;// use the name as it currently exists
            STRCPY_SD TERMINATE

        .ELSE   ;// we are not being passed an initial name
                ;// so we're going to use the stated directory

            mov edx, [ebp].psz_defname  ;// see if we have a default name
            .IF edx     
                ;// we do have a default name, so we have to append the name to the directory

                ;//mov esi, [esp+4] ;// st_directory
                ;//add esi, FILENAME.szPath
                ;//STRCPY_SD NOTERMINATE

                mov esi, edx
                STRCPY_SD TERMINATE

            .ELSE       
                ;// we do not have a default name or an initializer
                ;// so we convert the initializer name to def extention
                ;// this results in the file being circuit name + def extension
                
                mov esi, filename_circuit_path
                mov ecx, [esi].pExt
                DEBUG_IF <!!ecx>    ;// extension was never set
                mov esi, [esi].pName
                DEBUG_IF <!!esi>    ;// name was never set
                sub ecx, esi
            ;// inc ecx         ;// add one to account for the dot
                rep movsb
                mov esi, [ebp].psz_defext
                DEBUG_IF <!!esi>    ;// GETFILENAME needs a defext pointer
                lodsd
                stosd   
                mov eax, ecx        ;// ecx is zero
                stosd

            .ENDIF

        .ENDIF
                
    ;// so now we have a directory and an initial name
    ;// let us continue on and build the OPENFILENAME struct on the stack

    ;// name dir edi ebx esi ebp ret mode
    ;// 00   04  08  0C  10  14  18  1C
        
        mov edx, [esp]      ;// filename or mem
        mov ebx, 16384      ;// size of block
        .IF !([ebp].opfn_flags & OFN_ALLOWMULTISELECT)
            add edx, FILENAME.szPath    
            mov ebx, 280
        .ENDIF
        mov ecx, [esp+4]    ;// directory filename
        xor eax, eax        ;// use for zero
        add ecx, FILENAME.szPath

        ;//OPENFILENAME
        push eax                ;// 19  pszTemplateName
        .IF [ebp].opfn_flags & OFN_ENABLEHOOK
            push OFFSET filename_OFNHookProc
        .ELSE
            push eax            ;// 18  pfnHook
        .ENDIF
        push eax                ;// 17  lCustData
        push [ebp].psz_defext   ;// 16  pszDefExt
        push eax                ;// 15  nFileExtension      ;// 14  nFileOffset
        push [ebp].opfn_flags   ;// 13  dwFlags
        push [ebp].psz_title    ;// 12  pszTitle
        push ecx                ;// 11  pszInitialDir
        push eax                ;// 10  nMaxFileTitle
        push eax                ;// 9   pszFileTitle
        push ebx                ;// 8   nMaxFile
        push edx                ;// 7   pszFile
        push eax                ;// 6   nFilterIndex
        push eax                ;// 5   nMaxCustFilter
        push eax                ;// 4   pszCustFilter
        push [ebp].psz_filter   ;// 3   pszFilter
        push hInstance          ;// 2   hInstance
        .IF app_DlgFlags & DLG_POPUP
            push popup_hWnd
            invoke EnableWindow, hMainWnd, 0
        .ELSE
            push hMainWnd       ;// 1   hWndOwner
        .ENDIF
        pushd SIZEOF OPENFILENAMEA;// 0 StructSize

    ;// now we invoke the correct function

            

        mov eax, getfilename_mode           ;// get the mode
                                            ;// we're about to set a new focus, so
        or app_DlgFlags, DLG_FILENAME       ;// tell popop handler to hide rather than destroy
        .IF eax == GETFILENAME_SAVEAS   || \
            eax == GETFILENAME_BITMAP
            invoke GetSaveFileNameA, esp
        .ELSE
            invoke GetOpenFileNameA, esp
        .ENDIF
        IFDEF DEBUGBUILD
            .IF !eax                
                invoke CommDlgExtendedError
                DEBUG_IF<eax>   ;// dialog error !!
            .ENDIF
        ENDIF
        and app_DlgFlags, NOT DLG_FILENAME  ;// tell popup handler to act like normal
        push eax    ;// save the reurn value

        .IF app_DlgFlags & DLG_POPUP            
            invoke EnableWindow, hMainWnd, 1
        .ENDIF
    
    ;// remove leftover mouse messages

        invoke GetAsyncKeyState, VK_LBUTTON
        .IF eax & 8000h

            ;// the left button is still down !!
            ;// if user holds it down, everything is ok
            ;// if user let's it up right away, then mouse_lbutton_up_proc
            ;// will drop the object right away

            ;// so we wait for either :
            ;//     the user to let up the button, then flush the message
            ;//     or doubleclicktime expires, and assume the user wants the button down
            
            invoke GetDoubleClickTime   ;// get the max time to wait
            push eax                    ;// we'll use the stack as a counter
            .REPEAT
                invoke Sleep, 10    ;// wait for a little bit
                invoke GetAsyncKeyState, VK_LBUTTON ;// button still down ?
                .IF !(eax & 8000h)  ;// button was let up flush the messages
                    sub esp, SIZEOF tagMSG  
                    .REPEAT
                        mov edx, esp
                        invoke PeekMessageA, edx, 0, WM_MOUSEFIRST, WM_MOUSELAST, PM_REMOVE
                    .UNTIL !eax
                    add esp, SIZEOF tagMSG
                    .BREAK
                .ENDIF
                sub DWORD PTR [esp], 10 ;// button is still down, check for timout
            .UNTIL CARRY?               ;// time out expired, user wants to wait
            add esp, 4
        .ENDIF

    ;//// check the results

        pop eax     ;// retrieve the return value
        mov esi, (OPENFILENAMEA PTR [esp]).pszFile
        add esp, SIZEOF OPENFILENAMEA
        pop edi     ;// temp name
        pop ebx     ;// temp directory

        .IF getfilename_mode != GETFILENAME_PLUGIN  ;// we're not a plugin object

            .IF eax     ;// we didn't cancel

                ;// now we set up a new file name
                ;// we can use the filename we grabbed for the directory
        
                invoke filename_InitFromString, FILENAME_FULL_PATH  ;// initialize to the new filename

                .IF eax ;// make sure it worked

                    DEBUG_IF <eax !!= 1>        ;// init from string returned a bad value
                    mov filename_get_path, ebx  ;// save as the return value

                ;//.ELSE    ;// filename did not work

                ;// xor eax, eax    ;// already zero

                .ENDIF
            .ELSE   ;// cancel

                filename_PutUnused ebx  ;// release the temp directory

            .ENDIF

                filename_PutUnused edi  ;// then we release the temp file name

        .ELSE   ;// we are a plugin
                ;// so edi points at memory
                
            .IF eax     ;// we didn't cancel
                
                mov eax, edi    ;// so we return the buffer we just created

            .ELSE   ;// user cancelled, we'll free the buffer here

                invoke memory_Free, edi
                ;// eax will be zero

            .ENDIF

        .ENDIF

    ;// resync popup undo

        .IF app_DlgFlags & DLG_POPUP
            dec popup_no_undo
        .ENDIF

    ;// that's it

        pop edi
        pop ebx
        pop esi
        pop ebp

    ;// return what ever is in eax
    
        ret 4

filename_GetFileName ENDP
PROLOGUE_ON





;//
;// this section is a kludge around for making sure that the default
;// extension is set to .ABox2
;//  there are two levels of proc's here
;//  the first level ( app_ONFproc ) is a hook for the GetSaveFileName dialog
;//     this allows us to get the window proceedure for the dialog
;//     wich we reset to the second proc( app_ONF2Proc )
;//
;//     the second level proc prevents windows from checking for the wrong filename
;//     when no extention is given.
;//
;// we also set different text for the file object dialog
;//  but we don't use the second hook proc
;//


ASSUME_AND_ALIGN
filename_ONF2Proc PROC STDCALL uses esi edi ebx hWnd:DWORD, msg:DWORD, wParam:DWORD, lParam:DWORD

    ;// this fixes that irritating flaw in the default extension
    ;// see the next function for how we got here

    .IF msg == WM_COMMAND

        mov ebx, wParam
        shr ebx, 16

        .IF bx == BN_CLICKED
    
            mov ebx, wParam
            .IF bx == IDOK

                ;// now we check the extension
                sub esp, 280
                mov edi, esp                    ;// edi holds the new stack pointer

                invoke GetDlgItem, hWnd, 480h
                mov ebx, eax                    ;// ebx is handle of edit window
                invoke GetWindowTextA, ebx, edi, 279

                ;// locate the end of the string
                mov ecx, 280
                mov esi, edi    ;// store start of string
                xor eax, eax
                repne scasb
                dec edi

                .IF edi > esi   ;// make sure it's not blank

                    mov edx, edi    ;// save edi just in case

                    ;// now we zip back to the last dot
                    sub ecx, 280
                    std
                    neg ecx
                    mov eax, '.'
                    repne scasb
                    cld
                    inc edi
                    .IF !ecx            ;// make sure something was found
                        mov edi, edx    ;// retrieve the old end
                    .ELSEIF ecx==1      ;// only a dot
                        jmp get_real
                    .ELSEIF ecx==2 && BYTE PTR [edi-1]=='.'
                        jmp get_real
                    .ENDIF

                    mov eax, 'oBA.' ;// force '.ABox2' extension
                    stosd
                    mov eax, '2x'
                    stosd

                    WINDOW ebx, WM_SETTEXT,0,esi
                    ;// invoke SetWindowTextA, ebx, esi

                .ENDIF

            get_real:
                add esp, 280

            .ENDIF
    
        .ENDIF

    .ELSEIF msg == WM_DESTROY

        invoke SetWindowLongA, hWnd, GWL_WNDPROC, ofnKludgeProc

    .ENDIF

    invoke CallWindowProcA, ofnKludgeProc, hWnd, msg, wParam, lParam
    
    ret

filename_ONF2Proc ENDP


ASSUME_AND_ALIGN
filename_OFNHookProc PROC   ;// STDCALL uses esi hWnd:DWORD, msg:DWORD, wParam:DWORD, lParam:DWORD

    ;// this is the first level hook proc

    .IF WP_MSG == WM_NOTIFY
    
        mov edx, WP_LPARAM
        ASSUME edx:PTR OFNOTIFY
        .IF [edx].dwCode == CDN_INITDONE
            
            mov eax, WP_HWND
            
            push esi
            push ebx
            invoke GetParent, eax
            mov esi, eax

            mov ebx, getfilename_mode
            BITSHIFT ebx, 1, SIZEOF GETFILENAME_TABLE
            add ebx, OFFSET getfilename_table
            ASSUME ebx:PTR GETFILENAME_TABLE

            mov ecx, [ebx].psz_button
            .IF ecx
                invoke SendMessageA, esi, CDM_SETCONTROLTEXT, IDOK, ecx
            .ENDIF

            .IF [ebx].dwFlags & GETFILENAME_USE_SUBHOOK
                invoke SetWindowLongA, esi, GWL_WNDPROC, OFFSET filename_ONF2Proc
                mov ofnKludgeProc, eax
            .ENDIF

            pop ebx
            pop esi

        .ENDIF

    .ENDIF

    xor eax, eax

    ret 10h
    
filename_OFNHookProc ENDP



;///
;///
;///
;///    G E T   F I L E N A M E 
;///
;///
;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////









.DATA

    app_szHasChanged        db ' has changed',0 
    app_szWannaSave_abox    db 'Save this ??', 0
    app_szWannaSave_abox2   db 'Save this as an ABox2 file ??', 0

.CODE


ASSUME_AND_ALIGN
filename_QueryAndSave PROC

    ;// asks to save
    ;// saves the file
    ;// forces name into mru

    ;// don't try to save empty files
    
    .IF master_context.oscZ_dlist_head  ;// anchor.pHead

            push ebp
            push ebx
            push edi
            push esi

        ;// we're going to build some text on the stack
        ;// and we need to check if this is an abox1 file

            mov edx, filename_circuit_path      ;// get the current name
            ASSUME edx:PTR FILENAME
            sub esp, 380    ;// make some room

        ;// we'll build the title first

            mov ebx, esp    ;// ebx will be used in message box function call
            xor eax, eax    ;// prevent big small problem
            mov edi, esp    ;// edi will store strings

            mov esi, [edx].pName
            STRCPY_SD NOTERMINATE

            lea esi, app_szHasChanged
            STRCPY_SD TERMINATE
        
        ;// then we determine the correct text to display
            
            lea esi, app_szWannaSave_abox       ;// get the default save string

            .IF mainmenu_mode & MAINMENU_ABOX1  ;// see if abox 1 file

                mov eax, [edx].pExt             ;// point at extension
                lea esi, app_szWannaSave_abox2  ;// point at the new save string
                mov DWORD PTR [eax+4], '2'      ;// change to abox2 file

            .ENDIF

        ;// now we build the message

            mov ebp, edi            ;// save this as the message pointer

            STRCPY_SD NOTERMINATE   ;// copy the message header

            mov al, 0ah             ;// line feed
            stosb

            lea esi, [edx].szPath   ;// get the full path

            STRCPY_SD TERMINATE     ;// copy it

        ;// turn off the ctrl key

        and app_bFlags, NOT APP_MODE_UNSELECT_OSC

        ;// then we ask for what user wants to do

        @@: 
            or app_DlgFlags, DLG_MESSAGE
            invoke MessageBoxA, hMainWnd, ebp , ebx,
                MB_YESNOCANCEL OR MB_ICONQUESTION OR MB_APPLMODAL OR MB_TOPMOST OR MB_SETFOREGROUND
            and app_DlgFlags, NOT DLG_MESSAGE   ;// turn off the message flag

        ;// do what user says

            .IF eax == IDYES        ;// yes we do

                invoke circuit_Save ;//, app_pFileName              
                mov eax, IDYES      ;// return value
                
                ;// since we are about to do something else,
                ;// does it make since to force the app_circuit name into the mru ?         
                ;// yes it does. Otherwise what ever happens next will erase this name

                invoke filename_SyncMRU
                
            .ENDIF

        ;// clean up

            add esp, 380

            pop esi
            pop edi
            pop ebx
            pop ebp

    .ENDIF

    ret

filename_QueryAndSave ENDP






;////////////////////////////////////////////////////////////////////
;//
;//
;//     MRU
;//

ASSUME_AND_ALIGN
filename_PackMRU PROC

    ;// make sure the mrus are packed (no zeros)

    ;// uses ecx and eax

    
    mov ecx, filename_mru1_path         ;// get the name
M1: .IF !ecx                            ;// empty ?
        xor eax, eax                    ;// eax is not_empty flag
        xchg filename_mru4_path, ecx
        or eax, ecx
        xchg filename_mru3_path, ecx
        or eax, ecx
        xchg filename_mru2_path, ecx
        or eax, ecx                     ;// all empty ?
        mov filename_mru1_path, ecx
        jnz M1
        jmp all_done
    .ENDIF      
        
    mov ecx, filename_mru2_path         ;// get the name
M2: .IF !ecx                            ;// empty ?
        xor eax, eax                    ;// eax is not_empty flag   
        xchg filename_mru4_path, ecx
        or eax, ecx
        xchg filename_mru3_path, ecx
        or eax, ecx                     ;// all empty ?
        mov filename_mru2_path, ecx
        jnz M2
        jmp all_done
    .ENDIF      
        
    mov ecx, filename_mru3_path         ;// get the name
M3: .IF !ecx                            ;// empty ?
        xchg filename_mru4_path, ecx    
        mov filename_mru3_path, ecx
    .ENDIF      ;// don't care if empty 
    
M4: ;// don't care

all_done:

    ret

filename_PackMRU ENDP




ASSUME_AND_ALIGN
filename_SyncMRU PROC uses ebx edi esi

    ;// task:   put circuit_path at top of mru
    ;// 
    ;// look for duplicate
    ;//     if found, move to top
    ;// else
    ;//     shove 2-4 down (removing 4)
    ;//     copy circuit title to mru1

    ;// 0) make sure the mrus are packed

        invoke filename_PackMRU

    ;// 1) look for duplicates

        ASSUME ebx:PTR FILENAME ;// ebx points at circuit_path
        ASSUME esi:PTR FILENAME ;// esi scans the mru
    
        mov ebx, filename_circuit_path
        DEBUG_IF <!!ebx>    ;// supposed to be set !!

        lea edi, [ebx].szPath   ;// edi points at the circuit_path string

M1:     mov esi, filename_mru1_path
        or esi, esi         ;// empty ?
        jz just_insert      ;// just insert if so
        invoke lstrcmpiA, edi, ADDR [esi].szPath
        or eax, eax         ;// match ??
        jnz M2              ;// do next if not a match
        jmp all_done        ;// found a match, it's already correct

M2:     mov esi, filename_mru2_path
        or esi, esi         ;// empty ?
        jz scoot_and_insert ;// scoot and insert if empty
        invoke lstrcmpiA, edi, ADDR [esi].szPath
        or eax, eax         ;// match ??
        jnz M3              ;// do next if not a match
        ;// found a match, move this to the top
        xchg filename_mru1_path, esi
        mov filename_mru2_path, esi
        jmp all_done

M3:     mov esi, filename_mru3_path
        or esi, esi         ;// empty ?
        jz scoot_and_insert ;// scoot and insert if empty
        invoke lstrcmpiA, edi, ADDR [esi].szPath
        or eax, eax         ;// match ??
        jnz M4              ;// do next if not a match
        ;// found a match, move this to the top
        xchg filename_mru1_path, esi
        xchg filename_mru2_path, esi
        mov filename_mru3_path, esi
        jmp all_done

M4:     mov esi, filename_mru4_path
        or esi, esi         ;// empty ?
        jz scoot_and_insert ;// scoot and insert if empty
        invoke lstrcmpiA, edi, ADDR [esi].szPath
        or eax, eax         ;// match ??
        jnz scoot_and_insert;// scoot_and_insert
        ;// found a match, move this to the top
        xchg filename_mru1_path, esi
        xchg filename_mru2_path, esi
        xchg filename_mru3_path, esi
        mov filename_mru4_path, esi
        jmp all_done


    ;// there are no matches
    scoot_and_insert:
    ;// this scoots 1-3 to 2-4 and inserts ebx at 1
    ;// then initializes a new mru with the circuit name

        mov esi, filename_mru1_path     ;// get the old top
        xchg filename_mru2_path, esi
        xchg filename_mru3_path, esi
        xchg filename_mru4_path, esi
        .IF esi         
            filename_PutUnused esi  ;// release the name            
        .ENDIF

    just_insert:

        invoke filename_GetUnused   ;// find an unused record
        mov filename_mru1_path, ebx ;// set the new top as circuit_path
        mov esi, edi                ;// set the initializer string
        invoke filename_InitFromString, FILENAME_FULL_PATH  ;// initialize the new name

    all_done:

        and app_bFlags, NOT APP_SYNC_MRU

        ret

filename_SyncMRU ENDP


;/////////////////////////////////////////////////////////////////////////////

;// DEBUG CODE

IFDEF USE_DEBUG_PANEL

filename_GetDebugStats PROTO

ASSUME_AND_ALIGN
filename_GetDebugStats PROC

    pool_GetDebugStats filename

    ret

filename_GetDebugStats ENDP


ENDIF ;// USE_DEBUG_PANEL

ASSUME_AND_ALIGN

END










