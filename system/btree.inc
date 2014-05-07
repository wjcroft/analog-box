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
;//     btree.inc           macros for binary tree
;// 
IFNDEF _BTREE_INCLUDED_
_BTREE_INCLUDED_ EQU 1
;// 
;// TOC:
;//
;// declaritors:
;//
;//     btree_Declare_link      MACRO name:req, stru:req, key:req, key_type:REQ
;//     btree_Declare           MACRO name:req
;//     btree_Declare_external  MACRO name:req
;//
;// acessors():
;//
;//     btree_Head              MACRO name:req, indirector
;//     btree_Left              MACRO name:req, reg:req
;//     btree_Right             MACRO name:req, reg:req
;//     btree_Back              MACRO name:req, reg:req
;//
;// misc:
;//
;//     btree_Assume            MACRO name:req, reg:req
;//     btree_CopyPointer       MACRO name:req, reg_from:req, reg_to:req
;//     btree_ClearItem         MACRO name:req, item:req
;//
;// getters:
;//
;//     btree_GetHead           MACRO name:req, reg:req,indirector
;//     btree_GetLeft           MACRO name:req, reg1:req, reg2
;//     btree_GetRight          MACRO name:req, reg1:req, reg2
;//     btree_GetBack           MACRO name:req, reg1:req, reg2
;//
;//     btree_OrGetHead         MACRO name:req, reg:req,indirector
;//     btree_OrGetLeft         MACRO name:req, reg1:req, reg2:req
;//     btree_OrGetRight        MACRO name:req, reg1:req, reg2:req
;//     btree_OrGetBack         MACRO name:req, reg1:req, reg2:req
;//
;// pre post fix iterating:
;//
;//     btree_GetFirst          MACRO name:req, reg:req, indirector
;//     btree_GetLast           MACRO name:req, reg:req, indirector
;//     btree_GetNext           MACRO name:req, iter:req
;//     btree_GetPrev           MACRO name:req, iter:req
;//
;// internal use:
;//
;//     btree_LoadKey           MACRO name:req, item:req,_key:req
;//     btree_UnloadKey         MACRO name:req
;//     btree_LoadKey_this      MACRO name:req, _key:req
;//     btree_CompareKeys       MACRO name:req, item:req
;//     btree_CompareAndLoad    MACRO name:req, item:req, iter:req
;//     btree_CompareAndJump    MACRO name:req, item:req,cmp_type:req,lab:req
;//     btree_CompareAndInsert  MACRO name:req, parent:req,item:req
;//
;// searching:
;//
;//     btree_FindItem          MACRO name:req, item:req, iter:req, indirector
;//     btree_FindKey           MACRO name:req, _key:req, iter:req, indirector
;//     btree_FindThisKey       MACRO name:req, _key:req, iter:req, indirector
;//
;// insert remove
;//
;//     btree_Insert            MACRO name:req, item:req, indirector, exit_if_duplicate
;//     btree_Remove            MACRO name:req, item:req, indirector
;//     btree_InsertFlat        MACRO name:req, item:req, indirector
;//
;// balancing
;//
;//     btree_Flatten           MACRO name:req, indirector
;//     btree_Unflatten         MACRO name:req, indirector
;//     btree_Balance           MACRO name:req, indirector
;//
;// roatation
;//
;//     btree_RotateRight       MACRO name:req, item:req, indirector
;//     btree_RotateLeft        MACRO name:req, item:req, indirector


comment ~ /*

head item

    name&_btree_Head    dd  0   ;// pointer to the 'center'

node items

    name&_btree_Back    dd  0   ;// pointer to parent
    name&_btree_Left    dd  0   ;// pointer to lesser node
    name&_btree_Right   dd  0   ;// pointer to greater node

    name&_btree_Key     depends on key type
                        does NOT allocate data

*/ comment ~



        BTREE_UNSIGNED_DWORD        EQU 1
        BTREE_SIGNED_DWORD          EQU 2
        BTREE_FLOAT                 EQU 3
        BTREE_DOUBLE                EQU 4
        BTREE_UNSIGNED_EXTERNAL     EQU 5
        BTREE_SIGNED_EXTERNAL       EQU 6

        BTREE_UNSIGNED_DWORD_DUPLICATE  EQU 7   ;// allow duplicate keys
        BTREE_SIGNED_DWORD_DUPLICATE    EQU 8   ;// allow duplicate keys
        BTREE_FLOAT_DUPLICATE           EQU 9   ;// allow duplicate keys

        BTREE_UNSIGNED_BYTE_ARRAY   EQU 00010000h   ;// + length must follow
        BTREE_SIGNED_BYTE_ARRAY     EQU 00020000h   ;// + length must follow
        BTREE_UNSIGNED_DWORD_ARRAY  EQU 00040000h   ;// + length must follow
        BTREE_SIGNED_DWORD_ARRAY    EQU 00080000h   ;// + length must follow

        ;// for arrays, FindThisKey must be a pointer to another array


comment ~ /*

btrees have two states, normal and flattened

    in normal mode, the btree is a binary tree
    in flattened mode, the btree is an slist, using Back as the pNext pointer

    Flattening a btree results in a sorted slist, approx n+log(n) time

    Unflattening a sorted slist results in a btree, approx log(n) time    

    Unflattening an unsorted slist results in a broken btree

to rebalence the tree, flatten then unflatten

loading and storing

    to store: iterate in reverse order, storing each node in turn

    to reload: add each new item as the head of a flattened btree
               Unflatten

    this scheme is faster than inserting each item into the btree
        1) save btree tranversal during insert
        2) does not require re-balancing

        --> Only works if items are loaded in reverse order <--
            aka: already sorted

iterating in normal mode:

    btree_GetFirst  btree_GetNext
    btree_GetLast   btree_GetPrev

iterating in flat mode: 

    not supported with macros
    use 'mov iter, btree_Back(name,iter)'

searching in normal mode

    btree_FindKey name,key,iter

inserting and removing in normal mode

    btree_Insert name,item,iter
    btree_Remove name,item,iter

inserting and removing in flat mode

    btree_InsertFlat name,item
        always inserts at head
    remove flat is not supported with a macro

REGISTER and CPU usage

    btrees are complicated and usually require temporary registers
    usage is prioritized as eax,edx,ecx,ebx,esi
    see the macro for acual register usage

    if .686 is specified, cmov and fucomi instructions will be used
    otherwise, equivalent cmp,jmp mechanisms are used

    note: .686 does not support cmov instructions with null pointers
          the cure for this may be worked out in the future


BTREE_EXTERNAL compare modes

    user must supply a function name as the key
    the function must except two pointers, A and B
    the two pointers are to the STRUCT that the btree references
    the function must return with:

        all registers intact
        flags set EXACTLY as they would be for cmp A,B
            UNSIGNED uses carry and zero flags
            SIGNED used sign, zero and overflow flags
        stack cleaned up

    example 1: 

        my_compare_proc PROC STDCALL USES eax edx ecx ptr_A:PTR MYSTRUCT, ptr_B:PTR MYSTRUCT
            
            mov edx, ptr_A
            mov ecx, ptr_B

            ASSUME edx:PTR MYSTRUCT
            ASSUME ecx:PTR MYSTRUCT

            mov eax, [edx].my_key
            cmp eax, [ecx].my_key

            ret

        my_compare_proc ENDP

    example 2

        my_compare_proc PROC
            
            xchg edx, [esp+4]   ;// preserve and load ptr A
            xchg ecx, [esp+8]   ;// preserve and load ptr B

            ASSUME edx:PTR MYSTRUCT
            ASSUME ecx:PTR MYSTRUCT

            mov edx, [edx].my_key
            mov ecx, [ecx].my_key   

            ASSUME edx:NOTHING
            ASSUME ecx:NOTHING

            cmp ecx, edx

            mov edx, [esp+4]
            mov ecx, [esp+8]

            retn 8 ;// STDCALL 2 args

        my_compare_proc ENDP

*/ comment ~



;// equates used for different types of keys
;// don't use these, for internal use

        BTREE_ERROR         EQU 0   ;// macro error, tell author
    
    ;// how to respond to compare events    name&_btree_DecideType

        BTREE_ABOVEBELOW    EQU 1000h   ;// use ja,jb type instructions
        BTREE_GREATERLESSER EQU 2000h   ;// use jl,jg type instructions
        BTREE_BELOWABOVE    EQU 3000h   ;// use jb,ja type instructions

        BTREE_ABOVEEQUALBELOW       EQU 0A000h  ;// use jae,jb type instructions
        BTREE_GREATEREQUALLESSER    EQU 0B000h  ;// use jl,jge type instructions
        BTREE_BELOWEQUALABOVE       EQU 0A000h  ;// use jb,jae type instructions

    ;// how to load keys                    name&_btree_KeyAccess

        BTREE_VALUE         EQU     4000h   ;// key is a value
        BTREE_FPU           EQU     5000h   ;// key is loaded into fpu
        BTREE_ITEM          EQU     6000h   ;// item pointer is used
        BTREE_ARRAY         EQU 000F0000h   ;// + length must follow, loads esi, edi, and ecx

    ;// how to compare keys                 name&_btree_CompareType

        BTREE_COMPARE       EQU     7000h   ;// use cmp A,B
        BTREE_FUCOMIP       EQU     8000h   ;// use fucomip st, st(1)
        BTREE_EXTERNAL      EQU     9000h   ;// call some other function
        BTREE_CMPSB         EQU    0A000h   ;// use repe cmpsb
        BTREE_CMPSD         EQU    0B000h   ;// use repe cmpsd

    ;// private key used inside searching macros
    ;// best not to mess with this

        btree_private_key   TEXTEQU <>

;//-----------------------------------------------------------------------------
;//
;// declarators
;//                       key_type: see BTREE_UNSIGNED_DWORD
;//-----------------------------------------------------------------------------

btree_Declare_link MACRO name:req, stru:req, key:req, key_type:req

        IFDEF name&_btree_HasLink
        .ERR <name already has a declared link>
        ENDIF

        name&_btree_Left    dd  ?   ;// pointer to lower
        name&_btree_Right   dd  ?   ;// pointer to higher
        name&_btree_Back    dd  ?   ;// pointer to parent

    %   name&_btree_Key     TEXTEQU <key>

        IF      key_type EQ BTREE_UNSIGNED_DWORD
            
            name&_btree_DecideType  EQU BTREE_ABOVEBELOW
            name&_btree_KeyAccess   EQU BTREE_VALUE
            name&_btree_CompareType EQU BTREE_COMPARE

        ELSEIF key_type EQ BTREE_UNSIGNED_DWORD_DUPLICATE           
            
            name&_btree_DecideType  EQU BTREE_ABOVEEQUALBELOW
            name&_btree_KeyAccess   EQU BTREE_VALUE
            name&_btree_CompareType EQU BTREE_COMPARE

            name&_btree_Allow_Duplicate_Keys EQU 1

        ELSEIF  key_type EQ BTREE_SIGNED_DWORD

            name&_btree_DecideType  EQU BTREE_GREATERLESSER
            name&_btree_KeyAccess   EQU BTREE_VALUE
            name&_btree_CompareType EQU BTREE_COMPARE

        ELSEIF  key_type EQ BTREE_SIGNED_DWORD_DUPLICATE

            name&_btree_DecideType  EQU BTREE_GREATEREQUALLESSER
            name&_btree_KeyAccess   EQU BTREE_VALUE
            name&_btree_CompareType EQU BTREE_COMPARE

            name&_btree_Allow_Duplicate_Keys EQU 1

        ELSEIF  key_type EQ BTREE_FLOAT

            name&_btree_DecideType  EQU BTREE_BELOWABOVE
            name&_btree_KeyAccess   EQU BTREE_FPU
            name&_btree_CompareType EQU BTREE_FUCOMIP

        ELSEIF  key_type EQ BTREE_FLOAT_DUPLICATE

            name&_btree_DecideType  EQU BTREE_BELOWEQUALABOVE
            name&_btree_KeyAccess   EQU BTREE_FPU
            name&_btree_CompareType EQU BTREE_FUCOMIP

            name&_btree_Allow_Duplicate_Keys EQU 1

        ELSEIF  key_type EQ BTREE_DOUBLE

            name&_btree_DecideType  EQU BTREE_BELOWABOVE
            name&_btree_KeyAccess   EQU BTREE_FPU
            name&_btree_CompareType EQU BTREE_FUCOMIP

        ELSEIF  key_type EQ BTREE_UNSIGNED_EXTERNAL

            name&_btree_DecideType  EQU BTREE_ABOVEBELOW
            name&_btree_KeyAccess   EQU BTREE_ITEM
            name&_btree_CompareType EQU BTREE_EXTERNAL

        ELSEIF key_type EQ BTREE_SIGNED_EXTERNAL

            name&_btree_DecideType  EQU BTREE_GREATERLESSER
            name&_btree_KeyAccess   EQU BTREE_ITEM
            name&_btree_CompareType EQU BTREE_EXTERNAL


        ELSEIF (key_type AND BTREE_UNSIGNED_BYTE_ARRAY)         ;// + length must follow

            name&_btree_DecideType  EQU BTREE_ABOVEBELOW
            name&_btree_KeyAccess   EQU BTREE_ARRAY OR key_type ;// encodes length, loads esi, edi, and ecx
            name&_btree_CompareType EQU BTREE_CMPSB             ;// use repe cmpsb

        ELSEIF (key_type AND BTREE_SIGNED_BYTE_ARRAY)           ;// + length must follow

            name&_btree_DecideType  EQU BTREE_GREATERLESSER
            name&_btree_KeyAccess   EQU BTREE_ARRAY OR key_type ;// encodes length, loads esi, edi, and ecx
            name&_btree_CompareType EQU BTREE_CMPSB             ;// use repe cmpsb

        ELSEIF (key_type AND BTREE_UNSIGNED_DWORD_ARRAY)        ;// + length must follow

            name&_btree_DecideType  EQU BTREE_ABOVEBELOW
            name&_btree_KeyAccess   EQU BTREE_ARRAY OR key_type ;// encodes length, loads esi, edi, and ecx
            name&_btree_CompareType EQU BTREE_CMPSD             ;// use repe cmpsd

        ELSEIF (key_type AND BTREE_SIGNED_DWORD_ARRAY)          ;// + length must follow

            name&_btree_DecideType  EQU BTREE_GREATERLESSER
            name&_btree_KeyAccess   EQU BTREE_ARRAY OR key_type ;// encodes length, loads esi, edi, and ecx
            name&_btree_CompareType EQU BTREE_CMPSD             ;// use repe cmpsd


        ELSE

            .ERR <key_type is not a supported key type>
            name&_btree_DecideType  EQU BTREE_ERROR
            name&_btree_KeyAccess   EQU BTREE_ERROR
            name&_btree_CompareType EQU BTREE_ERROR

        ENDIF

        name&_btree_Assume  TEXTEQU <stru>
        name&_btree_HasLink EQU 1

    ENDM



btree_Declare_alias_link MACRO newname:req, oldname:req

        ;// allows one tree to take the place of another
        ;// does not allocate data
        ;// only defines a new name for an old tree
        ;// trees must have the same struct and key locations

        IFDEF newname&_btree_HasLink
        .ERR <newname already has a declared link>
        ENDIF

        IFNDEF oldname&_btree_HasLink
        .ERR <btree oldname does not have a declared link>
        ENDIF

        newname&_btree_Left         TEXTEQU <oldname&_btree_Left>
        newname&_btree_Right        TEXTEQU <oldname&_btree_Right>  
        newname&_btree_Back         TEXTEQU <oldname&_btree_Back>       

        newname&_btree_Key          TEXTEQU <oldname&_btree_Key>

        newname&_btree_DecideType   TEXTEQU <oldname&_btree_DecideType> 
        newname&_btree_KeyAccess    TEXTEQU <oldname&_btree_KeyAccess>  
        newname&_btree_CompareType  TEXTEQU <oldname&_btree_CompareType>  

        newname&_btree_Assume       TEXTEQU <oldname&_btree_Assume> 
        newname&_btree_HasLink      EQU 1

    ENDM








btree_Declare MACRO name:req

        IFNDEF name&_btree_HasLink
        .ERR <name does not have a link>
        ENDIF

        name&_btree_Head    dd  0

        name&_btree_Declared EQU 1

    ENDM

btree_Declare_indirected MACRO name:req

        IFNDEF name&_btree_HasLink
        .ERR <name does not have a link>
        ENDIF

        name&_btree_Head    dd  0

        name&_btree_Declared        EQU 1
        name&_btree_is_indirected   EQU 1

    ENDM


btree_Declare_external MACRO name:req

        IFNDEF name&_btree_HasLink
        .ERR <name does not have a link>
        ENDIF

        EXTERNDEF name&_btree_Head:DWORD    ;//     dd  0

        name&_btree_Declared EQU 1

    ENDM


;//-----------------------------------------------------------------------------
;//                 
;// accessor macro functions            use of t symbols are a workaround 
;//                                     for unworking MASM macro
;// btree_Head()
;// btree_Left()        these functions are resposible for generating
;// btree_Right()       compile errors if the btree is not setup correctly
;// btree_Back()
;//
;//-----------------------------------------------------------------------------

btree_Head MACRO name:req, indirector

    ;// btree_Head() enter

        LOCAL t

        IFNDEF name&_btree_Declared
        .ERR <name has not been declared>
        ENDIF
 
        IFDEF name&_btree_is_indirected
            IFB <indirector>
            .ERR <btree name requires an indirector>
            ENDIF
            t CATSTR BRACKET(indirector),<.>,<name>,<_btree_Head>
        ELSE
            t CATSTR <name>,<_btree_Head>
        ENDIF

    ;// btree_Head() exit

        EXITM t
 
    ENDM


btree_Left MACRO name:req, reg:req

    ;// btree_Left() enter

        LOCAL t

        IFNDEF name&_btree_Declared
        .ERR <name has not been declared>
        ENDIF

    %   t CATSTR <BRACKET(reg)>, <.>, <name>, <_btree_Left>

    ;// btree_Left() exit

        EXITM t

    ENDM

btree_Right MACRO name:req, reg:req

    ;// btree_Right() enter

        LOCAL t

        IFNDEF name&_btree_Declared
        .ERR <name has not been declared>
        ENDIF

    %   t CATSTR <BRACKET(reg)>, <.>, <name>, <_btree_Right>

    ;// btree_Right() exit

        EXITM t

    ENDM


btree_Back MACRO name:req, reg:req

    ;// btree_Back() enter

        LOCAL t

        IFNDEF name&_btree_Declared
        .ERR <name has not been declared>
        ENDIF

    %   t CATSTR <BRACKET(reg)>, <.>, <name>, <_btree_Back>

    ;// btree_Back() exit

        EXITM t

    ENDM


;//-----------------------------------------------------------------------------
;//     
;//     misc helpers        Assume
;//                         CopyPointer
;//                         ClearItem
;//
;//-----------------------------------------------------------------------------

btree_Assume MACRO name:req, reg:req

        IFNDEF name&_btree_Declared
        .ERR <name has not been declared>
        ENDIF

        ASSUME reg:PTR name&_btree_Assume

    ENDM

btree_CopyPointer MACRO name:req, reg_from:req, reg_to:req

        mov reg_to, reg_from
        btree_Assume name, reg_to

    ENDM

btree_ClearItem MACRO name:req, item:req

    ;// clears the pointers

        xor eax, eax
        mov btree_Left(name,item), eax
        mov btree_Right(name,item), eax
        mov btree_Back(name,item), eax

    ENDM



;//-----------------------------------------------------------------------------
;//
;//     GetHead      OrGetHead      
;//     GetLeft      OrGetLeft      
;//     GetRight     OrGetRight     
;//     GetBack      OrGetBack      
;//
;//-----------------------------------------------------------------------------

btree_GetHead MACRO name:req, reg:req,indirector

        mov reg, btree_Head(name,indirector)
        btree_Assume name,reg

    ENDM

btree_GetLeft MACRO name:req, reg1:req, reg2

        IFB <reg2>
            mov reg1, btree_Left(name,reg1)
        ELSE
            mov reg2, btree_Left(name,reg1)
            btree_Assume name,reg2
        ENDIF

    ENDM

btree_GetRight MACRO name:req, reg1:req, reg2

        IFB <reg2>
            mov reg1, btree_Right(name,reg1)
        ELSE
            mov reg2, btree_Right(name,reg1)
            btree_Assume name,reg2
        ENDIF

    ENDM

btree_GetBack MACRO name:req, reg1:req, reg2

        IFB <reg2>
            mov reg1, btree_Back(name,reg1)
        ELSE
            mov reg2, btree_Back(name,reg1)
            btree_Assume name,reg2
        ENDIF

    ENDM


btree_OrGetHead MACRO name:req, reg:req,indirector

        or reg, btree_Head(name,indirector)
        btree_Assume name,reg

    ENDM

btree_OrGetLeft MACRO name:req, reg1:req, reg2:req

        or reg2, btree_Left(name,reg1)
        btree_Assume name,reg2

    ENDM

btree_OrGetRight MACRO name:req, reg1:req, reg2:req

        or reg2, btree_Right(name,reg1)
        btree_Assume name,reg2

    ENDM

btree_OrGetBack MACRO name:req, reg1:req, reg2:req

        or reg2, btree_Back(name,reg1)
        btree_Assume name,reg2

    ENDM




;//-----------------------------------------------------------------------------
;//
;// GetFirst            or GetLowest
;// GetLast             or GetHighest
;//
;// GetNext
;// GetPrev
;//
;//-----------------------------------------------------------------------------

btree_GetFirst MACRO name:req, reg:req, indirector

    ;// destroys eax

        LOCAL F0,F1

    .ERRIDNI <reg>,<eax>,<can't use eax as the iterator>
        
        xor reg,reg
        btree_Assume name,reg
        btree_GetHead name,eax,indirector
    F1: test eax, eax
        jz F0
        mov reg,eax     
        mov eax, btree_Left(name,eax)
        test eax, eax
        jz F0
        mov reg, eax
        mov eax, btree_Left(name,eax)
        jmp F1
    F0:

    ENDM

btree_GetLast MACRO name:req, reg:req, indirector

    ;// destroys eax

        LOCAL F0,F1

    .ERRIDNI <reg>,<eax>,<can't use eax as the iterator>
        
        xor reg,reg
        btree_Assume name,reg
        btree_GetHead name,eax,indirector
    F1: test eax, eax
        jz F0
        mov reg,eax
        mov eax, btree_Right(name,eax)
        test eax, eax
        jz F0
        mov reg, eax
        mov eax, btree_Right(name,eax)
        jmp F1
    F0:

    ENDM


    comment ~ /*

    GetNext

        if can_go_right
            
            go_right

    N0      while(can_go_left)  go_left
            return

    N1  else repeat go_back
             until !iter || !was_right

    N2      return


    */ comment ~

btree_GetNext MACRO name:req, iter:req

    ;// destroys eax

    ;// also means, 'find the next highest value'
    ;// returns iter=0 if not found

            LOCAL N0,N1,N2

    .ERRIDNI <iter>,<eax>,<can't use eax as the iterator>

            xor eax,eax

        ;// if can_go_right     
            or eax, btree_Right(name,iter)
            jz N1
        ;// go right
    N0:     mov iter, eax
        ;// while(can_go_left) go_left
            mov eax, btree_Left(name,iter)      
            test eax, eax
            jnz N0
            jmp N2
        ;// else go_back
    N1:     mov eax, iter
            mov iter,btree_Back(name,iter)
        ;// until ! iter
            test iter, iter
            jz N2
        ;// or until ! was_right
            cmp eax, btree_Right(name,iter)
            je N1

    N2: ;// return

    ENDM


    comment ~ /*

    GetPrev

        if can_go_left 
            
            go_left 

    P0      while(can_go_right) go_right
            return

    P1  else repeat go_back
             until !iter || !was_left 

    P2      return


    */ comment ~


btree_GetPrev MACRO name:req, iter:req

    ;// destroys eax

    ;// also means, 'find the next lowest value'
    ;// returns iter=0 if not found

            LOCAL P0,P1,P2

    .ERRIDNI <iter>,<eax>,<can't use eax as the iterator>

            xor eax,eax

        ;// if can_go_left      
            or eax, btree_Left(name,iter)
            jz P1
        ;// go left
    P0:     mov iter, eax
        ;// while(can_go_right) go_right
            mov eax, btree_Right(name,iter)     
            test eax, eax
            jnz P0
            jmp P2
        ;// else go_back
    P1:     mov eax, iter
            mov iter,btree_Back(name,iter)
        ;// until ! iter
            test iter, iter
            jz P2
        ;// or until ! was_left
            cmp eax, btree_Left(name,iter)
            je P1

    P2: ;// return

    ENDM





;//---------------------------------------------------------------internal use
;//
;//     LoadKey         used by types to prepare for multiple comparisons
;//     UnloadKey      
;//
;//---------------------------------------------------------------------------

btree_LoadKey   MACRO name:req,item:req,_key:req

        .ERRNB btree_private_key ,< private_key is still defined !!>

        IF      name&_btree_KeyAccess EQ BTREE_VALUE

            ;// key is the value to be tested, load it

            btree_private_key TEXTEQU <_key>

            mov btree_private_key, [item].name&_btree_Key

        ELSEIF  name&_btree_KeyAccess EQ BTREE_FPU 

            ;// key is st(0) in FPU, load it

            btree_private_key TEXTEQU <_key>    ;// dummy value

            fld [item].name&_btree_Key  ;// load into fpu

        ELSEIF  name&_btree_KeyAccess EQ BTREE_ITEM

            ;// key is the item pointer, load it

            btree_private_key TEXTEQU <_key>
            mov btree_private_key, item

        ELSEIF (name&_btree_KeyAccess AND BTREE_ARRAY)
    
            ;// key is the start of an array compare, load it

            btree_private_key TEXTEQU <_key>
            lea btree_private_key, [item].name&_btree_Key

        ELSE
            .ERR <some how KeyAccess was not defined>
        ENDIF

    ENDM


btree_UnloadKey   MACRO name:req

        .ERRB btree_private_key,<need to use btree_LoadKey before this>

        IF      name&_btree_KeyAccess EQ BTREE_VALUE

            ;// _key is a register, do nothing

        ELSEIF  name&_btree_KeyAccess EQ BTREE_FPU 

            ;// _key is an fpu register, free it
            
            fstp st

        ELSEIF  name&_btree_KeyAccess EQ BTREE_ITEM

            ;// _key is the source item we're comparing with, do nothing

        ELSEIF (name&_btree_KeyAccess AND BTREE_ARRAY)

            ;// _key is part of an lea instruction, do nothing

        ELSE
            .ERR <some how KeyAccess was not defined>
        ENDIF

        btree_private_key TEXTEQU <>

    ENDM



btree_LoadKey_this  MACRO name:req,_key:req

    ;// _this means that the key is already loaded
    ;// all we need to do is define btree_private_key
    ;// used by FindThisKey

        .ERRNB btree_private_key ,< private_key is still defined !!>

        IFE (name&_btree_CompareType-BTREE_EXTERNAL)
        ECHO <btree LoadKey this: not tested for external compare types>
        ENDIF

        IF      name&_btree_KeyAccess EQ BTREE_VALUE

            ;// key is the value to be tested, load it

            btree_private_key TEXTEQU <_key>

            ;// mov btree_private_key, [item].name&_btree_Key

        ELSEIF  name&_btree_KeyAccess EQ BTREE_FPU 

            ;// key is st(0) in FPU, load it

            btree_private_key TEXTEQU <_key>    ;// dummy value

            ;// fld [item].name&_btree_Key      ;// already loaded

        ELSEIF  name&_btree_KeyAccess EQ BTREE_ITEM

            ;// key is the item pointer, load it

            btree_private_key TEXTEQU <_key>
            
            ;// mov btree_private_key, item

        ELSEIF (name&_btree_KeyAccess AND BTREE_ARRAY)

            ;// _key is part of an lea instruction          
            ECHO <not fully tested !!>


            ;// _key is a pointer to another item
            btree_private_key TEXTEQU <_key>

            ;// btree_private_key TEXTEQU <item>
            ;// <[item].name&_btree_Key>

        ELSE
            .ERR <some how KeyAccess was not defined>
        ENDIF

    ENDM










;//---------------------------------------------------------------  internal use
;//
;//     CompareKeys     must use LoadKey before this
;//                     must use UnloadKey after this
;//
;// purpose: compare _key with item and set the CPU e-flags accordingly
;//          to be used in conjunction with 
;//             btree_JumpAfterCompare
;//             btree_CompareAndInsert
;//-----------------------------------------------------------------------------

btree_CompareKeys MACRO name:req,item:req

        .ERRB btree_private_key,<need to use btree_LoadKey before this>

        IF      name&_btree_CompareType EQ BTREE_COMPARE ;// use cmp A,B

            ;// key is a register

            cmp btree_private_key, [item].name&_btree_Key

        ELSEIF  name&_btree_CompareType EQ BTREE_FUCOMIP ;// use fucomip st, st(1)

            ;// key is st(0) in fpu

            fld [item].name&_btree_Key
            IF  @Cpu AND 1000000y
                %echo btree CompareKeys Pentium Pro instructions enabled.
                fucomip st, st(1)           ;// note: carry flag is reversed
            ELSE
            %echo warning, untested popf word, verify       
            %echo need to use sloppy sahf, can't store sw to an indirect register
                sub esp,2
                fucomp st, st(1)
                fnstsw WORD PTR [esp]                               
                popf    ;// should pop a word, should not mess up direction flag
            ENDIF

        ELSEIF  name&_btree_CompareType EQ BTREE_EXTERNAL ;// call some other function

            ;// btree_private_key is item to compare against
            push item
            push btree_private_key
            call name&_btree_Key

        ELSEIF  name&_btree_CompareType EQ BTREE_CMPSB

            push esi
            push edi
            push ecx
            lea esi, [item].name&_btree_Key
            mov edi, btree_private_key
            mov ecx, name&_btree_KeyAccess AND 0FFFFh 
            xchg esi, edi   ;// otherwise strings compare in wrong order
            repe cmpsb          
            pop ecx
            pop edi
            pop esi

        ELSEIF  name&_btree_CompareType EQ BTREE_CMPSD
            
            push esi
            push edi
            push ecx
            lea esi, [item].name&_btree_Key
            mov edi, btree_private_key
            xchg esi, edi   ;// otherwise strings compare in wrong order
            mov ecx, name&_btree_KeyAccess AND 0FFFFh 
            repe cmpsd
            pop ecx
            pop edi
            pop esi

        ELSE
        .ERR <somehow CompareType wasn't set>
        ENDIF

    ENDM




btree_CompareAndLoad MACRO name:req, item:req, iter:req

    ;// preserves all registers

    ;// used in FindKey

    ;// this macro compares keys and loads an iterator with desired left,right
    ;// note that we STOP if Allow_Duplicate_Keys

    ;// if _key < item.key  iter = item.left    
    ;// if _key > item.key  iter = item.right
    ;// if _key ==item.key  do nothing

        .ERRB btree_private_key ,<need to use btree_LoadKey before this>

    ;// compare the items

        btree_CompareKeys name,item

    ;// decide how to proceed

    ;// NOTE: 
    ;// this code will cause GPF because cmov will load value at address 0
    ;// this is dumb !!
    ;// thus we disable the code
comment ~ /*
        IF  @Cpu AND 1000000y
        ;//  %echo Pentium Pro instructions enabled.
        
            IF      name&_btree_DecideType EQ BTREE_ABOVEBELOW

                cmovb iter, btree_Left(name,item)
                cmova iter, btree_Right(name,item)

            ELSEIF  name&_btree_DecideType EQ BTREE_GREATERLESSER

                cmovl iter, btree_Left(name,item)
                cmovg iter, btree_Right(name,item)

            ELSEIF  name&_btree_DecideType EQ BTREE_BELOWABOVE

                cmova iter, btree_Left(name,item)  ;// float compares are backwards
                cmovb iter, btree_Right(name,item)

            ELSE
                .ERR <some how _btreeDecsicionType was not defined
            ENDIF

        ELSE
*/ comment ~
        ;// %echo Pentium Pro instructions Not enabled.

            IF      name&_btree_DecideType EQ BTREE_ABOVEBELOW

                .IF !ZERO?
                ;// cmovb iter, btree_Left(name,item)
                    .IF CARRY?
                        mov iter, btree_Left(name,item)
                    .ELSE
                ;// cmova iter, btree_Right(name,item)
                        mov iter, btree_Right(name,item)
                    .ENDIF
                .ENDIF              

            ELSEIF  name&_btree_DecideType EQ BTREE_ABOVEEQUALBELOW

                .IF !ZERO?
                ;// cmovb iter, btree_Left(name,item)
                    .IF CARRY?
                        mov iter, btree_Left(name,item)
                    .ELSE
                ;// cmova iter, btree_Right(name,item)
                        mov iter, btree_Right(name,item)
                    .ENDIF
                .ENDIF              

            ELSEIF  name&_btree_DecideType EQ BTREE_GREATERLESSER

                .IF !ZERO?
                    .IF SIGN?
                ;//cmovl iter, btree_Left(name,item)
                        mov iter, btree_Left(name,item)
                    .ELSE               
                ;//cmovg iter, btree_Right(name,item)
                        mov iter, btree_Right(name,item)
                    .ENDIF
                .ENDIF

            ELSEIF  name&_btree_DecideType EQ BTREE_GREATEREQUALLESSER

                .IF !ZERO?
                    .IF SIGN?
                ;//cmovl iter, btree_Left(name,item)
                        mov iter, btree_Left(name,item)
                    .ELSE               
                ;//cmovg iter, btree_Right(name,item)
                        mov iter, btree_Right(name,item)
                    .ENDIF
                .ENDIF

            ELSEIF  name&_btree_DecideType EQ BTREE_BELOWABOVE

                .IF !ZERO?
                    .IF !CARRY?
                ;//cmova iter, btree_Left(name,item)  ;// float compares are backwards
                        mov iter, btree_Left(name,item)
                    .ELSE
                ;//cmovb iter, btree_Right(name,item)
                        mov iter, btree_Right(name,item)
                    .ENDIF
                .ENDIF              

            ELSE
                .ERR <some how name&_btree_DecideType was not defined
            ENDIF

;//     ENDIF

    ;// that's it

    ENDM


btree_CompareAndLoadInsert MACRO name:req, item:req, iter:req

    ;// preserves all registers

    ;// used in Insert

    ;// this macro compares keys and loads an iterator with desired left,right

    ;// if _key < item.key  iter = item.left    
    ;// if _key >= item.key iter = item.right   
    ;// ^^^ note that for Allow_Duplicate we ALWAYS navigate somewhere

        .ERRB btree_private_key ,<need to use btree_LoadKey before this>

    ;// compare the items

        btree_CompareKeys name,item

    ;// decide how to proceed

    ;// NOTE: 
    ;// this code will cause GPF because cmov will load value at address 0
    ;// this is dumb !!
    ;// thus we disable the code
comment ~ /*
        IF  @Cpu AND 1000000y
        ;//  %echo Pentium Pro instructions enabled.
        
            IF      name&_btree_DecideType EQ BTREE_ABOVEBELOW

                cmovb iter, btree_Left(name,item)
                cmova iter, btree_Right(name,item)

            ELSEIF  name&_btree_DecideType EQ BTREE_GREATERLESSER

                cmovl iter, btree_Left(name,item)
                cmovg iter, btree_Right(name,item)

            ELSEIF  name&_btree_DecideType EQ BTREE_BELOWABOVE

                cmova iter, btree_Left(name,item)  ;// float compares are backwards
                cmovb iter, btree_Right(name,item)

            ELSE
                .ERR <some how _btreeDecsicionType was not defined
            ENDIF

        ELSE
*/ comment ~
        ;// %echo Pentium Pro instructions Not enabled.

            IF      name&_btree_DecideType EQ BTREE_ABOVEBELOW

                .IF !ZERO?
                ;// cmovb iter, btree_Left(name,item)
                    .IF CARRY?
                        mov iter, btree_Left(name,item)
                    .ELSE
                ;// cmova iter, btree_Right(name,item)
                        mov iter, btree_Right(name,item)
                    .ENDIF
                .ENDIF              

            ELSEIF  name&_btree_DecideType EQ BTREE_ABOVEEQUALBELOW
                
                ;// cmovb iter, btree_Left(name,item)
                    .IF CARRY?
                        mov iter, btree_Left(name,item)
                    .ELSE
                ;// cmovae iter, btree_Right(name,item)
                        mov iter, btree_Right(name,item)
                    .ENDIF

            ELSEIF  name&_btree_DecideType EQ BTREE_GREATERLESSER

                .IF !ZERO?
                    .IF SIGN?
                ;//cmovl iter, btree_Left(name,item)
                        mov iter, btree_Left(name,item)
                    .ELSE               
                ;//cmovg iter, btree_Right(name,item)
                        mov iter, btree_Right(name,item)
                    .ENDIF
                .ENDIF

            ELSEIF  name&_btree_DecideType EQ BTREE_GREATEREQUALLESSER

                    .IF SIGN?
                ;//cmovl iter, btree_Left(name,item)
                        mov iter, btree_Left(name,item)
                    .ELSE               
                ;//cmovge iter, btree_Right(name,item)
                        mov iter, btree_Right(name,item)
                    .ENDIF

            ELSEIF  name&_btree_DecideType EQ BTREE_BELOWABOVE

                .IF !ZERO?
                    .IF !CARRY?
                ;//cmova iter, btree_Left(name,item)  ;// float compares are backwards
                        mov iter, btree_Left(name,item)
                    .ELSE
                ;//cmovb iter, btree_Right(name,item)
                        mov iter, btree_Right(name,item)
                    .ENDIF
                .ENDIF              

            ELSEIF  name&_btree_DecideType EQ BTREE_BELOWEQUALABOVE

            
                    .IF !CARRY?
                ;//cmova iter, btree_Left(name,item)  ;// float compares are backwards
                        mov iter, btree_Left(name,item)
                    .ELSE
                ;//cmovb iter, btree_Right(name,item)
                        mov iter, btree_Right(name,item)
                    .ENDIF
            

            ELSE
                .ERR <some how name&_btree_DecideType was not defined
            ENDIF

;//     ENDIF

    ;// that's it

    ENDM





btree_CompareAndJump MACRO name:req, item:req, cmp_type:req, lab:req

    ;// used in FindAfterThisKey

    ;// example
    ;//
    ;//     CompareAndJump item,BTREE_ABOVE,above_label
    ;//
    ;//     will jump to above_label if private_key > item.key

    ;// quick parameter check

        IFIDN       <cmp_type>,<BTREE_BELOW>
        ELSEIFIDN   <cmp_type>,<BTREE_ABOVE>
        ELSE
            .ERR <cmp_type unknown compare type, use BTREE_ABOVE or BTREE_BELOW>
        ENDIF

        .ERRB btree_private_key,<need to use btree_LoadKey before this>

    ;// compare keys

        btree_CompareKeys name,item

    ;// decide how to proceed

        IF      name&_btree_DecideType EQ BTREE_ABOVEBELOW

            IFIDN            <cmp_type>,<BTREE_BELOW>
                    jb lab
            ELSE             ;// IFIDN   <cmp_type>,<BTREE_ABOVE>
                    ja lab
            ENDIF

        ELSEIF  name&_btree_DecideType EQ BTREE_ABOVEEQUALBELOW

            IFIDN            <cmp_type>,<BTREE_BELOW>
                    jb lab
            ELSE             ;// IFIDN   <cmp_type>,<BTREE_ABOVE>
                    jae lab
            ENDIF

        ELSEIF  name&_btree_DecideType EQ BTREE_GREATERLESSER

            IFIDN           <cmp_type>,<BTREE_BELOW>
                    jl lab
            ELSE            ;// IFIDN   <cmp_type>,<BTREE_ABOVE>
                    jg lab
            ENDIF

        ELSEIF  name&_btree_DecideType EQ BTREE_GREATEREQUALLESSER

            IFIDN           <cmp_type>,<BTREE_BELOW>
                    jl lab
            ELSE            ;// IFIDN   <cmp_type>,<BTREE_ABOVE>
                    jge lab
            ENDIF

        ELSEIF  name&_btree_DecideType EQ BTREE_BELOWABOVE

            IFIDN           <cmp_type>,<BTREE_BELOW>
                    ja lab  ;// float compares are backwards
            ELSE            ;// IFIDN   <cmp_type>,<BTREE_ABOVE>
                    jb lab
            ENDIF
        
        ELSEIF  name&_btree_DecideType EQ BTREE_BELOWEQUALABOVE

            IFIDN           <cmp_type>,<BTREE_BELOW>
                    ja lab  ;// float compares are backwards
            ELSE            ;// IFIDN   <cmp_type>,<BTREE_ABOVE>
                    jbe lab
            ENDIF
        
        ELSE            
            .ERR <some how _btreeDecsicionType was not defined
        ENDIF

    ENDM



btree_CompareAndInsert MACRO name:req,parent:req,item:req

    ;// used in Insert
    ;// this puts item in correct relation to parent, either left or right

        LOCAL A0, C0

    ;// compare keys

        .ERRB btree_private_key,<need to use btree_LoadKey before this>

    ;// DEBUG_IF <btree_Left(name,parent)>  ;// can't insert here !!
    ;// DEBUG_IF <btree_Right(name,parent)> ;// can't insert here !!

        btree_CompareKeys name,parent
        IFNDEF name&_btree_Allow_Duplicate_Keys
        DEBUG_IF <ZERO?>    ;// not supposed to be equal !!
        ENDIF

    ;// decide how to proceed

        IF      name&_btree_DecideType EQ BTREE_ABOVEBELOW

                ja  A0
                mov btree_Left(name,parent), item
                jmp C0
            A0: mov btree_Right(name,parent), item

        ELSEIF  name&_btree_DecideType EQ BTREE_ABOVEEQUALBELOW

                jae A0
                mov btree_Left(name,parent), item
                jmp C0
            A0: mov btree_Right(name,parent), item

        ELSEIF  name&_btree_DecideType EQ BTREE_GREATERLESSER

                jg  A0
                mov btree_Left(name,parent), item
                jmp C0
            A0: mov btree_Right(name,parent), item

        ELSEIF  name&_btree_DecideType EQ BTREE_GREATEREQUALLESSER

                jge A0
                mov btree_Left(name,parent), item
                jmp C0
            A0: mov btree_Right(name,parent), item

        ELSEIF  name&_btree_DecideType EQ BTREE_BELOWABOVE

                jb  A0  ;// float compares are backwards
                mov btree_Left(name,parent), item
                jmp C0
            A0: mov btree_Right(name,parent), item

        ELSE            
            .ERR <some how name _btreeDecsicionType was not defined
        ENDIF

    ;// set the back pointer

            C0: mov btree_Back(name,item), parent

    ENDM





;//-----------------------------------------------------------------------------
;//
;// FindItem    macro loads search key
;// FindKey     user loads search key and defines private key
;// FindThisKey user loads key, macro defines private key
;//
;// both return iter as non-zero for found, zero for not found
;// be sure to test iter,iter to make sure item was found
;//
;//-----------------------------------------------------------------------------

btree_FindItem MACRO name:req, item:req, iter:req, indirector

    ;// uses eax

    .ERRIDNI <iter>,<eax>,<can't use eax as the iterator>
    .ERRIDNI <item>,<eax>,<can't use eax as the node>

        btree_GetHead name, iter, indirector
        btree_LoadKey name,item,eax
        .REPEAT
            test iter, iter
            .BREAK .IF ZERO?    ;// not found           
            btree_CompareAndLoad name,iter,iter
        .UNTIL ZERO?

        btree_UnloadKey name

    ENDM

btree_FindKey MACRO name:req, _key:req, iter:req, indirector

    ;// caller must load the key correctly, see btree_LoadKey, 
    ;// but don't mess with btree_private_key
    ;// preserves all registers except those passed

    ;// note: it's easier to use FindThisKey

        btree_private_key TEXTEQU <_key>

        btree_GetHead name, iter, indirector
        .REPEAT
            test iter, iter
            .BREAK .IF ZERO?            
            btree_CompareAndLoad name,iter,iter        
        .UNTIL ZERO?

    ;// caller must unload key correctly, see btree_UnloadKey, but don't mess with btree_private_key

        btree_private_key TEXTEQU <>

    ENDM


btree_FindThisKey MACRO name:req, _key:req, iter:req, indirector

    ;// uses eax

    ;//.ERRIDNI <iter>,<eax>,<can't use eax as the iterator>
    ;//.ERRIDNI <item>,<eax>,<can't use eax as the node>

        btree_GetHead name, iter, indirector
        btree_LoadKey_this name,_key
        .REPEAT
            test iter, iter
            .BREAK .IF ZERO?            
            btree_CompareAndLoad name,iter,iter
        .UNTIL ZERO?

        btree_UnloadKey name

    ENDM




btree_FindAfterThisKey MACRO name:req, _key:req, iter:req, indirector

    ;// determine the item whos key is above this key
    ;// if key already exists, then return the next item

    ;// destroys eax,edx
    ;// eax may be used as the key to find, it WILL be destroyed
    
    ;// alway test iter,iter to determine if anything was found

    ;// recommended that this be put in a function

    ;// scheme:
    ;// locate where to insert = P
    ;// if key above P, return P.next
    ;// else return P

    LOCAL insert_here, get_next, search_done, find_all_done

    .ERRIDNI <_key>,<edx>,<can't use edx as the key>
    .ERRIDNI <iter>,<edx>,<can't use edx as the iterator>

    IFDEF name&_btree_Allow_Duplicate_Keys
    ECHO <btree_FindAfterThisKey: this will not work for duplicate keys !!>
    ENDIF

    ;// always clear the iter

        xor iter, iter
        btree_Assume name,iter

    ;// determine where to insert
    ;// always check for empty tree

        btree_GetHead name, edx, indirector
        test edx, edx
        jz find_all_done

    ;// prepare to locate iter as where we insert

        btree_LoadKey_this name,_key    ;// define btree_private_key

        .REPEAT

            test edx, edx   ;// empty node ?
            jz insert_here  ;// then we insert
            
            mov iter, edx   ;// next search
            btree_CompareAndLoad name,iter,edx

        .UNTIL ZERO?

    ;// if we hit this, we found a duplicate key

        jmp get_next    ;// duplicate key, iter has where the key is

    insert_here:

    ;// iter is now at where we insert
    ;// if _key is BELOW iter.key return iter
    ;// else return iter.next       

        btree_CompareAndJump name,iter,BTREE_BELOW,search_done

    get_next:

    ;// we are to return the next item
    ;// iter must be valid

        btree_GetNext name,iter

    search_done:

        btree_UnloadKey name

    find_all_done:

    ENDM

        




;//-----------------------------------------------------------------------------
;//
;// Insert
;//
;//-----------------------------------------------------------------------------

btree_Insert MACRO name:req, item:req, indirector

    ;// destroys eax,edx,ecx
    ;// recommended that this be put in a function

    ;// returns zero flag if key already exists
    ;// returns ecx as where we inserted
    ;// if already exists, ecx is the duplicate key
    
    LOCAL insert_here, insert_done

    .ERRIDNI <item>,<eax>,<can't use eax as the node>
    .ERRIDNI <item>,<edx>,<can't use edx as the node>
    .ERRIDNI <item>,<ecx>,<can't use ecx as the node>

    ;// find where to insert
    ;// if same key, return that the key already exists
    ;// this also complicates the balancing detection

    ;// always check for empty tree

        btree_GetHead name, edx, indirector
        .IF !edx

            mov btree_Head(name,indirector), item
            mov ecx, item   ;// return where
            test ecx, ecx   ;// must return non zero
            ;// return to normal exit (don't bother with key unload)

        .ELSE

        ;// prepare to locate ecx as where we insert

            btree_LoadKey name,item,eax     ;// define btree_private_key
            xor ecx, ecx
            btree_Assume name,ecx

            .REPEAT

                test edx, edx   ;// empty node ?
                jz insert_here  ;// then we insert

                mov ecx, edx    ;// next search
                btree_CompareAndLoadInsert name,ecx,edx

            IFDEF name&_btree_Allow_Duplicate_Keys
            .UNTIL 0        ;// always insert
            ELSE
            .UNTIL ZERO?    ;// if we hit this, we found a duplicate key
            jmp insert_done ;// duplicate key, 
                            ;//     ecx has where the key is
                            ;//     zero flag is set
            ENDIF

        insert_here:

        ;// time to insert, ecx is where to insert

            btree_CompareAndInsert name,ecx,item

        insert_done:

            btree_UnloadKey name
        
        .ENDIF

    ENDM


;//-----------------------------------------------------------------------------
;//
;// Remove
;//
;//-----------------------------------------------------------------------------
;//
;// this is complicated there are 5 cases to deal with
;// 
;//     U = Z.back          .  nil node                                 
;//     V = Z.right         ~  items changed                            
;//     W = Z.left          |  don't know left/right without checking   
;//                         || may be a longer chain                    
;// 
;//     if needed, locate Y as the leftest V
;//     P = Y.back
;//     X = Y.right, may be zero
;// 
;//     note:   P.next and U.next means determine wheather it should be left or right
;//             always check for U = 0, meaning it's the head
;// 
;// -----------------------------------------------
;// 
;// CASE 0: W==0 V==0
;// 
;//         U           U
;//         |           .
;//         Z           
;//        . .
;// 
;//     Y = 0   U.next(Z) = 0
;// 
;// -----------------------------------------------
;// 
;// CASE 1R: W==0 V!=0  
;// 
;//         U           U   
;//         |           ~   
;//         Z           V   
;//        . \         / \
;//           V        
;//          / \                
;//           
;//     Y = V   U.next(Z) = V   V.back = U
;// 
;// -----------------------------------------------
;// 
;// CASE 1L: W!=0 V==0      
;// 
;//         U           U   
;//         |           ~   
;//         Z           W   
;//        / .         / \     
;//       W                         
;//      / \
;//     
;//     Y = W   U.next(Z) = Y   Y.back = U    
;// 
;// -----------------------------------------------
;// 
;// CASE 2a: W!=0 V!=0 locateY Y==V
;// 
;//         U               U   
;//         |               ~   
;//         Z               V   
;//        / \             ~ \  
;//       W   V           W   
;//      / \ . \         / \ 
;//            
;//     W.back = V
;//     V.left = W
;// 
;//     Y = V   U.next(Z) = Y   V.back = U
;// 
;// -----------------------------------------------
;// 
;// CASE 2b:   W!=0 V!=0 locate Y Y!=V  
;// 
;//         U               U
;//         |               ~       
;//         Z               Y       
;//        / \             ~ ~      
;//       W   V           W   V                                                     
;//      / \  ||         / \  || 
;//           P               P  
;//          / \             ~ \ 
;//         Y               X                                                   
;//        . \             / \   
;//           X 
;//          / \
;// 
;//     X = Y.right                                         <- X might be zero
;//     P = Y.back    P.left=X    X.back=P    done with P X
;//     V = Z.right   V.back=Y    Y.right=V   done with V
;//     W = Z.left    W.back=Y    Y.left=W    done with W
;//     U = Z.back    U.next=Y    Y.back=U    done with U   <- acount for left right and head


btree_Remove MACRO name:req, item:req, indirector

    ;// destroys eax,edx,ecx

        LOCAL regVPU,regWX,regY,regZ
        LOCAL locate_Y, connect_U, all_done

        .ERRIDNI <item>,<eax>,<cant use eax for node>
        .ERRIDNI <item>,<edx>,<cant use eax for node>
        .ERRIDNI <item>,<ecx>,<cant use eax for node>

    ;// registers are reused, capital letters indicate the order

        regVPU  TEXTEQU <eax>   ;// first it's V then it's P then it's U
        regWX   TEXTEQU <edx>   ;// first it's W then it's X
        regY    TEXTEQU <ecx>
        regZ    TEXTEQU <item>

        xor regWX,regWX
        sub regVPU,regVPU
        xor regY,regY
        
        btree_OrGetLeft name,regZ,regWX     ;// !W ?
        .IF ZERO?

            btree_OrGetRight name,regZ,regVPU
            ;// CASE 0: W==0 V==0           redblack

            jz connect_U

            ;// CASE 1R: W==0 V!=0          redblack

            xchg regY, regVPU   ;// regY was zero, now regVPU is zero
            jmp connect_U

        .ENDIF
                                            
        btree_OrGetRight name,regZ,regVPU   ;// have W
        .IF ZERO?                           ;// !V ?  
            
            ;// CASE 1L: W!=0 V==0

            mov regY, regWX 
            jmp connect_U   ;// regVPU already zero

        .ENDIF

        btree_OrGetLeft name,regVPU,regY    ;// have W and V
        .IF ZERO?                           ;// Y==V ?

        ;// CASE 2a: W!=0 V!=0 locateY Y==V

        ;//    W.back = V
        ;//    V.left = W

            mov btree_Back(name,regWX), regVPU
            mov btree_Left(name,regVPU), regWX

        ;//    U.next(Z) = V    
        ;//    V.back = U

            xchg regY, regVPU   ;// regY was zero
            jmp connect_U

        .ENDIF
    
    ;// CASE 2b:   W!=0 V!=0 locate Y Y!=V  redblack
    ;// 
    ;//         U               U           P=P 
    ;//         |               ~           X=X
    ;//         Z               Y           W=P.right
    ;//        / \             ~ ~          copy Z color to V
    ;//       W   V           W   V         color = X.color                                         
    ;//      / \  ||         / \  || 
    ;//           P               P  
    ;//          / \             ~ \ 
    ;//         Y               X                                                   
    ;//        . \             / \   
    ;//           X 
    ;//          / \   

    locate_Y:                               ;// have W and V
                                            ;// look for Y
        test btree_Left(name,regY),-1
        .IF !ZERO?
            btree_GetLeft name,regY
            jmp locate_Y
        .ENDIF
        
    ;// W.back=Y     Y.left=W    done with W

        mov btree_Back(name,regWX), regY
        mov btree_Left(name,regY), regWX

    ;// X = Y.right  <- X might be zero

        btree_GetRight name,regY, regWX
        
    ;// V.back=Y Y.right=V   done with V  done with V

        mov btree_Back(name,regVPU), regY
        mov btree_Right(name,regY), regVPU

        test regWX, regWX   ;// <- X might be zero

    ;// P=Y.back     

        btree_GetBack name,regY,regVPU

    ;// P.left=X X.back=P 

        mov btree_Left(name,regVPU),regWX
        .IF !ZERO?
            mov btree_Back(name,regWX),regVPU
        .ENDIF

    ;// clear VPU

        xor regVPU,regVPU

    ;// regY already correct

    connect_U:
        
    ;// U = Z.back   U.next=Y    Y.back=U
    ;// note: regVPU must be zero
    ;//       regY must be set

        DEBUG_IF <regVPU>   ;// supposed to be zero !!

            .IF regY                            ;// might be zero
                mov btree_Back(name,regY),regVPU    
            .ENDIF
            btree_OrGetBack name,regZ,regVPU    ;// might be zero
            .IF !ZERO?
                .IF regZ == btree_Left(name,regVPU)
                    mov btree_Left(name,regVPU), regY
                    jmp all_done    ;// don't use nested .ELSE in MASM
                .ENDIF
                    mov btree_Right(name,regVPU), regY
            .ELSE
                mov btree_Head(name,indirector), regY
            .ENDIF

    all_done:

        ENDM


;//-----------------------------------------------------------------------------
;//
;//     InsertFlat      see notes about flat at top of file
;//
;//-----------------------------------------------------------------------------

btree_InsertFlat MACRO name:req,item:req,indirector

        push btree_Head(name,indirector)
        pop  btree_Back(name,item)
        mov  btree_Head(name,indirector), item

    ;// rewrite to use temp register

    ENDM



;//-----------------------------------------------------------------------------
;//
;//     Flatten
;//
;//-----------------------------------------------------------------------------

btree_Flatten MACRO name:req,indirector

        LOCAL  F2,F3

    ;// warning: destroys eax,edx,ebx,esi

        btree_GetFirst name,ebx ;// locate the lowest item
        mov btree_Head(name,indirector), ebx    ;// set that as the head

    ;// build the slist using left as the link (otherwise get next can't work)

        btree_CopyPointer name,ebx,esi    ;// esi is tag along
    F2: 
        btree_GetNext name, ebx
        mov btree_Left(name,esi), ebx
        mov esi, ebx
        test esi, esi
        jnz F2

    ;// xfer left to back and clear left and right for all the nodes

        btree_GetHead name,ebx,indirector
        xor eax, eax
        xor edx, edx        
    F3: 
        xchg edx,btree_Left(name,ebx)   ;// zero left and set ecx as next item
        mov btree_Right(name,ebx),eax   ;// zero the right side
        mov btree_Back(name,ebx),edx    ;// store next in back
        mov ebx, edx    ;// put next in ebx
        mov edx, eax    ;// rezero edx
        test ebx, ebx   ;// se if there's more to do
        jnz F3

    ENDM


;//-----------------------------------------------------------------------------
;//
;//     Unflatten       notes on algorithm below
;//
;//-----------------------------------------------------------------------------

btree_Unflatten MACRO name:req,indirector

        LOCAL  do_a_scan,back_to_top,C_was_zero,B_was_zero
        LOCAL  relink_last,check_E,all_done

    ;// warning! destroys eax,ebx,ecx,edx,esi

    ;// flatten the tree, storing the next pointers in Left
    ;// rescan the tree, xferring left to back, and zeroing left and right

        btree_Assume name,eax
        btree_Assume name,ebx
        btree_Assume name,ecx
        btree_Assume name,edx
        btree_Assume name,esi

    do_a_scan:
    
        btree_GetHead name,eAx,indirector   ;// A = slist head
        xor eDx, eDx                        ;// D = 0
        mov eBx, btree_Back(name,eAx)       ;// B = A.next

    back_to_top:
                        
        mov Esi, eDx    ;// E = D
        test eBx, eBx   ;// B ?
        mov eDx, 0      ;// D = 0
        jz B_was_zero
                                            
            mov eCx, btree_Back(name,eBx)   ;// C = B.next
            mov btree_Left(name,eBx), eAx   ;// link A as B.left           
            test eCx,eCx                    ;// C ?
            mov btree_Back(name,eAx), eBx   ;// A.back = B  ;// removes A from slist
            jz C_was_zero
        
                mov eDx, btree_Back(name,eCx)   ;// D = C.next  
                mov btree_Right(name,eBx), eCx  ;// B.right = C
                mov btree_Back(name,eCx), eBx   ;// C.back = B  ;// removes C from slist
    
        C_was_zero:

            mov btree_Back(name,eBx),eDx        ;// B.next = D  (clears or sets)

    B_was_zero:
                                                
        .IF Esi                                 ;// E ?
            mov btree_Back(name,Esi), eBx       ;//     E.next = B
        .ELSE                                   ;// :
            mov btree_Head(name,indirector),eBx ;//     head = B
        .ENDIF

        mov eAx, eDx    ;// A = D
        test eAx,eAx    ;// A ?
        jz check_E   
        
        mov eAx, btree_Back(name,eAx)   ;// A = A.next  ;// was left
        test eAx,eAx                    ;// A ?
        jz relink_last

        mov eBx, btree_Back(name,eAx)   ;// B = A.next  ;// was left
        test eBx,eBx                    ;// B ?
        jnz  back_to_top                

        ;// test eDx,eDx    ;// D ? <-- when is this NOT true ??
        ;// jz check_E

        ;// two nodes left over (D and A)
        
        mov btree_Right(name,eDx), eAx  ;// D.right = A
        mov btree_Back(name,eAx), eDx   ;// A.back = D  ;// removes from slist
        mov btree_Back(name,eDx), eBx   ;// D.next = 0  ;// terminates slist

        jmp do_a_scan   

    ;// one node left over (D) and C already has a right side
    relink_last:
        
        mov btree_Back(name,eCx), eDx   ;// C.back = D    removes C from slist
        mov btree_Back(name,eDx), eBx   ;// D.back = B
        mov btree_Left(name,eDx), eCx   ;// D.left = C   
        mov btree_Right(name,eBx), eDx  ;// B.right = D
        mov btree_Back(name,eBx), eAx   ;// B.next = 0   
    
    check_E:

        test Esi, Esi   ;// E ?
        jnz do_a_scan

    ;// lastly, make sure that head.back = 0

        btree_GetHead name,eAx,indirector
        mov btree_Back(name,eAx), Esi   ;// zero

    all_done:

    ENDM


;//-----------------------------------------------------------------------------
;//
;// Balance
;//
;//-----------------------------------------------------------------------------

btree_Balance MACRO name:req,indirector

    ;// warning! destroys eax,ebx,ecx,edx,esi

        ;// part 0) check for empty

        btree_GetHead name,eax,indirector
        test eax, eax
        .IF !ZERO?
        
        ;// Part 1) FLATTEN

            btree_Flatten name,indirector

        ;// Part 2) Unflatten

            btree_Unflatten name,indirector

        ;// that's it

        .ENDIF

        ENDM

;//-----------------------------------------------------------------------------
;//
;// RotateRight
;// RotateLeft
;//
;//-----------------------------------------------------------------------------

comment ~ /*    

    ROTATE C RIGHT

        H              H            x   indicates links to be changed
        x              x            H   head                         
        C              A            C   source item                  
       x \            / x           A,D other objects effected       
      A       ==>        C         
     / x                x \       
        D              D    

*/ comment ~


btree_RotateRight   MACRO name:req, item:req, indirector

    ;// destroys eax,edx
    
    ;// prevent programmer confusion

        LOCAL regA,regC,regD,regH
        LOCAL all_done
        regA TEXTEQU <eax>
        regD TEXTEQU <edx>
        regC TEXTEQU <item>     
        regH TEXTEQU <regD>     

    .ERRIDNI <item>,<eax>,<can't use eax as the node>
    .ERRIDNI <item>,<edx>,<can't use edx as the node>

    ;// do it
        
        xor regD, regD

        btree_GetLeft name,regC,regA        ;// A = C.Left  ; 
        DEBUG_IF < !!regA >                 ;// if !A ERROR: node does not have a left member!!

        btree_OrGetRight name,regA,regD     ;// D = A.Right         might be zero       
        mov btree_Left(name,regC),regD      ;// C.Left = D  
        .IF !ZERO?                          ;// if D                most common case
            mov btree_Back(name,regD),regC  ;//     D.Back = C      
        .ENDIF                              ;//                     done with D

        mov btree_Right(name,regA),regC     ;// A.Right = C ;   

        btree_GetBack name,regC,regH        ;// H = C.Back          might be zero

        mov btree_Back(name,regA),regH      ;// A.Back  = H 
        test regH,regH
        mov btree_Back(name,regC),regA      ;// C.Back  = A 

        .IF !ZERO?                              ;// if(H)               most common case
            .IF regC==btree_Left(name,regH)     ;//     if H.Left == C
                mov btree_Left(name,regH),regA  ;//         H.Left = A
                jmp all_done                    ;//     don't use nested .ELSE in MASM
            .ENDIF                              ;//     else                
                mov btree_Right(name,regH),regA ;//         H.Right = A
        .ELSE                                   ;// else
            mov btree_Head(name,indirector),regA;//     tree_root = A
        .ENDIF

    ;// that's it

    all_done:

    ENDM

    

comment ~ /*

    ROTATE A LEFT

        H              H            x   indicates links to be changed
        x              x            H   head                         
        A              C            A   source item                  
       / x            x \           C,D other objects effected       
          C   ==>    A             
         x \        / x           
        D              D          

*/ comment ~



btree_RotateLeft MACRO name:req, item:req, indirector

    ;// destroys eax,edx

    ;// prevent programmer confusion

        LOCAL regA,regC,regD,regH
        LOCAL all_done

        regC TEXTEQU <eax>
        regD TEXTEQU <edx>
        regA TEXTEQU <item>
        regH TEXTEQU <regD>

    .ERRIDNI <item>,<eax>,<can't use eax as the node>
    .ERRIDNI <item>,<edx>,<can't use edx as the node>

    ;// do it

        xor regD,regD
    
        btree_GetRight name,regA,regC       ;// C = A.Right
        DEBUG_IF < !!regC >                 ;// if !C   ERROR: node does not have a right member!!

        btree_OrGetLeft name,regC,regD      ;// D = C.Left          might be zero

        mov btree_Right(name,regA),regD     ;// A.Right = D 

        .IF !ZERO?                          ;// if D
            mov btree_Back(name,regD),regA  ;//     D.Back = A
        .ENDIF                              ;//                     done with D

        btree_GetBack name,regA,regH        ;// H = A.Back  might be zero
        mov btree_Left(name,regC),regA      ;// C.Left  = A
        test regH,regH
        mov btree_Back(name,regA),regC      ;// A.Back  = C 
        mov btree_Back(name,regC),regH      ;// C.Back  = H 
        .IF !ZERO?                          ;// if H                most common case ?
            .IF regA==btree_Left(name,regH)     ;// if H.Left == A
                mov btree_Left(name,regH),regC  ;//     H.Left  = C 
                jmp all_done                    ;//     don't use nested .ELSE in MASM
            .ENDIF                              ;// else        
                mov btree_Right(name,regH),regC ;//     H.Right = C
        .ELSE                               ;// else
            mov btree_Head(name,indirector),regC    ;// tree_root = C
        .ENDIF

    ;// that's it

    all_done:

    ENDM







;//-----------------------------------------------------------------------------
;//
;// dev notes
;//

comment ~ /*

    notes on unflatten

1) flatten the list, storing next in node.back

2) use 5 registers to iterate through the list

    push left sides, push right sides, reset head, re-link slist
    the five registers are A,B,C,D and E
    E acts as a tag along for the inner loop

.REPEAT
back_to_enter:
    A=b_head    D=0
    B=A.next
back_to_top:
    E=D         D=0   
    .IF B
        A.back=B   B.left=A      
        C=B.next
        .IF C
            B.right=C     
            D=C.next    C.back=B
        .ENDIF
        B.next=D
    .ENDIF     
    .IF E ? E.next=B : b_head=B     .ENDIF
    A=D
    .IF A
        A=A.next
        .IF A
            B=A.next
            .IF B
                jmp back_to_top
            .ELSEIF D   <-- when is this NOT true ?
                D.right=A   A.back=D
                D.next=B    ;// zero        
                jmp back_to_enter
            .ENDIF
        .ELSE
            D.left=C  C.back=D  
            B.right=D D.back=B  
            B.next=A  ;// zero
        .ENDIF
    .ENDIF
.UNTIL !E
       
*/ comment ~


ENDIF   ;// _BTREE_INCLUDED_