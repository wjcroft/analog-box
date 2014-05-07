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
;//                 -- added code for 1K and 1M clock cycle display
;//
;//##////////////////////////////////////////////////////////////////////////
;//
;//     clocks.asm          routines to manage the display of clock cycles
;//
OPTION CASEMAP:NONE
.586
.MODEL FLAT

    .NOLIST
    INCLUDE <ABox.inc>
    .LIST

.DATA

    comment ~ /*

    Design considerations:

        Clock cycle display is limited to 4 characters.
            Four characters is about the width of the thinest object (vertical slider).
            More than four characters did not appear pleasing to the author.
            More characters take longer to render.
        The display is to be right justified with no leading zeros.
            In the common case of rapidly fluctuating values,
            right justify helps the user percieve large values
            -- the more significant digits change more slowly and are to the left
            -- while the rpidly changing least significant digits are stuffed over to the right
        Because there only 4 characters, numbers larger than 9999 can not be displayed.
            Although such large cycle counts are uncommon for single ABox objects,
            they are the not uncommon for closed groups of any sophistication.
            A user may be interesting in knowing that such a group is consuming
            such a large number of cycles.

        With that in mind,
        a 'k' or 'M' suffix is used to display values than 9999 clocks per sample.

            'M' for mega -- millions of cycles
            'k' for kilo -- 1000's of cycles
            ''  (unit) -- no suffix for less than 1000 cycles

        Becuase the 'k' or 'M' uses one of the four characters,
        only three characters remain for numbers.
        If a cycle count is greater than 9999, it is displayed as 10k

        We wish to avoid rapid oscillations between 9999 and 10K.
        There is overlap between the two ranges.
            ex: 7890 and 7k represent about the same values.
            Since there is overlap, hysteresis can be used to reduce
            transtions between 'unit' and 'k'.

        #    Display as unit until count rises above 9999,
        #    then display as 'k' until until cycle count drops below 1000.

            Although displayed precision is reduced,
            it should allow the user to quickly note which objects are
            consuming the most cycles.

        In the presence of groups that consume large amounts of cycles
        in bursts then drop back low numbers of cycles, the transition
        between unit and 'k' may be less apparent.
            Perhaps using a bold font for 'k' may help with user perception.

        An argument could be made that after a few display cycles of 'k'
        where the number is less than 10k but greater than 1k,
        should autmatically drop back into 'unit' mode.

            Because of the 'state' storage considerations described below,
            such a feature will be left for later versions of ABox.

        Transitions between M and k mode are less simple because there is
        no overlap between the k and M range as there is between 'unit' and 'k'.
        Thus, hysteresis is not an option. Since consuming millions of cycles
        per sample is thought to be extremely unlikely, no additional was done

        It is possible that the cycle count could rise above 999M -- possible
        but unlikely. Rather than display in 'G' units (giga, biliions),
        a simple '!!!!' indicator can be displayed.

        Moving on to 'how' do we do it:

        Rendering 'k', 'M', and '!' requires the addition of said symbols
        to the clock cycle drawing routine. Since the characters 0-9 are
        already pre-compiled (see clocks_font), adding three more symbols
        is harmless.

        Detection of 'k' and 'M' display modes adds additional 'compare and jump'
        tests to the rendering code. The cpu work of the added tests is
        insignificant -- an extra few cycles in the presense of

        Implementing hysteresis requires 'state' -- knowledge of previous information.
            In this case, knowledge of the previous display mode -- unit,'k' or 'M'.

        'state' requires storage -- a place to hold the past information.
            OSC_OBJECT is the applicable struct where such state should be stored.
            There is no allocated storage for past cycle or display,
            nor is there room in OSC_OBJECT to add a new member to store it.
            (that is say: no room without having to rewrite APIN as well
            -- see notes under OSC_OBJECT in ABox.inc)

        There are bits in OSC_OBJECT.dwCycle that are unlikely to ever be non-zero.
            for instance:
            The 30th bit approximately represents 1 billion clock cycles per sample.
            (billion == 10^9 == 1000000000). Since ABox runs at 44100 samples per second,
            the users CPU would have to be running at 44.1THz (that's TERRA HERTZ, 441000 GHz).
            A similar argument can be made for the 29th bit, noting that each lower bit has
            a correspondingly higher probability of being needed for the count value.

        The sign bit is already used to indicate draw/no draw.
        The remaining 31 bits are (previous to ABox242) used for the cycle count.

        With that in mind:

        #    The top 3 bits of OSC_OBJECT.dwClocks are now used for display state.

        The routines in play_Calc (in abox_Play.asm) will need to be adjusted
        in order to preserve the state information -- currently they just overwrite
        the whole dword. This will require a 'load, mask, or, and store' sequence
        of instructions -- which adds 3 instructions to the existing 2 writes and 1 list insert.


    Data Implementation:

        The bits of OSC_OBJECT.dwClocks are divided into the following struct

            s mm c cccc cccc cccc cccc cccc cccc cccc

            where

                s    bit 31    sign bit    display/no display
                mm    bit 30 and 29        previous display mode
                c    bits 28 to 0        clock cycle count

        The mm field

            00        units
            01        'k'
            10        'M'
            11        none of the above, perhaps one of
                    -- part of the display flush sequence (sign bit was set)
                    -- or overflow

    */ comment ~


             ;//    0   1   2   3   4   5   6   7   8   9  10  11   12
    clocks_font dd '0','1','2','3','4','5','6','7','8','9','K','M', '!'
        ;// fonts 0 through 9 for displaying clocks
        ;// at app start these are characters
        ;// and are transformed into PTR GDI_SHAPE by clocks_Initialize
        CLOCK_FONT_NUM_SYMBOLS EQU 13    ;// total number of symbols
        CLOCK_FONT_BOLD_SYMBOL EQU 10    ;// after the first 10, use bold for the remaining


    ALIGN 8
    clocks_temp_bcd dt  0   ;// temp space for building digits as bcd -- 10 bytes
    ALIGN 8
    clocks_temp_int    dd    0    ;// temp storage for clocks after the mode bits are masked out

    clocks_font_adjust  dd  0   ;// add to osc.pDest to get to center of font
    clocks_rect_adjust  dd  0   ;// add to rect to get to top of what to erase
    clocks_raster_wrap  dd  0   ;// for clearing the block


    ; defined in abox.inc
    ;CLOCKS_RECT_WIDTH  EQU 24  ;// width of the block (must be multiple of 4)
    ;CLOCKS_RECT_HEIGHT EQU 8   ;// height of the block

    CLOCKS_CHAR_SPACING EQU 5   ;// character spacing for clocks
    CLOCKS_RECT_CENTER  EQU 4   ;// centerline for drawing

.CODE

ASSUME_AND_ALIGN
clocks_Initialize PROC

    ;// our task is make sure the ten characters are assigned
    ;// and determine the adjuster for TL

    ;// get the 12 characters

        xor ebx, ebx

        ;// decimal digits use font_pin
        ;// k and M use font_bus (bold)

        pushd OFFSET font_pin_slist_head
        .REPEAT
            mov edi, DWORD PTR [esp]        ;// load the font we want to draw with
            mov eax, clocks_font[ebx*4]     ;// load character
            invoke font_Locate              ;// locate the font
            mov clocks_font[ebx*4], edi     ;// store in table
            inc ebx                         ;// iterate
            .IF ebx==CLOCK_FONT_BOLD_SYMBOL
                mov DWORD PTR [esp], OFFSET font_bus_slist_head
            .ENDIF
        .UNTIL ebx >= CLOCK_FONT_NUM_SYMBOLS
        add esp, 4

    ;// build the adjusters

        mov ecx, gdi_bitmap_size.x      ;// load the bitmap width

        ;// determine the center line offset for printing

        mov eax, -CLOCKS_RECT_CENTER
        imul ecx
        add eax, CLOCKS_CHAR_SPACING/2
        mov clocks_font_adjust, eax     ;// store the results

        ;// determine the top of rect offset for clearing

        mov eax, -CLOCKS_RECT_HEIGHT    ;// pin height
        imul ecx
        mov clocks_rect_adjust, eax     ;// store the results

        sub ecx, CLOCKS_RECT_WIDTH
        mov clocks_raster_wrap, ecx

    ;// that's it

        ret

clocks_Initialize ENDP




ASSUME_AND_ALIGN
clocks_Render PROC  uses esi edi

    ASSUME esi:PTR OSC_OBJECT
    ASSUME ebx:PTR GDI_SHAPE    ;// forward assume


    DEBUG_IF < clocks_font[0] !< 100h > ;// table wasn't initialized

    ;// build the shape iterator

        mov edi, [esi].pDest        ;// load the osc from pDest

    .IF edi > gdi_pBitsGutter       ;// make it's on the screen

        add edi, clocks_font_adjust ;// adjust to center line of rectangle

        push edi                    ;// store as our iterator

    ;// stack:
    ;// dest    edi esi ret ...
    ;// 00      04  08  0Ch

        st_dest TEXTEQU <(DWORD PTR [esp])>

    ;// erase what was there

        mov edi, [esi].pDest        ;// load the osc from pDest
        add edi, clocks_rect_adjust ;// adjust to top of

        mov eax, F_COLOR_DESK_BACK
        mov ebx, CLOCKS_RECT_HEIGHT
        mov edx, CLOCKS_RECT_WIDTH/4
    @@: mov ecx, edx
        rep stosd
        add edi, clocks_raster_wrap
        dec ebx
        jnz @B

    ;// make sure we are supposed to show clocks for this object

    ;// ecx is zero
    or ecx, [esi].dwClocks    ;// smmc cccc cccc cccc cccc cccc cccc cccc
    .IF !SIGN?                ;// 0mmc cccc cccc cccc cccc cccc cccc cccc

        mov eax, ecx                    ;// eax copy, used to extract out the value
        and eax, CLOCK_CYCLE_TEST       ;// mask out the mode, leave the value
        mov clocks_temp_int, eax        ;// store in temp
        shr ecx, CLOCK_CYCLE_MODE_SHIFT ;// shift mm down to a value 0-3
        fild clocks_temp_int            ;// load into fpu
        jmp clock_cycle_state[ecx*4]    ;// jump to the state
        .DATA
        clock_cycle_state LABEL DWORD   ;// jump table
            dd ccs_00
            dd ccs_01
            dd ccs_10
            dd ccs_11
        .CODE
        ccs_00::    ;// in unit mode
            CMPJMP eax,     10000, jae enter_ccs_01    ;// to 'k' mode
            CMPJMP eax,   1000000, jae enter_ccs_10    ;// enter M mode
            CMPJMP eax, 999999999, ja  enter_ccs_11    ;// overflow!!
            jmp do_ccs_00                              ;// still in 'unit' mode
        ccs_01::    ;// in 'k' mode
            CMPJMP eax,      5000, jbe enter_ccs_00    ;// transition to unit mode -- at 5K ... why not ?
            CMPJMP eax,   1000000, jae enter_ccs_10    ;// transition to M mode
            CMPJMP eax, 999999999, ja  enter_ccs_11    ;// overflow!!
            jmp do_ccs_01                              ;// still in 'k' mode
        ccs_10::    ;// in 'M' mode
            CMPJMP eax,     10000, jb enter_ccs_00     ;// to unit ... too much of a jump ??
            CMPJMP eax,   1000000, jb enter_ccs_01     ;// to 'k' mode ... check for unit mode??
            CMPJMP eax, 999999999, ja enter_ccs_11     ;// overflow!!
            jmp do_ccs_10                              ;// still in 'M' mode
        ccs_11::    ;// previously not displayed -- or was overflow
            CMPJMP eax,     10000, jb  enter_ccs_00    ;// enter unit mode
            CMPJMP eax,   1000000, jb  enter_ccs_01    ;// enter k mode
            CMPJMP eax,1000000000, jb  enter_ccs_10    ;// enter M mode
            jmp do_ccs_11                              ;// still in overflow mode

        ;// pairs of enter,do
        ;// enter_X        entering from a different state -- so have to store new state bits
        ;//                eax has the value to store sans state bits
        ;// do_X        fpu has the full cycle count to display
        ;//                reduce fput value to display at most 4 digits and jmp to drawing code
        ;//                when needed, ecx already indexes the suffix to use

        ;// unit mode
        enter_ccs_00:    mov [esi].dwClocks, eax    ;// store back, without any additional unit bits
        do_ccs_00:       jmp draw_four_digits
        ;// 'k' mode
        enter_ccs_01:    or eax, CLOCK_CYCLE_MODE_01    ;// add the bit
                         mov [esi].dwClocks, eax        ;// store it
        do_ccs_01:       fmul math_1_1000               ;// kilo units
                         jmp draw_three_digits
        ;// 'M' mode
        enter_ccs_10:    or eax, CLOCK_CYCLE_MODE_10    ;// add the bit
                         mov [esi].dwClocks, eax        ;// store it
        do_ccs_10:       fmul math_Millionth            ;// mega units
                         jmp draw_three_digits
        ;// overflow
        enter_ccs_11:    or eax, CLOCK_CYCLE_MODE_11    ;// add the bit
                         mov [esi].dwClocks, eax        ;// store it
        do_ccs_11:

            ;// render '!!!!'
            ;// and done

            fstp st    ;// empty the fpu

            add ecx, CLOCK_FONT_BOLD_SYMBOL-1    ;// because ecx=1 for the
            mov ebx, clocks_font[ecx*4]          ;// get the shape pointer for this digit
            mov ebx, [ebx].pMask                 ;// load the masker for the font
            mov eax, F_COLOR_DESK_TEXT           ;// load the color to draw with

            mov ecx, 4
            .REPEAT
                mov edi, st_dest
                push ebx
                push ecx
                invoke shape_Fill                   ;// draw the text
                pop ecx
                pop ebx
                add st_dest, CLOCKS_CHAR_SPACING    ;// scoot iterator to next char
                dec ecx
            .UNTIL ZERO?

            jmp done_with_display

        ;// used for ecx = 01 or 10 modes
        ALIGN 8
        draw_three_digits:    ;// plus the suffix -- ecx

            fbstp clocks_temp_bcd    ;// store as decimal in temp

            ;// draw the suffix

            mov edi, st_dest
            add edi, CLOCKS_CHAR_SPACING*3 + 2   ;// position at 4th digit + 2 pixels for bold
            add ecx, CLOCK_FONT_BOLD_SYMBOL-1    ;// because ecx=1 for the

            mov ebx, clocks_font[ecx*4]          ;// get the shape pointer for this digit
            mov ebx, [ebx].pMask                 ;// load the masker for the font

            mov eax, F_COLOR_DESK_TEXT           ;// load the color to draw with

            invoke shape_Fill                    ;// draw the text

            ;// now jump to the routine that starts checking at the next to top digit

            mov ecx, DWORD PTR clocks_temp_bcd   ;// load the lower four digits
            mov edi, st_dest                     ;// get the X iterator
            jmp check_second_digit

        ALIGN 8
        draw_four_digits:

            fbstp clocks_temp_bcd                ;// store as decimal in temp
            mov eax, F_COLOR_DESK_TEXT           ;// load the color
            mov ecx, DWORD PTR clocks_temp_bcd   ;// load the lower four digits
            mov edi, st_dest                     ;// get the X iterator

        ;// scan the four digits / or three digits
        ;// ignore until first non zero
        ;// always draw the fourth digit
        ;// entering at any particular check can draw it and the remaining
        ;//
        ;// eax must have the color to draw with
        ;// ecx must have the bcd value of the ower four digits
        ;// edi must point at where to draw

        check_first_digit:
            TESTJMP ecx, 0000F000h, jnz draw_first_digit
            add edi, CLOCKS_CHAR_SPACING
        check_second_digit:
            TESTJMP ecx, 00000F00h, jnz draw_second_digit
            add edi, CLOCKS_CHAR_SPACING
        check_third_digit:
            TESTJMP ecx, 000000F0h, jnz draw_third_digit
            add edi, CLOCKS_CHAR_SPACING
        check_fourth_digit:
            jmp draw_fourth_digit

        ;// draw said digit and all that follow
        ;// edi must point at where to draw
        ;// eax must have the color
        draw_first_digit:
            mov st_dest, edi                    ;// store iterator back on stack
            mov ecx, DWORD PTR clocks_temp_bcd  ;// load as a dword
            and ecx, 0000F000h                  ;// strip off extra
            shr ecx, 12-2                       ;// scoot to index
            mov ebx, clocks_font[ecx]           ;// get the shape pointer for this digit
            mov ebx, [ebx].pMask                ;// load the masker for the font
            invoke shape_Fill                   ;// draw the text
            mov edi, st_dest                    ;// get the X iterator
            add edi, CLOCKS_CHAR_SPACING        ;// scoot iterator to next char
        draw_second_digit:
            mov st_dest, edi                    ;// store iterator back on stack
            mov ecx, DWORD PTR clocks_temp_bcd  ;// load as a dword
            and ecx, 00000F00h                  ;// strip off extra
            shr ecx, 8-2                        ;// scoot to index
            mov ebx, clocks_font[ecx]           ;// get the shape pointer for this digit
            mov ebx, [ebx].pMask                ;// load the masker for the font
            invoke shape_Fill                   ;// draw the text
            mov edi, st_dest                    ;// get the X iterator
            add edi, CLOCKS_CHAR_SPACING        ;// scoot iterator to next char
        draw_third_digit:
            mov st_dest, edi                    ;// store iterator back on stack
            mov ecx, DWORD PTR clocks_temp_bcd  ;// load as a dword
            and ecx, 000000F0h                  ;// strip off extra
            shr ecx, 4-2                        ;// scoot to index
            mov ebx, clocks_font[ecx]           ;// get the shape pointer for this digit
            mov ebx, [ebx].pMask                ;// load the masker for the font
            invoke shape_Fill                   ;// draw the text
            mov edi, st_dest                    ;// get the X iterator
            add edi, CLOCKS_CHAR_SPACING        ;// scoot iterator to next char
        draw_fourth_digit:
            ;// mov st_dest, edi                ;// store iterator back on stack
            mov ecx, DWORD PTR clocks_temp_bcd  ;// load as a dword
            and ecx, 0000000Fh                  ;// strip off extra
            mov ebx, clocks_font[ecx*4]         ;// get the shape pointer for this digit
            mov ebx, [ebx].pMask                ;// load the masker for the font
            invoke shape_Fill                   ;// draw the text

    .ENDIF  ;// clock value was not to be displayed

    done_with_display:
    ;// that's it

        add esp, 4
        st_dest TEXTEQU <>

    .ENDIF  ;// on screen

        ret

clocks_Render ENDP




ASSUME_AND_ALIGN


END