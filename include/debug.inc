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
;// debug.inc
;//

;// this is included in ABOX.INC if the correct debug flags are set




;////////////////////////////////////////////////////////////////////
;//
;//
;//     MACROS
;//

    ;// this forces the debug window to update

    UPDATE_DEBUG MACRO

        IFDEF USE_DEBUG_PANEL
        invoke InvalidateRect, debug_hWnd, 0, 1
        ENDIF

        ENDM

    DEBUG_CLOCKER_DECLARE MACRO name:req

        IFDEF USE_DEBUG_PANEL
        EXTERNDEF name&_debug_clocker_t0:DWORD
        EXTERNDEF name&_debug_clocker_t1:DWORD
        ENDIF

        ENDM

    DEBUG_CLOCKER_BEGIN MACRO name:req

        IFDEF USE_DEBUG_PANEL
        rdtsc
        mov name&_debug_clocker_t0, eax
        ENDIF

        ENDM

    DEBUG_CLOCKER_END MACRO name:req

        IFDEF USE_DEBUG_PANEL
        rdtsc
        mov name&_debug_clocker_t1, eax
        ENDIF

        ENDM

;//
;//
;//     MACROS
;//
;////////////////////////////////////////////////////////////////////





;////////////////////////////////////////////////////////////////////
;//
;//
;//     FUNCTIONS and externel values
;//

IFDEF USE_DEBUG_PANEL

    debug_Initialize    PROTO STDCALL
    debug_WndProc       PROTO

    EXTERNDEF debug_hWnd:DWORD
    ;// EXTERNDEF tick_tock:DWORD
    ;// EXTERNDEF debug_busy:DWORD  ;// interlock for play_wait


    DEBUG_CLOCKER_DECLARE render
    DEBUG_CLOCKER_DECLARE paint
    DEBUG_CLOCKER_DECLARE mouse
    DEBUG_CLOCKER_DECLARE play_render
    DEBUG_CLOCKER_DECLARE play_blit

    ;// OPTIONS

    SHOW_INVALIDATE_RECT equ 1


    EXTERNDEF debug_bShowInvalidRect:DWORD  ;// set true to turn invalid on
    EXTERNDEF debug_bShowInvalidBlit:DWORD  ;// set true to turn invalid on
    EXTERNDEF debug_bShowInvalidErase:DWORD ;// set true to turn invalid on

    EXTERNDEF debug_Enabled:DWORD   ;// set to zero to freeze the debug panel

ENDIF


;//
;//
;//     FUNCTIONS and externel values
;//
;////////////////////////////////////////////////////////////////////









