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
;//     hidusage.asm        implementation of the usage tables
;//

OPTION CASEMAP:NONE
.586
.MODEL FLAT

;// TOC
;//
;// private
;//     hidusage_find_usage_page    PROC    ;// ret ret usagepage
;//     find_usage_table            PROC    ;// ret ret usagepage
;//     search_through_tables       PROC
;//
;// public
;//     hidusage_GetPageString      PROC STDCALL dwPageUsage:DWORD, pBuffer:DWORD
;//     hidusage_GetUsageString     PROC STDCALL dwPageUsage:DWORD, pBuffer:DWORD
;//     hidusage_GetShortString     PROC STDCALL dwPageUsage:DWORD, pBuffer:DWORD

        .NOLIST
        INCLUDE utility.inc
        INCLUDE hidusage.inc
        INCLUDE win32A_imp.inc
        .LIST


;//////////////////////////////////
;//                             ;//
;//     !!! IMPORTANT !!!       ;//
                                ;//
        PROLOGUE_OFF            ;// for the entire file
                                ;//
;//     !!! IMPORTANT !!!       ;//
;//                             ;//
;//////////////////////////////////



comment ~ /*

    this is somewhat of a mess
    there are a lot of strings we want to get to in a reasonable amount of time
    and we really don't want to use a lot of space for these

    so we have a great number of USAGE_TABLE entries
    they are organized into groups
    there is a _UT_ macro that keeps track of how many in each group
    in that way we can linearly approximate where to start searching

    after all the tables is an array of USAGE_PAGE_TABLE entries
    each entry may point at a USAGE_TABLE

    some USAGE_TABLES are really format strings, check the flags to be sure

CONVENTIONS

    we may be asked for a usage page name

        return the string for that page, or 'Unknown' if not found

    we may be asked for a usage on a particular page

        return the string from USAGE_PAGE if found
        if not found, return the usage page name suffixed by the hex index
        if the page is also unknown, just return unknown


the tables were copied from

    from hut1_11.pdf

    HID Usage Tables
    6/27/2001
    Version 1.11
    Universal Serial Bus (USB)

    @1996-2001 USB Implementers’ Forum—All rights reserved.


*/ comment ~



    ;// the USAGE_MINIMUM struct
    ;// just a holder for a WORD so we can use common search routines

        USAGE_MINIMUM STRUCT
            wMin    dw  0
        USAGE_MINIMUM ENDS


    ;// the USAGE_TABLE stuct

        USAGE_TABLE STRUCT

            USAGE_MINIMUM {};// min low word for this entry
            wType   dw  0   ;// see SLIGHT_COMPRESSION below, also see HAS_SHORT_NAME
            pszName dd  0   ;// ptr to string name

        USAGE_TABLE ENDS    ;// size = 8

        ;// each array is preceeded and followed by a dword terminator who's value = 0FFFFFFFFh
        ;// if  wMin <= search_value < next.dwMin then we have found the entry

    ;// _UT_ macro to keep track of numbers

        _UT_ MACRO _num:REQ, _min:REQ, _flags, _string

                USAGE_TABLE { {_min},_flags,_string }

                NUM_USAGE_TABLE_&_num = NUM_USAGE_TABLE_&_num + 1
                LAST_USAGE_TABLE_&_num = _min

                ENDM

        ;// NUM_USAGE_TABLE_X is the number of entries in the table
        ;// MAX_USAGE_TABLE_X is the highest assigned min
        ;// taken together we can linearly interpolate where to start the search


    ;// the USAGE_PAGE_TABLE stuct

        USAGE_PAGE_TABLE STRUCT
            USAGE_MINIMUM {};// min page value
            wNum    dw  0   ;// if has table, this is the number of entries
            wLast   dw  0   ;// if has table, this is the min number of the last entry
            wFlags  dw  0   ;// flags ?...
            pTable  dd  0   ;// non zero if has table, ptr to a USAGE_PAGE array
            pszName dd  0   ;// ptr to the name of this page
        USAGE_PAGE_TABLE ENDS

    ;// macro to define them

        _UPT_ MACRO _min:REQ, _num,_flags, _string

            IFNB <_num>

                USAGE_PAGE_TABLE { {_min},NUM_USAGE_TABLE_&_num,LAST_USAGE_TABLE_&_num,_flags,up_&_num,_string }

            ELSE

                USAGE_PAGE_TABLE { {_min},,,,,_string }

            ENDIF

            NUM_USAGE_PAGE_TABLE = NUM_USAGE_PAGE_TABLE + 1

            ENDM



comment ~ /*

    SLIGHT_COMPRESSION

        USAGE_TABLE.wFlags tells us how to process the pszName entry
        if flags are set, some number of first characters in the pszName string
        are really indexes into the format_string_table[]

*/ comment ~

        IS_TEXT_STRING  EQU 0000h

            ;// default value
            ;// just copy the string verbatim

        IS_FMT_ORDINAL  EQU 0001h

            ;// first char is index, arg for fmt is the usage value
            ;// EX:     sprintf(buf,"Button %i",index);

        IS_FMT_PREFIX   EQU 0002h
            ;// first char is format_string_table,
            ;// followed by the string arg for the format
            ;// EX: sprintf(buf,"Keyboard %s","a and A" ) ;


        LAST_IS_FMT_TYPE EQU 0002h  ;// to prevent jmp table problems

        FORMAT_TEST     EQU 000Fh   ;// keep these bits clear !!




;///////////////////////////////////////////////////////////////////////
;//
;//
;//     short name flags

    HAS_SHORT_NAME      EQU 8000h   ;// one or two chars
    SHORT_IS_INDEXED    EQU 4000h   ;// one char + an index


.DATA


;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
;///
;/// USAGE TABLES
;///


;// USAGE TABLE 1

    dd -1   ;// terminator


up_1 LABEL USAGE_TABLE

    NUM_USAGE_TABLE_1 = 0

    _UT_ 1, 00000h,,sz_Undefined
    _UT_ 1, 00001h,,sz_Pointer
    _UT_ 1, 00002h,,sz_Mouse
    _UT_ 1, 00003h,,sz_Reserved
    _UT_ 1, 00004h,,sz_Joystick
    _UT_ 1, 00005h,,sz_Game_Pad
    _UT_ 1, 00006h,,sz_Keyboard
    _UT_ 1, 00007h,,sz_Keypad
    _UT_ 1, 00008h,,sz_Multi_axis_Controller
    _UT_ 1, 00009h,,sz_Reserved
    _UT_ 1, 00030h,HAS_SHORT_NAME,sz_X_Axis
    _UT_ 1, 00031h,HAS_SHORT_NAME,sz_Y_Axis
    _UT_ 1, 00032h,HAS_SHORT_NAME,sz_Z_Axis
    _UT_ 1, 00033h,HAS_SHORT_NAME,sz_Rx_Axis
    _UT_ 1, 00034h,HAS_SHORT_NAME,sz_Ry_Axis
    _UT_ 1, 00035h,HAS_SHORT_NAME,sz_Rz_Axis
    _UT_ 1, 00036h,HAS_SHORT_NAME,sz_Slider
    _UT_ 1, 00037h,HAS_SHORT_NAME,sz_Dial
    _UT_ 1, 00038h,HAS_SHORT_NAME,sz_Wheel
    _UT_ 1, 00039h,HAS_SHORT_NAME,sz_Hat_switch
    _UT_ 1, 0003Ah,,sz_Counted_Buffer
    _UT_ 1, 0003Bh,,sz_Byte_Count
    _UT_ 1, 0003Ch,,sz_Motion_Wakeup
    _UT_ 1, 0003Dh,,sz_Start
    _UT_ 1, 0003Eh,,sz_Select
    _UT_ 1, 0003Fh,,sz_Reserved
    _UT_ 1, 00040h,HAS_SHORT_NAME,sz_Vector_Vx
    _UT_ 1, 00041h,HAS_SHORT_NAME,sz_Vector_Vy
    _UT_ 1, 00042h,HAS_SHORT_NAME,sz_Vector_Vz
    _UT_ 1, 00043h,HAS_SHORT_NAME,sz_Vector_Vbrx
    _UT_ 1, 00044h,HAS_SHORT_NAME,sz_Vector_Vbry
    _UT_ 1, 00045h,HAS_SHORT_NAME,sz_Vector_Vbrz
    _UT_ 1, 00046h,HAS_SHORT_NAME,sz_Vector_Vno
    _UT_ 1, 00047h,,sz_Feature_Notification
    _UT_ 1, 00048h,,sz_Reserved
    _UT_ 1, 00080h,IS_FMT_PREFIX,fmt_sz_System_Control
    _UT_ 1, 00081h,IS_FMT_PREFIX,fmt_sz_System_Power_Down
    _UT_ 1, 00082h,IS_FMT_PREFIX,fmt_sz_System_Sleep
    _UT_ 1, 00083h,IS_FMT_PREFIX,fmt_sz_System_Wake_Up
    _UT_ 1, 00084h,IS_FMT_PREFIX,fmt_sz_System_Context_Menu
    _UT_ 1, 00085h,IS_FMT_PREFIX,fmt_sz_System_Main_Menu
    _UT_ 1, 00086h,IS_FMT_PREFIX,fmt_sz_System_App_Menu
    _UT_ 1, 00087h,IS_FMT_PREFIX,fmt_sz_System_Menu_Help
    _UT_ 1, 00088h,IS_FMT_PREFIX,fmt_sz_System_Menu_Exit
    _UT_ 1, 00089h,IS_FMT_PREFIX,fmt_sz_System_Menu_Select
    _UT_ 1, 0008Ah,IS_FMT_PREFIX,fmt_sz_System_Menu_Right
    _UT_ 1, 0008Bh,IS_FMT_PREFIX,fmt_sz_System_Menu_Left
    _UT_ 1, 0008Ch,IS_FMT_PREFIX,fmt_sz_System_Menu_Up
    _UT_ 1, 0008Dh,IS_FMT_PREFIX,fmt_sz_System_Menu_Down
    _UT_ 1, 0008Eh,IS_FMT_PREFIX,fmt_sz_System_Cold_Restart
    _UT_ 1, 0008Fh,IS_FMT_PREFIX,fmt_sz_System_Warm_Restart
    _UT_ 1, 00090h,HAS_SHORT_NAME,sz_D_pad_Up
    _UT_ 1, 00091h,HAS_SHORT_NAME,sz_D_pad_Down
    _UT_ 1, 00092h,HAS_SHORT_NAME,sz_D_pad_Right
    _UT_ 1, 00093h,HAS_SHORT_NAME,sz_D_pad_Left
    _UT_ 1, 00094h,,sz_Reserved
    _UT_ 1, 000A0h,IS_FMT_PREFIX,fmt_sz_System_Dock
    _UT_ 1, 000A1h,IS_FMT_PREFIX,fmt_sz_System_Undock
    _UT_ 1, 000A2h,IS_FMT_PREFIX,fmt_sz_System_Setup
    _UT_ 1, 000A3h,IS_FMT_PREFIX,fmt_sz_System_Break
    _UT_ 1, 000A4h,IS_FMT_PREFIX,fmt_sz_System_Debugger_Break
    _UT_ 1, 000A5h,,sz_Application_Break
    _UT_ 1, 000A6h,,sz_Application_Debugger_Break
    _UT_ 1, 000A7h,IS_FMT_PREFIX,fmt_sz_System_Speaker
    _UT_ 1, 000A8h,IS_FMT_PREFIX,fmt_sz_System_Hibernate
    _UT_ 1, 000A9h,,sz_Reserved
    _UT_ 1, 000B0h,IS_FMT_PREFIX,fmt_sz_System_Display_Invert
    _UT_ 1, 000B1h,IS_FMT_PREFIX,fmt_sz_System_Display_Internal
    _UT_ 1, 000B2h,IS_FMT_PREFIX,fmt_sz_System_Display_External
    _UT_ 1, 000B3h,IS_FMT_PREFIX,fmt_sz_System_Display_Both
    _UT_ 1, 000B4h,IS_FMT_PREFIX,fmt_sz_System_Display_Dual
    _UT_ 1, 000B5h,IS_FMT_PREFIX,fmt_sz_System_Display_Toggle_Intslash_Ext
    _UT_ 1, 000B6h,IS_FMT_PREFIX,fmt_sz_System_Display_Swap
    _UT_ 1, 000B7h,IS_FMT_PREFIX,fmt_sz_System_Display_LCD_Autoscale
    _UT_ 1, 000B8h,,sz_Reserved

    dd -1   ;// terminator

;// USAGE TABLE 2

up_2 LABEL USAGE_TABLE

    NUM_USAGE_TABLE_2 = 0

    _UT_ 2, 00000h,,sz_Undefined
    _UT_ 2, 00001h,,sz_Flight_Simulation_Device
    _UT_ 2, 00002h,,sz_Automobile_Simulation_Device
    _UT_ 2, 00003h,,sz_Tank_Simulation_Device
    _UT_ 2, 00004h,,sz_Spaceship_Simulation_Device
    _UT_ 2, 00005h,,sz_Submarine_Simulation_Device
    _UT_ 2, 00006h,,sz_Sailing_Simulation_Device
    _UT_ 2, 00007h,,sz_Motorcycle_Simulation_Device
    _UT_ 2, 00008h,,sz_Sports_Simulation_Device
    _UT_ 2, 00009h,,sz_Airplane_Simulation_Device
    _UT_ 2, 0000Ah,,sz_Helicopter_Simulation_Device
    _UT_ 2, 0000Bh,,sz_Magic_Carpet_Simulation_Device
    _UT_ 2, 0000Ch,,sz_Bicycle_Simulation_Device
    _UT_ 2, 0000Dh,,sz_Reserved
    _UT_ 2, 00020h,,sz_Flight_Control_Stick
    _UT_ 2, 00021h,,sz_Flight_Stick
    _UT_ 2, 00022h,,sz_Cyclic_Control
    _UT_ 2, 00023h,,sz_Cyclic_Trim
    _UT_ 2, 00024h,,sz_Flight_Yoke
    _UT_ 2, 00025h,,sz_Track_Control
    _UT_ 2, 00026h,,sz_Reserved
    _UT_ 2, 000B0h,,sz_Aileron
    _UT_ 2, 000B1h,,sz_Aileron_Trim
    _UT_ 2, 000B2h,,sz_Anti_Torque_Control
    _UT_ 2, 000B3h,,sz_Autopilot_Enable
    _UT_ 2, 000B4h,,sz_Chaff_Release
    _UT_ 2, 000B5h,,sz_Collective_Control
    _UT_ 2, 000B6h,,sz_Dive_Brake
    _UT_ 2, 000B7h,,sz_Electronic_Countermeasures
    _UT_ 2, 000B8h,,sz_Elevator
    _UT_ 2, 000B9h,,sz_Elevator_Trim
    _UT_ 2, 000BAh,,sz_Rudder
    _UT_ 2, 000BBh,,sz_Throttle
    _UT_ 2, 000BCh,,sz_Flight_Communications
    _UT_ 2, 000BDh,,sz_Flare_Release
    _UT_ 2, 000BEh,,sz_Landing_Gear
    _UT_ 2, 000BFh,,sz_Toe_Brake
    _UT_ 2, 000C0h,,sz_Trigger
    _UT_ 2, 000C1h,,sz_Weapons_Arm
    _UT_ 2, 000C2h,,sz_Weapons_Select
    _UT_ 2, 000C3h,,sz_Wing_Flaps
    _UT_ 2, 000C4h,,sz_Accelerator
    _UT_ 2, 000C5h,,sz_Brake
    _UT_ 2, 000C6h,,sz_Clutch
    _UT_ 2, 000C7h,,sz_Shifter
    _UT_ 2, 000C8h,,sz_Steering
    _UT_ 2, 000C9h,,sz_Turret_Direction
    _UT_ 2, 000CAh,,sz_Barrel_Elevation
    _UT_ 2, 000CBh,,sz_Dive_Plane
    _UT_ 2, 000CCh,,sz_Ballast
    _UT_ 2, 000CDh,,sz_Bicycle_Crank
    _UT_ 2, 000CEh,,sz_Handle_Bars
    _UT_ 2, 000CFh,,sz_Front_Brake
    _UT_ 2, 000D0h,,sz_Rear_Brake
    _UT_ 2, 000D1h,,sz_Reserved

    dd -1   ;// terminator


;// VR Controls Page (0x03)''

up_3 LABEL USAGE_TABLE

    NUM_USAGE_TABLE_3 = 0

    _UT_ 3, 00000h,,sz_Unidentified
    _UT_ 3, 00001h,,sz_Belt
    _UT_ 3, 00002h,,sz_Body_Suit
    _UT_ 3, 00003h,,sz_Flexor
    _UT_ 3, 00004h,,sz_Glove
    _UT_ 3, 00005h,,sz_Head_Tracker
    _UT_ 3, 00006h,,sz_Head_Mounted_Display
    _UT_ 3, 00007h,,sz_Hand_Tracker
    _UT_ 3, 00008h,,sz_Oculometer
    _UT_ 3, 00009h,,sz_Vest
    _UT_ 3, 0000Ah,,sz_Animatronic_Device
    _UT_ 3, 0000Bh,,sz_Reserved
    _UT_ 3, 00020h,,sz_Stereo_Enable
    _UT_ 3, 00021h,,sz_Display_Enable
    _UT_ 3, 00022h,,sz_Reserved

    dd -1   ;// terminator


;// Sport Controls Page

up_4 LABEL USAGE_TABLE

    NUM_USAGE_TABLE_4 = 0

    _UT_ 4, 00000h,,sz_Unidentified
    _UT_ 4, 00001h,,sz_Baseball_Bat
    _UT_ 4, 00002h,,sz_Golf_Club
    _UT_ 4, 00003h,,sz_Rowing_Machine
    _UT_ 4, 00004h,,sz_Treadmill
    _UT_ 4, 00005h,,sz_Reserved
    _UT_ 4, 00030h,,sz_Oar
    _UT_ 4, 00031h,,sz_Slope
    _UT_ 4, 00032h,,sz_Rate
    _UT_ 4, 00033h,,sz_Stick_Speed
    _UT_ 4, 00034h,,sz_Stick_Face_Angle
    _UT_ 4, 00035h,,sz_Stick_Heelslash_Toe
    _UT_ 4, 00036h,,sz_Stick_Follow_Through
    _UT_ 4, 00037h,,sz_Stick_Tempo
    _UT_ 4, 00038h,,sz_Stick_Type
    _UT_ 4, 00039h,,sz_Stick_Height
    _UT_ 4, 0003Ah,,sz_Reserved
    _UT_ 4, 00050h,,sz_Putter
    _UT_ 4, 00051h,,sz_1_Iron
    _UT_ 4, 00052h,,sz_2_Iron
    _UT_ 4, 00053h,,sz_3_Iron
    _UT_ 4, 00054h,,sz_4_Iron
    _UT_ 4, 00055h,,sz_5_Iron
    _UT_ 4, 00056h,,sz_6_Iron
    _UT_ 4, 00057h,,sz_7_Iron
    _UT_ 4, 00058h,,sz_8_Iron
    _UT_ 4, 00059h,,sz_9_Iron
    _UT_ 4, 0005Ah,,sz_10_Iron
    _UT_ 4, 0005Bh,,sz_11_Iron
    _UT_ 4, 0005Ch,,sz_Sand_Wedge
    _UT_ 4, 0005Dh,,sz_Loft_Wedge
    _UT_ 4, 0005Eh,,sz_Power_Wedge
    _UT_ 4, 0005Fh,,sz_1_Wood
    _UT_ 4, 00060h,,sz_3_Wood
    _UT_ 4, 00061h,,sz_5_Wood
    _UT_ 4, 00062h,,sz_7_Wood
    _UT_ 4, 00063h,,sz_9_Wood
    _UT_ 4, 00064h,,sz_Reserved

    dd -1   ;// terminator


;// Game Controls Page

up_5 LABEL USAGE_TABLE

    NUM_USAGE_TABLE_5 = 0

    _UT_ 5, 00000h,,sz_Undefined
    _UT_ 5, 00001h,,sz_3D_Game_Controller
    _UT_ 5, 00002h,,sz_Pinball_Device
    _UT_ 5, 00003h,,sz_Gun_Device
    _UT_ 5, 00004h,,sz_Reserved
    _UT_ 5, 00020h,,sz_Point_of_View
    _UT_ 5, 00021h,,sz_Turn_Rightslash_Left
    _UT_ 5, 00022h,,sz_Pitch_Forwardslash_Backward
    _UT_ 5, 00023h,,sz_Roll_Rightslash_Left
    _UT_ 5, 00024h,,sz_Move_Rightslash_Left
    _UT_ 5, 00025h,,sz_Move_Forwardslash_Backward
    _UT_ 5, 00026h,,sz_Move_Upslash_Down
    _UT_ 5, 00027h,,sz_Lean_Rightslash_Left
    _UT_ 5, 00028h,,sz_Lean_Forwardslash_Backward
    _UT_ 5, 00029h,,sz_Height_of_POV
    _UT_ 5, 0002Ah,,sz_Flipper
    _UT_ 5, 0002Bh,,sz_Secondary_Flipper
    _UT_ 5, 0002Ch,,sz_Bump
    _UT_ 5, 0002Dh,,sz_New_Game
    _UT_ 5, 0002Eh,,sz_Shoot_Ball
    _UT_ 5, 0002Fh,,sz_Player
    _UT_ 5, 00030h,,sz_Gun_Bolt
    _UT_ 5, 00031h,,sz_Gun_Clip
    _UT_ 5, 00032h,,sz_Gun_Selector
    _UT_ 5, 00033h,,sz_Gun_Single_Shot
    _UT_ 5, 00034h,,sz_Gun_Burst
    _UT_ 5, 00035h,,sz_Gun_Automatic
    _UT_ 5, 00036h,,sz_Gun_Safety
    _UT_ 5, 00037h,,sz_Gamepad_Fireslash_Jump
    _UT_ 5, 00039h,,sz_Gamepad_Trigger
    _UT_ 5, 0003Ah,,sz_Reserved

    dd -1   ;// terminator


;// Keyboard/Keypad Page

up_7 LABEL USAGE_TABLE

    NUM_USAGE_TABLE_7 = 0

    _UT_ 7, 00000h,             ,    sz_Reserved
    _UT_ 7, 00001h,IS_FMT_PREFIX,fmt_sz_Keyboard_ErrorRollOver
    _UT_ 7, 00002h,IS_FMT_PREFIX,fmt_sz_Keyboard_POSTFail
    _UT_ 7, 00003h,IS_FMT_PREFIX,fmt_sz_Keyboard_ErrorUndefined
    _UT_ 7, 00004h,IS_FMT_PREFIX,fmt_sz_Keyboard_a_and_A
    _UT_ 7, 00005h,IS_FMT_PREFIX,fmt_sz_Keyboard_b_and_B
    _UT_ 7, 00006h,IS_FMT_PREFIX,fmt_sz_Keyboard_c_and_C
    _UT_ 7, 00007h,IS_FMT_PREFIX,fmt_sz_Keyboard_d_and_D
    _UT_ 7, 00008h,IS_FMT_PREFIX,fmt_sz_Keyboard_e_and_E
    _UT_ 7, 00009h,IS_FMT_PREFIX,fmt_sz_Keyboard_f_and_F
    _UT_ 7, 0000Ah,IS_FMT_PREFIX,fmt_sz_Keyboard_g_and_G
    _UT_ 7, 0000Bh,IS_FMT_PREFIX,fmt_sz_Keyboard_h_and_H
    _UT_ 7, 0000Ch,IS_FMT_PREFIX,fmt_sz_Keyboard_i_and_I
    _UT_ 7, 0000Dh,IS_FMT_PREFIX,fmt_sz_Keyboard_j_and_J
    _UT_ 7, 0000Eh,IS_FMT_PREFIX,fmt_sz_Keyboard_k_and_K
    _UT_ 7, 0000Fh,IS_FMT_PREFIX,fmt_sz_Keyboard_l_and_L
    _UT_ 7, 00010h,IS_FMT_PREFIX,fmt_sz_Keyboard_m_and_M
    _UT_ 7, 00011h,IS_FMT_PREFIX,fmt_sz_Keyboard_n_and_N
    _UT_ 7, 00012h,IS_FMT_PREFIX,fmt_sz_Keyboard_o_and_O
    _UT_ 7, 00013h,IS_FMT_PREFIX,fmt_sz_Keyboard_p_and_P
    _UT_ 7, 00014h,IS_FMT_PREFIX,fmt_sz_Keyboard_q_and_Q
    _UT_ 7, 00015h,IS_FMT_PREFIX,fmt_sz_Keyboard_r_and_R
    _UT_ 7, 00016h,IS_FMT_PREFIX,fmt_sz_Keyboard_s_and_S
    _UT_ 7, 00017h,IS_FMT_PREFIX,fmt_sz_Keyboard_t_and_T
    _UT_ 7, 00018h,IS_FMT_PREFIX,fmt_sz_Keyboard_u_and_U
    _UT_ 7, 00019h,IS_FMT_PREFIX,fmt_sz_Keyboard_v_and_V
    _UT_ 7, 0001Ah,IS_FMT_PREFIX,fmt_sz_Keyboard_w_and_W
    _UT_ 7, 0001Bh,IS_FMT_PREFIX,fmt_sz_Keyboard_x_and_X
    _UT_ 7, 0001Ch,IS_FMT_PREFIX,fmt_sz_Keyboard_y_and_Y
    _UT_ 7, 0001Dh,IS_FMT_PREFIX,fmt_sz_Keyboard_z_and_Z
    _UT_ 7, 0001Eh,IS_FMT_PREFIX,fmt_sz_Keyboard_1_and_exclamation
    _UT_ 7, 0001Fh,IS_FMT_PREFIX,fmt_sz_Keyboard_2_and_at
    _UT_ 7, 00020h,IS_FMT_PREFIX,fmt_sz_Keyboard_3_and_pound
    _UT_ 7, 00021h,IS_FMT_PREFIX,fmt_sz_Keyboard_4_and_dollar
    _UT_ 7, 00022h,IS_FMT_PREFIX,fmt_sz_Keyboard_5_and_percent
    _UT_ 7, 00023h,IS_FMT_PREFIX,fmt_sz_Keyboard_6_and_upcaret
    _UT_ 7, 00024h,IS_FMT_PREFIX,fmt_sz_Keyboard_7_and_ampersand
    _UT_ 7, 00025h,IS_FMT_PREFIX,fmt_sz_Keyboard_8_and_star
    _UT_ 7, 00026h,IS_FMT_PREFIX,fmt_sz_Keyboard_9_and_lparen
    _UT_ 7, 00027h,IS_FMT_PREFIX,fmt_sz_Keyboard_0_and_rparen
    _UT_ 7, 00028h,IS_FMT_PREFIX,fmt_sz_Keyboard_Return
    _UT_ 7, 00029h,IS_FMT_PREFIX,fmt_sz_Keyboard_Escape
    _UT_ 7, 0002Ah,IS_FMT_PREFIX,fmt_sz_Keyboard_Backspace
    _UT_ 7, 0002Bh,IS_FMT_PREFIX,fmt_sz_Keyboard_Tab
    _UT_ 7, 0002Ch,IS_FMT_PREFIX,fmt_sz_Keyboard_Spacebar
    _UT_ 7, 0002Dh,IS_FMT_PREFIX,fmt_sz_Keyboard_minus_and_underscore
    _UT_ 7, 0002Eh,IS_FMT_PREFIX,fmt_sz_Keyboard_equal__and_plus
    _UT_ 7, 0002Fh,IS_FMT_PREFIX,fmt_sz_Keyboard_lbracket_and_lcurly
    _UT_ 7, 00030h,IS_FMT_PREFIX,fmt_sz_Keyboard_rbracket_and_rcurly
    _UT_ 7, 00031h,IS_FMT_PREFIX,fmt_sz_Keyboard_backslash__and_pipe_
    _UT_ 7, 00032h,IS_FMT_PREFIX,fmt_sz_Keyboard_Non_US_pound__and_tilde
    _UT_ 7, 00033h,IS_FMT_PREFIX,fmt_sz_Keyboard_semicolon__and_colon
    _UT_ 7, 00034h,IS_FMT_PREFIX,fmt_sz_Keyboard_squtoe_and_dquote
    _UT_ 7, 00035h,IS_FMT_PREFIX,fmt_sz_Keyboard_lsquote_and_tilde
    _UT_ 7, 00036h,IS_FMT_PREFIX,fmt_sz_Keyboard_comma_and_lcaret_
    _UT_ 7, 00037h,IS_FMT_PREFIX,fmt_sz_Keyboard_period_and_rcaret
    _UT_ 7, 00038h,IS_FMT_PREFIX,fmt_sz_Keyboard_slash__and_question
    _UT_ 7, 00039h,IS_FMT_PREFIX,fmt_sz_Keyboard_Caps_Lock
    _UT_ 7, 0003Ah,IS_FMT_PREFIX,fmt_sz_Keyboard_F1
    _UT_ 7, 0003Bh,IS_FMT_PREFIX,fmt_sz_Keyboard_F2
    _UT_ 7, 0003Ch,IS_FMT_PREFIX,fmt_sz_Keyboard_F3
    _UT_ 7, 0003Dh,IS_FMT_PREFIX,fmt_sz_Keyboard_F4
    _UT_ 7, 0003Eh,IS_FMT_PREFIX,fmt_sz_Keyboard_F5
    _UT_ 7, 0003Fh,IS_FMT_PREFIX,fmt_sz_Keyboard_F6
    _UT_ 7, 00040h,IS_FMT_PREFIX,fmt_sz_Keyboard_F7
    _UT_ 7, 00041h,IS_FMT_PREFIX,fmt_sz_Keyboard_F8
    _UT_ 7, 00042h,IS_FMT_PREFIX,fmt_sz_Keyboard_F9
    _UT_ 7, 00043h,IS_FMT_PREFIX,fmt_sz_Keyboard_F10
    _UT_ 7, 00044h,IS_FMT_PREFIX,fmt_sz_Keyboard_F11
    _UT_ 7, 00045h,IS_FMT_PREFIX,fmt_sz_Keyboard_F12
    _UT_ 7, 00046h,IS_FMT_PREFIX,fmt_sz_Keyboard_PrintScreen
    _UT_ 7, 00047h,IS_FMT_PREFIX,fmt_sz_Keyboard_Scroll_Lock
    _UT_ 7, 00048h,IS_FMT_PREFIX,fmt_sz_Keyboard_Pause
    _UT_ 7, 00049h,IS_FMT_PREFIX,fmt_sz_Keyboard_Insert
    _UT_ 7, 0004Ah,IS_FMT_PREFIX,fmt_sz_Keyboard_Home
    _UT_ 7, 0004Bh,IS_FMT_PREFIX,fmt_sz_Keyboard_PageUp
    _UT_ 7, 0004Ch,IS_FMT_PREFIX,fmt_sz_Keyboard_Delete
    _UT_ 7, 0004Dh,IS_FMT_PREFIX,fmt_sz_Keyboard_End
    _UT_ 7, 0004Eh,IS_FMT_PREFIX,fmt_sz_Keyboard_PageDown
    _UT_ 7, 0004Fh,IS_FMT_PREFIX,fmt_sz_Keyboard_RightArrow
    _UT_ 7, 00050h,IS_FMT_PREFIX,fmt_sz_Keyboard_LeftArrow
    _UT_ 7, 00051h,IS_FMT_PREFIX,fmt_sz_Keyboard_DownArrow
    _UT_ 7, 00052h,IS_FMT_PREFIX,fmt_sz_Keyboard_UpArrow
    _UT_ 7, 00053h,IS_FMT_PREFIX,fmt_sz_Keypad_Num_Lock_and_Clear
    _UT_ 7, 00054h,IS_FMT_PREFIX,fmt_sz_Keypad_slash
    _UT_ 7, 00055h,IS_FMT_PREFIX,fmt_sz_Keypad_star
    _UT_ 7, 00056h,IS_FMT_PREFIX,fmt_sz_Keypad__
    _UT_ 7, 00057h,IS_FMT_PREFIX,fmt_sz_Keypad_plus
    _UT_ 7, 00058h,IS_FMT_PREFIX,fmt_sz_Keypad_ENTER
    _UT_ 7, 00059h,IS_FMT_PREFIX,fmt_sz_Keypad_1_and_End
    _UT_ 7, 0005Ah,IS_FMT_PREFIX,fmt_sz_Keypad_2_and_Down_Arrow
    _UT_ 7, 0005Bh,IS_FMT_PREFIX,fmt_sz_Keypad_3_and_PageDn
    _UT_ 7, 0005Ch,IS_FMT_PREFIX,fmt_sz_Keypad_4_and_Left_Arrow
    _UT_ 7, 0005Dh,IS_FMT_PREFIX,fmt_sz_Keypad_5
    _UT_ 7, 0005Eh,IS_FMT_PREFIX,fmt_sz_Keypad_6_and_Right_Arrow
    _UT_ 7, 0005Fh,IS_FMT_PREFIX,fmt_sz_Keypad_7_and_Home
    _UT_ 7, 00060h,IS_FMT_PREFIX,fmt_sz_Keypad_8_and_Up_Arrow
    _UT_ 7, 00061h,IS_FMT_PREFIX,fmt_sz_Keypad_9_and_PageUp
    _UT_ 7, 00062h,IS_FMT_PREFIX,fmt_sz_Keypad_0_and_Insert
    _UT_ 7, 00063h,IS_FMT_PREFIX,fmt_sz_Keypad_dot_and_Delete
    _UT_ 7, 00064h,IS_FMT_PREFIX,fmt_sz_Keyboard_Non_US_backslash_and_pipe
    _UT_ 7, 00065h,IS_FMT_PREFIX,fmt_sz_Keyboard_Application
    _UT_ 7, 00066h,IS_FMT_PREFIX,fmt_sz_Keyboard_Power
    _UT_ 7, 00067h,IS_FMT_PREFIX,fmt_sz_Keypad_equal
    _UT_ 7, 00068h,IS_FMT_PREFIX,fmt_sz_Keyboard_F13
    _UT_ 7, 00069h,IS_FMT_PREFIX,fmt_sz_Keyboard_F14
    _UT_ 7, 0006Ah,IS_FMT_PREFIX,fmt_sz_Keyboard_F15
    _UT_ 7, 0006Bh,IS_FMT_PREFIX,fmt_sz_Keyboard_F16
    _UT_ 7, 0006Ch,IS_FMT_PREFIX,fmt_sz_Keyboard_F17
    _UT_ 7, 0006Dh,IS_FMT_PREFIX,fmt_sz_Keyboard_F18
    _UT_ 7, 0006Eh,IS_FMT_PREFIX,fmt_sz_Keyboard_F19
    _UT_ 7, 0006Fh,IS_FMT_PREFIX,fmt_sz_Keyboard_F20
    _UT_ 7, 00070h,IS_FMT_PREFIX,fmt_sz_Keyboard_F21
    _UT_ 7, 00071h,IS_FMT_PREFIX,fmt_sz_Keyboard_F22
    _UT_ 7, 00072h,IS_FMT_PREFIX,fmt_sz_Keyboard_F23
    _UT_ 7, 00073h,IS_FMT_PREFIX,fmt_sz_Keyboard_F24
    _UT_ 7, 00074h,IS_FMT_PREFIX,fmt_sz_Keyboard_Execute
    _UT_ 7, 00075h,IS_FMT_PREFIX,fmt_sz_Keyboard_Help
    _UT_ 7, 00076h,IS_FMT_PREFIX,fmt_sz_Keyboard_Menu
    _UT_ 7, 00077h,IS_FMT_PREFIX,fmt_sz_Keyboard_Select
    _UT_ 7, 00078h,IS_FMT_PREFIX,fmt_sz_Keyboard_Stop
    _UT_ 7, 00079h,IS_FMT_PREFIX,fmt_sz_Keyboard_Again
    _UT_ 7, 0007Ah,IS_FMT_PREFIX,fmt_sz_Keyboard_Undo
    _UT_ 7, 0007Bh,IS_FMT_PREFIX,fmt_sz_Keyboard_Cut
    _UT_ 7, 0007Ch,IS_FMT_PREFIX,fmt_sz_Keyboard_Copy
    _UT_ 7, 0007Dh,IS_FMT_PREFIX,fmt_sz_Keyboard_Paste
    _UT_ 7, 0007Eh,IS_FMT_PREFIX,fmt_sz_Keyboard_Find
    _UT_ 7, 0007Fh,IS_FMT_PREFIX,fmt_sz_Keyboard_Mute
    _UT_ 7, 00080h,IS_FMT_PREFIX,fmt_sz_Keyboard_Volume_Up
    _UT_ 7, 00081h,IS_FMT_PREFIX,fmt_sz_Keyboard_Volume_Down
    _UT_ 7, 00082h,IS_FMT_PREFIX,fmt_sz_Keyboard_Locking_Caps_Lock
    _UT_ 7, 00083h,IS_FMT_PREFIX,fmt_sz_Keyboard_Locking_Num_Lock
    _UT_ 7, 00084h,IS_FMT_PREFIX,fmt_sz_Keyboard_Locking_Scroll_Lock
    _UT_ 7, 00085h,IS_FMT_PREFIX,fmt_sz_Keypad_Comma
    _UT_ 7, 00086h,IS_FMT_PREFIX,fmt_sz_Keypad_Equal_Sign
    _UT_ 7, 00087h,IS_FMT_PREFIX,fmt_sz_Keyboard_International1
    _UT_ 7, 00088h,IS_FMT_PREFIX,fmt_sz_Keyboard_International2
    _UT_ 7, 00089h,IS_FMT_PREFIX,fmt_sz_Keyboard_International3
    _UT_ 7, 0008Ah,IS_FMT_PREFIX,fmt_sz_Keyboard_International4
    _UT_ 7, 0008Bh,IS_FMT_PREFIX,fmt_sz_Keyboard_International5
    _UT_ 7, 0008Ch,IS_FMT_PREFIX,fmt_sz_Keyboard_International6
    _UT_ 7, 0008Dh,IS_FMT_PREFIX,fmt_sz_Keyboard_International7
    _UT_ 7, 0008Eh,IS_FMT_PREFIX,fmt_sz_Keyboard_International8
    _UT_ 7, 0008Fh,IS_FMT_PREFIX,fmt_sz_Keyboard_International9
    _UT_ 7, 00090h,IS_FMT_PREFIX,fmt_sz_Keyboard_LANG1
    _UT_ 7, 00091h,IS_FMT_PREFIX,fmt_sz_Keyboard_LANG2
    _UT_ 7, 00092h,IS_FMT_PREFIX,fmt_sz_Keyboard_LANG3
    _UT_ 7, 00093h,IS_FMT_PREFIX,fmt_sz_Keyboard_LANG4
    _UT_ 7, 00094h,IS_FMT_PREFIX,fmt_sz_Keyboard_LANG5
    _UT_ 7, 00095h,IS_FMT_PREFIX,fmt_sz_Keyboard_LANG6
    _UT_ 7, 00096h,IS_FMT_PREFIX,fmt_sz_Keyboard_LANG7
    _UT_ 7, 00097h,IS_FMT_PREFIX,fmt_sz_Keyboard_LANG8
    _UT_ 7, 00098h,IS_FMT_PREFIX,fmt_sz_Keyboard_LANG9
    _UT_ 7, 00099h,IS_FMT_PREFIX,fmt_sz_Keyboard_Alternate_Erase
    _UT_ 7, 0009Ah,IS_FMT_PREFIX,fmt_sz_Keyboard_SysReqslash_Attention
    _UT_ 7, 0009Bh,IS_FMT_PREFIX,fmt_sz_Keyboard_Cancel
    _UT_ 7, 0009Ch,IS_FMT_PREFIX,fmt_sz_Keyboard_Clear
    _UT_ 7, 0009Dh,IS_FMT_PREFIX,fmt_sz_Keyboard_Prior
    _UT_ 7, 0009Eh,IS_FMT_PREFIX,fmt_sz_Keyboard_Return
    _UT_ 7, 0009Fh,IS_FMT_PREFIX,fmt_sz_Keyboard_Separator
    _UT_ 7, 000A0h,IS_FMT_PREFIX,fmt_sz_Keyboard_Out
    _UT_ 7, 000A1h,IS_FMT_PREFIX,fmt_sz_Keyboard_Oper
    _UT_ 7, 000A2h,IS_FMT_PREFIX,fmt_sz_Keyboard_Clearslash_Again
    _UT_ 7, 000A3h,IS_FMT_PREFIX,fmt_sz_Keyboard_CrSelslash_Props
    _UT_ 7, 000A4h,IS_FMT_PREFIX,fmt_sz_Keyboard_ExSel
    _UT_ 7, 000A5h,             ,    sz_Reserved
    _UT_ 7, 000B0h,IS_FMT_PREFIX,fmt_sz_Keypad_00
    _UT_ 7, 000B1h,IS_FMT_PREFIX,fmt_sz_Keypad_000
    _UT_ 7, 000B2h,             ,    sz_Thousands_Separator
    _UT_ 7, 000B3h,             ,    sz_Decimal_Separator
    _UT_ 7, 000B4h,             ,    sz_Currency_Unit
    _UT_ 7, 000B5h,             ,    sz_Currency_Sub_unit
    _UT_ 7, 000B6h,IS_FMT_PREFIX,fmt_sz_Keypad_lparen
    _UT_ 7, 000B7h,IS_FMT_PREFIX,fmt_sz_Keypad_rparen
    _UT_ 7, 000B8h,IS_FMT_PREFIX,fmt_sz_Keypad_lcurly
    _UT_ 7, 000B9h,IS_FMT_PREFIX,fmt_sz_Keypad_rcurly
    _UT_ 7, 000BAh,IS_FMT_PREFIX,fmt_sz_Keypad_Tab
    _UT_ 7, 000BBh,IS_FMT_PREFIX,fmt_sz_Keypad_Backspace
    _UT_ 7, 000BCh,IS_FMT_PREFIX,fmt_sz_Keypad_A
    _UT_ 7, 000BDh,IS_FMT_PREFIX,fmt_sz_Keypad_B
    _UT_ 7, 000BEh,IS_FMT_PREFIX,fmt_sz_Keypad_C
    _UT_ 7, 000BFh,IS_FMT_PREFIX,fmt_sz_Keypad_D
    _UT_ 7, 000C0h,IS_FMT_PREFIX,fmt_sz_Keypad_E
    _UT_ 7, 000C1h,IS_FMT_PREFIX,fmt_sz_Keypad_F
    _UT_ 7, 000C2h,IS_FMT_PREFIX,fmt_sz_Keypad_XOR
    _UT_ 7, 000C3h,IS_FMT_PREFIX,fmt_sz_Keypad_upcaret
    _UT_ 7, 000C4h,IS_FMT_PREFIX,fmt_sz_Keypad_percent
    _UT_ 7, 000C5h,IS_FMT_PREFIX,fmt_sz_Keypad_lcaret
    _UT_ 7, 000C6h,IS_FMT_PREFIX,fmt_sz_Keypad_rcaret
    _UT_ 7, 000C7h,IS_FMT_PREFIX,fmt_sz_Keypad_ampersand
    _UT_ 7, 000C8h,IS_FMT_PREFIX,fmt_sz_Keypad_ampersand_ampersand
    _UT_ 7, 000C9h,IS_FMT_PREFIX,fmt_sz_Keypad_pipe
    _UT_ 7, 000CAh,IS_FMT_PREFIX,fmt_sz_Keypad_pipe_pipe
    _UT_ 7, 000CBh,IS_FMT_PREFIX,fmt_sz_Keypad_colon
    _UT_ 7, 000CCh,IS_FMT_PREFIX,fmt_sz_Keypad_pound
    _UT_ 7, 000CDh,IS_FMT_PREFIX,fmt_sz_Keypad_Space
    _UT_ 7, 000CEh,IS_FMT_PREFIX,fmt_sz_Keypad_at
    _UT_ 7, 000CFh,IS_FMT_PREFIX,fmt_sz_Keypad_exclamation
    _UT_ 7, 000D0h,IS_FMT_PREFIX,fmt_sz_Keypad_Memory_Store
    _UT_ 7, 000D1h,IS_FMT_PREFIX,fmt_sz_Keypad_Memory_Recall
    _UT_ 7, 000D2h,IS_FMT_PREFIX,fmt_sz_Keypad_Memory_Clear
    _UT_ 7, 000D3h,IS_FMT_PREFIX,fmt_sz_Keypad_Memory_Add
    _UT_ 7, 000D4h,IS_FMT_PREFIX,fmt_sz_Keypad_Memory_Subtract
    _UT_ 7, 000D5h,IS_FMT_PREFIX,fmt_sz_Keypad_Memory_Multiply
    _UT_ 7, 000D6h,IS_FMT_PREFIX,fmt_sz_Keypad_Memory_Divide
    _UT_ 7, 000D7h,IS_FMT_PREFIX,fmt_sz_Keypad_plus_slash
    _UT_ 7, 000D8h,IS_FMT_PREFIX,fmt_sz_Keypad_Clear
    _UT_ 7, 000D9h,IS_FMT_PREFIX,fmt_sz_Keypad_Clear_Entry
    _UT_ 7, 000DAh,IS_FMT_PREFIX,fmt_sz_Keypad_Binary
    _UT_ 7, 000DBh,IS_FMT_PREFIX,fmt_sz_Keypad_Octal
    _UT_ 7, 000DCh,IS_FMT_PREFIX,fmt_sz_Keypad_Decimal
    _UT_ 7, 000DDh,IS_FMT_PREFIX,fmt_sz_Keypad_Hexadecimal
    _UT_ 7, 000DEh,             ,    sz_Reserved
    _UT_ 7, 000E0h,IS_FMT_PREFIX,fmt_sz_Keyboard_LeftControl
    _UT_ 7, 000E1h,IS_FMT_PREFIX,fmt_sz_Keyboard_LeftShift
    _UT_ 7, 000E2h,IS_FMT_PREFIX,fmt_sz_Keyboard_LeftAlt
    _UT_ 7, 000E3h,IS_FMT_PREFIX,fmt_sz_Keyboard_Left_GUI
    _UT_ 7, 000E4h,IS_FMT_PREFIX,fmt_sz_Keyboard_RightControl
    _UT_ 7, 000E5h,IS_FMT_PREFIX,fmt_sz_Keyboard_RightShift
    _UT_ 7, 000E6h,IS_FMT_PREFIX,fmt_sz_Keyboard_RightAlt
    _UT_ 7, 000E7h,IS_FMT_PREFIX,fmt_sz_Keyboard_Right_GUI
    _UT_ 7, 000E8h,             ,    sz_Reserved

    dd -1   ;// terminator

;// USAGE TABLE 9'

up_9 LABEL USAGE_TABLE

    USAGE_TABLE { {0},IS_FMT_ORDINAL OR HAS_SHORT_NAME OR SHORT_IS_INDEXED, fmt_sz_Button }

    dd -1   ;// terminator

    NUM_USAGE_TABLE_9 = 1
    LAST_USAGE_TABLE_9 = 0


;///////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////

;// USAGE_PAGE_TABLE


usage_page_table LABEL USAGE_PAGE_TABLE

    NUM_USAGE_PAGE_TABLE = 0    ;// counter

    ;//                0         1         2
    ;//    min  page   01234567890123456789012
    _UPT_ 00000h,   ,, sz_Undefined
    _UPT_ 00001h, 1 ,, sz_Generic_Desktop_Control
    _UPT_ 00002h, 2 ,, sz_Simulation_Control
    _UPT_ 00003h, 3 ,, sz_VR_Control
    _UPT_ 00004h, 4 ,, sz_Sport_Control
    _UPT_ 00005h, 5 ,, sz_Game_Control
    _UPT_ 00006h,   ,, sz_Generic_Device_Control
    _UPT_ 00007h, 7 ,, sz_Keyboard_Keypad
    _UPT_ 00008h,   ,, sz_LED
    _UPT_ 00009h, 9 ,, sz_Button
    _UPT_ 0000Ah,   ,, sz_Ordinal
    _UPT_ 0000Bh,   ,, sz_Telephony
    _UPT_ 0000Ch,   ,, sz_Consumer
    _UPT_ 0000Dh,   ,, sz_Digitizer
    _UPT_ 0000Eh,   ,, sz_Reserved
    _UPT_ 0000Fh,   ,, sz_PID
    _UPT_ 00010h,   ,, sz_Unicode
    _UPT_ 00011h,   ,, sz_Reserved
    _UPT_ 00014h,   ,, sz_Alphanumeric_Display
    _UPT_ 00015h,   ,, sz_Reserved
    _UPT_ 00040h,   ,, sz_Medical_Instrument
    _UPT_ 00041h,   ,, sz_Reserved
    _UPT_ 00080h,   ,, sz_Monitor_Device
    _UPT_ 00084h,   ,, sz_Power_Device
    _UPT_ 00088h,   ,, sz_Reserved
    _UPT_ 0008Ch,   ,, sz_Bar_Code_Scanner
    _UPT_ 0008Dh,   ,, sz_Scale
    _UPT_ 0008Eh,   ,, sz_Magnetic_Stripe_Reader
    _UPT_ 0008Fh,   ,, sz_Reserved
    _UPT_ 00090h,   ,, sz_Camera_Control
    _UPT_ 00091h,   ,, sz_Arcade_Device
    _UPT_ 00092h,   ,, sz_Reserved
    _UPT_ 0FF00h,   ,, sz_Vendor_defined

    dd  -1  ;// terminator

    LAST_USAGE_PAGE_TABLE EQU 00092h    ;// for linear aproximation


;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////
;///
;///
;///    FORMAT STRINGS


    fmt_indexed_page    db  '%s %X',0       ;// used to make indexed entries


;// FORMAT STRINGS TABLE        if IS_FMT_PREFIX then first byte indexs these strings

    ALIGN 4
    format_string_table LABEL DWORD

        dd  fmt_table_sz_none
        dd  fmt_table_sz_Button
        dd  fmt_table_sz_Keyboard
        dd  fmt_table_sz_Keypad
        dd  fmt_table_sz_System
        dd  fmt_table_sz_SysDisp

        NUM_FORMAT_STRINGS EQU 6    ;// index must be less than this

        fmt_table_sz_none           db  '?? %X',0       ;// incase of error
        fmt_table_sz_Button         db  'Button %i',0   ;// 01   used by page 9
        fmt_table_sz_Keyboard       db  'Keyboard %s',0 ;// 02
        fmt_table_sz_Keypad         db  'Keypad %s',0   ;// 03
        fmt_table_sz_System         db  'System %s',0   ;// 04
        fmt_table_sz_SysDisp        db  'System Display %s',0   ;// 05


        fmt_unknown_string  db "?? '%s'",0

;// strings
;//////////////////////////////////////////////////////////////////////////////////////

    sz_Undefined                 db 'Undefined',0
    sz_Generic_Desktop_Control   db 'Generic Desktop Control',0
    sz_Simulation_Control        db 'Simulation Control',0
    sz_VR_Control                db 'VR Control',0
    sz_Sport_Control             db 'Sport Control',0
    sz_Game_Control              db 'Game Control',0
    sz_Generic_Device_Control    db 'Generic Device Control',0
    sz_Keyboard_Keypad           db 'Keyboard/Keypad',0
    sz_LED                       db 'LED',0
    sz_Button                    db 'Button',0
    sz_Ordinal                   db 'Ordinal',0
    sz_Telephony                 db 'Telephony',0
    sz_Consumer                  db 'Consumer',0
    sz_Digitizer                 db 'Digitizer',0
    sz_Reserved                  db 'Reserved',0
    sz_PID                       db 'PID',0
    sz_Unicode                   db 'Unicode',0
    sz_Alphanumeric_Display      db 'Alphanumeric Display',0
    sz_Medical_Instrument        db 'Medical Instrument',0
    sz_Monitor_Device            db 'Monitor Device',0
    sz_Power_Device              db 'Power Device',0
    sz_Bar_Code_Scanner          db 'Bar Code Scanner',0
    sz_Scale                     db 'Scale',0
    sz_Magnetic_Stripe_Reader    db 'Magnetic Stripe Reader',0
    sz_Camera_Control            db 'Camera Control',0
    sz_Arcade_Device             db 'Arcade Device',0
    sz_Vendor_defined            db 'Vendor-defined',0

;//////////////////////////////////////////////////////////////////////////////////////////

    sz_Pointer                              db 'Pointer',0
    sz_Mouse                                db 'Mouse',0
    sz_Joystick                             db 'Joystick',0
    sz_Game_Pad                             db 'Game Pad',0
    sz_Keyboard                             db 'Keyboard',0
    sz_Keypad                               db 'Keypad',0
    sz_Multi_axis_Controller                db 'Multi-axis Controller',0
    sz_X_Axis                               db 'X Axis',0,'X',0
    sz_Y_Axis                               db 'Y Axis',0,'Y',0
    sz_Z_Axis                               db 'Z Axis',0,'Z',0
    sz_Rx_Axis                              db 'Rx Axis',0,'Rx',0
    sz_Ry_Axis                              db 'Ry Axis',0,'Ry',0
    sz_Rz_Axis                              db 'Rz Axis',0,'Rz',0
    sz_Slider                               db 'Slider',0,'S',0
    sz_Dial                                 db 'Dial',0,'D',0
    sz_Wheel                                db 'Wheel',0,'W',0
    sz_Hat_switch                           db 'Hat switch',0,'H',0
    sz_Counted_Buffer                       db 'Counted Buffer',0
    sz_Byte_Count                           db 'Byte Count',0
    sz_Motion_Wakeup                        db 'Motion Wakeup',0
    sz_Start                                db 'Start',0
    sz_Select                               db 'Select',0
    sz_Vector_Vx                            db 'Vector Vx',0,'Vx',0
    sz_Vector_Vy                            db 'Vector Vy',0,'Vy',0
    sz_Vector_Vz                            db 'Vector Vz',0,'Vz',0
    sz_Vector_Vbrx                          db 'Vector Vbrx',0,'bx',0
    sz_Vector_Vbry                          db 'Vector Vbry',0,'by',0
    sz_Vector_Vbrz                          db 'Vector Vbrz',0,'bz',0
    sz_Vector_Vno                           db 'Vector Vno',0,'b0',0
    sz_Feature_Notification                 db 'Feature Notification',0
fmt_sz_System_Control                       db 4,'Control',0
fmt_sz_System_Power_Down                    db 4,'Power Down',0
fmt_sz_System_Sleep                         db 4,'Sleep',0
fmt_sz_System_Wake_Up                       db 4,'Wake Up',0
fmt_sz_System_Context_Menu                  db 4,'Context Menu',0
fmt_sz_System_Main_Menu                     db 4,'Main Menu',0
fmt_sz_System_App_Menu                      db 4,'App Menu',0
fmt_sz_System_Menu_Help                     db 4,'Menu Help',0
fmt_sz_System_Menu_Exit                     db 4,'Menu Exit',0
fmt_sz_System_Menu_Select                   db 4,'Menu Select',0
fmt_sz_System_Menu_Right                    db 4,'Menu Right',0
fmt_sz_System_Menu_Left                     db 4,'Menu Left',0
fmt_sz_System_Menu_Up                       db 4,'Menu Up',0
fmt_sz_System_Menu_Down                     db 4,'Menu Down',0
fmt_sz_System_Cold_Restart                  db 4,'Cold Restart',0
fmt_sz_System_Warm_Restart                  db 4,'Warm Restart',0
    sz_D_pad_Up                             db 'D-pad Up',0,'up',0
    sz_D_pad_Down                           db 'D-pad Down',0,'dn',0
    sz_D_pad_Right                          db 'D-pad Right',0,'rt',0
    sz_D_pad_Left                           db 'D-pad Left',0,'lf',0
fmt_sz_System_Dock                          db 4,'Dock',0
fmt_sz_System_Undock                        db 4,'Undock',0
fmt_sz_System_Setup                         db 4,'Setup',0
fmt_sz_System_Break                         db 4,'Break',0
fmt_sz_System_Debugger_Break                db 4,'Debugger Break',0
    sz_Application_Break                    db 'Application Break',0
    sz_Application_Debugger_Break           db 'Application Debugger Break',0
fmt_sz_System_Speaker                       db 4,'Speaker',0
fmt_sz_System_Hibernate                     db 4,'Hibernate',0
fmt_sz_System_Display_Invert                db 5,'Invert',0
fmt_sz_System_Display_Internal              db 5,'Internal',0
fmt_sz_System_Display_External              db 5,'External',0
fmt_sz_System_Display_Both                  db 5,'Both',0
fmt_sz_System_Display_Dual                  db 5,'Dual',0
fmt_sz_System_Display_Toggle_Intslash_Ext   db 5,'Toggle Int/Ext',0
fmt_sz_System_Display_Swap                  db 5,'Swap',0
fmt_sz_System_Display_LCD_Autoscale         db 5,'LCD Autoscale',0

;//////////////////////////////////////////////////////////////////////////////////////////

    sz_Flight_Simulation_Device             db 'Flight Simulation Device',0
    sz_Automobile_Simulation_Device         db 'Automobile Simulation Device',0
    sz_Tank_Simulation_Device               db 'Tank Simulation Device',0
    sz_Spaceship_Simulation_Device          db 'Spaceship Simulation Device',0
    sz_Submarine_Simulation_Device          db 'Submarine Simulation Device',0
    sz_Sailing_Simulation_Device            db 'Sailing Simulation Device',0
    sz_Motorcycle_Simulation_Device         db 'Motorcycle Simulation Device',0
    sz_Sports_Simulation_Device             db 'Sports Simulation Device',0
    sz_Airplane_Simulation_Device           db 'Airplane Simulation Device',0
    sz_Helicopter_Simulation_Device         db 'Helicopter Simulation Device',0
    sz_Magic_Carpet_Simulation_Device       db 'Magic Carpet Simulation Device',0
    sz_Bicycle_Simulation_Device            db 'Bicycle Simulation Device',0
    sz_Flight_Control_Stick                 db 'Flight Control Stick',0
    sz_Flight_Stick                         db 'Flight Stick',0
    sz_Cyclic_Control                       db 'Cyclic Control',0
    sz_Cyclic_Trim                          db 'Cyclic Trim',0
    sz_Flight_Yoke                          db 'Flight Yoke',0
    sz_Track_Control                        db 'Track Control',0
    sz_Aileron                              db 'Aileron',0
    sz_Aileron_Trim                         db 'Aileron Trim',0
    sz_Anti_Torque_Control                  db 'Anti-Torque Control',0
    sz_Autopilot_Enable                     db 'Autopilot Enable',0
    sz_Chaff_Release                        db 'Chaff Release',0
    sz_Collective_Control                   db 'Collective Control',0
    sz_Dive_Brake                           db 'Dive Brake',0
    sz_Electronic_Countermeasures           db 'Electronic Countermeasures',0
    sz_Elevator                             db 'Elevator',0
    sz_Elevator_Trim                        db 'Elevator Trim',0
    sz_Rudder                               db 'Rudder',0
    sz_Throttle                             db 'Throttle',0
    sz_Flight_Communications                db 'Flight Communications',0
    sz_Flare_Release                        db 'Flare Release',0
    sz_Landing_Gear                         db 'Landing Gear',0
    sz_Toe_Brake                            db 'Toe Brake',0
    sz_Trigger                              db 'Trigger',0
    sz_Weapons_Arm                          db 'Weapons Arm',0
    sz_Weapons_Select                       db 'Weapons Select',0
    sz_Wing_Flaps                           db 'Wing Flaps',0
    sz_Accelerator                          db 'Accelerator',0
    sz_Brake                                db 'Brake',0
    sz_Clutch                               db 'Clutch',0
    sz_Shifter                              db 'Shifter',0
    sz_Steering                             db 'Steering',0
    sz_Turret_Direction                     db 'Turret Direction',0
    sz_Barrel_Elevation                     db 'Barrel Elevation',0
    sz_Dive_Plane                           db 'Dive Plane',0
    sz_Ballast                              db 'Ballast',0
    sz_Bicycle_Crank                        db 'Bicycle Crank',0
    sz_Handle_Bars                          db 'Handle Bars',0
    sz_Front_Brake                          db 'Front Brake',0
    sz_Rear_Brake                           db 'Rear Brake',0

;//////////////////////////////////////////////////////////////////////////////////////////

    sz_Unidentified                         db 'Unidentified',0
    sz_Belt                                 db 'Belt',0
    sz_Body_Suit                            db 'Body Suit',0
    sz_Flexor                               db 'Flexor',0
    sz_Glove                                db 'Glove',0
    sz_Head_Tracker                         db 'Head Tracker',0
    sz_Head_Mounted_Display                 db 'Head Mounted Display',0
    sz_Hand_Tracker                         db 'Hand Tracker',0
    sz_Oculometer                           db 'Oculometer',0
    sz_Vest                                 db 'Vest',0
    sz_Animatronic_Device                   db 'Animatronic Device',0
    sz_Stereo_Enable                        db 'Stereo Enable',0
    sz_Display_Enable                       db 'Display Enable',0

;//////////////////////////////////////////////////////////////////////////////////////////

    sz_Baseball_Bat                         db 'Baseball Bat',0
    sz_Golf_Club                            db 'Golf Club',0
    sz_Rowing_Machine                       db 'Rowing Machine',0
    sz_Treadmill                            db 'Treadmill',0
    sz_Oar                                  db 'Oar',0
    sz_Slope                                db 'Slope',0
    sz_Rate                                 db 'Rate',0
    sz_Stick_Speed                          db 'Stick Speed',0
    sz_Stick_Face_Angle                     db 'Stick Face Angle',0
    sz_Stick_Heelslash_Toe                  db 'Stick Heel/Toe',0
    sz_Stick_Follow_Through                 db 'Stick Follow Through',0
    sz_Stick_Tempo                          db 'Stick Tempo',0
    sz_Stick_Type                           db 'Stick Type',0
    sz_Stick_Height                         db 'Stick Height',0
    sz_Putter                               db 'Putter',0
    sz_1_Iron                               db '1 Iron',0
    sz_2_Iron                               db '2 Iron',0
    sz_3_Iron                               db '3 Iron',0
    sz_4_Iron                               db '4 Iron',0
    sz_5_Iron                               db '5 Iron',0
    sz_6_Iron                               db '6 Iron',0
    sz_7_Iron                               db '7 Iron',0
    sz_8_Iron                               db '8 Iron',0
    sz_9_Iron                               db '9 Iron',0
    sz_10_Iron                              db '10 Iron',0
    sz_11_Iron                              db '11 Iron',0
    sz_Sand_Wedge                           db 'Sand Wedge',0
    sz_Loft_Wedge                           db 'Loft Wedge',0
    sz_Power_Wedge                          db 'Power Wedge',0
    sz_1_Wood                               db '1 Wood',0
    sz_3_Wood                               db '3 Wood',0
    sz_5_Wood                               db '5 Wood',0
    sz_7_Wood                               db '7 Wood',0
    sz_9_Wood                               db '9 Wood',0

;//////////////////////////////////////////////////////////////////////////////////////////

    sz_3D_Game_Controller                   db '3D Game Controller',0
    sz_Pinball_Device                       db 'Pinball Device',0
    sz_Gun_Device                           db 'Gun Device',0
    sz_Point_of_View                        db 'Point of View',0
    sz_Turn_Rightslash_Left                 db 'Turn Right/Left',0
    sz_Pitch_Forwardslash_Backward          db 'Pitch Forward/Backward',0
    sz_Roll_Rightslash_Left                 db 'Roll Right/Left',0
    sz_Move_Rightslash_Left                 db 'Move Right/Left',0
    sz_Move_Forwardslash_Backward           db 'Move Forward/Backward',0
    sz_Move_Upslash_Down                    db 'Move Up/Down',0
    sz_Lean_Rightslash_Left                 db 'Lean Right/Left',0
    sz_Lean_Forwardslash_Backward           db 'Lean Forward/Backward',0
    sz_Height_of_POV                        db 'Height of POV',0
    sz_Flipper                              db 'Flipper',0
    sz_Secondary_Flipper                    db 'Secondary Flipper',0
    sz_Bump                                 db 'Bump',0
    sz_New_Game                             db 'New Game',0
    sz_Shoot_Ball                           db 'Shoot Ball',0
    sz_Player                               db 'Player',0
    sz_Gun_Bolt                             db 'Gun Bolt',0
    sz_Gun_Clip                             db 'Gun Clip',0
    sz_Gun_Selector                         db 'Gun Selector',0
    sz_Gun_Single_Shot                      db 'Gun Single Shot',0
    sz_Gun_Burst                            db 'Gun Burst',0
    sz_Gun_Automatic                        db 'Gun Automatic',0
    sz_Gun_Safety                           db 'Gun Safety',0
    sz_Gamepad_Fireslash_Jump               db 'Gamepad Fire/Jump',0
    sz_Gamepad_Trigger                      db 'Gamepad Trigger',0

;//////////////////////////////////////////////////////////////////////////////////////////

fmt_sz_Keyboard_ErrorRollOver               db 2,'ErrorRollOver',0
fmt_sz_Keyboard_POSTFail                    db 2,'POSTFail',0
fmt_sz_Keyboard_ErrorUndefined              db 2,'ErrorUndefined',0
fmt_sz_Keyboard_a_and_A                     db 2,'a and A',0
fmt_sz_Keyboard_b_and_B                     db 2,'b and B',0
fmt_sz_Keyboard_c_and_C                     db 2,'c and C',0
fmt_sz_Keyboard_d_and_D                     db 2,'d and D',0
fmt_sz_Keyboard_e_and_E                     db 2,'e and E',0
fmt_sz_Keyboard_f_and_F                     db 2,'f and F',0
fmt_sz_Keyboard_g_and_G                     db 2,'g and G',0
fmt_sz_Keyboard_h_and_H                     db 2,'h and H',0
fmt_sz_Keyboard_i_and_I                     db 2,'i and I',0
fmt_sz_Keyboard_j_and_J                     db 2,'j and J',0
fmt_sz_Keyboard_k_and_K                     db 2,'k and K',0
fmt_sz_Keyboard_l_and_L                     db 2,'l and L',0
fmt_sz_Keyboard_m_and_M                     db 2,'m and M',0
fmt_sz_Keyboard_n_and_N                     db 2,'n and N',0
fmt_sz_Keyboard_o_and_O                     db 2,'o and O',0
fmt_sz_Keyboard_p_and_P                     db 2,'p and P',0
fmt_sz_Keyboard_q_and_Q                     db 2,'q and Q',0
fmt_sz_Keyboard_r_and_R                     db 2,'r and R',0
fmt_sz_Keyboard_s_and_S                     db 2,'s and S',0
fmt_sz_Keyboard_t_and_T                     db 2,'t and T',0
fmt_sz_Keyboard_u_and_U                     db 2,'u and U',0
fmt_sz_Keyboard_v_and_V                     db 2,'v and V',0
fmt_sz_Keyboard_w_and_W                     db 2,'w and W',0
fmt_sz_Keyboard_x_and_X                     db 2,'x and X',0
fmt_sz_Keyboard_y_and_Y                     db 2,'y and Y',0
fmt_sz_Keyboard_z_and_Z                     db 2,'z and Z',0
fmt_sz_Keyboard_1_and_exclamation           db 2,'1 and !',0
fmt_sz_Keyboard_2_and_at                    db 2,'2 and @',0
fmt_sz_Keyboard_3_and_pound                 db 2,'3 and #',0
fmt_sz_Keyboard_4_and_dollar                db 2,'4 and $',0
fmt_sz_Keyboard_5_and_percent               db 2,'5 and %',0
fmt_sz_Keyboard_6_and_upcaret               db 2,'6 and ^',0
fmt_sz_Keyboard_7_and_ampersand             db 2,'7 and &',0
fmt_sz_Keyboard_8_and_star                  db 2,'8 and *',0
fmt_sz_Keyboard_9_and_lparen                db 2,'9 and (',0
fmt_sz_Keyboard_0_and_rparen                db 2,'0 and )',0
fmt_sz_Keyboard_Return                      db 2,'Return (ENTER)',0
fmt_sz_Keyboard_Escape                      db 2,'Escape',0
fmt_sz_Keyboard_Backspace                   db 2,'Backspace',0
fmt_sz_Keyboard_Tab                         db 2,'Tab',0
fmt_sz_Keyboard_Spacebar                    db 2,'Spacebar',0
fmt_sz_Keyboard_minus_and_underscore        db 2,'- and _',0
fmt_sz_Keyboard_equal__and_plus             db 2,'= and +',0
fmt_sz_Keyboard_lbracket_and_lcurly         db 2,'[ and {',0
fmt_sz_Keyboard_rbracket_and_rcurly         db 2,'] and,0',0
fmt_sz_Keyboard_backslash__and_pipe_        db 2,'\ and |',0
fmt_sz_Keyboard_Non_US_pound__and_tilde     db 2,'Non-US # and ~',0
fmt_sz_Keyboard_semicolon__and_colon        db 2,'; and :',0
fmt_sz_Keyboard_squtoe_and_dquote           db 2,'‘ and “',0
fmt_sz_Keyboard_lsquote_and_tilde           db 2,'` and ~',0
fmt_sz_Keyboard_comma_and_lcaret_           db 2,', and <',0
fmt_sz_Keyboard_period_and_rcaret           db 2,'. and >',0
fmt_sz_Keyboard_slash__and_question         db 2,'/ and ?',0
fmt_sz_Keyboard_Caps_Lock                   db 2,'Caps Lock',0
fmt_sz_Keyboard_F1                          db 2,'F1',0
fmt_sz_Keyboard_F2                          db 2,'F2',0
fmt_sz_Keyboard_F3                          db 2,'F3',0
fmt_sz_Keyboard_F4                          db 2,'F4',0
fmt_sz_Keyboard_F5                          db 2,'F5',0
fmt_sz_Keyboard_F6                          db 2,'F6',0
fmt_sz_Keyboard_F7                          db 2,'F7',0
fmt_sz_Keyboard_F8                          db 2,'F8',0
fmt_sz_Keyboard_F9                          db 2,'F9',0
fmt_sz_Keyboard_F10                         db 2,'F10',0
fmt_sz_Keyboard_F11                         db 2,'F11',0
fmt_sz_Keyboard_F12                         db 2,'F12',0
fmt_sz_Keyboard_PrintScreen                 db 2,'PrintScreen',0
fmt_sz_Keyboard_Scroll_Lock                 db 2,'Scroll Lock',0
fmt_sz_Keyboard_Pause                       db 2,'Pause',0
fmt_sz_Keyboard_Insert                      db 2,'Insert',0
fmt_sz_Keyboard_Home                        db 2,'Home',0
fmt_sz_Keyboard_PageUp                      db 2,'PageUp',0
fmt_sz_Keyboard_Delete                      db 2,'Delete',0
fmt_sz_Keyboard_End                         db 2,'End',0
fmt_sz_Keyboard_PageDown                    db 2,'PageDown',0
fmt_sz_Keyboard_RightArrow                  db 2,'RightArrow',0
fmt_sz_Keyboard_LeftArrow                   db 2,'LeftArrow',0
fmt_sz_Keyboard_DownArrow                   db 2,'DownArrow',0
fmt_sz_Keyboard_UpArrow                     db 2,'UpArrow',0
fmt_sz_Keypad_Num_Lock_and_Clear            db 3,'Num Lock and Clear',0
fmt_sz_Keypad_slash                         db 3,'/',0
fmt_sz_Keypad_star                          db 3,'*',0
fmt_sz_Keypad__                             db 3,'-',0
fmt_sz_Keypad_plus                          db 3,'+',0
fmt_sz_Keypad_ENTER                         db 3,'ENTER',0
fmt_sz_Keypad_1_and_End                     db 3,'1 and End',0
fmt_sz_Keypad_2_and_Down_Arrow              db 3,'2 and Down Arrow',0
fmt_sz_Keypad_3_and_PageDn                  db 3,'3 and PageDn',0
fmt_sz_Keypad_4_and_Left_Arrow              db 3,'4 and Left Arrow',0
fmt_sz_Keypad_5                             db 3,'5',0
fmt_sz_Keypad_6_and_Right_Arrow             db 3,'6 and Right Arrow',0
fmt_sz_Keypad_7_and_Home                    db 3,'7 and Home',0
fmt_sz_Keypad_8_and_Up_Arrow                db 3,'8 and Up Arrow',0
fmt_sz_Keypad_9_and_PageUp                  db 3,'9 and PageUp',0
fmt_sz_Keypad_0_and_Insert                  db 3,'0 and Insert',0
fmt_sz_Keypad_dot_and_Delete                db 3,'. and Delete',0
fmt_sz_Keyboard_Non_US_backslash_and_pipe   db 2,'Non-US \ and |',0
fmt_sz_Keyboard_Application                 db 2,'Application',0
fmt_sz_Keyboard_Power                       db 2,'Power',0
fmt_sz_Keypad_equal                         db 3,'=',0
fmt_sz_Keyboard_F13                         db 2,'F13',0
fmt_sz_Keyboard_F14                         db 2,'F14',0
fmt_sz_Keyboard_F15                         db 2,'F15',0
fmt_sz_Keyboard_F16                         db 2,'F16',0
fmt_sz_Keyboard_F17                         db 2,'F17',0
fmt_sz_Keyboard_F18                         db 2,'F18',0
fmt_sz_Keyboard_F19                         db 2,'F19',0
fmt_sz_Keyboard_F20                         db 2,'F20',0
fmt_sz_Keyboard_F21                         db 2,'F21',0
fmt_sz_Keyboard_F22                         db 2,'F22',0
fmt_sz_Keyboard_F23                         db 2,'F23',0
fmt_sz_Keyboard_F24                         db 2,'F24',0
fmt_sz_Keyboard_Execute                     db 2,'Execute',0
fmt_sz_Keyboard_Help                        db 2,'Help',0
fmt_sz_Keyboard_Menu                        db 2,'Menu',0
fmt_sz_Keyboard_Select                      db 2,'Select',0
fmt_sz_Keyboard_Stop                        db 2,'Stop',0
fmt_sz_Keyboard_Again                       db 2,'Again',0
fmt_sz_Keyboard_Undo                        db 2,'Undo',0
fmt_sz_Keyboard_Cut                         db 2,'Cut',0
fmt_sz_Keyboard_Copy                        db 2,'Copy',0
fmt_sz_Keyboard_Paste                       db 2,'Paste',0
fmt_sz_Keyboard_Find                        db 2,'Find',0
fmt_sz_Keyboard_Mute                        db 2,'Mute',0
fmt_sz_Keyboard_Volume_Up                   db 2,'Volume Up',0
fmt_sz_Keyboard_Volume_Down                 db 2,'Volume Down',0
fmt_sz_Keyboard_Locking_Caps_Lock           db 2,'Locking Caps Lock',0
fmt_sz_Keyboard_Locking_Num_Lock            db 2,'Locking Num Lock',0
fmt_sz_Keyboard_Locking_Scroll_Lock         db 2,'Locking Scroll Lock',0
fmt_sz_Keypad_Comma                         db 3,',',0
fmt_sz_Keypad_Equal_Sign                    db 3,'=',0
fmt_sz_Keyboard_International1              db 2,'International1',0
fmt_sz_Keyboard_International2              db 2,'International2',0
fmt_sz_Keyboard_International3              db 2,'International3',0
fmt_sz_Keyboard_International4              db 2,'International4',0
fmt_sz_Keyboard_International5              db 2,'International5',0
fmt_sz_Keyboard_International6              db 2,'International6',0
fmt_sz_Keyboard_International7              db 2,'International7',0
fmt_sz_Keyboard_International8              db 2,'International8',0
fmt_sz_Keyboard_International9              db 2,'International9',0
fmt_sz_Keyboard_LANG1                       db 2,'LANG1',0
fmt_sz_Keyboard_LANG2                       db 2,'LANG2',0
fmt_sz_Keyboard_LANG3                       db 2,'LANG3',0
fmt_sz_Keyboard_LANG4                       db 2,'LANG4',0
fmt_sz_Keyboard_LANG5                       db 2,'LANG5',0
fmt_sz_Keyboard_LANG6                       db 2,'LANG6',0
fmt_sz_Keyboard_LANG7                       db 2,'LANG7',0
fmt_sz_Keyboard_LANG8                       db 2,'LANG8',0
fmt_sz_Keyboard_LANG9                       db 2,'LANG9',0
fmt_sz_Keyboard_Alternate_Erase             db 2,'Alternate Erase',0
fmt_sz_Keyboard_SysReqslash_Attention       db 2,'SysReq/Attention',0
fmt_sz_Keyboard_Cancel                      db 2,'Cancel',0
fmt_sz_Keyboard_Clear                       db 2,'Clear',0
fmt_sz_Keyboard_Prior                       db 2,'Prior',0
fmt_sz_Keyboard_Separator                   db 2,'Separator',0
fmt_sz_Keyboard_Out                         db 2,'Out',0
fmt_sz_Keyboard_Oper                        db 2,'Oper',0
fmt_sz_Keyboard_Clearslash_Again            db 2,'Clear/Again',0
fmt_sz_Keyboard_CrSelslash_Props            db 2,'CrSel/Props',0
fmt_sz_Keyboard_ExSel                       db 2,'ExSel',0
fmt_sz_Keypad_00                            db 3,' 00',0
fmt_sz_Keypad_000                           db 3,' 000',0
    sz_Thousands_Separator                  db 'Thousands Separator',0
    sz_Decimal_Separator                    db 'Decimal Separator',0
    sz_Currency_Unit                        db 'Currency Unit',0
    sz_Currency_Sub_unit                    db 'Currency Sub-unit',0
fmt_sz_Keypad_lparen                        db 3,'(',0
fmt_sz_Keypad_rparen                        db 3,')',0
fmt_sz_Keypad_lcurly                        db 3,'{',0
fmt_sz_Keypad_rcurly                        db 3,'}',0
fmt_sz_Keypad_Tab                           db 3,'Tab',0
fmt_sz_Keypad_Backspace                     db 3,'Backspace',0
fmt_sz_Keypad_A                             db 3,'A',0
fmt_sz_Keypad_B                             db 3,'B',0
fmt_sz_Keypad_C                             db 3,'C',0
fmt_sz_Keypad_D                             db 3,'D',0
fmt_sz_Keypad_E                             db 3,'E',0
fmt_sz_Keypad_F                             db 3,'F',0
fmt_sz_Keypad_XOR                           db 3,'XOR',0
fmt_sz_Keypad_upcaret                       db 3,'^',0
fmt_sz_Keypad_percent                       db 3,'%',0
fmt_sz_Keypad_lcaret                        db 3,'<',0
fmt_sz_Keypad_rcaret                        db 3,'>',0
fmt_sz_Keypad_ampersand                     db 3,'&',0
fmt_sz_Keypad_ampersand_ampersand           db 3,'&&',0
fmt_sz_Keypad_pipe                          db 3,'|',0
fmt_sz_Keypad_pipe_pipe                     db 3,'||',0
fmt_sz_Keypad_colon                         db 3,':',0
fmt_sz_Keypad_pound                         db 3,'#',0
fmt_sz_Keypad_Space                         db 3,'Space',0
fmt_sz_Keypad_at                            db 3,'@',0
fmt_sz_Keypad_exclamation                   db 3,'!',0
fmt_sz_Keypad_Memory_Store                  db 3,'Memory Store',0
fmt_sz_Keypad_Memory_Recall                 db 3,'Memory Recall',0
fmt_sz_Keypad_Memory_Clear                  db 3,'Memory Clear',0
fmt_sz_Keypad_Memory_Add                    db 3,'Memory Add',0
fmt_sz_Keypad_Memory_Subtract               db 3,'Memory Subtract',0
fmt_sz_Keypad_Memory_Multiply               db 3,'Memory Multiply',0
fmt_sz_Keypad_Memory_Divide                 db 3,'Memory Divide',0
fmt_sz_Keypad_plus_slash                    db 3,'+/-',0
fmt_sz_Keypad_Clear                         db 3,'Clear',0
fmt_sz_Keypad_Clear_Entry                   db 3,'Clear Entry',0
fmt_sz_Keypad_Binary                        db 3,'Binary',0
fmt_sz_Keypad_Octal                         db 3,'Octal',0
fmt_sz_Keypad_Decimal                       db 3,'Decimal',0
fmt_sz_Keypad_Hexadecimal                   db 3,'Hexadecimal',0
fmt_sz_Keyboard_LeftControl                 db 2,'LeftControl',0
fmt_sz_Keyboard_LeftShift                   db 2,'LeftShift',0
fmt_sz_Keyboard_LeftAlt                     db 2,'LeftAlt',0
fmt_sz_Keyboard_Left_GUI                    db 2,'Left GUI',0
fmt_sz_Keyboard_RightControl                db 2,'RightControl',0
fmt_sz_Keyboard_RightShift                  db 2,'RightShift',0
fmt_sz_Keyboard_RightAlt                    db 2,'RightAlt',0
fmt_sz_Keyboard_Right_GUI                   db 2,'Right GUI',0

;//////////////////////////////////////////////////////////////////////////////////////////

fmt_sz_Button   db  1,0,'B',0   ;// that should do it


;//////////////////////////////////////////////////////////////////////////////////////////



.CODE


;// PROLOGUE IS OFF !!
ASSUME_AND_ALIGN
hidusage_find_usage_page PROC   ;// ret ret usagepage
                                ;// 00  04  08

    ;// call from a top level routine
    ;// we assume the usage_page_usage arg is at [esp+8]
    ;//
    ;// returns ecx with a ptr to the USAGE_PAGE_TABLE, always suceeds
    ;// returns eax = the page number
    ;// destroys edx, ebx

    ;// linear approximate where to start

        mov eax, [esp+8]                ;// page:usage
        shr eax, 16                     ;//    0:page
        imul eax, NUM_USAGE_PAGE_TABLE  ;// page*num
        cdq
        mov ecx, LAST_USAGE_PAGE_TABLE
        div ecx                 ;// index = page*num/last

    ;// check if index is beyond table

        .IF eax >= NUM_USAGE_PAGE_TABLE
            mov eax, NUM_USAGE_PAGE_TABLE-1 ;// force to last record
        .ENDIF

    ;// make ecx the intial usage page search iterator

        .ERRNZ ((SIZEOF USAGE_PAGE_TABLE)-16), <we're assume 16 byte records !! >

        shl eax, LOG2(SIZEOF USAGE_PAGE_TABLE)
        lea ecx,usage_page_table[eax]
        ASSUME ecx:PTR USAGE_PAGE_TABLE

        mov eax, [esp+8]                ;// page:usage
        shr eax, 16                     ;//    0:page

        cmp ax, [ecx].wMin
        jne have_to_search

        retn

    ALIGN 4
    have_to_search:

        push ebx
        mov ebx, SIZEOF USAGE_PAGE_TABLE
        jmp search_through_tables


hidusage_find_usage_page ENDP




;// PROLOGUE IS OFF !!
ASSUME_AND_ALIGN
find_usage_table PROC   ;// ret ret usagepage
                        ;// 00  04  08

        ASSUME ecx:PTR USAGE_PAGE_TABLE ;// passed by caller

    ;// call from a top level routine
    ;// we assume the usage_page_usage arg is at [esp+8]
    ;//
    ;// returns ecx with a ptr to the USAGE_PAGE_TABLE, always suceeds
    ;// returns eax = the page number
    ;// destroys edx, ebx

    ;// linear approximate where to start

        mov eax, [esp+8]    ;// page:usage
        and eax, 0FFFFh     ;//    0:usage

        movzx edx, [ecx].wNum
        mul edx                 ;// eax = usage*num
        push ecx                ;// save ecx, we need it later
        movzx ecx, [ecx].wLast  ;// get the last
        test ecx, ecx           ;// check for zero
        jz only_one_entry       ;// only one entry if zero
        cdq
        div ecx                 ;// index = usage*num/last
        jmp eax_is_index
    only_one_entry:
        xor eax, eax
    eax_is_index:
        pop ecx                 ;// retrieve the USAGE_PAGE_TABLE_PTR

    ;// check if index is beyond table

        movzx edx, [ecx].wNum
        .IF eax >= edx
            lea eax, [edx-1]    ;// force to last record
        .ENDIF

    ;// make ecx the intial usage page search iterator

        .ERRNZ ((SIZEOF USAGE_TABLE)-8), <we're assume 8 byte records !! >

        mov ecx, [ecx].pTable
        DEBUG_IF < !!ecx >  ;// supposed to have a table !!!
        lea ecx, [ecx+eax*8]
        ASSUME ecx:PTR USAGE_MINIMUM

        mov eax, [esp+8]    ;// page:usage
        and eax, 0FFFFh     ;//    0:usage

        cmp ax, [ecx].wMin
        jne have_to_search

        retn

    ALIGN 4
    have_to_search:

        push ebx
        mov ebx, SIZEOF USAGE_TABLE
        jmp search_through_tables


find_usage_table ENDP




ASSUME_AND_ALIGN
search_through_tables PROC

    ;// ebx MUST HAVE THE SIZE, ebx MUST BE PUSHED ON THE STACK
    ;// ecx MUST BE FIRST ITERATOR
    ;// eax MUST BE VALUE TO SEARCH FOR
    ;// flags MUST BE RESULTS OF cmp ax, [ecx].wMin

    ASSUME ecx:PTR USAGE_MINIMUM

        ja search_forwards

    search_backwards:

        ;// ax < [ecx].wMin

        ;// if ax >= previous.wMin then previous is the record we want
        ;// otherwise, iterate backwards

        sub ecx, ebx                ;// previous record
        DEBUG_IF < [ecx].wMin==-1 > ;// fell off the begining of the table !!
        cmp ax, [ecx].wMin
        jb search_backwards

    found_it:

        pop ebx ;// retrieve ebx
        retn

    search_forwards:

        ;// ax > [ecx].wMin

        ;// if ax < next.wMin then ecx is therecord we want
        ;// otherwise iterate forward
        lea edx, [ecx+ebx]          ;// look at the next record
        ASSUME edx:PTR USAGE_MINIMUM
        cmp ax, [edx].wMin
        jb found_it                 ;// if ax is below, then ecx is the desired record
        cmp [edx].wMin, -1
        je found_it                 ;// allow the very last undefined page
        mov ecx, edx                ;// other wise we are above and search forwards
        jmp search_forwards

search_through_tables ENDP


;// PROLOGUE IS OFF !!
ASSUME_AND_ALIGN
hidusage_GetPageString PROC STDCALL dwPageUsage:DWORD, pBuffer:DWORD
                        ;// 00      04             08

        ;// returns the number of characters copied to the out buffer
        ;// not including the terminator
        ;// destroys eax,edx,ecx

        invoke hidusage_find_usage_page
        ASSUME ecx:PTR USAGE_PAGE_TABLE
        ;// eax returns as the page number

        mov edx, [esp+8]            ;// get the out buffer ptr
        ASSUME edx:PTR BYTE

        .IF ax == [ecx].wMin    ;// exact match ?

            ;// we have an exact match, therefore we do not need any special formatting
            xor eax, eax    ;// counter and xfer
            mov ecx, [ecx].pszName
            ASSUME ecx:PTR BYTE

            G0: mov ah, [ecx]   ;// get
                test ah, ah     ;// test for zero
                mov [edx], ah   ;// store
                jz all_done     ;// done if zero
                inc ecx         ;// advance the getter
                inc edx         ;// advance storer
                inc al          ;// count characters
                jmp G0          ;// continue

        .ENDIF

        ;// we do not have an exact match
        ;// so we build a numbered entry
        ASSUME ecx:PTR USAGE_PAGE_TABLE
        invoke wsprintfA,edx,OFFSET fmt_indexed_page, [ecx].pszName, eax
        ;// eax now equals the size

    all_done:

        retn 8  ;// STDCALL 2 args

hidusage_GetPageString ENDP




;// PROLOGUE IS OFF !!
ASSUME_AND_ALIGN
hidusage_GetUsageString PROC STDCALL dwPageUsage:DWORD, pBuffer:DWORD
                        ;//  00      04             08

        invoke hidusage_find_usage_page
        ASSUME ecx:PTR USAGE_PAGE_TABLE
        ;// eax returns as the page number

        cmp [ecx].pTable, 0
        je there_is_no_page_table

    ;// we have a table
    ;// find the usage entry

        invoke find_usage_table
        ASSUME ecx:PTR USAGE_TABLE

    ;// process the string

        movzx eax, [ecx].wType
        and eax, FORMAT_TEST    ;// mask out any extra
        DEBUG_IF < eax !> LAST_IS_FMT_TYPE >    ;// not supposed to happen !!

        mov edx, [esp+8]        ;// edx = out buffer ptr
        ASSUME edx:PTR BYTE

        mov ecx, [ecx].pszName  ;// ecx = format ptr
        ASSUME ecx:PTR BYTE

        jmp build_usage_string_table[eax*4]

        .DATA
        ALIGN 4
        build_usage_string_table LABEL DWORD
            dd  build_usage_string_type_0
            dd  build_usage_string_type_1
            dd  build_usage_string_type_2
        .CODE

    ALIGN 4
    build_usage_string_type_0:
    ;// IS_TEXT_STRING  EQU 0000h
    ;//
    ;//     default value
    ;//     just copy the string verbatim

        xor eax, eax    ;// counter and xfer

        G0: mov ah, [ecx]   ;// get
            test ah, ah     ;// test for zero
            mov [edx], ah   ;// store
            jz all_done     ;// done if zero
            inc ecx         ;// advance the getter
            inc edx         ;// advance storer
            inc al          ;// count characters
            jmp G0          ;// continue


    ALIGN 4
    build_usage_string_type_1:
    ;// IS_FMT_ORDINAL  EQU 0001h
    ;//
    ;//     first char is index, arg for fmt is the usage value
    ;//     EX:     sprintf(buf,"Button %i",index);

        movzx eax, [ecx]    ;// get the first char
        DEBUG_IF < eax !>= NUM_FORMAT_STRINGS > ;// not supposed to happen !!
        mov ecx, [esp+4]    ;// page:usage
        and ecx, 0FFFFh     ;//    0:usage
        jmp do_the_format

    ALIGN 4
    build_usage_string_type_2:
    ;// IS_FMT_PREFIX   EQU 0002h
    ;//
    ;//     first char is format_string_table,
    ;//     followed by the string arg for the format
    ;//     EX: sprintf(buf,"Keyboard %s","a and A" ) ;

        movzx eax, [ecx]    ;// get the first char
        DEBUG_IF < eax !>= NUM_FORMAT_STRINGS > ;// not supposed to happen !!
        inc ecx             ;// point at next arg

    do_the_format:

        invoke wsprintfA,edx,format_string_table[eax*4],ecx
        ;// jmp all_done    ;// eax has the length

    all_done:

        retn 8  ;// STDCALL 2 args

    ALIGN 4
    there_is_no_page_table:

        ;// build as unknown

        mov edx, [esp+8]        ;// edx = out buffer ptr
        ASSUME edx:PTR DWORD
        ASSUME ecx:PTR USAGE_PAGE_TABLE
        invoke wsprintfA, edx, OFFSET fmt_unknown_string, [ecx].pszName
        jmp all_done




hidusage_GetUsageString ENDP






;// PROLOGUE IS OFF !!
ASSUME_AND_ALIGN
hidusage_GetShortString PROC STDCALL dwPageUsage:DWORD, pBuffer:DWORD
                        ;//  00      04             08

        invoke hidusage_find_usage_page
        ASSUME ecx:PTR USAGE_PAGE_TABLE
        ;// eax returns as the page number

        CMPJMP [ecx].pTable, 0, je no_short_name

    ;// we have a table
    ;// find the usage entry

        invoke find_usage_table
        ASSUME ecx:PTR USAGE_TABLE

        movzx eax, [ecx].wType  ;// get the type

    ;// determine if there is a short name

        TESTJMP eax, HAS_SHORT_NAME, jz no_short_name

        mov edx, [esp+8]        ;// edx = out buffer ptr
        ASSUME edx:PTR BYTE

    ;// we do have a short name

        ;// find the end of the input string
        mov ecx, [ecx].pszName
        ASSUME ecx:PTR BYTE
        .REPEAT
            inc ecx
        .UNTIL ![ecx]
        inc ecx

        ;// copy the first char
        mov al, [ecx]
        mov [edx], al
        inc edx

        .ERRNZ (SHORT_IS_INDEXED - 4000h), <we're assuming bits are still in ah !!!! >
        ;// check for indexed names
        TESTJMP eax, SHORT_IS_INDEXED, jnz has_indexed_name

        ;// non indexed name

            inc ecx
            mov al, 1       ;// always has at least one char
            ;// see if there's a second char
            mov ah, [ecx]
            test ah, ah
            mov [edx], ah
            jz all_done
            inc al          ;// add one to the count
            inc edx         ;// advance the output so we can terminate
            mov ah, 0       ;// reset ah
            mov [edx], ah   ;// terminate
            jmp all_done

        ;// indexed name
        ;// usage has the index
        ALIGN 4
        has_indexed_name:

            movzx eax, WORD PTR [esp+4] ;// usage
            ;// apply ranges
            ;// range   0-9 10-35 36-51 52-inf
            ;// letter  0-9  a-z   A-Z    ?
            .IF eax < 10
                add eax, '0'
            .ELSEIF eax < 36
                add eax, 'a'-36
            .ELSEIF eax < 52
                add eax, 'A'-52
            .ELSE
                mov eax, '?'
            .ENDIF
            mov WORD PTR [edx], ax  ;// store the letter and terminate it
            mov eax, 2              ;// causes a biglittle stall, too bad
            jmp all_done

        ALIGN 4
        no_short_name:

            mov edx, [esp+8]        ;// edx = out buffer ptr
            ASSUME edx:PTR DWORD
            mov [edx], '??'
            mov eax, 2

    ALIGN 4
    all_done:

        retn 8  ;// STDCALL 2 args



hidusage_GetShortString ENDP




;///    usage tables        we use these to return helpful strings
;///
;///
;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////




;//////////////////////////////////
;//                             ;//
;//     !!! IMPORTANT !!!       ;//
                                ;//
        PROLOGUE_ON             ;//
                                ;//
;//     !!! IMPORTANT !!!       ;//
;//                             ;//
;//////////////////////////////////




ASSUME_AND_ALIGN
END