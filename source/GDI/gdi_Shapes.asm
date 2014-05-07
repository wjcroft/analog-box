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
;// shapes.asm      this file includes:
;//
;//                 common shapes
;//                 the shape implemenation
;//
;// TOC:
;//
;// shape_Move
;// shape_Fill
;// shape_Test
;// rasterize
;// shape_Build
;// shape_Destroy
;// dib_initialize_shape
;// shape_Intersect
;// show_intersectors
;// gdi_VerifyShapes





OPTION CASEMAP:NONE
.586
.MODEL FLAT

    .NOLIST
    include <ABox.inc>
    .LIST

.DATA


    GDI_MAX_SCAN equ 20000h ;// limit for screen searching


;/////////////////////////////////////////////////////////////////////////////
;//
;//
;//     LISTS
;//

    ;// head of list for walking shapes

    slist_Declare shape_list, OFFSET shape_trig_both
    gdi_temp_buffer dd  0

;//
;//     LISTS
;//
;//
;/////////////////////////////////////////////////////////////////////////////


;// optimize flag, needed to keep the fonts working

    gdi_bNoOptimize dd  0   ;// ONLY font build should set this


;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;///
;///    SHAPE RENDERERS
;///

;// these next three sections of code are designed to use a RASTER_LINE record


;// these equates help out the various rasterizers

    RASTER_EXIT_JUMP    EQU 0   ;// always index 0
    RASTER_1_BYTE_JUMP  equ 1   ;// always index 1
    RASTER_DWORD_JUMP   equ 8   ;// the dword jump is always the 8th record
    RASTER_DWORD_2_JUMP equ 10  ;// always the tenth record
    RASTER_LINE_JUMP    equ 12  ;// line jumps are always the twelth record



.CODE
;/////// mover ////////////////////////
;//
;//   blits from esi to edi
;//
;//     ebx must point at GDI_RASTER_RECORD
;//     esi must be the refence point on the source surface
;//     edi must be the reference point on the destination surface
;//
;// destroys all GP registers

ASSUME_AND_ALIGN
shape_Move PROC

    ;// new version

                    push ebp
                    lea ebp, move_jump_table

                    ASSUME ebp:PTR DWORD
                    ASSUME ebx:PTR RASTER_LINE

                        mov eax, [ebx].jmp_to
                        add edi, [ebx].dest_wrap
                        add esi, [ebx].source_wrap
                        jmp [ebp+eax*4]

    move_multi_three::  movsb
    move_multi_two::    movsb
    move_multi_one::    movsb
    move_multi_zero::   mov ecx, [ebx].dw_count

                        add ebx, SIZEOF RASTER_LINE

                        rep movsd

                        mov eax, [ebx].jmp_to
                        add edi, [ebx].dest_wrap
                        add esi, [ebx].source_wrap
                        jmp DWORD PTR [ebp+eax*4]

    move_seven_bytes::  movsb
    move_six_bytes::    movsb
    move_five_bytes::   movsb
    move_four_bytes::   add ebx, SIZEOF RASTER_LINE

                        movsd

                        mov eax, [ebx].jmp_to
                        add edi, [ebx].dest_wrap
                        add esi, [ebx].source_wrap
                        jmp [ebp+eax*4]

    move_three_bytes::  movsb
    move_two_bytes::    movsb
    move_one_byte::     add ebx, SIZEOF RASTER_LINE

                        movsb

                        mov eax, [ebx].jmp_to
                        add edi, [ebx].dest_wrap
                        add esi, [ebx].source_wrap
                        jmp [ebp+eax*4]

    move_exit::         pop ebp
                        ret


    move_multi_lines::  mov edx, [ebx].dw_count     ;// line count is in high word
                        mov eax, edx                ;// xfer to eax
                        shr edx, 16                 ;// move to lower
                        and eax, 0FFFFh             ;// mask out line count
    move_lines_next:    mov ecx, eax                ;// get count
                        rep movsd                   ;// move the values
                        dec edx                     ;// decrease the line count
                        jz  move_lines_exit         ;// jump back to main loop
                        add edi, [ebx].dest_wrap        ;// add the dest wrap
                        add esi, [ebx].source_wrap      ;// add the source wrap
                        jmp move_lines_next         ;// jump to top

    move_lines_exit:    add ebx, SIZEOF RASTER_LINE
                        mov eax, [ebx].jmp_to
                        add edi, [ebx].dest_wrap
                        add esi, [ebx].source_wrap
                        jmp [ebp+eax*4]

shape_Move ENDP




.DATA
                                                    ;// index   bytes moved
    move_jump_table dd  OFFSET move_exit            ;// 0       0
                    dd  OFFSET move_one_byte        ;// 1       1
                    dd  OFFSET move_two_bytes       ;// 2       2
                    dd  OFFSET move_three_bytes     ;// 3       3
                    dd  OFFSET move_four_bytes      ;// 4       4
                    dd  OFFSET move_five_bytes      ;// 5       5
                    dd  OFFSET move_six_bytes       ;// 6       6
                    dd  OFFSET move_seven_bytes     ;// 7       7
                    dd  OFFSET move_multi_zero      ;// 8       4x+0
                    dd  OFFSET move_multi_one       ;// 9       4x+1
                    dd  OFFSET move_multi_two       ;// 10      4x+2
                    dd  OFFSET move_multi_three     ;// 11      4x+3
                    dd  OFFSET move_multi_lines     ;// 12      4x*y

.CODE

;////////////////////////////////////////////////////////////////////
;//
;//
;//     filler      same code as mover, but stores the value in eax
;//                 eax should be a packed color index
;//                 remarkably eax, is preserved
;//
;//   fills edi with eax
;//
;//     ebx must point at GDI_RASTER_RECORD
;//     edi must be the reference point on the destination surface
;//
;// destroys all GP registers

ASSUME_AND_ALIGN
shape_Fill PROC

                        push ebp

                        ASSUME ebp:PTR DWORD
                        ASSUME ebx:PTR RASTER_LINE

                        mov edx, [ebx].jmp_to
                        lea ebp, fill_jump_table
                        add edi, [ebx].dest_wrap

                        cmp edi, gdi_pBmpBits   ;// no matter how hard we try
                        jb fill_exit            ;// we'll still get bad values
                        cmp edi, gdi_pBmpBits_bottom
                        ja fill_exit

                        jmp [ebp+edx*4]

    fill_multi_three::  stosb
    fill_multi_two::    stosb
    fill_multi_one::    stosb
    fill_multi_zero::   mov ecx, [ebx].dw_count

                        add ebx, SIZEOF RASTER_LINE

                        rep stosd

                        mov edx, [ebx].jmp_to
                        add edi, [ebx].dest_wrap
                        jmp DWORD PTR [ebp+edx*4]

    fill_seven_bytes::  stosb
    fill_six_bytes::    stosb
    fill_five_bytes::   stosb
    fill_four_bytes::   add ebx, SIZEOF RASTER_LINE

                        stosd

                        mov edx, [ebx].jmp_to
                        add edi, [ebx].dest_wrap
                        jmp [ebp+edx*4]

    fill_three_bytes::  stosb
    fill_two_bytes::    stosb
    fill_one_byte::     add ebx, SIZEOF RASTER_LINE

                        stosb

                        mov edx, [ebx].jmp_to
                        add edi, [ebx].dest_wrap
                        jmp [ebp+edx*4]

    fill_exit::         pop ebp
                        ret

    fill_multi_lines::  mov edx, [ebx].dw_count ;// line count is in high word
                        mov esi, edx            ;// xfer to esi
                        shr edx, 16             ;// shift to lower
                        and esi, 0FFFFh         ;// mask out extra
    fill_lines_next:    mov ecx, esi            ;// get count
                        rep stosd               ;// fill the values
                        dec edx                 ;// decrease the line count
                        jz  fill_lines_exit     ;// jump back to main loop
                        add edi, [ebx].dest_wrap;// add the dest wrap
                        jmp fill_lines_next     ;// jump to top

    fill_lines_exit:    add ebx, SIZEOF RASTER_LINE
                        mov edx, [ebx].jmp_to
                        add edi, [ebx].dest_wrap
                        jmp [ebp+edx*4]

shape_Fill ENDP




.DATA
                                                    ;// index   bytes filled
    fill_jump_table dd  OFFSET fill_exit            ;// 0       0
                    dd  OFFSET fill_one_byte        ;// 1       1
                    dd  OFFSET fill_two_bytes       ;// 2       2
                    dd  OFFSET fill_three_bytes     ;// 3       3
                    dd  OFFSET fill_four_bytes      ;// 4       4
                    dd  OFFSET fill_five_bytes      ;// 5       5
                    dd  OFFSET fill_six_bytes       ;// 6       6
                    dd  OFFSET fill_seven_bytes     ;// 7       7
                    dd  OFFSET fill_multi_zero      ;// 8       4x+0
                    dd  OFFSET fill_multi_one       ;// 9       4x+1
                    dd  OFFSET fill_multi_two       ;// 10      4x+2
                    dd  OFFSET fill_multi_three     ;// 11      4x+3
                    dd  OFFSET fill_multi_lines     ;// 12      4x*y

.CODE


comment ~ /*

    since the tester only looks at wheather edi and esi ever cross each other
    we can get away with simply adding the jump to to edi

*/ comment ~

;/////// tester ////////////////////////
;//
;// hit testing is acomplished by determining if the screen address of the mouse
;// is inside one of the raster lines in a shape
;// these routines should only be called if the mouse is inside the boundry rect

    ;// assume edi points at the address we're searching for (gdi pointer)
    ;// assume esi is the refence point on the display surface (pDest)
    ;// assume ebx is the move/fill list to scan

    ;// at the top of the loop, esi is assumed to point at the beginning of a raster
    ;// so if esi is beyond edi, we are not hit

    ;// at the second test, esi is at the end of a raster
    ;// so if esi is beyond edi, we are hit (because we passed the first test)

    ;// if we fall off the end, we are not hit

    ;// all GP registers are destroyed

    ;// returns carry flag if hit
    ;//         no carry if not hit

ASSUME_AND_ALIGN
shape_Test  PROC
                        ASSUME ebx:PTR RASTER_LINE

    ;// esi is at the start of a line

    test_top_of_loop:

        mov edx, [ebx].jmp_to   ;// load the jumper now (cache line)
        add esi, [ebx].dest_wrap;// advance to next line
        cmp esi, edi            ;// test esi with edi
        ja test_exit_no_hit     ;// if esi is beyond edi, we are not hit

;// advance to end of line

        .IF !edx                ;// if zero we have to exit
            jmp test_exit_no_hit;// jump to exit, we're not hit
        .ENDIF

        .IF edx > 7                     ;// see if we've multiple dwords
            mov ecx, [ebx].dw_count     ;// get the count
            .IF edx == RASTER_LINE_JUMP ;// check for multiple lines

                    ;// special code for dib's, which are always dword aligned

                    mov edx, ecx            ;// load the line count (already in ecx
                    shr edx, 16             ;// move down into lower realm
                    and ecx, 0FFFFh         ;// mask off line count
                    shl ecx, 2              ;// convert to byte value

                    ;// at begin of line, move to end of line
            @01:    add esi, ecx            ;// add the byte count
                    ;// now at end of line
                    ;// check if end of line is now beyond edi
                    cmp esi, edi            ;// cmp end of line
                    jae test_exit_hit       ;// is esi is now beyond edi, we are hit
                    dec edx                 ;// check if we're done with lines
                    jz  test_loop_next      ;// jump to next loop
                    ;// jump to begin of next line
                    add esi, [ebx].dest_wrap;// advance to next line
                    cmp esi, edi            ;// test esi with edi
                    ja test_exit_no_hit     ;// if esi is beyond edi, we are not hit
                    jmp @01                 ;// jump to our loop

            .ENDIF

            and edx, 3              ;// strip off extra
            lea edx, [edx+ecx*4]    ;// accumulate the dwords and the extra

        .ENDIF

        add esi, edx                ;// advance esi

    ;// esi is at the end of a line

                        cmp esi, edi            ;// cmp end of line
                        jae test_exit_hit       ;// is esi is now beyond edi, we are hit

    ;// look at next record
    test_loop_next:     add ebx, SIZEOF RASTER_LINE ;// advance to next record
                        jmp test_top_of_loop



    test_exit_no_hit:   clc     ;// clear the carry flag
                        ret

    test_exit_hit:      stc     ;// set the carry flag
                        ret


shape_Test  ENDP









;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;///
;///
;///    RASTERIZER
;///
comment ~ /*

    to build these shapes, we draw them on the screen, then scan them
    building the raster list as we go

    the rasterizer simply searches for non zero

         fill in records in the passed pointer (ebp)
         returns one passed the end in the same pointer

        upon entering:
        the picture is assumed to be referenced to 0,0 on gdi_pBitmap
        ebx must point at the jump table to use

        all registers except esp are destroyed

*/ comment ~


.CODE

ASSUME_AND_ALIGN
rasterize PROC PRIVATE

    ASSUME ebp:PTR RASTER_LINE  ;// ebp must point at zeroed memory

    ;// set up the scan loop

        mov edi, gdi_pBmpBits       ;// edi will track the current point
        xor ebx, ebx                ;// ebx keeps track of lines for the optimaizer
        mov esi, edi                ;// esi is a tag along value for determining offsets

;// scan
top_of_loop:

    ;// search for the beginning of the next record
    ;// by looking for a non zero color

        mov ecx, GDI_MAX_SCAN   ;// ecx sets the limit
        xor eax, eax            ;// zero eax
        repe scasb              ;// look for non zero

        .IF ecx     ;// find anything ?

        ;// determine the correct soure and dest offset

            dec edi                 ;// edi is one passed
            mov eax, edi            ;// xfer to eax
            sub eax, esi            ;// eax is dest_wrap
            xor edx, edx            ;// clear for dividing
            mov esi, edi            ;// xfer current to tag along
            mov [ebp].dest_wrap, eax    ;// store the dest_wrap now

            ;// if we wrapped the source, we need to compute the correct adjustment
            ;// we also have to make sure to account for multiple lines

            div gdi_bitmap_size.x   ;// eax has lines
                                    ;// edx has remainder
            .IF edx > oBmp_width
                sub edx, gdi_bitmap_size.x
                inc eax
            .ENDIF

            shl eax, LOG2(oBmp_width)
            add eax, edx

            mov [ebp].source_wrap, eax      ;// now store source wrap

        ;// now determine the number of bytes that are on this section

            mov ecx, GDI_MAX_SCAN   ;// load the max count
            xor eax, eax            ;// eax must be 0
            repne scasb             ;// look for not zero

        ;// determine the count

            dec edi         ;// edi is one passed
            mov eax, edi    ;// xfer current to eax
            sub eax, esi    ;// eax is now the byte count
            mov esi, edi    ;// xfer to tag along register

        ;// determine the jump_to offset

            .IF eax < 8     ;// if count is less than 8
                mov [ebp].dw_count, 0   ;// set to zero for the font function
            .ELSE           ;// count is greater than 8
                mov edx, eax            ;// xfer to edx
                shr edx, 2              ;// edx equals dword count
                and eax, 3              ;// strip off extra from eax (also test for dword align)
                mov [ebp].dw_count, edx ;// store dw count in record
            ;// here, we can use the optimized dword loop
            ;// but we have to compare some things first
                jnz skip_optimize       ;// skip if eax is not zero
                cmp gdi_bNoOptimize, 0  ;// see if we allow any checks
                jnz skip_optimize
                or ebx, ebx             ;// can't optimize the first line
                jz skip_optimize
                cmp dx, WORD PTR [ebp-SIZEOF RASTER_LINE].dw_count      ;// counts must match
                jnz skip_optimize
                cmp [ebp-SIZEOF RASTER_LINE].jmp_to, RASTER_DWORD_JUMP  ;// jump's must be DWORD
                jz keep_trying_to_optimize
                cmp [ebp-SIZEOF RASTER_LINE].jmp_to, RASTER_LINE_JUMP   ;// or a previous optimize
                jnz skip_optimize
            keep_trying_to_optimize:
                mov edx, [ebp].source_wrap
                cmp edx, [ebp-SIZEOF RASTER_LINE].source_wrap   ;// source wraps must match
                jnz skip_optimize
                mov edx, [ebp].dest_wrap
                cmp edx, [ebp-SIZEOF RASTER_LINE].dest_wrap     ;// dest wraps must match
                jnz skip_optimize

            now_we_can_optimize:

                mov [ebp-SIZEOF RASTER_LINE].jmp_to, RASTER_LINE_JUMP   ;// set as optimized
                inc WORD PTR [ebp-SIZEOF RASTER_LINE].dw_count[2]       ;// increase the line count
                jmp top_of_loop                                         ;// do NOT advance ebp

            skip_optimize:
                add eax, 8              ;// add eight back to index
            .ENDIF
            mov [ebp].jmp_to, eax       ;// store in jmp_to

        ;// advance to next record

            add ebp, SIZEOF RASTER_LINE
            inc ebx             ;// set the first line flag

            jmp top_of_loop

        .ENDIF

    ;// when we get here, we're done
    ;// eax will also equal zero, which is always the exit
        mov [ebp].jmp_to, eax       ;// store exit in record
        add ebp, SIZEOF RASTER_LINE ;// return one passed the end

    ;// that's it

        ret

rasterize ENDP
;///
;///
;///    RASTERIZER
;///
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////














;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;///
;///    BUILDERS
;///
comment ~ /*

    this code draws the shape on the screen
    then builds the desired raster tables

*/ comment ~


ASSUME_AND_ALIGN
shape_Build PROC

;// debug traps, leave off
;// DEBUG_IF <ebx==(OFFSET r_rect_container.shape)>
;// DEBUG_IF <ebx==(OFFSET knob_shape_cont)>
;// DEBUG_IF <ebx==(OFFSET noise_container.shape)>
;// DEBUG_IF <ebx==(OFFSET mixer_container.shape)>

    ;// this function will build the tables and pointers needed for a shape
    ;// it can also initialize a container and an intersector

    ;// define the local variables

        ;// stack will look like this
        ;// d_ofs   s_ofs   pPoint  flags   pShape  ebp     ret
        ;// +00     +04     +08     +0C     +10     +14     +18

    call_depth = 0      ;// call_depth keeps track of the stack so our local functions can access


        d_ofs   TEXTEQU <(DWORD PTR [esp+00h+call_depth*4])>    ;// value to offset raster destination
        s_ofs   TEXTEQU <(DWORD PTR [esp+04h+call_depth*4])>    ;// value to offset raster source
        l_point TEXTEQU <(DWORD PTR [esp+08h+call_depth*4])>    ;// pointer to start of points workspace

        flags   TEXTEQU <(DWORD PTR [esp+0Ch+call_depth*4])>    ;// stored flags
        pShape  TEXTEQU <(DWORD PTR [esp+10h+call_depth*4])>    ;// stored ebx
        st_ebp  TEXTEQU <(DWORD PTR [esp+14h+call_depth*4])>    ;// stored ebp

    stack_size = 18h    ;// stack size just makes this easier to edit

    ASSUME ebx:PTR GDI_SHAPE    ;// ebx points at the shape and must be preserved
                                ;// all other registers are destroyed

        sub esp, stack_size     ;// storage space
        mov ecx, [ebx].dwFlags  ;// load flags now

    DEBUG_IF <ecx & SHAPE_INITIALIZED>      ;// why are we calling this ?


    ;// store registers

        mov st_ebp, ebp
        mov pShape, ebx
        mov flags, ecx

        mov ebp, gdi_temp_buffer    ;// ebp is going to iterate all the structs
        ASSUME ebp:PTR fPOINT

    ;// if we're a polygon, generate a sincos table

        bt ecx, LOG2(SHAPE_IS_POLYGON)
        .IF CARRY?

            mov eax, 0FFFFh         ;// mask for num points
            mov esi, [ebx].pPoints  ;// load the source pointer
            ASSUME esi:PTR fPOINT
            and eax, ecx            ;// mask in the number points

            .REPEAT

                fld [esi].y     ;// angle
                fsincos         ;// cos sin
                fstp [ebp].x
                fstp [ebp].y
                add esi, SIZEOF fPOINT
                add ebp, SIZEOF fPOINT
                dec eax

            .UNTIL ZERO?

            mov l_point, ebp        ;// store for future reference

            ;// add extra space for points we're going to generate

            mov eax, 0FFFFh         ;// mask for num points
            and eax, ecx            ;// mask in the number points
            shl eax, LOG2( SIZEOF POINT )   ;// turn into an offset
            add ebp, eax            ;// add on to ebp

        .ENDIF

    ;// determine the common offset for all points
    ;// this will be stored in fpu for the duration

        fld math_16
        bt ecx, LOG2(SHAPE_RGN_OFS_OC)
        fld st
        .IF CARRY?
            fadd [ebx].OC.x
            fxch
            fadd [ebx].OC.y
            fxch            ;// OCx     OCy
        .ENDIF

    ;// determine the common offset for all destinations

        bt ecx, LOG2( SHAPE_MOVE_DST_OC )
        mov eax, gdi_bitmap_size.x  ;// load the bitmap width (y*...)
        jnc test_dst_p1

            ;// all destinations must be offset by OC+16

            fld st          ;// OCx     OCx     OCy
            fld st(2)       ;// OCy     OCx     OCx     OCy

            jmp compute_dest_offset

    test_dst_p1:

        bt ecx, LOG2( SHAPE_MOVE_DST_SIZ )
        jnc use_default_dest

            ;// all destiantions are offset by user param P1 + 16

            fld [ebx].siz.x
            fadd math_16
            fld [ebx].siz.y
            fadd math_16

    compute_dest_offset:

        ;// FPU has disposable y and x
        ;// eax has gdi_bitmap_width

            ;// compute d_ofs
            sub esp, 8              ;// make some room

            fistp DWORD PTR [esp+4] ;// store OCy
            fistp DWORD PTR [esp]   ;// store OCy
            mul DWORD PTR [esp+4]   ;// y*width
            add eax, DWORD PTR [esp];// +x = offsets

        call_depth=2

            mov d_ofs, eax

            ;// compute s_ofs
            mov eax, DWORD PTR [esp+4]
            shl eax, LOG2( oBmp_width )
            add esp, 8              ;// free extra room
            add eax, 16

        call_depth = 0

            jmp done_with_dst_tests

    use_default_dest:

            ;// all destinations are to be offset by 16,16 only

            shl eax, 4          ;// 16 lines (width*16)
            add eax, 16         ;// plus another 16
            mov d_ofs, eax      ;// dest offset
            mov eax, oBmp_width * 16 + 16

    done_with_dst_tests:    ;// eax had better have the source offset

        mov s_ofs, eax

    ;// good o' place as any to offset the source

        bt ecx, LOG2( SHAPE_MOVE_SRC_OC )
        .IF CARRY?

            DEBUG_IF <!![ebx].pSource>  ;// have to have a source to use this

            fld [ebx].OC.y
            fld [ebx].OC.x
            sub esp, 8              ;// make some room
            fxch
            fistp DWORD PTR [esp+4] ;// store OCy
            fistp DWORD PTR [esp]   ;// store OCx

            mov eax, [esp+4]
            shl eax, LOG2(oBmp_width)
            add eax, DWORD PTR [esp];// +x = offsets
            add [ebx].pSource, eax  ;// offset

            add esp, 8              ;// free extra room

        .ENDIF

;//
;// build raster tables
;//

    ;// MASK

        fldz                    ;// maskers are NOT expanded
        call build_region       ;// build the region
        .IF esi
            invoke GetRgnBox, esi, ebp
            point_GetBR (RECT PTR [ebp])
            point_SubTL (RECT PTR [ebp])
            mov ecx, flags
            point_Set [ebx].siz
        .ENDIF
        lea edx, [ebx].pMask    ;// load the desired destination
        xor eax, eax            ;// want to fill, not frame
        call build_raster_table

    ;// OUT1

        bt ecx, LOG2(SHAPE_BUILD_OUT1)
        jnc @0

            fadd math_1         ;// out 1 is expanded by 1
            call build_region       ;// build the region
            or eax, 1               ;// want to outline the shape
            lea edx, [ebx].pOut1    ;// load the destination pointer
            call build_raster_table ;// call common routine

    ;// OUT2

        bt ecx, LOG2(SHAPE_BUILD_OUT2)
        jnc @0

            fadd math_2         ;// out2 is expanded by 3
            call build_region       ;// build the region
            or eax, 1               ;// want to outline the shape
            lea edx, [ebx].pOut2    ;// load the destination pointer
            call build_raster_table

    ;// OUT3

        bt ecx, LOG2(SHAPE_BUILD_OUT3)
        jnc @0

            fadd math_2         ;// out2 is expanded by 5
            call build_region       ;// build the region
            or eax, 1               ;// want to outline the shape
            lea edx, [ebx].pOut3
            call build_raster_table

    @0: fstp st ;// clear out the expansion
        fstp st ;// clear out OCx
        fstp st ;// clear out OCy

        ;// fpu should be empty

    DEBUG_IF <ebx !!= pShape>           ;// lost track somewhere
    DEBUG_IF <ecx !!= [ebx].dwFlags>    ;// lost track somewhere


;//
;// initialize the container (if any)
;//

    bt ecx, LOG2(SHAPE_IS_CONTAINER)
    .IF CARRY?

        lea esi, [ebx + -OFFSET(GDI_CONTAINER.shape)]
        ASSUME esi:PTR GDI_CONTAINER

        ;// if Q=3, build the a_24 value
        ;//
        ;//     see pheta_10.mcd and pheta_11.mcd for worksheet
        ;//
        ;//          (B^2-A^2)*(1-2*s)
        ;//     aa = -----------------
        ;//            -8*s*(A^2+B^2)
        ;//
        ;//     a_24 = pi/2 - 1/2 atan( aa, sqrt(1-aa^2) )


        .IF [esi].Q == 3

            fld [esi].AB.x
            fmul st, st
            fld [esi].AB.y
            fmul st, st     ;// B^2 A^2

            fld [esi].S
            fadd st, st     ;// 2s  B^2 A^2

            fld1
            fsub st, st(1)  ;// 1-2s    2s      B^2     A^2

            fld st(2)       ;// B^2     1-2s    2s      B^2     A^2
            fadd st, st(4)  ;// A2+B2   1-2s    2s      B^2     A^2
            fld math_4      ;// 4       A2+B2   1-2s    2s      B^2     A^2
            fmulp st(3), st ;// A2+B2   1-2s    8s      B^2     A^2

            fxch st(4)      ;// A^2     1-2s    8s      B^2     A2+B2
            fsubp st(3), st ;// 1-2*s   8s      B2-A2   A2+B2
            fxch            ;// 8s      1-2*s   B2-A2   A2+B2
            fmulp st(3), st ;// 1-2*s   B2-A2   bot
            fmul            ;// top     bot

            fdivr           ;// aa

            fld st
            fmul st, st     ;// aa^2    aa
            fsubr math_1    ;// 1-aa2   aa
            fsqrt           ;// bb      aa
            fxch
            fpatan          ;// F
            fldpi           ;// pi      F
            fsubr           ;// pi-F

            fmul math_1_2   ;// a_24
            fstp [esi].a_24

        .ENDIF

    ;// DEBUG_IF <ebx==(OFFSET noise_container.shape)>

        bt ecx, LOG2( SHAPE_IS_POLYGON )    ;// circles don't get intersectors

        ;// build the intersector
        .IF CARRY?
        ;// .IF [esi].Q     ;// Q = zero does not get an intersector


            ;// formula
            ;//
            ;//     P[i] = R[i]*cos(i)
            ;//          = R[i]*sin(i)
            ;//
            ;//     Q[i] = P[i]-P[i-1]
            ;//
            ;//     I[i] = norm(Q[i])

            add ebp, 15
            and ebp, 0FFFFFFF0h
            mov [esi].pInter, ebp       ;// store intersector pointer

            ;// this next loop is sort of confusing due to the
            ;// circular nature of the process ( ie, have to wrap)
            ;// in general, we keep the previous point and the current point
            ;// in the fpu, then do a post loop wrap

            ;// initialize

                ASSUME ebp:PTR I_POINT  ;// ebp walks the output
                mov edx, ecx            ;// edx will count
                mov esi, [ebx].pPoints  ;// esi walks the ra points
                and edx, 0FFFFh         ;// strip out extra
                mov edi, gdi_temp_buffer;// edi points at sincos
                xor eax, eax            ;// eax indexes the NEXT point
                dec edx                 ;// need to decrease by one so we can trap the last scan

            ASSUME esi:PTR fPOINT
            ASSUME edi:PTR fPOINT

            ;// generate first point manually

                fld [edi].y     ;// sin
                fmul [esi].x    ;// p0y
                fld [edi].x     ;// cos     p0y
                fmul [esi].x    ;// p0x     p0y

            @1: inc eax         ; TOP OF LOOP
            @2:                 ; LAST LOOP

            ;// generate the next point

                fld [edi+eax*8].y   ;// sin     Px      Py
                fmul [esi+eax*8].x  ;// p1y     Px      Py
                fld [edi+eax*8].x   ;// cos     p1y     Px      Py
                fmul [esi+eax*8].x  ;// p1x     p1y     Px      Py

            ;// store this point, and compute Q

                fxch st(2)          ;// Px      p1y     p1x     Py
                fst [ebp].P.x
                fsubr st, st(2)     ;// Qx      p1y     p1x     Py

                fxch st(3)          ;// Py      p1y     p1x     Qx
                fst [ebp].P.y
                fsubr st, st(1)     ;// Qy      p1y     p1x     Qx

            ;// store Q

                fxch st(3)          ;// Qx      p1y     p1x     Qy
                fstp [ebp].Q.x      ;// p1y     p1x     Qy
                fxch st(2)          ;// Qy      p1x     p1y
                fstp [ebp].Q.y      ;// p1x     p1y

                add ebp, SIZEOF I_POINT

                dec edx
                js @3       ;// trap the exit
                jnz @1      ;// trap the last loop
                xor eax, eax;// last loop points at first record
                jmp @2

            @3: ;// all done

                fstp st
                fstp st

        .ENDIF  ;// need intersector

    .ENDIF  ;// is container




    DEBUG_IF <ebx !!= pShape>           ;// lost track somewhere
    DEBUG_IF <ecx !!= [ebx].dwFlags>    ;// lost track somewhere

;//
;// now we know enough to allocate memory and copy the results
;//

;// here's the state of things
;//
;//     ebx is still the shape
;//     ebp points at the END of memory we need to copy
;//     [ebx].pMask points at the BEGIN of memory we need to copy


    ;// compute the required memory size, then allocate it

    mov ecx, ebp
    sub ecx, [ebx].pMask

    DEBUG_IF < ecx & 0Fh >                  ;// size was supposed to end as 16 byte aligned
    DEBUG_IF <ecx!>GDI_TEMP_BUFFER_SIZE>    ;// need to set this higher

    push ecx        ;// save the count
    invoke memory_Alloc, GPTR, ecx
    pop ecx         ;// retrieve the count

    mov edi, eax    ;// xfer to edi
    mov edx, eax    ;// save in edx as well

    ;// copy the memory

    mov esi, [ebx].pMask
    shr ecx, 2
    rep movsd

    ;// determine the offsets we need to add to the pointers

    mov eax, [ebx].pMask
    sub eax, edx

    ;// add ofset, resulting in the actual pointer
    mov ecx, [ebx].dwFlags

    sub [ebx].pMask, eax
    DEBUG_IF <[ebx].pMask !!= edx>  ;// supposed to be equal

    bt ecx, LOG2( SHAPE_BUILD_OUT1 )
    jnc @F
    DEBUG_IF< !![ebx].pOut1>    ;// wasn't built
    sub [ebx].pOut1, eax

    bt ecx, LOG2( SHAPE_BUILD_OUT2 )
    jnc @F
    DEBUG_IF< !![ebx].pOut2>    ;// wasn't built
    sub [ebx].pOut2, eax

    bt ecx, LOG2( SHAPE_BUILD_OUT3 )
    jnc @F
    DEBUG_IF< !![ebx].pOut3>    ;// wasn't built
    sub [ebx].pOut3, eax

@@: bt ecx, LOG2(SHAPE_IS_CONTAINER)
    .IF CARRY?
        bt ecx, LOG2( SHAPE_IS_POLYGON )    ;// circles don't get intersectors
        .IF CARRY?
            lea esi, [ebx + -OFFSET(GDI_CONTAINER.shape)]
            ASSUME esi:PTR GDI_CONTAINER
            DEBUG_IF<!![esi].pInter>    ;// wasn't built
            sub [esi].pInter, eax
        .ENDIF
    .ENDIF

;// that's it

    mov ebp, st_ebp
    add esp, stack_size
    or [ebx].dwFlags, SHAPE_INITIALIZED
    ret



;////////////////////////////////////////////////////////////////////
;//
;//
;//     local functions
;//



ASSUME_AND_ALIGN
build_raster_table:

    call_depth = 1

    ;// edx must point to where we store
    ;// esi must have the region or be zero
    ;// set eax to zero to fill the region
    ;// set eax to non zero to frame the region

    ASSUME ebx:PTR GDI_SHAPE
    ASSUME edx:PTR DWORD

    add ebp, 15             ;// align pointer
    and ebp, 0FFFFFFF0h     ;// align to 16 bytes
    mov [edx], ebp          ;// store it

push edx    ;// store the pointer

    ;// not all shapes build regions
    .IF esi
        .IF eax
            invoke FrameRgn, gdi_hDC, esi, hBRUSH(1),1,1;// frame it
            DEBUG_IF<!!eax>
        .ELSE
            invoke FillRgn, gdi_hDC, esi, hBRUSH(1)     ;// fill it
            DEBUG_IF <!!eax>, GET_ERROR
        .ENDIF
        invoke DeleteObject, esi                    ;// delete it
        DEBUG_IF <!!eax>
    .ENDIF

    ;// build the raster table
    invoke rasterize        ;// call the rasterizer

mov edx, [esp]  ;// retrieve the pointer

    ;// erase what we just drew
    xor eax, eax            ;// store zero
    mov edi, gdi_pBmpBits   ;// point at destination
    mov ebx, [edx]          ;// load what ever we just built
    call shape_Fill         ;// fill it

pop edx         ;// pop the pointer
    ;// adjust the results

    mov ebx, pShape         ;// reload the shape pointer
    mov edx, [edx]
    mov eax, d_ofs          ;// load the offset
    mov ecx, s_ofs
    sub (RASTER_LINE PTR [edx]).dest_wrap, eax
    sub (RASTER_LINE PTR [edx]).source_wrap, ecx
    mov ecx, flags          ;// reload the flags
    retn







ASSUME_AND_ALIGN
build_region:

    call_depth = 1

    ;// ebx must have the shape pointer
    ;// ecx must be the flags
    ;// fpu must be loaded with the radius adjust and the OCx OCy

    ;// returns with esi as the new region
    ;// if a region is not built (ie: fonts), esi will be zero

        ASSUME ebx:PTR GDI_SHAPE
        DEBUG_IF <ebx !!= pShape >
        DEBUG_IF <ecx!!=[ebx].dwFlags>

    ;// make sure the space is clear of previous drawing
    ;// all we need to do is zero the top of the gutter

        .IF gdi_bHasRendered

            push ecx

            imul ecx, gdi_bitmap_size.x, GDI_GUTTER_Y/4
            mov edi, gdi_pBmpBits
            xor eax, eax
            rep stosd

            pop ecx
            mov gdi_bHasRendered, eax ;// no since doing twice in a row

        .ENDIF


    ;// parse the bits to determine what shape we are

        bt ecx, LOG2( SHAPE_IS_POLYGON )
        jnc @F

        ;// POLYGON

            ;// build all the points in the table
            call build_points
            movzx eax, cx                   ;// eax will have the number of points
            mov edx, l_point
            invoke CreatePolygonRgn, edx, eax, WINDING
            DEBUG_IF<!!eax>

            jmp @10

    @@: bt ecx, LOG2( SHAPE_IS_CHARACTER )
        jnc @F

        ;// CHARACTER

            ;// build a rect to print to, also have to fill

            ASSUME ebp:PTR RECT

                            ;// dr      OCx     Ocy
            fld st(1)       ;// OCx     dr      OCx     OCy
            fadd math_4
            fist [ebp].left
            fadd math_64
            fistp [ebp].right

            fld st(2)
            fadd math_4
            fist [ebp].top
            fadd math_32
            fistp [ebp].bottom

            ;// draw the character(s), determine the length

            mov eax, [ebx].character

            btr eax, 31 ;// check the overwrite bit
            .IF CARRY?

                ;// we're supposed to draw the characters on top of each other
                ;// gdi_hDC draws with transparent, so all we do is print, shift and loop

                .REPEAT

                    push eax
                    mov eax, esp
                    invoke DrawTextA, gdi_hDC, eax, 1, ebp, DT_NOCLIP + DT_SINGLELINE
                    pop eax
                    shr eax, 8
                .UNTIL ZERO?

                jmp @10

            .ENDIF

            mov edx, 1      ;// edx will count
            shr eax, 8
            jz draw_the_text
            inc edx
            shr eax, 8
            jz draw_the_text
            inc edx
            shr eax, 8
            jz draw_the_text
            inc edx

        draw_the_text:

            lea eax, [ebx].character
            invoke DrawTextA, gdi_hDC, eax, edx, ebp, DT_NOCLIP + DT_SINGLELINE
            DEBUG_IF<!!eax>

            xor eax, eax    ;// must return zero
            jmp @10

    @@:
        ;// CIRCLE or ELLIPSE

        ;// we'll do this call manually

            sub esp, SIZEOF RECT;// dr      OCx     OCy

            ;// bottom = dr + AB.y + OCy
            fld st              ;// dr      dr      OCx     OCy
            fadd [ebx].OC.y     ;// bottom  dr      OCx     OCy
            fadd st, st(3)      ;// bottom
            fistp (RECT PTR [esp]).bottom

            ;// right = dr + AB.x + OCx
            fld st              ;// dr      dr      OCx     OCy
            fadd [ebx].OC.x     ;// right   dr      OCx     OCy
            fadd st, st(2)      ;// right
            fistp (RECT PTR [esp]).right

            ;// top = OCy - dr - AB.y
            fld st(2)           ;// ocy     dr      OCx     OCy
            fsub st, st(1)      ;// top
            fsub [ebx].OC.y     ;// top     dr      OCx     OCy
            fistp (RECT PTR [esp]).top

            ;// left = OCx - dr - AB.x
            fld st(1)           ;// ocy     dr      OCx     OCy
            fsub st, st(1)      ;// left
            fsub [ebx].OC.x     ;// left    dr      OCx     OCy
            fistp (RECT PTR [esp]).left

            call CreateEllipticRgn
            DEBUG_IF<!!eax>

            ;// now we get to a nasty little peice of kludging
            ;// these round regions will not pick up the last pixel on the x axis
            ;// so we copy the region, offset it, then 'or' it back on

            mov ecx, flags
            .IF !(ecx & SHAPE_NO_ROUND_ADJUST)

                mov esi, eax                                ;// store the region we want to keep

                xor eax, eax                                ;// load some dummy args
                xor edx, edx
                dec eax
                inc edx
                invoke CreateEllipticRgn, eax, eax, edx, edx;// create a temp region
                DEBUG_IF <!!eax>
                push ebx                                    ;// save ebx
                mov ebx, eax                                ;// ebx is the temp region
                invoke CombineRgn, ebx, esi, esi, RGN_COPY  ;// copy the real region to this one
                xor edx, edx
                xor eax, eax                                ;// create another set of dummy args
                inc edx
                invoke OffsetRgn, ebx, edx, eax             ;// offset the region over one pixel
                invoke CombineRgn, esi, esi, ebx, RGN_OR    ;// merge on to real region
                invoke DeleteObject, ebx                    ;// delete the temp region
                DEBUG_IF <!!eax>

                pop ebx                                     ;// restore ebx
                jmp @11     ;// skip xferring

            .ENDIF

    @10:    mov esi, eax
    @11:    mov ecx, flags
            retn                    ;// that's it




;//////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
build_points:

    call_depth = 2

    ;// this builds array of POINT based a pre-built sincos table
    ;// and the RA pointer

    ;// FPU must have the expansion amount for the radius
    ;// pPoint must be defined
    ;// sincos must already be built and be at gdi_temp_buffer
    ;// ebx must point at the shape
    ;// ecx must be the dwFlags

    ;// uses edi, esi
    ;// does not clear the fpu

    ASSUME ebx:PTR GDI_SHAPE
    DEBUG_IF <ecx !!= [ebx].dwFlags>

    mov eax, 0FFFFh         ;// load mask for count

    mov edi, l_point            ;// load from local
    ASSUME edi:PTR fPOINT

    mov esi, [ebx].pPoints  ;// load list of source radii
    ASSUME esi:PTR fPOINT

    and eax, ecx            ;// mask in the count
    DEBUG_IF <ZERO?>        ;// count wasn't specified

    mov edx, gdi_temp_buffer
    ASSUME edx:PTR fPOINT   ;// edx walks the sincos table

    ;// formula x =  (dr+R)*cos + OCx
    ;//         y =  (dr+R)*sin + OCy

    .REPEAT             ;// dr      OCx     OCy

        fld st          ;// dr      dr      OCx     OCy
        fadd [esi].x    ;// R       dr      OCx     OCy

        fld [edx].x     ;// cos     R       dr      OCx     OCy
        fmul st, st(1)  ;// x       R       dr      OCx     OCy

        fld [edx].y     ;// sin     x       R       dr      OCx     OCy
        fmulp st(2), st ;// x       y       dr      OCx     OCy

        fadd st, st(3)  ;// X       y       dr      OCx     OCy
        fxch            ;// y       X       dr      OCx     OCy
        fadd st, st(4)  ;// Y       X       dr      OCx     OCy
        fxch            ;// X       Y       dr      OCx     OCy

        add esi, SIZEOF fPOINT

        fistp [edi].x   ;// Y       dr      OCx     OCy

        add edx, SIZEOF fPOINT

        fistp [edi].y   ;// dr      OCx     OCy

        add edi, SIZEOF fPOINT

        dec eax

    .UNTIL ZERO?

    retn




shape_Build ENDP





ASSUME_AND_ALIGN
shape_Destroy   PROC

    ;// this function frees the memory allocated by the above

    ASSUME ebx:PTR GDI_SHAPE    ;// ebx points at the shape and must be preserved

    .IF [ebx].pMask
        invoke memory_Free, [ebx].pMask
    .ENDIF

    ret

shape_Destroy   ENDP



;//////////////////////////////////////////////////////////////////////////////


;///////////////////////////////////////////////////////////////////////////
;//
;//                             masm does not want to share the equate we need
;//     DIB functions           so we put this function from gdi_dib.asm here
;//

;////////////////////////////////////////////////////////////////////
;//
;//                         private function
;//
;//                             called from dib_initialize_shape
;//     generate_outline
;//

ASSUME_AND_ALIGN
generate_outline:

    ASSUME esi:PTR DIB_CONTAINER
    ASSUME edi:PTR RASTER_LINE

    ;// registers:
    ;// esi = gdi container
    ;// edi = raster line iterator
    ;// ebp = top_dst
    ;// edx = dwcount
    ;// ecx = left_dst
    ;// ebx = rite_dst
    ;// eax = line_count

    ;//     TOP     dst = top_dst
    ;//             jmp = DWORD_2
    ;//             dwc = dwcount

            mov [edi].jmp_to, RASTER_DWORD_2_JUMP
            mov [edi].dest_wrap,ebp
            mov [edi].dw_count,edx
            add edi, SIZEOF RASTER_LINE

    ;// for line_count
    ;//
    ;//     LEFT    dst = left_dst
    ;//             jmp = 1_BYTE
    ;//     RIGHT   dst = rite_dst
    ;//             jmp = 1_BYTE
    ;//
    ;// next line_count

        .REPEAT

            mov [edi].jmp_to, RASTER_1_BYTE_JUMP
            mov [edi].dest_wrap,ecx
            add edi, SIZEOF RASTER_LINE

            mov [edi].jmp_to, RASTER_1_BYTE_JUMP
            mov [edi].dest_wrap,ebx
            add edi, SIZEOF RASTER_LINE

            dec eax

        .UNTIL ZERO?

    ;//
    ;//     BOTTOM  dst = left_dst
    ;//             jmp = DWORD_2
    ;//             dwc = dwcount
    ;//

            mov [edi].jmp_to, RASTER_DWORD_2_JUMP
            mov [edi].dest_wrap,ecx
            mov [edi].dw_count,edx
            add edi, SIZEOF RASTER_LINE

    ;//     EXIT    jmp = EXIT

            mov [edi].jmp_to, RASTER_EXIT_JUMP

    ret


;//
;//     generate_outline
;//                             called from dib_initialize_shape
;//
;////////////////////////////////////////////////////////////////////





;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;//
;//                         private function
;//
;//                             initializes the shape
;//     dib_initialize_shape     and optional container/intersector
;//
ASSUME_AND_ALIGN
dib_initialize_shape PROC

;// enter

    push edi
    push ebp
    push ebx

    ASSUME esi:PTR DIB_CONTAINER

    mov edi, [esi].shape.pMask
    ASSUME edi:PTR RASTER_LINE      ;// edi will walk the raster tables

;// MASKER


        ;// the first source and dest offset are always zero
        ;// the dword count is always the same
        ;// the next dest offsets are siz.x - width
        ;// jump value is always RASTER_LINE_JUMP

        ;// total of three records
        ;// first one is a duplicate because:
        ;//     shape_Fill adds the dest first -- our first dest must always be zero
        ;//     fill_line adds the SAME source and dest as what ever jumped to it
        ;//     so we can't combine the first and second lines
        ;// the second line is the _line_ routine with H-1 as the count
        ;// the third line is the exit jump

        ;// compute the dest_wrap

            mov ecx, gdi_bitmap_size.x  ;// load gdi width
            mov edx, [esi].shape.siz.x  ;// load our width
            mov eax, [esi].shape.siz.y  ;// load our height
            sub ecx, edx                ;// dest wrap is the difference
            shr edx, 2                  ;// divide our width by 4 to get dw_count

        ;// state:
        ;//
        ;//     eax is the height of our bitmap
        ;//     ecx is the dest wrap for each new raster
        ;//     edx is the dword count for each raster

        ;// build the first record

            mov [edi].jmp_to, RASTER_DWORD_JUMP
            mov [edi].source_wrap, 0
            dec eax                         ;// always minus one line
            mov [edi].dw_count, edx
            mov [edi].dest_wrap, 0          ;// first dest wrap has to be zero

        ;// build the count and the next record

            shl eax, 16                     ;// shift height into high word
            add edi, SIZEOF RASTER_LINE     ;// advance to next record
            or edx, eax                     ;// merge the two together

            mov [edi].jmp_to, RASTER_LINE_JUMP  ;// set the instruction
            mov [edi].source_wrap, 0            ;// source wrap is zero
            mov [edi].dw_count, edx             ;// dw count
            mov [edi].dest_wrap, ecx            ;// dest wrap already computed

        ;// build the exit record

            add edi, SIZEOF RASTER_LINE     ;// advance to next record
            mov [edi].jmp_to, RASTER_EXIT_JUMP  ;// simple enough

;// the next sections involve some nomenclature from a worksheet
;//
;//     BW = width of gdi_bitmap
;//     DW = dword count of our bitmap width
;//     W = full width of our bitmap

;// OUTLINERS

    ;// the first line is solid
    ;// the next height+ofs lines are broken into two single byte records each
    ;// the last line is solid (width + 2ofs)
    ;// final record is the exit record


;// from worksheet: and aditional notes for implementation:
;//
;// using a set of state variables, an instruction generating algorithm can be used
;// then three quick sections manage the state

;// the state values are defined as:

        ;//                                     registers
        ;// OUT1
        ;//
        ;//     top_dst = -1 - BW               ebp
        ;//     dwcount = previous (edx)        edx already set (have to strip out the count however)
        ;//     left_dst = BW - W - 2           ecx
        ;//     rite_dst = W                    ebx
        ;//     line_count = H                  eax
        ;//
        ;//     generate_outline()
        ;//

                add edi, sizeof RASTER_LINE
                mov ebp, -1
                and edx, 0FFFFh
                mov ecx, gdi_bitmap_size.x
                mov ebx, [esi].shape.siz.x
                mov eax, [esi].shape.siz.y

                mov [esi].shape.pOut1, edi
                sub ebp, ecx
                sub ecx, ebx
                sub ecx, 2

                call generate_outline

        ;// OUT2
        ;//
        ;//     top_dst = top_dst -1 -2*bw      ebp
        ;//     dwcount++                       edx
        ;//     left_dst = left_dst - 4         ecx
        ;//     rite_dst = rite_dst + 4         ebx
        ;//     line_count = H+4                eax
        ;//
        ;//     generate_outline()
        ;//
                sub ebp, 2
                mov eax, gdi_bitmap_size.x
                add edi, sizeof RASTER_LINE
                shl eax, 1
                sub ecx, 4
                sub ebp, eax
                add ebx, 4
                mov eax, [esi].shape.siz.y
                add eax, 4
                mov [esi].shape.pOut2, edi
                inc edx

                call generate_outline

        ;// OUT3
        ;//
        ;//     top_dest = top_dest -1 - 2*bw   ebp
        ;//     dwcount++                       edx
        ;//     left_dst = left_dest - 4        ecx
        ;//     rite_dst = rite_dst + 4         ebx
        ;//     line_count = H+8                eax
        ;//
        ;//     generate_outline()

                sub ebp, 2
                mov eax, gdi_bitmap_size.x
                add edi, sizeof RASTER_LINE
                shl eax, 1
                sub ecx, 4
                sub ebp, eax
                add ebx, 4
                mov eax, [esi].shape.siz.y
                add eax, 8
                mov [esi].shape.pOut3, edi
                inc edx

                call generate_outline

    .IF [esi].shape.dwFlags & SHAPE_DIB_HAS_INTER

;// INTERSECTOR

    ;// building the intersector also involves filling in the container
    ;// since all the values are floats, we need the following:
    ;//
    ;// w, w2, w3   width, half width, and third width of bitmap
    ;// h, h2, h3   height, half height, and third height of bitmap
    ;// 1, 0        one and zero
    ;//
    ;// we also need to calculate Q, and S
    ;//
    ;// container values:
    ;//
    ;//     Q = 3           ;// addendum: using 1/3 for AB does not do well
    ;//     S = .1          ;// instead, we want to use half width height directly ?
    ;//     AB.x = w3       ;// so were is says 1/3, we're actually using 1/2
    ;//     AB.y = h3       ;//
    ;//                     ;//
    ;//     OC.x = w2       ;//
    ;//     OC.y = h2       ;//

        add edi, sizeof RASTER_LINE
        fld math_1_10   ;// bug abox228: s must be 0.1 or greater, other wise the intersector dies
        mov [esi].pInter, edi
        mov [esi].Q, 3
        fstp [esi].S

        fild [esi].shape.siz.x;//   w
        fild [esi].shape.siz.y;//   h       w

    ;// fld math_RadToNorm;// 1/3       h       w
        fld math_1_2

        fld math_1_2    ;// 1/2     1/3     h       w

        fld st(1)       ;// 1/3     1/2     1/3     h       w
        fmul st, st(3)  ;// h/3     1/2     1/3     h       w
        fld st(4)       ;// w       h/3     1/2     1/3     h       w
        fmulp st(3), st ;// h/3     1/2     w/3     h       w

        fld st(1)       ;// 1/2     h/3     1/2     w/3     h       w
        fmul st, st(4)  ;// h/2     h/3     1/2     w/3     h       w
        fld st(5)       ;// w       h/2     h/3     1/2     w/3     h       w
        fmulp st(3), st ;// h/2     h/3     w/2     w/3     h       w

        fxch st(3)      ;// w/3     h/3     w/2     h/2     h       w
        fstp [esi].AB.x ;// h/3     w/2     h/2     h       w
        ;//fxch
        fstp [esi].AB.y ;// w/2     h/2     h       w

        ;// fdivr           ;// h/w     w/2     h/2     h       w
        ;//fstp [esi].rBA   ;// w/2     h/2     h       w

        fst [esi].shape.OC.x
        fxch            ;// h/2     w/2     h       w
        fst [esi].shape.OC.y

    ;//
    ;// intersector values:
    ;// there are 4, in clockwise order

        ASSUME edi:PTR I_POINT
        I0 TEXTEQU <[edi]>
        I1 TEXTEQU <[edi+SIZEOF I_POINT]>
        I2 TEXTEQU <[edi+(SIZEOF I_POINT) * 2]>
        I3 TEXTEQU <[edi+(SIZEOF I_POINT) * 3]>

    ;//
    ;//     0           1           2           3
    ;//
    ;// Q   w,0         0,h         -w,0        0,-h
    ;//
    ;// P   -w2,-h2     w2,-h2      w2,h2       -w2,h2
    ;//
    ;// I   1,0         0,1         -1,0        0,-1

        fst  I2.P.y     ;// h/2     w/2     h       w
        fst  I3.P.y     ;// h/2     w/2     h       w
        fchs            ;// -h/2    w/2     h       w
        fst  I0.P.y     ;// -h/2    w/2     h       w
        fstp I1.P.y     ;// w/2     h       w
        fst  I1.P.x     ;// w/2     h       w
        fst  I2.P.x     ;// w/2     h       w
        mov eax, math_1 ;// eax = 1.0
        fchs            ;// -w/2    h       w
        fst  I0.P.x     ;// -w/2    h       w
        mov edx, math_neg_1;// edx = -1.0
        fstp I3.P.x     ;// h       w

    ;// mov I0.I.x, eax
        fst  I1.Q.y     ;// h       w
    ;// mov I1.I.y, eax
        fchs            ;// -h      w
        fstp I3.Q.y     ;// w
    ;// mov I2.I.y, edx
        fst  I0.Q.x     ;// w
    ;// mov I3.I.y, edx
        fchs            ;// -w
        fstp I2.Q.x     ;// w

        I0 TEXTEQU <>
        I1 TEXTEQU <>
        I2 TEXTEQU <>
        I3 TEXTEQU <>



    ;// gots to build k1 and k2

        ;// if Q=3, build the a_24 value
        ;//
        ;//     see pheta_10.mcd and pheta_11.mcd for worksheet
        ;//
        ;//          (B^2-A^2)*(1-2*s)
        ;//     aa = -----------------
        ;//            -8*s*(A^2+B^2)
        ;//
        ;//     a_24 = pi/2 - 1/2 atan( aa, sqrt(1-aa^2) )
        ;//
        ;// abox 228    s for dib containers must be 0.1


            fld [esi].AB.x
            fmul st, st
            fld [esi].AB.y
            fmul st, st     ;// B^2 A^2

            fld [esi].S
            fadd st, st     ;// 2s  B^2 A^2

            fld1
            fsub st, st(1)  ;// 1-2s    2s      B^2     A^2

            fld st(2)       ;// B^2     1-2s    2s      B^2     A^2
            fadd st, st(4)  ;// A2+B2   1-2s    2s      B^2     A^2
            fld math_4      ;// 4       A2+B2   1-2s    2s      B^2     A^2
            fmulp st(3), st ;// A2+B2   1-2s    8s      B^2     A^2

            fxch st(4)      ;// A^2     1-2s    8s      B^2     A2+B2
            fsubp st(3), st ;// 1-2*s   8s      B2-A2   A2+B2
            fxch            ;// 8s      1-2*s   B2-A2   A2+B2
            fmulp st(3), st ;// 1-2*s   B2-A2   bot
            fmul            ;// top     bot

            fdivr           ;// aa

            fld st
            fmul st, st     ;// aa^2    aa
            fsubr math_1    ;// 1-aa2   aa
            fsqrt           ;// bb      aa
            fxch
            fpatan          ;// F
            fldpi           ;// pi      F
            fsubr           ;// pi-F

            fmul math_1_2   ;// a_24
            fstp [esi].a_24

    .ENDIF


;// EXIT

    pop ebx
    pop ebp
    pop edi

    ret

dib_initialize_shape ENDP



;//
;//                             initializes the shape
;//     dib_initialize_shape     and optional container/intersector
;//
;////////////////////////////////////////////////////////////////////





;//////////////////////////////////////////////////////////////////////////////

IFDEF DEBUGBUILD
.DATA
    shape_temp dd 0
.CODE
ENDIF

ASSUME_AND_ALIGN
shape_Intersect PROC

    ;// given E and H in the FPU
    ;// and pointer edi->pContainer
    ;// calulate the correct intersection from E to a line on the container

    ;// return the sl value in the fpu
    ;// return the pointer to the intersector in ecx

    ;// register calling format

        ASSUME ebx:PTR APIN             ;// ebx is the APIN, preserved
        ASSUME esi:PTR OSC_OBJECT       ;// esi is it's osc, preserved
        ASSUME ebp:PTR GDI_CONTAINER    ;// ebp is the container, preserved

        ;// the rest are destroyed

    ;// FPU:
    ;// in      ;// eey     eex     hx      hy
    ;// out     ;// sl      eey     eex     hx      hy

        DEBUG_IF <esi !!= [ebx].pObject>    ;// must be true
        DEBUG_IF <ebp !!= [esi].pContainer> ;// must be so

    ;// have to scan each segment
    ;//
    ;//
    ;// E is assumed to be relative to the center of the container
    ;//
    ;// algorithm:
    ;//
    ;// for each intersector record
    ;//
    ;//      (Ey-Py)*Hx - (Ex-Px)*Hy
    ;//  d = -----------------------
    ;//           Hx*Qy - Hy*Qx
    ;//
    ;// if d is negative or greater than one, ignore
    ;//
    ;//      (Ey-Py)*Qx - (Ex-Px)*Qy
    ;// sl = -----------------------
    ;//           Hx*Qy - Hy*Qx
    ;//
    ;// store smallest value of sl


    ;// optimized version

    ;// let F = 1 / ( Hx*Qy - Hy*Qx )   <-- if F is zero, then they can't intersect
    ;// not enough registers to cache any more (would save only a dozen clocks anyways)

    pushd 0     ;// keep track of intersector

    movzx ecx, WORD PTR [ebp].shape.dwFlags ;// load the point count
    mov edx, [ebp].pInter   ;// load the intersector table
    ASSUME edx:PTR I_POINT

    DEBUG_IF <!!edx>    ;// an intersector was never defined for this
    DEBUG_IF <!!ecx>    ;// no points in the table

    fld math_Million    ;// start big
    xor edi, edi    ;// edi is a neg sl flag

    .REPEAT             ;// SL      eey     eex     hx      hy

    ;// 1/F = Hx*Qy - Hy*Qx

        fld st(4)       ;// hy      SL      eey     eex     hx      hy
        fmul [edx].Q.x  ;// qxhy    SL      eey     eex     hx      hy
        fld st(4)       ;// hx      qxhy    SL      eey     eex     hx      hy
        fmul [edx].Q.y  ;// hxqy    hyqx    SL      eey     eex     hx      hy
        fsubr           ;// 1/F     SL      eey     eex     hx      hy
    ;// test for zero
        xor eax, eax
        ftst
        fnstsw ax
        sahf
        jz @next_segment_1
    ;// F = 1/1/F

        fdivr math_1    ;// F       SL      eey     eex     hx      hy
    ;// dx = Ex-Px
    ;// dy = Ey-Py
        fld st(3)       ;// eex     F       SL      eey     eex     hx      hy
        fsub [edx].P.x  ;// dx      F       SL      eey     eex     hx      hy
        fld st(3)       ;// eey     dx      F       SL      eey     eex     hx      hy
        fsub [edx].P.y  ;// dy      dx      F       SL      eey     eex     hx      hy
    ;//  d = ( dy*Hx - dx*Hy ) * F
        fxch            ;// dx      dy      F       SL      eey     eex     hx      hy
        fmul st, st(7)  ;// dxhy    dy      F       SL      eey     eex     hx      hy
        fxch            ;// dy      dxhy    F       SL      eey     eex     hx      hy
        fmul st, st(6)  ;// dyhx    dxhy    F       SL      eey     eex     hx      hy
        fsubr           ;// top     F       SL      eey     eex     hx      hy
        fmul st, st(1)  ;// d       F       SL      eey     eex     hx      hy
    ;// check negative
        xor eax, eax
        ftst
        fnstsw ax
        sahf
        fld1            ;// 1       d       F       SL      eey     eex     hx      hy
        jb @next_segment_3
    ;// check greater than one
        xor eax, eax
        fucompp         ;// F       SL      eey     eex     hx      hy
        fnstsw ax
        sahf
        jb @next_segment_1
    ;// dx = Ex-Px
    ;// dy = Ey-Py
        fld st(3)       ;// eex     F       SL      eey     eex     hx      hy
        fsub [edx].P.x  ;// dx      F       SL      eey     eex     hx      hy
        fld st(3)       ;// eey     dx      F       SL      eey     eex     hx      hy
        fsub [edx].P.y  ;// dy      dx      F       SL      eey     eex     hx      hy
    ;// sl = ( dy*Qx - dx*Qy ) * F
        fxch            ;// dx      dy      F       SL      eey     eex     hx      hy
        fmul [edx].Q.y  ;// dxqy    dy      F       SL      eey     eex     hx      hy
        fxch            ;// dy      dxqy    F       SL      eey     eex     hx      hy
        fmul [edx].Q.x  ;// dyqx    dxqy    F       SL      eey     eex     hx      hy
        fsubr           ;// top     F       SL      eey     eex     hx      hy
        fmul            ;// sl      SL      eey     eex     hx      hy
    ;// compare with previous
        xor eax, eax
        ftst
        fnstsw ax
        sahf
        jnc @sl_positive

    @sl_negative:       ;// sl is negative

            fchs        ;// make sl positive
            fucom
            fnstsw ax
            sahf
            jae @next_segment_1
            ;// got a new sl
            fxch            ;// swap sl SL
            or edi, 1       ;// make sure and set edi
            mov [esp], edx  ;// store the pointer
            jmp @next_segment_1

    @sl_positive:       ;// sl is positive

            fucom
            fnstsw ax
            sahf
            jae @next_segment_1
            ;// got a new sl
            fxch            ;// swap sl and SL
            xor edi, edi    ;// make sure and reset edi
            mov [esp], edx  ;// store the pointer
            jmp @next_segment_1

    @next_segment_3:    ;// dump a total of 3 values

        fstp st
        fstp st

    @next_segment_1:    ;// dump one value

        add edx, SIZEOF I_POINT
        dec ecx
        fstp st

    .UNTIL ZERO?

    ;// make sure we found something
    IFDEF DEBUGBUILD
        fst shape_temp
        mov eax, shape_temp
        cmp eax, math_Million
        jnz @F
            int 3   ;// nothing was found
        @@:
    ENDIF

    pop ecx     ;// retrieve the itersector record

    ;// make the sign come out correct
    .IF edi
        fchs
    .ENDIF

    ret

shape_Intersect ENDP










;////////////////////////////////////////////////////////////////////
;//
;//
;//     show_intersector            debug code
;//
IFDEF DEBUGBUILD
show_intersectors PROC STDCALL PUBLIC uses esi edi ebx

    LOCAL point:POINT
    LOCAL hDC:DWORD
    LOCAL old_pen:DWORD

    invoke GetDC, hMainWnd
    mov hDC, eax
    invoke GetStockObject, WHITE_PEN
    invoke SelectObject, hDC, eax
    mov old_pen, eax

    stack_Peek gui_context, esi
    dlist_GetHead oscZ, esi, [esi]
    .WHILE esi

        xor eax, eax
        or eax, [esi].dwHintOsc
        .IF SIGN?

            mov edx, [esi].pContainer
            ASSUME edx:PTR GDI_CONTAINER
            .IF [edx].Q

                xor ecx, ecx
                mov cl, BYTE PTR [edx].shape.dwFlags
                mov edi, [edx].pInter
                ASSUME edi:PTR I_POINT

                .WHILE cl

                    call compute_point

                    push ecx
                    push edx

                    .IF cl == (BYTE PTR [edx].shape.dwFlags)
                        invoke MoveToEx, hDC, point.x, point.y, 0
                    .ELSE
                        invoke LineTo, hDC, point.x, point.y
                    .ENDIF

                    pop edx
                    pop ecx

                    add edi, SIZEOF I_POINT
                    dec cl

                .ENDW

                mov edi, [edx].pInter
                call compute_point
                invoke LineTo, hDC, point.x, point.y

            .ENDIF

        .ENDIF

        dlist_GetNext oscZ, esi

    .ENDW

    invoke SelectObject, hDC, old_pen
    invoke ReleaseDC, hMainWnd, hDC

    ret

    ;// local function

    compute_point:

        fld [edi].P.x
        fadd [edx].shape.OC.x
        fiadd [esi].rect.left
        fistp point.x

        fld [edi].P.y
        fadd [edx].shape.OC.y
        fiadd [esi].rect.top
        fistp point.y

        sub point.x, GDI_GUTTER_X
        sub point.y, GDI_GUTTER_Y

        retn



show_intersectors ENDP
ENDIF
;//
;//     show_intersector            debug code
;//
;//
;////////////////////////////////////////////////////////////////////




;////////////////////////////////////////////////////////////////////
;//
;//
;//     VerifyShapes            debug code
;//

IFDEF DEBUGBUILD
ASSUME_AND_ALIGN
gdi_VerifyShapes PROC uses ebx

    push eax

    slist_GetHead shape_list, ebx
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

        slist_GetNext shape_list, ebx

    .ENDW

    pop eax

    ret

gdi_VerifyShapes ENDP

ENDIF

























ASSUME_AND_ALIGN




END