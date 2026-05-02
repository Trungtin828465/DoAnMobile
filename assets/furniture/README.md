# Furniture 360 Assets

Dat anh that vao thu muc theo cau truc duoi day de hien thi trong man hinh room designer.

```
assets/furniture/
  sofa/
    thumb.jpg
    0.jpg
    45.jpg
    90.jpg
    135.jpg
    180.jpg
    225.jpg
    270.jpg
    315.jpg
  coffee_table/
    thumb.jpg
    0.jpg
    ...
```

## Quy tac

- `thumb.jpg`: anh dai dien o catalog.
- Cac file goc quay dung ten goc (do): `0.jpg`, `45.jpg`, ..., `315.jpg`.
- Nen dung cung ti le khung hinh cho toan bo frame de xoay 360 muot hon.
- Khuyen nghi nen anh PNG/JPG nen trong suot hoac da tach nen de nhin ro tren canvas.

Sau khi them anh:

```powershell
flutter pub get
flutter run
```
