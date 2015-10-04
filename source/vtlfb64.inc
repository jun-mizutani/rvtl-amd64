;-------------------------------------------------------------------------
;  Return of the Very Tiny Language
;  version : 4.01  2015/09/25
;  Copyright (C) 2002-2015 Jun Mizutani <mizutani.jun@nifty.ne.jp>
;
;  file : vtlfb64.inc
;         frame buffer extention
;-------------------------------------------------------------------------

                call    GetChar             ;
                cmp     al, 'b'
                je      .frame_buffer
    .error_exit:jmp     func_error

    .frame_buffer:
                call    GetChar             ;
                cmp     al, 'o'
                je      .func_fbo           ; fb open
                cmp     al, 'c'
                je      .func_fbc           ; fb close
                cmp     al, 'd'
                je      .func_fbd           ; fb dot
                cmp     al, 'f'
                je      .func_fbf           ; fb fill
                cmp     al, 'l'
                je      .func_fbl           ; fb line
                cmp     al, 'm'
                je      .func_fbm           ; fb mem_copy
                cmp     al, 'p'
                je      .func_fbp           ; fb put
                cmp     al, 'q'
                je      .func_fbq           ; fb put with mask
                cmp     al, 'r'
                je      .func_fbr           ; fb fill pattern
                cmp     al, 's'
                je      .func_fbs           ; fb set_screen
                cmp     al, 't'
                je      .func_fbt           ; fb put2
                jmp     short .error_exit

    .func_fbf:
                call    FrameBufferFill
                ret

    .func_fbc:
                push    rdi
                push    rsi
                call    fb_restore_sc       ; 保存済みの設定を復帰
                call    fb_unmap_screen
                call    fbdev_close
                js      .error
                pop     rsi
                pop     rdi
                ret
    .func_fbd:
                call    Dot
                ret
    .func_fbl:
                call    LineDraw
                ret
    .func_fbm:
                call    MemCopy
                ret
    .func_fbp:
                call    PatternTransfer
                ret

    .func_fbq:
                call    MPatternTransfer
                ret

    .func_fbr:
                call    PatternFill
                ret

    .func_fbs:
                push    rdi
                push    rsi
                call    fb_set_screen
                pop     rsi
                pop     rdi
                ret

    .func_fbt:
                call    PatternTransfer2
                ret

    .func_fbo:
                push    rdi
                push    rsi
                call    fbdev_open
    .error:     js      near SYS_Error
                call    fb_get_fscreen
                js      .error
                call    fb_get_screen
                js      .error
                call    fb_copy_scinfo
                call    fb_map_screen
                jns     .ok
                mov     rcx, rax
                neg     rcx
                cmp     rcx, 0xFF
                jbe     .error
    .ok         xor     ecx, ecx
                mov     cl, 'f'
                mov     [rbp+rcx*8], rax
                mov     cl, 'g'
                mov     dword[rbp+rcx*8], scinfo_data
                pop     rsi
                pop     rdi
                ret

;---------------------------------------------------------------------------
; rax : Y
; rbx : width(byte)
; rdi : addr
; carry : 32bits/pixel(set)
StartPoint:
                push    rbx
                imul    ebx                 ; Y * width
                mov     ebx, [rbp +  8]     ; X
                shl     ebx, 1              ; 16bit/pixel
                mov     edx, [rbp + 32]     ; depth
                cmp     dl, 32
                jne     .bit_16
                shl     ebx, 1              ; 32bit/pixel
                add     rax, rbx            ; Y * width + X
                add     rdi, rax            ; rdi := addr + rax
                pop     rbx
                stc
                ret

    .bit_16:    add     rax, rbx            ; Y * width + X
                add     rdi, rax            ; rdi := addr + rax
                pop     rbx
                clc
                ret

;---------------------------------------------------------------------------
; ライン描画
; l[0] = addr   [rbp +  0] l;0; 描画領域アドレス
; l[1] = addr   [rbp +  4]      描画領域アドレス
; l[2] = x1     [rbp +  8]      ; l[3] = y1     [rbp + 12]
; l[4] = x2     [rbp + 16]      ; l[5] = y2     [rbp + 20]
; l[6] = color  [rbp + 24]
; l[7] = ScrX   [rbp + 28]
; l[8] = Depth  [rbp + 32]      ; 1ピクセルのビット数
; l[9] = incr1  [rbp + 36]
; l[10]= incr2  [rbp + 40]

LineDraw:
                _PUSHA
                cld
                xor     ebx, ebx
                mov     bl, 'l'             ; 引数は l[0] -
                mov     rbp, [rbp+rbx*8]    ; rbp : argument top
                mov     rdi, [rbp]          ; buffer address (8byte)
                mov     ebx, [rbp + 28]     ; ScrX

                mov     ecx, [rbp + 16]     ; rcx = delta X (X2 - X1)
                sub     ecx, [rbp +  8]     ; rcx = X2 - X1
                jz      .VertLine           ; if (delta X=0) Vertical
                jns     .L01                ; JUMP IF X2 > X1

                neg     ecx                 ; deltaX = - deltaX
                mov     eax, [rbp + 16]     ; swap X1  X2
                xchg    eax, [rbp +  8]
                mov     [rbp + 16], eax

                mov     eax, [rbp + 20]     ; swap Y1  Y2
                xchg    eax, [rbp + 12]     ; Y1
                mov     [rbp + 20], eax

    .L01:       mov     eax, [rbp + 20]     ; rax = Y2-Y1
                sub     eax, [rbp + 12]     ; Y1
                jnz     .SlopeLine

    .HolizLine: inc     ecx                 ; DELTA X + 1 : # OF POINTS
                mov     eax, [rbp + 12]     ; Y1
                call    StartPoint          ; rdi=addr + X + Y1 * width
                mov     eax, [rbp + 24]     ; color
                jb      .h32
                rep     stosw               ; 16bit
                jmp     short .exit0        ; finished
    .h32:       rep     stosd               ; 32bit
                jmp     short .exit0        ; finished

    .VertLine:  mov     eax, [rbp + 12]     ; Y1
                mov     esi, [rbp + 20]     ; Y2
                mov     ecx, esi
                sub     ecx, eax            ; Y2 - Y1
                jge     .LVL1
                neg     ecx
                mov     eax, esi
    .LVL1:      inc     ecx                 ; DELTA Y + 1 : # OF POINTS
                call    StartPoint          ; rdi=addr + X + Y * width
                mov     eax, [rbp + 24]     ; color
                jb      .LVL32
    .LVL16:
                mov     [rdi], ax
                add     rdi, rbx            ; rbx:width
                loop    .LVL16
                jmp     short .exit0        ; finished
    .LVL32:
                mov     [rdi], eax
                add     rdi, rbx            ; rbx:width
                loop    .LVL32
    .exit0:     _POPA
                ret                         ; finished

    ;-------------------------------------------------
    ;      ENTRY : rax = DY   rbx = width (bytes/line)
    ;              rcx = dx
    .SlopeLine:
                jns     .L03                ; JUMP IF (Y2 > Y1)
                neg     eax                 ; DELTA Y
                neg     rbx                 ; BYTES/LINE

    .L03:       push    rax
                push    rcx
                cmp     eax, ecx            ; DELTA Y - DELTA X
                jle     .L04                ; JUMP IF DY <= dx ( SLOPE <= 1)
                xchg    eax, ecx

    .L04:       shl     eax, 1              ; eax := 2 * DY
                mov     [rbp + 36], eax     ; incr1 := 2 * DY
                sub     eax, ecx
                mov     esi, eax            ; rsi := D = 2 * DY - dx
                sub     eax, ecx

                mov     [rbp + 40], eax     ; incr2 := D = 2 * (DY - dx)

                mov     eax, [rbp + 12]     ; Y1
                push    rbx
                or      rbx, rbx
                jns     .L05
                neg     rbx
    .L05:
                call    StartPoint          ; rdi=addr + X + Y * width
                pop     rbx
                pop     rcx
                pop     rax
                jb      .Slope32
                cmp     eax, ecx            ; DELTA Y - DELTA X
                jg      .HiSlopeLine        ; JUMP IF DY > dx ( SLOPE > 1)

    .LoSlopeLine:
                inc     ecx
                mov     eax, [rbp + 24]     ; color
    .L11:       stosw
                or      esi, esi
                jns     .L12
                add     esi, [rbp + 36]     ; incr1
                loop    .L11
                jmp     short .exit

    .L12:       add     esi, [rbp + 40]     ; incr2
                add     rdi, rbx            ; rbx=(+/-)width
                loop    .L11
                jmp     short .exit

    .HiSlopeLine:
                xchg    eax, ecx
                inc     ecx
                mov     eax, [rbp + 24]     ; color
    .L21:       stosw
                add     rdi, rbx            ; rbx=(+/-)width
                or      esi, esi
                jns     .L22
                add     esi, [rbp + 36]     ; incr1
                dec     rdi
                dec     rdi
                loop    .L21
                jmp     short .exit

    .L22:       add     esi, [rbp + 40]     ; incr2
                loop    .L21

    .exit:      _POPA
                ret

    .Slope32:   cmp     eax, ecx            ; DELTA Y - DELTA X
                jg      .HiSlopeLine32      ; JUMP IF DY > dx ( SLOPE > 1)

    .LoSlopeLine32:
                inc     ecx
                mov     eax, [rbp + 24]     ; color
    .L31:       stosd
                or      esi, esi
                jns     .L32
                add     esi, [rbp + 36]     ; incr1
                loop    .L31
                jmp     short .exit2

    .L32:       add     esi, [rbp + 40]     ; incr2
                add     rdi, rbx            ; rbx=(+/-)width
                loop    .L31
                jmp     short .exit2

    .HiSlopeLine32:
                xchg    eax, ecx
                inc     ecx
                mov     eax, [rbp + 24]     ; color
    .L41:       stosd
                add     rdi, rbx            ; rbx=(+/-)width
                or      esi, esi
                jns     .L42
                add     esi, [rbp + 36]     ; incr1
                lea     rdi, [rdi - 4]
                loop    .L41
                jmp     short .exit2

    .L42:       add     esi, [rbp + 40]     ; incr2
                loop    .L41

    .exit2:     _POPA
                ret

;---------------------------------------------------------------------------
; 点の描画 16&32bit
;   d[0] = addr   [rbp +  0] d;0; 転送先アドレス
;   d[1] = addr   [rbp +  4]      転送先アドレス
;   d[2] = x      [rbp +  8] X座標
;   d[3] = y      [rbp + 12] Y座標
;   d[4] = Color  [rbp + 16] 色
;   d[5] = ScrX   [rbp + 20] 転送先X方向のバイト数
;   d[6] = Depth  [rbp + 24] 1ピクセルのビット数
Dot:
                _PUSHA
                xor     ebx, ebx
                mov     bl, 'd'             ; 引数
                mov     rbp, [rbp+rbx*8]    ; rbp : argument top
                mov     rdi, [rbp]          ; buffer address (mem or fb)
                mov     ecx, [rbp + 20]     ; ScrX
                mov     eax, [rbp + 12]     ; Y
                imul    ecx                 ; Y * ScrX
                mov     edx, [rbp +  8]     ; X
                add     rdi, rax            ; rdi := addr + Y * ScrX
                mov     ebx, [rbp + 16]     ; color
                mov     eax, [rbp + 24]     ; Depth
                cmp     al, 32
                je      .depth32
                shl     edx, 1              ; X * 2
                add     rdi, rdx            ; X * 2 + Y * ScrX
                mov     [rdi], bx           ; 16bit/pixel
                jmp     short .exit
    .depth32:
                shl     edx, 2              ; X * 4
                add     rdi, rdx            ; X * 4 + Y * ScrX
                mov     [rdi], ebx          ; 32bit/pixel
    .exit       _POPA
                ret


;---------------------------------------------------------------------------
; 引数関連共通処理
; return
;  eax = depth
;  ebx = ScrX
;  ecx = X*2
;  edx = PatH
;  rdi = 転送先アドレス
;  rsi = パターンの格納アドレス先頭
;  rbp = 引数先頭
PatternSize:
                cld
                mov     rbp, [rbp+rbx*8]    ; rbp : argument top
                mov     ecx, [rbp + 32]     ; ScrX
                mov     rdi, [rbp]          ; buffer address (8byte)
                mov     rsi, [rbp + 24]     ; pattern
                mov     eax, [rbp + 12]     ; Y
                imul    ecx                 ; Y * ScrX
                mov     edx, [rbp +  8]     ; X
                shl     edx, 1              ; X * 2
                add     eax, edx            ; X * 2 + Y * ScrX
                add     rdi, rax            ; rdi := addr + rax
                mov     ebx, ecx            ; rbx := Screen Width
                mov     ecx, edx            ; rcx := X*2
                mov     edx, [rbp + 20]     ; PatH
                mov     eax, [rbp + 36]     ; Depth
                ret

;---------------------------------------------------------------------------
; パターン転送 16&32bit
;   p[0] = addr   [rbp +  0] p;0; 転送先アドレス
;   p[1] = addr   [rbp +  4]      転送先アドレス
;   p[2] = x      [rbp +  8] 転送先のX座標
;   p[3] = y      [rbp + 12] 転送先のY座標
;   p[4] = PatW   [rbp + 16] パターンの幅
;   p[5] = PatH   [rbp + 20] パターンの高さ
;   p[6] = mem    [rbp + 24] p;3; パターンの格納アドレス ★
;   p[7] = mem    [rbp + 28]      パターンの格納アドレス ★
;   p[8] = ScrX   [rbp + 32] 転送先X方向のバイト数
;   p[9] = Depth  [rbp + 36] 1ピクセルのビット数

PatternTransfer:
                _PUSHA
                xor     ebx, ebx
                mov     bl, 'p'             ; 引数
                call    PatternSize
                cmp     al, 32
                je      .pat32
    .loop16:    mov     ecx, [rbp + 16]     ; PatW
                push    rdi
                rep     movsw
                pop     rdi
                add     rdi, rbx            ; y++
                dec     rdx
                jne     .loop16
                jmp     short .exit
    .pat32:     add     rdi, rcx            ; rdi=addr + Y*ScrX + X*4
    .loop32:    mov     ecx, [rbp + 16]     ; PatW
                push    rdi
                rep     movsd
                pop     rdi
                add     rdi, rbx            ; y++
                dec     rdx
                jne     .loop32
    .exit:      _POPA
                ret

;---------------------------------------------------------------------------
; パターン転送2 16&32bit
;   t[0] = addr   [rbp +  0] t;0; 転送先アドレス
;   t[1] = addr   [rbp +  4]      転送先アドレス
;   t[2] = x      [rbp +  8] 転送先のX座標
;   t[3] = y      [rbp + 12] 転送先のY座標
;   t[4] = PatW   [rbp + 16] パターンの幅
;   t[5] = PatH   [rbp + 20] パターンの高さ
;   t[6] = mem    [rbp + 24] t;3; パターンの格納アドレス先頭 ★
;   t[7] = mem    [rbp + 28]      パターンの格納アドレス先頭 ★
;   t[8] = ScrX   [rbp + 32] 転送先のX方向のバイト数
;   t[9] = Depth  [rbp + 36] 1ピクセルのビット数
;   t[10] = x2    [rbp + 40] 転送元のX座標
;   t[11] = y2    [rbp + 44] 転送元のY座標
;   t[12]= ScrX2  [rbp + 48] 転送元のX方向のバイト数

PatternTransfer2:
                _PUSHA
                xor     ebx, ebx
                mov     bl, 't'             ; 引数
                call    PatternSize
                push    rax                 ; depth
                push    rdx                 ; PatH
                push    rcx                 ; X*2
                push    rbx                 ; ScrX
                mov     ecx, [rbp + 48]     ; ScrX2
                mov     eax, [rbp + 44]     ; Y2
                imul    ecx                 ; Y2 * ScrX2
                mov     edx, [rbp + 40]     ; X2
                shl     edx, 1              ; X2 * 2
                mov     r12d, edx
                add     eax, edx            ; X2 * 2 + Y2 * ScrX2
                add     rsi, rax            ; rsi := mem + rax
                pop     rbx                 ; ScrX
                pop     rcx                 ; X*2
                pop     rdx                 ; PatH
                pop     rax                 ; depth
                cmp     al, 32
                je      .pat32
                mov     eax, [rbp + 48]     ; ScrX2
    .loop16:    mov     ecx, [rbp + 16]     ; PatW
                push    rdi
                push    rsi
                rep     movsw
                pop     rsi
                pop     rdi
                add     rdi, rbx            ; y++
                add     rsi, rax            ; y2++
                dec     rdx
                jne     .loop16
                jmp     short .exit
    .pat32:
                add     rsi, r12            ; rsi=mem + Y2*ScrX2 + X2*4
                add     rdi, rcx            ; rdi=addr + Y*ScrX + X*4
                mov     eax, [rbp + 48]     ; ScrX2
    .loop32:    mov     ecx, [rbp + 16]     ; PatW
                push    rdi
                push    rsi
                rep     movsd
                pop     rsi
                pop     rdi
                add     rdi, rbx            ; y++
                add     rsi, rax            ; y2++
                dec     rdx
                jne     .loop32
    .exit:      _POPA
                ret

;---------------------------------------------------------------------------
; マスク付きパターン転送 16&32bit
;   q[0] = addr   [rbp +  0] q;0; 転送先アドレス
;   q[1] = addr   [rbp +  4]      転送先アドレス
;   q[2] = x      [rbp +  8] 転送先のX座標
;   q[3] = y      [rbp + 12] 転送先のY座標
;   q[4] = PatW   [rbp + 16] パターンの幅
;   q[5] = PatH   [rbp + 20] パターンの高さ
;   q[6] = mem    [rbp + 24] q;3; パターンの格納アドレス ★
;   q[7] = mem    [rbp + 28]      パターンの格納アドレス ★
;   q[8] = ScrX   [rbp + 32] X方向のバイト数
;   q[9] = Depth  [rbp + 36] 1ピクセルのビット数
;   q[10] = Mask  [rbp + 40] マスク色
MPatternTransfer:
                _PUSHA
                xor     ebx, ebx
                mov     bl, 'q'             ; 引数
                call    PatternSize
                cmp     al, 32
                je      .pat32

    .loop16:    mov     ecx, [rbp + 16]     ; PatW
                push    rdi
    .l16b       mov     ax, [rsi]
                cmp     ax, [rbp + 40]      ; マスク色なら書込まない
                je      .l16n
                mov     [rdi], ax
    .l16n       lea     rsi, [rsi + 2]
                lea     rdi, [rdi + 2]
                loop    .l16b
                pop     rdi
                add     rdi, rbx            ; y++
                dec     rdx
                jne     .loop16
                jmp     short .exit

    .pat32:     add     rdi, rcx            ; rdi=addr + Y*ScrX + X*4
    .loop32:    mov     ecx, [rbp + 16]     ; PatW
                push    rdi
    .l32b       mov     eax, [rsi]
                cmp     eax, [rbp + 40]     ; マスク色なら書込まない
                je      .l32n
                mov     [rdi], eax
    .l32n       lea     rsi, [rsi + 4]
                lea     rdi, [rdi + 4]
                loop    .l32b
                pop     rdi
                add     rdi, rbx            ; y++
                dec     rdx
                jne     .loop32
    .exit:      _POPA
                ret

;---------------------------------------------------------------------------
; パターンフィル 16&32bit
;   r[0] = addr   [rbp +  0] r;0; 転送先アドレス
;   r[1] = addr   [rbp +  4]      転送先アドレス
;   r[2] = x      [rbp +  8] 転送先のX座標
;   r[3] = y      [rbp + 12] 転送先のY座標
;   r[4] = PatW   [rbp + 16] パターンの幅
;   r[5] = PatH   [rbp + 20] パターンの高さ
;   r[6] = Color  [rbp + 24] パターンの色
;   r[7] = ScrX   [rbp + 28] X方向のバイト数
;   r[8] = Depth  [rbp + 32] 1ピクセルのビット数

PatternFill:
                _PUSHA
                cld
                xor     ebx, ebx
                mov     bl, 'r'             ; 引数
                mov     rbp, [rbp+rbx*8]    ; rbp : argument top
                mov     ecx, [rbp + 28]     ; ScrX
                mov     rdi, [rbp]          ; buffer address (8byte)
                mov     esi, [rbp + 24]     ; color
                mov     eax, [rbp + 12]     ; Y
                imul    ecx                 ; Y * ScrX
                mov     edx, [rbp +  8]     ; X
                shl     edx, 1              ; X * 2
                add     eax, edx            ; X * 2 + Y * ScrX
                add     rdi, rax            ; rdi := addr + rax
                mov     ebx, ecx            ; rbx := Screen Width
                mov     ecx, edx            ; rcx := X*2
                mov     edx, [rbp + 20]     ; PatH
                mov     eax, [rbp + 32]     ; Depth
                cmp     al, 32
                je      .pat32
    .pat16:     mov     eax, esi            ; color
    .loop16:    mov     ecx, [rbp + 16]     ; PatW
                push    rdi
                rep     stosw
                pop     rdi
                add     rdi, rbx            ; y++
                dec     rdx
                jne     .loop16
                jmp     short .exit

    .pat32:     mov     eax, esi            ; color
                add     rdi, rcx            ; rdi=addr + Y*ScrX + X*4
    .loop32:    mov     ecx, [rbp + 16]     ; PatW
                push    rdi
                rep     stosd
                pop     rdi
                add     rdi, rbx            ; y++
                dec     rdx
                jne     .loop32
    .exit:      _POPA
                ret

;---------------------------------------------------------------------------
; メモリフィル 8&16&32bit
;  m[0] = addr   [rdx +  0] m;0; メモリフィル先頭アドレス
;  m[1] = addr   [rdx +  4]      メモリフィル先頭アドレス
;  m[2] = offset [rdx +  8] オフセット
;  m[3] = length [rdx + 12] 長さ(ピクセル単位)
;  m[4] = color  [rdx + 16] 色
;  m[5] = Depth  [rdx + 20] bits/pixel

FrameBufferFill:
                push    rdi
                cld
                xor     ebx, ebx
                mov     bl, 'm'             ; 引数は a[0] - a[4]
                mov     rdx, [rbp+rbx*8]
                mov     rdi, [rdx]          ; buffer address (8byte)
                mov     ebx, [rdx + 8]      ; offset
                add     rdi, rbx
                mov     ecx, [rdx +12]      ; length (pixel)
                mov     eax, [rdx +16]      ; color
                mov     edx, [rdx +20]      ; bits/pixel
                shr     edx, 4
                jne     .word
                rep     stosb               ; byte
                jmp     short .exit
    .word:      shr     edx, 1
                jne     .dword
                rep     stosw               ; word
                jmp     short .exit
    .dword:     rep     stosd               ; dword
    .exit:      pop     rdi
                ret

;---------------------------------------------------------------------------
; メモリコピー
;  c[0] = source [rdx +  0] c;0; 転送元先頭アドレス
;  c[1] = source [rdx +  4]      転送元先頭アドレス
;  c[2] = dest   [rdx +  8] c;1; 転送先先頭アドレス
;  c[3] = dest   [rdx + 12]      転送先先頭アドレス
;  c[4] = length [rdx + 16] 転送バイト数
MemCopy:
                _PUSHA
                cld
                xor     ebx, ebx
                mov     bl, 'c'             ; 引数は c[0] - c[2]
                mov     rdx, [rbp+rbx*8]
                mov     rsi, [rdx]          ; 転送元アドレス
                mov     rdi, [rdx + 8]      ; 転送先アドレス
                mov     ecx, [rdx +16]      ; 転送バイト数
                mov     rax, rdi
                sub     rax, rsi            ; rax = 転送先 - 転送元
                jle     .normal             ; 転送先 < 転送元
                std                         ; 逆順
                dec     rcx                 ; 行過ぎを事前に修正
                add     rsi, rcx            ; 最後部から
                add     rdi, rcx
                inc     rcx                 ; 転送量を戻す
    .normal:
                rep     movsb               ; バイト単位
                cld
                _POPA
                ret

