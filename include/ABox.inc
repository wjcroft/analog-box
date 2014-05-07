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
;//         -- version number += 0.01
;//         -- changed to osc_Clock_speed_string for about panel 
;//         -- added pfVirtualProtect for the equation anf dif sys objects
;//            many thanks to qWord and the folks at masm32.com
;//
;//##////////////////////////////////////////////////////////////////////////
;//
;// ABox.inc       this is the common include file for all modules
;//
;// custom build settings for DevStudio:
;// these must be set for each asm file
;//
;// debug:
;//     ml /c /Cp /Cx /coff /Zi         ;// don't link, preserve case, coff format, code view info
;//     /DDEBUGBUILD                    ;// define this symbol for debug options
;//     /FR$(OutDir)\$(InputName).sbr   ;// creates browser file
;//     /Fl$(OutDir)\$(InputName).lst   ;// creates listing file
;//     /Fo$(OutDir)\$(InputName).obj   ;// creates object file
;//     /Sg /Sn /nologo                 ;// list assembly generated code with no symbol table
;//     /I$(ProjDir)\include            ;// set include directory
;//     $(InputDir)\$(InputName).asm    ;// source file name
;//
;//     ml /c /Cp /Cx /coff /DDEBUGBUILD /Zi /FR$(OutDir)\$(InputName).sbr /Fl$(OutDir)\$(InputName).lst /Fo$(OutDir)\$(InputName).obj /Sg /Sn /nologo /I$(ProjDir)\include $(InputDir)\$(InputName).asm
;//
;// release:
;//     ml /c /Cp /coff /Cx /nologo     ;// don't link, preserve case, coff format, no logo
;//     /I$(ProjDir)\include            ;// set include directory
;//     /Fo$(OutDir)\$InputName).obj    ;// creates object file
;//     $(InputDir)\$(InputName).asm    ;// source file name
;//
;//     ml /c /Cp /coff /Cx /nologo /I$(ProjDir)\include /Fo$(OutDir)\$(InputName).obj $(InputDir)\$(InputName).asm
;//
;// browser:    for some reason, devstudio keeps removing this
;//             insert in the pre-link tab
;//
;//     bscmake /nologo $(OutDir)\abox.sbr $(OutDir)\*.sbr
;//
;//  resources:
;//     h2inc /C  /nologo resource.h
;//     set 'ignore standard include paths'
;//     add an afxres.h to the project with some equates for various flags
;//
;// use build_popup to convert abox.rc to popup_data.asm
;//
;// link:
;//     remove all the default libs in the edit box
;//     change system:console to system:windows
;//     turn off link incrementally
;//     use /FIXED
;//     use /SECTION:.text,ERW
;//
IFNDEF _ABOX_INCLUDED_
_ABOX_INCLUDED_ EQU 1


;// top level configuration

    IFDEF DEBUGBUILD
     USE_DEBUG_PANEL    EQU 1       ;// build and update the debug panel
    ENDIF

;// this sets the version number

        ABOX_VERSION        TEXTEQU <242>
        ABOX_VERSION_STRING TEXTEQU <'2.42'>
        ABOX_VERSION_STRING_REVERSE TEXTEQU <'24.2'>

;// W I N D O W S AND H E L P E R S

;// memory

        ALLOC2 EQU 1                ;// GLOBALALLOC = memory_Alloc
        INCLUDE _malloc.inc         ;// new memory_Alloc and GLOBALALLOC

;// utility includes

        INCLUDE <utility.inc>       ;// debug and GP macros
        INCLUDE <string.inc>        ;// macros for strings
        INCLUDE <geometry.inc>      ;// points and rects
        INCLUDE <fpu_math.inc>      ;// some macros for functions
        INCLUDE <testjump.inc>      ;// one line test and jmp macros

;// list macros

        INCLUDE <stack.inc>         ;// context stack list
        INCLUDE <slist3.inc>        ;// singley linked list, ver3 (+indirectable+cleanedup init)
        INCLUDE <dlist3.inc>        ;// doubley linked list, ver3 (+indirectable+cleanedup init)
        INCLUDE <clist3.inc>        ;// circular list        ver3 (+indirectable+cleanedup init)
        INCLUDE <pool3.inc>         ;// pools of fixed size structures
        INCLUDE <hashd3.inc>        ;// simple hash table

;// win32 includes

        INCLUDE <win32A_imp.inc>    ;// jumpless version of windows functions

;// abox includes

        INCLUDE <math.inc>          ;// definitions of tables and what not

        INCLUDE <gdi.inc>           ;// display declarations
        INCLUDE <containers.inc>    ;// linked list of containers

        INCLUDE <resource.inc>      ;// dialogs and icons
        INCLUDE <abox_objects.inc>  ;// object id's and command values, xlated from aboxobjects.h
        INCLUDE <object_bitmap.inc> ;// info about the object's blit source, built by bmp2asm
                                    ;// built by bmp_to_asm.cpp

        INCLUDE <ABox_strings.inc>  ;// extern defs for strings
        INCLUDE <popup_strings.inc> ;// externdefs for popup strings

        INCLUDE <auto_unit.inc>     ;// values for the units

        INCLUDE <unredo.inc>        ;// mechanisms for undo redo

        INCLUDE <misc.inc>          ;// helper functions


;// debugging

    ;// IFDEF USE_DEBUG_PANEL
        INCLUDE <debug.inc>         ;// status panel window and monitoring routines
        INCLUDE <message_log.inc>   ;// detailed message logs for the whole app
;// MESSAGE_LOG_ON
MESSAGE_LOG_OFF
    ;// ENDIF


;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;///
;///    M I S C E L L A N E O U S   S T U F F
;///

;// SAMPLES

    SAMARY_LENGTH   equ 1024    ;// size of each block in dwords
    SAMARY_SIZE     equ 4096    ;// size in bytes
    SAMARY_SHIFT    equ LOG2(SAMARY_SIZE)   ;// 2^12 = 4096

    SAMARY_LASTSAMPLE equ SAMARY_SIZE - 4   ;// useful for getting the last sample
    LAST_SAMPLE equ  SAMARY_LASTSAMPLE      ;// more straight forward

    MAX_SAMPLE_BUFFERS equ 32       ;// max buffers for devices that collect buffers

    SAMPLE_RATE equ 44100           ;// fixed sample rate

;// differential editor

    EXTERNDEF diff_atom:DWORD
    EXTERNDEF diff_szName:BYTE
    EXTERNDEF diff_hWnd:DWORD
    diff_Proc PROTO ;// STDCALL hWnd:dword, msg:dword, wParam:dword, lParam:dword

;// pins

    PIN_DEFAULT_S       TEXTEQU <0.1e+0>
    PIN_DEFAULT_Q       TEXTEQU <3.0e+0>


;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;///
;/// FILE and COPY BUFFER
;///
comment ~ /*

    every file starts with a FILE_HEADER
    followed by an array of variable sized blocks
    each block has three parts

        FILE_OSC    block header                    fixed size
        extra       any size array of osc data      size stated by FILE_OSC.extra
        FILE_PIN    array of pins                   length stated by FILE_OSC.numPins

*/ comment ~

    ABOX1_FILE_HEADER equ 786F6241h  ;// 'Abox' 'xobA'
    ABOX2_FILE_HEADER equ 786F4241h  ;// 'ABox' 'xoBA'

    ;// every file starts with this block

        FILE_HEADER STRUCT

            header      dd  0   ;// 'Abox' or 'ABox'
            numOsc      dd  0   ;// number of oscs we expect to see
            settings    dd  0   ;// file settings use the CIRCUIT_SETTINGS flags
            pEOB        dd  0   ;// end of the file block (meaningless at load time)

        FILE_HEADER ENDS

    ;// after the headers are sets of these structs

        FILE_OSC    STRUCT

            UNION
                id      dd  0   ;// id of the object from the file
                pBase   dd  0   ;// base pointer assumed by the ctor
            ENDS                ;// xlated by file_Load
            ;// if this value becomes zero, the object will be ignored

            numPins     dd  0   ;// number of pins in this block
            pos      POINT  {}  ;// position of object
            extra       dd  0   ;// extra bytes BETWEEN this struct and the pin table

        FILE_OSC    ends

        ;// special osc data follows this
        ;//  dwUser is ALWAYS first
        ;// then the first n bytes of custom oscdata

        ;// then this osc's pin records
        ;// if num pins was zero, then these records do not exist
        ;// extremely important that this reamains at three dwords

        FILE_PIN struct

            pSave dd 0      ;// pointer to the pin's adress at save time
                            ;// gets translated during realize to the value at load time
            pPin  dd 0      ;// the pPin value at save time (what the pin connects to)
                            ;// this may also be a bus number (abox1 added the pin_ouput bit as well)
            pheta REAL4 0.0e+0  ;// the pin's pheta value, ignored for abox1

        FILE_PIN ENDS

        comment ~ /*

            the scheme is:

            realize buffer  will negate all the pSave and pPin pointer values
                            bus indexes remain unchanged
            this will eliminate the chance of a duplicate pointer (it can happen)

            osc_Ctor    will replace pSave with the new pin address,
                        then scan the file block and replace all matching pPin values

            file_Connect pins can then simply scan the file block and call connect

            file_CheckConnections has a problem however:

                there is no simple way in this scheme to detect bus outputs
                thus, there is no simple way to detect output collisions during a paste operation

                abox1 solved this by storing the output bit with the bus number

                the only other way is:
                    determine the index of the pin
                    determine the base class of the osc
                    lookup the pin in apin_init array

                another option is to replace with direct connect
                but again, we have to where where the ouput pin is

                another option is:

                    place file_CheckConnections AFTER file_RealizeBuffer
                                            and BEFORE file_ConnectPins
                    this way we can query the pin directly



        */ comment ~

    ;////////////////////////////////////////////////////////////////////
    ;//                                         macro
    ;//
    ;//     FILE_ID_TO_BASE
    ;//
    ;// given a register with an ID, this will find the base class
    ;// and return it in iter. May return zero.
    ;// fall through is always NOT in list

        FILE_ID_TO_BASE MACRO id:req, iter:req, exit_yes:req

            LOCAL JJ1, JJ2

            IFIDNI <id>,<iter>
                .ERR <registers must not be the same>
            ENDIF

            slist_GetHead baseB, iter
            ;// mov iter, OFFSET baseB_HEAD
            ;// ASSUME iter:PTR OSC_BASE
            JJ1:cmp [iter].data.ID, id      ;// compare
                je exit_yes                 ;// jump if same
                ;//mov iter, [iter].data.slist_pNext_baseB
                slist_GetNext baseB, iter   ;// get the next base
                test iter, iter             ;// check for zero
                jz JJ2                      ;// jump if done (not found)
                cmp [iter].data.ID, id      ;// compare
                je exit_yes                 ;// jump if same
                ;//mov iter, [iter].data.slist_pNext_baseB
                slist_GetNext baseB, iter   ;// get the next base
                test iter, iter             ;// check for zero
                jnz JJ1                     ;// keep looping if not done
            JJ2:

            ENDM


    ;/////////////////////////////////////////////////////////////////
    ;///
    ;/// FILE macros    use these to manage FILE_OSC and FILE_PIN structs
    ;///

        GET_FILE_HEADER MACRO reg:req, where
        ;//
        ;// loads and assume pFileHeader
        ;//
            IFNB <where>
                mov reg, where
            ELSE
                mov reg, pFileHeader
            ENDIF
            ASSUME reg:PTR FILE_HEADER

            ENDM

        OR_GET_FILE_HEADER MACRO reg:req, where
        ;//
        ;// loads, tests and assumes pFileHeader
        ;//
            IFNB <where>
                or reg, where
            ELSE
                or reg, pFileHeader
            ENDIF
            ASSUME reg:PTR FILE_HEADER

            ENDM

        GET_FILE_OSC MACRO reg:req, where
        ;//
        ;// loads and assume pFileOsc
        ;//

            IFNB <where>
                mov reg, where
            ELSE
                mov reg, pFileOsc
            ENDIF
            ASSUME reg:PTR FILE_OSC

            ENDM


        FILE_HEADER_TO_FIRST_OSC MACRO reg:req, reg2
        ;//
        ;// moves reg to first file record
        ;// then assume reg as FILE_OSC
        ;//
            IFNB <reg2>
                lea reg2, [reg+SIZEOF FILE_HEADER]
                ASSUME reg2:PTR FILE_OSC
            ELSE
                add reg, SIZEOF FILE_HEADER
                ASSUME reg:PTR FILE_OSC
            ENDIF

            ENDM

        FILE_OSC_TO_NEXT_OSC MACRO reg:req, temp:=<eax>
        ;//
        ;// moves reg to next FILE_OSC_RECORD
        ;// does not trap for end
        ;// if reg is not already assumed to FILE_OSC the function will fail

            IFIDNI <reg>,<temp>
            .ERR <cant use the same registers for this macro>
            ENDIF

            mov temp, [reg].numPins     ;// load num pins
            lea temp, [temp+temp*2]     ;// *3
            shl temp, 2                 ;// =*12
            add temp, [reg].extra       ;// + extra stuff
            lea reg, [reg+temp+SIZEOF FILE_OSC];// reg is now the next record

            ENDM

        FILE_OSC_TO_FIRST_PIN MACRO reg:req, reg2
        ;//
        ;// advances reg to the pin table
        ;// does not check for missing pins section or end of file
        ;// if reg is not already assumed to FILE_OSC the function will fail
        ;// assumes the register to FILE_PIN
        ;//

            IFNB <reg2>

                IFIDNI <reg>,<reg2>
                .ERR <registers must not be the same>
                ENDIF

                mov reg2, [reg].extra
                lea reg2, [reg+reg2+SIZEOF FILE_OSC]
                ASSUME reg2:PTR FILE_PIN

            ELSE

                add reg, [reg].extra
                add reg, SIZEOF FILE_OSC
                ASSUME reg:PTR FILE_PIN

            ENDIF

            ENDM


        FILE_OSC_TO_BASE MACRO regO:req, regB:req

            ;// retrieves and assumes the base class

            mov regB, [regO].pBase
            ASSUME regB:PTR OSC_BASE

            ENDM

        FILE_OSC_BUILD_PIN_ITERATORS MACRO reg1:req, reg2:req
        ;// assuming reg1 points at the start of a FILE_OSC record
        ;// this builds two values
        ;// reg1 will end up at the FIRST pin in the block
        ;// reg2 will end up at the NEXT osc
        ;// subsequent code can then use WHILE reg1 < reg2 to scan the pins
        ;// as an added bonus, at the end of the scan, reg1 will equal reg2

        ;// macro will fail if reg1 is not assumed as a FILE_OSC

            IFIDNI <reg1>,<reg2>
            .ERR <registers must be different>
            ENDIF

            mov reg2, [reg1].numPins    ;// load num_pins from the FILE_OSC
            add reg1, [reg1].extra      ;// add reg1 with it's extra bytes
            lea reg2, [reg2+reg2*2]     ;// num_pins * 3
            add reg1, SIZEOF FILE_OSC   ;// reg1 points at the first pin
            lea reg2, [reg1+reg2*4]     ;// reg2 is now the next record
            ASSUME reg1:PTR FILE_PIN

            ENDM




    ;////////////////////////////////////////////////////////////////////
    ;//
    ;//
    ;//     extern parameters
    ;//


    ;// this is the copy buffer

        EXTERNDEF file_pCopyBuffer:DWORD    ;// pointer to copy memory
        EXTERNDEF file_bValidCopy:DWORD     ;// set true if file_pCopy has valid info

        EXTERNDEF context_bCopy:DWORD       ;// needed kludge so closed groups can be copied
        EXTERNDEF context_group_recording:DWORD ;// another kludge so unredo works


;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;///
;///    T H E   A B O X   C H A S S I S
;///

;// here are structs needed to build an osc base
;// these are broken up because MASM doesn't like long lines
;//
;//     OSC_BASE
;//         OSC_CORE    function to create and calculate
;//         OSC_GUI     function for display, mouseing and storage
;//         OSC_DATA    data sizes for creating the object
;//         OSC_HARD    functions for hardware devices
;//         OSC_DISPLAY display locations

    ;// CORE functions tell how to create the object, how to calculate

        OSC_Ctor TYPEDEF PROTO
        ptr_Ctor TYPEDEF PTR OSC_Ctor

            ;// register call
            ;// ASSUME ebp:PTR LIST_CONTEXT ;// preserve
            ;// ASSUME esi:PTR OSC_OBJECT   ;// preserve
            ;// ASSUME edi:PTR OSC_BASE     ;// may destroy
            ;// ASSUME ebx:PTR FILE_OSC     ;// may destroy
            ;// ASSUME edx:PTR FILE_HEADER  ;// may destroy

        OSC_Dtor TYPEDEF PROTO
        ptr_Dtor TYPEDEF PTR OSC_Dtor

        OSC_CALC TYPEDEF PROTO
        ptr_Calc TYPEDEF PTR OSC_CALC

        OSC_PREPLAY TYPEDEF PROTO
        ptr_PrePlay TYPEDEF PTR OSC_PREPLAY

        OSC_CORE STRUCT

            Ctor    ptr_Ctor 0  ;// pointer to an initialize function   ;// called by osc_Ctor
            Dtor    ptr_Dtor 0  ;// pointer to deinititialize function  ;// called by osc_Dtor

            PrePlay ptr_PrePlay  0  ;// pointer to preplay function     ;// called when play start
            Calc    ptr_Calc 0      ;// pointer to calc function        ;// called to calculate

        OSC_CORE ENDS



    ;// GUI functions tell how to display the object and respond to user events
    ;// most are register calls, see implementations for details

    ;// REGISTER CALLS:
    ;//
    ;//     ASSUME esi:PTR OSC_OBJECT   ;// preserved
    ;//     ASSUME edi:PTR OSC_BASE     ;// preserved

        OSC_Render      TYPEDEF PROTO
        ptr_Render      TYPEDEF PTR OSC_Render

        OSC_SetShape    TYPEDEF PROTO
        ptr_SetShape    TYPEDEF PTR OSC_SetShape

        OSC_HitTest     TYPEDEF PROTO
        ptr_HitTest     TYPEDEF PTR OSC_HitTest

            ;// return carry flag if osc control
            ;// return no flags otherwise (ns nc nz)

        OSC_Move        TYPEDEF PROTO
        ptr_Move        TYPEDEF PTR OSC_Move

        OSC_Control     TYPEDEF PROTO
        ptr_Control     TYPEDEF PTR OSC_Control

            ;// eax will have the WM_MOUSE msg that caused this call
            ;// objects must return CON_HAS_MOVED if their value has changed
            ;// this makes sure the unredo and dirty gets set correctly

        OSC_Command     TYPEDEF PROTO
        ptr_Command     TYPEDEF PTR OSC_Command
        ;// eax will be the command ID to handle
        ;// ecx may or may not contain extra data


        ;// COMMAND LIST    ;// see IDM_OSC for a list of key code derived values
                            ;// in abox_objects.h not abox_objects.inc
                            ;// see top of hwnd_popup.asm for more notes

        ;// ABOX233: we have grown to the point of having value collisions
        ;// therefore: all windows messages are SHL 16 + attribute
        ;// then we define OSC_COMMAND as WM_APP SHL 16
        ;// from that we can allocate all other osc messages to below this range

            OSC_COMMAND EQU WM_APP SHL 16

            OSC_COMMAND_POPUP_DEACTIVATE    EQU (WM_ACTIVATE SHL 16) + 0    ;// 60000h

                ;// only sent when popup_hWnd is being deactivated
                ;// ecx has window gaining active status
                ;// OSC_BASE.data.dwFlags must contain BASE_WANT_POPUP_DEACTIVATE
                ;// message is NOT sent of popup_hWnd is disabled

            OSC_COMMAND_POPUP_ACTIVATE      EQU (WM_ACTIVATE SHL 16) + 1    ;// windows = 60001

                ;// only sent when popup_hWnd is being deactivated
                ;// ecx has window gaining active status
                ;// OSC_BASE.data.dwFlags must contain BASE_WANT_POPUP_DEACTIVATE

            OSC_COMMAND_POPUP_WINDOWPOSCHANGING EQU (WM_WINDOWPOSCHANGING SHL 16) ;// windows = 460000

                ;// only sent when popup_hWnd recieves the WM_WINDOWPOSCHANGING message
                ;// sends directly to osc_Command, return value is NOT processed
                ;// ecx = ptr WINDOWPOS, handler may change it, will be sent to DefWindowProc
                ;// OSC_BASE.data.dwFlags must contain BASE_WANT_POPUP_WINDOWPOSCHANGING
                ;// ... subject to change

            OSC_COMMAND_EDIT_CHANGE     EQU (WM_COMMAND SHL 16)+EN_CHANGE   ;// 0111 0300

                ;// edit box control id is sent in ecx

            OSC_COMMAND_EDIT_SETFOCUS   EQU (WM_COMMAND SHL 16)+EN_SETFOCUS     ;// 0111 0100h
            OSC_COMMAND_EDIT_KILLFOCUS  EQU (WM_COMMAND SHL 16)+EN_KILLFOCUS    ;// 0111 0200h

                ;// edit box control id is sent in ecx
                ;// OSC_BASE.data.dwFlags must contain BASE_WANT_EDIT_FOCUS_MSG

            OSC_COMMAND_LIST_SELCHANGE  EQU (WM_COMMAND SHL 16)+LBN_SELCHANGE   ;// 0111 0001

                ;// the currently selected item's private dword is passed in ecx
                ;// resource style must have LBS_NOTIFY set

            OSC_COMMAND_LIST_DBLCLICK   equ (WM_COMMAND SHL 16)+LBN_DBLCLK      ;// 0111 0002

                ;// the currently selected item's private dword is passed in ecx
                ;// resource style must have LBS_NOTIFY set

            OSC_COMMAND_COMBO_SELCHANGE EQU (WM_COMMAND SHL 16)+CBN_SELCHANGE   ;// 0111 0001

                ;// the newly selected item's private dword is passed in ecx
                ;// note that the item has not technically been selected yet

            OSC_COMMAND_COMBO_SELENDOK  EQU (WM_COMMAND SHL 16)+CBN_SELENDOK    ;// 0111 0009

                ;// the currently selected item's private dword is passed in ecx

            OSC_COMMAND_COMBO_EDITUPDATE    EQU (WM_COMMAND SHL 16)+CBN_EDITUPDATE ;// 0111 0006

                ;// edit box control id is sent in ecx
                ;// OSC_BASE.data.dwFlags must contain BASE_WANT_EDIT_FOCUS_MSG

            OSC_COMMAND_CHANGE          EQU 0FFFh   ;// only used by plugins with menus

        ;// OSC_COMMAND_HARDWARE        equ 1000h   ;// user changed a device
        ;// OSC_COMMAND_HARDWARE_LAST   equ 10FFh   ;// (reserve the next 100h for indexes)

            OSC_COMMAND_SCROLL          equ 1100h   ;// scroll bar message
            OSC_COMMAND_SCROLL_LAST     equ 11FFh   ;// ( reserved the next 100h for indexes )

                ;// ecx will contain the new current scroll position
                ;// popups that use scrolls should set the ID as OSC_COMMAND_SCROLL + some number


            comment ~ /*
            ;///////////////////////////////////////////////////////////////////////////
            ;//
            ;//
            ;//     _Command
            ;//
            ASSUME_AND_ALIGN
            _Command PROC

                ASSUME esi:PTR OSC_OBJECT   ;// must preserve
                ASSUME edi:PTR OSC_BASE     ;// may destroy
                DEBUG_IF <edi!!=[esi].pBase>
                ;// eax has the command
                ;// exit by returning popup_flags in eax
                ;// or by jumping to osc_Command

                PARSE eax
                    DO WORK
                    mov eax, ;// must set eax as a popup flag
                    ret
                else
                    exit to osc_Command

            _Command ENDP
            ;//
            ;//     _Command
            ;//
            ;//
            ;///////////////////////////////////////////////////////////////////////////
            */ comment ~





        OSC_InitMenu    TYPEDEF PROTO
        ptr_InitMenu    TYPEDEF PTR OSC_InitMenu
        ;// return eax=0 for default size
        ;// else return new size in (eax,edx)

            comment ~ /*
            ;///////////////////////////////////////////////////////////////////////////
            ;//
            ;//
            ;//     _InitMenu
            ;//
            ASSUME_AND_ALIGN
            _InitMenu PROC

                ASSUME esi:PTR OSC_OBJECT   ;// preserve
                ASSUME edi:PTR OSC_BASE     ;// preserve
                DEBUG_IF <edi!!=[esi].pBase>

                xor eax, eax    ;// or set eax, edx as the new client size
                ret

            _InitMenu ENDP
            ;//
            ;//     _InitMenu
            ;//
            ;//
            ;///////////////////////////////////////////////////////////////////////////
            */ comment ~

        OSC_Write   TYPEDEF PROTO
        ptr_Write   TYPEDEF PTR OSC_Write

            comment ~ /*
            ;///////////////////////////////////////////////////////////////////////////
            ;//
            ;//
            ;//     _Write
            ;//
            ASSUME_AND_ALIGN
            _Write PROC

                ASSUME esi:PTR OSC_OBJECT   ;// preserve
                ASSUME edi:PTR FILE_OSC     ;// iterate as required

                ;// tasks:  write FILE_OSC.extra
                ;//         do not save OSC_OBJECT.dwUser
                ;//         save osc specific data
                ;//         iterate edi to end up at the FILE_PIN table


                ret

            _Write ENDP
            ;//
            ;//     _Write
            ;//
            ;//
            ;///////////////////////////////////////////////////////////////////////////
            */ comment ~




        OSC_AddExtraSize    TYPEDEF PROTO
        ptr_AddExtraSize    TYPEDEF PTR OSC_AddExtraSize

            comment ~ /*
            ;///////////////////////////////////////////////////////////////////////////
            ;//
            ;//
            ;//     _AddExtraSize
            ;//
            ASSUME_AND_ALIGN
            _AddExtraSize PROC

                ASSUME esi:PTR OSC_OBJECT   ;// preserve
                ASSUME edi:PTR OSC_BASE     ;// preserve
                ASSUME ebx:PTR DWORD        ;// preserve
                DEBUG_IF <edi!!=[esi].pBase>

                ;// task: determine how many extra bytes this object needs
                ;//       ADD it to [ebx]

                ;// do NOT include anything but the extra count
                ;// meaning do not include the size of the common OSC_FILE header
                ;// DO include the size of dwUser

                ret

            _AddExtraSize ENDP
            ;//
            ;//     _AddExtraSize
            ;//
            ;//
            ;///////////////////////////////////////////////////////////////////////////
            */ comment ~



        OSC_GetUnit TYPEDEF PROTO
        ptr_GetUnit TYPEDEF PTR OSC_GetUnit


            ;////////////////////////////////////////////////////////////////////
            ;//
            ;//
            ;//     _GetUnit
            ;//
            comment ~ /*
            ASSUME_AND_ALIGN
            _GetUnit PROC

                ASSUME esi:PTR OSC_OBJECT   ;// must preserve
                ASSUME ebx:PTR APIN         ;// must preserve

                ;// must preserve edi and ebp

            ;// 1) return don't know

                clc

            ;// 2) or return the unit

                mov eax, unit
                stc

            ;// return

                ret

            _GetUnit ENDP
            */ comment ~
            ;//
            ;//     _GetUnit
            ;//
            ;//
            ;////////////////////////////////////////////////////////////////////



            ;////////////////////////////////////////////////////////////////////
            ;//
            ;//
            ;//     _SaveUndo
            ;//
            comment ~ /*

            ASSUME_AND_ALIGN
            _SaveUndo   PROC

                ASSUME esi:PTR OSC_OBJECT

                ;// edx enters as either UNREDO_CONTROL_OSC or UNREDO_COMMAND
                ;// edi enters as where to store
                ;//
                ;// task:   1) save nessary data
                ;//         2) iterate edi
                ;//
                ;// may use all registers except ebp

                .IF edx == UNREDO_CONTROL_OSC

                    ;// save the control points


                .ELSE

                    ;// save object settings

                .ENDIF



                ret

            _SaveUndo ENDP
            */ comment ~
            ;//
            ;//
            ;//     _SaveUndo
            ;//
            ;////////////////////////////////////////////////////////////////////

            ;////////////////////////////////////////////////////////////////////
            ;//
            ;//
            ;//     _LoadUndo
            ;//
            comment ~ /*

            ASSUME_AND_ALIGN
            _LoadUndo PROC

                ASSUME esi:PTR OSC_OBJECT   ;// preserve
                ASSUME ebp:PTR LIST_CONTEXT ;// preserve

                ;// edx enters as either UNREDO_CONTROL_OSC or UNREDO_COMMAND
                ;// edi enters as where to load
                ;//
                ;// task:   1) load nessary data
                ;//         2) do what it takes to initialize it
                ;//
                ;// may use all registers except ebp and esi
                ;// return will invalidate HINTI_OSC_UPDATE

                .IF edx == UNREDO_CONTROL_OSC

                    ;// load control points

                .ELSE

                    ;// load object settings

                .ENDIF

                ;// initialize for the new data

                ret

            _LoadUndo ENDP

            */ comment ~
            ;//
            ;//
            ;//     _LoadUndo
            ;//
            ;////////////////////////////////////////////////////////////////////





    ;////////////////////////////////////////////////////////////////////
    ;//
    ;//
    ;//     OSC_GUI defines a a set of functions for interacting with user
    ;//

    OSC_GUI STRUCT

        ;// GDI
        Render      ptr_Render      gdi_render_osc  ;// special paint handler for objects with controls
        SetShape    ptr_SetShape    osc_SetShape    ;// makes sure that pSiz and pPos are set, overide to add new shapes and stuff

        ;// MOUSE
        HitTest     ptr_HitTest     0           ;// only needed for osc's with controls
        Control     ptr_Control     0           ;// mouse control for object's with controls

        ;// MOVE
        Move        ptr_Move        osc_Move    ;// objects with controls need to update there positions

        ;// MENUS
        Command     ptr_Command     osc_Command ;// command handler, optional, see command list below
        InitMenu    ptr_InitMenu    0           ;// context menu initializer, also optional

        ;// PERSISTANCE
        Write           ptr_Write           0   ;// defualt save funtion
        AddExtraSize    ptr_AddExtraSize    0   ;// default GetExtraSize function, needed for arbitary save lengths like the label

        ;// MISTAKES
        SaveUndo    dd 0 ;// save current state (either controls or settings)
        LoadUndo    dd 0 ;// load a new current state (either controls or settings)

        ;// AUTO UNITS
        GetUnit     ptr_GetUnit 0   ;// ptr to get unit function

    OSC_GUI ENDS

    ;// template: {Render,SetShape,HitTest,Control,Move,Command,InitMenu,Write,AddExtraSize,SaveUndo,LoadUndo,GetUnit}


    ;// HARD tells how objects use hardware

    OSC_HARD STRUCT     ;// these are pointers to member functions
                        ;// these are accessed by the hardware_ functions

        H_Ctor  dd 0    ;// pointer to the hardware costructor
        H_Dtor  dd 0    ;// pointer to the hardware destructor
        H_Open  dd 0    ;// pointer to the hardware open
        H_Close dd 0    ;// pointer to the hardware close
        H_Ready dd 0    ;// pointer to a buffer checking routine
        H_Calc  dd 0    ;// shared devices need an H_Calc (like midi out)
                        ;// this function gets called after all the objects are calced
    OSC_HARD ENDS





    ;// data layout tells the ctor how to allocate this object

    OSC_DATA_LAYOUT STRUCT

        slist_Declare_link baseB, OSC_BASE, data    ;// slist to next base, determined by the objectlist.inc
        ID              dd 0    ;// id of object, ex:IDB_object
        pPopupHeader    dd 0    ;// pointer to the POPUP_HEADER for this object, see popup below
        dwFlags         dd 0    ;// flags about this object, see below
        numPins         dd 0    ;// the default number of pins
        numFileBytes    dd 0    ;// standard number of extra file bytes required to store the object
        ofsPinData      dd 0    ;// offset from start of OSC_OBJECT to the pin data
        ofsOscData      dd 0    ;// offset from start of OSC_OBJECT to the osc data
        oscBytes        dd 0    ;// total amount of memory that needs allocated

    OSC_DATA_LAYOUT ENDS

    ;// values for data.dwFlags

        ;// play behavior               ------XX

        BASE_PLAYABLE               EQU 00000001h   ;// tells the CTor and DTor to register with play
        BASE_NO_WAIT                EQU 00000002h   ;// tells the play system, that this is an untimed (file object, scope)
                                                    ;// if set, play may skip waiting if no other objects override

        BASE_HARDWARE               EQU 00000004h   ;// these state that the base connects to a hardware device
                                                    ;// causes play proc to query _H_Ready function
        BASE_NO_GROUP               EQU 00000008h   ;// some hardware objects are allowed inside of groups
                                                    ;// this device is not to be allowed in groups
                                                    ;// usually this will be a hardware device

        ;// gdi display behavior        ----XX--

        BASE_BUILDS_OWN_CONTAINER   EQU 00000100h   ;// tells gdi that this object is managing it's own container
        BASE_SHAPE_EFFECTS_GEOMETRY EQU 00000200h   ;// tells gdi to invalidate pins when shape changes
                                                    ;// also maeans that we have to erase the object when the shape changes

        BASE_HAS_AUTO_UNITS         EQU 00000400h   ;// this object needs to determine it's units from GUI_CONTEXT UNIT TRACE
                                    ;// this flag means that UNIT_AUTO_TRACE is available in osc.dwUser
                                    ;// when UNIT_AUTO_TRACE is set, the osc must update it's display
                                    ;// to reflect that a pin's unit has changed

        ;// ctor behaviour              ---X----

        BASE_ALLOCATES_MANUALLY     EQU 00010000h   ;// ctor assume this object will do the entire allocate operation by itself
                                                    ;// usually this means that the object will create it's own base class from the ctor
                                                    ;// used in closed groups when they are being ctored

        ;// popup command behavior      XXX-----

        BASE_FORCE_DISPLAY_STATUS   EQU 00100000h   ;// osc_HID started this
                                                    ;// if an osc_InitMenu function returns non zero
                                                    ;// then we want to resize the popup_hWnd
                                                    ;// default behavior was to axe the status window
                                                    ;// axing was needed by vst popups
                                                    ;// HID on the other hand wants the status window
        BASE_NO_KEYBOARD            EQU 00200000h   ;// tells keyboard handler not to pass keystrokes to the object
        BASE_WANT_EDIT_FOCUS_MSG    EQU 00400000h   ;// if this is on, then we want to pass OSC_COMMAND_EN_SETFOCUS and OSC_COMMAND_EN_KILLFOCUS messages to
                                                    ;// edit controls in popup dialogs
        BASE_XLATE_DELETE           EQU 00800000h   ;// tells popup to xlate the delete key to ID_XLATE_DELETE
        BASE_WANT_POPUP_DEACTIVATE  EQU 01000000h   ;// some objects need to know when their popups close
                                                    ;// if they do, they can return popup_ignore to prevent closing of the window
                                                    ;// sends OSC_COMMAND_POPUP_DEACTIVATE and hWnd of new active in ecx
        BASE_WANT_POPUP_ACTIVATE    EQU 02000000h   ;// some objects need to know when their popups are activated
                                                    ;// if they do, then they should handle this message
                                                    ;// sends OSC_COMMAND_POPUP_ACTIVATE and hWnd of old active in ecx
        BASE_WANT_POPUP_WINDOWPOSCHANGING   EQU 04000000h ;// sends OSC_COMMAND_POPUP_WINDOWPOSCHANGING directly to
                                                    ;// osc_Command, does NOT process return value
                                                    ;// ... subject to change ....
        BASE_XLATE_CTLCOLORLISTBOX  EQU 08000000h   ;// tells popup proc to convert WM_CTLCOLORLISTBOX messages to WM_COMMAND.CBN_SELCHANGE
                                                    ;// this can be used to update popup_Status text
        BASE_NEED_THREE_LINES       EQU 10000000h   ;// the popup help status should three lines high, not two

        BASE_WANT_LIST_SELCHANGE    EQU 20000000h   ;// usually not handled, but if a popup has list boxs it may want to know this




;// display layout defines how to build the graphics the for the object
;// all base classes must have:
;//
;//     a container
;//     blit source
;//     create menu icon
;//

    OSC_DISPLAY_LAYOUT   STRUCT ;// these are objects graphics properties

    ;// container and blit source

        pContainer dd 0     ;// osc's with only one container must specify it here
                            ;// osc's with mutiple containers must specify it themseleves

                            ;// default object_bitmap source for the graphic
        pSource dd  0       ;// objects with more than one bmp, must keep track of it themselves
                            ;// using the SetShape member function

        ;// icons for create menu, use ICON_LAYOUT macro to set
        ;// !! do not set these when defining an object class
        ;// !!  USE ICON_LAYOUT
        ;//
        ;// ICON_LAYOUT expects integers in 12x24 format, see below

        create_pos_bmp      POINT   {}  ;// xy location on oBmp
        create_pos_small    POINT   {}  ;// position on create menu when in small mode
        create_pos_large    POINT   {}  ;// position on create menu when in large mode
        create_siz          POINT   {}  ;// size of the button window

        pszDescription  dd  0   ;// pointer to descriptive text when in large mode and for popup panels
        pszShortName    dd  0   ;// short name to use when in large mode

        create_text_rect    RECT    {}  ;// rectangle for displaying short name in large mode

        button_hWnd  dd  0      ;// this object's button on the create menu
                                ;// saves a call to windows to retrieve it
                                ;// built when create menu is built
    OSC_DISPLAY_LAYOUT ENDS


;// OSC_BASE    ;// lastly, we put all the above together
                ;// usually this will be a static structure, but some objects
                ;// recreate their own

    OSC_BASE STRUCT

        core    OSC_CORE            {}  ;// member functions for core
        gui     OSC_GUI             {}  ;// member functions for gui
        hard    OSC_HARD            {}  ;// member functions for hardware
        data    OSC_DATA_LAYOUT     {}  ;// class data
        display OSC_DISPLAY_LAYOUT  {}  ;// display data and menu icons

    OSC_BASE ENDS












;////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////
;///
;///    APIN_init       defines the pins on an object
;///
;///                    IT VERY IMPORTANT THAT THIS STRUCT REMAIN AT 16 BYTES

    APIN_init struct

        def_pheta   REAL4 0.0e+0;// parking position relative to center of owner container
                                ;// always in normalized angle form (-1 to +1 is clockwise)

        pName       dd  0       ;// pointer to full name string

        wName       dw  0       ;// chacracters for the name, used to build the shape
        wPad        dw  0       ;// not used

        dwStatus    dd  0       ;// starting dwStatus flags

    APIN_init ends

    IF (SIZEOF APIN_init) NE 16
    .ERR <APIN_init is supposed be 16 bytes>
    ENDIF


;///
;///    APIN_int
;///
;///                    IT VERY IMPORTANT THAT THIS STRUCT REMAIN AT 16 BYTES
;////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////









;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;///
;/// OSC OBJECT
;///
;///    SPECIAL NOTE: the size of OSC_OBJECT must be smaller or equal to the size of APIN
;///
;/// cache aligned version
;/// assume struct is 32 byte aligned (8 dwords)

    OSC_OBJECT STRUCT
;// 0
        pBase    dd 0   ;// pointer to base class
        dwUser   dd 0   ;// user values                 (STORED)
        pData    dd 0   ;// pointer to extra osc data
        slist_Declare_link oscC, OSC_OBJECT ;// pNextC   dd 0   ;// next item in the calc sequence      (context reliant)
;// 1
        dlist_Declare_link oscZ, OSC_OBJECT ;// pNextZ   dd 0   ;// dList Z for mouseing                (context reliant)
        ;//pPrevZ    dd 0   ;// dList Z for drawing                 (context reliant)
        pDevice  dd 0   ;// ptr to HARDWARE_DEVICEBLOCK if used
        pLastPin dd 0   ;// points at one past end, is also first pin data if needed
;// 2
        slist_Declare_link oscR, OSC_OBJECT ;// pNextR   dd 0   ;// sList Registered playable objects   (context reliant)
        clist_Declare_link oscS, OSC_OBJECT ;// pNextS   dd 0   ;// cList Selected objects              (context reliant)
        clist_Declare_link oscL, OSC_OBJECT ;// pNextL   dd 0   ;// clist Locked object                 (context reliant)
        slist_Declare_link oscG, OSC_OBJECT ;// pNextG   dd 0   ;// sList of Grouped object
;// 3
        dwHintI  dd 0   ;// reason this object is in the I list, see ABox_gdi.asm for values
        dwHintOsc dd 0  ;// flags for object gdi state, tells render what to do
        dlist_Declare_link oscI, OSC_OBJECT ;// pNextI   dd 0   ;// dList for invalidating objects      (context reliant)
;// 4
        pContainer dd 0 ;// pointer to this object's container
        pSource  dd 0   ;// cached location of this object's blit source
        pDest    dd 0   ;// cached screen destination for this object
        id       dd 0   ;// id for undo/redo
;// 5   ;// this block is used solely by the play thread
        depth    dd 0   ;// depth for the trace function
        dwClocks dd 0   ;// struct used for clock cyle display -- see notes in gdi_Clocks.asm
        clist_Declare_link oscIC, OSC_OBJECT    ;// pNextIC  dd 0   ;// slist for realtime displays         (context reliant)
        dwHintIC dd 0   ;// reason this object is in the IC list
;// 6
        rect    RECT {} ;// contains both the object's location and it's boundry (TL is STORED)
;// 7
        boundry RECT {} ;// same as rect, but includes outlines and pins
;// 8
    OSC_OBJECT ENDS ;// DO NOT ADD more UNTIL DOUBLING THE SIZE OF APIN !!!

    ;// there will be a number of APIN's following the OSC_OBJECT


;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;///
;/// APIN       SPECIAL NOTE:
;///            the size of APIN must be greater or equal to the size of OSC_OBJECT
;///            the ";// X" numbers are 16 byte cache lines
;///

    APIN STRUCT

        ;// pointers and status
;// 0
        pPin     dd 0   ;// the APIN object we're connected to or from
        pData    dd 0   ;// this object's sample data, or the next pin in the chain
        dwStatus dd 0   ;// op system flags for each pin, see PIN_ below
        dwUser   dd 0   ;// many objects store 'last values' from the calc function here.
;// 1
        dwHintI  dd 0   ;// hints for invalidating              (set by gdi_Invalidate_pin)
        dwHintIC dd 0   ;// hint for play_update
        dwHintPin dd 0  ;// render commands for this pin
        pDest    dd 0   ;// destination address of T0   (defined by pin_Layout_points)(gdi ptr)
;// 2
        pTShape  dd 0   ;// TRIANGLE SHAPE to draw at T0     (set by pin_Layout)(triangle_locate)
        pFShape  dd 0   ;// FONT_SHAPE shape of this pin's name     (set by osc_ctor)
        pBShape  dd 0   ;// BUS_SHAPE cached bus shape              (set by bus_GetShape)
        pLShape  dd 0   ;// LOGIC_SHAPE cached logic shape          (set by pin_SetTrigger)
;// 3
        t0  POINT {}    ;// ref point of the pin                        (gdi coord)
        t1  POINT {}    ;// cached location of the bezier start         (gdi_coord)
;// 4
        t2  POINT {}    ;// cached location of bezier control arm       (gdi_coord)
        E   fPOINT {}   ;// internal point, this is what get's pulled on    (real4) (gdi coord)
;// 5
        j_index  dd 0   ;// index for the connection type       (set by pin_SetJumpIndex)
        pad_5_1 dd  0
        pad_5_2 dd  0
        pad_5_3 dd  0
;// 6
        pheta REAL4 0.0 ;// our current angle, (normalized)

        pad_6_1 dd  0

        pObject  dd 0   ;// the oscillator that owns this pin   (set by osc_Ctor)
        pad_6_3 dd  0
;// 7
        color    dd 0   ;// packed color for drawing the pin (set by gdi_invalidate)
        pLName   dd 0   ;// pointer to a string representing the long name
        def_pheta REAL4 0.0 ;// default pheta for the pin (copied from APIN_init)
        slist_Declare_link pinBez,APIN  ;// slist for drawing erased beziers (used in gdi_render.asm)
;// 8
    APIN ENDS   ;// size = 8 groups of 4 dwords = 32 dwords = 128 bytes = shl 7

    APIN_SHIFT equ LOG2(SIZEOF (APIN))  ;// now we don't have to multiply !!!
                                        ;// this will also cause an error if sizeof if not
                                        ;// a power of two

    ;// pin data then immediately follows these
    ;// the data is always 4096 bytes for each pin
    ;// pin.pData will point at this area

    ;// after all the data, we get the object class data
    ;// which varies in size, if it even exists
    ;// this data must be readily loadable so we can use default functions
    ;// if base.fileBytes > 4, the extra (after dwUser) starts here
    ;// object.pData will point at this



;///////////////////////////////////////////////////////////////////////////////////
;//
;//
;//   APIN.dwStatus BITS    masks for APIN.dwStatus, also used by APIN_init
;//

    ;// BUSSES and PIN TYPES

                                            ;// bus index is stored in lower 8 bits
        PIN_BUS_TEST        equ  000000FFh  ;// 0 for not a bus
                                            ;// do not use these bits, they are the bus number
        PIN_BUS_MASK        equ 0FFFFFF00h  ;// bus number is 1-255
        PIN_BUS_SOURCE      equ  00000100h  ;// this is a bus source (same as output pin)

        BUS_SOURCE_TEST EQU PIN_BUS_TEST OR PIN_BUS_SOURCE

        PIN_OUTPUT          equ  00000100h  ;// is a source for data (so it gets a data block)
        PIN_HIDDEN          equ  00000200h  ;// do not display (very important that this equal 200)
        PIN_NULL            equ  00000400h  ;// do not allocate data (needed for outputs that xfer pointers)

    ;// UNITS
    ;// these are defined in auto_units.inc and shown here to state that these bits are not available

        PIN_DO_NOT_USE      equ  000FF800h  ;// see UNIT_AUTO_UNIT

    ;// LOGIC PINS

        ;// these are defined to offset a table of pointers to GDI_SHAPE STRUCTS
        ;// see pin_logic_shape_table

        ;// object's that use logic pins should follow the same bit pattern to prevent
        ;// undo hardship

        PIN_LEVEL_POS       equ  00100000h  ;// responds to positive level or edge \ both off is
        PIN_LEVEL_NEG       equ  00200000h  ;// responds to negative level or edge / both levels
        PIN_LOGIC_GATE      equ  00400000h  ;// is a gate input (off is trigger)
        PIN_LOGIC_INPUT     equ  00800000h  ;// is a logic detecting input

            ;// derived values
            PIN_LEVEL_TEST  equ PIN_LOGIC_GATE OR PIN_LEVEL_POS OR PIN_LEVEL_NEG
            PIN_LOGIC_TEST  equ PIN_LOGIC_INPUT OR PIN_LEVEL_TEST

    ;// these are the crucial pin changing values

        PIN_WAS_CHANGING    equ  20000000h  ;// can be used by calc functions
        PIN_CHANGING        equ  40000000h  ;// states that the pin has changing data
        PIN_PREV_CHANGING   equ  80000000h  ;// pin was previously changing/not changing
                                            ;// used only by play when show_changing is on



;//
;//   APIN.dwStatus BITS    masks for APIN.dwStatus, also used by APIN_init
;//
;//
;///////////////////////////////////////////////////////////////////////////////////



;////////////////////////////////////////////////////////////////////
;//
;//                         see gdi_pin_SetJIndex
;//     j_index equates
;//

    PIN_J_INDEX_hidden  EQU 0   ;// ---uses---
    PIN_J_INDEX_TFB     EQU 1   ;// bussed analog input
    PIN_J_INDEX_TFS     EQU 2   ;// connected analog input
    PIN_J_INDEX_TF      EQU 3   ;// unconnected analog (in or out)
    PIN_J_INDEX_LFB     EQU 4   ;// bussed logic input
    PIN_J_INDEX_LFS     EQU 5   ;// connected logic input
    PIN_J_INDEX_LF      EQU 6   ;// unconnected logic input
    PIN_J_INDEX_FB      EQU 7   ;// bussed output
    PIN_J_INDEX_FS      EQU 8   ;// connected output
    PIN_J_INDEX_FT      EQU 9   ;// unconnected output

    EXTERNDEF pin_j_index_connected:BYTE        ;// table of yes no values
                                            ;// defined in gdi_Invalidate
;//
;//                         see gdi_pin_SetJIndex
;//     j_index equates
;//
;////////////////////////////////////////////////////////////////////












;//////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////
;///
;///        P I N   C O N E C T I O N   F U N C T I O N S
;///
;///        see pin_connect.asm for details

;// NOTE: now that we are using contexts
;//     ALL PIN OPERATIONS MUST HAVE EBP AS THE IMPLIED CONTEXT


        pin_connect_query PROTO
        ;// validates and returns a jump pointer to connect with
        ;// returns the pin color, good or bad
        ;// pDown is always from, pTo is always pin_hover


    ;// pin connect functions are hidden from view
    ;// except as noted. Many are simply not implemented

    ;// all are register calls, see implementation for details


    ;// pin_connect_UO_UO PROTO
        pin_connect_UO_UI PROTO
    ;// pin_connect_UO_CO PROTO
    ;// pin_connect_UO_CI PROTO

        pin_connect_UI_UO PROTO
    ;// pin_connect_UI_UI PROTO
        pin_connect_UI_CI PROTO
        pin_connect_UI_CO PROTO ;// used by grid_action_connect

        pin_connect_CO_UO PROTO
    ;// pin_connect_CO_UI PROTO
        pin_connect_CO_CO PROTO
    ;// pin_connect_CO_CI PROTO

    ;// pin_connect_CI_UO PROTO
        pin_connect_CI_UI PROTO
    ;// pin_connect_CI_CO PROTO
    ;// pin_connect_CI_CI PROTO

        pin_connect_CI_UOCO_special PROTO


;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;///
;/// BUSSES     busses are indexed into the lower 8 bits of APIN.dwStatus
;///

        NUM_BUSSES  equ 240

    ;// utility, use these when needed
    ;// most are register calls, see implementation for details

        bus_Show            PROTO   STDCALL

        bus_GetNameFromPin  PROTO
        bus_GetShape        PROTO

        bus_LoadFile        PROTO
        bus_SaveFile        PROTO
        bus_AddExtraSize    PROTO

        bus_Clear           PROTO

        bus_GetEditRecord   PROTO

        bus_Create  PROTO
        bus_Rename  PROTO
        bus_Transfer PROTO
        bus_ConvertTo PROTO
        bus_Direct          PROTO
        bus_Pull            PROTO

    ;// user dialog

        BUS_STYLE       equ WS_POPUP + WS_CAPTION + WS_SYSMENU
        BUS_STYLE_EX    equ WS_EX_DLGMODALFRAME + WS_EX_TOPMOST + WS_EX_WINDOWEDGE + WS_EX_TOOLWINDOW

        bus_Proc PROTO





;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;//
;// see midi2.inc MIDIIN_TRACKER for details
;// we define here so we can use slist macros

        MIDIIN_TRACKER STRUCT   ;// stored in MIDIIN_DATA

            number  dd  0   ;// last note number (integer shifted left 8)
            event   dd  0   ;// state of the e pin (1 for on, 0 for off)
            stamp   dd  0   ;// used for LRU mode

            slist_Declare_link tracker_dest, MIDIIN_OSC_MAP, midiin, tracker    ;// slist of attached objects

            pTracker    dd  0   ;// PTR MIDIIN_TRACKER_CONTEXT

        MIDIIN_TRACKER ENDS

        MIDIIN_TRACKER_CONTEXT STRUCT   ;// attached to LIST_CONTEXT

            ID              dd  0   ;// numerical ID of this tracker
            slist_Declare_indirected tracker_dest   ;// list of attached objects
            tracker_stamp   dd  0   ;// LRU mode every event xfered from tracker to object updates the stamp
            tracker_flags   dd  0   ;// flags xfered from source object
            pSourceObject   dd  0   ;// single object that supllies the source data
            slist_Declare_link tracker, MIDIIN_TRACKER_CONTEXT
            numDevices      dd  0   ;// number of midiins using this
            szName          db  4+16 DUP (0)

        MIDIIN_TRACKER_CONTEXT ENDS

        .ERRNZ (OFFSET MIDIIN_TRACKER_CONTEXT.ID), <ID MUST BE FIRST FIELD!!>


;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;///
;///    LISTS
;///


comment ~ /*

    to allow grouped objects, we use the concept of a LIST_CONTEXT

    this is simply a struct with the list heads, tails, MRS etc

    it is called a LIST_CONTEXT
    there is a master context that anchors the entire circiut
    the two threads (gui and play) are each assigned a current context pointer
    both may navigate the context independantly of each other
    then there may be several stacks used by various functions
    contexts are usually pointed to by ebp

    GUI functions will then always use the top of the stack
    PLAY functions may push a seperate stack to allow group calcs

*/ comment ~

    LIST_CONTEXT STRUCT
    ;// 0
        dlist_Declare_indirected oscZ   ;// z order list
        dlist_Declare_indirected oscI   ;// invalidating and drawing oscs
    ;// 1
        slist_Declare_indirected oscC   ;// calc sequence list
        slist_Declare_indirected oscR   ;// playable objects
        clist_Declare_indirected oscS   ;// select mode list
        clist_Declare_indirected oscIC  ;// for displaying realtime grphics
    ;// 2                               ;// from the calc thread (used in play.asm)
        pFlags          dd  0   ;// PFLAG_ play flags for this context
        pNextPlay       dd  0   ;// next item in the play_context stack (above us)
        pGroup          dd  0   ;// pointer to the closed group that manages this context
                                ;// use for backtracking closed groups
        slist_Declare_indirected tracker    ;// ptr to MIDIIN_TRACKER_CONTEXT
    ;// 3
        gFlags      dd  0       ;// GFLAG_ gui flags for this context
        pNextGui    dd  0       ;// next item in the gui_context (above us)
        clist_Declare_indirected oscL   ;// lock MRS for this context
        pBusStrings dd  0       ;// pointer to where the compacted strings are
    ;// 4
        bus_table   dd  NUM_BUSSES dup (0)  ;// bus table for this context
                                            ;// these are ptrs to apin outputs (bus sources)
    LIST_CONTEXT ENDS   ;// total size 1024 bytes

    ;// context flags. There are two sets, one for gui, one for play
    ;// these tell app_Sync to do extra work

        GFLAG_DOING_NEW         EQU 00000001h
        ;// causes osc_Dtor to skip list removal, since it's about to be deleted anyways

    ;// GFLAG_AUTO_UNITS        EQU 00000002h
    ;// moved to app_bFlags and APP_SYNC_UNITS
        ;// tells app sync to tag osc's with BASE_HAS_AUTO_UNIT
        ;// set this to schedule an auto unit trace

        PFLAG_TRACE             EQU 00000001h
        ;// do a circuit trace

        PFLAG_FLUSH_CLOCKS      EQU 00000002h
        ;// flush the clocks for all objects
        ;// processed by play_Proc and play_Calc

        PFLAG_FLUSH_PINCHANGE   EQU 00000004h
        ;// flush the pin prev changing status
        ;// processed by play_Proc and play_Calc
        PFLAG_FLUSH_PINCHANGE_1 EQU 00000008h
        ;// after_loading, we nned to do this twice

    ;// declarations of the two context lists

        stack_Declare_external play_context, LIST_CONTEXT, pNextPlay    ;// play gets a context
        stack_Declare_external gui_context, LIST_CONTEXT, pNextGui      ;// gui gets a context

        EXTERNDEF master_context:LIST_CONTEXT       ;// top level list context synchronizes both

    ;// these lists exist outside of the contexts

        slist_Declare_external baseB    ;// , OSC_BASE, data.pNextB ;// how we iterate through a base list

        ;// slist_Declare_external oscG, OSC_OBJECT, pNextG     ;// grouped items
        ;// clist_Declare_external oscL, OSC_OBJECT, pNextL     ;// locks objects together

    ;//
    ;// objectlist.inc has all the EXTERNDEFs for each object
    ;//

    ;// except these, because they are not really objects

        EXTERNDEF osc_LockTable:OSC_BASE
        EXTERNDEF osc_BusTable:OSC_BASE
        EXTERNDEF osc_IdTable:OSC_BASE

    ;// useful macro

    BUS_TABLE MACRO index:req

        EXITM <[ebp].bus_table[index*4-4]>

        ENDM



;//////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////
;///
;///    now we get a collection of functions that use the above structures
;///    most are register calls. See implementation for details
;///
;/// osc_ member functions
;///

    osc_Ctor PROTO STDCALL pFileOsc:PTR FILE_OSC, pFileHeader:PTR FILE_HEADER, bNoPins:DWORD

    osc_Dtor PROTO      ;// STDCALL pObject:ptr OSC_OBJECT

    osc_Write PROTO     ;// STDCALL pObject:dword, pFile:PTR FILE_OSC

	;// osc_Render PROTO    ;// default osc_Render
	;// replaced by gdi_render_osc

    osc_SetShape    PROTO   ;// default set shape

    osc_Command     PROTO   ;// default command handler

    osc_Move        PROTO   ;// default osc_Move

    osc_SaveUndo    PROTO   ;// use for just saving dwUser

    osc_SetBadMode  PROTO STDCALL bBad:DWORD    ;// call to set and reset bad objects
    ;// this is only a display command

	;// clock cycle display -- called by osc_Render
	;// see gdi_Clock.asm

    clocks_Initialize PROTO ;// called once to build the fonts
    clocks_Render PROTO     ;// may be called by osc_Render

    ; defined in abox.inc
    CLOCKS_RECT_WIDTH   EQU 24  ;// width of the block (must be multiple of 4)
    CLOCKS_RECT_HEIGHT  EQU 8   ;// height of the block

	CLOCK_CYCLE_TEST	EQU	1FFFFFFFh	;// smmc cccc cccc cccc cccc cccc cccc cccc
	CLOCK_CYCLE_MASK	EQU 60000000h	;//    1    F    F    F    F    F    F    F
	CLOCK_CYCLE_MODE_00	EQU 00000000h	;// unit mode
	CLOCK_CYCLE_MODE_01	EQU 20000000h	;// 'k' kilo mode
	CLOCK_CYCLE_MODE_10	EQU 40000000h	;// 'M' mega mode
	CLOCK_CYCLE_MODE_11	EQU 60000000h	;// err mode -- way too many
	CLOCK_CYCLE_MODE_SHIFT EQU 29	;// right shift mm down to a value 0-3


;//
;// osc and pin combinations    defined in ABox_Pin.asm
;//


    pin_Layout_shape    PROTO   ;// determines how the pin should be displayed
    pin_Layout_points   PROTO   ;// second part of pin layout

    ;// min distances (use min^2-1 to get the integer test correct)

    pin_min_bezier      equ 256 ;// min dist^2 that we draw poly beziers
    pin_min_line        equ 9   ;// min dist^2 that we draw  a line

    pin_ComputePhetaFromXY  PROTO   ;// derives pheta from a reletive XY coordinate

    pin_SetInputShape   PROTO   ;// sets up a logic input with the correct shape, then invalidates it
    pin_Show            PROTO STDCALL bShow:DWORD
    pin_SetNameAndUnit  PROTO STDCALL pShortName:DWORD, pLongName:DWORD, unit:DWORD
    pin_SetName PROTO
    pin_SetUnit PROTO

    osc_Clone PROTO



;//
;// circuit functions       these effect the entire circuit
;//
;//

    circuit_New     PROTO
    circuit_Save    PROTO
    circuit_Load    PROTO
    circuit_SaveBmp PROTO


;//
;// context functions       these work with the currently displayed context
;//
;//

    ;// file to from circuit

    context_New         PROTO
    context_Load        PROTO
    context_PasteFile   PROTO
    context_Save        PROTO

    ;// copy buffer to/from circuit

    context_Copy    PROTO
    context_Cut     PROTO
    context_Paste   PROTO STDCALL pBuffer:DWORD, ids:DWORD, bSelect:DWORD
    context_Delete_prescan PROTO
    context_Delete  PROTO

    ;// storage helpers

    context_GetFileSize PROTO
    context_GetCopySize PROTO

    ;// gdi helper

    context_MoveAll PROTO

    ;// selection helper

    context_UnselectAll PROTO

    ;// auto unit helper

    context_SetAutoTrace PROTO


;//
;// locktables      defined in locktable.asm
;//

    locktable_Lock      PROTO
    locktable_Unlock    PROTO

    locktable_Load      PROTO

    locktable_GetSize_Z PROTO
    locktable_GetSize_S PROTO

    locktable_Save_Z    PROTO
    locktable_Save_S    PROTO

;//
;//
;// scroll bars
;//
;//

    EXTERNDEF HScroll:SCROLLINFO
    EXTERNDEF VScroll:SCROLLINFO
    EXTERNDEF scroll_state:DWORD    ;// used in nc hittest and nc paint

    HSCROLL_ON  EQU 00000001h
    VSCROLL_ON  EQU 00000002h

    context_UpdateExtents PROTO ;// manages the extents and scroll bars
                                ;// use app_bFlags to set


;//
;// pin functions
;//

    pin_Unconnect   PROTO

;//
;// file functions  found in abox_file.asm
;//

    file_Load PROTO ;// returns a buffer that will need to be destroyed

    ;// translation functions, defined in xlate.asm

    xlate_ABox1File PROTO   ;// register call
    xlate_ABox2File PROTO   ;// register call


    file_CheckConnections PROTO STDCALL pFile:PTR FILE_HEADER

    file_RealizeBuffer  PROTO STDCALL pFile:PTR FILE_HEADER, pIds:DWORD, bSelect:DWORD
    file_ConnectPins    PROTO STDCALL pFile:PTR FILE_HEADER


;//
;// app level functions
;//

    app_CreateOsc PROTO STDCALL pPosition:DWORD, dwId:DWORD



;//
;// aligning commands
;//

    EXTERNDEF align_hWnd:DWORD
    EXTERNDEF align_atom:DWORD

    align_Show PROTO
    align_Proc PROTO

    ALIGN_STYLE     equ WS_POPUP OR WS_CAPTION OR WS_SYSMENU
    ALIGN_STYLE_EX  equ WS_EX_DLGMODALFRAME OR WS_EX_TOPMOST OR WS_EX_WINDOWEDGE OR WS_EX_TOOLWINDOW


;////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////
;///
;///
;///        P L A Y   S Y S T E M
;///

    ;// SLEEP_TIME_WAIT equ 1   ;// sleep time for waiting

        SLEEP_TIME_PLAY equ 5   ;// sleep time for playing

        EXTERNDEF   play_status:DWORD
        EXTERNDEF   play_hEvent:DWORD

        WM_ABOX_XFER_IC_TO_I    EQU WM_APP      ;// handler defined in abox_play.asm
        play_wm_abox_xfer_ic_to_i_proc PROTO    ;// handler for message

    ;// these flags are set by play to inform the app of status

    ;// these flags are set by to the app to control the play thread

        PLAY_PLAYING    equ 00000002h   ;// set to make the thread play the circuit
        PLAY_PLAY_SYNC  equ 00000004h   ;// set if play has the crtical section
        PLAY_GUI_SYNC   equ 00000008h   ;// set if gui has sync
        PLAY_EXIT       equ 00000010h   ;// set to exit the play thread

        ;// note: leave high word free for debug lock count

    ;// these two macros are for temorarily pausing the play thread
    ;// this works because the play proc loop tries to enter the section every time

    ;// the debug version keeps track of the lock count so we can reset the flags when lock reaches zero

        EXTERNDEF crit_section:CRITICAL_SECTION     ;// defined in ABox.asm

        ENTER_PLAY_SYNC MACRO who:req

            IFDEF DEBUGBUILD

            ;// set the lock flag

                or play_status, PLAY_&who&_SYNC ;// set the flag first

            ;// increase the lock count

                IFIDN <who>,<GUI>
                    inc BYTE PTR play_status[2]
                ELSEIFIDN <who>,<PLAY>
                    inc BYTE PTR play_status[3]
                ELSE
                    .ERR <use GUI or PLAY>
                ENDIF

                DEBUG_IF <ZERO?>    ;// account for overrun > 256

            ENDIF

            ;// enter the crit section

            invoke EnterCriticalSection, OFFSET crit_section

            ENDM

        LEAVE_PLAY_SYNC MACRO who:req

            ;// leave the crit section

            invoke LeaveCriticalSection, OFFSET crit_section

            ;// reduce the lock count and reset the flag if zero

            IFDEF DEBUGBUILD

                IFIDN <who>,<GUI>
                    dec BYTE PTR play_status[2]
                ELSEIFIDN <who>,<PLAY>
                    dec BYTE PTR play_status[3]
                ELSE
                    .ERR <use GUI or PLAY>
                ENDIF
                DEBUG_IF <SIGN?>    ;// lost track of the count
                .IF ZERO?
                    and play_status, NOT PLAY_&who&_SYNC
                .ENDIF

            ENDIF

            ENDM


    ;// functions

        play_Initialize PROTO
        play_Destroy PROTO

        play_Start PROTO
        play_Stop PROTO

        play_Invalidate_osc PROTO

        INVAL_PLAY_CYCLES   equ 00000001h
        INVAL_PLAY_UPDATE   equ 00000002h
        INVAL_PLAY_PIN_UPDATE   equ 0004h
        INVAL_PLAY_MAKE_BAD equ 00000008h
        INVAL_PLAY_MAKE_GOOD equ 0000010h

        EXTERNDEF play_ClockMonitor:DWORD
        EXTERNDEF play_LastClock:DWORD
        EXTERNDEF play_fpu_control:DWORD
        EXTERNDEF play_sample_position:DWORD    ;// ABOX233

;////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////
;///
;///
;///        H A R D W A R E    S Y S T E M
;///

    ;// there is a list of these that is created upon calling InitializeHardware
    ;// it is destroyed by calling DestroyHardware
    ;// this sytem allows multiple devices and reallocation of devices on the fly

    ;// if an object is listed as a hardware device,
    ;// it's first osc_data value must be a pointer to this struct

    HARDWARE_DEVICEBLOCK STRUCT

        ID          dd 0    ;// for opening the device, set by the H_Ctor
        pBase       dd 0    ;// pointer to the osc_base class that manages this device
        slist_Declare_link hardwareL,HARDWARE_DEVICEBLOCK   ;// for iterating the list
        hDevice     dd 0    ;// handle to the device, null for a closed device

        numDevices  dd 0    ;// counts devices attached to this object, managed by hardware_AttachDevice and hardware_DetachDevice
        dwFlags     dd 0    ;// flags for this entry (see below)

        pData       dd 0    ;// ptr to data blocks, varies according to device type
        num_buffers dd 0    ;// wave devices store their number of buffers here
                            ;// other devices can use the preceeding two values for a dlist

        dwCount     dd  0   ;// countdown timer for the number of frames that elaspe before we try to open this device again

        szName  db 60+64 dup(0) ;// name of the device  ABOX233 added another 64 just in case

    HARDWARE_DEVICEBLOCK ENDS

    .ERRNZ (OFFSET HARDWARE_DEVICEBLOCK.ID), <ID MUST BE FIRST FIELD!!>

    ;// dwFlags incorporate the BASE_HARDWARE flags plus these

        HARDWARE_SHARED     equ  00000001h  ;// allow any number of devices to share
                                            ;// assumes that there is an H_Calc function to clean up
        HARDWARE_BAD_DEVICE equ  00000002h  ;// set true when a device can't be opened

        ;// do not use 00000004h, == BASE_HARDWARE

        HARDWARE_IS_DIRECTSOUND equ 00008h  ;// used by wave devices, driver is direct sound

        HARDWARE_HAS_CALCED     equ 00010h  ;// used by osc_HID to allow sharing and only 1 poll operation
        HARDWARE_SHARED_RESYNC  equ 00020h  ;// used by osc_HID all shared objects must rescyn their attachment

    ;// hardware specific functions

        ;// this initializes the hardware list

            hardware_Initialize PROTO
            hardware_Destroy PROTO

        ;// these are used to synchronize application menus

            hardware_CanCreate PROTO STDCALL pBase:PTR OSC_BASE, bWillReplace:DWORD

        ;// this assigns devices to objects

            hardware_AttachDevice PROTO
            hardware_DetachDevice PROTO

        ;// this checks if data is available and/or synchronized

            hardware_Ready PROTO

            ;// return flags

            READY_DO_NOT_CALC   equ 0001h   ;// set by buffer dependant devices when a buffer is not ready
            READY_BUFFERS       equ 0002h   ;// set by device when buffer is ready
            ;//READY_FILE           equ 0004h   ;// set by the file object
            ;//READY_DISPLAY        equ 0008h   ;// set by display devices
            READY_TIMER         equ 0010h   ;// set by midi out, and midi in
            READY_MARK_AS_BAD   equ 0020h   ;// extra flag, not used ?


        ;// these support object context menus and multiple devices

            hardware_FillInDeviceList PROTO
            hardware_ReplaceDevice PROTO STDCALL pTo:PTR HARDWARE_DEVICEBLOCK

    ;// this is the device list and some support data

        slist_Declare_external hardwareL    ;// , HARDWARE_DEVICEBLOCK, pNext


;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;///
;///
;///    F I L E N A M E S
;///

        FILENAME STRUCT
            pName       dd  0   ;// points at the name portion
            pExt        dd  0   ;// points at the extension
            dwLength    dd  0   ;// total length EXCLUDING nul
            szPath      db 280 dup (0)
        FILENAME ENDS

    ;// the filename system allocates memory

        filename_Initialize PROTO
        filename_Destroy    PROTO

    ;// filenames are pooled

        pool_Declare_external filename, FILENAME, 16, GENERATE_ALLOCATOR

    ;// use these to get and put FILENAME

        filename_GetUnused PROTO    ;// returns in ebx
        filename_PutUnused MACRO reg:REQ
            pool_PutUnused filename, reg
            ENDM

    ;// use these to initailize

        filename_InitFromString PROTO STDCALL bFlags:DWORD

            FILENAME_SPACE_TERMINATED   EQU 1   ;// unquoted spaces terminate the name
            FILENAME_FULL_PATH          EQU 2   ;// expand entry to a full path

        filename_CopyNewDirectory   PROTO STDCALL pName:DWORD, pDir:DWORD


    ;// the global pointers to FILENAMEs

        EXTERNDEF filename_app_path:DWORD       ;// app location
        EXTERNDEF filename_circuit_path:DWORD   ;// current circuit
        EXTERNDEF filename_paste_path:DWORD     ;// laste file paste
        EXTERNDEF filename_plugin_path:DWORD    ;// last plugin
        EXTERNDEF filename_data_path:DWORD      ;// last disk object
        EXTERNDEF filename_reader_path:DWORD    ;// last media reader
        EXTERNDEF filename_writer_path:DWORD    ;// last media writer
        EXTERNDEF filename_csvwriter_path:DWORD ;// last csv writer
        EXTERNDEF filename_csvreader_path:DWORD ;// last csv reader
        EXTERNDEF filename_bitmap_path:DWORD    ;// last bitmap

        EXTERNDEF filename_mru1_path:DWORD
        EXTERNDEF filename_mru2_path:DWORD
        EXTERNDEF filename_mru3_path:DWORD
        EXTERNDEF filename_mru4_path:DWORD
        EXTERNDEF filename_mru5_path:DWORD

        EXTERNDEF filename_get_path:DWORD       ;// xfer space for obtaining filenames

    ;// function proto types

        filename_GetFileName PROTO STDCALL dwMode:dword ;// , pPath:DWORD, ppName:DWORD
        ;// returns
        ;//     0 for cancel
        ;//     1 for file_get_name is valid
        ;//     mem_address for multiple selection

        ;// dwMode may have the following values

        GETFILENAME_OPEN        equ 0   ;// retreives a new file to load
        GETFILENAME_SAVEAS      equ 1   ;// retrieves the save name
        GETFILENAME_PASTE       equ 2   ;// retrieves a file to paste
        GETFILENAME_BITMAP      equ 3   ;// save as a bitmap

        GETFILENAME_PLUGIN      equ 4   ;// find a plugin

        GETFILENAME_DATA        equ 5   ;// retrieves a name for an osc_File object
        GETFILENAME_READER      equ 6   ;// media reader
        GETFILENAME_WRITER      equ 7   ;// media writer

        GETFILENAME_CSVREADER   equ 8   ;// CSV read
        GETFILENAME_CSVWRITER   equ 9   ;// CSV write



        filename_QueryAndSave PROTO ;// asks save and does so
        ;// returns zero for cancel

        filename_SyncAppTitle PROTO

        filename_PackMRU PROTO
        filename_SyncMRU PROTO




;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;//
;// CIRCUIT_SETTINGS
;//

    EXTERNDEF app_CircuitSettings:DWORD

    CIRCUIT_NOSAVE      equ  00000001h  ;// no ask save
    CIRCUIT_NOMOVE      equ  00000002h  ;// no move objects
    CIRCUIT_NOEDIT      equ  00000004h  ;// no adjusting objects
    CIRCUIT_AUTOPLAY    equ  00000008h  ;// play the circuit now
    CIRCUIT_NOPINS      equ  00000010h  ;// do not display pins or connections: added ABox231

    CIRCUIT_TEST        EQU  0000001Fh  ;// adjusted ABox231

    CIRCUIT_OPEN_GROUP  equ  00010000h  ;// set if the file has an open group


;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;//
;//                 manages both the create popup and the object menu
;// CREATE MENU     icons for both are stored in the menus.bmp
;//

    CREATE_STYLE     equ WS_POPUP + WS_DLGFRAME
    CREATE_STYLE_EX  equ WS_EX_DLGMODALFRAME + WS_EX_TOPMOST + WS_EX_WINDOWEDGE

    CREATE_STATUS_HEIGHT    equ 16  ;// extra height for the status line

    CREATE_WIDTH            equ 192 + 2
    CREATE_HEIGHT           equ 144 + CREATE_STATUS_HEIGHT + 4

    CREATE_WIDTH_LARGE      equ 446

    EXTERNDEF create_atom:DWORD
    EXTERNDEF create_szName:BYTE
    EXTERNDEF create_hWnd:DWORD


    create_Show PROTO STDCALL
    create_Proc PROTO   ;// STDCALL hWnd:dword, msg:dword, wParam:dword, lParam:dword

    ;// called when the pallettte changes
    create_SetMenuBitmaps PROTO STDCALL






;////////////////////////////////////////////////////////////////////
;//                                                    MACRO FUNCTION
;//
;//                                     x is in 12pix button coords
;//                                     y is in 24pix button coords
;//     ICON_LAYOUT( x,y,sx,ind )       sx is the width of the button (also in 12x)
;//                                     ind is the column index needed to build the large pos
;//                                     all buttons are 24 high
;//                                     button images are 20 pixels high (centered in 24x24 rect)
;//     this also defines pszShortName as OFFSET short_name
;//     and pszDescription as OFFSET descrition
;//
;// use this to initialize an OSC_BASE.OSC_DISPLAY struct
;// it sets up the data needed to connect the master abox bitmap
;// to the create panels
;//
;// ex: ICON_LAYOUT ( 5,4,3,2 )
;//
;// it's x position will 2 1/2 buttons over (5 / 2), starting at 0
;// it's y position on the create menu will be the 4th row, starting at 0
;// will define a button that is 36 pixels wide (3 * 12)
;//
;// it's location in the source bitmap will be calculated
;// it's client window rect in small and large will also be calculated
;// pointers to the description text will also be defined
;// text rect will be initialized as the largest it should get

    CREATE_ICON_WID_UNIT    equ 12
    CREATE_ICON_HIG_UNIT    equ 24

    CREATE_ICON_SOURCE_X    equ 312
    CREATE_ICON_SOURCE_Y    equ 0

    CREATE_ICON_MENU_LEFT   equ 0   ;// left column on create menu
    CREATE_ICON_MENU_TOP    equ 44  ;// top row on create menu


    ICON_LAYOUT MACRO X:req, Y:req, SX:req, IND:req

        local t
        local x1,y1,x2,y2,x3,y3,x4,y4,x5,y5,x6,y6

        x1 = CREATE_ICON_SOURCE_X + X * CREATE_ICON_WID_UNIT    ;// bitmap pos.x
        y1 = CREATE_ICON_SOURCE_Y + Y * CREATE_ICON_HIG_UNIT    ;// bitmap pos.y

        x2 = CREATE_ICON_MENU_LEFT + X * CREATE_ICON_WID_UNIT   ;// menu pos.x small
        y2 = CREATE_ICON_MENU_TOP + Y * CREATE_ICON_HIG_UNIT    ;// menu pos.y small

        x3 = x2 + IND * CREATE_ICON_WID_UNIT * 3    ;// menu pos.x large
        y3 = y2                                     ;// menu pos.y large

        x4 = SX * CREATE_ICON_WID_UNIT                          ;// menu width.x
        y4 = CREATE_ICON_HIG_UNIT                               ;// menu height.y

        x5 = x3 + x4 + 2                    ;// left of text rect
        y5 = y2                             ;// top of text rect
        x6 = x5 + CREATE_ICON_WID_UNIT * 3 - 4  ;// right of text rect
        y6 = y5 + y4                        ;// bottom of text rect

%       t TEXTEQU <{x1,y1},{x2,y2},{x3,y3},{x4,y4},OFFSET description, OFFSET short_name,{x5,y5,x6,y6}>
        EXITM t
        ENDM



;//
;//     ICON_LAYOUT( x,y,sx,ind )
;//
;//                                                    MACRO FUNCTION
;////////////////////////////////////////////////////////////////////














;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;//
;// POPUP MENU  this struct defines how we want the popup context to look
;//             it MUST be followed by an array of POPUP_ITEMs, then a zero
;//             a collection of these structs is built by build_popup.cpp
;//             and ends up in popup_data.asm
;//
;// the reason we don't use the standard windows dialog resources is that the fonts
;// get incredibly confusing. They are different sizes on every machine
;// going to our own custom setup eliminates this.
;// As an added bonus, we get quicker acces to the object names and parameters

    ;// every object starts with a POPUP_HEADER block

        POPUP_HEADER STRUCT

            pName   dd  0       ;// pointer to the name of this object
            siz     POINT {}    ;// desired client size
                                ;// if size if zero, then the default size is used
                                ;// and the item list is not parsed
        POPUP_HEADER ENDS

    ;// note: be sure to include popup_strings.asm in the project

    ;// following the popup header is an array POPUP_ITEM_xxx
    ;// they're slightly different for each type of control

    ;// these define each item in the popup window
    ;// flags for dwType (below), must be first DWORD of the popup ITEM

        POPUP_TYPE_END      equ  00000000h  ;// null terminator
        POPUP_TYPE_LABEL    equ  00000001h  ;// just draws the text
        POPUP_TYPE_BUTTON   equ  00000002h  ;// uses the button class
                                            ;// may be a button, check box, or radio button
        POPUP_TYPE_EDIT     equ  00000003h  ;// uses the edit class
        POPUP_TYPE_SCROLL   equ  00000004h  ;// uses a scroll bar
        POPUP_TYPE_LIST     equ  00000005h  ;// this is a list box (simple)
        POPUP_TYPE_COMBO    equ  00000006h  ;// combo box

        POPUP_LAST_TYPE     EQU         6h  ;// end of types

    ;// also incorporated into the high word of type
    ;// is an optional bitmap identifier
    ;// in popup_fix.txt use a line such as
    ;// IDD_DIALOG_DIVIDER BITMAP ID_DIGITAL_POS 0
    ;// note that this is an INDEX into button_bitmap_table


    ;// then we define the unique type structures for each item

        POPUP_ITEM_LABEL STRUCT

            ;// builds a STATIC label

            dwType  dd  POPUP_TYPE_LABEL
            pText   dd  0       ;// pointer to text for this item
            rect    RECT {}     ;// pos, siz of item
            cmdID   dd 0        ;// command ID for those that need them
            dwStyle dd  0       ;// style flags
            pHelp   dd  0       ;// pointer to help text

        POPUP_ITEM_LABEL ENDS

        POPUP_ITEM_BUTTON STRUCT

            ;// builds a BUTTON

            dwType  dd  POPUP_TYPE_BUTTON
            pText   dd  0       ;// pointer to text for this item
            cmdID   dd  0       ;// command id for the item
            rect    RECT {}     ;// pos, siz of item
            dwStyle dd  0       ;// window flags for the style
            pHelp   dd  0       ;// pointer to help text

        POPUP_ITEM_BUTTON ENDS

        POPUP_ITEM_EDIT STRUCT

            ;// builds an EDIT box

            dwType  dd  POPUP_TYPE_EDIT
            cmdID   dd  0       ;// command id for the item
            rect    RECT {}     ;// pos, siz of item
            dwStyle dd  0       ;// window flags for the style
            pHelp   dd  0       ;// pointer to help text

        POPUP_ITEM_EDIT ENDS

        POPUP_ITEM_SCROLL STRUCT

            ;// builds a scroll bar

            dwType  dd  POPUP_TYPE_SCROLL
            cmdID   dd  0       ;// command id for the item
            rect    RECT {}     ;// pos, siz of item
            dwStyle dd  0       ;// window flags for the style
            pHelp   dd  0       ;// pointer to help text

        POPUP_ITEM_SCROLL   ENDS

        POPUP_ITEM_LIST STRUCT

            ;// builds a list box

            dwType  dd  POPUP_TYPE_LIST
            cmdID   dd  0       ;// command id for the item
            rect    RECT {}     ;// pos, siz of item
            dwStyle dd  0       ;// window flags for the style
            pHelp   dd  0       ;// pointer to help text

        POPUP_ITEM_LIST ENDS

        POPUP_ITEM_COMBO STRUCT

            ;// builds a list box

            dwType  dd  POPUP_TYPE_COMBO
            cmdID   dd  0       ;// command id for the item
            rect    RECT {}     ;// pos, siz of item
            dwStyle dd  0       ;// window flags for the style
            pHelp   dd  0       ;// pointer to help text

        POPUP_ITEM_COMBO    ENDS


        ;// TODO
        ;//
        ;// POPUPITEM_TABCONTROL ?  no way!


    ;// then these functions access the pop stuf

    POPUP_STYLE     equ WS_CAPTION OR WS_SYSMENU OR WS_POPUP
    POPUP_STYLE_EX  equ WS_EX_DLGMODALFRAME OR WS_EX_TOPMOST OR WS_EX_WINDOWEDGE OR WS_EX_TOOLWINDOW

    EXTERNDEF popup_hWnd:DWORD
    EXTERNDEF popup_Object:DWORD    ;// set for object currently showing the popup
    EXTERNDEF popup_bDelete:DWORD   ;// set when an object is deleted, prevents dialog mixups
    EXTERNDEF popup_bShowing:DWORD      ;// prevents mixups, set by popup_Show
    EXTERNDEF popup_EndActionAlreadyCalled:DWORD
    EXTERNDEF popup_no_undo:DWORD   ;// prevents popup call endaction when loosing focus
    EXTERNDEF popup_status_hWnd:DWORD
    EXTERNDEF popup_hFocus:DWORD    ;// if an object needs it's focus set, we do that here

    POPUP_HELP_HEIGHT EQU 28

    popup_Show          PROTO STDCALL pObject:PTR OSC_OBJECT
    popup_BuildControls PROTO STDCALL hWnd:DWORD, pPopup:DWORD, bUseHelp:DWORD, dwFlags:DWORD
    popup_Proc PROTO    ;// STDCALL hWnd:dword, msg:dword, wParam:dword, lParam:dword

    popup_CleanupWindow PROTO       ;// destroys all child windows and extra menu items

    popup_wm_setcursor_proc PROTO   ;// defined in hWnd_popup
    popup_wm_drawitem_proc PROTO    ;// defined in hWnd_popup
    display_popup_help_text PROTO ;// special formatting for hotkeys

    ;// osc_Command must return one these flags in eax
    ;// POPUP_IGNORE is especially important for EN_xx messages

    ;// note: keep lower byte clear for re/developement to abox200

    POPUP_CLOSE             equ 4000h   ;// close the popup dialog
    POPUP_INITMENU          equ 2000h   ;// call object's initmenu function
    POPUP_REBUILD           equ 1000h   ;// completely rebuild the dialog calling popup_Show
    POPUP_KILL_THIS_FOCUS   equ 0800h   ;// kill the edit and list box focus
    POPUP_REDRAW_OBJECT     equ 0400h   ;// schedule object for redraw
    POPUP_SET_DIRTY         equ 0200h   ;// set the app dirty flag
    POPUP_IGNORE            equ 0100h   ;// ignore the return value
    POPUP_DONOT_RESET_FOCUS equ 8000h   ;// usually the popup command handler resets the focus
                                        ;// to the popup window, this causes problems for popups
                                        ;// that create other popups

    POPUP_REFRESH_STATUS    EQU 0080h   ;// forces the status text to be refreshed
                                        ;// ptr to text must be in edx

    POPUP_RETURN_TEST      equ 0FF80h   ;// test value for developement
                                        ;// osc_Command must return a bit




;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;//
;//
;// ;// objectlist.inc has all the EXTERN defs for each object with a popup
;//

        INCLUDE <objectlist.inc>

    ;// except these

        EXTERNDEF popup_GROUP_CLOSED:POPUP_HEADER
        EXTERNDEF popup_COLORS:POPUP_HEADER
        EXTERNDEF popup_BUS:POPUP_HEADER
        EXTERNDEF popup_ABOUT:POPUP_HEADER
        EXTERNDEF popup_ALIGN:POPUP_HEADER


;////////////////////////////////////////////////////////////////////
;//
;//                         gui handlers may use the SET_STATUS macro
;//     status window       along with one of the status_ values
;//

    status_Initialize PROTO
    status_Destroy PROTO
    status_Update PROTO

    EXTERNDEF status_mode:DWORD
    EXTERNDEF last_status_mode:DWORD


    SET_STATUS MACRO val:req, mandatory

        ;// REFRESH forces an update of the prveious
        ;// MANDATORY forces the value to display by clearing the last value cache

        or app_bFlags, APP_SYNC_STATUS
        IFIDN <val>,<REFRESH>
            or last_status_mode, -1
        ELSE
            mov status_mode, val
            IFNB <mandatory>
                .ERRDIF <mandatory>,<MANDATORY>,<must use MANDATORY or leave blank>
                or last_status_mode, -1
            ENDIF
        ENDIF

        ENDM

    ;// status_mode values

        status_HOVER_DESK       EQU 0001
        status_HOVER_OSC        EQU 0002
        status_HOVER_CON        EQU 0003
        status_HOVER_PIN_UNCON  EQU 0004
        status_HOVER_PIN_CON    EQU 0005

        status_CONNECT_UI_UI    EQU 0006    ;// "Can't connect inputs to inputs", 0
        status_CONNECT_UO_UO    EQU 0007    ;// "Can't connect outputs to outputs",0
        status_CONNECT_UO_CI    EQU 0008    ;// "Pin is already connected to a source",0
        status_CONNECT_UO_CO    EQU 0007    ;// "Can't connect outputs to outputs.",0
        status_CONNECT_CI_UO    EQU 0007    ;// "Can't connect outputs to outputs.",0
        status_CONNECT_CI_CI    EQU 0007    ;// "Can't connect outputs to outputs.",0
        status_CONNECT_CI_CO    EQU 0007    ;// "Can't connect outputs to outputs.",0
        status_CONNECT_CO_UI    EQU 0009    ;// "Can't move an output to an input.",0
        status_CONNECT_CO_CI    EQU 0009    ;// "Can't move an output to an input.",0
        status_CONNECT_BO_BO    EQU 0010    ;// "Can't move bus source to another source.",0

        status_CONNECT_CO_CO    EQU 0011    ;// "Move connection(s) to this output.",0
        status_CONNECT_CO_UO    EQU 0011    ;// "Move connection(s) to this output.",0
        status_CONNECT_CI_UI    EQU 0012    ;// "Move connection to this input.",0

        status_CONNECT_UI_CI    EQU 0013    ;// "Connect to this pin's source.",0
        status_CONNECT_UI_UO    EQU 0014    ;// "Connect these pins together",0
        status_CONNECT_UI_CO    EQU 0014    ;// "Connect these pins together",0
        status_CONNECT_UO_UI    EQU 0014    ;// "Connect these pins together",0

        status_CONNECT_CI_UI_special    EQU 0006
        status_CONNECT_CI_UO_special    EQU 0011
        status_CONNECT_CI_CI_special    EQU 0013
        status_CONNECT_CI_CO_special    EQU 0011
        status_CONNECT_CO_UI_special    EQU 0014
        status_CONNECT_CO_UO_special    EQU 0007
        status_CONNECT_CO_CI_special    EQU 0007
        status_CONNECT_CO_CO_special    EQU 0007

        status_CONNECT_SAME     EQU 0015    ;// "Can't connect a pin to itself.",0

        status_CONNECTING       EQU 0016


        status_MAINMENU         EQU 0017    ;// string ptr set by mainmenu_wm_setcursor_proc
        EXTERNDEF sm_mainmenu:DWORD

        status_HOVER_PIN_BUS_IN     EQU 0018
        status_HOVER_PIN_BUS_OUT    EQU 0019

        status_SAVING_BMP           EQU 0020

        status_HOVER_DESK_SEL       EQU 0021

        status_CONNECTING_swap      EQU 0022

        MAX_STATUS_MODE equ 0022


;////////////////////////////////////////////////////////////////////
;//
;//
;//     registry
;//

    registry_ReadSettings PROTO STDCALL
    registry_WriteSettings PROTO STDCALL
    registry_Uninstall PROTO STDCALL
    registry_ReadMRU5 PROTO STDCALL
    registry_WriteMRU5 PROTO STDCALL




;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;//
;//
;// SYSTEM AND MAIN WINDOW
;//
    ;// app_FatalExit PROTO STDCALL ;// some day this will not be needed

        EXTERNDEF app_ExitNow:NEAR

    ;// handles

        EXTERNDEF hInstance:DWORD       ;// global hInstance
        EXTERNDEF hMainWnd:DWORD        ;// main window handle
        EXTERNDEF app_msg:tagMSG        ;// main message struct

    ;// strings for creating windows

        EXTERNDEF szStatic:BYTE
        EXTERNDEF szButton:BYTE
        EXTERNDEF szEdit:BYTE
        EXTERNDEF szScrollBar:BYTE
        EXTERNDEF szListBox:BYTE
        EXTERNDEF szComboBox:BYTE

    comment ~ /*

    ;// the infamouse IsDirty flag, and a macro to set it
    ;// no longer used, see unredo.inc

    */ comment ~


    ;// these help synchronize the save buttons on the main menu
    ;// see mainmenu_SyncSaveButtons for details

        EXTERNDEF mainmenu_mode:DWORD   ;// flags for keeping track of stuff

        MAINMENU_NOSAVE         EQU 00000010h   ;// save should be disabled
        MAINMENU_NOSAVE_STATE   EQU 00000020h   ;// save IS disabled
        MAINMENU_NOSAVEAS       EQU 00000040h   ;// saveas should be disabled
        MAINMENU_NOSAVEAS_STATE EQU 00000080h   ;// saveas IS disabled

        MAINMENU_UNTITLED       EQU 00000001h   ;// set by build default title
        MAINMENU_ABOX1          EQU 00000002h   ;// set by

        MAINMENU_NOSAVEBMP      EQU 00001000h   ;// save bmp should be diabled
        MAINMENU_NOSAVEBMP_STATE EQU 0002000h   ;// save bmp IS disabled

        EXTERNDEF file_mode:DWORD   ;// used in circuit_Load and file_Load


;////////////////////////////////////////////////////////////////////
;//
;//                     collection of bits, telling us about the state of the app
;//     app_bFlags      there are several classes, DLG says that a dialog is on
;//                     SYNC say we need to check something
;//                     MODE says what the user is doing
;//
    ;// flags

        EXTERNDEF app_DlgFlags:DWORD
        EXTERNDEF app_bFlags:DWORD

    ;// dialog flags tell us which windows is on

        DLG_COLORS              equ 00000001h   ;// the colors dialog is on
        DLG_ABOUT               equ 00000001h   ;// we're showing the about panel
        DLG_FILENAME            equ 00000002h   ;// the filename dialog is on
        DLG_CREATE              equ 00000004h   ;// the create dialog is on, or the align dialog
        DLG_POPUP               equ 00000008h   ;// a popup dialog is on
        DLG_BUS                 equ 00000010h   ;// the bus popup is on
        DLG_MENU                equ 00000020h   ;// main menu is on, need to xlate mouse coords
        DLG_LABEL               equ 00000040h   ;// the label editor is on
        DLG_MESSAGE             equ 00000080h   ;// a message box is on

        DLG_TEST                equ 000000FFh

    ;// sync flags tell us which actions need to be taken to make the app tell the truth

        APP_SYNC_AUTOUNITS          equ 00000080h   ;// need to do call unit_AutoTrace
                                                    ;// use context_SetAutoTrace to set
        APP_SYNC_GROUP              equ 00000100h   ;// need to scan open group
        APP_SYNC_PLAYBUTTON         equ 00000200h   ;// need to make sure the play menu is set
        APP_SYNC_STATUS             equ 00000400h   ;// status needs updated
        APP_SYNC_OPTIONBUTTONS      equ 00000800h   ;// main menu sync with settings
        APP_SYNC_EXTENTS            equ 00001000h   ;// need to check the extents
        APP_SYNC_TITLE              equ 00002000h   ;// title needs to be built
        APP_SYNC_MOUSE              equ 00004000h   ;// send a mouse move message to set the hover
                                                    ;// processed by gdi_wm_paint_proc
        APP_SYNC_MRU                equ 00008000h   ;// put circuit title at top of mru
        APP_SYNC_SAVEBUTTONS        equ 00010000h   ;// need to adjust the save menus

        APP_SYNC_LOCK               equ 00020000h   ;// Z list needs scanned to determine if there
                                                    ;// are locked items. set by osc_Dtor

        APP_UNUSED_BIT18            equ 00040000h   ;// i forget what this did

    ;// call this function to synchronize the gui with the flags

        app_Sync PROTO  ;// defined in hwnd_Main.asm

    ;// APP_MODES tell gdi_render what to draw, and mouse/key handler how to operate

        APP_MODE_USING_SELRECT      equ 00080000h   ;// right click and drag

        APP_MODE_MOVING_SCREEN      equ 00100000h   ;// moving the screen
            ;// moving the screen

        APP_MODE_SELECT_OSC         equ 00200000h
            ;// shift key is down
            ;// no other pointers should be set

        APP_MODE_UNSELECT_OSC       equ 00400000h
            ;// control key is down
            ;// so we unselect the selection

        APP_MODE_CONNECTING_PIN     equ 00800000h   ;// connecting a pin
            ;// implies:
            ;// hMainwnd has mouse capture
            ;// pin_down is valid
            ;// osc_hover and pin_hover are being queried

        APP_MODE_MOVING_PIN         equ 01000000h   ;// moving a pin
            ;// hMainwnd has mouse capture
            ;// pin_down is valid

        APP_MODE_MOVING_OSC         equ 02000000h   ;// moving an osc or group of oscs
        APP_MODE_MOVING_OSC_SINGLE  equ 04000000h   ;// moving an osc, ignore group of oscs
        APP_MODE_CONTROLLING_OSC    equ 08000000h   ;// controlling an osc
            ;// this pair tells what osc_down means
            ;// it implies that hMainWnd has the screen capture

        APP_MODE_OSC_HOVER          equ 10000000h   ;// osc_hover is the osc
        APP_MODE_CON_HOVER          equ 20000000h   ;// osc_hover is an osc's control
            ;// this pair tells what osc_hover means

        APP_MODE_IN_GROUP           equ 40000000h   ;// editing a group

        APP_MODE_MAXIMIZED          equ 80000000h   ;// prevents drawing the resize grip


    ;// system values needed for various platforms

        EXTERNDEF app_CPUFeatures:DWORD ;// results of the cpuid function
        EXTERNDEF app_dwPlatformID:DWORD;// results of osversioninfo
        EXTERNDEF app_AllocationGranularity:DWORD;// from sys info

        ;//ABOX242 -- AJT -- Needed for VirtualProtect and FlushInstructionCache
        ;//                  So far only the 'equation' objects need this ...
        EXTERNDEF pfVirtualProtect:DWORD
        ;// not needed on IA32 architectureEXTERNDEF pfFlushInstructionCache:DWORD
        
        
    ;// xmouse

        EXTERNDEF app_xmouse:DWORD

    ;// functions

        mainWndProc PROTO                   ;// mainWndProc and it's direct jumps
        app_GetWindowSettings PROTO

;//
;// SYSTEM AND MAIN WINDOW
;//
;//
;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////


;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;//
;//
;// MOUSE   defined in ABox_mouse.asm
;//

    EXTERNDEF mouse_now:POINT   ;// where it is now

    EXTERNDEF mouse_selrect:RECT;// used by the selrect

    EXTERNDEF mouse_delta:POINT ;// how far it moved
    EXTERNDEF mouse_prev:POINT  ;// previous known position

    EXTERNDEF osc_hover:DWORD   ;// pointer to osc with the hover
    EXTERNDEF pin_hover:DWORD   ;// pointer to the pin with the hover

    EXTERNDEF pin_down:DWORD    ;// pointer to the pin that the mouse came down on
    EXTERNDEF osc_down:DWORD    ;// pointer to the osc that the mouse came down on

    EXTERNDEF mouse_pDest:DWORD ;// ptr to gdibitmap

    EXTERNDEF mouse_state:DWORD ;// state and interlock flags for mouse

    EXTERNDEF mouse_move_limit:DWORD    ;// trap for detecting motion

    ;// other state flags, the rest are defined in hWnd_mouse.asm

    PIN_HAS_MOVED EQU  100h ;// interlock for moving a pin
    OSC_HAS_MOVED EQU  200h ;// interlock for moving a single osc
    SEL_HAS_MOVED EQU  400h ;// interlock for drawing a selrect
    CON_HAS_MOVED EQU  800h ;// interlock for controlling an osc
    SCR_HAS_MOVED EQU 1000h ;// interlock for controlling the screen

    mouse_reset_all_hovers  PROTO
    mouse_reset_pin_down    PROTO
    mouse_reset_osc_down    PROTO

    mouse_set_pin_hover PROTO

    ;// see app_bFlags for further conditions to these values


;//
;// MOUSE   defined in ABox_mouse.asm
;//
;//
;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////


;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;//
;//                         use app_bFlags instead
;// APP level handlers
;//

    app_Uninstall PROTO STDCALL

;//
;// APP level handlers
;//
;//
;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////


;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;//
;// REGISTRY and PERSISTANT SETTINGS

    ;// flags for show (below)

    SHOW_STATUS         equ  00000001h  ;// show status
    SHOW_CLOCKS         equ  00000002h  ;// off for don't show
    SHOW_CHANGING       equ  00000004h  ;// show changing outputs
    SHOW_UPDATE_FAST    equ  00000008h  ;// use realtime updates, off for slow

    ;// color sets, 0 for none

    SHOW_COLOR_PRESET1  equ  00000040h  ;// using the custom 1 colors
    SHOW_COLOR_PRESET2  equ  00000050h  ;// using the custom 2 colors
    SHOW_COLOR_PRESET3  equ  00000060h  ;// using the custom 3 colors
    SHOW_COLOR_PRESET4  equ  00000070h  ;// using the custom 4 colors

    ;// window maximized
    SHOW_MAXIMIZE       equ  00000100h  ;// show the app maximized

    ;// create size
    SHOW_CREATE_LARGE   EQU  00000200h  ;// show the create panel as in large mode

    ;// this is the settings stuct
    ;// we use the defaults when creating a new one

    ABOX_SETTINGS STRUCT

        ;// window locations and display flags
        mainWnd_pos     POINT {128,64}  ;// position on screen
        mainWnd_siz     POINT {512,352} ;// size of screen
        show            dd  0           ;// show options

        ;// color schemes
        colors  GDI_PALETTE {}          ;// the current color set we're using
        presets GDI_PALETTE 4 dup ({})  ;// user settable color schemes

    ABOX_SETTINGS ENDS

    EXTERNDEF   app_settings:ABOX_SETTINGS          ;// defined in ABox.asm
    EXTERNDEF   app_default_colors:DWORD






;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;//
;// ABOUT
;//


    about_Show PROTO STDCALL bSplash:DWORD

    about_SetLoadStatus PROTO
    ;// about_ClearLoadStatus PROTO

    ;// used in hardware ctor to show devices as they are registered
    EXTERNDEF   about_hWnd_device:DWORD     ;// used by devices when ctoring
    EXTERNDEF   about_hWnd_load:DWORD       ;// used to inidcate the loading progress
    EXTERNDEF   about_hWnd:DWORD

    EXTERNDEF   sz_App_Title:BYTE   ;// needed for app_InitializeWindows


;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;//
;// COLORS
;//

    colors_Show PROTO


;///////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////
;//
;//
;// CLOCK SPEED


;// clock speeds
    ;//EXTERNDEF osc_Clock_Speed_int:DWORD    ABOX242 AJT
    ;//EXTERNDEF osc_Clock_Speed_frac:DWORD
    EXTERNDEF osc_Clock_Speed_string:BYTE       ;// string formatted with eng suffix

    clock_BeginMeasure  PROTO
    clock_EndMeasure    PROTO


;///////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////
;//
;//                     not used, just too damn tedious and complicated
;// ole drag drop

;// drop_Initialize PROTO
;// drop_Destroy    PROTO



;///////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////
;////
;////
;////   V S T   P L U G I N S
;////

    EXTERNDEF plugin_szRegKey:BYTE
    EXTERNDEF plugin_szRegKey_2:BYTE

    plugin_Initialize   PROTO STDCALL
    plugin_Destroy      PROTO

    plugin_ReadParameters PROTO STDCALL pObject:PTR OSC_OBJECT


;////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////
;///
;///                    a variety of useful macros to clean up the code
;///    M A C R O S
;///





;///                these take a normalized angle,
;///                convert it to the appropriate address
;/// MATH macros    and return the value in the FPU's st(0)
;///


math_Sin MACRO angle:req, mem:req, reg:=<eax>

    ;// scale the real4 angle to an intger adress

        fld   angle
        fmul  math_NormToOfs
        fistp mem

    ;// load the correct sin value

        mov reg, mem
        and  reg, math_AdrMask
        add  reg, math_pSin
        fld  REAL4 PTR [reg]

    ENDM


math_Cos MACRO angle:req, mem:req, reg:=<eax>

    ;// scale the real4 angle to an intger adress

        fld   angle
        fmul  math_NormToOfs
        fistp mem

    ;// load the correct cos value

        mov reg, mem
        add  reg, math_OfsQuarter
        and  reg, math_AdrMask
        add reg, math_pSin
        fld REAL4 PTR [reg]

    ENDM



math_SinCos MACRO angle:req, mem:req, use_abs

    ;// uses eax

    ;// scale the real4 angle to an intger adress

        fld   angle
        IFNB <use_abs>
            IFIDN <use_abs>,<ABS>
                fabs
            ELSE
                .ERR <use ABS or leave blank
            ENDIF
        ENDIF
        fmul  math_NormToOfs
        fistp mem

    ;// load the correct sin value

        mov eax, mem
        and  eax, math_AdrMask
        add  eax, math_pSin
        fld  REAL4 PTR [eax]

    ;// load the correct cos value

        mov eax, mem
        add  eax, math_OfsQuarter
        and  eax, math_AdrMask
        add eax, math_pSin
        fld REAL4 PTR [eax]

    ENDM





;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;//
;// BASE  MACROS    these are used to get parameters from the base class
;//                 they save some typeing and automatically assume


    BASE_TO_POPUP MACRO base:req, popup:req

        mov popup, [base].data.pPopupHeader
        ASSUME popup:PTR POPUP_HEADER

        ENDM


    BASE_TO_PIN_INDEX MACRO base:req, reg:req, index:req

        lea reg, [base+SIZEOF OSC_BASE+index*SIZEOF APIN_init]
        ASSUME reg:PTR APIN_init

        ENDM

    BASE_TO_LAST_PIN MACRO base:req, reg:req

        mov reg, [base].data.numPins
        shl reg, LOG2(SIZEOF APIN_init)
        lea reg, [base+SIZEOF OSC_BASE+reg]
        ASSUME reg:PTR APIN_init

        ENDM



;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;//
;// OSC MACROS      these are used to navigate OSC_OBJECT's
;//                 they save some typeing and automatically assume


    GET_OSC MACRO reg:req

        ;// this loads the register and assumes it
        ;// pObject MUST BE THE OBJECT

        mov reg, pObject
        ASSUME reg:PTR OSC_OBJECT

        ENDM


    GET_OSC_FROM MACRO reg:req, source:req

        ;// loads osc from some other source

        mov reg, source
        ASSUME reg:PTR OSC_OBJECT

        ENDM

    GET_OSC_MAP_FROM MACRO reg:req, source:req

        ;// loads osc from some other source

        mov reg, source
        ASSUME reg:PTR OSC_MAP

        ENDM


    OR_GET_OSC_FROM MACRO reg:req, source:req

        ;// loads osc from some other source

        or reg, source
        ASSUME reg:PTR OSC_OBJECT

        ENDM



    OSC_TO_DATA MACRO osc:req, dat:req, ass:req

        ;// loads the osc data pointer and assumes it

        mov dat, [osc].pData
        assume dat:PTR ass

        ENDM


    OSC_TO_BASE MACRO osc:req, bas:req

        ;// this loads and assumes the base

        mov bas, [osc].pBase
        ASSUME bas:PTR OSC_BASE

        ENDM

    OSC_TO_LAST_PIN MACRO osc:req, pin:req

        ;// gets and assumes the last pin
        ;// NOTE!!!
        ;//     this is really one passed the end

        mov pin, [osc].pLastPin
        ASSUME pin:PTR APIN

        ENDM



    OSC_TO_CONTAINER MACRO osc:req, cnt:req, noerror

        mov cnt, [osc].pContainer
        ASSUME cnt:PTR GDI_CONTAINER
        IFDIF <noerror>,<NOERROR>
            IFNB <noerror>
            .ERR <use NOERROR or leave blank>
            ENDIF
            DEBUG_IF <!!cnt>            ;// container was not set
        ENDIF

        ENDM


    OSC_TO_DEST MACRO osc:req, dest:req

        mov dest, [osc].pDest
        DEBUG_IF <!!dest>       ;// osc pDest was not set

        ENDM

    OSC_TO_SOURCE MACRO osc:req, src:req

        mov src, [osc].pSource
        DEBUG_IF <!!src>        ;// osc pSource was not set

        ENDM

    OSCMAP_TO_PIN MACRO osc:req, name:req, pin:req

        lea pin, [osc].name
        ASSUME pin:PTR APIN

        ENDM




;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////
;///
;///        APIN MACROS     these are used to navigate APIN's
;///

    GET_PIN MACRO nam:req, reg:req

        ;// this loads and assumes the pin

        mov reg, nam
        ASSUME reg:PTR APIN

        ENDM


    OR_GET_PIN MACRO nam:req, reg:req

        ;// this or's the pin so we set the flags and assumes the pin
        ;// reg is supposed to be zero

        or reg, nam
        ASSUME reg:PTR APIN

        ENDM

    GET_PIN_FROM    MACRO reg:req, nam:req

        ;// this loads and assumes the pin

        mov reg, nam
        ASSUME reg:PTR APIN

        ENDM

    OR_GET_PIN_FROM MACRO reg:req, nam:req

        ;// this or's the pin so we set the flags and assumes the pin
        ;// reg is supposed to be zero

        or reg, nam
        ASSUME reg:PTR APIN

        ENDM


    PIN_TO_OSC MACRO pin:req, osc:req

        ;// loads the osc pointer and assumes
        ;// pin must be assumed as a pin

        mov osc, [pin].pObject
        ASSUME osc:PTR OSC_OBJECT

        ENDM

    OSC_TO_PIN_INDEX MACRO osc:req, pin:req, index:req

        ;// this sets pin to the correct address
        ;// assumes the pin
        ;// index must be an INTEGER

        lea pin, [osc + SIZEOF OSC_OBJECT + (SIZEOF APIN) * index]
        ASSUME pin:PTR APIN

        ENDM

    GET_NEXT_PIN MACRO pin1:req, pin2:req

        ;// loads the next pin in an osicallator
        ;// the assumes it

        lea pin2, [pin1+SIZEOF APIN]
        ASSUME pin2:PTR APIN

        ENDM

    PIN_TO_DEST MACRO pin:req, dest:req

        mov dest, [pin].pDest
        DEBUG_IF <!!dest>       ;// dest wasn't set !

        ENDM

    PIN_TO_TSHAPE MACRO pin:req, shape:req, noerror

        ;// this get the pin's triangle shape

        mov shape, [pin].pTShape
        ASSUME shape:PTR TRIANGLE_SHAPE
        IFDIF <noerror>,<NOERROR>
            IFNB <noerror>
            .ERR <use NOERROR or leave blank>
            ENDIF
            DEBUG_IF <!!shape>      ;// shape wasn't set !
        ENDIF

        ENDM

    PIN_TO_BSHAPE MACRO pin:req, shape:req

        ;// this get the pin's bus shape

        mov shape, [pin].pBShape
        ASSUME shape:PTR GDI_SHAPE
        DEBUG_IF <!!shape>      ;// shape wasn't set !

        ENDM

    PIN_TO_LSHAPE MACRO pin:req, shape:req

        ;// this get the pin's logic shape

        mov shape, [pin].pLShape
        ASSUME shape:PTR GDI_SHAPE
        DEBUG_IF <!!shape>      ;// shape wasn't set !

        ENDM

    PIN_TO_FSHAPE MACRO pin:req, shape:req

        ;// this get the pin's font shape

        mov shape, [pin].pFShape
        ASSUME shape:PTR GDI_SHAPE
        DEBUG_IF <!!shape>      ;// shape wasn't set !

        ENDM

    PIN_TO_LNAME MACRO pin:req, lname:req

        mov lname, [pin].pLName
        ASSUME lname:PTR BYTE

        ENDM




;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;///
;///    ITERATE_PINS
;///
;///        use opening and closing statements to rip through the pins list
;///
;///    !!! ALWAYS USES ESI AND EBX AS OSC AND PIN !!!
;///
;///    !!! D O   N O T   N E S T  !!!


    ITERATE_PINS MACRO

        ;// esi must be the osc, ebx will be the iterator
        ;// must have a closing PINS_ITERATE

            OSC_TO_LAST_PIN esi, ebx
            jmp @F
            .REPEAT

        ENDM

    ;// do work here
    ;//
    ;// DO NOT USE @@ FOR LABELS
    ;//

    PINS_ITERATE MACRO

        ;// this closes the above macro

            @@: sub ebx, SIZEOF APIN

            .UNTIL ebx <= esi

        ENDM



    ;// ITERATE_PINS is not always the best way to do it
    ;// so this block may be used when the iteration should take place at the top of the loop
    ;//
    ;// pin and osc must be assume as APIN and OSC_OBJECT respectivly

    OSC_GET_PREV_PIN MACRO osc:req, pin:req, exit:req

        sub pin, SIZEOF APIN
        cmp pin, osc
        jbe exit

        ENDM




















;///////////////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////////////
;////
;////
;////   D E V I C E  M A C R O S
;////


    GET_DEVICE MACRO reg:req
    ;//
    ;// loads and assumes pDevice
    ;// "pDevice" must exist in the current scope

        mov reg, pDevice
        ASSUME reg:PTR HARDWARE_DEVICEBLOCK

        ENDM

    DEVICE_TO_DATA MACRO reg1:req, reg2:req, ass:=<DWORD>
    ;//
    ;// loads pData from a device block and assumes it
    ;//

        mov reg1, (HARDWARE_DEVICEBLOCK PTR [reg2]).pData
        ASSUME reg1:PTR ass

        ENDM



;/////////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////////
;/////
;/////                          these come in handy for building the calc functions
;/////  C A L C   M A C R O S
;/////
;/////

TINY_NUMBER_TEST MACRO reg:req, t_reg:=<eax>
;//
;// TINY_NUMBER_TEST    FXAM doesn't seam to work !!
;//                     this checks for zero,
;//                     subsequent instructions can use the carry flag
;//                     to check the sign (1 if negative)
;//
    xor t_reg, t_reg
    mov @CatStr( @SubStr( t_reg, 2,1 ), <l> ), BYTE PTR [reg+3]
    and @CatStr( @SubStr( t_reg, 2,1 ), <l> ), 0FCh
    shl @CatStr( @SubStr( t_reg, 2,1 ), <l> ), 1
    ENDM

;// in english, the above reads:
;//
;// xor eax, eax            ;// clear eax:
;// mov al, BYTE PTR reg    ;// or with sign and exponent of test value
;// and al, 0FCh            ;// ditch bottom two bits
;// shl al, 1               ;// shift sign bit into carry, and leave zero if denormal
;//


IF_TINY_NUMBER MACRO reg:req
;//
;//     don't forget to terminate the .IF clause
;//
    TINY_NUMBER_TEST reg
    .IF ZERO?
    ENDM


IF_NOT_TINY_NUMBER MACRO reg:req, t_reg:=<eax>
;//
;//     don't forget to terminate the .IF clause
;//
    TINY_NUMBER_TEST reg
    .IF !ZERO?
    ENDM


IF_CONNECTED MACRO reg:req
;//
;// this macro will check the connection,
;// load the pin, load the status, and load the data pointer
;// uses eax, and may leave the register null
;//
;// an ending .ELSE or .ENDIF is REQUIRED
;//
    mov reg, [reg].pPin         ;// load the pin
    .IF reg                     ;// check for zero
        mov eax, [reg].dwStatus ;// load the status
        mov reg, [reg].pData    ;// load the data pointer
    ENDM






comment ~ /*

    OSC_MAP is a struct that encompassed the entire osc_object, apin[], pin_data[], and osc_data
    this is only to be defined at file scope

    the following macro is designed for determining which calc routine to use
    it builds a pin data pointer and a tristate logic value
    osc's may implement this by building several values (all in base 3), then
    using a calc jump table

*/ comment ~
;////////////////////////////////////////////////////////////////////
;//                                                 OSC_MAP MACRO
;//
;//     OSC_TO_PIN_DATA
;//
comment ~ /*

    given an OSC_MAP
    this will:
        retrieve the data pointer for the named pin
        assume the data pointer as a dword
        define the base 3 jump index for n,s,d
        accumulate it to a jump pointer, always ecx
        assume the destination register as a DWORD

*/ comment ~

    LOG_PIN_CHANGING = LOG2(PIN_CHANGING)

    OSCMAP_TO_PIN_DATA MACRO osc:req, pin:req, name:req, power:req

    ;;// osc  = register that points at the osc map struct
    ;;// pin  = register to recieve the pin's data pointer
    ;;// name = name of the pin in question (in the OSC_MAP)
    ;;// power= base three digit (only 0,3 and 9 are currently supported)

    ;;// ecx = accumulated jump index

        LOCAL ll_next_pin

        mov pin, [osc].name.pPin;// load the pin
        xor eax, eax            ;// clear for testing
        cmp pin, eax            ;// check if zero
        jz  ll_next_pin         ;// done if not connected
        ASSUME pin:PTR APIN
        bt  [pin].dwStatus, LOG_PIN_CHANGING    ;// get the changing bit
        mov pin, [pin].pData    ;// load the data pointer
        ASSUME pin:PTR DWORD    ;// now it's a dword
        IF power EQ 0           ;// if power is zero, do not adjust anything
            adc ecx, 1
        ELSEIF power EQ 3       ;// if power is 3, do the base three conversion
            adc eax, 1              ;// add the changing bit, and set the connected status as well
            lea eax, [eax+eax*2]    ;// convert to base 3 and move into place
            add ecx, eax            ;// add to jump accumulator
        ELSEIF power EQ 9           ;// if power is not zero, do the base three conversion
            adc eax, 1              ;// add the changing bit, and set the connected status as well
            lea eax, [eax+eax*8]    ;// convert to base 3 and move into place
            add ecx, eax            ;// add to jump accumulator
        ELSE
            .ERR <Power must be 0,3 or 9>
        ENDIF

    ll_next_pin:

        ENDM

;//
;//
;//     OSC_TO_PIN_DATA
;//
;////////////////////////////////////////////////////////////////////











;/////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////
;/////
;/////
;/////
;/////
;/////          B O O M ! ! !
;/////
;/////
;/////
;/////



BOMB_TRAP MACRO

    DEBUG_IF <1>

    ENDM





FPU_STACK_TEST MACRO

;// this makes sure all the fpu registers were freed

    IFDEF DEBUGBUILD

    fnstsw ax
    shr eax, 11
    and eax, 7
    .IF !ZERO?
        int 3
    .ENDIF

    ENDIF

    ENDM







;////////////////////////////////////////////////////////////////////////////////////


;// !! whew !!


ENDIF ;// _ABOX_INCLUDED_