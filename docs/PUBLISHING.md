# Публикация на GitHub

Публичный репозиторий — [`ahrik/tashair`](https://github.com/ahrik/tashair), сайт документации — [GitHub Pages](https://ahrik.github.io/tashair/). Полный код приложения и книги находится в ветке **`main`**. Remote `origin` указывает на `git@github.com:ahrik/tashair.git`.

## Авторизация и создание репозитория

Авторизуйтесь под `ahrik`, проверьте аккаунт и создайте пустой публичный репозиторий без дополнительных README или лицензии:

```sh
gh auth login
gh auth status
gh repo create ahrik/tashair --public --description 'Tashkent air quality, weather and solar activity in your macOS menu bar' --homepage 'https://ahrik.github.io/tashair/'
```

Если репозиторий уже существует, сначала проверьте его состояние; повторное создание не требуется.

## Отправка изменений и основная ветка

Разработка ведётся в отдельных ветках. По правилам проекта push и merge выполняет владелец; действия агента требуют явного разрешения на конкретную задачу. После проверки и объединения изменений в локальную `main` владелец отправляет её:

```sh
git push origin main
```

В Settings → General → Default branch выберите **main**. После смены основной ветки проверьте ограничения окружения `github-pages`: оно должно разрешать публикацию из `main`. Workflow документации публикует книгу только из `main`; сборка и проверка продолжают выполняться для всех веток и PR.

## Включение GitHub Pages

После первой отправки откройте Settings → Pages → Build and deployment → Source → **GitHub Actions**. Альтернативно:

```sh
gh api --method POST repos/ahrik/tashair/pages -f build_type=workflow
```

Если Pages уже включён, проверьте, что источник — GitHub Actions. У окружения `github-pages` должны быть разрешены развёртывания из основной ветки. Затем запустите Documentation в разделе Actions; сборка и проверка проходят на каждой ветке, публикация — только из `main`. Перезапуск из CLI:

```sh
gh workflow run docs.yml --repo ahrik/tashair --ref main
```

После успешного задания `deploy` проверьте `https://ahrik.github.io/tashair/`, страницу виджетов и поиск. Проверка CI приложения идёт отдельно, без автоматического выпуска релиза.

## Выпуск приложения

Релиз v0.1.1 содержит `TashAir.dmg`, `TashAir-macOS.zip` и `SHA256SUMS`. Книга документации и README предлагают прямое скачивание DMG, альтернативный ZIP и контрольные суммы. Сборка универсальная: Apple Silicon и Intel, macOS 14+; подпись ad hoc, без Developer ID и нотариализации Apple.

Workflow `release.yml` запускается при отправке тега `v*`. Он выполняет тесты, собирает универсальный DMG/ZIP, проверяет архитектуры, подписи, содержимое архивов и контрольные суммы, затем публикует GitHub Release с файлами. Ошибка проверки останавливает публикацию. Для публикации используется временный `GITHUB_TOKEN` задания с правом `contents: write`.

После разрешения владельца на выпуск:

1. Обновите версии в метаданных приложения и расширения, проверках, README, книге, прямых ссылках и `docs/RELEASE_NOTES.md`.
2. Выполните проверки, объедините изменения в `main` и отправьте основную ветку.
3. Создайте тег той же версии на проверенном коммите и отправьте тег. Для 0.1.1:

```sh
git tag v0.1.1
git push origin v0.1.1
```

4. Дождитесь успешных Release, macOS и Documentation в GitHub Actions.
5. Проверьте прямые ссылки в опубликованной книге, скачайте установщик и сопоставьте SHA-256 с опубликованными контрольными суммами.

Не перемещайте теги опубликованных версий и не заменяйте их файлы новой сборкой: выпускайте следующую версию. Developer ID и нотариализация остаются отдельным этапом.

Подробнее: [официальная инструкция GitHub Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages).
