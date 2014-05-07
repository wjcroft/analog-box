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
;//                 macros for a circular singly linked list
;//     clist3.inc  there is no head, only an MRS (Most Recently Set)
;//                 MRS keeps track of insertions and removals
;//                 MRS is NOT thread safe !!!
;//     insertion will ignore items already in a list by checking pNext
;//     if item is in another clist, use merge
;//
;//     see slist.inc for far more documentation on the basic scheme
;//
IFNDEF _CLIST3_INCLUDED_
_CLIST3_INCLUDED_ EQU 1

;// TOC
;//
;// clist_Declare_link MACRO listName:req, listStruc:req
;// clist_Declare_external MACRO listName:req
;// clist_Declare MACRO listName:req
;// clist_Declare_indirected MACRO listName:req
;//
;// clist_MRS MACRO name:req, indirected
;// clist_Next MACRO name:req, reg:req
;//
;// clist_CopyPointer MACRO name:req, reg1:req, reg2:req
;// clist_ResetNode MACRO name:req, reg:req
;// clist_GetMRS MACRO name:req, reg:req, indirected
;// clist_OrGetMRS MACRO name:req, reg:req, indirected
;// clist_SetMRS MACRO name:req, reg:req, indirected
;// clist_GetNext MACRO name:req, regNow:req, regDest
;// clist_OrGetNext MACRO name:req, regNow:req, regDest:req
;//
;// clist_Insert MACRO name:req, rNew:req, rNow, indirected
;// clist_Remove MACRO name:req, rNow:req, rPrev:=<eax>, indirected, EXTRA
;// clist_RemoveMRS MACRO name:REQ, reg:req, indirected
;// clist_RemoveMRSNext MACRO name:req, reg:req,indirected,ABORT
;//
;// clist_Clear MACRO name:req, iter1:=<eax>, iter2:=<edx>, indirected
;// clist_Merge MACRO name:req, src:req, iter1:=<eax>, iter2:=<edx>, indirected
;// clist_Splice MACRO name:req, iter1:req, iter2:req, temp1:=<eax>, temp2:=<edx>
;// clist_IfInListGoto MACRO name:req, src:req, goto:req, iter:=<eax>, indirected


;//////////////////////////////////////////////
;//////////////////////////////////////////////
;//////////////////////////////////////////////
;//////////////////////////////////////////////
;//
;//
;//     D E C L A R A T I O N   M A C R O S
;//



    clist_Declare_link MACRO listName:req, listStruc:req

        IFDEF listName&_clist_has_link
        .ERR <clist listName already has a link>
        ENDIF

        clist_pNext_&listName   dd  0

        listName&_clist_next    TEXTEQU <clist_pNext_&listName>
        listName&_clist_assume  TEXTEQU <listStruc>

        listName&_clist_has_link EQU 1

        ENDM


    clist_Declare_external MACRO listName:req

        IFNDEF listName&_clist_has_link
        .ERR <clist listName does not have a declared link>
        ENDIF
        IFDEF listName&_clist_is_declared
        .ERR <clist listName is already declared>
        ENDIF

        listName&_clist_is_declared_external EQU 1
        listName&_clist_is_declared          EQU 1

        EXTERNDEF listName&_clist_MRS:DWORD

        ENDM

    clist_Declare MACRO listName:req

        IFNDEF listName&_clist_has_link
        .ERR <clist listName does not have a declared link>
        ENDIF
        IFDEF listName&_clist_is_declared
        IFNDEF listName&_clist_is_declared_external
        .ERR <clist listName is already declared>
        ENDIF
        ENDIF

        listName&_clist_MRS      dd  0

        listName&_clist_is_declared EQU 1

        ENDM


    clist_Declare_indirected MACRO listName:req

        listName&_clist_is_indirected EQU 1

        clist_Declare listName

        ENDM


;//////////////////////////////////////////////

    clist_MRS MACRO name:req, indirected

        LOCAL temp

    ;// use as a data item
        .ERRNDEF name&_clist_is_declared, <clist name is not declared>

        IFDEF name&_clist_is_indirected
            .ERRB <indirected>, <need an indirector>
            temp CATSTR BRACKET(indirected),<.>,<name>,<_clist_MRS>
        ELSE
            temp CATSTR <name>,<_clist_MRS>
        ENDIF

        EXITM temp
        ENDM


;//////////////////////////////////////////////


    clist_Next MACRO name:req, reg:req
    ;// use as a data item

        LOCAL temp

        .ERRNDEF name&_clist_is_declared, <clist name is not declared>

        temp CATSTR <[>,<reg>,<].>,<name>,<_clist_next>

        EXITM temp

        ENDM

;//////////////////////////////////////////////

    clist_CopyPointer MACRO name:req, reg1:req, reg2:req

        mov reg2, reg1
        ASSUME reg2:PTR name&_clist_assume  ;// assume it

        ENDM


;//////////////////////////////////////////////


    clist_ResetNode MACRO name:req, reg:req

        mov clist_Next(name,reg), 0

        ENDM


;//////////////////////////////////////////////

    clist_GetMRS MACRO name:req, reg:req, indirected

    ;// simply returns the name_MRS_clist value in reg
    ;// then assumes the register

        .ERRNDEF name&_clist_is_declared, <clist name is not declared>

        IFDEF name&_clist_is_indirected
            .ERRB <indirected>, <need an indirector>
            mov reg, BRACKET(indirected).&name&_clist_MRS
        ELSE
            mov reg, name&_clist_MRS            ;// get the head
        ENDIF

        ASSUME reg:PTR name&_clist_assume   ;// assume it

        ENDM

;//////////////////////////////////////////////

    clist_OrGetMRS MACRO name:req, reg:req, indirected

    ;// simply or's the name_MRS_clist value with reg
    ;// then assumes the register

        .ERRNDEF name&_clist_is_declared, <clist name is not declared>

        IFDEF name&_clist_is_indirected
            .ERRB <indirected>,<need an indirector>
            or reg, BRACKET(indirected).&name&_clist_MRS
        ELSE
            or reg, name&_clist_MRS         ;// get the head
        ENDIF

        ASSUME reg:PTR name&_clist_assume   ;// assume it

        ENDM

;//////////////////////////////////////////////

    clist_SetMRS MACRO name:req, reg:req, indirected

    ;// this sets the MRS, can be used to stop iteration

        .ERRNDEF name&_clist_is_declared, <clist name is not declared>

        IFDEF name&_clist_is_indirected
            .ERRB <indirected>, <need an indirector>
            mov BRACKET(indirected).&name&_clist_MRS, reg
        ELSE
            mov name&_clist_MRS, reg    ;// set the MRS
        ENDIF

        ENDM

;//////////////////////////////////////////////

    clist_GetNext MACRO name:req, regNow:req, regDest

        ;// retrieves the next item from said list
        ;// user implementation must assure that regNow is valid by checking for NULL
        ;// user must also store a pointer to know when to stop
        ;// or use clist_MRS to do this

        ;// will fail is regNow was not assumed

        .ERRNDEF name&_clist_is_declared, <clist name is not declared>

        IFNB <regDest>
            mov regDest, [regNow].name&_clist_next
        %   ASSUME regDest:PTR name&_clist_assume
        ELSE
            mov regNow, [regNow].name&_clist_next
        ENDIF

    ENDM

;//////////////////////////////////////////////

    clist_OrGetNext MACRO name:req, regNow:req, regDest:req

        ;// retrieves the next item from said list using or operator
        ;// regDest must be zero
        ;// user implementation must assure that regNow is valid by checking for NULL

        ;// will fail is regNow was not assumed

        .ERRNDEF name&_clist_is_declared, <clist name is not declared>

        or regDest, [regNow].name&_clist_next
    %   ASSUME regDest:PTR name&_clist_assume

    ENDM


;//////////////////////////////////////////////


    clist_Insert MACRO name:req, rNew:req, rNow, indirected

    ;// this inserts rNew after rNow
    ;//     if rNow not specifed, then use MRS as prev, and eax as a temp
    ;//     ignores if rNew is already in _A_ list
    ;//         does not check if in SAME list
    ;// sets MRS to rNew
    ;// uses eax, and edx if eax is specified as rNew
    ;//

        .ERRNDEF name&_clist_is_declared, <clist name is not declared>

        .IF ![rNew].name&_clist_next                ;// check if already in a list

            IFB <rNow>
                IFIDNI <eax>, <rNew>

                    .ERRIDNI <[edx]>,<indirected>,<edx can't be the indirecter>

                    clist_GetMRS name, edx, indirected
                    test edx, edx                       ;// check if empty
                    .IF !ZERO?
                        push [edx].name&_clist_next     ;// store the old next
                        pop [rNew].name&_clist_next     ;// set new as old next
                        mov [edx].name&_clist_next, rNew;// set as new
                        clist_SetMRS name, rNew, indirected ;// set the new MRS
                    .ELSE
                        clist_SetMRS name, rNew, indirected
                        mov [rNew].name&_clist_next, rNew
                    .ENDIF

                ELSE

                    .ERRIDNI <[eax]>,<indirected>, <eax can't be the indirecter>

                    clist_GetMRS name, eax, indirected
                    test eax, eax                           ;// check if empty
                    .IF !ZERO?
                        push [eax].name&_clist_next     ;// store the old next
                        pop [rNew].name&_clist_next     ;// set new as old next
                        mov [eax].name&_clist_next, rNew;// set as new
                        clist_SetMRS name, rNew, indirected ;// set the new MRS
                    .ELSE
                        clist_SetMRS name, rNew, indirected
                        mov [rNew].name&_clist_next, rNew
                    .ENDIF
                ENDIF
            ELSE    ;// rNow is specified
                IFDIFI <rNew>, <rNow>
                push [rNow].name&_clist_next        ;// store the old next
                .IF !([rNow].name&_clist_next)      ;// account for empty list
                    mov DWORD PTR [esp], rNow
                .ENDIF
                pop [rNew].name&_clist_next         ;// set new as old next
                ENDIF
                mov [rNow].name&_clist_next, rNew   ;// set as new
                clist_SetMRS name, rNew, indirected ;// set the new MRS
            ENDIF

        .ENDIF

    ENDM


;//////////////////////////////////////////////

    clist_Remove MACRO name:req, rNow:req, rPrev:=<eax>, indirected, EXTRA

    ;// returns rPrev as the item that points to us, if any
    ;// then use rPrev to get the new next item

    ;// extra can be a command or macro that will be hit if the item is removed

    ;// ok to use if item is not in a clist

    ;// MRS will be set or cleared.

        LOCAL R1, R2, R3, R4

        .ERRNDEF name&_clist_is_declared, <clist name is not declared>

        .ERRIDNI <[eax]>,<indirected>,<eax can't be the indirector>

        xor rPrev,rPrev
        cmp [rNow].name&_clist_next, rPrev      ;// check if we're even in a clist
        jz R4

        ;// do the extra

            EXTRA

        ;// find the item that points to us

            mov rPrev, rNow                     ;// rPrev will iterate
        %   ASSUME rPrev:PTR name&_clist_assume
        R1: cmp rNow, [rPrev].name&_clist_next  ;// see if rPrev is pointing at us
            je R2                               ;// jump if so
            mov rPrev, [rPrev].name&_clist_next ;// get the next item
            jmp R1                              ;// continue on

        R2: cmp rPrev, rNow                 ;// see if we're pointing at ourseleves
            je R3                           ;// jump if we were

        ;// rPrev points at us

            push [rNow].name&_clist_next            ;// push our next
            clist_SetMRS name, rPrev, indirected    ;// set the MRS
            and [rNow].name&_clist_next, 0      ;// clear our entry
            pop [rPrev].name&_clist_next        ;// pop the previous next
            jmp R4                              ;// exit

        ;// we were pointing at ourselves

        R3: xor rPrev, rPrev                    ;// no previous item
            mov [rNow].name&_clist_next, rPrev      ;// clear our entry
            clist_SetMRS name, rPrev, indirected    ;// set the MRS

        R4: ;// done or not in a list

        ENDM

;//////////////////////////////////////////////

    clist_RemoveMRS MACRO name:REQ, reg:req, indirected

        ;// removes MRS, sets as next item
        ;// safe for empty lists
        ;// always check reg for not in list
        ;// sets zero flag if list was empty
        ;// uses eax as temp reg
        ;// BAD for flushing lists, always requires a search

    ECHO < !!!! clist_RemoveMRS has not been tested !!!! >

        LOCAL A1,A2

        xor reg,reg
        clist_OrGetMRS name,reg,indirected
        .IF !ZERO?

            clist_GetNext name,reg,eax      ;// load the next node into eax
            mov clist_Next(name,reg), 0     ;// reset this node
            .IF reg != eax                  ;// only item in list ?
                ;// still items in list
                ;// which means we have to locate item that points to us
                mov clist_MRS(name,indirected), eax     ;// set the new MRS
                cmp clist_Next(name,eax), reg       ;// locate item that points to reg
                push eax                            ;// save what will be the new next pointer
                je A2                               ;// early out if first item was also last
            A1: clist_GetNext name,eax              ;// looking for item that points to reg
                cmp clist_Next(name,eax), reg
                jne A1
            A2: pop clist_Next(name,eax)            ;// set the new next pointer
            .ELSE   ;// list is now empty
                mov clist_MRS(name,indirected), 0
            .ENDIF
            test reg,reg                    ;// clear the zero flag

        .ENDIF

        ENDM


;//////////////////////////////////////////////

    clist_RemoveMRSNext MACRO name:req, reg:req,indirected,ABORT

        ;// remove and return NEXT item from MRS
        ;// or remove and return MRS itself if list has only one item
        ;// safe for empty lists
        ;// safe for single item lists
        ;// GOOD for flushing lists, no search required
        ;// zero flag set if empty list, reg at undetermined value
        ;// eax is used as temp register

        ;// optionally use ABORT as a label to exit a loop
        ;// if ABORT is used, fallthrough is reg = valid_item

        xor eax, eax
        clist_OrGetMRS name,eax             ;// get the MRS first
        IFNB <ABORT>
            jz ABORT
        ELSE
        .IF !ZERO?                          ;// list has at least one item
        ENDIF
            clist_GetNext name,eax,reg      ;// reg is now the correct return value
            .IF reg != eax                  ;// multiple item list (zero flag is off)
                push clist_Next(name,reg)   ;// push old next pointer
                pop clist_Next(name,eax)    ;// pop as mrs's new nex pointer
            .ELSE                           ;// single item list, zero flag is on
                mov clist_MRS(name,indirected),0    ;// empty the list
                IFB <ABORT>
                test reg, reg               ;// reset the zero flag
                ENDIF
            .ENDIF
            mov clist_Next(name,reg), 0     ;// reset this node

        IFB <ABORT>
        .ENDIF
        ENDIF

        ENDM


;//////////////////////////////////////////////




    clist_Clear MACRO name:req, iter1:=<eax>, iter2:=<edx>, indirected

        ;// this clears all items in the list

        .ERRNDEF name&_clist_is_declared, <clist name is not declared>
        .ERRIDNI <[eax]>,<indirected>,<eax can't be the indirector>
        .ERRIDNI <[edx]>,<indirected>,<edx can't be the indirector>

        clist_GetMRS name, iter1, indirected    ;// get the MRS
        .WHILE iter1                            ;// scan unti it's zero
            clist_GetNext name, iter1, iter2    ;// get next item
            mov [iter1].name&_clist_next, 0     ;// remove this item
            mov iter1, iter2                    ;// xfer next to current
        .ENDW                                   ;// do until we got a zero vlue
        clist_SetMRS name, 0, indirected        ;// reset the mrs

        ENDM


;//////////////////////////////////////////////


    clist_Merge MACRO name:req, src:req, iter1:=<eax>, iter2:=<edx>, indirected

        ;// this will splice src into name.MRS
        ;// will crash if name.MRS is not set
        ;// preserves src

        LOCAL CM1, CM2

        .ERRNDEF name&_clist_is_declared, <clist name is not declared>
        .ERRIDNI <src>,<iter1>, <SRC = ITER1 !!>
        .ERRIDNI <src>,<iter2>, <SRC = ITER2 !!>
        .ERRIDNI <iter1>,<iter2>, <ITER1 = ITER2 !!>

        clist_GetMRS name, iter1, indirected    ;// get the MRS of the dest list
        clist_GetNext name, iter1, iter2        ;// get the next item

        mov clist_Next(name,iter1), src         ;// set dest next as new list

        ;// locate the end of the src list (item that points at src)

            clist_GetNext name, src, iter1
        CM1:cmp src, clist_Next(name,iter1) ;// same item ?
            je CM2
            clist_GetNext name, iter1       ;// get next item in src
            jmp CM1
        CM2:

        ;// set next item of end of src as the old dest next

        mov clist_Next(name,iter1), iter2

        ENDM


;//////////////////////////////////////////////

;// Splice
;//
;// Splice is similar to merge in that one list may be added to another
;// Splice, however, degenerates to Insert when appropriate

    comment ~ /*

        if we divide the passed iters into 3 classes,
        there are 9 cases of splicing that we account for
        in some cases we need to check if iter is in the same list
        interestingly:
            if items are in same list,
            and we force the merge
            the list splits into two

        given all that, this macro might be better off inside a separate function

    classes

        null     A0     A.n = 0             A is not a member of any list
        sing     AA     A.n = a             A is the only member of this list
        full    _AB_    A.n = B, B.n=C ...  A is a member of a full list, 2 or more items

    cases: Merge A, C

    A    C    schematic  actions          results               C.null  C.sing  C.full
    null null  A0   C0   A.n=C    C.n=A    AC                 +------------------------
    null sing  A0   CC   A.n=C    C.n=A    AC          A.null | A.n=C   A.n=C   A.n=C.n
    null full  A0  _CD_  A.n=C.n  C.n=A    _CAD_              | C.n=A   C.n=A   C.n=A
                                                              |
    sing null  AA   C0   A.n=C    C.n=A    AC          A.sing | A.n=C   A.n=C   A.n=C.n
    sing sing  AA   CC   A.n=C    C.n=A    AC                 | C.n=A   C.n=A   C.n=A
    sing full  AA  _CD_  A.n=C.n  C.n=A    _CAD_              |
                                                       A.full | A.n=C   A.n=C   A.n=C.n
    full null _AB_  C0   A.n=C    C.n=A.n  _ACD_              | C.n=A.n C.n=A.n C.n=A.n
    full sing _AB_  CC   A.n=C    C.n=A.n  _ACD_
    full full _AB_ _CD_  A.n=C.n  C.n=A.n  _AD_CB_ check


    knowing that for AA, A=A.n
    the proceedure can be simplified

        xor TA,TA   or TA,A.n   cmovz TA,A
        xor TC,TC   or TC,C.n   cmovz TC,C
        cmp TA,A    je insert_now
        cmp TC,C    je insert_now
    search ;;;;

    insert_now:
        A.n = TC
        C.n = TA

    */ comment ~

    ;// does NOT set MRS
    ;// this DOES allow the creation of a single list if A == C
    ;// do pre test to prevent this

    clist_Splice MACRO name:req, iter1:req, iter2:req, temp1:=<eax>, temp2:=<edx>

        LOCAL do_not_insert

        .ERRNDEF name&_clist_is_declared, <clist name is not declared>
        .ERRIDNI <iter1>,<temp1>,<cant use iter1 as iterator !! >
        .ERRIDNI <iter1>,<temp2>,<cant use iter1 as iterator !! >
        .ERRIDNI <iter2>,<temp1>,<cant use iter2 as iterator !! >
        .ERRIDNI <iter2>,<temp2>,<cant use iter2 as iterator !! >

            xor temp1, temp1
            sub temp2, temp2
        ;// or TA,A.n   cmovz TA,A
            clist_OrGetNext name,iter1,temp1
            IF  @Cpu AND 1000000y   ;// 686 code
                cmovz temp1,iter1
            ELSE
                .IF ZERO?
                    mov temp1,iter1
                .ENDIF
            ENDIF
        ;// or TC,C.n   cmovz TC,C
            clist_OrGetNext name,iter2,temp2
            IF  @Cpu AND 1000000y   ;// 686 code
                cmovz temp2,iter2
            ELSE
                .IF ZERO?
                    mov temp2,iter2
                .ENDIF
            ENDIF
        ;// cmp TA,A    je insert_now
        ;// cmp TC,C    je insert_now
            .IF iter1 != temp1 && iter2 != temp2
            ;// have to search
            ;// temp1 = A.n     and we know that both are valid
            ;// temp2 = C.n     so we iterate both and look for the other
                .REPEAT
                    cmp temp1,iter2
                    je do_not_insert
                    cmp temp2,iter1
                    je do_not_insert
                    clist_GetNext name,temp1
                    clist_GetNext name,temp2
                .UNTIL iter1 == temp1 || iter2 == temp2
                clist_GetNext name,iter1,temp1  ;// reload A.n
                clist_GetNext name,iter2,temp2  ;// reload C.n
            .ENDIF
            mov clist_Next(name,iter2),temp1
            mov clist_Next(name,iter1),temp2

        do_not_insert:

            ENDM

;//////////////////////////////////////////////


    clist_IfInListGoto MACRO name:req, src:req, goto:req, iter:=<eax>, indirected

    ;// read as: If <src> is currently in <name>, then goto <goto>
    ;// so fall through means we are not in the list
    ;// will crash if name.MRS is zero

        .ERRNDEF name&_clist_is_declared, <clist name is not declared>
        .ERRIDNI <src>,<iter>,<SRC = ITER !!>

        clist_GetMRS name, iter, indirected
        .REPEAT
            cmp iter, src
            je goto
            clist_GetNext name, iter
        .UNTIL iter == clist_MRS(name, indirected)

        ENDM

;//////////////////////////////////////////////




ENDIF ;// _CLIST3_INCLUDED_