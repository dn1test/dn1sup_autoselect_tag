# frozen_string_literal: true

begin
  require 'sketchup.rb'
rescue LoadError
  # Outside SketchUp
end

module Dn1sup
  module AutoSelectTag
    ID      = 'dn1sup_autoselect_tag'
    VERSION = '0.3.0'
    REPO    = 'dn1test/sketchup-dn1sup-extensions'
    ASSET   = "#{ID}.rbz"
    PAGE_URL = "https://github.com/#{REPO}/releases"
    MANIFEST = { id: ID, repo: REPO, version: VERSION, asset: ASSET }.freeze

    PLUGIN_DIR = File.dirname(__FILE__).freeze

    Sketchup.require 'dn1sup_autoselect_tag/dn1sup_updater'
    Sketchup.require 'dn1sup_autoselect_tag/config'
    Sketchup.require 'dn1sup_autoselect_tag/settings_dialog'

    @pending = []
    @flush_scheduled = false

    module_function

    # --- Основная функциональность ------------------------------------------

    # Возвращает существующий тег или создаёт новый.
    def ensure_tag(model, name)
      tags = model.layers
      tags[name] || tags.add(name)
    end

    # Назначает тег сущности; сущности без поддержки тегов молча пропускаются.
    def assign_tag(model, entity, name)
      tag = ensure_tag(model, name)
      return if entity.layer == tag
      entity.layer = tag
    rescue StandardError
      nil
    end

    # Имена тегов берутся из настроек (Config) — действуют сразу после смены.
    def tag_name_for(entity)
      entity.is_a?(Sketchup::Dimension) ? Config.tag_dimension : Config.tag_label
    end

    def taggable?(entity)
      entity.is_a?(Sketchup::Dimension) || entity.is_a?(Sketchup::Text)
    end

    # Менять модель внутри onElementAdded небезопасно (элемент ещё создаётся
    # инструментом SketchUp) — назначение тега откладывается на нулевой таймер.
    def defer_assign(model, entity)
      return unless taggable?(entity)
      if defined?(UI) && UI.respond_to?(:start_timer)
        @pending << [model, entity]
        schedule_flush
      else
        assign_tag(model, entity, tag_name_for(entity))
      end
    end

    def schedule_flush
      return if @flush_scheduled
      @flush_scheduled = true
      UI.start_timer(0, false) { flush_pending }
    end

    def flush_pending
      @flush_scheduled = false
      pending = @pending
      @pending = []
      pending.each do |model, entity|
        next if entity.respond_to?(:deleted?) && entity.deleted?
        assign_tag(model, entity, tag_name_for(entity))
      end
    rescue StandardError
      nil
    end

    # --- Наблюдатели ----------------------------------------------------------

    # Назначает теги новым размерам и меткам по мере их появления.
    class EntitiesObserver < Sketchup::EntitiesObserver
      def onElementAdded(entities, entity)
        model = entities.respond_to?(:model) ? entities.model : Sketchup.active_model
        AutoSelectTag.defer_assign(model, entity)
      rescue StandardError
        nil
      end
    end

    # Подключает наблюдатель сущностей к новым определениям компонентов.
    class DefinitionsObserver < Sketchup::DefinitionsObserver
      def onComponentAdded(_definitions, definition)
        return if definition.nil?
        AutoSelectTag.attach_entities_observer(definition.entities)
      rescue StandardError
        nil
      end
    end

    # Подключает наблюдатели уровня модели к новым/открываемым/активируемым моделям.
    class AppObserver < Sketchup::AppObserver
      def onNewModel(model)
        AutoSelectTag.attach_model(model)
      end

      def onOpenModel(model)
        AutoSelectTag.attach_model(model)
      end

      def onActivateModel(model)
        AutoSelectTag.attach_model(model)
      end
    end

    def attach_entities_observer(entities)
      return if entities.nil?
      @entities_observer ||= EntitiesObserver.new
      entities.add_observer(@entities_observer)
    rescue StandardError
      nil
    end

    # Повторное подключение к той же обёртке модели подавляется; при другой
    # обёртке дубликат безопасен — назначение тега идемпотентно.
    def attach_model(model)
      return if model.nil?
      @attached_models ||= {}
      return if @attached_models.key?(model)
      @attached_models[model] = true

      attach_entities_observer(model.entities)
      model.definitions.each { |definition| attach_entities_observer(definition.entities) }
      @definitions_observer ||= DefinitionsObserver.new
      model.definitions.add_observer(@definitions_observer)
    rescue StandardError
      nil
    end

    # Подключает наблюдатели приложения один раз за сессию: флаг и наблюдатель
    # хранятся в глобальных переменных и переживают перезагрузку расширения.
    def install
      return if $dn1sup_autoselect_installed
      $dn1sup_autoselect_installed = true
      $dn1sup_autoselect_app_observer = AppObserver.new
      Sketchup.add_observer($dn1sup_autoselect_app_observer)
      attach_model(Sketchup.active_model)
    end

    # Dev-режим: перезагрузка всех файлов расширения без рестарта SketchUp.
    def reload(clear_console = true, undo = false)
      verbose = $VERBOSE
      $VERBOSE = nil
      Dir.glob(File.join(PLUGIN_DIR, '**/*.{rb,rbe}')).each { |f| load(f) }
      $VERBOSE = verbose
      UI.start_timer(0, false) { SKETCHUP_CONSOLE.clear } if clear_console && defined?(SKETCHUP_CONSOLE)
      Sketchup.undo if undo
    rescue StandardError => e
      $VERBOSE = verbose
      puts e.message
      puts e.backtrace.join("\n")
      nil
    end

    # --- Меню -----------------------------------------------------------------

    # Общий корень меню всех расширений DN1SUP («Расширения» → DN1SUP).
    # Sketchup::Menu не умеет ни искать подменю по имени, ни удалять пункты,
    # поэтому корень кэшируется в глобальных переменных на всю сессию:
    # первое загрузившееся расширение создаёт его, остальные переиспользуют.
    # Читаем и пишем обе глобальные — $dn1sup_menu (соглашение Comp Add View)
    # и $dn1sup_common_menu (Time Project 2), — чтобы корень не задваивался
    # при любом порядке загрузки расширений.
    def common_menu
      menu = $dn1sup_common_menu || $dn1sup_menu
      menu ||= UI.menu('Extensions').add_submenu('DN1SUP')
      $dn1sup_common_menu = $dn1sup_menu = menu
      menu
    end

    # Устанавливает меню, наблюдателей и отложенную проверку обновлений;
    # вызывается при каждой загрузке файла — повторный вход безопасен.
    # Своё подменю охраняет $dn1sup_menu_autoselect_tag (глобал переживает
    # перезагрузку, подменю создаётся один раз за сессию), а пункты
    # dispatch-атся через полные пути констант, поэтому после горячей
    # перезагрузки вызывают уже свежий код.
    def setup!
      return unless defined?(UI) && UI.respond_to?(:menu)

      install

      unless $dn1sup_menu_autoselect_tag
        menu = $dn1sup_menu_autoselect_tag = common_menu.add_submenu('AutoSelect Tag')
        menu.add_item('Настройки...') { Dn1sup::AutoSelectTag::SettingsDialog.show }
        menu.add_separator
        menu.add_item('Проверить обновления сейчас') do
          Dn1sup::Updater.check!(Dn1sup::AutoSelectTag::MANIFEST.merge(force: true, async: true))
        end
        menu.add_item('Страница релизов на GitHub') { UI.openURL(Dn1sup::AutoSelectTag::PAGE_URL) }
      end

      # Фоновая проверка обновлений один раз за сессию (не раньше, чем через
      # 15 секунд, чтобы не мешать загрузке SketchUp и сети).
      return if $dn1sup_autoselect_startup_check
      $dn1sup_autoselect_startup_check = true
      $dn1sup_autoselect_timer_id = UI.start_timer(15, false) do
        $dn1sup_autoselect_timer_id = nil
        Dn1sup::Updater.check!(Dn1sup::AutoSelectTag::MANIFEST.merge(async: true))
      end
    end

    # Снимает таймер и наблюдатель приложения (ext_reload вызывает перед
    # remove_const). Меню по API удалить нельзя — оно одно на сессию и не
    # дублируется благодаря глобальному кэшу.
    def unload!
      if (id = $dn1sup_autoselect_timer_id)
        UI.stop_timer(id)
        $dn1sup_autoselect_timer_id = nil
      end
      if (observer = $dn1sup_autoselect_app_observer)
        Sketchup.remove_observer(observer)
        $dn1sup_autoselect_app_observer = nil
      end
      $dn1sup_autoselect_installed = false
      nil
    end

    setup!
  end
end
