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
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;//
;//   ABox_ADSR.asm     simple linear ADSR
;//                     there are four control points
;//
;//
;// TOC
;//
;// adsr_CalcCoeff
;// adsr_SyncControls
;// adsr_DrawLines
;// adsr_SyncPins
;// adsr_GetUnit
;// adsr_Ctor
;// adsr_Dtor
;// adsr_PrePlay
;// adsr_SetShape
;// adsr_Render
;// adsr_HitTest
;// adsr_Control
;// adsr_InitMenu
;// adsr_Command
;// adsr_SaveUndo
;// adsr_LoadUndo
;// adsr_Calc






comment ~ /*

    New for ABox2

    this object maintains a small dib to draw lines on
    the 'o' character is used to display the controls

    the dib is blitted to the gdi surface
    then the control shapes are blitted on top of that

    there is a four pixel border around the control area
    the P points are assumed to referenced to that
    the P points are drawn after ofsetting them by the border
    the P points are hit tested after offsetting them

    there is also a smal version, which uses the fftop container

    so we store the dib in adsr.dib so we don't loose track of it

    then for abox211 we get two new settings and a new calc function

    ABOX232: fixed calc for accurate timing
             had to include old calc, impossible to exactly duplicate the error


general comments and numberings

    the ADSR has 6 stages
    these are two classes, ramp and wait
    see calc_notes for specific details on wait and ramp


stage    0       1      2         3           4         5      0
name     start   attack decay     sustain     release   final  start
type     wait    ramp   ramp      wait        ramp      ramp   wait
                 |      |         |           |         |      |
                 |      *         |           |         *      |
                 |     / \        |           |        / \     |
                 |    /   \       |           |       /   \    |
                 |   /     \      |           |      /     \   |
                 |  /       \     |           |     /       \  |
                 | /         \    |           |    /         \ |
                 |/           \   |           |   /           \|
      -----------*             \  |           |  /             *--------
                                \ |           | /
                                 \|           |/
                                  *-----------*                          P0 and P6 have the same y
P point          P1     P2        P34                   P5               3 and 4 are the same point
R point          R1     R2        R34                   R5               R0 is fixed at {0,0}
slope              dYdX12  dYdX23                dYdX45   dYdX56         R6 is fixed at {1,0}

indexes are set at the start of the stage

math

    setup

        R points are scaled from integer P points dependant on graphical size of object

        R.x represents the beginning X the stage
        R.y represents the beginning Y of the stage

        dYdXmn are derived from Rm and Rn

    calculation

        a phase variable X sweeps from 0 to 1 at rate of dX/dS
        the value of dX depends on the input to the T pin
        thus it may change between samples

        the output value Y advances at rate of dY/dX * dX/dS

        a stage is finished when X passes the beginning of the next stage

        when X passes, we bounce off the boundary
        we may bounce several times if dYdX is big enough



*/ comment ~

OPTION CASEMAP:NONE

.586
.MODEL FLAT

USE_THIS_FILE equ 1

IFDEF USE_THIS_FILE


        .NOLIST
        include <Abox.inc>
        .LIST
        ;//.LISTALL

.DATA



;// private data


    pShape_o_mask   dd  0   ;// font 'o' for drawing the controls
    pShape_O_mask   dd  0   ;// font 'O' for drawing the hovers


;// data structure to run the adsr

        OSC_ADSR struct

            ;// the four control points,
            ;// relative to top left of the boundry

                P1  POINT {}   ;// saved
                P2  POINT {}   ;// saved
                P34 POINT {}   ;// saved
                P5  POINT {}   ;// saved

            ;// calculated values, these are REAL4's
            ;// use Qn.x to check for end of stage
            ;// use Qn.y as start value to store and iterate

                Q1  fPOINT  {}
                R2  fPOINT  {}
                R34 fPOINT  {}
                R5  fPOINT  {}
                R6  fPOINT  {}

                dYdX12 REAL4 0.0e+0 ;//  slope of attack stage
                dYdX23 REAL4 0.0e+0 ;//  slope of decay stage
                dYdX45 REAL4 0.0e+0 ;//  slope of release stage
                dYdX56 REAL4 0.0e+0 ;//  slope of final stage

            ;// for painting and mousing, it behoves us to save these,
            ;// rather than recalculate all the time
            ;// be sure to ADD them to the object's pDest

                pDest_offset_P1  dd 0
                pDest_offset_P2  dd 0
                pDest_offset_P34 dd 0
                pDest_offset_P5  dd 0
                pDest_offset_P6  dd 0

            ;// lastly, we track running values here, rather than pin.dwUser

                stage   dd  0   ;// stage we need to account for
                last_t  dd  0   ;// last t_value we got

                last_dXdS dd    0   ;// dX value we got (not always used)
                last_Y  dd  0   ;// last Y value we stored
                last_X  dd  0   ;// last X value we worked with

            ;// then we need to store our dib

                dib dd  0   ;//

        OSC_ADSR ENDS


;// defines to save space

    ;// status + the four points
    ADSR_FILE_EXTRA equ 4 + (SIZEOF POINT)*4
    ADSR_OBJECT_SIZE equ SIZEOF OSC_OBJECT + (SIZEOF APIN * 3)

;// adsr object definition

osc_ADSR OSC_CORE { adsr_Ctor,adsr_Dtor,adsr_PrePlay,adsr_Calc }
         OSC_GUI  { adsr_Render,adsr_SetShape,
                    adsr_HitTest,adsr_Control,,
                    adsr_Command,adsr_InitMenu,,,
                    adsr_SaveUndo, adsr_LoadUndo, adsr_GetUnit }
         OSC_HARD { }

    ADSR_BASE EQU   BASE_BUILDS_OWN_CONTAINER OR \
                    BASE_SHAPE_EFFECTS_GEOMETRY OR \
                    BASE_NEED_THREE_LINES

    OSC_DATA_LAYOUT {NEXT_ADSR,IDB_ADSR,OFFSET popup_ADSR,ADSR_BASE,
        3,ADSR_FILE_EXTRA,
        ADSR_OBJECT_SIZE,
        ADSR_OBJECT_SIZE + SAMARY_SIZE,
        ADSR_OBJECT_SIZE + SAMARY_SIZE + SIZEOF OSC_ADSR }

    OSC_DISPLAY_LAYOUT {0,0,ICON_LAYOUT(4,1,3,2)}

    APIN_init {-0.9,sz_Time, 'T',, UNIT_SECONDS }                   ;// dQ
    APIN_init { 0.9,,        't',, PIN_LOGIC_INPUT OR UNIT_LOGIC }  ;// trigger
    APIN_init {-0.0,,        '=',, PIN_OUTPUT OR UNIT_AUTO_UNIT }   ;// envelope output

    short_name  db  'ADSR',0
    description db  '4 stage envelope generator. Adjust the control points with the mouse. Vertical range is always 1.0. The base line sets the zero points.',0
    ALIGN 4

    ;// values for object.dwUser
    ;//
    ;// note: the top 4 bits are reserved for the calc function
    ;//
    ;// NEVER USE TOP FOUR BITS !!!!!!!!!!!!!

        ;// hover states (leave these at the bottom!)

            ADSR_HOVER_P1   equ         1 ;// also includes P6
            ADSR_HOVER_P2   equ         2 ;//
            ADSR_HOVER_P34  equ         3 ;//
            ADSR_HOVER_P5   equ         4 ;//
            ADSR_HOVER_TEST equ 000000007h
            ADSR_HOVER_MASK equ 0FFFFFFF8h ;// used to zero the hover bits

        ;// ABOX232 preserves the old stage loop, this bit is set to use the new stage loop

            ADSR_232            EQU     00000800h

        ;// dwUser flags

            ADSR_NOSUSTAIN      equ     00001000h
            ADSR_NORETRIGGER    equ     00002000h

            ADSR_START_POS      equ     00004000h   ;// if both are off then this is the old version
            ADSR_START_NEG      equ     00008000h   ;// (ver<1.37), so we set to pos in the constructor
            ADSR_START_TEST     equ     0000C000h
            ADSR_START_MASK     equ    0FFFF3FFFh

            ADSR_SMALL          equ     00010000h   ;// display in small mode

            ADSR_IGNORE_T       equ     00020000h   ;// ignore T until trigger

            ADSR_AUTORESTART    equ     00040000h   ;// start automatically

        ;// then these are used to cache the gdi state

            ADSR_INVALID_Q      equ     00080000h   ;// the Q values are invalid
            ADSR_INVALID_PDEST  equ     00100000h   ;// the control pDests are invalid
            ADSR_INVALID_LINES  equ     00200000h   ;// the lines need redrawn
            ADSR_INVALID_PINS   equ     00400000h   ;// cascade pin has changed state

    ;// sizes

        ADSR_SIZE_X equ 136     ;// total size of the rect
        ADSR_SIZE_Y equ 56

        ADSR_OFS_X  equ 4       ;// offset to adsr rect (where the controls are)
        ADSR_OFS_Y  equ 4       ;//    acts as a border spec

        ADSR_WIDTH  EQU ADSR_SIZE_X - 2*ADSR_OFS_X
        ADSR_HEIGHT EQU ADSR_SIZE_Y - 2*ADSR_OFS_Y

        ADSR_SMALL_ADJUST_X equ 48
        ADSR_SMALL_ADJUST_Y equ 18

    ;// ADSR gdi

        adsr_Scale_X_old    REAL4 7.815e-3          ;// 1/width
        adsr_Scale_X_232    REAL4 7.8125e-3 ;// ABOX232: bah! got the number wrong
        adsr_Scale_Y        REAL4 20.8333333333e-3  ;// 1/height

        sz_adsr_old db  'old',0

    ;// this object's osc map


        ADSR_OSC_MAP STRUCT

                    OSC_OBJECT  {}
            pin_T   APIN    {}
            pin_t   APIN    {}
            pin_X   APIN    {}
            data_X  dd SAMARY_LENGTH dup (0)
            adsr    OSC_ADSR {}

        ADSR_OSC_MAP ENDS




.CODE






ASSUME_AND_ALIGN
adsr_CalcCoeff PROC

    ;// here we convert the control positions to Q values

    ;// this validates ADSR_INVALID_Q

    ASSUME esi:PTR OSC_OBJECT

    OSC_TO_DATA esi, edi, OSC_ADSR

    and [esi].dwUser, NOT ADSR_INVALID_Q    ;// shut off the invalid bit

    ;// set up the Q values, by translating P points into Q space
    ;// P coords are reletive to inside left top, with y going down

        ;// Y coords first

        fldz
        fst [edi].Q1.y
        fstp [edi].R6.y

        fild [edi].P1.y

        fld st
        fisub [edi].P2.y
        fmul adsr_Scale_Y
        fstp [edi].R2.y

        fld st
        fisub [edi].P34.y
        fmul adsr_Scale_Y
        fstp [edi].R34.y

        fisub [edi].P5.y
        fmul adsr_Scale_Y
        fstp [edi].R5.y

        ;// then the X's

        fldz
        fstp [edi].Q1.x

        .IF [esi].dwUser & ADSR_232

            fild [edi].P2.x
            fmul adsr_Scale_X_232

            fild [edi].P34.x
            fmul adsr_Scale_X_232

            fild [edi].P5.x
            fmul adsr_Scale_X_232

        .ELSE

            fild [edi].P2.x
            fmul adsr_Scale_X_old

            fild [edi].P34.x
            fmul adsr_Scale_X_old

            fild [edi].P5.x
            fmul adsr_Scale_X_old

        .ENDIF

        fxch st(2)

        fstp [edi].R2.x
        fstp [edi].R34.x
        fstp [edi].R5.x


        fld1
        fstp [edi].R6.x


    ;// now we determine the slopes for the X's
    ;// for dy=0, we can ignore, because X updates all the time

    ;// dYdX12 = ( Q2y - Q1y ) / ( Q2x - Q1x )

        fld  [edi].R2.x
        fsub [edi].Q1.x
        ftst
        fnstsw  ax
        sahf
        .IF !ZERO?
            fld  [edi].R2.y
            fsub [edi].Q1.y
            fdivr
        .ENDIF
        fstp [edi].dYdX12

    ;// dYdX23 = ( Q34y - Q2y ) / ( Q34x - Q2x )

        fld  [edi].R34.x
        fsub [edi].R2.x
        ftst
        fnstsw  ax
        sahf
        .IF !ZERO?
            fld  [edi].R34.y
            fsub [edi].R2.y
            fdivr
        .ENDIF
        fstp [edi].dYdX23

    ;// dYdX45 = ( Q5y - Q34y ) / ( Q5x - Q34x )

        fld  [edi].R5.x
        fsub [edi].R34.x
        ftst
        fnstsw  ax
        sahf
        .IF !ZERO?
            fld  [edi].R5.y
            fsub [edi].R34.y
            fdivr
        .ENDIF
        fstp [edi].dYdX45

    ;// dYdX56 = ( Q6y - Q5y ) / ( Q6x - Q5x )

        fld  [edi].R6.x
        fsub [edi].R5.x
        ftst
        fnstsw  ax
        sahf
        .IF !ZERO?
            fld  [edi].R6.y
            fsub [edi].R5.y
            fdivr
        .ENDIF
        fstp [edi].dYdX56

    ;// that's it

        ret

adsr_CalcCoeff ENDP


ASSUME_AND_ALIGN
adsr_SyncControls PROC

    ASSUME esi:PTR ADSR_OSC_MAP

    ;// this makes sure that the control pDests are set

    ;// this validates ADSR_INVALID_PDEST

    ;//GDI_POINT_TO_GDI_OFFSET [esi].adsr.P1, ecx

        mov eax, [esi].adsr.P1.y
        add eax, ADSR_OFS_Y
        mul gdi_bitmap_size.x
        mov ecx, [esi].adsr.P1.x
        lea ecx, [ecx+eax+ADSR_OFS_X]

        mov [esi].adsr.pDest_offset_P1, ecx
        add ecx, ADSR_WIDTH
        mov [esi].adsr.pDest_offset_P6, ecx

    ;//GDI_POINT_TO_GDI_OFFSET [esi].adsr.P2, ecx

        mov eax, [esi].adsr.P2.y
        add eax, ADSR_OFS_Y
        mul gdi_bitmap_size.x
        mov ecx, [esi].adsr.P2.x
        lea ecx, [ecx+eax+ADSR_OFS_X]

        mov [esi].adsr.pDest_offset_P2, ecx

    ;// GDI_POINT_TO_GDI_OFFSET [esi].adsr.P34, ecx

        mov eax, [esi].adsr.P34.y
        add eax, ADSR_OFS_Y
        mul gdi_bitmap_size.x
        mov ecx, [esi].adsr.P34.x
        lea ecx, [ecx+eax+ADSR_OFS_X]

        mov [esi].adsr.pDest_offset_P34, ecx

    ;// GDI_POINT_TO_GDI_OFFSET [esi].adsr.P5, ecx

        mov eax, [esi].adsr.P5.y
        add eax, ADSR_OFS_Y
        mul gdi_bitmap_size.x
        mov ecx, [esi].adsr.P5.x
        lea ecx, [ecx+eax+ADSR_OFS_X]

        mov [esi].adsr.pDest_offset_P5, ecx

    ;// clear the flag

        and [esi].dwUser, NOT ADSR_INVALID_PDEST

    ret

adsr_SyncControls ENDP

ASSUME_AND_ALIGN
adsr_DrawLines PROC

    ;// this draws four to five lines
    ;// it validates ADSR_INVALID_LINES

        ASSUME esi:PTR ADSR_OSC_MAP

        mov ebx, [esi].pContainer

        ;//sub esp, SIZEOF RECT
        xor eax, eax
        push eax
        push eax
        push eax
        push eax
        st_rect TEXTEQU <(RECT PTR [esp])>

    ;// fill the background

        mov eax, F_COLOR_GROUP_GENERATORS + F_COLOR_GROUP_LAST - 02020202h
        invoke dib_Fill

    ;// if we are an old version, display that

        .IF !([esi].dwUser & ADSR_232)
            mov edx, esp
            invoke DrawTextA, (DIB_CONTAINER PTR [ebx]).shape.hDC, OFFSET sz_adsr_old,3, edx, DT_NOCLIP OR DT_SINGLELINE
        .ENDIF

    ;// draw the lines

        xor eax, eax    ;// prevent stalls

    ;// draw the optional sustain line

        mov al, COLOR_GROUP_GENERATORS + 1Fh - 06h  ;// medium color

        .IF !([esi].dwUser & ADSR_NOSUSTAIN)

            mov edx, [esi].adsr.P34.x
            add edx, ADSR_OFS_X
            rect_Set st_rect, edx, ADSR_OFS_Y, edx, ADSR_OFS_Y + ADSR_HEIGHT
            invoke dib_DrawLine

        .ENDIF

    ;// draw the base line

        mov edx, [esi].adsr.P1.y
        add edx, ADSR_OFS_Y
        rect_Set st_rect, ADSR_OFS_X, edx, ADSR_OFS_X + ADSR_WIDTH, edx
        invoke dib_DrawLine

    ;// draw the four connecting lines

        mov al, COLOR_GROUP_GENERATORS

        ;// P1 already set as TL
        point_Get [esi].adsr.P2, edx, ecx
        add edx, ADSR_OFS_X
        add ecx, ADSR_OFS_Y
        point_SetBR st_rect, edx, ecx   ;// P2 = BR
        invoke dib_DrawLine

        ;// P2 to P34
        point_Get [esi].adsr.P34, edx, ecx
        add edx, ADSR_OFS_X
        add ecx, ADSR_OFS_Y
        point_SetTL st_rect, edx, ecx
        invoke dib_DrawLine

        ;// P34 to P5
        point_Get [esi].adsr.P5, edx, ecx
        add edx, ADSR_OFS_X
        add ecx, ADSR_OFS_Y
        point_SetBR st_rect, edx, ecx
        invoke dib_DrawLine

        ;// P5 to P4
        mov edx, [esi].adsr.P1.y
        add edx, ADSR_OFS_X
        add ecx, ADSR_OFS_Y
        point_SetTL st_rect, ADSR_OFS_X + ADSR_WIDTH, edx
        invoke dib_DrawLine

    ;// turn the flag off, clean up the stack

        add esp, SIZEOF RECT
        st_rect TEXTEQU <>
        and [esi].dwUser, NOT ADSR_INVALID_LINES

    ;// that's it

        ret

adsr_DrawLines ENDP


ASSUME_AND_ALIGN
adsr_SyncPins PROC

    ASSUME esi:PTR ADSR_OSC_MAP

    ;// set the level on the trigger pin

        mov ecx, [esi].dwUser
        OSC_TO_PIN_INDEX esi, ebx, 1

        .IF ecx & ADSR_START_POS
            mov eax, PIN_LOGIC_INPUT OR PIN_LEVEL_POS
        .ELSE   ;// ecx & ADSR_START_NEG
            mov eax, PIN_LOGIC_INPUT OR PIN_LEVEL_NEG
        .ENDIF

    ;// ABOX232: adjusted so auto_restart shows a gate pin

        and ecx, ADSR_AUTORESTART OR ADSR_NOSUSTAIN
        .IF ecx == ADSR_AUTORESTART OR ADSR_NOSUSTAIN
            or eax, PIN_LOGIC_GATE
        .ENDIF

    ;// then set the pin

        invoke pin_SetInputShape

    ;// that's it, shut the bit off

        and [esi].dwUser, NOT ADSR_INVALID_PINS

        ret

adsr_SyncPins ENDP


ASSUME_AND_ALIGN
adsr_GetUnit PROC

    clc ;// we never know what the output unit is
    ret

adsr_GetUnit ENDP





;////////////////////////////////////////////////////////////////////
;//
;//
;//     adsr Ctor
;//

ASSUME_AND_ALIGN
adsr_Ctor PROC


        ;// register call
        ASSUME ebp:PTR LIST_CONTEXT ;// preserve
        ASSUME esi:PTR OSC_OBJECT   ;// preserve
        ASSUME edi:PTR OSC_BASE     ;// may_destroy
        ASSUME ebx:PTR FILE_OSC     ;// may destroy
        ASSUME edx:PTR FILE_HEADER  ;// may destroy

    ;// if we're not loading from a file
    ;// initialize the ADSR data with defaults

        OSC_TO_DATA esi, ebx, OSC_ADSR

        .IF !edx        ;// starting from scratch ?

            mov [esi].dwUser, ADSR_START_NEG OR ADSR_232    ;// setup the trigger and that we are a new ADSR

            point_Set [ebx].P1,   0, ADSR_HEIGHT
            point_Set [ebx].P2,  16, 18
            point_Set [ebx].P34, 28, 32
            point_Set [ebx].P5,  46, 22

        .ENDIF

    ;// make sure dwUser is conditioned correctly and
    ;// force an update of the coefficients and positions

        or [esi].dwUser, ADSR_INVALID_Q OR ADSR_INVALID_PDEST OR ADSR_INVALID_LINES OR ADSR_INVALID_PINS

    ;// that should do it

    ;// adsr_SetShape will make sure our dib gets allocated

        ret

adsr_Ctor ENDP
;//
;//     adsr Ctor
;//
;//
;////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////
;//
;//
;//     adsr Dtor
;//
ASSUME_AND_ALIGN
adsr_Dtor PROC

    ASSUME esi:PTR ADSR_OSC_MAP

    xor eax, eax
    or  eax, [esi].adsr.dib
    .IF !ZERO?

        invoke dib_Free,    eax

    .ENDIF

    ret

adsr_Dtor ENDP
;//
;//     adsr Dtor
;//
;//
;////////////////////////////////////////////////////////////////////




;////////////////////////////////////////////////////////////////////
;//
;//
;//
;//
ASSUME_AND_ALIGN
adsr_PrePlay PROC

        ASSUME esi:PTR ADSR_OSC_MAP

        xor eax, eax
        mov [esi].adsr.stage,   eax ;// stage we need to account for
        mov [esi].adsr.last_t,  eax ;// last t_value we got
        mov [esi].adsr.last_dXdS, eax ;// dX value we got (not always used)
        mov [esi].adsr.last_Y,  eax ;// last Y value we stored
        mov [esi].adsr.last_X,  eax ;// last X value we worked with

    ;// that's it, eax = zero so preplay will erase our data

        ret

adsr_PrePlay ENDP








ASSUME_AND_ALIGN
adsr_SetShape PROC

        ASSUME esi:PTR ADSR_OSC_MAP

    .IF !([esi].dwUser & ADSR_SMALL)

    ;// make sure we have a dib container
    ;// we store it in adsr.dib so we have a backup

        mov eax, [esi].adsr.dib
        .IF !eax

            invoke dib_Reallocate, DIB_ALLOCATE_INTER, ADSR_SIZE_X, ADSR_SIZE_Y ;// do it
            mov [esi].adsr.dib, eax ;// always store for a backup !!!!

            .IF !([esi].dwUser & ADSR_232)
            ;// account for drawing a special text label
                push eax
                invoke SelectObject, (DIB_CONTAINER PTR [eax]).shape.hDC, hFont_pin
                mov eax, [esp]
                mov edx, oBmp_palette[COLOR_GROUP_GENERATORS*4]
                BGR_TO_RGB edx
                invoke SetTextColor, (DIB_CONTAINER PTR [eax]).shape.hDC, edx
                mov eax, [esp]
                invoke SetBkMode, (DIB_CONTAINER PTR [eax]).shape.hDC, TRANSPARENT
                pop eax
            .ENDIF

        .ENDIF

        mov [esi].pContainer, eax   ;// store in object
        mov eax, (DIB_CONTAINER PTR [eax]).shape.pSource
        mov [esi].pSource, eax

    ;// make sure we know where the o is

        .IF !pShape_o_mask

        push edi

            mov eax, 'o'
            lea edi, font_pin_slist_head
            invoke font_Locate
            mov eax, (GDI_SHAPE PTR [edi]).pMask
            mov pShape_o_mask, eax

            mov eax, 'O'
            lea edi, font_pin_slist_head
            invoke font_Locate
            mov eax, (GDI_SHAPE PTR [edi]).pMask
            mov pShape_O_mask, eax

        pop edi

        .ENDIF

    .ELSE   ;// we are the small version

        lea edx, fftop_container
        .IF [esi].dwUser & ADSR_232
            mov eax, ADSR_SMALL_PSOURCE
        .ELSE
            mov eax, ADSR2SMALL_PSOURCE
        .ENDIF

        mov [esi].pContainer, edx
        mov [esi].pSource, eax

    .ENDIF

    ;// make sure pins are synced

        .IF [esi].dwUser & ADSR_INVALID_PINS
            invoke adsr_SyncPins
        .ENDIF

    ;// that just might do it

        jmp osc_SetShape

adsr_SetShape ENDP





ASSUME_AND_ALIGN
adsr_Render PROC

        ASSUME esi:PTR ADSR_OSC_MAP

    ;// check if we're small

        test [esi].dwUser, ADSR_SMALL
        jnz gdi_render_osc

    ;// make sure we have a valid picture

        .IF [esi].dwUser & ADSR_INVALID_LINES
            invoke adsr_DrawLines
        .ENDIF

    ;// double check the pin states

        .IF [esi].dwUser & ADSR_INVALID_PINS
            invoke adsr_SyncPins
        .ENDIF

    ;// call base class to blit the image

        invoke gdi_render_osc

    ;// draw our controls
    ;// make sure they're valid

        .IF [esi].dwUser & ADSR_INVALID_PDEST
            invoke adsr_SyncControls
        .ENDIF

    push esi

        mov eax, F_COLOR_GROUP_GENERATORS

        mov ebx, pShape_o_mask
        mov edi, [esi].pDest
        add edi, [esi].adsr.pDest_offset_P1
        invoke shape_Fill
        mov esi, [esp]

        mov ebx, pShape_o_mask
        mov edi, [esi].pDest
        add edi, [esi].adsr.pDest_offset_P2
        invoke shape_Fill
        mov esi, [esp]

        mov ebx, pShape_o_mask
        mov edi, [esi].pDest
        add edi, [esi].adsr.pDest_offset_P34
        invoke shape_Fill
        mov esi, [esp]

        mov ebx, pShape_o_mask
        mov edi, [esi].pDest
        add edi, [esi].adsr.pDest_offset_P5
        invoke shape_Fill
        mov esi, [esp]

        mov ebx, pShape_o_mask
        mov edi, [esi].pDest
        add edi, [esi].adsr.pDest_offset_P6
        invoke shape_Fill
        mov esi, [esp]

    ;// if we have a control hover, draw that

        mov ecx, [esi].dwUser
        and ecx, ADSR_HOVER_TEST
        .IF !ZERO?

            ;// make sure the app says it's ok

            .IF app_bFlags & (APP_MODE_CONTROLLING_OSC OR APP_MODE_CON_HOVER)

                ;// draw appropriate hover
                ;//
                mov eax, F_COLOR_OSC_HOVER

                dec ecx
                .IF ZERO?   ;// base line ?
                    ;// draw the other control as well
                    mov edi, [esi].adsr.pDest_offset_P6
                    mov ebx, pShape_O_mask
                    add edi, [esi].pDest
                    invoke shape_Fill
                    xor ecx, ecx
                    mov esi, [esp]
                .ENDIF
                mov edi, [esi+ecx*4].adsr.pDest_offset_P1
                mov ebx, pShape_O_mask
                add edi, [esi].pDest
                invoke shape_Fill

            .ELSE

                ;// high time to shut control hover off

            .ENDIF

        .ENDIF

    pop esi

    ;// that's it

        ret

adsr_Render ENDP





ASSUME_AND_ALIGN
adsr_HitTest PROC uses esi

    ASSUME esi:PTR ADSR_OSC_MAP

    ;// check if we're small first

    test [esi].dwUser, ADSR_SMALL
    jnz exit_no_hit

    ;// we return carry flag if any of our controls have the hover

    and [esi].dwUser, ADSR_HOVER_MASK   ;// turn off the hovers

    mov ebx, shape_pin_font.pMask
    mov edx, [esi].pDest
    mov esi, [esi].adsr.pDest_offset_P1
    mov edi, mouse_pDest
    add esi, edx
    invoke shape_Test
    mov esi, [esp]
    jnc @F
        or [esi].dwUser, ADSR_HOVER_P1
        jmp exit_hit

@@: mov ebx, shape_pin_font.pMask
    mov edx, [esi].pDest
    mov esi, [esi].adsr.pDest_offset_P2
    mov edi, mouse_pDest
    add esi, edx
    invoke shape_Test
    mov esi, [esp]
    jnc @F
        or [esi].dwUser, ADSR_HOVER_P2
        jmp exit_hit

@@: mov ebx, shape_pin_font.pMask
    mov edx, [esi].pDest
    mov esi, [esi].adsr.pDest_offset_P34
    mov edi, mouse_pDest
    add esi, edx
    invoke shape_Test
    mov esi, [esp]
    jnc @F
        or [esi].dwUser, ADSR_HOVER_P34
        jmp exit_hit

@@: mov ebx, shape_pin_font.pMask
    mov edx, [esi].pDest
    mov esi, [esi].adsr.pDest_offset_P5
    mov edi, mouse_pDest
    add esi, edx
    invoke shape_Test
    mov esi, [esp]
    jnc @F
        or [esi].dwUser, ADSR_HOVER_P5
        jmp exit_hit

@@: mov ebx, shape_pin_font.pMask
    mov edx, [esi].pDest
    mov esi, [esi].adsr.pDest_offset_P6
    mov edi, mouse_pDest
    add esi, edx
    invoke shape_Test
    mov esi, [esp]
    jnc @F
        or [esi].dwUser, ADSR_HOVER_P1
        jmp exit_hit

;// no hit
exit_no_hit:
@@: xor eax, eax
    inc eax
    ret

;// yes hit
exit_hit:

    xor eax, eax
    inc eax
    stc
    ret


adsr_HitTest ENDP

ASSUME_AND_ALIGN
adsr_Control PROC

    ASSUME esi:PTR ADSR_OSC_MAP
    ASSUME ebp:PTR LIST_CONTEXT

    DEBUG_IF <[esi].dwUser & ADSR_SMALL>    ;// not supposed to happen!

    ;// eax has the mouse message indicating why this is being called

    ;// if mouse move, the move the control

    cmp eax, WM_MOUSEMOVE
    mov eax, 0
    jne all_done

        ;// detrmine which hover we have

        mov ecx, [esi].dwUser       ;// get dwUser
        point_Get mouse_now         ;// get the current mouse points
        point_Sub ADSR_OFS          ;// subtract the border
        and ecx, ADSR_HOVER_TEST    ;// strip out the rest
        DEBUG_IF <ZERO?>            ;// no hover is set

        dec ecx
        jmp adsr_control_jump[ecx*4]


    adsr_control_1::    ;// all we care about is Y

        lea ecx, [esi].adsr.P1
        xor eax, eax
        jmp offset_and_test_edx

    adsr_control_2::    ;// working with P2

        sub eax, [esi].rect.left    ;// offset X and test too far left
        lea ecx, [esi].adsr.P2
        jnc J1
        xor eax, eax
    J1: cmp eax, [esi].adsr.P34.x   ;// compare X with next point
        jbe offset_and_test_edx
        mov eax, [esi].adsr.P34.x
        jmp offset_and_test_edx

    adsr_control_34::   ;// working with P34

        sub eax, [esi].rect.left    ;// offset X
        lea ecx, [esi].adsr.P34
        cmp eax, [esi].adsr.P2.x    ;// test against previous X
        jge J2                      ;// signed compare
        mov eax, [esi].adsr.P2.x
    J2: cmp eax, [esi].adsr.P5.x    ;// compare X with next point
        jbe offset_and_test_edx
        mov eax, [esi].adsr.P5.x
        jmp offset_and_test_edx

    adsr_control_5::        ;// working with P5

        sub eax, [esi].rect.left    ;// offset X
        lea ecx, [esi].adsr.P5
        cmp eax, [esi].adsr.P34.x   ;// test against previous X
        jge J3                      ;// signed compare
        mov eax, [esi].adsr.P34.x
    J3: cmp eax, ADSR_WIDTH         ;// compare X with too far right
        jb offset_and_test_edx
        mov eax, ADSR_WIDTH-1

    offset_and_test_edx:    ;// offset the hieght and check for range

        sub edx, [esi].rect.top     ;// offset and test above
        jnc J4
        xor edx, edx
    J4: cmp edx, ADSR_HEIGHT        ;// check for below
        jbe J5
        mov edx, ADSR_HEIGHT
    J5: point_Set (POINT PTR [ecx])

    cleanup_and_go:

        or [esi].dwUser, ADSR_INVALID_Q OR ADSR_INVALID_LINES OR ADSR_INVALID_PDEST

        GDI_INVALIDATE_OSC HINTI_OSC_UPDATE

        mov eax, CON_HAS_MOVED

all_done:

    ret

adsr_Control ENDP

.DATA

adsr_control_jump   LABEL DWORD

    dd adsr_control_1
    dd adsr_control_2
    dd adsr_control_34
    dd adsr_control_5

.CODE




ASSUME_AND_ALIGN
adsr_InitMenu PROC

        ASSUME esi:PTR OSC_OBJECT

    ;// take care of the trigger modes

        mov ebx, [esi].dwUser

        xor edx, edx
        bt ebx, LOG2(ADSR_NOSUSTAIN)
        rcl edx, 1
        invoke CheckDlgButton, popup_hWnd, ID_ADSR_NOSUSTAIN, edx

        xor edx, edx
        bt ebx, LOG2(ADSR_NORETRIGGER)
        rcl edx, 1
        invoke CheckDlgButton, popup_hWnd, ID_ADSR_NORETRIGGER, edx

        .IF ebx & ADSR_START_POS
            mov ecx, ID_ADSR_START_POS
        .ELSE   ;//IF [esi].dwUser & ADSR_START_NEG
            mov ecx, ID_ADSR_START_NEG
        .ENDIF

        invoke CheckDlgButton, popup_hWnd, ecx, BST_CHECKED

        xor edx, edx
        bt ebx, LOG2(ADSR_SMALL)
        rcl edx, 1
        invoke CheckDlgButton, popup_hWnd, ID_ADSR_SMALL, edx

        xor edx, edx
        bt ebx, LOG2(ADSR_IGNORE_T)
        rcl edx, 1
        invoke CheckDlgButton, popup_hWnd, ID_ADSR_IGNORE_T, edx

        xor edx, edx
        bt ebx, LOG2(ADSR_AUTORESTART)
        rcl edx, 1
        invoke CheckDlgButton, popup_hWnd, ID_ADSR_AUTORESTART, edx

    ;// that's it

        xor eax, eax

        ret

adsr_InitMenu ENDP


ASSUME_AND_ALIGN
adsr_Command PROC

    ASSUME ebp:PTR LIST_CONTEXT
    ASSUME esi:PTR OSC_OBJECT
    ;// eax has command id

    cmp eax, ID_ADSR_SMALL
    jnz @F

    mov eax, ADSR_SMALL_ADJUST_X
    mov edx, ADSR_SMALL_ADJUST_Y

    btc [esi].dwUser, LOG2(ADSR_SMALL)
    .IF CARRY?
        neg eax
        neg edx
    .ENDIF

    point_AddToTL [esi].rect

    GDI_INVALIDATE_OSC HINTI_OSC_MOVED OR HINTI_OSC_SHAPE_CHANGED

    mov eax, POPUP_SET_DIRTY OR POPUP_REDRAW_OBJECT
    ret

@@: cmp eax, ID_ADSR_IGNORE_T
    jne @F

    xor [esi].dwUser, ADSR_IGNORE_T
    mov eax, POPUP_SET_DIRTY
    ret

@@: cmp eax, ID_ADSR_AUTORESTART
    jne @F

    xor [esi].dwUser, ADSR_AUTORESTART
    or [esi].dwUser, ADSR_INVALID_PINS
    mov eax, POPUP_SET_DIRTY OR POPUP_REDRAW_OBJECT
    ret

@@: cmp eax, ID_ADSR_NOSUSTAIN
    jnz @F

    or [esi].dwUser, ADSR_INVALID_LINES OR ADSR_INVALID_PINS ;// turn on/off the sustain line
    mov ecx, ADSR_NOSUSTAIN
    jmp xor_then_exit

@@: cmp eax, ID_ADSR_NORETRIGGER
    jnz @F

        mov ecx, ADSR_NORETRIGGER

    xor_then_exit:

        xor [esi].dwUser, ecx
        mov eax, POPUP_SET_DIRTY OR POPUP_REDRAW_OBJECT
        ret

@@: cmp eax, ID_ADSR_START_POS
    jnz @F

        mov edx, ADSR_START_POS OR ADSR_INVALID_PINS
        jmp set_new_pin_trigger

@@: cmp eax, ID_ADSR_START_NEG
    jnz osc_Command

        mov edx, ADSR_START_NEG OR ADSR_INVALID_PINS

    set_new_pin_trigger:

        and [esi].dwUser, ADSR_START_MASK
        or [esi].dwUser, edx
        invoke adsr_SyncPins
        mov eax, POPUP_SET_DIRTY OR POPUP_REDRAW_OBJECT OR POPUP_INITMENU
        ret


adsr_Command ENDP


ASSUME_AND_ALIGN
adsr_SaveUndo   PROC

        ASSUME esi:PTR ADSR_OSC_MAP

        ;// edx enters as either UNREDO_CONTROL_OSC or UNREDO_COMMAND
        ;// edi enters as where to store
        ;//
        ;// task:   1) save nessary data
        ;//         2) iterate edi
        ;//
        ;// may use all registers except ebp

        .IF edx == UNREDO_CONTROL_OSC

            ;// save the control points

            mov ecx, (SIZEOF POINT * 4 ) / 4
            lea esi, [esi].adsr.P1

            rep movsd

        .ELSE   ;// save object settings

            mov eax, [esi].dwUser
            stosd

        .ENDIF

        ret

adsr_SaveUndo ENDP


ASSUME_AND_ALIGN
adsr_LoadUndo PROC

        ASSUME esi:PTR ADSR_OSC_MAP     ;// preserve
        ASSUME ebp:PTR LIST_CONTEXT ;// preserve

        ;// edx enters as either UNREDO_CONTROL_OSC or UNREDO_COMMAND
        ;// edi enters as where to load
        ;//
        ;// task:   1) load nessary data
        ;//         2) do what it takes to initialize it
        ;//
        ;// may use all registers except ebp and esi
        ;// return will invalidate HINTI_OSC_UPDATE

        or [esi].dwHintI, HINTI_OSC_MOVED OR HINTI_OSC_SHAPE_CHANGED

        .IF edx == UNREDO_CONTROL_OSC

            ;// load control points

            push esi

            or [esi].dwUser, ADSR_INVALID_Q OR ADSR_INVALID_LINES OR ADSR_INVALID_PDEST

            lea esi, [esi].adsr.P1
            mov ecx, (SIZEOF POINT * 4 ) / 4
            xchg esi, edi

            rep movsd

            pop esi

        .ELSE   ;// load object settings

            mov eax, [edi]          ;// get new settings
            mov edx, [esi].dwUser   ;// get old settings

            mov ecx, eax
            xor ecx, edx

            and eax, ADSR_HOVER_MASK    ;// strip out enevelope bits from old settings
            or eax, ADSR_INVALID_Q OR ADSR_INVALID_LINES OR ADSR_INVALID_PDEST;// force rebuild
            and edx, ADSR_HOVER_TEST    ;// strip out hover bits from old command

            or eax, edx             ;// merge old and new
            mov [esi].dwUser, eax   ;// store back in dwUser

            .IF ecx & ADSR_SMALL

                bt eax, LOG2(ADSR_SMALL)

                mov eax, ADSR_SMALL_ADJUST_X
                mov edx, ADSR_SMALL_ADJUST_Y

                .IF !CARRY?
                    neg eax
                    neg edx
                .ENDIF

                point_AddToTL [esi].rect

                or [esi].dwHintI, (HINTI_OSC_MOVED OR HINTI_OSC_SHAPE_CHANGED)

            .ENDIF

            invoke adsr_SyncPins

        .ENDIF


        ret

adsr_LoadUndo ENDP







comment ~ /*

calc_notes

loop flow

    there are 6 stages

    0   wait for start trigger
    1   do first ramp
    2   do second ramp
    3   wait for release trigger
    4   do third ramp
    5   do fourth ramp

    stages 1,2,4 and 5 may be restarted by jumping back to stage 1
    stage 3 may be skipped if a release trigger is hit


general ramp calculation

    for each sample

        dXdS  = abs(F/2)         F is read from T input pin
        Xnow += dXdS             stage complete if Xnow >= Xend of the next stage
        Ynow += dYdX * dXdS      store Ynow and advance to next sample

    the macro ADSR_RAMP performs this operation along with trigger testing
    it returns zero and carry flags
    more details below in ramp_details

registers

    ebp     ADSR_OSC_MAP

    esi     F source timming data
    ebx     t source trigger data

    ecx     sample counter
    edx     special flags
    edi     temporary, used as jumper and trigger tester

    eax     unknown, may be fpu stats, fill value, etc

    FPU     Xnow    Ynow    dXdS

flags in edx

    edx will track several flags

    bit 31      sign of the last recieved trigger from ebx
    bits 0-15   incremented value of 'got_edge'

stack variables

    st_ramp     pointer to ramp function, one of ramp_mode
    st_start    pointer to stage 0 start function, one of wait_mode
    st_release  pointer to stage 3 release function, one of wait_mode

    these are build at adsr_Calc entrance depending of state of inputs


-----------------------------------------------------------------------

stage_X_run                 run the wait or ramp, produce output
stage_X_interpolate_Y       transform from stage X to stage Y

    for the most part the stage_X_run is accessed at calc entrance
    stage_X_interpolate_Y is accessed inside the calc loop

    stage_X_run does the actual generation of output data
    and will call a wait or ramp function

    stage_X_interpolate_Y does the work nessesary to transform to
    the next stage


-----------------------------------------------------------------------

ramp_details

    there are 12 ramp functions that depend on

        dF/sF   F input is changing or not
        dT/sT   trigger input is changing or not
        mR/pR   neg or pos retrigger (opposite of start edge)
        nR/yR   retrigger is enabled or not

        these are stated in ramp_mode

    ramp_mode return values

        flags   meaning             FPU state               action
        -----   -----------------   --------------------    -----------
        z       done with frame     Xnow    Ynow    dXdS    jz calc_exit
        nz c    got retrigger       Xnow    Ynow    dXdS    jc stage_1_retrigger
        nz nc   done with segment   Xnow    Ybad    dXdS    interpolate to next segment

        edx is updated with 'got edge' (lower 16 bits)
        always test for zero first, then test for carry

    FPU behavior

        INPUT:      dYdX    Xend    Xnow    Ynow    dXdS
        OUTPUT:     Xnow    Ynow    dXdS

        if nz and nc this segment is complete, new point Ynow must be interpolated

        ecx will point at the last vaue stored (NOT YET ITERATED)

    INTERPOLATE proceedure

        Ynow will be the wrong value, it must be interpolated by bouncing

            Ycorrect = Ystart + dYdX * (Xnow - Xstart)

        Xnow MAY be already passed the end of the next segment

            if this is true, derive K using next segment
            derive Y using next segment
            jump to next segment

        genric proceedure

            run:
                load FPU
                call ramp
                jz calc_exit
                jc retrigger
            interpolate:
                cmp Xnow with Xend of next frame
                if above or equal, jmp to that interpolate
                otherwise
                compute and store the correct Yvalue
                advance ecx, exit if frame end
                fall unto next run

    ITERATE proceedure

        a new Ycorrect value must be stored at the output position indicated by ecx
        ecx must then be advanced, exit calc my then be jumped to is applicable

        for sustain==yes and autoretrigger==no, this interperatation does NOT take place
        instead the value of Ystart is stored and Xadjusted to Xstart

-----------------------------------------------------------------------

setup proceedure

    define modes

        tmp name                        notes
        --- ------------                --------------
        ecx ramp_mode                   store on stack

            if dF, add 4
            if dT, add 2
            if no retrigger
                add 8
                if no sustain, add 1
            else
                if pR, add 1


        tmp name                        notes
        --- ------------                --------------
        edx start_mode                  store on stack
            release_mode                store on stack

            if dT, add 2
            if pS, add 1


    prepare the fpu

        Xnow    Ynow    dXdS

        dT  nI  load dummy dXdS from osc.adsr.last_dXdS
        sT  nI  build dXdS from [esi] (F source data)
        dT  yI  load real dXdS from osc.adsr.last_dXdS
        sT  yI  load real dXdS from osc.adsr.last_dXdS

        if yI turn off bit 2 of ramp mode (so we have to set bit first)

    prepare the status flag (aka osc.adsr.last_t)

        edx

        load the previous value of last_t (contains the sign and 'got_edge' counter)
        move the NO_SUSTAIN bit from osc.dwUser to the staus flag

        merge in the previous changing status of pin_x
        then clear pin_x pin changing

        clear the counter

            ecx

    jump into correct entry point

        jump stage_jump[stage*4]


ramp restart trigger testing

    to account for no-sustain mode,
    edx is incremented to indicate that a trigger was recieved
    this works because if we are in a ramp, the next edge we get must
    either be a release trigger, or a re-trigger

    there are then two flavours of restart testing

        pos restart                     neg restart
        edx     [ebx]                   edx     [ebx]
        last    this                    last    this
        sign    sign                    sign    sign
        0       0   ignore              0       0   ignore
        0       1   toggle last sign    0       1   retrigger
        1       0   retrigger           1       0   toggle last sign
        1       1   ignore              1       1   ignore

        ...
        mov edi, edx        ;// xfer flags to temp
        xor edi, [ebx+ecx*4];// test the new value
        js trigger          ;// jmp if sign changed
        false_alarm:
        ...
    trigger:

        btc edx, 31     ;// toggle the sign
        inc edx         ;// set that we got a trigger
        jnc false_alarm ;// return if false alarm (pos restart)




*/ comment ~

.DATA

    ;// jump tables

    stage_jump LABEL DWORD  ;// re done in ABOX232

        dd  stage_0_run, stage_1_run, stage_2_run, stage_3_run, stage_4_run, stage_5_run

    stage_jump_231 LABEL DWORD  ;// preserved for backwards compatability

        dd  stage_0_231, stage_1_231, stage_2_231, stage_3_231, stage_4_231, stage_5_231

    wait_mode LABEL DWORD   ;// toggle the low bit of the index to get to release_mode

        dd  wait_sTm, wait_sTp, wait_dTm, wait_dTp

    ramp_mode LABEL DWORD

        dd  ramp_sF_sT_mR,  ramp_sF_sT_pR,  ramp_sF_dT_mR,  ramp_sF_dT_pR
        dd  ramp_dF_sT_mR,  ramp_dF_sT_pR,  ramp_dF_dT_mR,  ramp_dF_dT_pR
        dd  ramp_sF_sT_nR,  ramp_sF_dT_nR,  ramp_dF_sT_nR,  ramp_dF_dT_nR


.CODE

ASSUME_AND_ALIGN
adsr_Calc PROC USES ebp

    ;// make sure coefficients are valid

        ASSUME esi:PTR ADSR_OSC_MAP
        .IF [esi].dwUser & ADSR_INVALID_Q
            invoke adsr_CalcCoeff
        .ENDIF


    ;/////////////////////////////////////////
    ;//
    ;//     set up to enter the loop
    ;//

        ;// clear all the registers

            mov ebp, esi
            ASSUME ebp:PTR ADSR_OSC_MAP
            xor eax, eax        ;// oper mode index

            mov ebx, eax        ;// t pin or t data
            mov ecx, eax        ;// temp wait mode index
            mov edi, [ebp].dwUser   ;// temp mode flags
            mov edx, eax        ;// temp ramp mode index
            mov esi, eax        ;// T pin or T data

        ;// F input

            OR_GET_PIN [ebp].pin_T.pPin, esi
            jz T0
            test [esi].dwStatus, PIN_CHANGING
            mov esi, [esi].pData
            ASSUME esi:PTR DWORD
            jz T1
            add ecx, 4
            jmp T1
        T0: mov esi, math_pNull
        T1:

        ;// fpu loading

            .IF !(ecx & 4) && !(edi & ADSR_IGNORE_T)
                fld [esi]       ;// F
                fmul math_1_2   ;// dXdS
                fabs            ;// dXdS
            .ELSE
                fld [ebp].adsr.last_dXdS
            .ENDIF

            fld [ebp].adsr.last_Y   ;// Ynow    dXdS
            fld [ebp].adsr.last_X   ;// Xnow    Ynow    dXdS

        ;// t input

            OR_GET_PIN [ebp].pin_t.pPin, ebx
            jz t0
            test [ebx].dwStatus, PIN_CHANGING
            mov ebx, [ebx].pData
            ASSUME ebx:PTR DWORD
            jz t1
            add ecx, 2  ;// advance ramp index
            add edx, 2  ;// advance start index
            jmp t1
        t0: mov ebx, math_pNull
        t1:

        ;// ramp retrigger/sustain/start options

            .IF edi & ADSR_NORETRIGGER
                shr ecx, 1  ;// divide by 2
                add ecx, 8  ;// add 8
            .ELSEIF edi & ADSR_START_POS
                inc ecx
            .ENDIF

        ;// start/release edge

            BITT edi, ADSR_START_POS
            adc edx, 0

        ;// ramp ignore T

            .IF edi & ADSR_IGNORE_T
                and ecx, NOT 4
            .ENDIF

        ;// store the mode values on the stack

            push ramp_mode[ecx*4]   ;// ramp mode function
            push wait_mode[edx*4]   ;// start mode function
            xor edx, 1
            push wait_mode[edx*4]   ;// release mode function

            st_ramp     TEXTEQU <(DWORD PTR [esp+8])>
            st_start    TEXTEQU <(DWORD PTR [esp+4])>
            st_release  TEXTEQU <(DWORD PTR [esp+0])>
            stack_size = 12

        ;// prepare edx status flag

            mov edx, [ebp].adsr.last_t
            and edi, ADSR_NOSUSTAIN
            or edx, edi

            mov eax, [ebp].pin_X.dwStatus
            and eax, PIN_CHANGING
            and [ebp].pin_X.dwStatus, NOT PIN_CHANGING
            or edx, eax

        ;// clear the count and let's go

            mov eax, [ebp].adsr.stage
            xor ecx, ecx
            .IF [ebp].dwUser & ADSR_232 ;// use new routines
                jmp stage_jump[eax*4]
            .ENDIF
            jmp stage_jump_231[eax*4]   ;// else use old routines



    ;///////////////////////////////////////////////////////////
    ;//
    ;//
    ;//     S T A G E S     new stages
    ;//


        stage_0_run::   ;// Xnow    Ynow    dXdS

            mov [ebp].adsr.stage, 0 ;// set the stage mask

            mov edi, st_start   ;// get the wait value
            xor eax, eax        ;// store zero for this stage
            call edi            ;// call the wait function
            jz calc_exit        ;// jump if done with frame


        stage_1_retrigger:  ;// Xnow    Ynow    dXdS

            and edx, NOT 3FFh   ;// strip out extra stuff from edx
            .ERRNZ (SAMARY_LENGTH-1024),<code assumes frame size of 1024>

            fsub st, st         ;// set fpu as 0, 0 (Q,X)
            fxch
            fsub st, st

            .IF [ebp].dwUser & ADSR_IGNORE_T

                ;// grab the correct dXdS

                fld [esi+ecx*4] ;// F       Xnow    Ynow    dXdS
                fmul math_1_2
                fabs            ;// dXdS    Xnow    Ynow    dXdS
                fxch st(3)      ;// dXdS    Xnow    Ynow    dXdS
                fstp st         ;// Xnow    Ynow    dXdS

            .ENDIF

            mov [ebp].adsr.stage, 1

        stage_1_run::   ;// Xnow    Ynow    dXdS

            mov edi, st_ramp        ;// load the ramp function

            fld [ebp].adsr.R2.x     ;// Xend    Xnow    Ynow    dXdS
            fld [ebp].adsr.dYdX12   ;// dYdX    Xend    Xnow    Ynow    dXdS

            call edi                ;// call the ramp function

            jz calc_exit            ;// exit if end of frame
            jc stage_1_retrigger    ;// retreat if retrigger

        stage_1_interpolate_2:      ;// Xnow    Ynow    dXdS

        ;// check if we are now beyond the NEXT segment also

            fcom [ebp].adsr.R34.x
            fnstsw ax
            sahf
            jae stage_2_interpolate_3

        ;// compute and store the correct Ynow = Ystart + dYdX * (Xnow-Xend)

            fld st                  ;// Xnow    Xnow    Ybad    dXdS
            fsub[ebp].adsr.R2.x     ;// K       Xnow    Ybad    dXdS
            fmul [ebp].adsr.dYdX23
            fadd [ebp].adsr.R2.y    ;// Ynow    Xnow    Ybad    dXdS
            fst [ebp].data_X[ecx*4] ;// Ynow    Xnow    Ybad    dXdS
            mov [ebp].adsr.stage, 2
            fstp st(2)              ;// Xnow    Ynow    dXdS
            inc ecx
            cmp ecx, SAMARY_LENGTH
            jae calc_exit

        stage_2_run::           ;// Xnow    Ynow    dXdS

            mov edi, st_ramp        ;// load the ramp function

            fld [ebp].adsr.R34.x    ;// Xend    Xnow    Ynow    (dXdS)
            fld [ebp].adsr.dYdX23   ;// dYdX    Xend    Xnow    Ynow    (dXdS)

            call edi                ;// call the ramp function
            jz calc_exit            ;// exit if end of frame
            jc stage_1_retrigger    ;// retreat if retrigger

        stage_2_interpolate_3:      ;// Xnow    Ybad    dXdS

            .IF [ebp].dwUser & ADSR_NOSUSTAIN   ;// if no sustain, we must bounce

                ;// check if beyond the next stage

                fcom [ebp].adsr.R5.x
                fnstsw ax
                sahf
                jae stage_4_interpolate_5

                fld st                  ;// Xnow    Xnow    Ybad    dXdS
                fsub[ebp].adsr.R34.x    ;// K       Xnow    Ybad    dXdS
                fmul [ebp].adsr.dYdX45
                fadd [ebp].adsr.R34.y   ;// Ynow    Xnow    Ybad    dXdS
                fst [ebp].data_X[ecx*4] ;// Ynow    Xnow    Ybad    dXdS
                mov [ebp].adsr.stage, 4
                fstp st(2)              ;// Xnow    Ynow    dXdS
                inc ecx
                cmp ecx, SAMARY_LENGTH
                jae calc_exit

                jmp stage_4_run

            .ENDIF

            ;// we have sustain, thus we reset Xnow and Ynow

            fstp st
            fstp st
            fld [ebp].adsr.R34.y    ;// Ynow    dXdS
            fld [ebp].adsr.R34.x    ;// Xnow    Ynow    dXdS

            mov [ebp].adsr.stage, 3

        stage_3_run::                   ;// Xnow    Ynow    dXdS

            test edx, 0FFFFh            ;// see if we already got the release, or if no sustain was set
            jnz stage_4_begin           ;// jump to next stage if so

            mov edi, st_release         ;// load the wait function pointer
            mov eax, [ebp].adsr.R34.y   ;// we store for this stage

            call edi                    ;// call the wait function
            jz calc_exit                ;// exit if frame done

        stage_4_begin:

            mov [ebp].adsr.stage, 4

        stage_4_run::   ;// Xnow    Ynow    (dXdS)

            mov edi, st_ramp            ;// load the ramp function

            fld [ebp].adsr.R5.x         ;// Xend    Xnow    Ynow    (dXdS)
            fld [ebp].adsr.dYdX45       ;// dYdS    Xend    Xnow    Ynow    (dXdS)

            call edi                    ;// call the ramp function
            jz calc_exit                ;// exit if end of frame
            jc stage_1_retrigger        ;// retreat if retrigger

        ;// check if we are now beyond the NEXT segment also
        stage_4_interpolate_5:

            fcom [ebp].adsr.R6.x
            fnstsw ax
            sahf
            jae stage_5_interpolate_6

        ;// compute and store the correct Ynow = Ystart + dYdX * (Xnow-Xend)

            fld st                  ;// Xnow    Xnow    Ybad    dXdS
            fsub[ebp].adsr.R5.x     ;// K       Xnow    Ybad    dXdS
            fmul [ebp].adsr.dYdX56
            fadd [ebp].adsr.R5.y    ;// Ynow    Xnow    Ybad    dXdS
            fst [ebp].data_X[ecx*4] ;// Ynow    Xnow    Ybad    dXdS
            mov [ebp].adsr.stage, 5
            fstp st(2)              ;// Xnow    Ynow    dXdS
            inc ecx
            cmp ecx, SAMARY_LENGTH
            jae calc_exit

        stage_5_run::               ;// Xnow    Ynow    dXdS

            mov edi, st_ramp        ;// load the ramp function

            fld [ebp].adsr.R6.x     ;// Xend    Xnow    Ynow    dXdS
            fld [ebp].adsr.dYdX56   ;// dYdX    Xend    Xnow    Ynow    dXdS

            call edi                ;// call the ramp function
            jz calc_exit            ;// exit if end of frame
            jc stage_1_retrigger    ;// retreat if retrigger

        stage_5_interpolate_6:      ;// Xnow    Ybad    dXdS

            test [ebp].dwUser, ADSR_AUTORESTART
            jz stage_0_run          ;// stage zero waits, then resets

        ;// we are in auto restart
        ;// check if we have a restart level

        .IF [ebp].dwUser & ADSR_START_POS
            TESTJMP edx, edx, js stage_0_run
        .ELSE
            TESTJMP edx, edx, jns stage_0_run
        .ENDIF
        ;// auto restart: preserve existing Xnow

            ;// first get correct Xnow  ;// Xnow    Ybad    dXdS
            fsub [ebp].adsr.R6.x        ;// Xnow    Ybad    dXdS

        ;// check if we are beyond end of stage 1

            fcom [ebp].adsr.R2.x
            fnstsw ax
            sahf
            jae stage_1_interpolate_2

        ;// compute and store the correct Ynow = Ystart + dYdX * (Xnow-Xend)
        ;// in this case, K = Xnow

            fld st                  ;// K       Xnow    Ybad    dXdS
            fmul [ebp].adsr.dYdX12
            fst [ebp].data_X[ecx*4] ;// Ynow    Xnow    Ybad    dXdS
            mov [ebp].adsr.stage, 1
            fstp st(2)              ;// Xnow    Ynow    dXdS
            inc ecx
            cmp ecx, SAMARY_LENGTH
            jb stage_1_run
            jmp calc_exit


    ;//
    ;//     S T A G E S     new stages
    ;//
    ;//
    ;///////////////////////////////////////////////////////////

    ;///////////////////////////////////////////////////////////
    ;//
    ;//
    ;//     S T A G E S   2 3 1     presereved for backwards compatibility
    ;//

        stage_0_231::   ;// Q   X   (dQ)

            mov [ebp].adsr.stage, 0 ;// set the stage mask

            mov edi, st_start   ;// get the wait value
            xor eax, eax        ;// store zero for this stage
            call edi            ;// call the wait function
            jz calc_exit        ;// jump if done with frame

        stage_retrigger_231:

            and edx, NOT 3FFh   ;// strip out extra stuff from edx
            .ERRNZ (SAMARY_LENGTH-1024),<code assumes frame size of 1024>

            fsub st, st         ;// set fpu as 0, 0 (Q,X)
            fxch
            fsub st, st

            .IF [ebp].dwUser & ADSR_IGNORE_T

                ;// grab the correct dQ

                fld [esi+ecx*4] ;// F   Q   X   (dQ)
                fmul math_1_2
                fabs            ;// dQ  Q   X   (dQ)
                fxch st(3)      ;// (dQ)Q   X   dQ
                fstp st         ;// Q   X   dQ

            .ENDIF

        stage_1_231::   ;// Q   X   (dQ)

            mov edi, st_ramp    ;// load the ramp function
            mov [ebp].adsr.stage, 1

            fld [ebp].adsr.R2.x     ;//Q1.x ;// Qe  Q   X   (dQ)
            fld [ebp].adsr.dYdX12   ;//dX01 ;// dX  Qe  Q   X   (dQ)

            call edi            ;// call the ramp function

            jz calc_exit        ;// exit if end of frame
            jc stage_retrigger_231  ;// retreat if retrigger
                                ;// Q   X0  (dQ)
            fld [ebp].adsr.R2.y     ;//Q1.y ;// X1  Q   X0  (dQ)
            fxch st(2)          ;// X0  Q   X1  (dQ)
            fstp st             ;// Q   X1  (dQ)

        stage_2_231::   ;// Q   X   (dQ)

            mov edi, st_ramp    ;// load the ramp function
            mov [ebp].adsr.stage, 2

            fld [ebp].adsr.R34.x    ;//Q2.x ;// Qe  Q   X   (dQ)
            fld [ebp].adsr.dYdX23   ;//dX12 ;// dX  Qe  Q   X   (dQ)

            call edi            ;// call the ramp function
            jz calc_exit        ;// exit if end of frame
            jc stage_retrigger_231  ;// retreat if retrigger
                                ;// Q   X0  (dQ)
            fld [ebp].adsr.R34.y    ;//Q2.y ;// X1  Q   X0  (dQ)
            fxch st(2)          ;// X0  Q   X1  (dQ)
            fstp st             ;// Q   X1  (dQ)

        stage_3_231::   ;// Q   X   (dQ)

            test edx, 0FFFFh    ;// see if we already got the release, or if no sustain was set
            jnz stage_4_231     ;// jump to next stage if so

            mov [ebp].adsr.stage, 3

            mov edi, st_release ;// load the wait function pointer
            mov eax, [ebp].adsr.R34.y   ;//Q2.y;// we store for this stage

            call edi            ;// call the wait function
            jz calc_exit        ;// exit if frame done

        stage_4_231::   ;// Q   X   (dQ)

            mov edi, st_ramp    ;// load the ramp function
            mov [ebp].adsr.stage, 4

            fld [ebp].adsr.R5.x ;//Q3.x ;// Qe  Q   X   (dQ)
            fld [ebp].adsr.dYdX45   ;//dX23 ;// dX  Qe  Q   X   (dQ)

            call edi            ;// call the ramp function
            jz calc_exit        ;// exit if end of frame
            jc stage_retrigger_231  ;// retreat if retrigger
                                ;// Q   X0  (dQ)
            fld [ebp].adsr.R5.y     ;//Q3.y ;// X1  Q   X0  (dQ)
            fxch st(2)          ;// X0  Q   X1  (dQ)
            fstp st             ;// Q   X1  (dQ)

        stage_5_231::   ;// Q   X   (dQ)

            mov edi, st_ramp    ;// load the ramp function
            mov [ebp].adsr.stage, 5

            fld1                ;// Qe  Q   X   (dQ)
            fld [ebp].adsr.dYdX56   ;//dX34 ;// dX  Qe  Q   X   (dQ)

            call edi            ;// call the ramp function
            jz calc_exit        ;// exit if end of frame
            jc stage_retrigger_231  ;// retreat if retrigger

            test [ebp].dwUser, ADSR_AUTORESTART
            jz stage_0_231

            inc ecx
            cmp ecx, SAMARY_LENGTH
            jae calc_exit

            test [ebp].dwUser, ADSR_START_POS
            jnz auto_pos_231

            auto_neg_231:

                or edx, edx
                js stage_retrigger_231
                jmp stage_0_231

            auto_pos_231:

                or edx, edx
                jns stage_retrigger_231
                jmp stage_0_231     ;// do all over again

    ;//
    ;//     S T A G E S   2 3 1     presereved for backwards compatibility
    ;//
    ;//
    ;///////////////////////////////////////////////////////////




    ;////////////////////////////////////////
    ;//
    ;//     E X I T
    ;//
    ALIGN 16
    calc_exit:      ;// Xnow    Ynow    dXdS

        ;// store the final values


        and edx, NOT (PIN_CHANGING OR ADSR_NOSUSTAIN)
        mov [ebp].adsr.last_t, edx

        fxch st(2)
        fstp [ebp].adsr.last_dXdS
        fstp [ebp].adsr.last_Y
        fstp [ebp].adsr.last_X

        ;// that's it
        add esp, stack_size
        mov esi, ebp
        ret
    ;//
    ;//     E X I T
    ;//
    ;////////////////////////////////////////






;////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////
;///
;///
;///    W A I T  L O O P S
;///
;///
;////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////

    ;// eax must have value to fill with
    ;// ecx must have current count
    ;// edx must have sign of last trigger
    ;// ebx is input pointer

    ;// return zero flag if end of frame

    ;// we do two per loop

    ALIGN 16
    wait_dTp::  ;// wait for a pos edge

        .REPEAT
            mov edi, edx
            xor edi, [ebx+ecx*4]
            js dTp_trigger
        dTp_false_alarm:
            mov [ebp].data_X[ecx*4], eax
            inc ecx
            cmp ecx, SAMARY_LENGTH
            mov edi, edx
            jae dTp_done
            xor edi, [ebx+ecx*4]
            js dTp_trigger
            mov [ebp].data_X[ecx*4], eax
            inc ecx
        .UNTIL ecx >= SAMARY_LENGTH
        ;// zero flag had better be set
        ;// carry flag had better not be set
        dTp_done:
            retn

        dTp_trigger:

            btc edx, 31 ;// flip the sign bit
            inc edx     ;// state that we got an edge
            jnc dTp_false_alarm ;// jump if value WAS positive (pos to neg)
            jmp dTp_done    ;// zero is not set


    ALIGN 16
    wait_dTm::  ;// wait for a neg edge

        .REPEAT
            mov edi, edx
            xor edi, [ebx+ecx*4]
            js dTm_trigger
        dTm_false_alarm:
            mov [ebp].data_X[ecx*4], eax
            inc ecx
            cmp ecx, SAMARY_LENGTH
            mov edi, edx
            jae dTm_done
            xor edi, [ebx+ecx*4]
            js dTm_trigger
            mov [ebp].data_X[ecx*4], eax
            inc ecx
        .UNTIL ecx >= SAMARY_LENGTH
        ;// zero flag is set
        dTm_done:
            retn

        dTm_trigger:

            btc edx, 31     ;// toggle and test the sign bit
            inc edx         ;// state that we got an edge (reset zero in the process)
            jc dTm_false_alarm  ;// ignore if edx WAS neg (neg to pos)
            stc             ;// set the carry flag
            jmp dTm_done    ;// zero is not set



    comment ~ /*

    wait mode with sT

        these may be called at start of frame
        or may be called in mid frame

        regardless, we test the trigger using the current value of ecx

        if got trigger

            return with carry flag set

        else no trigger

            if partial frame

                fill the rest of the frame
                exit with zero flag set

            else full frame

                test previous changing
                if not set

                    test current value with eax
                    if same

                        exit

                else else

                fill frame with eax

    */ comment ~
    ALIGN 16
    wait_sTp::  ;// wait for a pos edge

        mov edi, edx            ;// xfer last value to edi
        xor edi, [ebx+ecx*4]    ;// test the current bit
        jns fill_the_rest       ;// no edge here
        ;// got a trigger
        btc edx, 31             ;// toggle and flip the sign bit
        inc edx                 ;// state that we got an edge
        jc sT_done              ;// jump if value WAS neg
        ;// got the wrong trigger
        jmp fill_the_rest       ;// jump to common routine down below

    ALIGN 16
    wait_sTm::  ;// wait for a neg edge

        mov edi, edx            ;// xfer last value to edi
        xor edi, [ebx+ecx*4]    ;// test the current bit
        jns fill_the_rest       ;// no edge here
        ;// got a trigger
        btc edx, 31             ;// toggle and flip the sign bit
        inc edx                 ;// state that we got an edge
        jc fill_the_rest        ;// jump if value WAS neg (neg to pos, wrong trigger)
        ;// got the right trigger
        stc                     ;// set the carry flag to indicate correct trigger
        jmp sT_done             ;// jump to common exit

    ALIGN 16
    fill_the_rest:
        or ecx, ecx             ;// see if ecx is zero
        lea edi, [ebp].data_X[ecx*4];// load destination now
        jnz fill_the_frame      ;// jump to partial fill if ecx is not zero
        ;// full frame fill
        test edx, PIN_CHANGING  ;// check if frame WAS changing
        jnz fill_the_frame      ;// have to fill if was changing

        cmp eax, DWORD PTR [edi];// see if new fill value is same as old
        jz sT_done              ;// skip fill if yes (zero already set)

    fill_the_frame:

        sub ecx, SAMARY_LENGTH  ;// need (SAMARY_LENGTH-ecx)
        jns skip_fill
        neg ecx                 ;//
        rep stosd               ;// store the fill value

    skip_fill:

        xor eax, eax        ;// set the zero flag, we're done with the frame

    sT_done:

        retn


;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;///
;///
;///    R A M P   M A C R O
;///
;///
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////

;// registers
;// ebp = osc_map
;// esi = input data
;// ebx = trigger data
;// ecx = current count
;// edx = flags high bit = last trigger

comment ~ /*
                    ;// return  sustain
                    ;// retrig  tracking
                    ;// ------  --------
0   ramp_sF_sT_mR:: ;// once    once
1   ramp_sF_sT_pR:: ;// once    once

2   ramp_sF_dT_mR:: ;// neg     yes
3   ramp_sF_dT_pR:: ;// pos     yes

4   ramp_dF_sT_mR:: ;// once    once
5   ramp_dF_sT_pR:: ;// once    once

6   ramp_dF_dT_mR:: ;// neg     yes
7   ramp_dF_dT_pR:: ;// pos     yes

8   ramp_sF_sT_nR:: ;// never   once        divide by 2, add 8
9   ramp_sF_dT_nR:: ;// never   yes
10  ramp_dF_sT_nR:: ;// never   once
11  ramp_dF_dT_nR:: ;// never   yes

*/ comment ~


    ADSR_RAMP MACRO freq:req, trig:req, mode:req

        LOCAL got_trigger, false_alarm

        ;// check the args first

        IFDIF <freq>,<dF>
        .ERRDIF <freq>,<sF>,<use dF or sF>
        ENDIF

        IFDIF <trig>,<dT>
        .ERRDIF <trig>,<sT>,<use dT or sT>
        ENDIF

        IFIDN <mode>,<nR>
        ELSEIFDIF <mode>,<mR>
        .ERRDIF <mode>,<pR>,<use mR,pR or nR>
        ENDIF


        ;// prepare FPU

            ;// enter as        ;// dYdX    Xend    Xnow    Ynow    dXdS
            IFIDN <freq>,<sF>
            fmul st, st(4)      ;// dYdS    Xend    Xnow    Ynow    dXdS
            ENDIF
            fxch st(3)          ;// Ynow    Xend    Xnow    dYdX    dXdS

        ;// sT trigger test

            IFIDN <trig>,<sT>

                mov edi, [ebx+ecx*4]    ;// get the trigger value
                xor edi, edx
                js got_trigger

            false_alarm:
            ENDIF

        ;// main loop

        .REPEAT

        ;// dT trigger test

            IFIDN <trig>,<dT>
                mov edi, [ebx+ecx*4]
                xor edi, edx
                js got_trigger
            false_alarm:
            ENDIF

        ;// dF/sF calc

            IFIDN <freq>,<dF>

                ;// ramp calculation
                ;// dXdS = abs(F/2) [esi+ecx*4] <-- dXdS is NOT updated
                ;// dYdS = dXdS * dYdX
                ;// Xnow+=dXdS
                ;// Ynow+=dYdS
                                ;// Ynow    Xend    Xnow    dYdX    dXdS
                fld [esi+ecx*4] ;// F       Ynow    Xend    Xnow    dYdX    dXdS
                fmul math_1_2   ;// dXdS    Ynow    Xend    Xnow    dYdX    dXdS
                fabs            ;// dXdS    Ynow    Xend    Xnow    dYdX    dXdS
                fadd st(3), st  ;// dXdS    Ynow    Xend    Xnew    dYdX    dXdS
                fmul st, st(4)  ;// dYdS    Ynow    Xend    Xnew    dYdX    dXdS
                fadd            ;// Ynew    Xend    Xnew    dYdX    dXdS
                fst [ebp].data_X[ecx*4]

            ELSEIFIDN <freq>,<sF>

                ;// ramp calculation
                ;// Xnow+=dXdS
                ;// Ynow+=dYdS
                                ;// Ynow    Xend    Xnow    dYdS    dXdS
                fadd st, st(3)  ;// Ynew    Xend    Xnow    dYdS    dXdS
                fxch st(2)      ;// Xnow    Xend    Ynew    dYdS    dXdS
                fadd st, st(4)  ;// Xnew    Xend    Ynew    dYdS    dXdS
                fxch st(2)      ;// Ynew    Xend    Xnew    dYdS    dXdS
                fst [ebp].data_X[ecx*4]

            ENDIF

        ;// segment done test

            fld st(2)       ;// Xnew    Ynew    Xend    Xnew    dYdX    dXdS
            fucomp st(2)    ;// Ynew    Xend    Xnew    dYd?    dXdS
            fnstsw ax
            sahf
            jae ramp_segment_done

        ;// iterate

            inc ecx

        .UNTIL ecx >= SAMARY_LENGTH     ;// bottom of loop
        jmp ramp_frame_done             ;// exit to common

    ;// trigger jump to
        ALIGN 16
        got_trigger:
            btc edx, 31
            inc edx
        IFIDN <mode>,<nR>
            jmp false_alarm
        ELSE
            IFIDN <mode>,<mR>
            jc false_alarm      ;// false alarm if neg to pos
            ELSE
            jnc false_alarm     ;// false alarm if pos to neg
            ENDIF
            jmp ramp_retrigger  ;// otherwise we got a retrigger
        ENDIF

        ENDM


;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;///
;///
;///    R A M P   L O O P S
;///
;///
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////

    ALIGN 16
    ramp_sF_sT_mR::     ADSR_RAMP sF,sT,mR  ;//00
    ALIGN 16
    ramp_sF_sT_pR::     ADSR_RAMP sF,sT,pR  ;//01
    ALIGN 16
    ramp_sF_dT_mR::     ADSR_RAMP sF,dT,mR  ;//02
    ALIGN 16
    ramp_sF_dT_pR::     ADSR_RAMP sF,dT,pR  ;//03
    ALIGN 16
    ramp_dF_sT_mR::     ADSR_RAMP dF,sT,mR  ;//04
    ALIGN 16
    ramp_dF_sT_pR::     ADSR_RAMP dF,sT,pR  ;//05
    ALIGN 16
    ramp_dF_dT_mR::     ADSR_RAMP dF,dT,mR  ;//06
    ALIGN 16
    ramp_dF_dT_pR::     ADSR_RAMP dF,dT,pR  ;//07
    ALIGN 16
    ramp_sF_sT_nR::     ADSR_RAMP sF,sT,nR  ;//08
    ALIGN 16
    ramp_sF_dT_nR::     ADSR_RAMP sF,dT,nR  ;//09
    ALIGN 16
    ramp_dF_sT_nR::     ADSR_RAMP dF,sT,nR  ;//10
    ALIGN 16
    ramp_dF_dT_nR::     ADSR_RAMP dF,dT,nR  ;//11


    ALIGN 16
    ramp_frame_done:

        or [ebp].pin_X.dwStatus, PIN_CHANGING   ;// turns off zero and carry
        xor eax, eax                            ;// turn on zero
        jmp ramp_done

    ALIGN 16
    ramp_segment_done:

        or [ebp].pin_X.dwStatus, PIN_CHANGING   ;// clears zero and carry flags
        jmp ramp_done

    ALIGN 16
    ramp_retrigger:

        or [ebp].pin_X.dwStatus, PIN_CHANGING   ;// turns off zero
        stc                                     ;// turn on carry

    ;// NOTE: do NOT put ALIGN 16 on this, add eax, 0 messes up the carry flag
    ramp_done:
                    ;// Ynow    Xend    Xnow    dYd?    dXdS
        fxch st(3)  ;// dYd?    Xend    Xnow    Ynow    dXdS
        fstp st     ;// Xend    Xnow    Ynow    dXdS
        fstp st     ;// Xnow    Ynow    dXdS
        retn


adsr_Calc ENDP





ASSUME_AND_ALIGN

ENDIF   ;// USE_THIS_FILE
END





