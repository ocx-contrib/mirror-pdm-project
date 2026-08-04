# NOTICE

This repository packages and redistributes upstream software published by the
[PDM](https://github.com/pdm-project/pdm) project. The Apache-2.0 license in
[`LICENSE`](LICENSE) covers the OCX pipeline files authored here. It does
**not** cover any upstream-derived asset — each package's redistributed bytes
carry their own license, recorded below.

Each package's logo in this repository reproduces the **upstream project's own
mark** at 512 px, unmodified apart from scaling, solely to identify the
software being mirrored. No endorsement or affiliation is implied, and no
trademark right is claimed.

| Package | GHCR path | Upstream SPDX |
|---|---|---|
| `pdm` | `ghcr.io/ocx-contrib/pdm-project/pdm` | `MIT` |

---

## `pdm`

Upstream: <https://github.com/pdm-project/pdm>
Published to `ghcr.io/ocx-contrib/pdm-project/pdm`.

| Component | SPDX | Holder |
|---|---|---|
| pdm (`pdm`) | **MIT** | Copyright (c) 2019 Frost Ming |

Verified at the Phase 1.5 license gate:

```console
$ gh api repos/pdm-project/pdm/license --jq '{spdx: .license.spdx_id, path: .path}'
{"path":"LICENSE","spdx":"MIT"}
```

The MIT License grants redistribution of the software in source and binary form
without restriction, on the single condition that the copyright notice and the
permission notice accompany all copies or substantial portions of the software.

⚠️ Upstream's archives ship the **binary alone** — no `LICENSE` file travels
inside them, so unlike a mirror whose archive carries its own notice, that
condition is met by *this file*: it reproduces the SPDX identifier and
copyright holder for the redistributed bytes, and is published in this
repository alongside the mirror that ships them.

The published binary is a [PyApp](https://ofek.dev/pyapp/) launcher (MIT,
Copyright (c) 2023-present Ofek Lev) wrapping an embedded CPython distribution
built by [`astral-sh/python-build-standalone`](https://github.com/astral-sh/python-build-standalone)
(PSF-2.0 for CPython itself) and pdm's own wheel. pdm's remaining Python
dependencies are **not** embedded — they are fetched from PyPI on first run
under their own licenses and are not redistributed by this mirror.

No modifications are made to any upstream artifact in this repository; they are
republished byte-for-byte inside an OCX bundle.
