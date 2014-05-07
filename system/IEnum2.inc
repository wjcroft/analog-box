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
;// IEnum2.inc
;//


;// build enumerators by calling _ctor with applicable parameters

    ;// return eax with err code
    ;//        edx with interface


    IEnum2_ctor PROTO STDCALL ppItemList:DWORD, pCtor:DWORD, pAddRef:DWORD

    IENUM2 STRUCT

        vtable      dd  0   ;// our vtable
        ref_count   dd  0   ;// current refcount

        ppItemList  dd  0   ;// start of the table
        pIterator   dd  0   ;// current position in table
        pCtor       dd  0   ;// where to get newly allocated memory from
        pAddRef     dd  0   ;// if need to add ref

    IENUM2 ENDS

