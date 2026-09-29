"! <p class="shorttext">abap-data-validator with abap2UI5</p>
"!
"! Rule-based validation of an internal table with
"! https://github.com/hhelibeb/abap-data-validator: edit the demo contacts,
"! choose per column which rule applies (required, must be empty, one of the
"! library's types, a custom regex, a reference data element) and press
"! Validate. zcl_adata_validator->validate( ) checks the whole table in ABAP;
"! every invalid cell turns red with the library's message - the frontend
"! only draws the bound tables. The regex a user types into a rule is itself
"! checked with zcl_adv_regex_check before it is used.
"!
"! Safe defaults: the validator is created with an explicit check
"! configuration WITHOUT the experimental HTML type - zcl_adv_html_check posts
"! the value to validator.w3.org, so no cell content ever leaves the system.
"! A reference data element is only described with RTTI (read-only); nothing
"! is read from or written to the database.
CLASS z2ui5_cl_osl_validator DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_key_text,
        key  TYPE string,
        text TYPE string,
      END OF ty_s_key_text.
    TYPES ty_t_key_text TYPE STANDARD TABLE OF ty_s_key_text WITH EMPTY KEY.

    " one demo contact - every value is a string, as it comes from an upload;
    " <field>_ST / <field>_TX are the value state and its text per cell
    TYPES:
      BEGIN OF ty_s_row,
        row           TYPE i,
        name          TYPE string,
        name_st       TYPE string,
        name_tx       TYPE string,
        email         TYPE string,
        email_st      TYPE string,
        email_tx      TYPE string,
        birth_date    TYPE string,
        birth_date_st TYPE string,
        birth_date_tx TYPE string,
        call_time     TYPE string,
        call_time_st  TYPE string,
        call_time_tx  TYPE string,
        changed_at    TYPE string,
        changed_at_st TYPE string,
        changed_at_tx TYPE string,
        website       TYPE string,
        website_st    TYPE string,
        website_tx    TYPE string,
        phone         TYPE string,
        phone_st      TYPE string,
        phone_tx      TYPE string,
        imei          TYPE string,
        imei_st       TYPE string,
        imei_tx       TYPE string,
        order_id      TYPE string,
        order_id_st   TYPE string,
        order_id_tx   TYPE string,
        quantity      TYPE string,
        quantity_st   TYPE string,
        quantity_tx   TYPE string,
        settings      TYPE string,
        settings_st   TYPE string,
        settings_tx   TYPE string,
      END OF ty_s_row.
    TYPES ty_t_row TYPE STANDARD TABLE OF ty_s_row WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_rule,
        fname            TYPE string,
        label            TYPE string,
        required         TYPE abap_bool,
        initial_or_empty TYPE abap_bool,
        user_type        TYPE string,
        regex            TYPE string,
        regex_msg        TYPE string,
        ref_element      TYPE string,
        regex_st         TYPE string,
        regex_tx         TYPE string,
      END OF ty_s_rule.
    TYPES ty_t_rule TYPE STANDARD TABLE OF ty_s_rule WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_result,
        row     TYPE i,
        field   TYPE string,
        type    TYPE string,
        message TYPE string,
      END OF ty_s_result.
    TYPES ty_t_result TYPE STANDARD TABLE OF ty_s_result WITH EMPTY KEY.

    DATA t_rows       TYPE ty_t_row.
    DATA t_rules      TYPE ty_t_rule.
    DATA t_types      TYPE ty_t_key_text.
    DATA t_results    TYPE ty_t_result.
    DATA summary      TYPE string.
    DATA summary_type TYPE string.

  PROTECTED SECTION.
    DATA client  TYPE REF TO z2ui5_if_client.
    " the validated fields - the names of the data columns of ty_s_row
    DATA columns TYPE string_table.

    METHODS view_display.
    METHODS view_data
      IMPORTING
        content TYPE REF TO z2ui5_cl_ui5_view_builder.
    METHODS view_rules
      IMPORTING
        content TYPE REF TO z2ui5_cl_ui5_view_builder.
    METHODS view_results
      IMPORTING
        content TYPE REF TO z2ui5_cl_ui5_view_builder.

    METHODS on_event.
    METHODS model_init.
    METHODS rows_init.
    METHODS rules_init.
    METHODS states_reset.
    METHODS validate
      RAISING
        zcx_adv_exception.
    METHODS rules_regex_valid
      RETURNING
        VALUE(result) TYPE abap_bool.

    CLASS-METHODS check_config
      RETURNING
        VALUE(result) TYPE zcl_adata_validator=>ty_check_config_t.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_osl_validator IMPLEMENTATION.

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
            )->ele( `Shell`
                )->a( n = `appWidthLimited` v = `false`
                )->ele( `Page`
                    )->a( n = `title`          v = `Data validation with ABAP - abap-data-validator x abap2UI5`
                    )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
                    )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    page->ele( `headerContent`
        )->tag( `Button`
            )->a( n = `text`  v = `Reset demo data`
            )->a( n = `icon`  v = `sap-icon://reset`
            )->a( n = `type`  v = `Transparent`
            )->a( n = `press` v = client->_event( `RESET` )
        )->tag( `Link`
            )->a( n = `text`   v = `hhelibeb/abap-data-validator`
            )->a( n = `href`   v = `https://github.com/hhelibeb/abap-data-validator`
            )->a( n = `target` v = `_blank` ).

    DATA(content) = page->ele( `content` ).

    content->tag( `MessageStrip`
        )->a( n = `text`     v = client->_bind( summary )
        )->a( n = `type`     v = client->_bind( summary_type )
        )->a( n = `showIcon` v = `true`
        )->a( n = `class`    v = `sapUiSmallMargin` ).

    view_data( content ).
    view_rules( content ).
    view_results( content ).

    page->ele( `footer`
        )->ele( `OverflowToolbar`
            )->tag( `ToolbarSpacer`
            )->tag( `Button`
                )->a( n = `text`  v = `Validate`
                )->a( n = `icon`  v = `sap-icon://validate`
                )->a( n = `type`  v = `Emphasized`
                )->a( n = `press` v = client->_event( `VALIDATE` ) ).

    client->view_display( page->stringify( ) ).

  ENDMETHOD.


  METHOD view_data.

    DATA(table) = content->ele( `Panel`
        )->a( n = `headerText` v = `Data - edit any cell, then press Validate`
        )->ele( `ScrollContainer`
            )->a( n = `horizontal` v = `true`
            )->a( n = `vertical`   v = `false`
            )->a( n = `width`      v = `100%`
            )->ele( `Table`
                )->a( n = `items` v = client->_bind( val                = t_rows
                                                     omit_initial_paths = VALUE #( ( `NAME_ST` )
                                                                                   ( `EMAIL_ST` )
                                                                                   ( `BIRTH_DATE_ST` )
                                                                                   ( `CALL_TIME_ST` )
                                                                                   ( `CHANGED_AT_ST` )
                                                                                   ( `WEBSITE_ST` )
                                                                                   ( `PHONE_ST` )
                                                                                   ( `IMEI_ST` )
                                                                                   ( `ORDER_ID_ST` )
                                                                                   ( `QUANTITY_ST` )
                                                                                   ( `SETTINGS_ST` ) ) )
                )->a( n = `width` v = `130rem` ).

    table->ele( `columns`
        )->ele( `Column`
            )->a( n = `width` v = `3rem`
            )->tag( `Text`
                )->a( n = `text` v = `#`
        )->end(
        )->ele( `Column`
            )->a( n = `width` v = `10rem`
            )->tag( `Text`
                )->a( n = `text` v = `Name`
        )->end(
        )->ele( `Column`
            )->a( n = `width` v = `14rem`
            )->tag( `Text`
                )->a( n = `text` v = `E-mail`
        )->end(
        )->ele( `Column`
            )->a( n = `width` v = `8rem`
            )->tag( `Text`
                )->a( n = `text` v = `Birth date`
        )->end(
        )->ele( `Column`
            )->a( n = `width` v = `7rem`
            )->tag( `Text`
                )->a( n = `text` v = `Call time`
        )->end(
        )->ele( `Column`
            )->a( n = `width` v = `11rem`
            )->tag( `Text`
                )->a( n = `text` v = `Changed at`
        )->end(
        )->ele( `Column`
            )->a( n = `width` v = `14rem`
            )->tag( `Text`
                )->a( n = `text` v = `Website`
        )->end(
        )->ele( `Column`
            )->a( n = `width` v = `10rem`
            )->tag( `Text`
                )->a( n = `text` v = `Phone`
        )->end(
        )->ele( `Column`
            )->a( n = `width` v = `11rem`
            )->tag( `Text`
                )->a( n = `text` v = `Device IMEI`
        )->end(
        )->ele( `Column`
            )->a( n = `width` v = `18rem`
            )->tag( `Text`
                )->a( n = `text` v = `Order GUID`
        )->end(
        )->ele( `Column`
            )->a( n = `width` v = `8rem`
            )->tag( `Text`
                )->a( n = `text` v = `Quantity`
        )->end(
        )->ele( `Column`
            )->a( n = `width` v = `12rem`
            )->tag( `Text`
                )->a( n = `text` v = `Settings (JSON)` ).

    table->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells`
                )->tag( `Text`
                    )->a( n = `text` v = `{ROW}`
                )->tag( `Input`
                    )->a( n = `value`          v = `{NAME}`
                    )->a( n = `valueState`     v = `{NAME_ST}`
                    )->a( n = `valueStateText` v = `{NAME_TX}`
                )->tag( `Input`
                    )->a( n = `value`          v = `{EMAIL}`
                    )->a( n = `valueState`     v = `{EMAIL_ST}`
                    )->a( n = `valueStateText` v = `{EMAIL_TX}`
                )->tag( `Input`
                    )->a( n = `value`          v = `{BIRTH_DATE}`
                    )->a( n = `valueState`     v = `{BIRTH_DATE_ST}`
                    )->a( n = `valueStateText` v = `{BIRTH_DATE_TX}`
                )->tag( `Input`
                    )->a( n = `value`          v = `{CALL_TIME}`
                    )->a( n = `valueState`     v = `{CALL_TIME_ST}`
                    )->a( n = `valueStateText` v = `{CALL_TIME_TX}`
                )->tag( `Input`
                    )->a( n = `value`          v = `{CHANGED_AT}`
                    )->a( n = `valueState`     v = `{CHANGED_AT_ST}`
                    )->a( n = `valueStateText` v = `{CHANGED_AT_TX}`
                )->tag( `Input`
                    )->a( n = `value`          v = `{WEBSITE}`
                    )->a( n = `valueState`     v = `{WEBSITE_ST}`
                    )->a( n = `valueStateText` v = `{WEBSITE_TX}`
                )->tag( `Input`
                    )->a( n = `value`          v = `{PHONE}`
                    )->a( n = `valueState`     v = `{PHONE_ST}`
                    )->a( n = `valueStateText` v = `{PHONE_TX}`
                )->tag( `Input`
                    )->a( n = `value`          v = `{IMEI}`
                    )->a( n = `valueState`     v = `{IMEI_ST}`
                    )->a( n = `valueStateText` v = `{IMEI_TX}`
                )->tag( `Input`
                    )->a( n = `value`          v = `{ORDER_ID}`
                    )->a( n = `valueState`     v = `{ORDER_ID_ST}`
                    )->a( n = `valueStateText` v = `{ORDER_ID_TX}`
                )->tag( `Input`
                    )->a( n = `value`          v = `{QUANTITY}`
                    )->a( n = `valueState`     v = `{QUANTITY_ST}`
                    )->a( n = `valueStateText` v = `{QUANTITY_TX}`
                )->tag( `Input`
                    )->a( n = `value`          v = `{SETTINGS}`
                    )->a( n = `valueState`     v = `{SETTINGS_ST}`
                    )->a( n = `valueStateText` v = `{SETTINGS_TX}` ).

  ENDMETHOD.


  METHOD view_rules.

    DATA(table) = content->ele( `Panel`
        )->a( n = `headerText` v = `Rules - one per column, all checks run in zcl_adata_validator`
        )->ele( `Table`
            )->a( n = `items` v = client->_bind( t_rules ) ).

    table->ele( `columns`
        )->ele( `Column`
            )->a( n = `width` v = `10rem`
            )->tag( `Text`
                )->a( n = `text` v = `Column`
        )->end(
        )->ele( `Column`
            )->a( n = `width` v = `6rem`
            )->tag( `Text`
                )->a( n = `text` v = `Required`
        )->end(
        )->ele( `Column`
            )->a( n = `width` v = `6rem`
            )->tag( `Text`
                )->a( n = `text` v = `Must be empty`
        )->end(
        )->ele( `Column`
            )->a( n = `width` v = `16rem`
            )->tag( `Text`
                )->a( n = `text` v = `Type check`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Custom regex`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Regex message`
        )->end(
        )->ele( `Column`
            )->a( n = `width` v = `12rem`
            )->tag( `Text`
                )->a( n = `text` v = `Reference data element` ).

    table->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells`
                )->tag( `ObjectIdentifier`
                    )->a( n = `title` v = `{LABEL}`
                    )->a( n = `text`  v = `{FNAME}`
                )->tag( `CheckBox`
                    )->a( n = `selected` v = `{REQUIRED}`
                )->tag( `CheckBox`
                    )->a( n = `selected` v = `{INITIAL_OR_EMPTY}`
                )->ele( `Select`
                    )->a( n = `selectedKey` v = `{USER_TYPE}`
                    )->a( n = `items`       v = client->_bind( t_types )
                    )->a( n = `width`       v = `100%`
                    )->tag( n = `Item` ns = `core`
                        )->a( n = `key`  v = `{KEY}`
                        )->a( n = `text` v = `{TEXT}`
                )->end(
                )->tag( `Input`
                    )->a( n = `value`          v = `{REGEX}`
                    )->a( n = `valueState`     v = `{REGEX_ST}`
                    )->a( n = `valueStateText` v = `{REGEX_TX}`
                    )->a( n = `placeholder`    v = `e.g. \.com$`
                )->tag( `Input`
                    )->a( n = `value` v = `{REGEX_MSG}`
                )->tag( `Input`
                    )->a( n = `value`       v = `{REF_ELEMENT}`
                    )->a( n = `placeholder` v = `e.g. MENGE_D` ).

  ENDMETHOD.


  METHOD view_results.

    DATA(table) = content->ele( `Panel`
        )->a( n = `headerText` v = `Result of validate( ) - one line per invalid cell`
        )->ele( `Table`
            )->a( n = `items`            v = client->_bind( t_results )
            )->a( n = `noDataText`       v = `No errors - press Validate`
            )->a( n = `growing`          v = `true`
            )->a( n = `growingThreshold` v = `50` ).

    table->ele( `columns`
        )->ele( `Column`
            )->a( n = `width` v = `4rem`
            )->tag( `Text`
                )->a( n = `text` v = `Row`
        )->end(
        )->ele( `Column`
            )->a( n = `width` v = `10rem`
            )->tag( `Text`
                )->a( n = `text` v = `Field`
        )->end(
        )->ele( `Column`
            )->a( n = `width` v = `10rem`
            )->tag( `Text`
                )->a( n = `text` v = `Type`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Message` ).

    table->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells`
                )->tag( `Text`
                    )->a( n = `text` v = `{ROW}`
                )->tag( `Text`
                    )->a( n = `text` v = `{FIELD}`
                )->tag( `Text`
                    )->a( n = `text` v = `{TYPE}`
                )->tag( `ObjectStatus`
                    )->a( n = `text`  v = `{MESSAGE}`
                    )->a( n = `state` v = `Error` ).

  ENDMETHOD.


  METHOD on_event.

    " validate( ) raises zcx_adv_exception (a table that is not flat, a check
    " class that cannot be called) - shown, not dumped
    TRY.
        CASE client->get_event( ).

          WHEN `VALIDATE`.
            validate( ).

          WHEN `RESET`.
            rows_init( ).
            rules_init( ).
            states_reset( ).
            CLEAR t_results.
            summary      = `Demo data and rules reset - press Validate.`.
            summary_type = `Information`.

        ENDCASE.
      CATCH zcx_adv_exception INTO DATA(error).
        client->message_box_display( error ).
    ENDTRY.

  ENDMETHOD.


  METHOD validate.

    states_reset( ).
    CLEAR t_results.

    " trim every cell - blanks around a value are no content error, and
    " a blank-only value would reach the INT4 check as non-initial
    LOOP AT t_rows ASSIGNING FIELD-SYMBOL(<row>).
      LOOP AT columns INTO DATA(column).
        ASSIGN COMPONENT column OF STRUCTURE <row> TO FIELD-SYMBOL(<value>).
        <value> = shift_left( val = shift_right( val = CONV string( <value> ) ) ).
      ENDLOOP.
    ENDLOOP.

    " a custom regex goes into contains( regex = ) inside the library -
    " check it with the library's own REGEX type first
    IF rules_regex_valid( ) = abap_false.
      summary      = `A custom regex is not a valid regular expression - fix the rule marked red.`.
      summary_type = `Error`.
      RETURN.
    ENDIF.

    DATA(rules) = VALUE zcl_adata_validator=>ty_rules_t( FOR r IN t_rules
        ( fname            = to_upper( r-fname )
          required         = r-required
          initial_or_empty = r-initial_or_empty
          user_type        = r-user_type
          regex            = r-regex
          regex_msg        = r-regex_msg
          ref_element      = to_upper( r-ref_element ) ) ).

    DATA(results) = NEW zcl_adata_validator( check_class_conifg = check_config( )
        )->validate( rules = rules
                     data  = t_rows ).

    DATA error_rows TYPE SORTED TABLE OF i WITH UNIQUE KEY table_line.
    LOOP AT results INTO DATA(result).
      INSERT result-row INTO TABLE error_rows.
      DATA(message) = condense( concat_lines_of( table = VALUE string_table( FOR m IN result-message ( m-text ) )
                                                 sep   = ` ` ) ).
      ASSIGN t_rows[ result-row ] TO <row>.
      IF sy-subrc = 0.
        ASSIGN COMPONENT |{ result-fname }_ST| OF STRUCTURE <row> TO FIELD-SYMBOL(<state>).
        IF sy-subrc = 0.
          <state> = `Error`.
        ENDIF.
        ASSIGN COMPONENT |{ result-fname }_TX| OF STRUCTURE <row> TO FIELD-SYMBOL(<text>).
        IF sy-subrc = 0.
          <text> = message.
        ENDIF.
      ENDIF.
      INSERT VALUE #( row     = result-row
                      field   = result-fname
                      type    = COND #( WHEN result-type IS INITIAL THEN `required / empty / regex`
                                        ELSE result-type )
                      message = message ) INTO TABLE t_results.
    ENDLOOP.

    IF results IS INITIAL.
      summary      = |All { lines( t_rows ) } rows are valid - { lines( t_rules ) } rules checked.|.
      summary_type = `Success`.
    ELSE.
      summary      = |{ lines( t_rows ) } rows checked: { lines( results ) } invalid cells in |
                  && |{ lines( error_rows ) } rows.|.
      summary_type = `Error`.
    ENDIF.

  ENDMETHOD.


  METHOD rules_regex_valid.

    result = abap_true.
    LOOP AT t_rules ASSIGNING FIELD-SYMBOL(<rule>) WHERE regex IS NOT INITIAL.
      IF zcl_adv_regex_check=>is_valid( <rule>-regex ) = abap_false.
        <rule>-regex_st = `Error`.
        <rule>-regex_tx = `Not a valid regular expression (zcl_adv_regex_check).`.
        result = abap_false.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD states_reset.

    LOOP AT t_rows ASSIGNING FIELD-SYMBOL(<row>).
      LOOP AT columns INTO DATA(column).
        ASSIGN COMPONENT |{ column }_ST| OF STRUCTURE <row> TO FIELD-SYMBOL(<state>).
        <state> = `None`.
        ASSIGN COMPONENT |{ column }_TX| OF STRUCTURE <row> TO FIELD-SYMBOL(<text>).
        CLEAR <text>.
      ENDLOOP.
    ENDLOOP.

    LOOP AT t_rules ASSIGNING FIELD-SYMBOL(<rule>).
      <rule>-regex_st = `None`.
      CLEAR <rule>-regex_tx.
    ENDLOOP.

  ENDMETHOD.


  METHOD check_config.

    " the library's default configuration minus HTML, whose check class
    " sends the value to validator.w3.org
    result = VALUE #(
        ( type    = zcl_adata_validator=>c_type_date
          class   = `ZCL_ADV_DATE_CHECK`
          message = `Invalid value for field "&1". Date format should be YYYYMMDD.` )
        ( type = zcl_adata_validator=>c_type_email     class = `ZCL_ADV_EMAIL_CHECK` )
        ( type = zcl_adata_validator=>c_type_time      class = `ZCL_ADV_TIME_CHECK` )
        ( type = zcl_adata_validator=>c_type_int4      class = `ZCL_ADV_INT4_CHECK` )
        ( type = zcl_adata_validator=>c_type_regex     class = `ZCL_ADV_REGEX_CHECK` )
        ( type = zcl_adata_validator=>c_type_timestamp class = `ZCL_ADV_TIMESTAMP_CHECK` )
        ( type = zcl_adata_validator=>c_type_url       class = `ZCL_ADV_URL_CHECK` )
        ( type = zcl_adata_validator=>c_type_hex       class = `ZCL_ADV_HEX_CHECK` )
        ( type = zcl_adata_validator=>c_type_json      class = `ZCL_ADV_JSON_CHECK` )
        ( type = zcl_adata_validator=>c_type_imei      class = `ZCL_ADV_IMEI_CHECK` )
        ( type = zcl_adata_validator=>c_type_guid      class = `ZCL_ADV_GUID_CHECK` )
        ( type = zcl_adata_validator=>c_type_base64    class = `ZCL_ADV_BASE64_CHECK` ) ).

  ENDMETHOD.


  METHOD model_init.

    columns = VALUE #( ( `NAME` )
                       ( `EMAIL` )
                       ( `BIRTH_DATE` )
                       ( `CALL_TIME` )
                       ( `CHANGED_AT` )
                       ( `WEBSITE` )
                       ( `PHONE` )
                       ( `IMEI` )
                       ( `ORDER_ID` )
                       ( `QUANTITY` )
                       ( `SETTINGS` ) ).

    t_types = VALUE #(
        ( key = ``                                     text = `(no type check)` )
        ( key = zcl_adata_validator=>c_type_date      text = `Date - YYYYMMDD` )
        ( key = zcl_adata_validator=>c_type_time      text = `Time - HHMMSS` )
        ( key = zcl_adata_validator=>c_type_timestamp text = `Timestamp - YYYYMMDDhhmmss` )
        ( key = zcl_adata_validator=>c_type_email     text = `E-mail` )
        ( key = zcl_adata_validator=>c_type_url       text = `URL` )
        ( key = zcl_adata_validator=>c_type_int4      text = `Integer - INT4 range` )
        ( key = zcl_adata_validator=>c_type_json      text = `JSON` )
        ( key = zcl_adata_validator=>c_type_imei      text = `IMEI - 15 digits, Luhn` )
        ( key = zcl_adata_validator=>c_type_guid      text = `GUID - 32 hex digits` )
        ( key = zcl_adata_validator=>c_type_hex       text = `Hex` )
        ( key = zcl_adata_validator=>c_type_base64    text = `Base64` )
        ( key = zcl_adata_validator=>c_type_regex     text = `Regex - value is a pattern` ) ).

    rows_init( ).
    rules_init( ).
    states_reset( ).
    summary      = `Some demo values are invalid on purpose - press Validate.`.
    summary_type = `Information`.

  ENDMETHOD.


  METHOD rows_init.

    t_rows = VALUE #(
        ( row        = 1
          name       = `Ada Lovelace`
          email      = `ada@example.com`
          birth_date = `18151210`
          call_time  = `093000`
          changed_at = `20240115083000`
          website    = `https://www.example.com`
          phone      = `+44 20 7946 0958`
          imei       = `490154203237518`
          order_id   = `0A1B2C3D4E5F4A6B8C7D0E1F2A3B4C5D`
          quantity   = `42`
          settings   = `{"theme":"dark"}` )
        ( row        = 2
          name       = `Grace Hopper`
          email      = `grace.hopper@@navy.mil`
          birth_date = `19061209`
          call_time  = `250000`
          changed_at = `20240229235959`
          website    = `htp:/navy.mil`
          phone      = `+1 202 555 0143`
          imei       = `490154203237519`
          order_id   = `0a1b2c3d4e5f4a6b8c7d0e1f2a3b4c5d`
          quantity   = `3000000000`
          settings   = `{theme: dark` )
        ( row        = 3
          name       = `Alan Turing`
          email      = `alan.turing@example.org`
          birth_date = `19120230`
          call_time  = `120000`
          changed_at = `20241301000000`
          website    = `https://turing.example.org/papers`
          phone      = `call me`
          imei       = `35-209900-176148-1`
          order_id   = `3F2504E04F8941D3AA0C0305E82C3301`
          quantity   = `-17`
          settings   = `[1,2,3]` )
        ( row        = 4
          email      = `katherine.johnson@nasa.gov`
          birth_date = `19180826`
          call_time  = `083015`
          changed_at = `20230704120000`
          website    = `ftp://files.example.com/data`
          phone      = `+1 757 864 1000`
          quantity   = `12a` )
        ( row        = 5
          name       = `Edsger Dijkstra`
          email      = `edsger at example.nl`
          birth_date = `1930-05-11`
          call_time  = `23:59:59`
          changed_at = `20220806101500`
          website    = `www.example.nl`
          phone      = `+31 20 555 0199`
          imei       = `356938035643809`
          order_id   = `3F2504E04F8941D3AA0C0305E82C3301`
          quantity   = `+2147483647`
          settings   = `{"weights":[1,2],"directed":true}` ) ).

  ENDMETHOD.


  METHOD rules_init.

    t_rules = VALUE #(
        ( fname = `NAME`       label = `Name`            required  = abap_true )
        ( fname = `EMAIL`      label = `E-mail`          user_type = zcl_adata_validator=>c_type_email )
        ( fname = `BIRTH_DATE` label = `Birth date`      user_type = zcl_adata_validator=>c_type_date )
        ( fname = `CALL_TIME`  label = `Call time`       user_type = zcl_adata_validator=>c_type_time )
        ( fname = `CHANGED_AT` label = `Changed at`      user_type = zcl_adata_validator=>c_type_timestamp )
        ( fname = `WEBSITE`    label = `Website`         user_type = zcl_adata_validator=>c_type_url )
        ( fname     = `PHONE`
          label     = `Phone`
          regex     = `^\+?[0-9 ]{6,20}$`
          regex_msg = `Phone: digits and blanks only, optionally a leading +.` )
        ( fname = `IMEI`       label = `Device IMEI`     user_type = zcl_adata_validator=>c_type_imei )
        ( fname = `ORDER_ID`   label = `Order GUID`      user_type = zcl_adata_validator=>c_type_guid )
        ( fname = `QUANTITY`   label = `Quantity`        user_type = zcl_adata_validator=>c_type_int4 )
        ( fname = `SETTINGS`   label = `Settings (JSON)` user_type = zcl_adata_validator=>c_type_json ) ).

  ENDMETHOD.

ENDCLASS.
