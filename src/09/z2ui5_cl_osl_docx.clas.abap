"! <p class="shorttext">zcl_docx Word documents with abap2UI5</p>
"!
"! A delivery note or invoice form whose data
"! https://github.com/AntonSikidin/zcl_docx turns into a Word .docx:
"! zcl_docx3=>get_document fills the tagged content controls of a template
"! (plain fields, a structure, a repeated table row, repeated paragraphs,
"! checkboxes) and returns the finished file, which the browser downloads.
"!
"! No SMW0 object is needed: the app builds the template itself in ABAP (an
"! Office Open XML package written with cl_abap_zip, with the font, colors
"! and table borders chosen on the Template tab) and hands it to the library
"! through iv_template. Alternatively a .docx with content controls tagged
"! like the listed tags can be uploaded and is used instead. The Preview tab
"! shows the text of the generated document and the asXML data the library
"! matches the tags against. The app reads no data from the system and
"! writes nothing - iv_no_save keeps the library from its SAP GUI download.
"!
"! A tag that is also the name of a DDIC table or structure is renamed to
"! item by the library before matching - hence the DOC_/SHIP_/ITEM_ prefixes.
CLASS z2ui5_cl_osl_docx DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES ty_amount TYPE p LENGTH 15 DECIMALS 2.

    TYPES:
      BEGIN OF ty_s_item,
        pos    TYPE i,
        text   TYPE string,
        qty    TYPE i,
        unit   TYPE string,
        price  TYPE ty_amount,
        amount TYPE ty_amount,
      END OF ty_s_item.
    TYPES ty_t_item TYPE STANDARD TABLE OF ty_s_item WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_form,
        doc_type  TYPE string,
        doc_no    TYPE string,
        doc_date  TYPE string,
        sender    TYPE string,
        name      TYPE string,
        street    TYPE string,
        city      TYPE string,
        country   TYPE string,
        currency  TYPE string,
        vat_rate  TYPE p LENGTH 5 DECIMALS 1,
        express   TYPE abap_bool,
        fragile   TYPE abap_bool,
        signature TYPE abap_bool,
        signed_by TYPE string,
        remarks   TYPE string,
      END OF ty_s_form.

    TYPES:
      BEGIN OF ty_s_layout,
        source       TYPE string,
        font         TYPE string,
        font_size    TYPE i,
        accent       TYPE string,
        borders      TYPE string,
        shade_header TYPE abap_bool,
        protect      TYPE abap_bool,
      END OF ty_s_layout.

    TYPES:
      BEGIN OF ty_s_tag,
        tag         TYPE string,
        kind        TYPE string,
        parent      TYPE string,
        description TYPE string,
        found       TYPE string,
        state       TYPE string,
      END OF ty_s_tag.
    TYPES ty_t_tag TYPE STANDARD TABLE OF ty_s_tag WITH EMPTY KEY.

    DATA tab            TYPE string.
    DATA form           TYPE ty_s_form.
    DATA t_items        TYPE ty_t_item.
    DATA net            TYPE ty_amount.
    DATA vat            TYPE ty_amount.
    DATA total          TYPE ty_amount.
    DATA prices_visible TYPE abap_bool.

    DATA layout         TYPE ty_s_layout.
    DATA built          TYPE abap_bool.
    DATA upload_value   TYPE string.
    DATA upload_path    TYPE string.
    DATA template_info  TYPE string.
    DATA t_tags         TYPE ty_t_tag.

    DATA preview_info   TYPE string.
    DATA preview_state  TYPE string.
    DATA preview_text   TYPE string.
    DATA data_xml       TYPE string.

  PROTECTED SECTION.
    TYPES:
      BEGIN OF ty_s_doc_item,
        item_pos    TYPE string,
        item_text   TYPE string,
        item_qty    TYPE string,
        item_unit   TYPE string,
        item_price  TYPE string,
        item_amount TYPE string,
      END OF ty_s_doc_item.
    TYPES ty_t_doc_item TYPE STANDARD TABLE OF ty_s_doc_item WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_doc_ship_to,
        ship_name    TYPE string,
        ship_street  TYPE string,
        ship_city    TYPE string,
        ship_country TYPE string,
      END OF ty_s_doc_ship_to.

    TYPES:
      BEGIN OF ty_s_doc_remark,
        remark_text TYPE string,
      END OF ty_s_doc_remark.
    TYPES ty_t_doc_remark TYPE STANDARD TABLE OF ty_s_doc_remark WITH EMPTY KEY.

    " the data handed to zcl_docx3=>get_document - every component name is
    " the tag of a content control in the template
    TYPES:
      BEGIN OF ty_s_doc,
        doc_title      TYPE string,
        doc_no         TYPE string,
        doc_date       TYPE string,
        doc_sender     TYPE string,
        doc_ship_to    TYPE ty_s_doc_ship_to,
        doc_items      TYPE ty_t_doc_item,
        doc_net        TYPE string,
        doc_vat_rate   TYPE string,
        doc_vat        TYPE string,
        doc_total      TYPE string,
        flag_express   TYPE abap_bool,
        flag_fragile   TYPE abap_bool,
        flag_signature TYPE abap_bool,
        doc_remarks    TYPE ty_t_doc_remark,
        doc_signed_by  TYPE string,
      END OF ty_s_doc.

    TYPES:
      BEGIN OF ty_s_column,
        label TYPE string,
        tag   TYPE string,
        width TYPE i,
        align TYPE string,
      END OF ty_s_column.
    TYPES ty_t_column TYPE STANDARD TABLE OF ty_s_column WITH EMPTY KEY.

    " A4 minus 2 x 2 cm margin, in twentieths of a point
    CONSTANTS c_text_width TYPE i VALUE 9638.
    CONSTANTS c_mime_docx TYPE string VALUE `application/vnd.openxmlformats-officedocument.wordprocessingml.document`.

    DATA client   TYPE REF TO z2ui5_if_client.
    DATA template TYPE xstring.

    METHODS view_display.
    METHODS view_document
      IMPORTING
        items TYPE REF TO z2ui5_cl_ui5_view_builder.
    METHODS view_template
      IMPORTING
        items TYPE REF TO z2ui5_cl_ui5_view_builder.
    METHODS view_preview
      IMPORTING
        items TYPE REF TO z2ui5_cl_ui5_view_builder.

    METHODS on_event.
    METHODS items_recalc.
    METHODS document_generate
      RETURNING
        VALUE(result) TYPE xstring.
    METHODS document_data
      RETURNING
        VALUE(result) TYPE ty_s_doc.
    METHODS preview_update
      IMPORTING
        template_file TYPE xstring
        document      TYPE xstring
        data          TYPE ty_s_doc.
    METHODS template_get
      RETURNING
        VALUE(result) TYPE xstring.
    METHODS template_source.
    METHODS template_upload.
    METHODS template_build
      RETURNING
        VALUE(result) TYPE xstring.
    METHODS template_document_xml
      RETURNING
        VALUE(result) TYPE string.
    METHODS template_styles_xml
      RETURNING
        VALUE(result) TYPE string.
    METHODS table_borders_xml
      RETURNING
        VALUE(result) TYPE string.
    METHODS tags_check
      IMPORTING
        document_xml TYPE string.
    METHODS file_download
      IMPORTING
        file TYPE xstring
        name TYPE string.
    METHODS amount_text
      IMPORTING
        val           TYPE ty_amount
      RETURNING
        VALUE(result) TYPE string.
    METHODS model_init.

    CLASS-METHODS xml_run
      IMPORTING
        text          TYPE string
        bold          TYPE abap_bool DEFAULT abap_false
        italic        TYPE abap_bool DEFAULT abap_false
        color         TYPE string OPTIONAL
        size          TYPE i DEFAULT 0
      RETURNING
        VALUE(result) TYPE string.
    CLASS-METHODS xml_field
      IMPORTING
        tag           TYPE string
        bold          TYPE abap_bool DEFAULT abap_false
        color         TYPE string OPTIONAL
        size          TYPE i DEFAULT 0
      RETURNING
        VALUE(result) TYPE string.
    CLASS-METHODS xml_checkbox
      IMPORTING
        tag           TYPE string
      RETURNING
        VALUE(result) TYPE string.
    CLASS-METHODS xml_para
      IMPORTING
        content       TYPE string
        align         TYPE string OPTIONAL
        before        TYPE i DEFAULT 0
        after         TYPE i DEFAULT 120
      RETURNING
        VALUE(result) TYPE string.
    CLASS-METHODS xml_cell
      IMPORTING
        content       TYPE string
        width         TYPE i
        shade         TYPE string OPTIONAL
      RETURNING
        VALUE(result) TYPE string.
    CLASS-METHODS xml_to_text
      IMPORTING
        xml           TYPE string
      RETURNING
        VALUE(result) TYPE string.
    CLASS-METHODS zip_text
      IMPORTING
        file          TYPE xstring
        name          TYPE string
      RETURNING
        VALUE(result) TYPE string.
    CLASS-METHODS date_text
      IMPORTING
        val           TYPE string
      RETURNING
        VALUE(result) TYPE string.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_osl_docx IMPLEMENTATION.

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
            )->a( n = `xmlns:form`   v = `sap.ui.layout.form`
            )->a( n = `xmlns:editor` v = `sap.ui.codeeditor`
            )->a( n = `xmlns:z2ui5`  v = `z2ui5.cc`
            )->ele( `Shell`
                )->a( n = `appWidthLimited` v = `false`
                )->ele( `Page`
                    )->a( n = `title`          v = `Word documents with ABAP - zcl_docx x abap2UI5`
                    )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
                    )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    page->ele( `headerContent`
        )->tag( `Button`
            )->a( n = `text`  v = `Preview`
            )->a( n = `icon`  v = `sap-icon://detail-view`
            )->a( n = `type`  v = `Transparent`
            )->a( n = `press` v = client->_event( `PREVIEW` )
        )->tag( `Button`
            )->a( n = `text`  v = `Generate .docx`
            )->a( n = `icon`  v = `sap-icon://download`
            )->a( n = `type`  v = `Emphasized`
            )->a( n = `press` v = client->_event( `GENERATE` )
        )->tag( `Link`
            )->a( n = `text`   v = `AntonSikidin/zcl_docx`
            )->a( n = `href`   v = `https://github.com/AntonSikidin/zcl_docx`
            )->a( n = `target` v = `_blank` ).

    DATA(items) = page->ele( `content`
        )->ele( `IconTabBar`
            )->a( n = `selectedKey` v = client->_bind( tab )
            )->a( n = `expandable`  v = `false`
            )->a( n = `class`       v = `sapUiResponsiveContentPadding`
            )->ele( `items` ).

    view_document( items ).
    view_template( items ).
    view_preview( items ).

    client->view_display( page->stringify( ) ).

  ENDMETHOD.


  METHOD view_document.

    DATA(content) = items->ele( `IconTabFilter`
        )->a( n = `key`  v = `DOCUMENT`
        )->a( n = `text` v = `Document`
        )->a( n = `icon` v = `sap-icon://document`
        )->ele( `content` ).

    content->tag( `MessageStrip`
        )->a( n = `text`     v = `Fill in the form and press Generate .docx - zcl_docx3=>get_document fills the tagged content ` &&
                                 `controls of the template with this data and returns the finished Word file.`
        )->a( n = `type`     v = `Information`
        )->a( n = `showIcon` v = `true` ).

    content->ele( n = `SimpleForm` ns = `form`
        )->a( n = `editable`   v = `true`
        )->a( n = `layout`     v = `ResponsiveGridLayout`
        )->a( n = `labelSpanL` v = `4`
        )->a( n = `labelSpanM` v = `4`
        )->a( n = `columnsL`   v = `2`
        )->a( n = `columnsXL`  v = `2`
        )->ele( n = `content` ns = `form`

            )->tag( n = `Title` ns = `core`
                )->a( n = `text` v = `Header`
            )->tag( `Label`
                )->a( n = `text` v = `Document type`
            )->ele( `SegmentedButton`
                )->a( n = `selectedKey`     v = client->_bind( form-doc_type )
                )->a( n = `selectionChange` v = client->_event( `DOC_TYPE` )
                )->ele( `items`
                    )->tag( `SegmentedButtonItem`
                        )->a( n = `key`  v = `DELIVERY`
                        )->a( n = `text` v = `Delivery note`
                    )->tag( `SegmentedButtonItem`
                        )->a( n = `key`  v = `INVOICE`
                        )->a( n = `text` v = `Invoice`

                )->end(
            )->end(
            )->tag( `Label`
                )->a( n = `text` v = `Number`
            )->tag( `Input`
                )->a( n = `value` v = client->_bind( form-doc_no )
            )->tag( `Label`
                )->a( n = `text` v = `Date`
            )->tag( `DatePicker`
                )->a( n = `value`         v = client->_bind( form-doc_date )
                )->a( n = `valueFormat`   v = `yyyy-MM-dd`
                )->a( n = `displayFormat` v = `medium`
            )->tag( `Label`
                )->a( n = `text` v = `Sender line`
            )->tag( `Input`
                )->a( n = `value` v = client->_bind( form-sender )
            )->tag( `Label`
                )->a( n = `text` v = `Currency / VAT %`
            )->tag( `Input`
                )->a( n = `value`   v = client->_bind( form-currency )
                )->a( n = `enabled` v = client->_bind( prices_visible )
            )->tag( `StepInput`
                )->a( n = `value`                 v = client->_bind( form-vat_rate )
                )->a( n = `min`                   v = `0`
                )->a( n = `max`                   v = `50`
                )->a( n = `step`                  v = `0.5`
                )->a( n = `displayValuePrecision` v = `1`
                )->a( n = `enabled`               v = client->_bind( prices_visible )
                )->a( n = `change`                v = client->_event( `RECALC` )
            )->tag( n = `Title` ns = `core`
                )->a( n = `text` v = `Ship to`
            )->tag( `Label`
                )->a( n = `text` v = `Name`
            )->tag( `Input`
                )->a( n = `value` v = client->_bind( form-name )
            )->tag( `Label`
                )->a( n = `text` v = `Street`
            )->tag( `Input`
                )->a( n = `value` v = client->_bind( form-street )
            )->tag( `Label`
                )->a( n = `text` v = `City`
            )->tag( `Input`
                )->a( n = `value` v = client->_bind( form-city )
            )->tag( `Label`
                )->a( n = `text` v = `Country`
            )->tag( `Input`
                )->a( n = `value` v = client->_bind( form-country )
            )->tag( n = `Title` ns = `core`
                )->a( n = `text` v = `Shipping and remarks`
            )->tag( `Label`
                )->a( n = `text` v = `Checkboxes`
            )->ele( `VBox`

                )->tag( `CheckBox`
                    )->a( n = `text`     v = `Express delivery`
                    )->a( n = `selected` v = client->_bind( form-express )
                )->tag( `CheckBox`
                    )->a( n = `text`     v = `Fragile`
                    )->a( n = `selected` v = client->_bind( form-fragile )
                )->tag( `CheckBox`
                    )->a( n = `text`     v = `Signature on receipt`
                    )->a( n = `selected` v = client->_bind( form-signature )

            )->end(
            )->tag( `Label`
                )->a( n = `text` v = `Signed by`
            )->tag( `Input`
                )->a( n = `value` v = client->_bind( form-signed_by )
            )->tag( `Label`
                )->a( n = `text` v = `Remarks`
            )->tag( `TextArea`
                )->a( n = `value`       v = client->_bind( form-remarks )
                )->a( n = `rows`        v = `3`
                )->a( n = `placeholder` v = `one remark per line - each becomes a repeated paragraph` ).

    DATA(table) = content->ele( `Table`
        )->a( n = `items` v = client->_bind( t_items )
        )->a( n = `class` v = `sapUiSmallMarginTop` ).

    table->ele( `headerToolbar`
        )->ele( `OverflowToolbar`
            )->tag( `Title`
                )->a( n = `text`  v = `Items - one repeated table row in the template`
                )->a( n = `level` v = `H4`
            )->tag( `ToolbarSpacer`
            )->tag( `Button`
                )->a( n = `text`  v = `Add item`
                )->a( n = `icon`  v = `sap-icon://add`
                )->a( n = `press` v = client->_event( `ITEM_ADD` ) ).

    " header is the default aggregation of sap.m.Column
    table->ele( `columns`
        )->ele( `Column`
            )->a( n = `width` v = `4rem`

            )->tag( `Text`
                )->a( n = `text` v = `Pos.`

        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Description`
        )->end(
        )->ele( `Column`
            )->a( n = `width` v = `9rem`

            )->tag( `Text`
                )->a( n = `text` v = `Quantity`

        )->end(
        )->ele( `Column`
            )->a( n = `width` v = `6rem`

            )->tag( `Text`
                )->a( n = `text` v = `Unit`

        )->end(
        )->ele( `Column`
            )->a( n = `width`   v = `10rem`
            )->a( n = `visible` v = client->_bind( prices_visible )

            )->tag( `Text`
                )->a( n = `text` v = `Price`

        )->end(
        )->ele( `Column`
            )->a( n = `width`   v = `9rem`
            )->a( n = `hAlign`  v = `End`
            )->a( n = `visible` v = client->_bind( prices_visible )

            )->tag( `Text`
                )->a( n = `text` v = `Amount`

        )->end(
        )->ele( `Column`
            )->a( n = `width` v = `4rem`

            )->tag( `Text`
                )->a( n = `text` v = `` ).

    table->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells`
                )->tag( `Text`
                    )->a( n = `text` v = `{POS}`
                )->tag( `Input`
                    )->a( n = `value` v = `{TEXT}`
                )->tag( `StepInput`
                    )->a( n = `value`  v = `{QTY}`
                    )->a( n = `min`    v = `1`
                    )->a( n = `max`    v = `9999`
                    )->a( n = `change` v = client->_event( `RECALC` )
                )->tag( `Input`
                    )->a( n = `value` v = `{UNIT}`
                )->tag( `StepInput`
                    )->a( n = `value`                 v = `{PRICE}`
                    )->a( n = `min`                   v = `0`
                    )->a( n = `max`                   v = `999999`
                    )->a( n = `step`                  v = `0.5`
                    )->a( n = `displayValuePrecision` v = `2`
                    )->a( n = `change`                v = client->_event( `RECALC` )
                )->tag( `ObjectNumber`
                    )->a( n = `number` v = `{AMOUNT}`
                    )->a( n = `unit`   v = client->_bind( form-currency )
                )->tag( `Button`
                    )->a( n = `icon`    v = `sap-icon://delete`
                    )->a( n = `type`    v = `Transparent`
                    )->a( n = `tooltip` v = `Delete item`
                    )->a( n = `press`   v = client->_event( val   = `ITEM_DELETE`
                                                            arg   = `${POS}` ) ).

    content->ele( `OverflowToolbar`
        )->a( n = `style`   v = `Clear`
        )->a( n = `visible` v = client->_bind( prices_visible )
        )->ele( `content`
            )->tag( `ToolbarSpacer`
            )->tag( `Label`
                )->a( n = `text` v = `Net`
            )->tag( `ObjectNumber`
                )->a( n = `number` v = client->_bind( net )
                )->a( n = `unit`   v = client->_bind( form-currency )
            )->tag( `Label`
                )->a( n = `text` v = `VAT`
            )->tag( `ObjectNumber`
                )->a( n = `number` v = client->_bind( vat )
                )->a( n = `unit`   v = client->_bind( form-currency )
            )->tag( `Label`
                )->a( n = `text` v = `Total`
            )->tag( `ObjectNumber`
                )->a( n = `number`     v = client->_bind( total )
                )->a( n = `unit`       v = client->_bind( form-currency )
                )->a( n = `emphasized` v = `true` ).

  ENDMETHOD.


  METHOD view_template.

    DATA(content) = items->ele( `IconTabFilter`
        )->a( n = `key`  v = `TEMPLATE`
        )->a( n = `text` v = `Template`
        )->a( n = `icon` v = `sap-icon://attachment-text-file`
        )->ele( `content` ).

    content->tag( `MessageStrip`
        )->a( n = `text`     v = `zcl_docx fills a template: a .docx whose content controls carry a tag. By default this app ` &&
                                 `builds that template itself in ABAP - no SMW0 object needed. Download it, change it in Word ` &&
                                 `(Developer tab, content controls, Properties - Tag) and upload it again, or upload any .docx ` &&
                                 `whose tags are those listed below.`
        )->a( n = `type`     v = `Information`
        )->a( n = `showIcon` v = `true` ).

    content->ele( n = `SimpleForm` ns = `form`
        )->a( n = `editable`   v = `true`
        )->a( n = `layout`     v = `ResponsiveGridLayout`
        )->a( n = `labelSpanL` v = `4`
        )->a( n = `labelSpanM` v = `4`
        )->a( n = `columnsL`   v = `2`
        )->a( n = `columnsXL`  v = `2`
        )->ele( n = `content` ns = `form`

            )->tag( n = `Title` ns = `core`
                )->a( n = `text` v = `Template`
            )->tag( `Label`
                )->a( n = `text` v = `Source`
            )->ele( `SegmentedButton`
                )->a( n = `selectedKey`     v = client->_bind( layout-source )
                )->a( n = `selectionChange` v = client->_event( `SOURCE` )
                )->ele( `items`
                    )->tag( `SegmentedButtonItem`
                        )->a( n = `key`  v = `BUILT`
                        )->a( n = `text` v = `Built in ABAP`
                    )->tag( `SegmentedButtonItem`
                        )->a( n = `key`  v = `UPLOAD`
                        )->a( n = `text` v = `Uploaded .docx`

                )->end(
            )->end(
            )->tag( `Label`
                )->a( n = `text` v = `In use`
            )->tag( `Text`
                )->a( n = `text` v = client->_bind( template_info )
            )->tag( `Label`
                )->a( n = `text` v = `Upload a template`
            )->tag( n = `FileUploader` ns = `z2ui5`
                )->a( n = `value`             v = client->_bind( upload_value )
                )->a( n = `path`              v = client->_bind( upload_path )
                )->a( n = `fileType`          v = `docx`
                )->a( n = `placeholder`       v = `.docx with tagged content controls`
                )->a( n = `checkDirectUpload` v = `true`
                )->a( n = `upload`            v = client->_event( `UPLOAD` )
            )->tag( `Label`
                )->a( n = `text` v = `Built template`
            )->tag( `Button`
                )->a( n = `text`  v = `Download the built template`
                )->a( n = `icon`  v = `sap-icon://download`
                )->a( n = `press` v = client->_event( `DOWNLOAD_TEMPLATE` )
            )->tag( n = `Title` ns = `core`
                )->a( n = `text` v = `Layout of the built template`
            )->tag( `Label`
                )->a( n = `text` v = `Font`
            )->ele( `Select`
                )->a( n = `selectedKey` v = client->_bind( layout-font )
                )->a( n = `enabled`     v = client->_bind( built )
                )->ele( `items`
                    )->tag( n = `Item` ns = `core`
                        )->a( n = `key`  v = `Calibri`
                        )->a( n = `text` v = `Calibri`
                    )->tag( n = `Item` ns = `core`
                        )->a( n = `key`  v = `Arial`
                        )->a( n = `text` v = `Arial`
                    )->tag( n = `Item` ns = `core`
                        )->a( n = `key`  v = `Georgia`
                        )->a( n = `text` v = `Georgia`
                    )->tag( n = `Item` ns = `core`
                        )->a( n = `key`  v = `Times New Roman`
                        )->a( n = `text` v = `Times New Roman`
                    )->tag( n = `Item` ns = `core`
                        )->a( n = `key`  v = `Courier New`
                        )->a( n = `text` v = `Courier New`

                )->end(
            )->end(
            )->tag( `Label`
                )->a( n = `text` v = `Font size (pt)`
            )->tag( `StepInput`
                )->a( n = `value`   v = client->_bind( layout-font_size )
                )->a( n = `min`     v = `8`
                )->a( n = `max`     v = `14`
                )->a( n = `enabled` v = client->_bind( built )
            )->tag( `Label`
                )->a( n = `text` v = `Accent color`
            )->ele( `Select`
                )->a( n = `selectedKey` v = client->_bind( layout-accent )
                )->a( n = `enabled`     v = client->_bind( built )
                )->ele( `items`
                    )->tag( n = `Item` ns = `core`
                        )->a( n = `key`  v = `0A6ED1`
                        )->a( n = `text` v = `Blue`
                    )->tag( n = `Item` ns = `core`
                        )->a( n = `key`  v = `107E3E`
                        )->a( n = `text` v = `Green`
                    )->tag( n = `Item` ns = `core`
                        )->a( n = `key`  v = `BB0000`
                        )->a( n = `text` v = `Red`
                    )->tag( n = `Item` ns = `core`
                        )->a( n = `key`  v = `E9730C`
                        )->a( n = `text` v = `Orange`
                    )->tag( n = `Item` ns = `core`
                        )->a( n = `key`  v = `32363A`
                        )->a( n = `text` v = `Black`

                )->end(
            )->end(
            )->tag( `Label`
                )->a( n = `text` v = `Table borders`
            )->ele( `SegmentedButton`
                )->a( n = `selectedKey` v = client->_bind( layout-borders )
                )->a( n = `enabled`     v = client->_bind( built )
                )->ele( `items`
                    )->tag( `SegmentedButtonItem`
                        )->a( n = `key`  v = `GRID`
                        )->a( n = `text` v = `Grid`
                    )->tag( `SegmentedButtonItem`
                        )->a( n = `key`  v = `LINES`
                        )->a( n = `text` v = `Lines`
                    )->tag( `SegmentedButtonItem`
                        )->a( n = `key`  v = `NONE`
                        )->a( n = `text` v = `None`

                )->end(
            )->end(
            )->tag( `Label`
                )->a( n = `text` v = `Table header`
            )->tag( `CheckBox`
                )->a( n = `text`     v = `Shade the header row in the accent color`
                )->a( n = `selected` v = client->_bind( layout-shade_header )
                )->a( n = `enabled`  v = client->_bind( built )
            )->tag( n = `Title` ns = `core`
                )->a( n = `text` v = `Library option`
            )->tag( `Label`
                )->a( n = `text` v = `iv_protect`
            )->tag( `CheckBox`
                )->a( n = `text`     v = `Protect the document from editing (read-only)`
                )->a( n = `selected` v = client->_bind( layout-protect ) ).

    DATA(table) = content->ele( `Table`
        )->a( n = `items` v = client->_bind( t_tags )
        )->a( n = `class` v = `sapUiSmallMarginTop` ).

    table->ele( `headerToolbar`
        )->ele( `OverflowToolbar`
            )->tag( `Title`
                )->a( n = `text`  v = `Tags - a content control's tag is the name of an ABAP component (case-insensitive)`
                )->a( n = `level` v = `H4` ).

    table->ele( `columns`
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Tag`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Kind`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Inside`
        )->end(
        )->ele( `Column`
            )->a( n = `minScreenWidth` v = `Tablet`
            )->a( n = `demandPopin`    v = `true`

            )->tag( `Text`
                )->a( n = `text` v = `What the library does with it`

        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `In the template` ).

    table->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells`
                )->tag( `ObjectIdentifier`
                    )->a( n = `title` v = `{TAG}`
                )->tag( `Text`
                    )->a( n = `text` v = `{KIND}`
                )->tag( `Text`
                    )->a( n = `text` v = `{PARENT}`
                )->tag( `Text`
                    )->a( n = `text` v = `{DESCRIPTION}`
                )->tag( `ObjectStatus`
                    )->a( n = `text`  v = `{FOUND}`
                    )->a( n = `state` v = `{STATE}` ).

  ENDMETHOD.


  METHOD view_preview.

    DATA(content) = items->ele( `IconTabFilter`
        )->a( n = `key`  v = `PREVIEW`
        )->a( n = `text` v = `Preview`
        )->a( n = `icon` v = `sap-icon://detail-view`
        )->ele( `content` ).

    content->tag( `MessageStrip`
        )->a( n = `text`     v = client->_bind( preview_info )
        )->a( n = `type`     v = client->_bind( preview_state )
        )->a( n = `showIcon` v = `true` ).

    content->tag( `Title`
        )->a( n = `text`  v = `Text of the generated document (read back from its word/document.xml)`
        )->a( n = `level` v = `H4`
        )->a( n = `class` v = `sapUiSmallMarginTop` ).

    content->tag( `TextArea`
        )->a( n = `value`    v = client->_bind( preview_text )
        )->a( n = `rows`     v = `22`
        )->a( n = `width`    v = `100%`
        )->a( n = `editable` v = `false` ).

    content->tag( `Title`
        )->a( n = `text`  v = `The data handed to zcl_docx3=>get_document as asXML - every element name is a tag`
        )->a( n = `level` v = `H4`
        )->a( n = `class` v = `sapUiSmallMarginTop` ).

    content->tag( n = `CodeEditor` ns = `editor`
        )->a( n = `value`    v = client->_bind( data_xml )
        )->a( n = `type`     v = `xml`
        )->a( n = `height`   v = `420px`
        )->a( n = `editable` v = `false` ).

  ENDMETHOD.


  METHOD on_event.

    " the library works through CALL TRANSFORMATION and cl_abap_zip - a
    " template it cannot read is shown, not dumped
    TRY.
        CASE client->get_event( ).

          WHEN `DOC_TYPE`.
            prices_visible = xsdbool( form-doc_type = `INVOICE` ).
            items_recalc( ).
            template_source( ).

          WHEN `RECALC`.
            items_recalc( ).

          WHEN `ITEM_ADD`.
            INSERT VALUE #( text = `New item` qty = 1 unit = `PC` ) INTO TABLE t_items.
            items_recalc( ).

          WHEN `ITEM_DELETE`.
            DATA(pos) = CONV i( client->get_event_arg( ) ).
            DELETE t_items WHERE pos = pos.
            items_recalc( ).

          WHEN `SOURCE`.
            template_source( ).

          WHEN `UPLOAD`.
            template_upload( ).

          WHEN `DOWNLOAD_TEMPLATE`.
            file_download( file = template_build( )
                           name = `zcl_docx_template.docx` ).

          WHEN `PREVIEW`.
            document_generate( ).
            tab = `PREVIEW`.

          WHEN `GENERATE`.
            file_download( file = document_generate( )
                           name = |{ to_lower( form-doc_type ) }_{ form-doc_no }.docx| ).
            client->message_toast_display( `Document generated by zcl_docx3=>get_document` ).

        ENDCASE.
      CATCH cx_root INTO DATA(error).
        client->message_box_display( text = error->get_text( )
                                     type = `error` ).
    ENDTRY.

  ENDMETHOD.


  METHOD items_recalc.

    LOOP AT t_items ASSIGNING FIELD-SYMBOL(<item>).
      <item>-pos    = sy-tabix.
      <item>-amount = <item>-qty * <item>-price.
    ENDLOOP.

    net = REDUCE #( INIT sum = VALUE ty_amount( )
                    FOR item IN t_items
                    NEXT sum = sum + item-amount ).
    vat   = net * form-vat_rate / 100.
    total = net + vat.

  ENDMETHOD.


  METHOD document_generate.

    items_recalc( ).
    DATA(data) = document_data( ).
    DATA(template_file) = template_get( ).

    " iv_no_save: return the file only - no SAP GUI download, no Word started
    result = zcl_docx3=>get_document( iv_template = template_file
                                      iv_protect  = layout-protect
                                      iv_no_save  = abap_true
                                      iv_data     = data ).

    preview_update( template_file = template_file
                    document      = result
                    data          = data ).

  ENDMETHOD.


  METHOD document_data.

    DATA(invoice) = xsdbool( form-doc_type = `INVOICE` ).

    result = VALUE #( doc_title      = COND #( WHEN invoice = abap_true THEN `Invoice` ELSE `Delivery note` )
                      doc_no         = form-doc_no
                      doc_date       = date_text( form-doc_date )
                      doc_sender     = form-sender
                      doc_ship_to    = VALUE #( ship_name    = form-name
                                                ship_street  = form-street
                                                ship_city    = form-city
                                                ship_country = form-country )
                      doc_net        = amount_text( net )
                      doc_vat_rate   = |{ form-vat_rate }|
                      doc_vat        = amount_text( vat )
                      doc_total      = amount_text( total )
                      flag_express   = form-express
                      flag_fragile   = form-fragile
                      flag_signature = form-signature
                      doc_signed_by  = form-signed_by ).

    LOOP AT t_items INTO DATA(item).
      INSERT VALUE #( item_pos    = |{ item-pos }|
                      item_text   = item-text
                      item_qty    = |{ item-qty }|
                      item_unit   = item-unit
                      item_price  = amount_text( item-price )
                      item_amount = amount_text( item-amount ) )
             INTO TABLE result-doc_items.
    ENDLOOP.

    SPLIT form-remarks AT cl_abap_char_utilities=>newline INTO TABLE DATA(remarks).
    LOOP AT remarks INTO DATA(remark).
      remark = condense( replace( val  = remark
                                  sub  = |\r|
                                  with = ``
                                  occ  = 0 ) ).
      IF remark IS NOT INITIAL.
        INSERT VALUE #( remark_text = remark ) INTO TABLE result-doc_remarks.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD preview_update.

    DATA(template_xml) = zip_text( file = template_file
                                   name = `word/document.xml` ).
    DATA(result_xml)   = zip_text( file = document
                                   name = `word/document.xml` ).

    FIND ALL OCCURRENCES OF REGEX `<w:tag ` IN template_xml MATCH COUNT DATA(controls).
    FIND ALL OCCURRENCES OF REGEX `<w:tag ` IN result_xml MATCH COUNT DATA(controls_left).
    FIND ALL OCCURRENCES OF `</w:p>` IN result_xml MATCH COUNT DATA(paragraphs).
    FIND ALL OCCURRENCES OF `</w:tr>` IN result_xml MATCH COUNT DATA(rows).

    preview_text = xml_to_text( result_xml ).
    preview_info = |{ xstrlen( document ) } bytes .docx from a { xstrlen( template_file ) } bytes template: | &&
                   |{ controls } tagged content controls filled and removed ({ controls_left } left), | &&
                   |{ paragraphs } paragraphs, { rows } table rows| &&
                   |{ COND #( WHEN layout-protect = abap_true THEN `, protected against editing` ) }.|.
    preview_state = `Success`.

    " the library serializes the data with CALL TRANSFORMATION id as well
    DATA(writer) = cl_sxml_string_writer=>create( type = if_sxml=>co_xt_xml10 ).
    DATA(options) = CAST if_sxml_writer( writer ).
    options->set_option( option = if_sxml_writer=>co_opt_linebreaks ).
    options->set_option( option = if_sxml_writer=>co_opt_indent ).
    CALL TRANSFORMATION id SOURCE data = data RESULT XML writer.
    data_xml = cl_abap_codepage=>convert_from( writer->get_output( ) ).

  ENDMETHOD.


  METHOD template_get.

    result = COND #( WHEN layout-source = `UPLOAD` THEN template ELSE template_build( ) ).

  ENDMETHOD.


  METHOD template_source.

    IF layout-source = `UPLOAD` AND template IS INITIAL.
      layout-source = `BUILT`.
      client->message_box_display( `Upload a .docx first - until then the built template is used.` ).
    ENDIF.

    built = xsdbool( layout-source = `BUILT` ).
    IF built = abap_true.
      template_info = `Built in ABAP by this app with cl_abap_zip - no SMW0 object needed`.
      tags_check( template_document_xml( ) ).
    ELSE.
      template_info = |{ upload_path } - { xstrlen( template ) } bytes, uploaded|.
      tags_check( zip_text( file = template
                            name = `word/document.xml` ) ).
    ENDIF.

  ENDMETHOD.


  METHOD template_upload.

    IF upload_value IS INITIAL.
      RETURN.
    ENDIF.

    " the uploader delivers a data URI - data:<mime>;base64,<payload>
    DATA(file) = cl_web_http_utility=>decode_x_base64( substring_after( val = upload_value
                                                                        sub = `,` ) ).
    CLEAR upload_value.

    " a file the library could not unzip would end in a runtime error
    IF zip_text( file = file
                 name = `word/document.xml` ) IS INITIAL.
      client->message_box_display( text = |{ upload_path } is no .docx - it has no word/document.xml.|
                                   type = `error` ).
      RETURN.
    ENDIF.

    template = file.
    layout-source = `UPLOAD`.
    template_source( ).
    client->message_toast_display( |Template { upload_path } uploaded| ).

  ENDMETHOD.


  METHOD template_build.

    DATA(zip) = NEW cl_abap_zip( ).

    DATA(content_types) =
        `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>` &&
        `<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">` &&
        `<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>` &&
        `<Default Extension="xml" ContentType="application/xml"/>` &&
        `<Default Extension="png" ContentType="image/png"/>` &&
        `<Override PartName="/word/document.xml" ` &&
        `ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>` &&
        `<Override PartName="/word/styles.xml" ` &&
        `ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>` &&
        `<Override PartName="/word/settings.xml" ` &&
        `ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/>` &&
        `</Types>`.

    DATA(package_rels) =
        `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>` &&
        `<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">` &&
        `<Relationship Id="rId1" ` &&
        `Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" ` &&
        `Target="word/document.xml"/>` &&
        `</Relationships>`.

    DATA(document_rels) =
        `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>` &&
        `<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">` &&
        `<Relationship Id="rId1" ` &&
        `Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>` &&
        `<Relationship Id="rId2" ` &&
        `Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings" Target="settings.xml"/>` &&
        `</Relationships>`.

    " iv_protect adds w:documentProtection to this part
    DATA(settings) =
        `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>` &&
        `<w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">` &&
        `<w:defaultTabStop w:val="720"/>` &&
        `</w:settings>`.

    zip->add( name    = `[Content_Types].xml`
              content = cl_abap_codepage=>convert_to( content_types ) ).
    zip->add( name    = `_rels/.rels`
              content = cl_abap_codepage=>convert_to( package_rels ) ).
    zip->add( name    = `word/_rels/document.xml.rels`
              content = cl_abap_codepage=>convert_to( document_rels ) ).
    zip->add( name    = `word/settings.xml`
              content = cl_abap_codepage=>convert_to( settings ) ).
    zip->add( name    = `word/styles.xml`
              content = cl_abap_codepage=>convert_to( template_styles_xml( ) ) ).
    zip->add( name    = `word/document.xml`
              content = cl_abap_codepage=>convert_to( template_document_xml( ) ) ).

    result = zip->save( ).

  ENDMETHOD.


  METHOD template_document_xml.

    DATA(invoice) = xsdbool( form-doc_type = `INVOICE` ).
    DATA(accent)  = layout-accent.

    DATA(columns) = COND ty_t_column(
        WHEN invoice = abap_true
        THEN VALUE #( ( label = `Pos.`        tag = `ITEM_POS`    width = 700  align = `left` )
                      ( label = `Description` tag = `ITEM_TEXT`   width = 3938 align = `left` )
                      ( label = `Qty`         tag = `ITEM_QTY`    width = 1000 align = `right` )
                      ( label = `Unit`        tag = `ITEM_UNIT`   width = 900  align = `left` )
                      ( label = `Price`       tag = `ITEM_PRICE`  width = 1550 align = `right` )
                      ( label = `Amount`      tag = `ITEM_AMOUNT` width = 1550 align = `right` ) )
        ELSE VALUE #( ( label = `Pos.`        tag = `ITEM_POS`    width = 800  align = `left` )
                      ( label = `Description` tag = `ITEM_TEXT`   width = 5838 align = `left` )
                      ( label = `Quantity`    tag = `ITEM_QTY`    width = 1600 align = `right` )
                      ( label = `Unit`        tag = `ITEM_UNIT`   width = 1400 align = `left` ) ) ).

    DATA(header_color) = COND string( WHEN layout-shade_header = abap_true THEN `FFFFFF` ELSE accent ).
    DATA(header_shade) = COND string( WHEN layout-shade_header = abap_true THEN accent ).
    DATA(grid)         = ``.
    DATA(header_cells) = ``.
    DATA(item_cells)   = ``.
    LOOP AT columns INTO DATA(column).
      grid = grid && |<w:gridCol w:w="{ column-width }"/>|.
      header_cells = header_cells && xml_cell( width   = column-width
                                               shade   = header_shade
                                               content = xml_para( content = xml_run( text  = column-label
                                                                                      bold  = abap_true
                                                                                      color = header_color )
                                                                   align   = column-align
                                                                   after   = 0 ) ).
      item_cells = item_cells && xml_cell( width   = column-width
                                           content = xml_para( content = xml_field( column-tag )
                                                               align   = column-align
                                                               after   = 0 ) ).
    ENDLOOP.

    " DOC_ITEMS wraps one table row: the library repeats it for every line
    DATA(table) =
        |<w:tbl><w:tblPr><w:tblW w:w="{ c_text_width }" w:type="dxa"/>{ table_borders_xml( ) }| &&
        |<w:tblLayout w:type="fixed"/><w:tblCellMar><w:top w:w="60" w:type="dxa"/><w:left w:w="100" w:type="dxa"/>| &&
        |<w:bottom w:w="60" w:type="dxa"/><w:right w:w="100" w:type="dxa"/></w:tblCellMar></w:tblPr>| &&
        |<w:tblGrid>{ grid }</w:tblGrid>| &&
        |<w:tr><w:trPr><w:tblHeader/></w:trPr>{ header_cells }</w:tr>| &&
        |<w:sdt><w:sdtPr><w:alias w:val="DOC_ITEMS"/><w:tag w:val="DOC_ITEMS"/></w:sdtPr><w:sdtContent>| &&
        |<w:tr>{ item_cells }</w:tr>| &&
        |</w:sdtContent></w:sdt></w:tbl>|.

    DATA(totals) = ``.
    IF invoice = abap_true.
      totals = xml_para( content = xml_run( `Net amount: ` ) && xml_field( `DOC_NET` )
                         align   = `right`
                         before  = 120
                         after   = 0 ) &&
               xml_para( content = xml_run( `VAT ` ) && xml_field( `DOC_VAT_RATE` ) && xml_run( ` %: ` ) && xml_field( `DOC_VAT` )
                         align   = `right`
                         after   = 0 ) &&
               xml_para( content = xml_run( text = `Total: `
                                            bold = abap_true ) &&
                                   xml_field( tag   = `DOC_TOTAL`
                                              bold  = abap_true
                                              color = accent )
                         align   = `right` ).
    ENDIF.

    " DOC_SHIP_TO wraps a structure, DOC_REMARKS a paragraph repeated per line
    DATA(body) =
        xml_para( content = xml_field( tag   = `DOC_SENDER`
                                       color = `7F7F7F`
                                       size  = 8 )
                  after   = 240 ) &&
        `<w:sdt><w:sdtPr><w:alias w:val="DOC_SHIP_TO"/><w:tag w:val="DOC_SHIP_TO"/></w:sdtPr><w:sdtContent>` &&
        xml_para( content = xml_field( tag  = `SHIP_NAME`
                                       bold = abap_true )
                  after   = 0 ) &&
        xml_para( content = xml_field( `SHIP_STREET` )
                  after   = 0 ) &&
        xml_para( content = xml_field( `SHIP_CITY` )
                  after   = 0 ) &&
        xml_para( content = xml_field( `SHIP_COUNTRY` )
                  after   = 0 ) &&
        `</w:sdtContent></w:sdt>` &&
        xml_para( content = xml_field( tag   = `DOC_TITLE`
                                       bold  = abap_true
                                       color = accent
                                       size  = 20 )
                  before  = 720 ) &&
        xml_para( content = xml_run( `No. ` ) && xml_field( tag  = `DOC_NO`
                                                            bold = abap_true ) &&
                            xml_run( `     Date: ` ) && xml_field( tag  = `DOC_DATE`
                                                                   bold = abap_true )
                  after   = 240 ) &&
        table &&
        totals &&
        xml_para( content = xml_checkbox( `FLAG_EXPRESS` ) && xml_run( ` Express delivery      ` ) &&
                            xml_checkbox( `FLAG_FRAGILE` ) && xml_run( ` Fragile      ` ) &&
                            xml_checkbox( `FLAG_SIGNATURE` ) && xml_run( ` Signature on receipt` )
                  before  = 240 ) &&
        xml_para( content = xml_run( text  = `Remarks`
                                     bold  = abap_true
                                     color = accent )
                  before  = 240
                  after   = 60 ) &&
        `<w:sdt><w:sdtPr><w:alias w:val="DOC_REMARKS"/><w:tag w:val="DOC_REMARKS"/></w:sdtPr><w:sdtContent>` &&
        xml_para( content = xml_run( `- ` ) && xml_field( `REMARK_TEXT` )
                  after   = 0 ) &&
        `</w:sdtContent></w:sdt>` &&
        xml_para( content = xml_run( COND #( WHEN invoice = abap_true THEN `Issued by:` ELSE `Received in good order:` ) )
                  before  = 480
                  after   = 0 ) &&
        xml_para( content = xml_field( tag    = `DOC_SIGNED_BY`
                                       bold   = abap_true ) ) &&
        xml_para( content = xml_run( text   = `Generated in ABAP with zcl_docx3 - github.com/AntonSikidin/zcl_docx - and abap2UI5`
                                     italic = abap_true
                                     color  = `7F7F7F`
                                     size   = 7 )
                  before  = 480 ).

    result =
        `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>` &&
        `<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" ` &&
        `xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml" ` &&
        `xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" mc:Ignorable="w14">` &&
        `<w:body>` && body &&
        `<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>` &&
        `<w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134" w:header="567" w:footer="567" w:gutter="0"/>` &&
        `</w:sectPr></w:body></w:document>`.

  ENDMETHOD.


  METHOD template_styles_xml.

    DATA(font) = escape( val    = layout-font
                         format = cl_abap_format=>e_xml_attr ).
    DATA(size) = layout-font_size * 2.

    result =
        `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>` &&
        `<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">` &&
        `<w:docDefaults><w:rPrDefault><w:rPr>` &&
        |<w:rFonts w:ascii="{ font }" w:hAnsi="{ font }" w:eastAsia="{ font }" w:cs="{ font }"/>| &&
        |<w:sz w:val="{ size }"/><w:szCs w:val="{ size }"/><w:lang w:val="en-US"/>| &&
        `</w:rPr></w:rPrDefault>` &&
        `<w:pPrDefault><w:pPr><w:spacing w:after="120" w:line="264" w:lineRule="auto"/></w:pPr></w:pPrDefault>` &&
        `</w:docDefaults>` &&
        `<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:qFormat/></w:style>` &&
        `<w:style w:type="table" w:default="1" w:styleId="TableNormal"><w:name w:val="Normal Table"/>` &&
        `<w:tblPr><w:tblInd w:w="0" w:type="dxa"/></w:tblPr></w:style>` &&
        `</w:styles>`.

  ENDMETHOD.


  METHOD table_borders_xml.

    DATA(edges) = SWITCH string_table( layout-borders
        WHEN `GRID`  THEN VALUE #( ( `top` ) ( `left` ) ( `bottom` ) ( `right` ) ( `insideH` ) ( `insideV` ) )
        WHEN `LINES` THEN VALUE #( ( `top` ) ( `bottom` ) ( `insideH` ) ) ).
    DATA(color) = COND string( WHEN layout-borders = `GRID` THEN `A6A6A6` ELSE layout-accent ).

    LOOP AT edges INTO DATA(edge).
      result = result && |<w:{ edge } w:val="single" w:sz="4" w:space="0" w:color="{ color }"/>|.
    ENDLOOP.
    IF result IS NOT INITIAL.
      result = |<w:tblBorders>{ result }</w:tblBorders>|.
    ENDIF.

  ENDMETHOD.


  METHOD tags_check.

    LOOP AT t_tags ASSIGNING FIELD-SYMBOL(<tag>).
      <tag>-found = `not used`.
      <tag>-state = `None`.
    ENDLOOP.
    DELETE t_tags WHERE kind = `Unknown`.

    FIND ALL OCCURRENCES OF REGEX `<w:tag w:val="([^"]*)"` IN document_xml RESULTS DATA(matches).
    LOOP AT matches INTO DATA(match).
      DATA(submatch) = match-submatches[ 1 ].
      DATA(name) = to_upper( substring( val = document_xml
                                        off = submatch-offset
                                        len = submatch-length ) ).
      READ TABLE t_tags ASSIGNING <tag> WITH KEY tag = name.
      IF sy-subrc = 0.
        <tag>-found = `yes`.
        <tag>-state = COND #( WHEN <tag>-kind = `Unknown` THEN `Warning` ELSE `Success` ).
      ELSE.
        INSERT VALUE #( tag         = name
                        kind        = `Unknown`
                        description = `No such component in the data - the control keeps its template text`
                        found       = `yes`
                        state       = `Warning` )
               INTO TABLE t_tags.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD file_download.

    client->follow_up_action( val   = client->cs_event-download_b64_file
                              t_arg = VALUE #( ( |data:{ c_mime_docx };base64,{ cl_web_http_utility=>encode_x_base64( file ) }| )
                                               ( name ) ) ).

  ENDMETHOD.


  METHOD amount_text.

    result = |{ val NUMBER = ENVIRONMENT DECIMALS = 2 } { form-currency }|.

  ENDMETHOD.


  METHOD model_init.

    tab = `DOCUMENT`.

    form = VALUE #( doc_type  = `DELIVERY`
                    doc_no    = `DN-2026-0815`
                    doc_date  = |{ sy-datum DATE = ISO }|
                    sender    = `Open Source Tools Ltd. - 1 Example Road - 12345 Sampletown`
                    name      = `Example Corp. - Jane Doe`
                    street    = `42 Lambda Lane`
                    city      = `10115 Berlin`
                    country   = `Germany`
                    currency  = `EUR`
                    vat_rate  = 19
                    express   = abap_true
                    fragile   = abap_false
                    signature = abap_true
                    signed_by = `J. Doe`
                    remarks   = |Please deliver to the goods entrance.\nPallets are returnable.| ).

    t_items = VALUE #(
        ( text = `Mechanical keyboard`     qty = 2 unit = `PC` price = `89.90` )
        ( text = `USB-C docking station`   qty = 1 unit = `PC` price = `149.00` )
        ( text = `Monitor arm, dual`       qty = 1 unit = `PC` price = `64.50` )
        ( text = `Cable ties, pack of 100` qty = 3 unit = `PK` price = `4.99` ) ).
    items_recalc( ).

    layout = VALUE #( source       = `BUILT`
                      font         = `Calibri`
                      font_size    = 11
                      accent       = `0A6ED1`
                      borders      = `LINES`
                      shade_header = abap_true
                      protect      = abap_false ).

    t_tags = VALUE #(
        ( tag = `DOC_TITLE`      kind = `Field`        description = `Replaces the text of the control` )
        ( tag = `DOC_NO`         kind = `Field`        description = `Replaces the text of the control` )
        ( tag = `DOC_DATE`       kind = `Field`        description = `Replaces the text of the control` )
        ( tag = `DOC_SENDER`     kind = `Field`        description = `Replaces the text of the control` )
        ( tag = `DOC_SHIP_TO`    kind = `Structure`    description = `Resolves the tags inside against the sub-structure` )
        ( tag = `SHIP_NAME`      kind = `Field`        parent = `DOC_SHIP_TO` description = `Replaces the text of the control` )
        ( tag = `SHIP_STREET`    kind = `Field`        parent = `DOC_SHIP_TO` description = `Replaces the text of the control` )
        ( tag = `SHIP_CITY`      kind = `Field`        parent = `DOC_SHIP_TO` description = `Replaces the text of the control` )
        ( tag = `SHIP_COUNTRY`   kind = `Field`        parent = `DOC_SHIP_TO` description = `Replaces the text of the control` )
        ( tag = `DOC_ITEMS`      kind = `Table`        description = `Repeats its content - here a table row - once per line` )
        ( tag = `ITEM_POS`       kind = `Field`        parent = `DOC_ITEMS`   description = `Replaces the text, per line` )
        ( tag = `ITEM_TEXT`      kind = `Field`        parent = `DOC_ITEMS`   description = `Replaces the text, per line` )
        ( tag = `ITEM_QTY`       kind = `Field`        parent = `DOC_ITEMS`   description = `Replaces the text, per line` )
        ( tag = `ITEM_UNIT`      kind = `Field`        parent = `DOC_ITEMS`   description = `Replaces the text, per line` )
        ( tag = `ITEM_PRICE`     kind = `Field`        parent = `DOC_ITEMS`   description = `Replaces the text, per line` )
        ( tag = `ITEM_AMOUNT`    kind = `Field`        parent = `DOC_ITEMS`   description = `Replaces the text, per line` )
        ( tag = `DOC_NET`        kind = `Field`        description = `Replaces the text of the control` )
        ( tag = `DOC_VAT_RATE`   kind = `Field`        description = `Replaces the text of the control` )
        ( tag = `DOC_VAT`        kind = `Field`        description = `Replaces the text of the control` )
        ( tag = `DOC_TOTAL`      kind = `Field`        description = `Replaces the text of the control` )
        ( tag = `FLAG_EXPRESS`   kind = `Checkbox`     description = `Checked when the component is not initial` )
        ( tag = `FLAG_FRAGILE`   kind = `Checkbox`     description = `Checked when the component is not initial` )
        ( tag = `FLAG_SIGNATURE` kind = `Checkbox`     description = `Checked when the component is not initial` )
        ( tag = `DOC_REMARKS`    kind = `Table`        description = `Repeats its content - here a paragraph - once per line` )
        ( tag = `REMARK_TEXT`    kind = `Field`        parent = `DOC_REMARKS` description = `Replaces the text, per line` )
        ( tag = `DOC_SIGNED_BY`  kind = `Field`        description = `Replaces the text of the control` ) ).

    template_source( ).

    preview_info  = `Press Preview or Generate .docx - the text of the generated document appears here.`.
    preview_state = `Information`.

  ENDMETHOD.


  METHOD xml_run.

    DATA(properties) = COND string( WHEN bold = abap_true THEN `<w:b/>` ) &&
                       COND string( WHEN italic = abap_true THEN `<w:i/>` ) &&
                       COND string( WHEN color IS NOT INITIAL THEN |<w:color w:val="{ color }"/>| ) &&
                       COND string( WHEN size > 0 THEN |<w:sz w:val="{ size * 2 }"/><w:szCs w:val="{ size * 2 }"/>| ).

    result = |<w:r>{ COND #( WHEN properties IS NOT INITIAL THEN |<w:rPr>{ properties }</w:rPr>| ) }| &&
             |<w:t xml:space="preserve">{ escape( val    = text
                                                 format = cl_abap_format=>e_xml_text ) }</w:t></w:r>|.

  ENDMETHOD.


  METHOD xml_field.

    " a run-level content control - its tag names the component whose value
    " replaces the placeholder text, the run keeps its formatting
    result = |<w:sdt><w:sdtPr><w:alias w:val="{ tag }"/><w:tag w:val="{ tag }"/></w:sdtPr><w:sdtContent>| &&
             xml_run( text  = |[{ tag }]|
                      bold  = bold
                      color = color
                      size  = size ) &&
             `</w:sdtContent></w:sdt>`.

  ENDMETHOD.


  METHOD xml_checkbox.

    result = |<w:sdt><w:sdtPr><w:alias w:val="{ tag }"/><w:tag w:val="{ tag }"/>| &&
             `<w14:checkbox><w14:checked w14:val="0"/>` &&
             `<w14:checkedState w14:val="2612" w14:font="MS Gothic"/>` &&
             `<w14:uncheckedState w14:val="2610" w14:font="MS Gothic"/></w14:checkbox></w:sdtPr>` &&
             `<w:sdtContent><w:r><w:rPr><w:rFonts w:ascii="MS Gothic" w:eastAsia="MS Gothic" w:hAnsi="MS Gothic"/></w:rPr>` &&
             `<w:t>&#x2610;</w:t></w:r></w:sdtContent></w:sdt>`.

  ENDMETHOD.


  METHOD xml_para.

    result = |<w:p><w:pPr><w:spacing w:before="{ before }" w:after="{ after }"/>| &&
             |{ COND #( WHEN align IS NOT INITIAL THEN |<w:jc w:val="{ align }"/>| ) }</w:pPr>{ content }</w:p>|.

  ENDMETHOD.


  METHOD xml_cell.

    result = |<w:tc><w:tcPr><w:tcW w:w="{ width }" w:type="dxa"/>| &&
             |{ COND #( WHEN shade IS NOT INITIAL THEN |<w:shd w:val="clear" w:color="auto" w:fill="{ shade }"/>| ) }| &&
             |</w:tcPr>{ content }</w:tc>|.

  ENDMETHOD.


  METHOD xml_to_text.

    " cheap, not a renderer: one line per paragraph and per table row
    result = xml.
    REPLACE ALL OCCURRENCES OF REGEX `</w:p>\s*</w:tc>` IN result WITH `</w:tc>`.
    REPLACE ALL OCCURRENCES OF `</w:tc>` IN result WITH ` | `.
    REPLACE ALL OCCURRENCES OF REGEX `<w:tr[ >]` IN result WITH `| <`.
    REPLACE ALL OCCURRENCES OF `</w:tr>` IN result WITH cl_abap_char_utilities=>newline.
    REPLACE ALL OCCURRENCES OF `</w:p>` IN result WITH cl_abap_char_utilities=>newline.
    REPLACE ALL OCCURRENCES OF `<w:tab/>` IN result WITH `    `.
    REPLACE ALL OCCURRENCES OF REGEX `<[^>]*>` IN result WITH ``.
    REPLACE ALL OCCURRENCES OF REGEX `[ ]+\n` IN result WITH cl_abap_char_utilities=>newline.
    REPLACE ALL OCCURRENCES OF `&lt;` IN result WITH `<`.
    REPLACE ALL OCCURRENCES OF `&gt;` IN result WITH `>`.
    REPLACE ALL OCCURRENCES OF `&quot;` IN result WITH `"`.
    REPLACE ALL OCCURRENCES OF `&apos;` IN result WITH `'`.
    REPLACE ALL OCCURRENCES OF `&amp;` IN result WITH `&`.
    result = shift_left( val = result
                         sub = cl_abap_char_utilities=>newline ).

  ENDMETHOD.


  METHOD zip_text.

    DATA content TYPE xstring.

    DATA(zip) = NEW cl_abap_zip( ).
    zip->load( EXPORTING  zip    = file
               EXCEPTIONS OTHERS = 1 ).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    zip->get( EXPORTING  name    = name
              IMPORTING  content = content
              EXCEPTIONS OTHERS  = 1 ).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    result = cl_abap_codepage=>convert_from( content ).

  ENDMETHOD.


  METHOD date_text.

    DATA(date) = CONV d( replace( val  = val
                                  sub  = `-`
                                  with = ``
                                  occ  = 0 ) ).
    result = COND #( WHEN date IS INITIAL THEN val ELSE |{ date DATE = ENVIRONMENT }| ).

  ENDMETHOD.

ENDCLASS.
