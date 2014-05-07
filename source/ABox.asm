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
;//                 -- In debug build, allowing fpu overflow and invalid
;//                    exposes a huge number of otherwise harmless faults.
;//                    FPU trap enables in fpu_ctrl_word removed for those.
;//                 -- changed palette version from 99 to 220 
;//                    which fixes the registry color storage
;//                    ??! why that bug decided to appear 8 years !?? 
;//                 -- Added support for VirtualProtect
;//                    many thanks to qWord and the folks at masm32.com
;//
;//##////////////////////////////////////////////////////////////////////////
;//                 main module
;// ABox.asm
;//
;// TOC
;//
;// app_Main
;// app_GetWindowSettings
;// app_InitializeWindows
;// app_CreateOsc
;// app_SystemCheck


OPTION CASEMAP:NONE

.586
.MODEL FLAT

        .NOLIST
        INCLUDE <Abox.inc>
        INCLUDE <com.inc>
    ;// .LIST
        .LISTALL
    ;// .LISTMACROALL

;////////////////////////////////////////////////////////////////////
;//
;// FUNCTIONS IN THIS FILE
;//

        app_Main                PROTO STDCALL
        app_SystemCheck         PROTO STDCALL
        app_InitializeWindows   PROTO STDCALL


;//
;// FUNCTIONS IN THIS FILE
;//
;////////////////////////////////////////////////////////////////////


.DATA

;////////////////////////////////////////////////////////////////////
;//
;//
;// data for application
;//
    ;//
    ;// app and main window data
    ;//

        hInstance     dd 0 ;//  global hInstance
        hAccel        dd 0 ;//  accelerators for main wnindow

        mainWndAtom     dd 0
        mainWnd_szName  db  'a_m',0
        hMainWnd        dd 0

    ;// atom and class table, wm_create's are responsible for storing their handles

        bus_atom        dd  0       ;// atom for the context menu class
        bus_szName      db  'a_b',0 ;// name of the bus context menu class

        popup_atom      dd  0
        popup_szName    db  'a_p',0

    ;// strings (4 byte aligned)

        szStatic        db 'STATIC',0,0
        szButton        db 'BUTTON',0,0
        szEdit          db 'EDIT',0,0,0,0
        szScrollBar     db 'SCROLLBAR',0,0,0
        szListBox       db 'LISTBOX', 0
        szComboBox      db 'COMBOBOX', 0,0,0,0

    ;// flags that tells us which dialogs are on

        app_DlgFlags    dd  0

    ;// says that com needs shut down

        com_initialized dd  0

    ;// master lists

        master_context  LIST_CONTEXT {}
        stack_Declare_internal gui_context, master_context
        stack_Declare_internal play_context, master_context

    ;// critical section to synchronize the play and gui thread

        crit_section CRITICAL_SECTION {}

    ;// flags for various behaviors, see ABox.inc

        app_bFlags      dd  APP_SYNC_EXTENTS

    ;// circuit behaviour   see ABox.inc

        app_CircuitSettings dd  0

    ;// global app msg and paint handler data

        app_msg   tagMSG {}      ;// app global MSG


;//////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////
;/////
;/////
;/////      A P P   S E T T T I N G S
;/////
    ;//                                these get stored in the registry
    ;//  PERSISTANT SETTINGS           default values are stored here
    ;//


    ;// masm can't initialize the big struct
    ;// so references in abox.asm need this macro

    ABox_Settings TEXTEQU <(ABOX_SETTINGS PTR app_settings)>

    ;// again, IN THIS FILE, reference ABox_Settings, NOT app_settings

app_settings \
        POINT {128,64}  ;// position on screen
        POINT {590,352} ;// size of screen
        dd  SHOW_STATUS OR SHOW_CREATE_LARGE    ;// default show options

    ;// current color scheme, there are rgb colors
    dd  00404040h,  00B0B000h,  0000FFFFh,  00FF0000h,  0000FF00h,  00BBBBBBh,  00A0A000h,  0000A0A0h
    dd  00A1A4D3h,  009D9CFFh,  0075A040h,  00A29EF0h,  0001A8A8h,  0000A000h,  00404041h,  00B0B001h
    dd  0000FFFDh,  00FF0001h,  0000FF01h,  00BBBBBCh,  00A0A001h,  0000A0A1h,  00A1A4D4h,  009D9CFEh
    dd  00404042h,  0075A041h,  00EFF066h,  00909000h,  00C0F0F0h,  00FF0002h,  0000FFFFh,  00000220h
    ;//
    dd  00954B6Dh,  009D8068h
    dd  0045655Bh,  008580B8h
    dd  00008582h,  00858285h
    dd  00188365h,  003D6A8Eh
    dd  0013856Dh,  00958485h
    dd  00B27530h,  0018A395h

;// user settable color schemes

    ;// group 1 (printer)
    ;//
    dd  00FFFFFFh,  00000001h,  002D01FFh,  00FF0000h,  0000FF00h,  00000003h,  00000008h,  00000006h
    dd  0000000Ah,  0000000Ch,  00000011h,  00FF0101h,  009801FFh,  0000A000h,  00FFFFFEh,  00000002h
    dd  002D01FEh,  00FF0001h,  0000FF01h,  00000004h,  00000009h,  00000007h,  0000000Bh,  0000000Dh
    dd  00FFFFFDh,  00000012h,  0000000Eh,  00907809h,  00000005h,  00FF0002h,  002D01FFh,  00000220h
    ;//
    dd  000000F0h,  00000070h
    dd  00446496h,  00000000h
    dd  00002D88h,  00858266h
    dd  00185A8Eh,  00000041h
    dd  00134AEEh,  00958485h
    dd  000001FFh, 0FFFFFEFFh

    ;// group 2 (same as default)
    ;//
    dd  00404040h,  00B0B000h,  0000FFFFh,  00FF0000h,  0000FF00h,  00BBBBBBh,  00A0A000h,  0000A0A0h
    dd  00A1A4D3h,  009D9CFFh,  0075A040h,  00A29EF0h,  0001A8A8h,  0000A000h,  00404041h,  00B0B001h
    dd  0000FFFDh,  00FF0001h,  0000FF01h,  00BBBBBCh,  00A0A001h,  0000A0A1h,  00A1A4D4h,  009D9CFEh
    dd  00404042h,  0075A041h,  00EFF066h,  00909000h,  00C0F0F0h,  00FF0002h,  0000FFFFh,  00000220h
    ;//
    dd  00954B6Dh,  009D8068h
    dd  0045655Bh,  008580B8h
    dd  00008582h,  00858285h
    dd  00188365h,  003D6A8Eh
    dd  0013856Dh,  00958485h
    dd  00B27530h,  0018A395h

    ;// group 3 (dark dark dark)
    ;//
    dd  00000006h,  000402BEh,  00847DFEh,  00FF0000h,  0000FF00h,  004C6648h,  00626300h,  00007171h
    dd  006B6B6Bh,  00484874h,  000F6200h,  00FF7E01h,  00AF01E0h,  0000A000h,  00000007h,  000402BFh
    dd  00847DFFh,  00FF0001h,  0000FF01h,  004C6649h,  00626301h,  00007172h,  006B6B6Ch,  00484875h
    dd  00000008h,  000F6201h,  00519155h,  00686900h,  00999999h,  00FF0002h,  00847DFEh,  00000220h
    ;//
    dd  00B03725h,  008B772Bh
    dd  00000012h,  00598066h
    dd  008EFF1Ch,  0052885Eh
    dd  00000000h,  003DF363h
    dd  00128325h,  00957A66h
    dd  00000000h,  0096FF5Eh

    ;// group 4 (pretty blue)
    ;//
    dd  005577FFh,  0001E1FFh,  00DFFF05h,  00FF0000h,  0000FF00h,  00D7D7D7h,  00D6D75Ch,  0002CCCCh
    dd  00DAA4DAh,  00A7A7A7h,  004AC67Bh,  00FFFFFFh,  00C2C401h,  0000A000h,  005577FEh,  0001E1FEh
    dd  00DFFF06h,  00FF0001h,  0000FF01h,  00D7D7D8h,  00D6D75Dh,  0002CCCDh,  00DAA4DBh,  00A7A7A8h
    dd  005577FDh,  004AC67Ch,  00000001h,  00909000h,  00009090h,  00FF0002h,  00DFFF05h,  00000220h
    ;//
    dd  00938485h,  00857E6Fh
    dd  00A48485h,  008580B5h
    dd  00938582h,  00AD8085h
    dd  00C18485h,  005B8869h
    dd  0047555Ah,  00A784CFh
    dd  00B85882h,  0025836Fh


    ;// this exists outside of the ABOX_SETTINGS realm and is the default color set
    ;// the color editor is designed so this can never be written to

app_default_colors LABEL DWORD

          ;// system colors
;// default -- is a GDI_PALETTE
;//

    dd  00404040h,  00B0B000h,  0000FFFFh,  00FF0000h,  0000FF00h,  00BBBBBBh,  00A0A000h,  0000A0A0h
    dd  00A1A4D3h,  009D9CFFh,  0075A040h,  00A29EF0h,  0001A8A8h,  0000A000h,  00404041h,  00B0B001h
    dd  0000FFFDh,  00FF0001h,  0000FF01h,  00BBBBBCh,  00A0A001h,  0000A0A1h,  00A1A4D4h,  009D9CFEh
    dd  00404042h,  0075A041h,  00EFF066h,  00909000h,  00C0F0F0h,  00FF0002h,  0000FFFFh,  00000220h ;<<-- AJT changed 99 to 220
    ;// note that the last color (31) serves as a versioning tool
    ;// ABOX242 AJT -- oops! need to set the palette version to 220 -- why did this never show up before ???

    ;//
    dd  00954B6Dh,  009D8068h
    dd  0045655Bh,  008580B8h
    dd  00008582h,  00858285h
    dd  00188365h,  003D6A8Eh
    dd  0013856Dh,  00958485h
    dd  00B27530h,  0018A395h



;/////
;/////      A P P   S E T T T I N G S
;/////
;/////
;//////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////



    ;//
    ;// processor features
    ;//

        app_CPUFeatures  dd 0   ;// cpu
        app_dwPlatformID dd 0   ;// os


    IFDEF DEBUGBUILD    ;// this is ored onto the control word
        IF USE_MESSAGE_LOG EQ 2 ;// need for plugin testing
            ECHO FPU_EXCEPTION_OVERFLOW OR FPU_EXCEPTION_INVALID is OFF
            app_fpu_control dd  7Fh AND NOT(FPU_EXCEPTION_STACK OR FPU_EXCEPTION_ZERO_DIVIDE) ;// OR FPU_EXCEPTION_OVERFLOW OR FPU_EXCEPTION_INVALID)
        ELSE
            ;//app_fpu_control dd  7Fh AND NOT(FPU_EXCEPTION_STACK OR FPU_EXCEPTION_ZERO_DIVIDE OR FPU_EXCEPTION_OVERFLOW OR FPU_EXCEPTION_INVALID)
            ;// AJT ABOX242 -- allowing overflow and invalid expose a huge number of otherwise harmless faults
            ECHO FPU_EXCEPTION_OVERFLOW OR FPU_EXCEPTION_INVALID is OFF
            app_fpu_control dd  7Fh AND NOT(FPU_EXCEPTION_STACK OR FPU_EXCEPTION_ZERO_DIVIDE )
        ENDIF
    ELSE
        app_fpu_control dd  07Fh    ;// real presicion, no un masked exeptions
    ENDIF


        app_AllocationGranularity   dd  0   ;// allocation granularity

    ;//
    ;// xmouse
    ;//

        app_xmouse  dd  0   ;// 1 for xmouse



;//////////////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////////////

.CODE

;// here's where it all begins

ASSUME_AND_ALIGN
app_Main PROC STDCALL

    ;// quick check to make sure we're ok

        invoke app_SystemCheck
        dec eax
        js AllDone

    ;// get our module handle

        invoke GetModuleHandleA, 0
        mov    hInstance, eax

    ;// initialize our critical section

        invoke InitializeCriticalSection, OFFSET crit_section

    ;// preset the FPU

        fninit
        fldcw WORD PTR app_fpu_control

    ;// preparse the command line
    ;// so we can check for another file

        invoke filename_Initialize      ;// initialize and read command line

        .IF !ebx        ;// do we have a command name ?

        preinit_and_splash:

            invoke gdi_PreInitialize    ;// pre initialize gdi

            .IF ebx     ;// command line ?
                pushd 0 ;// no timer
            .ELSE       ;// no commandline
                pushd 1 ;// use timer
            .ENDIF

            call about_Show     ;// launch the splash screen

        .ELSE   ;// we have a command line

            ;// is there another instnce running ?

            invoke FindWindowA, OFFSET mainWnd_szName, 0

            or eax, eax ;// no, ;// pre initialize gdi
            jz preinit_and_splash

            ;// there's another app running, so we send the file there

            mov esi, eax    ;// eax has the window handle
            invoke registry_WriteMRU5
            invoke PostMessageA, esi, WM_COMMAND, COMMAND_MRU5, 0

            jmp AllDone


        .ENDIF

    ;// initialize lot's of stuff

        invoke CoInitialize,0
        .IF !eax
            inc com_initialized
        .ENDIF

    ;// if we can, start measuring the clock speed

    .IF app_CPUFeatures & 10h
        invoke clock_BeginMeasure
    .ENDIF

        invoke about_SetLoadStatus

    invoke registry_ReadSettings    ;// get our settings

        invoke about_SetLoadStatus

    invoke plugin_Initialize        ;// read the plugin registry

        invoke about_SetLoadStatus

    invoke hardware_Initialize      ;// initialize the hardware

        invoke about_SetLoadStatus

        fninit
        fldcw WORD PTR app_fpu_control

    invoke gdi_Initialize           ;// initialize all the graphics

        invoke about_SetLoadStatus

    invoke math_Initialize          ;// build the math tables

        invoke about_SetLoadStatus

    invoke play_Initialize          ;// start the play thread

        invoke about_SetLoadStatus

    invoke app_InitializeWindows    ;// allocate and create all the windows

        invoke about_SetLoadStatus

    invoke unredo_Initialize

        invoke about_SetLoadStatus

    ;// if we could, finish measuring the clock speed

    .IF app_CPUFeatures & 10h
        invoke clock_EndMeasure
    .ENDIF


    .IF filename_get_path           ;// did we get a command line ?

        invoke circuit_Load         ;// try to load it

    .ENDIF

    IFDEF USE_DEBUG_PANEL
        invoke debug_Initialize ;// create the debug status window
    ENDIF


    invoke DragAcceptFiles, hMainWnd, 1 ;// yes we do

    ;// invoke drop_Initialize

        invoke about_SetLoadStatus




    ;////////////////////////////////////////////////////////////////////
    ;//
    ;// message pump
    ;//
    ;//

        mov esi, hMainWnd
    IFDEF DEBUGBUILD
        xor ebx, ebx
    ENDIF
        mov edi, OFFSET app_msg
        ASSUME edi:PTR tagMSG

        @@:
        invoke GetMessageA, edi, 0, 0, 0
        .IF eax

;//         MESSAGE_LOG_MSG edi

            xor eax, eax

            ;// only xlate accelerator messages for our window

            .IF esi == [edi].hWnd
                invoke TranslateAcceleratorA, esi, hAccel, edi
            .ENDIF
            ;// if eax is zero, we need to pass this message on
            .IF !eax
                ;// intercept important hot keys for popup_hwnd child windows
                ;// check if child window of popup_hWnd has the keyboard focus
                .IF [edi].message == WM_KEYDOWN
                    invoke IsChild, popup_hWnd, [edi].hWnd
                    .IF eax
                        .IF [edi].wParam == VK_ESCAPE
                            invoke SetFocus, hMainWnd ;
                            jmp @B
                        .ELSEIF [edi].wParam == VK_TAB
                            invoke SetFocus, popup_hWnd
                            WINDOW_P popup_hWnd, WM_KEYDOWN, [edi].wParam, [edi].lParam
                            jmp @B
                        .ENDIF
                    .ENDIF
                .ENDIF
                invoke TranslateMessage, edi
                invoke DispatchMessageA, edi

                DEBUG_IF <edi !!= OFFSET app_msg>   ;// something changed this !!!
                DEBUG_IF <esi !!= hMainWnd>         ;// something changed this !!!
                DEBUG_IF <ebx>                      ;// something changed this !!!

            .ENDIF

            jmp @B

        .ENDIF

    ;//
    ;// message pump
    ;//
    ;//
    ;////////////////////////////////////////////////////////////////////

    invoke registry_WriteSettings       ;// save our settings

app_ExitNow::       ;// jumped to by uninstall

    invoke unredo_Destroy   ;// clear out the unredo memory
    invoke plugin_Destroy   ;// free the plugin records
    invoke filename_Destroy ;// free the circuit names
    invoke play_Destroy     ;// tell play to exit
    invoke status_Destroy
    invoke gdi_Destroy      ;// free the gdi
    invoke math_Destroy     ;// destroy the lookup tables
    invoke hardware_Destroy ;// free the hardware list

    .IF com_initialized
        invoke CoUninitialize
    .ENDIF


AllDone:    ;// jumped to by error condition

    IFDEF USE_MEMORYLEAKS
        .IF app_MemoryUse
            int 3   ;// there's still allocated memory
        .ENDIF      ;// look at GlobalMemory_slist_head to see why
    ENDIF

    jmp ExitProcess ;// exit the application

app_Main ENDP



ASSUME_AND_ALIGN
app_GetWindowSettings PROC

        push ebx
        sub esp, SIZEOF WINDOWPLACEMENT
        mov ebx, esp
        ASSUME ebx:PTR WINDOWPLACEMENT

    ;// this should be called before the window is destroyed

        mov [ebx].dwLength, SIZEOF WINDOWPLACEMENT

    ;//
    ;// mainWindow first
    ;//

        invoke GetWindowPlacement, hMainWnd, ebx

        .IF [ebx].dwShowCmd == SW_SHOWMAXIMIZED
            or ABox_Settings.show, SHOW_MAXIMIZE
        .ELSE
            and ABox_Settings.show, NOT SHOW_MAXIMIZE
        .ENDIF

        point_GetTL [ebx].normalPosition
        point_Set ABox_Settings.mainWnd_pos

        neg eax
        neg edx

        point_AddBR [ebx].normalPosition
        point_Set ABox_Settings.mainWnd_siz

    ;// that's it

        add esp, SIZEOF WINDOWPLACEMENT
        pop ebx

        ret


app_GetWindowSettings ENDP






;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;///
;///    windows initialization
;///



ASSUME_AND_ALIGN
app_InitializeWindows PROC STDCALL  ;// uses esi edi

        ;// LOCAL rect:RECT
        LOCAL wndClass:WNDCLASSEXA


    ;/////////////////////////////////////////////////////
    ;//
    ;//
    ;//     registration
    ;//

        xor edi, edi    ;// use for zero

    ;//
    ;// set up the wndClass struct for the mainWnd
    ;//

        mov wndClass.cbSize, SIZEOF WNDCLASSEXA
        mov wndClass.style, CS_OWNDC OR CS_DBLCLKS
        mov wndClass.lpfnWndProc, OFFSET mainWndProc
        mov esi, hInstance
        mov wndClass.cbClsExtra, edi
        mov wndClass.cbWndExtra, edi
        mov wndClass.hInstance, esi
        invoke LoadIconA, esi, IDR_ABOX
        mov ebx, hCursor_normal
        mov  wndClass.hIcon, eax
        mov  wndClass.hIconSm, eax
        mov  wndClass.hCursor, ebx
        mov  wndClass.hbrBackground, edi
        mov  wndClass.lpszMenuName, edi
        mov  wndClass.lpszClassName, OFFSET mainWnd_szName

        invoke RegisterClassExA, ADDR wndClass
        and eax, 0FFFFh     ;// atoms are words
        mov mainWndAtom, eax

    ;//
    ;// register the create panel
    ;//
    ;// mov wndClass.style, CS_PARENTDC + CS_HREDRAW + CS_VREDRAW

        mov wndClass.hIcon, edi
        mov wndClass.hIconSm, edi
        mov wndClass.hbrBackground, COLOR_BTNFACE + 1
        mov wndClass.lpszMenuName, edi
        mov wndClass.lpfnWndProc, OFFSET create_Proc
        mov wndClass.lpszClassName, OFFSET create_szName

        invoke RegisterClassExA, ADDR wndClass
        and eax, 0FFFFh     ;// atoms are words
        mov create_atom, eax

    ;//
    ;// register the popup window
    ;//

        mov wndClass.lpfnWndProc, OFFSET popup_Proc
        mov  wndClass.lpszClassName, OFFSET popup_szName
        mov  wndClass.lpszMenuName, IDR_POPUP
        invoke RegisterClassExA, ADDR wndClass
        and eax, 0FFFFh ;// atoms are words
        mov popup_atom, eax

    ;//
    ;// register the BUS context menu
    ;//

        bus_Proc PROTO  ;// defined in bus.asm

        mov wndClass.lpfnWndProc, OFFSET bus_Proc
        mov wndClass.lpszMenuName, edi
        mov wndClass.lpszClassName, OFFSET bus_szName

        invoke RegisterClassExA, ADDR wndClass
        and eax, 0FFFFh ;// atoms are words
        mov bus_atom, eax

    ;//
    ;// register the diff_equation editor
    ;//

        mov wndClass.lpfnWndProc, OFFSET diff_Proc
        mov  wndClass.lpszClassName, OFFSET diff_szName
        invoke RegisterClassExA, ADDR wndClass
        and eax, 0FFFFh ;// atoms are words
        mov diff_atom, eax

    ;//
    ;// register the align panel
    ;//

        mov wndClass.lpfnWndProc, OFFSET align_Proc
        mov wndClass.lpszClassName, OFFSET align_atom
        invoke RegisterClassExA, ADDR wndClass
        and eax, 0FFFFh ;// atoms are words
        mov align_atom, eax

    ;//
    ;//
    ;//     registration
    ;//
    ;/////////////////////////////////////////////////////


    ;/////////////////////////////////////////////////////
    ;//
    ;//
    ;//     window creation
    ;//

    ;//
    ;// that being done, we try to create the main window
    ;// some settings depend on the registry
    ;//
    ;//     edi is still zero

        invoke about_SetLoadStatus

        MAINWND_STYLE = WS_CLIPCHILDREN OR  \
                        WS_THICKFRAME   OR  \
                        WS_MAXIMIZEBOX  OR  \
                        WS_MINIMIZEBOX  OR  \
                        WS_SYSMENU      OR  \
                        WS_HSCROLL      OR  \
                        WS_VSCROLL

        invoke CreateWindowExA, WS_EX_APPWINDOW, mainWndAtom, OFFSET sz_App_Title,
            MAINWND_STYLE,
            ABox_Settings.mainWnd_pos.x, ABox_Settings.mainWnd_pos.y,
            ABox_Settings.mainWnd_siz.x, ABox_Settings.mainWnd_siz.y,
            edi, edi, hInstance, edi
        mov hMainWnd, eax

    MESSAGE_LOG_PRINT_1 sz_hWndMain_is, eax, <"hWndMain = %8.8X">

    ;// make sure the title gets built

        or app_bFlags, APP_SYNC_TITLE OR APP_SYNC_SAVEBUTTONS

        invoke about_SetLoadStatus

    ;//
    ;// create an invisible window for the create popup
    ;//

        invoke CreateWindowExA, CREATE_STYLE_EX, create_atom,
            edi, CREATE_STYLE, edi, edi, ecx, ecx,
            hMainWnd, edi, hInstance, edi
        mov create_hWnd, eax

    MESSAGE_LOG_PRINT_1 sz_create_hWnd_is, eax, <"create_hWnd = %8.8X">

    ;//
    ;// create an invisible window for the context menu popup
    ;//

        invoke about_SetLoadStatus

        invoke CreateWindowExA, POPUP_STYLE_EX, popup_atom,
            edi, POPUP_STYLE,edi, edi,10, 10,
            hMainWnd, 0, hInstance, edi
        mov popup_hWnd, eax

    MESSAGE_LOG_PRINT_1 sz_popup_hWnd_is, eax, <"popup_hWnd = %8.8X">

    ;//
    ;// create a hidden window for the BUS popup
    ;//

        invoke about_SetLoadStatus

        invoke CreateWindowExA, BUS_STYLE_EX, bus_atom,
            edi, BUS_STYLE, edi, edi, 10, 10,
            hMainWnd, edi, hInstance, edi

    MESSAGE_LOG_PRINT_1 sz_bus_hWnd_is, eax, <"bus_hWnd = %8.8X">

    ;//
    ;// create a hidden window for the align panel
    ;//

        invoke about_SetLoadStatus

        invoke CreateWindowExA, ALIGN_STYLE_EX, align_atom,
            edi, ALIGN_STYLE, edi, edi, 10, 10,
            hMainWnd, edi, hInstance, edi

    MESSAGE_LOG_PRINT_1 sz_align_hWnd_is, eax, <"align_hWnd = %8.8X">

    ;//
    ;//     window creation
    ;//
    ;//
    ;/////////////////////////////////////////////////////


    ;// get the accelerators for the main wnd

        invoke about_SetLoadStatus

        invoke LoadAcceleratorsA, hInstance, IDR_ABOX
        DEBUG_IF <!!eax>    ;// did you forget to link these ?
        mov hAccel, eax

    ;// if the main window was maximized, we do that now

        invoke about_SetLoadStatus

        test ABox_Settings.show, SHOW_MAXIMIZE
        mov ebx, SW_SHOWNORMAL
        jz @F
        mov ebx, SW_SHOWMAXIMIZED
        or app_bFlags, APP_MODE_MAXIMIZED
    @@:
        invoke ShowWindow, hMainWnd, ebx
        invoke SetForegroundWindow, hMainWnd

    ;//
    ;// that's it
    ;//

        ret

app_InitializeWindows ENDP



;///
;///    windows initialization
;///
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////
;/////////////////////////////////////////////////////////////////////////////







;////////////////////////////////////////////////////////////////////
;//
;//
;//     generic osc creation
;//
comment ~ /*

    this function creates an osc
    hooks it to the mouse
    grabs capture to main window

    eax must have the id of the object
    the new object is returned in eax for no real reason

*/ comment ~



PROLOGUE_OFF
ASSUME_AND_ALIGN
app_CreateOsc PROC STDCALL uses ebp edi esi ebx pPosition:DWORD, dwId:DWORD

        push ebp
        push edi
        push esi
        push ebx

    ;// eax must have the id of the osc to create

    ;// if pPosition is NOT zero, then we do NOT grab the mouse
    ;// AND we create the osc at that position

        push eax    ;// store on stack

        sub esp, SIZEOF FILE_OSC ;// make some room fake_oFile FILE_OSC {}

    ;// stack
    ;// file    id  ebx esi edi ebp ret pPos dwId
    ;// 00      +0  +4  +8  +C  +10 +14 +18  +1C

        st_file TEXTEQU <(FILE_OSC PTR [esp])>
        st_id   TEXTEQU <(DWORD PTR [esp+SIZEOF FILE_OSC])>
        st_pos  TEXTEQU <(DWORD PTR [esp+SIZEOF FILE_OSC + 18h])>
        st_osc_id   TEXTEQU <(DWORD PTR [esp+SIZEOF FILE_OSC + 1Ch])>

        stack_size = SIZEOF FILE_OSC + 4

    ;// determine the position

        mov ecx, st_pos
        .IF !ecx

            ;// create at mouse pos

            invoke GetCursorPos, OFFSET mouse_now
            invoke ScreenToClient, hMainWnd, OFFSET mouse_now

            point_Get mouse_now
            point_Add GDI_GUTTER
            point_Set mouse_prev
            point_Set mouse_now

            sub eax, 6
            sub edx, 6

        .ELSE

            ASSUME ecx:PTR POINT
            point_Get [ecx]

        .ENDIF

        point_Set st_file.pos

    ;// locate the base class we want

        mov eax, st_id              ;// load the passed id
        FILE_ID_TO_BASE eax, edx, so_what
    so_what:
        DEBUG_IF <!!edx>            ;// couldn't find an object

    ;// setup the fake file record

        xor ecx, ecx
        mov st_file.pBase, edx      ;// store the base pointer
        mov st_file.numPins, ecx    ;// clear both feilds
        mov st_file.extra, ecx      ;// no extra data

    ;// create the object and register it in Z list

    stack_Peek gui_context, ebp

        mov edx, esp
        invoke osc_Ctor, edx, 0, 0  ;// no file header, no osc ids

        GET_OSC_FROM esi, eax   ;// save returned pointer in esi

    ;// now we check for how to leave the osc

        mov eax, st_osc_id
        mov [esi].id, eax

        .IF !eax

        ;// make sure we set this as osc_down and get the capture
        ;// make sure the rest of the app knows what happened

            mov osc_down, esi
            invoke SetCapture, hMainWnd

            or app_bFlags, APP_MODE_MOVING_OSC OR APP_SYNC_GROUP OR APP_SYNC_EXTENTS
            or mouse_state, MK_LBUTTON

        .ELSE

            hashd_Set unredo_id, eax, esi, edx  ;// make sure the id gets a new pointer
            or app_bFlags, APP_SYNC_GROUP OR APP_SYNC_EXTENTS

        .ENDIF

        mov eax, esi    ;// jic

        add esp, stack_size

        pop ebx
        pop esi
        pop edi
        pop ebp

        ret 8

        st_file TEXTEQU <>
        st_id   TEXTEQU <>
        st_pos  TEXTEQU <>
        st_osc_id   TEXTEQU <>

app_CreateOsc ENDP
PROLOGUE_ON
























;////////////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////////////
;////
;////
;////   E R R O R   H A N D L E R S
;////
;////

.DATA

    szSorry         db 'Sorry',0
    szPentium       db 'ABox requires a Pentium CPU.', 0
    szWarning       db 'Warning',0
    sz31_warning    db 'ABox2 will not run on Windows 3.1.',0

    ALIGN 4

.CODE


ASSUME_AND_ALIGN
app_SystemCheck PROC STDCALL

    ;// this is the first function called by the program
    ;// we return 0 if we want to exit the application

        LOCAL sys:SYSTEM_INFO
        LOCAL ver:OSVERSIONINFO

    ;// check for compatible CPU

        invoke GetSystemInfo, ADDR sys

        .IF sys.dwProcessorType < 586

            invoke MessageBoxA, 0, OFFSET szPentium, OFFSET szSorry, MB_ICONHAND + MB_OK + MB_SYSTEMMODAL
            xor eax, eax
            jmp AllDone

        .ENDIF

        mov eax, 1
        cpuid
        ;// and edx, NOT 10h    ;// debug check, turn off rdtsc
        mov app_CPUFeatures, edx

    ;// Check Windows version

        mov ver.dwOSVersionInfoSize, SIZEOF OSVERSIONINFO
        invoke GetVersionExA, ADDR ver
        mov eax, ver.dwPlatformId
        mov app_dwPlatformID, eax

        cmp eax, VER_PLATFORM_WIN32s
        mov eax, 1
        .IF ZERO?

            invoke MessageBoxA, 0, OFFSET sz31_warning, OFFSET szWarning, MB_ICONEXCLAMATION + MB_YESNO + MB_SYSTEMMODAL
            xor eax, eax
            jmp AllDone

        .ENDIF

    ;// ABOX242 -- AJT -- Add support for VirtualProtect
    ;// Get values for VirtualProtect and FlushInstructionCache
    ;// they might not exist
        .DATA
        sz_KERNEL_DLL db 'kernel32.dll',0
        sz_VirtualProtect db 'VirtualProtect',0
        ;//sz_FlushInstructionCache db 'FlushInstructionCache',0
        ALIGN 4
        pfVirtualProtect        dd  0
        ;//pfFlushInstructionCache dd  0
        .CODE    
        invoke LoadLibraryA, OFFSET sz_KERNEL_DLL
        .IF !eax
            int 3
        .ENDIF            
        .IF eax
            push eax                            ;// arg FreeLibrary
            push OFFSET sz_VirtualProtect       ;// arg GetProcAddress.pFunctionName
            push eax                            ;// arg GetProcaddress.hLib
            call GetProcAddress
            mov pfVirtualProtect, eax
            ;// iff the fucntion fails -- NULL -- then I guess we don't need to call it ...
            call FreeLibrary
        .ENDIF

    ;// xfer the paging size

        mov eax, sys.dwAllocationGranularity
        mov app_AllocationGranularity, eax
        ;// verify that is only one bit is set

        xor edx, edx        ;// counter
    top_of_bitscan:
        xor ecx, ecx        ;// clear just in case
        bsf ecx, eax        ;// scan the bits
        jz done_with_bitscan;// done if none found
        inc edx             ;// bump the bit count
        btr eax, ecx        ;// turn off the bit
        jmp top_of_bitscan  ;// do again
    done_with_bitscan:
        add eax, edx        ;// make eax = 1
        dec edx             ;// how many were on
        DEBUG_IF <!!ZERO?>  ;// more than one bit was on

AllDone:

    ret

app_SystemCheck ENDP




;////
;////
;////   E R R O R   H A N D L E R S
;////
;////
;////////////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN



END app_Main

















