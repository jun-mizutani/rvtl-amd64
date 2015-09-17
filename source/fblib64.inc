;-------------------------------------------------------------------------
;  file : fblib64.inc
;  2010/06/23
;  Copyright (C) 2001-2010  Jun Mizutani <mizutani.jun@nifty.ne.jp>
;-------------------------------------------------------------------------

%include    "fb64.inc"
%include    "mman64.inc"

%assign O_RDWR               02q

;==============================================================
section .text

;-------------------------------------------------------------------------
; フレームバッファのデバイスファイルをオープン
;-------------------------------------------------------------------------
fbdev_open:
                mov     eax, SYS_open       ; /dev/fb0 のオープン
                lea     rdi, [fb_device]
                mov     esi, O_RDWR
                syscall
                mov     [fb_desc], rax      ; /dev/fb0 の fd を保存
                test    rax, rax
                ret
fb_device       db      "/dev/fb0", 0
                align   8

;-------------------------------------------------------------------------
; フレームバッファのデバイスファイルをクローズ
;-------------------------------------------------------------------------
fbdev_close:
                mov     eax, SYS_close       ; /dev/fb0
                mov     rdi, [fb_desc]
                syscall
                ret

;-------------------------------------------------------------------------
; フレームバッファの物理状態を取得
;-------------------------------------------------------------------------
fb_get_fscreen:
                mov     eax, SYS_ioctl
                mov     rdi, [fb_desc]
                mov     esi, FBIOGET_FSCREENINFO
                lea     rdx, [fscinfo]      ; 保存先指定
                syscall
                test    rax, rax
                ret

;-------------------------------------------------------------------------
; 現在のフレームバッファの状態を保存
;-------------------------------------------------------------------------
fb_get_screen:
                mov     eax, SYS_ioctl
                mov     rdi, [fb_desc]
                mov     esi, FBIOGET_VSCREENINFO
                lea     rdx, [scinfo_save]  ; 保存先指定
                syscall
                test    rax, rax
                ret

;-------------------------------------------------------------------------
; フレームバッファ設定を書きこむ
;-------------------------------------------------------------------------
fb_set_screen:
                mov     eax, SYS_ioctl
                mov     rdi, [fb_desc]
                mov     esi, FBIOPUT_VSCREENINFO
                lea     rdx, [scinfo_data]  ; 設定済みデータ
                syscall
                test    rax, rax
                ret

;-------------------------------------------------------------------------
; 保存済みのフレームバッファ設定を新規設定用にコピー
;-------------------------------------------------------------------------
fb_copy_scinfo:
                push    rsi
                push    rdi
                lea     rsi, [scinfo_save]  ; 保存済みデータ
                lea     rdi, [scinfo_data]  ; 設定用データ
                mov     ecx, (fb_var_screeninfo_size / 4)
                cld
                rep movsd
                pop     rdi
                pop     rsi
                ret

;-------------------------------------------------------------------------
; フレームバッファメモリをマッピング
;    addr:      rdi
;    len:       rsi
;    prot:      rdx
;    flags:     r10
;    fd:        r8
;    offset:    r9
;-------------------------------------------------------------------------
fb_map_screen:
                mov     eax, [scinfo_data+fb_var_screeninfo.yres_virtual]
                mul     dword [scinfo_data+fb_var_screeninfo.xres_virtual]
                mov     ebx, [scinfo_data+fb_var_screeninfo.bits_per_pixel]
                shr     ebx, 3
                mul     rbx
                mov     rsi, rax                ; len
                mov     [mmap_len],rax          ; for unmap
                mov     edx, (PROT_READ | PROT_WRITE) ; prot
                mov     r10d, MAP_SHARED        ; flags
                mov     r8, [fb_desc]           ; fd
                xor     eax, eax
                mov     rdi, rax                ; addr
                mov     r9, rax                 ; offset
                mov     eax, SYS_mmap
                syscall
                test    rax, rax
                mov     [mmap_addr],rax         ; for unmap
                ret

;-------------------------------------------------------------------------
; フレームバッファメモリをアンマップ
;-------------------------------------------------------------------------
fb_unmap_screen:
                mov     eax, SYS_munmap
                mov     rdi, [mmap_addr]
                mov     rsi, [mmap_len]
                syscall
                test    rax, rax
                ret

;-------------------------------------------------------------------------
; カラーマップ(パレット)を取得
;-------------------------------------------------------------------------
fb_get_colormap:
                mov     eax, SYS_ioctl
                mov     rdi, [fb_desc]
                mov     esi, FBIOGETCMAP
                lea     rdx, [colormap_save]
                syscall
                test    rax, rax
                ret

;-------------------------------------------------------------------------
; カラーマップ(パレット)を設定
;-------------------------------------------------------------------------
fb_set_colormap:
                mov     eax, SYS_ioctl
                mov     rdi, [fb_desc]
                mov     esi, FBIOPUTCMAP
                lea     rdx, [colormap_data]
                syscall
                ret

;-------------------------------------------------------------------------
; カラーマップ(パレット)を作成
;-------------------------------------------------------------------------
fb_test_colormap:
                push    rdi
                mov     eax, 0xffff
                lea     rdi, [red_data]
                mov     ecx, 0x100
    .loop:
                mov     [rdi], ax
                mov     [rdi+0x200], ax
                mov     [rdi+0x400], ax
                dec     eax
                inc     rdi
                loop    .loop
                pop     rdi
                ret

;-------------------------------------------------------------------------
; 保存済みのフレームバッファ設定を復帰
;-------------------------------------------------------------------------
fb_restore_sc:
                mov     eax, SYS_ioctl
                mov     rdi, [fb_desc]
                mov     esi, FBIOPUT_VSCREENINFO
                lea     rdx, [scinfo_save]
                syscall
                ret

;-------------------------------------------------------------------------
; 保存済みのカラーマップ(パレット)を復帰
;-------------------------------------------------------------------------
fb_restore_cmap:
                mov     eax, SYS_ioctl
                mov     rdi, [fb_desc]
                mov     esi, FBIOPUTCMAP
                lea     rdx, [colormap_save]
                syscall
                ret

;==============================================================
section .data

                align   4
colormap_save istruc fb_cmap
    .start      dd    0           ; First entry
    .len        dd    0x100       ; Number of entries (256)
    .red        dd    red_save
    .green      dd    green_save
    .blue       dd    blue_save
    .transp     dd    0           ; transparency, can be NULL
iend

colormap_data istruc fb_cmap
    .start      dd    0           ; First entry
    .len        dd    0x100       ; Number of entries
    .red        dd    red_data
    .green      dd    green_data
    .blue       dd    blue_data
    .transp     dd    0           ; transparency, can be NULL
iend

;==============================================================
section .bss
                        alignb   4

fb_desc:                resq    1
fb_address:             resq    1

red_save:               resw    0x100
green_save:             resw    0x100
blue_save:              resw    0x100

red_data:               resw    0x100
green_data:             resw    0x100
blue_data:              resw    0x100

mmap_addr:              resq    1
mmap_len :              resq    1

                        alignb   8
scinfo_save:    resb    fb_var_screeninfo_size

                        alignb   8
scinfo_data:    resb    fb_var_screeninfo_size

fscinfo:        resb    fb_fix_screeninfo_size

