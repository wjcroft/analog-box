ECHO OFF
cls
REM ##########################################################################
REM 
REM    This file is part of the Analog Box open source project.
REM    Copyright 1999-2011 Andy J Turner
REM 
REM    	This program is free software: you can redistribute it and/or modify
REM    	it under the terms of the GNU General Public License as published by
REM    	the Free Software Foundation, either version 3 of the License, or
REM    	(at your option) any later version.
REM 
REM    	This program is distributed in the hope that it will be useful,
REM    	but WITHOUT ANY WARRANTY; without even the implied warranty of
REM    	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
REM    	GNU General Public License for more details.
REM 
REM    	You should have received a copy of the GNU General Public License
REM    	along with this program.  If not, see <http://www.gnu.org/licenses/>.
REM 
REM ##########################################################################
mkdir temp
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\containers.obj" "VR\containers.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox.obj" "source\ABox.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\abox_align.obj" "source\abox_align.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox_circuit.obj" "source\ABox_circuit.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\abox_context.obj" "source\abox_context.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox_File.obj" "source\ABox_File.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox_Hardware.obj" "source\ABox_Hardware.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox_Math.obj" "source\ABox_Math.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox_Osc.obj" "source\ABox_Osc.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox_Play.obj" "source\ABox_Play.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\auto_unit.obj" "source\auto_unit.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\filenames.obj" "source\filenames.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\locktable.obj" "source\locktable.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\misc.obj" "source\misc.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\object_bitmap.obj" "source\object_bitmap.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\pin_connect.obj" "source\pin_connect.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\pin_layout.obj" "source\pin_layout.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\popup_data.obj" "source\popup_data.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\popup_help.obj" "source\popup_help.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\popup_strings.obj" "source\popup_strings.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\registry.obj" "source\registry.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\unredo.obj" "source\unredo.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\xlate.obj" "source\xlate.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox_PinInterface.obj" "source\OBJECTS\ABox_PinInterface.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\closed_Group.obj" "source\OBJECTS\closed_Group.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\equation.obj" "source\OBJECTS\equation.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\fft_abox.obj" "source\OBJECTS\fft_abox.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\opened_Group.obj" "source\OBJECTS\opened_Group.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\midi_filter.obj" "source\OBJECTS\midi\midi_filter.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\midi_strings.obj" "source\OBJECTS\midi\midi_strings.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\midiin_que.obj" "source\OBJECTS\midi\midiin_que.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\midiin2.obj" "source\OBJECTS\midi\midiin2.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\midiout_device.obj" "source\OBJECTS\midi\midiout_device.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\midiout2.obj" "source\OBJECTS\midi\midiout2.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\midistream_insert.obj" "source\OBJECTS\midi\midistream_insert.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\range_parser.obj" "source\OBJECTS\midi\range_parser.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\tracker.obj" "source\OBJECTS\midi\tracker.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox_Clock.obj" "source\OBJECTS\Devices\ABox_Clock.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox_HID.obj" "source\OBJECTS\Devices\ABox_HID.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox_Plugin.obj" "source\OBJECTS\Devices\ABox_Plugin.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox_Plugin_Editor.obj" "source\OBJECTS\Devices\ABox_Plugin_Editor.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox_WaveIn.obj" "source\OBJECTS\Devices\ABox_WaveIn.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox_WaveOut.obj" "source\OBJECTS\Devices\ABox_WaveOut.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox_1cP.obj" "source\OBJECTS\Processors\ABox_1cP.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox_Damper.obj" "source\OBJECTS\Processors\ABox_Damper.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox_Delay.obj" "source\OBJECTS\Processors\ABox_Delay.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox_Delta.obj" "source\OBJECTS\Processors\ABox_Delta.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox_Divider.obj" "source\OBJECTS\Processors\ABox_Divider.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox_Equation.obj" "source\OBJECTS\Processors\ABox_Equation.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox_FFT.obj" "source\OBJECTS\Processors\ABox_FFT.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox_FFTOP.obj" "source\OBJECTS\Processors\ABox_FFTOP.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox_IIR.obj" "source\OBJECTS\Processors\ABox_IIR.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox_OscMath.obj" "source\OBJECTS\Processors\ABox_OscMath.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox_QKey.obj" "source\OBJECTS\Processors\ABox_QKey.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox_Dplex.obj" "source\OBJECTS\Routers\ABox_Dplex.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox_Mixer.obj" "source\OBJECTS\Routers\ABox_Mixer.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox_Mplex.obj" "source\OBJECTS\Routers\ABox_Mplex.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox_Probe.obj" "source\OBJECTS\Routers\ABox_Probe.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox_SamHold.obj" "source\OBJECTS\Routers\ABox_SamHold.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox_ADSR.obj" "source\OBJECTS\Generators\ABox_ADSR.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox_Difference.obj" "source\OBJECTS\Generators\ABox_Difference.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox_Oscillators.obj" "source\OBJECTS\Generators\ABox_Oscillators.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox_Rand.obj" "source\OBJECTS\Generators\ABox_Rand.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox_Button.obj" "source\OBJECTS\Controls\ABox_Button.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox_Knob.obj" "source\OBJECTS\Controls\ABox_Knob.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox_Slider.obj" "source\OBJECTS\Controls\ABox_Slider.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\knob_parser.obj" "source\OBJECTS\Controls\knob_parser\knob_parser.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox_Label.obj" "source\OBJECTS\Displays\ABox_Label.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox_Readout.obj" "source\OBJECTS\Displays\ABox_Readout.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox_Scope.obj" "source\OBJECTS\Displays\ABox_Scope.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\ABox_OscFile.obj" "source\OBJECTS\File\ABox_OscFile.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\csv_reader.obj" "source\OBJECTS\File\csv_reader.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\csv_writer.obj" "source\OBJECTS\File\csv_writer.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\data_file.obj" "source\OBJECTS\File\data_file.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\file_calc.obj" "source\OBJECTS\File\file_calc.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\file_hardware.obj" "source\OBJECTS\File\file_hardware.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\media_reader.obj" "source\OBJECTS\File\media_reader.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\media_writer.obj" "source\OBJECTS\File\media_writer.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\memory_buffer.obj" "source\OBJECTS\File\memory_buffer.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\hwnd_About.obj" "source\HWND\hwnd_About.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\hwnd_colors.obj" "source\HWND\hwnd_colors.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\hwnd_Create.obj" "source\HWND\hwnd_Create.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\hwnd_debug.obj" "source\HWND\hwnd_debug.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\hwnd_equation.obj" "source\HWND\hwnd_equation.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\hwnd_main.obj" "source\HWND\hwnd_main.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\hwnd_mainmenu.obj" "source\HWND\hwnd_mainmenu.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\hwnd_mouse.obj" "source\HWND\hwnd_mouse.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\hwnd_popup.obj" "source\HWND\hwnd_popup.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\hwnd_Status.obj" "source\HWND\hwnd_Status.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\Bus.obj" "source\BUS\Bus.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\bus_catmem.obj" "source\BUS\bus_catmem.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\bus_edit.obj" "source\BUS\bus_edit.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\bus_grid.obj" "source\BUS\bus_grid.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\gdi_clocks.obj" "source\GDI\gdi_clocks.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\gdi_Colors.obj" "source\GDI\gdi_Colors.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\gdi_DIB.obj" "source\GDI\gdi_DIB.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\gdi_display.obj" "source\GDI\gdi_display.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\gdi_font.obj" "source\GDI\gdi_font.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\gdi_invalidate.obj" "source\GDI\gdi_invalidate.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\gdi_resource.obj" "source\GDI\gdi_resource.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\gdi_Shapes.obj" "source\GDI\gdi_Shapes.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\gdi_Triangles.obj" "source\GDI\gdi_Triangles.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\strings.obj" "source\GDI\strings.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\float_to_sz.obj" "system\float_to_sz.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\HIDObject.obj" "system\HIDObject.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\HIDUsage.obj" "system\HIDUsage.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\IEnum2.obj" "system\IEnum2.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\memory3.obj" "system\memory3.asm"
c:\masm32\bin\ml.exe /c /Cp /Cx /coff /DALLOC2 /Gz /nologo /X /DRELEASEBUILD /Iinclude /Isystem /Ivr /Fo"temp\sz_to_float.obj" "system\sz_to_float.asm"
cd temp
c:\masm32\bin\link.exe /FIXED /INCREMENTAL:NO /MACHINE:IX86 /nologo /SUBSYSTEM:WINDOWS /LIBPATH:c:\masm32\lib /MAP:ABox242.map /OUT:"..\ABox242.exe" ..\resources\abox.res containers.obj ABox.obj abox_align.obj ABox_circuit.obj abox_context.obj ABox_File.obj ABox_Hardware.obj ABox_Math.obj ABox_Osc.obj ABox_Play.obj auto_unit.obj filenames.obj locktable.obj misc.obj object_bitmap.obj pin_connect.obj pin_layout.obj popup_data.obj popup_help.obj popup_strings.obj registry.obj unredo.obj xlate.obj ABox_PinInterface.obj closed_Group.obj equation.obj fft_abox.obj opened_Group.obj midi_filter.obj midi_strings.obj midiin_que.obj midiin2.obj midiout_device.obj midiout2.obj midistream_insert.obj range_parser.obj tracker.obj ABox_Clock.obj ABox_HID.obj ABox_Plugin.obj ABox_Plugin_Editor.obj ABox_WaveIn.obj ABox_WaveOut.obj ABox_1cP.obj ABox_Damper.obj ABox_Delay.obj ABox_Delta.obj ABox_Divider.obj ABox_Equation.obj ABox_FFT.obj ABox_FFTOP.obj ABox_IIR.obj ABox_OscMath.obj ABox_QKey.obj ABox_Dplex.obj ABox_Mixer.obj ABox_Mplex.obj ABox_Probe.obj ABox_SamHold.obj ABox_ADSR.obj ABox_Difference.obj ABox_Oscillators.obj ABox_Rand.obj ABox_Button.obj ABox_Knob.obj ABox_Slider.obj knob_parser.obj ABox_Label.obj ABox_Readout.obj ABox_Scope.obj ABox_OscFile.obj csv_reader.obj csv_writer.obj data_file.obj file_calc.obj file_hardware.obj media_reader.obj media_writer.obj memory_buffer.obj hwnd_About.obj hwnd_colors.obj hwnd_Create.obj hwnd_debug.obj hwnd_equation.obj hwnd_main.obj hwnd_mainmenu.obj hwnd_mouse.obj hwnd_popup.obj hwnd_Status.obj Bus.obj bus_catmem.obj bus_edit.obj bus_grid.obj gdi_clocks.obj gdi_Colors.obj gdi_DIB.obj gdi_display.obj gdi_font.obj gdi_invalidate.obj gdi_resource.obj gdi_Shapes.obj gdi_Triangles.obj strings.obj float_to_sz.obj HIDObject.obj HIDUsage.obj IEnum2.obj memory3.obj sz_to_float.obj
cd ..
del /Q temp\*.*
rmdir temp