# Публикация владельцем

Локальная рабочая ветка — `codex/tashair-initial`, remote `origin` указывает на `git@github.com:ahrik/tashair.git`. Публикация, push и merge не выполняются автоматически.

После входа в GitHub CLI владелец может создать пустой публичный репозиторий, не добавляя README или лицензию на стороне GitHub:

```sh
gh auth login
gh repo create ahrik/tashair --public --description 'Tashkent air quality, weather and solar activity in your macOS menu bar'
```

Отправку подготовленной ветки выполняет владелец:

```sh
git push -u origin codex/tashair-initial
```

После первого push GitHub Actions проверит тесты и универсальную сборку; результат появится как артефакт workflow. Настройку основной ветки и слияние выполняет владелец отдельно.

Релиз создаётся вручную после проверки установленного приложения, системных разрешений и галереи виджетов. К релизу 0.1.0 приложите `TashAir.dmg`, `TashAir-macOS.zip` и `SHA256SUMS`, укажите локальную подпись ad hoc и отсутствие нотариализации. GitHub Actions не публикует релизы сам.

Первый запуск и добавление виджета через галерею macOS требуют ручной проверки; рендеринг PNG не заменяет этот системный сценарий. Developer ID и нотариализация остаются отдельным этапом.
