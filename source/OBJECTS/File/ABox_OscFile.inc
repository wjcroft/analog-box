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
;// ABox_OscFile.inc        ver2 (see media_reader.asm)
;//                         ver 2+ (removed hardware and went to special calc)

comment ~ /*

    the generic scheme

        file_length may or may not be defined
            xxx_Open must account for this
        file_size is then derived from file length

        file_Open will

            set dwUser with new mode and flags
            call xxx_Open

        xxx_Open must

            open the source media
            setup the MODE_IS varaiables
            initialize the buffer mechanism
            set file_size correctly
            set max_length if applicable
            rewind to start of media

            or: return an error

        file_Close will 

            reset MODE_IS flags
            call xxx_Close
            reset the length, size and position to 0

        xxx_Close must

            free any allocated memory
            close all devices


    CALC

        file_Calc will

            call xxx_CheckState
            
            process loop
            
                may call xxx_WriteBuffers
                may call xxx_GetBuffers

            exit

        xxx_CheckState must

            setup file.buf from xxx_ buffer mechanism
            prepare any seeking count limits
            verify that the length and size are correct
            verify that buffers are ready to be read
            detect if file_position is out side of range
            if file_position is inside range, exit to xxx_GetBuffers
            otherwise exit with non zero value

            see check_state_table

        xxx_GetBuffers must

            preserve ecx ebx edi ebp esp

            read data to buffer specified by file.buf
            issue any seek commands reqired to get the buffers
            if seek-sync, wait for completion
            fill in buffers with acceptable data
            return non zero for sucess

        xxx_Write buffers must

            preserve ecx ebx edi ebp esp

            write data specified by file.buf            
            issue any seek commands required 
            if seek-sync, wait for completion
            format and write the buffers with acceptable data


DATA BUFFER manipulation

    reader_Open 
    
        allocates 2 DATA_BUFFER's, buf1 and buf2
        it sets begin, end and remain of each to cause reading

    reader_fill_buffer 
        
        called from IMemInputPin_recieve
        selects which buffer to use by
            comparing buffer position passed from caller
            againt buffer positions in buf1 and buf2
        if a buffer is not found
            wait for reader.hEvent to become signaled

    reader_CheckState

        checks if file_position is between either buffer
        if that buffer has zero remaining
            then set file_buffer

        if neither buffer is acceptable
            return fail or wait

    reader_ReadBuffers

        check if desired position applies to either buffer
        if that buffer is ready
            set up file_buffer
        otherwise
            issue a seek command            
            if sync seek, wait until it completes ??
            otherwise return fail




ABOX234

    we now use the ABox's hardware H_stop mechanism to flush media writer
    that way user can copy the file as expected

    we also have a serious revamp of the wave writer

    and we have finally taken the plunge and introduced text modes
    see csvwriter.asm and csvreader.asm


*/ comment ~


IFNDEF ABOX_OSC_FILE_IS_INCLUDED
ABOX_OSC_FILE_IS_INCLUDED EQU 1

;//////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////
;///
;///
;///    build configuration

;// debugging

        INCLUDE <file_debug.inc>

    ;// build configuration

    ;// one of these must be on 
        
        FILE_DEBUG_OFF      ;// ignore FILE_DEBUG_MESSAGE
        ;// FILE_DEBUG_ON           ;// store FILE_DEBUG_MESSAGE to file_debug.txt

    ;// optional

        ;//USELOGFILE EQU 1 ;// tell DirectShow to log connection quest



;//////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////
;///
;///
;///    sizes and lengths


    ;// sizes of xfer buffers for various modes
    ;// we'll use two samary buffer per data buffer

        DATA_BUFFER_LENGTH      EQU 2 * SAMARY_LENGTH

    ;// edit buffer sizes for dialogs

        FILE_EDIT_LENGTH_BUFFER_LENGTH  EQU 16
        FILE_MAX_ID_LENGTH              EQU 16
        FILE_MAX_RATE_LENGTH            EQU 8


;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////
;///
;///                        allows one thread to get data
;///    DATA BUFFER         while another thread processes
;///                        seeking may be synchronized by an event
;///                        _CheckState must set up the file.buf
;///                        _GetBuffers can read, write, and schedule a seek

        DATA_BUFFER STRUCT

            start       dd  0   ;// stream position in samples          
            stop        dd  0   ;// stream position in samples          
            remain      dd  0   ;// 0 = ready for action
            samples     dd  0   ;// number of samples to get
            pointer     dd  0   ;// allocated memory block, DATA_BUFFER_LENGTH*num_channels floats
            dwFlags     dd  0   ;// flag to indicate that data needs written

            DATA_BUFFER_DIRTY   EQU 00000001h   ;// data needs written to disk

        DATA_BUFFER ENDS

        ;// convention, 2nd channel of stereo data is DATA_BUFFER_LENGTH samples after ptr



;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////
;///
;///    DATA_FILE
;///

        DATA_FILE STRUCT

            hFile   dd  0   
            dwFlags dd  0

            ;// bothe flags are reset by file_H_Calc
            DATA_FILE_SIZE_READ EQU 00000001h   ;// the file size has been read
            DATA_FILE_BUFFER_READY EQU 00002h   ;// the data buffer has been read from disk

        DATA_FILE ENDS



;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////
;///
;///    GMAP
;///

        GMAP STRUCT

            hMap        dd  0   ;// duplicated handle to our file data
            pTable      dd  0   ;// pointer to our gmap table entry         
            actual_size dd  0   ;// actual size of the memory block in bytes
            ;// gmap sets up buf directly

        GMAP ENDS
            

;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////
;///
;///    MEDIA READER COM STRUCT DEFINITIONS
;///

        IPIN STRUCT
            vtable      dd  0   ;// OFFSET IPin_vtable
            ref_count   dd  0
        IPIN ENDS

        IMEMINPUTPIN STRUCT
            vtable      dd  0   ;// IMemInputPin_vtable
            ref_count   dd  0
        IMEMINPUTPIN ENDS

        IFILTER STRUCT
            vtable      dd  0   ;// OFFSET IMediaFilter_vtable
            ref_count   dd  0
        IFILTER ENDS

        IMEDIAREADER    STRUCT

            filter          IFILTER         {}
            pin             IPIN            {}
            meminputpin     IMEMINPUTPIN    {}

            pGraphBuilder   dd  0   ;// ptr to IGraphBuilder interface
            pMediaControl   dd  0   ;// ptr to IMediaControl interface
            pMediaSeeking   dd  0   ;// ptr to IMediaSeeking interface
            pFilterGraph    dd  0   ;// ptr to IFilterGraph that we are Joined to
            pReferenceClock dd  0   ;// ptr to IReferenceClock
            pConnectedPin   dd  0   ;// IPin we're connected to

            ;// needed by IEnum2

            pPins   dd  2 DUP (0)   ;// zero terminated pin list

            ;// rate chan bits are set by one one thread and read by another

            rate        dd  0   ;// sample rate
            chan        dd  0   ;// number of channels
            bits        dd  0   ;// number of bits

            ;// chanbits 0=8bit 1=16bit 2=32bit  +3 for sterao

            chanbits_shift  dd  0   ;// number of bits to shift samples to bytes
            chanbits_xfer   dd  0   ;// jump pointer to the receiver transfer loop

            ;// we swap buffers, to do this we need flags
            ;// reader_CheckState and reader_fill_buffers will coordinate access

            state       dd  0   ;// see flags below

            hEvent      dd  0   ;// event used to signal the reader

            buf1    DATA_BUFFER {}
            buf2    DATA_BUFFER {}

            ;// media time
            ;// some streams are not represented as samples
            ;// to acount for this, we get a lot of code dedicated to 
            ;// to managing media time.
            uses_media_time     dd  0   ;// 0 if using samples

            time_sample_convert dq  0   ;// 0.64 bit fraction to convert from media time to samples
            sample_time_convert dq  0   ;// 32.32 bit fraction to convert samples to media time

        IMEDIAREADER ENDS

    ;// values for state

        READER_STATE_TEST       EQU 00000003h   ;// mask to get FILTER_STATE_STOPPED

        READER_FLUSHING         EQU 00000010h   ;// got begin flush
        READER_END_OF_STREAM    EQU 00000020h   ;// end of stream was received
        READER_IN_RECEIVE       EQU 00000040h   ;// IMemInputPin_Receive is currently active
        READER_IS_WAITING       EQU 00000080h   ;// filter is currently waiting for a buffer        

;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;///
;///                    allocates 3 buffers for the DATA_BUFFER
;///    writer          1) left input float data
;///                    2) right input float data
;///                    3) l+r output stereo word data
;///

    FILE_WRITER STRUCT

        hmmio   dd  0   ;// handle of opened file
        dwFlags dd  0   ;// flags
        
            WRITER_PREPARED EQU 00000001h   ;// we have descended to the end of the data chunk

        chunk_riff  MMCKINFO {}
        chunk_wave  MMCKINFO {}

    FILE_WRITER ENDS


;//////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////
;///
;///    csv writer and reader
;///


    CSV_READER STRUCT
        
        pData       dd  0   ;// allocated table data
        num_rows    dd  0   ;// number of rows in the file
        num_cols    dd  0   ;// number of columns in the file
        pAdressBuffer   dd  0   ;// allocated buffer for converting C R input to addresses
        dwFlags dd  0

        CSVREADER_UPDATE_CR_PINS    EQU 00000001h

    CSV_READER ENDS



    CSV_WRITER STRUCT
        
        hFile   dd  0   ;// handle of the opened file

        dwFlags dd  0   ;//

            FIRST_ON_LINE   EQU 00000001h   ;// true if the value is the first on the line


    CSV_WRITER ENDS


;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////
;///
;///    OSC_DATA
;///

        OSC_FILE_DATA STRUCT

        ;// positioning and size

            file_length     dd  0   ;// file length in samples  (master)
            file_size       dd  0   ;// file size in bytes      (slave)
            ;// note: dword is sufficient for 6 hours 45 minutes of material

            file_position   dd  0   ;// position of the file pointer (samples)          

            position_accumulator dd 0   ;// fractional acummulator (fractions of samples)

        ;// data buffers (file data is read/write here first)           

            buf DATA_BUFFER {}

        ;// data file interface

            datafile    DATA_FILE   {}
            ;// data creates 1 buf for read and write
            
        ;// memory buffer interface

            gmap    GMAP {}

        ;// media reader interface

            reader  IMEDIAREADER {}
            ;// reader swaps buffers bewteen threads

        ;// wave writer interface

            writer  FILE_WRITER {}

        ;// and we have CSV structs now too

            csvreader CSV_READER    {}
            csvwriter CSV_WRITER    {}

        ;// now that we maintain a hardware list, we set that here

            dlist_Declare_link file_hardware, OSC_FILE_DATA
            ;// head and tail are in FILE_HARDWARE_DEVICEBLOCK

        ;// file names  (these must be in order and consecutive)

            filename_table  dd  0   ;//0 pad, should always be zero
            filename_Data   dd  0   ;//1 (these must be in order and consecutive)
            filename_Memory dd  0   ;//2 (these must be in order and consecutive)
            filename_Reader dd  0   ;//3 (these must be in order and consecutive)
            filename_Writer dd  0   ;//4 (these must be in order and consecutive)
            filename_CSVReader dd 0 ;//5 (these must be in order and consecutive)
            filename_CSVWriter dd 0 ;//6 (these must be in order and consecutive)

        ;// sizing information

            max_length  dd  0   ;// maximum length we allow

        ;// display stuff

            FILE_PLAY_UPDATE_COUNT EQU 4

            play_update_count   dd  0   ;// update every FILE_PLAY_UPDATE_COUNT frames

        ;// format information (set by xxx_Open, reset by file_CloseMode)

            fmt_rate    dd  0   ;// samples per second
            fmt_chan    dd  0   ;// num channels
            fmt_bits    dd  0   ;// number of bits

        OSC_FILE_DATA ENDS

;//
;// user settings stored in object dwUser
;// these are defined as bits becuase they do not fall on hex boundaries

        ;// MODE                    -----------------------------XXXy   zero for bad mode

        FILE_MODE_DATA          EQU 00000000000000000000000000000001y
        FILE_MODE_MEMORY        EQU 00000000000000000000000000000010y
        FILE_MODE_READER        EQU 00000000000000000000000000000011y
        FILE_MODE_WRITER        EQU 00000000000000000000000000000100y

        FILE_MODE_CSVREADER     EQU 00000000000000000000000000000101y   ;// ABOX234: new
        FILE_MODE_CSVWRITER     EQU 00000000000000000000000000000110y   ;// ABOX234: new

        FILE_MODE_MAX           EQU 00000000000000000000000000000110y   ;// can add one more
        FILE_MODE_TEST          EQU 00000000000000000000000000000111y

        ;// WRITE TRIGGER           --------------------------XXX---y
                                                                 
        FILE_WRITE_POS          EQU 00000000000000000000000000001000y   ;// off for both edge
        FILE_WRITE_NEG          EQU 00000000000000000000000000010000y
        FILE_WRITE_GATE         EQU 00000000000000000000000000100000y

        FILE_WRITE_TEST  EQU FILE_WRITE_POS OR FILE_WRITE_NEG
    
        ;// MOVE TRIGGER            ----------------------XXXX------y
                                                                
        FILE_MOVE_POS           EQU 00000000000000000000000001000000y   ;// off for both edge
        FILE_MOVE_NEG           EQU 00000000000000000000000010000000y
        FILE_MOVE_GATE          EQU 00000000000000000000000100000000y
        FILE_MOVE_LOOP          EQU 00000000000000000000001000000000y   ;// loop at end

        FILE_MOVE_TEST  EQU FILE_MOVE_POS OR FILE_MOVE_NEG
    
        ;// SEEK TRIGGER            -----------------XXXXX----------y
                                                        
        FILE_SEEK_POS           EQU 00000000000000000000010000000000y   ;// off for both edge
        FILE_SEEK_NEG           EQU 00000000000000000000100000000000y
        FILE_SEEK_GATE          EQU 00000000000000000001000000000000y
                                                 
        FILE_SEEK_SYNC          EQU 00000000000000000010000000000000y   ;// don't wait for seeking
        FILE_SEEK_NORM          EQU 00000000000000000100000000000000y   ;// off for percent

        FILE_SEEK_TEST  EQU FILE_SEEK_POS OR FILE_SEEK_NEG
    
        ;// MODE_IS                 --XXXXXXXXXXXXXXX---------------y   ;// set by xxx_Open

        ;// ui actions
        FILE_MODE_IS_MOVEABLE   EQU 00000000000000001000000000000000y   ;// enable the move buttons
        FILE_MODE_IS_RATEABLE   EQU 00000000000000010000000000000000y   ;// enable the sr pin
        FILE_MODE_IS_SIZEABLE   EQU 00000000000000100000000000000000y   ;// enable the size edit box
        ;// pin and calc configuration
        FILE_MODE_IS_SEEKABLE   EQU 00000000000001000000000000000000y   ;// enable the seek buttons
        FILE_MODE_IS_READABLE   EQU 00000000000010000000000000000000y
        FILE_MODE_IS_WRITABLE   EQU 00000000000100000000000000000000y   ;// enable the write buttons
        ;// calc configuration
        FILE_MODE_IS_CALCABLE   EQU 00000000001000000000000000000000y   ;// this object is ready for action
        FILE_MODE_IS_SYNCABLE   EQU 00000000010000000000000000000000y   ;// can do seek sync
        FILE_MODE_IS_REWINDONLY EQU 00000000100000000000000000000000y   ;// can not do arbitrary seeks, don't show the norm/percent buttons
        ;// calc processing
        FILE_MODE_IS_REVERSABLE EQU 00000001000000000000000000000000y   ;// sr can be negative
        FILE_MODE_IS_STEREO     EQU 00000010000000000000000000000000y   ;// off for mono
        ;// clipping indicators
        FILE_MODE_IS_CLIPPING   EQU 00000100000000000000000000000000y   ;// calcs can set this
        FILE_MODE_WAS_CLIPPING  EQU 00001000000000000000000000000000y   ;// only file_Calc sets this
        FILE_MODE_IS_NOREWIND   EQU 00010000000000000000000000000000y   ;// don't rewind at start
        ;// no gates for text mode   
        FILE_MODE_NO_GATES      EQU 00100000000000000000000000000000y   ;// no gates for triggers
        ;// masking value                               
        FILE_MODE_IS_TEST       EQU 00111111111111111000000000000000y


;////////////////////////////////////////////////////////////////////////////////

;// calc flags are used by file_Calc_general and some by csvwriter_Calc
;// the bits that are masked out are copied from dwUser

        CALC_YES_SEEK           EQU 00000000000000001000000000000000y   ;// do a seek test
        CALC_ONE_SEEK           EQU 00000000000000010000000000000000y   ;// only do one seek test
        CALC_ALL_SEEK           EQU 00000000000000100000000000000000y   ;// seek is always triggered
        CALC_SAME_SEEK          EQU 00000100000000000000000000000000y   ;// set if P input is not changing
        
        CALC_YES_WRITE          EQU 00000000000001000000000000000000y   ;// do a write test
        CALC_ONE_WRITE          EQU 00000000000010000000000000000000y   ;// only do one write test
        CALC_ALL_WRITE          EQU 00000000000100000000000000000000y   ;// write is always triggered

        CALC_YES_MOVE           EQU 00000000001000000000000000000000y   ;// do a move test
        CALC_ONE_MOVE           EQU 00000000010000000000000000000000y   ;// only do one move test
        CALC_ALL_MOVE           EQU 00000000100000000000000000000000y   ;// move is always triggered
        
        ;// these two bits are copied from dwUser
        CALC_REVERSABLE         EQU 00000001000000000000000000000000y   ;// can have negative sample rates
        CALC_STEREO             EQU 00000010000000000000000000000000y   ;// off for mono
        .ERRNZ CALC_REVERSABLE-FILE_MODE_IS_REVERSABLE, <must be the same>
        .ERRNZ CALC_STEREO-FILE_MODE_IS_STEREO, <must be the same>

        CALC_LOUT_CHANGING      EQU 00001000000000000000000000000000y
        CALC_ROUT_CHANGING      EQU 00010000000000000000000000000000y
            
        CALC_HAVE_SEEKED        EQU 01000000000000000000000000000000y   ;// so we don't move
        CALC_POSITION_STUCK     EQU 10000000000000000000000000000000y   ;// so we do not read or write

        CALC_EARLY_OUT          EQU 00100000000000000000000000000000y   ;// force and early out 

        CALC_TEST               EQU 00000011000000000111111111111111y   ;// mask for dwuser
    





;///////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////
;//
;//
;//     now that were are hardware, we revamp the HARDWARE_DEVICEBLOCK

    FILE_HARDWARE_DEVICEBLOCK STRUCT
    
        ID          dd 0    ;// for opening the device, set by the H_Ctor       
        pBase       dd 0    ;// pointer to the osc_base class that manages this device
        slist_Declare_link hardwareFL,FILE_HARDWARE_DEVICEBLOCK ;// for iterating the list
        hDevice     dd 0    ;// handle to the device, null for a closed device

        numDevices  dd 0    ;// counts devices attached to this object, managed by hardware_AttachDevice and hardware_DetachDevice
        dwFlags     dd 0    ;// flags for this entry (see below)

        dlist_Declare_indirected file_hardware  ;// OSC_FILE_DATA
        ;// takes the place of 
        ;// pData       dd 0
        ;// num_buffers dd 0

        dwCount     dd  0   ;// countdown timer for the number of frames that elaspe before we try to open this device again

        szName  db 60+64 dup(0) ;// name of the device  ABOX233 added another 64 just in case

    FILE_HARDWARE_DEVICEBLOCK ENDS

    ;// we provide numerous compile time errors here

    .ERRNZ HARDWARE_DEVICEBLOCK.ID - FILE_HARDWARE_DEVICEBLOCK.ID
    .ERRNZ HARDWARE_DEVICEBLOCK.pBase - FILE_HARDWARE_DEVICEBLOCK.pBase
    .ERRNZ HARDWARE_DEVICEBLOCK.hDevice - FILE_HARDWARE_DEVICEBLOCK.hDevice
    .ERRNZ HARDWARE_DEVICEBLOCK.numDevices - FILE_HARDWARE_DEVICEBLOCK.numDevices
    .ERRNZ HARDWARE_DEVICEBLOCK.dwFlags - FILE_HARDWARE_DEVICEBLOCK.dwFlags
    .ERRNZ HARDWARE_DEVICEBLOCK.dwCount - FILE_HARDWARE_DEVICEBLOCK.dwCount

;//////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////
;///
;/// OSC_FILE_MAP for the file (needed to get to settings for each object)
;///

        OSC_FILE_MAP STRUCT

            OSC_OBJECT   {}
            pin_Lin APIN {}
            pin_Rin APIN {}
            pin_w   APIN {}
            pin_sr  APIN {}
            pin_m   APIN {}
            pin_s   APIN {}     ;// seek
            pin_P   APIN {}     ;// position input
            pin_Lout APIN {}
            pin_Rout APIN {}
            pin_Pout APIN {}    ;// added ABOX232
            pin_Sout APIN {}    ;// added ABOX234
            data_L  dd SAMARY_LENGTH DUP (?)
            data_R  dd SAMARY_LENGTH DUP (?)
            data_P  dd SAMARY_LENGTH DUP (?)    ;// added ABOX232
            data_S  dd SAMARY_LENGTH DUP (?)    ;// added ABOX234
            file    OSC_FILE_DATA   {}

        OSC_FILE_MAP ENDS

    ;// common data

        EXTERNDEF file_changing_name:DWORD      ;// prevents popup mixups

        EXTERNDEF file_available_modes:DWORD    ;// bits for available modes
        FILE_AVAILABLE_DATA     equ 00000001h   ;// bit position of FILE_MODE
        FILE_AVAILABLE_MEMORY   equ 00000002h
        FILE_AVAILABLE_READER   equ 00000004h
        FILE_AVAILABLE_WRITER   equ 00000008h
        
        FILE_AVAILABLE_CSVREADER equ 0000010h
        FILE_AVAILABLE_CSVWRITER equ 0000020h


    ;//
    ;// function prototypes
    ;//

    ;// Calc and PrePlay

        file_Calc           PROTO   STDCALL
        file_PrePlay        PROTO

    ;// file utility functions

        file_locate_name    PROTO
        file_ask_retry      PROTO STDCALL pObjectName:DWORD, pFILENAME:DWORD
        
    ;// data file access

        data_Open           PROTO
        data_SetLength      PROTO
        data_CheckState     PROTO
        data_GetBuffer      PROTO       
        data_Close          PROTO

    ;// memory buffer access, defined in memory_buffer.asm

        gmap_Initialize     PROTO
        gmap_Destroy        PROTO
        gmap_Open           PROTO       
        gmap_SetLength      PROTO
        gmap_CheckState     PROTO
        gmap_Close          PROTO

    ;// media reader access, defined in media_Reader.asm
        
        reader_Initialize   PROTO
        reader_Destroy      PROTO
        reader_Open         PROTO
        reader_CheckState   PROTO
        reader_GetBuffer    PROTO
        reader_Close        PROTO

    ;// wave writer access, defined in media_Writer.asm

        writer_Initialize   PROTO
        writer_Destroy      PROTO
        writer_Open         PROTO       
        writer_Calc PROTO STDCALL   ;// writer gets it's own calc so we can have better file length and position management
        writer_Close        PROTO

        writer_Flush PROTO
        writer_Prepare PROTO

    ;// common hardware functionality

        file_H_Ctor PROTO
        file_H_Dtor PROTO
        file_H_Open PROTO STDCALL pDevice:PTR FILE_HARDWARE_DEVICEBLOCK
        file_H_Close PROTO STDCALL pDevice:PTR FILE_HARDWARE_DEVICEBLOCK
        file_H_Ready PROTO
        file_H_Calc PROTO   ;// STDCALL pDevice:PTR FILE_HARDWARE_DEVICEBLOCK

    ;// csv file functions

        csvreader_Initialize    PROTO
        csvreader_Destroy       PROTO
        csvreader_Open          PROTO       
        csvreader_Calc PROTO    ;// reader gets its own calc
        csvreader_Close         PROTO

        csvreader_preparse  PROTO STDCALL hFile:DWORD
        ;// returns the number of cols and rows
        ;// writer needs to call this to get the size




        csvwriter_Initialize    PROTO
        csvwriter_Destroy       PROTO
        csvwriter_Open          PROTO       
        csvwriter_Close         PROTO

        csvwriter_Calc PROTO STDCALL    ;// writer gets its own calc



ENDIF   ;// ABOX_OSC_FILE_IS_INCLUDED




