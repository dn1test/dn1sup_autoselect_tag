# Общее вложенное меню DN1SUP для всех расширений

## Цель
В меню «Расширения» один общий корень **DN1SUP**, внутри него — вложенные меню каждого расширения. Ничего не дублируется: ни корень, ни вложенные меню, ни при повторной загрузке (hot-reload).

## Принцип (по фактам из доков SU2026.2 и кода соседей)
- `Sketchup::Menu` **не умеет** искать подменю по имени и **не умеет удалять** пункты (только add_item/add_separator/add_submenu/set_validation_proc) → единственный надёжный способ «не дублировать» — кэш меню в глобальных переменных на всю сессию.
- Соседи уже кэшируют корень, но в **две разные глобальные**: `$dn1sup_menu` (comp_add_view) и `$dn1sup_common_menu` (time_project2) → сейчас возможны два корня DN1SUP. Новый код читает `$dn1sup_menu || $dn1sup_common_menu` и **пишет обе** — все расширения сходятся к одному корню.
- Пункты меню — диспетчеры через полные пути констант (`Dn1sup::AutoSelectTag::SettingsDialog.show` и т.п.) → после hot-reload closure вызывает свежий код, пункты не плодятся (добавляются только при первом создании подменю).
- `file_loaded?`-блок в autoselect_tag заменяется на `setup!`/`unload!` (скилл: file_loaded блокирует пересоздание меню).
- Алфавитный порядок загрузки: autoselect_tag грузится первым и создаёт корень — соседи переиспользуют.

## Изменения

**1. `dn1sup_autoselect_tag` (основа)** — `U:\dn1code\sketchup_ext\dn1sup_autoselect_tag\dn1sup_autoselect_tag\dn1sup_autoselect_tag\main.rb`:
- `module_function common_menu` — find-or-create корня `UI.menu('Extensions').add_submenu('DN1SUP')`, всегда синхронизирует обе глобальные.
- `setup!` (вызов внизу файла вместо `unless file_loaded?…`): `install` (наблюдатель AppObserver кэшируется в глобальную `$dn1sup_autoselect_app_observer` + флаг `$dn1sup_autoselect_installed` — без дублей наблюдателей при reload); вложенное меню `$dn1sup_menu_autoselect_tag ||= common_menu.add_submenu('AutoSelect Tag')`; пункты: «Настройки...», разделитель, «Проверить обновления сейчас», «Страница релизов на GitHub»; отложенная проверка обновлений (15 с, один раз за сессию, глобальный флаг).
- Новый `unload!`: снять AppObserver, остановить таймер. Меню не удаляется (API не умеет) и не дублируется благодаря кэшу.
- Версия 0.2.0 → **0.2.1** в main.rb (`VERSION`) и регистраторе (`extension.version`); README.MD — новый путь меню.

**2. Синхронизация соседей** (по 2 строки): 
- `dn1sup_comp_add_view\su_component_add_view\main.rb` (~стр. 33): перед `||=` подтянуть `$dn1sup_common_menu`, после создания записать в обе.
- `dn1sup_time_project2\...\main.rb` (`setup_ui`): то же зеркально.

**3. Перенос под корень**:
- `dn1sup_export_pdf2\dn1sup_export_pdf2\main.rb` (~стр. 136): корень DN1SUP вместо прямого подменю в Plugins; подпись пункта сохраняется.
- `dn1sup_extensions\src\dn1sup_ext_manager\main.rb` (стр. 481): то же.

**4. Мост** `C:\...\Plugins\dn1sup_mcp2_bridge\dn1sup_mcp2_bridge.rb` (стр. 442): `UI.menu('DN1SUP')` (не находит вложенное меню, падает в rescue) → `($dn1sup_menu || $dn1sup_common_menu || UI.menu('Extensions')).add_submenu('Bridge')`. Сначала поищу исходник моста в `U:\dn1code\mcp` — если найдётся, правлю в source, иначе прямо в Plugins (перезапись только при переустановке моста).

## Проверка
1. `ruby -c` всех правленых файлов (офлайн, сразу).
2. SketchUp сейчас закрыт → попрошу запустить (однократно, без цикла ретраев). Затем: `ext_check` (синтаксис Ruby 3.2 внутри SU) → `ext_install` force + `ext_reload` для 5 расширений → `console_eval`: `$dn1sup_menu.equal?($dn1sup_common_menu) # => true`, повторный reload autoselect_tag — объект подменю не меняется (нет дублей).
3. `ext_pack` → dist `dn1sup_autoselect_tag-0.2.1.rbz`. Итог — глазами: Расширения → DN1SUP → {AutoSelect Tag, Comp Add View, Time Project 2, Экспорт PDF, Extension Store, Bridge}.

## Заметки
- Дубли корня из текущей сессии (если были) исчезнут только после перезапуска SketchUp.
- rbz соседей не пересобираю (версии не менял) — при публикации обновить пакеты.
- Меню «Автовыбор» label'ов соседей не меняю (только родитель).