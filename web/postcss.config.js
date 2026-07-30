// Without this file Vite never runs Tailwind, so the built CSS still contains
// raw `@tailwind` at-rules and the app ships unstyled. `tailwindcss` and
// `autoprefixer` were already declared as devDependencies but never wired in.
export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
