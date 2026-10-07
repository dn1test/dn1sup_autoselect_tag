# frozen_string_literal: true
# =============================================================================
# dn1sup_autoselect_tag/test/run_all.rb — локальный запуск всех тестов
# (в обычном Ruby, без SketchUp). Тесты настоящих компонентов помечаются
# skip (их ветка живёт только внутри SketchUp).
# Запуск: ruby test/run_all.rb
# =============================================================================

require_relative 'test_helper'

Dir.glob(File.join(__dir__, '*_test.rb')).sort.each do |file|
  next if File.expand_path(file) == File.expand_path(__FILE__)
  require file
end

report = Dn1sup::AutoSelectTag::Test.run!

puts '————————————————————————————————————'
puts "Тестов: #{report['total']}  Прошло: #{report['passed']}  " \
      "Провалено: #{report['failures'].size}  Пропущено: #{report['skipped'].size}  " \
      "за #{report['duration_ms']} мс"

report['failures'].each do |failure|
  puts "\n✗ #{failure['name']}\n  #{failure['error']}"
  Array(failure['backtrace']).each { |line| puts "    #{line}" }
end
report['skipped'].each { |s| puts "  ⊘ #{s['name']}: #{s['reason']}" }

exit(report['failures'].empty? ? 0 : 1)
