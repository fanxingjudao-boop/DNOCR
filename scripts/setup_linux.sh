#!/bin/bash
# DN_SuperBook_PDF_Converter Linux/WSL2 セットアップスクリプト
# CUDA (RTX 3090等) 対応版

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
EXTERNAL_TOOLS_DIR="$PROJECT_ROOT/external_tools/external_tools/image_tools"

echo "========================================"
echo "DN_SuperBook_PDF_Converter Linux Setup"
echo "========================================"

# 1. システムパッケージのインストール
echo ""
echo "[1/5] Installing system packages..."
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
    unzip \
    libgtk2.0-0

# 2. ImageMagick PDF ポリシー設定
# デフォルトでは PDF の読み書きが制限されているので解除
echo ""
echo "[2/5] Configuring ImageMagick PDF policy..."
POLICY_FILE="/etc/ImageMagick-6/policy.xml"
if [ -f "$POLICY_FILE" ]; then
    # PDF 制限を緩和 (コメントアウトまたは削除)
    sudo sed -i 's/<policy domain="coder" rights="none" pattern="PDF" \/>/<policy domain="coder" rights="read|write" pattern="PDF" \/>/g' "$POLICY_FILE"
    echo "ImageMagick PDF policy updated: $POLICY_FILE"
else
    echo "Warning: ImageMagick policy file not found at $POLICY_FILE"
    echo "Trying ImageMagick-7 location..."
    POLICY_FILE="/etc/ImageMagick-7/policy.xml"
    if [ -f "$POLICY_FILE" ]; then
        sudo sed -i 's/<policy domain="coder" rights="none" pattern="PDF" \/>/<policy domain="coder" rights="read|write" pattern="PDF" \/>/g' "$POLICY_FILE"
        echo "ImageMagick PDF policy updated: $POLICY_FILE"
    fi
fi

# 3. pdfcpu Linux バイナリのダウンロード
echo ""
echo "[3/5] Setting up pdfcpu..."
PDFCPU_DIR="$EXTERNAL_TOOLS_DIR/pdfcpu"
mkdir -p "$PDFCPU_DIR"

if [ ! -f "$PDFCPU_DIR/pdfcpu" ]; then
    echo "Downloading pdfcpu for Linux..."
    PDFCPU_VERSION="0.11.1"
    curl -sL "https://github.com/pdfcpu/pdfcpu/releases/download/v${PDFCPU_VERSION}/pdfcpu_${PDFCPU_VERSION}_Linux_x86_64.tar.xz" -o /tmp/pdfcpu.tar.xz
    tar -xJf /tmp/pdfcpu.tar.xz -C /tmp
    mv /tmp/pdfcpu_${PDFCPU_VERSION}_Linux_x86_64/pdfcpu "$PDFCPU_DIR/pdfcpu"
    chmod +x "$PDFCPU_DIR/pdfcpu"
    rm -rf /tmp/pdfcpu.tar.xz /tmp/pdfcpu_${PDFCPU_VERSION}_Linux_x86_64
    echo "pdfcpu installed to: $PDFCPU_DIR/pdfcpu"
else
    echo "pdfcpu already exists, skipping download"
fi

# 4. RealEsrgan Python 仮想環境のセットアップ
echo ""
echo "[4/5] Setting up RealEsrgan venv with CUDA support..."
REALESRGAN_DIR="$EXTERNAL_TOOLS_DIR/RealEsrgan/RealEsrgan_Repo"

if [ -d "$REALESRGAN_DIR" ]; then
    cd "$REALESRGAN_DIR"

    # Real-ESRGAN サブディレクトリへのシンボリックリンク作成
    # (コードが Real-ESRGAN/inference_realesrgan.py を期待するため)
    if [ ! -e "Real-ESRGAN" ]; then
        echo "Creating Real-ESRGAN symlink..."
        ln -s . Real-ESRGAN
    fi

    if [ ! -d "venv" ]; then
        echo "Creating Python venv..."
        python3 -m venv venv

        echo "Activating venv and installing packages..."
        source venv/bin/activate

        pip install --upgrade pip

        # PyTorch with CUDA support (CUDA 11.8)
        # RTX 3090 に対応
        echo "Installing PyTorch with CUDA support..."
        pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118

        # RealEsrgan requirements
        pip install basicsr facexlib gfpgan opencv-python numpy

        # Real-ESRGAN をローカルからインストール (realesrgan パッケージ)
        echo "Installing Real-ESRGAN from local source..."
        pip install -e .

        # basicsr の torchvision 互換性パッチ
        # (新しい torchvision では functional_tensor が削除されているため)
        echo "Patching basicsr for torchvision compatibility..."
        DEGRADATIONS_FILE="$REALESRGAN_DIR/venv/lib/python*/site-packages/basicsr/data/degradations.py"
        for f in $DEGRADATIONS_FILE; do
            if [ -f "$f" ]; then
                sed -i 's/from torchvision.transforms.functional_tensor import rgb_to_grayscale/from torchvision.transforms.functional import rgb_to_grayscale/' "$f"
                echo "Patched: $f"
            fi
        done

        deactivate
        echo "RealEsrgan venv setup complete"
    else
        echo "RealEsrgan venv already exists, skipping"
    fi
else
    echo "Warning: RealEsrgan directory not found at $REALESRGAN_DIR"
    echo "Please clone the RealEsrgan repository manually or ensure external_tools is properly set up"
fi

# 5. Tesseract OCR データの確認
echo ""
echo "[5/5] Checking Tesseract OCR data..."
TESSDATA_DIR="$EXTERNAL_TOOLS_DIR/TesseractOCR_Data"
mkdir -p "$TESSDATA_DIR"

# システムの tessdata をシンボリックリンクまたはコピー
if [ ! -f "$TESSDATA_DIR/jpn.traineddata" ]; then
    echo "Setting up Tesseract data..."
    SYSTEM_TESSDATA="/usr/share/tesseract-ocr/4.00/tessdata"
    if [ -d "$SYSTEM_TESSDATA" ]; then
        cp "$SYSTEM_TESSDATA/jpn.traineddata" "$TESSDATA_DIR/" 2>/dev/null || true
        cp "$SYSTEM_TESSDATA/jpn_vert.traineddata" "$TESSDATA_DIR/" 2>/dev/null || true
        cp "$SYSTEM_TESSDATA/eng.traineddata" "$TESSDATA_DIR/" 2>/dev/null || true
        echo "Tesseract data copied from system"
    else
        # 5.x 版
        SYSTEM_TESSDATA="/usr/share/tesseract-ocr/5/tessdata"
        if [ -d "$SYSTEM_TESSDATA" ]; then
            cp "$SYSTEM_TESSDATA/jpn.traineddata" "$TESSDATA_DIR/" 2>/dev/null || true
            cp "$SYSTEM_TESSDATA/jpn_vert.traineddata" "$TESSDATA_DIR/" 2>/dev/null || true
            cp "$SYSTEM_TESSDATA/eng.traineddata" "$TESSDATA_DIR/" 2>/dev/null || true
            echo "Tesseract data copied from system (5.x)"
        else
            echo "Warning: System tessdata not found, please copy traineddata files manually"
        fi
    fi
else
    echo "Tesseract data already exists"
fi

# 6. OpenCvSharp ネイティブライブラリのシンボリックリンク作成
# (ビルド後に実行が必要)
echo ""
echo "[6/6] Note about OpenCvSharp native library..."
echo "After building, you need to create a symlink for OpenCvSharp:"
echo ""
echo "  cd SuperBookToolsApp/bin/Debug/net8.0/runtimes/linux-x64/native/"
echo "  ln -s ../../ubuntu.22.04-x64/native/libOpenCvSharpExtern.so libOpenCvSharpExtern.so"
echo ""

# 完了
echo ""
echo "========================================"
echo "Setup complete!"
echo "========================================"
echo ""
echo "Next steps:"
echo "1. Build the project:"
echo "   dotnet build SuperBookToolsApp/SuperBookToolsApp.csproj"
echo ""
echo "2. Create OpenCvSharp symlink (after first build):"
echo "   cd SuperBookToolsApp/bin/Debug/net8.0/runtimes/linux-x64/native/"
echo "   ln -s ../../ubuntu.22.04-x64/native/libOpenCvSharpExtern.so libOpenCvSharpExtern.so"
echo "   cd -"
echo ""
echo "3. Run the application:"
echo "   dotnet run --project SuperBookToolsApp/SuperBookToolsApp.csproj"
echo ""
echo "4. At the prompt, use:"
echo "   ConvertPdf <srcDir> /dst:<dstDir>"
echo ""
