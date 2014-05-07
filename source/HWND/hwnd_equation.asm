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
;// hwnd_equation.asm   this is the code that mangages the equation builder
;//

;// TOC

;// equ_LocateCurPos
;// equ_Command
;// equ_EditCommands
;// equ_InitDialog
;// equ_UpdateDialog
;// equ_EnableDialog


OPTION CASEMAP:NONE

.586
.MODEL FLAT


USE_THIS_FILE equ 1

IFDEF USE_THIS_FILE

    .NOLIST
    include <Abox.inc>
    include <equation.inc>
    .LIST

;// implemented in equation.asm

.DATA

    equ_szStatus db 'nLev:%i fReg:%i cRem:%i fLen:%i dLen:%i eLen:%i',0

;// private functions implemented here

    equ_LocateCurPos PROTO STDCALL hWnd:DWORD
    equ_EditCommands PROTO
    equ_UpdateDialog PROTO STDCALL hWnd:DWORD
    equ_EnableDialog PROTO STDCALL hWnd:DWORD, dwFlags:DWORD

;// private functions implemented in equation.asm

    equ_BuildSubBuf PROTO
    equ_private_compile PROTO


;// enable gets final say on wheather certain ops can be done
;// so we need to pass the equation as well

;// flags for enable dialog tell it what to look at

    QED_NUMBERS     equ 00000001h   ;// try to enable numbers
    QED_DECIMAL     equ 00000002h   ;// enable the decimal too
    QED_VARIABLES   equ 00000004h   ;// try to enable variables
    QED_BOPS        equ 00000008h   ;// try to enable bops
    QED_UOPS        equ 00000010h   ;// try to enable uops
    QED_BACKSPACE   equ 00000020h   ;// enable the backspace button
    QED_DELETE      equ 00000040h   ;// enable the delete button
    QED_UPDOWN      equ 00000080h   ;// try to enable the updown buttons

    ;// these equtes save some time during a search
    ;// it's rather rediculus to have to define them manually

    ;// index of the decimal element
    EQU_ELEMENT_DECIMAL equ 10
    ;// anything less is a number

    ;// index of the close ')'
    EQU_ELEMENT_CLOSE equ 29
    ;// any higher index is a uop


.CODE

;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
equ_LocateCurPos PROC STDCALL uses esi edi ebx hWnd:DWORD

    ;// with a mouse position
    ;// we locate where curPos is
    ;// then call UpdateDialog

    LOCAL point:POINT

    invoke GetDlgItem, hWnd, ID_EQU_DISPLAY
    mov ebx, eax

    DEBUG_IF<app_msg.hWnd !!= eax>  ;// app msg must be same as this window

;// so, mouse pos should be correct
;// we'll get the character pos from the mouse

    mov eax, app_msg.pt.x
    mov edx, app_msg.pt.y
    mov point.x, eax
    mov point.y, edx
    invoke ScreenToClient, ebx, ADDR point
    movsx edx, WORD PTR [point.y]
    shl edx, 16
    mov dx, WORD PTR [point.x]
    invoke SendMessageA, ebx, EM_CHARFROMPOS, 0, edx
    mov edx, eax

;// now we determine what for_buf location would equal the mouse location

    mov ebx, equ_pEdit
    ASSUME ebx:PTR EQU_EDIT_HEADER

    mov esi, [ebx].pFor_buf ;// esi walks the formula buffer
    ASSUME esi:PTR BYTE

    xor ecx, ecx    ;// cl counts the position in for_buf
                    ;// ch counts accumulated string length

    mov [ebx].selPos, dl    ;// set as the target
    mov [ebx].selLen, 1     ;// default to one

    lodsb
    jmp enter_loop

top_of_loop:

    lea edx, equ_element
    ASSUME edx:PTR EQU_ELEMENT

    search_loop:            ;// locate the token from the for_buf

        xor ah, ah
        or ah, [edx].cFor
        jz not_found

        cmp ah, al
        jz found_it

        add edx, SIZEOF EQU_ELEMENT
        jmp search_loop

    found_it:

        mov al, [edx].cLen  ;// get it's display length

        add ch, al          ;// add to current total

        .IF ch>=[ebx].selPos    ;// check if accumulated is now
            jmp AllDone         ;// greater than the mouse position
        .ENDIF

        inc cl              ;// advance the position count

    ;// get the next character

    lodsb

enter_loop:

    or al, al
    jnz top_of_loop

AllDone:

    mov [ebx].curPos, cl

    ret

not_found:  ;// a token could not be found for a character in for buf

    BOMB_TRAP


equ_LocateCurPos ENDP


;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////
;//
;//     this is the command handler for the equation builder
;//     equ_pEdit must be set up
;//
ASSUME_AND_ALIGN
equ_Command PROC STDCALL USES esi edi hWnd:DWORD, cmdID:DWORD

;// we must return what popup wants to see

;// ignore the status message

    .IF !cmdID

        mov eax, POPUP_IGNORE

;// edit focus messages

    .ELSEIF     cmdID == OSC_COMMAND_EDIT_SETFOCUS

        ;// determine where to set the selction

        invoke equ_LocateCurPos, hWnd
        invoke equ_BuildSubBuf
        invoke equ_UpdateDialog, hWnd

        mov eax, POPUP_KILL_THIS_FOCUS

    .ELSEIF cmdID == OSC_COMMAND_EDIT_KILLFOCUS

        mov eax, POPUP_IGNORE

;// navigation

    .ELSEIF cmdID==ID_EQU_LEFT

        mov esi, equ_pEdit
        ASSUME esi:PTR EQU_EDIT_HEADER
        dec [esi].curPos        ;// back up one

        ;// run the gauntlet and check for an indexed variable
        .IF [esi].bFlags & EQE_USE_INDEX        ;// check flag first
            movzx ecx, [esi].curPos             ;// load current position
            .IF ecx                             ;// check for zero (start)
                mov edi, [esi].pSub_buf         ;// get the sub buf
                ASSUME edi:PTR EQU_SUBBUF       ;// edi is the sub buf
                movzx edx, [edi+ecx*2-2].i_ele  ;// get index of previous character
                shl edx, EQU_ELEMENT_SHIFT      ;// shift to an offset
                .IF equ_element[edx].cTok=='x'  ;// is previous token a varaiable ??
                    dec [esi].curPos            ;// yep, backup another one
                .ENDIF
            .ENDIF
        .ENDIF

        invoke equ_BuildSubBuf
        invoke equ_UpdateDialog, hWnd
        mov eax, POPUP_IGNORE

    .ELSEIF cmdID==ID_EQU_RIGHT

        mov esi, equ_pEdit
        ASSUME esi:PTR EQU_EDIT_HEADER
        movzx ecx, [esi].curPos             ;// load current position

        ;// run the gauntlett and check for an indexed variable
        ;// if we're on a variable now, we add two to the current posiion
        .IF [esi].bFlags & EQE_USE_INDEX        ;// check flag first
            mov edi, [esi].pSub_buf             ;// get the sub buf
            ASSUME edi:PTR EQU_SUBBUF           ;// edi is the sub buf
            movzx edx, [edi+ecx*2].i_ele        ;// get index of current character
            shl edx, EQU_ELEMENT_SHIFT      ;// shift to an offset
            .IF equ_element[edx].cTok=='x'  ;// is previous token a varaiable ??
                inc ecx                     ;// yep, advance another one
            .ENDIF
        .ENDIF

        inc ecx                 ;// advance
        mov [esi].curPos, cl    ;// store new postion

        invoke equ_BuildSubBuf
        invoke equ_UpdateDialog, hWnd
        mov eax, POPUP_IGNORE

;// ignore this

    .ELSEIF cmdID == ID_EQU_DISPLAY

        mov eax, POPUP_IGNORE

    .ELSEIF cmdID == IDC_STATIC_SMALL

        mov eax, POPUP_IGNORE

    .ELSEIF cmdID == ID_EQU_STATUS

        mov eax, POPUP_IGNORE

    .ELSE

        mov eax, cmdID
        invoke equ_EditCommands
        invoke equ_UpdateDialog, hWnd
        mov eax, POPUP_REDRAW_OBJECT + POPUP_SET_DIRTY

    .ENDIF

    ret

equ_Command ENDP

;/////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
equ_EditCommands PROC
;// eax MUST BE THE COMMAND ID
EQU_ENTER


    ;// no matter what happens here, the formula gets dirty

    mov esi, [ebp].pFor_head
    ASSUME esi:PTR EQU_FORMULA_HEADER
    mov [esi].bDirty, 1

    ;// then we load pointers to the rest of this mess

    mov esi, [ebp].pSub_buf
    ASSUME esi:PTR EQU_SUBBUF   ;// get pointer to sub buf
    mov ebx, [ebp].pFor_buf
    ASSUME ebx:PTR BYTE         ;// get pointer to for buf
    movzx ecx, [ebp].curPos
    movzx edi, [esi+ecx*2].i_ele;// get element of current character
    shl edi, EQU_ELEMENT_SHIFT

;// delete and insert

    cmp eax ,ID_EQU_DEL     ;// delete
    jz process_delete

    cmp eax ,ID_EQU_BACK    ;// back space
    jz process_backspace

;// presets

    CMPJMP eax, ID_EQU_PRESET_M2F,  jne @F
    LEAJMP esi,           equ_m2f,  jmp load_preset

@@: CMPJMP eax, ID_EQU_PRESET_F2M,  jne @F
    LEAJMP esi,           equ_f2m,  jmp load_preset

@@: CMPJMP eax, ID_EQU_PRESET_D2F,  jne @F
    LEAJMP esi,           equ_d2f,  jmp load_preset

@@: CMPJMP eax, ID_EQU_PRESET_D2M,  jne @F
    LEAJMP esi,           equ_d2m,  jmp load_preset

@@: CMPJMP eax, ID_EQU_PRESET_M2D,  jne @F
    LEAJMP esi,           equ_m2d,  jmp load_preset

@@: CMPJMP eax, ID_EQU_PRESET_F2D,  jne @F
    LEAJMP esi,           equ_f2d,  jmp load_preset

@@: CMPJMP eax, ID_EQU_PRESET_RESET,jne @F
    lea    esi,        equ_default

    load_preset:

        .ERRNZ EQUATION_PRESET.formula  ;// esi must point at the text

        mov edi, [ebp].pFor_buf
        mov ecx, EQU_PRESET_FORMULA_LENGTH
        rep movsd
        mov [ebp].curPos, 0
        jmp update_and_exit

;// small values
@@:
.IF     eax == ID_EQU_SMALL_8
        xor eax, eax
    @@: mov edi, [ebp].pFor_head
        ASSUME edi:PTR EQU_FORMULA_HEADER
        mov [edi].i_small, eax
        mov eax, POPUP_SET_DIRTY
        jmp update_and_exit
.ELSEIF eax == ID_EQU_SMALL_16
        mov eax, 1
        jmp @B
.ELSEIF eax == ID_EQU_SMALL_32
        mov eax, 2
        jmp @B
.ELSEIF eax == ID_EQU_SMALL_64
        mov eax, 3
        jmp @B


.ELSEIF eax == ID_EQU_UP

    ;// advance an index
    ;// assume this is ok to do

    movzx ecx, [ebp].curPos
    mov edi, [ebp].pFor_buf
    inc BYTE PTR [edi+ecx+1]
    jmp update_and_exit

.ELSEIF eax == ID_EQU_DOWN

    ;// retreat an index
    ;// assume this is ok to do

    movzx ecx, [ebp].curPos
    mov edi, [ebp].pFor_buf
    dec BYTE PTR [edi+ecx+1]
    jmp update_and_exit


;// all the rest

.ELSE

;// determine what the command is

    lea edx, equ_element
    ASSUME edx:PTR EQU_ELEMENT

@@: cmp al, [edx].cmd
    je @F
    add edx, SIZEOF EQU_ELEMENT
    cmp edx, OFFSET equ_element_end
    jb @B


;// ABOX232
;// if we hit this, the command was not found
;// so instead BOMB TRAP
;// we abort

    jmp update_and_exit

;// BOMB_TRAP ;// command not found
;// ABOX232



@@: ;// when we get here:

    ;// ecx is index of current character
    ;// edx is ELEMENT of the command
    ;// esi points at sub buf
    ;// ebp is pointer to equ_editor
    ;// edi is the ofset into the element table for the current token

        mov al, [edx].cTok  ;// get the token
        mov ah, [edx].cFor  ;// get the for character
        ASSUME edx:NOTHING

    ;// al is the token of the command
    ;// ah is the character of the command

    .IF al == 'x'   ;// variables

        ;// if we're using indexed variables ...

        ;// if cursor is on a number, we insert another character
        ;// if cursor is on a constant, we insert a character
        ;// otherwise we're replacing

        ;// we want to default to the variable with the lowest number
        ;// by design, that number will be zero, how convinient!

        .IF [ebp].bFlags & EQE_USE_INDEX    ;// check if we're using indexed variables
            ;// see if this char is a number or constsnt
            .IF [esi+ecx*2].i_ele < 10 ||       \
            (   [esi+ecx*2].i_ele >= 11  &&     \
                [esi+ecx*2].i_ele <= 13 )
                call insert_one_char
            .ENDIF
            mov BYTE PTR [ebx+ecx], ah  ;// set current char to desired variable
            inc ecx                     ;// increase the position index
            mov ah, '0'                 ;// make sure we store zero as the index
        .ENDIF


        ;// these are common exit exit points for this entire funtion

        replace_and_exit:

            ;// ebx must point at the for buffer
            ;// ecx must index it
            ;// ah must be what we want to store
            mov BYTE PTR [ebx+ecx], ah

        update_and_exit:

            EQU_EXIT

    .ELSEIF al == 'K'   ;// constants


        ;// if we are indexed and replacing and variable
        ;// we must delete the index

        test [ebp].bFlags, EQE_USE_INDEX
        jz replace_and_exit ;// treat K's like x's

        call delete_one_char
        jmp replace_and_exit    ;// treat K's like x's


    .ELSEIF al == 'k'   ;// numbers

        ;// if we're on a number now, we insert after
        ;// if we're on a variable we replace it with a number

        comment ~ /*

        there is some errant behavior having to do with this routine appending zero
        versus the user inserting zero. To fix it we would have to remember whether
        or not we or the user inserted the zero

        example:
        key results
        0   _0_
        .   0._0_
        0   0.0_0_  this routine inserted the zero
        1   0.00_1_ but doesn't remember that, so the 1 is added after the extra zero

        other numbers seem to work correctly
        for the time being, this will not be fixed

        */ comment ~

        .IF equ_element[edi].cTok == 'k'        ;// the cursor is on a number now

            ;// if this number is the first digit and it equals zero
            ;// and we're not typeing a decimal, then we replace
            ;// otherwise we insert

                ;// check command char
                CMPJMP ah, '.', je got_decimal          ;// jump if command is a decimal

            ;// not typeing in a decimal

                ;// check current char
                CMPJMP [ebx+ecx],'0', jnz insert_digit  ;// jump if not on a zero

            ;// we are on a zero

                ;// check if very first char
                TESTJMP ecx, ecx, jz replace_and_exit   ;// jump if very first char

            ;// we are not the very first chacter in the string

            ;// if prev char is not a number, then we replace

                CMPJMP [ebx+ecx-1], '.', jz @F
                CMPJMP [ebx+ecx-1], '0', jb replace_and_exit
                CMPJMP [ebx+ecx-1], '9', ja replace_and_exit

            ;// if we get here, then we are on zero
            ;// if we are the last char (we equal zero)
            ;// and there is a decimal before us
            ;// then we replace, insert a zero, and advance the cursor
            @@:
            .IF [ebx+ecx+1] > '9' || [ebx+ecx+1] < '0'

                ;// the cursor is on the last digit of a number
                ;// if:
                ;//     the previous character is the decimal
                ;//     and the types character is not a zero
                ;//     then: we replace
                ;// otherwise we insert

                    mov edx, ecx
                    dec edx                 ;// check for start of string
                    js insert_digit         ;// insert if so
                    .IF [ebx+edx] == '.'        ;// check for decimal
                        .IF ah=='0'             ;// want to type in a zero
                            jmp insert_digit
                        .ELSE
                            jmp replace_and_exit;// replace if found
                        .ENDIF
                    .ENDIF

                ;// if we get here, then we insert a digit and replace it with this char

                ;// call insert_one_char
                ;// inc [ebp].curPos
                ;// jmp replace_and_exit

            .ENDIF

        ;// if we get here, we are on a zero, but we are not the first of last character
        ;// so we insert the typed character

            jmp insert_digit

        got_decimal:

        ;// the command typed in was a decimal place
        ;// if the next character is not a number
        ;// we insert a trailing zero also

            CMPJMP [ebx+ecx+1], '0', jb insert_a_zero
            CMPJMP [ebx+ecx+1], '9', jbe insert_digit

        insert_a_zero:
        ;// have to insert a zero also

            ;// insert two chars

                inc ecx
                call insert_two_char

            ;// then store '.0'

                mov WORD PTR [ebx+ecx], '0.'
                add [ebp].curPos, 2
                jmp update_and_exit

        ;// insert this digit

        insert_digit:

            inc ecx
            inc [ebp].curPos
            call insert_one_char
            jmp replace_and_exit        ;// jmp to replace routine


        .ELSE   ;// check if we're on a variable or a constant

            .IF equ_element[edi].cTok=='x'  ;// cursor is on a variable

                .IF [ebp].bFlags & EQE_USE_INDEX
                    call delete_one_char
                .ENDIF

                jmp replace_and_exit        ;// jmp to replace routine

            .ELSEIF equ_element[edi].cTok=='K'  ;// cursor is on a predefeined constant

                ;// we're on a variable now
                jmp replace_and_exit        ;// jmp to replace routine

            .ENDIF

            BOMB_TRAP   ;// not supposed to happen
            ;// typed in a number over an operator

        .ENDIF

    .ELSEIF al == 'b'   ;//bops

        ;// if we're on a bop now, we replace it
        ;// if we're at the end of the string we insert it

        .IF [ebx+ecx]   ;// check if at end

            ;// not at end

            .IF equ_element[edi].cTok=='b'  ;// on a bop now

                jmp replace_and_exit

            .ELSEIF equ_element[edi].cTok=='x'  ;// on a variable now

                ;// check if we have to advance the cursor
                .IF [ebp].bFlags & EQE_USE_INDEX
                    inc ecx
                    inc [ebp].curPos
                .ENDIF
                jmp insert_bop

            .ELSEIF equ_element[edi].cTok=='k' || \
                    equ_element[edi].cTok=='K' || \
                    equ_element[edi].cFor==')'

            ;// on a variable, so we insert this bop
            insert_bop:

                ;// to do this, we swap in two chars until the end
                inc ecx
                call insert_two_char

                mov [ebx+ecx], ah       ;// store the operator
                inc ecx
                ;// always use zero as the default
                mov ah, '0'
                add [ebp].curPos, 2
                jmp replace_and_exit

            .ELSE

                BOMB_TRAP   ;// invalid char

            .ENDIF

        .ELSE ;// we're at the end, so we append

            mov [ebx+ecx], ah       ;// save the op
            inc ecx                 ;// advance
            mov ah, '0'             ;// always use zero as the default
            mov [ebx+ecx], ah       ;// save the default
            mov [ebp].curPos, cl    ;// save new cursor pos
            inc ecx                 ;// advance
            xor ah, ah              ;// nul terminate
            jmp replace_and_exit

        .ENDIF

    .ELSEIF al == 'u'   ;// uops

        ;// if we're on a uop, we replace
        ;// if we're on a variable, and previous command is a bop
        ;// then we insert this uop
        ;// if we're on a number, we surround with a uop

        .IF [ebx+ecx]   ;// we're not at the end

            .IF equ_element[edi].cTok=='u'

                ;// replace one uop with another

                jmp replace_and_exit

            .ELSEIF equ_element[edi].cTok=='x'  ;// on a variable now

                ;// check if we're using indexes
                .IF !([ebp].bFlags & EQE_USE_INDEX)
                    jmp insert_uop
                .ENDIF

                ;// have to use a different method for uops
                call insert_one_char
                mov [ebx+ecx], ah
                add ecx, 2
                call insert_one_char
                mov ah, ')'
                inc ecx
                add [ebp].curPos, 1
                jmp replace_and_exit


            .ELSEIF equ_element[edi].cTok=='K'

                insert_uop:
                ;// uops insert two chars, one before and one after

                ;// to do this, we swap in two chars until the end

                    call insert_two_char

                    mov [ebx+ecx], ah
                    mov ah, [ebx+ecx+2]
                    mov [ebx+ecx+1], ah
                    mov ah, ')'
                    add ecx, 2
                    inc [ebp].curPos
                    jmp replace_and_exit

            .ELSEIF equ_element[edi].cTok=='k'

                ;// have to surround with uop

                call insert_one_char
                mov [ebx+ecx], ah
                call locate_number_end
                call insert_one_char
                mov ah, ')'
                inc [ebp].curPos
                jmp replace_and_exit

            .ELSE

                BOMB_TRAP   ;// not supposed to happen

            .ENDIF

        .ELSE   ;// insert uop at end

            BOMB_TRAP   ;// not supposed to happen

        .ENDIF

    .ELSE   ;// fell through the command parser

        BOMB_TRAP   ;// command not processed

    .ENDIF

.ENDIF

BOMB_TRAP   ;// how'd we get here ?



;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;//                      all these use edi and edx
;// local functions      locate commands return in ecx
;//

insert_one_char:

    ;// ecx must be at the character to insert
    ;// preserves ecx
    ;// ebx must point at for_buf

        lea edi, [ebx+ecx]
        xor edx, edx
        mov dl, BYTE PTR [edi]
    @@: inc edi
        xchg dl, BYTE PTR [edi]
        or dl, dl
        jnz @B
        mov BYTE PTR [edi+1], dl

        retn

insert_two_char:

    ;// ecx must be at the character to insert
    ;// preserves ecx
    ;// ebx must point at for_buf

        lea edi, [ebx+ecx]
        xor edx, edx
        mov dx, WORD PTR [edi]
    @@: add edi, 2
        xchg dx, WORD PTR [edi]
        or dx, dx
        jnz @B
        mov WORD PTR [edi+2], dx

        retn

locate_number_start:

    ;// returns the start index in ecx
    ;// ebx must point at for_buf

    @@: dec ecx
        js  @F      ;// stop if at start
        cmp [ebx+ecx], '.'
        jz @B
        cmp [ebx+ecx], '0'
        jb @F
        cmp [ebx+ecx], '9'
        jbe @B
    @@: inc ecx
        retn

locate_number_end:

    ;// returns one passed end in ecx
    ;// ebx must point at for_buf

    @@: inc ecx
        cmp [ebx+ecx], '.'
        jz @B
        cmp [ebx+ecx], '0'
        jb @F
        cmp [ebx+ecx], '9'
        jbe @B
    @@: retn

delete_one_char:

    ;// ecx must be at the character to delete
    ;// ebx must point at for_buf

        lea edi, [ebx+ecx]
    @@: xor edx, edx
        or dl, BYTE PTR [edi+1]
        mov BYTE PTR [edi], dl
        jz @F
        inc edi
        jmp @B
    @@: retn

delete_two_char:

    ;// ecx must be at the character to delete
    ;// ebx must point at for_buf

        lea edi, [ebx+ecx]
    @@: xor edx, edx
        or dx, WORD PTR [edi+2]
        mov WORD PTR [edi], dx
        jz @F
        add edi, 2
        jmp @B
    @@: retn

delete_edx_to_ecx:

    ;// moves ecx to edx until end of string
    ;// ebx must point at for_buf

        sub ecx, edx                ;// determine the difference
        .IF SIGN? || ZERO?
            BOMB_TRAP   ;// bad parameters
        .ENDIF
        lea edi, [ebx+edx]      ;// point at destination
    @@: xor eax, eax                ;// clear accum
        or al, BYTE PTR [edi+ecx]   ;// load and test next char
        mov BYTE PTR [edi],al       ;// store in current char
        jz @F                       ;// exit if done
        inc edi                     ;// advance edi
        jmp @B                      ;// continue loop
    @@: retn


;//////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////
;//
;//  key handlers
;//

process_delete:

    ;// if cur is number then we delete at
    ;// if cur is variable we shouldn't be here
    ;// if cur is bop we shouldn't be here
    ;// if cur is uop we delete the surrounding parenthesis

    mov al, equ_element[edi].cTok   ;// load token we're on now

    .IF al =='u'    ;// char is uop, we delete the surrounding parenthesis

            ;// delete the current character

            call delete_one_char

            ;// search forward to closing parenthesis
            ;// also have to track opening new paranthesis

            mov edi, [ebp].pSub_buf
            ASSUME edi:PTR EQU_SUBBUF

            xor eax, eax;// clear accum

        @0: inc ecx     ;// advance first, because sub buf hasn't been rebuilt yet
        @1: cmp [edi+ecx*2].i_ele, EQU_ELEMENT_CLOSE
            jb @0       ;// iterate
            ja @3       ;// new opening uop
            dec eax     ;// got a close
            jns @0      ;// jump out if this is the one we want

        @4: dec ecx     ;// ecx is index of closing
            call delete_one_char
            jmp update_and_exit

        @3: inc eax     ;// new opening uop
            jmp @0


    .ELSEIF al=='b'     ;// we're currently on a bop

        ;// we delete this and the next item

        ;// if next char is a number, we have to delete the entire number

        .IF ( [ebx+ecx+1] >= '0' && [ebx+ecx+1] <= '9' ) || [ebx+ecx+1] == '.'

            ;// scan forward to end of number

                call locate_number_end

            ;// now ecx is one passed number

                movzx edx, [ebp].curPos     ;// reload cursor pos
                call delete_edx_to_ecx
                jmp update_and_exit

        .ELSE   ;// we assume the next char is either a variable or constant

                call delete_two_char
                .IF [ebx+ecx] >= '0' && [ebx+ecx] <= '9'
                    ;// delete the index too
                    call delete_one_char
                .ENDIF
                jmp update_and_exit

        .ENDIF

    .ELSEIF al=='k' ;// we're currently on a number

        ;// if the next char is a decimal
        ;// and the previous char is not a number
        ;// we delete the decimal also

        ;// if this is the last char, and the previous char is a decimal
        ;// we delete the decimal

        ;// if this is the last number, then we retreat

            .IF [ebx+ecx+1]=='.'    ;// next char is a decimal

                .IF !ecx

                    ;// no previous char, so it can't be a number
                    ;// so we delete this char, and the decimal

                        jmp @F

                .ELSE ;// IF [ebx+ecx-1] >= '0' && [ebx+ecx-1] <= '9'

                        ;// we delete this char, and the decimal

                    @@: call delete_two_char
                        jmp update_and_exit

                .ENDIF

            .ELSEIF ([ebx+ecx+1] < '0' || [ebx+ecx+1] > '9')

                ;// we are the last digit of a number

                .IF ecx

                    .IF [ebx+ecx-1]=='.'

                    ;// delete decimal if last digit
                    ;// have to delete the previous decimal

                        dec ecx
                    @@: call delete_two_char
                        sub [ebp].curPos, 2
                        jmp update_and_exit

                    .ENDIF

                    ;// retreat if last digit, but not first
                    dec [ebp].curPos

                .ENDIF

            .ENDIF

            ;// here we simply delete the current char

            call delete_one_char
            jmp update_and_exit

    .ELSEIF al=='x'
        BOMB_TRAP   ;// not supposed to happen
    .ELSE
        BOMB_TRAP   ;// not supposed to happen
    .ENDIF

    BOMB_TRAP   ;// how the hell did we get here ??

process_backspace:

    dec ecx
    DEBUG_IF <SIGN?>    ;// not supposed to be able to backspace on first char

    ;// --> ecx points at the previous character
    ;// the one we're going to delete

    ;// if cur char is uop, we shouldn't be here
    ;// if cur is variable we shouldn't be here

    ;// if cur is number then we delete backwards to start of number
    ;//     if cur is a decimal
    ;//     and cur-2 is not a number
    ;//         then we delete two chars

    ;// if cur is bop, we delete backwards including previous element

    mov al, equ_element[edi].cTok

    .IF al=='k' ;// this is a number

        .IF equ_element[edi].cFor == '.'

            ;// we're on the decimal

            ;// if cur-1 is not a number
            ;// then we delete it and the decimal

            .IF ecx

                .IF [ebx+ecx-1]<'0' || [ebx+ecx-1]>'9'

                    ;// have to delete the decimal
                    jmp @F

                .ENDIF

            .ELSE   ;// char before previous is before the start of the string
                    ;// so it can't be a number

                ;// have to delete the decimal

                @@: call delete_two_char
                    jmp update_and_exit

            .ENDIF

        .ENDIF

        ;// simply delete previous char

            dec [ebp].curPos            ;// retreat now
            call delete_one_char
            jmp update_and_exit

    .ELSEIF al=='b' ;// this is a bop

        ;// if previous is a number, and not part of an indexed variable
        ;// we have to delete the entire the entire number
        ;// if previous is a variable, we delete this the variable
        ;// any other is an error

        ;// check for previous being a number
        .IF [ebx+ecx] >= '0' && [ebx+ecx] <= '9'

            ;// now we check if this number isn't part of an index
            cmp ecx, 1  ;// too close to start to be a variable ?
            jb  @F

            ;// the best way is to determine it's token class
            movzx edx, [esi+ecx*2-2].i_ele
            shl edx, EQU_ELEMENT_SHIFT

            .IF equ_element[edx].cTok != 'x'

                ;// have to delete an entire number
            @@:     call locate_number_start
                    xor edx, edx
                    mov dl, [ebp].curPos
                    mov [ebp].curPos, cl
                    inc dl
                    xchg cl, dl
                    call delete_edx_to_ecx
                    dec [ebp].curPos
                    jns update_and_exit
                    mov [ebp].curPos, 0
                    jmp update_and_exit

            .ELSE   ;// previous was an indexed variable
                    ;// so we have to delete it too

                    dec ecx
                    call delete_two_char
                    call delete_one_char
                    sub [ebp].curPos, 3
                    jns update_and_exit
                    mov [ebp].curPos, 0
                    jmp update_and_exit

            .ENDIF

        .ELSE   ;// assume that the previous is a variable or a konstant

                ;// delete this and the previous

                dec [ebp].curPos            ;// retreat now
                jz @F
                dec [ebp].curPos            ;// retreat again
            @@: call delete_two_char
                jmp update_and_exit

        .ENDIF

    .ELSEIF al=='x'
        BOMB_TRAP   ;// not supposed to happen
    .ELSEIF al =='u'
        BOMB_TRAP
    .ELSE
        BOMB_TRAP   ;// invalid token
    .ENDIF

    BOMB_TRAP   ;// how the hell did we get here ??


equ_EditCommands ENDP

;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
equ_InitDialog PROC STDCALL uses esi edi ebx hWnd:DWORD, pObject:DWORD, pFor:DWORD, pVar:DWORD, dwFlags:DWORD

    ;// initialize an edit header for this formula

        .IF equ_pEdit
            invoke equ_EditDtor
        .ENDIF
        invoke equ_EditCtor, pFor, pVar, dwFlags

    ;// get all the hWnds for the controls
    ;// if they don't exist we bomb

        lea esi, equ_element
        ASSUME esi:PTR EQU_ELEMENT
        .WHILE [esi].cFor
            movzx eax, [esi].cmd
            .IF eax
                invoke GetDlgItem, hWnd, eax
                mov [esi].hWnd, eax
                .IF !eax
                    BOMB_TRAP   ;// required control was not found
                .ENDIF
            .ENDIF
            add esi, SIZEOF EQU_ELEMENT
        .ENDW

    ;// get the pointer to the formula header

        mov esi, pFor
        ASSUME esi:PTR EQU_FORMULA_HEADER

    ;// set the correct small button
        .IF     [esi].i_small == 3
            mov ecx, ID_EQU_SMALL_64
        .ELSEIF [esi].i_small == 2
            mov ecx, ID_EQU_SMALL_32
        .ELSEIF [esi].i_small == 1
            mov ecx, ID_EQU_SMALL_16
        .ELSE;//[esi].i_small == 0
            mov ecx, ID_EQU_SMALL_8
        .ENDIF
        invoke CheckDlgButton, hWnd, ecx, 1

    ;// check if we disable the presets

        .IF dwFlags & EQE_NO_PRESETS
            push ebx
            mov ebx, ID_EQU_PRESET_FIRST
            .REPEAT
                invoke GetDlgItem, hWnd, ebx
                invoke EnableWindow, eax, 0
                inc ebx
            .UNTIL ebx > ID_EQU_PRESET_LAST
        .ENDIF

    ;// set the controls correctly

        invoke equ_UpdateDialog, hWnd

    ret

equ_InitDialog ENDP



;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
equ_UpdateDialog PROC STDCALL uses esi edi ebx hWnd:DWORD

    ;// this looks at where the cursor is and enables\disables the
    ;// appropriate dialog buttons
    ;// naturally the dialog must exist as well as all the controls being defined
    ;// we also require an edit header

    LOCAL buf[64]:BYTE  ;// buffer for strings

;// load the equ_edit pointer

    mov ebx, equ_pEdit
    ASSUME ebx:PTR EQU_EDIT_HEADER

;// make sure the equation is built

    mov esi, [ebx].pFor_head
    ASSUME esi:PTR EQU_FORMULA_HEADER
    .IF [esi].bDirty

        .IF diff_hWnd

            ;// need to use another method if a differential system caused this

            ;// here's how:
            ;//
            ;//     save settings for edit header
            ;//     save pEdit->pFor, pEdit->pVar, and pEdit flags
            ;//     call equ_EditDtor
            ;//     load the pop_object and call inaval_shape changed
            ;//     call gdi_invalidate
            ;//         diff_set shape will then do all the work
            ;//     re create a new pEdit using the stored pEdit and pVar
            ;//  continue on

            ;// here we go

            mov eax, DWORD PTR [ebx].curPos ;// get cursor settings
            and eax, 0FFFFFFh               ;// strip out flags
            push eax                        ;// store on stack

            ;// curPos  db  0   ;// position of the cursor in for_buf
            ;// selPos  db  0   ;// position of the cursor in dis_buf
            ;// selLen  db  0   ;// number of characters to highlight
            ;// bFlags  db  0   ;// flags for operation

            mov eax, DWORD PTR [ebx].curPos ;// get cursor settings
            shr eax, 24                         ;// move flags down into place
            push eax                ;// store them
            push [ebx].pVar_head    ;// store the variables
            push [ebx].pFor_head    ;// store the equation

            invoke equ_EditDtor     ;// destroy the current struct

        ;// mov eax, INVAL_SHAPE_CHANGED + INVAL_UPDATE + INVAL_OSC_MOVED   ;// setup for a call to set shape
        ;// invoke gdi_Invalidate_osc       ;// add to inval list

            push ebp
            GET_OSC_FROM esi, popup_Object          ;// get the object in question
            stack_Peek gui_context, ebp
            GDI_INVALIDATE_OSC (HINTI_OSC_SHAPE_CHANGED OR HINTI_OSC_UPDATE OR HINTI_OSC_MOVED)
            pop ebp

            invoke gdi_Invalidate           ;// cause diff to recompile

            call equ_EditCtor       ;// recreate using stored values

            mov ebx, equ_pEdit      ;// reload just in case
            pop eax                 ;// retrieve the cursor settings
            or DWORD PTR [ebx].curPos, eax  ;// put back in header

            invoke equ_BuildSubBuf  ;// build sub buffer to get the stats

            mov ebx, equ_pEdit      ;// reload again

        .ELSE       ;// diff hWnd is not on, so we just compile this

            invoke equ_private_compile

        .ENDIF

    .ENDIF


;// determine if the cursor is at the end

    mov esi, [ebx].pFor_buf
    ASSUME esi:PTR BYTE
    movzx ecx, [ebx].curPos

.IF ![esi+ecx]  ;// we're at the end of the string

    call check_buffer_length

    .IF CARRY?

        ;// buffers are too long
        ;// don't do anything
        invoke equ_EnableDialog, hWnd, 0
        jmp AllDone

    .ELSE

        ;// the string is NOT too long
        ;// and we are passed the end
        ;// we allow bops

        ;// and defeat the right button
        ;// by logic, we cannot delete the last char
        ;// and we cannot backspace either

        xor edx, edx            ;// bops insert konstants
        .IF [ebx].k_remain > 1  ;// make sure there are some left
            or edx, QED_BOPS
        .ENDIF

        invoke equ_EnableDialog, hWnd, edx
        invoke GetDlgItem, hWnd, ID_EQU_RIGHT
        invoke EnableWindow, eax, 0

    .ENDIF

.ELSE
;// we're not at the end, but might still be too big to add anything new
;// we still have to allow correct backspace and delete however

    ;// get the current token

        mov edi, [ebx].pSub_buf
        movzx edi, (EQU_SUBBUF PTR [edi+ecx*2]).i_ele
        shl edi, EQU_ELEMENT_SHIFT

        mov ax, WORD PTR (equ_element[edi])

    ;// ah and al have the current character

    ;// at the end of this mess, we'll have eax as the flags we want

        .IF al==')'

            ;// can't replace with anything
            ;// but we can insert a bop

            call check_buffer_length
            .IF CARRY?
                xor eax, eax
            .ELSEIF [ebx].k_remain > 1
                mov eax, QED_BOPS
            .ENDIF

        .ELSEIF ah == 'k'

            ;// the cursor is on a number

            ;// this routine is complicated enough to require a seperate function

            ;// if this is a single digit
            ;//   we can replace it with a variable or a uop
            ;//    we can also insert a bop
            ;// otherwise we can only type in more numbers
            ;//   if this the last digit
            ;//     no delete, backspace ok
            ;//     we can insert a bop -- if there's room in the const buffer
            ;//    if this is the first digit
            ;//     no backspace, delete ok
            ;// to futher compilcate matters
            ;// if this number already a decimal, we cannot insert another one
            ;// we also must check if we've enough room to add anything
            ;// to make it even worse,
            ;// we have to check exactly 'which' numbers we can type in

            ;// so: let's just parse the number
            ;// use eax as a 'found decimal' flags

            ;// locate start of number and store index in dl

                movzx ecx, [ebx].curPos
                xor eax, eax
                mov edi, [ebx].pSub_buf
                ASSUME edi:PTR EQU_SUBBUF

                @0: mov dl, cl  ;// store string start
                    dec ecx     ;// decrease pointer
                    js @1       ;// exit if before start of string
                    cmp [edi+ecx*2].i_ele, EQU_ELEMENT_DECIMAL
                    ja  @1      ;// exit if not number
                    jb  @0      ;// iterate if normal number
                    inc eax     ;// this is a decimal
                    jmp @0      ;// iterate
                @1: ;// dl is start of number

            ;// locate end of number and store index in dh

                movzx ecx, [ebx].curPos

                @2: mov dh, cl  ;// store string end
                    inc ecx     ;// advance the pointer
                    cmp [edi+ecx*2].i_ele, EQU_ELEMENT_DECIMAL
                    ja  @3      ;// exit if not a number
                    jb  @2      ;// iterate if normal number
                    inc eax     ;// this is the decimal
                    jmp @2      ;// iterate
                @3: ;// dh is end of number

            ;// now we can decide what to enable

            .IF dh==dl      ;// single digit

            ;// so we're at the start and the end of the number
            ;// we can also add a decimal
            ;// make sure adding a new number
            ;// won't make the for_buf or dis_buf too long
            ;// also check if there's room in the k_buf

                call check_buffer_length

                .IF CARRY?
                    xor eax, eax    ;// no room
                .ELSE

                    .IF eax
                        mov eax, QED_NUMBERS + QED_VARIABLES + QED_UOPS
                    .ELSE
                        mov eax, QED_NUMBERS + QED_DECIMAL + QED_VARIABLES + QED_UOPS
                    .ENDIF

                    .IF [ebx].k_remain > 1
                        or eax, QED_BOPS
                    .ELSE
                        and eax, NOT ( QED_NUMBERS + QED_DECIMAL )
                    .ENDIF

                .ENDIF

            .ELSE   ;// more than 1 digit

                ;// determine if the number is too big
                mov ah, dh  ;// al still has the decimal flag
                sub ah, dl
                .IF ah>=18  ;// the number has too many digits

                    .IF [ebx].k_remain <= 1

                        xor eax, eax    ;// can't edit this number

                    .ELSE

                        movzx ecx, [ebx].curPos

                        .IF dh==cl      ;// last digit

                            mov eax, QED_BACKSPACE
                            call check_buffer_length
                            .IF !CARRY?
                                .IF [ebx].k_remain > 1
                                    or eax, QED_BOPS
                                .ENDIF
                            .ENDIF

                        .ELSEIF dl==cl  ;// first digit

                            call check_buffer_length

                            .IF CARRY?
                                mov eax, QED_DELETE
                            .ELSE
                                mov eax, QED_UOPS + QED_DELETE
                            .ENDIF

                        .ELSE           ;// middle digit

                            mov eax, QED_BACKSPACE + QED_DELETE

                        .ENDIF

                    .ENDIF

                .ELSE   ;// number does NOT have too many digits

                    .IF [ebx].k_remain <= 1

                        xor eax, eax    ;// can't edit this number

                    .ELSE

                         call check_buffer_length
                         movzx ecx, [ebx].curPos
                         .IF CARRY?

                            .IF dh==cl      ;// last digit
                                mov eax, QED_BACKSPACE
                            .ELSEIF dl==cl  ;// first digit
                                xor eax, eax
                            .ELSE           ;// middle digit
                                mov eax, QED_DELETE + QED_BACKSPACE
                            .ENDIF

                        .ELSE   ;// buffer has room for more digits

                            .IF al
                                mov eax, QED_NUMBERS + QED_DELETE
                            .ELSE
                                mov eax, QED_NUMBERS + QED_DELETE + QED_DECIMAL
                            .ENDIF

                            .IF dh==cl      ;// last digit
                                or eax,  QED_BACKSPACE
                                .IF [ebx].k_remain > 1
                                    or eax, QED_BOPS
                                .ENDIF
                            .ELSEIF dl==cl  ;// first digit
                                add eax, QED_UOPS
                            .ELSE           ;// middle digit
                                add eax, QED_BACKSPACE
                            .ENDIF

                        .ENDIF
                    .ENDIF
                .ENDIF

            .ENDIF

        .ELSEIF ah == 'u'

            ;// we're on a uop
            ;// we can replace it with another uop
            ;// and we can delete it
            ;// we can not back space

            call check_buffer_length
            .IF CARRY?
                mov eax, QED_DELETE
            .ELSE
                mov eax, QED_UOPS + QED_DELETE
            .ENDIF

        .ELSEIF ah == 'x'

            ;// we're on a variable
            ;// we can replace it with another variable
            ;// we can replace it with a number -- if there is a slot left in the constants
            ;// we can insert a bop -- if there is a slot left in the constants
            ;// we can surrond it with a uop
            ;// we can up or down the index, if such a variable is valid
            ;//                             enable dialog will determine that
            ;// we can not delete or backspace variables

            mov eax, QED_VARIABLES + QED_UPDOWN

            ;// check the number of constants left
            .IF [ebx].k_remain > 1  ;// leave one to spare
                or eax, QED_NUMBERS
            .ENDIF

            ;// then check if there's room to display a new bop or uop
            call check_buffer_length
            .IF !CARRY?
                or eax, QED_UOPS
                .IF [ebx].k_remain > 1  ;// check if there's room for a new constant
                    or eax, QED_BOPS
                .ENDIF
            .ENDIF

        .ELSEIF ah == 'b'

            ;// we're on a bop
            ;// we can replace it with another bop
            ;// if the preceeding token is a number or variable, we can backspace

            ;// if the following token is a number or var, we can delete
            call check_buffer_length
            .IF CARRY?
                xor eax, eax
            .ELSE
                mov eax, QED_BOPS
            .ENDIF

            mov edi, [ebx].pSub_buf
            ASSUME edi:PTR EQU_SUBBUF

            movzx ecx, [ebx].curPos
            .IF ecx

                movzx edx, [edi+ecx*2-2].i_ele
                shl edx, EQU_ELEMENT_SHIFT
                .IF equ_element[edx].cTok == 'x' || \
                    equ_element[edx].cTok == 'k'    || \
                    equ_element[edx].cTok == 'K'
                    or eax, QED_BACKSPACE       ;// backspace is ok
                .ENDIF
            .ENDIF

            movzx edx, [edi+ecx*2+2].i_ele
            shl edx, EQU_ELEMENT_SHIFT

            .IF equ_element[edx].cTok == 'x' || \
                equ_element[edx].cTok == 'k'    || \
                equ_element[edx].cTok == 'K'
                or eax, QED_DELETE          ;// delete ok

            .ENDIF

        .ELSEIF ah == 'K'

            ;// we're on a constant
            ;// we can replace with another constant or a variable
            ;// and we can insert a bop

            call check_buffer_length
            .IF CARRY?
                xor eax, eax
            .ELSE
                mov eax, QED_VARIABLES + QED_UOPS
                .IF [ebx].k_remain > 1
                    or eax, QED_BOPS + QED_NUMBERS
                .ENDIF

            .ENDIF

        .ELSE

            BOMB_TRAP   ;// invalid character

        .ENDIF

    ;// finally, we get to enable the button

        invoke equ_EnableDialog, hWnd, eax

AllDone_right:  ;// since we're here, we allow the right button

    invoke GetDlgItem, hWnd, ID_EQU_RIGHT
    invoke EnableWindow, eax, 1

.ENDIF
AllDone:    ;// show the current display string

    invoke GetDlgItem, hWnd, ID_EQU_DISPLAY
    mov edi, eax
    WINDOW edi, WM_SETTEXT, 0, [ebx].pDis_buf
    ;//invoke SetWindowTextA, edi, [ebx].pDis_buf
    movzx edx, [ebx].selPos
    movzx eax, [ebx].selLen
    add eax, edx
    invoke SendMessageA, edi, EM_SETSEL, edx, eax
    invoke SendMessageA, edi, EM_SCROLLCARET, 0, 0

;// check if we allow the left button

    invoke GetDlgItem, hWnd, ID_EQU_LEFT
    movzx ecx, [ebx].selPos
    invoke EnableWindow, eax, ecx

;// show the status at this position
;// do not show status if at end of string

    ;// equ_szStatus db 'nLev:%i fReg:%i cRem:%i fLen:%i dLen:%i eLen:%i',0

    movzx ecx, [ebx].curPos
    mov edi, [ebx].pSub_buf
    movzx edi, (EQU_SUBBUF PTR [edi+ecx*2]).i_tok

    .IF edi != 0FFh  ;// check for invalid value and do not show status if so

    ;// valid value

        shl edi, 1
        add edi, [ebx].pPre_buf

        movzx edx, (EQU_PREBUF PTR [edi]).FPU
        movzx ecx, (EQU_PREBUF PTR [edi]).POS
        mov edi, [ebx].k_remain
        dec edi

        invoke wsprintfA, ADDR buf, OFFSET equ_szStatus, ecx, edx, edi, [ebx].f_len, [ebx].d_len, [ebx].e_len
        invoke GetDlgItem, hWnd, ID_EQU_STATUS
        mov ecx, eax
        WINDOW ecx, WM_SETTEXT,0,ADDR buf

    .ELSE

    ;// invalid value (end of string)

        pushd 0
        push esp
        push 0
        pushd WM_SETTEXT
        invoke GetDlgItem, hWnd, ID_EQU_STATUS
        push eax
        call SendMessageA
        pop eax

    .ENDIF

;// that's about it

    ret




;/////////////////////////////////////////////////////////////////////////////
;//
;//  local functions
;//
;/////////////////////////////////////////////////////////////////////////////

check_buffer_length:

    ;// consumes ecx
    ;// returns carry flag if too long

;// xor ecx, ecx
    ;// check if the for_buf is too long
    mov ecx, [ebx].f_len
    cmp ecx, [ebx].f_len_max_dlg
    jnc @F

    ;// check if the dis_buf is about to be too long
;// xor ecx, ecx
    mov ecx, [ebx].d_len
    cmp ecx, [ebx].d_len_max_dlg

@@: cmc     ;// flip the carry flag
    retn    ;// return


equ_UpdateDialog ENDP

;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN

equ_EnableDialog PROC STDCALL USES esi edi ebx hWnd:DWORD, dwFlags:DWORD

;// scan through all the elements and enable each
;// type of button as indicated by the passed parameters

;// update dialog called this with dwFlags being logically acceptable
;// keystrokes we allow. This function however gets final say on wheather
;// a keystroke can be used based on the current values of POS and FPU

    mov ebx, equ_pEdit          ;// get the equation
    ASSUME ebx:PTR EQU_EDIT_HEADER

    lea esi, equ_element        ;// esi walks equ_elements
    ASSUME esi:PTR EQU_ELEMENT


;// we'll do this in groups
;// numbers
;// variables and constants
;// uops
;// bops


;// numbers

    xor edi, edi
    .IF dwFlags & QED_NUMBERS
        inc edi
    .ENDIF

    .REPEAT
        invoke EnableWindow, [esi].hWnd, edi
        add esi, SIZEOF EQU_ELEMENT
    .UNTIL esi == OFFSET equ_element_dec

;// decimal

    xor edi, edi
    .IF dwFlags & QED_DECIMAL
        inc edi
    .ENDIF

    invoke EnableWindow, [esi].hWnd, edi
    add esi, SIZEOF EQU_ELEMENT

;// constants, treat as non indexed variables

    xor edi, edi
    .IF dwFlags & QED_VARIABLES
        inc edi
    .ENDIF

    .REPEAT
        invoke EnableWindow, [esi].hWnd, edi
        add esi, SIZEOF EQU_ELEMENT
    .UNTIL esi == OFFSET equ_element_var

;// variables

;// variables require that we scan the evar table variables we can find
;// while we're here, we'll verify the QED_UP and QED_DOWN flag

;// we'll csan through the letters
;// variable names are located in order, both in the element table and the edit_header
;// do a new sub-scan for each new letter
;// if a letter is available, enable it's button
;// if a letter has available indexes, enable the appropriate up down buttons

;// registers thus far
;//
;//     esi points at current element
;//     ebx points at the element header
;//

    .IF dwFlags & QED_VARIABLES

        ;// variables requires both an FPU and a POS
        ;// so we check both now
        mov edx, [ebx].pPre_buf
        movzx ecx, [ebx].curPos
        lea edx, [edx+ecx*2]
        ASSUME edx:PTR EQU_PREBUF
        .IF [edx].POS < EQU_MAX_POS_DLG && [edx].FPU < EQU_MAX_FPU

            ;// if we get here, there's room in the compiler for variables

            mov edi, [ebx].pVar_buf
            ASSUME edi:PTR EQU_VARIABLE ;// edi walks variables
                                        ;// esi walks elements
            xor ecx, ecx    ;// ecx tracks the element buffer
            xor edx, edx    ;// edx tracks the variable table

            ;// outside scan:   scan elements
            ;// inside scan:    scan variables, indexed or not
            ;// unmtaching name letters will define the button state
            ;// and iterate the outside loop
            ;//
            ;// a treacherous scan, we assume both the element table and
            ;// equ_variables are set up correctly
            ;// if this is not the case, the buttons will not be set correctly

            .REPEAT
            @0: xor eax, eax                ;// eax is a flag to enable or disable
                mov cl, [esi].cFor          ;// load letter from element
            @1: cmp cl, [edi].textname.letter   ;// compare letter with letter
                jnz @3                      ;// do they match ??
                test [edi].dwFlags, EVAR_AVAILABLE  ;// is variable available ?
                jz @2                       ;// jmp if it's not
                mov eax, 1                  ;// enable if so
            @2: add edi, SIZEOF EQU_VARIABLE;// iterate to next variable
                jmp @1                      ;// jump to inner loop
                ;// letters did not match, so we're done with this block
            @3: invoke EnableWindow, [esi].hWnd, eax    ;// enable or disbale the window
                add esi, SIZEOF EQU_ELEMENT             ;// iterate to next element
            .UNTIL esi == OFFSET equ_element_bop

            ;// now we check the current position and see if we're index or not
            ;// if so, we determine is we can enable of disable the updown buttons

            .IF dwFlags & QED_UPDOWN    ;// this is keyed by update dialog

            ;// here's were we check the updown buttons
            ;// to do that we look at the token, and then
            ;// scan through evar to see if up or down should be enabled

                ;// by convention, indexable variables will have an ascii numeral
                ;// as part of their token.texName
                ;// if this numeral does not exist, then up and down are disbaled
                ;// if the numeral does exit, we look at previous evar and see if the text
                ;// name is the same, and that it has a lower index
                ;// if found, then down is enabled
                ;// do the opposite for the up button (scan forward, look for match and a higher index)

                ;// to get the evar entry in question, we have to get from the sub_buf
                ;// to the evar table, to do this we use the i_tok index

                movzx ecx, [ebx].curPos     ;// reload current position
                mov edi, [ebx].pSub_buf     ;// look at the sub buffer
                movzx edi, (EQU_SUBBUF PTR [edi+ecx*2]).i_tok   ;// load the token index
                DEBUG_IF <edi==0FFh> ;// not supposed to happen
                shl edi,1                   ;// rescale to a token index
                add edi, [ebx].pTok_buf     ;// add offset of token table
                movzx edi, (EQU_TOKBUF PTR[edi]).oper   ;// load the index into evar
                shl edi, EQU_VARIABLE_SHIFT ;// shift into a variable
                add edi, [ebx].pVar_buf     ;// add the offset to the variable table
                ;// now edi points at the equ_variable in question
                ASSUME edi:PTR EQU_VARIABLE

                .IF BYTE PTR [edi].textname.index   ;// check the index

                    ;// if the next variable has the same name
                    ;// and a lower number, we can go down

                    ;// if the previous variable has the same name
                    ;// and a higher number, we can go up


                    ;// check previous first
                    mov dx, WORD PTR [edi].textname ;// get the name and index
                    xor ecx, ecx                ;// ecx is enable/disable flag
                    inc dh                      ;// advance one index
                    cmp edi, [ebx].pVar_buf     ;// make sure there's a previous
                    jbe @4                      ;// jump out if so
                    ;// compare names
                    cmp WORD PTR [edi-SIZEOF EQU_VARIABLE].textname, dx
                    jnz @4                      ;// jump if not same
                    ;// check if available
                    test [edi-SIZEOF EQU_VARIABLE].dwFlags, EVAR_AVAILABLE
                    jz @4                       ;// jump if not available
                    inc ecx ;// when we get here the up button is ok to use
                @4: push ecx                            ;// push this
                    invoke GetDlgItem, hWnd, ID_EQU_UP  ;// get handle to up button
                    push eax                            ;// push
                    call EnableWindow                   ;// parameters pushed manually

                    ;// assume that there's always constants next
                    ;// this will bite me in months to come
                    mov dx, WORD PTR [edi].textname ;// get the name (again)
                    xor ecx, ecx                ;// ecx is enable/disable flag
                    dec dh                      ;// decease one index
                    ;// compare the names
                    cmp WORD PTR [edi+SIZEOF EQU_VARIABLE].textname, dx
                    jnz @5
                    ;// check if available
                    test [edi+SIZEOF EQU_VARIABLE].dwFlags, EVAR_AVAILABLE
                    jz @5
                    inc ecx     ;// when we get here the down button is ok to use
                @5: push ecx                            ;// push this
                    invoke GetDlgItem, hWnd, ID_EQU_DOWN;// get handle to down button
                    push eax                            ;// push
                    call EnableWindow                   ;// parameters pushed manually

                    jmp do_bops     ;// jump to next section

                .ENDIF

            .ENDIF

            ;// QED_UPDOWN is not specified or is invalid
            xor edi, edi            ;// disable the updown buttons
            jmp disable_up_down     ;// jump to next section

        .ENDIF

    .ENDIF

    ;// if we hit this, variables are not wanted or acceptable
    ;// so we diable all of them and the updown butons

    ;// disbale the variable buttons

    xor edi, edi
    .REPEAT
        invoke EnableWindow, [esi].hWnd, edi
        add esi, SIZEOF EQU_ELEMENT
    .UNTIL esi == OFFSET equ_element_bop

disable_up_down:

    ;// disable the updown buttons
    invoke GetDlgItem, hWnd, ID_EQU_UP
    invoke EnableWindow, eax, edi
    invoke GetDlgItem, hWnd, ID_EQU_DOWN
    invoke EnableWindow, eax, edi


;// bops
do_bops:

    .IF dwFlags & QED_BOPS

        ;// we want to make sure each individgual bop does not
        ;// overflow the pos stack or the fpu
        ;// we also check if said instruction would make the exe too long

        ;// get the pre_buf for the current position
        ;// via the sub_buf

        mov edi, [ebx].pSub_buf
        movzx ecx, [ebx].curPos
        movzx ecx, (EQU_SUBBUF PTR [edi+ecx*2]).i_tok

        .IF ecx != 0FFh

            mov edi, [ebx].pPre_buf
            lea edi, [edi+ecx*2]
            ASSUME edi:PTR EQU_PREBUF
            .IF [edi].POS < EQU_MAX_POS_DLG

                .REPEAT
                    xor edx, edx
                    ;// check fpu use
                    mov al, [edi].FPU
                    .IF al < [esi].fpu
                    ;// check exe space
                        movzx eax, [esi].eLen
                        .IF eax < [ebx].e_remain
                            inc edx
                        .ENDIF
                    .ENDIF
                    invoke EnableWindow, [esi].hWnd, edx
                    add esi, SIZEOF EQU_ELEMENT
                .UNTIL esi == OFFSET equ_element_close

                jmp do_close

            .ENDIF

        .ELSE
            ;// we are at the end of the string
            ;// so we have to ...

            .REPEAT
                xor edx, edx
                ;// check fpu use, fpu use will be zero for end of string
                ;// check exe space
                movzx eax, [esi].eLen
                .IF eax < [ebx].e_remain
                    inc edx
                .ENDIF
                invoke EnableWindow, [esi].hWnd, edx
                add esi, SIZEOF EQU_ELEMENT
            .UNTIL esi == OFFSET equ_element_close

            jmp do_close

        .ENDIF

    .ENDIF

    ;// if we hit this, bops are not allowed

    xor edi, edi
    .REPEAT
        invoke EnableWindow, [esi].hWnd, edi
        add esi, SIZEOF EQU_ELEMENT
    .UNTIL esi == OFFSET equ_element_close

do_close:

    ;// close ')' doesn't have a command id
    add esi, SIZEOF EQU_ELEMENT

;// uops

    .IF dwFlags & QED_UOPS

        ;// we want to make sure each individgual uop does not
        ;// overflow the pos stack or the fpu
        ;// we also check if said instruction would make the exe too long

        ;// get the pre_buf for the current position
        ;// via the sub_buf

        mov edi, [ebx].pSub_buf
        movzx ecx, [ebx].curPos
        movzx ecx, (EQU_SUBBUF PTR [edi+ecx*2]).i_tok
        DEBUG_IF <ecx==0FFh>    ;// not supposed to happen
        mov edi, [ebx].pPre_buf
        lea edi, [edi+ecx*2]
        ASSUME edi:PTR EQU_PREBUF
        .IF [edi].POS < EQU_MAX_POS_DLG

            .REPEAT
                xor edx, edx
                ;// check fpu use
                mov al, [edi].FPU
                .IF al < [esi].fpu
                    ;// check exe space
                    movzx eax, [esi].eLen
                    .IF eax < [ebx].e_remain
                        inc edx
                    .ENDIF
                .ENDIF
                invoke EnableWindow, [esi].hWnd, edx
                add esi, SIZEOF EQU_ELEMENT
            .UNTIL esi == OFFSET equ_element_end

            jmp do_delete

        .ENDIF

    .ENDIF

    ;// if we hit this, uops are not allowed

    xor edi, edi
    .REPEAT
        invoke EnableWindow, [esi].hWnd, edi
        add esi, SIZEOF EQU_ELEMENT
    .UNTIL esi == OFFSET equ_element_end


;// then hit del, back space, and up down
do_delete:

    invoke GetDlgItem, hWnd, ID_EQU_BACK
    xor edx, edx
    .IF dwFlags & QED_BACKSPACE
        inc edx
    .ENDIF
    invoke EnableWindow, eax, edx

    invoke GetDlgItem, hWnd, ID_EQU_DEL
    xor edx, edx
    .IF dwFlags & QED_DELETE
        inc edx
    .ENDIF
    invoke EnableWindow, eax, edx


;// that should do it

    ret

equ_EnableDialog ENDP


ASSUME_AND_ALIGN


ENDIF   ;// USE_THIS_FILE

END

