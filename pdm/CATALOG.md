---
title: pdm
description: Modern Python package and dependency manager — PEP 621 metadata, a cross-platform lock file, PEP 582 local packages and a pluggable build backend
keywords: pdm,python,package-manager,dependency-management,pep-621,pep-582,pep-517,lockfile,virtualenv,pyproject,build-backend,cli
---

# pdm

[PDM](https://github.com/pdm-project/pdm) is a Python package and dependency
manager built on modern packaging standards. Projects are described entirely by
PEP 621 metadata in `pyproject.toml`; `pdm lock` resolves that into a
cross-platform `pdm.lock` that pins every transitive dependency with hashes, and
`pdm install` reproduces it. It manages virtualenvs for you, or skips them
entirely via PEP 582 local packages, and ships `pdm-backend` as a PEP 517 build
backend so the same file that declares your dependencies also builds your wheel.

Beyond the resolver it carries a full project lifecycle: `pdm init`/`pdm new`
scaffolding, `pdm run` for user-defined scripts, `pdm build`/`pdm publish` for
distribution, `pdm export` to requirements/PEP 751 formats, `pdm import` from
Poetry, Pipenv, `requirements.txt` or setup.py, and a plugin system.

## What's included

- **pdm** — the binary (`pdm.exe` on Windows), the single entry point for every
  subcommand.

The archive contains this one executable and nothing else — no `bin/`
directory, no license or docs alongside it.

## First run downloads from PyPI

This binary is a [PyApp](https://ofek.dev/pyapp/) launcher, not a fully
self-contained executable. It embeds a CPython distribution and pdm's own
wheel, but **not** pdm's Python dependencies. On its first invocation it unpacks
CPython and pip-installs those dependencies from **PyPI** into a per-user data
directory, which takes roughly 9 seconds and **requires network access**. Every
run after that is offline and immediate.

That is upstream's design for its standalone binaries and is reproduced here
byte-for-byte. Practical consequences:

- A fully air-gapped host cannot complete the first run.
- The install directory is `$XDG_DATA_HOME`/`~/.local/share/pyapp` on Linux,
  `~/Library/Application Support/pyapp` on macOS and `%LOCALAPPDATA%\pyapp` on
  Windows — set `PYAPP_INSTALL_DIR_PDM` to relocate it. It must be writable.
- Pinning a pdm version pins the *wheel*; its dependency versions are resolved
  from PyPI at bootstrap time.

If you need a genuinely hermetic install, use `pipx`/`uv tool install` against
a private index instead.

## Usage

```sh
# start a project, then resolve and install its dependencies
pdm init
pdm add requests
pdm install
```

```sh
# migrate an existing project into PEP 621 metadata
pdm import -f requirements requirements.txt
```

```sh
# run a script declared under [tool.pdm.scripts]
pdm run test
```

```sh
# export the lock file for a consumer that wants requirements.txt
pdm export -o requirements.txt --without-hashes
```

## Install with ocx

```sh
ocx install ocx.sh/pdm-project/pdm
```

```sh
# or pin a specific version
ocx install ocx.sh/pdm-project/pdm:2.28.0
```

## Links

- [pdm on GitHub](https://github.com/pdm-project/pdm)
- [Documentation](https://pdm-project.org)
- [CLI reference](https://pdm-project.org/latest/reference/cli/)
- [pdm-backend](https://github.com/pdm-project/pdm-backend)
