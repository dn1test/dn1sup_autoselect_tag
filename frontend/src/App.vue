<script setup>
import { nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { announceReady, callRuby, onSettings } from './bridge'
import { applyTheme, loadTheme, saveTheme } from './theme'
import TagField from './components/TagField.vue'
import RuleRow from './components/RuleRow.vue'

const dimension = ref('')
const label = ref('')
const rules = ref([])
const tags = ref([])

// Ruby -> JS: настройки, правила и список тегов активной модели.
function handleSettings(data) {
  dimension.value = data.dimension || ''
  label.value = data.label || ''
  rules.value = (data.rules || []).map((rule) => ({
    trigger: rule.trigger || '',
    tag: rule.tag || ''
  }))
  tags.value = data.tags || []
}

function save() {
  callRuby(
    'save',
    JSON.stringify({
      dimension: dimension.value.trim(),
      label: label.value.trim(),
      // как и раньше: строка с непустым триггером ИЛИ тегом сохраняется
      rules: rules.value
        .map((rule) => ({ trigger: rule.trigger.trim(), tag: rule.tag.trim() }))
        .filter((rule) => rule.trigger || rule.tag)
    })
  )
}

function cancel() {
  callRuby('cancel')
}

function addRule() {
  rules.value.push({ trigger: '', tag: '' })
  nextTick(() => {
    const inputs = document.querySelectorAll('[data-rule-trigger]')
    inputs[inputs.length - 1]?.focus()
  })
}

// Esc — отмена, Enter в поле — сохранить (как в vanilla-версии).
function onKeydown(event) {
  if (event.key === 'Escape') {
    cancel()
  } else if (event.key === 'Enter' && event.target.tagName === 'INPUT') {
    save()
  }
}

// Тема: тёмная по умолчанию, выбор запоминается в localStorage.
const theme = ref(loadTheme())
applyTheme(theme.value)
watch(theme, (value) => {
  applyTheme(value)
  saveTheme(value)
})
function toggleTheme() {
  theme.value = theme.value === 'dark' ? 'light' : 'dark'
}

onMounted(() => {
  onSettings(handleSettings)
  document.addEventListener('keydown', onKeydown)
  announceReady()

  // Заглушка для проверки вёрстки в обычном браузере (npm run dev):
  // перезаписывается настоящими настройками, когда 'ready' доходит до Ruby.
  if (import.meta.env.DEV && !window.sketchup) {
    handleSettings({
      dimension: 'Dimension',
      label: 'Label',
      rules: [
        { trigger: 'дверь, дверь двусторонняя', tag: 'Двери' },
        { trigger: 'фасад', tag: 'Фасады' }
      ],
      tags: ['Dimension', 'Label', 'Layer0', 'Размеры', 'Метки', 'Двери', 'Фасады']
    })
  }
})

onBeforeUnmount(() => document.removeEventListener('keydown', onKeydown))
</script>

<template>
  <div
    class="flex h-screen flex-col bg-zinc-100 text-zinc-800 dark:bg-zinc-900 dark:text-zinc-200"
  >
    <header
      class="flex shrink-0 items-center justify-between border-b border-zinc-200 px-4 py-2.5 dark:border-zinc-700/60"
    >
      <h1 class="text-sm font-semibold tracking-tight">Настройки автоназначения</h1>
      <button
        type="button"
        :title="theme === 'dark' ? 'Светлая тема' : 'Тёмная тема'"
        :aria-label="theme === 'dark' ? 'Светлая тема' : 'Тёмная тема'"
        class="rounded-md p-1.5 text-zinc-500 transition-colors hover:bg-zinc-200 hover:text-zinc-700 dark:text-zinc-400 dark:hover:bg-zinc-700/70 dark:hover:text-zinc-200"
        @click="toggleTheme"
      >
        <svg v-if="theme === 'dark'" class="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <circle cx="12" cy="12" r="4" />
          <path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41" />
        </svg>
        <svg v-else class="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" />
        </svg>
      </button>
    </header>

    <main class="flex-1 space-y-5 overflow-y-auto px-4 py-4">
      <section class="space-y-3">
        <h2 class="text-sm font-semibold">Теги автоназначения</h2>
        <TagField v-model="dimension" label="Тег размеров" placeholder="Dimension" />
        <TagField v-model="label" label="Тег текстовых меток" placeholder="Label" />
        <p class="text-xs leading-relaxed text-zinc-500 dark:text-zinc-400">
          Выберите существующий тег из списка или впишите новое имя — тег создастся
          при первом назначении.
        </p>
      </section>

      <hr class="border-zinc-200 dark:border-zinc-700/60" />

      <section class="space-y-2.5">
        <div class="flex items-center justify-between">
          <h2 class="text-sm font-semibold">Правила по имени компонента</h2>
          <button
            type="button"
            class="rounded-md px-2 py-1 text-xs font-medium text-sky-600 transition-colors hover:bg-sky-500/10 dark:text-sky-400 dark:hover:bg-sky-400/10"
            @click="addRule"
          >
            + Добавить правило
          </button>
        </div>

        <div class="space-y-2">
          <p
            v-if="rules.length === 0"
            class="rounded-md border border-dashed border-zinc-300 px-3 py-3 text-xs text-zinc-500 dark:border-zinc-600/70 dark:text-zinc-400"
          >
            Правил нет. Добавьте правило — и компоненты с подходящим именем будут
            переноситься в его тег.
          </p>
          <RuleRow
            v-for="(rule, index) in rules"
            :key="index"
            v-model:trigger="rule.trigger"
            v-model:tag="rule.tag"
            @remove="rules.splice(index, 1)"
          />
        </div>

        <p class="text-xs leading-relaxed text-zinc-500 dark:text-zinc-400">
          Компонент, в имени экземпляра или определения которого есть любое из
          слов-триггеров (без учёта регистра), переносится в тег правила. Правила
          проверяются сверху вниз — первое совпадение выигрывает.
        </p>
      </section>
    </main>

    <footer
      class="flex shrink-0 justify-end gap-2 border-t border-zinc-200 bg-zinc-50 px-4 py-3 dark:border-zinc-700/60 dark:bg-zinc-800/40"
    >
      <button
        type="button"
        class="rounded-md border border-zinc-300 px-3.5 py-1.5 text-sm font-medium transition-colors hover:bg-zinc-200 focus:outline-none focus:ring-2 focus:ring-sky-500/40 dark:border-zinc-600 dark:hover:bg-zinc-700/70 dark:focus:ring-sky-400/40"
        @click="cancel"
      >
        Отмена
      </button>
      <button
        type="button"
        class="rounded-md bg-sky-600 px-3.5 py-1.5 text-sm font-medium text-white transition-colors hover:bg-sky-500 focus:outline-none focus:ring-2 focus:ring-sky-500/40 dark:bg-sky-500 dark:hover:bg-sky-400"
        @click="save"
      >
        Сохранить
      </button>
    </footer>
  </div>

  <datalist id="tag-options">
    <option v-for="name in tags" :key="name" :value="name" />
  </datalist>
</template>
