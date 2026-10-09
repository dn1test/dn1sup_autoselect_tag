<script setup>
const model = defineModel({ type: String, default: '' })

defineProps({
  label: { type: String, required: true },
  placeholder: { type: String, default: '' }
})
</script>

<template>
  <label class="block">
    <span class="mb-1 block text-xs font-medium text-zinc-500 dark:text-zinc-400">{{ label }}</span>
    <input
      type="text"
      v-model="model"
      :placeholder="placeholder"
      list="tag-options"
      autocomplete="off"
      spellcheck="false"
      class="w-full rounded-md border border-zinc-300 bg-white px-2.5 py-1.5 text-sm text-zinc-800 transition-colors placeholder:text-zinc-400 focus:border-sky-500 focus:ring-2 focus:ring-sky-500/40 focus:outline-none dark:border-zinc-600/70 dark:bg-zinc-800 dark:text-zinc-100 dark:placeholder:text-zinc-500 dark:focus:ring-sky-500/50"
    />
  </label>
</template>
