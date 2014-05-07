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
;//         -- label_Write was not terminating saved string, causes mysterious bugs elswhere
;//
;//##////////////////////////////////////////////////////////////////////////
;//
;// ABox_Label.asm
;//
;//
;// TOC
;// label_Ctor
;// label_Dtor
;// label_Calc
;// label_Render
;// label_SetShape
;// label_Move
;// label_InitMenu
;// label_Command
;// label_LoadUndo
;// label_AddExtraSize
;// label_Write
;//
;// label_proc
;// label_wm_setfocus_proc
;// label_wm_killfocus_proc
;// label_wm_exitsizemove_proc
;// label_wm_nchittest_proc
;// label_wm_mouseactivate_proc

OPTION CASEMAP:NONE

.586
.MODEL FLAT

USE_THIS_FILE equ 1

IFDEF USE_THIS_FILE

        .NOLIST
        include <Abox.inc>
        include <groups.inc>
        .LIST


comment ~ /*

    NOTES:  the label works like this:

        osc.string.pText stores the pointer to allocated text
        this is re allocated if the text gets larger due to editing
        the length of the lext is stored in osc.string.text_len

        pContainer stores a DIB_CONTAINER
        this holds the bitmap for when the editor is OFF

        there is a common editor, shared by all labels
        label_Move activates the editor

        the editor is accessed by making it visible and setting the focus
        when this happens,
            the label's text is copied to the edit window

        when the editor is deactivated (by loosing focus)
        if the text has changed,
            it is copied back to the label,
            reallocting string space as required

        if the user resizes or moves the editor
            the dib_container may be resized as well

        label text is stored in allocated memory, pointed at by string.pText

    object behavior:

        if user clicks and drags, it does NOT call up the editor

            this is managed by checking the return pointer in label_Move
            if it is mouse_move_osc_return_ptr
                label_moved is increased

        if user clicks and let's up, it DOES call up the editor

            this is also managed by checking the return pointer in label_Move
            if it is mouse_done_move_return_ptr
                label_moved is checked for zero (and reset in the process)
                if label_moved was zero the editor is sommoned

    editor behavior:

        if the editor is visible, it is on.
        if user clicks on editor, and drags, it moves the object
        if user resizes the edit box, it resizes the object

    unredo is implemented by set and kill focus


*/ comment ~


.DATA


    ;// private data for the label

    OSC_LABEL STRUCT

        pText       dd  0   ;// pointer to the allocated text block
        text_len    dd  0   ;// length of the text

    OSC_LABEL ENDS



osc_Label OSC_CORE { label_Ctor,label_Dtor,,label_Calc }

          OSC_GUI { label_Render,label_SetShape,
                    ,,label_Move,
                    label_Command,label_InitMenu,
                    label_Write,label_AddExtraSize,
                    osc_SaveUndo, label_LoadUndo }

          OSC_HARD { }

    BASE_FLAGS = BASE_BUILDS_OWN_CONTAINER OR BASE_SHAPE_EFFECTS_GEOMETRY

    OSC_DATA_LAYOUT {NEXT_Label,IDB_LABEL,OFFSET popup_LABEL,BASE_FLAGS,
        0,4,
        SIZEOF OSC_OBJECT,
        SIZEOF OSC_OBJECT,
        SIZEOF OSC_OBJECT + SIZEOF OSC_LABEL }

    OSC_DISPLAY_LAYOUT {,,ICON_LAYOUT(10,0,3,5) }

    ;// flags for dwUser

        ;//LABEL_KEEP_GROUP EQU 00000001h   ;// keep this label in a group
        ; defined in groups.inc



        ;// LABEL_TRANSPARENT   EQU 00000002h   ;// make this label immune to moving


    ;// short name and description

        short_name  db  'Label',0
        description db  'Simple text editor for notating circuitry.',0
        ALIGN 4

    ;// sizes

        LABEL_DEFAULT_SIZ_X equ 128
        LABEL_DEFAULT_SIZ_Y equ 64

        LABEL_MIN_X equ 12  ;// we don't allow smaller
        LABEL_MIN_Y equ 12  ;// we don't allow smaller

        LABEL_TAB_CHARS equ 3

    ;// the label shares ONE edit window for all instances
    ;// this is where it is

        label_OldProc   dd  0   ;// orig proc for the label

        label_hWnd      dd  0   ;// the common editorwindow
        label_pObject   dd  0   ;// set when an osc get's control

        label_border_cx dd  0   ;// width of the edit window border
        label_border_cy dd  0   ;// height of the edit window border

        label_moved     dd  0   ;// set true if user has moved the label

        label_proc PROTO    ;//  STDCALL hWnd:dword, msg:dword, wParam:dword, lParam:dword

        LABEL_STYLE equ WS_CHILD + WS_CLIPSIBLINGS + WS_THICKFRAME + \
                        ES_LEFT + ES_AUTOVSCROLL + ES_MULTILINE + ES_WANTRETURN


    ;// OSC_MAP for this object

        OSC_MAP STRUCT

                    OSC_OBJECT  {}
            string  OSC_LABEL   {}

        OSC_MAP ENDS









.CODE


;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
label_create_editor PROC uses ebx

        ASSUME esi:PTR OSC_MAP

    ;// for the label, we have a common edit window
    ;// we set that up right here

        DEBUG_IF <label_OldProc>    ;// supposed to check this first

    ;// create the lable window

        invoke CreateWindowExA,
            WS_EX_NOPARENTNOTIFY, ;// + WS_EX_TRANSPARENT,
            OFFSET szEdit,
            0,
            LABEL_STYLE,
            0,  0,
            LABEL_DEFAULT_SIZ_X,    LABEL_DEFAULT_SIZ_X,
            hMainWnd,
            0,
            hInstance,
            0
        mov label_hWnd, eax     ;// save the hWnd

    ;// set the font

        invoke PostMessageA,eax, WM_SETFONT, hFont_label, 0

    ;// set the tab stops this is complicated,
    ;// we have to convert from average character widths to dialog units
    ;// to be able to do that, we have to have a DC with the appropriate font

        sub esp, SIZEOF TEXTMETRICA

        OSC_TO_CONTAINER esi, ecx
        DEBUG_IF <!![ecx].shape.hDC>    ;// supposed to be allocated by now !!
        invoke GetTextMetricsA, [ecx].shape.hDC, esp

        invoke GetDialogBaseUnits
        and eax, 0FFFFh
        mov ecx, eax

        ;//                         4 * average * tab_chars
        ;// then, dialog units =    -----------------------
        ;//                                 base_x

        mov eax, (TEXTMETRICA PTR [esp]).dwAveCharWidth
        add esp, SIZEOF TEXTMETRICA

        imul eax, LABEL_TAB_CHARS   ;// average * tab_chars
        shl eax, 2                  ;// 4 * average * tab_chars
        xor edx, edx
        div ecx                     ;// dialog units

        ;// then set the tab stops
        add eax, 3  ;// <-- kludge !! the damn formula is still wrong !!
        push eax
        invoke SendMessageA, label_hWnd, EM_SETTABSTOPS, 1, esp
        add esp, 4

    ;// subclass the window

        invoke SetWindowLongA,  label_hWnd, GWL_WNDPROC, OFFSET label_proc
        mov label_OldProc, eax  ;// save the old window proc

    ;// get the border size

        invoke GetSystemMetrics, SM_CXFRAME
        mov label_border_cx, eax

        invoke GetSystemMetrics, SM_CYFRAME
        mov label_border_cy, eax

    ;// that should do it

        ret

label_create_editor ENDP






;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////



ASSUME_AND_ALIGN
label_Ctor PROC

        ;// register call
        ASSUME ebp:PTR LIST_CONTEXT ;// preserve
        ASSUME esi:PTR OSC_MAP      ;// preserve
        ASSUME edi:PTR OSC_BASE     ;// may destroy
        ASSUME ebx:PTR FILE_OSC     ;// may destroy
        ASSUME edx:PTR FILE_HEADER  ;// may destroy

    push ebx    ;// save the file pointer
    push edx    ;// save the file header pointer

    st_fileheader   TEXTEQU <(DWORD PTR [esp])>

    ;// check if we'e being initialized from a file
    ;// if we are then retrieve our initial window size

        .IF st_fileheader   ;// loaded from file

            mov edx, DWORD PTR [ebx+SIZEOF FILE_OSC+8]  ;// get the size.y
            mov ebx, DWORD PTR [ebx+SIZEOF FILE_OSC+4]  ;// get the size.x

        .ELSE           ;// not being loaded from file

            mov ebx, LABEL_DEFAULT_SIZ_X
            mov edx, LABEL_DEFAULT_SIZ_Y

        .ENDIF

    ;// allocate the container

        invoke dib_Reallocate, DIB_ALLOCATE_SHAPE, ebx, edx
        mov [esi].pContainer, eax
        mov ebx, eax
        ASSUME ebx:PTR DIB_CONTAINER

    ;// set up the rest of the DC

        mov eax, oBmp_palette[COLOR_OSC_TEXT*4]
        BGR_TO_RGB eax
        invoke SetTextColor, [ebx].shape.hDC, eax
        invoke SetBkMode, [ebx].shape.hDC, TRANSPARENT
        invoke SelectObject, [ebx].shape.hDC, hFont_label

    ;// then make sure the editor is created

        .IF !label_OldProc  ;// make sure the editor exists
            invoke label_create_editor
        .ENDIF

    ;// allocate storage for the text
    ;// we check again if we're being loaded from a file

    pop edx ;// retrieve the file header
    pop ebx ;// retrieve the file osc
    st_fileheader   TEXTEQU <>
    ASSUME ebx:PTR FILE_OSC

        .IF edx                 ;// loading from file ?
        mov eax, [ebx].extra
        sub eax, 12     ;// anything to left ?
        jbe @F
            add eax, 3
            and eax, -4
            invoke memory_Alloc, GPTR, eax  ;// allocate memory
            mov [esi].string.pText, eax     ;// store in object
            lea ecx, [ebx+(SIZE FILE_OSC) + (SIZEOF POINT) + 4] ;// 4 more for dwUser
            STRCPY eax, ecx, d              ;// copy the text
        @@:
        .ENDIF

    ;// the we check if we need to clear the old bits
    ;// older versions of label would store the text pointer in dwUser
    ;// rather than go to all the trouble to do an xlater
    ;// we'll just test for bits we haven't used yet

        .IF [esi].dwUser & 0FFFFFF00h

            mov [esi].dwUser, 0

        .ENDIF

    ;// that's it
    ;// set shape will render the text

        ret

label_Ctor ENDP



ASSUME_AND_ALIGN
label_Dtor PROC

        ASSUME esi:PTR OSC_MAP

    ;// detroy our text

        .IF [esi].string.pText
            invoke memory_Free, [esi].string.pText
        .ENDIF

    ;// destroy our dib
        mov eax, [esi].pContainer
        .IF eax

            invoke dib_Free, eax

        .ENDIF

    ;// that's it

        ret

label_Dtor ENDP




ASSUME_AND_ALIGN
label_Calc PROC ;// STDCALL pObject:PTR OSC_OBJECT

    ;// that's it

    DEBUG_IF    <esi>   ;// this should never be called

label_Calc ENDP




ASSUME_AND_ALIGN
label_Render    PROC

    ASSUME esi:PTR OSC_OBJECT

    ;// if we are being edited, do not render
    .IF esi != label_pObject

        ;// always check if the dib is going to need clipped
        ;// otherwise the shape_Fill/Move functions will explode

        point_GetBR [esi].rect

        and [esi].dwHintOsc, NOT HINTOSC_RENDER_CLOCKS

        .IF [esi].rect.left > 0     && \
            [esi].rect.top > 0      && \
            eax < gdi_bitmap_size.x && \
            edx < gdi_bitmap_size.y

            xor ecx, ecx
            .IF esi == osc_hover

                or [esi].dwHintOsc, HINTOSC_RENDER_OUT1

            .ENDIF

            or ecx, [esi].dwHintOsc
            .IF SIGN?

                invoke gdi_render_osc

            .ENDIF

        .ELSE

            ;// eax and edx are already loaded

            point_SubTL [esi].rect
            OSC_TO_CONTAINER esi, ecx

            invoke BitBlt, gdi_hDC,
                [esi].rect.left, [esi].rect.top,
                eax, edx,
                [ecx].shape.hDC, 0, 0, SRCCOPY

        .ENDIF

    .ENDIF

    ret

label_Render    ENDP



ASSUME_AND_ALIGN
label_SetShape  PROC

        ASSUME esi:PTR OSC_MAP

    push ebx

        OSC_TO_CONTAINER esi, ebx

    ;// always make sure that pSource is correct

        mov eax, [ebx].shape.pSource
        mov [esi].pSource, eax

    ;// our job here is to define the dib
    ;// the label editor takes care of resizing,
    ;// so all we need to do is draw our text

    ;// if label is empty, fill border

        xor ecx, ecx
        or ecx, [esi].string.pText  ;// get the string pointer
        ASSUME ecx:PTR BYTE
        jz draw_border          ;// jump if buffer is not allocated
        cmp [ecx], 0            ;// check for empty string
        jz draw_border          ;// jump if it was empty

    draw_text:                  ;// draw the text

        ;// fill with background color

            mov eax, F_COLOR_OSC_BACK
            invoke dib_Fill

        ;// build of formatting rect on the stack

            push [ebx].shape.siz.y
            push [ebx].shape.siz.x
            pushd 0
            pushd 0
            mov edx, esp            ;// edx is the rect pointer
            ASSUME edx:PTR RECT

            mov ecx, [esi].string.pText ;// get the text pointer again

        ;// resize the rect for the border

            mov eax, label_border_cx
            inc eax
            add [edx].left,eax
            sub [edx].right, eax

            mov eax, label_border_cy

            add [edx].top, eax
            sub [edx].bottom, eax

        ;// create and initialize a dtParams struct to work with

            pushd 0 ;// mov dtParam.dwLengthDrawn,0
            pushd 0 ;// mov dtParam.dwRightMargin,0
            pushd 0 ;// mov dtParam.dwLeftMargin, 2
            pushd LABEL_TAB_CHARS ;// mov dtParam.dwTabLength, 3    ;// number of characters
            pushd SIZEOF DRAWTEXTPARAMS ;// mov dtParam.cbSize, sizeof  DRAWTEXTPARAMS

        ;// call DrawTextExA to do the dirty work

            invoke DrawTextExA,
                [ebx].shape.hDC,    ;// [edi].hDC,
                ecx,                ;// textPtr,
                -1,                 ;// length
                edx,                ;// ADDR rect2,
                DT_EDITCONTROL + DT_NOPREFIX + DT_WORDBREAK + DT_EXPANDTABS + DT_TABSTOP,
                esp                 ;// ADDR dtParam

        ;// clean up the stack and exit to osc_SetShape

            add esp, SIZEOF DRAWTEXTPARAMS + SIZEOF RECT
            pop ebx
            jmp osc_SetShape


    draw_border:

        ;// draw a border around this empty label

        mov eax, F_COLOR_OSC_BACK
        mov edx, F_COLOR_OSC_TEXT
        invoke dib_FillAndFrame

    ;// exit to osc_SetShape

        pop ebx
        jmp osc_SetShape

    ;// that should do it


label_SetShape  ENDP



ASSUME_AND_ALIGN
label_Move  PROC

        ASSUME esi:PTR OSC_OBJECT
        ASSUME ebp:PTR LIST_CONTEXT

        EXTERNDEF mouse_move_osc_return_ptr:NEAR
        EXTERNDEF mouse_done_move_return_ptr:NEAR

        mov eax, [esp]  ;// get the return pointer

        cmp eax, OFFSET mouse_move_osc_return_ptr
        jne J1

    J0: ;// we are moving the osc, and we are osc_down

        test app_bFlags, APP_MODE_MOVING_OSC
        jz osc_Move

        inc label_moved
        jmp osc_Move

    J1: cmp eax, OFFSET mouse_done_move_return_ptr
        jne osc_Move

        ;// we are done moving the osc, and we are osc_down

        xor eax, eax
        xchg label_moved, eax   ;// load and clear label_moved
        or eax, eax             ;// was it zero ?
        jnz osc_Move

        ;// launch editor

        ;// define the rectangle to show at
        ;// set the label object and launch the editor

        push ebx

            point_GetTL [esi].rect, eax, ebx    ;// get tl
            point_GetBR [esi].rect, ecx, edx    ;// get br

            sub ecx, eax            ;// subtract to get width
            sub edx, ebx            ;// subtract to get height
            sub eax, GDI_GUTTER_X   ;// subtract to put in window coords
            sub ebx, GDI_GUTTER_Y   ;// subtract to put in window coords

            ;//add ecx, label_border_cx
            ;//sub eax, label_border_cx

            invoke MoveWindow, label_hWnd, eax, ebx, ecx, edx, 0

            mov label_pObject, esi      ;// set the object AFTER we move everything
            invoke ShowWindow, label_hWnd, SW_SHOWNORMAL
            invoke SetFocus, label_hWnd

        pop ebx

        ret ;// return now, don't move osc


label_Move  ENDP




ASSUME_AND_ALIGN
label_InitMenu PROC

    ASSUME esi:PTR OSC_MAP

    .IF !pGroupObject

        invoke GetDlgItem, popup_hWnd, IDC_LABEL_KEEP_GROUP
        invoke EnableWindow, eax, 0

    .ELSEIF [esi].dwUser & LABEL_KEEP_GROUP

        invoke CheckDlgButton, popup_hWnd, IDC_LABEL_KEEP_GROUP, BST_CHECKED

    .ENDIF

    ;//.IF [esi].dwUser & LABEL_TRANSPARENT
    ;//
    ;// invoke CheckDlgButton, popup_hWnd, IDC_LABEL_TRANSPARENT, BST_CHECKED
    ;//
    ;//.ENDIF

    xor eax, eax

    ret

label_InitMenu ENDP


ASSUME_AND_ALIGN
label_Command PROC

    ASSUME esi:PTR OSC_MAP

    cmp eax, IDC_LABEL_KEEP_GROUP
    jne osc_Command

    xor [esi].dwUser, LABEL_KEEP_GROUP
    or app_bFlags, APP_SYNC_GROUP

    mov eax, POPUP_SET_DIRTY

    ret

label_Command ENDP




;////////////////////////////////////////////////////////////////////
;//
;//
;//     _LoadUndo
;//

ASSUME_AND_ALIGN
label_LoadUndo PROC

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

        ret

label_LoadUndo ENDP

;//
;//
;//     _LoadUndo
;//
;////////////////////////////////////////////////////////////////////








ASSUME_AND_ALIGN
label_AddExtraSize PROC

    ASSUME esi:PTR OSC_MAP
    ASSUME ebx:PTR DWORD

    ;// determine the number of bytes to save

        xor edx, edx
        xor eax, eax
        or edx, [esi].string.pText
        .IF !ZERO?
            STRLEN edx, eax
        .ENDIF

        ;// size of text + null + sizeof point + size of int
        ;//  eax         +  1   +  8           +  4

        add eax, 13

        add [ebx],eax   ;// accumulate to passed pointer

    ;// that's it

        ret

label_AddExtraSize ENDP





ASSUME_AND_ALIGN
label_Write PROC    ;// STDCALL uses esi edi pObject:PTR OSC_OBJECT, pFile:ptr FILE_OSC

    ASSUME esi:PTR OSC_MAP      ;// preserve
    ASSUME edi:PTR FILE_OSC     ;// iterate
    ;// ebx is destroyed

    ;// this is called AFTER the pBase and position have been written
    ;// and BEFORE the pin table is written
    ;// our job is to store our extra count, dwUser, size, and text
    ;// we MUST iterate edi in the process

    ;// write our stuff

    ;// determine the number of bytes to save

        xor eax, eax
        mov [edi].extra, eax        ;// clear the extra count
        lea ebx, [edi].extra        ;// point to it
        invoke label_AddExtraSize   ;// call this to set the size

    ;// save something for dw user

        add edi, SIZEOF FILE_OSC    ;// advance to dword user

        mov eax, [esi].dwUser   ;// load current dwUser
        stosd                   ;// store and iterate

    ;// determine and save our window size
    ;// we can get this from our container

        OSC_TO_CONTAINER esi, ebx   ;// get container
        point_Get [ebx].shape.siz   ;// get the size
        stosd                       ;// store width and iterate
        mov eax, edx                ;// move height to width
        stosd                       ;// store height and iterate

    ;// copy the text

        mov edx, [esi].string.pText ;// make sure there is something to save
        .IF edx
            STRCPY edi, edx
        .ENDIF

        xor eax, eax    ;// always terminate !! ABOX242 AJT
        stosb
        ;//inc edi


    ;// that's it

        ret



label_Write ENDP



















;////////////////////////////////////////////////////////////////////
;//
;//
;//     label editor stuff
;//




ASSUME_AND_ALIGN
label_proc PROC PRIVATE     ;// STDCALL uses esi edi ebx hWnd:dword, msg:dword, wParam:dword, lParam:dword

    mov eax, WP_MSG

    HANDLE_WM WM_SETFOCUS,      label_wm_setfocus_proc
    HANDLE_WM WM_KILLFOCUS,     label_wm_killfocus_proc
    HANDLE_WM WM_EXITSIZEMOVE,  label_wm_exitsizemove_proc  ;// make sure dib shape get's updated
    HANDLE_WM WM_NCHITTEST,     label_wm_nchittest_proc     ;// this is how we move the editor
    HANDLE_WM WM_MOUSEACTIVATE, label_wm_mouseactivate_proc ;// intercept or mainwnd will shut off
    HANDLE_WM WM_GETMINMAXINFO, label_wm_getminmaxinfo_proc ;// enforces minimum size

label_proc_exit::

    SUBCLASS_DEFPROC label_OldProc

    ret 10h

label_proc ENDP





ASSUME_AND_ALIGN
label_wm_setfocus_proc PROC PRIVATE ;// STDCALL PRIVATE hWnd:DWORD, msg:DWORD, wParam:DWORD, lParam:DWORD

    ;// we're being activated

        xor ecx, ecx
        GET_OSC_MAP_FROM edx, label_pObject
        DEBUG_IF <!!edx>

        or ecx, [edx].string.pText  ;// get and test the string buffer
        .IF !ZERO?
            EDITBOX label_hWnd, WM_SETTEXT,0,ecx    ;// set text using what's in the buffer
        .ELSE
            push ecx
            EDITBOX label_hWnd, WM_SETTEXT,0,esp    ;// set text to the null string
            add esp, 4
        .ENDIF

        EDITBOX label_hWnd, EM_SETMODIFY            ;// always clear the modify flag

        or app_DlgFlags, DLG_LABEL

        ;// then we setup uredo data

        unredo_BeginAction UNREDO_EDIT_LABEL

        jmp label_proc_exit


label_wm_setfocus_proc ENDP

PROLOGUE_OFF
ASSUME_AND_ALIGN
label_set_text PROC STDCALL pObject:DWORD, pText:DWORD, len:DWORD

        push ebx
        push esi
        push ebp

    ;// stack
    ;// ebp esi ebx ret osc txt len
    ;// 00  04  08  0C  10  14  18

        st_osc TEXTEQU <(DWORD PTR [esp+10h])>
        st_txt TEXTEQU <(DWORD PTR [esp+14h])>
        st_len TEXTEQU <(DWORD PTR [esp+18h])>

    ;// if txt < 10000h, then txt is an hWnd

        GET_OSC_MAP_FROM esi, st_osc
        DEBUG_IF <!!esi>    ;// how does this happen ??
        stack_Peek gui_context, ebp

        mov ebx, st_txt

        invoke IsWindow, ebx
        .IF eax

        ;// .IF ebx < 10000h

            ;// check if we need to reallocate

            invoke GetWindowTextLengthA, ebx    ;// get the length
            inc eax                             ;// bump for nul term
            .IF eax > [esi].string.text_len         ;// bigger now ?

                mov [esi].string.text_len, eax      ;// store the size in the object
                add eax, 3
                and eax, -4
                push eax                    ;// save size as parameter
                .IF [esi].string.pText      ;// check for previously allocated
                    invoke memory_Free, [esi].string.pText ;// free it
                .ENDIF
                pushd GPTR                  ;// push the second parameter
                call memory_Alloc           ;// allocate memory
                mov [esi].string.pText, eax ;// store in object

            .ENDIF

            ;// get the new text
            invoke GetWindowTextA, ebx, [esi].string.pText, [esi].string.text_len

        .ELSE   ;// txt is a pointer to text, len must be valid

            mov eax, st_len
            DEBUG_IF <!!eax>
            .IF eax > [esi].string.text_len         ;// bigger now ?

                mov [esi].string.text_len, eax      ;// store the size in the object
                add eax, 3
                and eax, -4
                push eax                    ;// save size as parameter
                .IF [esi].string.pText      ;// check for previously allocated
                    invoke memory_Free, [esi].string.pText ;// free it
                .ENDIF
                pushd GPTR                  ;// push the second parameter
                call memory_Alloc           ;// allocate memory
                mov [esi].string.pText, eax ;// store in object

            .ENDIF

            mov ecx, st_len
            push esi
            push edi
            mov edi, [esi].string.pText
            mov esi, ebx
            rep movsb
            pop edi
            pop esi

        .ENDIF

        GDI_INVALIDATE_OSC HINTI_OSC_SHAPE_CHANGED

    ;// clean up and split

        pop ebp
        pop esi
        pop ebx
        ret 12

label_set_text ENDP
PROLOGUE_ON

ASSUME_AND_ALIGN
label_wm_killfocus_proc PROC PRIVATE ;// STDCALL PRIVATE hWnd:DWORD, msg:DWORD, wParam:DWORD, lParam:DWORD

    ;// update the display dib's contents
    ;// hide edit window

    EDITBOX label_hWnd, EM_GETMODIFY
    or eax, eax
    jz hide_and_exit

    ;// need to reassign the edit text

        invoke label_set_text, label_pObject, label_hWnd, 0

    hide_and_exit:

        unredo_EndAction UNREDO_EDIT_LABEL

        invoke ShowWindow, label_hWnd, SW_HIDE
        mov label_pObject, 0
        and app_DlgFlags, NOT DLG_LABEL

    ;// that's it
    jmp label_proc_exit

label_wm_killfocus_proc ENDP


PROLOGUE_OFF
ASSUME_AND_ALIGN
label_set_size PROC STDCALL pObject:DWORD, pRect:DWORD

        push esi
        push ebx

        sub esp, SIZEOF POINT

        ;// stack
        ;// X   Y   ebx esi ret osc rect
        ;// 00  04  08  0C  10  14  18

        st_size TEXTEQU <(POINT PTR [esp])>
        st_osc  TEXTEQU <(DWORD PTR [esp+14h])>
        st_prect TEXTEQU <(DWORD PTR [esp+18h])>

    ;// determine if size has changed

        GET_OSC_FROM esi, st_osc
        mov ebx, st_prect
        ASSUME ebx:PTR RECT

        point_GetBR [ebx]
        OSC_TO_CONTAINER esi, ecx
        point_SubTL [ebx]
        point_Set st_size           ;// store back, since we may need it in next test

        .IF eax != [ecx].shape.siz.x || \
            edx != [ecx].shape.siz.y

            .IF eax < LABEL_MIN_X
                mov eax, LABEL_MIN_X
            .ENDIF
            .IF edx < LABEL_MIN_Y
                mov edx, LABEL_MIN_Y
            .ENDIF

            push edx                ;// height
            push eax                ;// width
            push ecx                ;// shape pointer
            call dib_Reallocate     ;// reallocate the bitmap

            or [esi].dwHintI, HINTI_OSC_SHAPE_CHANGED   ;// object must synchronize the new size

        .ENDIF

    ;// determine if position has changed

        point_GetTL [ebx]

        .IF eax != [esi].rect.left || \
            edx != [esi].rect.top

            point_SetTL [esi].rect
            point_Add st_size
            point_SetBR [esi].rect

            or [esi].dwHintI, HINTI_OSC_MOVED OR HINTI_OSC_SHAPE_CHANGED

        .ENDIF

    ;// see if we need to invalidate

        .IF [esi].dwHintI & (HINTI_OSC_MOVED OR HINTI_OSC_SHAPE_CHANGED)

            push ebp
            stack_Peek gui_context, ebp
            GDI_INVALIDATE_OSC HINTI_OSC_UPDATE
            pop ebp

        .ENDIF

    ;// clean up and split

        add esp, SIZEOF POINT
        pop ebx
        pop esi

        ret 8

label_set_size ENDP
PROLOGUE_ON


ASSUME_AND_ALIGN
label_wm_exitsizemove_proc  PROC PRIVATE

    xor ecx, ecx
    or ecx, label_pObject
    jz label_proc_exit

    sub esp, SIZEOF RECT
    st_rect TEXTEQU <(RECT PTR [esp])>

    invoke GetWindowRect, label_hWnd, esp
    mov edx, esp
    invoke MapWindowPoints, 0, hMainWnd, edx, 2

    add st_rect.left, GDI_GUTTER_X      ;// adjust for gutter
    add st_rect.top, GDI_GUTTER_Y       ;// adjust for gutter
    add st_rect.right, GDI_GUTTER_X     ;// adjust for gutter
    add st_rect.bottom, GDI_GUTTER_Y    ;// adjust for gutter

    invoke label_set_size, label_pObject, esp

    ;// that should do it

    add esp, SIZEOF RECT


    jmp label_proc_exit


label_wm_exitsizemove_proc ENDP




ASSUME_AND_ALIGN
label_wm_nchittest_proc PROC PRIVATE

    ;// if the editor is on we check if mouse is in client area
    ;// if it is, then we return HTCAPTION so that the window will move

    sub esp, SIZEOF RECT

;// stack looks like this
;// left    right   top     bottom  ret     hWnd    msg     wParam  lParam
;// 00      04      08      0Ch     10h     14h     18h     1Ch     20h

    st_rect TEXTEQU <(RECT PTR [esp])>

    invoke GetClientRect, label_hWnd, esp   ;// get the client rect
    point_DecBR st_rect

    movsx eax, WORD PTR [esp+20h]           ;// xfer mouse coord to TL
    movsx edx, WORD PTR [esp+22h]
    point_SetTL st_rect
    invoke ScreenToClient, label_hWnd, esp  ;// convert to hWnd coords

    xor eax, eax
    xor edx, edx

    or eax, [esp]
    js default_processing

    or edx, [esp+4]
    js default_processing

    cmp eax, [esp+8]
    ja default_processing

    cmp edx, [esp+0Ch]
    ja default_processing

    ;// we are inside the client area

    add esp, SIZEOF RECT
    mov eax, HTCAPTION
    ret 10h

default_processing:

    add esp, SIZEOF RECT
    jmp label_proc_exit


label_wm_nchittest_proc ENDP





ASSUME_AND_ALIGN
label_wm_mouseactivate_proc PROC

    ;// this prevent hMainWnd from getting this message
    ;// when user wants to resize the editor

    mov eax, MA_ACTIVATE
    ret 10h

label_wm_mouseactivate_proc ENDP


;// this enforces a min size

MIN_TRACK_SIZE_X EQU 256
MIN_TRACK_SIZE_Y EQU 256

ASSUME_AND_ALIGN
label_wm_getminmaxinfo_proc PROC PUBLIC

    mov ecx, WP_LPARAM
    ASSUME ecx:PTR MINMAXINFO

    mov eax, label_border_cx
    mov edx, label_border_cy

    lea eax, [eax*2+FONT_LABEL+1]
    lea edx, [edx*2+FONT_LABEL+1]

    mov [ecx].ptMinTrackSize.x, eax
    mov [ecx].ptMinTrackSize.y, edx

    xor eax, eax
    ret 10h

label_wm_getminmaxinfo_proc ENDP








ASSUME_AND_ALIGN

ENDIF   ;// USE_THIS_FILE
END


