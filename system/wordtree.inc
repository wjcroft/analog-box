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
;// wordtree.inc        declares the macros needed for wordtree.exe
;//

;// these two macros define both internal labels and act as tags for wordtree.exe


    ;// use once per tree, defines the tree

    WORDTREE_BEGIN MACRO nam:req

        ASSUME esi:PTR BYTE

        push ebx
        push esi
        mov ebx, OFFSET wordtree_UpperTable

        INCLUDE &nam.asm

        ALIGN 16
        return_fail:

            mov edx, esi    ;// edx must point at fail char
            xor eax, eax    ;// indicate no match
            pop esi         ;// retrieve origonal esi
            dec edx         ;// points at char that ended scan
            stc             ;// set carry to indicate fail
            jmp all_done

        ENDM


    ;// use once per label, defines the accepting exit points for the parser

    WORDTREE MACRO lab:req

        ALIGN 16

        IFIDN <lab>,<*>
            NODE__STAR:
        ELSEIFIDN <lab>,<+>
            NODE__PLUS:
        ELSEIFIDN <lab>,<!%>
            NODE__PERCENT:
        ELSEIFIDN <lab>,<->
            NODE__MINUS:
        ELSE
            NODE_&lab:
        ENDIF

            ;// do work
            ;// be sure to exit to return sucess

        ENDM


    WORDTREE_t_DIGIT MACRO lab:req

        WORDTREE lab

        ENDM


    ;// then this defines the exit point

    WORDTREE_END MACRO

        ALIGN 16
        return_success:

            dec esi     ;// must return esi at char than ended scan
            add esp, 4  ;// clears the carry flag

        all_done:   ;// stack must be cleaned up !!
                    ;// exit code must be set
            pop ebx ;// retrieve ebx
            ret

        ENDM



    ;// use this macro to define wordtree_UpperTable

    WORDTREE_MAKEUPPERTABLE MACRO

        ALIGN 16
        wordtree_UpperTable LABEL BYTE
        db 000h,001h,002h,003h,004h,005h,006h,007h,008h,009h,00Ah,00Bh,00Ch,00Dh,00Eh,00Fh
        db 010h,011h,012h,013h,014h,015h,016h,017h,018h,019h,01Ah,01Bh,01Ch,01Dh,01Eh,01Fh
        db 020h,021h,022h,023h,024h,025h,026h,027h,028h,029h,02Ah,02Bh,02Ch,02Dh,02Eh,02Fh
        db 030h,031h,032h,033h,034h,035h,036h,037h,038h,039h,03Ah,03Bh,03Ch,03Dh,03Eh,03Fh
        db 040h,041h,042h,043h,044h,045h,046h,047h,048h,049h,04Ah,04Bh,04Ch,04Dh,04Eh,04Fh
        db 050h,051h,052h,053h,054h,055h,056h,057h,058h,059h,05Ah,05Bh,05Ch,05Dh,05Eh,05Fh
        db 060h,041h,042h,043h,044h,045h,046h,047h,048h,049h,04Ah,04Bh,04Ch,04Dh,04Eh,04Fh ;// <-- upper
        db 050h,051h,052h,053h,054h,055h,056h,057h,058h,059h,05Ah,07Bh,07Ch,07Dh,07Eh,07Fh ;// <-- upper
        db 080h,081h,082h,083h,084h,085h,086h,087h,088h,089h,08Ah,08Bh,08Ch,08Dh,08Eh,08Fh
        db 090h,091h,092h,093h,094h,095h,096h,097h,098h,099h,09Ah,09Bh,09Ch,09Dh,09Eh,09Fh
        db 0A0h,0A1h,0A2h,0A3h,0A4h,0A5h,0A6h,0A7h,0A8h,0A9h,0AAh,0ABh,0ACh,0ADh,0AEh,0AFh
        db 0B0h,0B1h,0B2h,0B3h,0B4h,0B5h,0B6h,0B7h,0B8h,0B9h,0BAh,0BBh,0BCh,0BDh,0BEh,0BFh
        db 0C0h,0C1h,0C2h,0C3h,0C4h,0C5h,0C6h,0C7h,0C8h,0C9h,0CAh,0CBh,0CCh,0CDh,0CEh,0CFh
        db 0D0h,0D1h,0D2h,0D3h,0D4h,0D5h,0D6h,0D7h,0D8h,0D9h,0DAh,0DBh,0DCh,0DDh,0DEh,0DFh
        db 0E0h,0E1h,0E2h,0E3h,0E4h,0E5h,0E6h,0E7h,0E8h,0E9h,0EAh,0EBh,0ECh,0EDh,0EEh,0EFh
        db 0F0h,0F1h,0F2h,0F3h,0F4h,0F5h,0F6h,0F7h,0F8h,0F9h,0FAh,0FBh,0FCh,0FDh,0FEh,0FFh

        ENDM


















