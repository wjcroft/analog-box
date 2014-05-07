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
;//
;// bus.inc     shared among three files
;//

comment ~ /*

FIRST OFF

    index and number have two different meanings

    index   a ZERO based index into an array
            converts to a pointer by simple multiplication and add to base

    number  a ONE based index in an array
            convertes to a pointer by subtract 1, then multiply and offset



PIECES

    named busses are somewhat complicated
    the peices we work with in this file are:

    the bus name

        consists of two strings

            a category      shared by several busses
            a member name   not nessesarily unique

    the pin (APIN)

        holds an index in APIN.dwStatus (lower 8 bits)
        this index is one based, so a subtraction is always mandatory

        holds a pBShape pointer
        used to draw and hittest the bus shape by gdi pin_Render functions
        this value is assigned by bus_AssignPin

    the context (LIST_CONTEXT)

        the pin is owned by the osc
        the osc is owned by the context

        the context holds a bus table and bus string pointer
        the bus_table is an indexed array of pointers to bus sources (APIN*)
        the pBusStrings member is a pointer to a block of memory that holds the bus names

        the names for a context are nessesarily current.
        the names held in BUS_EDIT_RECORD are ALWAYS current
        functions in this file will take that into account

    the string table ( BUS_STRING_CATEGORY BUS_STRING_MEMBER )

        is organized to be stored in a file and not take up a lot of room in memory
        the string table is then organized as

            ofs_mem     DWORD   states the size of the category list
                                add this value to pBusString to get to ofs_end

            arrary[] of:    BUS_STRING_CATEGORY

                cat_length  BYTE    size of the following string including the nul terminator
                                    use to get to the next string for searching
                cat_string  BYTE[]  zero terminated string (zero is always stored)


            ofs_end     DWORD   total size of the member table
                                add to the current iterator to get to the EOB value

            array[] of:     BUS_STRING_MEMBER

                bus_number  BYTE    index of the bus that this member name applies to (0 based)
                cat_index   BYTE    index of the category for this member
                mem_length  BYTE    sizeof the following string including the nul terminator
                                    use to get to the next string for searching
                mem_string  BYTE[]  zero terminated string

        using this format allows esi to point at source and edi to point at dest
        i86 string commands can do the rest


        EXAMPLE:

            TABLE

                bus a1 = Default.name_1     <- category index = 0
                bus b2 = Another.name_2     <- category idex = 1

            STORAGE

                category_header:

                    ofs_mem     =   9

                category_string_array:

                [0] cat_size    =   8
                    cat_string  =   'Another',0

                member_header:

                    ofs_end     =   20  <- size of next table

                member_string_array:

                [0] bus_index   =   1   <- bus a1 is index 1
                    cat_index   =   0   <- default category
                    mem_size    =   7
                    mem_string  =   'name_1',0

                [1] bus_index   =   12  <- bus b2 is index 12
                    cat_index   =   1   <- category 1
                    mem_size    =   7
                    mem_string  =   'name_2',0


    edit lists (cat_list and mem_list)

        simple list boxes that own their strings
        categories are stored exclusivly in the cat_list (because there's only one set per context)
        member names are loaded according to the selected category

        the item data of each member list entry is a POINTER to the bus record

    a structure to edit busses in a context (BUS_EDIT_RECORD)

        this struct is only for helping out with the grids and lists used to edit
        busses and pin connections

        there is an array of these records, one per bus

        it contains indexes, id's, list indexes, hit test lists, hit test rectangles, and strings

        bus_LoadContext is used to transfer pBusString to the BUS_EDIT_RECORD
        bus_SaveContext is used to build a new string table for the context
        this action will REPLACE THE pBusStrings POINTER


NOMENCLATURE

    prefixed state the relevance of a value or function

        bus_    generalized bus level functions and values

    dialog level functions and values

        GRID_VIEW

            grid_   routines to control the grid

            trig_   routines to control the trigger commands
                    no longer implemented


        LIST_VIEW

            nav_    routines to control the bus navigator
                    no longer implemented

            list_   routines to manage between two lists

            cat_    rountines that work with e cat list

            mem_    routines that work with the member list

            edit_   routines to manage the edit box used to edit names in the list



*/ comment ~



;////////////////////////////////////////////////////////////////////
;//
;//
;//     BUS_STRING_ templates
;//

        BUS_STRING_CATEGORY STRUCT

            cat_length  db  0   ;// length of the following string
            cat_string  db  0   ;// place holder and minimum string

        BUS_STRING_CATEGORY ENDS

            ;// note: category are always stored in packed order
            ;// meaning that all category strings are to be in adjacent BUS_EDIT_RECORDs
            ;// this is enforfoced right before a bus_edit_table is saved to a bus_context

        BUS_STRING_MEMBER   STRUCT

            bus_index   db  0   ;// bus index this string refers too
            cat_index   db  0   ;// category index this string referes to
            mem_length  db  0   ;// length of the following string
            mem_string  db  0   ;// place holder (also the min string length)

        BUS_STRING_MEMBER   ENDS

;//
;//     BUS_STRING_ templates
;//
;//
;////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////
;//
;//
;//     BUS_EDIT_RECORD
;//
    ;// an array of bus records are allocated and intialized
    ;// there is only one of these that may follow the current context
    ;// some of the fields are fixed at app initialization
    ;// other will depend on the current context and the edit actions

    BUS_EDIT_RECORD STRUCT

    ;// fixed data for any bus

        number      dd  0       ;// 00h (fixed) one bassed index saves some code hassle
        pNameShape  dd  0       ;// 04h (fixed) pointer to assigned font (GDI_SHAPE), only way to get the ascii short name

    ;// values owned by the grid

        slist_Declare_link gridList, BUS_EDIT_RECORD
                                ;// 08h pointer to the next button that qualifies for hit testing

        hit_rect    RECT{}      ;// 0Ch (fixed) rectangle for context menu display, client coords, sorted x, then y for searching

        left_rect   RECT{}      ;// 1Ch how to highlight the left row

        top_rect    RECT{}      ;// 2Ch how to highlight the top column

    ;// values owned by the category and member lists

        cat_pointer dd  0       ;// 3Ch (context) BUS_EDIT_RECORD pointer

    ;// values owned by the bus_editor (context dependant, used by several functions)

        mem_name db 32 dup (0)  ;// 40h (context) member name of this entry

        cat_name db 32 dup (0)  ;// 60h (context) category name (NOT of this entry)

        ;// note: mem_name and cat_name MUST BE THE LAST ITEMS

                                ;// 80h total size in BYTES
    BUS_EDIT_RECORD ENDS

    BUS_EDIT_RECORD_SHIFT equ LOG2(SIZEOF BUS_EDIT_RECORD)  ;// shifts a zero based index to an offset



    ;// bus table
    ;//
    ;//     to manipulate these, we need a struct with some parameters
    ;//     these are allocated in wm_create

    EXTERNDEF bus_pTable:DWORD  ;// allocated ptr to 240 BUS_EDIT_RECORDs plus one more for temp strings
    EXTERNDEF bus_pString:DWORD ;// allocated string holder acts as an xfer between lists and records
                                ;// this is limited to 128 bytes (2 records)
    bus_pEnd TEXTEQU <bus_pString>  ;// pString is also one passed-the-end of pTable
                            ;// so it can also be a reverse iterator

    EXTERNDEF bus_last_context:DWORD;// last viewed context

    EXTERNDEF bus_table_is_dirty:DWORD ;// flag means we need to save the context when exiting
                                    ;// this will over write the the context.pBusStrings pointer


;//
;//
;//     BUS_EDIT_RECORD
;//
;////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////
;//
;//
;//     BUS DIALOG HELPERS
;//

    ;// dialog sizes

    ;// bus_pos POINT {}    ;// temp defined in wm_create, where we display on the screen
    ;// bus_siz POINT {}    ;// defined in wm_create, size of the window

    ;// handles
    ;//
    ;//     bus dialog window data
    ;//     these get defined in InitializeWindows, and by wm_create
    ;//     these are stored to cache them

    EXTERNDEF bus_hWnd:DWORD    ;// hWnd for the context menu
    EXTERNDEF hWnd_bus_status:DWORD ;// handle of the status control
    EXTERNDEF bus_last_status:DWORD ;// pointer to the last display status string
    EXTERNDEF grid_hWnd:DWORD       ;// hWnd for the control
    EXTERNDEF cat_hWnd:DWORD        ;// handle of the category list
    EXTERNDEF mem_hWnd:DWORD        ;// handle of the members list

    EXTERNDEF hWnd_bus_undo:DWORD
    EXTERNDEF hWnd_bus_redo:DWORD

;// EXTERNDEF edit_hWnd:DWORD       ;// handle for the floating edit box

;//     hWnd_grid_status dd 0   ;// handle of the grid status
;//     hWnd_add_cat     dd 0   ;// handle of the add cat button
;//     hWnd_del_cat     dd 0   ;// handle of the del cat button

;//     hWnd_edit       dd  0   ;// handle of the floating editor
;//     edit_OldProc    dd  0   ;// we subclass the editor
;//     cat_OldProc     dd  0   ;// we subclass the cat list
;//     mem_OldProc     dd  0   ;// we subclass the mem list


    ;//
    ;// dialog modes        collection of bits that tell us what's going on
    ;//

    ;// view flags
    ;//
    ;// view and viewing flags are designed to be shifted
    ;// so keep lower eight bits reserved only for them

        DM_VIEW_GRID    equ 00000001h   ;// command to view the grid
        DM_VIEWING_GRID equ 00000002h   ;// status says we are viewing the grid

        DM_VIEW_LIST    equ 00000004h   ;// command to view the list
        DM_VIEWING_LIST equ 00000008h   ;// status that we are viewing the list

        DM_SORT_NAMES   equ 00000100h   ;// off for sort by number

    ;// edit flags

        DM_EDITING_CAT  equ 00001000h   ;// the list editor is on cat
        DM_EDITING_MEM  equ 00002000h   ;// the list editor is on mem
                                        ;// both off for no editor

    ;// list drag drop flags

        DM_DRAG_CAT     equ 00004000h   ;// user is moving a category
        DM_DRAG_MEM     equ 00008000h   ;// user is moving a member

        DM_CAT_DOWN     equ 00010000h   ;// mouse came down on cat
        DM_MEM_DOWN     equ 00020000h   ;// mouse came down on mem

        ;// DM_DOWN_TEST    equ DM_CAT_DOWN OR DM_MEM_DOWN
        ;// DM_DRAG_TEST    equ DM_DRAG_CAT OR DM_DRAG_MEM

        DM_DROP_ON      equ 00040000h   ;// set if the drop highlight rect is on
        DM_CAT_BAD      equ 00080000h   ;// on if drop is not ok
                                        ;// also means that the cursor is set

        DM_CAT_CAPTURE  equ 00100000h   ;// on if the cat_list has the mouse capture

        DM_CAT_DRAG_DROP_TEST   equ DM_DRAG_CAT OR DM_DRAG_MEM OR DM_CAT_DOWN OR DM_MEM_DOWN
        DM_CAT_CLEANUP_TEST     equ DM_CAT_BAD OR DM_CAT_CAPTURE OR DM_DROP_ON

    ;// cature and clip flags

        DM_GRID_CAPTURE equ 00200000h   ;// set if grid window has the mouse capture

    ;// list synchronization flag (set by load_context and bus_wm_activate_proc)

        DM_CAT_INIT     equ 00400000h   ;// on for reset the lists
        DM_GRID_INIT    equ 00800000h   ;// on means that show window will call grid_update

    ;// dlg mode

        EXTERNDEF dlg_mode:DWORD    ;//     dd  DM_VIEWING_GRID ;// collection of flags

    ;// the selected pin

        EXTERNDEF bus_pPin:DWORD    ;// the pin that the user clicked on to lauch this
                                    ;// may change by pressing one the nav buttons

        EXTERNDEF cat_cursel:DWORD  ;// currently selected category

;//
;//
;//     BUS DIALOG HELPERS
;//
;////////////////////////////////////////////////////////////////////




;// function prototypes


    grid_Initialize     PROTO STDCALL   ;// call to initialize and subclass the grid control
    catmem_Initialize   PROTO   ;// call to initialize and subclass the category list
    edit_Initialize     PROTO   ;// call to initialize and subclass the edit control

    grid_Destroy        PROTO   ;// call to destroy and unsubclass the grid control
    catmem_Destroy      PROTO   ;// call to destroy and unsubclass the category list
    edit_Destroy        PROTO   ;// call to destroy and unsubclass the edit control



    bus_LoadContext     PROTO   ;// forward reference
    bus_SaveContext     PROTO   ;// forward reference

    bus_GetNameFromRecord   PROTO

    bus_UpdateUndoRedo  PROTO


    grid_unconnect_proc PROTO
    grid_direct_proc    PROTO
    grid_pull_proc      PROTO

    bus_wm_close_proc   PROTO

    catmem_AddCat PROTO STDCALL pCat:DWORD, pName:DWORD
    catmem_DelCat PROTO STDCALL pCat:DWORD
    catmem_CatCat PROTO STDCALL pCat1:DWORD, pCat2:DWORD
    catmem_MemCat PROTO STDCALL pMem:DWORD, pCat:DWORD
    catmem_SetCatName PROTO STDCALL pCat:DWORD, pName:DWORD
    catmem_SetMemName PROTO STDCALL pMem:DWORD, pName:DWORD

    catmem_Update   PROTO

    catmem_wm_drawitem_proc     PROTO
    catmem_wm_measureitem_proc  PROTO
    catmem_wm_compareitem_proc  PROTO

    catmem_wm_dblclk_proc       PROTO

    catmem_LocateBusPin PROTO

    edit_Launch PROTO




















