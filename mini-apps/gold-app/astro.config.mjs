import { defineConfig } from 'astro/config';

// https://astro.build/config
export default defineConfig({
  // Allow external access from local network (Flutter WebView, mobile emulators)
  server: {
    host: true,
    port: 4321,
  },
});
