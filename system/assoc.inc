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
;// assoc.inc       associative container
;//
IFNDEF _ASSOC_INC_INCLUDED_
_ASSOC_INC_INCLUDED_ EQU 1

comment ~ /*

    the purpose of this container is to share units of data 
    between different container structs

    ie: associate STRUCT_1 with STRUCT_2 by sharing STRUCT_3
        associate STRUCT_1 with STRUCT_4 by sharing STRUCT_5
        etc
        then be able to iterate

    the mechanism used is all about KEY's and LINK's

    a KEY is a struct that one wishes to attach LINKS to
    a LINK is a center connector between KEY's

    there may be several KEY's attached to a LINK
    
    RULE: 1 LINK many KEYS

    keys are accessed by name

    name defaults to the struct name, or may be aliased

    To iterate, start some where, then make one step transtions to the next point

example:

    given

        a list of images called FRAMES
        a list of named features called NAME
        a MARKER stating the location of a specific NAME on a specific FRAME

    tasks:
        quickly determine all frames with a given fetures
        determine what features a frame contians
        determine where a particular feature is

    define FRAME, SET, and MARKER

        MARKER  STRUCT

            ; in the nomenclature, MARKER is a _link_
            
            location    POINT   {}  ;// location of this marker
            
            assoc_Declare_link    marker, MARKER    ;// state that we are creating a marker association
            
            ; declare link defines the intermediate struct (MARKER) used to 
            ; connect FRAMEs and NAMEs

            assoc_Declare_keyname marker, FRAME     ;// fwd/bak pointers to frame assigned to markers
            assoc_Declare_keyname marker, NAME      ;// fwd/bak pointers to set assigned to markers

            ; this marker may be used to get at the frame, or the set by following the bak pointer
            ; or it may be used to get the next frame or set by following the fwd pointer
            ; declare_keyname allocates 2 pointers and defines the struct that they point to 
        
        MARKER ENDS
        
        FRAME   STRUCT

            ; in the nomenclature, FRAME is a _key_
            
            image_data  IMAGE {}

            assoc_Declare_key marker, FRAME ;// pointer to first associated marker

            ; this frame may have many markers attached to it, each having a different name
            ; Declare_key allocates the head of the slist

        FRAME   ENDS

        NAME    STRUCT

            ; in the nomenclature, NAME is a _key_

            marker_name db  16 DUP (?)

            assic_Declare_key marker, MARKER_NAME

            ; this set may have many mamy markers, each belonging to a different frame
            ; Declare_key allocates the head of the slist

        NAME ENDS

    we now have all the constructs in place to attach different named markers
    to a specific frame. we are also able determine what frames have a given feature

    1) iterate the markers attached to a specific frame

        ASSUME esi:PTR FRAME
        
        assoc_GetHead marker, FRAME, edi, esi   ;// edi is now the first marker belonging to [esi]
        ; asked for the first MARKER in the FRAME set
        .WHILE edi
            
            ... do work with MARKER [edi]

            assic_GetNext marker, FRAME, edi    ;// get the next marker attached to this frame
            ; now we asked for the NEXT marker with the same FRAME

        .ENDW

    2) locate all the frames belong to a NAME

        




*/ comment ~

;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////
;///
;///                        Declare_link        declares the association name and the link struct
;///    DECLARITORS         Declare_keyname     declares a pointer in the link struct            
;///                        Declare_key         declares the pointer to the link in a key struct 
;///

;// only one link per container
;// declare the assume for this link

assoc_Declare_link MACRO assoc_name:req, struct_name:req

    IFDEF assoc_name&_LINK_ASSUME_assoc
    .ERR <assoc_name is already declared !! >
    ENDIF

    assoc_name&_LINK_ASSUME_assoc   TEXTEQU <struct_name>

    ENDM

;// must have a link declared before this
;// declare the assume for this key
;// define the data needed for this link

assoc_Declare_keyname MACRO assoc_name:req, struct_name:req, key_name

    .ERRNDEF assoc_name&_LINK_ASSUME_assoc, <assoc_name is needs a link declared first !! >

    IFB <key_name>  ;// key name == struct name

        IFDEF assoc_name&_&struct_name&_ASSUME_assoc
        .ERR <key name is already defined !! >
        ENDIF

        assoc_name&_&struct_name&_ASSUME_assoc TEXTEQU <struct_name>

        assoc_name&_pNext_&struct_name&_assoc   dd  ?   ;// next pointer to link
        assoc_name&_pKey_&struct_name&_assoc    dd  ?   ;// back pointer to KEY

    ELSE    

        IFDEF assoc_name&_&key_name&_ASSUME_assoc
        .ERR <key name is already defined !! >
        ENDIF

        assoc_name&_&key_name&_ASSUME_assoc TEXTEQU <struct_name>
        
        assoc_name&_pNext_&key_name&_assoc  dd  ?   ;// next pointer to link
        assoc_name&_pKey_&key_name&_assoc   dd  ?   ;// back pointer to KEY

    ENDIF

    ENDM


;// use inside a key struct to point to first link in set
;// declare data for the link

assoc_Declare_key MACRO assoc_name:req, _name:req

    .ERRNDEF assoc_name&_LINK_ASSUME_assoc, <assoc_name is needs a link declared first !! >

    IFNDEF assoc_name&_&_name&_ASSUME_assoc
    .ERR <this key is not defined !!! >
    ENDIF

    assoc_name&_pHead_&_name&_assoc dd  ?   ;// ptr to first node in this list

    ENDM


;///
;///                            Declare_link        declares the association name and the link struct
;///    DECLARITORS             Declare_keyname     declares a pointer in the link struct            
;///                            Declare_key         declares the pointer to the link in a key struct 
;///
;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////




;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////
;///
;///                            Head    Key->Link   returns name of pointer to first link in set
;///    ACCESSOR FUNCTIONS      Next    Link->Link  returns name of pointer to next link in set
;///                            Key     Link->Key   returns name of poiner to key owner for this set
;///


assoc_Head MACRO assoc_name:req, key_name:req, reg:req

    .ERRNDEF assoc_name&_LINK_ASSUME_assoc, <assoc_name needs to have a shared link defined !! >
    .ERRNDEF assoc_name&_&key_name&_ASSUME_assoc, <assoc_name key is not defined !! >

    EXITM <[reg].&assoc_name&_pHead_&key_name&_assoc>

    ENDM

assoc_Next MACRO assoc_name:req, key_name:req, reg:req

    .ERRNDEF assoc_name&_LINK_ASSUME_assoc, <assoc_name needs to have a shared link defined !! >
    .ERRNDEF assoc_name&_&key_name&_ASSUME_assoc, <assoc_name key is not defined !! >

    EXITM <[&reg&].&assoc_name&_pNext_&key_name&_assoc>

    ENDM

assoc_Key MACRO assoc_name:req, key_name:req, reg:req

    .ERRNDEF assoc_name&_LINK_ASSUME_assoc, <assoc_name needs to have a shared link defined !! >
    .ERRNDEF assoc_name&_&key_name&_ASSUME_assoc, <assoc_name key is not defined !! >

    EXITM <[&reg&].&assoc_name&_pKey_&key_name&_assoc>

    ENDM



;///
;///                            Head    Key->Link   returns name of pointer to first link in set
;///    ACCESSOR FUNCTIONS      Next    Link->Link  returns name of pointer to next link in set
;///                            Key     Link->Key   returns name of poiner to key owner for this set
;///
;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////


;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////
;///
;///                            GetHead     Key  -> first Link in set
;///    ITERATORS               GetNext     Link -> Next link in set 
;///                            GetKey      Link -> key              
;///

assoc_GetHead MACRO assoc_name:req, key_name:req, reg:req, this_reg:req

    mov reg,assoc_Head(assoc_name,key_name,this_reg)
    ASSUME reg:PTR assoc_name&_LINK_ASSUME_assoc

    ENDM


assoc_GetNext MACRO assoc_name:req, key_name:req, reg:req, reg2

    IFNB <reg2>
        mov reg2,assoc_Next(assoc_name,key_name,reg)
        ASSUME reg2:PTR assoc_name&_LINK_ASSUME_assoc
    ELSE
        mov reg,assoc_Next(assoc_name,key_name,reg)
    ENDIF

    ENDM


assoc_GetKey MACRO assoc_name:req, key_name:req, reg:req, link_reg:req

    mov reg,assoc_Key(assoc_name,key_name,link_reg)
    ASSUME reg:PTR assoc_name&_&key_name&_ASSUME_assoc

    ENDM


;///
;///                            GetHead     Key  -> first Link in set
;///    ITERATORS               GetNext     Link -> Next link in set 
;///                            GetKey      Link -> key              
;///
;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////


;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////
;///
;///    
;///    Insert      must insert once for each link
;///    Remove      must remove once for each link
;///


assoc_Insert MACRO assoc_name:req, key_name:req, link_reg:req, key_reg:req, temp:=<eax>

;// always inserts at the head

    mov temp, assoc_Head(assoc_name,key_name,key_reg)
    mov assoc_Key(assoc_name,key_name,link_reg), key_reg
    mov assoc_Head(assoc_name,key_name,key_reg),link_reg
    mov assoc_Next(assoc_name,key_name,link_reg),temp

    ENDM

assoc_Remove MACRO assoc_name:req, key_name:req, link_reg:req, temp:=<eax>

;// UNSAFE TO USE if link is not a member of KEY
;// DOES NOT clear the data

    LOCAL search_loop

    assoc_GetKey assoc_name, key_name, temp, link_reg   ;// get T
    push assoc_Next(assoc_name,key_name,link_reg)       ;// push L.next
    .IF link_reg == assoc_Head(assoc_name,key_name,temp);// L == T.head ?
        ;// we are removing the head
        ;//     T          L
        ;// key.head --> link1 --> link2 --> link3
        lea temp, assoc_Head(assoc_name,key_name,temp)  ;// pop T.head
        ;//     T        
        ;// key.head --> link2 --> link3
    .ELSE
        ;// we have to determine who points to us
        ;//     T                   L
        ;// key.head --> link1 --> link2 --> link3
        assoc_GetHead assoc_name,key_name,temp,temp
    search_loop:
        .IF link_reg != assoc_Next(assoc_name,key_name,temp)
            assoc_GetNext assoc_name,key_name,temp
            jmp search_loop
        .ENDIF
        lea temp, assoc_Next(assoc_name,key_name,temp)
        ;//                T        
        ;// key.head --> link1 --> link3    
    .ENDIF
    pop DWORD PTR [temp]

    ENDM

;///    
;///    Insert
;///    Remove
;///
;///
;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////






ENDIF ;// _ASSOC_INC_INCLUDED_