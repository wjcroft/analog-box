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
;//             -- interfaces transcibed from Microsoft VC5 header files
;//
;// History:
;//
;//     2.41 Mar 04, 2011 AJT
;//         Initial port to GPLv3
;//
;//     ABOX242 AJT -- detabified
;//
;//##////////////////////////////////////////////////////////////////////////
;//;                this file defines the com interface needed for DirectX anything
;//;    Com.inc     included is the GUID definition
;//;                cocreateinstance, coInitialize
;//;                and the defintions for IUnknown and IDispatch

IFNDEF _COM_INCLUDED_
_COM_INCLUDED_ EQU 1


;// INCLUDELIB UUID
;// INCLUDELIB STRMBASE


    INCLUDE <win32A_imp.inc>


;//////////////////////////////////////////////////////////////////;
;//////////////////////////////////////////////////////////////////;
;//
;//  data type naming prefixes
;//!!!pay attention and you won't get screwed up.
;//!!!NONE of the prototypes are typed!!!
;//
;//  p      pointer to a DWORD ( implied )
;//  p64    pointer to a 64 bit integer value
;//  pd64   pointer to a double ( real8 )
;//  d      double ( 8 bytes ), broken into HI ( adr + 4 )
;//                           , and LO ( adr )
;//  dw     DWORD by value
;//  pp     pointer to a pointer to a DWORD ( implied )
;//  pguid  pointer to a GUID
;//  pCLSID also a pointer to a guid
;//
;//  psz    pointer to a zero terminated ASCII ( one byte ) string
;//  pwsz   pointer to a zero terminated UNICODE ( two bytes ) string
;//
;//  h      handle by value (DWORD)
;//  ph     pointer to a handle
;//
;//  pAry   pointer to an array of ...


;/////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////
;///
;///                    for any classID or iterfaceID, delclare
;///    G U I D         a variable with externdef C as a GUID
;///                    ie:  externdef C CLSID_FilterGraph:GUID
;///                    use externdef C to create a leading underscore and preserve the case
    GUID STRUCT         ;// 16 bytes
        data1 DWORD ?
        data2 WORD ?
        data3 WORD ?
        data4 BYTE 2 DUP (?)
        data5 BYTE 6 DUP (?)
    GUID ENDS

    ;// some interfaces require pushing an entire guid
    ;// here's how it can be done
    ;// uses eax, ebx and edx

    PUSH_GUID   macro pGuid:req

        IFDIFI <ebx>, <pGuid>
            mov ebx, pGuid
        ENDIF
        sub  esp,10h
        mov  eax,esp
        mov  edx,DWORD PTR [ebx]
        mov  DWORD PTR [eax],edx
        mov  edx,DWORD PTR [ebx+4]
        mov  DWORD PTR [eax+4],edx
        mov  edx,DWORD PTR [ebx+8]
        mov  DWORD PTR [eax+8],edx
        mov  edx,DWORD PTR [ebx+0Ch]
        mov  DWORD PTR [eax+0Ch],edx

    ENDM

    EXTERNDEF C GUID_NULL:GUID


;///////////////////////////////////////////////////////////////////
;//                                                         macro
;//     MAKE_GUID
;//
;// use this to define a guid
;// this is not very sophisticated,
;// PAD ALL FIELDS TO THEIR REQUIRED LENGTHS !!
;//
;// example:
;//
;//     MAKE_GUID myGuid, c4bffd20-3fd8-11d5-ad84-9d4d1c56c624
;//
;// generates:
;//
;//     EXTERNDEF C myGuid:GUID
;//     myGuid GUID{ 0c4bffd20h, 03fd8h, 011d5h, { 084h, 0adh }, { 9dh, 04dh, 01ch, 056h, 0c6h, 024h } }
;//


    MAKE_GUID MACRO name:req, guid:req

        LOCAL g

        ;// emit the extern and name

        EXTERNDEF C name:GUID

        ;// build the guid declaration

        ;// c4bffd20-3fd8-11d5-ad 84-9d 4d 1c 56 c6 24
        ;//          1111 1111 22 22 22 22 23 33 33 33
        ;// 12345678 0123 5678 01 23 56 78 90 12 34 56

        g CATSTR <name GUID {0>, @SubStr(guid,  1,8), <h,0>, @SubStr(guid, 10,4)
        g CATSTR g, <h,0>, @SubStr(guid, 15,4), <h,{0>, @SubStr(guid, 20,2), <h,0>
        g CATSTR g, @SubStr(guid, 22,2), <h},{0>, @SubStr(guid, 25,2), <h,0>
        g CATSTR g, @SubStr(guid, 27,2), <h,0>, @SubStr(guid, 29,2), <h,0>
        g CATSTR g, @SubStr(guid, 31,2), <h,0>, @SubStr(guid, 33,2), <h,0>
        g CATSTR g, @SubStr(guid, 35,2),<h}}>

        g

        ENDM


;/////////////////////////////////////////////////////////////////
;//                                         macro
;//
;//     IF_SAME_GUID_GOTO                   destroys esi, edi, ecx
;//
;//

    IF_SAME_GUID_GOTO MACRO p1:req, p2:req, goto:req

        mov esi, p1
        mov ecx, SIZEOF GUID/4
        mov edi, p2
        repe cmpsd
        je goto

        ENDM

    ;// faster way, preserves both regs, uses eax

    IF_GUID_SAME_GOTO MACRO reg1:req, reg2:req, exit:req

        LOCAL fail

        .ERRIDNI <reg1>,<eax>,<reg cant be eax>
        .ERRIDNI <reg2>,<eax>,<reg cant be eax>

    ;// cmp reg1, reg2
    ;// je exit

        mov eax, DWORD PTR [reg1]
        cmp eax, DWORD PTR [reg2]
        jne fail

        mov eax, DWORD PTR [reg1+4]
        cmp eax, DWORD PTR [reg2+4]
        jne fail

        mov eax, DWORD PTR [reg1+8]
        cmp eax, DWORD PTR [reg2+8]
        jne fail

        mov eax, DWORD PTR [reg1+12]
        cmp eax, DWORD PTR [reg2+12]
        je exit

        fail:

        ENDM

    IF_GUID_DIFFERENT_GOTO MACRO reg1:req, reg2:req, exit:req

    ;// LOCAL match

        .ERRIDNI <reg1>,<eax>,<reg cant be eax>
        .ERRIDNI <reg2>,<eax>,<reg cant be eax>

    ;// cmp reg1, reg2
    ;// je match

        mov eax, DWORD PTR [reg1]
        cmp eax, DWORD PTR [reg2]
        jne exit

        mov eax, DWORD PTR [reg1+4]
        cmp eax, DWORD PTR [reg2+4]
        jne exit

        mov eax, DWORD PTR [reg1+8]
        cmp eax, DWORD PTR [reg2+8]
        jne exit

        mov eax, DWORD PTR [reg1+12]
        cmp eax, DWORD PTR [reg2+12]
        jne exit

    ;// match:

        ENDM




;////////////////////////////////////////////////////////////////
;//                                 macro
;//
;//     guid_Format         formats guid to a text buffer
;//
;// define sz_guid_format somewhere
;// sz_guid_format  db  "{%8.8X-%4.4X-%4.4X-%2.2X%2.2X-%2.2X%2.2X%2.2X%2.2X%2.2X%2.2X}",0

    guid_Format MACRO buf:req, pid:req

        .ERRIDNI <buf>,<eax>,<same regs>
        .ERRIDNI <pid>,<eax>,<same regs>
        .ERRIDNI <buf>,<pid>,<same regs>

        movzx eax, (GUID PTR [pid]).data5[5]    ;// 1
        push eax
        movzx eax, (GUID PTR [pid]).data5[4]    ;// 2
        push eax
        movzx eax, (GUID PTR [pid]).data5[3]    ;// 3
        push eax
        movzx eax, (GUID PTR [pid]).data5[2]    ;// 4
        push eax
        movzx eax, (GUID PTR [pid]).data5[1]    ;// 5
        push eax
        movzx eax, (GUID PTR [pid]).data5[0]    ;// 6
        push eax

        movzx eax, (GUID PTR [pid]).data4[1]    ;// 7
        push eax
        movzx eax, (GUID PTR [pid]).data4[0]    ;// 8
        push eax

        movzx eax, (GUID PTR [pid]).data3       ;// 9
        push eax
        movzx eax, (GUID PTR [pid]).data2       ;// 10
        push eax
        mov  eax, (GUID PTR [pid]).data1        ;// 11
        push eax

        push OFFSET sz_guid_format              ;// 12

        IF ( (OPATTR(buf)) AND 16)
        push buf
        ELSE
        lea eax, buf                            ;// 13
        push eax
        ENDIF

        call wsprintfA

        add esp, 13*4

        ENDM


    ;// down and dirty debug dump
    ;// ties in with DEBUG_MESSAGE_STATUS
    ;// see DEBUG_MESSAGE for more details

    ;// !!WARNING!! do not use esp for pid

    DEBUG_DUMP_GUID MACRO pid:req

        IFDEF DEBUGBUILD

            IF DEBUG_MESSAGE_STATUS EQ 2

            pushad
            pushf

            mov ecx, pid
            sub esp, 48
            mov edx, esp
            guid_Format edx, ecx
            invoke OutputDebugStringA, esp
            add esp, 48
            pushd 0d0ah
            invoke OutputDebugStringA, esp
            pop eax

            popf
            popad

            ENDIF

        ENDIF

        ENDM



;// an example is:

;// pIFilterMapper2 dd 0                    ;// pointer to the interface we want
;// externdef C CLSID_FilterGraph:GUID      ;// useually implemented in some library
;// externdef C IID_IEnumRegFilters:GUID    ;// useually implemented in some library
;//
;// invoke CoCreateInstance, ADDR CLSID_FilterGraph, 0, CLSCTX_INPROC_SERVER,
;//                         ADDR IID_IFilterMapper2, ADDR pIFilterMapper2
;//
;// comInvoke methods may then be called


;////////////////////////////////////////////////////////////////////////;
;////////////////////////////////////////////////////////////////////////;
;//                                     these definitions allow using
;// macro for interface definitions     the COM_INVOKE macro
;//                                     Each time the macro is used it generates
;//                                     three lines of code
;//  example:
;//
;//     COM_METHOD QueryInterface, pRefID, ppvObject
;//
;//  produces the following code:
;//
;//     COM_COM_QueryInterface TYPEDEF PROTO STDCALL pThis:DWORD, pRefID:DWORD, ppvObject:DWORD
;//     COM_QueryInterface TYPEDEF PTR COM_COM_QueryInterface
;//     QueryInterface COM_QueryInterface ?
;//
;//
;//  notes: all COM functions take the this parameter
;//         all parameters are assumed to be dwords, this cannot be overridden
;//

COM_METHOD  MACRO method_name:req, argList:VARARG

    LOCAL argText
    argText TEXTEQU <COM_COM_&method_name TYPEDEF PROTO STDCALL pThis:DWORD>

%   FOR arg, <argList>                              ;// add :DWORD to each arg
        argText CATSTR argText,<,>,<arg>,<:DWORD>   ;// append the DWORD declaration
    ENDM                                            ;// we're using a leading comma

    ;// define the typedeffed function call
    argText

    ;// define a pointer to that function call
    COM_&method_name TYPEDEF PTR COM_COM_&method_name

    ;// declare that pointer as a structure member
    method_name COM_&method_name ?

    ENDM


;//////////////////////////////////////////////////////////////////;
;//////////////////////////////////////////////////////////////////;
;//
;//                         uses eax, edx
;//     comInvoke macro
;//
COM_INVOKE MACRO interface:req, method:req, pointer:req, argList:VARARG

    .ERRIDNI <edx>,<pointer>,<INTERFACE POINTER can not be edx>

    IF ((OPATTR(pointer)) AND 16)       ;// register ?
        mov edx, DWORD PTR [pointer]
    ELSE
        IFDIFI <eax>,<pointer>
            mov eax, pointer            ;// use eax as interface pointer
        ENDIF
        mov edx, DWORD PTR [eax]    ;// use edx as member pointer
    ENDIF

    ASSUME edx:PTR interface

    IFB <argList>
        invoke interface.method[edx], pointer
    ELSE
        invoke interface.method[edx], pointer, &argList
    ENDIF

ENDM

com_invoke TEXTEQU <COM_INVOKE>



;//////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////
;//
;// com server macros       these are intended to clean up code
;//

    com_GetObject MACRO pThis:req, reg:req, inter:req

        mov reg, pThis
        ASSUME reg:PTR inter

        ENDM


    com_OrGetObject MACRO pThis:req, reg:req, inter:req

        or reg, pThis
        ASSUME reg:PTR inter

        ENDM

    ;// use this to load an preserve
    ;// take care to balance

    com_XchgObject MACRO pThis:req, reg:req, inter

        xchg reg, pThis
        IFNB <inter>
            ASSUME reg:PTR inter
        ELSE
            ASSUME reg:NOTHING
        ENDIF

        ENDM





;////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////
;//;
;//;        G E N E R A L   C O M   F U N C T I O N S
;//;


    INCLUDELIB OLE32        ;// required com function alitity


    ;// for OLE use the ole commands, do not call Coinitialize
    WIN32API OleInitialize, reserved:DWORD
    WIN32API OleUninitialize
    ;// for COM use COM functions, do not call OleInitialize

    WIN32API CoInitialize, reserved:DWORD
    ;// returns ERROR CODE, zero for success

    WIN32API CoUninitialize
    ;// no return value

    WIN32API CoCreateInstance, pCLSID:DWORD, pUnkOuter:DWORD, dwClsContext:DWORD, pRefID:DWORD, ppInterface:DWORD
    ;// returns zero or errorcode

        ; values for dwClsContext
        CLSCTX_INPROC_SERVER  equ  1
        CLSCTX_INPROC_HANDLER equ  2
        CLSCTX_LOCAL_SERVER   equ  4
        CLSCTX_REMOTE_SERVER  equ 16


    WIN32API CoTaskMemAlloc, dwSize:DWORD

    WIN32API CoGetClassObject, rclsid:DWORD, dwClsContext:DWORD, pServerInfo:DWORD, riid:DWORD, ppv:DWORD

    WIN32API CoFreeUnusedLibraries

    WIN32API CoTaskMemFree, pMem:DWORD
    ;// no return value


    WIN32API StringFromGUID2, pGuid:DWORD, pwsz:DWORD, cbMax:DWORD




comment ~ /*
    CoRegisterClassObject PROTO STDCALL rclsid:DWORD, pUnk:DWORD, dwClsContext:DWORD, dwFlags:DWORD, pdwRegister:DWORD
    CoRegisterClassObject PROTO STDCALL rclsid:DWORD, pUnk:DWORD, dwClsContext:DWORD, dwFlags:DWORD, pdwRegister:DWORD
    CoRegisterClassObject PROTO STDCALL rclsid:DWORD, pUnk:DWORD, dwClsContext:DWORD, dwFlags:DWORD, pdwRegister:DWORD
    CoRegisterClassObject PROTO STDCALL rclsid:DWORD, pUnk:DWORD, dwClsContext:DWORD, dwFlags:DWORD, pdwRegister:DWORD
    ;// returns zero or error code

        ;// values for dwFlags
        REGCLS_SINGLEUSE    EQU 0   ;// class object only generates one instance
        REGCLS_MULTIPLEUSE  EQU 1   ;// same class object genereates multiple inst.
                                    ;// and local automatically goes into inproc tbl.
        REGCLS_MULTI_SEPARATE EQU 2 ;// multiple use, but separate control over each
                                    ;// context.
        REGCLS_SUSPENDED    EQU 4   ;// register is as suspended, will be activated
                                    ;// when app calls CoResumeClassObjects

    CoRevokeClassObject PROTO STDCALL dwRegister:DWORD
    CoRevokeClassObject PROTO STDCALL dwRegister:DWORD
    CoRevokeClassObject PROTO STDCALL dwRegister:DWORD
    CoRevokeClassObject PROTO STDCALL dwRegister:DWORD
*/ comment ~







;// common base interfaces


;////////////////////////////////////////////////////////////////////////;
;////////////////////////////////////////////////////////////////////////;
;//
;//     IUnknown
;//
    EXTERNDEF C IID_IUnknown:GUID
    ;// MAKE_GUID IID_IUnknown:00000000-0000-0000-C000-000000000046

    IUnknown STRUCT

        COM_METHOD QueryInterface, pRefID, ppvObject
        COM_METHOD AddRef
        COM_METHOD Release

    IUnknown ENDS



;////////////////////////////////////////////////////////////////////////;
;////////////////////////////////////////////////////////////////////////;
;//
;//     IPersist :: IUnknown
;//

    IPersist STRUCT

        IUnknown {}

        COM_METHOD GetClassID, ppClsid

    IPersist ENDS

;////////////////////////////////////////////////////////////////////////;
;////////////////////////////////////////////////////////////////////////;
;//
;//     IDispatch :: IUnknown
;//


    IDispatch   STRUCT

        IUnknown    {}

        COM_METHOD GetTypeInfoCount,pctinfo
        COM_METHOD GetTypeInfo,itinfo,lcid,pptinfo
        COM_METHOD GetIDsOfNames,riid,rgszNames,cNames,lcid,rgdispid
        COM_METHOD _Invoke,dispidMember,riid,lcid,wFlags,pdispparams,pvarResult,pexcepinfo,puArgErr

    IDispatch   ENDS


;////////////////////////////////////////////////////////////////////////;
;////////////////////////////////////////////////////////////////////////;
;//
;//     IClassFactory :: IUnknown
;//

    EXTERNDEF C IID_IClassFactory:GUID
    ;// MAKE_GUID IID_IClassFactory:00000001-0000-0000-C000-000000000046


    IClassFactory   STRUCT

        IUnknown    {}

        COM_METHOD CreateInstance, pUnkOutter, pRefIID, ppObject
        COM_METHOD LockServer, bLock

    IClassFactory   ENDS













;/////////////////////////////////////////////////////////////////////////
;//                                                        from winerror.h
;//     E R R O R   C O D E S
;//


    NOERROR EQU 0
    S_OK    EQU 0
    S_FALSE equ 1



;// MessageId: E_UNEXPECTED
;// MessageText:  Catastrophic failure

    E_UNEXPECTED                 EQU    8000FFFFh


;// MessageId: E_NOTIMPL
;// MessageText: Not implemented

    E_NOTIMPL                        EQU 80004001h

;// MessageId: E_OUTOFMEMORY
;// MessageText: Ran out of memory

    E_OUTOFMEMORY                    EQU 8007000Eh

;// MessageId: E_INVALIDARG
;// MessageText: One or more arguments are invalid

    E_INVALIDARG                     EQU 80070057h

;// MessageId: E_NOINTERFACE
;// MessageText: No such interface supported

    E_NOINTERFACE                    EQU 80004002h

;// MessageId: E_POINTER
;// MessageText: Invalid pointer

    E_POINTER                        EQU 80004003h

;// MessageId: E_HANDLE
;// MessageText:  Invalid handle

    E_HANDLE                         EQU 80070006h

;// MessageId: E_ABORT
;// MessageText:  Operation aborted

    E_ABORT                          EQU 80004004h

;// MessageId: E_FAIL
;// MessageText: Unspecified error

    E_FAIL                           EQU 80004005h

;// MessageId: E_ACCESSDENIED
;// MessageText: General access denied error

    E_ACCESSDENIED                   EQU 80070005h








ENDIF ;// _COM_INCLUDED_