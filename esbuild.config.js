const esbuild = require("esbuild");

const watchMode = process.argv.includes("--watch");

const config = {
  entryPoints: [
    "app/javascript/application.js",
    "app/javascript/components.js",
  ],
  outdir: "app/assets/builds",
  bundle: true,
  format: "esm",
  splitting: false, // Disable splitting for simpler asset management
  sourcemap: true,
  publicPath: "/assets",
  jsx: "transform",
  jsxFactory: "React.createElement",
  jsxFragment: "React.Fragment",
  external: [
    "react",
    "react-dom",
    "@hotwired/turbo-rails",
    "@hotwired/stimulus",
    "@hotwired/stimulus-loading",
  ],
  loader: {
    ".js": "jsx", // Treat .js files as JSX
  },
  define: {
    "process.env.NODE_ENV": '"development"',
  },
};

if (watchMode) {
  esbuild.context(config).then((ctx) => {
    ctx.watch();
    console.log("👀 Watching for changes...");
  });
} else {
  esbuild.build(config).catch(() => process.exit(1));
}
