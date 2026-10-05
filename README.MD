# DN1Sup AutoSelect Tag

Автоматически назначает теги (слои) размерам и текстовым меткам в SketchUp.
Имена тегов настраиваются в HTML-окне настроек.

## Что делает
- При появлении размеров (`Sketchup::Dimension`) присваивает настраиваемый тег (по умолчанию `Dimension`).
- При появлении текстовых меток (`Sketchup::Text`) присваивает настраиваемый тег (по умолчанию `Label`).
- Работает для геометрии в модели и в новых компонентных определениях.
- Назначение тега отложено до завершения создания элемента (безопасно для текущих инструментов).

## Настройки
**Extensions → DN1SUP → AutoSelect Tag → «Настройки...»** — окно, где для двух
параметров выбирается имя тега:
- «Тег размеров» — тег для размеров;
- «Тег текстовых меток» — тег для меток.

В каждом поле можно выбрать существующий тег модели из списка или вписать
новое имя — тег создастся при первом назначении. После сохранения
предлагается переназначить новые теги всем существующим размерам и меткам
(одна операция Undo).

Настройки хранятся в реестре SketchUp (`Sketchup.read_default` /
`write_default`, раздел `dn1sup_autoselect_tag`) и переживают перезапуск.
Значения по умолчанию — `Dimension` и `Label` (см. `dn1sup_autoselect_tag/config.rb`).

## Установка
1. Возьмите `dn1sup_autoselect_tag.rbz` (архив: регистратор в корне + папка `dn1sup_autoselect_tag/`).
2. SketchUp → Extensions → Extension Manager → Install Extension.
3. Перезапуск SketchUp не обязателен.

## Использование
Работает автоматически при старте SketchUp и при открытии/создании модели.
Меню: Extensions → DN1SUP → AutoSelect Tag → «Настройки...», «Проверить
обновления сейчас», «Страница релизов на GitHub».

## Структура проекта
```
dn1sup_autoselect_tag.rb           # регистратор (в .rbz — в корне архива)
dn1sup_autoselect_tag/
  main.rb                          # логика: обсерверы, меню, dev-reload
  config.rb                        # настройки (реестр SketchUp)
  settings_dialog.rb               # HtmlDialog настроек
  html/index.html                  # UI настроек (Modus Bootstrap, тёмная тема)
  dn1sup_updater.rb                # общий апдейтер (синхронизируется из монорепо)
archive/
  auto_tag_dimension_label.rb      # старая однофайловая версия 1.0 (не устанавливать!)
```

## Разработка
Папка — dev-копия (манифест `.sketchup_dev.json` внутри `dn1sup_autoselect_tag/dn1sup_autoselect_tag/`),
раскладка и структура совпадают с монорепо `dn1sup_extensions/src/dn1sup_autoselect_tag`. Цикл:
1. Правка файлов в этой папке.
2. Установка в живой SketchUp: `ext_install dir=<папка>` (sketchup-mcp) или ручное копирование в `Plugins`.
3. Перезагрузка без рестарта: `Dn1sup::AutoSelectTag.reload` в консоли SketchUp.
   (`ext_reload` не поддерживает вложенный неймспейс `Dn1sup::AutoSelectTag` — purge константы не срабатывает.)

Актуальную версию монорепо не забывать синхронизировать обратно (`src/`,
`registry.json`, сборка `tools/pack.rb dn1sup_autoselect_tag`).

## Совместимость
SketchUp 2024–2026 (Ruby 3.2). Не использовать фичи Ruby новее 3.2.

## Лицензия
MIT

## Автор
dn1sup
