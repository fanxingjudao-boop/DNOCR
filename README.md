
# DN_SuperBook_PDF_Converter - 自炊書籍 PDF を電子書籍並みに綺麗に読みやすくする本格派ツール


# インストール環境
## 前提環境
- OS: Windows 10 / 11 x64 版
- RAM: メモリは、かなり食います。このプログラムは、手抜きのため、多数のページがメモリ上に展開される部分があります。変換しようとする元 PDF のページ数に応じて、数 GB ～数十 GB の空きメモリが必要になるかも知れません。
- GPU: 内部で利用している [RealEsrgan](https://github.com/xinntao/Real-ESRGAN) という画像鮮明化 AI が、GPU 処理を必要とします。CPU でも処理はできると思いますが、その場合、極めて長時間かかり、実用的ではありません。GPU は、NVIDIA の CUDA 対応の GeForce シリーズを推奨します。以下のインストール手順サンプルでは、pytorch のインストールに際して `cu128` というバージョンの CUDA に対応したものをインストールするようにしています。私は CUDA に詳しくないので、他のバージョンでも動くかも知れません。あるいは、CUDA 以外の GPU 用ドライバでも動くかも知れません。

## 必要な開発環境
- Visual Studio 2022 または Visual Studio 2026 を利用します。C# .net 6.0 (少し古い) の開発環境をインストールすることを推奨します。Community Edition でも動作します。
- Python 3 系を利用します。以下の設定サンプルでは、Python 3.11.9 を使用していますが、おそらく、他のバージョンでも動作します。
- git を利用します。以下の設定サンプルでは、`git.exe` が `C:\Program Files\Git\bin\git.exe` としてインストールされていることを前提とします。


# インストール手順書
## このリポジトリのクローン
どこか適当な開発用ディレクトリ (ディリレクトリ名のフルパスには、スペースや全角文字列を含まないことを推奨) を作成し、そのディレクトリに移動したのちに、コマンドラインから以下のとおりこのリポジトリのクローンをします。
```
"C:\Program Files\Git\bin\git.exe" --recursive https://github.com/dnobori/DN_SuperBook_PDF_Converter.git
```

## 1. external_tool\image_tools\ ディレクトリの準備
本プログラムが内部的に子プロセス等として呼び出す、第三者が配布しているプログラム等を、以下のとおりダウンロードし、`external_tool\image_tools\` というサブディレクトリに保存してください。以下のダウンロードする各プログラムは、各配布主体が配布するものであり、私が配布するものではありません。ダウンロードした各ファイルにマルウェア等か含まれないかどうかは、各自アンチウイルスソフトウェア等で慎重に確認してください。

### 1.1. exiftool-13.30_64 ディレクトリ
[ExifTool](https://exiftool.org/) の Version 13.30 x64 を入れます。このディレクトリの直下に、`exiftool.exe` というファイルが置かれた状態にしてください。このソフトウェアはフリーソフトウェア (GPL ライセンス) なので、インターネット上からダウンロードすることが可能です。以下でも再配布しています。  
[https://filecenter.softether-upload.com/d/260118_003_73929/exiftool-13.30_64.zip](https://filecenter.softether-upload.com/d/260118_003_73929/exiftool-13.30_64.zip)

### 1.2. ImageMagick-portable-Q16-HDRI-x64 ディレクトリ
まず、[ImageMagick](https://imagemagick.org/) の 7.1.x 系の **portable-Q16-HDRI-x64 版** を入れます。このディレクトリの直下に、`magick.exe` や `mogrify.exe` などのファイルが置かれた状態にしてください。このソフトウェアはフリーソフトウェア (ImageMagick ライセンス) で、以下からダウンロードできます。  
[https://imagemagick.org/archive/binaries/](https://imagemagick.org/archive/binaries/)
  
本ドキュメント作成時は、`ImageMagick-7.1.2-12-portable-Q16-HDRI-x64.7z` というファイル名で配布されています。しかし、バージョンアップによって、バージョンやファイルが変わるようです。

  
次に、[ghostscript](https://www.ghostscript.com/releases/gsdnld.html) の 10.5.1 x64 版のいくつかの実行可能ファイルを、この `ImageMagick-portable-Q16-HDRI-x64` ディレクトリに入れる必要があります。以下の直リンクにあるインストールから、Ghostscript をインストールすると、`C:\Program Files\gs\gs10.05.1\bin\` というディレクトリに、`gsdll64.dll`, `gsdll64.lib`, `gswin64.exe`, `gswin64c.exe` という 4 個のバイナリファイルが保存されます。これらの 4 個のファイルを、すべて、`ImageMagick-portable-Q16-HDRI-x64` ディレクトリにコピーします。  
[https://github.com/ArtifexSoftware/ghostpdl-downloads/releases/download/gs10051/gs10051w64.exe](https://github.com/ArtifexSoftware/ghostpdl-downloads/releases/download/gs10051/gs10051w64.exe)

### 1.3. pdfcpu ディレクトリ
pdfcpu の v0.11.0 x64 を入れます。このディレクトリの直下に、`pdfcpu.exe` というファイルが置かれた状態にしてください。このソフトウェアはフリーソフトウェア (Apache ライセンス) なので、インターネット上からダウンロードすることが可能です。以下に直リンクを示します。
[https://github.com/pdfcpu/pdfcpu/releases/download/v0.11.0/pdfcpu_0.11.0_Windows_x86_64.zip](https://github.com/pdfcpu/pdfcpu/releases/download/v0.11.0/pdfcpu_0.11.0_Windows_x86_64.zip)


### 1.4. qpdf ディレクトリ
qpdf の v11.9.1 x64 (msvc64) を入れます。このディレクトリの直下に、`bin` というサブディレクトリがあり、その下に、`qpdf.exe` というファイルが置かれた状態にしてください。このソフトウェアはフリーソフトウェア (Apache ライセンス) なので、インターネット上からダウンロードすることが可能です。以下に直リンクを示します。  
[https://github.com/qpdf/qpdf/releases/download/v11.9.1/qpdf-11.9.1-msvc64.zip](https://github.com/qpdf/qpdf/releases/download/v11.9.1/qpdf-11.9.1-msvc64.zip)


### 1.5. RealEsrgan ディレクトリ
これは追加的手順が必要なので、後述します。


### 1.6. TesseractOCR_Data ディレクトリ
OCR エンジンのモデルデータである、[tesseract-ocr / tessdata_best] の v4.1.0 のデータのうち、`eng.traineddata` と `jpn.traineddata` の 2 つのファイルを入れます。このディレクトリの直下に、これらの 2 つのファイルが置かれた状態にしてください。このデータはフリーデータ (Apache ライセンス) なので、インターネット上からダウンロードすることが可能です。以下に直リンクを示します。  
[https://github.com/tesseract-ocr/tessdata_best/archive/4.1.0.zip](https://github.com/tesseract-ocr/tessdata_best/archive/4.1.0.zip)



## 2. external_tool\image_tools\RealEsrgan\ ディレクトリの準備

1. [Python 3.11.9 for Windows](https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe) をインストールします。(他のバージョンでも良いかも知れません。)  
   インストール後、`%LOCALAPPDATA%\Programs\Python\Python311\python.exe` に `python.exe` が存在するという前提で、以下の解説をいたします。
1. コマンドプロンプトを開きます。
1. 以下を 1 つずつ実行します。意味をよく理解しながら、実行してください。環境によっては、追加的に補正作業が必要となる可能性があります。
   ```
   mkdir <このgitをダウンロードしたディレクトリ>\DN_SuperBook_PDF_Converter\external_tools\external_tools\image_tools\RealEsrgan\RealEsrgan_Repo\

   cd <このgitをダウンロードしたディレクトリ>\DN_SuperBook_PDF_Converter\external_tools\external_tools\image_tools\RealEsrgan\RealEsrgan_Repo\

   %LOCALAPPDATA%\Programs\Python\Python311\python.exe -m venv venv

   venv\Scripts\activate

   python -m pip install --upgrade pip

   pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128

   cd /d <このgitをダウンロードしたディレクトリ>\DN_SuperBook_PDF_Converter\external_tools\external_tools\image_tools\RealEsrgan\RealEsrgan_Repo\

   "C:\Program Files\Git\bin\git.exe" clone https://github.com/xinntao/Real-ESRGAN.git

   cd <このgitをダウンロードしたディレクトリ>\DN_SuperBook_PDF_Converter\external_tools\external_tools\image_tools\RealEsrgan\RealEsrgan_Repo\Real-ESRGAN\

   "C:\Program Files\Git\bin\git.exe" checkout a4abfb2979a7bbff3f69f58f58ae324608821e27
   ```
1. [https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth](https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth) を、`<このgitをダウンロードしたディレクトリ>\DN_SuperBook_PDF_Converter\external_tools\external_tools\image_tools\RealEsrgan\RealEsrgan_Repo\Real-ESRGAN\weights\` に、手動でダウンロードして、保存します。
1. 以下を 1 つずつ実行します。意味をよく理解しながら、実行してください。環境によっては、追加的に補正作業が必要となる可能性があります。
   ```
   cd <このgitをダウンロードしたディレクトリ>\DN_SuperBook_PDF_Converter\external_tools\external_tools\image_tools\RealEsrgan\RealEsrgan_Repo\

   venv\Scripts\activate

   pip install -r Real-ESRGAN\requirements.txt
   ```
1. 任意のテキストエディタで、`<このgitをダウンロードしたディレクトリ>\DN_SuperBook_PDF_Converter\external_tools\external_tools\image_tools\RealEsrgan\RealEsrgan_Repo\venv\Lib\site-packages\basicsr\data\degradations.py` を開きます。  
   以下のとおり、インチキ書き換えをします。  
   旧:
   ```
   from torchvision.transforms.functional_tensor import rgb_to_grayscale
   ```
   新:
   ```
   from torchvision.transforms.functional import rgb_to_grayscale
   ```
1. 任意のテキストエディタで、`<このgitをダウンロードしたディレクトリ>\DN_SuperBook_PDF_Converter\external_tools\external_tools\image_tools\RealEsrgan\RealEsrgan_Repo\Real-ESRGAN\realesrgan\version.py` というファイル名の、内容が空のファイルを作成します。





