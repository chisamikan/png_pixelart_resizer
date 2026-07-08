@echo off
setlocal enabledelayedexpansion

REM ===================================================
REM   出力先フォルダをここで指定してください
REM   （すべての入力元フォルダの画像がこの1箇所にまとめて出力されます）
REM ===================================================
set "OUTPUT_DIR=C:\Users\YourName\Desktop\output"


echo ===================================================
echo   PNG画像 ニアレストネイバー法 拡大バッチ（複数フォルダ対応）
echo ===================================================
echo.
echo 出力先フォルダ: %OUTPUT_DIR%
echo （変更したい場合は、このbatファイルをテキストエディタで開き、
echo   先頭の OUTPUT_DIR の行を書き換えてください）
echo.

if not exist "%~dp0resize_nn.ps1" (
    echo resize_nn.ps1 が見つかりません。
    echo このバッチファイルと同じフォルダに置いてください。
    pause
    exit /b 1
)

set "DIR_LIST="

REM --- 複数フォルダをドラッグ&ドロップした場合はそれを使用 ---
if not "%~1"=="" (
    for %%F in (%*) do (
        if defined DIR_LIST (
            set "DIR_LIST=!DIR_LIST!;%%~fF"
        ) else (
            set "DIR_LIST=%%~fF"
        )
    )
    echo 指定された入力元フォルダ:
    echo !DIR_LIST!
    echo.
    goto ask_scale
)

REM --- ドラッグ&ドロップがない場合はフォルダパスを1つずつ入力 ---
echo 入力元フォルダのパスを1つずつ入力してください。
echo 入力を終える場合は、何も入力せずEnterキーを押してください。
echo.

:input_loop
set /p "ONE_DIR=フォルダパス: "
if "%ONE_DIR%"=="" goto after_input

if not exist "%ONE_DIR%" (
    echo   -> このフォルダは見つかりません。もう一度入力してください。
    goto input_loop
)

if defined DIR_LIST (
    set "DIR_LIST=!DIR_LIST!;%ONE_DIR%"
) else (
    set "DIR_LIST=%ONE_DIR%"
)
goto input_loop

:after_input

if not defined DIR_LIST (
    echo フォルダが1つも指定されませんでした。処理を終了します。
    pause
    exit /b 1
)

:ask_scale
set /p SCALE="拡大倍率を入力してください（例: 2 と入力すると2倍）: "

echo.
echo 処理を開始します...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0resize_nn.ps1" -DirList "!DIR_LIST!" -OutDir "%OUTPUT_DIR%" -Scale %SCALE%

echo.
echo 処理が終了しました。何かキーを押すと終了します。
pause >nul
