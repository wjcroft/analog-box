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
;//     file_debug.inc          thread safe debuggingmessages
;//                             for the file object

IFNDEF _FILE_DEBUG_INCLUDED_
_FILE_DEBUG_INCLUDED_ EQU 1

    IFDEF DEBUGBUILD

        file_debug_message PROTO    ;// C pszFmt:DWORD num_args:DWORD args:VARARG
        file_debug_initialize PROTO ;// C pszFmt:DWORD num_args:DWORD args:VARARG

    ENDIF


    FILE_DEBUG_ON   MACRO
        @MESSAGE <debug messaging is ON>
        FILE_DEBUG_IS_ON EQU 2
        file_debug_format_number = 1

        ENDM

    FILE_DEBUG_OFF  MACRO

        FILE_DEBUG_IS_ON EQU 1

        ENDM

    FILE_DEBUG_INITIALIZE MACRO

        IFDEF DEBUGBUILD

            IFNDEF FILE_DEBUG_IS_ON
            .ERR <use FILE_DEBUG_ON or FILE_DEBUG_OFF>
            ENDIF

            IF FILE_DEBUG_IS_ON EQ 2

                invoke file_debug_initialize

            ENDIF

        ENDIF

        ENDM


    FILE_DEBUG_MESSAGE MACRO fmt:REQ, args:VARARG

        LOCAL format
        LOCAL format_name
        LOCAL got_backslash
        LOCAL double_quote
        LOCAL single_quote
        LOCAL arg_index
        LOCAL arg_count

        IFDEF DEBUGBUILD

            IFNDEF FILE_DEBUG_IS_ON
            .ERR <use FILE_DEBUG_ON or FILE_DEBUG_OFF>
            ENDIF

            IF FILE_DEBUG_IS_ON EQ 2
            ;// build a format string, input must be quoted !!
                format TEXTEQU <db >
                got_backslash = 0
                double_quote = 0
                single_quote = 0    ;// true if we are in single quote
                have_char = 0
                FORC char, <fmt>
                    IF double_quote EQ 0
                        IFIDN <char>, <">
                            double_quote = 1
                        ENDIF
                    ELSE
                        IFIDN <char>, <">
                            double_quote = 2
                        ELSE
                            IF got_backslash EQ 1
                                IFIDN <char>,<n>
                                ;// we've received \n so we define descrete bytes
                                    ;// if in quote, exit quote
                                    IF single_quote NE 0
                                        format CATSTR format, <'>
                                        single_quote = 0
                                        have_char = 1
                                    ENDIF
                                    ;// if previous chars, append a comma
                                    IF have_char NE 0
                                        format CATSTR format, <,>
                                    ENDIF
                                    format CATSTR format, <0dh,0ah>
                                    have_char = 1       ;// we now have characters
                                ELSE
                                ;// unknown escape sequence, treat as literal
                                    ;// if not in quote, enter quote
                                    IF single_quote EQ 0
                                        ;// if previous chars, append a comma
                                        IF have_char NE 0
                                            format CATSTR format, <,>
                                        ENDIF
                                        format CATSTR format, <'>
                                        single_quote = 1
                                    ENDIF
                                    format CATSTR format, <\>, char
                                    have_char = 1       ;// we now have characters
                                ENDIF
                                got_backslash = 0   ;// turn the tag off
                            ELSEIFIDN <char>,<\>    ;// we have an escape sequence char
                                got_backslash = 1   ;// print next go around
                            ELSE
                            ;// normal text
                                ;// if not in single quote, enter single quote
                                IF single_quote EQ 0
                                    ;// if previous chars, append a comma
                                    IF have_char NE 0
                                        format CATSTR format, <,>
                                    ENDIF
                                    format CATSTR format, <'>
                                    single_quote = 1
                                    have_char = 1       ;// we now have characters
                                ENDIF
                                ;// append the char
                                format CATSTR format,<char>
                                have_char = 1
                            ENDIF
                        ENDIF
                    ENDIF
                ENDM
                IF single_quote NE 0
                    format CATSTR format, <'>
                    have_char = 1
                ENDIF
                IF have_char NE 0   ;// make sure we have previous characters
                    format CATSTR format, <,>
                ENDIF
                format CATSTR format, <0>

                ;// build a new name

                format_name CATSTR <file_debug_format_>,%file_debug_format_number

                file_debug_format_number = file_debug_format_number + 1

                ;// and finally, declare as data
                .DATA
                format_name format
                ALIGN 4
                .CODE

            ;// count the args

                arg_count = 0
                FOR arg, <args>
                    arg_count = arg_count + 1
                ENDM

            ;// call the central debug function

                pushfd                      ;// save the flags so we can use this anywhere
                pushad

            ;// must push args in reverse order

                arg_index = arg_count

                REPEAT arg_count

                    pushd @ArgI(arg_index, args)
                    arg_index = arg_index-1

                ENDM

                pushd arg_count
                push OFFSET format_name     ;// format string
                call file_debug_message     ;// call the function
                add esp, 8 + arg_count * 4  ;// clean up the stack
                popad                       ;// restore registers
                popfd

            ;// and that should do it

            ENDIF   ;// FILE_DEBUG_IS_ON EQ 2

        ENDIF


    ENDM

ENDIF   ;// _FILE_DEBUG_INCLUDED_


