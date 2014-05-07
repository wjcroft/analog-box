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
;//     bnhlist.inc     Back Next Head List
;//
IFNDEF _BNHLIST_INCLUDED_
_BNHLIST_INCLUDED_ EQU 1

    INCLUDE <testjump.inc>


comment ~ /*

    Back Next Head

    bnh lists are modeled after the AnalogBox connection scheme
    they are intended to reprepresent uni-directional connections between objects
    any one source object may have several destination objects attached to it
    any one destination has at most one source

    in this file

        Back means a pointer to the source object
            any number of objects may have identical back pointers
            meaning that they all connect to the same source
        Next means the next object that has an identical back pointer
            next pointers are assumed to be unique
        Head means the pointer to to the first connection from a source object to dest object
            head pointers are assumed to be unique

             0
             A                         example:
             |                         b = back   A = up direction
             b                         n = next   V = down direction    
             |                         h = head
            NODE0
            |  A                                  NODE0 can be considered the parent of NODE1,2,3
            |  |______________________            NODE1 can be considered a sibling of NODE2 and 3
            h  |         |            |           NODE0 has no parent
            |  b         b            b           NODE1,2,3 have no children
            V  |         |            |
            NODE1 --n--> NODE2 --n--> NODE3 --n--> 0
             |           |            |
             h           h            h
             |           |            |
             V           V            V
             0           0            0

    there is no global Head
    this means that some other container must manage the existance of the object itself
    all these macros do is define connections between objects

    ALL MACROS START WITH bnh_

    while these macros maintain single connections
    it is entirely possible to navigate through all the links of a connected graph
    use the GetHead and GetBack to navigate objects in a circuit
    as required, use GetNext to navigate the side chains

    Insert and Delete are not defined
    use Connect and Unconnect instead
    This allows for simpler implementation and somewhat easier conceptualization

*/ comment ~

;////////////////////////////////////////////////////////////////////////////////
;//
;//
;//     DECLARITOR


    ;// this is all that is needed to declare a bnh list
    ;// use this inside the STRUCT definition of the object
    ;// 3 dword pointers are assigned

    bnh_Declare_link MACRO nam:req, stru:req

        IFDEF nam&_bnh_assume
        .ERR < bnh nam is already declared !!!! >
        ENDIF

        nam&_bnh_assume TEXTEQU <stru>

        nam&_bnh_pHead  dd  ?   ;// ptr to first connected object
        nam&_bnh_pNext  dd  ?   ;// ptr to next connected object
        nam&_bnh_pBack  dd  ?   ;// ptr to source object

        ENDM

    
;//     DECLARITOR
;//
;//
;////////////////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////////////////
;//
;//
;//     ACCSESSOR FUNCTIONS


    bnh_Head MACRO nam:req, reg:req

        ;// bnh_Head()  enter
        LOCAL t,s
        IFNDEF nam&_bnh_assume
        .ERR <bnh nam is not declared>
        ENDIF
    %   s CATSTR <nam>, <_bnh_pHead>
    %   t CATSTR <BRACKET(reg)>, <.>, <s>
        ;// bnh_Head()      exit
        EXITM t
        ENDM


    bnh_Next MACRO nam:req, reg:req

        ;// bnh_Next()  enter
        LOCAL t,s
        IFNDEF nam&_bnh_assume
        .ERR <bnh nam is not declared>
        ENDIF
    %   s CATSTR <nam>, <_bnh_pNext>
    %   t CATSTR <BRACKET(reg)>, <.>, <s>
        ;// bnh_Next()      exit
        EXITM t
        ENDM

    bnh_Back MACRO nam:req, reg:req

        ;// bnh_Back()  enter
        LOCAL t,s
        IFNDEF nam&_bnh_assume
        .ERR <bnh nam is not declared>
        ENDIF
    %   s CATSTR <nam>, <_bnh_pBack>
    %   t CATSTR <BRACKET(reg)>, <.>, <s>
        ;// bnh_Back()      exit
        EXITM t
        ENDM

;//     ACCSESSOR FUNCTIONS
;//
;//
;////////////////////////////////////////////////////////////////////////////////

;////////////////////////////////////////////////////////////////////////////////
;//
;//
;//     MAINTANCE

    bnh_ClearNode MACRO nam:req, reg:req, zero_reg

        IFNB <zero_reg>
            mov bnh_Head(nam, reg), zero_reg
            mov bnh_Next(nam, reg), zero_reg
            mov bnh_Back(nam, reg), zero_reg
        ELSE
            mov bnh_Head(nam, reg), 0
            mov bnh_Next(nam, reg), 0
            mov bnh_Back(nam, reg), 0
        ENDIF

        ENDM




;//     MAINTANCE
;//
;//
;////////////////////////////////////////////////////////////////////////////////



        
;////////////////////////////////////////////////////////////////////////////////
;//
;//
;//     ITERATORS


    bnh_GetHead MACRO nam:req, reg:req, from

        IFB <from>
            mov reg, bnh_Head(nam,reg)
        ELSE
            mov reg, bnh_Head(nam,from)
            ASSUME reg:PTR nam&_bnh_assume
        ENDIF

        ENDM

    bnh_GetNext MACRO nam:req, reg:req, from

        IFB <from>
            mov reg, bnh_Next(nam,reg)
        ELSE
            mov reg, bnh_Next(nam,from)
            ASSUME reg:PTR nam&_bnh_assume
        ENDIF

        ENDM

    bnh_GetBack MACRO nam:req, reg:req, from

        IFB <from>
            mov reg, bnh_Back(nam,reg)
        ELSE
            mov reg, bnh_Back(nam,from)
            ASSUME reg:PTR nam&_bnh_assume
        ENDIF

        ENDM



    bnh_OrGetHead MACRO nam:req, reg:req, from:req

        or reg, bnh_Head(nam,from)
        ASSUME reg:PTR nam&_bnh_assume

        ENDM

    bnh_OrGetNext MACRO nam:req, reg:req, from:req

        or reg, bnh_Next(nam,from)
        ASSUME reg:PTR nam&_bnh_assume

        ENDM

    bnh_OrGetBack MACRO nam:req, reg:req, from:req

        or reg, bnh_Back(nam,from)
        ASSUME reg:PTR nam&_bnh_assume

        ENDM

;//     ITERATORS
;//
;//
;////////////////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////////////////
;//
;//
;//     CONNECT UNCONNECT

    ;// Connect new dest to src
    ;// assume that new is cleared

    bnh_Connect MACRO nam:req, new:req, src:req, temp:=<eax>

        ;// insert new as src.head, push existing source head back
        mov temp, bnh_Head(nam,src)     ;// get existing head
        mov bnh_Back(nam,new),src       ;// set the new back pointer
        mov bnh_Next(nam,new),temp      ;// set the new.next as the old head
        mov bnh_Head(nam,src),new       ;// set src.head as new

        ENDM


    bnh_ConnectAtEnd MACRO nam:req, new:req, src:req, temp:=<eax>

        ;// insert new at end of src.head list, not at head as before

        LOCAL check_if_at_end
        LOCAL insert_after_temp
        LOCAL set_as_head
        LOCAL done_with_this

            xor temp, temp
            mov bnh_Back(nam,new),src       ;// set the new back pointer
            mov bnh_Next(nam,new),temp      ;// set the new.next as zero, we are at the end
            
            bnh_OrGetHead nam,temp,src      ;// get existing head and check for zero
            jz set_as_head
        check_if_at_end:
            cmp bnh_Next(nam,temp),0
            je insert_after_temp
            bnh_GetNext nam,temp
            jmp check_if_at_end
        insert_after_temp:
            mov bnh_Next(nam,temp),new
            jmp done_with_this
        set_as_head:
            mov bnh_Head(nam,src),new       ;// set src.head as new
        done_with_this:

        ENDM





    ;// Unconnect reg from it's source
    ;// safe to use if not connected
    ;// unsafe to use if list is corrupted
    ;// does not remove reg's connections to destinations
    ;// = does not remove the head list for this object

    bnh_Unconnect MACRO nam:req, reg:req, temp1:=<eax>, temp2:=<edx>

        LOCAL reg_not_head
        LOCAL top_of_unconnect_search
        LOCAL ready_to_unconnect
        LOCAL done_unconnecting
        LOCAL not_connected

            xor temp1,temp1
            bnh_OrGetBack nam,temp1,reg
            jz not_connected
            CMPJMP bnh_Head(nam,temp1), reg, jne reg_not_head
        ;// temp1 is the source object

        ;// reg is first item
            mov temp2, bnh_Next(nam,reg)
            mov bnh_Head(nam,temp1),temp2
            jmp done_unconnecting
        reg_not_head:   ;// have to search for previous item to reg
            bnh_GetHead nam,temp1
            DEBUG_IF <!!temp1>              ;// corrupted list          
        top_of_unconnect_search:            ;// temp1 is iterting the connections
            mov temp2, bnh_Next(nam,temp1)
            CMPJMP temp2, reg, je ready_to_unconnect
            mov temp1,temp2
            jmp top_of_unconnect_search
        ready_to_unconnect:                 ;// link previous to reg.next
            mov temp2, bnh_Next(nam,reg)    
            mov bnh_Next(nam,temp1),temp2
        done_unconnecting:
            xor temp1, temp1
            mov bnh_Back(nam,reg), temp1    ;// clear the back pointer      
        not_connected:  ;// temp1 = 0
            mov bnh_Next(nam,reg), temp1    ;// clear the next pointer

        ENDM        

;//     CONNECT UNCONNECT
;//
;//
;////////////////////////////////////////////////////////////////////////////////












ENDIF   ;// _BNHLIST_INCLUDED_