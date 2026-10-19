<script setup>
defineProps({
  hint: { type: String, default: '' },
  status: { type: String, default: '' },
  busy: { type: Boolean, default: false }
})
</script>

<template>
  <div
    class="flex shrink-0 items-center gap-2 border-t border-slate-200 bg-slate-100/70 px-4 py-1.5 text-xs dark:border-slate-800 dark:bg-slate-800/50"
    role="status"
    aria-live="polite"
  >
    <span
      class="h-1.5 w-1.5 shrink-0 rounded-full"
      :class="busy ? 'animate-pulse bg-amber-500' : 'bg-emerald-500'"
      aria-hidden="true"
    />
    <span class="min-w-0 flex-1 truncate text-slate-500 dark:text-slate-400" :title="hint">{{ hint }}</span>
    <span class="shrink-0 text-slate-400 dark:text-slate-500">{{ status }}</span>
  </div>
</template>
