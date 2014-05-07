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
;//   pin_connect.asm       connection managment routines
;//
;//
;// TOC:
;//
;// pin_connect_UI_UO
;// pin_connect_UO_UI
;// pin_connect_CO_UO
;// pin_connect_CI_UI
;// pin_connect_UI_CI
;// pin_connect_UI_CO
;// pin_connect_CO_CO
;//
;// pin_connect_CI_UOCO_special
;// pin_connect_CI_CI_special
;// pin_connect_CO_UI_special
;//
;// pin_connect_query
;//
;// pin_Unconnect


OPTION CASEMAP:NONE
.586
.MODEL FLAT

        .NOLIST
        include <Abox.inc>
        include <groups.inc>    ;// unconnect needs to call pinint_Calc
        include <bus.inc>       ;// need the bus table macro
        include <gdi_pin.inc>
        .LIST

.DATA


;//////////////////////////////////////////////////////////////////////////////
;//
;//
;// C O N N E C T I O N   I N T E R F A C E
;//
;//
comment ~ /*


    TOC:    pin_connect_XX_YY functions
            pin_connect_query
            pin_connect_table
            pin_unconnect

    notes:

    now that we allow multiple connections to outputs
    we treat ALL connections like busses
    this leaves us with the following table:

        U = unconnected
        C = connected now
        I = input pin
        O = output pin

        src dst
        edi ebx
        U I U I     16 cases
        C O C O     only a few are valid

    How to call connection functions

        all calls are register calls
        the implied order is 'function(from_arg,to_arg)

        edi must be the source pin (from_arg)
        ebx must be the destination pin (to_arg)

        ebx, edi and esi are always presereved
        eax ecx and edx will be destroyed

        1) verify the connection is valid by calling pin_connect_query
            always skip if ecx is zero, or the zero flag is set

        2) call the returned pointer (in ecx)
            the connect functions will invalidate the appropriate items

            ALLWAYS set ebp as the current context
            ALWAYS ENTER_PLAY_WAIT befor calling
            ALWAYS schedule a trace before leaving play wait
            ALWAYS LEAVE_PLAY_WAIT after calling

*/ comment ~



    pin_connect_special_18  DD  0   ;// set true to reverse pin connect
                                    ;// must be 18 or zero



;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;//
;//
;//     P I N   C O N N E C T    F U N C T I O N S
;//     edi must be the source pin  (preserved)
;//     ebx must be the dest pin    (destroyed)
;//
;//     also uses eax, ecx

.CODE




;////////////////////////////////////////////////////////////////////
;//
;//     pin_connect_UI_UO
;//     pin_connect_UO_UI
;//
ASSUME_AND_ALIGN
;//        edi ebx
;//        --- ---
pin_connect_UI_UO PROC
;// same as next function
pin_connect_UI_UO ENDP

;//        edi ebx
;//        --- ---
pin_connect_UO_UI PROC

        ASSUME edi:PTR APIN ;// source pin
        ASSUME ebx:PTR APIN ;// dest pin
        ASSUME ebp:PTR LIST_CONTEXT

    ;// verify the args

        DEBUG_IF <edi==ebx> ;// connect to self !!!

        DEBUG_IF <!!(play_status & PLAY_GUI_SYNC)>  ;// supposed to be in play waut

        DEBUG_IF < ([edi].pPin) || ([edi].dwStatus & PIN_BUS_TEST) >
        ;// source is either connected or a bus

        DEBUG_IF < ([ebx].pPin) || ([ebx].dwStatus & PIN_BUS_TEST) >
        ;// dest is either connected or a bus

    ;// check for undo redo

        mov ecx, unredo_pRecorder
        .IF ecx
            ASSUME ecx:PTR UNREDO_PIN_CONNECT
            mov [ecx].num_pin, 2
            mov [ecx].mode, -2
            mov [ecx].con.pin, edi
            mov [ecx+SIZEOF UNREDO_PIN].con.pin, ebx
            add unredo_pRecorder, SIZEOF UNREDO_PIN_CONNECT + SIZEOF UNREDO_PIN
        .ENDIF

    ;// connect the pins

        mov [edi].pPin, ebx
        mov [ebx].pPin, edi

    ;// invalidate them

        GDI_INVALIDATE_PIN HINTI_PIN_CONNECTED, edi
        GDI_INVALIDATE_PIN HINTI_PIN_CONNECTED, ebx

    ;// that's it

        ret


pin_connect_UO_UI ENDP

;////////////////////////////////////////////////////////////////////
;//
;//
;//     pin_connect_CO_UO           move an output to an unused output
;//                                 this reroutes all attached pins
;//
ASSUME_AND_ALIGN
;//        edi ebx
;//        --- ---
pin_connect_CO_UO PROC

        ASSUME edi:PTR APIN ;// CO pin
        ASSUME ebx:PTR APIN ;// UO pin
        ASSUME ebp:PTR LIST_CONTEXT

    ;// verify the args

        DEBUG_IF <edi==ebx> ;// connect to self !!!

        DEBUG_IF <!!(play_status & PLAY_GUI_SYNC)>  ;// supposed to be in play wait

        DEBUG_IF < (!![edi].pPin) && !!([edi].dwStatus & PIN_BUS_TEST) >
        ;// CO is neither connected nor a bus

        DEBUG_IF <[ebx].pPin || ([ebx].dwStatus & PIN_BUS_TEST)>
        ;// UO is already connected or bussed

    ;// check for undo redo

        mov ecx, unredo_pRecorder
        .IF ecx
            ASSUME ecx:PTR UNREDO_PIN_CONNECT
            mov [ecx].num_pin, 2
            mov [ecx].mode, UNREDO_CON_CO_UO
            mov [ecx].con.pin, edi
            mov [ecx+SIZEOF UNREDO_PIN].con.pin, ebx
            add unredo_pRecorder, SIZEOF UNREDO_PIN_CONNECT + SIZEOF UNREDO_PIN

        .ENDIF

    ;// update the bus head if nessesary

        mov eax, [edi].dwStatus
        xor edx, edx    ;// clear for zeroing
        and eax, PIN_BUS_TEST
        .IF !ZERO?

            mov [ebp].bus_table[eax*4-4], ebx   ;// set the new head

            or [ebx].dwStatus, eax  ;// mask in the new bus index

            and [edi].dwStatus, NOT PIN_BUS_TEST;// reset the old bus index

            mov eax, [edi].pBShape  ;// get the name shape
            mov [ebx].pBShape, eax  ;// store in new

        .ENDIF

    ;// unconnect and invalidate the current head

        mov ecx, [edi].pPin         ;// get the old first connection (may be zero)

        mov [edi].pPin, edx         ;// zero the connection

        GDI_INVALIDATE_PIN HINTI_PIN_UNCONNECTED, edi   ;// invalidate it

    ;// connect and invalidate the new head

        mov [ebx].pPin, ecx             ;// set the new first in chain

        GDI_INVALIDATE_PIN HINTI_PIN_CONNECTED  ;// invalidate it

    ;// reconnect all the pins in the list
    ;// no need to invalidate ???

        xchg ebx, ecx   ;// store UO in ecx, and load the first in chain
        .WHILE ebx

            mov [ebx].pPin, ecx                     ;// set new source connection
            GDI_INVALIDATE_PIN HINTI_PIN_CONNECTED  ;// invalidate it
            mov ebx, [ebx].pData                    ;// get the next pin

        .ENDW

    ;// that's it

        mov ebx, ecx    ;// restore ebx

        ret

pin_connect_CO_UO ENDP

;////////////////////////////////////////////////////////////////////
;//
;//
;//     pin_connect_CI_UI       MOVE a connection from one input to another
;//
ASSUME_AND_ALIGN
;//        edi ebx
;//        --- ---
pin_connect_CI_UI PROC

        ASSUME edi:PTR APIN ;// CI pin
        ASSUME ebx:PTR APIN ;// UI pin
        ASSUME ebp:PTR LIST_CONTEXT

    ;// verify the args

        DEBUG_IF <edi==ebx> ;// connect to self !!!

        DEBUG_IF <!!(play_status & PLAY_GUI_SYNC)>  ;// supposed to be in play waut

        DEBUG_IF < (!![edi].pPin) && !!([edi].dwStatus & PIN_BUS_TEST) >
        ;// CI is neither connected nor a bus

        DEBUG_IF <[ebx].pPin>   ;// UI is already connected

        DEBUG_IF < [edi].dwStatus & PIN_OUTPUT >;// CI is not an input

        DEBUG_IF < [ebx].dwStatus & PIN_OUTPUT >;// UI is not an input

    ;// check for undo redo

        mov ecx, unredo_pRecorder
        .IF ecx
            ASSUME ecx:PTR UNREDO_PIN_CONNECT
            mov [ecx].num_pin, 2
            mov [ecx].mode, UNREDO_CON_CI_UI
            mov [ecx].con.pin, edi
            mov [ecx+SIZEOF UNREDO_PIN].con.pin, ebx
            add unredo_pRecorder, SIZEOF UNREDO_PIN_CONNECT + SIZEOF UNREDO_PIN
        .ENDIF

        ASSUME ecx:PTR APIN ;// temp pin

    ;// actions:    get the source pin
    ;//             remove the input pin from the source pin's list
    ;//                 if bus, remove index as well
    ;//             add the new pin to the source pins list
    ;//                 if bus, set the index


        mov ecx, [edi].pPin     ;// get CI's source pin

        GDI_INVALIDATE_PIN HINTI_PIN_CONNECTED, ecx ;// invalidate it so it gets erased

        xor edx, edx            ;// clear for clearing
        mov eax, [ecx].pPin     ;// get the first pin in CI's chain
        mov [ebx].pPin, ecx     ;// set UI's new connection

        ;// locate the pin that points to us

        cmp eax, edi
        jne @F

            ;// CI was the first pin in the chain

            mov eax, [edi].pData        ;// get the next pin in CI's chain (may be zero)
            mov [ecx].pPin, ebx         ;// set first input as UI
            mov [ebx].pData, eax        ;// set UI's next in chain (zero is ok)

            jmp finish_up_CI_UI

        @@:
            ;// we are not the first pin in the chain
            ;// next block of code assumes that the pin will be found
            ;// there are two iterations per jump

            mov ecx, eax            ;// get the next pin
            mov eax, [ecx].pData    ;// load it's pNextPin value
            cmp eax, edi            ;// same as us ?
            jz @F                   ;// jmp to exit
            mov ecx, eax            ;// xfer to ecx
            mov eax, [ecx].pData    ;// load it's pNextPin value
            cmp eax, edi            ;// same as us ?
            jnz @B                  ;// do until found

            ;// now ecx point at the pin that points to us

        @@:
            mov eax, [edi].pData        ;// get the old next
            mov [ecx].pData, ebx        ;// set it's pNext as us
            mov [ebx].pData, eax        ;// set our pNext as the old pNext

        finish_up_CI_UI:

            mov [edi].pPin, edx         ;// clear the old connection
            mov [edi].pData, edx        ;// clear the old chain
            mov eax, PIN_BUS_TEST   ;// load for the next test
            and eax, [edi].dwStatus ;// test the status for a bus

        ;// check for bus

            .IF !ZERO?

                and [edi].dwStatus, NOT PIN_BUS_TEST;// clear the old index
                or [ebx].dwStatus, eax              ;// merge on the new index

                mov eax, [edi].pBShape  ;// get the bus shape
                mov [ebx].pBShape, eax  ;// xfer to new pin

            .ENDIF

        ;// invalidate the old and the new

            GDI_INVALIDATE_PIN HINTI_PIN_UNCONNECTED, edi
            GDI_INVALIDATE_PIN HINTI_PIN_CONNECTED

        ;// that's it

            ret


pin_connect_CI_UI ENDP




;////////////////////////////////////////////////////////////////////
;//
;//                             ADD the pin to current chain
;//     pin_connect_UI_CI       this inserts it as the first connection
;//
ASSUME_AND_ALIGN
;//        edi ebx
;//        --- ---
pin_connect_UI_CI PROC

    ASSUME edi:PTR APIN ;// UI pin
    ASSUME ebx:PTR APIN ;// CI pin
    ASSUME ebp:PTR LIST_CONTEXT


    ;// verify the args

        DEBUG_IF <edi==ebx> ;// connect to self !!!

        DEBUG_IF <!!(play_status & PLAY_GUI_SYNC)>  ;// supposed to be in play wait

        DEBUG_IF < (!![ebx].pPin) && !!([ebx].dwStatus & PIN_BUS_TEST) >
        ;// dest is neither connected nor a bus

        DEBUG_IF <[edi].pPin>   ;// UI is already connected

        DEBUG_IF < [edi].dwStatus & PIN_OUTPUT >    ;// not an input

        DEBUG_IF < [ebx].dwStatus & PIN_OUTPUT >    ;// not an input

    ;// check for undo redo

        mov ecx, unredo_pRecorder
        .IF ecx
            ASSUME ecx:PTR UNREDO_PIN_CONNECT
            mov [ecx].num_pin, 2
            mov [ecx].mode, -1
            mov [ecx].con.pin, edi
            mov eax, [ebx].pPin
            mov [ecx+SIZEOF UNREDO_PIN].con.pin, eax
            add unredo_pRecorder, SIZEOF UNREDO_PIN_CONNECT + SIZEOF UNREDO_PIN
        .ENDIF

        ASSUME ecx:PTR APIN     ;// temp source pin

    ;// do the list insertion

        mov ecx, [ebx].pPin     ;// get the source pin from existing connection
        mov edx, PIN_BUS_TEST   ;// load the bus mask

        mov [edi].pPin, ecx     ;// set new connection to the source pin
        and edx, [ebx].dwStatus ;// mask in the bus index (zero is ok)

        mov eax, [ecx].pPin     ;// get the old first destination pin
        or [edi].dwStatus, edx  ;// set the new bus index (if any)

        mov [ecx].pPin, edi     ;// set the new first destination pin

        mov [edi].pData, eax    ;// set our next in chain as the old first in chain

        mov eax, [ebx].pBShape  ;// get the bus shape (zero is ok)
        mov [edi].pBShape, eax  ;// xfer to new pin

    ;// invalidate

        GDI_INVALIDATE_PIN HINTI_PIN_CONNECTED, edi

    ;// that's it

        ret

pin_connect_UI_CI ENDP


;////////////////////////////////////////////////////////////////////
;//
;//                             ADD the pin to current chain
;//     pin_connect_UI_CO       this inserts it as the first connection
;//
ASSUME_AND_ALIGN
;//        edi ebx
;//        --- ---
pin_connect_UI_CO PROC

        ASSUME edi:PTR APIN ;// UI pin
        ASSUME ebx:PTR APIN ;// CO pin
        ASSUME ebp:PTR LIST_CONTEXT

    ;// verify the args

        DEBUG_IF <edi==ebx> ;// connect to self !!!

        DEBUG_IF <!!(play_status & PLAY_GUI_SYNC)>  ;// supposed to be in play wait

        DEBUG_IF < (!![ebx].pPin) && !!([ebx].dwStatus & PIN_BUS_TEST) >
        ;// CO is neither connected nor a bus

        DEBUG_IF <[edi].pPin>   ;// UI is already connected

        DEBUG_IF < [edi].dwStatus & PIN_OUTPUT >    ;// UI is not an input

        DEBUG_IF < !!([ebx].dwStatus & PIN_OUTPUT) >;// CO is not an output

    ;// check for undo redo

        mov ecx, unredo_pRecorder
        .IF ecx
            ASSUME ecx:PTR UNREDO_PIN_CONNECT
            mov [ecx].num_pin, 2
            mov [ecx].mode, -1
            mov [ecx].con.pin, edi
            mov [ecx+SIZEOF UNREDO_PIN].con.pin, ebx
            add unredo_pRecorder, SIZEOF UNREDO_PIN_CONNECT + SIZEOF UNREDO_PIN
        .ENDIF

    ;// do the list insertion

        mov ecx, [ebx].pPin     ;// get the first dest pin from the source (may be zero)
        mov edx, PIN_BUS_TEST   ;// load the bus mask

        mov [edi].pPin, ebx     ;// set our new connection to the source pin
        and edx, [ebx].dwStatus ;// mask in the bus index (zero is ok)

        mov [ebx].pPin, edi     ;// set the new first first in chain
        or [edi].dwStatus, edx  ;// set the new bus index (if any)

        mov eax, [ebx].pBShape  ;// get the bus shape from CO

        mov [edi].pData, ecx    ;// set the new first in chain

        mov [edi].pBShape, eax  ;// xfer to UI


    ;// invalidate

        GDI_INVALIDATE_PIN HINTI_PIN_CONNECTED, edi ;// invalidate UI

    ;// that's it

        ret


pin_connect_UI_CO ENDP



;////////////////////////////////////////////////////////////////////
;//
;//                             MOVE all the connections from one source
;//     pin_connect_CO_CO       to another source
;//
ASSUME_AND_ALIGN
;//        edi ebx
;//        --- ---
pin_connect_CO_CO PROC

        ASSUME edi:PTR APIN ;// CO pin
        ASSUME ebx:PTR APIN ;// CO pin
        ASSUME ebp:PTR LIST_CONTEXT

    ;// this moves one set of connection to another
    ;// it should NOT BE USED FOR BUSSES

    ;// move each input to the other chain
    ;// simplest way is to insert at the head

    ;// verify the args

        DEBUG_IF <edi==ebx> ;// connect to self !!!

        DEBUG_IF <!!(play_status & PLAY_GUI_SYNC)>  ;// supposed to be in play wait

        DEBUG_IF <!![ebx].pPin> ;// not connected
        DEBUG_IF <!![edi].pPin> ;// not connected

        DEBUG_IF <!!([edi].dwStatus & PIN_OUTPUT)>  ;// not an output
        DEBUG_IF <!!([ebx].dwStatus & PIN_OUTPUT)>  ;// not an output

        DEBUG_IF <[edi].dwStatus & PIN_BUS_TEST>    ;// not supposed to be a bus
        DEBUG_IF <[ebx].dwStatus & PIN_BUS_TEST>    ;// not supposed to be a bus

    ;// check for undo redo

        mov ecx, unredo_pRecorder
        .IF ecx

            ASSUME ecx:PTR UNREDO_PIN_CONNECT
            mov [ecx].num_pin, 2    ;// minimum amount
            mov [ecx].mode, UNREDO_CON_CO_CO
            mov [ecx].con.pin, edi
            mov [ecx+SIZEOF UNREDO_PIN].con.pin, ebx

        ;// then store a list of what edi connects to

            lea edx, [ecx+3*(SIZEOF UNREDO_PIN)]
            ASSUME edx:PTR UNREDO_PIN

            mov eax, [edi].pPin     ;// get the first connection
            .WHILE eax              ;// anything ?

                inc [ecx].num_pin   ;// bump number of pins

                mov [edx].pin, eax  ;// store the pin
                mov eax, (APIN PTR [eax]).pData ;// get the next pin
                add edx, SIZEOF UNREDO_PIN      ;// advance to the next record

            .ENDW

            mov unredo_pRecorder, edx

        .ENDIF

    ;// unconnect old and set the new first of chain

        xor eax, eax            ;// clear for zeroing

        mov ecx, [edi].pPin     ;// get the first dest pin
        mov edx, [ebx].pPin     ;// get first destination

        mov [edi].pPin, eax     ;// unconnect the source pin
        mov [ebx].pPin, ecx     ;// set new first destination

        ASSUME ecx:PTR APIN

    ;// search for the end of the chain and set the new source as we go

    top_of_scan:

        or eax, [ecx].pData     ;// get and test the next connection
        mov [ecx].pPin, ebx     ;// set the new source
        jz found_the_end        ;// jump if ecx is at the end
        mov ecx, eax            ;// iterate
        xor eax, eax            ;// clear for testing
        jmp top_of_scan         ;// do until done

    found_the_end:  ;// now ecx is the last pin in the chain

        mov [ecx].pData, edx    ;// splice on old chain

    ;// now we invalidate both connections
    ;// we'll call pin_set_color to do this ?

        GDI_INVALIDATE_PIN HINTI_PIN_UNCONNECTED, edi

        invoke gdi_pin_reset_color, HINTI_PIN_CONNECTED

    ;// that's it

        ret

pin_connect_CO_CO ENDP




;////////////////////////////////////////////////////////////////////
;//
;//                                     unconnect CI from it's connection
;//     pin_connect_CI_UOCO_special     connect to UO or CO
;//                                     works for both connected and unconnected outputs
ASSUME_AND_ALIGN
;//        edi ebx
;//        --- ---
pin_connect_CI_UOCO_special PROC

        ASSUME edi:PTR APIN ;// CI pin
        ASSUME ebx:PTR APIN ;// UO or CO pin
        ASSUME ebp:PTR LIST_CONTEXT

    ;// verify the args

        DEBUG_IF <edi==ebx> ;// connect to self !!!

        DEBUG_IF <!!(play_status & PLAY_GUI_SYNC)>  ;// supposed to be in play wait

        DEBUG_IF <!![edi].pPin> ;// not connected
        ;//DEBUG_IF <!![ebx].pPin> ;// not connected

        DEBUG_IF <([edi].dwStatus & PIN_OUTPUT)>    ;// supposed to be an input
        DEBUG_IF <!!([ebx].dwStatus & PIN_OUTPUT)>  ;// supposed to be an output

;// can be a bus        DEBUG_IF <[edi].dwStatus & PIN_BUS_TEST>    ;// not supposed to be a bus
;// can be a bus        DEBUG_IF <[ebx].dwStatus & PIN_BUS_TEST>    ;// not supposed to be a bus

    ;// check for undo redo

        GET_PIN [edi].pPin, ecx ;// get ci's source pin
        GDI_INVALIDATE_PIN HINTI_PIN_UNCONNECTED, ecx
        GET_PIN [edi].pPin, edx ;// get ci's source pin

        mov ecx, unredo_pRecorder
        .IF ecx
        ;// unredo = CI, new CO, old CO
            ASSUME ecx:PTR UNREDO_PIN_CONNECT
            mov [ecx].num_pin, 3
            mov [ecx].mode, UNREDO_CON_CI_UOCO
            mov [ecx].con.pin, edi  ;// store CI
            add ecx, SIZEOF UNREDO_PIN_CONNECT
            ASSUME ecx:PTR UNREDO_PIN
            mov [ecx].pin, ebx      ;// store new CO
            add ecx, SIZEOF UNREDO_PIN
            mov [ecx].pin, edx  ;// store old CO
            add ecx, SIZEOF UNREDO_PIN
            mov unredo_pRecorder, ecx
        .ENDIF

    ;// locate the pin that points to CI
    ;// edx is stil ci's source pin

        cmp [edx].pPin, edi
        jne have_to_search

            ;// edx points at first
            mov eax, [edi].pData    ;// get ci's next pin
            mov [edx].pPin, eax     ;// set as start of chain
            jmp ready_to_reconnect

        have_to_search:
        ;// else, have to search for pin
        ;// two iterations per loop

            mov edx, [edx].pPin

        keep_searching:

            DEBUG_IF <!!edx>    ;// can't find in chain !!
            cmp [edx].pData, edi
            je found_previous_pin
            mov edx, [edx].pData
            DEBUG_IF <!!edx>    ;// can't find in chain !!
            cmp [edx].pData, edi
            je found_previous_pin
            mov edx, [edx].pData
            jmp keep_searching

        found_previous_pin:

        ;// remove CI from the input chain
        ;// edx is the previous item in the chain

            mov eax, [edi].pData    ;// CI's next pin ( if any)
            mov [edx].pData, eax    ;// is now edx->next

    ;// re connect CI to new source
    ready_to_reconnect:

        mov eax, [ebx].pPin     ;// get old first destination of new source
        mov [edi].pPin, ebx     ;// set ci's new destination as new source
        mov [edi].pData, eax    ;// insert CO's chain into new input
        mov [ebx].pPin, edi     ;// connect new CO with CI

    ;// xfer the bus, if any

        mov eax, [edi].dwStatus ;// get the existing bus number
        mov edx, [ebx].dwStatus ;// get the bus number from new pin

        and eax, NOT PIN_BUS_TEST;// remove old bus number
        and edx, PIN_BUS_TEST   ;// remove all the extra stuff from bus number

        or eax, edx             ;// merge bus number into CI pin
        mov [edi].dwStatus, eax ;// store new bus number

        mov eax, [ebx].pBShape  ;// get the bus shape, if any
        mov [edi].pBShape, eax  ;// store bus shape

    ;// invalidate both connections

        ;// why are we unconnecting edi ?
        ;// should be unconnecting edx ?
        ;// removed in abox 2.27
        ;// added back in ABox228

;//     GDI_INVALIDATE_PIN HINTI_PIN_UNCONNECTED, edi

        invoke gdi_pin_reset_color, HINTI_PIN_CONNECTED

    ;// that's it

        ret

pin_connect_CI_UOCO_special ENDP


;////////////////////////////////////////////////////////////////////
;//
;//                                 unconnect CI from it's connection
;//     pin_connect_CI_CI_special   connect into CI's source
;//
ASSUME_AND_ALIGN
;//        edi ebx
;//        --- ---
pin_connect_CI_CI_special PROC

        ASSUME edi:PTR APIN ;// CI pin
        ASSUME ebx:PTR APIN ;// CI pin
        ASSUME ebp:PTR LIST_CONTEXT

        mov ebx, [ebx].pPin             ;// get the source pin
        jmp pin_connect_CI_UOCO_special ;// use the other routine

pin_connect_CI_CI_special ENDP


;////////////////////////////////////////////////////////////////////
;//
;//
;//     pin_connect_CO_UI_special   same as UI_CO but whith pointers swapped
;//
ASSUME_AND_ALIGN
;//        edi ebx
;//        --- ---
pin_connect_CO_UI_special PROC

        ASSUME edi:PTR APIN ;// CO pin
        ASSUME ebx:PTR APIN ;// ui pin
        ASSUME ebp:PTR LIST_CONTEXT

        xchg edi, ebx
        jmp pin_connect_UI_CO

pin_connect_CO_UI_special ENDP





;// not implemented, just don't make good gui sense

;//        edi ebx
;//        --- ---
pin_connect_CI_CO = 0   ;// do not implement or it will screw up the file handler
pin_connect_CO_CI = 0   ;// file_ConnectPins relies on these being zero to detect duplicates

pin_connect_CO_UI = 0

pin_connect_CI_CI = 0
pin_connect_CI_UO = 0
pin_connect_UI_UI = 0
pin_connect_UO_CI = 0
pin_connect_UO_CO = 0
pin_connect_UO_UO = 0

pin_connect_CI_UI_special = 0   ;// these modes are filtered out when swapping ends
pin_connect_CO_UO_special = 0
pin_connect_CO_CI_special = 0
pin_connect_CO_CO_special = 0



;///
;///        P I N   C O N N E C T    F U N C T I O N S
;///
;///
;//////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////


.DATA

pin_connect_table LABEL DWORD

;// uses the following bit pattern (DO NOT REARRANGE)
                        ;// src dst
                        ;// edi ebx     code    implemented
                        ;// --- ---     ----
dd  pin_connect_UI_UI   ;// U I U I     0000    no
dd  pin_connect_UI_UO   ;// U I U O     0001    yes
dd  pin_connect_UI_CI   ;// U I C I     0010    yes
dd  pin_connect_UI_CO   ;// U I C O     0011    yes

dd  pin_connect_UO_UI   ;// U O U I     0100    yes
dd  pin_connect_UO_UO   ;// U O U O     0101    no
dd  pin_connect_UO_CI   ;// U O C I     0110    no
dd  pin_connect_UO_CO   ;// U O C O     0111    no

dd  pin_connect_CI_UI   ;// C I U I     1000    yes
dd  pin_connect_CI_UO   ;// C I U O     1001    no
dd  pin_connect_CI_CI   ;// C I C I     1010    no
dd  pin_connect_CI_CO   ;// C I C O     1011    no

dd  pin_connect_CO_UI   ;// C O U I     1100    no
dd  pin_connect_CO_UO   ;// C O U O     1101    yes
dd  pin_connect_CO_CI   ;// C O C I     1110    no
dd  pin_connect_CO_CO   ;// C O C O     1111    maybe

;// special modes CI is CI
dd 0
dd 0

dd  pin_connect_UI_UI   ;// U I U I     0000    no
dd  pin_connect_UI_UO   ;// U I U O     0001    yes
dd  pin_connect_UI_CI   ;// U I C I     0010    yes
dd  pin_connect_UI_CO   ;// U I C O     0011    yes

dd  pin_connect_UO_UI   ;// U O U I     0100    yes
dd  pin_connect_UO_UO   ;// U O U O     0101    no
dd  pin_connect_UO_CI   ;// U O C I     0110    no
dd  pin_connect_UO_CO   ;// U O C O     0111    no

dd  pin_connect_CI_UI_special   ;// C I U I     1000    no
dd  pin_connect_CI_UOCO_special ;// C I U O     1001    special
dd  pin_connect_CI_CI_special   ;// C I C I     1010    special yes
dd  pin_connect_CI_UOCO_special ;// C I C O     1011    special

dd  pin_connect_CO_UI_special   ;// C O U I     1100    special
dd  pin_connect_CO_UO_special   ;// C O U O     1101    no
dd  pin_connect_CO_CI_special   ;// C O C I     1110    no
dd  pin_connect_CO_CO_special   ;// C O C O     1111    no



pin_status_table LABEL DWORD

dd  status_CONNECT_UI_UI    ;// 0 "Can't connect inputs to inputs", 0       ;// U I U I     0000    no
dd  status_CONNECT_UI_UO    ;// 1 "Connect these pins together",0           ;// U I U O     0001    yes
dd  status_CONNECT_UI_CI    ;// 2 "Connect to this pin's source.",0         ;// U I C I     0010    yes
dd  status_CONNECT_UI_CO    ;// 3 "Connect these pins together",0           ;// U I C O     0011    yes

dd  status_CONNECT_UO_UI    ;// 4 "Connect these pins together",0           ;// U O U I     0100    yes
dd  status_CONNECT_UO_UO    ;// 5 "Can't connect outputs to outputs",0      ;// U O U O     0101    no
dd  status_CONNECT_UO_CI    ;// 6 "Pin is already connected to a source",0  ;// U O C I     0110    no
dd  status_CONNECT_UO_CO    ;// 7 "Can't connect outputs to outputs.",0     ;// U O C O     0111    no

dd  status_CONNECT_CI_UI    ;// 8 "Move connection to this pin.",0          ;// C I U I     1000    yes
dd  status_CONNECT_CI_UO    ;// 9 "Can't connect outputs to outputs.",0     ;// C I U O     1001    no
dd  status_CONNECT_CI_CI    ;// A "Can't connect outputs to outputs.",0     ;// C I C I     1010    no
dd  status_CONNECT_CI_CO    ;// B "Can't connect outputs to outputs.",0     ;// C I C O     1011    no

dd  status_CONNECT_CO_UI    ;// C "Can't move an output to an input.",0     ;// C O U I     1100    no
dd  status_CONNECT_CO_UO    ;// D "Move connection(s) to this output.",0    ;// C O U O     1101    yes
dd  status_CONNECT_CO_CI    ;// E "Can't move an output to an input.",0     ;// C O C I     1110    no
dd  status_CONNECT_CO_CO    ;// F "Move connection(s) to this output.",0    ;// C O C O     1111    maybe

dd  status_CONNECT_BO_BO    ;// 10 "Can't move bus source to another source.",0
dd  status_CONNECT_SAME     ;// 11 "Can't connect a pin to itself.",0

;// special mode

dd  status_CONNECT_UI_UI    ;// 0 "Can't connect inputs to inputs", 0       ;// U I U I     0000    no
dd  status_CONNECT_UI_UO    ;// 1 "Connect these pins together",0           ;// U I U O     0001    yes
dd  status_CONNECT_UI_CI    ;// 2 "Connect to this pin's source.",0         ;// U I C I     0010    yes
dd  status_CONNECT_UI_CO    ;// 3 "Connect these pins together",0           ;// U I C O     0011    yes

dd  status_CONNECT_UO_UI    ;// 4 "Connect these pins together",0           ;// U O U I     0100    yes
dd  status_CONNECT_UO_UO    ;// 5 "Can't connect outputs to outputs",0      ;// U O U O     0101    no
dd  status_CONNECT_UO_CI    ;// 6 "Pin is already connected to a source",0  ;// U O C I     0110    no
dd  status_CONNECT_UO_CO    ;// 7 "Can't connect outputs to outputs.",0     ;// U O C O     0111    no

dd  status_CONNECT_CI_UI_special    ;//
dd  status_CONNECT_CI_UO_special    ;//
dd  status_CONNECT_CI_CI_special    ;//
dd  status_CONNECT_CI_CO_special    ;//

dd  status_CONNECT_CO_UI_special    ;//
dd  status_CONNECT_CO_UO_special    ;// D "Move connection(s) to this output.",0    ;// C O U O     1101    yes
dd  status_CONNECT_CO_CI_special    ;// E "Can't move an output to an input.",0     ;// C O C I     1110    no
dd  status_CONNECT_CO_CO_special    ;// F "Move connection(s) to this output.",0    ;// C O C O     1111    maybe

dd  status_CONNECT_BO_BO    ;// 10 "Can't move bus source to another source.",0
dd  status_CONNECT_SAME     ;// 11 "Can't connect a pin to itself.",0



.CODE
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;//
;//
;//     pin_connect_query   if not connectable, then return 0 in ecx
;//                         and the zero flag is set
;//                         otherwise returns the QC jump index in ecx
;//                         and the zero flag NOT set
;// a pin is connected if:
;//     1)    pPin is set
;//     2) OR it has a bus index

ASSUME_AND_ALIGN
pin_connect_query PROC

        ASSUME edi:PTR APIN ;// source pin
        ASSUME ebx:PTR APIN ;// dest pin

        DEBUG_IF <!!edi>    ;// source pin is zero !!

        DEBUG_IF <!!ebx>    ;// dest pin is zero !!

        xor ecx, ecx            ;// clear as a byte register

    ;// NEVER allow connect to self

        mov eax, 17     ;// status index for same pin
        cmp edi, ebx
        jz all_done

    ;// build the source pin

        mov ch, BYTE PTR [edi].dwStatus ;// load the bus index
        xor eax, eax                    ;// zero for testing
        sub cl, ch                      ;// sets carry if not zero
        jnz @F                          ;// jump if a bus
        cmp eax, [edi].pPin             ;// sets carry if valid address (below)
    @@: rcl eax, 1                      ;// add results to accumulator

        bt [edi].dwStatus, LOG2(PIN_OUTPUT) ;// test for output pin
        rcl eax, 1                      ;// accumulate results

    ;// build the dest pin

        xor ecx, ecx                    ;// clear as a byte register
        mov ch, BYTE PTR [ebx].dwStatus ;// load the bus index
        sub cl, ch                      ;// sets carry if not zero
        jnz @F
        cmp eax, [ebx].pPin             ;// sets carry if valid address (below)
    @@: rcl eax, 1                      ;// move the carry bit into place
        bt [ebx].dwStatus, LOG2(PIN_OUTPUT) ;// test for output pin
        rcl eax, 1                      ;// accumulate results

    ;// get the jump pointer

        xor ecx, ecx        ;// clear and prevent stalls
        cmp eax, 0Fh        ;// need special test for CO_CO
        je check_CO_CO

        add eax, pin_connect_special_18 ;// account for special modes

    get_the_connect_function:

        or ecx, pin_connect_table[eax*4]    ;// load and test the return address

    all_done:

        mov eax, pin_status_table[eax*4]    ;// load the status code
        ret

    check_CO_CO:

        ;// we do not allow dragging of bus sources
        ;// so if either connection is a bus
        ;// we must return zero

        test [edi].dwStatus, PIN_BUS_TEST   ;// check the dest for a bus connection
        jnz @F                              ;// jump if a bus
        test [ebx].dwStatus, PIN_BUS_TEST   ;// check the source for a bus connection
        jz get_the_connect_function         ;// good to go if not a bus

    @@: inc eax
        xor ecx, ecx        ;// clear and set the zero flags
        jmp all_done        ;// jump to the ret




pin_connect_query ENDP
;//
;//     pin_connect_query
;//
;//
;////////////////////////////////////////////////////////////////////



















;////////////////////////////////////////////////////////////////////
;//
;//
;//     pin_Unconnect
;//
ASSUME_AND_ALIGN
pin_Unconnect PROC uses esi edi ebx

        ASSUME ebp:PTR LIST_CONTEXT
        ASSUME ebx:PTR APIN     ;// ebx must be what we want to unconnect

    ;// verify the args

        DEBUG_IF <!!(play_status & PLAY_GUI_SYNC)>  ;// supposed to be in play wait

        DEBUG_IF <!![ebx].pPin && !!([ebx].dwStatus & PIN_BUS_TEST)>;// this pin is not connected

    ;// step one is make sure the entire connection chain gets redrawn correctly
    ;// we'll do this by calling set pin color
    ;// what this means is that we do not have to GDI_INVALIDATE_PIN,
    ;// we only have to merge in new hinti bits

        invoke gdi_pin_reset_color, 0   ;// use the default color

        mov ecx, [ebx].dwStatus         ;// load the status now

    ;// merge on the unconnected status bit

        or [ebx].dwHintI, HINTI_PIN_UNCONNECTED OR HINTI_PIN_LOST_BUS_HOVER

    ;// account for unredo recording

        mov edi, unredo_pRecorder   ;// unredo requires that we record actions
        ASSUME edi:PTR UNREDO_PIN_CONNECT

    ;// figure out how to unconnect this

        bt ecx, LOG2(PIN_OUTPUT)    ;// output pin ?
        jnc unconnecting_input_pin

    unconnecting_output_pin:        ;// this is an output pin

        and ecx, PIN_BUS_TEST   ;// saves a step

        ;// account for recording

        .IF edi     ;// are we recording ?

            mov [edi].num_pin, 1    ;// min number of pins
            mov [edi].mode, ecx     ;// save the mode
            mov [edi].con.pin, ebx  ;// save the output pin

        ;// store all the connections

            mov eax, [ebx].pPin
            lea edx, [edi+SIZEOF UNREDO_PIN_CONNECT]
            ASSUME edx:PTR UNREDO_PIN
            .WHILE eax

                mov [edx].pin, eax
                inc [edi].num_pin
                mov eax, (APIN PTR [eax]).pData
                add edx, SIZEOF UNREDO_PIN

            .ENDW

            mov unredo_pRecorder, edx

        .ENDIF

    ;// determine bussed or no

        or ecx, ecx ;// we're we bussed ?
        jz unconnecting_output_unbussed

    unconnecting_output_bussed:     ;// and it's a bus

        xor edx, edx                ;// use for zeroing
        mov BUS_TABLE(ecx), edx     ;// clear the bus head

        mov ecx, [ebx].pPin         ;// get the first pin
        mov esi, NOT PIN_BUS_TEST   ;// load the mask for index clearing

        mov [ebx].pPin, edx         ;// clear the pin
        and [ebx].dwStatus, esi     ;// clear the bus index

        .WHILE ecx

            mov ebx, ecx            ;// set ebx as next in chain
            or [ebx].dwHintI, HINTI_PIN_UNCONNECTED OR HINTI_PIN_LOST_BUS_HOVER
            mov ecx, [ebx].pData    ;// get the next pin in the chain
            mov [ebx].pPin, edx     ;// clear the source connection
            and [ebx].dwStatus, esi ;// clear the bus index
            mov [ebx].pData, edx    ;// clear the next in chain

        .ENDW

        jmp all_done

    unconnecting_output_unbussed:   ;// output, but not a bus

        ;// xor ecx, ecx    ecx already equals zero

        mov edx, [ebx].pPin         ;// get the first pin
        mov [ebx].pPin, ecx         ;// clear the pin

        .WHILE edx      ;// scan all the input pins

            mov ebx, edx            ;// set ebx as next in chain
            or [ebx].dwHintI, HINTI_PIN_UNCONNECTED
            mov edx, [ebx].pData    ;// get the next pin in the chain
            mov [ebx].pPin, ecx     ;// clear the source connection
            mov [ebx].pData, ecx    ;// clear the next in chain

        .ENDW

        jmp all_done

    unconnecting_input_pin: ;// this is an input pin

        xor ecx, ecx        ;// ecx must be zero

    ;// if we are a bus, we must invalidate the entire chain

        .IF [ebx].dwStatus & PIN_BUS_TEST

            GET_PIN [ebx].pPin, ecx     ;// get the first item
            or [ecx].dwHintI, HINTI_PIN_LOST_BUS_HOVER
            mov ecx, [ecx].pPin
            .REPEAT

                or [ecx].dwHintI, HINTI_PIN_LOST_BUS_HOVER
                mov ecx, [ecx].pData

            .UNTIL !ecx     ;// ecx is now zero again

        .ENDIF

    ;// get the chain source

        GET_PIN [ebx].pPin, edx ;// get the chain source
        DEBUG_IF <!!edx>        ;// input is not connected

    ;// account for recording

        .IF edi

            mov [edi].num_pin, 2
            or [edi].mode, -1
            mov [edi].con.pin, ebx  ;// store input pin
            mov [edi+SIZEOF UNREDO_PIN].con.pin, edx    ;// store output pin
            add unredo_pRecorder, SIZEOF UNREDO_PIN_CONNECT + SIZEOF UNREDO_PIN

        .ENDIF

    ;// locate the pin that points to us

        and [ebx].dwStatus, NOT PIN_BUS_TEST    ;// clear the bus mask now
        cmp ebx, [edx].pPin                     ;// does it point at us ??
        jne unconnecting_an_input_further_in

    unconnecting_first_input_in_chain:  ;// we are the first pin in the chain

        or ecx, [ebx].pData     ;// get our next data and test for zero
        mov [edx].pPin, ecx     ;// set the source's first in chain

        ;// was there anything there ?
        jnz unconnecting_input_but_there_are_pins_behind_us

    ;// we are the only connection to this pin
    ;// ecx is already zero

        mov [ebx].pPin, ecx     ;// clear our connection

    ;// account for recording, all we have to do is bump the mode to -2

        .IF edi
            dec [edi].mode
        .ENDIF

    ;// invalidate the only other pin

        xchg ebx, edx       ;// swap in with out
        or [ebx].dwHintI, HINTI_PIN_UNCONNECTED

        jmp all_done


    unconnecting_input_but_there_are_pins_behind_us:
    ;// there are more connections after us
    ;// we've already xferred the next connection
    ;// edx = the output put

        xor ecx, ecx                ;// clear for zeroing
        mov [ebx].pPin, ecx         ;// unconnect our source
        mov [ebx].pData, ecx        ;// reset our next connection
        or [edx].dwHintI, HINTI_PIN_CONNECTED   ;// so it get's erased

        jmp all_done

    unconnecting_an_input_further_in:
    ;// there are pins in front of us
    ;// edx points at the chain source
    ;// ecx is still zero

        or [edx].dwHintI, HINTI_PIN_CONNECTED   ;// so it get's erased

    ;// locate the pin that points at us

        mov edx, [edx].pPin ;// get the first pin in the chain
    @@:
        cmp ebx, [edx].pData
        je @F
        mov edx, [edx].pData
        cmp ebx, [edx].pData
        je @F
        mov edx, [edx].pData
        jmp @B
    @@:
        ;// edx points at us
        mov eax, [ebx].pData    ;// load our next in chain
        mov [edx].pData, eax    ;// store in previous

        mov [ebx].pPin, ecx     ;// clear our pin
        mov [ebx].pData, ecx    ;// clear our next in chain

    ;// jmp all_done

all_done:

    or [ebp].pFlags, PFLAG_TRACE        ;// always schedule a trace
    invoke context_SetAutoTrace         ;// schedule a unit trace

    ;// to make matters worse ...
    ;// if we are inside a closed group
    ;// we have to tell the group to attach it's pins
    ;// otherwise we get a nasty problem
    ;// now is the time to do this because we are still in play sync

    .IF ebp != OFFSET master_context && play_status & PLAY_PLAYING

        mov esi, [ebp].pGroup       ;// get group's osc pointer
        ASSUME esi:PTR OSC_OBJECT
        ITERATE_PINS                ;// scan it's pins

            .IF [ebx].dwStatus & PIN_OUTPUT ;// output pin ?

                push esi
                push ebx
                mov esi, [ebx].dwUser   ;// get the pin interface assigned to this pin
                invoke pinint_Calc      ;// call the calc for that pin interface, it'll do the rest
                pop ebx
                pop esi

            .ENDIF

        PINS_ITERATE

    .ENDIF

;// that's it

    ret

pin_Unconnect ENDP

;//
;//     pin_Unconnect
;//
;//
;////////////////////////////////////////////////////////////////////








ASSUME_AND_ALIGN





END
