import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { viteSingleFile } from 'vite-plugin-singlefile'

// 通常ビルド: docs/app/ に出力（GitHub Pages で /PhysLog/app/ として配信）
// single モード: 1ファイルの HTML（プレビュー共有用）
export default defineConfig(({ mode }) => ({
  base: './',
  plugins: mode === 'single' ? [react(), viteSingleFile()] : [react()],
  build: {
    outDir: mode === 'single' ? 'dist-single' : '../docs/app',
    emptyOutDir: true,
  },
}))
