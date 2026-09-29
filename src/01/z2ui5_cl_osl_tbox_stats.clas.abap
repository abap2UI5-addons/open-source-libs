"! <p class="shorttext">tbox-stats visualized with abap2UI5</p>
"!
"! Descriptive statistics, group-by aggregations and the distribution
"! generators of https://github.com/zenrosadira/abap-tbox-stats rendered as
"! tiles and sap.viz charts. Every number is computed in ABAP by
"! ztbox_cl_stats - the frontend only draws the bound tables.
"!
"! sap.viz ships with SAPUI5 only: bootstrap the SAPUI5 runtime (the one of
"! the system or ui5.sap.com) instead of the OpenUI5 default.
CLASS z2ui5_cl_osl_tbox_stats DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_key_text,
        key  TYPE string,
        text TYPE string,
      END OF ty_s_key_text.
    TYPES ty_t_key_text TYPE STANDARD TABLE OF ty_s_key_text WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_tile,
        header TYPE string,
        value  TYPE string,
        unit   TYPE string,
        footer TYPE string,
        color  TYPE string,
      END OF ty_s_tile.
    TYPES ty_t_tile TYPE STANDARD TABLE OF ty_s_tile WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_bar,
        label    TYPE string,
        observed TYPE p LENGTH 16 DECIMALS 2,
        expected TYPE p LENGTH 16 DECIMALS 2,
      END OF ty_s_bar.
    TYPES ty_t_bar TYPE STANDARD TABLE OF ty_s_bar WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_cdf,
        label     TYPE string,
        empirical TYPE p LENGTH 16 DECIMALS 4,
        normal    TYPE p LENGTH 16 DECIMALS 4,
      END OF ty_s_cdf.
    TYPES ty_t_cdf TYPE STANDARD TABLE OF ty_s_cdf WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_group,
        label      TYPE string,
        bookings   TYPE i,
        share      TYPE p LENGTH 5 DECIMALS 1,
        share_text TYPE string,
        mean       TYPE p LENGTH 16 DECIMALS 2,
        median     TYPE p LENGTH 16 DECIMALS 2,
        std_dev    TYPE p LENGTH 16 DECIMALS 2,
        cv         TYPE p LENGTH 16 DECIMALS 3,
        iqr        TYPE p LENGTH 16 DECIMALS 2,
        skewness   TYPE p LENGTH 16 DECIMALS 2,
      END OF ty_s_group.
    TYPES ty_t_group TYPE STANDARD TABLE OF ty_s_group WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_lab,
        distribution TYPE string,
        p1           TYPE p LENGTH 16 DECIMALS 2,
        p1_label     TYPE string,
        p1_min       TYPE p LENGTH 16 DECIMALS 2,
        p1_max       TYPE p LENGTH 16 DECIMALS 2,
        p1_step      TYPE p LENGTH 16 DECIMALS 2,
        p1_precision TYPE i,
        p2           TYPE p LENGTH 16 DECIMALS 2,
        p2_label     TYPE string,
        p2_min       TYPE p LENGTH 16 DECIMALS 2,
        p2_max       TYPE p LENGTH 16 DECIMALS 2,
        p2_visible   TYPE abap_bool,
        size         TYPE i,
        title        TYPE string,
      END OF ty_s_lab.

    DATA tab             TYPE string.
    DATA column_unit     TYPE string.

    DATA column          TYPE string.
    DATA class_filter    TYPE string.
    DATA t_columns       TYPE ty_t_key_text.
    DATA t_tiles         TYPE ty_t_tile.
    DATA histogram_title TYPE string.
    DATA t_histogram     TYPE ty_t_bar.
    DATA cdf_title       TYPE string.
    DATA t_cdf           TYPE ty_t_cdf.
    DATA quartiles       TYPE string.

    DATA group_field     TYPE string.
    DATA groups_title    TYPE string.
    DATA t_groups        TYPE ty_t_group.

    DATA lab             TYPE ty_s_lab.
    DATA t_distributions TYPE ty_t_key_text.
    DATA t_lab_tiles     TYPE ty_t_tile.
    DATA t_lab_bars      TYPE ty_t_bar.

  PROTECTED SECTION.
    TYPES:
      BEGIN OF ty_s_booking,
        carrid     TYPE c LENGTH 3,
        class      TYPE c LENGTH 1,
        loccuram   TYPE p LENGTH 16 DECIMALS 2,
        luggweight TYPE p LENGTH 8 DECIMALS 1,
      END OF ty_s_booking.
    TYPES ty_t_booking TYPE STANDARD TABLE OF ty_s_booking WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_measure,
        name  TYPE string,
        field TYPE string,
      END OF ty_s_measure.
    TYPES ty_t_measure TYPE STANDARD TABLE OF ty_s_measure WITH EMPTY KEY.

    DATA client   TYPE REF TO z2ui5_if_client.
    DATA bookings TYPE ty_t_booking.

    METHODS view_display.
    METHODS view_explore
      IMPORTING
        items TYPE REF TO z2ui5_cl_ui5_view_builder.
    METHODS view_groups
      IMPORTING
        items TYPE REF TO z2ui5_cl_ui5_view_builder.
    METHODS view_lab
      IMPORTING
        items TYPE REF TO z2ui5_cl_ui5_view_builder.
    METHODS view_tiles
      IMPORTING
        parent TYPE REF TO z2ui5_cl_ui5_view_builder
        tiles  TYPE string.
    METHODS view_chart
      IMPORTING
        parent     TYPE REF TO z2ui5_cl_ui5_view_builder
        viz_type   TYPE string
        binding    TYPE string
        dimension  TYPE string
        measures   TYPE ty_t_measure
        properties TYPE string.

    METHODS on_event.
    METHODS explore_update
      RAISING
        zcx_tbox_stats.
    METHODS groups_update
      RAISING
        zcx_tbox_stats.
    METHODS lab_defaults.
    METHODS lab_update
      RAISING
        zcx_tbox_stats.
    METHODS bookings_generate
      RAISING
        zcx_tbox_stats.
    METHODS model_init.

    CLASS-METHODS normal_cdf
      IMPORTING
        z             TYPE f
      RETURNING
        VALUE(result) TYPE f.
    CLASS-METHODS fmt
      IMPORTING
        val           TYPE f
        decimals      TYPE i DEFAULT 2
      RETURNING
        VALUE(result) TYPE string.
    CLASS-METHODS fmt_p_value
      IMPORTING
        val           TYPE f
      RETURNING
        VALUE(result) TYPE string.
    CLASS-METHODS viz_properties
      IMPORTING
        data_shape    TYPE string OPTIONAL
        data_labels   TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(result) TYPE string.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_osl_tbox_stats IMPLEMENTATION.

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
            )->a( n = `displayBlock`    v = `true`
            )->a( n = `height`          v = `100%`
            )->a( n = `xmlns`           v = `sap.m`
            )->a( n = `xmlns:mvc`       v = `sap.ui.core.mvc`
            )->a( n = `xmlns:core`      v = `sap.ui.core`
            )->a( n = `xmlns:l`         v = `sap.ui.layout`
            )->a( n = `xmlns:viz`       v = `sap.viz.ui5.controls`
            )->a( n = `xmlns:viz.data`  v = `sap.viz.ui5.data`
            )->a( n = `xmlns:viz.feeds` v = `sap.viz.ui5.controls.common.feeds`
            )->ele( `Shell`
                )->a( n = `appWidthLimited` v = `false`
                )->ele( `Page`
                    )->a( n = `title`          v = `Statistics with ABAP - tbox-stats x abap2UI5`
                    )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
                    )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    page->ele( `headerContent`
        )->tag( `Button`
            )->a( n = `text`  v = `New random data`
            )->a( n = `icon`  v = `sap-icon://refresh`
            )->a( n = `type`  v = `Transparent`
            )->a( n = `press` v = client->_event( `REGENERATE` )
        )->tag( `Link`
            )->a( n = `text`   v = `zenrosadira/abap-tbox-stats`
            )->a( n = `href`   v = `https://github.com/zenrosadira/abap-tbox-stats`
            )->a( n = `target` v = `_blank` ).

    DATA(items) = page->ele( `content`
        )->ele( `IconTabBar`
            )->a( n = `selectedKey` v = client->_bind( tab )
            )->a( n = `expandable`  v = `false`
            )->a( n = `class`       v = `sapUiResponsiveContentPadding`
            )->ele( `items` ).

    view_explore( items ).
    view_groups( items ).
    view_lab( items ).

    client->view_display( page->stringify( ) ).

  ENDMETHOD.


  METHOD view_explore.

    DATA(content) = items->ele( `IconTabFilter`
        )->a( n = `key`  v = `EXPLORE`
        )->a( n = `text` v = `Explore a column`
        )->a( n = `icon` v = `sap-icon://vertical-bar-chart`
        )->ele( `content` ).

    content->ele( `OverflowToolbar`
        )->a( n = `style` v = `Clear`
        )->ele( `content`
            )->tag( `Label`
                )->a( n = `text` v = `Column`
            )->ele( `Select`
                )->a( n = `selectedKey` v = client->_bind( column )
                )->a( n = `items`       v = client->_bind( t_columns )
                )->a( n = `change`      v = client->_event( `EXPLORE` )
                )->tag( n = `Item` ns = `core`
                    )->a( n = `key`  v = `{KEY}`
                    )->a( n = `text` v = `{TEXT}`
            )->end(
            )->tag( `ToolbarSpacer`
            )->tag( `Label`
                )->a( n = `text` v = `Booking class`
            )->ele( `SegmentedButton`
                )->a( n = `selectedKey`     v = client->_bind( class_filter )
                )->a( n = `selectionChange` v = client->_event( `EXPLORE` )
                )->ele( `items`
                    )->tag( `SegmentedButtonItem`
                        )->a( n = `key`  v = `ALL`
                        )->a( n = `text` v = `All`
                    )->tag( `SegmentedButtonItem`
                        )->a( n = `key`  v = `Y`
                        )->a( n = `text` v = `Economy`
                    )->tag( `SegmentedButtonItem`
                        )->a( n = `key`  v = `C`
                        )->a( n = `text` v = `Business`
                    )->tag( `SegmentedButtonItem`
                        )->a( n = `key`  v = `F`
                        )->a( n = `text` v = `First` ).

    view_tiles( parent = content
                tiles  = client->_bind( t_tiles ) ).

    DATA(grid) = content->ele( n = `Grid` ns = `l`
        )->a( n = `defaultSpan` v = `XL6 L6 M12 S12`
        )->a( n = `class`       v = `sapUiSmallMarginTop` ).

    DATA(left) = grid->ele( `VBox` ).
    left->tag( `Title`
        )->a( n = `text`  v = client->_bind( histogram_title )
        )->a( n = `level` v = `H4` ).
    view_chart( parent     = left
                viz_type   = `combination`
                binding    = client->_bind( t_histogram )
                dimension  = `Bin`
                measures   = VALUE #( ( name = `Observed`   field = `OBSERVED` )
                                      ( name = `Normal fit` field = `EXPECTED` ) )
                properties = viz_properties( data_shape = `["bar","line"]` ) ).

    DATA(right) = grid->ele( `VBox` ).
    right->tag( `Title`
        )->a( n = `text`  v = client->_bind( cdf_title )
        )->a( n = `level` v = `H4` ).
    view_chart( parent     = right
                viz_type   = `combination`
                binding    = client->_bind( t_cdf )
                dimension  = `Value`
                measures   = VALUE #( ( name = `Empirical CDF` field = `EMPIRICAL` )
                                      ( name = `Normal CDF`    field = `NORMAL` ) )
                properties = viz_properties( data_shape = `["line","line"]` ) ).

    content->tag( `MessageStrip`
        )->a( n = `text`     v = client->_bind( quartiles )
        )->a( n = `type`     v = `Information`
        )->a( n = `showIcon` v = `true`
        )->a( n = `class`    v = `sapUiSmallMarginTop` ).

  ENDMETHOD.


  METHOD view_groups.

    DATA(content) = items->ele( `IconTabFilter`
        )->a( n = `key`  v = `GROUPS`
        )->a( n = `text` v = `Group by`
        )->a( n = `icon` v = `sap-icon://group-2`
        )->ele( `content` ).

    content->ele( `OverflowToolbar`
        )->a( n = `style` v = `Clear`
        )->ele( `content`
            )->tag( `Label`
                )->a( n = `text` v = `Group by`
            )->ele( `SegmentedButton`
                )->a( n = `selectedKey`     v = client->_bind( group_field )
                )->a( n = `selectionChange` v = client->_event( `GROUPS` )
                )->ele( `items`
                    )->tag( `SegmentedButtonItem`
                        )->a( n = `key`  v = `CLASS`
                        )->a( n = `text` v = `Booking class`
                    )->tag( `SegmentedButtonItem`
                        )->a( n = `key`  v = `CARRID`
                        )->a( n = `text` v = `Carrier` ).

    DATA(grid) = content->ele( n = `Grid` ns = `l`
        )->a( n = `defaultSpan` v = `XL5 L5 M12 S12`
        )->a( n = `class`       v = `sapUiSmallMarginTop` ).

    DATA(left) = grid->ele( `VBox` ).
    left->tag( `Title`
        )->a( n = `text`  v = client->_bind( groups_title )
        )->a( n = `level` v = `H4` ).
    view_chart( parent     = left
                viz_type   = `column`
                binding    = client->_bind( t_groups )
                dimension  = `Group`
                measures   = VALUE #( ( name = `Mean`   field = `MEAN` )
                                      ( name = `Median` field = `MEDIAN` ) )
                properties = viz_properties( data_labels = abap_true ) ).

    DATA(table) = grid->ele( `Table`
        )->a( n = `items` v = client->_bind( t_groups )
        )->ele( `layoutData`
            )->tag( n = `GridData` ns = `l`
                )->a( n = `span` v = `XL7 L7 M12 S12`
        )->end( ).

    " header is the default aggregation of sap.m.Column
    table->ele( `columns`
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Group`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Share`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Mean`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Median`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Std. dev.`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `CV`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `IQR`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Skewness` ).

    table->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells`
                )->tag( `ObjectIdentifier`
                    )->a( n = `title` v = `{LABEL}`
                    )->a( n = `text`  v = `{BOOKINGS} bookings`
                )->tag( `ProgressIndicator`
                    )->a( n = `percentValue` v = `{SHARE}`
                    )->a( n = `displayValue` v = `{SHARE_TEXT}`
                    )->a( n = `showValue`    v = `true`
                )->tag( `ObjectNumber`
                    )->a( n = `number` v = `{MEAN}`
                    )->a( n = `unit`   v = client->_bind( column_unit )
                )->tag( `ObjectNumber`
                    )->a( n = `number` v = `{MEDIAN}`
                    )->a( n = `unit`   v = client->_bind( column_unit )
                )->tag( `ObjectNumber`
                    )->a( n = `number` v = `{STD_DEV}`
                )->tag( `ObjectNumber`
                    )->a( n = `number` v = `{CV}`
                )->tag( `ObjectNumber`
                    )->a( n = `number` v = `{IQR}`
                )->tag( `ObjectNumber`
                    )->a( n = `number` v = `{SKEWNESS}` ).

  ENDMETHOD.


  METHOD view_lab.

    DATA(content) = items->ele( `IconTabFilter`
        )->a( n = `key`  v = `LAB`
        )->a( n = `text` v = `Distribution lab`
        )->a( n = `icon` v = `sap-icon://lab`
        )->ele( `content` ).

    content->ele( `OverflowToolbar`
        )->a( n = `style` v = `Clear`
        )->ele( `content`
            )->ele( `Select`
                )->a( n = `selectedKey` v = client->_bind( lab-distribution )
                )->a( n = `items`       v = client->_bind( t_distributions )
                )->a( n = `change`      v = client->_event( `DISTRIBUTION` )
                )->tag( n = `Item` ns = `core`
                    )->a( n = `key`  v = `{KEY}`
                    )->a( n = `text` v = `{TEXT}`
            )->end(
            )->tag( `Label`
                )->a( n = `text` v = client->_bind( lab-p1_label )
            )->tag( `StepInput`
                )->a( n = `value`                 v = client->_bind( lab-p1 )
                )->a( n = `min`                   v = client->_bind( lab-p1_min )
                )->a( n = `max`                   v = client->_bind( lab-p1_max )
                )->a( n = `step`                  v = client->_bind( lab-p1_step )
                )->a( n = `displayValuePrecision` v = client->_bind( lab-p1_precision )
                )->a( n = `width`                 v = `9rem`
            )->tag( `Label`
                )->a( n = `text`    v = client->_bind( lab-p2_label )
                )->a( n = `visible` v = client->_bind( lab-p2_visible )
            )->tag( `StepInput`
                )->a( n = `value`                 v = client->_bind( lab-p2 )
                )->a( n = `min`                   v = client->_bind( lab-p2_min )
                )->a( n = `max`                   v = client->_bind( lab-p2_max )
                )->a( n = `step`                  v = `0.1`
                )->a( n = `displayValuePrecision` v = `2`
                )->a( n = `width`                 v = `9rem`
                )->a( n = `visible`               v = client->_bind( lab-p2_visible )
            )->tag( `Label`
                )->a( n = `text` v = `Draws`
            )->tag( `StepInput`
                )->a( n = `value` v = client->_bind( lab-size )
                )->a( n = `min`   v = `100`
                )->a( n = `max`   v = `200000`
                )->a( n = `step`  v = `1000`
                )->a( n = `width` v = `10rem`
            )->tag( `Button`
                )->a( n = `text`  v = `Draw sample`
                )->a( n = `icon`  v = `sap-icon://synchronize`
                )->a( n = `type`  v = `Emphasized`
                )->a( n = `press` v = client->_event( `DRAW` ) ).

    view_tiles( parent = content
                tiles  = client->_bind( t_lab_tiles ) ).

    content->tag( `Title`
        )->a( n = `text`  v = client->_bind( lab-title )
        )->a( n = `level` v = `H4`
        )->a( n = `class` v = `sapUiSmallMarginTop` ).
    view_chart( parent     = content
                viz_type   = `combination`
                binding    = client->_bind( t_lab_bars )
                dimension  = `Value`
                measures   = VALUE #( ( name = `Observed` field = `OBSERVED` )
                                      ( name = `Theory`   field = `EXPECTED` ) )
                properties = viz_properties( data_shape = `["bar","line"]` ) ).

  ENDMETHOD.


  METHOD view_tiles.

    parent->ele( `FlexBox`
        )->a( n = `wrap`  v = `Wrap`
        )->a( n = `items` v = tiles
        )->a( n = `class` v = `sapUiSmallMarginTop`
        )->ele( `GenericTile`
            )->a( n = `header`    v = `{HEADER}`
            )->a( n = `frameType` v = `OneByOne`
            )->a( n = `class`     v = `sapUiTinyMarginEnd sapUiTinyMarginBottom`
            )->ele( `tileContent`
                )->ele( `TileContent`
                    )->a( n = `unit`   v = `{UNIT}`
                    )->a( n = `footer` v = `{FOOTER}`
                    )->ele( `content`
                        )->tag( `NumericContent`
                            )->a( n = `value`           v = `{VALUE}`
                            )->a( n = `valueColor`      v = `{COLOR}`
                            )->a( n = `withMargin`      v = `false`
                            )->a( n = `truncateValueTo` v = `9` ).

  ENDMETHOD.


  METHOD view_chart.

    DATA(viz_frame) = parent->ele( n = `VizFrame` ns = `viz`
        )->a( n = `vizType`       v = viz_type
        )->a( n = `uiConfig`      v = `{applicationSet:'fiori'}`
        )->a( n = `vizProperties` v = properties
        )->a( n = `height`        v = `360px`
        )->a( n = `width`         v = `100%` ).

    DATA(dataset) = viz_frame->ele( n = `dataset` ns = `viz`
        )->ele( n = `FlattenedDataset` ns = `viz.data`
            )->a( n = `data` v = binding ).

    dataset->ele( n = `dimensions` ns = `viz.data`
        )->tag( n = `DimensionDefinition` ns = `viz.data`
            )->a( n = `name`  t = dimension
            )->a( n = `value` v = `{LABEL}` ).

    DATA(measure_definitions) = dataset->ele( n = `measures` ns = `viz.data` ).
    LOOP AT measures INTO DATA(measure).
      measure_definitions->tag( n = `MeasureDefinition` ns = `viz.data`
          )->a( n = `name`  t = measure-name
          )->a( n = `value` v = |\{{ measure-field }\}| ).
    ENDLOOP.

    DATA(measure_names) = concat_lines_of( table = VALUE string_table( FOR m IN measures ( m-name ) )
                                           sep   = `,` ).
    viz_frame->ele( n = `feeds` ns = `viz`
        )->tag( n = `FeedItem` ns = `viz.feeds`
            )->a( n = `uid`    v = `valueAxis`
            )->a( n = `type`   v = `Measure`
            )->a( n = `values` t = measure_names
        )->tag( n = `FeedItem` ns = `viz.feeds`
            )->a( n = `uid`    v = `categoryAxis`
            )->a( n = `type`   v = `Dimension`
            )->a( n = `values` t = dimension ).

  ENDMETHOD.


  METHOD on_event.

    " every tbox-stats method raises the static zcx_tbox_stats (a column
    " that is not numeric, p outside [0, 1], ...) - shown, not dumped
    TRY.
        CASE client->get_event( ).

          WHEN `EXPLORE`.
            explore_update( ).
            groups_update( ).

          WHEN `GROUPS`.
            groups_update( ).

          WHEN `DISTRIBUTION`.
            lab_defaults( ).
            lab_update( ).

          WHEN `DRAW`.
            lab_update( ).

          WHEN `REGENERATE`.
            bookings_generate( ).
            explore_update( ).
            groups_update( ).
            client->message_toast_display( |New random dataset: { lines( bookings ) } bookings| ).

        ENDCASE.
      CATCH zcx_tbox_stats INTO DATA(error).
        client->message_box_display( error ).
    ENDTRY.

  ENDMETHOD.


  METHOD explore_update.

    DATA(rows) = bookings.
    IF class_filter <> `ALL`.
      DELETE rows WHERE class <> class_filter.
    ENDIF.

    DATA(table) = NEW ztbox_cl_stats( rows ).
    DATA(values) = table->col( CONV #( column ) ).

    DATA(n)         = values->count( ).
    DATA(mean)      = CONV f( values->mean( ) ).
    DATA(std_dev)   = CONV f( values->standard_deviation( ) ).
    DATA(skewness)  = CONV f( values->skewness( ) ).
    DATA(kurtosis)  = CONV f( values->kurtosis( ) ).
    DATA(p_value)   = VALUE f( ).
    DATA(is_normal) = values->are_normal( EXPORTING alpha   = `0.05`
                                          IMPORTING p_value = p_value ).
    DATA(outliers)  = values->outliers( ).
    DATA(decimals)  = COND i( WHEN column = `LUGGWEIGHT` THEN 1 ELSE 0 ).
    column_unit = COND #( WHEN column = `LUGGWEIGHT` THEN `KG` ELSE `EUR` ).

    t_tiles = VALUE #(
        ( header = `Mean`              value = fmt( mean ) unit = column_unit
          footer = |median { fmt( CONV f( values->median( ) ) ) }|
          color  = `Neutral` )
        ( header = `Std. deviation`    value = fmt( std_dev ) unit = column_unit
          footer = |CV { fmt( val = CONV f( values->coefficient_variation( ) ) decimals = 3 ) }|
          color  = `Neutral` )
        ( header = `Skewness`          value = fmt( skewness )
          footer = COND #( WHEN skewness > `0.5` THEN `right tail`
                           WHEN skewness < `-0.5` THEN `left tail`
                           ELSE `about symmetric` )
          color  = COND #( WHEN abs( skewness ) > 1 THEN `Critical` ELSE `Neutral` ) )
        ( header = `Kurtosis`          value = fmt( kurtosis )
          footer = |excess { fmt( kurtosis - 3 ) }|
          color  = COND #( WHEN abs( kurtosis - 3 ) > 1 THEN `Critical` ELSE `Neutral` ) )
        ( header = `Normal? (Jarque-Bera)` value = fmt_p_value( p_value ) unit = `p`
          footer = COND #( WHEN is_normal = abap_true THEN `yes, at 5 %` ELSE `no, rejected at 5 %` )
          color  = COND #( WHEN is_normal = abap_true THEN `Good` ELSE `Error` ) )
        ( header = `Outliers (1.5 IQR)` value = |{ lines( outliers ) }|
          footer = |IQR { fmt( val = CONV f( values->interquartile_range( ) ) decimals = decimals ) }|
          color  = COND #( WHEN outliers IS INITIAL THEN `Good` ELSE `Critical` ) )
        ( header = `Correlation`       value = fmt( CONV f( table->correlation( `LOCCURAM, LUGGWEIGHT` ) ) )
          footer = `price vs. luggage`
          color  = `Neutral` ) ).

    " histogram( ) bins by the Freedman-Diaconis rule, the normal fit is the
    " count a normal distribution with the same mean and deviation expects
    DATA(histogram) = values->histogram( ).
    DATA(width) = COND f( WHEN lines( histogram ) > 1
                          THEN CONV f( histogram[ 2 ]-x ) - CONV f( histogram[ 1 ]-x )
                          ELSE 1 ).
    CLEAR t_histogram.
    LOOP AT histogram INTO DATA(bin).
      DATA(bin_start) = CONV f( bin-x ).
      INSERT VALUE #( label    = fmt( val = bin_start decimals = decimals )
                      observed = bin-y
                      expected = COND #( WHEN std_dev > 0
                                         THEN n * ( normal_cdf( ( bin_start + width - mean ) / std_dev )
                                                  - normal_cdf( ( bin_start - mean ) / std_dev ) ) ) )
             INTO TABLE t_histogram.
    ENDLOOP.

    " empirical_cdf( ) returns F(x) at every distinct value (sorted) - read
    " at 31 evenly spaced values from min to max it draws the curve
    DATA(cdf)     = values->empirical_cdf( ).
    DATA(lowest)  = CONV f( values->min( ) ).
    DATA(highest) = CONV f( values->max( ) ).
    DATA(ix) = 0.
    CLEAR t_cdf.
    DO 31 TIMES.
      DATA(x) = lowest + ( highest - lowest ) * ( sy-index - 1 ) / 30.
      WHILE ix < lines( cdf ) AND CONV f( cdf[ ix + 1 ]-x ) <= x.
        ix = ix + 1.
      ENDWHILE.
      INSERT VALUE #( label     = fmt( val = x decimals = decimals )
                      empirical = COND #( WHEN ix > 0 THEN cdf[ ix ]-y )
                      normal    = COND #( WHEN std_dev > 0 THEN normal_cdf( ( x - mean ) / std_dev ) ) )
             INTO TABLE t_cdf.
    ENDDO.

    DATA(column_text) = t_columns[ key = column ]-text.
    histogram_title = |{ column_text } - { n } bookings in { lines( histogram ) } bins, with normal fit|.
    cdf_title       = |Empirical distribution function vs. normal CDF, min to max|.
    quartiles = |Q1 { fmt( val = CONV f( values->first_quartile( ) ) decimals = decimals ) }, | &&
                |median { fmt( val = CONV f( values->median( ) ) decimals = decimals ) }, | &&
                |Q3 { fmt( val = CONV f( values->third_quartile( ) ) decimals = decimals ) }, | &&
                |range { fmt( val = lowest decimals = decimals ) } - | &&
                |{ fmt( val = highest decimals = decimals ) } { column_unit } | &&
                |- harmonic { fmt( CONV f( values->harmonic_mean( ) ) ) } <= | &&
                |geometric { fmt( CONV f( values->geometric_mean( ) ) ) } <= | &&
                |arithmetic { fmt( mean ) } <= quadratic mean { fmt( CONV f( values->quadratic_mean( ) ) ) }|.

  ENDMETHOD.


  METHOD groups_update.

    DATA(grouped) = NEW ztbox_cl_stats( bookings )->group_by( group_field )->col( CONV #( column ) ).

    " every aggregation walks the groups in the same order, so row i of one
    " result belongs to row i of the next
    DATA(counts)    = grouped->count( ).
    DATA(means)     = grouped->mean( ).
    DATA(medians)   = grouped->median( ).
    DATA(std_devs)  = grouped->standard_deviation( ).
    DATA(cvs)       = grouped->coefficient_variation( ).
    DATA(iqrs)      = grouped->interquartile_range( ).
    DATA(skews)     = grouped->skewness( ).

    CLEAR t_groups.
    LOOP AT counts INTO DATA(count).
      DATA(ix) = sy-tabix.
      DATA(key) = count-group_by[ 1 ]-group_value.
      INSERT VALUE #( label    = COND #( WHEN group_field = `CARRID` THEN key
                                         WHEN key = `Y` THEN `Economy`
                                         WHEN key = `C` THEN `Business`
                                         ELSE `First` )
                      bookings = count-value
                      share    = 100 * CONV f( count-value ) / lines( bookings )
                      mean     = CONV f( means[ ix ]-value )
                      median   = CONV f( medians[ ix ]-value )
                      std_dev  = CONV f( std_devs[ ix ]-value )
                      cv       = CONV f( cvs[ ix ]-value )
                      iqr      = CONV f( iqrs[ ix ]-value )
                      skewness = CONV f( skews[ ix ]-value ) )
             INTO TABLE t_groups ASSIGNING FIELD-SYMBOL(<group>).
      <group>-share_text = |{ <group>-share } %|.
    ENDLOOP.
    SORT t_groups BY mean.

    groups_title = |{ t_columns[ key = column ]-text } by | &&
                   |{ COND string( WHEN group_field = `CARRID` THEN `carrier` ELSE `booking class` ) }: mean and median|.

  ENDMETHOD.


  METHOD lab_defaults.

    DATA(size) = lab-size.
    DATA(distribution) = lab-distribution.
    lab = SWITCH #( distribution
      WHEN `NORMAL`    THEN VALUE #( p1 = 0  p1_label = `Mean`   p1_min = -100 p1_max = 100 p1_step = `0.5`
                                     p2 = 1  p2_label = `Variance` p2_min = `0.1` p2_max = 100 p2_visible = abap_true )
      WHEN `UNIFORM`   THEN VALUE #( p1 = 0  p1_label = `Low`    p1_min = -100 p1_max = 100 p1_step = 1
                                     p2 = 10 p2_label = `High`   p2_min = -100 p2_max = 100 p2_visible = abap_true )
      WHEN `POISSON`   THEN VALUE #( p1 = 4  p1_label = `Lambda` p1_min = `0.1` p1_max = 50 p1_step = `0.5` )
      WHEN `BINOMIAL`  THEN VALUE #( p1 = 15 p1_label = `Trials n` p1_min = 1 p1_max = 100 p1_step = 1
                                     p2 = `0.4` p2_label = `p`   p2_min = 0 p2_max = 1 p2_visible = abap_true )
      WHEN `GEOMETRIC` THEN VALUE #( p1 = `0.3` p1_label = `p`   p1_min = `0.01` p1_max = `0.99` p1_step = `0.05` )
      WHEN `BERNOULLI` THEN VALUE #( p1 = `0.7` p1_label = `p`   p1_min = 0 p1_max = 1 p1_step = `0.05` ) ).
    lab-distribution = distribution.
    lab-size         = size.
    lab-p1_precision = COND #( WHEN lab-p1_step < 1 THEN 2 ).

  ENDMETHOD.


  METHOD lab_update.

    TYPES:
      BEGIN OF ty_s_draw,
        k TYPE i,
      END OF ty_s_draw.
    TYPES:
      BEGIN OF ty_s_frequency,
        k     TYPE i,
        count TYPE i,
      END OF ty_s_frequency.
    DATA floats      TYPE ztbox_cl_stats=>ty_floats.
    DATA ints        TYPE ztbox_cl_stats=>ty_ints.
    DATA draws       TYPE STANDARD TABLE OF ty_s_draw WITH EMPTY KEY.
    DATA frequencies TYPE SORTED TABLE OF ty_s_frequency WITH UNIQUE KEY k.
    DATA stats       TYPE REF TO ztbox_cl_stats.
    DATA col         TYPE name_feld.

    CASE lab-distribution.
      WHEN `NORMAL`.
        floats = ztbox_cl_stats=>normal( mean = CONV #( lab-p1 ) variance = CONV #( lab-p2 ) size = lab-size ).
      WHEN `UNIFORM`.
        floats = ztbox_cl_stats=>uniform( low = CONV #( lab-p1 ) high = CONV #( lab-p2 ) size = lab-size ).
      WHEN `POISSON`.
        ints = ztbox_cl_stats=>poisson( l = CONV #( lab-p1 ) size = lab-size ).
      WHEN `BINOMIAL`.
        ints = ztbox_cl_stats=>binomial( n = CONV #( lab-p1 ) p = CONV #( lab-p2 ) size = lab-size ).
      WHEN `GEOMETRIC`.
        ints = ztbox_cl_stats=>geometric( p = CONV #( lab-p1 ) size = lab-size ).
      WHEN `BERNOULLI`.
        ints = ztbox_cl_stats=>bernoulli( p = CONV #( lab-p1 ) size = lab-size ).
    ENDCASE.

    DATA(p1) = CONV f( lab-p1 ).
    DATA(p2) = CONV f( lab-p2 ).
    DATA(theory_mean) = SWITCH f( lab-distribution
      WHEN `NORMAL`    THEN p1
      WHEN `UNIFORM`   THEN ( p1 + p2 ) / 2
      WHEN `POISSON`   THEN p1
      WHEN `BINOMIAL`  THEN p1 * p2
      WHEN `GEOMETRIC` THEN 1 / p1
      WHEN `BERNOULLI` THEN p1 ).
    DATA(theory_variance) = SWITCH f( lab-distribution
      WHEN `NORMAL`    THEN p2
      WHEN `UNIFORM`   THEN ( p2 - p1 ) * ( p2 - p1 ) / 12
      WHEN `POISSON`   THEN p1
      WHEN `BINOMIAL`  THEN p1 * p2 * ( 1 - p2 )
      WHEN `GEOMETRIC` THEN ( 1 - p1 ) / ( p1 * p1 )
      WHEN `BERNOULLI` THEN p1 * ( 1 - p1 ) ).

    CLEAR t_lab_bars.
    IF floats IS NOT INITIAL.

      " continuous: histogram( ) against the probability mass of each bin
      col   = `TABLE_LINE`.
      stats = NEW #( floats ).
      DATA(n) = CONV f( stats->count( ) ).
      DATA(histogram) = stats->histogram( ).
      DATA(width) = COND f( WHEN lines( histogram ) > 1
                            THEN CONV f( histogram[ 2 ]-x ) - CONV f( histogram[ 1 ]-x )
                            ELSE 1 ).
      LOOP AT histogram INTO DATA(bin).
        DATA(bin_start) = CONV f( bin-x ).
        DATA(bin_end)   = bin_start + width.
        INSERT VALUE #( label    = fmt( bin_start )
                        observed = bin-y
                        expected = COND #(
                          WHEN lab-distribution = `NORMAL`
                            THEN n * ( normal_cdf( ( bin_end - p1 ) / sqrt( p2 ) ) - normal_cdf( ( bin_start - p1 ) / sqrt( p2 ) ) )
                          WHEN p2 > p1
                            THEN n * nmax( val1 = 0 val2 = nmin( val1 = bin_end val2 = p2 ) - nmax( val1 = bin_start val2 = p1 ) ) / ( p2 - p1 ) ) )
               INTO TABLE t_lab_bars.
      ENDLOOP.

    ELSE.

      " discrete: the frequency of each value is a group-by plus count( )
      col   = `K`.
      draws = VALUE #( FOR i IN ints ( k = i ) ).
      stats = NEW #( draws ).
      n = stats->count( ).
      LOOP AT stats->group_by( `K` )->count( ) INTO DATA(frequency).
        INSERT VALUE #( k     = frequency-group_by[ 1 ]-group_value
                        count = frequency-value ) INTO TABLE frequencies.
      ENDLOOP.

      DATA(pmf) = SWITCH f( lab-distribution
        WHEN `POISSON`   THEN exp( 0 - p1 )
        WHEN `BINOMIAL`  THEN ( 1 - p2 ) ** p1
        WHEN `BERNOULLI` THEN 1 - p1
        ELSE 0 ).
      DO CONV i( stats->max( col ) ) + 1 TIMES.
        DATA(k) = sy-index - 1.
        IF lab-distribution = `GEOMETRIC`.
          pmf = COND #( WHEN k > 0 THEN p1 * ( 1 - p1 ) ** ( k - 1 ) ).
        ENDIF.
        INSERT VALUE #( label    = |{ k }|
                        observed = VALUE #( frequencies[ k = k ]-count OPTIONAL )
                        expected = n * pmf )
               INTO TABLE t_lab_bars.
        pmf = SWITCH #( lab-distribution
          WHEN `POISSON`   THEN pmf * p1 / ( k + 1 )
          WHEN `BINOMIAL`  THEN COND #( WHEN p2 < 1 THEN pmf * ( p1 - k ) / ( k + 1 ) * p2 / ( 1 - p2 ) )
          WHEN `BERNOULLI` THEN p1
          ELSE pmf ).
      ENDDO.

    ENDIF.

    DATA(p_value) = VALUE f( ).
    DATA(is_normal) = stats->are_normal( EXPORTING col     = col
                                                   alpha   = `0.05`
                                         IMPORTING p_value = p_value ).
    t_lab_tiles = VALUE #(
        ( header = `Draws`    value = |{ stats->count( ) }| footer = |requested { lab-size }|
          color  = COND #( WHEN stats->count( ) = lab-size THEN `Good` ELSE `Error` ) )
        ( header = `Mean`     value = fmt( CONV f( stats->mean( col ) ) )
          footer = |theory { fmt( theory_mean ) }| color = `Neutral` )
        ( header = `Variance` value = fmt( CONV f( stats->variance( col ) ) )
          footer = |theory { fmt( theory_variance ) }| color = `Neutral` )
        ( header = `Skewness` value = fmt( CONV f( stats->skewness( col ) ) )
          footer = |kurtosis { fmt( CONV f( stats->kurtosis( col ) ) ) }| color = `Neutral` )
        ( header = `Normal? (Jarque-Bera)` value = fmt_p_value( p_value ) unit = `p`
          footer = COND #( WHEN is_normal = abap_true THEN `yes, at 5 %` ELSE `no, rejected at 5 %` )
          color  = COND #( WHEN is_normal = abap_true THEN `Good` ELSE `Error` ) ) ).

    lab-title = |{ t_distributions[ key = lab-distribution ]-text }| &&
                |({ lab-p1_label } = { fmt( val = p1 decimals = lab-p1_precision ) }| &&
                |{ COND string( WHEN lab-p2_visible = abap_true THEN |, { lab-p2_label } = { fmt( p2 ) }| ) }) - | &&
                |{ stats->count( ) } draws: observed vs. theory|.

  ENDMETHOD.


  METHOD bookings_generate.

    " A stand-in for SBOOK, drawn with tbox-stats' own generators. With the
    " flight data model on the system this method is one statement:
    "   SELECT carrid, class, loccuram, luggweight FROM sbook
    "     INTO CORRESPONDING FIELDS OF TABLE @bookings.
    TYPES:
      BEGIN OF ty_s_class,
        class   TYPE c LENGTH 1,
        size    TYPE i,
        mean    TYPE f,
        std_dev TYPE f,
        luggage TYPE f,
      END OF ty_s_class.
    TYPES:
      BEGIN OF ty_s_carrier,
        carrid TYPE c LENGTH 3,
        factor TYPE f,
      END OF ty_s_carrier.
    DATA classes TYPE STANDARD TABLE OF ty_s_class WITH EMPTY KEY.
    DATA carriers TYPE STANDARD TABLE OF ty_s_carrier WITH EMPTY KEY.

    classes = VALUE #( ( class = `Y` size = 3100 mean = 650  std_dev = 180 luggage = 17 )
                       ( class = `C` size = 700  mean = 1900 std_dev = 420 luggage = 21 )
                       ( class = `F` size = 200  mean = 4200 std_dev = 900 luggage = 25 ) ).
    carriers = VALUE #( ( carrid = `AA` factor = `0.95` )
                        ( carrid = `LH` factor = `1.00` )
                        ( carrid = `SQ` factor = `1.15` )
                        ( carrid = `UA` factor = `0.92` )
                        ( carrid = `JL` factor = `1.08` ) ).

    CLEAR bookings.
    LOOP AT classes INTO DATA(class_spec).
      DATA(prices)  = ztbox_cl_stats=>normal( mean     = class_spec-mean
                                              variance = class_spec-std_dev * class_spec-std_dev
                                              size     = class_spec-size ).
      DATA(luggage) = ztbox_cl_stats=>normal( mean = class_spec-luggage variance = 16 size = class_spec-size ).
      DATA(picks)   = ztbox_cl_stats=>uniform( high = CONV #( lines( carriers ) ) size = class_spec-size ).
      LOOP AT prices INTO DATA(price).
        DATA(ix) = sy-tabix.
        " uniform( ) draws from [0, high), so the index stays within 1 .. 5
        DATA(carrier) = carriers[ 1 + CONV i( floor( picks[ ix ] ) ) ].
        INSERT VALUE #( carrid     = carrier-carrid
                        class      = class_spec-class
                        loccuram   = nmax( val1 = 99 val2 = price * carrier-factor )
                        luggweight = nmin( val1 = 32 val2 = nmax( val1 = 0 val2 = luggage[ ix ] ) ) )
               INTO TABLE bookings.
      ENDLOOP.
    ENDLOOP.

  ENDMETHOD.


  METHOD model_init.

    tab          = `EXPLORE`.
    column       = `LOCCURAM`.
    class_filter = `ALL`.
    group_field  = `CLASS`.
    t_columns = VALUE #( ( key = `LOCCURAM`   text = `Price (LOCCURAM)` )
                         ( key = `LUGGWEIGHT` text = `Luggage weight (LUGGWEIGHT)` ) ).
    t_distributions = VALUE #( ( key = `NORMAL`    text = `Normal` )
                               ( key = `UNIFORM`   text = `Uniform` )
                               ( key = `POISSON`   text = `Poisson` )
                               ( key = `BINOMIAL`  text = `Binomial` )
                               ( key = `GEOMETRIC` text = `Geometric` )
                               ( key = `BERNOULLI` text = `Bernoulli` ) ).

    lab-distribution = `NORMAL`.
    lab-size         = 10000.
    lab_defaults( ).

    TRY.
        bookings_generate( ).
        explore_update( ).
        groups_update( ).
        lab_update( ).
      CATCH zcx_tbox_stats INTO DATA(error).
        client->message_box_display( error ).
    ENDTRY.

  ENDMETHOD.


  METHOD normal_cdf.

    " standard normal CDF via erf, Abramowitz & Stegun 7.1.26 (|error| < 1.5E-7)
    CONSTANTS c_p  TYPE f VALUE '0.3275911'.
    CONSTANTS c_a1 TYPE f VALUE '0.254829592'.
    CONSTANTS c_a2 TYPE f VALUE '-0.284496736'.
    CONSTANTS c_a3 TYPE f VALUE '1.421413741'.
    CONSTANTS c_a4 TYPE f VALUE '-1.453152027'.
    CONSTANTS c_a5 TYPE f VALUE '1.061405429'.

    DATA(x) = abs( z ) / sqrt( CONV f( 2 ) ).
    DATA(t) = 1 / ( 1 + c_p * x ).
    DATA(erf) = 1 - ( ( ( ( c_a5 * t + c_a4 ) * t + c_a3 ) * t + c_a2 ) * t + c_a1 ) * t * exp( 0 - x * x ).
    result = COND #( WHEN z >= 0 THEN ( 1 + erf ) / 2 ELSE ( 1 - erf ) / 2 ).

  ENDMETHOD.


  METHOD fmt.

    " DECIMALS switches f to mathematical notation and rounds; whole
    " numbers take the short way through i
    result = COND #( WHEN decimals > 0 THEN |{ val DECIMALS = decimals }| ELSE |{ CONV i( val ) }| ).

  ENDMETHOD.


  METHOD fmt_p_value.

    result = COND #( WHEN val < `0.001` THEN `< 0.001` ELSE fmt( val = val decimals = 3 ) ).

  ENDMETHOD.


  METHOD viz_properties.

    " the vizProperties object, set once with the view - the data moves, the
    " look stays
    result = |\{"title":\{"visible":false\},"legendGroup":\{"layout":\{"position":"bottom"\}\},| &&
             |"valueAxis":\{"title":\{"visible":false\}\},"categoryAxis":\{"title":\{"visible":false\}\},| &&
             |"plotArea":\{"isFixedDataPointSize":false,"dataPointSize":\{"min":1\},| &&
             |"colorPalette":["#5899DA","#E8743B","#19A979"],| &&
             |"dataLabel":\{"visible":{ COND string( WHEN data_labels = abap_true THEN `true` ELSE `false` ) }\},| &&
             |"marker":\{"visible":false\}| &&
             |{ COND string( WHEN data_shape IS NOT INITIAL THEN |,"dataShape":\{"primaryAxis":{ data_shape }\}| ) }\}\}|.

  ENDMETHOD.

ENDCLASS.
