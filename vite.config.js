import gleam from "vite-gleam";
import { compression } from 'vite-plugin-compression2'
import { resolve } from "path";


export default {
  plugins: [gleam(), compression()],
  resolve: {
    alias: {
      app: resolve(__dirname, "build/dev/javascript/app"),
      "@build": resolve(__dirname, "build/dev/javascript/"),
    },
  },
  build: {
    outDir: "priv/static/",
    rollupOptions: {
      input: {
        spa: "index.html",
        'pages/home': "pages/home.html"
      },
    },
  },
};
