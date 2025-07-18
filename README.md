# mediakit_tester

Flutter app to test video playbacks.

## Raspberry pi instruction

-  Install raspberry os bookworm (64 bit headless) 
-  Install [flutter elinux](https://github.com/sony/flutter-elinux)
-  Install dependecies. TODO: Impelement dependency list here

```sh
cd ~
git clone https://github.com/Sravdar/flutter-media-tester/
cd flutter-media-tester
flutter-elinux clean
flutter-elinux pub get
FVP_DEPS_LATEST=1 flutter-elinux build elinux --release --target-backend-type=gbm

# remove generated ffmpeg lib for hardware acceleartion
sudo rm ~/flutter-media-tester/build/elinux/arm64/release/bundle/lib/libffmpeg.so.8

# run
sudo FLUTTER_DRM_DEVICE=/dev/dri/card1 ~/flutter-media-tester/build/elinux/arm64/release/bundle/flutter-media-tester -b ~/flutter-media-tester/build/elinux/arm64/release/bundle

```
