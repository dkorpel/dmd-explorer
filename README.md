# dmd-explorer

Hosts the **DMD compiler explorer** — a WebAssembly build of the D compiler
that lexes, parses, runs semantic analysis and generates code entirely in the
browser, with AST / IR / ASM views and a Run button.

Live site: https://dkorpel.github.io/dmd-explorer/

## How it works

The website source lives in the `wasm-web-app` branch of
[`dkorpel/dmd`](https://github.com/dkorpel/dmd/tree/wasm-web-app/compiler/wasm/web)
(`compiler/wasm/web`). Nothing is served from this repo's `main` branch; the
workflows here build `dmd.wasm` and write what Pages serves to the **`site`**
branch:

```
site/
  index.html, glue.js, worker.js, …   the explorer page (from wasm-web-app)
  dmd.wasm                            main build of the wasm-web-app branch
  pr/index.json                       list of hosted PR builds
  pr/<N>/dmd.wasm, pr/<N>/meta.json   dmd built from dlang/dmd pull request N
```

`scripts/site-update.sh` rewrites that branch as a single commit each time
(binaries never pile up in history) and `publish.yml` deploys it to Pages.

| Workflow | Trigger | What it does |
|---|---|---|
| `deploy.yml` Deploy to GitHub Pages | manual | build the main `dmd.wasm`, replace the page + main build in `site`, publish |
| `try-pr.yml` Build PR | manual, or `repository_dispatch` `try-pr` | build a PR's `dmd.wasm`, add it as `pr/<N>`, publish |
| `publish.yml` Publish site | called by the two above, or manual | deploy the `site` branch to Pages |

The toolchain (host LDC, LLVM 21 `wasm-ld`, Binaryen `wasm-opt`) is set up by
`.github/actions/setup-toolchain`; bump the pinned versions there.

## Deploying the main build

1. Push the `wasm-web-app` branch of `dkorpel/dmd` (no need to commit `dmd.wasm`).
2. **Actions → Deploy to GitHub Pages → Run workflow**, or:

   ```sh
   gh workflow run deploy.yml -R dkorpel/dmd-explorer
   ```

PR builds already on the site survive a main deploy.

## Trying a pull request

Builds are made on demand, one PR at a time, never for every open PR.

1. **Actions → Build PR → Run workflow**, enter the PR number (repository
   defaults to `dlang/dmd`), or:

   ```sh
   gh workflow run try-pr.yml -R dkorpel/dmd-explorer -f pr=23803
   ```

2. About five minutes later the build is live at
   `https://dkorpel.github.io/dmd-explorer/?pr=23803`. The page shows which PR
   and commit it runs, and the **PR…** button lists every hosted build.

The PR's diff (merge base to head) is applied on top of the explorer branch,
which is upstream `master` plus the wasm backend and the explorer. A PR that
touches code the explorer branch also changed, or that depends on newer
`master` commits, fails to apply; the job log names the conflicting files, and
the fix is to rebase `wasm-web-app` onto a newer `master`.

Builds of merged or closed PRs are pruned the next time any workflow updates
the site. To drop one by hand, run **Build PR** with action `remove`.

### Locally

On a checkout of the `wasm-web-app` branch, with a Phobos checkout next to the
dmd repository:

```sh
./compiler/wasm/trypr.sh 23803
python -m http.server -d compiler/wasm/web
# open http://localhost:8000/?pr=23803
```

That creates worktrees under `tmp/prbuild/`, builds everything there and
writes `compiler/wasm/web/pr/23803/`. The workflow runs the same script with
`--in-place`.

### From another repository

`try-pr.yml` also accepts a `repository_dispatch` event, so a workflow in
`dlang/dmd` (say, on a `explorer` label or a `/explorer` comment) can request
a build with a token that has `actions: write` here:

```sh
gh api repos/dkorpel/dmd-explorer/dispatches \
  -f event_type=try-pr -F 'client_payload[pr]=23803'
```

If a `PR_COMMENT_TOKEN` secret that can comment on the PR's repository is
configured, the job posts the link to the PR when the build is ready.
