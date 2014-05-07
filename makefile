#   This file is part of the Analog Box open source project.
#   Copyright 1999-2011 Andy J Turner
#
#   	This program is free software: you can redistribute it and/or modify
#   	it under the terms of the GNU General Public License as published by
#   	the Free Software Foundation, either version 3 of the License, or
#   	(at your option) any later version.
#
#   	This program is distributed in the hope that it will be useful,
#   	but WITHOUT ANY WARRANTY; without even the implied warranty of
#   	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   	GNU General Public License for more details.
#
#   	You should have received a copy of the GNU General Public License
#   	along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#############################################################################
#
#   Authors:	AJT Andy J Turner
#
#   History:
#
#   	2.41 Mar 04, 2011 AJT
#   		Initial port to GPLv3
#
#		ABOX242 AJT
#           changed project name to 242
#			added /Y to recursive nmake invocation (needed for nmake version >=1.62)
# 			added /Gz in ml.exe cmd to set default lang type for function calls with no arguments (ml 6.14 didn't care)
#           re-cast to work with trimmed down version of the source code
#
#############################################################################
#
# nmake file for ABox2
#
# note: .inc files are not included in the tree ...
#       if you change one, best to do a clean build.

.SILENT:

ProjName=ABox242

#############################################################################
#############################################################################
##
## configure for either debug, release or recursion

!IF !DEFINED(CFG)   #not recursed

AS=ERROR
LK=ERROR

!ELSE   # are recursed, define the tools

!IF "$(CFG)" == "DEBUG"

!MESSAGE Using debug configuration

OutDir=debug

AS=ml.exe /Gz /c /Cp /Cx /coff /DALLOC2 /DDEBUGBUILD\
    /Sn /nologo /Iinclude /Isystem /Ivr\
    /Fl$(OutDir)\$(@B).lst /Fo$@

LK=link.exe /nologo /subsystem:windows /incremental:no \
    /machine:I386 /FIXED\
    /map:"$(OutDir)/$(ProjName).map"\
    /out:"$(ProjName).exe"

!ELSEIF "$(CFG)" == "RELEASE"

!MESSAGE Using release configuration

OutDir=release

AS = ml.exe /Gz /c /Cp /coff /DALLOC2 /nologo\
    /Iinclude /Isystem /Ivr /Fo$@

LK = link.exe /nologo /subsystem:windows /incremental:no\
    /machine:I386 /FIXED /RELEASE /MAP\
    /map:"$(OutDir)/$(ProjName).map"\
    /out:"$(ProjName).exe"

!ELSE   # unknown option
!ERROR unknown option
!ENDIF  # which option was hit
!ENDIF  # CFG is defined

## configure for either debug, release or recursion
##
#############################################################################
#############################################################################

needacfg :
 @ECHO Need a build target, one or more of the following:
 @ECHO "NMAKE < releasebuild | debugbuild | clean  >"
 @ECHO releasebuild creates a distributable version in the 'release' directory.
 @ECHO debugbuild   creates a version for testing in the 'debug' directory.
 @ECHO clean        erases release, debug directories

debugbuild :
    -@mkdir debug
    nmake /NOLOGO /Y CFG=DEBUG all

releasebuild :
    -@mkdir release
    nmake /NOLOGO /Y CFG=RELEASE all
    -@erase release\*.obj

clean:
  	-@erase debug\*.*
  	-@erase release\*.*

#don't target this directly, the CFG needs to be set first
all : $(ProjName).exe




#############################################################################
#############################################################################
##
## description blocks -- organized by tool needed


# uses <your build tools directory>\ML.EXE  (assembler)
$(OutDir)\memory3.obj : system\memory3.asm
    $(AS) $?
$(OutDir)\float_to_sz.obj : system\float_to_sz.asm
    $(AS) $?
$(OutDir)\sz_to_float.obj : system\sz_to_float.asm
    $(AS) $?
$(OutDir)\IEnum2.obj : system\IEnum2.asm
    $(AS) $?
$(OutDir)\HIDObject.obj : system\HIDObject.asm
    $(AS) $?
$(OutDir)\HIDUsage.obj : system\HIDUsage.asm
    $(AS) $?
$(OutDir)\ABox.obj : source\ABox.asm
    $(AS) $?
$(OutDir)\containers.obj : VR\containers.asm
    $(AS) $?
$(OutDir)\abox_align.obj : source\abox_align.asm
    $(AS) $?
$(OutDir)\ABox_circuit.obj : source\ABox_circuit.asm
    $(AS) $?
$(OutDir)\abox_context.obj : source\abox_context.asm
    $(AS) $?
$(OutDir)\ABox_File.obj : source\ABox_File.asm
    $(AS) $?
$(OutDir)\ABox_Hardware.obj : source\ABox_Hardware.asm
    $(AS) $?
$(OutDir)\ABox_Math.obj : source\ABox_Math.asm
    $(AS) $?
$(OutDir)\ABox_Osc.obj : source\ABox_Osc.asm
    $(AS) $?
$(OutDir)\ABox_Play.obj : source\ABox_Play.asm
    $(AS) $?
$(OutDir)\auto_unit.obj : source\auto_unit.asm
    $(AS) $?
$(OutDir)\Bus.obj : source\BUS\Bus.asm
    $(AS) $?
$(OutDir)\bus_catmem.obj : source\BUS\bus_catmem.asm
    $(AS) $?
$(OutDir)\bus_edit.obj : source\BUS\bus_edit.asm
    $(AS) $?
$(OutDir)\bus_grid.obj : source\BUS\bus_grid.asm
    $(AS) $?
$(OutDir)\filenames.obj : source\filenames.asm
    $(AS) $?
$(OutDir)\gdi_clocks.obj : source\GDI\gdi_clocks.asm
    $(AS) $?
$(OutDir)\gdi_Colors.obj : source\GDI\gdi_Colors.asm
    $(AS) $?
$(OutDir)\gdi_DIB.obj : source\GDI\gdi_DIB.asm
    $(AS) $?
$(OutDir)\gdi_display.obj : source\GDI\gdi_display.asm
    $(AS) $?
$(OutDir)\gdi_font.obj : source\GDI\gdi_font.asm
    $(AS) $?
$(OutDir)\gdi_invalidate.obj : source\GDI\gdi_invalidate.asm
    $(AS) $?
$(OutDir)\gdi_resource.obj : source\GDI\gdi_resource.asm
    $(AS) $?
$(OutDir)\gdi_Shapes.obj : source\GDI\gdi_Shapes.asm
    $(AS) $?
$(OutDir)\gdi_Triangles.obj : source\GDI\gdi_Triangles.asm
    $(AS) $?
$(OutDir)\strings.obj : source\GDI\strings.asm
    $(AS) $?
$(OutDir)\hwnd_About.obj : source\HWND\hwnd_About.asm
    $(AS) $?
$(OutDir)\hwnd_colors.obj : source\HWND\hwnd_colors.asm
    $(AS) $?
$(OutDir)\hwnd_Create.obj : source\HWND\hwnd_Create.asm
    $(AS) $?
$(OutDir)\hwnd_debug.obj : source\HWND\hwnd_debug.asm
    $(AS) $?
$(OutDir)\hwnd_equation.obj : source\HWND\hwnd_equation.asm
    $(AS) $?
$(OutDir)\hwnd_main.obj : source\HWND\hwnd_main.asm
    $(AS) $?
$(OutDir)\hwnd_mainmenu.obj : source\HWND\hwnd_mainmenu.asm
    $(AS) $?
$(OutDir)\hwnd_mouse.obj : source\HWND\hwnd_mouse.asm
    $(AS) $?
$(OutDir)\hwnd_popup.obj : source\HWND\hwnd_popup.asm
    $(AS) $?
$(OutDir)\hwnd_Status.obj : source\HWND\hwnd_Status.asm
    $(AS) $?
$(OutDir)\locktable.obj : source\locktable.asm
    $(AS) $?
$(OutDir)\misc.obj : source\misc.asm
    $(AS) $?
$(OutDir)\object_bitmap.obj : source\object_bitmap.asm
    $(AS) $?
$(OutDir)\ABox_PinInterface.obj : source\OBJECTS\ABox_PinInterface.asm
    $(AS) $?
$(OutDir)\closed_Group.obj : source\OBJECTS\closed_Group.asm
    $(AS) $?
$(OutDir)\ABox_Button.obj : source\OBJECTS\Controls\ABox_Button.asm
    $(AS) $?
$(OutDir)\ABox_Knob.obj : source\OBJECTS\Controls\ABox_Knob.asm
    $(AS) $?
$(OutDir)\ABox_Slider.obj : source\OBJECTS\Controls\ABox_Slider.asm
    $(AS) $?
$(OutDir)\knob_parser.obj : source\OBJECTS\Controls\knob_parser\knob_parser.asm
    $(AS) $?
$(OutDir)\ABox_Clock.obj : source\OBJECTS\Devices\ABox_Clock.asm
    $(AS) $?
$(OutDir)\ABox_HID.obj : source\OBJECTS\Devices\ABox_HID.asm
    $(AS) $?
$(OutDir)\ABox_Plugin.obj : source\OBJECTS\Devices\ABox_Plugin.asm
    $(AS) $?
$(OutDir)\ABox_Plugin_Editor.obj : source\OBJECTS\Devices\ABox_Plugin_Editor.asm
    $(AS) $?
$(OutDir)\ABox_WaveIn.obj : source\OBJECTS\Devices\ABox_WaveIn.asm
    $(AS) $?
$(OutDir)\ABox_WaveOut.obj : source\OBJECTS\Devices\ABox_WaveOut.asm
    $(AS) $?
$(OutDir)\ABox_Label.obj : source\OBJECTS\Displays\ABox_Label.asm
    $(AS) $?
$(OutDir)\ABox_Readout.obj : source\OBJECTS\Displays\ABox_Readout.asm
    $(AS) $?
$(OutDir)\ABox_Scope.obj : source\OBJECTS\Displays\ABox_Scope.asm
    $(AS) $?
$(OutDir)\equation.obj : source\OBJECTS\equation.asm
    $(AS) $?
$(OutDir)\fft_abox.obj : source\OBJECTS\fft_abox.asm
    $(AS) $?
$(OutDir)\ABox_OscFile.obj : source\OBJECTS\File\ABox_OscFile.asm
    $(AS) $?
$(OutDir)\csv_reader.obj : source\OBJECTS\File\csv_reader.asm
    $(AS) $?
$(OutDir)\csv_writer.obj : source\OBJECTS\File\csv_writer.asm
    $(AS) $?
$(OutDir)\data_file.obj : source\OBJECTS\File\data_file.asm
    $(AS) $?
$(OutDir)\file_calc.obj : source\OBJECTS\File\file_calc.asm
    $(AS) $?
$(OutDir)\file_hardware.obj : source\OBJECTS\File\file_hardware.asm
    $(AS) $?
$(OutDir)\media_reader.obj : source\OBJECTS\File\media_reader.asm
    $(AS) $?
$(OutDir)\media_writer.obj : source\OBJECTS\File\media_writer.asm
    $(AS) $?
$(OutDir)\memory_buffer.obj : source\OBJECTS\File\memory_buffer.asm
    $(AS) $?
$(OutDir)\ABox_ADSR.obj : source\OBJECTS\Generators\ABox_ADSR.asm
    $(AS) $?
$(OutDir)\ABox_Difference.obj : source\OBJECTS\Generators\ABox_Difference.asm
    $(AS) $?
$(OutDir)\ABox_Oscillators.obj : source\OBJECTS\Generators\ABox_Oscillators.asm
    $(AS) $?
$(OutDir)\ABox_Rand.obj : source\OBJECTS\Generators\ABox_Rand.asm
    $(AS) $?
$(OutDir)\midi_filter.obj : source\OBJECTS\midi\midi_filter.asm
    $(AS) $?
$(OutDir)\midi_strings.obj : source\OBJECTS\midi\midi_strings.asm
    $(AS) $?
$(OutDir)\midiin_que.obj : source\OBJECTS\midi\midiin_que.asm
    $(AS) $?
$(OutDir)\midiin2.obj : source\OBJECTS\midi\midiin2.asm
    $(AS) $?
$(OutDir)\midiout_device.obj : source\OBJECTS\midi\midiout_device.asm
    $(AS) $?
$(OutDir)\midiout2.obj : source\OBJECTS\midi\midiout2.asm
    $(AS) $?
$(OutDir)\midistream_insert.obj : source\OBJECTS\midi\midistream_insert.asm
    $(AS) $?
$(OutDir)\range_parser.obj : source\OBJECTS\midi\range_parser.asm
    $(AS) $?
$(OutDir)\tracker.obj : source\OBJECTS\midi\tracker.asm
    $(AS) $?
$(OutDir)\opened_Group.obj : source\OBJECTS\opened_Group.asm
    $(AS) $?
$(OutDir)\ABox_1cP.obj : source\OBJECTS\Processors\ABox_1cP.asm
    $(AS) $?
$(OutDir)\ABox_Damper.obj : source\OBJECTS\Processors\ABox_Damper.asm
    $(AS) $?
$(OutDir)\ABox_Delay.obj : source\OBJECTS\Processors\ABox_Delay.asm
    $(AS) $?
$(OutDir)\ABox_Delta.obj : source\OBJECTS\Processors\ABox_Delta.asm
    $(AS) $?
$(OutDir)\ABox_Divider.obj : source\OBJECTS\Processors\ABox_Divider.asm
    $(AS) $?
$(OutDir)\ABox_Equation.obj : source\OBJECTS\Processors\ABox_Equation.asm
    $(AS) $?
$(OutDir)\ABox_FFT.obj : source\OBJECTS\Processors\ABox_FFT.asm
    $(AS) $?
$(OutDir)\ABox_FFTOP.obj : source\OBJECTS\Processors\ABox_FFTOP.asm
    $(AS) $?
$(OutDir)\ABox_IIR.obj : source\OBJECTS\Processors\ABox_IIR.asm
    $(AS) $?
$(OutDir)\ABox_OscMath.obj : source\OBJECTS\Processors\ABox_OscMath.asm
    $(AS) $?
$(OutDir)\ABox_QKey.obj : source\OBJECTS\Processors\ABox_QKey.asm
    $(AS) $?
$(OutDir)\ABox_Dplex.obj : source\OBJECTS\Routers\ABox_Dplex.asm
    $(AS) $?
$(OutDir)\ABox_Mixer.obj : source\OBJECTS\Routers\ABox_Mixer.asm
    $(AS) $?
$(OutDir)\ABox_Mplex.obj : source\OBJECTS\Routers\ABox_Mplex.asm
    $(AS) $?
$(OutDir)\ABox_Probe.obj : source\OBJECTS\Routers\ABox_Probe.asm
    $(AS) $?
$(OutDir)\ABox_SamHold.obj : source\OBJECTS\Routers\ABox_SamHold.asm
    $(AS) $?
$(OutDir)\pin_connect.obj : source\pin_connect.asm
    $(AS) $?
$(OutDir)\pin_layout.obj : source\pin_layout.asm
    $(AS) $?
$(OutDir)\popup_data.obj : source\popup_data.asm
    $(AS) $?
$(OutDir)\popup_help.obj : source\popup_help.asm
    $(AS) $?
$(OutDir)\popup_strings.obj : source\popup_strings.asm
    $(AS) $?
$(OutDir)\registry.obj : source\registry.asm
    $(AS) $?
$(OutDir)\unredo.obj : source\unredo.asm
    $(AS) $?
$(OutDir)\xlate.obj : source\xlate.asm
    $(AS) $?

# uses <your build tools directory>\LINK.EXE  (linker)
LOBJS= \
	"$(OutDir)\ABox.obj" \
	"resources\ABox.res" \
	"$(OutDir)\ABox_1cP.obj" \
	"$(OutDir)\ABox_ADSR.obj" \
	"$(OutDir)\abox_align.obj" \
	"$(OutDir)\ABox_Button.obj" \
	"$(OutDir)\ABox_circuit.obj" \
	"$(OutDir)\ABox_Clock.obj" \
	"$(OutDir)\abox_context.obj" \
	"$(OutDir)\ABox_Damper.obj" \
	"$(OutDir)\ABox_Delay.obj" \
	"$(OutDir)\ABox_Delta.obj" \
	"$(OutDir)\ABox_Difference.obj" \
	"$(OutDir)\ABox_Divider.obj" \
	"$(OutDir)\ABox_Dplex.obj" \
	"$(OutDir)\ABox_Equation.obj" \
	"$(OutDir)\ABox_FFT.obj" \
	"$(OutDir)\ABox_FFTOP.obj" \
	"$(OutDir)\ABox_File.obj" \
	"$(OutDir)\ABox_Hardware.obj" \
	"$(OutDir)\ABox_HID.obj" \
	"$(OutDir)\ABox_IIR.obj" \
	"$(OutDir)\ABox_Knob.obj" \
	"$(OutDir)\ABox_Label.obj" \
	"$(OutDir)\ABox_Math.obj" \
	"$(OutDir)\ABox_Mixer.obj" \
	"$(OutDir)\ABox_Mplex.obj" \
	"$(OutDir)\ABox_Osc.obj" \
	"$(OutDir)\ABox_OscFile.obj" \
	"$(OutDir)\ABox_Oscillators.obj" \
	"$(OutDir)\ABox_OscMath.obj" \
	"$(OutDir)\ABox_PinInterface.obj" \
	"$(OutDir)\ABox_Play.obj" \
	"$(OutDir)\ABox_Plugin.obj" \
	"$(OutDir)\ABox_Plugin_Editor.obj" \
	"$(OutDir)\ABox_Probe.obj" \
	"$(OutDir)\ABox_QKey.obj" \
	"$(OutDir)\ABox_Rand.obj" \
	"$(OutDir)\ABox_Readout.obj" \
	"$(OutDir)\ABox_SamHold.obj" \
	"$(OutDir)\ABox_Scope.obj" \
	"$(OutDir)\ABox_Slider.obj" \
	"$(OutDir)\ABox_WaveIn.obj" \
	"$(OutDir)\ABox_WaveOut.obj" \
	"$(OutDir)\auto_unit.obj" \
	"$(OutDir)\Bus.obj" \
	"$(OutDir)\bus_catmem.obj" \
	"$(OutDir)\bus_edit.obj" \
	"$(OutDir)\bus_grid.obj" \
	"$(OutDir)\closed_Group.obj" \
	"$(OutDir)\containers.obj" \
	"$(OutDir)\csv_reader.obj" \
	"$(OutDir)\csv_writer.obj" \
	"$(OutDir)\data_file.obj" \
	"$(OutDir)\equation.obj" \
	"$(OutDir)\fft_abox.obj" \
	"$(OutDir)\file_calc.obj" \
	"$(OutDir)\file_hardware.obj" \
	"$(OutDir)\filenames.obj" \
	"$(OutDir)\float_to_sz.obj" \
	"$(OutDir)\gdi_clocks.obj" \
	"$(OutDir)\gdi_Colors.obj" \
	"$(OutDir)\gdi_DIB.obj" \
	"$(OutDir)\gdi_display.obj" \
	"$(OutDir)\gdi_font.obj" \
	"$(OutDir)\gdi_invalidate.obj" \
	"$(OutDir)\gdi_resource.obj" \
	"$(OutDir)\gdi_Shapes.obj" \
	"$(OutDir)\gdi_Triangles.obj" \
	"$(OutDir)\HIDObject.obj" \
	"$(OutDir)\HIDUsage.obj" \
	"$(OutDir)\hwnd_About.obj" \
	"$(OutDir)\hwnd_colors.obj" \
	"$(OutDir)\hwnd_Create.obj" \
	"$(OutDir)\hwnd_debug.obj" \
	"$(OutDir)\hwnd_equation.obj" \
	"$(OutDir)\hwnd_main.obj" \
	"$(OutDir)\hwnd_mainmenu.obj" \
	"$(OutDir)\hwnd_mouse.obj" \
	"$(OutDir)\hwnd_popup.obj" \
	"$(OutDir)\hwnd_Status.obj" \
	"$(OutDir)\IEnum2.obj" \
	"$(OutDir)\knob_parser.obj" \
	"$(OutDir)\locktable.obj" \
	"$(OutDir)\media_reader.obj" \
	"$(OutDir)\media_writer.obj" \
	"$(OutDir)\memory3.obj" \
	"$(OutDir)\memory_buffer.obj" \
	"$(OutDir)\midi_filter.obj" \
	"$(OutDir)\midi_strings.obj" \
	"$(OutDir)\midiin2.obj" \
	"$(OutDir)\midiin_que.obj" \
	"$(OutDir)\midiout2.obj" \
	"$(OutDir)\midiout_device.obj" \
	"$(OutDir)\midistream_insert.obj" \
	"$(OutDir)\misc.obj" \
	"$(OutDir)\object_bitmap.obj" \
	"$(OutDir)\opened_Group.obj" \
	"$(OutDir)\pin_connect.obj" \
	"$(OutDir)\pin_layout.obj" \
	"$(OutDir)\popup_data.obj" \
	"$(OutDir)\popup_help.obj" \
	"$(OutDir)\popup_strings.obj" \
	"$(OutDir)\range_parser.obj" \
	"$(OutDir)\registry.obj" \
	"$(OutDir)\strings.obj" \
	"$(OutDir)\sz_to_float.obj" \
	"$(OutDir)\tracker.obj" \
	"$(OutDir)\unredo.obj" \
	"$(OutDir)\xlate.obj"

# uses <your build tools directory>\LINK.EXE  (linker)
"$(ProjName).exe" : $(LOBJS)
    @ECHO linking ...
	 $(LK) @<<
  $(LOBJS)
<<


## description blocks
##
#############################################################################
#############################################################################