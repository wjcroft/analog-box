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
;//////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////
;///
;///                    defines a project level GLOBALALLOC
;///     _malloc.inc    and GLOBALFREE, also implements memory3.inc
;///
IFNDEF __MALLOC_INCLUDED_
__MALLOC_INCLUDED_ EQU 1



;///////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////
;///
;///
;///    GLOBALALLOC         define ONE of
;///    GLOBALFREE          ALLOC1 --> GLOBALALLOC = _GlobalAlloc
;///                        ALLOC2 --> GLOBALALLOC = memory_Alloc

IFDEF ALLOC1
    .ERRDEF ALLOC2,<multiple ALLOCx defintions>
    .ERRDEF ALLOC3,<multiple ALLOCx defintions>
    GLOBALALLOC TEXTEQU <_GlobalAlloc>
    GLOBALFREE  TEXTEQU <_GlobalFree>
ELSEIFDEF ALLOC2
    .ERRDEF ALLOC3,<multiple ALLOCx defintions>
    GLOBALALLOC TEXTEQU <memory_Alloc>
    GLOBALFREE  TEXTEQU <memory_Free>
ELSEIFDEF ALLOC3
    GLOBALALLOC TEXTEQU <.ERR use either _GlobalAlloc or memory_Alloc>
    GLOBALFREE  TEXTEQU <.ERR use either _GlobalFree or memory_Free>
ELSE
    .ERR <ALLOCx must be defined at project level !!!!>
ENDIF

;///    GLOBALFREE
;///    GLOBALALLOC
;///
;///
;///////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////


;///////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////
;///
;///
;///    Win32 alloc


        INCLUDELIB kernel32

        _imp__GlobalAlloc PROTO STDCALL dwFlags:DWORD, dwSize:DWORD
        _ptr__GlobalAlloc TYPEDEF PROTO STDCALL dwFlags:DWORD, dwSize:DWORD
        _typ__GlobalAlloc TYPEDEF PTR _ptr__GlobalAlloc
        _GlobalAlloc TEXTEQU <(_typ__GlobalAlloc PTR _imp__GlobalAlloc )>
        ;// returns handle to allocated memory

            ;// Global Memory Flags
            GMEM_FIXED          EQU 0000h
            GMEM_MOVEABLE       EQU 0002h
            GMEM_NOCOMPACT      EQU 0010h
            GMEM_NODISCARD      EQU 0020h
            GMEM_ZEROINIT       EQU 0040h
            GMEM_MODIFY         EQU 0080h
            GMEM_DISCARDABLE    EQU 0100h
            GMEM_NOT_BANKED     EQU 1000h
            GMEM_SHARE          EQU 2000h
            GMEM_DDESHARE       EQU 2000h
            GMEM_NOTIFY         EQU 4000h
            GMEM_VALID_FLAGS    EQU 7F72h
            GMEM_INVALID_HANDLE EQU 8000h

            GPTR                EQU GMEM_FIXED OR GMEM_ZEROINIT

        _imp__GlobalFree PROTO STDCALL hMem:DWORD
        _ptr__GlobalFree TYPEDEF PROTO STDCALL hMem:DWORD
        _typ__GlobalFree TYPEDEF PTR _ptr__GlobalFree
        _GlobalFree TEXTEQU <(_typ__GlobalFree PTR _imp__GlobalFree )>
        ;// must have allocated hMem with _GlobalAlloc
        ;// return's null for sucess

        _imp__GlobalRealloc PROTO STDCALL hMem:DWORD, dwBytes:DWORD, dwFlags:DWORD
        _ptr__GlobalRealloc TYPEDEF PROTO STDCALL hMem:DWORD, dwBytes:DWORD, dwFlags:DWORD
        _typ__GlobalRealloc TYPEDEF PTR _ptr__GlobalRealloc
        _GlobalRealloc TEXTEQU <(_typ__GlobalRealloc PTR _imp__GlobalRealloc )>
        ;// must have allocated hMem with _GlobalAlloc
        ;// returns handle to reallocated memory



        _imp__GlobalSize PROTO STDCALL hMem:DWORD
        _ptr__GlobalSize TYPEDEF PROTO STDCALL hMem:DWORD
        _typ__GlobalSize TYPEDEF PTR _ptr__GlobalSize
        _GlobalSize TEXTEQU <(_typ__GlobalSize PTR _imp__GlobalSize )>
        ;// must have allocated hMem with _GlobalAlloc
        ;// returns actual size of memory, or zero for error

        _imp__GlobalLock PROTO STDCALL hMem:DWORD
        _ptr__GlobalLock TYPEDEF PROTO STDCALL hMem:DWORD
        _typ__GlobalLock TYPEDEF PTR _ptr__GlobalLock
        _GlobalLock TEXTEQU <(_typ__GlobalLock PTR _imp__GlobalLock )>
        ;// must have allocated hMem with _GlobalAlloc
        ;//return pointer to memory

        _imp__GlobalUnlock PROTO STDCALL hMem:DWORD
        _ptr__GlobalUnlock TYPEDEF PROTO STDCALL hMem:DWORD
        _typ__GlobalUnlock TYPEDEF PTR _ptr__GlobalUnlock
        _GlobalUnlock TEXTEQU <(_typ__GlobalUnlock PTR _imp__GlobalUnlock )>
        ;// must have allocated hMem with _GlobalAlloc
        ;// returns non zero if still locked,
        ;// zero for success or error


;///    Win32 global alloc
;///
;///
;///////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////




;///////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////
;///
;///
;///    memory3 allocate


    memory_Alloc    PROTO STDCALL dwFlags:DWORD, dwSize:DWORD   ;// allocate memory
    memory_Free     PROTO STDCALL dwPtr:DWORD                   ;// free memory
    memory_Expand   PROTO STDCALL dwPtr:DWORD, dwSize:DWORD     ;// resize and copy
    memory_Resize   PROTO STDCALL dwPtr:DWORD, dwSize:DWORD     ;// resize and destroy


    IFDEF DEBUGBUILD

        INCLUDE <slist3.inc>

        MEMORY_BLOCK STRUCT

            slist_Declare_link memory_Global, MEMORY_BLOCK  ;// pointer to next block       (memory leaks)
            pCaller     dd  0   ;// address of calling function (memory leaks)
            pTailBytes  dd  0   ;// ptr to the tail of the block
            dwTailSize  dd  0   ;// number of bytes in the tail
            dwChecksum  dd  0   ;// sum of lead and tail bytes
            dwLeadSize  dd  0   ;// size of the lead of the block

            pOrig       dd  0   ;// pointer to origonal block
            dwReqSize   dd  0   ;// requested size of the block

        MEMORY_BLOCK ENDS

        slist_Declare_external memory_Global

        memory_VerifyAll    PROTO
        memory_Verify       PROTO STDCALL pMem:DWORD
        memory_VerifyBlock  PROTO

    ELSE

        MEMORY_BLOCK    STRUCT
            pOrig       dd  0
            dwReqSize   dd  0
        MEMORY_BLOCK    ENDS

    ENDIF


    EXTERNDEF memory_GlobalSize:DWORD ;// counter for global memory allocated

    MEMORY_SIZE MACRO reg:req
        EXITM <(DWORD PTR [reg-4])>
        ENDM



;///    memory3 allocate
;///
;///
;///////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////






ENDIF ;// __MALLOC_INCLUDED_