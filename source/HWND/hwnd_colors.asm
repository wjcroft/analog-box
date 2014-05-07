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
;//     ABox_colors.asm         color setting dialog
;//
OPTION CASEMAP:NONE
.586
.MODEL FLAT

;// TOC:

colors_Initialize PROTO
colors_Show PROTO

colors_Proc PROTO
colors_wm_create_proc PROTO STDCALL hWnd:DWORD, msg:DWORD, wParam:DWORD, lParam:DWORD
colors_wm_destroy_proc PROTO
colors_wm_activate_proc PROTO
colors_wm_close_proc PROTO
colors_wm_command_proc PROTO ;// STDCALL hWnd:DWORD, msg:DWORD, wParam:DWORD, lParam:DWORD
colors_wm_keydown_proc PROTO
colors_wm_setcursor_proc PROTO
colors_enable_controls PROTO STDCALL bEnable:DWORD

scrolls_Initialize PROTO
scrolls_Destroy PROTO
scrolls_UpdateBrushes PROTO
scrolls_UpdatePositions PROTO
scrolls_UpdateColor PROTO
scrolls_wm_scroll_proc PROTO STDCALL hWnd:DWORD, msg:DWORD, wParam:DWORD, lParam:DWORD
scrolls_wm_ctlcolorscrollbar_proc PROTO

list_Initialize PROTO
list_Destroy PROTO
list_LoadColorSet PROTO
list_UpdateColor PROTO
list_wm_measureitem_proc PROTO
list_wm_drawitem_proc PROTO
list_lbn_selchange_proc PROTO



        .NOLIST
        include <Abox.inc>
        .LIST



comment ~ /*

    pieces:

        list_hWnd

            a list box containing all the settable items
            the item data holds a pointer to a COLOR LIST struct

        color_list

            an array of COLOR_LIST records

        color_scrolls

            three scroll bars with some assorted extra info

        example_hWnd

            static control that shows the example circuit

    data flow:

        color_list GETS the color from gdi palette

        color_list SETS the item being edited by the color_scrolls

        color_list UPDATES the example display

        color_scrolls SETS the gdi palette color

        color_scroll UPDATES a color_list item

*/ comment ~

.DATA

    ;// color list defines the color being edited
    ;// a ptr to each record is stored in the list item

        COLOR_LIST  STRUCT

            index   db  0           ;// contains the index of the color being edited
            example db  0           ;// which example to build
            pad     dw  0           ;// alignment pad
            hBrush  dd  0           ;// brush for drawing the rect
            bgr     dd  0           ;// current rgb color value
            string  db 20 dup (0)   ;// contains the text of the item

        COLOR_LIST  ENDS

        color_list  LABEL COLOR_LIST        ;//  0        1         2
        ;//          color id       example ;//  12345678901234567890
        COLOR_LIST  {COLOR_DESK_BACK,,,,,       'Background'        }
        COLOR_LIST  {COLOR_DESK_HOVER,,,,,      'Hover'             }
        COLOR_LIST  {COLOR_DESK_TEXT,,,,,       'Dotted and Clocks' }

        COLOR_LIST  {COLOR_DESK_DEFAULT,,,,,    'Default signal'    }
        COLOR_LIST  {COLOR_DESK_FREQUENCY,,,,,  'Frequency signal'  }
        COLOR_LIST  {COLOR_DESK_MIDI,,,,,       'Midi signal'       }
        COLOR_LIST  {COLOR_DESK_LOGIC,,,,,      'Logic signal'      }
        COLOR_LIST  {COLOR_DESK_SPECTRAL,,,,,   'Spectrum signal'   }
        COLOR_LIST  {COLOR_DESK_STREAM,,,,,     'Stream signal'     }

        COLOR_LIST  {COLOR_DESK_SELECTED,,,,,   'Selected object'   }
        COLOR_LIST  {COLOR_DESK_LOCKED,,,,,     'Locked object'     }

        COLOR_LIST  {COLOR_OSC_TEXT,,,,,        'Object Text'       }
        COLOR_LIST  {COLOR_OSC_1,,,,,           'Object Control 1'  }
        COLOR_LIST  {COLOR_OSC_2,,,,,           'Object Control 2'  }

        COLOR_LIST  {COLOR_GROUP_CONTROLS+1,,,,,'Controls (front)'  }
        COLOR_LIST  {COLOR_GROUP_CONTROLS,,,,,  'Controls (back)'   }

        COLOR_LIST  {COLOR_GROUP_GENERATORS+1,,,,,'Generators (front)'}
        COLOR_LIST  {COLOR_GROUP_GENERATORS,,,,,'Generators (back)' }

        COLOR_LIST  {COLOR_GROUP_ROUTERS+1,,,,, 'Routers (front)'   }
        COLOR_LIST  {COLOR_GROUP_ROUTERS,,,,,   'Routers (back)'    }

        COLOR_LIST  {COLOR_GROUP_PROCESSORS+1,,,,,'Processors (front)'}
        COLOR_LIST  {COLOR_GROUP_PROCESSORS,,,,,'Processors (back)' }

        COLOR_LIST  {COLOR_GROUP_DEVICES+1,,,,, 'Devices (front)'   }
        COLOR_LIST  {COLOR_GROUP_DEVICES,,,,,   'Devices (back)'    }

        COLOR_LIST  {COLOR_GROUP_DISPLAYS+1,,,,,'Displays (front)'  }
        COLOR_LIST  {COLOR_GROUP_DISPLAYS,,,,,  'Displays (back)'   }

        color_list_terminator   dd  0

    ;// window handles

        colors_hWnd     dd 0    ;// hWnd for colors box
        colors_Atom     dd 0    ;// hWnd for colors box

        list_hWnd   dd  0   ;// hWnd of color list
        list_cursel dd  0
        list_curptr dd  0

        static_hWnd dd  0   ;// handle of the static example box

    ;// GDI and placement data

        COLORS_STYLE        TEXTEQU <POPUP_STYLE + WS_VISIBLE>
        COLORS_STYLE_EX     TEXTEQU <POPUP_STYLE_EX>

        colors_curPos   POINT {0,0}     ;// location for display
        colors_curSiz   POINT {128,128} ;// size of the display

    ;// helpful tips

        colors_hWnd_status  dd  0   ;//
        colors_status_ptext dd  0

        sz_color_help   db  'Select a color and use the HSV sliders to adjust.',0


comment ~ /*

    there is one scrolls of scroll bars
    there is a current selection
    there is a list item for that selection

    cursel_ind  dd  0   ;// list index of current selection


    when user changes list selection

        the scrolls need set at that color
        the example screen needs to be updated

    when user IS changing a color

        the example color needs to change
        the example screen should keep track

    when user has CHANGED a color

        the rest of abox should be updated


*/ comment ~


    ;// colors_scrolls
    ;//
    ;// there are three, each is assinged this special struct
    ;// a pointer to this struct is assigned in GWL_USERDATA

        SCROLLINFO_EX STRUCT
        ;// scrollinfo
            dwSize      dd  SIZEOF SCROLLINFO
            dwMask      dd      SIF_PAGE + SIF_RANGE
            dwMin       SDWORD  0
            dwMax       SDWORD  255+16-1    ;// page size plus max value minus 1, lame
            dwPage      dd      16
            dwPos       SDWORD  0
            dwTrackPos  dd      0
        ;// extra info we need
            hBrush      dd      0   ;// hBrush for filling the background
            hWnd        dd      0   ;// window handle
        SCROLLINFO_EX   ENDS

        color_scroll LABEL SCROLLINFO_EX

        H_scroll    SCROLLINFO_EX   {}
        S_scroll    SCROLLINFO_EX   {}
        V_scroll    SCROLLINFO_EX   {}

        scrolls_bgr dd  0   ;// current rgb value we're working with

    ;// current prset selection

        colors_current_preset   dd  0   ;// have to scan to find the correct one (wm_create_proc)
        colors_bSet             dd  0   ;// tells us if user has hit the set button

    ;// strings

        colors_szColors db 'COLORS', 0

.CODE


;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;////
;////
;////       A P P   L E V E L   F U N C T I O N S
;////

;////////////////////////////////////////////////////////////////////
;//
;//
;//     colors_Initialize
;//
ASSUME_AND_ALIGN
colors_Initialize PROC

        LOCAL rect:RECT
        LOCAL wndClass:WNDCLASSEXA
    ;//
    ;// set up the wndClass struct
    ;//
        xor eax, eax
        mov wndClass.cbSize, SIZEOF WNDCLASSEXA
        mov wndClass.style, CS_PARENTDC + CS_HREDRAW + CS_VREDRAW
        mov wndClass.lpfnWndProc, OFFSET colors_Proc
        mov wndClass.cbClsExtra, eax
        mov wndClass.cbWndExtra, eax
        mov ecx, hInstance
        mov wndClass.hInstance, ecx
        mov  wndClass.hIcon, eax
        mov  wndClass.hIconSm, eax
        mov  wndClass.hCursor, eax
        mov  wndClass.hbrBackground, COLOR_BTNFACE + 1
        mov  wndClass.lpszMenuName, eax
        mov  wndClass.lpszClassName, OFFSET colors_szColors

        invoke RegisterClassExA, ADDR wndClass
        and eax, 0FFFFh         ;// atoms are words
        mov colors_Atom, eax

    ;// calculate the correct size

        point_Get popup_COLORS.siz
        mov rect.left, 0
        mov rect.top, 0
        point_SetBR rect
        invoke AdjustWindowRectEx, ADDR rect, COLORS_STYLE, 0, COLORS_STYLE_EX

        point_GetBR rect
        point_SubTL rect
        add edx, POPUP_HELP_HEIGHT
        point_SetBR rect

    ;// create the hidden window at the main wnd's client origon

        invoke ClientToScreen, hMainWnd, OFFSET colors_curPos

        invoke CreateWindowExA,
            COLORS_STYLE_EX, colors_Atom, 0, ;//ADDR colors_szSettings,
            COLORS_STYLE,
            colors_curPos.x, colors_curPos.y,
            rect.right, rect.bottom,
            0, 0, hInstance, 0

    ;// that's it

        ret

colors_Initialize ENDP
;//
;//     colors_Initialize
;//
;//
;////////////////////////////////////////////////////////////////////







;////////////////////////////////////////////////////////////////////
;//
;//     colors_Show
;//
ASSUME_AND_ALIGN
colors_Show PROC

    ;// make sure we're built

        .IF !colors_hWnd
            invoke colors_Initialize
        .ENDIF
        mov colors_status_ptext, 0
        invoke ShowWindow, colors_hWnd, SW_RESTORE

    ;// and take care of xmouse

        .IF app_xmouse

            point_Get colors_curPos
            add eax, 8
            add edx, 8
            invoke SetCursorPos, eax, edx

        .ENDIF

    ;// tell the app we're on and split

        or app_DlgFlags, DLG_COLORS

        ret

colors_Show ENDP
;//
;//     colors_Show
;//
;////////////////////////////////////////////////////////////////////


;////
;////
;////       A P P   L E V E L   F U N C T I O N S
;////
;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////








;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;////
;////
;////       C O L O R   W I N D O W   F U N C T I O N S
;////

;/////////////////////////////////////////////////////////////////////////
;//
;//     colors_Proc
;//

ASSUME_AND_ALIGN
colors_Proc PROC

    mov eax, WP_MSG

    ;// color window handlers

    HANDLE_WM WM_CREATE,        colors_wm_create_proc
    HANDLE_WM WM_DESTROY,       colors_wm_destroy_proc

    HANDLE_WM WM_ACTIVATE,      colors_wm_activate_proc
    HANDLE_WM WM_CLOSE,         colors_wm_close_proc

    HANDLE_WM WM_COMMAND,       colors_wm_command_proc
    HANDLE_WM WM_KEYDOWN,       colors_wm_keydown_proc

    ;// helpful text

    HANDLE_WM WM_SETCURSOR,     colors_wm_setcursor_proc

    ;// scroll bar handlers

    HANDLE_WM WM_VSCROLL,           scrolls_wm_scroll_proc
    HANDLE_WM WM_HSCROLL,           scrolls_wm_scroll_proc
    HANDLE_WM WM_CTLCOLORSCROLLBAR, scrolls_wm_ctlcolorscrollbar_proc

    ;// color list handlers

    HANDLE_WM WM_MEASUREITEM,   list_wm_measureitem_proc
    HANDLE_WM WM_DRAWITEM,      list_wm_drawitem_proc

    ;// default processing

    jmp DefWindowProcA

colors_Proc ENDP

;//
;//     colors_Proc
;//
;/////////////////////////////////////////////////////////////////////////


;///////////////////////////////////////////////////////////////////////////
;//
;//     WM_CREATE
;//
ASSUME_AND_ALIGN
colors_wm_create_proc PROC STDCALL PRIVATE uses esi ebx edi hWnd:DWORD, msg:DWORD, wParam:DWORD, lParam:DWORD

    ;// store the hwnd

        mov eax, hWnd
        mov colors_hWnd, eax

    ;// create the status bar

        invoke CreateWindowExA, 0, OFFSET szStatic,
            0,  WS_VISIBLE OR WS_CHILD OR SS_NOTIFY,
            0,  0, popup_COLORS.siz.x   ,   POPUP_HELP_HEIGHT,
            hWnd,   0,      hInstance, 0
        mov colors_hWnd_status, eax
        invoke PostMessageA, eax, WM_SETFONT, hFont_help, 1

    ;// build the controls

        invoke popup_BuildControls, hWnd, OFFSET popup_COLORS, OFFSET sz_color_help, 0  ;// use help

    ;// intialize the list box

        invoke list_Initialize
        invoke list_LoadColorSet

    ;// initialize the scroll scrollss

        invoke scrolls_Initialize
        invoke scrolls_UpdateColor

    ;// get the static box hWnd

        invoke GetDlgItem, colors_hWnd, IDC_EXAMPLE
        mov static_hWnd, eax

    ;// set up the dialog to default state

        ;// the background button needs pressed
        ;// invoke CheckDlgButton, hWnd, IDC_COL_BACKGROUND, BST_CHECKED

        ;// the controls group button needs pushed
        ;// invoke CheckDlgButton, hWnd, IDC_OBJ_CONTROLS, BST_CHECKED

    ;// figure out which preset we're on

        lea edi, app_settings.presets
        xor ebx, ebx    ;// ebx count

        .REPEAT

        push edi
            lea esi, app_settings.colors
            mov ecx, ( SIZEOF GDI_PALETTE ) / 4
            repe cmpsd
        pop edi
            jz @1   ;// jump if we found it
            add edi, SIZEOF GDI_PALETTE
            inc ebx

        .UNTIL ebx > 4

        ;// if we hit this, we're not using a preset
        jmp @2

    @1: .IF ebx == 4
            mov ebx, IDC_PRESET_0
        .ELSE
            add ebx, IDC_PRESET_1
        .ENDIF
        mov colors_current_preset, ebx

        invoke CheckDlgButton, hWnd, ebx, BST_CHECKED

    ;// return 1

    @2: mov eax, 1
        ret

colors_wm_create_proc ENDP
;//
;//     WM_CREATE
;//
;///////////////////////////////////////////////////////////////////////////


;///////////////////////////////////////////////////////////////////////////
;//
;//     WM_DESTROY
;//
ASSUME_AND_ALIGN
colors_wm_destroy_proc PROC PRIVATE ;// STDCALL PRIVATE hWnd:DWORD, msg:DWORD, wParam:DWORD, lParam:DWORD

    ;// remove the brushes we created

    invoke list_Destroy
    invoke scrolls_Destroy

    xor eax, eax

    ret 10h

colors_wm_destroy_proc ENDP
;//
;//     WM_DESTROY
;//
;///////////////////////////////////////////////////////////////////////////


;///////////////////////////////////////////////////////////////////////////
;//
;//     WM_ACTIVATE
;//
ASSUME_AND_ALIGN
colors_wm_activate_proc PROC PRIVATE ;// STDCALL PRIVATE hWnd:DWORD, msg:DWORD, wParam:DWORD, lParam:DWORD

    test WP_WPARAM, 0FFFFh
    jz colors_wm_close_proc
    xor eax, eax
    ret 10h

colors_wm_activate_proc ENDP
;//
;//     WM_ACTIVATE
;//
;///////////////////////////////////////////////////////////////////////////


;///////////////////////////////////////////////////////////////////////////
;//
;//     WM_CLOSE
;//
ASSUME_AND_ALIGN
colors_wm_close_proc PROC PRIVATE ;// STDCALL PRIVATE hWnd:DWORD, msg:DWORD, wParam:DWORD, lParam:DWORD

    ;// make sure we don't close with the buttons disabled
    .IF colors_bSet
        invoke colors_enable_controls, colors_bSet
    .ENDIF
    mov eax, WP_HWND
    invoke ShowWindow, eax, SW_HIDE

    and app_DlgFlags, NOT DLG_COLORS

    xor eax, eax

    ret 10h

colors_wm_close_proc ENDP
;//
;//     WM_CLOSE
;//
;///////////////////////////////////////////////////////////////////////////




;///////////////////////////////////////////////////////////////////////////
;//
;// WM_COMMAND  wNotifyCode = HIWORD(wParam)    ;// notification code
;//             wID = LOWORD(wParam)            ;// item, control, or accelerator identifier
;//             hwndCtl = (HWND) lParam         ;// handle of control ASSUME_AND_ALIGN
;//
colors_wm_command_proc PROC ;// STDCALL PRIVATE hWnd:DWORD, msg:DWORD, wParam:DWORD, lParam:DWORD

    mov eax, WP_WPARAM
    shr eax, 16

    cmp eax, LBN_SELCHANGE
    je list_lbn_selchange_proc

    .IF eax == BN_CLICKED

        ;// BN_CLICKED  idButton = (int) LOWORD(wParam) ;// identifier of button
        ;//             hwndButton = (HWND) lParam      ;// handle of button

        mov eax, WP_WPARAM
        and eax, 0FFFFh

    ;// check for a preset being hit

        .IF eax >= IDC_PRESET_0 && eax <= IDC_PRESET_4

            mov colors_current_preset, eax      ;// save now
            sub eax, IDC_PRESET_0               ;// determine the index

            .IF colors_bSet ;// was the set button pushed ?

                dec eax
                invoke gdi_SaveColorSet
                invoke colors_enable_controls, colors_bSet

            .ELSE   ;// nope, so we want to load a color set

                invoke gdi_LoadColorSet         ;// load the preset
                invoke list_LoadColorSet        ;// tell the list box to do the same
                invoke scrolls_UpdateColor      ;// update the scroll bars

                invoke InvalidateRect, colors_hWnd, 0, 1;// redraw this entire window
                invoke InvalidateRect, static_hWnd, 0, 0
                invoke InvalidateRect, hMainWnd, 0, 1   ;// redraw the main window

                .IF app_settings.show & SHOW_STATUS
                    or last_status_mode, -1
                    invoke status_Update
                .ENDIF

            .ENDIF

        ;// check for the set button being hit
        .ELSEIF eax == IDC_PRESET_SET

            invoke colors_enable_controls, colors_bSet
            ;// colors_bSet must be correct

        .ENDIF

        invoke SetFocus, colors_hWnd

    .ENDIF

;// all_done:

    ;// tha's it
    xor eax, eax

    ret 10h

colors_wm_command_proc ENDP
;//
;// WM_COMMAND
;//
;///////////////////////////////////////////////////////////////////////////



;/////////////////////////////////////////////////////////////////////////
;//
;//
;//     WM_KEYDOWN
;//
ASSUME_AND_ALIGN
colors_wm_keydown_proc PROC PRIVATE

    mov eax, WP_WPARAM
    cmp eax, VK_ESCAPE
    jz @F
    jmp DefWindowProcA
@@: invoke SetFocus, hMainWnd

    xor eax, eax
    ret 10h

colors_wm_keydown_proc ENDP
;//
;//     WM_KEYDOWN
;//
;//
;/////////////////////////////////////////////////////////////////////////


;/////////////////////////////////////////////////////////////////////////
;//
;//
;//     WM_SETCURSOR
;//
ASSUME_AND_ALIGN
colors_wm_setcursor_proc PROC

        mov eax, WP_WPARAM

        invoke GetWindowLongA, eax, GWL_USERDATA    ;// get the base class pointer

    ;// is there a message to display ?

        or eax, eax
        jz no_displayable_text

        cmp eax, OFFSET popup_help_first
        jb no_displayable_text
        cmp eax, OFFSET popup_help_last
        ja no_displayable_text

        cmp eax, colors_status_ptext    ;// same as previous ?
        je all_done

            mov colors_status_ptext, eax    ;// set the new value
            invoke SetWindowTextA, colors_hWnd_status, eax

            jmp all_done

    no_displayable_text:

        cmp colors_status_ptext, 0  ;// is there text already on ??
        je all_done

        xor eax, eax
        pushd eax
        mov colors_status_ptext, eax
        invoke SetWindowTextA, colors_hWnd_status, esp
        pop edx

    all_done:

        xor eax, eax    ;// return zero
        ret 10h         ;// exit

colors_wm_setcursor_proc ENDP
;//
;//
;//     WM_SETCURSOR
;//
;/////////////////////////////////////////////////////////////////////////











;//////////////////////////////////////////////////////////////////////////////
;//
;//                                 action: colors_hWnd[].enable/disable
;//     colors_enable_controls              set colors_bSet appropriately
;//

.DATA

    sz_cancel   db  'cancel',0
;// sz_set      db  'set',0

.CODE

PROLOGUE_OFF
ASSUME_AND_ALIGN
colors_enable_controls PROC STDCALL uses ebx, bEnable:DWORD

    ;// this en/dis ables all controls except the the set buttons

        push ebx

    ;// stack:
    ;// ebx ret bEnable
    ;// 00  04  08

        st_bEnable TEXTEQU <(DWORD PTR [esp+8])>

        DEBUG_IF <st_bEnable && st_bEnable !!= SW_SHOW> ;// passed a wrong value

    ;// scan through all the child windows

        invoke GetWindow, colors_hWnd, GW_CHILD
    @@: .IF eax
            mov ebx, eax
            invoke GetWindowLongA, ebx, GWL_ID
            .IF eax < IDC_PRESET_1 || eax > IDC_PRESET_SET
                ;// invoke EnableWindow, ebx, st_bEnable
                invoke ShowWindow, ebx, st_bEnable
            .ENDIF
            invoke GetWindow, ebx, GW_HWNDNEXT
            jmp @B
        .ENDIF

    ;// turn on or off the set flag


        xor eax, eax
        .IF !st_bEnable
            mov eax, SW_SHOW    ;// set the command for next time
        .ENDIF
        mov colors_bSet, eax

    ;// set the 'set' button text correctly

        .IF eax
            lea ebx, sz_cancel
        .ELSE
            lea ebx, sz_set
        .ENDIF

        invoke GetDlgItem, colors_hWnd, IDC_PRESET_SET
        WINDOW eax,WM_SETTEXT,0,ebx

    ;// that's it

        pop ebx

        st_bEnable TEXTEQU <>

        ret 4

colors_enable_controls ENDP
PROLOGUE_ON
;//
;//     colors_enable_controls
;//
;//////////////////////////////////////////////////////////////////////////////







;////
;////
;////       C O L O R   W I N D O W   F U N C T I O N S
;////
;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////



;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;////
;////
;////       S C R O L L   B A R   H A N D L E R S
;////



;////////////////////////////////////////////////////////////////////
;//
;//
;//     scrolls_Initialize
;//
ASSUME_AND_ALIGN
scrolls_Initialize PROC

    lea esi, color_scroll
    ASSUME esi:PTR SCROLLINFO_EX    ;// esi must point at the scrolls to initialize

    mov ebx, IDC_SCROLL_H       ;// ebx must be the starting command ID

    .REPEAT

        invoke GetDlgItem, colors_hWnd, ebx         ;// get the hwnd
        mov [esi].hWnd, eax                         ;// store in struct
        invoke SetWindowLongA, eax, GWL_USERDATA, esi;// set the item pointer
        invoke SetScrollInfo, [esi].hWnd, SB_CTL, esi, 0    ;// set the range and page
        mov [esi].dwMask, SIF_POS                   ;// from now on, we only need the position

        add esi, SIZEOF SCROLLINFO_EX   ;// iterate esi
        inc ebx                         ;// bump the command id

    .UNTIL ebx > IDC_SCROLL_V

    ret

scrolls_Initialize ENDP
;//
;//     scrolls_Initialize
;//
;////////////////////////////////////////////////////////////////////

;////////////////////////////////////////////////////////////////////
;//
;//
;//     scrolls_Destroy
;//
ASSUME_AND_ALIGN
scrolls_Destroy PROC

    .IF H_scroll.hBrush
        invoke DeleteObject, H_scroll.hBrush
        DEBUG_IF <!!eax>
    .ENDIF
    .IF S_scroll.hBrush
        invoke DeleteObject, S_scroll.hBrush
        DEBUG_IF <!!eax>
    .ENDIF
    .IF V_scroll.hBrush
        invoke DeleteObject, V_scroll.hBrush
        DEBUG_IF <!!eax>
    .ENDIF

    ret

scrolls_Destroy ENDP
;//
;//     scrolls_Destroy
;//
;////////////////////////////////////////////////////////////////////




;////////////////////////////////////////////////////////////////////
;//
;//                             action: HSV_scrolls.dwPos --> scrolls_bgr
;//     scrolls_UpdateBrushes                             --> HSV_scroll.hBrush[]
;//
ASSUME_AND_ALIGN
scrolls_UpdateBrushes PROC  uses ebx

    ;// call this when one of the scroll bars changes value
    ;//
    ;// our job here is to make sure the brushes are correct
    ;// we assume that dwPos is correct for all three scroll bars
    ;//
    ;// build the color using the scroll positions,
    ;// alloacte three brushes as we go

    ;// hue
    ;// H is 00HHffff

        .IF H_scroll.hBrush
            invoke DeleteObject, H_scroll.hBrush
            DEBUG_IF <!!eax>
        .ENDIF

        mov ebx, H_scroll.dwPos
        shl ebx, 16
        or ebx, 0FFFFh
        mov eax, ebx
        invoke gdi_hsv_to_bgr
        invoke CreateSolidBrush, eax
        mov H_scroll.hBrush, eax

    ;// saturation
    ;// S is 00HHSSff

        .IF S_scroll.hBrush
            invoke DeleteObject, S_scroll.hBrush
            DEBUG_IF <!!eax>
        .ENDIF

        mov bh, BYTE PTR S_scroll.dwPos
        mov eax, ebx
        invoke gdi_hsv_to_bgr
        invoke CreateSolidBrush, eax
        mov S_scroll.hBrush, eax

    ;// brightness
    ;// V is 00HHSSVV

        .IF V_scroll.hBrush
            invoke DeleteObject, V_scroll.hBrush
            DEBUG_IF <!!eax>
        .ENDIF

        mov bl, BYTE PTR V_scroll.dwPos
        mov eax, ebx
        invoke gdi_hsv_to_bgr
        mov scrolls_bgr, eax    ;// save it now
        invoke CreateSolidBrush, eax
        mov V_scroll.hBrush, eax

    ;// make sure what ever calls this invalidates the scrolls

        ret

scrolls_UpdateBrushes ENDP
;//
;//
;//     scrolls_UpdateBrushes
;//
;////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////
;//
;//                             action: scrolls_rgb --> color_list.hsv
;//     scrolls_UpdatePositions                     --> all three scroll positions
;//                                                 --> scrolls_UpdateBrushes
ASSUME_AND_ALIGN
scrolls_UpdatePositions PROC

    ;// call this when editing a new color
    ;// scrolls_bgr must be set correctly

    ;// our job is to determine and set the scroll bar positions
    ;// we call update brushes automatically

    mov eax, scrolls_bgr    ;// load the color
    invoke gdi_bgr_to_hsv   ;// convert bgr into hsv
    mov edx, eax            ;// store for safe keeping

    ;// value
    and eax, 0FFh
    mov V_scroll.dwPos, eax

    ;// saturation
    mov eax, edx
    shr eax, 8
    and eax, 0FFh
    mov S_scroll.dwPos, eax

    ;// hue
    shr edx, 16
    mov H_scroll.dwPos, edx

    ;// call update brush
    invoke scrolls_UpdateBrushes

    ;// set all three with instructions to redraw
    invoke SetScrollInfo, H_scroll.hWnd, SB_CTL, OFFSET H_scroll, 1
    invoke SetScrollInfo, S_scroll.hWnd, SB_CTL, OFFSET S_scroll, 1
    invoke SetScrollInfo, V_scroll.hWnd, SB_CTL, OFFSET V_scroll, 1

    ret

scrolls_UpdatePositions ENDP
;//
;//
;//     scrolls_UpdatePositions
;//
;////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////
;//
;//                             action: list.cursel --> scrolls_rgb
;//     scrolls_UpdateColor                         --> scrolls_UpdatePositions
;//
ASSUME_AND_ALIGN
scrolls_UpdateColor PROC

    ;// this updates all three scrolls
    ;// call when cursel changes

    ;// set scrolls_bgr using the current selection

        mov eax, list_curptr
        ASSUME eax:PTR COLOR_LIST
        mov eax, [eax].bgr
        mov scrolls_bgr, eax

    ;// set the positions on the scroll bars

        invoke scrolls_UpdatePositions

    ;// that's it

        ret

scrolls_UpdateColor ENDP
;//
;//
;//     scrolls_UpdateColor
;//
;////////////////////////////////////////////////////////////////////


;///////////////////////////////////////////////////////////////////////////
;//
;// WM_SCROLL   nScrollCode = (int) LOWORD(wParam)  ;// scroll bar value
;//             nPos = (short int) HIWORD(wParam)   ;// scroll box position
;//             hwndScrollBar = (HWND) lParam       ;// handle of scroll bar

ASSUME_AND_ALIGN
scrolls_wm_scroll_proc PROC STDCALL PRIVATE USES esi edi ebx hWnd:DWORD, msg:DWORD, wParam:DWORD, lParam:DWORD

    ;// something's happening with a scroll bars
    ;// our first job is make sure the scroll bar itself gets updated
    ;// next we make sure the scrolls get updated

    ;// if a scrollbar changes, then we update the scrolls
    ;// if a scroll bar is done being changed, then we set the color or group

    ;// so we need to keep track of:
    ;//
    ;//     the scrollinfo stuct we're working with
    ;//     the scrolls index we're working with

comment ~ /*
SB_LINEUP          equ 0    ;// GetInfo(scroll_info) range_check SetInfo updateBrushes(scrolls)
SB_LINEDOWN        equ 1    ;// GetInfo(scroll_info) range_check SetInfo updateBrushes(scrolls)
SB_PAGEUP          equ 2    ;// GetInfo(scroll_info) range_check SetInfo updateBrushes(scrolls)
SB_PAGEDOWN        equ 3    ;// GetInfo(scroll_info) range_check SetInfo updateBrushes(scrolls)

SB_THUMBPOSITION   equ 4    ;// npos ->(scroll_info)             SetInfo updateBrushes(scrolls)
SB_THUMBTRACK      equ 5    ;// npos ->(scroll_info)                     updateBrushes(scrolls)
SB_TOP             equ 6    ;// 0    ->(scroll_info)             SetInfo updateBrushes(scrolls)
SB_BOTTOM          equ 7    ;// 255  ->(scroll_info)             SetInfo updateBrushes(scrolls)

SB_ENDSCROLL       equ 8    ;// must call appropriate gdi_SetColor or set Group functions
                            ;// ID=0 ? call gdi_SetColor
                            ;// ID>0 ? call gdi_SetGroup
*/ comment ~



    mov ebx, wParam     ;// load the command
    and ebx, 0FFFFh     ;// strip out the xtra

    .IF ebx < SB_ENDSCROLL

        ;// determine which scroll we're working with

            invoke GetWindowLongA, lParam, GWL_USERDATA ;// get the pointer
            mov edi, eax
            ASSUME edi:PTR SCROLLINFO_EX        ;// edi points at the scroll we're setting

        ;// determine which scroll command we're handling

        .IF ebx < SB_THUMBPOSITION

    get_info:

            invoke GetScrollInfo, lParam, SB_CTL, edi

            .IF     ebx == SB_LINEUP
                dec [edi].dwPos
            .ELSEIF ebx == SB_LINEDOWN
                inc [edi].dwPos
            .ELSEIF ebx == SB_PAGEUP
                sub [edi].dwPos, 16
            .ELSE   ;// IF ebx == SB_DOWN
                add [edi].dwPos, 16
            .ENDIF

    range_check:

            .IF [edi].dwPos < 0
                mov [edi].dwPos, 0
            .ELSEIF [edi].dwPos > 255
                mov [edi].dwPos, 255
            .ENDIF

        .ELSEIF ebx == SB_THUMBPOSITION || ebx == SB_THUMBTRACK

            movsx eax, WORD PTR wParam+2    ;// get npos
            mov [edi].dwPos, eax

        .ELSEIF ebx == SB_TOP

            mov [edi].dwPos, 255

        .ELSE ;// IF ebx == SB_BOTTOM

            mov [edi].dwPos, 0

        .ENDIF

    set_info:

        invoke SetScrollInfo, lParam, SB_CTL, edi, 0    ;// don't redraw just yet

    update_brushes:

        invoke scrolls_UpdateBrushes

    force_redraw:

        invoke InvalidateRect, H_scroll.hWnd,0,1
        invoke InvalidateRect, S_scroll.hWnd,0,1
        invoke InvalidateRect, V_scroll.hWnd,0,1
        invoke InvalidateRect, static_hWnd, 0, 0


        mov esi, list_curptr        ;// get the current selection
        ASSUME esi:PTR COLOR_LIST
        movzx eax, [esi].index      ;// load the index we want to set
        mov ecx, scrolls_bgr        ;// load the color from scroll
        mov [esi].bgr, ecx          ;// store color in struct

        invoke gdi_SetThisColor     ;// tell gdi to set the color
        invoke list_UpdateColor     ;// tell list box to update color

    .ELSE   ;// edx == SB_ENDSCROLL

        ;// then we shut off any preset button that might have been on

        .IF colors_current_preset
            invoke CheckDlgButton, colors_hWnd, colors_current_preset, BST_UNCHECKED
            mov colors_current_preset, 0
        .ENDIF

        invoke InvalidateRect, hMainWnd, 0, 1   ;// redraw entire window

    .ENDIF


    xor eax, eax

    ret

scrolls_wm_scroll_proc ENDP
;//
;// WM_SCROLL
;//
;///////////////////////////////////////////////////////////////////////////






;///////////////////////////////////////////////////////////////////////////
;//
;//     WM_CTLCOLORSCROLLBAR
;//
ASSUME_AND_ALIGN
scrolls_wm_ctlcolorscrollbar_proc PROC PRIVATE ;// STDCALL hWnd:DWORD, msg:DWORD, wParam:DWORD, lParam:DWORD

    mov eax, WP_LPARAM                          ;// get wparam
    invoke GetWindowLongA, eax, GWL_USERDATA    ;// get the pointer to the scrollinfo
    ASSUME eax:PTR SCROLLINFO_EX
    mov eax, [eax].hBrush   ;// get the brush
    ret 10h                 ;// that's it

scrolls_wm_ctlcolorscrollbar_proc ENDP
;//
;//     WM_CTLCOLORSCROLLBAR
;//
;///////////////////////////////////////////////////////////////////////////



;////
;////       S C R O L L   B A R   H A N D L E R S
;////
;////
;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////


















;////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////
;////
;////
;////       C O L O R   L I S T   F U N C T I O N S
;////


;////////////////////////////////////////////////////////////////////
;//
;//
;//     list_Initialize
;//
ASSUME_AND_ALIGN
list_Initialize PROC    uses ebx esi

    ;// set all the strings
    ;// create all the brushes


    ;// get the list box handle

        invoke GetDlgItem, colors_hWnd, IDC_COLOR_LIST
        mov list_hWnd, eax
        mov ebx, eax

    ;// intialize all the items and strings

        lea esi, color_list
        ASSUME esi:PTR COLOR_LIST

        mov list_curptr, esi

    .REPEAT

        LISTBOX ebx, LB_ADDSTRING, 0, esi   ;// add the string
        add esi, SIZEOF COLOR_LIST  ;// itertate

    .UNTIL ![esi].index

    ;// set the default selection

        LISTBOX list_hWnd, LB_SETCURSEL, 0, 0

    ;// that's it

        ret

list_Initialize ENDP
;//
;//
;//     list_Initialize
;//
;////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////
;//
;//
;//     list_Destroy
;//
ASSUME_AND_ALIGN
list_Destroy PROC   uses esi

    lea esi, color_list
    ASSUME esi:PTR COLOR_LIST

    .REPEAT

        xor eax, eax
        or eax, [esi].hBrush
        .IF !ZERO?
            invoke DeleteObject, eax
            DEBUG_IF <!!eax>
        .ENDIF

        add esi, SIZEOF COLOR_LIST  ;// itertate

    .UNTIL ![esi].index

    ret

list_Destroy ENDP
;//
;//     list_Destroy
;//
;//
;////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////
;//
;//
;//     list_LoadColorSet
;//
ASSUME_AND_ALIGN
list_LoadColorSet PROC uses esi

    lea esi, color_list
    ASSUME esi:PTR COLOR_LIST

    .REPEAT

        movzx eax, [esi].index      ;// get the color index we want
        invoke gdi_GetThisColor     ;// ask gdi to get it for us
        mov [esi].bgr, eax          ;// store in struct

        invoke list_UpdateColor     ;// tell list to build the brush

        add esi, SIZEOF COLOR_LIST  ;// itertate

    .UNTIL ![esi].index

    ret

list_LoadColorSet ENDP
;//
;//
;//     list_LoadColorSet
;//
;////////////////////////////////////////////////////////////////////





;////////////////////////////////////////////////////////////////////
;//
;//                          action: color_list.rgb --> color_list.hBrush
;//     list_UpdateColor             invalidate the item rect
;//
ASSUME_AND_ALIGN
list_UpdateColor    PROC

        ASSUME esi:PTR COLOR_LIST   ;// esi must be the color we want to set

    ;// destroy current brush, if any

        xor eax, eax
        or eax, [esi].hBrush
        .IF !ZERO?
            invoke DeleteObject, eax
            DEBUG_IF <!!eax>
        .ENDIF

    ;// create the new brush

        invoke CreateSolidBrush, [esi].bgr
        mov [esi].hBrush, eax

    ;// invalidate the color item

    push esi

        sub esp, SIZEOF RECT

        sub esi, OFFSET color_list
        shr esi, LOG2(SIZEOF COLOR_LIST)
        LISTBOX list_hWnd, LB_GETITEMRECT, esi, esp
        .IF eax != LB_ERR

            mov eax, esp
            invoke InvalidateRect, list_hWnd, eax, 0

        .ENDIF

        add esp, SIZEOF RECT

    pop esi

    ;// that's it

        ret

list_UpdateColor ENDP
;//
;//     list_UpdateColor
;//                                 action: color_scroll -> color_list
;//
;////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////
;//
;//
;//     WM_MEASUREITEM
;//

ASSUME_AND_ALIGN
list_wm_measureitem_proc    PROC        ;// STDCALL hWnd, msg, wParam, lParam

        mov ecx, WP_LPARAM
        ASSUME ecx:PTR MEASUREITEMSTRUCT

        sub esp, SIZEOF RECT

        mov ecx, list_hWnd
        invoke GetClientRect,ecx, esp
        add esp, 12
        pop edx

        mov ecx, WP_LPARAM
        mov [ecx].itemHeight, FONT_POPUP
        mov [ecx].itemWidth, edx

    ;// return true

        or eax, 1
        ret 10h

list_wm_measureitem_proc ENDP
;//
;//
;//     WM_MEASUREITEM
;//
;////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////
;//
;// WM_DRAWITEM
;//
;// idCtl = (UINT) wParam;             // control identifier
;// lpdis = (LPDRAWITEMSTRUCT) lParam; // item-drawing information
;//
ASSUME_AND_ALIGN
list_wm_drawitem_proc PROC  ;// STDCALL hWnd, msg, wParam, lParam


    ;// set correct back color  select and focus
    ;// draw appropriate text
    ;// draw correct sample color

        xchg ebx, WP_LPARAM ;// load and store
        ASSUME ebx:PTR DRAWITEMSTRUCT

    ;// make sure we're drawing on the correct control

        mov eax, WP_WPARAM
        CMPJMP eax, IDC_EXAMPLE, je draw_static_example
        CMPJMP eax, IDC_COLOR_LIST, je draw_list_box
        jmp all_done_ebx

    draw_static_example:

    ;// make sure we're drawing on the correct control

        push esi
        push edi

    ;// we draw 32 sections based on the current spectrum

        ;// initialize a reverse iterator for the colors

        mov esi, list_curptr                ;// get the current selection
        movzx esi, (COLOR_LIST PTR [esi]).index ;// determine the palette group
        and esi, 0E0h                       ;// strip out any index
        lea esi, oBmp_palette[esi*4+1Fh*4]  ;// point at END of pallette group
        ASSUME esi:PTR DWORD

        ;// build a scan rect using rcItem and edi as the iterate amount

        invoke GetClientRect, static_hWnd, ADDR [ebx].rcItem
        mov edx, [ebx].rcItem.bottom
        mov edi, edx
        shr edi, 5
        sub edx, edi
        mov [ebx].rcItem.top, edx

        ;// do the loop

        .REPEAT

            mov eax, [esi]
            RGB_TO_BGR eax
            invoke CreateSolidBrush, eax
        push eax

            lea edx, [ebx].rcItem
            invoke FillRect, [ebx].hDC, edx, eax
            call DeleteObject
            DEBUG_IF <!!eax>

        ;direct call does the pop for us

            sub esi, 4      ;// previous color
            mov eax, [ebx].rcItem.top
            sub [ebx].rcItem.top, edi
            mov [ebx].rcItem.bottom, eax

        .UNTIL SIGN?

        ;// that's it

        pop edi
        pop esi

        jmp all_done_ebx

    ALIGN 16
    draw_list_box:

    ;// skip if empty list

        cmp [ebx].dwItemID, -1
        je all_done_ebx

    ;// skip changing focus commands

    ;// cmp [ebx].dwItemAction, ODA_FOCUS
    ;// je all_done_ebx

        push esi    ;// store now
        push edi

    comment ~ /*

        here's what we have to do

        determine what string to draw
        this will be stored in esi

        check the item state and do the following

        (ODS_FOCUS)
        determine if we change the background color
        this also implies that we are selected

        (ODS_SELECTED)
        have to draw a focus rect

    */ comment ~

    ;// 1) dtermine what string to draw

        mov esi, [ebx].dwItemData   ;// load the color_list record pointer
        ASSUME esi:PTR COLOR_LIST

    ;// 2)  determine how to draw this

    do_the_draw:

    ;// fill the background with the appropriate color
    ;// if text is selected, then set the background color

        lea edi, [ebx].rcItem
        ASSUME edi:PTR RECT
        test [ebx].dwItemState, ODS_SELECTED
        mov edx, COLOR_WINDOW+1
        jz @F

        invoke GetSysColor,COLOR_HIGHLIGHT
        invoke SetBkColor, [ebx].hDC, eax
        invoke GetSysColor, COLOR_HIGHLIGHTTEXT
        invoke SetTextColor, [ebx].hDC, eax
        mov edx, COLOR_HIGHLIGHT+1
    @@:
        invoke FillRect, [ebx].hDC, edi, edx

    ;// draw the text

        lea ecx, [esi].string   ;// point at what to draw
        or edx, -1              ;// set as -1
        invoke DrawTextA, [ebx].hDC, ecx, edx, edi, DT_NOCLIP OR DT_SINGLELINE OR DT_NOPREFIX

    ;// draw the focus rect

        .IF [ebx].dwItemState & ODS_FOCUS
            invoke DrawFocusRect, [ebx].hDC, edi
        .ENDIF

    ;// replace the background color

        .IF [ebx].dwItemState & ODS_SELECTED
            invoke GetSysColor, COLOR_WINDOW
            invoke SetBkColor, [ebx].hDC, eax
            invoke GetSysColor, COLOR_WINDOWTEXT
            invoke SetTextColor, [ebx].hDC, eax
        .ENDIF

    ;// draw the sample color

        COLOR_LIST_SAMPLE_WIDTH = 30

        mov eax, [edi].right
        inc [edi].top
        sub eax, COLOR_LIST_SAMPLE_WIDTH
        dec [edi].right
        mov [edi].left, eax
        dec [edi].bottom

        invoke FillRect, [ebx].hDC, edi, [esi].hBrush

    ;// 3) clean up and beat it

        pop edi
        pop esi

    all_done_ebx:

        xchg ebx, WP_LPARAM
        mov eax, 1
        ret 10h


list_wm_drawitem_proc   ENDP
;//
;// WM_DRAWITEM
;//
;// idCtl = (UINT) wParam;             // control identifier
;// lpdis = (LPDRAWITEMSTRUCT) lParam; // item-drawing information
;//
;////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////
;//                             jumped from colors_wm_command_proc
;//
;//     list_lb_selchange_proc      action list.cursel --> list_cursel
;//                                                    --> list_curptr
;//                                                    --> scrolls_UpdateColor
ASSUME_AND_ALIGN
list_lbn_selchange_proc PROC ;// STDCALL hWnd, msg, wParam, lParam

    LISTBOX list_hWnd, LB_GETCURSEL, 0, 0
    mov list_cursel, eax
    LISTBOX list_hWnd, LB_GETITEMDATA, eax, 0
    mov list_curptr, eax

    invoke scrolls_UpdateColor
    invoke InvalidateRect, static_hWnd, 0, 0

    xor eax, eax
    ret 10h

list_lbn_selchange_proc ENDP
;//
;//     list_lb_selchange_proc
;//                             jumped from colors_wm_command_proc
;//
;////////////////////////////////////////////////////////////////////










;////
;////       C O L O R   L I S T   F U N C T I O N S
;////
;////
;////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////
ASSUME_AND_ALIGN

END

