# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

DN_SuperBook_PDF_Converter は、スキャンした書籍 PDF を高品質化・調整するツール。紙の汚れ、裏写り、インクにじみ、JPEG モアレノイズの除去、傾き補正、ページ番号自動検出・PDF メタデータ設定などを行う。

## ビルド・実行コマンド

```bash
# ビルド (Visual Studio 2022/2026)
# DN_SuperBook_PDF_Converter_VS2026.sln を開いてビルド

# CLI からビルド (dotnet)
dotnet build SuperBookToolsApp/SuperBookToolsApp.csproj

# 実行（デバッグなしで実行を推奨。デバッグありだと重くなる）
dotnet run --project SuperBookToolsApp/SuperBookToolsApp.csproj

# PDF 変換コマンド（プログラム起動後のプロンプトで）
ConvertPdf <srcDir> /dst:<dstDir>

# ヘルプ
ConvertPdf --help
```

## アーキテクチャ

### プロジェクト構成
- **SuperBookToolsApp/** - メインアプリケーション (エントリーポイント、CLI コマンド)
  - `Startup.cs` - Main 関数、ConsoleService によるコマンドループ
  - `AiCommands.cs` - `ConvertPdf` コマンド実装、外部ツールパス設定
- **SuperBookTools/** - 共有ライブラリ (Shared Project)
  - `Basic/SuperPdfUtil.cs` - PDF 処理のコアロジック (約3000行)
- **submodules/IPA-DN-Cores/** - 共通ライブラリ (Cores.NET)

### 主要クラス
- `SuperPdfUtil` - PDF 変換メイン処理 (`PerformPdfAsync`)
- `PnOcrLib` - ページ番号 OCR 検出・書籍メタデータ処理
- `SuperImgUtil` - 画像処理ユーティリティ
- `DnImageSharpHelper` - ImageSharp 拡張メソッド

### 外部ツール依存
`external_tools/external_tools/image_tools/` に配置が必要:
- ImageMagick + Ghostscript
- exiftool
- qpdf
- pdfcpu
- RealEsrgan (Python/CUDA 環境)
- Tesseract OCR データ

### NuGet パッケージ
- OpenCvSharp4 - 画像処理
- SixLabors.ImageSharp.Drawing - 画像描画
- Tesseract - OCR エンジン

## 技術スタック
- C# / .NET 6.0
- IPA-DN-Cores ライブラリ（ファイル操作、コンソールサービス等）
- RealEsrgan (AI 画像鮮明化、Python + CUDA)
- Tesseract OCR (ページ番号検出用)

## 開発メモ
- メモリ使用量が大きい（数GB〜数十GB の可能性）
- GPU (NVIDIA CUDA 対応) が必要（RealEsrgan 処理）
- Windows 向けに開発されているが、C# なので原理的に Linux/macOS 対応可能
