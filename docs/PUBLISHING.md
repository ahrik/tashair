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

Релиз создаётся вручную после проверки установленного приложения, системных разрешений и галереи виджетов. К релизу 0.1.0 приложите `TashAir.dmg`, `TashAir-macOS.zip` и `SHA256SUMS`, укажите локальную подпись ad hoc и отсутствие нотариализации. GitHub Actions не публикует релизы сам.

Developer ID и нотариализация остаются отдельным этапом. Сайт ведёт на инструкцию установки; он не обещает скачивание опубликованного релиза, которого ещё нет.

Подробнее: [официальная инструкция GitHub Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages).
