<script setup>
import { nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { announceReady, callRuby, onSettings } from './bridge'
import { applyTheme, loadTheme, saveTheme } from './theme'
import TagField from './components/TagField.vue'
import RuleRow from './components/RuleRow.vue'
import HelpDialog from './components/HelpDialog.vue'
import StatusBar from './components/StatusBar.vue'

const dimension = ref('')
const label = ref('')
const rules = ref([])
const tags = ref([])
const version = ref('')
const helpOpen = ref(false)
const updateBusy = ref(false)
// Статусная строка: подсказка слева, состояние работы справа.
const HINT_DEFAULT = 'Готово. Enter — сохранить, Esc — отмена.'
const HINTS = {
  dimension: 'Тег размеров: выберите из списка или впишите новый — создастся при первом назначении.',
  label: 'Тег текстовых меток: выберите из списка или впишите новый.',
  trigger: 'Триггеры через запятую или точку с запятой. Совпадение — без учёта регистра.',
  tag: 'Целевой тег правила: выберите из списка или впишите новый.',
  add: 'Добавить новое правило «слова-триггеры → тег».',
  save: 'Сохранить настройки и предложить применить их к модели.',
  cancel: 'Закрыть без сохранения.'
}
const hint = ref(HINT_DEFAULT)
const statusText = ref('Готов')
function setHint(key) {
  hint.value = HINTS[key] || HINT_DEFAULT
}
function resetHint() {
  hint.value = HINT_DEFAULT
}
let updateTimer = null

// Ruby -> JS: настройки, правила и список тегов активной модели.
function handleSettings(data) {
  dimension.value = data.dimension || ''
  label.value = data.label || ''
  rules.value = (data.rules || []).map((rule) => ({
    trigger: rule.trigger || '',
    tag: rule.tag || ''
  }))
  tags.value = data.tags || []
  if (data.version) version.value = String(data.version)
  updateBusy.value = false
  statusText.value = `Готов · правил: ${rules.value.length}`
  hint.value = HINT_DEFAULT
}

function save() {
  statusText.value = 'Сохранение…'
  hint.value = 'Сохраняем настройки…'
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

// Проверка обновления: сначала локальная папка разработки, потом GitHub.
function checkUpdate() {
  callRuby('check_update')
  updateBusy.value = true
  statusText.value = 'Проверка обновлений…'
  hint.value = 'Проверяем обновления: сначала локальная папка, потом GitHub.'
  clearTimeout(updateTimer)
  updateTimer = setTimeout(() => {
    updateBusy.value = false
    statusText.value = `Готов · правил: ${rules.value.length}`
    hint.value = HINT_DEFAULT
  }, 2500)
}

function addRule() {
  rules.value.push({ trigger: '', tag: '' })
  statusText.value = `Черновик · правил: ${rules.value.length}`
  hint.value = HINTS.trigger
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
      version: '0.6.7',
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
    class="flex h-screen flex-col bg-slate-50 text-slate-800 dark:bg-slate-900 dark:text-slate-200"
  >
    <header
      class="flex shrink-0 items-center justify-between border-b border-slate-200 bg-white px-4 py-3 dark:border-slate-800 dark:bg-slate-900"
    >
      <div class="flex min-w-0 items-center gap-2.5">
        <img src="./assets/logo.svg" width="28" height="28" class="shrink-0" alt="DN1Sup AutoSelect Tag">
        <div class="min-w-0">
          <div class="flex items-center gap-2">
            <h1 class="text-sm font-semibold leading-tight text-slate-800 dark:text-slate-100">DN1Sup AutoSelect Tag</h1>
            <span v-if="version" class="rounded bg-slate-100 px-1.5 py-0.5 text-[10px] text-slate-500 dark:bg-slate-800">v{{ version }}</span>
          </div>
          <p class="text-xs text-slate-500 dark:text-slate-400">Автоназначение тегов размерам, меткам и компонентам</p>
        </div>
      </div>
      <div class="flex items-center gap-1.5">
        <button
          type="button"
          title="Справка"
          aria-label="Справка"
          class="rounded-full p-1.5 text-slate-400 transition-colors hover:bg-slate-100 hover:text-sky-600 dark:text-slate-500 dark:hover:bg-slate-800 dark:hover:text-sky-400"
          @click="helpOpen = true"
        >
          <svg class="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <circle cx="12" cy="12" r="10" />
            <path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3" />
            <path d="M12 17h.01" />
          </svg>
        </button>
        <button
          type="button"
          title="Проверить обновление: сначала локальная папка разработки, потом GitHub"
          aria-label="Проверить обновление"
          class="rounded-full p-1.5 text-slate-400 transition-colors hover:bg-slate-100 hover:text-sky-600 dark:text-slate-500 dark:hover:bg-slate-800 dark:hover:text-sky-400"
          @click="checkUpdate"
        >
          <svg class="h-4 w-4" :class="{ 'animate-spin': updateBusy }" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M21 12a9 9 0 1 1-9-9c2.52 0 4.93 1 6.74 2.74L21 8" />
            <path d="M21 3v5h-5" />
          </svg>
        </button>
        <button
          type="button"
          :title="theme === 'dark' ? 'Светлая тема' : 'Тёмная тема'"
        :aria-label="theme === 'dark' ? 'Светлая тема' : 'Тёмная тема'"
        class="rounded-full p-1.5 text-slate-400 transition-colors hover:bg-slate-100 hover:text-sky-600 dark:text-slate-500 dark:hover:bg-slate-800 dark:hover:text-sky-400"
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
      </div>
    </header>

    <main class="flex-1 space-y-5 overflow-y-auto px-4 py-4">
      <section class="space-y-3">
        <h2 class="text-sm font-semibold text-slate-800 dark:text-slate-100">Теги автоназначения</h2>
        <TagField v-model="dimension" label="Тег размеров" placeholder="Dimension" @field-focus="setHint('dimension')" @field-blur="resetHint" />
        <TagField v-model="label" label="Тег текстовых меток" placeholder="Label" @field-focus="setHint('label')" @field-blur="resetHint" />
        <p class="text-xs leading-relaxed text-slate-500 dark:text-slate-400">
          Выберите существующий тег из списка или впишите новое имя — тег создастся
          при первом назначении.
        </p>
      </section>

      <hr class="border-slate-200 dark:border-slate-800" />

      <section class="space-y-2.5">
        <div class="flex items-center justify-between">
          <h2 class="text-sm font-semibold text-slate-800 dark:text-slate-100">Правила по имени компонента</h2>
          <button
            type="button"
            class="rounded-md px-2 py-1 text-xs font-medium text-sky-600 transition-colors hover:bg-sky-500/10 dark:text-sky-400 dark:hover:bg-sky-400/10"
            @click="addRule"
            @mouseenter="setHint('add')"
            @mouseleave="resetHint"
            @focus="setHint('add')"
            @blur="resetHint"
          >
            + Добавить правило
          </button>
        </div>

        <div class="space-y-2">
          <p
            v-if="rules.length === 0"
            class="rounded-md border border-dashed border-slate-300 px-3 py-3 text-xs text-slate-500 dark:border-slate-700 dark:text-slate-400"
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
            @focus-field="setHint"
            @field-blur="resetHint"
          />
        </div>

        <p class="text-xs leading-relaxed text-slate-500 dark:text-slate-400">
          Компонент, в имени экземпляра или определения которого есть любое из
          слов-триггеров (без учёта регистра), переносится в тег правила. Правила
          проверяются сверху вниз — первое совпадение выигрывает.
        </p>
      </section>
    </main>

    <footer
      class="flex shrink-0 justify-end gap-2 border-t border-slate-200 bg-white px-4 py-3 dark:border-slate-800 dark:bg-slate-900"
    >
      <button
        type="button"
        class="rounded-md border border-slate-300 px-3.5 py-1.5 text-sm font-medium transition-colors hover:bg-slate-100 focus:outline-none focus:ring-2 focus:ring-sky-500/40 dark:border-slate-700 dark:hover:bg-slate-800 dark:focus:ring-sky-400/40"
        @click="cancel"
        @mouseenter="setHint('cancel')"
        @mouseleave="resetHint"
        @focus="setHint('cancel')"
        @blur="resetHint"
      >
        Отмена
      </button>
      <button
        type="button"
        class="rounded-md bg-sky-600 px-3.5 py-1.5 text-sm font-medium text-white transition-colors hover:bg-sky-500 focus:outline-none focus:ring-2 focus:ring-sky-500/40 dark:bg-sky-500 dark:hover:bg-sky-400"
        @click="save"
        @mouseenter="setHint('save')"
        @mouseleave="resetHint"
        @focus="setHint('save')"
        @blur="resetHint"
      >
        Сохранить
      </button>
    </footer>

    <StatusBar :hint="hint" :status="statusText" :busy="updateBusy" />
  </div>

  <HelpDialog v-if="helpOpen" :version="version" @close="helpOpen = false" />

  <datalist id="tag-options">
    <option v-for="name in tags" :key="name" :value="name" />
  </datalist>
</template>
