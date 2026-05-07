import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Cloud Shell web preview hostname pattern allowed.
const cloudShellHostPattern = /\.cloudshell\.dev$/;

export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    port: Number(process.env.VITE_PORT ?? (process.env.CLOUD_SHELL === 'true' ? 8081 : 5173)),
    strictPort: false,
    allowedHosts: [cloudShellHostPattern, 'localhost'],
  },
});
