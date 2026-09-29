"! <p class="shorttext">abap2xlsx Excel workbench with abap2UI5</p>
"!
"! An Excel workbench on top of https://github.com/abap2xlsx/abap2xlsx.
"! Export: 50 generated flight bookings, and every option of the panel is
"! one abap2xlsx call - an Excel table with a style and a totals row, or a
"! plain range with an autofilter, frozen panes, a data bar and a cell-is
"! rule on the amount, a dropdown validation and a summary sheet with a bar
"! chart. zcl_excel_writer_2007 writes the file, and the code panel shows
"! the exact calls that built it. Import: zcl_excel_reader_2007 reads an
"! uploaded .xlsx back, sheet by sheet, and zcl_excel_common converts the
"! serial numbers of a date column into ABAP dates.
"!
"! The data is generated in ABAP, nothing is read from or written to the
"! database. An upload is only parsed in memory, and only its first 200
"! rows and 26 columns per sheet are kept. abap2xlsx is Standard ABAP, not
"! ABAP Cloud.
CLASS z2ui5_cl_osl_abap2xlsx DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_key_text,
        key  TYPE string,
        text TYPE string,
      END OF ty_s_key_text.
    TYPES ty_t_key_text TYPE STANDARD TABLE OF ty_s_key_text WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_booking,
        bookid       TYPE i,
        carrid       TYPE c LENGTH 3,
        connid       TYPE n LENGTH 4,
        fldate       TYPE d,
        passname     TYPE c LENGTH 25,
        class        TYPE c LENGTH 1,
        amount       TYPE p LENGTH 8 DECIMALS 2,
        fldate_text  TYPE string,
        amount_state TYPE string,
      END OF ty_s_booking.
    TYPES ty_t_booking TYPE STANDARD TABLE OF ty_s_booking WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_options,
        as_table           TYPE abap_bool,
        table_style        TYPE string,
        totals             TYPE abap_bool,
        autofilter         TYPE abap_bool,
        autofilter_enabled TYPE abap_bool,
        freeze             TYPE string,
        databar            TYPE abap_bool,
        highlight          TYPE abap_bool,
        threshold          TYPE i,
        validation         TYPE abap_bool,
        chart              TYPE abap_bool,
      END OF ty_s_options.

    TYPES:
      BEGIN OF ty_s_import,
        file        TYPE string,
        sheet       TYPE string,
        header      TYPE abap_bool,
        date_column TYPE string,
        info        TYPE string,
        loaded      TYPE abap_bool,
      END OF ty_s_import.

    " one row of the imported sheet - the field is the column letter
    TYPES:
      BEGIN OF ty_s_row,
        a TYPE string,
        b TYPE string,
        c TYPE string,
        d TYPE string,
        e TYPE string,
        f TYPE string,
        g TYPE string,
        h TYPE string,
        i TYPE string,
        j TYPE string,
        k TYPE string,
        l TYPE string,
        m TYPE string,
        n TYPE string,
        o TYPE string,
        p TYPE string,
        q TYPE string,
        r TYPE string,
        s TYPE string,
        t TYPE string,
        u TYPE string,
        v TYPE string,
        w TYPE string,
        x TYPE string,
        y TYPE string,
        z TYPE string,
      END OF ty_s_row.
    TYPES ty_t_row TYPE STANDARD TABLE OF ty_s_row WITH EMPTY KEY.

    DATA tab            TYPE string.

    DATA opt            TYPE ty_s_options.
    DATA t_table_styles TYPE ty_t_key_text.
    DATA t_freeze       TYPE ty_t_key_text.
    DATA t_bookings     TYPE ty_t_booking.
    DATA code           TYPE string.
    DATA build_info     TYPE string.

    DATA upload_value   TYPE string.
    DATA upload_path    TYPE string.
    DATA imp            TYPE ty_s_import.
    DATA t_sheets       TYPE ty_t_key_text.
    DATA t_date_columns TYPE ty_t_key_text.
    DATA t_rows         TYPE ty_t_row.

  PROTECTED SECTION.
    TYPES:
      BEGIN OF ty_s_cell,
        sheet   TYPE string,
        row     TYPE i,
        column  TYPE i,
        value   TYPE string,
        is_date TYPE abap_bool,
      END OF ty_s_cell.
    TYPES ty_t_cell TYPE STANDARD TABLE OF ty_s_cell WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_column,
        index  TYPE i,
        letter TYPE string,
        header TYPE string,
      END OF ty_s_column.
    TYPES ty_t_column TYPE STANDARD TABLE OF ty_s_column WITH EMPTY KEY.

    CONSTANTS c_letters     TYPE string VALUE `ABCDEFGHIJKLMNOPQRSTUVWXYZ`.
    CONSTANTS c_max_rows    TYPE i VALUE 200.
    CONSTANTS c_max_columns TYPE i VALUE 26.

    DATA client     TYPE REF TO z2ui5_if_client.
    DATA seed       TYPE p LENGTH 16 DECIMALS 0.
    DATA code_lines TYPE string_table.
    DATA cells      TYPE ty_t_cell.
    DATA columns    TYPE ty_t_column.

    METHODS view_display.
    METHODS view_export
      IMPORTING
        items TYPE REF TO z2ui5_cl_ui5_view_builder.
    METHODS view_options
      IMPORTING
        parent TYPE REF TO z2ui5_cl_ui5_view_builder.
    METHODS view_bookings
      IMPORTING
        parent TYPE REF TO z2ui5_cl_ui5_view_builder.
    METHODS view_import
      IMPORTING
        items TYPE REF TO z2ui5_cl_ui5_view_builder.

    METHODS on_event.
    METHODS options_update
      RAISING
        zcx_excel.
    METHODS xlsx_write
      RETURNING
        VALUE(result) TYPE xstring
      RAISING
        zcx_excel.
    METHODS xlsx_build
      RETURNING
        VALUE(result) TYPE REF TO zcl_excel
      RAISING
        zcx_excel.
    METHODS xlsx_summary
      IMPORTING
        excel TYPE REF TO zcl_excel
      RAISING
        zcx_excel.
    METHODS import_load
      IMPORTING
        xdata TYPE xstring
      RAISING
        zcx_excel.
    METHODS import_sheet
      IMPORTING
        detect TYPE abap_bool DEFAULT abap_false.
    METHODS bookings_generate.
    METHODS model_init.

    METHODS code_add
      IMPORTING
        line TYPE string.
    METHODS random
      IMPORTING
        low           TYPE i
        high          TYPE i
      RETURNING
        VALUE(result) TYPE i.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_osl_abap2xlsx IMPLEMENTATION.

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
            )->a( n = `xmlns:form`   v = `sap.ui.layout.form`
            )->a( n = `xmlns:editor` v = `sap.ui.codeeditor`
            )->a( n = `xmlns:z2ui5`  v = `z2ui5.cc`
            )->ele( `Shell`
                )->a( n = `appWidthLimited` v = `false`
                )->ele( `Page`
                    )->a( n = `title`          v = `Excel workbench - abap2xlsx x abap2UI5`
                    )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
                    )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    page->ele( `headerContent`
        )->tag( `Link`
            )->a( n = `text`   v = `abap2xlsx/abap2xlsx`
            )->a( n = `href`   v = `https://github.com/abap2xlsx/abap2xlsx`
            )->a( n = `target` v = `_blank` ).

    DATA(items) = page->ele( `content`
        )->ele( `IconTabBar`
            )->a( n = `selectedKey` v = client->_bind( tab )
            )->a( n = `expandable`  v = `false`
            )->a( n = `class`       v = `sapUiResponsiveContentPadding`
            )->ele( `items` ).

    view_export( items ).
    view_import( items ).

    client->view_display( page->stringify( ) ).

  ENDMETHOD.


  METHOD view_export.

    DATA(content) = items->ele( `IconTabFilter`
        )->a( n = `key`  v = `EXPORT`
        )->a( n = `text` v = `Export`
        )->a( n = `icon` v = `sap-icon://excel-attachment`
        )->ele( `content` ).

    content->ele( `OverflowToolbar`
        )->a( n = `style` v = `Clear`
        )->ele( `content`
            )->tag( `Button`
                )->a( n = `text`  v = `Download bookings.xlsx`
                )->a( n = `icon`  v = `sap-icon://download`
                )->a( n = `type`  v = `Emphasized`
                )->a( n = `press` v = client->_event( `DOWNLOAD` )
            )->tag( `Button`
                )->a( n = `text`  v = `New random data`
                )->a( n = `icon`  v = `sap-icon://refresh`
                )->a( n = `type`  v = `Transparent`
                )->a( n = `press` v = client->_event( `REGENERATE` )
            )->tag( `ToolbarSpacer`
            )->tag( `Text`
                )->a( n = `text` v = client->_bind( build_info ) ).

    DATA(grid) = content->ele( n = `Grid` ns = `l`
        )->a( n = `defaultSpan` v = `XL5 L5 M12 S12`
        )->a( n = `class`       v = `sapUiSmallMarginTop` ).

    view_options( grid ).

    grid->ele( `VBox`
        )->ele( `layoutData`
            )->tag( n = `GridData` ns = `l`
                )->a( n = `span` v = `XL7 L7 M12 S12`
        )->end(
        )->tag( `Title`
            )->a( n = `text`  v = `The abap2xlsx calls these options make`
            )->a( n = `level` v = `H4`
        )->tag( n = `CodeEditor` ns = `editor`
            )->a( n = `value`       v = client->_bind( code )
            )->a( n = `type`        v = `abap`
            )->a( n = `editable`    v = `false`
            )->a( n = `lineNumbers` v = `true`
            )->a( n = `height`      v = `620px` ).

    view_bookings( content ).

  ENDMETHOD.


  METHOD view_options.

    parent->ele( n = `SimpleForm` ns = `form`
        )->a( n = `title`    v = `Workbook options`
        )->a( n = `editable` v = `true`
        )->a( n = `layout`   v = `ResponsiveGridLayout`
        )->ele( n = `content` ns = `form`
            )->tag( `Label`
                )->a( n = `text` v = `Excel table`
            )->tag( `CheckBox`
                )->a( n = `text`     v = `bind_table( ) - a styled table with filter buttons`
                )->a( n = `selected` v = client->_bind( opt-as_table )
                )->a( n = `select`   v = client->_event( `OPTIONS` )
            )->tag( `Label`
                )->a( n = `text` v = `Table style`
            )->ele( `Select`
                )->a( n = `selectedKey` v = client->_bind( opt-table_style )
                )->a( n = `items`       v = client->_bind( t_table_styles )
                )->a( n = `enabled`     v = client->_bind( opt-as_table )
                )->a( n = `change`      v = client->_event( `OPTIONS` )
                )->tag( n = `Item` ns = `core`
                    )->a( n = `key`  v = `{KEY}`
                    )->a( n = `text` v = `{TEXT}`
            )->end(
            )->tag( `Label`
                )->a( n = `text` v = `Totals row`
            )->tag( `CheckBox`
                )->a( n = `text`     v = `totals_function = sum on the amount`
                )->a( n = `selected` v = client->_bind( opt-totals )
                )->a( n = `enabled`  v = client->_bind( opt-as_table )
                )->a( n = `select`   v = client->_event( `OPTIONS` )
            )->tag( `Label`
                )->a( n = `text` v = `Autofilter`
            )->tag( `CheckBox`
                )->a( n = `text`     v = `add_new_autofilter( ) - plain range only`
                )->a( n = `selected` v = client->_bind( opt-autofilter )
                )->a( n = `enabled`  v = client->_bind( opt-autofilter_enabled )
                )->a( n = `select`   v = client->_event( `OPTIONS` )
            )->tag( `Label`
                )->a( n = `text` v = `Freeze panes`
            )->ele( `Select`
                )->a( n = `selectedKey` v = client->_bind( opt-freeze )
                )->a( n = `items`       v = client->_bind( t_freeze )
                )->a( n = `change`      v = client->_event( `OPTIONS` )
                )->tag( n = `Item` ns = `core`
                    )->a( n = `key`  v = `{KEY}`
                    )->a( n = `text` v = `{TEXT}`
            )->end(
            )->tag( `Label`
                )->a( n = `text` v = `Data bar`
            )->tag( `CheckBox`
                )->a( n = `text`     v = `Conditional format dataBar on the amount`
                )->a( n = `selected` v = client->_bind( opt-databar )
                )->a( n = `select`   v = client->_event( `OPTIONS` )
            )->tag( `Label`
                )->a( n = `text` v = `Highlight`
            )->tag( `CheckBox`
                )->a( n = `text`     v = `Conditional format cellIs, amount greater than`
                )->a( n = `selected` v = client->_bind( opt-highlight )
                )->a( n = `select`   v = client->_event( `OPTIONS` )
            )->tag( `StepInput`
                )->a( n = `value`   v = client->_bind( opt-threshold )
                )->a( n = `min`     v = `0`
                )->a( n = `max`     v = `10000`
                )->a( n = `step`    v = `250`
                )->a( n = `enabled` v = client->_bind( opt-highlight )
                )->a( n = `change`  v = client->_event( `OPTIONS` )
            )->tag( `Label`
                )->a( n = `text` v = `Dropdown`
            )->tag( `CheckBox`
                )->a( n = `text`     v = `Data validation list Y, C, F on the class`
                )->a( n = `selected` v = client->_bind( opt-validation )
                )->a( n = `select`   v = client->_event( `OPTIONS` )
            )->tag( `Label`
                )->a( n = `text` v = `Chart`
            )->tag( `CheckBox`
                )->a( n = `text`     v = `Summary sheet with a bar chart per carrier`
                )->a( n = `selected` v = client->_bind( opt-chart )
                )->a( n = `select`   v = client->_event( `OPTIONS` ) ).

  ENDMETHOD.


  METHOD view_bookings.

    DATA(table) = parent->ele( `Table`
        )->a( n = `items`            v = client->_bind( t_bookings )
        )->a( n = `growing`          v = `true`
        )->a( n = `growingThreshold` v = `10`
        )->a( n = `class`            v = `sapUiSmallMarginTop` ).

    table->ele( `headerToolbar`
        )->ele( `OverflowToolbar`
            )->tag( `Title`
                )->a( n = `text`  v = `Sheet Bookings - the rows the workbook is built from`
                )->a( n = `level` v = `H4` ).

    " header is the default aggregation of sap.m.Column
    table->ele( `columns`
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Booking`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Carrier`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Flight`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Date`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Passenger`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Class`
        )->end(
        )->ele( `Column`
            )->a( n = `hAlign` v = `End`
            )->tag( `Text`
                )->a( n = `text` v = `Amount` ).

    table->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells`
                )->tag( `Text`
                    )->a( n = `text` v = `{BOOKID}`
                )->tag( `Text`
                    )->a( n = `text` v = `{CARRID}`
                )->tag( `Text`
                    )->a( n = `text` v = `{CONNID}`
                )->tag( `Text`
                    )->a( n = `text` v = `{FLDATE_TEXT}`
                )->tag( `Text`
                    )->a( n = `text` v = `{PASSNAME}`
                )->tag( `Text`
                    )->a( n = `text` v = `{CLASS}`
                )->tag( `ObjectNumber`
                    )->a( n = `number` v = `{AMOUNT}`
                    )->a( n = `unit`   v = `EUR`
                    )->a( n = `state`  v = `{AMOUNT_STATE}` ).

  ENDMETHOD.


  METHOD view_import.

    DATA(content) = items->ele( `IconTabFilter`
        )->a( n = `key`  v = `IMPORT`
        )->a( n = `text` v = `Import`
        )->a( n = `icon` v = `sap-icon://upload`
        )->ele( `content` ).

    content->ele( `OverflowToolbar`
        )->a( n = `style` v = `Clear`
        )->ele( `content`
            )->tag( n = `FileUploader` ns = `z2ui5`
                )->a( n = `value`             v = client->_bind( upload_value )
                )->a( n = `path`              v = client->_bind( upload_path )
                )->a( n = `placeholder`       v = `Choose an .xlsx file`
                )->a( n = `fileType`          v = `xlsx`
                )->a( n = `checkDirectUpload` v = `true`
                )->a( n = `upload`            v = client->_event( `UPLOAD` )
            )->tag( `Button`
                )->a( n = `text`  v = `Or read the Export workbook`
                )->a( n = `icon`  v = `sap-icon://synchronize`
                )->a( n = `press` v = client->_event( `ROUNDTRIP` ) ).

    content->ele( `OverflowToolbar`
        )->a( n = `style`   v = `Clear`
        )->a( n = `visible` v = client->_bind( imp-loaded )
        )->ele( `content`
            )->tag( `Label`
                )->a( n = `text` v = `Sheet`
            )->ele( `Select`
                )->a( n = `selectedKey` v = client->_bind( imp-sheet )
                )->a( n = `items`       v = client->_bind( t_sheets )
                )->a( n = `change`      v = client->_event( `SHEET` )
                )->tag( n = `Item` ns = `core`
                    )->a( n = `key`  v = `{KEY}`
                    )->a( n = `text` v = `{TEXT}`
            )->end(
            )->tag( `Label`
                )->a( n = `text` v = `First row is header`
            )->tag( `Switch`
                )->a( n = `state`  v = client->_bind( imp-header )
                )->a( n = `change` v = client->_event( `HEADER` )
            )->tag( `Label`
                )->a( n = `text` v = `Date column`
            )->ele( `Select`
                )->a( n = `selectedKey` v = client->_bind( imp-date_column )
                )->a( n = `items`       v = client->_bind( t_date_columns )
                )->a( n = `change`      v = client->_event( `DATE_COLUMN` )
                )->tag( n = `Item` ns = `core`
                    )->a( n = `key`  v = `{KEY}`
                    )->a( n = `text` v = `{TEXT}` ).

    content->tag( `MessageStrip`
        )->a( n = `text`     v = client->_bind( imp-info )
        )->a( n = `type`     v = `Information`
        )->a( n = `showIcon` v = `true`
        )->a( n = `class`    v = `sapUiSmallMarginTop` ).

    DATA(table) = content->ele( `Table`
        )->a( n = `items`            v = client->_bind( t_rows )
        )->a( n = `visible`          v = client->_bind( imp-loaded )
        )->a( n = `growing`          v = `true`
        )->a( n = `growingThreshold` v = `50`
        )->a( n = `class`            v = `sapUiSmallMarginTop` ).

    " the columns are the ones the sheet uses, so this part of the view is
    " rebuilt whenever another sheet is chosen - the header text comes from
    " the file and goes through t, which escapes it as a literal
    DATA(column_list) = table->ele( `columns` ).
    LOOP AT columns INTO DATA(column).
      column_list->ele( `Column`
          )->tag( `Text`
              )->a( n = `text` t = column-header ).
    ENDLOOP.

    DATA(cell_list) = table->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells` ).
    LOOP AT columns INTO column.
      cell_list->tag( `Text`
          )->a( n = `text` v = |\{{ column-letter }\}| ).
    ENDLOOP.

  ENDMETHOD.


  METHOD on_event.

    " abap2xlsx raises the static zcx_excel (a file that is no xlsx, a
    " range it cannot place, ...) - shown, not dumped
    TRY.
        CASE client->get_event( ).

          WHEN `OPTIONS`.
            options_update( ).

          WHEN `REGENERATE`.
            bookings_generate( ).
            options_update( ).
            client->message_toast_display( |New random dataset: { lines( t_bookings ) } bookings| ).

          WHEN `DOWNLOAD`.
            DATA(file) = xlsx_write( ).
            client->follow_up_action(
                val   = client->cs_event-download_b64_file
                t_arg = VALUE #( ( |data:application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;base64,| &&
                                   cl_web_http_utility=>encode_x_base64( file ) )
                                 ( `bookings.xlsx` ) ) ).

          WHEN `UPLOAD`.
            " the uploader hands over a data URL - the payload follows the comma
            DATA(base64) = substring_after( val = upload_value sub = `,` ).
            imp-file = upload_path.
            CLEAR upload_value.
            import_load( cl_web_http_utility=>decode_x_base64( base64 ) ).
            view_display( ).

          WHEN `ROUNDTRIP`.
            imp-file = `bookings.xlsx, as the Export tab builds it`.
            import_load( xlsx_write( ) ).
            view_display( ).

          WHEN `SHEET`.
            import_sheet( detect = abap_true ).
            view_display( ).

          WHEN `HEADER` OR `DATE_COLUMN`.
            import_sheet( ).
            view_display( ).

        ENDCASE.
      CATCH zcx_excel INTO DATA(error).
        client->message_box_display( error ).
    ENDTRY.

  ENDMETHOD.


  METHOD options_update.

    " an Excel table carries its own filter buttons - a sheet autofilter
    " over it would make a file Excel has to repair
    opt-autofilter_enabled = xsdbool( opt-as_table = abap_false ).
    LOOP AT t_bookings ASSIGNING FIELD-SYMBOL(<booking>).
      <booking>-amount_state = COND #( WHEN opt-highlight = abap_true AND <booking>-amount > opt-threshold
                                       THEN `Error`
                                       ELSE `None` ).
    ENDLOOP.

    " building and writing the workbook refreshes the code panel and the
    " size - 50 rows take no time
    xlsx_write( ).

  ENDMETHOD.


  METHOD xlsx_write.

    DATA(excel) = xlsx_build( ).
    DATA(writer) = CAST zif_excel_writer( NEW zcl_excel_writer_2007( ) ).
    result = writer->write_file( excel ).

    code_add( `` ).
    code_add( `DATA(writer) = CAST zif_excel_writer( NEW zcl_excel_writer_2007( ) ).` ).
    code_add( `DATA(file) = writer->write_file( excel ).` ).
    code = concat_lines_of( table = code_lines
                            sep   = |\n| ).

    build_info = |{ excel->get_worksheets_size( ) } sheet(s), { lines( t_bookings ) } bookings, | &&
                 |{ xstrlen( result ) } bytes by zcl_excel_writer_2007|.

  ENDMETHOD.


  METHOD xlsx_build.

    " every call on the workbook is echoed into the code panel - the panel
    " shows what builds the file, not a description of it
    CLEAR code_lines.
    DATA(last_row) = lines( t_bookings ) + 1.

    result = NEW #( ).
    DATA(sheet) = result->get_active_worksheet( ).
    sheet->set_title( `Bookings` ).
    code_add( `DATA(excel) = NEW zcl_excel( ).` ).
    code_add( `DATA(sheet) = excel->get_active_worksheet( ).` ).
    code_add( |sheet->set_title( `Bookings` ).| ).

    " the field catalog names the columns and hides the two UI-only fields
    DATA(fieldcatalog) = zcl_excel_common=>get_fieldcatalog( t_bookings ).
    LOOP AT fieldcatalog ASSIGNING FIELD-SYMBOL(<field>).
      <field>-column_name = SWITCH #( <field>-fieldname
        WHEN `BOOKID`   THEN `Booking`
        WHEN `CARRID`   THEN `Carrier`
        WHEN `CONNID`   THEN `Flight`
        WHEN `FLDATE`   THEN `Date`
        WHEN `PASSNAME` THEN `Passenger`
        WHEN `CLASS`    THEN `Class`
        WHEN `AMOUNT`   THEN `Amount (EUR)` ).
      <field>-dynpfld = xsdbool( <field>-column_name IS NOT INITIAL ).
      IF <field>-fieldname = `AMOUNT` AND opt-as_table = abap_true AND opt-totals = abap_true.
        <field>-totals_function = zcl_excel_table=>totals_function_sum.
      ENDIF.
    ENDLOOP.
    code_add( `` ).
    code_add( `DATA(fieldcatalog) = zcl_excel_common=>get_fieldcatalog( bookings ).` ).
    code_add( `" per field: column_name = the header, dynpfld = abap_false hides it` ).
    IF opt-as_table = abap_true AND opt-totals = abap_true.
      code_add( |fieldcatalog[ fieldname = `AMOUNT` ]-totals_function = zcl_excel_table=>totals_function_sum.| ).
    ENDIF.

    code_add( `` ).
    IF opt-as_table = abap_true.
      sheet->bind_table( ip_table          = t_bookings
                         it_field_catalog  = fieldcatalog
                         is_table_settings = VALUE #( table_style = opt-table_style ) ).
      code_add( `sheet->bind_table( ip_table          = bookings` ).
      code_add( `                   it_field_catalog  = fieldcatalog` ).
      DATA(style_name) = to_lower( substring_after( val = opt-table_style sub = `TableStyle` ) ).
      code_add( |                   is_table_settings = VALUE #( table_style = zcl_excel_table=>builtinstyle_{ style_name } ) ).| ).
    ELSE.
      DATA(header_style) = result->add_new_style( ).
      header_style->font->bold        = abap_true.
      header_style->fill->filltype    = zcl_excel_style_fill=>c_fill_solid.
      header_style->fill->fgcolor-rgb = `FFD9E1F2`.
      DATA(header_guid) = header_style->get_guid( ).
      DATA(col_count) = 0.
      LOOP AT fieldcatalog INTO DATA(field) WHERE dynpfld = abap_true.
        col_count = col_count + 1.
        DATA(alpha) = zcl_excel_common=>convert_column2alpha( col_count ).
        sheet->set_cell( ip_column = alpha
                         ip_row    = 1
                         ip_value  = field-column_name
                         ip_style  = header_guid ).
        LOOP AT t_bookings ASSIGNING FIELD-SYMBOL(<booking>).
          DATA(row) = sy-tabix + 1.
          ASSIGN COMPONENT field-fieldname OF STRUCTURE <booking> TO FIELD-SYMBOL(<value>).
          sheet->set_cell( ip_column = alpha
                           ip_row    = row
                           ip_value  = <value> ).
        ENDLOOP.
        sheet->set_column_width( ip_column = alpha ).
      ENDLOOP.
      code_add( `DATA(header) = excel->add_new_style( ).` ).
      code_add( `header->font->bold        = abap_true.` ).
      code_add( `header->fill->filltype    = zcl_excel_style_fill=>c_fill_solid.` ).
      code_add( |header->fill->fgcolor-rgb = `FFD9E1F2`.| ).
      code_add( `" per visible field of the catalog, column by column:` ).
      code_add( `sheet->set_cell( ip_column = alpha ip_row = 1 ip_value = field-column_name` ).
      code_add( `                 ip_style  = header->get_guid( ) ).` ).
      code_add( `sheet->set_cell( ip_column = alpha ip_row = row ip_value = <value> ). " each booking` ).
      code_add( `sheet->set_column_width( ip_column = alpha ). " autosize` ).
      IF opt-autofilter = abap_true.
        result->add_new_autofilter( sheet )->set_filter_area( VALUE #( row_start = 1
                                                                       col_start = 1
                                                                       row_end   = last_row
                                                                       col_end   = col_count ) ).
        code_add( `` ).
        code_add( `excel->add_new_autofilter( sheet )->set_filter_area(` ).
        code_add( |    VALUE #( row_start = 1 col_start = 1 row_end = { last_row } col_end = { col_count } ) ).| ).
      ENDIF.
    ENDIF.

    CASE opt-freeze.
      WHEN `ROW`.
        sheet->freeze_panes( ip_num_rows = 1 ).
        code_add( `` ).
        code_add( `sheet->freeze_panes( ip_num_rows = 1 ).` ).
      WHEN `ROW_COLUMN`.
        sheet->freeze_panes( ip_num_rows = 1 ip_num_columns = 1 ).
        code_add( `` ).
        code_add( `sheet->freeze_panes( ip_num_rows = 1 ip_num_columns = 1 ).` ).
    ENDCASE.

    " the amount is column G, the class column F - the order of the catalog
    IF opt-databar = abap_true.
      DATA(databar) = sheet->add_new_style_cond( ).
      databar->rule         = zcl_excel_style_cond=>c_rule_databar.
      databar->priority     = 1.
      databar->mode_databar = VALUE #( cfvo1_type  = zcl_excel_style_cond=>c_cfvo_type_min
                                       cfvo1_value = `0`
                                       cfvo2_type  = zcl_excel_style_cond=>c_cfvo_type_max
                                       cfvo2_value = `0`
                                       colorrgb    = `FF638EC6` ).
      databar->set_range( ip_start_column = `G`
                          ip_start_row    = 2
                          ip_stop_column  = `G`
                          ip_stop_row     = last_row ).
      code_add( `` ).
      code_add( `DATA(databar) = sheet->add_new_style_cond( ).` ).
      code_add( `databar->rule         = zcl_excel_style_cond=>c_rule_databar.` ).
      code_add( `databar->mode_databar = VALUE #( cfvo1_type = zcl_excel_style_cond=>c_cfvo_type_min` ).
      code_add( `                                 cfvo2_type = zcl_excel_style_cond=>c_cfvo_type_max` ).
      code_add( |                                 colorrgb   = `FF638EC6` ).| ).
      code_add( |databar->set_range( ip_start_column = `G` ip_start_row = 2| ).
      code_add( |                    ip_stop_column  = `G` ip_stop_row  = { last_row } ).| ).
    ENDIF.

    IF opt-highlight = abap_true.
      DATA(alert) = result->add_new_style( ).
      alert->font->color-rgb    = `FF9C0006`.
      alert->fill->filltype     = zcl_excel_style_fill=>c_fill_solid.
      alert->fill->bgcolor-rgb  = `FFFFC7CE`.
      DATA(highlight) = sheet->add_new_style_cond( ).
      highlight->rule        = zcl_excel_style_cond=>c_rule_cellis.
      highlight->priority    = 2.
      highlight->mode_cellis = VALUE #( operator   = zcl_excel_style_cond=>c_operator_greaterthan
                                        formula    = |{ opt-threshold }|
                                        cell_style = alert->get_guid( ) ).
      highlight->set_range( ip_start_column = `G`
                            ip_start_row    = 2
                            ip_stop_column  = `G`
                            ip_stop_row     = last_row ).
      code_add( `` ).
      code_add( `DATA(alert) = excel->add_new_style( ).` ).
      code_add( |alert->font->color-rgb   = `FF9C0006`.| ).
      code_add( `alert->fill->filltype    = zcl_excel_style_fill=>c_fill_solid.` ).
      code_add( |alert->fill->bgcolor-rgb = `FFFFC7CE`.| ).
      code_add( `DATA(highlight) = sheet->add_new_style_cond( ).` ).
      code_add( `highlight->rule        = zcl_excel_style_cond=>c_rule_cellis.` ).
      code_add( `highlight->mode_cellis = VALUE #( operator   = zcl_excel_style_cond=>c_operator_greaterthan` ).
      code_add( |                                  formula    = `{ opt-threshold }`| ).
      code_add( `                                  cell_style = alert->get_guid( ) ).` ).
      code_add( |highlight->set_range( ip_start_column = `G` ip_start_row = 2| ).
      code_add( |                      ip_stop_column  = `G` ip_stop_row  = { last_row } ).| ).
    ENDIF.

    IF opt-validation = abap_true.
      DATA(validation) = sheet->add_new_data_validation( ).
      validation->type           = zcl_excel_data_validation=>c_type_list.
      validation->formula1       = `"Y,C,F"`.
      validation->cell_column    = `F`.
      validation->cell_row       = 2.
      validation->cell_column_to = `F`.
      validation->cell_row_to    = last_row.
      validation->prompttitle    = `Booking class`.
      validation->prompt         = `Y economy, C business, F first`.
      code_add( `` ).
      code_add( `DATA(validation) = sheet->add_new_data_validation( ).` ).
      code_add( `validation->type           = zcl_excel_data_validation=>c_type_list.` ).
      code_add( |validation->formula1       = `"Y,C,F"`.| ).
      code_add( |validation->cell_column    = `F`.| ).
      code_add( `validation->cell_row       = 2.` ).
      code_add( |validation->cell_column_to = `F`.| ).
      code_add( |validation->cell_row_to    = { last_row }.| ).
      code_add( |validation->prompt         = `Y economy, C business, F first`.| ).
    ENDIF.

    IF opt-chart = abap_true.
      xlsx_summary( result ).
    ENDIF.

  ENDMETHOD.


  METHOD xlsx_summary.

    TYPES:
      BEGIN OF ty_s_total,
        carrid TYPE c LENGTH 3,
        amount TYPE p LENGTH 12 DECIMALS 2,
      END OF ty_s_total.
    DATA totals TYPE SORTED TABLE OF ty_s_total WITH UNIQUE KEY carrid.

    LOOP AT t_bookings INTO DATA(booking).
      DATA(total) = VALUE ty_s_total( carrid = booking-carrid
                                      amount = booking-amount ).
      COLLECT total INTO totals.
    ENDLOOP.
    DATA(last_row) = lines( totals ) + 1.

    DATA(summary) = excel->add_new_worksheet( `Summary` ).
    summary->set_cell( ip_columnrow = `A1` ip_value = `Carrier` ).
    summary->set_cell( ip_columnrow = `B1` ip_value = `Amount (EUR)` ).
    LOOP AT totals INTO total.
      DATA(row) = sy-tabix + 1.
      summary->set_cell( ip_column = `A` ip_row = row ip_value = total-carrid ).
      summary->set_cell( ip_column = `B` ip_row = row ip_value = total-amount ).
    ENDLOOP.
    summary->set_cell( ip_column = `A` ip_row = last_row + 1 ip_value = `Total` ).
    summary->set_cell( ip_column = `B` ip_row = last_row + 1 ip_formula = |SUM(B2:B{ last_row })| ).
    summary->set_column_width( ip_column = `B` ).

    DATA(bars) = NEW zcl_excel_graph_bars( ).
    bars->create_serie( ip_order            = 0
                        ip_invertifnegative = zcl_excel_graph_bars=>c_invertifnegative_no
                        ip_lbl              = |Summary!$A$2:$A${ last_row }|
                        ip_ref              = |Summary!$B$2:$B${ last_row }|
                        ip_sername          = `Amount by carrier` ).
    bars->create_ax( ip_type = zcl_excel_graph_bars=>c_catax ).
    bars->create_ax( ip_type = zcl_excel_graph_bars=>c_valax ).
    bars->set_title( `Amount by carrier` ).

    DATA(drawing) = excel->add_new_drawing( ip_type  = zcl_excel_drawing=>type_chart
                                            ip_title = `Amount by carrier` ).
    drawing->graph      = bars.
    drawing->graph_type = zcl_excel_drawing=>c_graph_bars.
    drawing->set_position2( ip_from = VALUE #( col = 3 row = 0 )
                            ip_to   = VALUE #( col = 12 row = 20 ) ).
    drawing->set_media( ip_media_type = zcl_excel_drawing=>c_media_type_xml ).
    summary->add_drawing( drawing ).
    excel->set_active_sheet_index( 1 ).

    code_add( `` ).
    code_add( |DATA(summary) = excel->add_new_worksheet( `Summary` ).| ).
    code_add( |" A2:B{ last_row }: carrier and amount, computed in ABAP, then the total| ).
    code_add( |summary->set_cell( ip_column = `B` ip_row = { last_row + 1 } ip_formula = `SUM(B2:B{ last_row })` ).| ).
    code_add( `DATA(bars) = NEW zcl_excel_graph_bars( ).` ).
    code_add( `bars->create_serie( ip_order            = 0` ).
    code_add( `                    ip_invertifnegative = zcl_excel_graph_bars=>c_invertifnegative_no` ).
    code_add( |                    ip_lbl              = `Summary!$A$2:$A${ last_row }`| ).
    code_add( |                    ip_ref              = `Summary!$B$2:$B${ last_row }`| ).
    code_add( |                    ip_sername          = `Amount by carrier` ).| ).
    code_add( `bars->create_ax( ip_type = zcl_excel_graph_bars=>c_catax ).` ).
    code_add( `bars->create_ax( ip_type = zcl_excel_graph_bars=>c_valax ).` ).
    code_add( `DATA(drawing) = excel->add_new_drawing( ip_type = zcl_excel_drawing=>type_chart ).` ).
    code_add( `drawing->graph      = bars.` ).
    code_add( `drawing->graph_type = zcl_excel_drawing=>c_graph_bars.` ).
    code_add( `drawing->set_position2( ip_from = VALUE #( col = 3 row = 0 )` ).
    code_add( `                        ip_to   = VALUE #( col = 12 row = 20 ) ).` ).
    code_add( `drawing->set_media( ip_media_type = zcl_excel_drawing=>c_media_type_xml ).` ).
    code_add( `summary->add_drawing( drawing ).` ).
    code_add( `excel->set_active_sheet_index( 1 ).` ).

  ENDMETHOD.


  METHOD import_load.

    DATA date_styles TYPE SORTED TABLE OF zexcel_cell_style WITH UNIQUE KEY table_line.

    DATA(reader) = CAST zif_excel_reader( NEW zcl_excel_reader_2007( ) ).
    DATA(excel) = reader->load( xdata ).

    " Excel keeps a date as a serial number (days since 1900) - it is a date
    " only through the number format of its style
    DATA(styles) = excel->get_styles_iterator( ).
    WHILE styles->has_next( ) = abap_true.
      DATA(style) = CAST zcl_excel_style( styles->get_next( ) ).
      IF style->number_format IS BOUND.
        DATA(format) = to_lower( CONV string( style->number_format->format_code ) ).
        IF format CS `yy` OR format CS `dd`.
          DATA(guid) = style->get_guid( ).
          INSERT guid INTO TABLE date_styles.
        ENDIF.
      ENDIF.
    ENDWHILE.

    CLEAR: cells, t_sheets.
    DATA(sheets) = excel->get_worksheets_iterator( ).
    WHILE sheets->has_next( ) = abap_true.
      DATA(sheet) = CAST zcl_excel_worksheet( sheets->get_next( ) ).
      DATA(title) = CONV string( sheet->get_title( ) ).
      INSERT VALUE #( key  = title
                      text = |{ title } - { sheet->get_highest_row( ) } rows, { sheet->get_highest_column( ) } columns| )
             INTO TABLE t_sheets.
      LOOP AT sheet->sheet_content INTO DATA(cell) WHERE cell_row <= c_max_rows AND cell_column <= c_max_columns.
        INSERT VALUE #( sheet   = title
                        row     = cell-cell_row
                        column  = cell-cell_column
                        value   = cell-cell_value
                        is_date = xsdbool( line_exists( date_styles[ table_line = cell-cell_style ] ) ) )
               INTO TABLE cells.
      ENDLOOP.
    ENDWHILE.

    imp-loaded = abap_true.
    imp-sheet  = VALUE #( t_sheets[ 1 ]-key OPTIONAL ).
    import_sheet( detect = abap_true ).

  ENDMETHOD.


  METHOD import_sheet.

    DATA(sheet_cells) = VALUE ty_t_cell( FOR c IN cells WHERE ( sheet = imp-sheet ) ( c ) ).
    DATA(max_row)    = REDUCE i( INIT m = 0 FOR c IN sheet_cells NEXT m = nmax( val1 = m val2 = c-row ) ).
    DATA(max_column) = REDUCE i( INIT m = 0 FOR c IN sheet_cells NEXT m = nmax( val1 = m val2 = c-column ) ).
    DATA(first_row)  = COND i( WHEN imp-header = abap_true THEN 2 ELSE 1 ).

    CLEAR columns.
    DO max_column TIMES.
      DATA(letter) = substring( val = c_letters off = sy-index - 1 len = 1 ).
      DATA(header) = COND string( WHEN imp-header = abap_true
                                  THEN VALUE #( sheet_cells[ row = 1 column = sy-index ]-value OPTIONAL ) ).
      INSERT VALUE #( index  = sy-index
                      letter = letter
                      header = COND #( WHEN header IS INITIAL THEN letter ELSE |{ header } ({ letter })| ) )
             INTO TABLE columns.
    ENDDO.

    " suggest the column with the most date-formatted cells below the header
    IF detect = abap_true.
      CLEAR imp-date_column.
      DATA(best) = 0.
      LOOP AT columns INTO DATA(candidate).
        DATA(dates) = REDUCE i( INIT n = 0
                                FOR c IN sheet_cells WHERE ( column = candidate-index AND is_date = abap_true )
                                NEXT n = n + 1 ).
        IF dates > best.
          best = dates.
          imp-date_column = candidate-letter.
        ENDIF.
      ENDLOOP.
    ENDIF.
    t_date_columns = VALUE #( ( key = `` text = `(none)` )
                              ( LINES OF VALUE #( FOR col IN columns ( key = col-letter text = col-header ) ) ) ).

    CLEAR t_rows.
    DO nmax( val1 = 0 val2 = max_row - first_row + 1 ) TIMES.
      INSERT INITIAL LINE INTO TABLE t_rows.
    ENDDO.

    DATA(converted) = 0.
    DATA(failed)    = 0.
    DATA(example)   = ``.
    LOOP AT sheet_cells INTO DATA(cell) WHERE row >= first_row.
      ASSIGN t_rows[ cell-row - first_row + 1 ] TO FIELD-SYMBOL(<row>).
      DATA(field) = substring( val = c_letters off = cell-column - 1 len = 1 ).
      ASSIGN COMPONENT field OF STRUCTURE <row> TO FIELD-SYMBOL(<value>).
      <value> = cell-value.
      IF field = imp-date_column.
        TRY.
            DATA(date) = zcl_excel_common=>excel_string_to_date( cell-value ).
            <value> = |{ date DATE = ISO }|.
            converted = converted + 1.
            IF example IS INITIAL.
              example = |, e.g. { cell-value } -> { <value> }|.
            ENDIF.
          CATCH zcx_excel.
            failed = failed + 1.
        ENDTRY.
      ENDIF.
    ENDLOOP.

    imp-info = |{ imp-file }: sheet { imp-sheet } read by zcl_excel_reader_2007, | &&
               |{ lines( t_rows ) } rows x { max_column } columns shown (at most { c_max_rows } rows, columns A-Z).|.
    IF imp-date_column IS NOT INITIAL.
      imp-info = |{ imp-info } Column { imp-date_column }: { converted } serial numbers converted by | &&
                 |zcl_excel_common=>excel_string_to_date{ example }, { failed } values are no date.|.
    ENDIF.

  ENDMETHOD.


  METHOD bookings_generate.

    " A stand-in for SBOOK, drawn from a seeded generator. With the flight
    " data model on the system this is a SELECT from sbook.
    TYPES:
      BEGIN OF ty_s_flight,
        carrid TYPE c LENGTH 3,
        connid TYPE n LENGTH 4,
        factor TYPE p LENGTH 3 DECIMALS 2,
      END OF ty_s_flight.
    DATA flights TYPE STANDARD TABLE OF ty_s_flight WITH EMPTY KEY.

    flights = VALUE #( ( carrid = `AA` connid = `0017` factor = `0.95` )
                       ( carrid = `LH` connid = `0400` factor = `1.00` )
                       ( carrid = `LH` connid = `2402` factor = `0.80` )
                       ( carrid = `SQ` connid = `0026` factor = `1.15` )
                       ( carrid = `UA` connid = `3504` factor = `0.92` )
                       ( carrid = `JL` connid = `0407` factor = `1.08` ) ).
    DATA(names) = VALUE string_table( ( `Anna Schmidt` )  ( `Ben Carter` )     ( `Chiara Rossi` )
                                      ( `David Kim` )     ( `Elena Petrova` )  ( `Farid Haddad` )
                                      ( `Grace Lee` )     ( `Hannes Berg` )    ( `Ines Moreau` )
                                      ( `Jonas Weber` )   ( `Keiko Tanaka` )   ( `Lucas Silva` ) ).

    CLEAR t_bookings.
    DO 50 TIMES.
      DATA(bookid) = 1000 + sy-index.
      DATA(flight) = flights[ random( low = 1 high = lines( flights ) ) ].
      DATA(pick)   = random( low = 1 high = 20 ).
      DATA(class)  = COND string( WHEN pick <= 14 THEN `Y` WHEN pick <= 18 THEN `C` ELSE `F` ).
      DATA(base)   = SWITCH i( class WHEN `Y` THEN 450 WHEN `C` THEN 1600 ELSE 3800 ).
      INSERT VALUE #( bookid   = bookid
                      carrid   = flight-carrid
                      connid   = flight-connid
                      fldate   = sy-datum + random( low = 1 high = 90 )
                      passname = names[ random( low = 1 high = lines( names ) ) ]
                      class    = class
                      amount   = ( base + random( low = 0 high = base / 2 ) ) * flight-factor )
             INTO TABLE t_bookings ASSIGNING FIELD-SYMBOL(<booking>).
      <booking>-fldate_text = |{ <booking>-fldate DATE = ISO }|.
    ENDDO.

  ENDMETHOD.


  METHOD model_init.

    tab  = `EXPORT`.
    seed = 42.
    opt = VALUE #( as_table    = abap_true
                   table_style = zcl_excel_table=>builtinstyle_medium2
                   freeze      = `ROW`
                   databar     = abap_true
                   highlight   = abap_true
                   threshold   = 2500
                   validation  = abap_true
                   chart       = abap_true ).
    t_table_styles = VALUE #( ( key = zcl_excel_table=>builtinstyle_medium2  text = `Medium 2 - blue` )
                              ( key = zcl_excel_table=>builtinstyle_medium9  text = `Medium 9 - blue header` )
                              ( key = zcl_excel_table=>builtinstyle_medium7  text = `Medium 7 - green` )
                              ( key = zcl_excel_table=>builtinstyle_light9   text = `Light 9` )
                              ( key = zcl_excel_table=>builtinstyle_light15  text = `Light 15` )
                              ( key = zcl_excel_table=>builtinstyle_dark1    text = `Dark 1` ) ).
    t_freeze = VALUE #( ( key = `NONE`       text = `None` )
                        ( key = `ROW`        text = `Header row` )
                        ( key = `ROW_COLUMN` text = `Header row and first column` ) ).

    imp-header = abap_true.
    imp-info   = `Upload an .xlsx file, or read the workbook the Export tab builds.`.

    TRY.
        bookings_generate( ).
        options_update( ).
      CATCH zcx_excel INTO DATA(error).
        client->message_box_display( error ).
    ENDTRY.

  ENDMETHOD.


  METHOD code_add.

    INSERT line INTO TABLE code_lines.

  ENDMETHOD.


  METHOD random.

    " Park-Miller minimal standard generator - the same seed, the same data
    seed = seed * 16807 MOD 2147483647.
    result = low + seed MOD ( high - low + 1 ).

  ENDMETHOD.

ENDCLASS.
