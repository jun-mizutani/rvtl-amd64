;---------------------------------------------------------------------
;   Mersenne Twister
;   file : mt19937ar.inc
;     Rewritten in Assembly by Jun Mizutani 2025/08/10.
;     From original code in C by Takuji Nishimura(mt19937ar.c).
;---------------------------------------------------------------------

;  A C-program for MT19937, with initialization improved 2002/1/26.
;  Coded by Takuji Nishimura and Makoto Matsumoto.
;
;  Before using, initialize the state by using init_genrand(seed)  
;  or init_by_array(init_key, key_length).
;
;  Copyright (C) 1997 - 2002, Makoto Matsumoto and Takuji Nishimura,
;  All rights reserved.                          
;
;  Redistribution and use in source and binary forms, with or without
;  modification, are permitted provided that the following conditions
;  are met:
;
;    1. Redistributions of source code must retain the above copyright
;       notice, this list of conditions and the following disclaimer.
;
;    2. Redistributions in binary form must reproduce the above copyright
;       notice, this list of conditions and the following disclaimer in the
;       documentation and/or other materials provided with the distribution.
;
;    3. The names of its contributors may not be used to endorse or promote 
;       products derived from this software without specific prior written 
;       permission.
;
;  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
;  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
;  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
;  A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
;  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
;  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
;  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
;  PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
;  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
;  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
;  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;
;  Any feedback is very welcome.
;  http://www.math.sci.hiroshima-u.ac.jp/~m-mat/MT/emt.html
;  email: m-mat @ math.sci.hiroshima-u.ac.jp (remove space)

%assign         N   624
%assign         M   397

section .text

;---------------------------------------------------------------------
; Initialize Mersenne Twister
;   enter eax : seed
;---------------------------------------------------------------------
sgenrand:
                _PUSHA
                mov     esi, N
                mov     ebx, 1812433253
                xor     edx, edx
                inc     edx
                mov     [mt], eax               ; mt[0]
    .loop:
                push    rdx
                dec     edx
                mov     eax, [mt+edx*4]         ; mt[i-1]
                mov     ebx, eax
                shr     ebx, 30
                xor     eax, ebx
                imul    eax, 1812433253
                pop     rdx
                add     eax, edx
                mov     [mt+edx*4], eax         ; mt[i]
                inc     edx
                cmp     edx, esi
                jl      .loop
                mov     dword [mti], esi        ; N:624
                _POPA
                ret

;---------------------------------------------------------------------
; Generate Random Number
;   return eax : random number
;---------------------------------------------------------------------
genrand:
                _PUSHA
                mov     rsi, mt
                mov     rdi, mti
                mov     eax, [rdi]
                mov     ecx, N-1
                cmp     eax, ecx                ; 623
                jle     .genrand2
                mov     rbp, mag01
                shl     ecx, 2                  ; (N-1)*4
                xor     ebx, ebx

    .loop1:     call    .common
                xor     eax, [rsi+rbx+M*4]      ; mt[kk+M]
                call    .common2
                cmp     ebx, (N-M-1)*4          ; N-M-1
                jle     .loop1
                cmp     ebx, ecx                ; (N-1)*4
                jge     .next

    .loop2:     call    .common
                xor     eax, [rsi+rbx+(M-N)*4]  ; (M-N=-227)
                call    .common2
                cmp     ebx, ecx                ; (N-1)*4
                jl      .loop2

    .next:
                mov     edx, [rsi+rcx]          ; (N-1)*4
                mov     eax, [rsi]
                call    .common1
                xor     eax, [rsi+(M-1)*4]
                call    .common2                ; ebx = ecx
                xor     eax, eax
                mov     [rdi], eax              ; mti=0

    .genrand2:  mov     eax, [rdi]
                mov     edx, [rsi+rax*4]        ; mt[mti]
                inc     dword [rdi]             ; mti++
                mov     eax, edx
                shr     eax, 11
                xor     edx, eax
                mov     eax, edx
                shl     eax, 7
                and     eax, 0x9d2c5680         ; TEMPERING_MASK_B
                xor     edx, eax
                mov     eax, edx
                shl     eax, 15
                and     eax, 0xefc60000         ; TEMPERING_MASK_C
                xor     edx, eax
                mov     eax, edx
                shr     eax, 18
                xor     edx, eax
                and     rdx, 0xffffffff
                mov     [rsp+48], rdx           ; return eax
                _POPA
                ret

    .common:    mov     edx, [rsi+rbx]
                mov     eax, [rsi+rbx+4]
    .common1:   and     edx, 0x80000000
                and     eax, 0x7fffffff
                or      edx, eax
                mov     eax, edx
                shr     eax, 1
                ret

    .common2:   and     edx, byte 1
                xor     eax, [rbp+rdx*4]
                mov     [rsi+rbx], eax
                add     ebx, byte 4
                ret

;==============================================================
section .data

mag01           dd 0x00000000
                dd 0x9908b0df
mti             dd N+1

;==============================================================
section .bss

mt              resd N
