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
;// hardware_debug.inc      macros for hardware debugging
;//                         in general: leave these off


    H_LOG_TRACE_STATUS = 1      ;// OFF
    ;// H_LOG_TRACE_STATUS = 2      ;// ON



;////////////////////////////////////////////////////////////////////



IF H_LOG_TRACE_STATUS EQ 2
ECHO <hardware_debug.inc    HLOG IS ON !!!!!! TURN IT OFF>
ENDIF



;////////////////////////////////////////////////////////////////////



    ;// use H_LOG_OPEN to set these
    ;// which ever source file opens the log, owns the data
    EXTERNDEF   hLog:DWORD
    EXTERNDEF   sz_log_buffer:BYTE
    EXTERNDEF   sz_hLogName:BYTE
    EXTERNDEF   sz_log_0_arg:BYTE
    EXTERNDEF   sz_log_1_arg:BYTE
    EXTERNDEF   sz_log_2_arg:BYTE
    EXTERNDEF   sz_log_3_arg:BYTE
    EXTERNDEF   sz_log_4_arg:BYTE
    EXTERNDEF   log_critsection:CRITICAL_SECTION

    ;///////////////////////////////////////////////////////

    H_LOG_OPEN MACRO

        IFDEF DEBUGBUILD

            IF H_LOG_TRACE_STATUS EQ 2

                .DATA
                hLog dd 0
                sz_log_buffer   db  256 DUP (0)
            ;// sz_hLogName     db  'c:\windows\desktop\hlog.txt',0
                sz_hLogName     db  'hlog.txt',0
                sz_log_0_arg    db  '%8.8X:%8.8X %s',0dh,0ah,0
                sz_log_1_arg    db  '%8.8X:%8.8X %s %8.8X',0dh,0ah,0
                sz_log_2_arg    db  '%8.8X:%8.8X %s %8.8X %8.8X',0dh,0ah,0
                sz_log_3_arg    db  '%8.8X:%8.8X %s %8.8X %8.8X %8.8X',0dh,0ah,0
                sz_log_4_arg    db  '%8.8X:%8.8X %s %8.8X %8.8X %8.8X %8.8X',0dh,0ah,0
                ALIGN 4
                log_critsection CRITICAL_SECTION {}
                .CODE

                pushad
                pushf

                invoke CreateFileA,
                    OFFSET sz_hLogName,
                    GENERIC_WRITE,
                    FILE_SHARE_READ OR FILE_SHARE_WRITE,
                    0,
                    CREATE_ALWAYS,
                    0,0

                mov hLog, eax

                invoke InitializeCriticalSection, OFFSET log_critsection

                popf
                popad

            ENDIF

        ENDIF

        ENDM

    ;///////////////////////////////////////////////////////

    H_LOG_CLOSE MACRO

        IFDEF DEBUGBUILD

            IF H_LOG_TRACE_STATUS EQ 2

                pushad
                pushf

                .IF hLog
                    invoke CloseHandle, hLog
                    mov hLog,0
                    invoke DeleteCriticalSection, OFFSET log_critsection
                .ENDIF

                popf
                popad

            ENDIF
        ENDIF

        ENDM

    ;///////////////////////////////////////////////////////

    H_LOG_CODE MACRO source:REQ

        LOCAL count

        ;// optionally emits code

        IFDEF DEBUGBUILD
        IF H_LOG_TRACE_STATUS EQ 2
        source
        ENDIF
        ENDIF
        ENDM

    ;///////////////////////////////////////////////////////

    H_LOG_TRACE MACRO msg:req, args:VARARG

        LOCAL count,rev,ar,szfmt

        IFDEF DEBUGBUILD
        IF H_LOG_TRACE_STATUS EQ 2

                ;// build the msg name and text
                debug_trace_msg_name CATSTR <_>, <msg>

                debug_trace_msg CATSTR <'>, <msg>, <'>

                ;// declare it as data

                .DATA

                debug_trace_msg_name db debug_trace_msg,0
                ALIGN 4

                ;// display a message

                .CODE

                pushad
                pushf

                ;// count and reverse the args
                rev TEXTEQU <>
                count=0
            IFNB <args>
            %   FOR ar,<args>
                    count = count + 1
                    rev CATSTR <ar>,<,>,rev
                ENDM
                rev SUBSTR rev,1,@SizeStr(%rev)-1
                rev CATSTR <!<>,rev,<!>>

                IF count GT 4
                .ERR <TOO MANY ARGUMENTS !!!!!>
                ENDIF


                ;// push the args on the stack
            %   FOR ar,rev
                pushd ar
                ENDM
            ENDIF

                ;// do the time stamp and format string

                szfmt CATSTR <sz_log_>,%count,<_arg>

                push OFFSET debug_trace_msg_name
                rdtsc
                push eax
                push edx
                pushd OFFSET szfmt
                pushd OFFSET sz_log_buffer
                invoke EnterCriticalSection, OFFSET log_critsection
                call wsprintfA
                add esp, (count+5)*4    ;// wsprintf buf, &fmt, eax, edx, message ....
                invoke WriteFile, hLog, OFFSET sz_log_buffer, eax, esp, 0
                invoke LeaveCriticalSection, OFFSET log_critsection

                popf
                popad

        ENDIF
        ENDIF

        ENDM


