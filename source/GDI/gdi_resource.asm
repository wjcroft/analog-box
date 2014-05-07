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
;// Gdi_resource.asm        data and routines for the resources
;//
;//
;// TOC
;//
;// gdi_PreInitialize PROC STDCALL
;// gdi_Initialize PROC PUBLIC
;// gdi_Destroy PROC    ;//  STDCALL
;// gdi_AllocateAllResources PROC
;// gdi_DestroyAllResources PROC


OPTION CASEMAP:NONE

.586
.MODEL FLAT

        .NOLIST
        include <Abox.inc>
        include <triangles.inc>
        .LIST

.DATA

    ;//
    ;// common resources
    ;//

    ;// cursors

        hCursor_normal  dd  0   ;// just the normal cursor
        hCursor_bad     dd  0   ;// used in the bus drag drop

    ;// fonts

        hFont_pin        dd 0   ;// font for pin lables
        hFont_help       dd 0   ;// font for help text
        hFont_popup      dd 0   ;// font for popup text
        hFont_osc        dd 0   ;// font for oscillators and busses
        hFont_huge       dd 0   ;// font for big text
        hFont_label      dd 0   ;// font for lables

    ;// brushes

        hBrush_null dd  0
        hPen_null   dd  0

    ;// pens

        hPen_dot    dd  0

    ;//
    ;//     gdi_resource table
    ;//


        gdi_resource LABEL GDI_WRAPPER

        COLORS_ASM TEXTEQU <YES>

        include <colors.inc>


    ;// these track the current
    ;// GDI_DC_SELECT macro to help out

        gdi_current_brush       dd 0
        gdi_current_pen         dd 0
        gdi_current_font        dd 0
        gdi_current_color_ind   dd 0

    ;// private protos

        gdi_AllocateAllResources PROTO
        gdi_DestroyAllResources PROTO

    ;// strings

        szArial       db 'Arial', 0 , 0, 0  ;// pad to eight bytes

    ;// private functions

        gdi_BuildButtonBitmaps  PROTO PRIVATE
        gdi_DestroyButtonBitmaps    PROTO PRIVATE




.CODE


ASSUME_AND_ALIGN
gdi_PreInitialize PROC STDCALL uses ebx

    ;// this builds enough stuff to be able to show the splash screen

        LOCAL lFont:LOGFONT

    ;// determine the size of the desktop


    ;// ABOX 238
    ;//     finally figured out why some pc's have wacky screens
    ;//     it's due to having task bar on the side
    ;//     and hence a non-mul 4 screen width

        invoke GetSystemMetrics, SM_CXSCREEN
            ;// ABOX240, hah, sizes may still be wrong (non 4x)
            ;// see if this works
            add eax, 3
            and eax, NOT 3
        mov gdi_desk_size.x, eax


        invoke GetSystemMetrics, SM_CYSCREEN
        mov gdi_desk_size.y, eax

    ;// build all the fonts

        xor eax, eax
        mov lFont.lfWidth, eax
        mov lFont.lfEscapement, eax
        mov lFont.lfOrientation, eax
        mov lFont.lfWeight, 400
        mov lFont.lfItalic, al
        mov lFont.lfUnderline, al
        mov lFont.lfStrikeOut, al
        mov lFont.lfCharSet, al
        mov lFont.lfOutPrecision, al
        mov lFont.lfClipPrecision, al
        mov lFont.lfQuality, al
        mov lFont.lfPitchAndFamily, al
        invoke lstrcpyA, ADDR lFont.lfFaceName, OFFSET szArial

    ;// application fonts

        lea ebx, lFont

        mov lFont.lfHeight, FONT_PIN
        invoke CreateFontIndirectA, ebx
        mov hFont_pin, eax

        mov lFont.lfHeight, FONT_POPUP
        invoke CreateFontIndirectA, ebx
        mov hFont_popup, eax

        mov lFont.lfHeight, FONT_BIG
        invoke CreateFontIndirectA, ebx
        mov hFont_help, eax

        mov lFont.lfWeight, 700
        invoke CreateFontIndirectA, ebx
        mov hFont_osc, eax

        mov lFont.lfHeight, FONT_HUGE
        invoke CreateFontIndirectA, ebx
        mov hFont_huge, eax

        mov lFont.lfHeight, FONT_LABEL
        ;// mov lFont.lfWeight, 700
        invoke CreateFontIndirectA, ebx
        mov hFont_label, eax

    ;// that's it

        ret

gdi_PreInitialize ENDP


ASSUME_AND_ALIGN
gdi_Initialize PROC PUBLIC

    ;// this is called to initialize the rest of the gdi

    ;// 1)  initialize the DIB system

        invoke about_SetLoadStatus

        invoke dib_Initialize   ;// eax returns with the BITMAP info struct

    ;// 2) allocate and load the reference palette
    ;//     we'll convert all entries to hsv to save some hassle later

        invoke about_SetLoadStatus

        invoke memory_Alloc, GPTR, 256*4
        mov gdi_pRefPalette, eax
        lea esi, oBmp_palette
        mov edi, eax
        pushd 256                   ;// counter
        .REPEAT
            lodsd                   ;// load from main palette
            invoke gdi_rgb_to_hsv   ;// convert to hsv
            dec DWORD PTR [esp]     ;// decrease counter
            stosd                   ;// store in ref palette
        .UNTIL ZERO?
        add esp, 4                  ;// clean up

    ;// 3) define the geometry for the gdi_display surface
    ;// the desk size was filled in earlier by gdi_PreInitialize

        invoke about_SetLoadStatus

        mov eax, GDI_GUTTER_X
        mov edx, GDI_GUTTER_Y

        point_SetTL gdi_client_rect ;// set the client rect
        point_Add gdi_desk_size     ;// add the desktop size
        point_Add GDI_GUTTER        ;// add another gutter

        point_Set gdi_bitmap_size   ;// store as bitmap size

    ;// 4) allocate the main bitmap, and it's dc

        invoke dib_Reallocate, DIB_ALLOCATE, eax, edx
        mov gdi_pDib, eax
        mov ebx, eax
        ASSUME ebx:PTR DIB_CONTAINER

    ;// 5) define gdi_hDC, and pBits

        mov eax, [ebx].shape.hDC
        mov edx, [ebx].shape.pSource
        mov gdi_hDC, eax
        mov gdi_pBmpBits, edx

    ;// 6) finish defining the bit gutter address

        mov eax, GDI_GUTTER_Y       ;// load the height
        mul gdi_bitmap_size.x       ;// has total width
        add eax, GDI_GUTTER_X       ;// add one more for x offset
        add eax, [ebx].shape.pSource;// add on the source offset
        mov gdi_pBitsGutter, eax    ;// now bits gutter is the correct adress

    ;// 7) determine the delta width

        mov eax, gdi_bitmap_size.x
        sub eax, oBmp_bmih.biWidth
        mov gdi_bitmap_object_delta, eax

    ;// 7a determine the bottom displayable line

        mov eax, gdi_bitmap_size.y
        sub eax, GDI_GUTTER_Y
        mul gdi_bitmap_size.x
        add eax, gdi_pBmpBits
        mov gdi_pBmpBits_bottom, eax

    ;// 8) select appropriate resources

        invoke SetBkMode, gdi_hDC, TRANSPARENT

    ;// 8a) build the button bitmaps
    ;// do before gdi_AllocateAllResources
    ;// because it calls gdi_SyncButtonPalettes

        invoke gdi_BuildButtonBitmaps

    ;// 9) allocate the pens and brushes

        invoke about_SetLoadStatus

        invoke gdi_AllocateAllResources

    ;// 10) allocate gdi_temp and define all known shapes

        invoke about_SetLoadStatus

        invoke memory_Alloc, GPTR, GDI_TEMP_BUFFER_SIZE ;// should be enough
        mov gdi_temp_buffer, eax

        slist_GetHead shape_list, ebx
        .WHILE ebx
            invoke shape_Build
            slist_GetNext shape_list, ebx
        .ENDW

    ;// 11) allocate the triangles

        invoke about_SetLoadStatus

        invoke triangle_BuildTable

    ;// 12) make sure we have clock fonts

        invoke about_SetLoadStatus

        invoke clocks_Initialize

    ;//
    ;// that's it
    ;//

        ret

gdi_Initialize ENDP

;//////////////////////////////////////////////////////////////////////

;//////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
gdi_Destroy PROC    ;//  STDCALL

    ;// this is where we destroy everything we can

    invoke GetStockObject, NULL_PEN
    invoke SelectObject, gdi_hDC, eax
    invoke GetStockObject, NULL_BRUSH
    invoke SelectObject, gdi_hDC, eax



    ;// destroy all the shapes

    slist_GetHead shape_list, ebx
    .WHILE ebx
        invoke shape_Destroy
        slist_GetNext shape_list, ebx
    .ENDW

    ;// destroy everything else

    invoke dib_Destroy                  ;// destroy the bitmaps
    invoke memory_Free, gdi_temp_buffer ;// delete the temp buf
    invoke font_Destroy                 ;// destroy the fonts
    invoke triangle_Destroy             ;// destroy all the pins
    invoke memory_Free, gdi_pRefPalette ;// destroy the reference palette
    invoke gdi_DestroyButtonBitmaps     ;// destroy the button bitmaps
    invoke gdi_DestroyAllResources      ;// destroy resources we've created

    ;// that just might do it

    ret

gdi_Destroy ENDP

;//////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
gdi_AllocateAllResources PROC

    ;// load the cursors

        invoke LoadCursorA, 0, IDC_ARROW
        mov hCursor_normal, eax

        invoke LoadCursorA, 0, IDC_NO
        mov hCursor_bad, eax

    ;// the null brush and pen

        invoke GetStockObject, NULL_BRUSH
        mov hBrush_null, eax

        invoke GetStockObject, NULL_PEN
        mov hPen_null, eax

    ;// initialize the default color palette

        invoke gdi_BuildColorSet

    ;// that's it

        ret

gdi_AllocateAllResources ENDP


;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
gdi_DestroyAllResources PROC

    ;// delete the fonts

        invoke DeleteObject, hFont_pin
        DEBUG_IF <!!eax>
        invoke DeleteObject, hFont_help
        DEBUG_IF <!!eax>
        invoke DeleteObject, hFont_popup
        DEBUG_IF <!!eax>
        invoke DeleteObject, hFont_osc
        DEBUG_IF <!!eax>
        invoke DeleteObject, hFont_label
        DEBUG_IF <!!eax>
        invoke DeleteObject, hFont_huge

    ;// delete the pens

        invoke DeleteObject, hPen_dot
        DEBUG_IF <!!eax>

    ;// delete the wrapper objects

        mov esi, OFFSET gdi_resource    ;// lea esi, gdi_resource
        ASSUME esi:PTR GDI_WRAPPER
        xor edi, edi    ;// use for zero

        mov ebx, COLOR_SYSTEM_MAX
        .REPEAT

            cmp edi,[esi].hBrush
            je @F
            invoke DeleteObject, [esi].hBrush
            DEBUG_IF <!!eax>

        @@: cmp edi, [esi].hPen_1
            je @F
            invoke DeleteObject, [esi].hPen_1
            DEBUG_IF <!!eax>

        @@: cmp edi, [esi].hPen_3
            je @F
            invoke DeleteObject, [esi].hPen_3
            DEBUG_IF <!!eax>

        @@: add esi, SIZEOF GDI_WRAPPER
            dec ebx

        .UNTIL ZERO?


    ;// that should do it

        ret

gdi_DestroyAllResources ENDP

;//////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////
;///
;///    BUTTON BITMAPS      these are used by popup to show
;///                        bitmaps on buttons
;///


.DATA

    ;// layout parameters for edge/gate pin buttons displayed on popup
    ;// these parameters are needed to do a 2x blit from obmp to the button

    BUTTON_EDGEGATE_WIDTH           EQU PIN_LOGIC_RADIUS * 2 - 1
    BUTTON_EDGEGATE_HEIGHT          EQU PIN_LOGIC_RADIUS * 2 - 1

    BUTTON_EDGEGATE_LAST_LINE       EQU (BUTTON_EDGEGATE_HEIGHT-1) * oBmp_width
    BUTTON_EDGEGATE_RASTER          EQU BUTTON_EDGEGATE_WIDTH + oBmp_width
    BUTTON_EDGEGATE_DWORD_ALIGNER   EQU ((BUTTON_EDGEGATE_WIDTH*2+3) AND -4) - BUTTON_EDGEGATE_WIDTH*2

    ;// layout parameters for aligner buttons displayed on popup
    ;// these parameters are needed to do a 1x blit from obmp to the button

    BUTTON_ALIGNER_WIDTH            EQU 30
    BUTTON_ALIGNER_HEIGHT           EQU 30

    BUTTON_ALIGNER_LAST_LINE        EQU (BUTTON_ALIGNER_HEIGHT-1) * oBmp_width
    BUTTON_ALIGNER_RASTER           EQU BUTTON_ALIGNER_WIDTH + oBmp_width
    BUTTON_ALIGNER_DWORD_ALIGNER    EQU ((BUTTON_ALIGNER_WIDTH+3) AND -4) - BUTTON_ALIGNER_WIDTH

    ;// bitmap images for button_table
    ;// initialize these by pointing at the image
    ;// gdi_BuildButtonBitmaps converts these to handles
    ;// popup_BuildControls assigns these to buttons
    ;// see POPUP_TYPE_BUTTON for how to declare buttons

    ;// button_bitmaps_initialized dd 0

    button_bitmap_table LABEL DWORD

        ;// psource for pin buttons
        dd  TRIG_BOTH_PSOURCE   ;// 0
        dd  TRIG_POS_PSOURCE    ;// 1
        dd  TRIG_NEG_PSOURCE    ;// 2
        dd  GATE_POS_PSOURCE    ;// 3
        dd  GATE_NEG_PSOURCE    ;// 4

        dd  OUTPUT_BIPOLAR_PSOURCE  ;// 5
        dd  OUTPUT_DIGITAL_PSOURCE  ;// 6

        ;// psource for HID buttons not already covered

        dd  HID_CONTROL_OFF_PSOURCE     ;// 7
        dd  HID_CONTROL_POS_PSOURCE     ;// 8
        dd  HID_CONTROL_NEG_PSOURCE     ;// 9

        NUM_PIN_BUTTONS EQU 10

        ;// psource for align buttons
        dd  ALIGN_ICON_1B_PSOURCE   ;// 18  oops, got the object composite wrong
        dd  ALIGN_ICON_2B_PSOURCE   ;// 19  so we'll kludge it here by swapping banks
        dd  ALIGN_ICON_3B_PSOURCE   ;// 20
        dd  ALIGN_ICON_4B_PSOURCE   ;// 21
        dd  ALIGN_ICON_6B_PSOURCE   ;// 22
        dd  ALIGN_ICON_7B_PSOURCE   ;// 23
        dd  ALIGN_ICON_8B_PSOURCE   ;// 24
        dd  ALIGN_ICON_9B_PSOURCE   ;// 25
        dd  ALIGN_ICON_1A_PSOURCE   ;// 10
        dd  ALIGN_ICON_2A_PSOURCE   ;// 11
        dd  ALIGN_ICON_3A_PSOURCE   ;// 12
        dd  ALIGN_ICON_4A_PSOURCE   ;// 13
        dd  ALIGN_ICON_6A_PSOURCE   ;// 14
        dd  ALIGN_ICON_7A_PSOURCE   ;// 15
        dd  ALIGN_ICON_8A_PSOURCE   ;// 16
        dd  ALIGN_ICON_9A_PSOURCE   ;// 17

        dd  0   ;// terminator for list



.CODE

ASSUME_AND_ALIGN
gdi_BuildButtonBitmaps  PROC PRIVATE

    ;// destroys esi edi ebx ebp

        xor ebp, ebp    ;// counter

    ;// build a bitmap info header to work with

        pushd 10h   ;// biClrImportant  dd 0    10
        pushd 10h   ;// biClrUsed       dd 0    9
        pushd 100h  ;// biYPelsPerMeter dd 0    8
        pushd 100h  ;// biXPelsPerMeter dd 0    7
        pushd 0     ;// biSizeImage     dd 0    6
        pushd BI_RGB    ;// biCompression   dd 0    5
        pushd 80001h    ;// biBitCount      dw 0    4
        ;//pushd 1      ;// biPlanes        dw 0    3
        pushd BUTTON_EDGEGATE_WIDTH * 2 ;// biHeight        dd 0    2
        pushd BUTTON_EDGEGATE_WIDTH * 2 ;// biWidth         dd 0    1
        pushd 40    ;// biSize          dd 40   0

        st_width TEXTEQU <(DWORD PTR [esp+4])>
        st_height TEXTEQU <(DWORD PTR [esp+8])>

    ;// use esi to iterate the source ptr table
    ;// use ebx to point at GDI_SHAPES

        mov ebx, OFFSET button_bitmap_table
        ASSUME ebx:PTR DWORD

    top_of_loop:

        mov esi, [ebx]  ;// esi is the psource

    ;// allocate a dib

        xor eax, eax
        mov edx, esp
        push eax        ;// store ptr to bits
        mov ecx, esp

        invoke CreateDIBSection, gdi_hDC, edx, DIB_RGB_COLORS, ecx, eax, eax
        pop edi         ;// get ptr to the bits
        mov [ebx], eax  ;// store the handle
        DEBUG_IF <!!edi>

    ;// fill in the bits


        .IF ebp < NUM_PIN_BUTTONS

        ;// this is a pin edge/gate button
        ;// we're doing a 2x stretch
        ;// we also know that all the bitmaps are the same size
        ;// this little routine was surprising obnoxious to debug
        ;// do not overwrite gdi display memory

            add esi, BUTTON_EDGEGATE_LAST_LINE  ;// move esi to bottom of the icon

        ;// do a 2x blit

            mov edx, BUTTON_EDGEGATE_HEIGHT ;// Y counter
        L0: mov ecx, BUTTON_EDGEGATE_WIDTH  ;// X counter
            .REPEAT
                lodsb
                stosb
                dec ecx
                stosb
            .UNTIL ZERO?
            mov ecx, BUTTON_EDGEGATE_WIDTH
            add edi, BUTTON_EDGEGATE_DWORD_ALIGNER
            sub esi, ecx
            .REPEAT
                lodsb
                stosb
                dec ecx
                stosb
            .UNTIL ZERO?
            sub esi, BUTTON_EDGEGATE_RASTER
            add edi, BUTTON_EDGEGATE_DWORD_ALIGNER
            dec edx
            ja  L0

        .ELSE

            ;// this is an align button

            add esi, BUTTON_ALIGNER_LAST_LINE   ;// move esi to bottom of the icon

            ;// do a 1x blit

            mov edx, BUTTON_ALIGNER_HEIGHT  ;// Y counter
        L1: mov ecx, BUTTON_ALIGNER_WIDTH       ;// X counter
            rep movsb
            sub esi, BUTTON_ALIGNER_RASTER
            add edi, BUTTON_ALIGNER_DWORD_ALIGNER
            dec edx
            ja  L1

        .ENDIF

    ;// iterate

        inc ebp
        add ebx, 4
        .IF ebp == NUM_PIN_BUTTONS
            mov st_width, BUTTON_ALIGNER_WIDTH
            mov st_height, BUTTON_ALIGNER_HEIGHT
        .ENDIF
        cmp [ebx], 0
        jne top_of_loop

    ;// cleanup

        add esp, SIZEOF BITMAPINFOHEADER

    ;// exit

        ret

gdi_BuildButtonBitmaps  ENDP



ASSUME_AND_ALIGN
gdi_SyncButtonPalettes PROC

        push esi
        mov esi, OFFSET button_bitmap_table
        ASSUME esi:PTR DWORD
        push edi
        invoke CreateCompatibleDC, gdi_hDC
        mov edi, eax

        .REPEAT

            invoke SelectObject, edi, [esi]
            push eax
            invoke SetDIBColorTable, edi, 0, 32, OFFSET oBmp_palette
            push edi
            call SelectObject
            add esi, 4

        .UNTIL ![esi]
        invoke DeleteDC, edi
        pop edi
        pop esi

    ret

gdi_SyncButtonPalettes ENDP

ASSUME_AND_ALIGN
gdi_DestroyButtonBitmaps PROC

    mov esi, OFFSET button_bitmap_table
    ASSUME esi:PTR DWORD

    .REPEAT
        invoke DeleteObject, [esi]
        DEBUG_IF <!!eax>
        add esi, 4
    .UNTIL ![esi]

    ret

gdi_DestroyButtonBitmaps ENDP






END




