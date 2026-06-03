/// <reference types="vitest/config" />
import { defineConfig } from 'vite';
import path from 'path';
import RubyPlugin from 'vite-plugin-ruby';
import ReactPlugin from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [RubyPlugin(), ReactPlugin()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './app/javascript/src'),
    },
  },
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: './src/testing/setup.ts',
  },
});
