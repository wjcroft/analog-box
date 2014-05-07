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
;//     ABOX242 AJT -- detabified + text adjustments for 'lines too long' errors
;//
;//##////////////////////////////////////////////////////////////////////////
;//
;// ABox_Damper.asm
;//
OPTION CASEMAP:NONE

.586
.MODEL FLAT

USE_THIS_FILE equ 1

IFDEF USE_THIS_FILE

        .NOLIST
        include <Abox.inc>
        .LIST


.DATA

    ;// object dwUser is the number points
    ;// damper stores previous values here

    OSC_DAMPER STRUCT

        X  REAL4   8 dup (0.0e+0)

    OSC_DAMPER ENDS



osc_Damper OSC_CORE { ,,damper_PrePlay,damper_Calc }
           OSC_GUI  { ,damper_SetShape,,,,
            damper_Command,damper_InitMenu,,,
            osc_SaveUndo,damper_LoadUndo,damper_GetUnit }
           OSC_HARD {}

    ;// don't make the lines too lone
    ofsPinData  = SIZEOF OSC_OBJECT + ( SIZEOF APIN ) * 2
    ofsOscData  = SIZEOF OSC_OBJECT + ( SIZEOF APIN ) * 2 + SAMARY_SIZE
    oscBytes    = SIZEOF OSC_OBJECT + ( SIZEOF APIN ) * 2 + SAMARY_SIZE + SIZEOF OSC_DAMPER + 16
    
    OSC_DATA_LAYOUT {NEXT_Damper,IDB_DAMPER,OFFSET popup_DAMPER,,
        2,4,
        ofsPinData,
        ofsOscData,
        oscBytes }

    OSC_DISPLAY_LAYOUT { filter_container, DAMPER3_PSOURCE, ICON_LAYOUT(7,3,3,3)}

    APIN_init {-1.0,,'X',, UNIT_AUTO_UNIT }                 ;// input
    APIN_init { 0.0,,'=',, PIN_OUTPUT OR UNIT_AUTO_UNIT }   ;// output

    short_name  db  'Damp Filter',0
    description db  'A lowpass FIR filter. Adjust the number of points to set the frequency.',0
    ALIGN 4

    ;// point tables, see Damper_01.MCD for derivation

        damper_table0   REAL4 3.519420E-1
        damper_scale0   REAL4 5.86894413E-1

        damper_table1   REAL4 1.40986E-1
                        REAL4 6.37546E-1
        damper_scale1   REAL4 3.91073512E-1

        damper_table2   REAL4 7.54690E-2
                        REAL4 3.51942E-1
                        REAL4 7.77711E-1
        damper_scale2   REAL4 2.93234149E-1


        damper_table3   REAL4 4.793202E-2
                        REAL4 2.127530E-1
                        REAL4 5.196440E-1
                        REAL4 8.513830E-1
        damper_scale3   REAL4 2.34553258E-1


;// osc map

    OSC_MAP STRUCT

        OSC_OBJECT  {}
        pin_x   APIN    {}
        pin_y   APIN    {}
        data_y  dd SAMARY_LENGTH DUP (0)
        damper_data OSC_DAMPER {}

    OSC_MAP ENDS


.CODE

;////////////////////////////////////////////////////////////////////////////////


ASSUME_AND_ALIGN
damper_GetUnit PROC

        ASSUME esi:PTR OSC_MAP  ;// must preserve
        ASSUME ebx:PTR APIN     ;// must preserve

        ;// must preserve edi and ebp

    ;// determine the pin we want to grab the unit from

        lea ecx, [esi].pin_x
        .IF ecx == ebx
            lea ecx, [esi].pin_y
        .ENDIF
        ASSUME ecx:PTR APIN

        mov eax, [ecx].dwStatus
        BITT eax, UNIT_AUTOED
        ret


damper_GetUnit ENDP


;////////////////////////////////////////////////////////////////////////////////








ASSUME_AND_ALIGN
damper_PrePlay PROC ;// STDCALL uses edi pObject:PTR OSC_OBJECT

    ;// here we want to zero the previous values

    ASSUME esi:PTR OSC_OBJECT

    OSC_TO_DATA esi, edi, OSC_DAMPER

    xor eax, eax
    mov ecx, ( SIZEOF OSC_DAMPER ) / 4
    rep stosd

    ;// eax is zero, we want to have play_start erase our data

    ret

damper_PrePlay ENDP


ASSUME_AND_ALIGN
damper_Calc PROC uses esi

    ;// we'll do this six different ways ( to sunday ?? )

        GET_OSC_FROM ebx, esi
        assume ebx:PTR OSC_OBJECT

        OSC_TO_PIN_INDEX ebx, edi, 1    ;// edi points at OUT pin

        DEBUG_IF <!![edi].pPin> ;// supposed to be connected to calc

    OSC_TO_PIN_INDEX ebx, esi, 0    ;// esi points at IN pin

    .IF [esi].pPin

            ;// the input is connected
            ;// make sure our data's pointing at what samAray allocated

            mov esi, [esi].pPin
            mov eax, [esi].dwStatus             ;// load input status
            OSC_TO_DATA ebx, edx, OSC_DAMPER
            mov ecx, [edi].dwStatus
            or [edi].dwStatus, PIN_CHANGING     ;// assume we are
            mov edi, [edi].pData
            mov esi, [esi].pData

            ;// now we can check if we need to calculate the whole thing
            ;// if the input is NOT changing AND the first input value
            ;// equals the last output value, then we don't have to do the filter

            .IF !(eax & PIN_CHANGING)   ;// input changing ?

                mov eax, DWORD PTR [edi+(SAMARY_LENGTH-1)*4]    ;// load last output
                .IF eax == DWORD PTR [esi]                      ;// equ input ?

                    .IF ecx & PIN_CHANGING      ;// we're we changing last time ?

                        mov ecx, SAMARY_LENGTH  ;// store the value
                        rep stosd

                    .ENDIF

                    OSC_TO_PIN_INDEX ebx, edi, 1    ;// esi points at OUT pin
                    and [edi].dwStatus, NOT PIN_CHANGING

                    jmp AllDone

                .ENDIF

            .ENDIF

            ;// input data is changing

                assume edi:ptr REAL4
                assume esi:ptr REAL4
                assume edi:ptr REAL4
                xor ecx, ecx

            ;// determine which algorithm we use

            .IF [ebx].dwUser == 0

                ;// three point alg

                ;// we can do this operation entirely in the FPU
                ;// x0 = new point
                ;// Y = ( b1*(x2+x0) + x1 ) * S
                ;// x2=x1   x1=x0

                fld damper_scale0   ;// S
                fld damper_table0   ;// B1  S

                fld DWORD PTR [edx+8] ;// x1     b1   S
                fld DWORD PTR [edx+4] ;// x2     x1   b1   S

                .WHILE ecx < SAMARY_LENGTH

                                      ;// x2     x1   b1   S
                    fld DWORD PTR [esi+ecx*4]
                                      ;// x0     x2   x1   b1   S
                    fxch              ;// x2     x0   x1   b1   S
                    fadd st, st(1)    ;// x2x0 x0   x1   b1 S
                    fmul st, st(3)    ;// b120 x0   x1   b1 S
                    fadd st, st(2)    ;// y  x0   x1   b1   S
                    fmul st, st(4)    ;// Y  x0   x1   b1   S
                    fstp DWORD PTR [edi+ecx*4]
                                      ;// x0     x1    b1   S
                    fxch              ;// x2     x1    b1   S
                    inc ecx

                .ENDW

                fstp DWORD PTR [edx+4];// x1     b1   S
                fstp DWORD PTR [edx+8];// b1     S

                fstp st
                fstp st

            .ELSEIF [ebx].dwUser == 1

                ;// five point alg
                ;// x0 = new point
                ;// ( b1*(x4+x0) + b2*(x3+x1) + x2 ) * S
                ;// x4=x3  x3=x2  x2=x1 x1=x0

                assume edx:PTR DWORD

                fld  [edx+16] ;// x1
                fld  [edx+12] ;// x2     x1
                fld  [edx+8]  ;// x3     x2   x1
                fld  [edx+4]  ;// x4     x3   x2   x1

                .WHILE ecx < SAMARY_LENGTH

                    fld   [esi+ecx*4]
                                       ;// x0   x4   x3 x2   x1
                    fxch               ;// x4   x0   x3 x2   x1
                    fadd st, st(1)     ;// x40  x0   x3 x2   x1
                    fld  st(2)         ;// x3   x40  x0 x3   x2   x1
                    fadd st, st(5)     ;// x31  x40  x0 x3   x2   x1
                    fxch               ;// x40  x31  x0 x3   x2   x1
                    fmul damper_table1 ;// b1   x31  x0 x3   x2   x1
                    fxch               ;// x31  b1   x0 x3   x2   x1
                    fmul damper_table1+4;//b2   b1   x0 x3   x2   x1
                    fadd               ;// b12  x0   x3 x2   x1
                    fadd st, st(3)     ;// y      x0   x3   x2   x1
                    fmul damper_scale1 ;// Y      x0   x3   x2   x1

                    fxch               ;// x0   Y    x3 x2   x1
                    fxch st(4)         ;// x1   Y    x3 x2   x0
                    fxch st(3)         ;// x2   Y    x3 x1   x0
                    fxch               ;// Y      x2   x3   x1   x0
                    fstp  [edi+ecx*4]
                                       ;// x2   x3   x1 x0
                    inc ecx
                    fxch               ;// x3   x2   x1 x0

                .ENDW

                fstp  [edx+4]
                fstp  [edx+8]
                fstp  [edx+12]
                fstp  [edx+16]

            .ELSEIF [ebx].dwUser == 2

                assume edx:ptr DWORD
                assume esi:ptr DWORD
                assume edi:ptr DWORD

                ;// seven point alg
                ;// Y = ( b1*(x6+x0) + b2*(x5+x1) + b3*(x4+x2) + x3 ) * S

                ;// now we need a pre, core and post operations to take
                ;// care of the previous values between calcs
                ;// we do have a free register in ebx

                ;// we need six steps to get from prev values in [edx]
                ;// to all current values in [esi]

                ;// STEP 1

                    fld  [edx+4]
                    fadd [esi]
                    fmul damper_table2
                    fld  [edx+8]
                    fadd [edx+24]
                    fmul damper_table2+4
                    fadd
                    fld  [edx+12]
                    fadd [edx+20]
                    fmul damper_table2+8
                    fadd
                    fadd [edx+16]
                    fmul damper_scale2
                    fstp [edi]

                ;// STEP 2

                    fld  [edx+8]
                    fadd [esi+4]
                    fmul damper_table2
                    fld  [edx+12]
                    fadd [esi]
                    fmul damper_table2+4
                    fadd
                    fld  [edx+16]
                    fadd [edx+24]
                    fmul damper_table2+8
                    fadd
                    fadd [edx+20]
                    fmul damper_scale2
                    fstp [edi+4]

                ;// STEP 3

                    fld  [edx+12]
                    fadd [esi+8]
                    fmul damper_table2
                    fld  [edx+16]
                    fadd [esi+4]
                    fmul damper_table2+4
                    fadd
                    fld  [edx+20]
                    fadd [esi]
                    fmul damper_table2+8
                    fadd
                    fadd [edx+24]
                    fmul damper_scale2
                    fstp [edi+8]

                ;// STEP 4

                    fld  [edx+16]
                    fadd [esi+12]
                    fmul damper_table2
                    fld  [edx+20]
                    fadd [esi+8]
                    fmul damper_table2+4
                    fadd
                    fld  [edx+24]
                    fadd [esi+4]
                    fmul damper_table2+8
                    fadd
                    fadd [esi]
                    fmul damper_scale2
                    fstp [edi+12]

                ;// STEP 5

                    fld  [edx+20]
                    fadd [esi+16]
                    fmul damper_table2
                    fld  [edx+24]
                    fadd [esi+12]
                    fmul damper_table2+4
                    fadd
                    fld  [esi]
                    fadd [esi+8]
                    fmul damper_table2+8
                    fadd
                    fadd [esi+4]
                    fmul damper_scale2
                    fstp [edi+16]

                ;// STEP 6

                    fld  [edx+24]
                    fadd [esi+20]
                    fmul damper_table2
                    fld  [esi]
                    fadd [esi+16]
                    fmul damper_table2+4
                    fadd
                    fld  [esi+12]
                    fadd [esi+4]
                    fmul damper_table2+8
                    fadd
                    fadd [esi+8]
                    fmul damper_scale2
                    fstp [edi+20]

                ;// now we do the loop

                    .WHILE ecx < ( SAMARY_LENGTH-6 )

                        fld  [esi+ecx*4]
                        fadd [esi+ecx*4+24]
                        fmul damper_table2
                        fld  [esi+ecx*4+4]
                        fadd [esi+ecx*4+20]
                        fmul damper_table2+4
                        fadd
                        fld  [esi+ecx*4+8]
                        fadd [esi+ecx*4+16]
                        fmul damper_table2+8
                        fadd
                        fadd [esi+ecx*4+12]
                        fmul damper_scale2
                        fstp [edi+ecx*4+24]

                        inc ecx

                    .ENDW

                ;// finally we xfer the last values

                    lea esi, [esi+ecx*4]
                    mov ecx, 6
                    lea edi, [edx+4]
                    rep movsd

            .ELSEIF [ebx].dwUser == 3

                ;// nine point alg

                ;// Y = ( b1*(x8+x0) + b1*(x7+x1) + b2*(x6+x2) +
                ;//     b3*(x7+x3) + b4*(x6+x4) + x5 ) * S

                ;// it takes eight steps to get from all previous
                ;// to all current

                ;// STEP 1


                fld  [edx+4 ]
                fadd [esi   ]
                fmul damper_table3

                fld  [edx+8 ]
                fadd [edx+32]
                fmul damper_table3+4
                fadd

                fld  [edx+12]
                fadd [edx+28]
                fmul damper_table3+8
                fadd

                fld  [edx+16]
                fadd [edx+24]
                fmul damper_table3+12
                fadd

                fadd [edx+20]
                fmul damper_scale3

                fstp [edi   ]

                ;// STEP 2


                fld  [edx+8 ]
                fadd [esi+4 ]
                fmul damper_table3

                fld  [edx+12]
                fadd [esi   ]
                fmul damper_table3+4
                fadd

                fld  [edx+16]
                fadd [edx+32]
                fmul damper_table3+8
                fadd

                fld  [edx+20]
                fadd [edx+28]
                fmul damper_table3+12
                fadd

                fadd [edx+24]
                fmul damper_scale3

                fstp [edi+4 ]

                ;// STEP 3


                fld  [edx+12]
                fadd [esi+8 ]
                fmul damper_table3

                fld  [edx+16]
                fadd [esi+4 ]
                fmul damper_table3+4
                fadd

                fld  [edx+20]
                fadd [esi   ]
                fmul damper_table3+8
                fadd

                fld  [edx+24]
                fadd [edx+32]
                fmul damper_table3+12
                fadd

                fadd [edx+28]
                fmul damper_scale3

                fstp [edi+8 ]


                ;// STEP 4


                fld  [edx+16]
                fadd [esi+12]
                fmul damper_table3

                fld  [edx+20]
                fadd [esi+8 ]
                fmul damper_table3+4
                fadd

                fld  [edx+24]
                fadd [esi+4 ]
                fmul damper_table3+8
                fadd

                fld  [edx+28]
                fadd [esi   ]
                fmul damper_table3+12
                fadd

                fadd [edx+32]
                fmul damper_scale3

                fstp [edi+12]


                ;// STEP 5


                fld  [edx+20]
                fadd [esi+16]
                fmul damper_table3

                fld  [edx+24]
                fadd [esi+12]
                fmul damper_table3+4
                fadd

                fld  [edx+28]
                fadd [esi+8 ]
                fmul damper_table3+8
                fadd

                fld  [edx+32]
                fadd [esi+4 ]
                fmul damper_table3+12
                fadd

                fadd [esi   ]
                fmul damper_scale3

                fstp [edi+16]


                ;// STEP 6


                fld  [edx+24]
                fadd [esi+20]
                fmul damper_table3

                fld  [edx+28]
                fadd [esi+16]
                fmul damper_table3+4
                fadd

                fld  [edx+32]
                fadd [esi+12]
                fmul damper_table3+8
                fadd

                fld  [esi   ]
                fadd [esi+8 ]
                fmul damper_table3+12
                fadd

                fadd [esi+4 ]
                fmul damper_scale3

                fstp [edi+20]

                ;// STEP 7


                fld  [edx+28]
                fadd [esi+24]
                fmul damper_table3

                fld  [edx+32]
                fadd [esi+20]
                fmul damper_table3+4
                fadd

                fld  [esi   ]
                fadd [esi+16]
                fmul damper_table3+8
                fadd

                fld  [esi+4 ]
                fadd [esi+12]
                fmul damper_table3+12
                fadd

                fadd [esi+8 ]
                fmul damper_scale3

                fstp [edi+24]

                ;// STEP 8


                fld  [edx+32]
                fadd [esi+28]
                fmul damper_table3

                fld  [esi   ]
                fadd [esi+24]
                fmul damper_table3+4
                fadd

                fld  [esi+4 ]
                fadd [esi+20]
                fmul damper_table3+8
                fadd

                fld  [esi+8 ]
                fadd [esi+16]
                fmul damper_table3+12
                fadd

                fadd [esi+12]
                fmul damper_scale3

                fstp [edi+28]

                ;// now we can do the loop
                .WHILE ecx < ( SAMARY_LENGTH-8 )


                    fld  [esi+ecx*4   ]
                    fadd [esi+ecx*4+32]
                    fmul damper_table3

                    fld  [esi+ecx*4+4 ]
                    fadd [esi+ecx*4+28]
                    fmul damper_table3+4
                    fadd

                    fld  [esi+ecx*4+8 ]
                    fadd [esi+ecx*4+24]
                    fmul damper_table3+8
                    fadd

                    fld  [esi+ecx*4+12]
                    fadd [esi+ecx*4+20]
                    fmul damper_table3+12
                    fadd

                    fadd [esi+ecx*4+16]
                    fmul damper_scale3

                    fstp [edi+ecx*4+32]
                    inc ecx

                .ENDW

                ;// finally we xfer the last values

                lea esi, [esi+ecx*4]
                mov ecx, 8
                lea edi, [edx+4]
                cld
                rep movsd

            .ENDIF

        .ELSE

            ;// the input is NOT connected

            assume edi:PTR APIN
            btr [edi].dwStatus, LOG2(PIN_CHANGING)
            .IF CARRY?

                mov edi, [edi].pData
                xor eax, eax
                mov ecx, SAMARY_LENGTH
                rep stosd

            .ENDIF

        .ENDIF

AllDone:
    ;// that's all folks

        ret

damper_Calc ENDP



ASSUME_AND_ALIGN
damper_InitMenu PROC    ;// STDCALL uses esi edi pObject:ptr OSC_OBJECT

    ;// set the corect checkmarks

        ASSUME esi:PTR OSC_OBJECT

        mov eax, [esi].dwUser
        .IF eax == 0
            mov ecx, ID_DAMPER_RANGE_3
        .ELSEIF eax == 1
            mov ecx, ID_DAMPER_RANGE_5
        .ELSEIF eax == 2
            mov ecx, ID_DAMPER_RANGE_7
        .ELSEIF eax == 3
            mov ecx, ID_DAMPER_RANGE_9
        .ELSE
            xor ecx, ecx
        .ENDIF

        invoke CheckDlgButton, popup_hWnd, ecx, BST_CHECKED

    ;// that's it

        xor eax, eax

        ret

damper_InitMenu ENDP


ASSUME_AND_ALIGN
damper_Command PROC ;// STDCALL uses esi edi pObject:ptr OSC_OBJECT, cmdID:DWORD

        ASSUME esi:PTR OSC_OBJECT
        ;// eax has the command id

    cmp eax, ID_DAMPER_RANGE_3
    jnz @F

        mov [esi].dwUser, 0
        mov ecx, DAMPER3_PSOURCE
        jmp all_done

@@: cmp eax, ID_DAMPER_RANGE_5
    jnz @F
        mov [esi].dwUser, 1
        mov ecx, DAMPER5_PSOURCE
        jmp all_done

@@: cmp eax, ID_DAMPER_RANGE_7
    jnz @F

        mov [esi].dwUser, 2
        mov ecx, DAMPER7_PSOURCE
        jmp all_done

@@: cmp eax, ID_DAMPER_RANGE_9
    jnz osc_Command

        mov [esi].dwUser, 3
        mov ecx, DAMPER9_PSOURCE

all_done:

    mov [esi].pSource, ecx
    mov eax, POPUP_SET_DIRTY OR POPUP_REDRAW_OBJECT
    ret

damper_Command ENDP


;////////////////////////////////////////////////////////////////////
;//
;//
;//     _LoadUndo
;//

ASSUME_AND_ALIGN
damper_LoadUndo PROC

        ASSUME esi:PTR OSC_OBJECT   ;// preserve
        ASSUME ebp:PTR LIST_CONTEXT ;// preserve

    ;// edx enters as either UNREDO_CONTROL_OSC or UNREDO_COMMAND
    ;// edi enters as where to load
    ;//
    ;// task:   1) load nessary data
    ;//         2) do what it takes to initialize it
    ;//
    ;// may use all registers except ebp and esi
    ;// return will invalidate HINTI_OSC_UPDATE

        mov eax, [edi]
        mov [esi].dwUser, eax

        .IF eax == 0
            mov ecx, DAMPER3_PSOURCE
        .ELSEIF eax == 1
            mov ecx, DAMPER5_PSOURCE
        .ELSEIF eax == 2
            mov ecx, DAMPER7_PSOURCE
        .ELSE ;// [esi].dwUser == 3
            mov ecx, DAMPER9_PSOURCE
        .ENDIF

        mov [esi].pSource, ecx

        ret

damper_LoadUndo ENDP

;//
;//
;//     _LoadUndo
;//
;////////////////////////////////////////////////////////////////////



ASSUME_AND_ALIGN
damper_SetShape PROC

    ASSUME esi:PTR OSC_OBJECT

    .IF [esi].dwUser == 0
        mov ecx, DAMPER3_PSOURCE
    .ELSEIF [esi].dwUser == 1
        mov ecx, DAMPER5_PSOURCE
    .ELSEIF [esi].dwUser == 2
        mov ecx, DAMPER7_PSOURCE
    .ELSE ;// [esi].dwUser == 3
        mov ecx, DAMPER9_PSOURCE
    .ENDIF

    mov [esi].pSource, ecx

    jmp osc_SetShape

damper_SetShape ENDP


ASSUME_AND_ALIGN


ENDIF   ;// USE_THIS_FILE
END
