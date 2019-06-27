//-------------------------------------------------------------------------
// Return of the Very Tiny Language for ARM64
// file : vtllib.s
// 2019/06/27
// Copyright (C) 2003-2019 Jun Mizutani <mizutani.jun@nifty.ne.jp>
// vtllib.s may be copied under the terms of the GNU General Public License.
//-------------------------------------------------------------------------

.ifndef __VTLLIB
__VTLLIB = 1

.include "syscalls.s"
.include "signal.s"
.include "stdio.s"
.include "registers.s"

//==============================================================
.text

MAXLINE      = 128         // Maximum Line Length
MAX_FILE     = 256         // Maximum Filename
MAXHISTORY   =  16         // No. of history buffer

TIOCGWINSZ   = 0x5413

NCCS  = 19

//  c_cc characters
VTIME     = 5
VMIN      = 6

//  c_lflag bits
ISIG      = 0000001
ICANON    = 0000002
XCASE     = 0000004
ECHO      = 0000010
ECHOE     = 0000020
ECHOK     = 0000040
ECHONL    = 0000100
NOFLSH    = 0000200
TOSTOP    = 0000400
ECHOCTL   = 0001000
ECHOPRT   = 0002000
ECHOKE    = 0004000
FLUSHO    = 0010000
PENDIN    = 0040000
IEXTEN    = 0100000

TCGETS    = 0x5401
TCSETS    = 0x5402

SEEK_SET  = 0               // Seek from beginning of file.
SEEK_CUR  = 1               // Seek from current position.
SEEK_END  = 2               // Seek from end of file.

// from include/linux/wait.h
WNOHANG   = 0x00000001
WUNTRACED = 0x00000002

// from include/asm-i386/fcntl.h
O_RDONLY =    00
O_WRONLY =    01
O_RDWR   =    02
O_CREAT  =  0100
O_EXCL   =  0200
O_NOCTTY =  0400
O_TRUNC  = 01000

S_IFMT   = 0170000
S_IFSOCK = 0140000
S_IFLNK  = 0120000
S_IFREG  = 0100000
S_IFBLK  = 0060000
S_IFDIR  = 0040000
S_IFCHR  = 0020000
S_IFIFO  = 0010000
S_ISUID  = 0004000
S_ISGID  = 0002000
S_ISVTX  = 0001000

S_IRWXU  = 00700
S_IRUSR  = 00400
S_IWUSR  = 00200
S_IXUSR  = 00100

S_IRWXG  = 00070
S_IRGRP  = 00040
S_IWGRP  = 00020
S_IXGRP  = 00010

S_IRWXO  = 00007
S_IROTH  = 00004
S_IWOTH  = 00002
S_IXOTH  = 00001

// from include/linux/fs.h
MS_RDONLY       =  1        // Mount read-only
MS_NOSUID       =  2        // Ignore suid and sgid bits
MS_NODEV        =  4        // Disallow access to device special files
MS_NOEXEC       =  8        // Disallow program execution
MS_SYNCHRONOUS  = 16        // Writes are synced at once
MS_REMOUNT      = 32        // Alter flags of a mounted FS

//-------------------------------------------------------------------------
// 編集付き行入力(初期文字列付き)
//   x0:バッファサイズ, x1:バッファ先頭
//   x0 に入力文字数を返す
//-------------------------------------------------------------------------
        .align  2
READ_LINE2:
        adr     x2, LINE_TOP
        ldr     x3, [x2]
        str     x3, [x2, #8]           // FLOATING_TOP=LINE_TOP
        stp     x1, x30, [sp, #-16]!
        stp     x2, x3,  [sp, #-16]!
        mov     xip, x0                // バッファサイズ退避
        mov     x2, x1                 // 入力バッファ先頭退避
        mov     x0, x1                 // 入力バッファ表示
        bl      OutAsciiZ
        bl      StrLen                 // <r0:アドレス, >r1:文字数
        mov     rv4, x1                // 行末位置
        mov     x1, x2                 // バッファ先頭復帰
        mov     x0, xip                // バッファサイズ復帰
        b       RL_0

//-------------------------------------------------------------------------
// 編集付き行入力
//   x0:バッファサイズ, x1:バッファ先頭
//   x0 に入力文字数を返す
//   カーソル位置を取得して行頭を保存, 複数行にわたるペースト不可
//-------------------------------------------------------------------------
READ_LINE3:
        stp     x1, x30, [sp, #-16]!
        bl      get_cursor_position
        ldp     x1, x30, [sp], #16
        b       RL

//-------------------------------------------------------------------------
// 編集付き行入力
//   x0:バッファサイズ, x1:バッファ先頭
//   x0 に入力文字数を返す
//-------------------------------------------------------------------------
READ_LINE:
        adr     x2, LINE_TOP
        ldr     x3, [x2]
        str     x3, [x2, #8]           // FLOATING_TOP=LINE=TOP
RL:
        stp     x1, x30, [sp, #-16]!
        stp     x2, x3,  [sp, #-16]!
        mov     rv4, #0                // 行末位置
RL_0:
        adr     rv3, HistLine          // history string ptr
        mov     rv1, x1                // Input Buffer
        mov     x2, #0
        strb    w2, [rv1, rv4]         // mark EOL
        mov     rv2, x0                // BufferSize
        mov     rv5, rv4               // current position
RL_next_char:
        bl      InChar
        cmp     x0, #0x1B              // ESC ?
        bne     1f
        bl      translate_key_seq
    1:  cmp     x0, #0x09              // TAB ?
        beq     RL_tab
        cmp     x0, #127               // BS (linux console) ?
        beq     RL_bs
        cmp     x0, #0x08              // BS ?
        beq     RL_bs
        cmp     x0, #0x04              // ^D ?
        beq     RL_delete
        cmp     x0, #0x02              // ^B
        beq     RL_cursor_left
        cmp     x0, #0x06              // ^F
        beq     RL_cursor_right
        cmp     x0, #0x0E              // ^N
        beq     RL_forward
        cmp     x0, #0x10              // ^P
        beq     RL_backward
        cmp     x0, #0x0A              // enter ?
        beq     RL_in_exit
        cmp     x0, #0x20
        blo     RL_next_char           // illegal chars
RL_in_printable:
        add     rv4, rv4, #1           // eol
        add     rv5, rv5, #1           // current position
        cmp     rv4, rv2               // buffer size
        bhs     RL_in_toolong
        cmp     rv5, rv4               // at eol?
        blo     RL_insert              //  No. Insert Char
        bl      OutChar                //  Yes. Display Char
        sub     xip, rv5, #1           // before cursor
        strb    w0, [rv1, xip]
        b       RL_next_char
RL_insert:
        cmp     x0, #0x80
        bhs     0f
        bl      OutChar
    0:  sub     xip, rv4, #1           // p = eol-1
    1:
        cmp     rv5, xip               // while(p=>cp){buf[p]=buf[p-1]; p--}
        bhi     2f                     //   if(rv5>ip) goto2
        sub     x1, xip, #1            //   x1=ip-1
        ldrb    w2, [rv1, x1]
        strb    w2, [rv1, xip]
        mov     xip, x1                // xip--
        b       1b
    2:
        sub     xip, rv5, #1
        strb    w0, [rv1, xip]         // before cursor

        cmp     x0, #0x80
        bhs     3f
        bl      print_line_after_cp
        b       RL_next_char
    3:
        bl      print_line
        b       RL_next_char
RL_in_toolong:
        sub     rv4, rv4, #1
        sub     rv5, rv5, #1
        b       RL_next_char
RL_in_exit:
        bl      regist_history
        bl      NewLine
        mov     x0, rv4                // x0 に文字数を返す
        ldp     x2, x3,  [sp], #16
        ldp     x1, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// BackSpace or Delete Character
//-------------------------------------------------------------------------
RL_bs:
        tst     rv5, rv5               // if cp=0 then next_char
        beq     RL_next_char
        bl      cursor_left

  RL_delete:
        cmp     rv5, rv4               // if cp < eol then del2
        beq     RL_next_char           // 行末でDELでは何もしない
        ldrb    w0, [rv1, rv5]         // 1文字目確認
        and     x0, x0, #0xC0
        cmp     x0, #0xC0
        bne     1f
        adr     x0, DEL_AT_CURSOR      // 漢字なら2回1文字消去
        bl      OutPString
    1:  bl      RL_del1_char           // 1文字削除
        cmp     rv5, rv4               // if cp < eol then del2
        beq     2f                     // 行末なら終了
        ldrb    w0, [rv1, rv5]         // 2文字目文字取得
        and     x0, x0, #0xC0
        cmp     x0, #0x80
        beq     1b                     // UTF-8 後続文字 (ip==0x80)
    2:  adr     x0, DEL_AT_CURSOR      // 1文字消去
        bl      OutPString
        b       RL_next_char

 RL_del1_char:                         // while(p<eol){*p++=*q++;}
        stp     x1, x30, [sp, #-16]!
        stp     x2, x3,  [sp, #-16]!
        add     x2, rv5, rv1           // p
        add     x1, rv4, rv1           // eol
        add     x3, x2, #1             // q=p+1
    1:  ldrb    w0, [x3], #1           // *p++ = *q++;
        strb    w0, [x2], #1
        cmp     x3, x1
        bls     1b
        sub     rv4, rv4, #1
        ldp     x2, x3,  [sp], #16
        ldp     x1, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// Filename Completion
//-------------------------------------------------------------------------
RL_tab:
        bl      FilenameCompletion     // ファイル名補完
        bl      DispLine
        b       RL_next_char

//-------------------------------------------------------------------------
RL_cursor_left:
        bl      cursor_left
        b       RL_next_char

cursor_left:
        stp     x0, x30, [sp, #-16]!
        tst     rv5, rv5               // if cp = 0 then next_char
        beq     2f                     // 先頭なら何もしない
        adr     x0, CURSOR_LEFT        // カーソル左移動、
        bl      OutPString
    1:
        sub     rv5, rv5, #1           // 文字ポインタ-=1
        ldrb    w0, [rv1, rv5]         // 文字取得
        and     x0, x0, #0xC0
        cmp     x0, #0x80
        beq     1b                     // 第2バイト以降のUTF-8文字
        blo     2f                     // ASCII
        adr     x0, CURSOR_LEFT        // 第1バイト発見、日本語は2回左
        bl      OutPString
    2:
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
RL_cursor_right:
        bl      cursor_right
        b       RL_next_char

cursor_right:
        stp     x0, x30, [sp, #-16]!
        cmp     rv4, rv5               // if cp=eol then next_char
        beq     3f                     // 行末なら何もしない
        adr     x0, CURSOR_RIGHT
        bl      OutPString

        ldrb    w0, [rv1, rv5]         // 文字取得
        lsl     xip, x0, #24
        ands    xip, xip, #0xF0000000
        bmi     1f                     // UTF-8多バイト文字の場合
        add     rv5, rv5, #1           // ASCIIなら1バイトだけ
        b       3f
    1:
        add     rv5, rv5, #1           // 最大4byteまで文字位置を更新
        adds    xip, xip, xip
        bmi     1b
    2:
        adr     x0, CURSOR_RIGHT
        bl      OutPString
    3:
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
RL_forward:
        bl      regist_history      // 入力中の行をヒストリへ
        mov     x0, #1
        bl      next_history
        b       RL_disp
RL_backward:
        bl      regist_history      // 入力中の行をヒストリへ
        mov     x0, #-1
        bl      next_history
RL_disp:
        and     x0, x0, #0x0F       // ヒストリは 0-15
        str     x0, [rv3]           // HistLine
        bl      history2input       // ヒストリから入力バッファ
        bl      DispLine
        b       RL_next_char

//-------------------------------------------------------------------------
// 行頭マージン設定
//   x0 : 行頭マージン設定
//-------------------------------------------------------------------------
set_linetop:
        stp     x1, x30, [sp, #-16]!
        adr     x1, LINE_TOP
        str     x0, [x1]
        ldp     x1, x30, [sp], #16
        ret

//--------------------------------------------------------------
// 入力バッファをヒストリへ登録
//   rv1 : input buffer address
//   rv3 : history string ptr
//   rv4 : eol (length of input string)
//   x0,x1,x2,x3 : destroy
//--------------------------------------------------------------
regist_history:
        stp     x0, x30, [sp, #-16]!
        mov     x0, #0
        strb    w0, [rv1, rv4]         // write 0 at eol
        bl      check_history
        tst     x1, x1
        beq     1f                     // 同一行登録済み

        ldr     x0, [rv3, #+8]         // HistUpdate
        bl      input2history
        ldr     x0, [rv3, #+8]         // HistUpdate
        add     x0, x0, #1
        and     x0, x0, #0x0F          // 16entry
        str     x0, [rv3, #+8]         // HistUpdate
        str     x0, [rv3]              // HistLine
    1:  ldp     x0, x30, [sp], #16
        ret

//--------------------------------------------------------------
// ヒストリを x0 (1または-1) だけ進める
//    return : x0 = next entry
//--------------------------------------------------------------
next_history:
        stp     x1, x30, [sp, #-16]!
        stp     x2, x3,  [sp, #-16]!
        stp     rv1, rv2,  [sp, #-16]!
        ldr     rv1, [rv3]             // HistLine
        mov     x2, #MAXHISTORY
        mov     x3, x0
    1:  subs    x2, x2, #1             //
        blt     2f                     // すべて空なら終了
        add     rv1, rv1, x3           // +/-1
        and     rv1, rv1, #0x0F        // wrap around
        mov     x0, rv1                // 次のエントリー
        bl      GetHistory             // x0 = 先頭アドレス
        bl      StrLen                 // <r0:アドレス, >r1:文字数
        tst     x1, x1
        beq     1b                     // 空行なら次
    2:
        mov     x0, rv1                // エントリーを返す
        ldp     rv1, rv2,  [sp], #16
        ldp     x2, x3,  [sp], #16
        ldp     x1, x30, [sp], #16
        ret

//--------------------------------------------------------------
// すべてのヒストリ内容を表示
//--------------------------------------------------------------
disp_history:
        stp     x0, x30, [sp, #-16]!
        stp     x1, x2,  [sp, #-16]!
        stp     x3, x4,  [sp, #-16]!
        adr     x2, history
        mov     x3, #0                 // no. of history lines
    1:
        adr     x1, HistLine
        ldr     x0, [x1]
        cmp     x3, x0
        bne     2f
        mov     x0, #'*'
        b       3f
    2:  mov     x0, #' '
    3:  bl      OutChar

        mov     x0, x3                 // ヒストリ番号
        mov     x1, #2                 // 2桁
        bl      PrintRight0
        mov     x0, #' '
        bl      OutChar
        mov     x0, x2
        bl      OutAsciiZ
        bl      NewLine
        add     x2, x2, #MAXLINE       // next history string
        add     x3, x3, #1
        cmp     x3, #MAXHISTORY
        bne     1b                     // check next
        ldp     x3, x4,  [sp], #16
        ldp     x1, x2,  [sp], #16
        ldp     x0, x30, [sp], #16
        ret

//--------------------------------------------------------------
// すべてのヒストリ内容を消去
//--------------------------------------------------------------
erase_history:
        stp     x0, x30, [sp, #-16]!
        stp     x1, x2,  [sp, #-16]!
        adr     x2, history
        mov     x1, #0                 // no. of history lines
        mov     x0, #0
    1:  str     x0, [x2]
        add     x2, x2, #MAXLINE       // next history
        add     x1, x1, #1
        cmp     x1, #MAXHISTORY
        bne     1b                     // check next
        ldp     x1, x2,  [sp], #16
        ldp     x0, x30, [sp], #16
        ret

//--------------------------------------------------------------
// 入力バッファと同じ内容のヒストリバッファがあるかチェック
//   rv1 : input buffer address
//   rv4 : eol (length of input string)
//   x1 : if found then return 0
//   x0,r2,r3 : destroy
//--------------------------------------------------------------
check_history:
        stp     rv1, x30, [sp, #-16]!
        stp     rv2, rv3,  [sp, #-16]!
        mov     rv3, rv1               // save input buffer top
        adr     rv2, history
        mov     x3, #MAXHISTORY        // no. of history lines
    1:
        mov     rv1, rv3               // restore input buffer top
        mov     x2, #0                 // string top

    2:  ldrb    w0, [rv1], #1          // compare char, rv1++
        ldrb    w1, [rv2, x2]
        cmp     x0, x1
        bne     3f                     // different char
        tst     x0, x0                 // eol ?
        beq     4f                     // found
        add     x2, x2, #1             // next char
        b       2b

    3:  add     rv2, rv2, #MAXLINE     // next history string
        subs    x3, x3, #1
        bne     1b                     // check next

        mov     x1, #1                 // compare all, not found
        b       5f

    4:  mov     x1, #0                 // found
    5:  ldp     rv2, rv3,  [sp], #16
        ldp     rv1, x30, [sp], #16
        ret

//--------------------------------------------------------------
// 入力バッファのインデックスをアドレスに変換
//   enter  x0 : ヒストリバッファのインデックス (0..15)
//   exit   x0 : historyinput buffer top address
//--------------------------------------------------------------
GetHistory:
        stp     x1, x30, [sp, #-16]!
        stp     x2, x3,  [sp, #-16]!
        mov     x1, #MAXLINE
        adr     x2, history
        madd    x0, x1, x0, x2         // x0=r1*r0+r2
        ldp     x2, x3,  [sp], #16
        ldp     x1, x30, [sp], #16
        ret

//--------------------------------------------------------------
// 入力バッファからヒストリバッファへコピー
//   x0 : ヒストリバッファのインデックス (0..15)
//   rv1 : input buffer
//--------------------------------------------------------------
input2history:
        stp     x0, x30, [sp, #-16]!
        stp     x1, rv1,  [sp, #-16]!
        mov     x1, rv1
        bl      GetHistory
        mov     rv1, x0
        b       1f

//--------------------------------------------------------------
// ヒストリバッファから入力バッファへコピー
//   x0 : ヒストリバッファのインデックス (0..15)
//   rv1 : input buffer
//--------------------------------------------------------------
history2input:
        stp     x0, x30, [sp, #-16]!
        stp     x1, rv1,  [sp, #-16]!
        bl      GetHistory
        mov     x1, x0
    1:  ldrb    w0, [x1], #1
        strb    w0, [rv1], #1
        cmp     x0, #0
        bne     1b
        ldp     x1, rv1,  [sp], #16
        ldp     x0, x30, [sp], #16
        ret

//--------------------------------------------------------------
//  入力バッファをプロンプト直後の位置から表示してカーソルは最終
//  entry  rv1 : 入力バッファの先頭アドレス
//--------------------------------------------------------------
DispLine:
        stp     x0, x30, [sp, #-16]!
        bl      LineTop                // カーソルを行先頭に
        mov     x0, rv1
        bl      OutAsciiZ              // 入力バッファを表示
        adr     x0, CLEAR_EOL
        bl      OutPString
        mov     x0, rv1
        bl      StrLen                 // <r0:アドレス, >r1:文字数
        mov     rv4, x1                // 入力文字数更新
        mov     rv5, rv4               // 入力位置更新
        ldp     x0, x30, [sp], #16
        ret

//--------------------------------------------------------------
// カーソル位置を取得
get_cursor_position:
        stp     x0, x30, [sp, #-16]!
        stp     x1, x2,  [sp, #-16]!
        stp     x3, x4,  [sp, #-16]!
        adr     x0, CURSOR_REPORT
        bl      OutPString
        bl      InChar                 // 返り文字列
        cmp     x0, #0x1B              // ^[[y;xR
        bne     1f
        bl      InChar
        cmp     x0, #'['
        bne     1f
        bl      get_decimal            // Y
        mov     x3, x1
        bl      get_decimal            // X
        sub     x1, x1, #1
        adr     x0, FLOATING_TOP
        str     x1, [x0]               // 左マージン
    1:  ldp     x3, x4,  [sp], #16
        ldp     x1, x2,  [sp], #16
        ldp     x0, x30, [sp], #16
        ret

get_decimal:
        stp     x3, x30, [sp, #-16]!
        mov     x1, #0
        mov     x3, #10
        bl      InChar
        sub     x0, x0, #'0
    1:  mul     x2, x1, x3             //
        add     x1, x0, x2
        bl      InChar
        sub     x0, x0, #'0
        cmp     x0, #9
        ble     1b
        ldp     x3, x30, [sp], #16
        ret

//--------------------------------------------------------------
// rv5 = cursor position
print_line_after_cp:
        stp     x0, x30, [sp, #-16]!
        adr     x0, SAVE_CURSOR
        bl      OutPString
        adr     x0, CLEAR_EOL
        bl      OutPString
        add     x0, rv5, rv1           // address
        sub     x1, rv4, rv5           // length
        bl      OutString
        adr     x0, RESTORE_CURSOR
        bl      OutPString
        ldp     x0, x30, [sp], #16
        ret

//--------------------------------------------------------------
//
print_line:
        stp     x0, x30, [sp, #-16]!
        bl      LineTop
        mov     x0, rv1                // address
        mov     x1, rv4                // length
        bl      OutString
        bl      setup_cursor
        ldp     x0, x30, [sp], #16
        ret

setup_cursor:
        stp     x0, x30, [sp, #-16]!
        bl      LineTop
        mov     x1, #0
        cmp     x1, rv5
        beq     4f
    1:  ldrb    w0, [rv1, x1]
        and     x0, x0, #0xC0
        cmp     x0, #0x80              // 第2バイト以降のUTF-8文字
        beq     3f
        blo     2f
        adr     x0, CURSOR_RIGHT
        bl      OutPString
    2:  adr     x0, CURSOR_RIGHT
        bl      OutPString
    3:  add     x1, x1, #1
        cmp     x1, rv5
        bne     1b
    4:  ldp     x0, x30, [sp], #16
        ret

//--------------------------------------------------------------
// Translate Function Key into ctrl-sequence
translate_key_seq:
        stp     x1, x30, [sp, #-16]!   // x1:filler
        bl      InChar
        cmp     x0, #'[
        beq     1f
        mov     x0, xzr
        b       7f                     // return

    1:  bl      InChar
        cmp     x0, #'A
        bne     2f
        mov     x0, #'P - 0x40         // ^P
        b       7f                     // return

    2:  cmp     x0, #'B
        bne     3f
        mov     x0, #'N - 0x40         // ^N
        b       7f                     // return

    3:  cmp     x0, #'C
        bne     4f
        mov     x0, #'F - 0x40         // ^F
        b       7f                     // return

    4:  cmp     x0, #'D
        bne     5f
        mov     x0, #'B - 0x40         // ^B
        b       7f                     // return

    5:  cmp     x0, #'3                // ^[[3~ (Del)
        bne     6f
        cmp     x0, #'4                // ^[[4~ (End)
        b       7f                     // return

    6:  bl      InChar
        cmp     x0, #'~
        bne     7f
        mov     x0, #4                 // ^D

    7:  ldp     x1, x30, [sp], #16
        ret

//--------------------------------------------------------------
// 行先頭にカーソルを移動(左マージン付)
LineTop:
        stp     x0, x30, [sp, #-16]!
        stp     x1, x2,  [sp, #-16]!
        adr     x0, CURSOR_TOP
        bl      OutPString
        adr     x0, CURSOR_RIGHT
        adr     x2, FLOATING_TOP        // 左マージン
        ldr     x2, [x2]
        tst     x2, x2                  // if 0 return
        beq     2f
    1:  bl      OutPString
        subs    x2, x2, #1
        bne     1b
    2:
        ldp     x1, x2,  [sp], #16
        ldp     x0, x30, [sp], #16
        ret

//--------------------------------------------------------------
//  ファイル名補完機能
//  entry  rv5 : 次に文字が入力される入力バッファ中の位置
//         rv1 : 入力バッファの先頭アドレス
//--------------------------------------------------------------
FilenameCompletion:
        stp     x0, x30, [sp, #-16]!
        stp     x1, x2,  [sp, #-16]!
        stp     rv1, rv2,[sp, #-16]!
        stp     rv3, rv4,[sp, #-16]!
        stp     rv5, rv6,[sp, #-16]!
        stp     rv7, rv8,[sp, #-16]!
        adr     rv2, FileNameBuffer     // FileNameBuffer初期化
        adr     rv6, DirName
        adr     rv7, FNArray            // ファイル名へのポインタ配列
        adr     rv8, PartialName        // 入力バッファ内のポインタ
        bl      ExtractFilename         // 入力バッファからパス名を取得
        ldrb    w0, [rv1]               // 行頭の文字
        cmp     x0, #0                  // 行の長さ0？
        beq     1f
        bl      GetDirectoryEntry       // ファイル名をコピー
        bl      InsertFileName          // 補完して入力バッファに挿入
    1:
        ldp     rv7, rv8,[sp], #16
        ldp     rv5, rv6,[sp], #16
        ldp     rv3, rv4,[sp], #16
        ldp     rv1, rv2,[sp], #16
        ldp     x1, x2,  [sp], #16
        ldp     x0, x30, [sp], #16
        ret

//==============================================================
                .align  2
NoCompletion:   .asciz  "<none>"
                .align  2
current_dir:    .asciz  "./"
                .align  2

//--------------------------------------------------------------
// 一致したファイル名が複数なら表示し、なるべく長く補完する。
//
// 一致するファイル名なしなら、<none>を入力バッファに挿入
// 完全に一致したらファイル名をコピー
// 入力バッファ末に0を追加、次に入力される入力バッファ中の位置
// を更新. 入力バッファ中の文字数(rv5)を返す。
//--------------------------------------------------------------
InsertFileName:
        stp     x0, x30, [sp, #-16]!
        stp     x1, x2,  [sp, #-16]!
        stp     x3, rv8, [sp, #-16]!
        tst     rv4, rv4               // FNCount ファイル数
        bne     0f
        adr     x3, NoCompletion       // <none>を入力バッファに挿入
        b       6f                     // 一致するファイル名なし

    0:  ldr     x0, [rv8]              // 部分ファイル名
        bl      StrLen                 // x1 = 部分ファイル名長
        cmp     rv4, #1                // ひとつだけ一致?
        bne     5f                     // 候補複数なら5fへ
        ldr     x0, [rv7]              // FNArray[0]
        add     x3, x0, x1             // x3 = FNArray[0] + x1
        b       6f                     // 入力バッファに最後までコピー

    5:  bl      ListFile               // ファイルが複数なら表示

        // 複数が一致している場合なるべく長く補完
        // 最初のエントリーと次々に比較、すべてのエントリーが一致していたら
        // 比較する文字を1つ進める。一致しない文字が見つかったら終わり
        mov     x2, #0                 // 追加して補完できる文字数
    1:
        sub     rv8, rv4, #1           // ファイル数-1
        ldr     x0, [rv7]              // 最初のファイル名と比較
        add     x3, x0, x1             // x3 = FNArray[0] + 部分ファイル名長
        ldrb    w0, [x3, x2]           // x0 = (FNArray[0] + 一致長 + x2)
    2:
        ldr     xip, [rv7, rv8,LSL #3] // xip = &FNArray[rv8]
        add     xip, xip, x1           // xip = FNArray[rv8] + 一致長
        ldrb    wip, [xip, x2]         // xip = FNArray[rv8] + 一致長 + x2
        cmp     x0, xip
        bne     3f                     // 異なる文字発見
        subs    rv8, rv8, #1           // 次のファイル名
        bne     2b                     // すべてのファイル名で繰り返し

        add     x2, x2, #1             // 追加して補完できる文字数を+1
        b       1b                     // 次の文字を比較
    3:
        cmp     x2, #0                 // 追加文字なし
        beq     9f                     // 複数あるが追加補完不可

    4:
        ldrb    w0, [x3]               // 補完分をコピー
        strb    w0, [rv1, rv5]         // 入力バッファに追加
        subs    x2, x2, #1
        bmi     8f                     // 補完部分コピー終了
        add     x3, x3, #1             // 次の文字
        add     rv5, rv5, #1
        b       4b                     //

    6:
        ldrb    w0, [x3]               // ファイル名をコピー
        strb    w0, [rv1, rv5]         // 入力バッファに追加
        add     x3, x3, #1             // 次の文字
        add     rv5, rv5, #1
        tst     x0, x0                 // 文字列末の0で終了
        bne     6b
        b       9f
    8:
        mov     w0, wzr                // 補完終了
        strb    w0, [rv1, rv5]         // 入力バッファ末を0
    9:
        ldp     x3, rv8, [sp], #16
        ldp     x1, x2,  [sp], #16
        ldp     x0, x30, [sp], #16
        ret

//--------------------------------------------------------------
// 入力中の文字列からディレクトリ名と部分ファイル名を抽出して
// バッファ DirName(rv6), PartialName(rv8,ポインタ)に格納
// TABキーが押されたら入力バッファの最後の文字から逆順に
// スキャンして、行頭またはスペースまたは " を探す。
// 行頭またはスペースの後ろから入力バッファの最後までの
// 文字列を解析してパス名(rv6)とファイル名(rv8)バッファに保存
//  entry  rv5 : 次に文字が入力される入力バッファ中の位置
//         rv1 : 入力バッファの先頭アドレス
//--------------------------------------------------------------
ExtractFilename:
        stp     x0, x30, [sp, #-16]!
        add     x3, rv5, rv1            // (入力済み位置+1)をコピー
        mov     x1, x3
        mov     x0, #0
        strb    w0, [x1]                // 入力済み文字列末をマーク
        mov     rv3, rv2                // FNBPointer=FileNameBuffer
        mov     rv4, #0                 // FNCount=0
    1:
                                        // 部分パス名の先頭を捜す
        ldrb    w0, [x1]                // カーソル位置から前へ
        cmp     x0, #0x20               // 空白はパス名の区切り
        beq     2f                      // 空白なら次の処理
        cmp     x0, #'"                 // " 二重引用符もパス名の区切り
        beq     2f                      // 二重引用符でも次の処理
        cmp     x1, rv1                 // 行頭をチェック
        beq     3f                      // 行頭なら次の処理
        sub     x1, x1, #1              // 後ろから前に検索
        b       1b                      // もう一つ前を調べる

    2:  add     x1, x1, #1              // 発見したので先頭に設定
    3:
        ldrb    w0, [x1]
        cmp     x0, #0                  // 文末？
        bne     4f
        ldp     x0, x30, [sp], #16
        ret               // 何もない(長さ0)なら終了

    4:  sub     x3, x3, #1              // 入力済み文字列最終アドレス
        ldrb    w0, [x3]
        cmp     x0, #'/                 // ディレクトリ部分を抽出
        bne     5f
        add     x3, x3, #1              // ファイル名から/を除く
        b       6f                      // 区切り発見

    5:  cmp     x1, x3                  // ディレクトリ部分がない?
        bne     4b
    6:                                  // ディレクトリ名をコピー
        mov     x0, #0
        strb    w0, [rv6]               // ディレクトリ名バッファを空に
        str     x3, [rv8]               // 部分ファイル名先頭
        subs    x2, x3, x1              // x2=ディレクトリ名文字数
        beq     8f                      // ディレクトリ部分がない

        mov     xip, rv6                // DirName
    7:
        ldrb    w0, [x1],#1             // コピー
        strb    w0, [xip],#1            // ディレクトリ名バッファ
        subs    x2, x2, #1
        bne     7b
        mov     x0, #0
        strb    w0, [xip]               // 文字列末をマーク
    8:  ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// ディレクトリ中のエントリをgetdentsで取得(1つとは限らないのか?)して、
// 1つづつファイル/ディレクトリ名をlstatで判断し、
// ディレクトリ中で一致したファイル名をファイル名バッファに書き込む。
//-------------------------------------------------------------------------
GetDirectoryEntry:
        stp     x0, x30, [sp, #-16]!
        stp     x1, x2,  [sp, #-16]!
        stp     x3, x4,  [sp, #-16]!
        ldrb    w0, [rv6]               // ディレクトリ部分の最初の文字
        tst     x0, x0                  // 長さ 0 か?
        bne     0f
        adr     x0, current_dir         // ディレクトリ部分がない時
        b       9f
    0:  mov     x0, rv6                 // ディレクトリ名バッファ
    9:  bl      fropen                  // ディレクトリオープン
        bmi     4f
        mov     x3, x0                  // fd 退避
    1:  // ディレクトリエントリを取得
  // uint fd, struct linux_dirent64 *dirp, uint count
        mov     x0, x3                  // fd 復帰
        adr     x1, dir_ent             // dir_ent格納先頭アドレス
        mov     x4, x1                  // x4 : dir_entへのポインタ
        mov     x2, #size_dir_ent       // dir_ent格納領域サイズ
        mov     x8, #sys_getdents64     // dir_entを複数返す
        svc     0
        tst     x0, x0                  // valid buffer length
        bmi     4f
        beq     5f                      // 終了
    2:  mov     x2, x0                  // x2 : buffer size
    3:  // dir_entからファイル情報を取得
        mov     x1, x4                  // x4 : dir_entへのポインタ
        bl      GetFileStat             // ファイル情報を取得
        adr     x1, file_stat
        ldr     w0, [x1, #+16]          // file_stat.st_mode
        and     x0, x0, #S_IFDIR        // ディレクトリ?
        add     x1, x4, #19             // ファイル名先頭アドレス
        bl      CopyFilename            // 一致するファイル名を収集

        // sys_getdentsが返したエントリが複数の場合には次のファイル
        // 1つなら次のディレクトリエントリを得る。
        ldrh    w0, [x4, #16]           // rec_len レコード長
        subs    x2, x2, x0              // buffer_size - rec_len
        beq     1b                      // 次のディレクトリエントリ取得
        add     x4, x4, x0              // 次のファイル名の格納領域に設定
        b       3b                      // 次のファイル情報を取得

    4:
.ifdef DETAILED_MSG
        bl      SysCallError            // システムコールエラー
.endif
    5:  mov     x0, x3                  // fd
        bl      fclose                  // ディレクトリクローズ
        ldp     x3, x4,  [sp], #16
        ldp     x1, x2,  [sp], #16
        ldp     x0, x30, [sp], #16
        ret

//--------------------------------------------------------------
// DirNameとdir_ent.dnameからPathNameを作成
// PathNameのファイルの状態をfile_stat構造体に取得
// entry
//   x1 : dir_entアドレス
//   rv6 : DirName
//   DirName にディレクトリ名
//--------------------------------------------------------------
GetFileStat:
        stp     x0, x30, [sp, #-16]!
        stp     x1, x2,  [sp, #-16]!
        stp     x3, x4,  [sp, #-16]!
        add     x2, x1, #19             // dir_ent.d_name + x
        adr     x3, PathName            // PathName保存エリア
        mov     xip, x3
        mov     x0, rv6                 // DirNameディレクトリ名保存アドレス
        bl      StrLen                  // ディレクトリ名の長さ取得>r1
        tst     x1, x1
        beq     2f
    1:
        ldrb    w4, [x0], #1            // ディレクトリ名のコピー
        strb    w4, [xip], #1           // PathNameに書き込み
        subs    x1, x1, #1              // -1になるため, bne不可
        bne     1b
    2:  mov     x0, x2                  // ファイル名の長さ取得
        bl      StrLen                  // <r0:アドレス, >r1:文字数
    3:
        ldrb    w4, [x2], #1            // ファイル名のコピー
        strb    w4, [xip], #1           // PathNameに書き込み
        subs    x1, x1, #1
        bne     3b
        strb    w1, [xip]               // 文字列末(0)をマーク
        mov     x0, AT_FDCWD            // 第1引数 dirfd
        mov     x1, x3                  // パス名先頭アドレス
        adr     x2, file_stat           // file_stat0のアドレス
        mov     x3, xzr                 // flags
        mov     x8, #sys_fstatat        // ファイル情報の取得
        svc     0
        tst     x0, x0                  // valid buffer length
        bpl     4f
.ifdef DETAILED_MSG
        bl      SysCallError            // システムコールエラー
.endif
    4:  ldp     x3, x4,  [sp], #16
        ldp     x1, x2,  [sp], #16
        ldp     x0, x30, [sp], #16
        ret

//--------------------------------------------------------------
// ディレクトリ中で一致したファイル名をファイル名バッファ
// (FileNameBuffer)に書き込む
// ファイル名がディレクトリ名なら"/"を付加する
// entry x0 : ディレクトリフラグ
//       x1 : ファイル名先頭アドレス
//       rv8 : 部分ファイル名先頭アドレス格納領域へのポインタ
//--------------------------------------------------------------
CopyFilename:
        stp     x0, x30, [sp, #-16]!
        stp     x1, x2,  [sp, #-16]!
        stp     x3, x4,  [sp, #-16]!
        cmp     rv4, #MAX_FILE          // rv4:FNCount 登録ファイル数
        bhs     5f
        mov     x3, x1                  // ファイル名先頭アドレス
        mov     x4, x0                  // ディレクトリフラグ
        ldr     x2, [rv8]               // rv8:PartialName
    1:
        ldrb    w0, [x2], #1            // 部分ファイル名
        tst     x0, x0                  // 文字列末?
        beq     2f                      // 部分ファイル名は一致
        ldrb    wip, [x1], #1           // ファイル名
        cmp     x0, xip                 // 1文字比較
        bne     5f                      // 異なれば終了
        b       1b                      // 次の文字を比較

    2:  // 一致したファイル名が格納できるかチェック
        mov     x0, x3                  // ファイル名先頭アドレス
        bl      StrLen                  // ファイル名の長さを求める
        mov     x2, x1                  // ファイル名の長さを退避
        add     xip, x1, #2             // 文字列末の '/#0'
        add     xip, xip, rv3           // 追加時の最終位置 rv3:FNBPointer
        cmp     xip, rv7                // FileNameBufferの直後(FNArray0)
        bhs     5f                      // バッファより大きくなる:終了
        // ファイル名バッファ中のファイル名先頭アドレスを記録
        str     rv3, [rv7, rv4,LSL #3]  // FNArray[FNCount]=ip
        add     rv4, rv4, #1            // ファイル名数の更新
    3:
        ldrb    wip, [x3], #1           // ファイル名のコピー
        strb    wip, [rv3], #1
        subs    x2, x2, #1              // ファイル名の長さを繰り返す
        bne     3b

        tst     x4, x4                  // ディレクトリフラグ
        beq     4f
        mov     w0, #'/'                // ディレクトリ名なら"/"付加
        strb    w0, [rv3], #1
    4:  mov     w0, wzr
        strb    w0, [rv3], #1           // セパレータ(0)を書く
    5:
        ldp     x3, x4,  [sp], #16
        ldp     x1, x2,  [sp], #16
        ldp     x0, x30, [sp], #16
        ret

//--------------------------------------------------------------
// ファイル名バッファの内容表示
//--------------------------------------------------------------
ListFile:
        stp     x0, x30, [sp, #-16]!
        stp     x1, x2,  [sp, #-16]!
        stp     x3, x4,  [sp, #-16]!
        bl      NewLine
        mov     x3, #0                  // 個数
    1:
        ldr     x2, [rv7, x3,LSL #3]    // FNArray + FNCount * 8
        mov     x0, x3
        mov     x1, #4                  // 4桁
        bl      PrintRight              // 番号表示
        mov     x0, #0x20
        bl      OutChar
        mov     x0, x2
        bl      OutAsciiZ               // ファイル名表示
        bl      NewLine
        add     x3, x3, #1
        cmp     x3, rv4
        blt     1b
    2:
        ldp     x3, x4,  [sp], #16
        ldp     x1, x2,  [sp], #16
        ldp     x0, x30, [sp], #16
        ret

//--------------------------------------------------------------
// 現在の termios を保存
//--------------------------------------------------------------
GET_TERMIOS:
        stp     x0, x30, [sp, #-16]!
        stp     x1, x2,  [sp, #-16]!
        stp     x3, x4,  [sp, #-16]!    // x4 : filler
        adr     x1, old_termios
        mov     x3, x1                  // old_termios
        bl      tcgetattr
        adr     x2, new_termios
        mov     x1, x3                  // old_termios
        sub     x3, x2, x1
        lsr     x3, x3, #3
    1:
        ldr     x0, [x1], #8
        str     x0, [x2], #8
        subs    x3, x3, #1
        bne     1b
        ldp     x3,  x4, [sp], #16
        ldp     x1,  x2, [sp], #16
        ldp     x0, x30, [sp], #16
        ret

//--------------------------------------------------------------
// 新しい termios を設定
// Rawモード, ECHO 無し, ECHONL 無し
// VTIME=0, VMIN=1 : 1バイト読み取られるまで待機
//--------------------------------------------------------------
SET_TERMIOS:
        stp     x0, x30, [sp, #-16]!
        stp     x1, x2,  [sp, #-16]!
        adr     x2, new_termios
        ldr     w0, [x2, #+12]          // c_lflag
        ldr     w1, termios_mode
        and     w0, w0, w1
        orr     w0, w0, #ISIG
        str     w0, [x2, #+12]
        mov     w0, wzr
        adr     x1, nt_c_cc
        mov     w0, #1
        strb    w0, [x1, #VMIN]
        mov     w0, wzr
        strb    w0, [x1, #VTIME]
        adr     x1, new_termios
        bl      tcsetattr
        ldp     x1,  x2, [sp], #16
        ldp     x0, x30, [sp], #16
        ret

termios_mode:   .long   ~ICANON & ~ECHO & ~ECHONL

//--------------------------------------------------------------
// 現在の termios を Cooked モードに設定
// Cookedモード, ECHO あり, ECHONL あり
// VTIME=1, VMIN=0
//--------------------------------------------------------------
SET_TERMIOS2:
        stp     x0, x30, [sp, #-16]!
        stp     x1, x2,  [sp, #-16]!
        adr     x2, new_termios
        ldr     w0, [x2, #+12]          // c_lflag
        ldr     w1, termios_mode2
        orr     w0, w0, w1
        orr     w0, w0, #ISIG
        str     w0, [x2, #+12]
        mov     w0, wzr
        adr     x1, nt_c_cc
        mov     w0, wzr
        strb    w0, [x1, #VMIN]
        mov     w0, #1
        strb    w0, [x1, #VTIME]
        adr     x1, new_termios
        bl      tcsetattr
        ldp     x1,  x2, [sp], #16
        ldp     x0, x30, [sp], #16
        ret
termios_mode2:   .long   ICANON | ECHO | ECHONL

//--------------------------------------------------------------
// 保存されていた termios を復帰
//--------------------------------------------------------------
RESTORE_TERMIOS:
        stp     x0, x30, [sp, #-16]!
        stp     x1, x2,  [sp, #-16]!
        adr     x1, old_termios
        bl      tcsetattr
        ldp     x1,  x2, [sp], #16
        ldp     x0, x30, [sp], #16
        ret

//--------------------------------------------------------------
// 標準入力の termios の取得と設定
// tcgetattr(&termios)
// tcsetattr(&termios)
// x0 : destroyed
// x1 : termios buffer adress
//--------------------------------------------------------------
tcgetattr:
        ldr     x0, TC_GETS
        b       IOCTL

tcsetattr:
        ldr     x0, TC_SETS

//--------------------------------------------------------------
// 標準入力の ioctl の実行
// sys_ioctl(unsigned int fd, unsigned int cmd,
//           unsigned long arg)
// x0 : cmd
// x1 : buffer adress
//--------------------------------------------------------------
IOCTL:
        stp     x8, x30, [sp, #-16]!
        stp     x1, x2,  [sp, #-16]!
        mov     x2, x1                  // set arg
        mov     x1, x0                  // set cmd
        mov     x0, xzr                 // 0 : to stdin
        mov     x8, #sys_ioctl
        svc     #0
        ldp     x1,  x2, [sp], #16
        ldp     x8, x30, [sp], #16
        ret

TC_GETS:    .long   TCGETS
TC_SETS:    .long   TCSETS

//--------------------------------------------------------------
// input 1 character from stdin
// eax : get char (0:not pressed)
//--------------------------------------------------------------
RealKey:
        stp     x8, x30, [sp, #-16]!
        stp     x1, x2,  [sp, #-16]!
        stp     x3, x4,  [sp, #-16]!
        stp     x5, x6,  [sp, #-16]!
        adr     x3, nt_c_cc
        mov     x0, xzr
        strb    w0, [x3, #VMIN]
        adr     x1, new_termios
        bl      tcsetattr
        mov     x0, xzr                 // x0  stdin
        mov     x1, sp                  // x1(stack) address
        mov     x2, #1                  // x2  length
        mov     x8, #sys_read
        svc     #0
        mov     x4, x0
        tst     x0, x0                  // if 0 then empty
        beq     1f
        ldrb    w4, [x1]                // char code
    1:  mov     x1, #1
        strb    w1, [x3, #VMIN]
        adr     x1, new_termios
        bl      tcsetattr
        mov     x0, x4
        ldp     x5,  x6, [sp], #16
        ldp     x3,  x4, [sp], #16
        ldp     x1,  x2, [sp], #16
        ldp     x8, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// get window size
// x0 : column(upper 16bit), raw(lower 16bit)
//-------------------------------------------------------------------------
WinSize:
        stp     x8, x30, [sp, #-16]!
        stp     x1, x2,  [sp, #-16]!
        mov     x0, xzr                  // to stdout
        mov     x1, #TIOCGWINSZ          // get wondow size
        adr     x2, winsize
        mov     x8, #sys_ioctl
        svc     #0
        ldr     x0, [x2]                 // winsize.ws_row
        ldp     x1,  x2, [sp], #16
        ldp     x8, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// ファイルをオープン
// enter   x0: 第１引数 filename
// return  x0: fd, if error then x0 will be negative.
// destroyed x1
//-------------------------------------------------------------------------
fropen:
        stp     x8, x30, [sp, #-16]!
        stp     x1, x2,  [sp, #-16]!
        mov     x2, #O_RDONLY           // 第3引数 flag
        b       1f
fwopen:
        stp     x8, x30, [sp, #-16]!
        stp     x1, x2,  [sp, #-16]!
        ldr     x2, fo_mode
    1:
        mov     x1, x0                  // 第2引数 filename
        mov     x0, AT_FDCWD            // 第1引数 dirfd
        mov     x3, #0644               // 第4引数 mode
        mov     x8, #sys_openat         // システムコール番号
        svc     #0
        tst     x0, x0                  // x0 <- fd
        ldp     x1,  x2, [sp], #16
        ldp     x8, x30, [sp], #16
        ret

AT_FDCWD =  -100
fo_mode:    .long   O_CREAT | O_WRONLY | O_TRUNC

//-------------------------------------------------------------------------
// ファイルをクローズ
// enter   x0 : 第１引数 ファイルディスクリプタ
//-------------------------------------------------------------------------
fclose:
        stp     x8, x30, [sp, #-16]!
        mov     x8, #sys_close
        svc     #0
        ldp     x8, x30, [sp], #16
        ret

//==============================================================
.data
                    .align      2
CURSOR_REPORT:      .byte       4, 0x1B
                    .ascii      "[6n"               // ^[[6n
                    .align      2
SAVE_CURSOR:        .byte       2, 0x1B, '7         // ^[7
                    .align      2
RESTORE_CURSOR:     .byte       2, 0x1B, '8         // ^[8
                    .align      2
DEL_AT_CURSOR:      .byte       4, 0x1B
                    .ascii      "[1P"               // ^[[1P
                    .align      2
CURSOR_RIGHT:       .byte       4, 0x1B
                    .ascii      "[1C"               // ^[[1C
                    .align      2
CURSOR_LEFT:        .byte       4, 0x1B
                    .ascii      "[1D"               // ^[[1D
                    .align      2
CURSOR_TOP:         .byte       1, 0x0D
                    .align      2
CLEAR_EOL:          .byte       4, 0x1B
                    .ascii      "[0K"               // ^[[0K
                    .align      2
CSI:                .byte       2, 0x1B, '[         // ^[[

                    .align  3
LINE_TOP:           .quad   7          // No. of prompt characters
FLOATING_TOP:       .quad   7          // Save cursor position

//==============================================================
.bss
                    .align  3
HistLine:           .quad   0
HistUpdate:         .quad   0
input:              .skip   MAXLINE

                    .align  3
history:            .skip   MAXLINE * MAXHISTORY

                    .align  3
DirName:            .skip   MAXLINE
PathName:           .skip   MAXLINE

                    .align  3
PartialName:        .quad   0           // 部分ファイル名先頭アドレス格納
FileNameBuffer:     .skip   2048, 0     // 2kbyte for filename completion
FNArray:            .skip   MAX_FILE*8  // long* Filename[0..255]
FNBPointer:         .quad   0           // FileNameBufferの格納済みアドレス+1
FNCount:            .quad   0           // No. of Filenames

                    .align 3
old_termios:
ot_c_iflag:         .long   0           // input mode flags
ot_c_oflag:         .long   0           // output mode flags
ot_c_cflag:         .long   0           // control mode flags
ot_c_lflag:         .long   0           // local mode flags
ot_c_line:          .byte   0           // line discipline
ot_c_cc:            .skip   NCCS        // control characters

                    .align 3
new_termios:
nt_c_iflag:         .long   0           // input mode flags
nt_c_oflag:         .long   0           // output mode flags
nt_c_cflag:         .long   0           // control mode flags
nt_c_lflag:         .long   0           // local mode flags
nt_c_line:          .byte   0           // line discipline
nt_c_cc:            .skip   NCCS        // control characters

                    .align 3
new_sig:
nsa_sighandler:     .quad   0           //  0
nsa_mask:           .quad   0           //  8
nsa_flags:          .quad   0           // 16
nsa_restorer:       .quad   0           // 24
old_sig:
osa_sighandler:     .quad   0           // 32
osa_mask:           .quad   0           // 40
osa_flags:          .quad   0           // 48
osa_restorer:       .quad   0           // 56

TV:
tv_sec:             .quad   0
tv_usec:            .quad   0
TZ:
tz_minuteswest:     .quad   0
tz_dsttime:         .quad   0

winsize:
ws_row:             .hword  0
ws_col:             .hword  0
ws_xpixel:          .hword  0
ws_ypixel:          .hword  0

ru:                               // 18 words
ru_utime_tv_sec:    .long   0       // user time used
ru_utime_tv_usec:   .long   0       //
ru_stime_tv_sec:    .long   0       // system time used
ru_stime_tv_usec:   .long   0       //
ru_maxrss:          .long   0       // maximum resident set size
ru_ixrss:           .long   0       // integral shared memory size
ru_idrss:           .long   0       // integral unshared data size
ru_isrss:           .long   0       // integral unshared stack size
ru_minflt:          .long   0       // page reclaims
ru_majflt:          .long   0       // page faults
ru_nswap:           .long   0       // swaps
ru_inblock:         .long   0       // block input operations
ru_oublock:         .long   0       // block output operations
ru_msgsnd:          .long   0       // messages sent
ru_msgrcv:          .long   0       // messages received
ru_nsignals:        .long   0       // signals received
ru_nvcsw:           .long   0       // voluntary context switches
ru_nivcsw:          .long   0       // involuntary

                    .align 3
dir_ent:                           // 256 bytesのdir_ent格納領域
//        u64             d_ino;      // 0
//        s64             d_off;      // 8
//        unsigned short  d_reclen;   // 16
//        unsigned char   d_type;     // 18
//        char            d_name[0];  // 19    ディレクトリエントリの名前
// -----------------------------------------------------------------------
// de_d_ino:         .long   0       // 0
// de_d_off:         .long   0       // 4
// de_d_reclen:      .hword  0       // 8
// de_d_name:                        // 10    ディレクトリエントリの名前
                    .skip   512

                    .align  2
size_dir_ent = . - dir_ent

                    .align 3
// from linux-4.1.2/include/uapi/asm-generic/stat.h
file_stat:                          // 128 bytes
fs_st_dev:          .quad   0       // 0  ファイルのデバイス番号
fs_st_ino:          .quad   0       // 8  ファイルのinode番号
fs_st_mode:         .long   0       // 16 ファイルのアクセス権とタイプ
fs_st_nlink:        .long   0       // 20
fs_st_uid:          .long   0       // 24
fs_st_gid:          .long   0       // 28
fs_st_rdev:         .quad   0       // 32
fs_st_pad1:         .quad   0       // 40
fs_st_size:         .quad   0       // 48 ファイルサイズ(byte)
fs_st_blksize:      .long   0       // 56 ブロックサイズ
fs_st_pad2:         .long   0       // 60
fs_st_blocks:       .quad   0       // 64
fs_st_atime:        .quad   0       // 72 ファイルの最終アクセス日時
fs_st_atime_nsec:   .quad   0       // 80 ファイルの最終アクセスnsec
fs_st_mtime:        .quad   0       // 88 ファイルの最終更新日時
fs_st_mtime_nsec:   .quad   0       // 96 ファイルの最終更新nsec
fs_st_ctime:        .quad   0       //104 ファイルの最終status変更日時
fs_st_ctime_nsec:   .quad   0       //112 ファイルの最終status変更nsec
fs___unused4:       .long   0       //120
fs___unused5:       .long   0       //124

.endif

