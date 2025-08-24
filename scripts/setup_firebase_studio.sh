#!/bin/bash

# Скрипт для налаштування llama.cpp у Firebase Studio

set -e

PROJECT_DIR=$(pwd)

echo "Setting up llama.cpp for Firebase Studio environment..."

# Перевіряємо змінну середовища ANDROID_SDK_ROOT
if [ -z "$ANDROID_SDK_ROOT" ]; then
    echo "Setting ANDROID_SDK_ROOT to default Firebase Studio path..."
    export ANDROID_SDK_ROOT="/home/user/.androidsdkroot"
fi

echo "Using ANDROID_SDK_ROOT: $ANDROID_SDK_ROOT"

# Створюємо необхідні директорії
mkdir -p android/app/src/main/cpp
mkdir -p assets

# Створюємо assets README
echo "# Assets Directory" > assets/README.md
echo "Цю директорію використовують для зберігання статичних файлів додатку." >> assets/README.md

# Клонування llama.cpp якщо він не існує
if [ ! -d "android/app/src/main/cpp/llama.cpp" ]; then
    echo "Cloning llama.cpp..."
    cd android/app/src/main/cpp
    git clone https://github.com/ggerganov/llama.cpp.git
    cd llama.cpp
    git checkout master
    echo "llama.cpp cloned successfully"
    cd "$PROJECT_DIR"
else
    echo "llama.cpp already exists, updating..."
    cd android/app/src/main/cpp/llama.cpp
    git pull origin master
    cd "$PROJECT_DIR"
fi

echo "Setup completed!"
echo ""
echo "Next steps:"
echo "1. Run 'flutter pub get' to install dependencies"
echo "2. Build the project with 'flutter build apk' or run with 'flutter run'"
echo ""
echo "Note: The first build may take longer as it compiles llama.cpp"