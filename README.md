# mirror-pdm-project

OCX mirror for [PDM](https://github.com/pdm-project/pdm), the modern Python
package and dependency manager. One repository, one spec directory per package.

| Package | Spec | Publishes to | Announced as | Upstream SPDX |
|---|---|---|---|---|
| [pdm](https://github.com/pdm-project/pdm) | [`pdm/mirror.yml`](pdm/mirror.yml) | `ghcr.io/ocx-contrib/pdm-project/pdm` | [`ocx.sh/pdm-project/pdm`](https://index.ocx.sh/pdm-project/pdm) | `MIT` |

Each upstream release is discovered, re-bundled, smoke-tested per
`(version, platform)` and only then pushed with cascade tags, after which the
result is announced into the OCX index.

The GitHub org is the project's own brand, so the org names the namespace and
the tool names the package: `pdm-project/pdm`.

## Layout

```
mirror-base.yml         repo-wide policy every spec inherits via `extends:`
pdm/
├── mirror.yml          the spec — never at the repo root
├── metadata.json       bundle interface
├── CATALOG.md          → ocx package describe
├── logo.svg / logo.png describe assets, 512px PNG
└── tests/smoke.star    Starlark smoke test
```

`LICENSE` and `NOTICE.md` are shared at the root. Logos are **not** — each
package carries its own, because a repo-root `logo.*` sits in no workflow's
`paths:` filter, so replacing it would publish nothing until some unrelated
edit happened to fire.

⚠️ `extends:` is a **shallow** merge of top-level keys. A spec that restates
`platforms:` to change one runner drops every `containers:` entry with it, and
nothing reds — the legs simply stop existing, and every `os.features` claim
goes back to being asserted rather than verified. Restate a block in full or
not at all. `pdm/mirror.yml` does not restate it at all, which removes the trap
structurally.

## What this binary actually is

pdm's "standalone" release binary is a [PyApp](https://ofek.dev/pyapp/)
launcher, not a self-contained executable. It embeds a CPython distribution and
pdm's own wheel, but **not** pdm's Python dependencies: on first invocation it
unpacks CPython and pip-installs those dependencies **from PyPI** into a
per-user data directory (~9 s, measured), after which every run is offline and
immediate.

That is upstream's design and is reproduced byte-for-byte. It is documented in
[`pdm/CATALOG.md`](pdm/CATALOG.md) because it is a consumer-facing fact with no
declarable home in the spec — a first-run network requirement is not something
`os.features` can express. A fully air-gapped host cannot complete that first
run.

It also shapes the smoke test: the functional assertion had to be a verb that
is local *after* the bootstrap, which rules out `lock`, `install`, `add` and
`show`.

## Platforms

`pdm` publishes five platform entries: both Linux arches, both macOS arches and
`windows/amd64` — every target upstream ships.

`windows/arm64` is absent rather than deferred: upstream's only Windows target
is `x86_64-pc-windows-msvc`, on every release in range. There is nothing to
declare.

They were rolled out in three passes (linux → darwin → windows) for cost, with
each platform's key commented in `pdm/mirror.yml` and `mirror-base.yml`
*together* until its pass — a declared platform that resolves no asset does not
red, it boots a real runner and reports SUCCESS having tested nothing.

Before spending a macOS (10×) or Windows (2×) minute, the darwin and windows
archive layouts were settled **runner-free**: a throwaway probe spec through
`pipeline prepare` + `tar tvf` put a single mode-0755 `pdm` (`pdm.exe` on
Windows) at the bundle root for all three, each resolving exactly one asset with
no ambiguity error. `asset_type: archive` preserves the upstream `.exe` name, so
no per-platform `name:` override is needed and the `pdm.exe` ternary in
`tests/smoke.star` is what selects it.

### Both Linux keys are `+libc.glibc`, measured

The assets are named `-unknown-linux-gnu`, but a name is not a measurement.
Both declared arches were read at **both ends** of the mirrored range, 2.27.0
and 2.28.0: all four are `dynamically linked` PIE executables with a glibc
`PT_INTERP` and `libc.so.6`, `libm.so.6`, `libgcc_s.so.1` in `DT_NEEDED`. None
is UPX-packed (`strings -a … | grep -c '^UPX'` → 0, section headers present),
so the readelf verdict is the real one and not a packer stub.

`os.features` states what an artifact requires *of the host*, so both keys
carry `+libc.glibc` — on the `assets:` key and the `platforms:` key, or the two
halves would describe different platforms. The container legs are
`ubuntu:24.04` and `fedora:40` only: a `+libc.glibc` key tested in a musl image
is rejected by the renderer at exit 65, and the artifact could not load there
anyway:

```console
$ docker run --rm -v …:/b:ro alpine:3.20 sh -c '/b/pdm --version'
sh: /b/pdm: not found                                        # exit 127
```

The **glibc floor is `GLIBC_2.39` on both arches** — unusually high, and
identical across them. Nothing in the spec expresses a libc *version*
(`os.features` carries a family only), so it never reds on its own; it is
recorded in `mirror-base.yml` because it decides which base images clear it.
`ubuntu:24.04` and `fedora:40` both ship exactly 2.39 and pass with no
headroom; `ubuntu:22.04` (2.35) or `fedora:38` (2.37) would not.

### The floor is 2.27.0 because 2.26.9 ships no assets

Not because binary releases start there — 2.26.8 and every release back through
2.25.x publish the same five archives. Tag **2.26.9 has an empty `assets[]`**, a
source-only release:

```console
$ gh api repos/pdm-project/pdm/releases/tags/2.26.9 --jq '.assets|length'
0
```

An asset-less release inside the range is *silently dropped* by the pipeline
rather than reported, so the honest floor is the first release above it.

Resolution was verified **both ways on every in-range release** (2.27.0,
2.28.0): each declared pattern matches exactly one asset, every time. Every
pattern ends `\.tar\.gz$` because upstream ships a `.tar.gz.sha256` sidecar
beside each archive, and an unanchored pattern would match both and fail as
ambiguous.

## Editing

| File | Edit | Regenerate after |
|------|------|------------------|
| `mirror-base.yml`, `pdm/mirror.yml` | hand | yes — see below |
| `pdm/{metadata.json,CATALOG.md,logo.*}` | hand | — |
| `pdm/tests/smoke.star` | hand | — |
| `.github/workflows/*.yml` | **generated — never hand-edit** | re-run when a spec changes |

```bash
ocx-mirror package pipeline generate ci --spec pdm/mirror.yml
```

**Name every spec.** `--spec` *appends* rather than replaces, so a command
naming a subset silently stops rendering the rest while staying green — and the
drift guard reds on a generated workflow the current spec set no longer
produces.

`verify-generated.yml` exits 65 on drift. If a generated workflow is wrong, the
spec or the renderer template is wrong — fix it there and regenerate.

Run `direnv allow` once to put the pinned toolchain on `PATH`, and invoke
`ocx-mirror` directly — never `ocx run -- ocx-mirror`, which pins
`OCX_BINARY_PIN` to the bootstrap `ocx` and false-reds the nested push.

## The binaries claim

`pdm/metadata.json` declares `binaries: ["pdm"]` by hand, and `pdm/mirror.yml`
sets `bin_scan: "off"` — forced, not preferred. The scan only inspects an
interface-visible `${installPath}/<dir>` PATH entry, and pdm's archives are
**flat single-entry tarballs**: one mode-0755 file at the archive root (`pdm`,
`pdm.exe` on Windows) with no directory member at all. With nothing to inspect
the scan would pass green whatever the archive contained, so `auto` and
`verify` both fail spec load at exit 65 rather than offer a hollow check.

That layout also forces `strip_components: 0`, and **1 would not red**: on an
archive whose every entry sits at depth 1 there is nothing to hoist, so
stripping one component yields a bundle with zero entries while `prepare` still
exits 0 — an empty artifact published on a fully green run.

## The smoke test

`pdm/tests/smoke.star` asserts version *shape* (never the `PDM, version …`
prose, which a rebrand would change) and then runs one real, computed
transformation: `pdm import -f requirements`, reading a `requirements.txt`
written into scratch and rewriting a seed `pyproject.toml` that declares an
**empty** dependency list and **no** `[build-system]` table.

`import` is the one substantial pdm verb that is purely local. `lock`,
`install`, `add` and `show` all resolve against PyPI; `run` and `venv` need a
project interpreter the bundle does not ship.

The assertions are counts, not substring presence, so a duplicate rewrite fails
rather than passes. The discriminating one is the synthesized `[build-system]`
table with `build-backend = "pdm.backend"` — it appears in *neither* input file,
so a tool that merely echoed or concatenated its inputs could not produce it.
`dependencies = []` is asserted **absent**, which a tool that only appended
would fail.

Two negative controls follow: a named input file that does not exist, and a
`pyproject.toml` that is not TOML. Both exit **1**, measured on 2.27.0 and
2.28.0. Both codes are positive, so no platform branch is needed — only a
*negative* exit code differs across OSes (255 on unix, −1 on Windows).

`HOME` is pointed at a scratch subdirectory so the PyApp bootstrap lands inside
the sandbox rather than the container image's real home, making every leg start
from identical state. `PDM_CHECK_UPDATE=0` pins off pdm's `check_update`
config (default `True`), the only knob that could add a network-shaped notice
to stdout — insurance, not a fix: `--version` was measured byte-clean on a cold
cache with the default left on (`od -c` → exactly `PDM, version 2.28.0\n`,
empty stderr).

## Required secrets

| Secret | Use |
|--------|-----|
| `OCX_ANNOUNCE_TOKEN` | opens the index pull request from the `ocx-contrib/index` fork |
| `OCX_MIRROR_DISCORD_HOOK` | notify-stage Discord webhook URL |

(Inherited from the `ocx-contrib` org with visibility ALL. GHCR pushes use the
run's own `GITHUB_TOKEN` — no registry secret needed.)

## License

Apache-2.0 — see [`LICENSE`](LICENSE). Upstream assets are out of scope; the
redistribution license is recorded in [`NOTICE.md`](NOTICE.md). The logo
reproduces upstream's own mark, unmodified apart from scaling, solely to
identify the software being mirrored.
