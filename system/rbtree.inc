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
;// rbtree.inc      macros for red/back trees
;//                 rbtrees extend btree functionality
;//
IFNDEF _RBTREE_INCLUDED_
_RBTREE_INCLUDED_ EQU 1

    INCLUDE <btree.inc>


comment ~ /*


    btree is extended by first suffixing _rb to the passed name
    
    example
    
        user:   tree_name   ; this is all you ever need to know

        rbtree: tree_name_rb
        btree:  tree_name_rb_btree_

head item

    name&_rb&_btree_Head    dd  0   ;// pointer to the 'center'

node items that take up data space

    name&_rb&_tree_Back     dd  0   ;// pointer to parent
    name&_rb&_btree_Left    dd  0   ;// pointer to lesser node
    name&_rb&_btree_Right   dd  0   ;// pointer to greater node
    name&_rbtree_Color      dd  0   ;// 0 for red, non zero for black

other values that do not take up space

    name&_rb&_btree_Key     depends on key type
                            does NOT allocate data

        BTREE_UNSIGNED_DWORD
        BTREE_SIGNED_DWORD
        BTREE_FLOAT
        BTREE_EXTERNAL_UNSIGNED
        BTREE_EXTERNAL_SIGNED


iterating :

    rbtree_GetFirst  rbtree_GetNext
    rbtree_GetLast   rbtree_GetPrev

seraching :

    rbtree_FindKey name,key,iter

inserting and removing

    rbtree_Insert name,item,iter
    rbtree_Remove name,item,iter
        
REGISTER and CPU usage

    rbtrees are complicated and usually require temporary registers
    usage is prioritized as eax,edx,ecx,ebx,esi
    see the macro for acual register usage

    686 code may be used in places


RBTREE_EXTERNAL compare modes

    user must supply a function name
    the function must except two pointers, A and B
    the function must return with:

        ALL registers intact
        flags set EXACTLY as they would be for cmp A,B
            UNSIGNED uses carry and zero flags
            SIGNED used sign, zero and overflow flags
        stack cleaned up

    example:

    my_compare_proc PROC STDCALL USES eax edx ecx ptr_A:PTR MYSTRUCT, ptr_B:PTR MYSTRUCT
        
        mov edx, ptr_A
        mov ecx, ptr_B

        ASSUME edx:PTR MYSTRUCT
        ASSUME ecx:PTR MYSTRUCT

        mov eax, [edx].my_key
        cmp eax, [ecx].my_key

        ret

    my_compare_proc ENDP





*/ comment ~ 




;//-----------------------------------------------------
;//
;// declarators
;//                     key_type: see BTREE_UNSIGNED_DWORD

rbtree_Declare_link MACRO name:REQ, stru:REQ, key:REQ, key_type:REQ

        btree_Declare_link name&_rb, stru, key, key_type

        name&_rbtree_Color  dd  ?       ;// append another data element 

    ENDM

rbtree_Declare_alias_link MACRO newname:REQ, oldname:REQ

        btree_Declare_alias_link newname&_rb, oldname&_rb

        newname&_rbtree_Color   TEXTEQU <oldname&_rbtree_Color>
        
    ENDM



rbtree_Declare MACRO name:req

        btree_Declare name&_rb
        
    ENDM


rbtree_Declare_external MACRO name:req

        btree_Declare_external name&_rb

    ENDM

rbtree_Declare_indirected MACRO name:REQ

    btree_Declare_indirected name&_rb

    ENDM


;//---------------------------------------------------------------------------
;//                 
;// accessor macro functions
;//
;// rbtree_Head()
;// rbtree_Left()        these functions are responsible for generating
;// rbtree_Right()       compile errors if the rbtree is not setup correctly
;// rbtree_Back()
;// rbtree_Color()
;//
;//---------------------------------------------------------------------------

rbtree_Head MACRO name:req, indirector

        EXITM <btree_Head(name&_rb,indirector)>

    ENDM

rbtree_Left MACRO name:req, reg:req

        EXITM <btree_Left(name&_rb,reg)>

    ENDM

rbtree_Right MACRO name:req, reg:req

        EXITM <btree_Right(name&_rb,reg)>

    ENDM


rbtree_Back MACRO name:req, reg:req

        EXITM <btree_Back(name&_rb,reg)>

    ENDM


rbtree_Color MACRO name:req, reg:req

    ;// rbtree_Color() enter

        LOCAL t

        IFNDEF name&_rb_btree_Declared
        .ERR <name has not been declared>
        ENDIF

    %   t CATSTR <BRACKET(reg)>, <.>, <name>, <_rbtree_Color>

    ;// rbtree_Color() exit

        EXITM t

    ENDM


;//-----------------------------------------------------------------------------
;//     
;//     misc helpers        Assume
;//                         CopyPointer
;//                         ClearItem
;//
;//-----------------------------------------------------------------------------

rbtree_Assume MACRO name:req, reg:req

        btree_Assume name&_rb, reg

    ENDM

rbtree_CopyPointer MACRO name:req, reg_from:req, reg_to:req

        btree_CopyPointer name&_rb, reg_from, reg_to

    ENDM

rbtree_ClearItem MACRO name:req, item:req, zero_reg

    ;// clears the pointers
    IFB <zero_reg>
        xor eax, eax
        mov rbtree_Left(name,item), eax
        mov rbtree_Right(name,item), eax
        mov rbtree_Back(name,item), eax
        mov rbtree_Color(name,item), eax
    ELSE
        mov rbtree_Left(name,item), zero_reg
        mov rbtree_Right(name,item), zero_reg
        mov rbtree_Back(name,item), zero_reg
        mov rbtree_Color(name,item), zero_reg
    ENDIF

    ENDM






;//---------------------------------------------------------------------------
;//     
;//     GetHead     OrGetHead        
;//     GetLeft     OrGetLeft      
;//     GetRight    OrGetRight     
;//     GetBack     OrGetBack      
;//     GetColor    OrGetColor
;//
;//---------------------------------------------------------------------------

rbtree_GetHead MACRO name:req, reg:req,indirector

        btree_GetHead name&_rb, reg, indirector

    ENDM

rbtree_GetLeft MACRO name:req, reg1:req, reg2

        btree_GetLeft name&_rb, reg1, reg2
    
    ENDM

rbtree_GetRight MACRO name:req, reg1:req, reg2

        btree_GetRight name&_rb, reg1, reg2

    ENDM

rbtree_GetBack MACRO name:req, reg1:req, reg2

        btree_GetBack name&_rb, reg1, reg2

    ENDM

rbtree_GetColor MACRO name:req, reg1:req, reg2
        
        IFB <reg2>
            mov reg1, rbtree_Color(name,reg1)
        ELSE
            mov reg2, rbtree_Color(name,reg1)            
        ENDIF

    ENDM


rbtree_OrGetHead MACRO name:req, reg:req,indirector

        btree_OrGetHead name&_rb, reg, indirector

    ENDM

rbtree_OrGetLeft MACRO name:req, reg1:req, reg2:req

        btree_OrGetLeft name&_rb, reg1, reg2
    
    ENDM

rbtree_OrGetRight MACRO name:req, reg1:req, reg2:req

        btree_OrGetRight name&_rb, reg1, reg2

    ENDM

rbtree_OrGetBack MACRO name:req, reg1:req, reg2:req

        btree_OrGetBack name&_rb, reg1, reg2

    ENDM

rbtree_OrGetColor MACRO name:req, reg1:req, reg2:req
        
        or reg2, rbtree_Color(name,reg1)             

    ENDM





;//------------------------------------------------------
;//
;// GetFirst
;// GetLast 
;//
;// GetNext
;// GetPrev
;//
;//------------------------------------------------------

rbtree_GetFirst MACRO name:req, reg:req, indirector

    ;// destroys eax

        btree_GetFirst name&_rb, reg, indirector
    
    ENDM

rbtree_GetLast MACRO name:req, reg:req, indirector

    ;// destroys eax

        btree_GetLast name&_rb, reg, indirector

    ENDM


rbtree_GetNext MACRO name:req, iter:req

    ;// also means, 'find the next highest value'
    ;// returns iter=0 if not found

    ;// destroys eax

        btree_GetNext name&_rb, iter

    ENDM

rbtree_GetPrev MACRO name:req, iter:req

    ;// also means, 'find the next lowest value'
    ;// returns iter=0 if not found

    ;// destroys eax

        btree_GetPrev name&_rb, iter

    ENDM



;//------------------------------------------------------
;//
;// FindItem    macro does key load work
;// FindKey     user does keyload work and defines private key
;// FindThisKey user does keyload work, macro defines private key
;// FindAfterThisKey
;//
;// all return iter as non-zero for found, zero for not found
;// 

rbtree_FindItem MACRO name:req, item:req, iter:req, indirector

    ;// uses eax

        btree_FindItem name&_rb, item,iter,indirector

    ENDM

rbtree_FindKey MACRO name:req, _key:req, iter:req, indirector

    ;// caller must load the key correctly, see btree_LoadKey, but don't mess with btree_private_key
    ;// preserves all registers except those passed

        btree_FindKey name&_rb, _key,iter,indirector

    ;// caller must unload key correctly, see rbtree_UnloadKey, but don't mess with rbtree_private_key

    ENDM

rbtree_FindThisKey MACRO name:req, _key:req, iter:req, indirector

    ;// locate the key specified by the user

        btree_FindThisKey name&_rb, _key, iter, indirector

    ENDM

rbtree_FindAfterThisKey MACRO name:req, _key:req, iter:req, indirector

    ;// determine the item whos key is above this key
    ;// if key already exists, then return the next item
    ;// alway test iter,iter to determine if anything was found

    btree_FindAfterThisKey name&_rb, _key, iter, indirector

    ENDM


;//------------------------------------------------------
;//
;// Insert
;//
;//------------------------------------------------------

rbtree_Insert MACRO name:req, item:req, indirector

    ;// destroys eax,edx,ecx
    ;// it's recommended that this be put inside a function

    ;// returns zero flag if key already exists
    ;// returns ecx as where we inserted
    ;// if already exists, ecx is the duplicate key

        LOCAL regX,regP,regPP,regY
        LOCAL top_of_backtrack,done_with_backtrack,rbtree_insert_done
        LOCAL L_cases, R_cases

    .ERRIDNI <item>,<eax>,<can't use eax as the node>
    .ERRIDNI <item>,<ecx>,<can't use ecx as the node>
    .ERRIDNI <item>,<edx>,<can't use edx as the node>

                
    ;// insert like normal, abort if duplicate

        btree_Insert name&_rb,item,indirector
        IFNDEF name&_rb_btree_Allow_Duplicate_Keys
        jz rbtree_insert_done
        ENDIF

    push item   ;// we need to preserve item, and re-useit as regX

    ;// prevent programmer confusion

        regX    TEXTEQU <item>
        regP    TEXTEQU <eax>   ;// = X.Back
        regPP   TEXTEQU <ecx>   ;// = X.Back.Back   must be ecx as it's used for betree_Rotate
        regY    TEXTEQU <edx>   ;// = X.Uncle

    ;// now we do the red black fixups

        mov rbtree_Color(name,item),0   ;// new nodes are red

    top_of_backtrack:
        
        cmp regX, rbtree_Head(name,indirector)  ;// if( X == RBNODE::rb_root ) break
        je done_with_backtrack

        xor regP,regP   ;// make these are zero for easier testing
        sub regY,regY

        rbtree_OrGetBack name,regX,regP         ;// P = X.Back
        jz done_with_backtrack                  ;// if !P  break ;

        cmp regY, rbtree_Color(name,regP)       ;// if P.Color != RED  break
        jnz done_with_backtrack                 ;// RED = 0, regY is still zero

        rbtree_GetBack name,regP,regPP          ;// PP = P.Back

        DEBUG_IF <!!regPP>  ;// rbtree_Backtrack got nul parent of red node!!
                            ;// not supposed to happen 
                            ;// root always black, so we should have caught P != red
    
    ;// determine Left or Right cases

        cmp regP, rbtree_Left(name,regPP)       ;// if P==PP.Left
        jne R_cases

    L_cases:
                                                ;// Y is still zero
        rbtree_OrGetRight name,regPP,regY       ;// Y = PP.Right
        .IF !ZERO? && !rbtree_Color(name,regY)  ;// if Y && Y.Color == RED (red = zero)
        
        ;// CASE 1L - change the colours, Move x up the tree 
        
            inc rbtree_Color(name,regP)         ;// P.Color = BLACK
            inc rbtree_Color(name,regY)         ;// Y.Color = BLACK
            mov rbtree_Color(name,regPP),0      ;// PP.Color = RED
            mov regX,regPP                      ;// X = PP
            jmp top_of_backtrack

        .ENDIF
        
        ;// Y was black or nul (which is still black)
                
        .IF regX == rbtree_Right(name,regP)     ;// if X == P.Right

        ;// CASE 2L move X up and rotate Left

            mov regX, regP                      ;// X = P
            btree_RotateLeft name&_rb, regX, indirector ;// generates lots of code
            rbtree_GetBack name,regX,regP       ;// P = X.Back
            rbtree_GetBack name,regP,regPP      ;// PP = P.back

            ;// now it's case 3L

        .ENDIF

        ;// CASE 3L recolor, rotate PP right and continue

        inc rbtree_Color(name,regP)             ;// P.Color = BLACK
        mov rbtree_Color(name,regPP),0          ;// PP.Color = RED
        btree_RotateRight name&_rb,regPP,indirector ;// generates lots of code
        jmp top_of_backtrack
    
    ALIGN 16
    R_cases:
                                                ;// Y is still zero
        rbtree_OrGetLeft name,regPP,regY        ;// Y = PP.Left
        .IF !ZERO? && !rbtree_Color(name,regY)  ;// if Y && Y.Color == RED (red=zero)
        
        ;// CASE 1R change the colours  Move x up the tree 
        
            inc rbtree_Color(name,regP)         ;// P.Color = BLACK
            inc rbtree_Color(name,regY)         ;// Y.Color = BLACK
            mov rbtree_Color(name,regPP),0      ;// PP.Color = RED
            mov regX,regPP                      ;// X = PP
            jmp top_of_backtrack

        .ENDIF
        
        ;// Y was black or zero (which means it's still black)
        
        .IF regX == rbtree_Left(name,regP)      ;// if X == P.Left
        
        ;// CASE 2R move x up and rotate  Right
        
            mov regX, regP                      ;// X = P
            btree_RotateRight name&_rb,regX,indirector  ;// generates lots of code
            rbtree_GetBack name,regX,regP       ;// P = X.Back
            rbtree_GetBack name,regP,regPP      ;// PP = P.back
            
            ;// now it's case 3R
        
        .ENDIF
        
        ;// CASE 3R : recolor, rotate PP left and continue

        inc rbtree_Color(name,regP)             ;// P.Color = BLACK ;// x.parent.colour = black;              
        mov rbtree_Color(name,regPP),0          ;// PP.Color = RED  ;// x.parent.parent.colour = red;       
        btree_RotateLeft name&_rb, regPP, indirector    ;// generates lots of code      
        jmp top_of_backtrack

    ALIGN 16
    done_with_backtrack:

        ;// root nodes are always black
        rbtree_GetHead name,regX, indirector
        inc rbtree_Color(name,regX)

    pop item

        mov ecx, item
        test ecx, ecx   ;// return non-zero

    rbtree_insert_done:

    ENDM


;//------------------------------------------------------
;//             
;// Remove      heh heh, this one took a little work
;//     
;//
;//------------------------------------------------------

rbtree_Remove MACRO name:req, item:req, indirector

    LOCAL   case_0,not_case_1L,case_1L,case_1R,case_1LR, case_01_enter_fixup
    LOCAL   set_edx_head_and_done
    LOCAL   not_case_1,case_2n,case_2n_1
    ;// ,case_2
    LOCAL   top_of_fixup,x_is_black
    LOCAL   case_L,case_LW,case_L_not_black_L,case_L_not_black_R
    LOCAL   case_R,case_RW,case_R_not_black_R,case_R_not_black_L
    LOCAL   rebalance_done_item,rebalance_done,fixup_done,remove_done

    ECHO <rbtree_Remove has errors in it, fix it !! >

        .ERRIDNI <item>,<eax>,<cant use eax for name>
        .ERRIDNI <item>,<edx>,<cant use eax for name>
        .ERRIDNI <item>,<ecx>,<cant use eax for name>

        xor edx,edx
        sub eax,eax
        xor ecx,ecx

    ;// locate Y as the next name with a nil child

        rbtree_OrGetRight name,item,edx ;// V
        jnz not_case_1L
        rbtree_OrGetLeft name,item,edx  ;// W
        jnz case_1L

    case_0:    
    ;// eax = 0
    ;// edx = 0
    ;// ecx = 0        U p      U p     p = U, w must be determined
    ;//               . \      / .
    ;//     Z         x  w     w x      if Z was black
    ;//    . .                          jump to case_LW or case_RW

        rbtree_OrGetBack name,item,ecx      ;// U = Z.back
        jz set_edx_head_and_done            ;// if no back, just set head and done

        cmp item,rbtree_Left(name,ecx)      ;// Z on right or left side of U
        setnz al                            ;// eax = 1 for x on right
        mov rbtree_Left(name,ecx)[eax*4],edx;// U.next = X (edx=0)

        cmp edx, rbtree_Color(name,item)    ;// is Z red ? (edx is zero)
        je remove_done                      ;// no need to fixup, or even to set the color
        ;// edx is zero, so we know it's a black nil name
        jmp case_01_enter_fixup             ;// we can jump to comon fixup entrance

    not_case_1L:    ;// edx = W, V not tested yet

        rbtree_OrGetLeft name,item,eax  ;// V
        jnz not_case_1

    case_1L:   
    ;// edx = W, 
    ;// eax = 0,
    ;// ecx = 0
    ;//                U  p     U       p = U, w must be determined
    ;//     Z         / \      / \      if Z was black, AND x is black jump to case LW or case RW
    ;//    . \       w   V    V   w
    ;//       V          x    x
    case_1R:        
    ;// edx = V, 
    ;// eax = 0,
    ;// ecx = 0
    ;//                U p      U       p = U, w must be determined
    ;//     Z         / \      / \      if Z was black AND x is black jump to case LW or case RW
    ;//    / .       w   W    W   w     
    ;//   W              x    x
    case_1LR:

        ;// edx must be X
        ;// ecx not set yet
        ;// eax = 0

        rbtree_OrGetBack name,item,ecx      ;// U = Z.back
        mov rbtree_Back(name,edx),ecx       ;// X.back = U
        jz set_edx_head_and_done            ;// if no back, just set head and done

        cmp item,rbtree_Left(name,ecx)      ;// determine U.not.Z
        setnz al                            ;// eax = 1 for x on right
        mov rbtree_Left(name,ecx)[eax*4],edx;// U.next = X

        cmp rbtree_Color(name,item),0       ;// was Z red ?
        je remove_done                      ;// no need to fixup
        cmp rbtree_Color(name,edx),0        ;// is X red ?
        je fixup_done                       ;// just set the color and exit

    case_01_enter_fixup:

        push item       ;// have to preserve
        neg eax         ;// make neg offset, also sets the zero flag
        mov item, rbtree_Right(name,ecx)[eax*4] 
        jz case_LW      ;// if eax was
        xor eax, eax
        jmp case_RW

    ALIGN 16
    set_edx_head_and_done:

        mov rbtree_Head(name,indirector),edx
        jmp fixup_done  ;// since edx is the head, we don't need to fixup, just color it black

    ;----------------------------------------------------------------------------------------

    ALIGN 16    
    not_case_1: ;// edx = V, eax = W, ecx is zero


        rbtree_OrGetLeft name,edx,ecx
        jnz case_2n

    ;case_2:     
    ;// edx = V                  U = Z.back <- might be zero        
    ;// eax = W                  U.next = V                         
    ;// ecx = 0        U         V.back = U                         
    ;//                +                                            
    ;//     Z          V p       V.left = W                         
    ;//    / \        / \        W.back = V                         
    ;//   W   V      W   x                                           
    ;//      . \     w           V.color = Z.color                  
    ;//                          if V.oldcolor = black AND x = black
    ;//                          jmp to appropriate case            
    ;// p = V
    ;// x = p.right
    ;// w = p.left        


        mov rbtree_Left(name,edx), eax  ;// V.left = W                         
        mov rbtree_Back(name,eax), edx  ;// W.back = V  done with W
    
        mov eax, rbtree_Color(name,item);// Z.color
        xchg rbtree_Color(name,edx), eax ;// to Y.color

        push eax        ;// need to save the old color
        xor eax, eax

        rbtree_OrGetBack name,item,ecx  ;// U = Z.back <- might be zero        
        mov rbtree_Back(name,edx),ecx   ;// V.back = U  
        .IF !ZERO?        
            cmp item, rbtree_Left(name,ecx)
            setnz al
            mov rbtree_Left(name,ecx)[eax*4],edx    ;// U.next = V
        .ELSE
            mov rbtree_Head(name,indirector), edx
        .ENDIF

        pop eax
        mov ecx, edx    ;// p = V
        test eax, eax
        mov edx, rbtree_Right(name,ecx) ;// x=p.right
        jz rebalance_done   ;// x might be zero

        .IF edx
            cmp rbtree_Color(name,edx), 0
            je fixup_done   ;// just set the color
        .ENDIF

        push item   ;// preserve
        mov item, rbtree_Left(name,ecx) ;// w=V.left
        xor eax, eax    ;// must be zero
        jmp case_RW     ;// x is on the right

    ALIGN 16
    case_2n:    ;// edx = W, eax = V, ecx = V.left
        
        cmp rbtree_Left(name,ecx),0
        je case_2n_1
        rbtree_GetLeft name,ecx
        jmp case_2n
    
    ALIGN 16    
    case_2n_1:  

    ;// edx = V, 
    ;// eax = W,    this is the tuff one
    ;// ecx = Y     we have to move Y to Z, keep track of Y.right and P
    ;//
    ;//     Z           U           U = Z.back <- might be zero                              
    ;//    / \          +           Y.back = U                                               
    ;//   W   V         Y           U.next = Y                                               
    ;//      //        / \                                                                   
    ;//      Y        W   V         Y.left = W                                               
    ;//     .            //         W.back = Y                                               
    ;//                  P                                                                   
    ;//                 / \         Y.right = V                                              
    ;//                X   w        V.back = Y                                               
    ;//                x                                                                     
    ;//                             X = Y.right <- might be zero                             
    ;//                             P = Y.back                                               
    ;//                             P.left = X                                               
    ;//                             X.back = P                                               
    ;//                                                                                      
    ;//                             w = P.right                                              
    ;//                                                                                      
    ;//                             Y.color = Z.color                                        
    ;//                             if Y.oldcolor = black AND X.color = BLACK, jmp to case_LW


    ;// edx = V
    ;// eax = W
    ;// ecx = Y

        mov rbtree_Back(name,eax), ecx  ;// eax     W.back = Y  
        mov rbtree_Left(name,ecx), eax  ;//         Y.left = W      done with W

        mov eax, rbtree_Right(name,ecx) ;// eax     X = Y.right <- might be zero

        mov rbtree_Back(name,edx), ecx  ;// edx     V.back = Y      
        mov rbtree_Right(name,ecx), edx ;//         Y.right = V     done with V

        mov edx, rbtree_Color(name,item) ;// Z color
        xchg edx,rbtree_Color(name,ecx)  ;// swap with Y.color

        push edx        ;// need to save old Y color
        
        test eax,eax                    ;// X might be zero
        mov edx, rbtree_Back(name,ecx)  ;// edx P = Y.back
        mov rbtree_Left(name,edx), eax  ;//     P.left = X
        .IF !ZERO?                   
            mov rbtree_Back(name,eax),edx;//    X.back = P
        .ENDIF

        push edx        ;// need to save P

        xor eax, eax    ;// zero for next tests
        xor edx, edx    ;// zero for next tests

        rbtree_OrGetBack name,item,edx  ;// edx U = Z.back <- might be zero
        mov rbtree_Back(name,ecx),edx   ;//     Y.back = U
        .IF !ZERO?            
            cmp item, rbtree_Left(name,edx)
            setnz al
            mov rbtree_Left(name,edx)[eax*4],ecx;// U.next = Y
        .ELSE
            mov rbtree_Head(name,indirector),ecx
        .ENDIF

    ;// now we're done with Y
    
        pop ecx     ;// P
        pop eax     ;// color

    ;// if Y.oldcolor = black AND X.color = BLACK, jmp to case_LW

        test eax, eax                   ;// was Y read ?
        mov edx, rbtree_Left(name,ecx)  ;// X = P.left
        jz rebalance_done               ;// jump to exit if Y was red
        xor eax, eax        
        .IF edx                             ;// nil X = black
            cmp eax,rbtree_Color(name,edx)  ;// if X.color black ?
            je fixup_done                   ;// if red, just jump to color setter
        .ENDIF

        push item       ;// have to preserve item
        mov item,rbtree_Right(name,ecx) ;// w = P.right
        jmp case_LW     ;// x is on left side


    ;//////////////////////////////////////////////////////////////////
    ;//
    ;//             case R      case L     item preserved on stack
    ;//
    ;// fixup        ecx         ecx
    ;//               p           p
    ;//              / \         / \
    ;//             x   w       w   x
    ;//            edx item   item edx

    ;// while (X != Root && X->Color == Black)

    ALIGN 16
    top_of_fixup:   ;// this can be moved down below ??

        ;// eax = 0
        ;// edx X might be zero (in which case it's black)
        ;// ecx P should always be valid
        ;// W is not set yet

        cmp edx, rbtree_Head(name,indirector)
        je rebalance_done_item

        test edx,edx
        jz x_is_black

        cmp eax,rbtree_Color(name,edx)
        je rebalance_done_item

    x_is_black:

    ;// determine if X on left or right

        cmp edx, rbtree_Left(name,ecx)
        jne case_R

    ;// x is on the left

    case_L:     rbtree_GetRight name,ecx,item  ;// W = P.right

    case_LW:    DEBUG_IF < !!item > ;// W is supposed to be set !!!

        DEBUG_IF <eax>      ;// we thought eax was zero !!

        ;//     P    X might be zero
        ;//    X W

        .IF !rbtree_Color(name,item)        ;// if W is Red

    ;// CASE L1

            inc rbtree_Color(name,item)     ;// W.color = black
            mov rbtree_Color(name,ecx), 0   ;// P.color = red
            btree_RotateLeft name&_rb,ecx,indirector   ;// rotate P left (preserves P)
            rbtree_GetRight name, ecx,item  ;// W = P.right
            xor eax, eax                    ;// eax = zero = RED

        .ENDIF

        ;// if W left and right are black

        rbtree_GetLeft name, item, edx
        .IF edx
            cmp eax,rbtree_Color(name,edx)
            je case_L_not_black_L
        .ENDIF
        rbtree_GetRight name, item, edx
        .IF edx
            cmp eax,rbtree_Color(name,edx)
            je case_L_not_black_R
        .ENDIF

    ;// CASE L2     W.right and W.left are black

        mov rbtree_Color(name,item),eax ;// W.color = RED   eax is zero
        mov edx, ecx                    ;// X = P
        rbtree_GetBack name,ecx         ;// P = P.back
        jmp top_of_fixup                ;// back to top
    
    ALIGN 16
    case_L_not_black_L: ;// edx = W.left

        rbtree_GetRight name, item, edx

    case_L_not_black_R: ;// edx = W.right

        .IF !edx || eax != rbtree_Color(name,edx)   ;// if W.right is BLACK

    ;// CASE L3

            rbtree_GetLeft name,item,edx    ;// W.left
            DEBUG_IF <!!edx>            ;// not supposed to happen !!
            inc rbtree_Color(name,edx)      ;// W.left.color = black
            mov rbtree_Color(name,item),eax ;// W.color = red   eax is still zero = RED
            btree_RotateRight name&_rb,item,indirector  ;// rotate W.left, P preserved
            rbtree_GetRight name,ecx,item   ;// W = P.right

        .ENDIF

    ;// CASE L4

        mov eax, rbtree_Color(name,ecx)     ;// P.color
        mov rbtree_Color(name,item), eax    ;// W.color = P.color
        inc rbtree_Color(name,ecx)          ;// P.color = black
        rbtree_GetRight name,item,edx       ;// W.right
        DEBUG_IF <!!edx>    ;// not supposed to happen !!
        inc rbtree_Color(name,edx)          ;// W.right.color = black
        btree_RotateLeft name&_rb,ecx,indirector           ;// rotate P Left
        mov edx,rbtree_Head(name,indirector);// X = root
        jmp rebalance_done_item             ;// and that's it

    ;// X is on the right

    ALIGN 16
    case_R:     rbtree_GetLeft name,ecx,item   ;// W = P.left

    case_RW:    DEBUG_IF < !!item > ;// supposed to be non zero !!

        DEBUG_IF < eax >    ;// we thought eax was zero !!

        .IF eax == rbtree_Color(name,item)  ;// if W is RED eax = zero = RED

    ;// CASE R1

            inc rbtree_Color(name,item)     ;// W.color = black
            mov rbtree_Color(name,ecx), eax ;// P.color = red
            btree_RotateRight name&_rb,ecx,indirector      ;// rotate P right
            rbtree_GetLeft name,ecx,item    ;// W = P.left
            xor eax, eax                    ;// eax must be zero

        .ENDIF

        ;// if w left and right are black

        rbtree_GetRight name,item,edx       ;// W.right
        .IF edx
            cmp eax, rbtree_Color(name,edx) ;// eax = zero = RED
            je case_R_not_black_R
        .ENDIF
        rbtree_GetLeft name,item,edx        ;// W.left
        .IF edx
            cmp eax, rbtree_Color(name,edx) ;// eax = zero = RED
            je case_R_not_black_L
        .ENDIF

    ;// CASE R2

        mov rbtree_Color(name,item),eax ;// W.color = RED
        mov edx, ecx                    ;// X=P
        rbtree_GetBack name,ecx         ;// P=P.back

        jmp top_of_fixup
   
   ALIGN 16
    case_R_not_black_R:                 ;// edx = W.right

        rbtree_GetLeft name,item,edx    ;// W.left

    case_R_not_black_L:                 ;// edx = W.left

        .IF !edx || eax != rbtree_Color(name,edx)   ;// if W.left.color == BLACK

    ;// CASE R3

            rbtree_GetRight name,item,edx   ;// edx = W.right
            inc rbtree_Color(name,edx)      ;// W.right = BLACK
            mov rbtree_Color(name,item),eax ;// W.color = RED
            btree_RotateLeft name&_rb,item,indirector      ;// rotate W left
            rbtree_GetLeft name,ecx,item    ;// W=P.left

        .ENDIF

    ;// CASE R4

        mov eax, rbtree_Color(name,ecx)     ;// eax = P.color
        mov rbtree_Color(name,item),eax     ;// W.color = P.color
        inc rbtree_Color(name,ecx)          ;// P.color = black
        rbtree_GetLeft name,item,edx        ;// W.left
        inc rbtree_Color(name,edx)          ;// W.left = black
        btree_RotateRight name&_rb,ecx,indirector      ;// rotate P right
        mov edx,rbtree_Head(name,indirector);// X = head
        ;jmp rebalance_done_item            ;// and that's it

    rebalance_done_item:

        pop item    ;// retrieve stored item

    rebalance_done: ;// set X color as black

        test edx, edx
        jz remove_done
        
    fixup_done:
        .IF edx     ;// why does this happen ?
        inc rbtree_Color(name,edx)
        .ENDIF
    
    remove_done:

    ENDM


;//------------------------------------------------------
;//
;// MeasureAndVerify                dev macro
;//     
;//
;//------------------------------------------------------



rbtree_MeasureAndVerify MACRO name:req, display

    ;// returns ebx as:
    ;//
    ;//     bit 31      on for black height violation
    ;//     bit 30      on for red-red violation
    ;//     bits 0-29   first measured black height

    rbtree_GetFirst name,ecx    

    xor ebx, ebx    ;// black height, and flags

    .WHILE ecx

        .IF !rbtree_Left(name,ecx) && !rbtree_Right(name,ecx)
        ;// this is a leaf node

        ;// measure the black height, check for red-red violations

            xor eax, eax                    ;// reset counter
            rbtree_CopyPointer name,ecx,edx ;// edx is he iterator back up the tree
            .REPEAT
                .IF rbtree_Color(name,edx)  ;// non_zero = black
                    inc eax                 ;// increase black height
                    btr eax, 30             ;// reset the prev_was_red bit
                .ELSE                       ;// zero = red
                    bts eax,30              ;// set the prev_was_red bit
                    .IF CARRY?
                        bts ebx, 30     ;// set the red red viloation bit
                    .ENDIF
                .ENDIF                  
                rbtree_GetBack name,edx                     
            .UNTIL !edx
        
        ;// update the black height
            
            btr eax, 30             ;// turn off prev_was_red
            .IF !(ebx & 00FFFFFFh)  ;// black height set yet ?
                or ebx, eax         ;// store
            .ELSE                   ;// else, check for black height violations
                xor eax, ebx        ;// lower bits should be zero
                and eax, 00FFFFFFh  ;// 
                .IF !ZERO?
                    bts ebx, 31     ;// set the black height violation bit
                .ENDIF
            .ENDIF

        .ENDIF ;// leaf node

        rbtree_GetNext name,ecx

    .ENDW

    ;// now we have bit 31 as black height violation
    ;//             bit 30 as red red violation
    ;//             lower bits as black height

    IFNB <display>
        
        .ERRDIF <display>,<ERROR_STDOUT>,<use ERROR_STDOUT or leave blank>

        .IF !hStdOut
            stdout_Open
        .ENDIF
            
        IFNDEF name&_rbtree_stdout_buffer
        .DATA?
            name&_rbtree_stdout_buffer db 1024 DUP (?)
        .CODE
        ENDIF

        IFNDEF sz_rbtree_error_black_height err: black height violation
        .DATA
            sz_rbtree_error_black_height  db 'ERR: black height violation  '
            sz_rbtree_error_redred        db 'ERR: red-red violation  '
        .CODE
        ENDIF

        push edi
        mov edi, OFFSET name&_rbtree_stdout_buffer

        btr ebx, 31     ;// black height violation
        .IF CARRY?
            push esi
            lea esi, sz_rbtree_error_black_height
            mov ecx, SIZEOF sz_rbtree_error_black_height    ;// err: black height violation
            rep movsb
            pop esi
        .ENDIF

        btr ebx,30      ;// red-red violation
        .IF CARRY?
        
            push esi
            lea esi, sz_rbtree_error_redred       ;// db 'ERR: red-red violation  '
            mov ecx, SIZEOF sz_rbtree_error_redred
            rep movsb
            pop esi
        .ENDIF

        ;// assume we never have depth > 100
        mov eax, ebx
        aam
        xchg al, ah
        or eax, 0A0D3030h
        stosd

        mov ecx, edi
        mov edi, OFFSET name&_rbtree_stdout_buffer
        sub ecx, edi
        stdout_Print edi,ecx

        pop edi

    ENDIF

    ENDM


;//------------------------------------------------------
;//
;// DumpStdout
;//     
;//
;//------------------------------------------------------

rbtree_DumpStdout MACRO name:req

    ;// dumps tree to stdout
    ;// we assume that key is a character, so we only show one byte

    ;// destroys eax,edx,ecx

    LOCAL display_node, display_left, back_up, display_done

    ;// format:
    ;//
    ;// Br--Cr--Dr--Er
    ;// |   |   |
    ;// |   |   Fb
    ;// |   |
    ;// |   Gb--Hb--Ib
    ;// |
    ;// Ar

    ;// make sure we have a buffer declared

        IFNDEF name&_rbtree_stdout_buffer
        .DATA?
            name&_rbtree_stdout_buffer db 1024 DUP (?)
        .CODE
        ENDIF

    ;// make sure stdout is opened

        .IF !hStdOut
            stdout_Open
        .ENDIF

    ;// we need a stack frame to show the V connectors correctly
    
        push ebp
        push esi
        push edi
        mov ebp,esp

    ;// start from the head

        rbtree_GetHead name, esi    ;// esi iterates the list

        mov edi, OFFSET name&_rbtree_stdout_buffer  ;// edi is the text buffer we build
        
    ;// always store a preceeding linefeed

        mov eax, 0a0d2020h
        stosd

    display_node:

    ;// display self

        ;//mov eax, rbtree_Key(name,esi)
        mov eax, [esi].name&_rb_btree_Key   ;//[iter].name&_btree_Key
        and eax, 0FFh

        .IF rbtree_Color(name,esi)
            or eax, 'b' SHL 8
        .ELSE
            or eax, 'r' SHL 8
        .ENDIF

        .IF rbtree_Right(name,esi)

        ;// H connector

            or eax, '--' SHL 16
            stosd

        ;// recurse

            rbtree_GetRight name,esi
            jmp display_node
            
        .ENDIF

    ;// name has no right

    ;// emit a line feed and display the line

        or eax, 0a0d0000h
        stosd

        mov ecx, edi
        mov edi, OFFSET name&_rbtree_stdout_buffer
        sub ecx, edi
        stdout_Print edi,ecx    ;// print the text
        
    display_left:

    ;// check for a left name

        .IF rbtree_Left(name,esi)

        ;// draw V connector lines
        ;// this is clumsy because we have to reverse the order
        ;// so as to get the connections on the correct names

        ;// V connectors including self plus linefeed and print

            pushd 0a0d2020h                 ;// display crlf    
            push '   |'                     ;// display self
            rbtree_GetLeft name,esi,ecx ;// tag-along
            rbtree_GetBack name,ecx,edx ;// iterator
            .WHILE edx
                .IF ecx == rbtree_Right(name,edx)
                    .IF rbtree_Left(name,edx)
                        push '   |' ;// name needs a V connector
                    .ELSE
                        push '    ' ;// name does not need a V connector
                    .ENDIF
                .ENDIF
                mov ecx, edx            ;// update tag-along
                rbtree_GetBack name,edx ;// get previous
            .ENDW                       ;// until we run off the top
            ;// xfer the stack to the display buffer
            .REPEAT         ;// use post loop, we know we have characters
                pop eax
                stosd
            .UNTIL esp == ebp
            ;// display the text
            mov ecx, edi
            mov edi, OFFSET name&_rbtree_stdout_buffer
            sub ecx, edi
            stdout_Print edi,ecx    ;// print the text

        ;// display | not including self and don't print

            rbtree_GetLeft name,esi,ecx ;// tag-along
            rbtree_GetBack name,ecx,edx ;// iterator
            .WHILE edx
                .IF ecx == rbtree_Right(name,edx)
                    .IF rbtree_Left(name,edx)
                        push '   |' ;// name needs a V connector
                    .ELSE
                        push '    ' ;// name does not need a V connector
                    .ENDIF
                .ENDIF
                mov ecx, edx            ;// update tag-along
                rbtree_GetBack name,edx ;// get previous
            .ENDW                       ;// until we run off the top
            ;// xfer the stck to the display buffer
            .WHILE esp != ebp   ;// use pre loop, we might be first character
                pop eax
                stosd
            .ENDW
            ;// go back to display loop
            rbtree_GetLeft name,esi
            jmp display_node
    
        .ENDIF  ;// no left

    ;// done displaying this name and all it's descendants

    ;// back up

        back_up:

            mov edx, esi
            rbtree_GetBack name,esi
            test esi, esi
            je display_done

        ;// if we were right, goto display_left
        ;// if we were left goto back_up

            cmp edx, rbtree_Right(name,esi)
            je display_left
            jmp back_up

    display_done:

        pop edi
        pop esi
        pop ebp
        
    ENDM



ENDIF   ;// _RBTREE_INCLUDED_





