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
;//     slist3.inc          singley linked list
;//                         see dlist3.inc for concepts
;//
IFNDEF _SLIST3_INCLUDED
_SLIST3_INCLUDED EQU 1

;// TOC:

;// slist_Declare_link  MACRO listName:req, listStruct:req
;// slist_Declare_alias_link MACRO newList:req, oldList:req, newStruct, subStruc:VARARG
;// slist_Declare MACRO listName:req, initValue:=<0>
;// slist_Declare_external MACRO listName:req
;// slist_Declare_indirected MACRO listName:req
;// slist_Head  MACRO name:req, indirected
;// slist_Next  MACRO name:req, reg:req
;// slist_GetHead MACRO name:req, reg:req, indirected
;// slist_OrGetHead MACRO name:req, reg:req, indirected
;// slist_GetNext MACRO name:req, regNow:req, regDest
;// slist_InsertHead MACRO name:req, regNow:req, regPrev:=<eax>, indirected
;// slist_RemoveHead MACRO name:req, reg1:=<eax>, indirected
;// slist_InsertNext MACRO name:req, regNow:req, regNext:req
;// slist_RemoveNext MACRO name:req, reg:req, reg1:=<eax>
;// slist_CopyPtrTo MACRO  name:req, fReg:req, tReg:req
;// slist_Remove MACRO name:req, regNow:req, reg1:=<eax>, reg2:=<edx>, indirected
;// slist_AllocateHead MACRO name:req, reg:req, siz
;// slist_FreeHead MACRO name:req, reg:req
;// IF_SORT_TEST MACRO method:req, iter:req, key_name:req, key:req
;// IF_NOT_SORT_TEST MACRO method:req, iter:req, key_name:req, key:req
;// slist_InsertSorted MACRO name:req, method:req, item:req, key_name:req, iter:=<ecx>, last:=<edx>, key:=<eax>, indirected
;// slist_TextSort MACRO name:req, case:req, keyOfs:req


    INCLUDE <utility.inc>


;//////////////////////////////////////////////
;//////////////////////////////////////////////
;//////////////////////////////////////////////
;//////////////////////////////////////////////
;//
;//
;//     D E C L A R A T I O N   M A C R O S
;//

    slist_Declare_link  MACRO listName:req, listStruct:req, subStruc:VARARG

        LOCAL ssss,tttt

        IFDEF listName&_slist_has_link
        .ERR <slist listName is already has a link>
        ENDIF

        slist_pNext_&listName   dd  0

        IFB <subStruc>
            listName&_slist_next    TEXTEQU <slist_pNext_&listName> ;// define pNext
        ELSE
            tttt TEXTEQU <>
            FOR ssss,<subStruc>
                tttt CATSTR tttt,<ssss>,<.>
            ENDM
            tttt CATSTR tttt,<slist_pNext_>,<listName>
            listName&_slist_next TEXTEQU tttt
        ENDIF

        listName&_slist_assume  TEXTEQU <listStruct>    ;// define the auto assume
        listName&_slist_has_link EQU 1

        ENDM


    slist_Declare_alias_link MACRO newList:req, oldList:req, newStruct, subStruc:VARARG

        ;// allows one list to take the place of another
        ;// does not allocate data
        ;// only defines a new name for an old list
        ;// lists must have a different struct if newStruct is specified

        IFDEF newList&_slist_has_link
        .ERR <slist newName already has a declared link>
        ENDIF

        IFNDEF oldList&_slist_has_link
        .ERR <slist oldName does not have a declared link>
        ENDIF

        IFB <newStruct>
        newList&_slist_assume   TEXTEQU oldList&_slist_assume
        ELSE
        newList&_slist_assume   TEXTEQU <newStruct>
        ENDIF

        newList&_slist_has_link EQU 1
        ;// newList&_slist_next TEXTEQU oldList&_slist_next

        IFB <subStruc>
            newList&_slist_next TEXTEQU oldList&_slist_next ;// <slist_pNext_&listName> ;// define pNext
        ELSE
            tttt TEXTEQU <>
            FOR ssss,<subStruc>
                tttt CATSTR tttt,<ssss>,<.>
            ENDM
            tttt CATSTR tttt,oldList&_slist_next    ;// <slist_pNext_>,<listName>
            newList&_slist_next TEXTEQU tttt
        ENDIF


        ENDM


    slist_Declare MACRO listName:req, initValue:=<0>

        IFNDEF listName&_slist_has_link
        .ERR <slist listName does not have a declared link>
        ENDIF

        IFDEF listName&_slist_is_declared
            IFNDEF listName&_slist_is_declared_external
                .ERR <slist listName is already declared>
            ENDIF
        ELSE
            listName&_slist_is_declared EQU 1           ;// prevent duplicates
        ENDIF

        listName&_slist_head    dd  initValue   ;// allocate the head

        ENDM

    slist_Declare_external MACRO listName:req

        IFNDEF listName&_slist_has_link
        .ERR <slist listName does not have a declared link>
        ENDIF
        IFDEF listName&_slist_is_declared
        .ERR <listName is already declared>
        ENDIF

        listName&_slist_is_declared EQU 1           ;// prevent duplicates
        listName&_slist_is_declared_external    EQU 1           ;// prevent duplicates

        EXTERNDEF listName&_slist_head:DWORD    ;// allocate the head

        ENDM

    slist_Declare_indirected MACRO listName:req

        listName&_slist_is_indirected EQU 1

        slist_Declare listName

        ENDM







;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////
;///
;///    list component functions        _Head(name,indirector)
;///                                    _Next(name)
;///
;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////


;// note: clumsy use of % and dual t and s variables are to make the listing
;// files easier to follow

    slist_Head  MACRO name:req, indirected

        ;// slist_Head()    enter

        LOCAL t,s

        IFNDEF name&_slist_is_declared
        .ERR <slist name is not declared>
        ENDIF

    %   s CATSTR <name>,<_slist_head>

        IFDEF name&_slist_is_indirected
            IFB <indirected>
            .ERR <slist name requires an indirector>
            ENDIF
            t TEXTEQU BRACKET(indirected)
            t CATSTR t,<.>,s
        ELSE
    %       t TEXTEQU <s>
        ENDIF

        ;// slist_Head()    exit
        EXITM t
        ENDM

    ;// ex: mov slist_Head(myList), 0

    slist_Next  MACRO name:req, reg:req

        ;// slist_Next()    enter

        LOCAL t,s

        IFNDEF name&_slist_is_declared
        .ERR <slist name is not declared>
        ENDIF

    %   s CATSTR <name>, <_slist_next>
    %   t CATSTR <BRACKET(reg)>, <.>, <s>
        ;// slist_Next()    exit
        EXITM t
        ENDM


;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////
;///
;///    list macros
;///
;///
;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////

    slist_GetFrom MACRO name:req, reg:req, src:req

        mov reg, src
    %   ASSUME reg:PTR name&_slist_assume

        ENDM

;//////////////////////////////////////////////


    slist_GetHead MACRO name:req, reg:req, indirected

        mov reg, slist_Head( name, indirected )     ;// load reg with the head
    %   ASSUME reg:PTR name&_slist_assume           ;// load reg with the head

        ENDM


    slist_OrGetHead MACRO name:req, reg:req, indirected

        or reg, slist_Head( name, indirected )  ;// or reg with the head
    %   ASSUME reg:PTR name&_slist_assume       ;// assumes the register

        ENDM


;//////////////////////////////////////////////


    slist_GetNext MACRO name:req, regNow:req, regDest

        ;// retrieves the next item from said list
        ;// user implementation must assure that regNow is valid by checking for NULL

        ;// will fail is regNow was not assumed

        IFNB <regDest>
            mov regDest, slist_Next(name, regNow)
        %   ASSUME regDest:PTR name&_slist_assume
        ELSE
            mov regNow, slist_Next(name, regNow)
        ENDIF

        ENDM


    slist_OrGetNext MACRO name:req, regNow:req, regDest

        ;// retrieves the next item from said list
        ;// user implementation must assure that regNow is valid by checking for NULL

        ;// will fail is regNow was not assumed

        IFNB <regDest>
            or regDest, slist_Next(name, regNow)
        %   ASSUME regDest:PTR name&_slist_assume
        ELSE
            or regNow, slist_Next(name, regNow)
        ENDIF

        ENDM


;//////////////////////////////////////////////

        ;// inserts a new head item
        ;// returns old head in regPrev, not assumed

        ;// does NOT check for membership

    slist_InsertHead MACRO name:req, regNow:req, regPrev:=<eax>, indirected

        ;// slist_InsertHead

        .ERRIDNI <regNow>, <regPrev>, <registers must be different>

        mov regPrev, slist_Head(name,indirected )   ;//load the old head
        mov slist_Head(name,indirected), regNow     ;// set the new head
        mov slist_Next(name,regNow), regPrev        ;//set our next pointer

    ENDM


;//////////////////////////////////////////////

    slist_RemoveHead MACRO name:req, reg1:=<eax>, indirected

        ;// do not use for empty lists

        ;// returns the new head in reg1

        slist_GetHead name, reg1, indirected
        slist_GetNext name, reg1
        mov slist_Head(name,indirected), reg1

        ENDM


;//////////////////////////////////////////////

    slist_InsertNext MACRO name:req, regNow:req, regNext:req

        ;// inserts regNext AFTER regNow
        ;// preserves both registers
        ;// will fail if registers are not already assumed

        .ERRIDNI <regNow>, <regNext>, <registers must not be the same>

        push slist_Next( name, regNow )         ;//load the item we're wanting to push back
        mov slist_Next( name, regNow), regNext  ;//insert ourseleves in the chain
        pop slist_Next( name, regNext )         ;// set the new next

        ENDM

;//////////////////////////////////////////////

    slist_RemoveNext MACRO name:req, reg:req, reg1:=<eax>

        slist_GetNext name, reg, reg1
        slist_GetNext name, reg1, reg1
        mov slist_Next(name,reg), reg1

        ENDM



;//////////////////////////////////////////////

    slist_CopyPointer MACRO  name:req, fReg:req, tReg:req

        ;// this just copies and assume the new ptr
        ;// comes in useful

        IFNDEF name&_slist_assume
%       .ERR <name not declared.>
        ENDIF

        mov tReg, fReg
%       ASSUME tReg:PTR name&_slist_assume

        ENDM


;//////////////////////////////////////////////

    ;// this has to traverse the list from the head
    ;// use with care for very long lists
    ;// this is safe to use with empty lists
    ;// and safe to use if passed reg is not in the list

    ;// fails if regNow is not assumed

    ;// preserves regNow

    slist_Remove MACRO name:req, regNow:req, reg1:=<eax>, reg2:=<edx>, indirected

        LOCAL all_done, not_head, are_head, found_it

        .ERRIDNI <regNow>, <reg1>
        .ERRIDNI <regNow>, <reg2>
        .ERRIDNI <reg1>, <reg2>

        xor reg1, reg1              ;// clear for testing
        xor reg2, reg2              ;// clear for testing
        slist_OrGetHead name, reg1, indirected  ;// get the head and test it
        jz  all_done                ;// exit if list is empty

            cmp reg1, regNow        ;// see if we are the head
            je  are_head

        not_head:

        %   ASSUME reg1:PTR name&_slist_assume
        %   ASSUME reg2:PTR name&_slist_assume

            or reg2, slist_Next(name,reg1)
            jz all_done
            cmp reg2, regNow
            je found_it

            mov reg1, reg2
            xor reg2, reg2
            jmp not_head

        found_it:
        ;// reg1 points at previous item
        ;// reg2 = reg_now

            mov reg2, slist_Next(name,reg2)
            mov slist_Next(name,reg1), reg2

            jmp all_done

        are_head:

            mov reg1, slist_Next( name, reg1)
            mov slist_Head(name,indirected), reg1

        all_done:

            and slist_Next(name,regNow), 0

        ENDM






;////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////
;///
;//     A L L O C A T I O N   M A C R O S
;//
;//

    slist_AllocateHead MACRO name:req, reg:req, siz,indirected

        ;// allocates the object, siz may be over ridden at users risk
        ;// destroys eax, edx, ecx

        IFB <siz>
            invoke GLOBALALLOC, GPTR, SIZEOF name&_slist_assume
        ELSE
            invoke GLOBALALLOC, GPTR, siz
        ENDIF

        ;// insert at the head

        IFIDNI <reg>,<eax>
    %       ASSUME reg:PTR name&_slist_assume
            slist_InsertHead name,reg,edx,indirected
        ELSE
            mov reg, eax
    %       ASSUME reg:PTR name&_slist_assume
            slist_InsertHead name, reg,,indirected
        ENDIF

        ENDM


;////////////////////////////////////////////////////////////////////////////////////////

    slist_FreeHead MACRO name:req, reg:req

        IFDEF name&_slist_is_indirected
            .ERR <can't use this for indirected lists>
        ENDIF

        IFDIFI <reg>,<esi>
        IFDIFI <reg>,<edi>
        IFDIFI <reg>,<ebx>
        .ERR <register must be esi, edi or ebx>
        ENDIF
        ENDIF
        ENDIF

        ;// this removes the head and deallocates
        ;// don't call for empty lists
        ;// returns new head in reg

        IFNDEF name&_slist_assume
%       .ERR <name not declared.>
        ENDIF

        slist_GetHead name, reg
        slist_GetNext name, reg
        invoke GLOBALFREE, slist_Head(name)
        mov slist_Head(name), reg

        ENDM






;///////////////////////////////////////////////
;///////////////////////////////////////////////
;///////////////////////////////////////////////
;//
;//     S O R T I N G   M A C R O S
;//

; AJT: bubble-sort | insertion sort == unscalable == bad idea
; if you need to have sorted lists, consider a tree instead

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


    slist_InsertSorted MACRO name:req, method:req, item:req, key_name:req, iter:=<ecx>, last:=<edx>, key:=<eax>, indirected

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
        slist_OrGetHead name, iter, indirected  ;// get and test the head
        jz set_new_head                         ;// jump if empty

        mov key, [item].key_name    ;// DWORD PTR [item+keyOfs] ;// store the key locally

        IF_SORT_TEST method, iter, key_name, key

        set_new_head:       ;// we're at the head

            ;//slist_SetHead name, item, indirected
            mov slist_Head(name,indirected), item

        .ELSE

        insert_sorted_loop:

            ;//slist_CopyPtrTo name, iter, last
            mov last, iter
            ASSUME last:PTR name&_slist_assume
            slist_GetNext name, iter
            .IF iter

                IF_NOT_SORT_TEST method, iter, key_name, key

                    jmp insert_sorted_loop

                .ENDIF
            .ENDIF

            ;// when we get here, last is the item we insert after
            ;// iter is the next item, which may be blank

            mov slist_Next( name, last ), item

        .ENDIF

        ;// finally, we store the new next
        mov slist_Next( name, item ), iter

        ENDM



;//////////////////////////////////////////////;

    slist_TextSort MACRO name:req, case:req, keyOfs:req

        ;// this routine sorts by text values
        ;// and we'll use ascending only

        ;// win32A.inc must be included before using this

        ;// case mat be CASE or NOCASE ( text literal )

        ;// keyOfs points at a value to sort by relative to the object pointers

        ;// after careful consideration, the best way to do this is to use all 6 registers
        ;// SAVE WHAT REGISTERS NEED SAVED BEFORE THIS

        ;// r1 and p1 iterate the outside loop, p1 is always the previous r1
        ;// r2 and p2 iterate the inside loop, p2 is always the previous r2
        ;// p3 is previous pointer to the lowest object

        ;// V is the current compare value

        LOCAL preperation, outter_loop, insertion_point_outter, inner_loop, insertion_point_inner, inner_loop_done
        LOCAL swap_head, swap_head_next, swap_normal, swap_next, done_with_sort

        LOCAL r1, p1, r2, p2, p3, v

        IFDEF name&_slist_is_indirected
            .ERR <can't use this for indirected lists>
        ENDIF

        r1 TEXTEQU <eax>
        p1 TEXTEQU <ebx>
        r2 TEXTEQU <ecx>
        p2 TEXTEQU <edx>
        p3 TEXTEQU <esi>
        v  TEXTEQU <edi>

%       ASSUME r1:PTR name&_slist_assume
%       ASSUME p1:PTR name&_slist_assume
%       ASSUME r2:PTR name&_slist_assume
%       ASSUME p2:PTR name&_slist_assume
%       ASSUME p3:PTR name&_slist_assume


    preperation:

        xor p1, p1
        xor r1, r1
        or  r1, slist_Head(name)    ;//name&_slist_head
        jz  done_with_sort
        jmp insertion_point_outter

    outter_loop:

        ;// save the old pointer, and load the new

        mov p1, r1
        xor r1, r1
        or  r1, slist_Next(name,p1);//[p1].name&_slist_next
        jz done_with_sort

    insertion_point_outter:

        ;// load the initial value

        lea v, DWORD PTR [r1+keyOfs]
        mov p3, 0FFFFFFFFh
        xor p2, p2
        xor r2, r2
        or r2, slist_Next(name,r1);//[r1].name&_slist_next
        jz outter_loop

        jmp insertion_point_inner

    inner_loop:

        ;// save the old pointer and load the new

        mov p2, r2
        xor r2, r2
        or r2, slist_Next(name,p2);//[p2].name&_slist_next
        jz inner_loop_done

    insertion_point_inner:

        ;// do the test

        ;// cmp v, DWORD PTR [r2+keyOfs]

        push eax
        push ecx
        push edx
        IFIDN       <case>, <CASE>
            invoke lstrcmpA, v, ADDR DWORD PTR [r2+keyOfs]
        ELSEIFIDN   <case>, <NOCASE>
            invoke lstrcmpiA, v, ADDR DWORD PTR [r2+keyOfs]
        ELSE
            .ERR <must specify CASE or NOCASE.>
        ENDIF
        pop edx
        pop ecx
        or eax, eax
        pop eax
        js  inner_loop  ;// jump if v is less than ptr r2
    ;// jz
    ;// jns
        ;//   jbe  inner_loop       ; ASCENDING


        ;// v is greater or equal to ptr r2
        ;// copy the new pointers

        mov p3, p2
        lea v, DWORD PTR [r2+keyOfs]

        jmp inner_loop

    inner_loop_done:

        ;// now we have p3 as what we want to swap with p1

        cmp p3, 0FFFFFFFFh
        je outter_loop  ;//nothing to swap

        or p1, p1
        jz swap_head

        or p3, p3
        jz swap_next

    swap_normal:  ;// we're swapping like normal
                  ;// there are four items to change
                  ;// easiest way is to do this on the stack

        mov r2, slist_Next(name,p3);//[p3].name&_slist_next

        push r1
        push slist_Next(name,r1);//[r1].name&_slist_next
        push r2
        push slist_Next(name,r2);//[r2].name&_slist_next

        pop slist_Next(name,r1);//[r1].name&_slist_next
        pop slist_Next(name,p1);//[p1].name&_slist_next
        pop slist_Next(name,r2);//[r2].name&_slist_next
        pop slist_Next(name,p3);//[p3].name&_slist_next

        mov r1, r2

        jmp outter_loop

    swap_next:    ;// were swapping the next object

        mov r2, slist_Next(name,r1);//[r1].name&_slist_next

        push slist_Next(name,r2)    ;//[r2].name&_slist_next
        mov slist_Next(name,p1),r2  ;//[p1].name&_slist_next, r2
        mov slist_Next(name,r2),r1  ;//[r2].name&_slist_next, r1
        pop slist_Next(name,r1)     ;//[r1].name&_slist_next

        mov r1, r2

        jmp outter_loop

    swap_head:    ;// we're swapping in a new head

        or p3, p3
        jz swap_head_next

        mov r2, slist_Next(name,p3) ;//[p3].name&_slist_next

        mov slist_Head(name),r2     ;//name&_slist_head, r2
        mov slist_Next(name,p3),r1  ;//[p3].name&_slist_next, r1

        push slist_Next(name,r1)    ;//[r1].name&_slist_next
        push slist_Next(name,r2)    ;//[r2].name&_slist_next

        pop slist_Next(name,r1)     ;//[r1].name&_slist_next
        pop slist_Next(name,r2)     ;//[r2].name&_slist_next

        mov r1, r2

        jmp outter_loop


    swap_head_next:

        mov r2, slist_Next(name,r1) ;//[r1].name&_slist_next

        push slist_Next(name,r2)    ;//[r2].name&_slist_next
        mov slist_Head(name),r2     ;//name&_slist_head, r2
        mov slist_Next(name,r2),r1  ;//[r2].name&_slist_next, r1
        pop slist_Next(name,r1)     ;//[r1].name&_slist_next

        mov r1, r2

        jmp outter_loop


    done_with_sort:


    ENDM


;//////////////////////////////////////////////

ENDIF   ;// _SLIST3_INCLUDED