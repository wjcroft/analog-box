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
;//  equation.inc   common parameters for the equation object
;//                 notes at bottom


;// function prototypes called by the osc_object

    equ_Compile     PROTO STDCALL pFor:DWORD, pVar:DWORD, bInit:DWORD

    equ_InitDialog PROTO STDCALL hWnd:DWORD, pObject:DWORD, pFor:DWORD, pVar:DWORD, dwFlags:DWORD

        ;// values for flags
        EQE_INIT_VARIABLES  equ 01h ;// tells tokenize to initialize the variable table
        EQE_USE_INDEX       equ 02h ;// tells editor to use indexed variables
        EQE_NO_PRESETS      equ 04h ;// disbale the MtoF buttons

    equ_Command PROTO STDCALL hWnd:DWORD, cmdID:DWORD

    equ_build_this_number   PROTO


;// buffers and header are described below


;// fixed compiler and editor limits

    EQU_MAX_FPU equ 8       ;// max number of fpu registers
    EQU_MAX_POS equ 32      ;// max parenthis and op nesting (stack size)

    EQU_MAX_POS_DLG equ EQU_MAX_POS-1   ;// maximum  on the dialog

    EQU_EDIT_DLG_SUB equ 8  ;// f_len_max minus this is the limit we allow for
                            ;// adding new stuff

;//////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////
;//
;// the EQU_FORMULA_WRAPPER holds the for_buf for the equation
;// as well as the desired value of small and the f_len
;// this struct should be allocated with the object
;// thus it may be saved quickly
;// and painted as required

EQU_FORMULA_HEADER STRUCT

    ;// filled in by object

    f_len_max   dd  0   ;// maximum allowable length
    d_len_max   dd  0   ;// max allowable length
    e_len_max   dd  0   ;// max allowable length
    i_small     dd  0   ;// index of small for this object
    bDirty      dd  0   ;// flags tells us if we have to rebuild everything

    ;// filled in by equation
    pString     dd  0   ;// tells paint where to get it's text

EQU_FORMULA_HEADER  ENDS

;// three buffers must follow, in stated order
;//
;// for_buf db EQU_MAX_FOR dup (0)
;// dis_buf db EQU_MAX_DIS dup (0)
;// exe_buf db EQU_MAX_EXE dup (0)





;// the EQU_VARIABE table acts as the resource list for the formula
;// tokenize will use this table and update dwFlags as required

;// objects should initialize a fixed size array of EQU_VARIABLES
;// preceeded by an EQU_VARIABLE_HEADER. when passing pointers, pass the EQU_VARIABLE

;// There must be one EQU_VARIABLE for every possible variable
;// initialize these by filling in the texName (how it appears in the formula)
;// and the token name (how it appears in the token buffer)
;// for indexed systems, each index must be inorder!!!

;// dwFlags are set by the equ_Compile (VAR_IN_USE)
;// and by the objects InitPins or Command handler (VAR_AVAILABLE)

;// pPin is used only by osc_InitPins and osc_Calc to get to the APin quickly
;// this also allows objects that dynamically adjust the pins, ie:osc_Diff

EQU_VARIABLE_HEADER STRUCT  ;// 16 bytes    initialialized by object

    num_var dw  0   ;// size of the variable table
    tot_num dw  0   ;// total number of slots, gives the amount remaining for numbers

    small           REAL4 0.0e+0
    small_recip     REAL4 0.0e+0
    small_small_log REAL4 0.0e+0

EQU_VARIABLE_HEADER ENDS
;// more than one EQU_VARIABLEs must immediately follow this

    EQU_OFFSET_SMALL equ -12;//  this is how compiler locates
    EQU_OFFSET_RECIP equ -8 ;//  the various values of small
    EQU_OFFSET_LOG   equ -4 ;//  by using a negative offset from the var table pointer

;// this struct cleans up a lot of the confusion I've run into
;// variable is designed to be printable (text is stored in correct order)
;// and to allow struct offset to the item in question
variable    STRUCT

    letter  db  0   ;// letter assigned
    index   db  0   ;// index or zero

variable    ENDS

    ;// so: in memory, variable is arranged ( letter, index )
    ;// in a register variable is arranged  ( ah=index, al=letter )


;// EQU_VARIABLE s contain enough information to manage a variable

EQU_VARIABLE STRUCT ;// 16 bytes

    value   dd 0        ;// may be pointer or the actual value
                        ;// put value first to simplify generated instructions

    textname variable {};// initialize with value for object assigned variables
                        ;// leave blank for compiler assigned konstants
                        ;// if indexed, use UPPER byte for ascii index
    token   variable {} ;// corresponding token name, assign as xn ONLY
                        ;// otherwise leave blank
                        ;// k for constant , x for variable, index in lower byte
    pPin    dd 0        ;// pointer to the APin assigned to this variable
                        ;// used by the object
    dwFlags dd  0       ;// various flags, see below

EQU_VARIABLE ENDS   ;// 16 bytes

    ;// values for dwFlags
    EVAR_IN_USE     equ     00000001h   ;// this variable is in use
    EVAR_AVAILABLE  equ     00000002h   ;// this variable is available for use

    EQU_VARIABLE_SHIFT equ 4    ;// shift index left to get offset

    ;// future --> user flags are bits 31 to 16
    ;// so no system in the equation should use them

    ;// note --> variable in the var table must be assigned in order
    ;// a b x y z u v w
    ;// this saves code and time in the dialog enabler


;// the resulting executable must not be messed with while in use
;// so the compiler only acts when in play sync or preplay
;// play_sync saves a lot of code and head ache compared to buffer swapping or other Rube Goldberg systems
;// Since pins may be adjusted anyways it probably better to do this




;// to edit this:
;//
;//     we want to be able to call up a seperate editor
;//     so popup_system must be able to deal with this
;//     likely candidate is a flag in popup_show to tell popup not to reset popup_hWnd
;//     this will come in handy elsewhere (DX wrapper for instance)

;// after that, popup will call osc_InitMenu which in turn will call equ_InitEditor
;// init editor will grab all the resource handles, allocate an EQU_EDITOR struct
;// and generally make sure all is well

;// popup_Proc will recieve commands, and pass them to osc_Command, which inturn will
;// route them to osc_Equ_Command (or osc_Diff_Command)
;// which inturn will pass appropropriate commands to equ_Command
;//
;// equ_Command will do the desired action, then ReCompile as required
;// if the circuit is playing, it will invoke play_sync first
;// if appropriate, equ_Command will also call osc_Equ_UpdatePins, still in play sync
;//
;// it's upto osc_Equ_UpdatePins to adjust connections and hide/unhide pins

;// the editor struct will be allocated globally
;// only one equation may be edited at a time

EXTERNDEF   pEditHeader:DWORD   ;// defined in equation.asm

;// this struct is designed to replace ebp in appropriate equations
EQU_EDIT_HEADER STRUCT

    curPos  db  0   ;// position of the cursor in for_buf
    selPos  db  0   ;// position of the cursor in dis_buf
    selLen  db  0   ;// number of characters to highlight
    bFlags  db  0   ;// flags for operation

    f_len   dd  0   ;// length of the formaula string
    d_len   dd  0   ;// length of the display string
    e_len   dd  0   ;// length of exe_buffer
    t_len   dd  0   ;// length of the token buffer

;// num_con dd  0   ;// index of highest constant

    e_remain dd 0   ;// space left in the exe buffer
    k_remain dd 0   ;// number of slots left for consants

    f_len_max_dlg   dd  0   ;// maximum num characters we allow in the dlg
    d_len_max_dlg   dd  0   ;// maximum num characters we allow in the dlg

;// pObject  dd 0   ;// pointer to the object used when calling object.InitPins

    pFor_head   dd  0   ;// pointer to the formula header
    pFor_buf    dd  0   ;// pointer to formula header
    pDis_buf    dd  0   ;// pointer to display buffer
    pExe_buf    dd  0   ;// pointer to exe buf

    pVar_head   dd  0   ;// pointer to the variable header
    pVar_buf    dd  0   ;// pointer to the variable table

    pSub_buf    dd  0   ;// pointer to sub buffer
    pTok_buf    dd  0   ;// pointer to the token buffer
    pPre_buf    dd  0   ;// pointer to pre buffer

    ;// stacks for compiler
    FPU dd  EQU_MAX_FPU dup (?) ;// symbolic names for the FPU stack
    POS dd  EQU_MAX_POS dup (?) ;// positions of pushed parameters

    ;// temp's needed for build tok_buf
    temp_bcd TBYTE  ?   ;// storeage for building numbers
    temp_real   dd  ?   ;// the built number
    pPre        dd  ?   ;// iterator for the pre buf


EQU_EDIT_HEADER ENDS
;// three arrays will follow this, all are the size of f_len_max

;// sub_buf WORD ;// substitutes for chars with their token class
;// tok_buf WORD ;// tokenized equation
;// pre_buf WORD ;// pos/fpu pairs

;// format of the sub buf   one-to-one correspondance with for_buf

    EQU_SUBBUF  STRUCT

        i_ele   BYTE    ?   ;// element index
        i_tok   BYTE    ?   ;// token index

    EQU_SUBBUF  ENDS

;// format of the token buffer

    EQU_TOKBUF STRUCT

        oper    BYTE    ?   ;// index or operator
        class   BYTE    ?   ;// token class

    EQU_TOKBUF ENDS


;// format of the pre buf   one-to-one correspondance to tok buf

    EQU_PREBUF  STRUCT

        POS     BYTE    ?   ;// current parenthesis depth
        FPU     BYTE    ?   ;// current number of used fpu registers

    EQU_PREBUF  ENDS

;// since it's a temprary struct we need allocate and destoy
;// these should only be called by the equation system

;// equ_EditCtor PROTO STDCALL pObject:DWORD, pFor:DWORD, pVar:DWORD, dwFlags:DWORD
    equ_EditCtor PROTO STDCALL pFor:DWORD, pVar:DWORD, dwFlags:DWORD
    equ_EditDtor PROTO

    EXTERNDEF equ_pEdit:DWORD


;// EQU_EDIT is designed to replace ebp in proceedures
;// so the sub routines may not have local variables
;// and must not specify a language type
;// this also relies on a global equ_pEdit pointer
;// use these macros instead of the built in prologue and epilog

    EQU_ENTER MACRO

        push ebp
        push esi
        push edi
        push ebx
        mov ebp, equ_pEdit
        ASSUME ebp:PTR EQU_EDIT_HEADER

        ENDM

    EQU_EXIT MACRO

        pop ebx
        pop edi
        pop esi
        pop ebp
        ret

        ENDM



;//////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////

;// we can simplify a lot of the editing code by creating this table
;// it's purpose is to allow various ways of searching for elements
;// the table is defined in equation.asm

    EQU_ELEMENT STRUCT  ;// 16 bytes

        cFor    db  0   ;// charcter as appears in formula buffer
        cTok    db  0   ;// token class of character

        cLen    db  0   ;//   length of the display string
        cDis    db 6 dup (0);// display string for dis_buf

        fpu     db  7   ;// states the maximum number of fpu registers that can be in use
        eLen    db  2   ;// max size in bytes of the equation machine code

        cmd     db  0   ;// command ID of the button
        hWnd    dd  0   ;// hWnd of the button

    EQU_ELEMENT ENDS


    EQU_ELEMENT_SHIFT equ 4 ;// shift index left to get offset


;// these are sub categorized to simplfy some searches

    EXTERNDEF equ_element:EQU_ELEMENT
    EXTERNDEF equ_element_con:EQU_ELEMENT
    EXTERNDEF equ_element_dec:EQU_ELEMENT
    EXTERNDEF equ_element_var:EQU_ELEMENT
    EXTERNDEF equ_element_bop:EQU_ELEMENT
    EXTERNDEF equ_element_close:EQU_ELEMENT
    EXTERNDEF equ_element_uop:EQU_ELEMENT
    EXTERNDEF equ_element_end:EQU_ELEMENT


;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////


;// externals



;// these are supplied for backwards compatability with the funct1 object
;// they are defined in equation.asm

;// revamped ABOX232 to allow more, see equ_preset_table
;// EXTERNDEF equ_preset_m2f:BYTE
;// EXTERNDEF equ_preset_f2m:BYTE
;// EXTERNDEF equ_preset_default:BYTE
;// EXTERNDEF equ_szM2F:BYTE
;// EXTERNDEF equ_szF2M:BYTE

    EQU_PRESET_FORMULA_LENGTH equ 7

    EQUATION_PRESET STRUCT

        formula     db  EQU_PRESET_FORMULA_LENGTH*4 DUP (0) ;// formula, must be 7 dwords max
        string      db  8 DUP (0)   ;// string

    EQUATION_PRESET ENDS

    EXTERNDEF equ_m2f:EQUATION_PRESET
    EXTERNDEF equ_f2m:EQUATION_PRESET
    EXTERNDEF equ_d2f:EQUATION_PRESET
    EXTERNDEF equ_f2d:EQUATION_PRESET
    EXTERNDEF equ_d2m:EQUATION_PRESET
    EXTERNDEF equ_m2d:EQUATION_PRESET
    EXTERNDEF equ_default:EQUATION_PRESET



;/////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////

;/////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////

comment ~ /*
NOTES:

properly built for_bufs

    this whole system mandates that for_buf be correctly built at all times
    a slew of editing functions will do this.

character set, all are case sensitive

    0 1 2 3 4 5 6 7 8 9 .

        numbers,
        must be surrounded by operators or begin-end of string
        trailing decimals are not allowed
        leading and trailing zeros are correctly accounted for
        maximum of 18 digits.
        currently there are no previsions for sci notation

    c d e

        built in constants
        simply load one of the built in constants in the FPU

    a b x y z w u v

        variables
        if single character, then an implied index of zero
        if followed by a digit, then index is derived appropriately
        the tokenizer must be able to find the index in the evar table

    + - * / @ % #

        bops
        binary operators
        require numbers or variables on either side

    N M S C H Q ^ L (

        uops
        unary operators
        require a closing parenthesis
        opening parenthesis is implied

    )

        closing parenthesis
        required of all unary operator


the variable table

    in order to share variables across many equations
    the object must maintain a variable table

    it is set up as an array of variables names along with their tokens
    the compiler will scan this table to locate for_buf items

    extra space must be set aside for constant numbers
    (don't access from object)

    the variables MUST BE DEFINED in the order they appear in the element table
    this order is:

        a b x y z u v w

    incorrect order will mess up the compiler


indexed variables

    maintain the same order
    and assign an ascii index to the name
    indexed MUST BE ASSIGNED IN REVERSE ORDER



*/ comment ~
