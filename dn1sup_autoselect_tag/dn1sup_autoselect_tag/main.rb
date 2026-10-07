# frozen_string_literal: true

begin
  require 'sketchup.rb'
rescue LoadError
  # Outside SketchUp
end

module Dn1sup
  def self.common_menu
    @common_menu ||= begin
      legacy = (defined?($dn1sup_common_menu) && $dn1sup_common_menu) || (defined?($dn1sup_menu) && $dn1sup_menu)
      legacy || UI.menu('Extensions').add_submenu('DN1Sup')
    end
  end

  module AutoSelectTag
    ID      = 'dn1sup_autoselect_tag'
    VERSION = '0.4.0'
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
    # Пустое имя (правило не сработало) — ничего не делает.
    def assign_tag(model, entity, name)
      return false if name.nil? || name.to_s.strip.empty?
      tag = ensure_tag(model, name)
      return false if entity.layer == tag
      entity.layer = tag
      true
    rescue StandardError
      false
    end

    # Имя тега для сущности или nil, если подходящего правила нет.
    # Для компонентов (см. tag_name_for_component) nil — «не трогать»,
    # поэтому вызывать только после taggable?.
    def tag_name_for(entity)
      case entity
      when Sketchup::Dimension then Config.tag_dimension
      when Sketchup::Text      then Config.tag_label
      else tag_name_for_component(entity)
      end
    end

    def taggable?(entity)
      case entity
      when Sketchup::Dimension, Sketchup::Text then true
      else !tag_name_for_component(entity).nil?
      end
    end

    # --- Правила «имя компонента → тег» -------------------------------------

    # Имена компонента для сверки с правилами: имя экземпляра и имя определения.
    def component_name_candidates(entity)
      return [] unless entity.is_a?(Sketchup::ComponentInstance)
      names = [entity.name]
      names << entity.definition.name if entity.definition
      names.reject { |name| name.to_s.strip.empty? }
    end

    # Имя тега первого сработавшего правила или nil.
    def tag_name_for_component(entity)
      rule_tag_for_names(component_name_candidates(entity))
    end

    # Чистая сверка имён с правилами: имя тега первого правила, у которого
    # любое слово-триггер входит в любое из имён (без учёта регистра), или nil.
    # Правила проверяются в порядке настройки — первое совпадение выигрывает.
    def rule_tag_for_names(names)
      return nil if names.empty?
      lowered = names.map(&:downcase)
      rule = Config.name_rules.find do |candidate|
        candidate[:words].any? { |word| lowered.any? { |name| name.include?(word) } }
      end
      rule && rule[:tag]
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

    # --- Массовое применение правил -------------------------------------------

    # Переназначает теги существующим размерам/меткам и применяет правила
    # «имя → тег» к компонентам — одна операция Undo. Верхний уровень модели
    # плюс все определения (вложенные определения тоже лежат в model.definitions).
    def retag_existing(model)
      model.start_operation('DN1Sup AutoSelect Tag: применить правила тегов', true)
      count = retag_model_entities(model)
      model.commit_operation
      count
    rescue StandardError
      model.abort_operation
      raise
    end

    def retag_model_entities(model)
      count = 0
      model.entities.each { |entity| count += 1 if retag_entity(model, entity) }
      model.definitions.each do |definition|
        next if definition.nil? || definition.image?
        definition.entities.each { |entity| count += 1 if retag_entity(model, entity) }
      end
      count
    end

    def retag_entity(model, entity)
      return false if entity.respond_to?(:deleted?) && entity.deleted?
      return false unless taggable?(entity)
      assign_tag(model, entity, tag_name_for(entity))
    end

    # Пункт меню: применить правила к активной модели с отчётом пользователю.
    def apply_rules_to_model
      model = Sketchup.active_model
      return if model.nil?
      count = retag_existing(model)
      UI.messagebox("DN1Sup AutoSelect Tag\r\n\r\nПеренесено в теги: #{count}")
    rescue StandardError => e
      UI.messagebox("DN1Sup AutoSelect Tag: #{e.class}: #{e.message}")
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

      # Переименование компонента (Entity Info) не порождает нового элемента:
      # модификация перепроверяет правило тем же отложенным способом,
      # назначение идемпотентно.
      def onElementModified(entities, entity)
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
    # Тесты не загружаются: run_all.rb прогоняет сюиту и вызывает exit.
    def reload(clear_console = true, undo = false)
      verbose = $VERBOSE
      $VERBOSE = nil
      files = Dir.glob(File.join(PLUGIN_DIR, '**/*.{rb,rbe}'))
      files.reject! { |f| f.tr('\\', '/').include?('/test/') }
      files.each { |f| load(f) }
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

    # Общий корень меню всех расширений DN1Sup («Расширения» → DN1Sup).
    # Кэшируется в корневом модуле Dn1sup.common_menu без глобальных переменных.
    def common_menu
      Dn1sup.common_menu
    end

    # Устанавливает меню, наблюдателей и отложенную проверку обновлений;
    # вызывается при каждой загрузке файла — повторный вход безопасен.
    # Своё подменю охраняет @menu_autoselect_tag (глобал переживает
    # перезагрузку, подменю создаётся один раз за сессию), а пункты
    # dispatch-атся через полные пути констант, поэтому после горячей
    # перезагрузки вызывают уже свежий код.
    def setup!
      return unless defined?(UI) && UI.respond_to?(:menu)

      install

      unless @menu_autoselect_tag
        menu = @menu_autoselect_tag = common_menu.add_submenu('AutoSelect Tag')
        menu.add_item('Настройки...') { Dn1sup::AutoSelectTag::SettingsDialog.show }
        menu.add_item('Применить правила к модели') do
          Dn1sup::AutoSelectTag.apply_rules_to_model
        end
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
