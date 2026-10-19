<script setup>
const trigger = defineModel('trigger', { type: String, default: '' })
const tag = defineModel('tag', { type: String, default: '' })

const emit = defineEmits(['remove', 'focus-field', 'field-blur'])

const inputClass =
  'min-w-0 rounded-md border border-slate-300 bg-white px-2.5 py-1 text-sm text-slate-800 transition-colors placeholder:text-slate-400 focus:border-sky-500 focus:ring-2 focus:ring-sky-500/40 focus:outline-none dark:border-slate-700 dark:bg-slate-800 dark:text-slate-100 dark:placeholder:text-slate-500 dark:focus:ring-sky-500/50'
</script>

<template>
  <div class="flex items-center gap-2">
    <input
      type="text"
      v-model="trigger"
      data-rule-trigger
      placeholder="слова-триггеры через запятую"
      autocomplete="off"
      spellcheck="false"
      @focus="emit('focus-field', 'trigger')"
      @blur="emit('field-blur')"
      :class="inputClass"
      class="flex-1"
    />
    <span class="shrink-0 text-sm text-slate-400 dark:text-slate-500" aria-hidden="true">&rarr;</span>
    <input
      type="text"
      v-model="tag"
      list="tag-options"
      placeholder="тег"
      autocomplete="off"
      spellcheck="false"
      @focus="emit('focus-field', 'tag')"
      @blur="emit('field-blur')"
      :class="inputClass"
      class="w-32"
    />
    <button
      type="button"
      title="Удалить правило"
      aria-label="Удалить правило"
      class="flex h-7 w-7 shrink-0 items-center justify-center rounded-md text-base leading-none text-slate-400 transition-colors hover:bg-red-500/10 hover:text-red-500 dark:text-slate-500 dark:hover:text-red-400"
      @click="emit('remove')"
    >
      &times;
    </button>
  </div>
</template>
