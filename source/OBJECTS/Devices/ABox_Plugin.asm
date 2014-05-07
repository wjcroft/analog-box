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
;//                     
;// ABox_Plugin.asm             see plugin_alomost_1.asm for backup file
;//                             in this file we try to let plugins be free ...
;// 
;// TOC:
;// 
;// plugin_Sort PROC
;// plugin_Initialize PROC STDCALL uses esi edi
;// plugin_InitializeStream PROC
;// plugin_Unload PROC STDCALL pReg:PTR PLUGIN_REGISTRY
;// plugin_Destroy PROC
;// plugin_Register PROC STDCALL uses esi edi ebx
;// plugin_Match PROC STDCALL uses esi edi ebx pObject:PTR OSC_OBJECT
;// plugin_build_display_name PROC STDCALL pObject:DWORD
;// plugin_Open PROC STDCALL uses esi edi pObject:PTR OSC_OBJECT, bRead:DWORD
;// plugin_Attach PROC STDCALL USES esi edi pObject:PTR OSC_PLUGIN, pRegistry:PTR PLUGIN_REGISTRY
;// plugin_Close PROC STDCALL USES ebx esi edi pObject:PTR OSC_OBJECT
;// plugin_Detach PROC STDCALL USES esi edi ebx pObject:DWORD
;// plugin_ReadParameters PROC STDCALL uses esi edi ebx pObject:PTR OSC_OBJECT
;//
;// osc_Plugin_Ctor PROC
;// osc_Plugin_Dtor PROC
;// osc_Plugin_Render PROC
;// osc_Plugin_SetShape PROC
;// osc_Plugin_Write PROC uses esi
;// osc_Plugin_AddExtraSize PROC
;//
;// plugin_FabricateEditor PROC STDCALL USES edi ;// ABOX233 how'd edi get erased ???
;// plugin_CreateDefaultPanel PROC uses esi edi
;// osc_Plugin_InitMenu PROC
;// osc_Plugin_Command PROC
;//
;// plugin_SaveUndo PROC
;// plugin_LoadUndo PROC
;// plugin_AMCallback PROC C pAEffect:DWORD, dwOpcode:DWORD, dwIndex:DWORD, dwValue:DWORD, dwPtr:DWORD, dwOption:DWORD
;// osc_Plugin_PrePlay PROC
;// osc_Plugin_Calc PROC


OPTION CASEMAP:NONE

.586
.MODEL FLAT

USE_THIS_FILE equ 1

IFDEF USE_THIS_FILE


        .NOLIST
        INCLUDE ABox_Plugin.inc
        .LIST


;// DEBUG_MESSAGE_ON
 DEBUG_MESSAGE_OFF





;// dev notes:
comment ~ /*

new for ABox2

    on/off pin
    constant shape (due to new gdi model)
    plugin registry . size is complete ignored

new in ABox 220

    can_receive
    can_send
    midi events

plugin notes

    the model is:
        
        plugin objects attach to PLUGIN_REGISTRY's
        if the object exists, it's plugin module is assumed to be loaded
        and aEffect created and ready to go

        when there are no longer any objects using a given entry
        it's dll is unloaded

        to locate, dwUser stores a 32 bit checksum
        
    loading scenerios:

        create from the create menu

        create from a file/clipboard and able to locate the registry

        create from a file/clipboard and can not locate the registry


    if we can not locate the device, we still have enough parameters saved
    to be able to match a new user choice

    --------------------------------------------------------------------------

    potential hassles:

        plugins that need to be told to stop

        creating the buttons nessesary to allow the user to choose a plugin
        --> taken care of with a list box


    --------------------------------------------------------------------------

    pieces:

        PLUGIN_REGISTRY maintains the locations, names, and 'shape' of known plugins

            each record exists in an slist called pluginR

            plugin_Initialize reads from registry and creates pluginR, 
                also removes files that are not found
            plugin_Destroy frees the list from memory

            plugin_Register adds a new item to the list
            plugin_Match will try to locate a suitable match given a set of matching criteria
    
            plugin_Unload will free the dll, and reset the main pointer

        OSC_PLUGIN maintains an osc_object's connection with a PLUGIN_REGISTRY and the dll

            plugin_Open will 
                instansiate the dll 
                get the main function
                connect an object to a pReg
                get the AEffects pointer
                increase the instance count

            plugin_Close will unconnect the object and decrease the count

            plugin_Attach will xfer some setting from pReg to the object

            plugin_Detach will reset the object and call plugin_Close

            plugin_SetShape will define what pins exist on the object and determine 
                it's screen size

    ABOX233: 
    
        implemented midi out capability by adjusting MIDI_QUE_PORTSTREAM struct
        changes object size and arrangment of data
        removed data_so (output midi stream) and replaced with que_portstream

        also not that we MAY need to fiddle with
        test [ebx].midi_flags, MIDIIN_LOWEST_LATENCY    ;// do we care ?


*/ comment ~

.DATA


;//
;// plugin chassis
;//

    plugin_AMCallback PROTO C pAEffect:DWORD, dwOpcode:DWORD, dwIndex:DWORD, dwValue:DWORD, dwPtr:DWORD, dwOption:DWORD

;//
;// PLUGIN_REGISTRY     see ABox_Plugin.inc
;//
    
    ;// we use pluginR as a list of registered plugins

    slist_Declare pluginR   ;// , PLUGIN_REGISTRY, pNext

;//
;// OSC_PLUGIN          see ABox_Plugin.inc
;//



;//
;// plugin_object
;//

PLUGIN_BASE_FLAGS EQU BASE_SHAPE_EFFECTS_GEOMETRY OR BASE_WANT_POPUP_DEACTIVATE OR BASE_WANT_POPUP_ACTIVATE OR BASE_WANT_POPUP_WINDOWPOSCHANGING
PLUGIN_OBJECT_SIZE EQU SIZEOF OSC_OBJECT + ( SIZEOF APIN ) * 19

osc_Plugin OSC_CORE { osc_Plugin_Ctor,osc_Plugin_Dtor,osc_Plugin_PrePlay,osc_Plugin_Calc }
        OSC_GUI  {osc_Plugin_Render,osc_Plugin_SetShape,,,,osc_Plugin_Command,osc_Plugin_InitMenu,osc_Plugin_Write,osc_Plugin_AddExtraSize,plugin_SaveUndo,plugin_LoadUndo}
        OSC_HARD { }

    OSC_DATA_LAYOUT {NEXT_Plugin,IDB_PLUGIN,OFFSET popup_PLUGIN,PLUGIN_BASE_FLAGS,
        19,4,
        PLUGIN_OBJECT_SIZE,
        PLUGIN_OBJECT_SIZE + SAMARY_SIZE * 8,
        PLUGIN_OBJECT_SIZE + SAMARY_SIZE * 8 + SIZEOF OSC_PLUGIN + SIZEOF MIDI_QUE_PORTSTREAM }     

    OSC_DISPLAY_LAYOUT { devices_container,VST_PSOURCE,ICON_LAYOUT(8,4,2,4) }

    APIN_init { ,, '1',, UNIT_DB }
    APIN_init { ,, '2',, UNIT_DB }
    APIN_init { ,, '3',, UNIT_DB }
    APIN_init { ,, '4',, UNIT_DB }
    APIN_init { ,, '5',, UNIT_DB }
    APIN_init { ,, '6',, UNIT_DB }
    APIN_init { ,, '7',, UNIT_DB }
    APIN_init { ,, '8',, UNIT_DB }
                    
    APIN_init { ,, '1',, PIN_OUTPUT OR UNIT_DB }
    APIN_init { ,, '2',, PIN_OUTPUT OR UNIT_DB }
    APIN_init { ,, '3',, PIN_OUTPUT OR UNIT_DB }
    APIN_init { ,, '4',, PIN_OUTPUT OR UNIT_DB }
    APIN_init { ,, '5',, PIN_OUTPUT OR UNIT_DB }
    APIN_init { ,, '6',, PIN_OUTPUT OR UNIT_DB }
    APIN_init { ,, '7',, PIN_OUTPUT OR UNIT_DB }
    APIN_init { ,, '8',, PIN_OUTPUT OR UNIT_DB }

    APIN_init {0.5,sz_Enable,'e',,PIN_LOGIC_INPUT OR PIN_LOGIC_GATE OR PIN_LEVEL_POS OR UNIT_LOGIC }

        EXTERNDEF osc_Plugin_pin_si:APIN_init   ;// needed by xlate_convert_plugin
        EXTERNDEF osc_Plugin_pin_so:APIN_init

osc_Plugin_pin_si   APIN_init {0.65,sz_Stream,'is',,UNIT_MIDI_STREAM }
osc_Plugin_pin_so   APIN_init {0.35,sz_Stream,'os',,UNIT_MIDI_STREAM OR PIN_OUTPUT OR PIN_NULL}

    short_name  db  'Plugin',0
    description db  "Hosts a VST 2.0 compliant plugin filter. Register filters with the object's popup panel, then select as desired.",0
    ALIGN 4
    sz_can_send     db  "sendVstMidiEvent",0
    ALIGN 4
    sz_can_receive  db  "receiveVstMidiEvent", 0
    ALIGN 4
    sz_Change       db  "Change",0  ;// change plugin label
    ALIGN 4


;//
;// OSCMAP for this object  see ABox_Plugin.inc
;//


;// might as well equate these

    PLUGIN_MAX_INPUTS       EQU 8
    PLUGIN_MAX_OUTPUTS      EQU 8
    PLUGIN_SCROLL_TO_LABEL  EQU 128 ;// used to sync labels with scroll bars

;// gdi layout based on size of devices_container

    PLUGIN_WIDTH  EQU 40
    PLUGIN_HEIGHT EQU 56

;// dialog layout, we build our own dialog, by hand, yuck

    PLUGIN_POPUP_WIDTH   equ 272
    PLUGIN_BUTTON_HEIGHT equ 16
    PLUGIN_BUTTON_STYLE  equ BS_VCENTER + WS_CHILD + WS_VISIBLE

    PLUGIN_LABEL_WIDTH equ 80

    PLUGIN_LISTBOX_STYLE equ WS_CHILD + WS_HSCROLL + WS_VSCROLL + WS_VISIBLE + LBS_HASSTRINGS + LBS_NOINTEGRALHEIGHT + LBS_NOTIFY 
    PLUGIN_LISTBOX_WIDTH  equ 220   ;// 160
    PLUGIN_LISTBOX_HEIGHT equ 144   ;// 96

;// if plug does not have a parameter gui, we build one by hand
 
    PLUGIN_SCROLL_WIDTH equ PLUGIN_POPUP_WIDTH - PLUGIN_LABEL_WIDTH

    PLUGIN_SCROLL_RANGE  equ 256
    plugin_ScrollScale   TEXTEQU <math_1_256>
    plugin_ScrollUnscale TEXTEQU <math_256>


;// strings

;// registry keys, are broken in two to simplify opening the key by the app

    plugin_szRegKey     db  'Software\AndyWare\ABox2\'
    plugin_szRegKey_2   db  'vst_plugins',0
    plugin_szFmtName    db  '%8.8X',0   ;// to make a new reg key

;// default names

    plugin_szChoose     db  ' Select a Plug',0  ;// leading space required to enforce sort order
    plugin_szRegister   db  'Register plugins',0
    plugin_szRemove     db  'Unregister',0

;// function location

    plugin_szMain       db  'main',0    ;// to find the main() function

;// error messages

    plugin_szProblem    db  "Problem with Plugin", 0
    plugin_szNoLib      db  0dh, 0ah, "will not load as a dll.", 0
    plugin_szNoLike     db  0dh, 0ah, "does not like ABox and returned an error.", 0
    plugin_szNotVst     db  0dh, 0ah, "is not a VST plugin.",0
    plugin_szTooMuch    db  0dh, 0ah, "has too many ins or outs and cannot be used.", 0
    ALIGN 4

;/////////////////////////////////////////////////////////////////

;//
;// vst_midi_stream
;// PLUGIN_INPUT_STREAM 

    comment ~ /*

    we use ONE common input stream
        allocated by plugin_InitializeStream by first object that needs it
        destroyed by plugin_Destroy (at app shutdown)
    filled in by midi_stream_to_vst_stream
        using source data from the object
    the stream is processed via call tp dispatcher.processEvents

    */ comment ~

    PLUGIN_NUM_STREAM_EVENTS EQU MIDI_STREAM_LENGTH

    PLUGIN_INPUT_STREAM STRUCT

        VstMidiEvents   {}  ;// header
        ptr_array   dd  PLUGIN_NUM_STREAM_EVENTS    DUP (0)

        event   VstMidiEvent PLUGIN_NUM_STREAM_EVENTS DUP ({})

    PLUGIN_INPUT_STREAM ENDS
    

    plugin_input_stream dd  0   ;// ptr to PLUGIN_INPUT_STREAM


;// ABOX233
;//
;//     some objects need time information
;//     we are supposed to provide the structure
;// so we'll simply cement it in fixed memory
;// sample position is copied from play_sample_position as required

    PLUGIN_SAMPLE_RATE CATSTR %SAMPLE_RATE,<.0>
    plugin_time_info    VstTimeInfo { ,PLUGIN_SAMPLE_RATE, }


;// ABOX233
;// plugins that show their own panels are ... messy
;// we use these values to help decide what to do
;// we may at times choose to disable the main window
;// and we need to know when it is safe to close the panel
;// see plugin_Command popup_is_deactivating popup_is_activating

    
    ;// see ABox_Plugin_Editor.asm



;// ABOX233
;// added this as a nicety

    last_selection_item dd  0   ;// last selected item in the list box
    last_known_registry dd  0   ;// courtesy if user changes a plug



.CODE

;////////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////////
;////
;////   P L U G I N _ R E G I S T R Y
;////

;////////////////////////////////////////////////////////////////////////////////////////
ASSUME_AND_ALIGN
plugin_Sort PROC

    ;// all this does is sort the list
    ;// it gets called from a couple places, so we'll save some space and
    ;// make it a function instead ofa macro

    slist_TextSort pluginR, NOCASE, OFFSET PLUGIN_REGISTRY.szPlugName

    ret

plugin_Sort ENDP
;////////////////////////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////////////////////////
ASSUME_AND_ALIGN
plugin_Initialize PROC STDCALL uses esi edi

    ;// here we walk all the devices we know about
    ;// and fill in a plugin registry for each

    ;// this allocates creates and initializes pluginR
    ;// and should only be called at app_start

    ;// AOX233: we also register the editor window

    LOCAL hKey:DWORD
    LOCAL disp:DWORD
    LOCAL numValues:DWORD
    LOCAL valNameSize:DWORD
    LOCAL valSize:DWORD
    LOCAL regType:DWORD
    LOCAL valName[280]:BYTE

    ;// open the registry key

    invoke RegCreateKeyExA,
        HKEY_CURRENT_USER,
        OFFSET plugin_szRegKey, ;// Software\AndyWare\ABox\vst_plugins
        REG_OPTION_RESERVED,
        0,
        REG_OPTION_NON_VOLATILE,
        KEY_SET_VALUE + KEY_CREATE_SUB_KEY + KEY_QUERY_VALUE,
        0,
        ADDR hKey,
        ADDR disp

    xor esi, esi    ;// need to keep this string pointer clear

    ;// make sure we didn't just create this
    .IF disp != REG_CREATED_NEW_KEY

        ;// count the number of values
        invoke RegQueryInfoKeyA, hKey, 0,0,0,0,0,0,ADDR numValues,0,0,0,0 

        .WHILE numValues                        

        ;// iterate backwards
        ;// verify that we can do this safely

            dec numValues

        ;// allocate a new plugin entry

            slist_AllocateHead pluginR, edi

        ;// read the registry entry

            mov valNameSize, 279
            mov valSize, REGISTRY_SAVE_SIZE
            mov regType, REG_BINARY
            invoke RegEnumValueA, hKey, 
                numValues,          ;// dwIndex:DWORD, 
                ADDR valName,       ;// pValueName:DWORD, 
                ADDR valNameSize,   ;// pcbValueName:DWORD, 
                0,                  ;// pReserved:DWORD, 
                ADDR regType,       ;// pType:DWORD, 
                ADDR [edi].REGISTRY_SAVE_START, ;// pData:DWORD, 
                ADDR valSize        ;// pcbData:DWORD  

        ;// make sure it's still there

            invoke CreateFileA, ADDR [edi].szFileName, 0, FILE_SHARE_READ, 0, OPEN_EXISTING, 0, 0

            .IF eax == INVALID_HANDLE_VALUE

                slist_FreeHead pluginR, edi
                invoke RegDeleteValueA, hKey, ADDR valName

            .ELSE

                ;// to be nice, we parse this so user has a last directoy to work with
                ;// ebx is still filename_plugin_path                

                invoke CloseHandle, eax
                lea esi, [edi].szFileName

            .ENDIF
                        
        .ENDW

    .ENDIF

    invoke RegCloseKey, hKey

    ;// if any files were found, we'll set the last path
    
    .IF esi

        xor ebx, ebx
        or ebx, filename_plugin_path    ;// this may be wasted code
        .IF ZERO?

            invoke filename_GetUnused
            mov filename_plugin_path, ebx

        .ENDIF

        invoke filename_InitFromString, FILENAME_FULL_PATH

    .ENDIF

    ;// always create a default plugin as the first record

        slist_AllocateHead pluginR, edi
        
        lea edi, [edi].szPlugName
        lea esi, plugin_szChoose
        mov ecx, SIZEOF plugin_szChoose
        rep movsb

    ;// now let's be nice and sort this

        invoke about_SetLoadStatus

        call plugin_Sort
    
    ;// that's it
        
        ret

plugin_Initialize ENDP
;////////////////////////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////////////////////////
ASSUME_AND_ALIGN
plugin_InitializeStream PROC

        DEBUG_IF <plugin_input_stream>  ;// already allocated, check first !!

    ;// allocate the memory

        invoke memory_Alloc, GPTR, SIZEOF PLUGIN_INPUT_STREAM
        mov plugin_input_stream, eax
        ASSUME eax:PTR PLUGIN_INPUT_STREAM

    ;// setup pointers and counters
        
        mov ecx, PLUGIN_NUM_STREAM_EVENTS   ;// ecx counts

        lea edx, [eax].event
        ASSUME edx:PTR VstMidiEvent ;// edx walks events

        add eax, OFFSET PLUGIN_INPUT_STREAM.ptr_array
        ASSUME eax:PTR DWORD        ;// eax stores pointers

    ;// initialize the array

        .REPEAT 

            mov [eax],edx   ;// set the ptr
            
            mov [edx].dwType, kVstMidiType  ;// set event type
            mov [edx].byteSize, 24          ;// set the size

            add eax, 4                      ;// next pointer
            add edx, SIZEOF VstMidiEvent    ;// next event
            dec ecx                         ;// done yet ?
        
        .UNTIL ZERO?
    
    ;// that's it

        ret

plugin_InitializeStream ENDP
;////////////////////////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////////////////////////
ASSUME_AND_ALIGN
plugin_Unload PROC STDCALL pReg:PTR PLUGIN_REGISTRY

    ;// here, we unload the dll

        mov ebx, pReg
        ASSUME ebx:PTR PLUGIN_REGISTRY  

    ;// unload the dll

        invoke FreeLibrary, [ebx].hModule
        DEBUG_IF <!!eax>    ;// couldn't free

    ;// then we close the device

        mov [ebx].hModule, 0    ;// clear the handle
        mov [ebx].pMain, 0      ;// reset the pMain ptr                             

    ;// that's it

        ret

plugin_Unload ENDP
;////////////////////////////////////////////////////////////////////////////////////////




;////////////////////////////////////////////////////////////////////////////////////////
ASSUME_AND_ALIGN
plugin_Destroy PROC

    ;// this is called at app exit

        mov edx, filename_plugin_path
        .IF edx
            filename_PutUnused edx
        .ENDIF

    ;// free all the reg entries
    ;// all entries must be closed, we should check for this

        slist_GetHead pluginR, esi
        .WHILE esi
            .IF [esi].hModule
                invoke plugin_Unload, esi
            .ENDIF
            mov edi, slist_Next(pluginR,esi);//[esi].pNext
            invoke memory_Free, esi
            mov esi, edi
        .ENDW

    ;// free the common input stream

        .IF plugin_input_stream
            invoke memory_Free,plugin_input_stream
            mov plugin_input_stream, eax
        .ENDIF 

    ;// that's it

        ret

plugin_Destroy ENDP
;////////////////////////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////////////////////////
ASSUME_AND_ALIGN
plugin_Register PROC STDCALL uses esi edi ebx

    ;// this function always uses filename_plugin_path

    ;// our job is to make sure this is a vst plugin
    ;// we check if it's already registered
    ;// if not, we register it
    
        LOCAL hLib:DWORD                ;// handle of dll
        LOCAL pMain:PTR vst_Main        ;// pointer to main function
        LOCAL pAEffect:PTR vst_AEffect  ;// pointer to the return AEffect from main

        LOCAL hKey:DWORD
        LOCAL disp:DWORD
        LOCAL buf[320]:BYTE

    ;// first we determine if this has already been registered

        slist_GetHead pluginR, esi
        mov edi, filename_plugin_path
        lea edi, (FILENAME PTR [edi]).szPath
        .WHILE esi
            invoke lstrcmpiA, ADDR [esi].szFileName, edi
            .IF !eax            ;// already registered              
                mov eax, esi    ;// return the device pointer   
                jmp AllDone 
            .ENDIF
            slist_GetNext pluginR, esi
        .ENDW

    ;// if we get here, the file name was not found

    ;// so now we want to load the dll

        invoke LoadLibraryA, edi
        .IF !eax    ;// couldn't load the libray
            lea esi, plugin_szNoLib 
            jmp and_exit
        .ENDIF
        mov hLib, eax
    
    ;// then locate a main function

        invoke GetProcAddress, hLib, OFFSET plugin_szMain
        .IF !eax    ;// main function not found         
            lea esi, plugin_szNotVst
            jmp unload_lib
        .ENDIF
        mov pMain, eax

    ;// now we call the main function
    ;// when this returns we get a pointer to AEffects

        invoke pMain, OFFSET plugin_AMCallback
        .IF !eax    ;// plugin doesn't like us          
            lea esi, plugin_szNoLike
            jmp unload_lib
        .ENDIF                  
        mov pAEffect, eax
        
    ;// check the magic number

        .IF DWORD PTR [eax] != VST_MAGIC_NUMBER
            lea esi, plugin_szNotVst
            jmp unload_lib          ;// not a valid plugin
        .ENDIF
            
    ;// so far so good
    ;// now get some info about the plugin
    ;// and build our registry entry    
    ;// then return a pointer to the new entry

    ;// allocate a reg entry and set what we need to

        slist_AllocateHead pluginR, ebx

        mov esi, pAEffect
        ASSUME esi:PTR vst_AEffect

        mov edx,[esi].numInputs     ;// number of inputs we need
        mov ecx,[esi].numOutputs    ;// number of outputs

    ;// check for too many ins or outs

        .IF edx > 8 || ecx > 8          
            slist_FreeHead pluginR, ebx ;// remove the entry we just created
            lea esi, plugin_szTooMuch   ;// set err message
            jmp unload_lib          
        .ENDIF 

        mov eax,[esi].numParams     ;// tells us how to set up the plugin

        mov [ebx].numInputs, edx
        mov [ebx].numOutputs, ecx
        mov [ebx].numParameters, eax

    ;// save the file name

        invoke lstrcpyA, ADDR [ebx].szFileName, edi

    ;// copy the dll name to our name, make sure it's not too long

        mov edx, filename_plugin_path
        ASSUME edx:PTR FILENAME

        invoke lstrlenA, [edx].pName
        mov ecx, 31
        .IF eax < 32
            mov ecx, eax
        .ENDIF

        mov edx, filename_plugin_path
        lea edi, [ebx].szPlugName
        mov esi, [edx].pName
        rep movsb
        xor eax, eax
        stosb

    ;// we're done with this dll

        invoke FreeLibrary, hLib

    ;// determine the checksum by accumulating the sum of the bytes

        mov ecx, SIZEOF PLUGIN_REGISTRY
        mov esi, ebx
        inc [ebx].checksum

    @1: lodsb       
        inc eax     
        add [ebx].checksum, eax
        dec ecx
        jnz @1
            
    ;// now we store this in the registry

        ;// open the registry key

        invoke RegCreateKeyExA,
            HKEY_CURRENT_USER,
            OFFSET plugin_szRegKey, ;// Software\AndyWare\ABox\vst_plugins
            REG_OPTION_RESERVED,
            0,
            REG_OPTION_NON_VOLATILE,
            KEY_SET_VALUE + KEY_CREATE_SUB_KEY + KEY_QUERY_VALUE,
            0,
            ADDR hKey,
            ADDR disp

        ;// need to figure out what to call this        
        ;// we don't need anything very special so we'll use checksum to generate a name

    @3: 
        invoke wsprintfA, ADDR buf, OFFSET plugin_szFmtName, [ebx].checksum

        ;// check for duplicate

            invoke RegQueryValueExA, hKey, ADDR buf, 0, 0, 0, 0
            .IF !eax || ![ebx].checksum                             
                inc [ebx].checksum
                jmp @3
            .ENDIF
                    
        ;// determine the save length to save registry space

            invoke lstrlenA, ADDR [ebx].szFileName
            mov edx, REGISTRY_MIN_SAVE + 1
            add edx, eax

        ;// set the value
            
            invoke RegSetValueExA, 
                hKey, 
                ADDR buf,
                0, 
                REG_BINARY, 
                ADDR [ebx].REGISTRY_SAVE_START, 
                edx

        ;// close the key
        
            invoke RegCloseKey, hKey

        ;// then return non zero

            mov eax, 1
        
    ;// that should do it
        
    AllDone:

        ret


;// local error exit points

unload_lib:     ;// esi must point to an error message

    invoke FreeLibrary, hLib

and_exit:       ;// esi must point to an error message
                ;// edi must point at filename_plugin_path.szPath

    invoke lstrcpyA, ADDR buf, edi
    invoke lstrcatA, ADDR buf, esi
    or app_DlgFlags, DLG_MESSAGE        
    invoke MessageBoxA,0,ADDR buf, OFFSET plugin_szProblem, MB_ICONHAND + MB_OK + MB_TASKMODAL + MB_SETFOREGROUND
    and app_DlgFlags, NOT DLG_MESSAGE

    ;// show a message

    xor eax, eax    ;// make sure we return zero
    jmp AllDone

plugin_Register ENDP
;////////////////////////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////////////////////////
plugin_Match PROC STDCALL uses esi edi ebx pObject:PTR OSC_OBJECT

    ;// this can be called from ctor or _command

    ;// our job is to locate a registry entry for the object

    ;// if dwUser is not zero
    ;// then we locate the checksum
    ;// if check sum is not found, try to find another match
    ;// if another match is not found, then return zero
    ;// if another match is found, we replace dwUser with the new checksum
    
    ;// if dwUser is zero, we ignore

    ;// regradless, we set up pRegistry with what we find
    ;// and return the pointer

        xor edx, edx    
        GET_OSC edi 
        or edx, [edi].dwUser
        OSC_TO_DATA edi, ebx, OSC_PLUGIN
        .IF !ZERO?      
        
            ;// try to locate the checksum
            slist_GetHead pluginR, esi
            .WHILE esi 
                .IF [esi].checksum == edx                           
                    jmp AllDone         ;// got it
                .ENDIF
                slist_GetNext pluginR, esi
            .ENDW

            ;// if we get here, no match was found
            ;// so we try to find something suitable
            
            slist_GetHead pluginR, esi
            .WHILE esi      
                invoke lstrcmpiA, ADDR [ebx].szPlugName, ADDR [esi].szPlugName       
                .IF !eax    
                    mov eax, [ebx].numInputs
                    .IF [esi].numInputs == eax
                        mov eax, [ebx].numOutputs
                        .IF [esi].numOutputs == eax
                            mov eax, [ebx].numParameters
                            .IF [esi].numParameters == eax
                                mov eax, [esi].checksum
                                mov [edi].dwUser, eax   ;// set the new checksum                            
                                jmp AllDone
                            .ENDIF
                        .ENDIF
                    .ENDIF
                .ENDIF
                slist_GetNext pluginR, esi  
            .ENDW

        .ELSE

            ;// dwUser was zero
            xor esi, esi    ;// this is a wasted step ??

        .ENDIF

    AllDone:

        mov [ebx].pRegistry, esi;// set the registry
        mov eax, esi            ;// store the return value

        ret

plugin_Match ENDP
;////////////////////////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
PROLOGUE_OFF
plugin_build_display_name PROC STDCALL pObject:DWORD

        xchg ebx, [esp+4]
        ASSUME ebx:PTR PLUGIN_OSC_MAP

        push esi
        push edi

        lea esi, [ebx].plug.szPlugName
        lea edi, [ebx].plug.szDisplayName
        xor eax, eax
        
    J1: lodsb
        or al, al
        jz J2
        
        .IF !(  ( al >= 30h && al <= 39h ) ||   \
                ( al >= 41h && al <= 5Ah ) ||   \
                ( al >= 61h && al <= 7Ah ) )
                mov al, ' '
        .ENDIF

        stosb
        jmp J1
        
    J2: stosb   

        pop edi
        pop esi
        xchg ebx, [esp+4]
        
        retn 4

plugin_build_display_name ENDP  
PROLOGUE_ON
;////////////////////////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////////////////////////
ASSUME_AND_ALIGN
plugin_Open PROC STDCALL uses esi edi pObject:PTR OSC_OBJECT, bRead:DWORD
        
    comment ~ /*        

        destroys ebx
        
        make sure the dll is loaded
        add this object to the plugin_registry list
        call pMain for the plugin
        stuff in whatever parameters we have

        called from plugin_Attach   when user chooses a plugin in plugin_Command
                        plugin_Ctor     when loading from a file                
                        plugin_InitMenu as a double check, after plugin_Match
                        plugin_Command  after plugin_Match
                        plugin_LoadUndo when assigning a new plugin

    */ comment ~

        LOCAL hKey:DWORD
        LOCAL disp:DWORD
        LOCAL buf[16]:BYTE

        GET_OSC esi
        OSC_TO_DATA esi, esi, OSC_PLUGIN    ;// esi is our osc_plugin
        mov edi, [esi].pRegistry            ;// edi is the plugin_registry we use 
        ASSUME edi:PTR PLUGIN_REGISTRY

    ;// load the plugin ?

        .IF ![edi].hModule  ;// already loaded ?

            ;// so now we want to load the dll

                invoke LoadLibraryA, ADDR [edi].szFileName
                .IF !eax        ;// couldn't load the libray
                    
                    ;// this happens when user moves a plugin AFTER abox has loaded
                    ;// or if the plug cannot be loaded
                    ;// what now ?
                    ;// some how we have to:
                    ;//     remove this from the pRegList
                    ;//     delete the key from the registry
                    ;//     tell the object that we aren't valid

                    ;// we should be able to say that there are no other objects using this
                    
                    mov [esi].pRegistry, 0      ;// shut off the reg entry in the osc               
                    slist_Remove pluginR, edi   ;// remove from pluginR list

                    ;// open our key
                    invoke RegCreateKeyExA,
                        HKEY_CURRENT_USER,
                        OFFSET plugin_szRegKey, ;// Software\AndyWare\ABox\vst_plugins
                        REG_OPTION_RESERVED,0,REG_OPTION_NON_VOLATILE,KEY_SET_VALUE + KEY_CREATE_SUB_KEY + KEY_QUERY_VALUE,
                        0,ADDR hKey,ADDR disp

                    ;// build the name
                    invoke wsprintfA, ADDR buf, OFFSET plugin_szFmtName, [edi].checksum

                    ;// delete the key
                    invoke RegDeleteValueA, hKey, ADDR buf
                    
                    ;// close the key
                    invoke RegCloseKey, hKey

                    ;// delete the memory
                    invoke memory_Free, edi

                    ;// hope for the best
                    xor eax, eax
                    jmp AllDone

                .ENDIF
                mov [edi].hModule, eax  ;// store the module handle
            
            ;// locate the main function

                invoke GetProcAddress, [edi].hModule, OFFSET plugin_szMain
                DEBUG_IF <!!eax>        ;// main function not found         
                                        ;// supposed to be able to do this
                mov [edi].pMain, eax    ;// store in registry

        .ENDIF

    ;// insert the object in the plugin_registry list

        GET_OSC ebx             ;// get our object
        mov ecx, [edi].pHeadOsc ;// get the head of the list
        mov [edi].pHeadOsc, ebx ;// set the new head as us
        mov [esi].pNextOsc, ecx ;// set our next pointer as the old head

    ;// call main and get an AEffect pointer
        
        invoke EnableWindow,hMainWnd,0  ;// disable incase of splash screen

        invoke [edi].pMain, OFFSET plugin_AMCallback
        DEBUG_IF <!!eax>    ;// plugin doesn't like us          
                            ;// not supposed to happen  
        mov [esi].pAEffect, eax ;// save the pointer in our osc_plugin
        mov ebx, eax
        ASSUME ebx:PTR vst_AEffect

        invoke EnableWindow,hMainWnd,1  ;// re-enable

    ;// open and setup system level effects stuff
    ;// ABOX233, added new changed order as per VST2.3

        ;// pDispatcher:

        ;// effSetSampleRate,   // in opt (float)
        invoke [ebx].pDispatcher,ebx,effSetSampleRate,0,0,0,math_44100  ;//SampleRate

        ;// effSetBlockSize,    // in value
        invoke [ebx].pDispatcher,ebx,effSetBlockSize,0,SAMARY_LENGTH,0,0    ;// fOpt:REAL4

        ;// effectOpen
        invoke [ebx].pDispatcher,ebx,effOpen,0,0,0,0

        ;// effMainsChanged
        invoke [ebx].pDispatcher, ebx, effMainsChanged, 0, 1, 0, 0  ;// resume
        
        ;// effectCanDo receive midi events
        invoke [ebx].pDispatcher,ebx,effCanDo,0,0,OFFSET sz_can_receive,0
            dec eax     ;// 1 = yes, 0 = don't know, -1 = definately not
            .IF ZERO?
                mov [esi].can_receive, 1
                .IF !plugin_input_stream
                    invoke plugin_InitializeStream
                .ENDIF
            .ENDIF

        ;// effectCanDo send midi events
        invoke [ebx].pDispatcher,ebx,effCanDo,0,0,OFFSET sz_can_send,0
            dec eax     ;// 1 = yes, 0 = don't know, -1 = definately not
            .IF ZERO?
                mov [esi].can_send, 1
            .ENDIF


        ;// effStartProccess
        invoke [ebx].pDispatcher, ebx, effStartProcess, 0, 0, 0, 0


    ;// setup the plugin's settings, or read them
    ;// FYI: parameters are indeed stored in forwards order

        mov edi, [esi].pParameters  ;// edi points at the parameter block
        mov esi, [esi].numParameters;// esi counts them
        .IF esi                     ;// make sure there are some

            .IF bRead       ;// get the default settings from the plugin

                .WHILE esi
                    
                    dec esi
                    invoke [ebx].pGetParameter, ebx, esi
                    fstp DWORD PTR [edi+esi*4]              

                .ENDW

            .ELSE       ;// write the osc settings to the plugin

                .WHILE esi

                    dec esi
                    invoke [ebx].pSetParameter, ebx, esi, DWORD PTR [edi+esi*4]

                .ENDW

            .ENDIF

        .ENDIF

    ;// lastly, we build the display name, we turn all non ascii chars into spaces

        GET_OSC ebx
        invoke plugin_build_display_name, ebx

    ;// that should do it

        mov eax, 1  ;// return sucess

    AllDone:

        ret

plugin_Open ENDP

;////////////////////////////////////////////////////////////////////////////////////////




;////////////////////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
plugin_Attach PROC STDCALL USES esi edi pObject:PTR OSC_PLUGIN, pRegistry:PTR PLUGIN_REGISTRY

    ;// this should ONLY be called: 
    ;//     when the user chooses a new plug

    ;// this function attaches a plugin to an object
    ;// by copying several settings from the plugins registry entry

    ;// our job is to make sure we can save, load, and recreate the object
    ;// even though the plugin can not be found

    ;// so we also open the plugin, and initialize it

        GET_OSC edi

        mov esi, pRegistry              ;// get plugin registry entry
        ASSUME esi:PTR PLUGIN_REGISTRY

        mov eax, [esi].checksum         ;// load the checksum
        mov [edi].dwUser, eax           ;// store in osc dword user

        OSC_TO_DATA edi, edi, OSC_PLUGIN;// point at osc_plugin

        mov [edi].pRegistry, esi        ;// store the reg pointer

    ;// xfer the default settings

        mov ebx, [esi].numParameters    ;// save for a moment
        lea edi, [edi].PLUGIN_SAVE_START;// start of save data
        mov ecx, PLUGIN_MINIMUM_SAVE
        lea esi, [esi].PLUGIN_SAVE_START;// start of save data

        rep movsd   ;// mov the data

        .IF ebx
                
            ;// ABOX233 DEBUG_IF <DWORD PTR [edi]>      ;// this isn't spossed to be allocated yet
            ;// sometimes it does, for example if the plug could not be loaded
            .IF DWORD PTR [edi]
            invoke memory_Free, DWORD PTR [edi]
            .ENDIF

            ;// allocate the parameter memory
            shl ebx, 2  ;// *4
            invoke memory_Alloc, GPTR, ebx
            stosd

        .ENDIF

    ;// then make sure the object is set up

        invoke plugin_Open, pObject, 1  ;// read the settings

    ;// that should do it

    ret

plugin_Attach ENDP 

;////////////////////////////////////////////////////////////////////////////////////////







;////////////////////////////////////////////////////////////////////////////////////////

plugin_Close PROC STDCALL USES ebx esi edi pObject:PTR OSC_OBJECT
    
    ;// this function tells the plugin to close
    ;// we also remove ourselves from the pHeadOsc list in plugin registry
    ;// we assume that all parameters are already read

    ;// this is called from dtor and command

    DEBUG_IF <!!(play_status & PLAY_GUI_SYNC)>  ;// supposed to be in play sync

    GET_OSC ebx                     ;// ebx points at our osc
    OSC_TO_DATA ebx, esi, OSC_PLUGIN;// esi points at our osc_plugin
    mov edi, [esi].pRegistry        ;// edi points at our plugin_registry
    ASSUME edi:PTR PLUGIN_REGISTRY

    .IF edi     ;// skip if we're not registered

    ;// locate the item that points to us

        xor ecx, ecx                ;// ecx points at previous entry
        GET_OSC_FROM edx, [edi].pHeadOsc    ;// edx walks the list

        .WHILE edx != ebx                   ;// scan until match
            GET_OSC_FROM ecx, edx           ;// xfer new to prev
            OSC_TO_DATA edx, edx, OSC_PLUGIN;// get the osc's plugin
            mov edx, [edx].pNextOsc         ;// get the next osc
        .ENDW       
        
    ;// now ecx points at the item that points to us

        mov eax, [esi].pNextOsc     ;// get our next osc
        .IF !ecx                    ;// no item pointed to us                       
            mov [edi].pHeadOsc, eax ;// set our next as the new head
        .ELSE
            OSC_TO_DATA ecx, ecx, OSC_PLUGIN
            mov [ecx].pNextOsc, eax ;// set the new next
        .ENDIF

    ;// tell the plugin to un-initialize itself

        mov ebx, [esi].pAEffect
        ASSUME ebx:PTR vst_AEffect

        ;// effStopProccess
        invoke [ebx].pDispatcher, ebx, effStopProcess, 0, 0, 0, 0

        ;// effMainsChanged
        invoke [ebx].pDispatcher, ebx, effMainsChanged, 0, 0, 0, 0  ;// suspend

        ;//     effectClose 
        invoke [ebx].pDispatcher, ebx, effClose, 0, 0, 0, 0

    ;// zero our AEffects pointer

        mov [esi].pAEffect, 0

    ;// check if it's time to unload the dll

        .IF ![edi].pHeadOsc     ;// yep
            invoke plugin_Unload, edi
        .ENDIF

    ;// set our registry as zero

        mov [esi].pRegistry, 0

    .ENDIF


    ;// that should do it

    ret

plugin_Close ENDP

;////////////////////////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
plugin_Detach PROC STDCALL USES esi edi ebx pObject:DWORD

        GET_OSC esi
        ASSUME esi:PTR PLUGIN_OSC_MAP
        
        .IF editor_hWnd_Cage
            call plugin_CloseEditor ;// defined below, so we call, not invoke
        .ENDIF
            
        or [esi].dwHintI, HINTI_OSC_SHAPE_CHANGED
        invoke plugin_Close, esi

        xor eax, eax
        mov [esi].dwUser, eax

        lea edi, [esi].plug.PLUGIN_SAVE_START
        mov ecx, PLUGIN_MINIMUM_SAVE
        rep stosd
        .IF [esi].plug.pParameters
            invoke memory_Free, [esi].plug.pParameters
            mov [esi].plug.pParameters, eax
        .ENDIF
        ;// ABOX233: need to zero these too
        mov [esi].plug.can_send, eax
        mov [esi].plug.can_receive, eax

        ret

plugin_Detach ENDP



;////////////////////////////////////////////////////////////////////////////////////////
ASSUME_AND_ALIGN
plugin_ReadParameters PROC STDCALL uses esi edi ebx pObject:PTR OSC_OBJECT

    ;// this is called from popup_Proc when a plug is being shut down
    ;// it xfers the plug internal parameters to our osc.parameter block

    GET_OSC esi
    OSC_TO_DATA esi, esi, OSC_PLUGIN
    mov edi, [esi].pParameters  ;// edi points at the parameter block
    mov ebx, [esi].pAEffect     ;// ebx is the AEffect
    ASSUME ebx:PTR vst_AEffect
    mov esi, [esi].numParameters;// esi counts them

    .WHILE esi
        
        dec esi
        invoke [ebx].pGetParameter, ebx, esi
        fstp DWORD PTR [edi+esi*4]      

    .ENDW

    ret

plugin_ReadParameters ENDP
;////////////////////////////////////////////////////////////////////////////////////////



















;////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////
;////
;////       osc_object functions
;////
ASSUME_AND_ALIGN
osc_Plugin_Ctor PROC


        ;// register call
        ASSUME ebp:PTR LIST_CONTEXT ;// preserve
        ASSUME esi:PTR OSC_OBJECT   ;// preserve    
        ASSUME edi:PTR OSC_BASE     ;// may_destroy
        ASSUME ebx:PTR FILE_OSC     ;// may destroy
        ASSUME edx:PTR FILE_HEADER  ;// may destroy

    ;// dwUser contains the object id for this
    ;// if it's zero, then we setup for just a placeholder

    ;// we've been created
    ;// now we check if we're being created from a file
        
        .IF edx     ;// loading from file ??

            push esi
            
            OSC_TO_DATA esi, edi, OSC_PLUGIN    ;// edi points at plugin data
            GET_FILE_OSC esi, ebx               ;// xfer ebx to esi

            lea esi, [esi+SIZEOF FILE_OSC+4]    ;// add four for dwUser
            mov edx, DWORD PTR [esi+8]          ;// get num parameters from file
            mov ecx, PLUGIN_MINIMUM_SAVE        ;// get bare minimum
            lea edi, [edi].PLUGIN_SAVE_START    ;// point at start of saved data

            rep movsd

            or  ecx, edx        ;// load the number of parameters
            .IF !ZERO?

                push edx
                shl ecx, 2  ;// * 4
                invoke memory_Alloc, GPTR, ecx
                mov DWORD PTR [edi], eax    ;// save as pParameter
                pop ecx                     ;// reload the number of parameters
                mov edi, eax                ;// now it's edi

                rep movsd       ;// load 'em all

            .ENDIF

            pop esi

            ASSUME esi:PTR OSC_OBJECT

            ;// try to locate a plugin          
            .IF [esi].dwUser

                invoke plugin_Match, esi
                .IF eax
                    invoke plugin_Open, esi, 0  ;// open and write settings
                .ENDIF

            .ENDIF

        .ENDIF  ;// not loading from file

    ;// now that we know what we're supposed to be
    ;// we need to update our pins
    ;// we can't do that here, so we'll catch it on SetShape

    ;// that's it

        ret

osc_Plugin_Ctor ENDP
;////////////////////////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////////////////////////
ASSUME_AND_ALIGN
osc_Plugin_Dtor PROC

    ASSUME esi:PTR OSC_OBJECT

    ;// release our count on the device
    
    invoke plugin_Detach, esi

    ;// that should do it


    ret

osc_Plugin_Dtor ENDP
;////////////////////////////////////////////////////////////////////////////////////////




;////////////////////////////////////////////////////////////////////////////////////////
ASSUME_AND_ALIGN
osc_Plugin_Render PROC

        invoke gdi_render_osc   ;// call render first

        ASSUME esi:PTR PLUGIN_OSC_MAP

    ;// show our plugin name

        GDI_DC_SELECT_FONT hFont_pin
        GDI_DC_SET_COLOR COLOR_OSC_TEXT

    ;// we'll format this as best we can

        PLUGIN_DISPLAY_TOP EQU 24

        mov eax, [esi].rect.top
        push [esi].rect.bottom      
        add eax, PLUGIN_DISPLAY_TOP
        push [esi].rect.right
        push eax
        push [esi].rect.left
        
        .IF [esi].dwUser
            
            lea ebx, [esi].plug.szDisplayName
            .IF !(BYTE PTR [ebx])
                invoke plugin_build_display_name, esi
                lea ebx, [esi].plug.szDisplayName
            .ENDIF

        .ELSE
            lea ebx, plugin_szChoose
        .ENDIF
        mov edx, esp
        invoke DrawTextA, gdi_hDC, ebx, -1, edx, DT_CENTER OR DT_WORDBREAK 
        add esp, SIZEOF RECT

    ;// that's it

        ret

osc_Plugin_Render ENDP



;////////////////////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
osc_Plugin_SetShape PROC

        ASSUME ebp:PTR LIST_CONTEXT ;// preserve
        ASSUME esi:PTR PLUGIN_OSC_MAP       ;// preserve
        ASSUME edi:PTR OSC_BASE     ;// preserve

        push edi

        ;// our task here is:
        ;//
        ;//     make sure pins are hidden/un hidden as required
        ;//     set their default pheta locations
        ;//

        ;// first we need to get a container

            invoke osc_SetShape

        ;// there are 4 loops
        ;// 1)  scan used input pins and make sure  they are unhidden
        ;//     and have a default pheta
        ;// 2)  scan the rest of the input pins and make sure they are hidden
        ;// 3)  scan used output pins and make sure they are unhidden
        ;//     and that they have a default pheta
        ;// 4)  scan the rest of the output pins and make sure they are hidden

        ;// in all 4 loops, ebx will scan forwards

            xor ecx, ecx
            OSC_TO_PIN_INDEX esi, ebx, 0    ;// first input

            st_dY   TEXTEQU <(DWORD PTR [esp+8])>
            st_Y    TEXTEQU <(DWORD PTR [esp+4])>
            st_X    TEXTEQU <(DWORD PTR [esp])>

            sub esp, 12

        ;// make sure we have pins to set
            
            or ecx, [esi].plug.numInputs    ;// load and test the number
            jz prepare_hide_inputs              ;// skip if no pins

        ;// determine the spacing for default pheta for the input pins
        
            mov eax, PLUGIN_HEIGHT
            inc ecx
            xor edx, edx
            div ecx

        ;// set up an fpu iterator

            mov st_dY, eax  ;// save the pin spacing        
            mov st_Y, eax   ;// save first Y
            mov st_X, 0     ;// always start at left

            dec ecx ;// need the actual number, not one plus
        
    ;// scan the first group (used inputs)

    unhide_inputs:  

        ;// make sure is unhidden

        invoke pin_Show, 1

        ;// set def pheta as well

        fild st_Y       ;// load Y
        fild st_X       ;// load X
        push ecx        ;// save the counter    
        invoke pin_ComputePhetaFromXY
        .IF ![ebx].pPin && !([ebx].dwStatus & PIN_BUS_TEST)
            fst [ebx].pheta
        .ENDIF      
        fstp [ebx].def_pheta
        pop ecx         ;// retrieve the counter
        mov eax, st_dY  ;// get the delta
        add st_Y, eax   ;// add to Y

        ;// iterate loop

        add ebx, SIZEOF APIN
        loopnzd unhide_inputs

    ;// 2) hide remaining input pins

        mov ecx, [esi].plug.numInputs

    prepare_hide_inputs:    ;// hide the rest

        sub ecx, PLUGIN_MAX_INPUTS  ;// subtract from total
        jz prepare_unhide_outputs   ;// if zero, then skip  
        DEBUG_IF <!!SIGN?>

        ;// make sure is hidden
        
        .REPEAT

            invoke pin_Show, 0          
            add ebx, SIZEOF APIN
            inc ecx

        .UNTIL ZERO?

        ;// ha, ecx will always be zero at his point
        
    prepare_unhide_outputs:

        ;// load and test the ouputs

            DEBUG_IF <ecx>  ;// oops, ecx was NOT zero
            or ecx, [esi].plug.numOutputs       
            jz prepare_hide_outputs

        ;// determine the spacing for default pheta for the output pins

            mov eax, PLUGIN_HEIGHT
            inc ecx
            xor edx, edx
            div ecx

        ;// set up the fpu iterator

            mov st_dY, eax  ;// save the pin spacing
            mov st_Y, eax   ;// save first Y
            mov st_X, PLUGIN_WIDTH  ;// always start at right

            dec ecx ;// need the actual number, not 1 plus

    unhide_outputs: ;// scan the used outputs

        ;// make sure is unhidden

            invoke pin_Show, 1

        ;// ABOX 233
        ;// make sure pData points at the correct spot

            mov edx, [esi].plug.numOutputs  ;// get num outputs
            sub edx, ecx                    ;// subtract count remaining to get index
            shl edx, SAMARY_SHIFT           ;// scale by size of sample block
            lea edx, [esi].data_1[edx]      ;// offset by current pointer and data_1 slot
            mov [ebx].pData, edx            ;// save in pin

        ;// set def pheta as well

        fild st_Y       ;// load Y
        fild st_X       ;// load X
        push ecx        ;// save the counter
        invoke pin_ComputePhetaFromXY
        .IF ![ebx].pPin && !([ebx].dwStatus & PIN_BUS_TEST)
            fst [ebx].pheta
        .ENDIF      
        fstp [ebx].def_pheta
        pop ecx         ;// retrieve the counter
        mov eax, st_dY  ;// get the delta
        add st_Y, eax   ;// add to Y

        ;// iterate loop

        add ebx, SIZEOF APIN
        loopnzd unhide_outputs

    ;// 4) remaining output pins

        mov ecx, [esi].plug.numOutputs

    prepare_hide_outputs:   ;// hide the rest

        sub ecx, PLUGIN_MAX_OUTPUTS

        .IF !ZERO?
        
            DEBUG_IF <!!SIGN?>

            ;// make sure is hidden
            .REPEAT

                invoke pin_Show, 0              
                ;// ABOX233: turn offthe data so we don't get nasty sounds
                mov edx, math_pNull     
                and [ebx].dwStatus, NOT PIN_CHANGING    ;// 0 doesn't change
                mov [ebx].pData, edx
                
                ;// iterate the loop
                add ebx, SIZEOF APIN
                inc ecx

            .UNTIL ZERO?

        .ENDIF

    ;// 5) check if the device is good or bad

        mov eax, HINTI_OSC_LOST_BAD ;// default to lost

        .IF ![esi].plug.pRegistry && [esi].dwUser

            mov eax, HINTI_OSC_GOT_BAD

        .ENDIF

        or [esi].dwHintI, eax
        
    ;// 6) if we can do midi events, show the appropriate pins

        lea ebx, [esi].pin_si
        xor eax, eax
        .IF [esi].plug.can_receive
            inc eax
        .ENDIF
        invoke pin_Show, eax

        add ebx, SIZEOF APIN
        xor eax, eax
        .IF [esi].plug.can_send
            inc eax
        .ENDIF
        invoke pin_Show, eax

    ;// 7) and thaz bout it

;// all_done:

        add esp, 12

        pop edi

        ret

osc_Plugin_SetShape ENDP

;////////////////////////////////////////////////////////////////////////////////////////














;////////////////////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
osc_Plugin_Write PROC uses esi

    ;// we assume that the plugin edit trap read all the parameters for us

        ASSUME esi:PTR PLUGIN_OSC_MAP       ;// preserve
        ASSUME edi:PTR FILE_OSC     ;// iterate as required             
    
    ;// tasks:  write extra count
    ;//         write dwUser
    ;//         write the plugin settings
    ;//         iterate edi as required

        mov eax, [esi].plug.extra   ;// get the extra count
        mov [edi].extra, eax            ;// store it

        lea edi, [edi+SIZEOF FILE_OSC]  ;// scoot to start of private data

        mov eax, [esi].dwUser           ;// load dwUser
        stosd                           ;// store dwUser

        mov ebx, [esi].plug.numParameters   ;// get for later
        mov ecx, PLUGIN_MINIMUM_SAVE    ;// load min size to save
        lea esi, [esi].plug.PLUGIN_SAVE_START;// get start of savable data

        rep movsd                       ;// dump it all

        .IF ebx                         ;// check if there's more from the plugin
            mov ecx, ebx                ;// xfer the count
            mov esi, DWORD PTR [esi]    ;// get pointer to allocated
            DEBUG_IF <!!esi>            ;// pParameters not allocated, not sposed to happen
            rep movsd                   ;// dump it
        .ENDIF

    ;// simple as that

        ret

osc_Plugin_Write ENDP
;////////////////////////////////////////////////////////////////////////////////////////




;////////////////////////////////////////////////////////////////////////////////////////
ASSUME_AND_ALIGN
osc_Plugin_AddExtraSize PROC

        ASSUME esi:PTR PLUGIN_OSC_MAP
        ASSUME ebx:PTR DWORD

    ;// assume that attach and or ctor have properly setup the object for us

        mov eax, [esi].plug.numParameters
        shl eax, 2  ;// *4 for dwords
        add eax, 4 + PLUGIN_MINIMUM_SAVE * 4
        mov [esi].plug.extra, eax       ;// no sense doing this twice
        
        add [ebx], eax  ;// add to passed pointer
        ret

osc_Plugin_AddExtraSize ENDP


;////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////










;////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////
;///
;///    parameter editor fabrication
;///    


ASSUME_AND_ALIGN
plugin_FabricateEditor PROC STDCALL USES edi ;// ABOX233 how'd edi get erased ???

    LOCAL rect:RECT
    LOCAL sInfo:SCROLLINFO
    LOCAL buf[64]:BYTE

    ASSUME esi:PTR PLUGIN_OSC_MAP
    ASSUME ebx:PTR vst_AEffect

    DEBUG_IF <[esi].plug.pAEffect !!= ebx>  ;// supposed to be the same
    
    DEBUG_IF <!!ebx>    ;// and not supposed to be zero

    ;// build a fake control panel ?
    ;// reqires writting scroll handlers for popup
    ;// probably not a bad idea anyways

    ;// each scroll needs a label, and a scroll
    ;// all these can go in a big rect that slides down
    ;// since parameters names are limited to 8 chars, we'll probly not wrap the label
    ;// parameter values are usually longer

;// set up for scan

    ;// make scrolls 192 wide
    ;// make labels 64 wide
    ;// make cur value 96 wide

    xor edi, edi            

    mov rect.left, PLUGIN_LABEL_WIDTH       ;// rect.left is label width, and scroll.left
    mov rect.top, edi                       ;// rect.top iterates down
    mov rect.bottom, PLUGIN_BUTTON_HEIGHT   ;// rect botton is pretty tame
    mov rect.right, PLUGIN_SCROLL_WIDTH     ;// rect right is scroll width

    ;// define the scroll parameters
    mov sInfo.dwSize, SIZEOF SCROLLINFO
    mov sInfo.dwMask, SIF_RANGE + SIF_PAGE + SIF_POS
    mov sInfo.dwMin, edi
    mov sInfo.dwMax, PLUGIN_SCROLL_RANGE + PLUGIN_SCROLL_RANGE/16 - 1
    mov sInfo.dwPage, PLUGIN_SCROLL_RANGE/16

    ;// do the scan
    .WHILE edi < [ebx].numParams

    ;// build the label

        ;// get the text label
        ;// pDispatcher
        ;// effGetParamName     equ 08;// stuff parameter <index> label (max 8 char + 0) into string
        invoke [ebx].pDispatcher, ebx, effGetParamName, edi, 0, ADDR buf, 0

        ;// create the label
        invoke CreateWindowExA, 0, OFFSET szStatic, ADDR buf,
            SS_CENTER + SS_CENTERIMAGE + WS_BORDER + WS_CHILD + WS_VISIBLE,
            0, rect.top,
            rect.left, rect.bottom,
            popup_hWnd,IDC_STATIC, hInstance, 0
        ;// set the font
        invoke PostMessageA, eax, WM_SETFONT, hFont_popup, 1

    ;// build the scroll bar
        
        ;// get current value of property
        invoke [ebx].pGetParameter, ebx, edi
        ;// results are returned in fpu
        fmul plugin_ScrollUnscale       ;// turn results into a position
        fistp sInfo.dwPos

        ;// define the cmd ID
        lea edx, [edi+OSC_COMMAND_SCROLL]

        ;// create a small space between
        inc rect.top        
        dec rect.bottom

        ;// create the scroll bar
        invoke CreateWindowExA, 0, OFFSET szScrollBar, 0,
            WS_VISIBLE + WS_CHILD + SBS_HORZ,
            rect.left, rect.top,
            rect.right, rect.bottom,
            popup_hWnd,edx, hInstance, 0

        ;// remove the space
        dec rect.top        
        inc rect.bottom

        ;// set the range               
        lea edx, sInfo                  
        invoke SetScrollInfo, eax, SB_CTL, edx, 0
        
    ;// build the value box and assign id so we can set it
        
        ;// get the value
        ;// pDispatcher
        ;// effGetParamDisplay  equ 07;// stuff parameter <index> textual representation into string
        invoke [ebx].pDispatcher, ebx, effGetParamDisplay, edi, 0, ADDR buf, 0

        ;// append the type to it
        lea ecx, buf
    J0: cmp BYTE PTR [ecx], 0
        je J1
        inc ecx
        jmp J0
    J1: mov BYTE PTR [ecx], ' '
        inc ecx
        invoke [ebx].pDispatcher, ebx, effGetParamLabel, edi, 0, ecx, 0

        ;// set the cmd is as scroll+128
        lea edx, [edi+OSC_COMMAND_SCROLL+PLUGIN_SCROLL_TO_LABEL]

        ;// build the label and set the font
        invoke CreateWindowExA, 0, OFFSET szStatic, ADDR buf,
            SS_CENTER + SS_CENTERIMAGE + WS_BORDER + WS_CHILD + WS_VISIBLE,
            PLUGIN_POPUP_WIDTH, rect.top,
            96, rect.bottom,
            popup_hWnd,edx, hInstance, 0
        invoke PostMessageA, eax, WM_SETFONT, hFont_popup, 1
        
    ;// iterate

        add rect.top, PLUGIN_BUTTON_HEIGHT
        inc edi

    .ENDW

    ;// now we return our new size

    mov eax, PLUGIN_POPUP_WIDTH + 96
    mov edx, rect.top

    ret

plugin_FabricateEditor ENDP






;// defined in popup_help.asm

EXTERNDEF sz_IDC_PLUGIN_IDC_PLUGIN_REGISTER:BYTE
EXTERNDEF sz_IDC_PLUGIN_IDC_PLUGIN_LIST:BYTE
EXTERNDEF sz_IDC_PLUGIN_IDC_PLUGIN_REMOVE:BYTE


ASSUME_AND_ALIGN
plugin_CreateDefaultPanel PROC uses esi edi
                        
    ;// now we create all the buttons
    ;// this should really be a list box ...
    ;// ok, now it is a list box

    ;// create the 'register' button and set the font

        invoke CreateWindowExA, WS_EX_NOPARENTNOTIFY , 
            OFFSET szButton,    OFFSET plugin_szRegister,
            PLUGIN_BUTTON_STYLE,
            0, POPUP_HELP_HEIGHT, 
            PLUGIN_LISTBOX_WIDTH, PLUGIN_BUTTON_HEIGHT,
            popup_hWnd, IDC_PLUGIN_REGISTER, hInstance, 0
        mov esi, eax
        invoke PostMessageA, eax, WM_SETFONT, hFont_popup, 1        
        invoke SetWindowLongA, esi, GWL_USERDATA, OFFSET sz_IDC_PLUGIN_IDC_PLUGIN_REGISTER

    ;// create the list box

        ;// create the listbox, save the handle and set the font
        invoke CreateWindowExA, WS_EX_NOPARENTNOTIFY , 
            OFFSET szListBox, 0,
            PLUGIN_LISTBOX_STYLE,
            0, PLUGIN_BUTTON_HEIGHT + POPUP_HELP_HEIGHT, 
            PLUGIN_LISTBOX_WIDTH, PLUGIN_LISTBOX_HEIGHT,
            popup_hWnd, IDC_PLUGIN_LIST, hInstance, 0
        mov edi, eax            ;// save the list box handle
        invoke PostMessageA, edi, WM_SETFONT, hFont_popup, 1        
        invoke SetWindowLongA, edi, GWL_USERDATA, OFFSET sz_IDC_PLUGIN_IDC_PLUGIN_LIST

    ;// create the remove button

        invoke CreateWindowExA, WS_EX_NOPARENTNOTIFY , 
            OFFSET szButton,    OFFSET plugin_szRemove,
            PLUGIN_BUTTON_STYLE,
            0, PLUGIN_LISTBOX_HEIGHT + PLUGIN_BUTTON_HEIGHT + POPUP_HELP_HEIGHT, 
            PLUGIN_LISTBOX_WIDTH, PLUGIN_BUTTON_HEIGHT,
            popup_hWnd, IDC_PLUGIN_REMOVE, hInstance, 0
        mov esi, eax
        invoke PostMessageA, eax, WM_SETFONT, hFont_popup, 1        
        invoke SetWindowLongA, esi, GWL_USERDATA, OFFSET sz_IDC_PLUGIN_IDC_PLUGIN_REMOVE
        
    ;// add all the items to the list box

        slist_GetHead pluginR, esi      ;// scan the plugin list
        jmp P0                          ;// skip the first entry
        .REPEAT ;// add the string and set the item data
            invoke SendMessageA, edi, LB_ADDSTRING, 0, ADDR [esi].szPlugName
            invoke SendMessageA, edi, LB_SETITEMDATA, eax, esi
        P0: slist_GetNext pluginR, esi  ;// get the next entry in registered list
        .UNTIL !esi

    ;// highlight the index of the last selected item

        or esi, last_known_registry
        .IF !ZERO?
            WINDOW edi,LB_FINDSTRING,-1,ADDR [esi].szPlugName
            .IF eax != -1
                mov last_selection_item, eax
            .ENDIF
            mov last_known_registry, 0
        .ENDIF

        .IF last_selection_item != -1
            WINDOW edi,LB_SETCURSEL,last_selection_item,0
        .ENDIF

    ;// set the return values and leave

    comment ~ /*
        mov eax, PLUGIN_LISTBOX_WIDTH
        mov edx, PLUGIN_BUTTON_HEIGHT*2 + PLUGIN_LISTBOX_HEIGHT + POPUP_HELP_HEIGHT
    */ comment ~

        xor eax, eax    ;// use the default size

        ret

plugin_CreateDefaultPanel ENDP

;////////////////////////////////////////////////////////////////////////////////////////

comment ~ /*    

osc_Plugin_InitMenu

    outline:
    
        if object is registered (dwUser)
            
            if object has plugin (pAEffect)
            
                if that plugin does not have an editor

                    fabricate an editor 

                else 
                
                    launch built in editor

                endif

            else (no plugin)

                check for a match
                if match is found
                    open it
                    jmp to built_in_editor check
                endif

            endif

        else (not registered yet)

            build the chooser panel

        endif

*/ comment ~                    

ASSUME_AND_ALIGN
osc_Plugin_InitMenu PROC

                    
        ASSUME esi:PTR PLUGIN_OSC_MAP
        ASSUME ebp:PTR LIST_CONTEXT
        xor ebx, ebx                        ;// clear for testing

        CMPJMP [esi].dwUser, ebx, jz not_assigned_yet   ;// are we assigned yet ?

    are_assigned:

        ORJMP ebx, [esi].plug.pAEffect, jz no_plug_yet  ;// do we have a plugin ?
        ASSUME ebx:PTR vst_AEffect

    have_a_plug:

    ;// so we add the the change menu item here
    ;// we will remove as required

        invoke GetMenu, popup_hWnd
        invoke AppendMenuA, eax, MF_STRING, OSC_COMMAND_CHANGE, OFFSET sz_Change
    
ECHO also need to implement the 'program' menu item

        TESTJMP [ebx].flags, effFlagsHasEditor, jz have_to_fabricate    ;// check if plugin has an editor

    plug_has_editor:

        invoke plugin_LaunchEditor
        jmp all_done

    have_to_fabricate:

        invoke plugin_FabricateEditor       ;// use this function
        jmp all_done

    no_plug_yet:

        invoke plugin_Match, esi    ;// let's check for a match really quick            
        TESTJMP eax, eax, jz not_assigned_yet

    have_a_new_plugin:
        
        invoke plugin_Open, esi, 0      ;// open the plug, don't try to read data
        
        GDI_INVALIDATE_OSC HINTI_OSC_SHAPE_CHANGED
        jmp have_a_plug                 ;// jump to menu opener
        
    not_assigned_yet:

        invoke plugin_CreateDefaultPanel

    all_done:
        
        ;// that's it
        ;// the three functions are supposed to return with eax and edx as the size

        ret


osc_Plugin_InitMenu ENDP

;///
;///    parameter editor fabrication
;///    
;////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////






;//////////////////////////////////////////////////////////////////////////////////////////////
ASSUME_AND_ALIGN
osc_Plugin_Command PROC

        ASSUME ebp:PTR LIST_CONTEXT
        ASSUME esi:PTR PLUGIN_OSC_MAP
        ;// eax has the command id
        ;// ecx may have extra data

        cmp eax, OSC_COMMAND_SCROLL         ;// scroll message from custom dialog
        jb @F
        cmp eax, OSC_COMMAND_SCROLL_LAST
        jbe got_scroll_message
    @@: 
        CMPJMP eax, OSC_COMMAND_LIST_DBLCLICK, je set_plugin    ;// double click a list item
        CMPJMP eax, IDC_PLUGIN_REGISTER, je register_plugins    ;// the register button
        CMPJMP eax, IDC_PLUGIN_REMOVE, je remove_plugin         ;// the remove button
        CMPJMP eax, OSC_COMMAND_CHANGE, je change_plugin        ;// the change button
        CMPJMP eax, OSC_COMMAND_POPUP_DEACTIVATE, je popup_is_deactivating
        CMPJMP eax, OSC_COMMAND_POPUP_ACTIVATE,   je popup_is_activating
        CMPJMP eax, OSC_COMMAND_POPUP_WINDOWPOSCHANGING, je popup_windowposchanging

        jmp  osc_Command

;////////////////////////////////////////////////////////////////////////////////////////////

;// user says ... i want to find a new plugin
ALIGN 16
register_plugins:

        invoke filename_GetFileName, GETFILENAME_PLUGIN

    ;// this version returns a block of memory that we need to dealloacte

        TESTJMP eax, eax, jnz yep_register_plugins      ;// check if user canceled
        MOVJMP eax, POPUP_INITMENU,     jmp all_done    ;// user canceled
                        
    yep_register_plugins:

        ;// since we allow multiple selection
        ;//     eax is start of a buffer that we need to deallocate when we're done
        ;//     if user chooses multiple, the first item is the directory
        ;//     a single selection returns as the full name     
        ;//     filenames with spaces are not quoted
        ;// so we've many hassles to deal with
        
        push esi    ;// have to preserve
        push eax    ;// save so we can deallocate
        
        sub esp, 280+8  ;// iterators and space to build strings

        ASSUME edi:PTR BYTE
        ASSUME esi:PTR BYTE
        ASSUME ebx:PTR FILENAME

        ;// stack 
        ;// sz  file iter mem esi edi ret
        ;// 00  118  11C  120 124 

        st_sz   TEXTEQU <esp>                       ;// ptr to starting space
        st_file TEXTEQU <(DWORD PTR [esp+118h])>    ;// start of the file name on the stack
        st_iter TEXTEQU <(DWORD PTR [esp+11Ch])>    ;// current source filename we're working with

    ;// get filename_plugin_path to work with

        mov esi, eax    ;// better save this now !!

        mov ebx, filename_plugin_path
        .IF !ebx
            invoke filename_GetUnused
            mov filename_plugin_path, ebx
        .ENDIF

    ;// 1) determine if we are a single item
    ;//     at the same time, copy the directory to the stack

        mov edi, st_sz
        xor eax, eax

        mov al, '"'     ;// always start with a quote

    R1: stosb       ;// top of sz copy
        lodsb       ;// get the next char
        or al, al   ;// check for zero
        jnz R1      ;// jmp back if not zero
        
        cmp [esi], 0        ;// are there more ?
        je register_plugins_single  ;// jmp if not

    register_plugins_multiple:

        mov al, '\'         ;// load the backslash
        stosb               ;// store the backslash
        mov st_file, edi    ;// store the start of the file name we need
        lodsb               ;// get the first char

        .REPEAT

            mov edi, st_file    ;// point at start of file name

        ;// copy the filename part

        R2: stosb       ;// top of sz copy
            lodsb       ;// get the next char
            or al, al   ;// check for zero
            jnz R2      ;// jmp back if not zero

            mov al, '"' ;// load closing quote
            stosw       ;// store closing quote and zero terminate          

        ;// initialize the string

            mov st_iter, esi    ;// store our current source
            mov esi, st_sz      ;// load the start of the string
            invoke filename_InitFromString, FILENAME_FULL_PATH

        ;// register the plugin

            invoke plugin_Register

        ;// continue if there are more

            mov esi, st_iter    ;// load the current iter
            xor eax, eax        ;// clear for big smal
            lodsb               ;// get the next char

        .UNTIL !al

        jmp register_plugins_done


    register_plugins_single:

        mov al, '"' ;// load closing quote
        stosw       ;// store closing quote and zero terminate          

        mov esi, st_sz  ;// load the string start

        invoke filename_InitFromString, FILENAME_FULL_PATH  ;// initialize the string

        invoke plugin_Register  ;// register the plugin


    register_plugins_done:

    ;// clean up

        add esp, 280+8      ;// clean up the stack

        call memory_Free    ;// deallocate the origonal buffer
                            ;// pointer already on the stack

    plugin_verify_scan:     ;// also jumped to from plugin remove

        call plugin_Sort    ;// be nice and sort this

    ;// rip through oscZ and match all the plugins
    ;//
    ;// tasks:
    ;//
    ;//     scan entire circuit for bad plugins, see if there's a match
    ;//     dive into groups as required
    ;//         use a two push style so esp is a pointer to the list context
    ;//         and [esp+4] is the osc that caused the push

        push ebp        ;// must save
        mov edi, esp    ;// edi tells us when to stop

        lea ebp, master_context         ;// start at the start

        dlist_GetHead oscZ, esi, [ebp]  ;// esi scans oscs in the context
        jmp verify_enter_scan

    verify_top_of_scan:

        OSC_TO_BASE esi, edx        

        cmp edx, OFFSET osc_Plugin      ;// is this a plugin ?
        je verify_found_plugin          
        
        cmp [edx].data.ID, IDB_CLOSED_GROUP ;// is this a group ?
        je verify_found_group

    verify_iterate_scan:

        dlist_GetNext oscZ, esi

    verify_enter_scan:

        or esi, esi
        jnz verify_top_of_scan

        cmp esp, edi
        je verify_done_with_scan

        pop esi     ;// pop the iterator
        pop ebp     ;// pop the context
        jmp verify_iterate_scan

    verify_found_plugin:


        cmp [esi].dwUser, 0         ;// is this plugin assigned ?
        jz verify_iterate_scan      ;// nothing to match if not assigned

        GDI_INVALIDATE_OSC HINTI_OSC_SHAPE_CHANGED  ;// invalidate wheather good or bad

        OSC_TO_DATA esi, ecx, OSC_PLUGIN    ;// get the base class
        cmp [ecx].pRegistry, 0      ;// is plugin already attached ?
        jne verify_iterate_scan     ;// assume it's ok if already attached              
        
        invoke plugin_Match, esi    ;// so we check if this device is a match
        or eax, eax                 ;// match ??
        je verify_iterate_scan      ;// jmp if not
        invoke plugin_Open, esi, 0  ;// open and write the setting we loaded with
        
        jmp verify_iterate_scan
            
    verify_found_group:

        push ebp    ;// save the context
        push esi    ;// save the iterator
        
        OSC_TO_DATA esi, ecx, CLOSED_GROUP_DATA_MAP
        lea ebp, [ecx].context  ;// get the new context pointer

        dlist_GetHead oscZ, esi, [ebp]
        jmp verify_enter_scan

    verify_done_with_scan:

        pop ebp     ;// retrieve ebp
        pop esi     ;// always preserved esi        
        ASSUME esi:PTR PLUGIN_OSC_MAP

        ;// tell popup to reinitialize
        ;// lets user do this several time
        ;// then we can let user choose

        mov eax, POPUP_REBUILD OR POPUP_SET_DIRTY
        jmp all_done
                
;////////////////////////////////////////////////////////////////////////////////////////////

;// user double clicked on one of the plugins
ALIGN 16
set_plugin:

        ;// user says ... i want to use this plugin
        ;// ecx has the item data, which is the plugin registry pointer

        ;// get the index so we can set it nicely
        ;// need to do this before any nasty splash screens show up

        push ecx
        invoke GetDlgItem,popup_hWnd,IDC_PLUGIN_LIST
        WINDOW eax,LB_GETCURSEL
        mov last_selection_item, eax
        MESSAGE_LOG_PRINT_1 _setting_last_selection_,eax,<"_setting_last_selection_ %i">
        pop ecx
        
        ;// attach the new plugin settings
            
        invoke plugin_Attach, esi, ecx
        GDI_INVALIDATE_OSC HINTI_OSC_SHAPE_CHANGED

        ;// and finally, tell popup to do all this stuff

        mov eax, POPUP_REBUILD OR POPUP_SET_DIRTY OR POPUP_REDRAW_OBJECT
        jmp all_done

;////////////////////////////////////////////////////////////////////////////////////////////

;// user wants to remove item from list
remove_plugin:

    ;// to do this, we have to scan the desired registry
    ;// walk it's chain
    ;// close each item
    ;// then remove the registry entry
    ;// then delete the key

    ;// get the hwnd of the list box

        invoke GetDlgItem, popup_hWnd, IDC_PLUGIN_LIST
        mov ebx, eax

    ;// get cur sel and make sure it's valid
        
        LISTBOX ebx, LB_GETCURSEL
        or eax, eax
        js remove_done  ;// LB_ERR is -1

    ;// start calling delete string

        pushd 0         
        push eax
        pushd LB_DELETESTRING
        push ebx

    ;// get the item data

        LISTBOX ebx, LB_GETITEMDATA, eax    
        mov edi, eax
        ASSUME edi:PTR PLUGIN_REGISTRY

    ;// finish calling delete string
    
        call SendMessageA       

    ;// scan the registry chain and close all attached oscs

        ENTER_PLAY_SYNC GUI

        .WHILE [edi].pHeadOsc   

            invoke plugin_Close, [edi].pHeadOsc

            ;// do something about the name
            ;// perhaps reassign to head

        .ENDW

        LEAVE_PLAY_SYNC GUI

    ;// then we delete the registry key

        sub esp, 24 ;// room for disp, key and string

        ;// stack
        ;// disp key string
        ;// 00   04  08

        mov edx, esp
        lea ecx, [esp+4]

        invoke RegCreateKeyExA, HKEY_CURRENT_USER, OFFSET plugin_szRegKey,
            REG_OPTION_RESERVED, 0, REG_OPTION_NON_VOLATILE,
            KEY_SET_VALUE + KEY_CREATE_SUB_KEY + KEY_QUERY_VALUE,
            0, ecx, edx

        .IF !eax        ;// check for sucess

            pop eax     ;// get disposition
            ;// stack
            ;// key string
            ;// 00  04

            .IF eax == REG_OPENED_EXISTING_KEY 

                lea ecx, [esp+4]
                invoke wsprintfA, ecx, OFFSET plugin_szFmtName, [edi].checksum      
            
                lea ecx, [esp+4]
                mov edx, [esp]
                invoke RegDeleteValueA, edx, ecx

            .ENDIF

            call RegCloseKey

            add esp, 16

        .ELSE 
            
            add esp, 24

        .ENDIF

    ;// remove and deallocate the registry entry

        slist_Remove pluginR, edi

        invoke memory_Free, edi

    ;// then we jump to the verify scan

        push esi    ;// got's to save

        jmp plugin_verify_scan


    remove_done:    ;// nothing selected

        mov eax, POPUP_IGNORE
        jmp all_done
    


;////////////////////////////////////////////////////////////////////////////////////////////

;// user has adjusted one of the scroll bars on the kludge-o-matic panel
ALIGN 16
got_scroll_message:

    ;// by convention, ecx has the current position

        ;// determine where we are working with

        mov edi, eax                        ;// xfer command id to edi  
        mov edx, [esi].plug.pParameters     ;// point edx at our allocated parameter block
        sub edi, OSC_COMMAND_SCROLL         ;// turn edi into the parameter index

        mov ebx, [esi].plug.pAEffect        ;// ebx points at our effect
        ASSUME ebx:PTR vst_AEffect
        lea edx, [edx+edi*4]                ;// point edx at the correct parameter
        ASSUME edx:PTR DWORD

        mov [edx], ecx          ;// store scroll position in parameter
        fild [edx]              ;// load the position
        fmul plugin_ScrollScale ;// scale the position to a float
        fstp [edx]              ;// store the value in parameter block

        push [edx]  ;// push the VALUE
        push edi    ;// push the index of the value
        push ebx    ;// push the effect pointer
        
        ENTER_PLAY_SYNC GUI
        call [ebx].pSetParameter    ;// tell plugin to set the parameter (values already pushed)
        LEAVE_PLAY_SYNC GUI

        ;// add esp, 12 ;// C calling convention, we'll clean this up shortly
                        ;// but first we need more room for a text buffer
        sub esp, 52     ;// 52 more bytes to be exact, for a total of 64 bytes

    ;// since we're changing this, we want to update the display
    ;// edi already has the INDEX of the value we want

        mov edx, esp    ;// string pointer
        
        ;// get the displayable value
        ;// pDispatcher
        ;// effGetParamDisplay  equ 07
        ;// stuff parameter <index> textual representation into string
        invoke [ebx].pDispatcher, ebx, effGetParamDisplay, edi, 0, edx, 0

        ;// append the type to it
        mov ecx, esp
    J0: cmp BYTE PTR [ecx], 0
        je J1
        inc ecx
        jmp J0
    J1: mov BYTE PTR [ecx], ' '
        inc ecx
        invoke [ebx].pDispatcher, ebx, effGetParamLabel, edi, 0, ecx, 0

        
        ;// convert edi to the appropriate command id

        add edi, OSC_COMMAND_SCROLL + PLUGIN_SCROLL_TO_LABEL
        
        ;// and set the new text
        
        invoke GetDlgItem, popup_hWnd, edi
        WINDOW eax, WM_SETTEXT, 0,esp
        
    ;// now we clean up the stack and exit

        add esp, 64
        mov eax, POPUP_SET_DIRTY
        jmp all_done

;////////////////////////////////////////////////////////////////////////////////////////////

ALIGN 16
change_plugin:

    ;// call plugin close
    ;// free any extra memory
    ;// tell popup to rebuild

        ;// if we change a plugin, we should store the last_know_registry
        ;// in that way, we can highlight when the dialog starts

        mov eax, [esi].plug.pRegistry
        mov last_known_registry, eax

        ;// we need to detach the stated plugin

        invoke plugin_Detach, esi
        
        mov eax, POPUP_REBUILD OR POPUP_SET_DIRTY OR POPUP_REDRAW_OBJECT

        jmp all_done


;////////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////////

ALIGN 16
popup_is_deactivating:  

    cmp editor_hWnd_Cage, 0
    mov eax, POPUP_CLOSE
    je all_done
    invoke editor_Deactivating
    .IF eax == POPUP_CLOSE
        mov last_known_registry, 0
    .ENDIF
    jmp all_done



ALIGN 16
popup_is_activating:

    cmp editor_hWnd_Cage, 0
    mov eax, POPUP_IGNORE
    je all_done
    invoke editor_Activating
    jmp all_done

ALIGN 16
popup_windowposchanging:

    cmp editor_hWnd_Cage, 0
    je all_done 
    invoke editor_WindowPosChanging 
    jmp all_done

;////////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////////

;// exit point for all branches

ALIGN 16        
all_done:       

    ret

osc_Plugin_Command ENDP






;////////////////////////////////////////////////////////////////////
;//
;//
;//     _SaveUndo
;//

ASSUME_AND_ALIGN
plugin_SaveUndo PROC

        ASSUME esi:PTR PLUGIN_OSC_MAP

    ;// edx enters as either UNREDO_CONTROL_OSC or UNREDO_COMMAND
    ;// edi enters as where to store
    ;//
    ;// task:   1) save nessary data
    ;//         2) iterate edi
    ;//
    ;// may use all registers except ebp

        mov eax, [esi].dwUser           ;// load dwUser
        stosd                           ;// store dwUser

        mov ebx, [esi].plug.numParameters       ;// get for later
        mov ecx, PLUGIN_MINIMUM_SAVE                ;// load min size to save
        lea esi, [esi].plug.PLUGIN_SAVE_START   ;// get start of savable data

        rep movsd                       ;// dump it all

        .IF ebx                         ;// check if there's more from the plugin
            mov ecx, ebx                ;// xfer the count
            mov esi, DWORD PTR [esi]    ;// get pointer to allocated
            DEBUG_IF <!!esi>            ;// pParameters not allocated, not sposed to happen
            rep movsd                   ;// dump it
        .ENDIF

    ;// simple as that

        ret

plugin_SaveUndo ENDP
;//
;//
;//     _SaveUndo
;//
;////////////////////////////////////////////////////////////////////

;////////////////////////////////////////////////////////////////////
;//
;//
;//     _LoadUndo
;//

ASSUME_AND_ALIGN
plugin_LoadUndo PROC

        ASSUME esi:PTR OSC_OBJECT   ;// preserve
        ASSUME ebp:PTR LIST_CONTEXT ;// preserve

    ;// edx enters as either UNREDO_CONTROL_OSC or UNREDO_COMMAND
    ;// edi enters as where to load
    ;//
    ;// task:   1) load nessary data
    ;//         2) do what it takes to initialize it
    ;//
    ;// may use all registers except ebp and esi
    ;// return will invalidate HINTI_OSC_UPDATE

        ;// if new data is a null device, and old data is a device
        ;// we have to detach it (plugin_Close)
        ;// we also have to release the parameters memory

        ;// if new data is a device, and old data is a null device
        ;// we have to attach it (plugin_Attach)

    push esi

        mov eax, [edi]  ;// get dwUser
        mov ebx, esi
        ASSUME ebx:PTR PLUGIN_OSC_MAP
        lea esi, [edi+4]        ;// esi is now the next undo item
        ASSUME esi:PTR DWORD

        .IF eax     ;// new data has a plugin number

            .IF [ebx].dwUser    ;// and so does the osc

                .IF eax != [ebx].dwUser

                    push eax
                    invoke plugin_Detach, ebx
                    pop eax
                    jmp attach_new_plugin

                .ENDIF

                ;// so all we're doing is loading parameters
                ;// DEBUG_IF < eax !!= [ebx].dwUser >   ;// supposed to be the same !!

                call read_parameters
                call write_parameters

            .ELSE   ;// osc does not have a plugin assigned

            ;// we need to attach the stated plugin
            
            attach_new_plugin:

                mov [ebx].dwUser, eax

                invoke plugin_Match, ebx
                .IF eax

                    or [ebx].dwHintI, HINTI_OSC_SHAPE_CHANGED
                    call read_parameters        ;// read the undo settings
                    invoke plugin_Open, ebx, 0  ;// ebx is destroyed

                .ENDIF

            .ENDIF

        ;// new data does NOT have a plugin
        .ELSEIF [ebx].dwUser    ;// but the old data does have a plugin number

            ;// we need to detach the stated plugin

            invoke plugin_Detach, ebx
                            
            ;// and the old data doesn't have a plugin either
            ;// so we don't need to do anything
            ;// int 3
            ;// this where we have to process list commands !!!

        .ENDIF

    ;// clean up and split

        pop esi
        
        ret



;// local functions

ALIGN 16
read_parameters:

    ;// this loads the undo parameters to the osc
    ;// it will reallocate osc.plug.pParameters
    ;// destroyes edi and esi
    
        ASSUME ebx:PTR PLUGIN_OSC_MAP
        ASSUME esi:PTR DWORD    ;// points at undo data
        ASSUME edi:PTR DWORD    ;// destroyed
                    
        .IF [ebx].plug.pParameters
            invoke memory_Free, [ebx].plug.pParameters
            mov [ebx].plug.pParameters, eax
        .ENDIF

        mov edx, [esi+8]    ;// get num parameters
        lea edi, [ebx].plug.PLUGIN_SAVE_START
        mov ecx, PLUGIN_MINIMUM_SAVE
        rep movsd   
        ;// esi and edi are now at pParameters
        .IF edx
                                
            push edx
            lea ecx, [edx*4]    
            invoke memory_Alloc, GPTR, ecx
            mov [ebx].plug.pParameters, eax
            mov edi, eax
            pop ecx
            rep movsd

        .ENDIF
            
        retn

ALIGN 16
write_parameters:

        ;// this transfers the osc parameters to the plugin
        ;// destroys esi, edi, ebx

        mov esi, [ebx].plug.numParameters;// esi counts them
        .IF esi
            
            mov edi, [ebx].plug.pParameters ;// edi points at the parameter block
            DEBUG_IF <!!edi>    ;// pParameters hasn't been allocated !!
            mov ebx, [ebx].plug.pAEffect
            ASSUME ebx:PTR vst_AEffect
            DEBUG_IF <!!ebx>    ;// there is no pAEffect !!

            .REPEAT

                dec esi
                invoke [ebx].pSetParameter, ebx, esi, DWORD PTR [edi+esi*4]

            .UNTIL !esi

        .ENDIF

        retn

plugin_LoadUndo ENDP

;//
;//
;//     _LoadUndo
;//
;////////////////////////////////////////////////////////////////////









;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////
;////                       
;////                       
;////   vst_AMCallback      plugins will call this to get information
;////
ASSUME_AND_ALIGN
plugin_AMCallback PROC C pAEffect:DWORD, dwOpcode:DWORD, dwIndex:DWORD, dwValue:DWORD, dwPtr:DWORD, dwOption:DWORD

        mov ecx, dwOpcode

;// MESSAGE_LOG_PRINT_1 <plugin_AMCallback_> , ecx, <"plugin_AMCallback_ %8.8X">

        .IF     ecx ==  audioMasterAutomate ;// index, value, returns 0

            ;// the correct way to do this is to make plugin_calc
            ;// set the parameters all the time
            ;// a very expensive proposition
            
            ENTER_PLAY_SYNC GUI
            mov ecx, pAEffect
            ASSUME ecx:PTR vst_AEffect
            invoke [ecx].pSetParameter, ecx, dwIndex, dwOption
            LEAVE_PLAY_SYNC GUI
            xor eax, eax

        .ELSEIF ecx == audioMasterVersion   ;// vst version, currently 2 (0 for older)

            mov eax, 2      ;// may have problems with this

        .ELSEIF ecx == audioMasterWantMidi

            ;// this plugin wants midi events

            mov eax, 1

            comment ~ /*
            don't care !!
                ;// now we have to set receive_on in the object
                ;// to do this we have to search ??
                ;// nope: we set resvd1 as the object pointer

                mov edx, pAEffect
                ASSUME edx:PTR vst_AEffect
                mov edx, [edx].resvd1
                ASSUME edx: PTR PLUGIN_OSC_MAP
                .IF edx ;// make sure it exists
                    mov [edx].plug.receive_on, 1
                .ENDIF
            */ comment ~


        .ELSEIF ecx == audioMasterProcessEvents ;// EQU 8

            ;// ABOX233 
            comment ~ /*

                this is called inside osc_Plugin_Calc during ProcessReplacing
                pAEffect points at the vst block                
                dwPtr is &VstMidiEvents

                we should return 1


            1) locate the osc object by scanning plugin R for pAEffect ... clumsy
            2) copy stamps and events, advancing read write pointers appropriately
            3) .... that should do it

            */ comment ~

                mov eax, pAEffect   ;// what we search for
                xor ecx, ecx        ;// iterates the plugin registry
                xor edx, edx        ;// scans osc objects in a registry entry
                slist_OrGetHead pluginR, ecx    ;// start scanning the registry
                jz all_done         ;// abort now if empty
                .REPEAT
                    or edx, [ecx].pHeadOsc      ;// get and test the head of this entry
                    ASSUME edx:PTR PLUGIN_OSC_MAP
                    .IF !ZERO?          
                    .REPEAT         ;// scanning oscs attached to a registry pile
                        CMPJMP eax, [edx].plug.pAEffect, je located_the_object
                        mov edx, [edx].plug.pNextOsc    ;// next osc in pile
                    .UNTIL !edx
                    .ENDIF
                    slist_GetNext pluginR, ecx
                .UNTIL !ecx
                ;// if we hit this, the object was not found
                ;// so we return now with a fail
                jmp all_done

            located_the_object:
        
            ;// edx = OSC_PLUGIN

                ;// modified from midiin_Proc

                lea ecx, [edx].que_portstream   ;// get the device block
                ASSUME ecx:PTR MIDI_QUE_PORTSTREAM

                push ebx
                push edi
                push esi

                mov ebx, dwPtr                  ;// get VstEvents header from caller
                ASSUME ebx:PTR VstMidiEvents    ;// event iterator
                xor edi, edi                    ;// counter
            
                .WHILE edi < [ebx].numEvents    ;// counting through the struct

                    mov esi, DWORD PTR [ebx+edi*4+SIZEOF VstMidiEvents]
                    ASSUME esi: PTR VstMidiEvent

                    ;// last write += 1 then AND to make circular
                    mov edx, [ecx].last_write   ;// get last_write                  
                    lea eax, [edx+1]            ;// advance last write 1
                    and eax, MIDIIN_QUE_LENGTH-1;// make last_write circular
                    mov [ecx].last_write, eax   ;// store the new last_write index

                    lea edx, [ecx+edx*8].que    ;// point edx at the que
                    ASSUME edx:PTR MIDIIN_QUE   

                    ;// time stamp = (frame_counter*frame_size+deltaFrame)/2

                    mov eax, [esi].deltaFrames  ;// add time stamp: reletive to CURRENT FRAME !!
                    shr eax, 1                  ;// convert stamp to stream index (0-512)
                    mov [edx].stamp, eax        ;// store the slot index

                    ;// prepare the midi data

                    mov eax, [esi].midiData     ;// get midi event
                    bswap eax                   ;// reverse the sequence
                    shr eax, 8                  ;// scoot event into place
                    or eax, MIDI_FLOAT_BIAS     ;// merge on the float bias
                    mov [edx].event, eax        ;// store the event

                    ;// next event

                    inc edi ;// next event
                .ENDW

                pop esi
                pop edi
                pop ebx

            mov eax, 1


        .ELSEIF ecx == audioMasterGetTime   ;// EQU 7   ;// returns const VstTimeInfo* (or 0 if not supported)
                                        ;// <value> should contain a mask indicating which fields are required
                                        ;// (see valid masks above), as some items may require extensive
                                        ;// conversions

            fild QWORD PTR play_sample_position
            mov eax, OFFSET plugin_time_info    ;// return pointer
            fstp QWORD PTR [eax]                ;// plugin_time_info.r8SamplePos
                
        .ELSEIF ecx == audioMasterIOChanged ;// numInputs and/or numOutputs has changed

            xor eax, eax
            DEBUG_MESSAGE <plugin_AMCallback__audioMasterIOChanged>

            
            comment ~ /*
            bool AudioEffectX::ioChanged ()
            {
                if (audioMaster)
                    return (audioMaster (&cEffect, audioMasterIOChanged, 0, 0, 0, 0) != 0);
                return false;
            }
            */ comment ~


        .ELSEIF ecx == audioMasterSizeWindow    ;// dwIndex = width, dwValue = height

            ;// ABOX233 allow plugs to resize their windows
            
            comment ~ /*
            DEBUG_MESSAGE <plugin_AMCallback_audioMasterSizeWindow>
            mov eax, dwIndex
            DEBUG_MESSAGE_REG eax
            mov edx, dwValue
            DEBUG_MESSAGE_REG edx
            */ comment ~

            GET_OSC_FROM ecx, popup_Object          
            TESTJMP ecx, ecx, jz S0         ;// popup_Object must exist
            OSC_TO_BASE ecx, edx
            CMPJMP edx, OFFSET osc_Plugin, jne S0   ;// and it must be a plugin
            ASSUME ecx:PTR PLUGIN_OSC_MAP
            mov edx, [ecx].plug.pAEffect    
            CMPJMP edx, pAEffect, jne S0        ;// and it must be the same plugin ... 
            CMPJMP editor_hWnd_Cage, 0, je S0   ;// and we must have a cage
            CMPJMP editor_hWnd_Animal, 0, je S0 ;// and an animal inside it
            
                ;// determine how much the size is to change
                ;// then use MoveWindow
                ;//... problem: when the menu wraps, we don't get the size correct ...
                ;// so we limit the size ...
                pushd 1                 ;// MoveWindow.arg repaint
                sub esp, SIZEOF RECT
                invoke GetClientRect, popup_hWnd, esp
                mov eax, [esp+08h]      ;// client x
                mov edx, [esp+0Ch]      ;// client y
                sub dwIndex, eax        ;// now is dx 
                sub dwValue, edx        ;// now is dy
                invoke GetWindowRect, popup_hWnd, esp
                mov eax, [esp]          ;// left
                mov edx, [esp+04h]      ;// T
                sub eax, dwIndex        ;// L-dx
                sub edx, dwValue        ;// T-dy
                sub [esp+08h], eax      ;// width   R -= L-dx
                sub [esp+0Ch], edx      ;// heigt   B -= R-dy                   
                .IF DWORD PTR [esp+8] < 196
                    mov DWORD PTR [esp+8], 196
                .ENDIF
                pushd popup_hWnd
                call MoveWindow

            ;// now if we have an editor hWnd ...

                pushd 1
                sub esp, SIZEOF RECT
                invoke GetClientRect, popup_hWnd, esp
                push editor_hWnd_Cage
                call MoveWindow

                pushd 1
                sub esp, SIZEOF RECT
                invoke GetClientRect, popup_hWnd, esp
                push editor_hWnd_Animal
                call MoveWindow

            ;// eax has correct return value ?

            S0:
                    
        .ELSEIF ecx == audioMasterGetSampleRate     ;// EQU 10h 

            ;// ABOX233

            ;//     effSetSampleRate,   // in opt (float)
            mov ecx, pAEffect
            ASSUME ecx:PTR vst_AEffect
            invoke [ecx].pDispatcher, 
                    ecx,    ;//pAEffect:DWORD, 
                    effSetSampleRate,
                    0,  ;// dwIndex:DWORD, 
                    0,  ;// dwValue:DWORD, 
                    0,  ;// dwPtr:DWORD, 
                    math_44100;//SampleRate ;// fOpt:REAL4

            xor eax, eax
            
        .ELSEIF ecx == audioMasterGetBlockSize  ;// EQU 11h

            ;// ABOX233

            ;//     effSetBlockSize,    // in value
            mov ecx, pAEffect
            ASSUME ecx:PTR vst_AEffect
            invoke [ecx].pDispatcher, 
                    ecx,    ;//pAEffect:DWORD, 
                    effSetBlockSize,
                    0,  ;// dwIndex:DWORD, 
                    SAMARY_LENGTH,  ;// dwValue:DWORD, 
                    0,  ;// dwPtr:DWORD, 
                    0   ;// fOpt:REAL4

            xor eax, eax

        .ELSE       ;// unhandled opcode
                        
            DEBUG_MESSAGE <plugin_AMCallback_UNHANDLED>
            DEBUG_MESSAGE_REG ecx

            ;// assume we return zero
        all_done:           

            xor eax, eax

        .ENDIF


        ret

plugin_AMCallback ENDP
;////                       
;////                       
;////   vst_AMCallback      plugins will call this to get information
;////
;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////





;////////////////////////////////////////////////////////////////////////////////////////
ASSUME_AND_ALIGN
osc_Plugin_PrePlay PROC

    ;// make sure we've initialized the plugin

    ASSUME esi:PTR PLUGIN_OSC_MAP
    
    .IF [esi].dwUser        
        ;// OSC_TO_DATA esi, ebx, OSC_PLUGIN
        .IF [esi].plug.pRegistry
            mov ebx, [esi].plug.pAEffect
            ASSUME ebx:PTR vst_AEffect
            .IF ebx
                ;// toggle the mains and hope plugin knows what to do
                ;// NOTE: this is the same as suspend and resume
                                
                invoke [ebx].pDispatcher, ebx, effStopProcess, 0, 0, 0, 0
                invoke [ebx].pDispatcher, ebx, effMainsChanged, 0, 0, 0, 0  ;// suspend

                invoke [ebx].pDispatcher, ebx, effMainsChanged, 0, 1, 0, 0  ;// resume
                invoke [ebx].pDispatcher, ebx, effStartProcess, 0, 0, 0, 0

                .IF [esi].plug.can_send
                    xor eax, eax
                    mov [esi].que_portstream.last_write, eax
                    mov [esi].que_portstream.last_read, eax
                    mov [esi].que_portstream.frame_counter, eax
                    mov [esi].que_portstream.portstream_ready, eax
                    mov [esi].que_portstream.empty_frame, eax
                .ENDIF
            .ENDIF
        .ENDIF
    .ENDIF

    xor eax, eax    ;// tell play to erase our data

    ret

osc_Plugin_PrePlay ENDP
;////////////////////////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////////////////////////
ASSUME_AND_ALIGN
osc_Plugin_Calc PROC

    ASSUME esi:PTR PLUGIN_OSC_MAP

    ;// make sure we're good to go
    xor ebx, ebx                        ;// clear for testing

    CMPJMP [esi].dwUser, ebx, je all_done           ;// are we assigned ?

    CMPJMP [esi].plug.pRegistry, ebx, je all_done   ;// are we registered ??

    xor edi, edi                        ;// clear for future test

    ORJMP ebx, [esi].plug.pAEffect, jz all_done ;// do we have an effect ?

    xor eax, eax                        ;// clear for future test

    ORJMP edi, [esi].pin_off.pPin, jz ready_to_go   ;// check if 'off' is connected
                                          
    mov edi, (APIN PTR [edi]).pData     ;// get the source data pointer
    
    ;// load and test first value
    ORJMP eax, DWORD PTR [edi], jns ready_to_go ;// if neg, then we are supposed to ignore

plugin_is_off:

    ;// have to nul and reset all connected outputs
    xor edx, edx
    lea ebx, [esi].pin_out_1        ;// ebx will walk pins
    ASSUME ebx:PTR APIN
    xor eax, eax
    or edx, [esi].plug.numOutputs   ;// edx will count them

    .WHILE !ZERO?
        .IF [ebx].pPin              ;// connected ?
            mov edi, [ebx].pData    ;// get the data pointer
            btr [ebx].dwStatus, LOG_PIN_CHANGING;// changing ?
            jc have_to_zero         ;// yep, have to zero
            cmp eax, DWORD PTR [edi];// nope, zero already ?
            je dont_have_to_zero    ;// jump if already zero
        have_to_zero:
            mov ecx, SAMARY_LENGTH  ;// load the length
            rep stosd               ;// clear it
        dont_have_to_zero:

        .ENDIF

        add ebx, SIZEOF APIN
        dec edx     

    .ENDW

    jmp all_done


ALIGN 16
ready_to_go:    ;// we are rarin' to go

;// we'll need a stack frame and to use ebp 
;// so we preserve ebp here (stack frame is set shortly)

    push ebp    
 
;// MIDI INTO PLUGIN

    .IF [esi].plug.can_receive == 1

    ;// ABOX_STREAM_TO_VST_STREAM source, dest      

        ;// this is quite simple
        ;// we walk the object input stream and plugin_input_stream.event
        ;// we build events as required

        ;// to do this, we'll need a few registers

        mov ebx, [esi].pin_si.pPin
        .IF ebx

            mov ebx, [ebx].pData    
            ASSUME ebx:PTR MIDI_STREAM_ARRAY    ;// ebx is input stream

            mov ebp, plugin_input_stream                        
            ASSUME ebp:PTR PLUGIN_INPUT_STREAM

            xor ecx, ecx

            lea edi, [ebp].event            
            ASSUME edi:PTR VstMidiEvent

            mov [ebp].numEvents, ecx
            
            midistream_IterBegin [ebx], ecx, done_with_input_stream

        top_of_input_stream:

            mov eax, [ebx+ecx*8].evt    ;// get the event
            mov edx, ecx                ;// get the stream index
            bswap eax                   ;// rearrange event
            shl edx, 1                  ;// convert stream index to sample index
            shr eax, 8                  ;// shift event in to place
            mov [edi].deltaFrames, edx  ;// store sample index
            mov [edi].midiData, eax     ;// store the event
            inc [ebp].numEvents         ;// increase num events

            add edi, SIZEOF VstMidiEvent    ;// next event

            midistream_IterNext [ebx], ecx, top_of_input_stream

        done_with_input_stream:

            .IF [ebp].numEvents ;// make sure we got events
                
                mov ebx, [esi].plug.pAEffect    ;// get the effect ptr
                ASSUME ebx:PTR vst_AEffect

                ;//     effProcessEvents,   (ptr = events)
                invoke [ebx].pDispatcher, 
                        ebx,    ;//pAEffect:DWORD, 
                        effProcessEvents,
                        0,      ;// dwIndex:DWORD, 
                        0,      ;// dwValue:DWORD, 
                        ebp,    ;// dwPtr:DWORD, 
                        0       ;// fOpt:REAL4

            .ENDIF  ;// had events in stream

        .ENDIF  ;// input pin connected

    .ENDIF  ;// plugin wants events

;// MIDI FROM PLUGIN PREPARE

    ;// nothing really to do ??
    comment ~ /*
    .IF [esi].plug.can_send
        midistream_Reset [esi].que_portstream, ecx ;// clear the destination stream
    .ENDIF
    */ comment ~

;// AUDIO IN to and OUT of PLUGIN

    ;// plugins need to be passed pointers to parameter blocks
    ;// to do this we enter the function here

    mov ebp, esp

        ASSUME ecx:PTR APIN ;// pre assume to save some typing

    ;// input side

        mov ecx, [esi].plug.numInputs   
        shl ecx, APIN_SHIFT
        .IF !ZERO?  ;// JIC
            lea ecx, (PLUGIN_OSC_MAP PTR [esi+ecx-(SIZEOF APIN)]).pin_in_1
            xor eax, eax
            .REPEAT
                or eax, [ecx].pPin  ;// check if connected
                .IF !ZERO?
                    push (APIN PTR [eax]).pData ;// is connected, use that pin's data
                    xor eax, eax                ;// clear eax for next test
                .ELSE
                    push math_pNull     ;// not connected, use null data
                .ENDIF
                sub ecx, SIZEOF APIN    ;// iterate backwards
            .UNTIL ecx <= esi
        .ENDIF

        mov edx, esp    ;// store the ppInput value
                
    ;// output side

        mov ecx, [esi].plug.numOutputs
        mov eax, ecx
        shl ecx, SAMARY_SHIFT
        .IF !ZERO?  ;// JIC     
            lea ecx, (PLUGIN_OSC_MAP PTR [esi+ecx-SAMARY_SIZE]).data_1
            .REPEAT
                push ecx
                sub ecx, SAMARY_SIZE
                dec eax
            .UNTIL ZERO?
        .ENDIF

    ;// esp points at ppOut

        mov ebx, [esi].plug.pAEffect    ;// get the effect ptr
        ASSUME ebx:PTR vst_AEffect

    ;// see what plugin can do

        .IF [ebx].flags & effFlagsCanReplacing  ;// plug will overwrite the data
        
            ;// now we call the plugin

            mov eax, esp
            invoke [ebx].pProcessReplacing, ebx, edx, eax, SAMARY_LENGTH            

        .ELSE           ;// have to zero the output data
            
            .IF edx!=esp    ;// skip if no output pins
                
                mov ecx, [esi].plug.numOutputs  ;// get num outputs
                lea edi, [esi].data_1               ;// start of where to clear
                shl ecx, SAMARY_SHIFT - 2           ;// = size of data to clear
                xor eax, eax                        ;// what to clear with
                
                rep stosd   ;// clear the values
                
            .ENDIF  

            ;// now we call the plugin

            mov eax, esp
            invoke [ebx].pProcess, ebx, edx, eax, SAMARY_LENGTH

        .ENDIF
            
    ;// now we go through a see what's changing             
    ;// this is somewhat expensive when the signal is not changing

        mov edx, [esi].plug.numOutputs  ;// get the count
        lea ebx, [esi].pin_out_1            ;// point at first output pin
        ASSUME ebx:PTR APIN

        .WHILE edx

            .IF [ebx].pPin  ;// check if connected
            
                mov edi, [ebx].pData        ;// get the data pointer
                mov ecx, SAMARY_LENGTH      ;// load the scan length
                mov eax, DWORD PTR [edi]    ;// get the first value
                repe scasd              ;// check for changing values
                .IF ecx             ;// find any ?
                    or [ebx].dwStatus, PIN_CHANGING
                .ELSE
                    and [ebx].dwStatus, NOT PIN_CHANGING
                .ENDIF
            .ENDIF
        
            dec edx                 ;// decrease num pins
            add ebx, SIZEOF APIN    ;// advance the pin pointer

        .ENDW

    ;// exit this part of the code

        mov esp, ebp    ;// retrieve stack pointer
        pop ebp         ;// retrieve ebp

;// MIDI FROM PLUGIN PROCESS

    .IF [esi].plug.can_send

        lea edx, [esi].que_portstream.portstream
        lea ebx, [esi].que_portstream
        mov [esi].pin_so.pData, edx
        invoke midi_que_to_portstream
        inc [esi].que_portstream.frame_counter

    .ENDIF

;// that should do it
all_done:

    ret


osc_Plugin_Calc ENDP
;////////////////////////////////////////////////////////////////////////////////////////












ASSUME_AND_ALIGN


ENDIF   ;// USE_THIS_FILE
END

