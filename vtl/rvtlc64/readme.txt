------------------------------------------------------------
 rvtlc64.vtl - rvtl Compiler version 1.02

 2010/07/03    Jun Mizutani
------------------------------------------------------------

 32bit版のrvtlコンパイラを rvtl64 用に修正。システムコール
 番号を64bitに合わせました。
 rvtl64で32bit版用の vtl をコンパイルして、32bit の実行ファイル
 を生成します。

 コンパイルするrvtlソースをハイフンの後に指定

  rvtl64 rvtlc64.vtl - to_be_compiled.vtl
  #=1

 例：

  rvtl64 rvtlc64.vtl - rvtlc.vtl
  #=1

  32bit版のrvtlコンパイラの実行ファイルである rvtlc.elf が
  できます。

  詳細は http://www.mztn.org/rvtlc/rvtlc.html または
  http://www.mztn.org/rvtlc/rvtlc_toc.html を参照して下さい。

