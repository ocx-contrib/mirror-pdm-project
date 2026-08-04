# Smoke test for pdm-project/pdm.
#
# DIALECT: `ocx package test` runs the Bazel `.bzl` Starlark dialect. A
# top-level `if`/`for` STATEMENT is a parse error that reds every version on
# every platform before a single assertion runs. Branch at module scope only
# via an if-EXPRESSION (below) or a `def` + a bare top-level call.

PDM = "pdm.exe" if ocx.target_platform.os == ocx.os.Windows else "pdm"

# pdm's "standalone" binary is a PyApp launcher: it unpacks an embedded CPython
# distribution and pip-installs the embedded pdm wheel's DEPENDENCIES from PyPI
# into its user data dir on first run (~9 s, once), then runs offline. That
# bootstrap is upstream's design, not something this mirror can or should route
# around — see ../CATALOG.md.
#
# Pointing HOME at a scratch subdirectory keeps that unpack inside the sandbox
# instead of the container image's real HOME, so every leg starts from the same
# state whatever the image sets. On Windows PyApp resolves its data dir from
# FOLDERID_LocalAppData rather than HOME, so the key is inert there — harmless,
# and the runner's own profile is writable.
#
# PDM_CHECK_UPDATE=0 pins off pdm's `check_update` config (default True), which
# is the only knob that could add a network-shaped notice to stdout. Measured:
# `--version` is byte-clean on a cold cache with the default left ON —
# `od -c` gives exactly `PDM, version 2.28.0\n` and empty stderr — so this is
# insurance against a future release, not a fix for observed noise.
ocx.mkdir("home")
ENV = {
    "HOME": ocx.scratch_root + "/home",
    "PDM_CHECK_UPDATE": "0",
}

# ── Tier 1 + 2: liveness, and version SHAPE ────────────────────────────────
# Never the vendor string: "PDM, version …" is prose that a rebrand may change,
# and asserting it would red on a rename while passing on a broken binary.
r_version = ocx.run(PDM, "--version", env=ENV)
expect.ok(r_version)
expect.matches(r_version.stdout, r"\d+\.\d+\.\d+")

# ── Tier 3: a real, computed pyproject.toml transformation ─────────────────
#
# `pdm import` reads a foreign dependency format and rewrites the project's own
# pyproject.toml. It is the one substantial pdm verb that is purely local:
# `lock`, `install`, `add` and `show` all resolve against PyPI, and `run`/`venv`
# need a project interpreter the bundle does not ship. Both input files are
# written into scratch, so the whole operation is hermetic.
#
# The seed pyproject.toml deliberately declares an EMPTY dependency list and NO
# [build-system] table at all.
ocx.write_file("requirements.txt", "requests==2.31.0\nrich>=13.0\n")
ocx.write_file("pyproject.toml", """[project]
name = "ocxsmoke"
version = "0.0.0"
requires-python = ">=3.9"
dependencies = []
""")

r_import = ocx.run(PDM, "import", "-f", "requirements", "requirements.txt", env=ENV)
expect.ok(r_import)

out = ocx.read_file("pyproject.toml")

# Both requirements were carried across, each exactly once — asserted by COUNT
# so a duplicate rewrite is a failure rather than a pass.
expect.eq(out.count("\"requests==2.31.0\","), 1)
expect.eq(out.count("\"rich>=13.0\","), 1)

# The empty list is GONE: pdm rewrote the existing table in place rather than
# appending a second `dependencies` key. Without this a tool that only ever
# appended would still pass the two counts above.
expect.eq(out.count("dependencies = []"), 0)

# The discriminating assertion. This table appears in NEITHER input file —
# pdm synthesises it from its own knowledge of the default build backend when a
# project has none. A tool that merely echoed or concatenated its inputs cannot
# produce it, which is what separates this from a passthrough check.
expect.eq(out.count("[build-system]"), 1)
expect.eq(out.count("build-backend = \"pdm.backend\""), 1)
expect.eq(out.count("requires = [\"pdm-backend\"]"), 1)

# ── Negative controls ───────────────────────────────────────────────────────
#
# Exit 1 on both, measured on 2.27.0 and 2.28.0 in ubuntu:24.04. Both codes are
# POSITIVE, so no platform branch is needed — only a negative exit code differs
# across OSes (255 on unix, -1 on Windows).

# (1) A named input file that does not exist. Proves the reader actually opens
#     the path instead of pattern-matching the argument.
r_missing = ocx.run(PDM, "import", "-f", "requirements", "nosuch.txt", env=ENV)
expect.eq(r_missing.exit_code, 1)

# (2) A project file that is not TOML. Proves the pyproject.toml on the success
#     path was genuinely parsed rather than blindly appended to.
ocx.mkdir("broken")
ocx.write_file("broken/pyproject.toml", "this is not = = toml [[[\n")
ocx.write_file("broken/requirements.txt", "requests==2.31.0\n")
r_broken = ocx.run(PDM, "import", "-f", "requirements", "requirements.txt",
                   env=ENV, cwd="broken")
expect.eq(r_broken.exit_code, 1)
