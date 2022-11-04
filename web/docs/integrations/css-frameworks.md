---
title: CSS Frameworks
---

import useBaseUrl from '@docusaurus/useBaseUrl';

# CSS Frameworks

## Tailwind

To enable support for Tailwind in your Wasp project, you simply need to add two config files (`tailwind.config.js` and `postcss.config.js`) to the root directory. When they are present, Wasp will add the necessary NPM dependencies and copy your config files into the generated project output. You can then start adding [Tailwind CSS directives](https://tailwindcss.com/docs/functions-and-directives#directives) to your CSS files and `className`s to your React components.

### New project tree overview
```bash title="tree ." {3,7-8}
.
├── ext
│   ├── Main.css
│   ├── MainPage.js
│   └── waspLogo.png
├── main.wasp
├── postcss.config.js
└── tailwind.config.js
```

### Tailwind integration steps

#### 1) Add `./tailwind.config.js`
```js title="./tailwind.config.js"
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./src/**/*.{js,jsx,ts,tsx}",
  ],
  theme: {
    extend: {},
  },
  plugins: [],
}
```

#### 2) Add `./postcss.config.js`
```js title="./postcss.config.js"
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
```

#### 3) Update `./ext/Main.css`
```css title="./ext/Main.css" {1-3}
@tailwind base;
@tailwind components;
@tailwind utilities;

/* rest of content below */
```

#### 4) Start using Tailwind 🥳
```html title="./ext/MainPage.js"
<h1 className="text-3xl font-bold underline">
  Hello world!
</h1>
```

### Adding Tailwind plugins
To add Tailwind plugins, add them to your `tailwind.config.js` file and `main.wasp` files:

```js title="./tailwind.config.js" {10-11}
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./src/**/*.{js,jsx,ts,tsx}",
  ],
  theme: {
    extend: {},
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography'),
  ],
}
```

```js title="main.wasp" {4-5}
app todoApp {
  title: "Example App",
  dependencies: [
    ("@tailwindcss/forms", "^0.5.3"),
    ("@tailwindcss/typography", "^0.5.7")
  ],
  // ...
}
```
