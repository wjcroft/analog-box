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
;//     ABox_Plugin.inc     now that plugin editor has a separate file
;//                         we use this to manage the two
;//

        INCLUDE <Abox.inc>
        INCLUDE <vst.inc>
        INCLUDE <groups.inc>
        INCLUDE <midi2.inc>

;//
;// PLUGIN_REGISTRY
;//

    PLUGIN_REGISTRY STRUCT

        slist_Declare_link pluginR, PLUGIN_REGISTRY ;// pointer to next block
        hModule         dd  0   ;// module of the loaded dll
        pMain    ptr_vst_Main 0 ;// pointer to the main() functoin

        pHeadOsc        dd  0   ;// first osc attached

        checksum        dd  0   ;// checksum of the entry
        ;// this is byte for byte compatible with OSC_PLUGIN
        numInputs       dd  0   ;// num inputs reported by plugin
        numOutputs      dd  0   ;// num outputs reported by plugin
        numParameters   dd  0   ;// num parameter reported by plugin        

        szPlugName      db  32 dup (0)  ;// name of this plugin, either from horses mouth, or the dll name
        szFileName      db 280 dup (0)  ;// file name
    
    PLUGIN_REGISTRY ENDS    

    REGISTRY_SAVE_SIZE equ SIZEOF PLUGIN_REGISTRY - OFFSET PLUGIN_REGISTRY.checksum
    REGISTRY_MIN_SAVE  equ OFFSET PLUGIN_REGISTRY.szFileName - OFFSET PLUGIN_REGISTRY.checksum
    REGISTRY_SAVE_START TEXTEQU <checksum>


;//
;// OSC_PLUGIN          see ABox_Plugin.inc
;//


    OSC_PLUGIN  STRUCT

        pRegistry   dd  0   ;// pointer to the plugin registry
        pAEffect    dd  0   ;// pointer to the vst_AEffect struct inside the plugin

        siz       POINT {}  ;// size of the bitmap  (no longer needed)
        extra       dd  0   ;// extra bytes in file, no sense recounting all the time
        pNextOsc    dd  0   ;// pointer to next osc in the registry chain


        ;// start of saved data
        ;// this is also byte for byte compatible with PLUGIN_REGISTRY
        ;// these allow us to instanciate an object, even though we can't locate the plugin
        numInputs     dd 0  ;// this gets saved
        numOutputs    dd 0  ;//
        numParameters dd 0  ;//
        szPlugName db 32 DUP (0);// (8 dwords) name of the plugin, so we can try to locate it
                                ;// if the checksum doesn't pan out
        ;// end of directly saved data
        ;// pParameters points at extra to save
        pParameters dd  0   ;// pointer to an array of floats that are the plugin's settings
                            ;// this is allocated when the object is attached to a plugin

        szDisplayName db 32 dup (0) ;// 8 dwords, name we display

        can_send    dd  0   ;// plug can send midi events
        can_receive dd  0   ;// plug can rececive midi events

    OSC_PLUGIN  ENDS

    ;// save count in dwords

    PLUGIN_MINIMUM_SAVE equ 32/4+3  ;// number of dwords 
                                    ;// makes esi ends up on pParameters
    PLUGIN_SAVE_START TEXTEQU <numInputs>   ;// use this to start saving or xferring



;//
;// PLUGIN_OSC_MAP
;//


    PLUGIN_OSC_MAP STRUCT
    
        OSC_OBJECT  {}
        
        pin_in_1    APIN {} 
        pin_in_2    APIN {} 
        pin_in_3    APIN {} 
        pin_in_4    APIN {} 
        pin_in_5    APIN {} 
        pin_in_6    APIN {} 
        pin_in_7    APIN {} 
        pin_in_8    APIN {} 

        pin_out_1   APIN {} 
        pin_out_2   APIN {} 
        pin_out_3   APIN {} 
        pin_out_4   APIN {} 
        pin_out_5   APIN {} 
        pin_out_6   APIN {} 
        pin_out_7   APIN {} 
        pin_out_8   APIN {}
        
        pin_off     APIN {} 
        pin_si      APIN {}
        pin_so      APIN {}
        
        data_1  dd  SAMARY_LENGTH DUP (?)
        data_2  dd  SAMARY_LENGTH DUP (?)
        data_3  dd  SAMARY_LENGTH DUP (?)
        data_4  dd  SAMARY_LENGTH DUP (?)
        data_5  dd  SAMARY_LENGTH DUP (?)
        data_6  dd  SAMARY_LENGTH DUP (?)
        data_7  dd  SAMARY_LENGTH DUP (?)
        data_8  dd  SAMARY_LENGTH DUP (?)

        ;// data_so dd  SAMARY_LENGTH DUP (?)   ;// ABOX233 removed and replaced with MIDI_QUE_PORTSTREAM

        plug    OSC_PLUGIN {}

        que_portstream  MIDI_QUE_PORTSTREAM {}  ;// ABOX 233 added so we can deal with devices that send events

    PLUGIN_OSC_MAP ENDS



    EXTERNDEF editor_hWnd_Cage:DWORD    ;// handle of editor_hWndProc
    EXTERNDEF editor_hWnd_Animal:DWORD  ;// handle of an animal inside it


    editor_WindowPosChanging PROTO
    editor_Activating PROTO
    editor_Deactivating PROTO
    plugin_LaunchEditor PROTO
    plugin_CloseEditor PROTO
