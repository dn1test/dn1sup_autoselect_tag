# Changelog (Лог изменений)

Лог изменений **DN1Sup AutoSelect Tag** (`dn1sup_autoselect_tag`).
Формат версий соответствует правилам `MAJOR.MINOR.PATCH`.

## [0.6.0] — 2026-10-15

- Удалён функционал dev/prod (второй id `dn1sup_autoselect_tag_dev`): удалены
  `DEV_BUILD`, поле `dev_build` в данных диалога и бейдж DEV в шапке настроек.
  Разработка — рабочая копия под тем же id с перезагрузкой
  `Dn1sup::AutoSelectTag.reload`; self-update рабочей копии отключён по пути
  загрузки (`Dn1sup::Updater.dev_source?`); файлы `.sketchup_dev.json` удалены.
- Обновления: единый апдейтер v3 — проверка сначала смотрит папку разработки,
  потом GitHub (`check_local_first!`, `dev_dir` в MANIFEST); кнопка проверки
  обновлений в шапке диалога настроек (`check_update`); фикс кодировки UTF-8
  при чтении registry.json/CHANGELOG.md с GitHub.
- Чистка: удалены `archive/`, старые `.rbz` в `dist/`, `tools/list_rbz.rb`;
  `author` добавлен в `registry.json`.

## [0.5.0] — 2026-10-09

- feat(ui): rewrite settings dialog in Vue 3 + Tailwind; v0.5.0
- docs: PUBLISHING.md - GitHub repo requirements for Extension Store; link in README
