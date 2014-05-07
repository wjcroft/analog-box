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
;//     ABOX242 AJT -- detabified + text adjustments for 'lines too long' errors
;//
;//##////////////////////////////////////////////////////////////////////////
;//
;// closed_Group.asm    The grouping object
;//                     notes at the bottom
;//
;// TOC
;//
;// closed_group_DisplayHeirarchy
;// closed_group_EnterView
;// closed_group_ReturnFromView
;// closed_group_PrepareToLoad
;// idtable_Load
;//
;// closed_group_Ctor
;// closed_group_Dtor
;//
;// closed_group_PrePlay
;// closed_group_Calc
;//
;// closed_group_SetShape
;//
;// closed_group_Command
;// closed_group_InitMenu
;//
;// closed_group_Write
;// closed_group_AddExtraSize
;//
;// closed_group_GetUnit
;//
;// closed_group_LoadUndo


OPTION CASEMAP:NONE
.586
.MODEL FLAT


USE_THIS_FILE equ 1

IFDEF USE_THIS_FILE

    .NOLIST
    INCLUDE <Abox.inc>
    INCLUDE <groups.inc>
    INCLUDE <gdi_pin.inc>
    .LIST

.DATA


;// closed groups get a different interface
;// this is only a TEMPLATE for building a new base class
;// most of it will be copied to the new class

;// note that closed_group is NOT in the base list
;// xlate will set this up by itself

closed_Group    LABEL OSC_CORE

    OSC_CORE {  closed_group_Ctor,
                closed_group_Dtor,
                closed_group_PrePlay,
                closed_group_Calc }

    OSC_GUI {   closed_group_Render,closed_group_SetShape,,,,closed_group_Command,closed_group_InitMenu,
                closed_group_Write,closed_group_AddExtraSize,closed_group_SaveUndo,closed_group_LoadUndo,
                closed_group_GetUnit }

    OSC_HARD { }

    BASE_FLAGS EQU BASE_ALLOCATES_MANUALLY OR BASE_BUILDS_OWN_CONTAINER OR BASE_SHAPE_EFFECTS_GEOMETRY OR BASE_HAS_AUTO_UNITS

    OSC_DATA_LAYOUT { 0 ,
        IDB_CLOSED_GROUP,OFFSET popup_GROUP_CLOSED,
        BASE_FLAGS,,SIZEOF GROUP_DATA + 4 }


    OSC_DISPLAY_LAYOUT  {,,,,,,OFFSET sz_closed_group_description}



    sz_closed_group_description db 'A closed group contains other objects inside of it.',0

    ;// flags for dwUser, defined in groups.inc
    ;// see GROUP_CLOSED

    ;// layout parameters

        GROUP_PIN_SPACING_Y equ 10
        GROUP_TEXT_ADJUST   equ 12

    ;// top of heirarchy

        group_szPressEscape db 'Viewing Group [Press ESCAPE]',0
        ALIGN 4

    ;// id table needs a fake base class to be able to load it from a file
    ;// there is much wasted space here, too bad ?

        osc_IdTable OSC_CORE { idtable_Load }
                        OSC_GUI     {}
                        OSC_HARD    {}
                        OSC_DATA_LAYOUT { ,,,BASE_ALLOCATES_MANUALLY }



.CODE






ASSUME_AND_ALIGN
closed_group_DisplayHeirarchy PROC

    ;// edi enters as the dc to use

    ;// DESTROYS esi ebx ebp

    ;// make an iterator rect on the stack

        mov eax, 16     ;// left/right is indented
        push eax
        push eax
        push eax
        push eax

    ;// scan UP the stack and push all the string address

        mov ebp, esp    ;// we'll use ebp as an end of list
                        ;// and as a rect pointer

        stack_Peek gui_context, ebx

        CONTEXT_TO_GROUP_ADJUST = OFFSET CLOSED_GROUP_DATA_MAP.context - \
                                  OFFSET CLOSED_GROUP_DATA_MAP.szName
        top_of_first_scan:

            lea esi, [ebx-CONTEXT_TO_GROUP_ADJUST]
            .IF ebx == OFFSET master_context
                pushd OFFSET group_szPressEscape
                jmp done_with_first_scan
            .ENDIF
            push esi
            stack_PeekNext gui_context, ebx
            jmp top_of_first_scan

        done_with_first_scan:

    ;// scan DOWN the stack and print all the strings

        jmp enter_second_loop
        .REPEAT

            add (RECT PTR[ebp]).left, eax       ;// add the returned line height
            add (RECT PTR[ebp]).top, eax
            add (RECT PTR[ebp]).right, eax
            add (RECT PTR[ebp]).bottom, eax

        enter_second_loop:

            pop esi     ;// retrieve the text pointer

            invoke DrawTextA, edi, esi, -1, ebp, DT_NOCLIP

        .UNTIL ebp == esp

    ;// clean up and we're done

        add esp, SIZEOF RECT

        ret

closed_group_DisplayHeirarchy ENDP





ASSUME_AND_ALIGN
closed_group_EnterView PROC

    ASSUME ebp:PTR LIST_CONTEXT
    ASSUME esi:PTR OSC_OBJECT

    ;// we are about to set gui_context
    ;// so we've several things to do to get ready for that

    ;// in the current context

        ;// reset downs and hovers
        mouse_reset_all_hovers PROTO    ;// defined in hwnd_mouse.asm
        invoke mouse_reset_all_hovers

        or [esi].dwHintI, HINTI_OSC_HIDE_PINS

    ;// enter the new context

        OSC_TO_DATA esi, ecx, CLOSED_GROUP_DATA_MAP
        lea ecx, [ecx].context
        ASSUME ecx:PTR LIST_CONTEXT

        stack_Push gui_context, ecx     ;// push the new context

    ;// in the new context

        ;// if auto trace is still on, then we do that now
        ;// this catches internal unit settings that never made it outside

        .IF [esi].dwUser & UNIT_AUTO_TRACE

            push ebp
            mov ebp, ecx
            invoke unit_AutoTrace
            pop ebp

        .ENDIF

    ;// tell app to synchronize some things
    ;// tell windows to redraw the whole thing (adds all objects to I list)

        or app_bFlags, APP_MODE_IN_GROUP OR APP_SYNC_EXTENTS OR APP_SYNC_MOUSE
        invoke InvalidateRect, hMainWnd, 0, 1

    ;// that should do it

        ret

closed_group_EnterView ENDP






ASSUME_AND_ALIGN
closed_group_ReturnFromView PROC uses ebp ebx

    ;// tasks:
    ;//
    ;//     pop the gui context
    ;//     invalidate entire window
    ;//     set the extents
    ;//     update app_bFlags veiwing group

        DEBUG_IF <!!(app_bFlags & APP_MODE_IN_GROUP)>   ;// not in a group

        stack_Peek gui_context, ebp

        mouse_reset_all_hovers PROTO    ;// defined in hwnd_mouse.asm
        invoke mouse_reset_all_hovers

        or app_bFlags, APP_SYNC_EXTENTS OR APP_SYNC_MOUSE

        stack_Pop gui_context, ecx, ebp         ;// pop the context
        cmp ebp, OFFSET master_context          ;// see if we're at the top
        jnz @F                                  ;// skip if not
        and app_bFlags, NOT APP_MODE_IN_GROUP   ;// reset the viewing group flag
    @@:

        ;// we should call prepare pins,
        ;// how do we find the group for this context ?

        GET_OSC_FROM ecx, [ecx].pGroup
        or [ecx].dwUser, GROUP_SCAN_PINS
        GDI_INVALIDATE_OSC HINTI_OSC_SHAPE_CHANGED, ecx

        ;// that's it

        ret

closed_group_ReturnFromView ENDP










ASSUME_AND_ALIGN
closed_group_PrepareToLoad PROC

;// this is called when user pastes an open group
;// file xlate has already been called

;// tasks:  1) prepare the file_header and file_osc
;//         2) determine the file size and reallocate as nessesary
;//         3) prepare the group_data and group_file
;//         4) prepare the FILE_PIN table
;//         5) scan for pin interfaces and zero the external connection
;//         6) return the (new) file in edi

comment ~ /*

    some details

    edi points at

    FILE_HEADER             .header
1)                          .numOsc     set to 1
                            .settings   should be correct
                            .pEOB       need to define

1)  GROUP_FILE  .FILE_OSC   .pBase      change to closed group
1)                          .numPins    xfer from GROUP_DATA
                            .pos
3)                          .extra      determine from file
                .dwUser                 set to closed ?
                .GROUP_DATA .pDevice
                            .numPin     xfer to file osc
                            .szName
        .header .FILE_HEADER.header
                            .numOsc     use for counting
                            .settings   should be cleared
3)                          .pEOB       define ??

*/ comment ~


    ASSUME edi:PTR CLOSED_GROUP_FILE_HEADER ;// may be reallocated
    ASSUME ebp:PTR LIST_CONTEXT             ;// preserved


    ;// 1)  determine the new sizes

        ;// 2a) scan file and count oscs
        ;//     we count all oscs, even if they're bad

            FILE_HEADER_TO_FIRST_OSC edi, esi
            ASSUME esi:PTR GROUP_FILE

            xor ecx, ecx
            or ecx, [esi].header.numOsc
            jz scan_2a_done

        scan_2a_top:    FILE_OSC_TO_NEXT_OSC esi
                        dec ecx
                        jns scan_2a_top
        scan_2a_done:   ;// now esi is at where the pins should start

        ASSUME esi:NOTHING

    ;// 2)  set num osc to 1
    ;//     set the base class to closed group
    ;//     xfer numPin to numPins
    ;//     xfer origonal header to new header

        mov [edi].numOsc, 1                 ;// set num osc in header
        mov edx, [edi].group_file.numPin    ;// load num pins from group
        DEBUG_IF <!!edx>    ;// ABOX239 -- need to trap empty groups
        mov [edi].group_file.pBase, OFFSET closed_Group ;// set the base class
        mov [edi].group_file.numPins, edx   ;// store numPins in file osc


        ;// 2b  determine the memory needed for pins
        ;//     edx is stil the number of pins
        ;//     keep track of the size of the pins

            lea ebx, [edx+edx*2]    ;// *3 (ebx is num dwords in pin table)
            lea edx, [esi+ebx*4]    ;// very end of file
            sub edx, edi            ;// subtract start to get size

        ;// 2c  check if we've enough memory

            cmp edx, MEMORY_SIZE(edi)
            jb no_need_to_reallocate

        time_to_reallocate:

            ;// abox231: oops, make sure it's dword aligned
            add edx, 3
            and edx, NOT 3

            invoke memory_Expand, edi, edx

            sub esi, edi    ;// get old offset to pins
            mov edi, eax    ;// set the file header pointer
            add esi, eax    ;// set the new offset to the pins

        no_need_to_reallocate:

    ;// 3)  define the pEOB, set extra, prepare the pins
    ;//     esi is at start of pin table
    ;//     edi is still the header
    ;//
    ;// data map
    ;// |<---------CLOSED_GROUP_FILE_HEADER------------->|
    ;// |                                                |
    ;// FILE_HEADER |<-------------GROUP_FILE----------->| in oscs....  out oscs...
    ;// |        |  FILE_OSC dwUser GROUP_DATA FILE_HEADER FILE_OSC...  FILE_OSC...
    ;// |        |        |                                             |
    ;// edi      |        extra = esi-&dwUser                           esi
    ;//          |                                                      |<----ebx*4----->|
    ;//          pEOB = esi+ebx*4                                       FILE_PIN FILE_PIN

            lea edx, [edi].group_file.dwUser    ;// load address of dwUser
            sub edx, esi            ;// subtract end of group's osc's
            neg edx                 ;// negate = extra
            mov [edi].group_file.extra, edx ;// store in file osc

            lea eax, [esi+ebx*4]    ;// determine pEOB
            mov [edi].pEOB, eax     ;// store in file header

    ;// 4) clear the FILE_DATA

        push edi
        mov ecx, ebx
        mov edi, esi
        xor eax, eax
        rep stosd
        pop edi



    ;// 5) clear the connections for all interface pins

        lea esi, [edi+SIZEOF CLOSED_GROUP_FILE_HEADER]
        ASSUME esi:PTR FILE_OSC
        xor ecx, ecx
        mov ebx, [edi].pEOB
        .WHILE esi < ebx

            .IF [esi].pBase == OFFSET osc_PinInterface

                ASSUME esi:PTR PININT_FILE
                .IF [esi].dwUser & PININT_INPUT

                    ;// input pin, clear the pPin input pin of the pinint

                    mov (FILE_PIN PTR [esi+SIZEOF PININT_FILE]).pPin, ecx

                .ELSEIF [esi].dwUser & PININT_OUTPUT

                    ;// output pin, clear the pPin outpin pin of the pinint

                    mov (FILE_PIN PTR [esi+SIZEOF PININT_FILE + SIZEOF FILE_PIN]).pPin, ecx

                .ENDIF

            .ENDIF

            FILE_OSC_TO_NEXT_OSC esi

        .ENDW

    ;// 6) that should be it

        ret

closed_group_PrepareToLoad ENDP



ASSUME_AND_ALIGN
idtable_Load PROC

    ;// register call
    ASSUME ebp:PTR LIST_CONTEXT ;// preserve
    ;// ASSUME esi:PTR OSC_OBJECT   ;// destroy
    ;// ASSUME edi:PTR OSC_BASE     ;// may destroy
    ASSUME ebx:PTR FILE_OSC     ;// may destroy
    ;// ASSUME edx:PTR FILE_HEADER  ;// may destroy

    ;// this is called from osc_Ctor
    ;// we must return 0

    ;// the id_table is stored as pairs of index,id
    ;// our task is to assign every osc, it's id
    ;// indexes are now in reverse order
    ;// things are simplified by:
    ;//     no osc is bad
    ;//     all the oscs are loaded
    ;// so we can scaan bacwards from the tail

        lea esi, [ebx+SIZEOF FILE_OSC]  ;// where to start the id table
        FILE_OSC_TO_NEXT_OSC ebx    ;// when to stop

        .REPEAT

            lodsd                   ;// get the index
            dlist_GetTail oscZ, edi, [ebp]  ;// start at the tail
            jmp L0                  ;// jmp into loop

            .REPEAT
                dlist_GetPrev oscZ, edi ;// get prev osc
            L0: dec eax             ;// decrease the index count
            .UNTIL SIGN?

            lodsd                   ;// get the id to assign
            mov [edi].id, eax       ;// send it to the osc
            hashd_Set unredo_id, eax, edi, edx  ;// assign the new pointer value, using edx as temp

        .UNTIL esi >= ebx           ;// scan until done

    ;// and that's about it

        xor eax, eax    ;// return that we DO NOT continue with osc_Ctor

        ret

idtable_Load ENDP

































;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////
;///
;///    The rest of the osc stuff
;///



comment ~ /*





;// tasks:
;//
;// must set pEOB correctly based on the file size


FILE_OSC    pBase       ;// replace
            numPins
            position
            extra
            dwUser
GROUP_FILE  pDevice
            numPin
            szName[32]
FILE_HEADER header          ;// use as new file header for context_Load
            numOsc
            settings
            pEOB            ;// set with address of pins
    FILE_OSC[],FILE_PIN[] ...
FILE_PIN
FILE_PIN


to create the new base

    we'll allocate both the object and the base in one block
    so we need to determine the sizes

        OSC_OBJECT      allocate but do not initialize, osc_Ctor can do that
        APIN[]          allocate but do not initialize, osc_Ctor can do that
        GROUP_DATA
        LIST_CONTEXT    fill in completely
        OSC_BASE    <-- dib shape to draw with, data sizes and flags
        APIN_init[] <-- must set default pheta

then: push the context
      call context_Load
      pop the context

      all done

details:

    to allocate the pins, keep two interators on the stack
    one for inputs (left, one for outputs, right)

    also keep track of the number of each

    one problem is that file data has not been loaded yet
    portions of this we need

    .............


1)  setup FILE_HEADER

2)  determine size and allocate

3)  setup OSC_BASE

4)  scan FILE_PINS, build APIN_int structs, keep track of osc size realated materials

5)  setup the file context
    push context
    call context_Load
    pop context

6)  connect pin interfaces to the group

7)  call set shape and pin layout for the context

8)  return pointer


*/ comment ~




;// we are going to build the following structure
;// and fill in what is required
;//
;// ( p = pointer o = offset )
;//
;//     p1  OSC_OBJECT      memory_Alloc
;//         APIN
;//         ...
;// o1      GROUP_DATA                  CLOSED_GROUP_DATA_MAP
;//         FILE_HEADER     .header     CLOSED_GROUP_DATA_MAP
;//         LIST_CONTEXT    .context    CLOSED_GROUP_DATA_MAP
;//     p3  OSC_BASE
;//         APIN_init
;//         ...
;//
;//     o1 = numPins << APIN_SHIFT + SIZEOF OSC_OBJECT

ASSUME_AND_ALIGN
closed_group_Ctor PROC

        ;// register call
        ASSUME ebp:PTR LIST_CONTEXT     ;// preserve
        ;// ASSUME esi:PTR OSC_OBJECT   ;// don't care
        ;// ASSUME edi:PTR OSC_BASE     ;// replace with new block
        ASSUME ebx:PTR GROUP_FILE       ;// may destroy
        ;//ASSUME edx:PTR FILE_HEADER   ;// may destroy

    ;// 1) set the file header as the pointer to the first pin in the closed group

        FILE_OSC_TO_FIRST_PIN ebx, ecx  ;// determine the pEOB
        mov [ebx].header.pEOB, ecx      ;// store in GROUP_FILE.header.pEOB
        lea edx, [ebx].header           ;// point at the file header
        push edx                        ;// store header on stack

    ;// set dwuser in the file so we build our gdi
    ;// osc_ctor will load this for us

        or [ebx].dwUser, GROUP_BUILD_DIB OR GROUP_SCAN_PINS OR GROUP_LAYOUT_CON OR UNIT_AUTO_TRACE
        ;//or app_bFlags, APP_SYNC_UNITS    ;// otherwise it won't get done

    ;// 2) size the object and allocate memory

        mov edi, [ebx].numPins          ;// get the number of pins from the file
        lea edx, [edi*4]                ;// num pins * 4
        shl edi, LOG2(SIZEOF APIN)      ;// sizeof all the APIN records
        add edi, SIZEOF OSC_OBJECT      ;// o1 = offset to data
        lea edx, [edi+edx*4] + SIZEOF CLOSED_GROUP_DATA_MAP + SIZEOF OSC_BASE
        push edi                        ;// store o1
        invoke memory_Alloc, GPTR, edx  ;// allocate the memory
        push eax                        ;// store p1

    ;// 3)  setup the base class

        ;// stack looks like this:
        ;// p1  o1  ph  ret ....
        ;// 00  04  08
        ;// eax edi

        ;// copy the template

        mov edx, edi                    ;// save o1 while we still can
        mov esi, OFFSET closed_Group    ;// point at the template
        lea edi, [edi + eax + SIZEOF CLOSED_GROUP_DATA_MAP ]    ;// edi is now osc base
        mov ecx, (OFFSET OSC_BASE.data.numPins)/4   ;// copy this many dwords

        mov (OSC_BASE PTR [edi]).display.pszDescription, OFFSET sz_closed_group_description
                                        ;// set the description of popup panel doesn't work right

        mov eax, [ebx].numPins          ;// get the number of pins from the file

        push edi    ;// edi is at p3, the base pointer
        rep movsd   ;// move the template

        ;// edi is now at base.data.numPins

    ;// stack looks like this
    ;// p3  p1  o1  ph  ret
    ;// 00  04  08  0C
    ;//         edx

        ;// set the base.data.sizes correctly

        ;// numPins     dd 0  ;// the default number of pins
        ;// numFileBytes dd 0 ;// standard number of extra file bytes required to store the object
        ;// ofsPinData  dd 0  ;// offset from start of OSC_OBJECT to the pin data
        ;// ofsOscData  dd 0  ;// offset from start of OSC_OBJECT to the osc data
        ;// oscBytes    dd 0  ;// total amount of memory that needs allocated

        stosd           ;// store number of pins

        mov eax, (OSC_BASE PTR closed_Group).data.numFileBytes
        stosd           ;// store numFileBytes

        mov eax, edx    ;// get o1
        stosd           ;// store ofsPinData
        stosd           ;// store ofsOscData

;// 4)  set the base class in the osc
;//     redundant, but we need to do this for context load
;//     or do we ???

    ;// stack looks like this
    ;// p3  p1  o1  ph  ret
    ;// 00  04  08  0C
    ;//         edx

    mov ebx, [esp+4]    ;// get the osc
    mov eax, [esp]      ;// get the base class
    mov (OSC_OBJECT PTR [ebx]).pBase, eax;// store the base

;// 5)  push the context and load it

;--------------------------------------------------------------------------------------
push ebp                                                    ;// P U S H   C O N T E X T
;--------------------------------------------------------------------------------------

    ;// stack looks like this:
    ;// ebp p3  p1  o1  ph  ret ....
    ;// 00  04  08  0C  10
    ;//     eax ebx

    mov eax, ebx            ;// xfer osc to eax

    add ebx, [esp+0Ch]      ;// add o1 to get to data map
    ASSUME ebx:PTR CLOSED_GROUP_DATA_MAP

    mov edi, [esp+10h]      ;// get the file header
    lea ebp, [ebx].context  ;// point at context we want to load

    mov [ebp].pGroup, eax   ;// set the list context.pGroup member

;// we have to turn off pRecorder because
;// at this point, we are only storing unredo_id's
;// the call to context_Load will try to record connection information as well

    push unredo_pRecorder   ;// turn off precorder
    mov unredo_pRecorder, 0

    invoke context_Load     ;// call load context

    pop unredo_pRecorder    ;// retrieve pRecorder

    ;// note: There may be a weirdness with pasting abox1 files
    ;// the problem is that group_xlate sets group.header to 'Abox',
    ;// this will correctly cause osc_Ctor to initialize def_pheta for the pins
    ;// the weirdness may be that we never shut this off
    ;// if we were to shut it off, subsequent pastes might not intialize the pins correctly
    ;// so we'd have to go and define def_pheta for every object
    ;//
    ;// for now (jan 29,2001) this will have to remain as is
    ;//
    ;// now it's later (sep 4,2001)
    ;// the fix is to set OUR header as ABox
    ;// unfortunately, we can't do that untill after the ctor is returned to
    ;// because the ctor calls here THEN loads the file data (wich contains the errant header)
    ;// the fix is in SetShape, see note001
    ;//
    ;// and later still (jan 10, 2002)
    ;// opened_group_PrepareToSave does a similar thing


;// 6)  attach all interface pins to group pins
;//         set dwUser in piniterface
;//         set dwUser in group.pPin
;//     define the apin_init's
;//     register outputs in this context's oscR list
;//     see more notes in groups.inc

    ASSUME ebx:PTR APIN         ;// ebx = the first APIN in our new object
    ASSUME ecx:PTR APIN_init    ;// ecx = the first apin_int
    ASSUME esi:PTR OSC_OBJECT   ;// esi scans our zlist (ebp is still our context)
    ASSUME edi:PTR APIN         ;// edi points at a pin on the destination pinint

    ;// stack looks like this:
    ;// ebp p3  p1  o1  ph  ret ....
    ;// 00  04  08  0C  10

    mov ebx, [esp+8]            ;// get p1 pointer to our object
    dlist_GetHead oscZ, esi, [ebp]  ;// scan the zlist using esi
    mov ecx, [esp+4]            ;// get p3, pointer to new base class
    add ebx, SIZEOF OSC_OBJECT  ;// ebx point at first pin
    add ecx, SIZEOF OSC_BASE    ;// ecx points at first APIN_init

    ASSUME esi:PTR PININT_OSC_MAP   ;// reassume so code looks prettier

    .WHILE esi      ;// scan z list

        .IF [esi].pBase == OFFSET osc_PinInterface  ;// look for pinint

            mov edx, [esi].dwUser       ;// get dwUser from pin interface

            .IF edx & PININT_IO_TEST    ;// look at dwUser for IO test

                or [esi].dwHintI, HINTI_OSC_GOT_GROUP   ;// set the GOT_GROUP bit

                ;// determine which pin to hide

                test edx, PININT_OUTPUT         ;// check for output
                lea edi, [esi].pin_I            ;// most pins are inputs
                jz J1
                lea edi, [esi].pin_O            ;// point at output
                slist_InsertHead oscR,esi,,[ebp];// register this osc as playable
                ASSUME esi:PTR PININT_OSC_MAP   ;// reassume so code looks prettier

            J1: ;// now edi points at the pin we attach and hide

                or [edi].dwStatus, PIN_HIDDEN   ;// hide the pin

                and edx, PININT_INDEX_TEST      ;// strip off the rest of the data
                shr edx, 16-LOG2(SIZEOF APIN)   ;// convert to a length of apins
                lea eax, [ebx+edx]              ;// point at the correct pin on the group
                mov [edi].dwUser, eax           ;// attach this group.pin to that pin

                IFDEF DEBUGBUILD
                cmp (APIN PTR [eax]).dwUser,0
                .IF !ZERO?
                    int 3   ;// ALREADY set !!, not supposed to happen
                .ENDIF
                ENDIF
                mov (APIN PTR [eax]).dwUser, esi;// attach that pin to this group.pin

                ;// set up apin_init

                shr edx, LOG2(SIZEOF APIN)-LOG2(SIZEOF APIN_init)

                ;// APIN_init.dwStatus
                bt [esi].dwUser, LOG2(PININT_OUTPUT);// see if pin interface is output
                mov eax, PIN_NULL           ;// set up the bare minimum
                .IF CARRY?                  ;// output bit ?
                    or eax, PIN_OUTPUT      ;// set apin_init as output
                .ENDIF
                mov [ecx+edx].dwStatus, eax ;// store results in apin_init

                ;// APIN_init.wName
                mov eax, [esi].pinint.s_name        ;// get the shortname
                mov DWORD PTR [ecx+edx].wName, eax  ;// store in apin_init

                ;// APIN_init.pName
                lea eax, [esi].pinint.l_name        ;// point at long name
                mov [ecx+edx].pName, eax            ;// store in apin_init

            .ENDIF

        .ENDIF

        dlist_GetNext oscZ, esi     ;// next osc

    .ENDW


;// 7)  call set shape and pin layout for every osc and pin
;//     this will make sure probes get connected without having to view the context

    dlist_GetHead oscZ, esi, [ebp]
    .WHILE esi

        OSC_TO_BASE esi, edi
        invoke [edi].gui.SetShape

        ITERATE_PINS

            test [ebx].dwStatus, PIN_HIDDEN
            jnz J5
            test [ebx].dwHintI, HINTI_PIN_HIDE
            jnz J5

            invoke pin_Layout_shape
        J5:

        PINS_ITERATE

        dlist_GetNext oscZ, esi

    .ENDW


;------------------------------------------------------------------------------------
    pop ebp                                                 ;// P O P   C O N T E X T
;------------------------------------------------------------------------------------

;// 8)  that just may do it

    ;// stack looks like this:
    ;// p3  p1  o1  ph  ret ....
    ;// 00  04  08  0C

    pop edi     ;// retrieve the base class we created (replaces edi)
    pop eax     ;// retrieve the osc we created (return value)
    add esp, 8  ;// cleanup o1 and ph

;// that's it

    ret         ;// return to osc_ctor

closed_group_Ctor ENDP





ASSUME_AND_ALIGN
closed_group_Dtor PROC

    ASSUME esi:PTR OSC_OBJECT
    ASSUME ebp:PTR LIST_CONTEXT

    ;// we have to dtor all our contained objects
    ;// play_status

    ;// make sure we superseed pRecording

        push unredo_pRecorder       ;// turn off recorder
        mov unredo_pRecorder, 0

    ;// free our context

        push ebp
        OSC_TO_DATA esi, ecx, CLOSED_GROUP_DATA_MAP
        lea ebp, [ecx].context

        invoke context_New

        pop ebp

    ;// free our container

        xor ecx, ecx
        or ecx, [esi].pContainer
        .IF !ZERO?
            invoke dib_Free, ecx
        .ENDIF

    ;// restore pRecorder

        pop unredo_pRecorder    ;// restore recorder

    ;// that's it

        ret

closed_group_Dtor ENDP

ASSUME_AND_ALIGN
closed_group_PrePlay PROC

    ASSUME esi:PTR OSC_OBJECT

    ;// to dothis, we push the play context
    ;// then call play_PrePlay
    ;// then pop the play context

    OSC_TO_DATA esi, ecx, CLOSED_GROUP_DATA_MAP
    lea ecx, [ecx].context
    ASSUME ecx:PTR LIST_CONTEXT

    stack_Push play_context, ecx

        play_PrePlay PROTO  ;// defined in abox_play.asm
        invoke play_PrePlay

    stack_Pop play_context, ecx

    or eax, 1   ;// always return true, or calling function will erase our data

    ret

closed_group_PrePlay ENDP

ASSUME_AND_ALIGN
closed_group_Calc   PROC

    ;// to dothis, we push the play context
    ;// then call play_Calc
    ;// then pop the play context

    ASSUME esi:PTR OSC_OBJECT

    OSC_TO_DATA esi, ecx, CLOSED_GROUP_DATA_MAP
    lea ecx, [ecx].context
    ASSUME ecx:PTR LIST_CONTEXT

    stack_Push play_context, ecx

        play_Calc PROTO     ;// defined in abox_play.asm
        invoke play_Calc

    stack_Pop play_context, ecx

    ret

closed_group_Calc ENDP





ASSUME_AND_ALIGN
closed_group_Render PROC

    ASSUME esi:PTR OSC_OBJECT

    ;// check if a portion of the osc is offscreen (in gdi coords)
    ;// if so, then we blit the mask by hand and return

        point_GetTL [esi].boundry
        mov ecx, gdi_pDib
        ASSUME ecx:PTR DIB_CONTAINER

        cmp eax, 0
        jl blit_by_hand
        cmp edx, 0
        jle blit_by_hand

        point_GetBR [esi].boundry
        cmp eax, [ecx].shape.siz.x
        jge blit_by_hand
        cmp edx, [ecx].shape.siz.y
        jl gdi_render_osc

    blit_by_hand:

        ;// BitBlt gdi_hDC, x,y,sx,sy, osc.hDC, 0,0,SRC_COPY

        pushd SRCCOPY
        pushd 0
        pushd 0

        OSC_TO_CONTAINER esi, ecx

        pushd [ecx].shape.hDC

        point_GetBR [esi].rect
        point_SubTL [esi].rect

        push edx
        push eax

        point_GetTL [esi].rect
        ;//point_Add GDI_GUTTER
        push edx
        push eax

        push gdi_hDC

        call BitBlt

        ;// turn off other render flags

        and [esi].dwHintOsc, NOT HINTOSC_RENDER_MASK OR HINTOSC_RENDER_OUT1 OR HINTOSC_RENDER_OUT2 OR HINTOSC_RENDER_OUT3

        ret


closed_group_Render ENDP



ASSUME_AND_ALIGN
closed_group_SetShape    PROC

    ;// our task here is to define our dib shape
    ;// to do this, we have to define our size

    ;// now then:
    ;//
    ;//     set shape should only be called once
    ;//     so we can very well define the pins from that ?
    ;//     then shut the flag off

comment ~ /*

    determine: in_height, out_hieght, text_height
    choose: largest

    H_in    in_height = (num_inputs-1) * pin_spacing
    H_out   out_height = (num_outputs-1) * pin_spacing
    H_text  textheight = calcrect "group" + CrLf + name + pin_spacing

    H = max of all three

       --------
    ->| Group  |
      | name   |=->
    ->|        |
       --------

    then for each side

    y0 = ( H - H_in ) / 2
    then yo iterate and assign pheta for each

*/ comment ~

    ;// 1) determine the number of inputs and outputs as H_in and H_out
    ;// 2) allocate locals and build the string
    ;// 3) define the stack variables
    ;// 4) determine the size of the object
    ;//     4a) determine the rect needed to display the text
    ;//     4b) compare with H_in and H_out, choose maximum of the three
    ;//     4c) prepare the rect for building a dib
    ;// 5) build the dib
    ;// 6) set def pheta for all pins

        PIN_SPACING = 12
        ASSUME esi:PTR OSC_OBJECT
        ASSUME ebp:PTR LIST_CONTEXT

.IF [esi].dwUser & GROUP_BUILD_DIB

;// GROUP_BUILD_DIB

    ;// 1)  determine H_in and H_out

        ;// set up some accumulators

            mov eax, PIN_SPACING
            mov ecx, -PIN_SPACING   ;// H_in
            mov edx, -PIN_SPACING   ;// H_out

        ;// scan through the pins

            ITERATE_PINS

                test [ebx].dwStatus, PIN_OUTPUT
                jnz G1
            G0: add ecx, eax
                jmp G2
            G1: add edx, eax
            G2:
            PINS_ITERATE

        ;// store the results

            push edx    ;// H_out                   ;// 04
            push ecx    ;// H_in                    ;// 08

    ;// 2)  allocate and build the string we want to display
    ;//     allocate a rect on the stack
    ;//     dtermine th rect needed to display the text

            OSC_TO_DATA esi, edi, CLOSED_GROUP_DATA_MAP

        ;// note001, ABox218, high time we set the header, see note001 above

            mov [edi].header.header, ABOX2_FILE_HEADER

        ;// push the string onto the stack

            pushd 0 ; kludge fix needed to remove
            pushd 0 ; the group prefix

            pushd DWORD PTR [edi].szName[32-04h]    ;// 0Ch
            pushd DWORD PTR [edi].szName[32-08h]    ;// 10h
            pushd DWORD PTR [edi].szName[32-0Ch]    ;// 14h
            pushd DWORD PTR [edi].szName[32-10h]    ;// 18h
            pushd DWORD PTR [edi].szName[32-14h]    ;// 1Ch
            pushd DWORD PTR [edi].szName[32-18h]    ;// 20h
            pushd DWORD PTR [edi].szName[32-1Ch]    ;// 24h
            pushd DWORD PTR [edi].szName[32-20h]    ;// 28h

        ;// prefix with Group_crlf

            ; removed in abox210

        ;// pushd 0A0D2070h ;// p crlf              ;// 2Ch
        ;// pushd 'uorG'    ;// Grou                ;// 30h

        ;// select the desired font

            GDI_DC_SELECT_FONT hFont_osc    ;// select this now

        ;// build a rectangle on the stack

            xor edx, edx    ;// clear for pushing
            mov ecx, esp    ;// save for next call

            push edx                                ;// 34h
            push edx                                ;// 38h
            push edx                                ;// 3Ch
            push edx                                ;// 40h

    ;// 3)  define the stack variables

            H_out       TEXTEQU <(DWORD PTR [esp+(SIZEOF RECT)+2Ch])>
            H_in        TEXTEQU <(DWORD PTR [esp+(SIZEOF RECT)+28h])>
            st_string   TEXTEQU <(BYTE PTR [esp+(SIZEOF RECT)])>
            st_rect     TEXTEQU <(RECT PTR [esp])>

            stack_size = 40h    ;// depth of the stack we're using

    ;// 4) determine the size of the object

        ;// 4a determine the rect needed to display the text

            or eax, -1      ;// len
            mov edx, esp    ;// pRect
            invoke DrawTextA, gdi_hDC, ecx, eax, edx, DT_CALCRECT OR DT_NOPREFIX    ;// returns height in eax
            ;//               hDC      psz  len  pRect

            mov edi, eax    ;// store the text height for later
            ASSUME edi:NOTHING

        ;// 4b) compare with H_in and H_out, choose maximum of the three
        ;//     edi has the borderless text height

            mov edx, H_out  ;// get H_out
            mov eax, H_in   ;// get H_in

            cmp edi, edx    ;// compare H_out with H_text
            mov ecx, edi    ;// xfer ecx to text
            jge J1          ;// jump if text is larger
            mov ecx, edx    ;// H_out was larger

        J1: cmp ecx, eax    ;// cmp with H_in
            jge J2          ;// jump if current is larger
            mov ecx, eax    ;// H_in was larger

        J2: add ecx, PIN_SPACING ;// add the margin

            ;// ecx has the height

        ;// 4c) prepare the rect for building a dib
        ;//     condition the rect to be (0,0,wid,hig)
        ;//     width must also be dword aligned

            ;// ecx has the height

            pop eax ;// left
            pop edx ;// top
            neg eax ;// -left
            pop ebx ;// right

            mov [esp], ecx  ;// bottom = height

            lea eax, [ebx+eax+3+PIN_SPACING]    ;// width = right - left + 3 + BORDER
            xor edx, edx            ;// clear for zeroing
            and eax, -4             ;// dword align

            push eax    ;// right = width

            push edx    ;// top = 0
            push edx    ;// left = 0

    ;// 5)  build the dib

        ;// allocate the dib and attach to object
        ;// eax has the width, ecx has the height
        ;// make sure we reallocate correctly if we're already allocoated

            or edx, [esi].pContainer
            .IF ZERO?
                mov edx, DIB_ALLOCATE_INTER
            .ENDIF

            invoke dib_Reallocate, edx, eax, ecx

        ;// attach to object

            ASSUME eax:PTR DIB_CONTAINER

            mov edx, [eax].shape.pSource    ;// get the dib source
            mov [esi].pContainer, eax       ;// store container in object
            mov [esi].pSource, edx          ;// store the source in the object
            mov ebx, eax                    ;// put container in ebx

        ;// fill and frame with appropriate colors

            mov edx, F_COLOR_GROUP_DEVICES + 04040404h  ;// frame color
            mov eax, F_COLOR_GROUP_DEVICES + F_COLOR_GROUP_LAST - 06060606h ;// back color
            invoke dib_FillAndFrame         ;// fill and frame it

            mov ebx, (DIB_CONTAINER PTR [ebx]).shape.hDC    ;// get the dc

        ;// set up the dc

            invoke SelectObject, ebx, hFont_osc ;// select the font
            invoke SetBkMode, ebx, TRANSPARENT  ;// set as transparent

            mov eax, oBmp_palette[COLOR_OSC_TEXT*4] ;// (COLOR_GROUP_DEVICES+3)*4]
            RGB_TO_BGR eax
            invoke SetTextColor, ebx, eax

            mov eax, oBmp_palette[(COLOR_GROUP_DEVICES+COLOR_GROUP_LAST-4)*4]
            RGB_TO_BGR eax
            invoke SetBkColor, ebx, eax

        ;// we want the text to be centered
        ;// since we are doing multiple lines, we can not use dt_vcenter
        ;// so we have to center it here

        ;// luckily we stored the the text height in edi
        ;// H_text = edi

        ;// top = ( H - H_text ) / 2
        ;// bot = ( H + H_text ) / 2

            mov ecx, st_rect.bottom ;// H
            lea edx, [ecx+edi]      ;// H + H_text
            neg edi                 ;// - H_text
            lea eax, [ecx+edi]      ;// H - H_text
            shr edx, 1              ;// ( H + H_text ) / 2
            shr eax, 1              ;// ( H - H_text ) / 2

        ;// we need the total height in the next section,
        ;// so we grab that here

            mov edi, ecx    ;// edi is now total height

        ;// store the new top and bottom
        ;// adjust left as required

            mov st_rect.top, eax        ;// store the new top
            mov st_rect.bottom, edx     ;// store th new bottom
        ;// add st_rect.left, PIN_SPACING/2 ;// scoot left over a little bit

        ;// draw the title on the bitmap

            lea ecx, st_string  ;// pString
            or eax, -1          ;// len
            mov edx, esp        ;// pRect
            invoke DrawTextA, ebx, ecx, eax, edx, DT_NOCLIP OR DT_CENTER OR DT_NOPREFIX
            ;//               hDC  psz  len  rect


    ;// 6) set def pheta for all pins

        ;// we're going to need two POINT iterators
        ;// we'll take over rect for this

            st_rect TEXTEQU <>

            x_in    TEXTEQU <(DWORD PTR [esp+00h])> ;// needs adjusted back
            y_in    TEXTEQU <(DWORD PTR [esp+04h])>
            x_out   TEXTEQU <(DWORD PTR [esp+08h])> ;// already correct
            y_out   TEXTEQU <(DWORD PTR [esp+0Ch])>

        ;// determine y for both sides

        ;// y_in  = ( H - H_in ) / 2
        ;// y_out = ( H - H_out ) / 2

            ;// edi still has the total height
            ;// ebx still equals pin spacing

            mov eax, H_in   ;// get H_in
            mov edx, H_out  ;// get H_out

            neg eax         ;// - H_in
            neg edx         ;// - H_out

            add eax, edi    ;// H - H_in
            add edx, edi    ;// H - H_out

            sub x_in, ebx   ;// x_in - PIN_SPACING

            shr eax, 1      ;// (H - H_in) / 2
            shr edx, 1      ;// (H - H_out) / 2

            mov y_in, eax   ;// store
            mov y_out, edx  ;// store

        ;// set up pin and apin_init iterators

            mov edi, [esi].pData
            OSC_TO_PIN_INDEX esi, ebx, 0
            add edi, SIZEOF CLOSED_GROUP_DATA_MAP+SIZEOF OSC_BASE
            ASSUME edi:PTR APIN_init

        ;// do the scan

        .WHILE ebx < [esi].pLastPin

            test [ebx].dwStatus, PIN_OUTPUT
            mov edx, PIN_SPACING
            jz J3
                fild y_out      ;// output pin
                fild x_out
                add y_out, edx
                jmp J4
            J3:
                fild y_in       ;// input pin
                fldz
                add y_in, edx
            J4:

            push edi                ;// need to save
            invoke pin_ComputePhetaFromXY   ;// call the compute function
            pop edi                 ;// retrieve

            fst  [ebx].def_pheta    ;// store in pin
            fstp [edi].def_pheta    ;// store in pin_init

            add ebx, SIZEOF APIN
            add edi, SIZEOF APIN_init

        .ENDW

    ;// that's it

        H_in    TEXTEQU <>
        H_out   TEXTEQU <>
        st_string TEXTEQU <>
        x_in    TEXTEQU <>
        y_in    TEXTEQU <>
        x_out   TEXTEQU <>
        y_out   TEXTEQU <>

        add esp, stack_size     ;// flush the stack

        mov edi, [esi].pBase

        ASSUME esi:PTR OSC_OBJECT
        ASSUME edi:PTR OSC_BASE

        and [esi].dwUser, NOT GROUP_BUILD_DIB

.ENDIF ;// GROUP_BUILD_DIB

.IF [esi].dwUser & GROUP_LAYOUT_CON

    ;// this is only hit by loading an abox1 group

    ;// we need to set pheta equal to def pheta
    ;// then make sure all get redrawn

    ITERATE_PINS

        .IF ![ebx].pheta    ;// don't bother of already set

            mov eax, [ebx].def_pheta
            mov [ebx].pheta, eax
            or [ebx].dwHintI, HINTI_PIN_PHETA_CHANGED

        .ENDIF

    PINS_ITERATE

    and [esi].dwUser, NOT GROUP_LAYOUT_CON

.ENDIF

.IF [esi].dwUser & GROUP_SCAN_PINS

    ;// GROUP_SCAN_PINS

    ;// 7)  set our pins to look like their internal status
    ;//     we assume that all the pins are attached

        ;// group.pin.dwUser has the pointer to the pin interface

        comment ~ /*

            we need to make sure the following are correct
            if they are differnt we have to make sure the osc gets invalidated correctly
            we are being called from gdi_Invalidate, so we have to set bits manually

            ALL pins

                pFShape is set
                    set the pin layout bit
                    set the do pins bit ?
                singal type is correct
                    set the pin color changed bit
                    set the do pins bit

            INPUT pins:

                logic shapes are set

            steps:

                1) scan the group pins

                2) get the pininterface pointer from dwuser

                3) determine the correct route to trace (in or out)

                4) follow the path until a non pin interface is hit
                    if multiple paths, try find a consensus ???

                    check for multiple paths ?

                5) verify pFShape
                    set if different
                6) verify signal type
                    set if different
                7) if input pin
                    verify logic or normal shape
                        set if different

        */ comment ~

        xor ecx, ecx        ;// keep clear for testing

        ITERATE_PINS        ;// scan the pins

            ;// locate the assigned pininterface

            GET_OSC_FROM edi, [ebx].dwUser  ;// get the pin interface
            ASSUME edi:PTR PININT_OSC_MAP

            ;// inputs and outputs follow different paths

            .IF !([ebx].dwStatus & PIN_OUTPUT)      ;// PIN INPUT

            ;// load the font to get from

                pushd OFFSET font_pin_slist_head

            input_again:        DEBUG_IF <!!edi>    ;// never supposed to be zero !

                ;// trace through pin interfaces output sides

                OR_GET_PIN [edi].pin_O.pPin, ecx    ;// load and test the pin
                jz K1                               ;// make sure it exists

                PIN_TO_OSC ecx, edx     ;// get the osc
                .IF [edx].pBase == OFFSET osc_PinInterface  ;// interface ??
                    mov edi, edx        ;// yep, sxfer osc to edi
                    xor ecx, ecx        ;// clear ecx
                    jmp input_again     ;// try again
                .ENDIF

                ;// state:
                ;// ecx points at the pin we want to grab settings
                ;// esi points at our osc
                ;// ebx points at our pin
                ;// edi points at the pin interface

            ;// verify that the logic shape is correct

                mov eax, [ecx].dwStatus
                invoke pin_SetInputShape

            .ELSE   ;// PIN OUTPUT

            ;// build the name shape

                pushd OFFSET font_bus_slist_head

            output_again:       DEBUG_IF <!!edi>    ;// never supposed to be zero !

                ;// trace through pin interfaces input sides

                OR_GET_PIN [edi].pin_I.pPin, ecx    ;// load and test the pin
                jz K1                               ;// make sure it exists

                PIN_TO_OSC ecx, edx     ;// get the osc
                .IF [edx].pBase == OFFSET osc_PinInterface      ;// pin interface ??
                    mov edi, edx        ;// yep, xfer osc to edi
                    xor ecx, ecx        ;// clear ecx
                    jmp output_again    ;// try again
                .ENDIF

            .ENDIF

            ;// common to both

            ;// state
            ;// ecx points at the pin we want to grab the status and shape from
            ;// esi points at our osc
            ;// ebx points at our pin
            ;// edi points at the pin interface
            ;// edx points at the font to use for the shape
            ;// [esp] has the font pointer to use

            ;// verify the units are the same

                mov eax, [ecx].dwStatus

                invoke pin_SetUnit

        K1: ;// double check the name shape

                pop edi                         ;// retrieve the font pointer
                ASSUME edi:NOTHING              ;// JIC

                PIN_TO_FSHAPE ebx, eax          ;// get our pins font shape

                GET_OSC_FROM edx, [ebx].dwUser  ;// get the pin interface
                ASSUME edx:PTR PININT_OSC_MAP

                mov eax, [eax].character        ;// get the character therin
                .IF eax != [edx].pinint.s_name  ;// compare with name in pin initerface

                    mov eax, [edx].pinint.s_name;// move eax with char to search for
                    invoke font_Locate          ;// locate the font
                    mov [ebx].pFShape, edi      ;// store in our pin

                    or [ebx].dwHintI, HINTI_PIN_UPDATE_SHAPE
                    or [esi].dwHintOsc, HINTOSC_INVAL_DO_PINS

                .ENDIF

            xor ecx, ecx        ;// clear ecx

        PINS_ITERATE


    mov edi, [esi].pBase    ;// got's to preserve this

    and [esi].dwUser, NOT GROUP_SCAN_PINS

.ENDIF

    jmp osc_SetShape        ;// exit to osc_SetShape to do the rest of the dirty work

closed_group_SetShape ENDP



ASSUME_AND_ALIGN
closed_group_Command     PROC

    ASSUME ebp:PTR LIST_CONTEXT
    ASSUME esi:PTR OSC_OBJECT
    ;// eax has the command id

    cmp eax, ID_GROUP_EDIT_VIEW
    jnz @F

    ;// for unredo, we need to supperseed the action that's currently in progress

        unredo_BeginAction UNREDO_ENTER_GROUP

    ;// then we call the common entering function

        invoke closed_group_EnterView

    ;// then we finalize the unredo record

        unredo_EndAction UNREDO_ENTER_GROUP

    ;// then exit by closing the dialog

        mov eax, POPUP_CLOSE

    ;// that's it

        ret


@@: cmp eax, OSC_COMMAND_EDIT_CHANGE
    jnz osc_Command

    ;// get the hwnd of the edit box

        invoke GetDlgItem, popup_hWnd, ecx

    ;// point at where we want the text

        OSC_TO_DATA esi, ecx, CLOSED_GROUP_DATA_MAP
        lea ecx, [ecx].szName

    ;// set the text in the group object

        WINDOW eax, WM_GETTEXT, 32, ecx

    ;// invalidate so we get a new shape

        or [esi].dwUser, GROUP_BUILD_DIB
        GDI_INVALIDATE_OSC HINTI_OSC_SHAPE_CHANGED

    ;// return what popup wants

        mov eax, POPUP_SET_DIRTY + POPUP_REDRAW_OBJECT

        ret

closed_group_Command ENDP





ASSUME_AND_ALIGN
closed_group_InitMenu    PROC

        ASSUME esi:PTR OSC_OBJECT

    ;// xfer the name to the edit box

        invoke GetDlgItem, popup_hWnd, ID_GROUP_NAME
        mov ebx, eax
        OSC_TO_DATA esi, ecx, CLOSED_GROUP_DATA_MAP
        lea ecx, [ecx].szName
        WINDOW ebx ,WM_SETTEXT,0,ecx
        EDITBOX ebx,EM_SETLIMITTEXT, 31

    ;// that it

        xor eax, eax    ;// always return zero
        ret

closed_group_InitMenu ENDP



ASSUME_AND_ALIGN
closed_group_Write   PROC

    ASSUME esi:PTR OSC_OBJECT   ;// preserve
    ASSUME edi:PTR FILE_OSC     ;// iterate as required

    ;// task:   store extra count
    ;//         store dwuser
    ;//         store all contained objects
    ;//         iterate edi as required

    ;// push the context
    ;// then call context_Save

    ;// note!   context_Save converts pointers
    ;//         this may not what we want to do
    ;//         so we need a way to stop this behaviour
    ;//         to know when to stop, we need to know if we're in paste mode

    push ebp
    push esi
    mov edx, [esi].dwUser           ;// get dword user
    add edi, OFFSET FILE_OSC.extra  ;// scoot to extra count

    OSC_TO_DATA esi, esi, CLOSED_GROUP_DATA_MAP ;// point at data

;// mov [esi].header.header, ABOX2_FILE_HEADER  ;// this doesn't always get caught by xlate

    mov eax, [esi].extra_size   ;// get the extra size
    stosd                   ;// store the extra size
    mov eax, edx            ;// load dwUser
    stosd                   ;// store dwuser

    mov ecx, (SIZEOF GROUP_DATA) / 4    ;// amount to save, does the header as well

    rep movsd               ;// save the data

    mov ebp, esi            ;// esi ended up at the list context

    sub edi, SIZEOF FILE_HEADER ;// scoot edi back to header

    mov eax, unredo_delete      ;// account for deleting a group with undo steps
    add context_group_recording, eax

    invoke context_Save ;// call the context saver

    mov eax, unredo_delete      ;// account for deleting a group with undo steps
    sub context_group_recording, eax

    pop esi     ;// retrieve esi
    pop ebp     ;// retrieve ebp

    ret ;// that's it !


closed_group_Write ENDP



ASSUME_AND_ALIGN
closed_group_AddExtraSize    PROC


    ASSUME esi:PTR OSC_OBJECT   ;// preserve
    ASSUME edi:PTR OSC_BASE     ;// preserve
    ASSUME ebx:PTR DWORD        ;// preserve
    DEBUG_IF <edi!!=[esi].pBase>

    ;// task: determine how many extra bytes this object needs
    ;//       ADD it to [ebx]
    ;//       store it in group_data.pDevice
    ;//       store the number of oscs as well

    ;// do NOT include anything but the extra count
    ;// meaning do not include the size of the common OSC_FILE header
    ;// DO include the size of dwUser

    ;// to do this, we push the context
    ;// then call context get fileSize
    ;// then pop the context
    ;// then add our size to that

    push ebp
    push esi
    push edi

    OSC_TO_DATA esi, ecx, CLOSED_GROUP_DATA_MAP

    mov edx, [ebx]              ;// get the current size

    add [ebx], SIZEOF GROUP_DATA + SIZEOF DWORD

    lea ebp, [ecx].context      ;// set the context to ourselves

    mov [ecx].extra_size, edx   ;// store current size

    mov eax, unredo_delete      ;// account for needing to store id table
    add context_group_recording, eax

    invoke context_GetFileSize

    ;// if we are storing to an undo step
    ;// we have to determine if there is an id table

    mov edx, unredo_delete      ;// unaccount for needing to store id table
    sub context_group_recording, edx

    pop edi                     ;// retrieve the base class
    pop esi                     ;// retrieve the osc pointer

    mov edx, [ebx]              ;// get the new size

    OSC_TO_DATA esi, ecx, CLOSED_GROUP_DATA_MAP

    sub edx, [ecx].extra_size   ;// subtract the old size

    mov [ecx].header.numOsc,eax ;// store the number of oscs
    mov [ecx].extra_size, edx   ;// store as object size

    pop ebp

    ret

closed_group_AddExtraSize ENDP



ASSUME_AND_ALIGN
closed_group_GetUnit PROC

        ASSUME ebp:PTR LIST_CONTEXT
        ASSUME esi:PTR OSC_OBJECT
        ASSUME ebx:PTR APIN

    ;// if the desired pin does not have an internal connection

        cmp [ebx].dwUser, 0     ;// exit if not
        je all_done             ;// carry flag will be clear

    ;// else get the units from the pin

    ;// if UNIT_AUTO_TRACE do a trace of the context

        BITR [esi].dwUser, UNIT_AUTO_TRACE
        .IF CARRY?

        ;// do internal unit_AutoTrace

            push ebp
            OSC_TO_DATA esi, ecx, CLOSED_GROUP_DATA_MAP
            lea ebp, [ecx].context
            invoke unit_AutoTrace
            pop ebp

            ;//DEBUG_IF <[esi].dwUser & UNIT_AUTO_TRACE> this was supposed to be reset

            ;// this will get turned back on
            and [esi].dwUser, NOT UNIT_AUTO_TRACE

        .ENDIF

    ;// then get unit from pin inside group

        mov ecx, [ebx].dwUser
        ASSUME ecx:PTR PININT_OSC_MAP
        .IF [ebx].dwStatus & PIN_OUTPUT
            mov eax, [ecx].pin_I.dwStatus
        .ELSE
            mov eax, [ecx].pin_O.dwStatus
        .ENDIF

        BITT eax, UNIT_AUTOED

    all_done:

        ret

closed_group_GetUnit ENDP


;////////////////////////////////////////////////////////////////////
;//
;//
;//     _SaveUndo
;//

ASSUME_AND_ALIGN
closed_group_SaveUndo   PROC

        ASSUME esi:PTR OSC_OBJECT

    ;// edx enters as either UNREDO_CONTROL_OSC or UNREDO_COMMAND
    ;// edi enters as where to store
    ;//
    ;// task:   1) save nessary data
    ;//         2) iterate edi
    ;//
    ;// may use all registers except ebp

    ;//  group does not need dwUser
    ;// save    szName db GROUP_NAME_SIZE dup(0)    ;// name of this object

        OSC_TO_DATA esi,esi, GROUP_DATA
        add esi, GROUP_DATA.szName
        mov ecx, GROUP_NAME_SIZE / 4
        rep movsd

        ret

closed_group_SaveUndo ENDP
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

ASSUME_AND_ALIGN
closed_group_LoadUndo PROC

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

        or [esi].dwUser, GROUP_BUILD_DIB
        or [esi].dwHintI, HINTI_OSC_SHAPE_CHANGED

        ;// jmp opened_group_LoadUndo   ;// bad bad bad !!! removed ABox228

        push esi

        OSC_TO_DATA esi, esi, GROUP_DATA
        mov ecx, GROUP_NAME_SIZE / 4
        add esi, GROUP_DATA.szName
        xchg esi, edi
        rep movsd

        pop esi

        ret

closed_group_LoadUndo ENDP

;//
;//
;//     _LoadUndo
;//
;////////////////////////////////////////////////////////////////////





ASSUME_AND_ALIGN

ENDIF   ;// USE_THIS_FILE


END

