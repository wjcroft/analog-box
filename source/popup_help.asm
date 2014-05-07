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
;// popup_help.asm      help strings used in the popup panels
;//
OPTION CASEMAP:NONE
.586
.MODEL FLAT

    INCLUDE <popup_strings.inc>

.DATA

popup_help_first LABEL BYTE


sz_WAVEIN_ID_WAVE_LESS      LABEL BYTE
sz_WAVEOUT_ID_WAVE_LESS     db  'Reduce the number of buffers between ABox and the device. May cause dropouts.',0

sz_WAVEIN_ID_WAVE_MORE      LABEL BYTE
sz_WAVEOUT_ID_WAVE_MORE     db  'Increase the number of buffers between ABox and the device.',0

sz_WAVEIN_ID_WAVE_BUFFERS   LABEL BYTE
sz_WAVEOUT_ID_WAVE_BUFFERS  db 'Each buffer is 1024 samples, about 23.2 ms.',0

;//sz_WAVEIN_IDC_STATIC     LABEL BYTE
;//sz_WAVEOUT_IDC_STATIC        db  0

sz_MIDIIN2_ID_MIDIIN_INPUT_LIST     LABEL BYTE
sz_MIDIOUT2_ID_MIDIOUT_OUTPUT_LIST  LABEL BYTE
sz_WAVEIN_ID_WAVE_LIST              LABEL BYTE
sz_WAVEOUT_ID_WAVE_LIST             db  'Double click to select another device.',0

sz_MIDIIN2_ID_MIDIIN_INPUT_NAME_STATIC      LABEL BYTE
sz_MIDIOUT2_ID_MIDIOUT_OUTPUT_NAME_STATIC   LABEL BYTE
sz_WAVEIN_ID_WAVE_NAME      LABEL BYTE
sz_WAVEOUT_ID_WAVE_NAME     db 'Currently selected device.',0

sz_WAVEIN_ID_WAVE_LATENCY   LABEL BYTE
sz_WAVEOUT_ID_WAVE_LATENCY  db  "Estimated maximum latency between ABox and the device. ?? = not measured yet.",0


sz_WAVEIN_IDC_STATIC_BUFFERS        LABEL BYTE
sz_WAVEOUT_IDC_STATIC_BUFFERS       db 'Set the number of buffers to reduce latency or increase stability',0
sz_WAVEIN_IDC_STATIC_MAX_LATENCY    LABEL BYTE
sz_WAVEOUT_IDC_STATIC_MAX_LATENCY   db 'The minimum latency will be 23ms less than the maximum.',0




sz_HID_IDC_STATIC_HID_PINS  LABEL BYTE
sz_HID_ID_HID_PINS          db 'Select a pin then select an item from the control list.',0

sz_HID_IDC_STATIC_HID_CONTROLS LABEL BYTE
sz_HID_ID_HID_CONTROLS      db 'Shows the available devices and controls.',0

sz_HID_ID_HID_FLOAT_POS     db  'Do not change the sign of the control data. {Numpad +}',0
sz_HID_ID_HID_FLOAT_NEG     db  'Change the sign of the control data. {Numpad -}',0

sz_HID_IDC_STATIC_HID_SIGN  db  'Adjusts the sign of the selected control. Affects all objects connected to it.',0


sz_SAMHOLD_IDC_STATIC_MODE      db  'May be set to a per/sample or per/frame. { S F }',0
sz_SAMHOLD_IDC_STATIC_SINPUT    db  'The s input tells the object when to get new data from the X input. { / \ " > < } ',0

sz_SAMHOLD_ID_SH_SAMPLE     db  'Internal buffer is a signal sample. { S }',0
sz_SAMHOLD_ID_SH_FRAME      db  'Internal buffer is a queue of 1024 samples. New data is appended to the end. { F }',0

sz_SAMHOLD_ID_SH_POS_EDGE   db  'Accept new data when s goes positive. { / }',0
sz_SAMHOLD_ID_SH_NEG_EDGE   db  'Accept new data when s goes negative. { \ }',0
sz_SAMHOLD_ID_SH_BOTH_EDGE  db  'Accept new data when s changes sign. { " }',0
sz_SAMHOLD_ID_SH_POS_GATE   db  'Accept new data only when s is positive or zero. { > }',0
sz_SAMHOLD_ID_SH_NEG_GATE   db  'Accept new data only when s is negative. { < }',0

sz_SAMHOLD_ID_SH_ZEROSTART  db  'Reset all internal data when play starts. { Z }',0



sz_READOUT_ID_READOUT_METER1 db 'Display as an RMS VU meter with peak and average indicators. { 1 }',0
sz_READOUT_ID_READOUT_METER2 db 'Display as a high low VU meter with pos neg peak and average indicators. { 2 }',0

sz_READOUT_ID_READOUT_SMALL db  'Display a smaller readout. { Double left click or Enter }',0





sz_RAND_IDC_STATIC_NEXT     db  'The n pin tells the object when to produce the next value. { " / \ > < }',0
sz_RAND_IDC_STATIC_RESTART  db  'The s pin tells the object when to restart with the S value. { P N O }',0

sz_RAND_ID_RAND_NEXT_BOTH_EDGE  db  'Next value when n changes sign. { " }',0
sz_RAND_ID_RAND_NEXT_POS_EDGE   db  'Next value when n goes positive. { / }',0
sz_RAND_ID_RAND_NEXT_NEG_EDGE   db  'Next value when n goes negative. { \ }',0
sz_RAND_ID_RAND_NEXT_POS_GATE   db  'Next value when n is positive. { > }',0
sz_RAND_ID_RAND_NEXT_NEG_GATE   db  'Next value when n is negative. { < }',0

sz_RAND_ID_RAND_SEED_POS_EDGE   db  'Seed the sequence with the value at S when s goes positive. { P }',0
sz_RAND_ID_RAND_SEED_NEG_EDGE   db  'Seed the sequence with the value at S when s goes negative. { N }',0
sz_RAND_ID_RAND_SEED_BOTH_EDGE  db  'Seed the sequence with the value at S when s changes sign. { O }',0
;// sz_RAND_IDC_STATIC          db  0

sz_QKEY_VK_1        LABEL BYTE
sz_QKEY_VK_2        LABEL BYTE
sz_QKEY_VK_3        LABEL BYTE
sz_QKEY_VK_4        LABEL BYTE
sz_QKEY_VK_5        LABEL BYTE
sz_QKEY_VK_6        LABEL BYTE
sz_QKEY_VK_7        LABEL BYTE
sz_QKEY_VK_8        LABEL BYTE
sz_QKEY_VK_9        LABEL BYTE
sz_QKEY_VK_0        LABEL BYTE
sz_QKEY_VK_MINUS    db 'Enable or disable this note. { 0-9 - }',0
sz_QKEY_VK_F        db 'Output is converted to a frequency. { F }',0
sz_QKEY_VK_M        db 'Output is converted to a midi note. { M }',0

sz_SCOPE_IDC_SCOPE_OSCOPE       db  '2 channel Oscilloscope mode. r and o inputs control vertical scale and offset. { O }',0
sz_SCOPE_IDC_SCOPE_SPECTRUM     db  'Spectrum analyzer mode. r input controls vertical scale. o input controls start frequency. { S }',0
sz_SCOPE_IDC_SCOPE_SONOGRAPH    db  'Sonograph mode. r input controls color scale. { G }',0

sz_SCOPE_IDC_SCOPE_SWEEP        db  'The sweep rate tells the scope how fast to scan from left to right.',0

sz_SCOPE_IDC_SCOPE_RANGE1_0     db  '1 sample per pixel. 1/4 frame per sweep.',0
sz_SCOPE_IDC_SCOPE_RANGE1_1     db  '4 samples per pixel. 1 frame per sweep.',0
sz_SCOPE_IDC_SCOPE_RANGE1_2     db  '16 samples per pixel. 4 frames per sweep.',0
sz_SCOPE_IDC_SCOPE_RANGE1_3     db  '64 samples per pixel. 16 frames per sweep.',0
sz_SCOPE_IDC_SCOPE_RANGE1_4     db  '256 samples per pixel. 64 frames per sweep.',0
sz_SCOPE_IDC_SCOPE_RANGE1_5     db  '1024 samples per pixel. 256 frames per sweep.',0
sz_SCOPE_IDC_SCOPE_RANGE1_6     db  '4096 samples per pixel. 1024 frames per sweep.',0
sz_SCOPE_IDC_SCOPE_RANGE1_7     db  'X-Y mode. Requires that X be connected to provide left-right position.',0

sz_SCOPE_IDC_SCOPE_TRIGGER      db  'Enables the s input to start the sweep. Connect appropriate circuitry to cause a trigger event.',0
sz_SCOPE_IDC_SCOPE_TRIGGER_NONE db  'Disable the s input.',0
sz_SCOPE_IDC_SCOPE_TRIGGER_POS  db  'Start the sweep when s goes from negative to positive.',0
sz_SCOPE_IDC_SCOPE_TRIGGER_NEG  db  'Start the sweep when s goes from positive to negative.',0

sz_SCOPE_IDC_SCOPE_SCROLL       db  'Shift the display to left and add new data at the right. { S }',0
sz_SCOPE_IDC_SCOPE_LABELS       db  'Show or hide labels on the display. { L }',0

;// sz_SCOPE_IDC_SCOPE_UNITS        db  'The scope may set the display scale to Hertz or Midi note.',0

sz_SCOPE_IDC_SCOPE_ON           db  'Turn the scope ON or OFF. { Double left click or Enter }',0
sz_SCOPE_IDC_SCOPE_WIDTH        db  'Width tells the analyzer how much of the spectrum to display.',0
sz_SCOPE_IDC_SCOPE_RANGE2_0     db  '1/8 spectrum. Use the O input to shift left or right.',0
sz_SCOPE_IDC_SCOPE_RANGE2_1     db  '1/4 spectrum. Use the O input to shift left or right.',0
sz_SCOPE_IDC_SCOPE_RANGE2_2     db  '1/2 spectrum. Use the O input to shift left or right.',0

sz_SCOPE_IDC_SCOPE_AVERAGE      db  'Show or hide the averaging trace. { A }',0
sz_SCOPE_IDC_SCOPE_MODE         db  'The scope may be set to one of three modes { O S G }.',0

sz_SCOPE_IDC_SCOPE_RATE         db  'Scan rate tells the sonograph how often to add new data.',0
sz_SCOPE_IDC_SCOPE_RANGE3_0     db  '4 new columns per frame.',0
sz_SCOPE_IDC_SCOPE_RANGE3_1     db  '2 new columns per frame.',0
sz_SCOPE_IDC_SCOPE_RANGE3_2     db  '1 new column per frame.',0

sz_SCOPE_IDC_SCOPE_HEIGHT       db  'Height tells the sonograph how much of the spectrum to display.',0
sz_SCOPE_IDC_SCOPE_RANGE4_0     db  '1/4 spectrum. Use the O input to shift up or down.',0
sz_SCOPE_IDC_SCOPE_RANGE4_1     db  '1/2 spectrum. Use the O input to shift up or down.',0

sz_SCOPE_IDC_SCOPE_RANGE4_2     LABEL BYTE
sz_SCOPE_IDC_SCOPE_RANGE2_3     db  'Full spectrum. O input is ignored.',0







sz_OSCILLATOR_IDC_STATIC_ANALOG     db  'Analog wave forms are stored in lookup tables. They are slower but sound better. Use these for audio data.',0
sz_OSCILLATOR_IDC_STATIC_DIGITAL    db  'Digital wave forms are calculated by the CPU. They are faster but sound worse. Use these for control signals.',0
sz_OSCILLATOR_IDC_STATIC_FP         db  'Frequency or Phase input. { F P }',0

sz_OSCILLATOR_ID_O_SINEWAVE db  'Sine wave. { S }',0
sz_OSCILLATOR_ID_O_TRIANGLE db  'Triangle wave. { T }',0

sz_OSCILLATOR_ID_O_SQUARE1  db  'Lowpass filtered square wave. { Q }',0
sz_OSCILLATOR_ID_O_SQUARE2  db  'Frequency limited square wave. { U }',0
sz_OSCILLATOR_ID_O_SQUARE   db  'Pure digital square wave. Useful for timing ticks. { E }',0

sz_OSCILLATOR_ID_O_RAMP1    db  'Lowpass filtered ramp wave (saw tooth). { R }',0
sz_OSCILLATOR_ID_O_RAMP2    db  'Frequency limited ramp wave (saw tooth). { A }',0
sz_OSCILLATOR_ID_O_RAMP     db  'Pure digital ramp wave. Useful for phase inputs or linear ramps. { M }',0

sz_OSCILLATOR_ID_O_FREQ     db  'Set the F/P input to control the frequency. { F }',0
sz_OSCILLATOR_ID_O_PHASE    db  'Set the F/P input to control the phase. Requires changing phase to change the output. { P }',0

sz_OSCILLATOR_IDC_STATIC_RESET  db 'Where to start the waveform. Both off is undefined.',0
sz_OSCILLATOR_ID_O_RESET_ONE    db 'Start at -180 degrees, causes pos to neg edge on first output.',0
sz_OSCILLATOR_ID_O_RESET_ZERO   db 'Start at 0 degrees, output begins at 0 and goes positive.',0


sz_MPLEX_IDC_STATIC_MODE    db  'Tells the object how to use the s input to combine the X and Y inputs.',0
sz_MPLEX_ID_MPLEX_MPLEX     db  'Outputs 0.0 at center and X or Y elsewhere. { M }',0
sz_MPLEX_ID_MPLEX_XFADE     db  'Outputs X+Y at center and X and Y elsewhere. { C }',0
sz_MPLEX_ID_MPLEX_XFADE2    db  'Outputs 1/2 X+Y at center and X and Y elsewhere. { F }',0

sz_MATH_ID_MATH_ADD     db  'Arithmetic: Add X+Y { NumPad + }',0
sz_MATH_ID_MATH_MULT    db  'Arithmetic: Multiply X*Y { NumPad * }',0
sz_MATH_ID_MATH_SUB     db  'Arithmetic: Subtract X-Y { NumPad - }',0

sz_MATH_ID_MATH_AND     db  'Logic Gate: TRUE if a AND b are TRUE, otherwise FALSE { A }',0
sz_MATH_ID_MATH_OR      db  'Logic Gate: TRUE if a OR b are TRUE, otherwise FALSE { O }',0
sz_MATH_ID_MATH_NAND    db  'Logic Gate: FALSE if a AND b are TRUE, otherwise TRUE { N }',0
sz_MATH_ID_MATH_NOR     db  'Logic Gate: FALSE if a OR b are TRUE, otherwise TRUE { R }', 0
sz_MATH_ID_MATH_XOR     db  'Logic Gate: TRUE if a OR b are TRUE, but not BOTH, otherwise FALSE { X }',0

sz_MATH_ID_MATH_LT      db  'Comparison: TRUE if a is LESS THAN b, otherwise FALSE { < }',0
sz_MATH_ID_MATH_GT      db  'Comparison: TRUE if a is GREATER THAN b, otherwise FALSE { > }',0
sz_MATH_ID_MATH_LTE     db  'Comparison: TRUE if a is LESS THAN or EQUAL to b, otherwise FALSE { ( }',0
sz_MATH_ID_MATH_GTE     db  'Comparison: TRUE if a is GREATER THAN or EQUAL to b, otherwise FALSE { ) }',0
sz_MATH_ID_MATH_E       db  'Comparison: TRUE if a is EQUAL to b, otherwise FALSE { = }',0
sz_MATH_ID_MATH_NE      db  'Comparison: TRUE if a is NOT EQUAL to b, otherwise FALSE { ! }',0









sz_SLIDER_IDC_STATIC_MODE   LABEL BYTE
sz_KNOB_IDC_STATIC_MODE     db  'The object may be set to simply produce values, or to add or multiply to an input signal. { NumPad / + * }',0

sz_SLIDER_ID_SLIDER_SLIDE   db  'Input signal is ignored. Just produce a value. { NumPad / }',0
sz_KNOB_IDC_KNOB_MODE_KNOB  db  'Input signal is ignored. Just produce a value. [knob] { NumPad / }',0

sz_SLIDER_ID_SLIDER_ADD     db  'Add the value on the control to the input signal. { NumPad + }',0
sz_KNOB_IDC_KNOB_MODE_ADD   db  'Add the value on the control to the input signal. [add +] { NumPad + }',0

sz_SLIDER_ID_SLIDER_MULT    db  'Multiply the input signal by value on the control. { NumPad * }',0
sz_KNOB_IDC_KNOB_MODE_MULT  db  'Multiply the input signal by value on the control. [multiply mult mul *] { NumPad * }',0
;// sz_KNOB_IDC_STATIC          db  0




sz_KNOB_ID_KNOB_WRAP        db  'When knob is at maximum of minimum value, wrap around to opposite extreme. { W }',0

sz_KNOB_IDC_STATIC_TURNS    db  'Set the number of turns of the inner knob for precise control. [turn(s) t] { 0-9 }',0
sz_KNOB_IDC_STATIC_TAPER    db  'Set the taper to control the action at various positions. { A L }',0

sz_KNOB_ID_KNOB_LINEAR      db  'Set inner knob to linear taper. Changes have the same effect regardless where the control is. [linear lin] { L }',0
sz_KNOB_ID_KNOB_AUDIO       db  'Set inner knob to audio taper. Changes close to zero have less effect. Useful for frequency and time. [audio aud log] { A }',0

sz_SLIDER_ID_SLIDER_PRESET_0    LABEL BYTE
sz_KNOB_ID_KNOB_ZERO        db  'Set the value to zero. { NumPad 0 }',0

sz_SLIDER_ID_SLIDER_PRESET_1    LABEL BYTE
sz_KNOB_ID_KNOB_ONE         db  'Set the value to +1.0. { NumPad 1 }',0

sz_SLIDER_ID_SLIDER_PRESET_NEG  LABEL BYTE
sz_KNOB_ID_KNOB_NEG         db  'Change the sign of the value. [neg] { NumPad - }',0

sz_KNOB_IDC_KNOB_PRESETS   LABEL BYTE
sz_KNOB_IDC_STATIC_PRESETS  db  'Preset configurations and values. Double click to activate. { NumPad 2-9 }',0

sz_KNOB_IDC_KNOB_EDIT   LABEL BYTE
                            db  'Type in new values, units, turns and modes. Press Enter when done.',0

sz_KNOB_IDC_KNOB_TURNS   LABEL BYTE
                            db  'Adjust the number of turns. [turn(s) T] { 0-9 }',0


sz_KNOB_ID_KNOB_SET db 'Save the current knob configuration to the selected preset list item.',0



;//sz_KNOB_ID_KNOB_PRESET_0 LABEL BYTE
;//sz_KNOB_ID_KNOB_PRESET_1 LABEL BYTE

;// help strings for these are set manually

sz_READOUT_IDC_READOUT_UNITS    LABEL BYTE
sz_KNOB_IDC_KNOB_UNITS          LABEL BYTE


;//sz_KNOB_IDC_LIST2   LABEL BYTE
;//sz_KNOB_IDC_COMBO1   LABEL BYTE
;//sz_KNOB_IDC_EDIT1   LABEL BYTE
;//sz_KNOB_IDC_COMBO2   LABEL BYTE
;//sz_KNOB_IDC_STATIC_UNITS2   LABEL BYTE

    db 0



sz_FILE_ID_FILE_MODE_STATIC     db 'Select from one of the modes below',0
sz_FILE_ID_FILE_MODE_DATA       db 'Read and write raw floating point values to a .DAT file.',0
sz_FILE_ID_FILE_MODE_MEMORY     db 'Read and write raw floating point values to a memory buffer.',0
sz_FILE_ID_FILE_MODE_READER     db 'Read the audio stream from a media file.',0
sz_FILE_ID_FILE_MODE_WRITER     db 'Write 16 bit stereo samples to a .WAV file',0
sz_FILE_ID_FILE_MODE_CSVWRITER  db 'Write numeric data to a text file.',0
sz_FILE_ID_FILE_MODE_CSVREADER  db 'Read a table of numbers from a text file. co and ro pins are the Column and Row to read.',0


sz_FILE_ID_FILE_NAME            db 'Press to change the file name.',0

sz_FILE_ID_FILE_LENGTH_STATIC   db 'This mode requires a length in samples.',0
sz_FILE_ID_FILE_LENGTH_EDIT     db 'Current length of the file in samples. Edit and press Enter to set.',0
sz_FILE_ID_FILE_MAXLENGTH_STATIC db 'Maximum allowable length.',0

sz_FILE_ID_FILE_ID_STATIC       db 'The identifier of this memory buffer. Memory buffers with the same ID can share data.',0
sz_FILE_ID_FILE_ID_EDIT         db 'Change the ID of this memory buffer. Press Enter to set.',0

;// ABOX234 seek,write,move buttons have been moved to ABoxOscFile.asm
;// see file_button_init_table

;//sz_FILE_ID_FILE_SEEK_STATIC      db 's (Seek) controls when seeking to position P occurs.',0
;//sz_FILE_ID_FILE_SEEK_BOTH_EDGE   db 'Seek to position P when s changes sign.',0
;//sz_FILE_ID_FILE_SEEK_POS_EDGE    db 'Seek to position P when s goes positive.',0
;//sz_FILE_ID_FILE_SEEK_NEG_EDGE    db 'Seek to position P when s goes negative.',0
;//sz_FILE_ID_FILE_SEEK_POS_GATE    db 'Seek to position P when s is positive. Otherwise use the move trigger.',0
;//sz_FILE_ID_FILE_SEEK_NEG_GATE    db 'Seek to position P when s is negative. Otherwise use the move trigger.',0

sz_FILE_ID_FILE_SEEK_SYNC       db 'Reduces drop-outs caused by seeking at the risk of interrupting the entire circuit.',0
sz_FILE_ID_FILE_SEEK_NORM       db 'Normalized Position P. -1 is beginning, 0 is half way through, +1 is the end of the file.',0
sz_FILE_ID_FILE_SEEK_PERCENT    db 'Position P is a percentage (0 to +1) of the total length.',0

;//sz_FILE_ID_FILE_WRITE_STATIC db 'w (Write) controls when writing occurs.',0
;//sz_FILE_ID_FILE_WRITE_BOTH_EDGE  db 'Write one sample when w changes sign.',0
;//sz_FILE_ID_FILE_WRITE_POS_EDGE   db 'Write one sample when w goes positive.',0
;//sz_FILE_ID_FILE_WRITE_NEG_EDGE   db 'Write one sample when w goes negative.',0
;//sz_FILE_ID_FILE_WRITE_POS_GATE   db 'Write samples when w is positive.',0
;//sz_FILE_ID_FILE_WRITE_NEG_GATE   db 'Write samples when w is negative.',0

;//sz_FILE_ID_FILE_MOVE_STATIC      db 'm (Move) controls when the file position advances by the value at sr.',0
;//sz_FILE_ID_FILE_MOVE_BOTH_EDGE   db 'Move by sr when m changes sign.',0
;//sz_FILE_ID_FILE_MOVE_POS_EDGE    db 'Move by sr when m goes positive.',0
;//sz_FILE_ID_FILE_MOVE_NEG_EDGE    db 'Move by sr when m goes negative.',0
;//sz_FILE_ID_FILE_MOVE_POS_GATE    db 'Move at sr when m is positive.',0
;//sz_FILE_ID_FILE_MOVE_NEG_GATE    db 'Move at sr when m is negative.',0

sz_FILE_ID_FILE_MOVE_REWIND     db 'Rewind to start when the end is reached.',0

sz_FILE_ID_FILE_FMT_STATIC      db 'Format of the file.',0

sz_DPLEX_IDC_STATIC_MODE    db  'Tells the object how to apply the s input to route the X input to Y and Z. { D P A }',0
sz_DPLEX_ID_DPLEX_DPLEX     db  'Set Y and Z to 0.0 at the center position. Route X to Y or Z otherwise. { D }',0
sz_DPLEX_ID_DPLEX_PAN       db  'Set Y and Z equal to X at the center position. Route X to Y and Z otherwise. { P }',0
sz_DPLEX_ID_DPLEX_PAN2      db  'Set Y and Z equal to 1/2 X at the center position. Route X to Y and Z otherwise. { A }',0


sz_DIVIDER_IDC_STATIC_COUNT     db  'The t input tells the object when to count. { P N O }',0
sz_DIVIDER_IDC_STATIC_RESET     db  'The r input tells the object when to start over. { / \ " > < }',0
sz_DIVIDER_IDC_STATIC_OUTPUT    db  'The output may be set to two ranges.',0

sz_DIVIDER_ID_DIGITAL_POS       db  'Count positive t edges only. { P }',0
sz_DIVIDER_ID_DIGITAL_NEG       db  'Count negative t edges only. { N }',0
sz_DIVIDER_ID_DIGITAL_BOTH      db  'Count both positive and negative t edges. { O }',0

sz_DIVIDER_ID_DIVIDER_RESET_POS_EDGE    db 'Reset on positive r edge. { / }',0
sz_DIVIDER_ID_DIVIDER_RESET_NEG_EDGE    db 'Reset on negative r edge. { \ }',0
sz_DIVIDER_ID_DIVIDER_RESET_BOTH_EDGE   db 'Reset on either r edge. { " }',0
sz_DIVIDER_ID_DIVIDER_RESET_POS_GATE    db 'Reset when r is positive or zero. { > }',0
sz_DIVIDER_ID_DIVIDER_RESET_NEG_GATE    db 'Reset when r is negative. { < }',0

sz_DIVIDER_ID_DIVIDER_HOLD  db  'When count is reached, hold output until reset is received. { S }',0

sz_DIVIDER_ID_DIVIDER_1         LABEL BYTE
sz_DIVIDER_ID_DIVIDER_2         LABEL BYTE
sz_DIVIDER_ID_DIVIDER_3         LABEL BYTE
sz_DIVIDER_ID_DIVIDER_4         LABEL BYTE
sz_DIVIDER_ID_DIVIDER_5         LABEL BYTE
sz_DIVIDER_ID_DIVIDER_6         LABEL BYTE
sz_DIVIDER_ID_DIVIDER_7         LABEL BYTE
sz_DIVIDER_ID_DIVIDER_8         LABEL BYTE
sz_DIVIDER_ID_DIVIDER_9         LABEL BYTE
sz_DIVIDER_ID_DIVIDER_10        LABEL BYTE
sz_DIVIDER_ID_DIVIDER_11        LABEL BYTE
sz_DIVIDER_ID_DIVIDER_12        LABEL BYTE
sz_DIVIDER_ID_DIVIDER_13        LABEL BYTE
sz_DIVIDER_ID_DIVIDER_14        LABEL BYTE
sz_DIVIDER_ID_DIVIDER_15        LABEL BYTE
sz_DIVIDER_ID_DIVIDER_16        db  'Count this many edges, flip the output, then start over. { 1-9 Q W E R T Y }',0

sz_DELTA_ID_DELTA_NORMAL        db  'Difference between adjacent samples. { N }',0
sz_DELTA_ID_DELTA_DIGITAL       db  "Make the difference negative, unless it's zero. Use to detect when a signal changes. { D }",0
sz_DELTA_ID_DELTA_ABSOLUTE      db  "Make the difference positive, unless it's zero. Use to detect when a signal doesn't change. { A }",0
sz_DELTA_ID_DELTA_DERIVATIVE    db  'Approximates the time derivative of the input signal. { E }',0
sz_DELTA_IDC_DELTA_STATIC_STATS         db 'Peak is frequency and error at highest response. Zero is best bandwidth and error after the last zero (if any).',0
sz_DELTA_IDC_DELTA_STATIC_NUM_POINTS    LABEL BYTE
sz_DELTA_IDC_DELTA_SCROLL_NUMPOINTS     LABEL BYTE
sz_DELTA_IDC_DELTA_STATIC_NUM_POINTS_VALUE  db 'Number of points to compute with. More takes longer to calculate. Latency is always 1/2 this number.',0
sz_DELTA_IDC_DELTA_STATIC_ALPHA         LABEL BYTE
sz_DELTA_IDC_DELTA_SCROLL_ALPHA         LABEL BYTE
sz_DELTA_IDC_DELTA_STATIC_ALPHA_VALUE   db 'Flatness parameter, higher values are flatter but may lower the bandwidth.',0

sz_DELAY_ID_DELAY_INTERP_ALWAYS db  'Always interpolate between samples, even if D is static. { I }',0

sz_DAMPER_IDC_STATIC_NUM_POINTS db  'Number of points sets the lag between the input and the output. { 3 5 7 9 }',0
sz_DAMPER_ID_DAMPER_RANGE_3     db  'Output reaches the input after 3 samples. Cutoff approx 11KHz. { 3 }',0
sz_DAMPER_ID_DAMPER_RANGE_5     db  'Output reaches the input after 5 samples. Cutoff approx 5KHz. { 5 }',0
sz_DAMPER_ID_DAMPER_RANGE_7     db  'Output reaches the input after 7 samples. Cutoff approx 3KHz. { 7 }',0
sz_DAMPER_ID_DAMPER_RANGE_9     db  'Output reaches the input after 9 samples. Cutoff approx 2KHz. { 9 }',0

sz_BUTTON_ID_BUTTON_MOMENTARY   db  'Set the button action to momentary. { M }',0
sz_BUTTON_ID_BUTTON_TOGGLE      db  'Set the button action to push-on/push-off. { P }',0

sz_HID_ID_HID_BOOL_POS          LABEL BYTE
sz_MATH_ID_MATH_BIPOLAR         LABEL BYTE
;//sz_MIDIIN_ID_MIDI_BIPOLAR        LABEL BYTE
sz_DIVIDER_ID_DIGITAL_BIPOLAR   LABEL BYTE
sz_BUTTON_ID_DIGITAL_BIPOLAR    db  'Set output to TRUE=-1.0 and FALSE=1.0 { B }',0

sz_HID_ID_HID_BOOL_NEG          LABEL BYTE
sz_MATH_ID_MATH_DIGITAL         LABEL BYTE
;//sz_MIDIIN_ID_MIDI_DIGITAL        LABEL BYTE
sz_DIVIDER_ID_DIGITAL_DIGITAL   LABEL BYTE
sz_BUTTON_ID_DIGITAL_DIGITAL    db  'Set output to TRUE=-1.0 and FALSE=0.0 { D }',0

sz_ADSR_IDC_STATIC_TSTART   db  'The t input tells the object when to start, release and restart.',0

sz_ADSR_ID_ADSR_START_POS   db  'Start or Restart the envelope on the positive edge of the t input. Release will be the negative edge. { P }',0
sz_ADSR_ID_ADSR_START_NEG   db  'Start or Restart the envelope on the negative edge of the t input. Release will be the positive edge. { N }',0
sz_ADSR_ID_ADSR_NOSUSTAIN   db  'Do not wait for the release trigger. { S }',0
sz_ADSR_ID_ADSR_NORETRIGGER db  'Never allow the envelope to restart when it is already in progress. { R }',0
sz_ADSR_ID_ADSR_IGNORE_T    db  'Only grab the T value when the envelope is started or restarted. { I }',0
sz_ADSR_ID_ADSR_AUTORESTART db 'Restart when envelope is finished if t input on. { A }',0

;// sz_ADSR_IDC_STATIC              db  0

;//sz_1CP_IDC_STATIC_MODE   db  'The filter mode may be 1 pole, or 1 zero.',0
sz_1CP_ID_IIR_UNITY     db  'Calculate the input attenuation based on the F, R and L values. { = }',0

sz_1CP_ID_IIR_DETAIL    db  'Shows the filter response on a log scale from 20Hz to 20Khz. { Double left click or Enter }',0
sz_1CP_ID_IIR_1CP       db  'A pair of conjugate poles. R = Radius from origin on z-plane. { P }', 0
sz_1CP_ID_IIR_1CZ       db  'A pair of conjugate zeros. R = Radius from origin on z-plane. { Z }', 0

sz_1CP_ID_IIR_LP1   db  "1st order Low Pass filter. 6db/octave. { O }",0
sz_1CP_ID_IIR_HP1   db  "1st order High Pass filter. 6db/octave. { I }",0
sz_1CP_ID_IIR_BP2   db  "2nd order Band Pass filter. 6db/octave. L=Log2(Q). Q=2^L. { B }",0
sz_1CP_ID_IIR_LP2   db  "2nd order Low Pass filter. 12db/octave. L=Log2(Q). Q=2^L. { L }",0
sz_1CP_ID_IIR_HP2   db  "2nd order High Pass filter. 12db/octave. L=Log2(Q). Q=2^L. { H }",0
sz_1CP_ID_IIR_BR2   db  "2nd order Band Reject filter. 12db/octave. L=Log2(Q). Q=2^L. { R }",0

sz_1CP_ID_DECAY_BOTH    db  'Low frequency RC Lowpass filter. Output always follows input. T=RC time. { T }',0
sz_1CP_ID_DECAY_ABOVE   db  'Low frequency RC Lowpass filter. Output follows input only when input is higher than output. T=RC time. { A }',0
sz_1CP_ID_DECAY_BELOW   db  'Low frequency RC Lowpass filter. Output follows input only when input is lower than output. T=RC time. { E }',0

sz_IIR_IDC_STATIC_SCALE     db  'The angular scale may be set as linear or logarithmic. { N G }',0
sz_IIR_IDC_STATIC_DISPLAY   db  'Additional display features for this object.',0

sz_IIR_IDC_IIR_HP       db  'Set the filter to High Pass mode, Pole and Zero are enabled. { H }',0
sz_IIR_IDC_IIR_BP       db  'Set the filter to Band Pass mode, Pole is enabled, Zero is only effect on the X axis. { B }',0
sz_IIR_IDC_IIR_LP       db  'Set the filter to Low Pass mode. Zero is disabled. { L }',0
sz_IIR_IDC_IIR_LIN      db  'Set the angular display to linear scale. The dots are one octave apart. { N }',0
sz_IIR_IDC_IIR_LOG      db  'Set the angular display to logarithmic mode. The dots are one octave apart. { G }',0

sz_IIR_IDC_IIR_DETAILED db  'Show or hide the detailed information about the filter response. { D }',0

sz_KNOB_ID_KNOB_SMALL   LABEL BYTE
sz_ADSR_ID_ADSR_SMALL   LABEL BYTE
sz_IIR_IDC_IIR_SMALL    db  'Hide the display and controls by making the object smaller. { Double left click or Enter }',0

;//sz_DIFFERENCE_ID_DIFF_CLIP_SHOW  LABEL BYTE
;//sz_1CP_ID_IIR_CLIPPING   LABEL BYTE
;//sz_IIR_IDC_IIR_CLIPPING  db  'Show when the object saturates by drawing a red ring around it.',0
;//sz_IIR_IDC_STATIC        db  0

sz_GROUP_IDC_STATIC_NAME        LABEL BYTE
sz_GROUP_CLOSED_IDC_STATIC_NAME db "The Group's name is displayed on the object.",0
sz_GROUP_CLOSED_ID_GROUP_NAME       LABEL BYTE
sz_GROUP_ID_GROUP_NAME              db  'Sets the 32 character name of the group.',0
sz_GROUP_CLOSED_ID_GROUP_EDIT_VIEW  db  'Edit the contents of this group. { Double left click or Enter }',0
sz_GROUP_ID_GROUP_CREATE_CLOSED     db  'Create a Closed Group using the circuitry highlighted by this Group',0
;//sz_GROUP_CLOSED_IDC_STATIC           LABEL BYTE
;//sz_GROUP_IDC_STATIC                  db  0

sz_PININT_IDC_STATIC_SHORT  db  'When part of a closed group, the short name is displayed on the pin.',0
sz_PININT_IDC_STATIC_LONG   db  'When part of a closed group, the long name is displayed on the status bar.',0
sz_PININT_IDC_STATIC_CHECK  db  'This object can also perform tests on the data flowing through it.',0

sz_PININT_ID_PININT_S_NAME      db  'Sets the two character short name of the pin',0
sz_PININT_ID_PININT_L_NAME      db  'Sets the 32 character long name that will appear on the status bar.',0
sz_PININT_ID_PININT_TEST_CHANGE db  'Makes sure that data is really changing. Useful after filters and inside feedback loops.',0
sz_PININT_ID_PININT_TEST_DATA   db  'Removes bad data (denormals and infinities). Useful inside of feedback loops.',0
;//sz_PININT_IDC_STATIC         db  0

comment ~ /*
sz_MIDIOUT_IDC_STATIC_TRIGGER   db  'The t input tells the object when to send midi events.',0
sz_MIDIOUT_IDC_STATIC_NV        db  'These commands require N and V data inputs.',0
sz_MIDIOUT_IDC_STATIC_N         db  'These commands require an N input, V is ignored.',0
sz_MIDIOUT_IDC_STATIC_T         db  'These commands only require a t trigger. N and V are ignored.',0
*/ comment ~

;// sz_MIDIOUT_IDC_STATIC_MIDI_CHANNEL  db  'Set the channel to send midi events on.',0
;//sz_MIDIOUT_IDC_STATIC                db  0

;//sz_MIDIOUT_ID_DIGITAL_POS            db  'Send event when t goes positive.',0
;//sz_MIDIOUT_ID_DIGITAL_NEG            db  'Send event when t goes negative.',0
;//sz_MIDIOUT_ID_DIGITAL_BOTH           db  'Send event when t changes sign.',0

comment ~ /*
sz_MIDIOUT_ID_MIDI_CHANNEL_1        LABEL BYTE
sz_MIDIOUT_ID_MIDI_CHANNEL_2        LABEL BYTE
sz_MIDIOUT_ID_MIDI_CHANNEL_3        LABEL BYTE
sz_MIDIOUT_ID_MIDI_CHANNEL_4        LABEL BYTE
sz_MIDIOUT_ID_MIDI_CHANNEL_5        LABEL BYTE
sz_MIDIOUT_ID_MIDI_CHANNEL_6        LABEL BYTE
sz_MIDIOUT_ID_MIDI_CHANNEL_7        LABEL BYTE
sz_MIDIOUT_ID_MIDI_CHANNEL_8        LABEL BYTE
sz_MIDIOUT_ID_MIDI_CHANNEL_9        LABEL BYTE
sz_MIDIOUT_ID_MIDI_CHANNEL_10       LABEL BYTE
sz_MIDIOUT_ID_MIDI_CHANNEL_11       LABEL BYTE
sz_MIDIOUT_ID_MIDI_CHANNEL_12       LABEL BYTE
sz_MIDIOUT_ID_MIDI_CHANNEL_13       LABEL BYTE
sz_MIDIOUT_ID_MIDI_CHANNEL_14       LABEL BYTE
sz_MIDIOUT_ID_MIDI_CHANNEL_15       LABEL BYTE
sz_MIDIOUT_ID_MIDI_CHANNEL_16       db  'Send events to this midi channel.',0

sz_MIDIOUT_ID_MIDI_STATUS_1         db  'Send Note OFF events. N=Note Number, V=Release Velocity.',0
sz_MIDIOUT_ID_MIDI_STATUS_2         db  'Send Note ON events. N=Note Number, V=Attack Velocity.',0
sz_MIDIOUT_ID_MIDI_STATUS_3         db  'Send Note Aftertouch events. N=Note Number, V=Pressure.',0
sz_MIDIOUT_ID_MIDI_STATUS_4         db  'Send Midi Controller events. N=Controller Number, V=Control Value.',0

sz_MIDIOUT_ID_MIDI_STATUS_5         db  'Send Program Change events. N=Program Number, V is ignored.',0
sz_MIDIOUT_ID_MIDI_STATUS_6         db  'Send Channel Aftertouch events. N=Pressure, V is ignored.',0
sz_MIDIOUT_ID_MIDI_STATUS_7         db  'Send Pitch Wheel events. N=Wheel position (-1 to +1), V is ignored.',0

sz_MIDIOUT_ID_MIDI_STATUS_88        db  'Send Midi Clock events (24 per quarter note). N and V are ignored.',0
sz_MIDIOUT_ID_MIDI_STATUS_8A        db  'Send Start events. N and V are ignored.',0
sz_MIDIOUT_ID_MIDI_STATUS_8B        db  'Send Continue events. N and V are ignored.',0
sz_MIDIOUT_ID_MIDI_STATUS_8C        db  'Send Stop events. N and V are ignored.',0


sz_MIDIIN_IDC_STATIC_OUT    db  'Midi Clock, Start, Stop and Continue are logic events.',0
sz_MIDIIN_IDC_STATIC_NV     db  'These commands return data on the N and V pins.',0
sz_MIDIIN_IDC_STATIC_N      db  'These commands return data only on the N pin.',0

sz_MIDIIN_ID_MIDI_ZEROSTART         db  'Clear internal buffers when play starts.',0
sz_MIDIIN_IDC_STATIC_MIDI_CHANNEL   db  'Set the channel from which to recieve data.',0

*/ comment ~

comment ~ /*
sz_MIDIIN_ID_MIDI_CHANNEL_1         LABEL BYTE
sz_MIDIIN_ID_MIDI_CHANNEL_2         LABEL BYTE
sz_MIDIIN_ID_MIDI_CHANNEL_3         LABEL BYTE
sz_MIDIIN_ID_MIDI_CHANNEL_4         LABEL BYTE
sz_MIDIIN_ID_MIDI_CHANNEL_5         LABEL BYTE
sz_MIDIIN_ID_MIDI_CHANNEL_6         LABEL BYTE
sz_MIDIIN_ID_MIDI_CHANNEL_7         LABEL BYTE
sz_MIDIIN_ID_MIDI_CHANNEL_8         LABEL BYTE
sz_MIDIIN_ID_MIDI_CHANNEL_9         LABEL BYTE
sz_MIDIIN_ID_MIDI_CHANNEL_10        LABEL BYTE
sz_MIDIIN_ID_MIDI_CHANNEL_11        LABEL BYTE
sz_MIDIIN_ID_MIDI_CHANNEL_12        LABEL BYTE
sz_MIDIIN_ID_MIDI_CHANNEL_13        LABEL BYTE
sz_MIDIIN_ID_MIDI_CHANNEL_14        LABEL BYTE
sz_MIDIIN_ID_MIDI_CHANNEL_15        LABEL BYTE
sz_MIDIIN_ID_MIDI_CHANNEL_16        db  'Recieve midi events only from this channel.',0

;//sz_MIDIIN_IDC_STATIC             db  0

sz_MIDIIN_ID_MIDI_STATUS_1      db  'Recieve only Note OFF events. N=Note Number, V=Release Velocity.',0
sz_MIDIIN_ID_MIDI_STATUS_2      db  'Recieve only Note ON events. N=Note Number, V=Attack Velocity.',0
sz_MIDIIN_ID_MIDI_STATUS_3      db  'Recieve only Note Aftertouch events. N=Note Number, V=Pressure.',0
sz_MIDIIN_ID_MIDI_STATUS_4      db  'Recieve only Midi Controller events. N=Controller Number, V=Control Value.',0

sz_MIDIIN_ID_MIDI_STATUS_5      db  'Recieve only Program Change events. N=Program Number, V is ignored.',0
sz_MIDIIN_ID_MIDI_STATUS_6      db  'Recieve only Channel Aftertouch events. N=Pressure, V is ignored.',0
sz_MIDIIN_ID_MIDI_STATUS_7      db  'Recieve only Pitch Wheel events. N=Wheel position (-1 to +1), V is ignored.',0

sz_MIDIIN_ID_MIDI_STATUS_88     db  'Recieve only Midi Clock events. N=TRUE then FALSE for each event. V is ignored.',0
sz_MIDIIN_ID_MIDI_STATUS_8A     db  'Recieve only Start events. N=TRUE then FALSE for each event. V is ignored.',0
sz_MIDIIN_ID_MIDI_STATUS_8B     db  'Recieve only Continue events. N=TRUE then FALSE for each event. V is ignored.',0
sz_MIDIIN_ID_MIDI_STATUS_8C     db  'Recieve only Stop events. N=TRUE then FALSE for each event. V is ignored.',0

*/ comment ~

;// new for abox 220

;// sz_MIDIIN2_ID_MIDIIN_INPUT_STATIC   db  'Select where you want to get midi information from.',0
sz_MIDIIN2_ID_MIDIIN_INPUT_DEVICE   db  'Input midi events from a device.',0
sz_MIDIIN2_ID_MIDIIN_INPUT_STREAM   db  'Input midi events from a stream (si).',0
sz_MIDIIN2_ID_MIDIIN_INPUT_TRACKER  db  'Input midi events from a note tracker.',0

sz_MIDIIN2_ID_MIDIIN_OUTPUT_STATIC  db  "Configure the object's output by selecting an event and filling in a list or range.",0
sz_MIDIIN2_ID_MIDIIN_PORT_STATIC    db  'These commands are common to the device or port.',0
sz_MIDIIN2_ID_MIDIIN_PORT_STREAM    db  'Output all events to the s0 pin.',0
sz_MIDIIN2_ID_MIDIIN_PORT_CLOCK     db  'Output 24 edges per quarter note to the e pin. Start/Stop status to the V pin.',0
sz_MIDIIN2_ID_MIDIIN_PORT_RESET     db  'Toggle the e pin when a midi reset is received.',0

sz_MIDIIN2_ID_MIDIIN_CHAN_STATIC    db  'These commands require a list or range of channels to work with.',0
sz_MIDIIN2_ID_MIDIIN_CHAN_EDIT      db  'A list or range of channels to work with. Press Enter to set.',0dh,0ah,'Ex: 0 3 5-14',0
sz_MIDIIN2_ID_MIDIIN_CHAN_STREAM    db  'Output all events from the selected channels',0
sz_MIDIIN2_ID_MIDIIN_CHAN_PATCH     db  'Output patch changes from the selected channels.',0
sz_MIDIIN2_ID_MIDIIN_CHAN_PRESS     db  'Output pressure level from the selected channels.',0
sz_MIDIIN2_ID_MIDIIN_CHAN_WHEEL     db  'Output pitch-wheel events from the selected channels.',0
sz_MIDIIN2_ID_MIDIIN_CHAN_CTRLR     db  'Output controller messages from the selected channels. The list specifies which controllers.',0
sz_MIDIIN2_ID_MIDIIN_CTRL_EDIT      db  'A list or range of controllers to extract. Press Enter to set.',0dh,0ah,'Ex: 2 14 56-99',0

sz_MIDIIN2_ID_MIDIIN_NOTE_STATIC    db  'These commands are specific to notes on the selected channels.',0
sz_MIDIIN2_ID_MIDIIN_NOTE_EDIT      db  'A list or range of notes to extract. Press Enter to set.',0dh,0ah,'Ex: 2 14 56-99',0
sz_MIDIIN2_ID_MIDIIN_NOTE_STREAM    db  'Output all events from the specified notes and channels.',0
sz_MIDIIN2_ID_MIDIIN_NOTE_PRESS     db  'Output pressure events from the specified notes and channels.',0
sz_MIDIIN2_ID_MIDIIN_NOTE_ON        db  'Output note on events from the specified notes and channels.',0
sz_MIDIIN2_ID_MIDIIN_NOTE_OFF       db  'Output note off events from the specified notes and channels.',0
sz_MIDIIN2_ID_MIDIIN_NOTE_TRACKER   db  'Send the specified notes to a tracker table. Use other MidiIn objects to connect to the table.',0

sz_MIDIIN2_ID_MIDIIN_NOTE_TRACKER_SAT db    'On for saturate, ignores new notes if all objects are busy. Off for overwrite oldest note.',0
sz_MIDIIN2_ID_MIDIIN_NOTE_TRACKER_FREQ db   'Makes all attached objects output frequency instead of midi note.',0

sz_MIDIIN2_ID_MIDIIN_LOWEST_LATENCY  db  "Use this for keyboard input. For sequencer input, leave off to increase stability.", 0




sz_MIDIOUT2_ID_MIDIOUT_OUTPUT_STATIC    db 'Choose whether to send commands to a stream or to a device.',0
sz_MIDIOUT2_ID_MIDIOUT_OUTPUT_STREAM    db 'Send commands to a stream.',0
sz_MIDIOUT2_ID_MIDIOUT_OUTPUT_DEVICE    db 'Send commands to a device. Choose the device from the list.',0

sz_MIDIOUT2_ID_MIDIOUT_TRIG_STATIC      db 'Sets which edge of the t input to monitor.',0
sz_MIDIOUT2_ID_MIDIOUT_TRIG_EDGE_BOTH   db 'Send commands when t changes sign.',0
sz_MIDIOUT2_ID_MIDIOUT_TRIG_EDGE_POS    db 'Send commands when t changes from negative to positive.',0
sz_MIDIOUT2_ID_MIDIOUT_TRIG_EDGE_NEG    db 'Send commands when t changes from positive to negative.',0

sz_MIDIOUT2_ID_MIDIOUT_INPUT_STATIC     db 'These options control the input mode of the object.',0

sz_MIDIOUT2_ID_MIDIOUT_PORT_STATIC      db 'These commands will be sent to all channels.',0
sz_MIDIOUT2_ID_MIDIOUT_PORT_STREAM      db 'Merge the s1 stream with the si stream.',0
sz_MIDIOUT2_ID_MIDIOUT_PORT_CLOCK       db 'Send start stop clock commands. V is start/stop, t is 24 ticks per quarter note.',0
sz_MIDIOUT2_ID_MIDIOUT_PORT_RESET       db 'Send a reset command.',0

sz_MIDIOUT2_ID_MIDIOUT_CHAN_STATIC      db 'These commands are only sent to the specified channel.',0
sz_MIDIOUT2_ID_MIDIOUT_CHAN_EDIT        db 'Enter a channel to send commands to.',0
sz_MIDIOUT2_ID_MIDIOUT_CHAN_CTRLR       db 'Select the controller to send from the list. V is the controller value.',0
sz_MIDIOUT2_ID_MIDIOUT_CHAN_CTRLR_N     db 'Send controller number N when t is triggered. V is the controller value.',0
sz_MIDIOUT2_ID_MIDIOUT_CHAN_PATCH_N     db 'Send patch number N when t is triggered.',0
sz_MIDIOUT2_ID_MIDIOUT_CHAN_PATCH       db 'Select the patch to send from the list.',0
sz_MIDIOUT2_ID_MIDIOUT_CHAN_PRESS       db 'Send channel pressure commands. V is the pressure.',0
sz_MIDIOUT2_ID_MIDIOUT_CHAN_WHEEL       db 'Send pitch wheel commands. V is the position of the wheel.',0

sz_MIDIOUT2_ID_MIDIOUT_NOTE_STATIC      db 'These send note related commands.',0
sz_MIDIOUT2_ID_MIDIOUT_NOTE_TRACK_N     db 'Track NV and send note commands. N is note number, V is note velocity.',0
sz_MIDIOUT2_ID_MIDIOUT_NOTE_TRACK_t     db 'Track tV and send note commands. N is note number, V is note velocity, t is on/off state.',0
sz_MIDIOUT2_ID_MIDIOUT_NOTE_ON          db 'Send note on. N is note number, V is note velocity.',0
sz_MIDIOUT2_ID_MIDIOUT_NOTE_OFF         db 'Send note off. N is note number, V is release velocity.',0
sz_MIDIOUT2_ID_MIDIOUT_NOTE_PRESS       db 'Send note pressure. N is note number, V is note pressure.',0

sz_MIDIOUT2_ID_MIDIOUT_SELECT_COMBO     db 'Enter a controller or patch number, or select from the list.',0


sz_PROBE_IDC_PROBE_VALUE    db  "Probe grabs signal data from it's target. { V }",0
sz_PROBE_IDC_PROBE_STATUS   db  "Probe grabs status information from it's target (changing=TRUE, not changing = FALSE). { S }",0

sz_EQUATION_ID_EQU_A        LABEL BYTE
sz_EQUATION_ID_EQU_B        LABEL BYTE
sz_EQUATION_ID_EQU_X        LABEL BYTE
sz_EQUATION_ID_EQU_Y        LABEL BYTE
sz_EQUATION_ID_EQU_Z        LABEL BYTE
sz_EQUATION_ID_EQU_W        LABEL BYTE
sz_EQUATION_ID_EQU_U        LABEL BYTE
sz_EQUATION_ID_EQU_V        db  'Insert this variable.',0

sz_EQUATION_ID_EQU_PI       db  'Insert pi. Multiply normalized angles by pi to convert them to radians.',0
sz_EQUATION_ID_EQU_L2E      db  'Insert log2(e). Use in the equation e^X = 2^(x*log2(e)).',0
sz_EQUATION_ID_EQU_LN2      db  'Insert ln(2).',0

sz_EQUATION_ID_EQU_0        LABEL BYTE
sz_EQUATION_ID_EQU_1        LABEL BYTE
sz_EQUATION_ID_EQU_2        LABEL BYTE
sz_EQUATION_ID_EQU_3        LABEL BYTE
sz_EQUATION_ID_EQU_4        LABEL BYTE
sz_EQUATION_ID_EQU_5        LABEL BYTE
sz_EQUATION_ID_EQU_6        LABEL BYTE
sz_EQUATION_ID_EQU_7        LABEL BYTE
sz_EQUATION_ID_EQU_8        LABEL BYTE
sz_EQUATION_ID_EQU_9        db  'Insert this number.',0
sz_EQUATION_ID_EQU_DECIMAL  db  'Insert a decimal point.',0

sz_EQUATION_ID_EQU_MINUS    db  'Subtract.',0
sz_EQUATION_ID_EQU_PLUS     db  'Add.',0
sz_EQUATION_ID_EQU_DIVIDE   db  "Divide. Clips if divisor is closer to zero than 'small' is.",0
sz_EQUATION_ID_EQU_MAG      db  "Magnitude. Absolute value.",0
sz_EQUATION_ID_EQU_SIN      db  "Sine. Angle assumed to be in radians.",0
sz_EQUATION_ID_EQU_COS      db  "Cosine. Angle assumed to be in radians.",0
sz_EQUATION_ID_EQU_TANH     db  "Hyperbolic Tangent.",0
sz_EQUATION_ID_EQU_POWER    db  "2.0 raised to a number.",0
sz_EQUATION_ID_EQU_SQRT     db  "Square Root. The square root of a negative number returns 0.0",0
sz_EQUATION_ID_EQU_LOG2     db  "Logarithm base 2. Clips if number is less than 'small'.",0

sz_EQUATION_IDC_STATIC_SMALL    db "The 'small' value defines a clipping limit when a divisor or logarithm is too close to zero.",0
sz_EQUATION_ID_EQU_SMALL_8  LABEL BYTE
sz_EQUATION_ID_EQU_SMALL_16 LABEL BYTE
sz_EQUATION_ID_EQU_SMALL_32 LABEL BYTE
sz_EQUATION_ID_EQU_SMALL_64 db  "Set 'small' to this value. Maximum clip value will be the reciprocal of 'small'.",0

sz_EQUATION_ID_EQU_MULTIPLY db  'Multiply.',0

sz_EQUATION_ID_EQU_DEL      db  'Delete this item.',0
sz_EQUATION_ID_EQU_LEFT     db  'Move left.',0
sz_EQUATION_ID_EQU_RIGHT    db  'Move right.',0
sz_EQUATION_ID_EQU_PAREN    db  'Insert a pair of parenthesis.',0

sz_EQUATION_ID_EQU_NEG      db  'Negate.',0

sz_EQUATION_ID_EQU_MOD          db  'Modulus. Any number % 0.0 returns 0.0.',0
sz_EQUATION_ID_EQU_ANGLE        db  'Angle in radians. Ex. X @ Y returns atan(Y/X).',0
sz_EQUATION_ID_EQU_PRESET_M2F   db  'Preset function converts a midi note to a frequency in Hertz.',0
sz_EQUATION_ID_EQU_PRESET_F2M   db  'Preset function converts a frequency in Hertz to a midi note.',0
sz_EQUATION_ID_EQU_PRESET_D2F   db  'Preset function converts a delay in samples to frequency in Hertz.',0
sz_EQUATION_ID_EQU_PRESET_F2D   db  'Preset function converts a frequency in Hertz to a delay in samples.',0
sz_EQUATION_ID_EQU_PRESET_M2D   db  'Preset function converts a midi note to a delay in samples.',0
sz_EQUATION_ID_EQU_PRESET_D2M   db  'Preset function converts a delay in samples to a midi note.',0

sz_EQUATION_ID_EQU_PRESET_RESET db  'Clear the equation and start over.',0

sz_EQUATION_ID_EQU_DISPLAY      db  'Click on the display to set the cursor position.',0

sz_EQUATION_ID_EQU_BACK     db  'Delete the previous item.',0
sz_EQUATION_ID_EQU_UP       db  'Increase the suffix on a variable. May be a differential order (U-Z), or just an index (a and b).',0
sz_EQUATION_ID_EQU_DOWN     db  'Decrease the suffix on a variable. May be a differential order (U-Z), or just an index (a and b).',0
sz_EQUATION_ID_EQU_STATUS   db  0
sz_EQUATION_ID_EQU_SIGN     db  'Returns +1 if positive, -1.0 if negative. 0.0 is positive.',0
sz_EQUATION_ID_EQU_INT      db  'Round to closest whole integer.',0
sz_EQUATION_ID_EQU_CLIP     db  'Clip operator. Ex. X#Y clips X to be within the range of -Y and +Y.',0
;//sz_EQUATION_IDC_STATIC       LABEL BYTE

sz_DIFFERENCE_IDC_STATIC_EQUATION   db  'Build an equation to approximate.',0

sz_DIFFERENCE_IDC_STATIC_STEP       db  'The s input tells the object when to iterate the system.',0
sz_DIFFERENCE_IDC_STATIC_DERIVATIVE db  'Choose a variable to work with from this column. Set the derivative order as desired.',0
sz_DIFFERENCE_IDC_STATIC_OUTPUT     db  'Select which outputs to display from these columns.',0
sz_DIFFERENCE_IDC_STATIC_EQUALX     LABEL BYTE
sz_DIFFERENCE_IDC_STATIC_EQUALY     LABEL BYTE
sz_DIFFERENCE_IDC_STATIC_EQUALZ     LABEL BYTE
sz_DIFFERENCE_IDC_STATIC_EQUALW     LABEL BYTE
sz_DIFFERENCE_IDC_STATIC_EQUALU     LABEL BYTE
sz_DIFFERENCE_IDC_STATIC_EQUAL_V    LABEL BYTE
sz_DIFFERENCE_IDC_STATIC_EQUAL      db  'The derivative to the left will drive the equation to the right.',0

sz_DIFFERENCE_IDC_STATIC_INPUT_TRIGGER  db  'The t input tells the object when to grab initial values.',0
sz_DIFFERENCE_IDC_STATIC_SATURATE       db  'The saturate values clips all of the internal variables.',0
sz_DIFFERENCE_IDC_STATIC_APPROX         db  'The approximate setting tells the object how accurate to be.',0


sz_DIFFERENCE_ID_DIFF_S_POS     db  'Iterate only when s goes positive. Disconnect s to run at full speed.',0
sz_DIFFERENCE_ID_DIFF_S_NEG     db  'Iterate only when s goes negative. Disconnect s to run at full speed.',0
sz_DIFFERENCE_ID_DIFF_S_BOTH    db  'Iterate only when s changes sign. Disconnect s to run at full speed.',0

sz_DIFFERENCE_ID_DIFF_DU        LABEL BYTE
sz_DIFFERENCE_ID_DIFF_DV        LABEL BYTE
sz_DIFFERENCE_ID_DIFF_DW        LABEL BYTE
sz_DIFFERENCE_ID_DIFF_DX        LABEL BYTE
sz_DIFFERENCE_ID_DIFF_DY        LABEL BYTE
sz_DIFFERENCE_ID_DIFF_DZ        db  'Enable this differential equation.',0

sz_DIFFERENCE_ID_DIFF_dU1       LABEL BYTE
sz_DIFFERENCE_ID_DIFF_dV1       LABEL BYTE
sz_DIFFERENCE_ID_DIFF_dW1       LABEL BYTE
sz_DIFFERENCE_ID_DIFF_dZ1       LABEL BYTE
sz_DIFFERENCE_ID_DIFF_dY1       LABEL BYTE
sz_DIFFERENCE_ID_DIFF_dX1       db  'Approximate the solution of d()/dt = . First order equation (linear)',0

sz_DIFFERENCE_ID_DIFF_dU2       LABEL BYTE
sz_DIFFERENCE_ID_DIFF_dV2       LABEL BYTE
sz_DIFFERENCE_ID_DIFF_dW2       LABEL BYTE
sz_DIFFERENCE_ID_DIFF_dZ2       LABEL BYTE
sz_DIFFERENCE_ID_DIFF_dY2       LABEL BYTE
sz_DIFFERENCE_ID_DIFF_dX2       db  'Approximate the solution of d2()/dt2 = . Second order equation',0

sz_DIFFERENCE_ID_DIFF_dU3       LABEL BYTE
sz_DIFFERENCE_ID_DIFF_dV3       LABEL BYTE
sz_DIFFERENCE_ID_DIFF_dW3       LABEL BYTE
sz_DIFFERENCE_ID_DIFF_dZ3       LABEL BYTE
sz_DIFFERENCE_ID_DIFF_dY3       LABEL BYTE
sz_DIFFERENCE_ID_DIFF_dX3       db  'Approximate the solution of d3()/dt3 = . Third order equation',0

sz_DIFFERENCE_ID_DIFF_dU4       LABEL BYTE
sz_DIFFERENCE_ID_DIFF_dV4       LABEL BYTE
sz_DIFFERENCE_ID_DIFF_dW4       LABEL BYTE
sz_DIFFERENCE_ID_DIFF_dZ4       LABEL BYTE
sz_DIFFERENCE_ID_DIFF_dY4       LABEL BYTE
sz_DIFFERENCE_ID_DIFF_dX4       db  'Approximate the solution of d4()/dt4 = . Fourth order equation.',0

sz_DIFFERENCE_ID_DIFF_dU_EQU    LABEL BYTE
sz_DIFFERENCE_ID_DIFF_dV_EQU    LABEL BYTE
sz_DIFFERENCE_ID_DIFF_dW_EQU    LABEL BYTE
sz_DIFFERENCE_ID_DIFF_dZ_EQU    LABEL BYTE
sz_DIFFERENCE_ID_DIFF_dY_EQU    LABEL BYTE
sz_DIFFERENCE_ID_DIFF_dX_EQU    db  'Press to edit the equation.',0

sz_DIFFERENCE_ID_DIFF_U0        db  'Output U',0
sz_DIFFERENCE_ID_DIFF_V0        db  'Output V',0
sz_DIFFERENCE_ID_DIFF_W0        db  'Output W',0
sz_DIFFERENCE_ID_DIFF_X0        db  'Output X',0
sz_DIFFERENCE_ID_DIFF_Y0        db  'Output Y',0
sz_DIFFERENCE_ID_DIFF_Z0        db  'Output Z',0

sz_DIFFERENCE_ID_DIFF_U1        db  'Output dU/dt',0
sz_DIFFERENCE_ID_DIFF_V1        db  'Output dV/dt',0
sz_DIFFERENCE_ID_DIFF_W1        db  'Output dW/dt',0
sz_DIFFERENCE_ID_DIFF_Z1        db  'Output dZ/dt',0
sz_DIFFERENCE_ID_DIFF_Y1        db  'Output dY/dt',0
sz_DIFFERENCE_ID_DIFF_X1        db  'Output dX/dt',0

sz_DIFFERENCE_ID_DIFF_U2        db  'Output d2U/dt2',0
sz_DIFFERENCE_ID_DIFF_V2        db  'Output d2V/dt2',0
sz_DIFFERENCE_ID_DIFF_W2        db  'Output d2W/dt2',0
sz_DIFFERENCE_ID_DIFF_Z2        db  'Output d2Z/dt2',0
sz_DIFFERENCE_ID_DIFF_Y2        db  'Output d2Y/dt2',0
sz_DIFFERENCE_ID_DIFF_X2        db  'Output d2X/dt2',0

sz_DIFFERENCE_ID_DIFF_U3        db  'Output d3U/dt3',0
sz_DIFFERENCE_ID_DIFF_V3        db  'Output d3V/dt3',0
sz_DIFFERENCE_ID_DIFF_W3        db  'Output d3W/dt3',0
sz_DIFFERENCE_ID_DIFF_Z3        db  'Output d3Z/dt3',0
sz_DIFFERENCE_ID_DIFF_Y3        db  'Output d3Y/dt3',0
sz_DIFFERENCE_ID_DIFF_X3        db  'Output d3X/dt3',0

sz_DIFFERENCE_ID_DIFF_U4        db  'Output d4U/dt4',0
sz_DIFFERENCE_ID_DIFF_V4        db  'Output d4V/dt4',0
sz_DIFFERENCE_ID_DIFF_W4        db  'Output d4W/dt4',0
sz_DIFFERENCE_ID_DIFF_Z4        db  'Output d4Z/dt4',0
sz_DIFFERENCE_ID_DIFF_Y4        db  'Output d4Y/dt4',0
sz_DIFFERENCE_ID_DIFF_X4        db  'Output d4X/dt4',0

sz_DIFFERENCE_ID_DIFF_T_POS_EDGE    db  'Initial value on t positive edge.',0
sz_DIFFERENCE_ID_DIFF_T_NEG_EDGE    db  'Initial value on t negative edge.',0
sz_DIFFERENCE_ID_DIFF_T_BOTH_EDGE   db  'Initial value on either t edge.',0
sz_DIFFERENCE_ID_DIFF_T_POS_GATE    db  'Initial value when t is positive.',0
sz_DIFFERENCE_ID_DIFF_T_NEG_GATE    db  'Initial value when t is negative.',0

sz_DIFFERENCE_ID_DIFF_DIS_X     db  'Show initial values for X',0
sz_DIFFERENCE_ID_DIFF_DIS_Y     db  'Show initial values for Y',0
sz_DIFFERENCE_ID_DIFF_DIS_Z     db  'Show initial values for Z',0
sz_DIFFERENCE_ID_DIFF_DIS_W     db  'Show initial values for W',0
sz_DIFFERENCE_ID_DIFF_DIS_U     db  'Show initial values for U',0
sz_DIFFERENCE_ID_DIFF_DIS_V     db  'Show initial values for V',0

sz_DIFFERENCE_ID_DIFF_t0        db  'Enable the initial value for variable.',0
sz_DIFFERENCE_ID_DIFF_t0_E      db  'Initial value by replacing variable with value.',0
sz_DIFFERENCE_ID_DIFF_t0_PE     db  'Initial value by adding variable with value.',0
sz_DIFFERENCE_ID_DIFF_t0_ME     db  'Initial value by multiplying variable with value.',0

sz_DIFFERENCE_ID_DIFF_t1        db  'Enable the initial value for first derivative.',0
sz_DIFFERENCE_ID_DIFF_t1_E      db  'Initial value by replacing first derivative with value.',0
sz_DIFFERENCE_ID_DIFF_t1_PE     db  'Initial value by adding first derivative with value.',0
sz_DIFFERENCE_ID_DIFF_t1_ME     db  'Initial value by multiplying first derivative with value.',0

sz_DIFFERENCE_ID_DIFF_t2        db  'Enable the initial value for second derivative.',0
sz_DIFFERENCE_ID_DIFF_t2_E      db  'Initial value by replacing second derivative with value.',0
sz_DIFFERENCE_ID_DIFF_t2_PE     db  'Initial value by adding second derivative with value.',0
sz_DIFFERENCE_ID_DIFF_t2_ME     db  'Initial value by multiplying second derivative with value.',0

sz_DIFFERENCE_ID_DIFF_t3        db  'Enable the initial value for third derivative.',0
sz_DIFFERENCE_ID_DIFF_t3_E      db  'Initial value by replacing third derivative with value.',0
sz_DIFFERENCE_ID_DIFF_t3_PE     db  'Initial value by adding third derivative with value.',0
sz_DIFFERENCE_ID_DIFF_t3_ME     db  'Initial value by multiplying third derivative with value.',0

sz_DIFFERENCE_ID_DIFF_CLIP_2    LABEL BYTE
sz_DIFFERENCE_ID_DIFF_CLIP_8    db  'Saturate any derivative or variable greater than this number.',0


sz_DIFFERENCE_ID_DIFF_APPROX_LIN    db  'Approximate using linear interpolation. Fast but less accurate.',0
sz_DIFFERENCE_ID_DIFF_APPROX_RK     db  'Approximate using Runge-Kutta interpolation. Slow but more accurate.',0

sz_FFT_IDC_FFT_FORWARD      db  'Perform the Forward Transform. Time to Frequency. { F }',0
sz_FFT_IDC_FFT_REVERSE      db  'Perform the Reverse Transform. Frequency to Time. { R }',0
sz_FFT_IDC_FFT_WINDOW       db  'Apply Blackman window. { W }',0

sz_FFTOP_IDC_STATIC_TRANSFORM   db  'These operations transform a spectrum.',0
sz_FFTOP_IDC_STATIC_INSERT      db  'These operations insert new data into a spectrum.',0
sz_FFTOP_IDC_STATIC_COMPLEX     db  'These operations perform complex arithmetic on each bin in the spectrum.',0
sz_FFTOP_IDC_STATIC_EXTRACT     db  'These operations retrieve a single value from the spectrum.',0

sz_FFTOP_IDC_FFTOP_SHIFT    db  'Shift the input spectrum by the value at the b pin. Positive shifts up in frequency.',0
sz_FFTOP_IDC_FFTOP_SCALE    db  'Expand or Shrink the input spectrum by the value at the a pin. Positive a expands, negative a shrinks.',0
sz_FFTOP_IDC_FFTOP_CULL     db  'Zero frequency bins that are of lesser power than their immediate neighbors.',0

sz_FFTOP_IDC_FFTOP_MAG2     db  'Return the magnitude squared of each bin. 512 pairs of (mag2,0)',0
sz_FFTOP_IDC_FFTOP_CONJ     db  'Returns the complex conjugate of the input spectrum.',0

sz_FFTOP_IDC_FFTOP_SORT     db  'Returns a sorted array of the n largest frequencies. n pairs of (bin number,magnitude). Output is not a spectrum.',0

sz_FFTOP_IDC_FFTOP_REPLACE  db  'Replaces the bins indexed by n, with their counterparts from r and i.',0
sz_FFTOP_IDC_FFTOP_INJECT   db  'Adds the bins indexed by n, with their counterparts from r and i.',0

sz_FFTOP_IDC_FFTOP_MUL      db  'Combines each bin of X and Y using complex multiplication.',0
sz_FFTOP_IDC_FFTOP_DIV      db  'Combines each bin of X and Y using complex division.',0

sz_FFTOP_IDC_FFTOP_POWER    db  'Extracts the power of the bin indexed by n. Returns one value.',0
sz_FFTOP_IDC_FFTOP_REAL     db  'Extracts the real part of the bin indexed by n. Returns one value.',0
sz_FFTOP_IDC_FFTOP_IMAG     db  'Extracts the imaginary part of the bin indexed by n. Returns one value.',0

;// sz_FFTOP_IDC_STATIC         db  0


sz_SLIDER_IDC_STATIC_LAYOUT db  'The slider may be set as vertical or horizontal. { V H }',0
sz_SLIDER_IDC_STATIC_RANGE  db  'The start and stop values may be set three ways. { 0 - = }',0

sz_SLIDER_ID_SLIDER_HORIZONTAL  db  'Set orientation as left to right. { H }',0
sz_SLIDER_ID_SLIDER_VERTICAL    db  'Set orientation as bottom to top. { V }',0

sz_SLIDER_ID_SLIDER_RANGE0      db  'Set the range as 0.0 to 1.0 { 0 }',0
sz_SLIDER_ID_SLIDER_RANGE1      db  'Set the range as -1.0 to +1.0 { - }',0
sz_SLIDER_ID_SLIDER_RANGE2      db  'Set the range as +1.0 to -1.0 { = }',0
;//sz_SLIDER_IDC_STATIC         db  0

sz_SLIDER_IDC_STATIC_PRESET db  'Preset values. { NumPad 0 1 - }',0




sz_COLORS_IDC_COLOR_LIST    db  'Select a color or group of colors to adjust',0

sz_COLORS_IDC_SCROLL_H      LABEL BYTE
sz_COLORS_IDC_SCROLL_S      LABEL BYTE
sz_COLORS_IDC_SCROLL_V      db  0

sz_COLORS_IDC_EXAMPLE       db  'Example color or palette',0

sz_COLORS_IDC_PRESET_0      db  'Revert to the default color set.',0
sz_COLORS_IDC_PRESET_1      LABEL BYTE
sz_COLORS_IDC_PRESET_2      LABEL BYTE
sz_COLORS_IDC_PRESET_3      LABEL BYTE
sz_COLORS_IDC_PRESET_4      db  'Use this preset.',0

sz_COLORS_IDC_PRESET_SET    db  'Press this to save the current color set to one of the presets.'

sz_COLORS_IDC_STATIC        db  0

sz_LABEL_IDC_LABEL_KEEP_GROUP   db 'Keep this label inside the closed group. Otherwise it will be removed to save space.',0
;//sz_LABEL_IDC_LABEL_TRANSPARENT   db 'Disable moving of the object and move the screen instead, as if the label were transparent.',0


sz_ALIGN_IDC_ALIGN_MODE_1A  db  'Align objects so their middles are equal. { NumPad 1 }',0
sz_ALIGN_IDC_ALIGN_MODE_2A  db  'Align objects so their bottoms are equal. { NumPad 2 }',0
sz_ALIGN_IDC_ALIGN_MODE_3A  db  'Mirror objects top to bottom. { NumPad 3 }',0
sz_ALIGN_IDC_ALIGN_MODE_4A  db  'Align objects so their left sides are equal. { NumPad 4 }',0
sz_ALIGN_IDC_ALIGN_MODE_6A  db  'Align objects so their right sides are equal. { NumPad 6 }',0
sz_ALIGN_IDC_ALIGN_MODE_7A  db  'Align objects so their centers are equal. { NumPad 7 }',0
sz_ALIGN_IDC_ALIGN_MODE_8A  db  'Align objects so their tops are equal. { NumPad 8 }',0
sz_ALIGN_IDC_ALIGN_MODE_9A  db  'Mirror objects left to right. { NumPad 9 }',0

sz_ALIGN_IDC_ALIGN_MODE_1B  db  'Equally space objects up and down towards the middle. { NumPad 1 }',0
sz_ALIGN_IDC_ALIGN_MODE_2B  db  'Equally space objects towards the bottom. { NumPad 2 }',0
sz_ALIGN_IDC_ALIGN_MODE_3B  db  'Expand objects up and down away from the middle. { NumPad 3 }',0
sz_ALIGN_IDC_ALIGN_MODE_4B  db  'Equally space objects towards the left. { NumPad 4 }',0
sz_ALIGN_IDC_ALIGN_MODE_6B  db  'Equally space objects towards the right. { NumPad 6 }',0
sz_ALIGN_IDC_ALIGN_MODE_7B  db  'Equally space objects left and right towards the center. { NumPad 7 }',0
sz_ALIGN_IDC_ALIGN_MODE_8B  db  'Equally space objects towards the top. { NumPad 8 }',0
sz_ALIGN_IDC_ALIGN_MODE_9B  db  'Expand objects left and right away from the center. { NumPad 9 }',0

sz_ALIGN_IDC_ALIGN_MODE_5B  LABEL BYTE
sz_ALIGN_IDC_ALIGN_MODE_5A  db  'Move keyboard focus to the other panel. { NumPad 5 }',0

sz_ALIGN_IDC_STATIC_1   db  'These commands move objects to an edge of the selection boundary.',0
sz_ALIGN_IDC_STATIC_2   db  'These commands space objects within the selection boundary.',0


;// the plugin builds it's own panel, so we specify externdef here

EXTERNDEF sz_IDC_PLUGIN_IDC_PLUGIN_REGISTER:BYTE
EXTERNDEF sz_IDC_PLUGIN_IDC_PLUGIN_LIST:BYTE
EXTERNDEF sz_IDC_PLUGIN_IDC_PLUGIN_REMOVE:BYTE

sz_IDC_PLUGIN_IDC_PLUGIN_REGISTER   db  'Tells ABox where to find plugins. Navigate to the directory and select as many as desired.',0
sz_IDC_PLUGIN_IDC_PLUGIN_LIST       db  'Double left click to select a plugin to use.',0
sz_IDC_PLUGIN_IDC_PLUGIN_REMOVE     db  "Remove the selected plugin from ABox's list.",0


;// these strings are not required

sz_BUS_IDC_BUS_SHOWBUSSES   LABEL BYTE
sz_BUS_IDC_BUS_SHOWNAMES    LABEL BYTE
sz_BUS_IDC_BUS_STATUS       LABEL BYTE
sz_BUS_IDC_BUS_UNCONNECT    LABEL BYTE
sz_BUS_IDC_BUS_DIRECT       LABEL BYTE
sz_BUS_IDC_BUS_PULL         LABEL BYTE
sz_BUS_IDC_BUS_GRID         LABEL BYTE
sz_BUS_IDC_BUS_CATEGORY_STATIC  LABEL BYTE
sz_BUS_IDC_BUS_MEMBER_STATIC    LABEL BYTE
sz_BUS_IDC_BUS_CAT          LABEL BYTE
sz_BUS_IDC_BUS_MEM          LABEL BYTE
sz_BUS_IDC_BUS_ADD_CAT      LABEL BYTE
sz_BUS_IDC_BUS_DEL_CAT      LABEL BYTE
sz_BUS_IDC_BUS_SORT_NUMBER  LABEL BYTE
sz_BUS_IDC_BUS_SORT_NAME    LABEL BYTE
sz_BUS_IDC_BUS_EDITOR       LABEL BYTE
sz_BUS_IDC_BUS_UNDO         LABEL BYTE
sz_BUS_IDC_BUS_REDO         LABEL BYTE

sz_ABOUT_IDC_ANALOGBOX  LABEL BYTE
sz_ABOUT_IDC_VERSION    LABEL BYTE
sz_ABOUT_IDC_STATIC     LABEL BYTE
sz_ABOUT_IDC_DEVICES    LABEL BYTE
sz_ABOUT_IDC_COPYRIGHT  LABEL BYTE
sz_ABOUT_IDC_STATUS     LABEL BYTE
sz_ABOUT_IDC_TRADEMARKS LABEL BYTE
sz_ABOUT_IDC_LOAD_STATUS    LABEL BYTE




popup_help_last db 0


END