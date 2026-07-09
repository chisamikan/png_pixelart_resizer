@echo off
setlocal enabledelayedexpansion

REM ===================================================
REM   出力先フォルダをここで指定してください
REM   （すべての入力元の画像がこの1箇所にまとめて出力されます）
REM ===================================================
set "OUTPUT_DIR=C:\Users\YourName\Desktop\output"


echo ===================================================
echo   png_pixelart_resizer
echo ===================================================
echo.
echo 出力先フォルダ: %OUTPUT_DIR%
echo （変更したい場合は、このbatファイルをテキストエディタで開き、
echo   先頭の OUTPUT_DIR の行を書き換えてください）
echo.

if not exist "%~dp0resize.ps1" (
    echo resize.ps1 が見つかりません。
    echo このバッチファイルと同じフォルダに置いてください。
    pause
    exit /b 1
)

REM --- 出力先フォルダが初期値のままの場合は書き換えを案内して終了 ---
if /i "%OUTPUT_DIR%"=="C:\Users\YourName\Desktop\output" (
    echo 出力先フォルダが初期設定のままです。
    echo このbatファイルをテキストエディタで開き、先頭付近の
    echo   set "OUTPUT_DIR=C:\Users\YourName\Desktop\output"
    echo の行を、実際に使用したい出力先フォルダのパスに書き換えてから
    echo 再度実行してください。
    echo.
    echo 何かキーを押すと終了します。
    pause >nul
    exit /b 1
)

REM --- ドラッグ&ドロップされていない場合は案内して終了 ---
if "%~1"=="" (
    echo 拡大したいPNGファイル、またはPNG画像が入ったフォルダを
    echo このbatファイルにドラッグ^&ドロップして実行してください。
    echo（複数のファイル・フォルダをまとめて指定することもできます）
    echo.
    echo 何かキーを押すと終了します。
    pause >nul
    exit /b 0
)

set "INPUT_LIST="

for %%F in (%*) do (
    if defined INPUT_LIST (
        set "INPUT_LIST=!INPUT_LIST!;%%~fF"
    ) else (
        set "INPUT_LIST=%%~fF"
    )
)

echo.
echo ===================================================
echo 指定された入力元:
echo   !INPUT_LIST!
echo ===================================================
echo.

set "CLEAR_ANSWER="
set /p "CLEAR_ANSWER=処理開始前に出力先フォルダ内のPNG画像を全て削除しますか？ (y/n): "
if /i "%CLEAR_ANSWER%"=="y" (
    set "CLEAR_FLAG=1"
) else (
    set "CLEAR_FLAG=0"
)

set /p SCALE="拡大倍率を入力してください（例: 2 と入力すると2倍）: "

echo.
echo 処理を開始します...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0resize.ps1" -InputList "!INPUT_LIST!" -OutDir "%OUTPUT_DIR%" -Scale %SCALE% -ClearOutput %CLEAR_FLAG%

echo.
echo 処理が終了しました。何かキーを押すと終了します。
pause >nul
