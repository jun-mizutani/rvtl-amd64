;---------------------------------------------------------------------
;  RVTL64
;  file : vtllib64.inc
;  2015/08/30
;  Copyright (C) 2010-2015  Jun Mizutani <mizutani.jun@nifty.ne.jp>
;---------------------------------------------------------------------

%ifndef __VTLLIB_INC
%define __VTLLIB_INC

%ifndef __SYSCALL_INC
%include "syscall64.inc"
%endif

%ifndef __STDIO_INC
%include "stdio64.inc"
%endif

%ifndef __SIGNAL_INC
%include "signal64.inc"
%endif

section .bss

%assign         MAXLINE     128         ; Maximum Line Length
%assign         MAX_FILE    256         ; Maximum Filename
%assign         MAXHISTORY   16         ; No. of history buffer
%assign         LINE_TOP      7         ; No. of prompt characters

            align   4,resb 1
struc winsize
        .ws_row     resw 1
        .ws_col     resw 1
        .ws_xpixel  resw 1
        .ws_ypixel  resw 1
endstruc

%assign TIOCGWINSZ      0x5413

%assign NCCS 19

            align   4,resb 1
struc termios
    .c_iflag        resd    1       ; input mode flags
    .c_oflag        resd    1       ; output mode flags
    .c_cflag        resd    1       ; control mode flags
    .c_lflag        resd    1       ; local mode flags
    .c_line         resb    1       ; line discipline
    .c_cc           resb    NCCS    ; control characters
endstruc

struc  timeval
    .tv_sec         resq    1       ;
    .tv_usec        resq    1       ;
endstruc

struc timezone
    .tz_minuteswest resq    1       ;
    .tz_dsttime     resq    1       ;
endstruc

;  c_cc characters
%assign VTIME       5
%assign VMIN        6

;  c_lflag bits
%assign ISIG    0000001q
%assign ICANON  0000002q
%assign XCASE   0000004q
%assign ECHO    0000010q
%assign ECHOE   0000020q
%assign ECHOK   0000040q
%assign ECHONL  0000100q
%assign NOFLSH  0000200q
%assign TOSTOP  0000400q
%assign ECHOCTL 0001000q
%assign ECHOPRT 0002000q
%assign ECHOKE  0004000q
%assign FLUSHO  0010000q
%assign PENDIN  0040000q
%assign IEXTEN  0100000q

%assign TCGETS          0x5401
%assign TCSETS          0x5402

%assign SEEK_SET       0       ; Seek from beginning of file.
%assign SEEK_CUR       1       ; Seek from current position.
%assign SEEK_END       2       ; Seek from end of file.

; from include/linux/resource.h
struc  rusage
        .ru_utime_tv_sec   resd  1; user time used
        .ru_utime_tv_usec  resd  1;
        .ru_stime_tv_sec   resd  1; system time used
        .ru_stime_tv_usec  resd  1;
        .ru_maxrss    resd   1;  maximum rrsident set size
        .ru_ixrss     resd   1;  integral shared memory size
        .ru_idrss     resd   1;  integral unshared data size
        .ru_isrss     resd   1;  integral unshared stack size
        .ru_minflt    resd   1;  page reclaims
        .ru_majflt    resd   1;  page faults
        .ru_nswap     resd   1;  swaps
        .ru_inblock   resd   1;  block input operations
        .ru_oublock   resd   1;  block output operations
        .ru_msgsnd    resd   1;  messages sent
        .ru_msgrcv    resd   1;  messages received
        .ru_nsignals  resd   1;  signals received
        .ru_nvcsw     resd   1;  voluntary context switches
        .ru_nivcsw    resd   1;  involuntary
endstruc

; from include/linux/wait.h
%assign WNOHANG         0x00000001
%assign WUNTRACED       0x00000002

; from include/asm-i386/fcntl.h
%assign O_RDONLY             00q
%assign O_WRONLY             01q
%assign O_RDWR               02q
%assign O_CREAT            0100q ;  not fcntl
%assign O_EXCL             0200q ;  not fcntl
%assign O_NOCTTY           0400q ;  not fcntl
%assign O_TRUNC           01000q ;  not fcntl

; from include/linux/dirent.h
struc dirent
        .d_ino      resq    1
        .d_off      resq    1
        .d_reclen   resw    1
        .d_type     resb    1
        .d_name     resb    256
        ._padding   resb    5
endstruc

; from include/asm/stat.h
struc stat
        .st_dev     resq    1
        .st_ino     resq    1
        .st_nlink   resq    1
        .st_mode    resd    1
        .st_uid     resd    1
        .st_gid     resd    1
        ._padding1  resd    1
        .st_rdev    resq    1
        .st_size    resq    1
        .st_blksize resq    1
        .st_blocks  resq    1
        .st_atime   resq    1
        ._padding2  resq    1
        .st_mtime   resq    1
        ._padding3  resq    1
        .st_ctime   resq    1
        ._padding4  resb   32
endstruc

%assign S_IFMT  00170000q
%assign S_IFSOCK 0140000q
%assign S_IFLNK  0120000q
%assign S_IFREG  0100000q
%assign S_IFBLK  0060000q
%assign S_IFDIR  0040000q
%assign S_IFCHR  0020000q
%assign S_IFIFO  0010000q
%assign S_ISUID  0004000q
%assign S_ISGID  0002000q
%assign S_ISVTX  0001000q

%assign S_IRWXU 00700q
%assign S_IRUSR 00400q
%assign S_IWUSR 00200q
%assign S_IXUSR 00100q

%assign S_IRWXG 00070q
%assign S_IRGRP 00040q
%assign S_IWGRP 00020q
%assign S_IXGRP 00010q

%assign S_IRWXO 00007q
%assign S_IROTH 00004q
%assign S_IWOTH 00002q
%assign S_IXOTH 00001q

; from include/linux/fs.h
%assign MS_RDONLY        1      ; Mount read-only
%assign MS_NOSUID        2      ; Ignore suid and sgid bits
%assign MS_NODEV         4      ; Disallow access to device special files
%assign MS_NOEXEC        8      ; Disallow program execution
%assign MS_SYNCHRONOUS  16      ; Writes are synced at once
%assign MS_REMOUNT      32      ; Alter flags of a mounted FS

; pusha
%macro  _PUSHA 0
    push    rax
    push    rbx
    push    rcx
    push    rdx
    push    rdi
    push    rsi
    push    rbp
%endmacro

; popa
%macro  _POPA 0
    pop     rbp
    pop     rsi
    pop     rdi
    pop     rdx
    pop     rcx
    pop     rbx
    pop     rax
%endmacro

;==============================================================
section .text

;-------------------------------------------------------------------------
; 編集付き行入力(初期文字列付き)
;   rax:バッファサイズ, rbx:バッファ先頭
;   rax に入力文字数を返す
;-------------------------------------------------------------------------
READ_LINE2:
                mov     dword[FLOATING_TOP], LINE_TOP
                _PUSHA
                push    rax                     ; バッファサイズ退避
                mov     rax, rbx                ; 入力バッファ表示
                call    OutAsciiZ
                call    StrLen
                mov     rcx, rax
                pop     rax                     ; バッファサイズ復帰
                lea     rbp, [HistLine]         ; history string ptr
                mov     rdi, rbx                ; Input Buffer
                mov     rdx, rax                ; BufferSize
                mov     rsi, rcx                ; current position
                jmp     short READ_LINE.next_char

;-------------------------------------------------------------------------
; 編集付き行入力
;   rax:バッファサイズ, rbx:バッファ先頭
;   rax に入力文字数を返す
;   カーソル位置を取得して行頭を保存, 複数行にわたるペースト不可
;-------------------------------------------------------------------------
READ_LINE3:
                call    get_cursor_position
                jmp     short READ_LINE.entry

;-------------------------------------------------------------------------
; 編集付き行入力
;   rax:バッファサイズ, rbx:バッファ先頭
;   rax に入力文字数を返す
;-------------------------------------------------------------------------
READ_LINE:
                mov     dword[FLOATING_TOP], LINE_TOP
    .entry:     _PUSHA
                lea     rbp, [HistLine]         ; history string ptr
                mov     rdi, rbx                ; Input Buffer
                mov     rdx, rax                ; BufferSize
                xor     ecx, ecx                ; line length
                mov     esi, ecx                ; current position
    .next_char:
                call    InChar
                cmp     al, 0x1B                ; ESC ?
                jnz     .tab
                call    translate_key_seq

    .tab:       cmp     al, 0x09                ; TAB ?
                jnz     .bs
                call    FilenameCompletion      ; ファイル名補完
                call    DispLine
                jmp     short .next_char

    .bs:        cmp     al, 127                 ; BS (linux console) ?
                je      .bs_0
                cmp     al, 0x08                ; BS ?
                jnz     .delete
    .bs_0:      test    esi, esi                ; if cp=0 then next_char
                jz      .next_char
                call    CursorLeft
                jmp     short .del1

    .delete:
                cmp     al, 0x04                ; ^D ?
                jnz     .cursor_left
    .del1:
                cmp     esi, ecx                ; if cp < eol then del2
                jb      .del2
                jmp     short .next_char
    .del2:
                call    DeleteAtCursor
                jmp     short .next_char

    .cursor_left:
                cmp     al, 0x02                ; ^B
                jnz     .cursor_right
                test    esi, esi                ; if cp = 0 then next_char
                jz      .next_char
                call    CursorLeft
    .next_char2:
                jmp     short .next_char

    .cursor_right:
                cmp     al, 0x06                ; ^F
                jnz     .forward
                cmp     ecx, esi                ; if cp=eol then next_char
                je      .next_char
                call    CursorRight
                jmp     short .next_char2

    .forward:
                cmp     al, 0x0E                ; ^N
                jnz     .backward
                call    regist_history          ; 入力中の行をヒストリへ
                xor     eax, eax
                inc     rax                     ; +1
                call    next_history
                jmp     short .disp

    .backward:
                cmp     al, 0x10                ; ^P
                jnz     .enter_key
                call    regist_history          ; 入力中の行をヒストリへ
                xor     eax, eax
                dec     rax                     ; -1
                call    next_history
    .disp:
                and     eax, 0x0F               ; ヒストリは 0-15
                mov     [rbp], rax              ; HistLine
                call    history2input           ; ヒストリから入力バッファ
                call    DispLine
                jmp     short .next_char2

    .enter_key:
                cmp     al, 0x0A                ; enter ?
                jz      .in_exit
                cmp     al, 0x20
                jb      .next_char2             ; illegal chars

    .in_printable:
                inc     ecx
                inc     esi
                cmp     rcx, rdx                ; buffer size
                jae     .in_toolong
                cmp     esi, ecx
                jb      .insert
                call    OutChar
                mov     [rdi + rsi-1], al
                jmp     .next_char
    .insert:
                call    OutChar
                push    rax
                push    rcx                     ; p = eol
                dec     ecx
    .ins1:      cmp     esi, ecx        ; while(p=>cp){buf[p]=buf[p-1]; p--}
                ja      .ins2
                mov     al, [rdi + rcx - 1]
                mov     [rdi + rcx], al
                dec     ecx
                jmp     short .ins1
    .ins2:
                pop     rcx
                pop     rax
                mov     [rdi + rsi - 1] ,al
                call    print_line_after_cp
                jmp     .next_char

    .in_toolong:
                dec     ecx
                dec     esi
                jmp     .next_char

    .in_exit:
                push    rcx
                call    regist_history
                pop     rcx
                call    NewLine
                mov     [rsp+48], rcx           ; rax に文字数を返す
                _POPA
                ret

    ;----------------------------------
    ; カーソル左1文字 （UTF-8対応）
    ;----------------------------------
    CursorLeft:
                lea     rbx, [CURSOR_LEFT]
                call    OutPString
    .loop:      dec     esi
                mov     al, [rdi + rsi]
                and     al, 0xC0
                jns     .ascii                  ; ASCIIなら1バイトだけ
                cmp     al, 0x80                ; 第2バイト以降の文字?
                je      .loop
                lea     rbx, [CURSOR_LEFT]      ; 日本語は2回右
                call    OutPString
    .ascii:
                ret

    ;----------------------------------
    ; カーソル右1文字 （UTF-8対応）
    ;----------------------------------
    CursorRight:
                lea     rbx, [CURSOR_RIGHT]
                call    OutPString
                xor     ebx, ebx
                mov     al, [rdi + rsi]
                and     al, 0xF0
                js      .mb                     ; 多バイト文字の場合
                inc     esi                     ; ASCIIなら1バイトだけ
                ret
    .mb:
                inc     esi
                shl     al, 1
                jns     .exit
                jmp     short .mb
    .exit:
                lea     rbx, [CURSOR_RIGHT]     ; 日本語は2回右
                call    OutPString
                ret

    ;----------------------------------
    ; カーソル位置1文字削除 （UTF-8対応）
    ;----------------------------------
    DeleteAtCursor:
                lea     rbx, [DEL_AT_CURSOR]
                call    OutPString
                push    rdi
                add     rdi, rsi
                xor     ebx, ebx
                mov     al, [rdi + rbx]
                and     al, 0xF0
                js      .count
                inc     ebx
                jmp     short .done             ; ASCIIなら1バイト
    .count:     ; 1文字のバイト数をカウント
                inc     ebx
                shl     al, 1
                jns     .mb_done
                jmp     short .count
    .mb_done:   push    rbx
                lea     rbx, [DEL_AT_CURSOR]
                call    OutPString
                pop     rbx
    .done:
                pop     rdi
                ; 1文字のバイト数を削除
    .next:      sub     rcx, rbx
                push    rdi
                push    rcx
                add     rcx, rdi        ; rcx = 行末アドレス
                add     rdi, rsi        ; rdi = 文字ポインタのアドレス
    .del:       cmp     rdi, rcx
                je      .done2
                mov     al, [rdi+rbx]
                mov     [rdi], al
                inc     rdi
                jmp     short .del
    .done2:
                pop     rcx
                pop     rdi
                ret

;-------------------------------------------------------------------------
;  入力バッファをプロンプト直後の位置から表示してカーソルは最終
;  entry  rdi : 入力バッファの先頭アドレス
DispLine:
                call    LineTop                 ; カーソルを行先頭に
                mov     rax, rdi
                call    OutAsciiZ               ; 入力バッファを表示
                lea     rbx, [CLEAR_EOL]
                call    OutPString
                call    StrLen
                mov     ecx, eax                ; 入力文字数更新
                mov     esi, ecx                ; 入力位置更新
                ret

;-------------------------------------------------------------------------
;  ファイル名補完機能
;  entry  rsi : 次に文字が入力される入力バッファ中の位置
;         rdi : 入力バッファの先頭アドレス
FilenameCompletion:
                _PUSHA
                add     rsi, rdi
                mov     rcx, rsi            ; (入力済み位置+1)をコピー
                mov     byte[rsi], 0        ; 入力済み文字列末をマーク
                lea     rax, [FileNameBuffer] ; FileNameBuffer初期化
                mov     [FNBPointer], rax   ; FNBPointer=FileNameBuffer
                xor     eax, eax
                mov     [FNCount], eax      ; FNCount=0
                ; 部分パス名の先頭を捜す
    .nextch:
                cmp     byte[rsi], ' '      ; 空白はパス名の区切り
                je      .found              ; 空白なら次の処理
                cmp     byte[rsi], '"'      ; 二重引用符もパス名の区切り
                je      .found              ; 二重引用符でも次の処理
                cmp     rsi, rdi            ; 行頭をチェック
                je      .found2             ; 行頭なら次の処理
                dec     rsi                 ; 後ろから前に検索
                jmp     short .nextch       ; もう一つ前を調べる

    .found:     inc     rsi                 ; 発見したので先頭に設定
    .found2:    cmp     [rsi], al           ; al=0
                jne     .path
                _POPA                       ; 何もない(長さ0)なら終了
                ret

    .path:      dec     rcx                 ; 入力済み文字列最終アドレス
                cmp     byte[rcx], '/'      ; ディレクトリ部分を抽出
                je      .pathend            ; 区切り発見
                cmp     rsi, rcx            ; ディレクトリ部分がない?
                jne     .path
                jmp     short .pathend2
    .pathend:   inc     rcx                 ; ファイル名から/を除く
    .pathend2:  ; ディレクトリ名をコピー
                lea     rbx, [DirName]      ; ディレクトリ保存アドレス
                mov     byte[rbx], 0
                mov     [PartialName], rcx  ; 部分ファイル名先頭
                sub     rcx, rsi
                je      .skip               ; ディレクトリ部分がない
                push    rdi
                mov     rdi, rbx            ; ディレクトリ保存アドレス
                rep movsb                   ; コピー
                mov     byte[rdi], 0        ; 文字列末をマーク
                pop     rdi
    .skip:
                mov     al, [rbx]           ; ディレクトリ部分の最初の文字
                test    al, al              ; 長さ 0 か?
                jne     .list
                lea     rbx, [current_dir]  ; ディレクトリ部分がない時
    .list:      call    fropen              ; ディレクトリオープン
                js      near .exit0
                mov     r12, rax            ; fd
    .getdents:  ; ディレクトリエントリを取得
                mov     rdi, r12            ; rdi : fd
                lea     rsi, [dir_ent]
                mov     edx, size_dir_ent   ; 構造体のサイズ
                mov     eax, SYS_getdents
                syscall                     ;
                mov     rdi, rsi            ; rdi : struct top (dir_ent)
                test    rax, rax            ; valid buffer length
                js      near .exit0         ; システムコールエラー
                je      .checkfile          ; 終了
                mov     rbp, rax            ; rbp : buffer size
    .next:
                call    GetFileStat
                xor     eax, eax
                mov     ax, [file_stat+stat.st_mode]
                and     eax, S_IFDIR
                lea     rbx, [rdi+18]       ; ファイル名先頭アドレス
                call    CopyFilename        ; 一致するファイル名を収集
                movzx   eax, word[rdi+16]   ; rec_len レコード長
                sub     rbp, rax            ; buffer_size - rec_len
                je      .getdents           ; 次のディレクトリエントリ取得
                add     rdi, rax
                jmp     short .next         ; 次のファイル

    .checkfile: ;
                call    Selection           ; ファイルが複数なら表示
                lea     rbp, [FNArray]
                mov     rax, [PartialName]  ; 部分ファイル名までは一致
                call    StrLen
                mov     rdx, rax            ; 部分ファイル名長
                mov     ecx, [FNCount]      ; ファイル数
                or      ecx, ecx
                je      .none               ; 一致するファイル名なし
                dec     ecx
                je      .insert             ; ひとつだけ一致

                ; 複数が一致している場合なるべく長く補完
                xor     edx, edx
    .nextch1:
                mov     ecx, [FNCount]      ; ファイル数
                dec     ecx
                mov     rdi, [rbp]          ; rdi = FNArray[0]
                add     rdi, rax
                mov     bh, [rdi + rdx]     ; bh = (FNArray[0] + rax + rdx)
    .loop:      mov     rdi, [rcx*8 + rbp]  ; bl = (FNArray[rcx] + rax + rdx)
                add     rdi, rax
                mov     bl, [rdi + rdx]
                cmp     bh, bl
                jne     .partially          ; 異なる文字発見
                dec     ecx
                cmp     cl, 1               ; FNArray[0]は処理済
                jae     .loop               ; すべてのファイル名
                inc     rdx
                jmp     short .nextch1

    .partially:
                or      rdx, rdx
                je      .exit               ; 複数あるが追加補完不可
                mov     rbx, [rsp+8]        ; 入力バッファ追加位置(rsi)
                mov     rcx, [rsp+16]       ; 入力バッファ先頭(rdi)
    .nextch2:
                mov     al, [rdi]           ; ファイル名をコピー
                mov     [rcx+rbx], al       ; 入力バッファ
                dec     rdx
                je      .done1
                inc     rbx
                inc     rdi
                jmp     short .nextch2

    .none:      ; 一致するファイル名なし
                lea     rdi, [NoCompletion] ; <none>
                jmp     short .insert1      ; <none>を入力バッファに挿入

    .insert:    ; 完全に一致
                mov     rdi, [rbp]          ; rdi = FNArray[0]
                add     rdi, rdx            ; 部分ファイル名長だけ進める
    .insert1:   mov     rbx, [rsp+8]        ; 入力バッファ追加位置(rsi)
                mov     rcx, [rsp+16]       ; 入力バッファ先頭(rdi)
    .nextch3:   mov     al, [rdi]           ; ファイル名をコピー
                mov     [rcx+rbx], al
                or      al, al              ; 文字列末の0で終了
                je      .done
                inc     rbx
                inc     rdi
                jmp     short .nextch3

    .done1:     xor     eax, eax
                inc     rbx
                mov     [rcx+rbx], al       ; 入力バッファ末に0を追加
    .done:
                mov     [rsp+8], rbx        ; 次に入力される入力バッファ中の位置(rsi)
                mov     [rsp+32], rbx       ; 入力バッファ中の文字数(rcx)
                jmp     short .exit

    .exit0:
%ifndef SMALL_VTL
                call    SysCallError
%endif
    .exit:      mov     rbx, r12            ; fd
                call    fclose
                _POPA
                ret

%assign     S_IFDIR     0040000q

;--------------------------------------------------------------
; ディレクトリ中で一致したファイル名をファイル名バッファに書き込む
; entry rax : ディレクトリフラグ
;       rbx : ファイル名先頭アドレス
;       rcx : 部分ファイル名先頭
;--------------------------------------------------------------
CopyFilename:
                _PUSHA
                lea     rdx, [FNCount]  ; 登録ファイル数
                mov     eax, [rdx]      ; 登録ファイル数
                cmp     eax, MAX_FILE
                jae     .exit
                mov     rsi, rbx        ; ファイル名先頭アドレス
                mov     rcx, [PartialName]

    .next:      mov     al, [rcx]       ; 部分ファイル名
                or      al, al
                je      .ok
                cmp     al, [rbx]       ; ファイル名
                jne     .exit
                inc     rbx
                inc     rcx
                jmp     short .next
    .ok:
                lea     rbp, [FNBPointer]
                mov     rdi, [rbp]
                mov     rax, rsi        ;
                call    StrLen          ; ファイル名の長さを求める
                mov     rcx, rax
                inc     rax             ; 文字列末の/
                inc     rax             ; 文字列末の0
                add     rax, rdi        ; 追加時の最終位置
                cmp     rax, rbp        ; FileNameBufferの直後
                jae     .exit           ; バッファより大きくなる
                mov     eax, [rdx]      ; FNArray[FNCount++]=rdi
                mov     [rax*8 + FNArray], rdi
                inc     rax
                mov     [rdx], eax      ; ファイル名数の更新
                rep     movsb           ; ファイル名のコピー
                mov     rax, [rsp+48]   ; ディレクトリフラグ(rax)
                or      rax, rax        ; ディレクトリ名なら"/"付加
                je      .file
    .dir:       mov     byte[rdi], '/'
                inc     rdi
    .file:      mov     byte[rdi], 0    ; セパレータ(0)を書く
                inc     rdi
                mov     [rbp], rdi      ; 最終位置(FNBPointer)更新
    .exit:
                _POPA
                ret

;--------------------------------------------------------------
; ファイル名バッファの内容表示
Selection:
                _PUSHA
                mov     ecx, [FNCount]
                or      ecx, ecx
                je      .exit           ; 0個なら非表示
                dec     ecx
                je      .exit           ; 1個なら非表示
                inc     ecx
                call    NewLine
                xor     ebx, ebx
    .loop:      mov     rdi, [rbx*8 + FNArray]
                mov     rax, rdi
                mov     rax, rbx
                push    rcx
                xor     ecx, ecx
                mov     cl, 4           ; 4桁
                call    PrintRight      ; 番号表示
                pop     rcx
                mov     al, ' '
                call    OutChar
                mov     rax, rdi
                ;call    PrintHex16
                ;call    NewLine
                call    OutAsciiZ       ; ファイル名表示
                call    NewLine
                inc     ebx
                loop    .loop
    .exit:      _POPA
                ret

;--------------------------------------------------------------
; entry
;   rdi : dirent先頭、+18:ファイル名保存アドレス
;   DirName にディレクトリ名
;--------------------------------------------------------------
GetFileStat:
                _PUSHA
                lea     rbx, [PathName]
                lea     rdx, [rdi+18]       ; rdx = rdi+18
                mov     ecx, MAXLINE
                mov     rdi, rbx            ; PathName
                lea     rax, [DirName]      ; ディレクトリ保存アドレス
                mov     rsi, rax
                call    StrLen
                mov     rcx, rax
                rep     movsb               ; PathName += DirName
                mov     rsi, rdx            ; dirent.d_name
                mov     rax, rsi
                call    StrLen
                mov     rcx, rax
                rep     movsb               ; PathName +=dirent.d_name
                mov     byte[rdi], 0
                mov     eax, SYS_newlstat
                mov     rdi, rbx            ; PathName
                lea     rsi, [file_stat]
                syscall
                _POPA
                ret

;--------------------------------------------------------------
get_cursor_position:
                _PUSHA
                lea     rbx, [CURSOR_REPORT]
                call    OutPString
                call    InChar              ; 返り文字列
                cmp     al, 0x1B            ; ^[[y;xR
                jne     .exit
                call    InChar
                cmp     al, '['
                jne     .exit
                call    get_decimal         ; Y
                mov     ecx, ebx
                call    get_decimal         ; X
                dec     ebx
                mov     [FLOATING_TOP], rbx ; 左マージン
    .exit:      _POPA
                ret
get_decimal:
                xor     ebx, ebx
                call    InChar
                sub     al, '0'
    .gd_loop:
                imul    ebx, 10             ;
                add     ebx, eax
                call    InChar
                sub     al, '0'
                cmp     al,  9
                jle     .gd_loop
                ret

;--------------------------------------------------------------
print_line_after_cp:
                push    rax
                push    rdx
                lea     rbx, [SAVE_CURSOR]
                call    OutPString

                ; 全行表示 2010/06/11
                ; カーソル位置がずれる?
                call    LineTop
                mov     rax, rdi
                mov     rdx, rcx
                call    OutString

;                lea     rbx, [CLEAR_EOL]
;                call    OutPString
;                lea     rax, [rsi+rdi]
;                mov     rdx, rcx
;                sub     rdx, rsi
;                call    OutString

                lea     rbx, [RESTORE_CURSOR]
                call    OutPString
                pop     rdx
                pop     rax
                ret

;--------------------------------------------------------------
translate_key_seq:
                call    InChar
                cmp     al, '['
                jnz     .exit
                call    InChar
    .tk0:       cmp     al, 'A'
                jnz     .tk1
                mov     al, 'P' - 0x40          ; ^P
                ret
    .tk1:       cmp     al, 'B'
                jnz     .tk2
                mov     al, 'N' - 0x40          ; ^N
                ret
    .tk2:       cmp     al, 'C'
                jnz     .tk3
                mov     al, 'F' - 0x40          ; ^F
                ret
    .tk3:       cmp     al, 'D'
                jnz     .tk4
                mov     al, 'B' - 0x40          ; ^B
                ret
    .tk4:       cmp     al, '3'
                jnz     .tk5
                jmp     short .tk5_1
    .tk5:       cmp     al, '4'
                jnz     .exit
    .tk5_1:     call    InChar
                cmp     al, '~'
                mov     al, 4                   ; ^D
                ret
    .exit:      mov     al, 0
                ret

;--------------------------------------------------------------
; 入力バッファをヒストリへ登録
;--------------------------------------------------------------
regist_history:
                mov     byte [rdi + rcx], 0
                call    check_history
                jae     .exit                   ; 同一行登録済み
                mov     rax, [rbp+8]            ; HistUpdate
                call    input2history
                mov     rax, [rbp+8]            ; HistUpdate
                inc     rax
                and     rax, 0x0F
                mov     [rbp+8], rax            ; HistUpdate
                mov     [rbp], rax              ; HistLine
    .exit:      ret

;--------------------------------------------------------------
; ヒストリを rax (1または-1) だけ進める
;--------------------------------------------------------------
next_history:
                push    rdx                     ; buffer size
                push    rbx
                mov     rbx, [rbp]              ; HistLine
                mov     edx, MAXHISTORY
    .next:      dec     rdx
                je      .exit                   ; すべて空なら終了
                push    rax
                add     rbx, rax
                and     ebx, MAXHISTORY-1
                mov     rax, rbx
                call    GetHistory
                call    StrLen
                or      rax, rax
                pop     rax
                je      .next
    .exit:      mov     rax, rbx
                pop     rbx
                pop     rdx                     ; buffer size
                ret

;--------------------------------------------------------------
; 入力バッファと同じ内容のヒストリバッファがあるかチェック
;   rdi : input buffer
;--------------------------------------------------------------
check_history:
                _PUSHA
                mov     rbp, rdi                ; input buffer top
                lea     rsi, [history0]
                mov     ecx, MAXHISTORY
    .nextline:
                mov     rdi, rbp                ; input buffer top
                xor     ebx, ebx
    .nextchar:  mov     al, [rdi]
                cmp     al, [rsi+rbx]
                jne     .neq
                test    al, al
                je      .equal
                inc     rdi
                inc     rbx
                jmp     .nextchar
    .neq:
                add     rsi, MAXLINE
                loop    .nextline
                stc
                jmp     short .exit
    .equal:
                clc
    .exit:      _POPA
                ret

;--------------------------------------------------------------
; 入力バッファのインデックスをアドレスに変換
;   enter  rax : ヒストリバッファのインデックス (0..15)
;   exit   rax : historyinput buffer top address
;--------------------------------------------------------------
GetHistory:
                push    rdx
                mov     ecx, MAXLINE
                mul     rcx
                add     rax, history0
                pop     rdx
                ret

;--------------------------------------------------------------
; 入力バッファからヒストリバッファへコピー
;   rax : ヒストリバッファのインデックス (0..15)
;   rdi : input buffer
;--------------------------------------------------------------
input2history:
                push    rsi
                push    rdi
                mov     rsi, rdi
                call    GetHistory
                mov     rdi, rax
                jmp     short history2input.loop

;--------------------------------------------------------------
; ヒストリバッファから入力バッファへコピー
;   rax : ヒストリバッファのインデックス (0..15)
;   rdi : input buffer
;--------------------------------------------------------------
history2input:
                push    rsi
                push    rdi
                call    GetHistory
                mov     rsi, rax
    .loop:      mov     al, [rsi]
                mov     [rdi], al
                cmp     al, 0
                je      .done
                inc     rsi
                inc     rdi
                loop    .loop
    .done:
                pop     rdi
                pop     rsi
                ret

;--------------------------------------------------------------
; 行先頭にカーソルを移動(左マージン付)
LineTop:
                push    rcx
                lea     rbx, [CURSOR_TOP]
                call    OutPString
                lea     rbx, [CURSOR_RIGHT]
                mov     ecx, [FLOATING_TOP] ; 左マージン
                or      rcx, rcx
                je      .exit
    .next:      call    OutPString
                loop    .next
    .exit:      pop     rcx
                ret

;--------------------------------------------------------------
; 現在の termios を保存
GET_TERMIOS:
                _PUSHA
                lea     rsi, [old_termios]
                lea     rdi, [new_termios]
                mov     rbx, rsi            ; old_termios
                call    tcgetattr
                mov     rcx, rdi            ; new_termios
                sub     rcx, rsi
        rep     movsb
                _POPA
                ret

;--------------------------------------------------------------
; 新しい termios を設定
; Rawモード, ECHO 無し, ECHONL 無し
; VTIME=0, VMIN=1 : 1バイト読み取られるまで待機
SET_TERMIOS:
                _PUSHA
                lea     rdi, [new_termios+termios.c_lflag]
                mov     eax, [rdi]
                and     eax, ~ICANON & ~ECHO & ~ECHONL
                or      eax, ISIG
                mov     [rdi], eax
                xor     eax, eax
                inc     eax
                lea     rdi, [new_termios+termios.c_cc]
                mov     [rdi + VMIN], al    ; 1
                dec     eax
                mov     [rdi + VTIME], al   ; 0
                lea     rbx, [new_termios]
                call    tcsetattr
                _POPA
                ret

;--------------------------------------------------------------
; 現在の termios を Cooked モードに設定
; Cookedモード, ECHO あり, ECHONL あり
; VTIME=1, VMIN=0
SET_TERMIOS2:
                _PUSHA
                lea     rdi, [new_termios+termios.c_lflag]
                mov     eax, [rdi]
                and     eax, ICANON | ECHO & ECHONL
                or      eax, ISIG
                mov     [rdi], eax
                xor     eax, eax
                lea     rdi, [new_termios+termios.c_cc]
                mov     [rdi + VMIN], al    ; 0
                inc     eax
                mov     [rdi + VTIME], al   ; 1
                lea     rbx, [new_termios]
                call    tcsetattr
                _POPA
                ret

;--------------------------------------------------------------
; 保存されていた termios を復帰
RESTORE_TERMIOS:
                _PUSHA
                lea     rbx, [old_termios]
                call    tcsetattr
                _POPA
                ret

;--------------------------------------------------------------
; 標準入力の termios の取得と設定
; tcgetattr(&termios)
; tcsetattr(&termios)
; rax : destroyed
; rbx : termios buffer adress
; rcx, rdx : destroyed
tcgetattr:
                mov     eax, TCGETS
                jmp     short IOCTL

tcsetattr:
                mov     eax, TCSETS

;--------------------------------------------------------------
; 標準入力の ioctl の実行
; sys_ioctl(unsigned int fd, unsigned int cmd,
;           unsigned long arg)
; rax : cmd
; rbx : buffer adress
IOCTL:
                push    rdi
                push    rsi
                mov     rsi, rax            ; set cmd
                mov     rdx, rbx            ; set arg
                mov     eax, SYS_ioctl      ; sys_ioctl
                xor     edi, edi            ; 0 : to stdin
                syscall                     ; call kernel
                pop     rsi
                pop     rdi
                ret

;------------------------------------
; input 1 character from stdin
; rax : get char (0:not pressed)
RealKey:
                _PUSHA
                lea     rbp, [new_termios+termios.c_cc]
                mov     [rbp + VMIN], byte 0    ; 0
                lea     rbx, [new_termios]
                call    tcsetattr
                push    rax                 ; work buffer on stack
                xor     edi, edi            ; 0:from stdin
                mov     rsi, rsp            ; into Input Buffer
                mov     edx, edi
                inc     edx                 ; 1 char
                mov     eax, SYS_read
                syscall                     ; call kernel
                pop     rbx                 ; set char
                test    rax, rax            ; if 0 then empty
                je      .nohit
                mov     rax, rbx            ; char code
    .nohit:     mov     [rsp+48], rax       ; return rax with key
                mov     [rbp + VMIN], byte 1; 1
                lea     rbx, [new_termios]
                call    tcsetattr
                _POPA
                ret

;------------------------------------
; get window size
; rax : column(upper 16bit), raw(lower 16bit)
WinSize:        _PUSHA
                mov     eax, SYS_ioctl
                xor     edi, edi            ; to stdout
                mov     esi, TIOCGWINSZ     ; get wondow size
                lea     rdx, [wsize]
                syscall                     ; call kernel
                xor     eax, eax
                mov     ax, [rdx + winsize.ws_col]
                mov     cl, 16
                shl     rax, cl
                mov     ax, [rdx + winsize.ws_row]
                mov     [rsp+48], rax       ; return rax
                _POPA
                ret

;-------------------------------------------------------------------------
; ファイルをオープン
; enter   rbx: 第１引数 filename
; return  rax: fd, if error then rax will be negative.
;-------------------------------------------------------------------------
fropen:
                push    rdi
                push    rsi
                mov     rsi, O_RDONLY       ; 第２引数 flag
                jmp     short fopen
fwopen:
                push    rdi
                push    rsi
                mov     esi, O_CREAT | O_WRONLY | O_TRUNC
fopen:          mov     eax, SYS_open       ; システムコール番号
                mov     rdi, rbx
                mov     edx, 0644q          ; 第３引数 mode
                syscall                     ; ★
                test    rax,rax             ; rax <- fd
                pop     rsi
                pop     rdi
                ret

;-------------------------------------------------------------------------
; ファイルをクローズ
; enter   rbx: 第１引数 ファイルディスクリプタ
;-------------------------------------------------------------------------
fclose:         push    rdi
                mov     eax, SYS_close      ; システムコール番号
                mov     rdi, rbx
                syscall
                pop     rdi
                ret


;==============================================================
section .data

FLOATING_TOP    dq      0         ; No. of prompt characters
HistLine        dq      0
HistUpdate      dq      0
CURSOR_REPORT   db      4, 0x1B, "[6n"
SAVE_CURSOR     db      2, 0x1B, '7'             ; ^[7
RESTORE_CURSOR  db      2, 0x1B, '8'             ; ^[8
DEL_AT_CURSOR   db      4, 0x1B, "[1P"           ; ^[[1P
CURSOR_RIGHT    db      4, 0x1B, "[1C"           ; ^[[1C
CURSOR_LEFT     db      4, 0x1B, "[1D"           ; ^[[1D
CURSOR_TOP      db      1, 0x0D
CLEAR_EOL       db      4, 0x1B, "[0K"           ; ^[[0K
CSI             db      2, 0x1B, '['             ; ^[[
NoCompletion    db      "<none>",0
current_dir     db      './',0

;==============================================================
section .bss

input           resb MAXLINE
history0        resb MAXLINE * MAXHISTORY

DirName         resb MAXLINE
PathName        resb MAXLINE

PartialName     resq 1          ; 部分ファイル名先頭アドレス格納
FileNameBuffer  resd 512        ; 2kbyte for filename completion
FNBPointer      resq 1          ; FileNameBufferの格納済みアドレス+1
FNCount         resd 1          ; No. of Filenames
FNArray         resq MAX_FILE   ; *Filename[0..255]

            align   8,resb 1
wsize:      resb  winsize_size

            align   8,resb 1
old_termios: resb  termios_size

            align   8,resb 1
new_termios: resb  termios_size

            align   8,resb 1
new_sig:    resb  sigaction_size
            align   8,resb 1
old_sig:    resb  sigaction_size
            align   8,resb 1
TV:         resb  timeval_size
            align   8,resb 1
TZ:         resb  timeval_size
            align   8,resb 1
;ru:         resb   rusage_size
;            align   8,resb 1
dir_ent:    resb  dirent_size

size_dir_ent    equ         $ - dir_ent

            align   8,resb 1
file_stat:  resb    stat_size

%endif
