# AGENTS.md — AI Assistant Guide for abap2UI5 open-source-libs

> This file follows the cross-tool AGENTS.md convention and is the single
> agent instruction file of this repository — `CLAUDE.md` only points here.

## Project Overview

[abap2UI5](https://github.com/abap2UI5/abap2UI5) sample apps for open-source
ABAP libraries: every package in `src/` puts one library to work in an
abap2UI5 app, so that the library can be seen and tried in the browser.

**Language:** English — all code, comments, commit messages, PRs, issues and
documentation must be in English.

## Package Structure

| Package | Content |
|---|---|
| `src/` | Root package, no objects of its own |
| `src/01/` | [abap-tbox-stats](https://github.com/zenrosadira/abap-tbox-stats) — `z2ui5_cl_osl_tbox_stats`, statistics and random distributions with `sap.viz` charts |

## The Library Is a Dependency, Never a Copy

A sample shows a library; it does not ship one. The library is installed on
its own with abapGit, keeps its own names and releases, and is resolved in CI
from its repository. Never vendor library code into `src/`, and never rename
it: the rename check moves only the samples (`z2ui5_*`).

## Adding a Sample for Another Library

1. Take the next free package, `src/NN/`, with a `package.devc.xml` whose text
   is `abap2UI5 - open-source libs - <library>`.
2. Name the classes `z2ui5_cl_osl_<library>` (or `…_<nn>` for several apps),
   **25 characters at most**: `build-rename` may make the namespace up to four
   characters longer, and ABAP stops at 30.
3. Add the library to the `dependencies` of `abaplint.jsonc` and
   `.github/abaplint/rename.json`, and to the README (samples table,
   installation, dependencies, credits).
4. Standard types a library uses that are no released API stay void through
   the `errorNamespace`; do not add stubs for them.
5. The render gate serves OpenUI5. A view with a SAPUI5-only control
   (`sap.viz`, `sap.suite`, `sap.gantt`, …) cannot load there — add the class to
   `render-error`'s `exclude` in `abap2ui5lint.jsonc`, with the control in a
   comment. Every other render error is a real one.

## Dependencies

Installed alongside via abapGit; declared in the abaplint configs:

* [abap2UI5](https://github.com/abap2UI5/abap2UI5)
* the library of each sample — [abap-tbox-stats](https://github.com/zenrosadira/abap-tbox-stats) (`src/01`)

## Coding Style

The samples follow the abap2UI5 app conventions — see the core's
[building-apps guide](https://github.com/abap2UI5/abap2UI5/blob/main/docs/agents/building-apps.md):
one class per app implementing `z2ui5_if_app`, `main` as a pure dispatcher
(`check_on_init` / `check_on_navigated` / `check_on_event`), public attributes
only for bound data, `client->_bind( )` for every binding, and views built
with `z2ui5_cl_ui5_view_builder` in the chain layout the linter checks
(`chain-house-layout`). Every number is computed in ABAP; the frontend only
draws bound tables. Clean ABAP with backtick string literals and string
templates (`|…{ }…|`).

## Validation

Run `npm run check` before considering changes complete: it runs the same steps
as CI, and all of them must pass. CI:

* `abap-standard` — lint against Standard ABAP (`abaplint.jsonc`), resolved
  against abap2UI5 and the libraries
* `check-abap2ui5` — the abap2UI5-linter over the app classes and their views
  (`abap2ui5lint.jsonc`), with the render gate
* `check-rename` — namespace-rename check (`.github/abaplint/rename.json`,
  against the 9-character placeholder `zabap2ui5`)
* `build-rename` — manual workflow that pushes a namespace-renamed branch
  `rename_<name>` for a parallel install

There is no ABAP Cloud gate yet: tbox-stats, the only library so far, is
Standard ABAP (it uses `NAME_FELD` and `IF_FSBP_CONST_RANGE`, neither released
for ABAP Cloud). Add `.github/abaplint/abap_cloud.jsonc` and an `abap-cloud`
workflow (as in [sql-console](https://github.com/abap2UI5-addons/sql-console))
with the first sample whose library runs on ABAP Cloud, and exclude the
packages whose library does not. There is no 702 downport either — tbox-stats
has none.

All `.abap`/`.xml`/config files are LF-only (`.gitattributes` enforces it).
