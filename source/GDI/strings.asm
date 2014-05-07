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
;// strings.asm         all the strings we'd ever want
;//
OPTION CASEMAP:NONE

.586
.MODEL FLAT

        .NOLIST
        include <Abox.inc>
        .LIST

.DATA

    sz_Left         db  'Left',0
    sz_Right        db  'Right',0
    sz_Amplitude    db  'Amplitude', 0
    sz_Frequency    db  'Frequency', 0
    sz_Phase        db  'Phase', 0
    sz_Offset       db  'Offset',0
    sz_Switch       db  'Switch', 0
    sz_Count        db  'Count',0
    sz_Reset        db  'Reset',0
    sz_Resonance    db  'Resonance',0
    sz_Sample       db  'Sample',0
    sz_Pan          db  'Pan',0
    sz_Cascade      db  'Cascade',0
    sz_Time         db  'Time',0

    sz_Index        db  'Index',0
    sz_Shift        db  'Shift',0
    sz_Real         db  'Real',0
    sz_Imag         db  'Imaginary',0

    sz_Enable       db  'Enable',0

    sz_Write        db  'Write',0
    sz_SampleRate   db  'Sample Rate',0
    sz_Move         db  'Move',0
    sz_Seek         db  'Seek',0
    sz_SeekPosition db  'Seek Position',0
    sz_CurrentPosition db  'Current Position',0
    sz_FileSize     db  'Reciprocal of Current Size (1/samples)',0

    sz_Data         db  'Data',0
    sz_Column       db  'Column',0
    sz_Row          db  'Row',0
    sz_NumColumn    db  'Reciprocal of number Columns (1/columns)',0
    sz_NumRow       db  'Reciprocal of number of Rows (1/rows)',0
    sz_Erase        db  'Erase',0
    sz_NextColumn   db  'Next Column',0
    sz_NextRow      db  'Next Row (at first column)',0
    sz_ReRead       db  'Re-Read',0

    sz_SeedValue    db  'Seed value',0
    sz_Restart      db  'Restart', 0
    sz_NextValue    db  'Next value', 0

    sz_Step         db  'Step', 0
    sz_StepSize     db  'Step size', 0
    sz_Damping      db  'Damping', 0
    sz_InitialValue db  'Initial value', 0
    sz_Parameter    db  'Parameter', 0

    sz_Positive     db  'Positive',0
    sz_Negative     db  'Negative',0
    sz_Any          db  'Any',0
    sz_EdgeTrigger  db  'edge trigger',0
    sz_Gate         db  'gate',0

    sz_Logic        db  'Logic',0
    sz_Spectral     db  'Spectral',0
    sz_Input        db  'Input',0
    sz_Output       db  'Output',0

    sz_Stream   db  'Midi Stream',0
    sz_Number   db  'Midi Number',0
    sz_Value    db  'Midi Value',0
    sz_Event    db  'Midi Event',0



ASSUME_AND_ALIGN



END