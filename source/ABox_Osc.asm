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
;//   ABox_osc.asm        these are the default implemenations of each OSC_BASE member
;//
;//
;// TOC
;// osc_Ctor
;// osc_Dtor
;// osc_SetShape
;// osc_Move
;// osc_Command
;// osc_Write
;// osc_Clone
;// osc_SaveUndo

;// osc_SetBadMode

OPTION CASEMAP:NONE

.586
.MODEL FLAT

        .NOLIST
        include <Abox.inc>
        include <triangles.inc>
        include <groups.inc>
        include <gdi_pin.inc>
        .LIST
        ;//.LISTALL
        ;//.LISTMACROALL



.DATA

    ;// singly linked list of all registered osc bases
    ;// see objectlist.inc for how this head is set

        slist_Declare baseB, OFFSET baseB_HEAD

    ;// see LIST_CONTEXT and context.asm for more about that heirarchy


.CODE



;///
;// D E F A U L T    O S C    M E M B E R     F U N C T I O N S
;///

;// here's what we're going to do
;// this is a general purpose function, that works for ALL osc_objects
;//
;// we'll first determine how many bytes we need
;//
;// then allocate those bytes
;//
;// in the allocated memory, we'll layout the pointer structures needed for the osc
;//
;// insert object in Z-list at the head
;// insert object in I-list at the head
;//
;// then we call the object's init function, if there is one
;//
;// then we initialize all the pins
;//
;// we return the pointer to the newly created object


ASSUME_AND_ALIGN
PROLOGUE_OFF
osc_Ctor PROC STDCALL USES esi edi pFileOsc:PTR FILE_OSC, pFileHeader:PTR FILE_HEADER, bNoPins:DWORD

;// destroys ebx

        ASSUME ebp:PTR LIST_CONTEXT

        push esi
        push edi

    ;// stack looks like this
    ;// edi     esi     ret     pFileOsc    pFileHeader bNoPins
    ;// 0       4       8       0Ch         10h         14h

        st_pFileOsc     TEXTEQU <(DWORD PTR [esp+0Ch])>
        st_pFileHeader  TEXTEQU <(DWORD PTR [esp+10h])>
        st_bNoPins      TEXTEQU <(DWORD PTR [esp+14h])>

        GET_FILE_OSC edi, st_pFileOsc
        FILE_OSC_TO_BASE edi, edi

    ;// allocate memory for the object

        .IF [edi].data.dwFlags & BASE_ALLOCATES_MANUALLY

            ;// this object needs to allocate it's own memory on the fly
            ;// for the most part because we do not know how much memory to allocate
            ;// we may not even allocate any memory at all
            ;//
            ;//     closed_group    needs to allocate it's object and the base class
            ;//                     may also recursively call context_Load
            ;//     lock list       does not allocate at all, is not even an object
            ;//     bus list        needs to allocate a bus string table, is not an object
            ;//
            ;// SO: we will call the ctor function and monitor what it returns
            ;//     if the ctor returns zero, we abort this function and assume the object is done
            ;//     if the ctor is not zero, we assume the object wants us to continue as normal

            mov ebx, st_pFileOsc
            mov edx, st_pFileHeader
            invoke [edi].core.Ctor
            xor esi, esi
            or eax, eax
            jz all_done             ;// zero means do not continue
            jmp object_is_allocated ;// otherwsie eax has the pointer to the new osc

        .ENDIF

    ;// allocate using the standard routines

        mov eax, [edi].data.oscBytes
        add eax, 3
        and eax, -4

        invoke memory_Alloc, GPTR, eax

;//     DEBUG_IF <eax==968400h>     ;// bug hunt
;//     DEBUG_IF <eax==0C17900h>

    object_is_allocated:

        GET_OSC_FROM esi, eax           ;// esi will be the osc

        mov [esi].pBase, edi            ;// set the base

    ;// set pLastPin

        mov eax, [edi].data.numPins     ;// load num pins from base class
        shl eax, APIN_SHIFT             ;// shift to an offset
        lea eax, [esi+SIZEOF OSC_OBJECT+eax];// scoot to a pointer
        mov [esi].pLastPin, eax         ;// store in osc

    ;// set the pData pointer

        mov edx, [edi].data.ofsOscData  ;// load offset from base class
        add edx, esi                    ;// convert to a pointer
        mov [esi].pData, edx            ;// store in osc

    ;// xfer our position

        GET_FILE_OSC ebx, st_pFileOsc   ;// get the passed file osc pointer
        point_Get [ebx].pos             ;// load the TL position
        point_SetTL [esi].rect          ;// store in osc position

    ;// if we're playable, register it

        .IF [edi].data.dwFlags & BASE_PLAYABLE
            slist_InsertHead oscR, esi,,[ebp]
            or app_bFlags, APP_SYNC_PLAYBUTTON
        .ENDIF

    ;// now that we use contexts, we'll insert this osc in the zlist and invalidate it

        ;// since we just created this osc, there's no way we can already be in the list
        dlist_InsertHead oscZ, esi,,[ebp]       ;// add to zlist at head

        GDI_INVALIDATE_OSC HINTI_OSC_CREATED    ;// set this so the object get initialized

    ;// state:
    ;//
    ;//     esi is OSC_OBJECT
    ;//     edi is OSC_BASE
    ;//     ebx is FILE_OSC

    ;// if we are recording, we must create and record an id

        mov ecx, unredo_pRecorder
        .IF ecx

            ASSUME ecx:PTR UNREDO_OSC_ID
            invoke unredo_assign_id
            mov [ecx].id, eax
            add ecx, SIZEOF UNREDO_OSC_ID
            mov unredo_pRecorder, ecx

            xor ecx, ecx    ;// clear for next tests

        .ENDIF

    ;// continue on and intialize the OSC_OBJECT

        xor edx, edx    ;// clear for next tests
        ;// xor ecx, ecx    ;// clear for next tests

    ;// if we have file bytes, then load them now

        or edx, st_pFileHeader          ;// loading or creating from scratch ?
        jz done_loading_from_file_1
        or ecx, [edi].data.numFileBytes ;// load and test the extra bytes
        jz done_loading_from_file_1     ;// skip if none

    loading_from_file_1:

        DEBUG_IF <ecx !< 4> ;// not supposed to happen

        mov eax, DWORD PTR [ebx+SIZEOF FILE_OSC];// we're loading from a file
        sub ecx, 4                  ;// lower the count
        mov [esi].dwUser, eax       ;// we must be storing dwUser
        jz done_loading_from_file_1 ;// jump if there are no more

    ;// load the rest of the bytes

        push edi
        push esi
        mov edi, [esi].pData                ;// load the data pointer
        lea esi, [ebx+SIZEOF FILE_OSC+4]    ;// load start of extra block
        rep movsb                           ;// xfer the data

        pop esi
        pop edi

    done_loading_from_file_1:

    ;// initialize all the pins
    ;// state:
    ;//
    ;//     esi is OSC_OBJECT
    ;//     edi is OSC_BASE

        OSC_TO_DATA esi, eax, NOTHING
        BASE_TO_LAST_PIN edi, edx
        push eax        ;// data block iterator
        push edx        ;// apin_init iterator

        st_data_iter    TEXTEQU <(DWORD PTR [esp+4])>   ;// keeps track of data blocks
        st_init_iter    TEXTEQU <(DWORD PTR [esp])>     ;// keeps track of pin init's

    ITERATE_PINS

    ;// state:
    ;//
    ;//     esi is OSC_OBJECT
    ;//     ebx is APIN
    ;//     edx is APIN_init

        sub edx, SIZEOF APIN_init   ;// iterate backwards

        mov [ebx].pObject, esi      ;// the object pointer

        mov eax, [edx].def_pheta    ;// load default pheta
        mov ecx, [edx].pName        ;// load the long name

        mov [ebx].def_pheta, eax    ;// store default pheta
        mov [ebx].pheta, eax        ;// store as pheta just in case we're loading an old file

        mov [ebx].pLName, ecx       ;// store long name

        mov eax, [edx].dwStatus     ;// load the pin status from APIN_init

        or [ebx].dwStatus, eax      ;// OR the pin status so the pin flags get maintained

        mov st_init_iter, edx       ;// store the iterator NOW

        mov eax, [ebx].dwStatus     ;// load the status from the pin (the ctor may have changed it)
        test eax, PIN_LOGIC_INPUT   ;// check if we need to assign a logic shape

        jz set_the_pin_name

            and eax, PIN_LEVEL_TEST             ;// strip out extra bits
            BITSHIFT eax, PIN_LEVEL_POS, 4      ;// turn into a dword offset
            mov eax, pin_logic_shape_table[eax] ;// load address from table
            mov [ebx].pLShape, eax              ;// store as pin's logic shape

    set_the_pin_name:

        movzx eax, [edx].wName          ;// get the name from apin_init
        test [ebx].dwStatus, PIN_OUTPUT
        lea edi, font_pin_slist_head    ;// load the head of the font list
        jz H1
        lea edi, font_bus_slist_head
    H1: invoke font_Locate              ;// call the locate/build function
        mov [ebx].pFShape, edi          ;// store pointer
        ;// BEWARE! edx just got trashed

    determine_pin_color:

        PIN_TO_UNIT_COLOR ebx, eax  ;// derive color from dwStatus

        mov [ebx].color, eax        ;// store in pin

    set_the_data_pointer:

    ;// set the initial data pointer
    ;// we do not set pData for input pins

        mov eax, [ebx].dwStatus
        bt eax, LOG2(PIN_OUTPUT)    ;// output pin ?
        jnc done_with_this_pin      ;// no need to do more if input pin
        bt eax, LOG2(PIN_NULL)      ;// pin null ?

        jc pin_null_assign          ;// set default if so

        mov eax, st_data_iter       ;// load from local
        sub eax, SAMARY_SIZE        ;// retreat to prev slot
        mov [ebx].pData, eax        ;// store in pin
        mov st_data_iter, eax       ;// store back in local
        jmp done_with_this_pin      ;// done with this pin

    pin_null_assign:    ;// this is nessesary when using multiple feedback paths
                        ;// with objects that assign pointers
        mov eax, math_pNull
        mov [ebx].pData, eax

    done_with_this_pin:

        mov edx, st_init_iter

    PINS_ITERATE

    add esp, 8      ;// clean up
    st_data_iter    TEXTEQU <>
    st_init_iter    TEXTEQU <>


    ;// now we call the osc_Init function, if any
    ;//
    ;// state:
    ;//
    ;//     esi is OSC_OBJECT

        xor eax, eax
        OSC_TO_BASE esi, edi

        .IF !([edi].data.dwFlags & BASE_ALLOCATES_MANUALLY)
            or eax, [edi].core.Ctor
            .IF !ZERO?
                mov ebx, st_pFileOsc
                mov edx, st_pFileHeader
                call eax
            .ENDIF
        .ENDIF

    ;// now we do another scan and check if we're needing to connect pins
    ;// if so, we have to scan the entire data block

    ;// state
    ;//
    ;//     esi is OSC_OBJECT

        xor edi, edi
        OR_GET_FILE_HEADER edi, st_pFileHeader
        jz all_done

    ;// state:
    ;//
    ;// ASSUME esi:PTR OSC_OBJECT   ;// esi is osc
    ;// ASSUME edi:PTR FILE_HEADER  ;// edi is file header
    comment ~ /*

        the task is:

            set the pins' pSave as the actual pin pointer
                do not adjust busses
            using the previous pSave value,
                search the all the pins in the block
                for each matching pPin value
                replace it with the new pin pointer
            transfer pheta from the file buffer to the object

    ;// task:
    ;//
    ;//     scan the entire file block
    ;//     for each osc
    ;//         for each pin in the osc
    ;//             if pPin == edx then pPin = ebx  ;// replace the pointer

    */ comment ~


    ;// there are four ways to do this
    ;// 1A) is for abox 1 files, where we do NOT xfer pheta
    ;// 2A) is for abox 2 files, where we DO xfer pheta

        GET_FILE_OSC ecx, st_pFileOsc
        OSC_TO_PIN_INDEX esi, ebx, 0    ;// ebx will iterate pins forwards
        cmp ebx, [esi].pLastPin         ;// see if there are any pins
        jae all_done

        mov edx, st_bNoPins ;// load this now

        FILE_OSC_TO_FIRST_PIN ecx       ;// ecx will iterate OUR pins in the file

        push [edi].pEOB         ;// so we know when to stop
        mov eax, [edi].header   ;// load to test for abox1 file
        FILE_HEADER_TO_FIRST_OSC edi, edi   ;// start at first osc in file
        push edi                ;// so we know where to start

        st_file_start   TEXTEQU <(DWORD PTR [esp+stack_depth*4])>
        st_file_end     TEXTEQU <(DWORD PTR [esp+4+stack_depth*4])>

        stack_depth = 0

    ;// state:
    ;//
    ;//     esi is OSC_OBJECT
    ;//     edi is the first osc in the file
    ;//     ebx iterates the osc's pins
    ;//     ecx iterate the pin's in the file
    ;//     st_file_start points at the first osc in the file
    ;//     st_file_end points at pEOB of the file
    ;//
    ;// that leaves eax, edi, and edx to play with
    ;//
    ;// there are four ways to do this in two pairs

    ;// group A: use the pin data
    ;//
    ;//     1A) is for abox 1 files
    ;//         do NOT xfer pheta
    ;//
    ;//     2A) is for abox 2 files
    ;//         DO xfer pheta

    ;// group B: do not use the pin data
    ;//
    ;//     1B) is for abox 1 files
    ;//         do NOT xfer pheta
    ;//
    ;//     2B) is for abox 2 files
    ;//         DO xfer pheta


        or edx, edx     ;// edx has bNoPins
        jnz group_B

        cmp eax, ABOX1_FILE_HEADER
        je pin_xlate_abox1A


    ;////////////////////////////////////////////////////////////////////////////
    pin_xlate_abox2A:       ;// DO xfer pheta
                            ;// do NOT adjust pPin

        .REPEAT

            mov edx, [ecx].pSave        ;// load the save pointer
            mov eax, [ecx].pheta        ;// load pheta from file block
            cmp [ecx].pPin, PIN_BUS_TEST;// check for zero or not connected
            mov [ecx].pSave, ebx        ;// always save current pointer
            mov [ebx].pheta, eax        ;// store pheta in the object
            jbe @F                      ;// jump if connection was a bus or zero
            call xlate_pin_connections  ;// call the file scanning xlating function
        @@: add ebx, SIZEOF APIN        ;// iterate the osc's pin
            add ecx, SIZEOF FILE_PIN    ;// iterate the file pin

        .UNTIL ebx >= [esi].pLastPin

        jmp done_with_pin_xlate


    ;////////////////////////////////////////////////////////////////////////////
    pin_xlate_abox1A:   ;// do not xfer pheta
                        ;// this assumes that closed groups have done their job
                            ;// esi is the osc
                            ;// ebx is the pin
                            ;// ecx iterates the file
        .REPEAT

            mov edx, [ecx].pSave    ;// load the save pointer
            mov eax, [ecx].pPin     ;// get the pPin
            mov [ecx].pSave, ebx    ;// always save current pointer

            .IF eax > PIN_BUS_TEST  ;// skip busses
                call xlate_pin_connections  ;// call the file scanning xlating function
            .ENDIF

            add ebx, SIZEOF APIN        ;// iterate the osc's pin
            add ecx, SIZEOF FILE_PIN    ;// iterate the file pin

        .UNTIL ebx >= [esi].pLastPin
        jmp done_with_pin_xlate


    ;////////////////////////////////////////////////////////////////////////////
    group_B:    ;// do not mess with pins, something else will connect them

        cmp eax, ABOX1_FILE_HEADER
        je pin_xlate_abox1B

    ;////////////////////////////////////////////////////////////////////////////
    pin_xlate_abox2:        ;// DO xfer pheta
                            ;// do NOT adjust pPin

        .REPEAT

            mov eax, [ecx].pheta        ;// load pheta from file block
            mov [ebx].pheta, eax        ;// store pheta in the object
            add ebx, SIZEOF APIN        ;// iterate the osc's pin
            add ecx, SIZEOF FILE_PIN    ;// iterate the file pin

        .UNTIL ebx >= [esi].pLastPin

    ;// jmp done_with_pin_xlate


    ;////////////////////////////////////////////////////////////////////////////
    pin_xlate_abox1B:   ;// do not xfer pheta
                        ;// this assumes that closed groups have done their job
                            ;// esi is the osc
                            ;// ebx is the pin
                            ;// ecx iterates the file
        ;// since we are in group B, this leaves us with nothing to do

    done_with_pin_xlate:

        add esp, 8  ;// clean up

all_done:

    ;// that should do it
    ;// we return the new osc pointer

        mov eax, esi

        pop edi
        pop esi

        ret 12


;//     local function

ASSUME_AND_ALIGN
xlate_pin_connections:

    stack_depth=1

    ;// state:
    ;//
    ;//     esi is OSC_OBJECT
    ASSUME edi:PTR FILE_OSC ;// edi is FILE_HEADER
    ;//     ebx is our APIN
    ;//     ecx is FILE_OSC
    ;//     edx is the previous psave value
    ;//
    ;// task:
    ;//
    ;//     scan the entire file block
    ;//     for each osc in the file
    ;//         for each pin in the osc
    ;//             if pPin == edx then pPin = ebx  ;// replace the pointer

    .REPEAT

        .IF ![edi].pBase                ;// skip bad objects
            FILE_OSC_TO_NEXT_OSC edi
            jmp done_with_pin_block_now
        .ENDIF

        FILE_OSC_BUILD_PIN_ITERATORS edi, eax

    top_of_pin_block:           ;// scan this pin block

        cmp edi, eax            ;// done yet ?
        jae done_with_pin_block ;// jump if so
        cmp [edi].pPin, edx     ;// pins match ??
        jne J1                  ;// skip if not
        mov [edi].pPin, ebx     ;// store with new value
    J1: add edi, SIZEOF FILE_PIN;// next pin
        cmp edi, eax            ;// done yet ?
        jae done_with_pin_block ;// jump if so
        cmp [edi].pPin, edx     ;// pins match ??
        jne J2                  ;// skip if not
        mov [edi].pPin, ebx     ;// store with new value
    J2: add edi, SIZEOF FILE_PIN;// next pin
        cmp edi, eax            ;// done yet ?
        jb top_of_pin_block

    done_with_pin_block:

        DEBUG_IF <edi !!= eax>  ;// supposed to be equal
        ;// mov edi, eax        ;// set edi as the next file osc

    done_with_pin_block_now:

    .UNTIL edi >= st_file_end

    mov edi, st_file_start      ;// reset edi as the first osc in the file

    retn


osc_Ctor ENDP
PROLOGUE_ON




ASSUME_AND_ALIGN
osc_Dtor PROC uses edi ebx

    ;// this is the master destructor for any osc

        ASSUME ebp:PTR LIST_CONTEXT
        ASSUME esi:PTR OSC_OBJECT

        DEBUG_IF <!!(play_status & PLAY_GUI_SYNC)>  ;// supposed to be in play wait

    ;// make sure we're not the hover

        .IF esi == osc_hover
            and app_bFlags, NOT (APP_MODE_OSC_HOVER OR APP_MODE_CON_HOVER)
            mov osc_hover, 0
        .ENDIF
        .IF esi== osc_down
            and app_bFlags, NOT (APP_MODE_MOVING_OSC OR APP_MODE_CONTROLLING_OSC )
            mov osc_down, 0
        .ENDIF

    ;// unconnect all our pins

        .IF !([ebp].gFlags & GFLAG_DOING_NEW)

            mov edi, unredo_pRecorder   ;// need to record unconnection ?
            ASSUME edi:PTR UNREDO_PIN_CONNECT

            .IF edi     ;// we are recording
                        ;// edi points at UNREDO_PIN_CONNECT

                ITERATE_PINS

                    .IF [ebx].pPin || ([ebx].dwStatus & PIN_BUS_TEST)

                        invoke pin_Unconnect    ;// un connect it, will record the connections

                        ;// before we delete this osc,
                        ;// we have to convert all the UNREDO_PIN records

                        lea ecx, [edi].con          ;// ecx will scan this block
                        mov [edi].num_pin, 0        ;// reset the pin count
                        ASSUME ecx:PTR UNREDO_PIN
                        .REPEAT

                            GET_PIN [ecx].pin, edx  ;// get the pin pointer from the unredo record
                            inc [edi].num_pin       ;// increase the number of pins in this block
                            PIN_TO_OSC edx, edx     ;// get the osc for this pin
                            mov eax, [edx].id       ;// get the id of the osc
                            sub [ecx].pin, edx      ;// subtract osc from pin to get offset
                            .IF !eax    ;// this osc doesn't have an id yet

                                push esi        ;// have to use as arg
                                mov esi, edx    ;// this is the osc
                                invoke unredo_assign_id;// assign the id
                                pop esi         ;// retrieve the osc

                            .ENDIF

                            mov [ecx].id, eax       ;// save the id
                            add ecx, SIZEOF UNREDO_PIN  ;// advance ecx

                        .UNTIL ecx >= unredo_pRecorder

                        mov edi, ecx    ;// set edi as the next record

                    .ENDIF

                    .IF ebx==pin_hover
                        mov pin_hover, 0
                    .ENDIF
                    .IF ebx==pin_down
                        mov pin_down, 0
                    .ENDIF

                PINS_ITERATE

            .ELSE   ;// no recording, don't waste time checking

                ITERATE_PINS

                    .IF [ebx].pPin || ([ebx].dwStatus & PIN_BUS_TEST)
                        invoke pin_Unconnect
                    .ENDIF
                    .IF ebx==pin_hover
                        mov pin_hover, 0
                    .ENDIF
                    .IF ebx==pin_down
                        mov pin_down, 0
                    .ENDIF

                PINS_ITERATE

            .ENDIF

        ;// erase the object if it is onscreen

            xor eax, eax
            or eax, [esi].dwHintOsc ;// load and test ON SCREEN
            .IF SIGN?               ;// ONSCREEN is the sign bit

                lea eax, [esi].boundry
                gdi_Erase_rect PROTO    ;// defined in gdi.asm
                invoke gdi_Erase_rect

            .ENDIF

        .ENDIF

    ;// if there is an dtor function, we call it

        OSC_TO_BASE esi, edi
        .IF [edi].core.Dtor
            invoke [edi].core.Dtor
        .ENDIF

    ;// if we're playable, then we resync

        .IF [edi].data.dwFlags & BASE_PLAYABLE
            or app_bFlags, APP_SYNC_PLAYBUTTON
        .ENDIF

    ;// remove ourseleves from any lists we might be in

        .IF !([ebp].gFlags & GFLAG_DOING_NEW)   ;// skip if we're trashing the whole circuit

            dlist_Remove oscZ, esi,,[ebp]

            slist_Remove oscC, esi,,,[ebp]

            clist_Remove oscS, esi,,[ebp]

            ;// oscL get special attention
            ;// make sure we never leave a single lock

            ;//xor ecx, ecx ;// abox 231 no longer needed
            clist_Remove oscL, esi,ecx,[ebp]    ;// remove the osc, keep track of previous

            ;// check if we were in the list (ecx!=0) and if ecx is the only item left

            .IF ecx && ecx == clist_Next(oscL,ecx)

                ;// there is only one item in this lock list!
                xor eax, eax
                mov clist_MRS(oscL,[ebp]), eax      ;// clear the mrs
                mov clist_Next(oscL,ecx), eax       ;// clear the next

                GDI_INVALIDATE_OSC HINTI_OSC_LOST_LOCK_SELECT OR HINTI_OSC_LOST_LOCK_HOVER, ecx ;// invalidate the osc

                or app_bFlags, APP_SYNC_LOCK        ;// tell app_Sync to take of the rest

            .ENDIF

            slist_Remove oscR, esi,,,[ebp]

            dlist_Remove oscI, esi,,[ebp]

            clist_Remove oscIC, esi,,[ebp]

            slist_Remove oscG, esi

        .ENDIF

    ;// free allocated memory

        invoke memory_Free, esi
        or app_bFlags, APP_SYNC_GROUP   ;// tell group that we've moved

    ;// that's it

        ret

osc_Dtor ENDP



;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////



ASSUME_AND_ALIGN
osc_SetShape PROC

    ASSUME esi:PTR OSC_OBJECT   ;// esi is the osc          must preserve
    ASSUME edi:PTR OSC_BASE     ;// edi is he base class    must preserve
    ;// must preserve ebx

    DEBUG_IF <edi!!=[esi].pBase>

;// DEBUG_IF <esi==569FC0h> ;// bug hunt

    ;// since this is the default member function
    ;// we have to be sure that the osc has a shape assigned
    ;// if it does not, and we're supposed to assign the default shape
    ;// then we do that

    ;// we also make sure that all the pins are assigned a container
    ;// if they are not, we throw an error

    ;// assign the container ?

        .IF ![esi].pContainer

            DEBUG_IF <[edi].data.dwFlags & BASE_BUILDS_OWN_CONTAINER>

            .IF !([edi].data.dwFlags & BASE_BUILDS_OWN_CONTAINER)

                mov ecx, [edi].display.pContainer   ;// get from base
                DEBUG_IF <!!ecx>                    ;// pContainer was not defined in base class
                mov [esi].pContainer, ecx           ;// store in object

            .ENDIF

        .ELSE
            OSC_TO_CONTAINER esi, ecx
        .ENDIF

        DEBUG_IF <!!([ecx].shape.dwFlags & SHAPE_INITIALIZED)>  ;// container was not initialized

        DEBUG_IF<!![ecx].shape.pMask>   ;// masker not built
        DEBUG_IF<!![ecx].shape.pOut1>   ;// out1 not built
        DEBUG_IF<!![ecx].shape.pOut2>   ;// out2 not built
        DEBUG_IF<!![ecx].shape.pOut3>   ;// out3 not built

    ;// check pSource, ignore if something else already set it

        .IF ![esi].pSource
            mov eax, [edi].display.pSource
            DEBUG_IF <!!eax>
            mov [esi].pSource, eax
        .ENDIF

    ;// verify that pins have logic shapes ??

    ;// set the osc's rect

        point_Get   [ecx].shape.siz
        point_AddTL [esi].rect
        point_SetBR [esi].rect

    ;// that should do it

        ret

osc_SetShape ENDP


;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
osc_Move PROC

    ;// this central function takes care of moving oscs
    ;// it also takes care of updating the pin positions without requiring a relayout
    ;// this should only be called when we are moving an object
    ;// mouse_delta is assumed to have the offset to move

        ASSUME esi:PTR OSC_OBJECT   ;// esi must be the osc, preserved
        ASSUME ebp:PTR LIST_CONTEXT ;// preserved
        ;// ebx will be destroyed

    ;// load mouse delta

        point_Get mouse_delta
        fild mouse_delta.x  ;// dx
        fild mouse_delta.y  ;// dy dx

    ;// move osc.rect

        point_AddToTL [esi].rect
        point_AddToBR [esi].rect

    ;// move the pins

    ;// the correct way to do this is:
    ;//     move t0 and E
    ;//     HINTI_OSC_MOVED will do the rest
    ;//

    ;// if we are moving the screen, we have to tell the pin to layout it's points
    ;// the previous way was to kill the DEST_VALID bit
    ;// the new way will need to do a seperate loop

        mov ecx, app_bFlags
        test ecx, APP_MODE_MOVING_SCREEN

    .IF ZERO?   ;// NOT moving screen

        ITERATE_PINS

            fld [ebx].E.x   ;// ex  dy  dx
            fadd st, st(2)  ;// Ex  dy  dx
            fld [ebx].E.y   ;// ey  Ex  dy  dx
            fadd st, st(2)  ;// Ey  Ex  dy  dx
            fxch            ;// Ex  Ey  dy  dx

            fstp [ebx].E.x  ;// Ey  dy  dx

            point_AddTo [ebx].t0

            fstp [ebx].E.y  ;// Fx  Fy  dy  dx

        PINS_ITERATE

        ;// redefine the group

        or app_bFlags, APP_SYNC_GROUP

        ;// make sure we set the osc as moved

        GDI_INVALIDATE_OSC HINTI_OSC_MOVED

        ;// now we check the extents

        mov ecx, APP_SYNC_EXTENTS   ;// get the flag as a register
        test app_bFlags, ecx        ;// don't do twice
        jnz all_done

        test [esi].dwHintOsc, HINTOSC_STATE_SETS_EXTENTS;// see if this is an extent setting object
        jnz set_extent_flag                     ;// jmp if so

        ;// see if this object crosses the extents

        point_GetTL [esi].rect
        cmp eax, HScroll.dwMin
        jle set_extent_flag
        cmp edx, VScroll.dwMin
        jle set_extent_flag
        point_GetBR [esi].rect
        cmp eax, HScroll.dwMax
        jge set_extent_flag
        cmp edx, VScroll.dwMax
        jl all_done

    set_extent_flag:

        or app_bFlags, ecx          ;// set the sync extents flag

    .ELSE   ;// YES MOVING SCREEN

        mov ecx, NOT HINTPIN_STATE_VALID_DEST

        ITERATE_PINS

            fld [ebx].E.x   ;// ex  dy  dx
            fadd st, st(2)  ;// Ex  dy  dx
            fld [ebx].E.y   ;// ey  Ex  dy  dx
            fadd st, st(2)  ;// Ey  Ex  dy  dx
            fxch            ;// Ex  Ey  dy  dx

            and [ebx].dwHintPin, ecx

            fstp [ebx].E.x  ;// Ey  dy  dx

            point_AddTo [ebx].t0

            fstp [ebx].E.y  ;// Fx  Fy  dy  dx

        PINS_ITERATE

    .ENDIF

    all_done:

        fstp st
        fstp st

    ;// that should be it

        ret

osc_Move ENDP




;///////////////////////////////////////////////////////////////////////////
;//
;//                     called from popup_Command
;//     osc_Command     or jumped to from an osc that got there first
;//                     or called via wm_keydown
ASSUME_AND_ALIGN
osc_Command PROC PUBLIC

    ASSUME ebp:PTR LIST_CONTEXT ;// must be a valid list context
    ASSUME esi:PTR OSC_OBJECT   ;// preserve

;// ASSUME edi:PTR OSC_BASE     ;// may destroy
;// DEBUG_IF <edi!!=[esi].pBase>

    ;// eax is the command


;// COMMAND_DELETE

    cmp eax, COMMAND_DELETE
    jnz @F

    ;// make sure we cannot delete pin interfaces in closed groups

        .IF [esi].pBase == OFFSET osc_PinInterface  &&  app_bFlags & APP_MODE_IN_GROUP

            test [esi].dwHintOsc, HINTOSC_STATE_HAS_GROUP
            mov eax, POPUP_CLOSE
            jnz all_done

        .ENDIF

        .IF [esi].pBase == OFFSET opened_Group
            invoke InvalidateRect, hMainWnd, 0, 1
        .ENDIF

    ;// clear the sel list, then select the osc in question

        invoke context_UnselectAll
        clist_Insert oscS, esi,,[ebp]

    ;// begin the undo step, popup will close it

        unredo_BeginAction UNREDO_DEL_OSC

    ENTER_PLAY_SYNC GUI
        mov eax, popup_Object   ;// for keyboard commands this will be 0
        mov popup_bDelete, eax  ;// set this so popup knows how to close
        invoke osc_Dtor         ;// call the dtor
    LEAVE_PLAY_SYNC GUI
        mov eax, POPUP_CLOSE
        jmp all_done

;// COMMAND_CLONE

@@: cmp eax, COMMAND_CLONE
    jnz @F

        invoke osc_Clone    ;// , esi
        mov eax, POPUP_CLOSE
        jmp all_done

;// COMMAND_SELECT

@@: cmp eax, VK_SHIFT   ;// COMMAND_SELECT
    jnz @F

        .IF [esi].dwHintOsc & HINTOSC_STATE_HAS_SELECT
            mov eax, POPUP_IGNORE
            jmp all_done
        .ENDIF
        clist_Insert oscS, esi,, [ebp]
        mov eax, POPUP_IGNORE
        GDI_INVALIDATE_OSC HINTI_OSC_GOT_SELECT
        jmp all_done

;// COMMAND_UNSELECT

@@: cmp eax, VK_CONTROL ;// COMMAND_UNSELECT
    jnz @F

        .IF !([esi].dwHintOsc & HINTOSC_STATE_HAS_SELECT)
            mov eax, POPUP_IGNORE
            jmp all_done
        .ENDIF
        clist_Remove oscS, esi,,[ebp]
        mov eax, POPUP_IGNORE
        GDI_INVALIDATE_OSC HINTI_OSC_LOST_SELECT
        jmp all_done

@@: mov eax, POPUP_IGNORE
all_done:

    ret

osc_Command ENDP
;//
;//     osc_Command
;//
;//
;///////////////////////////////////////////////////////////////////////////


;////////////////////////////////////////////////////////////////////
;//
;//
;//     osc_Write
;//
ASSUME_AND_ALIGN
osc_Write PROC

    ;// this should work for all osc's
    ;// assume that enough memory has already been allocated
    ;// this is called both for file storage and copying

    ;// task:   store the osc and it's pins
    ;//         iterate edi in the process

        ASSUME esi:PTR OSC_OBJECT   ;// preserved
        ASSUME edi:PTR FILE_OSC     ;// iterated
        OSC_TO_BASE esi, ebx        ;// ebx is destroyed

    ;// setup our file header

        mov ecx, [ebx].data.numPins             ;// get number of pins
        .IF [ebx].data.ID != IDB_CLOSED_GROUP   ;// do NOT save the virtual class !!
            mov [edi].pBase, ebx                ;// store our pBase
        .ELSE
            mov [edi].pBase, OFFSET closed_Group;// save the common base class instead !!
        .ENDIF
        mov [edi].numPins, ecx      ;// store our num pins

        point_GetTL [esi].rect      ;// get our position
        point_Set [edi].pos         ;// store our position

    ;// check if there's a derived write function
    ;// if so, we call it and let it do the rest of the work

    .IF [ebx].gui.Write

        invoke [ebx].gui.Write      ;// call base class

    .ELSE   ;// store our number of extra bytes

        mov ecx, [ebx].data.numFileBytes    ;// number from base class
        mov [edi].extra, ecx                ;// store in the osc

        add edi, SIZEOF FILE_OSC    ;// adjust edi to point beyond this structure

        ;// determine how we store the extra bytes

        sub ecx, 4
        jc no_extra_data            ;// jump if lower than 4

            mov eax, [esi].dwUser   ;// have to store dwUser
            stosd

        jz no_extra_data            ;// flags are still set from previous subtraction
                                    ;// there are still more bytes to store
            push esi                ;// save esi
            mov esi, [esi].pData    ;// get the data pointer
            rep movsb               ;// move all
            pop esi                 ;// retrieve esi

    no_extra_data:

    .ENDIF


    ASSUME edi:ptr FILE_PIN             ;// now edi points at our pin table

    ;// store all the pins

        OSC_TO_PIN_INDEX esi, ebx, 0    ;// ebx iterates pins
        .WHILE ebx < [esi].pLastPin     ;// iterate until ...

            mov [edi].pSave, ebx    ;// store the pin's address
            mov eax, [ebx].dwStatus ;// load the status
            mov edx, [ebx].pheta    ;// load pheta
            and eax, PIN_BUS_TEST   ;// strip out all extra bits from status
            jnz @F                  ;// jmp if theres anything left
            mov eax, [ebx].pPin     ;// load connection or zero
        @@:
            mov [edi].pheta, edx    ;// store pheta in pNow
            mov [edi].pPin, eax     ;// store the pPin value

        ;// iterate to the next pin

            add ebx, SIZEOF APIN    ;// advance the pin pointer
            add edi, SIZEOF FILE_PIN;// advance the file_osc pointer

        .ENDW

    ;// that should do it

        ret

osc_Write ENDP




ASSUME_AND_ALIGN
osc_Clone PROC  uses ebp

        ASSUME esi:PTR OSC_OBJECT

    ;// osc clone, clones 1 object
    ;//
    ;// this is called from osc_Command, assume this is valid, or we wouldn't be here
    ;//
    ;// new method for undo redo
    ;//
    ;// clear the select list
    ;// select the osc
    ;// call context_Copy
    ;// unredo_Begin
    ;// call context_Paste
    ;// trick popup into NOT storing the resultant end popup

            stack_Peek gui_context, ebp

        ;// set this osc as the only selection

            invoke context_UnselectAll

            clist_Insert oscS, esi,,[ebp]

        ;// copy

            invoke context_Copy

        ;// start recording, but first flush any old commands we might have

            .IF esi == popup_Object
                unredo_EndAction UNREDO_COMMAND_OSC
            .ENDIF

        ;// now we can start recording

            unredo_BeginAction UNREDO_CLONE_OSC

        ;// prevent popup from calling end action

            BITR app_DlgFlags, DLG_POPUP
            adc popup_no_undo, 0

        ;// paste the newly copied file

            invoke context_Paste, file_pCopyBuffer, 0, 1

        ;// that should do it

            ret

osc_Clone  ENDP




ASSUME_AND_ALIGN
osc_SaveUndo    PROC

    ASSUME esi:PTR OSC_OBJECT

    ;// edx enters as either UNREDO_CONTROL_OSC or UNREDO_COMMAND
    ;// edi enters as where to store
    ;//
    ;// task:   1) save nessary data
    ;//         2) iterate edi
    ;//
    ;// may use all registers except ebp

    ;// use this function when all that is required is to save dwUser

        mov eax, [esi].dwUser
        stosd

        ret


osc_SaveUndo ENDP



ASSUME_AND_ALIGN
PROLOGUE_OFF
osc_SetBadMode PROC STDCALL bBad:DWORD

    ;// uses eax

        ASSUME esi:PTR OSC_OBJECT
        ASSUME ebp:PTR LIST_CONTEXT

    ;// setting good or bad ?

        dec DWORD PTR [esp+4]
        js set_good_mode

    set_bad_mode:

        ;// are we bad now ?
        test [esi].dwHintOsc, HINTOSC_STATE_HAS_BAD
        jnz all_done

        ;// are we scheduled to be bad ?
        test [esi].dwHintI, eax
        mov eax, HINTI_OSC_GOT_BAD
        jnz all_done
        jmp invalidate_the_osc

    ALIGN 16
    set_good_mode:

        ;// are we scheduled to be good ?
        mov eax, HINTI_OSC_LOST_BAD
        test [esi].dwHintI, eax
        jnz all_done

        ;// are we good now ?
        test [esi].dwHintOsc, HINTOSC_STATE_HAS_BAD
        jz all_done

    ALIGN 16
    invalidate_the_osc:

        or [esi].dwHintI, eax

        dlist_IfMember_jump oscI,esi,all_done,ebp
        dlist_InsertTail oscI, esi,,ebp

    ALIGN 16
    all_done:

        ret 4

osc_SetBadMode ENDP
PROLOGUE_ON



ASSUME_AND_ALIGN
END

