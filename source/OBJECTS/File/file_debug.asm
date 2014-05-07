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
;//     file_debug.asm      we need a thread safe, fast way to debug this stuff
;//
OPTION CASEMAP:NONE
.586
.MODEL FLAT
IFDEF DEBUGBUILD

        .NOLIST
        INCLUDE <ABox.inc>
        INCLUDE <file_debug.inc>
        .LIST
        ;//.LISTALL
        ;//.LISTMACROALL


comment ~ /*


    we'll open a file, then print messages to it
    each message will be stamped with the time and the tread
    we'll have a critical section

timestamp thread_id  message args...

0123456701234567  01234567  MESSAGE

*/ comment ~







.DATA

    file_debug_crit_section CRITICAL_SECTION {}

    file_debug_hFile    dd  0

    file_debug_text     db  1024 DUP (?)
    sz_file_debug_name  db  'file_debug.txt',0
    ;//                     time stamp thread msg
    file_debug_format   db  '%8.8X%8.8X %8.8X ', 256 DUP (?)
    ;//                      01234567890123456
    ALIGN 4

.CODE

ASSUME_AND_ALIGN
file_debug_initialize PROC

    ;// open the file and initialize the critical section

        .IF !file_debug_hFile

            invoke CreateFileA, OFFSET sz_file_debug_name, GENERIC_WRITE, FILE_SHARE_READ, 0, CREATE_ALWAYS, 0, 0
            mov file_debug_hFile, eax
            invoke InitializeCriticalSection, OFFSET file_debug_crit_section

        .ENDIF

    ;// that's it

        ret

file_debug_initialize ENDP







ASSUME_AND_ALIGN
file_debug_message PROC ;// C pszFmt:DWORD num_args:DWORD args:VARARG
                    ;//   ret 4            8              C ...

    ;// we have the luxery of using all the registers if we want

    ;// do a time stamp and save to registers

        rdtsc
        mov edi, edx
        mov esi, eax

    ;// interlock access to prevent mixed up messages

        invoke EnterCriticalSection, OFFSET file_debug_crit_section

    ;// copy the format string, and push args on stack

        invoke lstrcpy, OFFSET file_debug_format[17], [esp+4]
        mov ebx, [esp+8]        ;// number of args
        .IF ebx                 ;// if ebx, append the format to our format
            mov ecx, ebx        ;// and push all the args in the correct order
            .REPEAT
                push [esp+08h+ebx*4]    ;// ofset=8 so 1 arg ends up in the correct spot
            .UNTILCXZ
        .ENDIF

    ;// get the thread

        invoke GetCurrentThreadId
        push eax

    ;// push the time stamp

        push esi
        push edi

    ;// and call wsprintf

        push OFFSET file_debug_format
        push OFFSET file_debug_text
        call wsprintfA

        lea esp, [esp+ebx*4+5*4]    ;// always our 5 args, then what ever ebx had

    ;// and write it to the output file

        invoke WriteFile, file_debug_hFile, OFFSET file_debug_text, eax, esp, 0

    ;// that should do it !

        invoke LeaveCriticalSection, OFFSET file_debug_crit_section

        retn    ;// c caller cleans up stack

file_debug_message ENDP



comment ~ /*
;// testing

    FILE_DEBUG_ON

    FILE_DEBUG_MESSAGE <"this is a test\n">


*/ comment ~









ASSUME_AND_ALIGN
ENDIF   ;//  DEBUGBUILD
END