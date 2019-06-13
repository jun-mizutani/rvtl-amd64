;-------------------------------------------------------------------------
;  Return of the Very Tiny Language 64bit
;  file : rvtl.asm
;  version : 4.01  2015/10/05
;  Copyright (C) 2002-2015 Jun Mizutani <mizutani.jun@nifty.ne.jp>
;  RVTL may be copied under the terms of the GNU General Public License.
;
; build :
;   nasm -f elf64 rvtl.asm
;   ld -s -melf_x86_64 -o rvtl rvtl.o
;
; build small rvtl :
;   nasm -f elf64 rvtl.asm -dSMALL_VTL
;   ld -s -melf_x86_64 -o rvtls rvtl.o
;
; disassemble
;   objdump -d -M x86-64,intel rvtl >rvtl.txt
;-------------------------------------------------------------------------

DEFAULT REL

%include        "vtllib64.inc"
%include        "mt19937.inc"

%define VTL_LABEL

%ifdef  SMALL_VTL
  %undef  FRAME_BUFFER
  %undef  DETAILED_MSG
  %define NO_FB
%else
  %define DETAILED_MSG
  %include      "syserror64.inc"
%endif

%ifndef  NO_FB
  %define FRAME_BUFFER
  %include      "fblib64.inc"
%endif

%ifdef  DEBUG
%include        "debug64.inc"
%endif

%assign         ARGMAX      15
%assign         VSTACKMAX   1024
%assign         MEMINIT     256*1024
%assign         LSTACKMAX   127
%assign         FNAMEMAX    256
%assign         LABELMAX    1024
%assign         VERSION     40000
%assign         VERSION64   1
%assign         CPU         4

%assign         NOERROR     $00
%assign         ERR_SPACE   $01
%assign         ERR_DIVZERO $02
%assign         ERR_NOLABEL $04
%assign         ERR_VSTACK  $10
%assign         ERR_SIGINT  $80

;==============================================================
section .text
global _start

;-------------------------------------------------------------------------
; システムの初期化
;
; システムコール
;   1.rax にシステムコール番号を設定
;   2.第 1 引数 を rdi に設定
;   3.第 2 引数 を rsi に設定
;   4.第 3 引数 を rdx に設定
;   5.第 4 引数 を r10 に設定
;   6.第 5 引数 を r8 に設定
;   7.第 6 引数 を r9 に設定
;   8.システムコール命令( syscall ) を実行
;   * r11とrcxは破壊される
;-------------------------------------------------------------------------
_start:
                mov     rdi, argc               ; パラメータ保存領域先頭
                pop     rbx                     ; rbx = argc
                mov     [rdi], rbx              ; argc 引数の数を保存
                mov     [rdi + 8], rsp          ; argvp 引数配列先頭を保存
                lea     rax, [rsp+rbx*8+8]      ; 環境変数アドレス取得
                mov     [rdi + 16], rax         ; envp 環境変数領域の保存
                mov     r13d, 1                 ; use r13 as unity

                mov     rax, [rdi]              ; パラメータ個数を rax に
                mov     rsi, [rdi + 8]          ; パラメータ配列先頭を rsi に
                mov     ecx, 1
                cmp     rax, rcx
                je      .L4                     ; 引数なしならスキップ
    .L1:        mov     rbx, [rsi + rcx * 8]    ; rbx = argvp[rcx]
                mov     dl, [rbx]               ;
                inc     ecx
                cmp     rcx, rax
                je      .L3
                cmp     dl, '-'                 ; 「-」か？
                jne     .L1
                dec     rcx
                mov     [rdi], rcx              ; argc 引数の数を更新
                inc     rcx
    .L3         lea     rdx, [rsi + rcx * 8]
                mov     [rdi + 32], rdx         ; vtl用の引数への配列先頭
                sub     rax, rcx
                mov     [rdi + 24], rax         ; vtl用の引数の個数 (argc_vtl0)

    .L4:        ; argv[0]="xxx/rvtlw" ならば cgiモード
                xor     edx, edx
                lea     rbx, [cginame]            ; 文字列 'wltvr',0
                mov     rcx, [rsi]              ; argv[0]
    .L5:        mov     al, [rcx]
                inc     rcx
                cmp     al, 0
                jne     .L5
                lea     rcx, [rcx - 2]          ; 文字列の最終文字位置(w)
    .L6:        mov     al, [rcx]
                mov     ah, [rbx]
                inc     rbx
                dec     rcx
                cmp     ah, 0
                je      .L7                     ; found
                cmp     al, ah
                jne     .L8                     ; no
                jmp     short .L6
    .L7:        inc     edx                     ; edx = 1
    .L8:        mov     [cgiflag], edx          ; rvtlwフラグ設定

                call    GET_TERMIOS             ; termios の保存
                call    SET_TERMIOS             ; 端末のローカルエコーOFF

                mov     rbp, VarArea            ; サイズ縮小のための準備
                xor     edi, edi                ; 0 を渡して現在値を得る
                mov     eax, SYS_brk            ; ヒープ先頭取得
                syscall
                mov     rbx, rax                ; ヒープにコードも配置
                mov     rdi, rax
                xor     ecx, ecx
                mov     cl, ','                 ; アクセス可能領域先頭
                mov     qword[rbp+rcx*8], rax
                mov     cl, '='                 ; プログラム先頭
                mov     qword[rbp+rcx*8], rax
                lea     rax, [rax + 8]          ; ヒープ先頭
                mov     cl, '&'
                mov     qword[rbp+rcx*8], rax
                add     rdi, MEMINIT            ; ヒープ末(brk)設定
                mov     cl, '*'                 ; RAM末設定
                mov     [rbp+rcx*8], rdi
                mov     eax, SYS_brk            ; brk
                syscall
                xor     eax, eax
                dec     eax
                mov     [rbx] ,eax              ; コード末マーク

                mov     eax, 672274774          ; 初期シード値
                xor     ecx, ecx
                mov     cl, '`'                 ; 乱数シード設定
                mov     [rbp+rcx*8], rax
                call    sgenrand

                xor     ebx, ebx                ; シグナルハンドラ設定
                lea     rax, [SigIntHandler]
                mov     [new_sig + sigaction.sighandler], rax
                mov     eax, SA_NOCLDSTOP       ; 子プロセス停止を無視
                or      eax, SA_RESTORER
                mov     [new_sig + sigaction.sa_flags], rax
                lea     rax, [SigReturn]
                mov     [new_sig + sigaction.sa_restorer], rax
                mov     [new_sig + sigaction.sa_mask], rbx
                mov     eax, SYS_rt_sigaction
                mov     edi, SIGINT             ; ^C
                lea     rsi, [new_sig]
                xor     edx, edx                ; oact = NULL
                mov     r10d, 8
                syscall
                call    CheckError              ; rbp の設定後は使用可
                mov     eax, SIG_IGN            ; シグナルの無視
                mov     [new_sig+sigaction.sighandler], rax
                mov     eax, SYS_rt_sigaction
                mov     edi, SIGTSTP            ; ^Z
                syscall
                call    CheckError              ; rbp の設定後は使用可

                mov     eax, SYS_getpid
                syscall
                mov     [rbp-40], rax           ; pid の保存
                dec     eax
                ja      .not_init
                lea     rdi, [envp]             ; pid=1 なら環境変数設定
                mov     qword[rdi], env         ; envp 環境変数
                lea     rbx, [initvtl]          ; /etc/init.vtl
                call    fropen                  ; open
                jle     .not_init               ; 無ければ継続
                mov     [rbp-12], rax           ; FileDesc
                call    WarmInit2
                mov     byte[rbp-4], 1          ; Read from file
                mov     r14b, 1                 ; EOL=yes
                jmp     short Launch
    .not_init:
                call    WarmInit2
                xor     eax, eax
                mov     [counter], rax          ; コマンド実行カウント初期化
                mov     [current_arg], rax      ; 処理済引数カウント初期化
                call    LoadCode                ; あればプログラムロード
                jg      Launch                  ; メッセージ無し
%ifndef SMALL_VTL
                ; 起動メッセージを表示
                mov     rax, start_msg          ; 起動メッセージ
                call    OutAsciiZ
%endif

Launch:         ; 初期化終了
                mov     [save_stack], rsp

;-------------------------------------------------------------------------
; メインループ
;
;  レジスタの使用原則
;    rax ソースポインタの示す文字，式の値
;    rbx 項の値
;    rsi ソースポインタ
;    rdi 実行時行先頭
;    rbp 変数領域先頭
;-------------------------------------------------------------------------
MainLoop:
                mov     bl, [rbp-29]
                cmp     bl, NOERROR
                jne     DetectError
                cmp     r14b, 0             ; EOL
                je      .not_eol
                cmp     byte[rbp-3], 1      ; ExecMode=Memory
                jne     ReadLine            ; 行取得
                jmp     ReadMem             ; メモリから行取得

    .not_eol:   call    GetChar             ; [rsi]をalに読み込み,rsiを更新
    .next:      cmp     al, ' '             ; 空白読み飛ばし
                jne     .done
                call    GetChar
                jmp     short .next
    .done:
                call    IsNum               ; 行番号付なら編集モード
                jb      .exec
                call    EditMode            ; 編集モード
                jmp     short MainLoop

    .exec:      inc     qword[counter]
                call    IsAlpha
                jb      Command             ; コマンド実行
                call    SetVar              ; 変数代入
    .end:       jmp     short MainLoop

;-------------------------------------------------------------------------
; キー入力またはファイル入力されたコードを実行
;-------------------------------------------------------------------------
ReadLine:       ; 1行入力 : キー入力とファイル入力に対応
                cmp     byte[rbp-4], 0      ; Read from ?
                je      .console            ; コンソールから入力
                call    READ_FILE           ; ファイルから入力
                jmp     short .exit

    .console:   call    DispPrompt
                mov     eax, MAXLINE        ; 1 行入力
                lea     rbx, [input]
                call    READ_LINE           ; 編集機能付キー入力
                mov     rsi, rbx
                mov     r14b, 0             ; not EOL
    .exit:      jmp     short MainLoop

;-------------------------------------------------------------------------
; メモリに格納されたコードを実行
;-------------------------------------------------------------------------
ReadMem:
                mov     eax, [rdi]          ; JUMP先かもしれない
                or      eax, eax            ; コード末？
                js      .stop
                add     rdi, rax            ; Next Line
                mov     eax, [rdi]          ; 次行オフセット
                or      eax, eax            ; コード末？
                jns     .run
    .stop:
                call    CheckCGI            ; CGIモードなら終了
                mov     byte[rbp-3], 0      ; ExecMode=Direct
                mov     r14b, 1             ; EOL=yes
                jmp     MainLoop
    .run:
                call    SetLineNo           ; 行番号を # に設定
                lea     rsi, [rdi+8]        ; 行のコード先頭
%ifdef DEBUG
                call    CodeCheck           ; rsi の値チェック
%endif

    .exit:      mov     r14b, 0             ; EOL=no
                jmp     MainLoop

;-------------------------------------------------------------------------
; 文の実行
;   文を実行するサブルーチンコール
;-------------------------------------------------------------------------
Command:
                xor     ebx, ebx
                mov     bl, al
                cmp     al, '!'
                jb      .comm2
                cmp     al, '/'
                ja      .comm2
                sub     bl,  '!'            ; ジャンプテーブル
                call    [rbx * 8 + TblComm1]
                jmp     MainLoop
    .comm2:     cmp     al, ':'
                jb      .comm3
                cmp     al, '@'
                ja      .comm3
                sub     bl,  ':'
                call    [rbx * 8 + TblComm2]
                jmp     MainLoop
    .comm3:     cmp     al, '['
                jb      .comm4
                cmp     al, '`'
                ja      .comm4
                sub     bl,  '['
                call    [rbx * 8 + TblComm3]
                jmp     MainLoop
    .comm4:     cmp     al, '{'
                jb      .comexit
                cmp     al, '~'
                ja      .comexit
                sub     bl,  '{'
                call    [rbx * 8 + TblComm4]
    .exit:      jmp     MainLoop
    .comexit:   cmp     al, ' '
                je      .exit
                cmp     al, 0
                je      .exit
                cmp     al, 8
                je      .exit
                jmp     SyntaxError

;-------------------------------------------------------------------------
; エラー検出時の処理
;-------------------------------------------------------------------------
DetectError:
                test    bl, ERR_SIGINT      ; SIGINT 受信?
                je      .div0p
                lea     rax, [sigint_msg]
                jmp     short .ee2
    .div0p:     test    bl, ERR_DIVZERO     ; 0除算発生
                je      .exp_err
                lea     rax, [err_div0]     ; 0除算メッセージ
                jmp     short .ee2
    .exp_err:   test    bl, ERR_SPACE
                je      .elvl
                lea     rax, [err_exp]      ; 式中の空白メッセージ
                jmp     short .ee2
    .elvl:      test    bl, ERR_NOLABEL
                je      .evstk
                lea     rax, [err_label]    ; ラベル未定義メッセージ
                jmp     short .ee2
    .evstk:     test    bl, ERR_VSTACK
                je      .ee2
                lea     rax, [err_vstack]   ; 変数スタックメッセージ
    .ee2:       jmp     Error

;-------------------------------------------------------------------------
; 行番号をシステム変数 # に設定
;-------------------------------------------------------------------------
SetLineNo:
                xor     ecx, ecx
                mov     eax, [rdi+4]        ; Line No.
                mov     cl, '#'
                mov     [rbp+rcx*8], rax    ; 行番号を # に設定
                ret

SetLineNo2:
                xor     ecx, ecx
                mov     cl, '#'
                mov     rax, [rbp+rcx*8]    ; # から旧行番号を取得
                dec     ecx
                dec     ecx
                mov     [rbp+rcx*8], rax    ; ! に行番号を設定
                mov     eax, [rdi+4]        ; Line No.
                inc     ecx
                inc     ecx
                mov     [rbp+rcx*8], rax    ; 行番号を # に設定
                ret

;-------------------------------------------------------------------------
; 文法エラー
;-------------------------------------------------------------------------
LongJump:       mov     rsp, [save_stack]   ; スタック復帰
                mov     ebx, eax            ; 文字コード退避
                lea     rax, [err_exp]      ; メッセージ
                jmp     short Error

SyntaxError:
                mov     ebx, eax            ; 入力文字退避
                lea     rax, [syntaxerr]
Error:          call    OutAsciiZ
                cmp     byte[rbp-3], 0      ; ExecMode=Direct
                je      .position
                mov     eax, [rdi+4]        ; エラー行行番号
                call    PrintLeft
                call    NewLine
                lea     rax, [rdi + 8]
                call    OutAsciiZ           ; エラー行表示
                call    NewLine
                sub     rsi, rdi
                mov     rcx, rsi
                lea     rcx, [rcx - 9]
                je      .position
                cmp     rcx, MAXLINE
                jae     .skip
    .errloop:   mov     al, ' '             ; エラー位置設定
                call    OutChar
                loop    .errloop
    .position:  mov     eax, '^  ['
                call    OutChar4
                mov     eax, ebx            ; 入力文字復帰
                call    PrintHex2           ; エラー文字コード表示
                mov     al, ']'
                call    OutChar
                call    NewLine

    .skip:      call    WarmInit            ; システムを初期状態に
                jmp     MainLoop

;-------------------------------------------------------------------------
; プロンプト表示
;-------------------------------------------------------------------------
DispPrompt:
                lea     rax, [prompt1]      ; プロンプト表示
                call    OutAsciiZ
                mov     rax, [rbp-40]       ; pid の取得
                call    PrintHex4
                lea     rax, [prompt2]      ; プロンプト表示
                call    OutAsciiZ
                ret

;-------------------------------------------------------------------------
; シグナルハンドラ
;-------------------------------------------------------------------------
                align   8
SigReturn:
                mov     eax, SYS_rt_sigreturn
                syscall                     ; 戻らない？

                align   8
SigIntHandler:
                or      byte[ErrFlag], ERR_SIGINT ; SIGINT シグナル受信
                ret

;-------------------------------------------------------------------------
; シグナルによるプログラム停止時の処理
;-------------------------------------------------------------------------
RangeError:
                lea     rax, [Range_msg]    ; 範囲エラーメッセージ
                call    OutAsciiZ
                xor     ecx, ecx
                mov     cl, '#'             ; 行番号
                mov     rax, [rbp+rcx*8]
                call    PrintLeft
                mov     al, ','
                call    OutChar
                mov     cl, '!'
                mov     rax, [rbp+rcx*8]    ; 呼び出し元行番号
                call    PrintLeft
                call    NewLine
WarmInit:
                call    CheckCGI            ; CGIモードなら終了
WarmInit2:
                mov     byte[rbp-4], 0      ; Read from console
WarmInit1:
                xor     ecx, ecx
                xor     eax, eax
                inc     eax                 ; 1
                mov     cl, '['             ; 範囲チェックON
                mov     [rbp+rcx*8], rax
                mov     r14b, al            ; EOL=yes
                dec     eax                 ; 0
                mov     rdi, exarg          ; execve 引数配列初期化
                mov     [rdi], rax
                mov     [rbp-29], al        ; 各種のエラー無し
                mov     [rbp-3], al         ; ExecMode=Direct
                mov     [rbp-1], al         ; LSTACK
                mov     [rbp-28], rax       ; VSTACK
                ret

;-------------------------------------------------------------------------
; 変数への代入, FOR文処理
; EAX に変数名を設定して呼び出される
;-------------------------------------------------------------------------
SetVar:         ; 変数代入
                call    SkipAlpha           ; 変数の冗長部分の読み飛ばし
                push    rdi
                lea     rdi, [rbp+rbx*8]    ; 変数のアドレス
                cmp     al, '='
                je      .var
                cmp     al, '('
                je      .array1
                cmp     al, '{'
                je      .array2
                cmp     al, '['
                je      .array4
                cmp     al, ';'
                je      .array8
                cmp     al, '*'
                je      .strptr
                pop     rdi
                jmp     Com_Error

    .var:       ; 単純変数
                call    Exp                 ; 式の処理(先読み無しで呼ぶ)
                mov     [rdi], rax          ; 変数に代入
                mov     rbx, rax
                pop     rdi
                xor     eax, eax
                mov     al, [rsi-1]
                cmp     al, ','             ; FOR文か?
                jne     .exit
                cmp     byte[rbp-3], 0      ; ExecMode=Direct
                jne     .for
                lea     rax, [no_direct_mode]
                call    OutAsciiZ
                pop     rbx                 ; スタック修正
                call    WarmInit
                jmp     MainLoop
    .for:
                mov     byte[rbp-32], 0     ; 昇順
                call    Exp                 ; 終了値
                cmp     rax, rbx            ; 開始値と終了値を比較
                jge     .asc
                mov     byte[rbp-32], 1     ; 降順 (開始値 >= 終了値)
    .asc:
                call    PushValue           ; 終了値を退避(NEXT部で判定)
                call    PushLine            ; For文の直後を退避
    .exit:      ret

    .array1:    call    .array
                jb      .range_err          ; 範囲外をアクセス
                mov     [rdi+rbx], al       ; 代入
                pop     rdi
                ret

    .array2:    call    .array
                jb      .range_err          ; 範囲外をアクセス
                mov     [rdi+rbx*2], ax     ; 代入
                pop     rdi
                ret

    .array4:    call    .array
                jb      .range_err          ; 範囲外をアクセス
                mov     [rdi+rbx*4], eax    ; 代入
                pop     rdi
                ret

    .array8:    call    .array
                jb      .range_err          ; 範囲外をアクセス
                mov     [rdi+rbx*8], rax    ; 代入
                pop     rdi
                ret

    .range_err:
                call    RangeError          ; アクセス可能範囲を超えた
                pop     rdi
                ret

    .strptr:    call    GetChar
                mov     rdi, [rdi]          ; 文字列をコピー
                call    RangeCheck          ; コピー先を範囲チェック
                jb      .range_err          ; 範囲外をアクセス
                mov     al, [rsi]           ; PeekChar
                cmp     al, '"'
                jne     .sp0

                xor     ecx, ecx            ; 即値文字列コピー
                call    GetChar             ; skip "
    .next:      call    GetChar
                cmp     al, '"'
                je      .done
                or      al, al
                je      .done
                mov     [rdi + rcx], al
                inc     ecx
                cmp     ecx, FNAMEMAX
                jb      .next
    .done:
                xor     al, al
                mov     [rdi + rcx], al
                xor     ebx, ebx
                mov     bl, '%'             ; %に文字数を保存
                mov     [rbp+rbx*8], rcx
                pop     rdi
                ret

    .sp0:       call    Exp                 ; コピー元のアドレス
                cmp     rdi, rax
                je      .sp3
                push    rdi                 ; コピー先退避
                mov     rdi, rax            ; RangeCheckはrdiを見る
                call    RangeCheck          ; コピー元を範囲チェック
                pop     rdi                 ; コピー先復帰
                jb      .range_err          ; 範囲外をアクセス
                push    rsi
                mov     rsi, rax
                xor     ecx, ecx
    .sp1:
                mov     al, [rsi+rcx]
                mov     [rdi+rcx], al
                inc     rcx
                cmp     rcx, 256*1024       ; 256KB
                je      .sp2
                or      al, al
                jne     .sp1
    .sp2:
                dec     rcx
                xor     ebx, ebx
                mov     bl, '%'             ; %に文字数を保存
                mov     [rbp+rbx*8], rcx
                pop     rsi
                pop     rdi
                ret

    .sp3:       call    StrLen
                xor     ebx, ebx
                mov     bl, '%'             ; %に文字数を保存
                mov     [rbp+rbx*8], rax
                pop     rdi
                ret

    .array:     call    Exp                 ; 配列インデックス
                mov     rbx, rax
                mov     rdi, [rdi]
                call    SkipCharExp         ; 式の処理(先読み無しで呼ぶ)
                call    RangeCheck          ; 範囲チェック
                ret

;-------------------------------------------------------------------------
; 配列のアクセス可能範囲をチェック
; , < rdi < *
;-------------------------------------------------------------------------
RangeCheck:
                push    rax
                push    rbx
                push    rcx
                xor     ecx, ecx
                mov     cl, '['             ; 範囲チェックフラグ
                mov     rax, [rbp+rcx*8]
                test    rax, rax
                je      .exit               ; 0 ならチェックしない
                lea     rax, [input2]
                cmp     rdi, rax            ; if addr=input2
                je      .exit               ; インプットバッファはOK
                mov     cl, ','             ; プログラム先頭
                mov     rax, [rbp+rcx*8]
                mov     cl, '*'             ; RAM末
                mov     rbx, [rbp+rcx*8]
                cmp     rdi, rax            ; if = > addr, stc
                jb      .exit
                cmp     rbx, rdi            ; if * < addr, stc
    .exit       pop     rcx
                pop     rbx
                pop     rax
                ret

;-------------------------------------------------------------------------
; 変数の冗長部分の読み飛ばし
;   変数名をrbxに退避, 次の文字をraxに返す
;   SetVar, Variable で使用
;-------------------------------------------------------------------------
SkipAlpha:
                mov     ebx, eax            ; 変数名をebxに退避
    .next:      call    GetChar
                call    IsAlpha
                jb      .exit
                jmp     short .next
    .exit:      ret

;-------------------------------------------------------------------------
; 行の編集
;   rax 行番号
;-------------------------------------------------------------------------
LineEdit:
                call    LineSearch          ; 入力済み行番号を探索
                jae     .exit
                mov     rsi, input          ; 入力バッファ
                mov     eax, [rdi+4]        ; 行番号
                call    PutDecimal          ; 行番号書き込み
                mov     al, ' '
                mov     [rsi], al
                inc     rsi
                lea     rdi, [rdi + 8]
    .copy:      mov     al, [rdi]           ; 入力バッファにコピー
                mov     [rsi], al
                cmp     al, 0
                je      .done
                inc     rsi
                inc     rdi
                jmp     short .copy
    .done:
                call    DispPrompt
                mov     eax, MAXLINE        ; 1 行入力
                lea     rbx, [input]
                call    READ_LINE2
                mov     rsi, rbx
    .exit:
                mov     r14b, 0             ; EOL=no, 入力済み
                ret

;-------------------------------------------------------------------------
; ListMore
;   rax に表示開始行番号
;-------------------------------------------------------------------------
ListMore:
                call    LineSearch          ; 表示開始行を検索
                call    GetChar             ; skip '+'
                call    Decimal             ; 表示行数を取得
                jnb     .list
    .default:   xor     ebx, ebx            ; 表示行数無指定は20行
                mov     bl, 20
    .list:      push    rdi
    .count:     mov     eax, [rdi]          ; 次行までのオフセット
                or      eax, eax
                js      .all                ; コード最終か?
                dec     rbx
                mov     edx, [rdi+4]        ; 行番号
                add     rdi, rax            ; オフセットを加算
                or      ebx, ebx
                jne     .count
                pop     rdi
                jmp     short List.loop

    .all        pop     rdi                 ;
                jmp     short List.all      ; コード最終まで

;-------------------------------------------------------------------------
; List
;   rax に表示開始行番号, rdi に表示行先頭アドレス
;-------------------------------------------------------------------------
List:
                test    rax, rax
                jne     .partial
                xor     ebx, ebx
                mov     bl, '='
                mov     rdi, [rbp+rbx*8]    ; コード先頭アドレス
                jmp     short .all
    .partial:
                call    LineSearch          ; 表示開始行を検索
                call    GetChar             ; 仕様では -
                call    Decimal             ; 範囲最終を取得
                jb      .all
                mov     rdx, rbx            ; 終了行番号
                jmp     short .loop
    .all:       xor     edx, edx
                dec     edx                 ; 最終まで表示(最大値)
    .loop:      mov     eax, [rdi]          ; 次行までのオフセット
                or      eax, eax
                js      .exit               ; コード最終か?
                mov     eax, [rdi+4]        ; 行番号
                cmp     edx, eax
                jb      .exit
                call    PrintLeft           ; 行番号表示
                mov     al, ' '
                call    OutChar
                mov     ebx, 8
    .code:      mov     al, [rdi + rbx]     ; コード部分表示
                cmp     al, 0
                je      .next
                call    OutChar
                inc     ebx
                jmp     short .code
    .next:      mov     eax, [rdi]          ; オフセットは32bit
                add     rdi, rax
                call    NewLine
                jmp     short .loop         ; 次行処理

    .exit:      mov     r14b, 1             ; 次に行入力 EOL=yes
                ret

;-------------------------------------------------------------------------
;  編集モード
;       0) 行番号 0 ならリスト
;       1) 行が行番号のみの場合は行削除
;       2) 行番号の直後が - なら行番号指定部分リスト
;       3) 行番号の直後が + なら行数指定部分リスト
;       4) 行番号の直後が ! なら指定行編集
;       5) 同じ行番号の行が存在すれば入れ替え
;       6) 同じ行番号がなければ挿入
;-------------------------------------------------------------------------
EditMode:
                call    Decimal             ; ebx に行番号取得
                xchg    rax, rbx            ; rax:行番号, rbx:次の文字
                test    rax, rax
                je      List                ; 行番号 0 ならリスト
                cmp     bl, 0               ; 行番号のみか
                je      near LineDelete     ; 行削除
                cmp     bl, '-'
                je      List                ; 部分リスト
                cmp     bl, '+'
                je      near ListMore       ; 部分リスト 20行
%ifdef DEBUG
                cmp     bl, '#'
                je      near DebugList      ; デバッグ用行リスト(#)
                cmp     bl, '$'
                je      near VarList        ; デバッグ用変数リスト($)
                cmp     bl, '%'
                je      near DumpList       ; デバッグ用ダンプリスト(%)
                cmp     bl, '&'
                je      near LabelList      ; デバッグ用ラベルリスト(&)
%endif

    .edit:      cmp     bl, '!'
                je      near LineEdit       ; 指定行編集
                call    LineSearch          ; 入力済み行番号を探索
                jae     LineInsert          ; 一致する行がなければ挿入
                call    LineDelete          ; 行置換(行削除+挿入)
LineInsert:
                xor     ecx, ecx            ; 挿入する行のサイズを計算
    .next:      cmp     byte[rsi+rcx], 0    ; rsi:コード部先頭
                je      .done               ; EOL発見 (rcx には n-1)
                inc     ecx                 ; 次の文字
                jmp     short .next
    .done:
                lea     ecx, [ecx + 12]     ; rcx に挿入サイズ(+8+1+3)
                and     ecx, 0xfffffffc     ; 4バイト境界に整列
                push    rax                 ; 行番号退避
                mov     rax, rdi            ; 挿入ポイント退避
                push    rsi                 ; 挿入用ギャップ作成
                push    rdi                 ; 挿入位置
                push    rcx                 ; 挿入量退避
                xor     ebx, ebx
                mov     bl, '&'             ; ヒープ先頭システム変数取得
                mov     rdx, [rbp+rbx*8]
                mov     rdi, rdx
                add     rdi, rcx            ; 新ヒープ先頭計算
                mov     [rbp+rbx*8], rdi    ; 新ヒープ先頭設定
                mov     rsi, rdx            ; 元の &
                sub     rdx, rax            ; 移動サイズ=元& - 挿入位置
                dec     rsi                 ; 始めは old &-1 から
                dec     rdi                 ; new &-1 へのコピー
                mov     rcx, rdx
                std                         ; メモリ後部から移動
            rep movsb
                cld
                pop     rcx                 ; 挿入量復帰
                pop     rdi                 ; 挿入ポイント復帰
                pop     rsi                 ; 入力ポインタ
                pop     rax                 ; 行番号復帰

                mov     [rdi], ecx          ; 次行へのオフセット設定
                mov     [rdi+4], eax        ; 行番号設定
                mov     eax, 8
                add     rdi, rax            ; 書き込み位置更新
                sub     rcx, rax            ; 書き込みサイズ更新
            rep movsb
                mov     r14b, 1             ; 次に行入力 EOL=yes
                ret

;-------------------------------------------------------------------------
; 行の削除
;-------------------------------------------------------------------------
                align   4
LineDelete:
                push    rsi
                push    rdi
                call    LineSearch          ; 入力済み行番号を探索
                jae     .exit
                mov     rsi, rdi            ; 削除行先頭位置
                mov     ebx, [rsi]          ; 次行先頭オフセット
                add     rsi, rbx            ; 次行先頭位置取得
                xor     ebx, ebx
                mov     bl, '&'             ; ヒープ先頭
                mov     rcx, [rbp+rbx*8]
                sub     rcx, rdi            ; rcx:移動バイト数
                cld                         ; 増加方向
        rep     movsb                       ; rcxバイト移動
                mov     [rbp+rbx*8], rdi
    .exit:      pop     rdi
                pop     rsi
                mov     r14b, 1             ; 次に行入力  EOL=yes
                ret

;-------------------------------------------------------------------------
; 入力済み行番号を探索
; rax に検索行番号
; 一致行先頭または不一致の場合には次に大きい行番号先頭位置にrdi設定
; 同じ行番号があればキャリーセット
; rbx, rdi 破壊
;-------------------------------------------------------------------------
LineSearch:
                xor     ebx, ebx
                mov     bl, '='             ; プログラム先頭
                mov     rdi, [rbp+rbx*8]

                align   4

    .nextline:  mov     ebx, [rdi]          ; コード末なら検索終了
                inc     ebx
                je      .exit
                mov     ebx, [rdi+4]        ; 行番号
                cmp     ebx, eax
                ja      .exit
                je      .found
                mov     ebx, [rdi]          ; オフセット
                add     rdi, rbx            ; 次行先頭
                jmp     short .nextline
    .exit:      clc
                ret
    .found:     stc
                ret

%ifdef DEBUG
;-------------------------------------------------------------------------
; コード範囲をチェックして範囲外ならエラー表示
; & < rsi < *
;-------------------------------------------------------------------------
CodeCheck:
                cmp     byte[rbp-3], 1      ; ExecMode=Memory ?
                je      .check
                clc                         ; ExecMode=Directなら無視
                ret

    .check:     push    rax
                push    rbx
                push    rcx
                push    rdx
                call    CheckCodeAddress
                jb      .code_error
                jmp     short .exit
    .code_error:
                mov     eax, 'L# :'
                call    OutChar4
                mov     cl, '#'             ; プログラム先頭
                mov     rax, [rbp+rcx*8]
                call    PrintLeft
                call    NewLine
                mov     eax, 'rdi:'
                call    OutChar4
                mov     rax, rdi
                call    PrintHex16
                call    NewLine
                mov     eax, 'rsi:'
                call    OutChar4
                mov     rax, rsi
                call    PrintHex16
                call    NewLine
                stc
    .exit:
                pop     rdx
                pop     rcx
                pop     rbx
                pop     rax
                ret

;-------------------------------------------------------------------------
; コード範囲をチェック
; & < rsi < *
;-------------------------------------------------------------------------
CheckCodeAddress:
                xor     ecx, ecx
                mov     cl, ','             ; プログラム先頭
                mov     rax, [rbp+rcx*8]
                mov     cl, '&'             ; RAM末
                mov     rbx, [rbp+rcx*8]
                cmp     rsi, rax            ; if = > addr, stc
                jb      .exit
                cmp     rbx, rsi            ; if * < addr, stc
    .exit:
                ret

;-------------------------------------------------------------------------
; デバッグ用プログラム行リスト <xxxx> 1#
;-------------------------------------------------------------------------
DebugList:
                _PUSHA
                xor     ebx, ebx
                mov     bl, '='             ; プログラム先頭
                mov     rax, [rbp+rbx*8]
                mov     rcx, rax
                mov     rdi, rax
                call    PrintHex8           ; プログラム先頭表示
                mov     al, ' '
                call    OutChar
                mov     bl, '&'             ; ヒープ先頭
                mov     rax, [rbp+rbx*8]
                mov     rax, rcx
                call    PrintHex16           ; ヒープ先頭表示
                mov     al, ' '
                call    OutChar
                sub     rax, rcx            ; プログラム領域サイズ
                call    PrintLeft
                call    NewLine
    .L1:
                mov     rax, rdi
                call    PrintHex8           ; 行頭アドレス
                mov     esi, [rdi]          ; 次行までのオフセット
                mov     al, ' '
                call    OutChar
                mov     eax, esi
                call    PrintHex8           ; オフセットの16進表記
                mov     ecx, 4              ; 4桁右詰
                call    PrintRight          ; オフセットの10進表記
                inc     eax
                je      .L4                 ; コード最終か?
                mov     al, ' '
                call    OutChar

                mov     eax, [rdi+4]        ; 行番号
                cmp     eax, 0
                je      .L4
                call    PrintLeft           ; 行番号表示
                mov     al, ' '
                call    OutChar
                mov     ebx, 8
    .L2:
                mov     al, [rdi+rbx]       ; コード部分表示
                cmp     al, 0
                je      .L3                 ; 改行
                call    OutChar
                inc     ebx                 ; 次の1文字
                jmp     short .L2
    .L3:        call    NewLine
                add     rdi, rsi
                jmp     short .L1           ; 次行処理

    .L4:        call    NewLine
                _POPA
                ret

;-------------------------------------------------------------------------
; デバッグ用変数リスト <xxxx> 1$
;-------------------------------------------------------------------------
VarList:
                xor     ebx, ebx
                mov     bl, 0x21
    .1          mov     al, bl
                call    OutChar
                mov     al, ' '
                call    OutChar
                mov     rax, [rbp+rbx*8]    ; 変数取得
                call    PrintHex8
                mov     ecx, 12             ; 表示桁数の設定
                call    PrintRight
                call    NewLine
                inc     bl
                cmp     bl, 0x7F
                jb      .1
                ret

;-------------------------------------------------------------------------
; デバッグ用ダンプリスト <xxxx> 1%
;-------------------------------------------------------------------------
DumpList:
                _PUSHA
                xor     ebx, ebx
                mov     bl, '='             ; プログラム先頭
                mov     rdx, [rbp+rbx*8]

                and     dl, 0xf0            ; 16byte境界から始める
                mov     rdi, rdx
                mov     bl, 8
    .1:
                mov     rax, rdi
                call    PrintHex8           ; 先頭アドレス表示
                mov     al, ' '
                call    OutChar
                mov     al, ':'
                call    OutChar
                xor     ecx, ecx
                mov     cl,16
    .loop:
                mov     al, ' '
                call    OutChar
                mov     al, [rdi]           ; 1バイト表示
                call    PrintHex2
                inc     rdi
                loop    .loop
                call    NewLine
                dec     bl
                jnz     .1                  ; 次行処理
                _POPA
                ret

;-------------------------------------------------------------------------
; デバッグ用ラベルリスト <xxxx> 1&
;-------------------------------------------------------------------------
LabelList:
                _PUSHA
                call    LabelScan            ; 2010/05/03
                lea     rbx, [LabelTable]    ; ラベルテーブル先頭
                mov     rax, rbx
                call    PrintHex16
                call    NewLine
                lea     rcx, [TablePointer]
                mov     rax, rcx
                call    PrintHex16
                call    NewLine
                mov     rcx, [rcx]           ; テーブル最終登録位置
    .1:
                cmp     rbx, rcx
                jge     .2
                mov     rax, [rbx+24]
                call    PrintHex16
                mov     al, ' '
                call    OutChar
                mov     rax, rbx
                call    OutAsciiZ
                call    NewLine
                lea     rbx, [rbx - 32]
                jmp     short .1
    .2:
                _POPA
                ret
%endif

;-------------------------------------------------------------------------
; SkipEqualExp  = に続く式の評価
; SkipCharExp   1文字を読み飛ばした後 式の評価
; Exp           式の評価
; rax に値を返す (先読み無しで呼び出し, 1文字先読みで返る)
; rbx, rcx, rdx, rdi 保存
;-------------------------------------------------------------------------
SkipEqualExp:
                call    GetChar             ; check =
SkipEqualExp2:  cmp     al, '='             ; 先読みの時
                je      Exp
                lea     rax, [equal_err]    ;
                call    OutAsciiZ
                                            ; スタック修正(LongJumpでも可？)
                pop     rbx                 ; コマンド内の次の命令を廃棄
                pop     rbx                 ; call [各Command]の次を廃棄
                jmp     SyntaxError         ; 文法エラー

SkipCharExp:
                call    GetChar             ; skip a character
Exp:
                mov     al, [rsi]           ; PeekChar
                cmp     al, ' '
                jne     .ok
                or      byte[rbp-29], ERR_SPACE ; 式中の空白はエラー
                jmp     LongJump            ; トップレベルに戻る

    .ok:
                _PUSHA
                call    Factor
    .next:
                cmp     al,  '+'            ; ADD
                jne     .sub
                push    rbx                 ; 項の値を退避
                call    Factor              ; 右項を取得
                mov     rcx, rbx            ; 右項を rcx に設定
                pop     rbx                 ; 左の項を復帰
                add     rbx, rcx            ; 2項を加算
                jmp     short .next
    .sub:       cmp     al,  '-'            ; SUB
                jne     .mul
                push    rbx                 ; 項の値を退避
                call    Factor              ; 右項を取得
                mov     rcx, rbx            ; 右項を rcx に設定
                pop     rbx                 ; 左の項を復帰
                sub     rbx, rcx            ; 左項から右項を減算
                jmp     short .next
    .mul:       cmp     al,  '*'            ; MUL
                jne     .div
                push    rbx                 ; 項の値を退避
                call    Factor              ; 右項を取得
                mov     rcx, rbx            ; 右項を rcx に設定
                pop     rbx                 ; 左の項を復帰
                push    rax
                mov     rax, rbx
                imul    rcx                 ; 符号付乗算
                mov     rbx, rax
                pop     rax
                jmp     short .next
    .div:       cmp     al,  '/'            ; DIV
                jne     .udiv
                push    rbx                 ; 項の値を退避
                call    Factor              ; 右項を取得
                mov     rcx, rbx            ; 右項を rcx に設定
                pop     rbx                 ; 左の項を復帰
                or      rcx, rcx
                jne     .div1
                or      byte[rbp-29], ERR_DIVZERO ; ０除算エラー
                jmp     .exit
    .div1:      push    rax
                mov     rax, rbx
                cqo                         ; rax-->rdx:rax(sign-extend)
                idiv    rcx                 ; 右項で左項を除算
                xor     ecx, ecx
                mov     cl, '%'             ; 剰余の保存
                mov     [rbp+rcx*8], rdx
                mov     rbx, rax            ; 商を rbx に
                pop     rax
    .next2:     jmp     short .next
    .udiv:      cmp     al,  '\'            ; UDIV
                jne     .and
                push    rbx                 ; 項の値を退避
                call    Factor              ; 右項を取得
                mov     rcx, rbx            ; 右項を rcx に設定
                pop     rbx                 ; 左の項を復帰
                or      rcx, rcx
                jne     .udiv1
                or      byte[rbp-29], ERR_DIVZERO ; ０除算エラー
                jmp     .exit
    .udiv1:     push    rax
                mov     rax, rbx
                xor     edx, edx            ; rax-->rdx:rax
                div     rcx                 ; 右項で左項を除算
                xor     ecx, ecx
                mov     cl, '%'             ; 剰余の保存
                mov     [rbp+rcx*8], rdx
                mov     rbx, rax            ; 商を rbx に
                pop     rax
                jmp     short .next2
    .and:       cmp     al, '&'             ; AND
                jne     .or
                push    rbx                 ; 項の値を退避
                call    Factor              ; 右項を取得
                mov     rcx, rbx            ; 右項を rcx に設定
                pop     rbx                 ; 左の項を復帰
                and     rbx, rcx            ; 左項と右項をAND
                jmp     short .next2
    .or:        cmp     al,  '|'            ; OR
                jne     .xor
                push    rbx                 ; 項の値を退避
                call    Factor              ; 右項を取得
                mov     rcx, rbx            ; 右項を rcx に設定
                pop     rbx                 ; 左の項を復帰
                or      rbx, rcx            ; 左項と右項を OR
                jmp     short .next2
    .xor:       cmp     al,  '^'            ; XOR
                jne     .equal
                push    rbx                 ; 項の値を退避
                call    Factor              ; 右項を取得
                mov     rcx, rbx            ; 右項を rcx に設定
                pop     rbx                 ; 左の項を復帰
                xor     rbx, rcx            ; 左項と右項を XOR
                jmp     short .next2
    .equal:     cmp     al,  '='            ; =
                jne     .exp7
                push    rbx                 ; 項の値を退避
                call    Factor              ; 右項を取得
                mov     rcx, rbx            ; 右項を rcx に設定
                pop     rbx                 ; 左の項を復帰
                cmp     rbx, rcx            ; 左項と右項を比較
                jne     .false
    .true:      xor     ebx, ebx
                inc     rbx                 ; 1:真
                jmp     .next
    .false:     xor     ebx, ebx            ; 0:偽
    .next3:     jmp     .next
    .exp7:      cmp     al,  '<'            ; <
                jne     .exp8
                mov     al, [rsi]           ; PeekChar
                cmp     al,  '='            ; <=
                je      .exp71
                cmp     al,  '>'            ; <>
                je      .exp72
                cmp     al,  '<'            ; <<
                je      .shl
                                            ; <
                push    rbx                 ; 項の値を退避
                call    Factor              ; 右項を取得
                mov     rcx, rbx            ; 右項を rcx に設定
                pop     rbx                 ; 左の項を復帰
                cmp     rbx, rcx            ; 左項と右項を比較
                jge     .false
                jmp     short .true
    .exp71:     call    GetChar             ; <=
                push    rbx                 ; 項の値を退避
                call    Factor              ; 右項を取得
                mov     rcx, rbx            ; 右項を rcx に設定
                pop     rbx                 ; 左の項を復帰
                cmp     rbx, rcx            ; 左項と右項を比較
                jg      .false
                jmp     short .true
    .exp72:     call    GetChar             ; <>
                push    rbx                 ; 項の値を退避
                call    Factor              ; 右項を取得
                mov     rcx, rbx            ; 右項を rcx に設定
                pop     rbx                 ; 左の項を復帰
                cmp     rbx, rcx            ; 左項と右項を比較
                je      .false
    .true2:     jmp     short .true
    .false2     jmp     short .false
    .shl:       call    GetChar             ; <<
                push    rbx                 ; 項の値を退避
                call    Factor              ; 右項を取得
                cmp     ebx, 64             ; 32以上は結果を0に固定
                jae     .zero
                mov     rcx, rbx            ; 右項を rcx に設定
                pop     rbx                 ; 左の項を復帰
                shl     rbx, cl             ; 左項を右項で SHL (*2)
    .next4:     jmp     short .next3
    .zero:      pop     rbx
                xor     ebx, ebx
                jmp     short .next3

    .exp8:      cmp     al,  '>'            ; >
                jne     .exp9
                mov     al, [rsi]           ; PeekChar
                cmp     al,  '='            ; >=
                je      .exp81
                cmp     al,  '>'            ; >>
                je      .shr
                                            ; >
                push    rbx                 ; 項の値を退避
                call    Factor              ; 右項を取得
                mov     rcx, rbx            ; 右項を rcx に設定
                pop     rbx                 ; 左の項を復帰
                cmp     rbx, rcx            ; 左項と右項を比較
                jle     .false2
                jmp     short .true2
    .exp81:     call    GetChar             ; >=
                push    rbx                 ; 項の値を退避
                call    Factor              ; 右項を取得
                mov     rcx, rbx            ; 右項を rcx に設定
                pop     rbx                 ; 左の項を復帰
                cmp     rbx, rcx            ; 左項と右項を比較
                jl      .false2
                jmp     short .true2
    .shr:       call    GetChar             ; >>
                push    rbx                 ; 項の値を退避
                call    Factor              ; 右項を取得
                cmp     ebx, 64             ; 32以上は結果を0に固定
                jae     .zero
                mov     rcx, rbx            ; 右項を rcx に設定
    .shr2:      pop     rbx                 ; 左の項を復帰
                shr     rbx, cl             ; 左項を右項で SHR (/2)
                jmp     short .next4
    .exp9:
    .exit:
                mov     [rsp+48], rbx       ; rax に返す
                mov     [rsp+ 8], rsi       ; rsi に返す
                _POPA
                ret

;-------------------------------------------------------------------------
; UNIX時間をマイクロ秒単位で返す
;-------------------------------------------------------------------------
GetTime:
                push    rdi
                push    rsi
                mov     rdi, TV
                mov     eax, SYS_gettimeofday
                lea     rsi, [rdi + 16]     ; TZ
                syscall
                mov     rbx, [rdi]          ; sec  (64bit)
                mov     rax, [rdi + 8]      ; usec (64bit)
                xor     ecx, ecx
                mov     cl, '%'             ; 剰余に usec を保存
                mov     [rbp+rcx*8], rax
                pop     rsi
                pop     rdi
                call    GetChar
                ret

;-------------------------------------------------------------------------
; マイクロ秒単位のスリープ _=n
;-------------------------------------------------------------------------
Com_USleep:
                call    SkipEqualExp        ; = を読み飛ばした後 式の評価
                push    rdi
                push    rsi
                mov     rdi, TV
                xor     ebx, ebx
                mov     [rdi], rbx          ; sec は 0
                mov     [rdi+8], rax        ; usec
                mov     eax, SYS_select
                mov     r8,  rdi            ; timeval
                mov     rdi, rbx            ; *inp
                mov     rsi, rbx            ; nfds
                mov     rdx, rbx            ; *outp
                mov     r10, rbx            ; *exp
                syscall
                call    CheckError
                pop     rsi
                pop     rdi
                ret

;-------------------------------------------------------------------------
; 10進整数
; rbx に数値が返る, rax,rbx,rcx 使用
; 1 文字先読みで呼ばれ 1 文字先読みして返る
;-------------------------------------------------------------------------
Decimal:
                xor     ecx, ecx            ; 正の整数を仮定
                xor     ebx, ebx
                cmp     al, "+"
                je      .EatSign
                cmp     al, "-"
                jne     .Num
                inc     ecx                 ; 負の整数
    .EatSign:
                call    GetDigit
                jb      .exit               ; 数字でなければ返る
                jmp     short .NumLoop
    .Num:
                call    IsNum
                jb      .exit
                sub     al, '0'
    .NumLoop:
                imul    rbx, 10             ;
                add     rbx, rax
                call    GetDigit
                jae     .NumLoop

                or      ecx, ecx            ; 数は負か？
                je      .exit
                neg     rbx                 ; 負にする
    .exit:
                ret

;-------------------------------------------------------------------------
; 配列と変数の参照, rbx に値が返る
;-------------------------------------------------------------------------
Variable:
                call    SkipAlpha           ; 変数名は blに
                lea     rdi, [rbp+rbx*8]    ; 変数アドレス
                xor     ebx, ebx
                cmp     al, '('
                je      .array1
                cmp     al, '{'
                je      .array2
                cmp     al, '['
                je      .array4
                cmp     al, ';'
                je      .array8
                mov     rbx, [rdi]          ; 単純変数
                ret

    .array1:    call    .array
                jb      .range_err          ; 範囲外をアクセス
                mov     bl, [rdi + rax]
                call    GetChar             ; skip )
                ret

    .array2:    call    .array
                jb      .range_err          ; 範囲外をアクセス
                mov     bx, [rdi + rax * 2]
                call    GetChar             ; skip }
                ret

    .array4:    call    .array
                jb      .range_err          ; 範囲外をアクセス
                mov     ebx, [rdi + rax * 4]
                movsx   rbx, ebx            ; 符号拡張
;                mov     ebx, ebx            ; ゼロ拡張
                call    GetChar             ; skip ]
                ret

    .array8:    call    .array
                jb      .range_err          ; 範囲外をアクセス
                mov     rbx, [rdi + rax * 8]
                call    GetChar             ; skip !
                ret

    .array:     call    Exp                 ; 1バイト配列
                mov     rdi, [rdi]
                call    RangeCheck          ; 範囲チェック
                ret

    .range_err:
                call    RangeError
                ret

;-------------------------------------------------------------------------
; 変数値
; rbx に値を返す (先読み無しで呼び出し, 1文字先読みで返る)
;-------------------------------------------------------------------------
Factor:
                call    GetChar
                call    IsNum
                jb      .bracket
                call    Decimal             ; 正の10進整数
                ret

    .bracket:   cmp     al, '('
                jne     .yen
                call    Exp                 ; カッコ処理
                mov     rbx, rax            ; 項の値は rbx
                call    GetChar             ; skip )
                ret

    .yen:       cmp     al, '\'
                jne     .rand
                mov     al, [rsi]           ; Peek Char
                cmp     al, '\'
                je      .env
                call    Exp                 ; 引数番号を示す式
                lea     rdx, [argc_vtl]
                mov     rcx, [rdx]          ; vtl用の引数の個数
                cmp     rax, rcx            ; 引数番号と引数の数を比較
                jl      .L2                 ; 引数番号 < 引数の数
                mov     rbx, [rdx - 8]      ; argvp
                mov     rbx, [rbx]
    .L1:        mov     cl, [rbx]           ; 0を探す
                inc     rbx
                or      cl, cl
                jne     .L1
                dec     rbx                 ; argv[0]のEOLに設定
                jmp     short .L3
    .L2:        mov     rbx, [rdx + 8]      ; found [argp_vtl]
                mov     rbx, [rbx + rax*8]  ; 引数文字列先頭アドレス
    .L3:        ret

    .env:
                call    GetChar             ; skip '\'
                call    Exp                 ; 引数番号を示す式
                mov     rdx, [envp]
                xor     ecx, ecx
    .L4:        cmp     dword[rdx+rcx*8], 0 ; 環境変数の数をカウント
                je      .L5
                inc     rcx
                jmp     short .L4
    .L5:
                cmp     rax, rcx
                jge     short .L6           ; 引数番号が過大
                mov     rbx, [rdx + rax*8]  ; 引数文字列先頭アドレス
                ret
    .L6:        lea     rbx, [rdx + rcx*8]  ; null pointer を返す
                ret

    .rand:      cmp     al, '`'
                jne     .hex
                call    genrand             ; 乱数の読み出し
                mov     rbx, rax
                call    GetChar
                ret

    .hex:       cmp     al, '$'
                jne     .time
                call    Hex                 ; 16進数または1文字入力
                ret

    .time:      cmp     al, '_'
                jne     .num
                call    GetTime             ; 時間を返す
                ret

    .num:       cmp     al, '?'
                jne     .char
                call    NumInput            ; 数値入力
                ret

    .char:      cmp     al, 0x27
                jne     .singnzex
                call    CharConst           ; 文字定数
                ret

    .singnzex:  cmp     al, '<'
                jne     .neg
                call    Factor
                mov     ebx, ebx            ; ゼロ拡張
                ret

    .neg:       cmp     al, '-'
                jne     .abs
                call    Factor              ; 負符号
                neg     rbx
                ret

    .abs:       cmp     al, '+'
                jne     .realkey
                call    Factor              ; 変数，配列の絶対値
                or      rbx, rbx
                jns     .exit
                neg     rbx
                ret

    .realkey:   cmp     al, '@'
                jne     .winsize
                call    RealKey             ; リアルタイムキー入力
                mov     rbx, rax
                call    GetChar
                ret

    .winsize:   cmp     al, '.'
                jne     .pop
                call    WinSize             ; ウィンドウサイズ取得
                mov     rbx, rax
                call    GetChar
                ret

    .pop:       cmp     al, ';'
                jne     .label
                mov     rcx, [rbp-28]       ; VSTACK
                dec     rcx
                jge     .pop2
                or      byte [rbp-29], ERR_VSTACK ; 変数スタックエラー
                jmp     short .pop3
    .pop2:
                mov     rbx, [rbp+rcx*8+2048]    ; 変数スタックから復帰
                mov     [rbp-28], rcx       ; スタックポインタ更新
    .pop3:      call    GetChar
                ret

    .label:
%ifdef VTL_LABEL
                cmp     al, '^'
                jne     .var
                call    LabelSearch         ; ラベルのアドレスを取得
                jae     .label2
                or      byte [rbp-29], ERR_NOLABEL ; ラベル未定義エラー
                call    GetChar
    .label2:
                ret
%endif

    .var:
                call    Variable            ; 変数，配列参照
    .exit       ret

;-------------------------------------------------------------------------
; コンソールから数値入力
;-------------------------------------------------------------------------
NumInput:
                mov     al, r14b            ; EOL状態退避
                push    rax
                push    rsi
                mov     eax, MAXLINE        ; 1 行入力
                lea     rbx, [input2]       ; 行ワークエリア
                call    READ_LINE3
                mov     rsi, rbx
                lodsb                       ; 1文字先読み
                call    Decimal
                pop     rsi
                pop     rax
                mov     r14b, al            ; EOL状態復帰
                call    GetChar
                ret

;-------------------------------------------------------------------------
; コンソールから input2 に文字列入力
;-------------------------------------------------------------------------
StringInput:
                mov     al, r14b            ; EOL状態退避
                push    rax
                mov     eax, MAXLINE        ; 1 行入力
                lea     rbx, [input2]       ; 行ワークエリア
                call    READ_LINE3
                xor     edx, edx
                mov     dl, '%'             ; %に文字数を保存
                mov     [rbp + rdx*8], rax
                pop     rax
                mov     r14b, al            ; EOL状態復帰
                call    GetChar
                ret

;-------------------------------------------------------------------------
; 文字定数を数値に変換
; rbx に数値が返る, rax,rbx,rcx使用
;-------------------------------------------------------------------------
CharConst:
                xor     ebx, ebx
                mov     ecx, 8              ; 文字定数は8バイトまで
    .next:      call    GetChar
                cmp     al, 0x27            ; '''
                je      .exit
                shl     rbx, 8
                add     rbx, rax
                loop    .next
    .exit:      call    GetChar
                ret

;-------------------------------------------------------------------------
; 16進整数の文字列を数値に変換
; rbx に数値が返る, rax,rbx 使用
;-------------------------------------------------------------------------
Hex:
                xor     ebx, ebx
                xor     ecx, ecx
                mov     al, [rsi]           ; string input
                cmp     al, '$'             ; string input
                je      StringInput         ; string input
    .next:      call    GetChar             ; $ の次の文字
                call    IsNum
                jb      .hex1
                sub     al, '0'             ; 整数に変換
                jmp     short .num
    .hex1:      cmp     al, ' '             ; 数字以外
                je      .exit
                cmp     al, 'A'
                jb      .exit               ; 'A' より小なら
                cmp     al, 'F'
                ja      .hex2
                sub     al, 55              ; -'A'+10 = -55
                jmp     short .num
    .hex2:      cmp     al, 'a'
                jb      .exit
                cmp     al, 'f'
                ja      .exit
                sub     al, 87              ; -'a'+10 = -87
    .num:
                shl     rbx, 4
                add     rbx, rax
                inc     rcx
                jmp     short .next
    .exit:      test    rcx, rcx
                je      CharInput
                ret

;-------------------------------------------------------------------------
; ソースコードを1文字読み込む
; rsi の示す文字を rax に読み込み, rsi を次の位置に更新
;-------------------------------------------------------------------------
GetChar:
%ifdef DEBUG
                call    CodeCheck           ; rsi の値チェック
                jae     .continue
                mov     eax, 'Getc'
                call    OutChar4
                call    NewLine
    .continue:
%endif

                xor     eax, eax
                cmp     r14b, 1             ; EOL=yes
                je      .exit
                mov     al, [rsi]
                or      al, al
                cmove   r14, r13     ; EOL=yes
                inc     rsi
    .exit:      ret

;-------------------------------------------------------------------------
; コンソールから 1 文字入力, EBXに返す
;-------------------------------------------------------------------------
CharInput:
                push    rax                 ; 次の文字を保存
                call    InChar
                mov     rbx, rax
                pop     rax
                ret

;---------------------------------------------------------------------
; AL の文字が数字かどうかのチェック
; 数字なら整数に変換して AL 返す. 非数字ならキャリーセット
; ! 16進数と文字定数の処理を加えること
;---------------------------------------------------------------------

IsNum:          cmp     al, "0"             ; 0 - 9
                jb      IsAlpha2.no
                cmp     al, "9"
                ja      IsAlpha2.no
                clc
                ret
GetDigit:
                call    GetChar             ; 0 - 9
                call    IsNum
                jb      IsAlpha2.no
                sub     al, '0'             ; 整数に変換
                clc
                ret

IsAlpha:        call    IsAlpha1            ; 英文字か?
                jae     .yes
                call    IsAlpha2
                jb      IsAlpha2.no
    .yes:       clc
                ret

IsAlpha1:       cmp     al, "A"             ; 英大文字(A-Z)か?
                jb      IsAlpha2.no
                cmp     al, "Z"
                ja      IsAlpha2.no
                clc
                ret

IsAlpha2:       cmp     al, "a"             ; 英小文字(a-z)か?
                jb      .no
                cmp     al, "z"
                ja      .no
                clc
                ret
    .no:        stc
                ret

IsAlphaNum:     call    IsAlpha             ; 英文字か?
                jae     .yes
                call    IsNum
                jb      IsAlpha2.no
    .yes:       clc
                ret


;-------------------------------------------------------------------------
; コマンドラインで指定されたVTLコードファイルをロード
;   オープンの有無は jg で判断、オープンなら真
;-------------------------------------------------------------------------
LoadCode:
                push    rcx
                push    rdi
                push    rsi
                mov     rdi, current_arg    ; 処理済みの引数
                mov     rcx, [rdi]
                inc     rcx                 ; カウントアップ
                cmp     [rdi+8], rcx        ; argc 引数の個数
                je      .exit
                mov     [rdi], rcx
                mov     rsi, [rdi+16]       ; argvp 引数配列先頭
                mov     rsi, [rsi+rcx*8]    ; 引数取得
                mov     rdi, FileName
                mov     ecx, FNAMEMAX
    .next:      mov     al, [rsi]
                mov     [rdi], al
                or      al, al
                je      .open
                inc     rsi
                inc     rdi
                loop    .next
    .open:
                lea     rbx, [FileName]     ; ファイルオープン
                call    fropen              ; open
                jle     .exit
                mov     [rbp-12], rax       ; FileDesc
                mov     byte[rbp-4], 1      ; Read from file
                mov     r14b, 1             ; EOL=yes
    .exit:      pop     rsi
                pop     rdi
                pop     rcx
                ret

;-------------------------------------------------------------------------
; vtlファイル1行読み込み
;-------------------------------------------------------------------------
READ_FILE:
                mov     rsi, input
                mov     rdi, [rbp-12]       ; FileDesc
    .next:
                mov     eax, SYS_read       ; システムコール番号
                mov     edx, 1              ; 読みこみバイト数
                syscall                     ; ファイルから読みこみ
                test    rax, rax
                je      .end                ; EOF
                cmp     byte[rsi], 10       ; LineFeed
                je      .exit
                inc     rsi
                jmp     short .next
    .end:                                   ; ファイル末の場合
                mov     rbx, [rbp-12]       ; FileDesc
                call    fclose              ; File Close
                mov     byte[rbp-4], 0      ; Read from console
                call    LoadCode            ; 次のファイルをオープン
                jmp     short .skip
    .exit:      mov     r14b, 0             ; EOL=no
    .skip:      mov     byte [rsi], 0
                mov     rsi, input
                ret

;-------------------------------------------------------------------------
; 符号無し10進数文字列メモリ書き込み
;   rsi の示すメモリに書き込み
;-------------------------------------------------------------------------
PutDecimal:
                push    rax
                push    rbx
                push    rcx
                push    rdx
                xor     ecx, ecx
                mov     ebx, 10
    .PL1:       xor     edx, edx            ; 上位桁を 0 に
                div     rbx                 ; 10 で除算
                push    rdx                 ; 剰余(下位桁)をPUSH
                inc     ecx                 ; 桁数更新
                test    rax, rax            ; 終了か?
                jnz     .PL1
    .PL2:       pop     rax                 ; 上位桁から POP
                add     al,'0'              ; 文字コードに変更
                mov     [rsi], al           ; バッファに書込み
                inc     rsi
                loop    .PL2
                pop     rdx
                pop     rcx
                pop     rbx
                pop     rax
                ret

;-------------------------------------------------------------------------
; 数値出力 ?
;-------------------------------------------------------------------------
Com_OutNum:     call    GetChar             ; get next
                cmp     al, '='             ; PrintLeft
                jne     .ptn1
                call    Exp
                call    PrintLeft
                ret

    .ptn1:      cmp     al, '*'             ; 符号無し10進
                je      .unsigned
                cmp     al, '$'             ; ?$ 16進2桁
                je      .hex2
                cmp     al, '#'             ; ?# 16進4桁
                je      .hex4
                cmp     al, '?'             ; ?? 16進8桁
                je      .hex8
                cmp     al, '%'             ; ?% 16進16桁
                je      .hex16
                jmp     short .ptn2

    .unsigned:  call    SkipEqualExp     ; 1文字を読み飛ばした後 式の評価
                call    PrintLeftU
                ret
    .hex2:      call    SkipEqualExp     ; 1文字を読み飛ばした後 式の評価
                call    PrintHex2
                ret
    .hex4:      call    SkipEqualExp     ; 1文字を読み飛ばした後 式の評価
                call    PrintHex4
                ret
    .hex8:      call    SkipEqualExp     ; 1文字を読み飛ばした後 式の評価
                call    PrintHex8
                ret
    .hex16:     call    SkipEqualExp     ; 1文字を読み飛ばした後 式の評価
                call    PrintHex16
                ret

    .ptn2:      mov     dl, al
                push    rdx
                call    Exp
                mov     ecx, eax            ; 表示桁数設定
                and     ecx, 0xff           ; 桁数の最大を255に制限
                call    SkipEqualExp     ; 1文字を読み飛ばした後 式の評価
                pop     rdx
                cmp     dl, '{'             ; ?{ 8進数
                je      .oct
                cmp     dl, '!'             ; ?! 2進nビット
                je      .bin
                cmp     dl, '('             ; ?( print right
                je      .dec_right
                cmp     dl, '['             ; ?[ print right
                je      .dec_right0
    .error:     jmp     Com_Error           ; エラー

    .oct:       call    PrintOctal
                ret
    .bin:       call    PrintBinary
                ret
    .dec_right: call    PrintRight
                ret
    .dec_right0:call    PrintRight0
                ret

;-------------------------------------------------------------------------
; 文字出力 $
;-------------------------------------------------------------------------
Com_OutChar:    call    GetChar             ; get next
                cmp     al, '='
                je      .char1
                cmp     al, '$'             ; $$ 2byte
                je      .char2
                cmp     al, '#'             ; $# 4byte
                je      .char3
                cmp     al, '%'             ; $% 8byte
                je      .char4
                cmp     al, '*'             ; $*=StrPtr
                je      .char5
                ret
    .char1:     call    Exp                 ; １バイト文字
                call    OutChar
                ret
    .char2:     call    SkipEqualExp        ; ２バイト文字
                mov     rbx, rax
                mov     al, bh
                call    OutChar
                mov     al, bl
                call    OutChar
                ret
    .char3:     call    SkipEqualExp        ; ４バイト文字
                call    OutChar4B
                ret
    .char4:     call    SkipEqualExp        ; ４バイト文字
                call    OutChar8B
                ret
    .char5:     call    SkipEqualExp
                call    OutAsciiZ
                ret

;-------------------------------------------------------------------------
; 空白出力 .=n
;-------------------------------------------------------------------------
Com_Space:      call    SkipEqualExp     ; 1文字を読み飛ばした後 式の評価
                mov     rcx, rax
    .loop:      mov     al, ' '
                call    OutChar
                loop    .loop
                ret

;-------------------------------------------------------------------------
; 改行出力 /
;-------------------------------------------------------------------------
Com_NewLine:    mov     al, 10              ; LF
                call    OutChar
                ret

;-------------------------------------------------------------------------
; 文字列出力 "
;-------------------------------------------------------------------------
Com_String:     mov     rcx, rsi
                xor     edx, edx
    .next       call    GetChar
                cmp     al, '"'
                je      .exit
                cmp     r14b, 1             ; EOL=yes ?
                je      .exit
                inc     rdx
                jmp     short .next
    .exit:
                mov     rax, rcx
                call    OutString
                ret

;-------------------------------------------------------------------------
; GOTO #
;-------------------------------------------------------------------------
Com_GO:
                call    GetChar
                cmp     al, '!'
                je      .nextline           ; #! はコメント
%ifdef VTL_LABEL
                call    ClearLabel
%endif
                call    SkipEqualExp2       ; = をチェックした後 式の評価
    .go:
                cmp     byte[rbp-3], 0      ; ExecMode=Direct
                je      .label
%ifdef VTL_LABEL
                xor     ebx, ebx
                mov     bl, '^'             ; システム変数「^」の
                mov     rcx, [rbp+rbx*8]    ; チェック
                or      rcx, rcx            ; 式中でラベル参照があるか?
                je      .linenum            ; 無い場合は行番号
                mov     rdi, rcx            ; rdi を指定行の先頭アドレスへ
                xor     ecx, ecx            ; システム変数「^」クリア
                mov     [rbp+rbx*8], rcx    ; ラベル無効化
                jmp     short .check
%endif

    .linenum:   or      eax, eax            ; #=0 なら次行
                jne     .linenum2
    .nextline:  mov     r14b, 1             ; EOL=yes
                ret

    .linenum2:  cmp     eax, [rdi+4]        ; 現在の行と行番号比較
                jb      .top
                call    LineSearch.nextline ; 現在行から検索
                jmp     short .check
    .label:
%ifdef VTL_LABEL
                call    LabelScan           ; ラベルテーブル作成
%endif
    .top:       call    LineSearch          ; rdi を指定行の先頭へ
    .check:
                mov     eax, [rdi]          ; コード末チェック
                inc     eax
                je      .stop
                mov     byte[rbp-3], 1      ; ExecMode=Memory
                call    SetLineNo2          ; 行番号を # に設定
                lea     rsi, [rdi + 8]      ; 行内ポインタrsiを行先頭に
                mov     r14b, 0             ; EOL=no
                ret
    .stop:
                call    CheckCGI            ; CGIモードなら終了
                call    WarmInit1           ; 入力デバイス変更なし
                ret

%ifdef VTL_LABEL
;-------------------------------------------------------------------------
; 式中でのラベル参照結果をクリア
;-------------------------------------------------------------------------
ClearLabel:
                xor     ecx, ecx            ; システム変数「^」クリア
                xor     ebx, ebx
                mov     bl, '^'             ;
                mov     [rbp+rbx*8], rcx    ; ラベル無効化
                ret

;-------------------------------------------------------------------------
; コードをスキャンしてラベルとラベルの次の行アドレスをテーブルに登録
;-------------------------------------------------------------------------
LabelScan:
                _PUSHA
                xor     ebx, ebx
                mov     bl, '='
                mov     rdi, [rbp+rbx*8]    ; コード先頭アドレス
                mov     eax, [rdi]          ; コード末なら終了
                inc     eax
                jne     .maketable
                _POPA
                ret

    .maketable: mov     rsi, LabelTable     ; ラベルテーブル先頭
                mov     [TablePointer], rsi ; 登録する位置
                xor     ecx, ecx

    .nextline:  mov     cl, 8               ; テキスト先頭
    .space:     mov     al, [rdi+rcx]       ; 1文字取得
                cmp     al, 0
                je      .eol                ; 行末
                cmp     al, ' '             ; 空白読み飛ばし
                jne     .nextch
                inc     ecx
                jmp     short .space

    .nextch:    cmp     al, '^'             ; ラベル?
                jne     .eol

    .label:     inc     ecx                 ; ラベルテーブルに登録
                mov     rsi, [TablePointer] ; 登録位置をrsi
                mov     rax, rdi
                mov     ebx, [rdi]          ; 次行先頭オフセット
                add     rax, rbx            ; 次行先頭アドレス計算
                mov     [rsi + 24], rax     ; 次行先頭アドレス登録
                xor     edx, edx
    .label2:    mov     al, [rdi+rcx]       ; 1文字取得
                cmp     al, 0
                je      .registerd          ; 行末
                cmp     al, ' '             ; ラベルの区切りは空白
                je      .registerd          ; ラベル文字列
                cmp     rdx, 23             ; 最大23文字まで
                je      .registerd          ; 文字数上限
                mov     [rsi+rdx], al       ; 1文字登録
                inc     ecx                 ; ソースポインタ更新
                inc     edx                 ; ラベル文字列登録位置更新
                jmp     short .label2

    .registerd: mov     byte[rsi+rdx], 0    ; ラベル文字列末
                lea     rsi, [rsi + 32]
                mov     [TablePointer], rsi ; 次に登録する位置
    .eol:       mov     eax, [rdi]          ; 次行オフセット
                add     rdi, rax            ; 次行先頭
                inc     eax                 ; コード末チェック
                je      .finish             ; スキャン終了
                cmp     rsi, TablePointer   ; テーブル最終位置
                je      .finish             ; スキャン終了
                jmp     short .nextline

    .finish:    _POPA
                ret

;-------------------------------------------------------------------------
; テーブルからラベルの次の行アドレスを取得
; ラベルの次の行の先頭アドレスをrbxと「^」に設定して返る
; Factorからrsiを^の次に設定して呼ばれる
; rsi はラベルの後ろ(長すぎる場合は読み飛ばして)に設定される
;-------------------------------------------------------------------------
LabelSearch:
                _PUSHA
                lea     rdi, [LabelTable]   ; ラベルテーブル先頭
                mov     rcx, [TablePointer] ; テーブル最終位置

    .cmp_line:  xor     edx ,edx            ; ラベルの先頭から
    .cmp_ch:    mov     al, [rsi+rdx]       ; ラベルの文字
                mov     bl, [rdi+rdx]       ; テーブルと比較
                or      bl, bl              ; テーブル文字列の最後?
                jne     .cmp_ch2            ; 比較を継続
                call    IsAlphaNum
                jb      .found              ; 発見
    .cmp_ch2:   cmp     al, bl              ; 比較
                jne     .next               ; 一致しない場合は次

                inc     edx                 ; 一致したら次の文字
                cmp     dl, 23              ; 長さ
                jne     .cmp_ch             ; 次の文字を比較
                call    Skip_excess         ; 長過ぎるラベルは空白か
                                            ; 行末まで読み飛ばし
    .found:     mov     rax, [rdi+24]       ; テーブルからアドレス取得
                mov     [rsp+40], rax       ; rbx に次行先頭を返す
                xor     ebx, ebx
                mov     bl, '^'             ; システム変数「^」に
                mov     [rbp+rbx*8], rax    ; ラベルの次行先頭を設定
                add     rsi, rdx            ; ラベルの次の文字位置
                call    GetChar
                mov     [rsp+48], rax       ; rax に1文字を返す
                mov     [rsp+8], rsi        ; rsi を更新
                clc
                _POPA
                ret

    .next:      lea     rdi, [rdi + 32]     ; 次のラベルエントリー
                cmp     rdi, rcx            ; すべての登録をチェック
                je      .notfound
                cmp     rdi, TablePointer   ; ラベル領域最終？
                je      .notfound
                jmp     short .cmp_line     ; 次のテーブルエントリ

    .notfound:
                xor     edx, edx
                call    Skip_excess         ; ラベルを空白か行末まで読飛ばし
                xor     eax, eax
                mov     [rsp+40], rax       ; rbx に 0 を返す
                stc                         ; なければキャリー
                _POPA
                ret

Skip_excess:
    .skip:      mov     al, [rsi+rdx]       ; 長過ぎるラベルは
                call    IsAlphaNum
                jb      .exit
                inc     edx                 ; 読み飛ばし
                jmp     short .skip
    .exit:      ret

%endif

;-------------------------------------------------------------------------
; GOSUB !
;-------------------------------------------------------------------------
Com_GOSUB:
                cmp     byte[rbp-3], 0      ; ExecMode=Direct
                jne     .ok
                lea     rax, [no_direct_mode]
                call    OutAsciiZ
                pop     rbx                 ; スタック修正
                call    WarmInit
                jmp     MainLoop
    .ok:
%ifdef VTL_LABEL
                call    ClearLabel
%endif
                call    SkipEqualExp        ; = を読み飛ばした後 式の評価
                call    PushLine
                call    Com_GO.go
                ret

;-------------------------------------------------------------------------
; スタックへアドレスをプッシュ (行と文末位置を退避)
; rbx 変更
;-------------------------------------------------------------------------
PushLine:
                xor     ebx, ebx
                mov     bl, [rbp-1]             ; LSTACK
                cmp     bl, LSTACKMAX
                jge     StackError.over         ; overflow
                mov     [rbp+rbx*8+1024], rdi   ; push rdi
                inc     ebx
                cmp     byte [rsi-1], 0
                je      .endofline              ; 行末処理
                mov     [rbp+rbx*8+1024], rsi   ; push rsi
                jmp     short .exit
    .endofline:
                dec     rsi                     ; 1文字戻す
                mov     [rbp+rbx*8+1024], rsi   ; push rsi
                inc     rsi                     ;
    .exit       inc     ebx
                mov     [rbp-1], bl             ; LSTACK
                ret

;-------------------------------------------------------------------------
; スタックからアドレスをポップ (行と文末位置を復帰)
; rbx, rsi, rdi  変更
;-------------------------------------------------------------------------
PopLine:
                xor     ebx, ebx
                mov     bl, [rbp-1]             ; LSTACK
                cmp     bl, 2
                jl      StackError.under        ; underflow
                dec     ebx
                mov     rsi, [rbp+rbx*8+1024]   ; pop rsi
                dec     ebx
                mov     rdi, [rbp+rbx*8+1024]   ; pop rdi
                mov     [rbp-1], bl             ; LSTACK
                ret

;-------------------------------------------------------------------------
; スタックエラー
; rax 変更
;-------------------------------------------------------------------------
StackError:
    .over:      lea     rax, [stkover]
                jmp     short .print
    .under:     lea     rax, [stkunder]
    .print:     call    OutAsciiZ
                call    WarmInit
                ret

;-------------------------------------------------------------------------
; スタックへ終了条件(RAX)をプッシュ
; rbx 変更
;-------------------------------------------------------------------------
PushValue:
                xor     ebx, ebx
                mov     bl, [rbp-1]         ; LSTACK
                cmp     bl, LSTACKMAX
                jge     StackError.over
                mov     [rbp+rbx*8+1024], rax
                inc     ebx
                mov     [rbp-1], bl         ; LSTACK
                ret

;-------------------------------------------------------------------------
; スタック上の終了条件を rax に設定
; rax, rbx 変更
;-------------------------------------------------------------------------
PeekValue:
                xor     ebx, ebx
                mov     bl, [rbp-1]         ; LSTACK
                sub     bl, 3               ; 行,文末位置の前
                mov     rax, [rbp+rbx*8+1024]
                ret

;-------------------------------------------------------------------------
; スタックから終了条件(RAX)をポップ
; rax, rbx 変更
;-------------------------------------------------------------------------
PopValue:
                xor     ebx, ebx
                mov     bl, [rbp-1]         ; LSTACK
                cmp     bl, 1
                jl      StackError.under
                dec     ebx
                mov     rax, [rbp+rbx*8+1024]
                mov     [rbp-1], bl         ; LSTACK
                ret

;-------------------------------------------------------------------------
; Return ]
;-------------------------------------------------------------------------
Com_Return:
                call    PopLine             ; 現在行の後ろは無視
                mov     r14b, 0             ; not EOL
                ret

;-------------------------------------------------------------------------
; IF ; コメント :
;-------------------------------------------------------------------------
Com_IF:
                call    SkipEqualExp        ; = を読み飛ばした後 式の評価
                or      rax, rax
                jne     Com_Comment.true
Com_Comment:    mov     r14b, 1             ; 次の行へ
    .true:
                ret

;-------------------------------------------------------------------------
; 未定義コマンド処理(エラーストップ)
;-------------------------------------------------------------------------
Com_Error:
                pop     rbx                 ; スタック修正
                jmp     SyntaxError

;-------------------------------------------------------------------------
; DO UNTIL NEXT @
;-------------------------------------------------------------------------
Com_DO:
                cmp     byte[rbp-3], 0      ; ExecMode=Direct
                jne     .ok
                lea     rax, [no_direct_mode]
                call    OutAsciiZ
                pop     rbx                 ; スタック修正
                call    WarmInit
                jmp     MainLoop
    .ok:
                call    GetChar
                cmp     al, '='
                jne     .do
                mov     al, [rsi]           ; PeekChar
                cmp     al, '('             ; UNTIL?
                jne     .next               ; ( でなければ NEXT
                call    SkipCharExp         ; (を読み飛ばして式の評価
                mov     rcx, rax            ; 式の値
                call    GetChar             ; ) を読む(使わない)
                call    PeekValue           ; 終了条件
                cmp     rcx, rax            ; rax:終了条件
                jl      .continue
                jmp     short .exit
    .next:                                  ; FOR
                call    IsAlpha             ; al=[A-Za-z] ?
                jb      Com_Error
                push    rdi
                lea     rdi, [rbp+rax*8]    ; 制御変数のアドレス
                call    Exp                 ; 任意の式
                mov     rdx, [rdi]          ; 更新前の値を rbx に
                mov     [rdi], rax          ; 制御変数の更新
                pop     rdi
                mov     rcx, rax            ; 式の値
                call    PeekValue           ; 終了条件を rax に
                cmp     byte[rbp-32], 1     ; 降順 (開始値 > 終了値)
                jne     .asc

    .desc:      ; for 降順
                cmp     rdx, rcx            ; 更新前 - 更新後
                jle     Com_Error           ; 更新前が小さければエラー
                cmp     rdx, rax            ; rax:終了条件
                jg      .continue
                jmp     short .exit         ; 終了

    .asc:       ; for 昇順
                cmp     rdx, rcx            ; 更新前 - 更新後
                jge     Com_Error           ; 更新前が大きければエラー
                cmp     rdx, rax            ; rax:終了条件
                jl      .continue

    .exit:      ; ループ終了
                xor     ebx, ebx
                mov     bl, [rbp-1]         ; LSTACK=LSTACK-3
                sub     bl, 3
                mov     [rbp-1], bl         ; LSTACK
                ret

    .continue:  ; UNTIL
                xor     ebx, ebx            ; 戻りアドレス
                mov     bl, [rbp-1]         ; LSTACK
                mov     rsi, [rbp+rbx*8+1016]    ; rbp+(rbx-1)*8+1024
                mov     rdi, [rbp+rbx*8+1008]    ; rbp+(rbx-2)*8+1024
                mov     r14b, 0             ; not EOL
                ret

    .do:        mov     eax, 1              ; DO
                call    PushValue
                call    PushLine
                ret

;-------------------------------------------------------------------------
; = コード先頭アドレスを再設定
;-------------------------------------------------------------------------
Com_Top:
                call    SkipEqualExp        ; = を読み飛ばした後 式の評価
                push    rdi
                mov     rdi, rax
                call    RangeCheck          ; ',' <= '=' < '*'
                jb      Com_NEW.range_err   ; 範囲外エラー
                xor     ebx, ebx
                mov     bl, '='             ; コード先頭
                mov     [rbp+rbx*8], rax    ; 式の値を=に設定
                mov     bl, '*'             ; メモリ末
                mov     rdi, [rbp+rbx*8]    ; rdi=*
    .nextline:                              ; コード末検索
                mov     rbx, [rax]          ; 次行へのオフセット
                inc     rbx                 ; 行先頭が -1 ?
                je      .found              ; yes
                dec     rbx                 ; 次行へのオフセットを戻す
                or      rbx, rbx
                jle     .endmark_err        ; 次行へのオフセット <= 0
                mov     rbx, [rax+4]        ; 行番号 > 0
                or      rbx, rbx
                jle     .endmark_err        ; 行番号 <= 0
                add     rax, [rax]          ; 次行先頭アドレス
                cmp     rdi, rax            ; 次行先頭 > メモリ末
                jle     .endmark_err
                jmp     short .nextline     ; 次行処理
    .found:     mov     rcx, rax            ; コード末発見
                pop     rdi
                jmp     short Com_NEW.set_end   ; & 再設定
    .endmark_err:
                pop     rdi
                lea     rax, [EndMark_msg]  ; プログラム未入力
                call    OutAsciiZ
                call    WarmInit            ;
                ret

;-------------------------------------------------------------------------
; コード末マークと空きメモリ先頭を設定 &
;   = (コード領域の先頭)からの相対値で指定, 絶対アドレスが設定される
;-------------------------------------------------------------------------
Com_NEW:
                call    SkipEqualExp        ; = を読み飛ばした後 式の評価
                xor     ebx, ebx
                mov     bl, '='             ; コード先頭
                mov     rcx, [rbp+rbx*8]    ; &==+4
                xor     eax, eax
                dec     eax                 ; コード末マーク(-1)
                mov     [rcx] ,eax          ; コード末マーク
    .set_end:
                mov     bl, '&'             ; 空きメモリ先頭
                lea     rcx, [rcx + 4]      ; コード末の次
                mov     [rbp+rbx*8], rcx
                call    WarmInit1           ; 入力デバイス変更なし
                ret
    .range_err: pop     rdi
                call    RangeError
                ret

;-------------------------------------------------------------------------
; BRK *
;    メモリ最終位置を設定, brk
;-------------------------------------------------------------------------
Com_BRK:
                call    SkipEqualExp        ; = を読み飛ばした後 式の評価
                mov     rdx, rdi            ; rdi 退避
                mov     rdi, rax            ; rbx にメモリサイズ
                mov     eax, SYS_brk        ; メモリ確保
                syscall
                mov     rdi, rdx            ; rdi 復帰
                xor     ebx, ebx
                mov     bl, '*'             ; ヒープ先頭
                mov     [rbp+rbx*8], rax
                ret

;-------------------------------------------------------------------------
; RANDOM '
;-------------------------------------------------------------------------
Com_RANDOM:
                call    SkipEqualExp        ; = を読み飛ばした後 式の評価
                mov     cl, '`'             ; 乱数シード設定
                mov     [rbp+rcx*8], rax
                call    sgenrand
                ret

;-------------------------------------------------------------------------
; 文字列取得 " または EOL まで
;-------------------------------------------------------------------------
GetString:
                push    rdi
                xor     ecx, ecx
                mov     rdi, FileName
    .next:      call    GetChar
                cmp     al, '"'
                je      .exit
                or      al, al
                je      .exit
                mov     [rdi + rcx], al
                inc     ecx
                cmp     ecx, FNAMEMAX
                jb      .next
    .exit:
                xor     al, al
                mov     [rdi + rcx], al
                pop     rdi
                ret

;-------------------------------------------------------------------------
; CodeWrite <=
;-------------------------------------------------------------------------
Com_CdWrite:
                push    rdi
                push    rsi
                call    GetFileName
                call    fwopen              ; open
                je      .exit
                js      .error
                mov     [rbp-20], rax       ; FileDescW
                xor     ebx, ebx
                mov     bl, '='
                mov     rdi, [rbp+rbx*8]    ; コード先頭アドレス
    .loop:      mov     rsi, input2         ; ワークエリア(行)
                mov     eax, [rdi]          ; 次行へのオフセット
                inc     eax                 ; コード最終か?
                je      .exit               ; 最終なら終了
                mov     eax, [rdi+4]        ; 行番号取得
                call    PutDecimal          ; 行番号書き込み
                mov     al, ' '             ; スペース書込み
                mov     [rsi], al           ; Write One Char
                inc     rsi
                mov     ebx, 8
    .code:      mov     al, [rdi + rbx]     ; コード部分表示
                cmp     al, 0               ; 行末か?
                je      .next               ; file出力後次行
                mov     [rsi], al           ; Write One Char
                inc     rsi
                inc     rbx
                jmp     short .code
    .next:      mov     ecx, [rdi]          ; 次行へのオフセット
                add     rdi, rcx            ; 次行先頭へ
                mov     byte[rsi], 10       ; 改行書込み
                inc     rsi
                mov     byte[rsi], 0        ; EOL
                push    rdi                 ; 次行先頭保存
                mov     rsi, input2         ; バッファアドレス
                mov     rax, rsi
                call    StrLen
                mov     rdx, rax            ; 書きこみバイト数
                mov     rdi, [rbp-20]       ; FileDescW
                mov     eax, SYS_write
                syscall
                pop     rdi                 ; 次行先頭復帰
                jmp     short .loop         ; 次行処理
    .exit:
                mov     rbx, [rbp-20]       ; FileDescW
                call    fclose
                mov     r14b, 1             ; EOL
                pop     rsi
                pop     rdi
                ret

    .error:     pop     rsi
                pop     rdi
                jmp     short SYS_Error

;-------------------------------------------------------------------------
; CodeRead >=
;-------------------------------------------------------------------------
Com_CdRead:
                cmp     byte[rbp-4], 1      ; Read from file
                je      .error
                call    GetFileName
                call    fropen              ; open
                je      .exit
                js      SYS_Error
                mov     [rbp-12], rax       ; FileDesc
                mov     byte[rbp-4], 1      ; Read from file
                mov     r14b, 1             ; EOL
    .exit:      ret
    .error:
                lea     rax, [error_cdread]
                call    OutAsciiZ
                jmp     short SYS_Error.return

;-------------------------------------------------------------------------
; ファイル名をバッファに取得
;-------------------------------------------------------------------------
GetFileName:
                call    GetChar             ; skip =
                cmp     al, '='
                jne     .error
                call    GetChar             ; skip =
                cmp     al, '"'
                je      .file
                jmp     short .error
    .file:      call    GetString
                lea     rax, [FileName]     ; ファイル名表示
                ; call    OutAsciiZ
                mov     rbx, rax
                ret
    .error:
                pop     rbx                 ; スタック修正

;-------------------------------------------------------------------------
; 未定義コマンド処理(エラーストップ)
;-------------------------------------------------------------------------
SYS_Error:
                call    CheckError
    .return:    pop     rbx                 ; スタック修正
                call    WarmInit
                jmp     MainLoop

;-------------------------------------------------------------------------
; FileWrite (=
;-------------------------------------------------------------------------
Com_FileWrite:
                mov     al, [rsi]           ; PeekChar
                cmp     al, '*'             ; (*=
                jne     .L1
                call    GetChar             ; skip (
                call    GetChar             ; skip =
                cmp     al, '='
                jne     near Com_Error
                call    Exp
                mov     rbx, rax
                jmp     short .L2
    .L1:        call    GetFileName
    .L2:        call    fwopen              ; open
                je      .exit
                js      SYS_Error
                mov     [rbp-20], rax       ; FileDescW

                push    rsi
                push    rdi
                xor     eax, eax
                mov     al, '{'
                mov     rsi, [rbp+rax*8]    ; バッファ指定
                mov     al, '}'             ; 格納領域最終
                mov     rax, [rbp+rax*8]    ;
                cmp     rax, rsi
                jb      .exit0
                sub     rax, rsi
                mov     rdx, rax            ; 書き込みサイズ
                mov     eax, SYS_write      ; システムコール番号
                mov     rdi, [rbp-20]       ; FileDescW
                syscall
                call    fclose
    .exit0:     pop     rdi
                pop     rsi
    .exit       ret

;-------------------------------------------------------------------------
; FileRead )=
;-------------------------------------------------------------------------
Com_FileRead:
                mov     al, [rsi]           ; PeekChar
                cmp     al, '*'             ; )*=
                jne     .L1
                call    GetChar             ; skip )
                call    GetChar             ; skip =
                cmp     al, '='
                jne     near Com_Error
                call    Exp
                mov     rbx, rax
                jmp     short .L2
    .L1:        call    GetFileName
    .L2:        call    fropen              ; open
                je      .exit
                js      near SYS_Error
                mov     [rbp-20], rax       ; FileDescW

                push    rsi
                push    rdi
                mov     rdi, rax            ; 第１引数 : fd
                mov     eax, SYS_lseek      ; システムコール番号
                xor     esi, esi            ; 第２引数 : offset = 0
                mov     edx, SEEK_END       ; 第３引数 : origin
                syscall                     ; ファイルサイズを取得

                push    rax                 ; file_size 退避
                mov     rdi, [rbp-20]       ; 第１引数 : fd
                mov     eax, SYS_lseek      ; システムコール番号
                xor     esi, esi            ; 第２引数 : offset=0
                xor     edx, edx            ; 第３引数 : origin=0
                syscall                     ; ファイル先頭にシーク

                xor     eax, eax
                mov     al, '{'             ; 格納領域先頭
                mov     rsi, [rbp+rax*8]    ; バッファ指定
                pop     rdx                 ; file_size 取得
                mov     al, ')'             ; 読み込みサイズ設定
                mov     [rbp+rax*8], rdx
                mov     rbx, rsi
                add     rbx, rdx
                mov     al, '}'             ; 格納領域最終設定
                mov     [rbp+rax*8], rbx    ;
                mov     al, '*'
                mov     rax, [rbp+rax*8]    ; RAM末
                cmp     rax, rbx
                jl      .exit0              ; 領域不足

                mov     eax, SYS_read       ; システムコール番号
                mov     rdi, [rbp-20]       ; FileDescW
                syscall                     ; ファイル全体を読みこみ
                push    rax
                mov     rbx, [rbp-20]       ; FileDescW
                call    fclose
                pop     rax

                test    rax,rax             ; エラーチェック
    .exit0:     pop     rdi
                pop     rsi
    .exit       ret

;-------------------------------------------------------------------------
; ファイル格納域先頭を指定
;-------------------------------------------------------------------------
Com_FileTop:
                call    SkipEqualExp        ; = を読み飛ばした後 式の評価
                push    rdi
                mov     rdi, rax
                call    RangeCheck          ; 範囲チェック
                pop     rdi
                jb      Com_FileEnd.range_err   ; 範囲外をアクセス
                xor     ebx, ebx
                mov     bl, '{'             ; ファイル格納域先頭
                mov     [rbp+rbx*8], rax
                ret

;-------------------------------------------------------------------------
; ファイル格納域最終を指定
;-------------------------------------------------------------------------
Com_FileEnd:
                call    SkipEqualExp        ; = を読み飛ばした後 式の評価
                push    rdi
                mov     rdi, rax
                call    RangeCheck          ; 範囲チェック
                pop     rdi
                jb      .range_err          ; 範囲外をアクセス
                xor     ebx, ebx
                mov     bl, '}'             ; ファイル格納域先頭
                mov     [rbp+rbx*8], rax
                ret
    .range_err:
                call    RangeError
                ret

;-------------------------------------------------------------------------
; CGI モードなら rvtl 終了
;-------------------------------------------------------------------------
CheckCGI:
                cmp     dword[cgiflag], 1   ; CGI mode ?
                je      Com_Exit
                ret

;-------------------------------------------------------------------------
; 終了
;-------------------------------------------------------------------------
Com_Exit:
                call    RESTORE_TERMIOS
                jmp     Exit

;-------------------------------------------------------------------------
; 範囲チェックフラグ [
;-------------------------------------------------------------------------
Com_RCheck:
                call    SkipEqualExp        ; = を読み飛ばした後 式の評価
                xor     ebx, ebx
                mov     bl, '['             ; 範囲チェック
                mov     [rbp+rbx*8], rax
                ret

;-------------------------------------------------------------------------
; 変数または式をスタックに保存
;-------------------------------------------------------------------------
Com_VarPush:
                mov     rcx, [rbp-28]       ; VSTACK
                mov     edx, VSTACKMAX - 1
    .next:
                cmp     rcx, rdx
                jge     VarStackError.over
                call    GetChar
                cmp     al, '='             ; +=式
                jne     .push2
                call    Exp
                mov     [rbp+rcx*8+2048], rax    ; 変数スタックに式を保存
                inc     rcx
                jmp     short .exit
    .push2:     cmp     al, ' '
                je      .exit
                or      al, al
                cmp     r14b, 1             ; EOL
                je      .exit
                mov     rax, [rbp+rax*8]    ; 変数の値取得
                mov     [rbp+rcx*8+2048], rax    ; 変数スタックに式を保存
                inc     rcx
                jmp     short .next
    .exit:
                mov     [rbp-28], rcx       ; スタックポインタ更新
                ret

;-------------------------------------------------------------------------
; 変数をスタックから復帰
;-------------------------------------------------------------------------
Com_VarPop:
                mov     rcx, [rbp-28]       ; VSTACK
    .next:
                call    GetChar
                cmp     al, ' '
                je      .exit
                or      al, al
                ; cmp     r14b, 1           ; EOL
                je      .exit
                dec     rcx
                jl      VarStackError.under
                mov     rbx, [rbp+rcx*8+2048]    ; 変数スタックから復帰
                mov     [rbp+rax*8], rbx    ; 変数の値取得
                jmp     short .next
    .exit:
                mov     [rbp-28], rcx       ; スタックポインタ更新
                ret

;-------------------------------------------------------------------------
; 変数スタック範囲エラー
;-------------------------------------------------------------------------
VarStackError:
    .over:
                lea     rax, [vstkover]
                jmp     short .print
    .under:
                lea     rax, [vstkunder]
    .print:     call    OutAsciiZ
                call    WarmInit
                ret

;-------------------------------------------------------------------------
; ForkExec , 外部プログラムの実行
;-------------------------------------------------------------------------
Com_Exec:
%ifndef SMALL_VTL
                call    GetChar             ;
                cmp     al, '*'             ; ,*=A 形式
                jne     .normal
                call    GetChar             ; get =
                cmp     al, '='
                jne     near Com_Error
                call    Exp
                call    GetString2          ; FileNameにコピー
                jmp     short .parse
    .normal:    cmp     byte[rsi], '"'
                jne     .filename           ; , /bin/xx 形式
                call    GetChar             ; ,="/bin/xx yy" 形式
    .filename:  call    GetFileName.file    ; 外部プログラム名取得
                call    NewLine

    .parse:
                _PUSHA
                call    ParseArg            ; コマンド行の解析
                mov     rdi, rbx            ; リダイレクト先ファイル名
                inc     edx                 ; 子プロセスの数
                lea     rsi, [exarg]        ; char ** argp
                xor     ebp, ebp            ; 先頭プロセス
                cmp     edx, 1
                ja      .loop               ; パイプが必要
                mov     eax, SYS_fork       ; パイプ不要の場合
                syscall                     ;
                test    rax, rax
                je      .child              ; pid が 0 なら子プロセス
                jmp     short .wait
    .loop:
                lea     r12, [ipipe]          ; パイプをオープン
                mov     eax, SYS_pipe
                mov     rdi, r12            ; r12 に pipe_fd 配列先頭
                syscall                     ; pipe

        ;------------------------------------------------------------
        ; fork
        ;------------------------------------------------------------
                mov     eax, SYS_fork
                syscall                     ; fork
                test    rax, rax
                je      .child              ; pid が 0 なら子プロセス

        ;------------------------------------------------------------
        ; 親プロセス側の処理
        ;------------------------------------------------------------
                test    ebp, ebp            ; 先頭プロセスか?
                je      .not1st
                call    close_old_pipe
    .not1st:    push    rax                 ; 子プロセスの pid の保存
                mov     eax, [r12]          ; パイプ fd の移動
                mov     [r12+8], eax        ; ipipe2
                mov     eax, [r12+4]        ; opipe
                mov     [r12+12], eax       ; opipe2
                pop     rax                 ; 子プロセスの pid の復帰
                dec     edx                 ; 残り子プロセスの数
                je      .done               ; 終了

    .findargp:  lea     rsi, [rsi + 8]      ; 次のコマンド文字列探索
                cmp     qword[rsi], 0       ; 区切りを探す
                jne     .findargp
                lea     rsi, [rsi + 8]      ; 次のコマンド文字列設定
                inc     ebp                 ; 次は先頭プロセスではない
                jmp     short   .loop

    .done:
                call    close_new_pipe
    .wait:
                mov     rdi, rax            ; 最後に起動したプロセスpid
                mov     eax, SYS_wait4      ; 終了を待つ
                lea     rsi, [stat_addr]
                mov     edx, WUNTRACED      ; WNOHANG
                xor     r10d, r10d          ; r10 = NULL
;                mov     r10, ru             ; rusage
                syscall                     ; wait4
                call    SET_TERMIOS         ; 子プロセスの設定を復帰
                _POPA
                ret

        ;------------------------------------------------------------
        ; 子プロセス側の処理
        ;------------------------------------------------------------
    .child:
                call    RESTORE_TERMIOS
                push    rsi                 ; rcx に char **argp 設定済
                dec     edx                 ; 最終プロセスチェック
                jne     .pipe_out           ; 最終プロセスでない
                test    rbx, rbx            ; リダイレクトがあるか
                je      .pipe_in            ; リダイレクト無し, 標準出力
                call    fwopen
                mov     rdi, rax            ; オープン済みのファイル fd
                mov     eax, SYS_dup2       ; 標準出力をファイルに
                xor     esi, esi
                inc     esi                 ; 標準出力をファイルに差替え
                syscall                     ; dup2
                call    fclose              ; rbx にはオープンしたfd
                jmp     short .pipe_in

    .pipe_out:  mov     eax, SYS_dup2       ; 標準出力をパイプに
                mov     edi, [r12+4]        ; 新パイプの書込み fd
                xor     esi, esi            ; new_fd
                inc     esi                 ; 標準出力
                syscall                     ; dup2
                call    close_new_pipe
    .pipe_in:   test    ebp, ebp            ; 先頭プロセスならスキップ
                je      .execve
                mov     eax, SYS_dup2       ; 標準入力をパイプに
                mov     edi, [r12+8]        ; 前のパイプの読出し fd
                xor     esi, esi            ; new_fd 標準入力
                syscall                     ; dup2
                call    close_old_pipe
    .execve:
                pop     rsi                 ; rsi に char **argp
                mov     eax, SYS_execve     ; 変身
                mov     rdi, [rsi]          ; char * filename
                mov     rdx, [envp]         ; char ** envp
                syscall
                call    CheckError          ; 正常ならここには戻らない
                call    Exit                ; 単なる飾り

close_new_pipe:
                push    rax
                mov     ebx, [r12 + 4]      ; 出力パイプをクローズ
                call    fclose
                mov     ebx, [r12]          ; 入力パイプをクローズ
                call    fclose
                pop     rax
                ret
close_old_pipe:
                push    rax
                mov     ebx, [r12 + 12]     ; 出力パイプをクローズ
                call    fclose
                mov     ebx, [r12 + 8]      ; 入力パイプをクローズ
                call    fclose
                pop     rax
                ret
%endif

;-------------------------------------------------------------------------
; 組み込みコマンドの実行
;-------------------------------------------------------------------------
Com_Function:
%ifndef SMALL_VTL
                call    GetChar             ; | の次の文字
    .func_c     cmp     al, 'c'
                jne     .func_d
                call    def_func_c          ; |c
                ret
    .func_d:
    .func_e:    cmp     al, 'e'
                jne     .func_f
                call    def_func_e          ; |e
                ret
    .func_f:    cmp     al, 'f'
                jne     .func_l
                call    def_func_f          ; |f
                ret
    .func_l:    cmp     al, 'l'
                jne     .func_m
                call    def_func_l          ; |l
                ret
    .func_m:    cmp     al, 'm'
                jne     .func_n
                call    def_func_m          ; |m
                ret
    .func_n:
    .func_p:    cmp     al, 'p'
                jne     .func_q
                call    def_func_p          ; |p
                ret
    .func_q:
    .func_r:    cmp     al, 'r'
                jne     .func_s
                call    def_func_r          ; |r
                ret
    .func_s:    cmp     al, 's'
                jne     .func_t
                call    def_func_s          ; |s
                ret
    .func_t:
    .func_u:    cmp     al, 'u'
                jne     .func_v
                call    def_func_u          ; |u
                ret
    .func_v:    cmp     al, 'v'
                jne     .func_z
                call    def_func_v          ; |v
                ret
    .func_z:    cmp     al, 'z'
                jne     func_error
                call    def_func_z          ; |z
                ret
func_error:
                jmp     Com_Error

;------------------------------------
; |c で始まる組み込みコマンド
;------------------------------------
def_func_c:
                call    GetChar             ;
                cmp     al, 'a'
                je      .func_ca            ; cat
                cmp     al, 'd'
                je      .func_cd            ; cd
                cmp     al, 'm'
                je      .func_cm            ; chmod
                cmp     al, 'r'
                je      .func_cr            ; chroot
                cmp     al, 'w'
                je      near .func_cw       ; pwd
                jmp     short func_error
    .func_ca:
                lea     rax, [msg_f_ca]     ; |ca file
                call    FuncBegin
                mov     rbx, [rbx]          ; filename
                call    DispFile
                ret
    .func_cd:
                lea     rax, [msg_f_cd]     ; |cd path
                call    FuncBegin
                push    rdi
                mov     rdi, [rbx]          ; char ** argp
                lea     rax, [FileName]
                call    OutAsciiZ
                call    NewLine
                mov     eax, SYS_chdir
                syscall
                call    CheckError
                pop     rdi
                ret
    .func_cm:
                lea     rax, [msg_f_cm]     ; |cm 644 file
                call    FuncBegin
                push    rdi
                push    rsi
                mov     rax, [rbx]          ; permission
                mov     rdi, [rbx+8]        ; file name
                call    Oct2Bin
                mov     rsi, rax
                mov     eax, SYS_chmod
                syscall
                call    CheckError
                pop     rsi
                pop     rdi
                ret
    .func_cr:
                lea     rax, [msg_f_cr]     ; |cr path
                call    FuncBegin
                push    rdi
                mov     rdi, [rbx]          ; char ** argp
                lea     rax, [FileName]
                call    OutAsciiZ
                call    NewLine
                mov     eax, SYS_chroot
                syscall
                call    CheckError
                pop     rdi
                ret
    .func_cw:
                lea     rax, [msg_f_cw]    ; |cw
                call    OutAsciiZ
                push    rdi
                push    rsi
                mov     rdi, FileName
                mov     esi, FNAMEMAX
                mov     eax, SYS_getcwd
                syscall
                call    CheckError
                mov     rax, rdi
                pop     rsi
                pop     rdi
                call    OutAsciiZ
                call    NewLine
                ret

;------------------------------------
; |e で始まる組み込みコマンド
;------------------------------------
def_func_e:
                call    GetChar             ;
                cmp     al, 'x'
                je      .func_ex            ; execve
                jmp     func_error
    .func_ex:   lea     rax, [msg_f_ex]     ; |ex file arg ..
                call    RESTORE_TERMIOS     ; 端末設定を戻す
                call    FuncBegin
                push    rdi
                push    rsi
                mov     eax, SYS_execve     ; 変身
                mov     rsi, rbx            ; char ** argp
                mov     rdi, [rsi]          ; char * filename
                mov     rdx, [rsi-24]       ; char ** envp
                syscall
                call    CheckError          ; 正常ならここには戻らない
                call    SET_TERMIOS         ; 端末のローカルエコーをOFF
                pop     rsi
                pop     rdi
                ret

;------------------------------------
; |f で始まる組み込みコマンド
;------------------------------------
def_func_f:
%ifdef FRAME_BUFFER
%include        "vtlfb64.inc"
%endif

;------------------------------------
; |l で始まる組み込みコマンド
;------------------------------------
def_func_l:
                call    GetChar             ;
                cmp     al, 's'
                je      .func_ls            ; ls
                jmp     func_error

    .func_ls:
                _PUSHA
                lea     rax, [msg_f_ls]     ; |ls dir
                call    FuncBegin
                mov     rax, [rbx]          ; ディレクトリ名先頭アドレス
                mov     rsi, rax
                lea     rbx, [DirName]
                mov     rdi, rbx
                mov     byte[rdi], 0        ; DirNameを空文字列に初期化
                test    rax, rax
                je      .empty

                call    StrLen              ; 引数をDirNameにコピー
                mov     rcx, rax            ; 文字列長をrcx
                rep     movsb
                cmp     byte[rdi-1], '/'
                je      .end
                mov     byte[rdi] ,'/'
                inc     rdi
    .end:       mov     byte[rdi], 0
                jmp     short .list

    .empty:     lea     rbx, [current_dir]  ; 指定なしなら ./
    .list:      call    fropen
                js      .exit0
                mov     rbx, rax            ; fd
    .getdents:
                mov     rdi, rbx            ; rdi : fd
                lea     rsi, [dir_ent]
                mov     edx, size_dir_ent
                mov     eax, SYS_getdents
                syscall
                mov     rdi, rsi            ; rdi : struct top (dir_ent)
                test    rax, rax            ; valid buffer length
                js      .exit0
                je      .exit
                mov     rbp, rax            ; rbp : buffer size
    .next:
                call    GetFileStat
                xor     eax, eax
                mov     ax, [file_stat+stat.st_mode]
                mov     ecx, 6
                call    PrintOctal          ; mode
                mov     rax, [file_stat+stat.st_size]
                mov     ecx, 12
                call    PrintRight          ; file size
                mov     eax, ' '
                call    OutChar
                lea     rax, [rdi+18]
                call    OutAsciiZ           ; filename
                call    NewLine
                movzx   rax, word[rdi+16]   ; 64bitにゼロ拡張
                sub     rbp, rax
                je      .getdents           ; バッファーをすべて処理
                add     rdi, rax            ; バッファーの残り
                jmp     short .next
    .exit0:
                call    CheckError
    .exit:
                call    fclose              ; rbx = fd
                _POPA
                ret

;------------------------------------
; |m で始まる組み込みコマンド
;------------------------------------
def_func_m:
                call    GetChar             ;
                cmp     al, 'd'
                je      .func_md            ; mkdir
                cmp     al, 'o'
                je      .func_mo            ; mo
                cmp     al, 'v'
                je      .func_mv            ; mv
    .func_error:jmp     func_error

    .func_md:   lea     rax, [msg_f_md]     ; |md dir [777]
                call    FuncBegin
                mov     rax, [rbx+8]        ; permission
                push    rdi
                push    rsi
                mov     rdi, [rbx]          ; directory name
                test    rax, rax
                je      .def
                call    Oct2Bin
                mov     esi, eax
                jmp     short .not_def
    .def:       mov     esi, 0755q
    .not_def:   mov     eax, SYS_mkdir
                syscall
                call    CheckError
                pop     rsi
                pop     rdi
                ret
    .func_mo:   lea     rax, [msg_f_mo]     ; |mo dev_name dir fstype
                call    FuncBegin
                push    rdi
                push    rsi
                push    rbp
                mov     rbp, rbx            ; exarg
                mov     rdi, [rbp]          ; dev_name
                mov     rsi, [rbp+8]        ; dir_name
                mov     rdx, [rbp+16]       ; fstype
                mov     r10, [rbp+24]       ; flags
                or      r10, r10            ; Check ReadOnly
                je      .rw                 ; Read/Write
                mov     r10, [r10]
                mov     esi, MS_RDONLY      ; ReadOnly FileSystem
    .rw:        xor     r8d, r8d            ; void * data
                mov     eax, SYS_mount
                syscall
                call    CheckError
                pop     rbp
                pop     rsi
                pop     rdi
                ret
    .func_mv:   lea     rax, [msg_f_mv]     ; |mv fileold filenew
                call    FuncBegin
                push    rdi
                push    rsi
                mov     rsi, [rbx+8]
                mov     rdi, [rbx]
                mov     eax, SYS_rename
                jmp     SysCallCheckReturn

;------------------------------------
; |p で始まる組み込みコマンド
;------------------------------------
def_func_p:
                call    GetChar             ;
                cmp     al, 'v'
                je      .func_pv            ; pivot_root
    .func_error:jmp     func_error

    .func_pv:   lea     rax, [msg_f_pv]     ; |pv /dev/hda2 /mnt
                call    FuncBegin
                push    rdi
                push    rsi
                mov     rsi, [rbx+8]
                mov     rdi, [rbx]
                mov     eax, SYS_pivot_root
                jmp     short SysCallCheckReturn

;------------------------------------
; |r で始まる組み込みコマンド
;------------------------------------
def_func_r:
                call    GetChar             ;
                cmp     al, 'd'
                je      .func_rd            ; rmdir
                cmp     al, 'm'
                je      .func_rm            ; rm
                cmp     al, 't'
                je      .func_rt            ; rt
    .func_error:jmp     short def_func_p.func_error

    .func_rt:                               ; reset terminal
                lea     rax, [msg_f_rt]     ; |rt
                call    OutAsciiZ
                call    SET_TERMIOS2        ; cooked mode
                call    GET_TERMIOS         ; termios の保存
                call    SET_TERMIOS         ; raw mode
                ret

    .func_rd:   lea     rax, [msg_f_rd]     ; |rd path
                call    FuncBegin           ; char ** argp
                push    rdi
                push    rsi
                mov     rdi, [rbx]
                mov     eax, SYS_rmdir
                jmp     short SysCallCheckReturn
    .func_rm:   lea     rax, [msg_f_rm]     ; |rm path
                call    FuncBegin           ; char ** argp
                push    rdi
                push    rsi
                mov     rdi, [rbx]
                mov     eax, SYS_unlink

SysCallCheckReturn:
                syscall
                call    CheckError
                pop     rsi
                pop     rdi
                ret

;------------------------------------
; |s で始まる組み込みコマンド
;------------------------------------
def_func_s:
                call    GetChar             ;
                cmp     al, 'f'
                je      .func_sf            ; swapoff
                cmp     al, 'o'
                je      .func_so            ; swapon
                cmp     al, 'y'
                je      .func_sy            ; sync
    .func_error:jmp     short def_func_r.func_error

    .func_sf:   lea     rax, [msg_f_sf]     ; |sf dev_name
                call    FuncBegin           ; const char * specialfile
                push    rdi
                push    rsi
                mov     rdi, [rbx]
                mov     eax, SYS_swapoff
                jmp     short SysCallCheckReturn

    .func_so:   lea     rax, [msg_f_so]     ; |so dev_name
                call    FuncBegin
                push    rdi
                push    rsi
                xor     esi, esi            ; int swap_flags
                mov     rdi, [rbx]          ; const char * specialfile
                mov     eax, SYS_swapon
                jmp     short SysCallCheckReturn

    .func_sy:   lea     rax, [msg_f_sy]     ; |sy
                call    OutAsciiZ
                mov     eax, SYS_sync
                syscall
                call    CheckError
                ret

;------------------------------------
; |u で始まる組み込みコマンド
;------------------------------------
def_func_u:
                call    GetChar             ;
                cmp     al, 'm'
                je      .func_um            ; umount
                cmp     al, 'd'
                je      func_ud             ; umount
                jmp     short def_func_s.func_error

    .func_um:   lea     rax, [msg_f_um]     ; |um dev_name
                call    FuncBegin           ;
                push    rdi
                mov     rdi, [rbx]          ; dev_name
                mov     eax, SYS_umount     ; sys_oldumount
                syscall
                call    CheckError
                pop     rdi
                ret

     func_ud:
                ;------------------------------------
                ; URL デコード
                ;  u;0] URLエンコード文字列の先頭設定
                ;  u[2] 変更範囲の文字数を設定
                ;  u[3] 空き
                ;  u;2] デコード後の文字列先頭を設定
                ;  u[6] デコード後の文字数を返す
                ;------------------------------------
                push    rbp
                xor     ebx, ebx
                mov     bl, 'u'             ; 引数
                mov     rbp, [rbp+rbx*8]    ; rbp : argument top
                mov     rax, [rbp]          ; URLエンコード文字列の先頭設定
                mov     ebx, [rbp +  8]     ; 変更範囲の文字数を設定
                mov     rcx, [rbp + 16]     ; デコード後の文字列先頭を設定
                call    URL_Decode
                mov     [rbp + 24], eax     ; デコード後の文字数を設定
                pop     rbp
                ret

;------------------------------------
; |v で始まる組み込みコマンド
;------------------------------------
def_func_v:
                call    GetChar             ;
                cmp     al, 'e'
                je      .func_ve            ; version
                cmp     al, 'c'
                je      .func_vc            ; cpu
    .func_error:jmp     func_error

    .func_ve:
                xor     ebx, ebx
                mov     bl, '%'             ; 引数
                mov     dword[rbp+rbx*8], VERSION
                mov     dword[rbp+rbx*8+4], VERSION64
                ret

    .func_vc:
                xor     ebx, ebx
                mov     bl, '%'             ; 引数
                mov     qword[rbp+rbx*8], CPU
                ret

;------------------------------------
; |zz システムコール
;------------------------------------
def_func_z:
                call    GetChar             ;
                cmp     al, 'z'
                je      .func_zz            ; system call
                cmp     al, 'c'
                je      .func_zc            ; read exec counter
                jmp     short def_func_v.func_error

    .func_zz:
                call    GetChar             ; skip space
                push    rdi
                push    rsi
                xor     ecx, ecx
                mov     cl, 'a'
                mov     rax, [rbp+rcx*8]    ; [a] syscall no.
                inc     ecx
                mov     rdi, [rbp+rcx*8]    ; [b] param1
                inc     ecx
                mov     rsi, [rbp+rcx*8]    ; [c] param2
                inc     ecx
                mov     rdx, [rbp+rcx*8]    ; [d] param3
                inc     ecx
                mov     r10, [rbp+rcx*8]    ; [e] param4
                inc     ecx
                mov     r8, [rbp+rcx*8]     ; [f] param5
                inc     ecx
                mov     r9, [rbp+rcx*8]     ; [g] param6
                syscall
                pop     rsi
                pop     rdi
                call    CheckError
                ret

    .func_zc:
                xor     ebx, ebx
                mov     bl, '%'             ; 引数
                mov     rcx, [counter]
                mov     qword[rbp+rbx*8], rcx
                ret

;---------------------------------------------------------------------
; AL の文字が16進数字かどうかのチェック
; 数字なら整数に変換して AL 返す. 非数字ならキャリーセット
;---------------------------------------------------------------------

IsHex:          call    IsHex1              ; 英文字か?
                jae     .yes
                call    IsHex2
                jb      IsHex2.no
    .yes:       clc
                ret

IsHex1:         cmp     al, "A"             ; 英大文字(A-F)か?
                jb      IsHex2.no
                cmp     al, "F"
                ja      IsHex2.no
                sub     al, "A"
                add     al, 10
                clc
                ret

IsHex2:         cmp     al, "a"             ; 英小文字(a-f)か?
                jb      .no
                cmp     al, "f"
                ja      .no
                sub     al, "a"
                add     al, 10
                clc
                ret
    .no:        stc
                ret

IsHexNum:       call    IsHex               ; 16進文字？
                jae     .yes
                call    IsNum
                jb      IsHex2.no
                sub     al, "0"
    .yes:       clc
                ret

;-------------------------------------
; URLデコード
;
; rax にURLエンコード文字列の先頭設定
; rbx に変更範囲の文字数を設定
; rcx にデコード後の文字列先頭を設定
; rax にデコード後の文字数を返す
;-------------------------------------
URL_Decode:
                _PUSHA
                mov     rsi, rax
                mov     rdi, rcx
                xor     eax, eax
                xor     ecx, ecx
                push    rsi
    .next:
                mov     al, [rsi]           ; エンコード文字
                cmp     al, '+'
                jne     .urld2
                mov     al, ' '
                mov     [rdi + rcx], al     ; デコード文字
                jmp     .urld4
    .urld2:
                cmp     al, '%'
                je      .urld3
                mov     [rdi + rcx], al     ; 非エンコード文字
                jmp     .urld4

    .urld3:
                xor     edx, edx
                inc     rsi
                mov     al, [rsi]
                call    IsHexNum
                jb      .urld4
                add     dl, al
                inc     rsi
                mov     al, [rsi]
                call    IsHexNum
                jb      .urld4
                shl     dl, 4
                add     dl, al
                mov     [rdi + rcx], dl
    .urld4:
                inc     rsi
                inc     rcx
                mov     rdx, [rsp]          ; initial rsi
                sub     rdx, rsi
                neg     rdx
                cmp     rdx, rbx
                jl      .next
                pop     rsi
                xor     eax, eax
                mov     [rdi + rcx], al
                mov     [rsp+48], rcx       ; rax に文字数を返す
                _POPA
                ret

;-------------------------------------------------------------------------
; 組み込み関数用
;-------------------------------------------------------------------------
FuncBegin:
                call    OutAsciiZ           ; 必要か？
                call    GetChar             ; 空白か等号
                cmp     al, "*"
                jne     .line
                call    SkipEqualExp        ; rax にアドレス
                push    rdi                 ; コピー先退避
                mov     rdi, rax            ; RangeCheckはrdiを見る
                call    RangeCheck          ; コピー元を範囲チェック
                pop     rdi                 ; コピー先復帰
                jb      .range_err          ; 範囲外をアクセス

                call    GetString2          ; FileNameにコピー
                jmp     short .parse
    .line:      cmp     byte[rsi], '"'      ; コード行から
                jne     .get
                call    GetChar             ; skip "
    .get:       call    GetString           ; パス名の取得
    .parse:     call    ParseArg            ; 引数のパース
                lea     rbx, [exarg]
                ret

    .range_err: mov     eax, 0xFF           ; エラー文字を FF
                jmp     LongJump            ; アクセス可能範囲を超えた

;-------------------------------------------------------------------------
; rax のアドレスからFileNameにコピー
;-------------------------------------------------------------------------
  GetString2:
                push    rdi
                mov     rbx, rax
                xor     ecx, ecx
                lea     rdi, [FileName]
    .next:      mov     al, [rbx + rcx]
                mov     [rdi + rcx], al
                or      al, al
                je      .exit
                inc     rcx
                cmp     rcx, FNAMEMAX
                jb      .next
    .exit:      pop     rdi
                ret

;-------------------------------------------------------------------------
; 8進数文字列を数値に変換
; rax からの8進数文字列を数値に変換して rax に返す
;-------------------------------------------------------------------------
Oct2Bin:
                push    rbx
                push    rdi
                mov     rdi, rax
                xor     ebx, ebx
                call    GetOctal
                ja      .exit
                mov     rbx, rax
    .OctLoop:
                call    GetOctal
                ja      .exit
                shl     rbx, 3              ;
                add     rbx, rax
                jmp     short .OctLoop
    .exit:
                mov     rax, rbx
                pop     rdi
                pop     rbx
                ret

;-------------------------------------------------------------------------
; rdi の示す8進数文字を数値に変換して rax に返す
; 8進数文字でないかどうかは ja で判定可能
;-------------------------------------------------------------------------
GetOctal:
                xor     eax, eax
                mov     al, [rdi]
                inc     rdi
                sub     al, '0'
                cmp     al, 7
                ret

;-------------------------------------------------------------------------
; ファイル内容表示
; rbx にファイル名
;-------------------------------------------------------------------------
DispFile:
                _PUSHA
                call    fropen              ; open
                call    CheckError
                je      .exit
                mov     rbx, rax            ; FileDesc
                push    rax                 ; buffer on stack
    .next:
                mov     eax, SYS_read       ; システムコール番号
                mov     rdi, rbx            ; FileDesc
                mov     rsi, rsp            ; バッファ指定
                xor     edx, edx
                mov     dl, 4
                syscall                     ; ファイル 4 バイト
                test    rax, rax
                je      .done
                js      .done
                mov     rdx, rax            ; # of bytes
                mov     eax, SYS_write
                xor     edi, edi
                inc     edi                 ; 1:to stdout
                mov     rsi, rsp
                syscall
                jmp     short .next

    .done:      pop     rax
                call    fclose
    .exit:      _POPA
                ret

;-------------------------------------------------------------------------
; execve 用の引数を設定
; コマンド文字列のバッファ FileName をAsciiZに変換してポインタの配列に設定
; rdx に パイプの数 (子プロセス数-1) を返す．
; rbx にリダイレクト先ファイル名文字列へのポインタを返す．
;-------------------------------------------------------------------------
ParseArg:
                push    rdi
                push    rsi
                xor     ecx, ecx            ; 配列インデックス
                xor     edx, edx            ; パイプのカウンタ
                xor     ebx, ebx            ; リダイレクトフラグ
                lea     rsi, [FileName]     ; コマンド文字列のバッファ
                lea     rdi, [exarg]        ; ポインタの配列先頭
    .nextarg:
    .space:     mov     al, [rsi]           ; 連続する空白のスキップ
                or      al, al              ; 行末チェック
                je      .exit
                cmp     al, ' '
                jne     .pipe               ; パイプのチェック
                inc     rsi                 ; 空白なら次の文字
                jmp     short .space

    .pipe:      cmp     al, '|'             ; パイプ?
                jne     .rrdirect
                inc     rdx                 ; パイプのカウンタ
                xor     eax, eax
                mov     [rdi + rcx*8], rax  ; コマンドの区切り 0
                inc     rcx                 ; 配列インデックス
                jmp     short .check_and_next

    .rrdirect:  cmp     al, '>'             ; リダイレクト?
                jne     .arg
                inc     rbx
                xor     eax, eax
                mov     [rdi + rcx*8], rax  ; コマンドの区切り 0
                inc     rcx                 ; 配列インデックス
                jmp     short .check_and_next

    .arg:       mov     [rdi + rcx*8], rsi  ; 引数へのポインタを登録
                inc     rcx
    .nextchar:  mov     al, [rsi]           ; スペースを探す
                or      al, al              ; 行末チェック
                je      .found2
                cmp     al, ' '
                je      .found
                inc     rsi
                jmp     short .nextchar
    .found:     mov     byte[rsi], 0        ; スペースを 0 に置換
                test    rbx, rbx            ; リダイレクトフラグ
                je      .check_and_next
    .found2:    test    rbx, rbx            ; リダイレクトフラグ
                je      .exit
                dec     rcx
                mov     rbx, [rdi + rcx*8]
                inc     rcx
                jmp     short .exit

    .check_and_next:
                inc     rsi
                cmp     rcx, ARGMAX
                jae     .exit
                jmp     short .nextarg

    .exit:
                xor     eax, eax
                mov     [rdi + rcx*8], rax  ; 引数ポインタ配列の最後
                pop     rsi
                pop     rdi
                ret
%endif

;-------------------------------------------------------------------------
; システムコールエラーチェック
;-------------------------------------------------------------------------
CheckError:
                push    rcx
                xor     ecx, ecx
                mov     cl, '|'             ; 返り値を | に設定
                mov     [rbp+rcx*8], rax
                pop     rcx
%ifdef  DETAILED_MSG
                call    SysCallError
%else
                test    rax, rax
                jns     .exit
                lea     rax, [Error_msg]
                call    OutAsciiZ
%endif
    .exit:      ret

;-------------------------------------------------------------------------
; ユーザ拡張コマンド処理
;-------------------------------------------------------------------------
Com_Ext:
%ifndef SMALL_VTL
%include        "ext.inc"
    .func_err:  jmp     func_error
%endif
                ret

;-------------------------------------------------------------------------
; コマンド用ジャンプテーブル
;-------------------------------------------------------------------------
                align   4

TblComm1:
        dq Com_GOSUB    ;   21  !  GOSUB
        dq Com_String   ;   22  "  文字列出力
        dq Com_GO       ;   23  #  GOTO 実行中の行番号を保持
        dq Com_OutChar  ;   24  $  文字コード出力
        dq Com_Error    ;   25  %  直前の除算の剰余または usec を保持
        dq Com_NEW      ;   26  &  NEW, VTLコードの最終使用アドレスを保持
        dq Com_Error    ;   27  '  文字定数
        dq Com_FileWrite;   28  (  File 書き出し
        dq Com_FileRead ;   29  )  File 読み込み, 読み込みサイズ保持
        dq Com_BRK      ;   2A  *  メモリ最終(brk)を設定, 保持
        dq Com_VarPush  ;   2B  +  ローカル変数PUSH, 加算演算子, 絶対値
        dq Com_Exec     ;   2C  ,  fork & exec
        dq Com_VarPop   ;   2D  -  ローカル変数POP, 減算演算子, 負の十進数
        dq Com_Space    ;   2E  .  空白出力
        dq Com_NewLine  ;   2F  /  改行出力, 除算演算子
TblComm2:
        dq Com_Comment  ;   3A  :  行末まで注釈
        dq Com_IF       ;   3B  ;  IF
        dq Com_CdWrite  ;   3C  <  rvtlコードのファイル出力
        dq Com_Top      ;   3D  =  コード先頭アドレス
        dq Com_CdRead   ;   3E  >  rvtlコードのファイル入力
        dq Com_OutNum   ;   3F  ?  数値出力  数値入力
        dq Com_DO       ;   40  @  DO UNTIL NEXT
TblComm3:
        dq Com_RCheck   ;   5B  [  Array index 範囲チェック
        dq Com_Ext      ;   5C  \  拡張用  除算演算子(unsigned)
        dq Com_Return   ;   5D  ]  RETURN
        dq Com_Comment  ;   5E  ^  ラベル宣言, 排他OR演算子, ラベル参照
        dq Com_USleep   ;   5F  _  usleep, gettimeofday
        dq Com_RANDOM   ;   60  `  擬似乱数を保持 (乱数シード設定)
TblComm4:
        dq Com_FileTop  ;   7B  {  ファイル先頭(ヒープ領域)
        dq Com_Function ;   7C  |  組み込みコマンド, エラーコード保持
        dq Com_FileEnd  ;   7D  }  ファイル末(ヒープ領域)
        dq Com_Exit     ;   7E  ~  VTL終了

;==============================================================
section .data

  envstr        db   'PATH=/bin:/usr/bin', 0
  env           dq   envstr, 0
  cginame       db   'wltvr', 0

%ifndef SMALL_VTL
start_msg       db   'RVTL64 v.4.01 2015/10/05'
                db   ', Copyright 2002-2015 Jun Mizutani', 10,
                db   'RVTL64 may be copied under the terms of the GNU',
                db   ' General Public License.', 10
%ifdef DEBUG
                db   'DEBUG VERSION', 10
%endif
                db   0
%endif

initvtl         db   '/etc/init.vtl',0
prompt1         db   10,'<',0
prompt2         db   '> ',0
equal_err       db   10,'= required.',0
syntaxerr       db   10,'Syntax error! at line ', 0
stkunder        db   10,'Stack Underflow!', 10, 0
stkover         db   10,'Stack Overflow!', 10, 0
vstkunder       db   10,'Variable Stack Underflow!', 10, 0
vstkover        db   10,'Variable Stack Overflow!', 10, 0
Range_msg       db   10,'Out of range!', 10, 0
EndMark_msg     db   10,'&=0 required.', 10, 0
Error_msg       db   10,'Error!', 10, 0
sigint_msg      db   10,'^C',10,0
err_div0        db   10,'Divided by 0!',10,0
err_exp         db   10,'Error in Expression at line ',0
err_label       db   10,'Label not found!',10,0
err_vstack      db   10,'Empty stack!',10,0
error_cdread    db   10,'Code Read (>=) is not allowed!',10,0
no_direct_mode  db   10,"Direct mode is not allowed!", 10,0

                align 4
stat_addr       dd   0

;-------------------------------------------------------------------------
; 組み込み関数用メッセージ
;-------------------------------------------------------------------------
%ifndef SMALL_VTL
    msg_f_ca    db   0
    msg_f_cd    db   'Change Directory to ',0
    msg_f_cm    db   'Change Permission ',10, 0
    msg_f_cr    db   'Change Root to ',0
    msg_f_cw    db   'Current Working Directory : ',0
    msg_f_ex    db   'Exec Command',10, 0
    msg_f_ls    db   'List Directory ',10, 0
    msg_f_md    db   'Make Directory ',10, 0
    msg_f_mv    db   'Change Name',10, 0
    msg_f_mo    db   'Mount',10, 0
    msg_f_pv    db   'Pivot Root',10, 0
    msg_f_rd    db   'Remove Directory',10, 0
    msg_f_rm    db   'Remove File',10, 0
    msg_f_rt    db   'Reset Termial',10, 0
    msg_f_sf    db   'Swap Off',10, 0
    msg_f_so    db   'Swap On',10, 0
    msg_f_sy    db   'Sync',10, 0
    msg_f_um    db   'Unmount',10, 0
%endif
;==============================================================
section .bss

cgiflag         resd    1
counter         resq    1           ; command
current_arg     resq    1
argc            resq    1           ;
argvp           resq    1           ; argc+8
envp            resq    1           ; argc+16 (exarg - 24)
argc_vtl        resq    1           ; argc+24
argp_vtl        resq    1           ; argc+32
exarg           resq ARGMAX+1       ; execve 用
ipipe           resd    1
opipe           resd    1
ipipe2          resd    1
opipe2          resd    1
save_stack      resq    1

                alignb  4
input2          resb    MAXLINE
FileName        resb    FNAMEMAX
pid             resq    1           ; rbp-40
FOR_direct      resb    1           ; rbp-32
Resvd           resb    2           ; rbp-30
ErrFlag         resb    1           ; rbp-29
VSTACK          resq    1           ; rbp-28
FileDescW       resq    1           ; rbp-20
FileDesc        resq    1           ; rbp-12
ReadFrom        resb    1           ; rbp-4
ExecMode        resb    1           ; rbp-3
EOL             resb    1           ; rbp-2
LSTACK          resb    1           ; rbp-1
VarArea         resq    256         ; rbp    後半128qwordはLSTACK用
VarStack        resq    VSTACKMAX   ; rbp+2048

%ifdef VTL_LABEL
                alignb  4
LabelTable      resq    LABELMAX*4  ; 1024*32 bytes
TablePointer    resq    1
%endif

