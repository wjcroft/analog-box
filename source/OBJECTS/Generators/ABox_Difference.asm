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
;//     ABOX242 AJT -- detabified + text adjustments for 'lines too long' errors
;//     ABOX242 -- AJT -- Using Virtual Protect to allow dynamicly generated code
;//                    -- many thanks to qWord and the folks at masm32.com
;//
;//##////////////////////////////////////////////////////////////////////////
;//
;// ABox_Difference.asm         differential system
;//
;//
;// TOC:
;//
;// diff_build_inuse_masks
;// diff_assign_pins
;// diff_compile
;// diff_build_equation_string
;// diff_determine_size
;// diff_layout_pins
;// diff_build_text
;// diff_set_triggers
;// diff_EnableDialog_differential
;// diff_UpdateDialog_differentials
;// diff_launch_editor
;//
;// diff_Ctor
;// diff_kludge_ctor
;// diff_Dtor
;// diff_SetShape
;// diff_InitMenu
;// diff_Command
;//
;// diff_Proc
;// diff_wm_command_proc
;// diff_wm_keydown_proc
;// diff_wm_activate_proc
;// diff_wm_close_proc
;//
;// diff_AddExtraSize
;// diff_private_write
;// diff_Write
;// diff_SaveUndo
;// diff_LoadUndo
;//
;// diff_PrePlay
;// diff_Calc


OPTION CASEMAP:NONE

.586
.MODEL FLAT

    .NOLIST
    include <Abox.inc>
    include <equation.inc>
    .LIST


;// DEBUG_MESSAGE_ON
    DEBUG_MESSAGE_OFF


;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;///
;///    this would be version 2 of the differential system
;///
;///
;// general:
;//
;//     this system is divided into differentials, the set of all dX, ddX, etc
;//
;//     there are a maximum of 6 differentials.
;//     labeled and indexed as X,Y,Z,U,V,W.
;//     each differential has an order which ranges from 1 to 4
;//     and an equation compatible with the eqution compiler.
;//     variables in the equation may be selected from the other differentials
;//     or from a pool of external parameters.
;//
;//     each derivative may be applied to a triggered input pin that may
;//     be set to replace, add, or scale the current value
;//
;//     there is also a step trigger, a step size, and a damping input pin
;//
;//     internal to the calculation is the integration order and clipping factor
;//

;///    object layout considerations:

;// maximum of 12 output pins (right side)
;// maximum of 12 parameter input pins (top side)
;// maximum of 12 triggered inputs (bottom)
;// the step_trigger, step_size and damping inputs are on the left side

;// there must be at least one output




;////////////////////////////////////////////////////////////////////////

;//
;// data sizes
;//

    DIFF_NUM_EQUATION   equ 6   ;// x,y,z,w,u,v
    DIFF_NUM_DERIVATIVE equ 5   ;// 0 through 4
    ;// derivative[4] may not be assigned a trigger

    DIFF_NUM_FOR    equ 128                 ;// bytes for storing formula
    DIFF_NUM_DIS    equ DIFF_NUM_FOR * 3    ;// bytes for the display
    DIFF_NUM_EXE    equ 1024                ;// bytes of exe buffer

    ;// this is the limit of the common variable pool
    DIFF_NUM_VAR    EQU 5 * 6   ;// = 30
    DIFF_NUM_PARAM  EQU 12      ;// = 12
    DIFF_NUM_NUMBER EQU DIFF_NUM_VAR * 2
    DIFF_TOT_NUM    EQU DIFF_NUM_VAR + DIFF_NUM_PARAM + DIFF_NUM_NUMBER
    ;// = 72, 30 dif variables, 12 parameters, 30 constants


;/////////////////////////////////////////////////////////////////////////////
;//
;// data structures
;//

;// this struct represents one equation and the pile of dirivitives
;// all equations share a common variable pool, described below

    DIFF_EQUATION STRUCT

        for_head EQU_FORMULA_HEADER {}      ;// required equation header
        for_buf db DIFF_NUM_FOR dup (0)     ;// user formula for this variable
        dis_buf db DIFF_NUM_DIS dup (0)     ;// display buff for this formula
        exe_buf db DIFF_NUM_EXE dup (0)     ;// executable code

        cur_value dd DIFF_NUM_DERIVATIVE dup (0);// the current values, evar_value always points at these
        rk_RX    dd DIFF_NUM_DERIVATIVE dup (0) ;// runge-kutta initial values
        rk_RA    dd DIFF_NUM_DERIVATIVE dup (0) ;// runge-kutta accumulated values

        order       dd  0   ;// the order of this equation
                            ;// zero for not used
        pVariables  dd  0   ;// pointer to this equation's variable block
                            ;// saves some code, set in the Ctor
    DIFF_EQUATION ENDS

;// this struct also manages the pin interface
;// since there's extra room in each variable
;// we'll store the trigger states as well

    DIFF_VARIABLES  STRUCT

        var_head    EQU_VARIABLE_HEADER {}

        parameter_table EQU_VARIABLE DIFF_NUM_PARAM dup ({})
        variable_table  EQU_VARIABLE DIFF_NUM_VAR   dup ({})
        number_table    EQU_VARIABLE DIFF_NUM_NUMBER dup ({})

    DIFF_VARIABLES  ENDS

;// the parameter table is a fixed size block of 30 EQU_VARIABLE s
;// these represent the six equations, with 5 deriviatives each
;// the evar.text names are ALWAYS stored in reverse order ( z5, z4, z3, z2, z1 )
;// the token names are stored in evar format in forward order

;// EVAR.dwFlags

;//     in the common variable pool, we use the evar.dwFlags to store settings
;//     the botton 16 bits are reserved for the equation, so we use the top 16
;//     for various fields

;// there are two classes of values:
;//
;//     type    tells something about what the variable is
;//     index   tells which pin the variable is to be assigned to
;//
;//     so it is crucial to store the evar.dwFlags in the file

    ;// trigger type (upper case to indicate this is the 'type' field )
                                    ;// zero for no trigger, non zero requires pin assignment
        DVAR_T_E     equ 00010000h  ;// value = input
        DVAR_T_PE    equ 00020000h  ;// value += input
        DVAR_T_ME    equ 00030000h  ;// value *= input

        DVAR_T_TEST  equ 00030000h  ;// test for existance
        DVAR_T_MASK equ 0FFFCFFFFh  ;// if T_ is used, t_index needs to be assigned
        DVAR_T_SHIFT equ 16         ;// shift to get an index to a button

    ;// index of the triggered input pin assigned to this variable
    ;// lower case to indicate this is the 'index' field
    ;// a type bit must be defined for this to be valid

        DVAR_t_TEST equ  00F00000h  ;// use 0 to tell InitPins to assign a new pin
        DVAR_t_MASK equ 0FF0FFFFFh
        DVAR_t_SHIFT equ 20         ;// shift right to get an index

        ;// note that the t_index is ONE BASED !!!!!
        ;// zero indicates that a pin is not assigned

    ;// index of the output pin assigned, needed when loading from a file

        DVAR_x_TEST equ  0F000000h  ;// also doubles as the display flag (non-zero)
        DVAR_x_MASK equ 0F0FFFFFFh  ;// use 0Fh to tell pin_init to assign a pin
        DVAR_x_SHIFT equ 24         ;// shift right to get an index

        ;// x_index is also ONE BASED !!!

    ;// for the parameter pins, we share the same field location
    ;// but define a different name so I don't confused

        DVAR_a_TEST equ DVAR_x_TEST
        DVAR_a_MASK equ DVAR_x_MASK
        DVAR_a_SHIFT equ DVAR_x_SHIFT

        ;// a_index is ONE BASED !!!!


comment ~ /*

    quick summery of the pin flags

    apin.dwUser points at variable to indicate the pin is assigned

    there are three assignment schemes, indicated by variable.dwFlags

    class   action          flags
    ------------------------------------------------------
    x pins

        remove or unassign  : value of zero in index field
        assign new          : value of 0Fh in index field
        init from file      : any other value

        evar.pPin indicates that the variable is currently assigned to a pin


    class   action          flags
    ------------------------------------------------------
    t pins

        remove or unassign  : zero in type field, non-zero in index field
        assign new          : non-zero in type field, zero in index field
        init from file      : non_zero in both type field and index field

        zero in both fields indicates un-assigned


    class   action          flags
    ------------------------------------------------------
    a pins

        remove or unassign  : EVAR_IN_USE is OFF
        assign new          : EVAR_IN_USE is ON, and index is zero
        init from file      : any other value in index field

*/ comment ~


;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////


;// then we roll all this into a diff_data struct
;// the Ctor will take care of initilizing it

    OSC_DIFF_DATA   STRUCT

        equations       DIFF_EQUATION   DIFF_NUM_EQUATION dup ({})
        variables       DIFF_VARIABLES      {}

    ;// these next values are maintained and help performance by
    ;// skipping functions if nothing needs done

        extra dd 0      ;// extra file bytes we need, no since in counting them twice

        inuse_variables     dd  0   ;// bit mask for the displayed variables
        display_variables   dd  0   ;// bit flags for displayed output pins
        display_triggers    dd  0   ;// bit mask for the displayed triggers
        inuse_parameters    dd  0   ;// bit flags for the parameters

        ;// use diff_build_inuse_masks to measure

        ;// do NOT rearrange these, must be in A T X order !!

        num_A   dd  0   ;// number of parameter inputs being shown
        num_T   dd  0   ;// number of trigger inputs being shown
        num_X   dd  0   ;// number of outputs being shown

        pTrigger dd 0   ;// pointer to the currently selected trigger display

        siz POINT {}    ;// desired width and height of the object

    OSC_DIFF_DATA ENDS






;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
;//
;// object definition
;//

.DATA


DIFF_BASE_FLAGS EQU BASE_BUILDS_OWN_CONTAINER   OR  \
                    BASE_WANT_EDIT_FOCUS_MSG    OR  \
                    BASE_XLATE_DELETE           OR  \
                    BASE_WANT_POPUP_DEACTIVATE  OR  \
                    BASE_SHAPE_EFFECTS_GEOMETRY

osc_Difference OSC_CORE { diff_Ctor,diff_Dtor,diff_PrePlay,diff_Calc }
             OSC_GUI  { ,diff_SetShape,,,,
                diff_Command,diff_InitMenu,
                diff_Write,diff_AddExtraSize,
                diff_SaveUndo, diff_LoadUndo, diff_GetUnit }
             OSC_HARD { }

    ;// don't make the lines too long
    ofsPinData = SIZEOF OSC_OBJECT+(SIZEOF APIN)*40
    ofsOscData = SIZEOF OSC_OBJECT+(SIZEOF APIN)*40+(12*SAMARY_SIZE)
    oscBytes   = SIZEOF OSC_OBJECT+(SIZEOF APIN)*40+(12*SAMARY_SIZE) + SIZEOF OSC_DIFF_DATA
        
    OSC_DATA_LAYOUT {NEXT_Difference,IDB_DIFFERENCE,OFFSET popup_DIFFERENCE,DIFF_BASE_FLAGS,
        40,4,
        ofsPinData,
        ofsOscData,
        oscBytes }

    OSC_DISPLAY_LAYOUT { ,,ICON_LAYOUT(7,1,2,3)}

;// flags for osc.dwUser:

    ;// common input trigger ;// last value stored in t.dwUser

        DIFF_T_POS      equ  00000001h  ;// pos edge    ;// 0 for both
        DIFF_T_NEG      equ  00000002h  ;// neg edge    ;// ignore if pin not connected

        DIFF_T_MASK     equ 0FFFFFFFCh
        DIFF_T_TEST     equ  00000003h

        DIFF_T_GATE     equ  00000004h  ;// true if we want a gated input

    ;// step trigger  ;// last value stored in s.dwUser

        DIFF_S_POS      equ  00000010h  ;// pos edge    ;// 0 for both
        DIFF_S_NEG      equ  00000020h  ;// neg edge    ;// ignore if pin not connected
        DIFF_S_MASK     equ 0FFFFFFCFh
        DIFF_S_TEST     equ  00000030h
        DIFF_S_SHIFT    equ  4

    ;// clip level and approximation

        DIFF_CLIP_2     equ  00000000h
        DIFF_CLIP_8     equ  00001000h
        DIFF_CLIP_MASK  equ NOT DIFF_CLIP_8
        DIFF_CLIP_TEST  equ DIFF_CLIP_8
        DIFF_CLIP_SHIFT equ LOG2(DIFF_CLIP_8)

    ;// DIFF_CLIP_SHOW  equ  00002000h  ;// we want to display clipping
        DIFF_CLIP_NOW   equ  00004000h  ;// we are clipping now

        DIFF_APPROX_LIN equ  00000000h  ;// use linear pediction
        DIFF_APPROX_RK  equ  00008000h  ;// use runge kutta

    ;// i_small

        DIFF_SMALL_0    equ  00000000h
        DIFF_SMALL_1    equ  00010000h
        DIFF_SMALL_2    equ  00020000h
        DIFF_SMALL_3    equ  00030000h
        DIFF_SMALL_TEST equ  00030000h
        DIFF_SMAL_MASK  equ 0FFFCFFFFh
        DIFF_SMALL_SHIFT equ 16

    ;// xlated from abox 1

        DIFF_LAYOUT_CON equ  00100000h  ;// says that set shape should should xfer def_pheta to pheta


;// this object has a hell of a lot of pins
;// most of which will be hidden
;// the default locations as well as the object size will be reassigned
;// when the formula changes, but we need to allocate all of the these now

    ;// see diff_layout_notes for explaination

    ;// layout parameters

        DIFF_PIN_SPACING    equ 12      ;// space pins at 12 (or more)

        DIFF_MAX_WIDTH      equ 128     ;// max width of the object
        DIFF_MIN_WIDTH      equ DIFF_PIN_SPACING * 4    ;// min wdith

        DIFF_MIN_HEIGHT     equ 2*DIFF_PIN_SPACING  ;// min height
                                                    ;// there is no need for a max height

        DIFF_MAX_TEXT_WIDTH equ DIFF_MAX_WIDTH-DIFF_PIN_SPACING ;// max width before line wrap

        DIFF_TEXT_SPACING   equ DIFF_PIN_SPACING/2  ;// extra added bewteen equations

    ;// fixed pins

        ;// s, h, m, and t

        ;// upper case to indicate a 'fixed' pin
        DIFF_APIN_S equ 0
        DIFF_APIN_H equ 1
        DIFF_APIN_M equ 2
        DIFF_APIN_T equ 3   ;// index of the T pin

        APIN_init {,OFFSET sz_Step          , 's' ,, PIN_LOGIC_INPUT OR UNIT_LOGIC }    ;// input
        APIN_init {,OFFSET sz_StepSize      , 'h' ,, UNIT_VALUE }    ;// input
        APIN_init {,OFFSET sz_Damping       , 'm' ,, UNIT_PERCENT }  ;// input
        APIN_init {,OFFSET sz_InitialValue  , 't' ,, PIN_LOGIC_INPUT OR UNIT_LOGIC }

    ;// PARAMETER INPUTS A0 through A11
    ;//
    ;//     these are a fixed set of pins


        ;// upper case to indicate a pin from the fixed array

        DIFF_APIN_A equ 4   ;// index of first parameter pin
        DIFF_APIN_A_offset equ DIFF_APIN_A * SIZEOF APIN    ;// offset from start of pin table

        APIN_init {,OFFSET sz_Parameter, '5a' ,, UNIT_AUTO_UNIT }    ;// input
        APIN_init {,OFFSET sz_Parameter, '4a' ,, UNIT_AUTO_UNIT }    ;// input
        APIN_init {,OFFSET sz_Parameter, '3a' ,, UNIT_AUTO_UNIT }    ;// input
        APIN_init {,OFFSET sz_Parameter, '2a' ,, UNIT_AUTO_UNIT }    ;// input
        APIN_init {,OFFSET sz_Parameter, '1a' ,, UNIT_AUTO_UNIT }    ;// input
        APIN_init {,OFFSET sz_Parameter, '0a' ,, UNIT_AUTO_UNIT }    ;// input

        APIN_init {,OFFSET sz_Parameter, '5b' ,, UNIT_AUTO_UNIT }    ;// input
        APIN_init {,OFFSET sz_Parameter, '4b' ,, UNIT_AUTO_UNIT }    ;// input
        APIN_init {,OFFSET sz_Parameter, '3b' ,, UNIT_AUTO_UNIT }    ;// input
        APIN_init {,OFFSET sz_Parameter, '2b' ,, UNIT_AUTO_UNIT }    ;// input
        APIN_init {,OFFSET sz_Parameter, '1b' ,, UNIT_AUTO_UNIT }    ;// input
        APIN_init {,OFFSET sz_Parameter, '0b' ,, UNIT_AUTO_UNIT }    ;// input

    ;// TRIGGERED INPUTS t0 through t12
    ;//
    ;//     these are modeled as a pool of pins that are assigned as required

        ;// lower case to indicate a pin from the pool
        DIFF_APIN_t equ 16  ;// index of first triggered input
        DIFF_APIN_t_offset equ DIFF_APIN_t * SIZEOF APIN    ;// offset from start of pin table

        APIN_init {,OFFSET sz_InitialValue, '0t' ,, UNIT_AUTO_UNIT }     ;// input
        APIN_init {,OFFSET sz_InitialValue, '1t' ,, UNIT_AUTO_UNIT }     ;// input
        APIN_init {,OFFSET sz_InitialValue, '2t' ,, UNIT_AUTO_UNIT }     ;// input
        APIN_init {,OFFSET sz_InitialValue, '3t' ,, UNIT_AUTO_UNIT }     ;// input
        APIN_init {,OFFSET sz_InitialValue, '4t' ,, UNIT_AUTO_UNIT }     ;// input
        APIN_init {,OFFSET sz_InitialValue, '5t' ,, UNIT_AUTO_UNIT }     ;// input

        APIN_init {,OFFSET sz_InitialValue, '0t' ,, UNIT_AUTO_UNIT }     ;// input
        APIN_init {,OFFSET sz_InitialValue, '1t' ,, UNIT_AUTO_UNIT }     ;// input
        APIN_init {,OFFSET sz_InitialValue, '2t' ,, UNIT_AUTO_UNIT }     ;// input
        APIN_init {,OFFSET sz_InitialValue, '3t' ,, UNIT_AUTO_UNIT }     ;// input
        APIN_init {,OFFSET sz_InitialValue, '4t' ,, UNIT_AUTO_UNIT }     ;// input
        APIN_init {,OFFSET sz_InitialValue, '5t' ,, UNIT_AUTO_UNIT }     ;// input

    ;// VALUE OUTPUTS X0 through X12
    ;//
    ;//     these are also a pool of pins that are assigned as required

        ;// lower case to indicate a pin from the pool
        DIFF_APIN_x equ 28  ;// index of first X pin
        DIFF_APIN_x_offset equ DIFF_APIN_x * SIZEOF APIN    ;// offset from start of pin table

        APIN_init { ,, '0d' ,, PIN_OUTPUT OR UNIT_AUTO_UNIT }  ;// output
        APIN_init { ,, '1d' ,, PIN_OUTPUT OR UNIT_AUTO_UNIT }  ;// output
        APIN_init { ,, '2d' ,, PIN_OUTPUT OR UNIT_AUTO_UNIT }  ;// output
        APIN_init { ,, '3d' ,, PIN_OUTPUT OR UNIT_AUTO_UNIT }  ;// output
        APIN_init { ,, '4d' ,, PIN_OUTPUT OR UNIT_AUTO_UNIT }  ;// output
        APIN_init { ,, '5d' ,, PIN_OUTPUT OR UNIT_AUTO_UNIT }  ;// output

        APIN_init { ,, '0e' ,, PIN_OUTPUT OR UNIT_AUTO_UNIT }  ;// output
        APIN_init { ,, '1e' ,, PIN_OUTPUT OR UNIT_AUTO_UNIT }  ;// output
        APIN_init { ,, '2e' ,, PIN_OUTPUT OR UNIT_AUTO_UNIT }  ;// output
        APIN_init { ,, '3e' ,, PIN_OUTPUT OR UNIT_AUTO_UNIT }  ;// output
        APIN_init { ,, '4e' ,, PIN_OUTPUT OR UNIT_AUTO_UNIT }  ;// output
        APIN_init { ,, '5e' ,, PIN_OUTPUT OR UNIT_AUTO_UNIT }  ;// output

        short_name  db  'Diff Sys',0
        description db  'Approximates up to 6 differential equations. Optional initial value, step size, step trigger and damping inputs.',0
        ALIGN 4


    ;// then this keeps the dialog from tripping over itself

        diff_DialogBusy dd 0

        diff_section CRITICAL_SECTION {}    ;// this synchronizes preplay and gui compiling
        diff_context dd 0                   ;// need to store the context
        diff_section_initialized dd 0       ;// flag states we are initialized


    ;// we also have to juggle equation popups

        diff_atom       dd  0
        diff_szName db  'd_p',0
        diff_hWnd       dd  0

    ;// and store this as a real4

        diff_pin_spacing REAL4 @REAL(DIFF_PIN_SPACING)

    ;// then we get the private clipping indicator

        diff_clipping   dd  0

    ;// and an id table for the popup

        diff_t_id_table LABEL DWORD

        dd ID_DIFF_T_BOTH_EDGE
        dd ID_DIFF_T_POS_EDGE
        dd ID_DIFF_T_NEG_EDGE
        dd 0
        dd 0
        dd ID_DIFF_T_POS_GATE
        dd ID_DIFF_T_NEG_GATE

;// this is for filling in the variable table
;// it makes for neat little intilizer key
;// used in diff_Ctor

    diff_var_init db 'a5b5x4y4z4u4v4w4'
                  dd 0  ;// terminator for table


;// how files are stored and the default system
;//
;// default system, acts as a fake file
;// each record is:
;//     5 dwOrds for the variable's dwFlags
;//     a nul-terminated formula string
;//
;// there are a total of six sets

;// for a default, we'll just do a mass-sprong-dashhpot system
;// x will have a settable value
;// diff_InitPins will take care of assigning the input
;// don't forget to assign the five dwFlags in reverse order
comment ~ /*

    file storage:

        store osc.dwUser
        then six sets of differentials

            five evar.dwFlags (one for each variable)
            zero terminated formula string

*/ comment ~

;//                             dwFlags, X0 is assigned last
diff_default_system dd 0,0,0,EVAR_AVAILABLE,EVAR_AVAILABLE+DVAR_T_E+DVAR_x_TEST
                    db 'a1*x1+a0*x0',0

                    dd 0,0,0,0,0    ;// Y default
                    db 0

                    dd 0,0,0,0,0    ;// Z default
                    db 0

                    dd 0,0,0,0,0    ;// U default
                    db 0

                    dd 0,0,0,0,0    ;// V default
                    db 0

                    dd 0,0,0,0,0    ;// W default
                    db 0



.CODE
;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
;///
;///    private functions
;///

;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////


comment ~ /*

    compile and invalidate

    very complicated, break into sections

    0)  determine if any equations are dirty

    1)  build bit flags of all currently used variables
        at the same time, define the order of the equation

    2)  compile all equations that are in use
        in_use is defined as order > 0
        set the first as EQE_INIT so that all get initialized

    3)  rescan bit flags to determine if assign pins needs to be called

    4)  scan all variables and assign pins
        a)  unassign all that are not in use
        b)  take care of preassigned (index field !0 and ! 0Fh)
        c)  take care of IN_USE and not assigned (index field = 0)
        d)  take care of assign requests (index field = 0Fh) (INUSE must be on)
        e)  count each class of pins (naum_A,num_T,num_X)

    5)  synchronize pins with evars by hiding and unhiding as required

    6)  determine the dimensions of the object
    7)  reallocate the dib_container
    8)  assign default pheta's to pins
    9)  build the text to display

    1)2)3)  should be a seperate function   diff_compile
    4)5)    should be a seperate function   diff_assign_pins
    6)7)8)9)should be a seperate function   diff_build_graphics

*/ comment ~


;////////////////////////////////////////////////////////////////////
;//
;//                                 uses all registers
;//     diff_build_inuse_masks
;//
;//         ebp is the passed pointer to and OSC_DIFF_DATA structure
;//         detroys esi, edi, ebx
;//
;//         returns:
;//
;//             eax as the IN_USE mask for the variables
;//             ebx as the display mask for variables
;//             ecx as the display mask for triggers
;//             edx as the IN_USE mask for the parameters
;//

ASSUME_AND_ALIGN
diff_build_inuse_masks PROC PRIVATE

    ASSUME ebp:PTR OSC_DIFF_DATA

        lea edi, [ebp].variables.variable_table
        ASSUME edi:PTR EQU_VARIABLE     ;// edi walks all 30 variables

        mov esi, DIFF_NUM_VAR   ;// esi counts

        xor eax, eax        ;// eax will count variable inuse bits
        xor ebx, ebx        ;// ebx will count displayed variables
        xor ecx, ecx        ;// ecx will count displayed triggers
        xor edx, edx        ;// edx will count inuse parameters

    ;// scan through the variables

        .REPEAT

            .IF [edi].dwFlags & EVAR_IN_USE     ;// test the x variable in use
                inc eax
            .ENDIF
            .IF [edi].dwFlags & DVAR_x_TEST     ;// test if it is to be displayed
                inc ebx
            .ENDIF
            .IF [edi].dwFlags & DVAR_T_TEST     ;// check if trigger is to be displayed
                inc ecx
            .ENDIF

            add edi, SIZEOF EQU_VARIABLE;// iterate
            shl eax, 1
            shl ebx, 1
            shl ecx, 1

            dec esi

        .UNTIL ZERO?

    ;// the parameters are also stored consecutively

        lea edi, [ebp].variables.parameter_table
        ASSUME edi:PTR EQU_VARIABLE
        mov esi, DIFF_NUM_PARAM
        .REPEAT

            .IF [edi].dwFlags & EVAR_IN_USE
                inc edx
            .ENDIF
            add edi, SIZEOF EQU_VARIABLE
            shl edx, 1
            dec esi

        .UNTIL ZERO?

    ;// that's it

        ret

diff_build_inuse_masks ENDP
;//
;//
;//     diff_build_inuse_masks
;//
;////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////
;//
;//                         only called from diff_compile
;//     diff_assign_pins
;//
comment ~ /*
;//               verify that all pins are assigned as required
;// first scan:   in the process, count them so we can determine the object size
;//

A pins

    the model is a fixed set of 12
    no need to index, only to make sure they are displayed if the in-use flag is on

    new: if not in use, schedule for hiding

    scan through all the for_bufs, no other way to do it
    have to look for a or b and make sure the correct pin is assigned
    then undo any that are not in use
    since 'a' and 'b' only appear as variables, this is a safe test

    need to set some sort of flag to tell us which pins are used
    one way is to unassign dwUser in the APIN and pPin in the variables
    then scan through and reassign


X pins

    the model is a pool of 12 APIN's that get assigned and unassigned as required
    there is a matching index in the EQU_VARIABLE.dwFlags so we can load and store

    DIFF_EQUATION.order must be observed

    maximum variable marked as available must equal the order
    this should be maintained by the UI

    all lower variables must be marked as available

    if also marked as display

        --> if set as 0Fh
            then locate the first available apin
            un hide
            set the name
            next scan will invalidate the apin
            set the x_index

        --> if not set as 0Fh
            if pPin is unassigned (happens form the ctor)
                locate that pin
                assign pPin
                pin should not be hidden
                set the name correctly
        increment the num_x counter

    otherwise (not display)

        if pPin is assigned
            un_assign pPin
            reset x_index to zero
            ;// unconnect if connected
            hide the pin

T pins

    the model is a pool of 12 APIN's that get assigned and unassigned as required
    there is a matching index in the EQU_VARIABLE.dwFlags so we can load and store

    triggers must also be displayed as required

        DVAR_t_TEST tells us that a pin must be assigned
        t_index tells us to either assign a new one (=0Fh)
            or make sure the correct pin is assigned (<0Fh)


problem with autoassign:

    since user may change the index arbitrarily,
    we have to check that displayed pins are actually in use
    the compiler doesn't know enough to do this when there are multiple formulas
    using indexed pins

    the X pins require enforcement of the equation.order, because we're often telling
    equ_compile not to reset the variable table

    order should be set at this point ???
    so we can adjust as required ???


;// indexes to use

;// DIFF_APIN_A     index of the first parameter pin
;// DIFF_APIN_T     index of the trigger pin, the first T input is +1
;// DIFF_APIN_X     index of the first X pin for output

*/ comment ~

ASSUME_AND_ALIGN
diff_assign_pins PROC PRIVATE   ;// pObject:PTR OSC_OBJECT

    ASSUME ebp:PTR OSC_DIFF_DATA
    ASSUME esi:PTR OSC_OBJECT

    ;// stack better look like this

    ;// ret     osc     .....
    ;// 00      04

    DEBUG_IF <esi !!= [esp+4]>      ;// bad calling format

    st_osc  TEXTEQU <(DWORD PTR [esp+4])>

    DEBUG_IF <ebp!!=[esi].pData>    ;// bad calling format

    DEBUG_IF <!!diff_context>   ;// somehow we slipped through

;/////////////////////////////////////////////////////////////////////////
;//
;// P A R A M   S C A N
;//
;/////////////////////////////////////////////////////////////////////////

    ;// scan three, make sure all inuse pins are assigned
    ;// and make sure all unused are unassigned

    OSC_TO_PIN_INDEX esi, ebx, 0    ;// ebx is the reference to the first pin
                                    ;// use an offset to get the desired pin
    lea edi, [ebp].equations
    ASSUME edi:PTR DIFF_EQUATION    ;// edi walks equations

    lea esi, [ebp].variables.parameter_table
    ASSUME esi:PTR EQU_VARIABLE     ;// esi walks variables

    ASSUME edx:NOTHING  ;// jic

    mov ecx, DIFF_NUM_PARAM     ;// load number of parameters

    .REPEAT

        ;// check if this variable is in use
        mov eax, [esi].dwFlags  ;// load the flag
        test eax, EVAR_IN_USE   ;// check if used in equation
        jnz param_IN_USE        ;// jump if used in equation

    param_NOT_IN_USE:           ;// this parameter is NOT in use

        xor edx, edx                ;// clear for testing
        OR_GET_PIN [esi].pPin, edx  ;// check if variable's pPin is assigned
        jz param_scan_next_param    ;// jump if not assigned

        mov [edx].dwUser, 0     ;// unassign pin.dwUser
        mov [esi].pPin, 0       ;// unassign the variable

        jmp param_scan_next_param   ;// jump to the next parameter

    ALIGN 16
    param_IN_USE:           ;// this parameter is in use

        ;// so we check if a pin is assigned yet
        ;// if not, we assign the pin

        and eax, DVAR_a_TEST        ;// mask off all but the index
        jz param_assign_new_pin     ;// jump if not set yet

        ;// the index is assigned
        xor edx, edx                ;// check if pin is assigned
        OR_GET_PIN [esi].pPin, edx  ;// check if pin already assigned
        jnz param_scan_next_param   ;// jump if it is

    param_assign_this:          ;// jumped to from below
                                ;// eax must have the index to assign
        shr eax, DVAR_a_SHIFT - APIN_SHIFT  ;// shift index field to index
        add eax, DIFF_APIN_A_offset - SIZEOF APIN   ;// a_indexs are ONE BASED !!!
        lea edx, [ebx+eax]      ;// get pin address
        mov [edx].dwUser, esi   ;// store variable pointer in pin
        mov [esi].pPin, edx     ;// store pin pointer in variable

        jmp param_scan_next_param   ;// jump to the next parameter

    ALIGN 16
    param_assign_new_pin:   ;// pin is marked in use, but the index isn't set yet

        mov eax, DIFF_NUM_PARAM+1   ;// load number of params plus one for ONE BASED !!
        sub eax, ecx                ;// subtract the number remaining
        shl eax, DVAR_a_SHIFT       ;// shift up to an index field
        or [esi].dwFlags, eax       ;// merge into variable flags
        jmp param_assign_this       ;// jump to the asignment routine

    ALIGN 16
    param_scan_next_param:

        add esi, SIZEOF EQU_VARIABLE
        dec ecx

    .UNTIL ZERO?


;/////////////////////////////////
;//
;//     V A R I A B L E   S C A N
;//
;/////////////////////////////////

    mov ecx, DIFF_NUM_VAR           ;// ecx counts x variables

    .REPEAT

    ;// check if this variable is marked for display

        mov eax, [esi].dwFlags      ;// load the flag
        and eax, DVAR_x_TEST        ;// mask off all but x_index
        jnz var_marked_for_display  ;// jump if anything left

    var_NOT_marked_for_display:     ;// this variable is NOT marked for display

        xor edx, edx
        OR_GET_PIN [esi].pPin, edx  ;// check if pPin is assigned
        jz var_scan_check_triggers  ;// jump to the trigger testing

        mov [edx].dwUser, 0         ;// unassign pin.dwUser
        mov [esi].pPin, 0           ;// unassign the variable

        jmp var_scan_check_triggers ;// jump to the trigger testing

    var_marked_for_display:         ;// this variable is marked for display

        cmp eax, DVAR_x_TEST        ;// check if we're wanting to assign this
        jz var_locate_unused_pin    ;// jump if so

    var_NOT_assign_to_pin:  ;// should be assigned already

        cmp [esi].pPin, 0           ;// check if pPin is assigned
        jnz var_scan_check_triggers ;// jump to the trigger testing

    ;// this happens when an osc is loaded from a file
    var_assign_to_this_pin:

        ;// x_index is set, and a pin has been assigned yet

        ;// convert eax to a pin index, then locate the desired pin

        shr eax, DVAR_x_SHIFT - LOG2(SIZEOF APIN)   ;// convert to ofset
        lea edx, [ebx+eax+DIFF_APIN_x_offset - SIZEOF APIN]

        ASSUME edx:PTR APIN

        DEBUG_IF <[edx].dwUser>     ;// already assigned, now what

        mov [esi].pPin, edx                 ;// assign pin to equation
        mov (APIN PTR [edx]).dwUser, esi    ;// assign equation to pin

        push ecx    ;// needed to inface with next function

        jmp assign_var_pin_name

    ALIGN 16
    var_locate_unused_pin:  ;// we want to locate the first unused x pin

        ;// this is hit by assigning 0Fh to the x_index

        push ecx    ;// store the count
        lea edx, [ebx+DIFF_APIN_x_offset];// get address of first x output pin
        xor ecx, ecx            ;// ecx counts pins
        .REPEAT

            .IF !([edx].dwUser) ;// found one

                ;// connect variable and pin

                mov [esi].pPin, edx     ;// store pin's address in evar
                mov [edx].dwUser, esi   ;// store variable pointer in apin

                ;// build the name

                inc ecx                 ;// index is ONE BASED !!!
                shl ecx, DVAR_x_SHIFT   ;// shift index to a field
                and [esi].dwFlags, DVAR_x_MASK  ;// mask out the 'set_me' flag
                or [esi].dwFlags, ecx   ;// merge in the new index

            assign_var_pin_name:

                ;// edx must be the pin
                ;// esi must be the equation

                mov eax, 0000FFDFh      ;// mask for uppercase
                xor ecx, ecx            ;// no mask for lower case
                call build_pin_text_name    ;// build the name

                pop ecx                     ;// retrieve the count

                jmp var_scan_check_triggers ;// jump to the trigger testing

            .ENDIF

            inc ecx                     ;// iterate the counter
            add edx, SIZEOF APIN        ;// iterate to next apin
        .UNTIL ecx >= DIFF_NUM_VAR
        ;// if we get here, there are no more output pins left
        ;// UI should have disallowed this

            BOMB_TRAP   ;// ecx is still on the stack


    ;// local function

        ALIGN 16
        build_pin_text_name:

            ;// locate a font for this name

            ;// edx must be the pin
            ;// esi must be the equation

            ;// ecx must hav an OR value         ( use 00000020h for lower case )
            ;// eax must enter and an AND value, ( use 0000FFDFh for upper case )

            DEBUG_IF <eax & 0FFFF0000h> ;// improper and mask
            DEBUG_IF <ecx & 0FFFF0000h> ;// improper or mask

            push edi
            and eax, DWORD PTR [esi].textname;// load the desired lable
            push edx
            lea edi, font_pin_slist_head    ;// use the pin font
            or eax, ecx                     ;// make name lower case
            invoke font_Locate
            pop edx
            mov [edx].pFShape, edi  ;// store new name in pin
            pop edi

            retn




    ALIGN 16
    ;// t_pins use a different scheme
    ;// if the trigger type is assigned, then the t_index is the pin requested
    ;// if t_index is zero, then no pin is assigned
    ;// if t_index is 0Fh, then we want to locate a pin
    ;// if t_index is anything else, then the pin is assigned
    var_scan_check_triggers:

        ;// check if this variable is marked for display

        mov eax, [esi].dwFlags          ;// load the flag
        test eax, DVAR_T_TEST           ;// check if trigger type is assigned
        jnz trig_marked_for_display     ;// jump if value is set

    trig_NOT_marked_for_display:        ;// this trigger is NOT marked for display

        and eax, DVAR_t_TEST            ;// mask off all but index
        jz  var_scan_next_var           ;// jump to the next variable

        ;// this pin is marked for display, but not for use
        ;// so we need to un assign this triggered input

        shr eax, DVAR_t_SHIFT - APIN_SHIFT  ;// shift field to an index, t_indexes are one based !!
        lea edx, [ebx+eax+DIFF_APIN_t_offset-SIZEOF APIN]   ;// get the pin
        mov (APIN PTR [edx]).dwUser, 0  ;// unassign pin.dwUser
        and [esi].dwFlags, DVAR_t_MASK  ;// un assign the index

        jmp var_scan_next_var       ;// jump to the next variable

    ALIGN 16
    trig_marked_for_display:        ;// this trigger is marked for display

        and eax, DVAR_t_TEST        ;// check if we're wanting to assign this
        jz trig_locate_unused_pin   ;// jump if so

    trig_DONT_assign_to_pin:        ;// should be assigned already

        ;// make sure the pin is assigned as stated

        shr eax, DVAR_t_SHIFT - APIN_SHIFT  ;// shift index field to index
        lea edx, [ebx+eax+DIFF_APIN_t_offset - SIZEOF APIN] ;// t_index is ONE BASED !!!

        cmp esi, [edx].dwUser       ;// see if already correctly assigned
        je var_scan_next_var        ;// jump to the next variable

        push ecx

        ;// t_index is assigned, but pin is not
        ;// time to assign
        DEBUG_IF <[edx].dwUser> ;// requested pin is already asigned !!

        mov [edx].dwUser, esi   ;// assign equation to pin

        mov ecx, 00000020h  ;// mask for lower case
        mov eax, 0000FFFFh  ;// no mask for upper case

        call build_pin_text_name

        pop ecx

        jmp var_scan_next_var


    ALIGN 16
    trig_locate_unused_pin:     ;// we want to locate the first unused t pin

        ;// this is hit by assigning 0 to the t_index
        ;// and assigning a trigger type to the type field

        push ecx    ;// store the count
        lea edx, [ebx+DIFF_APIN_t_offset]   ;// get address of first t input pin
        ASSUME edx:PTR APIN
        xor ecx, ecx            ;// ecx counts pins
        .REPEAT

            .IF !([edx].dwUser) ;// found one

                ;// connect pin to variable

                mov [edx].dwUser, esi   ;// store variable pointer in apin

                ;// build the name

                inc ecx                 ;// t_index is ONE BASED
                shl ecx, DVAR_t_SHIFT   ;// shift index to a field
                or [esi].dwFlags, ecx   ;// merge in the new index

                ;// locate a font for this name

                mov eax, 0000FFFFh  ;// set the and value
                mov ecx, 20h        ;// set the or value

                call build_pin_text_name    ;// assign the name

                pop ecx                 ;// retrieve the count

                jmp var_scan_next_var   ;// jump to the next variable

            .ENDIF
            inc ecx                     ;// iterate the pin counter
            add edx, SIZEOF APIN        ;// iterate to next apin
        .UNTIL ecx >= DIFF_NUM_VAR
        ;// if we get here, there are no more trigger pins left
        ;// UI should have disallowed this

            BOMB_TRAP   ;// ecx is still on the stack

    ALIGN 16
    var_scan_next_var:

        ;// now we iterate until there are no more variables left

        add esi, SIZEOF EQU_VARIABLE
        dec ecx

    .UNTIL ZERO?



;////////////////////////////////////////////
;//
;//     S Y N C H R O N I Z E    S C A N
;//
;///////////////////////////////////////////
;// next scan, synchronize the pin display states
;// count the number in each class
;//
;//     for all pins
;// if dwUser is non zero, the pin should be displayed (un hidden)
;// otherwise the pin should hidden

    ;// reset the counts

        xor edi, edi            ;// edi will also index which num_variable we're on
        ASSUME edi:NOTHING
        mov [ebp].num_A, edi
        mov [ebp].num_T, edi
        mov [ebp].num_X, edi

    ;// these are not really redudant, since we optionally display them
    ;// and in_use only means the equations are using them

    GET_OSC_FROM esi, [esp+4]               ;// get the osc
    OSC_TO_PIN_INDEX esi, ebx, DIFF_APIN_A  ;// get the first param pin

    xor esi, esi    ;// esi will count each group
    ASSUME esi:NOTHING

    mov ecx, diff_context
    ASSUME ecx:PTR LIST_CONTEXT

    .REPEAT

        xor eax, eax    ;// mov eax, HINTI_PIN_HIDE     ;// assume have to hide

        .IF [ebx].dwUser                    ;// marked for display ??

            ;// this pin is being shown, or should be
            inc [ebp+edi].num_A             ;// increase the count
            inc eax ;// mov eax, HINTI_PIN_UNHIDE       ;// schedule to unhide

        .ELSEIF [ebx].pPin || [ebx].dwStatus & PIN_BUS_TEST

            ;// this pin has not yet been hidden, so we have to make room for it
            inc [ebp+edi].num_A             ;// increase the count

        .ENDIF

        xchg esi, st_osc
        xchg ecx, ebp
        invoke pin_Show, eax;// GDI_INVALIDATE_PIN eax,,ecx
        xchg esi, st_osc
        xchg ecx, ebp

        inc esi             ;// increase inner count (pins in a group)
        .IF esi >= 12       ;// end of group ?
            add edi, 4      ;// increase group count by one dword
            xor esi, esi    ;// clear inner count
        .ENDIF

        add ebx, SIZEOF APIN    ;// bump to next pin

    .UNTIL edi == 12        ;// 3 groups

    ;// that's it, all pins are assigned or unassigned, and hidden or unhidden


    ret

diff_assign_pins ENDP






;///////////////////////////////////////////////////////////////////////////////////
;//
;//                         top level initializer and updater for all thing compile
;//     diff_compile        called from set_Shape and preplay
;//
ASSUME_AND_ALIGN
diff_compile    PROC PRIVATE    uses ebp esi

        ASSUME esi:PTR OSC_OBJECT

    invoke EnterCriticalSection, OFFSET diff_section
    mov diff_context, ebp


    ;// stack looks like this
    ;//
    ;// esi=osc     ebp     ret ...
    ;// 00          04          08          0Ch     10h


    ;// 0)  determine if any equation is dirty

        OSC_TO_DATA esi, ebp, OSC_DIFF_DATA

        lea edi, [ebp].equations        ;// ebx will walk each equation
        ASSUME edi:PTR DIFF_EQUATION
        mov ecx, DIFF_NUM_DERIVATIVE    ;// ecx counts dirivatives
        .REPEAT
            cmp [edi].for_head.bDirty, 0
            jne have_to_compile
            add edi, SIZEOF DIFF_EQUATION
            dec ecx
        .UNTIL ZERO?

    ;// when we hit this, we don't have to compile

        jmp check_inuse_masks


have_to_compile:

    ;// 2) compile all six equations, set the compile init flag on the first one


        mov esi, EQE_INIT_VARIABLES + EQE_USE_INDEX ;// init flags
        mov ecx, DIFF_NUM_EQUATION
        lea edi, [ebp].equations.for_head
        ASSUME edi:PTR EQU_FORMULA_HEADER   ;// edi walks formulas
        lea ebx, [ebp].equations
        ASSUME ebx:PTR DIFF_EQUATION        ;// ebx walk differential sets

        .REPEAT

            cmp [ebx].order, 0                  ;// see if order is defined
            jz skip_compiling                   ;// skip if not

        compile_this_equation:

            mov [edi].bDirty, 1 ;// force it to compile

            push ecx                            ;// store the count
            lea edx, [ebp].variables            ;// point at variable table
            invoke equ_Compile, edi, edx, esi   ;// compile the equation
            pop ecx                             ;// restore the count
            and esi, NOT EQE_INIT_VARIABLES     ;// reset the 'first_equation' flag

        skip_compiling:

            mov [edi].bDirty, 0                 ;// set dirty as false (jic)
            add edi, SIZEOF DIFF_EQUATION       ;// iterate equation pointer
            add ebx, SIZEOF DIFF_EQUATION       ;// itterate the differential pointer
            dec ecx

        .UNTIL ZERO?

        DEBUG_IF <esi&EQE_INIT_VARIABLES>       ;// nothing was compiled !!!

check_inuse_masks:

    ;// 3) rebuild the inuse masks and compare with previously stored

        call diff_build_inuse_masks

        cmp eax, [ebp].inuse_variables
        jne have_to_assign_pins
        cmp ebx, [ebp].display_variables
        jne have_to_assign_pins
        cmp ecx, [ebp].display_triggers
        jne have_to_assign_pins
        cmp edx, [ebp].inuse_parameters
        jne have_to_assign_pins

    ;// if we hit this, our pin states are aok

        jmp check_layout

have_to_assign_pins:

    ;// store the new flags

        mov [ebp].inuse_variables, eax
        mov [ebp].display_variables, ebx
        mov [ebp].display_triggers, ecx
        mov [ebp].inuse_parameters, edx

    ;// now then, we get to the assign pins routine

        mov esi, [esp]  ;// get the object pointer

        invoke diff_assign_pins

check_layout:

    ;// check if we need to relayout the object

have_to_layout:

    IFDEF DEBUGBUILD
    mov diff_context, 0     ;// force an error if we fall through
    ENDIF
    invoke LeaveCriticalSection, OFFSET diff_section

    ret

diff_compile    ENDP

;// calculate parameters

    ;// after all that, we know:

    ;//     how many input pins there are       num_A
    ;//     how many trigger pins there are     num_T
    ;//     how many output pins there are      num_X

    ;// from that we can define the object's size



comment ~ /*

    new layout algorithm:

    AB pins are centered on the left, equally spaced.
    s h and m pins are centered on the top, fixed spacing
    T pins are centered on the bottom
    t is to the left of the T pins
    X pins are cenetered on the right and equally spaced

    for each set we determine (A for example)

        dyA     spacing in pixels
        yA      start point
        numA    count of pins

    we also determine:

        dxC, xC, numC   s h m control inputs
        dyX, yX, numX   outputs
        dxT, xT, numT   triggered inputs


    once we know the spacing, start point and count,
    we use the FPU as an iterator and call pin_ComputeDefPheta

    text: each equation must be prefixed with dXn = ...
        calculate the rect for each one, accumulating and adding pin_spacing between
        each rect.
        use successive calls to DrawTextA(...DT_CACLRECT..) to do this.
        keep track of the min and max width for each pass.

resultant formulas:

    higA = max (numA+2)*pin_spacing, MIN_HEIGHT     required height of A pins
    widC = MIN_WIDTH    required width of control pins (always the same)
    higX = max (numX+2)*pin_spacing, MIN_HEIGHT     required height of X pins
    widT = min (numT+4)*pin_spacing, MAX_WIDTH      may require squeezing
    hTxt = accumulated height of text


    wid = max( widC, widT, MIN_WIDTH )
    hig = max( higA, higX, hTxt, MIN_HEIGHT )

    dyA = pin_spacing
    yA  = ( height - dyA*(numA-1) ) / 2

    dxC = pin_spacing
    yC  = ( height - dxC*3 ) / 2

    dyX = pin_spacing
    yX  = ( height - dyX*(numX-1) ) / 2

    dxT = min(  width/(num_T+4), pin_spacing )
    xT  = ( width - dxT*(num_T-1) ) / 2


*/ comment ~

ASSUME_AND_ALIGN
diff_build_equation_string PROC PRIVATE

    ;// convert for_buf to screen displayable format
    ;// needed to be able to display using draw text

    ;// ecx must enter with the index of the variable (0=X 1=Y 2=Z 3=U 4=V 5=W )
    ;// edx must point at the start of the storage space
    ;// ebx must point at the DIFF_EQUATION to use

    ;// returns esi=length
    ;// destroys ecx, edx, eax

    ASSUME ebx:PTR DIFF_EQUATION

        add ecx, 'X'            ;// 0   0   0   X
        .IF ecx > 5Ah
            sub ecx, '[' - 'U'  ;// 0   0   0   X
        .ENDIF
        shl ecx, 8              ;// 0   0   X   0
        add ecx, [ebx].order    ;// 0   0   X   4
        add ecx, '0'
        shl ecx, 8              ;// 0   X   4   0
        add ecx, 'd'            ;// 0   X   4   d

        mov [edx], ecx      ;// store 'd4X'
        add edx, 3          ;// next 3 chars

        mov ecx, ' = '
        mov [edx], ecx      ;// store ' = '

        add edx, 3          ;// next 3 chars

        mov ecx, [ebx].for_head.pString     ;// get start of string

        ASSUME esi:NOTHING
        STRCPY edx, ecx, a, esi     ;// copy the formula

        add esi, 6                  ;// add 6 for the prefix

    ret

diff_build_equation_string ENDP




ASSUME_AND_ALIGN
diff_determine_size PROC PRIVATE uses ebp esi

    ;// determines the display size of the object

    ASSUME esi:PTR OSC_OBJECT

    ;// we'll use gdi_hDC to work this

    ;// we need storage space for strings

    sub esp, 136            ;// 128 for formula, 8 more for prefix

    ;// we need to accumulate a size

    pushd 0                 ;// bottom
    pushd DIFF_MIN_WIDTH    ;// right

    ;// then we need a rect for accumulating text

    pushd 0     ;// bottom
    pushd DIFF_MAX_TEXT_WIDTH   ;// right
    pushd 0     ;// top
    pushd 0     ;// left

    pushd 0     ;// counter

    ;// stack looks like this
    ;//
    ;// count   rect    size    string  .....   esi=osc ebp     ret
    ;// 00      04      14h     1Ch             A4      A8      AC  ...

        st_count    TEXTEQU <(DWORD PTR [esp])>
        st_rect     TEXTEQU <(RECT PTR [esp+4])>
        st_size     TEXTEQU <(POINT PTR [esp+14h])>
        st_string   TEXTEQU <[esp+1Ch]>
        st_osc      TEXTEQU <[esp+0A4h]>

        stack_size = 0A4h

    ;// text size first
    ;// for each equation with order != 0
    ;//     build a prefixed string
    ;//     determine the rect needed to display it
    ;//     accumulate the height
    ;//     keep track of minimum width
    ;// use gdi_hDC to do the work

    GDI_DC_SELECT_FONT hFont_osc

    OSC_TO_DATA esi, ebp, OSC_DIFF_DATA

    lea ebx, [ebp].equations
    ASSUME ebx:PTR DIFF_EQUATION

    .REPEAT

        .IF [ebx].order

        ;// build the prefixed string

            lea edx, st_string
            mov ecx, [esp]
            invoke diff_build_equation_string

        ;// call calc rect to determine the size

            lea edx, st_string
            lea eax, st_rect

            invoke DrawTextA, gdi_hDC, edx, esi, eax,
                DT_CALCRECT OR DT_EDITCONTROL OR DT_NOPREFIX OR DT_WORDBREAK

        ;// accumulate the height and track max width

            point_GetBR st_rect         ;// determine the size
            point_SubTL st_rect
            cmp eax, st_size.x          ;// compare width with current
            jb @F
            mov st_size.x, eax
        @@:
            add edx, DIFF_TEXT_SPACING  ;// accumulate height
            add st_size.y, edx

        ;// clear the rect for the next test

            xor eax, eax
            xor edx, edx
            point_SetTL st_rect
            mov eax, DIFF_MAX_TEXT_WIDTH
            point_SetBR st_rect

        .ENDIF

        inc st_count
        add ebx, SIZEOF DIFF_EQUATION

    .UNTIL st_count >= DIFF_NUM_EQUATION

;// now we have the size required by the text

    ;// if width is not the maximum, we calculate width based on the max number num_A, num_T

        point_Get st_size               ;// get the size

        .IF eax < DIFF_MAX_TEXT_WIDTH   ;// less than max ??

            mov eax, [ebp].num_T    ;// always use num_T + 2
            add eax, 2

            ;// since pin spacing is 12...
            lea eax, [eax+eax*2+3]      ;// determine desired width
            shl eax, 2

            cmp eax, st_size.x          ;// use text size if pin size is smaller
            ja @F
                mov eax, st_size.x
            @@:
            add eax, DIFF_PIN_SPACING   ;// always add the borderr

        .ENDIF

        add eax, 3          ;// always dword align the width
        and eax, 0FFFFFFFCh

        mov [ebp].siz.x, eax    ;// store in object

    ;//                                      num_A+1 * pin spacing
    ;// to get height, we use the maximum of num_X+1 * pin spacing and local height

        add edx, DIFF_PIN_SPACING   ;// always adjust the height

        mov eax, [ebp].num_X
        .IF eax < [ebp].num_A
            mov eax, [ebp].num_A
        .ENDIF

        .IF eax > 3

            ;// since pin spacing is 12...
            lea eax, [eax+eax*2+3]
            shl eax, 2

            .IF eax > edx
                mov edx, eax
            .ENDIF

        .ENDIF

        .IF edx < DIFF_MIN_HEIGHT       ;// enforce minimum height
            mov edx, DIFF_MIN_HEIGHT
        .ENDIF

        mov [ebp].siz.y, edx

    ;// and that should do it

        add esp, stack_size

        ret

diff_determine_size ENDP



;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
diff_layout_pins PROC PRIVATE

        ASSUME esi:PTR OSC_OBJECT

    ;// tasks:
    ;//
    ;//     layout all the assigned pins using the layout algoritm
    ;//

    ;// first three (shm) are set centered on the top from left to right

    ;// the next pin (t) we come back to

    ;// next 12 (A) are set centered on left from top to bottom

    ;// next 12 (T) are set centered on the bottom from left to right
    ;// we always include the (t) pin as the first pin, and seperate with one pin space

    ;// last 12 are set centered on the right from top to bottom


    ;// to do these we'll build a stack frame
    ;// delta and coord can be X or Y coords
    ;// we assume that num_A, num_T, and num_X are correct

        stack_size  = 8
        sub esp, stack_size

        st_delta    TEXTEQU <(DWORD PTR [esp+4])>   ;// delta to iterate coord
        st_coord    TEXTEQU <(DWORD PTR [esp])>     ;// coord we're iterating

    ;// here we go

        OSC_TO_PIN_INDEX esi, ebx, 0        ;// get first pin (s)
        OSC_TO_DATA esi, edi, OSC_DIFF_DATA

    ;// dxC = pin_spacing
    ;// xC = ( width - dxC*2 ) / 2

        fldz                    ;// Y
        fild [edi].siz.x        ;// width
        fld diff_pin_spacing    ;// dxC     width
        fmul math_2         ;// dxC*2
        fsub                    ;// width-dxC*2
        fmul math_1_2           ;// xC
        fst st_coord
        mov ecx, 3  ;// three pins

        mov eax, diff_pin_spacing
        mov st_delta, eax

        @@:
            push ecx        ;// store ecx
            invoke pin_ComputePhetaFromXY   ;// call the approximator
            .IF ![ebx].pPin && !([ebx].dwStatus & PIN_BUS_TEST)
                fst [ebx].pheta     ;// have to store pheta as well
            .ENDIF
            fstp [ebx].def_pheta    ;// store in the pin
            pop ecx                 ;// retireve ecx
            add ebx, SIZEOF APIN    ;// next pin
            dec ecx                 ;// count
            jz @F
            fldz                    ;// Y
            fld st_coord            ;// X   Y
            fadd diff_pin_spacing   ;// advance first
            fst st_coord            ;// store on stack
            jmp @B
        @@:

        add ebx, SIZEOF APIN    ;// next pin (skip the t pin)

;// dyA = pin_spacing
;// yA = ( height - dyA*(num_A-1) ) / 2

        OSC_TO_DATA esi, edi, OSC_DIFF_DATA

        fldz                ;// X
        fild [edi].num_A
        fsub math_1
        fmul diff_pin_spacing
        fisubr [edi].siz.y
        fmul math_1_2       ;// Y   X

        mov ecx, DIFF_NUM_PARAM     ;// ecx counts paramaters

        lea edx, [edi].variables.parameter_table
        ASSUME edx:PTR EQU_VARIABLE

        fst st_coord
        fxch                    ;// X   Y

        .REPEAT
            mov ebx, [edx].pPin
            .IF ebx
                push ecx
                push edx
                invoke pin_ComputePhetaFromXY
                .IF ![ebx].pPin && !([ebx].dwStatus & PIN_BUS_TEST)
                    fst [ebx].pheta     ;// have to store pheta as well
                .ENDIF
                fstp [ebx].def_pheta
                pop edx
                pop ecx

                fld st_coord
                fadd st_delta
                fst st_coord    ;// Y
                fldz            ;// X   Y

            .ENDIF
            add edx, SIZEOF EQU_VARIABLE
            dec ecx
        .UNTIL ZERO?

        fstp st
        fstp st

;// dxT = min(  width/(num_T+4), pin_spacing )
;// xT = ( width - dxT*(num_T+1) ) / 2

        OSC_TO_DATA esi, edi, OSC_DIFF_DATA

        mov eax, [edi].num_T
        fild [edi].siz.x    ;// width
        add eax, 4
        fld st              ;// width   width
        mov st_coord, eax
        fidiv st_coord      ;// dxT?    width
        xor eax, eax
        fld diff_pin_spacing
        fucom           ;// pin_spacing dxT     width
        fnstsw ax
        sahf
        .IF CARRY?
            fxch
        .ENDIF
        fstp st
        sub st_coord, 3
        fst st_delta    ;// dxT
        fimul st_coord  ;// dxT*(num_T-1)   width
        fsub
        fmul math_1_2   ;// dxT
        fst st_coord    ;// x0
        fild [edi].siz.y;// y   x0
        fxch            ;// x0  y

        ;// do the t pin

        OSC_TO_PIN_INDEX esi, ebx, DIFF_APIN_T
        push edx
        invoke pin_ComputePhetaFromXY
        pop edx
        .IF ![ebx].pPin && !([ebx].dwStatus & PIN_BUS_TEST)
            fst [ebx].pheta     ;// have to store pheta as well
        .ENDIF
        fstp [ebx].def_pheta

        OSC_TO_DATA esi, edi, OSC_DIFF_DATA
        fld st_coord
        fadd st_delta
        fild [edi].siz.y    ;// y   x0
        fxch
        fadd st_delta
        fst st_coord

        ;// do the rest of the T pins

        mov ecx, DIFF_NUM_VAR   ;// ecx will scan all the variables

        OSC_TO_PIN_INDEX esi, ebx, DIFF_APIN_t

        .REPEAT

            mov eax, [edx].dwFlags
            and eax, DVAR_t_TEST    ;// is this slated for triggered input ?
            .IF !ZERO?              ;// yes

                ;// determine the pin
                shr eax, DVAR_t_SHIFT - APIN_SHIFT
                mov ebx, esi
                lea ebx, [ebx+eax+SIZEOF OSC_OBJECT+DIFF_APIN_t_offset-SIZEOF APIN];// one based, remember ??
                push ecx
                push edx
                invoke pin_ComputePhetaFromXY
                .IF ![ebx].pPin && !([ebx].dwStatus & PIN_BUS_TEST)
                    fst [ebx].pheta     ;// have to store pheta as well
                .ENDIF
                fstp [ebx].def_pheta
                pop edx
                pop ecx
                fld st_coord
                fadd st_delta
                OSC_TO_DATA esi, edi, OSC_DIFF_DATA
                fild [edi].siz.y    ;// y   x0
                fxch
                fst st_coord

            .ENDIF
            add edx, SIZEOF EQU_VARIABLE
            dec ecx
        .UNTIL ZERO?

        fstp st
        fstp st

;// dyX = pin_spacing
;// yX = ( height - dyX*(num_X-1) ) / 2

        mov eax, diff_pin_spacing
        mov st_delta, eax

        sub edx, SIZEOF EQU_VARIABLE*DIFF_NUM_VAR   ;// t and X share the same variables

        fild [edi].num_X
        fsub math_1
        fmul diff_pin_spacing
        fisubr [edi].siz.y
        fmul math_1_2

        fst st_coord
        fild [edi].siz.x    ;// x   y0

        mov ecx, DIFF_NUM_VAR   ;// ecx will scan all the variables

        .REPEAT
            mov ebx, [edx].pPin
            .IF ebx
                push edx
                push ecx
                invoke pin_ComputePhetaFromXY
                .IF ![ebx].pPin && !([ebx].dwStatus & PIN_BUS_TEST)
                    fst [ebx].pheta     ;// have to store pheta as well
                .ENDIF
                fstp [ebx].def_pheta
                pop ecx
                pop edx
                fld st_coord        ;// Y
                fadd st_delta
                OSC_TO_DATA esi, edi, OSC_DIFF_DATA
                fst st_coord
                fild [edi].siz.x    ;// x   y
            .ENDIF
            add edx, SIZEOF EQU_VARIABLE
            dec ecx
        .UNTIL ZERO?

        fstp st
        fstp st

;// that's it

    add esp, stack_size

    ret

diff_layout_pins ENDP










ASSUME_AND_ALIGN
diff_build_text PROC PRIVATE uses ebp esi

    ASSUME esi:PTR OSC_OBJECT

    ;// we need storage space for strings

        sub esp, 136            ;// 128 for formula, 8 more for prefix

    ;// ebp will be the diff data

        OSC_TO_DATA esi, ebp, OSC_DIFF_DATA

    ;// need a rect for formatting text
    ;// we'll adjust the top to iterate each equation

        pushd [ebp].siz.y           ;// bottom (fixed)
        pushd [ebp].siz.x           ;// right (fixed)
        pushd DIFF_PIN_SPACING/2    ;// top (iterates)
        pushd DIFF_PIN_SPACING/2    ;// left (fixed)

        pushd 0     ;// counter

    ;// stack looks like this
    ;//
    ;// count   rect    string  .....   esi=osc ebp     ret
    ;// 00      04      14h             9C      A0      A4  ...

        st_count    TEXTEQU <(DWORD PTR [esp])>
        st_rect     TEXTEQU <(RECT PTR [esp+4])>
        st_string   TEXTEQU <[esp+14h]>
        st_osc      TEXTEQU <[esp+09Ch]>

        stack_size = 09Ch

    ;// adjust the right side

        sub st_rect.right, DIFF_PIN_SPACING/2

    ;// for each equation with order != 0
    ;//     build a prefixed string
    ;//     draw it
    ;//     accumulate the height
    ;// use osc.container.shape.hDC to do the work

        OSC_TO_CONTAINER esi, edi

    ;// always set the text color

        mov eax, oBmp_palette[COLOR_GROUP_GENERATORS*4]
        BGR_TO_RGB eax
        invoke SetTextColor, [edi].shape.hDC, eax

    ;// do the scan

    lea ebx, [ebp].equations
    ASSUME ebx:PTR DIFF_EQUATION

    .REPEAT

        .IF [ebx].order

            ;// build the prefixed string

                lea edx, st_string
                mov ecx, [esp]
                invoke diff_build_equation_string

            ;// call DrawText to draw it

                lea edx, st_string
                lea eax, st_rect

                invoke DrawTextA, [edi].shape.hDC, edx, esi, eax,
                    DT_NOPREFIX OR DT_WORDBREAK

            ;// accumulate the height

                add eax, DIFF_TEXT_SPACING
                add st_rect.top, eax


        .ENDIF

        inc st_count
        add ebx, SIZEOF DIFF_EQUATION

    .UNTIL st_count >= DIFF_NUM_EQUATION

    ;// and that should do it

        add esp, stack_size

        ret

diff_build_text ENDP







;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
diff_set_triggers   PROC uses ebx

    ASSUME esi:PTR OSC_OBJECT

    ;// assume that dwUser is correct
    ;// we have two trigger pins to set

    ;// step trigger

    mov eax, [esi].dwUser
    OSC_TO_PIN_INDEX esi, ebx, DIFF_APIN_S
    and eax, DIFF_S_TEST    ;// strip out extra
    shl eax, LOG2(PIN_LEVEL_POS)-LOG2(DIFF_S_POS)   ;// scoot into place for an APIN
    or eax, PIN_LOGIC_INPUT         ;// merge on logic input
    invoke pin_SetInputShape        ;// call the assigner function

    ;// common input trigger

    mov eax, [esi].dwUser
    OSC_TO_PIN_INDEX esi, ebx, DIFF_APIN_T
    and eax, DIFF_T_GATE OR DIFF_T_TEST
    shl eax, LOG2(PIN_LEVEL_POS)-LOG2(DIFF_T_POS)
    or eax, PIN_LOGIC_INPUT
    invoke pin_SetInputShape        ;// call the assigner function

    ret

diff_set_triggers   ENDP








;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
diff_EnableDialog_differential PROC STDCALL uses esi edi ebx pDiff:DWORD, cmdStart:DWORD, bOutputOK:DWORD, bTriggerOK:DWORD, bTrigger:DWORD

    ;// this function sets the dialog buttons for one differemtial

    ;// pDiff is pointer to DIFF_DIFFERENTIAL   (equation)
    ;// pVar is pointer to EQU_VARIABLE (start of table for that block)
    ;// cmdStart is first control id for that block

comment ~ /*

    for the differentials:

        if the order is not zero

            push the current order
            disbale all all higher orders
            if lower orders are in use, disable their buttons
            enable the trigger selection button
            set the display string on the button

        else

            disable all buttons in row
            disbale the show_trigger button

    push each output that is used

    if current_t_diff = current_diff

        set up the trigger correctly

*/ comment ~


        LOCAL locText:DWORD     ;// display string for setting names
        LOCAL bDerEnable:DWORD  ;// keeps track of highest in use

    ;// get the passed pointer

        mov esi, pDiff
        ASSUME esi:PTR DIFF_EQUATION

        mov bDerEnable, 1   ;// start as on

        mov edi, cmdStart

    ;// check if equation is enabled
    .IF [esi].order

        ;// push the enable button
        invoke CheckDlgButton, popup_hWnd, edi, BST_CHECKED

        ;// enable the show trigger button
        mov ecx, id_D_trigger
        add ecx, cmdStart
        invoke GetDlgItem, popup_hWnd, ecx
        invoke EnableWindow, eax, 1


        ;// see if this is the equation we're showing triggers for
        .IF bTrigger
            ;// push the 'show_trigger' button
            add edi, id_D_trigger
            invoke CheckDlgButton, popup_hWnd, edi, BST_CHECKED
        .ENDIF

        ;// scan through all the variables for this differential
        mov ebx, [esi].pVariables
        ASSUME ebx:PTR EQU_VARIABLE
        mov edi, DIFF_NUM_DERIVATIVE

        jmp @0  ;// iterate through edi's

        .REPEAT

            cmp edi, [esi].order
            jz @1
            jb @2

            ;// current edi index is above the order
            ;// so we enable the deriviative button
            ;// and disable the output button

                ;// enable the derivative button
                mov ecx, cmdStart
                add ecx, edi
                invoke GetDlgItem, popup_hWnd, ecx
                invoke EnableWindow, eax, 1

                ;// un push and disable the output button
                mov ecx, cmdStart
                add ecx, edi
                add ecx, id_D_output
                push ecx
                invoke CheckDlgButton, popup_hWnd, ecx, BST_UNCHECKED
                pop ecx
                invoke GetDlgItem, popup_hWnd, ecx
                invoke EnableWindow, eax, 0


                ;// check if this is the desired trigger display
                .IF bTrigger && edi != DIFF_NUM_DERIVATIVE - 1

                    ;// we cannot have a trigger for higher dirivatives
                    ;// and we need to set the name
                    push edi        ;// save our counter
                    push esi        ;// save the equation pointer
                    xor esi, esi    ;// set esi to disable
                    call setup_trigger_group
                    pop esi         ;// retrieve the equation pointer
                    pop edi         ;// retrieve the counter

                .ENDIF
                jmp next_variable

            ;// current edi index is equal to the order
            @1:
                ;// enable and push the derivative button
                mov ecx, cmdStart
                add ecx, edi
                invoke GetDlgItem, popup_hWnd, ecx
                invoke EnableWindow, eax, 1
                mov ecx, cmdStart
                add ecx, edi
                invoke CheckDlgButton, popup_hWnd, ecx, BST_CHECKED

                .IF bTrigger

                    .IF edi != DIFF_NUM_DERIVATIVE-1

                        ;// cannot have a trigger for the current derivative
                        push edi        ;// save our counter
                        push esi        ;// save the equation pointer
                        xor esi, esi    ;// set esi to disable
                        call setup_trigger_group
                        pop esi         ;// retrieve the equation pointer
                        pop edi         ;// retrieve the counter
                    .ENDIF

                .ENDIF

                jmp check_output_status

            ;// current edi index is below order
            @2:
                .IF !edi    ;// this is the button to enable the entire equation
                            ;// we have to be sure that there is at least one other equation

                    GET_OSC_FROM edx, popup_Object
                    OSC_TO_DATA edx, edx, OSC_DIFF_DATA
                    lea edx, [edx].equations
                    ASSUME edx:PTR DIFF_EQUATION
                    mov ecx, DIFF_NUM_EQUATION
                    xor eax, eax
                    .REPEAT
                        .IF [edx].order
                            inc eax
                        .ENDIF
                        add edx, SIZEOF DIFF_EQUATION
                        dec ecx
                    .UNTIL ZERO?
                    .IF eax<2
                        mov bDerEnable, 0
                    .ENDIF
                .ENDIF
                .IF [ebx].dwFlags & EVAR_IN_USE
                    mov bDerEnable, 0   ;// reset the derivative enable button
                .ENDIF
                mov ecx, cmdStart
                add ecx, edi
                invoke GetDlgItem, popup_hWnd, ecx
                invoke EnableWindow, eax, bDerEnable

                ;// check if we are showing triggers
                .IF bTrigger

                    ;// we can trigger this pin,
                    ;// so we set the name and enable all four buttons
                    push edi        ;// save our counter
                    push esi        ;// save the equation pointer
                    mov esi, bTriggerOK ;// set esi to enable
                    call setup_trigger_group
                    pop esi         ;// retrieve the equation pointer
                    pop edi         ;// retrieve the counter

                .ENDIF

            check_output_status:

                ;// if we get here, we have to enable the output button

                ;// check if button is tagged for output
                ;// if so push and enable the button
                ;// if not, use the passed bOutputOK flag
                ;// that way we can turn outpts off, but not on

                ;// then check if it's tagged for output
                mov ecx, cmdStart
                mov eax, DVAR_x_TEST
                add ecx, edi
                add ecx, id_D_output
                and eax, [ebx].dwFlags
                push ecx
                .IF !ZERO?      ;// this variable is tagged for output
                                ;// push the output button
                    invoke GetDlgItem, popup_hWnd, ecx
                    invoke EnableWindow, eax, 1
                    pop ecx
                    invoke CheckDlgButton, popup_hWnd, ecx, BST_CHECKED

                .ELSE   ;// variable not tagged for output
                        ;// try to enable just the same

                    invoke CheckDlgButton, popup_hWnd, ecx, BST_UNCHECKED
                    pop ecx
                    invoke GetDlgItem, popup_hWnd, ecx
                    invoke EnableWindow, eax, bOutputOK

                .ENDIF

        next_variable:

            add ebx, SIZEOF EQU_VARIABLE

        @0: dec edi

        .UNTIL SIGN?

        ;// enable the formula button
        ;// set the string correctly

        mov ecx, cmdStart
        add ecx, id_D_equation
        invoke GetDlgItem, popup_hWnd, ecx
        mov ebx, eax
        invoke EnableWindow, ebx, 1
        invoke SetWindowTextA, ebx, [esi].for_head.pString

    .ELSE   ;// equation is not enabled

        ;// disable and uncheck the 4 deriviative buttons

        mov ebx, DIFF_NUM_DERIVATIVE
        .REPEAT
            inc edi
            invoke CheckDlgButton, popup_hWnd, edi, BST_UNCHECKED
            invoke GetDlgItem, popup_hWnd, edi
            invoke EnableWindow, eax, 0
            dec ebx
        .UNTIL ZERO?

        ;// set the equation display text to empty

        invoke GetDlgItem, popup_hWnd, edi
        mov ebx, eax
        invoke SetWindowTextA, ebx, ADDR [esi].order
        invoke EnableWindow, ebx, 0

        ;// disable and uncheck the five output buttons

        mov ebx, DIFF_NUM_DERIVATIVE + 1
        .REPEAT
            inc edi
            invoke CheckDlgButton, popup_hWnd, edi, BST_UNCHECKED
            invoke GetDlgItem, popup_hWnd, edi
            invoke EnableWindow, eax, 0
            dec ebx
        .UNTIL ZERO?

        ;// disable the show trigger button

        invoke GetDlgItem, popup_hWnd, edi
        invoke EnableWindow, eax, 0

    .ENDIF

        ;// that's it

        ret

;//////////////////////////////////////////////////////////////////////////////
;//
;//     local functions

setup_trigger_group:

    ;// this local function sets the trigger names
    ;// and enables or disables the four buttons

    ;// edi must be the index to the variable
    ;// esi must be set to one or zero to enable or disable
    ;// ebx must be set to equ_variable to use as the name

    ;// consumes edi and esi

    ;// get the cmd id of the button group we're going to set
    shl edi, 2              ;// multiply by four
    add edi, ID_DIFF_TRIG   ;// add on id of first button

    ASSUME ebx:PTR EQU_VARIABLE

    ;// determine the name for the button

    movzx eax, WORD PTR [ebx].textname  ;// get name from variable
    and eax, 0FFFFFFDFh     ;// make upper case
    ;// shl eax, 8          ;// stuff in a new letter
    ;// or eax, 't'         ;// tack on a t
    mov locText, eax    ;// store here

    ;// set the name of the button

    invoke GetDlgItem, popup_hWnd, edi
    mov ecx, eax
    invoke SetWindowTextA, ecx, ADDR locText


;// if the group is going to be enabled (esi != 0)
;// then we enable first, then check the button state
;// if the trigger is on, then we enble the other three, and press one of them
;// if the trigger is off, we unpress all three, then disable

;// if the group is going to be disabled
;// we unpress the buttons, and then disable

    .IF esi         ;// we're enabling this group

        ;// enable the group button

        invoke GetDlgItem, popup_hWnd, edi
        invoke EnableWindow, eax, esi

        ;// check if we're on or off

        mov eax, DVAR_T_TEST
        and eax, [ebx].dwFlags
        .IF !ZERO?              ;// this trigger group is currently on

            push eax

        setup_group:

            ;// push the group button
            invoke CheckDlgButton, popup_hWnd, edi, 1

            ;// enable and un press the sub group
            add edi, 3
            invoke GetDlgItem, popup_hWnd, edi
            invoke EnableWindow, eax, 1
            invoke CheckDlgButton, popup_hWnd, edi, 0
            dec edi
            invoke GetDlgItem, popup_hWnd, edi
            invoke EnableWindow, eax, 1
            invoke CheckDlgButton, popup_hWnd, edi, 0
            dec edi
            invoke GetDlgItem, popup_hWnd, edi
            invoke EnableWindow, eax, 1
            invoke CheckDlgButton, popup_hWnd, edi, 0
            dec edi

            ;// press the correct group button
            pop eax
            shr eax, DVAR_T_SHIFT
            add edi, eax
            invoke CheckDlgButton, popup_hWnd, edi, 1

        .ELSE   ;// this trigger group is currently OFF

            ;// enable and uncheck the group button
            invoke CheckDlgButton, popup_hWnd, edi, 0
            invoke GetDlgItem, popup_hWnd, edi
            invoke EnableWindow, eax, 1
            inc edi

            ;// then uncheck and disable the remaining three
            invoke CheckDlgButton, popup_hWnd, edi, 0
            invoke GetDlgItem, popup_hWnd, edi
            invoke EnableWindow, eax, 0
            inc edi
            invoke CheckDlgButton, popup_hWnd, edi, 0
            invoke GetDlgItem, popup_hWnd, edi
            invoke EnableWindow, eax, 0
            inc edi
            invoke CheckDlgButton, popup_hWnd, edi, 0
            invoke GetDlgItem, popup_hWnd, edi
            invoke EnableWindow, eax, 0

        .ENDIF

    .ELSE   ;// this trigger group should be disabled
            ;// uncheck and disable all four buttons

;// need to account for: allowing a button to be shut off when the out put is at it's max
;// this means that the button is pressed, by we want to disable it
;// this is different from disabling because the the variable no longer exists

;// hint: the only reason esi would be zero is if there are no more triggers available
;// so if the variable is on now, we want to leave it on

        ;// check if we're on or off

        mov eax, DVAR_T_TEST
        and eax, [ebx].dwFlags
        .IF !ZERO?              ;// this trigger group is currently on

            push eax    ;// save eax
            invoke GetDlgItem, popup_hWnd, edi
            invoke EnableWindow, eax, 1
            jmp setup_group

        .ELSE       ;// this group is currently off, so we disable it

            invoke CheckDlgButton, popup_hWnd, edi, 0   ;// group button
            invoke GetDlgItem, popup_hWnd, edi
            invoke EnableWindow, eax, 0
            inc edi
            invoke CheckDlgButton, popup_hWnd, edi, 0   ;// =
            invoke GetDlgItem, popup_hWnd, edi
            invoke EnableWindow, eax, 0
            inc edi
            invoke CheckDlgButton, popup_hWnd, edi, 0   ;// +=
            invoke GetDlgItem, popup_hWnd, edi
            invoke EnableWindow, eax, 0
            inc edi
            invoke CheckDlgButton, popup_hWnd, edi, 0   ;// *=
            invoke GetDlgItem, popup_hWnd, edi
            invoke EnableWindow, eax, 0

        .ENDIF

    .ENDIF

    retn

diff_EnableDialog_differential ENDP




;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////



ASSUME_AND_ALIGN
diff_UpdateDialog_differentials PROC STDCALL uses esi edi pObject:DWORD

    ;// this makes sure the dialog's equations are displayed correctly

    LOCAL bOutputOK:DWORD   ;// set true if less than 12 outputs
    LOCAL bTriggerOK:DWORD  ;// set true if less than 12 triggers
    LOCAL pTrigger:DWORD    ;// address of current trigger display

    GET_OSC ebx
    OSC_TO_DATA ebx, ebx, OSC_DIFF_DATA
    mov eax, [ebx].pTrigger
    mov pTrigger, eax

    ;// locate the first used equation and set the
    ;// pTrigger pointer to selected trigger

    lea esi, [ebx].equations
    ASSUME esi:PTR DIFF_EQUATION
    mov ecx, DIFF_NUM_EQUATION
    .REPEAT
        .IF [esi].order
            .IF !pTrigger
                mov [ebx].pTrigger, esi
                mov pTrigger, esi
            .ENDIF
            jmp scan_differentials
        .ENDIF
        add esi, SIZEOF DIFF_EQUATION
    .UNTILCXZ

    ;// if we get here, there are no equations

        BOMB_TRAP   ;// this shouldn't happen

scan_differentials:

    ;// check if there are too many triggers
    ;// check if there are too many output

    .IF [ebx].num_T < 12
        mov bTriggerOK, 1   ;// ok to enable trigger buttons
    .ELSE
        mov bTriggerOK, 0
    .ENDIF

    .IF [ebx].num_X < 12
        mov bOutputOK, 1    ;// ok to enable output buttons
    .ELSE
        mov bOutputOK, 0
    .ENDIF

    ;// scan through all the equtions and have
    ;// diff_EnableDialog_differential enable as required

    lea esi, [ebx].equations
    mov edi, ID_DIFF_DX
    mov ecx, DIFF_NUM_EQUATION

    .REPEAT
        push ecx
        xor ecx, ecx
        cmp pTrigger, esi
        setz cl
        invoke diff_EnableDialog_differential, esi, edi, bOutputOK, bTriggerOK, ecx
        pop ecx
        add esi, SIZEOF DIFF_EQUATION
        add edi, id_DIFF_block_size
    .UNTILCXZ


    ;// now we do second scan to enforce the existance of at least ONE equation

    mov edi, ID_DIFF_DX ;// edi scans differential ID's
    xor ebx, ebx        ;// ebx counts the number that are pushed
    xor esi, esi        ;// esi tracks the last pushed button

    .REPEAT

        invoke IsDlgButtonChecked, popup_hWnd, edi
        .IF eax == BST_CHECKED
            mov esi, edi
            inc ebx
        .ENDIF

        add edi, id_DIFF_block_size

    .UNTIL edi >= ID_DIFF_TRIG

    .IF ebx == 1

        invoke GetDlgItem, popup_hWnd, esi
        invoke EnableWindow, eax, 0

    .ENDIF

    ret

diff_UpdateDialog_differentials ENDP

ASSUME_AND_ALIGN
diff_launch_editor PROC

    sub esp, SIZEOF RECT
    st_rect TEXTEQU <(RECT PTR [esp])>

    ASSUME esi:PTR OSC_OBJECT

    ;//
    ;// call up the editor for this equation
    ;//

    ;// define the display rectangle

        invoke GetWindowRect, popup_hWnd, esp
        add st_rect.top, 32

        lea ebx, popup_EQUATION
        ASSUME ebx:PTR POPUP_HEADER

        mov eax, [ebx].siz.x
        mov edx, [ebx].siz.y
        add edx, POPUP_HELP_HEIGHT

        add eax, st_rect.left
        add edx, st_rect.top    ;// adjust for the status

        mov ecx, esp

        mov st_rect.right, eax
        mov st_rect.bottom, edx

        invoke AdjustWindowRectEx, ecx, POPUP_STYLE, 0, POPUP_STYLE_EX

        mov eax, st_rect.left
        mov edx, st_rect.top
        sub st_rect.right, eax
        sub st_rect.bottom, edx

    ;// create a new popup_window

        mov ecx, esp
        ASSUME ecx:PTR RECT

        invoke CreateWindowExA,
            POPUP_STYLE_EX,
            diff_atom,
            0,
            POPUP_STYLE,
            [ecx].left, [ecx].top,
            [ecx].right, [ecx].bottom,
            popup_hWnd, 0, hInstance, 0

        mov diff_hWnd, eax

    ;// initialize the window with the controls from osc_Equation

        EXTERNDEF equ_sz_desription:BYTE    ;// defined in abox_equation.asm
        invoke popup_BuildControls, eax, ebx, OFFSET equ_sz_desription, 0   ;// use help, two lines

    ;// initialize an equation edit object

        GET_OSC_FROM ecx, popup_Object
        OSC_TO_DATA ecx, ecx, OSC_DIFF_DATA
        lea ecx, [ecx].variables

        invoke equ_InitDialog, diff_hWnd, esi,
            edi, ecx, EQE_USE_INDEX + EQE_NO_PRESETS

    ;// then show the new window

        mov ecx, esp
        ASSUME ecx:PTR RECT

        invoke SetWindowPos, diff_hWnd, popup_hWnd,
            [ecx].left, [ecx].top, [ecx].right, [ecx].bottom,
            SWP_SHOWWINDOW + SWP_NOSIZE + SWP_NOMOVE ;// + SWP_FRAMECHANGED

    ;// clean up the stack

        add esp, SIZEOF RECT

    ;//invoke SetFocus, diff_hWnd

    ;//invoke SetActiveWindow, diff_hWnd

    ;// set a flag to cancel our deactivate ??
    ;// set a flag to route commands to the equation builder

        ret

diff_launch_editor ENDP




;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;//
;//
;//     osc object functions
;//



;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
ASSUME_AND_ALIGN

diff_Ctor PROC

    diff_kludge_ctor PROTO STDCALL pObject:ptr OSC_OBJECT, pFile:PTR FILE_OSC, bFileHeader:DWORD
    invoke diff_kludge_ctor, esi, ebx, edx

    ret

diff_Ctor ENDP

diff_kludge_ctor PROC STDCALL uses esi edi pObject:PTR OSC_OBJECT, pFile:PTR FILE_OSC, bFileHeader:DWORD

        LOCAL i_small:DWORD

    ;// make sure the critcal section is initialized
    .IF !diff_section_initialized

        invoke InitializeCriticalSection, OFFSET diff_section
        inc diff_section_initialized

    .ENDIF

    ;// get i_small from osc.dwUser

        GET_OSC ebx
        mov eax, [ebx].dwUser       ;// get i_small
        and eax, DIFF_SMALL_TEST    ;// prepare it
        shr eax, DIFF_SMALL_SHIFT
        mov i_small, eax            ;// store locally

    ;// initalize our local data

        OSC_TO_DATA ebx, ebx, OSC_DIFF_DATA

    ;// define the tokens and labels in the variable table
    ;// these are stored in reverse order
    ;// paramaters are always available
    ;// state variables default to not available

        lea edi, [ebx].variables
        ASSUME edi:PTR DIFF_VARIABLES
        mov [edi].var_head.num_var, DIFF_NUM_VAR + DIFF_NUM_PARAM   ;// store the number of variables
        mov [edi].var_head.tot_num, DIFF_TOT_NUM    ;// store the total size of the table

        lea edi, [edi].parameter_table  ;// parameters come first
        ASSUME edi:PTR EQU_VARIABLE     ;// edi will walk varaiables

        lea esi, diff_var_init      ;// source for initializer data

        mov ecx, EVAR_AVAILABLE     ;// ecx sets the evar_available flag
        mov edx, 7800h  ;// 'x'0    ;// edx will iterate token name
        jmp @F

        .WHILE ax                   ;// ax iterates text names BACKWARDS !!!
            .IF al=='x'             ;// check if it's time to change the available flag
                xor ecx, ecx        ;// ecx sets the evar_available flag
            .ENDIF
            .REPEAT                 ;// setup this variable
                mov WORD PTR [edi].textname, ax ;// store the text name
                mov [edi].token, dx             ;// store the token name
                mov [edi].dwFlags, ecx          ;// store the available flag
                dec ah                          ;// decrease ah (index number)
                inc dx                          ;// increase token name
                add edi, SIZEOF EQU_VARIABLE
            .UNTIL ah=='/'  ;// loop until ax isn't an indexed name anymore
        @@: lodsw           ;// load the next text name and count
        .ENDW           ;// iterate until nul terminator

    ;// initialize all six equations
    ;// and finish the evar table

        GET_OSC ebx
        OSC_TO_DATA ebx, ebx, OSC_DIFF_DATA

        lea edi, [ebx].equations
        lea edx, [ebx].variables.variable_table

        ASSUME edi:PTR DIFF_EQUATION    ;// edi walks formulas
        ASSUME edx:PTR EQU_VARIABLE     ;// edx walks variables
        mov ecx, DIFF_NUM_EQUATION  ;// ecx counts equations

    ;// check if we're being loaded from a file

        .IF bFileHeader                 ;// we are being loaded from a file
            mov esi, pFile
            add esi, SIZEOF FILE_OSC+4  ;// zip to first param block
        .ELSE                           ;// dword user is already loaded
            GET_OSC eax
        ;// or [eax].dwUser, DIFF_CLIP_SHOW
            lea esi, diff_default_system
        .ENDIF

    ;// esi now points at an initialization structure
    ;// edi points at the equation(s) to initialize

        @0: push edi    ;// store start of this equation
            push ecx    ;// store equation count

            ;ABOX242 -- AJT -- Using Virtual Protect to allow dynamicly generated code
            .IF pfVirtualProtect ;// does it even exist? if it does, then call it
            push edx ;// need to save this ... clumsy andy clucmsy
                pushd 0                 ;// return val for lpOldProtect
                push esp                ;// ptr to OldProtect
                pushd 40h               ;// PAGE_EXECUTE_READWRITE
                pushd DIFF_NUM_EXE      ;// dwSize
                lea eax, [edi].exe_buf  
                push eax                ;// lpAddress
                call pfVirtualProtect
                add esp, 4 ;-- not much we can do here ...
            pop edx
            .ENDIF
            
            
            ;// set up the formula header
            mov [edi].for_head.f_len_max, DIFF_NUM_FOR
            mov [edi].for_head.d_len_max, DIFF_NUM_DIS
            mov [edi].for_head.e_len_max, DIFF_NUM_EXE
            mov eax, i_small
            mov [edi].for_head.i_small, eax
            mov [edi].for_head.bDirty, 1
            mov [edi].pVariables, edx   ;// store the variable pointer
            
            ;// load the 5 evar dwFlags
            ;// and point evar.value it the correct cur_value slot
            lea ebx, [edi].cur_value        ;// load pointer to current value
            mov ecx, DIFF_NUM_DERIVATIVE    ;// ecx counts
        @1: lodsd                           ;// load the flag from file
            mov [edx].dwFlags, eax          ;// store in variable
            mov [edx].value, ebx            ;// store the pointer to cur_value
            add edx, SIZEOF EQU_VARIABLE    ;// iterate the variable
            add ebx, 4                      ;// point at next cur value
            loop @1

            ;// load the formula
            lea edi, [edi].for_buf  ;// edi will walk the for buf
            xor eax, eax            ;// clear to prevent CPU big-small problem
        @2: lodsb                   ;// load char from file
            or al, al               ;// check for nul terminator
            stosb                   ;// store in for_buf
            jnz @2                  ;// loop until found

            ;// iterate this thing
            pop ecx             ;// retrieve equation count
            pop edi             ;// retrieve start of this equation
            add edi, SIZEOF DIFF_EQUATION   ;// iterate to next equation
            loop @0

    ;// determine the order of the six equations
    ;// them from here on out, it will be a maintained variable

        GET_OSC esi
        OSC_TO_DATA esi, esi, OSC_DIFF_DATA

        lea edi, [esi].variables.variable_table
        ASSUME edi:PTR EQU_VARIABLE     ;// edi walks all 30 variables
        lea ebx, [esi].equations        ;// ebx points at each equation
        ASSUME ebx:PTR DIFF_EQUATION
        xor ecx, ecx                    ;// ecx will count a number of things

        xor eax, eax                    ;// eax is a temp register
        mov ch, DIFF_NUM_EQUATION       ;// ch count equations

        .REPEAT                         ;// outter loop
            xor edx, edx                ;// accumulates the order of each set
            mov cl, DIFF_NUM_DERIVATIVE ;// cl count variables in a set
            .REPEAT                         ;// inner loop
                mov eax, [edi].dwFlags      ;// load the flags
                bt eax, LOG2(EVAR_AVAILABLE);// count the order
                adc edx, 0                  ;// accumulate
                add edi, SIZEOF EQU_VARIABLE;// iterate
                dec cl
            .UNTIL ZERO?
            mov [ebx].order, edx        ;// store the order
            add ebx, SIZEOF DIFF_EQUATION
            dec ch                      ;// decrease equation count
        .UNTIL ZERO?


;// call diff_build_inuse_masks and store in data struct
;// these can then be maintained



    ;// that should be it

        ret

diff_kludge_ctor ENDP


ASSUME_AND_ALIGN
diff_Dtor PROC ;// STDCALL pObject:DWORD

    ASSUME esi:PTR OSC_OBJECT
    mov eax, [esi].pContainer

    .IF eax
        invoke dib_Free,eax
    .ENDIF

    ret

diff_Dtor ENDP



;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////

;////////////////////////////////////////////////////////////////////
;//
;//
;//     diff_SetShape
;//
ASSUME_AND_ALIGN
diff_SetShape PROC  ;// STDCALL uses esi edi pObject:PTR OSC_OBJECT

    ASSUME esi:PTR OSC_OBJECT
    ASSUME edi:PTR OSC_BASE

comment ~ /*


    tasks:

        compile equation and assign all the pins
        determine size of object
        make sure a dib is assigned
        fill in the text shape
        set pin positions

        exit to osc_SetShape

*/ comment ~

    push esi
    push edi
    push ebx

    invoke diff_compile             ;// always call compile

    invoke diff_determine_size      ;// always determine the desired size

    OSC_TO_DATA esi, edi, OSC_DIFF_DATA
    OSC_TO_CONTAINER esi, ebx, NOERROR

    .IF !ebx    ;// allocating for the first time

        invoke dib_Reallocate, DIB_ALLOCATE_INTER, [edi].siz.x, [edi].siz.y
        mov [esi].pContainer, eax
        mov ebx, eax

        invoke SelectObject, [ebx].shape.hDC, hFont_osc
        invoke SetTextColor, [ebx].shape.hDC, COLOR_OSC_TEXT
        invoke SetBkMode, [ebx].shape.hDC, TRANSPARENT

        mov eax, [ebx].shape.pSource
        mov [esi].pSource, eax

    .ELSE       ;// see if we need to reallocate

        point_Get [edi].siz
        .IF eax != [ebx].shape.siz.x    ||  \
            edx != [ebx].shape.siz.y

            invoke dib_Reallocate, ebx, eax, edx

            mov eax, [ebx].shape.pSource
            mov [esi].pSource, eax

        .ENDIF

    .ENDIF

    ;// always erase the rect and draw a border

        mov edx, F_COLOR_GROUP_GENERATORS
        mov eax, F_COLOR_GROUP_GENERATORS + F_COLOR_GROUP_LAST - 01010101h
        invoke dib_FillAndFrame

    ;// build the text graphics

        invoke diff_build_text

    ;// now we layout the pins

        invoke diff_layout_pins

    ;// set the trigger shapes

        invoke diff_set_triggers

    ;// lastly, we check if DIFF_LAYOUT_CON is on

        .IF [esi].dwUser & DIFF_LAYOUT_CON

            ITERATE_PINS

                .IF [ebx].pPin || [ebx].dwStatus & PIN_BUS_TEST

                    mov eax, [ebx].def_pheta
                    mov [ebx].pheta, eax

                .ENDIF

            PINS_ITERATE

            and [esi].dwUser, NOT DIFF_LAYOUT_CON

        .ENDIF

    ;// and exit to osc_SetShape

        pop ebx
        pop edi
        pop esi

        jmp osc_SetShape



diff_SetShape ENDP

;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////







;////////////////////////////////////////////////////////////////////
;//
;//
;//     diff_InitMenu
;//

ASSUME_AND_ALIGN
diff_InitMenu PROC  uses edi    ;// STDCALL uses esi edi pObject:PTR OSC_OBJECT

    ASSUME esi:PTR OSC_OBJECT

;// make sure buttons are enabled and disabled as required

    mov edi, [esi].dwUser

;// step trigger

    .IF edi & DIFF_S_TEST
        .IF edi & DIFF_S_POS
            mov ecx, ID_DIFF_S_POS
        .ELSE
            mov ecx, ID_DIFF_S_NEG
        .ENDIF
    .ELSE
        mov ecx, ID_DIFF_S_BOTH
    .ENDIF
    invoke CheckDlgButton, popup_hWnd, ecx, 1

;// clipping

    .IF     edi & DIFF_CLIP_8
        mov ecx, ID_DIFF_CLIP_8
    .ELSE   ;//IF   esi & DIFF_CLIP_1
        mov ecx, ID_DIFF_CLIP_2
    .ENDIF
    invoke CheckDlgButton, popup_hWnd, ecx, 1

;// .IF edi & DIFF_CLIP_SHOW
;//     invoke CheckDlgButton, popup_hWnd, ID_DIFF_CLIP_SHOW, 1
;// .ENDIF

;// approximation

    mov ecx, ID_DIFF_APPROX_LIN
    .IF edi & DIFF_APPROX_RK
        mov ecx, ID_DIFF_APPROX_RK
    .ENDIF
    invoke CheckDlgButton, popup_hWnd, ecx, 1

;// trigger type and mode

    mov ecx, edi
    and ecx, DIFF_T_TEST OR DIFF_T_GATE
    mov ecx, diff_t_id_table[ecx*4]
    invoke CheckDlgButton, popup_hWnd, ecx, 1

;// differentials

    ;// best to relagate this to another function
    ;// so it can be called from diff_Command

    ;// reset the pTrigger to zero
    OSC_TO_DATA esi, edi, OSC_DIFF_DATA
    mov [edi].pTrigger, 0

    ;// call the function right below
    invoke diff_UpdateDialog_differentials, esi

;// return 0 so the menu doesn't get resized

    xor eax, eax    ;//int 3

    ret

diff_InitMenu ENDP




;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
diff_Command PROC

    ASSUME esi:PTR OSC_OBJECT
    ASSUME edi:PTR OSC_BASE
    ASSUME ebp:PTR LIST_CONTEXT

    ;// eax = command ID

.IF diff_hWnd       ;// check if equation editor is active

    .IF eax == OSC_COMMAND_POPUP_DEACTIVATE

DEBUG_MESSAGE <diff_Command__dif_hWnd__OSC_COMMAND_POPUP_DEACTIVATE>

        ;// ecx has handle of window getting the focus

        mov eax, POPUP_CLOSE
        .IF ecx == diff_hWnd
            mov eax, POPUP_IGNORE
        .ENDIF

    .ENDIF


;// equation editor is not active

.ELSEIF eax == OSC_COMMAND_POPUP_DEACTIVATE

DEBUG_MESSAGE <diff_Command__not_dif_hWnd__OSC_COMMAND_POPUP_DEACTIVATE>

    mov eax, POPUP_CLOSE

.ELSE

    .IF eax < ID_DIFF_BASE
        jmp osc_Command
    .ENDIF

    .IF eax >= ID_DIFF_LAST
        jmp osc_Command
    .ENDIF

    ;// a big big mess
    ;// these commands are parsed in order
    ;// see abox_objects.inc for definitions

    push edi
    push ebx

    mov edi, [esi].dwUser

    .IF eax < ID_DIFF_CLIP
    ;// new step trigger type

        sub eax, ID_DIFF_S      ;// subtract out command base
        and edi, DIFF_S_MASK    ;// mask out extra
        shl eax, DIFF_S_SHIFT   ;// move into place
        or edi, eax             ;// merge into dwUser
        mov [esi].dwUser, edi   ;// store dwUser

        invoke diff_set_triggers    ;// we do need this function after all

        mov eax, POPUP_SET_DIRTY

    .ELSEIF eax < ID_DIFF_T
    ;// new clip type or show or approximation

        .IF eax <= ID_DIFF_CLIP_8

            sub eax, ID_DIFF_CLIP
            and edi, DIFF_CLIP_MASK
            shl eax, DIFF_CLIP_SHIFT
            or edi, eax

        .ELSEIF eax == ID_DIFF_APPROX_LIN

            BITR edi, DIFF_APPROX_RK

        .ELSEIF eax == ID_DIFF_APPROX_RK

            BITS edi, DIFF_APPROX_RK

        .ENDIF

        mov [esi].dwUser, edi
        mov eax, POPUP_SET_DIRTY

    .ELSEIF eax < ID_DIFF_D
    ;// new trigger type or mode

        .IF     eax == ID_DIFF_T_BOTH_EDGE
            BITR edi, DIFF_T_GATE
            BITR edi, DIFF_T_POS
            BITR edi, DIFF_T_NEG
        .ELSEIF eax == ID_DIFF_T_POS_EDGE
            BITR edi, DIFF_T_GATE
            BITS edi, DIFF_T_POS
            BITR edi, DIFF_T_NEG
        .ELSEIF eax == ID_DIFF_T_NEG_EDGE
            BITR edi, DIFF_T_GATE
            BITR edi, DIFF_T_POS
            BITS edi, DIFF_T_NEG
        .ELSEIF eax == ID_DIFF_T_POS_GATE
            BITS edi, DIFF_T_GATE
            BITS edi, DIFF_T_POS
            BITR edi, DIFF_T_NEG
        .ELSEIF eax == ID_DIFF_T_NEG_GATE
            BITS edi, DIFF_T_GATE
            BITR edi, DIFF_T_POS
            BITS edi, DIFF_T_NEG
        .ENDIF

        mov [esi].dwUser, edi

        invoke diff_set_triggers

        mov eax, POPUP_SET_DIRTY + POPUP_REDRAW_OBJECT

    .ELSEIF eax < ID_DIFF_TRIG
    ;// one of the differential groups

        OSC_TO_DATA esi, ebx, OSC_DIFF_DATA

        ;// extract the group and command index
        sub eax, ID_DIFF_D  ;// strip out the command offset
        mov ecx, eax        ;// store in ecx
        mov edx, SIZEOF DIFF_EQUATION   ;// need to do this anyways
        and ecx, 0Fh    ;// ecx is now the command ID
        shr eax, 4      ;// eax is now the EQUATION's index
        mul edx         ;// eax is now the EQUATIONS's offset
        lea edi, [ebx+eax].equations    ;// edi is now a pointer to DIFF_EQUATION
        ASSUME edi:PTR DIFF_EQUATION

        .IF ecx     == id_D_order
        ;// wanting to select or deselect a differential

            ;// if select
            ;//     set a default equation  ='0'
            ;//     set order to 1
            ;//   call enable dialog after compiling the equation

            .IF [edi].order
            ;// wanting to turn this off

                mov [edi].order, 0  ;// reset the order

                .IF [ebx].pTrigger == edi   ;// check if this the trigger we're displaying
                    mov [ebx].pTrigger, 0   ;// force update_dialog to choose a new one
                .ENDIF

                mov ecx, DIFF_NUM_DERIVATIVE
                mov edi, [edi].pVariables
                .REPEAT
                    ;// reset the AVAILABLE flag
                    and (EQU_VARIABLE PTR [edi]).dwFlags, DVAR_T_MASK AND DVAR_x_MASK AND (NOT EVAR_AVAILABLE)
                    add edi, SIZEOF EQU_VARIABLE
                .UNTILCXZ

            .ELSE
            ;// wanting to turn this on

                ENTER_PLAY_SYNC GUI

                mov [edi].order, 1                      ;// default order of 1
                mov DWORD PTR [edi].for_buf, '0'        ;// set a default eqution
                mov DWORD PTR [edi].for_head.bDirty, 1  ;// set as dirty

                ;// set up the EVAR_AVAILABLE flags
                push edi
                call init_variable_with_order
                pop edi
                invoke equ_Compile, ADDR [edi].for_head, ADDR [ebx].variables, EQE_USE_INDEX

                LEAVE_PLAY_SYNC GUI

            .ENDIF

            GDI_INVALIDATE_OSC HINTI_OSC_SHAPE_CHANGED

            ;// mov eax,
            ;// invoke gdi_Invalidate_osc

            mov eax, POPUP_SET_DIRTY OR POPUP_REDRAW_OBJECT

        .ELSEIF ecx < id_D_equation
        ;// wanting to set a new order

            ;// set the order to the desired number
            ;// mark the appropriate variables as available
            ;// call update dialog

            mov [edi].order, ecx

            call init_variable_with_order

            ;// mov eax, INVAL_SHAPE_CHANGED
            ;// invoke gdi_Invalidate_osc

            GDI_INVALIDATE_OSC HINTI_OSC_SHAPE_CHANGED

            mov eax, POPUP_SET_DIRTY + POPUP_REDRAW_OBJECT

        .ELSEIF ecx == id_D_equation
        ;// wanting to edit this equation

            invoke diff_launch_editor

            ;// set the focus to the popup

            mov eax, POPUP_DONOT_RESET_FOCUS

        .ELSEIF ecx < id_D_trigger
        ;// wanting to change an output pin

            ;// if ->on     set the display flag for this variable
            ;// if ->off    reset the display flag for this bariable

            ;// determine the variable we want
            sub ecx, id_D_output            ;// subtract out command offset
            mov edi, [edi].pVariables       ;// load this equation's variable pointer
            sub ecx, DIFF_NUM_DERIVATIVE-1  ;// subtract max+derivative
            neg ecx                         ;// flip to positive
            mov eax, SIZEOF EQU_VARIABLE    ;// load the variable size
            mul ecx                         ;// multiply to an offset
            lea edi, [edi+eax]              ;// get pointer to variable in question
            ASSUME edi:PTR EQU_VARIABLE

            .IF [edi].dwFlags & DVAR_x_TEST     ;// variable is currently ON
                and [edi].dwFlags, DVAR_x_MASK  ;// strip out index
            .ELSE                               ;// variable is currently OFF
                or [edi].dwFlags, DVAR_x_TEST   ;// tag for display
            .ENDIF

            ;// mov eax, INVAL_SHAPE_CHANGED
            ;// invoke gdi_Invalidate_osc

            GDI_INVALIDATE_OSC HINTI_OSC_SHAPE_CHANGED

            mov eax, POPUP_SET_DIRTY + POPUP_REDRAW_OBJECT

        .ELSE
        ;// IF ecx == id_D_trigger
        ;// wanting to set this as the trigger to display

            ;// set pTrigger as this variable

            mov [ebx].pTrigger, edi
            mov eax, POPUP_REDRAW_OBJECT

        .ENDIF

    .ELSE

    ;// new trigger pin

        DEBUG_IF <eax !>= ID_DIFF_LAST> ;// some how, we recieved a bad command ID

        OSC_TO_DATA esi, ebx, OSC_DIFF_DATA

        ;// extract the group and command index

        mov edi, [ebx].pTrigger     ;// load the trigger we're looking at
        ASSUME edi:PTR DIFF_EQUATION
        sub eax, ID_DIFF_TRIG       ;// strip out the command offset
        mov ecx, eax                ;// store in ecx
        mov edx, SIZEOF EQU_VARIABLE;// need to do this anyways
        and ecx, 03h                ;// ecx is now the command ID
        shr eax, 2                  ;// eax is now the VARIABLES's NUMBER
        mov edi, [edi].pVariables   ;// load the variable block for this equation
        sub eax, DIFF_NUM_DERIVATIVE-1;// need to turn eax around
        neg eax                     ;// and flip the sign
        mul edx                     ;// eax is now the VARIABLES's offset
        add edi, eax                ;// edi is now a pointer to EQU_VARIABLE
        ASSUME edi:PTR EQU_VARIABLE

        .IF ecx==0
        ;// wanting to turn on or off this trigger pin

            .IF [edi].dwFlags & DVAR_T_TEST ;// wanting to turn off
                and [edi].dwFlags, DVAR_T_MASK
            .ELSE                           ;// wanting to turn on
                or [edi].dwFlags, DVAR_T_E  ;// default to 'equals'
                ;// index should be zero already
            .ENDIF

            ;// mov eax, INVAL_SHAPE_CHANGED
            ;// invoke gdi_Invalidate_osc

            GDI_INVALIDATE_OSC HINTI_OSC_SHAPE_CHANGED

            mov eax, POPUP_SET_DIRTY + POPUP_REDRAW_OBJECT

        .ELSE
        ;// wanting to set this trigger's type

            shl ecx, DVAR_T_SHIFT
            and [edi].dwFlags, DVAR_T_MASK
            or [edi].dwFlags, ecx
            mov eax, POPUP_REDRAW_OBJECT

        .ENDIF

    .ENDIF

    ;// now we check if we have to update the dialog

    .IF eax & POPUP_REDRAW_OBJECT

        push eax
        invoke gdi_Invalidate
        invoke diff_UpdateDialog_differentials, esi
        pop eax

    .ENDIF

    pop ebx
    pop edi

.ENDIF

    ;// b'gosh, that's it

        ret


;////////////////////////////////////////////////////////////////////////////
;//
;//   L O C A L   F U N C T I O N S
;//

ALIGN 16
init_variable_with_order:

    ;// this sets the EVAR AVAILABLE flags for the desired variable

    ;// destroys edi

    ;// edi must be the desired DIFF_EQUATION
    ;// [edi].order must already be set

    ASSUME edi:PTR DIFF_EQUATION

    mov edx, [edi].order
    inc edx
    mov ecx, DIFF_NUM_DERIVATIVE
    mov edi, [edi].pVariables
    ASSUME edi:PTR EQU_VARIABLE
    .REPEAT
        cmp edx, ecx
        je @0
        ja @1
            ;// order is LESS than current
            mov [edi].dwFlags, 0    ;// reset the AVAILABLE flag
            jmp @2
        @0:
            ;// order EQUALS current
            and [edi].dwFlags, NOT EVAR_AVAILABLE
            jmp @2
        @1:
            ;// order if GREATER than current
            or [edi].dwFlags, EVAR_AVAILABLE    ;// set the available flag
        @2:
            add edi, SIZEOF EQU_VARIABLE
    .UNTILCXZ

    retn

diff_Command ENDP


;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
diff_GetUnit PROC

    ASSUME ebp:PTR LIST_CONTEXT
    ASSUME esi:PTR OSC_MAP
    ASSUME ebx:PTR APIN

    clc ;// we never know
    ret

diff_GetUnit ENDP





;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;//////
;//////
;//////     handler for the equation builder when being used by the diff popup
;//////     these are commands intended for the equation builder

ASSUME_AND_ALIGN
diff_Proc PROC  ;// STDCALL uses esi edi hWnd:dword, msg:dword, wParam:dword, lParam:dword

    mov eax, WP_MSG

    HANDLE_WM   WM_COMMAND, diff_wm_command_proc
    HANDLE_WM   WM_KEYDOWN, diff_wm_keydown_proc
    HANDLE_WM   WM_ACTIVATE, diff_wm_activate_proc
    HANDLE_WM   WM_CLOSE, diff_wm_close_proc
    HANDLE_WM   WM_SYSCOMMAND, diff_wm_syscommand_proc
    HANDLE_WM   WM_SETCURSOR, popup_wm_setcursor_proc
    HANDLE_WM   WM_DRAWITEM, popup_wm_drawitem_proc

    jmp DefWindowProcA

diff_Proc ENDP

ASSUME_AND_ALIGN
diff_wm_command_proc PROC PRIVATE

        mov eax, WP_WPARAM
        test eax, 0FFFF0000h        ;// check notify message from a control
        jz not_notify_message

        ;// we'll take this message
        ;// only if it's a change for an edit control
        shr eax, 16
        .IF eax == EN_CHANGE
            mov eax, OSC_COMMAND_EDIT_CHANGE
            jmp call_equ_command
        .ENDIF
        .IF eax == EN_SETFOCUS
            mov eax, OSC_COMMAND_EDIT_SETFOCUS
            jmp call_equ_command
        .ENDIF
        .IF eax == EN_KILLFOCUS
            mov eax, OSC_COMMAND_EDIT_KILLFOCUS
            jmp call_equ_command
        .ENDIF

        jmp DefWindowProcA

    ASSUME_AND_ALIGN
    not_notify_message:

        and eax, 0FFFFh         ;// strip off top of cmd id

    call_equ_command:

        mov ecx, WP_HWND

        invoke equ_Command, ecx, eax    ;// send this right to the equ command handler

        .IF eax & POPUP_REDRAW_OBJECT
            invoke diff_UpdateDialog_differentials, popup_Object
        .ENDIF

        invoke SetFocus, diff_hWnd  ;// make sure we can keep sending keystrokes

        invoke app_Sync             ;// alway invalidate

        xor eax, eax
        ret 10h

diff_wm_command_proc ENDP


ASSUME_AND_ALIGN
diff_wm_syscommand_proc PROC

    ;// this makes sure hitting close on the equation builder does not close the popup as well

        mov eax, WP_WPARAM
        and eax, 0FFF0h
        .IF eax == SC_CLOSE
            .IF popup_Object
                invoke SetFocus, popup_hWnd
                xor eax, eax
                ret 10h
            .ENDIF
        .ENDIF
        jmp DefWindowProcA


diff_wm_syscommand_proc ENDP





ASSUME_AND_ALIGN
diff_wm_keydown_proc PROC PRIVATE

    mov eax, WP_WPARAM

    .IF eax == VK_ESCAPE

        mov eax, WP_HWND
        invoke SetFocus, popup_hWnd

    .ELSE

        push esi
        push ebx

        ;// stack looks like this
        ;//
        ;// ebx esi ret wnd msg wpa lpa
        ;// 00  04  08  0C  10  14  18

        ;// check if delete key, then see if we xlate it

        mov ebx, eax     ;// xfer the key to ebx
        .IF ebx == VK_DELETE
            GET_OSC_FROM edx, popup_Object
            OSC_TO_BASE edx, edx
            .IF [edx].data.dwFlags & BASE_XLATE_DELETE
                mov ebx, ID_XLATE_DELETE
            .ENDIF
        .ENDIF

        ;// scan through all the controls
        mov eax, [esp+0Ch]  ;// get the hWnd
        invoke GetWindow, eax, GW_CHILD
        mov esi, eax

        .WHILE esi

            invoke GetWindowLongA, esi, GWL_ID
            .IF eax == ebx

                ;// make sure the control is enabled before we click on it
                invoke GetWindowLongA, esi, GWL_STYLE
                .IF !(eax & WS_DISABLED)
                    invoke PostMessageA, esi, BM_CLICK, 0, 0
                .ENDIF

                xor eax, eax
                .BREAK

            .ENDIF

            invoke GetWindow, esi, GW_HWNDNEXT
            mov esi, eax

        .ENDW

        pop ebx
        pop esi

    .ENDIF

    xor eax, eax
    ret 10h

diff_wm_keydown_proc ENDP

.DATA

    diff_kludge_closer  dd  0

.CODE


ASSUME_AND_ALIGN
diff_wm_activate_proc PROC PRIVATE

    mov eax, WP_WPARAM
    .IF !(eax & 0FFFFh)

        ;// we are loosing activation

        .IF diff_hWnd

        ;// xfer hwnd gaining activation to kludeamatic

            mov eax, WP_LPARAM
            mov diff_kludge_closer, eax

        ;// close the diff hwnd, causes WM_CLOSE handler to be hit
        ;// causes this funcion (WM_ACTIVATE) to be hit again

            mov eax, WP_HWND
            invoke SendMessageA, eax, WM_CLOSE, 0, 0

        .ENDIF

    .ENDIF

    xor eax, eax
    ret 10h

diff_wm_activate_proc ENDP


ASSUME_AND_ALIGN
diff_wm_close_proc PROC PRIVATE

    .IF diff_hWnd

        invoke equ_EditDtor
        push esi
        push ebp

        GET_OSC_FROM esi, popup_Object
        stack_Peek gui_context, ebp

        GDI_INVALIDATE_OSC HINTI_OSC_SHAPE_CHANGED

        pop ebp
        pop esi

        invoke diff_UpdateDialog_differentials, popup_Object

        mov diff_hWnd, 0    ;// be sure to keep this BEFORE Set focus
                            ;// otherwise an infinate loop results

        mov eax, diff_kludge_closer
        mov diff_kludge_closer, 0
        .IF eax != popup_hWnd
            invoke PostMessageA, popup_hWnd, WM_CLOSE, 0, 0

            ;// now we have the problem of the equation editor not saveing it's unredo data
            unredo_EndAction  UNREDO_COMMAND_OSC
            inc popup_EndActionAlreadyCalled

        .ELSE
            invoke SetFocus, eax
        .ENDIF


        invoke app_Sync

    .ENDIF

    jmp DefWindowProcA

diff_wm_close_proc ENDP




;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
diff_AddExtraSize PROC uses edi ;// STDCALL uses esi edi pObject:PTR OSC_OBJECT

    ASSUME esi:PTR OSC_OBJECT   ;// preserve
    ASSUME ebx:PTR DWORD        ;// preserve

    ;// determine the size needed to store all the equations
    ;// and our settings

    ;// size is: 6 sets of : 5 dwords plus a null terminated string

    OSC_TO_DATA esi, edi, OSC_DIFF_DATA
    lea edi, [edi].equations
    ASSUME edi:PTR DIFF_EQUATION

    mov ecx, DIFF_NUM_EQUATION
    xor edx, edx            ;// clear the string length

    ;// count the length of all equations
    J0: cmp [edi].order, 0      ;// anything ?
        jz J3                   ;// jump if empty
        lea eax, [edi].for_buf  ;// point at formula buffer
        STRLEN eax, edx         ;// determine the length
    J3: inc edx             ;// add one for the terminator
        add edi, SIZEOF DIFF_EQUATION   ;// next differential
        loop J0                 ;// loop until done

    ;// add the fixed size

    OSC_TO_DATA esi, edi, OSC_DIFF_DATA ;// get the dat pointer
    add edx, DIFF_NUM_EQUATION * DIFF_NUM_DERIVATIVE * 4 + 4
    mov [edi].extra, edx    ;// store extra for later
    add [ebx], edx          ;// accumulate as requested

    ret

diff_AddExtraSize ENDP

;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
diff_private_write PROC

    ;// writes the diff data to memory

    ;// edi must bethe destination (iterated)
    ;// esi must point at osc (destroyed)
    ;// ebx mouse point at OSC_DIFF_DATA (destroyed)

    ASSUME esi:PTR OSC_OBJECT   ;// destroyed
    ASSUME edi:PTR DWORD        ;// iterated
    ASSUME ebx:PTR OSC_DIFF_DATA;// destroyed

    ;// write dword user

        mov eax, [esi].dwUser           ;// load dword user
        stosd

    ;// prepare to store the equations

        lea ebx, [ebx].equations
        ASSUME ebx:PTR DIFF_EQUATION
        mov ecx, DIFF_NUM_EQUATION  ;// ecx counts equations

    ;// store the five variable flags

    J0: mov esi, [ebx].pVariables       ;// load pointer to this equation's variables
        ASSUME esi:PTR EQU_VARIABLE

        mov edx, DIFF_NUM_DERIVATIVE    ;// edx counts variables
    J1: mov eax, [esi].dwFlags
        stosd
        add esi, SIZEOF EQU_VARIABLE
        dec edx
        jnz J1

        mov eax, edx
        or [ebx].order, edx
        jz J3

    ;// store the equation

        lea esi, [ebx].for_buf

    J2: lodsb
    J3: stosb
        or al, al
        jnz J2

        ;// iterate
        add ebx, SIZEOF DIFF_EQUATION
        loop J0

    ;// that's it

        ret

diff_private_write ENDP





;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
diff_Write PROC uses esi

    ASSUME esi:PTR OSC_OBJECT   ;// preserve
    ASSUME edi:PTR FILE_OSC     ;// iterate
    OSC_TO_DATA esi, ebx, OSC_DIFF_DATA ;// ebx is destroyed

    ;// write our settings and all the equations
    ;// iterate edi in the process

    mov eax, [ebx].extra    ;// load extra count
    DEBUG_IF <!!eax>        ;// zero ? why wasn't add extra size called ?

    mov [edi].extra, eax            ;// store in file
    add edi, SIZEOF FILE_OSC        ;// advance

    invoke diff_private_write


    ;// that's it

        ret

diff_Write ENDP

;////////////////////////////////////////////////////////////////////
;//
;//
;//     _SaveUndo
;//



ASSUME_AND_ALIGN
diff_SaveUndo   PROC

DEBUG_MESSAGE <diff_SaveUndo>

        ASSUME esi:PTR OSC_OBJECT

    ;// edx enters as either UNREDO_CONTROL_OSC or UNREDO_COMMAND
    ;// edi enters as where to store
    ;//
    ;// task:   1) save nessary data
    ;//         2) iterate edi
    ;//
    ;// may use all registers except ebp


        ;// for save undo, we want to store all the equations
        ;// just like we do for saveing to a file

        OSC_TO_DATA esi, ebx, OSC_DIFF_DATA
        invoke diff_private_write

        ;// have to dword align

        mov ecx, edi
        and ecx, 3
        .IF !ZERO?

            neg ecx
            xor eax, eax
            and ecx, 3
            rep stosb

        .ENDIF

        ret

diff_SaveUndo ENDP
;//
;//
;//     _SaveUndo
;//
;////////////////////////////////////////////////////////////////////

;////////////////////////////////////////////////////////////////////
;//
;//
;//     _LoadUndo
;//

ASSUME_AND_ALIGN
diff_LoadUndo PROC


DEBUG_MESSAGE <diff_LoadUndo>

        ASSUME esi:PTR OSC_OBJECT   ;// preserve
        ASSUME ebp:PTR LIST_CONTEXT ;// preserve

    ;// edx enters as either UNREDO_CONTROL_OSC or UNREDO_COMMAND
    ;// edi enters as where to load
    ;//
    ;// task:   1) load nessary data
    ;//         2) do what it takes to initialize it
    ;//
    ;// may use all registers except ebp and esi
    ;// return will invalidate HINTI_OSC_UPDATE


        ;// to do this, we'll fool kludge ctor

        mov eax, [edi]  ;// have to xfer dwUser
        mov [esi].dwUser, eax

        sub edi, SIZEOF FILE_OSC    ;// fool's ctor into pointing at the correct spot

        invoke diff_kludge_ctor, esi, edi, edi

        or [esi].dwHintI, HINTI_OSC_CREATED

        ret

diff_LoadUndo ENDP

;//
;//
;//     _LoadUndo
;//
;////////////////////////////////////////////////////////////////////





























;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
diff_PrePlay PROC uses ebp

    ASSUME esi:PTR OSC_OBJECT   ;// preserve
    ASSUME edi:PTR OSC_BASE

    ;// reset last triggers

    ;// GET_OSC esi

        xor eax, eax    ;// eax will be zero for most of this function

        OSC_TO_PIN_INDEX esi, ebx, DIFF_APIN_S
        mov [ebx].dwUser, eax
        OSC_TO_PIN_INDEX esi, ebx, DIFF_APIN_T
        mov [ebx].dwUser, eax

    ;// clear out local variables

        push esi
        mov ebp, eax    ;// ebp is a 'do compile' flag
        mov edx, DIFF_NUM_EQUATION

        OSC_TO_DATA esi, esi, OSC_DIFF_DATA
        lea esi, [esi].equations
        ASSUME esi:PTR DIFF_EQUATION

        .REPEAT

            .IF [esi].for_head.bDirty
                inc ebp
            .ENDIF

            lea edi, [esi].cur_value
            mov ecx, DIFF_NUM_DERIVATIVE
            rep stosd

            add esi, SIZEOF DIFF_EQUATION
            dec edx

        .UNTIL ZERO?

        pop esi
        ASSUME esi:PTR OSC_OBJECT

    ;// check need to compile

        .IF ebp

            mov ebp, [esp]      ;// ABOX233, how'd the context get messed up ?
            invoke diff_compile

        .ENDIF

    ;// that's it

        xor eax, eax    ;//  eax is zero so play_Start will erase our data

        ret

diff_PrePlay ENDP





;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
;///////
;///////
;///////    C  A  L  C
;///////
;///////
;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////


    ;// structs


;// piles

    ;// to iterate the equations, we use 'piles' of derivatives
    ;// there is one DIFF_PILE struct assigned to each diff equation
    ;// we make use of the fact that the actual values are stored in
    ;// consecutive slots DIFF_EQUATION.cur_value
    ;//
    ;// so all we have to store is a pointer to the top (highest) derivative

    DIFF_PILE STRUCT
        count   dd  0   ;// order of this equation
        pTop    dd  0   ;// pointer to top slot in the pile, ptr to DIFF_EQUATION.cur_value
        pExe    dd  0   ;// pointer to the code that exectutes
    DIFF_PILE ENDS

    ;// piles are set up by
    ;//
    ;//     initialize_piles
    ;//
    ;// the top derivative are calculated by
    ;//
    ;//     DIFF_DO_EQUATIONS
    ;//
    ;//     diff_fill_frame
    ;//     step_test_all
    ;//     trigger_test_all
    ;//     diff_calc_full_speed
    ;//
    ;// the piles are approximated by one of
    ;//
    ;//     diff_stack_dH_dM
    ;//     diff_stack_nH_dM
    ;//     diff_stack_dH_nM
    ;//     diff_stack_nH_nM
    ;//
    ;//     pointed at by pDiffStack
    ;//
    ;// diff_stack then jumps to a clip test
    ;//
    ;//     diff_clip_test_2
    ;//     diff_clip_test_8
    ;//
    ;//     pointed at by pClipTest

    ;// to produce output, we store pairs of (source,dest) pointers

    DIFF_OUTPUT STRUCT
        source  dd  0   ;// pointer where to get the data from
        dest    dd  0   ;// pointer where to put the data
        pPin    dd  0   ;// pointer to output pin, needed for pin changing status
    DIFF_OUTPUT ENDS

    ;// results are sent to the output by
    ;//
    ;//     DIFF_PRODUCE_OUTPUT macro
    ;//
    ;// pointers are iterated by
    ;//
    ;//     DIFF_ITERATE_POINTERS macro
    ;//
    ;//
    ;// output pin status is set by
    ;//
    ;//     DIFF_SET_OUTPUT_STATUS


;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////




;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////

comment ~ /*


    the jump sequence

    rather than use self modifying code this routine uses jump values
    there are several of them that are set according to the various states on the pins

    here is the complete list in a likely order of execution

    trigger testing

        pTrigTest   pointer to the trigger test (or zero for not used)

            if no trigger, jump to pTrigReturn
            if yes trigger, jump to the first value in pT_jump[]

        pT_jump[13] pointers to next routine to do the trigger for
        pT_oper[12] pointers to triggered inputs data (what we're doing to the trigger data)
        pT_data[12] pointers to target's data (source and dest)

            these are a chain of jumps, the last of which always jumps to pTrigReturn
            these tables are needed to allow setting the trigger accumulations correctly

        pTrigReturn where the trigger test returns to

    step testing

        pStepTest   pointer to step tester

            if no step trigger, jump to pStepReturn
            if yes step trigger, jump to pEquation

        pStepReturn where pStepTest and pClipTest return to

    equation iteration

        pEquation   how we perform the equation

            may jump to pDiffStack or pEquation_2

        pEquation_2 second part of the rk approximation

            always jumps to pClipTest

        pDiffStack  how we accumulate the derivatives

            always jumps to pClipTest

        pClipTest   pointer to clip test routine

            always jumps to pStepReturn



    given all that:

    the branch structure in step 3 will do the jumps accordingly
    and will set the _Return pointers as required



*/ comment ~

;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////

    ;// runge kutta

comment ~ /*

    the calculation sequence is quite a bit different

    runge kutta method as seen in text book

        F1 = h*F(X)     F2 = h*(X+1/2*F1)   F3 = h*(X+1/2*F2)   F4 = h*(X+F3)

        X += 1/6 * (F1 + 2*F2 + 2*F3 + F4)

    to do this we implement 2 more arrays to store states

        RX[] is an array inside DIFF_EQUATION, holds initial value of pile
        RK[] is an array inside DIFF_EQUATION, accumlates the F values

        both may be indexed by pile+offset

    the equation is rearranged

        X is replaced by P, for Piles
        RA accumulates F's
        RX stores initial X
        h factors are not included in the F acumulation
        the 1/6 factor is multiplied through

        so at the end of the four, we get RA as the derivatives
        this is needed to store the highest derivative as the value we come up with

    here's an expanded version for second order

    iterators   n = n
                m = n-1

                    RX2     RX1     RX0     |   P2      P1      P0      |   RA2     RA1     RA0
                    ------------------------|---------------------------|------------------------
    initial state                           |           P1      P0      |
                    ------------------------|---------------------------|------------------------
    DO_EQ                                   |   P2        \             |
    RAm = 1/6 * Pm                          |     \        \            | = 1/6P2   1/6P1
    RXn = Pn                RX1     RX0     |      \        \           |
    Pn += h/2 * Pm                          |       *h/2+P1  *h/2+P0    |
                    ------------------------|---------------------------|------------------------
    DO_EQ                                   |   P2                      |
    RAm += 1/3 * Pm                         |                           | + 1/3P2   1/3P1
    Pn = h/2 * Pm + RXn                     |           P1      P0      |
                    ------------------------|---------------------------|------------------------
    DO_EQ                                   |   P2                      |
    RAm += 1/3 * Pm                         |                           | + 1/3P2   1/3P1
    Pn = h * Pm + RXn                       |           P1      P0      |
                    ------------------------|---------------------------|------------------------
    DO_EQ                                   |   P2                      |
    Pn = ( RAm + 1/6 * Pm ) * h + RXn       |           P1      P0      |
    last iter, stores(RAm + 1/6 * Pm)       |   P2                      |
                    ------------------------|---------------------------|------------------------


    n always scans backwards from the bottom of the pile until it reaches the top of the pile

    each stage does two things then iterates

        accumulate the derivative   RA[m] += rf * P[m]
        prepare for next approx     P[n] = hf * P[m] + RX[m]
        iterate                     n -= 4

        rf and hf are integration values, listed below

    there are then 4 stages to each approximation,
    note the differences in integration values and operations
    also note that stage 4
        combines the accumulate,
        applies the damping factor
        stores back to P[]


    ;// stage       setup           accumulate              prepare                     integration values
    ;// -------     ------------    ------------------      ------------------------    --------    --------
    ;// DIFF_DO_EQUATIONS
    ;// stage_1     RX[n] = P[n]    RA[m] = rf * P[m]       P[n] += hf * P[m]           rf = 1/6    hf = h/2
    ;// DIFF_DO_EQUATIONS
    ;// stage_2                     RA[m] += rf * P[m]      P[n] = hf * P[m] + RX[n]    rf = 1/3    hf = h/2
    ;// DIFF_DO_EQUATIONS
    ;// stage_3                     RA[m] += rf * P[m]      P[n] = hf * P[m] + RX[n]    rf = 1/3    hf = h
    ;// DIFF_DO_EQUATIONS
    ;// stage_4     P[n] = (( RA[m] + rf * P[m] ) * hf + RX[n] ) * m                    rf = 1/6    hf = h
    ;//             last iteration must store ( RA[m] + rf * P[m] )

    states there are 4 flavors depending on H and M
    then there are two parts to the algorithm

        dH  dM
        nH  nM

        stages 1 through 3

            rk_stage_123_dH
            rk_stage_123_nH

            pointed at by pEquation

        stage 4

            rk_stage_4_dH_dM
            rk_stage_4_nH_dM
            rk_stage_4_dH_nM
            rk_stage_4_nH_nM

            pointed at by pEquation_2


*/ comment ~

;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////


;// macros for the calc function

;//////////////////////////////////////////////////////////////////////////////


    DIFF_DO_EQUATIONS MACRO

        local J0

        mov ecx, num_piles          ;// ecx counts equation piles
        lea edi, piles              ;// load the pile pointer
        ASSUME edi:PTR DIFF_PILE

    J0: mov ebx, [edi].pTop         ;// load top of this pile pointer (ptr to cur_value)
        call [edi].pExe             ;// call the equation for this
        add edi, SIZEOF DIFF_PILE   ;// advance to next pile
        dec ecx                     ;// decreasethe count remaining
        fstp DWORD PTR [ebx]        ;// store results of equation in cur_value
        jnz J0

        ENDM


;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////


    DIFF_ITERATE_POINTERS   MACRO

        LOCAL J0

        ;// iterate pointers
        mov ecx, num_iterate        ;// load the size of the table
        lea ebx, iterate            ;// point at the table
    J0: mov edx, DWORD PTR [ebx]    ;// load the pointers value
        add ebx, 4                  ;// advance the indexer
        add DWORD PTR [edx], 4      ;// advance the pointer
        dec ecx                     ;// decrease the count remaining
        jnz J0                      ;// loop until done

        ENDM

;//////////////////////////////////////////////////////////////////////////////


    DIFF_PRODUCE_OUTPUT MACRO

        ;// this scans the output array
        ;// and xfers data from one pointer to another

        LOCAL J0

        mov ecx, num_outputs        ;// load the table size
        lea ebx, outputs            ;// point at the output table
        ASSUME ebx:PTR DIFF_OUTPUT

    J0: mov edx, [ebx].source       ;// load the source pointer
        mov edi, [ebx].dest         ;// load the destination ptr
        add ebx, SIZEOF DIFF_OUTPUT ;// iterate the indexer
        mov eax, DWORD PTR [edx]    ;// load the source value
        dec ecx                     ;// decrease the count remaining
        mov DWORD PTR [edi], eax    ;// store source data in destination pointer
        jnz J0

        ENDM

;//////////////////////////////////////////////////////////////////////////////

    DIFF_SET_OUTPUT_STATUS MACRO t

        ;// this macro sets the pin.dwStatus for all pins in the output array
        ;// passed parameter is either 1=changing data
        ;// or 0=not changing data

        LOCAL J0

        mov ecx, num_outputs        ;// load the size of the table
        lea ebx, outputs            ;// point at the ouput table
        ASSUME ebx:PTR DIFF_OUTPUT

    J0: mov edi, [ebx].pPin         ;// get the pin pointer
        IF t EQ 1
            or (APIN PTR [edi]).dwStatus, PIN_CHANGING
        ELSE
            and (APIN PTR [edi]).dwStatus, NOT PIN_CHANGING
        ENDIF
        add ebx, SIZEOF DIFF_OUTPUT ;// advance the table iterator
        dec ecx                     ;// decrease count reamaining
        jnz J0                      ;// loop until done


        ENDM



.CODE

;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;//
;// the calc function   (not completely rewritten for abox2)
;//                     be aware that the context pointer is INVALID


ASSUME_AND_ALIGN
diff_Calc PROC STDCALL uses esi ;// pObject:PTR OSC_OBJECT

    LOCAL pObject:DWORD     ;// (abox2 does not pass this on the stack)

    ;// instead of local routines, we're going to use jump pointers

    LOCAL pStepTest:DWORD   ;// pointer to step tester
    LOCAL pClipTest:DWORD   ;// pointer to clip test routine
    LOCAL pStepReturn:DWORD ;// where pStepTest and pClipTest return to
    LOCAL pTrigTest:DWORD   ;// pointer to the trigger test (or zero for not used)
    LOCAL pTrigReturn:DWORD ;// where the trigger test returns to
    LOCAL pEquation:DWORD   ;// how we perform the equation
    LOCAL pEquation_2:DWORD ;// second part of the rk approximation
    LOCAL pDiffStack:DWORD  ;// points at the correct diff stack process (h and m)
                            ;// diff stack implements the clip test

    ;// iterators to values
    LOCAL pS:DWORD          ;// pointer to step trigger data
    LOCAL pH:DWORD          ;// pointer to the current step size value
    LOCAL pM:DWORD          ;// pointer to the current damper value
    LOCAL pT:DWORD          ;// pointer to the current trigger value

    ;// last values
    LOCAL lastT:DWORD       ;// last t trigger value
    LOCAL lastS:DWORD       ;// last s trigger value

    ;// sample counter
    LOCAL sample_counter:DWORD  ;// counts samples

    LOCAL num_pT:DWORD      ;// counts these for setting them up

    ;// jump pointers
    LOCAL pT_jump[13]:DWORD ;// pointer to next routine to do the trigger for
    LOCAL pT_oper[12]:DWORD ;// pointer to triggered inputs data (what we're doing to the trigger data)
    LOCAL pT_data[12]:DWORD ;// pointer to target's data (source and dest)

    ;// piles   piles maintain pointers to equ variables
    LOCAL piles[DIFF_NUM_EQUATION]:DIFF_PILE    ;// array of piles
    LOCAL num_piles:DWORD   ;// number of piles we actually deal with

    ;// output retreival
    LOCAL outputs[12]:DIFF_OUTPUT   ;// array of output pointers
    LOCAL num_outputs:DWORD         ;// number of entries in array

    ;// to iterate pointers, we store an array
    MAX_ITERATE_VALUES equ 40               ;// there's only 40 pins on the object
    LOCAL iterate[MAX_ITERATE_VALUES]:DWORD ;// pointers to values to iterate
    LOCAL num_iterate:DWORD                 ;// number of values to iterate


    ;// flags for deciding what to do


    ;// step trigger iterator and tester
    LOCAL bStep_once:DWORD  ;// set true if we only s trigger test once

    ;// t trigger iterator and tester
    LOCAL bTrig_once:DWORD  ;// set true if we only t trigger test once
                            ;// triggered input jump array

    ;// then here's an equate to clean up code

    iT_reg TEXTEQU <ebx>
    iO_reg TEXTEQU <eax>
    iD_reg TEXTEQU <edx>





;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;///
;///
;///    S E T U P       values requiring dwUser
;///
;///    P A R T 1
;///

        mov pObject, esi


    ;// reset some counters

        xor eax, eax
        mov num_iterate, eax
        mov bStep_once, eax
        mov bTrig_once, eax
        mov num_piles, eax
        mov num_outputs, eax
        mov num_pT, eax
        mov lastS, eax
        mov lastT, eax

        mov pS, eax
        mov pH, eax
        mov pM, eax
        mov pT, eax

        mov diff_clipping, eax

    ;// look at the four fixed pins

        mov ebx, esi    ;// esi has the osc pointer

        lea edi, iterate            ;// edi will advance the iterate table

        ;// GET_OSC ebx                 ;// ebx will point at the osc for a while
        ASSUME ebx:PTR OSC_OBJECT
        OSC_TO_PIN_INDEX ebx, esi, 0    ;// point at s pin

    ;// s pin

        xor ecx, ecx
        OR_GET_PIN [esi].pPin, ecx
        .IF !ZERO?          ;// S pin is connected
            mov eax, [ecx].pData    ;// load the pin's data pointer
            mov pS, eax             ;// store in pointer to S
            mov eax, [esi].dwUser   ;// load the last trigger
            mov lastS, eax          ;// store in last_S
            .IF [ecx].dwStatus & PIN_CHANGING
                lea eax, pS         ;// load address of pS pointer
                stosd               ;// store in iterate table
                inc num_iterate     ;// increase number to iterate
            .ELSE
                mov bStep_once, 1   ;// step is connected and not changing
            .ENDIF                  ;// so we only calculate once
            mov eax, [ebx].dwUser
            and eax, DIFF_S_TEST
            .IF !ZERO?
                .IF eax & DIFF_S_POS
                    lea eax, check_s_trig_pos
                .ELSE
                    lea eax, check_s_trig_neg
                .ENDIF
            .ELSE
                lea eax, check_s_trig_both
            .ENDIF
        .ELSE               ;// S is not connected
            xor eax, eax
        .ENDIF

        ;// now eax has the pointer to the S trigger test

        mov pStepTest, eax

    ;// for the next two pins ( h and m )
    ;// we use edx as a flag
    ;// then store the results in pDiffStack

        xor edx, edx
        mov pEquation,  diff_linear ;// always set the default

    ;// h pin

        add esi, SIZEOF APIN

        xor ecx, ecx

        OR_GET_PIN [esi].pPin, ecx
        .IF !ZERO?          ;// H pin is connected
            mov eax, [ecx].pData    ;// load the pin's data pointer
            mov pH, eax             ;// store in pointer to S
            .IF [ecx].dwStatus & PIN_CHANGING
                lea eax, pH         ;// load address of pH pointer
                stosd               ;// store in iterate table
                inc num_iterate     ;// increase number to iterate
            .ENDIF

            inc edx     ;// set as true, we are using H

        .ENDIF

    ;// m pin

        add esi, SIZEOF APIN

        xor ecx, ecx
        OR_GET_PIN [esi].pPin, ecx
        .IF !ZERO?          ;// M pin is connected
            mov eax, [ecx].pData    ;// load the pin's data pointer
            mov pM, eax             ;// store in pointer to S
            .IF [ecx].dwStatus & PIN_CHANGING
                lea eax, pM         ;// load address of pS pointer
                stosd               ;// store in iterate table
                inc num_iterate     ;// increase number to iterate
            .ENDIF                  ;// so we only calculate once

        ;// we are using M

            .IF edx
                lea eax, diff_stack_dH_dM
                .IF [ebx].dwUser & DIFF_APPROX_RK
                    mov pEquation,  diff_rk_stage_123_dH
                    mov pEquation_2,diff_rk_stage_4_dH_dM
                .ENDIF
            .ELSE
                lea eax, diff_stack_nH_dM
                .IF [ebx].dwUser & DIFF_APPROX_RK
                    mov pEquation,  diff_rk_stage_123_nH
                    mov pEquation_2,diff_rk_stage_4_nH_dM
                .ENDIF
            .ENDIF

        .ELSE ;// we are not using M

            .IF edx
                lea eax, diff_stack_dH_nM
                .IF [ebx].dwUser & DIFF_APPROX_RK
                    mov pEquation,  diff_rk_stage_123_dH
                    mov pEquation_2,diff_rk_stage_4_dH_nM
                .ENDIF
            .ELSE
                lea eax, diff_stack_nH_nM
                .IF [ebx].dwUser & DIFF_APPROX_RK
                    mov pEquation,  diff_rk_stage_123_nH
                    mov pEquation_2,diff_rk_stage_4_nH_nM
                .ENDIF
            .ENDIF

        .ENDIF

        mov pDiffStack, eax

    ;// clip test

        .IF [ebx].dwUser & DIFF_CLIP_8
            lea eax, diff_clip_test_8
        .ELSE
            lea eax, diff_clip_test_2
        .ENDIF

        mov pClipTest, eax

    ;// t pin

        add esi, SIZEOF APIN

        xor ecx, ecx
        OR_GET_PIN [esi].pPin, ecx
        .IF !ZERO?          ;// T pin is connected
            mov eax, [ecx].pData    ;// load the pin's data pointer
            mov pT, eax             ;// store in pointer to T
            mov eax, [esi].dwUser   ;// load the last trigger
            mov lastT, eax          ;// store in lastT
            .IF [ecx].dwStatus & PIN_CHANGING
                lea eax, pT         ;// load address of pT pointer
                stosd               ;// store in iterate table
                inc num_iterate     ;// increase number to iterate
            .ELSE
                mov bTrig_once, 1   ;// trigger is connected and not changing
            .ENDIF                  ;// so we only t trigger test once

            mov eax, [ebx].dwUser
            .IF eax & DIFF_T_GATE   ;// using gate triggers

                and eax, DIFF_T_TEST;// ABox232, changed from BOMB_TRAP
                DEBUG_IF <ZERO?>    ;// got both edges on a gate

                .IF eax & DIFF_T_POS
                    lea eax, check_t_trig_pos_gate
                .ELSE
                    lea eax, check_t_trig_neg_gate
                .ENDIF

                mov bTrig_once, 0   ;// ABox232: need to turn this off for gates
                                    ;// or the first values gets added twice

            .ELSE                   ;// using edge triggers

                and eax, DIFF_T_TEST
                .IF !ZERO?
                    .IF eax & DIFF_T_POS
                        lea eax, check_t_trig_pos_edge
                    .ELSE
                        lea eax, check_t_trig_neg_edge
                    .ENDIF
                .ELSE
                    lea eax, check_t_trig_both_edge
                .ENDIF

            .ENDIF

        .ELSE           ;// T is not connected
            xor eax, eax
        .ENDIF

        ;// now eax has the pointer to the t trigger test
        ;// or it is zero, for none

        mov pTrigTest, eax



;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;///
;///
;///    S E T U P       values requiring diff_data
;///
;///    P A R T 2
;///

        OSC_TO_DATA ebx, ebx, OSC_DIFF_DATA

    ;// set up the parameter pins
    ;// edi is still pointing at the iterate buffer

        lea esi, [ebx].variables.parameter_table
        ASSUME esi:PTR EQU_VARIABLE
        mov ecx, DIFF_NUM_PARAM
        xor edx, edx

        .REPEAT

            OR_GET_PIN [esi].pPin, edx  ;// if the pin is set, then we use it
            .IF !ZERO?                  ;// in use ?
                mov edx, [edx].pPin     ;// load the pin
                or edx, edx             ;// pin is connected ?
                .IF !ZERO?              ;// pin is connected
                    mov eax, [edx].pData    ;// get its data pointer
                    mov [esi].value, eax    ;// save data pointer in variable
                    .IF [edx].dwStatus & PIN_CHANGING   ;// changing data ?
                        lea eax, [esi].value;// load pointer to variables's value
                        stosd               ;// store in iterate table
                        inc num_iterate     ;// bump the iterate pointer
                    .ENDIF
                .ELSE               ;// this pin is not connected
                    mov eax, math_pNull ;// point at zero
                    mov [esi].value, eax    ;// save data pointer in variable
                .ENDIF

            .ENDIF  ;// varaiable pin in use

            add esi, SIZEOF EQU_VARIABLE    ;// iterate to next variable
            xor edx, edx

        .UNTILCXZ

        ;// now all the a paramemters are set up

    initialize_piles:

    ;// now we set up the piles for this system
    ;// we use two methods, one for using triggered inputs
    ;// and the other for not

        ;// edi is still pointing at the iterate table

        lea esi, [ebx].equations
        ASSUME esi:PTR DIFF_EQUATION    ;// esi walks equations
        mov ecx, DIFF_NUM_EQUATION      ;// ecx counts equations
        xor edx, edx                    ;// edx needs cleared to test the order

        lea ebx, piles                  ;// ebx will walk piles
        ASSUME ebx:PTR DIFF_PILE

    .REPEAT

        or edx, [esi].order     ;// load and test the order
        .IF !ZERO?              ;// is equation in use ??

            mov [ebx].count, edx    ;// store number in pile
            lea eax, [esi].exe_buf  ;// load exe pointer
            mov [ebx].pExe, eax     ;// store in pile
            inc num_piles           ;// advance this now

            ;// determine which cur value is the top of the pile

            push ecx    ;// save the equation count, we need it for pointing at cur_value
            push ebx    ;// store pile pointer, need ebx to point else where
            push edx    ;// need to save the order, need edx to point at varaiables

            sub edx, DIFF_NUM_DERIVATIVE-1
            neg edx     ;// now edx is index into cur_value, and variable

            lea ecx, [esi+edx*4].cur_value  ;// ecx points at top of pile
            mov [ebx].pTop, ecx             ;// store in pile

            shl edx, EQU_VARIABLE_SHIFT ;// turn edx into an equ_variable offset
            add edx, [esi].pVariables   ;// now edx points at top varaiable
            ASSUME edx:PTR EQU_VARIABLE

            jmp @F  ;// jump into loop entry point


            ;// now we scan through this and the remaining variables

            ;// ecx will point at cur_values
            ;// edx will point at variables

            .REPEAT

                push eax    ;// eax had the count

            @@: ;// entry point for this loop

                xor eax, eax
                OR_GET_PIN [edx].pPin, eax      ;// ? is this variable tagged for output ?
                .IF !ZERO?                      ;// yes

                    .IF [eax].pPin  ;// is this pin connected ??
                                    ;// yes

                        ;// get the output pointer

                        mov ebx, num_outputs    ;// load current number of outputs
                        lea ebx, [ebx+ebx*2]    ;// *3
                        lea ebx, outputs[ebx*4] ;// ebx now points at the output table
                        ASSUME ebx:PTR DIFF_OUTPUT

                        ;// store pointers in DIFF_OUTPUT

                        mov [ebx].pPin, eax     ;// store the pin pointer
                        mov [ebx].source, ecx   ;// store data source, from cur_value
                        mov eax, [eax].pData    ;// load this pin's data pointer
                        inc num_outputs         ;// bump the num_outputs count
                        mov [ebx].dest, eax     ;// store destination

                        ;// store pointers in output array

                        lea eax, [ebx].dest     ;// get the address of output pointer
                        stosd                   ;// store pointer in iterate array
                        inc num_iterate         ;// adjust it's count

                    .ENDIF  ;// tagged for output but not connected
                .ENDIF  ;// not tagged for output

                .IF pTrigTest   ;// check if we care about triggers

                    mov eax, [edx].dwFlags  ;// load the flags
                    and eax, DVAR_t_TEST    ;// is this slated for triggered input ?
                    .IF !ZERO?              ;// yes

                        ;// determine the pin
                        shr eax, DVAR_t_SHIFT - APIN_SHIFT
                        mov ebx, pObject
                        lea eax, [ebx+eax+SIZEOF OSC_OBJECT+DIFF_APIN_t_offset-SIZEOF APIN];// one based, remember ??
                        ASSUME eax:PTR APIN

                        mov ebx, num_pT         ;// load current number of triggered inputs
                        mov pT_data[ebx*4], ecx ;// store pointer to cur_value

                        ;// is pin connected ?
                        mov eax, [eax].pPin
                        .IF eax                 ;// yes
                            .IF [eax].dwStatus & PIN_CHANGING   ;// is the data changing ?
                                ;// store pT_data pointer in iterate table
                                push eax                ;// store pin pointer
                                lea eax, pT_oper[ebx*4] ;// load address of oper_pointer
                                stosd                   ;// store in iterate table
                                pop eax                 ;// retirve pin pointer
                                inc num_iterate         ;// adjust num iter
                            .ENDIF
                            mov eax, [eax].pData    ;// load the source pins data
                        .ELSE   ;// pin is not connected
                            mov eax, math_pNull ;// store zero data pointer
                        .ENDIF

                        mov pT_oper[ebx*4], eax     ;// store data pointer in oper array

                        ;// determine trigger mode
                        mov eax, [edx].dwFlags
                        and eax, DVAR_T_TEST
                        .IF     eax == DVAR_T_E
                            .IF ebx
                                lea eax, do_trigger_E_2nd
                            .ELSE
                                lea eax, do_trigger_E_1st
                            .ENDIF
                        .ELSEIF eax == DVAR_T_PE
                            .IF ebx
                                lea eax, do_trigger_PE_2nd
                            .ELSE
                                lea eax, do_trigger_PE_1st
                            .ENDIF
                        .ELSE ;// eax == DVAR_T_ME
                            .IF ebx
                                lea eax, do_trigger_ME_2nd
                            .ELSE
                                lea eax, do_trigger_ME_1st
                            .ENDIF
                        .ENDIF

                        mov pT_jump[ebx*4], eax ;// store the jump pointer
                        inc num_pT

                    .ENDIF

                .ENDIF  ;// variable not wanting trigger

                ;// now we get to iterate this

                pop eax             ;// retrieve the count
                add ecx, 4          ;// bump the cur_value pointer
                add edx, SIZEOF EQU_VARIABLE    ;// point at next variable
                dec eax             ;// decrease the count

            .UNTIL SIGN?

            pop ebx ;// retrieve the pile pointer
            pop ecx ;// retrieve the equation counter

            ;// now that were done with this pile, we advance ebx
            add ebx, SIZEOF DIFF_PILE

        .ENDIF  ;// equation not in use

        add esi, SIZEOF DIFF_EQUATION   ;// iterate to next equation
        xor edx, edx                        ;// reset for testing
        dec ecx

    .UNTIL ZERO?        ;// repeat until all five equations are done

    ;// whew !!

    ;// sanity check
    .IF !num_outputs;// no output pins ?
        ret         ;// nothing to do
    .ENDIF

    ;// now we make sure the pT table is terminated correctly
    ;// we also have to make sure that if num_pT is zero, that we ignore testing the triggers

    mov ebx, num_pT             ;// load number of pT's
    .IF ebx ;// are there any ?

        lea eax, do_trigger_last    ;// load last trigger function
        mov pT_jump[ebx*4], eax     ;// store last jump

    .ELSEIF pTrigTest != ebx    ;// if the trigger test scheduled, we have to ignore it

        mov pTrigTest, ebx  ;// ebx is already zero

    .ENDIF


;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;///
;///
;///  I T E R A T E     determine how to iterate and start the loop
;///                    each block in this section must set up
;///    P A R T 3       pStepReturn and pTrigReturn
;///


    GET_OSC ebx
    OSC_TO_DATA ebx, esi, OSC_DIFF_DATA
    lea esi, [esi].variables.parameter_table

    ;// very important that esi remain pointing at the parameter table

    mov sample_counter, SAMARY_LENGTH

    .IF pTrigTest               ;// do we care about t triggers ?

        xor iT_reg, iT_reg      ;// clear this incase we're a gate

        .IF bTrig_once          ;// do we only need to trigger test once ?

            mov pTrigReturn, tr_00

            jmp pTrigTest           ;// do first trigger test now

        tr_00:

            .IF pTrigTest == check_t_trig_pos_gate || pTrigTest == check_t_trig_neg_gate

                .IF iT_reg  ;// iT_reg is non zero if we got a trigger

                    ;// have to do the gate every time
                    jmp trigger_test_all    ;// kludge for now

                .ENDIF      ;// gate was off, so we continue like normal

            .ENDIF

            .IF pStepTest       ;// do we need to step test ?

                .IF bStep_once  ;// do we only need to step test once ?

                    jmp diff_fill_frame ;// then just fill the frame

                .ELSE           ;// need to step test every sample

                    jmp step_test_all   ;// jump down below

                .ENDIF

            .ELSE               ;// no step testing

                jmp diff_calc_full_speed    ;// jump to same routine far below

            .ENDIF

        .ELSE                   ;// need to trigger test every sample
        trigger_test_all:

            .IF pStepTest       ;// do we need to step test ?

                .IF bStep_once  ;// do we only need to step test once ?

                    mov pTrigReturn, tr_01
                    mov pStepReturn, st_01

                    jmp pStepTest   ;// do first step test now

                st_01:

                    ;// test remaining triggers
                    .REPEAT

                        jmp pTrigTest           ;// do a trigger test

                    tr_01:

                        DIFF_PRODUCE_OUTPUT     ;// output what needs output
                        DIFF_ITERATE_POINTERS   ;// iterate pointers

                        dec sample_counter      ;// iterate samples

                    .UNTIL ZERO?

                    DIFF_SET_OUTPUT_STATUS 1


                .ELSE           ;// need to step test every sample

                    mov pTrigReturn, tr_02
                    mov pStepReturn, st_02

                    .REPEAT

                        jmp pTrigTest           ;// do a trigger test

                    tr_02:

                        jmp pStepTest           ;// do a step test

                    st_02:

                        DIFF_PRODUCE_OUTPUT     ;// output what needs output
                        DIFF_ITERATE_POINTERS   ;// iterate pointers

                        dec sample_counter      ;// iterate samples

                    .UNTIL ZERO?

                    DIFF_SET_OUTPUT_STATUS 1

                .ENDIF

            .ELSE               ;// no step testing

                mov pTrigReturn, tr_03
                mov pStepReturn, st_03

                .REPEAT

                    jmp pTrigTest           ;// do a trigger test

                tr_03:

                    jmp pEquation           ;// do the equations and integration

                st_03:

                    DIFF_PRODUCE_OUTPUT     ;// output what needs output
                    DIFF_ITERATE_POINTERS   ;// iterate pointers

                    dec sample_counter      ;// iterate samples

                .UNTIL ZERO?

                DIFF_SET_OUTPUT_STATUS 1

            .ENDIF

        .ENDIF

    .ELSE                       ;// we don't care about t_triggers

        .IF pStepTest           ;// do we need to step test ?

            .IF bStep_once      ;// do we only need to step test once ?

            diff_fill_frame:    ;// jumped to from above

                mov pStepReturn, st_04

                jmp pStepTest       ;// do first step

            st_04:

                ;// single trigger may or may not have happened
                ;// so we check all the outputs and see if we need to
                ;// fill frame with new data

                mov edx, num_outputs
                lea ebx, outputs
                ASSUME ebx:PTR DIFF_OUTPUT

                .REPEAT

                    GET_PIN [ebx].pPin, esi ;// get the pin
                    mov eax, [ebx].source   ;// load the data source pointer
                    mov edi, [ebx].dest     ;// load wehere it was supposed to go
                    mov eax, DWORD PTR [eax];// load the data at the source

                    .IF [esi].dwStatus & PIN_CHANGING || \  ;// test pin changing
                        eax != DWORD PTR [edi]              ;// and different data
                        mov ecx, SAMARY_LENGTH              ;// load the frame length
                        rep stosd                           ;// store the new data
                    .ENDIF
                    and [esi].dwStatus, NOT PIN_CHANGING    ;// set data as not changing regardless

                    add ebx, SIZEOF DIFF_OUTPUT     ;// iterate the ouput pointer
                    dec edx                         ;// decrease the output count

                .UNTIL ZERO?

            .ELSE               ;// need to step test every sample

            step_test_all:  ;// jumped to from above

                ;// calculate remaining equation
                    mov pStepReturn, st_05

                    .REPEAT

                        jmp pStepTest           ;// do a step test

                    st_05:

                        DIFF_PRODUCE_OUTPUT     ;// output what needs output
                        DIFF_ITERATE_POINTERS   ;// iterate pointers

                        dec sample_counter      ;// iterate samples

                    .UNTIL ZERO?

                    DIFF_SET_OUTPUT_STATUS 1


            .ENDIF

        .ELSE                   ;// no step testing

        diff_calc_full_speed:


            ;// calulate full equation

                mov pStepReturn, st_06

                .REPEAT

                    jmp pEquation           ;// do the equations and integration

                st_06:

                    DIFF_PRODUCE_OUTPUT     ;// output what needs output
                    DIFF_ITERATE_POINTERS   ;// iterate pointers

                    dec sample_counter      ;// iterate samples

                .UNTIL ZERO?

                DIFF_SET_OUTPUT_STATUS 1

        .ENDIF

    .ENDIF


;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;///
;///
;///    E X I T
;///


    ;// store last triggers

        GET_OSC esi
        mov eax, lastS
        OSC_TO_PIN_INDEX esi, ebx, DIFF_APIN_S
        mov [ebx].dwUser, eax

        mov eax, lastT
        OSC_TO_PIN_INDEX esi, ebx, DIFF_APIN_T
        mov [ebx].dwUser, eax

    ;// see if we clipped

        mov ecx, [esi].dwUser

        .IF diff_clipping

            BITS ecx, DIFF_CLIP_NOW
            jc diff_clip_done

            mov eax, HINTI_OSC_GOT_BAD

        .ELSE

            BITR ecx, DIFF_CLIP_NOW
            jnc diff_clip_done

            mov eax, HINTI_OSC_LOST_BAD

        .ENDIF

        mov [esi].dwUser, ecx   ;// store the new state
        or [esi].dwHintI, eax   ;// set appropriate gdi commands
        .IF [esi].dwHintOsc & HINTOSC_STATE_ONSCREEN

            invoke play_Invalidate_osc  ;// send to IC list

        .ENDIF


    diff_clip_done:



    ;// tha's 'bout it




        ret



;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////


    ASSUME_AND_ALIGN
    check_t_trig_pos_edge:

        ;// do work
        mov edi, pT
        xor eax, eax
        mov ecx, DWORD PTR [edi]
        or eax,  lastT
        mov lastT, ecx
        .IF SIGN?   ;// negative now
            and eax, ecx        ;// test against new trigger
            .IF !SIGN?
                ;// got a trigger
                xor iT_reg, iT_reg      ;// reset the trigger doer
                jmp [pT_jump]   ;// call the routine
            .ENDIF
        .ENDIF

        ;// exit this
        jmp pTrigReturn

    ASSUME_AND_ALIGN
    check_t_trig_neg_edge:

        ;// do work
        mov edi, pT
        xor eax, eax
        mov ecx, DWORD PTR [edi]
        or eax,  lastT
        mov lastT, ecx
        .IF !SIGN?          ;// positive now?
            or eax, ecx ;// test against new trigger
            .IF SIGN?       ;// got a trigger
                xor iT_reg, iT_reg      ;// reset the trigger doer
                jmp [pT_jump]   ;// call the routine
            .ENDIF
        .ENDIF

        ;// exit this
        jmp pTrigReturn

    ASSUME_AND_ALIGN
    check_t_trig_both_edge:

        ;// do work
        mov edi, pT
        mov eax, lastT
        mov ecx, DWORD PTR [edi]
        xor eax, ecx
        mov lastT, ecx
        .IF SIGN?               ;// got a trigger
            xor iT_reg, iT_reg  ;// reset the trigger doer
            jmp [pT_jump]       ;// call the routine
        .ENDIF

        ;// exit this
        jmp pTrigReturn

    ASSUME_AND_ALIGN
    check_t_trig_pos_gate:

        ;// do work
        mov edi, pT
        test DWORD PTR [edi], 80000000h
        .IF ZERO?                   ;// positive now?
            xor iT_reg, iT_reg      ;// reset the trigger doer
            jmp [pT_jump]   ;// call the routine
        .ENDIF

        ;// exit this
        jmp pTrigReturn

    ASSUME_AND_ALIGN
    check_t_trig_neg_gate:

        ;// do work
        mov edi, pT
        test DWORD PTR [edi], 80000000h
        .IF !ZERO?                  ;// negatie now?
            xor iT_reg, iT_reg      ;// reset the trigger doer
            jmp [pT_jump]   ;// call the routine
        .ENDIF

        ;// exit this
        jmp pTrigReturn


;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////


    ASSUME_AND_ALIGN
    check_s_trig_pos:

        ;// do work
        mov edi, pS             ;// load pointer to S data
        xor eax, eax            ;// clear eax
        mov ecx, DWORD PTR [edi];// load the new S data
        or eax,  lastS          ;// test old data
        mov lastS, ecx          ;// store new value (cause it may be destroyed)
        .IF SIGN?               ;// negative now?
            and eax, ecx        ;// test against new trigger
            .IF !SIGN?          ;// got a trigger?

                jmp pEquation

            .ENDIF
        .ENDIF

        ;// exit this
        jmp pStepReturn

    ASSUME_AND_ALIGN
    check_s_trig_neg:

        ;// do work
        mov edi, pS             ;// load pointer to S data
        xor eax, eax            ;// clear eax
        mov ecx, DWORD PTR [edi];// load the new S data
        or eax,  lastS          ;// test old data
        mov lastS, ecx          ;// store new value (cause it may be destroyed)
        .IF !SIGN?              ;// positive now
            or eax, ecx         ;// test against new trigger
            .IF SIGN?           ;// got a trigger?

                jmp pEquation

            .ENDIF
        .ENDIF

        ;// exit this
        jmp pStepReturn

    ASSUME_AND_ALIGN
    check_s_trig_both:

        ;// do work
        mov edi, pS             ;// load pointer to S data
        mov eax, lastS
        mov ecx, DWORD PTR [edi];// load the new S data
        xor eax, ecx            ;// then test with same
        mov lastS, ecx          ;// store new lastS
        .IF SIGN?               ;// got a trigger?

            jmp pEquation

        .ENDIF

        ;// exit this
        jmp pStepReturn


;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
diff_linear:

    DIFF_DO_EQUATIONS   ;// do the equations
    jmp pDiffStack      ;// call the integrate pointer

;/////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////


    ;// diff stack computes the lower derivatives and values
    ;//
    ;//     there are four flavours to account for h and m


    ;//---------------------------------------------------------------------------------
    ;//;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;//---------------------------------------------------------------------------------

    ASSUME_AND_ALIGN
    diff_stack_nH_nM:   ;// ignore h and m

    ;// setup pointers and load fpu

        lea ebx, piles      ;// load the pile pointer
        mov ecx, num_piles  ;// load number of piles

        ;// loop through all the stacks

        ASSUME ebx:PTR DIFF_PILE
        ASSUME edi:PTR DWORD

        .REPEAT ;// loop through the stacks

            mov edi, [ebx].pTop     ;// load pointer to first pile
            mov edx, [ebx].count    ;// load the number of items in this pile

            fld  [edi]              ;// load top level first

            .REPEAT

                add edi, 4  ;// point at the next value

                fadd [edi]  ;// add it
                dec edx     ;// decease the counter
                fst [edi]   ;// store the new value

            .UNTIL ZERO?            ;// loop until this pile is done

            add ebx, SIZEOF DIFF_PILE   ;// iterate the pile pointer
            dec ecx
            fstp st         ;// dump the current value

        .UNTIL ZERO?

        jmp pClipTest       ;// clip test

    ;//---------------------------------------------------------------------------------
    ;//;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;//---------------------------------------------------------------------------------

    ASSUME_AND_ALIGN
    diff_stack_dH_nM:

    ;// use h and ignore m

        mov eax, pH         ;// load pointer to h
        lea ebx, piles      ;// load the pile pointer
        mov ecx, num_piles
        fld DWORD PTR [eax] ;// load the step size

        ;// loop through all the stacks

        ASSUME ebx:PTR DIFF_PILE
        ASSUME edi:PTR DWORD

        .REPEAT ;// loop through the stacks

            mov edi, [ebx].pTop     ;// load pointer to first pile
            mov edx, [ebx].count    ;// load the number of items in this pile

            fld  [edi]              ;// load top level first

            .REPEAT

                add edi, 4          ;// point at the next value

                fmul st, st(1)  ;// do the step size
                fadd [edi]      ;// the previous value

                dec edx             ;// decease the counter
                fst [edi]           ;// store the new value

            .UNTIL ZERO?            ;// loop until this pile is done

            add ebx, SIZEOF DIFF_PILE   ;// iterate the pile pointer
            dec ecx
            fstp st         ;// dump the current value

        .UNTIL ZERO?

        fstp st

        jmp pClipTest       ;// clip test


    ;//---------------------------------------------------------------------------------
    ;//;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;//---------------------------------------------------------------------------------

    ASSUME_AND_ALIGN
    diff_stack_nH_dM:

    ;// ignore h and use m

        mov eax, pM         ;// load pointer to M
        fld1
        mov ecx, num_piles
        fld DWORD PTR [eax] ;// load M
        lea ebx, piles      ;// load the pile pointer
        fabs
        fsub    ;// 1-M

        ;// loop through all the stacks

        ASSUME ebx:PTR DIFF_PILE
        ASSUME edi:PTR DWORD

        .REPEAT ;// loop through the stacks

            mov edi, [ebx].pTop     ;// load pointer to first pile
            mov edx, [ebx].count    ;// load the number of items in this pile

            fld  [edi]              ;// load top level first

            .REPEAT

                add edi, 4          ;// point at the next value

                fadd [edi]          ;// add the previous value
                fmul st, st(1)      ;// do the damping
                dec edx             ;// decease the counter
                fst [edi]           ;// store the new value

            .UNTIL ZERO?            ;// loop until this pile is done

            add ebx, SIZEOF DIFF_PILE   ;// iterate the pile pointer
            dec ecx
            fstp st         ;// dump the current value

        .UNTIL ZERO?

        fstp st

        jmp pClipTest       ;// clip test


    ;//---------------------------------------------------------------------------------
    ;//;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;//---------------------------------------------------------------------------------

    ASSUME_AND_ALIGN
    diff_stack_dH_dM:   ;// use m and h

    ;// setup pointers and load fpu

        mov eax, pM         ;// load pointer to m
        fld1
        mov ecx, num_piles  ;// load number of piles
        fld DWORD PTR [eax] ;// load the damping value
        mov eax, pH         ;// load pointer to h
        fabs
        lea ebx, piles      ;// load the pile pointer
        fsub
        fld DWORD PTR [eax] ;// load the step size

    ;// loop through all the stacks

        ASSUME ebx:PTR DIFF_PILE
        ASSUME edi:PTR DWORD

        .REPEAT ;// loop through the stacks

            mov edi, [ebx].pTop     ;// load pointer to first pile
            mov edx, [ebx].count    ;// load the number of items in this pile

            fld  [edi]              ;// load top level first

            .REPEAT

                add edi, 4      ;// point at the next value
                fmul st, st(1)  ;// do the step size
                fadd [edi]      ;// add it
                fmul st, st(2)  ;// do the damping
                dec edx         ;// decease the counter
                fst [edi]       ;// store the new value

            .UNTIL ZERO?        ;// loop until this pile is done

            add ebx, SIZEOF DIFF_PILE   ;// iterate the pile pointer
            dec ecx
            fstp st         ;// dump the current value

        .UNTIL ZERO?

        fstp st
        fstp st

        jmp pClipTest       ;// clip test

;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;//
;//                 esi and ebp must be preserved
;// runge kutta     the rest may be destroyed
;//


    ;// these macros simplify reading/writting the runge kutta code
    ;// all they do is return the correct address of the varaible in question

    IF ((OFFSET DIFF_EQUATION.rk_RX) - DIFF_NUM_DERIVATIVE*4) NE (OFFSET DIFF_EQUATION.cur_value)
        .ERR <code depends of DIFF_EQUATION.rk_RX immediately following cur_value>
    ENDIF
    IF ((OFFSET DIFF_EQUATION.rk_RA) - DIFF_NUM_DERIVATIVE*8) NE (OFFSET DIFF_EQUATION.cur_value)
        .ERR <code depends of DIFF_EQUATION.rk_RA immediately following DIFF_EQUATION.rk_RX>
    ENDIF

    DIFF_Pn     MACRO   reg:req
                EXITM <[reg]>
                ENDM

    DIFF_Pm     MACRO   reg:req
                EXITM <[reg-4]>
                ENDM

    DIFF_RXn    MACRO   reg:req
                EXITM <[reg+DIFF_NUM_DERIVATIVE*4]>
                ENDM

    DIFF_RXm    MACRO   reg:req
                EXITM <[reg+DIFF_NUM_DERIVATIVE*4-4]>
                ENDM

    DIFF_RAn    MACRO   reg:req
                EXITM <[reg+DIFF_NUM_DERIVATIVE*2*4]>
                ENDM


    DIFF_RAm    MACRO   reg:req
                EXITM <[reg+DIFF_NUM_DERIVATIVE*2*4-4]>
                ENDM

;// stage       setup           accumulate              prepare                     integration values
;// -------     ------------    ------------------      ------------------------    --------    --------
;// DIFF_DO_EQUATIONS
;// stage_1     RX[n] = P[n]    RA[m] = rf * P[m]       P[n] += hf * P[m]           rf = 1/6    hf = h/2
;// DIFF_DO_EQUATIONS
;// stage_2                     RA[m] += rf * P[m]      P[n] = hf * P[m] + RX[n]    rf = 1/3    hf = h/2
;// DIFF_DO_EQUATIONS
;// stage_3                     RA[m] += rf * P[m]      P[n] = hf * P[m] + RX[n]    rf = 1/3    hf = h
;// DIFF_DO_EQUATIONS
;// stage_4     P[n] = (( RA[m] + rf * P[m] ) * hf + RX[n] ) * m                    rf = 1/6    hf = h
;//             last iteration must store ( RA[m] + rf * P[m] )


ASSUME_AND_ALIGN
diff_rk_stage_123_nH:

    ASSUME edi:PTR DIFF_PILE    ;// edi scans piles
    ASSUME ebx:PTR DWORD        ;// ebx scans values in the pile

    ;///////////////////////////////////////////////////////////////////////////////////

    DIFF_DO_EQUATIONS

    ;///////////////////////////////////////////////////////////////////////////////////
    ;//
    ;// stage 1
    ;//

    ;// setup fpu

        fld math_1_2    ;// hf
        fld math_1_6    ;// rf      hf

    ;// scan piles

    mov ecx, num_piles          ;// ecx counts equation piles
    lea edi, piles              ;// load the pile pointer

    .REPEAT

        ;// get to the end of the pile

        mov edx, [edi].pTop         ;// load top of this pile pointer (ptr to cur_value)
        mov ebx, [edi].count        ;// get the length of the  pile
        lea ebx, [edx+ebx*4]        ;// scoot to the end

        .REPEAT

            ;// RX[n] = P[n]
            ;// RA[m] = rf * P[m]
            ;// P[n] += hf * P[m]           rf = 1/6    hf = h/2

            fld DIFF_Pm(ebx)    ;// Pm      rf      hf
            fld st(1)           ;// rf      Pm      rf      hf
            fmul st, st(1)      ;// Pm*rf   Pm      rf      hf
            fld st(3)           ;// hf      Pm*rf   Pm      rf      hf
            fmulp st(2), st     ;// Pm*rf   Pm*hf   rf      hf
            fstp DIFF_RAm(ebx)  ;// Pm*hf   rf      hf
            mov eax, DIFF_Pn(ebx)
            fld DIFF_Pn(ebx)    ;// Pn      Pm*hf   rf      hf
            fadd                ;// Pn+Pm*hf rf     hf
            mov DIFF_RXn(ebx), eax
            fstp DIFF_Pn(ebx)   ;// Pn+Pm*hf rf     hf

            sub ebx, 4          ;// iterate this pile

        .UNTIL ebx <= edx       ;// done yet ?

        add edi, SIZEOF DIFF_PILE   ;// advance to next pile
        dec ecx                     ;// decreasethe count remaining

    .UNTIL ZERO?    ;// done yet ?

    fstp st
    fstp st

    ;//
    ;// stage 1
    ;//
    ;///////////////////////////////////////////////////////////////////////////////////

    DIFF_DO_EQUATIONS

    ;///////////////////////////////////////////////////////////////////////////////////
    ;//
    ;// stage 2
    ;//

    ;// setup fpu

        fld math_1_2    ;// hf
        fld math_1_3    ;// rf      hf

    ;// scan piles

    mov ecx, num_piles          ;// ecx counts equation piles
    lea edi, piles              ;// load the pile pointer

    .REPEAT

        ;// get to the end of the pile

        mov edx, [edi].pTop         ;// load top of this pile pointer (ptr to cur_value)
        mov ebx, [edi].count        ;// get the length of the  pile
        lea ebx, [edx+ebx*4]        ;// scoot to last value

        .REPEAT

            ;// RA[m] += rf * P[m]
            ;// P[n] = hf * P[m] + RX[n]

            fld DIFF_Pm(ebx)    ;// Pm      rf      hf
            fld st(1)           ;// rf      Pm      rf      hf
            fmul st, st(1)      ;// Pm*rf   Pm      rf      hf

            fld st(3)           ;// hf      Pm*rf   Pm      rf      hf
            fmulp st(2), st     ;// Pm*rf   Pm*hf   rf      hf

            fld DIFF_RAm(ebx)   ;// RAm     Pm*rf   Pm*hf   rf      hf
            fadd                ;// RAm+Pm*rf   Pm*hf   rf      hf

            fld DIFF_RXn(ebx)   ;// RXn   RAm+Pm*rf Pm*hf   rf      hf
            faddp st(2), st     ;// RAm+Pm*rf   RXn+Pm*hf   rf      hf

            fstp DIFF_RAm(ebx)
            fstp DIFF_Pn(ebx)

            sub ebx, 4          ;// iterate this pile

        .UNTIL ebx <= edx

        add edi, SIZEOF DIFF_PILE   ;// advance to next pile
        dec ecx                     ;// decreasethe count remaining

    .UNTIL ZERO?    ;// done yet ?

    fstp st
    fstp st

    ;//
    ;// stage 2
    ;//
    ;///////////////////////////////////////////////////////////////////////////////////

    DIFF_DO_EQUATIONS

    ;///////////////////////////////////////////////////////////////////////////////////
    ;//
    ;// stage 3
    ;//

    ;// setup fpu

        fld math_1_3    ;// rf      hf=1, ignore

    ;// scan piles

    mov ecx, num_piles          ;// ecx counts equation piles
    lea edi, piles              ;// load the pile pointer

    .REPEAT

        ;// get to the end of the pile

        mov edx, [edi].pTop         ;// load top of this pile pointer (ptr to cur_value)
        mov ebx, [edi].count        ;// get the length of the  pile
        lea ebx, [edx+ebx*4]        ;// scoot to last value


        .REPEAT

            ;// RA[m] += rf * P[m]
            ;// P[n] = P[m] + RX[n]

            fld DIFF_Pm(ebx)    ;// Pm      rf
            fld st(1)           ;// rf      Pm      rf
            fmul st, st(1)      ;// Pm*rf   Pm      rf

            fld DIFF_RXn(ebx)   ;// RXn     Pm*rf   Pm      rf
            faddp st(2), st     ;// Pm*rf   Pm+RXn  rf
            fld DIFF_RAm(ebx)   ;// RAm     Pm*rf   Pm+RXn  rf
            fadd                ;// RAm+Pm*rf       Pm+RXn  rf
            fxch                ;// Pm+RXn  RAm+Pm*rf   rf

            fstp DIFF_Pn(ebx)
            fstp DIFF_RAm(ebx)

            sub ebx, 4          ;// iterate this pile

        .UNTIL ebx <= edx

        add edi, SIZEOF DIFF_PILE   ;// advance to next pile
        dec ecx                     ;// decreasethe count remaining

    .UNTIL ZERO?    ;// done yet ?

        fstp st

    ;//
    ;// stage 3
    ;//
    ;///////////////////////////////////////////////////////////////////////////////////

    jmp pEquation_2



ASSUME_AND_ALIGN
diff_rk_stage_123_dH:

    ASSUME edi:PTR DIFF_PILE    ;// edi scans piles
    ASSUME ebx:PTR DWORD        ;// ebx scans values in the pile

    ;///////////////////////////////////////////////////////////////////////////////////

    DIFF_DO_EQUATIONS

    ;///////////////////////////////////////////////////////////////////////////////////
    ;//
    ;// stage 1
    ;//

    ;// setup fpu

        mov eax, pH         ;// load pointer to h
        fld math_1_2    ;// hf
        fmul DWORD PTR [eax] ;// multiply by step size
        fld math_1_6    ;// rf      hf

    ;// scan piles

    mov ecx, num_piles          ;// ecx counts equation piles
    lea edi, piles              ;// load the pile pointer

    .REPEAT

        ;// get to the end of the pile

        mov edx, [edi].pTop         ;// load top of this pile pointer (ptr to cur_value)
        mov ebx, [edi].count        ;// get the length of the  pile
        lea ebx, [edx+ebx*4]        ;// scoot to the end

        .REPEAT

            ;// RX[n] = P[n]
            ;// RA[m] = rf * P[m]
            ;// P[n] += hf * P[m]           rf = 1/6    hf = h/2

            fld DIFF_Pm(ebx)    ;// Pm      rf      hf
            fld st(1)           ;// rf      Pm      rf      hf
            fmul st, st(1)      ;// Pm*rf   Pm      rf      hf
            fld st(3)           ;// hf      Pm*rf   Pm      rf      hf
            fmulp st(2), st     ;// Pm*rf   Pm*hf   rf      hf
            fstp DIFF_RAm(ebx)  ;// Pm*hf   rf      hf
            mov eax, DIFF_Pn(ebx)
            fld DIFF_Pn(ebx)    ;// Pn      Pm*hf   rf      hf
            fadd                ;// Pn+Pm*hf rf     hf
            mov DIFF_RXn(ebx), eax
            fstp DIFF_Pn(ebx)   ;// Pn+Pm*hf rf     hf

            sub ebx, 4          ;// iterate this pile

        .UNTIL ebx <= edx       ;// done yet ?

        add edi, SIZEOF DIFF_PILE   ;// advance to next pile
        dec ecx                     ;// decreasethe count remaining

    .UNTIL ZERO?    ;// done yet ?

    fstp st
    fstp st

    ;//
    ;// stage 1
    ;//
    ;///////////////////////////////////////////////////////////////////////////////////

    DIFF_DO_EQUATIONS

    ;///////////////////////////////////////////////////////////////////////////////////
    ;//
    ;// stage 2
    ;//

    ;// setup fpu

        mov eax, pH         ;// load pointer to h
        fld math_1_2    ;// hf
        fmul DWORD PTR [eax] ;// multiply by step size
        fld math_1_3    ;// rf      hf

    ;// scan piles

    mov ecx, num_piles          ;// ecx counts equation piles
    lea edi, piles              ;// load the pile pointer

    .REPEAT

        ;// get to the end of the pile

        mov edx, [edi].pTop         ;// load top of this pile pointer (ptr to cur_value)
        mov ebx, [edi].count        ;// get the length of the  pile
        lea ebx, [edx+ebx*4]        ;// scoot to last value

        .REPEAT

            ;// RA[m] += rf * P[m]
            ;// P[n] = hf * P[m] + RX[n]

            fld DIFF_Pm(ebx)    ;// Pm      rf      hf
            fld st(1)           ;// rf      Pm      rf      hf
            fmul st, st(1)      ;// Pm*rf   Pm      rf      hf

            fld st(3)           ;// hf      Pm*rf   Pm      rf      hf
            fmulp st(2), st     ;// Pm*rf   Pm*hf   rf      hf

            fld DIFF_RAm(ebx)   ;// RAm     Pm*rf   Pm*hf   rf      hf
            fadd                ;// RAm+Pm*rf   Pm*hf   rf      hf

            fld DIFF_RXn(ebx)   ;// RXn   RAm+Pm*rf Pm*hf   rf      hf
            faddp st(2), st     ;// RAm+Pm*rf   RXn+Pm*hf   rf      hf

            fstp DIFF_RAm(ebx)
            fstp DIFF_Pn(ebx)

            sub ebx, 4          ;// iterate this pile

        .UNTIL ebx <= edx

        add edi, SIZEOF DIFF_PILE   ;// advance to next pile
        dec ecx                     ;// decreasethe count remaining

    .UNTIL ZERO?    ;// done yet ?

    fstp st
    fstp st

    ;//
    ;// stage 2
    ;//
    ;///////////////////////////////////////////////////////////////////////////////////

    DIFF_DO_EQUATIONS

    ;///////////////////////////////////////////////////////////////////////////////////
    ;//
    ;// stage 3
    ;//

    ;// setup fpu

        mov eax, pH         ;// load pointer to h
        fld DWORD PTR [eax] ;// load the step size
        fld math_1_3        ;// rf      hf

    ;// scan piles

    mov ecx, num_piles          ;// ecx counts equation piles
    lea edi, piles              ;// load the pile pointer

    .REPEAT

        ;// get to the end of the pile

        mov edx, [edi].pTop         ;// load top of this pile pointer (ptr to cur_value)
        mov ebx, [edi].count        ;// get the length of the  pile
        lea ebx, [edx+ebx*4]        ;// scoot to last value

        .REPEAT

            ;// RA[m] += rf * P[m]
            ;// P[n] = hf * P[m] + RX[n]    rf = 1/3    hf = h

            fld DIFF_Pm(ebx)    ;// Pm      rf      hf
            fld st(1)           ;// rf      Pm      rf      hf
            fmul st, st(1)      ;// Pm*rf   Pm      rf      hf

            fld st(3)           ;// hf      Pm*rf   Pm      rf      hf
            fmulp st(2), st     ;// Pm*rf   Pm*hf   rf      hf

            fld DIFF_RXn(ebx)   ;// RXn     Pm*rf   Pm*hf       rf      hf
            faddp st(2), st     ;// Pm*rf   Pm*hf+RXn   rf      hf
            fld DIFF_RAm(ebx)   ;// RAm     Pm*rf   Pm+RXn  rf      hf
            fadd                ;// RAm+Pm*rf       Pm+RXn  rf      hf
            fxch                ;// Pm+RXn  RAm+Pm*rf   rf      hf

            fstp DIFF_Pn(ebx)
            fstp DIFF_RAm(ebx)

            sub ebx, 4          ;// iterate this pile

        .UNTIL ebx <= edx

        add edi, SIZEOF DIFF_PILE   ;// advance to next pile
        dec ecx                     ;// decreasethe count remaining

    .UNTIL ZERO?    ;// done yet ?

        fstp st
        fstp st

    ;//
    ;// stage 3
    ;//
    ;///////////////////////////////////////////////////////////////////////////////////

    jmp pEquation_2


















ASSUME_AND_ALIGN
diff_rk_stage_4_nH_nM:

    ASSUME edi:PTR DIFF_PILE    ;// edi scans piles
    ASSUME ebx:PTR DWORD        ;// ebx scans values in the pile

    ;///////////////////////////////////////////////////////////////////////////////////

    DIFF_DO_EQUATIONS

    ;///////////////////////////////////////////////////////////////////////////////////
    ;//
    ;// stage 4
    ;//
    ;// P[n] = (( RA[m] + rf * P[m] ) * hf + RX[n] ) * m        rf = 1/6    hf = h = 1
    ;//         last iteration must store ( RA[m] + rf * P[m] )

    ;// setup fpu

        fld math_1_6    ;// rf

    ;// scan piles

    mov ecx, num_piles          ;// ecx counts equation piles
    lea edi, piles              ;// load the pile pointer

    .REPEAT

        ;// get to the end of the pile

        mov edx, [edi].pTop         ;// load top of this pile pointer (ptr to cur_value)
        mov ebx, [edi].count        ;// get the length of the  pile
        lea ebx, [edx+ebx*4]        ;// scoot to last value
        add edx, 4  ;// need special for last iteration

        ;// ebx is at one passed of pile
        ;// edx points at start of pile

        .WHILE ebx > edx

            ;// P[n] = (RA[m] + rf * P[m]) + RX[n]

            fld DIFF_Pm(ebx)    ;// Pm      rf
            fmul st, st(1)      ;// rf*Pm   rf
            fld DIFF_RXn(ebx)   ;// RXn     rf*Pm   rf
            fld DIFF_RAm(ebx)   ;// RAm     RXn     rf*Pm   rf

            faddp st(2), st     ;// RXn     rf*Pm+RAm       rf
            fadd                ;// RXn+rf*Pm+RAm       rf
            fstp DIFF_Pn(ebx)   ;// rf

            sub ebx, 4          ;// iterate this pile

        .ENDW

        ;// P[n] = (RA[m] + rf * P[m]) + RX[n]
        ;// P[m] = (RA[m] + rf * P[m])

        fld DIFF_Pm(ebx)    ;// Pm      rf
        fmul st, st(1)      ;// rf*Pm   rf
        fld DIFF_RXn(ebx)   ;// RXn     rf*Pm   rf
        fld DIFF_RAm(ebx)   ;// RAm     RXn     rf*Pm   rf

        faddp st(2), st     ;// RXn     rf*Pm+RAm       rf
        add edi, SIZEOF DIFF_PILE   ;// advance to next pile
        fadd st, st(1)      ;// RXn+rf*Pm+RAm   rf*Pm+RAm   rf
        fxch                ;// rf*Pm+RAm   RXn+rf*Pm+RAm   rf
        fstp DIFF_Pm(ebx)   ;// RXn+rf*Pm+RAm   rf
        dec ecx                     ;// decreasethe count remaining
        fstp DIFF_Pn(ebx)   ;// rf

    .UNTIL ZERO?    ;// done yet ?

    fstp st

    ;//
    ;// stage 4
    ;//
    ;///////////////////////////////////////////////////////////////////////////////////

    jmp pClipTest








ASSUME_AND_ALIGN
diff_rk_stage_4_nH_dM:

    ASSUME edi:PTR DIFF_PILE    ;// edi scans piles
    ASSUME ebx:PTR DWORD        ;// ebx scans values in the pile

    ;///////////////////////////////////////////////////////////////////////////////////

    DIFF_DO_EQUATIONS

    ;///////////////////////////////////////////////////////////////////////////////////
    ;//
    ;// stage 4
    ;//
    ;// P[n] = (( RA[m] + rf * P[m] ) * hf + RX[n] ) * m        rf = 1/6    hf = h = 1
    ;//         last iteration must store ( RA[m] + rf * P[m] )

    ;// setup fpu
        fld1
        mov eax, pM
        fsub DWORD PTR [eax]    ;// m
        fabs
        fld math_1_6        ;// rf  m

    ;// scan piles

    mov ecx, num_piles          ;// ecx counts equation piles
    lea edi, piles              ;// load the pile pointer

    .REPEAT

        ;// get to the end of the pile

        mov edx, [edi].pTop         ;// load top of this pile pointer (ptr to cur_value)
        mov ebx, [edi].count        ;// get the length of the  pile
        lea ebx, [edx+ebx*4]        ;// scoot to last value
        add edx, 4  ;// need special for last iteration

        ;// ebx is at one passed of pile
        ;// edx points at start of pile

        .WHILE ebx > edx

            ;// P[n] = (( RA[m] + rf * P[m] ) * hf + RX[n] ) * m

            fld DIFF_Pm(ebx)    ;// Pm      rf      m
            fmul st, st(1)      ;// rf*Pm   rf      m
            fld DIFF_RXn(ebx)   ;// RXn     rf*Pm   rf      m
            fld DIFF_RAm(ebx)   ;// RAm     RXn     rf*Pm   rf      m

            faddp st(2), st     ;// RXn     rf*Pm+RAm       rf      m
            fadd                ;// RXn+rf*Pm+RAm       rf      m
            fmul st, st(2)
            fstp DIFF_Pn(ebx)   ;// rf

            sub ebx, 4          ;// iterate this pile

        .ENDW

        ;// P[n] = ((RA[m] + rf * P[m]) + RX[n])*m
        ;// P[m] = (RA[m] + rf * P[m])

        fld DIFF_Pm(ebx)    ;// Pm      rf      m
        fmul st, st(1)      ;// rf*Pm   rf      m
        fld DIFF_RXn(ebx)   ;// RXn     rf*Pm   rf      m
        fld DIFF_RAm(ebx)   ;// RAm     RXn     rf*Pm   rf      m

        faddp st(2), st     ;// RXn     rf*Pm+RAm       rf      m
        add edi, SIZEOF DIFF_PILE   ;// advance to next pile
        fadd st, st(1)      ;// RXn+rf*Pm+RAm   rf*Pm+RAm   rf      m
        fxch                ;// rf*Pm+RAm   RXn+rf*Pm+RAm   rf      m
        fstp DIFF_Pm(ebx)   ;// RXn+rf*Pm+RAm   rf      m
        fmul st, st(2)
        dec ecx                     ;// decreasethe count remaining
        fstp DIFF_Pn(ebx)   ;// rf

    .UNTIL ZERO?    ;// done yet ?

    fstp st
    fstp st

    ;//
    ;// stage 4
    ;//
    ;///////////////////////////////////////////////////////////////////////////////////

    jmp pClipTest







ASSUME_AND_ALIGN
diff_rk_stage_4_dH_nM:

    ASSUME edi:PTR DIFF_PILE    ;// edi scans piles
    ASSUME ebx:PTR DWORD        ;// ebx scans values in the pile

    ;///////////////////////////////////////////////////////////////////////////////////

    DIFF_DO_EQUATIONS

    ;///////////////////////////////////////////////////////////////////////////////////
    ;//
    ;// stage 4
    ;//
    ;// P[n] = (( RA[m] + rf * P[m] ) * hf + RX[n] ) * m        rf = 1/6    hf = h
    ;//         last iteration must store ( RA[m] + rf * P[m] )

    ;// setup fpu

        mov eax, pH         ;// load pointer to h
        fld DWORD PTR [eax] ;// load the step size
        fld math_1_6    ;// rf

    ;// scan piles

    mov ecx, num_piles          ;// ecx counts equation piles
    lea edi, piles              ;// load the pile pointer

    .REPEAT

        ;// get to the end of the pile

        mov edx, [edi].pTop         ;// load top of this pile pointer (ptr to cur_value)
        mov ebx, [edi].count        ;// get the length of the  pile
        lea ebx, [edx+ebx*4]        ;// scoot to last value
        add edx, 4  ;// need special for last iteration

        ;// ebx is at one passed of pile
        ;// edx points at start of pile

        .WHILE ebx > edx

            ;// P[n] = (RA[m] + rf * P[m]) * hf + RX[n]

            fld DIFF_Pm(ebx)    ;// Pm      rf      hf
            fmul st, st(1)      ;// rf*Pm   rf      hf
            fld DIFF_RXn(ebx)   ;// RXn     rf*Pm   rf      hf
            fld DIFF_RAm(ebx)   ;// RAm     RXn     rf*Pm   rf      hf

            faddp st(2), st     ;// RXn     rf*Pm+RAm       rf      hf
            fld st(3)           ;// hf      RXn     rf*Pm+RAm       rf      hf
            fmulp st(2), st     ;// RXn     (rf*Pm+RAm)*hf      rf      hf
            fadd                ;// RXn+rf*Pm+RAm       rf      hf
            fstp DIFF_Pn(ebx)   ;// rf      hf

            sub ebx, 4          ;// iterate this pile

        .ENDW

        ;// P[n] = (RA[m] + rf * P[m]) + RX[n]
        ;// P[m] = (RA[m] + rf * P[m])

        fld DIFF_Pm(ebx)    ;// Pm      rf      hf
        fmul st, st(1)      ;// rf*Pm   rf      hf
        fld DIFF_RXn(ebx)   ;// RXn     rf*Pm   rf      hf
        fld DIFF_RAm(ebx)   ;// RAm     RXn     rf*Pm   rf      hf

        faddp st(2), st     ;// RXn     rf*Pm+RAm       rf      hf

        fxch                ;// rf*Pm+RAm   RXn         rf      hf
        fst DIFF_Pm(ebx)
        fmul st,st(3)       ;// rf*Pm+RAm*h RXn         rf      hf
        add edi, SIZEOF DIFF_PILE   ;// advance to next pile
        fadd
        dec ecx                     ;// decreasethe count remaining
        fstp DIFF_Pn(ebx)   ;// rf

    .UNTIL ZERO?    ;// done yet ?

    fstp st
    fstp st

    ;//
    ;// stage 4
    ;//
    ;///////////////////////////////////////////////////////////////////////////////////

    jmp pClipTest




ASSUME_AND_ALIGN
diff_rk_stage_4_dH_dM:

    ASSUME edi:PTR DIFF_PILE    ;// edi scans piles
    ASSUME ebx:PTR DWORD        ;// ebx scans values in the pile

    ;///////////////////////////////////////////////////////////////////////////////////

    DIFF_DO_EQUATIONS

    ;///////////////////////////////////////////////////////////////////////////////////
    ;//
    ;// stage 4
    ;//
    ;// P[n] = (( RA[m] + rf * P[m] ) * hf + RX[n] ) * m        rf = 1/6    hf = h = 1
    ;//         last iteration must store ( RA[m] + rf * P[m] )

    ;// setup fpu
        fld1
        mov eax, pM
        fsub DWORD PTR [eax];// m
        mov eax, pH
        fabs
        fld DWORD PTR [eax] ;// h   m
        fld math_1_6        ;// rf  h   m

    ;// scan piles

    mov ecx, num_piles          ;// ecx counts equation piles
    lea edi, piles              ;// load the pile pointer

    .REPEAT

        ;// get to the end of the pile

        mov edx, [edi].pTop         ;// load top of this pile pointer (ptr to cur_value)
        mov ebx, [edi].count        ;// get the length of the  pile
        lea ebx, [edx+ebx*4]        ;// scoot to last value
        add edx, 4  ;// need special for last iteration

        ;// ebx is at one passed of pile
        ;// edx points at start of pile

        .WHILE ebx > edx

            ;// P[n] = (( RA[m] + rf * P[m] ) * hf + RX[n] ) * m

            fld DIFF_Pm(ebx)    ;// Pm      rf      h       m
            fmul st, st(1)      ;// rf*Pm   rf      h       m
            fld DIFF_RXn(ebx)   ;// RXn     rf*Pm   rf      h       m
            fld DIFF_RAm(ebx)   ;// RAm     RXn     rf*Pm   rf      h       m

            faddp st(2), st     ;// RXn     rf*Pm+RAm       rf      h       m
            fld st(3)           ;// h       RXn     rf*Pm+RAm       rf      h       m
            fmulp st(2), st     ;// RXn     rf*Pm+RAm*h     rf      h       m
            fadd                ;// RXn+rf*Pm+RAm       rf      h       m
            fmul st, st(3)      ;// *=m
            fstp DIFF_Pn(ebx)   ;// rf

            sub ebx, 4          ;// iterate this pile

        .ENDW

        ;// P[n] = ((RA[m] + rf * P[m]) + RX[n])*m
        ;// P[m] = (RA[m] + rf * P[m])

        fld DIFF_Pm(ebx)    ;// Pm      rf      h       m
        fmul st, st(1)      ;// rf*Pm   rf      h       m
        fld DIFF_RXn(ebx)   ;// RXn     rf*Pm   rf      h       m
        fld DIFF_RAm(ebx)   ;// RAm     RXn     rf*Pm   rf      h       m

        faddp st(2), st     ;// RXn     rf*Pm+RAm       rf      h       m

        fld st(3)           ;// h       RXn     rf*Pm+RAm       rf      h       m
        fmul st, st(2)      ;// (rf*Pm+RAm)*h       RXn     rf*Pm+RAm       rf      h       m
        fadd                ;// (rf*Pm+RAm)*h+RXn       rf*Pm+RAm       rf      h       m
        fmul st, st(4)      ;// *m
        add edi, SIZEOF DIFF_PILE   ;// advance to next pile

        fxch                ;// rf*Pm+RAm   Pn      rf      h       m

        fstp DIFF_Pm(ebx)   ;// Pn      rf      h       m
        dec ecx                     ;// decreasethe count remaining
        fstp DIFF_Pn(ebx)   ;// rf      h       m

    .UNTIL ZERO?    ;// done yet ?

    fstp st
    fstp st
    fstp st

    ;//
    ;// stage 4
    ;//
    ;///////////////////////////////////////////////////////////////////////////////////


    jmp pClipTest






;//---------------------------------------------------------------------------------
;//;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;//---------------------------------------------------------------------------------

    ;// clip test prevents overflow and denormals


    ASSUME_AND_ALIGN
    diff_clip_test_2:       ;// clip test at 2

        lea ebx, piles      ;// load the pile pointer
        mov ecx, num_piles  ;// load number of piles

        ;// loop through all the stacks

        ASSUME ebx:PTR DIFF_PILE
        ASSUME edi:PTR DWORD

        .REPEAT ;// loop through the stacks

            mov edi, [ebx].pTop     ;// load pointer to first pile
            mov edx, [ebx].count    ;// load the number of items in this pile

            .REPEAT

                .IF [edi]       & 40000000h ;// expnonet greater than 1 ?
                    and [edi],   0C0000000h ;// make the value = 2 and retain the sign
                    inc diff_clipping       ;// set the clipping flag
                .ELSEIF !([edi] & 70000000h)    ;// test for denormal
                    .IF [edi] &   07FFFFFFh ;// skip if zero
                        mov [edi], 0
                    .ENDIF
                .ENDIF

                add edi, 4          ;// point at the next value
                dec edx             ;// decease the counter

            .UNTIL SIGN?            ;// loop until this pile is done

            add ebx, SIZEOF DIFF_PILE   ;// iterate the pile pointer
            dec ecx

        .UNTIL ZERO?

        ;// done
        jmp pStepReturn


;////////////////////////////////////////////////////////////////////////////////////


    ASSUME_AND_ALIGN
    diff_clip_test_8:   ;// clip test at 8

        lea ebx, piles      ;// load the pile pointer
        mov ecx, num_piles  ;// load number of piles

        ;// loop through all the stacks

        ASSUME ebx:PTR DIFF_PILE
        ASSUME edi:PTR DWORD

        .REPEAT ;// loop through the stacks

            mov edi, [ebx].pTop     ;// load pointer to first pile
            mov edx, [ebx].count    ;// load the number of items in this pile

            .REPEAT

                .IF [edi] &         40000000h   ;// expnonet greater than 1 ?
                    .IF [edi] &     3F000000h   ;// expnonet greater than 2 ?
                        and [edi], 080000000h   ;// retain the sign
                        inc diff_clipping       ;// set the clipping flag
                        or  [edi],  41000000h   ;// make equal to 8
                    .ENDIF
                .ELSEIF !([edi] & 70000000h)    ;// test for denormal
                    .IF [edi] &   07FFFFFFh     ;// skip if zero
                        mov [edi], 0
                    .ENDIF
                .ENDIF

                add edi, 4          ;// point at the next value
                dec edx             ;// decease the counter

            .UNTIL SIGN?            ;// loop until this pile is done

            add ebx, SIZEOF DIFF_PILE   ;// iterate the pile pointer
            dec ecx

        .UNTIL ZERO?

        ;// done
        jmp pStepReturn

;////////////////////////////////////////////////////////////////////////////////////


;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////

    ;// do triggers
    ;// put these in groups so we can can have jump to the next
    ;// and overlap the load store operations

    ;// iT_reg indexer for the next three tables (register)
    ;// pT_jump[13] pointer to next block
    ;// pT_oper[12] pointer to triggered inputs data (what we're doing to the trigger data)
    ;// pT_data[12] pointer to target's data (source and dest)

    ;// these value may or may not be included in the iterate table

    ;// always call the first value in the jmp table

    ASSUME_AND_ALIGN
    do_trigger_E_2nd:

        fstp DWORD PTR [iD_reg]         ;// store previous results

    do_trigger_E_1st:

        mov iO_reg, [pT_oper+iT_reg*4]  ;// load the pointer to the oper value
        mov iD_reg, [pT_data+iT_reg*4]  ;// load pointer to the data value
        inc  iT_reg                     ;// increment the indexer

        fld  DWORD PTR [iO_reg] ;// load the value at that pointer
        jmp  [pT_jump+iT_reg*4] ;// jump to next section


    ASSUME_AND_ALIGN
    do_trigger_PE_2nd:

        fstp DWORD PTR [iD_reg]         ;// store previous results

    do_trigger_PE_1st:
        mov iO_reg, [pT_oper+iT_reg*4]  ;// load the pointer to the oper value
        mov iD_reg, [pT_data+iT_reg*4]  ;// load pointer to the data value
        inc  iT_reg                     ;// increment the indexer

        fld  DWORD PTR [iD_reg] ;// load the current data value
        fadd DWORD PTR [iO_reg] ;// add the trigger value
        jmp  [pT_jump+iT_reg*4] ;// jump to next section


    ASSUME_AND_ALIGN
    do_trigger_ME_2nd:

        fstp DWORD PTR [iD_reg]         ;// store previous results

    do_trigger_ME_1st:

        mov iO_reg, [pT_oper+iT_reg*4]  ;// load the pointer to the oper value
        mov iD_reg, [pT_data+iT_reg*4]  ;// load pointer to the data value
        inc iT_reg                      ;// increment the indexer

        fld  DWORD PTR [iD_reg] ;// load the current data value
        fmul DWORD PTR [iO_reg] ;// add the trigger value
        jmp  [pT_jump+iT_reg*4] ;// jump to next section


    ASSUME_AND_ALIGN
    do_trigger_last:

        fstp DWORD PTR [iD_reg]         ;// store previous results
        jmp pTrigReturn ;// exit this


;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////


;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////


diff_Calc ENDP

;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN

END

