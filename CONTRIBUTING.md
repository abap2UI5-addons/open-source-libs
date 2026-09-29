# Contributing

abap2UI5 sample apps for open-source ABAP libraries — every library with a UI.

## Adding a library

One package per library, the library as a dependency and never as a copy. The
steps — package, class names, the abaplint dependencies, the render gate — are
in [AGENTS.md](AGENTS.md#adding-a-sample-for-another-library). Not sure the
library fits? Open an issue first.

## Before you open a pull request

Run what CI runs:

```sh
npm ci
npm run check
```

`npm run check` is the same set of steps the workflows run on a pull request,
so a green run locally is a green run there. `npm test` is an alias for it —
this repository has no separate unit-test suite; its ABAP is checked, not
executed.

## What the gates are

| Gate | What it proves |
| --- | --- |
| `npm run lint` | abaplint: syntax and style, resolved against the abap2UI5 core and the libraries the samples show |
| `npm run check:abap2ui5` | [abap2UI5-linter](https://github.com/abap2UI5/linter): the app class and the view it builds, judged together — controls, members, bindings, the UI5 version floor, and a headless render of every view that does not need SAPUI5 |
| `npm run rename` | the namespace rename still applies cleanly; only the samples move, the libraries keep their names |

## Conventions

English for code, comments, commit messages and pull requests. Commit subjects
are written in the imperative and describe the outcome, not the mechanics. One
topic per pull request. The wider rules the whole ecosystem follows live in
[abap2UI5's CONVENTIONS.md](https://github.com/abap2UI5/abap2UI5/blob/main/.github/shared/CONVENTIONS.md).

## Views

Views are built with `z2ui5_cl_ui5_view_builder`, the generic builder in the
core's `src/02` — five verbs (`ele`, `tag`, `a`, `end`, `stringify`) that
translate a UI5 XML view one to one. Two things to know before editing a chain:

- `a( )` applies to the element the chain is pointing at, so give a control its
  attributes immediately after the `ele( )` or `tag( )` that opened it;
- an ABAP boolean goes into `b =`, never `v =`. Through `v =` an `abap_false`
  renders as an empty string, which UI5 reads as true.

Do not use the frozen `z2ui5_cl_xml_view`: it lives in the core's `src/99`,
outside the released API, and the view gate can read nothing that is built
with it.
