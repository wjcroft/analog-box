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
;//
;//##////////////////////////////////////////////////////////////////////////
;//
;// ABox_QKey.asm
;//
;//
;// TOC
;//
;// qkey_SetTable
;// qkey_Ctor
;// qkey_SetShape
;// qkey_Render
;// qkey_HitTest
;// qkey_Control
;// qkey_InitMenu
;// qkey_Command
;// qkey_SaveUndo
;// qkey_LoadUndo
;// qkey_Calc




OPTION CASEMAP:NONE

.586
.MODEL FLAT

USE_THIS_FILE equ 1

IFDEF USE_THIS_FILE

        .NOLIST
        include <Abox.inc>
        .LIST

.DATA


    ;// a struct for quantizing

        OSC_KEY STRUCT

            PR      REAL4   0.0 ;// N * 10.66 octaves
            numTable    dd  0   ;// number of elements currently in table
            numOn       dd  0   ;// number of frets that are on
            lastOn      dd  0   ;// indicator of last on fret that was quantized to
            fretOn      dd  0   ;// the number of the fret associated with last on

            K dd 128 DUP (0) ;// key offset table, max size allocated

        OSC_KEY ENDS


osc_QKey OSC_CORE { qkey_Ctor,,,qkey_Calc}
         OSC_GUI  { qkey_Render,qkey_SetShape,
                    qkey_HitTest,qkey_Control,,
                    qkey_Command,qkey_InitMenu,,,
                    qkey_SaveUndo, qkey_LoadUndo }
         OSC_HARD { }

    ;// don't make lines too long
    ofsPinData  = SIZEOF OSC_OBJECT + (SIZEOF APIN) * 3
    ofsOscData  = SIZEOF OSC_OBJECT + (SIZEOF APIN) * 3 + SAMARY_SIZE
    oscBytes    = SIZEOF OSC_OBJECT + (SIZEOF APIN) * 3 + SAMARY_SIZE + SIZEOF OSC_KEY

    OSC_DATA_LAYOUT { NEXT_QKey, IDB_KEY,OFFSET popup_QKEY, BASE_SHAPE_EFFECTS_GEOMETRY,
        3, 4,
        ofsPinData,
        ofsOscData,
        oscBytes  }

    OSC_DISPLAY_LAYOUT {qkey_container, QKEY_PSOURCE, ICON_LAYOUT( 11,1,2,5 ) }

    APIN_init {-1.0,,'M' ,, UNIT_MIDI } ;// input
    APIN_init {-0.5,,'R' ,, UNIT_MIDI } ;// ROOT
    APIN_init { 0.0,,'F' ,, UNIT_HERTZ OR PIN_OUTPUT } ;// output

    short_name  db  'Quan- tizer',0
    description db  'Converts a midi value to the closest available note. Output may be frequency or midi value. Used to define scales and modes.',0
    ALIGN 4

    ;// flags for modes, stored in object.dwUser

        QKEY_MODE_MASK      equ 0FFFFFC00h    ;// 12 bits
        QKEY_MODE_TEST      equ 0000003FFh

        QKEY_HOVER_TEST     equ  0F000000h  ;// INDEX of the button that has the hover
        QKEY_HOVER_MASK     equ NOT QKEY_HOVER_TEST
        QKEY_HOVER_SHIFT    equ 24

        QKEY_OUTPUT_MIDI    equ  00010000h  ;// set true to output Midi notes

        ;// each bit in the mode specifies a key that can be played
        ;// we count the bits to get the notes/per octave
        ;// there are always ten and half octaves

    ;// two fonts specify what the output pin shape is

        qkey_font_F dd  0
        qkey_font_M dd  0

    ;// table of pDests for drawing the buttons

        qkey_pDest  dd 12 dup(0)

        ;// left sides of frets
        qkey_x      dd  0 ,12 ,22,32,44,54
                    dd  65,76,87,98,109,119,129 ;// one extra value
        qkey_mask   dd  0   ;// mask of the 'o' for the buttons

    ;// layout number

        QKEY_DEST_X equ 4   ;// offset from left to center of first fret
        QKEY_DEST_Y equ 14  ;// offset form top to center of first row

        QKEY_MOUSE_TOP equ 10   ;// highest level for mouse testing


    OSC_QKEY_MAP STRUCT

        OSC_OBJECT  {}
        pin_m   APIN    {}
        pin_r   APIN    {}
        pin_f   APIN    {}
        data_f  dd  SAMARY_LENGTH DUP (?)
        qkey    OSC_KEY {}

    OSC_QKEY_MAP ENDS





.CODE

ASSUME_AND_ALIGN
qkey_SetTable PROC

    ;// this builds the internal look up table for this object

    ;// destroys edi and ebx

        ASSUME esi:PTR OSC_OBJECT

        OSC_TO_DATA esi, edi, OSC_KEY

    ;// psuedo kludge
    ;// the root bit must ALWAYS be on

        or [esi].dwUser, 1

    ;// count the number of bits that are on

        mov eax, [esi].dwUser
        xor edx, edx
        xor ecx, ecx
        xor ebx, ebx

        .REPEAT
            bt eax, ecx
            adc ebx, edx
            inc ecx
            bt eax, ecx
            adc ebx, edx
            inc ecx
        .UNTIL ecx >= 12

        mov [edi].numOn, ebx

    ;// calculate N and PR

        ;//fild  DWORD PTR [esp]    ;// numNotes
        fild [edi].numOn
        fmul  math_10_2_3       ;// times notes per octave
        fist  [edi].numTable    ;// equals total notes in lookup table
        fstp  [edi].PR

    ;// compute the table

        xor ecx, ecx    ;// ecx counts chromatic notes
        xor edx, edx    ;// edx counts K indexs
        xor ebx, ebx    ;// ebx counts bit positions
                        ;// eax has the bit mask
        .WHILE ecx < 128

            bt eax, ebx                 ;// test if we play this note
            .IF CARRY?                  ;// we do, so store the chromatic index
                mov [edi+edx*4].K, ecx
                inc edx                 ;// and advance the K index
            .ENDIF
            inc ebx                     ;// increase the bit counter
            .IF ebx >= 12               ;// if bit counter >= 12
                xor ebx, ebx            ;// reset it to zero
            .ENDIF
            inc ecx                     ;// iterate 'till we're done
        .ENDW

    ;// that's it

        ret

qkey_SetTable ENDP


ASSUME_AND_ALIGN
qkey_Ctor PROC      ;// uses edi

        ;// register call
        ASSUME ebp:PTR LIST_CONTEXT ;// preserve
        ASSUME esi:PTR OSC_OBJECT   ;// preserve
        ASSUME edi:PTR OSC_BASE     ;// may destroy
        ASSUME ebx:PTR FILE_OSC     ;// may destroy
        ASSUME edx:PTR FILE_HEADER  ;// may destroy

    ;// set our default settings, and make sure no bad bits are on

        and [esi].dwUser, QKEY_HOVER_MASK
        .IF ZERO?
            mov [esi].dwUser, 101010110101y ;// ionian
        .ENDIF

    ;// then build the lookup table for this object

        invoke qkey_SetTable

    ;// that's it

        ret

qkey_Ctor ENDP


ASSUME_AND_ALIGN
qkey_SetShape   PROC

    ;// sets the shape of the output pin to F or M
    ;// we also set the units

    ASSUME ebp:PTR LIST_CONTEXT
    ASSUME esi:PTR OSC_OBJECT

    ;// make sure the fonts have been allocated

        .IF !qkey_font_F
        push edi

            mov eax, 'F'
            lea edi, font_bus_slist_head
            invoke font_Locate
            mov qkey_font_F, edi

            mov eax, 'M'
            lea edi, font_bus_slist_head
            invoke font_Locate
            mov qkey_font_M, edi

        pop edi
        .ENDIF

    ;// set the output pin correctly

        OSC_TO_PIN_INDEX esi, ebx, 2    ;// get the pin

        .IF [esi].dwUser & QKEY_OUTPUT_MIDI ;// midi output ?

            pushd UNIT_MIDI
            pushd 0
            pushd qkey_font_M

        .ELSE

            pushd UNIT_HERTZ
            pushd 0
            pushd qkey_font_F

        .ENDIF

        call pin_SetNameAndUnit

        jmp osc_SetShape    ;// exit to base class

qkey_SetShape ENDP


ASSUME_AND_ALIGN
qkey_Render PROC

    ASSUME esi:PTR OSC_QKEY_MAP
    ASSUME edi:PTR OSC_BASE

    ;// make sure the pdest table is built

        .IF !qkey_pDest[0]

            push esi

            ;// get the button symbol first

                mov eax, 'o'
                lea edi, font_bus_slist_head
                invoke font_Locate
                mov eax, (GDI_SHAPE PTR [edi]).pMask
                mov qkey_mask, eax

            ;// then build the pdest table

                lea edi, qkey_pDest ;// point at dest table
                lea esi, qkey_x     ;// point at source table

                mov eax, QKEY_DEST_Y;// define the first item
                mul gdi_bitmap_size.x   ;// turn into a gdi offset
                mov ecx, 12         ;// 12 notes
                lea edx, [eax+QKEY_DEST_X]  ;// edx is the base
                .REPEAT

                    lodsd       ;// get the offset
                    add eax, edx;// add the base
                    dec ecx     ;// decrease the count
                    stosd       ;// store in table

                .UNTIL ZERO?

            pop esi

        .ENDIF

    ;// call the base first

        invoke gdi_render_osc

    ;// draw the shapes that are on

        mov edx, [esi].dwUser
        xor ecx, ecx
        mov eax, F_COLOR_OSC_TEXT
        push esi

        .REPEAT

            shr edx, 1      ;// is this bit on ?
            .IF CARRY?

                push edx                ;// save the bits
                mov ebx, qkey_mask      ;// get the mask
                mov edi, [esi].pDest    ;// get our source
                push ecx                ;// save the count
                add edi, qkey_pDest[ecx*4]  ;// add appropriate offset
                .IF ecx == [esi].qkey.fretOn
                    mov eax, F_COLOR_OSC_HOVER
                .ENDIF
                invoke shape_Fill           ;// fill
                pop ecx
                mov eax, F_COLOR_OSC_TEXT
                pop edx
                mov esi, [esp]  ;// reload esi

            .ENDIF
            inc ecx

        .UNTIL ecx >= 12

    ;// do the hover

        mov edx, [esi].dwUser       ;// get dwUser
        and edx, QKEY_HOVER_TEST    ;// strip out extra
        .IF !ZERO?                  ;// anything ?

            .IF app_bFlags & (APP_MODE_OSC_HOVER OR APP_MODE_CON_HOVER)

                shr edx, QKEY_HOVER_SHIFT   ;// turn into a table index
                mov eax, F_COLOR_DESK_HOVER ;// load the color
                mov edi, [esi].pDest        ;// load our dest
                mov ebx, shape_pin_font.pOut1   ;// get the font shape to highlight with
                add edi, qkey_pDest[edx*4]  ;// add appropriate offset
                invoke shape_Fill           ;// fill the outline

            .ELSE   ;// time to shut this off

                not edx
                and [esi].dwUser, edx

            .ENDIF

        .ENDIF

    ;// that should do it

        pop esi
        ret

qkey_Render ENDP



ASSUME_AND_ALIGN
qkey_HitTest PROC

    ASSUME esi:PTR OSC_OBJECT
    ASSUME ebp:PTR LIST_CONTEXT

    ;// different from other hit test's we'll use geometry for this


    ;// make sure old hovers are turned off first

        .IF [esi].dwUser & QKEY_HOVER_TEST

            and [esi].dwUser, QKEY_HOVER_MASK   ;// turn off old hovers
            GDI_INVALIDATE_OSC HINTI_OSC_UPDATE

        .ENDIF

    ;// then figure out what we hit


    point_Get mouse_now
    point_SubTL [esi].rect

    .IF edx > QKEY_MOUSE_TOP

        lea ebx, qkey_x
        xor ecx, ecx

        .WHILE eax > DWORD PTR [ebx+ecx*4]

            inc ecx

        .ENDW
        DEBUG_IF <ecx !> 12>    ;// not supposed to happen

        dec ecx
        js @F       ;// don't hover the first one
        jz @F

            shl ecx, QKEY_HOVER_SHIFT   ;// shove index into place
            or [esi].dwUser, ecx        ;// set as new hover
            xor eax, eax                ;// clear for the next test
            GDI_INVALIDATE_OSC HINTI_OSC_UPDATE
            inc eax                     ;// clear any flags we may have set
            stc         ;// we are hit, return the carry flag set
            ret

    .ENDIF

    ;// nothing was hit, return with no flags sets

    @@: xor eax, eax
        inc eax
        ret

qkey_HitTest ENDP

ASSUME_AND_ALIGN
qkey_Control PROC

    ASSUME esi:PTR OSC_OBJECT
    ASSUME ebp:PTR LIST_CONTEXT
    ;// eax has the message

    ;// simply enough, if we get mouse down we toggle the state

    cmp eax, WM_LBUTTONDOWN
    mov eax, 0
    jnz all_done

    mov ecx, [esi].dwUser       ;// get dwUser
    and ecx, QKEY_HOVER_TEST    ;// strip out bits
    shr ecx, QKEY_HOVER_SHIFT   ;// into an index
    btc [esi].dwUser, ecx       ;// compliment the bit

    GDI_INVALIDATE_OSC HINTI_OSC_UPDATE     ;// shedule for update

    invoke qkey_SetTable    ;// update the table

    mov eax, CON_HAS_MOVED

all_done:

    ret

qkey_Control ENDP

ASSUME_AND_ALIGN
qkey_InitMenu PROC  ;// STDCALL uses esi edi pObject:PTR OSC_OBJECT

    ASSUME esi:PTR OSC_OBJECT
    mov ebx, [esi].dwUser

    .IF ebx & QKEY_OUTPUT_MIDI
        invoke CheckDlgButton, popup_hWnd, ID_KEY_MIDINOTE, BST_CHECKED
    .ELSE
        invoke CheckDlgButton, popup_hWnd, ID_KEY_FREQUENCY, BST_CHECKED
    .ENDIF

    .IF ebx & 10b
        invoke CheckDlgButton, popup_hWnd, VK_1, BST_CHECKED
    .ENDIF
    .IF ebx & 100b
        invoke CheckDlgButton, popup_hWnd, VK_2, BST_CHECKED
    .ENDIF
    .IF ebx & 1000b
        invoke CheckDlgButton, popup_hWnd, VK_3, BST_CHECKED
    .ENDIF
    .IF ebx & 10000b
        invoke CheckDlgButton, popup_hWnd, VK_4, BST_CHECKED
    .ENDIF
    .IF ebx & 100000b
        invoke CheckDlgButton, popup_hWnd, VK_5, BST_CHECKED
    .ENDIF
    .IF ebx & 1000000b
        invoke CheckDlgButton, popup_hWnd, VK_6, BST_CHECKED
    .ENDIF
    .IF ebx & 10000000b
        invoke CheckDlgButton, popup_hWnd, VK_7, BST_CHECKED
    .ENDIF
    .IF ebx & 100000000b
        invoke CheckDlgButton, popup_hWnd, VK_8, BST_CHECKED
    .ENDIF
    .IF ebx & 1000000000b
        invoke CheckDlgButton, popup_hWnd, VK_9, BST_CHECKED
    .ENDIF
    .IF ebx & 10000000000b
        invoke CheckDlgButton, popup_hWnd, VK_0, BST_CHECKED
    .ENDIF
    .IF ebx & 100000000000b
        invoke CheckDlgButton, popup_hWnd, VK_MINUS, BST_CHECKED
    .ENDIF

    xor eax, eax    ;// return zero, or else
    ret

qkey_InitMenu ENDP


ASSUME_AND_ALIGN
qkey_Command PROC   ;//  STDCALL uses esi edi pObject:ptr OSC_OBJECT, cmdID:DWORD

    ASSUME esi:PTR OSC_OBJECT
    ;// eax has command id

    cmp eax, ID_KEY_FREQUENCY
    jne @F
        and [esi].dwUser, NOT QKEY_OUTPUT_MIDI
        or [esi].dwHintI, HINTI_OSC_SHAPE_CHANGED
        jmp all_done

@@: cmp eax, ID_KEY_MIDINOTE
    jne @F
        or  [esi].dwUser, QKEY_OUTPUT_MIDI
        or [esi].dwHintI, HINTI_OSC_SHAPE_CHANGED
        jmp all_done

@@: cmp eax, VK_1
    jne @F
        xor [esi].dwUser, 10b
        jmp set_table

@@: cmp eax, VK_2
    jne @F
        xor [esi].dwUser, 100b
        jmp set_table

@@: cmp eax, VK_3
    jne @F
        xor [esi].dwUser, 1000b
        jmp set_table

@@: cmp eax, VK_4
    jne @F
        xor [esi].dwUser, 10000b
        jmp set_table

@@: cmp eax, VK_5
    jne @F
        xor [esi].dwUser, 100000b
        jmp set_table

@@: cmp eax, VK_6
    jne @F
        xor [esi].dwUser, 1000000b
        jmp set_table

@@: cmp eax, VK_7
    jne @F
        xor [esi].dwUser, 10000000b
        jmp set_table

@@: cmp eax, VK_8
    jne @F
        xor [esi].dwUser, 100000000b
        jmp set_table

@@: cmp eax, VK_9
    jne @F
        xor [esi].dwUser, 1000000000b
        jmp set_table

@@: cmp eax, VK_0
    jne @F
        xor [esi].dwUser, 10000000000b
        jmp set_table

@@: cmp eax, VK_MINUS
    jne osc_Command
        xor [esi].dwUser, 100000000000b

set_table:

    invoke qkey_SetTable

all_done:

    mov eax, POPUP_REDRAW_OBJECT + POPUP_SET_DIRTY
    ret

qkey_Command ENDP


ASSUME_AND_ALIGN
qkey_SaveUndo   PROC

        ASSUME esi:PTR OSC_OBJECT

        ;// edx enters as either UNREDO_CONTROL_OSC or UNREDO_COMMAND
        ;// edi enters as where to store
        ;//
        ;// task:   1) save nessary data
        ;//         2) iterate edi
        ;//
        ;// may use all registers except ebp

        mov eax, [esi].dwUser
        stosd

        ret

qkey_SaveUndo ENDP


ASSUME_AND_ALIGN
qkey_LoadUndo PROC

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

        mov eax, [edi]
        and eax, QKEY_HOVER_MASK
        mov [esi].dwUser, eax

        invoke qkey_SetTable

        ret

qkey_LoadUndo ENDP





;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;///
;///
;///    C A L C   M A C R O S
;///



.DATA

    ALIGN 8
        qkey_temp_1    dd    0
    ALIGN 8
        qkey_temp_2    dd    0
    ALIGN 8


.CODE




QKEY_dFdR MACRO

    LOCAL @01, @02, @11, @12
    LOCAL enter_loop, top_of_loop

    ASSUME edx:PTR DWORD
    ASSUME esi:PTR DWORD

        xor eax, eax
        xor ecx, ecx
        OSC_TO_DATA ebx, ebx, OSC_KEY

        fld [ebx].PR        ;// PR
        fld math_1_128      ;// 1/128   PR
        fld math_10_2_3     ;// 10.66   128     PR
        fld math_12         ;// 12      10.66   128     PR
        fld math_1_2        ;// 0.5     12      10.66   1/128   PR

        ;// need to do one pass to set up the init value

            fld [edx+ecx*4] ;// k       0.5     12      10.66   1/128   PR
            fabs
            fmul st, st(3)  ;// k*10.66 0.5     12      10.66   1/128   PR
            fld st(1)       ;// 0.5     k*10.66 0.5     12      10.66   1/128   PR
            fsubr st, st(1) ;// k*10.66 k*10.66 0.5     12      10.66   1/128   PR
            frndint         ;// int
            fsub            ;// fract

            fmul st, st(2)  ;// T       0.5     12      10.66   1/128   PR
            fld [esi+ecx*4] ;// n       T       0.5     12      10.66   1/128   PR
            fabs            ;// n       T       0.5     12      10.66   1/128   PR
            fxch            ;// T       n       0.5     12      10.66   1/128   PR
            fist qkey_temp_1;// T       n       0.5     12      10.66   1/128   PR

            fmul st, st(5)  ;// t       n       0.5     12      10.66   1/128   PR
            xor eax, eax
            fsub            ;// n-t     0.5     12      10.66   1/128   PR
            fmul st,st(5)   ;// (n-t)PR 0.5     12      10.66   1/128   PR
            fistp qkey_temp_2

            or eax, qkey_temp_2
            js @11
            cmp eax, [ebx].numTable
            jb @12
            mov eax, [ebx].numTable
            dec eax ;// bug fix abox226
            jmp @12
        @11:xor eax, eax
        @12:mov eax, [ebx+eax*4].K  ;// load the index from table

            add eax, qkey_temp_1    ;// add k back on
            and eax, 127            ;// make sure eax doesn't go out of range

            ;// look up and store the output

            mov eax, DWORD PTR [ebp+eax*4]  ;// get the frequency value
            inc ecx
            stosd                           ;// store the frequency

            xor eax, eax
            jmp enter_loop


        ALIGN 16
        top_of_loop:

            sub eax, DWORD PTR [edi-8]

        enter_loop:

            fld [edx+ecx*4] ;// k       0.5     12      10.66   1/128   PR
            fabs
            fmul st, st(3)  ;// k*10.66 0.5     12      10.66   1/128   PR
            or [esp], eax
            fld st(1)       ;// 0.5     k*10.66 0.5     12      10.66   1/128   PR
            fsubr st, st(1) ;// k*10.66 k*10.66 0.5     12      10.66   1/128   PR
            frndint         ;// int
            fsub            ;// fract

            fmul st, st(2)  ;// T       0.5     12      10.66   1/128   PR
            fld [esi+ecx*4] ;// n       T       0.5     12      10.66   1/128   PR
            fabs            ;// n       T       0.5     12      10.66   1/128   PR
            fxch            ;// T       n       0.5     12      10.66   1/128   PR
            fist qkey_temp_1;// T       n       0.5     12      10.66   1/128   PR

            fmul st, st(5)  ;// t       n       0.5     12      10.66   1/128   PR
            xor eax, eax
            fsub            ;// n-t     0.5     12      10.66   1/128   PR
            fmul st,st(5)   ;// (n-t)PR 0.5     12      10.66   1/128   PR
            fistp qkey_temp_2

            or eax, qkey_temp_2
            js @01
            cmp eax, [ebx].numTable
            jb @02
            mov eax, [ebx].numTable
            dec eax ;// bug fix abox226
            jmp @02
        @01:xor eax, eax
        @02:mov eax, [ebx+eax*4].K  ;// load the index from table

            inc ecx

            add eax, qkey_temp_1    ;// add k back on
            and eax, 127

            ;// look up and store the output

            cmp ecx, SAMARY_LENGTH

            mov eax, DWORD PTR [ebp+eax*4]  ;// get the frequency value

            stosd                           ;// store the frequency

            jb top_of_loop

            sub eax, DWORD PTR [edi-8]
            or [esp], eax

        fstp st
        fstp st
        fstp st
        fstp st
        fstp st

ENDM










QKEY_dFsR MACRO

    LOCAL @01, @02, @11, @12
    LOCAL enter_loop, top_of_loop

    ASSUME edx:PTR DWORD
    ASSUME esi:PTR DWORD

        xor eax, eax
        xor ecx, ecx
        OSC_TO_DATA <(OSC_OBJECT PTR [ebx])>, ebx, OSC_KEY

        fld [ebx].PR        ;// PR

        ;// need to do one pass to set up the init value
        ;// we also compute the static T and t

            fld [edx]       ;// k       PR
            fabs
            fmul math_10_2_3;// k*10.66 PR
            fld math_1_2    ;// 0.5     k*10.66 PR
            fsubr st, st(1) ;// k*10.66 k*10.66 PR
            frndint         ;// int
            fsub            ;// fract

            fmul math_12    ;// T       PR
            fld [esi]       ;// n       T       PR
            fabs            ;// n       T       PR
            fxch            ;// T       n       PR
            fist qkey_temp_1;// T       n       PR

            fmul math_1_128;//  t       n       PR
            xor eax, eax
            fxch            ;// n       t       PR

            fsub st, st(1)  ;// n-t     t       PR
            fmul st,st(2)   ;// (n-t)PR t       PR
            fistp qkey_temp_2

            or eax, qkey_temp_2
            js @11
            cmp eax, [ebx].numTable
            jb @12
            mov eax, [ebx].numTable
            dec eax ;// bug fix abox226
            jmp @12
        @11:xor eax, eax
        @12:mov eax, [ebx+eax*4].K  ;// load the index from table

            add eax, qkey_temp_1    ;// add k back on
            and eax, 127            ;// make sure eax doesn't go out of range

            ;// look up and store the output

            mov eax, DWORD PTR [ebp+eax*4]  ;// get the frequency value
            inc ecx
            stosd                           ;// store the frequency

            xor eax, eax
            jmp enter_loop

        ALIGN 16
        top_of_loop:

            sub eax, DWORD PTR [edi-8]

        enter_loop:

            fld [esi+ecx*4] ;// n       t       PR
            fabs            ;// n       t       PR

            fsub st, st(1)  ;// n-t     t       PR
            or [esp], eax
            fmul st,st(2)   ;// (n-t)PR t       PR
            inc ecx
            fistp qkey_temp_2
            xor eax, eax

            or eax, qkey_temp_2
            js @01
            cmp eax, [ebx].numTable
            jb @02
            mov eax, [ebx].numTable
            dec eax ;// bug fix abox226
            jmp @02
        @01:xor eax, eax
        @02:mov eax, [ebx+eax*4].K  ;// load the index from table

            add eax, qkey_temp_1    ;// add k back on
            and eax, 127

            ;// look up and store the output

            mov eax, DWORD PTR [ebp+eax*4]  ;// get the frequency value
            cmp ecx, SAMARY_LENGTH
            stosd                           ;// store the frequency
            jb top_of_loop


            sub eax, DWORD PTR [edi-8]
            or [esp], eax

        fstp st
        fstp st

ENDM




QKEY_dFnR MACRO

    LOCAL @02, @12
    LOCAL enter_loop, top_of_loop

    ASSUME edx:PTR DWORD
    ASSUME esi:PTR DWORD

        xor eax, eax
        xor ecx, ecx
        OSC_TO_DATA <(OSC_OBJECT PTR [ebx])>, ebx, OSC_KEY

        fld [ebx].PR        ;// PR

        ;// need to do one pass to set up the init value

            fld [esi+ecx*4] ;// n   PR
            fabs            ;// n   PR
            fmul st,st(1)   ;// (n-t)PR PR
            fistp qkey_temp_2

            mov eax, qkey_temp_2
            cmp eax, [ebx].numTable
            jb @02
            mov eax, [ebx].numTable
            dec eax ;// bug fix abox226
        @02:mov eax, [ebx+eax*4].K  ;// load the index from table
            inc ecx
            mov eax, DWORD PTR [ebp+eax*4]  ;// get the frequency value
            stosd                           ;// store the frequency
            xor eax, eax
            jmp enter_loop

        ALIGN 16
        top_of_loop:

            sub eax, DWORD PTR [edi-8]

        enter_loop:

            fld [esi+ecx*4] ;// n   PR
            fabs            ;// n   PR
            or [esp], eax
            fmul st,st(1)   ;// (n-t)PR PR
            fistp qkey_temp_2
            mov eax, qkey_temp_2
            cmp eax, [ebx].numTable
            jb @12
            mov eax, [ebx].numTable
            dec eax ;// bug fix abox226
        @12:mov eax, [ebx+eax*4].K  ;// load the index from table
            inc ecx
            mov eax, DWORD PTR [ebp+eax*4]  ;// get the frequency value
            cmp ecx, SAMARY_LENGTH
            stosd                           ;// store the frequency
            jb top_of_loop

            sub eax, DWORD PTR [edi-8]
            or [esp], eax

        fstp st


ENDM









QKEY_sFsR MACRO

    LOCAL @11, @12

    ASSUME edx:PTR DWORD    ;// R pin data
    ASSUME esi:PTR DWORD    ;// M pin data
    ASSUME edi:PTR DWORD    ;// destination

        OSC_TO_DATA <(OSC_OBJECT PTR [ebx])>, ebx, OSC_KEY

        fld [ebx].PR        ;// PR

        ;// need to do one pass to set up the init value
        ;// we also compute the static T and t

            fld [edx]           ;// k       PR
            fabs
            fmul math_10_2_3    ;// k*10.66 PR
            fld math_1_2        ;// 0.5     k*10.66 PR
            fsubr st, st(1)     ;// k*10.66 k*10.66 PR
            frndint             ;// int
            fsub                ;// fract

            fmul math_12        ;// T       PR
            fld [esi]           ;// n       T       PR
            fabs                ;// n       T       PR
            fxch                ;// T       n       PR
            fist qkey_temp_1    ;// T       n       PR

            fmul math_1_128     ;// t       n       PR
            xor eax, eax
            fsub                ;// n-t     PR
            fmul                ;// (n-t)PR
            fistp qkey_temp_2

            or eax, qkey_temp_2
            js @11
            cmp eax, [ebx].numTable
            jb @12
            mov eax, [ebx].numTable
            dec eax ;// bug fix abox226
            jmp @12
        @11:xor eax, eax
        @12:mov eax, [ebx+eax*4].K  ;// load the index from table

            add eax, qkey_temp_1    ;// add k back on
            and eax, 127            ;// make sure eax doesn't go out of range

            ;// look up and store the output

            mov eax, DWORD PTR [ebp+eax*4]  ;// get the frequency value

            .IF eax!=[edi] || ecx & PIN_CHANGING

                mov ecx, SAMARY_LENGTH
                rep stosd

            .ENDIF

        add esp, 4
        jmp skip_changing



ENDM




QKEY_sFnR MACRO

    LOCAL @02

    ASSUME esi:PTR DWORD
    ASSUME edi:PTR DWORD

            OSC_TO_DATA <(OSC_OBJECT PTR [ebx])>, ebx, OSC_KEY

        ;// need to do one pass to set up the init value

            fld [esi]       ;// n   PR
            fld [ebx].PR    ;// PR  n
            fmul            ;// nPR
            fabs            ;// nPR
            fistp qkey_temp_2

            mov eax, qkey_temp_2
            cmp eax, [ebx].numTable
            .IF !CARRY? ;// jb @02
            mov eax, [ebx].numTable
            dec eax ;// bug fix abox226
        ;// @02:
            .ENDIF
            mov eax, [ebx+eax*4].K  ;// load the index from table
            mov eax, DWORD PTR [ebp+eax*4]  ;// get the frequency value

        .IF eax != [edi] || ecx & PIN_CHANGING

            mov ecx, SAMARY_LENGTH
            rep stosd                   ;// store the frequency

        .ENDIF

        add esp, 4
        jmp skip_changing

ENDM















;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
qkey_Calc PROC USES esi ebp

comment ~ /*

    registers:

    F pointer   esi+ecx*4
    R pointer   edx+ecx*4
    O pointer   edi
    changing    stack
    counter     ecx
    chrome      ebp+eax*4
    param       ebx
    temp        eax

*/ comment ~

    GET_OSC_FROM ebx, esi
    OSC_TO_PIN_INDEX esi, edi, 2    ;// output pin
    DEBUG_IF < !![edi].pPin >   ;// supposed to be connected to calc


    OSC_TO_PIN_INDEX ebx, esi, 0    ;// input pin
    .IF [esi].pPin      ;// input connected ?

        pushd 0 ;// temp for changing

    ;// stack:  change  ebp esi ret

        .IF [ebx].dwUser & QKEY_OUTPUT_MIDI
            mov ebp, math_pMidiNote ;// use the midi note table
        .ELSE
            mov ebp, math_pChromatic    ;// use the frequency table
        .ENDIF

        mov esi, [esi].pPin

        .IF [esi].dwStatus & PIN_CHANGING

            ;// F has changing data

            mov edi, [edi].pData    ;// load the data pointer
            OSC_TO_PIN_INDEX ebx, edx, 1    ;// get the R pin
            mov esi, [esi].pData    ;// load the data pointer
            .IF [edx].pPin      ;// R is connected

                mov edx, [edx].pPin

                .IF [edx].dwStatus & PIN_CHANGING

                    mov edx, [edx].pData

;///////////////////////////////////////////////////
;//
;// dFdR
;//
        QKEY_dFdR
;//
;// dFdR
;//
;///////////////////////////////////////////////////


                    .ELSE
                    ASSUME edx:PTR APIN

                        mov edx, [edx].pData

;///////////////////////////////////////////////////
;//
;// dFsR
;//
    QKEY_dFsR
;//
;// dFsR
;//
;///////////////////////////////////////////////////


                    .ENDIF

                .ELSE       ;// R is not connected

;///////////////////////////////////////////////////
;//
;// dFnR
;//
        QKEY_dFnR
;//
;// dFnR
;//
;///////////////////////////////////////////////////

                .ENDIF

            .ELSE   ;// F data is not changing
            ASSUME esi:PTR APIN
            ASSUME edx:PTR APIN
            ASSUME ebx:PTR OSC_OBJECT
            ASSUME edi:PTR APIN

                mov ecx, [edi].dwStatus
                mov esi, [esi].pData
                and [edi].dwStatus, NOT PIN_CHANGING
                OSC_TO_PIN_INDEX ebx, edx, 1    ;// get the R pin
                mov edi, [edi].pData
                .IF [edx].pPin      ;// R is connected

                    mov edx, [edx].pPin

                    .IF [edx].dwStatus & PIN_CHANGING

                        mov edx, [edx].pData

;///////////////////////////////////////////////////
;//
;// sFdR
;//
        QKEY_dFdR
;//
;// sFdR
;//
;///////////////////////////////////////////////////


                    .ELSE
                    ASSUME edx:PTR APIN
                        mov edx, [edx].pData

;///////////////////////////////////////////////////
;//
;// sFsR
;//
        QKEY_sFsR
;//
;// sFsR
;//
;///////////////////////////////////////////////////


                    .ENDIF

                .ELSE       ;// R is not connected

;///////////////////////////////////////////////////
;//
;// sFnR
;//
    ;//     QKEY_sFnR


    ASSUME esi:PTR DWORD
    ASSUME edi:PTR DWORD

            OSC_TO_DATA <(OSC_OBJECT PTR [ebx])>, ebx, OSC_KEY

        ;// need to do one pass to set up the init value

            fld [esi]       ;// n   PR
            fld [ebx].PR    ;// PR  n
            fmul            ;// nPR
            fabs            ;// nPR
            fistp qkey_temp_2

            mov eax, qkey_temp_2
            cmp eax, [ebx].numTable
            .IF !CARRY? ;// jb @02
            mov eax, [ebx].numTable
            dec eax ;// bug fix abox226
        ;// @02:
            .ENDIF
            mov eax, [ebx+eax*4].K  ;// load the index from table
            mov eax, DWORD PTR [ebp+eax*4]  ;// get the frequency value

        .IF eax != [edi] || ecx & PIN_CHANGING

            mov ecx, SAMARY_LENGTH
            rep stosd                   ;// store the frequency

        .ENDIF

        add esp, 4
        jmp skip_changing




;//
;// sFnR
;//
;///////////////////////////////////////////////////

                .ENDIF

            .ENDIF

            pop edx ;// retrieve changing

;// stack:  ebp     esi     ret

            mov ebx, [esp+4h]   ;// get the osc
            OSC_TO_PIN_INDEX ebx, ebx, 2
            .IF edx
                or [ebx].dwStatus, PIN_CHANGING
            .ELSE
                and [ebx].dwStatus, NOT PIN_CHANGING
            .ENDIF


        ASSUME edi:PTR APIN
        ;// F not connected, fill with last value
        .ELSEIF [edi].dwStatus & PIN_CHANGING

                and [edi].dwStatus, NOT PIN_CHANGING
                mov edi, [edi].pData
                mov eax, DWORD PTR [edi]
                mov ecx, SAMARY_LENGTH
                rep stosd

        .ENDIF

skip_changing:


        xor eax, eax
        mov esi, [esp+4h]   ;// get the osc
        ASSUME esi:PTR OSC_QKEY_MAP

    ;// determine which fret should be on

    or eax, [esi].dwHintOsc     ;// onscreen is hintosc sign bit
    .IF SIGN?                   ;// don't bother if offscreen

        mov eax, qkey_temp_2
        xor edx, edx
        div [esi].qkey.numOn
        .IF edx != [esi].qkey.lastOn
            mov [esi].qkey.lastOn, edx  ;//

            mov eax, [esi].dwUser
            inc edx         ;// need to bump one
            xor ecx, ecx    ;// counter of on bits
            xor ebx, ebx    ;// a fret index
            .REPEAT
                shr eax, 1
                inc ebx
                adc ecx, 0
                DEBUG_IF <ebx !> 12>
            .UNTIL ecx == edx

            dec ebx
            mov [esi].qkey.fretOn, ebx

            ;// then schedule for a redraw

            invoke play_Invalidate_osc  ;// schedule for redraw

        .ENDIF

    .ENDIF



    ret

qkey_Calc ENDP




ASSUME_AND_ALIGN




ENDIF   ;// use this file

END
