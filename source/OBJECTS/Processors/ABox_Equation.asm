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
;//  ABox_Equation.asm   the new Function1 object
;//                      see osc_Equ_Ctor for how the conversion from
;//                      osc_func1 to this works
;//
;// TOC
;//
;// osc_Equ_Ctor
;// equ_kludge_ctor
;// osc_Equ_Dtor
;// osc_Equ_Render
;// osc_Equ_SetShape
;// osc_Equ_InitMenu
;// osc_Equ_Command
;// osc_Equ_SaveUndo
;// osc_Equ_LoadUndo
;// osc_Equ_AddExtraSize
;// osc_Equ_Write
;// osc_Equ_PrePlay
;// osc_Equ_Calc

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

;////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////


;// to use the equation system, we must define
;//     the forumula wrapper
;//     and the var_table

    ;// first we define the limits for this object

    OSC_EQU_MAX_FOR equ 128
    OSC_EQU_MAX_DIS equ OSC_EQU_MAX_FOR * 3 ;// hope changing this to three isn't a problem
    OSC_EQU_MAX_EXE equ 1024

    OSC_EQU_NUM_VAR equ 8
    OSC_EQU_MAX_VAR equ 24

    ;// then build the correct header struct for osc.data

    ;// equ data is defined in equation.inc

OSC_EQU_DATA    STRUCT

    ;// FORMULA HEADER
    for_head    EQU_FORMULA_HEADER{ OSC_EQU_MAX_FOR, OSC_EQU_MAX_DIS, OSC_EQU_MAX_EXE }
    for_buf     db OSC_EQU_MAX_FOR dup (0)
    dis_buf     db OSC_EQU_MAX_DIS dup (0)
    exe_buf     db OSC_EQU_MAX_EXE dup (0)

    ;// VARIABLE_HEADER
    var_head    EQU_VARIABLE_HEADER{ OSC_EQU_NUM_VAR, OSC_EQU_MAX_VAR }
    var_table   EQU_VARIABLE OSC_EQU_MAX_VAR dup ({})

    ;// extra for object
    extra   dd  0    ;// length of equation when stored

OSC_EQU_DATA    ENDS



;////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////


BASE_FLAGS = BASE_BUILDS_OWN_CONTAINER  OR  \
            BASE_SHAPE_EFFECTS_GEOMETRY OR  \
            BASE_WANT_EDIT_FOCUS_MSG    OR  \
            BASE_XLATE_DELETE           OR  \
            BASE_NO_KEYBOARD            OR  \
            BASE_WANT_POPUP_DEACTIVATE

osc_Equation OSC_CORE { osc_Equ_Ctor,osc_Equ_Dtor,osc_Equ_PrePlay,osc_Equ_Calc }
             OSC_GUI  { osc_Equ_Render,osc_Equ_SetShape,,,,
                osc_Equ_Command,osc_Equ_InitMenu,
                osc_Equ_Write,osc_Equ_AddExtraSize,
                osc_Equ_SaveUndo, osc_Equ_LoadUndo, osc_Equ_GetUnit }
             OSC_HARD { }

    ;// don't make the lines too long
    ofsPinData  = SIZEOF OSC_OBJECT+(SIZEOF APIN)*9
    ofsOscData  = SIZEOF OSC_OBJECT+(SIZEOF APIN)*9+SAMARY_SIZE
    oscBytes    = SIZEOF OSC_OBJECT+(SIZEOF APIN)*9+SAMARY_SIZE + SIZEOF OSC_EQU_DATA

    OSC_DATA_LAYOUT {NEXT_Equation,IDB_EQUATION,OFFSET popup_EQUATION,
        BASE_FLAGS,
        9,4,
        ofsPinData,
        ofsOscData,
        oscBytes    }

    OSC_DISPLAY_LAYOUT { 0,0, ICON_LAYOUT( 8,0,2,4 )}

    ;// this object has 8 input pins max, and one output
    ;// most of which will be hidden
    ;// the default locations as well as the object size will be reassigned
    ;// when the formula changes
    ;// but we need to allocate all of the these now

    ;// layout parameters

        EQU_MIN_WIDTH   equ 48
        EQU_MIN_HEIGHT  equ 24

        EQU_MAX_WIDTH   equ 192

        EQU_MARGIN_X    equ 4       ;// text margin
        EQU_MARGIN_Y    equ 4       ;// text margin

    ;// input pins

osc_Equ_APin \
        APIN_init {-0.9,, 'a' ,, UNIT_AUTO_UNIT }  ;// input
        APIN_init {+0.9,, 'b' ,, UNIT_AUTO_UNIT }  ;// input

        APIN_init {-0.6,, 'X' ,, UNIT_AUTO_UNIT }  ;// input
        APIN_init {-0.5,, 'Y' ,, UNIT_AUTO_UNIT }  ;// input
        APIN_init {-0.4,, 'Z' ,, UNIT_AUTO_UNIT }  ;// input

        APIN_init {0.6,, 'U' ,, UNIT_AUTO_UNIT }  ;// input
        APIN_init {0.5,, 'V' ,, UNIT_AUTO_UNIT }  ;// input
        APIN_init {0.4,, 'W' ,, UNIT_AUTO_UNIT }  ;// input

    ;// output pin

        APIN_init {0.0,, '=' ,, PIN_OUTPUT OR UNIT_AUTO_UNIT }   ;// output

        short_name  db  'Equa- tion',0
    EXTERNDEF equ_sz_desription:BYTE    ;// needed by diff_launch_editor
        equ_sz_desription LABEL BYTE
        description db  'Use this to build mathematical expressions with up to 8 variables. May also be used to create precise constant values.',0
        ALIGN 4

    ;// values for dwUser

        OSC_EQU_IS_EQUATION equ 80000000h   ;// must be set to load correctly

        OSC_EQU_SMALL_0     equ 00000000h   ;// i_small is not always stored in dwUser
        OSC_EQU_SMALL_1     equ 00000001h   ;// but gets xfered there when storing
        OSC_EQU_SMALL_2     equ 00000002h   ;// and loaded when loading
        OSC_EQU_SMALL_3     equ 00000003h
        OSC_EQU_SMALL_TEST  equ 00000003h


    ;// this prevents the dialog from tripping over itself

        equ_DialogBusy dd 0


    ;// osc map for this object

        OSC_MAP STRUCT

            OSC_OBJECT  {}

            pin_a   APIN    {}
            pin_b   APIN    {}

            pin_X   APIN    {}
            pin_Y   APIN    {}
            pin_Z   APIN    {}

            pin_U   APIN    {}
            pin_V   APIN    {}
            pin_W   APIN    {}
            pin_out APIN    {}

            equation    OSC_EQU_DATA    {}

        OSC_MAP ENDS



;//////////////////////////

;// convert from the old equations

    func1_convert dd func1_sin,func1_cos,func1_sqr,func1_sqrt, equ_m2f, equ_f2m
    .ERRNZ EQUATION_PRESET.formula  ;// must be first field

    func1_sin    db 'Sc*x)',0,0,0
    func1_cos    db 'Cc*x)',0,0,0
    func1_sqr    db 'x*x',0
    func1_sqrt   db 'QMx))',0,0,0

;// the presets are taken care of by equation.inc and equation.asm

;// equ_szDefault   db 'x',0
;// equ_szDefault   db '2+N0)',0


.CODE
;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////



;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////




ASSUME_AND_ALIGN
osc_Equ_Ctor PROC

    ;// register call
    ;// ASSUME ebp:PTR LIST_CONTEXT ;// preserve
    ;// ASSUME esi:PTR OSC_OBJECT   ;// preserve
    ;// ASSUME edi:PTR OSC_BASE     ;// may destroy
    ;// ASSUME ebx:PTR FILE_OSC     ;// may destroy
    ;// ASSUME edx:PTR FILE_HEADER  ;// may destroy

    equ_kludge_ctor PROTO STDCALL pObject:ptr OSC_OBJECT, pFile:PTR OSC_FILE, bFileHeader:DWORD
    invoke equ_kludge_ctor, esi, ebx, edx
    ret

osc_Equ_Ctor ENDP

equ_kludge_ctor PROC STDCALL uses esi edi pObject:ptr OSC_OBJECT, pFile:PTR OSC_FILE, bFileHeader:DWORD

    ;// we've been allocated
    ;// the default file bytes have been loaded ( dwUser )
    ;// the pins have NOT been initialized, but they do exist

    ;// load the rest of the formula
    ;// osc_Ctor (which called us ) will call SetBitmap after initializing the pins
    ;// and that's where we'll set all the pin flags

        GET_OSC ebx

    ;// define our formula header

        OSC_TO_DATA ebx, edi, OSC_EQU_DATA

        mov [edi].for_head.f_len_max, OSC_EQU_MAX_FOR
        mov [edi].for_head.d_len_max, OSC_EQU_MAX_DIS
        mov [edi].for_head.e_len_max, OSC_EQU_MAX_EXE
        mov [edi].for_head.bDirty, 1

    ;// define our equation variables

        mov [edi].var_head.num_var, OSC_EQU_NUM_VAR
        mov [edi].var_head.tot_num, OSC_EQU_MAX_VAR

        lea esi, osc_Equ_APin       ;// esi walks apin inits
        ASSUME esi:PTR APIN_init

        lea edx, [edi].var_table    ;// edx walks the variable table
        ASSUME edx:PTR EQU_VARIABLE

        push edi
        OSC_TO_PIN_INDEX ebx, edi, 0    ;// edi will assign pPin's

        xor ecx, ecx
        xor eax, eax
        mov ch, 'x'                 ;// cx will be the token name

        .REPEAT

            mov ax, [esi].wName             ;// get the text name (ah had better be zero)
            or  ax, 20h                     ;// make lower case
            mov WORD PTR [edx].textname, ax ;// store in table
            mov [edx].token, cx             ;// save the token name
            mov [edx].pPin, edi             ;// set he pPin pointer
            mov [edx].dwFlags, EVAR_AVAILABLE

            add esi, SIZEOF APIN_init
            add edi, SIZEOF APIN
            add edx, SIZEOF EQU_VARIABLE
            inc cx

        .UNTIL cx >= (OSC_EQU_NUM_VAR + ('x' SHL 8))


        pop edi
        ASSUME edi:PTR OSC_EQU_DATA

    ;// check if and how we're being initialized from a file

        .IF bFileHeader     ;// we are loading an equation from a file

            xor ecx, ecx
            or ecx, [ebx].dwUser    ;// OSC_EQU_IS_EQUATION is the sign bit

            ;// see if we're loading an ancient version of the file
            .IF SIGN?

                mov esi, pFile                  ;// point at file block
                add esi, SIZEOF FILE_OSC + 4    ;// point esi at the formula

            .ELSE

                ;// we are loading an old func 1 object from the days of yester year
                ;// so dwUser is actually an index to a function

                and ecx, 7                      ;// JIC
                mov esi, func1_convert[ecx*4]   ;// load the new formula
                mov [ebx].dwUser, 0             ;// clear out dwUser

            .ENDIF

        .ELSE   ;// not being loaded from file

            ;// use the default equation
            mov esi, OFFSET equ_default
            .ERRNZ EQUATION_PRESET.formula  ;// must be first field

        .ENDIF

    ;// then xfer to for_buf

        lea edi, [edi].for_buf
        .REPEAT
            lodsb
            stosb
        .UNTIL !al

    ;// make sure the equation gets built as required
    ;// and xfer the desired i_small to the formula header

        mov eax, [ebx].dwUser
        and eax, OSC_EQU_SMALL_TEST
        OSC_TO_DATA ebx, edi, OSC_EQU_DATA
        or [ebx].dwUser, OSC_EQU_IS_EQUATION
        mov [edi].for_head.i_small, eax
        
    ;ABOX242 -- AJT -- Using Virtual Protect to allow dynamicly generated code
    .IF pfVirtualProtect ;// does it even exist? if it does, then call it
        pushd 0                 ;// return val for lpOldProtect
        push esp                ;// ptr to OldProtect
        pushd 40h               ;// PAGE_EXECUTE_READWRITE
        pushd OSC_EQU_MAX_EXE   ;// dwSize
        lea eax, [edi].exe_buf  
        push eax                ;// lpAddress
        call pfVirtualProtect
        add esp, 4 ;-- not much we can do here ...
    .ENDIF

    ;// then we make sure we're compiled

        invoke equ_Compile, ADDR [edi].for_head, ADDR [edi].var_head, 1

    ;// that's it

        ret

equ_kludge_ctor ENDP

;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN

osc_Equ_Dtor PROC   ;// STDCALL pObject:PTR OSC_OBJECT

    ASSUME esi:PTR OSC_OBJECT

    .IF [esi].pContainer
        push [esi].pContainer
        call dib_Free
    .ENDIF

    ret

osc_Equ_Dtor ENDP




ASSUME_AND_ALIGN
osc_Equ_Render PROC

    ASSUME esi:PTR OSC_OBJECT

    ;// jump to osc render to exit

        jmp gdi_render_osc

osc_Equ_Render ENDP




;////////////////////////////////////////////////////////////////////
;//
;//
;//     osc_Equ_SetShape
;//

comment ~ /*

    determine the size nessesary to display the equation
    to do this we call drawtext with DT_CALC_RECT set
    this returns the required height and will account for the width
    -- or will it :( --

    so we set the fixed width, define the minimum height, then call the function

    if the dib has not been allocated, then allocate
    if the size has changed, we reallocate the dib

    then we rip through and make all the pin def x0 in the correct spot
     arrange like this:

        X   Y   Z
        -----------         ab spacing is H/3
     a-|           |        - spacing is W,H/2
       |           |-=
     b-|           |
        -----------
        U   V   W

*/ comment ~


ASSUME_AND_ALIGN
osc_Equ_SetShape PROC

        ASSUME esi:PTR OSC_OBJECT
        ASSUME ebp:PTR LIST_CONTEXT

        push edi
        push ebx

    ;// make sure we are compiled

        OSC_TO_DATA esi, edi, OSC_EQU_DATA
        .IF [edi].for_head.bDirty   ;// compile the equation
            invoke equ_Compile, ADDR [edi].for_head, ADDR [edi].var_head, 1
        .ENDIF

    ;// then tell gdi to deal with hiding pins

        lea edx,[edi].var_table             ;// point at the variables
        ASSUME edx:PTR EQU_VARIABLE         ;// edx iterates evars
        OSC_TO_PIN_INDEX esi, ebx, 0        ;// eax walks apins
        mov ecx, OSC_EQU_NUM_VAR            ;// ecx just counts

        .REPEAT

            DEBUG_IF <[edx].pPin !!= ebx>   ;// these are supposed to match

            mov eax, [edx].dwFlags
        push edx
            and eax, EVAR_IN_USE    ;// non zero for show
            invoke pin_Show, eax
        pop edx

            add ebx, SIZEOF APIN                    ;// advance pin pointer
            add edx, SIZEOF EQU_VARIABLE            ;// advance variable ptr
            dec ecx                                 ;// decrease the count

        .UNTIL ZERO?

    ;// make sure we have a container

        OSC_TO_CONTAINER esi, ebx, NOERROR
        .IF !ebx

            ;// need to allocate
            pushd EQU_MIN_HEIGHT
            pushd EQU_MIN_WIDTH
            pushd DIB_ALLOCATE_INTER
            call dib_Reallocate
            mov [esi].pContainer, eax
            mov ebx, eax

            mov edx, [ebx].shape.pSource
            mov [esi].pSource, edx

            invoke SelectObject, [ebx].shape.hDC, hFont_osc
            invoke SetBkMode, [ebx].shape.hDC, TRANSPARENT

        .ENDIF

    ;// determine the text size

        pushd EQU_MIN_HEIGHT    ;// create a format rect on the stack
        pushd EQU_MAX_WIDTH
        pushd 0
        pushd 0

        mov edx, esp

        invoke DrawTextA,
            [ebx].shape.hDC,
            [edi].for_head.pString,
            -1,
            edx, DT_WORDBREAK OR DT_CALCRECT OR DT_NOPREFIX

    ;// expand the rect to get the object size
    ;// and offset the format rect

        mov edx, (RECT PTR [esp]).bottom
        mov eax, (RECT PTR [esp]).right

        mov (RECT PTR [esp]).left, EQU_MARGIN_X
        mov (RECT PTR [esp]).top, EQU_MARGIN_Y

        add (RECT PTR [esp]).bottom, EQU_MARGIN_Y
        add (RECT PTR [esp]).right, EQU_MARGIN_X

        add edx, EQU_MARGIN_Y * 2
        add eax, EQU_MARGIN_X * 2

    ;// enforce minimum size

        .IF eax < EQU_MIN_WIDTH
            mov eax, EQU_MIN_WIDTH
        .ELSE
            add eax, 3
            and eax, 0FFFFFFFCh
        .ENDIF

        .IF edx < EQU_MIN_HEIGHT
            mov edx, EQU_MIN_HEIGHT
        .ENDIF

    ;// eax has the new width
    ;// edx has the new height

    ;// if new width and height are different, reassign the dib

        .IF eax != [ebx].shape.siz.x ||     \
            edx != [ebx].shape.siz.y

            push edx    ;// hieght
            push eax    ;// width
            push ebx    ;// current pointer
            call dib_Reallocate
            mov edx, [ebx].shape.pSource
            mov [esi].pSource, edx

        .ENDIF

    ;// osc_SetShape will do the object size for us

;// build our picture

    ;// fill and frame

        mov edx, F_COLOR_GROUP_PROCESSORS + 04040404h   ;// frame color
        mov eax, F_COLOR_GROUP_PROCESSORS + F_COLOR_GROUP_LAST - 05050505h  ;// back color
        invoke dib_FillAndFrame

    ;// draw the text

        mov eax, oBmp_palette[(COLOR_GROUP_PROCESSORS+04)*4]    ;// always set the text color
        BGR_TO_RGB eax
        invoke SetTextColor, [ebx].shape.hDC, eax
        mov edx, esp                                ;// point at format rect
        invoke DrawTextA,
            [ebx].shape.hDC,
            [edi].for_head.pString,
            -1,
            edx, DT_WORDBREAK OR DT_NOPREFIX

        add esp, SIZEOF RECT                        ;// done with format rect

    ;// by golly that just might do it

        pop ebx
        pop edi

        jmp osc_SetShape

osc_Equ_SetShape ENDP





;///////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////
;/////
;/////
;/////  U S E R   I N T E R F A C E
;/////
;/////
;/////


ASSUME_AND_ALIGN
osc_Equ_InitMenu PROC   ;// STDCALL uses esi pObject:DWORD

        ASSUME esi:PTR OSC_OBJECT
        ASSUME edi:PTR OSC_BASE

        mov equ_DialogBusy, 1

    ;// call the equation function to do this, and tell it to initialize

        OSC_TO_DATA esi, ecx, OSC_EQU_DATA
        invoke equ_InitDialog, popup_hWnd, esi, ADDR [ecx].for_head, ADDR [ecx].var_head, 1

    ;// then return zero or else

        xor eax, eax

        mov equ_DialogBusy, eax

    ;// return zero or whatever called this will resize

        ret

osc_Equ_InitMenu ENDP







;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////
;/////
;/////  o s c _ E q u _ C o m m a n d
;/////
;/////
ASSUME_AND_ALIGN
osc_Equ_Command PROC

    ;// eax has the command
    ASSUME esi:PTR OSC_OBJECT
    ASSUME ebp:PTR LIST_CONTEXT

    cmp equ_DialogBusy, 0
    jz @F

ignore_this:

    mov eax, POPUP_IGNORE

all_done:

    ret


@@: cmp eax, OSC_COMMAND_EDIT_CHANGE            ;// edit_messages must be ignored
    jz ignore_this

    cmp eax, OSC_COMMAND_POPUP_DEACTIVATE       ;// deactivate must close the editor
    jnz @F

        invoke equ_EditDtor
        mov eax, POPUP_CLOSE    ;// close the dialog
        jmp all_done

    ;// take care of standard interface

@@: cmp eax, COMMAND_DELETE
    je osc_Command
    cmp eax, COMMAND_CLONE
    je osc_Command
    cmp eax, VK_SHIFT   ;// COMMAND_SELECT
    je osc_Command
    cmp eax, VK_CONTROL ;// COMMAND_UNSELECT
    je osc_Command

    ;// assume that any other key is ok to send to equation editor

        mov equ_DialogBusy, 1
        invoke equ_Command, popup_hWnd, eax
        mov equ_DialogBusy, 0

        push eax
        invoke SetFocus, popup_hWnd     ;// ABOX234: make sure we can keep sending keystrokes
        pop eax

    ;// eax has the correct return value

        bt eax, LOG2(POPUP_REDRAW_OBJECT)
        jnc all_done

    ;// make sure we get rebuilt

        OSC_TO_DATA esi, ecx, OSC_EQU_DATA
        .IF [ecx].for_head.bDirty   ;// compile the equation
        push eax
            invoke equ_Compile, ADDR [ecx].for_head, ADDR [ecx].var_head, 1
        pop eax
        .ENDIF

        GDI_INVALIDATE_OSC HINTI_OSC_SHAPE_CHANGED  ;// make sure we get a ride through setshape

        jmp all_done

osc_Equ_Command ENDP



;////////////////////////////////////////////////////////////////////
;//
;//
;//     _SaveUndo
;//

ASSUME_AND_ALIGN
osc_Equ_SaveUndo    PROC

        ASSUME esi:PTR OSC_OBJECT

    ;// edx enters as either UNREDO_CONTROL_OSC or UNREDO_COMMAND
    ;// edi enters as where to store
    ;//
    ;// task:   1) save nessary data
    ;//         2) iterate edi
    ;//
    ;// may use all registers except ebp


    ;// save dwuser

        mov eax, [esi].dwUser
        stosd

    ;// save the formula

        OSC_TO_DATA esi, esi, OSC_EQU_DATA
        lea esi, [esi].for_buf
        mov ecx, OSC_EQU_MAX_FOR / 4
        rep movsd

    ;// that's it

        ret

osc_Equ_SaveUndo ENDP
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
osc_Equ_LoadUndo PROC uses esi

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


    ;// load dwUser

        mov eax, [edi]
        mov [esi].dwUser, eax
        or [esi].dwHintI, HINTI_OSC_SHAPE_CHANGED   ;// make sure we get a ride through setshape

    ;// load the equation

        add edi, 4

        OSC_TO_DATA esi, esi, OSC_EQU_DATA
        inc [esi].for_head.bDirty
        push esi
        lea esi, [esi].for_buf
        mov ecx, OSC_EQU_MAX_FOR / 4
        xchg esi, edi
        rep movsd

    ;// make sure we get rebuilt

        pop esi

        invoke equ_Compile, ADDR [esi].for_head, ADDR [esi].var_head, 1

    ;// that should do it

        ret

osc_Equ_LoadUndo ENDP

;//
;//
;//     _LoadUndo
;//
;////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////
;//
;//
;//     _GetUnit
;//

ASSUME_AND_ALIGN
osc_Equ_GetUnit PROC

        ASSUME esi:PTR OSC_MAP      ;// must preserve
        ASSUME ebx:PTR APIN         ;// must preserve

        clc     ;// we never know
        ret

osc_Equ_GetUnit ENDP

;//
;//
;//     _GetUnit
;//
;////////////////////////////////////////////////////////////////////




;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////



ASSUME_AND_ALIGN
osc_Equ_AddExtraSize PROC

    ASSUME esi:PTR OSC_OBJECT
    ASSUME ebx:PTR DWORD

    ;// we accumulate how many bytes we need to store our formula

    ;// determine current size of equation

    OSC_TO_DATA esi,ecx, OSC_EQU_DATA
    xor eax, eax            ;// clear for counting
    lea edx, [ecx].for_buf  ;// point at formula buffer
    STRLEN edx              ;// do the length
    add eax, 5              ;// bump for nul terminator plus sizeof dwUser
    mov [ecx].extra, eax    ;// store for later
    add [ebx],eax           ;// accumulate to passed pointer

    ret

osc_Equ_AddExtraSize ENDP





ASSUME_AND_ALIGN
osc_Equ_Write PROC uses esi ;// STDCALL uses esi edi pObject:PTR OSC_OBJECT, pFile:ptr FILE_OSC

    ;// this is called AFTER the pBase and position have been written
    ;// and BEFORE the pin table is written
    ;// our job is to store our extra count, dwUser, and equation
    ;// we MUST iterate to the pin table
    ;// also make sure that small is stored in dword user


    ASSUME esi:PTR OSC_OBJECT   ;// preserve
    ASSUME edi:PTR FILE_OSC     ;// iterate
    ;// ebx is destroyed

    ;// write our stuff

    lea edi, [edi].extra        ;// extra is the last dword in the file header

    OSC_TO_DATA esi, ebx, OSC_EQU_DATA
    mov ecx, [ebx].extra        ;// load our extra count (ecx will be used below)

    .IF !ecx                    ;// groups don't call the getWsize, so we do it now
        xor eax, eax            ;// clear for counting
        lea edx, [ebx].for_buf  ;// load the start of for buffer
        STRLEN edx              ;// determine the length
        add eax, 5              ;// bump for nul terminator and dw user
        mov [ebx].extra, eax    ;// store for later
        mov ecx, eax            ;// xfer to ecx

    .ELSE

        mov eax, ecx            ;// xfer count to ecx

    .ENDIF

    stosd                       ;// store the extra count

    ;// prepare a dwUser value

    mov eax, [ebx].for_head.i_small
    or eax, OSC_EQU_IS_EQUATION
    stosd                   ;// store as dwuser

    ;// store the equation

    sub ecx, 4
    lea esi, [ebx].for_buf
    rep movsb

    ;// now edi is at the pin table

    ;// that's it should do it

    ret

osc_Equ_Write ENDP


;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
osc_Equ_PrePlay PROC    ;//  STDCALL uses esi edi pObject:PTR OSC_OBJECT

    ;// here we want to reset all the internals
    ;// return zero if we want play_preplay to reset our data

    xor eax, eax

    ret

osc_Equ_PrePlay ENDP




;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
.CODE

ASSUME_AND_ALIGN
osc_Equ_Calc PROC uses esi  ;//  STDCALL uses esi edi pObject:PTR OSC_OBJECT

    LOCAL iter[8]:DWORD ;// ptr to eVar[]
    LOCAL numIter:DWORD ;// number of entries in table

    ;// ASSUME esi:PTR OSC_OBJECT

    GET_OSC_FROM ebx, esi
    OSC_TO_PIN_INDEX ebx, edi, 8    ;// get the output pin
    .IF [edi].pPin                  ;// connected ?

;//----------------------------------------------------------------------------

        OSC_TO_DATA ebx, ebx, OSC_EQU_DATA  ;// ebx is the equation pointer

;//----------------------------------------------------------------------------

    ;// sanity check
    IFDEF DEBUGBUILD
        .IF [ebx].for_head.bDirty
            int 3   ;// supposed to be compiled by now
        .ENDIF
    ENDIF

;//----------------------------------------------------------------------------

    ;// build the iterate table

    ;// we want to scan through ePin
    ;// if a pin is used
    ;//  get the apin for that entry
    ;// if the pin is connected
    ;//  set it's data pointer to the correct eVar
    ;//  if the pin is changing,
    ;//      add the eVar.value pointer to the iter list
    ;// else
    ;//  set the eVar pointer to math_pNull

        mov numIter, 0
        mov ecx, OSC_EQU_NUM_VAR        ;// check maximum of 8 inputs
        lea esi, [ebx].var_table        ;// edi walks variables
        ASSUME esi:PTR EQU_VARIABLE

        .REPEAT

            .IF [esi].dwFlags & EVAR_IN_USE ;// variable used ?

                GET_PIN [esi].pPin, edx     ;// get the pin assigned to this variable
                xor eax, eax
                OR_GET_PIN [edx].pPin, eax  ;// load and test connection
                .IF !ZERO?                  ;// pin connected ?

                    .IF [eax].dwStatus & PIN_CHANGING   ;// is it changing as well ?
                        mov edx, numIter        ;// load num iter
                        inc numIter             ;// advance numIter ators
                        mov iter[edx*4], esi    ;// store in iter table
                                                ;// value is the first entry in equ_variable
                    .ENDIF

                    mov eax, [eax].pData    ;// get the data pointer

                .ELSE                       ;// pin not connected

                    mov eax, math_pNull     ;// load the zero pointer

                .ENDIF

                mov [esi].value, eax    ;// store data pointer in eVar.value

            .ENDIF

            add esi, SIZEOF EQU_VARIABLE
            dec ecx

        .UNTIL ZERO?

    ;// now we know what pins need iterated

;//-------------------------------------------------------------------------

    ;// determine how to calculate
    ;// these are common to both types of calculation

    lea esi, [ebx].var_table    ;// load esi as the eVar pointer
    lea ebx, [ebx].exe_buf      ;// load the calc pointer

    .IF numIter

        ;// there are items that need iterated
        ;// so the output is changing
        ;////////////////////////////////////////////////////////////////
        ;//
        ;//  version with at least one iterator
        ;//
        ;//--------------------------------------------------------------
            or [edi].dwStatus, PIN_CHANGING ;// set the changing bit
            mov edi, [edi].pData            ;// edi is now output data
            mov ecx, SAMARY_LENGTH          ;// load the number of samples
        ;//--------------------------------------------------------------
        next_sample:
            call ebx            ;// call the calc function
            ;// --> range check
            fstp DWORD PTR [edi];// store output
            mov edx, numIter    ;// reload this now
            dec ecx             ;// decrease sample count
            jz AllDone          ;// jmp if done
            add edi, 4          ;// advance output iterator
        ;//--------------------------------------------------------------
        @@: dec edx             ;// decrease index
            mov eax, iter[edx*4];// load the eVar pointer
            js next_sample      ;// jump if done
            add DWORD PTR [eax], 4  ;// advance the eVar iterator
            jmp @B              ;// do it again
        ;//--------------------------------------------------------------
        ;//
        ;//  version with at least one iterator
        ;//
        ;////////////////////////////////////////////////////////////////

    .ENDIF

    ;// there are no items that need iterated
    ;// so we only calc once
    ;// and then check if we need to store the entire frame
    ;////////////////////////////////////////////////////////
    ;//
    ;//  version with no iterators
    ;//
    ;//-------------------------------------------------------

        call ebx            ;// call the calc function
        ;// --> range check
        fstp numIter        ;// store output in temp

        mov edx, [edi].dwStatus                 ;// get previous status
        and [edi].dwStatus, NOT PIN_CHANGING    ;// set new status
        mov eax, numIter                        ;// load equation results
        mov edi, [edi].pData                    ;// edi is now output data

        .IF (edx & PIN_CHANGING) || (eax != DWORD PTR [edi])

            ;// have to store all
            mov ecx, SAMARY_LENGTH
            rep stosd

        .ENDIF

    ;//-------------------------------------------------------
    ;//
    ;//  version with no iterators
    ;//
    ;////////////////////////////////////////////////////////

    .ENDIF  ;// output connected

AllDone:



    ret

osc_Equ_Calc ENDP


ASSUME_AND_ALIGN


ENDIF ;// USE_THIS_FILE



END

