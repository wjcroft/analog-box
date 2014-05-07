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
;//             -- portions transcribed from Steinberg VSTSDK headers
;// History:
;//
;//     2.41 Mar 04, 2011 AJT
;//         Initial port to GPLv3
;//
;//     ABOX242 AJT -- detabified
;//
;//##////////////////////////////////////////////////////////////////////////
;//             these are the prototypes and structs needed to host plugins
;// vst.inc     function names have been prefixed with vst_ to prevent name collisions
;//             this code was xformed from the vstsdk which is copyrighted by Steinberg
;//
;// Author: Andy J Turner
;// Start Date: mid 2000
;//

IFNDEF _VST_INCLUDED_
_VST_INCLUDED_ EQU 1

;// function protypes

;//---------------------------------------------------------------------------------------------
;//
;//     vst_Main    is supplied by the plugin DLL
;//                 host must call this first
;//                 this the ONLY external definition supplied by the plugin
;//
;//---------------------------------------------------------------------------------------------

    vst_Main TYPEDEF PROTO C pAMCallback:DWORD
    ptr_vst_Main TYPEDEF PTR vst_Main
    ;// the plug will return a pointer to it's AEffect struct after querying the call back

;//---------------------------------------------------------------------------------------------
;//
;// AMCallback      is supplied by the host for the plug to call
;//                 host applications must define this function
;//                 plug >> host
;//---------------------------------------------------------------------------------------------


    vst_AMCallback PROTO C pAEffect:DWORD, dwOpcode:DWORD, dwIndex:DWORD, dwValue:DWORD, dwPtr:DWORD, dwOption:DWORD
    ;// returns a dword value


    ;//---------------------------------------------------------------------------------------------
    ;// ver 1  audioMaster opCodes   from aeffect.h    host application must respond to these
    ;//---------------------------------------------------------------------------------------------

        audioMasterAutomate     EQU 0   ;// index, value, returns 0
        audioMasterVersion      EQU 1   ;// vst version, currently 2 (0 for older)
        audioMasterCurrentId    EQU 2   ;// returns the unique id of a plug that's currently loading
        audioMasterIdle         EQU 3   ;// call application idle routine (this will
                                        ;// call effEditIdle for all open editors too)
        audioMasterPinConnected EQU 4   ;// inquire if an input or output is being connected;
                                        ;// index enumerates input or output counting from zero,
                                        ;// value is 0 for input and != 0 otherwise. note: the
                                        ;// return value is 0 for <true> such that older versions
                                        ;// will always return true.
    ;//---------------------------------------------------------------------------------------------
    ;// new audioMaster opCodes      from aeffectX.h
    ;//---------------------------------------------------------------------------------------------

    ;// VstEvents + VstTimeInfo
        audioMasterWantMidi     EQU 6   ;// <value> is a filter which is currently ignored

        audioMasterGetTime      EQU 7   ;// returns const VstTimeInfo* (or 0 if not supported)
                                        ;// <value> should contain a mask indicating which fields are required
                                        ;// (see valid masks above), as some items may require extensive
                                        ;// conversions
        audioMasterProcessEvents EQU 8  ;// VstEvents* in <ptr>

        audioMasterSetTime      EQU 09h ;// VstTimenfo* in <ptr>, filter in <value>, not supported
        audioMasterTempoAt      EQU 0Ah ;// returns tempo (in bpm * 10000) at sample frame location passed in <value>

        ;// parameters
        audioMasterGetNumAutomatableParameters  EQU 0Bh
        audioMasterGetParameterQuantization     EQU 0Ch ;// returns the integer value for +1.0 representation,
                                                ;// or 1 if full single float precision is maintained
                                                ;// in automation. parameter index in <value> (-1: all, any)
        ;// connections, configuration
        audioMasterIOChanged    EQU 0Dh     ;// numInputs and/or numOutputs has changed
        audioMasterNeedIdle     EQU 0Eh     ;// plug needs idle calls (outside its editor window)
        audioMasterSizeWindow   EQU 0Fh     ;// index: width, value: height
        audioMasterGetSampleRate    EQU 10h
        audioMasterGetBlockSize     EQU 11h
        audioMasterGetInputLatency  EQU 12h
        audioMasterGetOutputLatency EQU 13h
        audioMasterGetPreviousPlug  EQU 14h ;// input pin in <value> (-1: first to come), returns cEffect*
        audioMasterGetNextPlug      EQU 15h ;// output pin in <value> (-1: first to come), returns cEffect*

        ;// realtime info
        audioMasterWillReplaceOrAccumulate  EQU 16h ;// returns: 0: not supported, 1: replace, 2: accumulate
        audioMasterGetCurrentProcessLevel   EQU 17h ;// returns: 0: not supported,
                                            ;// 1: currently in user thread (gui)
                                            ;// 2: currently in audio thread (where process is called)
                                            ;// 3: currently in 'sequencer' thread (midi, timer etc)
                                            ;// 4: currently offline processing and thus in user thread
                                            ;// other: not defined, but probably pre-empting user thread.
        audioMasterGetAutomationState   EQU 18h ;// returns 0: not supported, 1: off, 2:read, 3:write, 4:read/write

        ;// offline
        audioMasterOfflineStart     EQU 19h
        audioMasterOfflineRead      EQU 1Ah ;// ptr points to offline structure, see below. return 0: error, 1 ok
        audioMasterOfflineWrite     EQU 1Bh ;// same as read
        audioMasterOfflineGetCurrentPass    EQU 1Ch
        audioMasterOfflineGetCurrentMetaPass    EQU 1Dh

        ;// other
        audioMasterSetOutputSampleRate  EQU 1Eh ;// for variable i/o, sample rate in <opt>
        audioMasterGetSpeakerArrangement EQU 1Fh;// (long)input in <value>, output in <ptr>
        audioMasterGetVendorString      EQU 20h ;// fills <ptr> with a string identifying the vendor (max 64 char)
        audioMasterGetProductString     EQU 21h ;// fills <ptr> with a string with product name (max 64 char)
        audioMasterGetVendorVersion     EQU 22h ;// returns vendor-specific version
        audioMasterVendorSpecific       EQU 23h ;// no definition, vendor specific handling
        audioMasterSetIcon              EQU 24h ;// void* in <ptr>, format not defined yet
        audioMasterCanDo                EQU 25h ;// string in ptr, see below
        audioMasterGetLanguage          EQU 26h ;// see enum
        audioMasterOpenWindow           EQU 27h ;// returns platform specific ptr
        audioMasterCloseWindow          EQU 28h ;// close window, platform specific handle in <ptr>
        audioMasterGetDirectory         EQU 29h ;// get plug directory, FSSpec on MAC, else char*
        audioMasterUpdateDisplay        EQU 2Ah ;// something has changed, update 'multi-fx' display



;//---------------------------------------------------------------------------------------------
;//
;// dispatcher  is called by the host to tell the plug what to do
;//             host >> plug
;//---------------------------------------------------------------------------------------------

    vst_Dispatcher TYPEDEF PROTO C pAEffect:DWORD, dwOpCode:DWORD, dwIndex:DWORD, dwValue:DWORD, dwPtr:DWORD, fOpt:REAL4
    ptr_vst_Dispatcher TYPEDEF PTR vst_Dispatcher
    ;// returns a long value

    ;// ver1 dispatcher opCodes   from aeffect.h

        effOpen             EQU 00  ;// initialise
        effClose            EQU 01  ;// exit, release all memory and other resources!

        effSetProgram       EQU 02  ;// program no in <value>
        effGetProgram       EQU 03  ;// return current program no.
        effSetProgramName   EQU 04  ;// user changed program name (max 24 char + 0) to as passed in string
        effGetProgramName   EQU 05  ;// stuff program name (max 24 char + 0) into string

        effGetParamLabel    EQU 06  ;// stuff parameter <index> label (max 8 char + 0) into string
                                    ;// (examples: sec, dB, type)
        effGetParamDisplay  EQU 07  ;// stuff parameter <index> textual representation into string
                                    ;// (examples: 0.5, -3, PLATE)
        effGetParamName     EQU 08  ;// stuff parameter <index> label (max 8 char + 0) into string
                                    ;// (examples: Time, Gain, RoomType)
        effGetVu            EQU 09  ;// called if (flags & (effFlagsHasClip | effFlagsHasVu))

        ;// system

        effSetSampleRate    EQU 10  ;// in opt (float)
        effSetBlockSize     EQU 11  ;// in value
        effMainsChanged     EQU 12  ;// the user has switched the 'power on' button to
                                    ;// value (0 off, else on). This only switches audio
                                    ;// processing; you should flush delay buffers etc.
        ;// editor

        effEditGetRect      EQU 13  ;// stuff rect (top, left, bottom, right) into ptr
        effEditOpen         EQU 14  ;// system dependant Window pointer in ptr
        effEditClose        EQU 15  ;// no arguments

        effEditIdle         EQU 19  ;// no arguments. Be gentle!
        ;// mac only ??
        effEditDraw         EQU 16  ;// draw method, ptr points to rect
        effEditMouse        EQU 17  ;// index: x, value: y
        effEditKey          EQU 18  ;// system keycode in value
        effEditTop          EQU 20  ;// window has topped, no arguments
        effEditSleep        EQU 21  ;// window goes to background

        ;// new

        effIdentify         EQU 22  ;// returns 'NvEf'
        effGetChunk         EQU 23  ;// host requests pointer to chunk into (void**)ptr, byteSize returned
        effSetChunk         EQU 24  ;// plug-in receives saved chunk, byteSize passed

        ;// new version 2 parameter codes in aeffectX.h

        ;// VstEvents
        effProcessEvents        EQU 25      ;// VstEvents* in <ptr>

        ;// parameters and programs
        effCanBeAutomated       EQU 26  ;// parameter index in <index>
        effString2Parameter     EQU 27  ;// parameter index in <index>, string in <ptr>
        effGetNumProgramCategories EQU 28;// no arguments. this is for dividing programs into groups (like GM)
        effGetProgramNameIndexed EQU 29 ;// get program name of category <value>, program <index> into <ptr>.
                                        ;// category (that is, <value>) may be -1, in which case program indices
                                        ;// are enumerated linearily (as usual); otherwise, each category starts
                                        ;// over with index 0.
        effCopyProgram          EQU 30  ;// copy current program to destination <index>
                                        ;// note: implies setParameter
        ;// connections, configuration
        effConnectInput         EQU 31  ;// input at <index> has been (dis-)connected;
                                        ;// <value> == 0: disconnected, else connected
        effConnectOutput        EQU 32  ;// same as input
        effGetInputProperties   EQU 33  ;// <index>, VstPinProperties* in ptr, return != 0 => true
        effGetOutputProperties  EQU 34  ;// dto
        effGetPlugCategory      EQU 35  ;// no parameter, return value is category

        ;// realtime
        effGetCurrentPosition   EQU 36  ;// for external dsp, see flag bits below
        effGetDestinationBuffer EQU 37  ;// for external dsp, see flag bits below. returns float*

        ;// offline
        effOfflineNotify        EQU 38  ;// ptr = VstAudioFile array, value = count, index = start flag
        effOfflinePrepare       EQU 39  ;// ptr = VstOfflineTask array, value = count
        effOfflineRun           EQU 40  ;// dto

        ;// other
        effProcessVarIo         EQU 41  ;// VstVariableIo* in <ptr>
        effSetSpeakerArrangement EQU 42 ;// VstSpeakerArrangement* pluginInput in <value>
                                        ;// VstSpeakerArrangement* pluginOutput in <ptr>
        effSetBlockSizeAndSampleRate EQU 43 ;// block size in <value>, sampleRate in <opt>
        effSetBypass            EQU 44  ;// onOff in <value> (0 = off)
        effGetEffectName        EQU 45  ;// char* name (max 32 bytes) in <ptr>
        effGetErrorText         EQU 46  ;// char* text (max 256 bytes) in <ptr>
        effGetVendorString      EQU 47  ;// fills <ptr> with a string identifying the vendor (max 64 char)
        effGetProductString     EQU 48  ;// fills <ptr> with a string with product name (max 64 char)
        effGetVendorVersion     EQU 49  ;// returns vendor-specific version
        effVendorSpecific       EQU 50  ;// no definition, vendor specific handling
        effCanDo                EQU 51  ;// ptr = psz can do string (see audioeffectx.cpp)
        effGetTailSize          EQU 52  ;// returns tail size; 0 is default (return 1 for 'no tail')
        effIdle                 EQU 53  ;// idle call in response to audioMasterneedIdle. must
                                        ;// return 1 to keep idle calls beeing issued
        ;// gui
        effGetIcon              EQU 54  ;// void* in <ptr>, not yet defined
        effSetViewPosition      EQU 55  ;// set view position (in window) to x <index> y <value>

        ;// and...
        effGetParameterProperties EQU 56    ;// of param <index>, VstParameterProperties* in <ptr>
        effKeysRequired         EQU 57  ;// returns 0: needs keys (default for 1.0 plugs), 1: don't need
        effGetVstVersion        EQU 58  ;// returns 2; older versions return 0



    ;//---from here VST 2.1 extension opcodes---------------------------------------------------------
    effEditKeyDown              EQU 59  ;// Character in <index>, virtual in <value>, modifiers in <opt>,
                                        ;// return -1 if not used, return 1 if used
    effEditKeyUp                EQU 60  ;// Character in <index>, virtual in <value>, modifiers in <opt>
                                        ;// return -1 if not used, return 1 if used
    effSetEditKnobMode          EQU 61  ;// Mode in <value>: 0: circular, 1:circular relativ, 2:linear

    ;// midi plugins channeldependent programs
    effGetMidiProgramName       EQU 62  ;// Passed <ptr> points to MidiProgramName struct.
                                        ;// struct will be filled with information for 'thisProgramIndex'.
                                        ;// returns number of used programIndexes.
                                        ;// if 0 is returned, no MidiProgramNames supported.

    effGetCurrentMidiProgram    EQU 63  ;// Returns the programIndex of the current program.
                                        ;// passed <ptr> points to MidiProgramName struct.
                                        ;// struct will be filled with information for the current program.

    effGetMidiProgramCategory   EQU 64  ;// Passed <ptr> points to MidiProgramCategory struct.
                                        ;// struct will be filled with information for 'thisCategoryIndex'.
                                        ;// returns number of used categoryIndexes.
                                        ;// if 0 is returned, no MidiProgramCategories supported.

    effHasMidiProgramsChanged   EQU 65  ;// Returns 1 if the MidiProgramNames or MidiKeyNames
                                        ;// had changed on this channel, 0 otherwise. <ptr> ignored.

    effGetMidiKeyName           EQU 66  ;// Passed <ptr> points to MidiKeyName struct.
                                        ;// struct will be filled with information for 'thisProgramIndex' and
                                        ;// 'thisKeyNumber'. If keyName is "" the standard name of the key
                                        ;// will be displayed. If 0 is returned, no MidiKeyNames are
                                        ;// defined for 'thisProgramIndex'.

    effBeginSetProgram          EQU 67  ;// Called before a new program is loaded
    effEndSetProgram            EQU 68  ;// Called when the program is loaded

    ;//---from here VST 2.3 extension opcodes---------------------------------------------------------
    effGetSpeakerArrangement    EQU 69  ;// VstSpeakerArrangement** pluginInput in <value>
                                        ;// VstSpeakerArrangement** pluginOutput in <ptr>

    effShellGetNextPlugin       EQU 70  ;// This opcode is only called, if plugin is of type kPlugCategShell.
                                        ;// returns the next plugin's uniqueID.
                                        ;// <ptr> points to a char buffer of size 64, which is to be filled
                                        ;// with the name of the plugin including the terminating zero.

    effStartProcess             EQU 71  ;// Called before the start of process call
    effStopProcess              EQU 72  ;// Called after the stop of process call
    effSetTotalSampleToProcess  EQU 73  ;// Called in offline (non RealTime) Process before process is called, indicates how many sample will be processed

    effSetPanLaw                EQU 74  ;// PanLaw : Type (Linear, Equal Power,.. see enum PanLaw Type) in <value>,
                                        ;// Gain in <opt>: for Linear : [1.0 => 0dB PanLaw], [~0.58 => -4.5dB], [0.5 => -6.02dB]
    effBeginLoadBank            EQU 75  ;// Called before a Bank is loaded, <ptr> points to VstPatchChunkInfo structure
                                        ;// return -1 if the Bank can not be loaded, return 1 if it can be loaded else 0 (for compatibility)
    effBeginLoadProgram         EQU 76  ;// Called before a Program is loaded, <ptr> points to VstPatchChunkInfo structure
                                        ;// return -1 if the Program can not be loaded, return 1 if it can be loaded else 0 (for compatibility)








;//---------------------------------------------------------------------------------------------
;//
;//     process     tells the plug to work on audio data
;//
;//---------------------------------------------------------------------------------------------

    vst_Process TYPEDEF PROTO C pAEffect:DWORD, ppInputs:DWORD, ppOutputs:DWORD, dwSampleframes:DWORD
    ptr_vst_Process TYPEDEF PTR vst_Process
    ;// no return value


    vst_ProcessReplacing TYPEDEF PROTO C pAEffect:DWORD, ppInputs:DWORD, ppOutputs:DWORD, dwSampleframes:DWORD
    ptr_vst_ProcessReplacing TYPEDEF PTR vst_ProcessReplacing
    ;// no return value


;//---------------------------------------------------------------------------------------------
;//
;//     set and get     c++ class interface
;//
;//---------------------------------------------------------------------------------------------

    vst_SetParameter TYPEDEF PROTO C pAEffect:DWORD, dwIndex:DWORD, fParameter:REAL4
    ptr_vst_SetParameter TYPEDEF PTR vst_SetParameter
    ;// no return value


    vst_GetParameter TYPEDEF PROTO C pAEffect:DWORD, dwIndex:DWORD
    ptr_vst_GetParameter TYPEDEF PTR vst_GetParameter
    ;// returns the parameter in .... fpu.st(0)


;//---------------------------------------------------------------------------------------------
;//
;//     AEffect   is a bridge between the plug and the host
;//               when vst_Main is called, the plug will fill in it's struct, and return a
;//               pointer to the host application.
;//
;//---------------------------------------------------------------------------------------------

    VST_MAGIC_NUMBER TEXTEQU <'VstP'>

    vst_AEffect STRUCT

        magic      dd VST_MAGIC_NUMBER  ;// must be kEffectMagic ('VstP')

        ;// member functions
        pDispatcher     ptr_vst_Dispatcher      0;// pointer to the dispatcher function
        pProcess        ptr_vst_Process         0;// pointer to the process function
        pSetParameter   ptr_vst_SetParameter    0;// pointer to the set parameter function
        pGetParameter   ptr_vst_GetParameter    0;// pointer to the get parameter function

        ;// member data
        numPrograms     dd 0;
        numParams       dd 0;// all programs are assumed to have numParams parameters
        numInputs       dd 0;//
        numOutputs      dd 0;//
        flags           dd 0;// see constants
        resvd1          dd 0;// reserved, must be 0
        resvd2          dd 0;// reserved, must be 0
        initialDelay    dd 0;// for algorithms which need input in the first place
        realQualities   dd 0;// number of realtime qualities (0: realtime)
        offQualities    dd 0;// number of offline qualities (0: realtime only)
        ioRatio REAL4 0.0e+0;// input samplerate to output samplerate ratio, not used yet
        pObject         dd 0;// for class access (see AudioEffect.hpp), MUST be 0 else!
        pUser           dd 0;// user access
        uniqueID        dd 0;// pls choose 4 character as unique as possible.
                            ;// this is used to identify an effect for save+load
        version         dd 0;//

        ;// more members
        pProcessReplacing ptr_vst_ProcessReplacing   0  ;// pointer to process replacing function

        future  db 60 dup (0)   ;// pls zero

    vst_AEffect ENDS

    ;//---------------------------------------------------------------------------------------------
    ;// AEffect flags bits
    ;//---------------------------------------------------------------------------------------------

        effFlagsHasEditor       EQU 01h ;// if set, is expected to react to editor messages
        effFlagsHasClip         EQU 02h ;// return > 1. in getVu() if clipped
        effFlagsHasVu           EQU 04h ;// return vu value in getVu(); > 1. means clipped
        effFlagsCanMono         EQU 08h ;// if numInputs == 2, makes sense to be used for mono in
        effFlagsCanReplacing    EQU 10h ;// supports in place output (processReplacing() exsists)
        effFlagsProgramChunks   EQU 20h ;// program data are handled in formatless chunks

    ;//---------------------------------------------------------------------------------------------
    ;// AEffectX flags bits
    ;//---------------------------------------------------------------------------------------------

        effFlagsIsSynth         EQU 1 SHL 8 ;// host may assign mixer channels for its outputs
        effFlagsNoSoundInStop   EQU 1 SHL 9 ;// does not produce sound when input is all silence
        effFlagsExtIsAsync      EQU 1 SHL 10;// for external dsp; plug returns immedeately from process()
                                            ;// host polls plug position (current block) via effGetCurrentPosition
        effFlagsExtHasBuffer    EQU 1 SHL 11;// external dsp, may have their own output buffe (32 bit float)
                                            ;// host then requests this via effGetDestinationBuffer

;//---------------------------------------------------------------------------------------------
;//
;//     VstEvents
;//
;//
;//---------------------------------------------------------------------------------------------


    ;// VstEvent types

        kVstMidiType        EQU 1   ;// midi event, can be cast as VstMidiEvent (see below)
        kVstAudioType       EQU 2   ;// audio
        kVstVideoType       EQU 3   ;// video
        kVstParameterType   EQU 3   ;// parameter
        kVstTriggerType     EQU 4   ;// trigger
        ;// ...etc



    VstMidiEvent    STRUCT  ;// to be casted from a VstEvent

        dwType      dd  0   ;// kVstMidiType (docs call this type, clashes with MASM)
        byteSize    dd  24  ;// 24
        deltaFrames dd  0   ;// sample frames related to the current block start sample position
        flags       dd  0   ;// none defined yet

        noteLength  dd  0   ;// (in sample frames) of entire note, if available, else 0
        noteOffset  dd  0   ;// offset into note from note start if available, else 0

        midiData    dd  0   ;// assigned as char in docs;// 1 thru 3 midi bytes; midiData[3] is reserved (zero)
            ;// [0] status
            ;// [1] number
            ;// [2] value
            ;// [3] 0
        detune      db  0   ;// -64 to +63 cents; for scales other than 'well-tempered' ('microtuning')
        noteOffVelocity db  0
        reserved1   db  0   ;// zero
        reserved2   db  0   ;// zero

    VstMidiEvent    ENDS


    VstMidiEvents   STRUCT  ;// a block of events for the current audio block

        numEvents   dd  0
        reserved    dd  0       ;// zero

        ;// VstEvent* events[2];    ;// variable

    VstMidiEvents   ENDS
    ;// an array of VstMidiEvent pointers must follow

;//--------------------------------------------------------------------------------------------------
;// VstTimeInfo as requested via audioMasterGetTime (getTimeInfo())
;// refers to the current time slice. note the new slice is
;// already started when processEvents() is called
;//--------------------------------------------------------------------------------------------------

        VstTimeInfo STRUCT
            r8SamplePos         REAL8 0.0 ;// double current location
            r8SampleRate        REAL8 0.0 ;//   double
            r8NanoSeconds       REAL8 0.0 ;// double system time
            r8PpqPos            REAL8 0.0 ;// double 1 ppq
            r8Tempo             REAL8 0.0 ;// double in bpm
            r8BarStartPos       REAL8 0.0 ;// double last bar start, in 1 ppq
            r8CycleStartPos     REAL8 0.0 ;// double 1 ppq
            r8CycleEndPos       REAL8 0.0 ;// double 1 ppq
            dwTimeSigNumerator  dd  0   ;// long time signature
            dwTimeSigDenominator dd 0   ;// long
            dwSmpteOffset       dd  0   ;// long
            dwSmpteFrameRate    dd  0   ;// long 0:24, 1:25, 2:29.97, 3:30, 4:29.97 df, 5:30 df
            dwSamplesToNextClock dd 0   ;// long midi clock resolution (24 ppq), can be negative
            dwFlags             dd  0   ;// long see below
        VstTimeInfo ENDS

            kVstTransportChanged        EQU 1
            kVstTransportPlaying        EQU 1 SHL 1
            kVstTransportCycleActive    EQU 1 SHL 2

            kVstAutomationWriting       EQU 1 SHL 6
            kVstAutomationReading       EQU 1 SHL 7

            ;// flags which indicate which of the fields in this VstTimeInfo are valid
            ;// r8SamplePos and r8SampleRate are always valid
            kVstNanosValid              EQU 1 SHL 8
            kVstPpqPosValid             EQU 1 SHL 9
            kVstTempoValid              EQU 1 SHL 10
            kVstBarsValid               EQU 1 SHL 11
            kVstCyclePosValid           EQU 1 SHL 12    // start and end
            kVstTimeSigValid            EQU 1 SHL 13
            kVstSmpteValid              EQU 1 SHL 14
            kVstClockValid              EQU 1 SHL 15







ENDIF ;// _VST_INCLUDED_
