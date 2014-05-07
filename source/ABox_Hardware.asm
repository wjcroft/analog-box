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
;// ABox_Hardware.asm
;//
;//
;// TOC
;//
;// hardware_CanCreate
;// hardware_Initialize
;// hardware_Destroy
;// hardware_AttachDevice
;// hardware_DetachDevice
;// hardware_Ready
;// hardware_FillInDeviceList
;// hardware_ReplaceDeviceWith



OPTION CASEMAP:NONE

.586
.MODEL FLAT

    .NOLIST
    include <Abox.inc>
    include <Com.inc>
    include <wave.inc>
    include <hardware_debug.inc>
    .LIST

.DATA

    ;// this is the master list of devices

    slist_Declare hardwareL

comment ~ /*


    this section manages the devices
    it's responsiblities are:

        locate all acceptable devices
        open and close devices as required
        allocate devices to objects on request
        return queries as to wheather or not a device can be created
        add buttons to popup menus with acceptable devices to switch to
        perform the switching

    here's how this works:

        the device list tells us what is available in the computer

        it is: an slist of HARDWARE_DEVICEBLOCK structs,
        accessed via slist_ macros as hardwareL

        devices are assumed to run by themselves and must contain the correct support functions
        ( the OSC_BASE.H_xxx functions )

        hardware initialize:

            only called once at program start up
            this function first scans through baseB and calls all the H_Ctor functions it can find.

        osc_base.H_Ctor:

            Each is resposible for finding acceptable devices to add to the device list.
            When an acceptable device is found:
                H_Ctor must allocate a new entry
                the pBase, object ID, and flags are filled in.
                The text name of the device is filledin ,
                then any and all private data the device needs to operate.

        osc_object.Ctor:

            when the osc_object is constructed,
            it asks hardware for a device by calling hardware_GetDevice with a desired ID
            GetDevice returns a pointer to the devices block which the osc.Ctor must
            store as THE FIRST OSC.DATA element.

            this way, osc_object knows the name of the device, and where it can find data
            and the hardware knows what devices are in use

        harware_GetDevice:

            called by osc.Ctors, this function scans the device list for matching base classes.
            when a match is found, it checks wheather or not the devices is already assigned
            and wheather is can be shared by multiple objects.

            if the device can be used, numDevices is increamented and the device_block pointer
            returned in eax.

            if there are no devices available, this functions returns zero

        play_start:

            calls preplay for all objects
            opens and starts all the devices
            then tells the play thread to use the playing logic

        hardware_Ready:

            play_proc calls this often.
            calls each open and assigned device's H_ready function.
            devices that are not assigned are closed.
            devices that are closed and (newly) assigned are opened (as not ready).
            devices that cannot be opened are marked as BAD and a count down is
            started that will try to reopen the device periodicly.

            this funtion returns flags that tell play_proc how to proceed

        osc_base.Calc:

            play_proc calls osc_object.Calc
            each osc_Calc knows how to find it's buffer and writes to it appropriately

        osc_base.H_Calc:

            some objects have a post calc routine that actually writes data to the hardware device
            this is called after all the objects have been calced

        osc_base.Dtor

            when osc_object is destroyed, it decreases the num_devices count.
            hardware_ready will take care of closing the device.

        play_stop:

            stops and closes all the devices
            and marks all devices as good

        hardware_Destroy:

            calls all the H_Dtor functions it can find


    for querying creation of devices from menus, we use

        hardware_CanCreate:

            returns 1 if the device can be created
            this simply means that there is a device available, either shared or not shared
            it does not nessirily mean that the object can be opened.

    for the switch to menus we have:

        hardware_AppendContext:

            locates matching base classes and adds buttons to the currently exiting popup_hWnd
            buttons that cannot be switched to are disabled, the device for the current object
            is enabled. command ID's are assigned in order starting at some number high enough
            to filter out key strokes
            This function returns the new popup window size in eax, ebx
            So it must be called last in the initMenu function.

        hardware_DeviceFromMenuID:

            convertes the command ID back to the device pointer.
            This intermediate step is nessessary so osc_base.command can determine if the user
            clicked on the same object

        hardware_ChangeDeviceTo:

            this function transfers an object from one device to another.




*/ comment ~



.CODE

PROLOGUE_OFF
ASSUME_AND_ALIGN
hardware_CanCreate PROC STDCALL pBase:PTR OSC_BASE, bWillReplace:DWORD

    ;// destroys eax and edx

    ;// stack
    ;// ret     pBase   bReplace
    ;// 00      04      08

        st_pBase    TEXTEQU <(DWORD PTR [esp+4])>
        st_bReplace TEXTEQU <(DWORD PTR [esp+8])>

    ;// must preserve ecx

    ;// this is called from context menu's
    ;// our job is to check if there are any unassigned devices
    ;// returns eax=0 if there are no objects available

    ;// always return false if we're showing a group

        xor eax, eax    ;// default return value

        slist_OrGetHead hardwareL, eax      ;// eax will scan the hardware list
        jz all_done                         ;// exit now if empty

        mov edx, st_pBase                   ;// edx will test the base
        ASSUME edx:PTR OSC_BASE

        test app_bFlags, APP_MODE_IN_GROUP  ;// can't add devices to groups
        jz J0
        test [edx].data.dwFlags, BASE_NO_GROUP
        jz J0
        xor eax, eax
        jmp all_done

    ;// we want: matching base pointers, un opened devices, un assigned devices

    J0: cmp [eax].pBase, edx    ;// matching base class ?
        jne J2                  ;// iterate if not

        test [eax].dwFlags, HARDWARE_SHARED ;// are we shared ?
        jnz all_done            ;// yes, we can always open shared devices

        cmp [eax].hDevice, 0    ;// is device already opened ?
        jnz J1                  ;// can't assign if already opened
        cmp [eax].numDevices, 0 ;// is device already assigned
        jz all_done             ;// OK to assign if not opened and not already assigned

    J1: cmp st_bReplace, 0      ;// are we going to replace the device ?
        je J2                   ;// iterate if not

        cmp [eax].numDevices, 0 ;// are there devices already assigned for this device ??
        jne all_done            ;// return OK if so, because we'll replace it

    J2: slist_GetNext hardwareL, eax    ;// get next device
        or eax, eax             ;// done yet ??
        jnz J0

    ;// fall through is always NO

    all_done:

        ret 8

hardware_CanCreate ENDP

PROLOGUE_ON



;//////////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////////

PROLOGUE_OFF
ASSUME_AND_ALIGN
hardware_Initialize PROC ;//  STDCALL uses esi edi

    ;// new for 1.40
    ;// since hardwareL is now dynamically allocated
    ;// this function is alot simpler

        H_LOG_OPEN
        H_LOG_TRACE <hardware_Initialize>

    ;// call all the H_Ctor Functions

        slist_GetHead baseB, esi
        .REPEAT

            .IF [esi].hard.H_Ctor

                call [esi].hard.H_Ctor
                invoke about_SetLoadStatus

            .ENDIF

            slist_GetNext baseB, esi

        .UNTIL !esi

    ;// that's it

        ret

hardware_Initialize ENDP
PROLOGUE_ON

;//////////////////////////////////////////////////////////////////////////////////////////////

PROLOGUE_OFF
ASSUME_AND_ALIGN
hardware_Destroy PROC;//  STDCALL

        H_LOG_TRACE <hardware_Destroy>

    ;// here, we simply call all the hardware destructors

        slist_GetHead hardwareL, esi
        .REPEAT

            ;// DEVICE_TO_BASE esi, edi
            mov edi, [esi].pBase
            ASSUME edi:PTR OSC_BASE
            .IF edi && [edi].hard.H_Dtor

                push esi
                call [edi].hard.H_Dtor

            .ENDIF

            slist_FreeHead hardwareL, esi

            ;//slist_GetNext hardwareL, esi
            ;//invoke memory_Free, slist_Head(hardwareL)
            ;//mov slist_Head(hardwareL), esi

        .UNTIL !esi

        H_LOG_CLOSE

    ;// that's it

        ret

hardware_Destroy ENDP
PROLOGUE_ON

;/////////////////////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN
hardware_AttachDevice PROC uses ebx edi

        ASSUME esi:PTR OSC_OBJECT
        ASSUME ebp:PTR LIST_CONTEXT
        ;// dx has to be the ID

        ;// our job is the locate a device
        ;// if ID=-1 then find the lowest number

        ;// we then store the device in the object
        ;// then set the good bad state
        ;// then return the results in eax

        movsx edx, dx   ;// sign extend id into edx (accounts for "use any you find")

    ;// some hardware is allowed in groups

        OSC_TO_BASE esi, ebx
        test [ebx].data.dwFlags, BASE_NO_GROUP
        jz ok_to_scan

    ;// detect if we are in a group

        xor edi, edi
        cmp ebp, OFFSET master_context
        jne all_done

    ok_to_scan:

        IFDEF DEBUGBUILD
            stack_Peek gui_context, eax
            stack_Peek play_context, ecx
            DEBUG_IF < ( (ebp !!= eax) && (ecx !!= ebp) && ([ebx].data.dwFlags & BASE_NO_GROUP)) >
        ENDIF

        slist_GetHead hardwareL, edi

        or ecx, -1

        .IF edx == -1

            ;// we're looking for the lowest number

            .WHILE edi

                .IF [edi].pBase == ebx &&   \
                    ([edi].dwFlags & HARDWARE_SHARED || ![edi].numDevices) &&   \
                    [edi].ID < edx

                    mov edx, [edi].ID
                    mov ecx, edi

                .ENDIF

                slist_GetNext hardwareL, edi

            .ENDW

            .IF ecx != -1   ;// we have a device

                mov edi, ecx
                inc [edi].numDevices
                jmp all_done

            .ENDIF

        .ELSE   ;// assigned device

            .WHILE edi

                .IF ( [edi].pBase == ebx ) && ( edx==-1 || edx==[edi].ID )

                    ;// we've found a matching pointer and ID
                    ;// now we check if we allow shared devices
                    ;// or if the device is closed

                    .IF [edi].dwFlags & HARDWARE_SHARED || ![edi].numDevices

                        ;// we do, or it is
                        inc [edi].numDevices
                        jmp all_done

                    .ENDIF

                .ENDIF

                slist_GetNext hardwareL, edi

            .ENDW

        .ENDIF

    all_done:

        xor ecx, ecx
        test edi, edi
        mov [esi].pDevice, edi  ;// set device in osc

        jz osc_is_bad

    osc_is_good:    ;// we're ok

        ;// now we check if we're direct sound
        .IF [edi].dwFlags & HARDWARE_IS_DIRECTSOUND && play_status & PLAY_PLAYING

                ;// we need to close any unattaced mmsys devices
                ;// we also have to close any primary secondary conflicts

            DEBUG_IF < !!(play_status & PLAY_GUI_SYNC)>

            slist_GetHead hardwareL, ebx
            mov ecx, [edi].pBase    ;// make sure to check for same device
            ASSUME ecx:PTR OSC_BASE
            .REPEAT

                .IF (ecx == [ebx].pBase)
                .IF [ebx].hDevice
                .IF ![ebx].numDevices
                ;// .IF !([ebx].dwFlags & HARDWARE_IS_DIRECTSOUND)

                    push ebx
                    call [ecx].hard.H_Close    ;// ENTER_PLAY_SYNC
                    .BREAK

                ;// .ENDIF
                .ENDIF
                .ENDIF
                .ENDIF

                slist_GetNext hardwareL, ebx
                or ebx, ebx

            .UNTIL ZERO?

        .ENDIF

        test [esi].dwHintOsc, HINTOSC_STATE_HAS_BAD
        jz done_with_inval
        mov ecx, HINTI_OSC_LOST_BAD
        jmp need_to_inavlidate

    osc_is_bad:

        test [esi].dwHintOsc, HINTOSC_STATE_HAS_BAD
        jnz done_with_inval
        mov ecx, HINTI_OSC_GOT_BAD

    need_to_inavlidate:

        GDI_INVALIDATE_OSC ecx

    done_with_inval:    ;// return the located device

        mov eax, edi

        ret

hardware_AttachDevice ENDP


ASSUME_AND_ALIGN
hardware_DetachDevice PROC

    ;// this common function is used by most hardware objects

    ;// we need to tell the device block that we no longer exist
    ;// the hardware system will take care of closing the device

        ASSUME esi:PTR OSC_OBJECT

        mov eax, [esi].pDevice
        .IF eax
            dec (HARDWARE_DEVICEBLOCK PTR [eax]).numDevices
            DEBUG_IF <SIGN?>;// some how we lost track
        .ENDIF
        and [esi].pDevice, 0

    ;// that's it

        ret

hardware_DetachDevice ENDP








;//////////////////////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
hardware_Ready PROC

    ;// this is called every 5ms by the play proc when playing
    ;// we call the base class Ready function and process the flags accordingly
    ;//
    ;// this function is the only way devices can be opened
    ;//
    ;//  READY_DO_NOT_CALC  set by buffer dependant devices when a buffer is not ready
    ;//  READY_BUFFERS      set by device when buffer is ready
    ;//  READY_TIMER        set by display devices, midi out, and midi in
    ;//
    ;// return flags are or'ed on to edi
    ;// which gets returned


    ;// do this for all open and assigned devices
    ;// if a device is open, and not assigned, close it

        slist_GetHead hardwareL, esi    ;// esi is device block pointer
        xor edi, edi                    ;// edi is return value, assume true

        or esi, esi
        jz done_with_scan

    top_of_scan:            ;// scan through device list

        xor eax, eax

        cmp [esi].hDevice, eax      ;// is device open now ?
        je device_not_open

        cmp [esi].numDevices, eax   ;// is device assigned ?
        je device_opened_not_assigned

        DEBUG_IF <[esi].dwFlags & HARDWARE_BAD_DEVICE>  ;// bad devices are supposed to be closed

    ;// call devices ready function

        mov ebx, [esi].pBase        ;// get base class from device
        ASSUME ebx:PTR OSC_BASE
        push esi                    ;// push the device pointer
        call [ebx].hard.H_Ready     ;// call the ready function

        or edi, eax                 ;// merge in now
        btr edi, LOG2(READY_MARK_AS_BAD)    ;// bad device ?
        jnc iterate_loop

        mov ecx, [esi].pBase
        mov ecx, (OSC_BASE PTR [ecx]).hard.H_Close
        .IF ecx
            push esi
            call ecx
        .ENDIF

        mov eax, INVAL_PLAY_MAKE_BAD
        jmp mark_all_attached_oscs

    ALIGN 16
    device_opened_not_assigned:     ;// so we close it

        mov ebx, [esi].pBase
        ASSUME ebx:PTR OSC_BASE
        push esi
        call [ebx].hard.H_Close

        and [esi].dwFlags, NOT HARDWARE_BAD_DEVICE
        jmp iterate_loop

    ALIGN 16
    device_not_open:    ;// device is closed now

        cmp [esi].numDevices, eax   ;// check if it's assigned
        je iterate_loop

    ;// this device is closed, and assigned, and we are playing
    ;// so it must be high time we open it
    ;// this has the added bonus of trying to open devices we couldn't open before

    ;// if the device is marked as bad, we do a countdown timer, then try and open it again

        test [esi].dwFlags, HARDWARE_BAD_DEVICE
        jnz device_is_bad

    try_to_open_device:

        push esi
        mov ebx, [esi].pBase
        ASSUME ebx:PTR OSC_BASE
        call [ebx].hard.H_Open

        or eax, eax
        jnz device_wont_open

    ;// device opened just fine

        or edi, READY_DO_NOT_CALC   ;// we cant't be ready if we just opened

        btr [esi].dwFlags, LOG2(HARDWARE_BAD_DEVICE)    ;// see if this was bad
        jnc iterate_loop

        mov eax, INVAL_PLAY_MAKE_GOOD
        jmp mark_all_attached_oscs

    ALIGN 16
    device_wont_open:

        mov [esi].dwCount, 64       ;// reset the count
        bts [esi].dwFlags, LOG2(HARDWARE_BAD_DEVICE)    ;// make sure bad is set
        jc iterate_loop

        mov eax, INVAL_PLAY_MAKE_BAD
        jmp mark_all_attached_oscs

    ALIGN 16
    device_is_bad:

    ;// this device was bad, let's try and open it again
    ;// when the countdown is done of course

        dec [esi].dwCount
        js try_to_open_device

    ALIGN 16
    iterate_loop:

        slist_GetNext hardwareL, esi
        xor eax, eax
        or esi, esi
        jnz top_of_scan

    done_with_scan:

        mov eax, edi

        ret


;// local functions

ALIGN 16
mark_all_attached_oscs:

    ASSUME esi:PTR HARDWARE_DEVICEBLOCK ;// passed by caller

    ;// destroys ebx

    ;// eax must have the good bad status

    push eax

    xor ecx, ecx

    dlist_GetHead oscZ, ebx, master_context
    .WHILE ebx

        OSC_TO_BASE ebx, edx
        .IF [edx].data.dwFlags & BASE_HARDWARE

            .IF esi == [ebx].pDevice

                ;// mark as bad

                clist_Insert oscIC, ebx,,master_context
                mov eax, [esp]
                or [ebx].dwHintIC, eax
                inc ecx

            .ENDIF

        .ENDIF

        dlist_GetNext oscZ, ebx

    .ENDW

    pop eax

    or ecx, ecx
    jz iterate_loop

    WINDOW_P hMainWnd, WM_ABOX_XFER_IC_TO_I
    jmp iterate_loop


hardware_Ready ENDP


;////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////

;// popup menu functions


ASSUME_AND_ALIGN
hardware_FillInDeviceList PROC uses ebp

    ASSUME esi:PTR OSC_OBJECT
    ;// ebx must be the hWnd of the list box
    ;// destroys edi
    OSC_TO_BASE esi, edi


    LISTBOX ebx, LB_RESETCONTENT

    slist_GetHead hardwareL, ebp

    .WHILE ebp

        .IF [ebp].pBase == edi && ebp != [esi].pDevice &&   \
            ([ebp].dwFlags & HARDWARE_SHARED || ![ebp].numDevices)

            LISTBOX ebx, LB_ADDSTRING, 0, ADDR [ebp].szName
            LISTBOX ebx, LB_SETITEMDATA, eax, ebp

        .ENDIF

        slist_GetNext hardwareL, ebp

    .ENDW

    ret

hardware_FillInDeviceList ENDP


;/////////////////////////////////////////////////////////////////////

.DATA

    change_device_jump LABEL DWORD

    dd  change_device_MM_xx_MM_xx   ;// ignore
    dd  change_device_MM_xx_DS_xx   ;// close fr
    dd  change_device_MM_xx_DS_PR   ;// close fr

    dd  change_device_DS_xx_MM_xx   ;// ignore
    dd  change_device_DS_xx_DS_xx   ;// ?
    dd  change_device_DS_xx_DS_PR   ;// close fr

    dd  change_device_DS_PR_MM_xx   ;// ignore
    dd  change_device_DS_PR_DS_xx   ;// close fr
    dd  change_device_DS_PR_DS_PR   ;// ignore

.CODE

PROLOGUE_OFF
ASSUME_AND_ALIGN
hardware_ReplaceDevice PROC STDCALL p_pTo:PTR HARDWARE_DEVICEBLOCK

    ;// this function un assigns one device and assigns another
    ;// also sets the object's device pointer and ID
    ;// sometimes we'll be getting pFrom equal to zero
    ;// that means we're switching a bad device to a new device
    ;// other times we'll get pTo = to zero, which happens in an undo step

    ;// preserves edi esi ebx

        ASSUME esi:PTR OSC_OBJECT   ;// must be passed by caller
        ASSUME ebp:PTR LIST_CONTEXT

        push ebx

    ;// stack
    ;// ebx     ret     to
    ;// 00      04      08

    st_to   TEXTEQU <(DWORD PTR [esp+08h])>

    DEBUG_IF < !!(play_status & PLAY_GUI_SYNC)> ;// supposed to be in play sync

    ;// detach from the from device

        mov ecx, [esi].pDevice
        ASSUME ecx:PTR HARDWARE_DEVICEBLOCK

        .IF ecx ;// if the object existed

            dec [ecx].numDevices
            DEBUG_IF <SIGN?>        ;// somehow we lost count

        .ENDIF

    ;// direct sound requires that an mmsys device be closed first
    ;// it also requires that primary buffers be closed

        mov ebx, st_to
        ASSUME ebx:PTR HARDWARE_DEVICEBLOCK

        .IF ecx && [ecx].hDevice && ![ecx].numDevices

            xor eax, eax
            test [ecx].dwFlags, HARDWARE_IS_DIRECTSOUND
            jz J0
            inc eax
            mov edx, [ecx].pData
            test (DIRECTSOUND_DATA PTR [edx]).dwFlags, DIRECTSOUND_IS_PRIMARY
            jz J0
            inc eax
        J0: lea eax, [eax*2+eax]    ;// multiply by three

            or ebx, ebx     ;// make sure device is a valid pointer
            jz J1
            test [ebx].dwFlags, HARDWARE_IS_DIRECTSOUND
            jz J1
            inc eax
            mov edx, [ebx].pData
            test (DIRECTSOUND_DATA PTR [edx]).dwFlags, DIRECTSOUND_IS_PRIMARY
            jz J1
            inc eax

        J1: jmp change_device_jump[eax*4]

        change_device_MM_xx_DS_xx:: ;// close fr
        change_device_MM_xx_DS_PR:: ;// close fr
        change_device_DS_xx_DS_PR:: ;// close fr
        change_device_DS_PR_DS_xx:: ;// close fr

            push ecx                ;// push the deviceblock pointer
            mov ecx, [ecx].pBase    ;// get the base class
            ASSUME ecx:PTR OSC_BASE
            call [ecx].hard.H_Close ;// call the close routine

        change_device_MM_xx_MM_xx:: ;// ignore
        change_device_DS_xx_MM_xx:: ;// ignore
        change_device_DS_PR_MM_xx:: ;// ignore
        change_device_DS_PR_DS_PR:: ;// ignore

        change_device_DS_xx_DS_xx:: ;// ?

        .ENDIF

    ;// make sure the object is no longer bad

        .IF ebx ;// make sure we're getting a good device pointer

            ;// make sure the bad is reset

            .IF [esi].dwHintOsc & HINTOSC_STATE_HAS_BAD

                GDI_INVALIDATE_OSC HINTI_OSC_LOST_BAD

            .ENDIF

        ;// attach to new device

            inc [ebx].numDevices

        ;// adjust the object's device ID and device pointer

            mov eax, [ebx].ID           ;// load the id of pFrom
            and eax, 0FFFFh             ;// strip off the high side
            and [esi].dwUser, 0FFFF0000h ;// mask off old ID but preserve num buffers
            or [esi].dwUser, eax        ;// mask the new id back on

        .ELSE   ;// got a bad device pointer

            .IF !([esi].dwHintOsc & HINTOSC_STATE_HAS_BAD)

                GDI_INVALIDATE_OSC HINTI_OSC_GOT_BAD

            .ENDIF

        .ENDIF

        mov [esi].pDevice, ebx      ;// store with new device

    ;// that's it

        pop ebx

        ret 4

    st_to   TEXTEQU <>


hardware_ReplaceDevice ENDP
PROLOGUE_ON



;////////////////////////////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN




END
