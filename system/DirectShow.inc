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
;//             -- interfaces transcibed from Microsoft DXSDK header files
;//
;// History:
;//
;//     2.41 Mar 04, 2011 AJT
;//         Initial port to GPLv3
;//
;//     ABOX242 AJT -- detabified
;//
;//##////////////////////////////////////////////////////////////////////////
;////                       this is a running include file for direct show
;////   DirectShow.inc      capabilities. functions are added as required
;////                       note that we're only providing Interfaces
;////                       and a useful comInvoke macro
;////                    also included are two string conversion proceedures

IFNDEF _DIRECTSHOW_INCLUDED_
_DIRECTSHOW_INCLUDED_ EQU 1

;// INCLUDE <Com.inc>


;////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////
;////                               these definitions are somewhat heirarchial
;////                               we start with the definitions of a GUID and
;////     D I R E C T   S H O W     the basic COM functionality. Then move on to the
;////                               direct show heirary. Use comInvoke to do the methods
;////




;// INCLUDELIB UUID         uuids.h has all the guids and iid's
;// INCLUDELIB STRMBASE     strmif.h has all the interface code

    ;// to avoid createing another section in the exe file
    ;// copy and paste the IID_Definitions



;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;////                                                       from strmif.h
;////   IFilterGraph::IUnknown
;////

    EXTERNDEF C CLSID_FilterGraph:GUID
    ;// MAKE_GUID CLSID_FilterGraph,e436ebb3-524f-11ce-9f53-0020af0ba770

    EXTERNDEF C IID_IFilterGraph:GUID
    ;// MAKE_GUID IID_IFilterGraph, 56a8689f-0ad4-11ce-b03a-0020af0ba770

    IFilterGraph STRUCT

        IUnknown {}

        COM_METHOD AddFilter, ppFilter, pName
        COM_METHOD RemoveFilter, ppFilter
        COM_METHOD EnumFilters, ppEnum
        COM_METHOD FindFilterByName, pName, ppFilter
        COM_METHOD ConnectDirect, ppinOut, ppinIn, pMediaType
        COM_METHOD Reconnect, ppin
        COM_METHOD Disconnect, ppin
        COM_METHOD SetDefaultSyncSource

    IFilterGraph ENDS


;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;////                                                       from strmif.h
;//// IGraphBuilder ::IFilterGraph( ::IUnknown )
;////

    EXTERNDEF C IID_IGraphBuilder:GUID
    ;// MAKE_GUID IID_IGraphBuilder,56a868a9-0ad4-11ce-b03a-0020af0ba770

    IGraphBuilder STRUCT

        IFilterGraph {}

        COM_METHOD Connect          , ppinOut, ppinIn
        COM_METHOD Render           , ppinOut
        COM_METHOD RenderFile       , pwszFile, pwszPlayList
        COM_METHOD AddSourceFilter  , pwszFileName, pwszFilterName, ppFilter
        COM_METHOD SetLogFile       , hFile
        COM_METHOD Abort
        COM_METHOD ShouldOperationContinue

    IGraphBuilder ENDS



;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;////                                                       from strmif.h
;////   IEnumFilters :: IUnknown
;////

        IEnumFilters STRUCT

            IUnknown {}

            COM_METHOD Next, numFilters, ppIFilterAry, pFetched
            COM_METHOD Skip, numFilters
            COM_METHOD Reset
            COM_METHOD Clone, ppIEnumFilters

        IEnumFilters endS


;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;////                                                       from strmif.h
;////   IEnumPins :: IUnknown
;////

        IEnumPins STRUCT

            IUnknown {}

            COM_METHOD Next, numPins, ppIPinAry, pFetched
            COM_METHOD Skip, numPins
            COM_METHOD Reset
            COM_METHOD Clone, ppIEnumPins

        IEnumPins ENDS

;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;////                                                       from strmif.h
;///    IEnumMediaTypes :: IUnknown
;///

        IEnumMediaTypes STRUCT

            IUnknown    {}

            COM_METHOD Next, numMediaTypes, ppMediaType, pFetched
            COM_METHOD Skip, numMediaTypes
            COM_METHOD Reset
            COM_METHOD Clone, ppIEnumMediaTypes

        IEnumMediaTypes ENDS


        AM_MEDIA_TYPE   STRUCT

            majortype               GUID    {}
            subtype                 GUID    {}
            bFixedSizeSamples       dd  0
            bTemporalCompression    dd  0
            lSampleSize             dd  0
            formattype              GUID {}
            pUnk            dd  0   ;// ptr to IUnknown
            cbFormat        dd  0
            pFormat         dd  0   ;// ptr to format info

        AM_MEDIA_TYPE ENDS


;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;////                                                       from strmif.h
;////   IFilterMapper :: IUnknown
;////


    EXTERNDEF C IID_IFilterMapper:GUID
    ;// MAKE_GUID IID_IFilterMapper, 56a868a3-0ad4-11ce-b03a-0020af0ba770

    IFilterMapper STRUCT

        IUnknown    {}

        COM_METHOD RegisterFilter, CLSID_Filter, pswName, dwMerit
        COM_METHOD RegisterFilterInstance, CLSID_Filter, pswName, pCLSIDMRId
        COM_METHOD RegisterPin, CLSID_Filter, pswName, bRendered, bOutput, bZero, bMany, CLSID_ConnectsToFilter, pswConnectsToPin
        COM_METHOD RegisterPinType, CLSID_Filter, pswName, CLSID_MajorType, CLSID_SubType
        COM_METHOD UnregisterFilter, CLSID_Filter
        COM_METHOD UnregisterFilterInstance, CLSID_MRId
        COM_METHOD UnregisterPin, CLSID_Filter, pswName
        COM_METHOD EnumMatchingFilters, ppEnum, dwMerit, bInputNeeded, CLSID_InMaj, CLSID_InSub,bRender,bOututNeeded,CLSID_OutMaj,CLSID_OutSub

    IFilterMapper ENDS






;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;////                                                       from strmif.h
;//// IEnumRegFilters :: IUnknown
;////

    EXTERNDEF C IID_IEnumRegFilters:GUID

    IEnumRegFilters STRUCT

        IUnknown {}

        COM_METHOD Next, dwNumFilters, pRegFilters, pNumFetched
        COM_METHOD Skip, dwNumToSkip
        COM_METHOD Reset
        COM_METHOD Clone, ppIEnumRegFilters

    IEnumRegFilters ENDS

    REGFILTER STRUCT

         clsid      GUID {}
         pswName    dd  ?

    REGFILTER ENDS



;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;////                                                       from strmif.h
;//// IMediaSeeking ::IUnknown
;////

    EXTERNDEF C IID_IMediaSeeking:GUID
    ;// MAKE_GUID IID_IMediaSeeking, 36B73880-C2C8-11CF-8B46-00805F6CEF60

    IMediaSeeking STRUCT

        IUnknown {}

        COM_METHOD GetCapabilities,     pCapabilities
        COM_METHOD CheckCapabilities,   pCapabilities
        COM_METHOD IsFormatSupported,   pguidFormat
        COM_METHOD QueryPreferredFormat,pquidFormat
        COM_METHOD GetTimeFormat,       pguidFormat
        COM_METHOD IsUsingTimeFormat,   pguidFormat
        COM_METHOD SetTimeFormat,       pguidFormat
        COM_METHOD GetDuration,         p64Duration
        COM_METHOD GetStopPosition,     pStop
        COM_METHOD GetCurrentPosition,  pCurrent
        COM_METHOD ConvertTimeFormat,   pTarget, pguidTargetFormat, dw64SourceHi, dw64SourceLo, pguidSourceFormat
        COM_METHOD SetPositions,        p64Current, dwCurrentFlags, p64Stop, dwStopFlags
        COM_METHOD GetPositions,        p64Current, p64Stop
        COM_METHOD GetAvailable,        p64Earliest, p64Latest
        COM_METHOD SetRate,             d64RateHi, d64RateLo
        COM_METHOD GetRate,             pd64Rate
        COM_METHOD GetPreroll,          p64Preroll

    IMediaSeeking ENDS

    ;//// flags for SetPositions
    AM_SEEKING_NoPositioning            equ  0
    AM_SEEKING_AbsolutePositioning      equ  1
    AM_SEEKING_RelativePositioning      equ  2
    AM_SEEKING_IncrementalPositioning   equ  3
    AM_SEEKING_PositioningBitsMask      equ  3
    AM_SEEKING_SeekToKeyFrame           equ  4
    AM_SEEKING_ReturnTime               equ  8
    AM_SEEKING_Segment                  equ 16
    AM_SEEKING_NoFlush                  equ 32

    ;// time formats    see IMediaSeeking main page

    ;//MAKE_GUID TIME_FORMAT_NONE       , 00000000-0000-0000-0000-000000000000
    ;//MAKE_GUID TIME_FORMAT_FRAME      , 7b785570-8c82-11cf-bc0c-00aa00ac74f6
    ;//MAKE_GUID TIME_FORMAT_BYTE       , 7b785571-8c82-11cf-bc0c-00aa00ac74f6
    ;//MAKE_GUID TIME_FORMAT_SAMPLE     , 7b785572-8c82-11cf-bc0c-00aa00ac74f6
    ;//MAKE_GUID TIME_FORMAT_FIELD      , 7b785573-8c82-11cf-bc0c-00aa00ac74f6
    ;//MAKE_GUID TIME_FORMAT_MEDIA_TIME , 7b785574-8c82-11cf-bc0c-00aa00ac74f6







;////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////
;////                                                       from control.h
;//// IVideoWindow  ::IDispatch ( ::IUnknown )
;////

    EXTERNDEF C IID_IVideoWindow:GUID

    IVideoWindow STRUCT

        IDispatch {}

        COM_METHOD put_Caption, pwszCaption
        COM_METHOD get_Caption, pwszCaption
        COM_METHOD put_WindowStyle, dwWindowStyle
        COM_METHOD get_WindowStyle, pWindowStyle
        COM_METHOD put_WindowStyleEx, dwWindowStyleEx
        COM_METHOD get_WindowStyleEx, pWindowStyleEx
        COM_METHOD put_AutoShow, dwAutoShow
        COM_METHOD get_AutoShow, pAutoShow
        COM_METHOD put_WindowState, dwWindowState
        COM_METHOD get_WindowState, pWindowState
        COM_METHOD put_BackgroundPalette, dwBackgroundPalette
        COM_METHOD get_BackgroundPalette, pBackgroundPalette
        COM_METHOD put_Visible, dwVisible
        COM_METHOD get_Visible, pVisible
        COM_METHOD put_Left, dwLeft
        COM_METHOD get_Left, pLeft
        COM_METHOD put_Width, dwWidth
        COM_METHOD get_Width, pWidth
        COM_METHOD put_Top, dwTop
        COM_METHOD get_Top, pTop
        COM_METHOD put_Height, dwHeight
        COM_METHOD get_Height, pHeight
        COM_METHOD put_Owner, hOwner
        COM_METHOD get_Owner, phOwner
        COM_METHOD put_MessageDrain, hDrain
        COM_METHOD get_MessageDrain, phDrain
        COM_METHOD get_BorderColor, pColor
        COM_METHOD put_BorderColor, dwColor
        COM_METHOD get_FullScreenMode, pFullScreenMode
        COM_METHOD put_FullScreenMode, dwFullScreenMode
        COM_METHOD SetWindowForeground, dwFocus
        COM_METHOD NotifyOwnerMessage, hWnd, uMsg, wParam, lParam
        COM_METHOD SetWindowPosition, dwLeft, dwTop, dwWidth, dwHeight
        COM_METHOD GetWindowPosition, pLeft, pTop, pWidth, pHeight
        COM_METHOD GetMinIdealImageSize, pWidth, pHeight
        COM_METHOD GetMaxIdealImageSize, pWidth, pHeight
        COM_METHOD GetRestorePosition, pLeft, pTop, pWidth, pHeight
        COM_METHOD HideCursor, dwHideCursor
        COM_METHOD IsCursorHidden, CursorHidden

    IVideoWindow endS



;////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////
;////                                                       from strmif.h
;//// IMediaEventSink ::IUnknown
;////

    EXTERNDEF C IID_IMediaEventSink:GUID
    ;// MAKE_GUID IID_IMediaEventSink, 56a868a2-0ad4-11ce-b03a-0020af0ba770

    IMediaEventSink STRUCT

        IUnknown    {}

        COM_METHOD Notify, EventCode, EventParam1, EventParam2

    IMediaEventSink ENDS

    ;// event codes     (from evcode.h)

    EC_COMPLETE EQU 1





;////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////
;////                                                       from control.h
;//// IMediaControl ::IDispatch ( ::IUnknown )
;////


    EXTERNDEF C IID_IMediaControl:GUID
    ;// MAKE_GUID IID_IMediaControl, 56A868B1-0AD4-11CE-B03A-0020AF0BA770

    IMediaControl STRUCT
        IDispatch   {}
        COM_METHOD Run
        COM_METHOD _Pause
        COM_METHOD Stop
        COM_METHOD GetState, msTimeout, pFileterState
        COM_METHOD RenderFile, pwszFilename
        COM_METHOD AddSourceFilter, pwszFilename, ppUnk
        COM_METHOD get_FilterCollection, ppUnk
        COM_METHOD get_RegFilterCollection, ppUnk
        COM_METHOD StopWhenReady
    IMediaControl ENDS




;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;////                                                       from strmif.h
;////   IAMovie :: IFilterGraph( ::IUnknown )
;////

    EXTERNDEF C IID_IAMovie:GUID
    ;// MAKE_GUID IID_IAMovie, 359ace10-7688-11cf-8b23-00805f6cef60

    IAMovie STRUCT

        IFilterGraph {}

        COM_METHOD Connect, pPinOut, pPinIn
        COM_METHOD Render, pPinOut
        COM_METHOD Run
        COM_METHOD _Pause
        COM_METHOD Stop
        COM_METHOD GetState, dwTimeout, pFilterState
        COM_METHOD RenderFile, pwszFilename
        COM_METHOD AddSourceFilter, pwszFilename, ppUnk
        COM_METHOD GetEventHandle, phEvent
        COM_METHOD GetEvent, plEventCode, pParam1, pParam2, dwTimeout
        COM_METHOD WaitForCompletion, dwTimeout, pEvCode
        COM_METHOD CancelDefaultHandling, dwEvCode
        COM_METHOD RestoreDefaultHandling, dwEvCode
        COM_METHOD get_Duration, pLength

        ;// don't use this yet!!!!!! should be QWORD
        COM_METHOD put_CurrentPosition, qwordTime

        COM_METHOD get_CurrentPosition, pd64Time
        COM_METHOD get_StopTime, pd64Time

        ;// don't use this yet!!!!!! should be QWORD
        COM_METHOD put_StopTime, qwordTime

        COM_METHOD get_PrerollTime, pd64Time

        ;// don't use this yet!!!!!! should be QWORD
        COM_METHOD put_PrerollTime, qwordTime
        ;// don't use this yet!!!!!! should be QWORD
        COM_METHOD put_Rate, qwordRate
        COM_METHOD get_Rate, pd64Rate
        COM_METHOD RemoveAllFilters
        COM_METHOD Play
        COM_METHOD PlayFile, pwszFilename
        COM_METHOD EnumFiltersByInterface, pGuid, ppIEnumFilters
        COM_METHOD EnumPins, ppIEnumPins
        COM_METHOD EnumPinsIn, ppIEnumPins
        COM_METHOD EnumPinsOut, ppIEnumPins
        COM_METHOD RenderAll
        COM_METHOD RenderNewFile, pwszFileName
        COM_METHOD FreeEventParams, dwEvCode, dwParam1, dwParam2

    IAMovie ENDS


;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;////                                                   from strmif.h
;////       IMediaFilter :: IPersist
;////
    EXTERNDEF C IID_IMediaFilter:GUID
    ;// MAKE_GUID IID_IMediaFilter, 56a86899-0ad4-11ce-b03a-0020af0ba770

    IMediaFilter STRUCT

        IPersist {}

        COM_METHOD Stop
        COM_METHOD _Pause
        COM_METHOD RunFilter, tStart_lo, tStart_hi

        COM_METHOD GetState, dwMilliSecsTimeout, pStateOut
        COM_METHOD SetSyncSource, pClock
        COM_METHOD GetSyncSource, ppClock

    IMediaFilter ENDS

    ;// values for get state

    FILTER_STATE_STOPPED    EQU 0   ;// The filter is not processing data.
    FILTER_STATE_PAUSED     EQU 1   ;// The filter is processing but not rendering data.
    FILTER_STATE_RUNNING    EQU 2   ;// The filter is processing and rendering data.


;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;////                                                   from strmif.h
;////       IBaseFilter :: IBaseMediaFilter             refered to as IFilter in documentation
;////

    EXTERNDEF C IID_IBaseFilter:GUID
    ;// MAKE_GUID IID_IBaseFilter, 56a86895-0ad4-11ce-b03a-0020af0ba770

    IBaseFilter STRUCT

        IMediaFilter {}

        COM_METHOD EnumPins, ppEnum
        COM_METHOD FindPin, pwszID, ppPin
        COM_METHOD QueryFilterInfo, pInfo
        COM_METHOD JoinFilterGraph, pGraph, pswzName ;//(do NOT AddRef on pGraph)
        COM_METHOD QueryVendorInfo, pwszVendorInfo

    IBaseFilter ENDS

    FILTER_INFO STRUCT

        wszName dw  128 DUP(?)
        pGraph  dd  0   ;// ptr to IFilterGraph (be sure to AddRef)

    FILTER_INFO ENDS



;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;////                                                  from strmif.h
;////       IPin :: IUnknown
;////

    EXTERNDEF IID_IPin:GUID
    ;// MAKE_GUID IID_IPin, 56a86891-0ad4-11ce-b03a-0020af0ba770

    IPin STRUCT

        IUnknown {}

        COM_METHOD Connect ,pReceivePin,pMediaType
        COM_METHOD ReceiveConnection, pConnectPin, pMediaType
        ;// IMPORTANT NOTE: documentaion states:
        ;//         return S_FALSE if media type is not acceptable
        ;// should be "return E_FAIL"
        COM_METHOD Disconnect

        COM_METHOD ConnectedTo, ppPin
        COM_METHOD ConnectionMediaType, pMediaType

        COM_METHOD QueryPinInfo, pPinInfo
        COM_METHOD QueryDirection,pPinDir
        COM_METHOD QueryId, pszwId
        COM_METHOD QueryAccept, pMediaType

        COM_METHOD EnumMediaTypes, ppEnum

        COM_METHOD QueryInternalConnections, ppPin, pNumPin

        COM_METHOD EndOfStream
        COM_METHOD BeginFlush
        COM_METHOD EndFlush

        ;// be carefull, parameters are 8 bytes each
        COM_METHOD NewSegment,tStart_lo,t_start_hi,tStop_lo,tStop_hi,dRate_lo,dRate_hi

    IPin ENDS


    PIN_DIRECTION_INPUT     EQU 0
    PIN_DIRECTION_OUTPUT    EQU 1

    PIN_INFO    STRUCT

        pFilter     dd  0   ;// ptr to IFilter (be sure to add ref)
        direction   dd  0   ;// PIN_DIRECTION value
        wszName     dw  128 DUP (?) ;// name of the pin

    PIN_INFO    ENDS


;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;////                                                  from strmif.h
;////       IMemInputPin :: IUnknown
;////


    EXTERNDEF C IID_IMemInputPin:GUID
    ;// MAKE_GUID IID_IMemInputPin, 56a8689d-0ad4-11ce-b03a-0020af0ba770

    IMemInputPin    STRUCT

        IUnknown    {}
        COM_METHOD GetAllocator, ppAllocator
        COM_METHOD NotifyAllocator,pAllocator,bReadOnly
        COM_METHOD GetAllocatorRequirements,pProps
        COM_METHOD Receive,pSample
        COM_METHOD ReceiveMultiple,ppMediaSamples,nSamples,nProcessed
        COM_METHOD ReceiveCanBlock

    IMemInputPin    ENDS

;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;////                                               from strmif.h
;////       IMemAllocater :: IUnknown
;////

    EXTERNDEF C IID_IMemAllocator:GUID
    ;// MAKE_GUID IID_IMemAllocator, 56a8689c-0ad4-11ce-b03a-0020af0ba770

    IMemAllocator   STRUCT

        IUnknown    {}

        COM_METHOD SetProperties,pRequest,pActual
        COM_METHOD GetProperties,pProps
        COM_METHOD Commit
        COM_METHOD Decommit
        COM_METHOD GetBuffer,ppBuffer,pStartTime,pEndTime,dwFlags
        COM_METHOD ReleaseBuffer,pBuffer

    IMemAllocator   ENDS

    ALLOCATOR_PROPERTIES    STRUCT

        cBuffers    dd  0
        cbBuffer    dd  0
        cbAlign     dd  0
        cbPrefix    dd  0

    ALLOCATOR_PROPERTIES    ENDS

    ;// EXTERN_C const IID IID_IAMDevMemoryAllocator;
    ;// interface DECLSPEC_UUID("c6545bf0-e76b-11d0-bd52-00a0c911ce86")


;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;////                                               from strmif.h
;////       IReferenceClock :: IUnknown
;////

    EXTERNDEF C  IID_IReferenceClock:GUID
    ;// MAKE_GUID IID_IReferenceClock, 56a86897-0ad4-11ce-b03a-0020af0ba770

    IReferenceClock STRUCT

        IUnknown    {}

        COM_METHOD _GetTime,pTime
        COM_METHOD AdviseTime,baseTime,streamTime,hEvent,pdwAdviseCookie
        COM_METHOD AdvisePeriodic,startTime,periodTime,hSemaphore,pdwAdviseCookie
        COM_METHOD Unadvise,dwAdviseCookie

    IReferenceClock ENDS



;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;////                                               from strmif.h
;////       IMediaSample :: IUnknown
;////

    EXTERNDEF C IID_IMediaSample:GUID
    ;// MAKE_GUID IID_IMediaSample, 56a8689a-0ad4-11ce-b03a-0020af0ba770

    IMediaSample    STRUCT

        IUnknown    {}

        COM_METHOD GetPointer,ppBuffer
        COM_METHOD GetSize
        COM_METHOD GetTime,pTimeStart,pTimeEnd
        COM_METHOD SetTime,pTimeStart,pTimeEnd
        COM_METHOD IsSyncPoint
        COM_METHOD SetSyncPoint,bIsSyncPoint
        COM_METHOD IsPreroll
        COM_METHOD SetPreroll,bIsPreroll
        COM_METHOD GetActualDataLength
        COM_METHOD SetActualDataLength,__MIDL_0008
        COM_METHOD GetMediaType,ppMediaType
        COM_METHOD SetMediaType,pMediaType
        COM_METHOD IsDiscontinuity
        COM_METHOD SetDiscontinuity,bDiscontinuity
        COM_METHOD GetMediaTime,pTimeStart,pTimeEnd
        COM_METHOD SetMediaTime,pTimeStart,pTimeEnd

    IMediaSample    ENDS

    ;// REFERENCE_TIME  qword


;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;////
;////   ERROR codes     see vfwmsgs.h
;////

    VFW_S_PARTIAL_RENDER        EQU 00040242h
    VFW_E_MEDIA_TIME_NOT_SET    EQU 80040251h


;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;////
;////   various extern defs for values
;////

;//EXTERNDEF C TIME_FORMAT_MEDIA_TIME:GUID

;//// there are the filter catagories

EXTERNDEF C CLSID_AudioInputDeviceCategory:GUID
EXTERNDEF C CLSID_AudioCompressorCategory:GUID
EXTERNDEF C CLSID_AudioRendererCategory:GUID
EXTERNDEF C CLSID_LegacyAmFilterCategory:GUID
EXTERNDEF C CLSID_MidiRendererCategory:GUID
EXTERNDEF C CLSID_VideoInputDeviceCategory:GUID
EXTERNDEF C CLSID_VideoCompressorCategory:GUID
EXTERNDEF C CLSID_ActiveMovieCategories:GUID


;//// media major types ( from uuids.h )

    ;// MAKE_GUID MEDIATYPE_Audio,      73647561-0000-0010-8000-00AA00389B71
    ;// MAKE_GUID MEDIATYPE_Midi,       7364696D-0000-0010-8000-00AA00389B71
    ;// MAKE_GUID MEDIATYPE_Stream,     e436eb83-524f-11ce-9f53-0020af0ba770
    ;// MAKE_GUID MEDIATYPE_Video,      73646976-0000-0010-8000-00AA00389B71

;//// media sub types   ( from uuids.h )

    ;// MAKE_GUID MEDIASUBTYPE_WAVE,    e436eb8b-524f-11ce-9f53-0020af0ba770
    ;// MAKE_GUID MEDIASUBTYPE_PCM,     00000001-0000-0010-8000-00AA00389B71
    ;// MAKE_GUID MEDIASUBTYPE_None,    e436eb8e-524f-11ce-9f53-0020af0ba770
    ;// MAKE_GUID MEDIASUBTYPE_RGB24,   e436eb7d-524f-11ce-9f53-0020af0ba770


;//// format types    ( from uuids.h )

    ;// MAKE_GUID FORMAT_WaveFormatEx,  05589f81-c356-11ce-bf01-00aa0055595a
    ;// MAKE_GUID FORMAT_VideoInfo,     05589f80-c356-11ce-bf01-00aa0055595a








;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;////
;////   more struct defs
;////


VIDEOINFOHEADER     STRUCT
    rcSource        RECT        {}
    rcTarget        RECT        {}
    dwBitRate       DWORD       ?
    dwBitErrorRate  DWORD       ?
    AvgTimePerFrame QWORD       ?
    bmiHeader       BITMAPINFOHEADER    {}
VIDEOINFOHEADER     ENDS









ENDIF ;// _DIRECTSHOW_INCLUDED_









