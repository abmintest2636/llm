{ pkgs, ... }: {
  # Which nixpkgs channel to use.
  channel = "stable-24.05";
  
  # Use https://search.nixos.org/packages to find packages
  packages = [
    pkgs.jdk21
    pkgs.unzip
    pkgs.git
    pkgs.cmake
    pkgs.gcc
    pkgs.gnumake
    pkgs.pkg-config
  ];
  
  # Sets environment variables in the workspace
  env = {
    ANDROID_SDK_ROOT = "/home/user/.androidsdkroot";
    ANDROID_NDK_HOME = "/home/user/.androidsdkroot/ndk";
  };
  
  idx = {
    # Search for the extensions you want on https://open-vsx.org/ and use "publisher.id"
    extensions = [
      "Dart-Code.flutter"
      "Dart-Code.dart-code"
    ];
    
    workspace = {
      # Runs when a workspace is first created with this `dev.nix` file
      onCreate = {
        default.openFiles = [ "lib/main.dart" ];
        setup-llama = "bash scripts/setup_firebase_studio.sh";
      };
      
      # To run something each time the workspace is (re)started, use the `onStart` hook
      onStart = {
        flutter-upgrade = "flutter upgrade";
        flutter-doctor = "flutter doctor";
      };
    };
    
    # Enable previews and customize configuration
    previews = {
      enable = true;
      previews = {
        web = {
          command = ["flutter" "run" "--machine" "-d" "web-server" "--web-hostname" "0.0.0.0" "--web-port" "$PORT"];
          manager = "flutter";
        };
        android = {
          command = ["flutter" "run" "--machine" "-d" "android" "-d" "localhost:5555"];
          manager = "flutter";
        };
      };
    };
  };
}