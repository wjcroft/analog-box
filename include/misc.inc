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
;//     misc.inc        protos for misc.asm
;//                     see misc.asm for details
IFNDEF _MISC_INCLUDED_
_MISC_INCLUDED_ EQU 1

    CLEAR_PROCESSED_BIT MACRO list:req

        IFIDN <list>,<S>
            call misc_clear_processed_bit_S
        ELSEIFIDN <list>,<Z>
            call misc_clear_processed_bit_Z
        ELSE
            .ERR <use Z or S>
        ENDIF

        ENDM


    misc_clear_processed_bit_S  PROTO
    misc_clear_processed_bit_Z  PROTO

    misc_IsChild PROTO STDCALL hParent:DWORD, hChild:DWORD


ENDIF ;// _MISC_INCLUDED_