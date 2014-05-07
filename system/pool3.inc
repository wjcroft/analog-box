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

; AJT: over the years, project flux has _possibly_ broken parts of the pool system
;      as such, the _Declare triple (ie in-place, external and internal)
;      may not be consitant across all 'alloc' declarations ...

;//
;// pool3.inc
;//
IFNDEF _POOL3_INCLUDED_
_POOL3_INCLUDED_ EQU 1

comment ~ /*

    a pool is a container of fixed size objects
    use a pool to keep a stash of memory blocks that need to be
    allocated and freed VERY often

    pool allocates n objects at a time and maintain an unused object list

    objects are removed from the pool using pool_GetUnused
    objects are returned to the pool using pool_PutUnused
    both of these happen in O(1) time unless the pool needs to allocate a new block
    in which case, time is at the mercy of the allocator

    declaring a pool requires a struct to store, the number of structs to allocate
    and a reference to an allocator/destroyer function to use

*/ comment ~

;// TOC
;//
;// pool_Declare
;//
;// pool_allocator
;// pool_Destroy
;// pool_Clear
;//
;// pool_GetUnused
;// pool_PutUnused
;//
;// pool_GetDebugStats


;// default memory managers

    IFNDEF <pool_alloc>
    pool_alloc TEXTEQU <GLOBALALLOC>
    ENDIF

    IFNDEF <pool_free>
    pool_free TEXTEQU <GLOBALFREE>
    ENDIF

;//////////////////////////////////////////////////////
;//
;//     declare
;//

    pool_Declare MACRO name:req, stru:req, block:req, alloc:req, aligner

    ;// name is name of pool, must be unique among pools
    ;// stru is the structure to hold in the pool
    ;// block is the number of items to store in the pool
    ;// alloc may specify a common pool_allocator to use (must be a function somewhere)
    ;// aligner may be 16 or 32 to specify extra frame padding for cache alignment
    ;// alloc may be GENERATE_ALLOCATOR which will define an allocator for us

            IFDEF name&_pool_assume
            .ERR <name is already declared>
            ENDIF

        ;// make sure stru is big enough

            IF SIZEOF(stru) LT 8
            .ERR <stru is too small>
            ENDIF

        ;// define this node

            name&_POOL_UNUSED   STRUCT

                next_unused dd  0

                padding db SIZEOF(stru)-4 DUP (0)

            name&_POOL_UNUSED ENDS

        ;// define a frame for the nodes

            name&_POOL_FRAME STRUCT

                next_frame  dd  ?   ;// slist of next frame

                IFNB <aligner>
                    IF aligner EQ 16
                        dd 3 DUP (0)
                    ELSEIF aligner EQ 32
                        dd 7 DUP (0)
                    ELSE
                        .ERR <Aligner must be 16 or 32 or leave blank>
                    ENDIF
                ENDIF

                unused name&_POOL_UNUSED block DUP ({})

            name&_POOL_FRAME ENDS

        ;// define the anchors for the pool

            name&_pool_frame    dd  0   ;// ptr to first frame
            name&_pool_unused   dd  0   ;// ptr to first available record

        ;// set the assume to use when we extract items from the pool

            name&_pool_assume TEXTEQU <stru>

        ;// declare the allocator
        ;// if specified, generate the allocator code
        ;// but not both

            IFDIF <alloc>,<GENERATE_ALLOCATOR>
                IFNB <alloc>
                name&_pool_allocator TEXTEQU <alloc>
                ENDIF
            ELSE
                .CODE
                ASSUME_AND_ALIGN
                name&_pool_allocator PROC
            %   pool_allocator name, eax
                retn
                name&_pool_allocator ENDP
                .DATA
            ENDIF


        ENDM


    pool_Declare_external MACRO name:req, stru:req, block:req, alloc, aligner

    ;// name is name of pool, must be unique
    ;// stru is the structure to hold in the pool
    ;// block is the number of items to store in the pool
    ;// alloc may specify a common pool_allocator to use (must be a function somewhere)

            IFDEF name&_pool_assume
            .ERR <name is already declared>
            ENDIF

        ;// make sure stru is big enough

            IF SIZEOF(stru) LT 8
            .ERR <stru is too small>
            ENDIF

        ;// define this node

            name&_POOL_UNUSED   STRUCT

                next_unused dd  0

                padding db SIZEOF(stru)-4 DUP (0)

            name&_POOL_UNUSED ENDS

        ;// define a frame for the nodes

            name&_POOL_FRAME STRUCT

                next_frame  dd  ?   ;// slist of next frame

                IFNB <aligner>
                    IF aligner EQ 16
                        dd 3 DUP (0)
                    ELSEIF aligner EQ 32
                        dd 7 DUP (0)
                    ELSE
                        .ERR <Aligner must be 16 or 32 or leave blank>
                    ENDIF
                ENDIF

                unused name&_POOL_UNUSED block DUP ({})

            name&_POOL_FRAME ENDS

        ;// define the anchors for the pool

            EXTERNDEF name&_pool_frame:DWORD    ;// ptr to first frame
            EXTERNDEF name&_pool_unused:DWORD   ;// ptr to first available record

        ;// set the assume to use when we extract items from the pool

            name&_pool_assume TEXTEQU <stru>

        ;// declare the allocator

            IFDIF <alloc>,<GENERATE_ALLOCATOR>
                IFNB <alloc>
                name&_pool_allocator TEXTEQU <alloc>
                ENDIF
                name&_generate_allocator EQU 0
            ELSE
                name&_generate_allocator EQU 1
            ENDIF

            EXTERNDEF name&_pool_allocator:NEAR

        ENDM



    pool_Declare_internal MACRO name:req

    ;// name is name of pool, must be unique
    ;// stru is the structure to hold in the pool
    ;// block is the number of items to store in the pool
    ;// alloc may specify a common pool_allocator to use (must be a function somewhere)

            IFNDEF name&_pool_assume
            .ERR <name is not declared external>
            ENDIF

        ;// define the anchors for the pool

            name&_pool_frame    dd  0   ;// ptr to first frame
            name&_pool_unused   dd  0   ;// ptr to first available record

        ;// if desired, generate the allocator

            IF name&_generate_allocator EQ 1
                .CODE
                ASSUME_AND_ALIGN
                name&_pool_allocator PROC
            %   pool_allocator name, eax
                retn
                name&_pool_allocator ENDP
                .DATA
            ENDIF

        ENDM




    pool_Declare_alias MACRO new_name,new_assume,old_name

    ;// this sets up a pool to use exactly the same size items as some other pool
    ;// a new assume may be defined
    ;// useful when there is a need to share memory

            IFDEF new_name&_pool_assume
            .ERR <pool Declare alias: new_name is already declared>
            ENDIF
            IFNDEF old_name&_pool_assume
            .ERR <pool Declare alias: old_name is not declared>
            ENDIF
            .ERRNZ ((SIZEOF new_assume)-(SIZEOF old_name&_pool_assume)), <structs are different sizes>

        ;// define this node

            new_name&_POOL_UNUSED CATSTR <old_name>,<_POOL_UNUSED>

        ;// define a frame for the nodes

            new_name&_POOL_FRAME CATSTR <old_name>,<_POOL_FRAME>

        ;// define the anchors for the pool

            new_name&_pool_frame    CATSTR  <old_name>,<_pool_frame>
            new_name&_pool_unused   CATSTR  <old_name>,<_pool_unused>

        ;// set the assume to use when we extract items from the pool

            new_name&_pool_assume TEXTEQU <new_assume>

        ;// declare the allocator

            new_name&_pool_allocator CATSTR <old_name>,<_pool_allocator>

        ENDM





;//
;//     declare
;//
;//////////////////////////////////////////////////////


;//////////////////////////////////////////////////////
;//
;//     frame stitcher          private macro helper
;//

    pool_stitch_frame MACRO name:req, frame:req, iter:=<eax>, reg:=<edx>

        ;// returns frame as the first record to use
        ;// destroys iter and frame

        LOCAL top_of_stitch, done_with_stitch

        PUSHCONTEXT ASSUMES

        .ERRIDNI <iter>,<frame>,<registers mustnt be the same>
        .ERRIDNI <iter>,<reg>,<registers mustnt be the same>
        .ERRIDNI <frame>,<reg>,<registers mustnt be the same>

        DEBUG_IF <name&_pool_unused>    ;// only call when unused is empty !!

            lea iter, [frame + SIZEOF name&_POOL_FRAME - SIZEOF name&_POOL_UNUSED]
            ASSUME iter:PTR name&_POOL_UNUSED
            lea frame, [frame].unused
            ASSUME frame:PTR name&_POOL_FRAME
            xor reg, reg

        top_of_stitch:

            mov [iter].next_unused, reg
            mov reg, iter
            sub iter, SIZEOF name&_POOL_UNUSED
            cmp iter, frame
            jb done_with_stitch

            mov [iter].next_unused, reg
            mov reg, iter
            sub iter, SIZEOF name&_POOL_UNUSED
            cmp iter, frame
            jae top_of_stitch

        done_with_stitch:

            mov name&_pool_unused, reg

        POPCONTEXT ASSUMES

        ENDM

;//
;//     frame stitcher          private macro helper
;//
;//////////////////////////////////////////////////////


;//////////////////////////////////////////////////////
;//
;//     block allocator
;//
;//
    ;// this allocates a new pool block and stitiches it together
    ;// it is only accessed from pool_GetUnused

    ;// allocator may be put in a function or used inline
    ;// if function: be sure to add a ret after wards
    ;//
    ;// example:
    ;//
    ;//     myAllocater PROC
    ;//         pool_allocator myName, eax
    ;//         retn
    ;//     myAllocater ENDP
    ;//
    ;// note: if function, reg must equal eax, otherwise the return value is lost
    ;//
    ;// destroys eax

    pool_allocator MACRO name:req, reg:req

        ;// save nessesary registers

            IFDIFI <reg>,<ecx>
            push ecx
            ENDIF

            IFDIFI <reg>,<edx>
            push edx
            ENDIF

        ;// allocate a new block and put at head of pool

            push name&_pool_frame       ;// save the old frame

            ;// allocate the new block

            invoke pool_alloc, GPTR, SIZEOF(name&_POOL_FRAME)
            DEBUG_IF <!!eax>

            ;// set reg as the start of the new block

            IFDIFI <reg>,<eax>
            mov reg, eax
            ENDIF

            mov name&_pool_frame, reg   ;// set the new frame
            ASSUME reg:PTR name&_POOL_FRAME

            pop [reg].next_frame        ;// link in the old frame

        ;// stitch the records together
        ;// stitch will return reg as the first record

            IFIDNI <reg>,<edx>
                pool_stitch_frame name, reg, eax, ecx
            ELSEIFIDNI <reg>,<eax>
                pool_stitch_frame name, reg, edx, ecx
            ELSE
                pool_stitch_frame name, reg
            ENDIF

        ;// retrieve registers

            IFDIFI <reg>,<edx>
            pop edx
            ENDIF
            IFDIFI <reg>,<ecx>
            pop ecx
            ENDIF
        ENDM

        ;// that should do it


;// let's save some hassle and make a macro for the allocator

    POOL_ALLOCATER MACRO nam:REQ
        ASSUME_AND_ALIGN
        nam&_pool_allocator PROC
            pool_allocator nam, eax
            retn
        nam&_pool_allocator ENDP
        ENDM


;//
;//     Allocater
;//
;//////////////////////////////////////////////////////

;//////////////////////////////////////////////////////
;//
;//     Destroy
;//
    ;// deallocates all frames
    ;// clears the frame head as well

    pool_Destroy MACRO name:req

        LOCAL top_of_destroy, all_done

    %   ASSUME eax:PTR name&_POOL_FRAME

            xor eax, eax                ;// clear for testing

        top_of_destroy:

            or eax, name&_pool_frame    ;// load and test the head
            jz all_done

            push eax                    ;// save what we want to free
            mov eax, [eax].next_frame   ;// load the next frame
            mov name&_pool_frame, eax   ;// set as new frame head

            call pool_free              ;// free the memory
            jmp top_of_destroy          ;// free returns zero, jump to next test

        all_done:

            mov name&_pool_unused, eax  ;// don't forget to do this !!

        ENDM

;//
;//     destroy
;//
;//////////////////////////////////////////////////////



;//////////////////////////////////////////////////////
;//
;//     pool_Clear
;//
    ;// frees extra blocks
    ;// clears the final block

    ;// destroys eax, edx, ecx


    pool_Clear MACRO name:req

        LOCAL top_of_destroy, done_with_destroy, pool_clear_done

        %   ASSUME eax:PTR name&_POOL_FRAME

            xor eax, eax

        ;// free extra blocks
        top_of_destroy:

            or eax, name&_pool_frame    ;// load and test the head
            jz pool_clear_done

            mov edx, [eax].next_frame
            or edx, edx
            je done_with_destroy

            push eax                    ;// save what we want to free
            mov name&_pool_frame, edx   ;// set as new frame head

            call pool_free              ;// free the memory
            jmp top_of_destroy          ;// free returns zero, jump to next test

        done_with_destroy:
        ;// stitch together the new block
        ;// eax is at the head

            pool_stitch_frame name, eax, edx, ecx

        pool_clear_done:

        ENDM

;//
;//     pool_Clear
;//
;//////////////////////////////////////////////////////









;//////////////////////////////////////////////////////
;//
;// GetUnused
;//
    ;// if not pool_unused_head
    ;//     allocate a new block
    ;//     stitch the block together
    ;// endif
    ;//
    ;// RemoveHead

pool_GetUnused MACRO name:req, reg:req, clear

    ;// may destroy eax

    LOCAL have_to_allocate, all_done

        mov reg, name&_pool_unused  ;// get head of unused list
        test reg, reg               ;// see if there was one
        jz have_to_allocate         ;// if not, then allocate
        ASSUME reg:PTR name&_POOL_UNUSED

        push [reg].next_unused  ;// get the next unused node
        pop name&_pool_unused   ;// store as the new head of the unused node list
        jmp all_done            ;// done

    have_to_allocate:

    %   IFNB <name&_pool_allocator> ;// common allocator ?

            call name&_pool_allocator   ;// call it
            IFDIFI <reg>,<eax>
            mov reg, eax
            ENDIF

        ELSE    ;// use inline allocator

            pool_allocator name, reg

        ENDIF

        ASSUME reg:PTR name&_POOL_UNUSED
        push [reg].next_unused
        pop name&_pool_unused

    all_done:

        IFIDN <clear>,<CLEAR>

            push edi
            push eax
            push ecx

            mov edi, reg
            mov ecx, (SIZEOF name&_pool_assume)/4
            xor eax, eax
            rep stosd

            pop ecx
            pop eax
            pop edi

        ELSEIFNB <clear>

            .ERR <use CLEAR or leave blank>

        ENDIF

        ASSUME reg:PTR name&_pool_assume

    ENDM
;//
;// GetUnused
;//
;//////////////////////////////////////////////////////




;//////////////////////////////////////////////////////
;//
;// PutUnused
;//
pool_PutUnused MACRO name:req, reg:req

    ;// put reg as new head of unused node list
    ;// changes no registers or flags

    PUSHCONTEXT ASSUMES

    ASSUME reg:PTR name&_POOL_UNUSED
    push name&_pool_unused      ;// store the old head
    mov name&_pool_unused, reg  ;// set the new head
    pop [reg].next_unused       ;// stitch in old chain

    POPCONTEXT ASSUMES

    ENDM

;//
;// PutUnused
;//
;//////////////////////////////////////////////////////



;//////////////////////////////////////////////////////
;//
;// GetDebugStats
;//
    ;// returns
    ;// ecx num used
    ;// edx num unused

    pool_GetDebugStats MACRO name:req

        mov eax, name&_pool_frame   ;// load and test the head
        ASSUME eax:PTR name&_POOL_FRAME
        xor edx, edx
        xor ecx, ecx

    .IF eax

    ;// count the total number of records

        .REPEAT

            add ecx, ((SIZEOF name&_POOL_FRAME) - 4) / SIZEOF name&_POOL_UNUSED
            mov eax, [eax].next_frame

        .UNTIL eax == edx

    ;// count the number of unused, reduce total number

        mov eax, name&_pool_unused
        ASSUME eax:PTR name&_POOL_UNUSED

        .WHILE eax

            inc edx
            dec ecx
            DEBUG_IF <SIGN?>    ;// what happened here ??
            mov eax, [eax].next_unused

        .ENDW

    .ENDIF
    ;// that's it

    ENDM


ENDIF ;// _POOL3_INCLUDED_