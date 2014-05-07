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
;//     GDI_Dib.asm     routines to manage the custom dibs
;//
;//
;// TOC
;//
;// dib_Initialize
;// dib_Destroy
;// dib_Reallocate
;// dib_Free
;// dib_SyncPalettes
;// dib_Fill
;// dib_FillAndFrame
;// dib_FillColumn
;// dib_DrawLine
;// dib_FillRect_ptr_ptr_height



OPTION CASEMAP:NONE

.586
.MODEL FLAT

    .NOLIST
    include <Abox.inc>
    .LIST

.DATA

    slist_Declare   dib     ;// slist for all allocated dibs
    dib_pBMIH   dd  0       ;// pointer to the common BITMAPINFO_256
                            ;// also containes the current palette

    DIB_BLOCK_SIZE equ 32   ;// allocate 32 DIB_WRAPPERS at a time

.CODE


;////////////////////////////////////////////////////////////////////
;//
;//                             public function
;//     dib_Initialize
;//
ASSUME_AND_ALIGN
dib_Initialize PROC

    ;// allocate memory for the dib_BMIH
    ;// fill in the struct

    DEBUG_IF <dib_pBMIH>    ;// already assigned

    invoke memory_Alloc, GPTR, SIZEOF BITMAPINFO_256
    mov dib_pBMIH, eax
    ASSUME eax:PTR BITMAPINFO_256

    ;// setup the bitmap header

    mov [eax].biSize, SIZEOF BITMAPINFOHEADER
    inc [eax].biPlanes
    mov [eax].biBitCount, 8

    ;// another function will initialize the palette

    ret


dib_Initialize ENDP
;//
;//
;//     dib_Initialize
;//
;////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////
;//
;//                             public function
;//     dib_Destroy
;//                             this destroys everything
ASSUME_AND_ALIGN
dib_Destroy     PROC

    ;// destroys all registers

    slist_GetHead dib, esi
    xor edi, edi    ;// edi counts slots
    mov ebx, esi    ;// ebx points at blocks
    xor eax, eax    ;// eax tests

    .WHILE esi

        or eax, [esi].shape.hDC         ;// load and test the bitmap handle
        .IF !ZERO?                  ;// assigned ?
            invoke SelectObject, [esi].shape.hDC, [esi].shape.hOldBmp
            invoke DeleteObject, [esi].shape.hBmp       ;// destroy the old bitmap
            DEBUG_IF <!!eax>
            ;// select null brush and null pin into dc
            invoke GetStockObject, NULL_BRUSH
            invoke SelectObject, [esi].shape.hDC, eax
            invoke GetStockObject, NULL_PEN
            invoke SelectObject, [esi].shape.hDC, eax

            invoke DeleteDC, [esi].shape.hDC            ;// delete the DC
            DEBUG_IF <!!eax>
            xor eax, eax
        .ENDIF
        or eax, [esi].shape.pMask   ;// if a shape was assigned, free it
        .IF !ZERO?
            invoke memory_Free, eax ;// delete the raster tables
            xor eax, eax
        .ENDIF

        inc edi                     ;// increase the slot counter
        slist_GetNext dib, esi      ;// get the next slot
        .IF !(edi & (DIB_BLOCK_SIZE-1)) ;// passed a block boundry ?
            invoke memory_Free, ebx ;// delete the block, eax will be null
            mov ebx, esi            ;// set new block start
        .ENDIF

    .ENDW

    ;// always free the last block
    .IF ebx
        invoke memory_Free, ebx
    .ENDIF

    ret

dib_Destroy ENDP
;//
;//
;//     dib_Destroy
;//
;////////////////////////////////////////////////////////////////////





;////////////////////////////////////////////////////////////////////
;//
;//                         private function
;//
;//                         locates the first unused slot
;//     dib_locate_slot     if none found, allocates and initializes a new block of slots
;//                         slot is returned in esi
;//                         this also allocates the DC for the slot
ASSUME_AND_ALIGN
dib_locate_slot:

    push edi

        slist_GetHead dib, esi
        xor edi, edi
        .WHILE esi
            cmp [esi].shape.hDC, 0  ;// test if slot is used
            jz initialize_slot      ;// jmp if not used (found it)
            mov edi, esi
            slist_GetNext dib, esi  ;// get the next slot
        .ENDW
        ASSUME edi:PTR DIB_CONTAINER

        ;// need to allocate

        ;// allocate a new block
        invoke memory_Alloc, GPTR, SIZEOF(DIB_CONTAINER) * DIB_BLOCK_SIZE
        mov esi, eax

        ;// append to list
        .IF edi     ;// list exists ?
            mov slist_Next(dib,edi),esi;//(DIB_CONTAINER PTR [edi]).shape.pNext, esi
        .ELSE
            ;//slist_SetHead dib, esi
            mov slist_Head(dib), esi
        .ENDIF

        ;// initialize the block
        mov ecx, DIB_BLOCK_SIZE-1   ;// ecx counts (don't set the last entry)
        mov edx, esi                ;// edx points at next block
        mov edi, esi                ;// edi iterates blocks
        .REPEAT
            add edx, SIZEOF DIB_CONTAINER   ;// bump to next block
            mov slist_Next(dib,edi), edx;//[edi].shape.pNext, edx       ;// set this block
            dec ecx                     ;// decrease the counter
            mov edi, edx                ;// xfer next to current
        .UNTIL ZERO?

    ;// esi is the slot to initialize
    initialize_slot:
    pop edi

        invoke CreateCompatibleDC, 0;// create a DC
        mov [esi].shape.hDC, eax    ;// store in wrapper

    ret
;//
;//     dib_locate_slot
;//
;//
;////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////
;//
;//                         private function
;//
;//                         delects and destroys the dib
;//     dib_free_dib
;//
ASSUME_AND_ALIGN
dib_free_dib:

    ASSUME esi:PTR DIB_CONTAINER

    ;// deslect and destroy the bitmap
    invoke SelectObject, [esi].shape.hDC, [esi].shape.hOldBmp
    invoke DeleteObject, [esi].shape.hBmp   ;// destroy the old bitmap
    DEBUG_IF <!!eax>
    IFDEF DEBUGBUILD
        mov [esi].shape.hBmp, 0
        mov [esi].shape.pSource, 0
    ENDIF

    ret
;//
;//     dib_free_dib
;//
;//
;////////////////////////////////////////////////////////////////////




;////////////////////////////////////////////////////////////////////
;//
;//                         private function
;//
;//                             this creates a new dib section
;//     dib_allocate_dib        and selects it into the dc
;//
ASSUME_AND_ALIGN
dib_allocate_dib:

    ASSUME esi:PTR DIB_CONTAINER

    mov edx, [esi].shape.siz.y      ;// get the requested height
    mov ecx, dib_pBMIH              ;// get the bitmap info struct
    ASSUME ecx:PTR BITMAPINFO_256
    mov [esi].shape.h_alloc, edx    ;// set as size allocated
    mov eax, [esi].shape.siz.x      ;// get the requested width
    DEBUG_IF< eax & 3 >     ;// width is supposed to be dword aligned

    neg edx                 ;// dibs must be built upside down !!!

    mov [ecx].biWidth,  eax         ;// set the width
    mov [ecx].biHeight, edx         ;// and height
    lea eax, [esi].shape.pSource    ;// get where we want the pointer to go

    ;// create the section
    invoke CreateDIBSection, [esi].shape.hDC, ecx, DIB_RGB_COLORS, eax, 0, 0
    DEBUG_IF <!!eax>
    mov [esi].shape.hBmp, eax           ;// store the handle
    invoke SelectObject, [esi].shape.hDC, [esi].shape.hBmp
    mov [esi].shape.hOldBmp, eax        ;// store the old handle so we can free

    ret


;////////////////////////////////////////////////////////////////////
;//
;//                         private function
;//
;//                         frees the memory allocated for the shape
;//     dib_free_shape
;//

ASSUME_AND_ALIGN
dib_free_shape:

    ASSUME esi:PTR DIB_CONTAINER
    DEBUG_IF <!![esi].shape.pMask>  ;// why are we calling this

    invoke memory_Free, [esi].shape.pMask
    mov [esi].shape.pMask, eax
    IFDEF DEBUGBUILD
        mov [esi].shape.pOut1, eax
        mov [esi].shape.pOut2, eax
        mov [esi].shape.pOut3, eax
    ENDIF

    ret
;//
;//     dib_free_shape
;//
;//
;////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////
;//
;//                         private function
;//     dib_clear_shape
;//                         the shapes must be completely zeroed before being initialized
;//                         we also assume that the height is correct
ASSUME_AND_ALIGN
dib_clear_shape:

    ASSUME esi:PTR DIB_CONTAINER

    push edi

    mov ecx, [esi].shape.h_alloc;// h   always use the allocated height
    add ecx, 6              ;// h+6
    lea ecx, [ecx+ecx*8]    ;// (h+6)*9
    mov edi, [esi].shape.pMask  ;// get pointer to what we're about to clear
    shl ecx, LOG2(64)       ;// (h+6)*9*64
    xor eax, eax            ;// store zero
    .IF [esi].shape.dwFlags & SHAPE_DIB_HAS_INTER
        add ecx, (SIZEOF I_POINT)*4
    .ENDIF
    shr ecx, 2              ;// turn back to dword
    rep stosd               ;// clear it

    pop edi

    ret
;//
;//                         private function
;//     dib_clear_shape
;//                         the shapes must be completely zeroed before being initialized
;//                         we also assume that the height is correct
;////////////////////////////////////////////////////////////////////






;////////////////////////////////////////////////////////////////////
;//
;//                         private function
;//
;//                             allocates enough memory for the shape
;//     dib_allocate_shape
;//

ASSUME_AND_ALIGN
dib_allocate_shape:

    ASSUME esi:PTR DIB_CONTAINER

    ;// according to a worksheet,
    ;// the number of raster lines to add = 36 + 6*height
    ;// deriving the byte size then optimizing results in
    ;//
    ;//     (H+6)*9  << log2(64)
    ;//
    ;// then add 4 IPOINTS if an intersector is required

    IF (SIZEOF GDI_CONTAINER) - 96
    .ERR <following code assumes that containers are 24 dwords>
    ENDIF

    mov eax, [esi].shape.h_alloc;// h   always use the allocated height
    add eax, 6              ;// h+6
    lea eax, [eax+eax*8]    ;// (h+6)*9
    shl eax, LOG2(64)       ;// (h+6)*9*64

    .IF [esi].shape.dwFlags & SHAPE_DIB_HAS_INTER
        add eax, (SIZEOF I_POINT)*4
    .ENDIF

    invoke memory_Alloc, GPTR, eax  ;// allocate the memory
    mov [esi].shape.pMask, eax      ;// store in container

    ret

;//
;//
;//     dib_allocate_shape
;//
;////////////////////////////////////////////////////////////////////















;//////////////////////////////////////////////////////////////////////
;//
;//                                         public function
;//
;//     dib_Reallocate      returns eax as a new slot, or the same slot
;//

comment ~ /*

    table for what to do
    the rule of thumb is to reallocate only if the size get's larger

    test        1   2   3   4
    --------------------------
    ptr==flag   1   0   0   0
    h>alloc     x   1   0   0
    w!=alloc    x   x   1   0
    --------------------------
    dib action
    --------------------------
    locate slot 1   0   0   0
    free DIB    0   1   1   0
    alloc DIB   1   1   1   0
    --------------------------
    shape action (flagged)
    --------------------------
    free        0   1   0   0
    alloc       1   1   0   0
    clear       0   0   1   1
    init        1   1   1   1

*/ comment ~

PROLOGUE_OFF
ASSUME_AND_ALIGN
dib_Reallocate PROC  STDCALL uses esi pDib:DWORD, wid:DWORD, hig:DWORD

push esi    ;// preserves esi, ebx, edi

;// stack looks like this

;// esi     ret     ptr     wid     hig
;// 00      04      08      0C      10

    mov esi, [esp+8]                ;// get the pointer/flag
    ASSUME esi:PTR DIB_CONTAINER

    ;// always condition the width to a dword

        mov eax, [esp+0Ch]          ;// get the requested width
        add eax, 3                  ;// add three before we realign
        and eax, 0FFFFFFFCh         ;// dib's must be dword aligned
        mov [esp+0Ch], eax          ;// store back for later

    ;// check if we're reallocating or allocating

    cmp esi, DIB_ALLOCATE_TEST  ;// check if flag or pointer
    ja reassign_slot

    ;// column 1

        call dib_locate_slot    ;// locate first unused wrapper
                                ;// also creates the dc
        mov ecx, [esp+08h]      ;// get the flags
        mov eax, [esp+0Ch]      ;// get the width
        mov edx, [esp+10h]      ;// get the height

        shl ecx, LOG2(SHAPE_DIB_HAS_SHAPE)  ;// shift to a normal set of flags
        mov [esi].shape.siz.x, eax          ;// store width
        or ecx, SHAPE_IS_DIB                ;// set the is dib flag
        mov [esi].shape.siz.y, edx          ;// store height

        imul edx                    ;// multiply by height
        shr eax, 2                  ;// change to number of dwords
        mov [esi].shape.dword_size, eax ;// store in object

        bt ecx, LOG2(SHAPE_DIB_HAS_INTER)   ;// check for intersector
        .IF CARRY?
            or ecx, 4                       ;// set the number of intersectors
        .ENDIF
        or ecx, SHAPE_INITIALIZED           ;// set this for other functions
        mov [esi].shape.dwFlags, ecx        ;// store flags in object

        bt ecx, LOG2(SHAPE_DIB_HAS_SHAPE)   ;// check if we allocate a shape
        .IF CARRY?
            mov edx, [esp+10h]      ;// get the height
            mov [esi].shape.h_alloc, edx    ;// have to store the height before calling
            call dib_allocate_shape         ;// allocate the shape
            call dib_initialize_shape       ;// initialize it
        .ENDIF

        call dib_allocate_dib       ;// allocate the dib

        ;// that's it
        mov eax, esi
        pop esi
        retn 0Ch


    ALIGN 16
    reassign_slot:

        ;// this is where we check if we have to reallocate
        DEBUG_IF<!![esi].shape.hBmp>    ;// reassign what ??

        ;// very important that we set the new sizes in the container

        mov eax, [esp+0Ch]      ;// get the requested width
        mov edx, [esp+10h]      ;// get the requested height

        cmp edx, [esi].shape.h_alloc ;// compare with allocated height
        jbe @01         ;// if above, we need to reallocate the dib

        ;// COLUMN 2

            mov [esi].shape.siz.x, eax  ;// store the width
            mov [esi].shape.siz.y, edx  ;// store the height

            imul edx                    ;// multiply width by height
            shr eax, 2                  ;// change to number of dwords
            mov [esi].shape.dword_size, eax ;// store in object

            call dib_free_dib           ;// free existing dib
            call dib_allocate_dib       ;// allocate a new one
            .IF [esi].shape.dwFlags & SHAPE_DIB_HAS_SHAPE
                call dib_free_shape
                call dib_allocate_shape
                call dib_initialize_shape
            .ENDIF

            ;// that's it
            mov eax, esi
            pop esi
            retn 0Ch

    @01:    ;// height is less or equal to allocated height

        cmp eax, [esi].shape.siz.x  ;// compare with what's there
        jz @02

        ;// COLUMN 3

            mov [esi].shape.siz.x, eax  ;// store width
            mov [esi].shape.siz.y, edx  ;// store height

            imul edx                    ;// multiply width by height
            shr eax, 2                  ;// change to number of dwords
            mov [esi].shape.dword_size, eax ;// store in object

            call dib_free_dib           ;// free existing dib
            call dib_allocate_dib       ;// allocate a new one
            .IF [esi].shape.dwFlags & SHAPE_DIB_HAS_SHAPE
                call dib_clear_shape
                call dib_initialize_shape
            .ENDIF

            ;// that's it
            mov eax, esi
            pop esi
            retn 0Ch

    @02:    ;// height is less than, width is same

        ;// COLUMN 4

            mov [esi].shape.siz.x, eax  ;// store width
            mov [esi].shape.siz.y, edx  ;// store height

            imul edx                    ;// multiply by height
            shr eax, 2                  ;// change to number of dwords
            mov [esi].shape.dword_size, eax ;// store in object

            .IF [esi].shape.dwFlags & SHAPE_DIB_HAS_SHAPE
                call dib_clear_shape
                call dib_initialize_shape
            .ENDIF

            ;// that's it
            mov eax, esi
            pop esi
            retn 0Ch


dib_Reallocate ENDP
PROLOGUE_ON

;//
;//     dib_Reallocate      returns eax as a new slot, or the same slot
;//
;//                                         public function
;//
;//////////////////////////////////////////////////////////////////////






;////////////////////////////////////////////////////////////////////
;//
;//                                 public function
;//     dib_Free
;//

PROLOGUE_OFF
ASSUME_AND_ALIGN
dib_Free PROC STDCALL uses esi pDib:DWORD

    push esi

;// stack looks like this
;// esi     ret     pDib
;// 00      04      08

    mov esi, [esp+8]                ;// get the passed pointer
    ASSUME esi:PTR DIB_CONTAINER

IFDEF DEBUGBUILD
    .IF ![esi].shape.hDC
        DEBUG_IF <!![esi].shape.hBmp>   ;// no dc but we have a bitmap ??
        DEBUG_IF <!![esi].shape.hOldBmp>
    .ENDIF
ENDIF

    DEBUG_IF <!!![esi].shape.hDC>   ;// supposed to check first

    call dib_free_dib               ;// destroy the bitmap
    invoke DeleteDC, [esi].shape.hDC;// destroy the DC

    .IF [esi].shape.dwFlags & SHAPE_DIB_HAS_SHAPE
        call dib_free_shape
    .ENDIF

    ;// slots are reused, so we must clear the important values
    xor edx, edx
    mov [esi].shape.hDC, edx
    mov [esi].shape.hBmp, edx
    mov [esi].shape.hOldBmp, edx
    pop esi

    ;// that should do it
    ret 4

dib_Free ENDP
PROLOGUE_ON
;//
;//                                 public function
;//     dib_Free
;//
;////////////////////////////////////////////////////////////////////




;////////////////////////////////////////////////////////////////////
;//
;//                             public function
;//     dib_SyncPalettes
;//

ASSUME_AND_ALIGN
dib_SyncPalettes    PROC

    push esi

    slist_GetHead dib, esi
    .WHILE esi

        .IF [esi].shape.hDC
            invoke SetDIBColorTable, [esi].shape.hDC, 0, 256, OFFSET oBmp_palette
        .ENDIF

        slist_GetNext dib, esi

    .ENDW

    ;// for creating new dib's, we copy obmp palette
    ;// to our palette

    push edi

    mov edi, dib_pBMIH
    lea esi, oBmp_palette
    ASSUME edi:PTR BITMAPINFO_256
    lea edi, [edi].palette
    mov ecx, 256
    rep movsd

    pop edi

    pop esi

    ret

dib_SyncPalettes    ENDP

;//
;//     dib_SyncPalettes
;//                             public function
;//
;////////////////////////////////////////////////////////////////////




;////////////////////////////////////////////////////////////////////
;//
;//
;//     dib_Fill                public function
;//
;//                 fills the entire dib
;//
ASSUME_AND_ALIGN                ;// ebx must point at dib
dib_Fill PROC                   ;// eax is fill color

    ASSUME ebx:PTR DIB_CONTAINER

    push edi

;// fill

    mov ecx, [ebx].shape.dword_size ;// get the dword size
    mov edi, [ebx].shape.pSource    ;// get the source pointer
    rep stosd                       ;// fill

    pop edi

    ret

dib_Fill ENDP


;////////////////////////////////////////////////////////////////////
;//
;//
;//     dib_FillAndFrame        public function
;//
;//                 fills the entire dib
;//                 then frames with 2 pixel border
;//     destroys ecx
;//
;//
ASSUME_AND_ALIGN                        ;// ebx must point at dib (preserved)
dib_FillAndFrame PROC                   ;// eax is fill color
                                        ;// edx is frame color
    ASSUME ebx:PTR DIB_CONTAINER        ;// frame is always 2 pixels wide

    push edi

;// fill

    mov ecx, [ebx].shape.dword_size ;// get the dword size
    mov edi, [ebx].shape.pSource    ;// get the source pointer
    rep stosd                       ;// fill

;// frame

    ;// top

        mov ecx, [ebx].shape.siz.x  ;// get the width
        mov eax, edx            ;// xfer frame color
        mov edi, [ebx].shape.pSource    ;// get the source
        shr ecx, 1              ;// dwords in two lines
        rep stosd               ;// frame it

    ;// right, left

        mov edx, [ebx].shape.siz.x  ;// get the line width
        mov ecx, [ebx].shape.siz.y  ;// get the height
        sub edi, 2                  ;// edi was at the start of this line
        sub edx, 4                  ;// adjust for dwords
        sub ecx, 4                  ;// subtract 4 lines from height

        @@: stosd
            add edi, edx
            dec ecx
            jz @F
            stosd
            add edi, edx
            dec ecx
            jnz @B
        @@:

        mov ecx, [ebx].shape.siz.x  ;// get the width
        stosw           ;// store the last one (only two pixels)

    ;// bottom

        shr ecx, 1              ;// dwords in two lines
        rep stosd               ;// frame it

    ;// that's it

        pop edi

        ret

dib_FillAndFrame ENDP
;//
;//
;//     dib_FillAndFrame        public function
;//
;////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////
;//
;//
;//     dib_FillColumn
;//

.DATA

    dib_fill_column_table LABEL DWORD

    dd  dib_FC_0,dib_FC_1, dib_FC_2, dib_FC_3
    dd  dib_FC_4, dib_FC_5, dib_FC_6, dib_FC_7
    dd  dib_FC_4n, dib_FC_4n1, dib_FC_4n2, dib_FC_4n3

.CODE


ASSUME_AND_ALIGN
dib_FillColumn PROC uses ebp edi esi

    ASSUME ebx:PTR DIB_CONTAINER

    ;// eax must have the color to fill with
    ;// ecx must be column width
    ;// edx must be X coord

    mov edi, [ebx].shape.pSource    ;// load the destination
    mov esi, [ebx].shape.siz.y      ;// get the total height
    add edi, edx                    ;// scoot Y0 over by requested X
    mov edx, [ebx].shape.siz.x      ;// get the width
    sub edx, ecx                ;// edx is wrap amount

    cmp ecx, 7          ;// see which routine we use
    jbe less_than_seven ;// jump if simpler one

more_than_seven:    ;// have to define a dword repeat count

    mov ebx, ecx;// xfer width to ebx
    and ecx, 3  ;// strip out extra
    shr ebx, 2  ;// ebx is dword count
    add ecx, 8  ;// ecx is an index again

less_than_seven:    ;// determine the jump index

    mov ebp, dib_fill_column_table[ecx*4]
    jmp ebp


dib_FC_3::  stosb       ;// 3
dib_FC_2::  stosb       ;// 2
dib_FC_1::  dec esi     ;// decrease the count
            stosb       ;// 1
            jz all_done ;// exit is zero
            add edi, edx;// wrap around to next row
            jmp ebp     ;// jump to top

dib_FC_7::  stosb       ;// 7
dib_FC_6::  stosb       ;// 6
dib_FC_5::  stosb       ;// 5
dib_FC_4::  dec esi     ;// decrease the count
            stosd       ;// 4
            jz all_done ;// exit is zero
            add edi, edx;// wrap around to next row
            jmp ebp     ;// jump to top

dib_FC_4n3::stosb       ;// 4n+3
dib_FC_4n2::stosb       ;// 4n+2
dib_FC_4n1::stosb       ;// 4n+1
dib_FC_4n:: mov ecx, ebx;// load the count
            rep stosd   ;// 4n

            dec esi     ;// decrease line count
            jz all_done ;// jump if done
            add edi, edx;// wrap to next row
            jmp ebp     ;// jump to top

ALIGN 16
dib_FC_0::
all_done:

    ret

dib_FillColumn ENDP


;//
;//
;//     dib_FillColumn
;//
;////////////////////////////////////////////////////////////////////





;////////////////////////////////////////////////////////////////////////
;//
;//                     draws a line from x0,y0 to x1,y1 using colorIndex
;//                     does NOT check values, so they'd better be valid
;//     dib_DrawLine
;//
comment ~ /*


    peices:

        dx  x1-x0
        dy  y1-y0
        C   Color to draw with

        W   Width of the display surface
        P   pointer to detination (starts at y0*W+x0, always drawn)
        R   Remainder AccumulateR

        aP  amount we Always Add to the pointer
        tP  amount we add when the remainder Trips
        aR  amount we Always Add to the accumulater
        tR  amount we Trip and subtract from the Remainder

        I   counter index

    general algorithm:  (optimizations preformed as required)

    @draw:  dec I       ;// dcrease the count
            mov [P],C   ;// draw the color
            js  @done   ;// exit if done
            add R, aR   ;// advance Remainder
            add P, aP   ;// advance pointer
            cmp R, tR   ;// check remainder
            jb  @draw   ;// draw if no trip
            add P, tP   ;// add trip to pointer
            sub R, tR   ;// subtract remainder with trip value
            jmp @draw   ;// draw
    @done:


    cases are oriented around the x0 point in clockwise order (0 to 7)
    so these are left handed coords
    there are eight cases charted thusly:


          \5 | 6/       special cases are
           \ | /
          4 \|/ 7           horizontal_pos  right       45_degrees is a combinned case
         ---------x         horizontal_neg  left        dx and dy will already be calculated
          3 /|\ 0           vertical_pos    down
           / | \            vertical_neg    up          dot is hit when dx and dy = 0
          /2 | 1\
             y

*/ comment ~

;// C CALLING CONVENTION !!!
;// C CALLING CONVENTION !!!
;// C CALLING CONVENTION !!!
;// C CALLING CONVENTION !!!
;// C CALLING CONVENTION !!!

ASSUME_AND_ALIGN
dib_DrawLine PROC   ;// ret x0  y0  x1  y0
                    ;// 00  04  08  0C  10
    push ebx
    push ebp
    push esi
    push edi

;// edi esi ebp ebx ret x0  y0  x1  y0
;// 00  04  08  0C  10  14  18  1C  20

    ;// al must be the color to draw with

    ASSUME ebx:PTR DIB_CONTAINER

    st_X0   TEXTEQU <(DWORD PTR [esp+14h])>
    st_Y0   TEXTEQU <(DWORD PTR [esp+18h])>
    st_X1   TEXTEQU <(DWORD PTR [esp+1Ch])>
    st_Y1   TEXTEQU <(DWORD PTR [esp+20h])>


;// error checking for development

    IFDEF DEBUGBUILD

        mov ecx, st_X0
        mov edx, st_Y0
        DEBUG_IF < ecx & 80000000h >            ;// out of range
        DEBUG_IF < edx & 80000000h >            ;// out of range
        DEBUG_IF < ecx !>= [ebx].shape.siz.x >  ;// out of range
        DEBUG_IF < edx !>= [ebx].shape.siz.y >  ;// out of range

        mov ecx, st_X1
        mov edx, st_Y1
        DEBUG_IF < ecx & 80000000h >            ;// out of range
        DEBUG_IF < edx & 80000000h >            ;// out of range
        DEBUG_IF < ecx !>= [ebx].shape.siz.x >  ;// out of range
        DEBUG_IF < edx !>= [ebx].shape.siz.y >  ;// out of range

    ENDIF

;// register use

    _dY TEXTEQU <edx>   ;// edx dy
    _dX TEXTEQU <ecx>   ;// ecx dx

    _P  TEXTEQU <edi>   ;// edi P   pointer to destination (starts at y0*W+x0, always drawn)
    _R  TEXTEQU <ebx>   ;// ebx R   Remainder AccumulateR

    _W  TEXTEQU <ebp>   ;// ebp W   Width of the display surface
    _I  TEXTEQU <esi>   ;// esi I   counter index

    _C  TEXTEQU <al>    ;// eax C   Color to draw with


;// determine _P, load _W

    mov _I, eax     ;// store for the multiply

    mov eax, st_Y0
    mov _W, [ebx].shape.siz.x   ;// ebp destroyed
    mov _P, [ebx].shape.pSource ;// edi destroyed
    mul _W                      ;// edx trashed
    add _P, st_X0
    add _P, eax                 ;// _P is correct
                                ;// _W is correct

;// determine dx and dy and run through the state tree

    mov eax, _I     ;// _C is correct

    mov _dX, st_X1
    mov _dY, st_Y1

    sub _dX, st_X0
    js case_2345
    jz case_vertical

case_6701:

    sub _dY, st_Y0
    js case_67
    jz case_horizontal_pos

    case_01:

        cmp _dX, _dY
        jb case_1
        je case_01_equal

        case_0:
        ;//    +1 | +W         aP | tP
        ;// dx---------     I ---------
        ;//    dy | dx         aR | tR

            mov _I, _dX
            mov _R, _dY

    @draw_0:dec _I      ;// dcrease the count
            stosb       ;// draw the color, and advance pointer
            js all_done ;// exit if done
            add _R, _dY ;// advance Remainder
            cmp _R, _dX ;// check remainder
            jb  @draw_0 ;// draw if no trip
            add _P, _W  ;// add trip to pointer
            sub _R, _dX ;// subtract remainder with trip value
            jmp @draw_0 ;// draw


        ALIGN 16
        case_1:
        ;//    +W | +1         aP | tP
        ;// dy---------     I ---------
        ;//    dx | dy         aR | tR


            mov _I, _dY
            mov _R, _dX

    @draw_1:dec _I      ;// dcrease the count
            mov [_P],_C ;// draw the color
            js  all_done;// exit if done
            add _R, _dX ;// advance Remainder
            add _P, _W  ;// advance pointer
            cmp _R, _dY ;// check remainder
            jb  @draw_1 ;// draw if no trip
            inc _P
            sub _R, _dY ;// subtract remainder with trip value
            jmp @draw_1 ;// draw

        ALIGN 16
        case_01_equal:
        ;//      W+1           aP | tP
        ;// I ---------     I ---------
        ;//                    aR | tR

            inc _W
            jmp @45_degrees


    ALIGN 16
    case_67:

        neg _dY

        cmp _dX, _dY
        ja case_7
        je case_67_equal

        case_6:
        ;//    -W | +1         aP | tP
        ;//-dy---------     I ---------
        ;//    dx |-dy         aR | tR

            mov _I, _dY
            mov _R, _dX

    @draw_6:dec _I      ;// dcrease the count
            mov [_P],_C ;// draw the color
            js  all_done;// exit if done
            add _R, _dX ;// advance Remainder
            sub _P, _W  ;// advance pointer
            cmp _R, _dY ;// check remainder
            jb  @draw_6 ;// draw if no trip
            inc _P      ;// add trip to pointer
            sub _R, _dY ;// subtract remainder with trip value
            jmp @draw_6 ;// draw


        ALIGN 16
        case_7:
        ;//    +1 | -W         aP | tP
        ;// dx---------     I ---------
        ;//   -dy | dx         aR | tR

            mov _I, _dX
            mov _R, _dY

    @draw_7:dec _I      ;// dcrease the count
            stosb       ;// draw the color, and advance
            js  all_done;// exit if done
            add _R, _dY ;// advance Remainder
            ;//add _P, aP  ;// advance pointer
            cmp _R, _dX ;// check remainder
            jb  @draw_7 ;// draw if no trip
            sub _P, _W  ;// add trip to pointer
            sub _R, _dX ;// subtract remainder with trip value
            jmp @draw_7 ;// draw




        ALIGN 16
        case_67_equal:
        ;//      1-W           aP | tP
        ;// I ---------     I ---------
        ;//                    aR | tR

            neg _W
            inc _W
            jmp @45_degrees


ALIGN 16
case_2345:

    neg _dX

    sub _dY, st_Y0
    js case_45
    jz case_horizontal_neg

    case_23:

        cmp _dX, _dY
        ja case_3
        je case_23_equal

        case_2:
        ;//    +W | -1         aP | tP
        ;// dy---------     I ---------
        ;//   -dx | dy         aR | tR

            mov _I, _dY
            mov _R, _dX

    @draw_2:dec _I      ;// dcrease the count
            mov [_P],_C ;// draw the color
            js  all_done;// exit if done
            add _R, _dX ;// advance Remainder
            add _P, _W  ;// advance pointer
            cmp _R, _dY ;// check remainder
            jb  @draw_2 ;// draw if no trip
            dec _P      ;// add trip to pointer
            sub _R, _dY ;// subtract remainder with trip value
            jmp @draw_2 ;// draw


        ALIGN 16
        case_3:
        ;//    -1 | +W         aP | tP
        ;//-dx---------     I ---------
        ;//    dy |-dx         aR | tR

            std

            mov _I, _dX
            mov _R, _dY

    @draw_3:dec _I      ;// dcrease the count
            stosb       ;// draw the color, and advance
            js  all_done_D ;  exit if done
            add _R, _dY ;// advance Remainder

            cmp _R, _dX ;// check remainder
            jb  @draw_3 ;// draw if no trip
            add _P, _W  ;// add trip to pointer
            sub _R, _dX ;// subtract remainder with trip value
            jmp @draw_3 ;// draw


        ALIGN 16
        case_23_equal:
        ;//      W-1           aP | tP
        ;// I ---------     I ---------
        ;//                    aR | tR

            dec _W
            jmp @45_degrees


    ALIGN 16
    case_45:

        neg _dY

        cmp _dX, _dY
        jb case_5
        je case_45_equal

        case_4:
        ;//    -1 | -W         aP | tP
        ;//-dx---------     I ---------
        ;//   -dy |-dx         aR | tR

            std

            mov _I, _dX
            mov _R, _dY

    @draw_4:dec _I      ;// dcrease the count
            stosb       ;// draw the color, and advance
            js  all_done_D; exit if done
            add _R, _dY ;// advance Remainder
            ;//add _P, aP  ;// advance pointer
            cmp _R, _dX ;// check remainder
            jb  @draw_4 ;// draw if no trip
            sub _P, _W  ;// add trip to pointer
            sub _R, _dX ;// subtract remainder with trip value
            jmp @draw_4 ;// draw


        ALIGN 16
        case_5:
        ;//    -W | -1         aP | tP
        ;//-dy---------     I ---------
        ;//   -dx |-dy         aR | tR

            mov _I, _dY
            mov _R, _dX

    @draw_5:dec _I      ;// dcrease the count
            mov [_P],_C ;// draw the color
            js  all_done;// exit if done
            add _R, _dX ;// advance Remainder
            sub _P, _W  ;// advance pointer
            cmp _R, _dY ;// check remainder
            jb  @draw_5 ;// draw if no trip
            dec _P      ;// add trip to pointer
            sub _R, _dY ;// subtract remainder with trip value
            jmp @draw_5 ;// draw



        ALIGN 16
        case_45_equal:
        ;//     -W-1           aP | tP
        ;// I ---------     I ---------
        ;//    aR | tR         aR | tR

            inc _W
            neg _W
        ;// jmp @45_degrees



ALIGN 16
@45_degrees:

        dec _W      ;// _W must already be set

    @@: dec _dX     ;// decrease the count
        stosb       ;// draw the color
        js  all_done;// exit if done
        add _P, _W  ;// advance Remainder
        jmp @B





ALIGN 16
case_horizontal_pos:
;//      +1            aP | tP
;// I ---------     I ---------
;//                    aR | tR

        DEBUG_IF <!!_dX>    ;// not supposed to be zero
        ;//mov ecx, _dX
        rep stosb
        jmp all_done

ALIGN 16
case_horizontal_neg:
;//      -1            aP | tP
;// I ---------     I ---------
;//                    aR | tR


        DEBUG_IF <!!_dX>    ;// not supposed to be zero
        std
        ;//mov ecx, _dX
        rep stosb
        jmp all_done_D


ALIGN 16
case_vertical:

    sub _dY, st_Y0
    js case_vertical_neg
    je case_dot

    case_vertical_pos:
    ;//      +W                aP | tP
    ;// I ---------         I ---------
    ;//                        aR | tR

        dec _W

    @@: dec _dY     ;// dcrease the count
        stosb
        js  all_done;// exit if done
        add _P, _W
        jmp @B


    ALIGN 16
    case_vertical_neg:
    ;//      -W                aP | tP
    ;// I ---------         I ---------
    ;//                        aR | tR

        neg _dY ;// have to make count positive
        inc _W

    @@: dec _dY      ;// dcrease the count
        stosb
        js  all_done;// exit if done
        sub _P, _W
        jmp @B



ALIGN 16
all_done_D:

    cld
    jmp all_done


ALIGN 16
case_dot:
;//       0                aP | tP
;// I ---------         I ---------
;//                        aR | tR

    stosb
    jmp all_done


ALIGN 16
all_done:

    pop edi
    pop esi
    pop ebp
    pop ebx

    ret

dib_DrawLine    ENDP

;//
;//
;//     dib_DrawLine
;//
;////////////////////////////////////////////////////////////////////




;////////////////////////////////////////////////////////////////////
;//                                         public function
;//
;//     dib_FillRect_ptr_ptr_height         fills pixels between p0 and p1
;//





ASSUME_AND_ALIGN
dib_FillRect_ptr_ptr_height PROC    ;// STDCALL pStart pStop height

        st_p0 TEXTEQU <(DWORD PTR [esp+4])>
        st_p1 TEXTEQU <(DWORD PTR [esp+8])>
        st_h  TEXTEQU <(DWORD PTR [esp+0Ch])>

        ASSUME ebx:PTR DIB_CONTAINER

        DEBUG_IF <!!([ebx].shape.dwFlags & SHAPE_IS_DIB) >  ;// supposed to be a dib

    ;// determine the loop parameters

        xchg edi, st_p0     ;// get the start spot (and store edi)

        xchg esi, st_p1     ;// get the stop pointer and store esi

        sub esi, edi        ;// stop - start = width

        DEBUG_IF <SIGN? || ZERO?>   ;// width is backwards bad bad bad

        mov edx, [ebx].shape.siz.x;// get the total width

        xchg ebx, st_h      ;// get the height and store ebx

        sub edx, esi        ;// subtract line width to get wrap

        DEBUG_IF <SIGN? || ZERO?>   ;// wrap is backwards bad bad bad

    ;// do the loop

        .REPEAT
            mov ecx, esi    ;// load the width
            rep stosb       ;// fill the bytes
            add edi, edx    ;// scoot edi to start of next line
            dec ebx         ;// decrease the count
        .UNTIL ZERO?

    ;// clean up

        mov edi, st_p0
        mov esi, st_p1
        mov ebx, st_h

    ;// exit

        ret 0Ch

dib_FillRect_ptr_ptr_height ENDP


IFDEF DEBUGBUILD
ASSUME_AND_ALIGN
dib_VerifyDibs PROC uses ebx

    push eax

    slist_GetHead dib, ebx
    .WHILE ebx

        or eax, [ebx].shape.pSource
        .IF !ZERO?
            invoke IsBadWritePtr, eax, 1
            DEBUG_IF <eax>  ;// this is an invalid ptr
        .ENDIF
        or eax, [ebx].shape.pMask
        .IF !ZERO?
            invoke IsBadWritePtr, eax, 1
            DEBUG_IF <eax>  ;// this is an invalid ptr
        .ENDIF
        or eax, [ebx].shape.pOut1
        .IF !ZERO?
            invoke IsBadWritePtr, eax, 1
            DEBUG_IF <eax>  ;// this is an invalid ptr
        .ENDIF
        or eax, [ebx].shape.pOut2
        .IF !ZERO?
            invoke IsBadWritePtr, eax, 1
            DEBUG_IF <eax>  ;// this is an invalid ptr
        .ENDIF
        or eax, [ebx].shape.pOut3
        .IF !ZERO?
            invoke IsBadWritePtr, eax, 1
            DEBUG_IF <eax>  ;// this is an invalid ptr
        .ENDIF
        or eax, [ebx].shape.hDC
        .IF !ZERO?
            invoke GetHandleInformation, eax, esp
            ;//DEBUG_IF <!!eax>, GET_ERROR ;// this is an invalid handle
            xor eax, eax
        .ENDIF
        or eax, [ebx].shape.hBmp
        .IF !ZERO?
            invoke GetHandleInformation, eax, esp
            ;//DEBUG_IF <!!eax>, GET_ERROR  ;// this is an invalid handle
            xor eax, eax
        .ENDIF

        slist_GetNext dib, ebx      ;// get the next slot

    .ENDW

    pop eax

    ret

dib_VerifyDibs  ENDP
ENDIF





ASSUME_AND_ALIGN




END