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
;//    objectlist.inc
;//    defines in, no particular order, the baseB list for all objects

    baseB_HEAD textequ <osc_Readout>

;// objects\displays\Abox_Readout.asm
    EXTERNDEF osc_Readout:OSC_BASE
    EXTERNDEF popup_READOUT:POPUP_HEADER
    NEXT_Readout textequ <osc_IIR>

;// objects\processors\Abox_IIR.asm
    EXTERNDEF osc_IIR:OSC_BASE
    EXTERNDEF popup_IIR:POPUP_HEADER
    NEXT_IIR textequ <osc_Delta>

;// objects\processors\ABox_Delta.asm
    EXTERNDEF osc_Delta:OSC_BASE
    EXTERNDEF popup_DELTA:POPUP_HEADER
    NEXT_Delta textequ <osc_MidiOut2>

;// objects\midi\midiout2.asm
    EXTERNDEF osc_MidiOut2:OSC_BASE
    EXTERNDEF popup_MIDIOUT2:POPUP_HEADER
    NEXT_MidiOut2 textequ <osc_Delay>

;// objects\processors\Abox_Delay.asm
    EXTERNDEF osc_Delay:OSC_BASE
    EXTERNDEF popup_DELAY:POPUP_HEADER
    NEXT_Delay textequ <osc_Math>

;// objects\processors\ABox_OscMath.asm
    EXTERNDEF osc_Math:OSC_BASE
    EXTERNDEF popup_MATH:POPUP_HEADER
    NEXT_Math textequ <osc_Oscillator>

;// objects\generaters\ABox_Oscillators.asm
    EXTERNDEF osc_Oscillator:OSC_BASE
    EXTERNDEF popup_OSCILLATOR:POPUP_HEADER
    NEXT_Oscillator textequ <osc_Mixer>

;// objects\routers\ABox_Mixer.asm
    EXTERNDEF osc_Mixer:OSC_BASE
    EXTERNDEF popup_MIXER:POPUP_HEADER
    NEXT_Mixer textequ <osc_Label>

;// objects\displays\ABox_Label.asm
    EXTERNDEF osc_Label:OSC_BASE
    EXTERNDEF popup_LABEL:POPUP_HEADER
    NEXT_Label textequ <osc_Clock>

;// objects\devices\Abox_Clock.asm
    EXTERNDEF osc_Clock:OSC_BASE
    EXTERNDEF popup_CLOCK:POPUP_HEADER
    NEXT_Clock textequ <osc_Knob>

;// objects\controls\ABox_Knob.asm
    EXTERNDEF osc_Knob:OSC_BASE
    EXTERNDEF popup_KNOB:POPUP_HEADER
    NEXT_Knob textequ <osc_MidiIn2>

;// objects\midi\midiin2.asm
    EXTERNDEF osc_MidiIn2:OSC_BASE
    EXTERNDEF popup_MIDIIN2:POPUP_HEADER
    NEXT_MidiIn2 textequ <osc_ADSR>

;// objects\generaters\ABox_ADSR.asm
    EXTERNDEF osc_ADSR:OSC_BASE
    EXTERNDEF popup_ADSR:POPUP_HEADER
    NEXT_ADSR textequ <osc_Rand>

;// objects\generaters\ABox_Rand.asm
    EXTERNDEF osc_Rand:OSC_BASE
    EXTERNDEF popup_RAND:POPUP_HEADER
    NEXT_Rand textequ <opened_Group>

;// objects\opened_group.asm
    EXTERNDEF opened_Group:OSC_BASE
    EXTERNDEF popup_GROUP:POPUP_HEADER
    NEXT_opened_Group textequ <osc_Difference>

;// objects\generaters\Abox_Difference.asm
    EXTERNDEF osc_Difference:OSC_BASE
    EXTERNDEF popup_DIFFERENCE:POPUP_HEADER
    NEXT_Difference textequ <osc_WaveOut>

;// objects\devices\ABox_WaveOut.asm
    EXTERNDEF osc_WaveOut:OSC_BASE
    EXTERNDEF popup_WAVEOUT:POPUP_HEADER
    NEXT_WaveOut textequ <osc_MPlex>

;// objects\routers\ABox_Mplex.asm
    EXTERNDEF osc_MPlex:OSC_BASE
    EXTERNDEF popup_MPLEX:POPUP_HEADER
    NEXT_MPlex textequ <osc_1cP>

;// objects\processors\Abox_1cP.asm
    EXTERNDEF osc_1cP:OSC_BASE
    EXTERNDEF popup_1CP:POPUP_HEADER
    NEXT_1cP textequ <osc_File>

;// objects\file\ABox_OscFile.asm
    EXTERNDEF osc_File:OSC_BASE
    EXTERNDEF popup_FILE:POPUP_HEADER
    NEXT_File textequ <osc_Equation>

;// objects\processors\Abox_Equation.asm
    EXTERNDEF osc_Equation:OSC_BASE
    EXTERNDEF popup_EQUATION:POPUP_HEADER
    NEXT_Equation textequ <osc_Slider>

;// objects\controls\Abox_Slider.asm
    EXTERNDEF osc_Slider:OSC_BASE
    EXTERNDEF popup_SLIDER:POPUP_HEADER
    NEXT_Slider textequ <osc_Plugin>

;// objects\devices\Abox_Plugin.asm
    EXTERNDEF osc_Plugin:OSC_BASE
    EXTERNDEF popup_PLUGIN:POPUP_HEADER
    NEXT_Plugin textequ <osc_SamHold>

;// objects\routers\ABox_SamHold.asm
    EXTERNDEF osc_SamHold:OSC_BASE
    EXTERNDEF popup_SAMHOLD:POPUP_HEADER
    NEXT_SamHold textequ <osc_PinInterface>

;// objects\Abox_PinInterface.asm
    EXTERNDEF osc_PinInterface:OSC_BASE
    EXTERNDEF popup_PININT:POPUP_HEADER
    NEXT_PinInterface textequ <osc_WaveIn>

;// objects\devices\ABox_WaveIn.asm
    EXTERNDEF osc_WaveIn:OSC_BASE
    EXTERNDEF popup_WAVEIN:POPUP_HEADER
    NEXT_WaveIn textequ <osc_HID>

;// objects\devices\ABox_HID.asm
    EXTERNDEF osc_HID:OSC_BASE
    EXTERNDEF popup_HID:POPUP_HEADER
    NEXT_HID textequ <osc_Probe>

;// objects\routers\Abox_Probe.asm
    EXTERNDEF osc_Probe:OSC_BASE
    EXTERNDEF popup_PROBE:POPUP_HEADER
    NEXT_Probe textequ <osc_Divider>

;// objects\processors\ABox_Divider.asm
    EXTERNDEF osc_Divider:OSC_BASE
    EXTERNDEF popup_DIVIDER:POPUP_HEADER
    NEXT_Divider textequ <osc_Damper>

;// objects\processors\Abox_Damper.asm
    EXTERNDEF osc_Damper:OSC_BASE
    EXTERNDEF popup_DAMPER:POPUP_HEADER
    NEXT_Damper textequ <osc_Scope>

;// objects\displays\ABox_Scope.asm
    EXTERNDEF osc_Scope:OSC_BASE
    EXTERNDEF popup_SCOPE:POPUP_HEADER
    NEXT_Scope textequ <osc_FFT>

;// objects\processors\Abox_FFT.asm
    EXTERNDEF osc_FFT:OSC_BASE
    EXTERNDEF popup_FFT:POPUP_HEADER
    NEXT_FFT textequ <osc_FFTOP>

;// objects\processors\Abox_FFTOP.asm
    EXTERNDEF osc_FFTOP:OSC_BASE
    EXTERNDEF popup_FFTOP:POPUP_HEADER
    NEXT_FFTOP textequ <osc_QKey>

;// objects\processors\ABox_QKey.asm
    EXTERNDEF osc_QKey:OSC_BASE
    EXTERNDEF popup_QKEY:POPUP_HEADER
    NEXT_QKey textequ <osc_DPlex>

;// objects\routers\ABox_Dplex.asm
    EXTERNDEF osc_DPlex:OSC_BASE
    EXTERNDEF popup_DPLEX:POPUP_HEADER
    NEXT_DPlex textequ <osc_Button>

;// objects\controls\ABox_Button.asm
    EXTERNDEF osc_Button:OSC_BASE
    EXTERNDEF popup_BUTTON:POPUP_HEADER
    NEXT_Button textequ <0>

