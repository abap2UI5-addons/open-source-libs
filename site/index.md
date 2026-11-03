---
layout: home

hero:
  name: "Open Source Libs"
  text: "Sample apps for eleven open-source ABAP libraries."
  image:
    src: /favicon.png
    alt: abap2UI5
  actions:
    - theme: brand
      text: Get started
      link: /guide
    - theme: alt
      text: GitHub
      link: https://github.com/abap2UI5-addons/open-source-libs
    - theme: alt
      text: All addons
      link: https://abap2ui5-addons.github.io/

features:
  - title: "Eleven sample apps, one package per library, e.g. z2ui5_cl_osl_abap2xlsx"
  - title: "Libraries: abap-tbox-stats, abap2xlsx, abap_fm_json, abap-openapi, ABAP Diff3"
  - title: "Also JSON2ABAPType, abap-fm-logger, zcl_pdf, zcl_docx, abapFaker, abap-data-validator"
  - title: "Each package needs only abap2UI5 and its own library"
  - title: "Statistics charts of tbox-stats use sap.viz and need SAPUI5 instead of OpenUI5"
  - title: "Written in nothing but ABAP"
---

## What it does

Each package in src/ is one abap2UI5 app for one community library: statistics, Excel, JSON, OpenAPI, diffs, PDF and Word documents, test data and validation. The libraries are installed as dependencies and never copied. It is for ABAP developers who want to see and try a library on their own system before they use it, for library authors who want to show their library at work and for abap2UI5 developers looking for complete apps to learn from.

## Requirements

- Standard ABAP: S/4 Private Cloud, On-Premise or SAP NetWeaver AS ABAP 7.50 or higher
- ABAP Cloud: no (most libraries use APIs not released for ABAP Cloud)
- SAPUI5 1.71 or higher
- abap2UI5
- The library of each sample you want to run
- SAPUI5 bootstrap (not OpenUI5) for the tbox-stats charts in src/01

## Installation

With [abapGit](https://abapgit.org), from [the repository](https://github.com/abap2UI5-addons/open-source-libs):

- Install with abapGit in this order: abap2UI5, the library of each sample you want to run, then this repository (branch main)
- abap_fm_json brings the authorization object Z_JSON; JSON2ABAPType needs its whole repository; abap-data-validator: install branch master; zcl_docx: install the whole package
- Start a sample with ?app_start=&lt;App&gt;, e.g. ?app_start=z2ui5_cl_osl_abap2xlsx
- For tbox-stats switch the bootstrap to SAPUI5 in the abap2UI5 user exit (cs_config-src)

The [Guide](/guide) has every step.

## A first app

```abap
METHOD z2ui5_if_ui5_exit~set_config_http_get.
  " or the SAPUI5 of the system: /sap/public/bc/ui5_ui5/resources/sap-ui-core.js
  cs_config-src = `https://ui5.sap.com/resources/sap-ui-core.js`.
ENDMETHOD.
```

## Links

- [abap-tbox-stats](https://github.com/zenrosadira/abap-tbox-stats)
- [abap2xlsx](https://github.com/abap2xlsx/abap2xlsx)
- [abap-openapi](https://github.com/abap-openapi/abap-openapi)
- [ABAP Diff3](https://github.com/abapPM/ABAP-Diff3)
- [abapFaker](https://github.com/se38/abapFaker)
- [abap-data-validator](https://github.com/hhelibeb/abap-data-validator)
- [The repository](https://github.com/abap2UI5-addons/open-source-libs) - issues and pull requests welcome
