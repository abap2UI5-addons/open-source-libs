"! <p class="shorttext">abap-fm-logger log viewer with abap2UI5</p>
"!
"! A browser version of ZAFL_VIEWER, the log report of
"! https://github.com/hhelibeb/abap-fm-logger: search the function module
"! calls the logger wrote into its table ZAFL_LOG (function module, date
"! range, status, message, the three custom fields), see the logged import,
"! export, changing and tables parameters pretty-printed as JSON, and a
"! count per function module. The labels of the custom fields come from
"! ZAFL_CONFIG, as in the report.
"!
"! Read-only by default. This app READS THE LOG TABLE, whose parameters hold
"! whatever the logged function modules received and returned - business
"! data included: add your own authorization check before production use.
"! Reprocessing (zcl_afl_utilities=>re_process, the WE19-like button of the
"! report) executes the function module again with the logged input. It is
"! off until the user switches it on, asks for an explicit confirmation
"! (with a warning in a productive client) and runs the library's own
"! authority check (S_DEVELOP, activity 16 - the SE37 test right) first.
CLASS z2ui5_cl_osl_fm_logger DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_key_text,
        key  TYPE string,
        text TYPE string,
      END OF ty_s_key_text.
    TYPES ty_t_key_text TYPE STANDARD TABLE OF ty_s_key_text WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_filter,
        fname     TYPE string,
        date_from TYPE string,
        date_to   TYPE string,
        status    TYPE string,
        message   TYPE string,
        cust1     TYPE string,
        cust2     TYPE string,
        cust3     TYPE string,
        max_rows  TYPE i,
      END OF ty_s_filter.

    TYPES:
      BEGIN OF ty_s_labels,
        cust1 TYPE string,
        cust2 TYPE string,
        cust3 TYPE string,
      END OF ty_s_labels.

    TYPES:
      BEGIN OF ty_s_log,
        guid         TYPE string,
        date         TYPE string,
        time         TYPE string,
        fname        TYPE string,
        uname        TYPE string,
        status       TYPE string,
        status_state TYPE string,
        message      TYPE string,
        cust1        TYPE string,
        cust2        TYPE string,
        cust3        TYPE string,
        runtime_ms   TYPE p LENGTH 12 DECIMALS 1,
      END OF ty_s_log.
    TYPES ty_t_log TYPE STANDARD TABLE OF ty_s_log WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_overview,
        fname        TYPE string,
        calls        TYPE i,
        share        TYPE p LENGTH 5 DECIMALS 1,
        share_text   TYPE string,
        errors       TYPE i,
        errors_state TYPE string,
        avg_ms       TYPE p LENGTH 12 DECIMALS 1,
        last_call    TYPE string,
      END OF ty_s_overview.
    TYPES ty_t_overview TYPE STANDARD TABLE OF ty_s_overview WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_detail,
        title              TYPE string,
        tab                TYPE string,
        import             TYPE string,
        export             TYPE string,
        change_in          TYPE string,
        change_out         TYPE string,
        table_in           TYPE string,
        table_out          TYPE string,
        import_visible     TYPE abap_bool,
        export_visible     TYPE abap_bool,
        change_in_visible  TYPE abap_bool,
        change_out_visible TYPE abap_bool,
        table_in_visible   TYPE abap_bool,
        table_out_visible  TYPE abap_bool,
        nothing_logged     TYPE abap_bool,
      END OF ty_s_detail.

    DATA filter            TYPE ty_s_filter.
    DATA labels            TYPE ty_s_labels.
    DATA t_fnames          TYPE ty_t_key_text.
    DATA tab               TYPE string.
    DATA result_title      TYPE string.
    DATA t_logs            TYPE ty_t_log.
    DATA overview_title    TYPE string.
    DATA t_overview        TYPE ty_t_overview.
    DATA detail            TYPE ty_s_detail.
    DATA reprocess_enabled TYPE abap_bool.
    DATA confirm_text      TYPE string.
    DATA is_production     TYPE abap_bool.

  PROTECTED SECTION.
    DATA client       TYPE REF TO z2ui5_if_client.
    DATA detail_guid  TYPE zafl_log-guid.
    DATA detail_fname TYPE zafl_log-fname.

    METHODS view_display.
    METHODS view_filter
      IMPORTING
        content TYPE REF TO z2ui5_cl_ui5_view_builder.
    METHODS view_logs
      IMPORTING
        items TYPE REF TO z2ui5_cl_ui5_view_builder.
    METHODS view_overview
      IMPORTING
        items TYPE REF TO z2ui5_cl_ui5_view_builder.
    METHODS view_field
      IMPORTING
        grid  TYPE REF TO z2ui5_cl_ui5_view_builder
        label TYPE string
        value TYPE string.
    METHODS popup_detail.
    METHODS popup_parameter
      IMPORTING
        items   TYPE REF TO z2ui5_cl_ui5_view_builder
        key     TYPE string
        text    TYPE string
        value   TYPE string
        visible TYPE string.
    METHODS popup_confirm.

    METHODS on_event.
    METHODS search.
    METHODS overview_update.
    METHODS labels_update.
    METHODS detail_load
      IMPORTING
        guid TYPE zafl_log-guid.
    METHODS reprocess.
    METHODS model_init.

    CLASS-METHODS range_add
      IMPORTING
        value TYPE string
      CHANGING
        range TYPE STANDARD TABLE.
    CLASS-METHODS status_state
      IMPORTING
        status        TYPE zafl_log-status
      RETURNING
        VALUE(result) TYPE string.
    CLASS-METHODS json_pretty
      IMPORTING
        json          TYPE string
      RETURNING
        VALUE(result) TYPE string.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_osl_fm_logger IMPLEMENTATION.

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
            )->ele( `Shell`
                )->a( n = `appWidthLimited` v = `false`
                )->ele( `Page`
                    )->a( n = `title`          v = `Function module logs - abap-fm-logger x abap2UI5`
                    )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
                    )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    page->ele( `headerContent`
        )->tag( `Label`
            )->a( n = `text` v = `Allow reprocessing`
        )->tag( `Switch`
            )->a( n = `state`         v = client->_bind( reprocess_enabled )
            )->a( n = `customTextOn`  v = `On`
            )->a( n = `customTextOff` v = `Off`
            )->a( n = `type`          v = `AcceptReject`
        )->tag( `Link`
            )->a( n = `text`   v = `hhelibeb/abap-fm-logger`
            )->a( n = `href`   v = `https://github.com/hhelibeb/abap-fm-logger`
            )->a( n = `target` v = `_blank` ).

    DATA(content) = page->ele( `content` ).
    view_filter( content ).

    DATA(items) = content->ele( `IconTabBar`
        )->a( n = `selectedKey` v = client->_bind( tab )
        )->a( n = `expandable`  v = `false`
        )->a( n = `class`       v = `sapUiResponsiveContentPadding`
        )->ele( `items` ).

    view_logs( items ).
    view_overview( items ).

    client->view_display( page->stringify( ) ).

  ENDMETHOD.


  METHOD view_filter.

    DATA(panel) = content->ele( `Panel`
        )->a( n = `headerText` v = `Search the log table ZAFL_LOG`
        )->a( n = `class`      v = `sapUiResponsiveContentPadding` ).

    DATA(grid) = panel->ele( n = `Grid` ns = `l`
        )->a( n = `defaultSpan` v = `XL3 L3 M6 S12` ).

    grid->ele( `VBox`
        )->tag( `Label`
            )->a( n = `text` v = `Function module (* for patterns)`
        )->ele( `ComboBox`
            )->a( n = `value`  v = client->_bind( filter-fname )
            )->a( n = `items`  v = client->_bind( t_fnames )
            )->a( n = `width`  v = `100%`
            )->a( n = `change` v = client->_event( `FNAME_CHANGE` )
            )->tag( n = `Item` ns = `core`
                )->a( n = `key`  v = `{KEY}`
                )->a( n = `text` v = `{TEXT}` ).

    grid->ele( `VBox`
        )->tag( `Label`
            )->a( n = `text` v = `Logged from`
        )->tag( `DatePicker`
            )->a( n = `value`       v = client->_bind( filter-date_from )
            )->a( n = `valueFormat` v = `yyyyMMdd`
            )->a( n = `width`       v = `100%` ).

    grid->ele( `VBox`
        )->tag( `Label`
            )->a( n = `text` v = `Logged to`
        )->tag( `DatePicker`
            )->a( n = `value`       v = client->_bind( filter-date_to )
            )->a( n = `valueFormat` v = `yyyyMMdd`
            )->a( n = `width`       v = `100%` ).

    grid->ele( `VBox`
        )->tag( `Label`
            )->a( n = `text` v = `Status code`
        )->tag( `Input`
            )->a( n = `value`     v = client->_bind( filter-status )
            )->a( n = `maxLength` v = `2`
            )->a( n = `width`     v = `100%` ).

    view_field( grid  = grid
                label = client->_bind( labels-cust1 )
                value = client->_bind( filter-cust1 ) ).
    view_field( grid  = grid
                label = client->_bind( labels-cust2 )
                value = client->_bind( filter-cust2 ) ).
    view_field( grid  = grid
                label = client->_bind( labels-cust3 )
                value = client->_bind( filter-cust3 ) ).
    view_field( grid  = grid
                label = `Message (* for patterns)`
                value = client->_bind( filter-message ) ).

    panel->ele( `OverflowToolbar`
        )->a( n = `style` v = `Clear`
        )->ele( `content`
            )->tag( `Label`
                )->a( n = `text` v = `Max. hits`
            )->tag( `StepInput`
                )->a( n = `value` v = client->_bind( filter-max_rows )
                )->a( n = `min`   v = `1`
                )->a( n = `max`   v = `10000`
                )->a( n = `step`  v = `100`
                )->a( n = `width` v = `9rem`
            )->tag( `ToolbarSpacer`
            )->tag( `Button`
                )->a( n = `text`  v = `Reset`
                )->a( n = `icon`  v = `sap-icon://reset`
                )->a( n = `press` v = client->_event( `RESET` )
            )->tag( `Button`
                )->a( n = `text`  v = `Search`
                )->a( n = `icon`  v = `sap-icon://search`
                )->a( n = `type`  v = `Emphasized`
                )->a( n = `press` v = client->_event( `SEARCH` ) ).

  ENDMETHOD.


  METHOD view_field.

    grid->ele( `VBox`
        )->tag( `Label`
            )->a( n = `text` v = label
        )->tag( `Input`
            )->a( n = `value` v = value
            )->a( n = `width` v = `100%` ).

  ENDMETHOD.


  METHOD view_logs.

    DATA(table) = items->ele( `IconTabFilter`
        )->a( n = `key`  v = `LOGS`
        )->a( n = `text` v = `Calls`
        )->a( n = `icon` v = `sap-icon://list`
        )->ele( `content`
            )->ele( `Table`
                )->a( n = `items`            v = client->_bind( t_logs )
                )->a( n = `growing`          v = `true`
                )->a( n = `growingThreshold` v = `50`
                )->a( n = `noDataText`       v = `No logged calls match the filter`
                )->a( n = `headerText`       v = client->_bind( result_title ) ).

    table->ele( `columns`
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Logged at`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Function module`
        )->end(
        )->ele( `Column`
            )->a( n = `minScreenWidth` v = `Tablet`
            )->a( n = `demandPopin`    v = `true`
            )->tag( `Text`
                )->a( n = `text` v = `User`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Status`
        )->end(
        )->ele( `Column`
            )->a( n = `minScreenWidth` v = `Tablet`
            )->a( n = `demandPopin`    v = `true`
            )->tag( `Text`
                )->a( n = `text` v = `Message`
        )->end(
        )->ele( `Column`
            )->a( n = `minScreenWidth` v = `Desktop`
            )->a( n = `demandPopin`    v = `true`
            )->tag( `Text`
                )->a( n = `text` v = client->_bind( labels-cust1 )
        )->end(
        )->ele( `Column`
            )->a( n = `minScreenWidth` v = `Desktop`
            )->a( n = `demandPopin`    v = `true`
            )->tag( `Text`
                )->a( n = `text` v = client->_bind( labels-cust2 )
        )->end(
        )->ele( `Column`
            )->a( n = `minScreenWidth` v = `Desktop`
            )->a( n = `demandPopin`    v = `true`
            )->tag( `Text`
                )->a( n = `text` v = client->_bind( labels-cust3 )
        )->end(
        )->ele( `Column`
            )->a( n = `hAlign` v = `End`
            )->tag( `Text`
                )->a( n = `text` v = `Runtime` ).

    table->ele( `items`
        )->ele( `ColumnListItem`
            )->a( n = `type`  v = `Navigation`
            )->a( n = `press` v = client->_event( val = `DETAIL` arg = `${GUID}` )
            )->ele( `cells`
                )->tag( `ObjectIdentifier`
                    )->a( n = `title` v = `{DATE}`
                    )->a( n = `text`  v = `{TIME}`
                )->tag( `Text`
                    )->a( n = `text` v = `{FNAME}`
                )->tag( `Text`
                    )->a( n = `text` v = `{UNAME}`
                )->tag( `ObjectStatus`
                    )->a( n = `text`  v = `{STATUS}`
                    )->a( n = `state` v = `{STATUS_STATE}`
                )->tag( `Text`
                    )->a( n = `text` v = `{MESSAGE}`
                )->tag( `Text`
                    )->a( n = `text` v = `{CUST1}`
                )->tag( `Text`
                    )->a( n = `text` v = `{CUST2}`
                )->tag( `Text`
                    )->a( n = `text` v = `{CUST3}`
                )->tag( `ObjectNumber`
                    )->a( n = `number` v = `{RUNTIME_MS}`
                    )->a( n = `unit`   v = `ms` ).

  ENDMETHOD.


  METHOD view_overview.

    DATA(table) = items->ele( `IconTabFilter`
        )->a( n = `key`  v = `OVERVIEW`
        )->a( n = `text` v = `Per function module`
        )->a( n = `icon` v = `sap-icon://group-2`
        )->ele( `content`
            )->ele( `Table`
                )->a( n = `items`      v = client->_bind( t_overview )
                )->a( n = `noDataText` v = `No logged calls match the filter`
                )->a( n = `headerText` v = client->_bind( overview_title ) ).

    table->ele( `columns`
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Function module`
        )->end(
        )->ele( `Column`
            )->a( n = `hAlign` v = `End`
            )->tag( `Text`
                )->a( n = `text` v = `Calls`
        )->end(
        )->ele( `Column`
            )->a( n = `minScreenWidth` v = `Tablet`
            )->a( n = `demandPopin`    v = `true`
            )->tag( `Text`
                )->a( n = `text` v = `Share of the hits`
        )->end(
        )->ele( `Column`
            )->a( n = `hAlign` v = `End`
            )->tag( `Text`
                )->a( n = `text` v = `Errors (status E, A, X)`
        )->end(
        )->ele( `Column`
            )->a( n = `hAlign` v = `End`
            )->tag( `Text`
                )->a( n = `text` v = `Avg. runtime`
        )->end(
        )->ele( `Column`
            )->a( n = `minScreenWidth` v = `Tablet`
            )->a( n = `demandPopin`    v = `true`
            )->tag( `Text`
                )->a( n = `text` v = `Last call` ).

    table->ele( `items`
        )->ele( `ColumnListItem`
            )->a( n = `type`  v = `Navigation`
            )->a( n = `press` v = client->_event( val = `OVERVIEW_PICK` arg = `${FNAME}` )
            )->ele( `cells`
                )->tag( `Text`
                    )->a( n = `text` v = `{FNAME}`
                )->tag( `ObjectNumber`
                    )->a( n = `number` v = `{CALLS}`
                )->tag( `ProgressIndicator`
                    )->a( n = `percentValue` v = `{SHARE}`
                    )->a( n = `displayValue` v = `{SHARE_TEXT}`
                    )->a( n = `showValue`    v = `true`
                )->tag( `ObjectNumber`
                    )->a( n = `number` v = `{ERRORS}`
                    )->a( n = `state`  v = `{ERRORS_STATE}`
                )->tag( `ObjectNumber`
                    )->a( n = `number` v = `{AVG_MS}`
                    )->a( n = `unit`   v = `ms`
                )->tag( `Text`
                    )->a( n = `text` v = `{LAST_CALL}` ).

  ENDMETHOD.


  METHOD popup_detail.

    DATA(dialog) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `FragmentDefinition` ns = `core`
            )->a( n = `xmlns`        v = `sap.m`
            )->a( n = `xmlns:core`   v = `sap.ui.core`
            )->a( n = `xmlns:editor` v = `sap.ui.codeeditor`
            )->ele( `Dialog`
                )->a( n = `title`        v = client->_bind( detail-title )
                )->a( n = `contentWidth` v = `60rem`
                )->a( n = `resizable`    v = `true`
                )->a( n = `draggable`    v = `true` ).

    DATA(content) = dialog->ele( `content` ).
    content->tag( `MessageStrip`
        )->a( n = `text`     v = `No parameters were logged for this call - switch them on per function module in ZAFL_CONFIG.`
        )->a( n = `type`     v = `Information`
        )->a( n = `showIcon` v = `true`
        )->a( n = `visible`  v = client->_bind( detail-nothing_logged )
        )->a( n = `class`    v = `sapUiSmallMargin` ).

    DATA(items) = content->ele( `IconTabBar`
        )->a( n = `selectedKey` v = client->_bind( detail-tab )
        )->a( n = `expandable`  v = `false`
        )->ele( `items` ).

    popup_parameter( items   = items
                     key     = `IMPORT`
                     text    = `Import`
                     value   = client->_bind( detail-import )
                     visible = client->_bind( detail-import_visible ) ).
    popup_parameter( items   = items
                     key     = `EXPORT`
                     text    = `Export`
                     value   = client->_bind( detail-export )
                     visible = client->_bind( detail-export_visible ) ).
    popup_parameter( items   = items
                     key     = `CHANGE_IN`
                     text    = `Changing in`
                     value   = client->_bind( detail-change_in )
                     visible = client->_bind( detail-change_in_visible ) ).
    popup_parameter( items   = items
                     key     = `CHANGE_OUT`
                     text    = `Changing out`
                     value   = client->_bind( detail-change_out )
                     visible = client->_bind( detail-change_out_visible ) ).
    popup_parameter( items   = items
                     key     = `TABLE_IN`
                     text    = `Tables in`
                     value   = client->_bind( detail-table_in )
                     visible = client->_bind( detail-table_in_visible ) ).
    popup_parameter( items   = items
                     key     = `TABLE_OUT`
                     text    = `Tables out`
                     value   = client->_bind( detail-table_out )
                     visible = client->_bind( detail-table_out_visible ) ).

    dialog->ele( `buttons`
        )->tag( `Button`
            )->a( n = `text`    v = `Reprocess...`
            )->a( n = `icon`    v = `sap-icon://restart`
            )->a( n = `type`    v = `Reject`
            )->a( n = `visible` v = client->_bind( reprocess_enabled )
            )->a( n = `press`   v = client->_event( `REPROCESS` )
        )->tag( `Button`
            )->a( n = `text`  v = `Close`
            )->a( n = `type`  v = `Emphasized`
            )->a( n = `press` v = client->follow_up_action( z2ui5_if_client=>cs_event-popup_close ) ).

    client->popup_display( dialog->stringify( ) ).

  ENDMETHOD.


  METHOD popup_parameter.

    items->ele( `IconTabFilter`
        )->a( n = `key`     v = key
        )->a( n = `text`    v = text
        )->a( n = `visible` v = visible
        )->ele( `content`
            )->tag( n = `CodeEditor` ns = `editor`
                )->a( n = `value`       v = value
                )->a( n = `type`        v = `json`
                )->a( n = `editable`    v = `false`
                )->a( n = `lineNumbers` v = `true`
                )->a( n = `height`      v = `28rem`
                )->a( n = `width`       v = `100%` ).

  ENDMETHOD.


  METHOD popup_confirm.

    DATA(dialog) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `FragmentDefinition` ns = `core`
            )->a( n = `xmlns`      v = `sap.m`
            )->a( n = `xmlns:core` v = `sap.ui.core`
            )->ele( `Dialog`
                )->a( n = `title`        v = `Reprocess this call?`
                )->a( n = `type`         v = `Message`
                )->a( n = `state`        v = `Warning`
                )->a( n = `contentWidth` v = `32rem` ).

    dialog->ele( `content`
        )->ele( `VBox`
            )->tag( `MessageStrip`
                )->a( n = `text`     v = `This client is flagged as productive.`
                )->a( n = `type`     v = `Error`
                )->a( n = `showIcon` v = `true`
                )->a( n = `visible`  v = client->_bind( is_production )
                )->a( n = `class`    v = `sapUiSmallMarginBottom`
            )->tag( `Text`
                )->a( n = `text` v = client->_bind( confirm_text ) ).

    dialog->ele( `buttons`
        )->tag( `Button`
            )->a( n = `text`  v = `Execute function module`
            )->a( n = `type`  v = `Reject`
            )->a( n = `press` v = client->_event( `REPROCESS_CONFIRM` )
        )->tag( `Button`
            )->a( n = `text`  v = `Cancel`
            )->a( n = `type`  v = `Emphasized`
            )->a( n = `press` v = client->_event( `REPROCESS_CANCEL` ) ).

    client->popup_display( dialog->stringify( ) ).

  ENDMETHOD.


  METHOD on_event.

    CASE client->get_event( ).

      WHEN `SEARCH`.
        search( ).

      WHEN `RESET`.
        DATA(max_rows) = filter-max_rows.
        CLEAR filter.
        filter-max_rows = max_rows.
        labels_update( ).
        search( ).

      WHEN `FNAME_CHANGE`.
        labels_update( ).

      WHEN `OVERVIEW_PICK`.
        filter-fname = client->get_event_arg( ).
        tab = `LOGS`.
        labels_update( ).
        search( ).

      WHEN `DETAIL`.
        DATA guid TYPE zafl_log-guid.
        guid = client->get_event_arg( ).
        detail_load( guid ).
        IF detail_guid IS NOT INITIAL.
          popup_detail( ).
        ENDIF.

      WHEN `REPROCESS`.
        IF reprocess_enabled = abap_false.
          client->message_box_display( text = `Switch on "Allow reprocessing" first.` type = `warning` ).
          RETURN.
        ENDIF.
        is_production = zcl_afl_utilities=>is_prd( ).
        confirm_text = |{ detail_fname } is called again with the import, changing and tables | &&
                       |parameters of this log entry (GUID { detail_guid }). The function module | &&
                       |really runs: whatever it posts, sends or changes happens again, under your user.|.
        popup_confirm( ).

      WHEN `REPROCESS_CANCEL`.
        popup_detail( ).

      WHEN `REPROCESS_CONFIRM`.
        client->popup_destroy( ).
        reprocess( ).

    ENDCASE.

  ENDMETHOD.


  METHOD search.

    DATA fnames     TYPE RANGE OF zafl_log-fname.
    DATA statuses   TYPE RANGE OF zafl_log-status.
    DATA messages   TYPE RANGE OF zafl_log-message.
    DATA cust1      TYPE RANGE OF zafl_log-cust_field1.
    DATA cust2      TYPE RANGE OF zafl_log-cust_field2.
    DATA cust3      TYPE RANGE OF zafl_log-cust_field3.
    DATA timestamps TYPE RANGE OF zafl_log-timestamp.
    DATA ts_from    TYPE zafl_log-timestamp.
    DATA ts_to      TYPE zafl_log-timestamp.
    DATA date       TYPE d.
    DATA time       TYPE t.
    DATA day_start  TYPE t VALUE '000000'.
    DATA day_end    TYPE t VALUE '235959'.

    range_add( EXPORTING value = to_upper( condense( filter-fname ) ) CHANGING range = fnames ).
    range_add( EXPORTING value = to_upper( condense( filter-status ) ) CHANGING range = statuses ).
    range_add( EXPORTING value = filter-message CHANGING range = messages ).
    range_add( EXPORTING value = filter-cust1 CHANGING range = cust1 ).
    range_add( EXPORTING value = filter-cust2 CHANGING range = cust2 ).
    range_add( EXPORTING value = filter-cust3 CHANGING range = cust3 ).

    " the date range of ZAFL_VIEWER: one date alone is that whole day, in the
    " time zone of the user
    IF filter-date_from IS NOT INITIAL OR filter-date_to IS NOT INITIAL.
      DATA(date_from) = CONV d( COND string( WHEN filter-date_from IS NOT INITIAL THEN filter-date_from ELSE filter-date_to ) ).
      DATA(date_to)   = CONV d( COND string( WHEN filter-date_to IS NOT INITIAL THEN filter-date_to ELSE filter-date_from ) ).
      CONVERT DATE date_from TIME day_start INTO TIME STAMP ts_from TIME ZONE sy-zonlo.
      CONVERT DATE date_to TIME day_end INTO TIME STAMP ts_to TIME ZONE sy-zonlo.
      timestamps = VALUE #( ( sign = `I` option = `BT` low = ts_from high = ts_to ) ).
    ENDIF.

    DATA(max_rows) = COND i( WHEN filter-max_rows > 0 THEN filter-max_rows ELSE 500 ).

    " the list reads the header columns only - the JSON parameters can be
    " large and are read per entry when it is opened
    SELECT guid, fname, cust_field1, cust_field2, cust_field3, status, timestamp, time_cost, uname, message
      FROM zafl_log
      WHERE fname       IN @fnames
        AND status      IN @statuses
        AND message     IN @messages
        AND cust_field1 IN @cust1
        AND cust_field2 IN @cust2
        AND cust_field3 IN @cust3
        AND timestamp   IN @timestamps
      ORDER BY timestamp DESCENDING
      INTO TABLE @DATA(rows)
      UP TO @max_rows ROWS.

    CLEAR t_logs.
    LOOP AT rows INTO DATA(row).
      CONVERT TIME STAMP row-timestamp TIME ZONE sy-zonlo INTO DATE date TIME time.
      INSERT VALUE #( guid         = |{ row-guid }|
                      date         = |{ date DATE = ISO }|
                      time         = |{ time TIME = ISO }|
                      fname        = row-fname
                      uname        = row-uname
                      status       = row-status
                      status_state = status_state( row-status )
                      message      = row-message
                      cust1        = row-cust_field1
                      cust2        = row-cust_field2
                      cust3        = row-cust_field3
                      runtime_ms   = row-time_cost * 1000 )
             INTO TABLE t_logs.
    ENDLOOP.

    result_title = COND #( WHEN lines( t_logs ) >= max_rows
                           THEN |{ lines( t_logs ) } logged calls (the newest - raise max. hits for more)|
                           ELSE |{ lines( t_logs ) } logged calls, newest first| ).

    labels_update( ).
    overview_update( ).

  ENDMETHOD.


  METHOD overview_update.

    TYPES:
      BEGIN OF ty_s_sum,
        fname      TYPE string,
        calls      TYPE i,
        errors     TYPE i,
        runtime_ms TYPE p LENGTH 16 DECIMALS 1,
        last       TYPE string,
      END OF ty_s_sum.
    DATA sums TYPE SORTED TABLE OF ty_s_sum WITH UNIQUE KEY fname.

    " t_logs is sorted newest first, so the first entry of a function module
    " is its last call
    LOOP AT t_logs INTO DATA(log).
      READ TABLE sums WITH TABLE KEY fname = log-fname ASSIGNING FIELD-SYMBOL(<sum>).
      IF sy-subrc <> 0.
        INSERT VALUE #( fname = log-fname last = |{ log-date } { log-time }| ) INTO TABLE sums ASSIGNING <sum>.
      ENDIF.
      <sum>-calls      = <sum>-calls + 1.
      <sum>-runtime_ms = <sum>-runtime_ms + log-runtime_ms.
      IF log-status_state = `Error`.
        <sum>-errors = <sum>-errors + 1.
      ENDIF.
    ENDLOOP.

    CLEAR t_overview.
    LOOP AT sums INTO DATA(sum).
      INSERT VALUE #( fname        = sum-fname
                      calls        = sum-calls
                      share        = 100 * CONV decfloat34( sum-calls ) / lines( t_logs )
                      errors       = sum-errors
                      errors_state = COND #( WHEN sum-errors > 0 THEN `Error` ELSE `None` )
                      avg_ms       = sum-runtime_ms / sum-calls
                      last_call    = sum-last )
             INTO TABLE t_overview ASSIGNING FIELD-SYMBOL(<overview>).
      <overview>-share_text = |{ <overview>-share } %|.
    ENDLOOP.
    SORT t_overview BY calls DESCENDING fname.

    overview_title = |{ lines( t_overview ) } function modules in the { lines( t_logs ) } hits - select one to filter the calls|.

  ENDMETHOD.


  METHOD labels_update.

    " ZAFL_CONFIG names the three custom fields per function module - taken
    " from the filter, or, as in the report, from the hits when they all
    " belong to one function module
    DATA(fname) = to_upper( condense( filter-fname ) ).
    IF ( fname IS INITIAL OR fname CA `*+` ) AND t_logs IS NOT INITIAL
        AND zcl_afl_utilities=>get_distinct_count( tab_data = t_logs field_name = `FNAME` ) = 1.
      fname = t_logs[ 1 ]-fname.
    ENDIF.
    CLEAR labels.
    IF fname IS NOT INITIAL AND fname NA `*+`.
      SELECT SINGLE cust_name1, cust_name2, cust_name3
        FROM zafl_config
        WHERE fname = @fname
        INTO @DATA(config).
      IF sy-subrc = 0.
        labels = VALUE #( cust1 = config-cust_name1
                          cust2 = config-cust_name2
                          cust3 = config-cust_name3 ).
      ENDIF.
    ENDIF.
    labels = VALUE #( cust1 = COND #( WHEN labels-cust1 IS INITIAL THEN `Custom field 1` ELSE labels-cust1 )
                      cust2 = COND #( WHEN labels-cust2 IS INITIAL THEN `Custom field 2` ELSE labels-cust2 )
                      cust3 = COND #( WHEN labels-cust3 IS INITIAL THEN `Custom field 3` ELSE labels-cust3 ) ).

  ENDMETHOD.


  METHOD detail_load.

    DATA date TYPE d.
    DATA time TYPE t.

    CLEAR: detail, detail_guid, detail_fname.
    SELECT SINGLE * FROM zafl_log
      WHERE guid = @guid
      INTO @DATA(log).
    IF sy-subrc <> 0.
      client->message_box_display( text = `The log entry no longer exists.` type = `error` ).
      RETURN.
    ENDIF.

    detail_guid  = log-guid.
    detail_fname = log-fname.
    CONVERT TIME STAMP log-timestamp TIME ZONE sy-zonlo INTO DATE date TIME time.
    detail = VALUE #(
        title              = |{ log-fname } - { date DATE = ISO } { time TIME = ISO } - { log-uname }|
        import             = json_pretty( log-import )
        export             = json_pretty( log-export )
        change_in          = json_pretty( log-change_in )
        change_out         = json_pretty( log-change_out )
        table_in           = json_pretty( log-table_in )
        table_out          = json_pretty( log-table_out )
        import_visible     = xsdbool( log-import IS NOT INITIAL )
        export_visible     = xsdbool( log-export IS NOT INITIAL )
        change_in_visible  = xsdbool( log-change_in IS NOT INITIAL )
        change_out_visible = xsdbool( log-change_out IS NOT INITIAL )
        table_in_visible   = xsdbool( log-table_in IS NOT INITIAL )
        table_out_visible  = xsdbool( log-table_out IS NOT INITIAL ) ).
    detail-nothing_logged = xsdbool( detail-import_visible = abap_false AND detail-export_visible = abap_false
                                     AND detail-change_in_visible = abap_false AND detail-change_out_visible = abap_false
                                     AND detail-table_in_visible = abap_false AND detail-table_out_visible = abap_false ).
    detail-tab = COND #( WHEN detail-import_visible = abap_true THEN `IMPORT`
                         WHEN detail-table_in_visible = abap_true THEN `TABLE_IN`
                         WHEN detail-change_in_visible = abap_true THEN `CHANGE_IN`
                         WHEN detail-export_visible = abap_true THEN `EXPORT`
                         WHEN detail-table_out_visible = abap_true THEN `TABLE_OUT`
                         ELSE `CHANGE_OUT` ).

  ENDMETHOD.


  METHOD reprocess.

    IF reprocess_enabled = abap_false OR detail_guid IS INITIAL.
      RETURN.
    ENDIF.

    " the check of ZAFL_VIEWER: S_DEVELOP test right on the function group,
    " unless ZAFL_CONFIG-NO_AUTH_CHECK is set for the function module
    IF zcl_afl_utilities=>fm_authority_check( detail_fname ) = abap_false.
      client->message_box_display( text = |You are not authorized to test function module { detail_fname }.|
                                   type = `error` ).
      RETURN.
    ENDIF.

    TRY.
        zcl_afl_utilities=>re_process( detail_guid ).
      CATCH cx_root INTO DATA(error).
        client->message_box_display( error ).
        RETURN.
    ENDTRY.

    client->message_toast_display( |{ detail_fname } reprocessed - its new call is logged if logging is on for it| ).
    search( ).

  ENDMETHOD.


  METHOD model_init.

    " the last seven days
    DATA(week_ago) = sy-datum.
    week_ago = week_ago - 7.

    tab              = `LOGS`.
    filter-max_rows  = 500.
    filter-date_from = |{ week_ago }|.
    filter-date_to   = |{ sy-datum }|.

    " the function modules the logger is configured for
    SELECT fname FROM zafl_config
      ORDER BY fname
      INTO TABLE @DATA(configured).
    t_fnames = VALUE #( FOR config IN configured ( key = config-fname text = config-fname ) ).

    labels_update( ).
    search( ).

  ENDMETHOD.


  METHOD range_add.

    IF value IS INITIAL.
      RETURN.
    ENDIF.

    APPEND INITIAL LINE TO range ASSIGNING FIELD-SYMBOL(<line>).
    ASSIGN COMPONENT `SIGN` OF STRUCTURE <line> TO FIELD-SYMBOL(<sign>).
    <sign> = `I`.
    ASSIGN COMPONENT `OPTION` OF STRUCTURE <line> TO FIELD-SYMBOL(<option>).
    <option> = COND string( WHEN value CA `*+` THEN `CP` ELSE `EQ` ).
    ASSIGN COMPONENT `LOW` OF STRUCTURE <line> TO FIELD-SYMBOL(<low>).
    <low> = value.

  ENDMETHOD.


  METHOD status_state.

    " the status code is free (/afl/set_status) - the usual message types
    " get their colour
    result = COND #( WHEN status IS INITIAL   THEN `None`
                     WHEN status(1) CA `EAX` THEN `Error`
                     WHEN status(1) = `W`    THEN `Warning`
                     WHEN status(1) = `S`    THEN `Success`
                     ELSE                         `Information` ).

  ENDMETHOD.


  METHOD json_pretty.

    " the logger stores compact JSON (/ui2/cl_json=>serialize) - indent it
    " by two per level, outside string literals only
    DATA in_string TYPE abap_bool.
    DATA escaped   TYPE abap_bool.
    DATA skip      TYPE abap_bool.
    DATA indent    TYPE i.

    DATA(length) = strlen( json ).
    IF length = 0 OR length > 2000000.
      result = json.
      RETURN.
    ENDIF.

    DO length TIMES.
      DATA(ix) = sy-index - 1.
      IF skip = abap_true.
        skip = abap_false.
        CONTINUE.
      ENDIF.
      DATA(char) = substring( val = json off = ix len = 1 ).

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

      DATA(next) = COND string( WHEN ix + 1 < length THEN substring( val = json off = ix + 1 len = 1 ) ).
      CASE char.
        WHEN `"`.
          in_string = abap_true.
          result = result && char.
        WHEN `{` OR `[`.
          IF next = `}` OR next = `]`.
            result = result && char && next.
            skip = abap_true.
          ELSE.
            indent = indent + 1.
            result = |{ result }{ char }\n{ repeat( val = `  ` occ = indent ) }|.
          ENDIF.
        WHEN `}` OR `]`.
          indent = nmax( val1 = 0 val2 = indent - 1 ).
          result = |{ result }\n{ repeat( val = `  ` occ = indent ) }{ char }|.
        WHEN `,`.
          result = |{ result },\n{ repeat( val = `  ` occ = indent ) }|.
        WHEN `:`.
          result = result && `: `.
        WHEN ` ` OR |\t| OR |\n| OR |\r|.
        WHEN OTHERS.
          result = result && char.
      ENDCASE.
    ENDDO.

  ENDMETHOD.

ENDCLASS.
