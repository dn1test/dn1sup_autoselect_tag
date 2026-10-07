# frozen_string_literal: true

require 'json'

module Dn1sup
  module AutoSelectTag
    # Диалог настроек: теги размеров/меток и правила «слова-триггеры → тег»
    # для компонентов. В поле выбирается существующий тег модели или вписывается
    # новое имя — тег будет создан при первом назначении.
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
          scrollable:      true,
          resizable:       true,
          width:           480,
          height:          560,
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

      # Текущие настройки, правила и список тегов активной модели.
      def push_settings
        data = {
          dimension: Config.tag_dimension,
          label:     Config.tag_label,
          rules:     Config.name_rules.map { |rule| { trigger: rule[:words].join(', '), tag: rule[:tag] } },
          tags:      Sketchup.active_model.layers.map(&:name).sort
        }
        @dialog.execute_script("window.loadSettings(#{JSON.generate(data)});")
      end

      # --- JS -> Ruby ---------------------------------------------------------

      # json — строка {"dimension": "...", "label": "...", "rules": [...]}.
      def apply_settings(json)
        data = JSON.parse(json.to_s)
        raise ArgumentError, 'Ожидался объект настроек' unless data.is_a?(Hash)

        Config.tag_dimension = data['dimension']
        Config.tag_label     = data['label']
        Config.name_rules    = data['rules']
        close
        offer_retag
      end

      def offer_retag
        answer = UI.messagebox(
          "Настройки сохранены.\r\n\r\nПрименить их к существующим размерам, меткам и компонентам в модели?",
          MB_YESNO
        )
        retag_existing(Sketchup.active_model) if answer == IDYES
      end
    end
  end
end
