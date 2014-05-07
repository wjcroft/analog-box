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
;// file_hardware.asm       hardware routines fort he file object
;//

OPTION CASEMAP:NONE
.586
.MODEL FLAT

USE_THIS_FILE equ 1
IFDEF USE_THIS_FILE


    .NOLIST
    INCLUDE <Abox.inc>
    INCLUDE <abox_OscFile.inc>
    .LIST


.CODE



ASSUME_AND_ALIGN
file_H_Ctor PROC    ;// STDCALL USES esi edi

    ;// allocate and fill in the required device block stuff

        push edi
        slist_AllocateHead hardwareL, edi
        ;// FILE_HARDWARE_DEVICEBLOCK
        mov [edi].pBase, OFFSET osc_File
        mov [edi].dwFlags,HARDWARE_SHARED ;// allow any number of devices to share
        pop edi

        ret

file_H_Ctor ENDP


ASSUME_AND_ALIGN
file_H_Dtor PROC;// STDCALL pDevBlock:PTR FILE_HARDWARE_DEVICEBLOCK

    ;// nothing to do

    ret 4

file_H_Dtor ENDP




ASSUME_AND_ALIGN
file_H_Open PROC STDCALL USES esi edi pDevice:PTR FILE_HARDWARE_DEVICEBLOCK

FILE_DEBUG_MESSAGE <"file_H_Open\n">

        mov edi, pDevice
        ASSUME edi:PTR FILE_HARDWARE_DEVICEBLOCK

        DEBUG_IF <[edi].hDevice>    ;// opening an open device, not good

        mov eax, 1
        mov [edi].hDevice, eax      ;// open the device by setting 1 in the device ptr

        xor eax, eax                ;// we can open

    ;// that's it

        ret

file_H_Open ENDP



ASSUME_AND_ALIGN
file_H_Close PROC STDCALL USES esi edi ebx pDevice:PTR FILE_HARDWARE_DEVICEBLOCK

    ;// here, we close the device and unprepare the headers

FILE_DEBUG_MESSAGE <"file_H_Close_____________ENTER\n">

        mov edi, pDevice
        ASSUME edi:PTR FILE_HARDWARE_DEVICEBLOCK

    ;// scan the file_hardware_list for opened media writers

        dlist_GetHead file_hardware, ebx, edi   ;// OSC_FILE_DATA
        .WHILE ebx

            .IF [ebx].writer.hmmio  ;// FILE_WRITER

                lea esi, [ebx-OSC_FILE_MAP.file]
                ASSUME esi:PTR OSC_FILE_MAP
                DEBUG_IF <[esi].pData !!= ebx>  ;// supoosed to be
                invoke writer_Flush
                invoke writer_Prepare

            .ENDIF
            dlist_GetNext file_hardware, ebx
        .ENDW

    ;// then close the device

        xor eax, eax
        mov [edi].hDevice, eax

FILE_DEBUG_MESSAGE <"file_H_Close_____________EXIT\n">

    ;// that's it

        ret

file_H_Close ENDP



ASSUME_AND_ALIGN
file_H_Ready PROC   ;// STDCALL USES esi edi pDevice:PTR FILE_HARDWARE_DEVICEBLOCK

    ;// we're always ready
    xor eax, eax    ;// don't need to return anything
    ret 4

file_H_Ready    ENDP




ASSUME_AND_ALIGN
file_H_Calc PROC    ;// STDCALL pDevice:PTR FILE_HARDWARE_DEVICEBLOCK

    ;// may use all registers except esi ebp
    ;// here we are going to turn off all the datafile.dwFlags DATA_FILE_SIZE_READ bits

    mov ebx, [esp+4]    ;// load the deviceblock pointer
    ASSUME ebx:PTR FILE_HARDWARE_DEVICEBLOCK
    dlist_GetHead file_hardware, ebx, ebx
    ASSUME ebx:PTR OSC_FILE_DATA
    .IF ebx
    .REPEAT
        and [ebx].datafile.dwFlags, NOT (DATA_FILE_SIZE_READ OR DATA_FILE_BUFFER_READY)
        dlist_GetNext file_hardware,ebx
    .UNTIL !ebx
    .ENDIF

    retn 4  ;// STDCALL 1 arg

file_H_Calc ENDP















;///////////////////////////////////////////////////////////////////////////////





ASSUME_AND_ALIGN

ENDIF   ;// USE_THIS_FILE
END



