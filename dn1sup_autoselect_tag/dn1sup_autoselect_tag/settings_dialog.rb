# frozen_string_literal: true

require 'json'

module Dn1sup
  module AutoSelectTag
    # Диалог настроек: выбор имени тега для размеров и текстовых меток.
    # В поле выбирается существующий тег модели или вписывается новое имя —
    # тег будет создан при первом назначении.
    module SettingsDialog
      module_function

      def show
        if @dialog&.visible?
          @dialog.bring_to_front
          push_settings
          return
        end

        # Закрытый HtmlDialog повторным show не поднимается (страница и
        # колбэки мертвы) — каждый раз создаём заново.
        @dialog = UI::HtmlDialog.new(
          dialog_title:    'DN1Sup AutoSelect Tag — Настройки',
          preferences_key: 'dn1sup_autoselect_tag_settings',
          scrollable:      false,
          resizable:       false,
          width:           440,
          height:          380,
          style:           UI::HtmlDialog::STYLE_DIALOG
        )
        attach_callbacks
        @dialog.set_file(html_path)
        @dialog.show
      rescue StandardError => e
        UI.messagebox("DN1Sup AutoSelect Tag: не удалось открыть настройки\r\n#{e.class}: #{e.message}")
      end

      def close
        @dialog.close if @dialog&.visible?
      end

      # Колбэки HtmlDialog очищаются при закрытии — вешаются перед каждым показом.
      def attach_callbacks
        # Один диспетчер: JS вызывает sketchup.call_ruby('ready'|'save'|'cancel', payload).
        @dialog.add_action_callback('call_ruby') do |_context, action, *args|
          dispatch(action.to_s, args)
        end
      end

      def dispatch(action, args)
        case action
        when 'ready'  then push_settings
        when 'save'   then apply_settings(args[0])
        when 'cancel' then close
        end
      rescue StandardError => e
        UI.messagebox("DN1Sup AutoSelect Tag: #{e.class}: #{e.message}")
      end

      def html_path
        File.join(File.dirname(__FILE__), 'html', 'index.html')
      end

      # --- Ruby -> JS ---------------------------------------------------------

      # Текущие настройки и список тегов активной модели.
      def push_settings
        data = {
          dimension: Config.tag_dimension,
          label:     Config.tag_label,
          tags:      Sketchup.active_model.layers.map(&:name).sort
        }
        @dialog.execute_script("window.loadSettings(#{JSON.generate(data)});")
      end

      # --- JS -> Ruby ---------------------------------------------------------

      # json — строка {"dimension": "...", "label": "..."}.
      def apply_settings(json)
        data = JSON.parse(json.to_s)
        raise ArgumentError, 'Ожидался объект настроек' unless data.is_a?(Hash)

        Config.tag_dimension = data['dimension']
        Config.tag_label     = data['label']
        close
        offer_retag
      end

      def offer_retag
        answer = UI.messagebox(
          "Теги сохранены.\r\n\r\nПереназначить новые теги существующим размерам и меткам в модели?",
          MB_YESNO
        )
        retag_existing(Sketchup.active_model) if answer == IDYES
      end

      # Переназначение существующих размеров/меток — одна операция Undo.
      def retag_existing(model)
        model.start_operation('DN1Sup AutoSelect Tag: переназначить теги', true)
        count = retag_model_entities(model)
        model.commit_operation
        puts "DN1Sup AutoSelect Tag: переназначено сущностей: #{count}" if count.positive?
        count
      rescue StandardError
        model.abort_operation
        raise
      end

      # Верхний уровень модели плюс все определения компонентов (вложенные
      # определения тоже лежат в model.definitions).
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
        return false unless AutoSelectTag.taggable?(entity)

        tag = AutoSelectTag.ensure_tag(model, AutoSelectTag.tag_name_for(entity))
        return false if entity.layer == tag

        entity.layer = tag
        true
      end
    end
  end
end
