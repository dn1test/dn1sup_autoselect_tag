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

      RULES_KEY = 'name_rules'

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

      # --- Правила «слова-триггеры → тег» для компонентов ---------------------

      # Разделитель правила и тега в хранимой строке. Правила хранятся
      # построчно («слово, слово => Тег»), а не JSON: write_default в SU2026
      # не переживает значений с двойными кавычками (read_default возвращает
      # nil), поэтому JSON в реестр не пишем.
      RULES_SEPARATOR = '=>'

      # Массив правил { words: ['дверь', 'фасад'], tag: 'Фасады' } в порядке
      # следования (первое совпадение выигрывает). Битые/пустые правила
      # отбрасываются. Результат кэшируется до следующей записи.
      def name_rules
        return @name_rules if defined?(@name_rules)
        @name_rules = normalize_rules(read_rules)
      end

      # Принимает массив { trigger: 'дверь, фасад', tag: 'Фасады' } (ключи
      # допустимы и строковые). Валидирует, пишет в реестр, обновляет кэш.
      def name_rules=(rules)
        list = normalize_rules(rules)
        payload = list.map { |rule| "#{rule[:words].join(', ')} #{RULES_SEPARATOR} #{rule[:tag]}" }
        Sketchup.write_default(SECTION, RULES_KEY, payload.join("\n"))
        @name_rules = list
        list
      end

      def read_rules
        Sketchup.read_default(SECTION, RULES_KEY, '').to_s.split("\n")
      end

      def normalize_rules(rules)
        Array(rules).filter_map { |rule| normalize_rule(rule) }
      end

      # Строки — это правила из хранилища («слово, слово => Тег»).
      def normalize_rule(rule)
        return parse_rule_line(rule) if rule.is_a?(String)
        return nil unless rule.is_a?(Hash)

        tag = (rule[:tag] || rule['tag']).to_s.strip
        words = (rule[:trigger] || rule['trigger']).to_s
                      .split(/[;,]/)
                      .map { |word| word.strip.downcase }
                      .reject(&:empty?)
                      .uniq
        return nil if tag.empty? || invalid_rule_text?(tag) || words.empty?
        return nil if words.any? { |word| invalid_rule_text?(word) }

        { words: words, tag: tag }
      end

      def parse_rule_line(line)
        left, right = line.split(RULES_SEPARATOR, 2)
        return nil if right.nil?

        normalize_rule('trigger' => left, 'tag' => right)
      end

      # Перевод строки рвёт хранимое правило на две, '=>' — разделитель
      # правила и тега; правила с такими символами отбрасываются.
      def invalid_rule_text?(text)
        text.include?("\n") || text.include?(RULES_SEPARATOR)
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
