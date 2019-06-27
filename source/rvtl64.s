//-------------------------------------------------------------------------
// Return of the Very Tiny Language for ARM64
// file : rvtla64.s
// 2015/07/16 - 2019/06/27 ver. 4.01b
// Copyright (C) 2003-2019 Jun Mizutani <mizutani.jun@nifty.ne.jp>
// rvtl.s may be copied under the terms of the GNU General Public License.
//-------------------------------------------------------------------------

ARGMAX      =   15
VSTACKMAX   =   1024
MEMINIT     =   256*1024
LSTACKMAX   =   127
FNAMEMAX    =   256
LABELMAX    =   1024
VERSION     =   40100
VERSION64   =   1
CPU         =   5

.ifndef SMALL_VTL
  VTL_LABEL    = 1
  DETAILED_MSG = 1
  FRAME_BUFFER = 1
.endif

.ifdef  DETAILED_MSG
  .include      "syserror.s"
.endif

.ifdef  FRAME_BUFFER
  .include      "fblib.s"
.endif

.ifdef  DEBUG
  .include      "debug.s"
.endif

.include "vtllib.s"
.include "vtlsys.s"
.include "mt19937.s"

//==============================================================
        .text
        .global _start

_start:
        .align   3
//-------------------------------------------------------------------------
// システムの初期化
//-------------------------------------------------------------------------
        // コマンドライン引数の数をスタックから取得し、[argc] に保存
        ldr     x5, [sp]               // x5 = argc
        adr     x4, argc               // argc 引数の数を保存
        str     x5, [x4]
        add     x1, sp, #8
        str     x1, [x4, #8]           // argvp 引数配列先頭を保存

        // 環境変数格納アドレスをスタックから取得し、[envp] に保存
        add     x2, sp, x5, LSL #3     // x2 = sp + argc * 8 + 16
        add     x2, x2, #16            // 環境変数アドレス取得
        str     x2, [x4, #16]          // envp 環境変数領域の保存

        // コマンドラインの引数を走査
        mov     x3, #1
        cmp     x5, x3                 // argc
        beq     4f                     // 引数なしならスキップ
    1:  ldr     x6, [x1, x3, LSL #3]   // x6 = argvp[x3]
        ldrb    w6, [x6]
        add     x3, x3, #1
        cmp     w6, #'-                // 「-」か？
        beq     2f                     // 「-」発見
        cmp     x3, x5
        bne     1b
        b       3f                     // 「-」なし
    2:
        sub     x6, x3, 1
        str     x6, [x4]               // argc 引数の数を更新

    3:  add     x6, x1, x3, LSL #3
        str     x6, [x4, #+32]         // vtl用の引数文字列数への配列先頭
        sub     x3, x5, x3
        str     x3, [x4, #+24]         // vtl用の引数の個数 (argc_vtl)

    4:  // argv[0]="xxx/rvtlw" ならば cgiモード
        mov     x2, xzr
        adr     x3, cginame            // 文字列 'wltvr',0
        ldr     x1, [x4, #+8]          // argvp
        ldr     x0, [x1]               // argv[0]
    5:  ldrb    w6, [x0], #1
        cbnz    w6, 5b                 // wip!=0 then 5b
        sub     x0, x0, #2             // 文字列の最終文字位置(w)
    6:  ldrb    w1, [x0], #-1
        ldrb    w6, [x3], #+1
        cbz     w6, 7f                 // found
        cmp     w1, w6
        bne     8f                     // no
        b       6b
    7:  mov     x4, #1
    8:  adr     x3, cgiflag
        str     x4, [x3]               // when cgiflag=1, cgiモード

        // 現在の端末設定を保存し、端末をローカルエコーOFFに再設定

        bl      GET_TERMIOS            // termios の保存
        bl      SET_TERMIOS            // 端末のローカルエコーOFF

        // x29に変数領域の先頭アドレスを設定、変数のアクセスはx29を使う
        adr     x29, VarArea           //

        // システム変数の初期値を設定
        mov     x0, xzr                // 0 を渡して現在値を得る
        mov     x8, #sys_brk           // brk取得
        svc     #0
        mov     x2, x0                 // brk
        mov     x1, #',                // プログラム先頭 (,)
        str     x0, [x29, x1,LSL #3]
        mov     x1, #'='               // プログラム先頭 (=)
        str     x0, [x29, x1,LSL #3]
        add     x3, x0, #4             // ヒープ先頭 (&)
        mov     x1, #'&
        str     x3, [x29, x1,LSL #3]
        ldr     x1, mem_init           // MEMINIT=256*1024
        add     x0, x0, x1             // 初期ヒープ最終
        mov     x1, #'*                // RAM末設定 (*)
        str     x0, [x29, x1,LSL #3]
        svc     #0                     // brk設定
        mov     w3, #-1                // -1
        str     w3, [x2]               // コード末マーク

        ldr     x0, n672274774         // 初期シード値
        mov     x3, #'`                // 乱数シード設定
        str     x0, [x29, x3,LSL #3]
        bl      sgenrand

        // ctrl-C, ctrl-Z用のシグナルハンドラを登録する
        mov     x1, xzr                // シグナルハンドラ設定
        adr     x4, new_sig
        adr     x0, SigIntHandler
        str     x0, [x4]               // nsa_sighandler
        str     x1, [x4, #+8]          // nsa_mask
        mov     x0, #SA_NOCLDSTOP      // 子プロセス停止を無視
        orr     x0, x0, #SA_RESTORER
        str     x0, [x4, #+16]         // nsa_flags
        adr     x0, SigReturn
        str     x0, [x4, #+24]         // nsa_restorer

        mov     x0, #SIGINT            // ^C
        mov     x1, x4                 // new_sig
        mov     x2, xzr                // old_sig
        mov     x3, #8                 // size
        mov     x8, #sys_rt_sigaction
        svc     #0

        mov     x0, #SIG_IGN           // シグナルの無視
        str     x0, [x4]               // nsa_sighandler
        mov     x0, #SIGTSTP           // ^Z
        mov     x8, #sys_rt_sigaction
        svc     #0

        // PIDを取得して保存(initの識別)、pid=1 なら環境変数設定
        mov     x8, #sys_getpid
        svc     #0
        str     x0, [x29, #-40]        // pid の保存
        cmp     x0, #1
        bne     go

        adr     x1, envp               // pid=1 なら環境変数設定
        adr     x0, env                // 環境変数配列先頭アドレス
        str     x0, [x1]
        adr     x1, envstr             // pid=1 なら環境変数設定
        str     x1, [x0]               // env[0] に @envstr を格納

        // /etc/init.vtlが存在すれば読み込む
        adr     x0, initvtl            // /etc/init.vtl
        bl      fropen                 // open
        ble     go                     // 無ければ継続
        str     x0, [x29, #-16]        // FileDesc
        bl      WarmInit2
        mov     x0, #1
        strb    w0, [x29, #-4]         // Read from file
        strb    w0, [x29, #-2]         // EOL=yes [x29, #-2]は未使用
        mov     xv5, x0                // EOLフラグ
        b       Launch
    go:
        bl      WarmInit2
        mov     x0, xzr
        adr     x1, counter
        str     x0, [x1]               // コマンド実行カウント初期化
        add     x1, x1, #16            // current_arg
        str     x0, [x1]               // 処理済引数カウント初期化
        bl      LoadCode               // あればプログラムロード
        bgt     Launch

.ifndef SMALL_VTL
        adr     x0, start_msg          // 起動メッセージ
        bl      OutAsciiZ
.endif

Launch:         // 初期化終了
        adr     x1, save_stack
        mov     x0, sp
        str     x0, [x1]               // スタックを保存

//-------------------------------------------------------------------------
// メインループ
//-------------------------------------------------------------------------
MainLoop:
        // SIGINTを受信(ctrl-Cの押下)を検出したら初期状態に戻す
        ldrb    wip, [x29, #-5]
        cbz     wip, 1f                // SIGINT 受信?
        bl      WarmInit               // 実行停止
        b       3f

        // 0除算エラーが発生したらメッセージを表示して停止
    1:  ldrb    wip, [x29, #-6]        // エラー
        cbz     wip, 2f
        adr     x0, err_div0           // 0除算メッセージ
        bl      OutAsciiZ
        bl      WarmInit               // 実行停止

        // 式中でエラーを検出したらメッセージを表示して停止
    2:  ldrb    wip, [x29, #-7]        // 式中にエラー?
        cbnz    wip, Exp_Error         // 式中でエラー発生

        // 行末をチェック (初期化直後は EOL=1)
    3:  cbz     xv5, 4f                // EOL

        // 次行取得 (コンソール入力またはメモリ上のプログラム)
        ldrb    wip, [x29, #-3]
        cbz     wip, ReadLine          // ExecMode=Memory ?
        b       ReadMem                // メモリから行取得

        // 空白なら読み飛ばし
    4:  bl      GetChar
    5:  cmp     xv1, #' '              // 空白読み飛ばし
        bne     6f
        bl      GetChar
        b       5b

        // 行番号付なら編集モード
    6:
        bl      IsNum                  // 行番号付なら編集モード
        bcs     7f
        bl      EditMode               // 編集モード
        b       MainLoop

        // 英文字なら変数代入、異なればコマンド
    7:
        adr     xip, counter
        ldr     x0, [xip]
        add     x0, x0, #1
        str     x0, [xip]
        bl      IsAlpha
        bcs     Command                // コマンド実行
    8:  bl      SetVar                 // 変数代入
        b       MainLoop

LongJump:
        adr     xip, save_stack
        ldr     x0, [xip]              // スタックを復帰
        mov     sp, x0
        adr     x0, err_exp            // 式中に空白
        b       Error
Exp_Error:
        adr     x0, err_vstack         // 変数スタックアンダーフロー
        cmp     xip, #2
        beq     9f
        adr     x0, err_label          // ラベル未定義メッセージ
    9:
        b       Error

//-------------------------------------------------------------------------
// キー入力またはファイル入力されたコードを実行
//-------------------------------------------------------------------------
ReadLine:
        // 1行入力 : キー入力とファイル入力に対応
        ldrb    w0, [x29, #-4]         // Read from console
        cbz     w0, 1f                 // コンソールから入力
        bl      READ_FILE              // ファイルから入力
        b       MainLoop

    1:  // プロンプトを表示してコンソールからキー入力
        bl      DispPrompt
        adr     x1, input2
        mov     x0, #MAXLINE           // 1 行入力
        bl      READ_LINE              // 編集機能付キー入力
        mov     xv3, x1                // 入力バッファ先頭
        mov     xv2, xv3
        mov     xv5, xzr               // not EOL
        b       MainLoop

//-------------------------------------------------------------------------
// メモリに格納されたコードの次行をxv3に設定
// xv2 : 行先頭アドレス
//-------------------------------------------------------------------------
ReadMem:
        ldr     w0, [xv2]              // JUMP先かもしれない
        adds    w0, w0, #1             // 次行オフセットが -1 か?
        beq     1f                     // コード末なら実行終了
        ldr     w0, [xv2]
        add     xv2, xv2, x0           // Next Line

        //次行へのオフセットが0ならばコード末
        ldr     w0, [xv2]              // 次行オフセット
        tst     w0, w0                 // コード末？
        bpl     2f

        //コード末ならばコンソール入力(ダイレクトモード)に設定し、
        //EOLを1とすることで、次行取得を促す
    1:
        bl      CheckCGI               // CGIモードなら終了
        mov     x0, xzr
        mov     xv5, #1                // EOL=yes
        strb    w0, [x29, #-3]         // ExecMode=Direct
        b       MainLoop

        //現在の行番号を # に設定し、コード部分先頭アドレスを xv3 に設定
    2:
        bl      SetLineNo              // 行番号を # に設定
        add     xv3, xv2, #+8          // 行のコード先頭
        mov     xv5, xzr               // EOL=no
        b       MainLoop

//-------------------------------------------------------------------------
// シグナルハンドラ
//-------------------------------------------------------------------------
SigIntHandler:
        stp     x0, x29, [sp, #-16]!
        mov     w0, #1                 // SIGINT シグナル受信
        adr     x29, VarArea           //
        strb    w0, [x29, #-5]         // x29は常に同じ値
        ldp     x0, x29, [sp], #16
        ret

SigReturn:
        mov     x8, #sys_rt_sigreturn
        svc     #0                     // 戻らない？

//-------------------------------------------------------------------------
// コマンドラインで指定されたVTLコードファイルをロード
// 実行後、bgt 真 ならロード
//-------------------------------------------------------------------------
LoadCode:
        stp     x0, x30, [sp, #-16]!
        stp     x1, xip, [sp, #-16]!
        adr     x3, current_arg        // 処理済みの引数
        ldr     x2, [x3]
        add     x2, x2, #1             // カウントアップ
        ldr     xip, [x3, #8]          // argc 引数の個数
        cmp     x2, xip
        beq     3f                     // すべて処理済み
        str     x2, [x3]               // 処理済みの引数更新
        ldr     xip, [x3, #+16]        // argvp 引数配列先頭
        ldr     xip, [xip, x2,LSL #3]  // 引数取得
        adr     x1, FileName
        mov     x2, #FNAMEMAX

    1:  ldrb    w0, [xip], #1
        strb    w0, [x1], #1
        cbz     w0, 2f                 // w0=0 then file open
        subs    x2, x2, #1
        bne     1b

    2:  adr     x0, FileName           // ファイルオープン
        bl      fropen                 // open
        bl      CheckError
        ble     3f
        str     x0, [x29, #-16]        // FileDesc
        mov     x0, #1
        strb    w0, [x29, #-4]         // Read from file(1)
        mov     xv5, #1                // EOL=yes
    3:
        ldp     x1, xip, [sp], #16
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// 文字列取得 " または EOL まで
//-------------------------------------------------------------------------
GetString:
        stp     x0, x30, [sp, #-16]!
        mov     x2, xzr
        adr     x3, FileName
    1: // next:
        bl      GetChar
        cmp     wv1, #'"               // "' closing quote for emacs
        beq     2f
        tst     wv1, wv1
        beq     2f
        strb    wv1, [x3, x2]
        add     x2, x2, #1
        cmp     x2, #FNAMEMAX
        blo     1b
    2: // exit:
        mov     wv1, wzr
        strb    wv1, [x3, x2]
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// x0 のアドレスからFileNameにコピー
//-------------------------------------------------------------------------
  GetString2:
        stp     x3, x30, [sp, #-16]!
        mov     x2, xzr
        adr     x3, FileName
    1:  ldrb    w1, [x0, x2]
        strb    w1, [x3, x2]
        tst     w1, w1
        beq     2f
        add     x2, x2, #1
        cmp     x2, #FNAMEMAX
        blo     1b
    2:  ldp     x3, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// ファイル名をバッファに取得
// バッファ先頭アドレスを r0 に返す
//-------------------------------------------------------------------------
GetFileName:
        stp     x1, x30, [sp, #-16]!   // x1:filler
        bl      GetChar                // skip =
        cmp     xv1, #'='
        bne     2f                     // エラー
        bl      GetChar                // skip double quote
        cmp     xv1, #'"               // "
        beq     1f
        b       2f                     // エラー
    1: // file
        bl      GetString
        adr     x0, FileName           // ファイル名表示
        ldp     x1, x30, [sp], #16
        ret
    2: // error
        add     sp, sp, #16            // スタック修正
        b       pop_and_Error

//-------------------------------------------------------------------------
// 文の実行
//   文を実行するサブルーチンをコール
//-------------------------------------------------------------------------
Command:
        //xv1レジスタの値によって各処理ルーチンを呼び出す
        subs    x1, xv1, #'!
        blo     1f
        cmp     x1, #('/ - '!)
        bhi     1f
        adr     x2, TblComm1            // ジャンプテーブル1 !-/
        b       jumpToCommand
    1:  subs    x1, xv1, #':'
        blo     2f
        cmp     x1, #('@ - ':)
        bhi     2f
        adr     x2, TblComm2            // ジャンプテーブル2 :-@
        b       jumpToCommand
    2:  subs    x1, xv1, #'['
        blo     3f
        cmp     x1, #('` - '[)
        bhi     3f
        adr     x2, TblComm3            // ジャンプテーブル3 [-`
        b       jumpToCommand
    3:  subs    x1, xv1, #'{'
        blo     4f
        cmp     x1, #('~ - '{)
        bhi     4f
        adr     x2, TblComm4            // ジャンプテーブル4 {-~

jumpToCommand:
        ldr     x1, [x2, x1,LSL #3]     // ジャンプ先アドレス設定
        blr      x1                     // 対応ルーチンをコール
        b       MainLoop

    4:  cmp     xv1, #' '
        beq     MainLoop
        cbz     xv1, MainLoop
        cmp     xv1, #8
        beq     MainLoop
        b       SyntaxError

//-------------------------------------------------------------------------
// コマンド用ジャンプテーブル
//-------------------------------------------------------------------------
        .align   4
TblComm1:
        .quad Com_GOSUB    //   21  !  GOSUB
        .quad Com_String   //   22  "  文字列出力
        .quad Com_GO       //   23  #  GOTO 実行中の行番号を保持
        .quad Com_OutChar  //   24  $  文字コード出力
        .quad Com_Error    //   25  %  直前の除算の剰余または usec を保持
        .quad Com_NEW      //   26  &  NEW, VTLコードの最終使用アドレスを保持
        .quad Com_Error    //   27  '  文字定数
        .quad Com_FileWrite//   28  (  File 書き出し
        .quad Com_FileRead //   29  )  File 読み込み, 読み込みサイズ保持
        .quad Com_BRK      //   2A  *  メモリ最終(brk)を設定, 保持
        .quad Com_VarPush  //   2B  +  ローカル変数PUSH, 加算演算子, 絶対値
        .quad Com_Exec     //   2C  ,  fork & exec
        .quad Com_VarPop   //   2D  -  ローカル変数POP, 減算演算子, 負の十進数
        .quad Com_Space    //   2E  .  空白出力
        .quad Com_NewLine  //   2F  /  改行出力, 除算演算子
TblComm2:
        .quad Com_Comment  //   3A  :  行末まで注釈
        .quad Com_IF       //   3B  ;  IF
        .quad Com_CdWrite  //   3C  <  rvtlコードのファイル出力
        .quad Com_Top      //   3D  =  コード先頭アドレス
        .quad Com_CdRead   //   3E  >  rvtlコードのファイル入力
        .quad Com_OutNum   //   3F  ?  数値出力  数値入力
        .quad Com_DO       //   40  //  DO UNTIL NEXT
TblComm3:
        .quad Com_RCheck   //   5B  [  Array index 範囲チェック
        .quad Com_Ext      //   5C  \  拡張用  除算演算子(unsigned)
        .quad Com_Return   //   5D  ]  RETURN
        .quad Com_Comment  //   5E  ^  ラベル宣言, 排他OR演算子, ラベル参照
        .quad Com_USleep   //   5F  _  usleep, gettimeofday
        .quad Com_RANDOM   //   60  `  擬似乱数を保持 (乱数シード設定)
TblComm4:
        .quad Com_FileTop  //   7B  {  ファイル先頭(ヒープ領域)
        .quad Com_Function //   7C  |  組み込みコマンド, エラーコード保持
        .quad Com_FileEnd  //   7D  }  ファイル末(ヒープ領域)
        .quad Com_Exit     //   7E  ~  VTL終了

//-------------------------------------------------------------------------
// ソースコードを1文字読み込む
// xv3 の示す文字を xv1(x9) に読み込み, xv3 を次の位置に更新
// レジスタ保存
//-------------------------------------------------------------------------
GetChar:
        cmp     xv5, #1                // EOL=yes
        beq     2f
        ldrb    wv1, [xv3]
        tst     wv1, wv1               // w9 = wv1
        bne     1f
        mov     xv5, #1                // EOL=yes
    1:  add     xv3, xv3, #1
    2:
        ret

//-------------------------------------------------------------------------
// 行番号をシステム変数 # に設定
//-------------------------------------------------------------------------
SetLineNo:
        mov     x3, #'#
        ldr     w0, [xv2, #+4]         // Line No.
        str     x0, [x29, x3,LSL #3]   // 行番号を # に設定
        ret

SetLineNo2:
        mov     x3, #'#
        ldr     x0, [x29, x3,LSL #3]   // 行番号を取得
        mov     x3, #'!
        str     x0, [x29, x3,LSL #3]   // 行番号を ! に設定
        ldr     w0, [xv2, #+4]         // Line No.
        mov     x3, #'#
        str     x0, [x29, x3,LSL #3]   // 行番号を # に設定
        ret

//-------------------------------------------------------------------------
// CGI モードなら rvtl 終了
//-------------------------------------------------------------------------
CheckCGI:
        adr     x3, cgiflag
        ldr     x3, [x3]
        cmp     x3, #1                 // CGI mode ?
        beq     Com_Exit
        ret

//-------------------------------------------------------------------------
// 文法エラー
//-------------------------------------------------------------------------
SyntaxError:
        adr     x0, syntaxerr
Error:  bl      OutAsciiZ
        ldrb    w0, [x29, #-3]
        cbz     w0, 3f                 // ExecMode=Direct ?
        ldr     w0, [xv2, #+4]         // エラー行行番号
        bl      PrintLeft
        bl      NewLine
        add     x0, xv2, #8            // 行先頭アドレス
    5:  bl      OutAsciiZ              // エラー行表示
        bl      NewLine
        sub     x3, xv3, xv2
        subs    x3, x3, #9
        beq     2f
        cmp     x3, #MAXLINE
        bhs     3f
        mov     x0, #' '               // エラー位置設定
    1:  bl      OutChar
        subs    x3, x3, #1
        bne     1b
    2:  adr     x0, err_str
        bl      OutAsciiZ
        mov     x0, xv1
        bl      PrintHex2              // エラー文字コード表示
        mov     x0, #']'
        bl      OutChar
        bl      NewLine

    3:  bl      WarmInit               // システムを初期状態に
        b       MainLoop

err_str:
        .asciz  "^  ["
        .align  2

//==============================================================

//-------------------------------------------------------------------------
// 変数スタック範囲エラー
//-------------------------------------------------------------------------
VarStackError_over:
        adr     x0, vstkover
        b       1f
VarStackError_under:
        adr     x0, vstkunder
    1:  bl      OutAsciiZ
        bl      WarmInit
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// スタックへアドレスをプッシュ (行と文末位置を退避)
//-------------------------------------------------------------------------
PushLine:
        stp     x0, x30, [sp, #-16]!
        stp     x1, x2,  [sp, #-16]!
        ldrb    w1, [x29, #-1]         // LSTACK
        cmp     w1, #LSTACKMAX
        bge     StackError_over        // overflow
        add     x2, x29, #1024         // (x29 + 1024) + LSTACK*8
        str     xv2, [x2, x1,LSL #3]   // push xv2

        add     x1, x1, #1             // LSTACK--
        ldrb    wip, [xv3, #-1]
        cmp     xip, xzr
        beq     1f                     // 行末処理
        str     xv3, [x2, x1,LSL #3]   // push xv3,(x29+1024)+LSTACK*8
        b       2f
    1:
        sub     xv3, xv3, #1           // 1文字戻す
        str     xv3, [x2, x1,LSL #3]   // push xv3,(x29+1024)+LSTACK*8
        add     xv3, xv3, #1           // 1文字進める
    2:
        add     x1, x1, #1             // LSTACK--
        strb    w1, [x29, #-1]         // LSTACK
        ldp     x1, x2,  [sp], #16
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// スタックからアドレスをポップ (行と文末位置を復帰)
// xv2, xv3 更新
//-------------------------------------------------------------------------
PopLine:
        stp     x0, x30, [sp, #-16]!
        stp     x1, x2,  [sp, #-16]!
        ldrb    w1, [x29, #-1]         // LSTACK
        cmp     w1, #2
        blo     StackError_under       // underflow
        sub     x1, x1, #1             // LSTACK--
        add     x2, x29, #1024         // (x29 + 1024) + LSTACK*8
        add     x2, x2, x1,LSL #3
        ldr     xv3, [x2]              // pop xv3
        ldr     xv2, [x2, #-8]         // pop xv2
        sub     x1, x1, #1
        strb    w1, [x29, #-1]         // LSTACK
        ldp     x1, x2,  [sp], #16
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// スタックエラー
// r0 変更
//-------------------------------------------------------------------------
StackError_over:
        adr     x0, stkover
        b       1f
StackError_under:
        adr     x0, stkunder
        stp     x0, x30, [sp, #-16]!  // ????
    1:  bl      OutAsciiZ
        bl      WarmInit
        ldp     x1, x2,  [sp], #16
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// スタックへ終了条件(x0)をプッシュ
//-------------------------------------------------------------------------
PushValue:
        stp     x0, x30, [sp, #-16]!
        stp     x1, x2,  [sp, #-16]!
        ldrb    w1, [x29, #-1]           // LSTACK
        cmp     w1, #LSTACKMAX
        bge     StackError_over
        add     x2, x29, #1024           // (x29 + 1024) + LSTACK*8
        str     x0, [x2, x1,LSL #3]      // push x0
        add     x1, x1, #1               // LSTACK++
        strb    w1, [x29, #-1]           // LSTACK
        ldp     x1, x2,  [sp], #16
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// スタック上の終了条件を x0 に設定
//-------------------------------------------------------------------------
PeekValue:
        stp     x2, x30, [sp, #-16]!   // x2:filler
        stp     x1, x2,  [sp, #-16]!
        ldrb    w1, [x29, #-1]         // LSTACK
        sub     w1, w1, #3             // 行,文末位置の前
        add     x2, x29, #1024         // (x29 + 1024) + LSTACK*8
        ldr     x0, [x2, x1,LSL #3]    // read Value
        ldp     x1, x2,  [sp], #16
        ldp     x2, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// スタックから終了条件(x0)をポップ
//-------------------------------------------------------------------------
PopValue:
        stp     x2, x30, [sp, #-16]!   // x2:filler
        stp     x1, x2,  [sp, #-16]!
        ldrb    w1, [x29, #-1]         // LSTACK
        cmp     w1, #1
        blo     StackError_under
        sub     x1, x1, #1             // LSTACK--
        add     x2, x29, #1024         // (x29 + 1024) + LSTACK*8
        ldr     x0, [x2, x1,LSL #3]    // pop r0
        strb    w1, [x29, #-1]         // LSTACK
        ldp     x1, x2,  [sp], #16
        ldp     x2, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// プロンプト表示
//-------------------------------------------------------------------------
DispPrompt:
        stp     x0, x30, [sp, #-16]!
        bl      WinSize
        lsr     x0, x0, #16           // 桁数
        cmp     x0, #48
        blo     1f
        mov     x0, #7                 // long prompt
        bl      set_linetop            // 行頭マージン設定
        adr     x0, prompt1            // プロンプト表示
        bl      OutAsciiZ
        ldr     x0, [x29, #-40]        // pid の取得
.ifdef DEBUG
        mov     x0, sp                 // sp の下位4桁
.endif
        bl      PrintHex4
        adr     x0, prompt2            // プロンプト表示
        bl      OutAsciiZ
        ldp     x0, x30, [sp], #16
        ret

    1:  mov     x0, #4                 // short prompt
        bl      set_linetop            // 行頭マージン設定
        bl      NewLine
        ldr     x0, [x29, #-40]        // pid の取得
        bl      PrintHex2              // pidの下1桁表示
        adr     x0, prompt2            // プロンプト表示
        bl      OutAsciiZ
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// アクセス範囲エラー
//-------------------------------------------------------------------------
RangeError:
        stp     x0, x30, [sp, #-16]!
        adr     x0, Range_msg       // 範囲エラーメッセージ
        bl      OutAsciiZ
        mov     x1, #'#             // 行番号
        ldr     x0, [x29, x1,LSL #3]
        bl      PrintLeft
        mov     x0, #',
        bl      OutChar
        mov     x1, #'!             // 呼び出し元の行番号
        ldr     x0, [x29, x1,LSL #3]
        bl      PrintLeft
        bl      NewLine
        bl      WarmInit
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// システム初期化２
//-------------------------------------------------------------------------
    //コマンド入力元をコンソールに設定

WarmInit:
        stp     x3, x30, [sp, #-16]!
        bl      CheckCGI
        ldp     x3, x30, [sp], #16
WarmInit2:
        mov     x0, xzr            // 0
        strb    w0, [x29, #-4]     // Read from console

    //システム変数及び作業用フラグの初期化
WarmInit1:
        mov     x0, #1             // 1
        mov     x3, #'[            // 範囲チェックON
        str     x0, [x29, x3,LSL #3]
        mov     xv5, #1            // EOL=yes
        mov     x0, xzr            // 0
        adr     x1, exarg          // execve 引数配列初期化
        str     x0, [x1]
        strb    w0, [x29, #-7]     // 式のエラー無し
        strb    w0, [x29, #-6]     // ０除算無し
        strb    w0, [x29, #-5]     // SIGINTシグナル無し
        strb    w0, [x29, #-3]     // ExecMode=Direct
        strb    w0, [x29, #-1]     // LSTACK
        str     x0, [x29, #-32]    // VSTACK
        ret

//-------------------------------------------------------------------------
// GOSUB !
//-------------------------------------------------------------------------
Com_GOSUB:
        stp     x0, x30, [sp, #-16]!
        ldrb    w0, [x29, #-3]
        tst     w0, w0              // ExecMode=Direct ?
        bne     1f
        adr     x0, no_direct_mode
        bl      OutAsciiZ
        add     sp, sp, #16         // スタック修正 ★要チェック
        bl      WarmInit
        b       MainLoop

    1:
.ifdef VTL_LABEL
        bl      ClearLabel
.endif
        bl      SkipEqualExp        // = を読み飛ばした後 式の評価
        bl      PushLine
        bl      Com_GO_go
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// Return ]
//-------------------------------------------------------------------------
Com_Return:
        stp     x0, x30, [sp, #-16]!
        bl      PopLine             // 現在行の後ろは無視
        mov     xv5, xzr            // not EOL
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// IF ; コメント :
//-------------------------------------------------------------------------
Com_IF:
        stp     x1, x30, [sp, #-16]!   // lr 保存
        bl      SkipEqualExp           // = を読み飛ばした後 式の評価
        ldp     x1, x30, [sp], #16
        tst     x0, x0
        beq     Com_Comment
        ret                            // 真なら戻る、偽なら次行
Com_Comment:
        mov     xv5, #1                // EOL=yes 次の行へ
        ret

//-------------------------------------------------------------------------
// 未定義コマンド処理(エラーストップ)
//-------------------------------------------------------------------------
pop2_and_Error:
        add     sp, sp, #16
pop_and_Error:
        add     sp, sp, #16
Com_Error:
        b       SyntaxError

//-------------------------------------------------------------------------
// DO UNTIL NEXT //
//-------------------------------------------------------------------------
Com_DO:
        stp     x0, x30, [sp, #-16]!
        ldr     x0, [x29, #-3]
        cbnz    x0, 1f                 // ExecMode=Direct ?
        adr     x0, no_direct_mode
        bl      OutAsciiZ
        add     sp, sp, #16            // スタック修正
        bl      WarmInit
        b       MainLoop
    1:
        bl      GetChar
        cmp     xv1, #'='
        bne     7f                     // DO コマンド
        ldrb    wv1, [xv3]             // PeekChar
        cmp     xv1, #'('              // UNTIL?
        bne     2f                     // ( でなければ NEXT
        bl      SkipCharExp            // (を読み飛ばして式の評価
        mov     x2, x0                 // 式の値
        bl      GetChar                // ) を読む(使わない)
        bl      PeekValue              // 終了条件
        cmp     x2, x0                 // x0:終了条件
        bne     6f                     // 等しくcontinue
        b       5f                     // ループ終了

    2: // next (FOR)
        bl      IsAlpha                // al=[A-Za-z] ?
        bcs     pop_and_Error          // スタック補正後 SyntaxError
        add     x2, x29, xv1,LSL #3    // 制御変数のアドレス
        bl      Exp                    // 任意の式
        ldr     x3, [x2]               // 更新前の値を x3 に
        str     x0, [x2]               // 制御変数の更新
        mov     x2, x0                 // 更新後の式の値をx2
        bl      PeekValue              // 終了条件を x0 に
        ldrb    w1, [x29, #-8]
        cmp     w1, #1                 // 降順 (開始値 > 終了値)
        bne     4f                     // 昇順

    3: // 降順
        cmp     x3, x2                 // 更新前 - 更新後
        ble     pop_and_Error          // 更新前が小さければエラー
        cmp     x3, x0                 // x0:終了条件
        bgt     6f                     // continue
        b       5f                     // 終了

    4: // 昇順
        cmp     x3, x2                 // 更新前 - 更新後
        bge     pop_and_Error          // 更新前が大きければエラー
        cmp     x3, x0                 // x0:終了条件
        blt     6f                     // continue

    5: // exit ループ終了
        ldrb    w1, [x29, #-1]          // LSTACK=LSTACK-3
        sub     x1, x1, #3
        strb    w1, [x29, #-1]          // LSTACK
        ldp     x0, x30, [sp], #16
        ret

    6: // continue UNTIL
        ldrb    w1, [x29, #-1]          // LSTACK 戻りアドレス
        sub     x3, x1, #1
        add     x2, x29, x3,LSL #3
        add     x2, x2, #1024
        ldr     xv3, [x2]               // x29+(x1-1)*8+1024
        sub     x3, x3, #1
        add     x2, x29, x3,LSL #3
        add     x2, x2, #1024
        ldr     xv2, [x2]               // x29+(x1-2)*8+1024
        mov     xv5, xzr                // not EOL
        ldp     x0, x30, [sp], #16
        ret

    7: // do
        mov     x0, #1                  // DO
        bl      PushValue
        bl      PushLine
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// 変数への代入, FOR文処理
// xv1 に変数名を設定して呼び出される
//-------------------------------------------------------------------------
SetVar:         // 変数代入
        stp     x0, x30, [sp, #-16]!
        bl      SkipAlpha              // 変数の冗長部分の読み飛ばし
        add     xv4, x29, x1,LSL #3    // 変数のアドレス
        cmp     xv1, #'('
        beq     s_array1               // 1バイト配列
        cmp     xv1, #'{'
        beq     s_array2               // 2バイト配列
        cmp     xv1, #'['
        beq     s_array4               // 4バイト配列
        cmp     xv1, #';'
        beq     s_array8               // 8バイト配列
        cmp     xv1, #'*
        beq     s_strptr               // ポインタ指定
        cmp     xv1, #'='
        bne     pop_and_Error

        // 単純変数
    0:  bl      Exp                    // 式の処理(先読み無しで呼ぶ)
        str     x0, [xv4]              // 代入
        mov     x1, x0
        cmp     xv1, #','              // FOR文か?
        bne     3f                     // 終了

        ldrb    wip, [x29, #-3]        // ExecMode=Direct ?
        cmp     wip, wzr
        bne     1f                     // 実行時ならOKなのでFOR処理
        adr     x0, no_direct_mode     // エラー表示
        bl      OutAsciiZ
        add     sp, sp, #16            // スタック修正(pop)
        bl      WarmInit
        b       MainLoop               // 戻る

    1:  // for
        mov     wip, wzr
        strb    wip, [x29, #-8]        // 昇順(0)
        bl      Exp                    // 終了値をx0に設定
        cmp     x0, x1                 // 開始値(x1)と終了値(x0)を比較
        bge     2f
        mov     wip, #1
        strb    wip, [x29, #-8]        // 降順 (開始値 >= 終了値)
    2:
        bl      PushValue              // 終了値を退避(NEXT部で判定)
        bl      PushLine               // For文の直後を退避
    3:
        ldp     x0, x30, [sp], #16
        ret

    s_array1:
        bl      s_array
        bcs     s_range_err            // 範囲外をアクセス
        strb    w0, [xv4, x1]          // 代入
        ldp     x0, x30, [sp], #16
        ret

    s_array2:
        bl      s_array
        bcs     s_range_err            // 範囲外をアクセス
        lsl     x1, x1, #1
        strh    w0, [xv4, x1]          // 代入
        ldp     x0, x30, [sp], #16
        ret

    s_array4:
        bl      s_array
        bcs     s_range_err            // 範囲外をアクセス
        str     w0, [xv4, x1,LSL #2]   // 代入
        ldp     x0, x30, [sp], #16
        ret

    s_array8:
        bl      s_array
        bcs     s_range_err            // 範囲外をアクセス
        str     x0, [xv4, x1,LSL #3]   // 代入
        ldp     x0, x30, [sp], #16
        ret

    s_strptr:                          // 文字列をコピー
        bl      GetChar                // skip =
        ldr     xv4, [xv4]             // 変数にはコピー先
        bl      RangeCheck             // コピー先を範囲チェック
        bcs     s_range_err            // 範囲外をアクセス
        ldrb    wv1, [xv3]             // PeekChar
        cmp     xv1, #'"               // "
        bne     s_sp0

        mov     x2, xzr                // 文字列定数を配列にコピー
        bl      GetChar                // skip double quote
    1:                                 // next char
        bl      GetChar
        cmp     xv1, #'"               // "
        beq     2f
        tst     xv1, xv1
        beq     2f
        strb    wv1, [xv4, x2]
        add     x2, x2, #1
        cmp     x2, #FNAMEMAX
        blo     1b
    2:                                 // done
        mov     xv1, xzr
        strb    wv1, [xv4, x2]
        mov     x1, #'%                // %
        str     x2, [x29, x1,LSL #3]   // コピーされた文字数
        ldp     x0, x30, [sp], #16
        ret

    s_sp0:
        bl      Exp                    // コピー元のアドレス
        cmp     xv4, x0
        beq     3f
        mov     x2, xv4                // xv4退避
        mov     xv4, x0                // RangeCheckはxv4を見る
        bl      RangeCheck             // コピー先を範囲チェック
        mov     xv4, x2                // コピー先復帰
        bcs     s_range_err            // 範囲外をアクセス
        mov     x2, xzr
    1:  ldrb    w1, [x0], #1
        strb    w1, [xv4], #1
        add     x2, x2, #1
        cmp     x2, #0x40000           // 262144文字まで
        beq     2f
        tst     w1, w1
        bne     1b
    2:  sub     x2, x2, #1             // 文字数から行末を除く
        mov     x1, #'%                // %
        str     x2, [x29, x1,LSL #3]   // コピーされた文字数
        ldp     x0, x30, [sp], #16
        ret

    3:  bl      StrLen
        mov     x2, #'%                // %
        str     x1, [x29, x2,LSL #3]   // 文字数
        ldp     x0, x30, [sp], #16
        ret

    s_array:
        stp     x2, x30, [sp, #-16]!   // x2:filler
        bl      Exp                    // 配列インデックス
        mov     x1, x0
        ldr     xv4, [xv4]
        bl      SkipCharExp            // 式の処理(先読み無しで呼ぶ)
        bl      RangeCheck             // 範囲チェック
        ldp     x2, x30, [sp], #16
        ret

    s_range_err:
        bl      RangeError             // アクセス可能範囲を超えた
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// 配列のアクセス可能範囲をチェック
// , < xv4 < *
//-------------------------------------------------------------------------
RangeCheck:
        stp     x0, x30, [sp, #-16]!
        stp     x1, x2,  [sp, #-16]!
        mov     x2, #'[                // 範囲チェックフラグ
        ldr     x0, [x29, x2,LSL #3]
        tst     x0, x0
        beq     2f                     // 0 ならチェックしない
        adr     x0, input2             // インプットバッファはOK
        cmp     xv4, x0
        beq     2f
        mov     x2, #','               // プログラム先頭
        ldr     x0, [x29, x2,LSL #3]
        mov     x2, #'*'               // RAM末
        ldr     x1, [x29, x2,LSL #3]
        cmp     x0, xv4                // if = > addr, stc
        bhi     1f
        cmp     xv4, x1                // if * <= addr, stc
        bcc     2f
    1:  mov     x0, #0x29000000
        msr     nzcv, x0               // set carry
        ldp     x1, x2, [sp], #16
        ldp     x0, x30, [sp], #16
        ret
    2:  msr     nzcv, xzr              // clear carry
        ldp     x1, x2, [sp], #16
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// 変数の冗長部分の読み飛ばし
//   変数名を x1 に退避, 次の文字を xv1 に返す
//   SetVar, Variable で使用
//-------------------------------------------------------------------------
SkipAlpha:
        stp     x0, x30, [sp, #-16]!
        mov     x1, xv1                // 変数名を x1 に退避
    1:  bl      GetChar
        bl      IsAlpha
        bcc     1b
    2:  ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// SkipEqualExp  = に続く式の評価
// SkipCharExp   1文字を読み飛ばした後 式の評価
// Exp           式の評価
// x0 に値を返す (先読み無しで呼び出し, 1文字先読みで返る)
//-------------------------------------------------------------------------
SkipEqualExp:
        stp     x0, x30, [sp, #-16]!
        bl      GetChar                 // check =
        ldp     x0, x30, [sp], #16

SkipEqualExp2:
        cmp     xv1, #'='               // 先読みの時
        beq     Exp                     // = を確認
        adr     x0, equal_err           //
        bl      OutAsciiZ
        b       pop_and_Error           // 文法エラー

SkipCharExp:
        stp     x0, x30, [sp, #-16]!
        bl      GetChar                 // skip a character
        ldp     x0, x30, [sp], #16

Exp:
        stp     x1, x30, [sp, #-16]!
        ldrb    wv1, [xv3]              // PeekChar
        cmp     xv1, #' '
        bne     e_ok
        mov     x1, #1
        strb    w1, [x29, #-7]          // 式中の空白はエラー
        b       LongJump                // エラー

    e_ok:
        stp     x1, x2, [sp, #-16]!
        stp     x3, xip, [sp, #-16]!
        bl      Factor                  // x1 に項の値
        mov     x0, x1                  // 式が項のみの場合に備える
    e_next:
        mov     x1, x0                  // これまでの結果をx1に格納
        cmp     xv1,  #'+'              // ADD
        bne     e_sub
        mov     x3, x1                  // 項の値を退避
        bl      Factor                  // 右項を取得
        add     x0, x3, x1              // 2項を加算
        b       e_next
    e_sub:
        cmp     xv1,  #'-'              // SUB
        bne     e_mul
        mov     x3, x1                  // 項の値を退避
        bl      Factor                  // 右項を取得
        sub     x0, x3, x1              // 左項から右項を減算
        b       e_next
    e_mul:
        cmp     xv1,  #'*'              // MUL
        bne     e_div
        mov     x3, x1                 // 項の値を退避
        bl      Factor                 // 右項を取得
        mul     x0, x3, x1             // 左項から右項を減算
        b       e_next
    e_div:
        cmp     xv1,  #'/'             // DIV
        bne     e_udiv
        mov     x3, x1                 // 項の値を退避
        tst     x3, x3
        mov     x2, xzr                // 被除数が正
        bpl     1f
        sub     x3, xzr, x3            // x3 = -x3
        mov     x2, #1                 // 被除数が負
    1:
        bl      Factor                 // 右項を取得
        tst     x1, x1
        bne     e_div1
        mov     w2, #1
        strb    w2, [x29, #-6]        // ０除算エラー
        b       e_exit
    e_div1:
        mov     xip, xzr               // 除数が正
        bpl     2f
        sub     x1, xzr, x1            // x1 = -x1
        mov     xip, #1                // 除数が負
    2:  mov     x0, x3
        udiv    x0, X0, x1             // x0/x1 = x0...x1
        msub    x1, x0, x1, x3         // x1 = x3 - (x0*x1)
        cmp     x2, xzr                // 被除数が負?
        beq     3f
        sub     x1, xzr, x1            // x1 = -x1
    3:  cmp     xip, x2                //
        beq     4f
        sub     x0, xzr, x0            // x0 = -x0
    4:  mov     x2, #'%'               // 剰余の保存
        str     x1, [x29, x2,LSL #3]
        mov     x1, x0                 // 商を x1 に
        b       e_next
    e_udiv:
        cmp     xv1,  #'\\'            // UDIV
        bne     e_and
        mov     x3, x1                 // 項の値を退避
        bl      Factor                 // 右項を取得
        tst     x1, x1
        bne     e_udiv1
        mov     w2, #1
        strb    w2, [x29, #-6]         // ０除算エラー
        b       e_exit
    e_udiv1:
        mov     x0, x3
        udiv    x0, X0, x1             // x0/x1 = x0...x1
        msub    x1, x0, x1, x3         // x1 = x3 - (x0*x1)
        mov     x2, #'%'               // 剰余の保存
        str     x1, [x29, x2,LSL #3]
        mov     x1, x0                 // 商を x1 に
        b       e_next
    e_and:
        cmp     xv1, #'&'              // AND
        bne     e_or
        mov     x3, x1                 // 項の値を退避
        bl      Factor                 // 右項を取得
        and     x0, x3, x1
        b       e_next
    e_or:
        cmp     xv1,  #'|'             // OR
        bne     e_xor
        mov     x3, x1                 // 項の値を退避
        bl      Factor                 // 右項を取得
        orr     x0, x3, x1             // 左項と右項を OR
        b       e_next
    e_xor:
        cmp     xv1, #'^'              // XOR
        bne     e_equal
        mov     x3, x1                 // 項の値を退避
        bl      Factor                 // 右項を取得
        eor     x0, x3, x1             // 左項と右項を XOR
        b       e_next
    e_equal:
        cmp     xv1, #'='              // =
        bne     e_exp7
        mov     x3, x1                 // 項の値を退避
        bl      Factor                 // 右項を取得
        cmp     x1, x3                 // 左項と右項を比較
        bne     e_false
    e_true:
        mov     x0, #1
        b       e_next
    e_false:
        mov     x0, xzr                // 0:偽
        b       e_next
    e_exp7:
        cmp     xv1, #'<'              // <
        bne     e_exp8
        ldrb    wv1, [xv3]             // PeekChar
        cmp     xv1, #'='              // <=
        beq     e_exp71
        cmp     xv1, #'>'              // <>
        beq     e_exp72
        cmp     xv1, #'<'              // <<
        beq     e_shl
                                       // <
        mov     x3, x1                 // 項の値を退避
        bl      Factor                 // 右項を取得
        cmp     x3, x1                 // 左項と右項を比較
        bge     e_false
        b       e_true
    e_exp71:
        bl      GetChar                // <=
        mov     x3, x1                 // 項の値を退避
        bl      Factor                 // 右項を取得
        cmp     x3, x1                 // 左項と右項を比較
        bgt     e_false
        b       e_true
    e_exp72:
        bl      GetChar                // <>
        mov     x3, x1                 // 項の値を退避
        bl      Factor                 // 右項を取得
        cmp     x3, x1                 // 左項と右項を比較
        beq     e_false
        b       e_true
    e_shl:
        bl      GetChar                // <<
        cmp     xv1, #'<'              //
        bne     e_exp9
        mov     x3, x1                 // 項の値を退避
        bl      Factor                 // 右項を取得
        lsl     x0, x3, x1             // 左項を右項で SHL (*2)
        b       e_next
    e_exp8:
        cmp     xv1, #'>'              // >
        bne     e_exp9
        ldrb    wv1, [xv3]             // PeekChar
        cmp     xv1, #'='              // >=
        beq     e_exp81
        cmp     xv1,  #'>'             // >>
        beq     e_shr
                                       // >
        mov     x3, x1                 // 項の値を退避
        bl      Factor                 // 右項を取得
        cmp     x3, x1                 // 左項と右項を比較
        ble     e_false
        b       e_true
    e_exp81:
        bl      GetChar                // >=
        mov     x3, x1                 // 項の値を退避
        bl      Factor                 // 右項を取得
        cmp     x3, x1                 // 左項と右項を比較
        blt     e_false
        b       e_true
    e_shr:
        bl      GetChar                // >>
        mov     x3, x1                 // 項の値を退避
        bl      Factor                 // 右項を取得
        lsr     x0, x3, x1             // 左項を右項で SHR (/2)
        b       e_next
    e_exp9:
    e_exit:
        ldp     x3, xip, [sp], #16
        ldp     x1, x2,  [sp], #16
        ldp     x1, x30, [sp], #16
        ret

equal_err:
        .asciz   "\n= reqiured."
        .align   2

//-------------------------------------------------------------------------
// UNIX時間をマイクロ秒単位で返す
//-------------------------------------------------------------------------
GetTime:
        stp     x0, x30, [sp, #-16]!
        stp     x2, x3,  [sp, #-16]!
        adr     x3, TV
        mov     x0, x3
        add     x1, x3, #16            // TZ
        mov     x8, #sys_gettimeofday
        svc     #0
        ldr     x1, [x3]               // sec
        ldr     x0, [x3, #8]           // usec
        mov     x2, #'%'               // 剰余に usec を保存
        str     x0, [x29, x2,LSL #3]
        bl      GetChar
        ldp     x2, x3,  [sp], #16
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// マイクロ秒単位のスリープ _=n
//-------------------------------------------------------------------------
Com_USleep:
        stp     x5, x30, [sp, #-16]!
        stp     x3, x4,  [sp, #-16]!
        bl      SkipEqualExp           // = を読み飛ばした後 式の評価
        adr     x4, TV                 // 第5引数
        mov     x2, #1000              // x2 = 1000
        mul     x3, x2, x2             // x3 = 1000000
        udiv    x1, x0, x3             // x1 = int(x0 / 1000000)
        msub    x0, x1, x3, x0         // x0 = x0 - (x1 * 1000000)
        str     x1, [x4]               // sec
        mul     x0, x0, x2             // usec --> nsec
        str     x0, [x4, #+8]          // nsec
        mov     x0, xzr
        mov     x1, xzr
        mov     x2, xzr
        mov     x3, xzr
        mov     x5, xzr                // 第6引数 NULL
        mov     x8, #sys_pselect6
        svc     #0
        bl      CheckError
        ldp     x3, x4,  [sp], #16
        ldp     x5, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// 配列と変数の参照, x1 に値が返る
// 変数参照にxv4を使用(保存)
// x0 は上位のFactorで保存
//-------------------------------------------------------------------------
Variable:
        stp     xv4, x30, [sp, #-16]!
        bl      SkipAlpha              // 変数名は x1
        add     xv4, x29, x1,LSL #3    // 変数のアドレス
        cmp     xv1, #'('
        beq     v_array1               // 1バイト配列
        cmp     xv1, #'{'
        beq     v_array2               // 2バイト配列
        cmp     xv1, #'['
        beq     v_array4               // 4バイト配列
        cmp     xv1, #';'
        beq     v_array8               // 8バイト配列
        ldr     x1, [xv4]              // 単純変数
        ldp     xv4, x30, [sp], #16
        ret

    v_array1:
        bl      Exp                    // 1バイト配列
        ldr     xv4, [xv4]
        bl      RangeCheck             // 範囲チェック
        bcs     v_range_err            // 範囲外をアクセス
        ldrb    w1, [xv4, x0]
        bl      GetChar                // skip )
        ldp     xv4, x30, [sp], #16
        ret

    v_array2:
        bl      Exp                    // 2バイト配列
        ldr     xv4, [xv4]
        bl      RangeCheck             // 範囲チェック
        bcs     v_range_err            // 範囲外をアクセス
        lsl     x0, x0, #1
        ldrh    w1, [xv4, x0]
        bl      GetChar                // skip }
        ldp     xv4, x30, [sp], #16
        ret

    v_array4:
        bl      Exp                    // 4バイト配列
        ldr     xv4, [xv4]
        bl      RangeCheck             // 範囲チェック
        bcs     v_range_err            // 範囲外をアクセス
        ldr     w1, [xv4, x0,LSL #2]
        bl      GetChar                // skip ]
        ldp     xv4, x30, [sp], #16
        ret

    v_array8:
        bl      Exp                    // 4バイト配列
        ldr     xv4, [xv4]
        bl      RangeCheck             // 範囲チェック
        bcs     v_range_err            // 範囲外をアクセス
        ldr     x1, [xv4, x0,LSL #3]
        bl      GetChar                // skip ]
        ldp     xv4, x30, [sp], #16
        ret

    v_range_err:
        bl      RangeError
        ldp     xv4, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// 変数値
// x1 に値を返す (先読み無しで呼び出し, 1文字先読みで返る)
//-------------------------------------------------------------------------
Factor:
        stp     x0, x30, [sp, #-16]!
        stp     x2, x3,  [sp, #-16]!
        bl      GetChar
        bl      IsNum
        bcs     f_bracket
        bl      Decimal                // 正の10進整数
        mov     x1, x0
        b       f_exit

    f_bracket:
        cmp     xv1, #'('
        bne     f_yen
        bl      Exp                    // カッコ処理
        mov     x1, x0                 // 項の値は x1
        bl      GetChar                // skip )
        b       f_exit

    f_yen:
        cmp     xv1, #'\\              // '\'
        bne     f_rand
        ldrb    wv1, [xv3]             // PeekChar
        cmp     xv1, #'\\              // '\\'
        beq     f_env

        bl      Exp                    // 引数番号を示す式
        ldr     x2, argc_vtl           // vtl用の引数の個数
        cmp     x0, x2                 // 引数番号と引数の数を比較
        blt     2f                     // 引数番号 < 引数の数
        ldr     x2, argvp              // argvp
        ldr     x1, [x2]               // argvp[0]
    1:  ldrb    w2, [x1], #1           // 0を探す
        cbnz    x2, 1b                 // x2!=0 then goto 1b
        sub     x1, x1, #1             // argv[0]のEOLに設定
        b       3f
    2:  adr     x2, argp_vtl           // found
        ldr     x2, [x2]
        ldr     x1, [x2, x0,LSL #3]    // 引数文字列先頭アドレス
    3:  b       f_exit

    f_env:
        bl      GetChar                // skip '\'
        bl      Exp
        ldr     x2, envp
        mov     x1, xzr
    4:  ldr     xip, [x2, x1, LSL #3]  // envp[0]
        cbz     xip, 5f                // xip==0 then 5f
        add     x1, x1, #1
        b       4b
    5:
        cmp     x0, x1
        bge     6f                     // 引数番号が過大
        ldr     x1, [x2, x0,LSL #3]    // 引数文字列先頭アドレス
        b       f_exit
    6:
        add     x1, x2, x1,LSL #3      // 0へのポインタ(空文字列)
        b       f_exit

    f_rand:
        cmp     xv1, #'`'
        bne     f_hex
        bl      genrand                // 乱数の読み出し
        mov     x1, x0
        bl      GetChar
        b       f_exit

    f_hex:
        cmp     xv1, #'$'
        bne     f_time
        bl      Hex                    // 16進数または1文字入力
        b       f_exit

    f_time:
        cmp     xv1, #'_'
        bne     f_num
        bl      GetTime                // 時間を返す
        b       f_exit

    f_num:
        cmp     xv1, #'?'
        bne     f_char
        bl      NumInput               // 数値入力
        b       f_exit

    f_char:
        cmp     xv1, #0x27
        bne     f_singnex
        bl      CharConst              // 文字定数
        b       f_exit

    f_singnex:
        cmp     xv1, #'<'
        bne     f_neg
        bl      Factor
        uxtw    x1, w1                 // ゼロ拡張
        b       f_exit

    f_neg:
        cmp     xv1, #'-'
        bne     f_abs
        bl      Factor                 // 負符号
        neg     x1, x1
        b       f_exit

    f_abs:
        cmp     xv1, #'+'
        bne     f_realkey
        bl      Factor                 // 変数，配列の絶対値
        cmp     x1, xzr
        csneg   x1, x1, x1, pl         // x1 < 0 then x1=-x1
        b       f_exit

    f_realkey:
        cmp     xv1, #'@'
        bne     f_winsize
        bl      RealKey                // リアルタイムキー入力
        mov     x1, x0
        bl      GetChar
        b       f_exit

    f_winsize:
        cmp     xv1, #'.'
        bne     f_pop
        bl      WinSize                // ウィンドウサイズ取得
        mov     x1, x0
        bl      GetChar
        b       f_exit

    f_pop:
        cmp     xv1, #';'
        bne     f_label
        ldr     x2, [x29, #-32]        // VSTACK
        subs    x2, x2, #1
        bhs     2f                     // unsigned higher or same
        mov     w2, #2
        strb    w2, [x29, #-7]         // 変数スタックエラー
        b       1f
    2:  add     x0, x29, x2,LSL #3
        add     x0, x0, #2048          // x29+x2*8+2048
        ldr     x1, [x0]               // 変数スタックから復帰
        str     x2, [x29, #-32]        // スタックポインタ更新
    1:  bl      GetChar
        b       f_exit

    f_label:
.ifdef VTL_LABEL
        cmp     xv1, #'^'
        bne     f_var
        bl      LabelSearch            // ラベルのアドレスを取得
        bcc     2f
        mov     w2, #3
        strb    w2, [x29, #-7]         // ラベルエラー ExpError
    2:  b       f_exit
.endif

    f_var:
        bl      Variable               // 変数，配列参照
    f_exit:
        ldp     x2, x3, [sp], #16
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// コンソールから数値入力
//-------------------------------------------------------------------------
NumInput:
        stp     x0, x30, [sp, #-16]!
        stp     x2, x3,  [sp, #-16]!
        mov     x2, xv5                // EOL状態退避
        mov     x0, #MAXLINE           // 1 行入力
        mov     x3, xv3
        adr     x1, input2             // 行ワークエリア
        bl      READ_LINE3
        mov     xv3, x1
        ldrb    wv1, [xv3], #1         // 1文字先読み
        bl      Decimal
        mov     xv3, x3
        mov     x1, x0
        mov     xv5, x2                // EOL状態復帰
        bl      GetChar
        ldp     x2, x3, [sp], #16
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// コンソールから input2 に文字列入力
//-------------------------------------------------------------------------
StringInput:
        stp     x0, x30, [sp, #-16]!
        stp     x2, x3,  [sp, #-16]!
        mov     x2, xv5                // EOL状態退避
        mov     x0, #MAXLINE           // 1 行入力
        adr     x1, input2             // 行ワークエリア
        bl      READ_LINE3
    2:  mov     x3, #'%                // %
        str     x0, [x29, x3,LSL #3]   // 文字数を返す
        mov     xv5, x2                // EOL状態復帰
        bl      GetChar
        ldp     x2, x3, [sp], #16
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// 文字定数を数値に変換
// x1 に数値が返る
//-------------------------------------------------------------------------
CharConst:
        stp     x0, x30, [sp, #-16]!
        stp     x2, x3,  [sp, #-16]!
        mov     x1, xzr
        mov     x0, #4                 // 文字定数は4バイトまで
    1:
        bl      GetChar
        cmp     xv1, #0x27             // #'''
        beq     2f
        add     x1, xv1, x1, LSL #8
        subs    x0, x0, #1
        bne     1b
    2:
        bl      GetChar
        ldp     x2, x3, [sp], #16
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// 16進整数の文字列を数値に変換
// x1 に数値が返る
//-------------------------------------------------------------------------
Hex:
        ldrb    wv1, [xv3]             // check $$
        cmp     xv1, #'$
        beq     StringInput
        stp     x0, x30, [sp, #-16]!
        stp     x2, x3,  [sp, #-16]!
        mov     x1, xzr
        mov     x2, x1
    1:
        bl      GetChar                // $ の次の文字
        bl      IsNum
        bcs     2f
        sub     xv1, xv1, #'0'         // 整数に変換
        b       4f
    2:
        cmp     xv1, #' '              // 数字以外
        beq     5f
        cmp     xv1, #'A'
        blo     5f                     // 'A' より小なら
        cmp     xv1, #'F'
        bhi     3f
        sub     xv1, xv1, #55          // -'A'+10 = -55
        b       4f
    3:
        cmp     xv1, #'a'
        blo     5f
        cmp     xv1, #'f'
        bhi     5f
        sub     xv1, xv1, #87          // -'a'+10 = -87
    4:
        add     x1, xv1, x1, LSL #4
        add     x2, x2, #1
        b       1b
    5:
        tst     x2, x2
        beq     CharInput
        ldp     x2, x3, [sp], #16
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// コンソールから 1 文字入力, EBXに返す
//-------------------------------------------------------------------------
CharInput:
        bl      InChar
        mov     x1, x0
        ldp     x2, x3, [sp], #16
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// 行の編集
//   x0 行番号
//   xv1    次の文字(GetCharが返す)
//   xv2    実行時行先頭
//   xv3    ソースへのポインタ(getcharで更新)
//   xv4    変数のアドレス
//   xv5    EOLフラグ
//   xv6    変数スタックポインタ
//   x29    変数領域の先頭アドレス
//   xip    局所的な作業レジスタ
//-------------------------------------------------------------------------
LineEdit:
        bl      LineSearch             // 入力済み行番号を探索
        bcc     4f                     // 見つからないので終了
        adr     xv3, input2            // 入力バッファ
        ldr     w0, [xv2, #+4]
        bl      PutDecimal             // 行番号書き込み
        mov     x0, #' '
        strb    w0, [xv3]
        add     xv3, xv3, #1
        add     xv2, xv2, #8
    2:
        ldrb    w0, [xv2], #1          // 行を入力バッファにコピー
        strb    w0, [xv3], #1
        cbnz    x0, 2b                 // 行末か?
    3:
        bl      DispPrompt
        mov     x0, #MAXLINE           // 1 行入力
        adr     x1, input2
        bl      READ_LINE2             // 初期化済行入力
        mov     xv3, x1
    4:
        mov     xv5, xzr               // EOL=no, 入力済み
        ldp     x0, x30, [sp], #16
        ret                            // Mainloopにreturn

//-------------------------------------------------------------------------
// ListMore
//   eax に表示開始行番号
//-------------------------------------------------------------------------
ListMore:
        bl      LineSearch             // 表示開始行を検索
        bl      GetChar                // skip '+'
        bl      Decimal                // 表示行数を取得
        bcs     1f
        mov     x0, #20                // 表示行数無指定は20行
    1:  mov     x2, xv2
    2:  ldr     w1, [x2]               // 次行までのオフセット
        tst     w1, w1
        bmi     List_all               // コード最終か?
        ldr     w3, [x2, #+4]          // 行番号
        add     x2, x2, x1             // 次行先頭
        subs    x0, x0, #1
        bne     2b
        b       List_loop

//-------------------------------------------------------------------------
// List
//  x0 に表示開始行番号
//  xv2 表示行先頭アドレス(破壊)
//-------------------------------------------------------------------------
List:
        tst     x0, x0
        bne     1f                     // partial
        mov     x1, #'='               // プログラム先頭
        ldr     xv2, [x29, x1,LSL #3]
        b       List_all

    1:  bl      LineSearch             // 表示開始行を検索
        bl      GetChar                // 仕様では -
        bl      Decimal                // 範囲最終を取得
        bcs     List_all
        mov     x3, x0                 // 終了行番号
        b       List_loop

List_all:
        mvn     x3, xzr                // 最終まで表示(最大値)
List_loop:
        ldr     w2, [xv2]              // 次行までのオフセット
        tst     w2, w2
        bmi     6f                     // コード最終か?
//        ble     6f                   // コード最終か?
        ldr     w0, [xv2, #+4]         // 行番号
        cmp     x3, x0
        blo     6f
        bl      PrintLeft              // 行番号表示
        mov     x0, #' '
        bl      OutChar
        mov     x1, #8
    4:
        ldrb    w0, [xv2, x1]          // コード部分表示
        cbz     x0, 5f                 // 改行
        bl      OutChar
        add     x1, x1, #1             // 次の1文字
        b       4b
    5:  bl      NewLine
        add     xv2, xv2, x2
        b       List_loop              // 次行処理

    6:
        mov     xv5, #1                // 次に行入力 EOL=yes
        ldp     x0, x30, [sp], #16
        ret                            // Mainloopにreturn

.ifdef DEBUG

//-------------------------------------------------------------------------
// デバッグ用プログラム行リスト <xxxx> 1#
//-------------------------------------------------------------------------
DebugList:
        stp     x0, x30, [sp, #-16]!
        stp     x1, x2,  [sp, #-16]!
        stp     x3, xv2, [sp, #-16]!
        mov     x1, #'='               // プログラム先頭
        ldr     xv2, [x29, x1,LSL #3]
        mov     x0, xv2
        bl      PrintHex16             // プログラム先頭表示
        mov     x0, #' '
        bl      OutChar
        mov     x1, #'&                // ヒープ先頭
        ldr     x0, [x29, x1,LSL #3]
        bl      PrintHex16             // ヒープ先頭表示
        sub     x2, x0, xv2            // プログラム領域サイズ
        mov     x0, #' '
        bl      OutChar
        mov     x0, x2
        bl      PrintLeft
        bl      NewLine
        mvn     x3, xzr                // 最終まで表示(最大値)
    1:
        mov     x0, xv2
        bl      PrintHex16             // 行頭アドレス
        ldr     w2, [xv2]              // 次行までのオフセット
        mov     x0, #' '
        bl      OutChar
        mov     x0, x2
        bl      PrintHex8              // オフセットの16進表記
        mov     x1, #4                 // 4桁右詰
        bl      PrintRight             // オフセットの10進表記
        mov     x0, #' '
        bl      OutChar
        tst     w2, w2
        ble     4f                     // コード最終か?

        ldr     w0, [xv2, #+4]         // 行番号
        cmp     x3, x0
        blo     4f
        bl      PrintLeft              // 行番号表示
        mov     x0, #' '
        bl      OutChar
        mov     x1, #8
    2:
        ldrb    w0, [xv2, x1]          // コード部分表示
        cbz     x0, 3f                 // 改行
        bl      OutChar
        add     x1, x1, #1             // 次の1文字
        b       2b
    3:  bl      NewLine
        add     xv2, xv2, x2
        b       1b                     // 次行処理

    4:  bl      NewLine
        ldp     x3, xv2,  [sp], #16
        ldp     x1, x2,  [sp], #16
        ldp     x0, x30, [sp], #16
        ret

call_DebugList:
        bl      DebugList
        ldp     x0, x30, [sp], #16
        ret                            // Mainloopにreturn

//-------------------------------------------------------------------------
// デバッグ用変数リスト <xxxx> 1$
//-------------------------------------------------------------------------
VarList:
        stp     x0, x30, [sp, #-16]!
        stp     x1, x2,  [sp, #-16]!

        mov     x2, #0x21
    1:  mov     x0, x2
        bl      OutChar
        mov     x0, #' '
        bl      OutChar
        ldr     x0, [x29, x2,LSL #3]
        bl      PrintHex16
        mov     x1, #20
        bl      PrintRight
        bl      NewLine
        add     x2, x2, #1
        cmp     x2, #0x7F
        blo     1b
        ldp     x1, x2,  [sp], #16
        ldp     x0, x30, [sp], #16
        ret

call_VarList:
        bl      VarList
        ldp     x0, x30, [sp], #16
        ret                            // Mainloopにreturn

//-------------------------------------------------------------------------
// デバッグ用ダンプリスト <xxxx> 1%
//-------------------------------------------------------------------------
DumpList:
        stp     x0, x30, [sp, #-16]!
        stp     x1, x2,  [sp, #-16]!
        stp     x3, xv1, [sp, #-16]!
        mov     x1, #'='               // プログラム先頭
        ldr     x2, [x29, x1,LSL #3]
        and     x2, x2, #0xfffffffffffffff0    // 16byte境界から始める
        mov     xv1, #16
    1:  mov     x0, x2
        bl      PrintHex16             // 先頭アドレス表示
        mov     x0, #' '
        bl      OutChar
        mov     x0, #':'
        bl      OutChar
        mov     x3, #16
    2:
        mov     x0, #' '
        bl      OutChar
        ldrb    w0, [x2], #1           // 1バイト表示
        bl      PrintHex2
        subs    x3, x3, #1
        bne     2b
        bl      NewLine
        subs    xv1, xv1, #1
        bne     1b                     // 次行処理
   3:   ldp     x3, xv1, [sp], #16
        ldp     x1, x2,  [sp], #16
        ldp     x0, x30, [sp], #16
        ret

call_DumpList:
        bl      DumpList
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// デバッグ用ラベルリスト <xxxx> 1&
//-------------------------------------------------------------------------
LabelList:
        stp     x0, x30, [sp, #-16]!
        adr     xip, LabelTable        // ラベルテーブル先頭
        adr     x2, TablePointer
        ldr     x3, [x2]               // テーブル最終登録位置
    1:
        cmp     xip, x3
        bhs     2f
        ldr     x0, [xip, #12]
        bl      PrintHex16
        mov     x0, #' '
        bl      OutChar
        mov     x0, xip
        bl      OutAsciiZ
        bl      NewLine
        add     xip, xip, #16
        b       1b
     2:
        ldp     x0, x30, [sp], #16
        ret

call_LabelList:
        bl      LabelList
        ldp     x0, x30, [sp], #16
        ret                            // Mainloopにreturn
.endif

//-------------------------------------------------------------------------
//  編集モード
//  Mainloopからcallされる
//       0) 行番号 0 ならリスト
//       1) 行が行番号のみの場合は行削除
//       2) 行番号の直後が - なら行番号指定部分リスト
//       3) 行番号の直後が + なら行数指定部分リスト
//       4) 行番号の直後が ! なら指定行編集
//       5) 同じ行番号の行が存在すれば入れ替え
//       6) 同じ行番号がなければ挿入
//-------------------------------------------------------------------------
EditMode:
        stp     x0, x30, [sp, #-16]!
        bl      Decimal             // 行番号取得
        tst     x0, x0              // 行番号
        beq     List                // 行番号 0 ならリスト
        cbnz    xv1, 1f             // 行番号のみか
        bl      LineDelete          // 行削除
        ldp     x0, x30, [sp], #16
        ret                         // Mainloopにreturn

    1:  cmp     xv1, #'-'
        beq     List                // 部分リスト
        cmp     xv1, #'+'
        beq     ListMore            // 部分リスト 20行
.ifdef DEBUG
        cmp     xv1, #'#'
        beq     call_DebugList      // デバッグ用行リスト[#]
        cmp     xv1, #'$'
        beq     call_VarList        // デバッグ用変数リスト[$]
        cmp     xv1, #'%'
        beq     call_DumpList       // デバッグ用ダンプリスト[%]
        cmp     xv1, #'&'
        beq     call_LabelList      // デバッグ用ラベルリスト[&]
.endif
        cmp     xv1, #'!'
        beq     LineEdit            // 指定行編集
        bl      LineSearch          // 入力済み行番号を探索
        bcc     LineInsert          // 一致する行がなければ挿入
        bl      LineDelete          // 行置換(行削除+挿入)

//-------------------------------------------------------------------------
// 行挿入
// x0 に挿入行番号
// xv2 に挿入位置
//-------------------------------------------------------------------------
LineInsert:
        mov     x1, xzr                // 挿入する行のサイズを計算
    1:  ldrb    w2, [xv3, x1]          // xv3:入力バッファ先頭
        cmp     w2, wzr                // 行末?
        add     x1, x1, #1             // 次の文字
        bne     1b

        add     x1, x1, #12            // 12=4+4+1+3
        and     x1, x1, #0xfffffffc    // 4バイト境界に整列
        mov     xip, #'&               // ヒープ先頭(コード末)
        ldr     x3, [x29, xip,LSL #3]  // ヒープ先頭アドレス
        mov     x2, x3                 // 元のヒープ先頭
        add     x3, x3, x1             // 新ヒープ先頭計算
        str     x3, [x29, xip,LSL #3]  // 新ヒープ先頭設定
        sub     xv1, x2, xv2           // 移動バイト数

        sub     x2, x2, #1             // 始めは old &-1 から
        sub     x3, x3, #1             // new &-1 へのコピー

    2:
        ldrb    wip, [x2], #-1         // メモリ後部から移動
        strb    wip, [x3], #-1
        subs    xv1, xv1, #1           // xv1バイト移動
        bne     2b

        str     w1, [xv2]              // 次行へのオフセット設定
        str     w0, [xv2, #4]          // 行番号設定
        add     xv2, xv2, #8           // 書き込み位置更新

    3:  ldrb    w2, [xv3],#1           // xv3:入力バッファ
        strb    w2, [xv2],#1           // xv2:挿入位置
        cbnz    x2, 3b                 // 行末?
        mov     xv5, #1                // 次に行入力 EOL=yes
        ldp     x0, x30, [sp], #16
        ret                            // Mainloopにreturn

//-------------------------------------------------------------------------
// 行の削除
// x0 に検索行番号
//-------------------------------------------------------------------------
LineDelete:
        stp     x0, x30, [sp, #-16]!
        bl      LineSearch             // 入力済み行番号を探索
        bcc     2f                     // 一致する行がなければ終了
        mov     x0, xv2                // 削除行先頭位置
        ldr     w2, [xv2]              // 次行オフセット取得
        add     x2, xv2, x2            // 次行先頭位置取得
        mov     x1, #'&                // ヒープ先頭
        ldr     x3, [x29, x1,LSL #3]
        sub     xv1, x3, x2            // xv1:移動バイト数
    1:
        ldrb    wip, [x2], #1          // xv1バイト移動
        strb    wip, [x0], #1
        subs    xv1, xv1, #1
        bne     1b
        str     x3, [x29, x1,LSL #3]
    2:
        mov     xv5, #1                // 次に行入力 EOL=yes
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// 入力済み行番号を探索
// x0 に検索行番号、x1, x2 破壊
// 一致行先頭または不一致の場合には次に大きい行番号先頭位置にxv2設定
// 同じ行番号があればキャリーセット
//-------------------------------------------------------------------------
LineSearch:
        mov     x1, #'='               // プログラム先頭
        ldr     xv2, [x29, x1,LSL #3]
LineSearch_nextline:
    1:  ldr     w1, [xv2]              // コード末なら検索終了
        tst     w1, w1
        bmi     3f                     // exit
        ldr     w2, [xv2, #+4]         // 行番号
        cmp     w0, w2
        beq     2f                     // 検索行x0 = 注目行x2
        blo     3f                     // 検索行x0 < 注目行x2
        add     xv2, xv2, x1           // 次行先頭 (xv2=xv2+offset)
        b       1b
    2:  mov     x1, #0x29000000        // carry set
        msr     nzcv, x1
        ret
    3:  msr     nzcv, xzr
        ret

//-------------------------------------------------------------------------
// 10進文字列を整数に変換
// x0 に数値が返る、非数値ならキャリーセット
// 1 文字先読み(xv1)で呼ばれ、1 文字先読み(xv1)して返る
//-------------------------------------------------------------------------
Decimal:
        stp     x1, x30, [sp, #-16]!
        stp     x2, x3,  [sp, #-16]!
        mov     x2, xzr                // 正の整数を仮定
        mov     x0, xzr
        mov     x1, #10
        cmp     xv1, #'+
        beq     1f
        cmp     xv1, #'-
        bne     2f                     // Num
        mov     x2, #1                 // 負の整数
    1:
        bl      GetDigit
        bcs     4f                     // 数字でなければ返る
        b       3f
    2:
        bl      IsNum
        bcs     5f                     // 数字でない
        sub     xv1, xv1, #'0          // 数値に変換

    3:
        madd    xip, x0, x1, xv1       // x0=x0*10+xv1
        mov     x0, xip
        bl      GetDigit
        bcc     3b
        tst     x2, x2                 // 数は負か？
        beq     4f
        subs    x0, xzr, x0            // 負にする
    4:  msr     nzcv, xzr              // clear carry
    5:  ldp     x2, x3,  [sp], #16
        ldp     x1, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// 符号無し10進数文字列 xv3 の示すメモリに書き込み
// x0 : 数値
//-------------------------------------------------------------------------
PutDecimal:
        stp     x0, x30, [sp, #-16]!
        stp     x1, x2,  [sp, #-16]!
        stp     x3, x4,  [sp, #-16]!
        mov     x4, sp
        sub     sp, sp, #32             // allocate buffer
        mov     x2, xzr                 // counter
    1:  mov     x1, #10                 //
        mov     x3, x0
        udiv    x0, X0, x1              // x0/x1 = x0...x1
        msub    x1, x0, x1, x3          // x1 = x3 - (x0*x1)
        add     x2, x2, #1              // counter++
        strb    w1, [x4, #-1]!          // least digit (reminder)
        cbnz    x0, 1b                  // done ?
    2:  ldrb    w0, [x4], #1            // most digit
        add     x0, x0, #'0'            // ASCII
        strb    w0, [xv3], #1           // output a digit
        subs    x2, x2, #1              // counter--
        bne     2b
        add     sp, sp, #32
        ldp     x3, x4,  [sp], #16
        ldp     x1, x2,  [sp], #16
        ldp     x0, x30, [sp], #16
        ret

//---------------------------------------------------------------------
// xv1 の文字が数字かどうかのチェック
// 数字なら整数に変換して xv1 返す. 非数字ならキャリーセット
// ! 16進数と文字定数の処理を加えること
//---------------------------------------------------------------------

IsNum:  cmp     xv1, #'0'              // 0 - 9
        bcs     1f
        mov     x0, #0x29000000        // set carry xv1<'0'
        msr     nzcv, x0
        ret
    1:  cmp     xv1, #':'              // set carry xv1>'9'
        ret

GetDigit:
        stp     x0, x30, [sp, #-16]!
        bl      GetChar                // 0 - 9
        bl      IsNum
        bcs     1f
        sub     xv1, xv1, #'0'         // 整数に変換 Cy=0
    1:  ldp     x0, x30, [sp], #16
        ret

IsAlpha:
        stp     x0, x30, [sp, #-16]!
        bl      IsAlpha1               // 英大文字か?
        bcc     1f                     // yes
        bl      IsAlpha2               // 英小文字か?
    1:  ldp     x0, x30, [sp], #16
        ret

IsAlpha1:
        cmp     xv1, #'A               // 英大文字(A-Z)か?
        bcs     1f
        mov     x0, #0x29000000        // if xv1<'A' Cy=1
        msr     nzcv, x0
        ret
    1:  cmp     xv1, #'[               // if xv1>'Z' Cy=1
        ret

IsAlpha2:
        cmp     xv1, #'a               // 英小文字(a-z)か?
        bcs     1f
        mov     x0, #0x29000000        // if xv1<'a' Cy=1
        msr     nzcv, x0
        ret
    1:  cmp     xv1, #'z+1             // if xv1>'z' Cy=1
        ret

IsAlphaNum:
        stp     x0, x30, [sp, #-16]!
        bl      IsAlpha                // 英文字か?
        bcc     1f                     // yes
        bl      IsNum                  // 数字か?
    1:  ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// ファイル読み込み
//-------------------------------------------------------------------------
READ_FILE:
        stp     x0, x30, [sp, #-16]!
        mov     xip, xzr            // ip=0
        adr     x1, input2          // 入力バッファアドレス
    1:
        ldr     x0, [x29, #-16]     // FileDesc
        mov     x2, #1              // 読みこみバイト数
        mov     x8, #sys_read       // ファイルから読みこみ
        svc     #0
        bl      CheckError
        tst     x0, x0
        beq     2f                  // EOF ?

        ldrb    w0, [x1]
        cmp     x0, #10             // LineFeed ?
        beq     3f
        add     x1, x1, #1          // input++
        b       1b
    2:
        ldr     x0, [x29, #-16]     // FileDesc
        bl      fclose              // File Close
        strb    wip, [x29, #-4]     // Read from console (0)
        bl      LoadCode            // 起動時指定ファイル有？
        b       4f
    3:  mov     xv5, xip            // EOL=no
    4:  strb    wip, [x1]
        adr     xv3, input2
    1:  ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// 数値出力 ?
//-------------------------------------------------------------------------
Com_OutNum:
        stp     x0, x30, [sp, #-16]!
        bl      GetChar             // get next
        cmp     xv1, #'='
        bne     1f
        bl      Exp                 // PrintLeft
        bl      PrintLeft
        b       to_ret

    1:
        cmp     xv1, #'*'           // 符号無し10進
        beq     on_unsigned
        cmp     xv1, #'$'           // ?$ 16進2桁
        beq     on_hex2
        cmp     xv1, #'#'           // ?# 16進4桁
        beq     on_hex4
        cmp     xv1, #'?'           // ?? 16進8桁
        beq     on_hex8
        cmp     xv1, #'%'           // ?% 16進16桁
        beq     on_hex16
        mov     x3, xv1
        bl      Exp
        and     x1, x0, #0xff       // 表示桁数(MAX255)設定
        bl      SkipEqualExp        // 1文字を読み飛ばした後 式の評価
        cmp     x3, #'{'            // ?{ 8進数
        beq     on_oct
        cmp     x3, #'!'            // ?! 2進nビット
        beq     on_bin
        cmp     x3, #'('            // ?( print right
        beq     on_dec_right
        cmp     x3, #'['            // ?[ print right
        beq     on_dec_right0
        b       pop_and_Error       // スタック補正後 SyntaxError

    on_unsigned:
        bl      SkipEqualExp        // 1文字を読み飛ばした後 式の評価
        bl      PrintLeftU
        b       to_ret
    on_hex2:
        bl      SkipEqualExp        // 1文字を読み飛ばした後 式の評価
        bl      PrintHex2
        b       to_ret
    on_hex4:
        bl      SkipEqualExp        // 1文字を読み飛ばした後 式の評価
        bl      PrintHex4
        b       to_ret
    on_hex8:
        bl      SkipEqualExp        // 1文字を読み飛ばした後 式の評価
        bl      PrintHex8
        b       to_ret
    on_hex16:
        bl      SkipEqualExp        // 1文字を読み飛ばした後 式の評価
        bl      PrintHex16
        b       to_ret
    on_oct:
        bl      PrintOctal
        b       to_ret
    on_bin:
        bl      PrintBinary
        b       to_ret
    on_dec_right:
        bl      PrintRight
        b       to_ret
    on_dec_right0:
        bl      PrintRight0
    to_ret:
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// 文字出力 $
//-------------------------------------------------------------------------
Com_OutChar:
        stp     x0, x30, [sp, #-16]!
        bl      GetChar                // get next
        cmp     xv1, #'='
        beq     1f
        cmp     xv1, #'$'              // $$ 2byte
        beq     2f
        cmp     xv1, #'#'              // $# 4byte
        beq     4f
        cmp     xv1, #'%'              // $% 8byte
        beq     5f
        cmp     xv1, #'*'              // $*=StrPtr
        beq     7f
        ldp     x0, x30, [sp], #16
        ret

    1:  bl      Exp                    // 1バイト文字
        b       3f

    2:  bl      SkipEqualExp           // 2バイト文字
        and     x1, x0, #0x00ff
        and     x2, x0, #0xff00
        lsr     x0, x2, #8             // 上位バイトが先
        bl      OutChar
        mov     x0, x1
    3:  bl      OutChar
        ldp     x0, x30, [sp], #16
        ret

    4:  bl      SkipEqualExp           // 4バイト文字
        mov     x1, x0
        mov     x2, #4
        b       6f

    5:  bl      SkipEqualExp           // 8バイト文字
        mov     x1, x0
        mov     x2, #8
    6:  ror     x1, x1, #24            // = ROL #8
        and     x0, x1, #0xFF
        bl      OutChar
        subs    x2, x2, #1
        bne     6b
        ldp     x0, x30, [sp], #16
        ret

    7:  bl      SkipEqualExp
        bl      OutAsciiZ
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// 空白出力 .=n
//-------------------------------------------------------------------------
Com_Space:
        stp     x0, x30, [sp, #-16]!
        bl      SkipEqualExp        // 1文字を読み飛ばした後 式の評価
        mov     x1, x0
        mov     x0, #' '
    1:  bl      OutChar
        subs    x1, x1, #1
        bne     1b
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// 改行出力 /
//-------------------------------------------------------------------------
Com_NewLine:
        stp     x0, x30, [sp, #-16]!
        bl      NewLine
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// 文字列出力 "
//-------------------------------------------------------------------------
Com_String:
        stp     x0, x30, [sp, #-16]!
        mov     x1, xzr
        mov     x0, xv3
    1:  bl      GetChar
        cmp     xv1, #'"               // "
        beq     2f
        cmp     xv5, #1                // EOL=yes ?
        beq     2f
        add     x1, x1, #1
        b       1b
    2:
        bl      OutString
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// GOTO #
//-------------------------------------------------------------------------
Com_GO:
        stp     x0, x30, [sp, #-16]!
        bl      GetChar
        cmp     xv1, #'!'
        beq     2f                     // #! はコメント、次行移動
.ifdef VTL_LABEL
        bl      ClearLabel
.endif
        bl      SkipEqualExp2          // = をチェックした後 式の評価
Com_GO_go:
        ldrb    w1, [x29, #-3]         // ExecMode=Direct ?
        cbz     x1, 4f                 // Directならラベル処理へ

.ifdef VTL_LABEL
        mov     x1, #'^'               // システム変数「^」の
        ldr     x2, [x29, x1,LSL #3]   // チェック
        tst     x2, x2                 // 式中でラベル参照があるか?
        beq     1f                     // 無い場合は行番号
        mov     xv2, x0                // xv2 を指定行の先頭アドレスへ
        mov     x0, xzr                // システム変数「^」クリア
        str     x0, [x29, x1,LSL #3]   // ラベル無効化
        b       6f                     // check
.endif

    1: // 行番号
        tst     x0, x0                 // #=0 なら次行
        bne     3f                     // 行番号にジャンプ
    2: // nextline
        mov     xv5, #1                // 次行に移動  EOL=yes
        ldp     x0, x30, [sp], #16
        ret

    3: // ジャンプ先行番号を検索
        ldr     w1, [xv2, #+4]         // 現在の行と行番号比較
        cmp     x0, x1
        blo     5f                     // 先頭から検索
        bl      LineSearch_nextline    // 現在行から検索
        b       6f                     // check

    4: // label
.ifdef VTL_LABEL
        bl      LabelScan              // ラベルテーブル作成
.endif

    5: // top:
        bl      LineSearch             // xv2 を指定行の先頭へ
    6: // check:
        ldr     w0, [xv2]              // コード末チェック
        adds    w0, w0, #1
        beq     7f                     // stop
        mov     w0, #1
        strb    w0, [x29, #-3]         // ExecMode=Memory
        bl      SetLineNo2             // 行番号を # に設定
        add     xv3, xv2, #8           // 次行先頭
        mov     xv5, xzr               // EOL=no
        ldp     x0, x30, [sp], #16
       ret
    7: // stop:
        bl      CheckCGI               // CGIモードなら終了
        bl      WarmInit1              // 入力デバイス変更なし
        ldp     x0, x30, [sp], #16
        ret

.ifdef VTL_LABEL
//-------------------------------------------------------------------------
// 式中でのラベル参照結果をクリア
//-------------------------------------------------------------------------
ClearLabel:
        mov     x1, #'^'               //
        mov     x0, xzr                // システム変数「^」クリア
        str     x0, [x29, x1,LSL #3]   // ラベル無効化
        ret

//-------------------------------------------------------------------------
// コードをスキャンしてラベルとラベルの次の行アドレスをテーブルに登録
// ラベルテーブルは32バイト／エントリで1024個(32KB)
// 24バイトのASCIIZ(23バイトのラベル文字) + 8バイト(行先頭アドレス)
// x0-x4保存, xv1,xv2 使用
//-------------------------------------------------------------------------
LabelScan:
        stp     x0, x30, [sp, #-16]!
        stp     x1, x2, [sp, #-16]!
        stp     x3, x4, [sp, #-16]!
        mov     x1, #'='
        ldr     xv2, [x29, x1,LSL #3]  // コード先頭アドレス
        ldr     wv1, [xv2]             // コード末なら終了
        adds    wv1, wv1, #1
        bne     1f                     // コード末でない
        ldp     x3, x4, [sp], #16
        ldp     x1, x2, [sp], #16
        ldp     x0, x30, [sp], #16
        ret

    1:  adr     x3, LabelTable         // ラベルテーブル先頭
        adr     x0, TablePointer
        str     x3, [x0]               // 登録する位置格納

    2:
        mov     x1, #8                 // テキスト先頭位置
    3:                                 // 空白をスキップ
        ldrb    wv1, [xv2, x1]         // 1文字取得
        cmp     wv1, wzr
        beq     7f                     // 行末なら次行
        cmp     xv1, #' '              // 空白読み飛ばし
        bne     4f                     // ラベル登録へ
        add     x1, x1, #1
        b       3b

    4: // nextch
        cmp     xv1, #'^'              // ラベル?
        bne     7f                     // ラベルでなければ
       // ラベルを登録
        add     x1, x1, #1             // ラベル文字先頭
        mov     x2, xzr                // ラベル長
    5:
        ldrb    wv1, [xv2, x1]         // 1文字取得
        cmp     wv1, wzr
        beq     6f                     // 行末
        cmp     wv1, #' '              // ラベルの区切りは空白
        beq     6f                     // ラベル文字列
        cmp     x2, #23                // 最大11文字まで
        beq     6f                     // 文字数
        strb    wv1, [x3, x2]          // 1文字登録
        add     x1, x1, #1
        add     x2, x2, #1
        b       5b                     // 次の文字

    6: // registerd
        mov     xv1, xzr
        strb    wv1, [x3, x2]          // ラベル文字列末
        ldr     wv1, [xv2]             // 次行オフセット
        add     xv1, xv2, xv1          // xv1に次行先頭
        str     xv1, [x3, #24]         // アドレス登録
        add     x3, x3, #32
        mov     xv2, xv1
        str     x3, [x0]               // 次に登録する位置(TablePointer)

    7:                                 // 次行処理
        ldr     wv1, [xv2]             // 次行オフセット
        add     xv2, xv2, xv1          // xv1に次行先頭
        ldr     wv1, [xv2]             // 次行オフセット
        adds    wv1, wv1, #1
        beq     8f                     // スキャン終了
        cmp     x3, x0                 // テーブル最終位置
        beq     8f                     // スキャン終了
        b       2b                     // 次行の処理を繰り返し

    8: // finish:
        ldp     x3, x4, [sp], #16
        ldp     x1, x2, [sp], #16
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// テーブルからラベルの次の行アドレスを取得
// ラベルの次の行の先頭アドレスを x1 と「^」に設定、xv1に次の文字を設定
// して返る。Factorから xv3 を^の次に設定して呼ばれる
// xv3 はラベルの後ろ(長すぎる場合は読み飛ばして)に設定される
// x0, x2, x3, ip は破壊
//-------------------------------------------------------------------------
LabelSearch:
        stp     x0, x30, [sp, #-16]!
        adr     x3, LabelTable         // ラベルテーブル先頭
        adr     x0, TablePointer
        ldr     x1, [x0]               // テーブル最終登録位置

    1:
        mov     x2, xzr                // ラベル長
    2:
        ldrb    wv1, [xv3, x2]         // ソース
        ldrb    wip, [x3, x2]          // テーブルと比較
        tst     wip, wip               // テーブル文字列の最後?
        bne     3f                     // 比較を継続
        bl      IsAlphaNum
        bcs     4f                     // xv1=space, ip=0

    3:  // 異なる
        cmp     xv1, xip               // 比較
        bne     5f                     // 一致しない場合は次のラベル
        add     x2, x2, #1             // 一致したら次の文字
        cmp     x2, #23                // 長さのチェック
        bne     2b                     // 次の文字を比較
        bl      Skip_excess            // 長過ぎるラベルは後ろを読み飛ばし

    4:  // found
        ldr     x1, [x3, #24]          // テーブルからアドレス取得
        mov     x0, #'^'               // システム変数「^」に
        str     x1, [x29, x0,LSL #3]   // ラベルの次行先頭を設定
        add     xv3, xv3, x2
        bl      GetChar
        mov     x0, #0x00000000        // 見つかればキャリークリア
        msr     nzcv, x0
        ldp     x0, x30, [sp], #16
        ret

    5:  // next
        add     x3, x3, #32
        cmp     x3, x1                 // テーブルの最終エントリ
        beq     6f                     // 見つからない場合
        cmp     x3, x0                 // テーブル領域最終?
        beq     6f                     //
        b       1b                     // 次のテーブルエントリ

    6:  // not found:
        mov     x2, xzr
        bl      Skip_excess            // ラベルを空白か行末まで読飛ばし
//        mvn     x1, #0x00000000      // x1 に-1を返す
        mov     x1, #1
        sub     x1, xzr, x1
        mov     x0, #0x29000000        // なければキャリーセット
        msr     nzcv, x0
        ldp     x0, x30, [sp], #16
        ret

Skip_excess:
        stp     x0, x30, [sp, #-16]!
    1:  ldrb    wv1, [xv3, x2]         // 長過ぎるラベルはスキップ
        bl      IsAlphaNum
        bcs     2f                     // 英数字以外
        add     x2, x2, #1             // ソース行内の読み込み位置更新
        b       1b
    2:  ldp     x0, x30, [sp], #16
        ret

.endif

//-------------------------------------------------------------------------
// = コード先頭アドレスを再設定
//-------------------------------------------------------------------------
Com_Top:
        stp     x0, x30, [sp, #-16]!
        bl      SkipEqualExp           // = を読み飛ばした後 式の評価
        mov     x3, x0
        bl      RangeCheck             // ',' <= '=' < '*'
        blo     4f                     // 範囲外エラー
        mov     x1, #'='               // コード先頭
        str     x3, [x29, x1,LSL #3]   // 式の値を=に設定 ==x3
        mov     x1, #'*'               // メモリ末
        ldr     x2, [x29, x1,LSL #3]   // x2=*
    1: // nextline:                    // コード末検索
        ldr     w0, [x3]               // 次行へのオフセット
        adds    w1, w0, #1             // 行先頭が -1 ?
        beq     2f                     // yes
        tst     w0, w0
        ble     3f                     // 次行へのオフセット <= 0 不正
        ldr     w1, [x3, #4]           // 行番号 > 0
        tst     w1, w1
        ble     3f                     // 行番号 <= 0 不正
        add     x3, x3, x0             // 次行先頭アドレス
        cmp     x2, x3                 // 次行先頭 > メモリ末
        ble     3f                     //
        b       1b                     // 次行処理
    2: // found:
        mov     x2, x0                 // コード末発見
        b       Com_NEW_set_end        // & 再設定
    3: // endmark_err:
        adr     x0, EndMark_msg        // プログラム未入力
        bl      OutAsciiZ
        bl      WarmInit               //
        ldp     x0, x30, [sp], #16
       ret

    4: // range_err
        bl      RangeError
        ldp     x0, x30, [sp], #16
       ret

EndMark_msg:
        .asciz   "\n&=0 required.\n"
        .align   2

//-------------------------------------------------------------------------
// コード末マークと空きメモリ先頭を設定 &
//   = (コード領域の先頭)からの相対値で指定, 絶対アドレスが設定される
//-------------------------------------------------------------------------
Com_NEW:
        stp     x0, x30, [sp, #-16]!
        bl      SkipEqualExp           // = を読み飛ばした後 式の評価
        mov     x1, #'='               // コード先頭
        ldr     x2, [x29, x1,LSL #3]   // &==*8
        mvn     w0, wzr                // コード末マーク(-1)
        str     w0, [x2]               // コード末マーク
Com_NEW_set_end:
        add     x2, x2, #4             // コード末の次
        mov     x1, #'&'               // 空きメモリ先頭
        str     x2, [x29, x1,LSL #3]   //
        bl      WarmInit1              // 入力デバイス変更なし
        ldp     x0, x30, [sp], #16
       ret

//-------------------------------------------------------------------------
// BRK *
//    メモリ最終位置を設定, brk
//-------------------------------------------------------------------------
Com_BRK:
        stp     x0, x30, [sp, #-16]!
        bl      SkipEqualExp           // = を読み飛ばした後 式の評価
        mov     x8, #sys_brk           // メモリ確保
        svc     #0
        mov     x1, #'*'               // ヒープ先頭
        str     x0, [x29, x1,LSL #3]
        ldp     x0, x30, [sp], #16
       ret

//-------------------------------------------------------------------------
// RANDOM '
//    乱数設定 /dev/urandom から必要バイト数読み出し
//    /usr/src/linux/drivers/char/random.c 参照
//-------------------------------------------------------------------------
Com_RANDOM:
        stp     x0, x30, [sp, #-16]!
        bl      SkipEqualExp           // = を読み飛ばした後 式の評価
        mov     x1, #'`'               // 乱数シード設定
        str     x0, [x29, x1,LSL #3]
        bl      sgenrand
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// 範囲チェックフラグ [
//-------------------------------------------------------------------------
Com_RCheck:
        stp     x0, x30, [sp, #-16]!
        bl      SkipEqualExp           // = を読み飛ばした後 式の評価
        mov     x1, #'['               // 範囲チェック
        str     x0, [x29, x1,LSL #3]
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// 変数または式をスタックに保存
//-------------------------------------------------------------------------
Com_VarPush:
        stp     x0, x30, [sp, #-16]!
        ldr     x2, [x29, #-32]        // VSTACK
        mov     x3, #VSTACKMAX
        sub     x3, x3, #1             // x3 = VSTACKMAX - 1
    1: // next
        cmp     x2, x3
        bhi     VarStackError_over
        bl      GetChar
        cmp     xv1, #'='              // +=式
        bne     2f
        bl      Exp
        add     x1, x29, #2048         // [x29+x2*8+2048]
        str     x0, [x1, x2,LSL #3]    // 変数スタックに式を保存
        add     x2, x2, #1
        b       3f
    2: // push2
        cmp     xv1, #' '
        beq     3f
        cmp     xv5 , #1               // EOL=yes?
        beq     3f
        ldr     x0, [x29, xv1,LSL #3]  // 変数の値取得
        add     x1, x29, #2048         // [x29+x2*8+2048]
        str     x0, [x1, x2,LSL #3]    // 変数スタックに式を保存
        add     x2, x2, #1
        b       1b                     // 次の変数
    3: // exit
        str     x2, [x29, #-32]        // VSTACK更新
        ldp     x0, x30, [sp], #16
       ret

//-------------------------------------------------------------------------
// 変数をスタックから復帰
//-------------------------------------------------------------------------
Com_VarPop:
        stp     x0, x30, [sp, #-16]!
        ldr     x2, [x29, #-32]         // VSTACK
    1: // next:
        bl      GetChar
        cmp     xv1, #' '
        beq     2f
        cmp     xv5 , #1                // EOL=yes?
        beq     2f
        subs    x2, x2, #1
        bmi     VarStackError_under
        add     x1, x29, #2048          // [x29+x2*8+2048]
        ldr     x0, [x1, x2,LSL #3]     // 変数スタックから復帰
        str     x0, [x29, xv1,LSL #3]   // 変数に値設定
        b       1b
    2: // exit:
        str     x2, [x29, #-32]         // VSTACK更新
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// ファイル格納域先頭を指定 xv4使用
//-------------------------------------------------------------------------
Com_FileTop:
        stp     x0, x30, [sp, #-16]!
        bl      SkipEqualExp           // = を読み飛ばした後 式の評価
        mov     xv4, x0
        bl      RangeCheck             // 範囲チェック
        bcs     1f                     // Com_FileEnd:1 範囲外をアクセス
        mov     x1, #'{'               // ファイル格納域先頭
        str     x0, [x29, x1,LSL #3]
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// ファイル格納域最終を指定 xv4使用
//-------------------------------------------------------------------------
Com_FileEnd:
        stp     x0, x30, [sp, #-16]!
        bl      SkipEqualExp           // = を読み飛ばした後 式の評価
        mov     xv4, x0
        bl      RangeCheck             // 範囲チェック
        bcs     1f                     // 範囲外をアクセス
        mov     x1, #'}'               // ファイル格納域先頭
        str     x0, [x29, x1,LSL #3]
        ldp     x0, x30, [sp], #16
        ret
    1: // range_err
        bl      RangeError
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// CodeWrite <=
//-------------------------------------------------------------------------
Com_CdWrite:
        stp     x0, x30, [sp, #-16]!
        bl      GetFileName
        bl      fwopen                 // open
        beq     4f                     // exit
        bmi     5f                     // error
        str     x0, [x29, #-24]        // FileDescW
        mov     x1, #'='
        ldr     x3, [x29, x1,LSL #3]   // コード先頭アドレス
        stp     xv3, x0, [sp, #-16]!   // save xv3

    1: // loop
        adr     xv3, input2            // ワークエリア(行)
        ldr     w0, [x3]               // 次行へのオフセット
        adds    w0, w0, #1             // コード最終か?
        beq     4f                     // 最終なら終了
        ldr     w0, [x3, #4]           // 行番号取得
        bl      PutDecimal             // x0の行番号をxv3に書き込み
        mov     x0, #' '               // スペース書込み
        strb    w0, [xv3], #1          // Write One Char
        mov     x1, #8
    2: // code:
        ldrb    w0, [x3, x1]           // コード部分書き込み
        cbz     x0, 3f                 // 行末か? file出力後次行
        strb    w0, [xv3], #1          // Write One Char
        add     x1, x1, #1
        b       2b

    3: // next:
        ldr     w1, [x3]               // 次行オフセット
        add     x3, x3, x1             // 次行先頭へ
        mov     x0, #10
        strb    w0, [xv3], #1          // 改行書込み
        mov     x0, xzr
        strb    w0, [xv3]              // EOL

        adr     x0, input2             // バッファアドレス
        bl      StrLen                 // x0の文字列長をx1に返す
        mov     x2, x1                 // 書きこみバイト数
        mov     x1, x0                 // バッファアドレス
        ldr     x0, [x29, #-24]        // FileDescW
        mov     x8, #sys_write         // システムコール
        svc     #0
        b       1b                     // 次行処理
    4: // exit:
        ldp     xv3, x0, [sp], #16     // restore xv3
        ldr     x0, [x29, #-24]        // FileDescW
        bl      fclose                 // ファイルクローズ
        mov     xv5, #1                // EOL=yes
        ldp     x0, x30, [sp], #16
        ret

    5: // error:
        b       pop_and_Error

//-------------------------------------------------------------------------
// CodeRead >=
//-------------------------------------------------------------------------
Com_CdRead:
        stp     x0, x30, [sp, #-16]!
        ldrb    w0, [x29, #-4]
        cmp     x0, #1                 // Read from file
        beq     2f
        bl      GetFileName
        bl      fropen                 // open
        beq     1f
        bmi     SYS_Error
        str     x0, [x29, #-16]         // FileDesc
        mov     x1, #1
        strb    w1, [x29, #-4]          // Read from file
        mov     xv5, x1                 // EOL
    1: // exit
        ldp     x0, x30, [sp], #16
       ret
    2: // error
        adr     x0, error_cdread
        bl      OutAsciiZ
        b       SYS_Error_return

error_cdread:   .asciz   "\nCode Read (>=) is not allowed!\n"
                .align   2

//-------------------------------------------------------------------------
// 未定義コマンド処理(エラーストップ)
//-------------------------------------------------------------------------
pop_and_SYS_Error:
        add     sp, sp, #16          // スタック修正
SYS_Error:
        bl      CheckError
SYS_Error_return:
        add     sp, sp, #16          // スタック修正
        bl      WarmInit
        b       MainLoop

//-------------------------------------------------------------------------
// システムコールエラーチェック
//-------------------------------------------------------------------------
CheckError:
        stp     x0, x30, [sp, #-16]!
        stp     x1, x2,  [sp, #-16]!
        mrs     x2, nzcv
        mov     x1, #'|'            // 返り値を | に設定
        str     x0, [x29, x1,LSL #3]
.ifdef  DETAILED_MSG
        bl      SysCallError
.else
        tst     x0, x0
        bpl     1f
        adr     x0, Error_msg
        bl      OutAsciiZ
.endif
        msr     nzcv, x2
    1:
        ldp     x1, x2, [sp], #16
        ldp     x0, x30, [sp], #16
        ret

Error_msg:      .asciz   "\nError!\n"
                .align   2

//-------------------------------------------------------------------------
// FileWrite (=
//-------------------------------------------------------------------------
Com_FileWrite:
        stp     x0, x30, [sp, #-16]!
        ldrb    wv1, [xv3]             // check (*=\0
        cmp     xv1, #'*
        bne     1f
        bl      GetChar
        bl      GetChar
        cmp     xv1, #'='
        bne     pop_and_Error
        bl      Exp                    // Get argument
        b       2f                     // open

    1:  bl      GetFileName
        bl      OutAsciiZ
    2:  bl      fwopen                 // open
        beq     3f
        bmi     SYS_Error
        str     x0, [x29, #-24]        // FileDescW

        mov     x2, #'{'               // 格納領域先頭
        ldr     x1, [x29, x2,LSL #3]   // バッファ指定
        mov     x2, #'}'               // 格納領域最終
        ldr     x3, [x29, x2,LSL #3]   //
        cmp     x3, x1
        blo     3f
        sub     x2, x3, x1             // 書き込みサイズ
        ldr     x0, [x29, #-24]        // FileDescW
        mov     x8, #sys_write         // システムコール
        svc     #0
        bl      fclose
    3: // exit:
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// FileRead )=
//-------------------------------------------------------------------------
Com_FileRead:
        stp     x0, x30, [sp, #-16]!
        ldrb    wv1, [xv3]             // check )*=\0
        cmp     xv1, #'*
        bne     1f
        bl      GetChar
        bl      GetChar
        cmp     xv1, #'='
        bne     pop_and_Error
        bl      Exp                    // Get argument
        b       2f                     // open

    1:  bl      GetFileName
    2:  bl      fropen                 // open
        beq     3f
        bmi     SYS_Error
        str     x0, [x29, #-24]        // 第１引数 : fd
        mov     x1, xzr                // 第２引数 : offset = 0
        mov     x2, #SEEK_END          // 第３引数 : origin
        mov     x8, #sys_lseek         // ファイルサイズを取得
        svc     #0

        mov     x3, x0                 // file_size 退避
        ldr     x0, [x29, #-24]        // 第１引数 : fd
        mov     x1, xzr                // 第２引数 : offset=0
        mov     x2, x1                 // 第３引数 : origin=0
        mov     x8, #sys_lseek         // ファイル先頭にシーク
        svc     #0

        mov     x0, #'{'               // 格納領域先頭
        ldr     x1, [x29, x0,LSL #3]   // バッファ指定
        mov     x0, #')'
        str     x3, [x29, x0,LSL #3]   // 読み込みサイズ設定
        add     x2, x1, x3             // 最終アドレス計算
        mov     x0, #'}'
        str     x2, [x29, x0,LSL #3]   // 格納領域最終設定
        mov     x0, #'*'
        ldr     x3, [x29, x0,LSL #3]   // RAM末
        cmp     x3, x1
        blo     3f                     // x3<x1 領域不足エラー

        ldr     x0, [x29, #-24]        // FileDescW
        mov     x8, #sys_read          // ファイル全体を読みこみ
        svc     #0
        mov     x2, x0
        ldr     x0, [x29, #-24]        // FileDescW
        bl      fclose
        tst     x2, x2                 // Read Error
        bmi     SYS_Error
    3: // exit
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// 終了
//-------------------------------------------------------------------------
Com_Exit:       //   7E  ~  VTL終了
        bl      RESTORE_TERMIOS
        bl      SET_TERMIOS2            // test
        b       Exit

//-------------------------------------------------------------------------
// ユーザ拡張コマンド処理
//-------------------------------------------------------------------------
Com_Ext:
        stp     x0, x30, [sp, #-16]!
.ifndef SMALL_VTL
.include        "ext.s"
func_err:
//        b       pop_and_Error
.endif
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// ForkExec , 外部プログラムの実行
//-------------------------------------------------------------------------
Com_Exec:
.ifndef SMALL_VTL
        stp     x0, x30, [sp, #-16]!
        bl      GetChar                // skip =
        cmp     xv1, #'*
        bne     0f
        bl      SkipEqualExp
        bl      GetString2
        b       3f
    0:  bl      GetChar                // skip double quote
        cmp     xv1, #'"'              // "
        beq     1f
        sub     xv3, xv3, #1           // ungetc 1文字戻す
    1:
        bl      GetString              // 外部プログラム名取得
//        adr     x0, FileName           // ファイル名表示
//        bl      OutAsciiZ
//        bl      NewLine

    3:
        stp     xv1, xv2, [sp, #-16]!
        stp     xv3, xv4, [sp, #-16]!
        bl      ParseArg               // コマンド行の解析
//        bl      CheckParseArg
        mov     xv2, x1                // リダイレクト先ファイル名
        add     x7, x3, #1             // 子プロセスの数
        adr     xv7, exarg             // char ** argp
        mov     xv4, xzr               // 先頭プロセス
        cmp     x7, #1
        bhi     2f                     // パイプが必要

        // パイプ不要な子プロセスを1つだけ生成
        mov     x0, SIGCHLD            // clone_flags
        mov     x1, xzr                // newsp
        mov     x2, xzr                // parent_tidptr
        mov     x3, xzr                // child_tidptr
        mov     x4, xzr                // tls_val
        mov     x8, #sys_clone         // as sys_fork
        svc     #0
        bl      CheckError
        tst     x0, x0
        beq     child                  // pid が 0 なら子プロセスの処理
        b       6f                     // 親は子プロセス終了を待つ処理へ

    2:  // パイプが必要な子プロセスを2つ以上生成する
        adr     xv3, ipipe             // パイプをオープン
        mov     x0, xv3                // xv3 に pipe_fd 配列先頭
        mov     x1, xzr                // flag = 0
        mov     x8, #sys_pipe2         // pipe システムコール
        svc     #0
        bl      CheckError

        //------------------------------------------------------------
        // fork
        //------------------------------------------------------------
        mov     x0, SIGCHLD            // clone_flags
        mov     x1, xzr                // newsp
        mov     x2, xzr                // parent_tidptr
        mov     x3, xzr                // child_tidptr
        mov     x4, xzr                // tls_val
        mov     x8, #sys_clone         // as sys_fork
        svc     #0
        tst     x0, x0
        beq     child                  // pid が 0 なら子プロセスの処理

        //------------------------------------------------------------
        // 親プロセス側の処理
        //------------------------------------------------------------
        tst     xv4, xv4               // 先頭プロセスか?
        beq     3f
        bl      close_old_pipe         // 先頭でなければパイプクローズ
    3:  ldr     wip, [xv3]             // パイプ fd の移動
        str     wip, [xv3, #+8]        // 直前の子プロセスのipipe
        ldr     wip, [xv3, #+4]
        str     wip, [xv3, #+12]       // 直前の子プロセスのopipe
        subs    x7, x7, #1             // 残り子プロセスの数
        beq     5f                     // 終了

    4:  add     xv7, xv7, #8           // 次のコマンド文字列探索
        ldr     xip, [xv7]
        cbnz    xip, 4b                // コマンド区切りを探す
        add     xv7, xv7, #8           // 次のコマンド文字列設定
        add     xv4, xv4, #1           // 次は先頭プロセスではない
        b       2b                     // 次の子プロセス生成

    5:  bl      close_new_pipe         //

    6:  // 子プロセスの終了を待つ x0=最後に起動した子プロセスのpid
        adr     x1, stat_addr
        mov     x2, #WUNTRACED         // WNOHANG
        adr     x3, ru                 // rusage
        mov     x8, #sys_wait4         // システムコール
        svc     #0
        bl      CheckError
        bl      SET_TERMIOS            // 子プロセスの設定を復帰
        ldp     xv3, xv4, [sp], #16
        ldp     xv1, xv2, [sp], #16
        ldp     x0, x30,  [sp], #16
        ret

        //------------------------------------------------------------
        // 子プロセス側の処理、 execveを実行して戻らない
        //------------------------------------------------------------
child:
        bl      RESTORE_TERMIOS
        subs    x7, x7, #1             // 最終プロセスチェック
        bne     pipe_out               // 最終プロセスでない
        tst     xv2, xv2               // リダイレクトがあるか
        beq     pipe_in                // リダイレクト無し, 標準出力
        mov     x0, xv2                // リダイレクト先ファイル名
        bl      fwopen                 // x0 = オープンした fd
        mov     xip, x0
        mov     x1, #1                 // 標準出力をファイルに差替え
        mov     x2, xzr                // flag = 0
        mov     x8, #sys_dup3          // dup2 システムコール
        svc     #0
        bl      CheckError
        mov     x0, xip
        bl      fclose                 // x0 にはオープンしたfd
        b       pipe_in

pipe_out:                              // 標準出力をパイプに
        ldr     w0, [xv3, #+4]         // 新パイプの書込み fd
        mov     x1, #1                 // 標準出力
        mov     x2, xzr                // flag = 0
        mov     x8, #sys_dup3          // dup2 システムコール
        svc     #0
        bl      CheckError
        bl      close_new_pipe

pipe_in:
        tst     xv4, xv4               // 先頭プロセスならスキップ
        beq     execve
                                       // 標準入力をパイプに
        ldr     w0, [xv3, #+8]         // 前のパイプの読出し fd
        mov     x1, xzr                // new_fd 標準入力
        mov     x2, xzr                // flag = 0
        mov     x8, #sys_dup3          // dup2 システムコール
        svc     #0
        bl      CheckError
        bl      close_old_pipe

execve:
        ldr     x0, [xv7]              // char * filename exarg[n]
        mov     x1, xv7                // char **argp     exarg+n
        adr     x2, envp               // char ** envp
        mov     x8, #sys_execve        // システムコール
        svc     #0
        bl      CheckError             // 正常ならここには戻らない
        bl      Exit                   // 単なる飾り

close_new_pipe:
        stp     x0, x30, [sp, #-16]!
        ldr     w0, [xv3, #+4]         // 出力パイプをクローズ
        bl      fclose
        ldr     w0, [xv3]              // 入力パイプをクローズ
        bl      fclose
        ldp     x0, x30, [sp], #16
        ret

close_old_pipe:
        stp     x0, x30, [sp, #-16]!
        ldr     w0, [xv3, #+12]        // 出力パイプをクローズ
        bl      fclose
        ldr     w0, [xv3, #+8]         // 入力パイプをクローズ
        bl      fclose
        ldp     x0, x30, [sp], #16
.endif
        ret


//-------------------------------------------------------------------------
// デバッグ用
//-------------------------------------------------------------------------
CheckParseArg:
        stp     x0, x30, [sp, #-16]!
        stp     x1, x2,  [sp, #-16]!
        stp     x3, x4,  [sp, #-16]!
        tst     x1, x1
        beq     0f
        mov     x0, x1
        bl      OutAsciiZ
        bl      NewLine
    0:
        mov     x1, xzr                // 配列インデックス
        adr     x2, exarg              // 配列先頭
    1:
        ldr     x4, [x2, x1,LSL #3]
        tst     x4, x4
        beq     2f

        mov     x0, x1
        bl      PrintLeft
        mov     x0, x4
        bl      OutAsciiZ
        bl      NewLine
        add     x1, x1, #1
        b       1b
    2:
        tst     x3, x3
        beq     3f
        add     x1, x1, #1
        sub     x3, x3, #1
        b       1b
    3:
        ldp     x3, x4,  [sp], #16
        ldp     x1, x2,  [sp], #16
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// execve 用の引数を設定
// コマンド文字列のバッファ FileName をAsciiZに変換してポインタの配列に設定
// x3 に パイプの数 (子プロセス数-1) を返す．x0 保存
// x1 にリダイレクト先ファイル名文字列へのポインタを返す．
//-------------------------------------------------------------------------
ParseArg:
        stp     x0, x30, [sp, #-16]!
        stp     xv2, xv3, [sp, #-16]!
        mov     x2, xzr                // 配列インデックス
        mov     x3, xzr                // パイプのカウンタ
        mov     x1, xzr                // リダイレクトフラグ
        adr     xv3, FileName          // コマンド文字列のバッファ
        adr     xv2, exarg             // ポインタの配列先頭
    1:
        ldrb    w0, [xv3]              // 連続する空白のスキップ
        tst     w0, w0                 // 行末チェック
        beq     pa_exit
        cmp     x0, #' '
        bne     2f                     // パイプのチェックへ
        add     xv3, xv3, #1           // 空白なら次の文字
        b       1b

    2:  cmp     x0, #'|'               // パイプ?
        bne     3f
        add     x3, x3, #1             // パイプのカウンタ+1
        bl      end_mark               // null pointer書込み
        b       6f

    3:  cmp     x0, #'>'               // リダイレクト?
        bne     4f
        mov     x1, #1                 // リダイレクトフラグ
        bl      end_mark               // null pointer書込み
        b       6f

    4:  str     xv3, [xv2, x2,LSL #3]  // 引数へのポインタを登録
        add     x2, x2, #1             // 配列インデックス+1

    5:  ldrb    w0, [xv3]              // 空白を探す
        tst     w0, w0                 // 行末チェック
        beq     7f                     // 行末なら終了
        cmp     x0, #' '
        beq     8f
        add     xv3, xv3, #1
        b       5b                     // 空白でなければ次の文字
    8:  mov     x0, xzr
        strb    w0, [xv3]              // スペースを 0 に置換
        tst     x1, x1                 // リダイレクトフラグ
        bne     7f                     // > の後ろはファイル名のみ

    6:  add     xv3, xv3, #1
        cmp     x2, #ARGMAX            // 個数チェックして次
        bhs     pa_exit
        b       1b

    7:  tst     x1, x1                 // リダイレクトフラグ
        beq     pa_exit
        sub     x2, x2, #1
        ldr     x1, [xv2, x2,LSL #3]
        add     x2, x2, #1
pa_exit:
        mov     x0, xzr
        str     x0, [xv2, x2,LSL #3]   // 引数ポインタ配列の最後
        ldp     xv2, xv3, [sp], #16
        ldp     x0, x30, [sp], #16
        ret

end_mark:
        mov     x0, xzr
        str     x0, [xv2, x2,LSL #3]   // コマンドの区切り NullPtr
        add     x2, x2, #1             // 配列インデックス
        ret

//-------------------------------------------------------------------------
// 組み込みコマンドの実行
//-------------------------------------------------------------------------
Com_Function:
.ifndef SMALL_VTL
        stp     x0, x30, [sp, #-16]!
        bl      GetChar             // | の次の文字
func_c:
        cmp     xv1, #'c'
        bne     func_d
        bl      def_func_c          // |c
        ldp     x0, x30, [sp], #16
        ret
func_d:
func_e:
        cmp     xv1, #'e'
        bne     func_f
        bl      def_func_e          // |e
        ldp     x0, x30, [sp], #16
        ret
func_f:
        cmp     xv1, #'f'
        bne     func_l
        bl      def_func_f          // |f
        ldp     x0, x30, [sp], #16
        ret
func_l:
        cmp     xv1, #'l'
        bne     func_m
        bl      def_func_l          // |l
        ldp     x0, x30, [sp], #16
        ret
func_m:
        cmp     xv1, #'m'
        bne     func_n
        bl      def_func_m          // |m
        ldp     x0, x30, [sp], #16
        ret
func_n:
func_p:
        cmp     xv1, #'p'
        bne     func_q
        bl      def_func_p          // |p
        ldp     x0, x30, [sp], #16
        ret
func_q:
func_r:
        cmp     xv1, #'r'
        bne     func_s
        bl      def_func_r          // |r
        ldp     x0, x30, [sp], #16
        ret
func_s:
        cmp     xv1, #'s'
        bne     func_t
        bl      def_func_s          // |s
        ldp     x0, x30, [sp], #16
        ret
func_t:
func_u:
        cmp     xv1, #'u'
        bne     func_v
        bl      def_func_u          // |u
        ldp     x0, x30, [sp], #16
        ret
func_v:
        cmp     xv1, #'v'
        bne     func_z
        bl      def_func_v          // |u
        ldp     x0, x30, [sp], #16
        ret
func_z:
        cmp     xv1, #'z'
        bne     pop_and_Error
        bl      def_func_z          // |z
        ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// 組み込み関数用メッセージ
//-------------------------------------------------------------------------
                .align  2
    msg_f_ca:   .asciz  ""
                .align  2
    msg_f_cd:   .asciz  "Change Directory to "
                .align  2
    msg_f_cm:   .asciz  "Change Permission \n"
                .align  2
    msg_f_cr:   .asciz  "Change Root to "
                .align  2
    msg_f_cw:   .asciz  "Current Working Directory : "
                .align  2
    msg_f_ex:   .asciz  "Exec Command\n"
                .align  2
//-------------------------------------------------------------------------

//------------------------------------
// |c で始まる組み込みコマンド
//------------------------------------
def_func_c:
        stp     x0, x30, [sp, #-16]!
        bl      GetChar             //
        cmp     xv1, #'a'
        beq     func_ca             // cat
        cmp     xv1, #'d'
        beq     func_cd             // cd
        cmp     xv1, #'m'
        beq     func_cm             // chmod
        cmp     xv1, #'r'
        beq     func_cr             // chroot
        cmp     xv1, #'w'
        beq     func_cw             // pwd
        b       pop2_and_Error
func_ca:
        adr     x0, msg_f_ca        // |ca file
        bl      FuncBegin
        ldr     x0, [x1]            // filename
        bl      DispFile
        ldp     x0, x30, [sp], #16
        ret
func_cd:
        adr     x0, msg_f_cd        // |cd path
        bl      FuncBegin
        ldr     x1, [x1]            // char ** argp
        adr     x0, FileName
        bl      OutAsciiZ
        bl      NewLine
        mov     x8, #sys_chdir      // システムコール
        svc     #0
        bl      CheckError
        ldp     x0, x30, [sp], #16
        ret
func_cm:
        adr     x0, msg_f_cm        // |cm 644 file
        bl      FuncBegin
        ldr     x0, [x1, #8]        // file name
        ldr     x1, [x1]            // permission
        bl      Oct2Bin
        mov     x1, x0
        mov     x8, #sys_chmod      // システムコール
        svc     #0
        bl      CheckError
        ldp     x0, x30, [sp], #16
        ret
func_cr:
        adr     x0, msg_f_cr        // |cr path
        bl      FuncBegin
        ldr     x1, [x1]            // char ** argp
        adr     x0, FileName
        bl      OutAsciiZ
        bl      NewLine
        mov     x8, #sys_chroot     // システムコール
        svc     #0
        bl      CheckError
        ldp     x0, x30, [sp], #16
        ret
func_cw:
        adr     x0, msg_f_cw        // |cw
        bl      OutAsciiZ
        adr     x0, FileName
        mov     x3, x0              // save x0
        mov     x1, #FNAMEMAX
        mov     x8, #sys_getcwd     // システムコール
        svc     #0
        bl      CheckError
        mov     x0, x3              // restore x0
        bl      OutAsciiZ
        bl      NewLine
        ldp     x0, x30, [sp], #16
        ret

//------------------------------------
// |e で始まる組み込みコマンド
//------------------------------------
def_func_e:
        stp     x0, x30, [sp, #-16]!
        bl      GetChar             //
        cmp     xv1, #'x'
        beq     func_ex             // execve
        b       pop2_and_Error
func_ex:
        adr     x0, msg_f_ex        // |ex file arg ..
        bl      RESTORE_TERMIOS     // 端末設定を戻す
        bl      FuncBegin           // x1: char ** argp
        ldr     x0, [x1]            // char * filename
        adr     x2, exarg           //
        ldr     x2, [x2, #-24]      // char ** envp
        mov     x8, #sys_execve     // システムコール
        svc     #0
        bl      CheckError          // 正常ならここには戻らない
        bl      SET_TERMIOS         // 端末のローカルエコーをOFF
        ldp     x0, x30, [sp], #16
        ret

//------------------------------------
// |f で始まる組み込みコマンド
//------------------------------------
def_func_f:
.ifdef FRAME_BUFFER
.include        "vtlfb.s"
.endif

//------------------------------------
// |l で始まる組み込みコマンド
//------------------------------------
def_func_l:
        stp     x0, x30, [sp, #-16]!
        bl      GetChar                //
        cmp     xv1, #'s'
        beq     func_ls                // ls
        b       pop2_and_Error

func_ls:
        adr     x0, msg_f_ls           // |ls dir
        bl      FuncBegin
        ldr     x2, [x1]
        tst     x2, x2
        bne     1f
        adr     x2, current_dir        // dir 指定なし
    1:  adr     x3, DirName
        mov     x0, x3
    2:  ldrb    wip, [x2], #1          // dir をコピー
        strb    wip, [x3], #1
        tst     wip, wip
        bne     2b
        ldrb    wip, [x3, #-2]         // dir末の/をチェック
        mov     w2, #'/'
        cmp     wip, w2
        beq     3f                     // / 有
        strb    w2, [x3, #-1]          // / 書き込み
        mov     x2, xzr
        strb    w2, [x3]               // end mark
    3:
        bl      fropen
        bmi     6f                     // エラーチェックして終了
        stp     xv1, xv2, [sp, #-16]!
        stp     xv3, x25, [sp, #-16]!  // x25 = rv6
        mov     xv2, x0                // fd 保存
        adr     x25, DirName           // for GetFileStat (rv6)
    4:  // ディレクトリエントリ取得
        // unsigned int fd, void * dirent, unsigned int count
        mov     x0, xv2                // fd 再設定
        adr     x1, dir_ent            // バッファ先頭
        mov     xv1, x1                // xv1 : struct top (dir_ent)
        mov     x2, #size_dir_ent
        mov     x8, #sys_getdents64    // システムコール
        svc     #0
        tst     x0, x0                 // valid buffer length
        bmi     6f
        beq     7f
        mov     x3, x0                 // x3 : buffer size

    5:  // dir_entからファイル情報を取得
        mov     x1, xv1                // xv1 : dir_ent
        bl      GetFileStat            // x1:dir_entアドレス
        adr     x2, file_stat
        ldrh    w0, [x2, #+16]         // file_stat.st_mode
        mov     x1, #6
        bl      PrintOctal             // mode
        ldr     x0, [x2, #+48]         // file_stat.st_size
        mov     x1, #12
        bl      PrintRight             // file size
        mov     x0, #' '
        bl      OutChar
        add     x0, xv1, #19           // dir_ent.filename
        bl      OutAsciiZ              // filename
        bl      NewLine
        ldrh    w0, [xv1, #+16]        // record length
        subs    x3, x3, x0             // バッファの残り
        beq     4b                     // 次のディレクトリエントリ取得
        add     xv1, xv1, x0           // 次のdir_ent
        b       5b

    6:  bl      CheckError
    7:  mov     x0, xv2                // fd
        bl      fclose
        ldp     xv3, x25, [sp], #16
        ldp     xv1, xv2, [sp], #16
        ldp     x0, x30, [sp], #16
        ret

//------------------------------------
// |m で始まる組み込みコマンド
//------------------------------------
def_func_m:
         stp     x0, x30, [sp, #-16]!
         bl      GetChar            //
         cmp     xv1, #'d'
         beq     func_md            // mkdir
         cmp     xv1, #'o'
         beq     func_mo            // mo
         cmp     xv1, #'v'
         beq     func_mv            // mv
         b       pop2_and_Error

func_md:
        adr     x0, msg_f_md        // |md dir [777]
        bl      FuncBegin
        ldr     x0, [x1, #4]        // permission
        ldr     x1, [x1]            // directory name
        tst     x0, x0
        bne     1f
        ldr     w0, c755
        b       2f
    1:  bl      Oct2Bin
    2:  mov     x1, x0
        mov     x8, #sys_mkdir      // システムコール
        svc     #0
        bl      CheckError
        ldp     x0, x30, [sp], #16
        ret

c755:   .long   0755

func_mo:
        adr     x0, msg_f_mo        // |mo dev_name dir fstype
        bl      FuncBegin
        mov     x4, x1              // exarg
        ldr     x0, [x4]            // dev_name
        ldr     x1, [x4, #+8]       // dir_name
        ldr     x2, [x4, #+16]      // fstype
        ldr     x3, [x4, #+24]      // flags
        tst     x3, x3              // Check ReadOnly
        beq     1f                  // Read/Write
        ldr     x3, [x3]
        mov     x3, #MS_RDONLY      // ReadOnly FileSystem
    1:
        mov     x4, xzr             // void * data
        mov     x8, #sys_mount      // システムコール
        svc     #0
        bl      CheckError
        ldp     x0, x30, [sp], #16
       ret
func_mv:
        adr     x0, msg_f_mv        // |mv fileold filenew
        bl      FuncBegin
        ldr     x0, [x1]
        ldr     x1, [x1, #8]
        mov     x8, #sys_rename     // システムコール
        svc     #0
        bl      CheckError
        ldp     x0, x30, [sp], #16
       ret

//------------------------------------
// |p で始まる組み込みコマンド
//------------------------------------
def_func_p:
        stp     x0, x30, [sp, #-16]!
        bl      GetChar             //
        cmp     xv1, #'v'
        beq     func_pv             // pivot_root
        b       pop2_and_Error

func_pv:
        adr     x0, msg_f_pv        // |pv /dev/hda2 /mnt
        bl      FuncBegin
        ldr     x0, [x1]
        ldr     x1, [x1, #8]
        mov     x8, #sys_pivot_root // システムコール
        svc     #0
        bl      CheckError
        ldp     x0, x30, [sp], #16
       ret

//------------------------------------
// |r で始まる組み込みコマンド
//------------------------------------
def_func_r:
        stp     x0, x30, [sp, #-16]!
        bl      GetChar             //
        cmp     xv1, #'d'
        beq     func_rd             // rmdir
        cmp     xv1, #'m'
        beq     func_rm             // rm
        cmp     xv1, #'t'
        beq     func_rt             // rt
        b       pop2_and_Error

func_rd:
        adr     x0, msg_f_rd        // |rd path
        bl      FuncBegin           // char ** argp
        ldr     x0, [x1]
        mov     x8, #sys_rmdir      // システムコール
        svc     #0
        bl      CheckError
        ldp     x0, x30, [sp], #16
        ret

func_rm:
        adr     x0, msg_f_rm        // |rm path
        bl      FuncBegin           // char ** argp
        ldr     x1, [x1]
        mov     x0, AT_FDCWD
        mov     x2, xzr
        mov     x8, #sys_unlinkat   // システムコール
        svc     #0
        bl      CheckError
        ldp     x0, x30, [sp], #16
        ret

AT_FDCWD =  -100

func_rt:                            // reset terminal
        adr     x0, msg_f_rt        // |rt
        bl      OutAsciiZ
        bl      SET_TERMIOS2        // cooked mode
        bl      GET_TERMIOS         // termios の保存
        bl      SET_TERMIOS         // raw mode
        ldp     x0, x30, [sp], #16
        ret

//------------------------------------
// |s で始まる組み込みコマンド
//------------------------------------
def_func_s:
        stp     x0, x30, [sp, #-16]!
        bl      GetChar                //
        cmp     xv1, #'f'
        beq     func_sf                // swapoff
        cmp     xv1, #'o'
        beq     func_so                // swapon
        cmp     xv1, #'y'
        beq     func_sy                // sync
        b       pop2_and_Error

func_sf:
        adr     x0, msg_f_sf           // |sf dev_name
        bl      FuncBegin              // const char * specialfile
        ldr     x0, [x1]
        mov     x8, #sys_swapoff       // システムコール
        svc     #0
        bl      CheckError
        ldp     x0, x30, [sp], #16
        ret

func_so:
        adr     x0, msg_f_so           // |so dev_name
        bl      FuncBegin
        ldr     x0, [x1]               // const char * specialfile
        mov     x1, xzr                // int swap_flags
        mov     x8, #sys_swapon        // システムコール
        svc     #0
        bl      CheckError
        ldp     x0, x30, [sp], #16
        ret

func_sy:
        adr     x0, msg_f_sy           // |sy
        mov     x8, #sys_sync          // システムコール
        svc     #0
        bl      CheckError
        ldp     x0, x30, [sp], #16
        ret

//------------------------------------
// |u で始まる組み込みコマンド
//------------------------------------
def_func_u:
        stp     x0, x30, [sp, #-16]!
        bl      GetChar                //
        cmp     xv1, #'m'
        beq     func_um                // umount
        cmp     xv1, #'d'
        beq     func_ud                // URL Decode
        b       pop2_and_Error

func_um:
        adr     x0, msg_f_um           // |um dev_name
        bl      FuncBegin              //
        ldr     x0, [x1]               // dev_name
        mov     x8, #sys_umount        // sys_oldumount システムコール
        svc     #0
        bl      CheckError
        ldp     x0, x30, [sp], #16
        ret

func_ud:
        mov     x0, #'u'
        ldr     xip, [x29, x0,LSL #3]  // 引数は u[0] - u[3]
        ldr     x0, [xip]              // x0 にURLエンコード文字列の先頭設定
        ldr     x1, [xip, #8]          // x1 に変更範囲の文字数を設定
        ldr     x2, [xip, #16]         // x2 にデコード後の文字列先頭を設定
        bl      URL_Decode
        str     x0, [xip, #24]         // デコード後の文字数を設定
        ldp     x0, x30, [sp], #16
        ret

//------------------------------------
// |v で始まる組み込みコマンド
//------------------------------------
def_func_v:
        stp     x0, x30, [sp, #-16]!
        bl      GetChar                //
        cmp     xv1, #'e'
        beq     func_ve                // version
        cmp     xv1, #'c'
        beq     func_vc                // cpu
        b       pop2_and_Error

func_ve:
        ldr     w3, version
        mov     x0, #'%'
        add     x1, x29, x0, LSL #3
        str     w3, [x1]               // バージョン設定
        mov     w3, VERSION64
        str     w3, [x1, #4]           // 64bit
        ldp     x0, x30, [sp], #16
        ret
func_vc:
        mov     x3, CPU
        mov     x0, #'%'
        str     x3, [x29, x0,LSL #3]   // cpu
        ldp     x0, x30, [sp], #16
        ret

version:
        .long   VERSION

//------------------------------------
// |zz システムコール
//------------------------------------
def_func_z:
        stp     x0, x30, [sp, #-16]!
        bl      GetChar                //
        cmp     xv1, #'c'
        beq     func_zc                //
        cmp     xv1, #'z'
        beq     func_zz                // system bl
        b       pop2_and_Error

func_zc:
        adr     x1, counter
                                ldr     x3, [x1]
        mov     x0, #'%'
        str     x3, [x29, x0,LSL #3]   // cpu
        ldp     x0, x30, [sp], #16
        ret

func_zz:
        bl      GetChar                // skip space
        bl      SystemCall
        bl      CheckError
        ldp     x0, x30, [sp], #16
        ret

//---------------------------------------------------------------------
// xv6 の文字が16進数字かどうかのチェック
// 数字なら整数に変換して xv6 に返す. 非数字ならキャリーセット
//---------------------------------------------------------------------

IsNum2: cmp     xv6, #'0'              // 0 - 9
        bcs     1f
        mov     x0, #0x29000000        // set carry xv6<'0'
        msr     nzcv, x0
        ret
    1:  cmp     xv6, #':'              // set carry xv6>'9'
        bcs     2f
        sub   xv6, xv6, #'0            // 整数に変換 Cy=0
    2:  ret

IsHex:
        stp     x0, x30, [sp, #-16]!
        bl      IsHex1                 // 英大文字か?
        bcc     1f
        bl      IsHex2                 // 英小文字か?
    1:
        bcs     2f
        add     xv6, xv6, #10
    2:  ldp     x0, x30, [sp], #16
        ret

IsHex1:
        cmp     xv6, #'A               // 英大文字(A-Z)か?
        bcs     1f
        mov     x0, #0x29000000        // if xv6<'A' Cy=1
        msr     nzcv, x0
        ret
    1:  cmp     xv6, #'F+1             // if xv6>'F' Cy=1
        bcs     2f
        sub     xv6, xv6, #'A          // yes
    2:  ret

IsHex2:
        cmp     xv6, #'a               // 英小文字(a-z)か?
        bcs     1f
        mov     x0, #0x29000000        // if xv6<'a' Cy=1
        msr     nzcv, x0
        ret
    1:  cmp     xv6, #'f+1             // if xv6>'f' Cy=1
        bcs     2f
        sub     xv6, xv6, #'a          // yes
    2:  ret

IsHexNum:
        stp     x0, x30, [sp, #-16]!
        bl      IsHex                  // 英文字か?
        bcc     1f                     // yes
        bl      IsNum2                 // 数字か?
    1:  ldp     x0, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// URLデコード
//
// x0 にURLエンコード文字列の先頭設定
// x1 に変更範囲の文字数を設定
// x2 にデコード後の文字列先頭を設定
// x0 にデコード後の文字数を返す
//-------------------------------------------------------------------------
URL_Decode:
        stp     xv8, x30, [sp, #-16]!
        stp     xv6, xv7, [sp, #-16]!
        stp     xv4, xv5, [sp, #-16]!
        add     xv7, x0, x1
        sub     xv7, xv7, #1
        mov     xv4, xzr
    1:
        ldrb    wv5, [x0], #1
        cmp     xv5, #'+
        bne     2f
        mov     xv5, #' '
        strb    wv5, [x2, xv4]
        b       4f
    2:  cmp     xv5, #'%
        beq     3f
        strb    wv5, [x2, xv4]
        b       4f
    3:
        mov     xv5, xzr
        ldrb    wv6, [x0], #1
        bl      IsHexNum
        bcs     4f
        add     xv5, xv5, xv6
        ldrb    wv6, [x0], #1
        bl      IsHexNum
        bcs     4f
        lsl     xv5, xv5, #4
        add     xv5, xv5, xv6
        strb    wv5, [x2, xv4]
    4:
        add     xv4, xv4, #1
        cmp     x0, xv7
        ble     1b

        mov     xv5, xzr
        strb    wv5, [x2, xv4]
        mov     x0, xv4                // 文字数を返す
        ldp     xv4, xv5, [sp], #16
        ldp     xv6, xv7, [sp], #16
        ldp     xv8, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// 組み込み関数用
//-------------------------------------------------------------------------
FuncBegin:
        stp     x0, x30, [sp, #-16]!
        bl      OutAsciiZ
        bl      GetChar                // get *
        cmp     xv1, #'*
        bne     1f
        bl      SkipEqualExp           // x0 にアドレス
        mov     x2, xv4                // xv4退避
        mov     xv4, x0                // RangeCheckはxv4を見る
        bl      RangeCheck             // コピー先を範囲チェック
        mov     xv4, x2                // コピー先復帰
        bcs     4f                     // 範囲外をアクセス
        bl      GetString2             // FileNameにコピー
        b       3f
    1:  ldrb    wip, [xv3]
        cmp     wip, #'"'
        bne     2f
        bl      GetChar                // skip "
    2:  bl      GetString              // パス名の取得
    3:  bl      ParseArg               // 引数のパース
        adr     x1, exarg
        ldp     x0, x30, [sp], #16
        ret
    4:  mov     xv1, #0xFF             // エラー文字を FF
        b       LongJump               // アクセス可能範囲を超えた

//-------------------------------------------------------------------------
// 8進数文字列を数値に変換
// x0 からの8進数文字列を数値に変換して x1 に返す
//-------------------------------------------------------------------------
Oct2Bin:
        stp     x2, x30, [sp, #-16]!
        bl      GetOctal               // x1
        bhi     2f                     // exit
        mov     x2, x1
    1:
        bl      GetOctal
        bhi     2f
        add     x2, x2, x1, LSL#3
        b       1b
    2:
        mov     x1, x2
        ldp     x2, x30, [sp], #16
        ret

//-------------------------------------------------------------------------
// x2 の示す8進数文字を数値に変換して x1 に返す
// 8進数文字でないかどうかは bhiで判定可能
//-------------------------------------------------------------------------
GetOctal:
        ldrb    w1, [x0], #1
        sub     x1, x1, #'0
        cmp     x1, #7
        ret

//-------------------------------------------------------------------------
// ファイル内容表示
// x0 にファイル名
//-------------------------------------------------------------------------
DispFile:
        stp     x7, x30, [sp, #-16]!
        bl      fropen                 // open
        bl      CheckError
        bmi     3f
        mov     x7, x0                 // FileDesc
        mov     x2, #16                // read 16 byte
        sub     sp, sp, #16
        mov     x1, sp                 // x1  address
    1:
        mov     x0, x7                 // x0  fd
        mov     x8, #sys_read
        svc     #0
        bl      CheckError
        tst     x0, x0
        beq     2f
        mov     x2, x0                 // x2  length
        mov     x0, #1                 // x0  stdout
        mov     x8, #sys_write
        svc     #0
        b       1b
    2:
        mov     x0, x7
        bl      fclose
        add     sp, sp, #16
    3:  ldp     x7, x30, [sp], #16
.endif                                 // .ifndef SMALL_VTL
        ret

//==============================================================
.data
                .align  3
n672274774:     .quad   672274774
mem_init:       .quad   MEMINIT

.ifndef SMALL_VTL
                .align   3
start_msg:      .ascii   "RVTL64 Arm64 v.4.01 2015/10/05,(C)2015 Jun Mizutani\n"
                .ascii   "RVTL may be copied under the terms of the GNU "
                .asciz   "General Public License.\n"
                .align   3
.endif

                .align   3
initvtl:        .asciz   "/etc/init.vtl"
                .align   3
cginame:        .asciz   "wltvr"
                .align   3
err_div0:       .asciz   "\nDivided by 0!\n"
                .align   3
err_label:      .asciz   "\nLabel not found!\n"
                .align   3
err_vstack:     .asciz   "\nEmpty stack!\n"
                .align   3
err_exp:        .asciz   "\nError in Expression at line "
                .align   3
envstr:         .asciz   "PATH=/bin:/usr/bin"
                .align   3
prompt1:        .asciz   "\n<"
                .align   3
prompt2:        .asciz   "> "
                .align   3
syntaxerr:      .asciz   "\nSyntax error! at line "
                .align   3
stkunder:       .asciz   "\nStack Underflow!\n"
                .align   3
stkover:        .asciz   "\nStack Overflow!\n"
                .align   3
vstkunder:      .asciz   "\nVariable Stack Underflow!\n"
                .align   3
vstkover:       .asciz   "\nVariable Stack Overflow!\n"
                .align   3
Range_msg:      .asciz   "\nOut of range!\n"
                .align   3
no_direct_mode: .asciz   "\nDirect mode is not allowed!\n"
                .align   3

//-------------------------------------------------------------------------
// 組み込み関数用メッセージ
//-------------------------------------------------------------------------
    msg_f_ls:   .asciz  "List Directory\n"
                .align  2
    msg_f_md:   .asciz  "Make Directory\n"
                .align  2
    msg_f_mv:   .asciz  "Change Name\n"
                .align  2
    msg_f_mo:   .asciz  "Mount\n"
                .align  2
    msg_f_pv:   .asciz  "Pivot Root\n"
                .align  2
    msg_f_rd:   .asciz  "Remove Directory\n"
                .align  2
    msg_f_rm:   .asciz  "Remove File\n"
                .align  2
    msg_f_rt:   .asciz  "Reset Termial\n"
                .align  2
    msg_f_sf:   .asciz  "Swap Off\n"
                .align  2
    msg_f_so:   .asciz  "Swap On\n"
                .align  2
    msg_f_sy:   .asciz  "Sync\n"
                .align  2
    msg_f_um:   .asciz  "Unmount\n"
                .align  2

//==============================================================
.bss

                .align   3
env:            .quad    0, 0

                .align  3
cgiflag:        .quad   0               // when cgiflag=1, cgi-mode
counter:        .quad   0
save_stack:     .quad   0
current_arg:    .quad   0
argc:           .quad   0
argvp:          .quad   0
envp:           .quad   0               // exarg - #24
argc_vtl:       .quad   0
argp_vtl:       .quad   0
exarg:          .skip   (ARGMAX+1)*8    // execve 用
ipipe:          .long   0               // 0   new_pipe
opipe:          .long   0               // +4
ipipe2:         .long   0               // +8 old_pipe
opipe2:         .long   0               // +12
stat_addr:      .quad   0

                .align  3
input2:         .skip   MAXLINE
FileName:       .skip   FNAMEMAX
pid:            .quad   0               // x29-40
VSTACK:         .quad   0               // x29-32
FileDescW:      .quad   0               // x29-24
FileDesc:       .quad   0               // x29-16
                .align  3
FOR_direct:     .byte   0               // x29-8
ExpError:       .byte   0               // x29-7
ZeroDiv:        .byte   0               // x29-6
SigInt:         .byte   0               // x29-5
ReadFrom:       .byte   0               // x29-4
ExecMode:       .byte   0               // x29-3
EOL:            .byte   0               // x29-2
LSTACK:         .byte   0               // x29-1
                .align  3
VarArea:        .skip   256*8           // x29 後半128dwordはLSTACK用
VarStack:       .skip   VSTACKMAX*8     // x29+2048

.ifdef VTL_LABEL
                .align  3
LabelTable:     .skip   LABELMAX*32     // 1024*32 bytes
TablePointer:   .quad   0
.endif

