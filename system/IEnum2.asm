;// This file is part of the Analog Box open source project
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
;//         added arg check in IENUM2_Next ppFetched
;//
;//##////////////////////////////////////////////////////////////////////////
;//
;// IEnum2.asm      attempt to build a generic enumerator for com
;//

OPTION CASEMAP:NONE
.586
.MODEL FLAT

    .NOLIST
    INCLUDE <utility.inc>
    INCLUDE <win32A_imp.inc>
    INCLUDE <com.inc>
    INCLUDE <IEnum2.inc>
    .LIST

    ;// one of these must be on

        ;// DEBUG_MESSAGE_ON
        DEBUG_MESSAGE_OFF


;///////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////
;///
;///
;///    IEnum2
;///

.DATA

IEnum2_vtable   LABEL DWORD

        dd  IEnum2_QueryInterface
        dd  IEnum2_AddRef
        dd  IEnum2_Release
        dd  IEnum2_Next
        dd  IEnum2_Skip
        dd  IEnum2_Reset
        dd  IEnum2_Clone

.CODE

ASSUME_AND_ALIGN
IEnum2_ctor PROC STDCALL USES ebx ppItemList:DWORD, pCtor:DWORD, pAddRef:DWORD

    ;// returns a new ienum interface in edx
    ;// return sucess or fail in eax

        DEBUG_MESSAGE <IEnum2_ctor>

        DEBUG_IF < pCtor && pAddRef >   ;// !! can't do both !!

    ;// allocate our memory

        invoke CoTaskMemAlloc, SIZEOF IENUM2
        test eax, eax
        jz no_mem

    ;// setup our struct

        mov ebx, eax
        ASSUME ebx:PTR IENUM2

        mov eax, ppItemList
        mov ecx, pCtor
        mov edx, pAddRef

        mov [ebx].vtable, OFFSET IEnum2_vtable

        mov [ebx].ref_count, 1

        mov [ebx].pIterator, eax
        mov [ebx].ppItemList, eax
        mov [ebx].pCtor, ecx
        mov [ebx].pAddRef, edx

    ;// set the return value

        mov edx, ebx    ;// interface is returned in edx
        xor eax, eax    ;// eax is sucess

    ;// that's it
    all_done:

        ret

    ;// CoTaskMemAlloc failed
    no_mem:

        mov eax, E_OUTOFMEMORY
        xor edx, edx

        jmp all_done

IEnum2_ctor ENDP


ASSUME_AND_ALIGN
IEnum2_QueryInterface PROC ;// STDCALL pThis, refid, presults
                            ;// 0       4       8     C

    DEBUG_MESSAGE <IEnum2_QueryInterface>

        ;// ABOX240 -- need to force clearing of caller's presults
        ;// some interfaces don't follow the rules

        xor eax, eax
        mov edx, [esp+0Ch]
        mov [edx], eax

        mov eax, E_NOINTERFACE
        retn 12

IEnum2_QueryInterface ENDP

ASSUME_AND_ALIGN
IEnum2_AddRef PROC ;// STDCALL pThis

    DEBUG_MESSAGE <IEnum2_AddRef>

        com_GetObject [esp+4], ecx, IENUM2
        inc [ecx].ref_count
        mov eax, [ecx].ref_count
        retn 4

IEnum2_AddRef ENDP

ASSUME_AND_ALIGN
IEnum2_Release PROC ;// STDCALL pThis

    DEBUG_MESSAGE <IEnum2_Release>

        com_GetObject [esp+4], ecx, IENUM2
        dec [ecx].ref_count
        mov eax, [ecx].ref_count
        jz time_to_deallocate

    all_done:

        retn 4

    time_to_deallocate:

        DEBUG_MESSAGE <IEnum2_Release__Deallocating>

    ;// free the memory

        invoke CoTaskMemFree, [esp+4]
        xor eax, eax
        jmp all_done

IEnum2_Release ENDP

ASSUME_AND_ALIGN
IEnum2_Next PROC ;// STDCALL pThis, num_items, ppItems, pFetched
                 ;//    00    04       08        0C       10

        DEBUG_MESSAGE <IEnum2_Next___Enter>

    ;// STDCALL pThis, num_items, ppItems, pFetched
    ;//    00     04       08        0C       10

        xchg ebp, [esp+04h]         ;// ebp = this
        ASSUME ebp:PTR IENUM2
        xchg edi, [esp+0Ch]         ;// edi = destination

        push ebx
        push esi

    ;// esi ebx STDCALL ebp, num_items, edi,pFetched
    ;// 00  04  08      0C   10         14  18

        st_num_items    TEXTEQU <(DWORD PTR [esp+10h])>
        st_pfetched     TEXTEQU <(DWORD PTR [esp+18h])>
        
        xor ebx, ebx            ;// ebx is num fetched
        mov esi, [ebp].pIterator;// get the iterator
        ASSUME esi:PTR DWORD
        xor edx, edx            ;// must be zero
    T0: lodsd                   ;// get the source arg
        test eax, eax           ;// check for zero
        je return_fail          ;// fail if ran off the end
        or edx, [ebp].pCtor     ;// check for some other ctor
        jz T1                   ;// check if we get memory from else where
        push eax                ;// push the source arg
        call edx                ;// call the allocater
        xor edx, edx            ;// and this must be zero
    T1: stosd                   ;// store the results and advance the output counter
        or edx, [ebp].pAddRef   ;// check if we've an addref
        jz T2                   ;// don't add ref if not set
        push eax                ;// push the this pointer
        call edx                ;// call add ref
        xor edx, edx            ;// must be zero
    T2: inc ebx                 ;// increase the fetched count
        dec st_num_items        ;// one less to get
        mov [ebp].pIterator, esi;// store the current iterator
        jnz T0                  ;// back to top of loop if still items to fetch

        xor eax, eax            ;// we're done and we succeeded

    all_done:

        ;// set ppFetched if it exists, edx here is zero for all paths
        ORJMP edx, st_pfetched, jz @F   ;// load+testforzero,jump if zero
        mov [edx], ebx                  ;// store it
    @@:
        
        ;// now recover the args and beat it
        
        pop esi
        pop ebx
        mov ebp, [esp+04h]          ;// ebp = this
        mov edi, [esp+0Ch]          ;// edi = destination

        DEBUG_MESSAGE <IEnum2_Next___Exit>

        retn 10h    ;// STDCALL 4 args

    return_fail:

        mov eax, S_FALSE
        jmp all_done

IEnum2_Next ENDP




ASSUME_AND_ALIGN
IEnum2_Skip PROC ;// STDCALL pThis, num_items
                 ;//    00    04      08

        DEBUG_MESSAGE <IEnum2_Skip>

        com_GetObject [esp+4], edx, IENUM2
        mov ecx, [esp+8]    ;// get num_items to skip
        push esi
        mov esi, [edx].pIterator
    T0: lodsd
        test eax, eax
        jz all_done
        mov [edx].pIterator, esi
        loop T0
    all_done:
        pop esi
        xor eax, eax
        retn 8  ;// STDCALL 2 args

IEnum2_Skip  ENDP

ASSUME_AND_ALIGN
IEnum2_Reset    PROC ;// STDCALL pThis

    DEBUG_MESSAGE <IEnum2_Reset>

    com_GetObject [esp+4], ecx, IENUM2
    mov edx, [ecx].ppItemList
    xor eax, eax    ;// get reseter and return value
    mov [ecx].pIterator, edx ;// reset the iterator
    retn 4

IEnum2_Reset ENDP

ASSUME_AND_ALIGN
IEnum2_Clone    PROC ;// STDCALL pThis, ppNewEnum
                    ;//     00  04      08

    DEBUG_MESSAGE <IEnum2_Clone>

    xchg [esp+4], ebx
    ASSUME ebx:PTR IENUM2
    invoke IEnum2_ctor, [ebx].ppItemList, [ebx].pCtor, [ebx].pAddRef
    ASSUME eax:PTR IENUM2
    mov edx, [esp+8]            ;// get the destination
    mov ecx, [ebx].pIterator    ;// get the current iterator we copy from
    mov [edx], eax              ;// store new ienum2 in destination
    mov [eax].pIterator, ecx    ;// store the current iterator in the new ienum2
    mov ebx, [esp+4]            ;// retreive stored ebx
    xor eax, eax                ;// we suceeded
    retn 8  ;// STDCALL 2 ARGS

IEnum2_Clone    ENDP









ASSUME_AND_ALIGN

END






