# DN_SuperBook_PDF_Converter インストールガイド (WSL2/Linux)

このドキュメントは WSL2 Ubuntu 22.04 環境でのセットアップ手順を説明します。

## 前提条件

- Ubuntu 22.04 (WSL2)
- NVIDIA GPU (CUDA 対応、RTX 3090 等)
- NVIDIA ドライバがインストール済み

## 1. .NET 8 SDK のインストール

```bash
# Microsoft パッケージリポジトリを追加
wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb

# .NET 8 SDK をインストール
sudo apt-get update
sudo apt-get install -y dotnet-sdk-8.0

# 確認
dotnet --version
```

## 2. システムパッケージのインストール

```bash
sudo apt-get update
sudo apt-get install -y \
    imagemagick \
    ghostscript \
    libimage-exiftool-perl \
    qpdf \
    python3 \
    python3-pip \
    python3-venv \
    libtesseract-dev \
    tesseract-ocr \
    tesseract-ocr-jpn \
    tesseract-ocr-jpn-vert \
    wget \
    curl \
    unzip \
    libgtk2.0-0
```

**注意**: `libgtk2.0-0` は OpenCvSharp のネイティブライブラリが依存しています。

## 3. ImageMagick 設定

### PDF ポリシー解除

ImageMagick はデフォルトで PDF の読み書きが制限されているため、解除が必要です。

```bash
sudo sed -i 's/<policy domain="coder" rights="none" pattern="PDF" \/>/<policy domain="coder" rights="read|write" pattern="PDF" \/>/g' /etc/ImageMagick-6/policy.xml
```

### メモリ/ディスク制限の緩和

大きな PDF (数十ページ以上) を処理する場合、デフォルトのリソース制限では不足します。

```bash
# メモリ制限を 256MB → 4GB に拡大
sudo sed -i 's/name="memory" value="256MiB"/name="memory" value="4GiB"/' /etc/ImageMagick-6/policy.xml

# ディスク制限を 1GB → 16GB に拡大
sudo sed -i 's/name="disk" value="1GiB"/name="disk" value="16GiB"/' /etc/ImageMagick-6/policy.xml
```

## 4. pdfcpu のインストール

```bash
cd external_tools/external_tools/image_tools/pdfcpu

# 最新版をダウンロード (v0.11.1)
curl -sL "https://github.com/pdfcpu/pdfcpu/releases/download/v0.11.1/pdfcpu_0.11.1_Linux_x86_64.tar.xz" -o pdfcpu.tar.xz
tar xJf pdfcpu.tar.xz
mv pdfcpu_*/pdfcpu .
rm -rf pdfcpu_* pdfcpu.tar.xz
chmod +x pdfcpu

# 確認
./pdfcpu version
```

## 5. Tesseract OCR データのコピー

```bash
cp /usr/share/tesseract-ocr/4.00/tessdata/{eng,jpn,jpn_vert,osd}.traineddata \
   external_tools/external_tools/image_tools/TesseractOCR_Data/
```

## 6. RealEsrgan のセットアップ (CUDA 対応)

```bash
cd external_tools/external_tools/image_tools/RealEsrgan
mkdir -p RealEsrgan_Repo
cd RealEsrgan_Repo

# リポジトリをクローン
git clone https://github.com/xinntao/Real-ESRGAN.git .

# シンボリックリンク作成 (コードが Real-ESRGAN/ サブディレクトリを期待するため)
ln -s . Real-ESRGAN

# Python 仮想環境を作成
python3 -m venv venv
source venv/bin/activate

# pip をアップグレード
pip install --upgrade pip

# PyTorch + CUDA 11.8 をインストール
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118

# RealEsrgan 依存関係をインストール (realesrgan は後でローカルからインストール)
pip install basicsr facexlib gfpgan opencv-python numpy

# Real-ESRGAN をローカルからインストール
pip install -e .

# basicsr の torchvision 互換性パッチ (新しい torchvision では functional_tensor が削除されている)
sed -i 's/from torchvision.transforms.functional_tensor import rgb_to_grayscale/from torchvision.transforms.functional import rgb_to_grayscale/' \
    venv/lib/python*/site-packages/basicsr/data/degradations.py

# CUDA 動作確認
python -c "import torch; print('CUDA available:', torch.cuda.is_available())"
```

## 7. プロジェクトのビルド

```bash
cd /path/to/DN_SuperBook_PDF_Converter

# ビルド
dotnet build SuperBookToolsApp/SuperBookToolsApp.csproj

# OpenCvSharp ネイティブライブラリのシンボリックリンクを作成
# (Ubuntu 版ランタイムが ubuntu.22.04-x64 にあるが、.NET は linux-x64 を探すため)
cd SuperBookToolsApp/bin/Debug/net8.0/runtimes/linux-x64/native/
ln -s ../../ubuntu.22.04-x64/native/libOpenCvSharpExtern.so libOpenCvSharpExtern.so
cd -

# 実行
dotnet run --project SuperBookToolsApp/SuperBookToolsApp.csproj
```

## 8. PDF 変換の実行

アプリケーション起動後、プロンプトで以下のコマンドを実行:

```
SuperBookTools> ConvertPdf /path/to/source/pdfs /dst:/path/to/output
```

## トラブルシューティング

### ImageMagick で PDF エラーが出る場合

```bash
# ポリシーファイルを確認
cat /etc/ImageMagick-6/policy.xml | grep PDF

# 制限が残っている場合は手動で編集
sudo nano /etc/ImageMagick-6/policy.xml
# <policy domain="coder" rights="none" pattern="PDF" /> を
# <policy domain="coder" rights="read|write" pattern="PDF" /> に変更
```

### ImageMagick で "cache resources exhausted" エラーが出る場合

大きな PDF を処理するときにメモリ/ディスク制限に達した場合:

```bash
# 現在の制限を確認
cat /etc/ImageMagick-6/policy.xml | grep -E "(memory|disk)"

# メモリとディスク制限を拡大
sudo sed -i 's/name="memory" value="256MiB"/name="memory" value="4GiB"/' /etc/ImageMagick-6/policy.xml
sudo sed -i 's/name="disk" value="1GiB"/name="disk" value="16GiB"/' /etc/ImageMagick-6/policy.xml
```

### CUDA が認識されない場合

```bash
# NVIDIA ドライバの確認
nvidia-smi

# WSL2 で CUDA を使う場合、Windows 側に NVIDIA ドライバが必要
# WSL2 内には CUDA ツールキットのみインストール
```

### OpenCvSharp でエラーが出る場合

```bash
# GTK2 依存ライブラリのインストール (libgtk-x11-2.0.so.0 が見つからない場合)
sudo apt-get install -y libgtk2.0-0

# libOpenCvSharpExtern.so が見つからない場合
cd SuperBookToolsApp/bin/Debug/net8.0/runtimes/linux-x64/native/
ln -s ../../ubuntu.22.04-x64/native/libOpenCvSharpExtern.so libOpenCvSharpExtern.so

# その他の依存ライブラリ
sudo apt-get install -y libgdiplus libc6-dev
```

### basicsr で torchvision エラーが出る場合

```bash
# "No module named 'torchvision.transforms.functional_tensor'" エラーの対処
sed -i 's/from torchvision.transforms.functional_tensor import rgb_to_grayscale/from torchvision.transforms.functional import rgb_to_grayscale/' \
    external_tools/external_tools/image_tools/RealEsrgan/RealEsrgan_Repo/venv/lib/python*/site-packages/basicsr/data/degradations.py
```

## 外部ツールのパス構成

```
external_tools/
└── external_tools/
    └── image_tools/
        ├── pdfcpu/
        │   └── pdfcpu          # Linux バイナリ
        ├── RealEsrgan/
        │   └── RealEsrgan_Repo/
        │       ├── venv/       # Python 仮想環境
        │       └── ...         # RealEsrgan ソースコード
        └── TesseractOCR_Data/
            ├── eng.traineddata
            ├── jpn.traineddata
            └── jpn_vert.traineddata
```

## 注意事項

- RealEsrgan は CUDA なしだと非常に遅くなります (CPU フォールバックは実用的でない)
- メモリ使用量が大きい (数 GB 〜 数十 GB の可能性)
- Windows でも同じソリューションでビルド可能 (OS 判定で自動分岐)
