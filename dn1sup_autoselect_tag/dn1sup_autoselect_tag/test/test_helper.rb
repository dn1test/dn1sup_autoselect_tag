# frozen_string_literal: true
# =============================================================================
# dn1sup_autoselect_tag/test/test_helper.rb — мини-харнесс тестов
# «DN1Sup AutoSelect Tag».
#
# Работает в двух средах:
#   • внутри SketchUp — запуск через ext_test MCP-сервера sketchup-dev;
#   • в обычном Ruby — ruby test/run_all.rb (юнит-тесты логики; без SketchUp
#     поднимается стаб Sketchup с in-memory реестром).
#
# Намеренно НЕ minitest/autorun: у него at_exit-хуки и накопление классов
# между повторными запусками в одном процессе SketchUp. Харнесс можно
# перезапускать сколько угодно (run! сам очищает список).
# =============================================================================

if !defined?(Sketchup)
  # Стаб для прогона вне SketchUp: минимальная поверхность API, которую трогают
  # main.rb/config.rb при загрузке, плюс in-memory реестр для Config.
  module Sketchup
    REGISTRY = {}

    module_function

    # main.rb грузит конфиг/диалог через Sketchup.require (формы путей Plugins);
    # апдейтер вне SketchUp не нужен — пропускается.
    def require(path)
      case path
      when 'dn1sup_autoselect_tag/config'          then require_relative '../config'
      when 'dn1sup_autoselect_tag/settings_dialog' then require_relative '../settings_dialog'
      end
      true
    end

    def read_default(section, key, default = nil)
      REGISTRY.fetch([section, key], default)
    end

    def write_default(section, key, value)
      REGISTRY[[section, key]] = value
      true
    end

    # Фейковые компоненты для тестов сопоставления имён вне SketchUp.
    class ComponentInstance; end

    # Классы, на которые опираются tag_name_for/taggable?.
    class Dimension; end
    class Text;      end

    # Классы-родители обсерверов из main.rb (наследуются при загрузке файла).
    class EntitiesObserver;     end
    class DefinitionsObserver;  end
    class AppObserver;          end
  end
end

require_relative '../main' unless defined?(Dn1sup::AutoSelectTag::VERSION)

module Dn1sup
  module AutoSelectTag
    module Test
      class Failure < StandardError; end
      class Skip    < StandardError; end

      @tests = []

      class << self
        attr_reader :tests

        def test(name, &block)
          @tests << [name, block]
        end

        def assert(condition, msg = 'утверждение ложно')
          raise Failure, msg unless condition
        end

        def assert_equal(expected, actual, msg = nil)
          return if expected == actual

          raise Failure, "#{msg ? "#{msg}: " : ''}ожидали #{expected.inspect}, получили #{actual.inspect}"
        end

        def assert_nil(actual, msg = nil)
          assert(actual.nil?, "#{msg ? "#{msg}: " : ''}ожидали nil, получили #{actual.inspect}")
        end

        def skip(reason = 'пропуск')
          raise Skip, reason
        end

        # Выполняет все зарегистрированные тесты, возвращает хеш-отчёт и
        # очищает список (повторный run! стартует с чистого листа).
        # Ключи отчёта — СТРОЧНЫЕ: через мост (TCP/JSON) Symbol-ключи
        # превращаются в ":total" и клиент их не находит.
        def run!
          results = { 'total' => @tests.size, 'failures' => [], 'skipped' => [] }
          t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          @tests.each do |name, block|
            begin
              block.call
            rescue Skip => e
              results['skipped'] << { 'name' => name, 'reason' => e.message }
            rescue Failure => e
              results['failures'] << { 'name' => name, 'error' => e.message }
            rescue Exception => e # rubocop:disable Lint/RescueException
              results['failures'] << { 'name' => name, 'error' => "#{e.class}: #{e.message}",
                                       'backtrace' => Array(e.backtrace).first(5) }
            end
          end
          results['duration_ms'] = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000).round(1)
          results['passed'] = results['total'] - results['failures'].size - results['skipped'].size
          reset!
          results
        end

        def reset!
          @tests = []
        end

        # Правила «имя → тег» на время блока — исходное значение реестра
        # восстанавливается (в SketchUp это реальные настройки пользователя).
        # Кэш Config сбрасывается при каждом входе/выходе.
        def with_saved_rules
          original = Sketchup.read_default(
            Config::SECTION, Config::RULES_KEY, '[]'
          ).to_s
          set_rules_raw('[]')
          yield
        ensure
          set_rules_raw(original)
        end

        def set_rules_raw(json)
          Sketchup.write_default(Config::SECTION, Config::RULES_KEY, json)
        ensure
          begin
            Config.send(:remove_instance_variable, :@name_rules)
          rescue NameError
            nil
          end
        end
      end
    end
  end
end
