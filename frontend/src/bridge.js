// Мост JS <-> Ruby. Протокол неизменен со времён vanilla-версии UI:
//   JS -> Ruby: sketchup.call_ruby(action, payload) — один диспетчер
//               'ready' | 'save' | 'cancel' в settings_dialog.rb.
//   Ruby -> JS: execute_script("window.loadSettings(<json>)").

export function callRuby(action, payload) {
  if (window.sketchup && typeof window.sketchup.call_ruby === 'function') {
    window.sketchup.call_ruby(action, payload)
    return true
  }
  return false
}

let settingsHandler = null

window.loadSettings = (data) => settingsHandler?.(data)

export function onSettings(handler) {
  settingsHandler = handler
}

// Мост sketchup.* появляется в странице позже загрузки (и execute_script до
// окончания загрузки теряется) — ретраим 'ready', пока не дойдёт. Ruby
// присылает настройки только в ответ на 'ready' (push_settings).
const READY_RETRIES_MS = [0, 100, 250, 500, 1000, 2000]

export function announceReady() {
  READY_RETRIES_MS.forEach((delay) => setTimeout(() => callRuby('ready'), delay))
}
