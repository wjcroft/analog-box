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
;//     ABox_Colors.asm     holds all the gdi_Color functions
;//
;// TOC
;// gdi_GetThisColor PROC
;// gdi_SetThisColor PROC uses esi ebx
;// gdi_LoadColorSet PROC USES esi edi
;// gdi_SaveColorSet PROC uses esi edi
;// gdi_BuildColorSet PROC
;// gdi_BuildColorGroup PROC    ;//  STDCALL uses esi edi ebx
;// gdi_BuildColor PROC uses ebx esi edi
;// gdi_SyncPalettes PROC
;// gdi_bgr_to_hsv PROC uses ebx
;// gdi_rgb_to_hsv PROC uses ebx
;// gdi_color_to_hsv PROC PRIVATE uses esi edi
;// gdi_hsv_to_bgr PROC uses ebx
;// gdi_hsv_to_rgb PROC uses ebx
;// gdi_hsv_to_color PROC PRIVATE


OPTION CASEMAP:NONE

.586
.MODEL FLAT

        .NOLIST
        include <Abox.inc>
        .LIST

.DATA


    ;// the reference palette

        gdi_pRefPalette dd  0   ;// pointer to the hsv reference palette

        gdi_BuildColor      PROTO
        gdi_BuildColorGroup PROTO


.CODE



;////////////////////////////////////////////////////////////////////
;//
;//
;//     gdi_get_this_color      returns BGR
;//

ASSUME_AND_ALIGN
gdi_GetThisColor PROC

    .IF eax < COLOR_SYSTEM_MAX

        mov eax, app_settings.colors.sys_color[eax*4]
        RGB_TO_BGR eax

    .ELSE

        mov edx, eax
        shr eax, 5
        .IF edx & 1Fh

            mov eax, app_settings.colors.pal_group[eax*8-8].hsv_1

        .ELSE

            mov eax, app_settings.colors.pal_group[eax*8-8].hsv_0

        .ENDIF

        invoke gdi_hsv_to_bgr

    .ENDIF

    ret

gdi_GetThisColor ENDP


;////////////////////////////////////////////////////////////////////
;//
;//
;// gdi_SetThisColor        stores one color in the app_settings
;//                         then makes sure the resources are built
;//
ASSUME_AND_ALIGN
gdi_SetThisColor PROC uses esi ebx

    ;// eax must be the color index to set
    ;// ecx must be the BGR color

    .IF eax < COLOR_SYSTEM_MAX      ;// system color

    ;// store the color in obmp palette

        BGR_TO_RGB ecx
        mov app_settings.colors.sys_color[eax*4], ecx

    ;// update all effected gdi_wrapper resources

        mov esi, eax            ;// build colors requires the index in esi
        invoke gdi_BuildColor   ;// build the color and resources
        invoke gdi_SyncPalettes ;// synchronize the attached palettes

    ;// update the desk color if required

        .IF !esi || esi == COLOR_DESK_TEXT

            invoke GetDC, hMainWnd
            mov ebx, eax
            mov eax, oBmp_palette[COLOR_DESK_TEXT*4]
            RGB_TO_BGR eax
            invoke SetTextColor, ebx, eax
            invoke ReleaseDC, hMainWnd, ebx

        .ENDIF

    .ELSE       ;// color group

        mov ebx, eax
        mov esi, eax

        mov eax, ecx
        invoke gdi_bgr_to_hsv

        shr ebx, 5              ;// scoot index to a group+1

        DEBUG_IF <ebx !> 6>     ;// what ever called this passed a bad value

        .IF esi & 1fh       ;// front color?
            mov app_settings.colors.pal_group[ebx*8-8].hsv_1, eax
        .ELSE               ;// back color
            mov app_settings.colors.pal_group[ebx*8-8].hsv_0, eax
        .ENDIF

        invoke gdi_BuildColorGroup  ;// build the color group
        invoke gdi_SyncPalettes     ;// synchronizethe palettes

    .ENDIF


    ;// that's it

        ret

gdi_SetThisColor    ENDP






ASSUME_AND_ALIGN
gdi_LoadColorSet PROC USES esi edi

    ;// action: preset -> app_settings
    ;//         then call gdi_BuildColorSet


    ;// eax must be an index

        DEBUG_IF <eax !> 4>     ;// what ever called this passes a bad value

    ;// figure out where to load from

        .IF !eax
            mov eax, 5  ;// the defualt set is one passed the end of app_settings
        .ENDIF  ;// loading one of the presets

        mov edx, SIZEOF GDI_PALETTE
        dec eax
        mul edx
        lea esi, app_settings.presets[eax]

        ASSUME esi:PTR GDI_PALETTE          ;// now esi point at the GDI_PALETTE to load

    ;// first we xfer the preset to app_settings

        lea edi, app_settings.colors
        mov ecx, (SIZEOF GDI_PALETTE)   / 4
        rep movsd

    ;// then we call gdi_BuildColorSet to do the rest

        invoke gdi_BuildColorSet

    ;// that's it

        ret

gdi_LoadColorSet ENDP


ASSUME_AND_ALIGN
gdi_SaveColorSet PROC uses esi edi

    ;// action: app_settings -> preset

    ;// eax must be the index to store to
    ;// zer0 = preset zero

        DEBUG_IF <eax !> 3>     ;// what ever called this passed a bad value

    ;// figure out where to store to

        mov edx, SIZEOF GDI_PALETTE
        mul edx
        lea edi, app_settings.presets[eax]
        lea esi, app_settings.colors
        mov ecx, SIZEOF GDI_PALETTE / 4
        rep movsd

    ret

gdi_SaveColorSet ENDP


ASSUME_AND_ALIGN
gdi_BuildColorSet PROC

    ;// action: app_settings -> gdi_resources
    ;//                      -> oBmp_palette
    ;//                      -> menu_palette
    ;//                      -> gdi_hDC

    ;// scan through each of the app colors and call gdi_BuildColor

        xor esi, esi
    @0: invoke gdi_BuildColor
        inc esi
        cmp esi, COLOR_SYSTEM_MAX
        jb @0

    ;// then scan through all of the groups and call gdi_BuildColorGroup

        mov ebx, 1
    @1: invoke gdi_BuildColorGroup
        inc ebx
        cmp ebx, 7
        jb @1

    ;// then we synchronize the palettes

        invoke gdi_SyncPalettes

    ;// that should do it

        ret

gdi_BuildColorSet ENDP




;/////////////////////////////////////////////////////////////////////////
;//
;//     gdi_BuildColorGroups        action app_settings -> oBmp_palette
;//                                        app_settings -> menu_palette

comment ~ /*

    here's how this works

    assume that the base color is H0 = 0
    and that the detail color is H1 = 1/2
    these will be constant

    user can changes any of the six, with values called sH0, sS0, sV0, sH1, sS1, sV1

    the task is to convert the 32 colors into what the user expects

    reference colors from gdi_ref_palette:  rH,rS,rV
    adjument values from app_settings:      sH0, sH1, sS0, sS1, sV0, sV1
    results go to oBmp_palette:             uH, uS, uV

    algorithm: (revamped a few time till it worked ;)

        if H < H1   uH = 2*(sH1-sH0)*H + sH0
        else

            add 1 to the lowest of sH1 and sH0
            uH = -2*(sH1-sH0)*H - sH0 + 2*sH1

        clip uH by ANDing with 255, or just use the low byte

            since 2*(sH1-sH0) is used in both cases
            and because it doesn't change in the group
            we'll calculate it ahead of time


        so we get A = 2*(sH1-sH0)

            no wrap = A * H + sH0
            wrap = A*(1-H) + sH0    1-H = 100h-H since H is a byte


        for saturation and value use the intermediate values dH0 and dH1

            if H < H1   dH0 = 2*(1-2*H)     dH1 = 4*H
            if H > H1   dH0 = 2*(2*H-1)     dH1 = 4*(1-H)


        then use

            uS = rS + dH0*(sS0-80h) + dH1*(sS1-80h)
            uV = rV + dH0*(sV0-80h) + dH1*(sV1-80h)

*/ comment ~

ASSUME_AND_ALIGN
gdi_BuildColorGroup PROC    ;//  STDCALL uses esi edi ebx

    ;// ebx must be the index of the group (preserved)

        DEBUG_IF <ebx==0 || ebx !> 6>   ;// bad index

        push ebp
        push ebx
        push esi
        push edi
        pushd 20h   ;// count for this group
        pushd 0     ;// holder for A

        st_count TEXTEQU <(DWORD PTR [esp+4])>
        st_A     TEXTEQU <(DWORD PTR [esp])>

    ;// get some values to start with

        dec ebx                     ;// pal_groups are one based

        lea ebp, app_settings.colors.pal_group[ebx*8]   ;// point at the correct adjuster
        inc ebx                     ;// put back at 256 color bitmap palette
        shl ebx, 7                  ;// each block of 32 colors group is 128 bytes
        mov esi, gdi_pRefPalette    ;// esi will iterate the reference palette
        lea edi, oBmp_palette[ebx]  ;// edi will iterate the destination palette
        add esi, ebx                ;// add offset to esi

        ASSUME esi:PTR HSV_COLOR        ;// rHSV    esi walks reference colors
        ASSUME ebp:PTR PALETTE_GROUP    ;// sHSV    ebp points at the adjuster for this group
        ASSUME edi:PTR RGB_COLOR        ;// uHSV    edi walks the destination

    ;// build st_A

        movzx ebx, [ebp].hsv_1.h;// sH1
        movzx edx, [ebp].hsv_0.h;// sH0
        sub ebx, edx            ;// sH1 - sH0
        shl ebx, 1              ;// 2*(sH1-sH0)
        mov st_A, ebx   ;// store on the stack

        .REPEAT

        ;// build the adjusted hue and compute dH0 and dH1

            movzx eax, [esi].h  ;// eax = H

            lea ecx, [eax*4]    ;// 4*H

            .IF eax < 80h   ;// if H < H1

                ;// eax = uH = A*H + sH0
                ;// ebx = dH0 = 2-4*H
                ;// ecx = dH1 = 4*H

                mov ebx, 200h   ;// 2
                sub ebx, ecx    ;// 2-4*H

            .ELSE           ;// if H > H1

                ;// eax = uH = A*(1-H) + sH0
                ;// ebx = dH0 = 4*H-2
                ;// ecx = dH1 = 4-4*H

                mov ebx, ecx    ;// 4H
                sub ebx, 200h   ;// 4H-2
                sub ecx, 400h   ;// 4H-4
                neg ecx         ;// 4-4H
                neg eax         ;// -H
                add eax, 100h   ;// 1-H

            .ENDIF

            mul st_A        ;// A*(1-H)

            ;// now we have:

            ;// eax = uH - sH0
            ;// ebx = dH0
            ;// ecx = dH1

        ;// finish up uH

            shr eax, 8                  ;// make up for byte muliply
            movzx edx, [ebp].hsv_0.h    ;// load sH0
            add eax, edx                ;// add, eax = uH

            mov [edi].r, al ;// store here for a moment

        ;// build uS = rS + sS0*dH0 + sS1*dH1

            movzx eax, [ebp].hsv_0.s    ;// sS0
            sub eax, 80h
            imul ebx
            push ebx    ;// save
            sar eax, 8  ;// adjust fraction, keep sign
            mov ebx, eax

            movzx eax, [ebp].hsv_1.s    ;// sS1
            sub eax, 80h
            imul ecx
            sar eax, 8  ;// adjust fraction, keep sign
            add ebx, eax

            movzx eax, [esi].s  ;// rS
            add eax, ebx
            .IF SIGN?
                xor eax, eax
            .ELSEIF eax > 0FFh
                mov eax, 0FFh
            .ENDIF
            mov [edi].g, al     ;// store here for a moment

            pop ebx ;// retrieve

        ;// build uV = rV + sV0*dH0 + sV1*dH1

            movzx eax, [ebp].hsv_0.v    ;// sV0
            sub eax, 80h
            imul ebx
            sar eax, 8  ;// adjust fraction, keep sign
            mov ebx, eax

            movzx eax, [ebp].hsv_1.v    ;// sV1
            sub eax, 80h
            imul ecx
            sar eax, 8  ;// adjust fraction, keep sign
            add ebx, eax

            movzx eax, [esi].v  ;// rV
            add eax, ebx
            .IF SIGN?
                xor eax, eax
            .ELSEIF eax > 0FFh
                mov eax, 0FFh
            .ENDIF
            mov [edi].b, al     ;// store here for a moment

        ;// convert to rgb and store

            mov eax, DWORD PTR [edi]
            invoke gdi_hsv_to_rgb   ;// convert hsv to rgb
            stosd                   ;// send to destination, iterate obmp_palette in the process
            add esi, SIZEOF HSV_COLOR   ;// point esi at next reference palette
            dec st_count            ;// descrease the count

        .UNTIL ZERO?


    ;// that's it

        add esp, 8

        pop edi
        pop esi
        pop ebx
        pop ebp

        ret

gdi_BuildColorGroup ENDP





ASSUME_AND_ALIGN
gdi_BuildColor PROC uses ebx esi edi

    ;// action: app_settings -> oBmp_palette
    ;//                      -> gdi_resources

    ;// esi must be the INDEX of the color to build
    ;// source color is grabbed from app_settings

    ;// this functions checks the GDI wrapper with said index and
    ;// makes sure that the brush and pen resources are built correctly
    ;// we also scan to check for dependant colors
    ;// it's up to what ever called this to synchronize the palettes

    DEBUG_IF <esi !> 31>    ;// what ever called this passed a bad value

    IF (SIZEOF GDI_WRAPPER) NE 16
        .ERR <following relies on gdi wrapper size being 16 bytes>
    ENDIF
    lea ebx, [esi*8 ]               ;// gdi wrappers are 16 bytes each
    lea ebx, gdi_resource[ebx*2]    ;// get the pointer
    ASSUME ebx:PTR GDI_WRAPPER

    ;// 0) skip if already done is set
    .IF !([ebx].bFlags & GDIW_ALREADY_DONE)

        mov eax, app_settings.colors.sys_color[esi*4]   ;// get the color

    ;// 1)  if this wrapper allocates resources
    ;//     make sure the color is unique for all 32 colors

        .IF [ebx].bFlags & GDIW_RESOURCE_TEST               ;// need to do this ?

        ;// since there are now three groups, this doesn't quite work anymore
        ;// we need all colors to be unique
        ;// so we'll:
        ;//     set a flag (very top bit) at the current value
        ;//     scan and adjust untill unique
        ;//     reset the flag

            or app_settings.colors.sys_color[esi*4], 80000000h
            ;// set the top bit so we don't find ourselves

        scan_up:                        ;// increament blu until unique

            lea edi, app_settings.colors.sys_color
            mov ecx, 20h                ;// 32 colors
            repne scasd                 ;// scan for a match
            jnz scan_done               ;// done if none found
            inc al                      ;// bump the blue value
            jnz scan_up                 ;// scan again if blu didn't wrap

        ;// scan down, blu wrapped

            mov eax, app_settings.colors.sys_color[esi*4]   ;// get the origonal color
            and eax, 7FFFFFFFh          ;// turn the flag off

        scan_down:                      ;// decrease blu untill unique

            dec al                      ;// decrease blue
            DEBUG_IF( OVERFLOW? )       ;// not supposed to happen
            lea edi, app_settings.colors.sys_color  ;// get the block pointer
            mov ecx, 20h                ;// scan 32 colors
            repne scasd                 ;// scan until match
            jz scan_down                ;// if match, do again

        scan_done:

            ;// now eax has a unique color

            mov app_settings.colors.sys_color[esi*4], eax   ;// store in app_settings
            mov oBmp_palette[esi*4], eax                    ;// store in oBmp

            mov edi, eax                ;// xfer to edi

    ;// 2) build the pens and brushes

            RGB_TO_BGR edi              ;// convert edi to a colorref
            movzx esi, [ebx].bFlags     ;// get the flags

        ;// check the brush flag

            .IF esi & GDIW_BRUSH
                .IF [ebx].hBrush
                    invoke DeleteObject, [ebx].hBrush
                    DEBUG_IF <!!eax>
                .ENDIF
                invoke CreateSolidBrush, edi
                mov [ebx].hBrush, eax
            .ENDIF

        ;// check the pen_1 flag

            .IF esi & GDIW_PEN_1
                .IF [ebx].hPen_1
                    invoke DeleteObject, [ebx].hPen_1
                    DEBUG_IF <!!eax>
                .ENDIF
                invoke CreatePen, PS_SOLID, 1, edi
                mov [ebx].hPen_1, eax
            .ENDIF

        ;// check the pen_3 flag

            .IF esi & GDIW_PEN_3
                .IF [ebx].hPen_3
                    invoke DeleteObject, [ebx].hPen_3
                    DEBUG_IF <!!eax>
                .ENDIF
                invoke CreatePen, PS_SOLID, GDI_PEN3_WIDTH, edi
                mov [ebx].hPen_3, eax
            .ENDIF

        ;// make sure we catch the dotted selection pen

        ;// build the dotted pens for connecting pens

            .IF esi == COLOR_DESK_TEXT
                .IF hPen_dot
                    invoke DeleteObject, hPen_dot
                .ENDIF
                mov eax, oBmp_palette[COLOR_DESK_TEXT*4]
                RGB_TO_BGR eax
                invoke CreatePen, PS_DOT, 0, eax
                mov hPen_dot, eax
            .ENDIF

    ;// 3) check for dependant colors

            BGR_TO_RGB edi

            .IF [ebx].depend_1
                movzx esi, [ebx].depend_1
                mov app_settings.colors.sys_color[esi*4], edi
                invoke gdi_BuildColor
            .ENDIF
            .IF [ebx].depend_2
                movzx esi, [ebx].depend_2
                mov app_settings.colors.sys_color[esi*4], edi
                invoke gdi_BuildColor
            .ENDIF
            .IF [ebx].depend_3
                movzx esi, [ebx].depend_3
                mov app_settings.colors.sys_color[esi*4], edi
                invoke gdi_BuildColor
            .ENDIF

        .ELSE       ;// no resources

            mov oBmp_palette[esi*4], eax    ;// store in bmp_palette

        .ENDIF

    ;// 4) set the already done bit

        or [ebx].bFlags, GDIW_ALREADY_DONE

    .ENDIF

    ;// that's it

        ret

gdi_BuildColor ENDP



ASSUME_AND_ALIGN
gdi_SyncPalettes PROC

    ;// this just clears all the ALREADY_DONE BITS
    ;// to indicate that all the palletes are synchronized

    mov edx, COLOR_SYSTEM_MAX * SIZEOF GDI_WRAPPER  ;// 32*16
    jmp @1
@0: and gdi_resource[edx].bFlags, NOT GDIW_ALREADY_DONE
@1: sub edx, 16
    jns @0

    ;// then we want to set the current pen to a bad value

    mov gdi_current_color_ind, -1


    ;// do a call to dib_sync palettes
    ;// this will make suree all the dib are synced

    invoke dib_SyncPalettes

    ;// then do the same for the button bitmaps

    invoke gdi_SyncButtonPalettes

    legend_Update   PROTO   ;// defined in hwnd_status.asm
    invoke legend_Update



    ret

gdi_SyncPalettes ENDP








;////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////
;///
;///
;///    C O L O R   T R A N S L A T I O N
;///
;///    there are two flavours, rgb and bgr
;///
;///
;///



ASSUME_AND_ALIGN
gdi_bgr_to_hsv PROC uses ebx

    ;// eax must hold a COLORREF 0BGR
    ;// returns with eax as hsv

    mov ecx, eax
    mov ebx, eax
    shr ecx, 16
    shr ebx, 8

    call gdi_color_to_hsv

    ret

gdi_bgr_to_hsv ENDP



ASSUME_AND_ALIGN
gdi_rgb_to_hsv PROC uses ebx

    ;// eax must hold a PALETTE 0RGB
    ;// returns with eax as hsv

    mov ecx, eax
    mov ebx, eax
    shr eax, 16
    shr ebx, 8

    call gdi_color_to_hsv

    ret

gdi_rgb_to_hsv ENDP


;// this does the actual convertion
ASSUME_AND_ALIGN
gdi_color_to_hsv PROC PRIVATE uses esi edi

    LOCAL iH:DWORD
    LOCAL delta:DWORD
    LOCAL j1:DWORD
    LOCAL j2:DWORD

    and eax, 0FFh   ;// R
    and ebx, 0FFh   ;// G
    and ecx, 0FFh   ;// B

    xor edx, edx

;//  float max = MAX (r, MAX (g, b));
;//  float min = MIN (r, MIN (g, b));

    .IF eax > ebx           ;// a > b
        .IF eax > ecx       ;// a > b   a > c
            mov esi, eax
            .IF ebx > ecx   ;// a > b   a > c   b > c
                mov edi, ecx
            .ELSE
                mov edi, ebx
            .ENDIF

            ;// a is max
            mov j2, 0
            sub ebx, ecx
            mov j1, ebx

        .ELSE               ;// a > b   a < c
            mov esi, ecx
            mov edi, ebx

            ;// c is max
            mov j2, 4
            sub eax, ebx
            mov j1, eax

        .ENDIF
    .ELSE                   ;// b > a
        .IF ebx > ecx       ;// b > a   b > c
            mov esi, ebx
            .IF eax > ecx   ;// b > a   b > c   a > c
                mov edi, ecx
            .ELSE           ;// b > a   b > c   a < c
                mov edi, eax
            .ENDIF

            ;// b is max
            mov j2, 2
            sub ecx, eax
            mov j1, ecx

        .ELSE               ;// b > a   b < c
            mov esi, ecx
            mov edi, eax

            ;// c is max
            mov j2, 4
            sub eax, ebx
            mov j1, eax

        .ENDIF
    .ENDIF

    ;// now esi is the max  and also the V value
    ;// and edi is the min

;//  *v = max;


;// float delta = max - min ;

    sub edi, esi
    mov iH, 0
    neg edi
    mov delta, edi  ;// store now

;//  if (max != 0.0)   *s = delta / max;  iS = 256*delta / max
;//     else *s = 0
    .IF esi

        shl edi, 8  ;// * 256
        mov eax, edi
        idiv esi    ;// now eax is iS

        .IF eax

            ;// h = ( j2 + j1/delta ) * 60

            fild    j1
            fidiv   delta
            fiadd   j2
            fmul    math_42_2_3
            fistp   iH

        .ENDIF

        mov edi, eax    ;// edi is iS

    .ELSE

        xor edi, edi

    .ENDIF

    ;// edi is iS
    ;// esi is iV
    ;// iH was defined taken care of above

    mov edx, iH
    .IF edi > 255
        mov edi, 255
    .ENDIF
    and edx, 0FFh   ;// hue can be negative, we remove the sign here <-- abox224
    shl edi, 8
    mov eax, esi
    shl edx, 16

    or eax, edi
    or eax, edx

    ;// that should do it

    ret

gdi_color_to_hsv ENDP



;// this struct is needed for the hsv to color conversion

HSV_TO_COLOR STRUCT

    iH  dd  0
    iS  dd  0
    iV  dd  0

    ii  dd  0

    iR  dd  0
    iG  dd  0
    iB  dd  0

HSV_TO_COLOR ENDS


ASSUME_AND_ALIGN
gdi_hsv_to_bgr PROC uses ebx

    LOCAL HTC:HSV_TO_COLOR

    lea ebx, HTC
    ASSUME ebx:PTR HSV_TO_COLOR

    call gdi_hsv_to_color

    .IF CARRY?

        ;// build the color
        mov edx, [ebx].iB
        mov ecx, [ebx].iG
        movzx eax, BYTE PTR [ebx].iR
        shl edx, 16
        shl ecx, 8
        or eax, edx
        or eax, ecx

    .ENDIF

    ret

gdi_hsv_to_bgr ENDP




ASSUME_AND_ALIGN
gdi_hsv_to_rgb PROC uses ebx

    LOCAL HTC:HSV_TO_COLOR

    lea ebx, HTC
    ASSUME ebx:PTR HSV_TO_COLOR

    call gdi_hsv_to_color

    .IF CARRY?

        ;// build the color
        mov edx, [ebx].iR
        mov ecx, [ebx].iG
        movzx eax, BYTE PTR [ebx].iB
        shl edx, 16
        shl ecx, 8
        or eax, edx
        or eax, ecx

    .ENDIF

    ret

gdi_hsv_to_rgb ENDP



ASSUME_AND_ALIGN
gdi_hsv_to_color PROC PRIVATE

    ASSUME ebx:PTR HSV_TO_COLOR

    ;// eax must contain 0hsv

    ;// first we want to get the three values

        mov [ebx].iV, eax
        shr eax, 8
        mov [ebx].iS, eax
        shr eax, 8
        mov [ebx].iH, eax

        and [ebx].iV, 0FFh
        and [ebx].iH, 0FFh
        and [ebx].iS, 0FFh

    ;// if no satuartion, then we're just grey

    ;//  if (s == 0) /* Grayscale */    *r = *g = *b = v;
    jnz @0
        ;// grey, use iV to build

        xor eax, eax
        mov al, BYTE PTR [ebx].iV
        mov ah, al
        shl eax, 8
        mov al, ah
        clc
        ret

    ;// build the correct color
@0:
    ;// aa = v - v*s
    ;// cc = v - v*s + v*s*f = aa + vsf
    ;// bb = v - v*s*f

    ;// H is 0 to 255
    ;// we want to divide it into six quadrants

    ;// iH / .0234375       ;// thats 6/256
    ;// h *= 6.0;           ;// divide into six quadrants ??!

        fild [ebx].iH               ;// iH
        fmul math_6_256
    ;//    i = ffloor (h);  ;// i is the quadrant
        fld st              ;// H   H
        fsub math_1_2
        frndint             ;// ii  H
        fist [ebx].ii           ;// H
    ;//    f = hh - ii;     ;// f is fractional part of that quadrant (0 to 1)
        fsub                ;// f

    ;// continue on building the actual color
    ;// since V is properly scaled, we don't have to multiply v by 256
    ;// but we do have to rescale s

        fild [ebx].iS   ;// iS      f
        fmul math_1_256
                        ;// s       f
        fild [ebx].iV   ;// v       s       f

        fld st(1)       ;// s       v       s       f
        fmulp st(3), st ;// v       s       sf
        fmul st(1), st  ;// v       vs      sf
        fmul st(2), st  ;// v       vs      vsf

        fsubr st(1), st ;// v       aa      vsf
        fld st(2)       ;// vsf     v       aa      vsf
        fadd st, st(2)  ;// cc      v       aa      vsf
        fxch            ;// v       cc      aa      vsf
        fsubr st(3), st ;// v       cc      aa      bb

    ;// then build the color

    ;// now we test wich quadrant

        xor eax, eax
        or eax,  [ebx].ii
        jnz @3

        ;//     case 0: *r = v;  *g = cc; *b = aa;
        ;// v       cc      aa      bb
        fistp [ebx].iR
        fistp [ebx].iG
        fistp [ebx].iB
        stc
        fstp st
        ret

    @3: cmp eax, 3
        ja @4
        jb @2
        ;//     case 3: *r = aa; *g = bb; *b = v
        ;// v       cc      aa      bb

        fistp [ebx].iB
        fstp st
        fistp [ebx].iR
        stc
        fistp [ebx].iG
        ret

    @2: dec eax
        jz @1
        ;//     case 2: *r = aa; *g = v;  *b = cc; break;   ;// green
        ;// v       cc      aa      bb

        fistp [ebx].iG
        fistp [ebx].iB
        fistp [ebx].iR
        stc
        fstp st
        ret

    @1: ;//     case 1: *r = bb; *g = v;  *b = aa; break;
        ;// v       cc      aa      bb
        fistp [ebx].iG
        fstp st
        fistp [ebx].iB
        stc
        fistp [ebx].iR
        ret

    @4: shr eax, 1
        jc @5
        ;//     case 4: *r = cc; *g = aa; *b = v;  break;   ;// blue
        ;// v       cc      aa      bb
        fistp [ebx].iB
        fistp [ebx].iR
        fistp [ebx].iG
        stc
        fstp st
        ret

    @5: ;//     case 5: *r = v;  *g = aa; *b = bb; break;
        ;// v       cc      aa      bb
        fistp [ebx].iR
        fstp st
        fistp [ebx].iG
        stc
        fistp [ebx].iB
        ret

gdi_hsv_to_color ENDP

;///
;///    C O L O R   T R A N S L A T I O N
;///
;///
;////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////






ASSUME_AND_ALIGN


END