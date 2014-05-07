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
;//     2.42 Jul 11, 2011 AJT
;//         Initial port to GPLv3
;//
;//##////////////////////////////////////////////////////////////////////////
;//
;// win32A_file.inc		macros for win32 file manipulation
;//
IFNDEF WIN32A_FILE_INCLUDED
WIN32A_FILE_INCLUDED EQU 1
comment ~ /*

    REQUIRED INCLUDES

        win32a_imp.inc

    TOC

    file_Open		name	mode
    file_Close		hFile
    file_GetSize	hFile
    file_GetSizeEx	hFile

    file_Seek		hFile	position direction:=<BEGIN>
    file_GetPosition hFile
    file_Read		hFile	dest len
    file_Write		hFile	src len
    file_Flush      hFile

    file_Load		pszName [allocater]

    file_Delete		pszName
    file_Move		exist_name	new_name
    file_Copy		exist_name	new_name	no_over_write


*/ comment ~

file_Open MACRO name:req, mode:req

    ;// returns HANDLE in eax
    ;// always check for HANDLE==INVALID_HANDLE_VALUE

    pushd	0	;//CreateFileA.hTemplateFile:DWORD
    pushd	0	;//CreateFileA.dwFlagsAndAttributes:DWORD,

    IFIDN <mode>,<READONLY>			;// fails if doesn't exist

        pushd	OPEN_EXISTING						;//CreateFileA.dwCreationDistribution:DWORD,
        pushd	0									;//CreateFileA.pSecurityAttributes:DWORD,
        pushd	FILE_SHARE_READ OR FILE_SHARE_WRITE ;//CreateFileA.dwShareMode:DWORD,
        pushd	GENERIC_READ						;//CreateFileA.dwDesiredAccess:DWORD,

    ELSEIFIDN <mode>,<WRITEONLY>	;// truncates if exists

        pushd	CREATE_ALWAYS						;//CreateFileA.dwCreationDistribution:DWORD,
        pushd	0									;//CreateFileA.pSecurityAttributes:DWORD,
        pushd	FILE_SHARE_READ OR FILE_SHARE_WRITE ;//CreateFileA.dwShareMode:DWORD,
        pushd	GENERIC_WRITE						;//CreateFileA.dwDesiredAccess:DWORD,

    ELSEIFIDN <mode>,<VERIFY>		;// just check if it exists

        pushd	OPEN_EXISTING						;//CreateFileA.dwCreationDistribution:DWORD,
        pushd	0									;//CreateFileA.pSecurityAttributes:DWORD,
        pushd	FILE_SHARE_READ OR FILE_SHARE_WRITE ;//CreateFileA.dwShareMode:DWORD,
        pushd	0									;//CreateFileA.dwDesiredAccess:DWORD,

    ELSEIFIDN <mode>,<APPEND>

        pushd	OPEN_ALWAYS
        pushd	0									;//CreateFileA.pSecurityAttributes:DWORD,
        pushd	FILE_SHARE_READ OR FILE_SHARE_WRITE ;//CreateFileA.dwShareMode:DWORD,
        pushd	GENERIC_WRITE						;//CreateFileA.dwDesiredAccess:DWORD,

    ELSE
        .ERR <mode must be READONLY, WRITEONLY, VERIFY or APPEND>
    ENDIF

    comment ~ /*
    IF (( OPATTR(name)) AND 10h )	;// register expression
        pushd name					;// CreateFileA.pFileName:DWORD,
    ELSE							;// better be a data label
        pushd OFFSET name			;// CreateFileA.pFileName:DWORD,
    ENDIF
    */ comment ~
    IF (( OPATTR(name)) EQ 2Ah )
        pushd OFFSET name			;// CreateFileA.pFileName:DWORD,	better be a data label
    ELSE
        pushd name					;// CreateFileA.pFileName:DWORD,	better be valid
    ENDIF
    call CreateFileA

    IFIDN <mode>,<APPEND>
        push eax
        invoke SetFilePointer, eax, 0, 0, FILE_END
        pop eax
    ENDIF

    ENDM


file_Close MACRO hFile:req

    invoke CloseHandle, hFile

    ENDM


;// this is only valid for small files
file_GetSize MACRO hFile:req, reg

    invoke GetFileSize, hFile, 0
    IFNB <reg>
    mov reg, eax
    ENDIF

    ENDM

;// this will return the QWORD size
;// returns in edx:eax
file_GetSizeEx MACRO hFile:req

    sub esp, 4
    invoke GetFileSize, hFile, esp
    pop edx

    ENDM


file_Seek MACRO hFile:req, position:req, direction:=<BEGIN>

    invoke SetFilePointer, hFile, position, 0, FILE_&direction

    ENDM

file_GetPosition MACRO hFile:req

    ;// returns current poistion in eax

    invoke SetFilePointer, hFile, 0, 0, FILE_CURRENT

    ENDM

file_Read MACRO hFile:req, dest:req, len:req, size_reg

    IFB <size_reg>

        ;// might not be safe for some operating systems
        invoke ReadFile, hFile, dest, len, esp, 0

    ELSE

        IFIDNI <hFile>,<eax>
        .ERR <eax cannot be the file handle>
        ENDIF
        IFIDNI <dest>,<eax>
        .ERR <eax cannot be destination ptr>
        ENDIF
        IFIDNI <len>,<eax>
        .ERR <eax cannot be length register>
        ENDIF

        ;// same as above but returns bytes read in reg

        push size_reg
        mov eax, esp	;// len != eax
        pushd 0
        push eax
        push len
        push dest
        push hFile
        call ReadFile
        pop size_reg

    ENDIF


    ENDM


file_Write MACRO hFile:req, src:req, len:req

    ;// might not be safe for some operating systems

    invoke WriteFile, hFile, src, len, esp, 0

    ENDM
    
file_Flush MACRO hFile:req
    invoke FlushFileBuffers, hFile
    ENDM


;/////////////////////////////////////////////////////

file_Write_byte MACRO hFile:req, val:req


    IF		(( OPATTR(val)) AND 4 )	;// immediate
        pushd val
    ELSEIF	(( OPATTR(val)) AND 16 );// register
        sub esp, 4
        mov (BYTE PTR [esp]), val
    ENDIF

    IFIDN <eax>,<hFile>
        mov edx, esp
        invoke WriteFile, hFile, edx, 1, esp, 0
    ELSE
        mov eax, esp
        invoke WriteFile, hFile, eax, 1, esp, 0
    ENDIF
    add esp, 4

    ENDM


;/////////////////////////////////////////////////////

file_Write_dword MACRO hFile:req, val:req

        pushd val

    IFIDN <eax>,<hFile>
        mov edx, esp
        invoke WriteFile, hFile, edx, 4, esp, 0
    ELSE
        mov eax, esp
        invoke WriteFile, hFile, eax, 4, esp, 0
    ENDIF
    add esp, 4

    ENDM


file_Read_dword MACRO hFile:req, reg:=<eax>

        lea eax, [esp-4]
        sub esp, 4
        invoke ReadFile, hFile, eax, 4, esp, 0
        pop reg

    ENDM



;/////////////////////////////////////////////////////


file_Load	MACRO name:req, alloc:=<GLOBALALLOC>

    ;// opens, allocates, loads, closes, quadruple terminates
    ;// return memory pointer and file size
    ;//
    ;// be sure to check eax for errors
    ;//
    ;// returns eax as mem or error
    ;// 		ecx as file size
    ;//			we allocate one more so we can terminate
    ;//
    ;// if eax == 0, then ecx = size that could not be allocated
    ;// if eax == -1, then file could not be opened

    file_Open name, READONLY
    .IF eax != INVALID_HANDLE_VALUE
        push eax					;// stack = hFile
        file_GetSize eax
        push eax					;// stack = size hFile
        add eax, 7					;// allocate one more dword
        and eax, NOT 3				;// should be dword aligned
        invoke alloc, GMEM_FIXED, eax
        .IF eax
            push eax				;// pMem	size	fFile
            mov edx, [esp+4]		;// 00		04		08
            mov ecx, [esp+8]
            file_Read ecx, eax, edx
            push DWORD PTR [esp+8]
            call CloseHandle
            pop eax					;// pMem
            pop ecx					;// size
            mov DWORD PTR [eax+ecx], 0	;// terminate
        .ELSE						;// stack = size hFile
            push DWORD PTR [esp+4]	;//
            call CloseHandle		;// stack = size hFile
            xor eax, eax			;// must return zero
            pop ecx					;// retrieve the size
        .ENDIF

        ;// stack = hFile
        add esp, 4
    .ENDIF

    ENDM









;/////////////////////////////////////////////////////


file_Delete MACRO name:REQ


    IF (( OPATTR(name)) EQ 2Ah )
        pushd OFFSET name			;// better be a data label
    ELSE
        pushd name					;// better be valid
    ENDIF
    call DeleteFileA

    ENDM


file_Move MACRO exist_name:REQ, new_name:REQ


    IF (( OPATTR(new_name)) EQ 2Ah )
        pushd OFFSET new_name			;// better be a data label
    ELSE
        pushd new_name					;// better be valid
    ENDIF
    IF (( OPATTR(exist_name)) EQ 2Ah )
        pushd OFFSET exist_name			;// better be a data label
    ELSE
        pushd exist_name				;// better be valid
    ENDIF
    call MoveFileA

    ENDM


file_Copy MACRO exist_name:REQ, new_name:REQ, no_over_write:=<0>

    pushd no_over_write
    IF (( OPATTR(new_name)) EQ 2Ah )
        pushd OFFSET new_name			;// better be a data label
    ELSE
        pushd new_name					;// better be valid
    ENDIF
    IF (( OPATTR(exist_name)) EQ 2Ah )
        pushd OFFSET exist_name			;// better be a data label
    ELSE
        pushd exist_name				;// better be valid
    ENDIF
    call CopyFileA

    ENDM




ENDIF ;// WIN32A_FILE_INCLUDED