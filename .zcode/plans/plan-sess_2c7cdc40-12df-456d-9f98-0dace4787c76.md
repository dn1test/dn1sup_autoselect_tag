# HTML-настройки тегов для dn1sup_autoselect_tag (в рабочей папке)

## Цель
Меню **Extensions → DN1Sup AutoSelect Tag → «Настройки…»** открывает HtmlDialog, где для двух параметров (тег размеров и тег текстовых меток) выбирается имя тега: из списка уже существующих тегов модели или вводится новое. Выбор сохраняется в реестре SketchUp и переживает перезапуск.

## Структура рабочей папки (итог)
```
U:\dn1code\sketchup_ext\dn1sup_autoselect_tag\
  dn1sup_autoselect_tag.rb          # регистратор SketchupExtension (v0.2.0)
  .sketchup_dev.json                # dev-манифест (для ext_install/ext_reload)
  dn1sup_autoselect_tag\
    main.rb                         # логика v0.1.0 из монорепо + пункт меню «Настройки…» + Config
    config.rb                       # НОВОЕ: модуль Config (сохранение настроек)
    settings_dialog.rb              # НОВОЕ: HtmlDialog настроек
    dn1sup_updater.rb               # копия shared-апдейтера из монорепо
    html\index.html                 # НОВОЕ: тёмная тема, как в dn1sup_ext_manager
  archive\auto_tag_dimension_label.rb  # старая v1.0 (самоустанавливается при загрузке — убираем, чтобы не дублировала обсерверы)
  README.MD                         # обновить: установка, настройки, dev-перезагрузка
```
Базой берём актуальный код `Dn1sup::AutoSelectTag` из `dn1sup_extensions\src\dn1sup_autoselect_tag\` (главный файл + апдейтер) — старый v1.0 не имеет ни регистрации, ни меню, и мутирует модель прямо в `onElementAdded`.

## 1. config.rb — хранение настроек
- Модуль `Dn1sup::AutoSelectTag::Config` по образцу `dn1sup_time_project2/config.rb`.
- `SECTION = 'dn1sup_autoselect_tag'`, ключи `tag_dimension` / `tag_label`, значения по умолчанию `'Dimension'` / `'Label'`.
- Чтение/запись через `Sketchup.read_default` / `write_default` (реестр, без файлов, переживает перезагрузку).
- Валидация: `strip`, пустое/nil → значение по умолчанию.
- Методы: `tag_dimension`, `tag_label`, `tag_dimension=`, `tag_label=`.

## 2. main.rb — изменения
- `Sketchup.require` для `config`, `settings_dialog`.
- Константы `TAG_DIMENSION`/`TAG_LABEL` → дефолты переезжают в `Config`; `tag_name_for` читает `Config.tag_dimension/tag_label` — смена имени тега действует сразу, без перезапуска.
- `VERSION = '0.2.0'` (и в регистраторе, и в description — «теги настраиваются в меню Настройки…»).
- В существующее подменю первым пунктом: **«Настройки…»** (`show_settings`), затем разделитель, далее прежние пункты.

## 3. settings_dialog.rb — диалог
- `UI::HtmlDialog.new(dialog_title: 'DN1Sup AutoSelect Tag — Настройки', preferences_key: 'dn1sup_autoselect_tag_settings', width: 440, height: 360, style: STYLE_DIALOG)`, файл `html/index.html`, один переиспользуемый `@dialog` (как в ext_manager: `bring_to_front` если уже открыт).
- Ruby → JS: `execute_script("window.loadSettings(#{JSON.generate(data)})")`, где data = `{ dimension:, label:, tags: [имена тегов активной модели, отсортированные] }`.
- JS → Ruby (add_action_callback): `ready` → push настроек; `save(json)` → `JSON.parse`, записать в `Config`, закрыть диалог; `cancel` → закрыть.
- После сохранения — вопрос `UI.messagebox`: «Переназначить новые теги существующим размерам и меткам в модели?» При согласии — обход `model.entities` и всех `model.definitions` (`grep(Sketchup::Dimension)` / `(Sketchup::Text)`), внутри `model.start_operation('DN1Sup: теги', true)` … `commit` (одно Undo, пропуск `deleted?`).

## 4. html/index.html — UI
- Одностраничный файл без сборки, в стиле `dn1sup_ext_manager`: тёмная тема на CSS-переменных (#0b1120 фон, #3b82f6 акцент), Segoe UI 13px, весь текст русский.
- Две строки: «Тег размеров» и «Тег текстовых меток» — `input` + `datalist` со списком тегов модели (выбор существующего + свободный ввод нового в одном поле).
- Кнопки «Сохранить» и «Отмена», закрытие по Escape.
- Хелпер `callRuby(name, ...args)` с фолбэком-заглушкой вне SketchUp (как в ext_manager) — страницу можно открыть в браузере для проверки; `callRuby('ready')` по `DOMContentLoaded`; сбор — `sketchup.save(JSON.stringify({dimension, label}))`.

## 5. Прочие файлы
- Регистратор `dn1sup_autoselect_tag.rb` — как в монорепо, версия 0.2.0.
- `.sketchup_dev.json` — манифест dev-копии.
- `dn1sup_updater.rb` — копия из монорепо (на него ссылается main.rb).
- Старый `auto_tag_dimension_label.rb` → `archive/` (без изменений), README обновить.

## 6. Проверка (в живом SketchUp через sketchup-mcp)
1. Синтаксис: `ext_check` (Ruby 3.2 SketchUp).
2. `ext_install` + `ext_reload` в работающий SketchUp.
3. Через `console_eval`: вызвать `show_settings`, убедиться, что диалог открылся без ошибок; сохранить тестовые имена («Размеры», «Метки») → проверить `Sketchup.read_default('dn1sup_autoselect_tag', ...)` и что новая размерность получает тег «Размеры».
4. Проверить переназначение существующим: создать размер до смены тега, пересохранить с подтверждением, убедиться что `entity.layer` сменился и всё откатывается одним Undo.
5. `index.html` открыть в браузере (mock-режим) и проверить вёрстку/взаимодействие.

## Вне рамок (после согласования)
Синхронизация результата в монорепо (`src/`, `registry.json`, сборка .rbz) — отдельно, если понадобится.