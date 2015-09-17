;=========================================================================
; file : fb.inc
; 2010/06/01
; derived from  : linux-2.6.34/include/linux/fb.h
;=========================================================================
%ifndef _FB_INC
%define _FB_INC

; Definitions of frame buffers

%assign FB_MAX                  32      ; sufficient for now

; ioctls
;   0x46 is 'F'
%assign FBIOGET_VSCREENINFO     0x4600
%assign FBIOPUT_VSCREENINFO     0x4601
%assign FBIOGET_FSCREENINFO     0x4602
%assign FBIOGETCMAP             0x4604
%assign FBIOPUTCMAP             0x4605
%assign FBIOPAN_DISPLAY         0x4606
; 0x4607-0x460B are defined below
; %assign FBIOGET_MONITORSPEC   0x460C
; %assign FBIOPUT_MONITORSPEC   0x460D
; %assign FBIOSWITCH_MONIBIT    0x460E
%assign FBIOGET_CON2FBMAP       0x460F
%assign FBIOPUT_CON2FBMAP       0x4610
%assign FBIOBLANK               0x4611          ; arg: 0 or vesa level + 1
;%assign FBIOGET_VBLANK          _IOR('F', 0x12, struct fb_vblank)
%assign FBIO_ALLOC              0x4613
%assign FBIO_FREE               0x4614
%assign FBIOGET_GLYPH           0x4615
%assign FBIOGET_HWCINFO         0x4616
%assign FBIOPUT_MODEINFO        0x4617
%assign FBIOGET_DISPINFO        0x4618


%assign FB_TYPE_PACKED_PIXELS         0 ; Packed Pixels
%assign FB_TYPE_PLANES                1 ; Non interleaved planes
%assign FB_TYPE_INTERLEAVED_PLANES    2 ; Interleaved planes
%assign FB_TYPE_TEXT                  3 ; Text/attributes
%assign FB_TYPE_VGA_PLANES            4 ; EGA/VGA planes

%assign FB_AUX_TEXT_MDA          0 ; Monochrome text
%assign FB_AUX_TEXT_CGA          1 ; CGA/EGA/VGA Color text
%assign FB_AUX_TEXT_S3_MMIO      2 ; S3 MMIO fasttext
%assign FB_AUX_TEXT_MGA_STEP16   3 ; MGA Millenium I:text,attr,14 reserved bytes
%assign FB_AUX_TEXT_MGA_STEP8    4 ; other MGAs: text, attr,  6 reserved bytes
%assign FB_AUX_TEXT_SVGA_GROUP   8 ; 8-15: SVGA tileblit compatible modes
%assign FB_AUX_TEXT_SVGA_MASK    7 ; lower three bits says step
%assign FB_AUX_TEXT_SVGA_STEP2   8 ; SVGA text mode:text,attr
%assign FB_AUX_TEXT_SVGA_STEP4   9 ; SVGA text mode:text,attr,2 reserved bytes
%assign FB_AUX_TEXT_SVGA_STEP8  10 ; SVGA text mode:text,attr,6 reserved bytes
%assign FB_AUX_TEXT_SVGA_STEP16 11 ; SVGA text mode:text,attr,14 reserved bytes
%assign FB_AUX_TEXT_SVGA_LAST   15 ; reserved up to 15

%assign FB_AUX_VGA_PLANES_VGA4        0 ; 16 color planes (EGA/VGA)
%assign FB_AUX_VGA_PLANES_CFB4        1 ; CFB4 in planes (VGA)
%assign FB_AUX_VGA_PLANES_CFB8        2 ; CFB8 in planes (VGA)

%assign FB_VISUAL_MONO01              0 ; Monochr. 1=Black 0=White
%assign FB_VISUAL_MONO10              1 ; Monochr. 1=White 0=Black
%assign FB_VISUAL_TRUECOLOR           2 ; True color
%assign FB_VISUAL_PSEUDOCOLOR         3 ; Pseudo color (like atari)
%assign FB_VISUAL_DIRECTCOLOR         4 ; Direct color
%assign FB_VISUAL_STATIC_PSEUDOCOLOR  5 ; Pseudo color readonly

%assign FB_ACCEL_NONE                 0 ; no hardware accelerator
%assign FB_ACCEL_ATARIBLITT           1 ; Atari Blitter
%assign FB_ACCEL_AMIGABLITT           2 ; Amiga Blitter
%assign FB_ACCEL_S3_TRIO64            3 ; Cybervision64 (S3 Trio64)
%assign FB_ACCEL_NCR_77C32BLT         4 ; RetinaZ3 (NCR 77C32BLT)
%assign FB_ACCEL_S3_VIRGE             5 ; Cybervision64/3D (S3 ViRGE)
%assign FB_ACCEL_ATI_MACH64GX         6 ; ATI Mach 64GX family
%assign FB_ACCEL_DEC_TGA              7 ; DEC 21030 TGA
%assign FB_ACCEL_ATI_MACH64CT         8 ; ATI Mach 64CT family
%assign FB_ACCEL_ATI_MACH64VT         9 ; ATI Mach 64CT family VT class
%assign FB_ACCEL_ATI_MACH64GT        10 ; ATI Mach 64CT family GT class
%assign FB_ACCEL_SUN_CREATOR         11 ; Sun Creator/Creator3D
%assign FB_ACCEL_SUN_CGSIX           12 ; Sun cg6
%assign FB_ACCEL_SUN_LEO             13 ; Sun leo/zx
%assign FB_ACCEL_IMS_TWINTURBO       14 ; IMS Twin Turbo
%assign FB_ACCEL_3DLABS_PERMEDIA2    15 ; 3Dlabs Permedia 2
%assign FB_ACCEL_MATROX_MGA2064W     16 ; Matrox MGA2064W (Millenium)
%assign FB_ACCEL_MATROX_MGA1064SG    17 ; Matrox MGA1064SG (Mystique)
%assign FB_ACCEL_MATROX_MGA2164W     18 ; Matrox MGA2164W (Millenium II)
%assign FB_ACCEL_MATROX_MGA2164W_AGP 19 ; Matrox MGA2164W (Millenium II)
%assign FB_ACCEL_MATROX_MGAG100      20 ; Matrox G100 (Productiva G100)
%assign FB_ACCEL_MATROX_MGAG200      21 ; Matrox G200 (Myst, Mill, ...)
%assign FB_ACCEL_SUN_CG14            22 ; Sun cgfourteen
%assign FB_ACCEL_SUN_BWTWO           23 ; Sun bwtwo
%assign FB_ACCEL_SUN_CGTHREE         24 ; Sun cgthree
%assign FB_ACCEL_SUN_TCX             25 ; Sun tcx
%assign FB_ACCEL_MATROX_MGAG400      26 ; Matrox G400
%assign FB_ACCEL_NV3                 27 ; nVidia RIVA 128
%assign FB_ACCEL_NV4                 28 ; nVidia RIVA TNT
%assign FB_ACCEL_NV5                 29 ; nVidia RIVA TNT2
%assign FB_ACCEL_CT_6555x            30 ; C&T 6555x
%assign FB_ACCEL_3DFX_BANSHEE        31 ; 3Dfx Banshee
%assign FB_ACCEL_ATI_RAGE128         32 ; ATI Rage128 family
%assign FB_ACCEL_IGS_CYBER2000       33 ; CyberPro 2000
%assign FB_ACCEL_IGS_CYBER2010       34 ; CyberPro 2010
%assign FB_ACCEL_IGS_CYBER5000       35 ; CyberPro 5000
%assign FB_ACCEL_SIS_GLAMOUR         36 ; SiS 300/630/540
%assign FB_ACCEL_3DLABS_PERMEDIA3    37 ; 3Dlabs Permedia 3
%assign FB_ACCEL_ATI_RADEON          38 ; ATI Radeon family
%assign FB_ACCEL_I810                39 ; Intel 810/815
%assign FB_ACCEL_SIS_GLAMOUR_2       40 ; SiS 315, 650, 740
%assign FB_ACCEL_SIS_XABRE           41 ; SiS 330 ("Xabre")
%assign FB_ACCEL_I830                42 ; Intel 830M/845G/85x/865G
%assign FB_ACCEL_NV_10               43 ; nVidia Arch 10
%assign FB_ACCEL_NV_20               44 ; nVidia Arch 20
%assign FB_ACCEL_NV_30               45 ; nVidia Arch 30
%assign FB_ACCEL_NV_40               46 ; nVidia Arch 40
%assign FB_ACCEL_XGI_VOLARI_V        47 ; XGI Volari V3XT, V5, V8
%assign FB_ACCEL_XGI_VOLARI_Z        48 ; XGI Volari Z7
%assign FB_ACCEL_OMAP1610            49 ; TI OMAP16xx
%assign FB_ACCEL_TRIDENT_TGUI        50 ; Trident TGUI
%assign FB_ACCEL_TRIDENT_3DIMAGE     51 ; Trident 3DImage
%assign FB_ACCEL_TRIDENT_BLADE3D     52 ; Trident Blade3D
%assign FB_ACCEL_TRIDENT_BLADEXP     53 ; Trident BladeXP
%assign FB_ACCEL_CIRRUS_ALPINE       53 ; Cirrus Logic 543x/544x/5480
%assign FB_ACCEL_NEOMAGIC_NM2070     90 ; NeoMagic NM2070
%assign FB_ACCEL_NEOMAGIC_NM2090     91 ; NeoMagic NM2090
%assign FB_ACCEL_NEOMAGIC_NM2093     92 ; NeoMagic NM2093
%assign FB_ACCEL_NEOMAGIC_NM2097     93 ; NeoMagic NM2097
%assign FB_ACCEL_NEOMAGIC_NM2160     94 ; NeoMagic NM2160
%assign FB_ACCEL_NEOMAGIC_NM2200     95 ; NeoMagic NM2200
%assign FB_ACCEL_NEOMAGIC_NM2230     96 ; NeoMagic NM2230
%assign FB_ACCEL_NEOMAGIC_NM2360     97 ; NeoMagic NM2360
%assign FB_ACCEL_NEOMAGIC_NM2380     98 ; NeoMagic NM2380
%assign FB_ACCEL_PXA3XX              99 ; PXA3xx

%assign FB_ACCEL_SAVAGE4           0x80 ; S3 Savage4
%assign FB_ACCEL_SAVAGE3D          0x81 ; S3 Savage3D
%assign FB_ACCEL_SAVAGE3D_MV       0x82 ; S3 Savage3D-MV
%assign FB_ACCEL_SAVAGE2000        0x83 ; S3 Savage2000
%assign FB_ACCEL_SAVAGE_MX_MV      0x84 ; S3 Savage/MX-MV
%assign FB_ACCEL_SAVAGE_MX         0x85 ; S3 Savage/MX
%assign FB_ACCEL_SAVAGE_IX_MV      0x86 ; S3 Savage/IX-MV
%assign FB_ACCEL_SAVAGE_IX         0x87 ; S3 Savage/IX
%assign FB_ACCEL_PROSAVAGE_PM      0x88 ; S3 ProSavage PM133
%assign FB_ACCEL_PROSAVAGE_KM      0x89 ; S3 ProSavage KM133
%assign FB_ACCEL_S3TWISTER_P       0x8a ; S3 Twister
%assign FB_ACCEL_S3TWISTER_K       0x8b ; S3 TwisterK
%assign FB_ACCEL_SUPERSAVAGE       0x8c ; S3 Supersavage
%assign FB_ACCEL_PROSAVAGE_DDR     0x8d ; S3 ProSavage DDR
%assign FB_ACCEL_PROSAVAGE_DDRK    0x8e ; S3 ProSavage DDR-K

struc fb_fix_screeninfo
    .id:                resb   16   ; identification string eg "TT Builtin"
    .smem_start:        resq    1   ; Start of frame buffer mem
                                    ; (physical address)
    .smem_len:          resd    1   ; Length of frame buffer mem
    .type:              resd    1   ; see FB_TYPE_*
    .type_aux:          resd    1   ; Interleave for interleaved Planes
    .visual:            resd    1   ; see FB_VISUAL_*
    .xpanstep:          resw    1   ; zero if no hardware panning
    .ypanstep:          resw    1   ; zero if no hardware panning
    .ywrapstep:         resw    1   ; zero if no hardware ywrap
    .padding:           resw    1   ;  for alignment, jm 1/26/2001
    .line_length:       resd    1   ; length of a line in bytes
    .padding2           resd    1   ;  for alignment, jm 06/01/2010
    .mmio_start:        resq    1   ; Start of Memory Mapped I/O
                                    ; (physical address)
    .mmio_len:          resd    1   ; Length of Memory Mapped I/O
    .accel:             resd    1   ; Type of acceleration available
    .reserved:          resw    3   ; Reserved for future compatibility
    .padding3           resw    1   ;  for alignment, jm 06/01/2010
endstruc

; Interpretation of offset for color fields: All offsets are from the right,
; inside a "pixel" value, which is exactly 'bits_per_pixel' wide (means: you
; can use the offset as right argument to <<). A pixel afterwards is a bit
; stream and is written to video memory as that unmodified. This implies
; big-endian byte order if bits_per_pixel is greater than 8.

struc fb_bitfield
    .offset:            resd    1   ; beginning of bitfield
    .length:            resd    1   ; length of bitfield
    .msb_right:         resd    1   ; != 0 : Most significant bit is
                                    ; right
endstruc


%assign FB_NONSTD_HAM           1   ; Hold-And-Modify (HAM)
%assign FB_NONSTD_REV_PIX_IN_B  2   ; order of pixels in each byte is reversed

%assign FB_ACTIVATE_NOW         0   ; set values immediately (or vbl)
%assign FB_ACTIVATE_NXTOPEN     1   ; activate on next open
%assign FB_ACTIVATE_TEST        2   ; don't set, round up impossible
%assign FB_ACTIVATE_MASK       15   ; values
%assign FB_ACTIVATE_VBL        16   ; activate values on next vbl
%assign FB_CHANGE_CMAP_VBL     32   ; change colormap on vbl
%assign FB_ACTIVATE_ALL        64   ; change all VCs on this fb
%assign FB_ACTIVATE_FORCE     128   ; force apply even when no change
%assign FB_ACTIVATE_INV_MODE  256   ; invalidate videomode

%assign FB_ACCELF_TEXT          1   ; (OBSOLETE) see fb_info.flags and vc_mode

%assign FB_SYNC_HOR_HIGH_ACT    1   ; horizontal sync high active
%assign FB_SYNC_VERT_HIGH_ACT   2   ; vertical sync high active
%assign FB_SYNC_EXT             4   ; external sync
%assign FB_SYNC_COMP_HIGH_ACT   8   ; composite sync high active
%assign FB_SYNC_BROADCAST       16  ; broadcast video timings
                                    ; vtotal = 144d/288n/576i => PAL
                                    ; vtotal = 121d/242n/484i => NTSC
%assign FB_SYNC_ON_GREEN        32  ; sync on green

%assign FB_VMODE_NONINTERLACED  0   ; non interlaced
%assign FB_VMODE_INTERLACED     1   ; interlaced
%assign FB_VMODE_DOUBLE         2   ; double scan
%assign FB_VMODE_ODD_FLD_FIRST  4   ; interlaced: top line first
%assign FB_VMODE_MASK           255

%assign FB_VMODE_YWRAP          256 ; ywrap instead of panning
%assign FB_VMODE_SMOOTH_XPAN    512 ; smooth xpan possible (internally used)
%assign FB_VMODE_CONUPDATE      512 ; don't update x/yoffset

; * Display rotation support

%assign FB_ROTATE_UR      0
%assign FB_ROTATE_CW      1
%assign FB_ROTATE_UD      2
%assign FB_ROTATE_CCW     3

struc fb_var_screeninfo
    .xres:              resd    1   ; visible resolution
    .yres:              resd    1
    .xres_virtual:      resd    1   ; virtual resolution
    .yres_virtual:      resd    1
    .xoffset:           resd    1   ; offset from virtual to visible
    .yoffset:           resd    1   ; resolution
    .bits_per_pixel:    resd    1   ; guess what
    .grayscale:         resd    1   ; != 0 Graylevels instead of colors
    .red_offset:        resd    1   ; beginning of bitfield
    .red_length:        resd    1   ; length of bitfield
    .red_msb_right:     resd    1   ; != 0 : Most significant bit is
    .green_offset:      resd    1   ; beginning of bitfield
    .green_length:      resd    1   ; length of bitfield
    .green_msb_right:   resd    1   ; != 0 : Most significant bit is
    .blue_offset:       resd    1   ; beginning of bitfield
    .blue_length:       resd    1   ; length of bitfield
    .blue_msb_right:    resd    1   ; != 0 : Most significant bit is
    .transp_offset:     resd    1   ; beginning of bitfield
    .transp_length:     resd    1   ; length of bitfield
    .transp_msb_right:  resd    1   ; != 0 : Most significant bit is
    .nonstd:            resd    1   ; != 0 Non standard pixel format
    .activate:          resd    1   ; see FB_ACTIVATE_*
    .height:            resd    1   ; height of picture in mm
    .width:             resd    1   ; width of picture in mm
    .accel_flags:       resd    1   ; acceleration flags (hints)
    ; Timing: All values in pixclocks, except pixclock (of course)
    .pixclock:          resd    1   ; pixel clock in ps (pico seconds)
    .left_margin:       resd    1   ; time from sync to picture
    .right_margin:      resd    1   ; time from picture to sync
    .upper_margin:      resd    1   ; time from sync to picture
    .lower_margin:      resd    1
    .hsync_len:         resd    1   ; length of horizontal sync
    .vsync_len:         resd    1   ; length of vertical sync
    .sync:              resd    1   ; see FB_SYNC_*
    .vmode:             resd    1   ; see FB_VMODE_*
    .reserved:          resd    6   ; Reserved for future compatibility
endstruc

struc fb_cmap
    .start:             resd    1   ; First entry
    .len:               resd    1   ; Number of entries
    .red:               resd    1   ; Red values
    .green:             resd    1
    .blue:              resd    1
    .transp:            resd    1   ; transparency, can be NULL
endstruc

struc fb_con2fbmap
    .console:           resd    1;
    .framebuffer:       resd    1;
endstruc

; VESA Blanking Levels
%assign  VESA_NO_BLANKING        0
%assign  VESA_VSYNC_SUSPEND      1
%assign  VESA_HSYNC_SUSPEND      2
%assign  VESA_POWERDOWN          3

struc fb_monspecs
    .hfmin:             resd    1   ; hfreq lower limit (Hz)
    .hfmax:             resd    1   ; hfreq upper limit (Hz)
    .vfmin:             resw    1   ; vfreq lower limit (Hz)
    .vfmax:             resw    1   ; vfreq upper limit (Hz)
    .dpms:              resw    1   ; supports DPMS
endstruc

%assign  FB_VBLANK_VBLANKING     0x001   ; currently in a vertical blank
%assign  FB_VBLANK_HBLANKING     0x002   ; currently in a horizontal blank
%assign  FB_VBLANK_HAVE_VBLANK   0x004   ; vertical blanks can be detected
%assign  FB_VBLANK_HAVE_HBLANK   0x008   ; horizontal blanks can be detected
%assign  FB_VBLANK_HAVE_COUNT    0x010   ; global retrace counter is available
%assign  FB_VBLANK_HAVE_VCOUNT   0x020   ; the vcount field is valid
%assign  FB_VBLANK_HAVE_HCOUNT   0x040   ; the hcount field is valid
%assign  FB_VBLANK_VSYNCING      0x080   ; currently in a vsync
%assign  FB_VBLANK_HAVE_VSYNC    0x100   ; verical syncs can be detected

struc fb_vblank
    .flags:             resd    1   ; FB_VBLANK flags
    .count:             resd    1   ; counter of retraces since boot
    .vcount:            resd    1   ; current scanline position
    .hcount:            resd    1   ; current scandot position
    .reserved:          resd    4   ; reserved for future compatibility
endstruc

%assign  FBCMD_GET_CURRENTPAR    0xDEAD0005
%assign  FBCMD_SET_CURRENTPAR    0xDEAD8005

; Hardware Cursor

%assign  FBIOGET_FCURSORINFO     0x4607
%assign  FBIOGET_VCURSORINFO     0x4608
%assign  FBIOPUT_VCURSORINFO     0x4609
%assign  FBIOGET_CURSORSTATE     0x460A
%assign  FBIOPUT_CURSORSTATE     0x460B

struc fb_fix_cursorinfo
    .crsr_width:        resw    1   ; width and height of the cursor in
    .crsr_height:       resw    1   ; pixels (zero if no cursor)
    .crsr_xsize:        resw    1   ; cursor size in display pixels
    .crsr_ysize:        resw    1
    .crsr_color1:       resw    1   ; colormap entry for cursor color1
    .crsr_color2:       resw    1   ; colormap entry for cursor color2
endstruc

struc fb_var_cursorinfo
    .width:             resw    1
    .height:            resw    1
    .xspot:             resw    1
    .yspot:             resw    1
    .data:              resb    1   ; field with [height][width]
endstruc

struc fb_cursorstate
    .xoffset:           resw    1
    .yoffset:           resw    1
    .mode:              resw    1
endstruc

%assign  FB_CURSOR_OFF           0
%assign  FB_CURSOR_ON            1
%assign  FB_CURSOR_FLASH         2

%endif
