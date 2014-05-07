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
;//     misc.asm        miscellaneous utilities used in may places
;//                     these are generally small loops
;//

;// this macro calls common code to clear HINTOSC_STATE_PROCESSED BIT
;// caller must supply S for oscS select list or Z for oscZ list

OPTION CASEMAP:NONE
.586
.MODEL FLAT

    .NOLIST
    INCLUDE <abox.inc>
    INCLUDE <misc.inc>
    .LIST

.CODE


ASSUME_AND_ALIGN
misc_clear_processed_bit_Z  PROC

    ;// ebp must be the list context
    ;// destroys ecx and eax

    ASSUME ebp:PTR LIST_CONTEXT

        dlist_GetHead oscZ, ecx, [ebp]
        mov eax, NOT HINTOSC_STATE_PROCESSED

    top_of_loop:

        and [ecx].dwHintOsc, eax
        dlist_GetNext oscZ, ecx
        or ecx, ecx
        jz done_with_loop
        and [ecx].dwHintOsc, eax
        dlist_GetNext oscZ, ecx
        or ecx, ecx
        jnz top_of_loop

    done_with_loop:

        ret

misc_clear_processed_bit_Z  ENDP

ASSUME_AND_ALIGN
misc_clear_processed_bit_S  PROC

    ;// ebp must be the list context
    ;// destroys ecx and eax

    ASSUME ebp:PTR LIST_CONTEXT

        clist_GetMRS oscS, ecx, [ebp]
        mov eax, NOT HINTOSC_STATE_PROCESSED

    top_of_loop:

        and [ecx].dwHintOsc, eax
        clist_GetNext oscS, ecx
        cmp ecx, clist_MRS( oscS, [ebp] )
        je done_with_loop
        and [ecx].dwHintOsc, eax
        clist_GetNext oscS, ecx
        cmp ecx, clist_MRS( oscS, [ebp] )
        jne top_of_loop

    done_with_loop:

        ret

misc_clear_processed_bit_S  ENDP



ASSUME_AND_ALIGN
PROLOGUE_OFF
misc_IsChild PROC STDCALL hParent:DWORD, hChild:DWORD
            ;//     00      04              08

IF USE_MESSAGE_LOG EQ 2
mov eax, [esp+4]
mov edx, [esp+8]
MESSAGE_LOG_PRINT_2 sz_misc_is_child,eax,edx,<"misc_IsChild(%8.8X,%8.8X)">,INDENT
ENDIF

    ;// win32 IsChild doesn't seem to work !!
    ;// or it does something we aren't expecting
    ;// in any event, we do it here the way we expect to

        xchg ebx, [esp+8]           ;// get the tester
    I0: CMPJMP ebx, [esp+4], je I2  ;// see if we match
        invoke GetParent, ebx       ;// get the parent
MESSAGE_LOG_PRINT_2 sz_misc_parent_is,eax,ebx,<"misc_IsChild__parent: %8.8X child: %8.8X">  ;// parent
        TESTJMP eax, eax, jz I1     ;// if zero then we didn't find it
        mov ebx, eax                ;// put new parent as iterator
        jmp I0                      ;// back to top
    I2: mov eax, 1
    I1: mov ebx, [esp+8]
MESSAGE_LOG_PRINT_1 sz_misc_IsChildResults,eax,<"misc_IsChild = %i">,UNINDENT
        retn 8

misc_IsChild ENDP
PROLOGUE_ON

ASSUME_AND_ALIGN
END