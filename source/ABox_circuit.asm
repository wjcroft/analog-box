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
;// ABox_circuit.asm        routines that work with the top level circuit
;//
;// TOC
;//
;// circuit_New PROC
;// circuit_Load PROC
;// circuit_Save PROC
;// circuit_SaveBmp


OPTION CASEMAP:NONE
.586
.MODEL FLAT

    .NOLIST
    INCLUDE <ABox.inc>
    INCLUDE <groups.inc>
    .LIST

.CODE



ASSUME_AND_ALIGN
circuit_New PROC

    ;// tasks:  exit any group veiw
    ;//         call context new

        .WHILE app_bFlags & APP_MODE_IN_GROUP
            invoke closed_group_ReturnFromView
        .ENDW

        push ebp

        lea ebp, master_context

    DEBUG_IF <!!(play_status & PLAY_GUI_SYNC)>  ;// supposed to be in play wait

        mov pin_hover, 0    ;// reset this now  ;// mouse_reset_all_hovers PROTO
                            ;// invoke mouse_reset_all_hovers

        invoke context_New

        and app_CircuitSettings, NOT ( CIRCUIT_NOMOVE OR CIRCUIT_NOSAVE OR CIRCUIT_NOEDIT OR CIRCUIT_AUTOPLAY )
        or app_bFlags, APP_SYNC_TITLE OR APP_SYNC_PLAYBUTTON OR APP_SYNC_OPTIONBUTTONS OR APP_SYNC_SAVEBUTTONS
        and mainmenu_mode, NOT (MAINMENU_ABOX1 OR MAINMENU_UNTITLED)

        pop ebp

    ;// reset the unreo table

        invoke unredo_Reset

        ret

circuit_New ENDP


;// DUMP_LOADED_FILES EQU 1     ;// bug hunting

IFDEF DUMP_LOADED_FILES
.DATA

    sz_dump_file db 'c:\windows\desktop\abox2xlate.abox',0

.CODE
ENDIF



ASSUME_AND_ALIGN
circuit_Load PROC

    ;// filename_load_path must be set as the circuit to load
    ;// it will be released when we are done
    ;// filename_circuit_path will be updated on a succesful load

    invoke file_Load    ;// create a new buffer (returned in eax)

    .IF !eax    ;// did it fail ??

        mov eax, filename_get_path
        filename_PutUnused eax
        xor eax, eax
        mov filename_get_path, eax

    .ELSE   ;// must have worked

        push edi
        push ebx
        push esi
        mov edi, eax        ;// store returned pointer

    ;// we need to set the filename so the file object can get to it
    ;// all we do is transfer the pointer

        or app_bFlags, APP_SYNC_TITLE OR APP_SYNC_MRU   ;// schedule for update

        mov eax, filename_get_path      ;// point at source name
        xchg filename_circuit_path, eax
        mov filename_get_path, 0
        .IF eax
            filename_PutUnused eax
        .ENDIF

    ;// then we continue on

        ASSUME edi:PTR FILE_HEADER

        IFDEF DUMP_LOADED_FILES
            mov DWORD PTR [edi], edi    ;// save the start address in the dump
            invoke CreateFileA, OFFSET sz_dump_file, GENERIC_WRITE, FILE_SHARE_READ, 0, CREATE_ALWAYS, 0, 0
            DEBUG_IF <eax==INVALID_HANDLE_VALUE>
            mov ebx, eax
            invoke WriteFile, ebx, edi, MEMORY_SIZE(edi), esp, 0
            invoke CloseHandle, ebx
        ENDIF

    ENTER_PLAY_SYNC GUI

    ;// we're ok to load this, and we always do a new

        invoke circuit_New

    ;// realize the buffer

        push ebp
        lea ebp, master_context         ;// always get the top level context

        invoke context_Load

        pop ebp

    LEAVE_PLAY_SYNC GUI

    ;// transfer the settings and do auto play

        mov eax, [edi].settings
        mov app_CircuitSettings, eax

        .IF eax & CIRCUIT_AUTOPLAY  &&  \
            !(play_status & PLAY_PLAYING)   && \
            master_context.oscR_slist_head

            invoke play_Start

        .ENDIF

    ;// set the mainmenu_mode correctly

        and mainmenu_mode, NOT (MAINMENU_UNTITLED OR MAINMENU_ABOX1)
        .IF file_mode
            or mainmenu_mode, MAINMENU_ABOX1
        .ENDIF

    ;// more clean up

        or app_bFlags, APP_SYNC_EXTENTS OR APP_SYNC_PLAYBUTTON OR APP_SYNC_OPTIONBUTTONS OR APP_SYNC_SAVEBUTTONS

        invoke memory_Free, edi         ;// release the file memory

        mov ebx, filename_get_path
        .IF ebx
            filename_PutUnused ebx      ;// release the name
            mov filename_get_path, 0    ;// clear the load pointer
        .ENDIF

    ;// then we set to flush changing signals

        or master_context.pFlags, PFLAG_FLUSH_PINCHANGE OR PFLAG_FLUSH_PINCHANGE_1

    ;// get on out o here

        pop esi
        pop edi
        pop ebx

        mov eax, 1  ;// return sucess

    .ENDIF

    ;// that's it

        ret

circuit_Load ENDP



ASSUME_AND_ALIGN
circuit_Save PROC

        push ebp
        push esi
        push edi
        push ebx

    ;// saves the file to filename_circuit_path
    ;// schedules app_sync title, mru, savebuttons

    ;// this is called from mainWnd_wm_command_proc
    ;// circuit_save always stores to a file
    ;// and that file is always called filename_circuit_path

    ;// load the master context

        lea ebp, master_context
        ASSUME ebp:PTR LIST_CONTEXT

    ;// step one is to check if we need to rearrange the Zlist for an open group
    ;// this takes care of oscAry_Save and oscAry_copy

        .IF app_CircuitSettings & CIRCUIT_OPEN_GROUP

            invoke opened_group_PrepareToSave

        .ENDIF

    ;// count all the osc's and determine the file size

        pushd SIZEOF FILE_HEADER    ;// make a temp variable for the file size
        mov ebx, esp                ;// ebx is required for next function

        invoke context_GetFileSize  ;// get the file size and osc count
                                    ;// eax returns as the number of oscs
                                    ;// [ebx] returns as the file size

        DEBUG_IF <!!eax>    ;// not supoosed to be able to save empty circuits

        xchg eax, DWORD PTR [esp]   ;// save the size so we know how much to write
                                    ;// load the file size as well
        push eax                    ;// then save again (programmer oversite)

    ;// stack looks like this:
    ;// file_size num_oscs ebx edi esi ebp ret
    ;// 00        04       08  0C  10  14  18

    ;// allocate space for the file

        add eax, 3
        and eax, -4

        invoke memory_Alloc, GPTR, eax
        mov edi, eax        ;// save in edi
        ASSUME edi:PTR FILE_HEADER

    ;// fill in the header

        pop [edi].header                ;// pop the stored file size into the header
        mov edx, app_CircuitSettings    ;// get the current circuit settings
        pop [edi].numOsc                ;// pop the number of oscs
        mov [edi].settings, edx         ;// save circuit settings in the file

        ;// stack is cleaned up

        push edi    ;// save file header pointer on the stack

        ;// stack looks like this
        ;// pFileMem ebx edi esi ebp ret
        ;// 00       04  08  0C  10  14

        invoke context_Save

    ;// create the file

        mov edx, filename_circuit_path
        add edx, OFFSET FILENAME.szPath

        invoke CreateFileA, edx, GENERIC_WRITE, FILE_SHARE_READ,
            0, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0

        mov esi, eax    ;// esi now holds the file handle

    ;// write all of it
    ;// stack looks like this
    ;// pFile   ebx edi esi ebp ret

        GET_FILE_HEADER edi, [esp]  ;// retrieve the allocated memory block
                                    ;// don't pop because we need a temp variable
        mov edx, [edi].header       ;// retrieve the filesize that was stored in the header
        mov [edi].header, ABOX2_FILE_HEADER ;// replace it with the abox header
        mov ecx, esp                ;// then use stack as a pointer byteWritten

        invoke WriteFile, esi, edi, edx, ecx, 0

        pop ecx                     ;// clean up the stack

    ;// file is saved, cleanup and beat feet

        invoke CloseHandle, esi     ;// close the file

        invoke memory_Free, edi     ;// free the memory we just allocated

        and mainmenu_mode, NOT (MAINMENU_ABOX1 OR MAINMENU_UNTITLED)
        or app_bFlags, APP_SYNC_TITLE OR APP_SYNC_MRU OR APP_SYNC_SAVEBUTTONS

    ;// reset the dirty flag
    ;// what we really want to do is xfer pCurrent to last save

        mov eax, unredo_last_action
        mov unredo_last_save, eax
        mov unredo_we_are_dirty, 0

    all_done:

        pop ebx
        pop edi
        pop esi
        pop ebp

        ret

circuit_Save ENDP












BITMAP_FILE_HEADER_SIZE EQU SIZEOF BITMAPFILEHEADER + SIZEOF BITMAPINFOHEADER
BITMAP_BORDER_X EQU 32
BITMAP_BORDER_Y EQU 32


ASSUME_AND_ALIGN
circuit_SaveBmp PROC

        push ebp
        push esi
        push edi
        push ebx

;// we use filename_bitmap_path for this        file_name       TEXTEQU <(DWORD PTR [esp+44h])> ;// pointer to passed file name
        file_size       TEXTEQU <(DWORD PTR [esp+40h])> ;// size of the file

        orig_position   TEXTEQU <(POINT PTR [esp+38h])> ;// how to get back
        extent_size     TEXTEQU <(POINT PTR [esp+30h])> ;// keeps track of total width
        client_size     TEXTEQU <(POINT PTR [esp+28h])> ;// keeps track of client window size
        frame_integer   TEXTEQU <(POINT PTR [esp+20h])> ;// number of frames to scan
        frame_remainder TEXTEQU <(POINT PTR [esp+18h])> ;// remainder for partial frames
        frame_counter   TEXTEQU <(POINT PTR [esp+10h])> ;// used to count frames
        frame_position  TEXTEQU <(POINT PTR [esp+08h])> ;// keeps track of position in the circuit
        frame_size      TEXTEQU <(POINT PTR [esp+00h])> ;// used to iterate the storage of a frame

        stack_size EQU 44h  ;// sub 4 to acount for ebx

    ;// set up the stack

        sub esp, stack_size

    ;// get the context so we can move the screen

        stack_Peek gui_context, ebp
        xor edi, edi

    ;// make sure the app is synced

        invoke mouse_reset_all_hovers
        SET_STATUS status_SAVING_BMP, MANDATORY
        invoke app_Sync

    ;// determine the sizeof of the bitmap

        ;// extent size plus a boarder
        ;// dword align the width
        ;// add extra for the headers and palette
        ;// determine some file positions as well

        ;// orig position

        mov eax, HScroll.dwMin
        mov edx, VScroll.dwMin
        sub eax, BITMAP_BORDER_X + GDI_GUTTER_X
        sub edx, BITMAP_BORDER_Y + GDI_GUTTER_Y
        point_Set orig_position

        ;// extents

        mov eax, HScroll.dwMax
        mov edx, VScroll.dwMax
        sub eax, HScroll.dwMin
        sub edx, VScroll.dwMin

        add eax, BITMAP_BORDER_X * 2
        add edx, BITMAP_BORDER_Y * 2

        and eax, 0FFFFFFFCh ;// dword align the wdith

        point_Set extent_size

        ;// file size

        inc edx ;// add one line
        mul edx
        add eax, BITMAP_FILE_HEADER_SIZE + 256*4
        mov file_size, eax

        ;// client size

        point_GetBR gdi_client_rect
        point_SubTL gdi_client_rect
        sub eax, 32
        sub edx, 32
        point_Set client_size

    ;// compute the scanning parameters

        ;// extent size divided by client width and height
        ;// will be the number of x and y frames

        mov eax, extent_size.x
        xor edx, edx
        div client_size.x
        mov frame_integer.x, eax
        mov frame_remainder.x, edx

        mov eax, extent_size.y
        xor edx, edx
        div client_size.y
        mov frame_integer.y, eax
        mov frame_remainder.y, edx

    ;// create a file and set the size
    ;// if can't open file, show an error

        mov eax, filename_bitmap_path
        add eax, OFFSET FILENAME.szPath

        invoke CreateFileA, eax, GENERIC_WRITE, FILE_SHARE_READ OR FILE_SHARE_WRITE, 0, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL OR FILE_FLAG_RANDOM_ACCESS, 0
        cmp eax, INVALID_HANDLE_VALUE
        je all_done
        mov edi, eax        ;// edi will hold the file pointer for the remainder of the function

        mov eax, file_size
        invoke SetFilePointer, edi, eax, 0, FILE_BEGIN
        invoke SetEndOfFile, edi
        invoke SetFilePointer, edi, 0, 0, FILE_BEGIN

    ;// build and save the header

        mov eax, file_size
        mov ebx, extent_size.x
        mov ecx, extent_size.y

        pushd   256     ;//17   BITMAPINFOHEADER.biClrImportant dd 0
        pushd   256-32  ;//16   BITMAPINFOHEADER.biClrUsed      dd 0
        pushd   2834    ;//15   BITMAPINFOHEADER.biYPelsPerMeter dd 0
        pushd   2834    ;//14   BITMAPINFOHEADER.biXPelsPerMeter dd 0
        pushd   eax     ;//13   BITMAPINFOHEADER.biSizeImage    dd 0
        pushd   BI_RGB  ;//12   BITMAPINFOHEADER.biCompression  dd 0
        pushw   8       ;//11   BITMAPINFOHEADER.biBitCount     dw 0
        pushw   1       ;//10   BITMAPINFOHEADER.biPlanes       dw 0
        pushd   ecx     ;//09   BITMAPINFOHEADER.biHeight       dd 0
        pushd   ebx     ;//08   BITMAPINFOHEADER.biWidth        dd 0
        pushd   40      ;//07   BITMAPINFOHEADER.biSize         dd 40
        pushd   BITMAP_FILE_HEADER_SIZE + 256*4     ;//03   BITMAPFILEHEADER    DWORD   bfOffBits;
        pushd   0       ;//02   BITMAPFILEHEADER    DWORD    bfReserved1;
        pushd   eax     ;//01   BITMAPFILEHEADER    DWORD   bfSize;
        pushw   'MB'    ;//00   BITMAPFILEHEADER    WORD    bfType;
        mov ecx, esp
        sub esp, 2      ;// make sure we keep dword alignment

        pushd 0
        mov edx, esp
        invoke WriteFile, edi, ecx, BITMAP_FILE_HEADER_SIZE, edx, 0
        pop edx
        add esp, BITMAP_FILE_HEADER_SIZE + 2

    ;// write the palette

        pushd 0
        mov edx, esp
        invoke WriteFile, edi, OFFSET oBmp_palette, 256*4, edx, 0
        pop edx

    ;// turn off the mouse

        SET_STATUS status_SAVING_BMP
        invoke EnableWindow, hMainWnd, 0
        invoke LoadCursorA,0,IDC_WAIT
        invoke SetCursor, eax

    ;// set the first position of the screen

        point_Get orig_position
        point_Neg
        point_Set mouse_delta

        or app_bFlags, APP_MODE_MOVING_SCREEN
        invoke context_MoveAll
        and app_bFlags, NOT APP_MODE_MOVING_SCREEN
        SET_STATUS status_SAVING_BMP, MANDATORY
        invoke app_Sync
        invoke UpdateWindow, hMainWnd

    ;// scan Y frames

        mov eax, frame_integer.y
        mov frame_position.y, 0
        mov frame_counter.y, eax

    frame_scan_y:

        ;// scan X frames

            mov eax, frame_integer.x
            mov frame_position.x, 0
            mov frame_counter.x, eax

        frame_scan_x:

            ;// start the Y line scan

                mov ebx, file_size          ;// ebx will scan the file pointer
                mov esi, gdi_pBitsGutter    ;// esi will scan the source bitmap

                ;// initialize the file pointer interator

                mov eax, frame_position.y
                inc eax
                mul extent_size.x
                sub ebx, eax
                add ebx, frame_position.x

                ;// dtermine the width to scan

                cmp frame_counter.x, 0
                mov eax, client_size.x
                jnz @F
                    mov eax, frame_remainder.x
                @@:
                mov frame_size.x, eax

                ;// dtermine the lines to scan

                cmp frame_counter.y, 0
                mov eax, client_size.y
                jnz @F
                    mov eax, frame_remainder.y
                @@:

                mov frame_size.y, eax

                ;// write the lines

                scan_frame_y:

                    invoke SetFilePointer,edi,ebx,0,FILE_BEGIN
                    mov edx, frame_size.x
                    pushd 0
                    mov ecx, esp
                    invoke WriteFile,edi,esi,edx,ecx, 0
                    pop ecx

                    sub ebx, extent_size.x      ;// move file pointer UP one line
                    add esi, gdi_bitmap_size.x  ;// move screen pointer DOWN one line

                    invoke GetAsyncKeyState, VK_ESCAPE
                    .IF eax & 8001h
                        jmp all_done
                    .ENDIF

                    dec frame_size.y    ;// decrease the scan count

                    jns scan_frame_y

            ;// jump to next frame

            frame_scan_x_next:

                invoke FlushFileBuffers, edi

                dec frame_counter.x
                js frame_scan_y_next

                mov eax, client_size.x
                xor edx, edx
                add frame_position.x, eax
                neg eax

                point_Set mouse_delta
                or app_bFlags, APP_MODE_MOVING_SCREEN
                invoke context_MoveAll
                and app_bFlags, NOT APP_MODE_MOVING_SCREEN
                SET_STATUS status_SAVING_BMP
                invoke app_Sync
                invoke UpdateWindow, hMainWnd

                jmp frame_scan_x

        frame_scan_y_next:

            dec frame_counter.y
            js frame_scan_y_done

            mov ecx, client_size.y
            add frame_position.y, ecx
            mov frame_position.x, 0

            mov eax, extent_size.x
            mov edx, client_size.y
            sub eax, frame_remainder.x
            neg edx

            point_Set mouse_delta
            or app_bFlags, APP_MODE_MOVING_SCREEN
            invoke context_MoveAll
            and app_bFlags, NOT APP_MODE_MOVING_SCREEN
            SET_STATUS status_SAVING_BMP
            invoke app_Sync
            invoke UpdateWindow, hMainWnd

            jmp frame_scan_y

        frame_scan_y_done:
        all_done:

    ;// close the file

        .IF edi

            invoke CloseHandle, edi

        .ENDIF

    ;// return to origonal position

        point_Get frame_position
        point_Add orig_position

        point_Set mouse_delta
        or app_bFlags, APP_MODE_MOVING_SCREEN
        invoke context_MoveAll
        and app_bFlags, NOT APP_MODE_MOVING_SCREEN
        invoke app_Sync
        invoke UpdateWindow, hMainWnd

        invoke LoadCursorA,0, IDC_ARROW
        invoke SetCursor, eax
        invoke EnableWindow, hMainWnd, 1

    ;// that should do it

        add esp, stack_size
        pop ebx
        pop edi
        pop esi
        pop ebp

        ret


circuit_SaveBmp ENDP

































ASSUME_AND_ALIGN

END
