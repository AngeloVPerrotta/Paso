import { defineConfig } from 'astro/config';

// Landing de Paso: una sola página, CSS propio, cero frameworks pesados, cero React.
export default defineConfig({
  // Angelo: poné acá el dominio final (sirve para canonical/OG y el sitemap).
  site: 'https://paso.angeloperrotta.online',
  build: {
    inlineStylesheets: 'auto',
  },
});
