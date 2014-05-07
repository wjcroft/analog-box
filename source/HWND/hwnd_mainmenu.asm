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
;// hwnd_mainmenu.asm       custom main menu for abox2
;//                         see mainmenu project for developement
;//
;//         includes:   wm_create for main window
;//                     mru verification
;//                     mainwnd_wm_command handler
;// TOC
;//
;// mainmenu_wm_create_proc             create the menu
;//
;// mainmenu_wm_drawitem_proc
;// mainmenu_wm_measureitem_proc
;//
;// mainmenu_wm_command_proc
;//
;// mainmenu_wm_initmenupopup_proc
;// mainmenu_wm_setcursor_proc      shows help text or does nothing
;// mainmenu_wm_menuselect_proc     shows popup item info
;//
;// mainmenu_wm_entermenuloop_proc
;// mainmenu_wm_exitmenuloop_proc
;//
;// mainmenu_SyncPlayButton
;// mainmenu_SyncOptionButtons
;// mainmenu_SyncSaveButtons




OPTION CASEMAP:NONE
.586
.MODEL FLAT

    .NOLIST
    INCLUDE <abox.inc>
    INCLUDE <groups.inc>
    INCLUDE <gdi_pin.inc>
    .LIST
    ;//.LISTALL

;////////////////////////////////////////////////////////////////////
;//
;//                 these define the structs we use
;//     main menu   command id's are first defined in abox_objects.h
;//

    ;// MXT items are the wrapper we use to create our custom menu

        MXT_ITEM STRUCT

            dwID    dd  0   ;// desired control id
            pText   dd  0   ;// ptr to menu text to display (double terminated)
            pHelp   dd  0   ;// ptr to menu help
            dwFlags dd  0   ;// flags, see below
            wid     dd  0   ;// specified or calculated width (leave 0 to calculate at initialize)
            pPath   dd  0   ;// ptr to a string containing the full path
            pad_2   dd  0
            pad_3   dd  0

        MXT_ITEM ENDS       ;// size = 8 dwords

        MXT_SIZE_DEV_TEST EQU LOG2(SIZEOF MXT_ITEM) ;// must be a power of two

    ;// dwFlag values

        ;// alignment   all off means LEFT TOP

        MXT_CENTER      EQU DT_CENTER   ;// = 1
        MXT_VCENTER     EQU DT_VCENTER  ;// = 4

        MXT_DT_TEST     EQU MXT_CENTER OR MXT_VCENTER

        ;// font selection  off for system font

        MXT_SMALL       EQU 00000010h   ;// use the small font (also means multi line)
        MXT_MEDIUM      EQU 00000020h   ;// use the medium font

        ;// seperaters

        MXT_HORZ_SEP    EQU 00000100h   ;// horizontal seperator for sub menus
        MXT_VERT_SEP    EQU 00000200h   ;// vertical seperator for main menus

        ;// menu heirarchy

        MXT_POPUP_BEGIN EQU 00001000h   ;// this item is a popup parent
        MXT_POPUP_END   EQU 00002000h   ;// done with this popup
        MXT_MENU_END    EQU 00004000h   ;// last item in menu

        ;// toggle button and state

        MXT_TOGGLE      EQU 00010000h   ;// this is a toggle button
        MXT_PUSHED      EQU 00020000h   ;// button is pushed

        ;// string expansion

        MXT_PATH        EQU 00100000h   ;// pPath is a valid filename
                                        ;// tells drawitem to format the results as a path name
                                        ;// tells showhelp to append the path
        MXT_PATH_EX     EQU 00200000h   ;// pPath is a pointer to a filename pointer
                                        ;// tells show help how to append the path
        MXT_LEFT_RIGHT  EQU 01000000h   ;// the two items are to be drawn left and right aligned

    ;// geometry values

        MXT_SMALL_ADJUST    EQU 3   ;// adjust small fonts by this much for the multi line
        MXT_WIDTH_ADJUST    EQU 10  ;// reduce width by this much
        MXT_HEIGHT          EQU 16  ;// standard height to return

        MXT_WIDTH           EQU 176 ;// max width of menu

;/////////////////////////////////////////////////////////////////////////


.DATA

    mainmenu_table LABEL MXT_ITEM

            MXT_ITEM { COMMAND_FILE,        sz_text_file    ,sz_help_file,  MXT_MEDIUM OR MXT_CENTER OR MXT_VCENTER OR MXT_POPUP_BEGIN  }

            MXT_ITEM { COMMAND_NEW,         sz_text_new     ,sz_help_new,   MXT_MEDIUM OR MXT_VCENTER OR MXT_LEFT_RIGHT, MXT_WIDTH  }
            MXT_ITEM { COMMAND_OPEN,        sz_text_open    ,sz_help_open,  MXT_MEDIUM OR MXT_VCENTER OR MXT_LEFT_RIGHT, MXT_WIDTH  }
            MXT_ITEM { COMMAND_SAVE,        sz_text_save    ,sz_help_save,  MXT_MEDIUM OR MXT_VCENTER OR MXT_LEFT_RIGHT OR MXT_PATH_EX, MXT_WIDTH, OFFSET filename_circuit_path }
            MXT_ITEM { COMMAND_SAVEAS,      sz_text_saveas  ,sz_help_saveas,MXT_MEDIUM OR MXT_VCENTER OR MXT_LEFT_RIGHT OR MXT_PATH_EX, MXT_WIDTH, OFFSET filename_circuit_path }
            MXT_ITEM { COMMAND_SAVEBMP,     sz_text_savebmp ,sz_help_savebmp,MXT_MEDIUM OR MXT_VCENTER OR MXT_LEFT_RIGHT, MXT_WIDTH }
            MXT_ITEM { ,,,MXT_HORZ_SEP   }
menu_mru1   MXT_ITEM { COMMAND_MRU1,        sz_text_mru1    ,sz_help_mru,   MXT_MEDIUM OR MXT_VCENTER OR MXT_PATH   ,MXT_WIDTH }
menu_mru2   MXT_ITEM { COMMAND_MRU2,        sz_text_mru2    ,sz_help_mru,   MXT_MEDIUM OR MXT_VCENTER OR MXT_PATH   ,MXT_WIDTH }
menu_mru3   MXT_ITEM { COMMAND_MRU3,        sz_text_mru3    ,sz_help_mru,   MXT_MEDIUM OR MXT_VCENTER OR MXT_PATH   ,MXT_WIDTH }
menu_mru4   MXT_ITEM { COMMAND_MRU4,        sz_text_mru4    ,sz_help_mru,   MXT_MEDIUM OR MXT_VCENTER OR MXT_PATH   ,MXT_WIDTH }
            MXT_ITEM { ,,,MXT_HORZ_SEP   }
            MXT_ITEM { COMMAND_UNINSTAL,    sz_text_uninstal,sz_help_uninstal,MXT_MEDIUM OR MXT_VCENTER, MXT_WIDTH  }
            MXT_ITEM { COMMAND_EXIT,        sz_text_exit    ,sz_help_exit,  MXT_MEDIUM OR MXT_VCENTER OR MXT_POPUP_END OR MXT_LEFT_RIGHT, MXT_WIDTH }

NUMITEMS_SANS_MRU   EQU 9   ;// number of items - mru list
POSITION_MRU1       EQU 7   ;// position of the first mru entry
POSITION_MRU4       EQU POSITION_MRU1 + 3

            MXT_ITEM { ,sz_text_vert,,MXT_VERT_SEP }
menu_play   MXT_ITEM { COMMAND_PLAY,        sz_text_play    ,sz_help_play,  MXT_SMALL OR MXT_TOGGLE OR MXT_VCENTER OR MXT_CENTER, 24 }
            MXT_ITEM { ,sz_text_vert,,MXT_VERT_SEP }
menu_status MXT_ITEM { COMMAND_STATUS,      sz_text_status  ,sz_help_status,MXT_SMALL OR MXT_TOGGLE OR MXT_VCENTER OR MXT_CENTER, 24 }
menu_clocks MXT_ITEM { COMMAND_CLOCKS,      sz_text_clocks  ,sz_help_clocks,MXT_SMALL OR MXT_TOGGLE OR MXT_VCENTER OR MXT_CENTER, 24 }
menu_change MXT_ITEM { COMMAND_CHANGING,    sz_text_change  ,sz_help_change,MXT_SMALL OR MXT_TOGGLE OR MXT_VCENTER OR MXT_CENTER, 24 }
menu_update MXT_ITEM { COMMAND_UPDATE,      sz_text_update  ,sz_help_update,MXT_SMALL OR MXT_CENTER OR MXT_VCENTER, 20 }
            MXT_ITEM { ,sz_text_vert,,MXT_VERT_SEP }
menu_nomove MXT_ITEM { COMMAND_NOMOVE,      sz_text_move    ,sz_help_move,  MXT_SMALL OR MXT_TOGGLE OR MXT_VCENTER OR MXT_CENTER, 20 }
menu_noask  MXT_ITEM { COMMAND_NOASKSAVE,   sz_text_ask     ,sz_help_ask,   MXT_SMALL OR MXT_TOGGLE OR MXT_VCENTER OR MXT_CENTER, 20 }
menu_noedit MXT_ITEM { COMMAND_NOEDIT,      sz_text_edit    ,sz_help_edit,  MXT_SMALL OR MXT_TOGGLE OR MXT_VCENTER OR MXT_CENTER, 20 }
menu_nopins MXT_ITEM { COMMAND_NOPINS,      sz_text_nopins  ,sz_help_nopins,MXT_SMALL OR MXT_TOGGLE OR MXT_VCENTER OR MXT_CENTER, 20 }
menu_auto   MXT_ITEM { COMMAND_AUTOPLAY,    sz_text_auto    ,sz_help_auto,  MXT_SMALL OR MXT_TOGGLE OR MXT_VCENTER OR MXT_CENTER, 20 }
            MXT_ITEM { ,sz_text_vert,,MXT_VERT_SEP }
            MXT_ITEM { COMMAND_COLORS,      sz_text_color   ,sz_help_color, MXT_MEDIUM OR MXT_CENTER OR MXT_VCENTER,30 }
            MXT_ITEM { COMMAND_ABOUT,       sz_text_about   ,sz_help_about, MXT_MEDIUM OR MXT_CENTER OR MXT_VCENTER,30 }
            MXT_ITEM { ,sz_text_vert,,MXT_VERT_SEP }
            MXT_ITEM { ,sz_text_vert,,MXT_VERT_SEP }
menu_undo   MXT_ITEM { COMMAND_UNDO_MENU,   sz_text_undo    ,sz_help_undo,  MXT_MEDIUM OR MXT_CENTER OR MXT_VCENTER, 30 }
menu_redo   MXT_ITEM { COMMAND_REDO_MENU,   sz_text_redo    ,sz_help_redo,  MXT_MEDIUM OR MXT_CENTER OR MXT_VCENTER OR MXT_MENU_END }


    menu_hilite_kludge  dd  0   ;// cmd id of an item we want to force a hilite
                                ;// turned on by mainmenu_wm_initpopupmenu_proc
                                ;// stays on until processed by mainmenu_wm_drawitem_proc

    hMainMenu   dd  0           ;// handle to the menu

    mainmenu_mode   dd  0   ;// flags for keeping track of stuff

    ;// values are defined in abox.inc
    ;//
    ;// MAINMENU_NOSAVE         EQU 00000010h   ;// save should be disabled
    ;// MAINMENU_NOSAVE_STATE   EQU 00000020h   ;// save IS disabled
    ;// MAINMENU_NOSAVEAS       EQU 00000040h   ;// saveas should be disabled
    ;// MAINMENU_NOSAVEAS_STATE EQU 00000080h   ;// saveas IS disabled
    ;//
    ;// MAINMENU_REDRAW         EQU 00000100h   ;// redraw
    ;//
    ;// MAINMENU_UNTITLED       EQU 00000001h   ;// re/set elsewhere
    ;// MAINMENU_ABOX1          EQU 00000002h   ;// re/set elsewhere

    ;// MAINMENU_NOSAVEBMP      EQU 00001000h
    ;// MAINMENU_NOSAVEBMP_STATE EQU 0002000h

        MAX_MXT_TEXT_LENGTH EQU 20


    ;// help string synchronization

    mainmenu_help_string    dd  0   ;// ptr to a FILENAME that serves as our help string
    EXTERNDEF mainmenu_last_hItem:DWORD ;// used in hwnd_main.asm
    mainmenu_last_hItem     dd  0   ;// last hMenu+item
    mainmenu_last_unredo    dd  0   ;// last recieved UNREDO_NODE pointer

    mainmenu_hUndo          dd  0   ;// hItem of undo button, set by wm_create
    mainmenu_hRedo          dd  0   ;// hItem of redo button, set by wm_create

    comment ~ /*

    NOTE

        hItem is hMenu<<16 + item
        this can serve as a unique id for all the menu items

    */ comment ~










;// main menu strings

sz_text_vert    db  '|',0,0

sz_text_file    db  '&File',0,0
sz_text_new     db  CSTR('&New\0Ctrl+N'),0
sz_text_open    db  CSTR('&Open\0Ctrl+O'),0
sz_text_save    db  CSTR('&Save\0Ctrl+S'),0
sz_text_saveas  db  CSTR('Save &As\0Ctrl+A'),0
sz_text_savebmp db  CSTR('Save B&MP\0Ctrl+M'),0
sz_text_mru1    db  '&1 ',0,0
sz_text_mru2    db  '&2 ',0,0
sz_text_mru3    db  '&3 ',0,0
sz_text_mru4    db  '&4 ',0,0
sz_text_uninstal db CSTR('Uninstall'),0
sz_text_exit    db  CSTR('E&xit\0Alt+X'),0
sz_text_play    db  'Play',0,0
sz_text_status  db  CSTR('Status'),0
sz_text_clocks  db  CSTR('Clocks'),0
sz_text_change  db  CSTR('Change'),0
;//sz_text_update   db  CSTR('Update\01234'),0  ;// need 4 chars plus the double terminator
;// UPDATE_INDICATER EQU 7                  ;// position of indicator
sz_text_update  db  '1234',0,0
    UPDATE_INDICATER EQU 0                  ;// position of indicator
sz_text_move    db  CSTR('~Move'),0
sz_text_ask     db  CSTR('~Ask'),0
sz_text_edit    db  CSTR('~Edit'),0
sz_text_nopins  db  CSTR('~Pins'),0
sz_text_auto    db  CSTR('Auto'),0
;//sz_text_color    db  CSTR('&Color\0Setup'),0
sz_text_color   db  '&Color',0,0
sz_text_about   db  '&About',0,0

sz_help_undo    db  'Nothing to '   ;// unterminated to help the  help string handler
sz_text_undo    db  'Undo',0,0      ;// these also double as sz_help_text
sz_help_redo    db  'Nothing to '   ;// unterminated to help the  help string handler
sz_text_redo    db  'Redo',0,0      ;// and as the nothing to do setting

sz_help_file    db  'Look at the File menu',0
sz_help_new     db  'Clear the entire circuit',0
sz_help_open    db  'Open a circuit',0
sz_help_save    db  'Save ',0
sz_help_saveas  db  'Choose a new name for ',0
sz_help_savebmp db  'Save circuit as a bitmap ',0
sz_help_mru     db  'Open Circuit ',0
sz_help_uninstal db 'Remove ABox from the registry',0
sz_help_exit    db  'Exit the program',0
sz_help_play    db  'Start or stop the circuit (Space Bar)',0
sz_help_status  db  'Display this status bar.',0
sz_help_clocks  db  'Display clocks per sample.',0
sz_help_change  db  'Highlight changing signals.',0
sz_help_update  db  'Adjust the graphics update rate',0
sz_help_move    db  'Disable the moving of objects',0
sz_help_ask     db  'Do not ask to save this circuit.',0
sz_help_edit    db  'Do not edit this circuit',0
sz_help_nopins  db  'Do not display pins or connections',0
sz_help_auto    db  'Automatically play this circuit.',0
sz_help_color   db  'Summon the color settings panel',0
sz_help_about   db  'About Analog Box',0

sz_uninstal_caption db  'Uninstall Analog Box',0

sz_uninstal_text    db  'This will remove Analog Box from the system registry.', 0Ah
                    db  'No files will be erased, but you will loose your color', 0Ah
                    db  'settings, file associations and plugin list.',0
    ALIGN 4

.CODE


PROLOGUE_OFF
ASSUME_AND_ALIGN
mainmenu_wm_create_proc PROC STDCALL uses edi esi ebx hWnd:DWORD, msg:DWORD, wParam:DWORD, lParam:DWORD

    ;// tasks:
    ;//
    ;//     build the menus
    ;//     determine the size of every item without a size

    ;// a somewhat odd entrance, we want ebp to equal esp AFTER the locals are assigned
    ;// STDCALL will set ebp to esp BEFORE locals are assigned

    ;// LOCAL rect:RECT
    ;// LOCAL menu_info:MENUITEMINFO
    ;// LOCAL hDC:DWORD
    ;// LOCAL hFont_sys:DWORD   ;// system font for menus
    ;// LOCAL hFont_prev:DWORD  ;// font we need to replace with
    ;// LOCAL hFont_last:DWORD  ;// last font we selected

        push edi
        push esi
        push ebx
        push ebp

        stack_size = (SIZEOF RECT) + (SIZEOF MENUITEMINFO) + (SIZEOF DWORD)*4

        sub esp, stack_size
        mov ebp, esp

        bp_rect         TEXTEQU <(RECT PTR [ebp+10h+SIZEOF MENUITEMINFO])>
        bp_menu_info    TEXTEQU <(MENUITEMINFO PTR [ebp+10h])>
        bp_hDC          TEXTEQU <(DWORD PTR [ebp+0Ch])>
        bp_hFont_sys    TEXTEQU <(DWORD PTR [ebp+8])>   ;// system font for menus
        bp_hFont_prev   TEXTEQU <(DWORD PTR [ebp+4])>   ;// font we need to replace with
        bp_hFont_last   TEXTEQU <(DWORD PTR [ebp+0])>   ;// last font we selected

        bp_hWnd         TEXTEQU <(DWORD PTR [ebp+stack_size+5*4])>

    ;// save our handle

        mov eax, bp_hWnd
        mov hMainWnd, eax

    ;// grab this for the mouse

        invoke GetSystemMetrics, SM_CXDRAG
        .IF eax >= 2
            mov mouse_move_limit, eax
        .ENDIF

    ;// setup our dc

        invoke GetDC, hMainWnd
        mov ebx, eax
        invoke SelectObject, ebx, hFont_osc
        mov eax, oBmp_palette[COLOR_DESK_BACK*4]
        BGR_TO_RGB eax
        invoke SetBkColor, ebx, eax
        mov eax, oBmp_palette[COLOR_DESK_TEXT*4]
        BGR_TO_RGB eax
        invoke SetTextColor, ebx, eax
        invoke SetBkMode, ebx, TRANSPARENT
        invoke ReleaseDC, hMainWnd, ebx

    ;// initialize the menu item info

        lea edi, bp_menu_info
        mov ecx, (SIZEOF MENUITEMINFO) / 4
        xor eax, eax
        rep stosd

        mov bp_menu_info.fType, MF_OWNERDRAW OR MF_STRING           ;//3    fType   dd 0    MFT_OWNERDRAW
        mov bp_menu_info.fMask, MIIM_TYPE OR MIIM_DATA OR MIIM_ID   ;//2    fMask   dd 0    MIIM_TYPE MIIM_DATA
        mov bp_menu_info.cbSize, SIZEOF MENUITEMINFO                ;//1    cbSize  dd SIZEOF MENUITEMINFO

    ;// get a dc to work with, and store the previous font

        invoke GetWindowDC, bp_hWnd
        mov bp_hDC, eax

        invoke GetStockObject, SYSTEM_FONT
        mov bp_hFont_sys, eax

        invoke SelectObject, bp_hDC, eax
        mov bp_hFont_prev, eax
        mov bp_hFont_last, 0

    ;// create the menu

        invoke CreateMenu
        mov hMainMenu, eax  ;// store the handle

    ;// scan the table and fill in the values

        lea esi, mainmenu_table
        ASSUME esi:PTR MXT_ITEM

        push hMainMenu  ;// always set this as the top
        pushd 0         ;// position counter

        jmp @F

        .REPEAT

        ;// iterate

            add esi, SIZEOF MXT_ITEM
        @@:

        ;// check for popup part 1, create the menu

            .IF [esi].dwFlags & MXT_POPUP_BEGIN ;// popup starter ?

                invoke CreateMenu               ;// create the sub menu
                mov bp_menu_info.hSubMenu, eax  ;// store the new sub menu
                mov bp_menu_info.fMask, MIIM_SUBMENU OR MIIM_TYPE OR MIIM_DATA OR MIIM_ID   ;// set that we are a sub menu

            .ENDIF

        ;// build the item

            .IF [esi].dwFlags & MXT_HORZ_SEP        ;// we are a horizontal separator

            ;// set up the separator value in menu_info

                mov bp_menu_info.fType, MF_SEPARATOR
                mov bp_menu_info.fMask, MIIM_TYPE

            ;// add the item and iterate the count

                mov ebx, [esp]      ;// get the position
                mov ecx, [esp+4]    ;// get the menu handle

                invoke InsertMenuItemA, ecx, ebx, MF_BYPOSITION, ADDR bp_menu_info

                inc DWORD PTR [esp] ;// add the position

            ;// reset the separator value in menu_info

                mov bp_menu_info.fType, MF_OWNERDRAW OR MF_STRING
                mov bp_menu_info.fMask, MIIM_TYPE OR MIIM_DATA OR MIIM_ID

            .ELSE       ;// we are a normal item

            ;// to get the hot keys correct, we have to insert in two steps
            ;// the first step inserts as a normal item, letting window do the hot key
            ;// the second step changes to owner draw, letting us do the drawing

                mov bp_menu_info.fType, MF_STRING

                mov bp_menu_info.dwItemData, esi    ;// set the pointer to the initializer

                mov eax, [esi].pText                ;// load the text address
                mov bp_menu_info.dwTypeData, eax    ;// save in type data

                mov ebx, [esp]      ;// get the position
                mov ecx, [esp+4]    ;// get the menu handle

                ;// take care of menu_undo and redo

                .IF esi == OFFSET menu_undo
                    shrd mainmenu_hUndo, ecx, 16
                    add mainmenu_hUndo, ebx
                .ELSEIF esi == OFFSET menu_redo
                    shrd mainmenu_hRedo, ecx, 16
                    add mainmenu_hRedo, ebx
                .ENDIF

                mov eax, [esi].dwID     ;// get the id from MXT
                mov bp_menu_info.dwID, eax  ;// save id in our struct

                invoke InsertMenuItemA, ecx, ebx, MF_BYPOSITION, ADDR bp_menu_info

                mov bp_menu_info.fType, MF_OWNERDRAW OR MF_STRING
                mov ecx, [esp+4]    ;// get the menu handle
                invoke SetMenuItemInfoA, ecx, ebx, MF_BYPOSITION, ADDR bp_menu_info

                inc DWORD PTR [esp] ;// increase the position counter

                ;// determine the size
                .IF ![esi].wid
                    call determine_the_size
                .ENDIF

            .ENDIF

        ;// popup part 2

            .IF [esi].dwFlags & MXT_POPUP_BEGIN

                xor eax, eax
                push bp_menu_info.hSubMenu      ;// store the new hMenu we're workin with
                mov bp_menu_info.hSubMenu, eax  ;// clear it
                push eax                        ;// start a new position index

                ;// mov bp_menu_info.fType, MF_OWNERDRAW
                mov bp_menu_info.fMask, MIIM_TYPE OR MIIM_DATA OR MIIM_ID

            .ENDIF

        ;// popup end

            .IF [esi].dwFlags & MXT_POPUP_END

                add esp, 8  ;// erase the old iterator

            .ENDIF

        .UNTIL [esi].dwFlags & MXT_MENU_END

        add esp, 8  ;// clear out the stack

        DEBUG_IF <esp!!=ebp>    ;// lost track of something

    ;// reset the dc

        invoke SelectObject, bp_hDC, bp_hFont_prev
        invoke ReleaseDC, bp_hWnd, bp_hDC

    ;// make sure clocks is disabled

        .IF !(app_CPUFeatures & 10h)

            invoke EnableMenuItem, hMainMenu, COMMAND_CLOCKS, MF_BYCOMMAND OR MF_GRAYED

        .ENDIF

    ;// attach the menu

        invoke SetMenu, bp_hWnd, hMainMenu

    ;// that should be it

        add esp, stack_size
        pop ebp
        pop ebx
        pop esi
        pop edi

    ;// exit to def window proc

        jmp DefWindowProcA




;// local function

ALIGN 16
determine_the_size:

    mov edi, [esi].pText    ;// get the text pointer
    ASSUME edi:PTR BYTE     ;// assume as a byte

    ;// set the font correctly

        mov ecx, [esi].dwFlags
        and ecx, MXT_SMALL OR MXT_MEDIUM
        .IF ZERO?
            mov edx, bp_hFont_sys
        .ELSEIF ecx & MXT_SMALL
            mov edx, hFont_pin
        .ELSE
            mov edx, hFont_popup
        .ENDIF

        .IF bp_hFont_last != ecx
            mov bp_hFont_last, ecx
            invoke SelectObject, bp_hDC, edx
        .ENDIF

    ;// scan the string

        .REPEAT

        ;// clear the rect

            xor eax, eax
            xor edx, edx

            point_SetTL bp_rect
            point_SetBR bp_rect

        ;// determine address of next string and length of current string

            mov edx, edi                    ;// xfer string pointer to edx

            mov ecx, MAX_MXT_TEXT_LENGTH    ;// max scan length
            xor eax, eax                    ;// value to test for
            repne scasb                     ;// scan while not equal
            ;// assume this worked
            not ecx                         ;// make negative (1 based)
            add ecx, MAX_MXT_TEXT_LENGTH    ;// add max length to get the text length

        ;// calculate the text length

            invoke DrawTextA, bp_hDC, edx, ecx, ADDR bp_rect, DT_CALCRECT

        ;// determine the width a see if it's bigger

            mov eax, bp_rect.right
            sub eax, bp_rect.left
            .IF eax > [esi].wid
                mov [esi].wid, eax
            .ENDIF

        .UNTIL ![edi]

    ;// subtract by fixup amount

        sub [esi].wid, MXT_WIDTH_ADJUST
        ja @F
        mov [esi].wid, 1
        @@:

    ;// that's it

        retn


mainmenu_wm_create_proc     ENDP
PROLOGUE_ON



;// WM_DRAWITEM
;// idCtl = (UINT) wParam;             // control identifier
;// lpdis = (LPDRAWITEMSTRUCT) lParam; // item-drawing information
;//
;// DRAWITEMSTRUCT STRUCT
;//     dwCtlType       dd  0
;//     dwCtlID         dd  0
;//     dwItemID        dd  0
;//     dwItemAction    dd  0
;//     dwItemState     dd  0
;//     hWndItem        dd  0
;//     hDC             dd  0
;//     rcItem          RECT {}
;//     dwItemData      dd  0
;// DRAWITEMSTRUCT  ENDS

ASSUME_AND_ALIGN
mainmenu_wm_drawitem_proc   PROC

    push ebx
    push esi
    push edi

    ;// stack
    ;// edi esi ebx ret hWnd    msg     wParam  lParam
    ;// 00  04  08  0C  10      14      18      1C

        mov ebx, [esp+1Ch]
        ASSUME ebx:PTR DRAWITEMSTRUCT

        mov esi, [ebx].dwItemData
        ASSUME esi:PTR MXT_ITEM

    ;// take care of the focus
    ;// do this here because we're using custom seperators

        .IF [ebx].dwItemAction & ODA_SELECT OR ODA_DRAWENTIRE

            .IF [ebx].dwItemState & ODS_SELECTED
            menu_hilite_kludge_jump:
                pushd COLOR_HIGHLIGHT + 1
            .ELSE
                pushd COLOR_BTNFACE+1   ;// COLOR_MENU + 1
            .ENDIF

            lea ecx, [ebx].rcItem
            mov edx, [ebx].hDC
            push ecx
            push edx
            call FillRect

        .ELSEIF menu_hilite_kludge

            mov eax, [esi].dwID
            .IF eax == menu_hilite_kludge

                mov menu_hilite_kludge, 0
                jmp menu_hilite_kludge_jump

            .ENDIF

        .ENDIF

    ;// skip alot of work if this is a vert seperator

    .IF [esi].dwFlags & MXT_VERT_SEP

        ;// compute the location of the vertical bar

            mov eax, [ebx].rcItem.right
            mov edx, [ebx].rcItem.bottom
            add eax, [ebx].rcItem.left
            dec edx
            shr eax, 1
            push edx    ;// bottom
            inc eax
            mov edx, [ebx].rcItem.top
            push eax    ;// right
            inc edx
            sub eax, 2
            push edx
            push eax

            mov edx, esp

        ;// draw the edge

            invoke DrawEdge, [ebx].hDC, edx, EDGE_ETCHED, BF_LEFT

            add esp, SIZEOF RECT

    .ELSE   ;// NORMAL MENU TEXT


        ;// take care of the buttons

            .IF [esi].dwFlags & MXT_TOGGLE

                pushd BF_RECT
                lea eax, [ebx].rcItem
                .IF ([esi].dwFlags & MXT_PUSHED)
                    pushd EDGE_SUNKEN
                .ELSEIF  [ebx].dwItemState & ODS_SELECTED
                    pushd EDGE_BUMP
                .ELSE
                    pushd EDGE_RAISED
                .ENDIF
                push eax
                push [ebx].hDC
                call DrawEdge

            .ENDIF

        ;// select the correct font

            invoke SetBkMode, [ebx].hDC, TRANSPARENT

            xor eax, eax

            .IF [esi].dwFlags & MXT_SMALL

                invoke SelectObject, [ebx].hDC, hFont_pin

            .ELSEIF [esi].dwFlags & MXT_MEDIUM

                invoke SelectObject, [ebx].hDC, hFont_popup

            .ENDIF

            push eax

        ;// set the proper color

            .IF [ebx].dwItemState & ODS_GRAYED

                invoke GetSysColor, COLOR_GRAYTEXT
                invoke SetTextColor, [ebx].hDC, eax

            .ENDIF

        ;// adjust the rect for a pleasing margin

            .IF !([esi].dwFlags & MXT_CENTER)

                add [ebx].rcItem.left, 4

            .ENDIF

        ;// DRAW THE TEXT

            .IF [esi].dwFlags & MXT_PATH

                ;// MXT_PATH items get special treatment

            ;// 1) build the full path string on the stack
            ;// 2) use draw text with the path ellipse option


            ;// 1) build the full path string on the stack

                DEBUG_IF <!!([esi].pPath)>  ;// initmeunitem should have set this

                sub esp, 280        ;// make room for the string
                mov edi, esp        ;// edi stores strings
                push esi            ;// save the MXT_ITEM pointer

                mov esi, [esi].pText    ;// point at the mxt text

                STRCPY_SD NOTERMINATE,LEN,edx   ;// copy the mxt text (&1 )

                mov esi, [esp]          ;// get the mxt pointer
                mov esi, [esi].pPath    ;// get the path pointer

                STRCPY_SD TERMINATE,ADD,edx ;// append and terminate

                pop esi             ;// retrieve the MXT_ITEM pointer

            ;// 2) draw the text

                lea ecx, [ebx].rcItem   ;// point at rect
                dec edx                 ;// decrease the count
                mov edi, esp            ;// point at string
                invoke DrawTextA, [ebx].hDC, edi, edx, ecx,
                    DT_SINGLELINE OR DT_NOCLIP OR DT_VCENTER OR DT_PATH_ELLIPSIS

            ;// 3) clean up

                add esp, 280


            .ELSEIF [esi].dwFlags & MXT_LEFT_RIGHT

                ;// do the left right option

                mov edi, [esi].pText
                ASSUME edi:PTR BYTE

            ;// LEFT

                mov edx, edi    ;// xfer text pointer to edx

                mov ecx, MAX_MXT_TEXT_LENGTH    ;// max scan length
                xor eax, eax                    ;// value to test for
                repne scasb                     ;// scan while not equal
                ;// assume this worked
                not ecx                         ;// make negative (1 based)
                add ecx, MAX_MXT_TEXT_LENGTH    ;// add max length to get the text length

                ;// determine the flags from mxt
                mov eax, [esi].dwFlags
                and eax, MXT_DT_TEST
                or eax, DT_SINGLELINE OR DT_NOCLIP
                ;// push the rest
                push eax
                lea eax, [ebx].rcItem   ;// point at display rect
                push eax
                push ecx
                push edx
                push [ebx].hDC
                call DrawTextA

            ;// RIGHT

                ;// adjust the item rect

                sub [ebx].rcItem.right, 4

                mov edx, edi    ;// xfer text pointer to edx

                mov ecx, MAX_MXT_TEXT_LENGTH    ;// max scan length
                xor eax, eax                    ;// value to test for
                repne scasb                     ;// scan while not equal
                ;// assume this worked
                not ecx                         ;// make negative (1 based)
                add ecx, MAX_MXT_TEXT_LENGTH    ;// add max length to get the text length

                ;// determine the flags from mxt
                mov eax, [esi].dwFlags
                and eax, MXT_DT_TEST
                or eax, DT_SINGLELINE OR DT_NOCLIP OR DT_RIGHT
                ;// push the rest
                push eax
                lea eax, [ebx].rcItem   ;// point at display rect
                push eax
                push ecx
                push edx
                push [ebx].hDC
                call DrawTextA

            .ELSE   ;// draw the text until there is no more

                mov edi, [esi].pText
                ASSUME edi:PTR BYTE

                .REPEAT

                    mov edx, edi    ;// xfer text pointer to edx

                    mov ecx, MAX_MXT_TEXT_LENGTH    ;// max scan length
                    xor eax, eax                    ;// value to test for
                    repne scasb                     ;// scan while not equal
                    ;// assume this worked
                    not ecx                         ;// make negative (1 based)
                    add ecx, MAX_MXT_TEXT_LENGTH    ;// add max length to get the text length

                    ;// determine the flags from mxt
                    mov eax, [esi].dwFlags
                    and eax, MXT_DT_TEST
                    or eax, DT_SINGLELINE OR DT_NOCLIP
                    ;// push the rest
                    push eax
                    lea eax, [ebx].rcItem   ;// point at display rect
                    push eax
                    push ecx
                    push edx
                    push [ebx].hDC
                    call DrawTextA

                    ;// adjust the item rect

                    sub eax, MXT_SMALL_ADJUST   ;// subtract by font adjust
                    add [ebx].rcItem.top, eax   ;// add to rect top

                .UNTIL ![edi]

            .ENDIF

        ;// reset the dc font

            xor ecx, ecx
            or ecx, [esp] ;// retrieve previous font
            .IF !ZERO?
                push [ebx].hDC
                call SelectObject
            .ELSE
                pop ecx
            .ENDIF

    .ENDIF  ;// MXT_VERT_SEP

    pop edi
    pop esi
    pop ebx

    or eax, 1
    ret 10h

mainmenu_wm_drawitem_proc   ENDP











;// WM_MEASUREITEM
;// idCtl = (UINT) wParam;                // control identifier
;// lpmis = (LPMEASUREITEMSTRUCT) lParam; // item-size information
;//
;// MEASUREITEMSTRUCT   STRUCT
;//     CtlType     dd  0   ;// type of control
;//     CtlID       dd  0   ;// combo box, list box, or button identifier
;//     itemID      dd  0   ;// menu item, variable-height list box, or combo box identifier
;//     itemWidth   dd  0   ;// width of menu item, in pixels
;//     itemHeight  dd  0   ;// height of single item in list box menu, in pixels
;//     itemData    dd  0   ;// application-defined 32-bit value
;// MEASUREITEMSTRUCT   ENDS

ASSUME_AND_ALIGN
mainmenu_wm_measureitem_proc    PROC

    mov ecx, WP_LPARAM
    ASSUME ecx:PTR MEASUREITEMSTRUCT

    mov edx, [ecx].itemData
    ASSUME edx:PTR MXT_ITEM

    mov eax, [edx].wid
    mov [ecx].itemHeight, MXT_HEIGHT
    mov [ecx].itemWidth, eax

    mov eax, 1
    ret 10h

mainmenu_wm_measureitem_proc    ENDP







;// WM_COMMAND wNotifyCode = HIWORD(wParam); // notification code
;// wID = LOWORD(wParam);         // item, control, or accelerator identifier
;// hwndCtl = (HWND) lParam;      // handle of control


ASSUME_AND_ALIGN
mainmenu_wm_command_proc    PROC


        mov eax, WP_WPARAM  ;// get the notify code and item ID
        and eax, 0FFFFh     ;// strip out notify code
        jz all_done_now     ;// if nothing left, then we don't care
                            ;// might not be safe, be careful of this


    ;// check if menu command
    .IF eax >= COMMAND_LOWEST && eax <= COMMAND_HIGHEST

        push ebp
        push esi
        push edi
        push ebx

        ASSUME ebx:PTR APIN
        ASSUME esi:PTR OSC_OBJECT

        stack_Peek gui_context, ebp
        xor esi, esi
        xor ebx, ebx

        ;// edit commands
        .IF eax <= COMMAND_PASTEFILE

            CMPJMP eax, COMMAND_DELETE,             je command_DELETE
            CMPJMP eax, COMMAND_DELETE_SELECTED,    je command_DELETE_SELECTED
            CMPJMP eax, COMMAND_CLONE,              je command_CLONE
            CMPJMP eax, COMMAND_CLONE_SELECTED,     je command_CLONE_SELECTED
            CMPJMP eax, COMMAND_PASTE,              je command_PASTE
            CMPJMP eax, COMMAND_CUT,                je command_CUT
            CMPJMP eax, COMMAND_COPY,               je command_COPY
            CMPJMP eax, COMMAND_PASTEFILE,          je command_PASTEFILE

        ;// navigation commands
        .ELSEIF eax <= COMMAND_PIN_PGDOWN

            OR_GET_PIN_FROM ebx, pin_down   ;// ignore if pin down
            jnz all_done_reg

            OR_GET_PIN_FROM ebx, pin_hover  ;// make sure there's a hover
            jz all_done_reg

            test [ebx].dwStatus, PIN_BUS_TEST   ;// make sure the hover is a bus
            jz all_done_reg

            ;// now we parse the keys

            CMPJMP eax, COMMAND_PIN_HOME,           je command_PIN_HOME
            CMPJMP eax, COMMAND_PIN_PGUP,           je command_PIN_PGUP
            CMPJMP eax, COMMAND_PIN_PGDOWN,         je command_PIN_PGDOWN

        ;// undo redo
        .ELSEIF eax <= COMMAND_REDO_MENU

            CMPJMP eax, COMMAND_UNDO,           je command_UNDO
            CMPJMP eax, COMMAND_UNDO_MENU,      je command_UNDO
            CMPJMP eax, COMMAND_REDO,           je command_REDO
            CMPJMP eax, COMMAND_REDO_MENU,      je command_REDO

        ;// select and lock
        .ELSEIF eax <= COMMAND_SELECT_CLEAR

            cmp eax, COMMAND_LOCK
            je command_LOCK
            cmp eax, COMMAND_UNLOCK
            je command_UNLOCK
            cmp eax, COMMAND_SELECT_CLEAR
            je command_SELECT_CLEAR

        ;// load save exit
        .ELSEIF eax <= COMMAND_EXIT

            CMPJMP eax, COMMAND_NEW,        je command_NEW
            CMPJMP eax, COMMAND_OPEN,       je command_OPEN
            CMPJMP eax, COMMAND_SAVE,       je command_SAVE
            CMPJMP eax, COMMAND_SAVEAS,     je command_SAVEAS
            CMPJMP eax, COMMAND_SAVEBMP,    je command_SAVEBMP
            CMPJMP eax, COMMAND_UNINSTAL,   je command_UNINSTAL
            CMPJMP eax, COMMAND_EXIT,       je command_EXIT

        ;// MRU
        .ELSEIF eax <= COMMAND_MRU5

            CMPJMP  eax, COMMAND_MRU1,      je command_MRU1
            CMPJMP  eax, COMMAND_MRU2,      je command_MRU2
            CMPJMP  eax, COMMAND_MRU3,      je command_MRU3
            CMPJMP  eax, COMMAND_MRU4,      je command_MRU4
            CMPJMP  eax, COMMAND_MRU5,      je command_MRU5


        ;// play stop
        .ELSEIF eax <= COMMAND_PLAY

            CMPJMP  eax, COMMAND_PLAY,      je command_PLAY_TOGGLE

        ;// circuit settings
        .ELSEIF eax <= COMMAND_AUTOPLAY

            CMPJMP eax, COMMAND_NOASKSAVE,  je command_NOASKSAVE
            CMPJMP eax, COMMAND_NOMOVE,     je command_NOMOVE
            CMPJMP eax, COMMAND_NOEDIT,     je command_NOEDIT
            CMPJMP eax, COMMAND_NOPINS,     je command_NOPINS
            CMPJMP eax, COMMAND_AUTOPLAY,   je command_AUTOPLAY

        ;// UI settings
        .ELSEIF eax <= COMMAND_UPDATE

            CMPJMP eax, COMMAND_CLOCKS,     je command_CLOCKS
            CMPJMP eax, COMMAND_CHANGING,   je command_CHANGING
            CMPJMP eax, COMMAND_STATUS,     je command_STATUS
            CMPJMP eax, COMMAND_UPDATE,     je command_UPDATE

        ;// popup panels
        .ELSEIF eax <= COMMAND_ESCAPE

            CMPJMP eax, COMMAND_COLORS,     je command_COLORS
            CMPJMP eax, COMMAND_ABOUT,      je command_ABOUT

        ;// view commands

            CMPJMP eax, COMMAND_ESCAPE,     je command_ESCAPE

        .ENDIF

        DEBUG_IF <1>    ;// UNHANDLED COMMAND !!

    all_done_reg:

        pop ebx
        pop edi
        pop esi
        pop ebp

        jmp all_done_now

    .ELSE

    ;// if we hit this, we want to insert an osc

        ;// we probably want to insert a control
        ;// make sure we're getting a message that wants to insert an object
        ;// and not a message from some control

            invoke app_CreateOsc, 0, 0

            unredo_BeginAction UNREDO_NEW_OSC

            jmp all_done_now

    .ENDIF

    ;// default is do nothing

        jmp DefWindowProcA

    all_done_now:

        SET_STATUS REFRESH

        invoke app_Sync

        xor eax, eax
        ret 10h








;////////////////////////////////////////////////////////////////////
;//
;//
;//     edit commands   sent from vkeys
;//

    ASSUME ebx:PTR APIN
    ASSUME esi:PTR OSC_OBJECT

    ;// COMMAND_DELETE
    command_DELETE:

        ;// delete what ? , an osc, a connection, or nothing

            or ebx, pin_down    ;// don't delete if we're dragging a pin
            jnz all_done_reg

            or ebx, pin_hover   ;// delete a pin ?
            jnz delete_pin

            or esi, osc_down    ;// don't delete if we're dragging a pin
            jnz all_done_reg

            or esi, osc_hover   ;// delete an osc ?
            jz command_DELETE_SELECTED  ;// try dlete selected

        delete_osc:

            invoke osc_Command
            unredo_EndAction UNREDO_DEL_OSC

            jmp all_done_reg

        delete_pin:

            ;// make sure it's connected

            cmp [ebx].pPin, 0
            jne unconnect_this

            test [ebx].dwStatus, PIN_BUS_TEST
            jz all_done_reg

        unconnect_this: ;// is connected

            push ebx
            invoke mouse_reset_all_hovers
            pop ebx

            unredo_BeginAction UNREDO_UNCONNECT

            ENTER_PLAY_SYNC GUI
                invoke pin_Unconnect
            LEAVE_PLAY_SYNC GUI

            unredo_EndAction UNREDO_UNCONNECT

            or app_bFlags, APP_SYNC_GROUP OR APP_SYNC_MOUSE

            jmp all_done_reg

    ;// COMMAND_DELETE_SELECTED
    command_DELETE_SELECTED:

        ;// make sure there's a clist
        CMPJMP clist_MRS(oscS, [ebp]), 0, je all_done_reg

        invoke context_Delete_prescan
        TESTJMP eax, eax, jz all_done_reg

        unredo_BeginAction UNREDO_DEL_OSC

        invoke context_Delete

        unredo_EndAction UNREDO_DEL_OSC

        jmp all_done_reg


    ;// COMMAND_CLONE
    command_CLONE:

        TESTJMP app_bFlags,APP_MODE_CONNECTING_PIN, jnz all_done_reg    ;// ABOX234

        .IF app_bFlags & APP_MODE_OSC_HOVER OR APP_MODE_CON_HOVER

            mov esi, osc_hover
            mov eax, COMMAND_CLONE
            invoke osc_Command
            jmp all_done_reg

        .ENDIF

    ;// COMMAND_CLONE_SELECTED
    command_CLONE_SELECTED:

        CMPJMP clist_MRS(oscS, [ebp]), 0, je all_done_reg

        invoke context_Copy

        unredo_BeginAction UNREDO_CLONE_OSC

        invoke context_Paste, file_pCopyBuffer, 0, 1    ;// no ids, select oscs

        jmp all_done_reg


    ;// COMMAND_PASTE
    command_PASTE:

        TESTJMP app_bFlags,APP_MODE_CONNECTING_PIN, jnz all_done_reg    ;// ABOX234

        ;// make sure (command may be hit from accelerator)
        CMPJMP file_pCopyBuffer, 0, je all_done_reg

        unredo_BeginAction UNREDO_PASTE

        invoke context_Paste,file_pCopyBuffer,0, 1      ;// no ids, select

        ;// unredo_EndAction UNREDO_PASTE

        jmp all_done_reg

    ;// COMMAND_CUT
    command_CUT:

        TESTJMP app_bFlags,APP_MODE_CONNECTING_PIN, jnz all_done_reg    ;// ABOX234

        ;// make sure something is selected
        CMPJMP clist_MRS(oscS, [ebp]), 0, je all_done_reg

        invoke context_Copy

        ;// remove objects that we are not supposed to delete
        invoke context_Delete_prescan
        TESTJMP eax, eax, jz all_done_reg

            unredo_BeginAction UNREDO_DEL_OSC

                invoke context_Delete

            unredo_EndAction UNREDO_DEL_OSC

            jmp all_done_reg

    ;// COMMAND_COPY
    command_COPY:

        TESTJMP app_bFlags,APP_MODE_CONNECTING_PIN, jnz all_done_reg    ;// ABOX234

        cmp clist_MRS(oscS, [ebp]), 0   ;// make sure something is selected
        je all_done_reg

        invoke context_Copy

        jmp all_done_reg

    ;// COMMAND_PASTEFILE
    command_PASTEFILE:

        invoke filename_GetFileName, GETFILENAME_PASTE

        or eax, eax
        jz all_done_reg ;// cancel ?

        invoke context_PasteFile    ;// call paste file

        jmp all_done_reg

;////////////////////////////////////////////////////////////////////
;//
;//
;//     navigation commands
;//
;//

    ;// in all cases: ebx has pin hover, it is already checked to be a bus

        ;// COMMAND_PIN_HOME
        command_PIN_HOME:   ;// go to the first pin in the bus

            test [ebx].dwStatus, PIN_OUTPUT ;// already there ?
            jnz all_done_reg

            mov ebx, [ebx].pPin ;// move to source
            jmp pin_move_to_ebx

        ;// COMMAND_PIN_PGUP
        command_PIN_PGUP:   ;// locate and move to previous pin in chain

            test [ebx].dwStatus, PIN_OUTPUT ;// make sure there is on
            jnz all_done_reg

            ;// locate the pin that points to us

            mov edx, ebx        ;// save in edx for testing
            mov ebx, [ebx].pPin ;// get the first item
            cmp edx, [ebx].pPin ;// are we there yet ?
            je pin_move_to_ebx  ;// jump if so
            mov ebx, [ebx].pPin ;// get the first pin

            .WHILE ebx
                cmp edx, [ebx].pData;// are we there yet ?
                je pin_move_to_ebx  ;// jump if so
                mov ebx, [ebx].pData;// get next pin
            .ENDW

            jmp all_done_reg

        ;// COMMAND_PIN_PGDOWN
        command_PIN_PGDOWN: ;// goto to next pin in chain

            ;// get it and make sure there is one
            .IF [ebx].dwStatus & PIN_OUTPUT
                mov ebx, [ebx].pPin
            .ELSE
                mov ebx, [ebx].pData
            .ENDIF
            or ebx, ebx
            jz all_done_reg

        pin_move_to_ebx:

            ;// ebx must have the pin to move to

            DEBUG_IF <!!ebx>    ;// ebx is zero !!!

            ;// our task now is to determine how much to move the screen
            ;// so we want the mouse to be on the point t1
            ;// we also need to make sure the points are valid to be able to that

            .IF !([ebx].dwHintPin & HINTPIN_STATE_VALID_TSHAPE)
                invoke pin_Layout_shape
            .ENDIF

            .IF !([ebx].dwHintPin & HINTPIN_STATE_VALID_DEST)
                invoke pin_Layout_points
            .ENDIF

            point_Get mouse_now
            point_Sub [ebx].t1
            point_Set mouse_delta

            unredo_BeginAction UNREDO_SCROLL

            or app_bFlags, APP_MODE_MOVING_SCREEN OR APP_SYNC_MOUSE
            invoke context_MoveAll
            and app_bFlags, NOT APP_MODE_MOVING_SCREEN

            unredo_EndAction UNREDO_SCROLL

            jmp all_done_reg



;////////////////////////////////////////////////////////////////////
;//
;//
;//     undo redo
;//
;//

    ;// COMMAND_UNDO
    command_UNDO:

    ;// make sure we can undo

        mov eax, unredo_pCurrent
        cmp eax, dlist_Head(unredo)
        je all_done_reg

    ;// see if we are the middle of something else

        cmp pin_down, 0
        jne all_done_reg

        cmp osc_down, 0
        jne all_done_reg

        cmp unredo_pRecorder, 0
        jnz all_done_reg

    ;// perform the undo step

        invoke unredo_Undo

        jmp all_done_reg

    ;// COMMAND_REDO
    command_REDO:

    ;// make sure we can redo

        mov eax, unredo_pCurrent
        cmp eax, dlist_Tail(unredo)
        je all_done_reg

    ;// see if we are the middle of something else

        cmp pin_down, 0
        jne all_done_reg

        cmp osc_down, 0
        jne all_done_reg

        cmp unredo_pRecorder, 0
        jnz all_done_reg

    ;// perform the redo step

        invoke unredo_Redo

        jmp all_done_reg


;////////////////////////////////////////////////////////////////////
;//
;//
;//     select and lock
;//
;//

    ;// COMMAND_LOCK
    command_LOCK:

        ;// make sure something is selected

        clist_GetMRS oscS, esi, [ebp]
        or esi, esi
        jz all_done_reg

        unredo_BeginEndAction UNREDO_LOCK_OSC

        invoke locktable_Lock
        jmp all_done_reg

    ;// COMMAND_UNLOCK
    command_UNLOCK:

        ;// make sure something is selected

        clist_GetMRS oscS, esi, [ebp]
        or esi, esi
        jz all_done_reg

        unredo_BeginEndAction UNREDO_UNLOCK_OSC

        invoke locktable_Unlock
        jmp all_done_reg


    ;// COMMAND_SELECT_CLEAR
    command_SELECT_CLEAR:

        invoke context_UnselectAll

        jmp all_done_reg




;////////////////////////////////////////////////////////////////////
;//
;//
;//     new load save exit
;//
;//



    ;// COMMAND_NEW
    command_NEW:

        .IF unredo_we_are_dirty && !( app_CircuitSettings & CIRCUIT_NOSAVE )
            invoke filename_QueryAndSave
            cmp eax, IDCANCEL
            je all_done_reg
        .ENDIF

        .IF play_status & PLAY_PLAYING
            invoke play_Stop
            invoke Sleep, 5
        .ENDIF

        ENTER_PLAY_SYNC GUI

            invoke circuit_New

        LEAVE_PLAY_SYNC GUI

        xor ebx, ebx
        xchg filename_circuit_path, ebx ;// set circuit path to zero
        test ebx, ebx                   ;// see if we had an old name
        jz all_done_reg                 ;// exit now if not
        filename_PutUnused ebx          ;// release the old name
        jmp all_done_reg

    ;// COMMAND_OPEN
    command_OPEN:


        .IF unredo_we_are_dirty && !( app_CircuitSettings & CIRCUIT_NOSAVE )
            invoke filename_QueryAndSave
            cmp eax, IDCANCEL
            je all_done_reg
        .ENDIF

        ;// ask for a filename

        invoke filename_GetFileName, GETFILENAME_OPEN

        ;// did we back out ?

        or eax, eax
        jz all_done_reg     ;// did we cancel ?

        invoke circuit_Load ;// load the file
        test eax, eax       ;// did it work ?
        jnz all_done_reg

        ;// need to release filename_get_path
        xchg eax, filename_get_path
        test eax, eax
        jz all_done_reg

        filename_PutUnused eax
        jmp all_done_reg


    ;// COMMAND_SAVE
    command_SAVE:

        DEBUG_IF <!!filename_circuit_path>  ;// supposed to have a filename !
        invoke circuit_Save

        jmp all_done_reg


    ;// COMMAND_SAVEAS
    command_SAVEAS:

        invoke filename_GetFileName, GETFILENAME_SAVEAS
        test eax, eax
        jz all_done_reg

        mov ebx, filename_get_path
        xchg filename_circuit_path, ebx
        mov filename_get_path, 0        ;// clear the pointer
        .IF ebx
            DEBUG_IF <ebx==filename_circuit_path>
            filename_PutUnused ebx      ;// release the name
        .ENDIF

        invoke circuit_Save
        jmp all_done_reg

    ;// COMMAND_SAVEBMP
    command_SAVEBMP:

        invoke filename_GetFileName, GETFILENAME_BITMAP
        test eax, eax               ;// cancel ?
        jz all_done_reg

        mov ebx, filename_get_path
        xchg filename_bitmap_path, ebx
        mov filename_get_path, 0
        .IF ebx
            DEBUG_IF <ebx==filename_get_path>
            filename_PutUnused ebx
        .ENDIF

        invoke circuit_SaveBmp  ;// save the file

        ;// destroy the filename so we copy the circuit name

        mov edx, filename_bitmap_path
        mov filename_bitmap_path, 0
        filename_PutUnused edx

        jmp all_done_reg

    ;// COMMAND_UNINSTAL
    command_UNINSTAL:

        or app_DlgFlags, DLG_MESSAGE
        invoke MessageBoxA, 0, OFFSET sz_uninstal_text, OFFSET sz_uninstal_caption, MB_OKCANCEL OR MB_ICONEXCLAMATION OR MB_APPLMODAL
        and app_DlgFlags, NOT DLG_MESSAGE
        cmp eax, IDCANCEL
        je all_done_reg

        jmp registry_Uninstall


    ;// COMMAND_EXIT
    command_EXIT:

        invoke PostMessageA, hMainWnd, WM_CLOSE, 0, 0
        jmp all_done_reg


;////////////////////////////////////////////////////////////////////
;//
;//
;//     MRU
;//
;//


    ;// COMMAND_MRU1
    command_MRU1:

        push filename_mru1_path
        jmp query_prepare_then_load

    ;// COMMAND_MRU2
    command_MRU2:

        push filename_mru2_path
        jmp query_prepare_then_load

    ;// COMMAND_MRU3
    command_MRU3:

        push filename_mru3_path
        jmp query_prepare_then_load

    ;// COMMAND_MRU4
    command_MRU4:

        push filename_mru4_path
        jmp query_prepare_then_load

    ;// COMMAND_MRU5
    command_MRU5:

        test app_DlgFlags, DLG_TEST
        jnz all_done_reg

        invoke registry_ReadMRU5
        push filename_mru5_path

    query_prepare_then_load:
    ;// filename to load must be pushed on the stack
    ;// we have to copy it to a new record

        .IF unredo_we_are_dirty && !( app_CircuitSettings & CIRCUIT_NOSAVE )
            invoke filename_QueryAndSave
            .IF eax == IDCANCEL
                pop eax ;// clean up the stack
                jmp all_done_reg
            .ENDIF
        .ENDIF

        ;// xfer the desired filename to filename_load_path

        pop esi ;// load the filename we want
                ;// we don't free esi, it's one of the mru entries
        add esi, OFFSET FILENAME.szPath
        DEBUG_IF <filename_get_path>
        invoke filename_GetUnused
        mov filename_get_path, ebx
        invoke filename_InitFromString, FILENAME_FULL_PATH

        invoke circuit_Load ;// load the file

        jmp all_done_reg



;////////////////////////////////////////////////////////////////////
;//
;//
;//     play toggle
;//

    ;// play stop

    ;// COMMAND_PLAY
    command_PLAY_TOGGLE:

        ;// make sure this is valid to do

        cmp master_context.oscR_slist_head, 0   ;// is there any device that can play ?
        je all_done_reg

        .IF play_status & PLAY_PLAYING
            invoke play_Stop
            and menu_play.dwFlags, NOT MXT_PUSHED
        .ELSE
            invoke play_Start
            or menu_play.dwFlags, MXT_PUSHED
        .ENDIF
        invoke DrawMenuBar, hMainWnd

        jmp all_done_reg


;////////////////////////////////////////////////////////////////////
;//
;//
;//     circuit settings
;//

    ;// COMMAND_NOASKSAVE
    command_NOASKSAVE:

        unredo_BeginAction UNREDO_SETTINGS

        xor app_CircuitSettings, CIRCUIT_NOSAVE
        jmp update_dirty_and_exit

    ;// COMMAND_NOMOVE
    command_NOMOVE:

        unredo_BeginAction UNREDO_SETTINGS

        xor app_CircuitSettings, CIRCUIT_NOMOVE
        jmp update_dirty_and_exit

    ;// COMMAND_NOEDIT
    command_NOEDIT:

        unredo_BeginAction UNREDO_SETTINGS

        xor app_CircuitSettings, CIRCUIT_NOEDIT
        jmp update_dirty_and_exit

    ;// COMMAND_NOPINS
    command_NOPINS:

        unredo_BeginAction UNREDO_SETTINGS

        xor app_CircuitSettings, CIRCUIT_NOPINS
        jmp update_dirty_and_exit


    ;// COMMAND_AUTOPLAY
    command_AUTOPLAY:

        unredo_BeginAction UNREDO_SETTINGS

        xor app_CircuitSettings, CIRCUIT_AUTOPLAY

    update_dirty_and_exit:

        unredo_EndAction UNREDO_SETTINGS

    update_and_exit:

        or app_bFlags, APP_SYNC_OPTIONBUTTONS
        jmp all_done_reg



;////////////////////////////////////////////////////////////////////
;//
;//
;//     UI settings
;//


    ;// COMMAND_CLOCKS
    command_CLOCKS:

        ENTER_PLAY_SYNC GUI
        xor app_settings.show, SHOW_CLOCKS
        or master_context.pFlags, PFLAG_FLUSH_CLOCKS
        LEAVE_PLAY_SYNC GUI
        jmp update_and_exit

    ;// COMMAND_CHANGING
    command_CHANGING:

        ENTER_PLAY_SYNC GUI
        xor app_settings.show, SHOW_CHANGING
        or master_context.pFlags, PFLAG_FLUSH_PINCHANGE
        LEAVE_PLAY_SYNC GUI
        jmp update_and_exit

    ;// COMMAND_STATUS
    command_STATUS:

        xor app_settings.show, SHOW_STATUS
        jmp update_and_exit

    ;// COMMAND_UPDATE
    command_UPDATE:

        ;// update has two values

        xor app_settings.show, SHOW_UPDATE_FAST
        jmp update_and_exit



;////////////////////////////////////////////////////////////////////
;//
;//
;//     panels
;//


    ;// popup panels

    ;// COMMAND_COLORS
    command_COLORS:

        invoke colors_Show
        jmp all_done_reg

    ;// COMMAND_ABOUT
    command_ABOUT:

        invoke about_Show, 0
        jmp all_done_reg

;////////////////////////////////////////////////////////////////////
;//
;//
;//     escape
;//

;// view commands

    ;// COMMAND_ESCAPE
    command_ESCAPE:

        test app_bFlags, APP_MODE_IN_GROUP
        jz all_done_reg

        unredo_BeginEndAction UNREDO_LEAVE_GROUP
        invoke closed_group_ReturnFromView
        invoke InvalidateRect, hMainWnd, 0, 1

        jmp all_done_reg


mainmenu_wm_command_proc    ENDP




;/////////////////////////////////////////////////////////////////////////


;// WM_INITMENUPOPUP
;// hmenuPopup = (HMENU) wParam;         // handle of submenu
;// uPos = (UINT) LOWORD(lParam);        // submenu item position
;// fSystemMenu = (BOOL) HIWORD(lParam); // window menu flag


;// then call SyncMRU to make sure all the files are there

ASSUME_AND_ALIGN
mainmenu_wm_initmenupopup_proc  PROC

    .IF !WP_LPARAM  ;//(WP_LPARAM) only use the file menu

    ;// all this does is make sure the damn item gets hilighted

        mov menu_hilite_kludge, COMMAND_NEW

        push ebp
        push ebx
        push esi
        push edi

        ;// stack
        ;// edi esi ebx ebp ret hWnd    msg hMenu   pos/sys
        ;// 00  04  08  0C  10  14      18  1C      20

        mov ebp, [esp+1Ch]  ;// get the menu handle

    ;// 1) verify the existance and count the 4 mru items
    ;// 2) make sure the count of menu items matches the count of mru items
    ;// 3) set the text pointers for the four items




    ;// 1) verify the existance and count the 4 mru items
    ;//     assume the mru's are packed

        mov esi, 4                  ;// count to 4
        lea edi, filename_mru1_path ;// iterate mru pointers
        xor ebx, ebx                ;// bl = number of valid files
                                    ;// bh = need to pack
        ASSUME edi:PTR DWORD
        ASSUME ecx:PTR FILENAME

        .REPEAT

            mov ecx, [edi]          ;// get the mru pointer
            .IF ecx                 ;// make sure it's not zero

                lea ecx, [ecx].szPath           ;// point at the filename string

                invoke CreateFileA, ecx, GENERIC_READ, FILE_SHARE_READ, 0, OPEN_EXISTING, 0, 0

                .IF eax == INVALID_HANDLE_VALUE ;// this file does not exist

                    inc eax         ;// = 0
                    mov ecx, [edi]          ;// get the file name again
                    filename_PutUnused ecx  ;// release the name
                    mov [edi], eax          ;// zero the pointer
                    inc bh                  ;// set need_to_pack

                .ELSE   ;// file does exist

                    invoke CloseHandle, eax ;// close the handle
                    inc bl                  ;// increase the valid count

                .ENDIF

            .ELSE

                inc bh  ;// increase need to pack

            .ENDIF


            add edi, 4  ;// next pointer
            dec esi     ;// decrease the counter

        .UNTIL ZERO?

    ;// 1a) call pack if nessseary

        .IF bh

            invoke filename_PackMRU
            mov bh, 0

        .ENDIF

    ;// 2) count the menu items

        invoke GetMenuItemCount, ebp    ;// get total nummber of items
        sub eax, NUMITEMS_SANS_MRU      ;// subtract the number that aren't mru's
        sub ebx, eax                    ;// subtract from number needed
        ;// so eax has the mru index of what ever to add

    ;// 2a) determine if we need to add or remove items

        .IF SIGN?   ;// need to remove -ebx items

            ;// ABBOX226 deleting the wrong menu items causes many problems later on
            ;// eax has the current number of mru items
            ;// we want to remove -ebx items starting from the end of the list

            mov esi, ebx    ;// save the count
            lea ebx, [ebx+eax+COMMAND_MRU1]
            .REPEAT
                invoke DeleteMenu, ebp, ebx, MF_BYCOMMAND
                DEBUG_IF <!!eax>,GET_ERROR
                inc ebx
                inc esi
            .UNTIL ZERO?

        comment ~ /*
        old version deleted wrong menu item
            add ebx, COMMAND_MRU5   ;// remove items starting here
            .REPEAT
                invoke DeleteMenu, ebp, ebx, MF_BYCOMMAND
                DEBUG_IF <!!eax>,GET_ERROR
                inc ebx
            .UNTIL ebx > COMMAND_MRU4
        */ comment ~

        .ELSEIF !ZERO?  ;// need to add ebx items

        ;// get a pointer to the item we want to add

        ;// ebx is the number to insert
        ;// eax is the number shown now

        ;// we need:
        ;// edi a menu position
        ;// esi a pointer to the mxt item
        ;// ebx a counter of items we just inserted

            lea esi, [eax*8]                ;// *8  mxt_items are 8 dwords
            lea edi, [eax+POSITION_MRU1-1]  ;// menu position
            lea esi, menu_mru1[esi*4]       ;// points at first record
            ASSUME esi:PTR MXT_ITEM

        ;// build a menu item info pointer on the stack

            xor eax, eax
            pushd eax   ;// 11  cch         dd 0
            pushd eax   ;// 10  dwTypeData  dd 0
            pushd eax   ;// 9   dwItemData  dd 0
            pushd eax   ;// 8   hbmpUnchecked   dd 0
            pushd eax   ;// 7   hbmpChecked dd 0
            pushd eax   ;// 6   hSubMenu    dd 0
            pushd eax   ;// 5   dwID        dd 0
            pushd eax   ;// 4   fState      dd 0
            pushd eax   ;// 3   fType       dd 0
            pushd MIIM_TYPE OR MIIM_DATA OR MIIM_ID ;// 2   fMask       dd 0
            pushd SIZEOF MENUITEMINFO   ;// 1   cbSize      dd SIZEOF MENUITEMINFO

            st_info TEXTEQU <(MENUITEMINFO PTR [esp])>

        ;// do the insertions

            .REPEAT

                ;// as above, in mainmenu_wm_create_proc, we insert the items in two steps

                mov st_info.fType, MF_STRING

                mov st_info.dwID, edi       ;// store the position as the id
                mov ecx, [esi].pText        ;// point at the string
                mov st_info.dwItemData, esi ;// store the item data

                add st_info.dwID, COMMAND_MRU1 - POSITION_MRU1 + 1 ;// add this to the position to get the command id right

                mov st_info.dwTypeData, ecx ;// store the string

                invoke InsertMenuItemA, ebp, edi, MF_BYPOSITION, esp
                mov st_info.fType, MF_OWNERDRAW OR MF_STRING
                invoke SetMenuItemInfoA, ebp, edi, MF_BYPOSITION, esp

                inc edi                     ;// increase the position
                add esi, SIZEOF MXT_ITEM    ;// increase the pointer
                dec ebx                     ;// decrease the count

            .UNTIL ZERO?    ;// ebx > POSITION_MRU4

        ;// clean up

            add esp, SIZEOF MENUITEMINFO

        .ENDIF

    ;// 5) set the string pointers for all four items

        lea edi, menu_mru1
        ASSUME edi:PTR MXT_ITEM
        lea esi, filename_mru1_path
        ASSUME esi:PTR DWORD

        mov ebx, 4

        ASSUME eax:PTR FILENAME

        .REPEAT

            lodsd       ;// get the mxt pointer
            .IF eax     ;// anything ?
                lea eax, [eax].szPath   ;// point at full path
            .ENDIF

            mov [edi].pPath, eax        ;// store in mxt item

            add edi, SIZEOF MXT_ITEM    ;// next item

            dec ebx                     ;// decrease the count

        .UNTIL ZERO?

    ;// 6) whew !

        pop edi
        pop esi
        pop ebx
        pop ebp

    .ENDIF
    jmp DefWindowProcA

mainmenu_wm_initmenupopup_proc  ENDP



;////////////////////////////////////////////////////////////////////////////////////
;//
;//     help string setting
;//


PROLOGUE_OFF
ASSUME_AND_ALIGN
mainmenu_update_help_text   PROC STDCALL hMenu:DWORD, item:DWORD

    stack_depth = 0

    ;// stack
    ;//
    ;// ret hMenu item
    ;// 00  04    08

        st_menu TEXTEQU <(DWORD PTR [esp+4+stack_depth*4])>
        st_item TEXTEQU <(DWORD PTR [esp+8+stack_depth*4])>

    ;// build a new hItem

        mov eax, st_menu
        mov ecx, st_item
        shl eax, 16
        add eax, ecx

    ;// see if we can skip entirely

        cmp eax, mainmenu_hUndo
        je item_is_unredo
        cmp eax, mainmenu_hRedo
        jne item_is_not_unredo

    item_is_unredo:

        mov edx, unredo_pCurrent        ;// see if we already know this
        cmp edx, mainmenu_last_unredo
        mov mainmenu_last_unredo, edx   ;// always update
        jne get_the_item

    item_is_not_unredo:

        cmp eax, mainmenu_last_hItem
        je all_done

    get_the_item:   ;// ecx is still the item number
                    ;// eax is still the new hItem

        mov edx, st_menu                    ;// get the menu before we kill the stack
        mov mainmenu_last_hItem, eax        ;// store the new last item

        sub esp, SIZEOF MENUITEMINFO - 8    ;// make room for MENUITEMINFO

        pushd MIIM_DATA                     ;// push the fMask value
        pushd SIZEOF MENUITEMINFO           ;// push the struct size

        xor eax, eax            ;// menu select sends the id, not the item index
        cmp ecx, COMMAND_LOWEST ;// so we check that here
        setb al

        invoke GetMenuItemInfoA, edx, ecx, eax, esp ;// get the info we want

        mov ecx, (MENUITEMINFO PTR [esp]).dwItemData    ;// get the MXT pointer
        add esp, SIZEOF MENUITEMINFO        ;// clean up the stack

        ASSUME ecx:PTR MXT_ITEM

    ;// see if this is an empty record, or does not have a help string

        xor edx, edx
        test ecx, ecx
        jz have_empty_mxt_record
        or edx, [ecx].pHelp         ;// edx is now the help string
        jz have_empty_mxt_record

    ;// we have to build something, determine what

        test [ecx].dwFlags, MXT_PATH OR MXT_PATH_EX
        jnz have_path_to_build

        cmp ecx, OFFSET menu_undo
        jae have_unredo_to_build    ;// this will preserve the zero flag

    ;// build normal help text
    have_normal_help_text:

        ;// state: edx must have the help string pointer

            mov sm_mainmenu, edx    ;// store the help string
            jmp exit_with_update

    ;// build a path
    have_path_to_build:

            push ebx
            push edi
            push esi

        ;// get the help string

            call get_mainmenu_help_string   ;// returns in ebx
            ASSUME ebx:PTR FILENAME

        ;// store the prefix

            lea edi, [ebx].szPath   ;// destination
            mov sm_mainmenu, edi    ;// store now
            mov esi, [ecx].pHelp    ;// help prefix

            STRCPY_SD NOTERMINATE   ;// copy the prefix

        ;// which type of path are we ?

            mov esi, [ecx].pPath    ;// path string

            .IF [ecx].dwFlags & MXT_PATH_EX ;// is it a path we have to parse ?

                ;// indirected path string
                mov esi, DWORD PTR [esi]
                lea esi, (FILENAME PTR [esi]).szPath

            .ENDIF

            STRCPY_SD TERMINATE     ;// copy it

            pop esi
            pop edi
            pop ebx

            jmp exit_with_update

    ;// build the unredo id
    have_unredo_to_build:

        ;// state, the zero flag is still set to indicate undo, or not set to indicate redo
        ;// ecx is still the mxt record
        ;// edx is still at [ecx].pHelp
        ;// last_unredo has already been updated

        mov eax, mainmenu_last_unredo
        jne got_redo

        got_undo:   ;// make sure there is something to undo

            cmp eax, dlist_Head(unredo)
            je have_normal_help_text    ;// defaults to displaying 'nothing to undo'

            test eax, eax
            jz have_normal_help_text

            push ebx
            push edi

            call get_mainmenu_help_string
            ASSUME ebx:PTR FILENAME

            lea edi, [ebx].szPath
            mov sm_mainmenu, edi

            invoke unredo_GetUndoString, edi

            ;// check for dropping records
            .IF unredo_drop_counter

                push esi
                lea edi, [eax-1]
                mov esi, OFFSET sz_unredo_full
                STRCPY_SD TERMINATE
                pop esi

            .ENDIF

            pop edi
            pop ebx

            jmp exit_with_update

        got_redo:

            cmp eax, dlist_Tail(unredo)
            je have_normal_help_text    ;// defaults to displaying 'nothing to redo'

            push ebx
            push edi

            call get_mainmenu_help_string
            ASSUME ebx:PTR FILENAME

            lea edi, [ebx].szPath
            mov sm_mainmenu, edi

            invoke unredo_GetRedoString, edi

            ;// check for dropping records
            .IF unredo_drop_counter

                push esi
                lea edi, [eax-1]
                mov esi, OFFSET sz_unredo_full
                STRCPY_SD TERMINATE
                pop esi

            .ENDIF

            pop edi
            pop ebx

            jmp exit_with_update

    have_empty_mxt_record:

        ;// state,  ecx is stil mxt record
        ;//         edx is zero

            xchg edx, sm_mainmenu
            or edx, edx
            je all_done

    exit_with_update:

        SET_STATUS status_MAINMENU, MANDATORY
        ;//invoke app_Sync

    all_done:

        ret 8


    ;// local function

    ALIGN 16
    get_mainmenu_help_string:

    ;// make sure mainmenu_help_string_is_allocated

        xor ebx, ebx
        or ebx, mainmenu_help_string    ;// load and test the help string path
        .IF ZERO?
            push ecx                    ;// allocate if not set yet
            invoke filename_GetUnused
            pop ecx
            mov mainmenu_help_string, ebx
        .ENDIF

        retn

mainmenu_update_help_text ENDP
PROLOGUE_ON



;// WM_SETCURSOR
;// hwnd = (HWND) wParam;       // handle of window with cursor
;// nHittest = LOWORD(lParam);  // hit-test code
;// wMouseMsg = HIWORD(lParam); // mouse-message identifier
ASSUME_AND_ALIGN
mainmenu_wm_setcursor_proc  PROC

    ;// task:   if cursor is over the main menu
    ;//         display the help text for that item

    .IF WP_LPARAM_LO != HTCLIENT

    ;// mouse is in our non_client area

    ;// make sure the mouse hovers get reset

        xor eax, eax
        or eax, pin_hover
        or eax, osc_hover
        .IF !ZERO?

            push ebp
            push ebx
            stack_Peek gui_context, ebp
            invoke mouse_reset_all_hovers
            pop ebx
            pop ebp

        .ENDIF

    ;// first check if we have the status bar on

        test app_settings.show, SHOW_STATUS     ;// are we showing the status ?
        jz all_done_now                             ;// nothing here to do if not

    ;// then check if the desk was being hovered

        .IF last_status_mode == status_HOVER_DESK       || \
            last_status_mode == status_HOVER_DESK_SEL
            SET_STATUS 0, MANDATORY
        .ENDIF

    ;// then check if the cursor is over the menu

        .IF WP_LPARAM_LO != HTMENU      ;// menu ?
        reset_last_item:
            mov mainmenu_last_hItem, 0  ;// reset this
            jmp all_done                ;// exit if not a menu
        .ENDIF

    ;// determine which menu item is being hit

        sub esp, SIZEOF POINT           ;// make a temp point
        invoke GetCursorPos, esp        ;// get the cursor position
        push hMainMenu                  ;// help system lies !
        push hMainWnd                   ;// item from point expects screen coords
        call MenuItemFromPoint

        test eax, eax   ;// exit if no item is being hit
        ;//js all_done
        js reset_last_item

        invoke mainmenu_update_help_text, hMainMenu, eax

    all_done:

        invoke app_Sync

    all_done_now:
    .ENDIF ;// HT_CLIENT

        jmp DefWindowProcA

mainmenu_wm_setcursor_proc  ENDP

;// WM_MENUSELECT
;// uItem = (UINT) LOWORD(wParam);   // menu item or submenu index
;// fuFlags = (UINT) HIWORD(wParam); // menu flags
;// hmenu = (HMENU) lParam;          // handle of menu clicked
ASSUME_AND_ALIGN
mainmenu_wm_menuselect_proc PROC

    ;// this is hit every time a menu item is highlighted
    ;// our job is to determine what the help string should be

    .IF app_settings.show & SHOW_STATUS &&  \       ;// setting must be on
        !(WP_WPARAM_HI & (MF_POPUP OR MF_SYSMENU))  ;// only do sub menus

        movzx ecx, WP_WPARAM_LO     ;// get the item ID
        mov edx, WP_LPARAM          ;// get the menu handle
        test ecx, ecx
        je all_done

        invoke mainmenu_update_help_text, edx, ecx
        invoke app_Sync

    all_done:

    .ENDIF  ;// status bar is off or we got a menu we dont care about

    jmp DefWindowProcA

mainmenu_wm_menuselect_proc ENDP




;///////////////////////////////////////////////////////////////////////////////////////
;//
;//     mouse translation
;//

;// these two routines are need to tell mouse handlers that they need to translate their
;// mouse coords from screen to client
comment ~ /*

    some intersting facts about this:

    when inside the menu loop,

        WM_MOUSEMOVE messages are eaten
        WM_LBUTTONDOWN messages are eaten
        WM_RBUTTONDOWN messages are eaten

        WM_LBUTTONUP will exit the loop, and is eaten

        WM_RBUTTONUP is NOT eaten, and then exits the loop


*/ comment ~

ASSUME_AND_ALIGN
mainmenu_wm_entermenuloop_proc  PROC    ;// stdcall hWnd, msg, wParam, lParam

    or app_DlgFlags, DLG_MENU

    xor eax, eax
    ret 10h

mainmenu_wm_entermenuloop_proc  ENDP


ASSUME_AND_ALIGN
mainmenu_wm_exitmenuloop_proc   PROC    ;// stdcall hWnd, msg, wParam, lParam

    and app_DlgFlags, NOT DLG_MENU

    xor eax, eax
    ret 10h

mainmenu_wm_exitmenuloop_proc   ENDP









;/////////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////////
;///
;///
;///    A P P   S Y N C H R O N I Z A T I O N
;///
;///


ASSUME_AND_ALIGN
mainmenu_SyncPlayButton PROC

    ;// this routine checks if the circuit is playable
    ;// and displays the main menu accordingly

        cmp master_context.oscR_slist_head, 0   ;// is there any device that can play ?
        jnz we_are_playable

    we_are_not_playable:

        .IF play_status & PLAY_PLAYING          ;// are we playing now ?
            invoke play_Stop                    ;// stop playing
        .ENDIF

        and menu_play.dwFlags, NOT MXT_PUSHED   ;// reset the flag in the toggle state

        mov ecx, MF_GRAYED OR MF_BYCOMMAND

        jmp redraw_the_menu

    we_are_playable:

        and menu_play.dwFlags, NOT MXT_PUSHED   ;// reset the flag in the toggle state
        .IF play_status & PLAY_PLAYING          ;// are we playing now ?
            or menu_play.dwFlags, MXT_PUSHED    ;// set the flags in the toggle state
        .ENDIF

        mov ecx, MF_ENABLED OR MF_BYCOMMAND

    redraw_the_menu:

        invoke EnableMenuItem, hMainMenu, COMMAND_PLAY, ecx
        invoke DrawMenuBar, hMainWnd            ;// redraw the menu

    ;//all_done:

        and app_bFlags, NOT APP_SYNC_PLAYBUTTON ;// turn the bit off

        ret

mainmenu_SyncPlayButton ENDP




ASSUME_AND_ALIGN
mainmenu_SyncOptionButtons  PROC uses ebx edi

    ;// make sure the menu buttons are correct
    ;// xfer the setting bit to the appropriate MXT record

    ;// CIRCUIT SETTINGS

        mov eax, NOT MXT_PUSHED     ;// ANDs
        mov ebx, MXT_PUSHED         ;// ORs
        ASSUME edi:PTR DWORD
        mov edx, SIZEOF MXT_ITEM    ;// iterates destinations

    mov ecx, app_CircuitSettings    ;// parses bits
    lea edi, menu_nomove.dwFlags    ;// scans desitinations

        and [edi], eax              ;// shut off current flag
        .IF ecx & CIRCUIT_NOMOVE    ;// test if should be on
            or [edi], ebx           ;// turn on now
        .ENDIF
        add edi, edx                ;// iterate to next record

        and [edi], eax              ;// shut off current flag
        .IF ecx & CIRCUIT_NOSAVE    ;// test if should be on
            or [edi], ebx           ;// turn on now
        .ENDIF
        add edi, edx                ;// iterate to next record

        and [edi], eax              ;// shut off current flag
        .IF ecx & CIRCUIT_NOEDIT    ;// test if should be on
            or [edi], ebx           ;// turn on now
        .ENDIF
        add edi, edx                ;// iterate to next record

        and [edi], eax              ;// shut off current flag
        .IF ecx & CIRCUIT_NOPINS    ;// test if should be on
            or [edi], ebx           ;// turn on now
        .ENDIF
        add edi, edx                ;// iterate to next record

        and [edi], eax              ;// shut off current flag
        .IF ecx & CIRCUIT_AUTOPLAY  ;// test if should be on
            or [edi], ebx           ;// turn on now
        .ENDIF
        add edi, edx                ;// iterate to next record

    ;// GDI SETTINGS

    lea edi, menu_status.dwFlags    ;// point at new section
    mov ecx, app_settings.show      ;// get new flags to parse

        and [edi], eax              ;// shut off current flag
        .IF ecx & SHOW_STATUS       ;// test if should be on
            or [edi], ebx           ;// turn on now
        .ENDIF
        add edi, edx                ;// iterate to next record

        and [edi], eax              ;// shut off current flag
        .IF ecx & SHOW_CLOCKS       ;// test if should be on
            or [edi], ebx           ;// turn on now
        .ENDIF
        add edi, edx                ;// iterate to next record

        and [edi], eax              ;// shut off current flag
        .IF ecx & SHOW_CHANGING     ;// test if should be on
            or [edi], ebx           ;// turn on now
        .ENDIF

    ;// update is a one of two display

        ;// NOTE: eax is destroyed !!

        mov eax, 'tsaF'
        .IF !(ecx & SHOW_UPDATE_FAST)
            mov eax, 'wolS'
        .ENDIF
        lea edi, sz_text_update[UPDATE_INDICATER] ;// point at the speed indicater
        stosd

    ;// UNDO REDO

        mov edi, unredo_pCurrent
        mov ecx, MF_GRAYED OR MF_BYCOMMAND
        .IF edi != dlist_Head( unredo )
            mov ecx, MF_ENABLED OR MF_BYCOMMAND
        .ENDIF

        invoke EnableMenuItem, hMainMenu, COMMAND_UNDO_MENU, ecx

        mov ecx, MF_GRAYED OR MF_BYCOMMAND
        .IF edi != dlist_Tail( unredo )
            mov ecx, MF_ENABLED OR MF_BYCOMMAND
        .ENDIF

        invoke EnableMenuItem, hMainMenu, COMMAND_REDO_MENU, ecx

    ;// redraw the menu

        invoke DrawMenuBar, hMainWnd

    ;// shut the flag off

        and app_bFlags, NOT APP_SYNC_OPTIONBUTTONS

        ret

mainmenu_SyncOptionButtons  ENDP



.DATA

comment ~ /*

    if abox1 file or app is untiltled
    disable the save button

    if file is NOT dirty, disable save and saveas

    keep track if these have changed so we don't redraw the menu all the time

    best to do a mode table

    there are three states we care about

                who sets            who resets      states
    --------    ---------------     ----------      -----------------------------
    dirty       anyone              New/Save        0   0   0   0   1   1   1   1   dirty
    abox1       file_Load           New/Save/Load   0   0   1   1   0   0   1   1   abox1
    untitled    SetDefaultTitle     Save            0   1   0   1   0   1   0   1   untitled
                                                    -----------------------------
                                        NOSAVE      1   1   1   e   0   1   1   e
                                        NOSAVEAS    1   1   0   r   0   0   0   r
                                                    ------------r---------------r
                                                    0   1   2   3   4   5   6   7
*/ comment ~


    main_menu_save_table LABEL DWORD

        ;// NOSAVE             NOSAVEAS

        dd  MAINMENU_NOSAVE OR MAINMENU_NOSAVEAS    ;// 0
        dd  MAINMENU_NOSAVE OR MAINMENU_NOSAVEAS    ;// 1
        dd  MAINMENU_NOSAVE                         ;// 2
        dd  MAINMENU_NOSAVE OR MAINMENU_NOSAVEAS    ;// 3
        dd  0                                       ;// 4
        dd  MAINMENU_NOSAVE                         ;// 5
        dd  MAINMENU_NOSAVE                         ;// 6
        dd  MAINMENU_NOSAVE                         ;// 7

.CODE

ASSUME_AND_ALIGN
mainmenu_SyncSaveButtons PROC uses ebx

    ;// update the save and savas buttons


    ;// build the new save, savas flags

        mov ecx, MAINMENU_UNTITLED OR MAINMENU_ABOX1
        mov ebx, mainmenu_mode      ;// get the mode
        and ecx, ebx                ;// mask out all but the index
        and ebx, NOT (MAINMENU_NOSAVE OR MAINMENU_NOSAVEAS OR MAINMENU_NOSAVEBMP)   ;// strip out old flags

        mov eax, unredo_last_action ;// are we dirty ?
        .IF eax != unredo_last_save
            .IF master_context.oscZ_dlist_head;//anchor.pHead   ;// are we not empty ?
                add ecx, 4      ;// add 4 more
            .ENDIF
        .ENDIF
        or ebx, main_menu_save_table[ecx*4] ;// mask in new flags

    ;//  check if the circuit is empty and turn off all if so

        .IF !(master_context.oscZ_dlist_head);//anchor.pHead)

            or ebx, MAINMENU_NOSAVE OR MAINMENU_NOSAVEAS OR MAINMENU_NOSAVEBMP

        .ENDIF

    ;// parse the bits

    ;// MAINMENU_NOSAVE

        bt ebx, LOG2(MAINMENU_NOSAVE)   ;// save supposed to be off ?
        jnc N0                          ;// jmp if not

    N0a:bts ebx, LOG2(MAINMENU_NOSAVE_STATE)    ;// save alreasy off ?
        jc N1                                   ;// jump if so
        invoke EnableMenuItem, hMainMenu, COMMAND_SAVE, MF_BYCOMMAND OR MF_GRAYED
        jmp N1

    N0:     ;// save is supposed to be on

    N0b:btr ebx, LOG2(MAINMENU_NOSAVE_STATE)    ;// already on ?
        jnc N1                                  ;// jump if so
        invoke EnableMenuItem, hMainMenu, COMMAND_SAVE, MF_BYCOMMAND OR MF_ENABLED
    N1:

    ;// MAINMENU_SAVEAS

        bt ebx, LOG2(MAINMENU_NOSAVEAS)         ;// saveas supposed to be off ?
        jc N2                                   ;// jump if so

        ;// save as is supposed to be on

    N2a:btr ebx, LOG2(MAINMENU_NOSAVEAS_STATE)  ;// is saveas on now ?
        jnc N3

        invoke EnableMenuItem, hMainMenu, COMMAND_SAVEAS, MF_BYCOMMAND OR MF_ENABLED
        jmp N3

    N2: ;// save as is sopposed to be off
        bts ebx, LOG2(MAINMENU_NOSAVEAS_STATE)  ;// is it alreaddy off ?
        jc N3                                   ;// jump if so
        invoke EnableMenuItem, hMainMenu, COMMAND_SAVEAS, MF_BYCOMMAND OR MF_GRAYED

    N3:

    ;// MAINMENU_SAVEBMP

        bt ebx, LOG2(MAINMENU_NOSAVEBMP)        ;// savebmp supposed to be off ?
        jc N4                                   ;// jump if so

        ;// save bmp is supposed to be on
        btr ebx, LOG2(MAINMENU_NOSAVEBMP_STATE) ;// is saveas on now ?
        jnc N5

        invoke EnableMenuItem, hMainMenu, COMMAND_SAVEBMP, MF_BYCOMMAND OR MF_ENABLED
        jmp N5

    N4: ;// save bmp is sopposed to be off
        bts ebx, LOG2(MAINMENU_NOSAVEBMP_STATE) ;// is it alreaddy off ?
        jc N5                                   ;// jump if so
        invoke EnableMenuItem, hMainMenu, COMMAND_SAVEBMP, MF_BYCOMMAND OR MF_GRAYED

    N5:


    ;// store the new flag

        mov mainmenu_mode, ebx

    ;// shut the flag off

        and app_bFlags, NOT APP_SYNC_SAVEBUTTONS

        ret

mainmenu_SyncSaveButtons ENDP



ASSUME_AND_ALIGN

END


