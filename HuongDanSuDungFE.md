# AI SP - Huong dan chay Flutter

## 1. Clone project

```bash
git clone https://github.com/Trungtin828465/DoAnMobile.git
cd doan
```

Mo dung thu muc co file `pubspec.yaml`.

## 2. Cai dat package

```bash
flutter pub get
```

Luu y project dang dung package STT local:

```text
third_party/speech_to_text
```

Vi vay sau khi clone phai dam bao thu muc tren ton tai trong project.

## 3. Tao file `.env`

Tao file `.env` o thu muc goc, cung cap voi `pubspec.yaml`.

Noi dung mau:

```env
baseUrl=https://doanapi.onrender.com/api
ttsUrl=https://doanapi.onrender.com/api/tts

openrouterApiKey=KEY_OPENROUTER_DUNG_CHO_STT
openrouterApiUrl=https://openrouter.ai/api/v1/chat/completions
openrouterModel=openai/gpt-3.5-turbo

geminiApiKey=KEY_OPENROUTER_DUNG_CHO_VISION
geminiApiUrl=https://openrouter.ai/api/v1/chat/completions
geminiVisionModel=google/gemini-2.5-flash

```

Trong do:

- `baseUrl` va `ttsUrl` dang tro den backend da deploy tren Render.
- `openrouterApiKey` dung de xu ly cau noi nguoi dung.
- `geminiApiKey` dung de xac minh anh detect confidence thap qua OpenRouter Vision.

## 4. Khai bao package va assets trong `pubspec.yaml`

Kiem tra `pubspec.yaml` và paste toàn bộ vào `pubspec.yaml`

```yaml
name: doan
description: "AI SP - Room Designer App for smart interior planning."
publish_to: 'none' 
version: 1.0.0+1
environment:
  sdk: ^3.7.0
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  http: ^1.1.0
  shared_preferences: ^2.2.0
  vector_math: ^2.1.4
  path_provider: ^2.1.5
  flutter_joystick: ^0.2.2
  speech_to_text:
    path: third_party/speech_to_text
  flutter_tts: ^4.2.5
  audioplayers: ^5.2.0
  flutter_dotenv: ^5.1.0
  permission_handler: ^12.0.1
  camera: ^0.11.0+1
  uuid: ^4.0.0
  sensors_plus: ^3.0.0
  webview_flutter: ^4.8.0
  tflite_flutter: ^0.11.0
  image: ^4.1.0
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
flutter:
  uses-material-design: true
  assets:
    - .env
    - assets/models/
    - assets/layouts/layout.json
    - assets/anh/
    - assets/model/bed.glb
    - assets/model/sofa.glb
    - assets/model/chair.glb
    - assets/model/table.glb
    - assets/model/wardrobe.glb
    - assets/model/refrigerator.glb
    - assets/model/tv.glb
    - assets/model/door.glb
    - assets/model/window.glb
    - assets/model/fan.glb
    - assets/model/laptop.glb
    - assets/model/washing_machine.glb
```

## 5. Kiem tra assets bat buoc

Dam bao cac file sau co trong project:

```text
assets/models/best.tflite
```

Va cac model 3D trong:

```text
assets/model/
```

Can co cac file:

```text
bed.glb
sofa.glb
chair.glb
table.glb
wardrobe.glb
refrigerator.glb
tv.glb
door.glb
window.glb
fan.glb
laptop.glb
washing_machine.glb
```

## 6. Chay app

Ket noi dien thoai Android that, bat USB Debugging, sau do chay:

```bash
flutter devices
flutter run
```


## 7. Quyen tren dien thoai

Khi app mo lan dau, cap quyen:

- Camera
- Micro

Neu STT khong nghe duoc, hay cai/bat:

- Google app
- Gboard
- Google voice typing / Nhap lieu bang giong noi cua Google

## 8. Build APK neu can

```bash
flutter build apk --release
```
