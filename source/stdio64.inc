;---------------------------------------------------------------------
; file          : stdio64.inc
; created       : 2010/06/08
; assembler     : nasm 2.07
; description   : standerd input/output version 1.0
;
;Copyright (C) 2010 Jun Mizutani <mizutani.jun@nifty.ne.jp>
;---------------------------------------------------------------------

%ifndef __STDIO64_INC
%define __STDIO64_INC

%ifndef __SYSCALL64_INC
%include "syscall64.inc"
%endif

;------------------------------------
; exit with 0
Exit:
                xor     edi, edi            ; exit with code 0
                mov     eax, SYS_exit
                syscall

;------------------------------------
; exit with ebx
ExitN:
               mov      rdi, rax            ; exit with code ebx
               mov      eax, SYS_exit
               syscall

;------------------------------------
; print string to stdout
; rax : buffer top address
; rdx : no of char to output
OutString:
                push    rcx
                push    rsi
                push    rdi
                mov     rsi, rax
    .out        mov     eax, SYS_write
                xor     edi, edi            ; 0 extends to 64bit
                inc     edi                 ; to stdout
                syscall
                pop     rdi
                pop     rsi
                pop     rcx
                ret

;------------------------------------
; print pascal string to stdout
; rbx : buffer top address
OutPString:
                push    rax
                push    rcx
                push    rsi
                push    rdi
                push    rdx
                xor     edx, edx
                mov     dl, [rbx]
                mov     rsi, rbx
                inc     rsi
                jmp     short  OutAsciiZ.out

;------------------------------------
; print asciiz string
; rax : pointer to string
OutAsciiZ:
                push    rax
                push    rcx
                push    rsi
                push    rdi
                push    rdx
                push    rax
                call    StrLen
                mov     rdx, rax            ; set length
                pop     rsi                 ; set address (rax-->ecx)
    .out        mov     eax, SYS_write
                xor     edi, edi            ; 0 extends to 64bit
                inc     edi                 ; to stdout
                syscall
                pop     rdx
                pop     rdi
                pop     rsi
                pop     rcx
                pop     rax
                ret

;------------------------------------
; get length of asciiz string
; rax : top address
; rax : return length
StrLen:
                push    rbx
                push    rcx
                xor     ecx, ecx
    .next       mov     bl, [rax+rcx]
                inc     rcx
                cmp     bl, 0
                jnz     short .next
                dec     rcx
                mov     rax, rcx
                pop     rcx
                pop     rbx
                ret

                push    rcx
                push    rdi
                mov     rdi, rax
                push    rax
                xor     eax, eax
                xor     ecx, ecx
                dec     rcx
         repne  scasb
                pop     rcx
                sub     rdi, rcx
                mov     rax, rdi
                dec     rax
                pop     rdi
                pop     rcx
                ret

;------------------------------------
; print 4 characters in rax to stdout
;   destroyed : rax
OutChar4:
                push    rcx
                mov     ch, 0x04
                mov     cl, 0x08
    .loop:      and     al, 0x7F            ; 7bit only
                test    al, al
                jz      .dot
                cmp     al, 0x20
                jae     .output
    .dot:       mov     al, '.'
    .output:    call    OutChar
                shr     rax, cl
                dec     ch
                jnz     .loop
                pop     rcx
                ret

;------------------------------------
; print 1 character to stdout
; rax : put char
OutChar:
                push    rdx
                xor     edx, edx
                inc     edx
                call    OutCharN
                pop     rdx
                ret

;------------------------------------
; print 4 characters in rax to stdout
;   destroyed : rax
OutChar4B:
                push    rdx
                xor     edx, edx
                mov     dl, 4
                bswap   rax
                call    OutCharN
                pop     rdx
                ret

;------------------------------------
; print 4 characters in rax to stdout
;   destroyed : rax
OutChar8B:
                push    rdx
                xor     edx, edx
                mov     dl, 8
                bswap   rax
                call    OutCharN
                pop     rdx
                ret

;------------------------------------
; print n characters in rax to stdout
;   rdx : no. of characters
;   destroyed : rax
OutCharN:
                push    rcx
                push    rsi
                push    rdi
                push    rax                 ; work buffer on stack
                mov     eax, SYS_write
                xor     edi, edi
                inc     edi                 ; 1:to stdout
                mov     rsi, rsp
                syscall
                pop     rax
                pop     rdi
                pop     rsi
                pop     rcx
                ret

;------------------------------------
; new line
;   all registers are preserved.
NewLine:
                push    rax
                mov     al, 0AH
                call    OutChar
                pop     rax
                ret

;------------------------------------
; Backspace
;   destroyed : al
BackSpace:
               mov    al, 0x08
               call   OutChar
               mov    al, ' '
               call   OutChar
               mov    al, 0x08
               call   OutChar
               ret

;------------------------------------
; print binary number
;   rax : number
;   ecx : bit
PrintBinary:
                push    rax
                push    rbx
                push    rcx
                push    rdx
                push    rsi
                push    rdi
                mov     rbx, rax
                mov     esi, 64
                or      ecx, ecx        ; ecx > 0 ?
                jle     .exit           ; no ecx<=0
                cmp     ecx, esi
                jg      .toobig
                mov     edx, ecx        ; extract lower bits
                sub     esi, ecx        ; 64
                mov     ecx, esi
                shl     rbx, cl
                mov     ecx, edx
                jmp     short .loop
    .toobig:
                mov     ecx, esi
    .loop:
                mov     al, '0'
                shl     rbx, 1
                jnc     .print_zero
                inc     rax
    .print_zero:
                call    OutChar
                loop    .loop
    .exit:
                pop     rdi
                pop     rsi
                pop     rdx
                pop     rcx
                pop     rbx
                pop     rax
                ret

;------------------------------------
; print ecx digit octal number
;   rax : number
;   ecx : digit
PrintOctal:
                push    rax
                push    rcx
                push    rbx
                push    rdx
                or      ecx, ecx
                je      .exit
                mov     edx, ecx            ; 桁数カウンタ
    .push:      mov     rbx, rax
                and     ebx, byte 7
                shr     rax, 3
                push    rbx                 ; 剰余(下位桁)をPUSH
                loop    .push
                mov     ecx, edx            ; 桁数カウンタ
    .pop:       pop     rax                 ; 上位桁から POP
                add     al, '0'             ; 文字コードに変更
                call    OutChar             ; 出力
                loop    .pop
    .exit:
                pop     rdx
                pop     rbx
                pop     rcx
                pop     rax
                ret

;------------------------------------
; print 2 digit hex number (lower 8 bit of rax)
;   rax : number
;   destroyed : edx
PrintHex2:
                mov     dl, 2
                jmp     short PrintHex

;------------------------------------
; print 4 digit hex number (lower 16 bit of rax)
;   rax : number
;   destroyed : edx
PrintHex4:
                mov    dl, 4
                jmp    short PrintHex

;------------------------------------
; print 8 digit hex number (rax)
;   rax : number
;   destroyed : edx
PrintHex8:
                mov    dl, 8
                jmp    short PrintHex

;------------------------------------
; print 16 digit hex number (rax)
;   rax : number
;   destroyed : edx
PrintHex16:
                mov    dl, 16

;------------------------------------
; print hex number
;   rax : number     edx : digit
PrintHex:
                push    rax
                push    rcx
                push    rbx
                xor     ecx, ecx
                mov     cl, dl
    .loop1:     mov     bl, al
                and     bl, 0x0F
                shr     rax, 4
                or      bl, 0x30
                cmp     bl, 0x3A
                jb      .skip
                add     bl, 0x41 - 0x3A     ; A-F
    .skip:
                push    rbx
                loop    .loop1
                mov     cl, dl
    .loop2:     pop     rax
                call    OutChar
                loop    .loop2
                pop     rbx
                pop     rcx
                pop     rax
                ret

;------------------------------------
; Output Unsigned Number to stdout
; rax : number
PrintLeftU:
                push    rax
                push    rbx
                push    rcx
                push    rdx
                push    rdi
                push    rbp
                xor     ecx, ecx            ; 桁数カウンタ
                xor     edi, edi            ; 正を仮定
                jmp     short PrintLeft.positive

;------------------------------------
; Output Number to stdout
; rax : number
PrintLeft:
                push    rax
                push    rbx
                push    rcx
                push    rdx
                push    rdi
                push    rbp
                xor     ecx, ecx            ; 桁数カウンタ
                xor     edi, edi            ; 正を仮定
                test    rax, rax
                jns     .positive
                inc     edi                 ; 負に設定
                neg     rax
    .positive:  mov     ebx, 10
    .PL1:       xor     edx, edx            ; 上位桁を 0 に
                div     rbx                 ; 10 で除算
                push    rdx                 ; 剰余(下位桁)をPUSH
                inc     ecx                 ; 桁数更新
                test    rax, rax            ; 終了か?
                jnz     .PL1
    .PL2:       test    edi, edi
                je      .pos
                mov     al, '-'             ; 文字コードに変更
                call    OutChar             ; 出力
    .pos:       pop     rax                 ; 上位桁から POP
                add     al, '0'             ; 文字コードに変更
                call    OutChar             ; 出力
                loop    .pos
                pop     rbp
                pop     rdi
                pop     rdx
                pop     rcx
                pop     rbx
                pop     rax
                ret

;------------------------------------
; Output Number to stdout
; ecx:column
; rax:number
PrintRight:
                push    rax
                push    rbx
                push    rcx
                push    rdx
                push    rdi
                push    rbp
                mov     ebp, ' '
    .pr0:
                push    rsi
                mov     esi, ecx            ; 表示桁数を esi に
                xor     ecx, ecx            ; 桁数カウンタ
                xor     edi, edi            ; 正を仮定
                test    rax, rax
                jns     .positive
                dec     esi
                inc     edi                 ; 負を設定
                neg     rax
    .positive:
                mov     ebx, 10
    .pr1:       xor     edx, edx            ; 上位桁を 0 に
                div     rbx                 ; 10 で除算
                push    rdx                 ; 剰余(下位桁)をPUSH
                inc     ecx                 ; 桁数更新
                test    rax, rax            ; 終了か?
                jnz     .pr1
                sub     esi, ecx            ; esi にスペース数
                jbe     .done               ; 表示桁数を超える
                xchg    esi, ecx            ; ecx にスペース数
    .space:     mov     eax, ebp            ; スペースか 0
                call    OutChar             ; スペース出力
                loop    .space
                xchg    esi, ecx            ; ecx に表示桁数
    .done:
                test    edi, edi
                je      .pos
                mov     al, '-'             ; 文字コードに変更
                call    OutChar             ; 出力
    .pos:       pop     rax                 ; 上位桁から POP
                add     al, '0'             ; 文字コードに変更
                call    OutChar             ; 出力
                loop    .pos
                pop     rsi
                pop     rbp
                pop     rdi
                pop     rdx
                pop     rcx
                pop     rbx
                pop     rax
                ret
                jmp     short PrintLeft.PL2

;------------------------------------
; Output Number to stdout
; ecx:column
; rax:number
PrintRight0:
                push    rax
                push    rbx
                push    rcx
                push    rdx
                push    rdi
                push    rbp
                mov     ebp, '0'
                jmp     short PrintRightU.pr0

;------------------------------------
; Output Unsigned Number to stdout
; ecx:column
; rax:number
PrintRightU:
                push    rax
                push    rbx
                push    rcx
                push    rdx
                push    rdi
                push    rbp
                mov     ebp, ' '
    .pr0:
                push    rsi
                mov     esi, ecx            ; 表示桁数を esi に
                xor     ecx, ecx            ; 桁数カウンタ
                xor     edi, edi            ; 正を仮定
                jmp     short PrintRight.positive


;------------------------------------
; input 1 character from stdin
; rax : get char
InChar:
                push    rcx
                push    rdx
                push    rdi
                push    rsi
                push    rax                 ; work buffer on stack
                mov     eax, SYS_read
                xor     edi, edi            ; 0:from stdin
                mov     rsi, rsp            ; into Input Buffer
                mov     edx, edi
                inc     edx                 ; 1 char
                syscall                     ; call kernel
                pop     rax                 ; retrieve a char from buffer
                pop     rsi
                pop     rdi
                pop     rdx
                pop     rcx
                ret

;------------------------------------
; Input Line
; rax : BufferSize
; rbx : Buffer Address
; return       rax : no. of char
;
InputLine0:
               push   rdi
               push   rcx
               push   rdx
               mov    rdx, rax
               mov    rdi, rbx       ; Input Buffer
               xor    ecx, ecx
   .in_char:
               call   InChar
               cmp    al, 0x08       ; BS ?
               jnz    .in_char2
               test   ecx, ecx
               jz     .in_char2
               call   BackSpace      ; backspace
               dec    ecx
               jmp    short .in_char
   .in_char2:
               cmp    al, 0x0A       ; enter ?
               jz     .in_exit

   .in_printable:
               call   OutChar
               mov    [rdi + rcx], al
               inc    ecx
               cmp    ecx, edx       ;
               jae    .in_toolong
               jmp    short .in_char
   .in_toolong:
               dec    ecx
               call   BackSpace
               jmp    short .in_char

   .in_exit:
               mov    dword [rdi + rcx], 0
               inc    ecx
               call   NewLine
               mov    eax, ecx
               pop    rdx
               pop    rcx
               pop    rdi
               ret

%endif
