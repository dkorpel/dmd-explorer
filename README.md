# dmd-explorer

Hosts the **DMD compiler explorer** — a WebAssembly build of the D frontend
that lexes, parses, and runs semantic analysis entirely in the browser, with
AST / IR / ASM views.

Live site: https://dkorpel.github.io/dmd-explorer/

## How it works

This repo holds no website source of its own. The static content comes from:

- repo: [`dkorpel/dmd`](https://github.com/dkorpel/dmd)
- branch: `wasm-web-app`
- folder: [`compiler/wasm/web`](https://github.com/dkorpel/dmd/tree/wasm-web-app/compiler/wasm/web)
  (`index.html`, `tour.html`, `glue.js`)

`dmd.wasm` is **not** committed — the [`Deploy to GitHub Pages`](.github/workflows/deploy.yml)
workflow checks out the dmd branch, builds `dmd.wasm` from source with LDC + the
wasi-sdk sysroot (via `compiler/wasm/build.sh`), then publishes the `web` folder
to GitHub Pages.

## Deploying

Deploys are **manual**. To publish the current state of the `wasm-web-app`
branch:

1. Make sure the latest `compiler/wasm` sources are pushed to `dkorpel/dmd`
   `wasm-web-app` (no need to rebuild/commit `dmd.wasm` — CI builds it).
2. Go to **Actions → Deploy to GitHub Pages → Run workflow**, or run:

   ```sh
   gh workflow run deploy.yml -R dkorpel/dmd-explorer
   ```

The build pins `LDC_VERSION` and `WASI_SDK_VERSION` in the workflow env; bump
those there if needed. To point at a different source repo / branch / folder,
edit `SOURCE_REPO`, `SOURCE_REF`, and `SOURCE_PATH`.
