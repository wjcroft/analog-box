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
;//     HIDObject.inc
;//
IFNDEF _HIDOBJECT_INCLUDED_
_HIDOBJECT_INCLUDED_ EQU 1

comment ~ /*

        HIDDEVICE   one per known device, container of HIDControl
        HIDCONTROL  one per device control, may be just a bit

        The HIDCONTROL is used to parse the input HIDREPORT created by the device

        External routine may then ask questions of the control

*/ comment ~

    ;//////////////////////////////////////////////////////////////////////////////////
    ;//
    ;//     nessesary includes
    ;//

        ALLOC2 EQU 1
        INCLUDE _malloc.inc

        INCLUDE utility.inc
        INCLUDE dlist3.inc
        INCLUDE clist3.inc

        INCLUDE win32A_imp.inc

        HID_NOLIBRARY EQU 1     ;// define to prevent HID library load at app start up
        INCLUDE <win32A_HID.inc>

        INCLUDE HIDUsage.inc

    ;//////////////////////////////////////////////////////////////////////////////////
    ;//
    ;//     PAGEUSAGE is used, here is the packed and unpacked form
    ;//


        PAGEUSAGE UNION

            STRUCT
                wUsage  dw  0
                wPage   dw  0
            ENDS
            dwPageUsage dd  0

        PAGEUSAGE ENDS



    ;//////////////////////////////////////////////////////////////////////////////////
    ;//
    ;// HID CONTROL     list owned by HIDDEVICE
    ;//

        HIDCONTROL STRUCT

            ;// information read from the device itself or by reading the registry key

                PAGEUSAGE       {}      ;// if known, the control type, packed usage page and usage value
                dwInstance      dd  0   ;// if multiple of same usage, this counts them
                ;// must either call hidevice_ReadNextReport or hidevice_BuildFormats to set this

                szShortName dd 0        ;// two char short name for ABox
                szLongName  db HIDUSAGE_MAX_STRING_SIZE DUP(0)  ;// name of this node (may be zero)

            ;// format information, either derived or read from registry

                dwFormat    dd  0

                ;// input/editing commands and how the registry string sets them

                HIDCONTROL_FORMAT       EQU 0000000Fh   ;// masker

            ;// HIDDEVICE_IN_LE         EQU 00000000h   ;// L
                HIDDEVICE_IN_BE         EQU 00000001h   ;// B

            ;// HIDCONTROL_IN_BOOL      EQU 00000000h   ;// B
            ;// HIDCONTROL_IN_UNSIGNED  EQU 00000000h   ;// U
                HIDCONTROL_IN_SIGNED    EQU 00000002h   ;// S

                ;// user commands

            ;// HIDCONTROL_OUT_INTEGER  EQU 00000000h   ;// I
                HIDCONTROL_OUT_FLOAT    EQU 00000004h   ;// F

            ;// HIDCONTROL_OUT_POSITIVE EQU 00000000h   ;// +
                HIDCONTROL_OUT_NEGATIVE EQU 00000008h   ;// -

            ;////////////////////////////////////////////////

                W0  dd  0   ;// start bit reletive to begining of data array (BE requires convertion)
                W1  dd  0   ;// last bit, may equal first bit (BE requires convertion)
                    ;// for LE formats, W0 is the LOWEST bit
                    ;//                 W1 is the HIGHEST bit
                    ;// for BE formats, W1 XOR 7 is the equivalent LOWEST BIT in LE format
                    ;//                 W0 XOR 7 is the equivalent HIGHEST BIT in LE format
                    ;//                 this assures that the container remains in order
                    HIDCONTROL_MAX_BITS EQU 24
                    ;// for now, do not allow more than 24 bits
                    ;// this assures we can read dwords and get all the data

            ;// data converter values derived from the above

                dwRead  dd  0   ;// read position inside the report, either bit or byte
                S1  dd  0       ;// shift (maybe right or left)
                S2  dd  0       ;// shift or and_mask

                normalizer  REAL4 0.0   ;// scalar if float

            ;// the current data itself

                dwValue dd 0            ;// converted value, depends on format

            ;// control node navigation

                dlist_Declare_link  hidcontrol, HIDCONTROL  ;// used to navigate

        HIDCONTROL ENDS



    comment ~ /*


        dir off/on      bit
        --- ----------  ---  -------------------
        in  LE/BE        0   read from device
        in  !SIGN/SIGN   1   read from control if !BOOL then ignore
        out INT/FLOAT    2   assigned by user
        out POS/NEG      3   if INT, ignore
                             if !SIGN, ignore
                             if BOOL then BIP/DIG

    */ comment ~




    ;//////////////////////////////////////////////////////////////////////////////////
    ;//
    ;// HIDREPORT   wrapper, there may be many of these owned by the device
    ;//

        HIDREPORT STRUCT

            overlapped  OVERLAPPED {}   ;// needed for polling, hEvent created and set when device is opened
            clist_Declare_link hidreport, HIDREPORT
            dwBytesRead dd  0   ;// number of bytes that are read
            ;// DATA ALWAYS FOLLOWS

        HIDREPORT ENDS

    ;//////////////////////////////////////////////////////////////////////////////////
    ;//
    ;// HID DEVICE
    ;//


        HIDDEVICE STRUCT

            dlist_Declare_link hiddevice, HIDDEVICE     ;// list of devices
            dlist_Declare_indirected hidcontrol         ;// controls owned by this device

            PAGEUSAGE           {}      ;// usage page and usage value read from the device
                                        ;// may be overridden by a registry string
            dwInstance          dd  0   ;// instance of this page usage
            dwInputReportSize   dd  0   ;// number of bytes in one report

            dwFlags             dd  0   ;// data type flags and signals

                HIDDEVICE_IN_BE             EQU 00000001h   ;// MUST EQUAL 1 !!! data is in BIG EDNDIAN

                ;// write only signals from some other place
                HIDDEVICE_FORMAT_CHANGED    EQU 00000008h   ;// true if we need to call hidmask_build_format

            hHidDevice          dd  0   ;// handle of opened device, zero for closed
            pReportMemory       dd  0   ;// so we can deallocate the reports
            clist_Declare_indirected hidreport  ;// MRS for the hid report, it does all the pointing
            pLastReport         dd  0   ;// ptr to the last report processed by hid_convert_data
                                        ;// may not be correct after a length of time
                                        ;// only used for getting raw unassigned bits

            szRegValueName  db  32 DUP (0)  ;//  4.4X_4.4X_4.4X_4.4X_4.4X     0
                                            ;//  vend prod page use repsize

            HID_MAX_NAME_LENGTH EQU 128     ;// including null terminator

            szFileName  db  HID_MAX_NAME_LENGTH DUP (0)
            szLongName  db  HID_MAX_NAME_LENGTH DUP (0)         ;// is the product string
            szShortName db  HIDUSAGE_MAX_STRING_SIZE DUP (0)    ;// read from hidusage_GetUsageString

        HIDDEVICE ENDS

        ;// master list exists in HIDObject.asm
        ;// should be private to our object

        dlist_Declare_external hiddevice

        ;// applications should not call these, needed by HIDTree.asm
        hidcontrol_create_this_node PROTO   ;// see function, register call
        hidcontrol_Dtor PROTO STDCALL pDevice:DWORD, pControl:DWORD


    ;//////////////////////////////////////////////////////////////////////////////////
    ;//
    ;//     PUBLIC INTERFACE
    ;//

        ;// Ctor Dtor   there is only one hid object per application

            hidobject_Initialize PROTO STDCALL
            ;// reads all it can, returns pObject, ptr first device in the master list
            ;// or zero for error

            hidobject_Destroy PROTO STDCALL
            ;// frees all resources

        ;// device,control navigation

            hidobject_EnumDevices PROTO STDCALL pObject:DWORD, pDevice:DWORD
            ;// if pDevice is zero, returns the first HIDDEVICE
            ;// if pDevice is not zero, returns the next device in the list

            hiddevice_EnumControls PROTO STDCALL pDevice:DWORD, pControl:DWORD
            ;// if pControl is zero, returns the first HIDCONTROL of said device
            ;// if pControl is not zero, returns the next control

        ;// device open and close

            hiddevice_Open  PROTO STDCALL, pDevice:DWORD
            ;// opens the device, returns non zero for sucess

            hiddevice_Close PROTO STDCALL, pDevice:DWORD
            ;// closes the device

        ;// force formats to be built

            hiddevice_BuildFormats PROTO STDCALL, pDevice:DWORD
            ;// this is also done by hiddevice_ReadNextReport
            ;// using BuildFormats will guarantee the instance values are built

        ;// reading data from a device

            hiddevice_CountReports PROTO STDCALL, pDevice:DWORD
            ;// returns the number available
            ;// (new data is still captured but is not reported until next call)

            hiddevice_ReadNextReport PROTO STDCALL, pDevice:DWORD
            ;// converts the next input report and updates the controls

        ;// for saving to registry, use this key

            EXTERNDEF szHidObjectRegKey:BYTE



ENDIF   ;// _HIDOBJECT_INCLUDED_