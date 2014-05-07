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
;// GDI_PIN.INC     include file for gdi pin invalidate
;//

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


        GDI_INVALIDATE_PIN MACRO flag:req, pin:=<ebx>,context:=<ebp>

        ;// uses edx, eax
        ;// pin and context must be assumed as APIN and LIST_CONTEXT
        ;// eax may be the flag, it will be destroyed

            LOCAL already_in_list

            .ERRIDNI <flag>,<edx>,<edx may NOT be the flag value>

            PUSHCONTEXT ASSUMES

            PIN_TO_OSC pin, edx         ;// get owning osc

            or [pin].dwHintI, flag      ;// add bits to pin
            or [edx].dwHintOsc, HINTOSC_INVAL_DO_PINS   ;// tell osc to call pins

            dlist_IfMember_jump oscI,edx,already_in_list,[context]

            dlist_InsertTail oscI, edx,,[context]   ;// add the osc to the invalidate list

        already_in_list:

            POPCONTEXT ASSUMES

            ENDM



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
    HINTPIN_STATE_HIDE              EQU 00000080h   ;// render state

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


;////////////////////////////////////////////////////////////////////////////

;// then we get flag that states we are using the reverse mode of pin connect

    EXTERNDEF pin_connect_special_18:DWORD  ;// reverse mode, must be 18 or 0




