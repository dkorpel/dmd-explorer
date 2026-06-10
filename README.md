# dmd-explorer

Hosts the **DMD compiler explorer** — a WebAssembly build of the D frontend
that lexes, parses, and runs semantic analysis entirely in the browser, with
AST / IR / ASM views.

Live site: https://dkorpel.github.io/dmd-explorer/

## How it works

This repo holds no website source of its own. The static content is pulled from:

- repo: [`dkorpel/dmd`](https://github.com/dkorpel/dmd)
- branch: `wasm-web-app`
- folder: [`compiler/wasm/web`](https://github.com/dkorpel/dmd/tree/wasm-web-app/compiler/wasm/web)
  (`index.html`, `tour.html`, `glue.js`, and the prebuilt `dmd.wasm`)

The [`Deploy to GitHub Pages`](.github/workflows/deploy.yml) workflow checks out
that folder and publishes it to GitHub Pages.

## Deploying

Deploys are **manual**. To publish the current state of the `wasm-web-app` web
folder:

1. Make sure the latest `compiler/wasm/web` (including a rebuilt `dmd.wasm`) is
   committed and pushed to `dkorpel/dmd` `wasm-web-app`.
2. Go to **Actions → Deploy to GitHub Pages → Run workflow**, or run:

   ```sh
   gh workflow run deploy.yml -R dkorpel/dmd-explorer
   ```

To point at a different source repo / branch / folder, edit the `SOURCE_REPO`,
`SOURCE_REF`, and `SOURCE_PATH` env vars in the workflow.
