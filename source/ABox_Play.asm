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
;//  ABox_Play.asm
;//
;//
;//
;// TOC:
;//
;// play_Initialize
;// play_Destroy
;//
;// play_PrePlay
;// play_Start
;// play_Stop
;// play_Invalidate_osc
;// play_wm_abox_xfer_ic_to_i_proc
;// play_Calc
;// play_DoACalc
;// play_Trace
;// play_Trace2
;// play_Trace3
;//
;// play_Proc


OPTION CASEMAP:NONE

.586
.MODEL FLAT

        .NOLIST
        INCLUDE <ABox.inc>
        INCLUDE <hardware_debug.inc>
        INCLUDE <midi2.inc>
        INCLUDE <gdi_pin.inc>
        .LIST

;// set to 1 to turn off
H_LOG_TRACE_STATUS = 1
;// set to 2 to turn on



;//                  the play thread manages all input and output synchronization
;// play thread      the thread is created when the app starts
;//


comment ~ /*

    this thread manages the playing of a circuit
    osc_objects that are capable of being played must register with this thread when they are created
    when the osc_objects are destroyed, they must unregister

    the default osc_Ctor and Dtor take care of this by looking at osc_base.data.dwFlags BASE_PLAYABLE

    the register works by using the oscR  (osc_object.pNextR) slist

    this system also allows a new circuit to be installed without stopping play
    this is accomplished by checking for an empty oscR after waiting

    the app communicates with this thread via the play_status flags
    the app may set certain bits and the play system will respond accordingly

    this thread also determines the correct calc order
    this is accomplished by setting the PLAY_TRACE flag.
    play_Proc will call the play_Trace function when it get around to it


*/ comment ~

.DATA

    ;// interface with application

        play_status   dd 0          ;// flags for synchronization and communcation between threads

    ;// these are used for the realtime graphics

    ;//
    ;// thread private data     ;// it's on the global heap, but used only here just the same
    ;//


    ;// play event can be signaled to stop waiting

        play_hEvent dd  0

    ;// here's the read id

        play_threadID dd 0 ;// handle of the play thread

        play_Proc PROTO STDCALL pValue:dword
        play_Calc PROTO

    ;// these two functions determine the calculation order

        play_Trace PROTO
        play_Trace2 PROTO
        ;//play_Trace3 PROTO

    ;// timer based items

        play_prevTime   dd  0   ;// milliseconds since windows started
        play_cumeTime   dd  0   ;// milliseconds since we last checked

    ;// clock cycle object monitoring

        play_ClockMonitor   dd  0   ;// set to one to use
        play_LastClock      dd  0   ;// total for the last interation

        IFDEF DEBUGBUILD    ;// this is ored onto the control word
        play_fpu_control    dd  7Fh AND NOT(FPU_EXCEPTION_STACK OR FPU_EXCEPTION_ZERO_DIVIDE ) ;//  OR FPU_EXCEPTION_OVERFLOW) ;//  OR FPU_EXCEPTION_INVALID)
        ELSE
        play_fpu_control    dd  07Fh    ;// real presicion, no un masked exeptions
        ENDIF

    ;// ABOX233: sample position counter for midi objects

        play_sample_position    dd   2 DUP (0)  ;// qword

    ;// data for menus and stuff

        play_szPlay db '&Play',0
        play_szStop db '&Stop',0

        ALIGN 4

.CODE





;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////




ASSUME_AND_ALIGN
play_Initialize PROC

    ;// create our thread

        invoke CreateThread, 0, 0, OFFSET play_Proc, ecx, 0, OFFSET play_threadID

    ;// that's it

    ret

play_Initialize ENDP



ASSUME_AND_ALIGN
play_Destroy PROC

    ;// the app is exiting and the window still exists
    ;// our job is to free and close all the allocated resources

    ;// wait for sync

        ENTER_PLAY_SYNC GUI
        or play_status, PLAY_EXIT
        LEAVE_PLAY_SYNC GUI

    ;// that's it

        ret

play_Destroy ENDP



;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
play_PrePlay PROC uses ebp esi edi

    ;// get the current context

        stack_Peek play_context, ebp

    ;// see if we need a trace

        .IF [ebp].pFlags & PFLAG_TRACE
            invoke play_Trace
        .ENDIF

    ;// scan through the c list and call all the preplays
    ;// ya know, this might not be the way to do it
    ;// if we miss this the first time, the object won't get initialized

        slist_GetHead oscC, esi, [ebp]  ;// get the calc head
        .WHILE esi

            xor eax, eax
            OSC_TO_BASE esi, edi

            or eax, [edi].core.PrePlay
            .IF !ZERO?

                call eax

            .ENDIF

            .IF !eax    ;// preplay returns true if we do NOT want to erase data

                ;// we want to zero all the data
                OSC_TO_BASE esi, edi
                mov ecx, [edi].data.ofsOscData
                mov edi, [edi].data.ofsPinData
                sub ecx, edi
                shr ecx, 2
                add edi, esi
                rep stosd

            .ENDIF


            slist_GetNext oscC, esi

        .ENDW

    ;// that's it

        ret

play_PrePlay ENDP


;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
play_Start PROC uses esi edi

        H_LOG_TRACE <play_Start>

    ;// here we want to start playing the circuit

        DEBUG_IF <play_status & PLAY_PLAYING>   ;// already playing

        DEBUG_IF <play_status & PLAY_GUI_SYNC>  ;// not supposed to be synced

        DEBUG_IF <play_status & PLAY_PLAY_SYNC> ;// not supposed to be synced

        IFDEF USE_DEBUG_PANEL
        mov debug_Enabled, 0
        ENDIF

    ;// ABOX233: reset the sample position counter

        and play_sample_position[0], 0
        and play_sample_position[4], 0

    ;// call pre play functions to initialize object data

        invoke play_PrePlay

    ;// open all the devices that need opened

        slist_GetHead hardwareL, edi
        TESTJMP edi, edi, jz done_with_scan

        xor eax, eax

    top_of_loop:

        CMPJMP [edi].numDevices, eax, jz iterate_loop

        mov ebx, [edi].pBase
        ASSUME ebx:PTR OSC_BASE

        CMPJMP [ebx].hard.H_Open, eax,  jz iterate_loop

        push edi
        call [ebx].hard.H_Open

        TESTJMP eax, eax, jnz device_is_bad

    device_is_good:

        BITRJMP [edi].dwFlags, HARDWARE_BAD_DEVICE, jnc iterate_loop

        mov eax, HINTI_OSC_LOST_BAD
        jmp mark_all_attached_oscs

    device_is_bad:

        BITSJMP [edi].dwFlags, HARDWARE_BAD_DEVICE, jc iterate_loop

        mov eax, HINTI_OSC_GOT_BAD

    mark_all_attached_oscs:

    ;// eax must have the good bad status

        push eax

        dlist_GetHead oscZ, ecx, master_context
        .WHILE ecx

            OSC_TO_BASE ecx, edx
            .IF [edx].data.dwFlags & BASE_HARDWARE

                .IF edi == [ecx].pDevice

                    mov eax, [esp]
                    GDI_INVALIDATE_OSC eax, ecx, master_context

                .ENDIF

            .ENDIF

            dlist_GetNext oscZ, ecx

        .ENDW

        pop eax

    iterate_loop:

        slist_GetNext hardwareL, edi
        xor eax, eax
        TESTJMP edi, edi, jnz top_of_loop


    done_with_scan:

    ;// now that all the devices are ready
    ;// we set the play thread flag to playing

        invoke timeGetTime
        mov play_prevTime, eax
        mov play_cumeTime, 0

        or play_status, PLAY_PLAYING

    ;// that's it

        ret

play_Start ENDP



ASSUME_AND_ALIGN
play_Stop PROC uses esi edi ebx

        H_LOG_TRACE <play_Stop>

    ;// if we're not playing now do an error

        DEBUG_IF< !!(play_status & PLAY_PLAYING) >

    ;// stop playing
    ;// wait for the play thread

        ENTER_PLAY_SYNC GUI
        xor play_status, PLAY_PLAYING
        LEAVE_PLAY_SYNC GUI

        IFDEF USE_DEBUG_PANEL
        mov debug_Enabled, -1
        ENDIF

    ;// close all the devices

        slist_GetHead hardwareL, esi
        .WHILE esi

            .IF [esi].hDevice

                push esi
                mov ebx, [esi].pBase
                DEBUG_IF <!!ebx>    ;// ??? supposed to be set
                ASSUME ebx:PTR OSC_BASE
                call [ebx].hard.H_Close

            .ENDIF
            btr [esi].dwFlags, LOG2(HARDWARE_BAD_DEVICE)
            jnc iterate_loop

        mark_all_attached_oscs:

            dlist_GetHead oscZ, ecx, master_context
            .WHILE ecx

                OSC_TO_BASE ecx, edx
                .IF [edx].data.dwFlags & BASE_HARDWARE

                    .IF esi == [ecx].pDevice

                        mov eax, [esp]
                        GDI_INVALIDATE_OSC HINTI_OSC_LOST_BAD, ecx, master_context

                    .ENDIF

                .ENDIF

                dlist_GetNext oscZ, ecx

            .ENDW

        iterate_loop:

            slist_GetNext hardwareL, esi

        .ENDW

    ;// that's it

        ret

play_Stop ENDP


;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////


.DATA

    play_render_counter dd  0   ;// counts calc's

.CODE


;////////////////////////////////////////////////////////////////////
;//                                                     public function
;//
;//     play_Invalidate_osc     osc's call this from osc_calc to signal that they want re blitted
;//
ASSUME_AND_ALIGN
play_Invalidate_osc PROC

    ;// uses edx and eax

    ASSUME esi:PTR OSC_OBJECT

    DEBUG_IF <!!([esi].dwHintOsc & HINTOSC_STATE_ONSCREEN)>
    ;// what ever called this should have checked first

    stack_Peek gui_context, edx
    .IF edx == play_context_stack_top

        clist_Insert oscIC, esi,,[edx]
        or [esi].dwHintIC, INVAL_PLAY_UPDATE

    .ENDIF

    ret

play_Invalidate_osc ENDP
;//
;//
;//     play_Invalidate_osc
;//
;////////////////////////////////////////////////////////////////////





;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;///
;///                            jumped from mainWndProc
;///                            this is a WM message sent by the play thread
;///    WM_ABOX_XFER_IC_TO_I    our task is to flush the IC list, by sending it to the I list
;///                            then call app_Sync to do the rest
;///
ASSUME_AND_ALIGN
play_wm_abox_xfer_ic_to_i_proc PROC ;// STDCALL hWnd, msg, wParam, lParam

    ;// task: xfer IC to I

    stack_Peek gui_context, edx     ;// empty list ?
    clist_GetMRS oscIC, ecx, [edx]

    .IF ecx

        ;// enter the function

        push ebp
        push esi
        push edi
        push ebx

        mov ebp, edx
        mov edi, ecx
        mov esi, ecx
        ASSUME esi:PTR OSC_OBJECT
        ASSUME ebp:PTR LIST_CONTEXT

        ENTER_PLAY_SYNC GUI     ;// have to pause the play thread

        .REPEAT

            clist_GetNext oscIC, esi

            mov ecx, [esi].dwHintIC
            xor eax, eax
            xor edx, edx

            ;// new clocks ?
            btr ecx, LOG2(INVAL_PLAY_CYCLES)
            rcl eax, LOG2(HINTI_OSC_UPDATE_CLOCKS)+1
            or edx, eax
            xor eax, eax

            ;// new picture ?
            btr ecx, LOG2(INVAL_PLAY_UPDATE)
            rcl eax, LOG2(HINTI_OSC_UPDATE)+1
            or edx, eax
            xor eax, eax

            ;// bad now ??
            btr ecx, LOG2(INVAL_PLAY_MAKE_BAD)
            rcl eax, LOG2(HINTI_OSC_GOT_BAD)+1
            or edx, eax
            xor eax, eax

            ;// good now ?
            btr ecx, LOG2(INVAL_PLAY_MAKE_GOOD)
            rcl eax, LOG2(HINTI_OSC_LOST_BAD)+1
            or edx, eax

            .IF !ZERO?
                GDI_INVALIDATE_OSC edx
            .ENDIF

            ;// something with the pins ?
            btr ecx, LOG2(INVAL_PLAY_PIN_UPDATE)
            .IF CARRY?

                ITERATE_PINS
                    mov edx, [ebx].dwHintIC
                    btr edx, LOG2(INVAL_PLAY_PIN_UPDATE)
                    .IF CARRY?
                        mov [ebx].dwHintIC, edx     ;// store the new flags
                        GDI_INVALIDATE_PIN HINTI_PIN_UPDATE_CHANGING
                    .ENDIF

                PINS_ITERATE

            .ENDIF

            cmp esi, edi            ;// done yet ?
            mov [esi].dwHintIC, ecx ;// store the flags too

        .UNTIL ZERO?

        clist_Clear oscIC ,,, [ebp]

        LEAVE_PLAY_SYNC GUI ;// unpause the play thread

    ;// we do this message peek to eliminate mixups in the mouse hover and update

        invoke PeekMessageA, OFFSET app_msg, hMainWnd, 0,0,PM_NOREMOVE
        or eax, eax
        jz need_to_post
        cmp app_msg.message, WM_ABOX_XFER_IC_TO_I
        jne dont_post
    need_to_post:
        invoke app_Sync     ;// tell gui to get to work
    dont_post:

        ;// leave the function

        pop ebx
        pop edi
        pop esi
        pop ebp

    .ELSE   ;// empty list
        invoke app_Sync
    .ENDIF

    xor eax, eax

    ret 10h

play_wm_abox_xfer_ic_to_i_proc ENDP




.DATA

    play_clocks_in  dd  0   ;// stores the start time of calcs

.CODE

;////////////////////////////////////////////////////////////////////
;//
;//
;//     play_Calc
;//


comment ~ /*

    play calc has states

    C   in context      means we are looking at the current context
    L   do clocks       means we show clock cycles
    H   do changing     means we show changing

    if there is a clock cycle object, we do that too

    yC  yL  yH      8 states total
    nC  nL  nH      nC cancels L and H
                    account for 5 states

    to be nice, we should skip graphics if the app is minimized

*/ comment ~

ASSUME_AND_ALIGN
play_Calc PROC uses ebp esi

    ;// get the current play context and calc list
    ;// this function can be called from any context

    stack_Peek play_context, ebp

    ;// see if we need a trace

    .IF [ebp].pFlags & PFLAG_TRACE

        invoke play_Trace
        .IF app_settings.show & SHOW_CLOCKS     ;// trace requires a flushing of clocks
            or master_context.pFlags, PFLAG_FLUSH_CLOCKS;// tag the top level to flush the ic list
        .ENDIF
        .IF app_settings.show & SHOW_CHANGING       ;// trace requires a flushing of changing
            or master_context.pFlags, PFLAG_FLUSH_PINCHANGE;// tag the top level to flush the ic list
        .ENDIF

    .ENDIF

    ;// see if we need to flush anything

    .IF master_context.pFlags & PFLAG_FLUSH_CLOCKS

        dlist_GetHead oscZ, esi, [ebp]
        or ecx, -1
        .WHILE esi
            mov [esi].dwClocks, ecx        ;// this writes 11 to mm field dwClocks
            or [esi].dwHintIC, INVAL_PLAY_CYCLES
            clist_Insert oscIC, esi,,[ebp]  ;// add to invalidate list ?
            dlist_GetNext oscZ, esi
        .ENDW

    .ENDIF

    .IF master_context.pFlags & PFLAG_FLUSH_PINCHANGE

        dlist_GetHead oscZ, esi, [ebp]
        .WHILE esi

            or [esi].dwHintIC, INVAL_PLAY_PIN_UPDATE
            clist_Insert oscIC, esi,,[ebp]  ;// add to invalidate list ?
            ITERATE_PINS
            mov eax, [ebx].dwStatus
            .IF eax & PIN_OUTPUT && !(eax & (PIN_HIDDEN OR PIN_BUS_TEST))
                and eax, NOT PIN_PREV_CHANGING
                mov [ebx].dwStatus, eax
                or [ebx].dwHintIC,INVAL_PLAY_PIN_UPDATE
            .ENDIF
            PINS_ITERATE
            dlist_GetNext oscZ, esi

        .ENDW

    .ENDIF

    ;// get the C head and see if there's anything there

        xor esi, esi                        ;// clear for testing
        slist_OrGetHead oscC, esi, [ebp]    ;// get and test the head
        jz play_calc_done                   ;// exit if empty list

        ASSUME esi:PTR OSC_OBJECT


    ;// determine how to calculate

        cmp ebp, gui_context_stack_top  ;// check if we are looking at what's being calced
        mov eax, app_settings.show      ;// get the app flags too
        jne play_calc_nLnH              ;// if not looking, then do a raw calc

    ;// we are looking at this context

        test eax, SHOW_CLOCKS           ;// showing clocks ?
        jnz play_calc_yL

play_calc_nL:

        test eax, SHOW_CHANGING         ;// showing changing
        jz play_calc_nLnH


;// no clocks
;// yes changing
play_calc_nLyH:

    .REPEAT

        xor eax, eax
        OSC_TO_BASE esi, edi

    ;// don't bother if off screen

        or eax, [esi].dwHintOsc     ;// test the on screen bit
        .IF SIGN?                   ;// ON SCREEN is the sign bit

        ;// call the calc for this object

            invoke [edi].core.Calc  ;// call it's calc function
            FPU_STACK_TEST          ;// what ever just calced did not clean up the stack

        ;// look for non busessed, not hidden, output pins

            ITERATE_PINS

                mov ecx, [ebx].dwStatus
                .IF ecx & PIN_OUTPUT && !(ecx & (PIN_HIDDEN OR PIN_BUS_TEST))

                ;// compare the changing status bits
                ;// if different, schedule for redraw
                    shr ecx, LOG2(PIN_CHANGING)
                    .IF !PARITY?    ;// odd number of one bits

                        shr ecx, 1  ;// move prev_changing into carry
                        .IF CARRY?  ;// bits were   01
                            or [ebx].dwStatus, PIN_PREV_CHANGING
                        .ELSE       ;// bits were   10
                            and [ebx].dwStatus, NOT PIN_PREV_CHANGING
                        .ENDIF

                        ;// set the inval flags and add to list
                        or [ebx].dwHintIC, INVAL_PLAY_PIN_UPDATE
                        or [esi].dwHintIC, INVAL_PLAY_PIN_UPDATE

                        clist_Insert oscIC, esi,,[ebp]  ;// add to invalidate list

                    .ENDIF

                .ENDIF

            PINS_ITERATE

        .ELSE                       ;// object was off screen

            invoke [edi].core.Calc  ;// just do the calc
            FPU_STACK_TEST          ;// what ever just calced did not clean up the stack

        .ENDIF

    ;// iterate the calc list

        slist_GetNext oscC, esi

    .UNTIL !esi

    jmp play_calc_done






;// no clocks
;// no changing
ALIGN 16
play_calc_nLnH:

    .REPEAT

        OSC_TO_BASE esi, edi
        invoke [edi].core.Calc
        FPU_STACK_TEST          ;// what ever just calced did not clean up the stack
        slist_GetNext oscC, esi

    .UNTIL !esi
    jmp play_calc_done




ALIGN 16
play_calc_yL:

    test eax, SHOW_CHANGING
    jz play_calc_yLnH

;// yes clocks
;// yes changing
play_calc_yLyH:


    .REPEAT

        xor eax, eax
        OSC_TO_BASE esi, edi

    ;// don't bother if off screen

        or eax, [esi].dwHintOsc     ;// test the on screen bit
        .IF SIGN?                   ;// ON SCREEN is the sign bit

        ;// keep track of time and do the calc

            rdtsc                   ;// get current time
            mov play_clocks_in, eax ;// store in memory

            invoke [edi].core.Calc  ;// call it's calc function

            FPU_STACK_TEST          ;// what ever just calced did not clean up the stack

            IFDEF DEBUGBUILD

                invoke memory_Verify, esi
                DEBUG_IF <eax>      ;// whatever just calced overwrote memory

            ENDIF

            rdtsc                        ;// get time now
            sub eax, play_clocks_in      ;// subtract start time
            mov edx, [esi].dwClocks      ;// load previous clock cycle field
            .IF SIGN?                    ;// negative ? (usually is, fall through works for us)
                neg eax
            .ENDIF
            shr eax, LOG2(SAMARY_LENGTH) ;// shift down to clocks per sample
            mov ecx, edx                 ;// copy prev field
            and edx, CLOCK_CYCLE_MASK    ;// mask out the prev value, but keep the prev display mode
            or eax, edx                  ;// merge in the new cycle count
            .IF eax!=ecx                 ;// different? new != old?
                or [esi].dwHintIC, INVAL_PLAY_CYCLES
                mov [esi].dwClocks, eax         ;// store new value in object
                clist_Insert oscIC, esi,,[ebp]  ;// add to invalidate list ?
            .ENDIF

        ;// look for non busessed, not hidden, output pins

            ITERATE_PINS

                mov ecx, [ebx].dwStatus
                .IF ecx & PIN_OUTPUT && !(ecx & (PIN_HIDDEN+PIN_BUS_TEST))

                ;// compare the changing status bits
                ;// if different, schedule for redraw
                    shr ecx, LOG2(PIN_CHANGING)
                    .IF !PARITY?    ;// odd number of one bits

                        shr ecx, 1  ;// move prev_changing into carry
                        .IF CARRY?  ;// bits were   01
                            or [ebx].dwStatus, PIN_PREV_CHANGING
                        .ELSE       ;// bits were   10
                            and [ebx].dwStatus, NOT PIN_PREV_CHANGING
                        .ENDIF

                        ;// set the inval flags and add to list
                        or [ebx].dwHintIC, INVAL_PLAY_PIN_UPDATE
                        or [esi].dwHintIC, INVAL_PLAY_PIN_UPDATE

                        clist_Insert oscIC, esi,,[ebp]  ;// add to invalidate list

                    .ENDIF

                .ENDIF

            PINS_ITERATE

        .ELSE                       ;// object was off screen

            invoke [edi].core.Calc  ;// just do the calc
            FPU_STACK_TEST          ;// whatever just calced did not clean up the stack
            IFDEF DEBUGBUILD
                invoke memory_Verify, esi
                DEBUG_IF <eax>      ;// whatever just calced overwrote memory
            ENDIF

        .ENDIF

    ;// iterate the calc list

        slist_GetNext oscC, esi

    .UNTIL !esi

    jmp play_calc_done



;// yes clocks
;// no changing
ALIGN 16
play_calc_yLnH:

    .REPEAT

        xor eax, eax
        OSC_TO_BASE esi, edi
        or eax, [esi].dwHintOsc         ;// don't bother if off screen
        jns play_calc_yLnH_off_screen   ;// INVAL ONSCREEN is the sign bit

        ;// object is currently on screen

            rdtsc                   ;// get current time
            mov play_clocks_in, eax     ;// store in memory

            invoke [edi].core.Calc  ;// call it's calc function
            FPU_STACK_TEST          ;// what ever just calced did not clean up the stack

            rdtsc                        ;// get time now
            sub eax, play_clocks_in      ;// subtract start time
            mov edx, [esi].dwClocks      ;// load previous clock cycle field
            .IF SIGN?                    ;// negative ? (usually is, fall through works for us)
                neg eax
            .ENDIF
            shr eax, LOG2(SAMARY_LENGTH) ;// shift down to clocks per sample
            mov ecx, edx                 ;// copy prev field
            and edx, CLOCK_CYCLE_MASK    ;// mask out the prev value, but keep the prev display mode
            or eax, edx                  ;// merge in the new cycle count
            .IF eax!=ecx                 ;// different? new != old?
                or [esi].dwHintIC, INVAL_PLAY_CYCLES
                mov [esi].dwClocks, eax         ;// store new value in object
                clist_Insert oscIC, esi,,[ebp]  ;// add to invalidate list ?
            .ENDIF

            jmp play_calc_yLnH_next_osc

        ;// object was off screen
        play_calc_yLnH_off_screen:

            invoke [edi].core.Calc  ;// just do the calc
            FPU_STACK_TEST          ;// what ever just calced did not clean up the stack

    play_calc_yLnH_next_osc:

        slist_GetNext oscC, esi

    .UNTIL !esi

    ;// jmp calc_done

play_calc_done:

        ret

play_Calc ENDP






;////////////////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
play_DoACalc PROC

        H_LOG_TRACE <play_DoACalc______ENTER>

    ;// initialize the fpu

        fninit
        fldcw WORD PTR play_fpu_control

    ;// check if there's a clock cycle object

        .IF play_ClockMonitor
            rdtsc
            push eax
        .ENDIF

    ;// call the calc function

        invoke play_Calc

    ;// now we check for opened and assigned hardware devices that need a post calc

        slist_GetHead hardwareL, esi
        .WHILE esi

            mov edi, [esi].pBase
            ASSUME edi:PTR OSC_BASE
            mov edi, [edi].hard.H_Calc
            .IF edi && [esi].hDevice && [esi].numDevices
                push esi
                call edi
            .ENDIF
            slist_GetNext hardwareL, esi

        .ENDW

    ;// check again if there's a clock cycle object

        .IF play_ClockMonitor

            rdtsc
            pop edx
            sub edx, eax
            .IF SIGN?
                neg edx
            .ENDIF
            mov play_LastClock, edx

        .ENDIF

    ;// ABOX233: update the sample position counter

        add play_sample_position[0], SAMARY_LENGTH
        adc play_sample_position[4], 0

    ;// now check if we need to render anything
    ;// we have to render if any flush flags were on
    ;// otherwise, we use the countdown timer

        .IF master_context.pFlags & (PFLAG_FLUSH_CLOCKS OR PFLAG_FLUSH_PINCHANGE)

            ;// turn off flush flags
            and master_context.pFlags, NOT (PFLAG_FLUSH_CLOCKS OR PFLAG_FLUSH_PINCHANGE)

            ;// ABOX 226: after file load we have to do this twice
            test master_context.pFlags, PFLAG_FLUSH_PINCHANGE_1
            jz force_the_transfer
            and master_context.pFlags, NOT PFLAG_FLUSH_PINCHANGE_1
            or master_context.pFlags, PFLAG_FLUSH_PINCHANGE
            jmp force_the_transfer

        .ENDIF

    ;// do the update counter and see if we xfer

        dec play_render_counter     ;// decrease the counter
        .IF SIGN?                   ;// if tripped, then call play_render

            ;// reset the count
            inc play_render_counter
            .IF !(app_settings.show & SHOW_UPDATE_FAST)
                add play_render_counter, 9
            .ENDIF

            ;// now we invalidate all the items in oscIC
            ;// thus putting them in oscI

        force_the_transfer: ;// jumped to from master context pFlags test

            stack_Peek gui_context, ecx     ;// get what we're currently looking at
            clist_GetMRS oscIC, edx,[ecx]   ;// see if there are any invalid items
            .IF edx
                invoke PostMessageA, hMainWnd, WM_ABOX_XFER_IC_TO_I, 0, 0
            .ENDIF

        .ENDIF

    ;// that's it

        H_LOG_TRACE <play_DoACalc______EXIT>

        ret

play_DoACalc ENDP


;/////////////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////////////
;//
;//     play_Trace
;//

IFDEF USE_DEBUG_PANEL

.DATA

    EXTERNDEF play_trace_1_count:DWORD
    EXTERNDEF play_trace_2_count:DWORD
    EXTERNDEF play_trace_4_count:DWORD
    EXTERNDEF play_trace_clocks:DWORD

    play_trace_1_count  dd  0   ;// play_trace
    play_trace_2_count  dd  0   ;// play_trace_2
    play_trace_4_count  dd  0   ;// num of objects that were inserted
    play_trace_clocks   dd  0   ;// total clocks count

.CODE

ENDIF



ASSUME_AND_ALIGN
play_Trace PROC PRIVATE uses esi edi

    ;// algorithm:
    ;//
    ;// pass 1
    ;//
    ;//     using the Z list, reset the C list
    ;//
    ;// pass 2
    ;//
    ;//     for every object in the R list
    ;//     recursively trace it's inputs
    ;//         ABox220: if object is a tracker dest, trace it's source
    ;//     every time a recurse is called, a running counter is increased
    ;//     a 'in_trace' flag is set as well
    ;//     if the running counter is greater than the depth
    ;//         replace the depth with the counter
    ;//
    ;//     ABOX232: force HID objects to be at start of list
    ;//
    ;//     intersting: this method finds the longest non intersecting route
    ;//                 to the final destination
    ;//
    ;// pass 3  doesn't work, not used
    ;//
    ;//     put feedback paths in proper order
    ;//     for every object with the following criteria
    ;//         depth != 0
    ;//         ! playable
    ;//         must have inputs
    ;//         must have outputs
    ;//         all inputs must be to objects with a lower depth (signed)
    ;//         all outputs must be to objects with a lower depth (signed)
    ;//             replace depth with lowest input-1
    ;//
    ;// pass 4
    ;//
    ;//     insert items in the C list in descending order


    DEBUG_IF <ebp !!= play_context_stack_top>   ;// supposed to be set
    ASSUME ebp:PTR LIST_CONTEXT

IFDEF USE_DEBUG_PANEL

    .IF ebp == OFFSET master_context
        mov play_trace_1_count, 1   ;// play_trace
        mov play_trace_2_count, 0   ;// play_trace_2
        mov play_trace_4_count, 0   ;// num objects that were inserted
        rdtsc
        mov play_trace_clocks, eax
    .ELSE
        inc play_trace_1_count
    .ENDIF

ENDIF


    pass_1:

        xor eax, eax
        dlist_GetHead oscZ, esi, [ebp]      ;// get the Z head
        mov slist_Head(oscC,[ebp]), eax     ;// clear the calc list
        and [ebp].pFlags, NOT PFLAG_TRACE   ;// clear the trace flag

        TESTJMP esi, esi, jz all_done       ;// is there a zlist ?
        .REPEAT         ;// scan the z list

            mov slist_Next(oscC,esi), eax   ;// clear nextC
            mov [esi].depth, eax            ;// clear the depth
            dlist_GetNext oscZ, esi         ;// iterate

        .UNTIL !esi

    pass_2:

        xor edi, edi                    ;// running counter
        slist_GetHead oscR, esi, [ebp]  ;// recursive iterator
        .WHILE esi
            invoke play_Trace2
            DEBUG_IF <edi>              ;// must return as zero
            .IF [esi].pBase == OFFSET osc_HID
                mov [esi].depth, 7FFFFFFFh  ;// always insert hids at start
            .ENDIF
            slist_GetNext oscR, esi
        .ENDW

    pass_3:

    ;// invoke play_Trace3

    pass_4:

        dlist_GetHead oscZ, esi, [ebp]
        .WHILE esi

            .IF [esi].depth

IFDEF USE_DEBUG_PANEL
    inc play_trace_4_count
ENDIF

                slist_InsertSorted oscC, SIGNED_DESCENDING, esi,depth,,,,[ebp]

            .ENDIF
            dlist_GetNext oscZ, esi

        .ENDW

    all_done:


IFDEF USE_DEBUG_PANEL
        rdtsc
        sub eax, play_trace_clocks
        .IF SIGN?
            neg eax
        .ENDIF
        shr eax, 18 ;// quarter million
        mov play_trace_clocks, eax
ENDIF

        ret


play_Trace ENDP

ASSUME_AND_ALIGN
play_Trace2 PROC PRIVATE

    ;// the task is to trace back into our connected inputs

    ;// pass 2
    ;//
    ;//     for every object in the R list
    ;//     recursively trace it's inputs
    ;//         ABox220: if objects is a tracker dest, trace it's source
    ;//     every time a recurse is called, a running counter is increased
    ;//     a 'in_trace' flag is set as well
    ;//     if the running counter is greater than the depth
    ;//         replace the depth with the counter
    ;//
    ;//     intersting: this method finds the longest non intersecting route
    ;//                 to the final destination

    ASSUME esi:PTR OSC_OBJECT   ;// esi is object we are currently tracing

    CMPJMP slist_Next(oscC,esi), 0, jnz J3  ;// make sure we're not already hit

IFDEF USE_DEBUG_PANEL
    inc play_trace_2_count
ENDIF

    inc edi                         ;// update the counter
    inc slist_Next(oscC,esi)        ;// flag ourselves as 'in_trace'
    CMPJMP [esi].depth, edi, jae J1 ;// check our depth, skip if already above

    mov [esi].depth, edi            ;// set the new depth

J1: xor ecx, ecx
    ITERATE_PINS

        DEBUG_IF <ecx>  ;// supposed to be zero !!

        TESTJMP [ebx].dwStatus, PIN_OUTPUT, jnz J2  ;// skip if output
        OR_GET_PIN [ebx].pPin, ecx              ;// are we a connected input ?
        jz J2                                   ;// skip if not connected
        DEBUG_IF <[ebx].dwStatus & PIN_HIDDEN>  ;// connected pins are not supposed to be hidden

;// USE_TRACE2_228 EQU 1


IFDEF USE_TRACE2_228

        ;// old version (pre ABox229)
        ;// suffered from huge recursion with complicated circuits


                push ebx            ;// save the pin
                PIN_TO_OSC ecx, esi ;// get the input's osc
                invoke play_Trace2  ;// call recursively
                pop ebx             ;// retrieve the pin we were on
                xor ecx, ecx        ;// must keep cleared
                PIN_TO_OSC ebx, esi ;// retrieve our osc


ELSE    ;//  USE_TRACE2_228, use trace 229


        ;// begin new version (ABox229)

        ;// check if we have already seen this pin
        ;// test is: if input pins are connected to same object

        ;// ecx is the pin we are connected to
        ;// ebx is the pin we on now
        ;// pins iterate is scanning backwards
        ;// esi is our current object

                PIN_TO_OSC ecx, edx ;// get the osc our pin is connected to

            push ebx            ;// save the pin

        T0:     xor eax, eax            ;// clear for testing
        T1:     add ebx, SIZEOF APIN    ;// previous pin
                CMPJMP ebx, [esi].pLastPin, jae T2  ;// ok to recurse
                TESTJMP [ebx].dwStatus, PIN_OUTPUT OR PIN_HIDDEN, jnz T1    ;// skip output pins
                ORJMP eax, [ebx].pPin, jz T1    ;// skip unconnected pins
                CMPJMP (APIN PTR [eax]).pObject, edx, jne T0    ;// same as osc we want to work with ?
                jmp T3                  ;// yes: do not recurse

        T2:     mov ebx, [esp]      ;// retrieve the pin after the above scan
                PIN_TO_OSC ecx, esi ;// get the input's osc
                invoke play_Trace2  ;// call recursively

        T3:     pop ebx             ;// retrieve the pin we were on
                xor ecx, ecx        ;// must keep cleared
                PIN_TO_OSC ebx, esi ;// retrieve our osc

ENDIF   ;//  USE_TRACE2_228 or 229




J2: PINS_ITERATE

    ;// check for tracker destinations
    CMPJMP [esi].pBase, OFFSET osc_MidiIn2, je check_for_tracker

J4: dec slist_Next(oscC,esi);// set ourselves as not traced
    DEBUG_IF <!!ZERO?>      ;// increased it twice
    dec edi                 ;// decrease the counter
    DEBUG_IF<SIGN?>         ;// lost track

J3: ret



ALIGN 16
check_for_tracker:

    ASSUME esi:PTR MIDIIN_OSC_MAP

    mov eax, [esi].dwUser           ;// get dwUser
    and eax, MIDIIN_INPUT_TEST      ;// remove extra stuff
    cmp eax, MIDIIN_INPUT_TRACKER   ;// is input a tracker ?
    jne J4                          ;// exit if not

    mov eax, [esi].midiin.tracker.pTracker  ;// get the context
    DEBUG_IF <!!eax>                ;// supposed to be set !!
    ASSUME eax:PTR MIDIIN_TRACKER_CONTEXT

    mov eax, [eax].pSourceObject    ;// get the source object
    test eax, eax                   ;// make sure there is one
    jz J4                           ;// exit if no source object

    ;// now we have eax as the source object for the tracker

    push esi            ;// preserve esi
    mov esi, eax        ;// set the new esi as the source object
    invoke play_Trace2  ;// call recursively
    pop esi             ;// retrieve our osc
    jmp J4              ;// exit to de-tracer


play_Trace2 ENDP

comment ~ /*



AJT: at one time is was possible to order feedback paths 'correctly'
    turns out that there is no general definition of 'correct'
    play_Trace3 was the last attempt
    it may still work ... but it's commented out for now


ASSUME_AND_ALIGN
play_Trace3 PROC uses ebp

    ASSUME ebp:PTR LIST_CONTEXT

    ret

    ;// pass 3
    ;//
    ;//     put feedback paths in proper order
    ;//     for every object with the following criteria
    ;//         depth != 0
    ;//         ! playable
    ;//         must have inputs
    ;//         must have outputs
    ;//         all inputs must be to objects with a lower depth (signed)
    ;//         all outputs must be to objects with a lower depth (signed)
    ;//             replace depth with lowest input-1

        xor edx, edx    ;// tracks current depth
        xor ecx, ecx    ;// pin's connection

    top_of_trace:   ;// repeated scans until done

        xor edi, edi        ;// edi has 3 flags
        dlist_GetHead oscZ, esi, [ebp]

    top_of_osc:     ;// scanning the z list

        or edx, [esi].depth     ;// depth != 0
        jz done_with_osc

        mov ebp, 7FFFFFFFh      ;// ebp holds lowest input depth
        OSC_TO_BASE esi, eax    ;// not playable
        test [eax].data.dwFlags, BASE_PLAYABLE
        jnz done_with_osc       ;// don't do playable objects

    ITERATE_PINS    ;// scanning pins

        DEBUG_IF <ecx>  ;// ecx is supposed to be zero

        OR_GET_PIN [ebx].pPin, ecx  ;// pin must be connected
        .IF !ZERO?                  ;// done if not connected

            .IF [ebx].dwStatus & PIN_OUTPUT ;// are we output or input ?

                ;// we are in output pin, so ecx is the first input pin

                or edi, 1       ;// set the output flag

                .REPEAT             ;// loop through the output chain
                PIN_TO_OSC ecx, eax     ;// ecx iterates the ouput chain
                cmp [eax].depth, edx    ;// lower depth ?
                jge done_with_osc       ;// jump if not (output to higher depth)
                mov ecx, [ecx].pData    ;// get next pin in output chain
                .UNTIL !ecx             ;// loop until done

                ;// if we hit this, all outputs were to lower depths

            .ELSE

                ;// we are an input pin, so ecx is the only output

                or edi, 2           ;// set the input flag

                PIN_TO_OSC ecx, eax     ;// get the osc
                cmp [eax].depth, edx    ;// check it's depth
                jge done_with_osc       ;// done with osc if greater

                mov eax, [eax].depth    ;// if we hit this, we may have a lower value
                cmp ebp, eax        ;// check current lowest depth with this osc's depth
                jle done_with_pin   ;// jump if a higher depth
                mov ebp, eax        ;// set the new lowest depth

            .ENDIF

        done_with_pin:

        xor ecx, ecx    ;// must keep clear
        .ENDIF

    PINS_ITERATE

        ;// if we hit this, we may have to replace the depth

        mov eax, edi
        and eax, 3
        sub eax, 3
        jnz done_with_osc

    ;// cmp ebp, 7FFFFFFFh
    ;// je done_with_osc

        or edi, 4   ;// set the we_replaced flag
        dec ebp     ;// lowest depth - 1
        .IF ZERO?   ;// make sure we never set as zero
            dec ebp ;// use neg1 instead
        .ENDIF
        mov [esi].depth, ebp    ;// set the osc's depth

    done_with_osc:

        dlist_GetNext oscZ, esi
        xor edx, edx    ;// must keep clear
        and edi, 4
        mov ecx, edx
        or esi, esi
        jnz top_of_osc

    ;// now we check for wheather or not we scan again

        test edi, 4         ;// did we replace anything ?
        mov ebp, [esp]      ;// reload the list context while we're here
        jnz top_of_trace    ;// have to repeat until we don't adjust anything

    ;// presto, we're done

        ret

play_Trace3 ENDP
*/ comment ~



;//
;//
;//     play_Trace
;//
;////////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
play_Proc PROC STDCALL uses esi edi ebx pValue:dword


    ;// set the start up priority
    ;// we always run at a SLIGHTLY higher priority

        invoke GetCurrentThread
        invoke SetThreadPriority, eax, 15  ;// THREAD_PRIORITY_TIME_CRITICAL
        DEBUG_IF<!!eax> ;// couldn't set priority

    ;// create our event

        invoke CreateEventA, 0, 0, 0, OFFSET play_szPlay
        mov play_hEvent, eax

    ;// this is just one big loop

    .WHILE ! ( play_status & PLAY_EXIT )

        .IF play_status & PLAY_PLAYING      ;// are we playing ?

            H_LOG_TRACE <_>

            ENTER_PLAY_SYNC PLAY        ;// we're playing so we enter sync

            invoke hardware_Ready       ;// check if any devices are ready

            test eax, READY_DO_NOT_CALC ;// anyone telling us not to continue ?
            jnz wait_for_a_while

            test eax, READY_BUFFERS     ;// can calc now
            jnz can_calc_now

            ;// no buffers, no timer, see if we have an impatient file object

            slist_GetHead oscR, esi, master_context ;// get the global R head
            xor eax, eax
            .WHILE esi
                OSC_TO_BASE esi, ebx
                or eax, [ebx].data.dwFlags
                slist_GetNext oscR, esi
            .ENDW
            test eax, BASE_NO_WAIT      ;// any of the devices imapatient ?
            jz check_the_timer          ;// jump to timer if not

        can_calc_now:

            mov play_cumeTime, 0
            invoke play_DoACalc
            jmp wait_for_a_while

        check_the_timer:        ;// check the timer

            mov ebx, play_prevTime  ;// get the prev time
            invoke timeGetTime      ;// get the now time
            mov play_prevTime, eax  ;// store as pervtime
            add eax, play_cumeTime  ;// add cume time
            sub eax, ebx            ;// subtract to get elasped
            cmp eax, 23             ;// see if it's time
            mov play_cumeTime, eax  ;// store cume time
            jae can_calc_now

        wait_for_a_while:

            LEAVE_PLAY_SYNC PLAY        ;// we're playing so we enter sync

            invoke WaitForSingleObject, play_hEvent, 5  ;// SLEEP_TIME_PLAY
            invoke ResetEvent, play_hEvent

        .ELSE   ;// not playing

            invoke WaitForSingleObject, play_hEvent, 25 ;// SLEEP_TIME_NOPLAY
            invoke ResetEvent, play_hEvent

        .ENDIF

    ;////////////////////////////////////////////////
    ;////////////////////////////////////////////////
    ;///
    ;///     that's about all there is to it
    ;///     we exit this loop when PLAY_EXIT is hit

    .ENDW

    ;// destroy our event

        invoke CloseHandle, play_hEvent

    ;// we've exited the above loop
    ;// this exit's the thread

        and play_status, NOT PLAY_EXIT  ;// turn the exit flag off
        invoke ExitThread, 0

play_Proc ENDP

;///////////////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN


END

