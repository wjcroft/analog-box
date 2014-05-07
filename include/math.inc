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
;//             -- rearranged compare order in macro CLIPTEST_ONE to catch 
;//                'unordered' compare
;//				-- removed math_temp_1 and math_temp_2 -- affects several other files ...
;//				-- added math_bool_X functions
;//
;//##////////////////////////////////////////////////////////////////////////
;//
;//     math.inc
;//

;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
;///
;///        M A T H   T A B L E S   and V A L U E S
;///

;// MATH        implementation is in ABox_math.asm

    EXTERNDEF   app_fpu_control:DWORD   ;// defined in abox asm


;// by decree, a math table is always 8192 values
;// use these to manipulate a math table

    MATH_TABLE_LENGTH       equ 02000h
    MATH_TABLE_SIZE         equ MATH_TABLE_LENGTH * 4

    math_AdrMask2   equ MATH_TABLE_SIZE-1   ;// chops an address
    math_AdrMask    equ MATH_TABLE_SIZE-4   ;// chops and masks to DWORD boundry

    EXTERNDEF math_NormToOfs:REAL4
    EXTERNDEF math_OfsToNorm:REAL4
    EXTERNDEF math_RadToNorm:REAL4
    EXTERNDEF math_RadToOfs:REAL4
    EXTERNDEF math_NormToOfsPi:REAL4

    math_OfsQuarter equ MATH_TABLE_LENGTH
    math_OfsHalf    equ MATH_TABLE_LENGTH * 2

    math_AdrMask3   equ MATH_TABLE_LENGTH-1

    EXTERNDEF math_TableScale:REAL4

    EXTERNDEF math_pSin:DWORD
    EXTERNDEF math_pTri:DWORD
    EXTERNDEF math_pRamp1:DWORD
    EXTERNDEF math_pSquare1:DWORD
    EXTERNDEF math_pRamp2:DWORD
    EXTERNDEF math_pSquare2:DWORD
    EXTERNDEF math_pChromatic:DWORD
    EXTERNDEF math_pMidiNote:DWORD

    EXTERNDEF math_pNullPin:DWORD
    EXTERNDEF math_pNull:DWORD
    EXTERNDEF math_pPosOne:DWORD
    EXTERNDEF math_pNegOne:DWORD

;// these initialize and destroy all tables

    math_Initialize PROTO
    math_Destroy PROTO

;// these convert between linear and log scales

    math_log_lin PROTO  ;// converts a number on a log scale to it's linear(actual) value
    math_lin_log PROTO  ;// converts an actual value to its log representation

;// these are useful values

    EXTERNDEF math_neg_1:REAL4
    EXTERNDEF math_0:REAL4

    EXTERNDEF math_1_16:REAL4
    EXTERNDEF math_1_8:REAL4
    EXTERNDEF math_neg_1_8:REAL4
    EXTERNDEF math_1_4:REAL4
    EXTERNDEF math_1_2:REAL4
    EXTERNDEF math_neg_1_2:REAL4
    EXTERNDEF math_1_6:REAL4
    EXTERNDEF math_1_3:REAL4

    EXTERNDEF math_5_6:REAL4
    EXTERNDEF math_1:REAL4
    EXTERNDEF math_2:REAL4
    EXTERNDEF math_4:REAL4
    EXTERNDEF math_10:REAL4
    EXTERNDEF math_16:REAL4
    EXTERNDEF math_neg_16:REAL4

    EXTERNDEF math_32:REAL4
    EXTERNDEF math_1_32:REAL4
    EXTERNDEF math_42_2_3:REAL4
    EXTERNDEF math_64:REAL4
    EXTERNDEF math_100:REAL4
    EXTERNDEF math_1000:REAL4
    EXTERNDEF math_1_1000:REAL4
    EXTERNDEF math_1_64:REAL4
    EXTERNDEF math_1_10:REAL4
    EXTERNDEF math_neg_1_64:REAL4
    EXTERNDEF math_4_3:REAL4
    EXTERNDEF math_3:REAL4
    EXTERNDEF math_6_256:REAL4

    EXTERNDEF math_2_24:REAL4
    EXTERNDEF math_2_neg_24:REAL4

    EXTERNDEF math_1_pi:REAL4
    EXTERNDEF math_pi:REAL4
    EXTERNDEF math_pi_2:REAL4
    EXTERNDEF math_pi_3:REAL4

    EXTERNDEF math_1_2_1_2:REAL4

    EXTERNDEF math_44100:REAL4
    EXTERNDEF math_1_44100:REAL4

    EXTERNDEF math_1_44100_2_24:REAL4

    EXTERNDEF math_1_256:REAL4
    EXTERNDEF math_1_512:REAL4
    EXTERNDEF math_255:REAL4
    EXTERNDEF math_256:REAL4
    EXTERNDEF math_511:REAL4
    EXTERNDEF math_512:REAL4

    EXTERNDEF math_12:REAL4
    EXTERNDEF math_128:REAL4
    EXTERNDEF math_1_128:REAL4
    EXTERNDEF math_8192:REAL4
    EXTERNDEF math_1_16384:REAL4
    EXTERNDEF math_1_32768:REAL4
    EXTERNDEF math_32767:REAL4
    EXTERNDEF math_65536:REAL4
    EXTERNDEF math_2_neg_31:REAL4

    EXTERNDEF math_10_2_3:REAL4
    EXTERNDEF math_1_10_2_3:REAL4

    ;// EXTERNDEF math_OneOverSamAryLength:REAL4
    EXTERNDEF math_Million:REAL4
    EXTERNDEF math_Millionth:REAL4

    EXTERNDEF math_if_k1:REAL4
    EXTERNDEF math_if_k2:REAL4

    EXTERNDEF math_11_8820:REAL4
    EXTERNDEF math_1_12:REAL4
    EXTERNDEF math_1_1200:REAL4

    EXTERNDEF math_tanh_k:REAL4

    EXTERNDEF math_1024:REAL4
    EXTERNDEF math_neg1024:REAL4
    EXTERNDEF math_1_1024:REAL4

;// EXTERNDEF math_readout_decay:REAL4
    EXTERNDEF math_spectrum_adjust:REAL4

;// AJT ABOX242 -- not a good idea to do this under multiple threads
;//		status -- removed
;//    EXTERNDEF math_temp_1:DWORD
;//    EXTERNDEF math_temp_2:DWORD

    EXTERNDEF math_decay:REAL4
    EXTERNDEF math_linear_decay:REAL4
    EXTERNDEF math_average:REAL4

    EXTERNDEF math_reader_media_scale:REAL8
    EXTERNDEF math_reader_sample_scale:REAL8







;////////////////////////////////////////////////////////////////////
;//
;//
;//     V E C T O R    A R I T H M E T I C    F U N C T I O N S
;//
;//	register calls -- works with arrays of SAMARY_LENGTH (1024)
;//	in general: 
;//		all registers except ebp are destroyed
;//		fpu is assumed to be empty 
;//		or, as in case of ramp and bool, 
;//		hold input paremeters and nothing else
;//		all fpu regs will be destroyed
;//
;//	see implementation for further details
;//		
;//	naming convention:	(d=dynamic, s=static)
;//
;//     name    
;//		code	sym		reg		description				vector length
;//		----	---		---		-------------------		---------------
;//		dX		X[]		esi		ptr to X input data   	1024 floats
;//		sX		X		esi		ptr to X input data   	1 float
;//		dA		A[]		ebx		ptr to A input data   	1024 floats
;//		sA		A		ebx		ptr to A input data   	1 float
;//		dB		B[]		edx		ptr to B input data   	1024 floats
;//		sB		B		edx		ptr to B input data   	1 float
;//
;//				Y[]		edi		ptr to Y output data    1024 floats
;//
;//	example: math_muladd_dXsAdB	
;//			
;//		esi points to 1024 floats
;//		ebx points to 1 float
;//		edx points to 1024 floats
;//		output is stored to edi, which is 1024 floats
;//

	;////////////////////////////////////////////////////////////////////////	
	;// NUMERIC
	;//
	;// these functions output numeric values

	math_neg_dX		PROTO   ;// Y[] = - X[]

    math_add_dXdB   PROTO   ;// Y[] = X[]+B[]
    math_add_dXsB   PROTO   ;// Y[] = X[]+B

    math_sub_dXdB   PROTO   ;// Y[] = X[]-B[]
    math_sub_dXsB   PROTO   ;// Y[] = X[]-B
    math_sub_sXdB   PROTO   ;// Y[] = X - B[]

    math_mul_dXdA       PROTO   ;// Y[] = X[]*A[]
    math_mul_dXdA_neg   PROTO   ;// Y[] = - X[]*A[]
    math_mul_dXsA       PROTO   ;// Y[] = X[]*A
    math_mul_dXsA_neg   PROTO   ;// Y[] = - X[]*A

    math_muladd_dXdAdB  PROTO   ;// Y[] = X[]*A[] + B[]
    math_muladd_dXdAsB  PROTO   ;// Y[] = X[]*A[] + B
    math_muladd_dXsAdB  PROTO   ;// Y[] = X[]*A + B[]
    math_muladd_dXsAsB  PROTO   ;// Y[] = X[]*A + B

	;////////////////////////////////////////////////////////////////////////	
	;// RAMP
	;//
	;// output a linear ramp of values from start to stop (non-inclusive stop)
	;// FPU MUST HOLD start,stop -- the values will be destroyed

    math_ramp           PROTO   ;// Y[] = ramp(start to stop)
    math_ramp_add_dB    PROTO   ;// Y[] = ramp(start to stop) + B[]
    math_ramp_mul_dA    PROTO   ;// Y[] = ramp(start to stop) * A[]

	;////////////////////////////////////////////////////////////////////////	
	;// BOOLEAN
	;//
	;// these functions output boolean true,false values
	;// FPU MUST HOLD false,true -- the values will be destroyed
	;//
	;//	in ABOX, a boolean uses the sign bit for true/false
	;//		-1 is true
	;//		-0 is true
	;//		+0 is false
	;//		+1 is false

	math_bool_dX_ft PROTO		;// Y[] = bool( X[] )
		;//
		;// to get NOT, swap false,true in the FPU before calling
		;//
	math_bool_and_dXdB_ft PROTO	;// Y[] = bool( X[] ) AND bool ( B[] )
	math_bool_or_dXdB_ft PROTO	;// Y[] = bool( X[] ) OR  bool ( B[] )
	math_bool_xor_dXdB_ft PROTO	;// Y[] = bool( X[] ) XOR bool ( B[] )
		;//
		;// to get NAND, NOR, or XNOR, swap false,true in the FPU before calling
		;// sX and sB combinations not provided 
		;//		because they reduce to either a constant 
		;//		or to bool_dX or NOT bool_dX
		;//
	math_bool_lt_dXdB_ft PROTO	;// Y[] = bool( X[] < B[] )
	math_bool_lt_dXsB_ft PROTO	;// Y[] = bool( X[] < B   )
	math_bool_lt_sXdB_ft PROTO	;// Y[] = bool( X   < B[] )
		;//
		;// only lt is provided -- lte, gt and gte may be implemented as follows:
		;//
		;// name	eqivalent expression		how to implement
		;// -----	------------------------	---------------------------------------------
		;// _gte_   a >= b  ==  NOT( a < b )	swap false,true in the FPU before calling
		;// _gt_    a > b   ==  b < a			swap X and B registers before calling
		;//										(1)	if applicable, call dXsB instead of sXdB
		;//											or call sXdB instead of dXsB 
		;//											dXdB will work the same regardless 
		;// _lte_   a <= b  ==  NOT( b < a )	swap false,true in the FPU before calling
		;//										and swap X and B registers before calling
		;//											if applicable, also implement note (1)
		;//
	math_bool_eq_dXdB_ft PROTO	;// Y[] = bool( X[] == B[] )
	math_bool_eq_dXsB_ft PROTO	;// Y[] = bool( X[] == B   )
		;//	
		;//	to implement ne, swap false,true before calling


;//
;//
;//     V E C T O R    A R I T H M E T I C    F U N C T I O N S
;//
;//     register calls, see implementation
;//
;////////////////////////////////////////////////////////////////////




















;////////////////////////////////////////////////////////////////////
;//
;//
;//     M A C R O S
;//
;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
;///
;///     CLIP TEST      saves code space
;///
;///                    saturation if value is beyond +/- 1
;///                    can set a flag as well

CLIPTEST_ONE MACRO clip_flag

    ;// y0 must be in st(0)
    ;// returns the number to store in st(0)

    ;// requires TWO FREE registers

    ;// clip flag may be any incrementable value


    ;// method: fpu test against abs(value) and 1
    ;//         if clip, then determine the sign

    LOCAL no_clip

    ;// AJT ABOX242 rearranged compore order to catch 'unordered' compare
    fld st          ;// y y
    fabs            ;// y y
    fld1            ;// 1 y y
    xor eax, eax
    fucompp         ;// y
    fnstsw ax
    sahf
    ja no_clip

    ;// we clipped

    ftst        ;// check the sign
    fnstsw ax   ;// xfer to ax
    fstp st     ;// dump the value
    sahf        ;// xfer results to flags
    fld1        ;// load the staturate value
    .IF CARRY?  ;// negative ?
        fchs    ;// make it so
    .ENDIF

    IFNB <clip_flag>    ;// clip_flag specified ?
    inc clip_flag       ;// set it
    ENDIF

no_clip:

    ENDM



