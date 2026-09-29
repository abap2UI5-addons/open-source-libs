"! <p class="shorttext">abap_fm_json - function modules as JSON</p>
"!
"! Function modules called with JSON in and JSON out through
"! https://github.com/cesar-sap/abap_fm_json - pick a function module, read
"! its interface, edit the JSON body and run it. Every step is a public
"! method of zcl_json_handler, the same ones its ICF handler strings
"! together: build_params( ) reads the interface, json_deserialize( ) or
"! deserialize_id( ) fill the parameters from the JSON, the dynamic CALL
"! FUNCTION runs it, serialize_json( ) / serialize_id( ) / serialize_xml( ) /
"! serialize_yaml( ) / serialize_perl( ) write the result.
"!
"! Security: the app offers a hard-coded whitelist of harmless, read-only
"! standard function modules (connection and structure tests, system
"! information, a date calculation) and calls nothing else. Before every call
"! it runs the library's own authority check - object Z_JSON, field FMNAME -
"! exactly as the ICF handler does; a user without it gets the handler's
"! "not authorized" and no call.
CLASS z2ui5_cl_osl_fm_json DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_key_text,
        key  TYPE string,
        text TYPE string,
      END OF ty_s_key_text.
    TYPES ty_t_key_text TYPE STANDARD TABLE OF ty_s_key_text WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_param,
        name        TYPE string,
        description TYPE string,
        kind        TYPE string,
        kind_state  TYPE string,
        type        TYPE string,
        default     TYPE string,
      END OF ty_s_param.
    TYPES ty_t_param TYPE STANDARD TABLE OF ty_s_param WITH EMPTY KEY.

    DATA function        TYPE string.
    DATA t_functions     TYPE ty_t_key_text.
    DATA interface_title TYPE string.
    DATA t_params        TYPE ty_t_param.

    DATA input           TYPE string.
    DATA deserializer    TYPE string.

    DATA format          TYPE string.
    DATA t_formats       TYPE ty_t_key_text.
    DATA upcase          TYPE abap_bool.
    DATA camelcase       TYPE abap_bool.
    DATA show_imports    TYPE abap_bool.
    DATA pretty          TYPE abap_bool.

    DATA status_text     TYPE string.
    DATA status_type     TYPE string.
    DATA http_call       TYPE string.
    DATA output          TYPE string.
    DATA output_type     TYPE string.

  PROTECTED SECTION.
    TYPES:
      BEGIN OF ty_s_function,
        name    TYPE string,
        text    TYPE string,
        example TYPE string,
      END OF ty_s_function.
    TYPES ty_t_function TYPE STANDARD TABLE OF ty_s_function WITH EMPTY KEY.

    DATA client    TYPE REF TO z2ui5_if_client.
    DATA whitelist TYPE ty_t_function.

    METHODS view_display.
    METHODS view_interface
      IMPORTING
        parent TYPE REF TO z2ui5_cl_ui5_view_builder.
    METHODS view_input
      IMPORTING
        parent TYPE REF TO z2ui5_cl_ui5_view_builder.
    METHODS view_output
      IMPORTING
        content TYPE REF TO z2ui5_cl_ui5_view_builder.

    METHODS on_event.
    METHODS function_select.
    METHODS interface_update.
    METHODS input_template.
    METHODS function_call.
    METHODS output_serialize
      IMPORTING
        paramtab TYPE abap_func_parmbind_tab
        exceptab TYPE abap_func_excpbind_tab
        params   TYPE ANY TABLE
      RAISING
        zcx_json.
    METHODS status_set
      IMPORTING
        type TYPE string
        text TYPE string.
    METHODS model_init.

    CLASS-METHODS json_pretty
      IMPORTING
        json          TYPE string
      RETURNING
        VALUE(result) TYPE string.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_osl_fm_json IMPLEMENTATION.

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
            )->a( n = `xmlns:core`   v = `sap.ui.core`
            )->a( n = `xmlns:l`      v = `sap.ui.layout`
            )->a( n = `xmlns:editor` v = `sap.ui.codeeditor`
            )->ele( `Shell`
                )->a( n = `appWidthLimited` v = `false`
                )->ele( `Page`
                    )->a( n = `title`          v = `Function modules as JSON - abap_fm_json x abap2UI5`
                    )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
                    )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    page->ele( `headerContent`
        )->tag( `Link`
            )->a( n = `text`   v = `cesar-sap/abap_fm_json`
            )->a( n = `href`   v = `https://github.com/cesar-sap/abap_fm_json`
            )->a( n = `target` v = `_blank` ).

    DATA(content) = page->ele( `content`
        )->ele( `VBox`
            )->a( n = `class` v = `sapUiSmallMargin` ).

    content->tag( `MessageStrip`
        )->a( n = `text`     v = `Pick a function module, edit its JSON input and call it through ZCL_JSON_HANDLER - ` &&
                                 `the interface lookup, deserializer, dynamic call and serializers of its ICF handler, ` &&
                                 `behind the same Z_JSON authority check. Only a whitelist of read-only standard function modules is offered.`
        )->a( n = `type`     v = `Information`
        )->a( n = `showIcon` v = `true` ).

    content->ele( `OverflowToolbar`
        )->a( n = `style` v = `Clear`
        )->ele( `content`
            )->tag( `Label`
                )->a( n = `text` v = `Function module`
            )->ele( `Select`
                )->a( n = `selectedKey` v = client->_bind( function )
                )->a( n = `items`       v = client->_bind( t_functions )
                )->a( n = `change`      v = client->_event( `FUNCTION` )
                )->a( n = `width`       v = `32rem`
                )->tag( n = `Item` ns = `core`
                    )->a( n = `key`  v = `{KEY}`
                    )->a( n = `text` v = `{TEXT}` ).

    DATA(grid) = content->ele( n = `Grid` ns = `l`
        )->a( n = `defaultSpan` v = `XL6 L6 M12 S12`
        )->a( n = `class`       v = `sapUiSmallMarginTop` ).

    view_interface( grid ).
    view_input( grid ).
    view_output( content ).

    client->view_display( page->stringify( ) ).

  ENDMETHOD.


  METHOD view_interface.

    DATA(box) = parent->ele( `VBox` ).
    box->tag( `Title`
        )->a( n = `text`  v = client->_bind( interface_title )
        )->a( n = `level` v = `H4` ).

    DATA(table) = box->ele( `Table`
        )->a( n = `items` v = client->_bind( val = t_params omit_initial_paths = VALUE #( ( `KIND_STATE` ) ) ) ).

    table->ele( `columns`
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Parameter`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Kind`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Type`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Default / optional` ).

    table->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells`
                )->tag( `ObjectIdentifier`
                    )->a( n = `title` v = `{NAME}`
                    )->a( n = `text`  v = `{DESCRIPTION}`
                )->tag( `ObjectStatus`
                    )->a( n = `text`  v = `{KIND}`
                    )->a( n = `state` v = `{KIND_STATE}`
                )->tag( `Text`
                    )->a( n = `text` v = `{TYPE}`
                )->tag( `Text`
                    )->a( n = `text` v = `{DEFAULT}` ).

  ENDMETHOD.


  METHOD view_input.

    DATA(box) = parent->ele( `VBox` ).
    box->tag( `Title`
        )->a( n = `text`  v = `Input - the JSON body of the HTTP request`
        )->a( n = `level` v = `H4` ).

    box->ele( `OverflowToolbar`
        )->a( n = `style` v = `Clear`
        )->ele( `content`
            )->tag( `Button`
                )->a( n = `text`  v = `Example`
                )->a( n = `icon`  v = `sap-icon://lightbulb`
                )->a( n = `press` v = client->_event( `EXAMPLE` )
            )->tag( `Button`
                )->a( n = `text`  v = `Template from interface`
                )->a( n = `icon`  v = `sap-icon://create-form`
                )->a( n = `press` v = client->_event( `TEMPLATE` )
            )->tag( `ToolbarSpacer`
            )->tag( `Label`
                )->a( n = `text` v = `Deserializer`
            )->ele( `SegmentedButton`
                )->a( n = `selectedKey` v = client->_bind( deserializer )
                )->ele( `items`
                    )->tag( `SegmentedButtonItem`
                        )->a( n = `key`  v = `ID`
                        )->a( n = `text` v = `deserialize_id`
                    )->tag( `SegmentedButtonItem`
                        )->a( n = `key`  v = `CLASSIC`
                        )->a( n = `text` v = `json_deserialize` ).

    box->tag( n = `CodeEditor` ns = `editor`
        )->a( n = `value`  v = client->_bind( input )
        )->a( n = `type`   v = `json`
        )->a( n = `height` v = `320px`
        )->a( n = `width`  v = `100%` ).

  ENDMETHOD.


  METHOD view_output.

    content->ele( `OverflowToolbar`
        )->a( n = `style` v = `Clear`
        )->a( n = `class` v = `sapUiSmallMarginTop`
        )->ele( `content`
            )->tag( `Label`
                )->a( n = `text` v = `Output`
            )->ele( `Select`
                )->a( n = `selectedKey` v = client->_bind( format )
                )->a( n = `items`       v = client->_bind( t_formats )
                )->tag( n = `Item` ns = `core`
                    )->a( n = `key`  v = `{KEY}`
                    )->a( n = `text` v = `{TEXT}`
            )->end(
            )->tag( `CheckBox`
                )->a( n = `text`     v = `upcase`
                )->a( n = `selected` v = client->_bind( upcase )
            )->tag( `CheckBox`
                )->a( n = `text`     v = `camelcase`
                )->a( n = `selected` v = client->_bind( camelcase )
            )->tag( `CheckBox`
                )->a( n = `text`     v = `show_import_params`
                )->a( n = `selected` v = client->_bind( show_imports )
            )->tag( `CheckBox`
                )->a( n = `text`     v = `pretty-print JSON`
                )->a( n = `selected` v = client->_bind( pretty )
            )->tag( `ToolbarSpacer`
            )->tag( `Button`
                )->a( n = `text`  v = `Call function module`
                )->a( n = `icon`  v = `sap-icon://process`
                )->a( n = `type`  v = `Emphasized`
                )->a( n = `press` v = client->_event( `CALL` ) ).

    content->tag( `MessageStrip`
        )->a( n = `text`     v = client->_bind( status_text )
        )->a( n = `type`     v = client->_bind( val = status_type omit_initial = abap_true )
        )->a( n = `showIcon` v = `true`
        )->a( n = `class`    v = `sapUiSmallMarginTop` ).

    content->tag( `Text`
        )->a( n = `text`  v = client->_bind( http_call )
        )->a( n = `class` v = `sapUiSmallMarginTop sapUiTinyMarginBottom` ).

    content->tag( n = `CodeEditor` ns = `editor`
        )->a( n = `value`    v = client->_bind( output )
        )->a( n = `type`     v = client->_bind( output_type )
        )->a( n = `editable` v = `false`
        )->a( n = `height`   v = `360px`
        )->a( n = `width`    v = `100%` ).

  ENDMETHOD.


  METHOD on_event.

    CASE client->get_event( ).

      WHEN `FUNCTION`.
        function_select( ).

      WHEN `EXAMPLE`.
        input = whitelist[ name = function ]-example.

      WHEN `TEMPLATE`.
        input_template( ).

      WHEN `CALL`.
        function_call( ).

    ENDCASE.

  ENDMETHOD.


  METHOD function_select.

    input = whitelist[ name = function ]-example.
    CLEAR output.
    status_set( type = `None`
                text = |{ function } not called yet - edit the input and press "Call function module".| ).
    interface_update( ).

  ENDMETHOD.


  METHOD interface_update.

    DATA params TYPE STANDARD TABLE OF rfc_fint_p WITH EMPTY KEY.

    " the interface as the ICF handler reads it - build_params( ) asks
    " RFC_GET_FUNCTION_INTERFACE_P, the params table is what it got back
    zcl_json_handler=>build_params( EXPORTING  function_name          = CONV #( function )
                                    IMPORTING  params                 = params
                                    EXCEPTIONS invalid_function       = 1
                                               unsupported_param_type = 2
                                               OTHERS                 = 3 ).
    IF sy-subrc <> 0.
      CLEAR t_params.
      interface_title = |Interface of { function } - not readable (build_params( ) sy-subrc { sy-subrc })|.
      RETURN.
    ENDIF.

    t_params = VALUE #( FOR p IN params
        ( name        = p-parameter
          description = p-paramtext
          kind        = SWITCH #( p-paramclass
                                  WHEN `I` THEN `Importing - JSON in`
                                  WHEN `E` THEN `Exporting - JSON out`
                                  WHEN `C` THEN `Changing - in and out`
                                  WHEN `T` THEN `Tables - in and out`
                                  WHEN `X` THEN `Exception`
                                  ELSE p-paramclass )
          kind_state  = SWITCH #( p-paramclass
                                  WHEN `I` THEN `Information`
                                  WHEN `E` THEN `Success`
                                  WHEN `X` THEN `Error`
                                  ELSE `Warning` )
          type        = COND #( WHEN p-fieldname IS INITIAL THEN p-tabname
                                ELSE |{ p-tabname }-{ p-fieldname }| )
          default     = COND #( WHEN p-default IS NOT INITIAL THEN p-default
                                WHEN p-optional = abap_true THEN `optional` ) ) ).

    interface_title = |Interface of { function } - { lines( t_params ) } parameters, from build_params( )|.

  ENDMETHOD.


  METHOD input_template.

    DATA paramtab TYPE abap_func_parmbind_tab.

    zcl_json_handler=>build_params( EXPORTING  function_name          = CONV #( function )
                                    IMPORTING  paramtab               = paramtab
                                    EXCEPTIONS invalid_function       = 1
                                               unsupported_param_type = 2
                                               OTHERS                 = 3 ).
    IF sy-subrc <> 0.
      client->message_box_display( |build_params( ) failed for { function } (sy-subrc { sy-subrc })| ).
      RETURN.
    ENDIF.

    " the input side only (the handler's kinds are the caller's view: the
    " function module's IMPORTING parameters are abap_func_exporting), with
    " the defaults build_params( ) put in - serialized by the library itself
    DELETE paramtab WHERE kind = abap_func_importing.
    zcl_json_handler=>serialize_json( EXPORTING paramtab  = paramtab
                                                show_impp = abap_true
                                                lowercase = abap_true
                                      IMPORTING o_string  = input ).
    input = json_pretty( input ).

  ENDMETHOD.


  METHOD function_call.

    DATA paramtab TYPE abap_func_parmbind_tab.
    DATA exceptab TYPE abap_func_excpbind_tab.
    DATA params   TYPE STANDARD TABLE OF rfc_fint_p WITH EMPTY KEY.

    IF NOT line_exists( whitelist[ name = function ] ).
      client->message_box_display( |{ function } is not on the whitelist of this sample| ).
      RETURN.
    ENDIF.
    DATA(funcname) = CONV rs38l_fnam( function ).

    " the library's own authority check, as in its ICF handler
    AUTHORITY-CHECK OBJECT 'Z_JSON'
      ID 'FMNAME' FIELD funcname.
    IF sy-subrc <> 0.
      CLEAR output.
      status_set( type = `Error`
                  text = |403 Not authorized - you are not authorized to invoke { function } | &&
                         |(authorization object Z_JSON, field FMNAME).| ).
      RETURN.
    ENDIF.

    zcl_json_handler=>build_params( EXPORTING  function_name          = funcname
                                    IMPORTING  paramtab               = paramtab
                                               exceptab               = exceptab
                                               params                 = params
                                    EXCEPTIONS invalid_function       = 1
                                               unsupported_param_type = 2
                                               OTHERS                 = 3 ).
    IF sy-subrc <> 0.
      client->message_box_display( |Invalid function { function } - build_params( ) sy-subrc { sy-subrc }| ).
      RETURN.
    ENDIF.

    " deserialize_id( ) runs CALL TRANSFORMATION id, json_deserialize( ) the
    " handler's default, parses with CL_JAVA_SCRIPT - an engine newer kernels
    " no longer run, so its failure is shown, not dumped
    TRY.
        IF deserializer = `CLASSIC`.
          zcl_json_handler=>json_deserialize( EXPORTING json     = input
                                              CHANGING  paramtab = paramtab ).
        ELSE.
          zcl_json_handler=>deserialize_id( EXPORTING json     = input
                                            CHANGING  paramtab = paramtab ).
        ENDIF.
      CATCH zcx_json INTO DATA(json_error).
        client->message_box_display( |The input is no valid JSON for { function }: { json_error->message }| ).
        RETURN.
      CATCH cx_root INTO DATA(error).
        client->message_box_display( error ).
        RETURN.
    ENDTRY.

    DATA(rc) = 0.
    TRY.
        CALL FUNCTION funcname
          PARAMETER-TABLE paramtab
          EXCEPTION-TABLE exceptab.
        rc = sy-subrc.
      CATCH cx_root INTO error.
        client->message_box_display( error ).
        RETURN.
    ENDTRY.

    " as the handler does: keep the exception that was raised, drop the rest
    DELETE exceptab WHERE value <> rc.
    DATA(exception) = VALUE string( exceptab[ 1 ]-name OPTIONAL ).
    IF exception IS INITIAL.
      status_set( type = `Success`
                  text = |{ function } called - no exception.| ).
    ELSE.
      status_set( type = `Warning`
                  text = |{ function } raised exception { exception } | &&
                         |(the handler sends it as header X-SAPRFC-Exception).| ).
    ENDIF.

    TRY.
        output_serialize( paramtab = paramtab
                          exceptab = exceptab
                          params   = params ).
      CATCH zcx_json INTO json_error.
        client->message_box_display( |Serialization failed: { json_error->message }| ).
    ENDTRY.

  ENDMETHOD.


  METHOD output_serialize.

    DATA(funcname)  = CONV rs38l_fnam( function ).
    DATA(lowercase) = xsdbool( upcase = abap_false ).

    CASE format.

      WHEN `JSON`.
        zcl_json_handler=>serialize_json( EXPORTING paramtab  = paramtab
                                                    exceptab  = exceptab
                                                    params    = params
                                                    show_impp = show_imports
                                                    lowercase = lowercase
                                                    camelcase = camelcase
                                          IMPORTING o_string  = output ).

      WHEN `JSON_ID`.
        zcl_json_handler=>serialize_id( EXPORTING paramtab  = paramtab
                                                  exceptab  = exceptab
                                                  params    = params
                                                  show_impp = show_imports
                                                  lowercase = lowercase
                                                  camelcase = camelcase
                                                  funcname  = funcname
                                                  format    = `JSON`
                                        IMPORTING o_string  = output ).

      WHEN `XML`.
        zcl_json_handler=>serialize_xml( EXPORTING paramtab  = paramtab
                                                   exceptab  = exceptab
                                                   params    = params
                                                   show_impp = show_imports
                                                   lowercase = lowercase
                                                   funcname  = funcname
                                                   format    = `XML`
                                         IMPORTING o_string  = output ).

      WHEN `XML_ID`.
        zcl_json_handler=>serialize_id( EXPORTING paramtab  = paramtab
                                                  exceptab  = exceptab
                                                  params    = params
                                                  show_impp = show_imports
                                                  funcname  = funcname
                                                  format    = `XML`
                                        IMPORTING o_string  = output ).

      WHEN `YAML`.
        zcl_json_handler=>serialize_yaml( EXPORTING paramtab    = paramtab
                                                    exceptab    = exceptab
                                                    params      = params
                                                    show_impp   = show_imports
                                                    lowercase   = lowercase
                                          IMPORTING yaml_string = output ).

      WHEN `PERL`.
        zcl_json_handler=>serialize_perl( EXPORTING paramtab    = paramtab
                                                    exceptab    = exceptab
                                                    params      = params
                                                    show_impp   = show_imports
                                                    lowercase   = lowercase
                                                    funcname    = funcname
                                          IMPORTING perl_string = output ).

    ENDCASE.

    output_type = SWITCH #( format
                            WHEN `JSON` OR `JSON_ID` THEN `json`
                            WHEN `XML` OR `XML_ID`   THEN `xml`
                            WHEN `YAML`              THEN `yaml`
                            ELSE `perl` ).
    IF output_type = `json` AND pretty = abap_true.
      output = json_pretty( output ).
    ENDIF.

    DATA(query) = |format={ to_lower( substring_before( val = |{ format }_| sub = `_` ) ) }| &&
                  |{ COND string( WHEN upcase = abap_true THEN `&upcase=X` ) }| &&
                  |{ COND string( WHEN camelcase = abap_true THEN `&camelcase=X` ) }| &&
                  |{ COND string( WHEN show_imports = abap_true THEN `&show_import_params=X` ) }|.
    http_call = |The same call over HTTP: POST <ICF node of ZCL_JSON_HANDLER>/{ to_lower( function ) }?{ query } | &&
                |with the input as body - result, { strlen( output ) } characters:|.

  ENDMETHOD.


  METHOD status_set.

    status_type = type.
    status_text = text.

  ENDMETHOD.


  METHOD model_init.

    " harmless, read-only standard function modules that every system has
    whitelist = VALUE #(
        ( name    = `STFC_CONNECTION`
          text    = `STFC_CONNECTION - echo a text (RFC connection test)`
          example = |\{\n  "requtext": "Hello from abap2UI5"\n\}| )
        ( name    = `STFC_STRUCTURE`
          text    = `STFC_STRUCTURE - echo a structure and a table (RFC test)`
          example = |\{\n  "importstruct": \{\n    "rfcfloat": 3.14,\n    "rfcchar1": "A",\n| &&
                    |    "rfcint4": 4711,\n    "rfcchar4": "ABAP",\n    "rfcdate": "2026-09-29",\n| &&
                    |    "rfcdata1": "a structure in JSON"\n  \},\n  "rfctable": [\n| &&
                    |    \{ "rfcchar4": "ROW1", "rfcint4": 1 \},\n| &&
                    |    \{ "rfcchar4": "ROW2", "rfcint4": 2 \}\n  ]\n\}| )
        ( name    = `RFC_SYSTEM_INFO`
          text    = `RFC_SYSTEM_INFO - release, host and code page of this system`
          example = `{}` )
        ( name    = `DATE_GET_WEEK`
          text    = `DATE_GET_WEEK - calendar week of a date (raises DATE_INVALID)`
          example = |\{\n  "date": "2026-09-29"\n\}| ) ).
    t_functions = VALUE #( FOR f IN whitelist ( key = f-name text = f-text ) ).

    t_formats = VALUE #( ( key = `JSON`    text = `JSON - serialize_json` )
                         ( key = `JSON_ID` text = `JSON - serialize_id` )
                         ( key = `XML`     text = `XML - serialize_xml` )
                         ( key = `XML_ID`  text = `XML - serialize_id` )
                         ( key = `YAML`    text = `YAML - serialize_yaml` )
                         ( key = `PERL`    text = `Perl - serialize_perl` ) ).

    function     = `STFC_CONNECTION`.
    deserializer = `ID`.
    format       = `JSON`.
    pretty       = abap_true.
    output_type  = `json`.
    function_select( ).

  ENDMETHOD.


  METHOD json_pretty.

    " display only: indents the one-line JSON of the serializers, strings
    " are copied as they are
    DATA(in_string) = abap_false.
    DATA(escaped)   = abap_false.
    DATA(depth)     = 0.
    DATA(length)    = strlen( json ).
    DATA(ix)        = 0.

    WHILE ix < length.
      DATA(char) = substring( val = json off = ix len = 1 ).
      DATA(next) = COND string( WHEN ix + 1 < length THEN substring( val = json off = ix + 1 len = 1 ) ).
      ix = ix + 1.

      IF in_string = abap_true.
        result = result && char.
        IF escaped = abap_true.
          escaped = abap_false.
        ELSEIF char = `\`.
          escaped = abap_true.
        ELSEIF char = `"`.
          in_string = abap_false.
        ENDIF.
        CONTINUE.
      ENDIF.

      CASE char.
        WHEN `"`.
          in_string = abap_true.
          result = result && char.
        WHEN `{` OR `[`.
          IF next = `}` OR next = `]`.
            result = result && char && next.
            ix = ix + 1.
          ELSE.
            depth = depth + 1.
            result = |{ result }{ char }\n{ repeat( val = `  ` occ = depth ) }|.
          ENDIF.
        WHEN `}` OR `]`.
          depth = nmax( val1 = 0 val2 = depth - 1 ).
          result = |{ result }\n{ repeat( val = `  ` occ = depth ) }{ char }|.
        WHEN `,`.
          result = |{ result },\n{ repeat( val = `  ` occ = depth ) }|.
        WHEN `:`.
          result = |{ result }: |.
        WHEN ` ` OR |\n| OR |\r| OR |\t|.
        WHEN OTHERS.
          result = result && char.
      ENDCASE.
    ENDWHILE.

  ENDMETHOD.

ENDCLASS.
