;//                         
;// containers.inc          definitions of object containers
;//     

;// slist

    first_container         TEXTEQU <OFFSET knob_container.shape>

    next_knob_container     TEXTEQU <OFFSET noise_container.shape>
    next_noise_container    TEXTEQU <OFFSET r_rect_container.shape>
    next_r_rect_container   TEXTEQU <OFFSET circle_container.shape>
    next_circle_container   TEXTEQU <OFFSET dplex_container.shape>  
    next_dplex_container    TEXTEQU <OFFSET mplex_container.shape>  
    next_mplex_container    TEXTEQU <OFFSET devices_container.shape>
    next_devices_container  TEXTEQU <OFFSET filter_container.shape>
    next_filter_container   TEXTEQU <OFFSET prism_container.shape>
    next_prism_container    TEXTEQU <OFFSET fftop_container.shape>
    next_fftop_container    TEXTEQU <OFFSET button_container.shape>
    next_button_container   TEXTEQU <OFFSET display_palette.shape>
    next_display_palette    TEXTEQU <OFFSET iir_container.shape>
    next_iir_container      TEXTEQU <OFFSET qkey_container.shape>
    next_qkey_container     TEXTEQU <OFFSET sh_container.shape>
    next_sh_container       TEXTEQU <OFFSET mixer_container.shape>
    next_mixer_container    TEXTEQU <OFFSET slider_container_h.shape>
    next_slider_container_h TEXTEQU <OFFSET slider_container_v.shape>
    next_slider_container_v TEXTEQU <OFFSET pinint_container.shape>
    next_pinint_container   TEXTEQU <0>



;///////////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////////
;///
;///    predefined shapes and containers
;///

        EXTERNDEF shape_trig_both:GDI_SHAPE
        EXTERNDEF shape_trig_pos:GDI_SHAPE
        EXTERNDEF shape_trig_neg:GDI_SHAPE
        EXTERNDEF shape_gate_both:GDI_SHAPE
        EXTERNDEF shape_gate_pos:GDI_SHAPE
        EXTERNDEF shape_gate_neg:GDI_SHAPE
        
        EXTERNDEF shape_output_digital:GDI_SHAPE    ;// not used except for
        EXTERNDEF shape_output_bipolar:GDI_SHAPE    ;// button bitmaps
        
        EXTERNDEF shape_pin_font:GDI_SHAPE  ;// shape for filling font background
        EXTERNDEF shape_bus:GDI_SHAPE
        
        EXTERNDEF knob_shape_hover_in:GDI_SHAPE
        EXTERNDEF knob_shape_hover_out:GDI_SHAPE
        EXTERNDEF knob_shape_mask:GDI_SHAPE

        EXTERNDEF button_control:GDI_SHAPE
                
;///
;///    predefined shapes and containers
;///
;///////////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////////


    ;// trigger and gate shapes

        BMP_COMPOSITE_TAG
        BCOM_PALETTE_GROUP  0
        BCOM_SOURCE_FILE    vr\pins\trig_both.bmp
        BCOM_SOURCE_RECT    0,0,9,9
        BCOM_DEST_TL        TRIG_BOTH_PSOURCE, 40, 30

        BMP_COMPOSITE_TAG
        BCOM_PALETTE_GROUP  0
        BCOM_SOURCE_FILE    vr\pins\trig_pos.bmp
        BCOM_SOURCE_RECT    0,0,9,9
        BCOM_DEST_TL        TRIG_POS_PSOURCE, 50, 30

        BMP_COMPOSITE_TAG
        BCOM_PALETTE_GROUP  0
        BCOM_SOURCE_FILE    vr\pins\trig_neg.bmp
        BCOM_SOURCE_RECT    0,0,9,9
        BCOM_DEST_TL        TRIG_NEG_PSOURCE, 60, 30

        BMP_COMPOSITE_TAG
        BCOM_PALETTE_GROUP  0
        BCOM_SOURCE_FILE    vr\pins\gate_both.bmp
        BCOM_SOURCE_RECT    0,0,9,9
        BCOM_DEST_TL        GATE_BOTH_PSOURCE, 40, 40

        BMP_COMPOSITE_TAG
        BCOM_PALETTE_GROUP  0
        BCOM_SOURCE_FILE    vr\pins\gate_pos.bmp
        BCOM_SOURCE_RECT    0,0,9,9
        BCOM_DEST_TL        GATE_POS_PSOURCE, 50, 40

        BMP_COMPOSITE_TAG
        BCOM_PALETTE_GROUP  0
        BCOM_SOURCE_FILE    vr\pins\gate_neg.bmp
        BCOM_SOURCE_RECT    0,0,9,9
        BCOM_DEST_TL        GATE_NEG_PSOURCE, 60, 40

        BMP_COMPOSITE_TAG
        BCOM_PALETTE_GROUP  0
        BCOM_SOURCE_FILE    vr\pins\output_digital.bmp
        BCOM_SOURCE_RECT    0,0,9,9
        BCOM_DEST_TL        OUTPUT_DIGITAL_PSOURCE, 30, 30

        BMP_COMPOSITE_TAG
        BCOM_PALETTE_GROUP  0
        BCOM_SOURCE_FILE    vr\pins\output_bipolar.bmp
        BCOM_SOURCE_RECT    0,0,9,9
        BCOM_DEST_TL        OUTPUT_BIPOLAR_PSOURCE, 30, 40

    ;// HID values not already covered
    
        BMP_COMPOSITE_TAG
        BCOM_PALETTE_GROUP  0
        BCOM_SOURCE_FILE    vr\pins\hid_off.bmp
        BCOM_SOURCE_RECT    0,0,9,9
        BCOM_DEST_TL        HID_CONTROL_OFF_PSOURCE, 60, 20

        BMP_COMPOSITE_TAG
        BCOM_PALETTE_GROUP  0
        BCOM_SOURCE_FILE    vr\pins\hid_pos.bmp
        BCOM_SOURCE_RECT    0,0,9,9
        BCOM_DEST_TL        HID_CONTROL_POS_PSOURCE, 60, 10

        BMP_COMPOSITE_TAG
        BCOM_PALETTE_GROUP  0
        BCOM_SOURCE_FILE    vr\pins\hid_neg.bmp
        BCOM_SOURCE_RECT    0,0,9,9
        BCOM_DEST_TL        HID_CONTROL_NEG_PSOURCE, 60, 0

    ;// align button shapes

        BMP_COMPOSITE_TAG
        BCOM_PALETTE_GROUP  0
        BCOM_SOURCE_FILE    vr\align\1A.bmp
        BCOM_SOURCE_RECT    0   ,   60  ,   29  ,   89      
        BCOM_DEST_TL        ALIGN_ICON_1A_PSOURCE,  0   ,396

        BMP_COMPOSITE_TAG
        BCOM_PALETTE_GROUP  0
        BCOM_SOURCE_FILE    vr\align\2A.bmp
        BCOM_SOURCE_RECT    30  ,   60  ,   59  ,   89      
        BCOM_DEST_TL        ALIGN_ICON_2A_PSOURCE,  30  ,396

        BMP_COMPOSITE_TAG
        BCOM_PALETTE_GROUP  0
        BCOM_SOURCE_FILE    vr\align\3A.bmp
        BCOM_SOURCE_RECT    60  ,   60  ,   89  ,   89      
        BCOM_DEST_TL        ALIGN_ICON_3A_PSOURCE,  60  ,396

        BMP_COMPOSITE_TAG
        BCOM_PALETTE_GROUP  0
        BCOM_SOURCE_FILE    vr\align\4A.bmp
        BCOM_SOURCE_RECT    0   ,   30  ,   29  ,   59      
        BCOM_DEST_TL        ALIGN_ICON_4A_PSOURCE,  90  ,396

        BMP_COMPOSITE_TAG
        BCOM_PALETTE_GROUP  0
        BCOM_SOURCE_FILE    vr\align\6A.bmp
        BCOM_SOURCE_RECT    60  ,   30  ,   89  ,   59      
        BCOM_DEST_TL        ALIGN_ICON_6A_PSOURCE,  120 ,396

        BMP_COMPOSITE_TAG
        BCOM_PALETTE_GROUP  0
        BCOM_SOURCE_FILE    vr\align\7A.bmp
        BCOM_SOURCE_RECT    0   ,   0   ,   29  ,   29      
        BCOM_DEST_TL        ALIGN_ICON_7A_PSOURCE,  150 ,396

        BMP_COMPOSITE_TAG
        BCOM_PALETTE_GROUP  0
        BCOM_SOURCE_FILE    vr\align\8A.bmp
        BCOM_SOURCE_RECT    30  ,   0   ,   59  ,   29      
        BCOM_DEST_TL        ALIGN_ICON_8A_PSOURCE,  180 ,396

        BMP_COMPOSITE_TAG
        BCOM_PALETTE_GROUP  0
        BCOM_SOURCE_FILE    vr\align\9A.bmp
        BCOM_SOURCE_RECT    60  ,   0   ,   89  ,   29      
        BCOM_DEST_TL        ALIGN_ICON_9A_PSOURCE,  210 ,396
                                                                     

        BMP_COMPOSITE_TAG
        BCOM_PALETTE_GROUP  0
        BCOM_SOURCE_FILE    vr\align\1B.bmp
        BCOM_SOURCE_RECT    90  ,   60  ,   119 ,   89      
        BCOM_DEST_TL        ALIGN_ICON_1B_PSOURCE,  0   ,426

        BMP_COMPOSITE_TAG
        BCOM_PALETTE_GROUP  0
        BCOM_SOURCE_FILE    vr\align\2B.bmp
        BCOM_SOURCE_RECT    120 ,   60  ,   149 ,   89      
        BCOM_DEST_TL        ALIGN_ICON_2B_PSOURCE,  30  ,426

        BMP_COMPOSITE_TAG
        BCOM_PALETTE_GROUP  0
        BCOM_SOURCE_FILE    vr\align\3B.bmp
        BCOM_SOURCE_RECT    150 ,   60  ,   179 ,   89      
        BCOM_DEST_TL        ALIGN_ICON_3B_PSOURCE,  60  ,426

        BMP_COMPOSITE_TAG
        BCOM_PALETTE_GROUP  0
        BCOM_SOURCE_FILE    vr\align\4B.bmp
        BCOM_SOURCE_RECT    90  ,   30  ,   119 ,   59      
        BCOM_DEST_TL        ALIGN_ICON_4B_PSOURCE,  90  ,426

        BMP_COMPOSITE_TAG
        BCOM_PALETTE_GROUP  0
        BCOM_SOURCE_FILE    vr\align\6B.bmp
        BCOM_SOURCE_RECT    150 ,   30  ,   179 ,   59      
        BCOM_DEST_TL        ALIGN_ICON_6B_PSOURCE,  120 ,426

        BMP_COMPOSITE_TAG
        BCOM_PALETTE_GROUP  0
        BCOM_SOURCE_FILE    vr\align\7B.bmp
        BCOM_SOURCE_RECT    90  ,   0   ,   119 ,   29      
        BCOM_DEST_TL        ALIGN_ICON_7B_PSOURCE,  150 ,426

        BMP_COMPOSITE_TAG
        BCOM_PALETTE_GROUP  0
        BCOM_SOURCE_FILE    vr\align\8B.bmp
        BCOM_SOURCE_RECT    120 ,   0   ,   149 ,   29      
        BCOM_DEST_TL        ALIGN_ICON_8B_PSOURCE,  180 ,426

        BMP_COMPOSITE_TAG
        BCOM_PALETTE_GROUP  0
        BCOM_SOURCE_FILE    vr\align\9B.bmp
        BCOM_SOURCE_RECT    150 ,   0   ,   179 ,   29      
        BCOM_DEST_TL        ALIGN_ICON_9B_PSOURCE,  210 ,426
                                          



;// definitions

    include <knob\knob.inc>
    include <noise\noise.inc>
    include <r_rect\r_rect.inc>
    include <circle\circle.inc>

    include <t_left\dplex.inc>
    include <t_rite\mplex.inc>

    include <devices\devices.inc>
    include <oval\filter\filter.inc>
    include <prism\prism.inc>
    include <prism\fftop.inc>

    include <button\button.inc>
    include <button\control.inc>

    include <display_palette.inc>
    include <iir\iir.inc>
    include <qkey\qkey.inc>
    include <sh\sh.inc>
    include <mixer\mixer.inc>
    include <slider\slider_h.inc>
    include <slider\slider_v.inc>
    
    include <group\pinint.inc>

