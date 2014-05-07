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
;// auto_unit.asm       routines to manage the various units
;//
;// TOC:
;//
;// unit_FillListBox
;// unit_BuildString
;// unit_ConvertOld
;// unit_AutoTrace


OPTION CASEMAP:NONE

.586
.MODEL FLAT

        .NOLIST
        INCLUDE <Abox.inc>
        INCLUDE <szfloat.inc>
        .LIST

.DATA

    ;// UNIT TO DESK COLOR

        unit_desk_color LABEL DWORD

            dd F_COLOR_DESK_DEFAULT     ;// 0 VALUE
            dd F_COLOR_DESK_FREQUENCY   ;// 1 INTERVL
            dd F_COLOR_DESK_DEFAULT     ;// 2 DB
            dd F_COLOR_DESK_FREQUENCY   ;// 3 HERTZ
            dd F_COLOR_DESK_MIDI        ;// 4 MIDI
            dd F_COLOR_DESK_FREQUENCY   ;// 5 SECONDS
            dd F_COLOR_DESK_FREQUENCY   ;// 6 NOTE
            dd F_COLOR_DESK_FREQUENCY   ;// 7 BPM
            dd F_COLOR_DESK_FREQUENCY   ;// 8 SAMPLES
            dd F_COLOR_DESK_LOGIC       ;// 9 LOGIC
            dd F_COLOR_DESK_SPECTRAL    ;// A BINS
            dd F_COLOR_DESK_DEFAULT     ;// B DEGREES
            dd F_COLOR_DESK_DEFAULT     ;// C PANNER
            dd F_COLOR_DESK_DEFAULT     ;// D PERCENT
            dd F_COLOR_DESK_FREQUENCY   ;// E 2xHERTZ
            dd F_COLOR_DESK_STREAM      ;// F MIDI_STREAM
            dd F_COLOR_DESK_SPECTRAL    ;// 10 SPECTRUM
            dd  0       ;// 11
            dd  0       ;// 12
            dd  0       ;// 13
            dd  0       ;// 14
            dd  0       ;// 15
            dd  0       ;// 16
            dd  0       ;// 17
            dd  0       ;// 18
            dd  0       ;// 19
            dd  0       ;// 1A
            dd  0       ;// 1B
            dd  0       ;// 1C
            dd  0       ;// 1D
            dd  0       ;// 1E
            dd  0       ;// 1F

    ;// UNIT TO PIN COLOR

        unit_pin_color LABEL DWORD

            dd F_COLOR_PIN_DEFAULT      ;// 0 VALUE
            dd F_COLOR_PIN_FREQUENCY    ;// 1 INTERVL
            dd F_COLOR_PIN_DEFAULT      ;// 2 DB
            dd F_COLOR_PIN_FREQUENCY    ;// 3 HERTZ
            dd F_COLOR_PIN_MIDI         ;// 4 MIDI
            dd F_COLOR_PIN_FREQUENCY    ;// 5 SECONDS
            dd F_COLOR_PIN_FREQUENCY    ;// 6 NOTE
            dd F_COLOR_PIN_FREQUENCY    ;// 7 BPM
            dd F_COLOR_PIN_FREQUENCY    ;// 8 SAMPLES
            dd F_COLOR_PIN_LOGIC        ;// 9 LOGIC
            dd F_COLOR_PIN_SPECTRAL     ;// A BINS
            dd F_COLOR_PIN_DEFAULT      ;// B DEGREES
            dd F_COLOR_PIN_DEFAULT      ;// C PANNER
            dd F_COLOR_PIN_DEFAULT      ;// D PERCENT
            dd F_COLOR_PIN_FREQUENCY    ;// E 2xHERTZ
            dd F_COLOR_PIN_STREAM       ;// F MIDI_STREAM
            dd F_COLOR_PIN_SPECTRAL     ;// 10 SEPCTRUM
            dd  0       ;// 11
            dd  0       ;// 12
            dd  0       ;// 13
            dd  0       ;// 14
            dd  0       ;// 15
            dd  0       ;// 16
            dd  0       ;// 17
            dd  0       ;// 18
            dd  0       ;// 19
            dd  0       ;// 1A
            dd  0       ;// 1B
            dd  0       ;// 1C
            dd  0       ;// 1D
            dd  0       ;// 1E
            dd  0       ;// 1F


    ;// UNIT TO SCALE

        unit_scale  LABEL DWORD

            REAL4   1.0e+0          ;// 0 VALUE
            REAL4   0.0             ;// 1 INTERVL
            REAL4   6.02059994e+0   ;// 2 DB        20/log2(10)
            REAL4   22050.0000e+0   ;// 3 HERTZ     1/2 of sample rate
            REAL4   128.0           ;// 4 MIDI      128 notes per range
            REAL4   4.53514795e-5   ;// 5 SECONDS   1/scale_hertz
            REAL4   2.69698413E+3   ;// 6 NOTE      (middle c)
            REAL4   1.32300000e+6   ;// 7 BPM       sample_rate/2 * 60 sec/minute
            REAL4   1024.0          ;// 8 SAMPLES   1024 samples per fram
            REAL4   0.0             ;// 9 LOGIC
            REAL4   512.00000e+0    ;// A BINS      512 bins per frame
            REAL4   180.0           ;// B DEGREES   360 degrees per circle
            REAL4   100.0           ;// C PANNER    100 percent
            REAL4   100.0           ;// D PERCENT   100 percent
            REAL4   44100.0         ;// E 2xHERTZ   sample rate
            REAL4   0.0             ;// F MIDI_STREAM
            REAL4   0.0             ;// 10 SPECTRUM
            REAL4   0.0     ;// 11
            REAL4   0.0     ;// 12
            REAL4   0.0     ;// 13
            REAL4   0.0     ;// 14
            REAL4   0.0     ;// 15
            REAL4   0.0     ;// 16
            REAL4   0.0     ;// 17
            REAL4   0.0     ;// 18
            REAL4   0.0     ;// 19
            REAL4   0.0     ;// 1A
            REAL4   0.0     ;// 1B
            REAL4   0.0     ;// 1C
            REAL4   0.0     ;// 1D
            REAL4   0.0     ;// 1E
            REAL4   0.0     ;// 1F

    ;// UNIT TO BUILDER

            dd build_auto       ;// auto must be before table
        unit_builder    LABEL DWORD
            dd build_value      ;// 0 VALUE
            dd build_interval   ;// 1 INTERVL
            dd build_dB         ;// 2 DB
            dd build_hertz      ;// 3 HERTZ
            dd build_midi       ;// 4 MIDI
            dd build_seconds    ;// 5 SECONDS
            dd build_note       ;// 6 NOTE
            dd build_BPM        ;// 7 BPM
            dd build_samples    ;// 8 SAMPLES
            dd build_bool       ;// 9 LOGIC
            dd build_bins       ;// A BINS
            dd build_degrees    ;// B DEGREES
            dd build_pan        ;// C PANNER
            dd build_percent    ;// D PERCENT
            dd build_2xhertz    ;// E 2xHERTZ
            dd build_midi_stream;// F MIDI_STREAM
            dd build_spectrum   ;// 10 SPECTRUM
            dd  0       ;// 11
            dd  0       ;// 12
            dd  0       ;// 13
            dd  0       ;// 14
            dd  0       ;// 15
            dd  0       ;// 16
            dd  0       ;// 17
            dd  0       ;// 18
            dd  0       ;// 19
            dd  0       ;// 1A
            dd  0       ;// 1B
            dd  0       ;// 1C
            dd  0       ;// 1D
            dd  0       ;// 1E
            dd  0       ;// 1F

    ;// UNIT TO ID

comment ~ /*

            dd ID_UNIT_AUTO     ;// -1, must be before table

        unit_to_id  LABEL DWORD

            dd ID_UNIT_VALUE    ;// 0 VALUE
            dd ID_UNIT_INTERVAL ;// 1 INTERVL
            dd ID_UNIT_DB       ;// 2 DB
            dd ID_UNIT_HERTZ    ;// 3 HERTZ
            dd ID_UNIT_MIDI     ;// 4 MIDI
            dd ID_UNIT_SECONDS  ;// 5 SECONDS
            dd ID_UNIT_NOTE     ;// 6 NOTE
            dd ID_UNIT_BPM      ;// 7 BPM
            dd ID_UNIT_SAMPLES  ;// 8 SAMPLES
            dd ID_UNIT_LOGIC    ;// 9 LOGIC
            dd ID_UNIT_BINS     ;// A BINS
            dd ID_UNIT_DEGREES  ;// B DEGREES
            dd ID_UNIT_PANNER   ;// C PANNER
            dd ID_UNIT_PERCENT  ;// D PERCENT
            dd 0        ;// E 2xHERTZ
            dd 0        ;// F MIDI_STREAM
            dd  0       ;// 10  SPECTRUM
            dd  0       ;// 11
            dd  0       ;// 12
            dd  0       ;// 13
            dd  0       ;// 14
            dd  0       ;// 15
            dd  0       ;// 16
            dd  0       ;// 17
            dd  0       ;// 18
            dd  0       ;// 19
            dd  0       ;// 1A
            dd  0       ;// 1B
            dd  0       ;// 1C
            dd  0       ;// 1D
            dd  0       ;// 1E
            dd  0       ;// 1F

*/ comment ~

    ;// UNIT TO LABEL

            dd 'otua'   ;// 10  auto    ;// must be before table
        unit_label  LABEL DWORD
            dd 'lav'    ;// 0 VALUE
            dd 'tni'    ;// 1 INTERVL
            dd 'Bd'     ;// 2 DB
            dd 'zH'     ;// 3 HERTZ
            dd 'idim'   ;// 4 MIDI
            dd 'ceS'    ;// 5 SECONDS
            dd 'eton'   ;// 6 NOTE
            dd 'MPB'    ;// 7 BPM
            dd 'mas'    ;// 8 SAMPLES
            dd 'loob'   ;// 9 LOGIC
            dd 'nib'    ;// A BINS
            dd 'ged'    ;// B DEGREES
            dd 'nap'    ;// C PANNER
            dd '%'      ;// D PERCENT
            dd '2zH'    ;// E 2xHERTZ
            dd 'mrts'   ;// F MIDI_STREAM
            dd 'ceps'   ;// 10  SPECTRUM
            dd  0       ;// 11
            dd  0       ;// 12
            dd  0       ;// 13
            dd  0       ;// 14
            dd  0       ;// 15
            dd  0       ;// 16
            dd  0       ;// 17
            dd  0       ;// 18
            dd  0       ;// 19
            dd  0       ;// 1A
            dd  0       ;// 1B
            dd  0       ;// 1C
            dd  0       ;// 1D
            dd  0       ;// 1E
            dd  0       ;// 1F

    ;// new scale, multiply by a value to convert from 120 range to 128 range

        knob_new_midi_scale REAL4 0.93750000e+0

    ;// text for notes, word aligned fields
    ;// octaves wrap at C, C0 is the lowest note
        ;// arranged as words  | | | | | | | | | | | |
        unit_text_notes    db ' CC# DEb E FF# GAb ABb B'
        ALIGN 4
        ;// unit_text_interval db 'r 7 b76 #55 b54 3 b32 b2'

        unit_interval_text dd 'tco' ,'ht7','ht7b','ht6' ,'ht5#','ht5' ,'ht5b','ht4' ,'dr3' ,'dr3b','dn2' ,'dn2b'

.DATA

;//////////////////////////////////////////////////////////////////////
;//
;//
;//     popup combo box support
;//
;//

comment ~ /*


        These two functions help manage combo boxes for units

    unit_UpdateListBox

        call this to initialize and select the current unit

    unit_HandleComboSelChange

        call this on _SELCHANGE messages
        it will update the help text for the control
        and set eax as an appropriate return value for popup

    the tables that follow allow all of this

*/ comment ~


    list_unit_table LABEL DWORD
        ;// string ptr      ,UNIT
        dd  sz_list_auto    ,UNIT_AUTO_UNIT     ;// 10  auto
        dd  sz_list_value   ,UNIT_VALUE         ;// 0 VALUE
        dd  sz_list_interval,UNIT_INTERVAL      ;// 1 INTERVL
        dd  sz_list_decibel ,UNIT_DB            ;// 2 DB
        dd  sz_list_hertz   ,UNIT_HERTZ         ;// 3 HERTZ
        dd  sz_list_midi    ,UNIT_MIDI          ;// 4 MIDI
        dd  sz_list_seconds ,UNIT_SECONDS       ;// 5 SECONDS
        dd  sz_list_note    ,UNIT_NOTE          ;// 6 NOTE
        dd  sz_list_tempo   ,UNIT_BPM           ;// 7 BPM
        dd  sz_list_samples ,UNIT_SAMPLES       ;// 8 SAMPLES
        dd  sz_list_logic   ,UNIT_LOGIC         ;// 9 LOGIC
        dd  sz_list_bins    ,UNIT_BINS          ;// A BINS
        dd  sz_list_degrees ,UNIT_DEGREES       ;// B DEGREES
        dd  sz_list_panner  ,UNIT_PANNER        ;// C PANNER
        dd  sz_list_percent ,UNIT_PERCENT       ;// D PERCENT
        dd  0


    ;// UNIT FROM ID (not including Hertx2X or MidiStream

    unit_from_id LABEL DWORD

            dd  UNIT_BINS       ;// VK_B
            dd  UNIT_PERCENT    ;// VK_C
            dd  UNIT_DB         ;// VK_D
            dd  UNIT_SAMPLES    ;// VK_E
            dd  -1              ;//    F
            dd  UNIT_DEGREES    ;// VK_G
            dd  UNIT_HERTZ      ;// VK_H
            dd  UNIT_INTERVAL   ;// VK_I
            dd  -1              ;//    J
            dd  -1              ;//    K
            dd  -1              ;//    L
            dd  UNIT_MIDI       ;// VK_M
            dd  UNIT_NOTE       ;// VK_N
            dd  UNIT_LOGIC      ;// VK_O
            dd  UNIT_BPM        ;// VK_P
            dd  -1              ;//    Q
            dd  UNIT_PANNER     ;// VK_R
            dd  UNIT_SECONDS    ;// VK_S
            dd  UNIT_AUTO_UNIT  ;// VK_T
            dd  -1              ;//    U
            dd  UNIT_VALUE      ;// VK_V


    ;// part of popup help
    sz_KNOB_IDC_STATIC_UNITS    LABEL BYTE
    sz_READOUT_IDC_STATIC_UNITS LABEL BYTE
    db 'Set the units to display. '
    db 'Changes the pin coloring and other auto-unit objects. '
    db '[knob commands]. {hotkey}.',0


    sz_list_auto        db 'Auto Units',0       ;// 10  auto
    sz_list_value       db 'Value',0            ;// 0 VALUE
    sz_list_interval    db 'Musical Interval',0 ;// 1 INTERVL
    sz_list_decibel     db 'Decibels',0         ;// 2 DB
    sz_list_hertz       db 'Hertz',0            ;// 3 HERTZ
    sz_list_midi        db 'Midi number',0      ;// 4 MIDI
    sz_list_seconds     db 'Seconds',0          ;// 5 SECONDS
    sz_list_note        db 'Musical Note',0     ;// 6 NOTE
    sz_list_tempo       db 'Beats Per Minute',0 ;// 7 BPM
    sz_list_samples     db 'Samples',0          ;// 8 SAMPLES
    sz_list_logic       db 'Logic true false',0 ;// 9 LOGIC
    sz_list_bins        db 'FFT Bins',0         ;// A BINS
    sz_list_degrees     db 'Degrees Phase',0    ;// B DEGREES
    sz_list_panner      db 'Pan left right',0   ;// C PANNER
    sz_list_percent     db 'Percent',0          ;// D PERCENT
    ALIGN 4


        dd  sz_isknob_UNIT_AUTO     ;// -1  auto    ;// must be before table
    list_help_table_isknob LABEL DWORD
        dd  sz_isknob_UNIT_VALUE    ;// 0 VALUE
        dd  sz_isknob_UNIT_INTERVAL ;// 1 INTERVL
        dd  sz_isknob_UNIT_DB       ;// 2 DB
        dd  sz_isknob_UNIT_HERTZ    ;// 3 HERTZ
        dd  sz_isknob_UNIT_MIDI     ;// 4 MIDI
        dd  sz_isknob_UNIT_SECONDS  ;// 5 SECONDS
        dd  sz_isknob_UNIT_NOTE     ;// 6 NOTE
        dd  sz_isknob_UNIT_BPM      ;// 7 BPM
        dd  sz_isknob_UNIT_SAMPLES  ;// 8 SAMPLES
        dd  sz_isknob_UNIT_LOGIC    ;// 9 LOGIC
        dd  sz_isknob_UNIT_BINS     ;// A BINS
        dd  sz_isknob_UNIT_DEGREES  ;// B DEGREES
        dd  sz_isknob_UNIT_PANNER   ;// C PANNER
        dd  sz_isknob_UNIT_PERCENT  ;// D PERCENT

        dd  sz_noknob_UNIT_AUTO     ;// -1  auto    ;// must be before table
    list_help_table_noknob LABEL DWORD
        dd  sz_noknob_UNIT_VALUE    ;// 0 VALUE
        dd  sz_noknob_UNIT_INTERVAL ;// 1 INTERVL
        dd  sz_noknob_UNIT_DB       ;// 2 DB
        dd  sz_noknob_UNIT_HERTZ    ;// 3 HERTZ
        dd  sz_noknob_UNIT_MIDI     ;// 4 MIDI
        dd  sz_noknob_UNIT_SECONDS  ;// 5 SECONDS
        dd  sz_noknob_UNIT_NOTE     ;// 6 NOTE
        dd  sz_noknob_UNIT_BPM      ;// 7 BPM
        dd  sz_noknob_UNIT_SAMPLES  ;// 8 SAMPLES
        dd  sz_noknob_UNIT_LOGIC    ;// 9 LOGIC
        dd  sz_noknob_UNIT_BINS     ;// A BINS
        dd  sz_noknob_UNIT_DEGREES  ;// B DEGREES
        dd  sz_noknob_UNIT_PANNER   ;// C PANNER
        dd  sz_noknob_UNIT_PERCENT  ;// D PERCENT

        sz_isknob_UNIT_AUTO     db  'Let ABox try to figure out what the units are. [auto] { T }',0
        sz_isknob_UNIT_VALUE    db  'Actual numeric value. [value val] { V }',0
        sz_isknob_UNIT_INTERVAL db  'Musical interval when a frequency is multiplied by this value. { I }',0
        sz_isknob_UNIT_DB       db  'Decibels attenuation when multiplied by this value. [decibel(s) dB] { D }',0
        sz_isknob_UNIT_HERTZ    db  'Frequency in Hertz. Cycles per second. [hertz Hz KHz mHz uHz] { H }',0
        sz_isknob_UNIT_MIDI     db  'Midi note or value. [midi] { M }',0
        sz_isknob_UNIT_SECONDS  db  'Time in seconds. 1/Frequency. [second(s) Sec S mS uS] { S }',0
        sz_isknob_UNIT_NOTE     db  'Musical note. Frequency. [note] { N }',0
        sz_isknob_UNIT_BPM      db  'Beats Per Minute. [tempo BPM] { P }',0
        sz_isknob_UNIT_SAMPLES  db  'Samples. Delay. [sample(s) sam] { E }',0
        sz_isknob_UNIT_LOGIC    db  'Logical TRUE or FALSE. [logic bool true false] { O }',0
        sz_isknob_UNIT_BINS     db  'Spectrum Bin number. Spectrum. [bin(s)] { B }',0
        sz_isknob_UNIT_DEGREES  db  'Degrees. Phase. [degree(s) deg] { G }',0
        sz_isknob_UNIT_PANNER   db  'Pan left or right. [pan L R left right center] { R }',0
        sz_isknob_UNIT_PERCENT  db  'Percentage. [percent %] { C }',0

        sz_noknob_UNIT_AUTO     db  'Let ABox try to figure out what the units are. { T }',0
        sz_noknob_UNIT_VALUE    db  'Actual numeric value. { V }',0
        sz_noknob_UNIT_INTERVAL db  'Musical interval when a frequency is multiplied by this value. { I }',0
        sz_noknob_UNIT_DB       db  'Decibels attenuation when multiplied by this value. { D }',0
        sz_noknob_UNIT_HERTZ    db  'Frequency in Hertz. Cycles per second. { H }',0
        sz_noknob_UNIT_MIDI     db  'Midi note or value. { M }',0
        sz_noknob_UNIT_SECONDS  db  'Time in seconds. 1/Frequency. { S }',0
        sz_noknob_UNIT_NOTE     db  'Musical note. Frequency. { N }',0
        sz_noknob_UNIT_BPM      db  'Beats Per Minute. { P }',0
        sz_noknob_UNIT_SAMPLES  db  'Samples. Delay. { E }',0
        sz_noknob_UNIT_LOGIC    db  'Logical TRUE or FALSE. { O }',0
        sz_noknob_UNIT_BINS     db  'Spectrum Bin number. Spectrum. { B }',0
        sz_noknob_UNIT_DEGREES  db  'Degrees. Phase. { G }',0
        sz_noknob_UNIT_PANNER   db  'Pan left or right. { R }',0
        sz_noknob_UNIT_PERCENT  db  'Percentage. { C }',0

        ALIGN 4



.CODE

PROLOGUE_OFF
ASSUME_AND_ALIGN
unit_UpdateComboBox PROC STDCALL dwID:DWORD, bIsKnob:DWORD

        push ebx
        push edi

    ;// stack
    ;// edi ebx ret dwID IsKnob
    ;// 00  04  08  0C   10

        ASSUME esi:PTR OSC_OBJECT
        ;// osc.dwUser must have UNITS in the correct spot

    ;// dwID must be the command id of a COMBOBOX

    ;// if empty, fill in the units list
    ;// determine which item is the current selection
    ;// set the help text for the selected item

        ;// get the window handle

            invoke GetDlgItem, popup_hWnd, DWORD PTR [esp+0Ch]
            mov ebx, eax

        ;// add all the strings and set the item data as the UNIT

            WINDOW ebx,CB_GETCOUNT
            .IF !eax

                xor edi, edi
                .REPEAT

                    WINDOW ebx,CB_ADDSTRING,0,list_unit_table[edi*8]
                    WINDOW ebx,CB_SETITEMDATA, eax, list_unit_table[edi*8+4]
                    inc edi

                .UNTIL !list_unit_table[edi*8]

            .ENDIF

        ;// locate the now sorted item that corresponds to our setting
        ;// set it as the current selection
        ;// and define the help text for the whole combo box

        push esi

        ;// stack
        ;// esi edi ebx ret dwID IsKnob
        ;// 00  04  08  0C  10   14

            mov esi, [esi].dwUser
            xor edi, edi
            and esi, UNIT_TEST OR UNIT_AUTO_UNIT
            .IF esi & UNIT_AUTO_UNIT
                and esi, UNIT_AUTO_UNIT
            .ENDIF
            .REPEAT
                WINDOW ebx,CB_GETITEMDATA,edi,0
                .IF eax == esi
                    WINDOW ebx,CB_SETCURSEL,edi
                    BITSHIFT esi, UNIT_INTERVAL, 1
                    .IF CARRY?
                        dec esi
                    .ENDIF
                    .IF DWORD PTR [esp+14h]
                        mov eax, list_help_table_isknob[esi*4]
                    .ELSE
                        mov eax, list_help_table_noknob[esi*4]
                    .ENDIF
                    invoke SetWindowLongA, ebx, GWL_USERDATA, eax
                    .BREAK
                .ENDIF
                inc edi
            .UNTIL !list_unit_table[edi*8]

        pop esi
        pop edi
        pop ebx

        retn 8  ;// STDCALL 2 arg

unit_UpdateComboBox ENDP
PROLOGUE_ON


ASSUME_AND_ALIGN
PROLOGUE_OFF
unit_HandleComboSelChange PROC STDCALL dwID:DWORD, dwUnit:DWORD, bIsKnob:DWORD

    ;// get the string and set the main help text
    ;// return eax = popup command return values
    ;//        edx as ptr to string to update help text for

    ;// dwID must be the command id of a COMBOBOX
    ;// dwUnit must be the user value set by unit_UpdateListBox

    ;// stack
    ;// ret dwID dwUnit
    ;// 00  04   08

    ;// get the window handle

        xchg ebx, [esp+4]   ;// load id and preserve ebx
        invoke GetDlgItem, popup_hWnd, ebx
        mov ebx, eax

    ;// build the string pointer from the unit

        mov edx, [esp+8]
        BITSHIFT edx, UNIT_INTERVAL, 1
        .IF CARRY?
            DEBUG_IF <!!ZERO?>  ;// extra bits !!!
            dec edx
        .ENDIF

    ;// set the help text

        .IF DWORD PTR [esp+0Ch]
            mov eax, list_help_table_isknob[edx*4]
        .ELSE
            mov eax, list_help_table_noknob[edx*4]
        .ENDIF
        push eax

        invoke SetWindowLongA,ebx,GWL_USERDATA,eax ;// list_help_table[edx*4]

    ;// return appropriate values
    ;// return that we want to update the help immediately

        pop edx ;// return edx as pointer to string
        mov eax, POPUP_IGNORE OR POPUP_REFRESH_STATUS

    ;// done

        mov ebx, [esp+4]
        retn 0Ch    ;// STDCALL 3 args


unit_HandleComboSelChange ENDP
PROLOGUE_ON

;//
;//
;//     popup combo box support
;//
;//
;//////////////////////////////////////////////////////////////////////


;//////////////////////////////////////////////////////////////////////
;//
;//
;//     object keyboard support
;//
;//

.CODE

ASSUME_AND_ALIGN
unit_FromKeystroke PROC

    ;// eax must have the command id
    ;// return no carry flag if unit not found
    ;// returns edx as unit if is found

    ;// destroys edx

        mov edx, eax

        sub edx, ID_UNIT_VALUE
        ja all_done
        add edx, ID_UNIT_VALUE-ID_UNIT_BINS;// max - min
        cmp edx, ID_UNIT_VALUE-ID_UNIT_BINS
        ja all_done
        mov edx, unit_from_id[edx*4]    ;// load the id
        cmp edx, -1                     ;// clears carry if below

    all_done:

        ret

unit_FromKeystroke ENDP



;//
;//
;//     object keyboard support
;//
;//
;//////////////////////////////////////////////////////////////////////





















PROLOGUE_OFF
ASSUME_AND_ALIGN
unit_BuildString PROC STDCALL pszBuffer:DWORD, dwUnits:DWORD, dwFmtFlags:DWORD

;// value to format must be in FPU (destroyed)
;// pBuffer size is NOT checked, 24 bytes should be enough

;// dwFmtFlags  UBS_SEPARATE_EXP    EQU 00000001h   ;// put a space between value and e+xx
;//             UBS_APPEND_NEG      EQU 00000002h   ;// for db int and note, add a neg suffix

                                                    ;// if raw value is negative

;// preserves esi edi ebx ecx
;// returns eax as end of string

;// dwUnit the pin.dwStatus UNIT format

;// stack
;// ret     pBuffer dwUnits dwFormat
;// 00      04      08      0C

    st_buf  TEXTEQU <(DWORD PTR [esp+04h])>
    st_unit TEXTEQU <(DWORD PTR [esp+08h])>
    st_fmt  TEXTEQU <(DWORD PTR [esp+0Ch])>


    ;// preserve registers and load parameters

    ;// determine correct auto state
    ;// auto autoed use
    ;// 0   x       1
    ;// 0   x       1
    ;// 1   0       0
    ;// 1   1       1

        xchg ecx, st_unit       ;// ecx will index the units
        xor eax, eax            ;// must be zero
        xchg edi, st_buf        ;// edi iterates the ouput buffer
        test ecx, UNIT_AUTO_UNIT;// check for auto unit
        xchg ebx, st_fmt        ;// ebx holds format flags

        jnz check_autoed

    use_unit:

        and ecx, UNIT_TEST
        BITSHIFT ecx, UNIT_INTERVAL, 4  ;// need a dword offset
        jmp unit_builder[ecx]

    check_autoed:

        test ecx, UNIT_AUTOED
        jnz use_unit
        mov ecx, -4         ;// must set as a dword offset
        jmp unit_builder[-4]


    ASSUME edi:PTR BYTE

    ALIGN 16
    build_pan::

        ;// L 100%
        ;// R 100%
        ;// center

            ftst
            fnstsw ax
            sahf
            jz p_zero
            jnc p_pos
        p_neg:
            xor eax, eax
            mov ax, ' R'
            fabs
            jmp p_per
        p_pos:
            xor eax, eax
            mov ax, ' L'
        p_per:
            fabs
            stosw
            xor eax, eax
            fmul math_100
            push edx
            fistp DWORD PTR [esp]
            pop eax

            cmp eax, 100
            jb p_99

            mov eax, '%001'
            stosd
            jmp tack_on_filler

        p_99:

            aam
            or ah, ah
            jz p_9

            xchg ah,al
            add ax, '00'
            stosw
            mov al, '%'
            stosb
            jmp tack_on_filler

        p_9:

            add ax, '%0'
            stosw
            jmp tack_on_filler

        p_zero: ;//  cent er

            mov eax, 'tnec'
            fstp st
            stosd
            mov ax, 're'
            stosw

            jmp tack_on_filler



    ALIGN 16
    build_seconds::

        ;// +0.0000
        ;//   sec

        ;// check for zero

            ftst
            fnstsw ax
            sahf
            jz got_Infinity

            fdivr unit_scale[ecx]
            mov edx, FLOATSZ_ENG OR FLOATSZ_DIG_5 OR FLOATSZ_SPACE
            invoke float_to_sz
            jmp tack_on_unit


    ALIGN 16
    build_note::

        ;// assume A=440
        ;// use labels from knob_text_notes

        ;// check for zero

            ftst
            fnstsw ax
            sahf
            jz got_overload ;// note is negative
            .IF CARRY? && ebx & UBS_APPEND_NEG
                or ebx, 80000000h
            .ENDIF

        ;// value is not zero

            fabs          ;// dQ
            fld1          ;// 1  dQ
            fxch          ;// dQ 1

            fmul unit_scale[ecx]  ;// Q1dQ 1
            fyl2x         ;// N

            ftst
            fnstsw  ax
            sahf
            jc got_overload ;// note is negative

        ;// note is not negative

            fld st        ;// N   N
            fsub math_1_2
            frndint       ;// oct   N
            fxch          ;// N   oct
            fsub st, st(1);// N-oct N
            fmul math_12
                          ;// dNote oct
            fld st        ;// dNote dNote oct
            frndint       ;// note  dNote oct
            fxch          ;// dNote note    oct
            fsub st, st(1)
            fmul math_100
            frndint       ;// cent  note    oct

            sub esp, 12 ;// room for 3 dwords

            st_tempCent TEXTEQU <( DWORD PTR [esp+8] )> ;// tempCent
            st_tempNote TEXTEQU <( DWORD PTR [esp+4] )> ;// tempNote
            st_tempOct  TEXTEQU <( DWORD PTR [esp]   )> ;// tempOct

            fistp st_tempCent
            fistp st_tempNote
            fistp st_tempOct

        ;// now we format the value

            mov edx, st_tempNote

            ;// check if note == 12
            .IF edx == 12
                xor edx, edx
                inc st_tempOct
            .ENDIF

            mov ax, WORD PTR [unit_text_notes+edx*2]
            mov WORD PTR [edi], ax

        ;// with this formula, octave is one too high
        ;// so we decrement and adjust for the minus sign

            mov ax, WORD PTR st_tempOct
            dec ax
            .IF !SIGN?          ;// assume we're ok
                .WHILE al > 9
                    sub al, 10
                    inc ah
                .ENDW
                xchg al, ah
                add ax, 3030h
                mov WORD PTR [edi+2], ax
            .ELSE
                mov WORD PTR [edi+2], '1-'
            .ENDIF

            xor eax, eax
            or eax, st_tempCent
            .IF SIGN?
                ;// cents is negative
                neg eax
                mov [edi+4],'-'
            .ELSE
                mov [edi+4],'+'
            .ENDIF

            .WHILE al > 9
                sub al, 10
                inc ah
            .ENDW
            xchg al, ah
            add ax, 3030h
            mov WORD PTR [edi+5], ax

            add edi, 7  ;// need to advance edi

        ;// clean up the stack and jump to tack on units

            add esp, 12

            st_tempCent TEXTEQU <>  ;// tempCent
            st_tempNote TEXTEQU <>  ;// tempNote
            st_tempOct  TEXTEQU <> ;// tempOct

            jmp tack_on_filler


    ALIGN 16
    build_interval::

        ;// log will always be negative
        ;// but the numbers come out right
        ;// use labels from knob_text_interval
        ;// see Note_01.mcd for formula

        ;// check for zero

            ftst
            fnstsw ax
            sahf

            .IF ZERO? ;// dQ==0

                ;// note is invalid
                fstp st

                mov eax, '####'
                stosd
                and eax, 00ffffffh
                stosd
                dec edi

                jmp term_and_done

            .ENDIF

            .IF CARRY? && ebx & UBS_APPEND_NEG
                or ebx, 80000000h
            .ENDIF

        ;// note is a valid value

            fabs          ;// dQ
            fld math_1    ;// 1  dQ
            fxch          ;// dQ 1
            fyl2x         ;// N
            fabs

        ;// assume this is a valid value
        ;// even though it's negative

            fld st        ;// N   N
            fsub math_1_2
            frndint       ;// oct   N
            fxch          ;// N   oct
            fsub st, st(1);// N-oct N
            fmul math_12
                          ;// dNote oct
            fld st        ;// dNote dNote oct
            frndint       ;// note  dNote oct
            fxch          ;// dNote note    oct
            fsub st, st(1)
            fmul math_100
            frndint       ;// cent  note    oct

            sub esp, 12 ;// room for 3 dwords

            st_tempCent TEXTEQU <( DWORD PTR [esp+8] )> ;// tempCent
            st_tempNote TEXTEQU <( DWORD PTR [esp+4] )> ;// tempNote
            st_tempOct  TEXTEQU <( DWORD PTR [esp]   )> ;// tempOct

            fchs
            fistp st_tempCent
            fistp st_tempNote
            fistp st_tempOct

        ;// now we format the value

            mov edx, st_tempNote

        ;// adjust octave

            .IF edx == 0
                dec st_tempOct
            .ELSEIF edx == 12
                xor edx, edx
            .ENDIF
            xor eax, eax
            inc st_tempOct

        ;// store the interval

            mov eax, unit_interval_text[edx*4]
            stosd
            shr eax, 24 ;// account for 3 and 4 characters
            .IF ZERO?
                dec edi
            .ENDIF

        ;// store the detune, if any

            xor eax, eax
            or eax, st_tempCent
            .IF !ZERO?
                .IF SIGN?
                    ;// cents is negative
                    neg eax
                    mov WORD PTR [edi],'-'
                .ELSE
                    mov WORD PTR [edi],'+'
                .ENDIF
                inc edi

                .REPEAT
                    .BREAK .IF al <= 9
                    sub al, 10
                    inc ah
                .UNTIL 0
                xchg al, ah
                add ax, 3030h
                stosw
            .ENDIF

            ;// tack on the filler, then the octave

            mov ax, '- '
            stosw

            mov ax, WORD PTR st_tempOct
            .REPEAT
                .BREAK .IF al <= 9
                sub al, 10
                inc ah
            .UNTIL 0
            xchg al, ah
            add ax, 3030h
            stosw

        ;// clean up and split

            add esp, 12

            st_tempCent TEXTEQU <>  ;// tempCent
            st_tempNote TEXTEQU <>  ;// tempNote
            st_tempOct  TEXTEQU <> ;// tempOct

            jmp term_and_done


    ALIGN 16
    build_dB::

        ;// check if value is zero

            ftst
            fnstsw  ax
            fabs    ;// force positive
            sahf
            .IF ZERO?
                mov eax, 'fnI-'
                fstp st
                jmp store_a_dword_then_filler
            .ENDIF
            .IF CARRY? && ebx & UBS_APPEND_NEG
                or ebx, 80000000h
            .ENDIF

            fld unit_scale[ecx] ;// knob_scale_dB
            fxch    ;// X   scale
            fyl2x   ;// dB

            jmp build_fixed_6

    ALIGN 16
    build_bool::

        ;// true
        ;// false

            ;// we have to check the sign bit manually
            ;// this is because we allow -0

            push eax
            fstp DWORD PTR [esp]
            pop eax

            test eax, eax
            .IF SIGN?
                mov DWORD PTR [edi], 'eurt'
                add edi, 4
                jmp term_and_done
            .ENDIF
            mov DWORD PTR [edi], 'slaf'
            mov BYTE PTR [edi+4], 'e'
            add edi, 5
            jmp term_and_done






;// INFINITY

    ALIGN 16
    got_Infinity:

        xor eax, eax
        ftst
        fnstsw ax
        fstp st
        sahf
        mov eax, 'fnI+'
        jnc store_a_dword_then_filler
        mov eax, 'fnI-'
        jmp store_a_dword_then_filler

;// OVERLOAD

    ALIGN 16
    got_overload:
    build_midi_stream::

        fstp st
        mov eax, '####'

    store_a_dword_then_filler:

        stosd
        jmp tack_on_filler




;// LINEAR ENGINEERING UNITS

    ALIGN 16
    build_hertz::
    build_2xhertz::

            fmul unit_scale[ecx]    ;// multiply by scale
            mov edx, FLOATSZ_ENG OR FLOATSZ_DIG_5 OR FLOATSZ_SPACE
            invoke float_to_sz
            jmp tack_on_unit


;// SCI FORMAT

    ALIGN 16
    build_value::

            ;// if value > 1/100 use fixed notion
            ;// otherwise use sci notion

            fld st
            fabs
            xor eax, eax
            fld math_1_1000
            fucompp
            fnstsw ax
            sahf
            mov edx, FLOATSZ_SCI OR FLOATSZ_DIG_6   ;// assume sci format ?
            jae sci_format                          ;// nope, use fixed format
        fixed_format:
            mov edx, FLOATSZ_FIX OR FLOATSZ_DIG_6
        sci_format:
            .IF !(ebx & UBS_NO_SEP_EXP)
                or edx,  FLOATSZ_SPACE
            .ENDIF
            invoke float_to_sz
            jmp term_and_done

;// LINEAR routines

    ALIGN 16
    build_degrees::
    build_midi::
    build_BPM::
    build_samples::
    build_bins::
    build_percent::

            fmul unit_scale[ecx]    ;// multiply by scale

    build_fixed_6:
    build_auto::
    build_spectrum::

            mov edx, FLOATSZ_FIX OR FLOATSZ_DIG_6

    float_sz_then_filler:   ;// edx must have desired unit format

            invoke float_to_sz

    tack_on_filler:

            mov al, ' '
            stosb

    tack_on_unit:

            mov eax, unit_label[ecx]    ;// get the desired unit
            TESTJMP eax, eax, jz term_and_done;// 0000
            stosb
            SHRJMP eax, 8, jz term_and_done ;// 000$
            stosb
            SHRJMP eax, 8, jz term_and_done ;// 00$$
            stosb
            SHRJMP eax, 8, jz term_and_done ;// 0$$$
            stosb
            SHRJMP eax, 8, jz term_and_done ;// $$$$
            stosb

    term_and_done:

        ;// check for append neg

            test ebx, ebx
            .IF SIGN?
                mov eax, 'gen '
                stosd
            .ENDIF

        ;// terminate the string

            mov [edi], 0
            mov eax, edi

        ;// and exit

            mov ebx, st_fmt
            mov ecx, st_unit
            mov edi, st_buf

            ret 0Ch ;// STDCALL 3 args

unit_BuildString ENDP
PROLOGUE_ON






ASSUME_AND_ALIGN
unit_ConvertOld PROC

    ;// eax must enter with the flags to set
    ;// uses edx

    ;// returns eax as new version

        mov edx, eax

        and eax, UNIT_OLD_MASK  ;// remove all old units
        and edx, UNIT_OLD_TEST  ;// old units

        .IF ZERO?   ;// UNIT_OLD_VALUE  ;// 00000000h   ;// just for clarity

                or eax,     UNIT_VALUE

        .ELSEIF edx & UNIT_OLD_AUTO     ;// 20000000h
                                        ;// make sure we remove the old units
                or eax, UNIT_AUTO_UNIT

        .ELSEIF edx == UNIT_OLD_HERTZ   ;// 00000100h

                or eax, UNIT_HERTZ

        .ELSEIF edx == UNIT_OLD_SECONDS ;// 00000200h

                or eax, UNIT_SECONDS

        .ELSEIF edx == UNIT_OLD_NOTE    ;// 00000400h

                or eax, UNIT_NOTE

        .ELSEIF edx == UNIT_OLD_TEMPO   ;// 00000800h

                or eax, UNIT_BPM

        .ELSEIF edx == UNIT_OLD_INTERVAL;// 00001000h

                or eax, UNIT_INTERVAL

        .ELSEIF edx == UNIT_OLD_DB      ;// 00002000h

                or eax, UNIT_DB

        .ELSEIF edx == UNIT_OLD_MIDI_NEW;// 02004000h

                or eax, UNIT_MIDI

        .ELSEIF edx == UNIT_OLD_SAMPLES ;// 00008000h

                or eax, UNIT_SAMPLES

        .ELSEIF edx == UNIT_OLD_LOGIC   ;// 08000000h

                or eax, UNIT_LOGIC

        .ELSEIF edx == UNIT_OLD_BINS    ;// 10000000h

                or eax, UNIT_BINS

        .ENDIF

    ;// that's it

        ret

unit_ConvertOld ENDP





;////////////////////////////////////////////////////////////////////
;//
;//                 to keep the names from getting too long
;//     TRACING     well break this into several procs
;//




ASSUME_AND_ALIGN
unit_AutoTrace PROC ;// USES ebp esi edi ebx

    ;// this may be called from any context

        ASSUME ebp:PTR LIST_CONTEXT

    ;// make sure we've objects to trace

        cmp dlist_Head( oscZ, ebp ), 0
        jz all_done

    ;// preserve appropriate registers

        push edi
        push esi
        push ebx

    ;// do the trace

        call autotrace_Clear
        call autotrace_BACK
        call autotrace_FORE
        call autotrace_BACK

    ;// revive preserved registers

        pop ebx
        pop esi
        pop edi

    all_done:

    ;// make sure and shut off trace, pin_SetUnit has turned it on

        and app_bFlags, NOT APP_SYNC_AUTOUNITS
        ret

unit_AutoTrace ENDP

ASSUME_AND_ALIGN
autotrace_Clear PROC
;////////////////////////////////////////////////////////////////
;//
;// 1)  reset all AUTOED pins
;//     set UNIT_AUTO_TRACE if nessesary

        ASSUME ebp:PTR LIST_CONTEXT

    ;// scan all oscs in zlist

        dlist_GetHead oscZ, esi, [ebp]
        xor ecx, ecx    ;// keeps track of changed pins

        .REPEAT

            ITERATE_PINS

                mov eax, [ebx].dwStatus
                BITR eax, UNIT_AUTOED       ;// turn off the autoed bit
                .IF CARRY?                  ;// if it was on

                    and eax, NOT UNIT_TEST  ;// abox225 remove the old unit (so it doesn't comback later)
                    invoke pin_SetUnit      ;// set unit and invalidate
                    inc ecx                 ;// tag that we've adjusted a pin

                .ENDIF

            PINS_ITERATE

            ;// now we check if base class wants a new display
            .IF ecx
                OSC_TO_BASE esi, ecx
                .IF [ecx].data.dwFlags & BASE_HAS_AUTO_UNITS
                    or [esi].dwUser, UNIT_AUTO_TRACE
                .ENDIF
                xor ecx, ecx    ;// keep clear for future use
            .ENDIF

            dlist_GetNext oscZ, esi

        .UNTIL !esi

        ret

;// 1)  reset all AUTOED pins
;//     set UNIT_AUTO_TRACE if nessesary
;//
;////////////////////////////////////////////////////////////////
autotrace_Clear ENDP



comment ~ /*

    BACKWARD UNIT PUSH  outline (see code for exact implementation )

    scan oscs

        scan_pins

            input ?

                no unit ?

                    GetUnit
                    fail ? goto next_pin
                    SetUnit

                connected ?

                    connection_have_unit ? goto next_pin

                    multiple connection ?

                        all the same ? no --> next_pin

                    enter_recursion

                        push pin
                        pin = connection, osc=pin.pObject
                        SetUnit
                        jmp scan_pins

        next_pin

        exit_recursion

        recursed ?

            pop pin, get osc
            jmp next_pin

    next_osc

    done


*/ comment ~


ASSUME_AND_ALIGN
autotrace_BACK PROC
;////////////////////////////////////////////////////////////////
;//
;// 2)  BACKWARD UNIT PUSH          push all input units
;//                                 back as far as they will go
;//

        ASSUME ebp:PTR LIST_CONTEXT

;// scan oscs

        dlist_GetHead oscZ, esi, [ebp]
        mov edi, esp    ;// edi tracks the top of the stack

;//     scan_pins

    scan_pins:


        OSC_TO_LAST_PIN esi, ebx

    next_pin:

        sub ebx, SIZEOF APIN
        cmp ebx, esi
        jbe exit_recursion

;//     DEBUG_IF <ebx==591DC0h> ;// bug hunt

;//         input ?

        mov eax, [ebx].dwStatus         ;// input ?
        test eax, PIN_OUTPUT
        jnz next_pin

;//             no unit ?

        test eax, UNIT_AUTOED
        jnz check_connection        ;// connection_have_unit
        test eax, UNIT_AUTO_UNIT
        jz check_connection         ;// connection_have_unit

;//                 GetUnit
;//                 fail ? goto next_pin

        OSC_TO_BASE esi, ecx
        invoke [ecx].gui.GetUnit
        jnc next_pin

;//                 SetUnit

        or eax, UNIT_AUTO_UNIT OR UNIT_AUTOED
        invoke pin_SetUnit
;//     mov edx, [ebx].pPin
        jnc check_connection    ;// connection_have_unit
        OSC_TO_BASE esi, ecx
        test [ecx].data.dwFlags, BASE_HAS_AUTO_UNITS
        jz check_connection     ;// connection_have_unit
        or [esi].dwUser, UNIT_AUTO_TRACE

    check_connection:

        GET_PIN_FROM edx, [ebx].pPin    ;// connected ?
        test edx, edx
        jz next_pin



;//             connection_have_unit ? goto next_pin

        mov eax, [edx].dwStatus
        test eax, UNIT_AUTOED       ;// unit already set ?
        jnz next_pin                ;// exit if already autoed
        test eax, UNIT_AUTO_UNIT    ;// is it a fixed unit ?
        jz next_pin                 ;// exit if fixed unit

;//             multiple connection ?

    multiple_connections:

        GET_PIN_FROM edx, [edx].pPin
        cmp [edx].pData, 0
        je enter_recursion

;//                 all the same ? no --> next_pin

        mov ecx, [ebx].dwStatus ;// we know ebx has a valid unit
        and ecx, UNIT_TEST      ;// ecx is what we'll compare against

    test_input_unit:            ;// if has_unit, units must match

        cmp edx, ebx            ;// don't check self
        je next_input_pin

        mov eax, [edx].dwStatus
        test eax, UNIT_AUTOED
        jnz cmp_input_unit
        test eax, UNIT_AUTO_UNIT
        jnz next_input_pin

    cmp_input_unit:

        and eax, UNIT_TEST
        cmp eax, ecx
        jne next_pin            ;// can't use if no match

    next_input_pin:

        mov edx, [edx].pData
        test edx, edx
        jne test_input_unit     ;// fall through is can use

;//             enter_recursion
;//                 push pin
;//                 pin = connection, osc=pin.pObject
;//                 SetUnit
;//                 jmp scan_pins

    enter_recursion:

        push ebx
        mov eax, [ebx].dwStatus
        GET_PIN_FROM ebx, [ebx].pPin
        or eax, UNIT_AUTO_UNIT OR UNIT_AUTOED
        PIN_TO_OSC ebx, esi
        invoke pin_SetUnit
        jnc scan_pins
        OSC_TO_BASE esi, ecx
        test [ecx].data.dwFlags, BASE_HAS_AUTO_UNITS
        jz scan_pins
        or [esi].dwUser, UNIT_AUTO_TRACE
        jmp scan_pins

;//     next_pin
;//     next pin is up above under scan_pins

    ALIGN 16
    exit_recursion:

;//     recursed ?
;//         pop pin, get osc
;//         jmp next_pin

        cmp edi, esp
        je next_osc

        pop ebx
        PIN_TO_OSC ebx, esi
        jmp next_pin

;// next_osc
    next_osc:

        dlist_GetNext oscZ, esi
        test esi, esi
        jnz scan_pins

;// done

        ret




;//
;// 2)  BACKWARD UNIT PUSH          push all fixed input units
;//                                 back as far as they will go
;//
;////////////////////////////////////////////////////////////////
autotrace_BACK ENDP





comment ~ /*



FOREWARD UNIT PUSH  outline (see code for exact implementation )

    scan_oscs   (esi is iterator)

        scan_pins   (ebx is iterator)

            output ?

                ebx unit not set ?

                    GetUnit ? pin_SetUnit
                    else goto next_pin

                connected ?

                    scan_input_chain    iter=edx pin=ebx

                        look for unset inputs   (edx is iterator)

                            ;// do we call get unit ? NO

                            push iter,pin
                            pin=iter, get osc
                            pin_SetUnit
                            goto scan_pins

                    next_input_chain    (iterate edx)

        next_pin    (ebx is iterator)

        top of stack ? goto next osc

        pop iter,pin, get osc

        top of stack ? goto next_pin

        goto next_input_chain

    next_osc (esi is iterator)


*/ comment ~

ASSUME_AND_ALIGN
autotrace_FORE PROC
;////////////////////////////////////////////////////////////////
;//
;// 3)  FOREWARD UNIT PUSH          push all units forwards
;//                                 as far as they will go

        ASSUME ebp:PTR LIST_CONTEXT

;// scan_oscs   (esi is iterator)

        dlist_GetHead oscZ, esi, ebp
        mov edi, esp    ;// edi tracks the top of the stack

;//     scan_pins   (ebx is iterator)

    scan_pins:

        OSC_TO_LAST_PIN esi, ebx

    next_pin:

        sub ebx, SIZEOF APIN
        cmp ebx, esi
        jbe next_osc

;//     output not hidden ?

        mov eax, [ebx].dwStatus
        test eax, PIN_OUTPUT        ;// output ?
        jz next_pin

        test eax, PIN_HIDDEN        ;// hidden ?
        jnz next_pin

;//     ebx unit not set ?
;//     can we set ebx's unit ?

        test eax, UNIT_AUTO_UNIT    ;// auto unit
        jz check_if_connected           ;// must be fixed unit, so we scan the chain
        test eax, UNIT_AUTOED       ;// yes auto unit, has it been set yet ?
        jnz check_if_connected      ;// if already set, we're ready to scan the input chain

;//     GetUnit ? pin_SetUnit
;//     else goto next_pin

        OSC_TO_BASE esi, ecx
        DEBUG_IF <!!([ecx].gui.GetUnit)>
        invoke [ecx].gui.GetUnit
        jnc next_pin

        or eax, UNIT_AUTO_UNIT OR UNIT_AUTOED
        invoke pin_SetUnit
        jnc check_if_connected

        OSC_TO_BASE esi, ecx
        test [ecx].data.dwFlags, BASE_HAS_AUTO_UNITS
        jz check_if_connected
        or [esi].dwUser, UNIT_AUTO_TRACE

    check_if_connected:

        GET_PIN_FROM edx, [ebx].pPin
        test edx, edx
        jz next_pin

;//     scan_input_chain    iter=edx pin=ebx

    scan_input_chain:

;//     look for unset inputs   (edx is iterator)

        mov eax, [edx].dwStatus
        test eax, UNIT_AUTO_UNIT
        jz next_input_chain
        test eax, UNIT_AUTOED
        jnz next_input_chain

        ;// do we call get unit ? NO

;//     push iter,pin
;//     pin=iter, get osc
;//     pin_SetUnit
;//     goto scan_pins

        mov eax, [ebx].dwStatus     ;// get the units we're about to set
        push edx                    ;// store the iterator
        push ebx                    ;// store the output pin
        mov ebx, edx                ;// set the new pin
        mov esi, [ebx].pObject      ;// get the object
        or eax, UNIT_AUTOED OR UNIT_AUTO_UNIT   ;// make sure we set these
        invoke pin_SetUnit          ;// set the unit on the input pin
        jnc scan_pins               ;// if not changed, the no sense telling osc
        OSC_TO_BASE esi, ecx
        test [ecx].data.dwFlags, BASE_HAS_AUTO_UNITS
        jz scan_pins
        or [esi].dwUser, UNIT_AUTO_TRACE
        jmp scan_pins

;//             next_input_chain    (iterate edx)

    ALIGN 16
    next_input_chain:

        mov edx, [edx].pData
        test edx, edx
        jnz scan_input_chain
        jmp next_pin

;//     next_pin    (ebx is iterator)
;//     next_pin is up above, under scan_pins

;// next_osc (esi is iterator)

    ALIGN 16
    next_osc:

;//     not top of stack ? goto exit recursion

        cmp edi, esp
        jne exit_recursion

        dlist_GetNext oscZ, esi
        test esi, esi
        jnz scan_pins
        jmp autotrace_3_done

    ALIGN 16
    exit_recursion:

;//     pop iter,pin, get osc

        pop ebx
        pop edx
        mov esi, [ebx].pObject

;// next input in chain (the olnly way we could have enetered a recursion

        jmp next_input_chain


    ALIGN 16
    autotrace_3_done:

        ret

;//
;// 3)  FOREWARD UNIT PUSH          push all units forwards
;//                                 as far as they will go
;//
;////////////////////////////////////////////////////////////////
autotrace_FORE ENDP







ASSUME_AND_ALIGN


END








