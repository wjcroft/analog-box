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
;// controllers.asm     selection values for standard controllers
;//
OPTION CASEMAP:NONE
.586
.MODEL FLAT

USE_THIS_FILE EQU 1
IFDEF USE_THIS_FILE

    .NOLIST
    INCLUDE <ABox.inc>
    INCLUDE <midi2.inc>
    .LIST

.DATA

    ;// all are replaced with ptr from font_Locate
    midi_font_N_out         dd  'N'     ;// bold
    midi_font_s1_out        dd  '1s'    ;// bold
    midi_font_N_in          dd  'N'     ;// normal
    midi_font_s1_in         dd  '1s'    ;// normal
    midi_font_F             dd  'F'     ;// F output for tracker mode
    midi_font_plus_minus    dd  0B1h    ;// +/- for e pin
    midi_font_plus_zero dd 80002DBAh    ;// 0/- digital (tracker dest)

;// COMMAND LABELS

    midiin_command_label_table LABEL DWORD

        dd  OFFSET sz_midiin_00
        dd  OFFSET sz_midiin_01
        dd  OFFSET sz_midiin_02
        dd  OFFSET sz_midiin_03
        dd  OFFSET sz_midiin_04
        dd  OFFSET sz_midiin_05
        dd  OFFSET sz_midiin_06
        dd  OFFSET sz_midiin_07
        dd  OFFSET sz_midiin_08
        dd  OFFSET sz_midiin_09
        dd  OFFSET sz_midiin_10
        dd  OFFSET sz_midiin_11
        dd  OFFSET sz_midiin_tracker  ;// 12
        dd  OFFSET sz_midi_not_used ;// 13
        dd  OFFSET sz_midi_not_used ;// 14
        dd  OFFSET sz_midi_not_used ;// 15

    midiout_command_label_table LABEL DWORD

        dd  OFFSET sz_midiout_00
        dd  OFFSET sz_midiout_01
        dd  OFFSET sz_midiout_02
        dd  OFFSET sz_midiout_03
        dd  OFFSET sz_midiout_04
        dd  OFFSET sz_midiout_05
        dd  OFFSET sz_midiout_06
        dd  OFFSET sz_midiout_07
        dd  OFFSET sz_midiout_08
        dd  OFFSET sz_midiout_09
        dd  OFFSET sz_midiout_10
        dd  OFFSET sz_midiout_11
        dd  OFFSET sz_midiout_track_N  ;// 12
        dd  OFFSET sz_midiout_track_t  ;// 13
        dd  OFFSET sz_midi_not_used ;// 14
        dd  OFFSET sz_midi_not_used ;// 15

;// STANDARD CONTROLLERS

    midi_controller_table   LABEL   MIDI_COMBO_ITEM

    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_0    ,    0   }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_1    ,    1   }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_2    ,    2   }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_4    ,    4   }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_5    ,    5   }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_6    ,    6   }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_7    ,    7   }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_8    ,    8   }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_10   ,    10  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_11   ,    11  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_12   ,    12  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_13   ,    13  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_16   ,    16  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_17   ,    17  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_18   ,    18  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_19   ,    19  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_32   ,    32  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_33   ,    33  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_34   ,    34  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_36   ,    36  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_37   ,    37  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_38   ,    38  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_39   ,    39  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_40   ,    40  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_42   ,    42  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_43   ,    43  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_44   ,    44  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_45   ,    45  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_64   ,    64  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_65   ,    65  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_66   ,    66  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_67   ,    67  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_68   ,    68  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_69   ,    69  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_70   ,    70  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_71   ,    71  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_72   ,    72  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_73   ,    73  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_74   ,    74  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_75   ,    75  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_76   ,    76  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_77   ,    77  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_78   ,    78  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_79   ,    79  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_80   ,    80  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_81   ,    81  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_82   ,    82  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_83   ,    83  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_91   ,    91  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_92   ,    92  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_93   ,    93  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_94   ,    94  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_95   ,    95  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_96   ,    96  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_97   ,    97  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_98   ,    98  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_99   ,    99  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_100  ,    100 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_101  ,    101 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_120  ,    120 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_121  ,    121 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_122  ,    122 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_123  ,    123 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_124  ,    124 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_125  ,    125 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_126  ,    126 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_ctrl_127  ,    127 }

    MIDI_COMBO_ITEM { 0, -1 } ;// terminator

;// GENERAL MIDI PATCHES

    midi_patch_table LABEL MIDI_COMBO_ITEM

    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_0a   ,    0  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_0    ,   0   }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_1    ,   1   }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_2    ,   2   }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_3    ,   3   }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_4    ,   4   }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_5    ,   5   }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_6    ,   6   }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_7    ,   7   }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_8a   ,    8  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_8    ,   8   }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_9    ,   9   }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_10   ,   10  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_11   ,   11  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_12   ,   12  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_13   ,   13  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_14   ,   14  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_15   ,   15  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_16a  ,    16 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_16   ,   16  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_17   ,   17  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_18   ,   18  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_19   ,   19  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_20   ,   20  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_21   ,   21  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_22   ,   22  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_23   ,   23  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_24a  ,    24 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_24   ,   24  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_25   ,   25  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_26   ,   26  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_27   ,   27  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_28   ,   28  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_29   ,   29  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_30   ,   30  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_31   ,   31  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_32a  ,    32 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_32   ,   32  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_33   ,   33  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_34   ,   34  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_35   ,   35  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_36   ,   36  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_37   ,   37  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_38   ,   38  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_39   ,   39  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_40a  ,    40 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_40   ,   40  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_41   ,   41  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_42   ,   42  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_43   ,   43  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_44   ,   44  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_45   ,   45  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_46   ,   46  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_47   ,   47  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_48a  ,    48 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_48   ,   48  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_49   ,   49  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_50   ,   50  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_51   ,   51  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_52   ,   52  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_53   ,   53  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_54   ,   54  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_55   ,   55  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_56a  ,    56 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_56   ,   56  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_57   ,   57  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_58   ,   58  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_59   ,   59  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_60   ,   60  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_61   ,   61  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_62   ,   62  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_63   ,   63  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_64a  ,    64 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_64   ,   64  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_65   ,   65  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_66   ,   66  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_67   ,   67  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_68   ,   68  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_69   ,   69  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_70   ,   70  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_71   ,   71  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_72a  ,    72 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_72   ,   72  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_73   ,   73  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_74   ,   74  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_75   ,   75  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_76   ,   76  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_77   ,   77  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_78   ,   78  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_79   ,   79  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_80a  ,    80 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_80   ,   80  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_81   ,   81  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_82   ,   82  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_83   ,   83  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_84   ,   84  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_85   ,   85  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_86   ,   86  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_87   ,   87  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_88a  ,    88 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_88   ,   88  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_89   ,   89  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_90   ,   90  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_91   ,   91  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_92   ,   92  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_93   ,   93  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_94   ,   94  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_95   ,   95  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_96a  ,    96 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_96   ,   96  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_97   ,   97  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_98   ,   98  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_99    ,  99  }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_100   ,  100 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_101   ,  101 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_102   ,  102 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_103   ,  103 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_104a  ,   104}
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_104   ,  104 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_105   ,  105 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_106   ,  106 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_107   ,  107 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_108   ,  108 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_109   ,  109 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_110   ,  110 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_111   ,  111 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_112a  ,   112}
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_112   ,  112 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_113   ,  113 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_114   ,  114 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_115   ,  115 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_116   ,  116 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_117   ,  117 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_118   ,  118 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_119   ,  119 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_120a  ,   120}
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_120   ,  120 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_121   ,  121 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_122   ,  122 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_123   ,  123 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_124   ,  124 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_125   ,  125 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_126   ,  126 }
    MIDI_COMBO_ITEM { OFFSET sz_midi_patch_127   ,  127 }
    MIDI_COMBO_ITEM { 0, -1 }   ;// terminator

    sz_midiin_00      db  'port',0dh,0ah,'stream',0
    sz_midiout_01   LABEL BYTE
    sz_midiin_01      db  'clock',0
    sz_midiout_02   LABEL BYTE
    sz_midiin_02      db  'reset',0
    sz_midiin_03      db  'channel',0dh,0ah,'stream',0
    sz_midiout_04   LABEL BYTE
    sz_midiin_04      db  'patch',0
    sz_midiout_05   LABEL BYTE
    sz_midiin_05      db  'pressure',0
    sz_midiout_06   LABEL BYTE
    sz_midiin_06      db  'pitch',0dh,0ah,'wheel',0
    sz_midiout_07   LABEL BYTE
    sz_midiin_07      db  'controller',0
    sz_midiin_08      db  'note',0dh,0ah,'stream',0
    sz_midiout_09   LABEL BYTE
    sz_midiin_09      db  'note',0dh,0ah,'pressure',0
    sz_midiout_10   LABEL BYTE
    sz_midiin_10      db  'note',0dh,0ah,'on',0
    sz_midiout_11   LABEL BYTE
    sz_midiin_11      db  'note',0dh,0ah,'off',0
    sz_midiin_tracker db  'notes'    ;// no terminator
    sz_midi_not_used  db 0
    sz_midiout_track_N  db  'track N',0dh,0ah,'note',0
    sz_midiout_track_t  db  'track t',0dh,0ah,'note',0

    sz_midiout_00     db  'stream',0dh,0ah,'merge',0
    sz_midiout_03     db  'patch N',0
    sz_midiout_08     db  'controller',0dh,0ah,'N', 0

    sz_midi_ctrl_0      db '0 Bank Select (coarse)'         ,0
    sz_midi_ctrl_1      db '1 Modulation Wheel (coarse)'    ,0
    sz_midi_ctrl_2      db '2 Breath controller (coarse)'   ,0
    sz_midi_ctrl_4      db '4 Foot Pedal (coarse)'          ,0
    sz_midi_ctrl_5      db '5 Portamento Time (coarse)'     ,0
    sz_midi_ctrl_6      db '6 Data Entry (coarse)'          ,0
    sz_midi_ctrl_7      db '7 Volume (coarse)'              ,0
    sz_midi_ctrl_8      db '8 Balance (coarse)'             ,0
    sz_midi_ctrl_10     db '10 Pan position (coarse)'       ,0
    sz_midi_ctrl_11     db '11 Expression (coarse)'         ,0
    sz_midi_ctrl_12     db '12 Effect Control 1 (coarse)'   ,0
    sz_midi_ctrl_13     db '13 Effect Control 2 (coarse)'   ,0
    sz_midi_ctrl_16     db '16 GP Slider 1'                 ,0
    sz_midi_ctrl_17     db '17 GP Slider 2'                 ,0
    sz_midi_ctrl_18     db '18 GP Slider 3'                 ,0
    sz_midi_ctrl_19     db '19 GP Slider 4'                 ,0
    sz_midi_ctrl_32     db '32 Bank Select (fine)'          ,0
    sz_midi_ctrl_33     db '33 Modulation Wheel (fine)'     ,0
    sz_midi_ctrl_34     db '34 Breath controller (fine)'    ,0
    sz_midi_ctrl_36     db '36 Foot Pedal (fine)'           ,0
    sz_midi_ctrl_37     db '37 Portamento Time (fine)'      ,0
    sz_midi_ctrl_38     db '38 Data Entry (fine)'           ,0
    sz_midi_ctrl_39     db '39 Volume (fine)'               ,0
    sz_midi_ctrl_40     db '40 Balance (fine)'              ,0
    sz_midi_ctrl_42     db '42 Pan position (fine)'         ,0
    sz_midi_ctrl_43     db '43 Expression (fine)'           ,0
    sz_midi_ctrl_44     db '44 Effect Control 1 (fine)'     ,0
    sz_midi_ctrl_45     db '45 Effect Control 2 (fine)'     ,0
    sz_midi_ctrl_64     db '64 Hold Pedal (on/off)'         ,0
    sz_midi_ctrl_65     db '65 Portamento (on/off)'         ,0
    sz_midi_ctrl_66     db '66 Sustenuto Pedal (on/off)'    ,0
    sz_midi_ctrl_67     db '67 Soft Pedal (on/off)'         ,0
    sz_midi_ctrl_68     db '68 Legato Pedal (on/off)'       ,0
    sz_midi_ctrl_69     db '69 Hold 2 Pedal (on/off)'       ,0
    sz_midi_ctrl_70     db '70 Sound Variation'             ,0
    sz_midi_ctrl_71     db '71 Sound Timbre'                ,0
    sz_midi_ctrl_72     db '72 Sound Release Time'          ,0
    sz_midi_ctrl_73     db '73 Sound Attack Time'           ,0
    sz_midi_ctrl_74     db '74 Sound Brightness'            ,0
    sz_midi_ctrl_75     db '75 Sound Control 6'             ,0
    sz_midi_ctrl_76     db '76 Sound Control 7'             ,0
    sz_midi_ctrl_77     db '77 Sound Control 8'             ,0
    sz_midi_ctrl_78     db '78 Sound Control 9'             ,0
    sz_midi_ctrl_79     db '79 Sound Control 10'            ,0
    sz_midi_ctrl_80     db '80 GP Button 1 (on/off)'        ,0
    sz_midi_ctrl_81     db '81 GP Button 2 (on/off)'        ,0
    sz_midi_ctrl_82     db '82 GP Button 3 (on/off)'        ,0
    sz_midi_ctrl_83     db '83 GP Button 4 (on/off)'        ,0
    sz_midi_ctrl_91     db '91 Effects Level'               ,0
    sz_midi_ctrl_92     db '92 Tremulo Level'               ,0
    sz_midi_ctrl_93     db '93 Chorus Level'                ,0
    sz_midi_ctrl_94     db '94 Celeste Level'               ,0
    sz_midi_ctrl_95     db '95 Phaser Level'                ,0
    sz_midi_ctrl_96     db '96 Data Button increment'       ,0
    sz_midi_ctrl_97     db '97 Data Button decrement'       ,0
    sz_midi_ctrl_98     db '98 NRParameter (fine)'          ,0
    sz_midi_ctrl_99     db '99 NRParameter (coarse)'        ,0
    sz_midi_ctrl_100    db '100 RParameter (fine)'          ,0
    sz_midi_ctrl_101    db '101 RParameter (coarse)'        ,0
    sz_midi_ctrl_120    db '120 All Sound Off'              ,0
    sz_midi_ctrl_121    db '121 All Controllers Off'        ,0
    sz_midi_ctrl_122    db '122 Local (on/off)'             ,0
    sz_midi_ctrl_123    db '123 All Notes Off'              ,0
    sz_midi_ctrl_124    db '124 Omni Off'                   ,0
    sz_midi_ctrl_125    db '125 Omni On'                    ,0
    sz_midi_ctrl_126    db '126 Mono'                       ,0
    sz_midi_ctrl_127    db '127 Poly'                       ,0

    sz_midi_patch_0a    db 'PIANOS'               ,0
    sz_midi_patch_0     db '0 Acoustic Grand'     ,0
    sz_midi_patch_1     db '1 Bright Acoustic'    ,0
    sz_midi_patch_2     db '2 Electric Grand'     ,0
    sz_midi_patch_3     db '3 Honky-Tonk'         ,0
    sz_midi_patch_4     db '4 Electric 1'         ,0
    sz_midi_patch_5     db '5 Electric 2'         ,0
    sz_midi_patch_6     db '6 Harpsichord'        ,0
    sz_midi_patch_7     db '7 Clavinet'           ,0
    sz_midi_patch_8a    db 'CHROMATIC PERCUSSION' ,0
    sz_midi_patch_8     db '8 Celesta'            ,0
    sz_midi_patch_9     db '9 Glockenspiel'         ,0
    sz_midi_patch_10    db '10 Music Box'           ,0
    sz_midi_patch_11    db '11 Vibraphone'          ,0
    sz_midi_patch_12    db '12 Marimba'             ,0
    sz_midi_patch_13    db '13 Xylophone'           ,0
    sz_midi_patch_14    db '14 Tubular Bells'       ,0
    sz_midi_patch_15    db '15 Dulcimer'            ,0
    sz_midi_patch_16a   db 'ORGANS'               ,0
    sz_midi_patch_16    db '16 Drawbar'             ,0
    sz_midi_patch_17    db '17 Percussive'          ,0
    sz_midi_patch_18    db '18 Rock'                ,0
    sz_midi_patch_19    db '19 Church'              ,0
    sz_midi_patch_20    db '20 Reed'                ,0
    sz_midi_patch_21    db '21 Accoridan'           ,0
    sz_midi_patch_22    db '22 Harmonica'           ,0
    sz_midi_patch_23    db '23 Tango Accordian'     ,0
    sz_midi_patch_24a   db 'GUITARS'              ,0
    sz_midi_patch_24    db '24 Nylon String'        ,0
    sz_midi_patch_25    db '25 Steel String'        ,0
    sz_midi_patch_26    db '26 Electric Jazz'       ,0
    sz_midi_patch_27    db '27 Electric Clean'      ,0
    sz_midi_patch_28    db '28 Electric Muted'      ,0
    sz_midi_patch_29    db '29 Overdriven'          ,0
    sz_midi_patch_30    db '30 Distortion'          ,0
    sz_midi_patch_31    db '31 Harmonics'           ,0
    sz_midi_patch_32a   db 'BASSES'               ,0
    sz_midi_patch_32    db '32 Acoustic'            ,0
    sz_midi_patch_33    db '33 Electric Fingered'   ,0
    sz_midi_patch_34    db '34 Electric Picked'     ,0
    sz_midi_patch_35    db '35 Fretless'            ,0
    sz_midi_patch_36    db '36 Slap 1'              ,0
    sz_midi_patch_37    db '37 Slap 2'              ,0
    sz_midi_patch_38    db '38 Synth 1'             ,0
    sz_midi_patch_39    db '39 Synth 2'             ,0
    sz_midi_patch_40a   db 'SOLO STRINGS'         ,0
    sz_midi_patch_40    db '40 Violin'              ,0
    sz_midi_patch_41    db '41 Viola'               ,0
    sz_midi_patch_42    db '42 Cello'               ,0
    sz_midi_patch_43    db '43 Contrabass'          ,0
    sz_midi_patch_44    db '44 Tremolo'             ,0
    sz_midi_patch_45    db '45 Pizzicato'           ,0
    sz_midi_patch_46    db '46 Orchestral'          ,0
    sz_midi_patch_47    db '47 Timpani'             ,0
    sz_midi_patch_48a   db 'ENSEMBLES'            ,0
    sz_midi_patch_48    db '48 String 1'            ,0
    sz_midi_patch_49    db '49 String 2'            ,0
    sz_midi_patch_50    db '50 SynthStrings 1'      ,0
    sz_midi_patch_51    db '51 SynthStrings 2'      ,0
    sz_midi_patch_52    db '52 Choir Aahs'          ,0
    sz_midi_patch_53    db '53 Voice Oohs'          ,0
    sz_midi_patch_54    db '54 Synth Voice'         ,0
    sz_midi_patch_55    db '55 Orchestra Hit'       ,0
    sz_midi_patch_56a   db 'BRASS'                ,0
    sz_midi_patch_56    db '56 Trumpet'             ,0
    sz_midi_patch_57    db '57 Trombone'            ,0
    sz_midi_patch_58    db '58 Tuba'                ,0
    sz_midi_patch_59    db '59 Muted Trumpet'       ,0
    sz_midi_patch_60    db '60 French Horn'         ,0
    sz_midi_patch_61    db '61 Brass Section'       ,0
    sz_midi_patch_62    db '62 SynthBrass 1'        ,0
    sz_midi_patch_63    db '63 SynthBrass 2'        ,0
    sz_midi_patch_64a   db 'REEDS'                ,0
    sz_midi_patch_64    db '64 Soprano Sax'         ,0
    sz_midi_patch_65    db '65 Alto Sax'            ,0
    sz_midi_patch_66    db '66 Tenor Sax'           ,0
    sz_midi_patch_67    db '67 Baritone Sax'        ,0
    sz_midi_patch_68    db '68 Oboe'                ,0
    sz_midi_patch_69    db '69 English Horn'        ,0
    sz_midi_patch_70    db '70 Bassoon'             ,0
    sz_midi_patch_71    db '71 Clarinet'            ,0
    sz_midi_patch_72a   db 'PIPES'                ,0
    sz_midi_patch_72    db '72 Piccolo'             ,0
    sz_midi_patch_73    db '73 Flute'               ,0
    sz_midi_patch_74    db '74 Recorder'            ,0
    sz_midi_patch_75    db '75 Pan Flute'           ,0
    sz_midi_patch_76    db '76 Blown Bottle'        ,0
    sz_midi_patch_77    db '77 Skakuhachi'          ,0
    sz_midi_patch_78    db '78 Whistle'             ,0
    sz_midi_patch_79    db '79 Ocarina'             ,0
    sz_midi_patch_80a   db 'SYNTH LEADS'          ,0
    sz_midi_patch_80    db '80 Square'              ,0
    sz_midi_patch_81    db '81 Sawtooth'            ,0
    sz_midi_patch_82    db '82 Calliope'            ,0
    sz_midi_patch_83    db '83 Chiff'               ,0
    sz_midi_patch_84    db '84 Charang'             ,0
    sz_midi_patch_85    db '85 Voice'               ,0
    sz_midi_patch_86    db '86 Fifths'              ,0
    sz_midi_patch_87    db '87 Bass+Lead'           ,0
    sz_midi_patch_88a   db 'SYNTH PADS'           ,0
    sz_midi_patch_88    db '88 New Age'             ,0
    sz_midi_patch_89    db '89 Warm'                ,0
    sz_midi_patch_90    db '90 Polysynth'           ,0
    sz_midi_patch_91    db '91 Choir'               ,0
    sz_midi_patch_92    db '92 Bowed'               ,0
    sz_midi_patch_93    db '93 Metallic'            ,0
    sz_midi_patch_94    db '94 Halo'                ,0
    sz_midi_patch_95    db '95 Sweep'               ,0
    sz_midi_patch_96a   db 'SYNTH EFFECTS'        ,0
    sz_midi_patch_96    db '96 Rain'                ,0
    sz_midi_patch_97    db '97 Soundtrack'          ,0
    sz_midi_patch_98    db '98 Crystal'             ,0
    sz_midi_patch_99    db '99 Atmosphere'          ,0
    sz_midi_patch_100   db '100 Brightness'         ,0
    sz_midi_patch_101   db '101 Goblins'            ,0
    sz_midi_patch_102   db '102 Echoes'             ,0
    sz_midi_patch_103   db '103 Sci-fi'             ,0
    sz_midi_patch_104a  db 'ETHNIC'               ,0
    sz_midi_patch_104   db '104 Sitar'              ,0
    sz_midi_patch_105   db '105 Banjo'              ,0
    sz_midi_patch_106   db '106 Shamisen'           ,0
    sz_midi_patch_107   db '107 Koto'               ,0
    sz_midi_patch_108   db '108 Kalimba'            ,0
    sz_midi_patch_109   db '109 Bagpipe'            ,0
    sz_midi_patch_110   db '110 Fiddle'             ,0
    sz_midi_patch_111   db '111 Shanai'             ,0
    sz_midi_patch_112a  db 'PERCUSSIVE'           ,0
    sz_midi_patch_112   db '112 Tinkle Bell'        ,0
    sz_midi_patch_113   db '113 Agogo'              ,0
    sz_midi_patch_114   db '114 Steel Drums'        ,0
    sz_midi_patch_115   db '115 Woodblock'          ,0
    sz_midi_patch_116   db '116 Taiko Drum'         ,0
    sz_midi_patch_117   db '117 Melodic Tom'        ,0
    sz_midi_patch_118   db '118 Synth Drum'         ,0
    sz_midi_patch_119   db '119 Reverse Cymbal'     ,0
    sz_midi_patch_120a  db 'SOUND EFFECTS'        ,0
    sz_midi_patch_120   db '120 Guitar Fret Noise'  ,0
    sz_midi_patch_121   db '121 Breath Noise'       ,0
    sz_midi_patch_122   db '122 Seashore'           ,0
    sz_midi_patch_123   db '123 Bird Tweet'         ,0
    sz_midi_patch_124   db '124 Telephone Ring'     ,0
    sz_midi_patch_125   db '125 Helicopter'         ,0
    sz_midi_patch_126   db '126 Applause'           ,0
    sz_midi_patch_127   db '127 Gunshot'            ,0

    ALIGN 4


comment ~ /*

;// GM DRUM SOUNDS

35  Acoustic Bass Drum
36  Bass Drum 1
37  Side Stick
38  Acoustic Snare
39  Hand Clap
40  Electric Snare
41  Low Floor Tom
42  Closed Hi-Hat
43  High Floor Tom
44  Pedal Hi-Hat
45  Low Tom
46  Open Hi-Hat
47  Low-Mid Tom
48  Hi-Mid Tom
49  Crash Cymbal 1
50  High Tom
51  Ride Cymbal 1
52  Chinese Cymbal
53  Ride Bell
54  Tambourine
55  Splash Cymbal
56  Cowbell
57  Crash Cymbal 2
58  Vibraslap
59  Ride Cymbal 2
60  Hi Bongo
61  Low Bongo
62  Mute High Conga
63  Open High Conga
64  Low Conga
65  High Timbale
66  Low Timbale
67  High Agogo
68  Low Agogo
69  Cabasa
70  Maracas
71  Short Whistle
72  Long Whistle
73  Short Guiro
74  Long Guiro
75  Claves
76  High Wood Block
77  Low Wood Block
78  Mute Cuica
79  Open Cuica
80  Mute Triangle
81  Open Triangle

*/ comment ~


.CODE


ASSUME_AND_ALIGN
midistring_SetFonts PROC

    ;// destroys edi

    mov eax, midi_font_N_out
    DEBUG_IF <eax !!= 'N'>  ;// fonts are already set !!
    mov edi, OFFSET font_bus_slist_head
    invoke font_Locate
    mov midi_font_N_out, edi

    mov eax, midi_font_s1_out
    mov edi, OFFSET font_bus_slist_head
    invoke font_Locate
    mov midi_font_s1_out, edi

    mov eax, midi_font_N_in
    mov edi, OFFSET font_pin_slist_head
    invoke font_Locate
    mov midi_font_N_in, edi

    mov eax, midi_font_s1_in
    mov edi, OFFSET font_pin_slist_head
    invoke font_Locate
    mov midi_font_s1_in, edi

    mov eax, midi_font_F
    mov edi, OFFSET font_bus_slist_head
    invoke font_Locate
    mov midi_font_F, edi

    mov eax, midi_font_plus_minus
    mov edi, OFFSET font_bus_slist_head
    invoke font_Locate
    mov midi_font_plus_minus, edi

    mov eax, midi_font_plus_zero
    mov edi, OFFSET font_bus_slist_head
    invoke font_Locate
    mov midi_font_plus_zero, edi

    ret

midistring_SetFonts ENDP







ASSUME_AND_ALIGN

ENDIF ;// USE_THIS_FILE


END

