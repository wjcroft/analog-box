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
;//     ABOX242 AJT
;//         manually set 1 operand size for masm 9
;//
;//##////////////////////////////////////////////////////////////////////////

; AJT: This equation system had its heart in the right place
;      but is certainly NOT a sane way to implement it.
;      In hindsight, 'compile at every keystroke' is (imho) a bad idea.
;      The more traditional aproach of lexer + context free grammar
;      would offer much to the user in that they can use a text editor
;      far more effectively than the button pressing seen here.


;//
;// Equation.asm
;//
;//
;// TOC:
;//
;// equ_Compile
;// equ_private_compile
;// equ_EditCtor
;// equ_EditDtor
;// equ_BuildSubBuf
;// equ_BuildTokBuf
;// equ_build_this_number
;// equ_BuildExeBuf
;// equ_debug_compile_dump_in
;// equ_debug_compile_dump_out
;// equ_debug_dump_tok_buf
;// equ_debug_dump_sub_buf


OPTION CASEMAP:NONE

.586
.MODEL FLAT

USE_THIS_FILE equ 1

IFDEF USE_THIS_FILE

    .NOLIST
    include <Abox.inc>
    include <equation.inc>
    .LIST

.DATA

;// for debugging ;///////////////////////


IFDEF DEBUGBUILD

    ;// rem this to turn off debug dumping

;// DEBUG_USE_DUMPING equ 1
;// DUMP_SUB_BUF_TOO equ 1
;// DEBUG_COMPILE_SLEEP equ 1

ENDIF

IFDEF DEBUG_USE_DUMPING
    equ_debug_compile_dump_in PROTO STDCALL pFPU:DWORD, pPOS:DWORD
    equ_debug_compile_dump_out PROTO STDCALL pFPU:DWORD, pEHeader:DWORD
    equ_debug_dump_tok_buf PROTO STDCALL
    equ_debug_dump_sub_buf PROTO STDCALL
ENDIF

;// for debugging ;///////////////////////



;// private to this file

    equ_private_compile PROTO

    equ_BuildSubBuf PROTO
    equ_BuildTokBuf PROTO
    equ_BuildExeBuf PROTO


    equ_pEdit   dd  0   ;// ptr to the current edit header
    equ_bCompiling dd 0 ;// tells Dtor to wait


;// we need some powers of ten for building numbers

equ_pow_ten REAL4 1.0e+0, 1.0e-1, 1.0e-2, 1.0e-3
            REAL4 1.0e-4, 1.0e-5, 1.0e-6, 1.0e-7
            REAL4 1.0e-8, 1.0e-9, 1.0e-10,1.0e-11
            REAL4 1.0e-12,1.0e-13,1.0e-14,1.0e-15
            REAL4 1.0e-16,1.0e-17,1.0e-18

;// these are for range checking

        equ_TanhK       REAL4 2.885390082e+0    ;// 2/ln(2)
        equ_Half        REAL4 0.5e+0

;// and this is the list of range checks

    equ_small_8  REAL4 3.90625e-3
                 REAL4 256.0E+0
                 REAL4 -8.0E+0

    equ_small_16 REAL4 1.525878906E-5
                 REAL4 65536.0E+0
                 REAL4 -16.0E+0

    equ_small_32 REAL4 2.328306437E-10
                 REAL4 4.294967296E+9
                 REAL4 -32.0E+0

    equ_small_64 REAL4 5.421010854E-20
                 REAL4 1.844674407E+19
                 REAL4 -64.0E+0


;// these are sub categorized to simplfy some searches

equ_element \         ;// for tok len dis fpu exe cmd
            EQU_ELEMENT { '0','k', 1 ,'0', 6 ,   , ID_EQU_0 }
            EQU_ELEMENT { '1','k', 1 ,'1', 6 ,   , ID_EQU_1 }
            EQU_ELEMENT { '2','k', 1 ,'2', 6 ,   , ID_EQU_2 }
            EQU_ELEMENT { '3','k', 1 ,'3', 6 ,   , ID_EQU_3 }
            EQU_ELEMENT { '4','k', 1 ,'4', 6 ,   , ID_EQU_4 }
            EQU_ELEMENT { '5','k', 1 ,'5', 6 ,   , ID_EQU_5 }
            EQU_ELEMENT { '6','k', 1 ,'6', 6 ,   , ID_EQU_6 }
            EQU_ELEMENT { '7','k', 1 ,'7', 6 ,   , ID_EQU_7 }
            EQU_ELEMENT { '8','k', 1 ,'8', 6 ,   , ID_EQU_8 }
            EQU_ELEMENT { '9','k', 1 ,'9', 6 ,   , ID_EQU_9 }

equ_element_dec \     ;// for tok len dis fpu exe cmd
            EQU_ELEMENT { '.','k', 1 ,'.', 6,   , ID_EQU_DECIMAL }

equ_element_con \     ;// for tok len dis     fpu exe cmd
            EQU_ELEMENT { 'c','K', 2 ,'pi'   , 6,   , ID_EQU_PI }
            EQU_ELEMENT { 'd','K', 5 ,'ln(2)', 6,   , ID_EQU_LN2 }
            EQU_ELEMENT { 'e','K', 5 ,'L2(e)', 6,   , ID_EQU_L2E }
equ_element_var \     ;// for tok len dis fpu exe cmd
            EQU_ELEMENT { 'a','x', 1 ,'a', 6,   , ID_EQU_A }
            EQU_ELEMENT { 'b','x', 1 ,'b', 6,   , ID_EQU_B }
            EQU_ELEMENT { 'x','x', 1 ,'X', 6,   , ID_EQU_X }
            EQU_ELEMENT { 'y','x', 1 ,'Y', 6,   , ID_EQU_Y }
            EQU_ELEMENT { 'z','x', 1 ,'Z', 6,   , ID_EQU_Z }
            EQU_ELEMENT { 'u','x', 1 ,'U', 6,   , ID_EQU_U }
            EQU_ELEMENT { 'v','x', 1 ,'V', 6,   , ID_EQU_V }
            EQU_ELEMENT { 'w','x', 1 ,'W', 6,   , ID_EQU_W }
equ_element_bop \     ;// for tok len dis fpu exe cmd
            EQU_ELEMENT { '+','b', 3 ,' + ', 6, 5 , ID_EQU_PLUS }
            EQU_ELEMENT { '-','b', 3 ,' - ', 6, 5 , ID_EQU_MINUS }
            EQU_ELEMENT { '*','b', 1 , '*', 6, 5 , ID_EQU_MULTIPLY }
            EQU_ELEMENT { '/','b', 1 , '/', 6, SIZE_equ_div_a1 , ID_EQU_DIVIDE }
            EQU_ELEMENT { '%','b', 1 , '%', 6,   , ID_EQU_MOD }
            EQU_ELEMENT { '@','b', 1 , '@', 6,   , ID_EQU_ANGLE }
            EQU_ELEMENT { '#','b', 1 , '#', 6, SIZE_equ_clip  , ID_EQU_CLIP }
equ_element_close \
            EQU_ELEMENT { ')','u', 2 ,' )' }
equ_element_uop \     ;// for tok len dis     fpu exe cmd
            EQU_ELEMENT { '(','u', 2 ,'( '    , 7, 0 , ID_EQU_PAREN }
            EQU_ELEMENT { 'M','u', 5 ,'mag( ' , 7, 5 , ID_EQU_MAG }
            EQU_ELEMENT { 'N','u', 5 ,'neg( ' , 7, 5 , ID_EQU_NEG }
            EQU_ELEMENT { 'S','u', 5 ,'sin( ' , 7, 5 , ID_EQU_SIN }
            EQU_ELEMENT { 'C','u', 5 ,'cos( ' , 7, 5 , ID_EQU_COS }
            EQU_ELEMENT { 'H','u', 6 ,'tanh( ', 5, SIZE_equ_tanh  , ID_EQU_TANH }
            EQU_ELEMENT { 'Q','u', 6 ,'sqrt( ', 5, SIZE_equ_sqrt  , ID_EQU_SQRT }
            EQU_ELEMENT { 'P','u', 4 ,'2^( '  , 5, SIZE_equ_pow2  , ID_EQU_POWER }
            EQU_ELEMENT { 'L','u', 6 ,'log2( ', 5, SIZE_equ_log2_uncombined  , ID_EQU_LOG2 }
        ;// EQU_ELEMENT { 'G','u', 6 ,'sign( ', 7, SIZE_equ_sign , ID_EQU_SIGN }
            EQU_ELEMENT { 'G','u', 6 ,'sign( ', 7, SIZE_equ_sign_abox225 , ID_EQU_SIGN }
            EQU_ELEMENT { 'I','u', 5 ,'int( ' , 7, 5 , ID_EQU_INT }
equ_element_end \
            EQU_ELEMENT {}  ;// nul term ends the list


;// these are the preset equations

comment ~ /* replaced by table in ABOX232

    equ_preset_m2f db '0.0003707845*PMx*10.6666))',0,0  ;// make sure these
    equ_preset_f2m db '0.09375*LMx*2696.984139))',0,0,0 ;// are 7 dwords in size

    equ_szM2F db 'M to F', 0
    equ_szF2M db 'F to M', 0

*/ comment ~


    ;// M to F
    ;// F to M
    ;// D to F
    ;// F to D
    ;// D to M
    ;// M to D

    equ_preset_table LABEL EQUATION_PRESET

    equ_m2f EQUATION_PRESET { '0.0003707845*PMx*10.6666))', 'M to F' }
    equ_f2m EQUATION_PRESET { '0.09375*LMx*2696.984139))',  'F to M' }

    equ_d2f EQUATION_PRESET { '1/(a*512)'               ,  'D to F' }
    equ_f2d EQUATION_PRESET { '1/(b*512)'               ,  'F to D' }

    equ_d2m EQUATION_PRESET { '0.224731-LMx))*0.09375', 'D to M' }
    equ_m2d EQUATION_PRESET { '5.267547*PN10.6666*Mx)))', 'M to D' }

    equ_default EQUATION_PRESET { '0' } ;// terminator


.CODE

;////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////
;//////
;//////
;//////  C O M P I L E   I N T E R F A C E
;//////
;//////
;////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
equ_Compile PROC STDCALL uses esi pFor:DWORD, pVar:DWORD, bInit:DWORD

    ;// this function is only to be called from an object
    ;// if bInit is true, then we setup the eVar table

    mov esi, pFor

    ASSUME esi:PTR EQU_FORMULA_HEADER

    .IF [esi].bDirty

        .IF equ_pEdit
            invoke equ_EditDtor ;// not supposed to exist
        .ENDIF

        ;// equ_EditCtor compiles for us

        invoke equ_EditCtor, pFor, pVar, bInit
        invoke equ_EditDtor

    .ENDIF

    ret

equ_Compile ENDP


;////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
equ_private_compile PROC

push esi
push edi
push ebx

    ;// this is called either from equ_Compile
    ;// or from equ_InitEdit

    ;// we assume that equ_pEdit is built

    ;// this is where we play sync
    ;// we do this regardless of wheather we're playing or not
    ;// this prevents crashes due to traces

ENTER_PLAY_SYNC GUI

        mov equ_bCompiling, 1   ;// set this flag

    ;// then we update the equation

        invoke equ_BuildSubBuf  ;// build the display and sub buffer
        invoke equ_BuildTokBuf  ;// tokenize and init the pre buffer
        invoke equ_BuildExeBuf  ;// compile and finish the pre buffer

    ;// call the supplied InitPin function

        mov esi, equ_pEdit
        ASSUME esi:PTR EQU_EDIT_HEADER

    ;// we're not dirty any more

        mov esi, [esi].pFor_head
        ASSUME esi:PTR EQU_FORMULA_HEADER
        mov [esi].bDirty, 0

    ;// good place to see what's going on

    IFDEF DEBUG_USE_DUMPING
    IFDEF DUMP_SUB_BUF_TOO
        invoke equ_debug_dump_sub_buf
    ENDIF
    ENDIF

    ;// done with playsync

    mov equ_bCompiling, 0   ;// reset this flag

LEAVE_PLAY_SYNC GUI

    ;// and that's about it

pop ebx
pop edi
pop esi

    ret

equ_private_compile ENDP


;////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////
;//////
;//////
;//////  E D I T O R   I N T E R F A C E
;//////
;//////
;////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////
ASSUME_AND_ALIGN
;// equ_EditCtor PROC STDCALL uses esi edi ebx pObject:DWORD, pFor:DWORD, pVar:DWORD, dwFlags:DWORD
equ_EditCtor PROC STDCALL uses esi edi ebx pFor:DWORD, pVar:DWORD, dwFlags:DWORD

    ;// we only allow one editor at a time

        DEBUG_IF <equ_pEdit>    ;// not supposed to be initialized

    ;// dtermine how much to allocate, then allocate

        mov esi, pFor
        ASSUME esi:PTR EQU_FORMULA_HEADER

    ;// size needed is edit_header + for_max * 6 <== for the three word arrays

        mov eax, [esi].f_len_max
        mov edx, SIZEOF EQU_EDIT_HEADER
        lea eax, [eax+eax*2]    ;// * 3
        lea edx, [edx+eax*2]+3  ;// * 6
        and edx, -4

        invoke memory_Alloc, GPTR, edx

        mov edi, eax
        ASSUME edi:PTR EQU_EDIT_HEADER

    ;// fill in the entire thing

        mov eax, dwFlags
        mov [edi].bFlags, al

        mov eax, [esi].f_len_max
        sub eax, EQU_EDIT_DLG_SUB
        mov [edi].f_len_max_dlg, eax

        mov eax, [esi].d_len_max
        sub eax, EQU_EDIT_DLG_SUB
        mov [edi].d_len_max_dlg, eax

    ;// mov eax, pObject
    ;// mov edx, pPinInit
    ;// mov [edi].pObject, eax
    ;// mov [edi].pPinInit, edx

        mov [edi].pFor_head, esi    ;// pointer to the formula header
        lea eax, [esi+SIZEOF EQU_FORMULA_HEADER]
        mov [edi].pFor_buf, eax     ;// pointer to formula buffer
        add eax, [esi].f_len_max
        mov [edi].pDis_buf, eax     ;// pointer to display buffer
        add eax, [esi].d_len_max
        mov [edi].pExe_buf, eax     ;// pointer to exe buf

        mov ebx, pVar
        ASSUME ebx:PTR EQU_VARIABLE_HEADER

        mov [edi].pVar_head, ebx    ;// pointer to the variable header
        add ebx, SIZEOF EQU_VARIABLE_HEADER
        mov [edi].pVar_buf, ebx     ;// pointer to the variable table

        mov eax, [esi].f_len_max    ;// load the common size
        shl eax, 1                  ;// shift to a word offset

        lea ebx, [edi+SIZEOF EQU_EDIT_HEADER]
        mov [edi].pSub_buf, ebx     ;// pointer to sub buffer
        add ebx, eax
        mov [edi].pTok_buf, ebx     ;// pointer to the token buffer
        add ebx, eax
        mov [edi].pPre_buf, ebx     ;// pointer to pre buffer

    ;// store the pointer

        mov equ_pEdit, edi

    ;// now we have to recompile to get all the buffers correct

        invoke equ_private_compile

    ;// that's it

        ret

equ_EditCtor ENDP




equ_EditDtor PROC

    .IF equ_pEdit   ;// this may be called more than once

        ;//.WHILE equ_bCompiling
        ;// invoke Sleep, SLEEP_TIME_WAIT
        ;//.ENDW

        DEBUG_IF <equ_bCompiling>   ;// this should not happen anymore

        invoke memory_Free, equ_pEdit
        mov equ_pEdit, eax  ;// zero the pointer

    .ENDIF
    ret

equ_EditDtor ENDP


;////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////
;//////
;//////
;//////  B U F F E R   B U I L D I N G   R O U T I N E S
;//////
;//////
;////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN

equ_BuildSubBuf PROC

EQU_ENTER

;// this builds the display buf
;// resets and defines the edit portion of the sub_buf
;// sets up the positions for editing
;// determines the sizes of the formula and display buf
;// sets the formula pString pointer

    mov esi, [ebp].pFor_buf ;// esi iterates for_buf
    ASSUME esi:PTR BYTE

    mov edi, [ebp].pDis_buf ;// edi iterate dis_buf
    ASSUME edi:PTR BYTE

    mov ebx, [ebp].pSub_buf ;// ebx iterate sub buf
    ASSUME ebx:PTR EQU_SUBBUF

    xor ecx, ecx    ;// cl counts the accumulated length of dis_buf
                    ;// ch counts characters scanned in for_buf

    mov [ebp].selPos, cl    ;// reset
    mov [ebp].selLen, cl

    jmp enter_loop

top_of_loop:

    ;// al has the character from the for_buf that we want to match with a token class

    ;// locate the element corresponding to this character

        lea edx, equ_element        ;// load start of element table
        ASSUME edx:PTR EQU_ELEMENT
        or WORD PTR [ebx], 000FFh   ;// reset the subbuf.element index

    search_loop:

        inc [ebx].i_ele     ;// advance the element index first (-1 is 'invalid')

        xor ah, ah          ;// clear ah
        or ah, [edx].cFor   ;// check for end of table
        jz not_found        ;// error if not found

        cmp ah, al          ;// check if formula character matches element character
        jz found_it         ;// and jump if we found a match

        add edx, SIZEOF EQU_ELEMENT ;// advance the element iterator
        jmp search_loop     ;// loop until done

    found_it:       ;// ah has the character from the formula

        mov al, [edx].cLen          ;// load the character length

        .IF cl==[ebp].curPos        ;// check if this is the current position
            mov [ebp].selPos, ch    ;// store the display position
            mov [ebp].selLen, al    ;// and set the length from the element table

            .IF [ebp].bFlags & EQE_USE_INDEX    ;// check if this is an indexed variable
                .IF [edx].cTok == 'x'
                    .IF BYTE PTR [esi] >= '0' && BYTE PTR [esi] <= '9'
                        inc [ebp].selLen
                    ;//.ELSE
                    ;// BOMB_TRAP   ;// supposed to be an index
                    .ENDIF
                .ENDIF
            .ENDIF
        .ENDIF

        add ch, al      ;// increase the displayed character length
        inc cl          ;// increase the for_buf length

        lea edx, [edx].cDis     ;// get the element display pointer
        mov ah, al              ;// store the length

    @@: mov al, BYTE PTR [edx]  ;// load the display character
        stosb                   ;// store it and advance the dis_buf pointer
        inc edx                 ;// iterate ele_display pointer
        dec ah                  ;// decrease the count
        jnz @B                  ;// rinse, repeat

    ;// iterate the sub buf pointer

        add ebx, 2


enter_loop:

    lodsb       ;// get the next character
    or al, al   ;// check if end
    jnz top_of_loop

build_subbuf_done:

    mov eax, 20h    ;// ' ' always end dis_buf with a space
    stosd           ;// so we have something to select

    mov WORD PTR [ebx], 0FFFFh  ;// don't forget the sub_buf either

    .IF ![ebp].selLen

        ;// we're at the end of the string
        mov [ebp].selLen, 1
        mov [ebp].selPos, ch

    .ENDIF

;// we also know how long both buffers are f_len is

    xor eax, eax

    mov al, cl
    mov [ebp].f_len, eax
    mov al, ch
    mov [ebp].d_len, eax

;// now we check if we're one of the prebuilt strings

    mov edx, OFFSET equ_preset_table
    ASSUME edx:PTR EQUATION_PRESET

    .REPEAT

        mov esi, [ebp].pFor_buf     ;// what to compare with
        .ERRNZ EQUATION_PRESET.formula
        mov edi, edx
        mov ecx, EQU_PRESET_FORMULA_LENGTH
        repe cmpsd
        .IF ZERO?
            lea esi, [edx].string   ;// point at the display string
            jmp done_with_preset_seach  ;// and exit to the storer
        .ENDIF
        add edx, SIZEOF EQUATION_PRESET ;// try the next preset

    .UNTIL edx == OFFSET equ_default    ;// stop at end of table

    ;// not found, use the existing equation as the display

        mov esi, [ebp].pDis_buf

done_with_preset_seach:

    mov ebx, [ebp].pFor_head        ;// get the for_headerpointer
    ASSUME ebx:PTR EQU_FORMULA_HEADER

    mov [ebx].pString, esi          ;// store the pointer for the display sttring

;// that should do it

    EQU_EXIT



;// a character from the for_buf was not found in the element table
not_found:

    BOMB_TRAP   ;// ideally, we want to reset the formaula to a default
                ;// then do this again

equ_BuildSubBuf ENDP

;////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN

equ_BuildTokBuf PROC

EQU_ENTER

    ;// this tokenizes a formula
    ;// sub buf must be built
    ;// it assigns variables to the var_table
    ;// and fills in the compile side of sub_buf

;// prepare to scan

    mov esi, [ebp].pSub_buf
    ASSUME esi:PTR EQU_SUBBUF   ;// esi walks sub_buf

    mov edi, [ebp].pTok_buf
    ASSUME edi:PTR EQU_TOKEN    ;// edi walks tok_buf

    xor ecx, ecx    ;// clear this just in case


;// determine a unique check for determining if we've corrupted eVar



;// reset evar to a default state
;// but only if user specified

.IF [ebp].bFlags & EQE_INIT_VARIABLES

    ;// clear all the in use flags in the evar table

        mov ebx, [ebp].pVar_head
        ASSUME ebx:PTR EQU_VARIABLE_HEADER

        movzx ecx, [ebx].tot_num    ;// load total size of evar table
        movzx eax, [ebx].num_var

        lea ebx, [ebx+SIZEOF EQU_VARIABLE_HEADER]
        ASSUME ebx:PTR EQU_VARIABLE

        sub eax, ecx

    @@: and [ebx].dwFlags, NOT EVAR_IN_USE
        add ebx, SIZEOF EQU_VARIABLE
        loop @B

        ;// reset k_remain
        neg eax
        mov [ebp].k_remain, eax

        ;// reset the init flag
    ;// and [ebp].bFlags, NOT EQE_INIT_VARIABLES

.ENDIF

;// since sub_buf is already built, and contains the indexs
;// to the element, we scan sub buf

;// ecx indexes tokens, for storing in the sub buf

top_of_loop:

    movzx eax, [esi].i_ele      ;// load the element index
    mov [esi].i_tok, cl         ;// store the index in the sub buf
    shl eax, EQU_ELEMENT_SHIFT
    lea edx, equ_element[eax]   ;// now edx is a pointer into the element table
    ASSUME edx:PTR EQU_ELEMENT

    .IF     edx < OFFSET equ_element

        BOMB_TRAP   ;// address was before the element table

    .ELSEIF edx < OFFSET equ_element_con    ;// got a number

        call build_and_locate_number

    .ELSEIF edx < OFFSET equ_element_var    ;// got a constant

        mov ax, WORD PTR [edx].cFor ;// load the token/oper pair
        stosw                       ;// stor the token in the tok buf

    .ELSEIF edx < OFFSET equ_element_bop    ;// got a variable

        .IF [ebp].bFlags & EQE_USE_INDEX
                                    ;// peek at next char and check if it's a number
            .IF [esi+2].i_ele >= 10 ;// check that element index is less than 10
                                    ;// this works because the numbers are first in the element list
                BOMB_TRAP   ;// supposed to an index next
            .ENDIF

            movzx eax, [esi+2].i_ele    ;// get the next index
            shl eax, EQU_ELEMENT_SHIFT
            lea eax, equ_element[eax]   ;// now eax is a pointer into the element table

            mov ah, (EQU_ELEMENT PTR [eax]).cFor

            ;// we also have to store the index here
            add esi, 2
            mov [esi].i_tok, cl

        .ELSE   ;// not using indexes
            mov ah, 0
        .ENDIF

        mov al, BYTE PTR [edx].cFor ;// add on the origonal variable name ;// ABOX242 AJT

        call locate_variable                ;// locate the variable in the evar buffer

    .ELSEIF edx < OFFSET equ_element_close  ;// got a bop

        mov ax, WORD PTR [edx].cFor ;// load the token/oper pair
        stosw                       ;// stor the token in the tok buf

    .ELSEIF edx < OFFSET equ_element_end    ;// got a uop

        mov ax, WORD PTR [edx].cFor ;// load the token/oper pair
        stosw                       ;// stor the token in the tok buf

    .ELSE   ;// index was passed the table end
            ;// which means we're done

        jmp done_tokenizing

    .ENDIF


    ;// iterate this

        add esi, 2      ;// iterate the sub_buf
        inc ecx         ;// iterate the token count

    jmp top_of_loop



done_tokenizing:

    ;// store the new t_len

        mov [ebp].t_len, ecx

    ;// terminate the tok_buf

        xor eax, eax
        stosd

    ;// determine the remaining constants

        mov esi, [ebp].pVar_head
        ASSUME esi:PTR EQU_VARIABLE_HEADER

        movzx eax, [esi].num_var
        movzx ecx, [esi].tot_num
        sub ecx, eax

        shl eax, EQU_VARIABLE_SHIFT
        lea esi, [esi+SIZEOF EQU_VARIABLE_HEADER+eax]
        ASSUME esi:PTR EQU_VARIABLE

        ;// ecx counts numbers
        ;// esi points at first number

        xor eax, eax
        .REPEAT
            .IF !([esi].textname.letter) && \
                ![esi].token &&             \
                !([esi].dwFlags & EVAR_IN_USE)
                inc eax
            .ENDIF
            add esi, SIZEOF EQU_VARIABLE
        .UNTILCXZ
        mov [ebp].k_remain, eax


    ;// build a new checksum for eVar
    ;// and compare with the old

    ;// if different, turn on eVar_changed



IFDEF DEBUG_USE_DUMPING
    invoke equ_debug_dump_tok_buf
ENDIF


EQU_EXIT

;/////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////

;// local functions

build_and_locate_number:

    ;// this builds a number
    ;// then looks for a prexisting konstant
    ;// if none found, then we assign a new constant

    ;// edx points at the element for this character
    ;// esi points at sub buf for this character
    ;// edi points at the tok_buf for this character
    ;// we iterate edi in this process,
    ;//     being sure to store all the tok_indexes

    ;// since this is re-rewritten code
    ;// we kludge on the fact that we need a pointer to the for buf

    push ecx    ;// save our token index
    push edi    ;// save the tok_buf pointer
    push esi    ;// save the sub_buf pointer

    sub esi, [ebp].pSub_buf ;// subtract to a word offset
    shr esi, 1              ;// turn into a byte offset
    add esi, [ebp].pFor_buf ;// now we're a pointer into the for_buf

    lea edi, [ebp].temp_bcd ;// edi will point at temp bcd


    ;// first step is to build the number

        invoke equ_build_this_number
        push ecx    ;// save the string length

        ;// eax returns with the number


    ;// then we locate the number in the variable table
    ;// when we find it, we assign it

        mov ebx, [ebp].pVar_head    ;// load the var_table header
        ASSUME ebx:PTR EQU_VARIABLE_HEADER

        movzx edx, [ebx].num_var    ;// get the number of variables
        movzx ecx, [ebx].tot_num    ;// get the total size of the table
        sub ecx, edx                ;// ecx is number of variable
        shl edx, EQU_VARIABLE_SHIFT ;// edx if offset into eVar
        lea ebx, [ebx + SIZEOF EQU_VARIABLE_HEADER + edx]
        ASSUME ebx:PTR EQU_VARIABLE ;// ebx points at first number record
        shr edx, EQU_VARIABLE_SHIFT ;// edx will index slots

    ;// we want to scan records until:
    ;//     we run into the first not_in_use flag
    ;//     we find a value match with eax
    ;//     we run out of slots
    @@: .IF [ebx].dwFlags & EVAR_IN_USE

            .IF [ebx].value == eax  ;// found a match

                mov dh, 'k'         ;// now dx is the token
                jmp fill_and_restore;// jump to the exit routine

            .ENDIF

        .ELSE

            ;// this record is not in use
            mov [ebp].k_remain, ecx         ;// store the new number of remaining konstants
            or [ebx].dwFlags, EVAR_IN_USE   ;// set in use flag
            mov [ebx].value, eax            ;// store the value

            mov dh, 'k'             ;// now dx is the token
            jmp fill_and_restore    ;// jump to the exit routine

        .ENDIF

        add ebx, SIZEOF EQU_VARIABLE
        inc edx     ;// advance the slot count
        loop @B     ;// loop until end of table

    ;// if we get here then we're out of slots for numbers
    ;// and there's still a mess of things on the stack

        BOMB_TRAP

fill_and_restore:

    ;// dx must have the token

    ;// still on the stack, and what to return them as
    ;//
    ;//     length of string    local
    ;//     pointer to sub_buf      esi
    ;//     pointer to tok_buf      edi
    ;//     index of current token  ecx

    pop ebx ;// retrieve the string length
    pop esi ;// retrieve the sub_buf pointer
    pop edi ;// retieve the token buf pointer
    pop ecx ;// retrieve the current index

;// store the correct token in tok_buf

    mov WORD PTR [edi], dx  ;// check if order is correct
    add edi, 2              ;// don't forget to iterate it as well

;// fill all the numbers in sub buf, with this token index
;// since the first one is already stored, we test first, then advance

    ASSUME esi:PTR EQU_SUBBUF
@@: dec ebx             ;// decrease the count
    jz @F               ;// exit if done
    add esi, 2          ;// advance sub pointer
    mov [esi].i_tok, cl ;// store index
    jmp @B

;// that should be it

@@: retn


;/////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////

locate_variable:

    ;// given the variable name in ax
    ;// we try to locate a prexisting variable
    ;// if none is found, then we crash
    ;// we then store the correct token in tok buf

    push ecx    ;// save the token indexer

        mov ebx, [ebp].pVar_head
        ASSUME ebx:PTR EQU_VARIABLE_HEADER
        movzx ecx, [ebx].num_var
        lea ebx, [ebx+SIZEOF EQU_VARIABLE_HEADER]
        ASSUME ebx:PTR EQU_VARIABLE
        xor edx, edx                    ;// edx counts slots

    ;// we want to scan until ecx goes to zero

    @@: .IF WORD PTR [ebx].textname == ax

            .IF !([ebx].dwFlags & EVAR_AVAILABLE)

                ;// not supposed to use unavailable variables
                BOMB_TRAP   ;// did you forget to define them in order ??

            .ELSE

                ;// this is it
                or [ebx].dwFlags, EVAR_IN_USE;// mark as in use
                mov dh, 'x'                 ;// build the token
                mov WORD PTR [edi], dx      ;// store in token buffer
                pop ecx                     ;// restore the token indexer
                add edi, 2                  ;// iterate the token pointer

            .ENDIF

            retn    ;// get on out o here

        .ENDIF

        add ebx, SIZEOF EQU_VARIABLE
        inc edx
        loop @B

    ;// if we get here, then there were no matching variables
    ;// meaning something went wrong

    ;// ecx is still on the stack

        BOMB_TRAP


equ_BuildTokBuf ENDP


;///////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////


equ_build_this_number   PROC

    ;// this builds a number and stores it in the
    ;// address pointed at by edi,
    ;// edi must point to a ten byte storeage space
    ;// esi must point at the start of the number

    ;// destroys ecx, edx, eax

    ;// this called mainly from the token izer
    ;// but also needs to be called from diff_PinInit

    ;// this returns the floating point number in eax as well as [edi]
    ;// it also returns the length of the string in ecx


    xor ecx, ecx ;// ecx will be the end of the string

    xor edx, edx ;// dl is the number of characters after the decimal
                 ;// dh is a flag for the first non zero character
    ASSUME esi:PTR BYTE

    push edi    ;// store for later

    ;// we'll treat number like a bcd
    ;// so we also keep track of where the decimal is

    ;// locate the end of the number
    ;// scan esi forwards

scan_1_top:

    mov al, [esi+ecx]   ;// load the character
    cmp al, '.'         ;// check for a decimal
    jne @F              ;// jmp if not

    inc dh          ;// by increasing we turn on decimal digit counting
    inc ecx         ;// count this char
    jmp scan_1_top  ;// do again

@@: cmp al, '9'         ;// check the range
    ja done_with_scan_1 ;// not in a number anymore
    cmp al, '0'
    jb done_with_scan_1 ;// not inside a number anymore

    or dh, dh           ;// check if we're counting decimal digits yet
    jz no_decimal_yet
    inc dl              ;// increase the digit count

no_decimal_yet:

    inc ecx             ;// increase the character count
    jmp scan_1_top      ;// continue on


done_with_scan_1:

    ;// now ecx has the number of bytes in the number
    ;// and dl tells us how to shift the decimal

    xor eax, eax ;// eax is the value we're building

    mov dh, 0   ;// dh is now a high/low flag

get_next_char:  ;// we're scanning esi backwards

    fldz                ;// clear temp_bcd
    fbstp TBYTE PTR [edi]
    push ecx            ;// store this for later

    .WHILE ecx
        dec ecx             ;// adjust num digits
        mov al, BYTE PTR [esi+ecx]
        .IF al=='.'         ;// got a decimal, ignore
        .ELSEIF al <= '9' && al >= '0'
            sub al, '0'     ;// ascii to packed
            .IF dh
                shl al, 4
                add al, ah
                stosb       ;// store in results
                dec dh      ;// reset the flag
            .ELSE
                mov ah, al
                inc dh      ;// set the flag
            .ENDIF
        .ELSE
            BOMB_TRAP   ;// not supposed to happen
        .ENDIF      ;// got a non numeric value
    .ENDW

    pop ecx ;// retrieve the string length

    ;// end of text string

        .IF dh  ;// still have one char left ?
            mov al, ah
            stosb       ;// store in results
        .ENDIF

    ;// temp_bcd is a now packed bcd
    ;// dl has the scaling factor

    pop edi ;// retrieve the start of the bcd buffer

        FBLD TBYTE PTR [edi]    ;// load as a bcd
        and edx, 000000FFh      ;// mask off anything else
        fmul equ_pow_ten[edx*4] ;// 1, .1, .01, .001, .0001 etc
        fstp DWORD PTR [edi]    ;// store as float

    ;// that's about it

        mov eax, DWORD PTR [edi]    ;// load the results as teh return value

        ret

equ_build_this_number ENDP































;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;////
;////       P R O T O T Y P E   C O D E
;////
;////
;////       some of the exe code is fairly long
;////       so we'll provide these templates to copy as required
;////       there's a format to this
;////       the name of the code block must be consistant so we can generate
;////       the sizes and xfer the code with macros


    ;//////////////////////////////////////////
    ;//////////////////////////////////////////
    ;///
    ;///    this defines the sizes for the code block
    ;///
    SET_SIZE MACRO nam:req

        SIZE_&nam   equ OFFSET nam&_done - OFFSET nam

        ENDM

    ;//////////////////////////////////////////
    ;//////////////////////////////////////////
    ;///
    ;/// this xfers the named code block to edi
    ;///
    CODE_XFER MACRO nam:req

        push esi
        push ecx
        lea esi, nam
        mov ecx, SIZE_&nam
        rep movsb
        pop ecx
        pop esi

    ENDM

;// then these are the function blocks
;// this code will never get exectuted directly
.code

;////////////////////////////////////////////////////////////////////////////
equ_div_d:
        fld DWORD PTR [esi+EQU_OFFSET_SMALL]    ;// load into fpu
        fld st(1)       ;// load the value we;//'re going to divide by
        fabs            ;// +x  smal    +-x     y ...
        fucompp         ;// +-x y ...
        fnstsw ax
        sahf
        jb div_out_of_range_d
        fdiv
        jmp equ_div_d_done
    div_out_of_range_d:
        ftst        ;// get the sign
        fnstsw ax
        fstp st     ;// y   ...
        sahf
        fld DWORD PTR [esi+EQU_OFFSET_RECIP]
        jnc do_div_d_mul
        fchs
    do_div_d_mul:
        fmul
equ_div_d_done:
SET_SIZE equ_div_d
;////////////////////////////////////////////////////////////////////////////

;////////////////////////////////////////////////////////////////////////
equ_div_a:
        fld DWORD PTR [esi+EQU_OFFSET_SMALL]
equ_div_a_reg_1:
        fld st(0)   ;// add dl to second byte <-- compiler set
        fabs        ;// +y small x ....
        fucompp     ;// x ...
        fnstsw ax
        sahf
        jb div_out_of_range_a
equ_div_a_reg_2:
        fdiv st, st(0)  ;// add dl to second byte <-- compiler set
        jmp equ_div_a_done
    div_out_of_range_a:
        ftst            ;// get the sign
        fnstsw ax
        sahf
        jnc do_mul_a
        fchs
    do_mul_a:
        fmul DWORD PTR [esi+EQU_OFFSET_RECIP]
equ_div_a_done:
SET_SIZE equ_div_a
DIV_A_1 equ OFFSET equ_div_a_reg_1 - OFFSET equ_div_a + 1
DIV_A_2 equ OFFSET equ_div_a_reg_2 - OFFSET equ_div_a + 1

;////////////////////////////////////////////////////////////////////////

;/////////////////////////////////////////////////////////////////////////////
equ_div_a1:     ;// edx must point at value
        fld DWORD PTR [esi+EQU_OFFSET_SMALL]
        fld DWORD PTR [edx]
        fabs
        fucompp
        fnstsw ax
        sahf
        jb div_out_of_range_a1
            fdiv DWORD PTR [edx]
            jmp equ_div_a1_done
    div_out_of_range_a1:
        xor eax, eax
        or eax, DWORD PTR [edx] ;// get the sign
        fmul DWORD PTR [esi+EQU_OFFSET_RECIP]
        jns equ_div_a1_done
            fchs
equ_div_a1_done:
SET_SIZE equ_div_a1
;/////////////////////////////////////////////////////////////////////////////


;/////////////////////////////////////////////////////////////////////
equ_tanh:
    fmul equ_TanhK  ;//  kx ...
    fld1        ;// 1   kx  ...
    fxch        ;// kx  1   ...
    fld st      ;// xk  xk  1   ...
    fabs        ;// xk  xk  1   ...
    fucomp st(2);// xk  1   ...
    fnstsw ax
    sahf
    ja ftan_long_method
ftan_short_method:  ;// xk < 1
    f2xm1           ;// ex-1    1
    fxch            ;// 1       ex-1
    fld st(1)       ;// ex-1    1       ex-1
    fadd st, st(1)  ;// ex      1       ex-1
    fadd            ;//  ex+1   ex-1
    jmp ftan_do_division
ftan_long_method:   ;// 2^frac_part * 2^int_part
    fld st          ;// xk  xk  1
    fsub equ_Half
    frndint         ;// ixk xk  1
    fsub st(1), st  ;// ixk fxk 1
    fxch            ;// fxk ixk 1
    f2xm1           ;// efx-1   ixk 1
    fadd st, st(2)  ;// efx ixk 1
    fscale          ;// ex  ixk 1
    fxch            ;// ixk ex  1
    fstp st         ;// ex  1
    fxch            ;// 1       ex
    fld st(1)       ;// ex  1   ex
    fsub st, st(1)  ;// ex-1    1   ex
    fxch st(2)      ;// ex  1   ex-1
    fadd            ;// ex+1    ex-1
ftan_do_division:
    fdiv            ;// 2^  ...
equ_tanh_done:
SET_SIZE equ_tanh
;////////////////////////////////////////////////////////////////////////////

;////////////////////////////////////////////////////////////////////////////
equ_mod:
        ftst
        fnstsw ax
        sahf
        fxch
        jz mod_out_of_range
        mod_try_again:
            fprem
            fnstsw  ax
            sahf
            jp mod_try_again
            fxch
            fstp st
            jmp equ_mod_done
    mod_out_of_range:
        fstp st
        fstp st
        fldz
equ_mod_done:
SET_SIZE equ_mod
;////////////////////////////////////////////////////////////////////////////

;////////////////////////////////////////////////////////////////////////////
equ_log2_combined:
        fld DWORD PTR [esi+EQU_OFFSET_SMALL]
        fucomp
        fnstsw ax
        sahf
        ja log2_out_of_range_1
        fyl2x
        jmp equ_log2_combined_done
    log2_out_of_range_1:
        fstp st
        fmul DWORD PTR [esi+EQU_OFFSET_LOG]
equ_log2_combined_done:
SET_SIZE equ_log2_combined
;////////////////////////////////////////////////////////////////////////////

;////////////////////////////////////////////////////////////////////////////
equ_log2_uncombined:
        fld DWORD PTR [esi+EQU_OFFSET_SMALL]
        fucomp
        fnstsw ax
        sahf
        ja log2_out_of_range_2
            fld1
            fxch
            fyl2x
            jmp equ_log2_uncombined_done
    log2_out_of_range_2:
        fstp st
        fld DWORD PTR [esi+EQU_OFFSET_LOG]
equ_log2_uncombined_done:
SET_SIZE equ_log2_uncombined
;////////////////////////////////////////////////////////////////////////////

;////////////////////////////////////////////////////////////////////////////
equ_pow2:
    fld1        ;// 1   x   ...
    fxch        ;// x   1   ...
    fld st      ;// x   x   1   ...
    fabs        ;// x   x   1   ...
    fucomp st(2);// x   1   ...
    fnstsw ax
    sahf
    ja pow2_long_method
pow2_short_method:  ;// x < 1
    f2xm1           ;// ex-1    1
    fadd
    jmp equ_pow2_done
pow2_long_method:   ;// 2^frac_part * 2^int_part
    fld st          ;// x   x   1
    fsub equ_Half
    frndint         ;// ix  x   1
    fsub st(1), st  ;// ix  fx  1
    fxch            ;// fx  ix  1
    f2xm1           ;// efx-1   ix  1
    faddp st(2), st ;// ix  efx
    fxch            ;// efx ix
    fscale          ;// ex  ix
    fxch            ;// ix  ex
    fstp st         ;// ex
equ_pow2_done:
SET_SIZE equ_pow2
;//////////////////////////////////////////////////////////////////////////

;//////////////////////////////////////////////////////////////////////////
equ_sqrt:
        ftst
        fnstsw ax
        sahf
        jbe sqrt_out_of_range
            fsqrt
            jmp equ_sqrt_done
    sqrt_out_of_range:
        fstp st
        fldz
equ_sqrt_done:
SET_SIZE equ_sqrt
;//////////////////////////////////////////////////////////////////////////



comment ~ /*
    old version does not detect neg 0
;//////////////////////////////////////////////////////////////////////////
equ_sign:
    ftst
    fnstsw ax
    fstp st
    sahf
    fld1
    jnc equ_sign_done
        fchs
equ_sign_done:
SET_SIZE equ_sign
;//////////////////////////////////////////////////////////////////////////
*/ comment ~

;// to convert old and new verions
;// locate occurances of equ_sign and replace according ly
;// there wll be three sections

;// new version detects neg zero, but is not thread safe

.DATA
ALIGN 4
equ_sign_tester dd  0
.CODE

equ_sign_abox225:
    fstp equ_sign_tester
    fld1
    test equ_sign_tester, -1
    jns equ_sign_abox225_done
        fchs
equ_sign_abox225_done:
SET_SIZE equ_sign_abox225


;//////////////////////////////////////////////////////////////////////////
equ_clip:   ;// clips st(1) by st(0)    ;// a # b ==> st(1) # st(0)
    fabs        ;// B   a   ...
    fld st(1)   ;// a   B   a
    ftst
    fnstsw ax
    fabs        ;// A   B   a   ...
    fucomp      ;// B   a   ...
    sahf
    jc a_was_negative
    fnstsw ax
    sahf
    jc equ_clip_unload
        fxch
    jmp equ_clip_unload
a_was_negative:
    fnstsw ax
    sahf
    jc equ_clip_unload
        fchs
        fxch
equ_clip_unload:
    fstp st
equ_clip_done:
SET_SIZE equ_clip
;//////////////////////////////////////////////////////////////////////////





;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;///
;///
;///        DEBUG CODE for COMPILER
;///
;// debug support for build exe buffer

IFDEF DEBUG_USE_DUMPING

.DATA
sz_bod_d            db 'emit_bop_d    ', 0
sz_bop_a_stack      db 'emit_bop_a st ', 0
sz_bop_a_memory_kon db 'emit_bop_a K  ', 0
sz_bop_a_memory_var db 'emit_bop_a V  ', 0
sz_uop_d_stack      db 'emit_uop_d    ', 0

sz_load_var_a_stack db 'load_var_a st FLD  ', 0
sz_load_var_a_mem   db 'load_var_a mm FLD  ', 0
sz_load_con_a       db 'load_kon_a    FLD  ', 0
sz_load_con_a_stack db 'load_kon_a st FLD  ', 0
sz_load_con_a_mem   db 'load_kon_a mm FLD  ', 0

sz_push_bop         db 'PUSH bop           ', 0
sz_push_uop         db 'PUSH uop           ', 0
sz_pop_uop          db 'POP                ', 0


sz_fadd                           db 'FADD ', 0   ;// dh, 0ah, 0
sz_fsub                           db 'FSUB ', 0   ;// dh, 0ah, 0
sz_fmul                           db 'FMUL ', 0   ;// dh, 0ah, 0
sz_fdiv                           db 'FDIV ', 0   ;// dh, 0ah, 0
sz_fpatan                         db 'ATAN ', 0   ;// dh, 0ah, 0
sz_mod                            db 'MOD  ', 0   ;// dh, 0ah, 0
sz_clip                           db 'CLIP ', 0   ;// dh, 0ah, 0
sz_log2_combined                  db 'LOGc ', 0   ;// dh, 0ah, 0
sz_log2_uncombined                db 'LOGu ', 0   ;// dh, 0ah, 0
sz_fchs                           db 'FCHS ', 0   ;// dh, 0ah, 0
sz_fabs                           db 'FABS ', 0   ;// dh, 0ah, 0
sz_fsin                           db 'FSIN ', 0   ;// dh, 0ah, 0
sz_fcos                           db 'FCOS ', 0   ;// dh, 0ah, 0
sz_tanh                           db 'TANH ', 0   ;// dh, 0ah, 0
sz_2_to_the_x                     db '2^X  ', 0   ;// dh, 0ah, 0
sz_sqrt                           db 'SQRT ', 0   ;// dh, 0ah, 0
sz_frndint                        db 'INT  ', 0   ;// dh, 0ah, 0
sz_sign                           db 'SIGN ', 0   ;// dh, 0ah, 0

.CODE

ENDIF

DEBUG_EQU_PROGRESS MACRO string:req

    IFDEF DEBUG_USE_DUMPING
    pushad
    invoke OutputDebugStringA, ADDR string
    popad
    ENDIF
    ENDM

;///
;///        DEBUG CODE for COMPILER
;///
;///
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////




;////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////
;//////
;//////
;//////     C O M P I L E R
;//////
;//////
;////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////

;//                         we've the regular push and pop
;// macros for POS stack    plus a peek function
;//

    PUSH_POS MACRO

    ;// ebx must INDEX the position stack
    ;// esi must point at a tok_buf

        ;//.IF ebx >= EQU_MAX_POS   ;// check for overrun
        ;// BOMB_TRAP           ;// overran the POS stack
        ;//.ENDIF

        DEBUG_IF < ebx!>= EQU_MAX_POS >

        inc ebx                     ;// advance the stack pointer
        mov [ebp].POS[ebx*4], esi   ;// store the current position

    ENDM

    POP_POS MACRO

    ;// ebx must INDEX the position stack
    ;// edx will then point at the token for that position

        DEBUG_IF < !!ebx >  ;// check for under run
                            ;// under ran the pos stack

        mov edx, [ebp].POS[ebx*4]   ;// get current pointer
        movzx edx, WORD PTR [edx]   ;// load value into dx
        dec ebx                     ;// decrease pointer

    ENDM

    PEEK_POS MACRO

        DEBUG_IF < !!ebx >  ;// check for under run
                            ;// under ran the pos stack

        mov edx, [ebp].POS[ebx*4]   ;// get current pointer
        movzx edx, WORD PTR [edx]   ;// load value into dx

    ENDM

;//
;// macros for FPU stack
;//
;//     ecx must INDEX the fpu stack

    PUSH_FPU MACRO

        mov [ebp].FPU[ecx*4], eax   ;// store the name
        inc ecx                 ;// advance the top

        DEBUG_IF < ecx !>= EQU_MAX_POS >

    ENDM

    POP_FPU MACRO

        dec ecx     ;// decrease the count
        DEBUG_IF <SIGN?>
        mov [ebp].FPU[ecx*4], 0 ;// clear the name

    ENDM


;////////////////////////////////////////////////////////////////////////////////

;//address generation

;//    we'll always need to create relative offsets
;//    we'll do immediate to save a prefetch ?????
;//    there are three levels to this

;//    1) [esi]        offset is zero and does not reqire an index
;//    2) [esi+127]    offset is less than 128, and may be specified by a byte
;//    3) [esi+234]    offset is greater then 127 and needs 4 bytes

;// to prevent big small interlock, we won't use eax as an index reg
;// too often, testing instruction only use ax and ah

;// so FMUL st, mem[esi] is emitted with:
;//
;//     movzx edx, ax               ;// save the index
;//     mov  ax, 0D80Eh             ;// mask for fmul st, mem[esi]
;//     call mask_and_emit_mod_ofs  ;// call the routine emit the instruction
;//
;// HA!!, we can use this same thing for generating addresses
;//
;// and mov eax, mem[esi] is:
;//
;//     movzx edx, ax
;//     mov ax, 8B0E                 ;// mask for mem[esi]
;//     call mask_and_emit_mod_ofs   ;// call the routine to emit the instruction
;//
;// then fmul [eax]
;//
;//     xor edx, edx                ;// clear to prevent offset generation
;//     mov ax, 0D08h               ;// mask for fmul [eax]
;//     call mask_and_emit_mod_ofs  ;// call the routine emit the instruction

;////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////
;//////
;//////
;//////     C O M P I L E R
;//////
;//////
;////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////
IFDEF DEBUG_USE_DUMPING

    .DATA

        sz_line_feed db 0dh, 0ah, 0
        sz_CompileStart db 'Compiling: ', 0

    .CODE

ENDIF

ASSUME_AND_ALIGN

equ_BuildExeBuf PROC

EQU_ENTER

    ;// this converts tok_buf into executable code
    ;// and builds prebuf as well

    ;// step one is to set the values for small

        mov esi, [ebp].pFor_head
        ASSUME esi:PTR EQU_FORMULA_HEADER
        .IF     [esi].i_small==0
            lea esi, equ_small_8
        .ELSEIF [esi].i_small==1
            lea esi, equ_small_16
        .ELSEIF [esi].i_small==2
            lea esi, equ_small_32
        .ELSEIF [esi].i_small==3
            lea esi, equ_small_64
        .ELSE
            BOMB_TRAP   ;// invalid small value
        .ENDIF

        mov edi, [ebp].pVar_head
        ASSUME edi:PTR EQU_VARIABLE_HEADER
        lea edi, [edi].small
        mov ecx, 3
        rep movsd

    ;// then we setup for compiling

    ;// iterators
    ;// ecx ;// current index of FPU stack
    ;// ebx ;// current top of POS stack
    ;// esi ;// pointer to current position in tok string
    ;// edi ;// pointer to current location in exe string

    IFDEF DEBUG_USE_DUMPING

        invoke OutputDebugStringA, ADDR sz_line_feed
        invoke OutputDebugStringA, ADDR sz_CompileStart
        invoke OutputDebugStringA, [ebp].pFor_buf

    ENDIF

    mov edi, [ebp].pExe_buf ;// load pointer to exe buffer
    ASSUME edi:NOTHING

    mov esi, [ebp].pTok_buf ;// load the input pointer
    ASSUME esi:PTR EQU_TOKBUF

    mov ebx, [ebp].pPre_buf
    mov [ebp].pPre, ebx     ;// xfer pointer to local

    xor ecx, ecx    ;// reset the FPU indexer
    xor ebx, ebx    ;// reset the POS indexer

;///
;///    compiler loop
;///

top_of_loop:

    IFDEF DEBUG_USE_DUMPING
        invoke equ_debug_compile_dump_in, ADDR [ebp].FPU, ADDR [ebp].POS
    ENDIF

    xor eax, eax            ;// reset eax
    mov ax, WORD PTR [esi]  ;// load the token( class is in ah, oper is in al)

    .IF ah == 'b'

        call look_ahead
        .IF CARRY?

            call emit_bop_a     ;// we can do this operation now

            ;// because we just consummed the next token
            ;// we have to advance pPre and store the correct token

            mov edx, [ebp].pPre ;// get the pre buf_iterator
            mov al, bl          ;// FPU
            mov ah, cl          ;// POS
            add [ebp].pPre, 2
            mov WORD PTR [edx], ax

        .ELSE

            ;// there are cases where we have to do this now
            ;// those would be if we've got a + or a minus
            ;// so, if pos is non zero, we want to emit a bop
            ;// peek_pos and do operation until pos returns (

            .IF al=='+' || al=='-'
                .IF ebx                 ;// check if anything to peek
                    PEEK_POS            ;// peek at position
                    .IF dh!='u'         ;// can we do it ?
                        dec ebx         ;// pop the pos (already have the value)
                        call emit_bop_d ;// perform this bop
                        jmp @F
                    .ENDIF
                .ENDIF
            .ENDIF

            DEBUG_EQU_PROGRESS sz_push_bop

            xor eax, eax

        @@: PUSH_POS    ;// come back to this later
                        ;// this is also a kludge for having poped the pos in the above secton

        .ENDIF

    .ELSEIF ax == 'u)'  ;// closing parenthesis

        POP_POS                     ;// token is in dx
        .IF dh=='u'                 ;// perform this uop
            .IF dl != '('           ;// check if we got another one
                call emit_uop_d     ;// call a function
            IFDEF DEBUG_USE_DUMPING
            .ELSE
                DEBUG_EQU_PROGRESS sz_pop_uop
            ENDIF
            .ENDIF
        .ELSEIF dh=='b'
            call emit_bop_d         ;// perform this bop
        .ELSE
            BOMB_TRAP   ;// bad bad bad
        .ENDIF          ;// poped pos is supposed to be an operator

    .ELSEIF ah=='u'                 ;// regular uops always push pos

        DEBUG_EQU_PROGRESS sz_push_uop

        PUSH_POS                    ;// and continue on
        xor eax, eax

    .ELSEIF ah == 'x'   ;// load a variable

        call emit_load_var_a

    .ELSEIF ah == 'k'   ;// a constant

        call emit_load_con_a

    .ELSEIF ah == 'K'   ;// a predefined constant

        call emit_load_kon_a

    .ELSEIF !ah         ;// that's it

        ;// here, we want to pop until the POS stack is empty

        .WHILE ebx

            POP_POS
            .IF dh == 'u'
                .IF dl != '('           ;// check if we got another one
                    call emit_uop_d     ;// call a function
                IFDEF DEBUG_USE_DUMPING
                .ELSE
                    DEBUG_EQU_PROGRESS sz_pop_uop
                ENDIF
                .ENDIF
            .ELSEIF dh=='b'
                call emit_bop_d     ;// perform this bop
            .ELSE
                BOMB_TRAP   ;// bad bad bad
            .ENDIF          ;// poped pos is supposed to be an operator

            IFDEF DEBUG_USE_DUMPING
                invoke equ_debug_compile_dump_out, ADDR [ebp].FPU, ebp
                invoke equ_debug_compile_dump_in, ADDR [ebp].FPU, ADDR [ebp].POS
            ENDIF

        .ENDW

        ;// terminate the exe code with a return

            mov al, 0C3h    ;// ret
            stosb

        ;// store the final position

            mov edx, [ebp].pPre
            mov ah, bl
            mov al, cl
            mov WORD PTR [edx], ax

        ;//store the equation size and calculte the amount remaining

            sub edi, [ebp].pExe_buf
            mov esi, [ebp].pFor_head
            mov [ebp].e_len, edi
            sub edi, (EQU_FORMULA_HEADER PTR [esi]).e_len_max
            neg edi
            sub edi, 4  ;// jic
            mov [ebp].e_remain, edi

        ;// do line feed for looks

            IFDEF DEBUG_USE_DUMPING
                invoke OutputDebugStringA, ADDR sz_line_feed
            ENDIF

        ;// and return !

            EQU_EXIT

    .ELSE       ;// bad bad bad

        BOMB_TRAP   ;// got invalid token

    .ENDIF

    xor eax, eax
    mov edx, [ebp].pPre ;// get the pre buf_iterator
    mov al, bl          ;// FPU
    mov ah, cl          ;// POS
    add [ebp].pPre, 2
    mov WORD PTR [edx], ax

    IFDEF DEBUG_USE_DUMPING

        ;// let's see what else we should have stored

        xor eax, eax
        dec ax
        mov WORD PTR [edx+2], ax
        mov WORD PTR [edx+4], ax
        mov WORD PTR [edx+6], ax
        mov WORD PTR [edx+8], ax

        invoke equ_debug_compile_dump_out, ADDR [ebp].FPU, ebp

    ENDIF

    add esi, 2      ;// advance to next token
    jmp top_of_loop ;// loop until al==0



;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;///
;/// local functions:
;///

;//////////////////////////////////////////////////////////////////////

look_ahead:

    ;// we have a bop in eax, we want to look ahead
    ;// and see if we can emit the instruction immediately

    ;// part 1: the next token must be an x or k
    ;// part 2: for plus and minus
    ;//         the token after that must be a +, -, or )

    .IF BYTE PTR [esi+3] == 'x' || \
        BYTE PTR [esi+3] == 'k'

        .IF al=='+' || \
            al=='-'

            .IF BYTE PTR [esi+5] == '+' || \
                BYTE PTR [esi+5] == '-' || \
                BYTE PTR [esi+4] == ')'

                stc
                retn

            .ENDIF

        .ELSE

            stc
            retn

        .ENDIF
    .ENDIF

    clc
    retn

;//////////////////////////////////////////////////////////////////////

look_back:

    ;// given a token name in ax
    ;// we want to see if there's a match in the FPU stack
    ;// since the FPU stack is indexed backwards from the actual device
    ;// we get a sequence like this:
    ;//         st                  FPU token
    ;// instr   (0) (1) (2) (3)..   [0] [1] [2] [3]...  ecx=
    ;//                                                 0
    ;// fld X   X                   X                   1
    ;//  fld Y  Y   X               X   Y               2
    ;//  fld Z  Z   Y   X           X   Y   Z           3
    ;//
    ;//  so to find a match for X, we iterate edx from 0 to ecx-1
    ;//  then return ecx-1-edx as the fpu reg

        dec ecx             ;// subtract 1 now
        xor edx, edx        ;// start at zero
        .WHILE SDWORD PTR edx <= SDWORD PTR ecx
                            ;// this will pass through if empty
            .IF [ebp].FPU[edx*4]==eax   ;// found it
                sub edx, ecx    ;// subtract from ecx
                neg edx
                inc ecx         ;// restore ecx count
                stc             ;// return sucess
                retn
            .ENDIF
            inc edx     ;// advance
        .ENDW
        inc ecx ;// restore ecx
        clc     ;// return fail
        retn


;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////

emit_load_con_a:

;// a constant is in ax
;// it's index is al
;// we want to emit instructions the load the constant
;// update the FPU stack
;// and store the new konstant name in the fpu stack
;// we also look back

    ;// check if eax is already in the stack

    call look_back

    .IF CARRY?

        DEBUG_EQU_PROGRESS sz_load_con_a_stack

        PUSH_FPU    ;// store name

        ;// edx is the fpu register that we load
        ;// "FLD st('edx')"
        mov ax, 0C0D9h  ;// fld st(0)
        add ah, dl

        stosw

    .ELSE

        DEBUG_EQU_PROGRESS sz_load_con_a_mem

        PUSH_FPU    ;// store name

        ;// have to load from memory, al is index
        ;// "fld [esi].eVar['eax'*8].value"

        movzx edx, al   ;// xfer index to address register
        mov ax, 0D906h  ;// mask for fld [esi+mem]
        call mask_and_emit_mod_ofs

    .ENDIF

    retn

;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////

emit_load_kon_a:
;//
;// here we load one of the FPU constants
;// it's type is in al

    DEBUG_EQU_PROGRESS sz_load_con_a

    PUSH_FPU

    .IF al == 'c'

         ;//FLDPI
         mov ax, 0EBD9h

    .ELSEIF al == 'd'   ;// ln(2)

        ;//FLDLN2
        mov ax, 0EDD9h

    .ELSEIF al == 'e'   ;// log2(e)

        ;//FLDL2E
        mov ax, 0EAD9h

    .ELSE

        BOMB_TRAP   ;// inavlid constant

    .ENDIF

    stosw

    retn



;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////

emit_load_var_a:

;// a variable is in ax
;// it's index is al
;// we want to emit instructions the load the variable
;// update the FPU stack
;// and store the new variable name in the fpu stack
;// we also look back

    ;// check if eax is already in the stack

    call look_back  ;// returns fpu reg in edx

    .IF CARRY?      ;// can load from fpu

        DEBUG_EQU_PROGRESS sz_load_var_a_stack

        PUSH_FPU    ;// store name

        ;// "FLD st('edx')"
        mov ax, 0C0D9h
        add ah, dl
        stosw

    .ELSE           ;// load from memory

        DEBUG_EQU_PROGRESS sz_load_var_a_mem

        PUSH_FPU    ;// store name

        ;// mov edx, [esi+index]
        movzx edx, al
        mov ax, 8B16h               ;// mask for mov edx, [esi+???]

        call mask_and_emit_mod_ofs   ;// call the routine to emit the instruction

        ;// "fld [edx]"
        mov ax, 002D9h
        stosw

    .ENDIF


    retn

;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////

emit_bop_d:

    ;// in this version, we are combining fpu registers
    ;// as the result of a pop instruction
    ;// the command is in dl

    DEBUG_EQU_PROGRESS sz_bod_d

    .IF dl == '+'

        ;// "FADD"

        DEBUG_EQU_PROGRESS sz_fadd

        mov ax, 0C1DEh
        stosw

    .ELSEIF dl=='-'

        ;// "FSUB"

        DEBUG_EQU_PROGRESS sz_fsub

        mov ax, 0E9DEh
        stosw

    .ELSEIF dl=='*'

        ;// "FMUL"

        DEBUG_EQU_PROGRESS sz_fmul

        mov ax, 0C9DEh
        stosw

    .ELSEIF dl=='/'   ;// y x  -> x/y

        ;// "RANGE CHECK"
        ;// "FDIV"
        ;// fpu must have two spare registers

        DEBUG_EQU_PROGRESS sz_fdiv

        .IF ecx >= 6
            BOMB_TRAP       ;// outof registers
        .ENDIF
        CODE_XFER equ_div_d

    .ELSEIF dl=='@' ;// x y -> atan( y/x )

        ;// FPATAN

        DEBUG_EQU_PROGRESS sz_fpatan

        mov ax, 0F3D9h
        stosw

    .ELSEIF dl=='%'

        ;//x%y = remainder of x/y
        ;//st(0)=y st(1) = x
        ;//fprem = remainder st(0)/st(1)
        ;// range check for zero

        DEBUG_EQU_PROGRESS sz_mod

        CODE_XFER equ_mod

    .ELSEIF dl=='#'

        DEBUG_EQU_PROGRESS sz_clip

        CODE_XFER equ_clip

    IFDEF DEBUGBUILD
    .ELSE
                ;// unknown bop
        BOMB_TRAP   ;// not supposed to happen
    ENDIF
    .ENDIF

    POP_FPU     ;// pop one reg off the fpu stack

    .IF !ecx    ;// then we've corrupted this FPU name
        BOMB_TRAP   ;// fpu is empty !!!
    .ENDIF
    mov [ebp].FPU[ecx*4-4], 0


    retn

;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////

emit_bop_a:

    ;// we've already checked look ahead
    ;// and determined that we can execute this instruction right now
    ;// that means that the first arg is in the fpu, and we have to
    ;// summon the second arg, either from memory, or an existing reg

    ;// we also advance esi in the process

    add esi, 2      ;// advance

    push eax                ;// store the instruction
    mov ax, WORD PTR [esi]  ;// get the next value
    call look_back          ;// fpu reg in edx

    .IF CARRY?              ;// we do the instruction using the FPU register in edx

        DEBUG_EQU_PROGRESS sz_bop_a_stack

        pop eax             ;// retrieve the instruction
        .IF al=='+'

            ;// "FADD st, st('edx')"

            DEBUG_EQU_PROGRESS sz_fadd

            mov ax, 0C0D8h
            add ah, dl
            stosw

        .ELSEIF al=='-'  ;// st - op -> op=st(edx) st-st(x)

            ;// "FSUB st, st('edx')"

            DEBUG_EQU_PROGRESS sz_fsub

            mov ax, 0E0D8h
            add ah, dl
            stosw

        .ELSEIF al=='*'

            ;// "FMUL st, st('edx')"

            DEBUG_EQU_PROGRESS sz_fmul

            mov ax, 0C8D8h
            add ah, dl
            stosw

        .ELSEIF al=='/' ;// st / st(d)

            ;// "RANGE_CHECK 'edx'"
            ;// "FDIV st, st('edx')"

            DEBUG_EQU_PROGRESS sz_fdiv

            ;// must have two free registers
            .IF ecx >=6
                BOMB_TRAP   ;// not enough registers
            .ENDIF

            push edi    ;// need to store this

            CODE_XFER equ_div_a

            ;// then there's two more values to set

            pop eax     ;// retreive where edi was when we started

            add BYTE PTR [eax + DIV_A_1], dl
            add BYTE PTR [eax + DIV_A_2], dl

        .ELSEIF al=='@'

            ;// "FPATAN st, st('edx')"
            ;// there's no such thing as this instruction
            ;// instead we get
            ;//  fld st(y)  ;// x y
            ;//     fpatan      ;// atan y/x

            ;// "FLD st('edx')"

            DEBUG_EQU_PROGRESS sz_fpatan

            mov ax, 0C0D9h
            add ah, dl
            stosw

            ;// FPATAN
            mov ax, 0F3D9h
            stosw

        .ELSEIF al=='%'

            ;// FPREM st, st(edx)
            ;// there's no such things athis instruction
            ;// instead, we get

            ;//  fld st(y)  ;// x y
            ;//     FREM        ;// y%x

            ;// "FLD st('edx')"

            DEBUG_EQU_PROGRESS sz_mod

            mov ax, 0C0D9h
            add ah, dl
            stosw

            CODE_XFER equ_mod

        .ELSEIF al=='#'     ;// clip

            ;// "FLD st('edx')"
            mov ax, 0C0D9h
            add ah, dl
            stosw

            DEBUG_EQU_PROGRESS sz_clip

            CODE_XFER equ_clip

        .ELSE
                    ;// invalid bop
            BOMB_TRAP   ;// not supposed to happen

        .ENDIF


    .ELSE       ;// we get this from memory

        ;// ah equals the next token class
        ;// al is the evar index
        ;// the stack has the instruction we want to execute

        .IF ah=='k'     ;// constant or varable ?

            DEBUG_EQU_PROGRESS sz_bop_a_memory_kon

            pop edx         ;// retrieve the instruction
            xchg dl, al     ;// swap index, with instruction
            and edx, 0FFh   ;// mask off everything else

            .IF al=='+'

                DEBUG_EQU_PROGRESS sz_fadd

                mov ax, 0D806h              ;// fadd mem
                call mask_and_emit_mod_ofs

            .ELSEIF al=='-'     ;// "FSUB [esi].eVar['edx'*8].value"

                DEBUG_EQU_PROGRESS sz_fsub

                mov ax, 0D826h
                call mask_and_emit_mod_ofs

            .ELSEIF al=='*'     ;// "FMUL [esi].eVar['edx'*8].value"

                DEBUG_EQU_PROGRESS sz_fmul

                mov ax, 0D80Eh
                call mask_and_emit_mod_ofs

            .ELSEIF al=='/'

                ;// "RANGE CHECK [esi].eVar['edx'*8].value"
                ;// "FDIV [esi].eVar['edx'*8].value"

                DEBUG_EQU_PROGRESS sz_fdiv

                ;// need two free registers
                .IF ecx >= 6
                    BOMB_TRAP       ;// not enough registers
                .ENDIF

                ;// to make edx point at the value

                mov ax, 8D16h
                call mask_and_emit_mod_ofs

                ;// then xfer the resutant code
                CODE_XFER equ_div_a1

            .ELSEIF al=='@'

                ;// FLD (EQU_EQUATION PTR [esi+?edx?]).eVar.value

                DEBUG_EQU_PROGRESS sz_fpatan

                mov ax, 0D906h
                call mask_and_emit_mod_ofs

                ;// FPATAN
                mov ax, 0F3D9h
                stosw

            .ELSEIF al=='%'

                ;// FLD (EQU_EQUATION PTR [esi+?edx?]).eVar.value

                DEBUG_EQU_PROGRESS sz_mod

                mov ax, 0D906h
                call mask_and_emit_mod_ofs

                ;// xfer the mod code
                CODE_XFER equ_mod

            .ELSEIF al == '#'

                ;// clip ==> a # b
                ;// a is already in fpu, so we load b

                ;// FLD (EQU_EQUATION PTR [esi+?edx?]).eVar.value

                DEBUG_EQU_PROGRESS sz_clip

                mov ax, 0D906h
                call mask_and_emit_mod_ofs

                ;// xfer the mod code
                CODE_XFER equ_clip

            IFDEF DEBUGBUILD
            .ELSE
                        ;// unknown bop
                BOMB_TRAP   ;// not supposed to happen
            ENDIF
            .ENDIF


        .ELSE ;// ah='x'    ;// variable

            ;// all of these need the pointer
            ;//mov edx, (EQU_EQUATION PTR [esi]).eVar[2*8].value    ;// eax=2

            DEBUG_EQU_PROGRESS sz_bop_a_memory_var

            movzx edx, al   ;// set up for xlation to offset
            mov ax, 8B16h
            call mask_and_emit_mod_ofs

            pop edx         ;// retrieve the instruction

            ;// then each opertion instruction gets an instruction

            .IF dl=='/'

                DEBUG_EQU_PROGRESS sz_fdiv

                ;// "RANGE CHECK [eax]"
                ;// "FDIV [eax]"
                ;// need two free registers
                .IF ecx >= 6
                    BOMB_TRAP       ;// out of registers
                .ENDIF

                ;// xfer the rest of the code
                CODE_XFER equ_div_a1

            .ELSEIF dl=='@'     ;// atan doesn't about ad swapping

                DEBUG_EQU_PROGRESS sz_fpatan

                ;// FLD DWORD PTR [edx]
                mov ax, 02D9h
                stosw

                ;// FPATAN
                mov ax, 0F3D9h
                stosw

            .ELSEIF dl=='%'     ;// mod doesn't about ad swapping

                DEBUG_EQU_PROGRESS sz_mod

                ;// FLD DWORD PTR [edx]
                mov ax, 02D9h
                stosw

                ;// xfer the rest of the code
                CODE_XFER equ_mod

            .ELSEIF dl=='+'

                DEBUG_EQU_PROGRESS sz_fadd

                ;// "FADD [edx]"
                mov ax, 002D8h
                stosw

            .ELSEIF dl=='-'

                DEBUG_EQU_PROGRESS sz_fsub

                ;// "FSUB [edx]"
                mov ax, 022D8h
                stosw

            .ELSEIF dl=='*'

                DEBUG_EQU_PROGRESS sz_fmul

                ;// "FMUL [edx]"
                mov ax, 00AD8h
                stosw

            .ELSEIF dl=='#'

                DEBUG_EQU_PROGRESS sz_clip

                ;// FLD DWORD PTR [edx]
                mov ax, 02D9h
                stosw

                CODE_XFER equ_clip

            IFDEF DEBUGBUILD
            .ELSE
                        ;// unknown bop
                BOMB_TRAP   ;// not supposed to happen
            ENDIF
            .ENDIF

        .ENDIF

    .ENDIF


    ;// then we've corrupted this FPU name
    IFDEF DEBUGBUILD
        .IF !ecx
            BOMB_TRAP   ;// fpu is empty !!!
        .ENDIF
    ENDIF
    mov [ebp].FPU[ecx*4-4], 0


    retn

;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////

emit_uop_d:

    ;// this is always the result of a pop_pos instruction
    ;// so st(0) has the parameter
    ;// some of these will pop registers, most do not
    ;// the instruction is in dl
    ;// all of these corrupt the name in the FPU stack

    DEBUG_EQU_PROGRESS sz_uop_d_stack

    ;// since ecx is the NEXT register to use
    ;// we correct ecx-1
    DEBUG_IF <!!ecx>;// fpu is empty !!!

    mov [ebp].FPU[ecx*4-4], 0


    .IF  dl=='L'    ;// this one pops an fpu
                    ;// so we do it seperately

        ;// we need 1 free reg
        .IF ecx >= 7
            BOMB_TRAP   ;// out of regs
        .ENDIF

        mov eax, [ebp].POS[ebx*4+4] ;// load previously pushed location
        sub eax, 2              ;// back up one(under-run will hit something)
        .IF WORD PTR [eax]=='b*'
            ;// we can combine
            ;// RANGE CHECK with small
            ;// y*log2(x) ;// st(0)=x, st(1) = y

            DEBUG_EQU_PROGRESS sz_log2_combined

            POP_FPU
            POP_POS ;// <--- this may not work

            CODE_XFER equ_log2_combined

        .ELSE
            ;// we can not combine
            ;// RANGE CHECK with small
            ;// log2

            DEBUG_EQU_PROGRESS sz_log2_uncombined

            CODE_XFER equ_log2_uncombined

        .ENDIF

    .ELSEIF dl=='N'

        DEBUG_EQU_PROGRESS sz_fchs

        ;// "FCHS"
        mov ax, 0E0D9h
        stosw

    .ELSEIF dl=='M'
        ;// "FABS"

        DEBUG_EQU_PROGRESS sz_fabs

        mov ax, 0E1D9h
        stosw

    .ELSEIF dl=='S'

        ;// FSIN

        DEBUG_EQU_PROGRESS sz_fsin

        mov ax, 0FED9h
        stosw

    .ELSEIF dl=='C'

        ;// FCOS

        DEBUG_EQU_PROGRESS sz_fcos

        mov ax, 0FFD9h
        stosw

    .ELSEIF dl=='H'

        ;// tanh function

        DEBUG_EQU_PROGRESS sz_tanh

        ;// need three free registers
        .IF ecx >= 5
            BOMB_TRAP       ;// not enough registers
        .ENDIF

        CODE_XFER equ_tanh

    .ELSEIF dl=='P'

        ;// 2^

        DEBUG_EQU_PROGRESS sz_2_to_the_x

        ;// need two free regs
        .IF ecx >=6
            BOMB_TRAP   ;// out of registers
        .ENDIF

        CODE_XFER equ_pow2

    .ELSEIF dl=='Q'

        DEBUG_EQU_PROGRESS sz_sqrt

        CODE_XFER equ_sqrt

    .ELSEIF dl=='I'

        ;// frndint D9 FC

        DEBUG_EQU_PROGRESS sz_frndint

        mov ax, 0FCD9h
        stosw

    .ELSEIF dl=='G'

        ;// sign

        DEBUG_EQU_PROGRESS sz_sign

        CODE_XFER equ_sign_abox225

    .ELSE
        BOMB_TRAP   ;// invalid instruction
    .ENDIF

    ;// that should do it

    retn


;///////////////////////////////////////////////////////////////////////



mask_and_emit_mod_ofs:

    ;// edi must point at destination
    ;// ax must have two byte instruction mask
    ;// dx must be an evar INDEX

    xchg al,ah                  ;// store in correct order
    shl edx, EQU_VARIABLE_SHIFT ;// turn into an offset
    .IF ZERO?                   ;// zero offset

        stosw                   ;// just store

    .ELSEIF edx & 0FFFFFF80h    ;// dword offset

        or ah, 10000000y        ;// [esi+dd]
        stosw
        mov DWORD PTR [edi], edx
        add edi, 4

    .ELSE                       ;// byte offset

        or ah, 01000000y        ;// [esi+db]
        stosw
        mov BYTE PTR [edi], dl
        inc edi

    .ENDIF

    retn


equ_BuildExeBuf ENDP


;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////



IFDEF DEBUG_USE_DUMPING

.DATA

    sz_pos_line db 0dh, 0ah,'%s  pos=%i   ',0
    sz_fpu      db 'st(%i)=%s ',0
    sz_pos_after db 'pos=%i pPre=%i ', 0

.CODE


equ_debug_compile_dump_in PROC STDCALL pFPU:DWORD, pPOS:DWORD


    ;// iterators
    ;// ecx ;// current index of FPU stack
    ;// ebx ;// current top of POS stack
    ;// esi ;// pointer to current position in tok string
    ;// edi ;// pointer to current location in exe string

    LOCAL buf[64]:BYTE
    LOCAL temp:DWORD

    pushad

    movzx eax, WORD PTR [esi]
    .IF al < 20h
        .IF ah
            add al, '0'
        .ELSE
            mov ax, '--'
        .ENDIF
    .ENDIF
    xchg ah, al
    mov temp, eax

    invoke wsprintfA, ADDR buf, ADDR sz_pos_line, ADDR temp, ebx
    invoke OutputDebugStringA, ADDR buf

    popad

    ret

equ_debug_compile_dump_in ENDP



equ_debug_compile_dump_out PROC STDCALL pFPU:DWORD, pEHeader:DWORD

    ;// this lists the contents of the pos and fpu stack

    LOCAL fpu_top:DWORD
    LOCAL buf[64]:BYTE
    LOCAL temp:DWORD

    pushad

    mov fpu_top, ecx

    ;// iterators
    ;// ecx ;// current index of FPU stack
    ;// ebx ;// current top of POS stack
    ;// esi ;// pointer to current position in tok string
    ;// edi ;// pointer to current location in exe string

    ;// show the position after the function

        ;// determine what the prebuffer thinks it pointing at
        mov ecx, pEHeader
        mov edx, (EQU_EDIT_HEADER PTR [ecx]).pPre
        sub edx, (EQU_EDIT_HEADER PTR [ecx]).pPre_buf
        sub edx, 2
        shr edx, 1

    invoke wsprintfA, ADDR buf, ADDR sz_pos_after, ebx, edx
    invoke OutputDebugStringA, ADDR buf

    ;// show the fpu stack

    mov edi, pFPU
    ASSUME edi:PTR DWORD
    mov esi, fpu_top

    .WHILE esi

        dec esi

        xor eax, eax
        or eax, [edi+esi*4]
        .IF ZERO?
            mov eax, '??'
        .ELSE
            .IF al<20h
                add al, '0'
            .ENDIF
        .ENDIF
        xchg ah, al

        mov temp, eax
        mov ecx, fpu_top
        sub ecx, esi
        dec ecx
        invoke wsprintfA, ADDR buf, ADDR sz_fpu, ecx, ADDR temp
        invoke OutputDebugStringA, ADDR buf

    .ENDW

    popad

    ret

equ_debug_compile_dump_out ENDP



.DATA

    szTok_1 db '%c%i ',0    ;// for variables and konstants
    szTok_2 db '%c%c ',0    ;// for operators
    sz_tokenizing db 'Tokenizing: ', 0

.CODE

equ_debug_dump_tok_buf PROC STDCALL

    LOCAL buf[32]:BYTE

    pushad

    mov ebx, equ_pEdit
    ASSUME ebx:PTR EQU_EDIT_HEADER

    invoke OutputDebugStringA, ADDR sz_line_feed
    invoke OutputDebugStringA, ADDR sz_tokenizing
    invoke OutputDebugStringA, [ebx].pFor_buf
    invoke OutputDebugStringA, ADDR sz_line_feed

    mov esi, [ebx].t_len
    mov edi, [ebx].pTok_buf
    ASSUME edi:PTR EQU_TOKBUF
    .WHILE esi
        movzx ecx, [edi].class
        movzx edx, [edi].oper
        .IF ecx=='x' || ecx=='k'
            invoke wsprintfA, ADDR buf, ADDR szTok_1, ecx, edx
        .ELSE
            invoke wsprintfA, ADDR buf, ADDR szTok_2, ecx, edx
        .ENDIF
        invoke OutputDebugStringA, ADDR buf
        add edi, 2
        dec esi
    .ENDW

    invoke OutputDebugStringA, ADDR sz_line_feed

    popad

    ret

equ_debug_dump_tok_buf ENDP




.DATA

    szDumpSubbuf db 0dh, 0ah, 'Sub Buffer', 0dh, 0ah, 'for ele iTok pos fpu', 0dh, 0ah, 0
    szTokNum db '%i %i %i', 0dh, 0ah, 0

.CODE


equ_debug_dump_sub_buf PROC STDCALL

;// here we want to display the for_buf, and matching tokens

    LOCAL buf[32]:BYTE
    LOCAL f_length:DWORD

    pushad

    IFDEF DEBUG_COMPILE_SLEEP
        invoke Sleep, 100   ;// give devstudio a chance to catch up ??
    ENDIF

    ;// clear the local buffer
    lea edi, buf
    mov ecx, 32/4-2
    mov eax, 20202020h
    rep stosd
    xor eax, eax
    stosd

    ;// get pointers
    mov ebx, equ_pEdit
    ASSUME ebx:PTR EQU_EDIT_HEADER

    mov eax, [ebx].f_len
    mov f_length, eax

    mov esi, [ebx].pSub_buf
    ASSUME esi:PTR EQU_SUBBUF

    mov edi, [ebx].pFor_buf
    ASSUME edi:PTR BYTE

    mov ebx, [ebx].pPre_buf
    ASSUME ebx:PTR EQU_PREBUF

    invoke OutputDebugStringA, ADDR szDumpSubbuf

    ;// get the for_buf character
@0: mov al, BYTE PTR [edi]
    mov buf[0], al

    ;// get the element
    movzx edx, [esi].i_ele
    shl edx, EQU_ELEMENT_SHIFT
    mov al, equ_element[edx].cFor
    mov buf[2], al

    ;// get the assigned token index
    movzx ecx, [esi].i_tok
    movzx edx, [ebx+ecx*2].POS
    push edi
    movzx edi, [ebx+ecx*2].FPU

    ;// format and display
    invoke wsprintfA, ADDR buf[4], ADDR szTokNum, ecx, edx, edi
    invoke OutputDebugStringA, ADDR buf

    IFDEF DEBUG_COMPILE_SLEEP
    .IF !(f_length & 0Fh)
        invoke Sleep, 100   ;// give devstudio a chance to catch up
    .ENDIF
    ENDIF


    pop edi

    ;// iterate
    add esi, 2
    inc edi
    dec f_length
    jnz @0

    ;// that should do it
    popad
    ret

equ_debug_dump_sub_buf ENDP

ENDIF   ;// DEBUGBUILD

;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
ENDIF ;// use this file
END


