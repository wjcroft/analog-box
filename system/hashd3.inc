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
;// hashd.inc
;//
comment ~ /*

    this is a simplistic (if not wrong) hashed dictionary

    it maps integer id's with integer values (pointers perferably)

    id = 0 IS NOT ALLOWED

    much of the design assumes that id's are used in consecutive order
    this is not required to be true, but the best performance is gained

    hash table overflow is implemented using pools that serve as linked lists

*/ comment ~

IFNDEF _HASHD_INCLUDED_
_HASHD_INCLUDED_ EQU 1

;// TOC
;//
;// hashd_Declare
;// hashd_Declare_common
;// hashd_Initialize
;// hashd_Destroy
;// hashd_Destroy_common
;// hashd_Clear
;//
;// hashd_build_address
;//
;// hashd_Get
;// hashd_Set
;// hashd_Find
;//
;// hashd_Insert
;// hashd_Delete


    IFNDEF <hashd_alloc>
    hashd_alloc TEXTEQU <GLOBALALLOC>
    ENDIF

    IFNDEF <hashd_free>
    hashd_free TEXTEQU <GLOBALFREE>
    ENDIF


    ;// declaration of a node

        HASHD_NODE STRUCT

            id  dd  0   ;// id assigned to this value
            val dd  0   ;// the value itself
            ovr dd  0   ;// ptr to the overflow slist

        HASHD_NODE ENDS



;////////////////////////////////////////////////////////////////////////
;//
;//     Declare
;//

    hashd_Declare MACRO name:req, num_keys:req, pool_allocating, val_assume

    ;// name is the name of the hash table
    ;// siz is the number of entries to present
    ;// pool_allocating may point to a pool allocater function (recomended)
    ;// val_assume may be applied if desired

            IFDEF name&_hashd_assume
            .ERR <name already declared>
            ENDIF

        ;// test and define the mask and size

            name&_hashd_size EQU num_keys * SIZEOF HASHD_NODE

            name&_hashd_size_test EQU LOG2(num_keys)    ;// will cause error of not power of 2

            name&_hashd_mask EQU (num_keys-1) SHL 2

        ;// define the table pointer

            name&_hashd_table dd 0  ;// ptr to the table

        ;// declare a pool of empties

            pool_Declare name&_hashd_pool, HASHD_NODE, num_keys, pool_allocating

        ;// define the assume if one is supplied

            IFB<val_assume>
            name&_hashd_assume TEXTEQU <NOTHING>
            ELSE
            name&_hashd_assume TEXTEQU <val_assume>
            ENDIF

        ENDM

    hashd_Declare_external MACRO name:req, num_keys:req, pool_allocating, val_assume

    ;// name is the name of the hash table
    ;// siz is the number of entries to present
    ;// pool_allocating may point to a pool allocater function (recomended)
    ;// val_assume may be applied if desired

            IFDEF name&_hashd_assume
            .ERR <name already declared>
            ENDIF

        ;// test and define the mask and size

            name&_hashd_size EQU num_keys * SIZEOF HASHD_NODE

            name&_hashd_size_test EQU LOG2(num_keys)    ;// will cause error of not power of 2

            name&_hashd_mask EQU (num_keys-1) SHL 2

        ;// define the table pointer

            EXTERNDEF name&_hashd_table:DWORD   ;// ptr to the table

        ;// declare a pool of empties

            pool_Declare_external name&_hashd_pool, HASHD_NODE, num_keys, pool_allocating

            IFDIF <pool_allocating>, <GENERATE_ALLOCATOR>
            name&_hashd_pool_allocating TEXTEQU pool_allocating
            ENDIF

        ;// define the assume if one is supplied

            IFB<val_assume>
            name&_hashd_assume TEXTEQU <NOTHING>
            ELSE
            name&_hashd_assume TEXTEQU <val_assume>
            ENDIF

        ENDM


    hashd_Declare_internal MACRO name:req

    ;// name is the name of the hash table
    ;// must be declared external

            IFNDEF name&_hashd_assume
            .ERR <name is not declared external>
            ENDIF

        ;// define the table pointer

            name&_hashd_table dd 0  ;// ptr to the table

        ;// declare a pool of empties

            pool_Declare_internal name&_hashd_pool  ;// , HASHD_NODE, name&_hashd_size, name&_hashd_pool_allocating

        ENDM








    hashd_Declare_common MACRO name:req, num_keys:req

        ;// this version declares a hash table that shares pool tables with other hashd's
        ;// user must define the hashd_common_pool_alloctor function see pool_allocater
        ;// the first declared common pool defines the size of the allocator pool

            IFDEF name&_hashd_assume
            .ERR <name already declared>
            ENDIF

        ;// test and define the mask and size

            name&_hashd_size EQU num_keys * SIZEOF HASHD_NODE

            name&_hashd_size_test EQU LOG2(num_keys)    ;// will cause error of not power of 2

            name&_hashd_mask EQU (num_keys-1) SHL 2

        ;// define the table pointer

            name&_hashd_table dd 0  ;// ptr to the table

        ;// declare a pool of empties

            name&_hashd_pool TEXTEQU <hashd_common_pool>

            IFNDEF hashd_common_pool_pool_assume

                pool_Declare hashd_common_pool, HASHD_NODE, num_keys, hashd_common_pool_alloctor

            ENDIF

        ;// define the assume if one is supplied

            IFB<val_assume>
            name&_hashd_assume TEXTEQU <NOTHING>
            ELSE
            name&_hashd_assume TEXTEQU <val_assume>
            ENDIF

        ENDM

;//
;//     Declare
;//
;////////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////////
;//
;//     Initialize/Destroy/Clear
;//
    ;// Allocate must be called to initialize the table

    hashd_Initialize MACRO name:req

        IFNDEF name&_hashd_table
        .ERR <name is not defined>
        ENDIF

        DEBUG_IF <name&_hashd_table>    ;// already allocated !!
        invoke hashd_alloc, GPTR, name&_hashd_size
        mov name&_hashd_table, eax
        ;// the pool will allocate itself
        ENDM

    ;// destroy must be called to free the table

    hashd_Destroy MACRO name:req

        IFNDEF name&_hashd_table
        .ERR <name is not defined>
        ENDIF

        .IF name&_hashd_table
            invoke hashd_free, name&_hashd_table
            mov name&_hashd_table, eax
        .ENDIF
        pool_Destroy name&_hashd_pool

        ENDM

    hashd_Destroy_common MACRO name:req

        ;// use this to destroy hashd's that use a common allocator

        IFNDEF name&_hashd_table
        .ERR <name is not defined>
        ENDIF

        .IF name&_hashd_table
            invoke hashd_free, name&_hashd_table
            mov name&_hashd_table, eax
        .ENDIF
        pool_Destroy hashd_common_pool

        ENDM


    ;// clear erases all the keys

    hashd_Clear MACRO name:req

        IFNDEF name&_hashd_table
        .ERR <name is not defined>
        ENDIF

        .IF name&_hashd_table

            push edi

            mov edi, name&_hashd_table
            mov ecx, (name&_hashd_size) / 4
            xor eax, eax

            rep stosd

            pop edi

        .ENDIF
        pool_Destroy name&_hashd_pool

        ENDM

;//
;//     Allocate/Destroy/Clear
;//
;////////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////////
;//
;//     build address       private macro helper
;//

    hashd_build_address MACRO name:req, id:req, reg:req

        ;// determine the hash address in a timely manner

        ;// this is assumed to be a local macro
        ;// not to be used elsewhere

        LOCAL o

        ;// make sure the list exists

            IFNDEF name&_hashd_table
            .ERR <name is not defined>
            ENDIF

        ;// varify that id and reg are registers

            o = (OPATTR(id))
            IF o NE 48
            .ERR <identifier must be a register>
            ENDIF

            o = (OPATTR(reg))
            IF o NE 48
            .ERR <identifier must be a register>
            ENDIF

        ;// check that they're different and double check the node size

            .ERRIDNI <id>,<reg>,<cant use register for identifier>

            IF SIZEOF(HASHD_NODE) NE 12
            .ERR <HASHD_NODE must be 12 bytes>
            ENDIF

        ;// do debug check on the id

            DEBUG_IF <!!id> ;// id is not supposed to be zero !!

        ;// do the work

            lea reg, [id*4]             ;// *4
            and reg, name&_hashd_mask   ;// mask out extra
            lea reg, [reg+reg*2]        ;// *12
            add reg, name&_hashd_table  ;// add on table offset
            ASSUME reg:PTR HASHD_NODE

        ENDM

;//
;//     build address   private macro helper
;//
;////////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////////
;//
;//     Get
;//


    hashd_Get MACRO name:req, ID:req, reg:req

        ;// get the value

        ;// BEWARE: fails if not in table

        LOCAL check_the_id, have_to_search, all_done

            hashd_build_address name, ID, reg

        check_the_id:

            DEBUG_IF <!!reg>    ;// id is not in table !!
            cmp ID, [reg].id    ;// is this the id we're want ?
            jne have_to_search  ;// assume it is (fall through = yes)
            mov reg, [reg].val  ;// load the value
            jmp all_done        ;// we're done

        have_to_search:

            mov reg, [reg].ovr  ;// get the ptr
            jmp check_the_id    ;// try again

        all_done:

        ASSUME reg:PTR name&_hashd_assume

        ENDM

;//
;//     Get
;//
;////////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////////
;//
;//     Set
;//


    hashd_Set MACRO name:req, ID:req, VAL:req, reg:=<eax>

        ;// set the value

        LOCAL check_the_id, have_to_search, all_done

        .ERRIDNI <ID>,<reg>,<identifier cant be reg>
        .ERRIDNI <val>,<reg>,<value cant be reg>


            hashd_build_address name, ID, reg

        check_the_id:

            DEBUG_IF <!!reg>    ;// id is not in table !!
            cmp ID, [reg].id    ;// is this the id we're want ?
            jne have_to_search  ;// assume it is (fall through = yes)
            mov [reg].val, VAL  ;// set the value
            jmp all_done        ;// we're done

        have_to_search:

            mov reg, [reg].ovr  ;// get the ptr
            jmp check_the_id    ;// try again

        all_done:

        ENDM

;//
;//     Set
;//
;////////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////////
;//
;//     Find
;//


    hashd_Find MACRO name:req, ID:req, reg:req

        ;// either get the value and clear the zero flag
        ;// or return zero and set the zero flag

        LOCAL check_the_id, have_to_search, all_done

            hashd_build_address name, ID, reg

        check_the_id:

            DEBUG_IF <!!reg>    ;// id is not in table !!
            cmp ID, [reg].id    ;// is this the id we're want ?
            jne have_to_search  ;// assume it is (fall through = yes)
            test reg, reg       ;// clear the zero flag
            mov reg, [reg].val  ;// load the value
            jmp all_done        ;// we're done

        have_to_search:

            mov reg, [reg].ovr  ;// get the ptr
            or reg, reg
            jne check_the_id    ;// try again

        all_done:

        ASSUME reg:PTR name&_hashd_assume

        ENDM

;//
;//     Find
;//
;////////////////////////////////////////////////////////////////////////



    ;// debugging

    hashd_fail_if_key_exists MACRO name:req, ID:req, reg:req

        ;// reg is already the desired pointer to the front of the hashd table

        IFDEF DEBUGBUILD

            push reg

            .REPEAT
            .IF ID == [reg].id
                int 3   ;// key already exists !!
            .ENDIF
            mov reg, [reg].ovr
            or reg, reg
            .UNTIL ZERO?

            pop reg

        ENDIF   ;// DEBUGBUILD

        ENDM



;////////////////////////////////////////////////////////////////////////
;//
;//     Insert          adds a new id to the table
;//                     fails if ID already exists


    hashd_Insert MACRO name:req, ID:req, VAL:req, reg:=<eax>

        LOCAL need_a_new_slot, all_done

        .ERRIDNI <ID>,<reg>,<identifier cant be reg>
        .ERRIDNI <VAL>,<reg>,<value cant be reg>

            hashd_build_address name, ID, reg

            hashd_fail_if_key_exists name, ID, reg

            cmp [reg].id, 0
            jne need_a_new_slot
            mov [reg].id, ID
            mov [reg].val, VAL
            jmp all_done

        need_a_new_slot:    ;// move the head to a new slot

            push [reg].id
            push [reg].val
            push [reg].ovr

            mov [reg].id, ID
            mov [reg].val, VAL
            mov ID, reg         ;// recast ID as the new head
            push ID         ;// save it (sloppy, but fixed a bug)

            pool_GetUnused name&_hashd_pool, reg

            pop ID          ;// retrieve it (sloppy, but fixed a bug)
            pop [reg].ovr
            pop [reg].val
            pop [reg].id

            mov (HASHD_NODE PTR [ID]).ovr, reg  ;// point new head at new next
            mov ID, (HASHD_NODE PTR [ID]).id    ;// retrieve the id

        all_done:

        ENDM

;//
;//     Insert
;//
;////////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////////
;//
;//     Delete
;//

    hashd_Delete MACRO name:req, ID:req, reg:=<eax>, reg1:=<edx>

        LOCAL have_to_unchain, have_to_find, remove_from_pool, all_done

        .ERRIDNI <ID>,<reg>,<identifier cant be reg>
        .ERRIDNI <ID>,<reg1>,<identifier cant be reg1>

            hashd_build_address name, ID, reg

            cmp [reg].ovr, 0
            jne have_to_unchain

            DEBUG_IF <ID !!= [reg].id>  ;// id is not in the table !!
            mov [reg].id, 0
            jmp all_done

        have_to_unchain:

            cmp ID, [reg].id    ;// are we already there (remove first item)
            jne have_to_find    ;// skip if not already there

            ;// remove the first item
            mov reg1, [reg].ovr

            push (HASHD_NODE PTR [reg1]).id
            push (HASHD_NODE PTR [reg1]).val

            xchg reg, reg1

            pop (HASHD_NODE PTR [reg1]).val
            pop (HASHD_NODE PTR [reg1]).id

            jmp remove_from_pool

        have_to_find:

            mov reg1, reg       ;// save as previous
            mov reg, [reg].ovr  ;// get the next in the chain
            DEBUG_IF <!!reg>    ;// id is not in table
            cmp ID, [reg].id    ;// are we there yet ?
            jne have_to_find    ;// try again if not

        remove_from_pool:

            ;// reg1 points at previous
            mov ID, [reg].ovr   ;// get the next in the chain
            mov (HASHD_NODE PTR [reg1]).ovr, ID ;// save as prev.pNext

            pool_PutUnused name&_hashd_pool, reg;// put slot back in the pool

            mov ID, (HASHD_NODE PTR [ID]).id    ;// retrieve the id

        all_done:

            ENDM

;//
;//     Delete
;//
;////////////////////////////////////////////////////////////////////////


ENDIF ;// _HASHD_INCLUDED_