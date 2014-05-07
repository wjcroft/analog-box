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
;//     stack.inc       simplified slist for stacks
;//
;//                     the stack list is never supposed to be empty
;//
IFNDEF _STACK_INCLUDED_
_STACK_INCLUDED_ EQU 1


comment ~ /*

    stack_Declare
    stack_Declare_external
    stack_Declare_internal

    stack_Push      inserts the head
    stack_Peek      retrieve the head, does not remove it
    stack_Pop       removes the head
    stack_PeekNext  retrieve the next item, does not pop remove it

*/ comment ~

;//////////////////////////////////////////////


    stack_Declare MACRO listName:req, listStruct:req, listNext:req, init:req

        listName&_stack_top     dd  OFFSET init         ;// allocate the head
        listName&_stack_next    TEXTEQU <listNext>      ;// define pNext
        listName&_stack_assume  TEXTEQU <listStruct>    ;// define the auto assume

        ENDM

        ;//                         list    structure   offset
        ;//                         name                to next
        ;// example:  stack_Declare oscAry, OSC_OBJECT, pNextI
        ;//

    stack_Declare_external MACRO listName:req, listStruct:req, listNext:req

        EXTERNDEF listName&_stack_top:DWORD
        listName&_stack_next     TEXTEQU <listNext>
        listName&_stack_assume TEXTEQU <listStruct>
        ENDM

    stack_Declare_internal MACRO listName:req, init:req

        IFNDEF listName&_stack_top
        .ERR <listName not defined externally.>
        ENDIF
        listName&_stack_top    dd  OFFSET init

        ENDM


;//////////////////////////////////////////////


    stack_Push MACRO name:req, reg:req, regTemp:=<eax>

        ;// inserts a new head item
        ;// returns old head in regTemp

        ;// assumes both if regPrev is not the default

        .ERRIDNI <reg>, <regTemp>
        IFNDEF name&_stack_assume
%       .ERR <name not declared.>
        ENDIF

        mov regTemp, name&_stack_top            ;// get the current head
        mov name&_stack_top, reg                ;// set the new head
        mov [reg].name&_stack_next, regTemp ;//set our next pointer

    ENDM


;//////////////////////////////////////////////

    stack_Peek MACRO name:req, reg:req

        ;// simply returns the name_head_stack value in reg
        ;// assumes the register

        IFNDEF name&_stack_assume
%       .ERR <name not declared.>
        ENDIF

        mov reg, name&_stack_top
        DEBUG_IF <!!reg>    ;// not supposed to be empty

%       ASSUME reg:PTR name&_stack_assume

        ENDM

;//////////////////////////////////////////////


    stack_Pop MACRO name:req, reg:req, reg2:=<eax>

        ;// pops the stack
        ;// returns old head in reg
        ;// return new head in reg2

        IFNDEF name&_stack_assume
%       .ERR <name not declared.>
        ENDIF

        mov reg, name&_stack_top            ;// get the current top (will be the old top)
        DEBUG_IF <!!reg>                    ;// not supposed to be empty
%       ASSUME reg:PTR name&_stack_assume
        mov reg2, [reg].name&_stack_next    ;// get our next pointer
        mov name&_stack_top, reg2           ;// set the new head
        DEBUG_IF <!!reg2>                   ;// not supposed to be empty
        ASSUME reg2:PTR name&_stack_assume
        ENDM


;//////////////////////////////////////////////

    stack_PeekNext MACRO name:req, reg:req, reg2

        ;// peeks at the next item
        ;// use for traversing the stack without changing it
        ;// reg must be assumed
        ;// will send to reg2 if required

        IFNDEF name&_stack_assume
%       .ERR <name not declared.>
        ENDIF

        IFNB <reg2>

            mov reg2, [reg].name&_stack_next    ;// get our next pointer
%           ASSUME reg2:PTR name&_stack_assume

        ELSE

            mov reg, [reg].name&_stack_next ;// get our next pointer

        ENDIF

        ENDM


;//////////////////////////////////////////////


ENDIF ;// _STACK_INCLUDED_