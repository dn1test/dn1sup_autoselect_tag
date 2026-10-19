<script setup>
import { onMounted, onUnmounted } from 'vue'
import { callRuby } from '../bridge.js'

const emit = defineEmits(['close'])
defineProps({
  version: { type: String, default: '' }
})

function onKey(e) {
  if (e.key === 'Escape') emit('close')
}
onMounted(() => window.addEventListener('keydown', onKey))
onUnmounted(() => window.removeEventListener('keydown', onKey))

function openReleases() {
  callRuby('open_releases')
}
</script>

<template>
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/50 p-4"
    @click.self="emit('close')"
  >
    <div class="max-h-full w-full max-w-md overflow-y-auto rounded-xl bg-white shadow-xl dark:bg-slate-900">
      <header class="flex items-center justify-between border-b border-slate-200 px-4 py-3 dark:border-slate-800">
        <h2 class="text-sm font-semibold text-slate-800 dark:text-slate-100">Справка — AutoSelect Tag</h2>
        <button
          type="button"
          title="Закрыть"
          aria-label="Закрыть"
          class="rounded-full p-1.5 text-slate-400 transition-colors hover:bg-slate-100 hover:text-slate-600 dark:text-slate-500 dark:hover:bg-slate-800 dark:hover:text-slate-300"
          @click="emit('close')"
        >
          <svg class="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M18 6 6 18" />
            <path d="m6 6 12 12" />
          </svg>
        </button>
      </header>

      <div class="space-y-4 px-4 py-3 text-xs leading-relaxed text-slate-600 dark:text-slate-300">
        <section>
          <h3 class="mb-1 text-xs font-semibold text-slate-800 dark:text-slate-100">Что делает</h3>
          <p>Автоназначает теги новым размерам и текстовым меткам, а компоненты переносит в теги по правилам «слова в имени → тег».</p>
        </section>

        <section>
          <h3 class="mb-1 text-xs font-semibold text-slate-800 dark:text-slate-100">Как пользоваться</h3>
          <ol class="list-decimal space-y-1 pl-4">
            <li>Выберите теги для размеров и меток (или впишите новые).</li>
            <li>Добавьте правила: триггеры через запятую и целевой тег.</li>
            <li>Нажмите «Сохранить» — при желании примените к существующей модели.</li>
          </ol>
        </section>

        <section>
          <h3 class="mb-1 text-xs font-semibold text-slate-800 dark:text-slate-100">Правила</h3>
          <p>Проверяются сверху вниз, первое совпадение выигрывает. Сравнение без учёта регистра, по имени экземпляра и определения.</p>
        </section>
      </div>

      <footer class="flex items-center justify-between border-t border-slate-200 px-4 py-3 text-xs dark:border-slate-800">
        <span class="text-slate-400 dark:text-slate-500">DN1Sup AutoSelect Tag{{ version ? ` · v${version}` : '' }}</span>
        <button
          type="button"
          class="font-medium text-xs text-sky-600 transition-colors hover:text-sky-700 dark:text-sky-400 dark:hover:text-sky-300"
          @click="openReleases"
        >
          Страница релизов
        </button>
      </footer>
    </div>
  </div>
</template>
