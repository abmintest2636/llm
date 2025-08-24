#!/bin/bash

# Скрипт для збирання llama.cpp для Android

# Шлях до Android NDK
if [ -z "$ANDROID_NDK" ]; then
  echo "ANDROID_NDK environment variable is not set. Please set it to your NDK path."
  exit 1
fi

# Директорія проекту
PROJECT_DIR=$(pwd)

# Клонування llama.cpp якщо він не існує
if [ ! -d "android/app/src/main/cpp/llama.cpp" ]; then
  echo "Cloning llama.cpp..."
  git clone https://github.com/ggerganov/llama.cpp.git android/app/src/main/cpp/llama.cpp
  cd android/app/src/main/cpp/llama.cpp
  git checkout master
  cd "$PROJECT_DIR"
fi

# Архітектури для збірки
ARCHS=("armeabi-v7a" "arm64-v8a" "x86_64")

# Збірка для кожної архітектури
for ARCH in "${ARCHS[@]}"; do
  echo "Building for $ARCH..."
  
  # Встановлення параметрів компіляції для різних архітектур
  case $ARCH in
    "armeabi-v7a")
      ABI="armeabi-v7a"
      TARGET_HOST="armv7a-linux-androideabi"
      TOOLCHAIN_PREFIX="armv7a-linux-androideabi"
      ;;
    "arm64-v8a")
      ABI="arm64-v8a"
      TARGET_HOST="aarch64-linux-android"
      TOOLCHAIN_PREFIX="aarch64-linux-android"
      ;;
    "x86_64")
      ABI="x86_64"
      TARGET_HOST="x86_64-linux-android"
      TOOLCHAIN_PREFIX="x86_64-linux-android"
      ;;
  esac

  # Шлях до тулчейну
  TOOLCHAIN="$ANDROID_NDK/toolchains/llvm/prebuilt/darwin-x86_64"
  API_LEVEL=24

  # Створення директорії для збірки
  BUILD_DIR="$PROJECT_DIR/android/app/src/main/cpp/build_$ARCH"
  mkdir -p "$BUILD_DIR"
  cd "$BUILD_DIR"

  # Запуск CMake
  cmake -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK/build/cmake/android.toolchain.cmake" \
        -DANDROID_ABI="$ABI" \
        -DANDROID_PLATFORM=android-$API_LEVEL \
        -DCMAKE_CXX_FLAGS="-std=c++17" \
        -DLLAMA_BLAS=OFF \
        -DLLAMA_CUBLAS=OFF \
        -DBUILD_SHARED_LIBS=ON \
        "../llama.cpp"

  # Збірка
  make -j$(nproc)
  
  # Повернення в директорію проекту
  cd "$PROJECT_DIR"
done

echo "Build completed for all architectures!"