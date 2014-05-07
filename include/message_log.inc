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
;//     message_log.inc             debug/dev helpers
;//                                 in general: leave these off

IFNDEF _MESSAGE_LOG_INCLUDED_
_MESSAGE_LOG_INCLUDED_ EQU 1


    MESSAGE_LOG_OFF MACRO
        USE_MESSAGE_LOG EQU 1
        ENDM

    MESSAGE_LOG_ON MACRO
        USE_MESSAGE_LOG EQU 2
        ECHO MESSAGE_LOG is on !!!!!!
        ENDM



    MESSAGE_LOG_MSG MACRO pMsg:REQ, indent
        LOCAL deb
        LOCAL INDENTER
        .ERRNDEF USE_MESSAGE_LOG, <must use MESSAGE_LOG_ON or MESSAGE_LOG_OFF>
        IFIDN <indent>,<INDENT>
            INDENTER EQU 1
        ELSEIFIDN <indent>,<UNINDENT>
            INDENTER EQU -1
        ELSE
            .ERRNB <indent>,<use INDENT, UNINDENT or leave blank>
            INDENTER EQU 0
        ENDIF
        IFDEF DEBUGBUILD
            IF USE_MESSAGE_LOG EQ 1
            ELSEIF USE_MESSAGE_LOG EQ 2
                invoke message_log_msg, pMsg, INDENTER
            ENDIF
        ENDIF
        ENDM


    MESSAGE_LOG_PROC MACRO pMsg:REQ, indent
        LOCAL deb
        LOCAL INDENTER
        .ERRNDEF USE_MESSAGE_LOG, <must use MESSAGE_LOG_ON or MESSAGE_LOG_OFF>
        IFIDN <indent>,<INDENT>
            INDENTER EQU 1
        ELSEIFIDN <indent>,<UNINDENT>
            INDENTER EQU -1
        ELSE
            .ERRNB <indent>,<use INDENT, UNINDENT or leave blank>
            INDENTER EQU 0
        ENDIF
        IFDEF DEBUGBUILD
            IF USE_MESSAGE_LOG EQ 1
            ELSEIF USE_MESSAGE_LOG EQ 2
                IFIDN <pMsg>,<STACK_4>
                    lea eax, [esp+4]
                    invoke message_log_proc, eax, INDENTER
                ELSE
                    invoke message_log_proc, pMsg, INDENTER
                ENDIF
            ENDIF
        ENDIF
        ENDM


    MESSAGE_LOG_PRINT_1 MACRO str_name, val:REQ, str_string:REQ, indent
        LOCAL deb, INDENTER
        LOCAL deb
        LOCAL INDENTER
        IFIDN <indent>,<INDENT>
            INDENTER EQU 1
        ELSEIFIDN <indent>,<UNINDENT>
            INDENTER EQU -1
        ELSE
            .ERRNB <indent>,<use INDENT, UNINDENT or leave blank>
            INDENTER EQU 0
        ENDIF
        IFDEF DEBUGBUILD
            IF USE_MESSAGE_LOG EQ 1
            ELSEIF USE_MESSAGE_LOG EQ 2
                .DATA
                str_name db str_string,0
                ALIGN 4
                .CODE
                invoke message_log_print_1, OFFSET str_name, val, INDENTER
            ENDIF
        ENDIF
        ENDM

    MESSAGE_LOG_PRINT_2 MACRO str_name, val1:REQ, val2:REQ, str_string:REQ, indent
        LOCAL deb
        LOCAL INDENTER
        .ERRNDEF USE_MESSAGE_LOG, <must use MESSAGE_LOG_ON or MESSAGE_LOG_OFF>
        IFIDN <indent>,<INDENT>
            INDENTER EQU 1
        ELSEIFIDN <indent>,<UNINDENT>
            INDENTER EQU -1
        ELSE
            .ERRNB <indent>,<use INDENT, UNINDENT or leave blank>
            INDENTER EQU 0
        ENDIF
        IFDEF DEBUGBUILD
            IF USE_MESSAGE_LOG EQ 1
            ELSEIF USE_MESSAGE_LOG EQ 2
                .DATA
                str_name db str_string,0
                ALIGN 4
                .CODE
                invoke message_log_print_2, OFFSET str_name, val1, val2, INDENTER
            ENDIF
        ENDIF
        ENDM

    MESSAGE_LOG_PRINT_3 MACRO str_name, val1:REQ, val2:REQ, val3:REQ, str_string:REQ, indent
        LOCAL deb
        LOCAL INDENTER
        .ERRNDEF USE_MESSAGE_LOG, <must use MESSAGE_LOG_ON or MESSAGE_LOG_OFF>
        IFIDN <indent>,<INDENT>
            INDENTER EQU 1
        ELSEIFIDN <indent>,<UNINDENT>
            INDENTER EQU -1
        ELSE
            .ERRNB <indent>,<use INDENT, UNINDENT or leave blank>
            INDENTER EQU 0
        ENDIF
        IFDEF DEBUGBUILD
            IF USE_MESSAGE_LOG EQ 1
            ELSEIF USE_MESSAGE_LOG EQ 2
                .DATA
                str_name db str_string,0
                ALIGN 4
                .CODE
                invoke message_log_print_3, OFFSET str_name, val1,val2,val3, INDENTER
            ENDIF
        ENDIF
        ENDM

    MESSAGE_LOG_TEXT MACRO str:REQ, indent
        LOCAL deb
        LOCAL INDENTER
        .ERRNDEF USE_MESSAGE_LOG, <must use MESSAGE_LOG_ON or MESSAGE_LOG_OFF>
        IFIDN <indent>,<INDENT>
            INDENTER EQU 1
        ELSEIFIDN <indent>,<UNINDENT>
            INDENTER EQU -1
        ELSE
            .ERRNB <indent>,<use INDENT, UNINDENT or leave blank>
            INDENTER EQU 0
        ENDIF
        IFDEF DEBUGBUILD
            IF USE_MESSAGE_LOG EQ 1
            ELSEIF USE_MESSAGE_LOG EQ 2
                deb CATSTR <">,<str>,<">
                .DATA
                str db deb,0
                ALIGN 4
                .CODE
                invoke message_log_text, OFFSET str, INDENTER
            ENDIF
        ENDIF
        ENDM





    IFDEF DEBUGBUILD

        message_log_msg PROTO STDCALL  pTagMsg:DWORD, indent:DWORD
        ;// dumps contents of tagMSG

        message_log_proc PROTO STDCALL pMsgArgs:DWORD, indent:DWORD
        ;// dumps contents of call stack

        message_log_text PROTO STDCALL pString:DWORD, indent:DWORD
        ;// use for no param messages, can browse the message in the log with F12

        message_log_print_1 PROTO STDCALL pString:DWORD, value:DWORD, indent:DWORD
        ;// use for 1 param message

        message_log_print_2 PROTO STDCALL pString:DWORD, val1:DWORD, val2:DWORD, indent:DWORD
        ;// use for 2 param message

        message_log_print_3 PROTO STDCALL pString:DWORD, val1:DWORD, val2:DWORD, val3:DWORD, indent:DWORD
        ;// use for 3 param message

    ENDIF





ENDIF ;// _MESSAGE_LOG_INCLUDED_