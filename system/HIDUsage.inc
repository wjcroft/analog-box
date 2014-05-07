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
;//     HIDUsage.inc            three routines to get text names from page:usage numbers
;//
IFNDEF _HIDUSAGE_INCLUDED_
_HIDUSAGE_INCLUDED_ EQU 1

    HIDUSAGE_MAX_STRING_SIZE EQU 32 ;// including zero terminator

    hidusage_GetPageString  PROTO STDCALL dwPageUsage:DWORD, pBuffer:DWORD
    hidusage_GetUsageString PROTO STDCALL dwPageUsage:DWORD, pBuffer:DWORD
    hidusage_GetShortString PROTO STDCALL dwPageUsage:DWORD, pBuffer:DWORD

    ;// all_return the length of the string sans the zero terminator


ENDIF   ;// _HIDUSAGE_INCLUDED_