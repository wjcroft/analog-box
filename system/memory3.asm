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
;//         -- adjused USE_MEMORY_DEBUG_REPORT code
;//
;//##////////////////////////////////////////////////////////////////////////
;//
;//     memory3.asm
;//
OPTION CASEMAP:NONE
.586
.MODEL FLAT


    .NOLIST

        INCLUDE <_malloc.inc>
        INCLUDE <utility.inc>

    .LISTALL
    ;// .LISTMACROALL


comment ~ /*

    use these functions instead of GlobalAlloc and the like

    benefits:

        32 byte aligned memory
        leak tracking
        corruption checking

    REQUIRED INCLUDES

        MUST INCLUDE utility.inc
        MUST INCLUDE slist3.inc


    to use the debug features

        DEBUGBUILD EQU 1


    memory_Alloc flags, size

        works just like GlobalAlloc

    memory_Free ptr

        works just like GlobalFree

    memory_Resize ptr size

        returns a new pointer with a new size

    memory_Expand ptr size

        returns a new pointer with a new size
        copies the old memory

    MEMORY_SIZE(ptr)

        macro to get the size of the block

*/ comment ~



.DATA

        memory_GlobalSize   dd  0 ;// counter for global memory allocated

;/////////////////////////////////////////////////////////////////////////
;//
;//
;//     DEBUG support

    IFDEF DEBUGBUILD

        slist_Declare memory_Global

    ;// USE_MEMORY_DEBUG_REPORT EQU 1   ;// undefine to turn off

        IFDEF USE_MEMORY_DEBUG_REPORT

            ECHO memory3.asm DEBUG REPORTING is ON !!!!

            .NOLIST
            INCLUDE win32A_imp.inc
            INCLUDE win32A_file.inc
            .NOLIST

            sz_memory_debug db 'memory_debug.txt',0
            ALIGN 4
            hMemoryDebug    dd  0

        ENDIF

    ENDIF





;////////////////////////////////////////////////////////////////////
;//
;//
;//     memory_Alloc, flags, size
;//
comment ~ /*

    fact: win32.GlobalAlloc will return an 4 byte aligned value
    wish: we want to return a 32byte aligned value
    fact: we are always working in dwords

there are then eight cases to account for


R E L E A S E

        ----    ptr returned by GlobalAlloc
        ====    ptr returned by memory_Alloc
        bbbb    MEMORY BLOCK
        -10-    offset required to get from pointer to memblock


        00      04      08      0C      10      14      18      1C

00      ----
04              ----
08                      ----
0C                              ----    -08-    -04-    -00-
10      -18-    -14-    -10-    -0C-    ----
14                                              ----
18      bbbb    bbbb    bbbb    bbbb    bbbb    bbbb    bbbb
1C      bbbb    bbbb    bbbb    bbbb    bbbb    bbbb    bbbb    ----
20      ====    ====    ====    ====    ====    ====    ====
24
28
2C                                                              -1C-
30
34
38                                                              bbbb
3C                                                              bbbb
40                                                              ====

    largest offset      1C
    + sizeof header   + 08
    = size to add     = 24





D E B U G

        ----    ptr returned by GlobalAlloc
        ====    ptr returned by memory_Alloc
        bbbb    MEMORY BLOCK
        -10-    offset required to get from pointer to memblock


        00      04      08      0C      10      14      18      1C

00      bbbb
04      bbbb    ----
08      bbbb            ----            -10-    -0C-    -08-    -04-
0C      bbbb                    ----
10      bbbb    -1C-    -18-            ----
14      bbbb                    -14-            ----
18      bbbb                                            ----
1C      bbbb                                                    ----
20      ====    bbbb    bbbb    bbbb    bbbb    bbbb    bbbb    bbbb
24              bbbb    bbbb    bbbb    bbbb    bbbb    bbbb    bbbb
28              bbbb    bbbb    bbbb    bbbb    bbbb    bbbb    bbbb
2C      -00-    bbbb    bbbb    bbbb    bbbb    bbbb    bbbb    bbbb
30              bbbb    bbbb    bbbb    bbbb    bbbb    bbbb    bbbb
34              bbbb    bbbb    bbbb    bbbb    bbbb    bbbb    bbbb
38              bbbb    bbbb    bbbb    bbbb    bbbb    bbbb    bbbb
3C              bbbb    bbbb    bbbb    bbbb    bbbb    bbbb    bbbb
40              ====    ====    ====    ====    ====    ====    ====


    largest offset      1C
    + sizeof header   + 20
    = size to add     = 3C


*/ comment ~



IFDEF DEBUGBUILD

    ALIGN 16
    memory_offset_table dd 00h,1Ch,18h,14h,10h,0Ch,08h,04h
    MEMORY_EXTRA_SIZE EQU 3Ch

ELSE

    ALIGN 16
    memory_offset_table dd 18h,14h,10h,0Ch,08h,04h,00h,1Ch
    MEMORY_EXTRA_SIZE EQU 24h

ENDIF










.CODE


IFDEF DEBUGBUILD

ASSUME_AND_ALIGN
memory_VerifyBlock PROC

    ;// return eax as the difference between checksum and the current checksum
    ;// so zero is un corrupted memory

    ASSUME ebx:PTR MEMORY_BLOCK

        push esi

        mov eax, [ebx].dwChecksum
        xor edx, edx

        mov esi, [ebx].pOrig
        DEBUG_IF <!!esi>    ;// trashed !!!
        mov ecx, [ebx].dwLeadSize
    J0: dec ecx
        js J1
        mov dl, [esi+ecx]
        sub eax, edx
        jmp J0
    J1: mov esi, [ebx].pTailBytes
        mov ecx, [ebx].dwTailSize
    J2: dec ecx
        js J3
        mov dl, [esi+ecx]
        sub eax, edx
        jmp J2
    J3: pop esi

    ret

memory_VerifyBlock ENDP




PROLOGUE_OFF
ASSUME_AND_ALIGN
memory_Verify   PROC STDCALL pMem:DWORD

    xchg ebx, [esp+4]
    sub ebx, SIZEOF MEMORY_BLOCK
    invoke memory_VerifyBlock
    mov ebx, [esp+4]

    retn 4

memory_Verify   ENDP
PROLOGUE_ON

ASSUME_AND_ALIGN
memory_VerifyAll PROC

    pushad

    slist_GetHead memory_Global, ebx
    .WHILE ebx
        invoke memory_VerifyBlock
        DEBUG_IF <eax>  ;// corrupted memory !!!!
        slist_GetNext memory_Global, ebx
    .ENDW

    popad

    ret

memory_VerifyAll ENDP



ENDIF   ;// DEBUG BUILD








PROLOGUE_OFF
ASSUME_AND_ALIGN
memory_Alloc PROC STDCALL dwFlags:DWORD, dwSize:DWORD

    ;// STACK
    ;// ret flg siz
    ;// 00  04  08

        st_flags TEXTEQU <(DWORD PTR [esp+4])>
        st_size  TEXTEQU <(DWORD PTR [esp+8])>

    ;// allocate the memory

        xchg ebx, st_flags  ;// save ebx and load the flags
        mov eax, st_size
        DEBUG_IF <eax&3>    ;// not supposed to allocate odd sized blocks
        DEBUG_IF <!!eax>    ;// requested zero bytes !!!
        add eax, MEMORY_EXTRA_SIZE
        invoke _GlobalAlloc, ebx, eax
        DEBUG_IF <eax & 3>  ;// not supposed to happen
        DEBUG_IF <!!eax>    ;// could not allocate !!!

    ;// determine the actual ptr

        mov ebx, eax    ;// ebx is the returned ptr
        mov ecx, eax    ;// ecx hold the origonal ptr for a moment
        and eax, 1Ch    ;// turn into a table offset (already dword aligned)
        add ebx, memory_offset_table[eax]   ;// ebx is now an aligned memory block

        ASSUME ebx:PTR MEMORY_BLOCK

    ;// fill in the memory block

        mov edx, st_size        ;// getthe requested size
        mov [ebx].pOrig, ecx    ;// save orig pointer
        mov [ebx].dwReqSize, edx;// save requested size

    ;// get the actual and add to our counter

        invoke _GlobalSize, [ebx].pOrig
        add memory_GlobalSize, eax

    ;// do the debug stuff

        IFDEF DEBUGBUILD

        ;// save the caller address

            mov edx, [esp]
            mov [ebx].pCaller, edx

        ;// determine the lead and tail lengths and pointers

            ;// dwLeadSize = ptr - pOrig
            ;// dwTailSize = TotSize - ReqSize - block size - lead size
            ;// pTail = ptr + block size + req size

            mov ecx, ebx
            sub ecx, [ebx].pOrig
            mov [ebx].dwLeadSize, ecx

            mov edx, eax                ;// eax is still the actual size
            sub edx, [ebx].dwReqSize
            sub edx, SIZEOF MEMORY_BLOCK
            sub edx, ecx
            mov [ebx].dwTailSize, edx

            mov ecx, ebx
            add ecx, SIZEOF MEMORY_BLOCK
            add ecx, [ebx].dwReqSize
            mov [ebx].pTailBytes, ecx

        ;// build the first checksum

            push esi

            xor eax, eax
            xor edx, edx

            mov esi, [ebx].pOrig
            mov ecx, [ebx].dwLeadSize
        J0: dec ecx
            js J1
            mov dl, [esi+ecx]
            add eax, edx
            jmp J0
        J1: mov esi, [ebx].pTailBytes
            mov ecx, [ebx].dwTailSize
        J2: dec ecx
            js J3
            mov dl, [esi+ecx]
            add eax, edx
            jmp J2
        J3: pop esi
            mov [ebx].dwChecksum, eax

        ;// reqister in global memory list

            slist_InsertHead memory_Global, ebx

        ;// report

            IFDEF USE_MEMORY_DEBUG_REPORT

                ;// ebx has the frame
                .DATA
                fmt_alloc_report db '%8.8X:%8.8X alloc frame:%8.8X caller:%8.8X size:%8.8X',0dh,0ah,0
                ALIGN 4
                .CODE
                .IF !hMemoryDebug
                    file_Open sz_memory_debug, WRITEONLY
                    mov hMemoryDebug, eax
                .ENDIF
                rdtsc
                sub esp, 128
                mov ecx, esp    ;// out buffer
                invoke wsprintfA,ecx, OFFSET fmt_alloc_report, edx,eax,ebx, [ebx].pCaller, [ebx].dwReqSize
                mov ecx, esp
                file_Write hMemoryDebug,ecx,eax
                file_Flush hMemoryDebug
                add esp, 128

            ENDIF

        ENDIF

    ;// do the returned pointer

        lea eax, [ebx+SIZEOF MEMORY_BLOCK]
        mov ebx, st_flags   ;// restore ebx

    ;// one last test

        DEBUG_IF <eax & 1Fh>    ;// supposed to be 32 byte aligned !!!

    ;// clean up and split

        retn 8

        st_flags TEXTEQU <>
        st_size  TEXTEQU <>

memory_Alloc ENDP
PROLOGUE_ON


PROLOGUE_OFF
ASSUME_AND_ALIGN
memory_Free PROC STDCALL dwPtr:DWORD        ;// stdcall ptr:DWORD

        st_ptr TEXTEQU <(DWORD PTR [esp+4])>

    ;// get the origonal block ptr

        xchg ebx, st_ptr
        sub ebx, SIZEOF MEMORY_BLOCK
        ASSUME ebx:PTR MEMORY_BLOCK

        IFDEF DEBUGBUILD

            IFDEF USE_MEMORY_DEBUG_REPORT

                ;// ebx has the frame
                .DATA
                fmt_free__report db '%8.8X:%8.8X free  frame:%8.8X caller:%8.8X',0dh,0ah,0
                ALIGN 4
                .CODE
                .IF !hMemoryDebug
                    file_Open sz_memory_debug, APPEND
                    mov hMemoryDebug, eax
                .ENDIF
                rdtsc
                sub esp, 128
                mov ecx, esp    ;// out buffer
                invoke wsprintfA,ecx,OFFSET fmt_free__report,edx,eax,ebx,(DWORD PTR [esp+128])
                mov ecx, esp
                file_Write hMemoryDebug,ecx,eax
                add esp, 128

            ENDIF

        ;// verify the checksum

            invoke memory_VerifyBlock
            DEBUG_IF <eax>  ;// memory is corrupted !!!

        ;// remove from list

            slist_Remove memory_Global, ebx

        ENDIF   ;// DEBUGBUILD

    ;// adjust the global size

        invoke _GlobalSize, [ebx].pOrig
        sub memory_GlobalSize, eax

    ;// free the memory

        invoke _GlobalFree, [ebx].pOrig
        DEBUG_IF <eax>  ;// ,GET_ERROR  ;// couldn't free

    ;// clean up and go

        mov ebx, st_ptr
        retn 4
        st_ptr TEXTEQU <>


memory_Free ENDP
PROLOGUE_ON




PROLOGUE_OFF
ASSUME_AND_ALIGN
memory_Expand PROC STDCALL dwPtr:DWORD, dwSize:DWORD

    ;// returns a new pointer in eax
    ;// DOES copy data

    st_ptr  TEXTEQU <(DWORD PTR [esp+4])>
    st_size TEXTEQU <(DWORD PTR [esp+8])>

    xchg ebx, st_size               ;// get the desired size
    DEBUG_IF < ebx&3 >  ;// size is supposed to be dword aligned !!
    invoke memory_Alloc, GPTR, ebx  ;// allocate the new block

    xchg esi, st_ptr    ;// store esi and load data source
    push eax            ;// store our return value
    push edi            ;// store edi
    mov ebx, MEMORY_SIZE(esi)   ;// need the size of the old block
    DEBUG_IF <ebx&3>    ;// supposed to be dword aligned !!
    mov edi, eax        ;// load the destination
    mov ecx, ebx        ;// load the count
    push esi        ;// store the passed ptr
    shr ecx, 2      ;// mov dwords
    rep movsd

    call memory_Free    ;// pointer already pushed
    pop edi             ;// retrieve edi
    pop eax             ;// retrieve the return value
    mov esi, st_ptr     ;// retrieve esi
    mov ebx, st_size    ;// retrieve ebx

    IFDEF DEBUGBUILD

    mov edx, [esp]      ;// get who called this
    mov (MEMORY_BLOCK PTR [eax-SIZEOF MEMORY_BLOCK]).pCaller, edx

    ENDIF

    retn 8

    st_ptr  TEXTEQU <>
    st_size TEXTEQU <>

memory_Expand ENDP
PROLOGUE_ON




PROLOGUE_OFF
ASSUME_AND_ALIGN
memory_Resize PROC STDCALL dwPtr:DWORD, dwSize:DWORD

    ;// returns a new pointer
    ;// does NOT copy data

    st_ptr  TEXTEQU <(DWORD PTR [esp+4])>
    st_size TEXTEQU <(DWORD PTR [esp+8])>

    invoke memory_Free, st_ptr
    mov st_ptr, GPTR
    jmp memory_Alloc

    st_ptr  TEXTEQU <>
    st_size TEXTEQU <>

memory_Resize ENDP
PROLOGUE_ON




ASSUME_AND_ALIGN

END
