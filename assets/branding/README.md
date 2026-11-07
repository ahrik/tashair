# Логотип TashAir

Знак: буква T, переходящая в потоки воздуха, и золотое солнце на бирюзовом фоне.

- `assets/branding/tashair-logo.png` — квадратный оригинал, 1254 × 1254.
- `web/assets/logo.png` — иконка 256 × 256 с прозрачными полями для README, шапки документации и favicon.
- `scripts/draw-icon.swift` — формирует все размеры `.iconset` из оригинала, добавляя скруглённую плитку и внешние прозрачные поля по пропорциям macOS. `scripts/build-app.sh` собирает `.icns` и включает его в приложение. Заголовок панели использует иконку приложения.

Обновление веб-версии из оригинала:

```sh
xcrun swift -module-cache-path temp/module-cache scripts/draw-icon.swift temp/icon.iconset
cp temp/icon.iconset/icon_256x256.png web/assets/logo.png
```

## Создание изображения

Создано встроенным инструментом ImageGen. Финальный промпт (без изображений-референсов, `transparent_background: false`):

```text
Create a crisp finished TashAir logo as a flat vector-style SQUARE image. The ENTIRE image canvas is a perfectly uniform solid teal #105B54 background from edge to edge. Absolutely no transparency, no gradients, no smudges, no dark shading, no mockup, no border, no rounded-square outer tile, just solid teal background. In the center create a bold white stylized capital T whose crossbar flows rightwards into a sweeping ribbon of air. Beneath the T put two separate broad gently sweeping wave ribbons: upper turquoise #20A58D, bottom ivory #F6FAF5. One round golden sun #F2CB66 in the upper right. Three or four LARGE clean shapes total, premium simple geometric air-quality macOS app identity. Icon design with ample negative space surrounding all the shapes, optical balanced composition. ALL fills completely flat and solid, NO shadows whatsoever. No text, no letters other than the symbolic T, no words, no captions, no signature, no watermark. Plain clean continuous teal in the empty area above the symbol. 1024 square.
```
