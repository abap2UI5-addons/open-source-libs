"! <p class="shorttext">abapFaker with abap2UI5</p>
"!
"! Test data generator on top of https://github.com/se38/abapFaker: choose a
"! locale (de_DE, en_US, pt_BR or the library's DEFAULT fallback), the number
"! of rows and which of the library's generators to include - persons,
"! addresses, companies, jobs, phone numbers and dates - and press Generate.
"! Every value is produced in ABAP by zcl_faker; the frontend only draws the
"! bound tables. The result can be regenerated and downloaded as CSV, and
"! every generator can be tried on its own in the catalog.
"!
"! Not every generator is filled for every locale (en_US has no short street
"! suffix, de_DE no city prefix or state, ...): the library then fails on an
"! empty word list. The app probes each generator once per locale and
"! disables the ones that fail, instead of dumping.
"!
"! Read-only: zcl_faker is always created with an explicit locale, and the
"! phone provider reads the short text of the data element AD_TLNMBR1 from
"! DD04T as its label. Nothing is written to the database.
CLASS z2ui5_cl_osl_faker DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_key_text,
        key  TYPE string,
        text TYPE string,
      END OF ty_s_key_text.
    TYPES ty_t_key_text TYPE STANDARD TABLE OF ty_s_key_text WITH EMPTY KEY.

    " one generator of the library - KEY is the component of ty_s_record
    " (and of ty_s_show) the generator fills
    TYPES:
      BEGIN OF ty_s_generator,
        key      TYPE string,
        grp      TYPE string,
        label    TYPE string,
        call     TYPE string,
        selected TYPE abap_bool,
        enabled  TYPE abap_bool,
        example  TYPE string,
      END OF ty_s_generator.
    TYPES ty_t_generator TYPE STANDARD TABLE OF ty_s_generator WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_record,
        nr                          TYPE i,
        address_street_address      TYPE string,
        address_street_name         TYPE string,
        address_building_number     TYPE string,
        address_street_suffix_long  TYPE string,
        address_street_suffix_short TYPE string,
        address_postcode            TYPE string,
        address_city                TYPE string,
        address_city_name           TYPE string,
        address_city_prefix         TYPE string,
        address_city_suffix         TYPE string,
        address_city_address        TYPE string,
        address_state_abbr          TYPE string,
        company_name                TYPE string,
        company_suffix              TYPE string,
        company_claim               TYPE string,
        company_catch_phrase_1      TYPE string,
        company_catch_phrase_2      TYPE string,
        company_catch_phrase_3      TYPE string,
        company_bs_1                TYPE string,
        company_bs_2                TYPE string,
        company_bs_3                TYPE string,
        date_of_birth               TYPE string,
        date_of_birth_adult         TYPE string,
        date_past                   TYPE string,
        date_future                 TYPE string,
        date_today                  TYPE string,
        date_tomorrow               TYPE string,
        date_yesterday              TYPE string,
        job_title                   TYPE string,
        person_name                 TYPE string,
        person_first_name           TYPE string,
        person_first_name_female    TYPE string,
        person_first_name_male      TYPE string,
        person_last_name            TYPE string,
        person_initial              TYPE string,
        phone_number                TYPE string,
        phone_label                 TYPE string,
      END OF ty_s_record.
    TYPES ty_t_record TYPE STANDARD TABLE OF ty_s_record WITH EMPTY KEY.

    " column visibility of the result table - same components as ty_s_record
    TYPES:
      BEGIN OF ty_s_show,
        address_street_address      TYPE abap_bool,
        address_street_name         TYPE abap_bool,
        address_building_number     TYPE abap_bool,
        address_street_suffix_long  TYPE abap_bool,
        address_street_suffix_short TYPE abap_bool,
        address_postcode            TYPE abap_bool,
        address_city                TYPE abap_bool,
        address_city_name           TYPE abap_bool,
        address_city_prefix         TYPE abap_bool,
        address_city_suffix         TYPE abap_bool,
        address_city_address        TYPE abap_bool,
        address_state_abbr          TYPE abap_bool,
        company_name                TYPE abap_bool,
        company_suffix              TYPE abap_bool,
        company_claim               TYPE abap_bool,
        company_catch_phrase_1      TYPE abap_bool,
        company_catch_phrase_2      TYPE abap_bool,
        company_catch_phrase_3      TYPE abap_bool,
        company_bs_1                TYPE abap_bool,
        company_bs_2                TYPE abap_bool,
        company_bs_3                TYPE abap_bool,
        date_of_birth               TYPE abap_bool,
        date_of_birth_adult         TYPE abap_bool,
        date_past                   TYPE abap_bool,
        date_future                 TYPE abap_bool,
        date_today                  TYPE abap_bool,
        date_tomorrow               TYPE abap_bool,
        date_yesterday              TYPE abap_bool,
        job_title                   TYPE abap_bool,
        person_name                 TYPE abap_bool,
        person_first_name           TYPE abap_bool,
        person_first_name_female    TYPE abap_bool,
        person_first_name_male      TYPE abap_bool,
        person_last_name            TYPE abap_bool,
        person_initial              TYPE abap_bool,
        phone_number                TYPE abap_bool,
        phone_label                 TYPE abap_bool,
      END OF ty_s_show.

    DATA tab          TYPE string.
    DATA locale       TYPE string.
    DATA t_locales    TYPE ty_t_key_text.
    DATA rows         TYPE i.
    DATA t_generators TYPE ty_t_generator.
    DATA selection    TYPE string.

    DATA t_records    TYPE ty_t_record.
    DATA show         TYPE ty_s_show.
    DATA has_records  TYPE abap_bool.
    DATA result_info  TYPE string.

  PROTECTED SECTION.
    CONSTANTS max_rows TYPE i VALUE 1000.

    DATA client TYPE REF TO z2ui5_if_client.

    METHODS view_display.
    METHODS view_generators
      IMPORTING
        items TYPE REF TO z2ui5_cl_ui5_view_builder.
    METHODS view_result
      IMPORTING
        items TYPE REF TO z2ui5_cl_ui5_view_builder.
    METHODS view_column
      IMPORTING
        columns TYPE REF TO z2ui5_cl_ui5_view_builder
        label   TYPE string
        cell    TYPE string
        visible TYPE string.

    METHODS on_event.
    METHODS generators_probe.
    METHODS generator_try
      IMPORTING
        key TYPE string.
    METHODS selection_set
      IMPORTING
        mode TYPE string.
    METHODS selection_update.
    METHODS records_generate.
    METHODS csv_download.
    METHODS model_init.

    "! one value of the generator KEY - the call into the library
    CLASS-METHODS fake
      IMPORTING
        faker         TYPE REF TO zcl_faker
        key           TYPE string
      RETURNING
        VALUE(result) TYPE string.
    CLASS-METHODS csv_value
      IMPORTING
        val           TYPE string
      RETURNING
        VALUE(result) TYPE string.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_osl_faker IMPLEMENTATION.

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
            )->a( n = `xmlns:t`      v = `sap.ui.table`
            )->ele( `Shell`
                )->a( n = `appWidthLimited` v = `false`
                )->ele( `Page`
                    )->a( n = `title`          v = `Test data generator - abapFaker x abap2UI5`
                    )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
                    )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    page->ele( `headerContent`
        )->tag( `Link`
            )->a( n = `text`   v = `se38/abapFaker`
            )->a( n = `href`   v = `https://github.com/se38/abapFaker`
            )->a( n = `target` v = `_blank` ).

    page->ele( `subHeader`
        )->ele( `OverflowToolbar`
            )->ele( `content`
                )->tag( `Label`
                    )->a( n = `text` v = `Locale`
                )->ele( `Select`
                    )->a( n = `selectedKey` v = client->_bind( locale )
                    )->a( n = `items`       v = client->_bind( t_locales )
                    )->a( n = `change`      v = client->_event( `LOCALE` )
                    )->tag( n = `Item` ns = `core`
                        )->a( n = `key`  v = `{KEY}`
                        )->a( n = `text` v = `{TEXT}`
                )->end(
                )->tag( `Label`
                    )->a( n = `text` v = `Rows`
                )->tag( `StepInput`
                    )->a( n = `value` v = client->_bind( rows )
                    )->a( n = `min`   v = `1`
                    )->a( n = `max`   v = `1000`
                    )->a( n = `step`  v = `10`
                    )->a( n = `width` v = `9rem`
                )->tag( `Button`
                    )->a( n = `text`  v = `Generate`
                    )->a( n = `icon`  v = `sap-icon://create`
                    )->a( n = `type`  v = `Emphasized`
                    )->a( n = `press` v = client->_event( `GENERATE` )
                )->tag( `ToolbarSpacer`
                )->tag( `Text`
                    )->a( n = `text` v = client->_bind( selection ) ).

    DATA(items) = page->ele( `content`
        )->ele( `IconTabBar`
            )->a( n = `selectedKey` v = client->_bind( tab )
            )->a( n = `expandable`  v = `false`
            )->a( n = `class`       v = `sapUiResponsiveContentPadding`
            )->ele( `items` ).

    view_generators( items ).
    view_result( items ).

    client->view_display( page->stringify( ) ).

  ENDMETHOD.


  METHOD view_generators.

    DATA(content) = items->ele( `IconTabFilter`
        )->a( n = `key`  v = `GENERATORS`
        )->a( n = `text` v = `Generators`
        )->a( n = `icon` v = `sap-icon://checklist`
        )->ele( `content` ).

    content->ele( `OverflowToolbar`
        )->a( n = `style` v = `Clear`
        )->ele( `content`
            )->tag( `Title`
                )->a( n = `text`  v = `Choose the columns - each example comes straight from the library`
                )->a( n = `level` v = `H4`
            )->tag( `ToolbarSpacer`
            )->tag( `Button`
                )->a( n = `text`  v = `All`
                )->a( n = `press` v = client->_event( `SELECT_ALL` )
            )->tag( `Button`
                )->a( n = `text`  v = `None`
                )->a( n = `press` v = client->_event( `SELECT_NONE` )
            )->tag( `Button`
                )->a( n = `text`  v = `Defaults`
                )->a( n = `press` v = client->_event( `SELECT_DEFAULTS` )
            )->tag( `Button`
                )->a( n = `text`  v = `New examples`
                )->a( n = `icon`  v = `sap-icon://refresh`
                )->a( n = `press` v = client->_event( `EXAMPLES` ) ).

    DATA(table) = content->ele( `Table`
        )->a( n = `items`  v = |\{ path: '{ client->_bind( val = t_generators path = abap_true ) }', | &&
                               |sorter: \{ path: 'GRP', group: true \} \}|
        )->a( n = `sticky` v = `ColumnHeaders` ).

    " header is the default aggregation of sap.m.Column
    table->ele( `columns`
        )->ele( `Column`
            )->a( n = `width` v = `5rem`
            )->tag( `Text`
                )->a( n = `text` v = `Include`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Generator`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Example`
        )->end(
        )->ele( `Column`
            )->a( n = `width` v = `5rem`
            )->tag( `Text`
                )->a( n = `text` v = `Try` ).

    table->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells`
                )->tag( `CheckBox`
                    )->a( n = `selected` v = `{SELECTED}`
                    )->a( n = `enabled`  v = `{ENABLED}`
                    )->a( n = `select`   v = client->_event( `SELECTION` )
                )->tag( `ObjectIdentifier`
                    )->a( n = `title` v = `{LABEL}`
                    )->a( n = `text`  v = `{CALL}`
                )->tag( `Text`
                    )->a( n = `text` v = `{EXAMPLE}`
                )->tag( `Button`
                    )->a( n = `icon`    v = `sap-icon://synchronize`
                    )->a( n = `type`    v = `Transparent`
                    )->a( n = `tooltip` v = `Call this generator once more`
                    )->a( n = `enabled` v = `{ENABLED}`
                    )->a( n = `press`   v = client->_event( val = `TRY` arg = `${KEY}` ) ).

  ENDMETHOD.


  METHOD view_result.

    DATA(content) = items->ele( `IconTabFilter`
        )->a( n = `key`  v = `RESULT`
        )->a( n = `text` v = `Result`
        )->a( n = `icon` v = `sap-icon://table-view`
        )->ele( `content` ).

    content->ele( `OverflowToolbar`
        )->a( n = `style` v = `Clear`
        )->ele( `content`
            )->tag( `Text`
                )->a( n = `text` v = client->_bind( result_info )
            )->tag( `ToolbarSpacer`
            )->tag( `Button`
                )->a( n = `text`    v = `Regenerate`
                )->a( n = `icon`    v = `sap-icon://refresh`
                )->a( n = `enabled` v = client->_bind( has_records )
                )->a( n = `press`   v = client->_event( `GENERATE` )
            )->tag( `Button`
                )->a( n = `text`    v = `Download CSV`
                )->a( n = `icon`    v = `sap-icon://download`
                )->a( n = `enabled` v = client->_bind( has_records )
                )->a( n = `press`   v = client->_event( `DOWNLOAD` ) ).

    DATA(columns) = content->ele( n = `Table` ns = `t`
        )->a( n = `rows`            v = client->_bind( t_records )
        )->a( n = `selectionMode`   v = `None`
        )->a( n = `visibleRowCount` v = `15`
        )->a( n = `noData`          v = `Choose the generators and press Generate`
        )->ele( n = `columns` ns = `t` ).

    columns->ele( n = `Column` ns = `t`
        )->a( n = `width` v = `4rem`
        )->ele( n = `label` ns = `t`
            )->tag( `Label`
                )->a( n = `text` v = `#`
        )->end(
        )->ele( n = `template` ns = `t`
            )->tag( `Text`
                )->a( n = `text` v = `{NR}` ).

    " one column per generator - hidden until the generator is part of a result
    view_column( columns = columns
                 label   = `Street address`
                 cell    = `{ADDRESS_STREET_ADDRESS}`
                 visible = client->_bind( show-address_street_address ) ).
    view_column( columns = columns
                 label   = `Street name`
                 cell    = `{ADDRESS_STREET_NAME}`
                 visible = client->_bind( show-address_street_name ) ).
    view_column( columns = columns
                 label   = `Building number`
                 cell    = `{ADDRESS_BUILDING_NUMBER}`
                 visible = client->_bind( show-address_building_number ) ).
    view_column( columns = columns
                 label   = `Street suffix`
                 cell    = `{ADDRESS_STREET_SUFFIX_LONG}`
                 visible = client->_bind( show-address_street_suffix_long ) ).
    view_column( columns = columns
                 label   = `Street suffix, short`
                 cell    = `{ADDRESS_STREET_SUFFIX_SHORT}`
                 visible = client->_bind( show-address_street_suffix_short ) ).
    view_column( columns = columns
                 label   = `Postcode`
                 cell    = `{ADDRESS_POSTCODE}`
                 visible = client->_bind( show-address_postcode ) ).
    view_column( columns = columns
                 label   = `City`
                 cell    = `{ADDRESS_CITY}`
                 visible = client->_bind( show-address_city ) ).
    view_column( columns = columns
                 label   = `City name`
                 cell    = `{ADDRESS_CITY_NAME}`
                 visible = client->_bind( show-address_city_name ) ).
    view_column( columns = columns
                 label   = `City prefix`
                 cell    = `{ADDRESS_CITY_PREFIX}`
                 visible = client->_bind( show-address_city_prefix ) ).
    view_column( columns = columns
                 label   = `City suffix`
                 cell    = `{ADDRESS_CITY_SUFFIX}`
                 visible = client->_bind( show-address_city_suffix ) ).
    view_column( columns = columns
                 label   = `Postcode and city`
                 cell    = `{ADDRESS_CITY_ADDRESS}`
                 visible = client->_bind( show-address_city_address ) ).
    view_column( columns = columns
                 label   = `State`
                 cell    = `{ADDRESS_STATE_ABBR}`
                 visible = client->_bind( show-address_state_abbr ) ).
    view_column( columns = columns
                 label   = `Company`
                 cell    = `{COMPANY_NAME}`
                 visible = client->_bind( show-company_name ) ).
    view_column( columns = columns
                 label   = `Legal form`
                 cell    = `{COMPANY_SUFFIX}`
                 visible = client->_bind( show-company_suffix ) ).
    view_column( columns = columns
                 label   = `Claim`
                 cell    = `{COMPANY_CLAIM}`
                 visible = client->_bind( show-company_claim ) ).
    view_column( columns = columns
                 label   = `Catch phrase word 1`
                 cell    = `{COMPANY_CATCH_PHRASE_1}`
                 visible = client->_bind( show-company_catch_phrase_1 ) ).
    view_column( columns = columns
                 label   = `Catch phrase word 2`
                 cell    = `{COMPANY_CATCH_PHRASE_2}`
                 visible = client->_bind( show-company_catch_phrase_2 ) ).
    view_column( columns = columns
                 label   = `Catch phrase word 3`
                 cell    = `{COMPANY_CATCH_PHRASE_3}`
                 visible = client->_bind( show-company_catch_phrase_3 ) ).
    view_column( columns = columns
                 label   = `Buzzword 1`
                 cell    = `{COMPANY_BS_1}`
                 visible = client->_bind( show-company_bs_1 ) ).
    view_column( columns = columns
                 label   = `Buzzword 2`
                 cell    = `{COMPANY_BS_2}`
                 visible = client->_bind( show-company_bs_2 ) ).
    view_column( columns = columns
                 label   = `Buzzword 3`
                 cell    = `{COMPANY_BS_3}`
                 visible = client->_bind( show-company_bs_3 ) ).
    view_column( columns = columns
                 label   = `Date of birth`
                 cell    = `{DATE_OF_BIRTH}`
                 visible = client->_bind( show-date_of_birth ) ).
    view_column( columns = columns
                 label   = `Date of birth, 18+`
                 cell    = `{DATE_OF_BIRTH_ADULT}`
                 visible = client->_bind( show-date_of_birth_adult ) ).
    view_column( columns = columns
                 label   = `Date, past 10 years`
                 cell    = `{DATE_PAST}`
                 visible = client->_bind( show-date_past ) ).
    view_column( columns = columns
                 label   = `Date, next 5 years`
                 cell    = `{DATE_FUTURE}`
                 visible = client->_bind( show-date_future ) ).
    view_column( columns = columns
                 label   = `Today`
                 cell    = `{DATE_TODAY}`
                 visible = client->_bind( show-date_today ) ).
    view_column( columns = columns
                 label   = `Tomorrow`
                 cell    = `{DATE_TOMORROW}`
                 visible = client->_bind( show-date_tomorrow ) ).
    view_column( columns = columns
                 label   = `Yesterday`
                 cell    = `{DATE_YESTERDAY}`
                 visible = client->_bind( show-date_yesterday ) ).
    view_column( columns = columns
                 label   = `Job title`
                 cell    = `{JOB_TITLE}`
                 visible = client->_bind( show-job_title ) ).
    view_column( columns = columns
                 label   = `Name`
                 cell    = `{PERSON_NAME}`
                 visible = client->_bind( show-person_name ) ).
    view_column( columns = columns
                 label   = `First name`
                 cell    = `{PERSON_FIRST_NAME}`
                 visible = client->_bind( show-person_first_name ) ).
    view_column( columns = columns
                 label   = `First name, female`
                 cell    = `{PERSON_FIRST_NAME_FEMALE}`
                 visible = client->_bind( show-person_first_name_female ) ).
    view_column( columns = columns
                 label   = `First name, male`
                 cell    = `{PERSON_FIRST_NAME_MALE}`
                 visible = client->_bind( show-person_first_name_male ) ).
    view_column( columns = columns
                 label   = `Last name`
                 cell    = `{PERSON_LAST_NAME}`
                 visible = client->_bind( show-person_last_name ) ).
    view_column( columns = columns
                 label   = `Initial`
                 cell    = `{PERSON_INITIAL}`
                 visible = client->_bind( show-person_initial ) ).
    view_column( columns = columns
                 label   = `Phone number`
                 cell    = `{PHONE_NUMBER}`
                 visible = client->_bind( show-phone_number ) ).
    view_column( columns = columns
                 label   = `Phone label`
                 cell    = `{PHONE_LABEL}`
                 visible = client->_bind( show-phone_label ) ).

  ENDMETHOD.


  METHOD view_column.

    columns->ele( n = `Column` ns = `t`
        )->a( n = `visible` v = visible
        )->a( n = `width`   v = `12rem`
        )->ele( n = `label` ns = `t`
            )->tag( `Label`
                )->a( n = `text` v = label
        )->end(
        )->ele( n = `template` ns = `t`
            )->tag( `Text`
                )->a( n = `text`     v = cell
                )->a( n = `wrapping` v = `false` ).

  ENDMETHOD.


  METHOD on_event.

    CASE client->get_event( ).

      WHEN `LOCALE`.
        generators_probe( ).
        IF has_records = abap_true.
          records_generate( ).
        ENDIF.

      WHEN `EXAMPLES`.
        generators_probe( ).

      WHEN `TRY`.
        generator_try( client->get_event_arg( ) ).

      WHEN `SELECTION`.
        selection_update( ).

      WHEN `SELECT_ALL`.
        selection_set( `ALL` ).

      WHEN `SELECT_NONE`.
        selection_set( `NONE` ).

      WHEN `SELECT_DEFAULTS`.
        selection_set( `DEFAULTS` ).

      WHEN `GENERATE`.
        IF NOT line_exists( t_generators[ selected = abap_true ] ).
          client->message_box_display( text = `Select at least one generator.` type = `error` ).
          RETURN.
        ENDIF.
        records_generate( ).
        tab = `RESULT`.

      WHEN `DOWNLOAD`.
        csv_download( ).

    ENDCASE.

  ENDMETHOD.


  METHOD generators_probe.

    " not every locale fills every word list - a generator whose list is
    " empty fails inside the library (table expression on index 0), so it is
    " called once here and switched off for this locale when it fails
    DATA(faker) = NEW zcl_faker( locale ).
    LOOP AT t_generators REFERENCE INTO DATA(generator).
      TRY.
          generator->example = fake( faker = faker
                                     key   = generator->key ).
          generator->enabled = abap_true.
        CATCH cx_sy_itab_line_not_found cx_sy_no_handler.
          generator->example  = `- not provided for this locale -`.
          generator->enabled  = abap_false.
          generator->selected = abap_false.
      ENDTRY.
    ENDLOOP.
    selection_update( ).

  ENDMETHOD.


  METHOD generator_try.

    ASSIGN t_generators[ key = key ] TO FIELD-SYMBOL(<generator>).
    IF sy-subrc <> 0 OR <generator>-enabled = abap_false.
      RETURN.
    ENDIF.
    TRY.
        <generator>-example = fake( faker = NEW zcl_faker( locale )
                                    key   = key ).
      CATCH cx_sy_itab_line_not_found cx_sy_no_handler.
        <generator>-example = `- failed for this locale -`.
    ENDTRY.

  ENDMETHOD.


  METHOD selection_set.

    DATA(defaults) = VALUE string_table( ( `PERSON_NAME` )
                                         ( `ADDRESS_STREET_ADDRESS` )
                                         ( `ADDRESS_CITY_ADDRESS` )
                                         ( `PHONE_NUMBER` )
                                         ( `COMPANY_NAME` )
                                         ( `JOB_TITLE` )
                                         ( `DATE_OF_BIRTH_ADULT` ) ).
    LOOP AT t_generators REFERENCE INTO DATA(generator).
      generator->selected = xsdbool( generator->enabled = abap_true
                                     AND ( mode = `ALL`
                                        OR ( mode = `DEFAULTS` AND line_exists( defaults[ table_line = generator->key ] ) ) ) ).
    ENDLOOP.
    selection_update( ).

  ENDMETHOD.


  METHOD selection_update.

    DATA(count) = 0.
    LOOP AT t_generators TRANSPORTING NO FIELDS WHERE selected = abap_true.
      count = count + 1.
    ENDLOOP.
    selection = |{ count } of { lines( t_generators ) } generators selected|.

  ENDMETHOD.


  METHOD records_generate.

    FIELD-SYMBOLS <value>   TYPE string.
    FIELD-SYMBOLS <visible> TYPE abap_bool.

    rows = nmax( val1 = 1 val2 = nmin( val1 = rows val2 = max_rows ) ).
    selection_update( ).

    GET RUN TIME FIELD DATA(start).
    DATA(faker) = NEW zcl_faker( locale ).
    CLEAR t_records.
    DO rows TIMES.
      DATA(record) = VALUE ty_s_record( nr = sy-index ).
      LOOP AT t_generators INTO DATA(generator) WHERE selected = abap_true.
        ASSIGN COMPONENT generator-key OF STRUCTURE record TO <value>.
        TRY.
            <value> = fake( faker = faker
                            key   = generator-key ).
          CATCH cx_sy_itab_line_not_found cx_sy_no_handler.
            " a format can pick a word list this locale leaves empty
            CLEAR <value>.
        ENDTRY.
      ENDLOOP.
      INSERT record INTO TABLE t_records.
    ENDDO.
    GET RUN TIME FIELD DATA(stop).

    CLEAR show.
    DATA(columns) = 0.
    LOOP AT t_generators INTO generator WHERE selected = abap_true.
      ASSIGN COMPONENT generator-key OF STRUCTURE show TO <visible>.
      <visible> = abap_true.
      columns = columns + 1.
    ENDLOOP.

    has_records = abap_true.
    result_info = |{ rows } records x { columns } columns, locale { locale }, | &&
                  |generated in { ( stop - start ) / 1000 } ms|.

  ENDMETHOD.


  METHOD csv_download.

    CONSTANTS utf8_bom TYPE x LENGTH 3 VALUE 'EFBBBF'.
    FIELD-SYMBOLS <value> TYPE string.

    DATA(selected) = VALUE ty_t_generator( FOR g IN t_generators WHERE ( selected = abap_true ) ( g ) ).
    DATA(csv) = concat_lines_of( table = VALUE string_table( FOR g IN selected ( to_lower( g-key ) ) )
                                 sep   = `,` ) && cl_abap_char_utilities=>cr_lf.

    LOOP AT t_records INTO DATA(record).
      DATA(line) = VALUE string_table( ).
      LOOP AT selected INTO DATA(generator).
        ASSIGN COMPONENT generator-key OF STRUCTURE record TO <value>.
        INSERT csv_value( <value> ) INTO TABLE line.
      ENDLOOP.
      csv = csv && concat_lines_of( table = line
                                    sep   = `,` ) && cl_abap_char_utilities=>cr_lf.
    ENDLOOP.

    " with a byte order mark, spreadsheet programs read the umlauts as UTF-8
    DATA(bytes) = cl_abap_codepage=>convert_to( csv ).
    CONCATENATE utf8_bom bytes INTO bytes IN BYTE MODE.
    DATA(base64) = cl_web_http_utility=>encode_x_base64( bytes ).
    client->follow_up_action( val   = client->cs_event-download_b64_file
                              t_arg = VALUE #( ( |data:text/csv;base64,{ base64 }| )
                                               ( |fake_data_{ locale }.csv| ) ) ).

  ENDMETHOD.


  METHOD model_init.

    tab    = `GENERATORS`.
    locale = `de_DE`.
    rows   = 25.

    t_locales = VALUE #( ( key = `de_DE`   text = `de_DE - German` )
                         ( key = `en_US`   text = `en_US - English (United States)` )
                         ( key = `pt_BR`   text = `pt_BR - Portuguese (Brazil)` )
                         ( key = `DEFAULT` text = `DEFAULT - the library fallback` ) ).

    " sorted by group, as the grouped table shows them
    t_generators = VALUE #(
        ( key = `ADDRESS_STREET_ADDRESS`      grp = `Address` label = `Street address`      call = `address->street_address( )` )
        ( key = `ADDRESS_STREET_NAME`         grp = `Address` label = `Street name`         call = `address->street_name( )` )
        ( key = `ADDRESS_BUILDING_NUMBER`     grp = `Address` label = `Building number`     call = `address->building_number( )` )
        ( key = `ADDRESS_STREET_SUFFIX_LONG`  grp = `Address` label = `Street suffix`       call = `address->street_suffix_long( )` )
        ( key = `ADDRESS_STREET_SUFFIX_SHORT` grp = `Address` label = `Street suffix, short` call = `address->street_suffix_short( )` )
        ( key = `ADDRESS_POSTCODE`            grp = `Address` label = `Postcode`            call = `address->postcode( )` )
        ( key = `ADDRESS_CITY`                grp = `Address` label = `City`                call = `address->city( )` )
        ( key = `ADDRESS_CITY_NAME`           grp = `Address` label = `City name`           call = `address->city_name( )` )
        ( key = `ADDRESS_CITY_PREFIX`         grp = `Address` label = `City prefix`         call = `address->city_prefix( )` )
        ( key = `ADDRESS_CITY_SUFFIX`         grp = `Address` label = `City suffix`         call = `address->city_suffix( )` )
        ( key = `ADDRESS_CITY_ADDRESS`        grp = `Address` label = `Postcode and city`   call = `address->city_address( )` )
        ( key = `ADDRESS_STATE_ABBR`          grp = `Address` label = `State`               call = `address->state_abbr( )` )
        ( key = `COMPANY_NAME`                grp = `Company` label = `Company`             call = `company->company_name( )` )
        ( key = `COMPANY_SUFFIX`              grp = `Company` label = `Legal form`          call = `company->company_suffix( )` )
        ( key = `COMPANY_CLAIM`               grp = `Company` label = `Claim`               call = `company->company_claim( )` )
        ( key = `COMPANY_CATCH_PHRASE_1`      grp = `Company` label = `Catch phrase word 1` call = `company->catch_phrase_words_part_1( )` )
        ( key = `COMPANY_CATCH_PHRASE_2`      grp = `Company` label = `Catch phrase word 2` call = `company->catch_phrase_words_part_2( )` )
        ( key = `COMPANY_CATCH_PHRASE_3`      grp = `Company` label = `Catch phrase word 3` call = `company->catch_phrase_words_part_3( )` )
        ( key = `COMPANY_BS_1`                grp = `Company` label = `Buzzword 1`          call = `company->bs_words_part_1( )` )
        ( key = `COMPANY_BS_2`                grp = `Company` label = `Buzzword 2`          call = `company->bs_words_part_2( )` )
        ( key = `COMPANY_BS_3`                grp = `Company` label = `Buzzword 3`          call = `company->bs_words_part_3( )` )
        ( key = `DATE_OF_BIRTH`               grp = `Date`    label = `Date of birth`       call = `date->date_of_birth( )` )
        ( key = `DATE_OF_BIRTH_ADULT`         grp = `Date`    label = `Date of birth, 18+`  call = `date->date_of_birth_adult( )` )
        ( key = `DATE_PAST`                   grp = `Date`    label = `Date, past 10 years` call = `date->date( i_max_years = 10 )` )
        ( key = `DATE_FUTURE`                 grp = `Date`    label = `Date, next 5 years`  call = `date->date( i_max_years = 5 i_future = abap_true )` )
        ( key = `DATE_TODAY`                  grp = `Date`    label = `Today`               call = `date->today( )` )
        ( key = `DATE_TOMORROW`               grp = `Date`    label = `Tomorrow`            call = `date->tomorrow( )` )
        ( key = `DATE_YESTERDAY`              grp = `Date`    label = `Yesterday`           call = `date->yesterday( )` )
        ( key = `JOB_TITLE`                   grp = `Job`     label = `Job title`           call = `job->job_title( )` )
        ( key = `PERSON_NAME`                 grp = `Person`  label = `Name`                call = `person->name( )` )
        ( key = `PERSON_FIRST_NAME`           grp = `Person`  label = `First name`          call = `person->first_name( )` )
        ( key = `PERSON_FIRST_NAME_FEMALE`    grp = `Person`  label = `First name, female`  call = `person->first_name_female( )` )
        ( key = `PERSON_FIRST_NAME_MALE`      grp = `Person`  label = `First name, male`    call = `person->first_name_male( )` )
        ( key = `PERSON_LAST_NAME`            grp = `Person`  label = `Last name`           call = `person->last_name( )` )
        ( key = `PERSON_INITIAL`              grp = `Person`  label = `Initial`             call = `person->initial( )` )
        ( key = `PHONE_NUMBER`                grp = `Phone`   label = `Phone number`        call = `phone->number( )` )
        ( key = `PHONE_LABEL`                 grp = `Phone`   label = `Phone label`         call = `phone->label( )` ) ).

    generators_probe( ).
    selection_set( `DEFAULTS` ).

  ENDMETHOD.


  METHOD fake.

    CASE key.
      WHEN `ADDRESS_STREET_ADDRESS`.
        result = faker->address->street_address( ).
      WHEN `ADDRESS_STREET_NAME`.
        result = faker->address->street_name( ).
      WHEN `ADDRESS_BUILDING_NUMBER`.
        result = faker->address->building_number( ).
      WHEN `ADDRESS_STREET_SUFFIX_LONG`.
        result = faker->address->street_suffix_long( ).
      WHEN `ADDRESS_STREET_SUFFIX_SHORT`.
        result = faker->address->street_suffix_short( ).
      WHEN `ADDRESS_POSTCODE`.
        result = faker->address->postcode( ).
      WHEN `ADDRESS_CITY`.
        result = faker->address->city( ).
      WHEN `ADDRESS_CITY_NAME`.
        result = faker->address->city_name( ).
      WHEN `ADDRESS_CITY_PREFIX`.
        result = faker->address->city_prefix( ).
      WHEN `ADDRESS_CITY_SUFFIX`.
        result = faker->address->city_suffix( ).
      WHEN `ADDRESS_CITY_ADDRESS`.
        result = faker->address->city_address( ).
      WHEN `ADDRESS_STATE_ABBR`.
        result = faker->address->state_abbr( ).
      WHEN `COMPANY_NAME`.
        result = faker->company->company_name( ).
      WHEN `COMPANY_SUFFIX`.
        result = faker->company->company_suffix( ).
      WHEN `COMPANY_CLAIM`.
        result = faker->company->company_claim( ).
      WHEN `COMPANY_CATCH_PHRASE_1`.
        result = faker->company->catch_phrase_words_part_1( ).
      WHEN `COMPANY_CATCH_PHRASE_2`.
        result = faker->company->catch_phrase_words_part_2( ).
      WHEN `COMPANY_CATCH_PHRASE_3`.
        result = faker->company->catch_phrase_words_part_3( ).
      WHEN `COMPANY_BS_1`.
        result = faker->company->bs_words_part_1( ).
      WHEN `COMPANY_BS_2`.
        result = faker->company->bs_words_part_2( ).
      WHEN `COMPANY_BS_3`.
        result = faker->company->bs_words_part_3( ).
      WHEN `DATE_OF_BIRTH`.
        result = faker->date->date_of_birth( ).
      WHEN `DATE_OF_BIRTH_ADULT`.
        result = faker->date->date_of_birth_adult( ).
      WHEN `DATE_PAST`.
        result = faker->date->date( i_max_years = 10 ).
      WHEN `DATE_FUTURE`.
        result = faker->date->date( i_max_years = 5
                                    i_future    = abap_true ).
      WHEN `DATE_TODAY`.
        result = faker->date->today( ).
      WHEN `DATE_TOMORROW`.
        result = faker->date->tomorrow( ).
      WHEN `DATE_YESTERDAY`.
        result = faker->date->yesterday( ).
      WHEN `JOB_TITLE`.
        result = faker->job->job_title( ).
      WHEN `PERSON_NAME`.
        result = faker->person->name( ).
      WHEN `PERSON_FIRST_NAME`.
        result = faker->person->first_name( ).
      WHEN `PERSON_FIRST_NAME_FEMALE`.
        result = faker->person->first_name_female( ).
      WHEN `PERSON_FIRST_NAME_MALE`.
        result = faker->person->first_name_male( ).
      WHEN `PERSON_LAST_NAME`.
        result = faker->person->last_name( ).
      WHEN `PERSON_INITIAL`.
        result = faker->person->initial( ).
      WHEN `PHONE_NUMBER`.
        result = faker->phone->number( ).
      WHEN `PHONE_LABEL`.
        result = faker->phone->label( ).
    ENDCASE.

  ENDMETHOD.


  METHOD csv_value.

    " RFC 4180: a value with a separator, a quote or a line break is quoted,
    " a quote inside it doubled
    IF val CA |,"\r\n|.
      result = |"{ replace( val = val sub = `"` with = `""` occ = 0 ) }"|.
    ELSE.
      result = val.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
