# frozen_string_literal: true
# Тесты сопоставления правил «имя компонента → тег».
# rule_tag_for_names — чистая функция (оба окружения); кандидаты имён и
# назначение тега — на фейковых классах вне SketchUp и на настоящих
# компонентах внутри него (в прерванной операции, без следов в модели).

require_relative 'test_helper'

module Dn1sup
  module AutoSelectTag
    module Test
      # --- Чистая сверка rule_tag_for_names ----------------------------------

      test 'без правил совпадений нет' do
        Test.with_saved_rules do
          assert_nil AutoSelectTag.rule_tag_for_names(['Фасад левый 600'])
        end
      end

      test 'подстрока без учёта регистра (кириллица)' do
        Test.with_saved_rules do
          Config.name_rules = [{ trigger: 'фасад', tag: 'Фасады' }]
          assert_equal 'Фасады', AutoSelectTag.rule_tag_for_names(['ФАСАД ЛЕВЫЙ 600'])
          assert_equal 'Фасады', AutoSelectTag.rule_tag_for_names(['Стенка Фасад нижний'])
        end
      end

      test 'срабатывает любое из слов-триггеров' do
        Test.with_saved_rules do
          Config.name_rules = [{ trigger: 'дверь, окно', tag: 'Проёмы' }]
          assert_equal 'Проёмы', AutoSelectTag.rule_tag_for_names(['Стена с окном'])
          assert_equal 'Проёмы', AutoSelectTag.rule_tag_for_names(['дверь двусторонняя'])
        end
      end

      test 'порядок правил: первое совпавшее выигрывает' do
        Test.with_saved_rules do
          Config.name_rules = [
            { trigger: 'фасад', tag: 'Первое' },
            { trigger: 'дверь', tag: 'Второе' }
          ]
          assert_equal 'Первое', AutoSelectTag.rule_tag_for_names(['дверь + фасад'])
        end
      end

      test 'нет совпадения — nil' do
        Test.with_saved_rules do
          Config.name_rules = [{ trigger: 'фасад', tag: 'Фасады' }]
          assert_nil AutoSelectTag.rule_tag_for_names(['Корпус 600'])
        end
      end

      test 'совпадение по части слова (подстрока)' do
        Test.with_saved_rules do
          Config.name_rules = [{ trigger: 'фас', tag: 'Короткий' }]
          assert_equal 'Короткий', AutoSelectTag.rule_tag_for_names(['Фасад 600'])
        end
      end

      # --- Кандидаты имён и назначение тега ----------------------------------

      if defined?(Sketchup::ComponentInstance) && !Sketchup.const_defined?(:REGISTRY)
        # Фикстура на настоящей модели: создание и уборка — в операциях.
        # В некоторых окружениях SU2026.2 (обсидер-плагины) commit_operation
        # стирает созданные экземпляры — тогда тест помечается skip, а не
        # проваливается. Обёртки сущностей протухают между операциями —
        # наружу отдаётся лямбда повторного поиска по persistent_id.
        def self.with_scratch_component(model, definition_name:, instance_name:)
          model.start_operation('DN1Sup AutoSelect Tag: тест — создать', true)
          definition = model.definitions.add(definition_name)
          instance = model.entities.add_instance(definition, Geom::Transformation.new)
          instance.name = instance_name if instance_name
          pid = instance.persistent_id
          model.commit_operation
          find_instance = lambda do
            model.entities.to_a.find { |e| e.persistent_id == pid }
          end
          begin
            skip('окружение стирает тестовые экземпляры при фиксации операции') if find_instance.call.nil?
            yield definition, find_instance
          ensure
            model.start_operation('DN1Sup AutoSelect Tag: тест — убрать', true)
            leftover = find_instance.call
            leftover.erase if leftover
            model.definitions.remove(definition) unless definition.deleted?
            model.commit_operation
          end
        end

        test 'компонент: кандидаты из имени экземпляра и определения' do
          model = Sketchup.active_model
          skip('нет активной модели') if model.nil?
          Test.with_scratch_component(
            model, definition_name: 'RuleTest_Dver_900', instance_name: 'Дверь двусторонняя'
          ) do |_definition, find_instance|
            instance = find_instance.call
            assert_equal ['Дверь двусторонняя', 'RuleTest_Dver_900'],
                         AutoSelectTag.component_name_candidates(instance)

            Test.set_rules_raw('дверь => Двери')
            assert_equal 'Двери', AutoSelectTag.tag_name_for_component(instance)
            assert AutoSelectTag.taggable?(instance)
            assert_equal 'Двери', AutoSelectTag.tag_name_for(instance)
          end
        end

        test 'без правил компонент не тегируется' do
          model = Sketchup.active_model
          skip('нет активной модели') if model.nil?
          Test.with_scratch_component(
            model, definition_name: 'RuleTest_Korpus', instance_name: nil
          ) do |_definition, find_instance|
            Test.set_rules_raw('[]')
            instance = find_instance.call
            assert !AutoSelectTag.taggable?(instance)
            assert_nil AutoSelectTag.tag_name_for_component(instance)
            assert !AutoSelectTag.assign_tag(model, instance, nil)
          end
        end

        # retag_existing сам открывает операцию, а операции в SketchUp не
        # вкладываются (новая неявно закрывает предыдущую) — изменения идут
        # вживую, уборка — в собственной операции фикс-туры выше. Правило
        # подменяется синглтон-методом Config: запись в реестр между запусками
        # тестов может читаться с запаздыванием, а триггер уникальный, чтобы
        # не задевать реальные компоненты модели пользователя.
        test 'retag_existing создаёт тег и назначает компонент (один перенос)' do
          model = Sketchup.active_model
          skip('нет активной модели') if model.nil?
          original_rules = Config.method(:name_rules)
          Config.define_singleton_method(:name_rules) do
            [{ words: ['ruletest_uniq'], tag: 'RuleTest_Tag' }]
          end
          begin
            Test.with_scratch_component(
              model, definition_name: 'RuleTest_Uniq_Fasad', instance_name: 'RuleTest_Uniq фасад левый'
            ) do |_definition, find_instance|
              count = AutoSelectTag.retag_existing(model)
              assert_equal 1, count
              fresh = find_instance.call
              assert fresh, 'тестовый экземпляр пропал из модели'
              assert_equal 'RuleTest_Tag', fresh.layer.name
              # Повторный прогон ничего не переносит — уже в нужном теге.
              assert_equal 0, AutoSelectTag.retag_existing(model)
            end
          ensure
            Config.define_singleton_method(:name_rules, original_rules)
          end
        end
      else
        # Вне SketchUp: фейковые компоненты поверх стаба Sketchup.
        fake_class = Class.new(Sketchup::ComponentInstance) do
          attr_accessor :name, :definition
        end

        def self.make_fake(fake_class, instance_name, definition_name)
          fake = fake_class.new
          fake.name = instance_name
          fake.definition = Struct.new(:name).new(definition_name)
          fake
        end

        test 'фейковый компонент: имя экземпляра срабатывает' do
          Test.with_saved_rules do
            Config.name_rules = [{ trigger: 'дверь', tag: 'Двери' }]
            fake = make_fake(fake_class, 'Дверь 900', 'Корпус')
            assert_equal 'Двери', AutoSelectTag.tag_name_for_component(fake)
            assert AutoSelectTag.taggable?(fake)
          end
        end

        test 'фейковый компонент: имя определения срабатывает' do
          Test.with_saved_rules do
            Config.name_rules = [{ trigger: 'фасад', tag: 'Фасады' }]
            fake = make_fake(fake_class, '', 'Фасад левый 600')
            assert_equal 'Фасады', AutoSelectTag.tag_name_for_component(fake)
          end
        end

        test 'фейковый компонент без имён и не-компонент — nil' do
          Test.with_saved_rules do
            Config.name_rules = [{ trigger: 'фасад', tag: 'Фасады' }]
            assert_nil AutoSelectTag.tag_name_for_component(make_fake(fake_class, '', ''))
            assert_nil AutoSelectTag.tag_name_for_component(Object.new)
            assert !AutoSelectTag.taggable?(Object.new)
          end
        end
      end
    end
  end
end
