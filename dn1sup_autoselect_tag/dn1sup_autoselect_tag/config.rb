# frozen_string_literal: true

# Настройки расширения. Хранятся в реестре SketchUp (Sketchup.read_default /
# write_default): переживают перезагрузку расширения и переустановку, файлов
# не создают. Раздел — id расширения (совпадает с ID в main.rb).
module Dn1sup
  module AutoSelectTag
    module Config
      SECTION = 'dn1sup_autoselect_tag'

      DEFAULT_TAG_DIMENSION = 'Dimension'
      DEFAULT_TAG_LABEL     = 'Label'

      KEYS = {
        tag_dimension: DEFAULT_TAG_DIMENSION,
        tag_label:     DEFAULT_TAG_LABEL
      }.freeze

      module_function

      # Имя тега для размеров.
      def tag_dimension
        read(:tag_dimension)
      end

      # Имя тега для текстовых меток.
      def tag_label
        read(:tag_label)
      end

      def tag_dimension=(value)
        write(:tag_dimension, value)
      end

      def tag_label=(value)
        write(:tag_label, value)
      end

      def read(key)
        default = KEYS.fetch(key)
        normalize(Sketchup.read_default(SECTION, key.to_s, default), default)
      end

      def write(key, value)
        Sketchup.write_default(SECTION, key.to_s, normalize(value, KEYS.fetch(key)))
      end

      # Пустое или нечитаемое значение откатывается к умолчанию.
      def normalize(value, default)
        name = value.to_s.strip
        name.empty? ? default : name
      end
    end
  end
end
