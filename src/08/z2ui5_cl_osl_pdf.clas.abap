"! <p class="shorttext">zcl_pdf - PDF without forms in abap2UI5</p>
"!
"! PDF without forms: a letter or an invoice typed into a small form is laid
"! out by https://github.com/beraadim/zcl_pdf - one stand-alone class that
"! writes the PDF bytes itself (built-in Helvetica, Times and Courier, text,
"! wrapped text boxes, shrink-to-fit, rectangles, pages) - and shown in a
"! sap.m.PDFViewer as a data: URI, with a download button. No Adobe Document
"! Server, no SmartForm, no spool: every coordinate, font size, line break
"! and page break is computed in ABAP by zcl_pdf.
"!
"! Everything the library offers is an option: page format (a3, a4, a5,
"! letter, legal), orientation, unit (mm or pt - the library takes whole
"! numbers, so cm and in are too coarse to lay out a page), font family and
"! style, font size, the largest subject size that fits the width
"! (get_max_font_size_for_width), the body shrunk into its box
"! (shrink_font_to_fit_box), left or centred text boxes, rectangle styles
"! (stroke, fill, both), colours through the raw content stream (write),
"! extra pages (add_page). The measurements behind the layout
"! (split_paragraph_to_lines, measure_lines_height, get_current_line_space,
"! get_page_height) are listed next to the document.
"!
"! Notes: zcl_pdf is Standard ABAP, not ABAP Cloud (SSFC_BASE64_DECODE,
"! cl_abap_conv_out_ce, cl_http_utility here). It writes WinAnsi text
"! (code page 1100): a character outside Latin-1 stops the generation with a
"! message. set_font takes the names add_fonts( ) registers, i.e. the
"! CONST_FONT_* and CONST_FONT_STYLE_* constants of zcl_pdf.
"! The viewer frames a data: URI, which the default abap2UI5 CSP allows
"! (default-src data:) - isTrustedSource, because the bytes come from this
"! class. The app reads and writes nothing in the system.
CLASS z2ui5_cl_osl_pdf DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_item,
        description TYPE string,
        quantity    TYPE i,
        price       TYPE p LENGTH 10 DECIMALS 2,
        amount      TYPE p LENGTH 12 DECIMALS 2,
      END OF ty_s_item.
    TYPES ty_t_item TYPE STANDARD TABLE OF ty_s_item WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_fact,
        label TYPE string,
        value TYPE string,
      END OF ty_s_fact.
    TYPES ty_t_fact TYPE STANDARD TABLE OF ty_s_fact WITH EMPTY KEY.

    DATA doc_type        TYPE string.
    DATA sender          TYPE string.
    DATA recipient       TYPE string.
    DATA subject         TYPE string.
    DATA body            TYPE string.
    DATA closing         TYPE string.
    DATA t_items         TYPE ty_t_item.
    DATA total           TYPE p LENGTH 14 DECIMALS 2.
    DATA items_visible   TYPE abap_bool.

    DATA font            TYPE string.
    DATA font_style      TYPE string.
    DATA font_size       TYPE i.
    DATA subject_fit     TYPE abap_bool.
    DATA body_shrink     TYPE abap_bool.
    DATA body_height     TYPE i.
    DATA body_align      TYPE string.
    DATA page_format     TYPE string.
    DATA orientation     TYPE string.
    DATA unit            TYPE string.
    DATA band_style      TYPE string.
    DATA accent          TYPE string.
    DATA show_boxes      TYPE abap_bool.
    DATA terms_page      TYPE abap_bool.

    DATA pdf             TYPE string.
    DATA pdf_ready       TYPE abap_bool.
    DATA file_name       TYPE string.
    DATA t_facts         TYPE ty_t_fact.
    DATA body_hint       TYPE string.
    DATA body_hint_type  TYPE string.

  PROTECTED SECTION.
    TYPES:
      BEGIN OF ty_s_color,
        fill   TYPE string,
        stroke TYPE string,
      END OF ty_s_color.

    DATA client  TYPE REF TO z2ui5_if_client.

    " the document in the making - zcl_pdf is not serializable, so the
    " reference lives for one request and is cleared before the draft is saved
    DATA doc     TYPE REF TO zcl_pdf.
    DATA page_h  TYPE i.
    DATA page_w  TYPE i.
    DATA margin  TYPE i.
    DATA width   TYPE i.
    DATA y       TYPE i.
    DATA page_no TYPE i.

    METHODS view_display.
    METHODS view_document
      IMPORTING
        items TYPE REF TO z2ui5_cl_ui5_view_builder.
    METHODS view_items
      IMPORTING
        items TYPE REF TO z2ui5_cl_ui5_view_builder.
    METHODS view_layout
      IMPORTING
        items TYPE REF TO z2ui5_cl_ui5_view_builder.

    METHODS on_event.
    METHODS model_init.
    METHODS items_demo
      IMPORTING
        count TYPE i.

    METHODS pdf_generate.
    METHODS pdf_header.
    METHODS pdf_subject.
    METHODS pdf_body.
    METHODS pdf_items.
    METHODS pdf_items_head.
    METHODS pdf_closing.
    METHODS pdf_terms.
    METHODS pdf_footer.
    METHODS pdf_page_break
      IMPORTING
        needed TYPE i.
    METHODS pdf_font
      IMPORTING
        style TYPE string.
    METHODS pdf_color.
    METHODS pdf_box
      IMPORTING
        x      TYPE i
        top    TYPE i
        w      TYPE i
        h      TYPE i
        style  TYPE string.
    METHODS fact_add
      IMPORTING
        label TYPE string
        value TYPE string.
    METHODS u
      IMPORTING
        mm            TYPE i
      RETURNING
        VALUE(result) TYPE i.

    CLASS-METHODS paragraphs
      IMPORTING
        val           TYPE string
      RETURNING
        VALUE(result) TYPE string.
    CLASS-METHODS one_line
      IMPORTING
        val           TYPE string
      RETURNING
        VALUE(result) TYPE string.
    CLASS-METHODS color
      IMPORTING
        accent        TYPE string
      RETURNING
        VALUE(result) TYPE ty_s_color.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_osl_pdf IMPLEMENTATION.

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
            )->a( n = `xmlns:f`      v = `sap.ui.layout.form`
            )->ele( `Shell`
                )->a( n = `appWidthLimited` v = `false`
                )->ele( `Page`
                    )->a( n = `title`          v = `PDF without forms - zcl_pdf x abap2UI5`
                    )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
                    )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    page->ele( `headerContent`
        )->tag( `Button`
            )->a( n = `text`  v = `Generate PDF`
            )->a( n = `icon`  v = `sap-icon://pdf-attachment`
            )->a( n = `type`  v = `Emphasized`
            )->a( n = `press` v = client->_event( `GENERATE` )
        )->tag( `Button`
            )->a( n = `text`    v = `Download`
            )->a( n = `icon`    v = `sap-icon://download`
            )->a( n = `type`    v = `Transparent`
            )->a( n = `enabled` v = client->_bind( pdf_ready )
            )->a( n = `press`   v = client->_event( `DOWNLOAD` )
        )->tag( `Link`
            )->a( n = `text`   v = `beraadim/zcl_pdf`
            )->a( n = `href`   v = `https://github.com/beraadim/zcl_pdf`
            )->a( n = `target` v = `_blank` ).

    DATA(grid) = page->ele( `content`
        )->ele( n = `Grid` ns = `l`
            )->a( n = `defaultSpan` v = `XL5 L5 M12 S12`
            )->a( n = `class`       v = `sapUiSmallMargin` ).

    DATA(left) = grid->ele( `VBox` ).

    DATA(items) = left->ele( `IconTabBar`
        )->a( n = `expandable` v = `false`
        )->ele( `items` ).

    view_document( items ).
    view_items( items ).
    view_layout( items ).

    left->tag( `MessageStrip`
        )->a( n = `text`     v = client->_bind( body_hint )
        )->a( n = `type`     v = client->_bind( body_hint_type )
        )->a( n = `showIcon` v = `true`
        )->a( n = `class`    v = `sapUiSmallMarginTop` ).

    left->ele( `List`
        )->a( n = `headerText` v = `Measured by zcl_pdf`
        )->a( n = `items`      v = client->_bind( t_facts )
        )->a( n = `class`      v = `sapUiSmallMarginTop`
        )->ele( `items`
            )->tag( `DisplayListItem`
                )->a( n = `label` v = `{LABEL}`
                )->a( n = `value` v = `{VALUE}` ).

    grid->ele( `VBox`
        )->ele( `layoutData`
            )->tag( n = `GridData` ns = `l`
                )->a( n = `span` v = `XL7 L7 M12 S12`
        )->end(
        )->tag( `PDFViewer`
            )->a( n = `source`          v = client->_bind( pdf )
            )->a( n = `title`           v = client->_bind( file_name )
            )->a( n = `height`          v = `85vh`
            )->a( n = `width`           v = `100%`
            )->a( n = `isTrustedSource` v = `true` ).

    client->view_display( page->stringify( ) ).

  ENDMETHOD.


  METHOD view_document.

    DATA(form) = items->ele( `IconTabFilter`
        )->a( n = `text` v = `Document`
        )->a( n = `icon` v = `sap-icon://email`
        )->ele( `content`
            )->ele( n = `SimpleForm` ns = `f`
                )->a( n = `editable` v = `true`
                )->a( n = `layout`   v = `ResponsiveGridLayout` ).

    form->tag( `Label`
        )->a( n = `text` v = `Type`
        )->ele( `SegmentedButton`
            )->a( n = `selectedKey`     v = client->_bind( doc_type )
            )->a( n = `selectionChange` v = client->_event( `GENERATE` )
            )->ele( `items`
                )->tag( `SegmentedButtonItem`
                    )->a( n = `key`  v = `LETTER`
                    )->a( n = `text` v = `Letter`
                )->tag( `SegmentedButtonItem`
                    )->a( n = `key`  v = `INVOICE`
                    )->a( n = `text` v = `Invoice` ).

    form->tag( `Label`
        )->a( n = `text` v = `Sender`
        )->tag( `Input`
            )->a( n = `value` v = client->_bind( sender )
        )->tag( `Label`
            )->a( n = `text` v = `Recipient`
        )->tag( `TextArea`
            )->a( n = `value` v = client->_bind( recipient )
            )->a( n = `rows`  v = `4`
        )->tag( `Label`
            )->a( n = `text` v = `Subject`
        )->tag( `Input`
            )->a( n = `value` v = client->_bind( subject )
        )->tag( `Label`
            )->a( n = `text` v = `Body text`
        )->tag( `TextArea`
            )->a( n = `value`     v = client->_bind( body )
            )->a( n = `rows`      v = `9`
            )->a( n = `growing`   v = `true`
            )->a( n = `maxLength` v = `20000`
        )->tag( `Label`
            )->a( n = `text` v = `Closing`
        )->tag( `TextArea`
            )->a( n = `value` v = client->_bind( closing )
            )->a( n = `rows`  v = `3`
        )->tag( `Label`
            )->a( n = `text` v = `Try it`
        )->tag( `Button`
            )->a( n = `text`  v = `Long body text`
            )->a( n = `icon`  v = `sap-icon://text`
            )->a( n = `press` v = client->_event( `TEXT_LONG` )
        )->tag( `Button`
            )->a( n = `text`  v = `Short body text`
            )->a( n = `icon`  v = `sap-icon://less`
            )->a( n = `press` v = client->_event( `TEXT_SHORT` ) ).

  ENDMETHOD.


  METHOD view_items.

    DATA(content) = items->ele( `IconTabFilter`
        )->a( n = `text`    v = `Line items`
        )->a( n = `icon`    v = `sap-icon://list`
        )->a( n = `visible` v = client->_bind( items_visible )
        )->ele( `content` ).

    content->ele( `OverflowToolbar`
        )->a( n = `style` v = `Clear`
        )->ele( `content`
            )->tag( `Button`
                )->a( n = `text`  v = `Add item`
                )->a( n = `icon`  v = `sap-icon://add`
                )->a( n = `press` v = client->_event( `ITEM_ADD` )
            )->tag( `Button`
                )->a( n = `text`  v = `Remove last`
                )->a( n = `icon`  v = `sap-icon://less`
                )->a( n = `press` v = client->_event( `ITEM_REMOVE` )
            )->tag( `Button`
                )->a( n = `text`  v = `Add 40 items (page breaks)`
                )->a( n = `icon`  v = `sap-icon://documents`
                )->a( n = `press` v = client->_event( `ITEMS_MANY` )
            )->tag( `ToolbarSpacer`
            )->tag( `ObjectNumber`
                )->a( n = `number`     v = client->_bind( total )
                )->a( n = `unit`       v = `EUR`
                )->a( n = `emphasized` v = `true` ).

    DATA(table) = content->ele( `Table`
        )->a( n = `items` v = client->_bind( t_items ) ).

    " header is the default aggregation of sap.m.Column
    table->ele( `columns`
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Description`
        )->end(
        )->ele( `Column`
            )->a( n = `width` v = `8rem`
            )->tag( `Text`
                )->a( n = `text` v = `Quantity`
        )->end(
        )->ele( `Column`
            )->a( n = `width` v = `10rem`
            )->tag( `Text`
                )->a( n = `text` v = `Price`
        )->end(
        )->ele( `Column`
            )->a( n = `width`  v = `7rem`
            )->a( n = `hAlign` v = `End`
            )->tag( `Text`
                )->a( n = `text` v = `Amount` ).

    table->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells`
                )->tag( `Input`
                    )->a( n = `value` v = `{DESCRIPTION}`
                )->tag( `StepInput`
                    )->a( n = `value` v = `{QUANTITY}`
                    )->a( n = `min`   v = `0`
                    )->a( n = `max`   v = `9999`
                )->tag( `StepInput`
                    )->a( n = `value`                 v = `{PRICE}`
                    )->a( n = `min`                   v = `0`
                    )->a( n = `max`                   v = `99999`
                    )->a( n = `step`                  v = `0.5`
                    )->a( n = `displayValuePrecision` v = `2`
                )->tag( `ObjectNumber`
                    )->a( n = `number` v = `{AMOUNT}` ).

  ENDMETHOD.


  METHOD view_layout.

    DATA(form) = items->ele( `IconTabFilter`
        )->a( n = `text` v = `Typography and layout`
        )->a( n = `icon` v = `sap-icon://text-formatting`
        )->ele( `content`
            )->ele( n = `SimpleForm` ns = `f`
                )->a( n = `editable` v = `true`
                )->a( n = `layout`   v = `ResponsiveGridLayout` ).

    form->tag( `Label`
        )->a( n = `text` v = `Font`
        )->ele( `Select`
            )->a( n = `selectedKey` v = client->_bind( font )
            )->a( n = `change`      v = client->_event( `GENERATE` )
            )->tag( n = `Item` ns = `core`
                )->a( n = `key`  v = `HELVETICA`
                )->a( n = `text` v = `Helvetica`
            )->tag( n = `Item` ns = `core`
                )->a( n = `key`  v = `TIMES`
                )->a( n = `text` v = `Times`
            )->tag( n = `Item` ns = `core`
                )->a( n = `key`  v = `COURIER`
                )->a( n = `text` v = `Courier`
        )->end(
        )->tag( `Label`
            )->a( n = `text` v = `Body style`
        )->ele( `Select`
            )->a( n = `selectedKey` v = client->_bind( font_style )
            )->a( n = `change`      v = client->_event( `GENERATE` )
            )->tag( n = `Item` ns = `core`
                )->a( n = `key`  v = `NORMAL`
                )->a( n = `text` v = `Normal`
            )->tag( n = `Item` ns = `core`
                )->a( n = `key`  v = `BOLD`
                )->a( n = `text` v = `Bold`
            )->tag( n = `Item` ns = `core`
                )->a( n = `key`  v = `ITALIC`
                )->a( n = `text` v = `Italic`
            )->tag( n = `Item` ns = `core`
                )->a( n = `key`  v = `BOLDITALIC`
                )->a( n = `text` v = `Bold italic`
        )->end(
        )->tag( `Label`
            )->a( n = `text` v = `Font size (pt)`
        )->tag( `StepInput`
            )->a( n = `value`  v = client->_bind( font_size )
            )->a( n = `min`    v = `6`
            )->a( n = `max`    v = `36`
            )->a( n = `change` v = client->_event( `GENERATE` )
        )->tag( `Label`
            )->a( n = `text` v = `Subject as large as the width allows`
        )->tag( `Switch`
            )->a( n = `state`  v = client->_bind( subject_fit )
            )->a( n = `change` v = client->_event( `GENERATE` )
        )->tag( `Label`
            )->a( n = `text` v = `Shrink body text to fit its box`
        )->tag( `Switch`
            )->a( n = `state`  v = client->_bind( body_shrink )
            )->a( n = `change` v = client->_event( `GENERATE` )
        )->tag( `Label`
            )->a( n = `text` v = `Body box height (mm)`
        )->tag( `StepInput`
            )->a( n = `value`  v = client->_bind( body_height )
            )->a( n = `min`    v = `20`
            )->a( n = `max`    v = `250`
            )->a( n = `step`   v = `5`
            )->a( n = `change` v = client->_event( `GENERATE` )
        )->tag( `Label`
            )->a( n = `text` v = `Body alignment`
        )->ele( `SegmentedButton`
            )->a( n = `selectedKey`     v = client->_bind( body_align )
            )->a( n = `selectionChange` v = client->_event( `GENERATE` )
            )->ele( `items`
                )->tag( `SegmentedButtonItem`
                    )->a( n = `key`  v = `LEFT`
                    )->a( n = `text` v = `Left`
                )->tag( `SegmentedButtonItem`
                    )->a( n = `key`  v = `MIDDLE`
                    )->a( n = `text` v = `Centred`
            )->end(
        )->end(
        )->tag( `Label`
            )->a( n = `text` v = `Page format`
        )->ele( `Select`
            )->a( n = `selectedKey` v = client->_bind( page_format )
            )->a( n = `change`      v = client->_event( `GENERATE` )
            )->tag( n = `Item` ns = `core`
                )->a( n = `key`  v = `a3`
                )->a( n = `text` v = `A3`
            )->tag( n = `Item` ns = `core`
                )->a( n = `key`  v = `a4`
                )->a( n = `text` v = `A4`
            )->tag( n = `Item` ns = `core`
                )->a( n = `key`  v = `a5`
                )->a( n = `text` v = `A5`
            )->tag( n = `Item` ns = `core`
                )->a( n = `key`  v = `letter`
                )->a( n = `text` v = `US Letter`
            )->tag( n = `Item` ns = `core`
                )->a( n = `key`  v = `legal`
                )->a( n = `text` v = `US Legal`
        )->end(
        )->tag( `Label`
            )->a( n = `text` v = `Orientation`
        )->ele( `SegmentedButton`
            )->a( n = `selectedKey`     v = client->_bind( orientation )
            )->a( n = `selectionChange` v = client->_event( `GENERATE` )
            )->ele( `items`
                )->tag( `SegmentedButtonItem`
                    )->a( n = `key`  v = `p`
                    )->a( n = `text` v = `Portrait`
                )->tag( `SegmentedButtonItem`
                    )->a( n = `key`  v = `l`
                    )->a( n = `text` v = `Landscape`
            )->end(
        )->end(
        )->tag( `Label`
            )->a( n = `text` v = `Unit of the coordinates`
        )->ele( `SegmentedButton`
            )->a( n = `selectedKey`     v = client->_bind( unit )
            )->a( n = `selectionChange` v = client->_event( `GENERATE` )
            )->ele( `items`
                )->tag( `SegmentedButtonItem`
                    )->a( n = `key`  v = `mm`
                    )->a( n = `text` v = `mm`
                )->tag( `SegmentedButtonItem`
                    )->a( n = `key`  v = `pt`
                    )->a( n = `text` v = `pt`
            )->end(
        )->end(
        )->tag( `Label`
            )->a( n = `text` v = `Header band (rectangle style)`
        )->ele( `SegmentedButton`
            )->a( n = `selectedKey`     v = client->_bind( band_style )
            )->a( n = `selectionChange` v = client->_event( `GENERATE` )
            )->ele( `items`
                )->tag( `SegmentedButtonItem`
                    )->a( n = `key`  v = `S`
                    )->a( n = `text` v = `Stroke`
                )->tag( `SegmentedButtonItem`
                    )->a( n = `key`  v = `F`
                    )->a( n = `text` v = `Fill`
                )->tag( `SegmentedButtonItem`
                    )->a( n = `key`  v = `FD`
                    )->a( n = `text` v = `Both`
            )->end(
        )->end(
        )->tag( `Label`
            )->a( n = `text` v = `Accent colour`
        )->ele( `Select`
            )->a( n = `selectedKey` v = client->_bind( accent )
            )->a( n = `change`      v = client->_event( `GENERATE` )
            )->tag( n = `Item` ns = `core`
                )->a( n = `key`  v = `GREY`
                )->a( n = `text` v = `Grey`
            )->tag( n = `Item` ns = `core`
                )->a( n = `key`  v = `BLUE`
                )->a( n = `text` v = `Blue`
            )->tag( n = `Item` ns = `core`
                )->a( n = `key`  v = `GREEN`
                )->a( n = `text` v = `Green`
            )->tag( n = `Item` ns = `core`
                )->a( n = `key`  v = `SAND`
                )->a( n = `text` v = `Sand`
        )->end(
        )->tag( `Label`
            )->a( n = `text` v = `Outline the text boxes`
        )->tag( `Switch`
            )->a( n = `state`  v = client->_bind( show_boxes )
            )->a( n = `change` v = client->_event( `GENERATE` )
        )->tag( `Label`
            )->a( n = `text` v = `Append a terms page`
        )->tag( `Switch`
            )->a( n = `state`  v = client->_bind( terms_page )
            )->a( n = `change` v = client->_event( `GENERATE` ) ).

  ENDMETHOD.


  METHOD on_event.

    CASE client->get_event( ).

      WHEN `GENERATE`.
        pdf_generate( ).

      WHEN `TEXT_LONG`.
        CLEAR body.
        DO 6 TIMES.
          body = |{ body }{ sy-index }. This paragraph is long on purpose. zcl_pdf measures every word | &&
                 |with the metrics of the chosen font, wraps the text at the width of the box and, | &&
                 |when asked to, lowers the font size until all lines fit into the height of the box.| &&
                 |{ cl_abap_char_utilities=>newline }|.
        ENDDO.
        pdf_generate( ).

      WHEN `TEXT_SHORT`.
        body = `Thank you for your order. Please find the details below.`.
        pdf_generate( ).

      WHEN `ITEM_ADD`.
        items_demo( 1 ).
        pdf_generate( ).

      WHEN `ITEM_REMOVE`.
        IF t_items IS NOT INITIAL.
          DELETE t_items INDEX lines( t_items ).
        ENDIF.
        pdf_generate( ).

      WHEN `ITEMS_MANY`.
        items_demo( 40 ).
        pdf_generate( ).

      WHEN `DOWNLOAD`.
        IF pdf_ready = abap_true.
          client->follow_up_action( val   = client->cs_event-download_b64_file
                                    t_arg = VALUE #( ( pdf )
                                                     ( file_name ) ) ).
        ENDIF.

    ENDCASE.

  ENDMETHOD.


  METHOD model_init.

    DATA(nl) = cl_abap_char_utilities=>newline.

    doc_type    = `INVOICE`.
    sender      = `ACME Widgets Ltd. - 1 Main Street - 12345 Springfield`.
    recipient   = |Jane Doe{ nl }Example Corp.{ nl }42 Harbour Road{ nl }54321 Shelbyville|.
    subject     = `Invoice 2026-0815 for your order of September`.
    body        = |Dear Ms Doe,{ nl }| &&
                  |thank you for your order. This document was not designed in a form editor: | &&
                  |every line of it was placed by zcl_pdf, one ABAP class that writes the PDF bytes | &&
                  |itself - fonts, text boxes with automatic line breaks, rectangles and pages. | &&
                  |Change the text, the font or the page format on the left and generate again.|.
    closing     = |Kind regards,{ nl }{ nl }ACME Widgets Ltd.|.
    items_demo( 4 ).

    font        = `HELVETICA`.
    font_style  = `NORMAL`.
    font_size   = 11.
    subject_fit = abap_false.
    body_shrink = abap_true.
    body_height = 40.
    body_align  = `LEFT`.
    page_format = `a4`.
    orientation = `p`.
    unit        = `mm`.
    band_style  = `F`.
    accent      = `BLUE`.
    show_boxes  = abap_false.
    terms_page  = abap_false.

    pdf_generate( ).

  ENDMETHOD.


  METHOD items_demo.

    DATA(names) = VALUE string_table( ( `Widget, standard` )
                                      ( `Widget, deluxe` )
                                      ( `Mounting kit` )
                                      ( `Installation (hours)` )
                                      ( `Extended warranty, 2 years` )
                                      ( `Shipping and handling` ) ).

    DO count TIMES.
      DATA(index) = lines( t_items ) MOD lines( names ) + 1.
      APPEND VALUE #( description = names[ index ]
                      quantity    = index MOD 3 + 1
                      price       = index * 12 + '9.9' ) TO t_items.
    ENDDO.

  ENDMETHOD.


  METHOD pdf_generate.

    items_visible = xsdbool( doc_type = `INVOICE` ).
    CLEAR: t_facts, total, pdf, pdf_ready.

    TRY.
        doc = NEW zcl_pdf( iv_orientation = orientation
                           iv_unit        = unit
                           iv_format      = page_format ).

        " the library tells the page height only - the width is the height of
        " the same format turned by 90 degrees
        page_h = doc->get_page_height( ).
        page_w = NEW zcl_pdf( iv_orientation = COND #( WHEN orientation = `p` THEN `l` ELSE `p` )
                              iv_unit        = unit
                              iv_format      = page_format )->get_page_height( ).
        margin  = u( 20 ).
        width   = page_w - 2 * margin.
        page_no = 1.
        doc->set_font_size( font_size ).

        pdf_header( ).
        pdf_subject( ).
        pdf_body( ).
        IF doc_type = `INVOICE`.
          pdf_items( ).
        ENDIF.
        pdf_closing( ).
        IF terms_page = abap_true.
          pdf_page_break( page_h ).
          pdf_terms( ).
        ENDIF.
        pdf_footer( ).

        DATA(content) = doc->output( ).
        pdf       = `data:application/pdf;base64,` && cl_http_utility=>encode_x_base64( content ).
        pdf_ready = abap_true.
        file_name = |{ to_lower( doc_type ) }_{ page_format }_{ to_lower( font ) }.pdf|.

        fact_add( label = `Page size`
                  value = |{ page_w } x { page_h } { unit } (get_page_height)| ).
        fact_add( label = `Pages`
                  value = |{ page_no }| ).
        fact_add( label = `PDF size`
                  value = |{ xstrlen( content ) } bytes (output)| ).

      CATCH cx_root INTO DATA(error).
        client->message_box_display( error ).
    ENDTRY.

    CLEAR doc.

  ENDMETHOD.


  METHOD pdf_header.

    DATA(band) = u( 18 ).
    pdf_color( ).
    doc->rect( iv_x      = margin
               iv_y      = margin
               iv_width  = width
               iv_heigth = band
               iv_style  = band_style ).

    doc->set_font_size( 18 ).
    pdf_font( `BOLD` ).
    doc->text_box( iv_text      = COND #( WHEN doc_type = `INVOICE` THEN `INVOICE` ELSE `LETTER` )
                   iv_x         = margin
                   iv_y         = margin + u( 5 )
                   iv_width     = width
                   iv_height    = band
                   iv_hor_align = zcl_pdf=>const_hor_text_align_middle ).

    doc->set_font_size( 8 ).
    pdf_font( `NORMAL` ).
    doc->text( iv_text = one_line( sender )
               iv_x    = margin
               iv_y    = margin + band + u( 6 ) ).

    doc->set_font_size( font_size ).
    DATA(top) = margin + band + u( 10 ).
    DATA(box_w) = width / 2.
    DATA(box_h) = u( 30 ).
    IF show_boxes = abap_true.
      pdf_box( x     = margin
               top   = top
               w     = box_w
               h     = box_h
               style = `S` ).
    ENDIF.
    doc->text_box( iv_text   = paragraphs( recipient )
                   iv_x      = margin
                   iv_y      = top
                   iv_width  = box_w
                   iv_height = box_h ).

    doc->text( iv_text = |Date: { sy-datum DATE = ISO }|
               iv_x    = margin + width - u( 45 )
               iv_y    = top + doc->get_current_line_space( ) ).

    y = top + box_h + u( 8 ).

  ENDMETHOD.


  METHOD pdf_subject.

    DATA(text) = one_line( subject ).
    DATA(size) = font_size + 2.
    " get_max_font_size_for_width grows the size until the text is wider than
    " the box - only a text with measurable characters ever gets there
    IF subject_fit = abap_true AND find( val = text regex = `[A-Za-z0-9]` ) >= 0.
      pdf_font( `BOLD` ).
      size = nmin( val1 = doc->get_max_font_size_for_width( iv_text      = text
                                                            iv_max_width = width )
                   val2 = 40 ).
    ENDIF.
    fact_add( label = `Subject font size`
              value = |{ size } pt{ COND #( WHEN subject_fit = abap_true
                                            THEN ` (get_max_font_size_for_width, at most 40)` ) }| ).

    doc->set_font_size( size ).
    pdf_font( `BOLD` ).
    y = doc->text_box( iv_text   = text
                       iv_x      = margin
                       iv_y      = y
                       iv_width  = width
                       iv_height = doc->get_current_line_space( ) ) + u( 4 ).
    doc->set_font_size( font_size ).

  ENDMETHOD.


  METHOD pdf_body.

    DATA(text) = paragraphs( body ).
    DATA(box_h) = nmax( val1 = nmin( val1 = u( body_height )
                                     val2 = page_h - margin - u( 30 ) - y )
                        val2 = u( 10 ) ).
    pdf_font( font_style ).

    DATA(size) = font_size.
    IF body_shrink = abap_true.
      size = nmax( val1 = doc->shrink_font_to_fit_box( iv_text       = text
                                                       iv_max_width  = width
                                                       iv_max_height = box_h )
                   val2 = 4 ).
    ENDIF.
    doc->set_font_size( size ).

    DATA(body_lines) = doc->split_paragraph_to_lines( iv_string = text
                                                 iv_maxlen = width ).
    DATA(needed) = doc->measure_lines_height( body_lines ).
    DATA(space) = doc->get_current_line_space( ).
    DATA(shown) = COND i( WHEN space > 0 THEN box_h DIV space ELSE 0 ).

    fact_add( label = `Body font size`
              value = |{ size } pt{ COND #( WHEN body_shrink = abap_true
                                            THEN |, shrunk from { font_size } (shrink_font_to_fit_box)| ) }| ).
    fact_add( label = `Line spacing`
              value = |{ space } { unit } (get_current_line_space)| ).
    fact_add( label = `Body lines`
              value = |{ lines( body_lines ) } (split_paragraph_to_lines)| ).
    fact_add( label = `Body height`
              value = |{ needed } of { box_h } { unit } (measure_lines_height)| ).

    IF lines( body_lines ) > shown.
      body_hint_type = `Warning`.
      body_hint = |The body needs { lines( body_lines ) } lines, its box holds { shown }: text_box cuts it off. | &&
                  |Switch on "Shrink body text" or make the box taller.|.
    ELSE.
      body_hint_type = `Success`.
      body_hint = |The body fits its box: { lines( body_lines ) } lines at { size } pt in { box_h } { unit }.|.
    ENDIF.

    IF show_boxes = abap_true.
      pdf_box( x     = margin
               top   = y
               w     = width
               h     = box_h
               style = `S` ).
    ENDIF.
    doc->text_box( iv_text      = text
                   iv_x         = margin
                   iv_y         = y
                   iv_width     = width
                   iv_height    = box_h
                   iv_hor_align = COND #( WHEN body_align = `MIDDLE`
                                          THEN zcl_pdf=>const_hor_text_align_middle
                                          ELSE zcl_pdf=>const_hor_text_align_left ) ).

    doc->set_font_size( font_size ).
    y = y + box_h + u( 6 ).

  ENDMETHOD.


  METHOD pdf_items.

    LOOP AT t_items REFERENCE INTO DATA(item).
      item->amount = item->quantity * item->price.
      total = total + item->amount.
    ENDLOOP.

    pdf_items_head( ).
    DATA(row_h) = doc->get_current_line_space( ) + u( 2 ).
    DATA(column) = width / 6.

    LOOP AT t_items INTO DATA(row).
      IF y + row_h > page_h - margin - u( 10 ).
        pdf_page_break( row_h ).
        pdf_items_head( ).
      ENDIF.
      pdf_font( font_style ).
      " one line per cell - text_box stops after the first line of its height
      doc->text_box( iv_text   = one_line( row-description )
                     iv_x      = margin + u( 2 )
                     iv_y      = y
                     iv_width  = 3 * column - u( 4 )
                     iv_height = doc->get_current_line_space( ) ).
      doc->text_box( iv_text      = |{ row-quantity }|
                     iv_x         = margin + 3 * column
                     iv_y         = y
                     iv_width     = column
                     iv_height    = doc->get_current_line_space( )
                     iv_hor_align = zcl_pdf=>const_hor_text_align_middle ).
      doc->text_box( iv_text      = |{ row-price NUMBER = USER }|
                     iv_x         = margin + 4 * column
                     iv_y         = y
                     iv_width     = column
                     iv_height    = doc->get_current_line_space( )
                     iv_hor_align = zcl_pdf=>const_hor_text_align_middle ).
      doc->text_box( iv_text      = |{ row-amount NUMBER = USER }|
                     iv_x         = margin + 5 * column
                     iv_y         = y
                     iv_width     = column
                     iv_height    = doc->get_current_line_space( )
                     iv_hor_align = zcl_pdf=>const_hor_text_align_middle ).
      y = y + row_h.
    ENDLOOP.

    pdf_page_break( 2 * row_h ).
    pdf_color( ).
    doc->rect( iv_x      = margin + 4 * column
               iv_y      = y
               iv_width  = 2 * column
               iv_heigth = row_h
               iv_style  = `S` ).
    pdf_font( `BOLD` ).
    doc->text_box( iv_text      = |Total EUR { total NUMBER = USER }|
                   iv_x         = margin + 4 * column
                   iv_y         = y
                   iv_width     = 2 * column
                   iv_height    = doc->get_current_line_space( )
                   iv_hor_align = zcl_pdf=>const_hor_text_align_middle ).
    y = y + row_h + u( 8 ).

    fact_add( label = `Line items`
              value = |{ lines( t_items ) }, total EUR { total NUMBER = USER }| ).

  ENDMETHOD.


  METHOD pdf_items_head.

    DATA(row_h) = doc->get_current_line_space( ) + u( 2 ).
    DATA(column) = width / 6.

    pdf_color( ).
    doc->rect( iv_x      = margin
               iv_y      = y
               iv_width  = width
               iv_heigth = row_h
               iv_style  = `FD` ).
    pdf_font( `BOLD` ).
    doc->text( iv_text = `Description`
               iv_x    = margin + u( 2 )
               iv_y    = y + doc->get_current_line_space( ) ).
    doc->text_box( iv_text      = `Quantity`
                   iv_x         = margin + 3 * column
                   iv_y         = y
                   iv_width     = column
                   iv_height    = doc->get_current_line_space( )
                   iv_hor_align = zcl_pdf=>const_hor_text_align_middle ).
    doc->text_box( iv_text      = `Price`
                   iv_x         = margin + 4 * column
                   iv_y         = y
                   iv_width     = column
                   iv_height    = doc->get_current_line_space( )
                   iv_hor_align = zcl_pdf=>const_hor_text_align_middle ).
    doc->text_box( iv_text      = `Amount`
                   iv_x         = margin + 5 * column
                   iv_y         = y
                   iv_width     = column
                   iv_height    = doc->get_current_line_space( )
                   iv_hor_align = zcl_pdf=>const_hor_text_align_middle ).
    y = y + row_h + u( 1 ).

  ENDMETHOD.


  METHOD pdf_closing.

    DATA(text) = paragraphs( closing ).
    pdf_font( font_style ).
    DATA(needed) = doc->measure_lines_height( doc->split_paragraph_to_lines( iv_string = text
                                                                             iv_maxlen = width ) ).
    pdf_page_break( needed + doc->get_current_line_space( ) ).
    y = doc->text_box( iv_text   = text
                       iv_x      = margin
                       iv_y      = y
                       iv_width  = width
                       iv_height = needed + doc->get_current_line_space( ) ).

  ENDMETHOD.


  METHOD pdf_terms.

    DATA(nl) = cl_abap_char_utilities=>cr_lf.

    doc->set_font_size( font_size + 4 ).
    pdf_font( `BOLD` ).
    y = doc->text( iv_text = `Terms and conditions`
                   iv_x    = margin
                   iv_y    = y ) + u( 4 ).

    doc->set_font_size( font_size - 2 ).
    pdf_font( font_style ).
    doc->text_box( iv_text   = |1. Payment is due within 30 days of the invoice date without deduction.{ nl }| &&
                               |2. The goods remain our property until paid in full.{ nl }| &&
                               |3. This page was appended with add_page( ); its text box wraps and | &&
                               |breaks lines with the font metrics of the chosen font, measured in ABAP.|
                   iv_x      = margin
                   iv_y      = y
                   iv_width  = width
                   iv_height = page_h - y - 2 * margin ).
    doc->set_font_size( font_size ).

  ENDMETHOD.


  METHOD pdf_footer.

    doc->set_font_size( 8 ).
    pdf_font( `NORMAL` ).
    doc->text( iv_text = |Page { page_no } - written by zcl_pdf|
               iv_x    = margin
               iv_y    = page_h - u( 10 ) ).
    doc->set_font_size( font_size ).

  ENDMETHOD.


  METHOD pdf_page_break.

    IF y + needed <= page_h - margin - u( 10 ).
      RETURN.
    ENDIF.
    DATA(size) = doc->get_font_size( ).
    pdf_footer( ).
    doc->add_page( ).
    page_no = page_no + 1.
    y = margin.
    doc->set_font_size( size ).

  ENDMETHOD.


  METHOD pdf_font.

    " set_font looks the font up by the names add_fonts( ) registered -
    " the const_font_* and const_font_style_* constants of zcl_pdf
    DATA(effective) = style.
    IF style = `BOLD` AND font_style CS `ITALIC`.
      effective = `BOLDITALIC`.
    ENDIF.

    doc->set_font( iv_font_name  = SWITCH #( font
                       WHEN `TIMES`   THEN zcl_pdf=>const_font_times
                       WHEN `COURIER` THEN zcl_pdf=>const_font_courier
                       ELSE zcl_pdf=>const_font_helvetica )
                   iv_font_style = SWITCH #( effective
                       WHEN `BOLD`       THEN zcl_pdf=>const_font_style_bold
                       WHEN `ITALIC`     THEN zcl_pdf=>const_font_style_italic
                       WHEN `BOLDITALIC` THEN zcl_pdf=>const_font_style_bold_italic
                       ELSE zcl_pdf=>const_font_style_normal ) ).

  ENDMETHOD.


  METHOD pdf_color.

    " zcl_pdf draws in black; write( ) puts raw operators into the page
    " stream - rg sets the fill colour, RG the stroke colour
    DATA(rgb) = color( accent ).
    doc->write( |{ rgb-fill } rg| ).
    doc->write( |{ rgb-stroke } RG| ).

  ENDMETHOD.


  METHOD pdf_box.

    doc->write( `0.6 0.6 0.6 RG` ).
    doc->rect( iv_x      = x
               iv_y      = top
               iv_width  = w
               iv_heigth = h
               iv_style  = style ).

  ENDMETHOD.


  METHOD fact_add.

    APPEND VALUE #( label = label
                    value = value ) TO t_facts.

  ENDMETHOD.


  METHOD u.

    " the layout is planned in mm; zcl_pdf takes whole numbers in its unit
    result = COND #( WHEN unit = `pt` THEN mm * 720 / 254 ELSE mm ).

  ENDMETHOD.


  METHOD paragraphs.

    " zcl_pdf breaks paragraphs at CR LF, the browser sends LF
    result = replace( val  = val
                      sub  = cl_abap_char_utilities=>cr_lf
                      with = cl_abap_char_utilities=>newline
                      occ  = 0 ).
    result = replace( val  = result
                      sub  = cl_abap_char_utilities=>newline
                      with = cl_abap_char_utilities=>cr_lf
                      occ  = 0 ).

  ENDMETHOD.


  METHOD one_line.

    result = replace( val  = val
                      sub  = cl_abap_char_utilities=>cr_lf
                      with = ` `
                      occ  = 0 ).
    result = replace( val  = result
                      sub  = cl_abap_char_utilities=>newline
                      with = ` `
                      occ  = 0 ).

  ENDMETHOD.


  METHOD color.

    result = SWITCH #( accent
        WHEN `GREY`  THEN VALUE #( fill = `0.92 0.92 0.92` stroke = `0.45 0.45 0.45` )
        WHEN `GREEN` THEN VALUE #( fill = `0.86 0.95 0.87` stroke = `0.20 0.55 0.30` )
        WHEN `SAND`  THEN VALUE #( fill = `0.98 0.93 0.82` stroke = `0.70 0.50 0.15` )
        ELSE              VALUE #( fill = `0.84 0.90 0.98` stroke = `0.20 0.40 0.75` ) ).

  ENDMETHOD.

ENDCLASS.
