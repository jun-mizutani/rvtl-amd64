;=========================================================================
; DEBUG
; file : debug64.inc
; 2010/06/11
; Copyright (C) 2010 Jun Mizutani <mizutani.jun;nifty.ne.jp>
;=========================================================================
%ifndef __DEBUG_INC
%define __DEBUG_INC

%ifndef __STDIO_INC
%include "stdio64.inc"
%endif

%define quote   '

; レジスタの値を表示するマクロ
; すべてのレジスタを非破壊で表示可能
; フラグレジスタは変化
; ラベルとして998:と999:を使っていることに注意】
;   ex. PRINTREG 'rax'

%macro  PRINTREG   1
        push    rax
        push    rax
        mov     rax, %%L0
        call    OutAsciiZ
        pop     rax
        push    rax
        push    rcx
        mov     rax, %1
        mov     ecx, 22
        call    PrintRight
        call    PrintRightU
        mov     al, ':'
        call    OutChar
        pop     rcx
        pop     rax
        push    rax
        push    rdx
        mov     rax, %1
        call    PrintHex16
        pop     rdx
        mov     al, ' '
        call    OutChar
        pop     rax
        mov     rax, %1
        call    OutChar4
        call    NewLine
        pop     rax
        jmp     short %%L1
%%L0:  db       quote %1 quote, 0
%%L1:
%endmacro

; レジスタの値を先頭アドレスとする文字列を表示するマクロ
; 文字列先頭アドレスの直接指定
;   ex. PRINTSTR esi
%macro  PRINTSTR   1
        pushfd
        push    rax
        mov     rax, %1
        call    OutAsciiZ
        call    NewLine
        pop     rax
        popfd
%endmacro

; レジスタが示すアドレスに格納された値を先頭アドレスとする文字列を
; 表示するマクロ
; 文字列先頭アドレスの間接指定
;   ex. PRINTSTRI esi
%macro  PRINTSTRI  1
        pushfd
        push    rax
        mov     rax, [%1]
        call    OutAsciiZ
        call    NewLine
        pop     rax
        popfd
%endmacro

; 指定した値を表示するマクロ
; すべてのレジスタを非破壊で表示可能
;   ex. CHECK 99
%macro CHECK 1
        pushfd
        push    rax
        mov     rax, %1
        call    PrintLeft
        call    NewLine
        pop     rax
        popfd
%endmacro

; キー入力待ち
%macro  PAUSE 0
        push    rax
        call    InChar
        pop     rax
%endmacro

%endif
