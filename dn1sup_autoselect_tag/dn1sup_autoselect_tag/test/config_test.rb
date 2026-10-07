# frozen_string_literal: true
# Тесты Config: правила «слова-триггеры → тег» (нормализация, валидация,
# round-trip через реестр, кэш).

require_relative 'test_helper'

module Dn1sup
  module AutoSelectTag
    module Test
      test 'правила по умолчанию пустые' do
        Test.with_saved_rules do
          assert_equal [], Config.name_rules
        end
      end

      test 'запись и чтение: слова в нижнем регистре, без дублей и пустых' do
        Test.with_saved_rules do
          Config.name_rules = [{ trigger: ' Фасад, фасад; ДВЕРЬ, , ', tag: ' Фасады ' }]
          assert_equal [{ words: %w[фасад дверь], tag: 'Фасады' }], Config.name_rules
        end
      end

      test 'битые правила отбрасываются' do
        Test.with_saved_rules do
          Config.name_rules = [
            { trigger: '',      tag: 'ПустойТриггер' },
            { trigger: 'окно',  tag: '' },
            { trigger: 'окно',  tag: nil },
            'мусор',
            nil,
            { trigger: 'дверь', tag: 'Двери' }
          ]
          assert_equal [{ words: %w[дверь], tag: 'Двери' }], Config.name_rules
        end
      end

      test 'ключи правил допустимы в строковой форме (как из JSON)' do
        Test.with_saved_rules do
          Config.name_rules = [{ 'trigger' => 'стол, стул', 'tag' => 'Мебель' }]
          assert_equal [{ words: %w[стол стул], tag: 'Мебель' }], Config.name_rules
        end
      end

      test 'round-trip через реестр сохраняет правила' do
        Test.with_saved_rules do
          Config.name_rules = [
            { trigger: 'дверь, окно', tag: 'Проёмы' },
            { trigger: 'фасад',       tag: 'Фасады' }
          ]
          assert_equal [
            { words: %w[дверь окно], tag: 'Проёмы' },
            { words: %w[фасад],      tag: 'Фасады' }
          ], Config.name_rules
        end
      end

      test 'хранимый формат: строки без разделителя и битые отбрасываются' do
        Test.with_saved_rules do
          Test.set_rules_raw("дверь, окно => Проёмы\nмусор без разделителя\n\nфасад => Фасады")
          assert_equal [
            { words: %w[дверь окно], tag: 'Проёмы' },
            { words: %w[фасад],      tag: 'Фасады' }
          ], Config.name_rules
        end
      end

      test 'правила с переводом строки или «=>» внутри отбрасываются' do
        Test.with_saved_rules do
          Config.name_rules = [
            { trigger: "дверь\nдве", tag: 'X' },
            { trigger: 'окно',       tag: 'Y=>Z' },
            { trigger: 'стена',      tag: 'Ок' }
          ]
          assert_equal [{ words: %w[стена], tag: 'Ок' }], Config.name_rules
        end
      end

      test 'после записи читается из кэша, а не из реестра' do
        Test.with_saved_rules do
          Config.name_rules = [{ trigger: 'дверь', tag: 'Двери' }]
          # Правка реестра мимо Config не должна влиять до сброса кэша.
          Sketchup.write_default(Config::SECTION, Config::RULES_KEY, '[]')
          assert_equal [{ words: %w[дверь], tag: 'Двери' }], Config.name_rules
        end
      end
    end
  end
end
