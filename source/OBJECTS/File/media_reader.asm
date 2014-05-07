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
;//     ABOX242 AJT
;//         manually set 2 operand sizes for masm 9
;//
;//##////////////////////////////////////////////////////////////////////////
;//
;//     media_reader.asm        implementation of direct show
;//                             media file reader
;//                             xlated from dshow.asm
;//
;//
;//         ver 2
;//         assume no backwards reading
;//         only seek to key frane
;//         assume: if a buffer is ready, it is ok to use
;//                 regardless of where the file pointer is
;//                 meaning: frame skew, time adjusters, drop buffers, are not needed
;//
;//         ver 3
;//         recast as general purpose library for cpp
;//
;//         ABox233: replace with IEnum2
;//
;// TOC (not nessesarily in order)
;//
;// iunknown_QueryUnknown PROC
;//
;// IPin_QueryInterface
;// IPin_AddRef::
;// IPin_Release::
;// IPin_ConnectionMediaType::
;// IPin_QueryId::
;// IPin_QueryAccept::
;// IPin_Connect::
;// IPin_QueryInternalConnections::
;// IPin_ReceiveConnection
;// IPin_Disconnect
;// IPin_ConnectedTo
;// IPin_QueryPinInfo
;// IPin_QueryDirection
;// IPin_EnumMediaTypes
;// IPin_EndOfStream
;// IPin_BeginFlush
;// IPin_EndFlush
;// IPin_NewSegment
;//
;// IMemInputPin_QueryInterface::
;// IMemInputPin_AddRef::
;// IMemInputPin_Release
;// IMemInputPin_GetAllocator::
;// IMemInputPin_GetAllocatorRequirements::
;// IMemInputPin_NotifyAllocator
;// IMemInputPin_Receive
;// IMemInputPin_ReceiveMultiple
;// IMemInputPin_ReceiveCanBlock
;//
;// IMediaFilter_QueryInterface
;// IMediaFilter_AddRef
;// IMediaFilter_Release
;// IMediaFilter_GetClassID::
;// IMediaFilter_GetSyncSource::
;// IMediaFilter_QueryVendorInfo::
;// IMediaFilter_GetState::
;// IMediaFilter_FindPin::
;// IMediaFilter_Stop
;// IMediaFilter_Pause
;// IMediaFilter_Run
;// IMediaFilter_SetSyncSource
;// IMediaFilter_EnumPins
;// IMediaFilter_QueryFilterInfo
;// IMediaFilter_JoinFilterGraph
;//
;// reader_Initialize
;// reader_Destroy
;//
;// reader_prepare_buffer
;// intmul_p0064_x_64   media time to samples
;// intmul_32_x_64      samples to media time
;//
;// reader_Open
;// reader_CheckState
;// reader_ReadBuffers
;// reader_Close


OPTION CASEMAP:NONE
.586
.MODEL FLAT

USE_THIS_FILE equ 1
IFDEF USE_THIS_FILE

    .NOLIST
    INCLUDE <Abox.inc>
    INCLUDE <qword.inc>
    INCLUDE <com.inc>
    INCLUDE <DirectShow.inc>
    INCLUDE <IEnum2.inc>
    INCLUDE <ABox_OscFile.inc>
    .LIST
    ;//.LISTALL
    ;//.LISTMACROALL

.DATA


;///////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////
;///
;///
;///    com iterfacing
;///


    pClassFactory   dd  0   ;// ptr to the filter graph class factory
    ;// if this value is zero, then we cannot use media reader

;// com_initialized dd  0   ;// just says that we initialized com
                            ;// moved to app_Main

;///////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////
;///
;///
;///    COM VTABLES
;///

    IPin_vtable LABEL DWORD

        dd  IPin_QueryInterface
        dd  IPin_AddRef
        dd  IPin_Release
        dd  IPin_Connect
        dd  IPin_ReceiveConnection
        dd  IPin_Disconnect
        dd  IPin_ConnectedTo
        dd  IPin_ConnectionMediaType
        dd  IPin_QueryPinInfo
        dd  IPin_QueryDirection
        dd  IPin_QueryId
        dd  IPin_QueryAccept
        dd  IPin_EnumMediaTypes
        dd  IPin_QueryInternalConnections
        dd  IPin_EndOfStream
        dd  IPin_BeginFlush
        dd  IPin_EndFlush
        dd  IPin_NewSegment

    IMemInputPin_vtable LABEL DWORD

        dd  IMemInputPin_QueryInterface
        dd  IMemInputPin_AddRef
        dd  IMemInputPin_Release
        dd  IMemInputPin_GetAllocator
        dd  IMemInputPin_NotifyAllocator
        dd  IMemInputPin_GetAllocatorRequirements
        dd  IMemInputPin_Receive
        dd  IMemInputPin_ReceiveMultiple
        dd  IMemInputPin_ReceiveCanBlock

    IMediaFilter_vtable LABEL DWORD

        dd  IMediaFilter_QueryInterface
        dd  IMediaFilter_AddRef
        dd  IMediaFilter_Release
        dd  IMediaFilter_GetClassID
        dd  IMediaFilter_Stop
        dd  IMediaFilter_Pause
        dd  IMediaFilter_Run
        dd  IMediaFilter_GetState
        dd  IMediaFilter_SetSyncSource
        dd  IMediaFilter_GetSyncSource
        dd  IMediaFilter_EnumPins
        dd  IMediaFilter_FindPin
        dd  IMediaFilter_QueryFilterInfo
        dd  IMediaFilter_JoinFilterGraph
        dd  IMediaFilter_QueryVendorInfo




;//////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////
;//
;//     theres a lot of com interfaces and we use stack based addressing
;//     so here's a macro to help out

    st_pThis TEXTEQU <DWORD PTR [esp+4]>


;//     here are some translation macros
;//     to get from one interface to another

;// use these to create a new reg ptr

    XLATE_OBJECT MACRO reg1:req, reg2, delta, assum
        IFB <reg2>
            add reg1, delta
            ASSUME reg1:PTR assum
        ELSE
            lea reg2, [reg1+delta]
            ASSUME reg2:PTR assum
        ENDIF
        ENDM

    IFILTER_TO_IMEMINPUTPIN MACRO reg1:req, reg2
        XLATE_OBJECT reg1, reg2, IMEDIAREADER.meminputpin - IMEDIAREADER.filter, IMEMINPUTPIN
        ENDM

    IFILTER_TO_IPIN MACRO reg1:req, reg2
        XLATE_OBJECT reg1, reg2, IMEDIAREADER.pin - IMEDIAREADER.filter,IPIN
        ENDM

    IPIN_TO_IFILTER MACRO reg1:req, reg2
        XLATE_OBJECT reg1, reg2, IMEDIAREADER.filter - IMEDIAREADER.pin, IFILTER
        ENDM

    IPIN_TO_IMEMINPUTPIN MACRO reg1:req, reg2
        XLATE_OBJECT reg1, reg2, IMEDIAREADER.meminputpin - IMEDIAREADER.pin, IMEMINPUTPIN
        ENDM

    ;// ABOX233 added see videopipe project
    IMEMINPUTPIN_TO_IPIN MACRO reg1:req, reg2
        XLATE_OBJECT reg1, reg2, IMEDIAREADER.pin-IMEDIAREADER.meminputpin, IPIN
        ENDM

    IMEMINPUTPIN_TO_IMEDIAREADER MACRO reg1:req, reg2
        XLATE_OBJECT reg1, reg2, 0-IMEDIAREADER.meminputpin, IMEDIAREADER
        ENDM

    IPIN_TO_IMEDIAREADER MACRO reg1:req, reg2
        XLATE_OBJECT reg1, reg2, 0-IMEDIAREADER.pin, IMEDIAREADER
        ENDM


;// use these to get at data in another section

    IMemInputPin_to_IMediaFilter MACRO reg:req
        EXITM <(IFILTER PTR [reg+IMEDIAREADER.filter-IMEDIAREADER.meminputpin])>
        ENDM

    IMediaFilter_to_IPin MACRO reg:req
        EXITM <(IPIN PTR [reg+IMEDIAREADER.pin-IMEDIAREADER.filter])>
        ENDM

    IPin_to_IMediaFilter MACRO reg:req
        EXITM <(IFILTER PTR [reg+IMEDIAREADER.filter-IMEDIAREADER.pin])>
        ENDM

    IPin_to_IMemInputPin MACRO reg:req
        EXITM <(IMEMINPUTPIN PTR [reg+IMEDIAREADER.meminputpin-IMEDIAREADER.pin])>
        ENDM

    IPin_to_IMediaReader MACRO reg:req
        EXITM <(IMEDIAREADER PTR [reg-IMEDIAREADER.pin])>
        ENDM

    IMemInputPin_to_IMediaReader MACRO reg:req
        EXITM <(IMEDIAREADER PTR [reg-IMEDIAREADER.meminputpin])>
        ENDM

    IMediaFilter_to_IMediaReader MACRO reg:req
        EXITM <(IMEDIAREADER PTR [reg-IMEDIAREADER.filter])>
        ENDM



;///////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////
;///
;///
;///    guids we need
;///

        MAKE_GUID IID_IUnknown,     00000000-0000-0000-C000-000000000046
        MAKE_GUID IID_IClassFactory,00000001-0000-0000-C000-000000000046
        MAKE_GUID IID_IPin,         56a86891-0ad4-11ce-b03a-0020af0ba770
        MAKE_GUID IID_IMemInputPin, 56a8689d-0ad4-11ce-b03a-0020af0ba770
        MAKE_GUID IID_IGraphBuilder,56a868a9-0ad4-11ce-b03a-0020af0ba770
        MAKE_GUID IID_IMediaControl,56A868B1-0AD4-11CE-B03A-0020AF0BA770
        MAKE_GUID CLSID_FilterGraph,e436ebb3-524f-11ce-9f53-0020af0ba770
        MAKE_GUID TIME_FORMAT_SAMPLE,7b785572-8c82-11cf-bc0c-00aa00ac74f6
        MAKE_GUID TIME_FORMAT_MEDIA_TIME, 7b785574-8c82-11cf-bc0c-00aa00ac74f6
        MAKE_GUID IID_IMediaSeeking,36B73880-C2C8-11CF-8B46-00805F6CEF60
    ;// MAKE_GUID IID_IMediaPosition,56A868B2-0AD4-11CE-B03A-0020AF0BA770

        ;//MAKE_GUID g_IReferenceClock,56a86897-0ad4-11ce-b03a-0020af0ba770
        ;//
        ;//IBasicAudio          56A868B3-0AD4-11CE-B03A-0020AF0BA770
        ;//IVideoWindow         56A868B4-0AD4-11CE-B03A-0020AF0BA770
        ;//IBasicVideo          56A868B5-0AD4-11CE-B03A-0020AF0BA770



;//////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////
;///
;///    AM_MEDIA_TYPE
;///

    mediatype_01 LABEL GUID

        ;// major type
        MAKE_GUID MEDIATYPE_Audio,  73647561-0000-0010-8000-00AA00389B71

        ;// sub type
        MAKE_GUID MEDIASUBTYPE_PCM, 00000001-0000-0010-8000-00AA00389B71

        dd  1   ;// bFixedSizeSamples
        dd  0   ;// bTemporalCompression
        dd  0   ;// lSampleSize

        ;// formattype
        MAKE_GUID FORMAT_WaveFormatEx, 05589f81-c356-11ce-bf01-00aa0055595a

        dd  0                   ;// pUnk
        dd  0;// SIZEOF WAVEFORMATEX ;// cbFormat
        ;//EXTERNDEF Wave_Format:WAVEFORMATEX   ;// defined in ABox_WavOut.asm
        dd  0;// OFFSET Wave_Format ;// pFormat


    media_penum2    dd  OFFSET mediatype_01, 0  ;// zero terminated list for IEnum2_Ctor

;//////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////
;//
;// sequencing helpers
;//

    ;// seeking limits

        ;// reset by    reader_CheckState
        ;// updated by  reader_ReadBuffers

        NUM_READER_WAITS    EQU 16
        reader_waits        dd  0   ;// prevents excessive waiting

        NUM_READER_SEEKS    EQU 16
        reader_seeks        dd  0   ;// prevents excessive seeking


    ;// tables

    chanbits_shift_table    LABEL DWORD
    ;// this table shifts samples to bytes

        dd  0   ;// 0   8 bit mono byte
        dd  1   ;// 1   16bit mono word
        dd  2   ;// 2   32bit mono dword
        dd  1   ;// 3   8 bit stereo
        dd  2   ;// 4   16bit stereo
        dd  3   ;// 5   32bit stereo



    chanbits_xfer_table     LABEL DWORD
    ;// this jumps to the correct IMemInputPin_Receive loop

        dd  xfer_8_mono     ;// 0   8 bit mono byte
        dd  xfer_16_mono    ;// 1   16bit mono word
        dd  xfer_32_mono    ;// 2   32bit mono dword
        dd  xfer_8_stereo   ;// 3   8 bit stereo
        dd  xfer_16_stereo  ;// 4   16bit stereo
        dd  xfer_32_stereo  ;// 5   32bit stereo



.CODE

;///////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////
;///
;///
;///    generic iunknown_QueryUnknown
;///

ASSUME_AND_ALIGN
iunknown_QueryUnknown PROC ;// STDCALL pRet pThis refID pInterface
                            ;//         4     8     12      16

    ;// task: check for IUnknown
    ;//     if found, call add ref and return to pRet
    ;//     otherwise, return to caller with ecx set as ref id


        IFDEF DEBUGBUILD
        FILE_DEBUG_MESSAGE <"iunknown_QueryUnknown\n">
        ENDIF

    ;// ABOX240 -- force clearing of caller's pInterface
    ;// some apps don't follow the rules and crash by not looking at the return value

        xor eax, eax
        mov edx, [esp+16]
        mov [edx],eax



        mov ecx, [esp+12]
        mov edx, OFFSET IID_IUnknown
        IF_GUID_DIFFERENT_GOTO edx, ecx, no_match

    got_iunknown:

        pop ecx             ;// kill the return pointer
        mov eax, [esp+4]    ;// get this
        mov edx, [esp+12]   ;// get the return pointer
        mov [edx], eax      ;// set it

        com_invoke IUnknown, AddRef, eax    ;// add ref
        xor eax, eax        ;// return sucess

        ret 12  ;// retturn to pRet

    ALIGN 16
    no_match:   ;// just return

        FILE_DEBUG_MESSAGE <"not_found\n">

        ret

iunknown_QueryUnknown   ENDP



;///////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////
;///
;///
;///    CONDENSED INTERFACES
;///


;// 1 PARAM
;//ASSUME_AND_ALIGN
;//
;// mov eax, E_NOTIMPL
;// ret 4


;// 2 PARAMS
ASSUME_AND_ALIGN
IPin_ConnectionMediaType::      ;// PROC ;//STDCALL pThis, pMediaType
    IFDEF DEBUGBUILD
    FILE_DEBUG_MESSAGE <"E_NOTIMPL__IPin_ConnectionMediaType\n">
    jmp G2
    ENDIF
IPin_QueryId::                  ;// PROC ;//STDCALL pThis, pszwId
    IFDEF DEBUGBUILD
    FILE_DEBUG_MESSAGE <"E_NOTIMPL__IPin_QueryId\n">
    jmp G2
    ENDIF
IPin_QueryAccept::              ;// PROC ;//STDCALL pThis, pMediaType
    IFDEF DEBUGBUILD
    FILE_DEBUG_MESSAGE <"E_NOTIMPL__IPin_QueryAccept\n">
    jmp G2
    ENDIF
IMemInputPin_GetAllocator::     ;// PROC ;//STDCALL pThis, ppAllocator
    IFDEF DEBUGBUILD
    FILE_DEBUG_MESSAGE <"E_NOTIMPL__IMemInputPin_GetAllocator\n">
    jmp G2
    ENDIF
IMediaFilter_GetClassID::       ;// PROC ;//STDCALL pThis, ppClsid
    IFDEF DEBUGBUILD
    FILE_DEBUG_MESSAGE <"E_NOTIMPL__IMediaFilter_GetClassID\n">
    jmp G2
    ENDIF
IMediaFilter_GetSyncSource::    ;// PROC ;//STDCALL pThis, ppClock
    IFDEF DEBUGBUILD
    FILE_DEBUG_MESSAGE <"E_NOTIMPL__IMediaFilter_GetSyncSource\n">
    jmp G2
    ENDIF
IMediaFilter_QueryVendorInfo::  ;// PROC ;//STDCALL pThis, pwszVendorInfo
    IFDEF DEBUGBUILD
    FILE_DEBUG_MESSAGE <"E_NOTIMPL__IMediaFilter_QueryVendorInfo\n">
    jmp G2
    ENDIF
IMemInputPin_GetAllocatorRequirements:: ;// PROC ;//STDCALL pThis,pProps
    IFDEF DEBUGBUILD
    FILE_DEBUG_MESSAGE <"E_NOTIMPL__IMemInputPin_GetAllocatorRequirements\n">
    jmp G2
    ENDIF

G2: FILE_DEBUG_MESSAGE <"generic_2Param\n">

    mov eax, E_NOTIMPL
    ret 8

;// 3 PARAMS

ASSUME_AND_ALIGN
IPin_Connect::                  ;// PROC ;//STDCALL pThis,pReceivePin,pMediaType
    IFDEF DEBUGBUILD
    FILE_DEBUG_MESSAGE <"E_NOTIMPL__IPin_Connect\n">
    jmp G3
    ENDIF
IPin_QueryInternalConnections:: ;// PROC ;//STDCALL pThis, ppPin, pNumPin
    IFDEF DEBUGBUILD
    FILE_DEBUG_MESSAGE <"E_NOTIMPL__IPin_QueryInternalConnections\n">
    jmp G3
    ENDIF
IMediaFilter_FindPin::          ;// PROC ;//STDCALL pThis, pwszID, ppPin
    IFDEF DEBUGBUILD
    FILE_DEBUG_MESSAGE <"E_NOTIMPL__IMediaFilter_FindPin\n">
    jmp G3
    ENDIF

G3: FILE_DEBUG_MESSAGE <"generic_3Param\n">

    mov eax, E_NOTIMPL
    ret 12


;// generic QueryInterface

comment ~ /*
ASSUME_AND_ALIGN
IMemInputPin_QueryInterface::       ;// PROC ;// STDCALL pThis, pRefID, ppvObject
ECHO need to check for IPin and return the the appropriate value
ECHO see slow video project
.ERR
    IFDEF DEBUGBUILD
    FILE_DEBUG_MESSAGE <"IMemInputPin_QueryInterface\n">
    jmp GQI
    ENDIF
*/ comment ~
GQI:FILE_DEBUG_MESSAGE <"____generic_QueryInterface\n">

    call iunknown_QueryUnknown
    ;// returns if interface is not found
    mov eax, E_NOINTERFACE

    ret 12

;// generic AddRef
ASSUME_AND_ALIGN
IMemInputPin_AddRef::       ;// PROC ;// STDCALL pThis
    IFDEF DEBUGBUILD
    FILE_DEBUG_MESSAGE <"IMemInputPin_AddRef\n">
    jmp GQA
    ENDIF
IPin_AddRef::               ;// PROC ;//STDCALL pThis
    IFDEF DEBUGBUILD
    FILE_DEBUG_MESSAGE <"IPin_AddRef\n">
    jmp GQA
    ENDIF

GQA:FILE_DEBUG_MESSAGE <"____generic_AddRef\n">

    mov eax, st_pThis
    inc DWORD PTR [eax+4]
    mov eax, DWORD PTR [eax+4]

    ret 4

;// genericRelease
ASSUME_AND_ALIGN
IPin_Release::      ;// PROC ;//STDCALL pThis
    IFDEF DEBUGBUILD
    FILE_DEBUG_MESSAGE <"IPin_Release\n">
    jmp GQR
    ENDIF
IMemInputPin_Release::
    IFDEF DEBUGBUILD
    FILE_DEBUG_MESSAGE <"IMemInputPin_Release\n">
    jmp GQR
    ENDIF

GQR:FILE_DEBUG_MESSAGE <"____generic_Release\n">

    mov eax, st_pThis
    dec DWORD PTR [eax+4]
    mov eax, DWORD PTR [eax+4]
    ret 4




;///////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////
;///
;///
;///    IPin
;///


;// IUnknown

ASSUME_AND_ALIGN
IPin_QueryInterface PROC ;//STDCALL pThis, pRefID, ppvObject

        FILE_DEBUG_MESSAGE <"IPin_QueryInterface\n">

    ;// try IUnknown first

        call iunknown_QueryUnknown
        ;// if it returns then it didn't find it
        ;// we also know that ecx has the ref id

    ;// check for mem input pin

        mov edx, OFFSET IID_IMemInputPin
        IF_GUID_DIFFERENT_GOTO ecx, edx, M3

    ;// got IMemInputPin

        FILE_DEBUG_MESSAGE <"IPin_QueryInterface_got_IMemInputPin\n">

        com_GetObject st_pThis, eax, IPIN
        IPIN_TO_IMEMINPUTPIN eax
        jmp all_done

    ;// got nothing we care about

    M3: xor eax, eax

    all_done:

        mov edx, [esp+12]
        mov [edx], eax

        .IF eax
            com_invoke IUnknown, AddRef, eax
            xor eax, eax
        .ELSE
            mov eax, E_NOINTERFACE
        .ENDIF

    ret 12

IPin_QueryInterface ENDP

;// IPin


ASSUME_AND_ALIGN
IPin_ReceiveConnection PROC ;//STDCALL pThis, pConnectPin, pMediaType
                            ;//         4       8           12
        FILE_DEBUG_MESSAGE <"IPin_ReceiveConnection\n">

    ;// verify type
    ;// graph builder passes us many values
    ;// so we'll try a few before we give up

    IFDEF DEBUGBUILD
    IF FILE_DEBUG_IS_ON EQ 2
    ECHO fixme
    comment ~ /*
    ;// what's goin on here ?!!
        mov ecx, [esp+12]           ;// get the AM_MEDIA_TYPE ptr
        DEBUG_DUMP_GUID ecx
        add ecx, SIZEOF GUID        ;// scoot to sub type
        DEBUG_DUMP_GUID ecx
        add ecx, 12 + SIZEOF GUID   ;// scoot to format type
        DEBUG_DUMP_GUID ecx
    */ comment ~
    ENDIF
    ENDIF

    ;// try the major type first

        mov ecx, [esp+12]   ;// get the AM_MEDIA_TYPE ptr

        mov edx, OFFSET MEDIATYPE_Audio             ;// MEDIATYPE_AUDIO
        IF_GUID_SAME_GOTO edx, ecx, check_subtype

    no_connect:

        mov eax, E_FAIL ;// S_FALSE ;// FAIL
                        ;// documentation is WRONG, return E_FAIL

        FILE_DEBUG_MESSAGE <"IPin_ReceiveConnection__Rejected\n">

        jmp all_done

    check_subtype:

        add ecx, SIZEOF GUID        ;// scoot to sub type

        mov edx, OFFSET MEDIASUBTYPE_PCM    ;// MEDIASUBTYPE_PCM
        IF_GUID_DIFFERENT_GOTO edx, ecx, no_connect

    check_format_type:

        add ecx, 12 + SIZEOF GUID   ;// scoot to format type

        mov edx, OFFSET FORMAT_WaveFormatEx     ;// FORMAT_WaveFormatEx
        IF_GUID_DIFFERENT_GOTO edx, ecx, no_connect

    ;// check the wave format (forces loading of ACM WRAPPER)
    check_wave_format:

        mov ecx, [ecx+AM_MEDIA_TYPE.pFormat - AM_MEDIA_TYPE.formattype]
        ASSUME ecx:PTR WAVEFORMATEX

        test ecx, ecx   ;// check for no format
        jz no_connect

        cmp [ecx].wBitsPerSample, 8     ;// can be 8 bit
        je accept_connection

        cmp [ecx].wBitsPerSample, 16    ;// can be 16 bit
        je accept_connection

        cmp [ecx].wBitsPerSample, 32    ;// can be 32 bit
        je accept_connection

        jmp no_connect

    ;// accept connection
    accept_connection:

        com_GetObject st_pThis, edx, IPIN

    ;// transfer rate settings to our struct

        mov eax, [ecx].dwSamplesPerSec
        mov IPin_to_IMediaReader(edx).rate, eax

        movzx eax, [ecx].wChannels
        mov IPin_to_IMediaReader(edx).chan, eax

        movzx eax, [ecx].wBitsPerSample
        mov IPin_to_IMediaReader(edx).bits, eax

    ;// connect pins

        mov eax, [esp+8]                ;// get the connection pin
        mov IPin_to_IMediaReader(edx).pConnectedPin, eax    ;// store in our pin
        com_invoke IUnknown, AddRef, eax;// add ref on connected pin

    ;// return success

        xor eax, eax

        FILE_DEBUG_MESSAGE <"IPin_ReceiveConnection__Accepted\n">

    all_done:

        ret 12

IPin_ReceiveConnection ENDP

ASSUME_AND_ALIGN
IPin_Disconnect PROC ;//STDCALL pThis

        FILE_DEBUG_MESSAGE <"IPin_Disconnect\n">

        xor eax, eax
        com_GetObject st_pThis, ecx, IPIN
        xchg IPin_to_IMediaReader(ecx).pConnectedPin, eax
        .IF eax
            ASSUME eax:PTR IPin
            com_invoke IPin, Release, eax
            xor eax, eax
        .ENDIF

        ret 4

IPin_Disconnect ENDP

ASSUME_AND_ALIGN
IPin_ConnectedTo PROC ;//STDCALL pThis, ppPin

        FILE_DEBUG_MESSAGE <"IPin_ConnectedTo\n">

        com_GetObject st_pThis, ecx, IPIN
        mov edx, [esp+8]
        mov eax, IPin_to_IMediaReader(ecx).pConnectedPin
        mov [edx], eax
        .IF eax
            ASSUME eax:PTR IPin
            com_invoke IPin, AddRef, eax
            xor eax, eax
        .ENDIF

        ret 8

IPin_ConnectedTo ENDP

ASSUME_AND_ALIGN
IPin_QueryPinInfo PROC ;//STDCALL pThis, pPinInfo

    FILE_DEBUG_MESSAGE <"IPin_QueryPinInfo\n">

    mov ecx, st_pThis

    xor eax, eax            ;// return value and zero

    com_GetObject [esp+8], edx, PIN_INFO

    IPIN_TO_IFILTER ecx     ;// bump IPin to IFilter
    mov [edx].pFilter, ecx  ;// store the filter pointer
    inc [ecx].ref_count     ;// have to call addref on filter

    mov [edx].direction, eax    ;// set as input pin
    mov DWORD PTR [edx].wszName, eax    ;// no name

    ret 8

IPin_QueryPinInfo ENDP

ASSUME_AND_ALIGN
IPin_QueryDirection PROC ;//STDCALL pThis,pPinDir

    FILE_DEBUG_MESSAGE <"IPin_QueryDirection\n">

    mov edx, [esp+8]    ;// get the results
    xor eax, eax        ;// input pin
    mov [edx], eax      ;// store as input

    ret 8

IPin_QueryDirection ENDP


;// from slowvideo project
ASSUME_AND_ALIGN
enum_mediatypes_ctor PROC STDCALL USES esi edi pSource:DWORD

    ;// task: return the a new media type pointer in eax
    ;//         copy everything accurately

        mov esi, pSource
        ASSUME esi:PTR AM_MEDIA_TYPE
        mov eax, [esi].cbFormat
        add eax, SIZEOF AM_MEDIA_TYPE
        invoke CoTaskMemAlloc, eax
        mov ecx, SIZEOF AM_MEDIA_TYPE
        ASSUME eax:PTR AM_MEDIA_TYPE
        mov edi, eax
        rep movsb
        mov esi, [eax].pFormat  ;// load where the old format was
        ASSUME esi:NOTHING
        mov ecx, [eax].cbFormat ;// get the format size
        mov [eax].pFormat, edi  ;// save ptr to new format, we just moved it
        rep movsb               ;// copy the rest of the format
        ;// heaven help us if there are more pointers ...
        DEBUG_IF <[eax].pUnk>
        ;//.IF [eax].pUnk   ;// do we need to add ref ?
        ;// int 3   ;// bah !
        ;//.ENDIF

        ret

enum_mediatypes_ctor ENDP


ASSUME_AND_ALIGN
IPin_EnumMediaTypes PROC ;//STDCALL pThis, ppEnum

    FILE_DEBUG_MESSAGE <"IPin_EnumMediaTypes\n">

    invoke IEnum2_ctor, OFFSET media_penum2,OFFSET enum_mediatypes_ctor,0

    ;// eax has correct return code
    ;// edx has ienum or zero
    mov ecx, [esp+8]
    mov [ecx], edx

    ret 8

IPin_EnumMediaTypes ENDP


ASSUME_AND_ALIGN
IPin_EndOfStream PROC ;//STDCALL pThis

        FILE_DEBUG_MESSAGE <"IPin_EndOfStream\n">

    ;// set our flags

        com_GetObject st_pThis, ecx, IPIN
        xor eax, eax
        or IPin_to_IMediaReader(ecx).state, READER_END_OF_STREAM

    ;// notify filter graph, why ??

    ;// pushd 0
    ;// com_invoke IGraphBuilder, QueryInterface, IPin_to_filter(ecx).pGraph, OFFSET IID_IMediaEventSink, esp
    ;// pop ecx

    ;// com_invoke IMediEventSink, Notify


    ;// return sucess

        ret 4

IPin_EndOfStream ENDP

ASSUME_AND_ALIGN
IPin_BeginFlush PROC ;//STDCALL pThis

        FILE_DEBUG_MESSAGE <"IPin_BeginFlush_ENTER\n">

    ;// get the object, preserve ebx

        xchg ebx, st_pThis
        IPIN_TO_IMEDIAREADER ebx

    ;// set the flags correctly

        or [ebx].state, READER_FLUSHING
        and [ebx].state, NOT READER_END_OF_STREAM

    ;// wait for any recieve operations to complete

        .WHILE [ebx].state & READER_IN_RECEIVE
            .IF [ebx].state & READER_IS_WAITING
                FILE_DEBUG_MESSAGE <"IPin_BeginFlush__pulsing\n">
                invoke PulseEvent, [ebx].hEvent
            .ENDIF
            FILE_DEBUG_MESSAGE <"IPin_BeginFlush__sleeping\n">
            invoke Sleep, 1
        .ENDW

    ;// get ebx

        mov ebx, st_pThis

    ;// return sucess   ;// eax alreay = 0

        FILE_DEBUG_MESSAGE <"IPin_BeginFlush_EXIT\n">

        ret 4

IPin_BeginFlush ENDP

ASSUME_AND_ALIGN
IPin_EndFlush PROC ;//STDCALL pThis

        FILE_DEBUG_MESSAGE <"IPin_EndFlush\n">

    ;// turn offthe flag

        com_GetObject st_pThis, ecx, IPIN
        xor eax, eax
        and IPin_to_IMediaReader(ecx).state, NOT READER_FLUSHING

    ;// return sucess

        ret 4

IPin_EndFlush ENDP



ASSUME_AND_ALIGN     ;//
IPin_NewSegment PROC ;//STDCALL pThis,tStart_lo,t_start_hi,tStop_lo,tStop_hi,dRate_lo,dRate_hi
                     ;//        4       8         12        16        20       24      28

        FILE_DEBUG_MESSAGE <"IPin_NewSegment\n">

    ;// by inspection, we should never be inside IMemInputPin_Receive
    ;// so we don't need to synchronize

    ;// tasks: reset endof stream

        com_GetObject st_pThis, ecx, IPIN
        xor eax, eax
        and IPin_to_IMediaReader(ecx).state, NOT READER_END_OF_STREAM

    ;// that's it (eax better be zero)

        ret 28

IPin_NewSegment ENDP






;///////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////
;///
;///
;///    IMemInputPin
;///

;// ABOX233 added, see video pipe project
ASSUME_AND_ALIGN
IMemInputPin_QueryInterface PROC ;// STDCALL pThis, pRefID, ppvObject
                                ;//  00     04      08      0C
        FILE_DEBUG_MESSAGE <"IMemInputPin_QueryInterface\n">

    ;// try iunknown first

        call iunknown_QueryUnknown

    ;// if it returns then we didn't find it
    ;// ecx is also pRefID

        mov edx, OFFSET IID_IPin
        IF_GUID_SAME_GOTO edx, ecx, got_ipin
;//     mov edx, OFFSET IID_IMediaPosition
;//     IF_GUID_SAME_GOTO edx, ecx, got_media_seeking

    ;// that's it !
    return_fail:

        mov eax, E_NOINTERFACE

    all_done:

        retn 12

    ALIGN 16
    got_ipin:

        FILE_DEBUG_MESSAGE <"got_IPin\n">
        com_GetObject st_pThis, ecx, IMEMINPUTPIN
        mov edx, [esp+0Ch]
        IMEMINPUTPIN_TO_IPIN ecx
        mov [edx], ecx
        com_invoke IUnknown, AddRef, ecx
        xor eax, eax
        jmp all_done

IMemInputPin_QueryInterface ENDP




ASSUME_AND_ALIGN
IMemInputPin_NotifyAllocator PROC   ;// STDCALL pThis, pAllocator, bReadOnly

    FILE_DEBUG_MESSAGE <"IMemInputPin_NotifyAllocator\n">

    xor eax, eax    ;// must always return sucess
                    ;// this took many many days to discover
    ret 12


IMemInputPin_NotifyAllocator ENDP

;/////////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////////

comment ~ /*

    check for invalid state

        READER_FLUSHING OR READER_END_OF_STREAM
        READER_STATE_TEST
        exit

    enter_function

    get the frame times
    get the buffer size and pointer

    check for discontinous frames

    is there a buffer to fill ?
    NO:

        check if we are supposed to drop the buffer
        YES:
            drop the buffer
            exit Receive
        NO:
            wait for buffer

    YES:

        process the buffer
        1) exit Receive
        2) wait for buffer

    ;/////////////////////////////////////////////////////

    task:

        transfer data to a file buffer
        if neither are busy, then wait

    input format states

    /        8 bit  \
    | mono   16 bit |
    | stereo 24 bit |
    \        32 bit /

    we are guaranteed to have partial buffers
    meaning we'll need multiple passes from time to time

    synchronization is accomplished by waiting for input buffers to be ready

    for this function, we assume these registers:

        ebx = IMEDIAREADER
        esi = source ptr (iterated)
        ebp = samples remaining (in sample units)


*/ comment ~

IFDEF DEBUGBUILD
IF FILE_DEBUG_IS_ON EQ 2
ECHO fixme
comment ~ /*
    READER_DUMP_START_TIME MACRO        ;// debug macro

        IFDEF DEBUGBUILD
        ;// show time after adjustment
        lea ecx, [ebx].frame_start_lo
        DEBUG_MESSAGE_1Q ecx
        ENDIF

        ENDM

    READER_DUMP_STARTSTOP_TIME MACRO        ;// debug macro

        IFDEF DEBUGBUILD
        ;// show time after adjustment
        lea ecx, [ebx].frame_start_lo
        DEBUG_MESSAGE_2Q ecx
        ENDIF

        ENDM
*/ comment ~
ENDIF
ENDIF




ASSUME_AND_ALIGN
IMemInputPin_Receive PROC ;// STDCALL pThis,pSample
                          ;//   00     04     08

        FILE_DEBUG_MESSAGE <"IMemInputPin_Receive_ENTER\n">
    comment ~ /*
        IFDEF DEBUGBUILD
            IF DEBUG_MESSAGE_STATUS EQ 2
                IF DONT_TRACE_RECEIVE EQ 1
                    DEBUG_MESSAGE_OFF
                    DONT_TRACE_RECEIVE = 2
                ENDIF
            ENDIF
        ENDIF
    */ comment ~

    ;// check if we are in flush or endof stream

        com_GetObject st_pThis, ecx, IMEMINPUTPIN
        test IMemInputPin_to_IMediaReader(ecx).state, READER_FLUSHING OR READER_END_OF_STREAM
        jnz cant_process
        test IMemInputPin_to_IMediaReader(ecx).state, READER_STATE_TEST
        jz cant_process

    ;// get interfaces, build a stack frame

        com_XchgObject [esp+4], ebx, IMemInputPin   ;// get and preserve
        com_XchgObject [esp+8], edi, IMediaSample   ;// get and preserve
        IMEMINPUTPIN_TO_IMEDIAREADER ebx    ;// clean up the code

        push ebp
        push esi

        or [ebx].state, READER_IN_RECEIVE   ;// tell other threads that we are here

    ;// get the stats for debugging

        IFDEF DEBUGBUILD
        IF FILE_DEBUG_IS_ON EQ 2
        comment ~ /*
        ECHO fixme

            sub esp, 8
            mov ecx, esp    ;// stop time
            sub esp, 8
            mov eax, esp    ;// start time

            com_invoke IMediaSample, GetMediaTime, edi, eax, ecx

            DEBUG_MESSAGE <IMediaSample_GetMediaTime__>
            mov ecx, esp
            DEBUG_MESSAGE_2Q ecx
            add esp, 16

        */ comment ~
        ENDIF
        ENDIF

    ;// get the actual data length

        com_invoke IMediaSample, GetActualDataLength, edi
        mov ebp, eax        ;// ebp will be decreased

    ;// get the pointer to the data

        push eax
        com_invoke IMediaSample, GetPointer, edi, esp
        pop esi  ;// esi gets iterated throughout this section

        ASSUME esi:NOTHING  ;// force error if used incorrectly



    ;/////////////////////////////////////////////////////////////////////////////////
    ;/////////////////////////////////////////////////////////////////////////////////
    ;///
    ;///
    ;///    set up house, look for a buffer to process, wait if nessesary
    ;///

    ;/////////////////////////////////
    ;//
    ;// stack
    ;//           pThis pSample
    ;// edi ebp ret ebx esi
    ;//  00  04  08  12  16
    ;// find a buffer to work with
    ;//
    ;/////////////////////////////////

    find_a_buffer:      ;// top of wait loop

    ;// check for abort flags

        TESTJMP [ebx].state, READER_FLUSHING,       jnz done_with_buffers
        TESTJMP [ebx].state, READER_STATE_TEST,     jz done_with_buffers

    ;// display the buffer stats

        FILE_DEBUG_MESSAGE <"find_a_buffer  1:%8.8X-%8.8X %3.3X-%3.3X  2:%8.8X-%8.8X %3.3X-%3.3X\n">,[ebx].buf1.start, [ebx].buf1.stop, [ebx].buf1.remain, [ebx].buf1.samples, [ebx].buf2.start, [ebx].buf2.stop, [ebx].buf2.remain, [ebx].buf2.samples

    ;// find a buffer to use
    ;// find the lowest start time that has remain set
    ;// if neither have remain set, jump to wait

        mov eax, [ebx].buf1.remain
        mov edx, [ebx].buf2.remain
        lea ecx, [ebx].buf1

        test eax, eax
        jz L0
        ;// buf1 is available
        test edx, edx
        jz got_buffer
        ;// both buffers are available
        ;// choose lowest start
        mov eax, [ebx].buf1.start
        cmp eax, [ebx].buf2.start
        jb got_buffer
        add ecx, SIZEOF DATA_BUFFER ;// point at buf2
        jmp got_buffer

        ALIGN 16
    L0: ;// buf1 is not available
        test edx, edx
        jz wait_for_buffer  ;// neither buffer is available
        add ecx, SIZEOF DATA_BUFFER ;// point at buf2
        jmp got_buffer

    ALIGN 16
    wait_for_buffer:    ;// wait and loop to top

        FILE_DEBUG_MESSAGE <"reader_fill_buffer_BEGIN_WAIT\n">

        or [ebx].state, READER_IS_WAITING   ;// tell other threads that we are waiting
        invoke WaitForSingleObject, [ebx].hEvent, -1
        and [ebx].state, NOT READER_IS_WAITING  ;// tell other threads that we are not waiting
        FILE_DEBUG_MESSAGE <"reader_fill_buffer_END_WAIT\n">

        jmp find_a_buffer

    ;///
    ;///
    ;///    set up house and demand that we a buffer to process
    ;///
    ;/////////////////////////////////////////////////////////////////////////////////
    ;/////////////////////////////////////////////////////////////////////////////////


    ;/////////////////////////////////////////////////////////////////////////////////
    ;/////////////////////////////////////////////////////////////////////////////////
    ;///
    ;///
    ;///    P R O C E S S
    ;///

    ALIGN 16
    got_buffer:
    ;// ebp = is bytes remaining in source buffer
    ;// esi = source ptr (iterated)
    ;// ecx = points buffer we want to use
    ;// ebx = IMEDIAREADER
    ;//
    ;// task:
    ;//     process as many samples as possible
    ;//     exit to done_with_input, or done_with_output

        FILE_DEBUG_MESSAGE <"reader_fill_buffers_PROCESSING\n">

        ASSUME ecx:PTR DATA_BUFFER

    ;// determine the pointer and starting index for edx

        mov eax, [ebx].chanbits_xfer
        mov edi, [ecx].pointer      ;// edi = dest ptr (indexed by edx)
        mov edx, [ecx].samples      ;// get the length of this buffer
        DEBUG_IF <!!edx>        ;// buffer must have a length
        sub edx, [ecx].remain       ;// edx indexes DWORDS
        DEBUG_IF <SIGN?>        ;// bad remain value
        ASSUME edi:PTR DWORD        ;// edi points at output buffers

    ;// jump to the correct reader algorithm

        jmp eax

    ALIGN 16
    xfer_8_stereo::

        ASSUME esi:PTR BYTE

        xor eax, eax            ;// no stalls here
        mov al, [esi]           ;// don't use math temp, we're on another thread
        sub eax, 80h
        push eax                ;// mov math_temp_1, eax
        fild DWORD PTR [esp]    ;// math_temp_1
        fmul math_1_256

        xor eax, eax            ;// no stalls here
        mov al, [esi+1]
        sub eax, 80h
        mov [esp], eax          ;// math_temp_1, eax
        fild DWORD PTR [esp]    ;// math_temp_1
        fmul math_1_256

        pop eax

        fxch
        fstp [edi+edx*4]
        add esi, 2
        fstp [edi+edx*4+DATA_BUFFER_LENGTH*4]

        inc edx
        sub ebp, 2
        jz done_with_input

        cmp edx, [ecx].samples  ;// are we done with this buffer ?
        jb xfer_8_stereo
        jmp done_with_output


    ALIGN 16
    xfer_8_mono::

        ASSUME esi:PTR BYTE

        xor eax, eax            ;// no stalls here
        mov al, [esi]
        sub eax, 80h
        push eax
        fild DWORD PTR [esp]
        fmul math_1_256
        inc esi
        pop eax
        fstp [edi+edx*4]
        inc edx
        dec ebp
        jz done_with_input

        cmp edx, [ecx].samples  ;// are we done with this buffer ?
        jb xfer_8_mono
        jmp done_with_output

    ALIGN 16
    xfer_16_stereo::

            ASSUME esi:PTR WORD

        ;// we want to do 4 at a time
        ;// we want to align edx on a 16 bit boundry
        ;// we must not overrun ebx

        ;// iterate the indexes first

            test ebp, ebp           ;// done with input ?
            je done_with_input
            cmp edx, [ecx].samples  ;// done with output ?
            je done_with_output

            lea eax, [edi+edx*4]    ;// output ponter
            add edx, 4              ;// 4 samples
            sub ebp, 16             ;// size of 4 stereo 16bit
            jb xfer_16_stereo_single;//_ebp

            cmp edx, [ecx].samples  ;// are we done with this buffer ?
            ja xfer_16_stereo_single;//_edx

        ;// 4 at a time

            ASSUME eax:PTR DWORD

            fild [esi+0]
            fmul math_1_32768   ;// L0
            fild [esi+2]
            fmul math_1_32768   ;// R0  L0

            fild [esi+4]
            fmul math_1_32768   ;// L1  R0  L0
            fild [esi+6]
            fmul math_1_32768   ;// R1  L1  R0  L0

            fild [esi+8]
            fmul math_1_32768   ;// L2  R1  L1  R0  L0
            fild [esi+10]
            fmul math_1_32768   ;// R2  L2  R1  L1  R0  L0

            fild [esi+12]
            fmul math_1_32768   ;// L3  R2  L2  R1  L1  R0  L0
            fild [esi+14]
            fmul math_1_32768   ;// R3  L3  R2  L2  R1  L1  R0  L0

            fxch st(7)          ;// R0  L3  R2  L2  R1  L1  R0  R3
            fstp [eax]  ;// L3  R2  L2  R1  L1  R0  R3

            fxch st(5)          ;// R0  R2  L2  R1  L1  L3  R3
            fstp [eax+DATA_BUFFER_LENGTH*4] ;// R2  L2  R1  L1  L3  R3
            fxch st(3)          ;// L1  L2  R1  R2  L3  R3
            fstp [eax+4]    ;// L2  R1  R2  L3  R3

            fxch                ;// R1  L2  R2  L3  R3
            fstp [eax+DATA_BUFFER_LENGTH*4+4]   ;// L2  R2  L3  R3

            fstp [eax+8]                            ;// R2  L3  R3
            fstp [eax+DATA_BUFFER_LENGTH*4+8]   ;// L3  R3
            fstp [eax+12]                           ;// R3
            add esi, 16
            fstp [eax+DATA_BUFFER_LENGTH*4+12]  ;//

            jmp xfer_16_stereo

            ASSUME eax:NOTHING

        ALIGN 16
        xfer_16_stereo_single:

            sub edx, 4  ;// decrease because we've already added 4
            add ebp, 16
            mov eax, -4 ;// size of two 16 bit samples (ebp is negative)

            .REPEAT

                fild [esi]
                fmul math_1_32768
                add esi, 2
                fstp [edi+edx*4]

                fild [esi]
                fmul math_1_32768
                add esi, 2
                fstp [edi+edx*4+DATA_BUFFER_LENGTH*4]

                inc edx

                add ebp, eax
                je done_with_input

                cmp edx, [ecx].samples  ;// are we done with this buffer ?
            .UNTIL ZERO?
            jmp done_with_output



    ALIGN 16
    xfer_16_mono::

            ASSUME esi:PTR WORD

        ;// esi is src ptr
        ;// ebp is byte size remaining in src
        ;// edi points at output array
        ;// edx indexes the output array
        ;// ecx points at buffer we're using

        ;// test and iterate indexes first

            test ebp, ebp               ;// input finished ?
            jz done_with_input          ;// input IS finished
            cmp edx, [ecx].samples      ;// are we done with this buffer ?
            je done_with_output         ;// output IS finished

            lea eax, [edi+edx*4]    ;// output pointer
            add edx, 4                  ;// 4 samples
            sub ebp, 8                  ;// 4 16 bit samples
            jb xfer_16_mono_single  ;//_ebp ;// input going to be finished ?

            cmp edx, [ecx].samples      ;// are we done with this buffer ?
            ja xfer_16_mono_single  ;//_edx ;// output going to be finished ?

        ;// 4 at a time

            ASSUME eax:PTR DWORD

            fild [esi+0]
            fmul math_1_32768   ;// L0
            fild [esi+2]
            fmul math_1_32768   ;// L1  L0
            fild [esi+4]
            fmul math_1_32768   ;// L2  L1  L0
            fild [esi+6]
            fmul math_1_32768   ;// L3  L2  L1  L0

            fxch st(3)
            fstp [eax]          ;// L2  L1  L3
            fxch
            fstp [eax+4]        ;// L2  L3
            fstp [eax+8]        ;// L3
            add esi, 8  ;// 4 16 bit samples
            fstp [eax+12]       ;//
            jmp xfer_16_mono

            ASSUME eax:NOTHING

        ALIGN 16
        xfer_16_mono_single:

            sub edx, 4  ;// decrease because we've already added 4
            add ebp, 8
            mov eax, -2 ;// one mono 16 bit sample (ebp is neg)
            ;// jmp xfer_mono_single

            .REPEAT
                fild [esi]
                fmul math_1_32768
                add esi, 2
                fstp [edi+edx*4]

                inc edx
                add ebp, eax
                je done_with_input

                cmp edx, [ecx].samples  ;// are we done with this buffer ?
            .UNTIL ZERO?

            jmp done_with_output


    ALIGN 16
    xfer_32_stereo::

            ASSUME esi:PTR DWORD

        ;// we want to do 4 at a time
        ;// we want to align edx on a 16 bit boundry
        ;// we must not overrun ebx

        ;// test and iterate indexes first

            test ebp, ebp
            je done_with_input
            cmp edx, [ecx].samples  ;// are we done with this buffer ?
            je done_with_output

            lea eax, [edi+edx*4]    ;// output pointer
            add edx, 4
            sub ebp, 32
            jb xfer_32_stereo_single;//_ebp
            cmp edx, [ecx].samples  ;// are we done with this buffer ?
            ja xfer_32_stereo_single;//_edx

        ;// 4 at a time

            ASSUME eax:PTR DWORD

            fild [esi+0]
            fmul math_2_neg_31  ;// L0
            fild [esi+4]
            fmul math_2_neg_31  ;// R0  L0

            fild [esi+8]
            fmul math_2_neg_31  ;// L1  R0  L0
            fild [esi+12]
            fmul math_2_neg_31  ;// R1  L1  R0  L0

            fild [esi+16]
            fmul math_2_neg_31  ;// L2  R1  L1  R0  L0
            fild [esi+20]
            fmul math_2_neg_31  ;// R2  L2  R1  L1  R0  L0

            fild [esi+24]
            fmul math_2_neg_31  ;// L3  R2  L2  R1  L1  R0  L0
            fild [esi+28]
            fmul math_2_neg_31  ;// R3  L3  R2  L2  R1  L1  R0  L0

            fxch st(7)          ;// R0  L3  R2  L2  R1  L1  R0  R3
            fstp [eax]          ;// L3  R2  L2  R1  L1  R0  R3

            fxch st(5)          ;// R0  R2  L2  R1  L1  L3  R3
            fstp [eax+DATA_BUFFER_LENGTH*4] ;// R2  L2  R1  L1  L3  R3
            fxch st(3)          ;// L1  L2  R1  R2  L3  R3
            fstp [eax+4]        ;// L2  R1  R2  L3  R3

            fxch                ;// R1  L2  R2  L3  R3
            fstp [eax+DATA_BUFFER_LENGTH*4+4]   ;// L2  R2  L3  R3

            fstp [eax+8]                            ;// R2  L3  R3
            fstp [eax+DATA_BUFFER_LENGTH*4+8]   ;// L3  R3
            fstp [eax+12]                           ;// R3
            fstp [eax+DATA_BUFFER_LENGTH*4+12]  ;//

            add esi, 32
            jmp xfer_32_stereo

            ASSUME eax:NOTHING


        ALIGN 16
        xfer_32_stereo_single:

            sub edx, 4
            add ebp, 32
            mov eax, -8

        .REPEAT

            fild [esi]
            fmul math_2_neg_31
            add esi, 4
            fstp [edi+edx*4]

            fild [esi]
            fmul math_2_neg_31
            add esi, 4
            fstp [edi+edx*4+DATA_BUFFER_LENGTH*4]

            inc edx

            add ebp, eax        ;// one sample
            je done_with_input

            cmp edx, [ecx].samples  ;// are we done with this buffer ?

        .UNTIL ZERO?

            jmp done_with_output


    ALIGN 16
    xfer_32_mono::

            ASSUME esi:PTR DWORD

        ;// esi is src ptr
        ;// ebp is byte size remaining in src
        ;// edi points at output array
        ;// edx indexes the output array
        ;// ecx points at buffer we're using


        ;// iterate indexs first

            test ebp, ebp
            jz done_with_output

            cmp edx, [ecx].samples  ;// are we done with this buffer ?
            je done_with_input

            lea eax, [edi+edx*4]
            add edx, 4
            sub ebp, 16 ;// 4 32 bit samples
            jb xfer_32_mono_single;//_ebp

            cmp edx, [ecx].samples  ;// are we done with this buffer ?
            ja xfer_32_mono_single;//_edx

        ;// 4 at a time

            ASSUME eax:PTR DWORD

            fild [esi+0]
            fmul math_2_neg_31  ;// L0
            fild [esi+4]
            fmul math_2_neg_31  ;// L1  L0
            fild [esi+8]
            fmul math_2_neg_31  ;// L2  L1  L0
            fild [esi+12]
            fmul math_2_neg_31  ;// L3  L2  L1  L0

            fxch st(3)
            fstp [eax]  ;// L2  L1  L3
            fxch
            fstp [eax+4]    ;// L2  L3
            fstp [eax+8]    ;// L3
            fstp [eax+12]   ;//

            add esi, 16 ;// 4 32 bit samples
            jmp xfer_32_mono

            ASSUME eax:NOTHING


        ALIGN 16
        xfer_32_mono_single:

            sub edx, 4
            add ebp, 16
            mov eax, -4

        .REPEAT
            fild [esi]
            fmul math_2_neg_31
            add esi, 4
            fstp [edi+edx*4]

            inc edx

            add ebp, eax            ;// one sample
            je done_with_input

            cmp edx, [ecx].samples  ;// are we done with this buffer ?
        .UNTIL ZERO?

            jmp done_with_output

    ;///
    ;///
    ;///    P R O C E S S
    ;///
    ;/////////////////////////////////////////////////////////////////////////////////
    ;/////////////////////////////////////////////////////////////////////////////////



    ;/////////////////////////////////////////////////////////////////////////////////
    ;/////////////////////////////////////////////////////////////////////////////////
    ;///
    ;///
    ;///    EXIT or continue back to wait_for_buffer
    ;///

    ALIGN 16
    done_with_input:
    ;// the input data has been consumed
    ;// we can exit this function

        DEBUG_IF <ebp>          ;// input is supposed to be consumed

        sub edx, [ecx].samples
        neg edx
        mov [ecx].remain, edx
        jmp done_with_buffers

    ALIGN 16
    done_with_output:
    ;// we have filled the entire buffer
    ;// we need to wait for another buffer

    ;// before we wait, we need to set frame start to what we are waiting for

        DEBUG_IF <edx !!= [ecx].samples>;// output is supposed to be done

        mov [ecx].remain, 0             ;// zero samples reamining
        jmp find_a_buffer

    ;/////////////////////////////////////////////////////////////////////////////////

    ALIGN 16
    done_with_buffers:

    ;// display the buffer stats

        FILE_DEBUG_MESSAGE <"done_with_buffers  1:%8.8X-%8.8X %3.3X-%3.3X  2:%8.8X-%8.8X %3.3X-%3.3X\n">,[ebx].buf1.start, [ebx].buf1.stop, [ebx].buf1.remain, [ebx].buf1.samples, [ebx].buf2.start, [ebx].buf2.stop, [ebx].buf2.remain, [ebx].buf2.samples

    ;// clean up and exit

        and [ebx].state, NOT READER_IN_RECEIVE ;// tell other threads that we are there

        pop esi
        pop ebp

        com_XchgObject st_pThis, ebx
        com_XchgObject [esp+8], edi     ;// pSample

    ;// return sucess

        xor eax, eax

    all_done:

        FILE_DEBUG_MESSAGE <"IMemInputPin_Receive_EXIT\n">
        ret 8

    ALIGN 16
    cant_process:

        mov eax, E_UNEXPECTED
        jmp all_done

    ;///
    ;///
    ;///    EXIT or continue back to wait_for_buffer
    ;///
    ;/////////////////////////////////////////////////////////////////////////////////
    ;/////////////////////////////////////////////////////////////////////////////////


IMemInputPin_Receive ENDP



;/////////////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////////////




ASSUME_AND_ALIGN
IMemInputPin_ReceiveMultiple PROC
    ;// STDCALL pThis,ppMediaSamples,nSamples,pProcessed
    ;//           4     8               12      16

        FILE_DEBUG_MESSAGE <"IMemInputPin_ReceiveMultiple_ENTER\n">

    ;///////////////////////////////////////////
    ;// dev loop calls Recieve a bunch of times
    ;//

    ;// process the samples

        mov eax, [esp+16]       ;// get the counter pointer
        xor edx, edx            ;// start count is zero
        mov DWORD PTR [eax], edx;// reset the counter
        jmp enter_loop

    top_of_loop:

        mov eax, [esp+16]       ;// get the counter pointer
        mov edx, [eax]          ;// get the count

    enter_loop:

        cmp edx, [esp+12]       ;// compare with passed count
        jae done_with_loop      ;// exit if done

        inc DWORD PTR [eax]     ;// increase the count
        shl edx, 2              ;// * 4
        add edx, [esp+8]        ;// add counter to pointer base

        mov ecx, [esp+4]        ;// get this

        push DWORD PTR [edx]    ;// push the media sample pointer
        push ecx                ;// push this
        call IMemInputPin_Receive   ;// call receive

        test eax, eax           ;// check results
        jnz all_done            ;// abort if error

        jmp top_of_loop

    done_with_loop:

    ;//
    ;// dev loop calls Recieve a bunch of times
    ;///////////////////////////////////////////

    ;// return sucess

        xor eax, eax

    all_done:

        FILE_DEBUG_MESSAGE <"IMemInputPin_ReceiveMultiple_EXIT\n">
        ret 16

IMemInputPin_ReceiveMultiple ENDP


ASSUME_AND_ALIGN
IMemInputPin_ReceiveCanBlock PROC ;// STDCALL pThis

    FILE_DEBUG_MESSAGE <"IMemInputPin_ReceiveCanBlock\n">
    mov eax, S_OK   ;// FALSE
    ret 4

IMemInputPin_ReceiveCanBlock ENDP





;/////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////
;///
;///
;///    IMediaFilter
;///

;// IUnknown

ASSUME_AND_ALIGN
IMediaFilter_QueryInterface PROC ;//STDCALL pThis, pRefID, ppvObject
                                 ;//        4       8       12
        FILE_DEBUG_MESSAGE <"IMediaFilter_QueryInterface\n">

    ;// try iunknown first

        call iunknown_QueryUnknown

    ;// if it returns then we didn't find it
    ;// ecx is also pRefID

        mov edx, OFFSET IID_IMediaSeeking
        IF_GUID_SAME_GOTO edx, ecx, got_media_seeking
;//     mov edx, OFFSET IID_IMediaPosition
;//     IF_GUID_SAME_GOTO edx, ecx, got_media_seeking

    ;// that's it !
    return_fail:

        mov eax, E_NOINTERFACE
        ret 12

    ALIGN 16
    got_media_seeking:  ;// // or media position

        FILE_DEBUG_MESSAGE <"got_IMediaSeeking\n">

        com_GetObject st_pThis, eax, IFILTER
        mov eax, IMediaFilter_to_IMediaReader(eax).pConnectedPin
        test eax, eax
        jz return_fail

        mov [esp+4], eax            ;// replace pthis with pin
        mov eax, DWORD PTR [eax]    ;// get the vtable
        jmp DWORD PTR [eax]         ;// jump to query interface

IMediaFilter_QueryInterface ENDP

ASSUME_AND_ALIGN
IMediaFilter_AddRef PROC ;//STDCALL pThis

        FILE_DEBUG_MESSAGE <"IMediaFilter_AddRef\n">

        com_GetObject st_pThis, ecx, IFILTER
        inc [ecx].ref_count
        mov eax, [ecx].ref_count
        ret 4

IMediaFilter_AddRef ENDP

ASSUME_AND_ALIGN
IMediaFilter_Release PROC ;//STDCALL pThis

        FILE_DEBUG_MESSAGE <"IMediaFilter_Release\n">

        com_GetObject st_pThis, ecx, IFILTER
        dec [ecx].ref_count
        mov eax, [ecx].ref_count
        .IF ZERO?
            or eax, IMediaFilter_to_IMediaReader(ecx).pReferenceClock
            .IF !ZERO?
                com_invoke IUnknown, Release, eax
                com_GetObject st_pThis, ecx, IFILTER
                xor eax, eax
                mov IMediaFilter_to_IMediaReader(ecx).pReferenceClock, eax
            .ENDIF
        .ENDIF


        ret 4

IMediaFilter_Release ENDP

;// IPersist

;// IMediaFilter

ASSUME_AND_ALIGN
IMediaFilter_Stop PROC ;//STDCALL pThis

        FILE_DEBUG_MESSAGE <"IMediaFilter_Stop_ENTER\n">

    ;// get this, preserve ebx

        xchg ebx, [esp+4]
        ASSUME ebx:PTR IMEDIAFILTER

    ;// turn off running and eos bits

        and IMediaFilter_to_IMediaReader(ebx).state, NOT (READER_END_OF_STREAM OR READER_STATE_TEST)

    ;// make sure the reader gets a chance to abort

    top_of_wait:

        test IMediaFilter_to_IMediaReader(ebx).state, READER_IN_RECEIVE
        jz done_with_wait
        invoke PulseEvent, IMediaFilter_to_IMediaReader(ebx).hEvent
        invoke Sleep, 5
        jmp top_of_wait

    done_with_wait:

    ;// retrive ebx and exit

        xchg ebx, [esp+4]
        xor eax, eax        ;// return sucess

        ret 4

IMediaFilter_Stop ENDP

ASSUME_AND_ALIGN
IMediaFilter_Pause PROC ;//STDCALL pThis


    ;// we need to return wheather or not there is data qued

;//When an application pauses a filter graph,
;//the filter graph does not return from its IMediaControl::Pause method
;//until there is data queued at the renderers.

;//when a renderer is paused,
;//it should return S_FALSE if there is no data waiting to be rendered.
;//If it has data queued, then it can return S_OK.

        com_GetObject st_pThis, ecx, IMEDIAFILTER

        FILE_DEBUG_MESSAGE <"IMediaFilter_Pause_ENTER state=%X\n">,IMediaFilter_to_IMediaReader(ecx).state

        and IMediaFilter_to_IMediaReader(ecx).state, NOT READER_STATE_TEST
        or IMediaFilter_to_IMediaReader(ecx).state, FILTER_STATE_PAUSED

        xor eax, eax    ;// S_OK

    ;// that should do it

        FILE_DEBUG_MESSAGE <"IMediaFilter_Pause_EXIT state=%X\n">,IMediaFilter_to_IMediaReader(ecx).state

        ret 4

IMediaFilter_Pause ENDP

ASSUME_AND_ALIGN
IMediaFilter_Run PROC ;//STDCALL pThis, tStart_lo, tStart_hi
                 ;//          4     8           12
        FILE_DEBUG_MESSAGE <"IMediaFilter_Run_ENTER\n">

        com_GetObject st_pThis, ecx, IMEDIAFILTER

        and IMediaFilter_to_IMediaReader(ecx).state, NOT READER_STATE_TEST
        or IMediaFilter_to_IMediaReader(ecx).state, FILTER_STATE_RUNNING

        ;// we're supposed to pass EC_ events when this happens

        xor eax, eax

        FILE_DEBUG_MESSAGE <"IMediaFilter_Run_EXIT\n">

        ret 12

IMediaFilter_Run ENDP


ASSUME_AND_ALIGN
IMediaFilter_GetState PROC ;//STDCALL pThis, dwMilliSecsTimeout, pStateOut
                           ;//  00      04         08              12
        FILE_DEBUG_MESSAGE <"IMediaFilter_GetState\n">

        com_GetObject st_pThis, ecx, IMEDIAFILTER
        mov edx, [esp+12]   ;// pStateOut
        mov ecx, IMediaFilter_to_IMediaReader(ecx).state
        xor eax, eax        ;// return sucess
        and ecx, READER_STATE_TEST
        mov [edx], ecx

        ret 12

IMediaFilter_GetState ENDP





ASSUME_AND_ALIGN
IMediaFilter_SetSyncSource PROC ;//STDCALL pThis, pClock
                           ;//          4       8
        FILE_DEBUG_MESSAGE <"IMediaFilter_SetSyncSource_enter\n">

    ;// add ref on the new clock

        com_GetObject [esp+8], eax, IUnknown
        com_GetObject st_pThis, ecx, IFILTER
        .IF eax
            com_invoke IUnknown, AddRef, eax
            com_GetObject [esp+8], eax, IUnknown
            com_GetObject st_pThis, ecx, IFILTER
        .ENDIF

    ;// set the new clock and release the old

        xchg eax, IMediaFilter_to_IMediaReader(ecx).pReferenceClock
        .IF eax
            com_invoke IUnknown, Release, eax
            xor eax, eax
        .ENDIF

    ;// return sucess

        FILE_DEBUG_MESSAGE <"IMediaFilter_SetSyncSource_exit\n">

        ret 8

IMediaFilter_SetSyncSource ENDP

;// IBaseFilter

ASSUME_AND_ALIGN
IMediaFilter_EnumPins PROC ;//STDCALL pThis, ppEnum
                          ;//   00    04      08
    FILE_DEBUG_MESSAGE <"IMediaFilter_EnumPins\n">

    com_GetObject st_pThis, ecx, IMediaFilter

    invoke IEnum2_ctor, ADDR IMediaFilter_to_IMediaReader(ecx).pPins, 0, IPin_vtable[4]
    ;// eax has correct return code
    ;// edx has ienum or zero
    mov ecx, [esp+8]
    mov DWORD PTR [ecx], edx

    ret 8

IMediaFilter_EnumPins ENDP


ASSUME_AND_ALIGN
IMediaFilter_QueryFilterInfo PROC ;//STDCALL pThis, pInfo
                             ;//            4   8
        FILE_DEBUG_MESSAGE <"IMediaFilter_QueryFilterInfo\n">

    ;// fill in pInfo

        mov edx, [esp+8]        ;// get the info pointer
        ASSUME edx:PTR FILTER_INFO

        mov DWORD PTR [edx].wszName, 0

        com_GetObject st_pThis, eax, IFILTER
        com_GetObject IMediaFilter_to_IMediaReader(eax).pFilterGraph, eax, IFilterGraph
        mov [edx].pGraph, eax

    ;// add ref to graph if it exists

        .IF eax
            com_invoke IFilterGraph, AddRef, eax    ;// call addref
            xor eax, eax
        .ENDIF

    ;// return sucess

        ret 8

IMediaFilter_QueryFilterInfo ENDP

ASSUME_AND_ALIGN
IMediaFilter_JoinFilterGraph PROC ;//STDCALL pThis, pGraph, pswzName
                             ;//            4   8       12
    FILE_DEBUG_MESSAGE <"IMediaFilter_JoinFilterGraph\n">

    com_GetObject st_pThis, ecx, IFILTER
    mov edx, [esp+8]        ;// get the graph
    xor eax, eax            ;// return value
    mov IMediaFilter_to_IMediaReader(ecx).pFilterGraph, edx ;// store in our struct

    ret 12

IMediaFilter_JoinFilterGraph ENDP
















;//////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////
;///
;///
;///
;///

ASSUME_AND_ALIGN
reader_Initialize PROC

    ;// task:
    ;//
    ;//     verify that we can create the class factory
    ;//     if not then we cannot create a media reader

        ASSUME esi:PTR OSC_FILE_MAP

    FILE_DEBUG_MESSAGE <"reader_Initialize___________________enter\n">

    ;// initialize com  ; moved to app_Main

    ;// get the class factory for the filter graph
    ;// we need multiple instances
    ;// so we use CoGetClassObject

        FILE_DEBUG_MESSAGE <"reader_CoGetClassObject\n">

        invoke CoGetClassObject,
            OFFSET CLSID_FilterGraph,
            CLSCTX_INPROC_SERVER,
            0,
            OFFSET IID_IClassFactory,
            OFFSET pClassFactory

        .IF eax
            invoke reader_Destroy
            mov eax, E_FAIL
        .ENDIF

    ;// that's it !! return value is in eax

    FILE_DEBUG_MESSAGE <"reader_Initialize___________________exit\n">


        ret

reader_Initialize ENDP

ASSUME_AND_ALIGN
reader_Destroy PROC

    ;// task: release the class factory and close out com

    FILE_DEBUG_MESSAGE <"reader_Destroy___________________enter\n">

        .IF pClassFactory
            FILE_DEBUG_MESSAGE <"reader_IClassFactory_Release\n">
            com_invoke IClassFactory, Release, pClassFactory
            mov pClassFactory, 0
        .ENDIF

    ;// moved to app_Main
    ;// .IF com_initialized
    ;//     DEBUG_MESSAGE <reader_CoUninitialize>, LINEFEED, LINEFEED
    ;//     invoke CoUninitialize
    ;//     dec com_initialized
    ;// .ENDIF

    ;// that should do it

    FILE_DEBUG_MESSAGE <"reader_Destroy___________________exit\n">

        ret

reader_Destroy ENDP



ASSUME_AND_ALIGN
reader_prepare_buffer PROC

        ASSUME esi:PTR OSC_FILE_MAP
        ASSUME ecx:PTR DATA_BUFFER
        ;// eax has the file position we want to prepare for

IFDEF DEBUGBUILD
IF FILE_DEBUG_IS_ON EQ 2
    lea edx, [esi].file.reader.buf1
    .IF edx == ecx
        FILE_DEBUG_MESSAGE <"reader_prepare_buffer buf1 %8.8X\n">, eax
    .ELSE
        FILE_DEBUG_MESSAGE <"reader_prepare_buffer buf2 %8.8X\n">, eax
    .ENDIF
ENDIF
ENDIF

;//     DEBUG_IF <[ecx].remain> ;// this buffer is still busy !!

        DEBUG_IF < eax !>= [esi].file.file_length >

        mov [ecx].start, eax
        mov edx, DATA_BUFFER_LENGTH

        add eax, edx

        mov [ecx].stop, eax

        mov [ecx].remain, DATA_BUFFER_LENGTH
        mov [ecx].samples, DATA_BUFFER_LENGTH

        cmp eax, [esi].file.file_length
        ja stop_passed_end

    all_done:

        ;// display the buffer
        FILE_DEBUG_MESSAGE <"reader_prepare_buffer prepared %8.8X-%8.8X %3.3X-%3.3X\n">,[ecx].start, [ecx].stop, [ecx].remain, [ecx].samples


        ret

    ALIGN 16
    stop_passed_end:

        sub eax, [esi].file.file_length
        DEBUG_IF <SIGN?>
        sub [ecx].remain, eax
        sub [ecx].samples, eax
        jmp all_done

reader_prepare_buffer ENDP





ASSUME_AND_ALIGN
intmul_p0064_x_64 PROC ;// STDCALL pDest, pConvert, lo_val, hi_val
                       ;//    0       4       8      12       16

        st_pD   TEXTEQU <(DWORD PTR [esp+4])>
        st_pC   TEXTEQU <(DWORD PTR [esp+8])>
        st_lo   TEXTEQU <(DWORD PTR [esp+12])>
        st_hi   TEXTEQU <(DWORD PTR [esp+16])>

    ;// we're going to do a qword multiply and store the top qword in the destination
    ;// we'll need 4 accumulators (stack)
    ;// we return the result to pDest
    ;// destroyes eax, edx, ecx

;// algorithm:  p4      p0
;//           * hi      lo
;//           --------------
;// 1)                 lo*p0            edx eax
;// 2)          lo*p4               edx eax
;// 3)          hi*p0               edx eax
;// 4)  hi*p4                   edx eax
;//                             ----------------------
;//                             D4  D0  pC  don't care

        mov ecx, st_pC      ;// pC
        ASSUME ecx:PTR DWORD

        xchg ebx, st_pD     ;// pD
        ASSUME ebx:PTR DWORD
        mov [ebx], 0
        mov [ebx+4], 0
    ;// 1
        mov eax, st_lo      ;// lo
        mul [ecx]           ;// lo*p0
        mov st_pC, edx      ;// store in pC
    ;// 2
        mov eax, st_lo      ;// lo
        mul [ecx+4]         ;// lo*p4
        add st_pC, eax
        adc [ebx], edx
    ;// 3
        mov eax, st_hi      ;// hi
        mul [ecx]           ;// hi*p0   ;// ABox230: WRONG should be mul, not imul
        add st_pC, eax                  ;// otherwise edx will be sign extended at wrong time
        adc [ebx], edx
        adc [ebx+4], 0
    ;// 4
        mov eax, st_hi      ;// hi
        imul [ecx+4]        ;// hi*p4   (signed)
        add [ebx], eax
        adc [ebx+4], edx
    ;// 5 account for rounding
    ;// mov eax, st_pC      ;// pC
    ;// shr eax, 31
    ;// add [ebx], eax
    ;// adc [ebx+4], 0
    ;// that's it
        xchg ebx, st_pD ;// pD

        ret 16

        st_pD   TEXTEQU <>
        st_pC   TEXTEQU <>
        st_lo   TEXTEQU <>
        st_hi   TEXTEQU <>

intmul_p0064_x_64  ENDP



ASSUME_AND_ALIGN
intmul_32_x_64  PROC ;// STDCALL pDest Convert lo_value hi_value
                     ;//   00     04     08       12       16

    ;// multiplies a 32bit int by a 64bit int
    ;// return top two dwords

        st_pD   TEXTEQU <(DWORD PTR [esp+4])>
        st_C    TEXTEQU <(DWORD PTR [esp+8])>
        st_lo   TEXTEQU <(DWORD PTR [esp+12])>
        st_hi   TEXTEQU <(DWORD PTR [esp+16])>

        mov ecx, st_pD      ;// pD
        ASSUME ecx:PTR DWORD

;// algorithm:      hi. lo
;//                     C
;//             -----------
;// 1) lo*C         edx eax
;// 2) hi*C     edx eax
;//             -----------
;//             D4  D0  don't care

    ;// 1 (also account for rounding ?)
        mov eax, st_C
        mul st_lo
        shr eax, 31
        add edx, eax
        mov [ecx], edx
    ;// 2
        mov eax, st_C
        mul st_hi
        add [ecx], eax
        adc edx, 0
        mov [ecx+4], edx
    ;// that's it

        ret 16

        st_pD   TEXTEQU <>
        st_C    TEXTEQU <>
        st_lo   TEXTEQU <>
        st_hi   TEXTEQU <>

intmul_32_x_64  ENDP





ASSUME_AND_ALIGN
reader_Open PROC USES edi ebx

    ;// task:
    ;//
    ;//     make sure our vtable is filled in
    ;//     using the common class factory
    ;//     get a graph builder
    ;//     build the graph
    ;//     start playing
    ;// return sucess or failure in eax

;// verify that fie can be opened
;// set the osc_object capability flags
;// open the file
;// set the osc_object capability flags
;// set the format variables
;// return zeero for sucess

        ASSUME esi:PTR OSC_FILE_MAP

    FILE_DEBUG_MESSAGE <"reader_Open_____________________enter\n">

    ;// verify that we can be opened

        test file_available_modes, FILE_AVAILABLE_READER
        jz set_bad_mode

    ;// make sure we have a file name

        cmp [esi].file.filename_Reader, 0 ;// skip if no name
        je set_bad_mode

    ;// fill in our vtable if not already doen

        .IF ![esi].file.reader.filter.vtable

            mov [esi].file.reader.filter.vtable, OFFSET IMediaFilter_vtable
            mov [esi].file.reader.pin.vtable, OFFSET IPin_vtable
            mov [esi].file.reader.meminputpin.vtable, OFFSET IMemInputPin_vtable

            lea eax, [esi].file.reader.pin      ;// get a a pointer to pin
            mov [esi].file.reader.pPins, eax    ;// set the pointer to pin
            mov [esi].file.reader.pPins[4], 0   ;// make sure zero terminated

        .ENDIF

    ;// have class factory build a filter graph

        FILE_DEBUG_MESSAGE <"reader_IClassFactory_CreateInstance\n">
        push eax
        com_invoke IClassFactory, CreateInstance, pClassFactory,0,OFFSET IID_IGraphBuilder, esp
        pop ecx

        test eax, eax
        jnz all_done    ;// cant_create_graphbuilder

        mov [esi].file.reader.pGraphBuilder, ecx    ;// store for later

    ;// set the log file

        IFDEF DEBUGBUILD
        IFDEF USELOGFILE
            .DATA
            hLogFile    dd  0
            szLogFile   db  'dshow.log',0
            ALIGN 4
            .CODE
            push ecx

            invoke CreateFileA, OFFSET szLogFile, GENERIC_WRITE, FILE_SHARE_READ OR FILE_SHARE_WRITE, 0, CREATE_ALWAYS, 0, 0
            mov hLogFile, eax

            mov ecx, [esp]
            com_invoke IGraphBuilder, SetLogFile, ecx, hLogFile
            pop ecx
        ENDIF
        ENDIF

    ;// add our wave filter

        FILE_DEBUG_MESSAGE <"reader_IGraphBuilder_AddFilter\n">

    ;// inc [esi].file.reader.filter.ref_count  ;// add ref ??
        com_invoke IGraphBuilder, AddFilter, ecx, ADDR [esi].file.reader.filter, 0

        test eax, eax
        jnz close_graph_builder     ;// can't add filter

    ;// format our name to wide char

        mov ebx, [esi].file.filename_Reader
        DEBUG_IF <!!ebx>    ;// supposed to be set !!
        ASSUME ebx:PTR FILENAME
        mov ecx, [ebx].dwLength
        DEBUG_IF <!!ecx>        ;// bad name !!
        inc ecx ;// need the terminator

        ;// make room on the stack
        push ebp
        mov ebp, esp
        neg ecx
        lea esp, [esp+ecx*2]    ;// make room
        and esp, -4             ;// dword align
        ;// setup for convertion
        push esi                ;// save esi
        lea edi, [esp+4]        ;// dest buffer
        lea esi, [ebx].szPath   ;// source
        xor eax, eax
        ;// convert to wide char
        .REPEAT
        lodsb           ;// get a byte
        inc ecx         ;// increase the count
        stosw           ;// store a word
        .UNTIL ZERO?

        pop esi         ;// retrieve esi

    ;// add the source file filter

        FILE_DEBUG_MESSAGE <"reader_IGraphBuilder_AddSourceFilter\n">

        mov ecx, esp    ;// point at the buffer we just built
        pushd 0
        com_invoke IGraphBuilder, AddSourceFilter, [esi].file.reader.pGraphBuilder, ecx, 0, esp
        pop edi         ;// edi is the source file filter

        ;// clean up the stack
        mov esp, ebp
        pop ebp

        ;// see if we suceeded
        test eax, eax
        jnz close_graph_builder ;// cant_add_source_filter

    ;// locate the output pin

        ;// start enumerating pins

        FILE_DEBUG_MESSAGE <"reader_IBaseFilter_EnumPins\n">

        pushd 0
        com_invoke IBaseFilter, EnumPins, edi, esp
        pop ebx         ;// enum pins interface

        ;// we should be done with the source filter

        push eax    ;// still need to check the return value

        FILE_DEBUG_MESSAGE <"reader_IBaseFilter_Release\n">

        com_invoke IBaseFilter, Release, edi

        pop eax

        test eax, eax
        jnz close_graph_builder ;// cant_enum_pins

        ;// make some room for IPin return pointers

    try_next_pin:

        pushd 0

        ;// get the next pin

        FILE_DEBUG_MESSAGE <"reader_IEnumPins_Next\n">

        mov ecx, esp
        pushd 0         ;// number fetched
        com_invoke IEnumPins, Next, ebx, 1, ecx, esp
        pop edx         ;// get the fetched count

        .IF eax || !edx ;// make sure we got a pin
            ;// cant_get_next_pin
            FILE_DEBUG_MESSAGE <"reader_IEnumPins_Release\n">
            com_invoke IEnumPins, Release, ebx
            jmp close_graph_builder
        .ENDIF

        ;// make sure it's an output pin

        FILE_DEBUG_MESSAGE <"reader_IPin_QueryDirection\n">

        mov ecx, [esp]  ;// get the IPin ptr
        pushd 0
        com_invoke IPin, QueryDirection, ecx, esp
        pop edx         ;// get the direction

        .IF eax
            ;// cant_query_direction
            mov ecx, [esp]  ;// get the IPin ptr
            FILE_DEBUG_MESSAGE <"reader_IPin_Release_failed_direction_query\n">
            com_invoke IPin, Release, ebx
            FILE_DEBUG_MESSAGE <"reader_IEnumPins_Release_failed_direction_query\n">
            com_invoke IEnumPins, Release, ebx
            jmp close_graph_builder
        .ENDIF

        .IF edx != PIN_DIRECTION_OUTPUT

            FILE_DEBUG_MESSAGE <"reader_IPin_Release_not_output_pin\n">

            pop ebx         ;// ebx is now a pin
            com_invoke IPin, Release, ebx
            jmp try_next_pin

        .ENDIF

    ;// found the pin, release the enum pins and get the pin

        FILE_DEBUG_MESSAGE <"reader_IEnumPins_Release_no_outputpin\n">

        com_invoke IEnumPins, Release, ebx

        ;// get the resultant pin

        pop ebx         ;// ebx is now the output pin of the source file

        comment ~ /*
        ;// just for fun -----------------------------------------------------
        ECHO just for fun, removethis code later
        ;// lets see what happens if we render the file
        ;// do we get a video stream ?

        com_invoke IGraphBuilder, Render, [esi].file.reader.pGraphBuilder, ebx
        ECHO works ! need to allow for controls in the video window

            program crashes when object is closed
            thus there is no way to change the file name
            also need to provide a proper clock for the video so it stays in sync

            we're relying on our own recieve buffer to halt the data flow
            that's how it works in the audio

            for the video we'd actually have to go in and issue pause commands

            this would take some srious rethinking ....

        ECHO done with fun  got error 40204
        ;// just for fun -----------------------------------------------------
        ;// be sure to comment out the connect the call to Connect that follows
        */ comment ~

    ;// connect them

        FILE_DEBUG_MESSAGE <"reader_IGraphBuilder_Connect\n">

        com_invoke IGraphBuilder, Connect, [esi].file.reader.pGraphBuilder, ebx, ADDR [esi].file.reader.pin

        push eax    ;// still need to test if connection passed

    ;// don't need our pin anymore

        FILE_DEBUG_MESSAGE <"reader_IPin_Release\n">
        com_invoke IPin, Release, ebx

        pop eax     ;// retrieve results of connection

        test eax, eax
        jz @F
        cmp eax, VFW_S_PARTIAL_RENDER   ;// account for video files
        jne close_graph_builder         ;// cant_connect_pins
        @@:

    ;// get the media control interface

        FILE_DEBUG_MESSAGE <"reader_IGraphBuilder_Query_IMediaControl\n">

        pushd 0
        com_invoke IGraphBuilder, QueryInterface, [esi].file.reader.pGraphBuilder, OFFSET IID_IMediaControl, esp
        pop ebx

        test eax, eax
        jnz close_graph_builder ;// cant_get_media_control, so we can't play the graph

        mov [esi].file.reader.pMediaControl, ebx    ;// store for later

    ;// see if we can get a media seeking interface

        FILE_DEBUG_MESSAGE <"reader_IGraphBuilder_Query_IMediaSeeking\n">

        pushd 0
        com_invoke IGraphBuilder, QueryInterface, [esi].file.reader.pGraphBuilder, OFFSET IID_IMediaSeeking, esp
        pop ebx

        test eax, eax
        jnz close_graph_builder ;// cant_get_seeker, so we can't play the graph

    ;// we have a seeking inferface

        mov [esi].file.reader.pMediaSeeking, ebx    ;// store for later

    ;// xfer rate and chan to main struct
    ;// setup the chanbits stuff

        mov eax, [esi].file.reader.chan
        mov edx, [esi].file.reader.rate
        mov ecx, [esi].file.reader.bits

        mov [esi].file.fmt_chan, eax
        mov [esi].file.fmt_rate, edx
        mov [esi].file.fmt_bits, ecx

        shr ecx, 4  ;// remove 4 bits, 8bit=0, 16bit=1, 32bit=2

        dec eax
        .IF !ZERO?
            or [esi].dwUser, FILE_MODE_IS_STEREO
            add ecx, 3  ;// bump jump to next category
        .ENDIF
        DEBUG_IF <ecx!>5>

        mov eax, chanbits_shift_table[ecx*4]
        mov edx, chanbits_xfer_table[ecx*4]
        mov [esi].file.reader.chanbits_shift, eax
        mov [esi].file.reader.chanbits_xfer, edx

    ;// set flags as ok

        or [esi].dwUser,FILE_MODE_IS_MOVEABLE   OR  \
                        FILE_MODE_IS_READABLE   OR  \
                        FILE_MODE_IS_SEEKABLE   OR  \
                        FILE_MODE_IS_RATEABLE   OR  \
                        FILE_MODE_IS_SYNCABLE
        ;// ver 213: IS_CALCABLE moved down below

    ;// set the format to samples

        mov [esi].file.reader.uses_media_time, 0    ;// assume we don't for now
        FILE_DEBUG_MESSAGE <"reader_IMediaSeeking_SetTimeFormat\n">
        com_invoke IMediaSeeking, SetTimeFormat, ebx, OFFSET TIME_FORMAT_SAMPLE
        .IF eax

            ;// we have seeking, but it doesn't want to use samples
            ;// so we'll use other values

            FILE_DEBUG_MESSAGE <"reader_IMediaSeeking_GetTimeFormat\n">

            sub esp, SIZEOF GUID
            com_invoke IMediaSeeking, GetTimeFormat, ebx, esp
            DEBUG_IF <eax>  ;// not supported !!

            comment ~ /*
            IFDEF DEBUGBUILD
            mov ecx, esp
            DEBUG_DUMP_GUID ecx
            ENDIF
            */ comment ~

            pop eax
            add esp, SIZEOF GUID - 4
            cmp eax, TIME_FORMAT_MEDIA_TIME.data1
            jne close_graph_builder     ;// don't know how to handle this format

            ;// we're probably using seconds

            mov [esi].file.reader.uses_media_time, 1

            fninit  ;// set to double
            fild [esi].file.reader.rate
            fmul math_reader_media_scale
            fistp [esi].file.reader.time_sample_convert
            fild [esi].file.reader.rate
            fdivr math_reader_sample_scale
            fistp [esi].file.reader.sample_time_convert
            fldcw WORD PTR play_fpu_control ;// put back to single

        .ENDIF

    ;// get the duration

        FILE_DEBUG_MESSAGE <"reader_IMediaSeeking_GetDuration\n">

        push eax    ;// eax is zero
        push eax    ;// we'll use it for default to zero length
        com_invoke IMediaSeeking, GetDuration, ebx, esp
        DEBUG_IF <eax>  ;// what happened here ??
        or eax, [esi].file.reader.uses_media_time
        .IF !ZERO?

            mov edx, esp

            ;// have to do this manually
            push [esp+4]    ;// pTime_hi
            lea ecx, [esi].file.reader.time_sample_convert
            push [esp+4]    ;// pTime_lo
            push ecx        ;// pConvert
            push edx        ;// destination
            call intmul_p0064_x_64  ;// call the convertion function

        .ENDIF
        pop eax ;// low dword
        pop edx ;// high dword
        .IF edx || (eax & 0C0000000h)
            DEBUG_IF <edx & 80000000h>
            mov eax, 3FFFFFFFh
        .ENDIF

        lea edx, [eax*4]
        mov [esi].file.file_length, eax
        mov [esi].file.file_size, edx

    ;// we're good to go

    ;// now we need to allocate our buffer blocks for reading

        mov ebx, DATA_BUFFER_LENGTH * 4 ;// size of ONE block
        .IF [esi].dwUser & FILE_MODE_IS_STEREO
            shl ebx, 1  ;// two channels
        .ENDIF

        lea eax, [ebx*2]    ;// allocate 2 blocks
        invoke memory_Alloc, GPTR, eax
        mov [esi].file.reader.buf1.pointer, eax ;// store first block
        add eax, ebx                        ;// bump to second block
        mov [esi].file.reader.buf2.pointer, eax ;// store second block
        ;// set both as needing to be filled

        lea ecx, [esi].file.reader.buf1
        xor eax, eax
        xor edx, edx
        invoke reader_prepare_buffer

        mov eax, DATA_BUFFER_LENGTH
        xor edx, edx
        if_qword_GT [esi].file.file_length, dont_prepare_2

            lea ecx, [esi].file.reader.buf2
            invoke reader_prepare_buffer

        dont_prepare_2:

    ;// create our event

        invoke CreateEventA, 0, 0, 0, 0
        DEBUG_IF <!!eax>    ;// can't create event
        mov [esi].file.reader.hEvent, eax

    ;// run the graph

    FILE_DEBUG_MESSAGE <"reader_IMediaControl_Pause\n">

        com_invoke IMediaControl, _Pause, [esi].file.reader.pMediaControl

    FILE_DEBUG_MESSAGE <"reader_IMediaControl_Run\n">

        com_invoke IMediaControl, Run, [esi].file.reader.pMediaControl

        test eax, eax
        ;// ver 213: trap for returning false
        .IF !ZERO?
        dec eax     ;// why asf returns E_FALSE I dont't know !!
        jne close_graph_builder ;// cant_run
        .ENDIF

        or [esi].dwUser, FILE_MODE_IS_CALCABLE      ;// set this here
        ;// ver 213 fix                             ;// otherwise we crash

    ;// that should do it   ;// eax has the return value
    all_done:

    FILE_DEBUG_MESSAGE <"reader_Open_____________________exit\n">

        ret

    ALIGN 16
    close_graph_builder:

        invoke reader_Close

    set_bad_mode:

        mov eax, E_FAIL

        jmp all_done


reader_Open ENDP


ASSUME_AND_ALIGN
reader_CheckState PROC

        ASSUME esi:PTR OSC_FILE_MAP

        mov reader_waits, NUM_READER_WAITS
        mov reader_seeks, NUM_READER_SEEKS

    ;// detect if file pointer is outside of range
    ;// if not, get the desired data buffers

        mov eax, [esi].file.file_position
        cmp eax, [esi].file.file_length
        jb reader_GetBuffer

    ;// otherwise return sucess
    ;// verify_file_position will take care of rewinding

        or eax, 1

        ret


reader_CheckState ENDP



ASSUME_AND_ALIGN
reader_GetBuffer PROC USES ecx

    ;// preserve ecx ebx edi ebp esp

    ;// combined CheckState and ReadBuffers

    ;// get the buffers that correspond with file position
    ;// issue a seek command if nessesary
    ;// setup buffers to be correct
    ;// assume read forward

        ASSUME esi:PTR OSC_FILE_MAP

IFDEF DEBUG_BUILD
    mov eax, [esi].file_position
    DEBUG_IF < eax!>= [esi].file_length >   ;// not supposed to happen now !!!
ENDIF

    ;//////////////////////////////////////////////////////////////////////////

    ;// check if a current buffer has the data we need
    check_for_existing_buffers:

        IFDEF DEBUGBUILD
        IF FILE_DEBUG_IS_ON EQ 2
        lea edx, [esi].file.reader
        ASSUME edx:PTR IMEDIAREADER
        FILE_DEBUG_MESSAGE <"reader_GetBuffer:check_for_existing_buffers: 1:%8.8X-%8.8X %3.3X-%3.3X  2:%8.8X-%8.8X %3.3X-%3.3X\n">,[edx].buf1.start, [edx].buf1.stop, [edx].buf1.remain, [edx].buf1.samples, [edx].buf2.start, [edx].buf2.stop, [edx].buf2.remain, [edx].buf2.samples
        ASSUME edx:NOTHING
        ENDIF
        ENDIF

        xor edx, edx    ;// zero
        mov eax, [esi].file.file_position   ;// load file_position

    try_buf1:

        CMPJMP eax, [esi].file.reader.buf1.start,   jb try_buf2
        CMPJMP eax, [esi].file.reader.buf1.stop,    jae try_buf2

        cmp [esi].file.reader.buf1.remain, edx
        jne reader_GetBuffer_wait_for_buffer    ;// buf1 has the data we need, but is still busy

        ;// buf1 is ready
        ;// try to schedule buf2 first

        .IF ![esi].file.reader.buf2.remain  ;// is buffer 2 busy ?

            mov eax, [esi].file.reader.buf1.stop
            .IF eax != [esi].file.reader.buf2.start ;// already at correct spot ?
            .IF eax < [esi].file.file_length        ;// don't go passed end

                lea ecx, [esi].file.reader.buf2
                invoke reader_prepare_buffer
                .IF [esi].file.reader.state & READER_IS_WAITING
                    FILE_DEBUG_MESSAGE <"reader_GetBuffer:check_for_existing_buffers: PULSING BUF2\n">
                    invoke PulseEvent, [esi].file.reader.hEvent
                .ENDIF

            .ENDIF
            .ENDIF

        .ENDIF

        lea ecx, [esi].file.reader.buf1
        jmp setup_buffer

    ALIGN 16
    try_buf2:

        ;// eax has file_position, edx is zero

        CMPJMP eax, [esi].file.reader.buf2.start,   jb need_to_seek
        CMPJMP eax, [esi].file.reader.buf2.stop,    jae need_to_seek

        cmp [esi].file.reader.buf2.remain, edx
        jne reader_GetBuffer_wait_for_buffer    ;// buf2 has the data we want, but it's not ready yet

        ;// buf2 is what we want to use

        ;// try to schedule buf1 first

        .IF ![esi].file.reader.buf1.remain  ;// is buf1 busy ?

            mov eax, [esi].file.reader.buf2.stop
            .IF eax != [esi].file.reader.buf1.start ;// already at correct spot ?
            .IF eax < [esi].file.file_length        ;// don't go passed end

                lea ecx, [esi].file.reader.buf1
                invoke reader_prepare_buffer
                .IF [esi].file.reader.state & READER_IS_WAITING
                    FILE_DEBUG_MESSAGE <"reader_GetBuffer:check_for_existing_buffers: PULSING BUF1\n">
                    invoke PulseEvent, [esi].file.reader.hEvent
                .ENDIF

            .ENDIF
            .ENDIF

        .ENDIF

        lea ecx, [esi].file.reader.buf2
        jmp setup_buffer


    ALIGN 16
    setup_buffer:

        ASSUME ecx:PTR DATA_BUFFER

        mov edx, [ecx].pointer
        mov eax, [ecx].start
        mov ecx, [ecx].stop

        mov [esi].file.buf.pointer, edx
        mov [esi].file.buf.start, eax
        mov [esi].file.buf.stop, ecx

        mov eax, 1  ;// return sucess

        jmp all_done


    ;//////////////////////////////////////////////////////////////////////////


    ALIGN 16
    reader_GetBuffer_wait_for_buffer:   ;//buffer_is_busy:

        TESTJMP [esi].file.reader.state, READER_END_OF_STREAM,  jz check_for_pulse
        test [esi].dwUser, FILE_MOVE_LOOP
        mov eax, 1  ;// we return sucess even though we can't read any more
        jz all_done
    ;// rewind
        xor eax, eax
        mov [esi].file.file_position, eax
        mov edi, eax
        jmp check_for_existing_buffers

    ALIGN 16
    check_for_pulse:

        .IF [esi].file.reader.state & READER_IS_WAITING
            FILE_DEBUG_MESSAGE <"reader_GetBuffer:check_for_pulse: PULSING\n">
            invoke PulseEvent, [esi].file.reader.hEvent
        .ENDIF

        DECJMP reader_waits,    js cant_seek    ;// don't wait too many times

        mov eax, [esi].dwUser
        ANDJMP eax, FILE_SEEK_SYNC, jz all_done ;// eax already has fail return value

        FILE_DEBUG_MESSAGE <"reader_GetBuffer:check_for_pulse: SLEEP BEGIN\n">
IFDEF DEBUGBUILD
IF FILE_DEBUG_IS_ON EQ 2
ECHO either increase the sleep time from 1 or raise reader_waits
ENDIF
ENDIF
        invoke Sleep, 5     ;// 5 seems to work well
        FILE_DEBUG_MESSAGE <"reader_GetBuffer:check_for_pulse: SLEEP END\n">

        jmp check_for_existing_buffers


    ;//////////////////////////////////////////////////////////////////////////

    ALIGN 16
    need_to_seek:

    ;// neither buffer is what we want
    ;// so we need to reschedule one of the buffers
    ;// then issue a seek command

    ;// TESTJMP [esi].dwUser, FILE_MODE_IS_SEEKABLE, jz cant_seek

        DECJMP reader_seeks,    js cant_seek

        FILE_DEBUG_MESSAGE <"reader_GetBuffer:need_to_seek: BEGIN\n">

    ;// pause the graph

        FILE_DEBUG_MESSAGE <"reader_GetBuffer:need_to_seek: pause_begin\n">
        com_invoke IMediaControl, _Pause, [esi].file.reader.pMediaControl
        FILE_DEBUG_MESSAGE <"reader_GetBuffer:need_to_seek: pause_end\n">
        ;// assume we can access immediately


        ;// define the position to seek to

        ;// to account for playing backwards
        ;// set buf 1 at file_pos
        ;// if buf2 is before file pos
        ;//     moving forwards
        ;//     set buf2 after buf1
        ;//     seek to buf1 start
        ;// else buf2 is after file pos
        ;//     moving backwards
        ;//     set buf2 before buf1
        ;//     seek to buf2 start

    ;// determine the seek time

        push edi

        mov edi, [esi].file.file_position
        and edi, NOT (DATA_BUFFER_LENGTH-1)

    ;// ABOX232: preparing buffer locations moved to after seek

    ;// issue a seek

        ;// com invoke is going be clumsy
        ;// so we build args on the stack and call manually

        xor eax, eax    ;// zero for pushing

        push eax        ;// stop time_hi
        push [esi].file.file_length     ;// stop time_lo
        push eax        ;// start time_hi
        push edi        ;// start time_lo

        FILE_DEBUG_MESSAGE <"reader_GetBuffer:need_to_seek: SEEKING %8.8X%8.8X-%8.8X%8.8X\n">, eax, edi, eax, [esi].file.file_length

        .IF [esi].file.reader.uses_media_time   ;// convert to media time if nessesary

            lea eax, [esp+8]    ;// dest
            pushd DWORD PTR [esi].file.reader.sample_time_convert[4]    ;// hi
            pushd DWORD PTR [esi].file.reader.sample_time_convert       ;// lo
            pushd DWORD PTR [eax]       ;// ABOX242 AJT
            push eax
            call intmul_32_x_64

            mov eax, esp    ;// dest
            pushd DWORD PTR [esi].file.reader.sample_time_convert[4]    ;// hi
            pushd DWORD PTR [esi].file.reader.sample_time_convert       ;// lo
            pushd DWORD PTR [eax]       ;// ABOX242 AJT
            push eax
            call intmul_32_x_64
        comment ~ /*
            IFDEF DEBUGBUILD
            mov ecx, esp
            DEBUG_MESSAGE_2Q ecx
            ENDIF
        */ comment ~
        .ENDIF

        lea edx, [esp+8];// pStop time
        mov ecx, esp    ;// pStart time

        pushd AM_SEEKING_NoPositioning      ;// stop flags
        pushd edx       ;// pStopTime
        pushd AM_SEEKING_AbsolutePositioning;// start flags
        pushd ecx       ;// pStart time
        mov eax, [esi].file.reader.pMediaSeeking
        push eax        ;// pThis
        mov eax, [eax]  ;// pVtable
        call (IMediaSeeking PTR [eax]).SetPositions
        add esp, 16     ;// clean up the rest of args

    ;// ABOX232
    ;// prepare the buffer locations AFTER issuing the seek
    ;// and BEFORE running the graph
    ;// this allow IPin_BeginFlush to correctly abort IMemInputPin_Receive

    ;// edi still has the start time
    ;// a seek has already been issued


    ;// set up buf1 and buf2

        mov eax, edi
        lea ecx, [esi].file.reader.buf1
        invoke reader_prepare_buffer

        lea eax, [edi+DATA_BUFFER_LENGTH]   ;// put buf2 after buf1
        .IF eax < [esi].file.file_length    ;// don't go passed end
            lea ecx, [esi].file.reader.buf2
            invoke reader_prepare_buffer
        .ENDIF


    ;// NOW we can run the filter graph

    pop edi  ;// retrieve edi


    ;// run the graph

        FILE_DEBUG_MESSAGE <"reader_GetBuffer:need_to_seek: running\n">
        com_invoke IMediaControl, Run, [esi].file.reader.pMediaControl

        FILE_DEBUG_MESSAGE <"reader_GetBuffer:need_to_seek: END\n">

    ;// if we are synchronous, we want to wait

        mov eax, [esi].dwUser
        and eax, FILE_SEEK_SYNC
        jnz reader_GetBuffer_wait_for_buffer

    cant_seek:

        xor eax, eax

    all_done:

        ret

reader_GetBuffer ENDP





ASSUME_AND_ALIGN
reader_Close PROC

    ;// task:
    ;//
    ;//     stop playing
    ;//     release intefaces we may hold

        ASSUME esi:PTR OSC_FILE_MAP

    ;// stop playing
    ;// release all the interfaces

    FILE_DEBUG_MESSAGE <"reader_Close_____________________enter\n">

    ;// close the log file

        IFDEF DEBUGBUILD
        IFDEF USELOGFILE
        .IF hLogFile

            invoke CloseHandle, hLogFile
            mov hLogFile, 0

        .ENDIF
        ENDIF
        ENDIF

    ;// close the rest of the interfaces

        .IF [esi].file.reader.pMediaSeeking

            com_invoke IMediaSeeking, Release, [esi].file.reader.pMediaSeeking

        .ENDIF

        .IF [esi].file.reader.pMediaControl

            FILE_DEBUG_MESSAGE <"reader_IMediaControl_Stop\n">

            com_invoke IMediaControl, Stop, [esi].file.reader.pMediaControl

            DEBUG_IF <eax>  ;//jnz cant_stop

            FILE_DEBUG_MESSAGE <"reader_IMediaFilter_Release\n">

            com_invoke IMediaControl, Release, [esi].file.reader.pMediaControl

        .ENDIF

        .IF [esi].file.reader.pGraphBuilder

            FILE_DEBUG_MESSAGE <"reader_IGraphBuilder_Release__close\n">
            com_invoke IGraphBuilder, Release, [esi].file.reader.pGraphBuilder

        .ENDIF

        .IF [esi].file.reader.hEvent    ;// release event AFTER stopping play

            invoke CloseHandle, [esi].file.reader.hEvent
            DEBUG_IF <!!eax>    ;// cant release event

        .ENDIF

        .IF [esi].file.reader.buf1.pointer

            invoke memory_Free, [esi].file.reader.buf1.pointer

        .ENDIF

    ;// clear the entire struct

        push edi

        lea edi, [esi].file.reader
        mov ecx, (SIZEOF IMEDIAREADER)/4
        xor eax, eax
        rep stosd
        pop edi

        mov [esi].file.buf.pointer, eax

    ;// that's it

        and [esi].dwUser, NOT FILE_MODE_IS_CALCABLE

    FILE_DEBUG_MESSAGE <"reader_Close_____________________exit\n">

        ret

reader_Close ENDP



;///
;///                    based on dshow.asm
;///    MEDIA READER
;///
;///
;///////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////

ASSUME_AND_ALIGN

ENDIF ;// USE_THIS_FILE

END



