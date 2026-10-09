import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import tailwindcss from '@tailwindcss/vite'
import { viteSingleFile } from 'vite-plugin-singlefile'

// Собираем самодостаточный index.html (JS и CSS инлайном) прямо в папку html
// расширения — именно его открывает UI::HtmlDialog (settings_dialog.rb, set_file).
export default defineConfig({
  plugins: [vue(), tailwindcss(), viteSingleFile()],
  build: {
    outDir: '../dn1sup_autoselect_tag/dn1sup_autoselect_tag/html',
    emptyOutDir: true,
    target: 'es2020'
  }
})
