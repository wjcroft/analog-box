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
;//             -- portions transcribed from Microsoft VC5 header files.
;//
;// History:
;//
;//     2.41 Mar 04, 2011 AJT
;//         Initial port to GPLv3
;//
;//     ABOX242 AJT -- detabified
;//
;//
;//     ABOX242 AJT
;//         added NOIMPORT32 macro in order to build manual import machanisms in newer masm and link
;//
;//##////////////////////////////////////////////////////////////////////////
;//                  this is running file of Win32A etal API calls for MASM
;// Win32A_imp.inc   these are listed as they were used in various projects
;//
;//                 this version links with jumpless calls
IFNDEF _WIN32A_IMP_INCLUDED_
_WIN32A_IMP_INCLUDED_ EQU 1


;// linkage:
;//
;//  link with nodefaultlibs OFF
;//
;// make sure model is set BEFORE including this

    INCLUDELIB kernel32
    INCLUDELIB user32
    INCLUDELIB gdi32
    INCLUDELIB advapi32
    INCLUDELIB comdlg32
    INCLUDELIB comctl32
    INCLUDELIB winmm
    INCLUDELIB vfw32
    INCLUDELIB shell32

    INCLUDE <geometry.inc>  ;// point and rect definitions and macros



;////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////
;//
;//                                 this proved to be usesful
;//   E R R O R   T R A P P I N G   so it's included here
;//                                 DEBUG_IF is really more useful ...



;////////////////////////////////////////////////////////////////////
;//
;//
;//     linker manipulation
;//     to avoid creating the usual jump table
;//     all these functions are defined using the following format
;//
comment ~ /*

    _imp__FUNCTION_NAME PROTO STDCALL args...
    _ptr__FUNCTION_NAME TYPEDEF PROTO STDCALL args
    _typ__FUNCTION_NAME TYPEDEF PTR _ptr__FUNCTION_NAME
    FUNCTION_NAME TEXTEQU <(_typ__FUNCTION_NAME PTR _imp__FUNCTION_NAME)>

    doing this still allows:

        invoke FUNCTION_NAME, args...

    but instead of calling a jump command
    it calls the address directly
    doing this may save several dozen cycles, both due to cache misses and call/return tracking

    a macro could be used, (ie WIN32API FUNCTION NAME args,...) ....

    here it is:

*/ comment ~

    WIN32API MACRO name:req, args:VARARG

        _imp__&name PROTO STDCALL args
        _ptr__&name TYPEDEF PROTO STDCALL args
        _typ__&name TYPEDEF PTR _ptr__&name
        name TEXTEQU <(_typ__&name PTR _imp__&name )>

        ENDM

    ;// many months later, this is a better version
    ;// does not require the :DWORD qualifier
    ;// ASSUMES ALL PARAMETERS ARE DWORDS


    IMPORT32 MACRO name:req, args:VARARG

        LOCAL arg_count, arg_list

        arg_count = 0
        arg_list TEXTEQU <>

        FOR arg, <args>
            IF arg_count EQ 0
                arg_list TEXTEQU <arg&:DWORD>
            ELSE
                arg_list CATSTR arg_list,<,>,<arg>,<:DWORD>
            ENDIF
            arg_count = arg_count+1
        ENDM

        _imp__&name PROTO STDCALL arg_list
        _ptr__&name TYPEDEF PROTO STDCALL arg_list
        _typ__&name TYPEDEF PTR _ptr__&name
        name TEXTEQU <(_typ__&name PTR _imp__&name )>

        ENDM

    ;// ABOX242 AJT -- NOIMPORT removes the PROTO declaration
    ;//    user MUST define a DWORD with the name _imp__NAME in order to use invove on NAME

    NOIMPORT32 MACRO name:req, args:VARARG

        LOCAL arg_count, arg_list

        arg_count = 0
        arg_list TEXTEQU <>

        FOR arg, <args>
            IF arg_count EQ 0
                arg_list TEXTEQU <arg&:DWORD>
            ELSE
                arg_list CATSTR arg_list,<,>,<arg>,<:DWORD>
            ENDIF
            arg_count = arg_count+1
        ENDM

    ;;  _imp__&name PROTO STDCALL arg_list <-- no, do not try import, we'll do ourselves ...
        _ptr__&name TYPEDEF PROTO STDCALL arg_list
        _typ__&name TYPEDEF PTR _ptr__&name
        name TEXTEQU <(_typ__&name PTR _imp__&name )>

        ENDM







;////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////
;//
;//
;//  G E N E R A L   L I B R A R Y
;//


    ;//                            POINT and RECT are defined
    ;// C O O R D I N A T E S      in geometry.inc
    ;//


        WIN32API PtInRect, pRect:DWORD, X:DWORD, Y:DWORD
        ;// return true if pt is inside the rect, or on the left, or top
        ;// botom and right are considered outside


        WIN32API ClientToScreen, hWnd:DWORD, pPoint:DWORD
        ;// returns non-zero for success

        WIN32API ScreenToClient, hWnd:DWORD, pPoint:DWORD
        ;// returns non-zero for success


        WIN32API MapWindowPoints, hWndFrom:DWORD, hWndTo:DWORD, pPoints:DWORD, dwNumPoints:DWORD
        ;// returns offset, see help for details


        WIN32API AdjustWindowRect, pRect:DWORD, dwStyle:DWORD, bMenu:DWORD
        ;// returns non zero for success


    ;//
    ;// S T R I N G S
    ;//

        ;// C CALL
        _imp__wsprintfA PROTO C pBuf:DWORD, pFmt:DWORD, args:VARARG
        _ptr__wsprintfA TYPEDEF PROTO C pBuf:DWORD, pFmt:DWORD, args:VARARG
        _typ__wsprintfA TYPEDEF PTR _ptr__wsprintfA
        wsprintfA TEXTEQU <(_typ__wsprintfA PTR _imp__wsprintfA )>
        ;//returns length of string

        _imp__wsprintfW PROTO C pBuf:DWORD, pFmt:DWORD, args:VARARG
        _ptr__wsprintfW TYPEDEF PROTO C pBuf:DWORD, pFmt:DWORD, args:VARARG
        _typ__wsprintfW TYPEDEF PTR _ptr__wsprintfW
        wsprintfW TEXTEQU <(_typ__wsprintfW PTR _imp__wsprintfW )>
        ;//returns length of string

        WIN32API lstrlen, pDest:DWORD
        WIN32API lstrlenA, pDest:DWORD
        ;// returns string length

        ;WIN32API lstrcat, pDest:DWORD, pSource:DWORD
        WIN32API lstrcatA, pDest:DWORD, pSource:DWORD
        ;// returns pointer to dest or NULL for error

        ;//WIN32API lstrcpy, pDest:DWORD, pSource:DWORD
        WIN32API lstrcpyA, pDest:DWORD, pSource:DWORD
        ;// returns pointer to dest or NULL for error

        ;//WIN32API lstrcmp, p1:DWORD, p2:DWORD
        WIN32API lstrcmpA, p1:DWORD, p2:DWORD
        ;// returns the comparison code

        ;//WIN32API lstrcmpi, p1:DWORD, p2:DWORD
        WIN32API lstrcmpiA, p1:DWORD, p2:DWORD
        ;// returns the comparison code

        WIN32API WideCharToMultiByte, CodePage:DWORD, dwFlags:DWORD, pWideCharStr:DWORD, cchWideChar:DWORD, pMultiByteStr:DWORD, cchMultiByte:DWORD, pDefaultChar:DWORD, pUsedDefaultChar:DWORD
        WIN32API MultiByteToWideChar, CodePage:DWORD, dwFlags:DWORD, lpMultiByteStr:DWORD, cchMultiByte:DWORD, lpWideCharStr:DWORD, cchWideChar:DWORD





;////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////
;//
;//
;//     windows System stuff


        WIN32API GetSystemInfo, pSysInfo:DWORD
        ;// no return value

        SYSTEM_INFO STRUCT

            dwFlags     dd  0   ;// see documentation

            dwPageSize                      dd  0   ;//
            lpMinimumApplicationAddress     dd  0   ;//  LPVOID
            lpMaximumApplicationAddress     dd  0   ;//  LPVOID
            dwActiveProcessorMask           dd  0   ;//  DWORD
            dwNumberOfProcessors            dd  0   ;//  DWORD
            dwProcessorType                 dd  0   ;//  DWORD
            dwAllocationGranularity         dd  0   ;//  DWORD
            wProcessorLevel                 dw  0   ;//  WORD
            wProcessorRevision              dw  0   ;//  WORD

        SYSTEM_INFO ENDS

        WIN32API GetVersionExA, pOSVersionInfo:DWORD
        ;//returns non zero for sucess

        OSVERSIONINFO STRUCT
            dwOSVersionInfoSize dd  SIZEOF OSVERSIONINFO
            dwMajorVersion      dd  0
            dwMinorVersion      dd  0
            dwBuildNumber       dd  0
            dwPlatformId        dd  0
            szCSDVersion        db  128 DUP (0)
        OSVERSIONINFO ENDS

        VER_PLATFORM_WIN32s         EQU 0
        VER_PLATFORM_WIN32_WINDOWS  EQU 1
        VER_PLATFORM_WIN32_NT       EQU 2


        WIN32API GetSystemMetrics, index:DWORD
        ;// returns said data

            ;// GetSystemMetrics() codes    winuser.h

            SM_CXSCREEN    EQU         0
            SM_CYSCREEN    EQU         1
            SM_CXVSCROLL   EQU         2
            SM_CYHSCROLL   EQU         3
            SM_CYCAPTION   EQU         4
            SM_CXBORDER    EQU         5
            SM_CYBORDER    EQU         6
            SM_CXDLGFRAME  EQU         7
            SM_CYDLGFRAME  EQU         8
            SM_CYVTHUMB    EQU         9
            SM_CXHTHUMB    EQU         10
            SM_CXICON      EQU         11
            SM_CYICON          EQU     12
            SM_CXCURSOR        EQU     13
            SM_CYCURSOR        EQU     14
            SM_CYMENU          EQU     15
            SM_CXFULLSCREEN    EQU     16
            SM_CYFULLSCREEN    EQU     17
            SM_CYKANJIWINDOW   EQU     18
            SM_MOUSEPRESENT    EQU     19
            SM_CYVSCROLL       EQU     20
            SM_CXHSCROLL       EQU     21
            SM_DEBUG           EQU     22
            SM_SWAPBUTTON      EQU     23
            SM_RESERVED1       EQU     24
            SM_RESERVED2       EQU     25
            SM_RESERVED3       EQU     26
            SM_RESERVED4       EQU     27
            SM_CXMIN           EQU     28
            SM_CYMIN           EQU     29
            SM_CXSIZE          EQU     30
            SM_CYSIZE          EQU     31
            SM_CXFRAME         EQU     32
            SM_CYFRAME         EQU     33
            SM_CXMINTRACK      EQU     34
            SM_CYMINTRACK      EQU     35
            SM_CXDOUBLECLK       EQU   36
            SM_CYDOUBLECLK       EQU   37
            SM_CXICONSPACING     EQU   38
            SM_CYICONSPACING     EQU   39
            SM_MENUDROPALIGNMENT EQU   40
            SM_PENWINDOWS        EQU   41
            SM_DBCSENABLED       EQU   42
            SM_CMOUSEBUTTONS     EQU   43
            SM_SECURE            EQU   44
            SM_CXEDGE            EQU   45
            SM_CYEDGE            EQU   46
            SM_CXMINSPACING      EQU   47
            SM_CYMINSPACING      EQU   48
            SM_CXSMICON          EQU   49
            SM_CYSMICON          EQU   50
            SM_CYSMCAPTION       EQU   51
            SM_CXSMSIZE          EQU   52
            SM_CYSMSIZE          EQU   53
            SM_CXMENUSIZE        EQU   54
            SM_CYMENUSIZE        EQU   55
            SM_ARRANGE           EQU   56
            SM_CXMINIMIZED       EQU   57
            SM_CYMINIMIZED       EQU   58
            SM_CXMAXTRACK        EQU   59
            SM_CYMAXTRACK        EQU   60
            SM_CXMAXIMIZED       EQU   61
            SM_CYMAXIMIZED       EQU   62
            SM_NETWORK           EQU   63
            SM_CLEANBOOT         EQU   67
            SM_CXDRAG            EQU   68
            SM_CYDRAG            EQU   69
            SM_SHOWSOUNDS        EQU   70
            SM_CXMENUCHECK       EQU   71
            SM_CYMENUCHECK       EQU   72
            SM_SLOWMACHINE       EQU   73
            SM_MIDEASTENABLED    EQU   74
            SM_MOUSEWHEELPRESENT EQU   75

;////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////
;//
;//     V x D
;//

    WIN32API DeviceIoControl, hDevice:DWORD, dwControlCode:DWORD,   pInBuffer:DWORD, sizInBuffer:DWORD,     pOutBuffer:DWORD, sizOutBuffer:DWORD,       pBytesReturned:DWORD,           pOverlapped:DWORD

    ;// returns non zero for sucess


;////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////
;//
;//
;////   M O D U L E S  AND P R O C E S S E S
;//

    WIN32API GetModuleHandleA, szModuleName:PTR BTYE
    ;// returns HMODULE -- same as hInstance

    WIN32API GetModuleFileNameA, hModule:DWORD, pString:DWORD, dwSize:DWORD

    WIN32API GetCurrentProcessId
    ;// returns the process id

    WIN32API GetCurrentProcess
    ;// return a process handle

    IMPORT32 GetWindowThreadProcessId, hWnd, pProcessID

    WIN32API ExitProcess, uExitCode:DWORD
    ;// use this exit the program

comment ~ /*
    WIN32API DllEntryPoint, hInstDLL:DWORD, dwReason:DWORD, reserved:DWORD
    _ptr__DllEntryPoint TYPEDEF, hInstDLL:DWORD, dwReason:DWORD, reserved:DWORD
    _typ__DllEntryPoint TYPEDEF PTR _ptr__DllEntryPoint
    DllEntryPoint TEXTEQU <(_typ__DllEntryPoint PTR WIN32API DllEntryPoint )>
    ;// this is a placeholder function to be defined in the dll code
    ;// return TRUE to indicate success
*/ comment ~
        ;// values of dwReason
        DLL_PROCESS_ATTACH EQU 1
        DLL_THREAD_ATTACH  EQU 2
        DLL_THREAD_DETACH  EQU 3
        DLL_PROCESS_DETACH EQU 0

    WIN32API GetCommandLineA
    ;// returns pointer to command line in eax

    WIN32API LoadLibraryA, pszLibName:DWORD
    ;// return hModule or zero for error

    WIN32API GetProcAddress, hModule:DWORD, pszName:DWORD
    ;// return the address of the process

    WIN32API FreeLibrary, hModule:DWORD
    ;// returns non zero for sucess

    WIN32API CreateProcessA, pApplicationName:DWORD,pCommandLine:DWORD,pProcessSecurityAttributes:DWORD,pThreadSecurityAttributes:DWORD,bInheritHandles:DWORD,dwCreationFlags:DWORD,pEnvironment:DWORD,pCurrentDirectory:DWORD,pStartupInfo:DWORD,pProcessInformation:DWORD
    ;// returns handle or error

        ;//
        ;// dwCreationFlag values
        ;//

        DEBUG_PROCESS               EQU 00000001h
        DEBUG_ONLY_THIS_PROCESS     EQU 00000002h
        CREATE_SUSPENDED            EQU 00000004h
        DETACHED_PROCESS            EQU 00000008h
        CREATE_NEW_CONSOLE          EQU 00000010h
        NORMAL_PRIORITY_CLASS       EQU 00000020h
        IDLE_PRIORITY_CLASS         EQU 00000040h
        HIGH_PRIORITY_CLASS         EQU 00000080h
        REALTIME_PRIORITY_CLASS     EQU 00000100h
        CREATE_NEW_PROCESS_GROUP    EQU 00000200h
        CREATE_UNICODE_ENVIRONMENT  EQU 00000400h
        CREATE_SEPARATE_WOW_VDM     EQU 00000800h
        CREATE_SHARED_WOW_VDM       EQU 00001000h
        CREATE_FORCEDOS             EQU 00002000h
        CREATE_DEFAULT_ERROR_MODE   EQU 04000000h
        CREATE_NO_WINDOW            EQU 08000000h
        PROFILE_USER                EQU 10000000h
        PROFILE_KERNEL              EQU 20000000h
        PROFILE_SERVER              EQU 40000000h


    WIN32API OpenProcess, dwDesiredAccess:DWORD, bInherit:DWORD, dwProcessId:DWORD
    ;// returns process handle or zero for error

        SYNCHRONIZE                 EQU 00100000h
        STANDARD_RIGHTS_REQUIRED    EQU 000F0000h

        PROCESS_TERMINATE         EQU 0001h
        PROCESS_CREATE_THREAD     EQU 0002h
        PROCESS_VM_OPERATION      EQU 0008h
        PROCESS_VM_READ           EQU 0010h
        PROCESS_VM_WRITE          EQU 0020h
        PROCESS_DUP_HANDLE        EQU 0040h
        PROCESS_CREATE_PROCESS    EQU 0080h
        PROCESS_SET_QUOTA         EQU 0100h
        PROCESS_SET_INFORMATION   EQU 0200h
        PROCESS_QUERY_INFORMATION EQU 0400h
        PROCESS_ALL_ACCESS        EQU STANDARD_RIGHTS_REQUIRED OR SYNCHRONIZE OR 0xFFFh




;//////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////
;//
;////
;////     T H R E A D S
;////

    WIN32API CreateThread, pThreadAttributes:DWORD, dwStackSize:DWORD, pStartAddress:DWORD, pParameter:DWORD, wCreationFlags:DWORD, pThreadId:DWORD
    ;// returns a thread ID or NULL for error

    WIN32API ExitThread, dwExitCode:DWORD
    ;// function does not return

    WIN32API PostThreadMessageA, dwThreadID:DWORD, dwMsg:DWORD, wParam:DWORD, lParam:DWORD
    ;// returns non zero for sucess

    WIN32API GetCurrentThread
    ;// returns thread handle

    WIN32API GetCurrentThreadId
    ;// returns thread identifier

    WIN32API SetPriorityClass, hProcess:DWORD, dwPriorityClass:DWORD
    ;// returns zero for error

    WIN32API GetPriorityClass, hProcess:DWORD
    ;// returns zero for error

        ;// values for priority class
        NORMAL_PRIORITY_CLASS    EQU 00000020h
        IDLE_PRIORITY_CLASS      EQU 00000040h
        HIGH_PRIORITY_CLASS      EQU 00000080h
        REALTIME_PRIORITY_CLASS  EQU 00000100h

    WIN32API SetThreadPriority, dwThreadID:DWORD, dwPriority:DWORD
    ;// returns zero for error

    WIN32API GetThreadPriority, dwThreadID:DWORD
    ;// returns zero for error

        ;// values for priority level
        THREAD_BASE_PRIORITY_LOWRT  EQU 15  ;// value that gets a thread to LowRealtime-1
        THREAD_BASE_PRIORITY_MAX    EQU 2   ;// maximum thread base priority boost
        THREAD_BASE_PRIORITY_MIN    EQU -2  ;// minimum thread base priority boost
        THREAD_BASE_PRIORITY_IDLE   EQU -15 ;// value that gets a thread to idle

        THREAD_PRIORITY_LOWEST          EQU THREAD_BASE_PRIORITY_MIN
        THREAD_PRIORITY_BELOW_NORMAL    EQU (THREAD_PRIORITY_LOWEST+1)
        THREAD_PRIORITY_NORMAL          EQU 0
        THREAD_PRIORITY_HIGHEST         EQU THREAD_BASE_PRIORITY_MAX
        THREAD_PRIORITY_ABOVE_NORMAL    EQU (THREAD_PRIORITY_HIGHEST-1)


    WIN32API DisableThreadLibraryCalls, hModule:DWORD


    WIN32API EnumThreadWindows, hWnd:DWORD, pEnumThreadWindowsProc:DWORD, pParam:DWORD



    ;//
    ;// T I M I N G
    ;//

        WIN32API Sleep, dwMilliseconds:DWORD
        ;// returns nothing





;////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////
;//
;////   W I N D O W S
;//

    ;//
    ;// W I N D O W   C L A S S E S
    ;//

        WIN32API RegisterClassExA, pWndClass:DWORD
        ;//returns ATOM or zero for error

        comment ~ /* to create the STRUCT and call, use

            pushd hIconSm       ;// 11  WNDCLASSEX.hIconSm
            pushd lpszClassName ;// 10  WNDCLASSEX.lpszClassName
            pushd lpszMenuName  ;// 9   WNDCLASSEX.lpszMenuName
            pushd hbrBackground ;// 8   WNDCLASSEX.hbrBackground
            pushd hCursor       ;// 7   WNDCLASSEX.hCursor
            pushd hIcon         ;// 6   WNDCLASSEX.hIcon
            pushd hInstance     ;// 5   WNDCLASSEX.hInstance
            pushd dwWndExtra    ;// 4   WNDCLASSEX.dwWndExtra
            pushd dwClsExtra    ;// 3   WNDCLASSEX.dwClsExtra
            pushd pWndProc      ;// 2   WNDCLASSEX.pWndProc
            pushd style         ;// 1   WNDCLASSEX.style
            pushd SIZEOF WNDCLASSEXA    ;// 0   WNDCLASSEX.

            push esp
            call RegisterClassExA
            and eax, 0FFFFh ;// atoms are WORDS !!

            ;// make sure to clean up the stack
            ;// add esp sizeof WNDCLASSEXA

            ;// or keep with    st_wndClass TEXTEQU <(WNDCLASSEX PTR [esp+depth*4])>
            ;//         and     st_wndClass TEXTEQU <>

        */ comment ~



        WIN32API IsWindow, hWnd:DWORD
        ;// returns non zero for yes








        WIN32API FindWindowA, pClassName:DWORD, pWindowName:DWORD
        ;// return the hWnd, or NULL

        WNDCLASSEXA STRUCT
            cbSize      dd  48
            style       dd  ?
            lpfnWndProc dd  ?
            cbClsExtra  dd  ?
            cbWndExtra  dd  ?
            hInstance   dd  ?
            hIcon       dd  ?
            hCursor     dd  ?
            hbrBackground   dd ?
            lpszMenuName    dd ?
            lpszClassName   dd ?
            hIconSm         dd ?
        WNDCLASSEXA ENDS

        ;// class styles
        CS_VREDRAW          EQU 0001h
        CS_HREDRAW          EQU 0002h
        CS_KEYCVTWINDOW     EQU 0004h
        CS_DBLCLKS          EQU 0008h
        CS_OWNDC            EQU 0020h
        CS_CLASSDC          EQU 0040h
        CS_PARENTDC         EQU 0080h
        CS_NOKEYCVT         EQU 0100h
        CS_NOCLOSE          EQU 0200h
        CS_SAVEBITS         EQU 0800h
        CS_BYTEALIGNCLIENT  EQU 1000h
        CS_BYTEALIGNWINDOW  EQU 2000h
        CS_GLOBALCLASS      EQU 4000h
        CS_IME              EQU 10000h

        ;// colors
        COLOR_SCROLLBAR        EQU 0
        COLOR_BACKGROUND       EQU 1
        COLOR_ACTIVECAPTION    EQU 2
        COLOR_INACTIVECAPTION  EQU 3
        COLOR_MENU             EQU 4
        COLOR_WINDOW           EQU 5
        COLOR_WINDOWFRAME      EQU 6
        COLOR_MENUTEXT         EQU 7
        COLOR_WINDOWTEXT       EQU 8
        COLOR_CAPTIONTEXT      EQU 9
        COLOR_ACTIVEBORDER     EQU 10
        COLOR_INACTIVEBORDER   EQU 11
        COLOR_APPWORKSPACE     EQU 12
        COLOR_HIGHLIGHT        EQU 13
        COLOR_HIGHLIGHTTEXT    EQU 14
        COLOR_BTNFACE          EQU 15
        COLOR_BTNSHADOW        EQU 16
        COLOR_GRAYTEXT         EQU 17
        COLOR_BTNTEXT          EQU 18
        COLOR_INACTIVECAPTIONTEXT EQU 19
        COLOR_BTNHIGHLIGHT     EQU 20
        COLOR_3DDKSHADOW       EQU 21
        COLOR_3DLIGHT          EQU 22
        COLOR_INFOTEXT         EQU 23
        COLOR_INFOBK           EQU 24


    ;//
    ;// C R E A T I O N
    ;//


        WIN32API CreateWindowExA, dwExStyle:DWORD,  lpClassName:ptr,    lpWindowName:ptr,    dwStyle:DWORD, X:DWORD,    Y:DWORD,    nWidth:DWORD,    nHeight:DWORD, hWndParent:DWORD,    hMenu:DWORD,    hInstance:DWORD,   lpParam:ptr
        ;//returns hWnd

            ;// to manually call
            ;// 11  lpParam:ptr
            ;// 10  hInstance:DWORD,
            ;// 9   hMenu:DWORD,
            ;// 8   hWndParent:DWORD,
            ;// 7   nHeight:DWORD,
            ;// 6   nWidth:DWORD,
            ;// 5   Y:DWORD,
            ;// 4   X:DWORD,
            ;// 3   dwStyle:DWORD,
            ;// 2   lpWindowName:ptr,
            ;// 1   lpClassName:ptr,
            ;// 0   dwExStyle:DWORD,
            ;//call CreateWindowExA,


        WIN32API CreateDialogParamA, hInstance:DWORD, pTemplate:DWORD, hParent:DWORD, pProc:DWORD, dwInit:DWORD
        ;// return window handle or zero for error

        WIN32API IsDialogMessage, hWnd:DWORD, pMsg:DWORD
        ;// returns non zero is message has been processed

        WIN32API SetWindowTextA, hWnd:DWORD, pszText:DWORD
        ;// returns nonzero for success

        WIN32API GetWindowTextA, hWnd:DWORD, pString:DWORD, dwMaxCount:DWORD
        ;// returns the number copied

        WIN32API GetWindowTextLengthA, hWnd:DWORD
        ;// returns the length, not including the null


        ;// default size and position
        CW_USEDEFAULT       EQU 80000000h

        ;// window styles
        WS_OVERLAPPED       EQU 00000000h
        WS_POPUP            EQU 80000000h
        WS_CHILD            EQU 40000000h
        WS_MINIMIZE         EQU 20000000h
        WS_VISIBLE          EQU 10000000h
        WS_DISABLED         EQU 08000000h
        WS_CLIPSIBLINGS     EQU 04000000h
        WS_CLIPCHILDREN     EQU 02000000h
        WS_MAXIMIZE         EQU 01000000h
        WS_BORDER           EQU 00800000h
        WS_DLGFRAME         EQU 00400000h
        WS_VSCROLL          EQU 00200000h
        WS_HSCROLL          EQU 00100000h
        WS_SYSMENU          EQU 00080000h
        WS_THICKFRAME       EQU 00040000h   ;// resizable
        WS_GROUP            EQU 00020000h
        WS_TABSTOP          EQU 00010000h
        WS_MINIMIZEBOX      EQU 00020000h
        WS_MAXIMIZEBOX      EQU 00010000h

        WS_CAPTION          EQU 00C00000h     ;// WS_BORDER | WS_DLGFRAME

        MDIS_ALLCHILDSTYLES EQU 00000001h

        ;// extended styles
        WS_EX_DLGMODALFRAME     EQU 00000001h
        WS_EX_NOPARENTNOTIFY    EQU 00000004h
        WS_EX_TOPMOST           EQU 00000008h
        WS_EX_ACCEPTFILES       EQU 00000010h
        WS_EX_TRANSPARENT       EQU 00000020h
        WS_EX_MDICHILD          EQU 00000040h
        WS_EX_TOOLWINDOW        EQU 00000080h
        WS_EX_WINDOWEDGE        EQU 00000100h
        WS_EX_CLIENTEDGE        EQU 00000200h
        WS_EX_CONTEXTHELP       EQU 00000400h
        WS_EX_RIGHT             EQU 00001000h
        WS_EX_LEFT              EQU 00000000h
        WS_EX_RTLREADING        EQU 00002000h
        WS_EX_LTRREADING        EQU 00000000h
        WS_EX_LEFTSCROLLBAR     EQU 00004000h
        WS_EX_RIGHTSCROLLBAR    EQU 00000000h
        WS_EX_CONTROLPARENT     EQU 00010000h
        WS_EX_STATICEDGE        EQU 00020000h
        WS_EX_APPWINDOW         EQU 00040000h

        ;// dialog box styles

        DS_ABSALIGN         EQU 0001h
        DS_SYSMODAL         EQU 0002h
        DS_LOCALEDIT        EQU 0020h   ;// Edit items get Local storage.
        DS_SETFONT          EQU 0040h   ;// User specified font for Dlg controls
        DS_MODALFRAME       EQU 0080h   ;// Can be combined with WS_CAPTION
        DS_NOIDLEMSG        EQU 0100h   ;// WM_ENTERIDLE message will not be sent
        DS_SETFOREGROUND    EQU 0200h   ;// not in win3.1
        DS_3DLOOK           EQU 0004h
        DS_FIXEDSYS         EQU 0008h
        DS_NOFAILCREATE     EQU 0010h
        DS_CONTROL          EQU 0400h
        DS_CENTER           EQU 0800h
        DS_CENTERMOUSE      EQU 1000h
        DS_CONTEXTHELP      EQU 2000h


        ;// return values from a dialog box

            IDOK      EQU 1
            IDCANCEL  EQU 2
            IDABORT   EQU 3
            IDRETRY   EQU 4
            IDIGNORE  EQU 5
            IDYES     EQU 6
            IDNO      EQU 7
            IDCLOSE   EQU 8
            IDHELP    EQU 9


        ;////////////////////////////////////////////////////////////////
        ;////////////////////////////////////////////////////////////////
        ;//
        ;////     C O N T R O L S
        ;//


        ;//
        ;//  E D I T
        ;//

            ;// EDIT CONTROL STYLES

            ES_LEFT             EQU 0000h
            ES_CENTER           EQU 0001h
            ES_RIGHT            EQU 0002h
            ES_MULTILINE        EQU 0004h
            ES_UPPERCASE        EQU 0008h
            ES_LOWERCASE        EQU 0010h
            ES_PASSWORD         EQU 0020h
            ES_AUTOVSCROLL      EQU 0040h
            ES_AUTOHSCROLL      EQU 0080h
            ES_NOHIDESEL        EQU 0100h
            ES_OEMCONVERT       EQU 0400h
            ES_READONLY         EQU 0800h
            ES_WANTRETURN       EQU 1000h
            ES_NUMBER           EQU 2000h


            ;// Edit Control Notification Codes
            ;// sent as WM_COMMAND to parent window
            EN_SETFOCUS         EQU 0100h
            EN_KILLFOCUS        EQU 0200h
            EN_CHANGE           EQU 0300h
            EN_UPDATE           EQU 0400h
            EN_ERRSPACE         EQU 0500h
            EN_MAXTEXT          EQU 0501h
            EN_HSCROLL          EQU 0601h
            EN_VSCROLL          EQU 0602h


            ;// Edit Control Messages

            EM_GETSEL               EQU 00B0h
            EM_SETSEL               EQU 00B1h
            EM_GETRECT              EQU 00B2h
            EM_SETRECT              EQU 00B3h
            EM_SETRECTNP            EQU 00B4h
            EM_SCROLL               EQU 00B5h
            EM_LINESCROLL           EQU 00B6h
            EM_SCROLLCARET          EQU 00B7h
            EM_GETMODIFY            EQU 00B8h
            EM_SETMODIFY            EQU 00B9h
            EM_GETLINECOUNT         EQU 00BAh
            EM_LINEINDEX            EQU 00BBh
            EM_SETHANDLE            EQU 00BCh
            EM_GETHANDLE            EQU 00BDh
            EM_GETTHUMB             EQU 00BEh
            EM_LINELENGTH           EQU 00C1h
            EM_REPLACESEL           EQU 00C2h
            EM_GETLINE              EQU 00C4h
            EM_LIMITTEXT            EQU 00C5h
            EM_CANUNDO              EQU 00C6h
            EM_UNDO                 EQU 00C7h
            EM_FMTLINES             EQU 00C8h
            EM_LINEFROMCHAR         EQU 00C9h
            EM_SETTABSTOPS          EQU 00CBh
            EM_SETPASSWORDCHAR      EQU 00CCh
            EM_EMPTYUNDOBUFFER      EQU 00CDh
            EM_GETFIRSTVISIBLELINE  EQU 00CEh
            EM_SETREADONLY          EQU 00CFh
            EM_SETWORDBREAKPROC     EQU 00D0h
            EM_GETWORDBREAKPROC     EQU 00D1h
            EM_GETPASSWORDCHAR      EQU 00D2h

            EM_SETMARGINS           EQU 00D3h
            EM_GETMARGINS           EQU 00D4h
            EM_SETLIMITTEXT         EQU EM_LIMITTEXT  ;// win40 Name change
            EM_GETLIMITTEXT         EQU 00D5h
            EM_POSFROMCHAR          EQU 00D6h
            EM_CHARFROMPOS          EQU 00D7h


        ;//
        ;// S T A T I C
        ;//
            ;// Static Control Constants ( for style in create window )

            SS_LEFT             EQU 00000000h
            SS_CENTER           EQU 00000001h
            SS_RIGHT            EQU 00000002h
            SS_ICON             EQU 00000003h
            SS_BLACKRECT        EQU 00000004h
            SS_GRAYRECT         EQU 00000005h
            SS_WHITERECT        EQU 00000006h
            SS_BLACKFRAME       EQU 00000007h
            SS_GRAYFRAME        EQU 00000008h
            SS_WHITEFRAME       EQU 00000009h
            SS_USERITEM         EQU 0000000Ah
            SS_SIMPLE           EQU 0000000Bh
            SS_LEFTNOWORDWRAP   EQU 0000000Ch

            SS_OWNERDRAW        EQU 0000000Dh
            SS_BITMAP           EQU 0000000Eh
            SS_ENHMETAFILE      EQU 0000000Fh
            SS_ETCHEDHORZ       EQU 00000010h
            SS_ETCHEDVERT       EQU 00000011h
            SS_ETCHEDFRAME      EQU 00000012h
            SS_TYPEMASK         EQU 0000001Fh

            SS_NOPREFIX         EQU 00000080h ;// Don't do "&" character translation

            SS_NOTIFY           EQU 00000100h
            SS_CENTERIMAGE      EQU 00000200h
            SS_RIGHTJUST        EQU 00000400h
            SS_REALSIZEIMAGE    EQU 00000800h
            SS_SUNKEN           EQU 00001000h
            SS_ENDELLIPSIS      EQU 00004000h
            SS_PATHELLIPSIS     EQU 00008000h
            SS_WORDELLIPSIS     EQU 0000C000h
            SS_ELLIPSISMASK     EQU 0000C000h





        ;//
        ;//  B U T T O N S
        ;//

            WIN32API CheckRadioButton, hDlg:DWORD,  nIDFirstButton:DWORD,   nIDLastButton:DWORD,    nIDCheckButton:DWORD
            ;// returns non zero for sucess


            WIN32API CheckDlgButton, hDlg:DWORD, dwIDButton:DWORD, dwCheck:DWORD
            ;// returns non zero for sucess

            WIN32API IsDlgButtonChecked, hDlg:DWORD, dwIDButton:DWORD
            ;// returna a BST_ state



        ;// control style

        ;// Button Control Styles

            BS_PUSHBUTTON       EQU 00000000h
            BS_DEFPUSHBUTTON    EQU 00000001h
            BS_CHECKBOX         EQU 00000002h
            BS_AUTOCHECKBOX     EQU 00000003h
            BS_RADIOBUTTON      EQU 00000004h
            BS_3STATE           EQU 00000005h
            BS_AUTO3STATE       EQU 00000006h
            BS_GROUPBOX         EQU 00000007h
            BS_USERBUTTON       EQU 00000008h
            BS_AUTORADIOBUTTON  EQU 00000009h
            BS_OWNERDRAW        EQU 0000000Bh
            BS_LEFTTEXT         EQU 00000020h
            BS_TEXT             EQU 00000000h
            BS_ICON             EQU 00000040h
            BS_BITMAP           EQU 00000080h
            BS_LEFT             EQU 00000100h
            BS_RIGHT            EQU 00000200h
            BS_CENTER           EQU 00000300h
            BS_TOP              EQU 00000400h
            BS_BOTTOM           EQU 00000800h
            BS_VCENTER          EQU 00000C00h
            BS_PUSHLIKE         EQU 00001000h
            BS_MULTILINE        EQU 00002000h
            BS_NOTIFY           EQU 00004000h
            BS_FLAT             EQU 00008000h

        ;// Button Control Messages

            BM_GETCHECK        EQU 00F0h
            BM_SETCHECK        EQU 00F1h
            BM_GETSTATE        EQU 00F2h
            BM_SETSTATE        EQU 00F3h
            BM_SETSTYLE        EQU 00F4h
            BM_CLICK           EQU 00F5h
            BM_GETIMAGE        EQU 00F6h
            BM_SETIMAGE        EQU 00F7h
                IMAGE_BITMAP    EQU 0
                IMAGE_ICON      EQU 1

            ;// button states
            BST_UNCHECKED      EQU 0000h
            BST_CHECKED        EQU 0001h
            BST_INDETERMINATE  EQU 0002h
            BST_PUSHED         EQU 0004h
            BST_FOCUS          EQU 0008h




        ;//
        ;// S C R O L L   B A R S
        ;//

        WIN32API SetScrollPos, hWndScroll:DWORD, dwBarFlag:DWORD, dwPos:DWORD, bRedraw:DWORD
        ;// return previous position of scroll bar

        WIN32API SetScrollInfo, hWndScroll:DWORD, dwBarFlag:DWORD, pScrollInfo:DWORD, bRedraw:DWORD
        ;// returns current position of scroll box

        WIN32API GetScrollInfo, hWndScroll:DWORD, dwBarFlag:DWORD, pScrollInfo:DWORD
        ;// returns non zero if values are retrieved

            ;// dwBarFlag values

            SB_HORZ      EQU    0
            SB_VERT      EQU    1
            SB_CTL       EQU    2
            SB_BOTH      EQU    3


            ;// SCROLLINFO STRUCT

            SCROLLINFO STRUCT
                dwSize      dd  SIZEOF SCROLLINFO
                dwMask      dd      0
                dwMin       SDWORD  0
                dwMax       SDWORD  0
                dwPage      dd      0
                dwPos       SDWORD  0
                dwTrackPos  dd      0
            SCROLLINFO ENDS
            ;// size 28 bytes, 7 dwords

            ;// values for dwMask
            SIF_RANGE           EQU 0001
            SIF_PAGE            EQU 0002
            SIF_POS             EQU 0004
            SIF_DISABLENOSCROLL EQU 0008
            SIF_TRACKPOS        EQU 0010
            SIF_ALL             EQU SIF_RANGE + SIF_PAGE + SIF_POS + SIF_TRACKPOS

            ;// scrollbar styles

            SBS_HORZ                    EQU 0000h
            SBS_VERT                    EQU 0001h
            SBS_TOPALIGN                EQU 0002h
            SBS_LEFTALIGN               EQU 0002h
            SBS_BOTTOMALIGN             EQU 0004h
            SBS_RIGHTALIGN              EQU 0004h
            SBS_SIZEBOXTOPLEFTALIGN     EQU 0002h
            SBS_SIZEBOXBOTTOMRIGHTALIGN EQU 0004h
            SBS_SIZEBOX                 EQU 0008h
            SBS_SIZEGRIP                EQU 0010h

        ;//
        ;// L I S T B O X
        ;//

            ;//Listbox Styles
            LBS_NOTIFY            EQU 0001h
            LBS_SORT              EQU 0002h
            LBS_NOREDRAW          EQU 0004h
            LBS_MULTIPLESEL       EQU 0008h
            LBS_OWNERDRAWFIXED    EQU 0010h
            LBS_OWNERDRAWVARIABLE EQU 0020h
            LBS_HASSTRINGS        EQU 0040h
            LBS_USETABSTOPS       EQU 0080h
            LBS_NOINTEGRALHEIGHT  EQU 0100h
            LBS_MULTICOLUMN       EQU 0200h
            LBS_WANTKEYBOARDINPUT EQU 0400h
            LBS_EXTENDEDSEL       EQU 0800h
            LBS_DISABLENOSCROLL   EQU 1000h
            LBS_NODATA            EQU 2000h
            LBS_NOSEL             EQU 4000h

        ;//
        ;// C O M B O B O X
        ;//


            ;// Combo Box return Values

            CB_OKAY     EQU  0
            CB_ERR         EQU -1
            CB_ERRSPACE    EQU -2

            ;// Combo Box Notification Codes (sent in WM_COMMAND)

            CBN_ERRSPACE        EQU (-1)
            CBN_SELCHANGE       EQU 1
            CBN_DBLCLK          EQU 2
            CBN_SETFOCUS        EQU 3
            CBN_KILLFOCUS       EQU 4
            CBN_EDITCHANGE      EQU 5
            CBN_EDITUPDATE      EQU 6
            CBN_DROPDOWN        EQU 7
            CBN_CLOSEUP         EQU 8
            CBN_SELENDOK        EQU 9
            CBN_SELENDCANCEL    EQU 10

            ;// Combo Box styles

            CBS_SIMPLE            EQU 0001h
            CBS_DROPDOWN          EQU 0002h
            CBS_DROPDOWNLIST      EQU 0003h
            CBS_OWNERDRAWFIXED    EQU 0010h
            CBS_OWNERDRAWVARIABLE EQU 0020h
            CBS_AUTOHSCROLL       EQU 0040h
            CBS_OEMCONVERT        EQU 0080h
            CBS_SORT              EQU 0100h
            CBS_HASSTRINGS        EQU 0200h
            CBS_NOINTEGRALHEIGHT  EQU 0400h
            CBS_DISABLENOSCROLL   EQU 0800h
            CBS_UPPERCASE         EQU 2000h
            CBS_LOWERCASE         EQU 4000h


    ;//
    ;// DESTRUCTION
    ;//

        WIN32API DestroyWindow, hWnd:DWORD



    ;//
    ;//  WINDOW BYTES, OWNERS, CHILDREN
    ;//
        WIN32API SetWindowLongA, hWnd:DWORD, dwIndex:DWORD, dwNewLong:DWORD
        ;// returns previous value, or zero
        ;// if previous value was already zero, well . . . you figure it out

        WIN32API GetWindowLongA, hWnd:DWORD, dwIndex:DWORD
        ;// returns value in eax

        ;// Window field offsets for Get/SetWindowLong()    winuser.h
        GWL_WNDPROC    EQU     (-4)
        GWL_HINSTANCE  EQU     (-6)
        GWL_HWNDPARENT EQU     (-8)
        GWL_ID         EQU     (-12)
        GWL_STYLE      EQU     (-16)    ;// see WS_VISIBLE ...
        GWL_EXSTYLE    EQU     (-20)
        GWL_USERDATA   EQU     (-21)


        WIN32API GetParent, hWnd:DWORD
        ;// returns hWnd or NULL for error

        WIN32API SetParent, hWndChild:DWORD, hWndParent:DWORD
        ;// returns hWnd or NULL for error

        WIN32API GetWindow, hWnd:DWORD, dwCmd:DWORD
        ;// returns null for error of the desired handle

            ;// GetWindow() Constants

            GW_HWNDFIRST   EQU     0
            GW_HWNDLAST    EQU     1
            GW_HWNDNEXT    EQU     2
            GW_HWNDPREV    EQU     3
            GW_OWNER       EQU     4
            GW_CHILD       EQU     5
            GW_MAX         EQU     5

        WIN32API GetForegroundWindow
        ;// returns hWnd

        WIN32API GetActiveWindow
        ;// returns hWnd


        WIN32API EnumChildWindows, hWnd:DWORD, pEnumChildProc:DWORD, param:DWORD


        ;// returns non zero for success

        WIN32API EnumChildProc, hWnd:DWORD, param:DWORD
        ;// this is a placeholder to be defined by the application
        ;// return non-zero to continue


        WIN32API GetDlgItem, hWnd:DWORD, dwID:DWORD
        ;// returns hWnd of control item with said ID

        WIN32API GetDlgCtrlID, hWnd:DWORD
        ;// return ID of window, or zero for error

        WIN32API IsChild, hWndParent:DWORD, hWndTest:DWORD
        ;// returns non zero if true


    ;//
    ;// M E S S A G E S
    ;//


        WIN32API DefWindowProcA, hWnd:DWORD, msg:DWORD, wParam:DWORD, lParam:DWORD

        ;// returns LRESULT

        WIN32API CallWindowProcA, pPrevWndFunc:DWORD, hWnd:DWORD, msg:DWORD, wParam:DWORD, lParam:DWORD
        ;// returns what the window proceedure returns



        tagMSG STRUCT
            hWnd    dd ?
            message dd ?
            wParam  dd ?
            lParam  dd ?
            time    dd ?
            pt      POINT { }
        tagMSG ENDS


        WIN32API PeekMessageA, pMsg:DWORD, hWnd:DWORD, wMsgFilterMin:DWORD, wMsgFilterMax:DWORD, wRemoveMsg:DWORD
        ;//return TRUE if a message was found

        PM_NOREMOVE         EQU 0000
        PM_REMOVE           EQU 0001
        PM_NOYIELD          EQU 0002

        WIN32API GetInputState
        ;// returns non zero if mouse or keyboard messages are waiting


        WIN32API WaitMessage

        WIN32API GetMessageA, pMsg:ptr, hWnd:DWORD, wMsgFilterMin:DWORD, wMsgFilterMax:DWORD
        ;// returns TRUE FALSE or -1 for error ( careful !! )

        WIN32API TranslateMessage, pMsg:PTR
        ;// returns TRUE or FALSE

        WIN32API DispatchMessageA, pMsg:PTR
        ;// returns what the wndProc returns


        WIN32API PostMessageA, hWnd:DWORD, msg:DWORD, wParam:DWORD, lParam:DWORD
        ;// return non zero for sucess

        WIN32API SendMessageA, hWnd:DWORD, msg:DWORD, wParam:DWORD, lParam:DWORD
        ;// return what the message handler returns







        ;//             many of these will have sub lists
        ;// MESSAGES    with the values of various flags
        ;//             see message_macros for helpful stuff
        ;//
        WM_NULL                         EQU 0000h
        WM_CREATE                       EQU 0001h

            CREATESTRUCT STRUCT

                pCreateParams   dd  0   ;
                hInstance       dd  0   ;
                hMenu           dd  0   ;
                hwndParent      dd  0   ;
                dw_cy           dd  0   ;
                dw_cx           dd  0   ;
                dw_y            dd  0   ;
                dw_x            dd  0   ;
                dwStyle         dd  0   ;
                pszName         dd  0   ;
                pszClass        dd  0   ;
                dwExStyle       dd  0   ;

            CREATESTRUCT ENDS

        WM_DESTROY                      EQU 0002h
        WM_MOVE                         EQU 0003h
        WM_SIZE                         EQU 0005h

            SIZE_RESTORED   EQU 0
            SIZE_MINIMIZED  EQU 1
            SIZE_MAXIMIZED  EQU 2
            SIZE_MAXSHOW    EQU 3
            SIZE_MAXHIDE    EQU 4

        WM_ACTIVATE                     EQU 0006h
            WA_INACTIVE     EQU 0   ;// loword(wParam)
            WA_ACTIVE       EQU 1
            WA_CLICKACTIVE  EQU 2

        WM_SETFOCUS                     EQU 0007h
        WM_KILLFOCUS                    EQU 0008h
        WM_ENABLE                       EQU 000Ah
        WM_SETREDRAW                    EQU 000Bh
        WM_SETTEXT                      EQU 000Ch
        WM_GETTEXT                      EQU 000Dh
        WM_GETTEXTLENGTH                EQU 000Eh
        WM_PAINT                        EQU 000Fh
        WM_CLOSE                        EQU 0010h
        WM_QUERYENDSESSION              EQU 0011h
        WM_QUIT                         EQU 0012h
        WM_QUERYOPEN                    EQU 0013h
        WM_ERASEBKGND                   EQU 0014h
        WM_SYSCOLORCHANGE               EQU 0015h
        WM_ENDSESSION                   EQU 0016h
        WM_SHOWWINDOW                   EQU 0018h
        WM_WININICHANGE                 EQU 001Ah
        WM_DEVMODECHANGE                EQU 001Bh
        WM_ACTIVATEAPP                  EQU 001Ch
        WM_FONTCHANGE                   EQU 001Dh
        WM_TIMECHANGE                   EQU 001Eh
        WM_CANCELMODE                   EQU 001Fh
        WM_SETCURSOR                    EQU 0020h
        WM_MOUSEACTIVATE                EQU 0021h

            MA_ACTIVATE         EQU 1
            MA_ACTIVATEANDEAT   EQU 2
            MA_NOACTIVATE       EQU 3
            MA_NOACTIVATEANDEAT EQU 4

        WM_CHILDACTIVATE                EQU 0022h
        WM_QUEUESYNC                    EQU 0023h
        WM_GETMINMAXINFO                EQU 0024h

            ;// lParam
            MINMAXINFO STRUCT

                ptReserved      POINT {}
                ptMaxSize       POINT {}
                ptMaxPosition   POINT {}
                ptMinTrackSize  POINT {}
                ptMaxTrackSize  POINT {}

            MINMAXINFO ENDS

        WM_PAINTICON                    EQU 0026h
        WM_ICONERASEBKGND               EQU 0027h
        WM_NEXTDLGCTL                   EQU 0028h
        WM_SPOOLERSTATUS                EQU 002Ah
        WM_DRAWITEM                     EQU 002Bh

            ;// lPramam

            DRAWITEMSTRUCT STRUCT
                dwCtlType       dd  0
                dwCtlID         dd  0
                dwItemID        dd  0
                dwItemAction    dd  0
                dwItemState     dd  0
                hWndItem        dd  0
                hDC             dd  0
                rcItem          RECT {}
                dwItemData      dd  0
            DRAWITEMSTRUCT  ENDS

            ;// OWNER DRAW TYPES

            ODT_MENU        EQU 1
            ODT_LISTBOX     EQU 2
            ODT_COMBOBOX    EQU 3
            ODT_BUTTON      EQU 4
            ODT_STATIC      EQU 5


            ;// Owner draw actions

            ODA_DRAWENTIRE  EQU 0001h   ;// draw the text ?
            ODA_SELECT      EQU 0002h   ;// check the select status and draw according ly
            ODA_FOCUS       EQU 0004h   ;// check the focus status and draw accodingly

            ;// Owner draw state

            ODS_SELECTED    EQU 0001h
            ODS_GRAYED      EQU 0002h
            ODS_DISABLED    EQU 0004h
            ODS_CHECKED     EQU 0008h
            ODS_FOCUS       EQU 0010h
            ODS_DEFAULT     EQU 0020h
            ODS_COMBOBOXEDIT EQU 1000h

        WM_MEASUREITEM                  EQU 002Ch

            MEASUREITEMSTRUCT   STRUCT
                CtlType     dd  0   ;// type of control
                CtlID       dd  0   ;// combo box, list box, or button identifier
                itemID      dd  0   ;// menu item, variable-height list box, or combo box identifier
                itemWidth   dd  0   ;// width of menu item, in pixels
                itemHeight  dd  0   ;// height of single item in list box menu, in pixels
                itemData    dd  0   ;// application-defined 32-bit value
            MEASUREITEMSTRUCT   ENDS

        WM_DELETEITEM                   EQU 002Dh
        WM_VKEYTOITEM                   EQU 002Eh
        WM_CHARTOITEM                   EQU 002Fh

        WM_SETFONT                      EQU 0030h
        WM_GETFONT                      EQU 0031h
        WM_SETHOTKEY                    EQU 0032h
        WM_GETHOTKEY                    EQU 0033h
        WM_QUERYDRAGICON                EQU 0037h
        WM_COMPAREITEM                  EQU 0039h

            COMPAREITEMSTRUCT   STRUCT
                CtlType     dd  0
                CtlID       dd  0
                hWndItem    dd  0
                itemID1     dd  0
                itemData1   dd  0
                itemID2     dd  0
                itemData2   dd  0
            COMPAREITEMSTRUCT   ENDS

        WM_COMPACTING                   EQU 0041h
        WM_WINDOWPOSCHANGING            EQU 0046h
        WM_WINDOWPOSCHANGED             EQU 0047h
        WM_POWER                        EQU 0048h
        WM_COPYDATA                     EQU 004Ah
        WM_CANCELJOURNAL                EQU 004Bh
        WM_NOTIFY                       EQU 004Eh

            ;// lParam points to this

            NMHDR STRUCT
                hWndFrom dd 0
                idFrom dd 0
                dwCode dd 0
            NMHDR ENDS

            ;//====== Generic WM_NOTIFY notification codes ===winuser.h====================

            NM_OUTOFMEMORY         EQU NM_FIRST-1
            NM_CLICK               EQU NM_FIRST-2
            NM_DBLCLK              EQU NM_FIRST-3
            NM_RETURN              EQU NM_FIRST-4
            NM_RCLICK              EQU NM_FIRST-5
            NM_RDBLCLK             EQU NM_FIRST-6
            NM_SETFOCUS            EQU NM_FIRST-7
            NM_KILLFOCUS           EQU NM_FIRST-8
            NM_CUSTOMDRAW          EQU NM_FIRST-12
            NM_HOVER               EQU NM_FIRST-13

            ;//====== WM_NOTIFY codes NMHDR.code values ==================================

            NM_FIRST                EQU 0         ;// generic to all controls
            NM_LAST                 EQU -99
            LVN_FIRST               EQU -100       ;// listview
            LVN_LAST                EQU -199
            HDN_FIRST               EQU -300       ;// header
            HDN_LAST                EQU -399
            TVN_FIRST               EQU -400       ;// treeview
            TVN_LAST                EQU -499
            TTN_FIRST               EQU -520       ;// tooltips
            TTN_LAST                EQU -549
            TCN_FIRST               EQU -550       ;// tab control
            TCN_LAST                EQU -580

            ;// Shell reserved               EQU -58 EQU -  EQU -589

            CDN_FIRST               EQU -601       ;// common dialog new
            CDN_LAST                EQU -699
            TBN_FIRST               EQU -700       ;// toolbar
            TBN_LAST                EQU -720
            UDN_FIRST               EQU -721      ;// updown
            UDN_LAST                EQU -740
            MCN_FIRST               EQU -750       ;// monthcal
            MCN_LAST                EQU -759
            DTN_FIRST               EQU -760       ;// datetimepick
            DTN_LAST                EQU -799
            CBEN_FIRST              EQU -800       ;// combo box ex
            CBEN_LAST               EQU -830
            RBN_FIRST               EQU -831       ;// rebar
            RBN_LAST                EQU -859

        WM_INPUTLANGCHANGEREQUEST       EQU 0050h
        WM_INPUTLANGCHANGE              EQU 0051h
        WM_TCARD                        EQU 0052h
        WM_HELP                         EQU 0053h
        WM_USERCHANGED                  EQU 0054h
        WM_NOTIFYFORMAT                 EQU 0055h
        WM_CONTEXTMENU                  EQU 007Bh
        WM_STYLECHANGING                EQU 007Ch
        WM_STYLECHANGED                 EQU 007Dh
        WM_DISPLAYCHANGE                EQU 007Eh
        WM_GETICON                      EQU 007Fh
        WM_SETICON                      EQU 0080h
        WM_NCCREATE                     EQU 0081h
        WM_NCDESTROY                    EQU 0082h
        WM_NCCALCSIZE                   EQU 0083h

            WINDOWPOS STRUCT

                hwnd            dd  0   ;
                hwndInsertAfter dd  0   ;
                pos POINT {}
                siz POINT {}
                dwFlags         dd  0   ;// uses SWP_DRAWFRAME flags

            WINDOWPOS ENDS

            ;// lPram may point at one of these
            NCCALCSIZE_PARAMS STRUCT

                new_window RECT {} ;//
                old_window RECT {} ;//
                old_client RECT {} ;//
                pWindPos   dd 0 ;// PTR WINDOWPOS   ;// points at WNDPOS STRUCT

            NCCALCSIZE_PARAMS ENDS

            ;// return values
            WVR_ALIGNTOP        EQU 0010h
            WVR_ALIGNLEFT       EQU 0020h
            WVR_ALIGNBOTTOM     EQU 0040h
            WVR_ALIGNRIGHT      EQU 0080h
            WVR_HREDRAW         EQU 0100h
            WVR_VREDRAW         EQU 0200h
            WVR_REDRAW          EQU WVR_HREDRAW OR WVR_VREDRAW
            WVR_VALIDRECTS      EQU 0400h


        WM_NCHITTEST                    EQU 0084h

            ;// WM_NCHITTEST and MOUSEHOOKSTRUCT Mouse Position Codes

            HTERROR        EQU  (-2)
            HTTRANSPARENT  EQU     (-1)
            HTNOWHERE      EQU     0
            HTCLIENT       EQU     1
            HTCAPTION      EQU     2
            HTSYSMENU      EQU     3
            HTSIZE         EQU     4
            HTMENU         EQU     5
            HTHSCROLL      EQU     6
            HTVSCROLL      EQU     7
            HTMINBUTTON    EQU     8
            HTMAXBUTTON    EQU     9
            HTLEFT         EQU     10
            HTRIGHT        EQU     11
            HTTOP          EQU     12
            HTTOPLEFT      EQU     13
            HTTOPRIGHT     EQU     14
            HTBOTTOM       EQU     15
            HTBOTTOMLEFT   EQU     16
            HTBOTTOMRIGHT  EQU     17
            HTBORDER       EQU     18
            HTOBJECT       EQU     19
            HTCLOSE        EQU     20
            HTHELP         EQU     21

        WM_NCPAINT                      EQU 0085h
        WM_NCACTIVATE                   EQU 0086h
        WM_GETDLGCODE                   EQU 0087h
        WM_NCMOUSEMOVE                  EQU 00A0h
        WM_NCLBUTTONDOWN                EQU 00A1h
        WM_NCLBUTTONUP                  EQU 00A2h
        WM_NCLBUTTONDBLCLK              EQU 00A3h
        WM_NCRBUTTONDOWN                EQU 00A4h
        WM_NCRBUTTONUP                  EQU 00A5h
        WM_NCRBUTTONDBLCLK              EQU 00A6h
        WM_NCMBUTTONDOWN                EQU 00A7h
        WM_NCMBUTTONUP                  EQU 00A8h
        WM_NCMBUTTONDBLCLK              EQU 00A9h

        SBM_SETPOS                      EQU 00E0h
        SBM_GETPOS                      EQU 00E1h
        SBM_SETRANGE                    EQU 00E2h
        SBM_SETRANGEREDRAW              EQU 00E6h
        SBM_GETRANGE                    EQU 00E3h
        SBM_ENABLE_ARROWS               EQU 00E4h
        SBM_SETSCROLLINFO               EQU 00E9h
        SBM_GETSCROLLINFO               EQU 00EAh


        WM_KEYFIRST                     EQU 0100h
        WM_KEYDOWN                      EQU 0100h
        WM_KEYUP                        EQU 0101h
        WM_CHAR                         EQU 0102h
        WM_DEADCHAR                     EQU 0103h
        WM_SYSKEYDOWN                   EQU 0104h
        WM_SYSKEYUP                     EQU 0105h
        WM_SYSCHAR                      EQU 0106h
        WM_SYSDEADCHAR                  EQU 0107h
        WM_KEYLAST                      EQU 0108h

        WM_IME_STARTCOMPOSITION         EQU 010Dh
        WM_IME_ENDCOMPOSITION           EQU 010Eh
        WM_IME_COMPOSITION              EQU 010Fh
        WM_IME_KEYLAST                  EQU 010Fh

        WM_INITDIALOG                   EQU 0110h

        WM_COMMAND                      EQU 0111h
            ;// hiWord wParam notify codes

            ;// button command codes

            BN_CLICKED  EQU 0

            ;// Listbox command Codes

            LBN_ERRSPACE   EQU (-2)
            LBN_SELCHANGE  EQU 1
            LBN_DBLCLK     EQU 2
            LBN_SELCANCEL  EQU 3
            LBN_SETFOCUS   EQU 4
            LBN_KILLFOCUS  EQU 5

        WM_SYSCOMMAND                   EQU 0112h

            ;// System Menu Command Values

            SC_SIZE         EQU 0F000h
            SC_MOVE         EQU 0F010h
            SC_MINIMIZE     EQU 0F020h
            SC_MAXIMIZE     EQU 0F030h
            SC_NEXTWINDOW   EQU 0F040h
            SC_PREVWINDOW   EQU 0F050h
            SC_CLOSE        EQU 0F060h
            SC_VSCROLL      EQU 0F070h
            SC_HSCROLL      EQU 0F080h
            SC_MOUSEMENU    EQU 0F090h
            SC_KEYMENU      EQU 0F100h
            SC_ARRANGE      EQU 0F110h
            SC_RESTORE      EQU 0F120h
            SC_TASKLIST     EQU 0F130h
            SC_SCREENSAVE   EQU 0F140h
            SC_HOTKEY       EQU 0F150h
            SC_DEFAULT      EQU 0F160h
            SC_MONITORPOWER EQU 0F170h
            SC_CONTEXTHELP  EQU 0F180h
            SC_SEPARATOR    EQU 0F00Fh

        WM_TIMER                        EQU 0113h

        WM_HSCROLL                      EQU 0114h
        WM_VSCROLL                      EQU 0115h
            ;// loWord of wParam specifies code
            SB_LINEUP          EQU 0
            SB_LINELEFT        EQU 0
            SB_LINEDOWN        EQU 1
            SB_LINERIGHT       EQU 1
            SB_PAGEUP          EQU 2
            SB_PAGELEFT        EQU 2
            SB_PAGEDOWN        EQU 3
            SB_PAGERIGHT       EQU 3
            SB_THUMBPOSITION   EQU 4
            SB_THUMBTRACK      EQU 5
            SB_TOP             EQU 6
            SB_LEFT            EQU 6
            SB_BOTTOM          EQU 7
            SB_RIGHT           EQU 7
            SB_ENDSCROLL       EQU 8


        WM_INITMENU                     EQU 0116h
        WM_INITMENUPOPUP                EQU 0117h
        WM_MENUSELECT                   EQU 011Fh
        WM_MENUCHAR                     EQU 0120h

            ;// return one these in the high word of eax
            MNC_IGNORE  EQU 00000h
            MNC_CLOSE   EQU 10000h
            MNC_EXECUTE EQU 20000h
            MNC_SELECT  EQU 30000h


        WM_ENTERIDLE                    EQU 0121h

            MSGF_DIALOGBOX  EQU 0
            MSGF_MENU       EQU 2

        WM_CTLCOLORMSGBOX               EQU 0132h
        WM_CTLCOLOREDIT                 EQU 0133h
        WM_CTLCOLORLISTBOX              EQU 0134h
        WM_CTLCOLORBTN                  EQU 0135h
        WM_CTLCOLORDLG                  EQU 0136h
        WM_CTLCOLORSCROLLBAR            EQU 0137h
        WM_CTLCOLORSTATIC               EQU 0138h

        ;// Combo Box messages

        CB_GETEDITSEL               EQU 0140h
        CB_LIMITTEXT                EQU 0141h
        CB_SETEDITSEL               EQU 0142h
        CB_ADDSTRING                EQU 0143h
        CB_DELETESTRING             EQU 0144h
        CB_DIR                      EQU 0145h
        CB_GETCOUNT                 EQU 0146h
        CB_GETCURSEL                EQU 0147h
        CB_GETLBTEXT                EQU 0148h
        CB_GETLBTEXTLEN             EQU 0149h
        CB_INSERTSTRING             EQU 014Ah
        CB_RESETCONTENT             EQU 014Bh
        CB_FINDSTRING               EQU 014Ch
        CB_SELECTSTRING             EQU 014Dh
        CB_SETCURSEL                EQU 014Eh
        CB_SHOWDROPDOWN             EQU 014Fh
        CB_GETITEMDATA              EQU 0150h
        CB_SETITEMDATA              EQU 0151h
        CB_GETDROPPEDCONTROLRECT    EQU 0152h
        CB_SETITEMHEIGHT            EQU 0153h
        CB_GETITEMHEIGHT            EQU 0154h
        CB_SETEXTENDEDUI            EQU 0155h
        CB_GETEXTENDEDUI            EQU 0156h
        CB_GETDROPPEDSTATE          EQU 0157h
        CB_FINDSTRINGEXACT          EQU 0158h
        CB_SETLOCALE                EQU 0159h
        CB_GETLOCALE                EQU 015Ah
        CB_GETTOPINDEX              EQU 015bh
        CB_SETTOPINDEX              EQU 015ch
        CB_GETHORIZONTALEXTENT      EQU 015dh
        CB_SETHORIZONTALEXTENT      EQU 015eh
        CB_GETDROPPEDWIDTH          EQU 015fh
        CB_SETDROPPEDWIDTH          EQU 0160h
        CB_INITSTORAGE              EQU 0161h

        ;// Listbox messages

        LB_ADDSTRING                    EQU 0180h
        LB_INSERTSTRING                 EQU 0181h
        LB_DELETESTRING                 EQU 0182h
        LB_SELITEMRANGEEX               EQU 0183h
        LB_RESETCONTENT                 EQU 0184h
        LB_SETSEL                       EQU 0185h
        LB_SETCURSEL                    EQU 0186h
        LB_GETSEL                       EQU 0187h
        LB_GETCURSEL                    EQU 0188h
        LB_GETTEXT                      EQU 0189h
        LB_GETTEXTLEN                   EQU 018Ah
        LB_GETCOUNT                     EQU 018Bh
        LB_SELECTSTRING                 EQU 018Ch
        LB_DIR                          EQU 018Dh
        LB_GETTOPINDEX                  EQU 018Eh
        LB_FINDSTRING                   EQU 018Fh
        LB_GETSELCOUNT                  EQU 0190h
        LB_GETSELITEMS                  EQU 0191h
        LB_SETTABSTOPS                  EQU 0192h
        LB_GETHORIZONTALEXTENT          EQU 0193h
        LB_SETHORIZONTALEXTENT          EQU 0194h
        LB_SETCOLUMNWIDTH               EQU 0195h
        LB_ADDFILE                      EQU 0196h
        LB_SETTOPINDEX                  EQU 0197h
        LB_GETITEMRECT                  EQU 0198h
        LB_GETITEMDATA                  EQU 0199h
        LB_SETITEMDATA                  EQU 019Ah
        LB_SELITEMRANGE                 EQU 019Bh
        LB_SETANCHORINDEX               EQU 019Ch
        LB_GETANCHORINDEX               EQU 019Dh
        LB_SETCARETINDEX                EQU 019Eh
        LB_GETCARETINDEX                EQU 019Fh
        LB_SETITEMHEIGHT                EQU 01A0h
        LB_GETITEMHEIGHT                EQU 01A1h
        LB_FINDSTRINGEXACT              EQU 01A2h
        LB_SETLOCALE                    EQU 01A5h
        LB_GETLOCALE                    EQU 01A6h
        LB_SETCOUNT                     EQU 01A7h
        LB_INITSTORAGE                  EQU 01A8h
        LB_ITEMFROMPOINT                EQU 01A9h

            ;// list box return values
            LB_ERR                      EQU 0FFFFFFFFh



        ;// mouse messages

        WM_MOUSEFIRST                   EQU 0200h

        WM_MOUSEMOVE                    EQU 0200h
        WM_LBUTTONDOWN                  EQU 0201h
        WM_LBUTTONUP                    EQU 0202h
        WM_LBUTTONDBLCLK                EQU 0203h
        WM_RBUTTONDOWN                  EQU 0204h
        WM_RBUTTONUP                    EQU 0205h
        WM_RBUTTONDBLCLK                EQU 0206h
        WM_MBUTTONDOWN                  EQU 0207h
        WM_MBUTTONUP                    EQU 0208h
        WM_MBUTTONDBLCLK                EQU 0209h
        WM_MOUSEWHEEL                   EQU 020Ah

        WM_MOUSELAST                    EQU WM_MOUSEWHEEL

            ;// wParam's for mouse messages
            ;// Key State Masks for Mouse Messages
            MK_LBUTTON   EQU 0001h
            MK_RBUTTON   EQU 0002h
            MK_SHIFT     EQU 0004h
            MK_CONTROL   EQU 0008h
            MK_MBUTTON   EQU 0010h
            MK_ALT       EQU 0020h


        WM_PARENTNOTIFY                 EQU 0210h
        WM_ENTERMENULOOP                EQU 0211h
        WM_EXITMENULOOP                 EQU 0212h
        WM_NEXTMENU                     EQU 0213h
        WM_SIZING                       EQU 0214h

            WMSZ_LEFT          EQU  1   ;// Left edge
            WMSZ_RIGHT         EQU  2   ;// Right edge
            WMSZ_TOP           EQU  3   ;// Top edge
            WMSZ_TOPLEFT       EQU  4   ;// Top-left corner
            WMSZ_TOPRIGHT      EQU  5   ;// Top-right corner
            WMSZ_BOTTOM        EQU  6   ;// Bottom edge
            WMSZ_BOTTOMLEFT    EQU  7   ;// Bottom-left corner
            WMSZ_BOTTOMRIGHT   EQU  8   ;// Bottom-right corner

        WM_CAPTURECHANGED               EQU 0215h
        WM_MOVING                       EQU 0216h
        WM_POWERBROADCAST               EQU 0218h
        WM_DEVICECHANGE                 EQU 0219h

        WM_MDICREATE                    EQU 0220h
        WM_MDIDESTROY                   EQU 0221h
        WM_MDIACTIVATE                  EQU 0222h
        WM_MDIRESTORE                   EQU 0223h
        WM_MDINEXT                      EQU 0224h
        WM_MDIMAXIMIZE                  EQU 0225h
        WM_MDITILE                      EQU 0226h
        WM_MDICASCADE                   EQU 0227h
        WM_MDIICONARRANGE               EQU 0228h
        WM_MDIGETACTIVE                 EQU 0229h
        WM_MDISETMENU                   EQU 0230h
        WM_ENTERSIZEMOVE                EQU 0231h
        WM_EXITSIZEMOVE                 EQU 0232h
        WM_DROPFILES                    EQU 0233h
        WM_MDIREFRESHMENU               EQU 0234h

        WM_IME_SETCONTEXT               EQU 0281h
        WM_IME_NOTIFY                   EQU 0282h
        WM_IME_CONTROL                  EQU 0283h
        WM_IME_COMPOSITIONFULL          EQU 0284h
        WM_IME_SELECT                   EQU 0285h
        WM_IME_CHAR                     EQU 0286h
        WM_IME_KEYDOWN                  EQU 0290h
        WM_IME_KEYUP                    EQU 0291h

        WM_MOUSEHOVER                   EQU 02A1h
        WM_MOUSELEAVE                   EQU 02A3h
        WM_CUT                          EQU 0300h
        WM_COPY                         EQU 0301h
        WM_PASTE                        EQU 0302h
        WM_CLEAR                        EQU 0303h
        WM_UNDO                         EQU 0304h
        WM_RENDERFORMAT                 EQU 0305h
        WM_RENDERALLFORMATS             EQU 0306h
        WM_DESTROYCLIPBOARD             EQU 0307h
        WM_DRAWCLIPBOARD                EQU 0308h
        WM_PAINTCLIPBOARD               EQU 0309h
        WM_VSCROLLCLIPBOARD             EQU 030Ah
        WM_SIZECLIPBOARD                EQU 030Bh
        WM_ASKCBFORMATNAME              EQU 030Ch
        WM_CHANGECBCHAIN                EQU 030Dh
        WM_HSCROLLCLIPBOARD             EQU 030Eh
        WM_QUERYNEWPALETTE              EQU 030Fh
        WM_PALETTEISCHANGING            EQU 0310h
        WM_PALETTECHANGED               EQU 0311h
        WM_HOTKEY                       EQU 0312h
        WM_PRINT                        EQU 0317h
        WM_PRINTCLIENT                  EQU 0318h
        WM_HANDHELDFIRST                EQU 0358h
        WM_HANDHELDLAST                 EQU 035Fh
        WM_AFXFIRST                     EQU 0360h
        WM_AFXLAST                      EQU 037Fh
        WM_PENWINFIRST                  EQU 0380h
        WM_PENWINLAST                   EQU 038Fh
        WM_USER                         EQU 0400h
        WM_APP                          EQU 8000h


        WIN32API PostQuitMessage, nExitCode:DWORD
        ;// returns nothing



    ;//
    ;// KEYBOARD
    ;//

        WIN32API SetFocus, hWnd:DWORD
        ;// returns the previous hWnd with the focus

        WIN32API GetFocus
        ;// returns the hWnd with the focus

        WIN32API GetAsyncKeyState, virtKey:DWORD
        ;// return ax=key state

        WIN32API GetKeyState, virtKey:DWORD
        ;// return ax=key state

        WIN32API GetKeyboardState, pKeyState:DWORD
        ;// returns zero for error

        WIN32API VkKeyScanA, character:DWORD

        WIN32API ShowCaret, hWnd:DWORD
        ;// returns zero for error

        WIN32API DestroyCaret
        ;// returns zero for error

        WIN32API HideCaret, hWnd:DWORD
        ;// returns zero for error



    ;//
    ;//  MOUSE
    ;//

        WIN32API GetCapture
        ;// return hWnd of window with the mouse capture

        WIN32API SetCapture, hWnd:DWORD
        ;// return previous capture window or NULL for no other window

        WIN32API ReleaseCapture
        ;// returns non-zero for sucess

        WIN32API GetDoubleClickTime
        ;// returns number of milliseconds


    ;//
    ;// W I N D O W    S I Z E  A N D   P L A C E M E  N T
    ;//
        WIN32API GetClientRect, hWnd:DWORD, pRect:DWORD
        ;// returns TRUE if successful

        WIN32API GetWindowRect, hWnd:DWORD, pRect:DWORD
        ;// return zero for error

        WIN32API AdjustWindowRectEx, pRect:DWORD, dwStyle:DWORD, bMenu:DWORD, dwExStyle:DWORD
        ;// returns non_zero for sucess

        WIN32API MoveWindow, hWnd:DWORD, X:DWORD, Y:DWORD, wid:DWORD, hig:DWORD, bRepaint:DWORD
        ;// returns non zero for sucess

        WIN32API SetWindowPos, hWnd:DWORD, hWndAfter:DWORD, X:DWORD, Y:DWORD, wid:DWORD, hig:DWORD, dwFlags:DWORD
        ;// returns non zero for sucess

            ;// flags for set window pos

            SWP_NOSIZE          EQU 0001h
            SWP_NOMOVE          EQU 0002h
            SWP_NOZORDER        EQU 0004h
            SWP_NOREDRAW        EQU 0008h
            SWP_NOACTIVATE      EQU 0010h
            SWP_FRAMECHANGED    EQU 0020h
            SWP_SHOWWINDOW      EQU 0040h
            SWP_HIDEWINDOW      EQU 0080h
            SWP_NOCOPYBITS      EQU 0100h
            SWP_NOOWNERZORDER   EQU 0200h
            SWP_NOSENDCHANGING  EQU 0400h

            SWP_DRAWFRAME       EQU SWP_FRAMECHANGED
            SWP_NOREPOSITION    EQU SWP_NOOWNERZORDER

            SWP_DEFERERASE      EQU 2000h
            SWP_ASYNCWINDOWPOS  EQU 4000h

            HWND_TOP        EQU 0
            HWND_BOTTOM     EQU 1
            HWND_TOPMOST    EQU -1
            HWND_NOTOPMOST  EQU -2

        WIN32API ShowWindow, hWnd:DWORD, dwFlags:DWORD
        ;// returns previous visible state

            ;// flags for show window
            SW_HIDE             EQU 0
            SW_SHOWNORMAL       EQU 1
            SW_NORMAL           EQU 1
            SW_SHOWMINIMIZED    EQU 2
            SW_SHOWMAXIMIZED    EQU 3
            SW_MAXIMIZE         EQU 3
            SW_SHOWNOACTIVATE   EQU 4
            SW_SHOW             EQU 5
            SW_MINIMIZE         EQU 6
            SW_SHOWMINNOACTIVE  EQU 7
            SW_SHOWNA           EQU 8
            SW_RESTORE          EQU 9
            SW_SHOWDEFAULT      EQU 10

        WIN32API IsWindowVisible, hWnd:DWORD
        ;// return non zero for yes

        WIN32API IsWindowEnabled, hWnd:DWORD
        ;// return non zero for yes

        WIN32API RedrawWindow, hWnd:DWORD, pRect:DWORD, pRgn:DWORD, dwFlags:DWORD
        ;// returns zero for error

            ;// values for flags
            RDW_INVALIDATE          EQU 0001h
            RDW_INTERNALPAINT       EQU 0002h
            RDW_ERASE               EQU 0004h

            RDW_VALIDATE            EQU 0008h
            RDW_NOINTERNALPAINT     EQU 0010h
            RDW_NOERASE             EQU 0020h

            RDW_NOCHILDREN          EQU 0040h
            RDW_ALLCHILDREN         EQU 0080h

            RDW_UPDATENOW           EQU 0100h
            RDW_ERASENOW            EQU 0200h

            RDW_FRAME               EQU 0400h
            RDW_NOFRAME             EQU 0800h

        WIN32API GetWindowPlacement, hWnd:DWORD, pWndPlacement:DWORD
        ;// returns non zero for success

            WINDOWPLACEMENT STRUCT
                dwLength    dd  SIZEOF WINDOWPLACEMENT
                dwFlags     dd  0
                dwShowCmd   dd  0
                minPosition POINT {}
                maxPosition POINT {}
                normalPosition  RECT {}
            WINDOWPLACEMENT ENDS

            ;// show command is the same as show window



    ;//
    ;//  OTHER
    ;//
        WIN32API EnableWindow, hWnd:DWORD, bEnable:DWORD
        ;// returns zero is window was not previously disabled

        WIN32API SetForegroundWindow, hWnd:DWORD
        ;// returns non zero for sucess

        WIN32API SetActiveWindow, hWnd:DWORD
        ;// return previously activated hWnd


        WIN32API ScrollWindowEx, hWnd:DWORD, dwDX:DWORD, dwDY:DWORD,    pScrollRect:DWORD, pClipRect:DWORD, hUpdateRegion:DWORD, pUpdateRect:DWORD, dwFlags:DWORD
        ;// return the type of region needed to update (SIMPLE, COMPLEX, etc)
        ;// or zero for ERROR

            ;// flags for dwFlags

            SW_SCROLLCHILDREN EQU 0001  ;// Scroll children within *lprcScroll.
            SW_INVALIDATE     EQU 0002  ;// Invalidate after scrolling
            SW_ERASE          EQU 0004  ;// If SW_INVALIDATE, don't send WM_ERASEBACKGROUND








    ;////////////////////////////////////////////////////////////////////
    ;////////////////////////////////////////////////////////////////////
    ;//
    ;////     R E S O U R C E S
    ;//

        WIN32API FindResourceA, hModule:DWORD, pszName:DWORD, pType:DWORD
        ;// returns hRsrc or null for error

            ;// Predefined Resource Types
            RT_CURSOR           EQU 0001
            RT_BITMAP           EQU 0002
            RT_ICON             EQU 0003
            RT_MENU             EQU 0004
            RT_DIALOG           EQU 0005
            RT_STRING           EQU 0006
            RT_FONTDIR          EQU 0007
            RT_FONT             EQU 0008
            RT_ACCELERATOR      EQU 0009
            RT_RCDATA           EQU 0010
            RT_MESSAGETABLE     EQU 0011
            RT_GROUP_CURSOR     EQU 0012
            RT_GROUP_ICON       EQU 0014
            RT_VERSION          EQU 0016
            RT_DLGINCLUDE       EQU 0017
            RT_PLUGPLAY         EQU 0019
            RT_VXD              EQU 0020
            RT_ANICURSOR        EQU 0021
            RT_ANIICON          EQU 0022
            ;// MFC defined
            RT_TOOLBAR          EQU 0241

        WIN32API LoadResource, hModule:DWORD, hRsrc:DWORD
        ;// returns hGlobal, use LockResource to get pointer
        ;// returns null for error

        WIN32API LockResource, hGlobal:DWORD
        ;// returns pMem to memory or null for error

        WIN32API SizeofResource, hModule:DWORD, hRsrc:DWORD


    ;//
    ;// ACCELERATORS
    ;//

        WIN32API LoadAcceleratorsA, hInstance:DWORD, pszName:DWORD
        ;// returns a handle to the accelerators, or 0 for error

        WIN32API TranslateAcceleratorA, hWnd:DWORD, hAccel:DWORD, pMsg:DWORD
        ;// returns non zero if this was an accelerator message

        WIN32API DestroyAcceleratorTable, hAccel:DWORD
        ;// returns non-zero for success


    ;//
    ;//  Cursors
    ;//



        WIN32API LoadCursorA, hInstance:DWORD, pCursorName:DWORD
        ;// pCursor name may be a resource ID
        ;//return hCursor

            ;// cursor types
            IDC_ARROW           EQU 32512
            IDC_IBEAM           EQU 32513
            IDC_WAIT            EQU 32514
            IDC_CROSS           EQU 32515
            IDC_UPARROW         EQU 32516
            IDC_SIZENWSE        EQU 32642
            IDC_SIZENESW        EQU 32643
            IDC_SIZEWE          EQU 32644
            IDC_SIZENS          EQU 32645
            IDC_SIZEALL         EQU 32646
            IDC_NO              EQU 32648
            IDC_APPSTARTING     EQU 32650
            IDC_HELP            EQU 32651

        WIN32API GetCursorPos, pPoint:DWORD
        ;// returns non zero for sucess

        WIN32API SetCursorPos, X:DWORD, Y:DWORD
        ;// returns non zero for sucess

        WIN32API SetCursor, hCursor:DWORD
        ;// return previous cursor, if there was one

        WIN32API ClipCursor, pRect:DWORD
        ;// return nonzero for success



    ;//
    ;//  ICONS
    ;//

        WIN32API LoadIconA, hInstance:DWORD, pIconName:DWORD
        ;// pIcon name may be a resource ID
        ;//returns hIcon


    ;//
    ;//  MENUS
    ;//

        WIN32API GetMenu, hWnd:DWORD
        ;// returns hMenu or NULL for error

        WIN32API GetSubMenu, hWnd:DWORD, dwPos:DWORD
        ;// return a submenu of zero for error

        WIN32API GetMenuState, hMenu:DWORD, dwPosID:DWORD, dwFlag:DWORD
        ;// returns item state or -1 for error

        WIN32API MenuItemFromPoint, hWnd:DWORD, hMenu:DWORD, X:DWORD, Y:DWORD
        ;// return ITEM POSITION or -1 for error

        WIN32API IsMenu, hMenu:DWORD
        ;// return non zero for yes


        WIN32API CheckMenuItem, hMenu:DWORD, dwPosID:DWORD, dwNewState:DWORD
        ;// returns previous state, or -1 for error

        WIN32API DrawMenuBar, hWnd:DWORD
        ;// returns non zero for sucess

        WIN32API EnableMenuItem, hMenu:DWORD, dwPosID:DWORD, dwNewState:DWORD
        ;// returns previous state, or -1 for error


            ;// Menu flags for Add/Check/EnableMenuItem()
            MF_BYCOMMAND        EQU 00000000h
            MF_BYPOSITION       EQU 00000400h

            MF_INSERT           EQU 00000000h
            MF_CHANGE           EQU 00000080h
            MF_APPEND           EQU 00000100h
            MF_DELETE           EQU 00000200h
            MF_REMOVE           EQU 00001000h

            MF_UNCHECKED        EQU 00000000h
            MF_CHECKED          EQU 00000008h
            MF_ENABLED          EQU 00000000h
            MF_GRAYED           EQU 00000001h
            MF_DISABLED         EQU 00000002h
            MF_SEPARATOR        EQU 00000800h

            MF_USECHECKBITMAPS  EQU 00000200h
            MF_STRING           EQU 00000000h
            MF_BITMAP           EQU 00000004h
            MF_OWNERDRAW        EQU 00000100h
            MF_POPUP            EQU 00000010h
            MF_MENUBARBREAK     EQU 00000020h
            MF_MENUBREAK        EQU 00000040h
            MF_UNHILITE         EQU 00000000h
            MF_HILITE           EQU 00000080h
            MF_DEFAULT          EQU 00001000h
            MF_SYSMENU          EQU 00002000h
            MF_HELP             EQU 00004000h
            MF_RIGHTJUSTIFY     EQU 00004000h
            MF_MOUSESELECT      EQU 00008000h
            MFT_RADIOCHECK      EQU 00000200h
            MFT_RIGHTORDER      EQU 00002000h
            MFS_GRAYED          EQU 00000003h


        WIN32API CreateMenu
        ;// returns hMenu (empty) or NULL for error

        WIN32API CreatePopupMenu
        ;// returns hMenu (empty) or NULL for error

        WIN32API LoadMenuA, hInstance:DWORD, pszName:DWORD
        ;// returns hMenu or NULL for error

        WIN32API SetMenu, hWnd:DWORD, hMenu:DWORD
        ;// returns non zero for success

        WIN32API DestroyMenu, hMenu:DWORD
        ;// returns non zero for sucess

        WIN32API TrackPopupMenu, hMenu:DWORD, dwFlags:DWORD,    x:DWORD, y:DWORD, reserved:DWORD, hWnd:DWORD, pRect:DWORD
        ;// returns non zero for sucess
        ;// if TPM_RETURNCMD is set, then return value is the command

            TPM_LEFTBUTTON  EQU 0000h
            TPM_RIGHTBUTTON EQU 0002h
            TPM_LEFTALIGN   EQU 0000h
            TPM_CENTERALIGN EQU 0004h
            TPM_RIGHTALIGN  EQU 0008h

            TPM_TOPALIGN        EQU 0000h
            TPM_VCENTERALIGN    EQU 0010h
            TPM_BOTTOMALIGN     EQU 0020h

            TPM_HORIZONTAL      EQU 0000h   ;// Horz alignment matters more
            TPM_VERTICAL        EQU 0040h   ;// Vert alignment matters more
            TPM_NONOTIFY        EQU 0080h   ;// Don't send any notification msgs
            TPM_RETURNCMD       EQU 0100h


        WIN32API SetMenuItemInfoA, hMenu:DWORD, dwItemID:DWORD, bByPosition:DWORD, pMenuItemInfo:DWORD
        ;// returns non-zero for sucess

        WIN32API GetMenuItemInfoA, hMenu:DWORD, dwItemID:DWORD, bByPosition:DWORD, pMenuItemInfo:DWORD
        ;// returns non-zero for sucess


        WIN32API HiliteMenuItem, hWnd:DWORD, hMenu:DWORD, dwItem:DWORD, dwFlags:DWORD
        ;// returns the new hilite state

        WIN32API InsertMenuItemA, hMenu:DWORD, dwItem:DWORD, bPosition:DWORD, pItemInfo:DWORD
        ;// returns non zero for sucess

        WIN32API AppendMenuA, hMenu:DWORD,uFlags:DWORD,uIDNewItem:DWORD,lpNewItem:DWORD
        ;// returns non zero for sucess
        ;// see MF_STRING for uFlags

        WIN32API DeleteMenu, hMenu:DWORD, dwPosition:DWORD, bByPosition:DWORD
        ;// returns non zero for sucess


            MENUITEMINFO STRUCT
                cbSize      dd SIZEOF MENUITEMINFO
                fMask       dd 0
                fType       dd 0    ;// use MF_ values above
                fState      dd 0
                dwID        dd 0
                hSubMenu    dd 0
                hbmpChecked dd 0
                hbmpUnchecked   dd 0
                dwItemData  dd 0
                dwTypeData  dd 0
                cch         dd 0
            MENUITEMINFO ENDS

            ;// values for mask
            MIIM_STATE       EQU 00000001h
            MIIM_ID          EQU 00000002h
            MIIM_SUBMENU     EQU 00000004h
            MIIM_CHECKMARKS  EQU 00000008h
            MIIM_TYPE        EQU 00000010h
            MIIM_DATA        EQU 00000020h


        WIN32API GetMenuItemRect, hWnd:DWORD, hMenu:DWORD, dwPostion:DWORD, pRect:DWORD
        ;// return non zero for sucess

        WIN32API GetMenuItemCount, hMeneu:DWORD
        ;// returns the number of items in the menu

        WIN32API GetMenuItemID, hMenu:DWORD, dwPosition:DWORD
        ;// return -1 for error


        WIN32API LoadMenuIndirect, pTemplateHeader:DWORD
        ;// returns hMenu or  0 for error


        ;// this is only good for single level menus

        MENUITEMTEMPLATEHEADER  STRUCT

            versionNumber   dw  0   ;// version number; must be zero
            ofs         dw  0   ;// offset first MENUITEMTEMPLATE structure

        MENUITEMTEMPLATEHEADER  ENDS

        MENUITEMTEMPLATE    STRUCT

            mtOption    dw  0   ;// menu item flags
            mtID        dw  0   ;// menu item identifier (omitted for pop-up items)
            mtString    dw  0   ;// null-terminated unicode string for menu item

        MENUITEMTEMPLATE    ENDS

        ;// use these for specifying full menus

        MENUEX_TEMPLATE_HEADER STRUCT
            wVersion    dd  1   ;// must be 1 for extended menu
            wOffset     dd  4   ;// should be 4 if packed correctly
            dwHelpId    dd  0   ;
        MENUEX_TEMPLATE_HEADER ENDS


        MENUEX_TEMPLATE_ITEM STRUCT
            dwType      dd  0   ;// use MF or MFT values
            dwState     dd  0   ;// use MFS values
            uId         dd  0   ;// limited to 16 bits
            bResInfo    dw  0   ;// use 80h for last in sub menu, use 1 for parent of sub menu
            szText      dw  0   ;// UNICODE string
            ;// dwHelpId;       used only for sub menu parents, must be dword aligned afeter text
        MENUEX_TEMPLATE_ITEM ENDS





    ;//
    ;// T O O L B A R S
    ;//
        ;//LockResource returns a pointer to this STRUCT
        TOOLBAR_RESOURCE STRUCT
            version  dw 0
            wid      dw 0
            hig      dw 0
            numItems dw 0
        TOOLBAR_RESOURCE ENDS
        ;// following this is an array of item ID's in WORD form


        WIN32API CreateToolbarEx, hWnd:DWORD,style:DWORD, ctrlID:DWORD, numBitmaps:DWORD,   hBMInst:DWORD, dwBMID:DWORD, pButtons:DWORD, numButtons:DWORD,  dxButton:DWORD, dyButton:DWORD, dxBitmap:DWORD, dyBitmap:DWORD, buttonStructSize:DWORD
        ;// returns an hWnd to the toolbar, or NULL for error

        TBBUTTON STRUCT
            indBitmap   dd 0
            idCommand   dd 0
            fsState     db 0
            fsStyle     db 0
            reserved    dw 0
            dwUser      dd 0
            indexString dd 0
        TBBUTTON ENDS

        ;// toolbar button states
        TBSTATE_CHECKED         EQU 01h
        TBSTATE_PRESSED         EQU 02h
        TBSTATE_ENABLED         EQU 04h
        TBSTATE_HIDDEN          EQU 08h
        TBSTATE_INDETERMINATE   EQU 10h
        TBSTATE_WRAP            EQU 20h
        TBSTATE_ELLIPSES        EQU 40h

        ;// toolbar button styles
        TBSTYLE_BUTTON          EQU 00h
        TBSTYLE_SEP             EQU 01h
        TBSTYLE_CHECK           EQU 02h
        TBSTYLE_GROUP           EQU 04h
        TBSTYLE_CHECKGROUP      EQU TBSTYLE_GROUP + TBSTYLE_CHECK
        TBSTYLE_DROPDOWN        EQU 08h

        ;// toolbar window styles
        TBSTYLE_TOOLTIPS      EQU 0100h
        TBSTYLE_WRAPABLE      EQU 0200h
        TBSTYLE_ALTDRAG       EQU 0400h
        TBSTYLE_FLAT          EQU 0800h
        TBSTYLE_LIST          EQU 1000h
        TBSTYLE_CUSTOMERASE   EQU 2000h


        ;// toolbar messages
        TB_ENABLEBUTTON         EQU WM_USER + 1
        TB_CHECKBUTTON          EQU WM_USER + 2
        TB_PRESSBUTTON          EQU WM_USER + 3
        TB_HIDEBUTTON           EQU WM_USER + 4
        TB_INDETERMINATE        EQU WM_USER + 5
        TB_ISBUTTONENABLED      EQU WM_USER + 9
        TB_ISBUTTONCHECKED      EQU WM_USER + 10
        TB_ISBUTTONPRESSED      EQU WM_USER + 11
        TB_ISBUTTONHIDDEN       EQU WM_USER + 12
        TB_ISBUTTONINDETERMINATE EQU WM_USER + 13
        TB_SETSTATE             EQU WM_USER + 17
        TB_GETSTATE             EQU WM_USER + 18
        TB_ADDBITMAP            EQU WM_USER + 19
        TB_SAVERESTOREA         EQU WM_USER + 26
        TB_SAVERESTOREW         EQU WM_USER + 76
        TB_CUSTOMIZE            EQU WM_USER + 27
        TB_ADDSTRINGA           EQU WM_USER + 28
        TB_ADDSTRINGW           EQU WM_USER + 77
        TB_GETITEMRECT          EQU WM_USER + 29
        TB_BUTTONSTRUCTSIZE     EQU WM_USER + 30
        TB_SETBUTTONSIZE        EQU WM_USER + 31
        TB_SETBITMAPSIZE        EQU WM_USER + 32
        TB_AUTOSIZE             EQU WM_USER + 33
        TB_GETTOOLTIPS          EQU WM_USER + 35
        TB_SETTOOLTIPS          EQU WM_USER + 36
        TB_SETPARENT            EQU WM_USER + 37
        TB_SETROWS              EQU WM_USER + 39
        TB_GETROWS              EQU WM_USER + 40
        TB_SETCMDID             EQU WM_USER + 42
        TB_CHANGEBITMAP         EQU WM_USER + 43
        TB_GETBITMAP            EQU WM_USER + 44
        TB_GETBUTTONTEXTA       EQU WM_USER + 45
        TB_GETBUTTONTEXTW       EQU WM_USER + 75
        TB_REPLACEBITMAP        EQU WM_USER + 46
        TB_SETINDENT            EQU WM_USER + 47
        TB_SETIMAGELIST         EQU WM_USER + 48
        TB_GETIMAGELIST         EQU WM_USER + 49
        TB_LOADIMAGES           EQU WM_USER + 50
        TB_GETRECT              EQU WM_USER + 51 ;// wParam is the Cmd instead of index
        TB_SETHOTIMAGELIST      EQU WM_USER + 52
        TB_GETHOTIMAGELIST      EQU WM_USER + 53
        TB_SETDISABLEDIMAGELIST EQU WM_USER + 54
        TB_GETDISABLEDIMAGELIST EQU WM_USER + 55
        TB_SETSTYLE             EQU WM_USER + 56
        TB_GETSTYLE             EQU WM_USER + 57
        TB_GETBUTTONSIZE        EQU WM_USER + 58
        TB_SETBUTTONWIDTH       EQU WM_USER + 59
        TB_SETMAXTEXTROWS       EQU WM_USER + 60
        TB_GETTEXTROWS          EQU WM_USER + 61
        TB_GETBUTTONTEXT        EQU TB_GETBUTTONTEXTA
        TB_SAVERESTORE          EQU TB_SAVERESTOREA
        TB_ADDSTRING            EQU TB_ADDSTRINGA


    ;////////////////////////////////////////////////////////////////////
    ;////////////////////////////////////////////////////////////////////
    ;//
    ;////     T O O L T I P S
    ;//

        ;// class name TOOLTIPS_CLASS EQU "tooltips_class32"

            LPSTR_TEXTCALLBACK EQU -1

        ;// style flags used in create window

            TTS_ALWAYSTIP   EQU 01h
            TTS_NOPREFIX    EQU 02h

        ;// toolinfo is used to connect a window to a tooltip

            TOOLINFO STRUCT
                dwSize  dd SIZEOF TOOLINFO
                dwFlags dd 0
                hWnd    dd 0
                dwId    dd 0
                rect RECT {}
                hInst   dd 0
                pszText dd 0
            TOOLINFO ENDS

            comment ~ /*    why are these structs different ?
                            perhaps the new version for IE4
            typedef STRUCT tagTOOLINFOA {
                UINT cbSize;
                UINT uFlags;
                HWND hwnd;
                UINT uId;
                RECT rect;
                HINSTANCE hinst;
                LPSTR lpszText;
                LPARAM lParam;
            } TTTOOLINFOA, NEAR *PTOOLINFOA, FAR *LPTTTOOLINFOA;
            */ comment ~

        ;// flags values for tool info

            TTF_IDISHWND    EQU  0001h

            ;// Use this to center around trackpoint in trackmode
            ;// -OR- to center around tool in normal mode.
            ;// Use TTF_ABSOLUTE to place the tip exactly at the track coords when
            ;// in tracking mode.  TTF_ABSOLUTE can be used in conjunction with TTF_CENTERTIP
            ;// to center the tip absolutely about the track point.

            TTF_CENTERTIP           EQU  0002h
            TTF_RTLREADING          EQU  0004h
            TTF_SUBCLASS            EQU  0010h
            TTF_TRACK               EQU  0020h
            TTF_ABSOLUTE            EQU  0080h
            TTF_TRANSPARENT         EQU  0100h
            TTF_DI_SETITEM          EQU  8000h       // valid only on the TTN_NEEDTEXT callback


        ;// this is the TOOLTIPTEXT STRUCT
        ;// also doubles as a notify STRUCT

            NMTTDISPIFNOA STRUCT
                hdr     NMHDR {}
                pszText dd 0
                szText  db 80 DUP(0)
                hInst   dd 0
                dwFlags dd 0
                lParam  dd 0
            NMTTDISPIFNOA ENDS

            TOOLTIPTEXT TYPEDEF NMTTDISPIFNOA


        ;// tool tip notify messages

            TTN_GETDISPINFOA        EQU TTN_FIRST       ;// need text
            TTN_NEEDTEXT            EQU TTN_GETDISPINFOA
            TTN_SHOW                EQU TTN_FIRST-1     ;// show
            TTN_POP                 EQU TTN_FIRST-2     ;// hide

        ;// tool tip window messages

            TTM_ACTIVATE            EQU (WM_USER + 1)
            TTM_SETDELAYTIME        EQU (WM_USER + 3)

                ;// wparam
                TTDT_AUTOMATIC   EQU       0
                TTDT_RESHOW      EQU       1
                TTDT_AUTOPOP     EQU       2
                TTDT_INITIAL     EQU       3

            TTM_ADDTOOL            EQU (WM_USER + 4)
            TTM_DELTOOL            EQU (WM_USER + 5)
            TTM_NEWTOOLRECT        EQU (WM_USER + 6)
            TTM_RELAYEVENT         EQU (WM_USER + 7)
            TTM_GETTOOLINFO        EQU (WM_USER + 8)
            TTM_SETTOOLINFO        EQU (WM_USER + 9)

            TTM_HITTEST            EQU (WM_USER +10)

                ;// lparam points at this
                TTHITTESTINFO   STRUCT

                    hwnd        dd  ?
                    point       POINT {}
                    toolinfo    TOOLINFO {}

                TTHITTESTINFO   ENDS

            TTM_GETTEXT             EQU (WM_USER +11)
            TTM_UPDATETIPTEXT       EQU (WM_USER +12)
            TTM_GETTOOLCOUNT        EQU (WM_USER +13)
            TTM_ENUMTOOLS           EQU (WM_USER +14)
            TTM_GETCURRENTTOOL      EQU (WM_USER + 15)
            TTM_WINDOWFROMPOINT     EQU (WM_USER + 16)
            ;// IE4 commands
            TTM_TRACKACTIVATE       EQU (WM_USER + 17)  ;// wParam = TRUE/FALSE start end  lparam = LPTOOLINFO
            TTM_TRACKPOSITION       EQU (WM_USER + 18)  ;// lParam = dwPos
            TTM_SETTIPBKCOLOR       EQU (WM_USER + 19)
            TTM_SETTIPTEXTCOLOR     EQU (WM_USER + 20)
            TTM_GETDELAYTIME        EQU (WM_USER + 21)
            TTM_GETTIPBKCOLOR       EQU (WM_USER + 22)
            TTM_GETTIPTEXTCOLOR     EQU (WM_USER + 23)
            TTM_SETMAXTIPWIDTH      EQU (WM_USER + 24)
            TTM_GETMAXTIPWIDTH      EQU (WM_USER + 25)
            TTM_SETMARGIN           EQU (WM_USER + 26)  ;// lParam = lprc
            TTM_GETMARGIN           EQU (WM_USER + 27)  ;// lParam = lprc
            TTM_POP                 EQU (WM_USER + 28)





        ;////////////////////////////////////////////////////////////////////
        ;////////////////////////////////////////////////////////////////////
        ;//
        ;////     S T A T U S   B A R S             are problematic, avoid using
        ;//
        ;//====== STATUS BAR CONTROL ===================================================

            SBARS_SIZEGRIP  EQU 0100h

            ;//WINCOMMCTRLAPI void WINAPI DrawStatusTextA(HDC hDC, LPRECT lprc, LPCSTR pszText, UINT uFlags);

            ;//WINCOMMCTRLAPI HWND WINAPI CreateStatusWindowA(LONG style, LPCSTR lpszText, HWND hwndParent, UINT wID);
            ;// #define STATUSCLASSNAMEA        "msctls_statusbar32"

            ;//note: there are A and W versions of these values
            ;//     this may or may not cause problems

            SB_SETTEXT          EQU    (WM_USER+1)
            SB_GETTEXT          EQU    (WM_USER+2)
            SB_GETTEXTLENGTH    EQU    (WM_USER+3)

            ;// these values do NOT have A and W versions

            SB_SETPARTS         EQU     (WM_USER+4)
            SB_GETPARTS         EQU     (WM_USER+6)
            SB_GETBORDERS       EQU     (WM_USER+7)
            SB_SETMINHEIGHT     EQU     (WM_USER+8)
            SB_SIMPLE           EQU     (WM_USER+9)
            SB_GETRECT          EQU     (WM_USER+10)
            SB_ISSIMPLE         EQU     (WM_USER+14)

            SBT_OWNERDRAW       EQU      1000h
            SBT_NOBORDERS       EQU      0100h
            SBT_POPOUT          EQU      0200h
            SBT_RTLREADING      EQU      0400h





    ;//             call DeleteObject to remove these
    ;// REGIONS
    ;//

        WIN32API CreateRectRgn, X1:DWORD, Y1:DWORD, X2:DWORD, Y2:DWORD
        ;// returns handle or zero for error

        WIN32API CreateRectRgnIndirect, pRect:DWORD
        ;// returns handle or zero for error

        WIN32API CreateRoundRectRgn, X1:DWORD, Y1:DWORD, X2:DWORD, Y2:DWORD, E1:DWORD, E2:DWORD
        ;// returns handle or zero for error

        WIN32API CreatePolygonRgn, pPoints:DWORD, numPoints:DWORD, dwMode:DWORD
        ;// return hRgn or NULL for error

        WIN32API CreateEllipticRgn, X1:DWORD, Y1:DWORD, X2:DWORD, Y2:DWORD
        ;// return hRgn or NULL for error


        WIN32API GetRegionData, hRgn:DWORD, dwCount:DWORD, pRgnData:DWORD
        ;// fills in the rgndata STRUCT !!!not defined yet!!!!
        ;// or zero for error

        ;// PolyFill() Modes
        ALTERNATE EQU 1
        WINDING   EQU 2

        WIN32API PtInRegion, hRgn:DWORD, X:DWORD, Y:DWORD
        ;// returns non-zero if yes

        WIN32API RectInRegion, hRgn:DWORD, pRect:DWORD
        ;// returns non-zero if yes

        WIN32API InvertRgn, hDC:DWORD, hRgn:DWORD

        WIN32API InvalidateRgn, hWnd:DWORD, hRgn:DWORD, bErase:DWORD
        ;// always returns non zero

        WIN32API GetRgnBox, hRgn:DWORD, pRect:DWORD
        ;// return what type of region it is

        WIN32API OffsetRgn, hRgn:DWORD, deltaX:DWORD, deltaY:DWORD
        ;// returns zero for sucess

        WIN32API CombineRgn, hDest:DWORD, hSrc1:DWORD, hSrc2:DWORD, cmbMode:DWORD
        ;// returns region type of NULL for error

            ;// CombineRgn() Styles
            RGN_AND    EQU 1
            RGN_OR     EQU 2
            RGN_XOR    EQU 3
            RGN_DIFF   EQU 4
            RGN_COPY   EQU 5

        WIN32API GetUpdateRgn, hWnd:DWORD, hRgn:DWORD, bErase:DWORD
        ;// return region type

            ;// Region types
            ERROR          EQU 0
            NULLREGION     EQU 1
            SIMPLEREGION   EQU 2
            COMPLEXREGION  EQU 3


        WIN32API FillRgn, hDC:DWORD, hRgn:DWORD, hBrush:DWORD
        ;// returns non zero for sucess

        WIN32API FrameRgn, hDC:DWORD, hRgn:DWORD, hBrush:DWORD, dwWidth:DWORD, dwHeight:DWORD
        ;// return non zero for sucess


    ;//
    ;// Other
    ;//

        WIN32API GetDesktopWindow
        ;// return hWnd or zero for error





;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;////              heirarchy:       creation          def window proc:
;////              ----------------------------------------------------------
;////              FrameWnd         CreateWindowEx    DefFrameWndProc
;////   M D I         ClientWnd     CreateWindowEx    n/a
;////                    childWnd   CreateMDIWindow   DefMDIChildWndProc
;////                    childWnd
;////                    ...

    WIN32API DefFrameProcA, hWndMDIFrame:DWORD, hWndMDIClient:DWORD, dwMsg:DWORD,wParam:DWORD, lParam:DWORD
    ;// returns what what the frame proc should return

    WIN32API CreateMDIWindowA, pClassName:DWORD, pszWindowName:DWORD, dwStyle:DWORD, dwX:DWORD, dwY:DWORD, dwWidth:DWORD, dwHeight:DWORD, hWndMDIClient:DWORD, hInstance:DWORD, lParam:DWORD
    ;// return an hWnd to the newly created child window

    WIN32API DefMDIChildProcA, hWndChild:DWORD, dwMsg:DWORD, wParam:DWORD, lParam:DWORD
    ;// returns what MDIChildProc should return

    WIN32API TranslateMDISysAccel, hWndClient:DWORD, pMsg:DWORD
    ;// return non-zero if this is a system command

    CLIENTCREATESTRUCT STRUCT
        hWindowMenu     dd 0
        idFirstChild    dd 0
    CLIENTCREATESTRUCT endS






;////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////
;//
;//
;//     R E G I S T R Y


    WIN32API RegCreateKeyA, hKey:DWORD, lpSubKey:DWORD, phkResult:DWORD
    WIN32API RegCreateKeyExA, hKey:DWORD,   lpSubKey:DWORD,Reserved:DWORD,pClass:DWORD,dwOptions:DWORD,samDesired:DWORD,lpSecurityAttributes:DWORD,phkResult:DWORD,pdwDisposition:DWORD
    ;// returns ERROR_SUCCESS (0) or error code

    WIN32API RegDeleteKeyA, hKey:DWORD, pszKeyName:DWORD
    ;// returns zero for sucess

    WIN32API RegOpenKeyExA, hKey:DWORD, pszSubKey:DWORD, dwOptions:DWORD, dwDesiredAccess:DWORD, pResult:DWORD

    WIN32API RegEnumKeyExA, hKey:DWORD, dwIndex:DWORD, lpName:DWORD, lpcbName:DWORD, lpReserved:DWORD, lpClass:DWORD, lpcbClass:DWORD, lpftLastWriteTime:DWORD


    WIN32API RegDeleteValueA, hKey:DWORD, pszValueName:DWORD
    ;// returns zero for sucess


    WIN32API RegQueryInfoKeyA, hKey:DWORD, pClass:DWORD, pcbClass:DWORD, pReserved:DWORD, pcSubKeys:DWORD, pcbMaxSubKeyLen:DWORD, pcbMaxClassLen:DWORD, pcValues:DWORD, pcbMaxValueNameLen:DWORD, pcbMaxValueLen:DWORD, pcbSecurityDescriptor:DWORD, pftLastWriteTime:DWORD
    ;// returns zero for sucess


    ;// predefined keys
    HKEY_CLASSES_ROOT           EQU 80000000h   ;// always open
    HKEY_CURRENT_USER           EQU 80000001h   ;// always open
    HKEY_LOCAL_MACHINE          EQU 80000002h   ;// always open
    HKEY_USERS                  EQU 80000003h   ;// always open
    HKEY_PERFORMANCE_DATA       EQU 80000004h
    HKEY_CURRENT_CONFIG         EQU 80000005h
    HKEY_DYN_DATA               EQU 80000006h

    ;// Open/Create Options
    REG_OPTION_RESERVED         EQU 00000000h
    REG_OPTION_NON_VOLATILE     EQU 00000000h
    REG_OPTION_VOLATILE         EQU 00000001h
    REG_OPTION_CREATE_LINK      EQU 00000002h
    REG_OPTION_BACKUP_RESTORE   EQU 00000004h
    REG_OPTION_OPEN_LINK        EQU 00000008h

    ;// access types
    KEY_QUERY_VALUE         EQU 0001h
    KEY_SET_VALUE           EQU 0002h
    KEY_CREATE_SUB_KEY      EQU 0004h
    KEY_ENUMERATE_SUB_KEYS  EQU 0008h
    KEY_NOTIFY              EQU 0010h
    KEY_CREATE_LINK         EQU 0020h

    ;// Key creation/open disposition
    REG_CREATED_NEW_KEY         EQU 00000001h
    REG_OPENED_EXISTING_KEY     EQU 00000002h


    WIN32API RegCloseKey, hKey:DWORD
    ;// returns 0 or error code

    WIN32API RegSetValueA, hKey:DWORD,pszSubKey:DWORD,dwType:DWORD,pData:ptr,cbData:DWORD


    WIN32API RegSetValueExA, hKey:DWORD,pValueName:ptr,Reserved:DWORD,dwType:DWORD,pData:ptr,cbData:DWORD
    ;// returns 0 or error code

    WIN32API RegQueryValueExA, hKey:DWORD, pValueName:ptr,Reserved:DWORD,pdwType:ptr,pData:ptr,pcbData:ptr
    ;// returns 0 or error code

    WIN32API RegEnumValueA, hKey:DWORD, dwIndex:DWORD, pValueName:DWORD, pcbValueName:DWORD, pReserved:DWORD, pType:DWORD, pData:DWORD, pcbData:DWORD
    ;// return zero for success


    ;// data types
    REG_NONE                    EQU 0
    REG_SZ                      EQU 1
    REG_EXPAND_SZ               EQU 2
    REG_BINARY                  EQU 3
    REG_DWORD                   EQU 4
    REG_DWORD_LITTLE_ENDIAN     EQU 4
    REG_DWORD_BIG_ENDIAN        EQU 5
    REG_LINK                    EQU 6
    REG_MULTI_SZ                EQU 7
    REG_RESOURCE_LIST           EQU 8
    REG_FULL_RESOURCE_DESCRIPTOR EQU 9
    REG_RESOURCE_REQUIREMENTS_LIST EQU 10









;//////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////
;//
;//
;////    C L I P B O A R D
;//

    WIN32API OpenClipboard, hWndOwner:DWORD
    ;// returns non-zero for sucess

    WIN32API EmptyClipboard

    WIN32API CloseClipboard
    ;// returns non-zero for sucess

    WIN32API SetClipboardData, dwFormat:DWORD, hMem:DWORD
    ;// returns handle to data or zero for error
    ;// hMem must be moveable and ddeshare

    ;// * Predefined Clipboard Formats

        CLIPFORMAT TYPEDEF DWORD

        CF_TEXT             EQU   1
        CF_BITMAP           EQU   2
        CF_METAFILEPICT     EQU   3
        CF_SYLK             EQU   4
        CF_DIF              EQU   5
        CF_TIFF             EQU   6
        CF_OEMTEXT          EQU   7
        CF_DIB              EQU   8
        CF_PALETTE          EQU   9
        CF_PENDATA          EQU   10
        CF_RIFF             EQU   11
        CF_WAVE             EQU   12
        CF_UNICODETEXT      EQU   13
        CF_ENHMETAFILE      EQU   14
        CF_HDROP            EQU   15
        CF_LOCALE           EQU   16
        CF_MAX              EQU   17
        CF_OWNERDISPLAY     EQU   0x0080
        CF_DSPTEXT          EQU   0x0081
        CF_DSPBITMAP        EQU   0x0082
        CF_DSPMETAFILEPICT  EQU   0x0083
        CF_DSPENHMETAFILE   EQU   0x008E
        ;// * "Private" formats don't get GlobalFree()'d
        CF_PRIVATEFIRST     EQU   0x0200
        CF_PRIVATELAST      EQU   0x02FF
        ;// "GDIOBJ" formats do get DeleteObject()'d
        CF_GDIOBJFIRST      EQU   0x0300
        CF_GDIOBJLAST       EQU   0x03FF






;//////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////
;//
;//                     use _malloc.inc to define ...
;//  M E M O R Y
;//

    WIN32API IsBadReadPtr, pMem:DWORD, siz:DWORD
    ;// return zero is entire block may be read

    WIN32API IsBadWritePtr, pMem:DWORD, siz:DWORD
    ;// return zero is entire block may be read

    WIN32API GlobalMemoryStatus, pMemoryStatus:DWORD
    ;// no return value

    MEMORYSTATUS STRUCT
        dwLength        dd SIZEOF MEMORYSTATUS
        dwMemoryLoad    dd 0    ;//  percent of memory in use
        dwTotalPhys     dd 0    ;//  bytes of physical memory
        dwAvailPhys     dd 0    ;//  free physical memory bytes
        dwTotalPageFile dd 0    ;//  bytes of paging file
        dwAvailPageFile dd 0    ;//  free bytes of paging file
        dwTotalVirtual  dd 0    ;//  user bytes of address space
        dwAvailVirtual  dd 0    ;//  free user bytes }
    MEMORYSTATUS ENDS



    WIN32API GetHandleInformation, hObject:DWORD, pResults:DWORD
    ;// returns non zero for sucess, reults in pResults




;////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////
;//
;//
;////   G R A P H I C S
;//
    ;//
    ;//     G D I   O B J E C T S
    ;//           A N D
    ;// D E V I C E   C O N T E X T S
    ;//
        WIN32API GetDC, hWnd:DWORD
        ;// returns hDC or NULL for error

        WIN32API GetWindowDC, hWnd:DWORD
        ;// returns hDC or NULL for error

        WIN32API GetDCEx, hWnd:DWORD, hRgn:DWORD, dwFlags:DWORD
        ;// returns hDC or NULL for error

            DCX_WINDOW           EQU 00000001h
            DCX_CACHE            EQU 00000002h
            DCX_NORESETATTRS     EQU 00000004h
            DCX_CLIPCHILDREN     EQU 00000008h
            DCX_CLIPSIBLINGS     EQU 00000010h
            DCX_PARENTCLIP       EQU 00000020h

            DCX_EXCLUDERGN       EQU 00000040h
            DCX_INTERSECTRGN     EQU 00000080h

            DCX_EXCLUDEUPDATE    EQU 00000100h
            DCX_INTERSECTUPDATE  EQU 00000200h

            DCX_LOCKWINDOWUPDATE EQU 00000400h

            DCX_VALIDATE         EQU 00200000h


        WIN32API ReleaseDC, hWnd:DWORD, hDC:DWORD
        ;// returns zero for error

        WIN32API CreateCompatibleDC, hDC:DWORD
        ;// return hDC or NULL for error

        WIN32API DeleteDC, hDC:DWORD
        ;// returns non zero for sucess


        WIN32API GdiFlush


        WIN32API SelectObject, hdc:DWORD, hgdiobj:DWORD
        ;//returns previously selected hGDIOBJ or NULL for error


        IMPORT32 GetCurrentObject, hDC, uObjType    ;// wingdi.h

        ;// Object Definitions for EnumObjects() and GetCurrentObject

            OBJ_PEN           EQU  1
            OBJ_BRUSH         EQU  2
            OBJ_DC            EQU  3
            OBJ_METADC        EQU  4
            OBJ_PAL           EQU  5
            OBJ_FONT          EQU  6
            OBJ_BITMAP        EQU  7
            OBJ_REGION        EQU  8
            OBJ_METAFILE      EQU  9
            OBJ_MEMDC         EQU  10
            OBJ_EXTPEN        EQU  11
            OBJ_ENHMETADC     EQU  12
            OBJ_ENHMETAFILE   EQU  13

        WIN32API GetObjectA, hGDIobj:DWORD, sizeBuffer:DWORD, pBuffer:DWORD
        ;// return pBuffer or NULL for error



        WIN32API DeleteObject, hgdiobj:DWORD
        ;// returns 0 for error

        WIN32API GetStockObject, dwIndex:DWORD

            ;// Stock Logical Objects
            WHITE_BRUSH         EQU 0
            LTGRAY_BRUSH        EQU 1
            GRAY_BRUSH          EQU 2
            DKGRAY_BRUSH        EQU 3
            BLACK_BRUSH         EQU 4
            NULL_BRUSH          EQU 5
            HOLLOW_BRUSH        EQU NULL_BRUSH
            WHITE_PEN           EQU 6
            BLACK_PEN           EQU 7
            NULL_PEN            EQU 8
            OEM_FIXED_FONT      EQU 10
            ANSI_FIXED_FONT     EQU 11
            ANSI_VAR_FONT       EQU 12
            SYSTEM_FONT         EQU 13
            DEVICE_DEFAULT_FONT EQU 14
            DEFAULT_PALETTE     EQU 15
            SYSTEM_FIXED_FONT   EQU 16
            DEFAULT_GUI_FONT    EQU 17



        WIN32API SetTextColor, hDc:DWORD, crColor:DWORD
        ;// returns the previous color or CLR_INAVLID for error

        WIN32API SetBkColor, hDc:DWORD, crColor:DWORD
        ;// return the previous color or CLR_INAVLID for error

        WIN32API SetBkMode, hdc:DWORD, iBkMode:DWORD
        ;// returns previous mode, or zero for error

            ;// bk mode values
            TRANSPARENT  EQU 1
            OPAQUE       EQU 2

        WIN32API SetTextAlign, hdc:DWORD, alignMode:DWORD
        ;// returns previous setting

            TA_NOUPDATECP   EQU 0
            TA_UPDATECP     EQU 1
            TA_LEFT         EQU 0
            TA_RIGHT        EQU 2
            TA_CENTER       EQU 6
            TA_TOP          EQU 0
            TA_BOTTOM       EQU 8
            TA_BASELINE     EQU 24
            TA_RTLREADING   EQU 256

        WIN32API GetSysColor, dwIndex:DWORD
        ;// return the DWORD color value, see COLOR_WINDOW

        WIN32API SetSysColors, dwNumElements:DWORD, pElements:DWORD, pColors:DWORD
        ;// returns non zero for sucess

        WIN32API GetSysColorBrush, dwIndex:DWORD
        ;// return the handle of said brush



        WIN32API GetDeviceCaps, hDC:DWORD, nIndex:DWORD
        ;// returns the desired data in eax
        ;//
        ;// Device Parameters for GetDeviceCaps()
        ;//  and some return value masks

            DRIVERVERSION EQU 0
            TECHNOLOGY    EQU 2
                DT_PLOTTER         EQU  0
                DT_RASDISPLAY      EQU  1
                DT_RASPRINTER      EQU  2
                DT_RASCAMERA       EQU  3
                DT_CHARSTREAM      EQU  4
                DT_METAFILE        EQU  5
                DT_DISPFILE        EQU  6

            HORZSIZE      EQU 4
            VERTSIZE      EQU 6
            HORZRES       EQU 8
            VERTRES       EQU 10
            BITSPIXEL     EQU 12
            PLANES        EQU 14
            NUMBRUSHES    EQU 16
            NUMPENS       EQU 18
            NUMMARKERS    EQU 20
            NUMFONTS      EQU 22
            NUMCOLORS     EQU 24
            PDEVICESIZE   EQU 26
            CURVECAPS     EQU 28
                CC_NONE            EQU  0
                CC_CIRCLES         EQU  1
                CC_PIE             EQU  2
                CC_CHORD           EQU  4
                CC_ELLIPSES        EQU  8
                CC_WIDE            EQU  16
                CC_STYLED          EQU  32
                CC_WIDESTYLED      EQU  64
                CC_INTERIORS       EQU  128
                CC_ROUNDRECT       EQU  256

            LINECAPS      EQU 30
                LC_NONE            EQU  0
                LC_POLYLINE        EQU  2
                LC_MARKER          EQU  4
                LC_POLYMARKER      EQU  8
                LC_WIDE            EQU  16
                LC_STYLED          EQU  32
                LC_WIDESTYLED      EQU  64
                LC_INTERIORS       EQU  128

            POLYGONALCAPS EQU 32
                PC_NONE             EQU 0
                PC_POLYGON          EQU 1
                PC_RECTANGLE        EQU 2
                PC_WINDPOLYGON      EQU 4
                PC_TRAPEZOID        EQU 4
                PC_SCANLINE         EQU 8
                PC_WIDE             EQU 16
                PC_STYLED           EQU 32
                PC_WIDESTYLED       EQU 64
                PC_INTERIORS        EQU 128
                PC_POLYPOLYGON      EQU 256
                PC_PATHS            EQU 512

            TEXTCAPS      EQU 34
                TC_OP_CHARACTER     EQU 0x00000001
                TC_OP_STROKE        EQU 0x00000002
                TC_CP_STROKE        EQU 0x00000004
                TC_CR_90            EQU 0x00000008
                TC_CR_ANY           EQU 0x00000010
                TC_SF_X_YINDEP      EQU 0x00000020
                TC_SA_DOUBLE        EQU 0x00000040
                TC_SA_INTEGER       EQU 0x00000080
                TC_SA_CONTIN        EQU 0x00000100
                TC_EA_DOUBLE        EQU 0x00000200
                TC_IA_ABLE          EQU 0x00000400
                TC_UA_ABLE          EQU 0x00000800
                TC_SO_ABLE          EQU 0x00001000
                TC_RA_ABLE          EQU 0x00002000
                TC_VA_ABLE          EQU 0x00004000
                TC_RESERVED         EQU 0x00008000
                TC_SCROLLBLT        EQU 0x00010000

            CLIPCAPS      EQU 36
                CP_NONE             EQU 0
                CP_RECTANGLE        EQU 1
                CP_REGION           EQU 2

            RASTERCAPS    EQU 38
                RC_NONE             EQU 0
                RC_BITBLT           EQU 1
                RC_BANDING          EQU 2
                RC_SCALING          EQU 4
                RC_BITMAP64         EQU 8
                RC_GDI20_OUTPUT     EQU 0x0010
                RC_GDI20_STATE      EQU 0x0020
                RC_SAVEBITMAP       EQU 0x0040
                RC_DI_BITMAP        EQU 0x0080
                RC_PALETTE          EQU 0x0100
                RC_DIBTODEV         EQU 0x0200
                RC_BIGFONT          EQU 0x0400
                RC_STRETCHBLT       EQU 0x0800
                RC_FLOODFILL        EQU 0x1000
                RC_STRETCHDIB       EQU 0x2000
                RC_OP_DX_OUTPUT     EQU 0x4000
                RC_DEVBITS          EQU 0x8000

            ASPECTX       EQU 40
            ASPECTY       EQU 42
            ASPECTXY      EQU 44

            LOGPIXELSX    EQU 88
            LOGPIXELSY    EQU 90

            SIZEPALETTE  EQU 104
            NUMRESERVED  EQU 106
            COLORRES     EQU 108

            ;// Printing related DeviceCaps. These replace the appropriate Escapes
            PHYSICALWIDTH   EQU 110
            PHYSICALHEIGHT  EQU 111
            PHYSICALOFFSETX EQU 112
            PHYSICALOFFSETY EQU 113
            SCALINGFACTORX  EQU 114
            SCALINGFACTORY  EQU 115

            ;// Display driver specific
            VREFRESH        EQU 116
            DESKTOPVERTRES  EQU 117
            DESKTOPHORZRES  EQU 118
            BLTALIGNMENT    EQU 119




    ;//
    ;//  C O O R D I N A T E   T R A N S F O R M S
    ;//


        WIN32API GetMapMode, hDC:DWORD
        ;// returns one of the map mode

        WIN32API SetMapMode, hDC:DWORD, dwMode:DWORD
        ;// returns prev map mode

            ;// Mapping Modes
            MM_TEXT           EQU  1
            MM_LOMETRIC       EQU  2
            MM_HIMETRIC       EQU  3
            MM_LOENGLISH      EQU  4
            MM_HIENGLISH      EQU  5
            MM_TWIPS          EQU  6
            MM_ISOTROPIC      EQU  7
            MM_ANISOTROPIC    EQU  8


        WIN32API SetWindowExtEx, hdc:DWORD, dwXExtent:DWORD, dwYExtent:DWORD, pOldSize:DWORD
        ;// return non zero for sucess

        WIN32API SetViewportExtEx, hdc:DWORD, dwXExtent:DWORD, dwYExtent:DWORD, pOldSize:DWORD
        ;// return non zero for sucess












    ;//
    ;// B I T M A P S
    ;//

        BITMAP STRUCT
            bmType          dd 0
            bmWidth         dd 0
            bmHeight        dd 0
            bmWidthBytes    dd 0
            bmPlanes        dw 0
            bmBitsPixel     dw 0
            pbmBits         dd 0
        BITMAP ENDS

        BITMAPFILEHEADER    STRUCT
            bfType          dw  'MB'
            bfSize          dd  0
            bfReserved12    dd  0   ;
            bfOffBits       dd  0   ;
        BITMAPFILEHEADER    ENDS

        ;// NOTE !! the above struct is NOT DWORD ALIGNED !!

        BITMAPINFOHEADER STRUCT
            biSize          dd SIZEOF BITMAPINFOHEADER
            biWidth         dd 0
            biHeight        dd 0
            biPlanes        dw 0
            biBitCount      dw 0
            biCompression   dd 0
            biSizeImage     dd 0
            biXPelsPerMeter dd 0
            biYPelsPerMeter dd 0
            biClrUsed       dd 0
            biClrImportant  dd 0
        BITMAPINFOHEADER ENDS

        BITMAPINFO STRUCT
            bmiHeader    BITMAPINFOHEADER {}
            bmiColors   dd 0
        BITMAPINFO ENDS

        ;// biCompression values

            BI_RGB       EQU 0
            BI_RLE8      EQU 1
            BI_RLE4      EQU 2
            BI_BITFIELDS EQU 3

        ;// pre built bitmap info headers


        BITMAP_INFO_24  STRUCT

            BITMAPINFOHEADER    {40,0,0,1,24,BI_RGB,0,0,0,0,0}

        BITMAP_INFO_24  ENDS



        BITMAPINFO_256 STRUCT

            BITMAPINFOHEADER    {40,0,0,1,8,BI_RGB,0,0,0,0,0}

            comment ~ /*
            biSize          dd 40
            biWidth         dd 0
            biHeight        dd 0
            biPlanes        dw 1
            biBitCount      dw 8
            biCompression   dd BI_RGB
            biSizeImage     dd 0
            biXPelsPerMeter dd 0
            biYPelsPerMeter dd 0
            biClrUsed       dd 0
            biClrImportant  dd 0
            */ comment ~

            palette dd 256 DUP (0)

        BITMAPINFO_256 ENDS


        ;// std colors ... for DOS at least

        COLOR_BLK       EQU 00000000h   ;// black
        COLOR_BLU       EQU 00000080h   ;// blue
        COLOR_GRN       EQU 00008000h   ;// green
        COLOR_CYN       EQU 00008080h   ;// cyan
        COLOR_RED       EQU 00800000h   ;// red
        COLOR_MAG       EQU 00800080h   ;// magenta
        COLOR_BRN       EQU 00808000h   ;// brown
        COLOR_WHT       EQU 00808080h   ;// white
                                        ;//   rrggbbh
        COLOR_LT_BLK    EQU 00404040h   ;// lt_black
        COLOR_LT_BLU    EQU 000000FFh   ;// lt_blue
        COLOR_LT_GRN    EQU 0000FF00h   ;// lt_green
        COLOR_LT_CYN    EQU 0000FFFFh   ;// lt_cyan
        COLOR_LT_RED    EQU 00FF0000h   ;// lt_red
        COLOR_LT_MAG    EQU 00FF00FFh   ;// lt_magenta
        COLOR_LT_BRN    EQU 00FFFF00h   ;// yellow
        COLOR_LT_WHT    EQU 00FFFFFFh   ;// lt_white







        DOS_256_PALETTE STRUCT

                    dd  00000000h   ;// black
                    dd  00000080h   ;// blue
                    dd  00008000h   ;// green
                    dd  00008080h   ;// cyan
                    dd  00800000h   ;// red
                    dd  00800080h   ;// magenta
                    dd  00808000h   ;// brown
                    dd  00808080h   ;// white
                    ;//   rrggbbh
                    dd  00404040h   ;// lt_black
                    dd  000000FFh   ;// lt_blue
                    dd  0000FF00h   ;// lt_green
                    dd  0000FFFFh   ;// lt_cyan
                    dd  00FF0000h   ;// lt_red
                    dd  00FF00FFh   ;// lt_magenta
                    dd  00FFFF00h   ;// yellow
                    dd  00FFFFFFh   ;// lt_white

                ;//     240 shades of grey

                dd  00101010h,00111111h,00121212h,00131313h,00141414h,00151515h,00161616h,00171717h,00181818h,00191919h,001A1A1Ah,001B1B1Bh,001C1C1Ch,001D1D1Dh,001E1E1Eh,001F1F1Fh
                dd  00202020h,00212121h,00222222h,00232323h,00242424h,00252525h,00262626h,00272727h,00282828h,00292929h,002A2A2Ah,002B2B2Bh,002C2C2Ch,002D2D2Dh,002E2E2Eh,002F2F2Fh
                dd  00303030h,00313131h,00323232h,00333333h,00343434h,00353535h,00363636h,00373737h,00383838h,00393939h,003A3A3Ah,003B3B3Bh,003C3C3Ch,003D3D3Dh,003E3E3Eh,003F3F3Fh
                dd  00404040h,00414141h,00424242h,00434343h,00444444h,00454545h,00464646h,00474747h,00484848h,00494949h,004A4A4Ah,004B4B4Bh,004C4C4Ch,004D4D4Dh,004E4E4Eh,004F4F4Fh
                dd  00505050h,00515151h,00525252h,00535353h,00545454h,00555555h,00565656h,00575757h,00585858h,00595959h,005A5A5Ah,005B5B5Bh,005C5C5Ch,005D5D5Dh,005E5E5Eh,005F5F5Fh
                dd  00606060h,00616161h,00626262h,00636363h,00646464h,00656565h,00666666h,00676767h,00686868h,00696969h,006A6A6Ah,006B6B6Bh,006C6C6Ch,006D6D6Dh,006E6E6Eh,006F6F6Fh
                dd  00707070h,00717171h,00727272h,00737373h,00747474h,00757575h,00767676h,00777777h,00787878h,00797979h,007A7A7Ah,007B7B7Bh,007C7C7Ch,007D7D7Dh,007E7E7Eh,007F7F7Fh
                dd  00808080h,00818181h,00828282h,00838383h,00848484h,00858585h,00868686h,00878787h,00888888h,00898989h,008A8A8Ah,008B8B8Bh,008C8C8Ch,008D8D8Dh,008E8E8Eh,008F8F8Fh
                dd  00909090h,00919191h,00929292h,00939393h,00949494h,00959595h,00969696h,00979797h,00989898h,00999999h,009A9A9Ah,009B9B9Bh,009C9C9Ch,009D9D9Dh,009E9E9Eh,009F9F9Fh
                dd  00A0A0A0h,00A1A1A1h,00A2A2A2h,00A3A3A3h,00A4A4A4h,00A5A5A5h,00A6A6A6h,00A7A7A7h,00A8A8A8h,00A9A9A9h,00AAAAAAh,00ABABABh,00ACACACh,00ADADADh,00AEAEAEh,00AFAFAFh
                dd  00B0B0B0h,00B1B1B1h,00B2B2B2h,00B3B3B3h,00B4B4B4h,00B5B5B5h,00B6B6B6h,00B7B7B7h,00B8B8B8h,00B9B9B9h,00BABABAh,00BBBBBBh,00BCBCBCh,00BDBDBDh,00BEBEBEh,00BFBFBFh
                dd  00C0C0C0h,00C1C1C1h,00C2C2C2h,00C3C3C3h,00C4C4C4h,00C5C5C5h,00C6C6C6h,00C7C7C7h,00C8C8C8h,00C9C9C9h,00CACACAh,00CBCBCBh,00CCCCCCh,00CDCDCDh,00CECECEh,00CFCFCFh
                dd  00D0D0D0h,00D1D1D1h,00D2D2D2h,00D3D3D3h,00D4D4D4h,00D5D5D5h,00D6D6D6h,00D7D7D7h,00D8D8D8h,00D9D9D9h,00DADADAh,00DBDBDBh,00DCDCDCh,00DDDDDDh,00DEDEDEh,00DFDFDFh
                dd  00E0E0E0h,00E1E1E1h,00E2E2E2h,00E3E3E3h,00E4E4E4h,00E5E5E5h,00E6E6E6h,00E7E7E7h,00E8E8E8h,00E9E9E9h,00EAEAEAh,00EBEBEBh,00ECECECh,00EDEDEDh,00EEEEEEh,00EFEFEFh
                dd  00F0F0F0h,00F1F1F1h,00F2F2F2h,00F3F3F3h,00F4F4F4h,00F5F5F5h,00F6F6F6h,00F7F7F7h,00F8F8F8h,00F9F9F9h,00FAFAFAh,00FBFBFBh,00FCFCFCh,00FDFDFDh,00FEFEFEh,00FFFFFFh

        DOS_256_PALETTE ENDS




        BITMAPINFO_256_DOS_GREY STRUCT

            BITMAPINFOHEADER    {40,0,0,1,8,BI_RGB,0,0,0,0,0}
                    ;//   rrggbbh

            palette DOS_256_PALETTE {}

        BITMAPINFO_256_DOS_GREY ENDS

        ;// indexes
        DOS_BLK     EQU 0
        DOS_BLU     EQU 1
        DOS_GRN     EQU 2
        DOS_CYN     EQU 3
        DOS_RED     EQU 4
        DOS_MAG     EQU 5
        DOS_BRN     EQU 6
        DOS_WHT     EQU 7

        DOS_LT_BLK  EQU 8
        DOS_LT_BLU  EQU 9
        DOS_LT_GRN  EQU 10
        DOS_LT_CYN  EQU 11
        DOS_LT_RED  EQU 12
        DOS_LT_MAG  EQU 13
        DOS_LT_BRN  EQU 14
        DOS_LT_WHT  EQU 15


        ;// DIB
        DIBSECTION STRUCT
            dsBm    BITMAP {}
            dsBmih  BITMAPINFOHEADER {}
            dsBitfields dd 3 DUP(0)
            dshSection  dd 0
            dsOffset    dd 0
        DIBSECTION ENDS


        WIN32API CreateCompatibleBitmap, hdc:DWORD, nWidth:DWORD,nHeight:DWORD
        ;// return hBitmap or NULL for error

        WIN32API CreateBitmap, nWidth:DWORD, nHeight:DWORD, cPlanes:DWORD, cBitsPerPel:DWORD, pBits:DWORD
        ;// return hBitmap, or 0 for error

        WIN32API CreateDIBitmap, hDC:DWORD, pBMIH:DWORD, dwInit:DWORD, pBits:DWORD, pBINFO:DWORD, dwUsage:DWORD
        ;// returns the handle

            ;// dwInit values
            CBM_INIT   EQU 4




        WIN32API GetDIBits, hDC:DWORD, hBitmap:DWORD, uStartScan:DWORD, cScanLines:DWORD, pBits:DWORD, pBitmapInfo:DWORD, uUsage:DWORD
        ;// returns the number of scan lines gotten

        WIN32API SetDIBits, hDC:DWORD, hBitmap:DWORD,   uStartScan:DWORD, cScanLines:DWORD, pBits:DWORD, pBitmapInfo:DWORD, uColorUse:DWORD
        ;// return number of scan-lines copied

        ;// flags for uColorUse
        DIB_RGB_COLORS  EQU 0
        DIB_PAL_COLORS  EQU 1


        WIN32API LoadBitmapA, hInstance:DWORD, pszName:DWORD
        ;// returns an hBitmap

            LR_DEFAULTCOLOR     EQU 0000h
            LR_MONOCHROME       EQU 0001h
            LR_COLOR            EQU 0002h
            LR_COPYRETURNORG    EQU 0004h
            LR_COPYDELETEORG    EQU 0008h
            LR_LOADFROMFILE     EQU 0010h
            LR_LOADTRANSPARENT  EQU 0020h
            LR_DEFAULTSIZE      EQU 0040h
            LR_VGACOLOR         EQU 0080h
            LR_LOADMAP3DCOLORS  EQU 1000h
            LR_CREATEDIBSECTION EQU 2000h
            LR_COPYFROMRESOURCE EQU 4000h
            LR_SHARED           EQU 8000h



        WIN32API GetBitmapDimensionEx, hBitmap:DWORD, pSize:DWORD
        ;// return non-zero for sucess
        ;// DOES NOT DO ANYTHING !!!!!!!


        WIN32API GetDIBColorTable, hDC:DWORD, dwStart:DWORD, dwNum:DWORD, pPalette:DWORD
        ;// returns number of entries retreived

        WIN32API SetDIBColorTable, hDC:DWORD, dwStart:DWORD, dwNum:DWORD, pPalette:DWORD
        ;// returns number of entries retreived

        WIN32API CreateDIBSection, hdc:DWORD, pbmi:DWORD, dwUsage:DWORD,ppBits:DWORD, hSection:DWORD, dwOffset:DWORD
        ;// returns a handle to created bitmap, or zero for error


    ;//
    ;// B I T M A P / D C
    ;//
        WIN32API BitBlt, hdcDest:DWORD, nXDest:DWORD, nYDest:DWORD, nWidth:DWORD, nHeight:DWORD, hdcSrc:DWORD, nXSrc:DWORD, nYSrc:DWORD, dwRop:DWORD
        ;// returns 0 for error

            ;// to push args manually
            ;// 8 BitBlt.dwRop
            ;// 7 BitBlt.nYSrc
            ;// 6 BitBlt.nXSrc
            ;// 5 BitBlt.hdcSrc
            ;// 4 BitBlt.nHeight
            ;// 3 BitBlt.nWidth
            ;// 2 BitBlt.nYDest
            ;// 1 BitBlt.nXDest
            ;// 0 BitBlt.hdcDest
            ;// call BitBlt


        ;// NT only
        WIN32API MaskBlt, hdcDest:DWORD, nXDest:DWORD, nYDest:DWORD, nWidth:DWORD, nHeight:DWORD, hdcSrc:DWORD, nXSrc:DWORD, nYSrc:DWORD, hbmpMask:DWORD, xMask:DWORD, yMask:DWORD, dwRop:DWORD
        ;// returns 0 for error


        WIN32API StretchBlt, dest_hDC:DWORD,dest_X:DWORD,dest_Y:DWORD,dest_Width:DWORD,dest_Height:DWORD,src_hDC:DWORD,src_X:DWORD,src_Y:DWORD,src_Width:DWORD,src_Height:DWORD,dwRop:DWORD

            STRETCHBLT_STACK    STRUCT

                dest_hDC    dd  0   ;// HDC hdcDest,        // handle of destination device context

                dest_X      dd  0   ;// int nXOriginDest,  // x-coordinate of upper-left corner of dest. rect.
                dest_Y      dd  0   ;// int nYOriginDest,  // y-coordinate of upper-left corner of dest. rect.
                dest_Width  dd  0   ;// int nWidthDest,    // width of destination rectangle
                dest_Height dd  0   ;// int nHeightDest,   // height of destination rectangle

                src_hDC     dd  0   ;// HDC hdcSrc,        // handle of source device context

                src_X       dd  0   ;// int nXOriginSrc,   // x-coordinate of upper-left corner of source rectangle
                src_Y       dd  0   ;// int nYOriginSrc,   // y-coordinate of upper-left corner of source rectangle
                src_Width   dd  0   ;// int nWidthSrc,     // width of source rectangle
                src_Height  dd  0   ;// int nHeightSrc,    // height of source rectangle

                dwRop       dd  0   ;// DWORD dwRop        // raster operation code

            STRETCHBLT_STACK    ENDS

        WIN32API SetDIBitsToDevice, hdc:DWORD, dwXdest:DWORD, dwYdest:DWORD, dwWidthSource:DWORD, dwHeightSource:DWORD, dwXsource:DWORD, dwYSource:DWORD, dwStartScan:DWORD, dwNumScan:DWORD, pBits:DWORD, pInfo:DWORD, dwUsage:DWORD
        ;// returns number of scan lines drawn



        ;// Ternary Raster Operation Codes
        SRCCOPY     EQU 00CC0020h ;// dest = source
        SRCPAINT    EQU 00EE0086h ;// dest = source OR dest
        SRCAND      EQU 008800C6h ;// dest = source AND dest
        SRCINVERT   EQU 00660046h ;// dest = source XOR dest
        SRCERASE    EQU 00440328h ;// dest = source AND (NOT dest )
        NOTSRCCOPY  EQU 00330008h ;// dest = (NOT source)
        NOTSRCERASE EQU 001100A6h ;// dest = (NOT src) AND (NOT dest)
        MERGECOPY   EQU 00C000CAh ;// dest = (source AND pattern)
        MERGEPAINT  EQU 00BB0226h ;// dest = (NOT source) OR dest
        PATCOPY     EQU 00F00021h ;// dest = pattern
        PATPAINT    EQU 00FB0A09h ;// dest = DPSnoo
        PATINVERT   EQU 005A0049h ;// dest = pattern XOR dest
        DSTINVERT   EQU 00550009h ;// dest = (NOT dest)
        BLACKNESS   EQU 00000042h ;// dest = BLACK
        WHITENESS   EQU 00FF0062h ;// dest = WHITE



    ;//
    ;//  FONTS AND TEXT
    ;//


        ;//too big !WIN32API CreateFontA, nHeight:DWORD, nWidth:DWORD, nEscapement:DWORD, nOrientation:DWORD, fnWeight:DWORD, fdwItalic:DWORD, fdwUnderline:DWORD, fdwStrikeOut:DWORD, fdwCharSet:DWORD, fdwOutputPrecision:DWORD, fdwClipPrecision:DWORD, fdwQuality:DWORD, fdwPitchAndFamily:DWORD, lpszFace:DWORD
        ;//WIN32API CreateFontA, :DWORD, :DWORD, :DWORD, :DWORD, :DWORD, :DWORD, :DWORD, :DWORD, :DWORD, :DWORD, :DWORD, :DWORD, :DWORD, :DWORD
        IMPORT32 CreateFontA, nHeight, nWidth, nEscapement, nOrientation, fnWeight, fdwItalic, fdwUnderline, fdwStrikeOut, fdwCharSet, fdwOutputPrecision, fdwClipPrecision, fdwQuality, fdwPitchAndFamily, lpszFace
        ;// returns HFONT or zero for error

        WIN32API CreateFontIndirectA, pLogFont:DWORD
        ;// return hFont or zero for error

        LOGFONT STRUCT

            lfHeight         dd  0
            lfWidth          dd  0
            lfEscapement     dd  0
            lfOrientation    dd  0
            lfWeight         dd  0
            lfItalic         db  0
            lfUnderline      db  0
            lfStrikeOut      db  0
            lfCharSet        db  0
            lfOutPrecision   db  0
            lfClipPrecision  db  0
            lfQuality        db  0
            lfPitchAndFamily db  0
            lfFaceName db 32 DUP (0)

        LOGFONT ENDS

            DEFAULT_PITCH   EQU     0
            FIXED_PITCH     EQU     1
            VARIABLE_PITCH  EQU     2




        WIN32API TextOutA, hDC:DWORD, xDst:DWORD, yDst:DWORD, pText:DWORD, cbText:DWORD
        ;// returns 0 for error

        WIN32API ExtTextOutA, hdc:DWORD, X:DWORD, Y:DWORD, uOptions:DWORD, pRect:DWORD, pString:DWORD, cbCount:DWORD, pDx:DWORD
        ;// returns zero for error

            ;// option flags
            ETO_OPAQUE         EQU 0002h
            ETO_CLIPPED        EQU 0004h
            ETO_GLYPH_INDEX    EQU 0010h
            ETO_RTLREADING     EQU 0080h
            ETO_IGNORELANGUAGE EQU 1000h


        WIN32API DrawTextA, hDC:DWORD, pString:DWORD, dwCount:DWORD, pRect:DWORD, dwFormat:DWORD
        ;// returns the height of drawn text

        WIN32API DrawTextW, hDC:DWORD, pString:DWORD, dwCount:DWORD, pRect:DWORD, dwFormat:DWORD
        ;// returns the height of drawn text

        WIN32API DrawTextExA, hDC:DWORD, pString:DWORD, dwCount:DWORD,  pRect:DWORD, dwFormat:DWORD, pParam:DWORD

        ;// DrawText() Format Flags
        DT_TOP              EQU 00000000h
        DT_LEFT             EQU 00000000h
        DT_CENTER           EQU 00000001h
        DT_RIGHT            EQU 00000002h
        DT_VCENTER          EQU 00000004h
        DT_BOTTOM           EQU 00000008h
        DT_WORDBREAK        EQU 00000010h
        DT_SINGLELINE       EQU 00000020h
        DT_EXPANDTABS       EQU 00000040h
        DT_TABSTOP          EQU 00000080h
        DT_NOCLIP           EQU 00000100h
        DT_EXTERNALLEADING  EQU 00000200h
        DT_CALCRECT         EQU 00000400h
        DT_NOPREFIX         EQU 00000800h
        DT_INTERNAL         EQU 00001000h
        DT_EDITCONTROL      EQU 00002000h
        DT_PATH_ELLIPSIS    EQU 00004000h
        DT_END_ELLIPSIS     EQU 00008000h
        DT_MODIFYSTRING     EQU 00010000h
        DT_RTLREADING       EQU 00020000h
        DT_WORD_ELLIPSIS    EQU 00040000h


        DRAWTEXTPARAMS STRUCT
            cbSize          dd  sizeof  DRAWTEXTPARAMS
            dwTabLength     dd  0
            dwLeftMargin    dd  0
            dwRightMargin   dd  0
            dwLengthDrawn   dd  0
        DRAWTEXTPARAMS ENDS


        WIN32API GetTextExtentExPointA, hDC:DWORD, pszText:DWORD,   dwLength:DWORD, dwMaxExtent:DWORD, pdwFit:DWORD, paryDx:DWORD, pSize:DWORD
        ;// return non zero for success


        WIN32API GetTextMetricsA, hDC:DWORD, pTextMetric:DWORD

        TEXTMETRICA STRUCT  ;// also see 'string widths and height' fonts and text
                            ;// wingdi.h

            dwHeight            dd  0
            dwAscent            dd  0
            dwDescent           dd  0
            dwInternalLeading   dd  0
            dwExternalLeading   dd  0
            dwAveCharWidth      dd  0
            dwMaxCharWidth      dd  0
            dwWeight            dd  0
            dwOverhang          dd  0
            dwDigitizedAspectX  dd  0
            dwDigitizedAspectY  dd  0

            tmFirstChar         db  0
            tmLastChar          db  0
            tmDefaultChar       db  0
            tmBreakChar         db  0

            tmItalic            db  0
            tmUnderlined        db  0
            tmStruckOut         db  0
            tmPitchAndFamily    db  0
            tmCharSet           db  0

            align_pad   db 3 DUP (0)    ;// added by andy

        TEXTMETRICA ENDS


            ;// tmPitchAndFamily flags
            TMPF_FIXED_PITCH    EQU 01h
            TMPF_VECTOR         EQU 02h
            TMPF_TRUETYPE       EQU 04h
            TMPF_DEVICE         EQU 08h



        CHOOSEFONTA STRUCT      ;// commdlg.h

            lStructSize             dd  ?
            hwndOwner               dd  ?   ;// caller's window handle
            hDC                     dd  ?   ;// printer DC/IC or NULL
            lpLogFont               dd  ?   ;// ptr. to a LOGFONT struct
            iPointSize              dd  ?   ;// 10 * size in points of selected font
            Flags                   dd  ?   ;// enum. type flags
            rgbColors               dd  ?   ;// returned text color
            lCustData               dd  ?   ;// data passed to hook fn.
            lpfnHook                dd  ?   ;// ptr. to hook function
            lpTemplateName          dd  ?   ;// custom template name
            hInstance               dd  ?   ;// instance handle of.EXE that contains cust. dlg. template
            lpszStyle               dd  ?   ;// return the style field here must be LF_FACESIZE or bigger
            nFontType               dw  ?   ;// same value reported to the EnumFonts call back with the extra FONTTYPE_ bits added
            ___MISSING_ALIGNMENT__  dw  ?
            nSizeMin                dd  ?   ;// minimum pt size allowed &
            nSizeMax                dd  ?   ;// max pt size allowed if CF_LIMITSIZE is used

        CHOOSEFONTA ENDS

            CF_SCREENFONTS             EQU 00000001h
            CF_PRINTERFONTS            EQU 00000002h
            CF_BOTH                    EQU CF_SCREENFONTS OR CF_PRINTERFONTS
            CF_SHOWHELP                EQU 00000004h
            CF_ENABLEHOOK              EQU 00000008h
            CF_ENABLETEMPLATE          EQU 00000010h
            CF_ENABLETEMPLATEHANDLE    EQU 00000020h
            CF_INITTOLOGFONTSTRUCT     EQU 00000040h
            CF_USESTYLE                EQU 00000080h
            CF_EFFECTS                 EQU 00000100h
            CF_APPLY                   EQU 00000200h
            CF_ANSIONLY                EQU 00000400h
            CF_SCRIPTSONLY             EQU CF_ANSIONLY
            CF_NOVECTORFONTS           EQU 00000800h
            CF_NOOEMFONTS              EQU CF_NOVECTORFONTS
            CF_NOSIMULATIONS           EQU 00001000h
            CF_LIMITSIZE               EQU 00002000h
            CF_FIXEDPITCHONLY          EQU 00004000h
            CF_WYSIWYG                 EQU 00008000h    ;// must also have CF_SCREENFONTS & CF_PRINTERFONTS
            CF_FORCEFONTEXIST          EQU 00010000h
            CF_SCALABLEONLY            EQU 00020000h
            CF_TTONLY                  EQU 00040000h
            CF_NOFACESEL               EQU 00080000h
            CF_NOSTYLESEL              EQU 00100000h
            CF_NOSIZESEL               EQU 00200000h
            CF_SELECTSCRIPT            EQU 00400000h
            CF_NOSCRIPTSEL             EQU 00800000h
            CF_NOVERTFONTS             EQU 01000000h


        IMPORT32    ChooseFontA, pChooseFont



            CHOOSECOLORA STRUCT     ;// commdlg.h
                lStructSize     dd  ?   ;// DWORD
                hwndOwner       dd  ?   ;// HWND
                hInstance       dd  ?   ;// HWND
                rgbResult       dd  ?   ;// COLORREF
                lpCustColors    dd  ?   ;// COLORREF*
                dwFlags         dd  ?   ;// DWORD
                lCustData       dd  ?   ;// LPARAM
                lpfnHook        dd  ?   ;// LPCCHOOKPROC
                lpTemplateName  dd  ?   ;// LPCTSTR
            CHOOSECOLORA ENDS

            CC_RGBINIT               EQU 00000001h
            CC_FULLOPEN              EQU 00000002h
            CC_PREVENTFULLOPEN       EQU 00000004h
            CC_SHOWHELP              EQU 00000008h
            CC_ENABLEHOOK            EQU 00000010h
            CC_ENABLETEMPLATE        EQU 00000020h
            CC_ENABLETEMPLATEHANDLE  EQU 00000040h
            CC_SOLIDCOLOR            EQU 00000080h
            CC_ANYCOLOR              EQU 00000100h


        IMPORT32    ChooseColorA, pChooseColor





    ;//
    ;//  O T H E R     D C
    ;//

        WIN32API Rectangle, hDC:DWORD, L:DWORD, T:DWORD, R:DWORD, B:DWORD
        ;// returns non zero for sucess

        WIN32API RoundRect, hDC:DWORD, L:DWORD, T:DWORD, R:DWORD, B:DWORD, W:DWORD, H:DWORD
        ;// returns non zero for sucess

        WIN32API RectVisible, hDC:DWORD, pRect:DWORD
        ;// returns non-zero if any part of the rect is inside the clipping region

        WIN32API FillRect, hDC:DWORD, pRect:DWORD, hBrush:DWORD
        ;// returns non zero for sucess

        WIN32API FrameRect, hDC:DWORD, pRect:DWORD, hBrush:DWORD
        ;// returns non zero for sucess

        WIN32API InvertRect, hDC:DWORD, pRect:DWORD
        ;// returns nonzero for sucess

        WIN32API DrawFocusRect, hDC:DWORD, pRect:DWORD
        ;// returns non zero for sucess


        WIN32API DrawFrameControl, hDC:DWORD, pRect:DWORD, dwType:DWORD, dwState:DWORD
        ;// returns non_zero for sucess

            ;// type flags for DrawFrameControl

            DFC_CAPTION           EQU  1
            DFC_MENU              EQU  2
            DFC_SCROLL            EQU  3
            DFC_BUTTON            EQU  4

            ;// state flags for DrawFrameControl */

            DFCS_CAPTIONCLOSE       EQU 0000h
            DFCS_CAPTIONMIN         EQU 0001h
            DFCS_CAPTIONMAX         EQU 0002h
            DFCS_CAPTIONRESTORE     EQU 0003h
            DFCS_CAPTIONHELP        EQU 0004h

            DFCS_MENUARROW          EQU 0000h
            DFCS_MENUCHECK          EQU 0001h
            DFCS_MENUBULLET         EQU 0002h
            DFCS_MENUARROWRIGHT     EQU 0004h

            DFCS_SCROLLUP           EQU 0000h
            DFCS_SCROLLDOWN         EQU 0001h
            DFCS_SCROLLLEFT         EQU 0002h
            DFCS_SCROLLRIGHT        EQU 0003h
            DFCS_SCROLLCOMBOBOX     EQU 0005h
            DFCS_SCROLLSIZEGRIP     EQU 0008h
            DFCS_SCROLLSIZEGRIPRIGHT EQU 0010h

            DFCS_BUTTONCHECK        EQU 0000h
            DFCS_BUTTONRADIOIMAGE   EQU 0001h
            DFCS_BUTTONRADIOMASK    EQU 0002h
            DFCS_BUTTONRADIO        EQU 0004h
            DFCS_BUTTON3STATE       EQU 0008h
            DFCS_BUTTONPUSH         EQU 0010h

            DFCS_INACTIVE           EQU 0100h
            DFCS_PUSHED             EQU 0200h
            DFCS_CHECKED            EQU 0400h
            DFCS_ADJUSTRECT         EQU 2000h
            DFCS_FLAT               EQU 4000h
            DFCS_MONO               EQU 8000h


        WIN32API DrawEdge, hDC:DWORD, pRect:DWORD, dwEdge:DWORD, dwBorder:DWORD
        ;// returns non zero for sucess

            ;// dwEdge flags    ( must specify inner and outer )

            BDR_RAISEDOUTER EQU 0001h
            BDR_SUNKENOUTER EQU 0002h
            BDR_RAISEDINNER EQU 0004h
            BDR_SUNKENINNER EQU 0008h

            BDR_OUTER       EQU 0003h
            BDR_INNER       EQU 000ch
            BDR_RAISED      EQU 0005h
            BDR_SUNKEN      EQU 000ah

            EDGE_RAISED  EQU   (BDR_RAISEDOUTER OR BDR_RAISEDINNER)
            EDGE_SUNKEN  EQU   (BDR_SUNKENOUTER OR BDR_SUNKENINNER)
            EDGE_ETCHED  EQU   (BDR_SUNKENOUTER OR BDR_RAISEDINNER)
            EDGE_BUMP    EQU   (BDR_RAISEDOUTER OR BDR_SUNKENINNER)

            ;// dwBorder flags

            BF_LEFT         EQU 0001h
            BF_TOP          EQU 0002h
            BF_RIGHT        EQU 0004h
            BF_BOTTOM       EQU 0008h
            BF_DIAGONAL     EQU 0010h
            BF_MIDDLE       EQU 0800h  ;// Fill in the middle
            BF_SOFT         EQU 1000h  ;// For softer buttons
            BF_ADJUST       EQU 2000h  ;// Calculate the space left over
            BF_FLAT         EQU 4000h  ;// For flat rather than 3D borders
            BF_MONO         EQU 8000h  ;// For monochrome borders

            BF_RECT         EQU BF_LEFT OR BF_TOP OR BF_RIGHT OR BF_BOTTOM


    ;//
    ;//  B R U S H E S
    ;//

        LOGBRUSH STRUCT

            lbStyle dd 0
            lbColor dd 0
            lbHatch dd 0

        LOGBRUSH ENDS

        ;// brush styles
        BS_SOLID         EQU   0
        BS_HOLLOW        EQU   1
        BS_HATCHED       EQU   2
        BS_PATTERN       EQU   3
        BS_INDEXED       EQU   4
        BS_DIBPATTERN    EQU   5
        BS_DIBPATTERNPT  EQU   6
        BS_PATTERN8X8    EQU   7
        BS_DIBPATTERN8X8 EQU   8
        BS_MONOPATTERN   EQU   9

        ;// Hatch Styles */
        HS_HORIZONTAL    EQU   0
        HS_VERTICAL      EQU   1
        HS_FDIAGONAL     EQU   2
        HS_BDIAGONAL     EQU   3
        HS_CROSS         EQU   4
        HS_DIAGCROSS     EQU   5


        WIN32API CreateBrushIndirect, pLogBrush:DWORD
        ;// returns a brush handle, or null for error

        WIN32API CreateSolidBrush, dwColor:DWORD
        ;// returns a brush handle, or null for error



    ;//
    ;// P E N S
    ;//

        WIN32API CreatePen, fnPenStyle:DWORD, dwWidth:DWORD, crColor :DWORD
        ;// returns hPen or NULL for error

        ;// pen styles
        PS_SOLID        EQU    0
        PS_DASH         EQU    1
        PS_DOT          EQU    2
        PS_DASHDOT      EQU    3
        PS_DASHDOTDOT   EQU    4
        PS_NULL         EQU    5
        PS_INSIDEFRAME  EQU    6
        PS_USERSTYLE    EQU    7
        PS_ALTERNATE    EQU    8




    ;//
    ;// L I N E S  for D C
    ;//
        WIN32API MoveToEx, hDC:DWORD, X:DWORD, Y:DWORD, pPrevPoint:DWORD
        ;// returns non zero for sucess

        WIN32API LineTo, hDC:DWORD, X:DWORD, Y:DWORD
        ;// returns non zero for sucess


        WIN32API Polygon, hDC:DWORD, pPoints:DWORD, dwCount:DWORD
        ;// return non-zero for success

        WIN32API PolyDraw, hDC:DWORD, pPoints:DWORD, pcTypes:DWORD, dwCount:DWORD
        ;// returns non zero for success

        ;// PolyDraw and GetPath point types
        PT_CLOSEFIGURE EQU 01
        PT_LINETO      EQU 02
        PT_BEZIERTO    EQU 04
        PT_MOVETO      EQU 06

        WIN32API Ellipse, hDC:DWORD, X1:DWORD, Y1:DWORD, X2:DWORD, Y2:DWORD
        ;// returns nonzero for sucess

        WIN32API Polyline, hDC:DWORD, pPoints:DWORD, numPoints:DWORD
        ;// returns non zero for sucess

        WIN32API Pie, hDC:DWORD,    dwLeftRect:DWORD, dwTopRect:DWORD, dwRightRect:DWORD, dwBottomRect:DWORD,   dwXRadial1:DWORD, dwYRadial1:DWORD, dwXRadial2:DWORD, dwYRadial2:DWORD
        ;// returns non zero for sucess
        ;// draws counter clockwise

        IMPORT32 AngleArc, hDC, X, Y, radius, angle0, angle1


        WIN32API PolyBezier, hDC:DWORD, pPoints:DWORD, numPoints:DWORD
        ;// returns non zero for sucess




    ;//
    ;//     single points
    ;//


        WIN32API SetPixel, hDC:DWORD, X:DWORD, Y:DWORD, color:DWORD

        WIN32API SetPixelV, hDC:DWORD, X:DWORD, Y:DWORD, color:DWORD






    ;//
    ;//     P A T H S
    ;//


        WIN32API BeginPath, hDC:DWORD
        ;// returns non zero for sucess

        WIN32API EndPath, hDC:DWORD
        ;// returns non zero for sucess

        WIN32API FillPath, hDC:DWORD
        ;// returns non zero for sucess

        WIN32API StrokePath, hDC:DWORD
        ;// returns non zero for sucess

        WIN32API StrokeAndFillPath, hDC:DWORD
        ;// returns non zero for sucess

        WIN32API PathToRegion, hDC:DWORD
        ;// returns hRgn or zero for error





    ;//
    ;// P A I N T   H A N D L I N G
    ;//


        PAINTSTRUCT STRUCT
            hDC         dd  ?   ;// device context to draw in
            bErase      dd  ?   ;// true if erase background
            rcPaint    RECT {} ;//
            reserved  dd 10 DUP (?)
        PAINTSTRUCT endS

        WIN32API InvalidateRect, hWnd:DWORD, pRect:DWORD, bErase:DWORD
        ;// returns 0 for error

        WIN32API ValidateRect, hWnd:DWORD, pRect:DWORD
        ;// returns 0 for error

        WIN32API GetUpdateRect, hWnd:DWORD, pRect:DWORD, bErase:DWORD
        ;// returns 0 if no update region

        WIN32API BeginPaint, hWnd:DWORD, pPaintStruct:DWORD
        ;// returns hDC or null for error

        WIN32API EndPaint, hWnd:DWORD, pPaintStruct:DWORD
        ;// return true if successful

        WIN32API UpdateWindow, hWnd:DWORD
        ;// return zero for error



;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;//
;////    F I L E S  A N D  D I R E C T O R I E S
;////

        WIN32API CloseHandle, hHandle:DWORD
        ;// returns zero for error

        WIN32API DuplicateHandle, hSourceProcessHandle:DWORD, hSourceHandle:DWORD, hTargetProcessHandle:DWORD, pTargetHandle:DWORD, dwDesiredAccess:DWORD, bInheritHandle:DWORD, dwOptions:DWORD

        DUPLICATE_CLOSE_SOURCE  EQU 00000001h
        DUPLICATE_SAME_ACCESS   EQU 00000002h



    INVALID_HANDLE_VALUE EQU -1

    ;//
    ;//  directory
    ;//

        WIN32API CreateDirectoryA, pPathName:DWORD, pSecurityAttributes:DWORD
        ;// returns non-zero for success

        WIN32API GetCurrentDirectoryA, nBufferLength:DWORD, pBuffer:DWORD
        ;// returns number of chars or zero for error

    ;//
    ;// general file operations
    ;//

        WIN32API CreateFileA, pFileName:DWORD, dwDesiredAccess:DWORD, dwShareMode:DWORD, pSecurityAttributes:DWORD,  dwCreationDistribution:DWORD,  dwFlagsAndAttributes:DWORD,  hTemplateFile:DWORD
        ;// return file handle or INVALID_HANDLE_VALUE

        WIN32API WriteFile, hFile:DWORD, pBuffer:DWORD, nNumberOfBytesToWrite:DWORD, pNumberOfBytesWritten:DWORD,   pOverlapped:DWORD
        ;// returns zero for error

        WIN32API MoveFileA, pExisting:DWORD, pNewName:DWORD
        ;// returns zero for error

        WIN32API CopyFileA, pszFrom:DWORD, pszTo:DWORD, bExists:DWORD
        ;// returns non zero if sucessful

        WIN32API DeleteFileA, pFileName:DWORD
        ;// return non zero for success



        WIN32API SetFilePointer, hFile:DWORD, dwDistanceToMove:DWORD, pDistanceToMoveHigh:DWORD, dwMoveMethod:DWORD
        ;// returns -1 for error, or the file position

            ;// dwMoveMethod values
            FILE_BEGIN     EQU   0
            FILE_CURRENT   EQU   1
            FILE_END       EQU   2

        WIN32API ReadFile, hFile:DWORD,pBuffer:DWORD, nNumberOfBytesToRead:DWORD,pNumberOfBytesRead:DWORD, pOverlapped:DWORD
        ;// returns zero for error

        WIN32API FlushFileBuffers, hFile:DWORD
        ;// returns nonzero for success

        WIN32API SetEndOfFile, hFile:DWORD
        ;// returns non zero for sucesss

    ;//
    ;// overlapped for asynchronis operation
    ;//

        OVERLAPPED STRUCT
            dwInternal      dd  0
            dwInternalHigh  dd  0
            dwOffset        dd  0
            dwOffsetHigh    dd  0
            hEvent          dd  0
        OVERLAPPED ENDS

        WIN32API CancelIo, hFile:DWORD
        ;// returns non zero for sucess


    ;//
    ;//  file attribute functions
    ;//

        WIN32API GetFileAttributesA, pFileName:DWORD
        ;// returns attributes or -1 for error

        WIN32API GetFileSize, hFile:DWORD, pdwHighSize:DWORD
        ;// returns low DWORD of size
        ;// returns -1 for error, most of the time



    ;//
    ;// various file flags
    ;//



        ;// desired access
        GENERIC_READ     EQU 80000000h
        GENERIC_WRITE    EQU 40000000h
        GENERIC_EXECUTE  EQU 20000000h
        GENERIC_ALL      EQU 10000000h


        ;// share mode
        FILE_SHARE_NONE    EQU 00000000h
        FILE_SHARE_READ    EQU 00000001h
        FILE_SHARE_WRITE   EQU 00000002h
        FILE_SHARE_DELETE  EQU 00000004h


        ;// creation distribution
        CREATE_NEW         EQU 1
        CREATE_ALWAYS      EQU 2
        OPEN_EXISTING      EQU 3
        OPEN_ALWAYS        EQU 4
        TRUNCATE_EXISTING  EQU 5

        ;//flags and attributes
        FILE_FLAG_WRITE_THROUGH     EQU 80000000h
        FILE_FLAG_OVERLAPPED        EQU 40000000h
        FILE_FLAG_NO_BUFFERING      EQU 20000000h
        FILE_FLAG_RANDOM_ACCESS     EQU 10000000h
        FILE_FLAG_SEQUENTIAL_SCAN   EQU 08000000h
        FILE_FLAG_DELETE_ON_CLOSE   EQU 04000000h
        FILE_FLAG_BACKUP_SEMANTICS  EQU 02000000h
        FILE_FLAG_POSIX_SEMANTICS   EQU 01000000h

        FILE_ATTRIBUTE_READONLY     EQU 00000001h
        FILE_ATTRIBUTE_HIDDEN       EQU 00000002h
        FILE_ATTRIBUTE_SYSTEM       EQU 00000004h
        FILE_ATTRIBUTE_DIRECTORY    EQU 00000010h
        FILE_ATTRIBUTE_ARCHIVE      EQU 00000020h
        FILE_ATTRIBUTE_NORMAL       EQU 00000080h
        FILE_ATTRIBUTE_TEMPORARY    EQU 00000100h
        FILE_ATTRIBUTE_COMPRESSED   EQU 00000800h
        FILE_ATTRIBUTE_OFFLINE      EQU 00001000h

        SECURITY_ANONYMOUS      EQU 00000000h
        SECURITY_IDENTIFICATION EQU 00010000h
        SECURITY_IMPERSONATION  EQU 00020000h
        SECURITY_DELEGATION     EQU 00030000h

        SECURITY_CONTEXT_TRACKING EQU 00040000h
        SECURITY_EFFECTIVE_ONLY   EQU 00080000h

        SECURITY_SQOS_PRESENT     EQU 00100000h
        SECURITY_VALID_SQOS_FLAGS EQU 001F0000h


    ;//
    ;//  SEARCHING FOR FILES
    ;//
        MAX_PATH EQU 260


        WIN32API FindFirstFileA, pFileName:DWORD, pFindFileData:DWORD
        ;// returns a findHandle or INVALID_HANDLE_VALUE

        WIN32API FindNextFileA, hFindFile:DWORD, pFindFileData:DWORD
        ;// return non-zero for success

        WIN32API FindClose, hFindFile:DWORD
        ;// return non-zero for success

        ;// WIN32_FIND_DATA
        WIN32_FIND_DATA STRUCT
            dwFileAttributes    DD  ?  ;// see above    FILE_ATTRIBUTE_DIRECTORY
            ftCreationTime      DQ  ?
            ftLastAccessTime    DQ  ?
            ftLastWriteTime     DQ  ?
            nFileSizeHigh       DD  ?
            nFileSizeLow        DD  ?
            qwReserved0         DQ  ?
            szFileName      DB MAX_PATH DUP (?)
            szAlternateFileName DB 16 DUP (?)       ;// changed from 14 to 16 on jan 14, 2006
        WIN32_FIND_DATA ENDS




    ;//
    ;//  temporary files
    ;//

        WIN32API GetTempPathA, dwBufferLength:DWORD, pBuffer:DWORD
        ;// returns length of string or zero for error

        WIN32API GetTempFileNameA , pszPathName:DWORD, pszPrefixString:DWORD, dwUnique:DWORD, pTempFileName:DWORD
        ;// returns the unique number used



    ;//
    ;// Other file operations
    ;//

        WIN32API GetFullPathNameA, pFileName:DWORD, nBufferLength:DWORD, pBuffer:DWORD, ppFilePart:DWORD
        ;// returns length of file name, or the number required, or zero for error


        WIN32API SetCurrentDirectoryA, pBuffer:DWORD

    comment ~ /* oops
        WIN32API GetCurrentDirectoryA, pBuffer:DWORD, dwLength:DWORD
    */ comment ~

        WIN32API GetDiskFreeSpaceA, pDiskName:DWORD, pSectorsPerCluster:DWORD, pBytesPerSector:DWORD, pNumFreeClusters:DWORD, pTotalNumClusters:DWORD


    ;//
    ;// file mappings       winbase.h
    ;//


    WIN32API CreateFileMappingA, hFile:DWORD, pFileMappingAttributes:DWORD, flProtect:DWORD, dwMaximumSizeHigh:DWORD, dwMaximumSizeLow:DWORD, pName:DWORD
    WIN32API OpenFileMappingA, dwDesiredAccess:DWORD, bInheritHandle:DWORD, pName:DWORD
    WIN32API MapViewOfFile, hFileMappingObject:DWORD, dwDesiredAccess:DWORD, dwFileOffsetHigh:DWORD, dwFileOffsetLow:DWORD, dwNumberOfBytesToMap:DWORD
    WIN32API UnmapViewOfFile, pBaseAddress:DWORD

        PAGE_NOACCESS          EQU 01h
        PAGE_READONLY          EQU 02h
        PAGE_READWRITE         EQU 04h
        PAGE_WRITECOPY         EQU 08h
        PAGE_EXECUTE           EQU 10h
        PAGE_EXECUTE_READ      EQU 20h
        PAGE_EXECUTE_READWRITE EQU 40h
        PAGE_EXECUTE_WRITECOPY EQU 80h
        PAGE_GUARD            EQU 100h
        PAGE_NOCACHE          EQU 200h
        MEM_COMMIT           EQU 1000h
        MEM_RESERVE          EQU 2000h
        MEM_DECOMMIT         EQU 4000h
        MEM_RELEASE          EQU 8000h
        MEM_FREE            EQU 10000h
        MEM_PRIVATE         EQU 20000h
        MEM_MAPPED          EQU 40000h
        MEM_RESET           EQU 80000h
        MEM_TOP_DOWN       EQU 100000h
        SEC_FILE           EQU 800000h
        SEC_IMAGE         EQU 1000000h
        SEC_RESERVE       EQU 4000000h
        SEC_COMMIT        EQU 8000000h
        SEC_NOCACHE      EQU 10000000h
        MEM_IMAGE        EQU SEC_IMAGE

        SECTION_QUERY       EQU 0001h
        SECTION_MAP_WRITE   EQU 0002h
        SECTION_MAP_READ    EQU 0004h
        SECTION_MAP_EXECUTE EQU 0008h
        SECTION_EXTEND_SIZE EQU 0010h

        SECTION_ALL_ACCESS  EQU STANDARD_RIGHTS_REQUIRED OR SECTION_QUERY OR SECTION_MAP_WRITE OR SECTION_MAP_READ OR SECTION_MAP_EXECUTE OR SECTION_EXTEND_SIZE

        FILE_MAP_COPY       EQU SECTION_QUERY
        FILE_MAP_WRITE      EQU SECTION_MAP_WRITE
        FILE_MAP_READ       EQU SECTION_MAP_READ
        FILE_MAP_ALL_ACCESS EQU SECTION_ALL_ACCESS






;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////
;//
;//
;////     D E B U G G I N G   S U P P O R T
;//


    WIN32API OutputDebugStringA, pOutputString:DWORD

    WIN32API GetLastError

    WIN32API Beep, freq:DWORD, dur:DWORD
    ;// parameters ignored in Win95
    ;// returns 0 for error

    WIN32API FlashWindow, hWnd:DWORD, bInvert:DWORD
    ;// returns true if window was active





;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////
;//
;//
;////     T I M E
;//



    WIN32API SetTimer, hWnd:DWORD, dwIDEvent:DWORD, dwElapse:DWORD, pTimerFunc:DWORD
    ;// returns a timer id

    WIN32API KillTimer, hWnd:DWORD, dwTimerID:DWORD
    ;// returns non zero for sucess



    WIN32API GetTickCount
    ;// returns number of milliseconds since windows started



    WIN32API timeBeginPeriod, dwRes:DWORD
    ;// return zero for sucess

    WIN32API timeEndPeriod, dwRes:DWORD
    ;// return zero for sucess


    WIN32API timeSetEvent, uDelay:DWORD, uResolution:DWORD, pTimeProc:DWORD, dwUser:DWORD, fuEvent:DWORD
    ;// returns timerID or zero for error

        ;// flags for fuEvent parameter of timeSetEvent() function */
        TIME_ONESHOT    EQU 0000
        TIME_PERIODIC   EQU 0001

    WIN32API timeKillEvent, ID:DWORD
    ;// returns TIMEERR_NOERR for success

    ;// this is the callback and must be defined by the user
    WIN32API TimeProc, uID:DWORD, uMsg:DWORD, dwUser:DWORD, dw1:DWORD, dw2:DWORD
    ;// no return value


    WIN32API timeGetTime
    ;// returns milliseconds

    WIN32API timeGetDevCaps, pTimeCaps:DWORD, dwSize:DWORD
    ;// returns TIMEERR_NOERR for sucess

    TIMECAPS STRUCT

        dwMinResolution dd 0
        dwMaxResolution dd 0

    TIMECAPS ENDS



    SYSTEMTIME STRUCT
        wYear       WORD    ?
        wMonth      WORD    ?
        wDayOfWeek  WORD    ?
        wDay        WORD    ?
        wHour       WORD    ?
        wMinute     WORD    ?
        wSecond     WORD    ?
        wMilliseconds WORD  ?
    SYSTEMTIME  ENDS

    ;// FILETIME QWORD

    WIN32API FileTimeToSystemTime, pFileTime:DWORD, pSystemTime:DWORD
    WIN32API SystemTimeToFileTime, pSystemTime:DWORD, pFileTime:DWORD
    ;// return non zero for sucess

    WIN32API FileTimeToLocalFileTime, p_filetime_sys:DWORD, p_filetime_loc:DWORD


    TIME_ZONE_INFORMATION STRUCT        ;// from winbase.h
        Bias            dd  ?           ;// in minutes
        StandardName    dw  32 DUP (?)
        StandardDate    SYSTEMTIME {}
        StandardBias    dd  ?
        DaylightName    dw  32 DUP (?)
        DaylightDate    SYSTEMTIME {}
        DaylightBias    dd  ?
    TIME_ZONE_INFORMATION ENDS

    IMPORT32 GetTimeZoneInformation, pTZI
    ;// returns one of these values

    TIME_ZONE_ID_UNKNOWN  EQU 0 ;// The operating system cannot determine the current time zone. This is usually because a previous call to the SetTimeZoneInformation function supplied only the bias (and no transition dates).
    TIME_ZONE_ID_STANDARD EQU 1 ;// The operating system is operating in the range covered by the StandardDate member of the structure pointed to by the lpTimeZoneInformation parameter.
    TIME_ZONE_ID_DAYLIGHT EQU 2 ;// The operating system is operating in the range covered by the DaylightDate member of the structure pointed to by the lpTimeZoneInformation parameter.



    IMPORT32 GetSystemTime, pSystemTime
    IMPORT32 GetLocalTime, pSystemTime





;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;//                                                 see mmsystem.h
;//   M M S Y S T E M
;//
;//   W A V E F O R M   A U D I O
;//


    ;//
    ;// error handling   values of MMRESULT
    ;//
        MMSYSERR_NOERROR      EQU 0   ;// no error
        MMSYSERR_ERROR        EQU 1   ;// unspecified error
        MMSYSERR_BADDEVICEID  EQU 2   ;// device ID out of range
        MMSYSERR_NOTENABLED   EQU 3   ;// driver failed enable
        MMSYSERR_ALLOCATED    EQU 4   ;// device already allocated
        MMSYSERR_INVALHANDLE  EQU 5   ;// device handle is invalid
        MMSYSERR_NODRIVER     EQU 6   ;// no device driver present
        MMSYSERR_NOMEM        EQU 7   ;// memory allocation error
        MMSYSERR_NOTSUPPORTED EQU 8   ;// function isn't supported
        MMSYSERR_BADERRNUM    EQU 9   ;// error value out of range
        MMSYSERR_INVALFLAG    EQU 10   ;// invalid flag passed
        MMSYSERR_INVALPARAM   EQU 11   ;// invalid parameter passed
        MMSYSERR_HANDLEBUSY   EQU 12   ;// handle being used simultaneously on another thread (eg callback)
        MMSYSERR_INVALIDALIAS EQU 13   ;// specified alias not found
        MMSYSERR_BADDB        EQU 14   ;// bad registry database
        MMSYSERR_KEYNOTFOUND  EQU 15   ;// registry key not found
        MMSYSERR_READERROR    EQU 16   ;// registry read error
        MMSYSERR_WRITEERROR   EQU 17   ;// registry write error
        MMSYSERR_DELETEERROR  EQU 18   ;// registry delete error
        MMSYSERR_VALNOTFOUND  EQU 19   ;// registry value not found
        MMSYSERR_NODRIVERCB   EQU 20   ;// driver does not call DriverCallback
        MMSYSERR_LASTERROR    EQU 20   ;// last error in range

        WAVERR_BADFORMAT    EQU 32 ;// unsupported wave format
        WAVERR_STILLPLAYING EQU 33 ;// still something playing
        WAVERR_UNPREPARED   EQU 34 ;// header not prepared
        WAVERR_SYNC         EQU 35 ;// device is synchronous
        WAVERR_LASTERROR    EQU 36 ;// last error in range


        WIN32API waveOutGetErrorText, mmrError:DWORD, pText:DWORD, cbText:DWORD
        ;// returns MMRESULT


    ;//
    ;// devices
    ;//

        MAXPNAMELEN             EQU 32
        MAX_JOYSTICKOEMVXDNAME  EQU 260

        WAVEOUTCAPS STRUCT
            wMid    dw 0
            wPid    dw 0
            vDriverVersion  dd 0
            szPname     db MAXPNAMELEN DUP (0)
            dwFormats   dd 0
            wChannels   dw 0
            wReserved1  dw 0
            dwSupport   dd 0
        WAVEOUTCAPS endS

        ;// defines for dwFormat field of WAVEINCAPS and WAVEOUTCAPS
        WAVE_INVALIDFORMAT  EQU 00000000h ;// invalid format
        WAVE_FORMAT_1M08    EQU 00000001h ;// 11.025 kHz, Mono,   8-bit
        WAVE_FORMAT_1S08    EQU 00000002h ;// 11.025 kHz, Stereo, 8-bit
        WAVE_FORMAT_1M16    EQU 00000004h ;// 11.025 kHz, Mono,   16-bit
        WAVE_FORMAT_1S16    EQU 00000008h ;// 11.025 kHz, Stereo, 16-bit
        WAVE_FORMAT_2M08    EQU 00000010h ;// 22.05  kHz, Mono,   8-bit
        WAVE_FORMAT_2S08    EQU 00000020h ;// 22.05  kHz, Stereo, 8-bit
        WAVE_FORMAT_2M16    EQU 00000040h ;// 22.05  kHz, Mono,   16-bit
        WAVE_FORMAT_2S16    EQU 00000080h ;// 22.05  kHz, Stereo, 16-bit
        WAVE_FORMAT_4M08    EQU 00000100h ;// 44.1   kHz, Mono,   8-bit
        WAVE_FORMAT_4S08    EQU 00000200h ;// 44.1   kHz, Stereo, 8-bit
        WAVE_FORMAT_4M16    EQU 00000400h ;// 44.1   kHz, Mono,   16-bit
        WAVE_FORMAT_4S16    EQU 00000800h ;// 44.1   kHz, Stereo, 16-bit

        ;// flags for dwSupport field of WAVEOUTCAPS
        WAVECAPS_PITCH          EQU 0001h ;// supports pitch control */
        WAVECAPS_PLAYBACKRATE   EQU 0002h ;// supports playback rate control */
        WAVECAPS_VOLUME         EQU 0004h ;// supports volume control */
        WAVECAPS_LRVOLUME       EQU 0008h ;// separate left-right volume control */
        WAVECAPS_SYNC           EQU 0010h ;//
        WAVECAPS_SAMPLEACCURATE EQU 0020h ;//
        WAVECAPS_DIRECTSOUND    EQU 0040h ;//

        WIN32API waveOutGetNumDevs
        ;// returns number of devices

        WIN32API waveOutGetDevCapsA, uDeviceID:DWORD, pWaveOutCaps:DWORD, cbWaveOutCaps:DWORD
        ;// returns an MMRESULT

        WAVE_MAPPER  EQU 0FFFFFFFFh ;// devID


        WAVEFORMATEX STRUCT
            wFormatTag       dw 0
            wChannels        dw 0
            dwSamplesPerSec  dd 0
            dwAvgBytesPerSec dd 0
            wBlockAlign      dw 0
            wBitsPerSample   dw 0
            cbSizeExtra      dw 0
        WAVEFORMATEX ENDS
        ;// IMPORTATNT !! this struct is NOT dword aligned


        ;// values for wFormatTag
        WAVE_FORMAT_PCM   EQU 1


        WIN32API waveOutOpen, phWaveOut:DWORD, uDeviceID:DWORD, pWaveFormatEx:DWORD, dwCallback:DWORD, dwCallbackInstance:DWORD, dwOpenFlags:DWORD
        ;// returns MMRESULT

            ;// flags for dwFlags parameter in waveOutOpen() and waveInOpen()
            WAVE_FORMAT_QUERY         EQU 0001h
            WAVE_ALLOWSYNC            EQU 0002h
            WAVE_MAPPED               EQU 0004h
            WAVE_FORMAT_DIRECT        EQU 0008h


            ;// open callback flags
            CALLBACK_NULL       EQU 000000h    ;// no callback
            CALLBACK_WINDOW     EQU 010000h    ;// dwCallback is a HWND
            CALLBACK_TASK       EQU 020000h    ;// dwCallback is a HTASK
            CALLBACK_FUNCTION   EQU 030000h    ;// dwCallback is a FARPROC
            CALLBACK_THREAD     EQU 020000h    ;// thread ID replaces 16 bit task
            CALLBACK_EVENT      EQU 050000h    ;// dwCallback is an EVENT Handle


        WIN32API waveOutClose, hWaveOut:DWORD
        ;// returns MMRESULT



    ;//
    ;// user defined callback prototype
    ;//

        WIN32API waveOutProc, hWaveOut:DWORD, uMsg:DWORD, dwInstance:DWORD, dwParam1:DWORD, dwParam2:DWORD
        ;// this is to be implemented by the user.
        ;// return nothing

        ;// note: SAVE EBX. other wise many bizarre things happen

        ;// wave out callback messages

        ;// waveform output */
        WOM_OPEN   EQU 03BBh
        WOM_CLOSE  EQU 03BCh
        WOM_DONE   EQU 03BDh


        WIN32API waveInProc, hWaveIn:DWORD, uMsg:DWORD, dwInstance:DWORD, dwParam1:DWORD, dwParam2:DWORD
        ;// this is to be implemented by the user.
        ;// return nothing

        ;// note: SAVE EBX. other wise many bizarre things happen

        ;// wave in callback messages
        ;// waveform input */
        WIM_OPEN   EQU 03BEh
        WIM_CLOSE  EQU 03BFh
        WIM_DATA   EQU 03C0h


    ;//
    ;// playing
    ;//
        WAVEHDR STRUCT
            pData           dd ?
            dwBufferLength  dd ?
            dwBytesRecorded dd ?
            dwUser          dd ?
            dwFlags         dd ?
            dwLoops         dd ?
            pNext           dd ?
            reserved        dd ?
        WAVEHDR ENDS

        ;// dwFlags
        WHDR_NONE       EQU 00000000h ;// no flags
        WHDR_DONE       EQU 00000001h ;// done bit
        WHDR_PREPARED   EQU 00000002h ;// set if this header has been prepared
        WHDR_BEGINLOOP  EQU 00000004h ;// loop start block
        WHDR_ENDLOOP    EQU 00000008h ;// loop end block
        WHDR_INQUEUE    EQU 00000010h ;// reserved for driver


        ;// wave hdrs are often used in an array. So here's two macros
        SIZE_WAVEHDR EQU 32
        WAVEHDR_COMPUTE_OFFSET MACRO index:REQ, reg:REQ
        ;// this macro computes resulting offset from 0000
        ;// of the record specified by index
        ;// and returns the value in reg
        ;//
            mov reg, index
            shl reg, 5
        ENDM

        WAVEHDR_COMPUTE_ADDRESS MACRO Adr:REQ, index:REQ, reg:REQ
        ;// this macro computes resulting address of the
        ;// of the record specified by index
        ;// and returns the value in reg
        ;// assumes the reg
        ;//
            WAVEHDR_COMPUTE_OFFSET index, reg
            add reg, Adr
            ASSUME reg:PTR WAVEHDR
        ENDM


        WIN32API waveOutPrepareHeader, hWaveOut:DWORD, pWaveHeader:DWORD, cbSizeWaveHeader:DWORD
        ;// returns MMRESULT

        WIN32API waveOutWrite, hWaveOut:DWORD, pWaveHdr:DWORD, cbSizeWaveHeader:DWORD
        ;// returns MMRESULT

        WIN32API waveOutUnprepareHeader, hWaveOut:DWORD, pWaveHdr:DWORD, cbSizeWaveHeader:DWORD
        ;// returns MMRESULT

        WIN32API waveOutPause, hWaveOut:DWORD
        ;// returns MMRESULT

        WIN32API waveOutRestart, hWaveOut:DWORD
        ;// returns MMRESULT

        WIN32API waveOutReset, hWaveOut:DWORD
        ;// returns MMRESULT



    ;//
    ;// recording
    ;//

        WAVEINCAPS STRUCT
            wMid    dw  0
            wPid    dw  0
            vDriverVersion  dd 0
            szPname     db MAXPNAMELEN DUP (0)
            dwFormats   dd 0
            wChannels   dw 0
            wReserved1  dw 0
        WAVEINCAPS ENDS

        WIN32API waveInGetNumDevs
        ;// returns number of devices

        WIN32API waveInGetDevCapsA, uDeviceID:DWORD, pWaveInCaps:DWORD, cbWaveInCaps:DWORD
        ;// returns an MMRESULT

        WIN32API waveInOpen, phWaveIn:DWORD, uDeviceID:DWORD, pWaveFormatEx:DWORD,  dwCallback:DWORD, dwCallbackInstance:DWORD, dwOpenFlags:DWORD

        WIN32API waveInStart, hWaveIn:DWORD

        WIN32API waveInPrepareHeader, hWaveIn:DWORD, pWaveHdr:DWORD, cbSizeWaveHeader:DWORD

        WIN32API waveInAddBuffer, hWaveIn:DWORD, pWaveHdr:DWORD, cbSizeWaveHeader:DWORD

        WIN32API waveInUnprepareHeader, hWaveIn:DWORD, pWaveHdr:DWORD, cbSizeWaveHeader:DWORD

        WIN32API waveInReset, hWaveIn:DWORD

        WIN32API waveInClose, hWaveIn:DWORD





    ;//
    ;// TIMING
    ;//

        MMTIME STRUCT
            dwType  dd  0   ;// see flags below
            dwDat1  dd  0   ;// this returns in various formats, see help section
            dwDat2  dd  0   ;//
            dwDat3 dd 0
        MMTIME ENDS

        ;// types for wType field in MMTIME STRUCT */
        TIME_MS         EQU 0001h  ;// time in milliseconds
        TIME_SAMPLES    EQU 0002h  ;// number of wave samples
        TIME_BYTES      EQU 0004h  ;// current byte offset
        TIME_SMPTE      EQU 0008h  ;// SMPTE time
        TIME_MIDI       EQU 0010h  ;// MIDI time
        TIME_TICKS      EQU 0020h  ;// Ticks within MIDI stream

        WIN32API waveOutGetPosition, hWaveOut:DWORD, pMMTime:DWORD, sizMMTime:DWORD
        ;// returns an MMRESULT

        WIN32API waveInGetPosition, hWaveIn:DWORD, pMMTime:DWORD, sizMMTime:DWORD
        ;// returns an MMRESULT



    ;//////////////////////////////////////////////////////////////////
    ;//
    ;// JOYSTICK        directx can monitor upto 16 joysticks
    ;//                 each joystick may have 6 axises and 32 buttons

            ;// joystick error return values

            JOYERR_NOERROR      EQU  (0)                  ;// no error

            JOYERR_BASE         EQU  00A0h  ;// 160
            JOYERR_PARMS        EQU  (JOYERR_BASE+5)      ;// bad parameters
            JOYERR_NOCANDO      EQU  (JOYERR_BASE+6)      ;// request not completed
            JOYERR_UNPLUGGED    EQU  (JOYERR_BASE+7)      ;// joystick is unplugged


        IMPORT32 joyGetNumDevs

            ;// returns only the number of drivers
            ;// each device must be queried by joyGetPosEx to determine if connected

        IMPORT32 joyGetDevCapsA, dwJoyID, pJoyCapsA, dwSizeofJoyCapsA

            ;// returm MMRESULT
            ;// fills in a JOYCAPSA struct

            JOYCAPSA    STRUCT
                wMid        dw ?    ;// manufacturer ID
                wPid        dw ?    ;// product ID
                szPname db MAXPNAMELEN DUP(?)   ;// product name (NULL terminated string)
                wXmin       dd ?    ;// minimum x position value
                wXmax       dd ?    ;// maximum x position value
                wYmin       dd ?    ;// minimum y position value
                wYmax       dd ?    ;// maximum y position value
                wZmin       dd ?    ;// minimum z position value
                wZmax       dd ?    ;// maximum z position value
                wNumButtons dd ?    ;// number of buttons
                wPeriodMin  dd ?    ;// minimum message period when captured
                wPeriodMax  dd ?    ;// maximum message period when captured
                wRmin       dd ?    ;// minimum r position value
                wRmax       dd ?    ;// maximum r position value
                wUmin       dd ?    ;// minimum u (5th axis) position value
                wUmax       dd ?    ;// maximum u (5th axis) position value
                wVmin       dd ?    ;// minimum v (6th axis) position value
                wVmax       dd ?    ;// maximum v (6th axis) position value
                wCaps       dd ?    ;// joystick capabilites
                wMaxAxes    dd ?    ;// maximum number of axes supported
                wNumAxes    dd ?    ;// number of axes in use
                wMaxButtons dd ?    ;// maximum number of buttons supported
                szRegKey db MAXPNAMELEN DUP(?)  ;// registry key
                szOEMVxD db MAX_JOYSTICKOEMVXDNAME DUP (?) ;// OEM VxD in use
            JOYCAPSA    ENDS

                ;// joystick ID constants
                JOYSTICKID1         EQU 0
                JOYSTICKID2         EQU 1

                ;// JOYCAPSA.wCaps driver capabilites
                JOYCAPS_HASZ        EQU 0001h
                JOYCAPS_HASR        EQU 0002h
                JOYCAPS_HASU        EQU 0004h
                JOYCAPS_HASV        EQU 0008h
                JOYCAPS_HASPOV      EQU 0010h
                JOYCAPS_POV4DIR     EQU 0020h
                JOYCAPS_POVCTS      EQU 0040h


        IMPORT32 joyGetPosEx, uJoyID, pJoyInfoEx

            ;// returns zero if successful
            ;// mm sys error otherwise

            ;// fills in JOYINFOEX struct

            JOYINFOEX STRUCT

                dwSize      dd  ?   ;// size of structure
                dwFlags     dd  ?   ;// flags to indicate what to return

                dwXpos      dd  ?   ;// x position
                dwYpos      dd  ?   ;// y position
                dwZpos      dd  ?   ;// z position
                dwRpos      dd  ?   ;// rudder/4th axis position
                dwUpos      dd  ?   ;// 5th axis position
                dwVpos      dd  ?   ;// 6th axis position

                dwButtons   dd  ?   ;// bit mask of button states
                dwButtonNumber dd ? ;// current button number pressed
                dwPOV       dd  ?   ;// point of view state

                dwReserved1 dd  ?   ;// reserved for communication between winmm & driver
                dwReserved2 dd  ?   ;// reserved for future expansion

            JOYINFOEX ENDS

                ;// values for JOYINFOEX.dwFlags
                JOY_RETURNX         EQU 00000001h
                JOY_RETURNY         EQU 00000002h
                JOY_RETURNZ         EQU 00000004h
                JOY_RETURNR         EQU 00000008h
                JOY_RETURNU         EQU 00000010h   ;// axis 5
                JOY_RETURNV         EQU 00000020h   ;// axis 6
                JOY_RETURNPOV       EQU 00000040h
                JOY_RETURNBUTTONS   EQU 00000080h
                JOY_RETURNRAWDATA   EQU 00000100h
                JOY_RETURNPOVCTS    EQU 00000200h
                JOY_RETURNCENTERED  EQU 00000400h
                JOY_USEDEADZONE     EQU 00000800h



        ;// WINMMAPI MMRESULT WINAPI joyGetThreshold(UINT uJoyID, LPUINT puThreshold);
        ;// WINMMAPI MMRESULT WINAPI joyReleaseCapture(UINT uJoyID);
        ;// WINMMAPI MMRESULT WINAPI joySetCapture(HWND hwnd, UINT uJoyID, UINT uPeriod, BOOL fChanged);
        ;// WINMMAPI MMRESULT WINAPI joySetThreshold(UINT uJoyID, UINT uThreshold);








;//////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////
;//
;//
;////     M I D I


    ;//// MIDI ERROR CODES    (MMRESULT)    note that MMSYSERR also applies

        MIDIERR_UNPREPARED    EQU 64 ;//  header not prepared
        MIDIERR_STILLPLAYING  EQU 65 ;//  still something playing
        MIDIERR_NOMAP         EQU 66 ;//  no configured instruments
        MIDIERR_NOTREADY      EQU 67 ;//  hardware is still busy
        MIDIERR_NODEVICE      EQU 68 ;//  port no longer connected
        MIDIERR_INVALIDSETUP  EQU 69 ;//  invalid MIF
        MIDIERR_BADOPENMODE   EQU 70 ;//  operation unsupported w/ open mode
        MIDIERR_DONT_CONTINUE EQU 71 ;//  thru device 'eating' a message


    ;//// STRUCTURES

        MIDIHDR STRUCT
            pData           dd 0 ;//  pointer to byte data
            dwBufferLength  dd 0 ;//  number of bytes
            dwBytesRecorded dd 0 ;//  number of bytes
            dwUser          dd 0 ;//  user parameter
            dwFlags         dd 0 ;//  see below
            pTagNext        dd 0 ;//  reserved
            dwReserved1     dd 0 ;//  reserved
            dwOffset        dd 0 ;//  callback offset for events
            dwReserved2     dd 4 DUP (0)    ;//  reserved
        MIDIHDR endS

        ;//// flags for dwFlags field of MIDIHDR structure
        MHDR_NONE       EQU 00000000h ;// empty
        MHDR_DONE       EQU 00000001h ;// done bit
        MHDR_PREPARED   EQU 00000002h ;// set if header prepared
        MHDR_INQUEUE    EQU 00000004h ;// reserved for driver
        MHDR_ISSTRM     EQU 00000008h ;// Buffer is stream buffer


comment ~ /*;// this doesn't appear to work like I expected
         ;// for some reason, the docs didn't say that short events are only 3 DWORDs

        MIDIEVENT STRUCT

            dwDeltaTime dd  0
            dwStreamID  dd  1
            dwEvent     dd  0
            dwParams    dd  0

        MIDIEVENT ENDS
*/ comment ~


        MIDISHORTEVENT STRUCT

            dwDeltaTime dd  0
            dwStreamID  dd  0
            dwEvent     dd  0   ;// see MEVT_ below for how to pack these

        MIDISHORTEVENT ENDS


    ;//// FUNCTIONS


        WIN32API midiInGetNumDevs

        WIN32API midiOutGetNumDevs
        ;// both of these return the number of said devices

        ;// these fuctions return MMRESULT or MIDIERR_

        WIN32API midiInGetDevCapsA, uDeviceID:DWORD, pMidiInCaps:DWORD, cbMidiInCaps:DWORD


            MAXPNAMELEN EQU 32

            MIDIINCAPS STRUCT
                wMid            dw 0 ;//
                wPid            dw 0 ;//
                dwDriverVersion dd 0 ;//
                szPname         db MAXPNAMELEN DUP (0)
                dwSupport       dd 0 ;//
            MIDIINCAPS endS


        WIN32API midiOutGetDevCapsA, uDeviceID:DWORD, pMidiOutCaps:DWORD, cbMidiOutCaps:DWORD

        MIDIOUTCAPS STRUCT
            wMid    dw 0
            wPid    dw 0
            vDriverVersion  dd 0 ;//
            szPname         db MAXPNAMELEN DUP(0)
            wTechnology     dw 0 ;//
            wVoices         dw 0 ;//
            wNotes          dw 0 ;//
            wChannelMask    dw 0 ;//
            dwSupport       dd 0 ;//
        MIDIOUTCAPS endS

        ;// flags for wTechnology field of MIDIOUTCAPS structure
        MOD_MIDIPORT EQU 1 ;// output port
        MOD_SYNTH    EQU 2 ;// generic internal synth
        MOD_SQSYNTH  EQU 3 ;// square wave internal synth
        MOD_FMSYNTH  EQU 4 ;// FM internal synth
        MOD_MAPPER   EQU 5 ;// MIDI mapper

        ;// flags for dwSupport field of MIDIOUTCAPS structure
        MIDICAPS_VOLUME   EQU 0001h ;// supports volume control */
        MIDICAPS_LRVOLUME EQU 0002h ;// separate left-right volume control
        MIDICAPS_CACHE    EQU 0004h ;// supports cache patching
        MIDICAPS_STREAM   EQU 0008h ;// driver supports midiStreamOut directly


        ;// flags used with waveOutOpen(), waveInOpen(), midiInOpen(), and
        ;// midiOutOpen() to specify the type of the dwCallback parameter.
        CALLBACK_NULL      EQU 00000000h ;// no callback
        CALLBACK_WINDOW    EQU 00010000h ;// dwCallback is a HWND
        CALLBACK_TASK      EQU 00020000h ;// dwCallback is a HTASK
        CALLBACK_FUNCTION  EQU 00030000h ;// dwCallback is a FARPROC
        CALLBACK_EVENT     EQU 00050000h ;// dwCallback is an EVENT Handle


        WIN32API midiOutOpen, phMidiOut:DWORD,    uDeviceID:DWORD,      dwCallback:DWORD,   dwInstance:DWORD,   dwOpenFlags:DWORD

        WIN32API midiOutClose, hMidiOut:DWORD

        WIN32API midiOutPrepareHeader, hMidiOut:DWORD, pMidiHdr:DWORD, cbMidiHeader:DWORD

        WIN32API midiOutUnprepareHeader, hMidiOut:DWORD, pMidiHdr:DWORD, cbMidiHeader:DWORD

        WIN32API midiOutShortMsg, hMidiOut:DWORD, dwMsg:DWORD

        WIN32API midiOutLongMsg, hMidiOut:DWORD, pMidiHdr:DWORD, cbMidiHeader:DWORD

        WIN32API midiOutReset, hMidiOut:DWORD

        WIN32API midiInOpen, phMidiIn:DWORD, uDeviceID:DWORD, pCallback:DWORD, dwCallbackInstance:DWORD, dwFlags:DWORD
        WIN32API midiInClose, hMidiIn:DWORD

        WIN32API midiInStart, hMidiIn:DWORD
        WIN32API midiInStop, hMidiIn:DWORD
        WIN32API midiInReset, hMidiIn:DWORD

        WIN32API midiInPrepareHeader, hMidiIn:DWORD, pMidiInHdr:DWORD, cbMidiInHdr:DWORD
        WIN32API midiInAddBuffer, hMidiIn:DWORD, pMidiInHdr:DWORD, cbMidiInHdr:DWORD
        WIN32API midiInUnprepareHeader, hMidiIn:DWORD, pMidiInHdr:DWORD, cbMidiInHdr:DWORD


        ;// this is a placeholder function to be defined by the application
        WIN32API MidiInProc, hMidiIn:DWORD, dwMsg:DWORD, dwInstance:DWORD, dwParam1:DWORD, dwParam2:DWORD
        ;// return nothing




    ;// streams, all of these return MMRESULT or MIDIERR_

        WIN32API midiStreamOpen, phStream:DWORD, pdwDeviceID:DWORD, dwMustBeOne:DWORD, pCallback:DWORD, dwCallBackInstance:DWORD, dwFlags:DWORD

        WIN32API midiStreamClose, hStream:DWORD

        WIN32API midiStreamOut, hStream:DWORD, pMidiHeader:DWORD, dwSizeMidiHeader:DWORD

        WIN32API midiStreamRestart, hStream:DWORD

    ;// event types
    ;// these are not quite as defined in mmsystem.h
    ;// but rearranged for asm implementation

        ;// for midi events, pack register as follows
        ;//
        ;// MEVT    param2  param1  status  channel
        ;//  31-24  23-16   15-8    7-4     3-0
        ;// e               h       l

        ;// these are designed to OR onto a byte
        MEVT_SHORTMSG     EQU   00000000h   ;// param = the event
        MEVT_TEMPO        EQU   01000000h   ;// parm = new tempo in microsec/qn
        MEVT_NOP          EQU   02000000h   ;// parm = unused;// does nothing
        MEVT_CALLBACK     EQU   40000000h   ;// generate a callback
        MEVT_LONG         EQU   80000000h   ;// send a long message

        ;// here are the status bytes
        MIDI_S_NOTEOFF      EQU 00000080h   ;// 2 param, encode channel in lsb
        MIDI_S_NOTEON       EQU 00000090h
        MIDI_S_PRESSURE     EQU 000000A0h
        MIDI_S_CONTROLLER   EQU 000000B0h
        MIDI_S_PROGRAM      EQU 000000C0h   ;// one param, encode channel in lsb
        MIDI_S_AFTERTOUCH   EQU 000000D0h
        MIDI_S_PITCHWHEEL   EQU 000000E0h
        MIDI_S_SYSX         EQU 000000F0h   ;// no params
        ;// F1  Quarter Frame, 1 byte follows (0-127)
        ;// F2  SPP N+V = number of 16ths since song start (1/16 is 6 clocks)
        ;// F3  song select
        ;// F4  not used
        ;// F5  not used
        ;// F6  tuning request
        MIDI_S_SYSX_END     EQU 000000F7h   ;// end sysx
        MIDI_S_CLOCK        EQU 000000F8h
        ;// F9  midi tick (every 10ms) no data
        MIDI_S_START        EQU 000000FAh
        MIDI_S_STOP         EQU 000000FBh
        MIDI_S_CONTINUE     EQU 000000FCh
        ;// FD  not used
        MIDI_S_ACTIVE       EQU 000000FEh   ;// keep alive, 1 every 3--ms
        MIDI_S_RESET        EQU 000000FFh   ;// FF  reset (aka panic)






    ;// properties

        WIN32API midiStreamProperty, hStream:DWORD, pData:DWORD, dwProperty:DWORD

        MIDIPROP_SET    EQU 80000000h
        MIDIPROP_GET    EQU 40000000L

        MIDIPROP_TIMEDIV EQU 00000001h
        MIDIPROP_TEMPO   EQU 00000002h

        MIDIPROPTIMEDIV STRUCT

            dwSize      dd  SIZEOF MIDIPROPTIMEDIV
            dwTimeDiv   dd  96      ;// ticks per beat

        MIDIPROPTIMEDIV ENDS

        MIDIPROPTEMPO STRUCT

            dwSize  dd SIZEOF MIDIPROPTEMPO
            dwTempo dd 500000       ;// uSec per quarter

        MIDIPROPTEMPO ENDS


    ;// messages

        ;// midi input
        MIM_OPEN         EQU 03C1h
        MIM_CLOSE        EQU 03C2h
        MIM_DATA         EQU 03C3h
        MIM_LONGDATA     EQU 03C4h
        MIM_ERROR        EQU 03C5h
        MIM_LONGERROR    EQU 03C6h

        ;// midi output
        MOM_OPEN         EQU 03C7h
        MOM_CLOSE        EQU 03C8h
        MOM_DONE         EQU 03C9h





;/////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////
;//
;//                                             xlated from mmsystem.h
;//         Multimedia File I/O support
;//

    ;//  MMIO error return values
    MMIOERR_BASE             EQU   100h
    MMIOERR_FILENOTFOUND     EQU   (MMIOERR_BASE + 1)  ;//  file not found
    MMIOERR_OUTOFMEMORY      EQU   (MMIOERR_BASE + 2)  ;//  out of memory
    MMIOERR_CANNOTOPEN       EQU   (MMIOERR_BASE + 3)  ;//  cannot open
    MMIOERR_CANNOTCLOSE      EQU   (MMIOERR_BASE + 4)  ;//  cannot close
    MMIOERR_CANNOTREAD       EQU   (MMIOERR_BASE + 5)  ;//  cannot read
    MMIOERR_CANNOTWRITE      EQU   (MMIOERR_BASE + 6)  ;//  cannot write
    MMIOERR_CANNOTSEEK       EQU   (MMIOERR_BASE + 7)  ;//  cannot seek
    MMIOERR_CANNOTEXPAND     EQU   (MMIOERR_BASE + 8)  ;//  cannot expand file
    MMIOERR_CHUNKNOTFOUND    EQU   (MMIOERR_BASE + 9)  ;//  chunk not found
    MMIOERR_UNBUFFERED       EQU   (MMIOERR_BASE + 10) ;//
    MMIOERR_PATHNOTFOUND     EQU   (MMIOERR_BASE + 11) ;//  path incorrect
    MMIOERR_ACCESSDENIED     EQU   (MMIOERR_BASE + 12) ;//  file was protected
    MMIOERR_SHARINGVIOLATION EQU   (MMIOERR_BASE + 13) ;//  file in use
    MMIOERR_NETWORKERROR     EQU   (MMIOERR_BASE + 14) ;//  network not responding
    MMIOERR_TOOMANYOPENFILES EQU   (MMIOERR_BASE + 15) ;//  no more file handles
    MMIOERR_INVALIDFILE      EQU   (MMIOERR_BASE + 16) ;//  default error file error


    ;//  general MMIO information data structure
    MMIOINFO    STRUCT

        ;//  general fields
        dwFlags     dd  0   ;//  general status flags
        fccIOProc   dd  0   ;//  fcc for I/O procedure
        pIOProc     dd  0   ;//  pointer to I/O procedure
        wErrorRet   dd  0   ;//  place for error to be returned
        htask       dd  0   ;//  alternate local task

        ;//  fields maintained by MMIO functions during buffered I/O
        cchBuffer   dd  0   ;//  size of I/O buffer (or 0L)
        pBuffer     dd  0   ;//  start of I/O buffer (or NULL)
        pNext       dd  0   ;//  pointer to next byte to read/write
        pEndRead    dd  0   ;//  pointer to last valid byte to read
        pEndWrite   dd  0   ;//  pointer to last byte to write
        dwBufOffset dd  0   ;//  disk offset of start of buffer

        ;//  fields maintained by I/O procedure
        dwDiskOffset dd 0   ;//  disk offset of next read or write
        adwInfo dd 3 DUP (0);//  data specific to type of MMIOPROC

        ;//  other fields maintained by MMIO
        dwReserved1 dd  0   ;//  reserved for MMIO use
        dwReserved2 dd  0   ;//  reserved for MMIO use
        hmmio       dd  0   ;//  handle to open file

    MMIOINFO ENDS

    ;//  constants for dwFlags field of MMIOINFO
    MMIO_CREATE     EQU 00001000h      ;//  create new file (or truncate file)
    MMIO_PARSE      EQU 00000100h      ;//  parse new file returning path
    MMIO_DELETE     EQU 00000200h      ;//  create new file (or truncate file)
    MMIO_EXIST      EQU 00004000h      ;//  checks for existence of file
    MMIO_ALLOCBUF   EQU 00010000h      ;//  mmioOpen() should allocate a buffer
    MMIO_GETTEMP    EQU 00020000h      ;//  mmioOpen() should retrieve temp name

    MMIO_DIRTY      EQU 10000000h      ;//  I/O buffer is dirty

    ;//  read/write mode numbers (bit field MMIO_RWMODE)
    MMIO_READ       EQU 00000000h      ;//  open file for reading only
    MMIO_WRITE      EQU 00000001h      ;//  open file for writing only
    MMIO_READWRITE  EQU 00000002h      ;//  open file for reading and writing

    MMIO_RWMODE     EQU 00000003h      ;//  open file for reading/writing/both

    ;//  share mode numbers (bit field MMIO_SHAREMODE)
    MMIO_COMPAT     EQU 00000000h      ;//  compatibility mode
    MMIO_EXCLUSIVE  EQU 00000010h      ;//  exclusive-access mode
    MMIO_DENYWRITE  EQU 00000020h      ;//  deny writing to other processes
    MMIO_DENYREAD   EQU 00000030h      ;//  deny reading to other processes
    MMIO_DENYNONE   EQU 00000040h      ;//  deny nothing to other processes

    MMIO_SHAREMODE  EQU 00000070h      ;//  file sharing mode number




    ;////////////////////////////////////////////////////////////////////
    ;//
    ;//
    ;//     MMIO function prototypes

    ;// general open and close

        WIN32API mmioOpenA, pszFileName:DWORD, pmmioinfo:DWORD, dwOpenFlags:DWORD
        ;// returns handle, or zero for error

            ;// open flags are defined above

        WIN32API mmioClose, hmmio:DWORD, dwCloseFlags:DWORD
        ;// returns zero for success

            MMIO_FHOPEN     EQU 0010h  ;//  mmioClose: keep file handle open

    ;// information

        WIN32API mmioGetInfo, hmmio:DWORD, pmmioinfo:DWORD, fuInfo:DWORD
            ;// dwFlags must be zero

        WIN32API mmioSetInfo, hmmio:DWORD, pmmioinfo:DWORD, fuInfo:DWORD
            ;//dwFlags must be zero

        WIN32API mmioSetBuffer, hmmio:DWORD, pBuffer:DWORD, sizBuffer:DWORD, dwBufferFlags:DWORD
            ;// dwFlags must be zero



    ;// read write seek

        WIN32API mmioRead, hmmio:DWORD, pBuffer:DWORD, dwSize:DWORD
        WIN32API mmioWrite, hmmio:DWORD, pBuffer:DWORD, dwSize:DWORD
        WIN32API mmioSeek, hmmio:DWORD, dwOffset:DWORD, dwOrigon:DWORD

            ;// values for dwOrigon
            SEEK_SET  EQU  0   ;//  seek to an absolute position
            SEEK_CUR  EQU  1   ;//  seek relative to current position
            SEEK_END  EQU  2   ;//  seek relative to end of file


    ;// buffered io

        WIN32API mmioFlush, hmmio:DWORD, dwFlags:DWORD

            ;// dwFlags
            MMIO_EMPTYBUF   EQU 0010h  ;//  empty the I/O buffer

        WIN32API mmioAdvance, hmmio:DWORD, pmmioinfo:DWORD, dwAdvance:DWORD

            ;// dwAdvance is defined above




;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////
;//
;//                         riff_header was creted by ajt
;//     RIFF support
;//

    RIFF_HEADER STRUCT

        fccID   dd  0   ;// RIFF or LIST
        dwSize  dd  0   ;// size of chunk (always releative to the NEXT item)
        fccType dd  0   ;// sub type of this chunk

    RIFF_HEADER ENDS

    ;//  RIFF chunk information data structure

    MMCKINFO    STRUCT

        RIFF_HEADER {}

        dwDataOffset    dd  0   ;//  offset of data portion of chunk (absolute file pos)
        dwFlags         dd  0   ;// flags used by MMIO functions (MMIO_DIRTY)

    MMCKINFO    ENDS


    ;// RIFF navigation

        WIN32API mmioDescend, hmmio:DWORD, pmmckinfo:DWORD, pmmckinfoParent:DWORD, dwFlags:DWORD

            ;// values for dwFlags
            MMIO_FINDCHUNK EQU 0010h  ;//  find a chunk by ID
            MMIO_FINDRIFF  EQU 0020h  ;//  find a RIFF chunk
            MMIO_FINDLIST  EQU 0040h  ;//  find a LIST chunk

        WIN32API mmioAscend, hmmio:DWORD, pmmckinfo:DWORD, fuAscend:DWORD
            ;// dwflags mustt be zero


        WIN32API mmioCreateChunk, hmmio:DWORD, pmmckinfo:DWORD, dwFlags:DWORD

            ;// values for dwflags
            MMIO_CREATERIFF EQU 0020h  ;//  make a LIST chunk
            MMIO_CREATELIST EQU 0040h  ;//  make a RIFF chunk








;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;//
;//
;////     M E S S A G E   B O X E S


    WIN32API MessageBoxA, hWnd:DWORD, pszText:DWORD, pszCaption:DWORD, uType:DWORD
    ;// returns one of the following
        IDOK      EQU 1
        IDCANCEL  EQU 2
        IDABORT   EQU 3
        IDRETRY   EQU 4
        IDIGNORE  EQU 5
        IDYES     EQU 6
        IDNO      EQU 7
        IDCLOSE   EQU 8
        IDHELP    EQU 9

        ;//
        ;////   MessageBox() Flags
        ;//

        MB_OK                       EQU 00000000h
        MB_OKCANCEL                 EQU 00000001h
        MB_ABORTRETRYIGNORE         EQU 00000002h
        MB_YESNOCANCEL              EQU 00000003h
        MB_YESNO                    EQU 00000004h
        MB_RETRYCANCEL              EQU 00000005h

        MB_ICONHAND                 EQU 00000010h
        MB_ICONQUESTION             EQU 00000020h
        MB_ICONEXCLAMATION          EQU 00000030h
        MB_ICONASTERISK             EQU 00000040h

        MB_USERICON                 EQU 00000080h

        MB_DEFBUTTON1               EQU 00000000h
        MB_DEFBUTTON2               EQU 00000100h
        MB_DEFBUTTON3               EQU 00000200h
        MB_DEFBUTTON4               EQU 00000300h

        MB_APPLMODAL                EQU 00000000h
        MB_SYSTEMMODAL              EQU 00001000h
        MB_TASKMODAL                EQU 00002000h
        MB_HELP                     EQU 00004000h
        MB_NOFOCUS                  EQU 00008000h
        MB_SETFOREGROUND            EQU 00010000h
        MB_DEFAULT_DESKTOP_ONLY     EQU 00020000h
        MB_TOPMOST                  EQU 00040000h
        MB_RIGHT                    EQU 00080000h
        MB_RTLREADING               EQU 00100000h









;////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////
;//
;//
;////     C O M M O N   C O N T R O L S
;//
    WIN32API InitCommonControls
    ;// no return value



    ;// COMMON CONTROL STYLES

    CCS_TOP                 EQU 00000001h
    CCS_NOMOVEY             EQU 00000002h
    CCS_BOTTOM              EQU 00000003h
    CCS_NORESIZE            EQU 00000004h
    CCS_NOPARENTALIGN       EQU 00000008h
    CCS_ADJUSTABLE          EQU 00000020h
    CCS_NODIVIDER           EQU 00000040h
    CCS_VERT                EQU 00000080h



;////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////
;//
;//
;//     C O M M O N   D I A L O G
;//


    WIN32API GetOpenFileNameA, pOpenFileNameA:DWORD
    ;// returns non zero if user didnot CANCEL

    WIN32API GetSaveFileNameA, pOpenFileNameA:DWORD
    ;// returns non zero if user didnot CANCEL

    OPENFILENAMEA STRUCT

       StructSize   dd   SIZEOF OPENFILENAMEA
       hWndOwner    dd   0
       hInstance    dd   0
       pszFilter    dd   0
       pszCustFilter   dd 0
       nMaxCustFilter  dd 0
       nFilterIndex    dd 0
       pszFile         dd 0
       nMaxFile        dd 0
       pszFileTitle    dd 0
       nMaxFileTitle   dd 0
       pszInitialDir  dd 0
       pszTitle       dd 0
       dwFlags         dd 0
       nFileOffset     dw 0
       nFileExtension  dw 0
       pszDefExt       dd 0
       lCustData       dd 0
       pfnHook         dd 0
       pszTemplateName dd 0

    OPENFILENAMEA ENDS

        ;// Flag values for OPENFILENAME.dwFlags

        OFN_READONLY                 EQU 00000001h
        OFN_OVERWRITEPROMPT          EQU 00000002h
        OFN_HIDEREADONLY             EQU 00000004h
        OFN_NOCHANGEDIR              EQU 00000008h
        OFN_SHOWHELP                 EQU 00000010h
        OFN_ENABLEHOOK               EQU 00000020h
        OFN_ENABLETEMPLATE           EQU 00000040h
        OFN_ENABLETEMPLATEHANDLE     EQU 00000080h
        OFN_NOVALIDATE               EQU 00000100h
        OFN_ALLOWMULTISELECT         EQU 00000200h
        OFN_EXTENSIONDIFFERENT       EQU 00000400h
        OFN_PATHMUSTEXIST            EQU 00000800h
        OFN_FILEMUSTEXIST            EQU 00001000h
        OFN_CREATEPROMPT             EQU 00002000h
        OFN_SHAREAWARE               EQU 00004000h
        OFN_NOREADONLYRETURN         EQU 00008000h
        OFN_NOTESTFILECREATE         EQU 00010000h
        OFN_NONETWORKBUTTON          EQU 00020000h
        OFN_NOLONGNAMES              EQU 00040000h     ;// force no long names for 4.x modules
        OFN_EXPLORER                 EQU 00080000h     ;// new look commdlg
        OFN_NODEREFERENCELINKS       EQU 00100000h
        OFN_LONGNAMES                EQU 00200000h     ;// force long names for 3.x modules


        ;// when using a hook proceedure these are useful


        OFNOTIFY STRUCT

            hWndFrom dd 0   ;// NMHDR STRUCT
            idFrom dd 0     ;//
            dwCode dd 0     ;//
            pOPENFILENAMEA  dd 0    ;// pointer to an OPENFILENAMEA STRUCT
            pszFile         dd 0 ;//

        OFNOTIFY ENDS


        ;// Notifications when Open or Save dialog status changes
        CDN_INITDONE            EQU 0FFFFFDA7h
        CDN_SELCHANGE           EQU 0FFFFFDA6h
        CDN_FOLDERCHANGE        EQU 0FFFFFDA5h
        CDN_SHAREVIOLATION      EQU 0FFFFFDA4h
        CDN_HELP                EQU 0FFFFFDA3h
        CDN_FILEOK              EQU 0FFFFFDA2h
        CDN_TYPECHANGE          EQU 0FFFFFDA1h

        ;// these are message that can be sent to a file dialog
        CDM_GETSPEC             EQU WM_USER + 100
        CDM_GETFILEPATH         EQU WM_USER + 101
        CDM_GETFOLDERPATH       EQU WM_USER + 102
        CDM_GETFOLDERIDLIST     EQU WM_USER + 103
        CDM_SETCONTROLTEXT      EQU WM_USER + 104
        CDM_HIDECONTROL         EQU WM_USER + 105
        CDM_SETDEFEXT           EQU WM_USER + 106


    WIN32API CommDlgExtendedError
    ;// return zero, or error code

        CDERR_DIALOGFAILURE   EQU 0FFFFh

        CDERR_GENERALCODES     EQU 0000h
        CDERR_STRUCTSIZE       EQU 0001h
        CDERR_INITIALIZATION   EQU 0002h
        CDERR_NOTEMPLATE       EQU 0003h
        CDERR_NOHINSTANCE      EQU 0004h
        CDERR_LOADSTRFAILURE   EQU 0005h
        CDERR_FINDRESFAILURE   EQU 0006h
        CDERR_LOADRESFAILURE   EQU 0007h
        CDERR_LOCKRESFAILURE   EQU 0008h
        CDERR_MEMALLOCFAILURE  EQU 0009h
        CDERR_MEMLOCKFAILURE   EQU 000Ah
        CDERR_NOHOOK           EQU 000Bh
        CDERR_REGISTERMSGFAIL  EQU 000Ch

        PDERR_PRINTERCODES     EQU 1000h
        PDERR_SETUPFAILURE     EQU 1001h
        PDERR_PARSEFAILURE     EQU 1002h
        PDERR_RETDEFFAILURE    EQU 1003h
        PDERR_LOADDRVFAILURE   EQU 1004h
        PDERR_GETDEVMODEFAIL   EQU 1005h
        PDERR_INITFAILURE      EQU 1006h
        PDERR_NODEVICES        EQU 1007h
        PDERR_NODEFAULTPRN     EQU 1008h
        PDERR_DNDMMISMATCH     EQU 1009h
        PDERR_CREATEICFAILURE  EQU 100Ah
        PDERR_PRINTERNOTFOUND  EQU 100Bh
        PDERR_DEFAULTDIFFERENT EQU 100Ch

        CFERR_CHOOSEFONTCODES  EQU 2000h
        CFERR_NOFONTS          EQU 2001h
        CFERR_MAXLESSTHANMIN   EQU 2002h

        FNERR_FILENAMECODES    EQU 3000h
        FNERR_SUBCLASSFAILURE  EQU 3001h
        FNERR_INVALIDFILENAME  EQU 3002h
        FNERR_BUFFERTOOSMALL   EQU 3003h

        FRERR_FINDREPLACECODES EQU 4000h
        FRERR_BUFFERLENGTHZERO EQU 4001h

        CCERR_CHOOSECOLORCODES EQU 5000h






;////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////
;//
;//
;////     D I A L O G   B O X E S


    WIN32API DialogBoxParamA, hInstance:DWORD, pTemplateName:DWORD, hWndParent:DWORD, pDialogFunc:DWORD, dwInitParam:DWORD
    ;// this creates a modal dialog box
    ;// returns whatever end dialog returns

    WIN32API DialogProc, hWndDlg:DWORD,  uMsg:DWORD,  wParam:DWORD,  lParam:DWORD
    ;// this is a placeholder definition
    ;// return false to prevent windows from calling the default proc
    ;// call EndDialog from within this proceedure to exit

    WIN32API EndDialog, hWndDlg:DWORD, nResult:DWORD
    ;// this should only be called from the DialogProc



    WIN32API GetDialogBaseUnits
    ;// return sPOINT x and y in base units
    ;// see docs for conversion to pixels











;//////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////
;//
;////                             these are the interface to the WM_DROPFILES function
;////     D R A G   D R O P
;//



    WIN32API DragAcceptFiles, hWnd:DWORD, bAccept:DWORD
    ;// no return value

    WIN32API DragFinish, hDrop:DWORD
    ;// no return value

    WIN32API DragQueryFileA, hDrop:DWORD, iFile:DWORD, pszFileName:DWORD, sizeFilname:DWORD
    ;// returns length of retrieved filename







;////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////
;//
;//  C R I T I C A L   S E C T I O N S
;//
    CRITICAL_SECTION  STRUCT
        pDebugInfo          dd ?
        dwLockCount         dd ?
        dwRecursionCount    dd ?
        dwOwningThread      dd ?
        dwLockSemaphore     dd ?
        dwReserved          dd ?
    CRITICAL_SECTION  ENDS

    WIN32API InitializeCriticalSection, pCriticalSection:DWORD

    WIN32API EnterCriticalSection, pCriticalSection:DWORD

    WIN32API LeaveCriticalSection, pCriticalSection:DWORD

    WIN32API DeleteCriticalSection, pCriticalSection:DWORD

    ;// none of the above returns a value

    WIN32API TryEnterCriticalSection, pCriticalSection:DWORD
    ;// return a bool



;//////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////
;//
;//  E V E N T S         use CloseHandle to destroy
;//

    WIN32API CreateEventA, pEventAttributes:DWORD, bManualReset:DWORD, bInitialState:DWORD, pszName:DWORD
    ;// returns hEvent or zero for error

    WIN32API SetEvent, hEvent:DWORD
    ;// return non zero for sucess

    WIN32API PulseEvent, hEvent:DWORD
    ;// return non zero for sucess

    WIN32API ResetEvent, hEvent:DWORD
    ;// returns non zero for sucess

    WIN32API WaitForSingleObject, hHandle:DWORD, dwMilliseconds:DWORD
    ;// returns handle of object to wait for
    ;// other return values:
        WAIT_FAILED     EQU 0FFFFFFFFh
        WAIT_OBJECT_0   EQU  00000000h
        WAIT_ABANDONED  EQU  00000080h
        WAIT_TIMEOUT    EQU  00000102h


    WIN32API SignalObjectAndWait, hObjectToSignal:DWORD,hObjectToWaitOn:DWORD, dwMilliseconds:DWORD, bAlertable:DWORD
    ;// return handle of object that caused return


    WIN32API WaitForMultipleObjects, nCount:DWORD, pHandles:DWORD, bWaitAll:DWORD, dwMilliseconds:DWORD
    ;// returns a number of things




;////////////////////////////////////////////////////////////////////
;//
;//
;//     MUTEX
;//



    WIN32API CreateMutexA, lpMutexAttributes:DWORD, bInitialOwner:DWORD, pName:DWORD

    WIN32API OpenMutexA, dwDesiredAccess:DWORD, bInheritHandle:DWORD, pName:DWORD

    WIN32API ReleaseMutex, hMutex:DWORD

    MUTANT_QUERY_STATE  EQU 0001h
    MUTEX_MODIFY_STATE  EQU MUTANT_QUERY_STATE
    MUTANT_ALL_ACCESS   EQU STANDARD_RIGHTS_REQUIRED OR SYNCHRONIZE OR MUTANT_QUERY_STATE

    MUTEX_ALL_ACCESS    EQU MUTANT_ALL_ACCESS


;////////////////////////////////////////////////////////////////////
;//
;//
;//     interlocked
;//


    WIN32API InterlockedIncrement, pAdd:DWORD
    WIN32API InterlockedDecrement, pAdd:DWORD




ENDIF ;// _WIN32A_IMP_INCLUDED_