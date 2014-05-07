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
;//             -- Parts transcribed from Microsoft DXSDK header files.
;//
;// History:
;//
;//     2.41 Mar 04, 2011 AJT
;//         Initial port to GPLv3
;//
;//     ABOX242 AJT -- detabified
;//
;//##////////////////////////////////////////////////////////////////////////
;//                     this is a running include file for direct sound
;// DirectSound.inc     capabilities. functions are added as required
;//                     note that we're only providing Interfaces
;// DX5/6               see Com.inc for more functions

;// include <Com.inc>

IFNDEF _DIRECTSOUND_INCLUDED_
_DIRECTSOUND_INCLUDED_ EQU

    INCLUDE com.inc

    IFNDEF DIRECTSOUND_NOLIB

        INCLUDELIB DSOUND


    ;////////////////////////////////////////////////////////////////////////
    ;////////////////////////////////////////////////////////////////////////
    ;//
    ;// function imported from dsound.dll
    ;//

        DSEnumCallback PROTO STDCALL pGuid:DWORD, pszDescription:DWORD, psszModule:DWORD, pContext:DWORD
        ;// must return true to continue

        DirectSoundEnumerateA PROTO STDCALL pCallBack:DWORD, pContext:DWORD
        ;// returns zero for sucess

        DirectSoundCreate PROTO STDCALL pGUID:DWORD, ppIDirectSound:DWORD, ppUnkOuter:DWORD
        ;// returns zero for sucess

        DirectSoundCaptureEnumerateA PROTO STDCALL pCallBack:DWORD, pContext:DWORD
        ;// returns zero for sucess

        DirectSoundCaptureCreate PROTO STDCALL pGUID:DWORD, ppIDirectSoundCapture:DWORD, ppUnkOuter:DWORD
        ;// returns zero for success

    ENDIF   ;// DIRECTSOUND_NOLIB



;////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////
;//                                                         from dsound.h
;// IDirectSound::IUnknown
;//

    IDirectSound STRUCT

        IUnknown {}

        COM_METHOD CreateSoundBuffer, pDSBufferDesc, ppIDirectSoundBuffer, pUnk_MustBeNull
        COM_METHOD GetCaps, pDSCaps
        COM_METHOD DuplicateSoundBuffer, pDirectSoundBuffer, ppNewBuffer
        COM_METHOD SetCooperativeLevel, hWnd, dwLevel
        COM_METHOD Compact
        COM_METHOD GetSpeakerConfig,  pSpeakerConfig
        COM_METHOD SetSpeakerConfig,  pSpeakerConfig
        COM_METHOD Initialize, pGuid

    IDirectSound ENDS


;////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////
;//                                                         from dsound.h
;// IDirectSoundBuffer::IUnknown
;//

    IDirectSoundBuffer STRUCT

        IUnknown {}

        COM_METHOD GetCaps, pDSBCaps
        COM_METHOD GetCurrentPosition, pdwPlayCursor, pdwWriteCursor
        COM_METHOD GetFormat, pWaveFormatEX, dwSizeAllocated, pdwSizeWritten
        COM_METHOD GetVolume, pdwVolume
        COM_METHOD GetPan, pdwPan
        COM_METHOD GetFrequency, pdwFreq
        COM_METHOD GetStatus, pdwStatus

        COM_METHOD InitializeBuffer, pIDirectSound, pDSBufferDesc
        ;// note: this funtion is refered to as Initialize in the documentation

        COM_METHOD LockBuffer, dwWriteCursor, dwWriteBytes, ppAudioPtr1, pdwAudioBytes1, ppAudioPtr2, pdwAudioBytes2, dwFlags
        ;// note: this function is called Lock in the documentation

        COM_METHOD Play, dwReserved1, dwReserved2, dwFlags
        COM_METHOD SetCurrentPosition, dwNewPosition
        COM_METHOD SetFormat, pWaveFormatEX
        COM_METHOD SetVolume, dwVolume
        COM_METHOD SetPan, dwPan
        COM_METHOD SetFrequency, dwFrequency
        COM_METHOD Stop
        COM_METHOD Unlock, pAudioPtr1, dwAudioBytes1, pAudioPtr2, dwAudioBytes2
        COM_METHOD Restore

    IDirectSoundBuffer ENDS



;////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////
;//                                                         from dsound.h
;// IDirectSoundCapture::IUnknown
;//

    IDirectSoundCapture STRUCT

        IUnknown {}

        COM_METHOD CreateCaptureBuffer, pDSCBufferDesc, ppDirectSoundCaptureBuffer, pUnk_MustBeNull
        COM_METHOD GetCaps, pDSCCaps
        COM_METHOD Initialize, pGuid

    IDirectSoundCapture ENDS



;////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////
;//                                                         from dsound.h
;// IDirectSoundCaptureBuffer::IUnknown
;//

    IDirectSoundCaptureBuffer STRUCT

        IUnknown {}

        COM_METHOD GetCaps, pDSBCaps
        COM_METHOD GetCurrentPosition, pdwCapturePos, pdwReadPos
        COM_METHOD GetFormat, pWaveFormatEX, dwSizeAllocated, pdwSizeWritten
        COM_METHOD GetStatus, pdwStatus
        COM_METHOD InitializeBuffer, pIDirectSound, pDSBufferDesc
        ;// note: this funtion is refered to as Initialize in the documentation

        COM_METHOD LockBuffer, dwWriteCursor, dwWriteBytes, ppAudioPtr1, pdwAudioBytes1, ppAudioPtr2, pdwAudioBytes2, dwFlags
        ;// note: this function is called Lock in the documentation

        COM_METHOD Start, dwFlags
        COM_METHOD Stop
        COM_METHOD Unlock, pAudioPtr1, dwAudioBytes1, pAudioPtr2, dwAudioBytes2
        COM_METHOD Restore

    IDirectSoundCaptureBuffer ENDS


;////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////
;//                                                         from dsound.h
;// IDirectSoundNotify::IUnknown     use query interface to get this
;//

    IDirectSoundNotify STRUCT

        IUnknown {}

        COM_METHOD SetNotificationPositions, dwNumPositions, pAryPositionNotify

    IDirectSoundNotify ENDS



;////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////
;//
;// GUIDS
;//

comment ~ /*

// Direct Sound Component GUID    {47D4D946-62E8-11cf-93BC-444553540000}
DEFINE_GUID(CLSID_DirectSound,
0x47d4d946, 0x62e8, 0x11cf, 0x93, 0xbc, 0x44, 0x45, 0x53, 0x54, 0x0, 0x0);

// DirectSound 279afa83-4981-11ce-a521-0020af0be560
DEFINE_GUID(IID_IDirectSound,0x279AFA83,0x4981,0x11CE,0xA5,0x21,0x00,0x20,0xAF,0x0B,0xE5,0x60);

// DirectSoundBuffer 279afa85-4981-11ce-a521-0020af0be560
DEFINE_GUID(IID_IDirectSoundBuffer,0x279AFA85,0x4981,0x11CE,0xA5,0x21,0x00,0x20,0xAF,0x0B,0xE5,0x60);

*/ comment ~

;////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////
;//
;//
;//



;// DirectSound Caps

    DSCAPS STRUCT

        dwSize                          DWORD   SIZEOF DSCAPS
        dwFlags                         DWORD   0
        dwMinSecondarySampleRate        DWORD   0
        dwMaxSecondarySampleRate        DWORD   0
        dwPrimaryBuffers                DWORD   0
        dwMaxHwMixingAllBuffers         DWORD   0
        dwMaxHwMixingStaticBuffers      DWORD   0
        dwMaxHwMixingStreamingBuffers   DWORD   0
        dwFreeHwMixingAllBuffers        DWORD   0
        dwFreeHwMixingStaticBuffers     DWORD   0
        dwFreeHwMixingStreamingBuffers  DWORD   0
        dwMaxHw3DAllBuffers             DWORD   0
        dwMaxHw3DStaticBuffers          DWORD   0
        dwMaxHw3DStreamingBuffers       DWORD   0
        dwFreeHw3DAllBuffers            DWORD   0
        dwFreeHw3DStaticBuffers         DWORD   0
        dwFreeHw3DStreamingBuffers      DWORD   0
        dwTotalHwMemBytes               DWORD   0
        dwFreeHwMemBytes                DWORD   0
        dwMaxContigFreeHwMemBytes       DWORD   0
        dwUnlockTransferRateHwBuffers   DWORD   0
        dwPlayCpuOverheadSwBuffers      DWORD   0
        dwReserved1                     DWORD   0
        dwReserved2                     DWORD   0

    DSCAPS ENDS

;////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////
;//
;//
;//


    ;// DirectSound Buffer Caps

        DSBCAPS STRUCT

            dwSize                  DWORD SIZEOF DSBCAPS
            dwFlags                 DWORD 0
            dwBufferBytes           DWORD 0
            dwUnlockTransferRate    DWORD 0
            dwPlayCpuOverhead       DWORD 0

        DSBCAPS ENDS

;////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////
;//
;//
;//



    ;// direct sound buffer description

        DSBUFFERDESC STRUCT

            dwSize          dd SIZEOF DSBUFFERDESC
            dwFlags         dd 0
            dwBufferBytes   dd 0
            dwReserved      dd 0
            lpwfxFormat     dd 0

        DSBUFFERDESC ENDS


;////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////
;//
;//
;//
    ;// flags

        DSCAPS_PRIMARYMONO      equ 00000001h
        DSCAPS_PRIMARYSTEREO    equ 00000002h
        DSCAPS_PRIMARY8BIT      equ 00000004h
        DSCAPS_PRIMARY16BIT     equ 00000008h
        DSCAPS_CONTINUOUSRATE   equ 00000010h
        DSCAPS_EMULDRIVER       equ 00000020h
        DSCAPS_CERTIFIED        equ 00000040h
        DSCAPS_SECONDARYMONO    equ 00000100h
        DSCAPS_SECONDARYSTEREO  equ 00000200h
        DSCAPS_SECONDARY8BIT    equ 00000400h
        DSCAPS_SECONDARY16BIT   equ 00000800h

        DSBPLAY_LOOPING         equ 00000001h
        DSCBSTART_LOOPING       equ 00000001h

        DSBSTATUS_PLAYING       equ 00000001h
        DSBSTATUS_BUFFERLOST    equ 00000002h
        DSBSTATUS_LOOPING       equ 00000004h


        DSBLOCK_FROMWRITECURSOR equ 00000001h



        DSSCL_NORMAL            equ    1
        DSSCL_PRIORITY          equ    2
        DSSCL_EXCLUSIVE         equ    3
        DSSCL_WRITEPRIMARY      equ    4

        DSBCAPS_PRIMARYBUFFER       equ 00000001h
        DSBCAPS_STATIC              equ 00000002h
        DSBCAPS_LOCHARDWARE         equ 00000004h
        DSBCAPS_LOCSOFTWARE         equ 00000008h
        DSBCAPS_CTRLFREQUENCY       equ 00000020h
        DSBCAPS_CTRLPAN             equ 00000040h
        DSBCAPS_CTRLVOLUME          equ 00000080h
        DSBCAPS_CTRLDEFAULT         equ 000000E0h  ;// Pan + volume + frequency.
        DSBCAPS_CTRLALL             equ 000000E0h  ;// All control capabilities
        DSBCAPS_STICKYFOCUS         equ 00004000h
        DSBCAPS_GLOBALFOCUS         equ 00008000h  ;// copied from WINE !!
        DSBCAPS_GETCURRENTPOSITION2 equ 00010000h  ;// More accurate play cursor under emulation

        DSSPEAKER_HEADPHONE   equ  1
        DSSPEAKER_MONO        equ  2
        DSSPEAKER_QUAD        equ  3
        DSSPEAKER_STEREO      equ  4
        DSSPEAKER_SURROUND    equ  5



;////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////
;//
;//
;//
    DSCBUFFERDESC STRUCT

        dwSize  dd  0   ;//
        dwFlags dd  0
        dwBufferBytes   dd  0;//
        dwReserved  dd 0
        pWaveFormat dd  0

    DSCBUFFERDESC ENDS



;////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////
;//
;//
;//
    DSCCAPS STRUCT

        dwSize      dd  SIZEOF DSCCAPS
        dwFlags     dd  0
        dwFormats   dd  0
        dwChannels  dd  0

    DSCCAPS ENDS


;////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////
;//
;//
;//
    DSCBCAPS STRUCT

        dwSize  dd  SIZEOF DSCBCAPS
        dwFlags dd  0
        dwBufferBytes   dd  0
        dwReserved      dd  0

    DSCBCAPS ENDS


;////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////
;//
;//
;//


    DSBPOSITIONNOTIFY STRUCT

        dwOffset        dd 0
        hEventNotify    dd 0

    DSBPOSITIONNOTIFY ENDS



;////////////////////////////////////////////////////////////////////////;//;//;//;//;//;
;////////////////////////////////////////////////////////////////////////;//;//;//;//;//;
;////////////////////////////////////////////////////////////////////////;//;//;//;//;//;
;//
;//
;//     E R R O R   C O D E S

    DS_OK equ 0

    DSERR_ALLOCATED  equ 8878000Ah
        ;// The call failed because resources (such as a priority level)
        ;//  were already being used by another caller.


    DSERR_CONTROLUNAVAIL equ 8878001Eh
        ;// The control (vol,pan,etc.) requested by the caller is not available.

        ;//
    DSERR_INVALIDPARAM   equ 80070057h
        ;// An invalid parameter was passed to the returning function

    DSERR_INVALIDCALL equ 88780032h
        ;// This call is not valid for the current state of this object

    DSERR_GENERIC   equ 80004005 ;//                   E_FAIL
        ;// An undetermined error occured inside the DSound subsystem

    DSERR_PRIOLEVELNEEDED   equ 88780046h
        ;// The caller does not have the priority level required for the function to
        ;// succeed.

        ;//DSERR_OUTOFMEMORY               E_OUTOFMEMORY
        ;// The DSound subsystem couldn't allocate sufficient memory to complete the
        ;// caller's request.

    DSERR_BADFORMAT   equ 88780064h
        ;// The specified WAVE format is not supported

        ;//DSERR_UNSUPPORTED               E_NOTIMPL
        ;// The function called is not supported at this time

    DSERR_NODRIVER  equ 88780078h
        ;// No sound driver is available for use

    DSERR_ALREADYINITIALIZED  equ 88780082
        ;// This object is already initialized

        ;//DSERR_NOAGGREGATION             CLASS_E_NOAGGREGATION
        ;// This object does not support aggregation

    DSERR_BUFFERLOST  equ 88780096h
        ;// The buffer memory has been lost, and must be Restored.

    DSERR_OTHERAPPHASPRIO  equ 887800A0h
        ;// Another app has a higher priority level, preventing this call from
        ;// succeeding.

    DSERR_UNINITIALIZED   equ 887800AAh
        ;// The Initialize() member on the Direct Sound Object has not been
        ;// called or called successfully before calls to other members.


ENDIF   ;// _DIRECTSOUND_INCLUDED_