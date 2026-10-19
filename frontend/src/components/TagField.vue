<script setup>
const model = defineModel({ type: String, default: '' })

defineProps({
  label: { type: String, required: true },
  placeholder: { type: String, default: '' }
})

const emit = defineEmits(['field-focus', 'field-blur'])
</script>

<template>
  <label class="block">
    <span class="mb-1 block text-xs font-medium text-slate-500 dark:text-slate-400">{{ label }}</span>
    <input
      type="text"
      v-model="model"
      :placeholder="placeholder"
      list="tag-options"
      autocomplete="off"
      spellcheck="false"
      @focus="emit('field-focus')"
      @blur="emit('field-blur')"
      class="w-full rounded-md border border-slate-300 bg-white px-2.5 py-1.5 text-sm text-slate-800 transition-colors placeholder:text-slate-400 focus:border-sky-500 focus:ring-2 focus:ring-sky-500/40 focus:outline-none dark:border-slate-700 dark:bg-slate-800 dark:text-slate-100 dark:placeholder:text-slate-500 dark:focus:ring-sky-500/50"
    />
  </label>
</template>
