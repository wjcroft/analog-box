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
;//             -- portions transcibed from Microsoft header files.
;//
;// History:
;//
;//     2.41 Mar 04, 2011 AJT
;//         Initial port to GPLv3
;//
;//     ABOX242 AJT -- detabified
;//
;//     ABOX242 AJT -- added IMPORT_ME macro in order to build function tables with new masm and link
;//
;//##////////////////////////////////////////////////////////////////////////
;//
;//     win32A_HID.inc          Andy J Turner       Includes HID_ functions
;//                                                 and the SetupDi_ functions needed to get them
IFNDEF _WIN32A_HID_INCLUDED_
_WIN32A_HID_INCLUDED_ EQU 1


    
    INCLUDE <COM.INC>       ;// need definition of a GUID, IMPORT32, and NOIMPORT32

IFNDEF HID_NOLIBRARY
    INCLUDELIB setupapi.lib
    INCLUDELIB hid.lib
    
    ;ABOX242 AJT -- yes, do include the libs and set IMPORT_ME to import like normal
    IMPORT_ME MACRO name:req, args:VARARG
        IMPORT32 name, args
        ENDM
ELSE    ;// not supposed to import win functions

    ;ABOX242 AJT -- don't include the libs and redefine import so function tables work in later link
    IMPORT_ME MACRO name:req, args:VARARG
        NOIMPORT32 name, args
        ENDM
    
ENDIF



;///    information was also obtained from http://www.osr.com/ddk/intinput/iidhdr_1sx3.htm
;///    NOTE that the data presented by osr.com appears to be far more accurate than the 
;///         than the older 1997/1998 MSDN/WIN98DDK documentation
;///
;///    SetupDi_    !!! my word the docementation is hard to find on these !!!
;///                Platform, SDK and DDK Documentation
;///                    Windows NT 4.0 DDK
;///                        Programmers Guide
;///                            2.4 Setup Functions
;///                                2.4.3 Device Installation Functions Reference
;///
;///        from setupapi.h FROM WIN98DDK !!!
;///        VC version does not have all the stuff
;///
;///    Hid_        also from the Win98DDK
;///                for better documentation, see the osr seriries of web pages
;///



    ;// there are several assumed sizes for data
    ;// these are catalogged here

    comment ~ 
        
            #define ANYSIZE_ARRAY 1       
            typedef USHORT USAGE, *PUSAGE;
            typedef BYTE  BOOLEAN;           

    comment ~




;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;///
;///    HidP                NTSTATUS is returned by HidP functions
;///    ERROR CODES         these define what they are
;///                        in general, sucess can be determined by the sign flags
;///                        from Hidpi.h

        HIDP_STATUS_SUCCESS                  EQU 000110000h
        HIDP_STATUS_NULL                     EQU 080110001h
        HIDP_STATUS_INVALID_PREPARSED_DATA   EQU 0C0110001h
        HIDP_STATUS_INVALID_REPORT_TYPE      EQU 0C0110002h
        HIDP_STATUS_INVALID_REPORT_LENGTH    EQU 0C0110003h
        HIDP_STATUS_USAGE_NOT_FOUND          EQU 0C0110004h
        HIDP_STATUS_VALUE_OUT_OF_RANGE       EQU 0C0110005h
        HIDP_STATUS_BAD_LOG_PHY_VALUES       EQU 0C0110006h
        HIDP_STATUS_BUFFER_TOO_SMALL         EQU 0C0110007h
        HIDP_STATUS_INTERNAL_ERROR           EQU 0C0110008h
        HIDP_STATUS_I8242_TRANS_UNKNOWN      EQU 0C0110009h
        HIDP_STATUS_INCOMPATIBLE_REPORT_ID   EQU 0C011000Ah
        HIDP_STATUS_NOT_VALUE_ARRAY          EQU 0C011000Bh
        HIDP_STATUS_IS_VALUE_ARRAY           EQU 0C011000Ch
        HIDP_STATUS_DATA_INDEX_NOT_FOUND     EQU 0C011000Dh
        HIDP_STATUS_DATA_INDEX_OUT_OF_RANGE  EQU 0C011000Eh
        HIDP_STATUS_BUTTON_NOT_PRESSED       EQU 0C011000Fh
        HIDP_STATUS_REPORT_DOES_NOT_EXIST    EQU 0C0110010h
        HIDP_STATUS_NOT_IMPLEMENTED          EQU 0C0110020h


;///
;///                        NTSTATUS is returned by several functions
;///    ERROR CODES         these define what they are
;///                        in general, sucess can be determined by the sign flags
;///                        from Hidpi.h
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////












;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;///
;///
;///    INITIALIZATION AND LOCATING HID DEVICES
;///
;/// After a user-mode application is loaded, it does the following sequence of operations: 


;// Calls HidD_GetHidGuid to obtain the system-defined GUID for HIDClass devices. 

        IMPORT_ME HidD_GetHidGuid, pHidGuid
        ;// HidD_GetHidGuid returns the GUID associated with HID devices.


;// Calls SetupDiGetClassDevs to obtain a handle to an opaque device information set that 
;// describes the device interfaces supported by all the HID collections currently installed 
;// in the system. The application should specify DIGCF_PRESENT and DIGCF_INTERFACEDEVICE in 
;// the Flags parameter passed to SetupDiGetClassDevs. 


        ;//
        ;// Flags controlling what is included in the device information set built
        ;// by SetupDiGetClassDevs
        ;//
        DIGCF_DEFAULT           EQU 00000001h  ;// only valid with DIGCF_DEVICEINTERFACE
        DIGCF_PRESENT           EQU 00000002h
        DIGCF_ALLCLASSES        EQU 00000004h
        DIGCF_PROFILE           EQU 00000008h
        DIGCF_DEVICEINTERFACE   EQU 00000010h

        IMPORT_ME SetupDiGetClassDevsA, pClassGuid, pszEnumerator, hwndParent, dwFlags
        ;// returns HDEVINFO

        IMPORT_ME SetupDiDestroyDeviceInfoList, hDeviceInfoSet  ;// --AJT--- and don't forget to destroy the device info set

;// Calls SetupDiEnumDeviceInterfaces repeatedly to retrieve all the available interface information. 

        ;//
        ;// Device information structure (references a device instance
        ;// that is a member of a device information set)
        ;//
        SP_DEVINFO_DATA STRUCT
            cbSize      dd  SIZEOF SP_DEVINFO_DATA  ;
            ClassGuid   GUID  {}                    ;
            DevInst     dd  0                       ;// DEVINST handle
            Reserved    dd  0                       ;
        SP_DEVINFO_DATA ENDS



        ;//
        ;// Device interface information structure (references a device
        ;// interface that is associated with the device information
        ;// element that owns it).
        ;//
        SP_DEVICE_INTERFACE_DATA STRUCT
            cbSize      dd  SIZEOF  SP_DEVICE_INTERFACE_DATA    ;
            InterfaceClassGuid  GUID  {}    ;
            dwFlags     dd  0   ;
            dwReserved  dd  0   ;
        SP_DEVICE_INTERFACE_DATA ENDS

        ;//
        ;// Flags for SP_DEVICE_INTERFACE_DATA.Flags field.
        ;//
        SPINT_ACTIVE  EQU 00000001h
        SPINT_DEFAULT EQU 00000002h
        SPINT_REMOVED EQU 00000004h

        ;//
        ;// Backward compatibility--do not use.
        ;//
        ;//typedef SP_DEVICE_INTERFACE_DATA  SP_INTERFACE_DEVICE_DATA;
        ;//typedef PSP_DEVICE_INTERFACE_DATA PSP_INTERFACE_DEVICE_DATA;
        ;//#define SPID_ACTIVE               SPINT_ACTIVE
        ;//#define SPID_DEFAULT              SPINT_DEFAULT
        ;//#define SPID_REMOVED              SPINT_REMOVED

        IMPORT_ME SetupDiEnumDeviceInterfaces,hDeviceInfoSet,pDeviceInfoData,pInterfaceClassGuid,dwMemberIndex,pDeviceInterfaceData
        ;// returns BOOL
        ;// WINSETUPAPI
        ;// BOOL
        ;// WINAPI
        ;// SetupDiEnumDeviceInterfaces(
        ;//     IN  HDEVINFO                  DeviceInfoSet,
        ;//     IN  PSP_DEVINFO_DATA          DeviceInfoData,     OPTIONAL
        ;//     IN  LPGUID                    InterfaceClassGuid,
        ;//     IN  DWORD                     MemberIndex,
        ;//     OUT PSP_DEVICE_INTERFACE_DATA DeviceInterfaceData
        ;//     );



;// Calls SetupDiGetDeviceInterfaceDetail to format interface information for each collection as 
;// a SP_INTERFACE_DEVICE_DETAIL_DATA structure. The DevicePath member of this structure contains 
;// the user-mode name that the application uses with the Win32® function CreateFile to obtain a 
;// file handle to a HID collection. 

        SP_DEVICE_INTERFACE_DETAIL_DATA_A STRUCT
            cbSize  dd  0
            ;// CHAR   DevicePath[ANYSIZE_ARRAY];   data follows
        SP_DEVICE_INTERFACE_DETAIL_DATA_A ENDS
        ;// ALWAYS set cbSize as 5, even though it is longer


        IMPORT_ME SetupDiGetDeviceInterfaceDetailA, hDeviceInfoSet,pDeviceInterfaceData,pDeviceInterfaceDetailData,dwDeviceInterfaceDetailDataSize,pRequiredSize,pDeviceInfoData
        ;// returns BOOL unless asking for size

        ;// WINSETUPAPI
        ;// BOOL
        ;// WINAPI
        ;// SetupDiGetDeviceInterfaceDetailA(
        ;//     IN  HDEVINFO                           DeviceInfoSet,
        ;//     IN  PSP_DEVICE_INTERFACE_DATA          DeviceInterfaceData,
        ;//     OUT PSP_DEVICE_INTERFACE_DETAIL_DATA_A DeviceInterfaceDetailData,     OPTIONAL
        ;//     IN  DWORD                              DeviceInterfaceDetailDataSize,
        ;//     OUT PDWORD                             RequiredSize,                  OPTIONAL
        ;//     OUT PSP_DEVINFO_DATA                   DeviceInfoData                 OPTIONAL
        ;//     );


;// Calls CreateFile to obtain a file handle to a HID collection. 

;// After any HID client has made a connection to the top-level collection for an underlying 
;// HID device, the client first retrieves the capability data and other information about the 
;// device before any doing any runtime data input or output on that device.

;// Each HID device has a discrete set of preparsed data that describes the device's 
;// capabilities and operations to the system's HID components. Before calling any other 
;// system-supplied HID routine, user-mode clients must obtain this preparsed data for the 
;// HID device. 


        IMPORT_ME HidD_GetPreparsedData, hHidDeviceObject, ppPreparsedData
       
        IMPORT_ME HidD_FreePreparsedData, ppPreparsedData


;// --ajt-- use these to find out about who makes device

        HIDD_ATTRIBUTES STRUCT
            dwSize          dd  SIZEOF HIDD_ATTRIBUTES  ; // = sizeof (struct _HIDD_ATTRIBUTES)         
            VendorID        dw  0   ;// Vendor ids of this hid device
            ProductID       dw  0   ;
            VersionNumber   dw  0   ;
            ;// Additional fields will be added to the end of this structure.
            
        HIDD_ATTRIBUTES ENDS

        IMPORT_ME HidD_GetAttributes, hHidDeviceObject, pHIDD_ATTRIBUTES
        ;// returns non zero for sucess

        IMPORT_ME HidD_GetProductString, hHidDeviceObject, pBuffer, dwBufferLength
        ;// returns non zero for sucess

        IMPORT_ME HidD_GetManufacturerString, hHidDeviceObject,pBuffer,dwBufferLength
        ;// returns non zero for sucess

        IMPORT_ME  HidD_GetPhysicalDescriptor, hHidDeviceObject, pBuffer, dwBufferLength
        ;// returns non zero for sucess


;// After a client has obtained the preparsed data for the underlying HID device, it first calls 
;// HidP_GetCaps, which returns a HIDP_CAPS structure for the top-level collection. The returned 
;// information includes the usage page and usage identifiers for the top-level collection, so the 
;// client can identify which top-level collections it will continue processing subsequently. The 
;// client can immediately disconnect itself from any top-level collection that is not of interest 
;// to that client, as well.

            

        HIDP_CAPS STRUCT                        ;// Declared in hidpi.h

            wUsage                  dw ?    ;// see HID_USAGE_PAGE_GENERIC below
            wUsagePage              dw ?    ;// see HID_USAGE_GENERIC_POINTER

            wInputReportByteLength  dw ?    ;// Specifies the maximum size, in bytes, of all the 
                                            ;// input reports (including the report ID, if report IDs
                                            ;// are used, which is prepended to the report data). 
            wOutputReportByteLength dw ?    ;// Specifies the maximum size, in bytes, of all the output reports (including the report ID, if report IDs are used, which is prepended to the report data). 
            wFeatureReportByteLength dw ?   ;// Specifies the maximum length, in bytes, of all the feature reports (including the report ID, if report IDs are used, which is prepended to the report data). 

            wReserved           dw 17 DUP (?)   ;// Reserved for internal system use

            wNumberLinkCollectionNodes dw ? ;// Specifies the number of HIDP_LINK_COLLECTION_NODE structures that are returned for this top-level collection by HidP_GetLinkCollectionNodes. 

            wNumberInputButtonCaps  dw ?    ;// Specifies the number of input HIDP_BUTTON_CAPS structures that HidP_GetButtonCaps returns
            wNumberInputValueCaps   dw ?    ;// Specifies the number of input HIDP_VALUE_CAPS structures that HidP_GetValueCaps returns
            wNumberInputDataIndices dw ?    ;// Specifies the number of data indices assigned to 
                                            ;// buttons and values in all input reports

            wNumberOutputButtonCaps dw ?    ;// Specifies the number of output HIDP_BUTTON_CAPS structures that HidP_GetButtonCaps returns. 
            wNumberOutputValueCaps  dw ?    ;// Specifies the number of output HIDP_VALUE_CAPS structures that HidP_GetValueCaps returns
            wNumberOutputDataIndices dw ?   ;// Specifies the number of data indices assigned to buttons and values in all output reports

            wNumberFeatureButtonCaps dw ?   ;// Specifies the total number of feature HIDP_BUTTONS_CAPS structures that HidP_GetButtonCaps returns
            wNumberFeatureValueCaps dw ?    ;// Specifies the total number of feature HIDP_VALUE_CAPS structures that HidP_GetValueCaps returns
            wNumberFeatureDataIndices dw ?  ;// Specifies the number of data indices assigned to buttons and values in all feature reports

        HIDP_CAPS   ENDS


        IMPORT_ME HidP_GetCaps, pPreparsedData, pHIDP_CAPS
        ;// returns NTSTATUS

;// After examining the usage page and usage identifiers for a particular top-level collection and 
;// determining that this connection is of interest, the client next obtains the capabilities of 
;// each button and value in that collection by calling one or more of the following support routines: 

        ;// --ajt-- to get reports, a HIDP_REPORT_TYPE must be used

        ;// typedef enum _HIDP_REPORT_TYPE {
            
            HidP_Input      EQU     0
            HidP_Output     EQU     1
            HidP_Feature    EQU     2

        ;// button and value caps may contain either type of hese members

            HCAPS_RANGE STRUCT  

                wUsageMin       dw  0   ;// Indicates the inclusive lower bound of usage range 
                wUsageMax       dw  0   ;// whose inclusive upper bound is specified by Range.UsageMax. 
                wStringMin      dw  0   ;// Indicates the inclusive lower bound of a range of string descriptors (specified by string minimum and string maximum items) 
                wStringMax      dw  0   ;// whose inclusive upper bound is indicated by Range.StringMax. 
                wDesignatorMin  dw  0   ;// Indicates the inclusive lower bound of a range of designators (specified by designator minimum and designator maximum items) 
                wDesignatorMax  dw  0   ;// whose inclusive upper bound is indicated by Range.DesignatorMax
                wDataIndexMin   dw  0   ;// Indicates the inclusive lower bound of a sequential range of data indices that correspond, one-to-one and in the same order, 
                wDataIndexMax   dw  0   ;// to the usages specified by the usage range Range.UsageMin to Range.UsageMax. 

            HCAPS_RANGE ENDS

            HCAPS_NOTRANGE STRUCT

                wUsage          dw  0   ;// Specifies the usage identifier for this button
                wReserved1      dw  0
                wStringIndex    dw  0   ;// Specifies a string index identifier for this button
                wReserved2      dw  0
                wDesignatorIndex dw 0   ;// Specifies a designator identifier for this button
                wReserved3      dw  0
                wDataIndex      dw  0   ;// Indicates the data index of the usage specified by NotRange.Usage. 
                wReserved4      dw  0

            HCAPS_NOTRANGE ENDS

        ;// --ajt-- although not specifically declared, each CAPS struct has an identical header

            HCAPS_HEADER STRUCT

                wUsagePage      dw  0   ;// Specifies the usage page for a usage or usage range
                wReportID       db  0   ;// Specifies the report ID of the HID report that contains 
                                        ;// the usage or usage range.               
                bIsAlias        db  0   ;// Indicates, if TRUE, that a button has a set of aliased 
                                        ;// usages. Otherwise, if IsAlias is FALSE, the button has 
                                        ;// only one usage
                wBitField       dw  0   ;// Contains the data fields (one or two bytes) associated 
                                        ;// with an input, output, or feature main item (can ignore)                
                wLinkCollection dw  0   ;// Specifies the index of the link collection in a top-level 
                                        ;// collection's link collection array that contains the 
                                        ;// usage or usage range. If LinkCollection is zero, the 
                                        ;// usage or usage range is contained in the top-level 
                                        ;// collection. 
                wLinkUsage      dw  0   ;// Specifies the usage of the link collection that contains 
                                        ;// the usage or usage range. If LinkCollection is zero, 
                                        ;// LinkUsage specifies the usage of the top-level collection
                wLinkUsagePage  dw  0   ;// Specifies the usage page of the link collection that 
                                        ;// contains the usage or usage range. If LinkCollection is 
                                        ;// zero, LinkUsagePage specifies the usage page of the 
                                        ;// top-level collection.               
                bIsRange        db  0   ;// Specifies, if TRUE, that the structure describes a usage 
                                        ;// range. Otherwise, if IsRange is FALSE, the structure 
                                        ;// describes a single usage. 
                bIsStringRange  db  0   ;// Specifies, if TRUE, that the usage or usage range has a 
                                        ;// set of string descriptors. Otherwise, if IsStringRange 
                                        ;// is FALSE, the usage or usage range has zero or one 
                                        ;// string descriptor. 
                bIsDesignatorRange db 0 ;// Specifies, if TRUE, that the usage or usage range has a 
                                        ;// set of designators. Otherwise, if IsDesignatorRange is 
                                        ;// FALSE, the usage or usage range has zero or one 
                                        ;// designator. 
                bIsAbsolute     db  0   ;// Specifies, if TRUE, that the button usage or usage range 
                                        ;// provides absolute data. Otherwise, if IsAbsolute is FALSE
                                        ;// the button data is the change in state from the previous 
                                        ;// value. 
            HCAPS_HEADER ENDS


;// HidP_GetButtonCaps 
;// To retrieve the button capability data for all buttons in a given type of report. 

            HIDP_BUTTON_CAPS    STRUCT
                
                HCAPS_HEADER    {}      ;// see above
                
                dwReserved dd 10 DUP (0);// Reserved for internal system use
                
                UNION
                    Range    HCAPS_RANGE {} ;// Specifies, if IsRange is TRUE, information about a usage range. Otherwise, if IsRange is FALSE, NotRange contains information about a single usage. 
                    NotRange HCAPS_NOTRANGE {};// Specifies, if IsRange is FALSE, information about a single usage. Otherwise, if IsRange is TRUE, Range contains information about a usage range. 
                ENDS

            HIDP_BUTTON_CAPS    ENDS


            IMPORT_ME HidP_GetButtonCaps, dwReportType,pHIDP_BUTTON_CAPS,pdwButtonCapsLength,pPreparsedData
            ;// returns NTSTATUS


;// HidP_GetSpecificButtonCaps 
;// To retrieve the button capability data for all buttons of a specific usage page, usage, 
;// or link collection or any combination of the above for a given type of report. 

    ;// HidP_GetSpecificButtonCaps



;// HidP_GetValueCaps 
;// To retrieve the value capability data for all values in a given type of report. 


            HIDP_VALUE_CAPS STRUCT
                
                HCAPS_HEADER    {}      ;// see above
                
                bHasNull        db  0   ;// Specifies, if TRUE, that the usage supports a NULL value,
                                        ;// which indicates that the data is not valid and should be 
                                        ;// ignored. Otherwise, if HasNull is FALSE, the usage does 
                                        ;// not have a NULL value. 
                bReserved       db  0   ;// Reserved for internal system use
                wBitSize        dw  0   ;// Specifies the size, in bits, of a usage's data field 
                                        ;// in a report. If ReportCount is greater than one, each 
                                        ;// usage has a separate data field of this size. 
                wReportCount    dw  0   ;// Specifies the number of usages that this structure describes
                
                wReserved2 dw 5 DUP (0) ;// Reserved for internal system use. 
                
                dwUnitsExp      dd  0   ;// Specifies the usage's exponent, as described by the USB HID Standard. 
                dwUnits         dd  0   ;// Specifies the usage's units, as described by the USB HID Standard
                
                dwLogicalMin    dd  0   ;// Specifies a usage's signed lower bound. 
                dwLogicalMax    dd  0   ;// Specifies a usage's signed upper bound
                
                dwPhysicalMin   dd  0   ;// Specifies a usage's signed lower bound after scaling is applied to the logical minimum value
                dwPhysicalMax   dd  0   ;// Specifies a usage's signed upper bound after scaling is applied to the logical maximum value. 
                
                UNION
                    Range    HCAPS_RANGE {} ;// Specifies, if IsRange is TRUE, information about a usage range. Otherwise, if IsRange is FALSE, NotRange contains information about a single usage. 
                    NotRange HCAPS_NOTRANGE {};// Specifies, if IsRange is FALSE, information about a single usage. Otherwise, if IsRange is TRUE, Range contains information about a usage range. 
                ENDS

            HIDP_VALUE_CAPS ENDS


            IMPORT_ME HidP_GetValueCaps, dwReportType,pHIDP_VALUE_CAPS,pValueCapsLength,pPreparsedData
            ;// returns NTSTATUS

;// HidP_GetSpecificValueCaps 
;// To retrieve the value capability data for all values that match a specific usage page, usage, 
;// or link collection or any combination of the above for a given type of report. 


    ;// HidP_GetSpecificValueCaps


    ;// HidP_MaxUsageListLength



;///
;///    INITIALIZATION AND LOCATING HID DEVICES
;///
;///
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////



;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////
;///
;///
;///    GETTING and PROCESSING REPORT DATA
;///


        ;// If the top-level collection includes report IDs, 
        ;// the caller must set the first byte of the buffer to a nonzero report ID; 
        ;// otherwise the caller must set the first byte to zero. 

        ;// NOT AVAILABLE UNDER WIN98 !!
        ;// IMPORT_ME HidD_GetInputReport, hHidDeviceObject,pReportBuffer,dwReportBufferLength
        ;// returns a bool
        ;// use read file instead, have to use the hEvent to determine if data is available

        IMPORT_ME HidD_GetFeature, hHidDeviceObject,pReportBuffer,pReportBufferLength
        ;// returns a bool



        ;// the report data is packed according to the HIDP_CAPS indexes and what not
        ;// we are able to build the data by inspection of the indexes and sizes
        ;// but the hid parser apparently can do this for us
        ;// so we can use the following to parse the data for us


        IMPORT_ME HidP_MaxDataListLength, dwReportType,pPreparsedData
        ;// returns the max number of HIDP_DATA structs that an be returned

        HIDP_DATA STRUCT

            wDataIndex  dw  0   ;
            wReserved   dw  0   ;       
            dwValue     dd  0   ;// note that for buttons we MAY need to ignore the top word

        HIDP_DATA ENDS

    
        IMPORT_ME HidP_GetData, dwReportType, pDataList, pDataLength, pPreparsedData, pReport, pReportLength
        ;// returns NTSTATUS
        ;// apparently does not exist prior to windows 2000    






        IMPORT_ME HidD_FlushQueue, hHidDeviceObject
        ;//BOOLEAN
    
        IMPORT_ME HidD_GetNumInputBuffers, hHidDeviceObject, pNumberBuffers
        ;// BOOLEAN













;///
;///
;///
;///
;//////////////////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////////////////













ENDIF ;// _WIN32A_HID_INCLUDED_