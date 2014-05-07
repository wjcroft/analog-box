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
;//                  macro implemetation of a remote doubly linked list
;//     dlist3.inc   remote means that these macros do not rely on any
;//                  specific block of memory but instead rely on a passed pointer

IFNDEF _DLIST3_INCLUDED_
_DLIST3_INCLUDED_ EQU 1


;// TOC
;//
;// dlist_Declare_link  MACRO listName:REQ, listStruc:REQ
;// dlist_Declare_alias_link MACRO newList:req, oldList:req
;// dlist_Declare MACRO listName:req
;// dlist_Declare_external MACRO listName:req
;// dlist_Declare_indirected MACRO listName:req
;//
;// dlist_Head  MACRO name:req, indirected
;// dlist_Tail  MACRO name:req, indirected
;// dlist_Next  MACRO name:req, reg:req
;// dlist_Prev  MACRO name:req, reg:req
;//
;// dlist_CopyPointer MACRO  name:req, fReg:req, tReg:req
;// dlist_ResetNode MACRO name:req, reg:req, clear
;//
;// dlist_GetHead MACRO name:req, regNow:req, indirected
;// dlist_OrGetHead MACRO name:req, regNow:req, indirected
;// dlist_GetTail MACRO name:req, regNow:req, indirected
;// dlist_OrGetTail MACRO name:req, regNow:req, indirected
;// dlist_GetNext MACRO name:req, regNow:req, regNew
;// dlist_OrGetNext MACRO name:req, regNow:req, regNew
;// dlist_GetPrev MACRO name:req, regNow:req, regNew
;// dlist_OrGetPrev MACRO name:req, regNow:req, regNew
;//
;// dlist_IfMember_jump MACRO name:req, reg:req, jumper:req, indirected
;// dlist_IfNotMember_jump MACRO name:req, reg:req, jumper:req, indirected
;//
;// dlist_InsertHead MACRO name:req, regNew:req, regTemp:=<eax>, indirected
;// dlist_InsertTail MACRO name:req, regNew:req, regTemp:=<eax>, indirected
;// dlist_InsertBefore MACRO name:req, regNew:req, regNow:req, regTemp:=<eax>, indirected
;// dlist_InsertAfter MACRO name:req, regNew:req, regNow:req, regTemp:=<eax>, indirected
;//
;// dlist_RemoveHead MACRO name:req, regOld:req, regNew:=<eax>, indirected
;// dlist_RemoveTail MACRO name:req, regOld:req, regNew:=<eax>, indirected
;// dlist_Remove MACRO name:req, regNow:req, regTemp:=<eax>, indirected
;// dlist_Remove_noheadtailclear MACRO name:req, regNow:req, regTemp:=<eax>, indirected
;//
;// dlist_MoveToHead MACRO name:req, regNow:req, regTemp:=<eax>, indirected
;// dlist_SwapNext MACRO name:req, rB:req, rA:=<eax>, rC:=<edx>, ind
;// dlist_SwapPrev MACRO name:req, rC:req, rA:=<eax>, rB:=<edx>, ind
;// dlist_SplitAfter MACRO name:req, reg_R:req, reg_N:req, reg_t:=<eax>, indirected
;// dlist_SplitBefore MACRO name:req, reg_R:req, reg_P:=<edx>, reg_t:=<eax>, indirected
;// dlist_MergeAfter MACRO name:req, reg_N:req, reg_R:req, reg_b:=<edx>, reg_t:=<eax>, indirected
;// dlist_MergeBefore MACRO name:req, reg_N:req, reg_R:req, reg_p:=<edx>, reg_t:=<eax>, indirected
;// dlist_MoveTailBefore MACRO name:req, reg_R:req, reg_N:req, reg_p:=<edx>,reg_b:=<eax>,indirected
;// dlist_Clear MACRO name:req, indirected
;//
;// IF_SORT_TEST MACRO method:req, iter:req, key_name:req, key:req
;// IF_NOT_SORT_TEST MACRO method:req, iter:req, key_name:req, key:req
;// dlist_InsertSorted MACRO name:req, method:req, item:req, key_name:req, iter:=<ecx>, last:=<edx>, key:=<eax>, indirected











    dlist_Declare_link  MACRO listName:REQ, listStruc:REQ

        IFDEF listName&_dlist_has_link
        .ERR <dlist listName already has a declared link>
        ENDIF

        dlist_pNext_&listName   dd  0
        dlist_pPrev_&listName   dd  0

        listName&_dlist_has_link    EQU 1
        listName&_dlist_next    TEXTEQU <dlist_pNext_&listName>
        listName&_dlist_prev    TEXTEQU <dlist_pPrev_&listName>
        listName&_dlist_assume  TEXTEQU <listStruc> ;// define the auto assume

        ENDM

    dlist_Declare_alias_link MACRO newList:req, oldList:req

        ;// allows one list to take the place of another
        ;// does not allocate data
        ;// only defines a new name for an old list
        ;// lists must have the same struct

        IFDEF newList&_dlist_has_link
        .ERR <dlist newName already has a declared link>
        ENDIF

        IFNDEF oldList&_dlist_has_link
        .ERR <dlist oldName does not have a declared link>
        ENDIF

        newList&_dlist_has_link EQU 1
        newList&_dlist_next TEXTEQU oldList&_dlist_next
        newList&_dlist_prev TEXTEQU oldList&_dlist_prev
        newList&_dlist_assume   TEXTEQU oldList&_dlist_assume

        ENDM


    dlist_Declare MACRO listName:req

        IFNDEF listName&_dlist_has_link
        .ERR <dlist listName does not have a declared link>
        ENDIF

        IFDEF listName&_dlist_is_declared
            IFNDEF listName&_dlist_is_declared_external
                .ERR <dlist listName is already declared>
            ENDIF
        ELSE
            listName&_dlist_is_declared EQU 1   ;// prevent duplicates
        ENDIF

        listName&_dlist_head    dd  0       ;// allocate the head
        listName&_dlist_tail    dd  0       ;// allocate the tail


        ENDM

    dlist_Declare_external MACRO listName:req

        IFNDEF listName&_dlist_has_link
        .ERR <dlist listName does not have a declared link>
        ENDIF
        IFDEF listName&_dlist_is_declared
        .ERR <listName is already declared>
        ENDIF

        listName&_dlist_is_declared EQU 1   ;// prevent duplicates
        listName&_dlist_is_declared_external    EQU 1   ;// prevent duplicates

        EXTERNDEF listName&_dlist_head:DWORD    ;// allocate the head
        EXTERNDEF listName&_dlist_tail:DWORD    ;// allocate the head

        ENDM

    dlist_Declare_indirected MACRO listName:req

        listName&_dlist_is_indirected EQU 1

        dlist_Declare listName

        ENDM


;///////////////////////////////////////////////////////////////////////
;//
;// macro functions         these act as access symbols
;//                         they are responsible for producing
;//                         a majority of the error messages


    dlist_Head  MACRO name:req, indirected

        ;// dlist_Head()    enter

        LOCAL t

        IFNDEF name&_dlist_is_declared
        .ERR <dlist name is not declared>
        ENDIF

        IFDEF name&_dlist_is_indirected
            IFB <indirected>
            .ERR <dlist name requires an indirector>
            ENDIF
            t CATSTR BRACKET(indirected),<.>,<name>,<_dlist_head>
        ELSE
            t CATSTR <name>,<_dlist_head>
        ENDIF

        ;// dlist_Head()    exit
        EXITM t
        ENDM


    dlist_Tail  MACRO name:req, indirected

        ;// dlist_Tail()    enter

        LOCAL t

        IFNDEF name&_dlist_is_declared
        .ERR <dlist name is not declared>
        ENDIF

        IFDEF name&_dlist_is_indirected
            IFB <indirected>
            .ERR <dlist name requires an indirector>
            ENDIF
            t CATSTR BRACKET(indirected),<.>,<name>,<_dlist_tail>
        ELSE
            t CATSTR <name>,<_dlist_tail>
        ENDIF

        ;// dlist_Tail()    exit
        EXITM t

        ENDM

    ;// ex: mov dlist_Head(myList), 0

    dlist_Next  MACRO name:req, reg:req

        ;// dlist_Next()    enter

        LOCAL t

        IFNDEF name&_dlist_is_declared
        .ERR <dlist name is not declared>
        ENDIF

    %   t CATSTR <BRACKET(reg)>, <.>, <name>, <_dlist_next>

        ;// dlist_Next()    exit
        EXITM t
        ENDM

    dlist_Prev  MACRO name:req, reg:req

        ;// dlist_Prev()    enter

        LOCAL t

        IFNDEF name&_dlist_is_declared
        .ERR <dlist name is not declared>
        ENDIF

    %   t CATSTR <BRACKET(reg)>, <.>, <name>, <_dlist_prev>

        ;// dlist_Prev()    exit
        EXITM t
        ENDM

;/////////////////////////////////////////////////////////////////
;//
;// sometimes usefull   dlist_CopyPointer       sometime this is cleanly
;//                     dlist_ResetNode     clears pNext and pPrev

    dlist_CopyPointer MACRO  name:req, fReg:req, tReg:req

        ;// this just copies and assume the new ptr
        ;// comes in handy on rare occassions

        IFNDEF name&_dlist_is_declared
        .ERR <dlist name is not declared>
        ENDIF

        mov tReg, fReg
%       ASSUME tReg:PTR name&_dlist_assume

        ENDM

    dlist_ResetNode MACRO name:req, reg:req, clear

        ;// clears out pNext and pPrev
        ;// useful after a block is allocated but not cleared

        IFNB <clear>

            mov dlist_Next(name,reg),clear
            mov dlist_Prev(name,reg),clear

        ELSE

            mov dlist_Next(name,reg),0
            mov dlist_Prev(name,reg),0

        ENDIF

        ENDM

;// sometimes usefull   CopyPointer     sometime this is cleanly
;//                     ResetNode       clears pNext and pPrev
;//
;/////////////////////////////////////////////////////////////////



;/////////////////////////////////////////////////
;//
;//                 dlist_GetHead
;//                 dlist_OrGetHead
;// iterating       dlist_GetTail
;//                 dlist_GetNext
;//                 dlist_OrGetNext
;//                 dlist_OrGetPrev

    dlist_GetHead MACRO name:req, regNow:req, indirected

        mov regNow, dlist_Head(name,indirected)
    %   ASSUME regNow:PTR name&_dlist_assume
        DEBUG_IF <regNow && dlist_Prev(name,regNow)>    ;// corrupted head

        ENDM

    dlist_OrGetHead MACRO name:req, regNow:req, indirected

        or regNow, dlist_Head(name,indirected)
    %   ASSUME regNow:PTR name&_dlist_assume

        ENDM

    dlist_GetTail MACRO name:req, regNow:req, indirected

        IFDEF name&_dlist_is_indirected
        IFB <indirected>
        .ERR <dlist name requires an indirector>
        ENDIF
        ENDIF

        mov regNow, dlist_Tail(name,indirected)
    %   ASSUME regNow:PTR name&_dlist_assume
        DEBUG_IF <regNow && dlist_Next(name,regNow)>    ;// corrupted tail

        ENDM

    dlist_OrGetTail MACRO name:req, regNow:req, indirected

        or regNow, dlist_Tail(name,indirected)
    %   ASSUME regNow:PTR name&_dlist_assume

        ENDM


    dlist_GetNext MACRO name:req, regNow:req, regNew

        IFNB <regNew>
            mov regNew, dlist_Next(name, regNow)
        %   ASSUME regNew:PTR name&_dlist_assume
        ELSE
            mov regNow, dlist_Next(name, regNow)
        ENDIF

        ENDM

    dlist_OrGetNext MACRO name:req, regNow:req, regNew

        IFNB <regNew>
            or regNew, dlist_Next(name, regNow)
        %   ASSUME regNew:PTR name&_dlist_assume
        ELSE
            or regNow, dlist_Next(name, regNow)
        ENDIF

        ENDM

    dlist_GetPrev MACRO name:req, regNow:req, regNew

        IFNB <regNew>
            mov regNew, dlist_Prev(name, regNow)
        %   ASSUME regNew:PTR name&_dlist_assume
        ELSE
            mov regNow, dlist_Prev(name, regNow)
        ENDIF

        ENDM

    dlist_OrGetPrev MACRO name:req, regNow:req, regNew

        IFNB <regNew>
            or regNew, dlist_Prev(name, regNow)
        %   ASSUME regNew:PTR name&_dlist_assume
        ELSE
            or regNow, dlist_Prev(name, regNow)
        ENDIF

        ENDM


;//
;// iterating
;//
;//
;/////////////////////////////////////////////////


;/////////////////////////////////////////////////////////
;//
;// member testing
;//

    dlist_IfMember_jump MACRO name:req, reg:req, jumper:req, indirected

        cmp dlist_Next(name,reg),0
        jnz jumper
        cmp reg, dlist_Tail( name,indirected )
        je jumper

        ENDM

    dlist_IfNotMember_jump MACRO name:req, reg:req, jumper:req, indirected

        LOCAL are_member

        cmp dlist_Next(name,reg),0
        jne are_member
        cmp reg, dlist_Tail( name,indirected )
        jne jumper

        are_member:

        ENDM

;//
;// member testing
;//
;/////////////////////////////////////////////////////////









;////////////////////////////////////////////////////////////////////////////////
;//
;//                     dlist_InsertHead    dlist_InsertAfter
;// inserting           dlist_InsertTail    dlist_InsertBefore
;//

    dlist_InsertHead MACRO name:req, regNew:req, regTemp:=<eax>, indirected

        ;// returns regTemp as old head, might be zero so check
        LOCAL ok_to_insert
        IFDEF DEBUGBUILD    ;// make sure we aren't already in the list
            dlist_IfNotMember_jump name, regNew, ok_to_insert, indirected
            int 3   ;// regNew is already in list
        ok_to_insert:
        ENDIF

        .ERRIDNI <regNew>,<regTemp>,<regs cannot be the same>

        dlist_GetHead name, regTemp, indirected     ;// get the old head

        mov dlist_Head(name, indirected), regNew    ;// set the new head
        mov dlist_Next(name,regNew), regTemp        ;// set the new next with the old head

        test regTemp, regTemp

        .IF !ZERO?                                  ;// check for a single entry
             mov dlist_Prev(name,regTemp), regNew   ;// set the new previous item
        .ELSE                                       ;// empty list
            mov dlist_Tail(name,indirected), regNew ;// set the new tail
        .ENDIF

        ENDM


    dlist_InsertTail MACRO name:req, regNew:req, regTemp:=<eax>, indirected

        ;// returns regTemp as old tail, might be zero so check

        LOCAL ok_to_insert
        IFDEF DEBUGBUILD    ;// make sure we aren't already in the list
            dlist_IfNotMember_jump name, regNew, ok_to_insert, indirected
            int 3   ;// regNew is already in list
        ok_to_insert:
        ENDIF

        .ERRIDNI <regNew>,<regTemp>,<regs cannot be the same>

        dlist_GetTail name, regTemp, indirected ;// get the old tail

        mov dlist_Tail(name, indirected), regNew;// set the new tail

        test regTemp, regTemp                   ;// test for zero
        mov dlist_Prev(name,regNew), regTemp    ;// set the new previous

        ;// check for a single item

        .IF !ZERO?
            mov dlist_Next(name,regTemp), regNew    ;// set the next pointer with new item
        .ELSE
            mov dlist_Head(name,indirected), regNew ;// set the new head
        .ENDIF

        ENDM



    ;// inserts regNew BEFORE regNow
    ;// regNow and regNew are preserved

    dlist_InsertBefore MACRO name:req, regNew:req, regNow:req, regTemp:=<eax>, indirected

        LOCAL ok_to_insert
        IFDEF DEBUGBUILD    ;// make sure we aren't already in the list
            dlist_IfNotMember_jump name, regNew, ok_to_insert, indirected
            int 3   ;// regNew is already in list
        ok_to_insert:
        ENDIF

        .ERRIDNI <regNew>,<regTemp>,<regs cannot be the same>
        .ERRIDNI <regNow>,<regTemp>,<regs cannot be the same>
        .ERRIDNI <regNew>,<regNow>,<regs cannot be the same>


        xor regTemp, regTemp                        ;// clear for testing
        mov dlist_Next(name,regNew), regNow     ;// set new.next = now
        or regTemp, dlist_Prev(name,regNow)     ;// load and get now.prev
        mov dlist_Prev(name,regNow), regNew     ;// set now.prev = new
        mov dlist_Prev(name,regNew), regTemp    ;// set new.prev = temp

        .IF !ZERO?  ;// we are NOT inserting before the head
                    ;// reg temp is a valid object

            %   ASSUME regTemp:PTR name&_dlist_assume
            mov dlist_Next(name,regTemp), regNew    ;// set temp.next = new

        .ELSE       ;// we are inserting before the head
                    ;// reg temp = 0

            mov dlist_Head(name,indirected), regNew ;// set head = new

        .ENDIF


        ENDM


    ;// inserts regNew AFTER regNow
    ;// regNow and regNew are preserved

    dlist_InsertAfter MACRO name:req, regNew:req, regNow:req, regTemp:=<eax>, indirected

        ;// dlist_InsertAfter   ENTER
        LOCAL ok_to_insert
        IFDEF DEBUGBUILD    ;// make sure we aren't already in the list
            dlist_IfNotMember_jump name, regNew, ok_to_insert, indirected
            int 3   ;// regNew is already in list
        ok_to_insert:
        ENDIF

        .ERRIDNI <regNew>,<regTemp>,<regs cannot be the same>
        .ERRIDNI <regNow>,<regTemp>,<regs cannot be the same>
        .ERRIDNI <regNew>,<regNow>,<regs cannot be the same>

        xor regTemp, regTemp                    ;// clear for testing
        mov dlist_Prev(name,regNew), regNow     ;// set new.prev = now
        or regTemp, dlist_Next(name,regNow)     ;// load and test now.next
        mov dlist_Next(name,regNow), regNew     ;// set now.next = new
        mov dlist_Next(name,regNew), regTemp    ;// set new.next = temp

        .IF !ZERO?  ;// we are not replacing the tail
                    ;// reg temp is a valid object

            %   ASSUME regTemp:PTR name&_dlist_assume
            mov dlist_Prev(name,regTemp), regNew    ;// set temp.prev = new

        .ELSE       ;// we are replacing the tail
                    ;// regtemp is zero
;//ECHO dlist_InsertAfter this line was wrong for tails (was regNow), make sure ABox still works
            mov dlist_Tail(name, indirected), regNew    ;// set list.tail = new

        .ENDIF

        ;// dlist_InsertAfter   EXIT
        ENDM


;//
;// inserting       dlist_InsertHead    dlist_InsertAfter
;//                 dlist_InsertTail    dlist_InsertBefore
;//
;////////////////////////////////////////////////////////////////////////////////




;////////////////////////////////////////////////////////////////////////////////
;//
;//                     dlist_RemoveHead -> returns with old head (for iterating)
;//     removing        dlist_RemoveTail -> returns with old tail (for iterating)
;//                     dlist_Remove
;//

    dlist_RemoveHead MACRO name:req, regOld:req, regNew:=<eax>, indirected

        ;// returns with regOld as the old head
        ;// returns with regNew as the new head
        ;// if list was empty, sets the zero flag

        dlist_GetHead name, regOld, indirected      ;// get the current head
        .IF regOld                                  ;// zero flag set if no head

            DEBUG_IF <dlist_Prev(name,regOld)>      ;// corrupted head

            dlist_GetNext name, regOld, regNew      ;// get the next item
            mov dlist_Head(name,indirected), regNew ;// set the new head
            mov dlist_Next(name,regOld), 0          ;// turn off old next (unique)
            .IF regNew                              ;// make sure not empty
                mov dlist_Prev(name,regNew), 0      ;// turn off the new prev
            .ELSE
                mov dlist_Tail(name, indirected), regNew        ;// erase the old tail
                test regOld, regOld                 ;// turn off the zero flag
            .ENDIF
        .ENDIF

        ENDM


    dlist_RemoveTail MACRO name:req, regOld:req, regNew:=<eax>, indirected

        ;// returns with regOld as the item that was removed (the old tail)
        ;// returns regNew as the new tail
        ;// if list was empty, the zero flag will be set

        dlist_GetTail name, regOld, indirected  ;// get the current tail
        .IF regOld  ;// this may set the zero flag

            DEBUG_IF <dlist_Next(name,regOld)>  ;// corrupted tail

            dlist_GetPrev name, regOld, regNew      ;// get the previous item
            mov dlist_Tail(name,indirected), regNew;// set it as the new tail
            mov dlist_Prev(name,regOld), 0          ;// turn off old prev (unique)

            .IF regNew      ;// zero flag not set       ;// make sure not empty
                mov dlist_Next(name,regNew), 0      ;// turn off it's next
            .ELSE           ;// list is now empty (regNew is zero)
                mov dlist_Head(name, indirected), regNew    ;// erase the old head
                test regOld, regOld                     ;// turn off the zero flag
            .ENDIF

        .ENDIF  ;// else zero flag set

        ENDM



    ;// dlist_Remove
    ;//
    ;// should be safe to use if regNow is not in list

    dlist_Remove MACRO name:req, regNow:req, regTemp:=<eax>, indirected

        LOCAL dlist_r_head
        LOCAL dlist_r_tail
        LOCAL dlist_r_empty
        LOCAL dlist_r_finished
        LOCAL dlist_r_not_member

        ;// get our previous item and see if we may be the head

            dlist_GetPrev name, regNow, regTemp ;// get our previous item
            test regTemp, regTemp               ;// see if we're the head
            jz dlist_r_head                     ;// if no prev, then we may be the head

        ;// we have a prev item, so we are not the head
        ;// regTemp is the previous item

            push dlist_Next(name,regNow)        ;// push our next pointer
            pop  dlist_Next(name,regTemp)       ;// retrieve as the new next pointer
                                                ;// for the previous item
            dlist_GetNext name, regNow, regTemp ;// get our next item

            or regTemp, regTemp                 ;// see if we may be the tail
            jz dlist_r_tail                     ;// jmp if we may be the tail

        ;// we have a next item, so we are not the tail
        ;// regTemp is the next item

            mov  dlist_Next(name,regNow), 0     ;// turn off our next item

            push dlist_Prev(name,regNow)        ;// push our previous item
            pop  dlist_Prev(name,regTemp)       ;// retrieve as the new previous item

            mov  dlist_Prev(name,regNow), 0     ;// turn off our previous item

            jmp dlist_r_finished

        ;// we do not have a prev item, so we may be the head
        ;// regTemp is zero
        dlist_r_head:

            cmp regNow, dlist_Head(name,indirected) ;// see if we are the head
            jne dlist_r_not_member                  ;// we're not a member if we are not the head

        ;// we are the head
        ;// see if the list is empty by checking our next value, regTemp is zero

            dlist_OrGetNext name,regNow,regTemp ;// get the next item
            jz dlist_r_empty                        ;// jump if empty list

        ;// we are head, the list is not empty,
        ;// regTemp is our next value

            mov dlist_Head(name,indirected), regTemp    ;// set the new head
            mov dlist_Prev(name,regTemp), 0             ;// turn off it's previous

        dlist_r_not_member: ;// jmped from above, prev already cleard

            mov dlist_Next(name,regNow), 0  ;// turn off our next

            jmp dlist_r_finished

        ;// we do not have a next item, we may be the tail, regTemp is zero
        ;// we had a prev item
        dlist_r_tail:

            dlist_GetPrev name, regNow, regTemp ;// get our previous item
            mov dlist_Tail(name, indirected), regTemp   ;// save as the new tail
            mov dlist_Next(name,regTemp), 0 ;// sets it's pNext to 0
            mov dlist_Prev(name,regNow), 0  ;// set our prev to zero

            jmp dlist_r_finished

        ;// list had a single item, reg Temp is zero
        dlist_r_empty:

            mov dlist_Head(name, indirected), regTemp   ;// turn off the head
            mov dlist_Tail(name, indirected), regTemp   ;// turn off the tail

        dlist_r_finished:

        ENDM


    ;// dlist_Remove_noheadtailclear
    ;//
    ;// this is the quick version when it assured that
    ;//     regNow is NOT the head or the tail
    ;// AND regNow is in the list
    ;// AND regNow doesn't need to be cleared

    dlist_Remove_noheadtailclear MACRO name:req, regNow:req, regTemp:=<eax>, indirected

            DEBUG_IF <!!dlist_Next(name,regNow)>
            DEBUG_IF <!!dlist_Prev(name,regNow)>

        ;// get our previous item and see if we may be the head

            dlist_GetPrev name, regNow, regTemp ;// get our previous item
            push dlist_Next(name,regNow)        ;// push our next pointer
            pop  dlist_Next(name,regTemp)       ;// retrieve as the new next pointer for the previous item
            dlist_GetNext name, regNow, regTemp ;// get our next item
            push dlist_Prev(name,regNow)        ;// push our previous item
            pop  dlist_Prev(name,regTemp)       ;// retrieve as the new previous item

        ENDM

;//
;//     removing
;//
;//
;////////////////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////////////////
;//
;//                 dlist_MoveToHead
;//     moving
;//

dlist_MoveToHead MACRO name:req, regNow:req, regTemp:=<eax>, indirected

        IFDEF name&_dlist_is_indirected
        IFB <indirected>
    %   .ERR <name required an indirector>
        ENDIF
        ENDIF

    dlist_GetPrev name, regNow, regTemp ;// get our previous item

    .IF regTemp     ;// skip entirely if we are the head

        ;// not the head

        push dlist_Next(name,regNow)        ;// push our next pointer
        pop  dlist_Next(name,regTemp)       ;// retrieve as the new next pointer
                                            ;// for the previous item
        dlist_GetNext name, regNow, regTemp ;// get our next item
        .IF regTemp                         ;// see if we're the tail

            ;// not the tail

            push dlist_Prev(name,regNow)    ;// push our previous item
            pop  dlist_Prev(name,regTemp)   ;// retrieve as the new previous item

        .ELSE

        ;// we are the tail

            dlist_GetPrev name, regNow, regTemp         ;// get our previous item
            mov dlist_Tail(name, indirected), regTemp   ;// save it the new tail
            mov dlist_Next(name,regTemp), 0             ;// sets it's pNext to 0

        .ENDIF

        dlist_GetHead name, regTemp, indirected ;// get the old head
        mov dlist_Next(name,regNow), regTemp    ;// set it as our next
        mov dlist_Prev(name,regTemp), regNow    ;// set ourseleves as it's previous
        mov dlist_Head(name,indirected), regNow ;// set ourseleves as the head
        mov dlist_Prev(name,regNow), 0          ;// set our prev to zero

    .ENDIF


    ENDM

;//
;//     moving
;//
;//
;////////////////////////////////////////////////////////////////////////////////

;////////////////////////////////////////////////////////////////////////////////
;//
;//                 dlist_SwapNext      these are complicated
;//     swapping    dlist_SwapPrev      consider using in a function
;//                                     requires 2 free registers
;//                                     requires indirector as well

comment ~ /*

details: SwapNext B

                       V
    input:  --> A <--> B <--> C <--> D <--

                              V
    output: --> A <--> C <--> B <--> D <--

        A = B.prev
        C = B.next  ;// if !C throw error, can't swap tail next

        .IF A
            A.next = C
        .ELSE

            head = C
        .ENDIF

        C.prev = A      ;// done with A
        B.prev = C      ;// set or zero

        D = C.next

        C.next = B
        B.next = D      ;// set or zero

        .IF D
            D.prev = B
        .ELSE
            tail = B
        .ENDIF

*/ comment ~




dlist_SwapNext MACRO name:req, rB:req, rA:=<eax>, rC:=<edx>, ind

    LOCAL rD
    rD TEXTEQU <rA> ;// saves programmer confusion

        xor rA, rA
        dlist_GetNext name,rB,rC        ;// C = B.next
        DEBUG_IF <!!rC>                 ;// if !C throw error, can't swap tail next
        dlist_OrGetPrev name, rB, rA    ;// A = B.prev
        .IF !ZERO?                      ;// .IF A
            mov dlist_Next(name,rA), rC ;//     A.next = C
        .ELSE
            mov dlist_Head(name,ind),rC ;//     head = C
        .ENDIF

        mov dlist_Prev(name,rC), rA     ;// C.prev = A      ;// done with A
        mov dlist_Prev(name,rB), rC     ;// B.prev = C      ;// set or zero

        dlist_GetNext name,rC,rD        ;// D = C.next

        mov dlist_Next(name,rC), rB     ;// C.next = B
        test rD, rD
        mov dlist_Next(name,rB), rD     ;// B.next = D      ;// set or zero

        .IF !ZERO?                      ;// .IF D
            mov dlist_Prev(name,rD),rB  ;//     D.prev = B
        .ELSE
            mov dlist_Tail(name,ind),rB ;//     tail = B
        .ENDIF

    ENDM



comment ~ /*

details: SwapPrev C

                              V
    input:  --> A <--> B <--> C <--> D <--

                       V
    output: --> A <--> C <--> B <--> D <--

        B = C.prev  ;// if !B error, can't swap head previous
        D = C.next

        .IF D
            D.prev = B
        .ELSE
            tail = B
        .ENDIF

        B.next = D  ;// done with D
        C.next = B

        A = B.prev

        B.prev = C
        C.prev = A  ;// sets or zeros

        .IF A
            A.next = C
        .ELSE
            head = C
        .ENDIF

*/ comment ~

dlist_SwapPrev MACRO name:req, rC:req, rA:=<eax>, rB:=<edx>, ind

        LOCAL rD
        rD TEXTEQU <rA>

        xor rD,rD
        dlist_GetPrev name,rC,rB        ;// B = C.prev
        DEBUG_IF <!!rB>                 ;// if !B error, can't swap head previous
        dlist_OrGetNext name,rC,rD      ;// D = C.next

        .IF !ZERO?                      ;// .IF D
            mov dlist_Prev(name,rD),rB  ;//     D.prev = B
        .ELSE
            mov dlist_Tail(name,ind),rB ;//     tail = B
        .ENDIF

        mov dlist_Next(name,rB), rD     ;// B.next = D  ;// done with D
        mov dlist_Next(name,rC),rB      ;// C.next = B

        dlist_GetPrev name,rB,rA        ;// A = B.prev

        mov dlist_Prev(name,rB), rC     ;// B.prev = C
        test rA, rA
        mov dlist_Prev(name,rC), rA     ;// C.prev = A  ;// sets or zeros

        .IF !ZERO?                      ;// .IF A
            mov dlist_Next(name,rA),rC  ;//     A.next = C
        .ELSE
            mov dlist_Head(name,ind),rC ;//     head = C
        .ENDIF

    ENDM







;////////////////////////////////////////////////////////////////////////////////
;//
;//     splicing        dlist_SplitAfter    dlist_SplitBefore
;//                     dlist_MergeAfter    dlist_MergeBefore
;//                     dlist_MoveTailBefore
comment ~ /*

    Split TRUNCATES a list and returns the floating fragment as a circular dlist

    Merge can INJECT the floating circular fragment back in to the list

    nomenclature    R   position in question
                    N   next item
                    P   prev item
                    t   tail of list

*/ comment ~


    dlist_SplitAfter MACRO name:req, reg_R:req, reg_N:req, reg_t:=<eax>, indirected

        ;// DO NOT USE IF reg_R is the tail

        ;// in   R
        ;//     012345  --> 01  2345
        ;// out   N  t       R  N  t

            dlist_GetNext name, reg_R, reg_N        ;// N = R.next
            dlist_GetTail name, reg_t, indirected   ;// t = name.tail

            mov dlist_Next(name,reg_t), reg_R       ;// t.next = R
            mov dlist_Prev(name,reg_N), reg_t       ;// N.prev = t

            mov dlist_Next(name,reg_R), 0           ;// reg_R.next = 0  [optional]
            mov dlist_Tail(name,indircted), reg_R   ;// name.tail = R

        ENDM

    dlist_SplitBefore MACRO name:req, reg_R:req, reg_P:=<edx>, reg_t:=<eax>, indirected

        ;// DO NOT USE IF   reg_R is the head

        ;// in    R
        ;//     012345  --> 01  2345
        ;// out  P   t       P  R  t

            dlist_GetPrev name, reg_R, reg_P        ;// P = R.prev
            dlist_GetTail name, reg_t, indirected   ;// t = name.tail

            mov dlist_Next(name,reg_t), reg_R       ;// t.next = R
            mov dlist_Prev(name,reg_R), reg_t       ;// R.prev = t

            mov dlist_Next(name,reg_prev), 0        ;// reg_R.next = 0  [optional]
            mov dlist_Tail(name,indirected), reg_P  ;// name.tail = P

        ENDM

    dlist_MergeAfter MACRO name:req, reg_N:req, reg_R:req, reg_b:=<edx>, reg_t:=<eax>, indirected

            ;// in  R     N
            ;//     0123  456 --> 0456123
            ;// out  a      t     RN ta

            ;// do NOT use if reg_R is the tail

            dlist_GetPrev name,reg_N,reg_t      ;// t = N.prev  because N is circular
            dlist_GetNext name,reg_R,reg_a      ;// a = R.next
            mov dlist_Next(name,reg_R), reg_N   ;// R.next = N
            mov dlist_Prev(name,reg_N), reg_R   ;// N.prev = R
            mov dlist_Next(name,reg_t), reg_a   ;// t.next = a
            mov dlist_Prev(name,reg_a), reg_t   ;// a.prev = t

            ENDM



    dlist_MergeBefore MACRO name:req, reg_N:req, reg_R:req, reg_p:=<edx>, reg_t:=<eax>, indirected

            ;// in   R    N
            ;//     0123  456 --> 0456123
            ;// out p       t     pN tR

            dlist_GetPrev name,reg_N,reg_t      ;// t = N.prev  because N is circular
            dlist_GetPrev name,reg_R,reg_p      ;// p = R.prev
            mov dlist_Next(name,reg_t), reg_R   ;// t.next = R
            mov dlist_Prev(name,reg_R), reg_t   ;// R.prev = t
            mov dlist_Next(name,reg_p), reg_N   ;// p.next = N
            mov dlist_Prev(name,reg_N), reg_p   ;// N.prev = p

            ENDM

    dlist_MoveTailBefore MACRO name:req, reg_R:req, reg_N:req, reg_p:=<edx>,reg_b:=<eax>,indirected

            ;// in    N  R        R N
            ;//     0123456 --> 0156234
            ;// out  p  b t      p    b

            ;// this macro isn't particulary simple, but is included just the same

            LOCAL reg_t
            reg_t TEXTEQU <reg_b>   ;// temp name

            dlist_GetTail name,reg_t,indirected ;// t = list.tail
            dlist_GetPrev name,reg_N,reg_p      ;// p = N.prev
            mov dlist_Next(name,reg_t), reg_N   ;// t.next = N
            mov dlist_Prev(name,reg_N), reg_t   ;// N.prev = t  ;// done with t, now we'll call it b again
            dlist_GetPrev name,reg_R, reg_b     ;// b = R.prev
            mov dlist_Next(name,reg_p), reg_R   ;// p.next = R
            mov dlist_Prev(name,reg_R), reg_p   ;// R.prev = p
            mov dlist_Tail(name,indirected),reg_b;// list.tail = b
            mov dlist_Next(name,reg_b), 0       ;// b.next = 0

        ENDM





;////////////////////////////////////////////////////////////////////////////////
;//
;//                                     DOES !NOT! DEALLOCATE
;//     clearing        dlist_Clear     DOES !NOT! REMOVE ITEMS
;//
;//     all this does is zero the head and tail

comment ~ /*
    dlist_Clear MACRO name:req, indirected

        IFDEF name&_dlist_is_indirected
        IFB <indirected>
    %   .ERR <name requires an indirector>
        ENDIF
        ENDIF

        mov dlist_Head(name,indirected), 0
        mov dlist_Tail(name,indirected), 0

        ENDM

*/ comment ~

;//
;//     clearing
;//
;////////////////////////////////////////////////////////////////////////////////




;///////////////////////////////////////////////
;//
;//     S O R T I N G
;//

;//////////////////////////////////////////////


    ;// this clumsy mess boils down to one instruction

    IF_SORT_TEST MACRO method:req, iter:req, key_name:req, key:req

        IFIDN <method>, <UNSIGNED_ASCENDING>
            .IF DWORD PTR [iter].key_name > key
        ELSEIFIDN <method>, <SIGNED_ASCENDING>
            .IF SDWORD PTR [iter].key_name > SDWORD PTR key
        ELSEIFIDN <method>, <UNSIGNED_DESCENDING>
            .IF DWORD PTR [iter].key_name < key
        ELSEIFIDN <method>, <SIGNED_DESCENDING>
            .IF SDWORD PTR [iter].key_name < key
        ELSE
            .ERR <bad sort method>
        ENDIF

        ENDM

    IF_NOT_SORT_TEST MACRO method:req, iter:req, key_name:req, key:req

        IFIDN <method>, <UNSIGNED_ASCENDING>
            .IF DWORD PTR [iter].key_name < key
        ELSEIFIDN <method>, <SIGNED_ASCENDING>
            .IF SDWORD PTR [iter].key_name < key
        ELSEIFIDN <method>, <UNSIGNED_DESCENDING>
            .IF DWORD PTR [iter].key_name > key
        ELSEIFIDN <method>, <SIGNED_DESCENDING>
            .IF SDWORD PTR [iter].key_name > key
        ELSE
            .ERR <bad sort method>
        ENDIF

        ENDM


    dlist_InsertSorted MACRO name:req, method:req, item:req, key_name:req, iter:=<ecx>, last:=<edx>, key:=<eax>, indirected

        ;// this inserts the said item using a sort key located at [item+keyOfs]
        ;//
        ;// note that we use three temporary registers
        ;// this method will bog down for long lists
        ;// as it will travserse until the sort method is achieved
        ;//
        ;// method may be one of the following:
        ;// UNSIGNED_ASCENDING
        ;// SIGNED_ASCENDING
        ;// UNSIGNED_DESCENDING
        ;// SIGNED_DESCENDING

        LOCAL insert_sorted_loop, set_new_head

        xor iter, iter                          ;// clear for testing
        dlist_OrGetHead name, iter, indirected  ;// get and test the head
        jz set_new_head                         ;// jump if empty

        mov key, DWORD PTR [item].key_name      ;// store the key locally

        IF_SORT_TEST method, iter, key_name, key    ;// compare keys

        set_new_head:       ;// we're at the head

            dlist_InsertHead name, item, key, indirected

        .ELSE

        insert_sorted_loop:

            mov last, iter
            ASSUME last:PTR name&_dlist_assume
            dlist_GetNext name, iter
            .IF iter

                IF_NOT_SORT_TEST  method, iter, key_name, key

                    jmp insert_sorted_loop

                .ENDIF

            .ENDIF

            ;// when we get here, last is the item we insert after
            ;// iter is the next item, which may be blank

            ;// read: insert 'item' AFTER 'last' USING 'key' as temp register

            dlist_InsertAfter name, item, last, key, indirected

        .ENDIF


        ENDM



ENDIF   ;// _DLIST3_INCLUDED_