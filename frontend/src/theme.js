const STORAGE_KEY = 'dn1sup_autoselect_tag_theme'

// Тема живёт в localStorage страницы. В HtmlDialog страница открывается с
// file:// — в Chromium-браузерах хранилище доступно, но может быть запрещено
// политикой: тогда молча откатываемся к тёмной теме по умолчанию.
export function loadTheme() {
  try {
    const saved = localStorage.getItem(STORAGE_KEY)
    if (saved === 'light' || saved === 'dark') return saved
  } catch {
    // хранилище недоступно — используем тему по умолчанию
  }
  return 'dark'
}

export function saveTheme(theme) {
  try {
    localStorage.setItem(STORAGE_KEY, theme)
  } catch {
    // переживаем: выбор просто не запомнится
  }
}

export function applyTheme(theme) {
  document.documentElement.classList.toggle('dark', theme === 'dark')
}
