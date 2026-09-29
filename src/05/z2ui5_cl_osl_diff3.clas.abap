"! <p class="shorttext">ABAP Diff3 visualized with abap2UI5</p>
"!
"! A diff and merge studio on top of https://github.com/abapPM/ABAP-Diff3,
"! the ABAP port of node-diff3: a side-by-side line diff (diff_comm, lcs,
"! diff_indices), a three-way merge with conflicts to resolve (diff3_merge,
"! diff3_merge_regions and the three conflict-marker styles merge,
"! merge_diff3, merge_dig_in) and a diff(1)-style patch to apply, invert
"! and strip (diff_patch, patch, invert_patch, strip_patch). Every result is
"! computed in ABAP by zcl_diff3 - the frontend only draws the bound data.
"!
"! The app only compares the texts typed into its editors - it reads and
"! changes nothing on the system.
CLASS z2ui5_cl_osl_diff3 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_diff_row,
        old_no    TYPE string,
        old_line  TYPE string,
        new_no    TYPE string,
        new_line  TYPE string,
        kind_text TYPE string,
        state     TYPE string,
      END OF ty_s_diff_row.
    TYPES ty_t_diff_row TYPE STANDARD TABLE OF ty_s_diff_row WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_diff_stats,
        unchanged TYPE string,
        changed   TYPE string,
        deleted   TYPE string,
        inserted  TYPE string,
        lcs       TYPE string,
        hunks     TYPE string,
      END OF ty_s_diff_stats.

    TYPES:
      BEGIN OF ty_s_conflict,
        id          TYPE i,
        title       TYPE string,
        location    TYPE string,
        mine        TYPE string,
        base        TYPE string,
        theirs      TYPE string,
        resolution  TYPE string,
        status_text TYPE string,
        state       TYPE string,
        mine_type   TYPE string,
        theirs_type TYPE string,
        both_type   TYPE string,
      END OF ty_s_conflict.
    TYPES ty_t_conflict TYPE STANDARD TABLE OF ty_s_conflict WITH EMPTY KEY.

    DATA tab              TYPE string.

    DATA old_text         TYPE string.
    DATA new_text         TYPE string.
    DATA t_diff_rows      TYPE ty_t_diff_row.
    DATA diff_stats       TYPE ty_s_diff_stats.
    DATA diff_summary     TYPE string.

    DATA base_text        TYPE string.
    DATA mine_text        TYPE string.
    DATA theirs_text      TYPE string.
    DATA exclude_false    TYPE abap_bool.
    DATA marker_style     TYPE string.
    DATA t_conflicts      TYPE ty_t_conflict.
    DATA markers_text     TYPE string.
    DATA merged_text      TYPE string.
    DATA merge_summary    TYPE string.
    DATA merge_state      TYPE string VALUE `Information`.

    DATA patch_mode       TYPE string.
    DATA patch_info       TYPE string.
    DATA patch_text       TYPE string.
    DATA patched_text     TYPE string.
    DATA patch_check      TYPE string.
    DATA patch_check_type TYPE string VALUE `Information`.

  PROTECTED SECTION.
    DATA client        TYPE REF TO z2ui5_if_client.
    DATA merge_regions TYPE zif_diff3=>ty_merge_region_t.

    METHODS view_display.
    METHODS view_diff
      IMPORTING
        items TYPE REF TO z2ui5_cl_ui5_view_builder.
    METHODS view_merge
      IMPORTING
        items TYPE REF TO z2ui5_cl_ui5_view_builder.
    METHODS view_patch
      IMPORTING
        items TYPE REF TO z2ui5_cl_ui5_view_builder.
    METHODS view_editor
      IMPORTING
        parent   TYPE REF TO z2ui5_cl_ui5_view_builder
        title    TYPE string
        value    TYPE string
        type     TYPE string DEFAULT `abap`
        editable TYPE abap_bool DEFAULT abap_true.

    METHODS on_event.
    METHODS diff_update.
    METHODS merge_update.
    METHODS markers_update.
    METHODS merged_update.
    METHODS patch_update.
    METHODS patch_apply.
    METHODS examples_set.
    METHODS model_init.

    CLASS-METHODS to_lines
      IMPORTING
        text          TYPE string
      RETURNING
        VALUE(result) TYPE string_table.
    CLASS-METHODS to_text
      IMPORTING
        lines         TYPE string_table
      RETURNING
        VALUE(result) TYPE string.
    CLASS-METHODS hunk_header
      IMPORTING
        offset1       TYPE i
        length1       TYPE i
        offset2       TYPE i
        length2       TYPE i
      RETURNING
        VALUE(result) TYPE string.
    CLASS-METHODS line_range
      IMPORTING
        offset        TYPE i
        length        TYPE i
      RETURNING
        VALUE(result) TYPE string.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_osl_diff3 IMPLEMENTATION.

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
            )->a( n = `xmlns:editor` v = `sap.ui.codeeditor`
            )->ele( `Shell`
                )->a( n = `appWidthLimited` v = `false`
                )->ele( `Page`
                    )->a( n = `title`          v = `Diff & Merge studio - ABAP Diff3 x abap2UI5`
                    )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
                    )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    page->ele( `headerContent`
        )->tag( `Button`
            )->a( n = `text`  v = `Restore examples`
            )->a( n = `icon`  v = `sap-icon://reset`
            )->a( n = `type`  v = `Transparent`
            )->a( n = `press` v = client->_event( `RESET` )
        )->tag( `Link`
            )->a( n = `text`   v = `abapPM/ABAP-Diff3`
            )->a( n = `href`   v = `https://github.com/abapPM/ABAP-Diff3`
            )->a( n = `target` v = `_blank` ).

    DATA(items) = page->ele( `content`
        )->ele( `IconTabBar`
            )->a( n = `selectedKey` v = client->_bind( tab )
            )->a( n = `expandable`  v = `false`
            )->a( n = `class`       v = `sapUiResponsiveContentPadding`
            )->ele( `items` ).

    view_diff( items ).
    view_merge( items ).
    view_patch( items ).

    client->view_display( page->stringify( ) ).

  ENDMETHOD.


  METHOD view_diff.

    DATA(content) = items->ele( `IconTabFilter`
        )->a( n = `key`  v = `DIFF`
        )->a( n = `text` v = `Diff`
        )->a( n = `icon` v = `sap-icon://compare`
        )->ele( `content` ).

    DATA(grid) = content->ele( n = `Grid` ns = `l`
        )->a( n = `defaultSpan` v = `XL6 L6 M12 S12` ).
    view_editor( parent = grid
                 title  = `Old`
                 value  = client->_bind( old_text ) ).
    view_editor( parent = grid
                 title  = `New`
                 value  = client->_bind( new_text ) ).

    content->ele( `OverflowToolbar`
        )->a( n = `style` v = `Clear`
        )->ele( `content`
            )->tag( `Button`
                )->a( n = `text`  v = `Compare`
                )->a( n = `icon`  v = `sap-icon://compare`
                )->a( n = `type`  v = `Emphasized`
                )->a( n = `press` v = client->_event( `COMPARE` )
            )->tag( `ToolbarSpacer`
            )->tag( `ObjectStatus`
                )->a( n = `title` v = `Unchanged`
                )->a( n = `text`  v = client->_bind( diff_stats-unchanged )
                )->a( n = `state` v = `None`
            )->tag( `ObjectStatus`
                )->a( n = `title` v = `Changed`
                )->a( n = `text`  v = client->_bind( diff_stats-changed )
                )->a( n = `state` v = `Warning`
            )->tag( `ObjectStatus`
                )->a( n = `title` v = `Deleted`
                )->a( n = `text`  v = client->_bind( diff_stats-deleted )
                )->a( n = `state` v = `Error`
            )->tag( `ObjectStatus`
                )->a( n = `title` v = `Inserted`
                )->a( n = `text`  v = client->_bind( diff_stats-inserted )
                )->a( n = `state` v = `Success`
            )->tag( `ObjectStatus`
                )->a( n = `title` v = `LCS`
                )->a( n = `text`  v = client->_bind( diff_stats-lcs )
                )->a( n = `state` v = `Information`
            )->tag( `ObjectStatus`
                )->a( n = `title` v = `Hunks`
                )->a( n = `text`  v = client->_bind( diff_stats-hunks )
                )->a( n = `state` v = `Information` ).

    content->tag( `MessageStrip`
        )->a( n = `text`     v = client->_bind( diff_summary )
        )->a( n = `type`     v = `Information`
        )->a( n = `showIcon` v = `true` ).

    DATA(table) = content->ele( `Table`
        )->a( n = `items`       v = client->_bind( t_diff_rows )
        )->a( n = `noDataText`  v = `Both texts are empty`
        )->a( n = `class`       v = `sapUiSmallMarginTop` ).

    " header is the default aggregation of sap.m.Column
    table->ele( `columns`
        )->ele( `Column`
            )->a( n = `width` v = `4rem`
            )->tag( `Text`
                )->a( n = `text` v = `Old #`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Old`
        )->end(
        )->ele( `Column`
            )->a( n = `width` v = `4rem`
            )->tag( `Text`
                )->a( n = `text` v = `New #`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `New`
        )->end(
        )->ele( `Column`
            )->a( n = `width` v = `8rem`
            )->tag( `Text`
                )->a( n = `text` v = `Change` ).

    " the row colour is the change kind diff_comm( ) reported for the line
    table->ele( `items`
        )->ele( `ColumnListItem`
            )->a( n = `highlight` v = `{STATE}`
            )->ele( `cells`
                )->tag( `Text`
                    )->a( n = `text` v = `{OLD_NO}`
                )->tag( `Text`
                    )->a( n = `text`             v = `{OLD_LINE}`
                    )->a( n = `renderWhitespace` v = `true`
                    )->a( n = `wrapping`         v = `false`
                )->tag( `Text`
                    )->a( n = `text` v = `{NEW_NO}`
                )->tag( `Text`
                    )->a( n = `text`             v = `{NEW_LINE}`
                    )->a( n = `renderWhitespace` v = `true`
                    )->a( n = `wrapping`         v = `false`
                )->tag( `ObjectStatus`
                    )->a( n = `text`  v = `{KIND_TEXT}`
                    )->a( n = `state` v = `{STATE}` ).

  ENDMETHOD.


  METHOD view_merge.

    DATA(content) = items->ele( `IconTabFilter`
        )->a( n = `key`  v = `MERGE`
        )->a( n = `text` v = `Three-way merge`
        )->a( n = `icon` v = `sap-icon://split`
        )->ele( `content` ).

    DATA(grid) = content->ele( n = `Grid` ns = `l`
        )->a( n = `defaultSpan` v = `XL4 L4 M12 S12` ).
    view_editor( parent = grid
                 title  = `Mine`
                 value  = client->_bind( mine_text ) ).
    view_editor( parent = grid
                 title  = `Base`
                 value  = client->_bind( base_text ) ).
    view_editor( parent = grid
                 title  = `Theirs`
                 value  = client->_bind( theirs_text ) ).

    content->ele( `OverflowToolbar`
        )->a( n = `style` v = `Clear`
        )->ele( `content`
            )->tag( `Button`
                )->a( n = `text`  v = `Merge`
                )->a( n = `icon`  v = `sap-icon://combine`
                )->a( n = `type`  v = `Emphasized`
                )->a( n = `press` v = client->_event( `MERGE` )
            )->tag( `CheckBox`
                )->a( n = `text`     v = `Exclude false conflicts`
                )->a( n = `selected` v = client->_bind( exclude_false )
                )->a( n = `select`   v = client->_event( `MERGE` )
            )->tag( `ToolbarSpacer`
            )->tag( `Label`
                )->a( n = `text` v = `Conflict markers`
            )->ele( `SegmentedButton`
                )->a( n = `selectedKey`     v = client->_bind( marker_style )
                )->a( n = `selectionChange` v = client->_event( `MARKERS` )
                )->ele( `items`
                    )->tag( `SegmentedButtonItem`
                        )->a( n = `key`  v = `MERGE`
                        )->a( n = `text` v = `merge( )`
                    )->tag( `SegmentedButtonItem`
                        )->a( n = `key`  v = `DIFF3`
                        )->a( n = `text` v = `merge_diff3( )`
                    )->tag( `SegmentedButtonItem`
                        )->a( n = `key`  v = `DIG_IN`
                        )->a( n = `text` v = `merge_dig_in( )` ).

    content->tag( `MessageStrip`
        )->a( n = `text`     v = client->_bind( merge_summary )
        )->a( n = `type`     v = client->_bind( merge_state )
        )->a( n = `showIcon` v = `true` ).

    DATA(table) = content->ele( `Table`
        )->a( n = `items`      v = client->_bind( t_conflicts )
        )->a( n = `noDataText` v = `No conflicts - the merge is clean`
        )->a( n = `class`      v = `sapUiSmallMarginTop` ).

    table->ele( `headerToolbar`
        )->ele( `Toolbar`
            )->tag( `Title`
                )->a( n = `text`  v = `Conflicts - resolve each one`
                )->a( n = `level` v = `H4` ).

    " header is the default aggregation of sap.m.Column
    table->ele( `columns`
        )->ele( `Column`
            )->a( n = `width` v = `12rem`
            )->tag( `Text`
                )->a( n = `text` v = `Conflict`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Mine`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Base`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Theirs`
        )->end(
        )->ele( `Column`
            )->a( n = `width` v = `20rem`
            )->tag( `Text`
                )->a( n = `text` v = `Resolution` ).

    table->ele( `items`
        )->ele( `ColumnListItem`
            )->a( n = `highlight` v = `{STATE}`
            )->ele( `cells`
                )->ele( `VBox`
                    )->tag( `ObjectIdentifier`
                        )->a( n = `title` v = `{TITLE}`
                        )->a( n = `text`  v = `{LOCATION}`
                    )->tag( `ObjectStatus`
                        )->a( n = `text`  v = `{STATUS_TEXT}`
                        )->a( n = `state` v = `{STATE}`
                )->end(
                )->tag( `Text`
                    )->a( n = `text`             v = `{MINE}`
                    )->a( n = `renderWhitespace` v = `true`
                )->tag( `Text`
                    )->a( n = `text`             v = `{BASE}`
                    )->a( n = `renderWhitespace` v = `true`
                )->tag( `Text`
                    )->a( n = `text`             v = `{THEIRS}`
                    )->a( n = `renderWhitespace` v = `true`
                )->ele( `HBox`
                    )->a( n = `wrap` v = `Wrap`
                    )->tag( `Button`
                        )->a( n = `text`  v = `Take mine`
                        )->a( n = `type`  v = `{MINE_TYPE}`
                        )->a( n = `class` v = `sapUiTinyMarginEnd`
                        )->a( n = `press` v = client->_event( val   = `RESOLVE`
                                                              t_arg = VALUE #( ( `${ID}` ) ( `MINE` ) ) )
                    )->tag( `Button`
                        )->a( n = `text`  v = `Take theirs`
                        )->a( n = `type`  v = `{THEIRS_TYPE}`
                        )->a( n = `class` v = `sapUiTinyMarginEnd`
                        )->a( n = `press` v = client->_event( val   = `RESOLVE`
                                                              t_arg = VALUE #( ( `${ID}` ) ( `THEIRS` ) ) )
                    )->tag( `Button`
                        )->a( n = `text`  v = `Both`
                        )->a( n = `type`  v = `{BOTH_TYPE}`
                        )->a( n = `press` v = client->_event( val   = `RESOLVE`
                                                              t_arg = VALUE #( ( `${ID}` ) ( `BOTH` ) ) ) ).

    DATA(results) = content->ele( n = `Grid` ns = `l`
        )->a( n = `defaultSpan` v = `XL6 L6 M12 S12`
        )->a( n = `class`       v = `sapUiSmallMarginTop` ).
    view_editor( parent   = results
                 title    = `Library output with conflict markers`
                 value    = client->_bind( markers_text )
                 editable = abap_false ).
    view_editor( parent   = results
                 title    = `Merged result with your resolutions`
                 value    = client->_bind( merged_text )
                 editable = abap_false ).

  ENDMETHOD.


  METHOD view_patch.

    DATA(content) = items->ele( `IconTabFilter`
        )->a( n = `key`  v = `PATCH`
        )->a( n = `text` v = `Patch`
        )->a( n = `icon` v = `sap-icon://syntax`
        )->ele( `content` ).

    content->ele( `OverflowToolbar`
        )->a( n = `style` v = `Clear`
        )->ele( `content`
            )->tag( `Label`
                )->a( n = `text` v = `Patch`
            )->ele( `SegmentedButton`
                )->a( n = `selectedKey`     v = client->_bind( patch_mode )
                )->a( n = `selectionChange` v = client->_event( `PATCH_MODE` )
                )->ele( `items`
                    )->tag( `SegmentedButtonItem`
                        )->a( n = `key`  v = `FULL`
                        )->a( n = `text` v = `diff_patch( old, new )`
                    )->tag( `SegmentedButtonItem`
                        )->a( n = `key`  v = `INVERTED`
                        )->a( n = `text` v = `invert_patch( )`
                    )->tag( `SegmentedButtonItem`
                        )->a( n = `key`  v = `STRIPPED`
                        )->a( n = `text` v = `strip_patch( )`
                )->end(
            )->end(
            )->tag( `ToolbarSpacer`
            )->tag( `Button`
                )->a( n = `text`  v = `Apply patch`
                )->a( n = `icon`  v = `sap-icon://accept`
                )->a( n = `type`  v = `Emphasized`
                )->a( n = `press` v = client->_event( `PATCH_APPLY` ) ).

    content->tag( `MessageStrip`
        )->a( n = `text`     v = client->_bind( patch_info )
        )->a( n = `type`     v = `Information`
        )->a( n = `showIcon` v = `true` ).

    DATA(grid) = content->ele( n = `Grid` ns = `l`
        )->a( n = `defaultSpan` v = `XL6 L6 M12 S12`
        )->a( n = `class`       v = `sapUiSmallMarginTop` ).
    view_editor( parent   = grid
                 title    = `Patch in diff(1) notation`
                 value    = client->_bind( patch_text )
                 type     = `text`
                 editable = abap_false ).
    view_editor( parent   = grid
                 title    = `Result of patch( )`
                 value    = client->_bind( patched_text )
                 editable = abap_false ).

    content->tag( `MessageStrip`
        )->a( n = `text`     v = client->_bind( patch_check )
        )->a( n = `type`     v = client->_bind( patch_check_type )
        )->a( n = `showIcon` v = `true` ).

  ENDMETHOD.


  METHOD view_editor.

    parent->ele( `VBox`
        )->tag( `Title`
            )->a( n = `text`  v = title
            )->a( n = `level` v = `H4`
        )->tag( n = `CodeEditor` ns = `editor`
            )->a( n = `value`    v = value
            )->a( n = `type`     v = type
            )->a( n = `editable` b = editable
            )->a( n = `height`   v = `15rem` ).

  ENDMETHOD.


  METHOD on_event.

    " zcl_diff3 raises no exceptions - a table index it cannot find in
    " unusual input is shown instead of dumping
    TRY.
        CASE client->get_event( ).

          WHEN `COMPARE`.
            diff_update( ).
            patch_update( ).

          WHEN `MERGE`.
            merge_update( ).

          WHEN `MARKERS`.
            markers_update( ).

          WHEN `RESOLVE`.
            DATA(id) = CONV i( client->get_event_arg( ) ).
            DATA(resolution) = client->get_event_arg( 2 ).
            ASSIGN t_conflicts[ id = id ] TO FIELD-SYMBOL(<conflict>).
            IF sy-subrc = 0.
              " a second press on the chosen resolution takes it back
              <conflict>-resolution = COND #( WHEN <conflict>-resolution <> resolution THEN resolution ).
            ENDIF.
            merged_update( ).

          WHEN `PATCH_MODE`.
            patch_update( ).

          WHEN `PATCH_APPLY`.
            patch_apply( ).

          WHEN `RESET`.
            examples_set( ).
            client->message_toast_display( `Example texts restored` ).

        ENDCASE.
      CATCH cx_sy_itab_line_not_found INTO DATA(error).
        client->message_box_display( error ).
    ENDTRY.

  ENDMETHOD.


  METHOD diff_update.

    DATA(diff3)     = zcl_diff3=>create( ).
    DATA(old_lines) = to_lines( old_text ).
    DATA(new_lines) = to_lines( new_text ).
    DATA(old_no)    = 0.
    DATA(new_no)    = 0.
    DATA(unchanged) = 0.
    DATA(changed)   = 0.
    DATA(deleted)   = 0.
    DATA(inserted)  = 0.

    " diff_comm( ) alternates common blocks and diff blocks - a diff block
    " pairs its old and new lines as changes, the surplus is deleted or new
    CLEAR t_diff_rows.
    LOOP AT diff3->diff_comm( it_buffer1 = old_lines it_buffer2 = new_lines ) INTO DATA(block).

      LOOP AT block-common INTO DATA(line).
        old_no    = old_no + 1.
        new_no    = new_no + 1.
        unchanged = unchanged + 1.
        INSERT VALUE #( old_no    = |{ old_no }|
                        old_line  = line
                        new_no    = |{ new_no }|
                        new_line  = line
                        kind_text = `unchanged`
                        state     = `None` ) INTO TABLE t_diff_rows.
      ENDLOOP.

      DATA(old_count) = lines( block-diff-buffer1 ).
      DATA(new_count) = lines( block-diff-buffer2 ).
      DO nmax( val1 = old_count val2 = new_count ) TIMES.
        DATA(ix) = sy-index.
        DATA(row) = VALUE ty_s_diff_row( ).
        IF ix <= old_count.
          old_no = old_no + 1.
          row-old_no   = |{ old_no }|.
          row-old_line = block-diff-buffer1[ ix ].
        ENDIF.
        IF ix <= new_count.
          new_no = new_no + 1.
          row-new_no   = |{ new_no }|.
          row-new_line = block-diff-buffer2[ ix ].
        ENDIF.
        IF ix <= old_count AND ix <= new_count.
          changed = changed + 1.
          row-kind_text = `changed`.
          row-state     = `Warning`.
        ELSEIF ix <= old_count.
          deleted = deleted + 1.
          row-kind_text = `deleted`.
          row-state     = `Error`.
        ELSE.
          inserted = inserted + 1.
          row-kind_text = `inserted`.
          row-state     = `Success`.
        ENDIF.
        INSERT row INTO TABLE t_diff_rows.
      ENDDO.

    ENDLOOP.

    " lcs( ) returns the Hunt-McIlroy candidates - the longest common
    " subsequence is the chain behind the last one
    DATA(lcs) = diff3->lcs( it_buffer1 = old_lines it_buffer2 = new_lines ).
    DATA(candidate) = lcs[ key = lines( lcs ) - 1 ].
    DATA(lcs_length) = 0.
    WHILE candidate-chain <> -1.
      lcs_length = lcs_length + 1.
      candidate = lcs[ key = candidate-chain ].
    ENDWHILE.

    " diff_indices( ) gives the mismatched chunks as offsets and lengths
    DATA(hunks) = diff3->diff_indices( it_buffer1 = old_lines it_buffer2 = new_lines ).

    diff_stats = VALUE #( unchanged = |{ unchanged }|
                          changed   = |{ changed }|
                          deleted   = |{ deleted }|
                          inserted  = |{ inserted }|
                          lcs       = |{ lcs_length }|
                          hunks     = |{ lines( hunks ) }| ).
    DATA(hunk_list) = concat_lines_of( table = VALUE string_table( FOR h IN hunks
                                                    ( hunk_header( offset1 = h-buffer1-key
                                                                   length1 = h-buffer1-len
                                                                   offset2 = h-buffer2-key
                                                                   length2 = h-buffer2-len ) ) )
                                       sep   = `, ` ).
    diff_summary = |{ lines( old_lines ) } old and { lines( new_lines ) } new lines share a longest common | &&
                   |subsequence of { lcs_length } lines. | &&
                   COND string( WHEN hunks IS INITIAL THEN `The texts are identical.`
                                ELSE |Hunks from diff_indices( ) in diff(1) notation: { hunk_list }| ).

  ENDMETHOD.


  METHOD merge_update.

    DATA(diff3)  = zcl_diff3=>create( ).
    DATA(mine)   = to_lines( mine_text ).
    DATA(base)   = to_lines( base_text ).
    DATA(theirs) = to_lines( theirs_text ).

    " diff3_merge( ) alternates ok blocks and conflict blocks - kept to
    " assemble the merged text from the resolutions
    merge_regions = diff3->diff3_merge( it_a                       = mine
                                        it_o                       = base
                                        it_b                       = theirs
                                        iv_exclude_false_conflicts = exclude_false ).

    CLEAR t_conflicts.
    LOOP AT merge_regions INTO DATA(region).
      IF region-ok IS NOT INITIAL.
        CONTINUE.
      ENDIF.
      DATA(id) = lines( t_conflicts ) + 1.
      INSERT VALUE #( id          = id
                      title       = |Conflict { id }|
                      location    = |base line { region-conflict-o_index + 1 }, | &&
                                    |mine { region-conflict-a_index + 1 }, theirs { region-conflict-b_index + 1 }|
                      mine        = COND #( WHEN region-conflict-a IS INITIAL THEN `(removed)` ELSE to_text( region-conflict-a ) )
                      base        = COND #( WHEN region-conflict-o IS INITIAL THEN `(nothing)` ELSE to_text( region-conflict-o ) )
                      theirs      = COND #( WHEN region-conflict-b IS INITIAL THEN `(removed)` ELSE to_text( region-conflict-b ) )
                      status_text = `open`
                      state       = `Warning`
                      mine_type   = `Default`
                      theirs_type = `Default`
                      both_type   = `Default` )
             INTO TABLE t_conflicts.
    ENDLOOP.

    markers_update( ).
    merged_update( ).

  ENDMETHOD.


  METHOD markers_update.

    DATA(diff3)  = zcl_diff3=>create( ).
    DATA(mine)   = to_lines( mine_text ).
    DATA(base)   = to_lines( base_text ).
    DATA(theirs) = to_lines( theirs_text ).
    DATA(labels) = VALUE zif_diff3=>ty_labels( a = `mine` o = `base` b = `theirs` ).

    DATA(result) = SWITCH zif_diff3=>ty_merge_result( marker_style
      WHEN `DIFF3`  THEN diff3->merge_diff3( it_a                       = mine
                                             it_o                       = base
                                             it_b                       = theirs
                                             iv_exclude_false_conflicts = exclude_false
                                             is_labels                  = labels )
      WHEN `DIG_IN` THEN diff3->merge_dig_in( it_a                       = mine
                                              it_o                       = base
                                              it_b                       = theirs
                                              iv_exclude_false_conflicts = exclude_false
                                              is_labels                  = labels )
      ELSE diff3->merge( it_a                       = mine
                         it_o                       = base
                         it_b                       = theirs
                         iv_exclude_false_conflicts = exclude_false
                         is_labels                  = labels ) ).
    markers_text = to_text( result-result ).

  ENDMETHOD.


  METHOD merged_update.

    DATA merged TYPE string_table.

    DATA(conflict_no) = 0.
    DATA(unresolved)  = 0.
    LOOP AT merge_regions INTO DATA(region).
      IF region-ok IS NOT INITIAL.
        INSERT LINES OF region-ok INTO TABLE merged.
        CONTINUE.
      ENDIF.

      conflict_no = conflict_no + 1.
      ASSIGN t_conflicts[ conflict_no ] TO FIELD-SYMBOL(<conflict>).
      CASE <conflict>-resolution.
        WHEN `MINE`.
          INSERT LINES OF region-conflict-a INTO TABLE merged.
        WHEN `THEIRS`.
          INSERT LINES OF region-conflict-b INTO TABLE merged.
        WHEN `BOTH`.
          INSERT LINES OF region-conflict-a INTO TABLE merged.
          INSERT LINES OF region-conflict-b INTO TABLE merged.
        WHEN OTHERS.
          unresolved = unresolved + 1.
          INSERT `<<<<<<< mine` INTO TABLE merged.
          INSERT LINES OF region-conflict-a INTO TABLE merged.
          INSERT `=======` INTO TABLE merged.
          INSERT LINES OF region-conflict-b INTO TABLE merged.
          INSERT `>>>>>>> theirs` INTO TABLE merged.
      ENDCASE.

      <conflict>-status_text = SWITCH #( <conflict>-resolution
                                 WHEN `MINE`   THEN `resolved: mine`
                                 WHEN `THEIRS` THEN `resolved: theirs`
                                 WHEN `BOTH`   THEN `resolved: both, mine first`
                                 ELSE `open` ).
      <conflict>-state       = COND #( WHEN <conflict>-resolution IS INITIAL THEN `Warning` ELSE `Success` ).
      <conflict>-mine_type   = COND #( WHEN <conflict>-resolution = `MINE`   THEN `Emphasized` ELSE `Default` ).
      <conflict>-theirs_type = COND #( WHEN <conflict>-resolution = `THEIRS` THEN `Emphasized` ELSE `Default` ).
      <conflict>-both_type   = COND #( WHEN <conflict>-resolution = `BOTH`   THEN `Emphasized` ELSE `Default` ).
    ENDLOOP.
    merged_text = to_text( merged ).

    " diff3_merge_regions( ) tells which side a clean change came from
    DATA(from_mine)   = 0.
    DATA(from_theirs) = 0.
    LOOP AT zcl_diff3=>create( )->diff3_merge_regions( it_a = to_lines( mine_text )
                                                       it_o = to_lines( base_text )
                                                       it_b = to_lines( theirs_text ) ) INTO DATA(merge_region)
         WHERE stable = abap_true.
      CASE merge_region-stable_region-buffer.
        WHEN `a`.
          from_mine = from_mine + 1.
        WHEN `b`.
          from_theirs = from_theirs + 1.
      ENDCASE.
    ENDLOOP.

    merge_summary = |{ from_mine } change(s) taken from mine and { from_theirs } from theirs without conflict, | &&
                    |{ lines( t_conflicts ) } conflict(s) - | &&
                    COND string( WHEN t_conflicts IS INITIAL THEN `the merge is clean.`
                                 WHEN unresolved = 0 THEN `all resolved, the merged result is complete.`
                                 ELSE |{ unresolved } still open, marked in the merged result.| ).
    merge_state = COND #( WHEN unresolved = 0 THEN `Success` ELSE `Warning` ).

  ENDMETHOD.


  METHOD patch_update.

    DATA(diff3)     = zcl_diff3=>create( ).
    DATA(old_lines) = to_lines( old_text ).
    DATA(new_lines) = to_lines( new_text ).

    DATA(patch) = diff3->diff_patch( it_buffer1 = old_lines it_buffer2 = new_lines ).
    patch = SWITCH #( patch_mode
      WHEN `INVERTED` THEN diff3->invert_patch( patch )
      WHEN `STRIPPED` THEN diff3->strip_patch( patch )
      ELSE patch ).

    " the diff(1) normal format: a header per hunk, < the lines it removes,
    " > the lines it adds - a stripped patch keeps no removed lines and no
    " position in the target
    DATA patch_lines TYPE string_table.
    LOOP AT patch INTO DATA(hunk).
      INSERT COND #( WHEN patch_mode = `STRIPPED`
                     THEN |{ line_range( offset = hunk-buffer1-offset length = hunk-buffer1-length ) }| &&
                          |c (stripped: { lines( hunk-buffer2-chunk ) } line(s))|
                     ELSE hunk_header( offset1 = hunk-buffer1-offset
                                       length1 = hunk-buffer1-length
                                       offset2 = hunk-buffer2-offset
                                       length2 = hunk-buffer2-length ) ) INTO TABLE patch_lines.
      LOOP AT hunk-buffer1-chunk INTO DATA(removed).
        INSERT |< { removed }| INTO TABLE patch_lines.
      ENDLOOP.
      IF hunk-buffer1-chunk IS NOT INITIAL AND hunk-buffer2-chunk IS NOT INITIAL.
        INSERT `---` INTO TABLE patch_lines.
      ENDIF.
      LOOP AT hunk-buffer2-chunk INTO DATA(added).
        INSERT |> { added }| INTO TABLE patch_lines.
      ENDLOOP.
    ENDLOOP.
    patch_text = to_text( patch_lines ).

    patch_info = |{ lines( patch ) } hunk(s) between the two texts of the Diff tab. | &&
                 SWITCH string( patch_mode
                   WHEN `INVERTED` THEN `The inverted patch applies to the new text and gives back the old one.`
                   WHEN `STRIPPED` THEN `The stripped patch keeps only what patch( ) needs - it still turns the old text into the new one, but can no longer be inverted.`
                   ELSE `Applied to the old text, the patch gives the new one.` ).
    CLEAR patched_text.
    patch_check      = `Press Apply patch to run patch( ).`.
    patch_check_type = `None`.

  ENDMETHOD.


  METHOD patch_apply.

    DATA(diff3)     = zcl_diff3=>create( ).
    DATA(old_lines) = to_lines( old_text ).
    DATA(new_lines) = to_lines( new_text ).

    DATA(patch) = diff3->diff_patch( it_buffer1 = old_lines it_buffer2 = new_lines ).
    DATA(inverted) = xsdbool( patch_mode = `INVERTED` ).
    patch = SWITCH #( patch_mode
      WHEN `INVERTED` THEN diff3->invert_patch( patch )
      WHEN `STRIPPED` THEN diff3->strip_patch( patch )
      ELSE patch ).

    DATA(source)   = COND string_table( WHEN inverted = abap_true THEN new_lines ELSE old_lines ).
    DATA(expected) = COND string_table( WHEN inverted = abap_true THEN old_lines ELSE new_lines ).
    DATA(result)   = diff3->patch( it_buffer = source it_patchres = patch ).
    patched_text = to_text( result ).

    DATA(target) = COND string( WHEN inverted = abap_true THEN `old` ELSE `new` ).
    IF result = expected.
      patch_check      = |patch( ) turned the { COND string( WHEN inverted = abap_true THEN `new` ELSE `old` ) } text | &&
                         |into the { target } text - all { lines( result ) } lines identical.|.
      patch_check_type = `Success`.
    ELSE.
      patch_check      = |The result differs from the { target } text - edit the texts on the Diff tab and press Compare.|.
      patch_check_type = `Error`.
    ENDIF.

  ENDMETHOD.


  METHOD examples_set.

    old_text = to_text( VALUE #(
        ( `METHOD get_discount.` )
        ( `  CLEAR result.` )
        ( `  DATA(rate) = 5.` )
        ( `  IF customer-category = 'A'.` )
        ( `    rate = 10.` )
        ( `  ENDIF.` )
        ( `  result = amount * rate / 100.` )
        ( `ENDMETHOD.` ) ) ).
    new_text = to_text( VALUE #(
        ( `METHOD get_discount.` )
        ( `  DATA(rate) = 5.` )
        ( `  IF customer-category = 'A'.` )
        ( `    rate = 10.` )
        ( `  ELSEIF customer-category = 'B'.` )
        ( `    rate = 7.` )
        ( `  ENDIF.` )
        ( `  result = round( val = amount * rate / 100 dec = 2 ).` )
        ( `ENDMETHOD.` ) ) ).

    " one clean change on each side (a comment in mine, rounding in theirs)
    " and both sides changing the same rate - the conflict
    base_text = to_text( VALUE #(
        ( `METHOD get_discount.` )
        ( `  DATA(rate) = 5.` )
        ( `  IF customer-category = 'A'.` )
        ( `    rate = 10.` )
        ( `  ENDIF.` )
        ( `  result = amount * rate / 100.` )
        ( `ENDMETHOD.` ) ) ).
    mine_text = to_text( VALUE #(
        ( `METHOD get_discount.` )
        ( `  " rate in percent` )
        ( `  DATA(rate) = 5.` )
        ( `  IF customer-category = 'A'.` )
        ( `    rate = 12.` )
        ( `  ENDIF.` )
        ( `  result = amount * rate / 100.` )
        ( `ENDMETHOD.` ) ) ).
    theirs_text = to_text( VALUE #(
        ( `METHOD get_discount.` )
        ( `  DATA(rate) = 5.` )
        ( `  IF customer-category = 'A'.` )
        ( `    rate = 15.` )
        ( `  ENDIF.` )
        ( `  result = round( val = amount * rate / 100 dec = 2 ).` )
        ( `ENDMETHOD.` ) ) ).

    diff_update( ).
    merge_update( ).
    patch_update( ).

  ENDMETHOD.


  METHOD model_init.

    tab           = `DIFF`.
    exclude_false = abap_true.
    marker_style  = `MERGE`.
    patch_mode    = `FULL`.

    TRY.
        examples_set( ).
      CATCH cx_sy_itab_line_not_found INTO DATA(error).
        client->message_box_display( error ).
    ENDTRY.

  ENDMETHOD.


  METHOD to_lines.

    " the browser sends LF; a CR from a pasted Windows text is dropped
    SPLIT replace( val = text sub = |\r| with = `` occ = 0 ) AT |\n| INTO TABLE result.

  ENDMETHOD.


  METHOD to_text.

    result = concat_lines_of( table = lines sep = |\n| ).

  ENDMETHOD.


  METHOD hunk_header.

    " diff(1) normal format: 2d1 deletes, 4a5,6 adds, 7c8 changes
    result = line_range( offset = offset1 length = length1 ) &&
             COND string( WHEN length1 = 0 THEN `a` WHEN length2 = 0 THEN `d` ELSE `c` ) &&
             line_range( offset = offset2 length = length2 ).

  ENDMETHOD.


  METHOD line_range.

    " offsets are 0-based; an empty range names the line it follows
    result = COND #( WHEN length = 0 THEN |{ offset }|
                     WHEN length = 1 THEN |{ offset + 1 }|
                     ELSE |{ offset + 1 },{ offset + length }| ).

  ENDMETHOD.

ENDCLASS.
