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
;// GDI.INC         include file for gdi and shapes
;//
;//                 see more_notes: at the bottom
;//
;//     abox221--> pin inval values moved to gdi_pin.inc




;///////////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////////
;///
;///    GDI MODEL FOR OBJECTS
;///

comment ~ /*

DATA STRUCTURES

  SHAPES

    shapes tell the renderer how to blit the osc object
    they are assigned to osc's via containers (below)
    they are assigned to fonts via the font table
    they are assigned to triangles (pins) via the triangle table

    each GDI_SHAPE will have a masker and optional outline tables,
    these are arrays of RASTER_LINES
    a non-font shape will also have a size to streamline hit testing

    gdi_shapes also hold an fPOINT to offset the shape to some other reference point
    this is called OC (OscCenter)

    shapes that need initialize at program start are assigned to a linked list
    build_Shape is the central function to initialize a shape
    if the shape is part of a container, shape_Build will initialize the container as well

    shapes come in three flavours:

    SHAPE_IS_CIRCLE

        OC must be the x and y radius
        this allows for elliptical shapes as well

    SHAPE_IS_POLYGON

        require that pPoint points at an array of RA points
        and that the low word of dwFlags hold the number of points

    SHAPE_IS_CHARACTER

        requires that character hold upto four ascii characters to render

    the OC parameter bares extra explaination
    OC (osc_center) has three purposes

    1)  causes the region built from the RA points to be drawn entirly on the screen
    2)  used in containers to layout the E track
    3)  specify the xy radius of a circle

    the model is this:

    OC specifies the offset from boundry_TL to the center of the shape
        the shape does not actually need to be centered here
        but it MUST cause the built region to fall entirely on the screen
        there is no checking for this
        If part of a container, OC is the origon of the E track

      ex: a rectangle(5x7) is to be drawn at point Z referenced to point TL

        1)  define shape's OC as (2.5,3.5),and the point list accordingly
            do NOT set any SHAPE_CENTER bits
            DO set the RGN_OFS_OC bit
        2)  build shape will resterize and NOT adjust any thing
        3)  render then computes pDest  as (Z.y*span + Z.x)
        4)  results are the rectangle's TL drawn at Z

        OC may also be declared to be WHERE pDest is
        this means that a shape may be drawn so that pDest derived from graphic coordinates
        will render the shape so that OC falls exactly on pDest

      ex: a 22 pixel radius circle that is to drawn centered at coord Z.

        1)  define the shape's OC as the offset (22,22) to the center
            DO set SHAPE_MOVE_DEST flag should be set
            DO set SHAPE_RGN_OFS_OC
        2)  build shape will rasterize appropriately, then offset the first
            raster address by OC.
        3)  renderer then computes pDest as (Z.y*span + Z.x)
        4)  results are the circle centered at Z

    WHY region build offsets by 16, then scoots it back:

        to allow for the expanded hover
        pDest will always come out right regardless what the origon is


  MASKERS and OUTLINERS

    both are arrays of RASTER_LINES
    both are built by gdi_BuildShape
    both are held by gdi_shape records

    maskers will raster the entire shape
    mask tables may be used to fill, move or hittest
    every shape is assigned a masker

    outliners only do the borders and are used for highlighting
    outline tables are optional
    there are three possible outliners, 1 2 and 3
    outliner1 is expanded by 1 pixel
    outliner2 is expanded by 3 pixels
    outliner3 is expanded by 5 pixel
    any shape except fonts may be outlined

  RASTER_LINES

    optimization is accomplished via raster line tables
    these are simply a list of the horizontal lines needed to
    blt, fill, outline and hittest the shape,
    there are some special considerations for these tables
    see shape_Move for details

  RA POINTS

    these are simply polar coords (radius,angle)
    to allow for an expanded outline, RA points are used
    many gdi_shapes will point to an array of these
    each RA point is defined as an fPOINT
    OC must also be set so that a Win32 region may be built from the RA points that
    falls entirely on the screen

  CONTAINERS

    containers hold parameter nessesary to define where connected pins should be placed
    every container also holds a gdi_shape
    containers are automatically assigned intersectors (unless it's a circle)

    a container bounds the pin to an area of the screen so it appears to be touching the osc
    all osc_objects must have a container
    any number of objects may share the same container
    containers define the E track used by pin_Layout, shape_Intersect, pin_Update


  INTERSECTERS (I_POINTS)

    polygons needs a special list of points to determine where the pin should go
    to do this, the container must point at an intersector table

    intersector table are simply an array of I_POINTS,
    start points and the direction to get to the next point
    direction is stored in both un-normalized (shape_Intersect)
    and normalized (pin_Update) form

    intersectors are always assumed to be relative to the center of the container
    intersectors are defined by build_Shape

    only containers that are polygons are assigned intersectors

  -----------------------------------------------------------------------------------------------

    INITIALIZATION

    shapes must be initialized by calling gdi_BuildShape
    shapes are built by drawing the desired item on the gdi display
    then rasterizing them by scanning for what was drawn
    each scan line will then be encoded as a RASTER_LINE

    the actual shape is defined by using Win32 regions
    this poses a peculiar problem in that the region coordinates appear to get truncated,
    making it very difficult to get streamlined polygons for the intersector tables

  -----------------------------------------------------------------------------------------------


OTHER SYSTEMS USING THIS FORMAT

  FONTS

    two fonts are also cached as GDI_SHAPES
    these are the pin fonts and the bus fonts
    fonts may be 1 to 4 characters
    every combination of string,font type is unique, and resides in an array

    call font_locate to get a GDI_SHAPE for a particular character
    memory is maintained automatically

    locating an unknown character is expensive,
    it is best to cache the returned shape pointer once it is found

    see gdi_font.asm for more details

  SHAPE_CHAR

    to draw strings we need some extra geometry as well as a center and top pointer
    the GDI_SHAPE.rect field works nicely for this

  TRIANGLES

    triangle for pins are built in a table with every unique triangle
    there is also a b_search routine to quickly locate any one of them given a
    direction vector. most of the details are found in gdi_triangle.asm

  DIB

    custom bitmaps be be assigned for objects to draw on
    these can also be rasterized by calling dib_Rasterize( ptr )

    see gdi_dib.asm for more details



*/ comment ~






;////////////////////////////////////////////////////////////////////////////////
;//
;//
;//     DATA STRUCTURES
;//

;// I_POINT     intersector table (allocated by build shape)
;//                               ( generated by RA points)

    ;// intersectors are lists of lines in vector form
    ;// P is always reletive to the center of the container defined by osc_to_cen
    ;// Q is set so P+Q*1=next_point

    I_POINT STRUCT

        Q   fPOINT  {}  ;// direction (NOT normalized)  ( stored first for cache reasons )
        P   fPOINT  {}  ;// start location of this line ( generated from RA )

    I_POINT ENDS

;// RASTER LINE         (allocated by build shape)

    RASTER_LINE STRUCT

        jmp_to      dd  0   ;// index of jump table to jump to
        dest_wrap   dd  0   ;// how to get to the next line on the dest (add to current address)
        dw_count    dd  0   ;// number of DWORDs to process
        source_wrap dd  0   ;// how to get to the next line on the source (add to current adress)

    RASTER_LINE ENDS

;// SHAPE CHAR fonts use this instead of the size       (filled in by build shape)

    SHAPE_CHAR STRUCT

        tl_adjust dd 0  ;// offset from TL pdest to CEN pDest
                        ;// add this to the first pDest to get back from center
                        ;// to top left where windows drew it
        max_x   dd  0   ;// width as measured by the font builder

    SHAPE_CHAR ENDS


;// GDI SHAPE       (user defined struct, may be part of a container)
;//                 ( may also be assigned on the fly )
;//                 ( triangle_Locate depends on gdi_shape being 16 dwords)

    GDI_SHAPE   STRUCT

    ;// 0   user specified (all required)

        dwFlags     dd  0   ;// flags for initialization and num points (see below)
                            ;// if part of a container, the flags effect the container as well
        UNION
        pPoints     dd  0   ;// pointer to the RA point list (polygon, intsecter)
        character   dd  0   ;// character for fonts, if sign bit is set, draw characters on top of each other
        dword_size  dd  0   ;// for dib's this is the dword size of the user image (not the allocated size)
        ENDS
        OC      fPOINT {}   ;// offset from shape bounding rect to center of track/shape

    ;// 1   user specified

        comment ~ /*

        note MASM does not like expanding macros inside unions
        doing this will screw up the listing file and browser information

            UNION
            slist_Declare_link shape_list, GDI_SHAPE    ;// list for allocating/deallocating
            slist_Declare_link font_pin, GDI_SHAPE      ;// list for allocating/deallocating
            slist_Declare_link font_bus, GDI_SHAPE      ;// list for allocating/deallocating
            slist_Declare_link dib, DIB_CONTAINER, shape;// list for allocating/deallocating
            ENDS

        so instead, we declare these lists as aliases
        ONLY THE FIRST declare link allocates space

        */ comment ~
        slist_Declare_link shape_list, GDI_SHAPE        ;// list for allocating/deallocating
        slist_Declare_alias_link font_pin, shape_list   ;// list for allocating/deallocating
        slist_Declare_alias_link font_bus, shape_list   ;// list for allocating/deallocating
        slist_Declare_alias_link dib, shape_list, DIB_CONTAINER, shape  ;// DIB_CONTAINER, shape;// list for allocating/deallocating

        pSource dd  0       ;// source for movable shapes (used for static shapes)
                            ;// this is the pointer into the oBmp or a dib created by dib_Reallocate,
                            ;// it may be defined by bmp_composite (if  oBMP)

    ;// set by shape_BuildShape

        UNION
        siz POINT {}            ;// size of the shape
        shape_char SHAPE_CHAR {};// font's superseed the size with this item
        ENDS

    ;// 2   raster pointers (built by shape_BuildShape)

        pMask       dd  0   ;// ptr to mask table (fill, hittest, move)
        pOut1       dd  0   ;// ptr to outline 1  (fill)    (hover)
        pOut2       dd  0   ;// ptr to outline 2  (fill)    (lock/selected)
        pOut3       dd  0   ;// ptr to outline 3  (fill)    (grouped/good/bad)

    ;// 3   for DIB's

        hDC         dd  0   ;// the dc to use
        hBmp        dd  0   ;// the bitmap handle
        h_alloc     dd  0   ;// this reduces reallocation, keeps track of last allocated height
                            ;// it is also used by fonts to count blocks
        hOldBmp     dd  0   ;// this is the old bitmap to reselect

    GDI_SHAPE   ENDS

    ;// values for dwFlags

    ;// types of shapes

        SHAPE_IS_CIRCLE     equ 00000000h   ;// circle or ellipse
                                            ;// OC must specify the radius

        SHAPE_IS_POLYGON    equ 00010000h   ;// requires num points in lower 16 bits of flags
                                            ;// requires pPoints

        SHAPE_IS_CHARACTER  equ 00020000h   ;// requires character

        SHAPE_IS_TEST       equ 00030000h   ;// test to save a couple cycles

        SHAPE_IS_DIB        equ 00040000h   ;// traps interlinking dib and container stuff
                                            ;// see DIB_ALLOCATE below

        SHAPE_NO_ROUND_ADJUST equ  80000h   ;// kludge for the round problem
                                            ;// see shape_build


    ;// flags for building

        SHAPE_IS_CONTAINER  equ 00100000h   ;// shape is part of a container (below)
                                            ;// initialize does extra work to setup the container
                                            ;// also builds rAB and the intersector

        SHAPE_BUILD_OUT1    equ 00200000h   ;// builds expanded by 1
        SHAPE_BUILD_OUT2    equ 00400000h   ;// builds expanded by 2
        SHAPE_BUILD_OUT3    equ 00800000h   ;// builds expanded by 3

    ;// these flags specify how OC is used (see above)

        SHAPE_RGN_OFS_OC    equ 01000000h   ;// offset the region by OC
                                            ;// before building the raster

        SHAPE_MOVE_SRC_OC   equ 02000000h   ;// move the fixed source by OC (req pSource)

        SHAPE_MOVE_DST_OC   equ 04000000h   ;// move raster[0] by OC (both src and dest)

        SHAPE_MOVE_DST_SIZ  equ 08000000h   ;// move raster[0] by SIZ (both src and dest)

    ;// more flags for dibs. These are the shifted forms of the DIB_ALLOCATE

        SHAPE_DIB_HAS_SHAPE equ 00100000h   ;// dib has a shape attached to it
        SHAPE_DIB_HAS_INTER equ 00200000h   ;// dib has a shape AND and intersector

    ;// lastly we get an initialized flag

        SHAPE_INITIALIZED   equ 80000000h   ;// prevents doing twice


;// GDI CONTAINER       (user defined struct [contains a shape as well)
;//                     use GBUILD.cpp to simplify the creation of these


    GDI_CONTAINER   STRUCT

    ;// 0   user defined ( all required )

        Q       dd      3       ;// Q number of the harmonic (0,2,3)
        S       REAL4   0.1e+0  ;// S ratio for harmonic (ignored if Q is zero)
        AB      fPOINT  {}      ;// scalers for the E track
                                ;// if Q=0, AB.x,AB.y must be the x,y radius

    ;// 1   ( system defined )

        pInter  dd      0       ;// points at itersector table for a shape
        ;//k1       REAL4   0.0     ;// offset for GA dynamics  (set by initializer)
        pad_1_1 dd  0
        ;//k2       REAL4   0.0     ;// scale for GA dynamics   (set by initializer)
        pad_1_2 dd  0
        a_24    REAL4 0.0   ;// alpha point used for Q=3 shapes (see pheta_11.mcd)

    ;// 2 3 4 5     ( shape struct, filled in as required )
    ;//             ( shape.dwFlags should have the container bit set

        shape   GDI_SHAPE {}

    ;// 6

    GDI_CONTAINER ENDS      ;// total size 24 dwords




    ;// useful macros

    CONTAINER_TO_MASK MACRO cont:req, mask:req

        mov mask, [cont].shape.pMask    ;// get the mask table
        DEBUG_IF <!!mask>               ;// mask table was not set

        ENDM

    SHAPE_TO_MASK MACRO shape:req, mask:req

        mov mask, [shape].pMask         ;// get the mask table
        DEBUG_IF <!!mask>               ;// mask table was not set

        ENDM

    SHAPE_TO_OUT1 MACRO shape:req, out1:req

        mov out1, [shape].pOut1         ;// get the out1 table
        DEBUG_IF <!!out1>               ;// out1 table was not set

        ENDM

    CONTAINER_TO_OUT1 MACRO cont:req, out1:req

        mov out1, [cont].shape.pOut1    ;// get the out1 table
        DEBUG_IF <!!out1>               ;// out1 table was not set

        ENDM

    SHAPE_TO_OUT2 MACRO shape:req, out2:req

        mov out2, [shape].pOut2         ;// get the out2 table
        DEBUG_IF <!!out2>               ;// out2 table was not set

        ENDM

    CONTAINER_TO_OUT2 MACRO cont:req, out2:req

        mov out2, [cont].shape.pOut2    ;// get the out2 table
        DEBUG_IF <!!out2>               ;// out2 table was not set

        ENDM

    SHAPE_TO_OUT3 MACRO shape:req, out3:req

        mov out3, [shape].pOut3         ;// get the out3 table
        DEBUG_IF <!!out3>               ;// out3 table was not set

        ENDM

    CONTAINER_TO_OUT3 MACRO cont:req, out3:req

        mov out3, [cont].shape.pOut3    ;// get the out3 table
        DEBUG_IF <!!out3>               ;// out3 table was not set

        ENDM



    SHAPE_TO_SOURCE MACRO shape:req, src:req

        mov src, [shape].pSource
        DEBUG_IF <!!src>                ;// src is ZERO !!

        ENDM



;//
;//
;//     DATA STRUCTURES
;//
;////////////////////////////////////////////////////////////////////////////////



    EXTERNDEF gdi_temp_buffer:DWORD ;// used for building shapes
                                    ;// define in ABox_shapes.asm

    GDI_TEMP_BUFFER_SIZE EQU 4000h  ;// enough space to build any of the shapes we need

    EXTERNDEF pin_logic_shape_table:DWORD   ;// pointer to a table of logic shapes
                                            ;// use to draw the logic inputs
                                            ;// see PIN_LOGIC_INPUT


    EXTERNDEF   gdi_erase_rect:RECT
    EXTERNDEF   gdi_blit_rect:RECT
    EXTERNDEF   gdi_bEraseValid:BYTE
    EXTERNDEF   gdi_bBlitValid:BYTE

    EXTERNDEF   button_bitmap_table:DWORD   ;// used in popups


;////////////////////////////////////////////////////////////////////////////////
;//
;//                     these are register calls, see implementation for details
;//     FUNCTIONS
;//

    ;// allocations

        shape_Build     PROTO   ;// initialize a shape
        shape_Destroy   PROTO   ;// destroys the raster tables

        slist_Declare_external shape_list   ;// , GDI_SHAPE, pNext

        EXTERNDEF gdi_bNoOptimize:DWORD ;// rasterize can optimize a little bit
                                        ;// but it will kill the fonts,
                                        ;// this flag keeps track

    ;// debugging

        IFDEF DEBUGBUILD

            gdi_VerifyShapes PROTO

        ENDIF



    ;// raster functions, please see implementation for important details)

        shape_Fill      PROTO   ;// fills with solid color
        shape_Move      PROTO   ;// blits from oBmp
        shape_Test      PROTO   ;// tests if an address is inside the shape

    ;// intersection

        shape_Intersect PROTO   ;// determines where to place a pin

    ;// fonts

        slist_Declare_external font_pin ;// , GDI_SHAPE, pNext
        slist_Declare_external font_bus ;// , GDI_SHAPE, pNext

        font_Locate     PROTO   ;// locates a character sequence and creates new on demand
        font_Destroy    PROTO   ;// destroys both lists

    ;// button bitmaps

        gdi_SyncButtonPalettes PROTO

    ;// debugging

        IFDEF DEBUGBUILD

            font_VerifyFonts PROTO

        ENDIF

;//
;//                     these are register calls, see implementation for details
;//     FUNCTIONS
;//
;////////////////////////////////////////////////////////////////////////////////







;///////////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////////
;///
;///    TRIANGLES   implemented in triangle.asm
;///

    ;// set PIN_TRIANGLE_HIEGHT and WIDTH to adjust

    triangle_Locate     PROTO STDCALL
    triangle_BuildTable PROTO STDCALL
    triangle_Destroy    PROTO

;///
;///    TRIANGLES
;///
;///////////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////////







;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;//
;//
;//     T H E    D I S P L A Y     S Y S T E M
;//

comment ~ /*

    coord_systems and display surfaces

    there is an offscreen bitmap called gdi_pBmpBits
    it has a margin called the gutter, who's purpose is to eliminate in-line border checking
    the display screen (video screen) has it's origon at (gutter,gutter)
    all osc objects and pins are referenced in GDI coords
    when using windows gdi, be sure to offset into the gdi display surface

    terms:

        gdi always refers to the gdi display surface
        win or screen refers to the user screen

*/ comment ~



;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;//
;//                             defined in ABox_DIB.asm
;//     DISPLAY_SURFACES
;//
comment ~ /*

CUSTOM DISPLAY SURFACES

    the focus is to minimize redraw time so the object can move quickly

    some objects need their own cached surface to draw on
    moving this surface involves using the shape_Move function,
    so we must be able to define a pSource value
    this requires the CreateDIBSection be used
    followed by a shape_BuildDIB call to build the raster table

    objects that need custon display surfaces

    label
        any size
        draw text
        changes infrequently

    oscope
    spectrum
        fixed size
        draw lines
        changes constantly

    equation
    differential
        variable height
        max width
        draw text
        changes infequently

    plugin
        variable height
        fixed width
        draw text
        changes infrequently


    the dibs are created with the gdi_palette,
    so we also need to resync when the user color changes

    objects that need their own bitmap for use in shape_Move calls
    use the following scheme:

        call dib_Reallocate( ptr wid hig )

            returns: pointer to the DIB_WRAPPER to draw with
            ptr may also be passed as one of the two allocation flags

        call dib_Free( ptr ) to deallocate

            this MUST be called from the object's DTOR unles the object is shared
            in which case the object must keep track of the reference count

    Reallocate is used to simplify height changes,
    if the width does not change, and the height does,
    the surface does not need to be reallocated, only shortened
    this means we keep track of a allocated height


*/ comment ~


comment ~ /*

    DIB_CONTAINER

        the DIB_CONTAINER struct stores a DIB section and DC to use with it
        DO NOT INTERMIX SHAPE_BUILD and DIB_BUILD

        DIB_CONTAINER is simply a GDI_CONTAINER

*/ comment ~

        DIB_CONTAINER TEXTEQU <GDI_CONTAINER>

    ;// dib maiantainance

        slist_Declare_external  dib ;// , GDI_CONTAINER, shape.pNext    ;// list of dib's

        dib_Initialize  PROTO   ;// initializes the dib system
        dib_Destroy     PROTO   ;// destroys the dib system

    ;// allocate and deallocate

        dib_Reallocate  PROTO STDCALL pDib:DWORD, wid:DWORD, hig:DWORD
        dib_Free        PROTO STDCALL pDib:DWORD

        ;// special forms for dib_Reallocate :
        ;//
        ;//     pDib may be ONE of these flags
        ;//     flags are then stored for all subsequent operations
        ;//
        ;// see dib_Reallocate for more info

        DIB_ALLOCATE        equ 0   ;// allocate the dib
        DIB_ALLOCATE_SHAPE  equ 1   ;// allocate the shape (raster tables)
        DIB_ALLOCATE_INTER  equ 3   ;// allocate an intersector AND shape (intersector records)

        DIB_ALLOCATE_TEST   equ 3   ;// checks if the passed value is a pointer or a flag

        dib_SyncPalettes PROTO      ;// synchronizes all bitmaps in the list with the current palette

    ;// special drawing operations

        dib_Fill            PROTO   ;// fills the dib with a solid color
        dib_FillAndFrame    PROTO   ;// fills dib with color, 2 pixel border with another color
        dib_FillColumn      PROTO   ;// fills a column with a color
        dib_DrawLine        PROTO   ;// draws a line between two points
        dib_FillRect_ptr_ptr_height PROTO   ;// fills a rect using two pointers and a height

    ;// private function made public
    ;// don't call this

    ;// debugging

        IFDEF DEBUGBUILD

            dib_VerifyDibs PROTO

        ENDIF


        dib_initialize_shape PROTO  ;// implemented in gdi_Shapes.asm

    ;// 256 color bitmap support

    ;// this incorporates a bitmap info header
    ;// with enough space for a 256 color palette

    ;// one of these is allocated by dib_Initialize
    ;// and containes the current palette

comment ~ /*
        BITMAPINFO_256 STRUCT

            biSize          dd 40
            biWidth         dd 0
            biHeight        dd 0
            biPlanes        dw 0
            biBitCount      dw 0
            biCompression   dd 0
            biSizeImage     dd 0
            biXPelsPerMeter dd 0
            biYPelsPerMeter dd 0
            biClrUsed       dd 0
            biClrImportant  dd 0

            palette dd 256 dup (0)

        BITMAPINFO_256 ENDS

*/ comment ~



;///////////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////////
;///
;///    GDI   defined in GDI.asm
;///

    ;// global access

    EXTERNDEF gdi_hDC:DWORD             ;// objects draw with this dc
    EXTERNDEF gdi_pDib:DWORD            ;// objects may need access for dib functions

    EXTERNDEF gdi_client_rect:RECT      ;// where the client window if gdi coords
    EXTERNDEF gdi_desk_size:POINT       ;// size of the user's desktop

    EXTERNDEF gdi_bHasRendered:DWORD    ;// needed to clear the screen before building shapes

    GDI_GUTTER_WIDTH EQU 256            ;// MAKE IT BIG JUST IN CASE

    GDI_GUTTER_X EQU GDI_GUTTER_WIDTH
    GDI_GUTTER_Y EQU GDI_GUTTER_WIDTH

    EXTERNDEF gdi_pBmpBits:DWORD        ;// where the bits are

    EXTERNDEF gdi_bitmap_size:POINT     ;// total width and height, including the gutters

    EXTERNDEF gdi_bitmap_object_delta:DWORD ;// bmp_width - object width

    EXTERNDEF gdi_pBitsGutter:DWORD     ;// gdi address of screen(0,0)

    EXTERNDEF gdi_pBmpBits_bottom:DWORD ;// address of bottom diplayable line



    ;// conversion from gdi x,y to an offset into the gdi display surface

    GDI_POINT_TO_GDI_OFFSET MACRO P:req, reg:req

        .ERRIDN <P>, <reg>
        .ERRIDN <reg>, <eax>

        ;// P must be a POINT and be dot addressable
        ;// uses both eax and edx
        mov eax, gdi_bitmap_size.x
        mul P.y
        mov reg, P.x
        add reg, eax

        ENDM

    GDI_POINT_TO_GDI_ADDRESS MACRO P:req, reg:req

        ;// point (P) is assumed to be in GDI coords
        ;// see coord_systems

        .ERRIDNI <P>, <reg>, <ptr and reg must not the same>
        .ERRIDNI <P>, <eax>, <ptr cannot be eax>
        .ERRIDNI <P>, <edx>, <ptr cannot be edx>
        .ERRIDNI <reg>, <eax>, <reg cannot be eax>

        ;// P must be a POINT and be dot addressable
        ;// uses both eax and edx
        mov eax, gdi_bitmap_size.x
        mul P.y
        mov reg, gdi_pBmpBits
        add reg, P.x
        add reg, eax

        ENDM

    GDI_RECTTL_TO_GDI_ADDRESS MACRO R:req, reg:req

        ;// point (R) is assumed to be in GDI coords
        ;// see coord_systems

        .ERRIDN <R>, <reg>
        .ERRIDN <reg>, <eax>

        ;// R must be a RECT and be dot addressable
        ;// uses both eax and edx
        mov eax, gdi_bitmap_size.x
        mul R.top
        mov reg, gdi_pBmpBits
        add reg, R.left
        add reg, eax

        ENDM



;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;////
;////                       these start in the palette of object bmp
;////   COLOR DEFINITIONS   and may be adjusted by user preference
;////                       always specify colors in hex
;////                       where a width is required, use another trailing prefix
;////
;////   implemented in GDI_colors.asm

comment ~ /*

    Explaination

        the 256 color palette is divided into 8 groups of 32 colors each
        the lowest group contains abox system colors
        the next seven groups are assigned, one each, to the object classes

*/ comment ~


    ;// a palette group then defines how to build two sets of palette ramps,
    ;// one for the background and/or/base
    ;// the second for the details and/or highlights

    ;// these ramps are NOT stored in any particular order,
    ;// instead they are KEYED by hue=pure red for background
    ;// and hue = pure cyan for forground
    ;// linear interpolation does the rest

        RGB_COLOR STRUCT

            b   db  0
            g   db  0
            r   db  0
            nul db  0

        RGB_COLOR ENDS

        HSV_COLOR STRUCT

            v   db  0
            s   db  0
            h   db  0
            nul db  0

        HSV_COLOR ENDS

    PALETTE_GROUP   STRUCT  ;// size 8 bytes

        UNION
            hsv_0 HSV_COLOR {}  ;// adjusters for the base color
            dd  0
        ENDS
        UNION
            hsv_1 HSV_COLOR {}  ;// adjusters for the detail color
            dd  0
        ENDS

    PALETTE_GROUP   ENDS

comment ~ /*

OBJECT_COLORS

    from this, we can let the user choose a variety of color schemes
    each object class can then have a different color
    it is also easy to extract what colors the menues should be
    simply choose the pure colors for each

    now we need a function to build the palette, and assign the menu colors

        groups of colors

        each object type is allocated 32 colors
        grp indexs  class
        --- ------  ----------
        1   20-3F   controls
        2   40-5F   generators
        3   60-7F   routers
        4   80-9F   processing
        5   A0-BF   devices
        6   C0-DF   display

SYSTEM COLORS

    the lowest 32 colors are reserved a generic colors
    brushes, pens and fonts will be built from these
    see gdi_resource for values

    we also use this handy trick to maximally optimize hit testing

        using different indexs for the same color,
        we can get away with simply querying the color under the mouse
        from there we know if we hit test osc's or pins, or hit the desk

    gottcha: lower colors cannot be an exact match of higher colors
             this because pins and brushes will use the lower index
             making the hit testing not work
             use the gdi_SetColor function to account for this

    the master color list is in gdi_resource
    this is manipulated via GDI_WRAPPER structs


COLOR CREATION and EDITING sequences

    hWnd_colors.asm has the UI
    gdi_colors.asm does the actual work

    there are five items to keep track of

    app_settings specifies the colors the user wants, registry settings

    gdi_palette colors used in the gdi_hBitmap, should always match oBmp_palette

    ref_palette is the origonal palette specified at load time
    oBmp_palette is the current palette of the source bitmap

    app_start: oBmp_palette -> ref_palette

    user edit: -> app_settings

    app_settings + ref_palette -> oBmp_Palette -> gdi resources
                                               -> all dib_ palettes


*/ comment ~


    ;// the entire palette collection can now be defined

    GDI_PALETTE STRUCT

        sys_color   dd  32 dup(0)               ;// rgb values
        pal_group   PALETTE_GROUP 6 dup ({})    ;// pairs of colors

    GDI_PALETTE ENDS

    EXTERNDEF gdi_pRefPalette:DWORD ;// pointer to the reference palette
    ;// these are stored as hsv values and are used to build any and all color groups


comment ~ /*
;/////////////////

    signal colors

    ??  think about these, they almost make sense
    ??  a->t = logic    l->a = logic    t->
    ??
    ??  output pins would need tags
    ??  input pins would need tags
        program logic can do the rest
    ??

    organizing in a heirarchy would let us know what to display,
    the lower the color the higher the priority

*/ comment ~

;//////////////////////////////////////////////////////
;//////////////////////////////////////////////////////
;///
;///    color adjustement
;///
;//////////////////////////////////////////////////////
;//////////////////////////////////////////////////////
comment ~ /*

    see gdi_BuildColorGroup for some math

    objects are designed with only two base colors
    specified as (h=0,s,v) and (h=.5,s,v)
    use may adjust the hue and saturation of either one
    to adjust the other 32 colors we use ratios of the reference palette
    versus where user places the new reference colors.

  after the three attributes are calulated, the resulting rgb value can be defined and stored
  in the oBmpPallette


*/ comment ~


    ;// these are conversion functions
    ;// eax holds source and is returned with dest
    ;// use the appropriate rgb or bgr function to save some hasle

    ;// they're all implented in gdi_colors.asm

        gdi_bgr_to_hsv PROTO
        gdi_rgb_to_hsv PROTO
        gdi_hsv_to_rgb PROTO
        gdi_hsv_to_bgr PROTO

    ;//                                                     d w o r d
    ;// note:   many windows functions expect a COLORREF    00BBGGRR    BGR
    ;//         bitmaps contain PALETTEREF                  00RRGGBB    RGB
    ;//         use the following macros to convert

        RGB_TO_BGR MACRO reg:req
            bswap reg
            shr reg, 8
            ENDM

        BGR_TO_RGB MACRO reg:req
            bswap reg
            shr reg, 8
            ENDM








;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;////
;////                           all defined in gdi_resources.asm
;////   GDI DRAWING OBJECTS
;////
;////

    ;// CURSORS

        EXTERNDEF hCursor_normal:DWORD  ;// should be set to one of these
        EXTERNDEF hCursor_bad:DWORD     ;// standard bad cursor

    ;// fonts

        EXTERNDEF  szArial:BYTE
        FONT_PIN   equ 12 ;// height of arrow fonts, also for osc names and clock cycles
        FONT_BIG   equ 14 ;// height of osc font
        FONT_POPUP equ 16 ;// height of popup font
        FONT_LABEL equ 16 ;// height of label font
        FONT_HUGE  equ 24 ;// height of bigger osc font

        EXTERNDEF   hFont_pin:DWORD     ;// font used for drawing pin text
        EXTERNDEF   hFont_help:DWORD    ;// font to use for help displays
        EXTERNDEF   hFont_popup:DWORD   ;// font used for popup panels
        EXTERNDEF   hFont_osc:DWORD     ;// normal font for drawing on osc's
        EXTERNDEF   hFont_label:DWORD   ;// common font used for labels
        EXTERNDEF   hFont_huge:DWORD    ;// big font for drawing on osc's

    ;// PINS and BRUSHES

        EXTERNDEF   hBrush_null:DWORD   ;// needed for several operations
        EXTERNDEF   hPen_dot:DWORD
        EXTERNDEF   hPen_null:DWORD

    ;// GDI_WRAPPER is a table of 32 records
    ;// the records are arranged in order, one for each system palette entry
    ;// each record may contain up to 3 handles ( 1 brush and two pens )
    ;// flags specifies what gets built and what other objects depend on the color
    ;// upto three other objects can depend on the color

        GDI_WRAPPER STRUCT      ;// keep this struct at 4 dwords

            bFlags      db  0   ;// see below
            depend_1    db  0   ;// index of another object that relies on this one
            depend_2    db  0   ;//
            depend_3    db  0   ;//

            hBrush      dd  0   ;// brush for this color
            hPen_1      dd  0   ;// 1 pixel pen for this color
            hPen_3      dd  0   ;// 3 pixel pen pen for this color

        GDI_WRAPPER ENDS

        EXTERNDEF   gdi_resource:GDI_WRAPPER    ;// table of 32 resources

    ;// values for flags

        GDIW_BRUSH  equ 01h ;// build a brush with this color
        GDIW_PEN_1  equ 02h ;// build a one pixel pen for this color
        GDIW_PEN_3  equ 04h ;// build a three pixel pen for this color
        GDIW_FONT   equ 08h ;// doesn't build a font, but makes sure that the color
                            ;// is unique so a font can be set at that color

        GDIW_RESOURCE_TEST equ GDIW_BRUSH + GDIW_PEN_1 + GDIW_PEN_3 + GDIW_FONT

        GDIW_ALREADY_DONE equ 80h   ;// used to prevent excessive recursion when
                                    ;// calling build color

        GDI_PEN3_WIDTH  equ 2   ;// which looks better ??

    ;// equates for color indexes,
    ;// these occupy the lower 8 bits of dwHintI (below)
    ;// make sure these stay in sync with the gdi_resource table in gdi.asm

;////////////////////////////////////////////////////////////////////
;//
;//
;//     COLOR DEFINITIONS
;//


    include <colors.inc>


;//
;//     COLOR DEFINITIONS
;//
;//
;////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////
;//
;//
;//     signal colors
;//
comment ~ /*

    APIN.dwStatus holds a desired pin color
    APIN.dwHintI then holds the actual color used to draw the pin

    there are three realms to deal with:

    1)  the color to draw the pin with:

            this must be hit testable as a pin

    2)  the color to draw the connecting line with

            this must hit test as a desk color

    3)  the packed color is stored in APIN.color


    because the none of the realms are bit aligned, we get the following values:

*/ comment ~

;//     INVAL_COLOR_MASK    equ 0FFFFFF00h          ;// the lower 8 bits are the pin color
;//     INVAL_COLOR_TEST    equ NOT INVAL_COLOR_MASK    ;// use to strip out extra

        ;// after masking the zero based index of a SIGNAL color,
        ;// add this value to get the color to draw a PIN with
;//     COLOR_PIN_DEFAULT

        ;// starting with a PIN color, subtract this value to
        ;// get the color to draw a LINE with
;//     COLOR_LOWEST_PIN

;//
;//
;//     signal colors
;//
;////////////////////////////////////////////////////////////////////





    ;// then these function are useful

        gdi_PreInitialize   PROTO STDCALL
        gdi_Initialize      PROTO
        gdi_Destroy         PROTO

        gdi_SaveColorSet    PROTO   ;// app_settings -> preset
        gdi_LoadColorSet    PROTO   ;// preset -> app_settings
        gdi_BuildColorSet   PROTO   ;// app_settings -> oBmp_palette -> gdi_hDC -> gdi_resources -> menu_palette

    ;// gdi_SetColor_system PROTO   ;// also updates the status panel
    ;// gdi_SetColor_group  PROTO

        gdi_GetThisColor    PROTO
        gdi_SetThisColor    PROTO

    ;// gdi_GetColor_system PROTO
    ;// gdi_GetColor_group  PROTO

        gdi_SyncPalettes    PROTO

    ;// these track current selected items in the gdi_hDC
    ;// might save some time

        EXTERNDEF   gdi_current_brush:DWORD     ;// handle of currently selected brush
        EXTERNDEF   gdi_current_pen:DWORD       ;// handle of currently selected pen
        EXTERNDEF   gdi_current_font:DWORD      ;// handle of currently selected font
        EXTERNDEF   gdi_current_color_ind:DWORD ;// index of currently selected font color

    ;// here are some macros to manage the above.
    ;// the purpose is reduce the number of calls to SelectObject by keeping track
    ;// of the current selection.
    ;// only use this for gdi_hDC
    ;// also note that the object type is required

    ;// GDI_DC_SELECT_RESOURCE

    ;// example:    GDI_DC_SELECT_RESOURCE hPen_3, 16h
    ;//
    ;//         will select the 3 pixel wide pen with color number 16h
    ;//         for clarity, use the color definitions found in colors.inc

    GDI_DC_SELECT_RESOURCE MACRO item:req, index:req

        ;; // test_attr = OPATTR( index )

        IF (( OPATTR( index )) AND 16 ) ;// is index a register ??

            IFDIFI <index>, <eax>
                mov eax, index
            ENDIF
            shl eax, 4

        ELSE    ;// must be immediate

            mov eax, index * 10h

        ENDIF

        IFIDN   <item>, <hBrush>

            mov eax, gdi_resource[eax].hBrush
            DEBUG_IF <!!eax>    ;// this is supposed to be defined
            .IF eax != gdi_current_brush
                mov gdi_current_brush, eax
                invoke SelectObject, gdi_hDC, eax
            .ENDIF
            EXITM

        ENDIF
        IFIDN   <item>,<hPen_1>

            mov eax, gdi_resource[eax].hPen_1
            DEBUG_IF <!!eax>    ;// this is supposed to be defined
            .IF eax != gdi_current_pen
                mov gdi_current_pen, eax
                invoke SelectObject, gdi_hDC, eax
            .ENDIF
            EXITM

        ENDIF
        IFIDN   <item>,<hPen_3>

            mov eax, gdi_resource[eax].hPen_3
            DEBUG_IF <!!eax>    ;// this is supposed to be defined
            .IF eax != gdi_current_pen
                mov gdi_current_pen, eax
                invoke SelectObject, gdi_hDC, eax
            .ENDIF
            EXITM

        ENDIF

        .err <invalid GDI object item>

    ENDM

    ;// GDI_DC_SETCOLOR

    ;// sets the font color to the desired index

    ;// example: GDI_DC_SETCOLOR 10h
    ;//          sets the text to color number 10h

    GDI_DC_SET_COLOR    MACRO ind:req

        IFDIFI <ind>,<eax>
            mov eax, ind
        ENDIF

        .IF eax != gdi_current_color_ind
            mov gdi_current_color_ind, eax
            mov eax, oBmp_palette[eax*4]
            RGB_TO_BGR eax
            invoke SetTextColor, gdi_hDC, eax
        .ENDIF

    ENDM

    ;// GDI_DC_SELECT_FONT

    ;// selects a font

    ;// example: GDI_DC_SELECT_FONT hFont_huge

    GDI_DC_SELECT_FONT MACRO item:req

        IFIDN   @SubStr( <item>, 0, 6 ), <hFont_>

            mov eax, item
            .IF eax != gdi_current_font
                mov gdi_current_font, eax
                invoke SelectObject, gdi_hDC, eax
            .ENDIF

            EXITM

        ENDIF

        .err <invalid GDI object item>

    ENDM

    ;// this will retrieve the desired brush for functions that take a brush directly
    ;// can not check for existance

    ;// example: invoke FrameRect, gdi_hDC, ADDR rect, hBRUSH(17h)

    hBRUSH MACRO ind:req

        IF (( OPATTR( ind )) AND 16 )
            EXITM <gdi_resource[ind].hBrush>
        ELSE
            EXITM <gdi_resource[ind*16].hBrush>
        ENDIF

    ENDM


    ;// this will retrieve the desired pen for functions that take a brush directly
    ;// can not check for existance

    hPEN_1 MACRO ind:req

        IF (( OPATTR( ind )) AND 16 )
            EXITM <gdi_resource[ind].hPen_1>
        ELSE
            EXITM <gdi_resource[ind*16].hPen_1>
        ENDIF

    ENDM


    hPEN_3 MACRO ind:req

        IF (( OPATTR( ind )) AND 16 )
            EXITM <gdi_resource[ind].hPen_3>
        ELSE
            EXITM <gdi_resource[ind*16].hPen_3>
        ENDIF

    ENDM








;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;///
;///                                    defined in ABox_GDI.asm
;///    REDRAW AND INVALIDATION
;///

comment ~ /*

    now we get to the mechanism that coordinates the gdi_pBMP in gdi_hDC with the
    application screen. This also manages the mouse state, mouse capture, and keyboard focus
    see ABox_mouse.asm for details that are not covered here
    complain to author for completely missing details

    SCHEME:

        a WM UI handler works with an osc or a pin
        it tells GDI_INVALIDATE to set a command bit and add the object
        to the IC list. Command bits always start withe HINTI

        after the handler is finished, it calls gdi_Invalidate or app_Sync

        gdi_Invalidate converts the HINTI command bits into HINT2 opeartions and states
        calls to various other funtions may also be performed:

            pin_Layout
            osc_SetShape
            gdi_TestOnScreen
            gdi_BuildBoundry

    RULES OF THUMB

        if ONSCREEN is set, every thing about the object is assumed to be valid
        including it's shapes, positions, bits, etc

        if ONSCREEN is off, only the osc.rect and pin.pheta are correct

*/ comment ~

    ;// commands sent from osc ctor/dtor

        HINTI_OSC_CREATED           EQU 00000001h   ;// this osc has just been created

    ;// commands sent from objects that change their shapes

        HINTI_OSC_SHAPE_CHANGED     EQU 00000002h   ;// call set_shape before rebuilding boundry

    ;// commands sent from mouse handler or a function that it calls

        HINTI_OSC_MOVED             EQU 00000004h   ;// the osc has moved
        HINTI_OSC_MOVE_SCREEN       EQU 00000008h   ;// all the osc have moved

        HINTI_OSC_GOT_SELECT        EQU 00000010h   ;// this osc has been selected
        HINTI_OSC_LOST_SELECT       EQU 00000020h   ;// this osc is no longer selected

        HINTI_OSC_SHOW_PINS         EQU 00000040h   ;// this osc is to display it's unconnected pins
        HINTI_OSC_HIDE_PINS         EQU 00000080h   ;// this osc can hide it's un connected pins

        HINTI_OSC_GOT_HOVER         EQU 00000100h   ;// must also show pins
        HINTI_OSC_LOST_HOVER        EQU 00000200h   ;// does not have to hide pins

        HINTI_OSC_GOT_CON_HOVER     EQU 00000400h   ;// must also show pins
        HINTI_OSC_LOST_CON_HOVER    EQU 00000800h

        HINTI_OSC_GOT_LOCK_HOVER    EQU 00001000h
        HINTI_OSC_LOST_LOCK_HOVER   EQU 00002000h

        HINTI_OSC_GOT_CON_DOWN      EQU 00004000h   ;// must also hide pins
        HINTI_OSC_LOST_CON_DOWN     EQU 00008000h

        HINTI_OSC_GOT_LOCK_SELECT   EQU 00010000h   ;// called after selected
        HINTI_OSC_LOST_LOCK_SELECT  EQU 00020000h   ;// no longer locked

    ;// commands sent to osc's from opened_group_DefineG

        HINTI_OSC_GOT_GROUP         EQU 00040000h   ;// osc has gotten group membership
        HINTI_OSC_LOST_GROUP        EQU 00080000h   ;// osc has lost group membership

    ;// commands sent from gui thread to redraw the osc

        HINTI_OSC_UPDATE            EQU 00100000h   ;// the object need reblitted (also from popup handler)

    ;// commands sent to oscs from the play thread IC list

        HINTI_OSC_UPDATE_CLOCKS     EQU 00200000h   ;// the clocks display needs updated

        HINTI_OSC_GOT_BAD           EQU 00400000h   ;// this device is now bad
        HINTI_OSC_LOST_BAD          EQU 00800000h   ;// this device is now good

comment ~ /*

    moved to gdi_pin.inc
    objects should not have to deal with these

    ;// commands sent to pins from mouse actions

        HINTI_PIN_GOT_HOVER         EQU 00000001h
        HINTI_PIN_LOST_HOVER        EQU 00000002h

        HINTI_PIN_GOT_DOWN          EQU 00000004h
        HINTI_PIN_LOST_DOWN         EQU 00000008h

        HINTI_PIN_GOT_BUS_HOVER     EQU 00000010h
        HINTI_PIN_LOST_BUS_HOVER    EQU 00000020h

    ;// commands sent to pins from the IC list

        HINTI_PIN_UPDATE_CHANGING   EQU 00000040h   ;// the changing status has changed

    ;// commands sent to pins from mouse pin drag

        HINTI_PIN_PHETA_CHANGED     EQU 00000080h   ;// schedule for pin layout

    ;// commands sent to pins from pin_Show

        HINTI_PIN_HIDE              EQU 00000100h   ;// hide this pin, or try to
        HINTI_PIN_UNHIDE            EQU 00000200h   ;// unhide this pin

    ;// command sent when pin's shape changes

        HINTI_PIN_UPDATE_SHAPE      EQU 00000400h   ;// the logic or triangle shape has changed
        HINTI_PIN_UPDATE_COLOR      EQU 00000800h   ;// the color of this pin has changed
        HINTI_PIN_UPDATE_PROBE      EQU 00001000h   ;// pin has been probed

    ;// commands sent from pin connect/unconnect functions

        HINTI_PIN_CONNECTED         EQU 00002000h   ;// pin has been connected
        HINTI_PIN_UNCONNECTED       EQU 00004000h   ;// pin has been unconnected



*/ comment ~



    ;// use these macros to send commands to the I list

        GDI_INVALIDATE_OSC MACRO flag:req, osc:=<esi>, context:=<[ebp]>

            LOCAL already_in_list

        ;// uses only edx

            or [osc].dwHintI, flag
            dlist_IfMember_jump oscI,osc,already_in_list,context
            dlist_InsertTail oscI, osc,edx,context
        already_in_list:

            ENDM


    ;// use these functions to save some hassle

    ;// gdi_pin_MakeHidden      PROTO   ;// hides a pin, schedules for invalidation
    ;// gdi_pin_MakeUnHidden    PROTO   ;// unhides a pin, schedules for invalidation

        gdi_pin_set_color   PROTO STDCALL dwHintI:DWORD ;// set the color for pins and their connections
        gdi_pin_reset_color PROTO STDCALL dwHintI:DWORD ;// restores all the colors

        gdi_osc_BuildRenderFlags PROTO  ;// builds render bits from the osc's state
        gdi_pin_BuildRenderFlags PROTO  ;// builds render bits from the pin's state

        gdi_render_osc          PROTO   ;// default osc_base member, renders an osc

    ;// after all objects are invalidated, use this to
    ;// flush the list and invalidate the screen
    ;// this should be done at the end of WM handlers

    ;// note: handlers must call app_Sync instead

        gdi_Invalidate          PROTO   ;// call this to synchronize with windows
                                        ;// this will flush all the items in the I list

        gdi_EraseMouseConnect   PROTO   ;// defined in gdi_Inavliadte.asm
        gdi_BlitSelRect         PROTO




;// private inval flags
;//
;//     only routines in gdi_invalidate and gdi_display should use these values
;//     the mouse handlers may need to query them as well

;// HINTOSC flags tell us how to draw the osc
;// these are stored in osc.dwHintOsc

;// these bits are used in three arenas:
;//
;//     _INVAL_  is a command to subsequent processing in gdi_Invalidate
;//     _RENDER_ is a command to the renderer
;//     _STATE_  is a shared value, set by gdi_Invalidate, read by gdi_Render and mouse functions


    HINTOSC_INVAL_TEST_ONSCREEN     EQU 00000001h   ;// inval command
    HINTOSC_INVAL_UPDATE_BOUNDRY    EQU 00000002h   ;// inval command

    HINTOSC_INVAL_DO_PINS           EQU 00000004h   ;// pins need to be scanned anyways
    HINTOSC_INVAL_DO_PINS_JUMP      EQU 00000008h   ;// build the render flags for pins

    HINTOSC_RENDER_DO_PINS          EQU 00000010h   ;// render command

        ;// gdi_Invalidate turns this on
        ;// gdi_Render turns this off

    HINTOSC_INVAL_ERASE_BOUNDRY     EQU 00000020h   ;// inval command
    HINTOSC_INVAL_BLIT_RECT         EQU 00000040h   ;// inval command
    HINTOSC_INVAL_BLIT_BOUNDRY      EQU 00000080h   ;// inval command
    HINTOSC_INVAL_BLIT_CLOCKS       EQU 00000100h   ;// inval command

        ;// these four commands add the item to the invalidate rect

    HINTOSC_INVAL_SET_SHAPE         EQU 00000200h   ;// inval command
    HINTOSC_INVAL_BUILD_RENDER      EQU 00000400h   ;// inval command

    HINTOSC_STATE_BOUNDRY_VALID     EQU 00000800h   ;// inval state

    HINTOSC_RENDER_CALL_BASE        EQU 00001000h   ;// render command

        ;// off means call gdi_render_osc directly
        ;// this can only be done if RENDER_MASK is OFF
        ;// and one of the OUT123 bits is ON
        ;// this is set by processing HINTOSC_INVAL_BUILD_RENDER

    HINTOSC_RENDER_MASK             EQU 00002000h   ;// render command

    HINTOSC_RENDER_OUT1             EQU 00004000h   ;// render command
    HINTOSC_STATE_HAS_HOVER         EQU 00008000h   ;// render state
    HINTOSC_STATE_HAS_CON_HOVER     EQU 00010000h   ;// render state
    HINTOSC_STATE_HAS_LOCK_HOVER    EQU 00020000h   ;// render state
    HINTOSC_STATE_HAS_LOCK_SELECT   EQU 00040000h   ;// render state

    HINTOSC_RENDER_OUT2             EQU 00080000h   ;// render command
    HINTOSC_STATE_HAS_SELECT        EQU 00100000h   ;// render state

    HINTOSC_RENDER_OUT3             EQU 00200000h   ;// render command
    HINTOSC_STATE_HAS_GROUP         EQU 00400000h   ;// render state
    HINTOSC_STATE_HAS_BAD           EQU 00800000h   ;// render state

    HINTOSC_RENDER_CLOCKS           EQU 01000000h   ;// render command

    HINTOSC_RENDER_BLIT_RECT        EQU 02000000h   ;// render command

    HINTOSC_STATE_SHOW_PINS         EQU 04000000h   ;// render state

    HINTOSC_INVAL_CREATED           EQU 08000000h   ;// inval_state
    HINTOSC_INVAL_REMOVE            EQU 10000000h   ;// inval command

        ;// these two flags make sure offscreen objects get initialized
        ;// needed when loading a circuit

    ;// needed by several functions as an aleady processed flag

    HINTOSC_STATE_PROCESSED         EQU 20000000h

    ;// sets extents is used by the scroll bars and osc move

    HINTOSC_STATE_SETS_EXTENTS      EQU 40000000h   ;// used by scroll bars

    ;// ONSCREEN is stored in dwHintOsc

    HINTOSC_STATE_ONSCREEN          EQU 80000000h   ;// the sign bit for simple testing


    HINTOSC_RENDER_TEST     EQU     HINTOSC_RENDER_CALL_BASE    OR  \
                                    HINTOSC_RENDER_MASK         OR  \
                                    HINTOSC_RENDER_OUT1         OR  \
                                    HINTOSC_RENDER_OUT2         OR  \
                                    HINTOSC_RENDER_OUT3         OR  \
                                    HINTOSC_RENDER_CLOCKS


comment ~ /*

    moved to gdi_pin.inc

;// HINTPIN flags that tell us how to draw a pin

    HINTPIN_RENDER_ASSY             EQU 00000001h   ;// render command
    HINTPIN_RENDER_OUT1             EQU 00000002h   ;// render command
    HINTPIN_RENDER_CONN             EQU 00000004h   ;// render command
    HINTPIN_RENDER_OUT1_BUS         EQU 00000008h   ;// render command

    HINTPIN_RENDER_TEST     EQU HINTPIN_RENDER_ASSY OR \
                                HINTPIN_RENDER_OUT1 OR \
                                HINTPIN_RENDER_OUT1_BUS OR \
                                HINTPIN_RENDER_CONN

    HINTPIN_STATE_HAS_HOVER         EQU 00000010h   ;// render state
    HINTPIN_STATE_HAS_DOWN          EQU 00000020h   ;// render state
    HINTPIN_STATE_HAS_BUS_HOVER     EQU 00000040h   ;// render state
*/ comment ~

    ;// need this one public so oscs can use it for calc purposes
    HINTPIN_STATE_HIDE              EQU 00000080h   ;// render state

comment ~ /*

        ;// _HIDE is a flag that causes gdi_render_pin
        ;// to draw the connection in COLOR_PIN_BAD
        ;// pin unconnected may shut this off

    HINTPIN_STATE_THICK             EQU 00000100h   ;// render state

        ;// causes gdi_render_pin to draw using thick pin

    HINTPIN_INVAL_LAYOUT_SHAPE      EQU 00001000h   ;// inval command
    HINTPIN_INVAL_LAYOUT_POINTS     EQU 00002000h   ;// inval command

    HINTPIN_STATE_VALID_TSHAPE      EQU 00004000h   ;// inval state
    HINTPIN_STATE_VALID_DEST        EQU 00008000h   ;// inval state

        ;// VALID_TSHAPE means that E,G,t0, and pTShape are valid
        ;// pin_Layout_shape turns this on
        ;// pin_Layout_shape RESETS, VALID_DEST

        ;// VALID_DEST means that t1, t2 and pDest are valid
        ;// pin_Layout_points turns this on
        ;// pin_Layout_points REQUIRES VALID_TSHAPE


    HINTPIN_INVAL_BUILD_JUMP        EQU 00010000h   ;// inval command
    HINTPIN_INVAL_BUILD_RENDER      EQU 00020000h   ;// inval command


    HINTPIN_INVAL_ERASE_CONN        EQU 00100000h   ;// inval command
    HINTPIN_INVAL_ERASE_RECT        EQU 00200000h   ;// inval command
    HINTPIN_INVAL_BLIT_RECT         EQU 00400000h   ;// inval command
    HINTPIN_INVAL_BLIT_CONN         EQU 00800000h   ;// inval command

        ;// these four update the invalidate rect

    HINTPIN_STATE_ONSCREEN          EQU 80000000h   ;// inval state

        ;// the sign bit as always
        ;// always set by pin_Layout_points


*/ comment ~



;///
;///    REDRAW AND INVALIDATION
;///                                    defined in GDI.asm
;///
;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////






comment ~ /*

more_notes:

brief notes about the UI model

    the definition heirarchy goes like this:

    OSC_OBJECT.rect

        always specified in gdi_pBMP coords
        assumed to ALWAYS be valid
        determines: INVAL_ONSCREEN
        operations are skipped if onscreen is false
        INVAL_TEST_ONSCREEN is used to flag the bit as invalid

    OSC_OBJECT.rect.TL then is able to define OSC_OBJECT.pDest

        pDest is needed for gdi_Move, gdi_Fill, gdi_Outline, gdi_Test
        INVAL_SET_PDEST is the flag to set pDest

        as a performance requirement, pDest is not needed if the osc is off screen

    APIN.T0

        is the base for APIN.pDest
        used in combination with APIN.pShape, it tells gdi_Fill and gdi_Test where to work
        changing this value requires that INVAL_SET_PDEST be set

    APIN.dT0

        is the delta between the last calulated T0 and the OSC_OBJECT.rect.TL
        if INVAL_PIN_MOVED + INVAL_OSC_MOVED, then this value can quickly update
            the required items.
        INVAL_PIN_MOVED automatically sets INVAL_SET_PDEST


*/ comment ~







;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;///
;///    BMP_COMPOSITE_TAG   see bmp_composite.cpp for details
;///
;///    these macros simplify the bmp_compostite actions
;///    bmp_composite allows each graphic bitmap to be developed elsewhere, then
;///    assembled into the object_bitmap.
;///
;///    These tags are often generated by GBUILD and used by BMP_COMPOSITE
;///

    BMP_COMPOSITE_TAG   MACRO
    ;// this tells bmp_composite that the next records are composite parameters
                        ENDM

    BCOM_PALETTE_GROUP  MACRO   num:req,    nopal
    ;// palette group is one of the seven designated object groups (1 7)
    ;// it may also be group 0 for objects that build their shape from a blit source
    ;// see OBJECT_COLORS
    ;// an optional NOPAL text item will cause the color reducer to make that object's pallette
    ;// have a population count of 1. Needed for the displays, which have a somewhat continous palette
                        ENDM

    BCOM_SOURCE_FILE    MACRO   name:req
    ;// source file may be a reletive path
                        ENDM

    BCOM_SOURCE_RECT    MACRO   rl:req, rt:req, rr:req, rb:req
    ;// source rect is referenced to the source file's top left
                        ENDM

    BCOM_DEST_TL        MACRO   name:req, X:req, Y:req
    ;// destination in the object bit map
    ;// since it's inverted these coords are reletive to the bottom left
    ;// bmp_composite will flip the image accordingly
    ;//
    ;// name may be used for further declarations and will be the source address
    ;// inside the obj bitmap
    ;//
    ;// the field is required by bmp_composite, use NONAME to skip equate generation

                    IFDIF <name>, <NONAME>
                    %   name EQU oBmp_address( X, Y )
                    ENDIF

                        ENDM


;///
;///    BMP_COMPOSITE_TAG       see bmp_composite.cpp for details
;///
;///
;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////






