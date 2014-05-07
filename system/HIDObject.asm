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
;//     ABOX242 AJT -- changed function import declarations for newer version of masm and link
;//         now uses NOIMPORT and we define function table staightforth
;//
;//##////////////////////////////////////////////////////////////////////////
;//
;//     HIDObject.asm       based loosely on the HIDMask project
;//                         containers for HIDDEVICE and HIDCONTROL

OPTION CASEMAP:NONE
.586
.MODEL FLAT

;// TOC

;// private
;//
;//     hiddevice_insert_this_control PROC
;//     hidcontrol_create_this_node PROC
;//     hidcontrol_Dtor PROC STDCALL pDevice:DWORD pControl:DWORD
;//     hiddevice_init_from_string  PROC STDCALL pHIDDEVICE:DWORD, pszString:DWORD
;//     hiddevice_try_init_from_registry PROC
;//     hiddevice_try_to_init_from_capabilities PROC
;//     hiddevice_Ctor PROC STDCALL pszHidDeviceName:DWORD
;//     hiddevice_build_formats PROC    ;// PRIVATE to this file
;//     hiddevice_convert_data PROC ;// PRIVATE to this file
;//
;// public
;//
;//     hidobject_Initialize PROC STDCALL
;//     hidobject_Destroy PROC STDCALL
;//     hiddevice_Open PROC STDCALL pDevice:DWORD
;//     hiddevice_Close PROC STDCALL pDevice:DWORD
;//     hiddevice_BuildFormats PROC STDCALL, pDevice:DWORD
;//     hiddevice_CountReports PROC STDCALL, pDevice:DWORD
;//     hiddevice_ReadNextReport PROC STDCALL, pDevice:DWORD
;//     hidobject_EnumDevices   PROC STDCALL pObject:DWORD, pDevice:DWORD
;//     hiddevice_EnumControls  PROC STDCALL pDevice:DWORD, pControl:DWORD


        .NOLIST

            INCLUDE HIDObject.inc

        ;//.LISTALL
        .LIST

;/////////////////////////////////////////////////////////
;//
;//
;//     build settings      these should be OFF

;// DO_NOT_FREE_REPORT_MEMORY   EQU 1   ;// looking for open/close bugs
;// VERIFY_THE_REPORT_COUNT     EQU 1   ;// double check, verify that buffers are returned in order
;// DISPLAY_THE_BUFFER_STATUS   EQU 1   ;// OutputDebugString of wheather a buffer is ready or not

;//////////////////////////////
;//                         ;//
;//                         ;//
                            ;//
        PROLOGUE_OFF        ;// !!! IMPORTANT !!!
                            ;//
;//                         ;//
;//                         ;//
;//////////////////////////////


.DATA


    hidobject_initialize_status dd  0   ;// 0 = not called yet
                                ;// 1 = already ctored sucessfully
                                ;//-1 = could not load libraries
                                ;//-2 = could load libs, but could not enumerate

    dlist_Declare   hiddevice   ;// our hid device list


;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;///
;///
;///    IMPORT LIBRARY

    ;// ABOX242 AJT -- now using the NOIMPORT version for newer masm,link (see win32A_imp.inc)

    ;// we use manual import loading
    ;// this makes it possible to use this module on a HIDless system

    ;// the function table is organized as:
    ;//
    ;//     function_table  := module_block+ 0
    ;//     module_block    := lib_name function_name+ 0
    ;//     lib_name        := zero terminated character string
    ;//     function_name   := zero terminated character string
    ;//
    ;//     the function name pointers are replaced by the addresses of the functions
    

    hid_function_table  LABEL DWORD

        dd  lib_name_1
        _imp__SetupDiGetClassDevsA              dd __sz__SetupDiGetClassDevsA
        _imp__SetupDiDestroyDeviceInfoList      dd __sz__SetupDiDestroyDeviceInfoList
        _imp__SetupDiEnumDeviceInterfaces       dd __sz__SetupDiEnumDeviceInterfaces
        _imp__SetupDiGetDeviceInterfaceDetailA  dd __sz__SetupDiGetDeviceInterfaceDetailA
        dd 0
        dd lib_name_2
        _imp__HidD_GetHidGuid                   dd __sz__HidD_GetHidGuid
        _imp__HidD_GetPreparsedData             dd __sz__HidD_GetPreparsedData
        _imp__HidD_FreePreparsedData            dd __sz__HidD_FreePreparsedData
        _imp__HidD_GetAttributes                dd __sz__HidD_GetAttributes
        _imp__HidD_GetProductString             dd __sz__HidD_GetProductString
        _imp__HidP_GetCaps                      dd __sz__HidP_GetCaps
        _imp__HidP_GetButtonCaps                dd __sz__HidP_GetButtonCaps
        _imp__HidP_GetValueCaps                 dd __sz__HidP_GetValueCaps
        dd 0,0

    ;// strings

        lib_name_1   db  'SETUPAPI.DLL',0
        __sz__SetupDiGetClassDevsA              db 'SetupDiGetClassDevsA',0
        __sz__SetupDiDestroyDeviceInfoList      db 'SetupDiDestroyDeviceInfoList',0
        __sz__SetupDiEnumDeviceInterfaces       db 'SetupDiEnumDeviceInterfaces',0
        __sz__SetupDiGetDeviceInterfaceDetailA  db 'SetupDiGetDeviceInterfaceDetailA',0
        lib_name_2   db  'HID.DLL',0
        __sz__HidD_GetHidGuid                   db 'HidD_GetHidGuid',0
        __sz__HidD_GetPreparsedData             db 'HidD_GetPreparsedData',0
        __sz__HidD_FreePreparsedData            db 'HidD_FreePreparsedData',0
        __sz__HidD_GetAttributes                db 'HidD_GetAttributes',0
        __sz__HidD_GetProductString             db 'HidD_GetProductString',0
        __sz__HidP_GetCaps                      db 'HidP_GetCaps',0
        __sz__HidP_GetButtonCaps                db 'HidP_GetButtonCaps',0
        __sz__HidP_GetValueCaps                 db 'HidP_GetValueCaps',0
        ALIGN 4

;///    IMPORT LIBRARY
;///
;///
;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////






.CODE

ASSUME_AND_ALIGN    ;// PROLOGUE IS OFF !!
hiddevice_insert_this_control PROC

        ASSUME ebp:PTR HIDDEVICE    ;// passed by caller, preserve
        ASSUME esi:PTR HIDCONTROL   ;// passed by caller, preserve

    ;// return eax as zero for error


    ;// check the values in the node

        mov edx, [esi].W1
        mov eax, [esi].W0

        mov ecx, edx
        sub ecx, eax
        CMPJMP ecx, HIDCONTROL_MAX_BITS, jae return_fail    ;// reversed or container too big

        mov ecx, [ebp].dwInputReportSize
        shl ecx, 3
        CMPJMP eax, ecx, jae return_fail        ;// invalid bit index
        CMPJMP edx, ecx, jae return_fail        ;// invalid bit index

    ;// locate where to store this

        dlist_GetHead hidcontrol, ecx, ebp
        TESTJMP ecx, ecx, jz insert_tail

    top_of_search:

        CMPJMP edx, [ecx].W0, jb insert_before  ;// the list is in order
        CMPJMP eax, [ecx].W1, jbe return_fail   ;// overlapping not allowed
        dlist_GetNext hidcontrol, ecx
        TESTJMP ecx, ecx, jnz top_of_search

    insert_tail:

        dlist_InsertTail hidcontrol, esi,,ebp
        jmp insert_done

    insert_before:

        dlist_InsertBefore hidcontrol, esi, ecx,, ebp

    insert_done:

        or [ebp].dwFlags, HIDDEVICE_FORMAT_CHANGED
        mov eax, 1

    all_done:

        retn

    ALIGN 4
    return_fail:

        xor eax, eax
        jmp all_done

hiddevice_insert_this_control ENDP


ASSUME_AND_ALIGN    ;// PROLOGUE IS OFF !!
hidcontrol_create_this_node PROC

    ;// creates a 1 bit node and inserts into container
    ;// copies the LE BE from main container

    ;// be sure to check esi for zero

    ASSUME ebp:PTR HIDDEVICE
    ;// ecx MUST BE THE BIT VALUE to insert
    ;// destroys esi, eax, edx, ecx
    ;// returns esi as the new node or zero for error

    ;// allocate a node

        push ecx                ;// save
        invoke GLOBALALLOC, GPTR, SIZEOF HIDCONTROL
        pop ecx                 ;// retrieve
        mov esi, eax
        ASSUME esi:PTR HIDCONTROL ;// esi is now the control
        mov [esi].W0, ecx       ;// store first bit
        mov [esi].W1, ecx       ;// store last_bit

    ;// call the inserter

        invoke hiddevice_insert_this_control

    ;// if fail, delete the node

        .IF !eax
            invoke GLOBALFREE, esi
            xor esi, esi
        .ENDIF

    all_done:

        retn

hidcontrol_create_this_node ENDP

ASSUME_AND_ALIGN    ;// PROLOGUE IS OFF !!
hidcontrol_Dtor PROC STDCALL pDevice:DWORD, pControl:DWORD

        xchg ebp, [esp+4]
        ASSUME ebp:PTR HIDDEVICE
        xchg ebx, [esp+8]
        ASSUME ebx:PTR HIDCONTROL

        dlist_Remove hidcontrol,ebx,,ebp
        invoke GLOBALFREE, ebx

        mov ebp, [esp+4]
        mov ebx, [esp+8]

        retn 8  ;// STDCALL 2 ARGS

hidcontrol_Dtor ENDP




ASSUME_AND_ALIGN    ;// PROLOGUE IS OFF !!
hiddevice_init_from_string  PROC STDCALL pHIDDEVICE:DWORD, pszString:DWORD

    ;// task: initialize the HIDDEVICE by parsing the passed string
    ;// return eax = 1 for sucess, 0 for fail

        push ebp
        push edi
        push esi
        push ebx

    ;// stack   ebx esi edi ebp ret phid pstring
    ;//         00  04  08  0C  10  14   18

        mov ebp, [esp+14h]
        ASSUME ebp:PTR HIDDEVICE
        mov edi, [esp+18h]
        ASSUME edi:PTR BYTE

    ;// make sure passed parameters are OK

        xor eax, eax
        TESTJMP ebp, ebp, jz all_done       ;// must have a pointer
        TESTJMP edi, edi, jz all_done       ;// must have a string
        mov eax, dlist_Head( hidcontrol, ebp)
        TESTJMP eax, eax, jz all_done       ;// must have the first node
        SUBJMP eax, dlist_Tail(hidcontrol, ebp), jne all_done   ;// must not already be initialized

    comment ~ /*

    now we do a sort of drop down descent parser

    we want to be able to override settings as well as define where the bits are
    thus we may want to specify the long name, and page:usage
    so we have a device line and lines for each control

        start   := ( device (EOL control)* )? EOS

        device  := Page:Usage WHT Endian WHT LongName
        control := Page:Usage(.Instance)? WHT FirstBit-LastBit WHT Sign WHT (ShortName WHT)? LongName

        Page        := HEX
        Usage       := HEX
        Instance    := HEX
        Endian      := [L|B]
        FirstBit    := HEX
        LastBit     := HEX
        Sign        := [U|S]
        ShortName   := 'CHAR (CHAR)?'
        LongName    := (CHAR|WHT)+  <-- ambiguous

        CHAR        := [21h-7Eh]    <-- ambiguous and context sensitive
        HEX         := [0-9A-F]+    <-- always assumed hex and must be capitalized
        WHT         := (20h|09h)+   <-- consume consecutive wht space
        EOL         := (0Dh|0Ah)+   <-- consume consecutive line feeds and carriage returns
        EOS         := 0            <-- input must be null terminated

    */ comment ~

        mov ebx, esp    ;// we can abort the parser, so we need ebx to clean up the call stack
        xor esi, esi    ;// esi will be an allocated HIDCONTROL struct

    ;// device
        ;// Page:Usage
        call page_usage ;// may abort
        TESTJMP edx, edx, jz parse_complete ;// bad if no page usage
        mov [ebp].dwPageUsage, ecx          ;// store it
        ;// WHT
        call eat_white                      ;// may abort
        TESTJMP edx, edx, jz parse_complete ;// abort if no white
        ;// Endian
        and [ebp].dwFlags, NOT HIDDEVICE_IN_BE
        CMPJMP al, 'L', je E0
        CMPJMP al, 'B', jne parse_complete  ;// abort if unknown char
        or [ebp].dwFlags, HIDDEVICE_IN_BE
    E0: inc edi                             ;// consume
        ;// WHT
        call eat_white                      ;// may abort
        TESTJMP edx, edx, jz parse_complete ;// abort if no white
        ;// LongName
        lea ecx, [ebp].szShortName  ;// <-- device short name, long name is product string
        call long_name                      ;// does not abort, may be empty
    ;// control loop
    allocate_control:                       ;// allocate esi as a struct to fill in
        invoke GLOBALALLOC, GMEM_FIXED, SIZEOF HIDCONTROL
        mov esi, eax
        ASSUME esi:PTR HIDCONTROL
    invalid_control:                        ;// cleanse this node
        mov edx, edi                        ;// save edi
        mov edi, esi                        ;// where we fill
        mov ecx, (SIZEOF HIDCONTROL)/4      ;// data size
        xor eax, eax                        ;// fill with zero
        rep stosd                           ;// fill it
        mov edi, edx                        ;// retreive edi
        ;// EOL
        call next_line                      ;// may abort
        ;// page:usage.instance
        call page_usage_instance            ;// may abort
        TESTJMP eax, eax, jz invalid_control;// bad node if no page usage
        mov [esi].dwPageUsage, ecx
        mov [esi].dwInstance, edx
        ;// WHT
        call eat_white                      ;// may abort
        TESTJMP edx, edx, jz invalid_control;// skip if no white space
        ;// first last bit
        call first_last                     ;// may abort
        TESTJMP edx, edx, jz invalid_control;// skip if no white space
        mov [esi].W0, eax                   ;// save first bit
        mov [esi].W1, ecx                   ;// save last
        ;// WHT
        call eat_white                      ;// may abort
        TESTJMP edx, edx, jz invalid_control;// skip if no white space
        ;// Sign
        and [esi].dwFormat, NOT HIDCONTROL_IN_SIGNED
        CMPJMP al, 'U', je  E1
        CMPJMP al, 'S', jne invalid_control
        or [esi].dwFormat, HIDCONTROL_IN_SIGNED
    E1: inc edi
        ;// WHT
        call eat_white                      ;// may abort
        TESTJMP edx, edx, jz invalid_control;// skip if no white space
        ;// short name
        call short_name                     ;// may abort
        mov [esi].szShortName, ecx          ;// store the short name
        ;// long name
        lea ecx, [esi].szLongName
        call long_name                      ;// does not abort
        ;// this record is complete
        invoke hiddevice_insert_this_control;// insert the node
        TESTJMP eax,eax,jnz allocate_control;// ok to allocate a new if valid
        jmp invalid_control                 ;// otherwise invalid and continue on



    ALIGN 4
    page_usage_instance:;// return ecx=page:usage
                        ;//        edx=instance
                        ;//        eax=valid
            ;// PageUsageIndex := PageUsage ( . HEX ) ?
            call page_usage         ;// read page:usage
            TESTJMP edx, edx, jz U0 ;// bad if no page:usage
            mov al, [edi]           ;// get the next char
            xor edx, edx            ;// set to zero as default
            CMPJMP al, '.', jne U1  ;// no instance if not set
            inc edi                 ;// consume the input
            push ecx                ;// save the page:usage
            call read_hex           ;// read the instance
            test edx, edx           ;// check the instance
            mov edx, ecx            ;// store the instance
            pop ecx                 ;// retrieve the page:usage
            jnz U1                  ;// ok if chars were read
            xor edx, edx            ;// invalid instance, ignore ?
        U1: or eax, 1               ;// good return value
        U2: retn
        U0: xor eax, eax            ;// bad return value
            jmp U2




    ALIGN 4
    page_usage: ;// return page:usage in ecx
                ;// set edx as non zero to indicate sucess
            ;// PageUsage := HEX : HEX
            call read_hex           ;// may abort
            TESTJMP edx, edx, jz P0 ;// bad if no hex
            CMPJMP al, ':', jne P0  ;// bad if not a colon
            inc edi                 ;// consume the character
            push ecx                ;// save the page
            call read_hex           ;// may abort
            pop eax                 ;// retrieve
            TESTJMP edx, edx, jz P0 ;// bad if no second part
            ;// have valid page usage
            and ecx, 0FFFFh         ;// just in case
            shl eax, 16             ;// scoot page up to top
            or ecx, eax
        P0: retn



    ALIGN 4
    first_last: ;// return first in eax
                ;// return last in ecx
                ;// set edx as non zero to indicate sucess
            ;// PageUsage := HEX : HEX
            call read_hex           ;// may abort
            TESTJMP edx, edx, jz Q0 ;// bad if no hex
            CMPJMP al, '-', jne Q0  ;// bad if not a dash
            inc edi                 ;// consume the input
            push ecx                ;// save the first
            call read_hex           ;// may abort
            pop eax                 ;// retrieve the first
        Q0: retn                    ;// read hex returns edx as our return value



    ALIGN 4
    short_name: ;// no return value
                ;// ecx must point at destination
        ;// ShortName := 'char(char)'
        ;// two chars max
        ;// bah: this routine is pretty brittle

            mov ecx, DWORD PTR [edi]
            TESTJMP cl, cl, jz parse_complete
            .IF cl == "'"
                shr ecx, 8
                .IF cl == "'"
                    xor ecx, ecx    ;// empty string
                    add edi, 2
                .ELSEIF ch == "'"
                    and ecx, 0FFh   ;// one char string
                    add edi, 3
                .ELSE               ;// more than one char
                    and ecx, 0FFFFh
                    add edi, 4
                .ENDIF
                .IF ch <= 20h
                    mov ch, 0
                .ENDIF
                .IF cl <= 20h
                    mov cl, ch
                    mov ch, 0
                .ENDIF
                .IF cl <= 20h
                    xor ecx, ecx
                .ENDIF
            .ELSE                   ;// no string
                xor ecx, ecx
            .ENDIF
            push ecx
            call eat_white
            pop ecx
            retn


    ALIGN 4
    long_name:  ;// no return value
                ;// does NOT abort at eos
                ;// ecx must point at destination
                ;// al must have first char
                ;// al must NOT be whitspace
                ;// edi must point at that char
                ;// return with al at next input char
        ;// end on eol eos, terminate string
        ;// convert tab to space
        ;// combine adjacent spaces
        ;// trim trailing spaces
            xor edx, edx            ;// edx tags consecutive spaces
        L0: TESTJMP al, al, jz L6   ;// end on eos
            CMPJMP al, 0Dh, je L6   ;// end on eol
            CMPJMP al, 0Ah, je L6   ;// end on eol
            CMPJMP al, 09h, je L4   ;// convert tabs to spaces
            CMPJMP al, 20h, je L5   ;// do special processing if space
            xor edx, edx            ;// reset the got space tag
        L2: mov [ecx], al           ;// store the char
            inc ecx                 ;// advance the output
        L3: inc edi                 ;// advance the input
            mov al, [edi]           ;// get the next char
            jmp L0                  ;// back to top of loop
        L4: mov al, 20h             ;// convert tabs to spaces
        L5: TESTJMP edx,edx, jnz L3 ;// get next char if conesecutive space
            inc edx                 ;// set the tag
            jmp L2                  ;// store the character
        L6: TESTJMP edx, edx, jz L7 ;// back up if last char is a space
            dec ecx
        L7: mov BYTE PTR [ecx], 0   ;// terminate the string
            retn                    ;// otherwise return to caller


    ALIGN 4
    read_hex:   ;// returns edx as the number of hex characters read
                ;//         ecx as the hex value
                ;//         al as the next char
            xor ecx, ecx    ;// return value
            xor edx, edx    ;// number of valid hax characters
        H0: xor eax, eax
            mov al, [edi]   ;// get the char
            TESTJMP al, al, jz parse_complete
            SUBJMP al, '0', jb H2
            CMPJMP al, 10 , jb H1
            SUBJMP al, 'A'-'0'-10, jb H2
            CMPJMP al, 10h, jae H2
            CMPJMP al, 10 , jb H2
        H1: shl ecx, 4      ;// have a valid hex value, accumulate it
            inc edx         ;// increase num characters consumed
            add ecx, eax
            inc edi         ;// next char
            jmp H0      ;// back to top
        H2: mov al, [edi]   ;// always retrun with the next char
            retn


    ALIGN 4
    eat_white:  ;// returns edx as the number of wht space read
                ;//         al as next char
            xor edx, edx    ;// space counter
        W0: mov al, [edi]
            TESTJMP al, al, je parse_complete
            CMPJMP al, 20h, je W1   ;// next char if space
            CMPJMP al, 09h, jne W2  ;// done if not space
        W1: inc edi         ;// next char
            inc edx         ;// count spaces
            jmp W0          ;// back to top
        W2: retn




    ALIGN 4
    next_line:
            mov al, [edi]
            TESTJMP al, al, je parse_complete
            CMPJMP al, 0Dh, je N1   ;// enter other loop if line feed
            CMPJMP al, 0Ah, je N1   ;// enter other loop if line feed
            inc edi
            jmp next_line
        N0: mov al, [edi]
            TESTJMP al, al, je parse_complete
            CMPJMP al, 0Dh, je  N1  ;// consume if lineed
            CMPJMP al, 0Ah, jne N2  ;// done if not linefeed
        N1: inc edi
            jmp N0
        N2: retn



    ALIGN 4
    parse_complete:

            mov esp, ebx    ;// restore the call stack
            .IF esi         ;// free any uninitialized nodes
                invoke GLOBALFREE, esi
            .ENDIF

    ;// and we have consumed
    ;// thus we return sucess

            mov eax, 1

    all_done:

            pop ebx
            pop esi
            pop edi
            pop ebp

            retn 8  ;// STDCALL 2 args

hiddevice_init_from_string ENDP





ASSUME_AND_ALIGN    ;// PROLOGUE IS OFF !!
hiddevice_try_init_from_registry PROC

        ASSUME ebp:PTR HIDDEVICE    ;// passed by caller, preserve
        push esi    ;// save
        push edi    ;// edi = hDevice: preserve !!
        push ebx    ;// ebx = ptr to preparsed data: preserve !!
        ;// can destroy eax edx ecx
        ;// return eax = 1 for initialized sucessfully

        xor esi, esi    ;// at the exit, esi is the return value

        .DATA
        szHidObjectRegKey   db 'Software\AndyWare\HIDObject',0
        ALIGN 4
        .CODE

    ;// try to open our key HKEY_CURRENT_USER\Software\AndyWare\HIDObject

        pushd 0 ;// hKey
        mov eax, esp
        pushd 0 ;// disp

        invoke RegCreateKeyExA, HKEY_CURRENT_USER,OFFSET szHidObjectRegKey,
            REG_OPTION_RESERVED,0,REG_OPTION_NON_VOLATILE,
            KEY_SET_VALUE + KEY_CREATE_SUB_KEY + KEY_QUERY_VALUE,
            0,eax,esp

        pop edx ;// disposition
        pop ebx ;// ebx is the hKey

        TESTJMP eax, eax, jnz all_done

    ;// if we created a new key then we don't have values to get do we

        CMPJMP edx, REG_CREATED_NEW_KEY, je close_the_reg_key

    ;// we have this key, see if we have this value

    ;// first: ask for the size of the data

        lea edx, [ebp].szRegValueName
        pushd 0                                     ;// size of data
        invoke RegQueryValueExA, ebx, edx,0,0,0,esp
        pop edi                                     ;// edi is the required size
        TESTJMP eax, eax, jnz close_the_reg_key     ;// exit if value doesn't exist
        TESTJMP edi, edi, jz close_the_reg_key      ;// exit if there is no data

    ;// second, get the data on the stack

        add edi, 15     ;// pad an extra dword or two
        and edi, NOT 3  ;// dword align the size
        sub esp, edi    ;// make a buffer on the stack

        lea edx, [ebp].szRegValueName
        mov eax, esp    ;// point at buffer
        push edi        ;// input size
        invoke RegQueryValueExA, ebx, edx,0,0,eax,esp
        pop ecx         ;// get the write size
                        ;// HO091, for XP we converted to a binary block
        mov DWORD PTR [esp+ecx], 0  ;// make sure the string is multiply terminated
        add edi, esp    ;// edi is where to put the stack
        TESTJMP eax, eax, jnz clean_up_stack_then_close
        TESTJMP ecx, ecx, jz clean_up_stack_then_close

    ;// STATE:  ebp = container
    ;//         edi = end of stack
    ;//         esp = stored data we need to parse
    ;//         ebx = opened reg key

        invoke hiddevice_init_from_string, ebp, esp ;// call the generic init function
        mov esi, eax                                ;// save it's return value

    clean_up_stack_then_close:

        mov esp, edi

    close_the_reg_key:

        .IF ebx
            invoke RegCloseKey, ebx
        .ENDIF

    all_done:

    ;// then do the return value and return

        mov eax, esi    ;// return value
        pop ebx
        pop edi
        pop esi

        retn

hiddevice_try_init_from_registry ENDP



comment ~ /*

hiddevice_try_to_init_from_capabilities

    this one's a monster ....

    for this one we are first going to make an array of holders
    we scan capabilities of the device and fill in the holders
    after that, we build a format string
    we pass the string to init from string
    and hope all goes well

    we will attempt to derive the data locations
    and attempt to define what names we can as well

    anything we can't deal with just aborts the process
    user can decide what to do

    see hid_caps_parse.txt for some examples of what we're working with


*/ comment ~


ASSUME_AND_ALIGN    ;// PROLOGUE IS OFF !!
hiddevice_try_to_init_from_capabilities PROC


        ASSUME ebp:PTR HIDDEVICE    ;// passed by caller: PRESERVE
        push ebx    ;// ebx is pointer to preparsed data
        push edi    ;// edi is the opened file handle:  PRESERVE
        push esi


        ;// we're going to be doing a lot of stuff on the stack ...
        ;// we'll use edi to point there

    ;// 1) get the capailities (again ?)

        sub esp, SIZEOF HIDP_CAPS
        invoke HidP_GetCaps, ebx, esp
        st_caps TEXTEQU <(HIDP_CAPS PTR [esp])>

        ;// we are interested in:
        ;//
        ;// HIDP_CAPS.wUsage        dw ?    tells us the device type
        ;// HIDP_CAPS.wUsagePage    dw ?
        ;//
        ;// HIDP_CAPS.wNumberInputButtonCaps    dw  ?   tells us how many button caps we need
        ;// HIDP_CAPS.wNumberInputValueCaps     dw ?    tells us how many input values there are
        ;// HIDP_CAPS.wNumberInputDataIndices   dw ?    tells us how many holders we need

        ;// try to get a short name
        mov eax, DWORD PTR st_caps.wUsage   ;// get the usage page and usage
        lea edx, [ebp].szShortName
        invoke hidusage_GetUsageString, eax, edx
        ;// then load other values we only need once
        mov eax, DWORD PTR st_caps.wUsage   ;// get the usage page and usage
        movzx edx, st_caps.wNumberInputButtonCaps
        movzx ecx, st_caps.wNumberInputValueCaps
        movzx esi, st_caps.wNumberInputDataIndices

        mov [ebp].dwPageUsage, eax ;// save the device type

        add esp, SIZEOF HIDP_CAPS   ;// clean up the stack
        st_caps TEXTEQU <>

;// stack cleaned up

        TESTJMP esi, esi, jz no_data_indices    ;// exit if there are no holders

        mov eax, edx
        ORJMP eax, ecx, jz no_control_values    ;// exit if there are no controls

    ;// we have things to process
    ;// build the values on the stack and allocate the holder array

        CONTROL_HOLDER STRUCT

            W0              dd  0   ;// start bit
            W1              dd  0   ;// stop bit
            PAGEUSAGE       {}      ;// usage page and usage
            dwFormat        dd  0   ;// data type if we can figure it out

            szLongName  db HIDUSAGE_MAX_STRING_SIZE DUP (0) ;// the name if we can figure it out
            szShortName dd  0   ;// always two chars or less

            pad_32 dd 3 dup(0)  ;// size must be a power of 2

        CONTROL_HOLDER ENDS

        .ERRNZ  ( (1 SHL LOG2(SIZEOF CONTROL_HOLDER) ) - (SIZEOF CONTROL_HOLDER) ), <size must be a power of 2>

        push edx    ;// num buttons
        push ecx    ;// num values
        push esi    ;// number of holders

        mov edi, esp    ;// now edi is the stack pointer

        edi_num_buttons TEXTEQU <(DWORD PTR [edi+08h])>
        edi_num_values  TEXTEQU <(DWORD PTR [edi+04h])>
        edi_num_holder  TEXTEQU <(DWORD PTR [edi+00h])>

        shl esi, LOG2(SIZEOF CONTROL_HOLDER)    ;// number of holders we need
        sub esp, esi                            ;// make array on the stack
        mov esi, esp                            ;// now esi points at them
        ASSUME esi:PTR CONTROL_HOLDER           ;// esi is also the bottom of our stack

    ;// initialize the holders

        mov ecx, edi_num_holder
        or eax, -1
        shl ecx, LOG2(SIZEOF CONTROL_HOLDER)
        .REPEAT
            sub ecx, SIZEOF CONTROL_HOLDER
            .BREAK .IF SIGN?
            or [esi+ecx].W0, eax
            or [esi+ecx].W1, eax
        .UNTIL 0

    ;// process the buttons

        mov eax, edi_num_buttons
        TESTJMP eax, eax, jz buttons_done

        imul eax, SIZEOF HIDP_BUTTON_CAPS   ;// convert to total array size
        sub esp, eax    ;// make array buffer on stack
        mov edx, esp    ;// point to the buffer
        push edi_num_buttons    ;// have to use the number of structs as an arg
        mov ecx, esp    ;// point to it
        invoke HidP_GetButtonCaps,
            HidP_Input, ;// dwReportType,
            edx,        ;// pHIDP_BUTTON_CAPS,      ptr to array we just built
            ecx,        ;// pdwButtonCapsLength,    ptr to the length
            ebx         ;// pPreparsedData
        pop ecx         ;// retrieve the number of structures
        CMPJMP eax, HIDP_STATUS_SUCCESS, jne abort_capabilities ;// abort of we can't get the caps

        ;// look at the arrays  as HIDP_BUTTON_CAPS at esp on up to esi

        st_button TEXTEQU <(HIDP_BUTTON_CAPS PTR [esp])>

        ;// we are interested in
        ;//
        ;//
        ;// HIDP_BUTTON_CAPS.wUsagePage dw // HID Page button << tells us where to look for the name
        ;// HIDP_BUTTON_CAPS.bIsRange   db // tells us how to process
        ;//
        ;// ;// if range
        ;// HIDP_BUTTON_CAPS.wUsageMin  dw
        ;// HIDP_BUTTON_CAPS.wUsageMax  dw // Button 5 - 9  << gives us the name
        ;// HIDP_BUTTON_CAPS.wDataIndexMin dw
        ;// HIDP_BUTTON_CAPS.wDataIndexMax dw   // data index 8 - C
        ;//
        ;// ;// if not range
        ;// HIDP_BUTTON_CAPS.wUsage             0x0031  // HID_USAGE_GENERIC_Y
        ;// HIDP_BUTTON_CAPS.wDataIndex ;// first index
        ;//
        ;// for the time being we will ignore strings ... although they might help us

        .REPEAT

            movzx ecx, st_button.Range.wDataIndexMin    ;// start the loop

            cmp st_button.bIsRange, 0   ;// trick the following loop to always succeed
            .IF ZERO?

                mov ax, st_button.Range.wUsageMin
                mov st_button.Range.wDataIndexMax, cx
                mov st_button.Range.wUsageMax, ax

            .ENDIF

            .REPEAT ;// assign the indexes

            ;// index = wDataIndexMin
            ;// if already set, abort

                shl ecx, LOG2(SIZEOF CONTROL_HOLDER)
                add ecx, esi
                ASSUME ecx:PTR CONTROL_HOLDER

                CMPJMP ecx, esi, jb  abort_capabilities ;// exit if beyond array
                CMPJMP ecx, edi, jae abort_capabilities ;// exit if beyond array
                CMPJMP [ecx].W0, -1, jne abort_capabilities ;// exit if already set

            ;// holder[index].W0 = 1    ;// bit size

                mov [ecx].W0, 1         ;// size is one bit

            ;// holder[index].dwDataType = HIDMASK_DATA_TYPE_B_LE

                mov [ecx].dwFormat,0    ;// HIDCONTROL_IN_BOOLEAN

            ;// holder[index].dwControlType = wUsagePage << 16 + wUsageMin

                mov ax, st_button.wUsagePage
                shl eax, 16
                mov ax, st_button.Range.wUsageMin
                mov [ecx].dwPageUsage, eax

                inc st_button.Range.wDataIndexMin       ;// wDataIndexMin ++
                inc st_button.Range.wUsageMin           ;// wUsageMin ++

                movzx ecx, st_button.Range.wDataIndexMin
                movzx eax, st_button.Range.wDataIndexMax

            .UNTIL ecx > eax

        ;// now we are done with this button cap

            add esp, SIZEOF HIDP_BUTTON_CAPS

        .UNTIL esp >= esi

        ;// clean up the stack just in case the loop failed
        mov esp, esi
        st_button TEXTEQU <>

    buttons_done:   ;// or there were none

    ;// process the values

        mov eax, edi_num_values
        TESTJMP eax, eax, jz values_done

        imul eax, SIZEOF HIDP_VALUE_CAPS    ;// convert to total array size
        sub esp, eax    ;// make array buffer on stack
        mov edx, esp    ;// point to the buffer
        push edi_num_values ;// have to use the number of structs as an arg
        mov ecx, esp    ;// point to it
        invoke HidP_GetValueCaps,
            HidP_Input, ;// dwReportType,
            edx,        ;// pHIDP_BUTTON_CAPS,      ptr to array we just built
            ecx,        ;// pdwButtonCapsLength,    ptr to the length
            ebx         ;// pPreparsedData
        pop ecx         ;// retrieve the number of structures
        CMPJMP eax, HIDP_STATUS_SUCCESS, jne abort_capabilities ;// abort of we can't get the caps

        ;// look at the arrays  as HIDP_BUTTON_CAPS at esp on up to esi

        st_value TEXTEQU <(HIDP_VALUE_CAPS PTR [esp])>

        ;// we are interested in
        ;//
        ;// HIDP_VALUE_CAPS.wUsagePage      dw  ;// usage page
        ;// HIDP_VALUE_CAPS.bIsRange    db  0   ;// range or single
        ;//
        ;// HIDP_VALUE_CAPS.wBitSize        dw  ;// number of bits
        ;// HIDP_VALUE_CAPS.wReportCount    dw  ;// must equal 1 !!
        ;//
        ;// HIDP_VALUE_CAPS.dwLogicalMin    dd  0   ;// we can persuse these to
        ;// HIDP_VALUE_CAPS.dwLogicalMax    dd  0   ;// get signed and unsigned
        ;// HIDP_VALUE_CAPS.dwPhysicalMin   dd  0
        ;// HIDP_VALUE_CAPS.dwPhysicalMax   dd  0
        ;//
        ;// HIDP_VALUE_CAPS.wUsageMin       dw  0   ;// iteraters for the loop
        ;// HIDP_VALUE_CAPS.wUsageMax       dw  0
        ;// HIDP_VALUE_CAPS.wDataIndexMin   dw  0
        ;// HIDP_VALUE_CAPS.wDataIndexMax   dw  0
        ;//
        ;// for the time being we will ignore strings ... although they might help us

        .REPEAT

            movzx ecx, st_value.Range.wDataIndexMin ;// start the loop

            cmp st_value.bIsRange, 0    ;// trick the following loop to always succeed
            .IF ZERO?

                mov ax, st_value.Range.wUsageMin
                mov st_value.Range.wDataIndexMax, cx
                mov st_value.Range.wUsageMax, ax

            .ENDIF

            .REPEAT ;// assign the indexes

            ;// index = wDataIndexMin
            ;// if already set, abort

                shl ecx, LOG2(SIZEOF CONTROL_HOLDER)
                add ecx, esi
                ASSUME ecx:PTR CONTROL_HOLDER

                CMPJMP ecx, esi, jb  abort_capabilities ;// exit if beyond array
                CMPJMP ecx, edi, jae abort_capabilities ;// exit if beyond array
                CMPJMP [ecx].W0, -1, jne abort_capabilities ;// exit if already set

            ;// check the report count

                CMPJMP st_value.wReportCount, 1, jne abort_capabilities

            ;// holder[index].W0 = bit size ;// bit size

                movzx eax, st_value.wBitSize
                mov [ecx].W0, eax

            ;// holder[index].dwDataType = int, either signed or unsigned

                ;// if only one bit, then we must be bool, although this shouldn't happen for values
                DECJMP eax, jz S1 ;// HIDCONTROL_IN_BOOLEAN
                mov eax, st_value.dwLogicalMin
                mov edx, HIDCONTROL_IN_SIGNED ;// assume signed for the moment
                XORJMP eax, st_value.dwLogicalMax, js S0
                mov eax, st_value.dwPhysicalMin
                XORJMP eax, st_value.dwPhysicalMax, js S0
            S1: xor edx, edx    ;// back off to unsigned
            S0: mov [ecx].dwFormat,edx

            ;// holder[index].dwControlType = wUsagePage << 16 + wUsageMin

                mov ax, st_value.wUsagePage
                shl eax, 16
                mov ax, st_value.Range.wUsageMin
                mov [ecx].dwPageUsage, eax

                inc st_value.Range.wDataIndexMin    ;// wDataIndexMin ++
                inc st_value.Range.wUsageMin        ;// wUsageMin ++

                movzx ecx, st_value.Range.wDataIndexMin
                movzx eax, st_value.Range.wDataIndexMax

            .UNTIL ecx > eax

        ;// now we are done with this button cap

            add esp, SIZEOF HIDP_VALUE_CAPS

        .UNTIL esp >= esi

        ;// clean up the stack just in case the loop failed
        mov esp, esi
        st_value TEXTEQU <>

    values_done:

    ;// ok, now we have a partially initialized array of holders
    ;// let us go through and initialize the W0 and W1 completely
    ;// we'll also try to find names for the controls

        mov ecx, esi                ;// at begining of holders
        mov edx, 8                  ;// running bit counter, always starts at 8

    ;// added note: if we get a value, and the previous holder is a button
    ;// then we must 16 bit align the index ....
    ;// we'll use ebx store the previous size
    ;// then if eax != 1 and ebx does equal 1, then we align

        mov ebx, 8
        .REPEAT
            mov eax, [ecx].W0       ;// get the size
            TESTJMP eax, eax, js abort_capabilities ;// EVERY holder must be set !!
            dec eax                 ;// stop bit = start + size - 1

            .IF !ZERO?              ;// this size is not zero
                .IF !ebx            ;// the previous size WAS ZERO
                    add edx, 15     ;// 16 bit align
                    and edx, NOT 15 ;// mask out the rest
                .ENDIF
            .ENDIF
            mov ebx, eax            ;// store the previous size-1

            mov [ecx].W0, edx       ;// save the running counter
            add edx, eax            ;// stop bit = start + size - 1
            mov [ecx].W1, edx
            inc edx                 ;// W0 for the next struct
            add ecx, SIZEOF CONTROL_HOLDER
        .UNTIL ecx >= edi           ;// until ecx goes beyond end of holder array

    ;// now check the final index and make sure it's equal or less than the max number of bits

        mov eax, [ebp].dwInputReportSize
        shl eax, 3
        CMPJMP edx, eax, ja abort_capabilities

    ;// now we have an array of holders and their bit values
    ;// let us try to determine names and how much room we need for the input string
    ;// we are done with ebx, so we'll use it as a string iterator

        mov ebx, 64     ;// start at max length of header line
        mov ecx, esi
        .REPEAT

            MIN_LINE_SIZE EQU 28    ;// see sz_out_fmt_02

            push ecx
            invoke hidusage_GetUsageString, [ecx].dwPageUsage, ADDR [ecx].szLongName
            lea ebx, [ebx+eax+MIN_LINE_SIZE]    ;// accumulate the name length

            mov ecx, [esp]
            invoke hidusage_GetShortString, [ecx].dwPageUsage, ADDR [ecx].szShortName
            pop ecx

            add ecx, SIZEOF CONTROL_HOLDER      ;// next holder

        .UNTIL ecx >= edi

    ;// now we have all sorts of names stuff that we can begin to build the format string for this

    ;// step one:   make a text buffer on the stack and point ebx at it
    ;//             we'll use ebx to iterate through the strings

        add ebx, 7
        and ebx, NOT 3  ;// keep the stack aligned!
        sub esp, ebx
        mov ebx, esp    ;// ebx always points at the output buffer

    ;// step two: fill in the string

        ;// store the endian type and device type, assume LE for now

            .DATA
            sz_out_fmt_01   db  '%X:%X %c ',0   ;//  %s',0Dh,0
            ALIGN 4
            .CODE

            pushd 'L'   ;// %c
            movzx eax, [ebp].wUsage
            movzx edx, [ebp].wPage
            push eax
            push edx
            push OFFSET sz_out_fmt_01
            push ebx
            call wsprintfA
            add esp, 5*4    ;// C call 5 args
            add ebx, eax    ;// accumulate the length

        ;// store the device short name

            invoke hidusage_GetUsageString, [ebp].dwPageUsage, ebx
            add ebx, eax

        ;// store all the controls

            mov ecx, esi    ;// ecx walks the controls
            .REPEAT

                ;// control := crPage:Usag.Inst Fi-La S 'xx' LongName
                ;//             01234567890123456789012345678
                ;//                       1         2
                .DATA
                sz_out_fmt_02 db 0Dh,"%X:%X.%X %X-%X %c '%s' %s",0
                ;// see MIN_LINE_SIZE EQU 28    ;// see sz_out_fmt_02
                ALIGN 4
                .CODE

                push ecx    ;// save the holder ptr

                lea eax, [ecx].szLongName
                lea edx, [ecx].szShortName
                push eax                    ;// %s      10
                push edx                    ;// %s      9
                test [ecx].dwFormat, HIDCONTROL_IN_SIGNED
                mov eax, 'U'
                .IF !ZERO?
                    add eax, 'S'-'U'
                .ENDIF
                push eax                    ;// %c      8
                push [ecx].W1               ;// %X      7
                push [ecx].W0               ;// %X      6
                pushd 0 ;// [ecx].dwInstance;// .%X     5
                movzx eax, [ecx].wUsage
                movzx edx, [ecx].wPage
                push eax                    ;// :%X     4
                push edx                    ;// %X      3
                push OFFSET sz_out_fmt_02   ;// pszFmt  2
                push ebx                    ;// pDest   1
                call wsprintfA
                add esp, 10*4   ;// C call 10 args

                pop ecx     ;// retrieve the holder ptr

                add ebx, eax
                DEBUG_IF < ebx !>= esi >    ;// not supposed to happen !!
                add ecx, SIZEOF CONTROL_HOLDER

            .UNTIL ecx >= edi

        ;// now we should have a fully built init string
        ;// we can call init from string to parse it

            invoke hiddevice_init_from_string, ebp, esp


    abort_capabilities: ;// can't work with this or we're done, free up the stack and exit

        lea esp, [edi+0Ch]  ;// cleanup the stack

;// error outs with no stack adjustment

    no_data_indices:    ;// exit if there are no holders
    no_control_values:  ;// exit if there are no controls

;// normal exit with no stack adjustment

    all_done:

        pop esi
        pop edi
        pop ebx

        retn

hiddevice_try_to_init_from_capabilities ENDP



ASSUME_AND_ALIGN    ;// PROLOGUE IS OFF !!
hiddevice_Ctor PROC STDCALL pszHidDeviceName:DWORD
    ;// stack           00      04
    ;//
    ;// returns eax = pHIDDEVICE or zero for error
    ;//
    ;// get data nessesary to read from the device
    ;// then closes the device

        push ebp
        push esi
        push edi
        push ebx

        xor ebp, ebp    ;// will be the return value
        xor esi, esi    ;// will point to a stack allocated HIDP_CAPS
        xor ebx, ebx    ;// will need to free preparsed data
        xor edi, edi    ;// will have the file

    ;// stack   ebx edi esi ebp ret pFilename
    ;//         00  04  08  0C  10  14

    ;// make sure we've a valid filename

            mov ecx, [esp+14h]      ;// pFileName
            TESTJMP ecx, ecx, jz err_no_filename
            CMPJMP BYTE PTR [ecx], 0, je err_no_filename

    ;// Call CreateFile to obtain a file handle to a HID collection.

            invoke CreateFileA,
                ecx,
                GENERIC_READ OR GENERIC_WRITE,
                FILE_SHARE_READ OR FILE_SHARE_WRITE,
                0, OPEN_EXISTING, FILE_FLAG_OVERLAPPED, 0

            .IF eax == -1   ;// WINXP doesn't allow r/w access to keyboard or mouse
                            ;// this let's us at least see it

                mov ecx, [esp+14h]      ;// pFileName
                invoke CreateFileA,
                    ecx,0,
                    FILE_SHARE_READ OR FILE_SHARE_WRITE,
                    0, OPEN_EXISTING, FILE_FLAG_OVERLAPPED, 0

            .ENDIF

            INCJMP eax, jz cant_open_device
            lea edi, [eax-1]        ;// edi = the handle of the device

    ;// get the preparsed data for this device

            pushd 0     ;// return ptr
            invoke HidD_GetPreparsedData, edi, esp
            pop ebx     ;// ebx = preparsed data
            TESTJMP eax, eax, jz cant_get_preparsed_data

    ;// get the device caps and check for zero data

            sub esp, SIZEOF HIDP_CAPS                   ;// make space on the stack
            mov esi, esp                                ;// esi now points at the device caps
            ASSUME esi:PTR HIDP_CAPS
            invoke HidP_GetCaps, ebx, esp               ;// get the caps
            CMPJMP eax, HIDP_STATUS_SUCCESS, jnz cant_get_hid_caps  ;// check for error
            movzx eax, [esi].wInputReportByteLength     ;// get the report size
            TESTJMP eax, eax, jz caps_has_no_device_data;// exit if no input data

    ;// allocate a DEVICE to fill in

            invoke GLOBALALLOC, GPTR, SIZEOF HIDDEVICE
            mov ebp, eax
            ASSUME ebp:PTR HIDDEVICE

    ;// force a rebuild of the format

            or [ebp].dwFlags, HIDDEVICE_FORMAT_CHANGED

    ;// copy the page usage
    ;// get the report size

            movzx eax, [esi].wInputReportByteLength     ;// get the report size
            mov edx, DWORD PTR [esi].wUsage
            mov [ebp].dwInputReportSize, eax            ;// store the data read size
            mov [ebp].dwPageUsage, edx

    ;// copy the filename

    ;// stack   CAPS    ebx edi esi ebp ret pFilename
    ;//         sizeof  00  04  08  0C  10  14

            mov edx, [esp+(SIZEOF HIDP_CAPS)+14h]
            lea eax, [ebp].szFileName
            invoke lstrcpyA, eax, edx

    ;// get the product string, it's wide char so we convert in place

            push edi    ;// save the file handle
            push esi    ;// save esi

            sub esp, HID_MAX_NAME_LENGTH * 2    ;// make string space on the stack
            mov esi, esp                        ;// point at input buffer
            invoke  HidD_GetProductString, edi, esi, HID_MAX_NAME_LENGTH * 2
            .IF eax ;// make sure we suceed

                mov ecx, HID_MAX_NAME_LENGTH-1  ;// max name size we support
                lea edi, [ebp].szLongName       ;// point at where we put it, edi destroyed !!
                .REPEAT
                    lodsw           ;// get a word
                    .BREAK .IF !al  ;// test for zero
                    stosb           ;// store as byte
                .UNTILCXZ           ;// stop if too long
                xor eax, eax
                stosb               ;// terminate

            .ENDIF                  ;// eax exits as zero

            add esp, HID_MAX_NAME_LENGTH * 2    ;// clean up the stack

            pop esi
            pop edi

    ;// build the registry key name

            .DATA
            fmt_reg_value_name      db  '%4.4X_%4.4X_%4.4X_%4.4X_%4.4X',0
            ALIGN 4               ;//    vend  prod  page  usage repsize
            .CODE

            pushd [ebp].dwInputReportSize   ;// wsprintf %repsize
            movzx eax, [ebp].wUsage
            push eax                ;// wsprintf %usage
            movzx eax, [ebp].wPage
            push eax                ;// wsprintf %page
            ;// make and read a HIDD_ATTRIBUTES struct on the stack
            push eax                ;// lo = VersionNumber
            push eax                ;// lo = VendorID   hi = ProductID
            pushd SIZEOF HIDD_ATTRIBUTES
            invoke HidD_GetAttributes, edi, esp
            add esp, 4              ;// size, don't care
            pop eax                 ;// prod:vend
            pop edx                 ;// ver, don't care, stack is now cleaned up
            mov ecx, eax
            shr eax, 16             ;// eax = prod
            and ecx, 0FFFFh         ;// ecx = vender
            ;// push the results
            push eax                ;// wsprintf %prod
            push ecx                ;// wsprintf %vend

            lea  edx, [ebp].szRegValueName

            push OFFSET fmt_reg_value_name  ;// wsprintf szFormat
            push edx                ;// wsprintf pDestination

            call wsprintfA

            add esp, 7*4    ;// C call

    ;// always create the first node, destroys esi

            xor ecx, ecx                        ;// always bit 0
            invoke hidcontrol_create_this_node  ;// returns esi as the node
            ASSUME esi:PTR HIDCONTROL
            mov [esi].W1, 7     ;// last bit of the report is always bit 7
            ;// set a default name
            ;// 'report number'
            mov DWORD PTR [esi].szLongName[00h], 'oper'
            mov DWORD PTR [esi].szLongName[04h], 'n tr'
            mov DWORD PTR [esi].szLongName[08h], 'ebmu'
            mov DWORD PTR [esi].szLongName[0Ch], 'r'

    ;// try to initialize the controls of this device
    ;// if registry override, then we may get a new page useage
    ;// or by analyzing the HID capabilities

            invoke hiddevice_try_init_from_registry
            .IF !eax
                invoke hiddevice_try_to_init_from_capabilities
            .ENDIF

    ;// determine the instance number
    ;// requires walking the rest of the structs to determine the instance number ...
    ;// we are not in the list yet so we can just check the page usage

            mov eax, [ebp].dwPageUsage  ;// what we are wanting to count
            xor edx, edx                ;// iterator
            xor ecx, ecx                ;// counter
            dlist_OrGetHead hiddevice, edx
            .IF !ZERO?
            .REPEAT
                .IF eax == [edx].dwPageUsage
                    inc ecx
                .ENDIF
                dlist_GetNext hiddevice, edx
            .UNTIL !edx
            .ENDIF
            mov [ebp].dwInstance, ecx

    ;// we also need the instance numbers for our controls
    ;// we'll do that in hiddevice_build_formats

    ;// sucesss !
    ;// that should do it !

err_no_filename:
cant_open_device:
cant_get_preparsed_data:
cant_get_hid_caps:
caps_has_no_device_data:

        .IF ebx     ;// free the preparsed data
            invoke HidD_FreePreparsedData, ebx
        .ENDIF
        .IF edi     ;// close the device
            invoke CloseHandle, edi
        .ENDIF
        .IF esi
            add esp, SIZEOF HIDP_CAPS
        .ENDIF

        mov eax, ebp    ;// return value

        pop ebx
        pop edi
        pop esi
        pop ebp

        retn 4  ;// STDCALL 1 arg

hiddevice_Ctor ENDP





;///////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////
;///
;///
;///    FORMAT AND CONVERT DATA
;///

comment ~ /*

    building the convertion parameters is confusing
    here is what we are working with:

        R0 = read bit, data is read as a dword  (absolute coords)
        W0 and W1 are the first_bit and last_bit of the LITTLE ENDIAN
        V0 and V1 are the resultant bits INSIDE THE READ DWORD

    for any format, step 1 is to convert W0 and W1 to V0 and V1
    these will be different for LE and BE type

    once we have V0 and V1 we can apply standard formulas to derive S1 and S2 values
    the S values are used to implement unsigned and signed types

        R0 = W0 AND NOT 7

            true for all non bit types

        LE FORMATS

            V0 = W0 - R0
            V1 = W1 - R0

        BE FORMATS

            U0 = (W1 XOR 7) - R0    ;// BE->LE bit = BE XOR 7
            U1 = (W0 XOR 7) - R0

            V0 = U0 XOR 18h         ;// BSWAP bit position is BIT XOR 18h
            V1 = U1 XOR 18h

    TYPE CONVERTIONS

        once the data is read into a dword register

        UNSIGNED ------------------------------------------------------------

            S1 = V0                     ;// right shift lsb to bit position 0
            S2 = (1 SHL (V1-V0+1))-1    ;// AND mask to remove extra

                                           31
                                           |
            |-------|-------|-------|-------
                 |         |
            <-S1-v0        v1                   right shift

                                           31
                                           |
            |-------|-------|-------|-------
            |         |
            v0        v1
            11111111111                         mask
                S2


        SIGNED --------------------------------------------------------------

            S1 = 31-V1      ;// left shift msb into sign
            S2 = S1+V0      ;// right shift lsb down to position 0

                                           31
                                           |
            |-------|-------|-------|-------
                 |         |
                 v0        v1-------S1----->    left shift

                                           31
                                           |
            |-------|-------|-------|-------
            <---------V0+S1------|         |    right shift sign extend
                                 v0+S1     v1



        NORMALIZED SIGNED FLOAT --------------------------------------------------------------

            do the signed
            then build node.normalizer
            node.normalizer = fscale neg(W1-W0)



    ADDENDUM FOR HIDOBJECT

        now that we differentiate between input and output formats
        we have redone the sequencing a little bit

        R0 = read bit, data is read as a dword  (absolute coords)
        W0 and W1 are the first_bit and last_bit of the LITTLE ENDIAN
        V0 and V1 are the resultant bits INSIDE THE READ DWORD


Let us define

    LE  SINGLEBIT   UNSIGNED    INT     POS
    BE  MULTIBIT    SIGNED      FLOAT   NEG

and we have two stages to read the data, input and output

taken together, there are only 11 routines to calculate any format

    input

        SINGLEBIT

            LE FORMATS      S1 = W0
            BE FORMATS      S1 = W0 XOR 7

                            xor eax, eax
                            bt dat,[S1]
                            adc eax,eax
                            jmp output

                    there are only three ways to calc this



        MULTIBIT            R0 = W0 AND NOT 7           ;// true for all non bit types

                            mov eax, [R0]

            LE FORMATS      V0 = W0 - R0
                            V1 = W1 - R0

                            jmp signed_unsigned

            BE FORMATS      U0 = (W1 XOR 7) - R0        ;// BE->LE bit = BE XOR 7
                            U1 = (W0 XOR 7) - R0

                            V0 = U0 XOR 18h             ;// BSWAP bit position is BIT XOR 18h
                            V1 = U1 XOR 18h

                            bswap eax
                            jmp signed_unsigned

        signed_unsigned

            UNSIGNED        S1 = V0                     ;// right shift lsb to bit position 0
                            S2 = (1 SHL (V1-V0+1))-1    ;// AND mask to remove extra

                            shr eax, S1
                            and eax, S2
                            jmp output

            SIGNED          S1 = 31-V1                  ;// left shift msb into sign
                            S2 = S1+V0                  ;// right shift lsb down to position 0

                            shl eax, S1
                            sar eax, S2
                            jmp output

                    4 combinations of input with 2 possible outputs
                    equal 8 multibit combinations

    output

        INTEGER             store eax

        FLOAT

            SINGLEBIT

                POS=BIP     shl eax,1
                            fild eax
                            fsub one
                            fstp out

                NEG=DIG     fild eax
                            fchs
                            fstp out

            MULTIBIT

                UNSIGNED    normalizer = fscale neg(W1-W0)

                SIGNED

                    POS     normalizer = fscale neg(W1-W0)

                    NEG     normalizer = - fscale neg(W1-W0)

                            fild eax
                            fmul normalizer
                            fstp out



*/ comment ~



;// PROLOGUE IS OFF !!
ASSUME_AND_ALIGN
hiddevice_build_formats PROC    ;// PRIVATE to this file

    ;// builds the convertion format parameters described above
    ;// we also make sure that the dwType value is appropriate
    ;// and we transfer HIDMASK_DATA_BE from the main container
    ;// we also set the instance numbers by counting page:usage

        ASSUME ebp:PTR HIDDEVICE    ;// passed by caller
        push ebx    ;// preserve
        push esi
        push edi

    ;// 1) reset the instance count for all

        dlist_GetHead hidcontrol, ebx, ebp
        TESTJMP ebx, ebx, jz all_done
        dlist_GetNext hidcontrol, ebx   ;// never set the first one
        TESTJMP ebx, ebx, jz all_done   ;// exit now if there is nothing to do
    push ebx    ;// save a couple instructions
        xor eax, eax
        .REPEAT
            mov [ebx].dwInstance, eax
            dlist_GetNext hidcontrol, ebx
        .UNTIL !ebx
    pop ebx

    ;// 2) scan for new instance counts and then build the formats

        .REPEAT

        ;// instance searching

            .IF ![ebx].dwInstance           ;// don't do extra scans
                mov edx, [ebx].dwPageUsage  ;// what we search for
                xor eax, eax                ;// counter
                dlist_GetNext hidcontrol,ebx,esi
                .IF esi
                    .REPEAT
                        .IF edx == [esi].dwPageUsage
                            inc eax
                            mov [esi].dwInstance, eax
                        .ENDIF
                        dlist_GetNext hidcontrol, esi
                    .UNTIL !esi
                .ENDIF
            .ENDIF

        ;// format building

        ;// load W's and the type, then compute R0 and dwRead

            ;// get the W's
            mov esi, [ebx].W0           ;// esi = W0
            mov edi, [ebx].W1           ;// edi = W1

            ;// load type and transfer the BE bit from MIDMASK_CONTAINER

            mov ecx, [ebx].dwFormat         ;// load the format from the control
            mov eax, [ebp].dwFlags          ;// load the flags from the device
            and ecx, NOT HIDDEVICE_IN_BE    ;// remove the BE bit
            and eax, HIDDEVICE_IN_BE        ;// remove all but the BE bit
            or ecx, eax                     ;// merge together
            mov [ebx].dwFormat, ecx         ;// store back in object

            ;// build the dwRead value, the R0

            mov edx, esi                    ;// W0
            shr edx, 3                      ;// divide by 8 to get byte address
            mov [ebx].dwRead, edx           ;// store back in object
            shl edx, 3                      ;// edx = R0

        ;// parse the dwFormat, possibly reset things that don't make sense

            .IF esi==edi
            ;// SINGLEBIT       ;// we don't care about signed unsigned
                                ;// and we've no special normalizer

                and [ebx].dwFormat, NOT HIDCONTROL_IN_SIGNED
                .IF ecx & HIDDEVICE_IN_BE
                    xor esi, 7      ;// S1 = W0 XOR 7
                .ENDIF
                mov [ebx].S1, esi
                .IF !(ecx & HIDCONTROL_OUT_FLOAT)
                    and [ebx].dwFormat, NOT HIDCONTROL_OUT_NEGATIVE
                .ENDIF

            .ELSE
            ;// MULTIBIT

                ;// esi = W0
                ;// edi = W1
                ;// edx = R0

                .IF ecx & HIDDEVICE_IN_BE
                    xchg esi, edi   ;// BE FORMAT   U0 = (W1 XOR 7) - R0
                    mov eax, 7      ;//             U1 = (W0 XOR 7) - R0
                    xor esi, eax    ;//             V0 = U0 XOR 18h
                    xor edi, eax    ;//             V1 = U1 XOR 18h
                    sub esi, edx
                    sub edi, edx
                    mov eax, 18h
                    xor esi, eax
                    xor edi, eax
                .ELSE   ;// HIDDEVICE_IN_LE
                    sub esi, edx    ;// LE FORMATS  V0 = W0 - R0
                    sub edi, edx    ;//             V1 = W1 - R0
                .ENDIF

                ;// esi = V0
                ;// edi = V1
                ;// edx = R0

                .IF ecx & HIDCONTROL_IN_SIGNED
                    mov eax, 31         ;//SIGNED       S1 = 31-V1
                    sub eax, edi        ;//             S2 = S1+V0
                    mov [ebx].S1, eax
                    add eax, esi
                    mov [ebx].S2, eax
                .ELSE   ;// HIDCONTROL_IN_UNSIGNED
                    mov [ebx].S1, esi   ;//UNSIGNED     S1 = V0
                    mov ecx, edi        ;//             S2 = (1 SHL (V1-V0+1))-1
                    sub ecx, esi
                    inc ecx
                    mov eax, 1
                    shl eax, cl
                    and [ebx].dwFormat, NOT HIDCONTROL_OUT_NEGATIVE
                    dec eax
                    mov [ebx].S2, eax
                    mov ecx, [ebx].dwFormat
                .ENDIF

                ;// esi undefined
                ;// edi undefined

                .IF ecx & HIDCONTROL_OUT_FLOAT
                    mov esi, [ebx].W0           ;// esi = W0
                    mov edi, [ebx].W1           ;// edi = W1
                    .IF ecx & HIDCONTROL_IN_SIGNED
                        mov eax, esi                ;// esi = W0
                        sub eax, edi    ;// W0-W1   ;// edi = W1
                        push eax                    ;// edx = R0
                    .ELSE   ;// HIDCONTROL_IN_UNSIGNED
                        mov eax, esi                ;// esi = W0
                        sub eax, edi    ;// W0-W1   ;// edi = W1
                        dec eax
                        push eax                    ;// edx = R0
                    .ENDIF
                    fild DWORD PTR [esp]
                    fld1
                    add esp, 4
                    fscale
                    .IF ecx & HIDCONTROL_OUT_NEGATIVE
                        fchs
                    .ENDIF
                    fstp [ebx].normalizer
                    fstp st
                .ELSE   ;// HIDCONTROL_OUT_INTEGER
                    and [ebx].dwFormat, NOT HIDCONTROL_OUT_NEGATIVE
                .ENDIF
            .ENDIF

            dlist_GetNext hidcontrol, ebx

        .UNTIL !ebx

    ;// now we are done
    all_done:   ;// turn the flag off and beat it

        and [ebp].dwFlags, NOT HIDDEVICE_FORMAT_CHANGED

        pop edi
        pop esi
        pop ebx
        retn

hiddevice_build_formats ENDP



;// PROLOGUE IS OFF !!
ASSUME_AND_ALIGN
hiddevice_convert_data PROC ;// PRIVATE to this file

    ;// applies the HIDCONTROL list to the current report data
    ;// will build the format values if nessesary
    ;// always puts report back into the read que

        ASSUME ebp:PTR HIDDEVICE    ;// passed by caller
        push esi
        push ebx
        push edi

        .IF [ebp].dwFlags & HIDDEVICE_FORMAT_CHANGED
            invoke hiddevice_build_formats
        .ENDIF

        clist_GetMRS hidreport, esi, ebp
        ;// always make sure we are really ready
        invoke WaitForSingleObject, [esi].overlapped.hEvent, 0
        CMPJMP eax, WAIT_OBJECT_0, jne convert_not_ready
        ;// we are good to go
        add esi, SIZEOF HIDREPORT
        ASSUME esi:PTR DWORD

        dlist_GetHead hidcontrol, ebx, ebp
        TESTJMP ebx, ebx, jz all_done   ;// exit now if nothing to do

        .REPEAT

            mov eax, [ebx].W0
            mov edi, [ebx].dwRead   ;// edi = R0 read position
            cmp eax, [ebx].W1
            mov ecx, [ebx].S1       ;// ecx = S1 load the first shift
            mov edx, [ebx].S2       ;// edx = S2 load the second shift

            .IF ZERO?
            ;// SINGLEBIT

                xor eax, eax        ;// clear
                bt [esi],ecx        ;// put the desired bit in the carry flag
                adc eax, eax        ;// add carry to eax
                .IF [ebx].dwFormat & HIDCONTROL_OUT_FLOAT
                    .IF [ebx].dwFormat & HIDCONTROL_OUT_NEGATIVE    ;// digital
                        .IF eax
                            fld1
                            fchs
                        .ELSE
                            fldz
                        .ENDIF
                    .ELSE ;// HIDCONTROL_OUT_POSITIVE   ;// bipolar
                        push eax
                        fild DWORD PTR [esp]
                        fadd st, st ;// *2
                        fld1
                        fsubr       ;// *2-1
                        add esp, 4
                    .ENDIF
                    fstp [ebx].dwValue
                .ELSE
                    mov [ebx].dwValue, eax
                .ENDIF

            .ELSE
            ;// MULTIBIT

                test [ebx].dwFormat, HIDDEVICE_IN_BE
                mov eax, [esi+edi]      ;// load the dword from report memort
                .IF !ZERO?
                    bswap eax           ;// xchg if big endian data
                .ENDIF

                .IF [ebx].dwFormat & HIDCONTROL_IN_SIGNED
                    shl eax,cl          ;// S1 shift put data into sign position
                    mov cl, dl          ;// copy the shift (clumsy)
                    sar eax,cl          ;// sign extend back to bottom
                .ELSE ;// HIDCONTROL_IN_UNSIGNED
                    shr eax, cl         ;// put lowest bit at zero
                    and eax, edx        ;// apply the mask
                .ENDIF

                .IF [ebx].dwFormat & HIDCONTROL_OUT_FLOAT
                    push eax
                    fild DWORD PTR [esp]
                    fmul [ebx].normalizer
                    add esp, 4
                    fstp [ebx].dwValue
                .ELSE ;// HIDCONTROL_OUT_INTEGER
                    mov [ebx].dwValue, eax
                .ENDIF

            .ENDIF

            dlist_GetNext hidcontrol,ebx

        .UNTIL !ebx

    ;// now we are done, put the report back in the que

        clist_GetMRS hidreport,esi,ebp
        mov [ebp].pLastReport, esi      ;// store just in case ... this is not the best way ?
        ;//OVERLAPPED
        xor eax, eax
        mov [esi].overlapped.dwInternal, eax
        mov [esi].overlapped.dwInternalHigh, eax
        mov [esi].overlapped.dwOffset,eax
        mov [esi].overlapped.dwOffsetHigh,eax
        invoke ResetEvent, [esi].overlapped.hEvent
        ;// then read file
        invoke ReadFile,
            [ebp].hHidDevice,
            ADDR [esi+SIZEOF HIDREPORT],
            [ebp].dwInputReportSize,
            ADDR [esi].dwBytesRead,
            esi
        ;// and advance the pointer
        clist_GetNext hidreport,esi
        clist_SetMRS hidreport,esi,ebp

    ;// and return sucess

        mov eax, ebx    ;// return value

    all_done:

        pop edi
        pop ebx
        pop esi

        retn

    ALIGN 4
    convert_not_ready:

        mov eax, 1
        jmp all_done

hiddevice_convert_data ENDP




;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////
;///                                                                public interface
;///
;///    INITIALZE   DESTROY


ASSUME_AND_ALIGN    ;// PROLOGUE IS OFF !!
hidobject_Initialize PROC STDCALL

        xor eax, eax
        or eax, hidobject_initialize_status
        jnz already_loaded

        push ebp
        push esi
        push edi
        push ebx

    ;// first: load the library and get the function pointers
    ;// fail if we can not

        mov esi, OFFSET hid_function_table  ;// input getter

    lib_loop:   xor ebx, ebx
                mov edi, esi                    ;// output value, must keep in sync
                lodsd                           ;// get the lib name
                TESTJMP eax, eax, jz load_done  ;// done if zero
                invoke LoadLibraryA, eax        ;// load the library
                TESTJMP eax, eax, jz cant_load  ;// fail if can't do
                stosd                           ;// keep in and out in sync
                mov ebx, eax
    func_loop:  lodsd                           ;// get the function name
                TESTJMP eax, eax, jz lib_loop   ;// back to top if done
                invoke GetProcAddress,ebx, eax  ;// get the proc address
                TESTJMP eax, eax, jz cant_load  ;// fail if can't do
                stosd                           ;// store the results
                jmp func_loop

    ALIGN 4
    cant_load:  or hidobject_initialize_status, -1
                xor eax, eax
                jmp all_done

    ALIGN 4
    load_done:

    ;// get the system guid for HID device

        sub esp, SIZEOF GUID            ;// make room on the stack
        invoke HidD_GetHidGuid, esp     ;// Call HidD_GetHidGuid
        mov edi, esp                    ;// point at the guid with edi

    ;// create a SP_DEVICE_INTERFACE_DATA on the stack

        mov ecx, ((SIZEOF SP_DEVICE_INTERFACE_DATA)-4)/4    ;// push this many dwords
        xor eax, eax
    G0: push eax
        loopd G0        ;// push until done, yes we could just sub esp, but this clears it too
        pushd SIZEOF SP_DEVICE_INTERFACE_DATA   ;// store the size

    ;// setup the iterator for getting all the device interfaces

        xor ebx, ebx    ;// in case we fail
        invoke SetupDiGetClassDevsA, edi, 0, 0, DIGCF_PRESENT OR DIGCF_DEVICEINTERFACE
        .IF eax == INVALID_HANDLE_VALUE
            or hidobject_initialize_status, -1
            invoke hidobject_Destroy
            jmp enum_devices_done
        .ENDIF
        mov ebx, eax    ;// ebx has the opened device iterator

    ;// call SetupDiEnumDeviceInterfaces repeatedly to retrieve all the available interface
    ;// information.

        or ebp, -1      ;// start counting at -1

    enum_devices_loop:

        inc ebp
        invoke SetupDiEnumDeviceInterfaces,ebx,0,edi,ebp,esp
        TESTJMP eax, eax, jz enum_devices_done  ;// exit loop if done

    ;// we have a device enumeration, get it's filename
    ;// ask for the size first

        mov ecx, esp        ;// point at device interface data
        pushd 0
        mov edx, esp
        invoke SetupDiGetDeviceInterfaceDetailA, ebx,ecx,0,0,edx,0
        pop esi             ;// esi = the size
        TESTJMP esi, esi, jz enum_devices_loop  ;// if no size, then fail

    ;// initialize a SP_DEVICE_INTERFACE_DETAIL_DATA_A buffer on the stack

        add esi, 31         ;// need to pad the size for WinXP
        mov edx, esp        ;// point at existing device info data
        and esi, NOT 3      ;// always dword align the size
        xor eax, eax        ;// we'll fill with zero of course
        mov ecx, esi        ;// ecx counts
        shr ecx, 2          ;// ecx counts dwords
        .REPEAT             ;// another push loop
        push eax            ;// there are faster ways
        .UNTILCXZ           ;// but this will do

    ;// call get detail interface to get device 'file' name

        mov ecx, esp            ;// point at the new buffer
        mov DWORD PTR [ecx], 5  ;// store the size of the header struct
        push eax                ;// store a size return value
        mov eax, esp            ;// point at the size
        invoke SetupDiGetDeviceInterfaceDetailA,ebx,edx,ecx,esi,eax,0
        pop edx                 ;// retrieve the read size

    ;// if we suceed, allocate a hid container for this

        .IF eax && edx ;// make sure we succeeded,
        ;// note that we check bocth the return value AND the number of bytes copied

            ;// we suceeded in getting the interface name
            ;// now we can call initialize to try to get the device

            lea eax, [esp+4]            ;// point at the name
            invoke hiddevice_Ctor, eax  ;// call the initialize function
            .IF eax                     ;// if we suceed, we store the results

                ASSUME eax:PTR HIDDEVICE
                dlist_InsertTail hiddevice,eax, edx

            .ENDIF

        .ENDIF

        add esp, esi            ;// clean up the stack

        jmp enum_devices_loop   ;// back to top of loop


    ALIGN 4
    enum_devices_done:  ;// we are done, clean up and go

        xor hidobject_initialize_status, 1  ;// turn on the flag, or perhaps make = -2

        .IF ebx
            invoke SetupDiDestroyDeviceInfoList, ebx    ;// ebx is now free
        .ENDIF

        add esp, SIZEOF SP_DEVICE_INTERFACE_DATA + SIZEOF GUID  ;// clean up the stack

    all_done:

        pop ebx
        pop edi
        pop esi
        pop ebp

        mov eax, dlist_Head(hiddevice)  ;// return value, first device

    already_loaded:

        retn


hidobject_Initialize ENDP



;// PROLOGUE IS OFF !!
ASSUME_AND_ALIGN
hidobject_Destroy PROC STDCALL

        push ebp

    D0: dlist_RemoveHead hiddevice,ebp
        jz D2
        invoke hiddevice_Close, ebp
    D1: dlist_RemoveHead hidcontrol,ecx,,ebp
        jz D0
        invoke GLOBALFREE, ecx
        jmp D1

    D2: pop ebp

        retn

hidobject_Destroy ENDP


;///    INITIALZE   DESTROY
;///
;///                                                                public interface
;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////



;///////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////
;///                                                                public interface
;///
;///    OPEN CLOSE
;///



;// PROLOGUE IS OFF !!
ASSUME_AND_ALIGN
hiddevice_Open PROC STDCALL pDevice:DWORD

        xchg ebp,[esp+4]
        DEBUG_IF <!!ebp>    ;// hey don't pass null pointers
        push esi
        push edi
        push ebx
        ASSUME ebp:PTR HIDDEVICE

    ;// don't open twice !!

        CMPJMP [ebp].hHidDevice, 0, jne already_opened

    ;// open the HidDevice

        invoke CreateFileA,
            ADDR [ebp].szFileName,
            GENERIC_READ OR GENERIC_WRITE,
            FILE_SHARE_READ OR FILE_SHARE_WRITE,
            0, OPEN_EXISTING, FILE_FLAG_OVERLAPPED, 0

        .IF eax == -1   ;// WinXP doesn't allow r/w access to keyboard and mouse
                        ;// this let's us at least see it
            invoke CreateFileA,
                ADDR [ebp].szFileName,
                0,
                FILE_SHARE_READ OR FILE_SHARE_WRITE,
                0, OPEN_EXISTING, FILE_FLAG_OVERLAPPED, 0
        .ENDIF

        CMPJMP eax, INVALID_HANDLE_VALUE, je cant_open_device
        mov [ebp].hHidDevice, eax

    ;// create the report que

        ;// determine the size

        mov ebx, [ebp].dwInputReportSize;// get the report size
        add ebx, SIZEOF HIDREPORT + 15  ;// must be able to read a dword at the highest position
        and ebx, NOT 3                  ;// dword align the size

        ;// allocate one big chunk

        mov edi, ebx    ;// size
        shl edi, 6      ;// 64 should be enough

        IFDEF DO_NOT_FREE_REPORT_MEMORY
        ECHO HEY, turn off DO_NOT_FREE_REPORT_MEMORY
            mov eax, [ebp].pReportMemory
            .IF !eax
                invoke GLOBALALLOC, GPTR, edi
                DEBUG_IF <!!eax>
                mov [ebp].pReportMemory, eax    ;// save so we can deallocate
            .ENDIF
        ELSE
            DEBUG_IF <[ebp].pReportMemory>
            invoke GLOBALALLOC, GPTR, edi
            DEBUG_IF <!!eax>
            mov [ebp].pReportMemory, eax    ;// save so we can deallocate
        ENDIF
        ASSUME esi:PTR HIDREPORT
        mov [ebp].pLastReport, eax      ;// set this
        mov esi, eax    ;// our iterator
        add edi, eax    ;// edi is when to stop

        ;// que them

        .REPEAT

            ;// create the event, manual reset, initialy unsignalled, no name
            invoke CreateEventA,0,1,0,0
            DEBUG_IF <!!eax>
            DEBUG_IF <[esi].overlapped.hEvent>
            mov [esi].overlapped.hEvent, eax
            ;// insert into que
            clist_Insert hidreport,esi,,ebp
            ;// call read file on it
            invoke ReadFile,
                [ebp].hHidDevice,
                ADDR [esi+SIZEOF HIDREPORT],
                [ebp].dwInputReportSize,
                ADDR [esi].dwBytesRead,
                esi
            ;// advance to next hid report
            add esi, ebx

        .UNTIL esi >= edi

        ;// and set the first report correctely

        mov eax, [ebp].pReportMemory
        clist_SetMRS hidreport, eax, ebp    ;// be sure to set the first report

        ;// return sucess

    already_opened:

        mov eax, [ebp].hHidDevice

    all_done:

        pop ebx
        pop edi
        pop esi
        mov ebp, [esp+4]
        retn 4  ;// STDCALL 1 arg

    ALIGN 4
    cant_open_device:

        xor eax, eax    ;// return zero
        jmp all_done

hiddevice_Open ENDP



;// PROLOGUE IS OFF !!
ASSUME_AND_ALIGN
hiddevice_Close PROC STDCALL pDevice:DWORD

        xchg ebp,[esp+4]
        DEBUG_IF <!!ebp>    ;// don't pass null pointers
        push esi
        ASSUME ebp:PTR HIDDEVICE

    ;// don't close twice !!

        CMPJMP [ebp].hHidDevice, 0, jz already_closed

    ;// cancel all pending reads

        invoke CancelIo, [ebp].hHidDevice
        DEBUG_IF <!!eax>
        ;// msdn sayeth:
        ;// The function does not cancel I/O operations issued for the file handle by other threads.
        ;// ... hmm doesn't appear to be true

    ;// free the hEvents

        clist_GetMRS hidreport,esi,ebp
        DEBUG_IF <!!esi>    ;// not supposed to be zero ?!!
        .REPEAT
            invoke CloseHandle, [esi].overlapped.hEvent
            DEBUG_IF <!!eax>
            clist_GetNext hidreport,esi
            DEBUG_IF <!!esi>    ;// not supposed to be zero ?!!
        .UNTIL esi == clist_MRS(hidreport,ebp)

    ;// free the report memory

        IFNDEF DO_NOT_FREE_REPORT_MEMORY
            invoke GLOBALFREE, [ebp].pReportMemory
            DEBUG_IF <eax>
            mov [ebp].pReportMemory, 0
            clist_SetMRS hidreport,0,ebp
            mov [ebp].pLastReport, 0    ;// make sure pLastReport is nulled too
        ENDIF ;// DO_NOT_FREE_REPORT_MEMORY

    ;// close the hid device

        invoke CloseHandle, [ebp].hHidDevice
        DEBUG_IF <!!eax>
        mov [ebp].hHidDevice, 0

    ;// that should do it !!

    already_closed:

        pop esi
        mov ebp, [esp+4]
        retn 4  ;// STDCALL 1 ARG

hiddevice_Close ENDP

;///
;///    OPEN CLOSE
;///
;///                                                                public interface
;///////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////



;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;///                                                            public interface
;///
;///    BUILD FORMATS               courtesy function
;///                                forces formats and instance counting


ASSUME_AND_ALIGN    ;// PROLOGUE IS OFF !!
hiddevice_BuildFormats PROC STDCALL, pDevice:DWORD

        xchg ebp, [esp+4]
        ASSUME ebp:PTR HIDDEVICE
        DEBUG_IF <!!ebp>    ;// don't pass null pointers

        .IF [ebp].dwFlags & HIDDEVICE_FORMAT_CHANGED
            invoke hiddevice_build_formats
        .ENDIF

        mov ebp, [esp+4]
        retn 4

hiddevice_BuildFormats ENDP


;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;///                                                        public interface
;///
;///    REPORT GETTING

ASSUME_AND_ALIGN    ;// PROLOGUE IS OFF !!
hiddevice_CountReports PROC STDCALL, pDevice:DWORD
    ;// returns the number available
    ;// (new data is still captured but is not reported until next call)

        xchg ebp, [esp+4]
        ASSUME ebp:PTR HIDDEVICE
        push edi
        push esi
        push ebx    ;// use ebx as a stop ptr so we don't worry about multi thread

        xor edi, edi    ;// return value

        .IF [ebp].hHidDevice    ;// if not opened, return zero

            DEBUG_IF <!![ebp].pReportMemory>    ;// supposed to exist !!
            clist_GetMRS hidreport,esi,ebp
            DEBUG_IF <!!esi>    ;// also supposed to exist
            mov ebx, esi
            .REPEAT
                invoke WaitForSingleObject,[esi].overlapped.hEvent,0
                .BREAK .IF eax  ;// done when object is not signaled
                inc edi ;// increase the count
                clist_GetNext hidreport,esi
            .UNTIL esi == ebx

            IFDEF VERIFY_THE_REPORT_COUNT
            ECHO HEY, turn off VERIFY_THE_REPORT_COUNT

                push edi
                clist_GetMRS hidreport,esi,ebp
                mov ebx, esi
                .REPEAT
                    invoke WaitForSingleObject,[esi].overlapped.hEvent,0
                    .IF !eax
                        inc edi ;// increase the count
                    .ENDIF
                    clist_GetNext hidreport,esi
                .UNTIL esi == ebx
                mov ecx, edi
                pop edi
                DEBUG_IF <ecx !!= edi>

            ENDIF

            IFDEF DISPLAY_THE_BUFFER_STATUS
            ECHO HEY, turn off DISPLAY_THE_BUFFER_STATUS
            ;// ok we have verified that the report mechanism is not correct
                push edi    ;// save

                sub esp, 128    ;// text buffer
                mov edi, esp

                clist_GetMRS hidreport,esi,ebp
                mov ebx, esi
                .REPEAT
                    invoke WaitForSingleObject,[esi].overlapped.hEvent,0
                    .IF !eax
                        mov eax, '+'
                    .ELSE
                        mov eax, '-'
                    .ENDIF
                    stosb
                    clist_GetNext hidreport,esi
                .UNTIL esi == ebx

                mov eax, 0A0Dh
                stosd
                invoke OutputDebugStringA,esp

                add esp, 128
                pop edi

            ENDIF

        .ENDIF

        mov eax, edi
        pop ebx
        pop esi
        pop edi
        mov ebp, [esp+4]
        retn 4  ;// STDCALL 1 ARG

hiddevice_CountReports ENDP


;// PROLOGUE IS OFF !!
ASSUME_AND_ALIGN
hiddevice_ReadNextReport PROC STDCALL, pDevice:DWORD

    ;// converts the next input report and updates the controls

        xchg ebp, [esp+4]

        ASSUME ebp:PTR HIDDEVICE
        DEBUG_IF <!![ebp].pReportMemory>    ;// supposed to exist !!

        invoke hiddevice_convert_data
        mov ebp, [esp+4]

        retn 4  ;// STDCALL 1 ARG

hiddevice_ReadNextReport ENDP

;///    REPORT GETTING
;///
;///                                                        public interface
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////


;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;///                                                    public interface
;///
;///    ENUMERATING

;// PROLOGUE IS OFF !!
ASSUME_AND_ALIGN
hidobject_EnumDevices   PROC STDCALL pObject:DWORD, pDevice:DWORD
                        ;//     00      04          08

    ;// if pDevice is zero, returns the first HIDDEVICE
    ;// if pDevice is not zero, returns the next device in the list

        mov eax, [esp+8]
        ASSUME eax:PTR HIDDEVICE
        .IF eax
            dlist_GetNext hiddevice,eax
        .ELSE
            mov eax, [esp+4]    ;// since pObject is really the head of the list
        .ENDIF

        retn 8  ;// STDCALL 2 ARGS

hidobject_EnumDevices   ENDP

;// PROLOGUE IS OFF !!
ASSUME_AND_ALIGN
hiddevice_EnumControls  PROC STDCALL pDevice:DWORD, pControl:DWORD

    ;// if pControl is zero, returns the first HIDCONTROL of said device
    ;// if pControl is not zero, returns the next control

        mov eax, [esp+8]
        ASSUME eax:PTR HIDCONTROL
        .IF eax
            dlist_GetNext hidcontrol,eax
        .ELSE
            mov eax, [esp+4]    ;// since pObject is really the head of the list
            ASSUME eax:PTR HIDDEVICE
            dlist_GetHead hidcontrol,eax,eax
        .ENDIF

        retn 8  ;// STDCALL 2 ARGS


hiddevice_EnumControls  ENDP

;///    ENUMERATING
;///
;///                                                    public interface
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////





;//////////////////////////////
;//                         ;//
;//                         ;//
                            ;//
        PROLOGUE_ON         ;// !!! IMPORTANT !!!
                            ;//
;//                         ;//
;//                         ;//
;//////////////////////////////


ASSUME_AND_ALIGN
END