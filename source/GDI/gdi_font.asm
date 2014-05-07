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
;// ABox_font.asm           shape wrappers for fonts
;//
;//
;// TOC
;//
;// font_Locate
;// font_Build
;// font_Destroy




OPTION CASEMAP:NONE

.586
.MODEL FLAT

        .NOLIST
        include <Abox.inc>
        .LIST


comment ~ /*

    dynamic font allocation

    these are designed for 1 to 4 character font drawing
    mainly for pins and busses, but oscs may use them as well (4 chars max)

    the intention is to bypass the windows DrawText
        with it's associated SelectObject, SetColor and SetBkMode

    The model is: fonts are built as GDI_SHAPES that are then drawn using shape_Fill

    system must include:

        detecting if a specified character sequence exists as a shape
        locating a specified character sequence, returning a shape
        allocating new characters as required (ie. not found in the list )

    data:

        font_pin    slist of shapes for pin fonts
        font_bus    slist of shapes for bus

        GDI_SHAPE.pOutliner will store the character sequence

    functions:

        public:

            font_Locate edi=table, which table defines the font
                        eax=charcter
                builds new as required
                returns eax=pShape


                new: if eax is negative, then all four characters are drawn on top of each other
                    this is needed for some special shapes


            font_DestroyTable

                deallocates as required

        private:

            font_Build  edi=table, which table determines the font
                        eax=character

                adds a new entry to the table




*/ comment ~

.DATA

    slist_Declare font_pin  ;// use the pin font (about 8 pt arial)
    slist_Declare font_bus  ;// same as osc font (about 8 pt arial bold)

    FONT_SHAPE_BLOCK_SIZE equ 32    ;// allocate this many GDI_SHAPES at a time

.CODE


;////////////////////////////////////////////////////////////////////
;//
;//                     linear search
;//     font_Locate     edi must point at the desired list head, not the head itself
;//                     eax must be character(s)

ASSUME_AND_ALIGN
font_Locate PROC PUBLIC

    ;// returns edi as the shape pointer for the character(s)
    ;// preserves esi, ebx

        DEBUG_IF<!!((edi==OFFSET font_pin_slist_head)||(edi==OFFSET font_bus_slist_head))>
        ;// edi must point at the head, and BE the head

        mov ecx, edi    ;// store head for building
        mov edi, DWORD PTR [edi]
        ASSUME edi:PTR GDI_SHAPE
        or edi, edi     ;// check for empty list
        jz font_Build

    ;// see if it already exists
@01:    cmp eax, [edi].character
        mov edx, slist_Next(font_pin,edi);//[edi].pNext font_pin and font_bus have same pNext
        jz @02
        or edx, edx
        jz font_Build
        mov edi, edx
        jmp @01

    ;// done
@02:

    ret

font_Locate ENDP

;//
;//     font_Locate
;//
;//
;////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////
;//
;//
;//     font_Build
;//

ASSUME_AND_ALIGN
font_Build PROC USES esi ebx

    ASSUME edi:PTR GDI_SHAPE

        LOCAL rect:RECT

    ;// this is jumped to by font_Locate, which was called by some other process wanting
    ;// a shape for some text. returns with edi as that text

    ;// edi points at the tail of the desired list
    ;// ecx will point at the head
    ;// eax has the desired character sequence (4 max)

    ;// append a new shape to the list

    ;// this allocation is done in blocks of 32, like dib_Reallocate,
    ;// but instead of an implied count using the existance of a key
    ;// we'll use a block count
    ;// this let's us keep the font search exactly the same

        ;// h_alloc is zero for the last slot in block
        .IF edi && [edi].h_alloc != 0

            ;// there are still slots left in this block
            ;// all we do is bump the pointer

            lea esi, [edi+SIZEOF GDI_SHAPE] ;// bump the pointer
            mov slist_Next(font_pin,edi),esi;//[edi].pNext, esi         ;// connect to previous

            mov edx, eax    ;// next part requires character in edx

        .ELSE

            push ecx    ;// store the head pointer
            push eax    ;// store character

            ;// allocate a new block
            invoke memory_Alloc, GPTR, (SIZEOF GDI_SHAPE) * FONT_SHAPE_BLOCK_SIZE
            mov esi, eax    ;// xfer the pointer

            ;// initialize the tags in the block
            ;// we start at size-1 to make sure the last block get's a zero tag
            mov edx, FONT_SHAPE_BLOCK_SIZE-1
            mov ecx, eax    ;// ecx is an iterator
            .REPEAT
                mov (GDI_SHAPE PTR [ecx]).h_alloc, edx  ;// store the count down
                add ecx, SIZEOF GDI_SHAPE               ;// iterate
                dec edx                                 ;// decrease
            .UNTIL ZERO?

            pop edx     ;// retrieve character (to edx)
            pop ecx     ;// retrieve the head pointer

            .IF edi                     ;// empty list ?
                mov slist_Next(font_pin,edi),esi;//[edi].pNext, esi ;// just set pNext
            .ELSEIF ecx == OFFSET font_bus_slist_head
                mov font_bus_slist_head, esi    ;// store new head
            .ELSE
                mov font_pin_slist_head, esi    ;// store new head
            .ENDIF

        .ENDIF

        ;// now esi point at the new shape

        mov edi, esi    ;// xfer new shape to edi

        mov [edi].character, edx                ;// store the character
        mov [edi].dwFlags, SHAPE_IS_CHARACTER   ;// set the character flag

        ;// OC may be able to get away with being zero

    ;// determine which font to select (ecx points at the list)

        .IF ecx==OFFSET font_bus_slist_head
            mov eax, hFont_osc
        .ELSE
            mov eax, hFont_pin
        .ENDIF
        .IF eax != gdi_current_font
            mov gdi_current_font, eax
            invoke SelectObject, gdi_hDC, eax
        .ENDIF

        GDI_DC_SET_COLOR 1

    ;// call shape_Build to do the dirty work

push edi

        mov ebx, edi

;//     ASSUME ebx:PTR GDI_SHAPE
;//     DEBUG_IF <[ebx].character == 'o'>   ;// bug hunt

        inc gdi_bNoOptimize ;// very important to get non optimized records
        invoke shape_Build
        dec gdi_bNoOptimize ;// reset the flag
        DEBUG_IF<!!ZERO?>   ;// lost sync with this!!!




    ;// determine the center offset

    ;// this will take a scan through the table we just built
    ;// we'll keep track of a running point of x,y and compare with min max
    ;//
    ;// future: may be a good idea to break this into a seperate function
    ;//         because it will correctly determine the boundry rect
    ;//
    ;// each scan, then has two parts
    ;//
    ;// part 1: determine the next point by examining the source wrap
    ;//     since oBmp is always 512 wide we get a convinient mask that looks like this
    ;//
    ;//        0    2    0    0    hex
    ;//     yyyy yyyx xxxx xxxx    bin
    ;//
    ;//     condition y by shr,1
    ;//     if this sets the carry then increase dy by one (just add carry)
    ;//     add to a running counter of the point (assume we NEVER go beyond 1 byte)
    ;//
    ;//     then {min,max}{x,y} can be checked
    ;//
    ;// part 2: determine the length of the blit
    ;//         by locating the index of the jmp_to record
    ;//         then adding on the dw_count
    ;//

    ;// prepare

        xor ebx, ebx    ;// bh, bl will track the min and max
                        ;// we'll use bswap to flip between the min and max modes
                        ;// it starts as max.min
        dec bx          ;// set bhbl as max posible value
mov esi, [esp]  ;// get the shape pointer
        mov esi, (GDI_SHAPE PTR [esi]).pMask    ;// load the masker table
        xor edx, edx    ;// dh, dl will track the running x,y
        bswap ebx   ;// min.max

        jmp @06         ;// jump to entrance point

    ;// scan

    ASSUME esi:PTR RASTER_LINE

    .REPEAT

    ;// determine the wrap

        mov ah, (BYTE PTR [esi].source_wrap)[1] ;// load the source y (plus one x)
        add dl, (BYTE PTR [esi].source_wrap)[0] ;// just add dx to running X
        DEBUG_IF <SIGN?>;// ran off the X edge
        shr ah, 1       ;// divide by two (also sets carry if X was neg)
        adc dh, ah      ;// add to running Y (plus the carry)
        DEBUG_IF <SIGN?>;// ran off the Y edge

                        ;// min.max

            cmp dl, bl  ;// new max x ?
            jbe @F
            mov bl, dl
        @@:
            cmp dh, bh  ;// new max y ?
            jbe @F
            mov bh, dh
        @@:
            bswap ebx   ;// max.min
            cmp dl, bl  ;// new min x ?
            jae @F
            mov bl, dl
        @@:
            cmp dh, bh  ;// new min y ?
            jae @F
            mov bh, dh
        @@:

    ;// determine the line length (al already loaded)

        .IF al>7                        ;// check for multiple dwords

            mov cl, BYTE PTR [esi].dw_count ;// get the dword count
            and al, 3                   ;// strip off to leave extra bytes
            shl cl, 2                   ;// turn into byte count
            add al, cl                  ;// add onto extra

        .ENDIF
        bswap ebx       ;// min.max

        add dl, al                      ;// add onto running x
        DEBUG_IF <CARRY?>               ;// not good

        ;// check for new max x
        cmp dl, bl
        jbe @F
        mov bl, dl

    @@: add esi, SIZEOF RASTER_LINE     ;// iterate

    @06:mov al, BYTE PTR [esi].jmp_to   ;// load jump_to

    .UNTIL !al                          ;// do until last record

    ;// now we can compute the center offset
    ;// since windows draws offset from the origon
    ;// we want to compute the delta to the center of what windows drew
    ;// which works out to
    ;//
    ;//     wx = ( min_x + max_x + 1 ) / 2  ;// +1 accounts for odd numbered offsets
    ;//     wy = ( min_y + max_y + 1 ) / 2  ;// +1 accounts for odd numbered offsets
    ;//     dest_wrap[0] -= wy*bmp_width + wx

    ;// should store the resulting boundry in rect
    ;// possible furtue use- multiple characters
    ;//
    ;//     the fill routine is very fast, it may be better to try and use it more often
    ;//     to do that, we need to know how the characters end up
    ;//     ( since we're currently centering them )

        mov edx, ebx    ;// xfer now, before too late

        mov ecx, ebx
        bswap ebx       ;// max.min
        add ecx, ebx
        add ecx, 0101h  ;// add one before dividing
        shr ecx, 1      ;// divide by two
        and ecx, 7F7Fh  ;// this shouldn't be needed

    ;// then we compute the center offset

pop edi
ASSUME edi:PTR GDI_SHAPE

        xor eax, eax
        and edx, 0FFh   ;// strip out extra bits
        mov al, ch
        mov [edi].shape_char.max_x, edx ;// store as width
        mul gdi_bitmap_size.x
        and ecx, 0FFh
        add eax, ecx    ;// pDest offset to center
        mov [edi].shape_char.tl_adjust, eax ;// store as tl_adjust

        mov edx, [edi].pMask
        sub (RASTER_LINE PTR [edx]).dest_wrap, eax

    ;// return with pointer in edi

        ret

font_Build ENDP

;//
;//     font_Build
;//
;//
;////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////
;//
;//
;//     font_Destroy
;//

ASSUME_AND_ALIGN
font_Destroy PROC PUBLIC

    ;// destroys both tables, keep track of the block counter in the process
    slist_GetHead font_pin, esi
    xor edi, edi
    .WHILE esi

        invoke memory_Free, [esi].pMask ;// destroy the character
        .IF [esi].h_alloc==FONT_SHAPE_BLOCK_SIZE-1
            .IF edi                     ;// previous item ??
                invoke memory_Free, edi ;// free the whole block
            .ENDIF
            mov edi, esi                ;// xfer the new block start
        .ENDIF
        slist_GetNext font_pin, esi     ;// iterate before we destroy it

    .ENDW
    .IF edi         ;// always free the last block
        invoke memory_Free, edi
    .ENDIF
    mov font_pin_slist_head, esi    ;// store zero

    slist_GetHead font_bus, esi
    xor edi, edi
    .WHILE esi

        invoke memory_Free, [esi].pMask ;// destroy the character
        .IF [esi].h_alloc==FONT_SHAPE_BLOCK_SIZE-1
            .IF edi                     ;// previous item ??
                invoke memory_Free, edi ;// free the whole block
            .ENDIF
            mov edi, esi                ;// xfer the new block start
        .ENDIF
        slist_GetNext font_pin, esi     ;// iterate before we destroy it

    .ENDW
    .IF edi         ;// always free the last block
        invoke memory_Free, edi
    .ENDIF
    mov font_bus_slist_head, esi    ;// store zero

    ret

font_Destroy ENDP

;//
;//     font_Destroy
;//
;//
;////////////////////////////////////////////////////////////////////




IFDEF DEBUGBUILD
ASSUME_AND_ALIGN
font_VerifyFonts PROC uses ebx

    push eax

    slist_GetHead font_pin, ebx ;// use the pin font (about 8 pt arial)
    .WHILE ebx

        or eax, [ebx].pSource
        .IF !ZERO?
            invoke IsBadWritePtr, eax, 16
            DEBUG_IF <eax>  ;// this is an invalid ptr
        .ENDIF
        or eax, [ebx].pMask
        .IF !ZERO?
            invoke IsBadWritePtr, eax, 16
            DEBUG_IF <eax>  ;// this is an invalid ptr
        .ENDIF
        or eax, [ebx].pOut1
        .IF !ZERO?
            invoke IsBadWritePtr, eax, 16
            DEBUG_IF <eax>  ;// this is an invalid ptr
        .ENDIF
        or eax, [ebx].pOut2
        .IF !ZERO?
            invoke IsBadWritePtr, eax, 16
            DEBUG_IF <eax>  ;// this is an invalid ptr
        .ENDIF
        or eax, [ebx].pOut3
        .IF !ZERO?
            invoke IsBadWritePtr, eax, 16
            DEBUG_IF <eax>  ;// this is an invalid ptr
        .ENDIF
        or eax, [ebx].hDC
        .IF !ZERO?
            invoke GetHandleInformation, eax, esp
            DEBUG_IF <!!eax>;// this is an invalid handle
            xor eax, eax
        .ENDIF
        or eax, [ebx].hBmp
        .IF !ZERO?
            invoke GetHandleInformation, eax, esp
            DEBUG_IF <!!eax>;// this is an invalid handle
            xor eax, eax
        .ENDIF

        slist_GetNext font_pin, ebx

    .ENDW
    slist_GetHead font_bus, ebx ;// same as osc font (abot 8 pt arial bold)
    .WHILE ebx

        or eax, [ebx].pSource
        .IF !ZERO?
            invoke IsBadWritePtr, eax, 16
            DEBUG_IF <eax>  ;// this is an invalid ptr
        .ENDIF
        or eax, [ebx].pMask
        .IF !ZERO?
            invoke IsBadWritePtr, eax, 16
            DEBUG_IF <eax>  ;// this is an invalid ptr
        .ENDIF
        or eax, [ebx].pOut1
        .IF !ZERO?
            invoke IsBadWritePtr, eax, 16
            DEBUG_IF <eax>  ;// this is an invalid ptr
        .ENDIF
        or eax, [ebx].pOut2
        .IF !ZERO?
            invoke IsBadWritePtr, eax, 16
            DEBUG_IF <eax>  ;// this is an invalid ptr
        .ENDIF
        or eax, [ebx].pOut3
        .IF !ZERO?
            invoke IsBadWritePtr, eax, 16
            DEBUG_IF <eax>  ;// this is an invalid ptr
        .ENDIF
        or eax, [ebx].hDC
        .IF !ZERO?
            invoke GetHandleInformation, eax, esp
            DEBUG_IF <!!eax>;// this is an invalid handle
            xor eax, eax
        .ENDIF
        or eax, [ebx].hBmp
        .IF !ZERO?
            invoke GetHandleInformation, eax, esp
            DEBUG_IF <!!eax>;// this is an invalid handle
            xor eax, eax
        .ENDIF

        slist_GetNext font_bus, ebx

    .ENDW


    pop eax

    ret

font_VerifyFonts ENDP

ENDIF
















ASSUME_AND_ALIGN



END
