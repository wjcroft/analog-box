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
;//     ABOX242 AJT
;//         manually set 2 operand sizes for masm 9
;//
;//##////////////////////////////////////////////////////////////////////////
;//
;//     ABox_HID.asm        Human Interface Device
;//                         Joystick, touch pad, rudders etc ...
;//             nuts! DirectInput only allows joysticks ...
;//             see the hid projects for how to import real USB/HID devices
;//
OPTION CASEMAP:NONE
.586
.MODEL FLAT

;// TOC
;//
;// hid_H_Ctor PROC
;// hid_H_Dtor PROC ;// STDCALL pDevBlock:PTR HARDWARE_DEVICEBLOCK
;// hid_H_Open PROC ;// STDCALL pDevice:PTR HARDWARE_DEVICEBLOCK
;// hid_H_Close PROC    ;//  STDCALL uses esi edi pDevice:PTR HARDWARE_DEVICEBLOCK
;// hid_H_Ready PROC ;// STDCALL uses esi edi pDevice:PTR HARDWARE_DEVICEBLOCK
;// hid_H_Calc PROC ;// STDCALL uses esi edi pDevice:PTR HARDWARE_DEVICEBLOCK
;// hid_Calc PROC USES ebp
;// hid_SyncPins    PROC
;// hid_Ctor PROC
;// hid_Dtor PROC
;// hid_Render PROC
;//
;// hid_InitMenu PROC
;// hid_Command PROC
;//
;// hid_SaveUndo PROC
;// hid_LoadUndo PROC




_USE_THIS_FILE_ EQU 1

IFDEF _USE_THIS_FILE_

;///////////////////////////////////////////////////////////////////


        .NOLIST
        INCLUDE <ABox.inc>
        INCLUDE <HIDOBject.inc>
        .LIST
        ;// .LISTALL
        ;// .LISTMACROALL


        DEBUG_MESSAGE_OFF   ;// turns OFF hid_Calc messages
    ;// DEBUG_MESSAGE_ON    ;// turns on hid_Calc messages







;///////////////////////////////////////////////////////////////////
comment ~ /*

NOTES

    we allocate ONE hardware for the entire system
    it will contain all the structs and pointers to interface with
    the HIDDEVICE and HIDCONTROL lists exposed by HIDObject.inc
    in this file see:
        hid_HARDWARE
        hid_DEVICE
        hid_CONTROL
        hid_CONNECT
        hid_DATA

    for the user display we have two windows
    the top for a maximum of six pins
    the bottom for a complete list of devices

    we match pins to device by page usage instance on both the device and the pin
    thus we store four dwords per object


OBJECT SCHEME

    there are many containers in use


hidobject.inc       hidobject           HIDREPORT
hidobject.asm                              A
                                           |
                                           |
                                        HIDDEVICE<----------HIDCONTROL      .dwValue
                                           A                     A
                                           |                     |
                                           |                     |
ABox_HID.asm        hid_HARDWARE------->hid_DEVICE<---------hid_CONTROL     .samples[]  .dwStatus
                                                                 A             A
                                                                 |             |
                                                                 |             |
                                        OSC_OBJECT-------->APIN.dwUser  .pData      .dwStatus


                                                            .hid_CONNECT

            then dlist hid_calc combines hid_CONTROL structs into one list
            ... might not actually need it ?



OPENING AND CLOSING HIDDEVICE



    hid_H_CALC is in charge of opening and closing
    we must be careful to only open and close from the play thread

    we are assured that PLAY and GUI are interlocked and do not overlap


    thread  action
    ------  ------------------------------------------------------------------------------------
    GUI     hid_COMMAND or hid_CTOR calls hid_sync_pins

    GUI     hid_sync_pins scans the pins and adjusts APIN.dwUser
            for any that change, set the HARDWARE_SHARED_RESYNC in HARDWARE_DEVICEBLOCK.dwFlags

    PLAY    hid_Calc sees that HARDWARE_SHARED_RESYNC is on and scans it's pins
            for each pin
                if connected (APIN.dwUser not zero)
                    verify hid_CONTROL is added to hid_calc
                    increment hid_DEVICE.dwConnectCount
                if not connected
                    verify hid_CONTROL is not in hid_calc

    PLAY    hid_H_CALC, after all objects have calced, sees that HARDWARE_SHARED_RESYNC is on
            resets the calc_device list
            it scans its hid_DEVICE list
            for each hid_DEVICE
                remove all calc_control elements
                if dwConnectCount is non zero
                    verify the HIDDEVICE is opened
                    reset dwConnectCount
                    build the local calc_control list by
                        adding all hid_calc elements with the same hid_DEVICE pointer
                    add self to calc_device
                else, dwConnectCount is zero
                    verify the device is closed

        now the device is opened for the next frame
        calc_device is built
        calc_control is built for each device


CALCULATE,

    moving data from HIDREPORT to hid_CONTROL.samples


    PLAY    hid_H_Ready turns off HARDWARE_HAS_CALCED

    PLAY    hid_Calc, if HARDWARE_HAS_CALCED is off, do the calc routine
            scan calc_device
                get num reports
                if zero, fill and set not changing
                else
                    do the segement scan
                        read data from device, sets dwValue in all HIDCONTROL
                        scan calc_control
                            xfer dwValue to sample frame
                            manipulate dwStatus
                    next segment
            next device


SIGN CHANGING

    any one object that changes the sign must update all objects in the circuit
    this is done by causing hid_Calc.HARDWARE_SHARED_RESYNC to set HID_SET_PIN_SHAPES
    ... which is really pretty irellevant since we aren't changingthe shapes

    we also must enforce all objects to load and store the sign bit
    this must happen before hid_SaveUndo and hid_Write
        all object must read the bits from the device
    then hid_find_controls can send the bit to the device

    which means we'd like the olde style of write_device_settings and read_device_settings





*/ comment ~
;///////////////////////////////////////////////////////////////////



.DATA


        HID_NUM_PINS EQU 6  ;// 6 per object should be enough



    ;///////////////////////////////////////////////////////////////
    ;//
    ;//     hid_CONTROL         one dimension of the controller
    ;//     hid_Device          one collection of hid_CONTROL structs
    ;//     hid_HARDWARE        pointed to by hid_OSC_MAP.dat.pHardware
    ;//
    ;//     we have one hid_CONTROL per HIDCONTROL in the HIDDEVICE
    ;//         each control contains a sample buffer that is filled in as required
    ;//     we have one hid_DEVICE per HIDDEVICE in the hidobject
    ;//     we have ONE hid_HARDWARE struct
    ;//
    ;//     with this we can present the user with all the controls
    ;//     and be able to locate suitable controls



        hid_CONTROL STRUCT  ;// allows for polled devices

            dlist_Declare_link hid_calc, hid_CONTROL    ;// oscs add there hid controls here
            dlist_Declare_link calc_control, hid_CONTROL;// local per device

            pDEVICE     dd  0   ;// back ptr to hid_Device
            pHIDCONTROL dd  0   ;// ptr to HIDCONTROL

            dwStatus    dd  0   ;// pins can read this to get the pin status

            prev_value  dd  0   ;// previously read value


            ;// inline control data, should be cache aligned
            ;// these are pointed to by APIN.pData

            samples  dd SAMARY_LENGTH DUP(0)


        hid_CONTROL ENDS

        ;////////////////////////////////////////////////////////////////////////////
        ;//
        ;//     hid_Device manages at the device level
        ;//

        hid_DEVICE STRUCT

            dlist_Declare_link calc_device, hid_DEVICE  ;// system calc device list
            dlist_Declare_indirected calc_control       ;// device local control list

            pHIDDEVICE  dd  0       ;// ptr to HIDDEVICE
            dwConnectCount  dd  0   ;// count of objects connected to this control

        hid_DEVICE ENDS


        ;////////////////////////////////////////////////////////////////////////////
        ;//
        ;//     hid_HARDWARE wraps the whole thing
        ;//

        hid_HARDWARE STRUCT

            HARDWARE_DEVICEBLOCK {}     ;// hDevice is 1 or zero
            ;// device specifics

            ;// iterating all known devices and controls

            pFirstDevice    dd  0   ;// ptr to first device
            pLastDevice     dd  0   ;// ptr to last device
            pFirstControl   dd  0   ;// ptr to first control
            pLastControl    dd  0   ;// ptr to last control

            ;// iterating only connected controls

            dlist_Declare_indirected calc_device    ;// calc uses the dlist to get around
            dlist_Declare_indirected hid_calc

        hid_HARDWARE ENDS

    ;//
    ;//
    ;//
    ;///////////////////////////////////////////////////////////////


    ;///////////////////////////////////////////////////////////////
    ;//
    ;//
    ;//     hid_DATA    contained after osc_HID

        hid_CONNECT STRUCT              ;// all of this data is stored

            device  PAGEUSAGE   {}      ;// desired device type, 0 for off
            dwDeviceInstance    dd  0   ;// instance number
            control PAGEUSAGE   {}      ;// desired control type
            dwControlInstance   dd  0   ;// instance number

        hid_CONNECT ENDS    ;// size = 4 dwords

        .ERRNZ ((SIZEOF hid_CONNECT)-16), <supposed to be 16 bytes !!>


        hid_DATA STRUCT                 ;// all data stored

            connect hid_CONNECT HID_NUM_PINS DUP ({})   ;// an object can have up to 6 connections to pins

        hid_DATA ENDS

    ;//     hid_DATA
    ;//
    ;//
    ;///////////////////////////////////////////////////////////////




;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;///
;///
;///    osc_HID

HID_BASE_FLAGS = BASE_HARDWARE OR BASE_PLAYABLE OR BASE_FORCE_DISPLAY_STATUS OR BASE_WANT_LIST_SELCHANGE

osc_HID     OSC_CORE { hid_Ctor,hid_Dtor,,hid_Calc}
            OSC_GUI  { hid_Render,,,,,hid_Command,hid_InitMenu,,hid_AddExtraSize,hid_SaveUndo, hid_LoadUndo }
            OSC_HARD { hid_H_Ctor,hid_H_Dtor,hid_H_Open,hid_H_Close,hid_H_Ready,hid_H_Calc }

    ;// bah, MASM doesn't like gigantic lines

    HID_numFileBytes    = 4+((SIZEOF hid_CONNECT)*HID_NUM_PINS)
    HID_ofsPinData      = SIZEOF OSC_OBJECT + (SIZEOF APIN)*HID_NUM_PINS
    HID_ofsOscData      = SIZEOF OSC_OBJECT + (SIZEOF APIN)*HID_NUM_PINS
    HID_oscBytes        = SIZEOF OSC_OBJECT + (SIZEOF APIN)*HID_NUM_PINS + SIZEOF hid_DATA

    OSC_DATA_LAYOUT {NEXT_HID,IDB_HID, OFFSET popup_HID,HID_BASE_FLAGS,
        HID_NUM_PINS,
        HID_numFileBytes,
        HID_ofsPinData,
        HID_ofsOscData,
        HID_oscBytes }

    OSC_DISPLAY_LAYOUT { devices_container, HID_PSOURCE, ICON_LAYOUT(4,4,2,2)}

    ;// there are a lot of pins, assigning slots for them may be rough
    ;// for starters, we do two outward alternating assignments

    APIN_init {-0.25,,'?',, PIN_OUTPUT OR PIN_NULL OR PIN_HIDDEN OR UNIT_VALUE }    ;// 00
    APIN_init {-0.15,,'?',, PIN_OUTPUT OR PIN_NULL OR PIN_HIDDEN OR UNIT_VALUE }    ;// 01
    APIN_init {-0.05,,'?',, PIN_OUTPUT OR PIN_NULL OR PIN_HIDDEN OR UNIT_VALUE }    ;// 02
    APIN_init { 0.05,,'?',, PIN_OUTPUT OR PIN_NULL OR PIN_HIDDEN OR UNIT_VALUE }    ;// 03
    APIN_init { 0.15,,'?',, PIN_OUTPUT OR PIN_NULL OR PIN_HIDDEN OR UNIT_VALUE }    ;// 04
    APIN_init { 0.25,,'?',, PIN_OUTPUT OR PIN_NULL OR PIN_HIDDEN OR UNIT_VALUE }    ;// 05

    short_name  db  'HID',0
    description db  'Reads data from a USB Human Interface Device. Includes joysticks, touchpads, headgear etc',0
    ;//sz_hid_special_help_text db 'Select the outputs and their formats by pressing the buttons.',0
    ALIGN 4



    HID_OSC_MAP STRUCT

        OSC_OBJECT  {}
        pin_0   APIN {}
        pin_1   APIN {}
        pin_2   APIN {}
        pin_3   APIN {}
        pin_4   APIN {}
        pin_5   APIN {}
        hid_data hid_DATA {}

    HID_OSC_MAP ENDS

    ;// flags stored on the top of dwUser
    ;// the bottom 16 bits must be for device id

        HID_CLIP            EQU 10000000h
        HID_SET_PIN_SHAPES  EQU 20000000h
            ;// true if we need to set new shapes for pins
            ;// this is et when user changes sign of a control
            ;// and if HARDWARE resync is on
            ;// is processed by hid_Render

        HID_SIGN_BITS       EQU 003F0000h
        ;// six bits, one per pin
        ;// these are read from the device by hid_read_control_signs
        ;// and sent to the device by hid_write_control_signs
        ;// changing any one osc must cause all others to change as well


;///
;///
;///    osc_HID
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////





;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////




.CODE


;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;///
;///
;///    hid_H_Ctor


ASSUME_AND_ALIGN
hid_H_Ctor PROC

        push esi    ;// preserve

    ;// here we fill in our dev blocks and allocate the headers and devices
    ;// must preserve esi

        invoke about_SetLoadStatus

    ;// 0) initialize the hid object

        invoke hidobject_Initialize
        TESTJMP eax, eax, jz all_done   ;// exit now if can't initialize
        mov ebp, eax
        ASSUME ebp:PTR HIDDEVICE

    ;// 1) enumerate the devices and look for devices with controls
    ;//    count both controls and devices

        xor edi, edi        ;// control counter
        xor esi, esi        ;// device counter
        mov edx, ebp        ;// need to preserve ebp for a moment
        ASSUME edx:PTR HIDDEVICE

        ;// enumerate the controls on this device
        ;// count controls with non zero page:usage
        ;// if there are none, then we don't use this device

        .REPEAT
            dlist_GetHead hidcontrol,ebx,edx    ;// all devices have at least one control
            dlist_GetNext hidcontrol,ebx        ;// always skip the first control
            .IF ebx                             ;// make sure there are more controls
                xor ecx, ecx                    ;// count controls on this device
                .REPEAT
                    xor eax, eax                ;// will be 1 or zero
                    test [ebx].dwPageUsage, -1  ;// see if not zero
                    setnz al                    ;// set al if has page usage
                    dlist_GetNext hidcontrol,ebx;// get the next control
                    add ecx, eax                ;// accumulate the count
                .UNTIL !ebx
                .IF ecx                         ;// did we find any ?
                    inc esi                     ;// bump the device count
                    add edi, ecx                ;// accuumulate the total number of controls
                .ENDIF
            .ENDIF
            dlist_GetNext hiddevice, edx        ;// next device
        .UNTIL !edx

    ;// 2) if we have devices and controls then allocate the total size and fill in the device block

        .IF !esi
            invoke hidobject_Destroy    ;// no sense keeping this around
            jmp all_done
        .ENDIF

        imul esi, SIZEOF hid_DEVICE     ;// esi is now total size of device block
        imul edi, SIZEOF hid_CONTROL    ;// edi is now total size of control block
        lea eax, [esi+edi+(SIZEOF hid_HARDWARE)]    ;// ecx is now total amount to allocate

        ;// allocate and link in the device block

        slist_AllocateHead hardwareL, ebx, eax
        ASSUME ebx:PTR hid_HARDWARE

        ;// assign the base class, adjust the flags, set the ID and the name

        mov [ebx].pBase, OFFSET osc_HID     ;// set the base class
        or [ebx].dwFlags, HARDWARE_SHARED   ;// set as a shared device
        mov [ebx].ID, 1                     ;// always 1
        mov (DWORD PTR [ebx].szName), 'DIH' ;// set the name

        ;// define the iterator pointers

        lea eax, [ebx+SIZEOF hid_HARDWARE]  ;// first device
        mov [ebx].pFirstDevice, eax
        add eax, esi                        ;// one passed last device
        lea edx, [eax-SIZEOF hid_DEVICE]    ;// last device
        mov [ebx].pFirstControl, eax
        mov [ebx].pLastDevice, edx
        lea eax, [eax+edi-SIZEOF hid_CONTROL]   ;// pLastControl
        mov [ebx].pLastControl, eax

    ;// 3) enumerate the devices and controls again
    ;//    initialize the hid_DEVICE and hid_CONTROL structs

        mov esi, [ebx].pFirstDevice
        mov edi, [ebx].pFirstControl

        ASSUME esi:PTR hid_DEVICE
        ASSUME edi:PTR hid_CONTROL

        ;// ebp is still at the head of the controls

        .REPEAT
            dlist_GetHead hidcontrol,ecx,ebp        ;// all devices have at least one control
            dlist_GetNext hidcontrol,ecx            ;// always skip the first control
            .IF ecx                                 ;// skip if none
                .REPEAT
                    .IF [ecx].dwPageUsage & -1      ;// see if not zero
                        mov [esi].pHIDDEVICE, ebp   ;// save the HIDDEVICE (perhaps many times)
                        mov [edi].pHIDCONTROL, ecx  ;// save the HIDCONTROL ptr
                        mov [edi].pDEVICE, esi      ;// set the back pointer to the device
                        or [ecx].dwFormat, HIDCONTROL_OUT_FLOAT     ;// make sure we have floats
                        or [ebp].dwFlags, HIDDEVICE_FORMAT_CHANGED  ;// and tell the device that too
                        add edi, SIZEOF hid_CONTROL ;// next control
                    .ENDIF
                    dlist_GetNext hidcontrol, ecx
                .UNTIL !ecx
                .IF [esi].pHIDDEVICE    ;// do we advance the device ?
                    ;// force the instance numbers to be correct
                    invoke hiddevice_BuildFormats, ebp
                    ;// show this entry in the device list
                    lea edx, [ebp].szLongName
                    LISTBOX about_hWnd_device, LB_ADDSTRING, 0, edx
                    lea edx, [ebp].szLongName
                    WINDOW about_hWnd_load, WM_SETTEXT, 0, edx
                    ;// advance the device iterator to the next slot
                    add esi, SIZEOF hid_DEVICE
                .ENDIF
            .ENDIF
            dlist_GetNext hiddevice, ebp

        .UNTIL !ebp

    ;// that's it ...

    all_done:

        pop esi

        ret

hid_H_Ctor ENDP


;///    hid_H_Ctor
;///
;///
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////



ASSUME_AND_ALIGN
hid_H_Dtor PROC ;// STDCALL pDevBlock:PTR HARDWARE_DEVICEBLOCK

    ;// we assume all the devices are stopped
    ;// and that they are already closed

        invoke hidobject_Destroy

    ;// that's it

        ret 4   ;// stdcall 1 arg

hid_H_Dtor ENDP




;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;///
;///
;///    hid_H_Open



ASSUME_AND_ALIGN
hid_H_Open PROC ;// STDCALL pDevice:PTR HARDWARE_DEVICEBLOCK

    ;// we pretend we are open
    ;// calc will do the rest

        mov ecx, [esp+4]
        ASSUME ecx:PTR hid_HARDWARE
        mov [ecx].hDevice, 1
        or [ecx].dwFlags, HARDWARE_SHARED_RESYNC    ;// force a resync
        xor eax, eax    ;// state that we suceed
        retn 4          ;// stdcall 1 arg

hid_H_Open ENDP



;///    hid_H_Open
;///
;///
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////






;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;///
;///
;///    hid_H_Close



ASSUME_AND_ALIGN
hid_H_Close PROC    ;//  STDCALL uses esi edi pDevice:PTR HARDWARE_DEVICEBLOCK

    ;// close is another matter
    ;// we must manually close each device

        xchg ebp, [esp+4]
        ASSUME ebp:PTR hid_HARDWARE
        push esi

        mov esi, [ebp].pFirstDevice
        .IF esi ;// don't screw this up ?
            ASSUME esi:PTR hid_DEVICE
            .REPEAT
                invoke hiddevice_Close,[esi].pHIDDEVICE
                add esi, SIZEOF hid_DEVICE
            .UNTIL esi > [ebp].pLastDevice
        .ENDIF
        mov [ebp].hDevice, 0    ;// state that we are closed

    ;// that's it

        pop esi
        mov ebp, [esp+4]
        retn 4  ;// stdcall 1 arg

hid_H_Close ENDP

;///    hid_H_Close
;///
;///
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////



ASSUME_AND_ALIGN
hid_H_Ready PROC ;// STDCALL pDevice:PTR HARDWARE_DEVICEBLOCK

    ;// this is called before the calc
    ;// turn off the HARDWARE_HAS_CALCED bit

        mov edx, [esp+4]
        ASSUME edx:PTR HARDWARE_DEVICEBLOCK
        mov eax, READY_BUFFERS  ;// assume for now that we are always ready
        and [edx].dwFlags, NOT HARDWARE_HAS_CALCED
        ret 4   ;// stdcall 1 arg

hid_H_Ready ENDP



;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////






;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;///
;///
;///    hid_H_Calc


ASSUME_AND_ALIGN
hid_H_Calc PROC ;// STDCALL pDevice:PTR HARDWARE_DEVICEBLOCK

    ;// this is called AFTER the calc
    ;// turn off the HARDWARE_SHARED_RESYNC bit

        mov eax, [esp+4]
        BITRJMP (HARDWARE_DEVICEBLOCK PTR [eax]).dwFlags, HARDWARE_SHARED_RESYNC, jc have_to_rescan
    return_now: ;// that should do it
        ret 4   ;// stdacll 1 arg

    ALIGN 16
    have_to_rescan:

    DEBUG_IF <!!(play_status & PLAY_PLAYING)>   ;// need to check for this

;// PLAY    hid_H_CALC, after all objects have calced, sees that HARDWARE_SHARED_RESYNC is on
;//         resets the calc_device list
;//         it scans its hid_DEVICE list
;//         for each hid_DEVICE
;//             remove all calc_control elements
;//             if dwConnectCount is non zero
;//                 verify the HIDDEVICE is opened
;//                 reset dwConnectCount
;//                 build the local calc_control list by
;//                     TRASFERRING all hid_calc elements with the same hid_DEVICE pointer
;//                 add self to calc_device
;//             else, dwConnectCount is zero
;//                 verify the device is closed


    ;// save registers

        push ebp
        push edi
        push esi
        push ebx

        mov ebp, eax
        ASSUME ebp:PTR hid_HARDWARE


        .REPEAT         ;// reset the calc_device list
            dlist_RemoveHead calc_device, edx,,ebp
        .UNTIL ZERO?
        mov esi, [ebp].pFirstDevice     ;// scan all the devices
        TESTJMP esi, esi, jz all_done   ;// exit now if empty
        ASSUME esi:PTR hid_DEVICE
        .REPEAT
            ;// remove the calc_control list
            .REPEAT
                dlist_RemoveHead calc_control,edx,,esi
            .UNTIL ZERO?
            .IF [esi].dwConnectCount            ;// if dwConnectCount is non zero
                invoke hiddevice_Open, [esi].pHIDDEVICE ;// verify device is opened
                DEBUG_IF <!!eax>    ;// does this ever happen ?
                ;// TESTJMP eax, eax, jz cant_open_device
                dlist_InsertHead calc_device, esi,,ebp  ;// make sure we are in the calc_device list
                mov [esi].dwConnectCount, 0             ;// reset the connect count
                dlist_GetHead hid_calc, edi,ebp         ;// rebuild the local calc_control list
                DEBUG_IF <!!edi>    ;// supposed to have stuff in it ?!!
                .REPEAT
                    dlist_GetNext hid_calc,edi,ebx      ;// set ebx as the next device
                    .IF esi == [edi].pDEVICE            ;// this device ?
                        dlist_Remove hid_calc, edi,,ebp         ;// remove from hid_calc
                        dlist_InsertHead calc_control, edi,,esi ;// add to our list
                    .ENDIF
                    mov edi, ebx
                .UNTIL !edi
            .ELSE                               ;// we have no connected devices
                invoke hiddevice_Close, [esi].pHIDDEVICE    ;// make sure we are closed
            .ENDIF
            ;// next device
            add esi, SIZEOF hid_DEVICE
        .UNTIL esi > [ebp].pLastDevice

    all_done:

        pop ebx
        pop esi
        pop edi
        pop ebp
        jmp return_now

hid_H_Calc ENDP



;///    hid_H_Calc
;///
;///
;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////





;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;///
;///
;///    hid_Calc


ASSUME_AND_ALIGN
hid_Calc PROC USES ebp

DEBUG_IF <!!(play_status & PLAY_PLAYING)>

        ASSUME esi:PTR HID_OSC_MAP  ;// preserve

        mov ebp, [esi].pDevice
        ASSUME ebp:PTR hid_HARDWARE
        TESTJMP ebp, ebp, je all_done   ;// can't do anything without a device !!

    ;// check if we need a resync

        TESTJMP [ebp].dwFlags, HARDWARE_SHARED_RESYNC, jnz update_connect_count

    ;// set the calc bit, if we have already calced, do not do so twice

        BITSJMP [ebp].dwFlags, HARDWARE_HAS_CALCED, jnc do_hid_calc

    ;// read_pin_states     now we set the pinstates for THIS osc

    read_pin_states:

        xor edi, edi                        ;// edi is hid_CONTROL pointer
        ASSUME edi:PTR hid_CONTROL
        ITERATE_PINS                        ;// ebx is scanning pins

            or edi, [ebx].dwUser
            .IF !ZERO?                      ;// pin is connected to a hid_CONTROL

                mov eax, [edi].dwStatus     ;// get the dwStatus from the control
                mov ecx, [ebx].dwStatus     ;// get the APIN status

                lea edx, [edi].samples      ;// point at samples

                and ecx, NOT PIN_CHANGING   ;// remove extra from hid_CONTROL status
                and eax, PIN_CHANGING       ;// remove pin changing from APIN status

                mov [ebx].pData, edx        ;// save the APIN pData

                or eax, ecx                 ;// merge statuses together
                xor edi, edi                ;// reset edi for next test

                mov [ebx].dwStatus, eax     ;// store back in object

            .ELSE           ;// pin is not connected to a hid_CONTROL

                mov eax, math_pNull         ;// point at zero data
                and [ebx].dwStatus, NOT PIN_CHANGING
                mov [ebx].pData, eax

            .ENDIF

        PINS_ITERATE

    ;// and that's about it
    all_done:

        ret



;////////////////////////////////////////////////////////////////////////////



    ALIGN
    update_connect_count:   ;// exits to either do_hid_calc or read_pin_states

        xor edi, edi                        ;// edi is hid_CONTROL pointer
        ASSUME edi:PTR hid_CONTROL
        ITERATE_PINS                        ;// ebx is scanning pins

            or edi, [ebx].dwUser
            .IF !ZERO?                      ;// pin is connected to a hid_CONTROL
                mov ecx, [edi].pDEVICE
                inc (hid_DEVICE PTR [ecx]).dwConnectCount
                ;// make sure we are added to the hid calc list
                dlist_IfMember_jump hid_calc, edi, control_in_hid_calc, ebp
                dlist_InsertHead hid_calc,edi,,ebp
            control_in_hid_calc:
                xor edi, edi    ;// be sure to reset this
            .ENDIF

        PINS_ITERATE
        or [esi].dwUser, HID_SET_PIN_SHAPES ;// need to make sure we are the same

    ;// set the calc bit, if we have already calced, do not do so twice

        BITSJMP [ebp].dwFlags, HARDWARE_HAS_CALCED, jc read_pin_states


;////////////////////////////////////////////////////////////////////////////



    ALIGN 16
    do_hid_calc:            ;// exits to read_pin_states

        push esi    ;// must preserve

        dlist_GetHead calc_device, esi, ebp
        .IF esi
        .REPEAT

            invoke hiddevice_CountReports, [esi].pHIDDEVICE
            ;// we react to three cases, 0, 1 and many
            cmp eax, 1
            jb zero_input_reports
            ja many_input_reports

        one_input_report:   ;// read new data, the fall into zero reports

            invoke hiddevice_ReadNextReport, [esi].pHIDDEVICE

        zero_input_reports: ;// all we do is check that new data is same or different

            dlist_GetHead calc_control, ebx,esi
            .REPEAT
                mov ecx, [ebx].pHIDCONTROL          ;// get the control pointer
                mov eax, (HIDCONTROL PTR [ecx]).dwValue ;// get the newly read value
                mov edx, [ebx].prev_value           ;// get the old value
                mov [ebx].prev_value, eax           ;// store new as old
                BITRJMP [ebx].dwStatus, PIN_CHANGING, jc one_have_to_fill
                CMPJMP eax, edx, je one_next_control
            one_have_to_fill:
                mov ecx, SAMARY_LENGTH
                lea edi, [ebx].samples
                rep stosd
            one_next_control:
                dlist_GetNext calc_control, ebx     ;// get next hid_CONTROL on this hid_DEVICE
            .UNTIL !ebx

        next_device:

            dlist_GetNext calc_device, esi

        .UNTIL !esi
        .ENDIF

        pop esi ;// retreieve
        jmp read_pin_states ;// and back to read pin states



        ALIGN 16
        many_input_reports:

            .IF eax > 512           ;// be realistic !!
                mov eax, 512
            .ENDIF
            push eax                ;// save report count on stack
            mov eax, SAMARY_LENGTH
            cdq
            idiv DWORD PTR [esp]    ;// eax is now segment size
            push eax                ;// save segment size on stack
            pushd 0                 ;// save a running counter

            st_num_segments TEXTEQU <(DWORD PTR [esp+8])>
            st_seg_size     TEXTEQU <(DWORD PTR [esp+4])>
            st_seg_offset   TEXTEQU <(DWORD PTR [esp+0])>

        ;// the first scan sets things differently

            invoke hiddevice_ReadNextReport, [esi].pHIDDEVICE
            dlist_GetHead calc_control, ebx,esi
            .REPEAT
                mov ecx, [ebx].pHIDCONTROL          ;// get the control pointer
                and [ebx].dwStatus, NOT PIN_CHANGING;// turn this off
                mov eax, (HIDCONTROL PTR [ecx]).dwValue ;// get the newly read value
                mov ecx, st_seg_size                ;// get the segment size
                lea edi, [ebx].samples              ;// point at output samples
                rep stosd                           ;// fill it
                mov [ebx].prev_value, eax           ;// store new as old
                dlist_GetNext calc_control, ebx     ;// get next hid_CONTROL on this hid_DEVICE
            .UNTIL !ebx

            dec st_num_segments                     ;// pre decrease the count

        top_of_seg_fill:                            ;// the rest of the scans

            mov eax, st_seg_size                    ;// bump the seg offset
            add st_seg_offset, eax                  ;// by adding seg size

            invoke hiddevice_ReadNextReport, [esi].pHIDDEVICE

            dlist_GetHead calc_control, ebx,esi
            .REPEAT
                mov ecx, [ebx].pHIDCONTROL          ;// get the control pointer
                mov edx, [ebx].prev_value           ;// get the previous value
                mov eax, (HIDCONTROL PTR [ecx]).dwValue ;// get the newly read value
                mov edi, st_seg_offset              ;// get the current segement offset
                mov ecx, st_seg_size                ;// get the segment size
                lea edi, [ebx].samples[edi*4]       ;// convert edi to dest pointer
                rep stosd                           ;// fill it
                cmp eax, edx                        ;// compare new with old
                mov [ebx].prev_value, eax           ;// store new as old
                .IF !ZERO?                          ;// if new different than old
                    or [ebx].dwStatus, PIN_CHANGING ;// set pin changing in hid_CONTROL
                .ENDIF
                dlist_GetNext calc_control, ebx     ;// get next hid_CONTROL on this hid_DEVICE
            .UNTIL !ebx
            DECJMP st_num_segments, jnz top_of_seg_fill

        done_with_segments:     ;// make sure to fill to end of frame

            mov eax, st_seg_size
            add eax, st_seg_offset                  ;// eax may be before the end of the frame
            DEBUG_IF < eax !> SAMARY_LENGTH>        ;// not supposed to happen !!
            .IF eax < SAMARY_LENGTH                 ;// have to store to end of frame
                mov edx, eax                        ;// xfer offset to edx
                dlist_GetHead calc_control, ebx,esi
                .REPEAT
                    mov eax, [ebx].prev_value       ;// get the last stored value
                    lea edi, [ebx].samples[edx*4]   ;// convert edi to dest pointer
                    mov ecx, SAMARY_LENGTH          ;// count remainin = length - offset
                    sub ecx, edx
                    rep stosd                       ;// fill it
                    dlist_GetNext calc_control,ebx  ;// get next hid_CONTROL on this hid_DEVICE
                .UNTIL !ebx
            .ENDIF

            ;// clean up the stack

            add esp, 12
            st_num_segments TEXTEQU <>
            st_seg_size     TEXTEQU <>
            st_seg_offset   TEXTEQU <>

            jmp next_device



hid_Calc ENDP


;///    hid_Calc
;///
;///
;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////




;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;///
;///
;///    read_control_signs

ASSUME_AND_ALIGN
hid_read_control_signs PROC

    ;// synchronize osc.dwUser sign bits with what the device actually has
    ;// calling this is how we enforce one object changing all the others

        ASSUME esi:PTR HID_OSC_MAP  ;// preserve
        ;// destroys ebx

        and [esi].dwUser, NOT HID_SIGN_BITS     ;// turn off all bits
        mov eax, (1 SHL (HID_NUM_PINS+16-1))    ;// bit location of highest
        ITERATE_PINS                ;// iterates pins backwards
            mov edx, [ebx].dwUser
            .IF edx
                mov edx, (hid_CONTROL PTR [edx]).pHIDCONTROL
                test (HIDCONTROL PTR [edx]).dwFormat, HIDCONTROL_OUT_NEGATIVE
                .IF !ZERO?
                    or [esi].dwUser, eax
                .ENDIF
            .ENDIF
            shr eax, 1
        PINS_ITERATE        ;// iterates pins backwards

    ;// that should do it

        ret

hid_read_control_signs ENDP

;///    read_control_signs
;///
;///
;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////




;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;///                                                internal functions
;///    set pin shapes
;///    and locate controls


ASSUME_AND_ALIGN
hid_set_pin_shapes PROC USES edi ebx

        ASSUME esi:PTR HID_OSC_MAP  ;// preserve
        ASSUME ebp:PTR LIST_CONTEXT ;// preserve
        ;// also preserve edi and ebx

        .IF ![esi].pDevice              ;// no device !!

            ITERATE_PINS                ;// hide all the pins
                invoke pin_Show, 0
            PINS_ITERATE
            or [esi].dwUser, HID_CLIP   ;// and flag as bad

        .ELSE       ;// we have a device

            ITERATE_PINS

                mov edi, [ebx].dwUser
                ASSUME edi:PTR hid_CONTROL

                ;// setup the pin
                .IF edi

                    mov edi, [edi].pHIDCONTROL
                    ASSUME edi:PTR HIDCONTROL

                    invoke pin_Show, 1  ;// show the pin

                    ;// pin must have units, a font, a name, and a shape
                    ;// we'll push the args on the stack
                    ;// call pin_SetNameAndUnit, pShortName:DWORD, pLongName:DWORD, unit:DWORD

                    mov eax, [edi].W0       ;// unit depends on type of control
                    .IF eax == [edi].W1
                        pushd UNIT_LOGIC    ;// boolean
                    .ELSE
                        pushd UNIT_VALUE    ;// continous
                    .ENDIF

                    lea eax, [edi].szLongName   ;// long name is the control long name
                    push eax

                    push edi                ;// font is the short name from the control
                    mov eax, [edi].szShortName
                    mov edi, OFFSET font_pin_slist_head
                    invoke font_Locate      ;// build or locate a font
                    xchg edi, [esp]         ;// retrieve edi, and store the arg

                    call pin_SetNameAndUnit ;// do it

                .ELSE
                    invoke pin_Show, edi    ;// hide the pin (edi=0)
                .ENDIF

            PINS_ITERATE

        .ENDIF  ;// have a device

    ;// that should be it

        ret


hid_set_pin_shapes ENDP



ASSUME_AND_ALIGN
hid_find_controls_and_write_signs PROC USES edi ebx

        ASSUME esi:PTR HID_OSC_MAP  ;// preserve
        ASSUME ebp:PTR LIST_CONTEXT ;// preserve
        ;// also preserve edi and ebx

    ;// tasks   connect pins to hid_CONTROLS
    ;//         for any that change, tag HARDWARE_SHARED_RESYNC

        .IF [esi].pDevice   ;// we have a device

            pushd 0 ;// counter
            st_count TEXTEQU <(DWORD PTR [esp])>

            ;// for each possible pin
            ;// get the connect pointer
            ;// if on
            ;//     locate a hid control
            ;//         if found, then ok
            ;// get the pin
            ;//     if dwUser different than pointer
            ;//         set new
            ;//         tag hardware sync
            ;//         setup the pin

            .REPEAT

                ;// get the connect pointer

                .ERRNZ ((SIZEOF hid_CONNECT)-16), <supposed to be 16 bytes !!>
                mov edi, st_count
                shl edi, LOG2(SIZEOF hid_CONNECT)
                add edi, [esi].pData
                ASSUME edi:PTR hid_CONNECT

                ;// if on
                ;//     locate a hid control
                ;// use edi as the output

                .IF [edi].device.dwPageUsage    ;// is it on ?

                    mov ebx, [esi].pDevice      ;// search through controls and find a match
                    ASSUME ebx:PTR hid_HARDWARE
                    mov ebx, [ebx].pFirstControl
                    ASSUME ebx:PTR hid_CONTROL
                    .REPEAT

                        mov ecx, [ebx].pHIDCONTROL
                        ASSUME ecx:PTR HIDCONTROL
                        mov edx, [edi].control.dwPageUsage
                        CMPJMP edx, [ecx].dwPageUsage, jne next_control

                        mov eax, [edi].dwControlInstance
                        CMPJMP eax, [ecx].dwInstance, jne next_control

                        mov edx, [ebx].pDEVICE
                        ASSUME edx:PTR hid_DEVICE
                        mov edx, [edx].pHIDDEVICE
                        ASSUME edx:PTR HIDDEVICE
                        mov eax, [edi].device.dwPageUsage
                        CMPJMP eax, [edx].dwPageUsage,  jne next_control

                        mov eax, [edi].dwDeviceInstance
                        CMPJMP eax, [edx].dwInstance, je searching_done

                    next_control:

                        add ebx, SIZEOF hid_CONTROL
                        mov ecx, [esi].pDevice
                        ASSUME ecx:PTR hid_HARDWARE

                    .UNTIL ebx > [ecx].pLastControl
                    xor ebx, ebx    ;// not found
                searching_done:
                    mov edi, ebx
                .ELSE   ;// no device specified
                    xor edi, edi
                .ENDIF

                ASSUME edi:PTR hid_CONTROL

            ;// get the pin

                mov ebx, st_count
                shl ebx, LOG2(SIZEOF APIN)
                lea ebx, [esi+SIZEOF OSC_OBJECT+ebx]
                ASSUME ebx:PTR APIN

            ;// if dwUser different than pointer

                .IF edi != [ebx].dwUser

                    mov [ebx].dwUser, edi   ;// set new

                    mov ecx, [esi].pDevice
                    ASSUME ecx:PTR hid_HARDWARE
                    or [ecx].dwFlags, HARDWARE_SHARED_RESYNC ;// tag hardware sync
                    or [esi].dwUser, HID_SET_PIN_SHAPES

                .ENDIF

            ;// force the control's sign to follow dwUser

                .IF edi

                    mov edx, [edi].pHIDCONTROL
                    ASSUME edx:PTR HIDCONTROL
                    mov ecx, st_count           ;// get the index we're working with
                    add ecx, 16                 ;// bit number to test
                    bt [esi].dwUser, ecx        ;// test if sign is on
                    jnc sign_should_be_off
                sign_should_be_on:              ;// supposed to be on
                    BITS [edx].dwFormat, HIDCONTROL_OUT_NEGATIVE
                    jc done_setting_sign        ;// ok if already on
                tag_as_format_change:
                    mov edx, [edi].pDEVICE
                    mov edx, (hid_DEVICE PTR [edx]).pHIDDEVICE
                    or (HIDDEVICE PTR [edx]).dwFlags, HIDDEVICE_FORMAT_CHANGED
                    jmp done_setting_sign
                sign_should_be_off:             ;// supposed to be off
                    BITR [edx].dwFormat, HIDCONTROL_OUT_NEGATIVE
                    jc tag_as_format_change     ;// jump up if was on
                done_setting_sign:

                .ENDIF

            ;// and iterate the count

                inc st_count    ;// next count

            .UNTIL st_count >= HID_NUM_PINS

            add esp, 4  ;// clean up the stack
            st_count TEXTEQU <>

        .ELSE   ;// no device !!

            ITERATE_PINS
                and [ebx].dwUser, 0     ;// reset just in case
            PINS_ITERATE

        .ENDIF  ;// have a device or not

    ;// call set pin shapes if we need to

        .IF [esi].dwUser & HID_SET_PIN_SHAPES
            invoke hid_set_pin_shapes
        .ENDIF

    ;// then check if we have a bad device

        .IF [esi].dwUser & HID_CLIP

            test [esi].dwHintOsc, HINTOSC_STATE_HAS_BAD
            jnz done_with_inval
            mov ecx, HINTI_OSC_GOT_BAD

        .ELSE

            test [esi].dwHintOsc, HINTOSC_STATE_HAS_BAD
            jz done_with_inval
            mov ecx, HINTI_OSC_LOST_BAD

        .ENDIF

        GDI_INVALIDATE_OSC ecx

    done_with_inval:

        or [esi].dwUser, HID_SET_PIN_SHAPES

        ret


hid_find_controls_and_write_signs ENDP

;///    set pin shapes
;///    and locate controls
;///                                                internal functions
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////





;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
hid_Ctor PROC

        ;// register call

        ASSUME ebp:PTR LIST_CONTEXT ;// preserve
        ASSUME esi:PTR HID_OSC_MAP  ;// preserve
        ASSUME edi:PTR OSC_BASE     ;// may destroy
        ASSUME ebx:PTR FILE_OSC     ;// may destroy
        ASSUME edx:PTR FILE_HEADER  ;// may destroy

    ;// we've been created
    ;// any data we have is loaded
    ;// so now we get a device
    ;// we have nothing to worry about id and instance

        and [esi].dwUser, NOT HID_CLIP  ;// turn off the previously clipping flag
        mov edx, 0FFFFh         ;// use the default device

        invoke hardware_AttachDevice

    ;// set the num buffers, set the device id

        .IF eax     ;// make sure we found something

            invoke hid_find_controls_and_write_signs
            ;// schedule a trace, hid's are playable
            or [ebp].pFlags, PFLAG_TRACE

        .ENDIF

    ;// that's it

        ret


hid_Ctor ENDP


;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
hid_Dtor PROC

        ASSUME esi:PTR HID_OSC_MAP
        ASSUME ebp:PTR LIST_CONTEXT

    ;// make sure we set the resync flag for all attached devices
    ;// then decrease our instance count
    ;// then reset out device

        mov eax, [esi].pDevice
        .IF eax
            or (HARDWARE_DEVICEBLOCK PTR [eax]).dwFlags, HARDWARE_SHARED_RESYNC
            dec (HARDWARE_DEVICEBLOCK PTR [eax]).numDevices
            DEBUG_IF <SIGN?>;// some how we lost track
            and [esi].pDevice, 0
        .ENDIF

    ;// that's it

        ret

hid_Dtor ENDP


;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
hid_Render PROC

        ASSUME esi:PTR HID_OSC_MAP

        BITR [esi].dwUser, HID_SET_PIN_SHAPES
        .IF CARRY?
            invoke hid_set_pin_shapes
        .ENDIF

        invoke gdi_render_osc

        .IF [esi].dwUser & HID_CLIP

            push edi
            push ebx
            push esi

            mov eax, F_COLOR_OSC_BAD
            OSC_TO_CONTAINER esi, ebx
            OSC_TO_DEST esi, edi        ;// get the destination
            mov ebx, [ebx].shape.pMask
            invoke shape_Fill

            pop esi
            pop ebx
            pop edi

        .ENDIF

    ;// that's it

        ret

hid_Render ENDP




;////////////////////////////////////////////////////////////////////////////////
;//
;//
;//     popup support rountines
;//




;// do the buttons, eax has the current selection, which is the index of the pin

    comment ~ /*
    #define     ID_HID_FLOAT_POS    VK_ADD
    #define     ID_HID_FLOAT_NEG    VK_SUBTRACT
    #define     ID_HID_BOOL_POS     VK_B
    #define     ID_HID_BOOL_NEG     VK_D
    */ comment ~

        .DATA
        hid_button_id dd ID_HID_FLOAT_POS,ID_HID_FLOAT_NEG,ID_HID_BOOL_POS,ID_HID_BOOL_NEG
        .CODE

ASSUME_AND_ALIGN
PROLOGUE_OFF
set_button_states PROC STDCALL dwCurrentSelection:DWORD

        ASSUME esi:PTR HID_OSC_MAP  ;// must be true !!
        ;// destroys ebx and edi

    comment ~ /*
        there are only 5 states
        which we can encode by which button is to be pushed

    pushed  FLOAT_POS   0   1   0   0   0
    enabled             0   1   1   0   0
    pushed  FLOAT_NEG   0   0   1   0   0
    enabled             0   1   1   0   0
    pushed  BOOL_POS    0   0   0   1   0
    enabled             0   0   0   1   1
    pushed  BOOL_NEG    0   0   0   0   1
    enabled             0   0   0   1   1
    -------------------------------------
    value               0   B   E   B0  E0

    */ comment ~

        mov eax, [esp+4]    ;// index of selected item

        shl eax, LOG2(SIZEOF APIN)  ;// eax has the index of the current selection
        lea edi, [esi+eax].pin_0
        mov edi, (APIN PTR [edi]).dwUser
        .IF edi ;// pin is connected, determine what it is
            mov edi, (hid_CONTROL PTR [edi]).pHIDCONTROL
            ASSUME edi:PTR HIDCONTROL
            mov eax, [edi].W0
            mov edx, [edi].W1
            .IF [edi].dwFormat & HIDCONTROL_OUT_NEGATIVE
                mov edi, 0Eh
            .ELSE
                mov edi, 0Bh
            .ENDIF
            ASSUME edi:NOTHING
            .IF eax == edx
            ;// BOOLEAN
                shl edi, 4  ;// easy as that
            .ENDIF
        .ENDIF  ;// else    pin has not been connected yet
                ;//         disable and uncheck all
                ;//         edi is already the correct value

        ;// then we loop through the bits

        xor ebx, ebx    ;// counter
        .REPEAT

            invoke GetDlgItem, popup_hWnd, hid_button_id[ebx*4]

            xor edx, edx
            shr edi, 1
            adc edx, edx    ;// check state BST_CHECKED = 1

            xor ecx, ecx
            shr edi, 1
            adc ecx, ecx    ;// enabled

            push ecx    ;// EnableWindow.bEnable
            push eax    ;// EnableWindow.hWnd

            pushd 0     ;// SendMessage.lParam
            push edx    ;// SendMessage.wParam
            pushd BM_SETCHECK
            push eax    ;// hWnd

            call SendMessageA
            call EnableWindow

            inc ebx

        .UNTIL ebx >= 4

        retn 4  ;// STDCALL 1 arg


set_button_states ENDP
PROLOGUE_ON




ASSUME_AND_ALIGN
select_current_control PROC

    ;// selects an item in the control window based on the current selection in the pin window

        ASSUME esi:PTR HID_OSC_MAP
        ;// destroys ebx and edi

        invoke GetDlgItem, popup_hWnd, ID_HID_PINS
        WINDOW eax,LB_GETCURSEL
        test eax, eax
        .IF SIGN?
            xor eax, eax
        .ENDIF

        push eax
        invoke set_button_states, eax
        pop eax

        ;// eax is an APIN index
        shl eax, LOG2(SIZEOF APIN)
        lea ecx, [esi+eax].pin_0
        mov edi, (APIN PTR [ecx]).dwUser    ;// edi is pointer

        invoke GetDlgItem, popup_hWnd, ID_HID_CONTROLS
        mov ebx, eax

    ;// now determine what to select in the bottom window

        ;// we'll set edi as the resultant index
        .IF edi

            ;// locate the index of the item in the bottom winodw with this value,
            ;// if edi was zero, then OFF is always the first item

            push esi    ;// counter
            WINDOW ebx, LB_GETCOUNT
            mov esi, eax
            .WHILE esi
                dec esi
                WINDOW ebx, LB_GETITEMDATA, esi
                CMPJMP eax, edi, je found_it
            .ENDW
            ;// if we hit this, we did not find a match
            dec esi ;// = LB_ERR
        found_it:
            mov edi, esi
            pop esi
        .ELSE   ;// edi was zero, so we turn off the selection
            dec edi
        .ENDIF

    ;// then we set the selection in the bottom list

        inc hid_popup_busy
        WINDOW ebx, LB_SETCURSEL, edi
        dec hid_popup_busy

    ;// that should do it

        retn

select_current_control ENDP









;//////////////////////////////////////////////////////////////////////////////
;//
;//
;//     hid_InitMenu
;//




.DATA

        fmt_instance    db '#%i',0
        ALIGN 4
        fmt_control     db 09,'%s #%i',09,'%s',0
        ALIGN 4
        fmt_device      db  '%s #%i    %s',0
        ALIGN 4
        NUM_PIN_TABS EQU 5
        pin_tabs        dd  40,80,90,100,110    ;// do a couple extra just in case

        NUM_CONTROL_TABS EQU 2
        control_tabs    dd  8, 56

.CODE

ASSUME_AND_ALIGN
hid_InitMenu PROC USES edi ebp

        ASSUME esi:PTR HID_OSC_MAP      ;// preserve
        ASSUME edi:PTR OSC_BASE         ;// preserve
        DEBUG_IF <edi!!=[esi].pBase>

    pushd -1        ;// cur sel
    pushd 0         ;// stop
    pushd 0         ;// counter
    sub esp, 128    ;// string space
    st_counter TEXTEQU <(DWORD PTR [esp+128])>
    st_stop    TEXTEQU <(DWORD PTR [esp+128+4])>
    st_cursel  TEXTEQU <(DWORD PTR [esp+128+8])>

    ;// fill in our pin information

        invoke GetDlgItem, popup_hWnd, ID_HID_PINS
        mov ebx, eax

        ;// get the current selection so we can set it again

        WINDOW ebx, LB_GETCURSEL
        test eax, eax
        .IF SIGN?
            xor eax, eax
        .ENDIF
        mov st_cursel, eax

        ;// we always rebuild this because the strings change

        WINDOW ebx, LB_RESETCONTENT

        ;// set the tab stops

        WINDOW ebx, LB_SETTABSTOPS, NUM_PIN_TABS, OFFSET pin_tabs

        ;// fill in the list

        mov ebp, [esi].pData
        ASSUME ebp:PTR hid_CONNECT
        .REPEAT
            mov edi, esp
            .IF [ebp].device.dwPageUsage    ;// are we on ?
                ;// build a nice display string on the stack
                ;// device page usage
                invoke hidusage_GetUsageString, [ebp].device.dwPageUsage, edi
                add edi, eax
                ;// space
                mov al, ' '
                stosb
                ;// instance
                mov eax, [ebp].dwDeviceInstance
                inc eax
                invoke wsprintfA,edi,OFFSET fmt_instance, eax
                add edi, eax
                ;// tab
                mov al, 09h
                stosb
                ;// control page usage
                invoke hidusage_GetUsageString, [ebp].control.dwPageUsage, edi
                add edi, eax
                ;// space
                mov al, ' '
                stosb
                ;// instance
                mov eax, [ebp].dwControlInstance
                inc eax
                invoke wsprintfA,edi,OFFSET fmt_instance, eax
                add edi, eax
                ;// tab
                mov al, 09h
                stosb
                ;// short name from desired connect
                invoke hidusage_GetShortString, [ebp].control.dwPageUsage, edi
                .IF (WORD PTR [edi]) == '??'    ;// no short string found
                    ;// see if we can get the name from the control itself
                    mov ecx, st_counter
                    shl ecx, LOG2(SIZEOF APIN)
                    lea ecx, [esi+ecx].pin_0
                    mov ecx, (APIN PTR [ecx]).dwUser
                    .IF ecx
                        mov ecx, (hid_CONTROL PTR [ecx]).pHIDCONTROL
                        mov ecx, (HIDCONTROL PTR [ecx]).szShortName
                        .IF ecx
                            mov BYTE PTR [edi], cl      ;// ABOX242 AJT
                            mov eax, 1
                            .IF ch
                                inc edi
                                mov BYTE PTR [edi], ch      ;// ABOX242 AJT
                            .ENDIF
                        .ENDIF
                    .ENDIF
                .ENDIF
                add edi, eax    ;// advance
                ;// tab
                mov al, 09h
                stosb
                ;// status, find the pin first
                mov ecx, st_counter
                shl ecx, LOG2(SIZEOF APIN)
                lea ecx, [esi+SIZEOF OSC_OBJECT+ecx]
                ASSUME ecx:PTR APIN
                .IF [ecx].dwUser
                    mov eax, 'KO'
                .ELSE
                    mov eax, '!!!'
                .ENDIF
            .ELSE                           ;// we are off
                mov eax, 'FFO'
            .ENDIF
            ;// set the text
            stosd   ;// and terminate
            WINDOW ebx,LB_ADDSTRING,,esp
            inc st_counter  ;// increase counter now so we add one
            WINDOW ebx,LB_SETITEMDATA,eax,st_counter    ;// set item data as index+1

            ;// next

            add ebp, SIZEOF hid_CONNECT

        .UNTIL st_counter >= HID_NUM_PINS

    ;// fill in the controls list
    ;// if there are already items in it, then we can skip

        invoke GetDlgItem, popup_hWnd, ID_HID_CONTROLS
        mov ebx, eax

        WINDOW ebx, LB_GETCOUNT
        .IF !eax && [esi].pDevice   ;// make sure we have devices and controls

            ;// always add the OFF at the top

            mov (DWORD PTR [esp]), 'FFO'
            WINDOW ebx,LB_ADDSTRING,,esp
            ;// item data = 0

            ;// set the tab stops

            WINDOW ebx, LB_SETTABSTOPS, NUM_CONTROL_TABS, OFFSET control_tabs

            ;// iterate and fill
            mov ebp, [esi].pDevice
            ASSUME ebp:PTR hid_HARDWARE
            mov eax, [ebp].pLastControl
            mov ebp, [ebp].pFirstControl
            ASSUME ebp:PTR hid_CONTROL
            mov st_stop, eax
            mov st_counter, 0   ;// now counter will be a device pointer
            mov edi, esp
            ASSUME edi:PTR BYTE

            ;// device      short name  long name
            ;// control     tab long name instance

            .REPEAT

                ;// new device ?

                mov ecx, [ebp].pDEVICE
                .IF ecx != st_counter

                    mov st_counter, ecx ;// set it so we don't do this twice
                    ASSUME ecx:PTR hid_DEVICE
                    mov ecx, [ecx].pHIDDEVICE
                    ASSUME ecx:PTR HIDDEVICE
                    mov edx, [ecx].dwInstance
                    inc edx
                    invoke wsprintfA,edi,OFFSET fmt_device,ADDR [ecx].szShortName,edx,ADDR [ecx].szLongName
                    WINDOW ebx,LB_ADDSTRING,,esp
                    WINDOW ebx,LB_SETITEMDATA, eax, -1 ;// set item data as -1 so we can ignore

                .ENDIF

                ;// do the controls on this device

                mov ecx, [ebp].pHIDCONTROL
                ASSUME ecx:PTR HIDCONTROL
                mov edx, [ecx].dwInstance
                inc edx
                invoke wsprintfA,edi,OFFSET fmt_control,ADDR [ecx].szLongName, edx, ADDR [ecx].szShortName
                WINDOW ebx,LB_ADDSTRING,,esp
                WINDOW ebx,LB_SETITEMDATA,eax,ebp   ;// item data is a pointer

                add ebp, SIZEOF hid_CONTROL

            .UNTIL ebp > st_stop

        .ENDIF  ;// list already filled in

    ;// set the previous selection in the pin window

        invoke GetDlgItem, popup_hWnd, ID_HID_PINS
        mov ebx, eax
        mov eax, st_cursel
        WINDOW ebx, LB_SETCURSEL, eax

    ;// select an item in the control list, does the button states as well

        invoke select_current_control

    ;// and that's it for strings

        add esp, 128+4+4+4
        st_stop    TEXTEQU <>
        st_counter TEXTEQU <>
        st_cursel  TEXTEQU <>

    ;// that's it, return zero to indicate no resize

        xor eax, eax

        ret

hid_InitMenu ENDP

;//
;//     hid_InitMenu
;//
;//
;//////////////////////////////////////////////////////////////////////////////


;///////////////////////////////////////////////////////////////////////////////////////////
;//
;//
;//     HID COMMAND

.DATA

    hid_popup_busy  dd  0   ;// prevents selection hassles

.CODE

ASSUME_AND_ALIGN
hid_Command PROC

    ASSUME esi:PTR HID_OSC_MAP  ;// must preserve
    ASSUME edi:PTR OSC_BASE     ;// may destroy
    DEBUG_IF <edi!!=[esi].pBase>

        CMPJMP hid_popup_busy, 0, jne osc_Command

    ;// deterine which command we are responding to

        CMPJMP eax, ID_HID_FLOAT_POS, je got_float_pos
        CMPJMP eax, ID_HID_FLOAT_NEG, je got_float_neg
        CMPJMP eax, ID_HID_BOOL_POS, je got_bool_pos
        CMPJMP eax, ID_HID_BOOL_NEG, je got_bool_neg
        CMPJMP eax, OSC_COMMAND_LIST_SELCHANGE, jne osc_Command

    ;// the currently selected item's private dword is passed in ecx
    ;// resource style must have LBS_NOTIFY set

        test ecx, ecx
        js ignore_this_event    ;// ecx == -1   ignore
        jz turn_off_pin         ;// ecx == 0    only OFF in the bottom window has a zero value
        cmp ecx, HID_NUM_PINS
        ja set_a_new_device     ;// ecx > 6     better be a pointer to hid_CONTROL
                                ;// else ecx<= 6    user clicked on the top window

    set_bottom_selection:   ;// top window, ecx-1 is the pin number

        invoke select_current_control

    ;// exit points
    ignore_this_event:
            mov eax, POPUP_IGNORE
    all_done:

            ret


    ALIGN 16
    turn_off_pin:

            invoke GetDlgItem, popup_hWnd, ID_HID_PINS
            WINDOW eax, LB_GETCURSEL
            CMPJMP eax, LB_ERR, je ignore_this_event        ;// oops !
            ;// eax is the pin index we set
            shl eax, LOG2(SIZEOF hid_CONNECT)
            mov ebx, [esi].pData
            add ebx, eax
            ASSUME ebx:PTR hid_CONNECT
            mov [ebx].device.dwPageUsage, 0

        sync_and_exit:

            invoke hid_read_control_signs
            invoke hid_find_controls_and_write_signs

            mov eax, POPUP_KILL_THIS_FOCUS OR POPUP_REDRAW_OBJECT OR POPUP_SET_DIRTY OR POPUP_INITMENU
            jmp all_done

    ALIGN 16
    set_a_new_device:   ;// bottom window, ecx is the ptr to hid control

            mov edi, ecx
            ASSUME edi:PTR hid_CONTROL

            invoke GetDlgItem, popup_hWnd, ID_HID_PINS
            WINDOW eax, LB_GETCURSEL
            CMPJMP eax, LB_ERR, je ignore_this_event        ;// oops !

            ;// eax is the pin index we set
            shl eax, LOG2(SIZEOF hid_CONNECT)
            mov ebx, [esi].pData
            add ebx, eax
            ASSUME ebx:PTR hid_CONNECT

            mov ecx, [edi].pHIDCONTROL
            ASSUME ecx:PTR HIDCONTROL
            mov eax, [ecx].dwPageUsage
            mov edx, [ecx].dwInstance
            mov [ebx].control.dwPageUsage, eax
            mov [ebx].dwControlInstance, edx

            mov edi, [edi].pDEVICE
            ASSUME edi:PTR hid_DEVICE
            mov ecx, [edi].pHIDDEVICE
            ASSUME ecx:PTR HIDDEVICE
            mov eax, [ecx].dwPageUsage
            mov edx, [ecx].dwInstance
            mov [ebx].device.dwPageUsage, eax
            mov [ebx].dwDeviceInstance, edx

            jmp sync_and_exit


    ALIGN 16
    got_float_pos:
    got_bool_pos:

        xor edi, edi
        jmp set_the_format

    ALIGN 16
    got_float_neg:
    got_bool_neg:

        mov edi, HIDCONTROL_OUT_NEGATIVE

    set_the_format:

        invoke GetDlgItem, popup_hWnd, ID_HID_PINS
        WINDOW eax, LB_GETCURSEL
        DEBUG_IF < eax==LB_ERR >    ;// not supposed to happen ??
        ;// eax is the index of the current selection
        shl eax, LOG2(SIZEOF APIN)
        lea ecx, [esi+eax].pin_0
        mov ecx, (APIN PTR [ecx]).dwUser
        DEBUG_IF <!!ecx>
        mov edx, (hid_CONTROL PTR [ecx]).pHIDCONTROL
        mov eax, (HIDCONTROL PTR [edx]).dwFormat
        and eax, NOT HIDCONTROL_OUT_NEGATIVE
        or eax, edi
        mov (HIDCONTROL PTR [edx]).dwFormat, eax

        mov ecx, (hid_CONTROL PTR [ecx]).pDEVICE
        mov ecx, (hid_DEVICE PTR [ecx]).pHIDDEVICE
        or (HIDDEVICE PTR [ecx]).dwFlags, HIDDEVICE_FORMAT_CHANGED

        invoke hid_read_control_signs   ;// make sure dwuser is set up correctly

        jmp sync_and_exit


hid_Command ENDP

;//     HID COMMAND
;//
;//
;///////////////////////////////////////////////////////////////////////////////////////////


;///////////////////////////////////////////////////////////////////////////
;//
;//
;//     _AddExtraSize
;//
ASSUME_AND_ALIGN
hid_AddExtraSize PROC

        ASSUME esi:PTR OSC_OBJECT   ;// preserve
        ASSUME edi:PTR OSC_BASE     ;// preserve
        ASSUME ebx:PTR DWORD        ;// preserve
        DEBUG_IF <edi!!=[esi].pBase>

    ;// task: determine how many extra bytes this object needs
    ;//       ADD it to [ebx]

    ;// do NOT include anything but the extra count
    ;// meaning do not include the size of the common OSC_FILE header
    ;// DO include the size of dwUser

    ;// we use this function to force the osc to update it's sign bits before saving

        push ebx
        invoke hid_read_control_signs
        pop ebx

        add [ebx], HID_numFileBytes

        ret

hid_AddExtraSize ENDP
;//
;//     _AddExtraSize
;//
;//
;///////////////////////////////////////////////////////////////////////////





ASSUME_AND_ALIGN
hid_SaveUndo PROC

        ASSUME esi:PTR HID_OSC_MAP

    ;// edx enters as either UNREDO_CONTROL_OSC or UNREDO_COMMAND
    ;// edi enters as where to store
    ;//
    ;// task:   1) save nessary data
    ;//         2) iterate edi
    ;//
    ;// may use all registers except ebp

    ;// make sure we read the device bits first

        invoke hid_read_control_signs   ;// make sure dwuser is set up correctly

    ;// for devices, we save dwUser and the data

        mov eax, [esi].dwUser
        stosd
        mov esi, [esi].pData
        mov ecx, (SIZEOF hid_DATA) / 4
        rep movsd

    ;// and that should do it

        ret

hid_SaveUndo ENDP



ASSUME_AND_ALIGN
hid_LoadUndo PROC

        ASSUME esi:PTR HID_OSC_MAP  ;// preserve
        ASSUME ebp:PTR LIST_CONTEXT ;// preserve

    ;// edx enters as either UNREDO_CONTROL_OSC or UNREDO_COMMAND
    ;// edi enters as where to load
    ;//
    ;// task:   1) load nessary data
    ;//         2) do what it takes to initialize it
    ;//
    ;// may use all registers except ebp and esi
    ;// return will invalidate HINTI_OSC_UPDATE


    ;// dwUser

        mov eax, [edi]
        btr eax, LOG2(HID_CLIP)
        mov [esi].dwUser, eax
        .IF CARRY?
            or [esi].dwHintI, HINTI_OSC_LOST_BAD
        .ENDIF

    ;// then load the rest and call our internal init function

    push esi
        add edi, 4
        mov esi, [esi].pData
        mov ecx, (SIZEOF hid_DATA) / 4
        xchg esi, edi
        rep movsd
    pop esi

        invoke hid_find_controls_and_write_signs

    ;// that should do it

        ret

hid_LoadUndo ENDP


;///////////////////////////////////////////////////////////////////

ENDIF ;// IFDEF _USE_THIS_FILE_

ASSUME_AND_ALIGN
END
