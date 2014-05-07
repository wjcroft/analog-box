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
##
## makeabox.py
##
""" makeabox.py is a simplistic build tool for making ABox executables.
    To use it you need to edit this file and customize it for your system.
    0) Define build_type as either 'DEBUG' or 'RELEASE'
    1) Set the values of ml_dir, lk_dir, and lb_dir for your system.
    2) Set the desired intermediate directories to where you want them.
    3) <optional> Configure the command line args to your taste.
    In both cases, directory names starting with / are absolute paths,
    and those starting without / are reletive to where makeabox.py was run.
"""

import os
import sys

#0) define build_type as either 'DEBUG' or 'RELEASE'
#build_type = 'DEBUG'
build_type = 'RELEASE'

#1) define these values for your system
(ml_dir,ml_name) = ("/masm32/bin","ml.exe")    #   where ml.exe lives
(lk_dir,lk_name) = ("/masm32/bin","link.exe")  #   where link.exe lives
lb_dir = "/masm32/lib"                          #   where the .lib files are

#2) define these for where you want intermediate and final files to be placed
int_dir = "temp"    # where .obj, .lst, .map and cmd files live

(out_dir,out_name) = ("", "ABox242")


## #########################################################################
## #########################################################################
## #########################################################################

#3) these define the command line args for ml and link

ml_fixed_args = [ # list of tuples, (debug option, release option)
    ##  Microsoft (R) Macro Assembler Version 6.14.8444
    ##  Copyright (C) Microsoft Corp 1981-1997.  All rights reserved.
    ##          ML [ /options ] filelist [ /link linkoptions ]
    ##
                    ##  /AT Enable tiny model (.COM file)
                    ##  /Bl<linker> Use alternate linker
    ("/c",)*2,      ##  /c Assemble without linking
    ("/Cp",)*2,     ##  /Cp Preserve case of user identifiers
                    ##  /Cu Map all identifiers to upper case
    ("/Cx",)*2,     ##  /Cx Preserve case in publics, externs
    ("/coff",)*2,    ##  /coff generate COFF format object file
    ("/DALLOC2",)*2,##below  /D<name>[=text] Define text macro
                    ##  /EP Output preprocessed listing to stdout
                    ##  /F <hex> Set stack size (bytes)
                    ##  /Fe<file> Name executable
                    ##below  /Fl[file] Generate listing
                    ##  /Fm[file] Generate map
                    ##below  /Fo<file> Name object file
                    ##  /FPi Generate 80x87 emulator encoding
                    ##  /Fr[file] Generate limited browser info
                    ##  /FR[file] Generate full browser info
    ("/Gz",)*2,     ##  /G<c|d|z> Use Pascal, C, or Stdcall calls
                    ##  /H<number> Set max external name length
                    ##below  /I<name> Add include path
                    ##  /link <linker options and libraries>
    ("/nologo",)*2, ##  /nologo Suppress copyright message
                    ##  /Sa Maximize source listing
                    ##  /Sc Generate timings in listing
                    ##  /Sf Generate first pass listing
                    ##  /Sl<width> Set line width
    ("/Sn",None),  ##  /Sn Suppress symbol-table listing
                    ##  /Sp<length> Set page length
                    ##  /Ss<string> Set subtitle
                    ##  /St<string> Set title
                    ##  /Sx List false conditionals
                    ##  /Ta<file> Assemble non-.ASM file
                    ##  /w Same as /W0 /WX
                    ##  /WX Treat warnings as errors
                    ##  /W<number> Set warning level
    ("/X",)*2       ##  /X Ignore INCLUDE environment path
                    ##  /Zd Add line number debug info
                    ##  /Zf Make all symbols public
                    ##  /Zi Add symbolic debug info
                    ##  /Zm Enable MASM 5.10 compatibility
                    ##  /Zp[n] Set structure alignment
                    ##  /Zs Perform syntax check only
    ] # ml_fixed_args

# additional /D args
ml_d_args = { 'DEBUG'   : [ "/DDEBUGBUILD" ] ,
              'RELEASE' : [ "/DRELEASEBUILD" ]
            }

ml_i_ags = [ "include", "system", "vr" ]

ml_variable_args = [ # list of tuples, (debug option, release option)
    ('/Fl"{}.lst"',None), ##  /Fl[file] Generate listing
    ('/Fo"{}.obj"',)*2    ##  /Fo<file> Name object file
    ] # ml_variable_args



lk_fixed_args = [
    ##  Microsoft (R) Incremental Linker Version 5.12.8078
    ##  Copyright (C) Microsoft Corp 1992-1998. All rights reserved.
    ##
    ##  usage: LINK [options] [files] [@commandfile]
                    ##
                    ##     options:
                    ##
                    ##        /ALIGN:#
                    ##        /BASE:{address|@filename,key}
                    ##        /COMMENT:comment
                    ##        /RELEASE
                    ##        /DEBUG
                    ##        /DEBUGTYPE:{CV|COFF}
                    ##        /DEF:filename
                    ##        /DEFAULTLIB:library
                    ##        /DLL
                    ##        /DRIVER[:{UPONLY|WDM}]
                    ##        /ENTRY:symbol
                    ##        /EXETYPE:DYNAMIC
                    ##        /EXPORT:symbol
    "/FIXED",       ##        /FIXED[:NO]
                    ##        /FORCE[:{MULTIPLE|UNRESOLVED}]
                    ##        /GPSIZE:#
                    ##        /HEAP:reserve[,commit]
                    ##        /IMPLIB:filename
                    ##        /INCLUDE:symbol
    "/INCREMENTAL:NO",##      /INCREMENTAL:{YES|NO}
                    ##        /LARGEADDRESSAWARE[:NO]
                    ##below   /LIBPATH:dir
    "/MACHINE:IX86",##        /MACHINE:{ALPHA|ARM|IX86|MIPS|MIPS16|MIPSR41XX|PPC|SH3|SH4}
                    ##below   /MAP[:filename]
                    ##        /MAPINFO:{EXPORTS|FIXUPS|LINES}
                    ##        /MERGE:from=to
    ##"/NODEFAULTLIB",##        /NODEFAULTLIB[:library]
                    ##        /NOENTRY
    "/NOLOGO",      ##        /NOLOGO
                    ##        /OPT:{ICF[,iterations]|NOICF|NOREF|NOWIN98|REF|WIN98}
                    ##        /ORDER:@filename
                    ##below   /OUT:filename
                    ##        /PDB:{filename|NONE}
                    ##        /PDBTYPE:{CON[SOLIDATE]|SEPT[YPES]}
                    ##        /PROFILE
                    ##        /SECTION:name,[E][R][W][S][D][K][L][P][X]
                    ##        /STACK:reserve[,commit]
                    ##        /STUB:filename
    "/SUBSYSTEM:WINDOWS"##    /SUBSYSTEM:{NATIVE|WINDOWS|CONSOLE|WINDOWSCE|POSIX}[,#[.##]]
                    ##        /SWAPRUN:{CD|NET}
                    ##        /VERBOSE[:LIB]
                    ##        /VERSION:#[.#]
                    ##        /VXD
                    ##        /WARN[:warninglevel]
                    ##        /WINDOWSCE:{CONVERT|EMULATION}
                    ##        /WS:AGGRESSIVE
    ] # lk_fixed_args

lk_lib_arg = '/LIBPATH:"{}"'  ##        /LIBPATH:dir
lk_map_arg = '/MAP:"{}"'      ##        /MAP[:filename]
lk_out_arg = '/OUT:"{}"'      ##        /OUT:filename



## #########################################################################
## #########################################################################
## #########################################################################

## now we get to work

additional_obj = [ 'resources/abox.res' ]

# src_tree is a dictionary of { directory_name : [ content ] }
# where content is either another src_tree or a "filename"
# every filename has an implied .asm extension
# every filename will be sent through the assembler
# the filename is used to build the resultant .obj and .lst
# the scheme is:
#   for every .asm file in the tree,
#       if this makefile is newer an existing execute
#       or the asm file's matching .obj doesn't exist
#       or it does exist but has an earlier time stamp
#       or it is current but has zero size
#       or it's object file is older than the make file
#
#       then the .asm file is sent through ml.exe

src_tree = {

    "system" : [ "float_to_sz" ,
                 "HIDObject" ,
                 "HIDUsage" ,
                 "IEnum2" ,
                 "memory3" ,
                 "sz_to_float"
               ] ,

    "VR" : [ "containers" ] ,

    "source" : [ "ABox" ,
                 "abox_align" ,
                 "ABox_circuit" ,
                 "abox_context" ,
                 "ABox_File" ,
                 "ABox_Hardware" ,
                 "ABox_Math" ,
                 "ABox_Osc" ,
                 "ABox_Play" ,
                 "auto_unit" ,
                 "filenames" ,
                 "locktable" ,
                 "misc" ,
                 "object_bitmap" ,
                 "pin_connect" ,
                 "pin_layout" ,
                 "popup_data" ,
                 "popup_help" ,
                 "popup_strings" ,
                 "registry" ,
                 "unredo" ,
                 "xlate" ,

                 { "BUS" : [ "Bus" ,
                             "bus_catmem" ,
                             "bus_edit" ,
                             "bus_grid"  ] ,

                   "GDI" : [ "gdi_clocks" ,
                             "gdi_Colors" ,
                             "gdi_DIB" ,
                             "gdi_display" ,
                             "gdi_font" ,
                             "gdi_invalidate" ,
                             "gdi_resource" ,
                             "gdi_Shapes" ,
                             "gdi_Triangles" ,
                             "strings"   ] ,

                   "HWND" : [ "hwnd_About" ,
                              "hwnd_colors" ,
                              "hwnd_Create" ,
                              "hwnd_debug" ,
                              "hwnd_equation" ,
                              "hwnd_main" ,
                              "hwnd_mainmenu" ,
                              "hwnd_mouse" ,
                              "hwnd_popup" ,
                              "hwnd_Status"   ] ,

                   "OBJECTS" : [ "ABox_PinInterface" ,
                                 "closed_Group" ,
                                 "equation" ,
                                 "fft_abox" ,
                                 "opened_Group" ,

                                 { "Controls" : [ "ABox_Button" ,
                                                  "ABox_Knob" ,
                                                  "ABox_Slider" ,
                                                  { "knob_parser" : [ "knob_parser" ] }
                                                ] ,

                                   "Devices" : [ "ABox_Clock" ,
                                                 "ABox_HID" ,
                                                 "ABox_Plugin" ,
                                                 "ABox_Plugin_Editor" ,
                                                 "ABox_WaveIn" ,
                                                 "ABox_WaveOut"  ] ,

                                   "Displays" : [ "ABox_Label" ,
                                                  "ABox_Readout" ,
                                                  "ABox_Scope"   ] ,

                                   "File" : [ "ABox_OscFile" ,
                                              "csv_reader" ,
                                              "csv_writer" ,
                                              "data_file" ,
                                              "file_calc" ,
                                            #  "file_debug" ,
                                              "file_hardware" ,
                                              "media_reader" ,
                                              "media_writer" ,
                                              "memory_buffer"   ] ,

                                   "Generators" : [ "ABox_ADSR" ,
                                                    "ABox_Difference" ,
                                                    "ABox_Oscillators" ,
                                                    "ABox_Rand"   ] ,

                                   "midi" : [ "midi_filter" ,
                                              "midi_strings" ,
                                              "midiin_que" ,
                                              "midiin2" ,
                                              "midiout_device" ,
                                              "midiout2" ,
                                              "midistream_insert" ,
                                              "range_parser" ,
                                              "tracker"   ] ,

                                   "Processors" : [ "ABox_1cP" ,
                                                    "ABox_Damper" ,
                                                    "ABox_Delay" ,
                                                    "ABox_Delta" ,
                                                    "ABox_Divider" ,
                                                    "ABox_Equation" ,
                                                    "ABox_FFT" ,
                                                    "ABox_FFTOP" ,
                                                    "ABox_IIR" ,
                                                    "ABox_OscMath" ,
                                                    "ABox_QKey"   ] ,

                                   "Routers" : [ "ABox_Dplex" ,
                                                 "ABox_Mixer" ,
                                                 "ABox_Mplex" ,
                                                 "ABox_Probe" ,
                                                 "ABox_SamHold" ]
                                 } # /objects/
                                ]
                 } # /source/
               ]
    } # src_tree

## #########################################################################
## #########################################################################
## #########################################################################

def file_exists(file_path) :    return os.path.exists(file_path)
def file_time(file_path) :    return os.path.getmtime(file_path)
def file_size(file_path) :    return os.path.getsize(file_path)

# define the build_int list
build_int = { 'DEBUG' : 0 , 'RELEASE' : 1 }

## #########################################################################
## #########################################################################
## #########################################################################


# make sure the specified files and dirs exist
ml_exe = os.path.join( os.path.abspath(ml_dir), ml_name )
lk_exe = os.path.join( os.path.abspath(lk_dir), lk_name )
lb_dir = os.path.abspath(lb_dir)
int_dir = os.path.abspath(int_dir)

assert file_exists( ml_exe )
assert file_exists( lk_exe )
assert file_exists( lb_dir )
if not file_exists( int_dir ) :
    os.makedirs(int_dir)

    
## #########################################################################
## #########################################################################
## #########################################################################
    
# open the ml command file and write the default args
ml_cmd_name = os.path.join( int_dir, "ml_cmd.txt" )
ml_cmd = open( ml_cmd_name,'wt' )

# fixed args
for fa in ml_fixed_args : # = [ # list of tuples, (debug option, release option)
    a = fa[ build_int[ build_type ] ]
    if a is not None :
        ml_cmd.write(a + "\n")
# addition D args
for a in ml_d_args[build_type] :
    if a is not None :
        ml_cmd.write(a + "\n")

#additional I args
for i in ml_i_ags :
    ml_cmd.write('/I"'+os.path.abspath(i) + '"\n')

## #########################################################################
## #########################################################################
## #########################################################################
  

# open the link command file and write the default args
lk_cmd_name = os.path.join( int_dir, "lk_cmd.txt" )
lk_cmd = open( lk_cmd_name,'wt' )

out_dir = os.path.abspath(out_dir)
map_path = os.path.join( int_dir, out_name + ".map" )
out_path = os.path.join( out_dir, out_name + ".exe" )
for fa in lk_fixed_args :
    lk_cmd.write(fa + "\n")
lk_cmd.write( lk_lib_arg.format( lb_dir ) + "\n" )
lk_cmd.write( lk_map_arg.format( map_path ) + "\n" )
lk_cmd.write( lk_out_arg.format( out_path ) + "\n" )

for a in additional_obj :
    lk_cmd.write( '"' + os.path.abspath(a) + '"\n' )


## #########################################################################
## #########################################################################
## #########################################################################
    
# determine the name of this file so we can check if it's newer
my_path = os.path.abspath(sys.argv[0])

force_rebuild = False
if file_exists( out_path ) and file_time(out_path) < file_time(my_path) :
    force_rebuild = True


## #########################################################################
## #########################################################################
## #########################################################################

# scan the src_tree and look for newer files

def process_asm_file(path,name) :

    # build some paths
    na = os.path.join(path,name)+".asm"
    ni = os.path.join(int_dir,name)
    no = ni+".obj"

    ret = False
    if force_rebuild or \
        not file_exists(no) or \
        file_time(no) < file_time(na) or \
        file_time(no) < file_time(my_path) or \
        not file_size(no) :

        line = ""
        # add to ml cmd list
        for va in ml_variable_args :
            v = va[build_int[build_type]]
            if v is None : continue
            line += v.format( ni ) + " "
        line += '"'+na+'"'
        ml_cmd.write( line + '\n' )
        ret = True

    # always add to link list
    lk_cmd.write( '"' + no + '"\n' )

    return ret


def scan_src_tree(path,iter) :
    assert( isinstance(iter,dict) )
    ret = False
    for k in iter.keys() :
        v = iter[k]
        assert( isinstance(v,list) )
        for f in v :
            if isinstance(f,dict) :
                ret |= scan_src_tree( os.path.join(path,k), f )
            else :
                assert( isinstance(f,str) )
                ret |= process_asm_file(os.path.join(path,k),f)
    return ret

have_asm_cmd = scan_src_tree(os.path.abspath(""),src_tree)

ml_cmd.close()
lk_cmd.close()

## #########################################################################
## #########################################################################
## #########################################################################

# check the results and do work

if have_asm_cmd :
    ret = os.spawnl( os.P_WAIT,ml_exe,ml_exe,'@"'+ml_cmd_name+'"' )
    if ret :
        # hmm we had errors
        # would be a very good idea to erase all the obj we just tried to make
        print( "ml reported errors -- quitting" )
        quit()

# otherwise, do the link
if force_rebuild or have_asm_cmd :
    print( 'linking' )
    ret = os.spawnl( os.P_WAIT,lk_exe,lk_exe,'@"'+lk_cmd_name+'"' )
    if ret :
        print( "link reported errors -- quitting" )
        quit()

print( "success -- done" )

## #########################################################################
## #########################################################################
## #########################################################################


