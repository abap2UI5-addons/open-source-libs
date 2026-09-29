"! <p class="shorttext">abap-openapi generator in abap2UI5</p>
"!
"! Paste or upload an OpenAPI 3 JSON document and let the v2 generator of
"! https://github.com/abap-openapi/abap-openapi (zcl_oapi_generator=>generate_v2,
"! the call the report ZOAPI_GENERATE_V2 makes) build the ABAP sources for it:
"! the interface with the types and methods, the HTTP client class, the ICF
"! handler and the ICF implementation stub. The operations are listed as the
"! library's parser (zcl_oapi_parser) reads them. Every source is produced in
"! ABAP by the library - the frontend only shows the bound strings.
"!
"! Nothing is written to the system: the generated sources exist only as
"! strings in this app and can be downloaded as files. An uploaded file stays
"! in memory. The library ASSERTs on documents it cannot handle, so the app
"! checks first that the input is JSON, declares OpenAPI 3 and resolves every
"! local $ref - a document that passes and still trips an ASSERT is a case for
"! the library's issue tracker.
CLASS z2ui5_cl_osl_openapi DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_operation,
        method       TYPE string,
        method_state TYPE string,
        path         TYPE string,
        operation_id TYPE string,
        abap_name    TYPE string,
        summary      TYPE string,
        parameters   TYPE i,
        body         TYPE string,
        responses    TYPE string,
      END OF ty_s_operation.
    TYPES ty_t_operation TYPE STANDARD TABLE OF ty_s_operation WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_names,
        intf        TYPE string,
        clas_client TYPE string,
        clas_serv   TYPE string,
        clas_impl   TYPE string,
      END OF ty_s_names.

    TYPES:
      BEGIN OF ty_s_options,
        skip_deprecated TYPE abap_bool,
        use_empty_key   TYPE abap_bool,
        no_compression  TYPE abap_bool,
      END OF ty_s_options.

    TYPES:
      BEGIN OF ty_s_counts,
        operations TYPE string,
        intf       TYPE string,
        client     TYPE string,
        serv       TYPE string,
        impl       TYPE string,
      END OF ty_s_counts.

    DATA spec_json    TYPE string.
    DATA upload_value TYPE string.
    DATA upload_path  TYPE string.
    DATA names        TYPE ty_s_names.
    DATA options      TYPE ty_s_options.

    DATA tab          TYPE string.
    DATA has_result   TYPE abap_bool.
    DATA summary      TYPE string.
    DATA counts       TYPE ty_s_counts.
    DATA t_operations TYPE ty_t_operation.
    DATA src_intf     TYPE string.
    DATA src_client   TYPE string.
    DATA src_serv     TYPE string.
    DATA src_impl     TYPE string.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    METHODS view_display.
    METHODS view_input
      IMPORTING
        parent TYPE REF TO z2ui5_cl_ui5_view_builder.
    METHODS view_result
      IMPORTING
        parent TYPE REF TO z2ui5_cl_ui5_view_builder.
    METHODS view_source_tab
      IMPORTING
        items  TYPE REF TO z2ui5_cl_ui5_view_builder
        key    TYPE string
        text   TYPE string
        icon   TYPE string
        count  TYPE string
        source TYPE string.

    METHODS on_event.
    METHODS upload_apply.
    METHODS generate.
    METHODS result_clear.
    METHODS download
      IMPORTING
        key TYPE string.
    METHODS model_init.

    "! returns the reason why the library would stop on this document, empty if none
    METHODS spec_check
      RETURNING
        VALUE(result) TYPE string.
    METHODS names_check
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS example_spec
      RETURNING
        VALUE(result) TYPE string.
    CLASS-METHODS line_count
      IMPORTING
        val           TYPE string
      RETURNING
        VALUE(result) TYPE i.
    CLASS-METHODS method_state
      IMPORTING
        method        TYPE string
      RETURNING
        VALUE(result) TYPE string.
    CLASS-METHODS file_name
      IMPORTING
        name          TYPE string
        suffix        TYPE string
      RETURNING
        VALUE(result) TYPE string.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_osl_openapi IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_init( ).
      model_init( ).
      view_display( ).
    ELSEIF client->check_on_navigated( ).
      view_display( ).
    ELSEIF client->check_on_event( ).
      on_event( ).
    ENDIF.

  ENDMETHOD.


  METHOD view_display.

    DATA(page) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `View` ns = `mvc`
            )->a( n = `displayBlock` v = `true`
            )->a( n = `height`       v = `100%`
            )->a( n = `xmlns`        v = `sap.m`
            )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc`
            )->a( n = `xmlns:l`      v = `sap.ui.layout`
            )->a( n = `xmlns:form`   v = `sap.ui.layout.form`
            )->a( n = `xmlns:editor` v = `sap.ui.codeeditor`
            )->a( n = `xmlns:z2ui5`  v = `z2ui5.cc`
            )->ele( `Shell`
                )->a( n = `appWidthLimited` v = `false`
                )->ele( `Page`
                    )->a( n = `title`          v = `OpenAPI to ABAP - abap-openapi x abap2UI5`
                    )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
                    )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    page->ele( `headerContent`
        )->tag( `Link`
            )->a( n = `text`   v = `abap-openapi/abap-openapi`
            )->a( n = `href`   v = `https://github.com/abap-openapi/abap-openapi`
            )->a( n = `target` v = `_blank` ).

    DATA(grid) = page->ele( `content`
        )->ele( n = `Grid` ns = `l`
            )->a( n = `defaultSpan` v = `XL5 L5 M12 S12`
            )->a( n = `class`       v = `sapUiSmallMargin` ).

    view_input( grid ).
    view_result( grid ).

    client->view_display( page->stringify( ) ).

  ENDMETHOD.


  METHOD view_input.

    DATA(box) = parent->ele( `VBox` ).

    box->ele( `OverflowToolbar`
        )->a( n = `style` v = `Clear`
        )->ele( `content`
            )->tag( `Title`
                )->a( n = `text`  v = `OpenAPI 3 document (JSON)`
                )->a( n = `level` v = `H4`
            )->tag( `ToolbarSpacer`
            )->tag( n = `FileUploader` ns = `z2ui5`
                )->a( n = `value`             v = client->_bind( upload_value )
                )->a( n = `path`              v = client->_bind( upload_path )
                )->a( n = `fileType`          v = `json`
                )->a( n = `buttonText`        v = `Upload`
                )->a( n = `icon`              v = `sap-icon://upload`
                )->a( n = `buttonOnly`        v = `true`
                )->a( n = `checkDirectUpload` v = `true`
                )->a( n = `upload`            v = client->_event( `UPLOAD` )
            )->tag( `Button`
                )->a( n = `text`  v = `Petstore example`
                )->a( n = `icon`  v = `sap-icon://reset`
                )->a( n = `press` v = client->_event( `EXAMPLE` ) ).

    box->tag( n = `CodeEditor` ns = `editor`
        )->a( n = `type`   v = `json`
        )->a( n = `value`  v = client->_bind( spec_json )
        )->a( n = `height` v = `420px` ).

    box->ele( n = `SimpleForm` ns = `form`
        )->a( n = `editable`   v = `true`
        )->a( n = `layout`     v = `ResponsiveGridLayout`
        )->a( n = `title`      v = `Objects to generate`
        )->a( n = `labelSpanL` v = `4`
        )->a( n = `labelSpanM` v = `4`
        )->ele( n = `content` ns = `form`
            )->tag( `Label`
                )->a( n = `text` v = `Interface`
            )->tag( `Input`
                )->a( n = `value`     v = client->_bind( names-intf )
                )->a( n = `maxLength` v = `30`
            )->tag( `Label`
                )->a( n = `text` v = `Client class`
            )->tag( `Input`
                )->a( n = `value`     v = client->_bind( names-clas_client )
                )->a( n = `maxLength` v = `30`
            )->tag( `Label`
                )->a( n = `text` v = `ICF handler class`
            )->tag( `Input`
                )->a( n = `value`     v = client->_bind( names-clas_serv )
                )->a( n = `maxLength` v = `30`
            )->tag( `Label`
                )->a( n = `text` v = `ICF implementation class`
            )->tag( `Input`
                )->a( n = `value`     v = client->_bind( names-clas_impl )
                )->a( n = `maxLength` v = `30`
            )->tag( `Label`
                )->a( n = `text` v = `Options`
            )->tag( `CheckBox`
                )->a( n = `text`     v = `Skip deprecated operations`
                )->a( n = `selected` v = client->_bind( options-skip_deprecated )
            )->tag( `CheckBox`
                )->a( n = `text`     v = `Tables WITH EMPTY KEY`
                )->a( n = `selected` v = client->_bind( options-use_empty_key )
            )->tag( `CheckBox`
                )->a( n = `text`     v = `No HTTP compression in the client`
                )->a( n = `selected` v = client->_bind( options-no_compression ) ).

    box->tag( `Button`
        )->a( n = `text`  v = `Generate`
        )->a( n = `icon`  v = `sap-icon://process`
        )->a( n = `type`  v = `Emphasized`
        )->a( n = `width` v = `100%`
        )->a( n = `press` v = client->_event( `GENERATE` ) ).

  ENDMETHOD.


  METHOD view_result.

    DATA(box) = parent->ele( `VBox`
        )->ele( `layoutData`
            )->tag( n = `GridData` ns = `l`
                )->a( n = `span` v = `XL7 L7 M12 S12`
        )->end( ).

    box->tag( `MessageStrip`
        )->a( n = `text`     v = client->_bind( summary )
        )->a( n = `type`     v = `Information`
        )->a( n = `showIcon` v = `true` ).

    DATA(items) = box->ele( `IconTabBar`
        )->a( n = `selectedKey` v = client->_bind( tab )
        )->a( n = `expandable`  v = `false`
        )->a( n = `visible`     v = client->_bind( has_result )
        )->a( n = `class`       v = `sapUiResponsiveContentPadding`
        )->ele( `items` ).

    DATA(table) = items->ele( `IconTabFilter`
        )->a( n = `key`   v = `OPERATIONS`
        )->a( n = `text`  v = `Operations`
        )->a( n = `icon`  v = `sap-icon://list`
        )->a( n = `count` v = client->_bind( counts-operations )
        )->ele( `content`
            )->ele( `Table`
                )->a( n = `items`            v = client->_bind( t_operations )
                )->a( n = `growing`          v = `true`
                )->a( n = `growingThreshold` v = `50` ).

    " header is the default aggregation of sap.m.Column
    table->ele( `columns`
        )->ele( `Column`
            )->a( n = `width` v = `6rem`
            )->tag( `Text`
                )->a( n = `text` v = `Method`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Path`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `operationId / ABAP method`
        )->end(
        )->ele( `Column`
            )->a( n = `minScreenWidth` v = `Desktop`
            )->a( n = `demandPopin`    v = `true`
            )->tag( `Text`
                )->a( n = `text` v = `Summary`
        )->end(
        )->ele( `Column`
            )->a( n = `minScreenWidth` v = `Tablet`
            )->a( n = `demandPopin`    v = `true`
            )->a( n = `hAlign`         v = `End`
            )->tag( `Text`
                )->a( n = `text` v = `Parameters`
        )->end(
        )->ele( `Column`
            )->a( n = `minScreenWidth` v = `Tablet`
            )->a( n = `demandPopin`    v = `true`
            )->tag( `Text`
                )->a( n = `text` v = `Request body`
        )->end(
        )->ele( `Column`
            )->a( n = `minScreenWidth` v = `Tablet`
            )->a( n = `demandPopin`    v = `true`
            )->tag( `Text`
                )->a( n = `text` v = `Responses` ).

    table->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells`
                )->tag( `ObjectStatus`
                    )->a( n = `text`  v = `{METHOD}`
                    )->a( n = `state` v = `{METHOD_STATE}`
                )->tag( `Text`
                    )->a( n = `text` v = `{PATH}`
                )->tag( `ObjectIdentifier`
                    )->a( n = `title` v = `{OPERATION_ID}`
                    )->a( n = `text`  v = `{ABAP_NAME}`
                )->tag( `Text`
                    )->a( n = `text` v = `{SUMMARY}`
                )->tag( `Text`
                    )->a( n = `text` v = `{PARAMETERS}`
                )->tag( `Text`
                    )->a( n = `text` v = `{BODY}`
                )->tag( `Text`
                    )->a( n = `text` v = `{RESPONSES}` ).

    view_source_tab( items  = items
                     key    = `INTF`
                     text   = `Interface`
                     icon   = `sap-icon://syntax`
                     count  = client->_bind( counts-intf )
                     source = client->_bind( src_intf ) ).
    view_source_tab( items  = items
                     key    = `CLIENT`
                     text   = `Client`
                     icon   = `sap-icon://outbox`
                     count  = client->_bind( counts-client )
                     source = client->_bind( src_client ) ).
    view_source_tab( items  = items
                     key    = `SERV`
                     text   = `ICF handler`
                     icon   = `sap-icon://inbox`
                     count  = client->_bind( counts-serv )
                     source = client->_bind( src_serv ) ).
    view_source_tab( items  = items
                     key    = `IMPL`
                     text   = `ICF implementation`
                     icon   = `sap-icon://source-code`
                     count  = client->_bind( counts-impl )
                     source = client->_bind( src_impl ) ).

  ENDMETHOD.


  METHOD view_source_tab.

    DATA(content) = items->ele( `IconTabFilter`
        )->a( n = `key`   v = key
        )->a( n = `text`  v = text
        )->a( n = `icon`  v = icon
        )->a( n = `count` v = count
        )->ele( `content` ).

    content->ele( `OverflowToolbar`
        )->a( n = `style` v = `Clear`
        )->ele( `content`
            )->tag( `Text`
                )->a( n = `text` v = `Lines of generated ABAP - read-only`
            )->tag( `ToolbarSpacer`
            )->tag( `Button`
                )->a( n = `text`  v = `Download`
                )->a( n = `icon`  v = `sap-icon://download`
                )->a( n = `press` v = client->_event( val = `DOWNLOAD` arg = key ) ).

    content->tag( n = `CodeEditor` ns = `editor`
        )->a( n = `type`     v = `abap`
        )->a( n = `value`    v = source
        )->a( n = `editable` v = `false`
        )->a( n = `height`   v = `560px` ).

  ENDMETHOD.


  METHOD on_event.

    CASE client->get_event( ).

      WHEN `GENERATE`.
        generate( ).

      WHEN `EXAMPLE`.
        spec_json = example_spec( ).
        result_clear( ).

      WHEN `UPLOAD`.
        upload_apply( ).

      WHEN `DOWNLOAD`.
        download( client->get_event_arg( ) ).

    ENDCASE.

  ENDMETHOD.


  METHOD upload_apply.

    " the uploader delivers a data URI - data:<mime>;base64,<payload>
    DATA(payload) = substring_after( val = upload_value sub = `,` ).
    IF payload IS INITIAL.
      client->message_box_display( text = `The uploaded file is empty.` type = `error` ).
      RETURN.
    ENDIF.

    TRY.
        spec_json = cl_abap_codepage=>convert_from( cl_web_http_utility=>decode_x_base64( payload ) ).
      CATCH cx_root INTO DATA(error).
        client->message_box_display( error ).
        RETURN.
    ENDTRY.

    CLEAR upload_value.
    result_clear( ).
    client->message_toast_display( |{ upload_path } loaded - press Generate| ).

  ENDMETHOD.


  METHOD generate.

    result_clear( ).

    DATA(problem) = names_check( ).
    IF problem IS INITIAL.
      problem = spec_check( ).
    ENDIF.
    IF problem IS NOT INITIAL.
      summary = problem.
      client->message_box_display( text = problem type = `error` ).
      RETURN.
    ENDIF.

    " the operations as the library's parser reads them
    DATA(specification) = NEW zcl_oapi_parser( )->parse( spec_json ).
    LOOP AT specification-operations INTO DATA(operation).
      IF options-skip_deprecated = abap_true AND operation-deprecated = abap_true.
        CONTINUE.
      ENDIF.
      DATA(responses) = ``.
      LOOP AT operation-responses INTO DATA(response).
        responses = COND #( WHEN responses IS INITIAL THEN response-code ELSE |{ responses }, { response-code }| ).
      ENDLOOP.
      DATA(body) = operation-request_body-schema_ref.
      REPLACE FIRST OCCURRENCE OF `#/components/schemas/` IN body WITH ``.
      IF body IS INITIAL.
        body = operation-request_body-type.
      ENDIF.
      DATA(method) = to_upper( operation-method ).
      INSERT VALUE #( method       = method
                      method_state = method_state( method )
                      path         = operation-path
                      operation_id = operation-operation_id
                      abap_name    = operation-abap_name
                      summary      = COND #( WHEN operation-deprecated = abap_true
                                             THEN |(deprecated) { operation-summary }|
                                             ELSE operation-summary )
                      parameters   = lines( operation-parameters ) + lines( operation-parameters_ref )
                      body         = body
                      responses    = responses ) INTO TABLE t_operations.
    ENDLOOP.

    " the generator itself - the call the report ZOAPI_GENERATE_V2 makes
    DATA(input) = VALUE zcl_oapi_generator_v2=>ty_input( intf            = names-intf
                                                          clas_client     = names-clas_client
                                                          clas_icf_serv   = names-clas_serv
                                                          clas_icf_impl   = names-clas_impl
                                                          openapi_json    = spec_json
                                                          skip_deprecated = options-skip_deprecated
                                                          use_empty_key   = options-use_empty_key
                                                          no_compression  = options-no_compression ).
    DATA(result) = zcl_oapi_generator=>generate_v2( input ).

    src_intf   = result-intf.
    src_client = result-clas_client.
    src_serv   = result-clas_icf_serv.
    src_impl   = result-clas_icf_impl.

    DATA(lines_intf)   = line_count( src_intf ).
    DATA(lines_client) = line_count( src_client ).
    DATA(lines_serv)   = line_count( src_serv ).
    DATA(lines_impl)   = line_count( src_impl ).
    counts = VALUE #( operations = |{ lines( t_operations ) }|
                      intf       = |{ lines_intf }|
                      client     = |{ lines_client }|
                      serv       = |{ lines_serv }|
                      impl       = |{ lines_impl }| ).

    summary = |{ specification-info-title } { specification-info-version } (OpenAPI { specification-openapi }): | &&
              |{ lines( t_operations ) } operations, { lines( specification-components-schemas ) } schemas - | &&
              |{ lines_intf + lines_client + lines_serv + lines_impl } lines of ABAP generated|.
    has_result = abap_true.
    tab = `OPERATIONS`.

  ENDMETHOD.


  METHOD result_clear.

    CLEAR: t_operations, src_intf, src_client, src_serv, src_impl, counts, has_result.
    summary = `Press Generate to run the abap-openapi v2 generator on the document.`.

  ENDMETHOD.


  METHOD download.

    DATA(name) = ``.
    DATA(source) = ``.
    CASE key.
      WHEN `INTF`.
        name   = file_name( name = names-intf suffix = `.intf.abap` ).
        source = src_intf.
      WHEN `CLIENT`.
        name   = file_name( name = names-clas_client suffix = `.clas.abap` ).
        source = src_client.
      WHEN `SERV`.
        name   = file_name( name = names-clas_serv suffix = `.clas.abap` ).
        source = src_serv.
      WHEN `IMPL`.
        name   = file_name( name = names-clas_impl suffix = `.clas.abap` ).
        source = src_impl.
    ENDCASE.
    IF source IS INITIAL.
      client->message_toast_display( `Nothing generated yet - press Generate first` ).
      RETURN.
    ENDIF.

    DATA(base64) = cl_web_http_utility=>encode_x_base64( cl_abap_codepage=>convert_to( source ) ).
    client->follow_up_action( val   = client->cs_event-download_b64_file
                              t_arg = VALUE #( ( |data:text/plain;base64,{ base64 }| ) ( name ) ) ).

  ENDMETHOD.


  METHOD spec_check.

    IF spec_json IS INITIAL.
      result = `Paste or upload an OpenAPI 3 document first.`.
      RETURN.
    ENDIF.

    " the library parses with sXML, which raises on text that is no JSON
    DATA json TYPE REF TO zcl_oapi_json.
    TRY.
        json = NEW zcl_oapi_json( spec_json ).
      CATCH cx_root INTO DATA(error).
        result = |The document is no valid JSON: { error->get_text( ) }|.
        RETURN.
    ENDTRY.

    DATA(version) = json->value_string( `/openapi` ).
    IF version NP `3*`.
      result = COND #( WHEN json->value_string( `/swagger` ) IS NOT INITIAL
                       THEN `Swagger 2 is not supported - convert the document to OpenAPI 3 first (e.g. with the Swagger Editor).`
                       ELSE `The document declares no OpenAPI 3 version ("openapi": "3.x.x").` ).
      RETURN.
    ENDIF.

    IF json->exists( `/paths` ) = abap_false.
      result = `The document has no "paths" object.`.
      RETURN.
    ENDIF.

    " every $ref has to point into this document, and to something that is there
    FIND ALL OCCURRENCES OF REGEX `"\$ref"\s*:\s*"([^"]*)"` IN spec_json RESULTS DATA(matches).
    LOOP AT matches INTO DATA(match).
      DATA(submatch) = match-submatches[ 1 ].
      DATA(ref) = substring( val = spec_json off = submatch-offset len = submatch-length ).
      IF strlen( ref ) < 2 OR substring( val = ref len = 2 ) <> `#/`.
        result = |Only local references are supported: { ref }|.
        RETURN.
      ENDIF.
      IF json->exists( substring( val = ref off = 1 ) ) = abap_false.
        result = |The reference { ref } points to nothing in the document.|.
        RETURN.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD names_check.

    DATA(all_names) = VALUE string_table( ( names-intf ) ( names-clas_client ) ( names-clas_serv ) ( names-clas_impl ) ).
    LOOP AT all_names INTO DATA(name).
      IF name IS INITIAL OR strlen( name ) > 30.
        result = `Give every object a name of 1 to 30 characters.`.
        RETURN.
      ENDIF.
      IF NOT matches( val = name regex = `^[A-Za-z/][A-Za-z0-9_/]*$` ).
        result = |{ name } is no valid ABAP object name.|.
        RETURN.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD model_init.

    names = VALUE #( intf        = `zif_petstore`
                     clas_client = `zcl_petstore_client`
                     clas_serv   = `zcl_petstore_icf_serv`
                     clas_impl   = `zcl_petstore_icf_impl` ).
    options = VALUE #( skip_deprecated = abap_true
                       use_empty_key   = abap_true ).
    spec_json = example_spec( ).
    generate( ).

  ENDMETHOD.


  METHOD example_spec.

    DATA(json_lines) = VALUE string_table(
        ( `{` )
        ( `  "openapi": "3.0.0",` )
        ( `  "info": {` )
        ( `    "title": "Petstore",` )
        ( `    "version": "1.0.0",` )
        ( `    "description": "A small petstore to try the generator"` )
        ( `  },` )
        ( `  "servers": [ { "url": "https://petstore.example.com/v1" } ],` )
        ( `  "paths": {` )
        ( `    "/pets": {` )
        ( `      "get": {` )
        ( `        "operationId": "listPets",` )
        ( `        "summary": "List all pets",` )
        ( `        "parameters": [` )
        ( `          { "name": "limit", "in": "query", "required": false, "schema": { "type": "integer" } }` )
        ( `        ],` )
        ( `        "responses": {` )
        ( `          "200": {` )
        ( `            "description": "A list of pets",` )
        ( `            "content": { "application/json": { "schema": { "$ref": "#/components/schemas/Pets" } } }` )
        ( `          }` )
        ( `        }` )
        ( `      },` )
        ( `      "post": {` )
        ( `        "operationId": "createPet",` )
        ( `        "summary": "Create a pet",` )
        ( `        "requestBody": {` )
        ( `          "content": { "application/json": { "schema": { "$ref": "#/components/schemas/Pet" } } }` )
        ( `        },` )
        ( `        "responses": { "201": { "description": "Created" } }` )
        ( `      }` )
        ( `    },` )
        ( `    "/pets/{petId}": {` )
        ( `      "get": {` )
        ( `        "operationId": "showPetById",` )
        ( `        "summary": "Info for a specific pet",` )
        ( `        "parameters": [` )
        ( `          { "name": "petId", "in": "path", "required": true, "schema": { "type": "string" } }` )
        ( `        ],` )
        ( `        "responses": {` )
        ( `          "200": {` )
        ( `            "description": "The pet",` )
        ( `            "content": { "application/json": { "schema": { "$ref": "#/components/schemas/Pet" } } }` )
        ( `          }` )
        ( `        }` )
        ( `      },` )
        ( `      "delete": {` )
        ( `        "operationId": "deletePet",` )
        ( `        "summary": "Delete a pet",` )
        ( `        "parameters": [` )
        ( `          { "name": "petId", "in": "path", "required": true, "schema": { "type": "string" } }` )
        ( `        ],` )
        ( `        "responses": { "204": { "description": "Deleted" } }` )
        ( `      }` )
        ( `    }` )
        ( `  },` )
        ( `  "components": {` )
        ( `    "schemas": {` )
        ( `      "Pet": {` )
        ( `        "type": "object",` )
        ( `        "required": [ "id", "name" ],` )
        ( `        "properties": {` )
        ( `          "id": { "type": "integer" },` )
        ( `          "name": { "type": "string" },` )
        ( `          "tag": { "type": "string" }` )
        ( `        }` )
        ( `      },` )
        ( `      "Pets": {` )
        ( `        "type": "array",` )
        ( `        "items": { "$ref": "#/components/schemas/Pet" }` )
        ( `      }` )
        ( `    }` )
        ( `  }` )
        ( `}` ) ).

    result = concat_lines_of( table = json_lines sep = cl_abap_char_utilities=>newline ).

  ENDMETHOD.


  METHOD line_count.

    IF val IS INITIAL.
      RETURN.
    ENDIF.
    result = count( val = val sub = cl_abap_char_utilities=>newline ) + 1.

  ENDMETHOD.


  METHOD method_state.

    result = COND #( WHEN method = `GET`                     THEN `Success`
                     WHEN method = `POST`                    THEN `Information`
                     WHEN method = `DELETE`                  THEN `Error`
                     WHEN method = `PUT` OR method = `PATCH` THEN `Warning`
                     ELSE `None` ).

  ENDMETHOD.


  METHOD file_name.

    " abapGit writes a namespace /abc/ as #abc#
    result = to_lower( name ) && suffix.
    REPLACE ALL OCCURRENCES OF `/` IN result WITH `#`.

  ENDMETHOD.

ENDCLASS.
