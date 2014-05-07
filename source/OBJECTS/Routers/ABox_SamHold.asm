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
;//     ABox_SamHold.asm
;//
;//
;// TOC:
;// sh_GetUnit
;// sh_SyncPins
;// sh_Ctor
;// sh_Render
;// sh_PrePlay
;// sh_Calc
;// sh_InitMenu
;// sh_Command
;// sh_SaveUndo
;// sh_LoadUndo



OPTION CASEMAP:NONE

.586
.MODEL FLAT

USE_THIS_FILE equ 1

IFDEF USE_THIS_FILE

    .NOLIST
    include <Abox.inc>
    .LIST

.DATA


osc_SamHold OSC_CORE { sh_Ctor,,sh_PrePlay,sh_Calc }
            OSC_GUI  { sh_Render,,,,,sh_Command, sh_InitMenu,,,osc_SaveUndo,sh_LoadUndo,sh_GetUnit }
            OSC_HARD { }

    ;// don't make lines too long
    ofsPinData  = SIZEOF OSC_OBJECT + ( SIZEOF APIN ) * 4
    ofsOscData  = SIZEOF OSC_OBJECT + ( SIZEOF APIN ) * 4 + SAMARY_SIZE * 2
    oscBytes    = SIZEOF OSC_OBJECT + ( SIZEOF APIN ) * 4 + SAMARY_SIZE * 2

    OSC_DATA_LAYOUT{NEXT_SamHold,IDB_SAMHOLD,OFFSET popup_SAMHOLD,BASE_NEED_THREE_LINES,
        4,4,
        ofsPinData,
        ofsOscData,
        oscBytes  }

    OSC_DISPLAY_LAYOUT { sh_container, SH_PSOURCE, ICON_LAYOUT( 6,2,2,3 ) }

    APIN_init {-1.0,,'X',, UNIT_AUTO_UNIT  }  ;// input
    APIN_init { 0.3,OFFSET sz_Sample,'s',, PIN_LOGIC_INPUT OR UNIT_LOGIC } ;// trigger
    APIN_init { 0.0,,'=',, PIN_OUTPUT OR UNIT_AUTO_UNIT }  ;// output
    APIN_init {-0.5,,'=',, PIN_OUTPUT OR PIN_HIDDEN }  ;// temp data for frame mode

    short_name  db  'Sample & Hold',0
    description db  'Uses a trigger input to freeze the data stream. May also be used as a gate that passes all signals and holds the last one.',0
    ALIGN 4


    ;// values stored in dwUser

    SH_POS       equ  00000001h
    SH_NEG       equ  00000002h
    SH_TEST     equ SH_POS OR SH_NEG
    SH_ZEROSTART equ  00000004h ;// this is negative logic
                                ;// if set true, we want to preserve the setting
    SH_GATE      equ  00000008h ;// use gate instead of edge

    sh_id_table LABEL DWORD

    dd ID_SH_BOTH_EDGE
    dd ID_SH_POS_EDGE
    dd ID_SH_NEG_EDGE
    dd 0,0
    dd ID_SH_POS_GATE
    dd ID_SH_NEG_GATE

    SH_FRAME     equ  00000010h ;// add new samples to the end of the frame

    ;// bugs discovered in ABox228 broke many circuits
    ;// we use this flag to state that we use the FIXED version

    SH_NOT_BACK_COMPAT_228  EQU 80000000h   ;// must be top bit

    ;// last trigger input stored in pin_s.dwUser
    ;// last output value, stored in pin_x.dwUser


    ;// display strings for the two modes
    ;// both get turned into font shape pointers

    sh_label LABEL DWORD

        p_sample_old    dd  'hs.'
        p_frame_old     dd  'hf.'
        p_sample_new    dd  'hs'
        p_frame_new     dd  'hf'

        p_dest_offset dd 0  ;// offset to center of object

        SH_WIDTH    EQU 16
        SH_HEIGHT   EQU 22

    ;// osc map for this object

    OSC_MAP STRUCT

        OSC_OBJECT      {}
        pin_x   APIN    {}
        pin_s   APIN    {}
        pin_y   APIN    {}
        pin_z   APIN    {}
        data_y  dd SAMARY_LENGTH dup (0)
        data_z  dd SAMARY_LENGTH dup (0)    ;// hidden data for frame and hold

    OSC_MAP ENDS



.CODE

;////////////////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
sh_GetUnit PROC

        ASSUME esi:PTR OSC_MAP  ;// must preserve
        ASSUME ebx:PTR APIN     ;// must preserve

        ;// must preserve edi and ebp

    ;// determine the pin we want to grab the unit from

        lea ecx, [esi].pin_x
        .IF ecx == ebx
            lea ecx, [esi].pin_y
        .ENDIF
        ASSUME ecx:PTR APIN

        mov eax, [ecx].dwStatus
        BITT eax, UNIT_AUTOED
        ret


sh_GetUnit ENDP


;////////////////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
sh_SyncPins PROC

;// set the logic shape for the s pin

    ASSUME esi:PTR OSC_MAP

    mov eax, [esi].dwUser
    mov edx, [esi].pin_s.dwStatus

    mov ecx, eax
    and edx, PIN_LEVEL_TEST
    and eax, SH_POS OR SH_NEG

    bt ecx, LOG2(SH_GATE)
    .IF CARRY?
        or eax, 4
    .ENDIF

    shl eax, LOG2(PIN_LEVEL_POS)

    .IF eax != edx

        lea ebx, [esi].pin_s
        or eax, PIN_LOGIC_INPUT
        invoke pin_SetInputShape

    .ENDIF

    ret

sh_SyncPins ENDP


;////////////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
sh_Ctor PROC

        ;// register call
        ASSUME ebp:PTR LIST_CONTEXT ;// preserve
        ASSUME esi:PTR OSC_OBJECT   ;// preserve
        ASSUME edi:PTR OSC_BASE     ;// may destroy
        ASSUME ebx:PTR FILE_OSC     ;// may destroy
        ASSUME edx:PTR FILE_HEADER  ;// may destroy

    ;// condition dwUser for various development paths
    ;// see also SH_NOT_BACK_COMPAT_228

        .IF [esi].dwUser & 00FFFFFE0h   ;// previous versions screwed this up
            and [esi].dwUser, 07h       ;// due to storing the value
        .ENDIF
        .IF !edx
            or [esi].dwUser, SH_NOT_BACK_COMPAT_228 OR SH_ZEROSTART
        .ENDIF

        invoke sh_SyncPins

        ret

sh_Ctor ENDP

;////////////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
sh_Render PROC

    ASSUME esi:PTR OSC_MAP

    .IF p_sample_new == 'hs'

        push edi

        mov eax, p_sample_new
        lea edi, font_bus_slist_head
        invoke font_Locate
        mov p_sample_new, edi

        mov eax, p_frame_new
        lea edi, font_bus_slist_head
        invoke font_Locate
        mov p_frame_new, edi

        mov eax, p_sample_old
        lea edi, font_bus_slist_head
        invoke font_Locate
        mov p_sample_old, edi

        mov eax, p_frame_old
        lea edi, font_bus_slist_head
        invoke font_Locate
        mov p_frame_old, edi

        mov eax, gdi_bitmap_size.x
        mov edx, SH_HEIGHT /2
        mul edx
        add eax, SH_WIDTH / 2
        mov p_dest_offset, eax

        pop edi

    .ENDIF

    invoke gdi_render_osc

    mov eax, [esi].dwUser

    xor ebx, ebx

    shl eax, 1                  ;// SH_NOT_BACK_COMPAT_228
    adc ebx, ebx

    mov edi, [esi].pDest

    shr eax, LOG2(SH_FRAME)+2   ;// SH_FRAME
    adc ebx, ebx

    add edi, p_dest_offset

    mov ebx, sh_label[ebx*4]

    mov eax, F_COLOR_GROUP_ROUTERS + 01010101h  ;// + F_COLOR_GROUP_LAST

    mov ebx, (GDI_SHAPE PTR [ebx]).pMask

    invoke shape_Fill

    ret

sh_Render ENDP




;////////////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
sh_PrePlay PROC

    ASSUME esi:PTR OSC_MAP

    xor eax, eax
    .IF [esi].dwUser & SH_ZEROSTART
        lea edi, [esi].data_y
        mov ecx, SAMARY_LENGTH * 2
        rep stosd
        mov [esi].pin_x.dwUser, eax
    .ENDIF
    mov [esi].pin_s.dwUser, eax

    inc eax ;// return non zero so play doesn't do this twice

    ret

sh_PrePlay ENDP

;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////

comment ~ /*

    version 207: new calc

    states:

    e = edge    p = positive    d = dynamic
    g = gate    m = minus       s = static
                b = both

    T = trigger     SH = sample and hold
    I = input       FH = frame shift and hold


    / gmT          \ 4  SH has 20 valid states
    | gpT          | 3  FH has 12 valid states
    | emT          | 2
    | epT dT dI SH | 1
    \ ebT sT sI FH / 0

col    0  5  10 20

*/ comment ~

.DATA

    sh_jump_table LABEL DWORD

    ;// SH modes

    dd  ebT_sT_sI_SH, epT_sT_sI_SH, emT_sT_sI_SH, gpT_sT_sI_SH, gmT_sT_sI_SH
    dd  ebT_dT_sI_SH, epT_dT_sI_SH, emT_dT_sI_SH, gpT_dT_sI_SH, gmT_dT_sI_SH
    dd  ebT_sT_dI_SH, epT_sT_dI_SH, emT_sT_dI_SH, gpT_sT_dI_SH, gmT_sT_dI_SH
    dd  ebT_dT_dI_SH, epT_dT_dI_SH, emT_dT_dI_SH, gpT_dT_dI_SH, gmT_dT_dI_SH

    ;// FH modes

    dd  ebT_sT_sI_FH, epT_sT_sI_FH, emT_sT_sI_FH, gpT_sT_sI_FH, gmT_sT_sI_FH
    dd  ebT_dT_sI_FH, epT_dT_sI_FH, emT_dT_sI_FH, gpT_dT_sI_FH, gmT_dT_sI_FH
    dd  ebT_sT_dI_FH, epT_sT_dI_FH, emT_sT_dI_FH, gpT_sT_dI_FH, gmT_sT_dI_FH
    dd  ebT_dT_dI_FH, epT_dT_dI_FH, emT_dT_dI_FH, gpT_dT_dI_FH, gmT_dT_dI_FH

.CODE

ASSUME_AND_ALIGN
sh_Calc PROC uses ebp

        ASSUME esi:PTR OSC_MAP

        mov edx, [esi].dwUser       ;// edx will track dwUser
        mov ebp, esi                ;// ebp will refernce the osc
        xor ecx, ecx                ;// ecx will be the jump pointer

        ASSUME ebp:PTR OSC_MAP

    ;// SAMPLE OR FRAME

        bt edx, LOG2(SH_FRAME)      ;// test the frame bit
        .IF CARRY?                  ;// copy old data to correct position
            add ecx, 20             ;// update the jump index
        .ELSE
            lea eax, [ebp].data_y       ;// get the y data pointer
            mov [ebp].pin_y.pData, eax  ;// reset the data pointer
        .ENDIF
        mov edi, [ebp].pin_y.pData  ;// load the output pointer
        ASSUME edi:PTR DWORD

    ;// INPUT PIN

        xor esi, esi    ;// input pointer
        xor ebx, ebx    ;// trigger pointer

        OR_GET_PIN [ebp].pin_x.pPin, esi
        .IF ZERO?
            mov esi, math_pNull
        .ELSE
            test [esi].dwStatus, PIN_CHANGING
            mov esi, [esi].pData
            .IF !ZERO?
                add ecx, 10
            .ENDIF
        .ENDIF
        ASSUME esi:PTR DWORD

    ;// TRIGGER PIN

        OR_GET_PIN [ebp].pin_s.pPin, ebx
        .IF ZERO?
            mov ebx, math_pNull
        .ELSE
            test [ebx].dwStatus, PIN_CHANGING
            mov ebx, [ebx].pData
            .IF !ZERO?
                add ecx, 5
            .ENDIF
        .ENDIF
        ASSUME ebx:PTR DWORD

    ;// TRIGGER TYPE

        IF (SH_POS OR SH_NEG) NE 3
        .ERR <supposed to equal 3>
        ENDIF

        xor eax, eax            ;// clear for accumulating
        bt edx, LOG2(SH_GATE)   ;// put the gate bit in the carry flag
        rcl eax, 2              ;// move carry so as to add two
        and edx, 3              ;// mask out all but the edge type

        add ecx, edx    ;// merge in the edge type
        add ecx, eax    ;// merge in the edge/gate

    ;// load the previous values

        mov edx, [ebp].pin_s.dwUser ;// get the last trigger value
        mov eax, [ebp].pin_x.dwUser ;// get the last sample we stored

    ;// JUMP AWAY

        DEBUG_IF < ecx !> 39 >  ;// jump came out too big

        jmp sh_jump_table[ecx*4]



    ;// state:
    ;//
    ;//     ebp = osc
    ;//     esi = input data
    ;//     ebx = trigger data
    ;//     edi = output data
    ;//     edx = last trigger value
    ;//     eax = last sample value

    ALIGN 16
    ebT_sT_sI_SH::
    ebT_sT_dI_SH::

        ;// check for trigger accros frame
        ;// then check store static

        xor edx, [ebx]              ;// test previous trigger with first trigger
        jns store_static            ;// if no sign, then no trigger
        lodsd                       ;// got a trigger, load the value to store
        jmp store_static            ;// jump to static storer

    ALIGN 16
    epT_sT_sI_SH::
    epT_sT_dI_SH::

        ;// check for trigger accros frame
        ;// then check store static

        or edx, edx                 ;// was pos ?
        jns store_static            ;// if was pos, then we can't get a trigger
        ;// was neg
        and edx, [ebx]              ;// test with new trigger
        js store_static             ;// if neg, then ignore
        ;// got pos
        lodsd                       ;// get the value to store
        jmp store_static

    ALIGN 16
    emT_sT_sI_SH::
    emT_sT_dI_SH::

        ;// check for trigger accros frame
        ;// then check store static

        or edx, edx                 ;// was neg ?
        js store_static             ;// if was neg, then we can't get a trigger
        ;// was pos
        or edx, [ebx]               ;// test with new trigger
        jns store_static            ;// if pos, then ignore
        ;// now neg
        lodsd                       ;// get the value to store
        jmp store_static

    ALIGN 16
    gpT_sT_sI_SH::

        ;// if on now, xfer pointer and reset changing
        ;// otherwise store static

        mov edx, [ebx]              ;// get the trigger
        or edx, edx                 ;// see if gate positive
        js store_static             ;// jump if gate is negative

        mov [ebp].pin_y.pData, esi  ;// transfer the data pointer
        and [ebp].pin_y.dwStatus, NOT PIN_CHANGING
        jmp all_done

    ALIGN 16
    gmT_sT_sI_SH::

        ;// if on now, xfer pointer and split
        mov edx, [ebx]              ;// get the trigger
        or edx, edx                 ;// see if gate is negative
        jns store_static            ;// jump if gate is positive

        mov [ebp].pin_y.pData, esi  ;// transfer the data pointer
        and [ebp].pin_y.dwStatus, NOT PIN_CHANGING
        jmp all_done

    ALIGN 16
    ebT_dT_sI_SH::

        ;// default to not changing
        ;// zip forwards to the first trigger
        ;// fill with last value along the way
        ;// then store the grabbed value for the remainder of the frame

        cmp eax, [esi]      ;// old last sample same as new ?
        je store_static     ;// so there no reason to do anything but fill static

        xor ecx, ecx        ;// ecx will count
        and [ebp].pin_y.dwStatus, NOT PIN_CHANGING

        top_of_ebT_dT_sI_SH:        ;// two at a time

            xor edx, [ebx+ecx*4]    ;// test the trigger
            mov edx, [ebx+ecx*4]    ;// load the trigger
            js fill_the_rest        ;// jump if we got a trigger

            inc ecx
            stosd

            xor edx, [ebx+ecx*4]    ;// test the trigger
            mov edx, [ebx+ecx*4]    ;// load the trigger
            js fill_the_rest        ;// jump if we got a trigger

            inc ecx
            stosd

            cmp ecx, SAMARY_LENGTH  ;// done yet ??
            jb top_of_ebT_dT_sI_SH  ;// loop if not

            jmp all_done            ;// now we're done

    ALIGN 16
    epT_dT_sI_SH::

        cmp eax, [esi]      ;// old last sample same as new ?
        je store_static     ;// so there no reason to do anything but fill static

        xor ecx, ecx        ;// ecx will count
        and [ebp].pin_y.dwStatus, NOT PIN_CHANGING

        test [ebp].dwUser, SH_NOT_BACK_COMPAT_228
        jz back_compat_epT_dT_sI_SH

        test edx, edx       ;// pos now ?
        js epT_dT_sI_SH_is_neg

        .REPEAT ;//     epT_dT_sI_SH_look_for_neg:      ;// the last trigger was positive

            or edx, [ebx+ecx*4]         ;// is this trigger negative ?
            js epT_dT_sI_SH_got_neg     ;// jump if so
            inc ecx
            stosd

            or edx, [ebx+ecx*4]
            js epT_dT_sI_SH_got_neg

            inc ecx
            stosd

        .UNTIL ecx >= SAMARY_LENGTH

        ;// cmp ecx, SAMARY_LENGTH
        ;// jb epT_dT_sI_SH_look_for_neg
            jmp all_done

        .REPEAT
        epT_dT_sI_SH_is_neg:            ;// last trigger is neg, look for pos edge

            and edx, [ebx+ecx*4]
            jns fill_the_rest           ;// jump if we got a trigger

        epT_dT_sI_SH_got_neg:   ;// we just got a neg value

            inc ecx
            stosd

            cmp ecx, SAMARY_LENGTH
            jae all_done

            and edx, [ebx+ecx*4]
            jns fill_the_rest   ;// jump if we got a trigger

            inc ecx
            stosd

        .UNTIL ecx >= SAMARY_LENGTH
        ;// cmp ecx, SAMARY_LENGTH
        ;// jb epT_dT_sI_SH_is_neg

            jmp all_done



;//     pre abox 228 version
;//     there are a couple bugs in this

ALIGN 16
back_compat_epT_dT_sI_SH::

        or edx, edx     ;// pos now ?
        js back_compat_epT_dT_sI_SH_got_neg

        back_compat_epT_dT_sI_SH_look_for_neg:      ;// the last trigger was positive

            or edx, [ebx+ecx*4]         ;// is this trigger negative ?
            js back_compat_epT_dT_sI_SH_got_neg     ;// jump if so
            inc ecx
            stosd

            or edx, [ebx+ecx*4]
            js back_compat_epT_dT_sI_SH_got_neg

            inc ecx
            stosd

            cmp ecx, SAMARY_LENGTH
            jb back_compat_epT_dT_sI_SH_look_for_neg
            jmp all_done

        back_compat_epT_dT_sI_SH_is_neg:            ;// last trigger is neg, look for pos edge

            and edx, [ebx+ecx*4]
            jns fill_the_rest           ;// jump if we got a trigger

        back_compat_epT_dT_sI_SH_got_neg:   ;// we just got a neg value

            inc ecx
            stosd
            cmp ecx, SAMARY_LENGTH
            jae all_done

            or edx, [ebx+ecx*4]
            jns fill_the_rest   ;// jump if we got a trigger
            inc ecx
            stosd
            cmp ecx, SAMARY_LENGTH

            jb back_compat_epT_dT_sI_SH_is_neg
            jmp all_done





    ALIGN 16
    emT_dT_sI_SH::

        cmp eax, [esi]      ;// old last sample same as new ?
        je store_static     ;// so there no reason to do anything but fill static

        xor ecx, ecx        ;// ecx will count
        and [ebp].pin_y.dwStatus, NOT PIN_CHANGING  ;// default to no

        test [ebp].dwUser, SH_NOT_BACK_COMPAT_228
        jz back_compat_emT_dT_sI_SH

        test edx, edx               ;// pos now ?
        jns emT_dT_sI_SH_is_pos     ;// jmp if pos now, meaning we MAY get a trigger

        ;// we are neg now, meaning we MAY go to pos
        .REPEAT ;// we are neg now, look for pos transition

            and edx, [ebx+ecx*4]
            jns emT_dT_sI_SH_got_pos

            inc ecx
            stosd

            and edx, [ebx+ecx*4]
            jns emT_dT_sI_SH_got_pos

            inc ecx
            stosd

        .UNTIL ecx >= SAMARY_LENGTH

        jmp all_done

        .REPEAT ;// now look for neg
        emT_dT_sI_SH_is_pos:

            or edx, [ebx+ecx*4]
            js fill_the_rest    ;// jump if we got a trigger

        emT_dT_sI_SH_got_pos:   ;// now look for neg

            inc ecx
            stosd

            cmp ecx, SAMARY_LENGTH
            jae all_done

            or edx, [ebx+ecx*4]
            js fill_the_rest    ;// jump if we got a trigger

            inc ecx
            stosd

        .UNTIL ecx >= SAMARY_LENGTH

        jmp all_done





;// pre abox 228
;// this has several bugs

ALIGN 16
back_compat_emT_dT_sI_SH::

        or edx, edx     ;// neg now ?
        js back_compat_emT_dT_sI_SH_got_pos         ;// bug: should be JNS IS POS

        back_compat_emT_dT_sI_SH_look_for_pos:

            and edx, [ebx+ecx*4]
            jns back_compat_emT_dT_sI_SH_got_pos

            inc ecx
            stosd

            and edx, [ebx+ecx*4]
            jns back_compat_emT_dT_sI_SH_got_pos

            inc ecx
            stosd

            cmp ecx, SAMARY_LENGTH
            jb back_compat_emT_dT_sI_SH_got_pos ;// BUG should be look_for_pos
            jmp all_done

        back_compat_emT_dT_sI_SH_is_pos:    ;// now look for neg

            or edx, [ebx+ecx*4]
            js fill_the_rest    ;// jump if we got a trigger

        back_compat_emT_dT_sI_SH_got_pos:   ;// now look for neg

            inc ecx
            stosd

            cmp ecx, SAMARY_LENGTH
            jae all_done

            or edx, [ebx+ecx*4]
            js fill_the_rest    ;// jump if we got a trigger

            inc ecx
            stosd

            cmp ecx, SAMARY_LENGTH
            jb back_compat_emT_dT_sI_SH_got_pos ;// bug: should be IS POS
            jmp all_done



    ALIGN 16
    fill_the_rest:

        ;// esi must point at start of input data
        ;// edi must point at where to store
        ;// ecx must index the sample to get
        ;// sets pin changing

        .IF ecx ;// check for full frame fill
            or [ebp].pin_y.dwStatus, PIN_CHANGING
        .ELSE
            and [ebp].pin_y.dwStatus, NOT PIN_CHANGING
        .ENDIF
        mov eax, [esi+ecx*4]    ;// get the new value
        sub ecx, SAMARY_LENGTH
        ;// or [ebp].pin_y.dwStatus, PIN_CHANGING
        neg ecx
        DEBUG_IF <ZERO?>

        rep stosd
        jmp all_done


    ALIGN 16
    gpT_dT_sI_SH::

        ;// fill with old value until we get the first gate value

        cmp eax, [esi]      ;// old last sample same as new ?
        je store_static     ;// so there no reason to do anything but fill static

        xor ecx, ecx        ;// ecx will count
        and [ebp].pin_y.dwStatus, NOT PIN_CHANGING

        gpT_dT_sI_SH_is_neg:

            and edx, [ebx+ecx*4]
            jns gpT_dT_sI_SH_got_pos

            inc ecx
            stosd
            cmp ecx, SAMARY_LENGTH
            jae all_done

            and edx, [ebx+ecx*4]
            jns gpT_dT_sI_SH_got_pos

            inc ecx
            stosd
            cmp ecx, SAMARY_LENGTH
            jb gpT_dT_sI_SH_is_neg

            jmp all_done

        gpT_dT_sI_SH_got_pos:

            mov eax, [esi+ecx*4]
            jmp fill_the_rest


    ALIGN 16
    gmT_dT_sI_SH::

        cmp eax, [esi]      ;// old last sample same as new ?
        je store_static     ;// so there no reason to do anything but fill static

        xor ecx, ecx        ;// ecx will count
        and [ebp].pin_y.dwStatus, NOT PIN_CHANGING

        gpT_dT_sI_SH_is_pos:

            or edx, [ebx+ecx*4]
            js gpT_dT_sI_SH_got_neg

            inc ecx
            stosd
            cmp ecx, SAMARY_LENGTH
            jae all_done

            or edx, [ebx+ecx*4]
            js gpT_dT_sI_SH_got_neg

            inc ecx
            stosd
            cmp ecx, SAMARY_LENGTH
            jb gpT_dT_sI_SH_is_pos

            jmp all_done

        gpT_dT_sI_SH_got_neg:

            mov eax, [esi+ecx*4]
            jmp fill_the_rest


    ALIGN 16
    gpT_sT_dI_SH::

        ;// if on now, xfer pointer and reset changing
        ;// otherwise store static

        mov edx, [ebx]              ;// get the trigger
        or edx, edx                 ;// see if gate positive
        js store_static             ;// jump if gate is negative

        mov [ebp].pin_y.pData, esi  ;// transfer the data pointer
        or [ebp].pin_y.dwStatus, PIN_CHANGING
        jmp all_done



    ALIGN 16
    gmT_sT_dI_SH::

        ;// if on now, xfer pointer and split
        mov edx, [ebx]              ;// get the trigger
        or edx, edx                 ;// see if gate is negative
        jns store_static            ;// jump if gate is positive

        mov [ebp].pin_y.pData, esi  ;// transfer the data pointer
        or [ebp].pin_y.dwStatus, PIN_CHANGING
        jmp all_done



    ALIGN 16
    ebT_dT_dI_SH::

        xor ecx, ecx
        and [ebp].pin_y.dwStatus, NOT PIN_CHANGING

        ebT_dT_dI_SH_top:

            xor edx, [ebx+ecx*4]
            mov edx, [ebx+ecx*4]
            js ebT_dT_dI_SH_got_trigger

        ebT_dT_dI_SH_enter:

            inc ecx
            stosd
            cmp ecx, SAMARY_LENGTH
            jae all_done

            xor edx, [ebx+ecx*4]
            mov edx, [ebx+ecx*4]
            js ebT_dT_dI_SH_got_trigger

            inc ecx
            stosd
            cmp ecx, SAMARY_LENGTH
            jb ebT_dT_dI_SH_top

            jmp all_done

        ebT_dT_dI_SH_got_trigger:

            mov eax, [esi+ecx*4]
            or [ebp].pin_y.dwStatus, PIN_CHANGING
            jmp ebT_dT_dI_SH_enter


    ALIGN 16
    epT_dT_dI_SH::

        xor ecx, ecx
        and [ebp].pin_y.dwStatus, NOT PIN_CHANGING

        or edx, edx
        jns epT_dT_dI_SH_is_pos

        epT_dT_dI_SH_got_neg:
        epT_dT_dI_SH_is_neg:

            and edx, [ebx+ecx*4]
            jns epT_dT_dI_SH_got_pos

            inc ecx
            stosd
            cmp ecx, SAMARY_LENGTH
            jae all_done

            and edx, [ebx+ecx*4]
            jns epT_dT_dI_SH_got_pos

            inc ecx
            stosd
            cmp ecx, SAMARY_LENGTH
            jb epT_dT_dI_SH_is_neg

            jmp all_done

        epT_dT_dI_SH_got_pos:

            mov eax, [esi+ecx*4]
            inc ecx
            stosd
            or [ebp].pin_y.dwStatus, PIN_CHANGING
            cmp ecx, SAMARY_LENGTH
            jae all_done

        epT_dT_dI_SH_is_pos:

            or edx, [ebx+ecx*4]
            js epT_dT_dI_SH_got_neg

            inc ecx
            stosd
            cmp ecx, SAMARY_LENGTH
            jae all_done

            or edx, [ebx+ecx*4]
            js epT_dT_dI_SH_got_neg

            inc ecx
            stosd
            cmp ecx, SAMARY_LENGTH
            jb epT_dT_dI_SH_is_pos

            jmp all_done

    ALIGN 16
    emT_dT_dI_SH::


        xor ecx, ecx
        and [ebp].pin_y.dwStatus, NOT PIN_CHANGING

        or edx, edx
        js emT_dT_dI_SH_is_neg

        emT_dT_dI_SH_got_pos:
        emT_dT_dI_SH_is_pos:

            or edx, [ebx+ecx*4]
            js emT_dT_dI_SH_got_neg

            inc ecx
            stosd
            cmp ecx, SAMARY_LENGTH
            jae all_done

            or edx, [ebx+ecx*4]
            js emT_dT_dI_SH_got_neg

            inc ecx
            stosd
            cmp ecx, SAMARY_LENGTH
            jb emT_dT_dI_SH_is_pos

            jmp all_done

        emT_dT_dI_SH_got_neg:

            mov eax, [esi+ecx*4]
            inc ecx
            stosd
            or [ebp].pin_y.dwStatus, PIN_CHANGING
            cmp ecx, SAMARY_LENGTH
            jae all_done

        emT_dT_dI_SH_is_neg:

            and edx, [ebx+ecx*4]
            jns emT_dT_dI_SH_got_pos

            inc ecx
            stosd
            cmp ecx, SAMARY_LENGTH
            jae all_done

            and edx, [ebx+ecx*4]
            jns emT_dT_dI_SH_got_pos

            inc ecx
            stosd
            cmp ecx, SAMARY_LENGTH
            jb emT_dT_dI_SH_is_neg

            jmp all_done


    ALIGN 16
    gpT_dT_dI_SH::

        xor ecx, ecx
        and [ebp].pin_y.dwStatus, NOT PIN_CHANGING

        or edx, edx
        jns gpT_dT_dI_SH_is_pos

        gpT_dT_dI_SH_is_neg:

            and edx, [ebx+ecx*4]
            jns gpT_dT_dI_SH_got_pos

            inc ecx
            stosd
            cmp ecx, SAMARY_LENGTH
            jae all_done

            and edx, [ebx+ecx*4]
            jns gpT_dT_dI_SH_got_pos

            inc ecx
            stosd
            cmp ecx, SAMARY_LENGTH
            jb gpT_dT_dI_SH_is_neg
            jmp all_done


        gpT_dT_dI_SH_is_pos:

            or edx, [ebx+ecx*4]
            js gpT_dT_dI_SH_is_neg

        gpT_dT_dI_SH_got_pos:

            mov eax, [esi+ecx*4]
            inc ecx
            or [ebp].pin_y.dwStatus, PIN_CHANGING
            stosd
            cmp ecx, SAMARY_LENGTH
            jae all_done

            or edx, [ebx+ecx*4]
            js gpT_dT_dI_SH_is_neg

            mov eax, [esi+ecx*4]
            inc ecx
            stosd
            cmp ecx, SAMARY_LENGTH
            jb gpT_dT_dI_SH_is_pos

            jmp all_done




    ALIGN 16
    gmT_dT_dI_SH::

        xor ecx, ecx
        and [ebp].pin_y.dwStatus, NOT PIN_CHANGING

        or edx, edx
        js gmT_dT_dI_SH_is_neg

        gmT_dT_dI_SH_is_pos:

            or edx, [ebx+ecx*4]
            js gmT_dT_dI_SH_got_neg

            inc ecx
            stosd
            cmp ecx, SAMARY_LENGTH
            jae all_done

            or edx, [ebx+ecx*4]
            js gmT_dT_dI_SH_got_neg

            inc ecx
            stosd
            cmp ecx, SAMARY_LENGTH
            jb gmT_dT_dI_SH_is_pos

            jmp all_done


        gmT_dT_dI_SH_is_neg:

            and edx, [ebx+ecx*4]
            jns gmT_dT_dI_SH_is_pos

        gmT_dT_dI_SH_got_neg:

            mov eax, [esi+ecx*4]
            inc ecx
            or [ebp].pin_y.dwStatus, PIN_CHANGING
            stosd
            cmp ecx, SAMARY_LENGTH
            jae all_done

            and edx, [ebx+ecx*4]
            jns gmT_dT_dI_SH_is_pos

            mov eax, [esi+ecx*4]
            inc ecx
            stosd
            cmp ecx, SAMARY_LENGTH
            jb gmT_dT_dI_SH_is_neg

            jmp all_done



    comment ~ /*

    FRAME

        keeping track of changing will be tricky
        the criteria are:

        WAS the signal changing last frame ?
        did we ADD NEW samples ?
        is the new sample the SAME as the previous sample ?

        WAS ADD SAME | CHANGE
        chg NEW prev |  NOW
        ----------------------
         0   0   x   |   0
         0   0   x   |   0
         0   1   1   |   0
         0   1   0   |   1
         1   0   x   |   1
         1   0   x   |   1
         1   1   1   |  test
         1   1   0   |   1

    */ comment ~

    ALIGN 16
    ebT_sT_sI_FH::
    ebT_sT_dI_FH::

        xor ecx, ecx
        add edi, SAMARY_LENGTH * 4  ;// edi needs to point at the end of the data

        xor edx, [ebx]  ;// check for sample accross frame
        jns all_done

        jmp FH_single_trigger

    ALIGN 16
    epT_sT_sI_FH::
    epT_sT_dI_FH::

        xor ecx, ecx
        add edi, SAMARY_LENGTH * 4  ;// edi needs to point at the end of the data

        or edx, edx     ;// check the previous trigger value
        jns all_done    ;// no way we can get a trigger
        ;// neg now
        and edx, [ebx]  ;// check for trigger accross frame
        js all_done     ;// no trigger

        jmp FH_single_trigger

    ALIGN 16
    emT_sT_sI_FH::
    emT_sT_dI_FH::

        xor ecx, ecx
        add edi, SAMARY_LENGTH * 4  ;// edi needs to point at the end of the data

        or edx, edx     ;// check the previous trigger value
        js all_done     ;// no way we can get a trigger
        ;// pos now
        or edx, [ebx]   ;// check for trigger accross frame
        jns all_done    ;// no trigger
        jmp FH_single_trigger



    ALIGN 16
    ebT_dT_sI_FH::

        ;// if we get enough sI's we will eventually stop changing

        ;// do a quick check to see if we need to  do anything

            mov ecx, [ebp].pin_y.dwStatus   ;// get previous change status
            test ecx, PIN_CHANGING          ;// see if it was canging
            jnz ebT_dT_sI_FH_scan           ;// jump if so

            cmp eax, [esi]  ;// is last value same as source value ?
            je all_done     ;// nothing to do !!

        ebT_dT_sI_FH_scan:

            push ecx                    ;// store the prev changing
            xor ecx, ecx                ;// reset for counting
            add edi, SAMARY_LENGTH * 4  ;// edi needs to point at the end of the data
            push ecx                    ;// store an accumulator

        ebT_dT_sI_FH_top:

            xor edx, [ebx+ecx*4]    ;// test the next trigger value
            mov edx, [ebx+ecx*4]    ;// load the next trigger value
            .IF SIGN?               ;// trigger ?
                call FH_append      ;// append the value
                or [esp], eax       ;// merge into test value
            .ENDIF

            inc ecx                 ;// advance the input counter
                                    ;// no need to test if done
            xor edx, [ebx+ecx*4]    ;// test the next trigger value
            mov edx, [ebx+ecx*4]    ;// load the next trigger value
            .IF SIGN?               ;// trigger ?
                call FH_append      ;// append the value
                or [esp], eax       ;// merge into test value
            .ENDIF

            inc ecx                 ;// advance the input counter
            cmp ecx, SAMARY_LENGTH  ;// done yet ?
            jb ebT_dT_sI_FH_top     ;// loop if not done yet

            jmp FH_dT_sI_cleanup


    ALIGN 16
    epT_dT_sI_FH::

        ;// do a quick check to see if we need to  do anything

            mov ecx, [ebp].pin_y.dwStatus   ;// get previous change status
            test ecx, PIN_CHANGING          ;// see if it was canging
            jnz epT_dT_sI_FH_scan           ;// jump if so
            ;// we were not changing
            cmp eax, [esi]  ;// is last value same as source value ?
            je all_done     ;// nothing to do !!

        epT_dT_sI_FH_scan:

            push ecx                    ;// store the prev changing
            xor ecx, ecx                ;// reset for counting
            add edi, SAMARY_LENGTH * 4  ;// edi needs to point at the end of the data
            push ecx                    ;// store an accumulator

            or edx, edx
            jns epT_dT_sI_FH_is_pos

        epT_dT_sI_FH_is_neg:

            and edx, [ebx+ecx*4]
            jns epT_dT_sI_FH_got_pos

        epT_dT_sI_FH_got_neg:

            inc ecx
            cmp ecx, SAMARY_LENGTH
            jae FH_dT_sI_cleanup

            and edx, [ebx+ecx*4]
            jns epT_dT_sI_FH_got_pos

            inc ecx
            cmp ecx, SAMARY_LENGTH
            jb epT_dT_sI_FH_is_neg

            jmp FH_dT_sI_cleanup

        epT_dT_sI_FH_got_pos:

            call FH_append  ;// append the value
            or [esp], eax   ;// merge onto accumulater

        epT_dT_sI_FH_is_pos:

            or edx, [ebx+ecx*4]
            js epT_dT_sI_FH_got_neg

            inc ecx
            cmp ecx, SAMARY_LENGTH
            jae FH_dT_sI_cleanup

            or edx, [ebx+ecx*4]
            js epT_dT_sI_FH_got_neg

            inc ecx
            cmp ecx, SAMARY_LENGTH
            jb epT_dT_sI_FH_is_pos

            jmp FH_dT_sI_cleanup


    ALIGN 16
    emT_dT_sI_FH::

        ;// do a quick check to see if we need to  do anything

            mov ecx, [ebp].pin_y.dwStatus   ;// get previous change status
            test ecx, PIN_CHANGING          ;// see if it was canging
            jnz emT_dT_sI_FH_scan           ;// jump if so
            ;// we were not changing
            cmp eax, [esi]  ;// is last value same as source value ?
            je all_done     ;// nothing to do !!

        emT_dT_sI_FH_scan:

            push ecx                    ;// store the prev changing
            xor ecx, ecx                ;// reset for counting
            add edi, SAMARY_LENGTH * 4  ;// edi needs to point at the end of the data
            push ecx                    ;// store an accumulator

            or edx, edx
            js emT_dT_sI_FH_is_neg

        emT_dT_sI_FH_is_pos:

            or edx, [ebx+ecx*4]
            js emT_dT_sI_FH_got_neg

        emT_dT_sI_FH_got_pos:

            inc ecx
            cmp ecx, SAMARY_LENGTH
            jae FH_dT_sI_cleanup

            or edx, [ebx+ecx*4]
            js emT_dT_sI_FH_got_neg

            inc ecx
            cmp ecx, SAMARY_LENGTH
            jb emT_dT_sI_FH_is_pos

            jmp FH_dT_sI_cleanup

        emT_dT_sI_FH_got_neg:

            call FH_append  ;// append the value
            or [esp], eax   ;// merge onto accumulater

        emT_dT_sI_FH_is_neg:

            and edx, [ebx+ecx*4]
            jns emT_dT_sI_FH_got_pos

            inc ecx
            cmp ecx, SAMARY_LENGTH
            jae FH_dT_sI_cleanup

            and edx, [ebx+ecx*4]
            jns emT_dT_sI_FH_got_pos

            inc ecx
            cmp ecx, SAMARY_LENGTH
            jb emT_dT_sI_FH_is_neg

            jmp FH_dT_sI_cleanup





    ALIGN 16
    ebT_dT_dI_FH::

        xor ecx, ecx
        add edi, SAMARY_LENGTH * 4  ;// edi needs to point at the end of the data

        ebT_dT_dI_FH_top:

            xor edx, [ebx+ecx*4]    ;// test the next trigger value
            mov edx, [ebx+ecx*4]    ;// load the next trigger value
            .IF SIGN?               ;// trigger ?
                call FH_append
            .ENDIF

            inc ecx                 ;// advance the input counter
                                    ;// no need to test if done
            xor edx, [ebx+ecx*4]    ;// test the next trigger value
            mov edx, [ebx+ecx*4]    ;// load the next trigger value
            .IF SIGN?               ;// trigger ?
                call FH_append
            .ENDIF

            inc ecx                 ;// advance the input counter
            cmp ecx, SAMARY_LENGTH  ;// done yet ?
            jb ebT_dT_dI_FH_top     ;// loop if not done yet

            jmp all_done            ;// now were done




    ALIGN 16
    epT_dT_dI_FH::

        xor ecx, ecx
        add edi, SAMARY_LENGTH * 4  ;// edi needs to point at the end of the data

        or edx, edx
        jns epT_dT_dI_FH_is_pos

        epT_dT_dI_FH_is_neg:

            and edx, [ebx+ecx*4]
            jns epT_dT_dI_FH_got_pos

        epT_dT_dI_FH_got_neg:

            inc ecx
            cmp ecx, SAMARY_LENGTH
            jae all_done

            and edx, [ebx+ecx*4]
            jns epT_dT_dI_FH_got_pos

            inc ecx
            cmp ecx, SAMARY_LENGTH
            jb epT_dT_dI_FH_is_neg

            jmp all_done

        epT_dT_dI_FH_got_pos:

            call FH_append

        epT_dT_dI_FH_is_pos:

            or edx, [ebx+ecx*4]
            js epT_dT_dI_FH_got_neg

            inc ecx
            cmp ecx, SAMARY_LENGTH
            jae all_done

            or edx, [ebx+ecx*4]
            js epT_dT_dI_FH_got_neg

            inc ecx
            cmp ecx, SAMARY_LENGTH
            jb epT_dT_dI_FH_is_pos
            jmp all_done


    ALIGN 16
    emT_dT_dI_FH::

        xor ecx, ecx
        add edi, SAMARY_LENGTH * 4  ;// edi needs to point at the end of the data

        or edx, edx
        js emT_dT_dI_FH_is_neg

        emT_dT_dI_FH_is_pos:

            or edx, [ebx+ecx*4]
            js emT_dT_dI_FH_got_neg

        emT_dT_dI_FH_got_pos:

            inc ecx
            cmp ecx, SAMARY_LENGTH
            jae all_done

            or edx, [ebx+ecx*4]
            js emT_dT_dI_FH_got_neg

            inc ecx
            cmp ecx, SAMARY_LENGTH
            jb emT_dT_dI_FH_is_pos

            jmp all_done

        emT_dT_dI_FH_got_neg:

            call FH_append

        emT_dT_dI_FH_is_neg:

            and edx, [ebx+ecx*4]
            jns emT_dT_dI_FH_got_pos

            inc ecx
            cmp ecx, SAMARY_LENGTH
            jae all_done

            and edx, [ebx+ecx*4]
            jns emT_dT_dI_FH_got_pos

            inc ecx
            cmp ecx, SAMARY_LENGTH
            jb emT_dT_dI_FH_is_neg
            jmp all_done


    ALIGN 16
    FH_dT_sI_cleanup:

        pop eax         ;// get the accumulated value
        pop ecx         ;// get the previous change status

        or eax, eax             ;// see if accumulated results are zero
        jnz all_done            ;// we're done if not (FH_append set pin changing)
        ;// FH_append did not change any values
        test ecx, PIN_CHANGING  ;// see if we were changing ?
        jz all_done             ;// we're still not changing

        jmp FH_check_changing   ;// exit to the check cheanging test


    ALIGN 16
    FH_single_trigger:      ;// process a single trigger across sample frame

        mov edx, [ebp].pin_y.dwStatus   ;// get the previous changing state
        call FH_append          ;// append the new sample
        test edx, PIN_CHANGING  ;// were we changing before ?
        jz  all_done            ;// jump if not, FH append took care of setting it
        test eax, PIN_CHANGING  ;// did FH_append set changing ?
        jnz all_done            ;// jump if it did, we're done

    ALIGN 16
    FH_check_changing:      ;// check changing status

        and [ebp].pin_y.dwStatus, NOT PIN_CHANGING  ;// assume we're not changing
        mov edi, [ebp].pin_y.pData  ;// get the start of the test area
        mov eax, [edi]              ;// get the first sample
        mov ecx, SAMARY_LENGTH      ;// this long
        repe scasd                  ;// test it
        je all_done                 ;// if equal, we're done
        or [ebp].pin_y.dwStatus, PIN_CHANGING   ;// we are changing
        jmp all_done                ;// and we're done as well


    ALIGN 16
    FH_append:

        ;// add a new sample to the end of the frame
        ;// check for frame shift as well

        ;// must preserve all registers except eax and edi

        ;// returns whether or not we set pin changing

            mov eax, [esi+ecx*4]    ;// get the input sample
            add [ebp].pin_y.pData, 4;// advance the y data pointer
            stosd                   ;// store the new sample at the end of pin_y.data
            sub eax, [edi-8]        ;// check if this is a new value by comparing with previous
                                    ;// also sets the return value
            .IF !ZERO?      ;// ADD new, not SAME
                or [ebp].pin_y.dwStatus, PIN_CHANGING
            .ENDIF
            .IF edi >= [ebp].pData  ;// see if edi is now at the end of the frame

                ;// shift all the data back into place by moving data_z to data_y
                ;// reset the pin_y data pointer
                ;// return edi as data_z (for the next iteration)
                ;// preserve ecx and esi

                push esi
                push ecx

                lea edi, [ebp].data_y       ;// load the dest (data_y)
                lea esi, [ebp].data_z       ;// load the source (data_z)
                mov [ebp].pin_y.pData, edi  ;// reset the pin_y data pointer
                mov ecx, SAMARY_LENGTH      ;// this many
                rep movsd                   ;// move data_z to data_y

                pop ecx
                pop esi

            .ENDIF

            retn


    ALIGN 16
    store_static:

        ;// eax must have the value to store
        ;// edi must point at output data

            btr [ebp].pin_y.dwStatus, LOG2(PIN_CHANGING)    ;// reset and test
            jc have_to_fill ;// if was changing, we have to fill
            cmp eax, [edi]  ;// same value ?
            je all_done     ;// if yes, then nothing to do
        have_to_fill:
            mov ecx, SAMARY_LENGTH
            rep stosd

            jmp all_done


    ALIGN 16
    gpT_sT_sI_FH::
    gmT_sT_sI_FH::
    gpT_dT_sI_FH::
    gmT_dT_sI_FH::
    gpT_sT_dI_FH::
    gmT_sT_dI_FH::
    gpT_dT_dI_FH::
    gmT_dT_dI_FH::

        DEBUG_IF <1>    ;// not supposed to allow gate in FM mode


    ALIGN 16
    all_done:

        ;// retrieve the last trigger
        ;// retrieve the last output sample

            mov ebx, [ebp].pin_s.pPin   ;// get t pin
            xor eax, eax                ;// clear as default value
            or ebx, ebx                 ;// make sure there is a t pin
            mov edi, [ebp].pin_y.pData  ;// get the current output pointer
            .IF !ZERO?                          ;// was t connected ?
                mov ebx, (APIN PTR [ebx]).pData ;// get it's data pointer
                mov eax, [ebx+LAST_SAMPLE]      ;// get it's last sample
            .ENDIF
            mov edx, [edi+LAST_SAMPLE]  ;// load the last out sample
            mov [ebp].pin_s.dwUser, eax ;// store the last trigger sample
            mov [ebp].pin_x.dwUser, edx ;// store the last output sample

        ;// restore esi and split

            mov esi, ebp
            ret



sh_Calc ENDP






;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////



ASSUME_AND_ALIGN
sh_InitMenu PROC

    ASSUME esi:PTR OSC_OBJECT

    ;// do trigger

        mov eax, [esi].dwUser
        mov edx, eax

        and eax, SH_GATE
        and edx, SH_POS OR SH_NEG
        shr eax, 1
        or eax, edx
        mov ecx, sh_id_table[eax*4]

        invoke CheckDlgButton, popup_hWnd, ecx, BST_CHECKED

    ;// disable gate mode when in frame shift

        test [esi].dwUser , SH_FRAME
        mov ebx, 1
        .IF !ZERO?
            dec ebx
            CHECK_BUTTON popup_hWnd, ID_SH_POS_GATE, ebx    ;// BST_UNCHECKED
            CHECK_BUTTON popup_hWnd, ID_SH_NEG_GATE, ebx    ;// BST_UNCHECKED
        .ENDIF
        ENABLE_CONTROL popup_hWnd, ID_SH_POS_GATE, ebx
        ENABLE_CONTROL popup_hWnd, ID_SH_NEG_GATE, ebx

    ;// check for sample or frame

        test [esi].dwUser, SH_FRAME
        mov ecx, ID_SH_SAMPLE       ;// button to push
        .IF !ZERO?
            mov ecx, ID_SH_FRAME
        .ENDIF
        invoke CheckDlgButton, popup_hWnd, ecx, BST_CHECKED

    ;// lastly, do the zero start

        .IF ([esi].dwUser & SH_ZEROSTART)
            invoke CheckDlgButton, popup_hWnd, ID_SH_ZEROSTART, BST_CHECKED
        .ENDIF

    ;// that's it

        xor eax, eax    ;// return zero or else

        ret

sh_InitMenu ENDP


ASSUME_AND_ALIGN
sh_Command PROC STDCALL ;// uses esi edi pObject:ptr OSC_OBJECT, cmdID:DWORD

    ASSUME esi:PTR OSC_MAP
    ;// eax has the command id

    mov ecx, [esi].dwUser

    cmp eax, ID_SH_POS_EDGE
    jnz @F

        BITS ecx, SH_POS
        BITR ecx, SH_NEG
        BITR ecx, SH_GATE
        jmp set_new_trigger

@@: cmp eax, ID_SH_NEG_EDGE
    jnz @F

        BITR ecx, SH_POS
        BITS ecx, SH_NEG
        BITR ecx, SH_GATE
        jmp set_new_trigger

@@: cmp eax, ID_SH_BOTH_EDGE
    jnz @F

        BITR ecx, SH_POS
        BITR ecx, SH_NEG
        BITR ecx, SH_GATE
        jmp set_new_trigger

@@: cmp eax, ID_SH_POS_GATE
    jnz @F

        BITS ecx, SH_POS
        BITR ecx, SH_NEG
        BITS ecx, SH_GATE
        jmp set_new_trigger

@@: cmp eax, ID_SH_NEG_GATE
    jnz @F

        BITR ecx, SH_POS
        BITS ecx, SH_NEG
        BITS ecx, SH_GATE

set_new_trigger:


    ;// disable gate mode when in frame shift

        .IF ecx & SH_FRAME
            BITR ecx, SH_GATE
        .ENDIF
        mov [esi].dwUser, ecx
        invoke sh_SyncPins
        mov eax, POPUP_INITMENU OR POPUP_SET_DIRTY OR POPUP_REDRAW_OBJECT
        ret

@@: cmp eax, ID_SH_SAMPLE
    jnz @F

        BITR ecx, SH_FRAME
        jmp set_new_trigger

@@: cmp eax, ID_SH_FRAME
    jnz @F

        BITS ecx, SH_FRAME
        jmp set_new_trigger

@@: cmp eax, ID_SH_ZEROSTART
    jnz osc_Command

        xor [esi].dwUser, SH_ZEROSTART
        mov eax, POPUP_SET_DIRTY
        ret

sh_Command ENDP




;////////////////////////////////////////////////////////////////////
;//
;//
;//     _LoadUndo
;//

ASSUME_AND_ALIGN
sh_LoadUndo PROC

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
        mov [esi].dwUser, eax

        invoke sh_SyncPins

        ret

sh_LoadUndo ENDP

;//
;//
;//     _LoadUndo
;//
;////////////////////////////////////////////////////////////////////




ASSUME_AND_ALIGN

ENDIF   ;// USE_THIS_FILE
END





