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
;// groups.inc
;//
comment ~ /*

    groups

    the new group object works with the context operations

OPENED GROUPS

    oscG is used by opened groups
    pGroupObject is defined in opened_group.asm

        it states that there is an opened group, and this is where to find it
        pGroupObject will always be the last object in oscG
        meaning that group membership can be determined by testing pNextG

    opened_group_DefineG

        will determine which objects in the circuit are inside and outside of the group
        it invalidates each one
        is called from app_Sync via the APP_SYNC_GROUP bit in app_bFlags

    opened_group_PrepareToSave

        must rearrange the z list in following order

            opened group at start
            pin interfaces that are inputs, in vertical order
            pin interfaces that are outputs, in vertical order
            oscs that are inside the group
            oscs that are outside the group

        must also determine it's file data

            num oscs inside the group
            num pins inside the group

    convert to closed

CLOSED GROUPS

    the new style of closed groups uses a common set of functions
    there is no pre defined base class for this
    so we do extra work in the xlate stage to provide one
    the closed_group_template may be used to fill in most of the structure

    closed_group_SetShape does the work of defining the sizes and pin placements

    the new closed_group base class acts a LIST_CONTEXT node
    it is capable of loading a new context into either gui_ or play_
    it then relies on the normal abox operations to do the rest (useing either gui_ or play_)

    this scheme is much simpler in the big picture as we don't require duplicated functions
    just to account for grouped objects

    closed_group_Ctor has to allocate the new object
    it must also replace the base class with a new class
    these can be combined into one memory block (osc first, then base)
    when the group is deleted, the base class will be deleted as well

PININTERFACES

    when a pin interface is inside a group, one side may attach pins on the outside container
    that side of the pin interface is marked as hidden, then it's is connected as normal

    pin.pData works by passing pointers
    pin interfaces do all the work of retrieving external pointers and setting internal pointers

          /----
          |     this pin interface (an INPUT pin) must first retrieve it's group pin (pin_I.pPin)
    ex: I-|->O  which will point to a pin on the group in the parent context (also an inputpin)
          |     that pin's connection (pPin) must then be queried for both it's data,
          |     and it's dwStatus.changing. if it's not connected, then set as pNullData
          |     this data must then be placed in the pin_O side of the pin interface
          \----


      ----\
          |     this pin interface (an OUTPUT pin) must query it's pin_I.pPin to retrive a
          |     source connection inside the group. the source connection must then be queried for
    ex: O-|->I  for it's pData and dwStatus.changing. This information is then passed to the
          |     pin_O.pPin member, which is the output pin on the group in the parent context.
          |     this will then set group's outputpin.
      ----/




BUILDING A CLOSED GROUP FROM AN OPENED GROUP

    PINS

    pin interfaces must be stored in vertical order
    their dwUser bits must be set appropriately

    need x iterators

        iter_input      keeps track of input pins on the group
        iter_output     keeps track of output pins on the group

        each time an iter is hit, it must determine the pheta, short name, long name, and status


-----------------------------------------------------------------------------------------

sanity check number one

USER ACTION:    paste_file ABox1 opened group

    context_PasteFile --> file_Load --> xlate_abox1_file

        pin interfaces are converted
        opened group is translated to new the opened_group_file format

    context_PasteFile file sees OPENED_GROUP flag in header.settings

        calls closed_group_PrepareToLoad ?

        closed_GroupPrepareLoad adjusts the file to the new closed group format

            determines pins and where they go
            adds new pins
            adjust file header accordingly

    context_PasteFile -->context_Paste

    context_Paste --> file_CheckForBusProblems
    context_Paste --> file_RealizeBuffer

    file_RealizeBuffer --> osc_Ctor

        osc_Ctor see the ALLOCATES_MANUALLY flag and calls closed_group_Ctor

    closed_group_Ctor

        allocates memory for the closed_group object and the new base class

        sets up the file iterators for the new file block

            pushes the gui context
            calls file_RealizeBuffer
            pops gui_context

        restores file pointers

        scans it's private zlist

            assigns interface pins there group-->pin connections
            hides appropriate pins as well

    ---

    closed_group_SetShape

        only needs to do this once

        determines it's private dib shape based on:

            the sizeof the name
            the number of input and output pins

        scans it's pins and dtermines where they should go

        fills in the dib with the correct colors and texts


-----------------------------------------------------------------------------------------

sanity check number two

USER ACTION:    load file with an ABox1 closed group

    xlate must sort the pin iterfaces by index
    then build the new file block

    the rest proceeds like normal


-----------------------------------------------------------------------------------------

plan of attack:

    make sure we can load test_70
    this will test:

        opened_group_xlate
        pinint_xlate

    write the new closed group functionality

    try to load test_71

        this will test the newly written code

    try to paste test_70



*/ comment ~



    GROUP_NAME_SIZE equ 32  ;// 8 dwords



;// old version of group file storage, used for both opened and closed

    GROUP_FILE_old STRUCT   ;// data that gets stored in a file
                            ;// this must be in the same order as abox1
        FILE_OSC    {}  ;// standard FILE_OSC hedaer

        dwUser      dd  0   ;// group's dword user

        not_used    dd  0   ;// was pDevice or pCalc

        numOsc      dd  0   ;// number of objects in the group
        numPin      dd  0   ;// number of interface pins

        szName db GROUP_NAME_SIZE dup(0)    ;// name of this object
        displaySize POINT {};// size of the rebuilt object
        fileSize    dd  0   ;// number of extra bytes needed to store the group

    GROUP_FILE_old ENDS ;// 14 dwords

;// new version of opened group data

    GROUP_DATA STRUCT   ;// data also gets stored in a file

        extra_size  dd  0   ;//pDevice  dd  0       ;// required pointer to our h_device (H_stuff)
        numPin      dd  0       ;// number of pins
        szName db GROUP_NAME_SIZE dup(0)    ;// name of this object

        header  FILE_HEADER {}  ;// fake file header, also stores num oscs

    GROUP_DATA ENDS     ;// 14 dwords, same size as old, different order

;// the new group file struct used for opened and closed

    GROUP_FILE STRUCT

        FILE_OSC    {}  ;// standard FILE_OSC

        dwUser  dd  0   ;// dwUser for the group

        GROUP_DATA  {}  ;// regular group data

    GROUP_FILE ENDS


    IF (SIZEOF GROUP_FILE) NE (SIZEOF GROUP_FILE_old)
    .ERR <these are supposed to be the same size>
    ENDIF

;// osc_map  for opened groups

    OPENED_GROUP_MAP STRUCT

        OSC_OBJECT      {}
        GROUP_DATA      {}

    OPENED_GROUP_MAP    ENDS

;// closed groups can not use an osc map, instead they use a data map
;// which is accesed by OSC_TO_DATA and allows access to the group data and list context

    CLOSED_GROUP_DATA_MAP STRUCT

                GROUP_DATA      {}  ;// group data struct
        context LIST_CONTEXT    {}  ;// LIST_CONTEXT for editing

    CLOSED_GROUP_DATA_MAP ENDS

    ;// an OSC_BASE struct immediately follows

;// when pasteing from a file, this saves some juggleing

    CLOSED_GROUP_FILE_HEADER    STRUCT

                    FILE_HEADER {}  ;// file header from disk
        group_file  GROUP_FILE  {}  ;// osc file from opened group

    CLOSED_GROUP_FILE_HEADER    ENDS



;// flags for closed group dwUser

    GROUP_CLOSED        EQU 00000001h   ;// turned on for pasting
    GROUP_BAD           EQU 00000002h   ;// set true if this is a bad group

    GROUP_BUILD_DIB     EQU 00000004h   ;// need to rebuild the dib
    GROUP_SCAN_PINS     EQU 00000008h   ;// need to scan the pins and set the shapes
    GROUP_LAYOUT_CON    EQU 00000010h   ;// need to set pheta = def_pheta (used by xlate)

    GROUP_DO_NOT_USE    EQU 0000FF80h   ;// needed for auto units

comment ~ /*


    more notes on pin interfaces

    pinint.pin.dwuser points back at the groups pin, that's how we attach them
    group.pin[].dwUser points at the pinint INSIDE the group, that's how we
    transfer the pin settings

    use GROUP_SCAN_PINS in group.dwUser along with GDI_INVALIDATE_osc HINTI_OSC_SHAPE_CHANGED
    to make sure this happens when navigating between views

    if the size needs to change use GROUP_REBUILD_DIB and SHAPE_CHANGED

    group_Ctor will set both

*/ comment ~








;// flags for pin interface dwUser

    PININT_INPUT            equ  00000001h  ;// set if input pin
    PININT_OUTPUT           equ  00000002h  ;// set if output pin

    PININT_IO_TEST          equ  PININT_INPUT OR PININT_OUTPUT

    PININT_INDEX_TEST       equ 0FFFF0000h  ;// index is stored in high word

    ;// PININT_CLOSED       equ  00000004h  ;// set if inside a closed group

    PININT_TEST_DATA        equ 00000100h   ;// test for denormals
    PININT_TEST_CHANGE      equ 00000200h   ;// test for changing signals

    PININT_TEST_TEST        equ 00000300h

;// old version of pin interface

    PININT_FILE_old STRUCT

        FILE_OSC {}             ;// standard file osc header struct

        dwUser  dd  0   ;// see PININT_FLAGS (see above)
                                ;// when closed ....
        position    POINT   {}  ;// parking position (convert to pheta ?)
        szName      dd      0   ;// 4 chars
        dwStatus    dd      0   ;// fake APIN_init, don't need

    PININT_FILE_old ENDS

;// the new pin interface data struct

    PININT_DATA STRUCT          ;// also stored in a file

        s_name      dd  0           ;// 4 chars for the name (only 2 are used)
        not_used    dd  0
        l_name      db 32 dup (0)   ;// 32 chars for the long name

    PININT_DATA ENDS

;// the new pin int file struct

    PININT_FILE STRUCT

        FILE_OSC {}

        dwUser  dd  0

        PININT_DATA {}

    PININT_FILE ENDS

;// for navigating we define an osc map for the pin interface

    PININT_OSC_MAP  STRUCT

        OSC_OBJECT  {}
        pin_I   APIN    {}
        pin_O   APIN    {}
        pinint  PININT_DATA {}

    PININT_OSC_MAP  ENDS


;// extern defs

    EXTERNDEF closed_Group:OSC_CORE     ;// template for building new bass classes

    slist_Declare_external oscG ;//, OSC_OBJECT, pNextG

    EXTERNDEF pGroupObject:DWORD    ;// app_Sync uses this to avoid calling opened_group_DefineG


;// interface functions

    opened_group_DefineG        PROTO
    opened_group_PrepareToSave  PROTO
    closed_group_PrepareToLoad  PROTO
    closed_group_EnterView      PROTO
    closed_group_ReturnFromView PROTO
    closed_group_DisplayHeirarchy PROTO

;// opened_group_SaveUndo   PROTO   closed groups can not ! share this
;// opened_group_LoadUndo   PROTO   removed ABox 228

    pinint_Calc PROTO   ;// called by pin_unconnect

;// flag to tell group to keep label

    LABEL_KEEP_GROUP    EQU 00000001h   ;// keep this label in a group





comment ~ /*

    tasks for loading abox1 opened group as a closed group

    1)  for the entire block
        sort the pin interfaces by their index
        be sure to look at dwUser for IO options

    2)  for the group data
        rearrange the data structure as required




    to paste an opened group as a closed group

        replace opened group id as closed group base class
        determine the number of pins
        determine the number of oscs
        determine the end of the group private data  --> group.header.pEOB
        determine the extra count                    --> header.extra
        add the required number of pins
        determine the end of the file for the header --> header.pEOB


-----------------------------------------------------------------------------


    now then:

        how do internal pin interfaces know what externel pin to connect to ?

        old version used an index embedded in pininit dwUser

        new version pin interfaces expect to be able to get their group pin
        from their pPin member (assuming we look at the correct side)

        the problem is:

            WHO attaches group.pin to pinint.pin ?
            WHEN does this happen ?


    try PININT attaches to the GROUP

        1)  if pin interface has an index,
            it can attach to group by determining the group.pin
            to do this it needs to know where the group is

            there is no safe way to do this

        2)  groups could assign the pinint a pointer, saying 'I'm here'
            from that pointer, pinint can look up the pin

        3)  connection can occur during pinint_Calc
            if a required pointer is zero, then call a connect me function
            trace will not be a proble as long as the pinint is hidden

    try GROUP attaches to the PININT

        1)  group needs to locate a pointer to the correct pin

            this does not seam possible unless each pinint has some unique value

            from there the group could scan it's zlist and look for the majik value

            this is no better than assigning the pin an index


    WHERE does the index go ?

        since we are allowing straight through, a pin may have two indexes
        this is not good

        --> redo pinint_flags to disallow through connections

        then the index goes into pinint.dwUser


    STEPS:

        closed_group.Ctor, calls context_Load

        on return, all the pin interfaces will be created and connected internally
        but not be attached to the group

        since the group has already been created, we can do a search through the list,

            and assign the 'here I am pointer' to pin.dwUser
            this must be by index. otherwise closed_group_save will have to sort
            we can go further and assign the pointer itself.

            how safe is this ?

            assigning at the closed_group_Ctor would allow the pin interface to assume
            that it is connected properly

            ctor is always called when the group is created
-->         user must be prevented from deleteing the pin interface
                perhaps use the group border to show this

        WHO assigns the index ?

            either closed_group_prepare_to_load or opened_group_prepare_to_save

            WHAT_IF the file is an abox1 file ...

                abox1 had the indexes in order but did not sort the interfaces
                this may not be a problem

                abox1 also assigned the indexes at opened group prepare to save
                so that forces us to do the same ??

                having xlate sort the pins is a chore...
                the advantage is that we can move the indexer to closed_group_prepare_to_load

                is moving this really an advantage ?

                    why are we requireing the pin iterfaces be sorted ?
                    the origonal thought was simpler loading
                    this is not turning out to be the case

-->     WHO assings the index ?

            opened_group_PrepareToSave must assign the index
            it does the sort, but only as an aid to indexing

                ie: just iterate the pins and index sequentially

        WHAT_IF the pin is copied, then pasted outside the group ?

            pin interface must know enough to turn off it's closed bit and
            unhide the pin.

            how do we detect this ?

        do we actually need the pin_closed flag ??

            pin interfaces always copy pointers ....
            pin_interfaces condition the data by setting the appropriate dwstatus pin_changing

            type            source pin          dest pin
            -------------   -----------------   ------------
            OPENED          pin_I.pPin          pin_O
            CLOSED  INPUT   pin_I.dwUser.pPin   pin_O
            CLOSED OUTPUT   pin_I.pPin          pin_O.dwUser

        yes, we do need a CLOSED flag

            this can actually be the hidden flag on the pin status
            by the same token, the io bit can be the pin_output

            if pin_hidden, then is_interface .... etc

            it may be too messey to do this however,
            since pinint.dwuser already has the io bit

        SO: we will remove the CLOSED_GROUP flag and let PIN_HIDDEN do the job
            this is set by closed_group_Ctor

-->     WHO sets the closed group flag ?
        WHO resets the close flag

            when a pin interface is constructed, it should do so as un-hidden
            closed_group ctor can then hide the pin
            this will take care of the copy paste operation

        inside the file, how do we detect if a pin is input or output ?

            opened_group_prepare_to_save will set pinint_dwuser as input or output
            this is acceptable

    ------------------------------------------------------------------------------

    SO:

        pinint.dwUser has the IO bit and index

        both are asigned by opened_group_prepare_to_save

        closed_group_ctor loads the context

            pinint.ctor must be created as unhidden

        closed_group_ctor scans it's zlist

            looks for pinint.dwUser and IO_TEST

                retreives the IO bit pinint.dwUser

                hides either pin_I or pin_O

                reteives the index from pinint.dwUser

                set pin_X.dwUser as the appropriate group.pin

                sets up the apin_init struct using the attached pin

        thus: pinint's do NOT assign their group connections
              pinint does not need to know where the group is

    ------------------------------------------------------------------------------


    NOW THEN:

        closed_group_SetShape

        needs to define def_pheta for the inits and the pins
        needs to determine the size and allocate the bitmap



*/ comment ~