![ABAP](https://img.shields.io/badge/ABAP-Standard%207.50%2B-blue)
[![namespace](https://img.shields.io/badge/namespace-z2ui5__cl__osl-blue)](abaplint.jsonc)
[![dependency](https://img.shields.io/badge/dependency-abap2UI5-blue)](https://github.com/abap2UI5/abap2UI5)
[![abap2UI5](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabap2UI5-addons%2Fopen-source-libs%2Fbadges%2Fabap2ui5.json)](https://github.com/abap2UI5-addons/open-source-libs/actions/workflows/check-abap2ui5.yaml)
<br><br>
[![abap-standard](https://github.com/abap2UI5-addons/open-source-libs/actions/workflows/abap-standard.yaml/badge.svg)](https://github.com/abap2UI5-addons/open-source-libs/actions/workflows/abap-standard.yaml)
<br>
[![check-abap2UI5](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabap2UI5-addons%2Fopen-source-libs%2Fbadges%2Fcheck-abap2ui5.json)](https://github.com/abap2UI5-addons/open-source-libs/actions/workflows/check-abap2ui5.yaml)
[![check-rename](https://github.com/abap2UI5-addons/open-source-libs/actions/workflows/check-rename.yaml/badge.svg)](https://github.com/abap2UI5-addons/open-source-libs/actions/workflows/check-rename.yaml)
<br>
[![build-rename](https://github.com/abap2UI5-addons/open-source-libs/actions/workflows/build-rename.yaml/badge.svg)](https://github.com/abap2UI5-addons/open-source-libs/actions/workflows/build-rename.yaml)

# open-source-libs
abap2UI5 Sample Apps for Open-Source ABAP Libraries – Every Library with a UI

The ABAP open-source community has built many good libraries. Most of them come with a README and unit tests, but without a screen. This repository adds one: every package in `src/` is an [abap2UI5](https://github.com/abap2UI5/abap2UI5) app that puts one library to work in the browser, on your own system, written in nothing but ABAP. The libraries stay where they are — each sample uses its library as a dependency, it never copies it.

#### Samples
| Package | Library | App | What it shows |
|---|---|---|---|
| `src/01` | [abap-tbox-stats](https://github.com/zenrosadira/abap-tbox-stats) | `z2ui5_cl_osl_tbox_stats` | Descriptive statistics, group-by aggregations and random distributions as tiles and `sap.viz` charts |
| `src/02` | [abap2xlsx](https://github.com/abap2xlsx/abap2xlsx) | `z2ui5_cl_osl_abap2xlsx` | Excel workbench: build styled workbooks with tables, conditional formats, validation and charts, and read uploaded ones back |
| `src/03` | [abap_fm_json](https://github.com/cesar-sap/abap_fm_json) | `z2ui5_cl_osl_fm_json` | Function modules called with JSON in and out: interface, editable JSON input, result as JSON, XML, YAML or Perl |
| `src/04` | [abap-openapi](https://github.com/abap-openapi/abap-openapi) | `z2ui5_cl_osl_openapi` | OpenAPI 3 JSON to generated ABAP interface, client and ICF handler, plus the parsed operations |
| `src/05` | [ABAP Diff3](https://github.com/abapPM/ABAP-Diff3) | `z2ui5_cl_osl_diff3` | Side-by-side line diff, three-way merge with conflict resolution, diff(1) patches |
| `src/06` | [JSON2ABAPType](https://github.com/fidley/JSON2ABAPType) | `z2ui5_cl_osl_json2type` | JSON pasted in the browser turned into ABAP TYPES, with naming modes, name mappings and the detected structure |
| `src/07` | [abap-fm-logger](https://github.com/hhelibeb/abap-fm-logger) | `z2ui5_cl_osl_fm_logger` | The log report ZAFL_VIEWER in the browser: logged function module calls, their parameters as JSON, optional reprocessing |
| `src/08` | [zcl_pdf](https://github.com/beraadim/zcl_pdf) | `z2ui5_cl_osl_pdf` | PDF letters and invoices built in ABAP, shown in a PDFViewer and downloadable |
| `src/09` | [zcl_docx](https://github.com/AntonSikidin/zcl_docx) | `z2ui5_cl_osl_docx` | A delivery note or invoice filled into a Word template and downloaded, with a text preview |
| `src/10` | [abapFaker](https://github.com/se38/abapFaker) | `z2ui5_cl_osl_faker` | Test data generator: fake persons, addresses, companies, jobs, phone numbers and dates per locale, as a table and CSV download |
| `src/11` | [abap-data-validator](https://github.com/hhelibeb/abap-data-validator) | `z2ui5_cl_osl_validator` | Rule-based validation of an editable table, invalid cells marked with the library's messages |

#### tbox-stats – Statistics with ABAP (`src/01`)
The app generates a stand-in for the flight bookings table SBOOK — 4,000 bookings with price, booking class, carrier and luggage weight, drawn with tbox-stats' own random generators — and puts tbox-stats to work on it:

* **Explore a column** – mean, standard deviation, skewness, kurtosis, the Jarque–Bera normality test, outliers and a correlation; a histogram with its normal fit and the empirical CDF against the normal CDF; for all bookings or one booking class
* **Group by** booking class or carrier – count, share, mean, median, standard deviation, coefficient of variation, IQR and skewness per group
* **Distribution lab** – draw samples from the normal, uniform, Poisson, binomial, geometric and Bernoulli generators, change their parameters and compare the result with the theory

Every number is computed in ABAP by `ztbox_cl_stats`; the frontend only draws the bound tables.

<img width="700" alt="Explore a column: tiles, histogram with normal fit, empirical vs. normal CDF" src="img/tbox-stats/explore.png">
<img width="700" alt="Group by carrier: mean and median per group" src="img/tbox-stats/group-by.png">
<img width="700" alt="Distribution lab: 10,000 normal draws against the theory" src="img/tbox-stats/distribution-lab.png">

#### abap2xlsx – Excel Workbench (`src/02`)
* **Export** – 50 generated flight bookings; every option is one abap2xlsx call: `bind_table` with a table style and a totals row (or a plain range with an autofilter), `freeze_panes`, a data bar and a cell-is rule on the amount, a dropdown validation and a summary sheet with a bar chart. `zcl_excel_writer_2007` writes the file, the browser downloads it
* **The code** – a panel shows the exact abap2xlsx calls the chosen options produce
* **Import** – upload an .xlsx (or read back the exported one); `zcl_excel_reader_2007` loads it, pick a sheet, see its cells, and watch `zcl_excel_common=>excel_string_to_date` turn the serial numbers of the detected date column into dates

#### abap_fm_json – Function Modules as JSON (`src/03`)
The app calls function modules the way the library's ICF handler does, without the HTTP round trip — every step is one of `zcl_json_handler`'s public methods:
* **Interface** – pick a function module and see its parameters as `build_params( )` reads them
* **JSON input** – edit the request, start from an example or a template the library serializes from the interface, choose the deserializer
* **Call and result** – the result, with any exception raised, as JSON, XML, YAML or Perl, with the handler's `upcase`, `camelcase` and `show_import_params` options

Only a hard-coded whitelist of harmless standard function modules is offered (`STFC_CONNECTION`, `STFC_STRUCTURE`, `RFC_SYSTEM_INFO`, `DATE_GET_WEEK`), and every call first passes the library's own authority check on `Z_JSON`.

#### abap-openapi – OpenAPI to ABAP (`src/04`)
* Paste or upload an OpenAPI 3 JSON document (a small petstore is prefilled) and run the library's generator (`zcl_oapi_generator=>generate_v2`)
* The generated interface, HTTP client, ICF handler and ICF implementation in read-only code editors, each downloadable
* The operations as the library's parser reads them – method, path, operationId, ABAP method name, parameters, request body, responses

#### ABAP Diff3 – Diff, Patch and Three-Way Merge (`src/05`)
* **Diff** – two texts compared line by line with `diff_comm( )`, side by side, every row marked unchanged, changed, deleted or inserted, with the LCS length and the hunks in diff(1) notation
* **Three-way merge** – base, mine and theirs merged with `diff3_merge( )`; clean changes are taken over, each conflict is resolved with *take mine*, *take theirs* or *both*, and the library's own conflict markers are shown in all three styles
* **Patch** – the diff as a diff(1)-style patch, inverted or stripped, applied with `patch( )` and checked against the expected text

#### JSON2ABAPType – ABAP Types from JSON (`src/06`)
* Paste JSON and press Generate – `zui2_json=>generate( )` builds the data, the library's type generator turns it into ABAP `TYPES`, shown in a code editor
* The library's naming modes, an editable JSON-name to ABAP-component mapping and the optional pretty printer
* A table of the structure the generator detected – structures, table types and components

#### abap-fm-logger – Function Module Logs in the Browser (`src/07`)
* A browser version of the log report `ZAFL_VIEWER`: search the logged calls by function module, date, status, message and the custom fields
* Each call opens with its import, export, changing and tables parameters as indented JSON
* An overview per function module – calls, share, errors, average runtime, last call
* Optional reprocessing through `zcl_afl_utilities=>re_process`: off by default, with a confirmation and the library's own authority check

#### zcl_pdf – PDF without Forms (`src/08`)
* A letter or invoice typed into a form becomes a PDF written in ABAP by one stand-alone class – no Adobe Document Server, SmartForm or spool
* Shown in a `sap.m.PDFViewer` and downloadable, regenerated on every option change
* Every library feature as an option: fonts and styles, font size, largest subject that fits, body shrunk into its box, text box alignment, rectangles, page formats, orientation, extra pages and page breaks – plus the measurements behind the layout

#### zcl_docx – Word Documents from ABAP (`src/09`)
* A delivery note or invoice form that `zcl_docx3=>get_document` fills into a Word template: fields, an address structure, a repeated table row, repeated paragraphs, checkboxes and read-only protection
* No template object needed – the app builds the template in ABAP; download it, change it in Word and upload it again, or upload your own
* A tag check against the template, and a text preview of the generated document

#### abapFaker – Test Data Generator (`src/10`)
* Choose a locale, the number of rows and which of the library's 37 generators to include – each with its call, a live example and a button to try it
* The generated records as a table whose columns follow the selection, and a CSV download

#### abap-data-validator – Validating Internal Tables (`src/11`)
* An editable table of demo contacts – e-mail, date, time, URL, phone, IMEI, GUID, number, JSON – some of them invalid on purpose
* A rules table: per column required, one of the library's type checks, a custom regex or a reference data element
* Validate runs `zcl_adata_validator->validate( )` over the table – every invalid cell turns red with the library's message

#### Installation
1. Install [abap2UI5](https://github.com/abap2UI5/abap2UI5)
2. Install the library of each sample you want to run (see [Samples](#samples))
3. Install this repository with abapGit

Each package needs abap2UI5 and its own library, nothing else. Library notes:
* abap_fm_json brings the authorization object `Z_JSON`; users need it for the function modules they call
* JSON2ABAPType's type generator is a local class of its report `ZJSON2ABAPTYPE` – install the whole repository
* abap-data-validator: install the Standard ABAP release (branch `master`), not the ABAP Cloud one
* zcl_docx: install the whole package, its XSLT transformations are part of the library

#### Running a Sample – SAPUI5 for the Charts
All samples run on OpenUI5, except tbox-stats (`src/01`): its charts are `sap.viz` controls, which ship with SAPUI5 only. abap2UI5 bootstraps OpenUI5 by default, so switch the bootstrap to SAPUI5 in your abap2UI5 user exit — the SAPUI5 of your system or the one of the SAPUI5 CDN. If your installation already has an exit class, add the one line to it:

```abap
CLASS zcl_my_abap2ui5_exit DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES z2ui5_if_ui5_exit.
ENDCLASS.

CLASS zcl_my_abap2ui5_exit IMPLEMENTATION.

  METHOD z2ui5_if_ui5_exit~set_config_http_get.
    " or the SAPUI5 of the system: /sap/public/bc/ui5_ui5/resources/sap-ui-core.js
    cs_config-src = `https://ui5.sap.com/resources/sap-ui-core.js`.
  ENDMETHOD.

  METHOD z2ui5_if_ui5_exit~set_config_http_post.
  ENDMETHOD.

ENDCLASS.
```

Then start the app class, e.g. `z2ui5_cl_osl_tbox_stats`, like any other abap2UI5 app.

#### Compatibility
* S/4 Private Cloud or On-Premise (Standard ABAP)
* SAP NetWeaver AS ABAP 7.50 or higher (Standard ABAP)
* SAPUI5 1.71 or higher

Not on ABAP Cloud yet: most of the libraries use APIs that are not released for ABAP Cloud (tbox-stats, for example, uses `NAME_FELD` and `IF_FSBP_CONST_RANGE`).

#### Security
Most samples read nothing from your system – they generate their data or work on what you type or upload. Three touch the system, each limited on purpose:
* **abap_fm_json** (`src/03`) calls function modules – only a hard-coded whitelist of harmless ones, after the library's `Z_JSON` authority check
* **abap-fm-logger** (`src/07`) reads the log table `ZAFL_LOG`, which holds whatever the logged function modules received and returned; reprocessing is off by default and runs the function module again
* **abap-data-validator** (`src/11`) leaves out the library's HTML check, which would send the cell content to validator.w3.org

The samples carry no authorization check of their own; restrict who may start them before using them beyond a development system.

#### Dependencies
* [abap2UI5](https://github.com/abap2UI5/abap2UI5)
* The library of each sample (see [Samples](#samples))

#### Credits
* [abap-tbox-stats](https://github.com/zenrosadira/abap-tbox-stats) by [Marco Marrone](https://github.com/zenrosadira), MIT License
* [abap2xlsx](https://github.com/abap2xlsx/abap2xlsx) by the abap2xlsx contributors, Apache License 2.0
* [abap_fm_json](https://github.com/cesar-sap/abap_fm_json) by César Martín, Apache License 2.0
* [abap-openapi](https://github.com/abap-openapi/abap-openapi) by the abap-openapi contributors, MIT License
* [ABAP Diff3](https://github.com/abapPM/ABAP-Diff3) by apm.to Inc. (Marc Bernard), MIT License – a port of [node-diff3](https://github.com/bhousel/node-diff3)
* [JSON2ABAPType](https://github.com/fidley/JSON2ABAPType) by Łukasz Pęgiel, Apache License 2.0
* [abap-fm-logger](https://github.com/hhelibeb/abap-fm-logger) by hhelibeb, Apache License 2.0
* [zcl_pdf](https://github.com/beraadim/zcl_pdf) by Bjørn Espen Raadim, MIT License
* [zcl_docx](https://github.com/AntonSikidin/zcl_docx) by Anton Sikidin, MIT License
* [abapFaker](https://github.com/se38/abapFaker) by Uwe Fetzer and contributors, MIT License
* [abap-data-validator](https://github.com/hhelibeb/abap-data-validator) by hhelibeb, MIT License

#### Your Library Here
Do you know an open-source ABAP library that deserves a UI? Open an issue, or add a sample yourself: one package per library, the library as a dependency — [CONTRIBUTING.md](CONTRIBUTING.md) has the steps.

#### Contribution & Support
Pull requests are welcome! Whether you're fixing bugs, adding new functionality, or improving documentation, your contributions are highly appreciated. If you encounter any issues, feel free to open an issue.
