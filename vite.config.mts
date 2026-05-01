import { defineConfig } from 'vite';
import path from 'path';
import RubyPlugin from 'vite-plugin-ruby';
import ReactPlugin from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [
    RubyPlugin(),
    ReactPlugin(),
  ],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './app/frontend/src')
    }
  }
})
