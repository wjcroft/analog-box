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
;//     registry.asm        app settings and what not
;// 
;// 
;// TOC
;// registry_ReadSettings
;// registry_WriteSettings
;// registry_Uninstall
;// registry_WriteMRU5
;// registry_ReadMRU5

OPTION CASEMAP:NONE
.586
.MODEL FLAT

    .NOLIST
    INCLUDE <ABox.inc>
    .LIST


comment ~ /*

    the abox registry is set thusly:

    HKEY_CLASSES_ROOT\.ABox2

        (Default)       ABox2_auto_file
        Content Type    application/abox2


    HKEY_CLASSES_ROOT\ABox2_auto_file

        (Default)       Analog Box 2.0 Circuit
        
        \Shell\Open\Command [app_path %1]

    HKEY_CURRENT_USER\Software\AndyWare\ABox2

        Config          [app_settings]
        MRU1
        MRU2
        MRU3
        MRU4
        MRU5
        MRU6    ;// paste path
        
        MRUD    ;// data file
        MRUR    ;// media reader file
        MRUW    ;// wave writer
    
        \vst_plugins


*/ comment ~

.DATA

        REG_KEY_SLASH_1 equ 17;// this tells us where the slash is so we can remove the key

        ;// strings
        szRegKey        db 'Software\AndyWare\ABox2',0
        szConfig        db 'Config',0

        ;// these set the file associations
        szRegKeyFile_1  db '.ABox2',0
        szRegKeyFile_1a db 'ABox2_auto_file',0
        szRegKeyFile_1b db 'Analog Box 2.0 Circuit', 0
        szRegKeyFile_1c db 'Content Type', 0
        szRegKeyFile_1d db 'application/abox2', 0
        szRegKeyFile_2  db 'ABox2_auto_file\Shell\Open\Command',0

        szMRU_slash db '\'      ;// back slask for erasing
        szMRU   db 'MRU1',0     ;// name and iterator for MRU 1-6,M,U,D
        szxmouse db 'xmouse',0

        ;// these tell where the slashes are in app_szRegKeyFile_2
        ;// needed because RegDeleteKey doesn't delete entire trees
        REG_FILE2_SLASH_1 equ 26
        REG_FILE2_SLASH_2 equ 21
        REG_FILE2_SLASH_3 equ 15

    REGISTRY_FILENAME STRUCT

        char        dd  0   ;// character to set szMRU to
        ppFilename  dd  0   ;// pointer to the filename to set

    REGISTRY_FILENAME ENDS

    ALIGN 4
    registry_filename_table LABEL REGISTRY_FILENAME

    REGISTRY_FILENAME {'1',OFFSET filename_mru1_path}
    REGISTRY_FILENAME {'2',OFFSET filename_mru2_path}
    REGISTRY_FILENAME {'3',OFFSET filename_mru3_path}
    REGISTRY_FILENAME {'4',OFFSET filename_mru4_path}
    REGISTRY_FILENAME {'6',OFFSET filename_paste_path}
    REGISTRY_FILENAME {'D',OFFSET filename_data_path}
    REGISTRY_FILENAME {'R',OFFSET filename_reader_path}
    REGISTRY_FILENAME {'W',OFFSET filename_writer_path}
    REGISTRY_FILENAME {'C',OFFSET filename_csvwriter_path}
    REGISTRY_FILENAME {'S',OFFSET filename_csvreader_path}
    
    dd 0    ;// required terminator






.CODE


ASSUME_AND_ALIGN
registry_ReadSettings PROC STDCALL uses esi edi

;// this function should be called before other functions that
;// allocate user adjustable settings

    LOCAL hKey:dword
    LOCAL hKey2:dword
    LOCAL disp:dword
    LOCAL regSize:dword

    ;// try to open our key HKEY_CURRENT_USER\Software\AndyWare\ABox2
 
        invoke RegCreateKeyExA, HKEY_CURRENT_USER,OFFSET szRegKey,
            REG_OPTION_RESERVED,0,REG_OPTION_NON_VOLATILE,
            KEY_SET_VALUE + KEY_CREATE_SUB_KEY + KEY_QUERY_VALUE,
            0,ADDR hKey,ADDR disp

    ;// if we created a new key, set the default values

        .IF disp == REG_CREATED_NEW_KEY     
        
            ;// load the default color set
                
                lea esi, app_default_colors
                lea edi, app_settings.colors
                mov ecx, SIZEOF GDI_PALETTE / 4
                rep movsd
                
            ;// then we store the complete set of settings
        
                invoke RegSetValueExA, hKey, OFFSET szConfig,0, REG_BINARY, OFFSET app_settings, SIZEOF ABOX_SETTINGS

    ;// otherwise, read the settings from the key

        .ELSE   ;// read settings from registry

            mov regSize, SIZEOF ABOX_SETTINGS
            invoke RegQueryValueExA, hKey, OFFSET szConfig, 0, 0, OFFSET app_settings, ADDR regSize

            ;// now we check if we need to update the color set (some early version of abox2, look in revisions.html)
            .IF app_settings.colors.sys_color[31*4] < 220h

                ;// need to do 5 sets of 2 shifts plus 1 write

                std ;// backwards
                
                lea edx, app_settings.colors.sys_color[31*4]
                mov eax, 5

                .REPEAT
                    
                    lea esi, [edx-4]
                    mov ecx, 32-10
                    mov edi, edx
                    rep movsd

                    lea esi, [edx-4]
                    mov ecx, 32-24
                    mov edi, edx
                    rep movsd
                    
                    mov DWORD PTR [edx], 220h
                    add edx, SIZEOF GDI_PALETTE
                    dec eax

                .UNTIL ZERO?
                

                cld ;// forwards

            .ENDIF

        .ENDIF

    ;// this may never ever get hit, unless jill user changed hardrives

        .IF !(app_CPUFeatures & 10h)
            and app_settings.show, NOT SHOW_CLOCKS
        .ENDIF

    ;// look for xmouse

        mov regSize, 0
        invoke RegQueryValueExA, hKey, OFFSET szxmouse, 0, 0, 0, ADDR regSize
        .IF !eax    ;// time to set xmouse
            inc app_xmouse
        .ENDIF

    ;// these set the default file associations and MIME types

    ;// create the HKEY_CLASSES_ROOT\.ABox2

        invoke RegCreateKeyExA, HKEY_CLASSES_ROOT, OFFSET szRegKeyFile_1,
            REG_OPTION_RESERVED,0,REG_OPTION_NON_VOLATILE,
            KEY_QUERY_VALUE + KEY_SET_VALUE + KEY_CREATE_SUB_KEY,
            0,ADDR hKey2,ADDR disp

    ;// set it to abox_auto_file

        invoke RegSetValueExA,hKey2,0,0,REG_SZ, 
            OFFSET szRegKeyFile_1a,SIZEOF szRegKeyFile_1a

    ;// then set the content type

        invoke RegSetValueExA,hKey2,OFFSET szRegKeyFile_1c,0,REG_SZ, 
            OFFSET szRegKeyFile_1d,SIZEOF szRegKeyFile_1d

    ;// we're done with this key
    
        invoke RegCloseKey, hKey2

    ;// see if there is an abox1 key of the same name
    ;// if not, then associate abox1 with abox2
                                    ;// 012345
        mov szRegKeyFile_1[5], 0    ;// .ABox2,0

        invoke RegCreateKeyExA, HKEY_CLASSES_ROOT, OFFSET szRegKeyFile_1,
            REG_OPTION_RESERVED,0,REG_OPTION_NON_VOLATILE,
            KEY_QUERY_VALUE + KEY_SET_VALUE + KEY_CREATE_SUB_KEY,
            0,ADDR hKey2,ADDR disp

        .IF disp == REG_CREATED_NEW_KEY     

            ;// set it to abox_auto_file

            invoke RegSetValueExA,hKey2,0,0,REG_SZ, 
                OFFSET szRegKeyFile_1a,SIZEOF szRegKeyFile_1a

            ;// then set the content type

            invoke RegSetValueExA,hKey2,OFFSET szRegKeyFile_1c,0,REG_SZ, 
                OFFSET szRegKeyFile_1d,SIZEOF szRegKeyFile_1d

        .ENDIF

    ;// we're done with this key
    
        invoke RegCloseKey, hKey2
        mov szRegKeyFile_1[5], '2'  ;// .ABox2,0
            
    ;// create the abox_auto_file key

        invoke RegCreateKeyExA,HKEY_CLASSES_ROOT,OFFSET szRegKeyFile_1a,
            REG_OPTION_RESERVED,0,REG_OPTION_NON_VOLATILE,
            KEY_QUERY_VALUE + KEY_SET_VALUE + KEY_CREATE_SUB_KEY,
            0,ADDR hKey2,ADDR disp

        invoke RegSetValueExA,hKey2,0,0,REG_SZ, 
            OFFSET szRegKeyFile_1b,SIZEOF szRegKeyFile_1b

        invoke RegCloseKey, hKey2

    ;// set up for the shell open command
    ;// by copying the abox command line to the stack

        sub esp, 280
        mov edi, esp

        ;// get app path 

        mov esi, filename_app_path  
        add esi, FILENAME.szPath

        ;// copy it and count the length

        mov ebx, 6  ;// account for the %1
    @@: lodsb
        inc ebx
        or al, al
        stosb
        jnz @B

    ;// tack the %1

        dec edi
        mov eax, '1%" '
        stosd
        mov eax, '"'
        stosd
    
    ;// create the shell open command key

        invoke RegCreateKeyExA,HKEY_CLASSES_ROOT,OFFSET szRegKeyFile_2,
            REG_OPTION_RESERVED,0,REG_OPTION_NON_VOLATILE,
            KEY_QUERY_VALUE + KEY_SET_VALUE + KEY_CREATE_SUB_KEY,
            0,ADDR hKey2,ADDR disp

    ;// set it's value to our command line

        mov edi, esp
        invoke RegSetValueExA, hKey2, 0,0, REG_SZ, edi, ebx
        invoke RegCloseKey, hKey2

    ;// still using the stack
    ;// load all the mru strings
        
        invoke about_SetLoadStatus

        mov ebx, OFFSET registry_filename_table
        ASSUME ebx:PTR REGISTRY_FILENAME

        .REPEAT
    
            mov al, BYTE PTR [ebx].char
            mov edi, [ebx].ppFilename           
            mov szMRU[3], al
            
            mov esi, esp        ;// point at buffer to initilaize with
            mov regSize, 280    ;// reset max size
            invoke RegQueryValueExA, hKey, OFFSET szMRU, 0, 0, esi, ADDR regSize
            .IF !eax
                push ebx            ;// store the iterator
                invoke filename_GetUnused       ;// get a new slot
                ASSUME ebx:PTR FILENAME
                invoke filename_InitFromString, FILENAME_FULL_PATH  ;// initialize it
                .IF !eax
                    filename_PutUnused ebx  ;// release the name
                    mov ebx, eax
                .ENDIF
                mov [edi], ebx              ;// store the filename pointer
                pop ebx
                ASSUME ebx:PTR REGISTRY_FILENAME
            .ENDIF

            add ebx, SIZEOF REGISTRY_FILENAME

        .UNTIL ![ebx].char

    ;// then we close our key and cleanup the stack

        add esp, 280
        invoke RegCloseKey, hKey

    ;// just incase, we pack the mru

        invoke about_SetLoadStatus

        invoke filename_PackMRU

    ;// and beat it on out'o'here

        or app_bFlags, APP_SYNC_OPTIONBUTTONS OR APP_SYNC_PLAYBUTTON

        ret

registry_ReadSettings ENDP


ASSUME_AND_ALIGN
registry_WriteSettings PROC STDCALL uses esi edi ebx

        LOCAL hKey:dword
        LOCAL disp:dword
        LOCAL string[280]:BYTE

    ;// try to open our key HKEY_CURRENT_USER\Software\AndyWare\ABox2
 
        invoke RegCreateKeyExA, HKEY_CURRENT_USER,OFFSET szRegKey,
            0,0,REG_OPTION_NON_VOLATILE,
            KEY_SET_VALUE + KEY_CREATE_SUB_KEY + KEY_QUERY_VALUE,
            0,ADDR hKey,ADDR disp
    
    ;// write settings to registry
    
        invoke RegSetValueExA, hKey, OFFSET szConfig,0, REG_BINARY, OFFSET app_settings, SIZEOF ABOX_SETTINGS

    ;// store the MRU list, delete unused values
    ;// have to surrond with quotes

        mov ebx, OFFSET registry_filename_table
        ASSUME ebx:PTR REGISTRY_FILENAME
        
        .REPEAT

        ;// setup sz MRU

            mov al, BYTE PTR [ebx].char
            mov szMRU[3], al

        ;// see if filename exists

            mov esi, [ebx].ppFilename
            mov esi, [esi]
            .IF esi     ;// make sure name was set

            ;// make quoted string

                ASSUME esi:PTR FILENAME
            
                lea edi, string
                mov eax, '"'
                stosb                   ;// first quote
                
                mov ecx, [esi].dwLength ;// get the length
                add esi, FILENAME.szPath;// bump to src string
                lea edx, [ecx+3]        ;// dtermine the store length
                ASSUME esi:NOTHING
                rep movsb               ;// store on stack
                
                stosd                   ;// end quote and terminate

            ;// store the value

                lea edi, string
                invoke RegSetValueExA, hKey, OFFSET szMRU, 0, REG_SZ, edi, edx

            .ELSE   ;// filename doesn't exist, delete the key
                invoke RegDeleteValueA, hKey, OFFSET szMRU
            .ENDIF

            add ebx, SIZEOF REGISTRY_FILENAME

        .UNTIL ![ebx].char


    ;// MRU5, delete this value
    ;// it might even be there

        mov szMRU[3], '5'
        invoke RegDeleteValueA, hKey, OFFSET szMRU
                
    ;// close the key

        invoke RegCloseKey, hKey

    ;// that's it

        ret

registry_WriteSettings ENDP







ASSUME_AND_ALIGN
registry_Uninstall PROC STDCALL

;// there are three key-trees we're dealing with

    LOCAL hKey:DWORD
    LOCAL disp:DWORD
    LOCAL num_keys:DWORD
    LOCAL regSize:DWORD

;// stop playing first

    .IF play_status & PLAY_PLAYING
        invoke play_Stop
    .ENDIF

;// Software\AndyWare\ABox2\vst_plugins

    invoke RegDeleteKeyA, HKEY_CURRENT_USER, OFFSET plugin_szRegKey

;// Software\AndyWare\ABox2

    invoke RegDeleteKeyA, HKEY_CURRENT_USER, OFFSET szRegKey

;// check if there are anymore sub keys
;// if not, delete andyware as well

    ;// take out the slash
        
        mov szRegKey[REG_KEY_SLASH_1], 0    
    
    ;// open the key
 
        invoke RegCreateKeyExA, HKEY_CURRENT_USER,
            OFFSET szRegKey, REG_OPTION_RESERVED,
            0,
            REG_OPTION_NON_VOLATILE,
            KEY_SET_VALUE + KEY_CREATE_SUB_KEY + KEY_QUERY_VALUE,
            0, ADDR hKey, ADDR disp

    ;// query it

        invoke RegQueryInfoKeyA, hKey, 0, 0, 0, ADDR num_keys, 0, 0, 0, 0, 0, 0, 0

    ;// close the key

        invoke RegCloseKey, hKey

    ;// check what we got

        .IF !num_keys
            invoke RegDeleteKeyA, HKEY_CURRENT_USER, OFFSET szRegKey
        .ENDIF


;// .ABox2

    invoke RegDeleteKeyA, HKEY_CLASSES_ROOT, OFFSET szRegKeyFile_1  

;// .ABox (only if it says abox2_auto_file

        mov szRegKeyFile_1[5], 0    ;// .ABox2,0

        invoke RegCreateKeyExA, HKEY_CLASSES_ROOT, OFFSET szRegKeyFile_1,
            REG_OPTION_RESERVED,0,REG_OPTION_NON_VOLATILE,
            KEY_QUERY_VALUE + KEY_SET_VALUE + KEY_CREATE_SUB_KEY,
            0,ADDR hKey,ADDR disp

            mov regSize, 32
            sub esp, 32
            mov edx, esp
            invoke RegQueryValueExA, hKey, 0, 0, 0, edx, ADDR regSize

            invoke RegCloseKey, hKey

            movzx eax, BYTE PTR [esp+4]

            add esp, 32

        .IF eax == '2' || disp == REG_CREATED_NEW_KEY

            invoke RegDeleteKeyA, HKEY_CLASSES_ROOT, OFFSET szRegKeyFile_1

        .ENDIF

        mov szRegKeyFile_1[5], '2'  ;// .ABox2,0


;// NT doesn't delete entire trees, so there's some work to do

    ;// starting with file_2, 
    ;// we delete each and null the preceeding slash
    ;// this is safe because we're about to exit anyways

    invoke RegDeleteKeyA, HKEY_CLASSES_ROOT, OFFSET szRegKeyFile_2
    mov szRegKeyFile_2[REG_FILE2_SLASH_1], 0
    invoke RegDeleteKeyA, HKEY_CLASSES_ROOT, OFFSET szRegKeyFile_2
    mov szRegKeyFile_2[REG_FILE2_SLASH_2], 0
    invoke RegDeleteKeyA, HKEY_CLASSES_ROOT, OFFSET szRegKeyFile_2
    mov szRegKeyFile_2[REG_FILE2_SLASH_3], 0
    invoke RegDeleteKeyA, HKEY_CLASSES_ROOT, OFFSET szRegKeyFile_2

    jmp app_ExitNow

registry_Uninstall ENDP





ASSUME_AND_ALIGN
registry_WriteMRU5 PROC STDCALL uses esi edi

    ;// this stores app_pFileName in MRU5 in the registry
    ;// it's only used as a tag for one instance of abox to load a file into another

    LOCAL hKey:dword
    LOCAL disp:dword

    ;// try to open our key
 
        invoke RegCreateKeyExA,
            HKEY_CURRENT_USER,
            OFFSET szRegKey,
            0,
            0,
            REG_OPTION_NON_VOLATILE,
            KEY_SET_VALUE + KEY_CREATE_SUB_KEY + KEY_QUERY_VALUE,
            0,
            ADDR hKey,
            ADDR disp
    
    ;// store the MRU list and deallocate

    ;// ebx has the filename


        ASSUME ebx:PTR FILENAME
        
        mov szMRU[3], '5'

        pushd 1
        lea edi, [ebx].szPath       
        push edi        
        STRLEN edi, DWORD PTR [esp+4]
        pushd REG_SZ
        pushd 0
        pushd OFFSET szMRU
        push hKey
        call    RegSetValueExA  ;// , hKey, ADDR app_szMRU, 0, REG_SZ, app_pCircuitName, ecx

    ;// close the key

        invoke RegCloseKey, hKey

    ;// that's it

        ret

registry_WriteMRU5 ENDP








ASSUME_AND_ALIGN
registry_ReadMRU5 PROC STDCALL uses esi edi

    ;// this reads MRU5 to filename_mru5
    ;// in responce to recieving the message from another instance of ABox
    
    LOCAL hKey:dword
    LOCAL hKey2:dword
    LOCAL disp:dword
    LOCAL regSize:dword

    ;// try to open our key
 
    invoke RegCreateKeyExA,
        HKEY_CURRENT_USER,
        OFFSET szRegKey,
        REG_OPTION_RESERVED,
        0,
        REG_OPTION_NON_VOLATILE,
        KEY_SET_VALUE + KEY_CREATE_SUB_KEY + KEY_QUERY_VALUE,
        0,
        ADDR hKey,
        ADDR disp

    DEBUG_IF <(disp == REG_CREATED_NEW_KEY)>
    
    mov szMRU[3], '5'

    sub esp, 280
    mov esi, esp
    mov regSize, 280
    invoke RegQueryValueExA, hKey, OFFSET szMRU, 0, 0, esi, ADDR regSize
    DEBUG_IF <eax>  ;// not set yet

    mov ebx, filename_mru5_path
    .IF !ebx
        invoke filename_GetUnused
        mov filename_mru5_path, ebx
    .ENDIF
    invoke filename_InitFromString, FILENAME_FULL_PATH
    add esp, 280

    invoke RegCloseKey, hKey

    ret

registry_ReadMRU5 ENDP







ASSUME_AND_ALIGN





END
