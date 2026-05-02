# 3D Room Layout (Flutter + flutter_scene)

Ung dung Flutter hien thi phong 3D va 12 object tu layout JSON de phuc vu bai toan nhan dien vat the.

## Tinh nang chinh

- Render room shell (`room.glb`) + 12 object trong `assets/models/`.
- Nhan layout tu `assets/layouts/layout.json` theo schema `position`, `rotationEulerDeg`, `scale`.
- Camera FPS/free-fly:
  - Joystick ben trai: di chuyen forward/back + strafe.
  - Drag ben phai: yaw/pitch.
  - Clamp camera theo room bounds.
  - Slider move speed (0.5 -> 3.0 m/s).
- Chon object bang dropdown fallback, rotate +-15 deg, move tren san bang drag pad.
- Save layout vao local storage (`layout_saved.json`) + in JSON ra debug log.

## Thu muc quan trong

- `lib/screens/room_designer_screen.dart`: man hinh editor 3D + UI control.
- `lib/controllers/room_designer_controller.dart`: camera loop, transform object, save/load.
- `lib/models/layout_model.dart`: schema layout.
- `lib/services/layout_storage_service.dart`: doc asset JSON va luu file local.
- `assets/layouts/layout.json`: layout mac dinh.

## Model files can copy vao `assets/models/`

- `room.glb`
- `bed.glb`
- `sofa.glb`
- `chair.glb`
- `table.glb`
- `lamp.glb`
- `tv.glb`
- `laptop.glb`
- `wardrobe.glb`
- `window.glb`
- `door.glb`
- `potted_plant.glb`
- `photo_frame.glb`

Neu model chua co, app se dung fallback cuboid de van test duoc luong dieu khien/sua layout.

## Run nhanh

```bash
flutter config --enable-native-assets
flutter pub get
dart --enable-experiment=native-assets run flutter_scene_importer:import --input assets/models/room.glb --output build/models/room.model --working-directory .
dart --enable-experiment=native-assets run flutter_scene_importer:import --input assets/models/bed.glb --output build/models/bed.model --working-directory .
dart --enable-experiment=native-assets run flutter_scene_importer:import --input assets/models/sofa.glb --output build/models/sofa.model --working-directory .
dart --enable-experiment=native-assets run flutter_scene_importer:import --input assets/models/chair.glb --output build/models/chair.model --working-directory .
dart --enable-experiment=native-assets run flutter_scene_importer:import --input assets/models/table.glb --output build/models/table.model --working-directory .
dart --enable-experiment=native-assets run flutter_scene_importer:import --input assets/models/lamp.glb --output build/models/lamp.model --working-directory .
dart --enable-experiment=native-assets run flutter_scene_importer:import --input assets/models/tv.glb --output build/models/tv.model --working-directory .
dart --enable-experiment=native-assets run flutter_scene_importer:import --input assets/models/laptop.glb --output build/models/laptop.model --working-directory .
dart --enable-experiment=native-assets run flutter_scene_importer:import --input assets/models/wardrobe.glb --output build/models/wardrobe.model --working-directory .
dart --enable-experiment=native-assets run flutter_scene_importer:import --input assets/models/window.glb --output build/models/window.model --working-directory .
dart --enable-experiment=native-assets run flutter_scene_importer:import --input assets/models/door.glb --output build/models/door.model --working-directory .
dart --enable-experiment=native-assets run flutter_scene_importer:import --input assets/models/potted_plant.glb --output build/models/potted_plant.model --working-directory .
dart --enable-experiment=native-assets run flutter_scene_importer:import --input assets/models/photo_frame.glb --output build/models/photo_frame.model --working-directory .
flutter run -d android
```

## Ghi chu wall backface culling

Neu mat trong tuong bi mat, sua `room.glb` trong Blender:

- Them do day tuong (Solidify), hoac
- Bat material `double-sided` truoc khi export.
