REPORT zabapgit.
* todo, program header + license
* todo, too many pulls, create repo object
* todo, send client name via git protocol

CONSTANTS: gc_version TYPE string VALUE 'alpha'.            "#EC NOTEXT

TYPES: t_type     TYPE c LENGTH 6,
       t_bitbyte  TYPE c LENGTH 8,
       t_adler32  TYPE x LENGTH 4,
       t_sha1     TYPE x LENGTH 20,
       t_unixtime TYPE c LENGTH 16.

TYPES: BEGIN OF st_node,
         chmod     TYPE string,
         name      TYPE string,
         sha1      TYPE t_sha1,
       END OF st_node.
TYPES: tt_nodes TYPE STANDARD TABLE OF st_node WITH DEFAULT KEY.

TYPES: BEGIN OF st_object,
         sha1 TYPE t_sha1,
         type TYPE t_type,
         data TYPE xstring,
       END OF st_object.
TYPES: tt_objects TYPE STANDARD TABLE OF st_object WITH DEFAULT KEY.

TYPES: BEGIN OF st_file,
         path     TYPE string,
         filename TYPE string,
         data     TYPE xstring,
       END OF st_file.
TYPES: tt_files TYPE STANDARD TABLE OF st_file WITH DEFAULT KEY.

TYPES: BEGIN OF st_commit,
         tree      TYPE t_sha1,
         parent    TYPE t_sha1,
         author    TYPE string,
         committer TYPE string,
         body      TYPE string,
       END OF st_commit.

TYPES: BEGIN OF st_repo,
         url TYPE string,
         branch_name TYPE string,
       END OF st_repo.

TYPES: BEGIN OF st_repo_sha1,
         url         TYPE string,
         branch_name TYPE string,
         sha1        TYPE string,
       END OF st_repo_sha1.
TYPES: tt_repos_sha1 TYPE STANDARD TABLE OF st_repo_sha1 WITH DEFAULT KEY.

TYPES: BEGIN OF st_result,
         obj_type TYPE tadir-object,
         obj_name TYPE tadir-obj_name,
         match    TYPE abap_bool,
       END OF st_result.
TYPES: tt_results TYPE STANDARD TABLE OF st_result WITH DEFAULT KEY.

TYPES: BEGIN OF st_comment,
         username TYPE string,
         email    TYPE string,
         comment  TYPE string,
       END OF st_comment.

CONSTANTS: gc_commit TYPE t_type VALUE 'commit',            "#EC NOTEXT
           gc_tree   TYPE t_type VALUE 'tree',              "#EC NOTEXT
           gc_ref_d  TYPE t_type VALUE 'ref_d',             "#EC NOTEXT
           gc_blob   TYPE t_type VALUE 'blob'.              "#EC NOTEXT

CONSTANTS: gc_chmod_file TYPE c LENGTH 6 VALUE '100644',
           gc_chmod_dir  TYPE c LENGTH 5 VALUE '40000'.

CONSTANTS: gc_newline TYPE abap_char1 VALUE cl_abap_char_utilities=>newline.

DEFINE _raise.
  raise exception type lcx_exception
    exporting
      iv_text = &1.                                         "#EC NOTEXT
END-OF-DEFINITION.

******************

START-OF-SELECTION.
  PERFORM run.

*----------------------------------------------------------------------*
*       CLASS CX_LOCAL_EXCEPTION DEFINITION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS lcx_exception DEFINITION INHERITING FROM cx_static_check FINAL.

  PUBLIC SECTION.
    DATA mv_text TYPE string.
    METHODS constructor IMPORTING iv_text TYPE string.

ENDCLASS.                    "CX_LOCAL_EXCEPTION DEFINITION

*----------------------------------------------------------------------*
*       CLASS CX_LOCAL_EXCEPTION IMPLEMENTATION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS lcx_exception IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    mv_text = iv_text.
  ENDMETHOD.                    "CONSTRUCTOR

ENDCLASS.                    "lcx_exception IMPLEMENTATION

*----------------------------------------------------------------------*
*       CLASS lcl_user DEFINITION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS lcl_user DEFINITION FINAL.

  PUBLIC SECTION.
    CLASS-METHODS: set_username IMPORTING iv_username TYPE string
                                RAISING lcx_exception.

    CLASS-METHODS: get_username RETURNING value(rv_username) TYPE string
                                RAISING lcx_exception.

    CLASS-METHODS: set_email IMPORTING iv_email TYPE string
                             RAISING lcx_exception.

    CLASS-METHODS: get_email RETURNING value(rv_email) TYPE string
                             RAISING lcx_exception.

  PRIVATE SECTION.

    CLASS-METHODS: read IMPORTING iv_name TYPE tdobname
                        RETURNING value(rv_value) TYPE string
                               RAISING lcx_exception.

    CLASS-METHODS: save IMPORTING iv_name TYPE tdobname
                                  iv_value TYPE string
                          RAISING lcx_exception.

ENDCLASS.                    "lcl_user DEFINITION

*----------------------------------------------------------------------*
*       CLASS lcl_user IMPLEMENTATION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS lcl_user IMPLEMENTATION.

  METHOD read.

    DATA: lt_lines TYPE TABLE OF tline,
          ls_line  LIKE LINE OF lt_lines.


    CALL FUNCTION 'READ_TEXT'
      EXPORTING
        id                      = 'ST'
        language                = 'E'
        name                    = iv_name
        object                  = 'TEXT'
      TABLES
        lines                   = lt_lines
      EXCEPTIONS
        id                      = 1
        language                = 2
        name                    = 3
        not_found               = 4
        object                  = 5
        reference_check         = 6
        wrong_access_to_archive = 7
        OTHERS                  = 8.
    IF sy-subrc <> 4 AND sy-subrc <> 0.
      _raise 'error from READ_TEXT'.
    ENDIF.

    READ TABLE lt_lines INTO ls_line INDEX 1.
    IF sy-subrc = 0.
      rv_value = ls_line-tdline.
    ENDIF.

  ENDMETHOD.                    "get_details

  METHOD save.

    DATA: ls_header TYPE thead,
          lt_lines  TYPE TABLE OF tline,
          ls_line   LIKE LINE OF lt_lines.


    ls_line-tdformat = '*'.
    ls_line-tdline = iv_value.
    APPEND ls_line TO lt_lines.

    ls_header-tdid       = 'ST'.
    ls_header-tdspras    = 'E'.
    ls_header-tdname     = iv_name.
    ls_header-tdobject   = 'TEXT'.

    CALL FUNCTION 'SAVE_TEXT'
      EXPORTING
        header   = ls_header
      TABLES
        lines    = lt_lines
      EXCEPTIONS
        id       = 1
        language = 2
        name     = 3
        object   = 4
        OTHERS   = 5.
    IF sy-subrc <> 0.
      ROLLBACK WORK.
      _raise 'error from SAVE_TEXT'.
    ENDIF.

    COMMIT WORK.

  ENDMETHOD.                    "change

  METHOD set_username.

    DATA: lv_name TYPE tdobname.


    CONCATENATE 'ZABAPGIT_USERNAME_' sy-uname INTO lv_name.

    save( iv_name  = lv_name
          iv_value = iv_username ).

  ENDMETHOD.                    "set_username

  METHOD get_username.

    DATA: lv_name TYPE tdobname.


    CONCATENATE 'ZABAPGIT_USERNAME_' sy-uname INTO lv_name.

    rv_username = read( lv_name ).

  ENDMETHOD.                    "get_username

  METHOD set_email.

    DATA: lv_name TYPE tdobname.


    CONCATENATE 'ZABAPGIT_EMAIL_' sy-uname INTO lv_name.

    save( iv_name  = lv_name
          iv_value = iv_email ).

  ENDMETHOD.                    "set_email

  METHOD get_email.

    DATA: lv_name TYPE tdobname.


    CONCATENATE 'ZABAPGIT_EMAIL_' sy-uname INTO lv_name.

    rv_email = read( lv_name ).

  ENDMETHOD.                    "get_email

ENDCLASS.                    "lcl_user IMPLEMENTATION

*----------------------------------------------------------------------*
*       CLASS lcl_xml DEFINITION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS lcl_xml DEFINITION FINAL.

  PUBLIC SECTION.
    METHODS constructor   IMPORTING iv_xml TYPE string OPTIONAL
                          RAISING lcx_exception.

    METHODS structure_add IMPORTING ig_structure TYPE data
                                    ii_root TYPE REF TO if_ixml_element OPTIONAL
                          RAISING lcx_exception.

    METHODS structure_read CHANGING cg_structure TYPE data.

    METHODS render        RETURNING value(rv_string) TYPE string.

    METHODS table_add     IMPORTING it_table TYPE STANDARD TABLE
                          RAISING lcx_exception.

* todo
* methods table_read

  PRIVATE SECTION.
    DATA: mi_ixml    TYPE REF TO if_ixml,
          mi_xml_doc TYPE REF TO if_ixml_document,
          mi_root    TYPE REF TO if_ixml_element.

ENDCLASS.                    "lcl_xml DEFINITION

*----------------------------------------------------------------------*
*       CLASS lcl_xml IMPLEMENTATION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS lcl_xml IMPLEMENTATION.

  METHOD structure_read.

    DATA: lv_name      TYPE string,
          li_struct    TYPE REF TO if_ixml_element,
          lv_value     TYPE string,
          lo_descr_ref TYPE REF TO cl_abap_structdescr.

    FIELD-SYMBOLS: <lg_any>  TYPE any,
                   <ls_comp> TYPE abap_compdescr.


    lo_descr_ref ?= cl_abap_typedescr=>describe_by_data( cg_structure ).
    lv_name = lo_descr_ref->get_relative_name( ).

    li_struct = mi_root->find_from_name( depth = 0 name = lv_name ).

    LOOP AT lo_descr_ref->components ASSIGNING <ls_comp>.

      ASSIGN COMPONENT <ls_comp>-name OF STRUCTURE cg_structure TO <lg_any>.

      lv_name = <ls_comp>-name.
      lv_value = li_struct->find_from_name( depth = 0 name = lv_name )->get_value( ).

      <lg_any> = lv_value.
    ENDLOOP.

  ENDMETHOD.                    "structure_read

  METHOD constructor.

    DATA: li_stream_factory TYPE REF TO if_ixml_stream_factory,
          li_istream        TYPE REF TO if_ixml_istream,
          li_parser         TYPE REF TO if_ixml_parser.


    mi_ixml = cl_ixml=>create( ).
    mi_xml_doc = mi_ixml->create_document( ).

    IF iv_xml IS SUPPLIED.
      li_stream_factory = mi_ixml->create_stream_factory( ).
      li_istream = li_stream_factory->create_istream_string( iv_xml ).
      li_parser = mi_ixml->create_parser( stream_factory = li_stream_factory
                                          istream        = li_istream
                                          document       = mi_xml_doc ).
      IF li_parser->parse( ) <> 0.
        _raise 'Error while parsing XML'.
      ENDIF.

      li_istream->close( ).

      mi_root = mi_xml_doc->find_from_name( depth = 0 name = 'abapGit' ).
    ELSE.
      mi_root = mi_xml_doc->create_element( 'abapGit' ).
      mi_root->set_attribute( name = 'version' value = gc_version ). "#EC NOTEXT
      mi_xml_doc->append_child( mi_root ).
    ENDIF.

  ENDMETHOD.                    "xml_root

  METHOD table_add.

    DATA: lv_name         TYPE string,
          li_table        TYPE REF TO if_ixml_element,
          lo_table_descr  TYPE REF TO cl_abap_tabledescr.

    FIELD-SYMBOLS: <lg_line>  TYPE any.


    lo_table_descr ?= cl_abap_typedescr=>describe_by_data( it_table ).
    lv_name = lo_table_descr->get_relative_name( ).

    IF lv_name IS INITIAL.
      _raise 'no name'.
    ENDIF.

    li_table = mi_xml_doc->create_element( lv_name ).

    LOOP AT it_table ASSIGNING <lg_line>.
      structure_add( ig_structure = <lg_line> ii_root = li_table ).
    ENDLOOP.

    mi_root->append_child( li_table ).

  ENDMETHOD.                    "table_add

  METHOD structure_add.

    DATA: li_element   TYPE REF TO if_ixml_element,
          li_structure TYPE REF TO if_ixml_element,
          li_text      TYPE REF TO if_ixml_text,
          lv_string    TYPE string,
          lv_name      TYPE string,
          lo_descr     TYPE REF TO cl_abap_structdescr.

    FIELD-SYMBOLS: <ls_comp> TYPE abap_compdescr,
                   <lg_any>  TYPE any.


    lo_descr ?= cl_abap_typedescr=>describe_by_data( ig_structure ).
    lv_name = lo_descr->get_relative_name( ).
    IF lv_name IS INITIAL.
      _raise 'no name'.
    ENDIF.
    li_structure = mi_xml_doc->create_element( lv_name ).

    LOOP AT lo_descr->components ASSIGNING <ls_comp>.

      ASSIGN COMPONENT <ls_comp>-name OF STRUCTURE ig_structure TO <lg_any>.

      lv_string  = <ls_comp>-name.
      li_element = mi_xml_doc->create_element( lv_string ).

      lv_string  = <lg_any>.
      li_text    = mi_xml_doc->create_text( lv_string ).

      li_element->append_child( li_text ).

      li_structure->append_child( li_element ).
    ENDLOOP.

    IF ii_root IS SUPPLIED.
      ii_root->append_child( li_structure ).
    ELSE.
      mi_root->append_child( li_structure ).
    ENDIF.

  ENDMETHOD.                    "structure_to_xml

  METHOD render.

    DATA: li_ostream       TYPE REF TO if_ixml_ostream,
          li_renderer      TYPE REF TO if_ixml_renderer,
          li_streamfactory TYPE REF TO if_ixml_stream_factory.


    li_streamfactory = mi_ixml->create_stream_factory( ).
    li_ostream = li_streamfactory->create_ostream_cstring( rv_string ).
    li_renderer = mi_ixml->create_renderer( ostream = li_ostream document = mi_xml_doc ).
    li_renderer->set_normalizing( ).
    li_renderer->render( ).

  ENDMETHOD.                    "xml_render

ENDCLASS.                    "lcl_xml IMPLEMENTATION


*----------------------------------------------------------------------*
*       CLASS lcl_time DEFINITION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS lcl_time DEFINITION FINAL.

  PUBLIC SECTION.
    CLASS-METHODS get RETURNING value(rv_time) TYPE t_unixtime
                      RAISING lcx_exception.

  PRIVATE SECTION.
    CONSTANTS: c_epoch TYPE datum VALUE '19700101'.

ENDCLASS.                    "lcl_time DEFINITION

*----------------------------------------------------------------------*
*       CLASS lcl_repo DEFINITION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS lcl_url DEFINITION FINAL.

  PUBLIC SECTION.
    CLASS-METHODS: host
                      IMPORTING iv_repo TYPE string
                      RETURNING value(rv_host) TYPE string
                      RAISING lcx_exception.

    CLASS-METHODS: name
                      IMPORTING iv_repo TYPE string
                      RETURNING value(rv_name) TYPE string
                      RAISING lcx_exception.

    CLASS-METHODS: path_name IMPORTING iv_repo TYPE string
                      RETURNING value(rv_path_name) TYPE string
                      RAISING lcx_exception.

  PRIVATE SECTION.
    CLASS-METHODS: regex IMPORTING iv_repo TYPE string
                         EXPORTING ev_host TYPE string
                                   ev_path TYPE string
                                   ev_name TYPE string
                         RAISING lcx_exception.

ENDCLASS.                    "lcl_repo DEFINITION

*----------------------------------------------------------------------*
*       CLASS lcl_repo IMPLEMENTATION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS lcl_url IMPLEMENTATION.

  METHOD host.
    regex( EXPORTING iv_repo = iv_repo
           IMPORTING ev_host = rv_host ).
  ENDMETHOD.                    "host

  METHOD name.
    regex( EXPORTING iv_repo = iv_repo
           IMPORTING ev_name = rv_name ).
  ENDMETHOD.                    "short_name

  METHOD path_name.

    DATA: lv_path TYPE string,
          lv_name TYPE string.

    regex( EXPORTING iv_repo = iv_repo
           IMPORTING ev_path = lv_path
                     ev_name = lv_name ).

    CONCATENATE lv_path lv_name INTO rv_path_name.

  ENDMETHOD.                    "path_name

  METHOD regex.

    FIND REGEX '(.*://[^/]*)(.*/)(.*).git' IN iv_repo
                     SUBMATCHES ev_host ev_path ev_name.
    IF sy-subrc <> 0.
      _raise 'Malformed URL'.
    ENDIF.

  ENDMETHOD.                    "url

ENDCLASS.                    "lcl_repo IMPLEMENTATION

*----------------------------------------------------------------------*
*       CLASS lcl_time IMPLEMENTATION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS lcl_time IMPLEMENTATION.

  METHOD get.

    DATA: lv_i       TYPE i,
          lv_tz      TYPE tznzone,
          lv_utcdiff TYPE tznutcdiff,
          lv_utcsign TYPE tznutcsign.


    lv_i = sy-datum - c_epoch.
    lv_i = lv_i * 86400.
    lv_i = lv_i + sy-uzeit.

    CALL FUNCTION 'TZON_GET_OS_TIMEZONE'
      IMPORTING
        ef_timezone = lv_tz.

    CALL FUNCTION 'TZON_GET_OFFSET'
      EXPORTING
        if_timezone      = lv_tz
        if_local_date    = sy-datum
        if_local_time    = sy-uzeit
      IMPORTING
        ef_utcdiff       = lv_utcdiff
        ef_utcsign       = lv_utcsign
      EXCEPTIONS
        conversion_error = 1
        OTHERS           = 2.
    IF sy-subrc <> 0.
      _raise 'Timezone error'.
    ENDIF.

    CASE lv_utcsign.
      WHEN '+'.
        lv_i = lv_i - lv_utcdiff.
      WHEN '-'.
        lv_i = lv_i + lv_utcdiff.
    ENDCASE.

    rv_time = lv_i.
    CONDENSE rv_time.
    rv_time+11 = lv_utcsign.
    rv_time+12 = lv_utcdiff.

  ENDMETHOD.                    "get

ENDCLASS.                    "lcl_time IMPLEMENTATION

*----------------------------------------------------------------------*
*       CLASS lcl_convert DEFINITION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS lcl_convert DEFINITION FINAL.

  PUBLIC SECTION.
    CLASS-METHODS bitbyte_to_int IMPORTING iv_bits TYPE clike
                                 RETURNING value(rv_int) TYPE i.

    CLASS-METHODS x_to_bitbyte IMPORTING iv_x TYPE x
                               RETURNING value(rv_bitbyte) TYPE t_bitbyte.

    CLASS-METHODS string_to_xstring_utf8 IMPORTING iv_string TYPE string
                                RETURNING value(rv_xstring) TYPE xstring.

    CLASS-METHODS xstring_to_string_utf8 IMPORTING iv_data TYPE xstring
                                         RETURNING value(rv_string) TYPE string.

    CLASS-METHODS xstring_to_int IMPORTING iv_xstring TYPE xstring
                                 RETURNING value(rv_i) TYPE i
                                 RAISING lcx_exception.

    CLASS-METHODS int_to_xstring IMPORTING iv_i TYPE i
                                           iv_length TYPE i
                                 RETURNING value(rv_xstring) TYPE xstring.

ENDCLASS.                    "lcl_convert DEFINITION

*----------------------------------------------------------------------*
*       CLASS lcl_convert IMPLEMENTATION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS lcl_convert IMPLEMENTATION.

  METHOD int_to_xstring.

    DATA: lv_x TYPE x LENGTH 4.


    ASSERT iv_length = 4. " other cases not implemented

    lv_x = iv_i.
    rv_xstring = lv_x.

  ENDMETHOD.                    "int_to_xstring

  METHOD xstring_to_int.

    DATA: lv_xstring TYPE xstring,
          lv_x TYPE x.


    lv_xstring = iv_xstring.
    WHILE xstrlen( lv_xstring ) > 0.
      lv_x = lv_xstring(1).
      rv_i = rv_i * 256 + lv_x.
      lv_xstring = lv_xstring+1.
    ENDWHILE.

  ENDMETHOD.                    "xstring_to_int

  METHOD xstring_to_string_utf8.

    DATA: lv_len    TYPE i,
          lo_obj    TYPE REF TO cl_abap_conv_in_ce.


    TRY.
        lo_obj = cl_abap_conv_in_ce=>create(
            input    = iv_data
            encoding = 'UTF-8' ).
        lv_len = xstrlen( iv_data ).

        lo_obj->read( EXPORTING n    = lv_len
                      IMPORTING data = rv_string ).

      CATCH cx_parameter_invalid_range
            cx_sy_codepage_converter_init
            cx_sy_conversion_codepage
            cx_parameter_invalid_type.                  "#EC NO_HANDLER
    ENDTRY.

  ENDMETHOD.                    "xstring_to_string_utf8

  METHOD string_to_xstring_utf8.

    DATA: lo_obj TYPE REF TO cl_abap_conv_out_ce.


    TRY.
        lo_obj = cl_abap_conv_out_ce=>create( encoding = 'UTF-8' ).

        lo_obj->convert( EXPORTING data = iv_string
                         IMPORTING buffer = rv_xstring ).

      CATCH cx_parameter_invalid_range
            cx_sy_codepage_converter_init
            cx_sy_conversion_codepage
            cx_parameter_invalid_type.                  "#EC NO_HANDLER
    ENDTRY.

  ENDMETHOD.                    "string_to_xstring_utf8

  METHOD bitbyte_to_int.

    DATA: lv_bits TYPE string.


    lv_bits = iv_bits.

    rv_int = 0.
    WHILE strlen( lv_bits ) > 0.
      rv_int = rv_int * 2.
      IF lv_bits(1) = '1'.
        rv_int = rv_int + 1.
      ENDIF.
      lv_bits = lv_bits+1.
    ENDWHILE.

  ENDMETHOD.                    "bitbyte_to_int

  METHOD x_to_bitbyte.

    DATA: lv_b TYPE n.

    CLEAR rv_bitbyte.

    DO 8 TIMES.
      GET BIT sy-index OF iv_x INTO lv_b.
      CONCATENATE rv_bitbyte lv_b INTO rv_bitbyte.
    ENDDO.

  ENDMETHOD.                    "x_to_bitbyte

ENDCLASS.                    "lcl_convert IMPLEMENTATION

*----------------------------------------------------------------------*
*       CLASS lcl_serialize DEFINITION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS lcl_serialize DEFINITION FINAL.

  PUBLIC SECTION.
    CLASS-METHODS serialize IMPORTING iv_obj_type TYPE tadir-object
                                      iv_obj_name TYPE tadir-obj_name
                            RETURNING value(rt_files) TYPE tt_files
                            RAISING lcx_exception.

    CLASS-METHODS status    IMPORTING it_files TYPE tt_files
                            RETURNING value(rt_results) TYPE tt_results
                            RAISING lcx_exception.

    CLASS-METHODS deserialize IMPORTING it_files TYPE tt_files
                            RAISING lcx_exception.

  PRIVATE SECTION.
    CLASS-METHODS prog_serialize
                            IMPORTING iv_obj_name TYPE tadir-obj_name
                            RETURNING value(rt_files) TYPE tt_files
                            RAISING lcx_exception.

    CLASS-METHODS prog_deserialize
                            IMPORTING it_files TYPE tt_files
                                      iv_obj_name TYPE tadir-obj_name
                            RAISING lcx_exception.

    CLASS-METHODS prog_exists
                            IMPORTING iv_obj_name TYPE tadir-obj_name
                            RETURNING value(rv_bool) TYPE abap_bool.

    CLASS-METHODS compare_files
                            IMPORTING it_repo TYPE tt_files
                                      it_sap TYPE tt_files
                            RETURNING value(rv_match) TYPE abap_bool
                            RAISING lcx_exception.

ENDCLASS.                    "lcl_serialize DEFINITION

*----------------------------------------------------------------------*
*       CLASS lcl_serialize IMPLEMENTATION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS lcl_serialize IMPLEMENTATION.

  METHOD prog_exists.

    DATA: lv_progname TYPE reposrc-progname.


    SELECT SINGLE progname FROM reposrc INTO lv_progname
      WHERE progname = iv_obj_name.                         "#EC WARNOK
    IF sy-subrc = 0.
      rv_bool = abap_true.
    ELSE.
      rv_bool = abap_false.
    ENDIF.

  ENDMETHOD.                    "prog_exists

  METHOD serialize.

    CASE iv_obj_type.
      WHEN 'PROG'.
        rt_files = prog_serialize( iv_obj_name ).
      WHEN OTHERS.
        _raise 'Serialize, unknown type'.
    ENDCASE.

  ENDMETHOD.                    "serialize

  METHOD status.

    DATA: lv_pre    TYPE tadir-obj_name,
          lt_files  TYPE tt_files,
          ls_result LIKE LINE OF rt_results,
          lv_type   TYPE string,
          lv_ext    TYPE string.

    FIELD-SYMBOLS: <ls_file> LIKE LINE OF it_files.


    LOOP AT it_files ASSIGNING <ls_file>.
      SPLIT <ls_file>-filename AT '.' INTO lv_pre lv_type lv_ext.
      TRANSLATE lv_pre TO UPPER CASE.
      TRANSLATE lv_type TO UPPER CASE.

      IF lv_ext <> 'xml'.
        CONTINUE. " current loop
      ENDIF.

      CLEAR ls_result.
      ls_result-obj_type = lv_type.
      ls_result-obj_name = lv_pre.

      CASE lv_type.
        WHEN 'PROG'.
          IF prog_exists( lv_pre ) = abap_true.
            lt_files = prog_serialize( lv_pre ).
            ls_result-match = compare_files( it_repo = it_files it_sap = lt_files ).
          ENDIF.
        WHEN OTHERS.
          _raise 'status, unknown type'.
      ENDCASE.

      APPEND ls_result TO rt_results.
    ENDLOOP.

* todo, how to handle deleted in repo?

  ENDMETHOD.                    "status

  METHOD deserialize.

    DATA: lv_pre   TYPE tadir-obj_name,
          lv_type  TYPE string,
          lv_ext   TYPE string.

    FIELD-SYMBOLS: <ls_file> LIKE LINE OF it_files.


    LOOP AT it_files ASSIGNING <ls_file>.
      SPLIT <ls_file>-filename AT '.' INTO lv_pre lv_type lv_ext.
      TRANSLATE lv_pre TO UPPER CASE.
      TRANSLATE lv_type TO UPPER CASE.

      IF lv_ext <> 'xml'.
        CONTINUE. " current loop
      ENDIF.

      CASE lv_type.
        WHEN 'PROG'.
          prog_deserialize( it_files = it_files iv_obj_name = lv_pre ).
        WHEN OTHERS.
          _raise 'deserialize, unknown type'.
      ENDCASE.
    ENDLOOP.

  ENDMETHOD.                    "deserialize

  METHOD compare_files.

    FIELD-SYMBOLS: <ls_sap> TYPE st_file.


    LOOP AT it_sap ASSIGNING <ls_sap>.
      READ TABLE it_repo WITH KEY path = <ls_sap>-path
                                  filename = <ls_sap>-filename
                                  data = <ls_sap>-data
        TRANSPORTING NO FIELDS.
      IF sy-subrc <> 0.
        rv_match = abap_false.
        RETURN.
      ENDIF.
    ENDLOOP.

    rv_match = abap_true.

  ENDMETHOD.                    "compare_files

  METHOD prog_serialize.

    DATA: ls_progdir     TYPE progdir,
          lv_program_name TYPE programm,
          lv_xml          TYPE string,
          lt_source       TYPE TABLE OF abaptxt255,
          lv_source       TYPE string,
          lt_textelements TYPE textpool_table,
          ls_file         LIKE LINE OF rt_files,
          lo_xml          TYPE REF TO lcl_xml.


    lv_program_name = iv_obj_name.

    CALL FUNCTION 'RPY_PROGRAM_READ'
      EXPORTING
        program_name     = lv_program_name
      TABLES
        source_extended  = lt_source
        textelements     = lt_textelements
      EXCEPTIONS
        cancelled        = 1
        not_found        = 2
        permission_error = 3
        OTHERS           = 4.
    IF sy-subrc <> 0.
      _raise 'Error reading program'.
    ENDIF.

    SELECT SINGLE * FROM progdir INTO ls_progdir WHERE name = lv_program_name AND state = 'A'.
    IF sy-subrc <> 0.
      _raise 'not found in progdir'.
    ENDIF.

    CLEAR: ls_progdir-cnam,
           ls_progdir-cdat,
           ls_progdir-unam,
           ls_progdir-udat,
           ls_progdir-vern,
           ls_progdir-rmand,
           ls_progdir-sdate,
           ls_progdir-stime,
           ls_progdir-idate,
           ls_progdir-itime.

    CREATE OBJECT lo_xml.
    lo_xml->structure_add( ls_progdir ).
    lo_xml->table_add( lt_textelements ).
    lv_xml = lo_xml->render( ).

    CLEAR ls_file.
    ls_file-path = '/'.
    CONCATENATE lv_program_name '.prog.xml' INTO ls_file-filename. "#EC NOTEXT
    TRANSLATE ls_file-filename TO LOWER CASE.
    ls_file-data = lcl_convert=>string_to_xstring_utf8( lv_xml ).
    APPEND ls_file TO rt_files.

    CONCATENATE LINES OF lt_source INTO lv_source SEPARATED BY gc_newline.
    CLEAR ls_file.
    ls_file-path = '/'.
    CONCATENATE lv_program_name '.prog.abap' INTO ls_file-filename. "#EC NOTEXT
    TRANSLATE ls_file-filename TO LOWER CASE.
    ls_file-data = lcl_convert=>string_to_xstring_utf8( lv_source ).
    APPEND ls_file TO rt_files.

  ENDMETHOD.                    "prog_serialize


  METHOD prog_deserialize.

    DATA: lv_name        TYPE string,
          lv_xml         TYPE string,
          ls_progdir     TYPE progdir,
          ls_progdir_new TYPE progdir,
          lo_xml         TYPE REF TO lcl_xml,
          lt_source      TYPE TABLE OF abaptxt255,
          lv_abap        TYPE string.

    FIELD-SYMBOLS: <ls_xml>  LIKE LINE OF it_files,
                   <ls_abap> LIKE LINE OF it_files.


    lv_name = iv_obj_name && '.prog.xml'.                   "#EC NOTEXT
    TRANSLATE lv_name TO LOWER CASE.
    READ TABLE it_files ASSIGNING <ls_xml> WITH KEY filename = lv_name.
    IF sy-subrc <> 0.
      _raise 'PROG, xml not found'.
    ENDIF.

    lv_name = iv_obj_name && '.prog.abap'.                  "#EC NOTEXT
    TRANSLATE lv_name TO LOWER CASE.
    READ TABLE it_files ASSIGNING <ls_abap> WITH KEY filename = lv_name.
    IF sy-subrc <> 0.
      _raise 'PROG, abap not found'.
    ENDIF.

    lv_xml = lcl_convert=>xstring_to_string_utf8( <ls_xml>-data ).
    lv_abap = lcl_convert=>xstring_to_string_utf8( <ls_abap>-data ).

    CREATE OBJECT lo_xml
      EXPORTING
        iv_xml = lv_xml.
    lo_xml->structure_read( CHANGING cg_structure = ls_progdir ).

    SPLIT lv_abap AT gc_newline INTO TABLE lt_source.

    IF prog_exists( iv_obj_name ) = abap_true.
      CALL FUNCTION 'RPY_PROGRAM_UPDATE'
        EXPORTING
          program_name     = ls_progdir-name
        TABLES
          source_extended  = lt_source
        EXCEPTIONS
          cancelled        = 1
          permission_error = 2
          not_found        = 3
          OTHERS           = 4.
      IF sy-subrc <> 0.
        _raise 'PROG, error updating'.
      ENDIF.
    ELSE.
      CALL FUNCTION 'RPY_PROGRAM_INSERT'
        EXPORTING
          application         = ls_progdir-appl
          authorization_group = ls_progdir-secu
          program_name        = ls_progdir-name
          program_type        = ls_progdir-subc
          title_string        = 'todo'
        TABLES
          source_extended     = lt_source
        EXCEPTIONS
          already_exists      = 1
          cancelled           = 2
          name_not_allowed    = 3
          permission_error    = 4
          OTHERS              = 5.
      IF sy-subrc <> 0.
        _raise 'PROG, error inserting'.
      ENDIF.

      SELECT SINGLE * FROM progdir INTO ls_progdir_new
        WHERE name = ls_progdir-name AND state = 'A'.
      IF sy-subrc <> 0.
        _raise 'not found in PROGDIR'.
      ENDIF.

      ls_progdir_new-ldbname = ls_progdir-ldbname.
      ls_progdir_new-dbapl = ls_progdir-dbapl.
      ls_progdir_new-rload = ls_progdir-rload.

      CALL FUNCTION 'UPDATE_PROGDIR'
        EXPORTING
          i_progdir    = ls_progdir_new
          i_progname   = ls_progdir_new-name
          i_state      = ls_progdir_new-state
        EXCEPTIONS
          not_executed = 1
          OTHERS       = 2.
      IF sy-subrc <> 0.
        _raise 'PROG, error inserting'.
      ENDIF.

      COMMIT WORK.
    ENDIF.

  ENDMETHOD.                    "p_deserialize

ENDCLASS.                    "lcl_serialize IMPLEMENTATION

*----------------------------------------------------------------------*
*       CLASS lcl_hash DEFINITION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS lcl_hash DEFINITION FINAL.

  PUBLIC SECTION.
    CLASS-METHODS adler32 IMPORTING iv_xstring TYPE xstring
                          RETURNING value(rv_checksum) TYPE t_adler32.

    CLASS-METHODS sha1 IMPORTING iv_type TYPE t_type
                                 iv_data TYPE xstring
                       RETURNING value(rv_sha1) TYPE t_sha1
                       RAISING lcx_exception.

    CLASS-METHODS sha1_raw IMPORTING iv_data TYPE xstring
                       RETURNING value(rv_sha1) TYPE t_sha1
                       RAISING lcx_exception.

ENDCLASS.                    "lcl_hash DEFINITION

*----------------------------------------------------------------------*
*       CLASS lcl_hash IMPLEMENTATION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS lcl_hash IMPLEMENTATION.

  METHOD adler32.

    CONSTANTS: lc_adler TYPE i VALUE 65521.

    DATA: lv_index TYPE i,
          lv_a     TYPE i VALUE 1,
          lv_b     TYPE i VALUE 0,
          lv_x     TYPE x LENGTH 2,
          lv_ca    TYPE c LENGTH 4,
          lv_cb    TYPE c LENGTH 4,
          lv_char8 TYPE c LENGTH 8.


    DO xstrlen( iv_xstring ) TIMES.
      lv_index = sy-index - 1.

      lv_a = ( lv_a + iv_xstring+lv_index(1) ) MOD lc_adler.
      lv_b = ( lv_b + lv_a ) MOD lc_adler.
    ENDDO.

    lv_x = lv_a.
    lv_ca = lv_x.

    lv_x = lv_b.
    lv_cb = lv_x.

    CONCATENATE lv_cb lv_ca INTO lv_char8.

    rv_checksum = lv_char8.

  ENDMETHOD.                    "adler32

  METHOD sha1_raw.

    DATA: lv_hash TYPE hash160.


    CALL FUNCTION 'CALCULATE_HASH_FOR_RAW'
      EXPORTING
        data           = iv_data
      IMPORTING
        hash           = lv_hash
      EXCEPTIONS
        unknown_alg    = 1
        param_error    = 2
        internal_error = 3
        OTHERS         = 4.
    IF sy-subrc <> 0.
      _raise 'Error while calculating SHA1'.
    ENDIF.

    rv_sha1 = lv_hash.

  ENDMETHOD.                    "sha1_raw

  METHOD sha1.

    DATA: lv_len     TYPE i,
          lv_char10  TYPE c LENGTH 10,

          lv_string  TYPE string,
          lv_xstring TYPE xstring.


    lv_len = xstrlen( iv_data ).
    lv_char10 = lv_len.
    CONDENSE lv_char10.
    CONCATENATE iv_type lv_char10 INTO lv_string SEPARATED BY space.
    lv_xstring = lcl_convert=>string_to_xstring_utf8( lv_string ).

    lv_string = lv_xstring.
    CONCATENATE lv_string '00' INTO lv_string.
    lv_xstring = lv_string.

    CONCATENATE lv_xstring iv_data INTO lv_xstring IN BYTE MODE.

    rv_sha1 = sha1_raw( lv_xstring ).

  ENDMETHOD.                    "sha1

ENDCLASS.                    "lcl_hash IMPLEMENTATION

*----------------------------------------------------------------------*
*       CLASS lcl_pack DEFINITION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS lcl_pack DEFINITION FINAL.

  PUBLIC SECTION.

    CLASS-METHODS decode IMPORTING iv_data TYPE xstring
                         RETURNING value(rt_objects) TYPE tt_objects
                         RAISING lcx_exception.

    CLASS-METHODS decode_tree IMPORTING iv_data TYPE xstring
                         RETURNING value(rt_nodes) TYPE tt_nodes
                         RAISING lcx_exception.

    CLASS-METHODS decode_deltas CHANGING ct_objects TYPE tt_objects
                         RAISING lcx_exception.

    CLASS-METHODS decode_commit IMPORTING iv_data TYPE xstring
                         RETURNING value(rs_commit) TYPE st_commit
                         RAISING lcx_exception.

    CLASS-METHODS encode IMPORTING it_objects TYPE tt_objects
                         RETURNING value(rv_data) TYPE xstring
                         RAISING lcx_exception.

    CLASS-METHODS: encode_tree IMPORTING it_nodes TYPE tt_nodes
                         RETURNING value(rv_data) TYPE xstring.

    CLASS-METHODS: encode_commit IMPORTING is_commit TYPE st_commit
                         RETURNING value(rv_data) TYPE xstring.


  PRIVATE SECTION.

    CONSTANTS: c_pack_start TYPE x LENGTH 4 VALUE '5041434B', " PACK
               c_debug_pack TYPE abap_bool VALUE abap_false,
               c_zlib       TYPE x LENGTH 2 VALUE '789C',
               c_zlib_hmm   TYPE x LENGTH 2 VALUE '7801',
               c_version    TYPE x LENGTH 4 VALUE '00000002'.

    CLASS-METHODS type_and_length IMPORTING is_object TYPE st_object
                                  RETURNING value(rv_xstring) TYPE xstring
                                  RAISING lcx_exception.

    CLASS-METHODS delta IMPORTING is_object TYPE st_object
                        CHANGING ct_objects TYPE tt_objects
                        RAISING lcx_exception.

    CLASS-METHODS delta_header CHANGING cv_delta TYPE xstring.

    CLASS-METHODS get_type IMPORTING iv_x TYPE x
                           RETURNING value(rv_type) TYPE t_type
                           RAISING lcx_exception.

    CLASS-METHODS get_length EXPORTING ev_length TYPE i
                             CHANGING cv_data TYPE xstring.

ENDCLASS.                    "lcl_pack DEFINITION

*----------------------------------------------------------------------*
*       CLASS lcl_pack IMPLEMENTATION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS lcl_pack IMPLEMENTATION.

  METHOD type_and_length.

    DATA: lv_bits   TYPE string,
          lv_type   TYPE string,
          lv_result TYPE string,
          lv_c      TYPE c,
          lv_offset TYPE i,
          lv_x4     TYPE x LENGTH 4,
          lv_x      TYPE x LENGTH 1.


    CASE is_object-type.
      WHEN gc_commit.
        lv_type = '001'.
      WHEN gc_tree.
        lv_type = '010'.
      WHEN gc_blob.
        lv_type = '011'.
      WHEN gc_ref_d.
        lv_type = '111'.
      WHEN OTHERS.
        _raise 'Unexpected object type while encoding pack'.
    ENDCASE.

    lv_x4 = xstrlen( is_object-data ).
    DO 32 TIMES.
      GET BIT sy-index OF lv_x4 INTO lv_c.
      CONCATENATE lv_bits lv_c INTO lv_bits.
    ENDDO.

    IF lv_bits(28) = '0000000000000000000000000000'.
      CONCATENATE '0' lv_type lv_bits+28(4) INTO lv_result.
    ELSEIF lv_bits(21) = '000000000000000000000'.
      CONCATENATE '1' lv_type lv_bits+28(4) INTO lv_result.
      CONCATENATE lv_result '0' lv_bits+21(7) INTO lv_result.
    ELSE.
* use shifting?
      _raise 'Todo, encoding length'.
    ENDIF.

* convert bit string to xstring
    CLEAR lv_x.
    DO strlen( lv_result ) TIMES.
      lv_offset = sy-index - 1.
      IF lv_result+lv_offset(1) = '1'.
        SET BIT ( lv_offset MOD 8 ) + 1 OF lv_x.
      ENDIF.
      IF ( lv_offset + 1 ) MOD 8 = 0.
        CONCATENATE rv_xstring lv_x INTO rv_xstring IN BYTE MODE.
        CLEAR lv_x.
      ENDIF.
    ENDDO.

  ENDMETHOD.                    "type_and_length

  METHOD get_length.

    DATA: lv_x           TYPE x,
          lv_length_bits TYPE string,
          lv_bitbyte     TYPE t_bitbyte.


    lv_x = cv_data(1).
    IF c_debug_pack = abap_true.
      WRITE: / 'A:', lv_x, '(hex)'.                         "#EC NOTEXT
    ENDIF.
    lv_bitbyte = lcl_convert=>x_to_bitbyte( lv_x ).
    IF c_debug_pack = abap_true.
      WRITE: lv_bitbyte.
    ENDIF.

    cv_data = cv_data+1.
    lv_length_bits = lv_bitbyte+4.

    WHILE lv_bitbyte(1) <> '0'.
      lv_x = cv_data(1).
      IF c_debug_pack = abap_true.
        WRITE: / 'x:', lv_x, '(hex)'.                       "#EC NOTEXT
      ENDIF.
      lv_bitbyte = lcl_convert=>x_to_bitbyte( lv_x ).
      IF c_debug_pack = abap_true.
        WRITE: lv_bitbyte.
      ENDIF.
      cv_data = cv_data+1.
      CONCATENATE lv_bitbyte+1 lv_length_bits INTO lv_length_bits.
    ENDWHILE.

    ev_length = lcl_convert=>bitbyte_to_int( lv_length_bits ).

  ENDMETHOD.                    "get_length

  METHOD encode_tree.

    DATA: lv_string  TYPE string,
          lv_null    TYPE x,
          lt_nodes   LIKE it_nodes,
          lv_xstring TYPE xstring.

    FIELD-SYMBOLS: <ls_node> LIKE LINE OF it_nodes.


    lv_null = '00'.

    lt_nodes[] = it_nodes[].
    SORT lt_nodes BY name ASCENDING. " this has to be done, or unpack will fail on server side

    LOOP AT lt_nodes ASSIGNING <ls_node>.
      CONCATENATE <ls_node>-chmod <ls_node>-name INTO lv_string SEPARATED BY space.
      lv_xstring = lcl_convert=>string_to_xstring_utf8( lv_string ).

      CONCATENATE rv_data lv_xstring lv_null <ls_node>-sha1 INTO rv_data IN BYTE MODE.
    ENDLOOP.

  ENDMETHOD.                    "encode_tree

  METHOD encode_commit.

    DATA: lv_string       TYPE string,
          lv_tmp          TYPE string,
          lv_tree_lower   TYPE string,
          lv_parent_lower TYPE string.


    lv_tree_lower = is_commit-tree.
    TRANSLATE lv_tree_lower TO LOWER CASE.

    lv_parent_lower = is_commit-parent.
    TRANSLATE lv_parent_lower TO LOWER CASE.

    lv_string = ''.

    CONCATENATE 'tree' lv_tree_lower INTO lv_tmp SEPARATED BY space. "#EC NOTEXT
    CONCATENATE lv_string lv_tmp gc_newline INTO lv_string.

    IF NOT is_commit-parent IS INITIAL.
      CONCATENATE 'parent' lv_parent_lower INTO lv_tmp  SEPARATED BY space. "#EC NOTEXT
      CONCATENATE lv_string lv_tmp gc_newline INTO lv_string.
    ENDIF.

    CONCATENATE 'author' is_commit-author INTO lv_tmp  SEPARATED BY space. "#EC NOTEXT
    CONCATENATE lv_string lv_tmp gc_newline INTO lv_string.

    CONCATENATE 'committer' is_commit-committer INTO lv_tmp SEPARATED BY space. "#EC NOTEXT
    CONCATENATE lv_string lv_tmp gc_newline INTO lv_string.

    CONCATENATE lv_string gc_newline is_commit-body INTO lv_string.

    rv_data = lcl_convert=>string_to_xstring_utf8( lv_string ).

  ENDMETHOD.                    "encode_commit

  METHOD get_type.

    DATA: lv_char3   TYPE c LENGTH 3,
          lv_bitbyte TYPE t_bitbyte.


    lv_bitbyte = lcl_convert=>x_to_bitbyte( iv_x ).
    lv_char3 = lv_bitbyte+1.

    CASE lv_char3.
      WHEN '001'.
        rv_type = gc_commit.
      WHEN '010'.
        rv_type = gc_tree.
      WHEN '011'.
        rv_type = gc_blob.
      WHEN '111'.
        rv_type = gc_ref_d.
      WHEN OTHERS.
        _raise 'Todo, unknown type'.
    ENDCASE.

  ENDMETHOD.                    "get_type

  METHOD decode_commit.

    DATA: lv_string TYPE string,
          lv_char40 TYPE c LENGTH 40,
          lv_mode   TYPE string,
          lv_len    TYPE i,
          lt_string TYPE TABLE OF string.

    FIELD-SYMBOLS: <lv_string> TYPE string.


    lv_string = lcl_convert=>xstring_to_string_utf8( iv_data ).

    SPLIT lv_string AT gc_newline INTO TABLE lt_string.

    lv_mode = 'tree'.                                       "#EC NOTEXT
    LOOP AT lt_string ASSIGNING <lv_string>.
      lv_len = strlen( lv_mode ).

      IF NOT lv_mode IS INITIAL AND <lv_string>(lv_len) = lv_mode.
        CASE lv_mode.
          WHEN 'tree'.
            lv_char40 = <lv_string>+5.
            TRANSLATE lv_char40 TO UPPER CASE.
            rs_commit-tree = lv_char40.
            lv_mode = 'parent'.                             "#EC NOTEXT
          WHEN 'parent'.
            lv_char40 = <lv_string>+7.
            TRANSLATE lv_char40 TO UPPER CASE.
            rs_commit-parent = lv_char40.
            lv_mode = 'author'.                             "#EC NOTEXT
          WHEN 'author'.
            rs_commit-author = <lv_string>+7.
            lv_mode = 'committer'.                          "#EC NOTEXT
          WHEN 'committer'.
            rs_commit-committer = <lv_string>+10.
            CLEAR lv_mode.
        ENDCASE.
      ELSEIF lv_mode = 'parent' AND <lv_string>(6) = 'author'. "#EC NOTEXT
* first commit doesnt have parent
        rs_commit-author = <lv_string>+7.
        lv_mode = 'committer'.                              "#EC NOTEXT
      ELSE.
* body
        CONCATENATE rs_commit-body <lv_string> INTO rs_commit-body
          SEPARATED BY gc_newline.
      ENDIF.
    ENDLOOP.

* strip first newline
    IF strlen( rs_commit-body ) >= 2.
      rs_commit-body = rs_commit-body+2.
    ENDIF.

    IF rs_commit-author IS INITIAL
        OR rs_commit-committer IS INITIAL
        OR rs_commit-tree IS INITIAL.
      _raise 'multiple parents? not supported'.
    ENDIF.

  ENDMETHOD.                    "decode_commit

  METHOD delta_header.

    DATA: lv_bitbyte TYPE t_bitbyte,
          lv_header1 TYPE i,                                "#EC NEEDED
          lv_header2 TYPE i,                                "#EC NEEDED
          lv_bits    TYPE string,
          lv_x       TYPE x.

* todo, use headers for verification

* Header 1
    lv_bits = ''.
    DO.
      lv_x = cv_delta(1).
      cv_delta = cv_delta+1.
      lv_bitbyte = lcl_convert=>x_to_bitbyte( lv_x ).
      CONCATENATE lv_bitbyte+1 lv_bits INTO lv_bits.
      IF lv_bitbyte(1) = '0'.
        EXIT. " current loop
      ENDIF.
    ENDDO.
    lv_header1 = lcl_convert=>bitbyte_to_int( lv_bits ).

* Header 2
    lv_bits = ''.
    DO.
      lv_x = cv_delta(1).
      cv_delta = cv_delta+1.
      lv_bitbyte = lcl_convert=>x_to_bitbyte( lv_x ).
      CONCATENATE lv_bitbyte+1 lv_bits INTO lv_bits.
      IF lv_bitbyte(1) = '0'.
        EXIT. " current loop
      ENDIF.
    ENDDO.
    lv_header2 = lcl_convert=>bitbyte_to_int( lv_bits ).

  ENDMETHOD.                    "delta_header

  METHOD delta.

    DATA: lv_delta   TYPE xstring,
          lv_base    TYPE xstring,
          lv_result  TYPE xstring,
          lv_bitbyte TYPE t_bitbyte,
          lv_offset  TYPE i,
          ls_object  LIKE LINE OF ct_objects,
          lv_len     TYPE i,
          lv_x       TYPE x.

    FIELD-SYMBOLS: <ls_object> LIKE LINE OF ct_objects.



    lv_delta = is_object-data.

* find base
    READ TABLE ct_objects ASSIGNING <ls_object> WITH KEY sha1 = is_object-sha1.
    IF sy-subrc <> 0.
      _raise 'Base not found'.
    ELSE.
      lv_base = <ls_object>-data.
    ENDIF.


    delta_header( CHANGING cv_delta = lv_delta ).


    WHILE xstrlen( lv_delta ) > 0.

      lv_x = lv_delta(1).
      lv_delta = lv_delta+1.
      lv_bitbyte = lcl_convert=>x_to_bitbyte( lv_x ).
*    WRITE: / 'Opcode', lv_x, lv_bitbyte.

      IF lv_bitbyte(1) = '1'. " MSB

        lv_offset = 0.
        IF lv_bitbyte+7(1) = '1'.
          lv_x = lv_delta(1).
          lv_delta = lv_delta+1.
          lv_offset = lv_x.
        ENDIF.
        IF lv_bitbyte+6(1) = '1'.
          lv_x = lv_delta(1).
          lv_delta = lv_delta+1.
          lv_offset = lv_offset + lv_x * 256.
        ENDIF.
        IF lv_bitbyte+5(1) = '1'.
          lv_x = lv_delta(1).
          lv_delta = lv_delta+1.
          lv_offset = lv_offset + lv_x * 65536.
        ENDIF.
        IF lv_bitbyte+4(1) = '1'.
          lv_x = lv_delta(1).
          lv_delta = lv_delta+1.
          lv_offset = lv_offset + lv_x * 16777216. " hmm, overflow?
        ENDIF.

        lv_len = 0.
        IF lv_bitbyte+3(1) = '1'.
          lv_x = lv_delta(1).
          lv_delta = lv_delta+1.
          lv_len = lv_x.
        ENDIF.
        IF lv_bitbyte+2(1) = '1'.
          lv_x = lv_delta(1).
          lv_delta = lv_delta+1.
          lv_len = lv_len + lv_x * 256.
        ENDIF.
        IF lv_bitbyte+1(1) = '1'.
          lv_x = lv_delta(1).
          lv_delta = lv_delta+1.
          lv_len = lv_len + lv_x * 65536.
        ENDIF.

        CONCATENATE lv_result lv_base+lv_offset(lv_len) INTO lv_result IN BYTE MODE.
      ELSE. " lv_bitbyte(1) = '0'
* insert from delta
        lv_len = lv_x.
        CONCATENATE lv_result lv_delta(lv_len) INTO lv_result IN BYTE MODE.
        lv_delta = lv_delta+lv_len.
      ENDIF.

    ENDWHILE.

    CLEAR ls_object.
    ls_object-sha1 = lcl_hash=>sha1( iv_type = <ls_object>-type iv_data = lv_result ).
    ls_object-type = <ls_object>-type.
    ls_object-data = lv_result.
    APPEND ls_object TO ct_objects.

  ENDMETHOD.                    "delta

  METHOD decode_deltas.

    DATA: ls_object LIKE LINE OF ct_objects,
          lt_deltas LIKE ct_objects.


    LOOP AT ct_objects INTO ls_object WHERE type = gc_ref_d.
      DELETE ct_objects INDEX sy-tabix.
      APPEND ls_object TO lt_deltas.
    ENDLOOP.

    LOOP AT lt_deltas INTO ls_object.
      delta( EXPORTING is_object = ls_object
             CHANGING ct_objects = ct_objects ).
    ENDLOOP.

  ENDMETHOD.                    "decode_deltas

  METHOD decode_tree.

    CONSTANTS: lc_sha_length TYPE i VALUE 20.

    DATA: lv_xstring TYPE xstring,
          lv_chmod   TYPE string,
          lv_name    TYPE string,
          lv_string  TYPE string,
          lv_len     TYPE i,
          lv_offset  TYPE i,
          lv_cursor  TYPE i,
          ls_node    TYPE st_node,
          lv_start   TYPE i.

    DO.
      IF lv_cursor >= xstrlen( iv_data ).
        EXIT. " current loop
      ENDIF.

      IF iv_data+lv_cursor(1) = '00'.
        lv_len = lv_cursor - lv_start.
        lv_xstring = iv_data+lv_start(lv_len).

        lv_string = lcl_convert=>xstring_to_string_utf8( lv_xstring ).
        SPLIT lv_string AT space INTO lv_chmod lv_name.

        lv_offset = lv_cursor + 1.

        CLEAR ls_node.
        ls_node-chmod = lv_chmod.
        IF ls_node-chmod <> gc_chmod_dir AND ls_node-chmod <> gc_chmod_file.
          _raise 'Unknown chmod'.
        ENDIF.

        ls_node-name = lv_name.
        ls_node-sha1 = iv_data+lv_offset(lc_sha_length).
        APPEND ls_node TO rt_nodes.

        lv_start = lv_cursor + 1 + lc_sha_length.
        lv_cursor = lv_start.
      ELSE.
        lv_cursor = lv_cursor + 1.
      ENDIF.
    ENDDO.

  ENDMETHOD.                    "decode_tree

  METHOD decode.

    DATA: lv_x           TYPE x,
          lv_data        TYPE xstring,
          lv_type        TYPE c LENGTH 6,
          lv_zlib        TYPE x LENGTH 2,
          lv_objects     TYPE i,
          lv_len         TYPE i,
          lv_sha1        TYPE t_sha1,
          lv_ref_delta   TYPE t_sha1,
          lv_adler32     TYPE t_adler32,
          lv_compressed     TYPE xstring,
          lv_compressed_len TYPE i,
          lv_decompress_len TYPE i,
          lv_decompressed   TYPE xstring,
          lv_xstring     TYPE xstring,
          lv_expected    TYPE i,
          ls_object      LIKE LINE OF rt_objects.


    lv_data = iv_data.

* header
    IF NOT xstrlen( lv_data ) > 4 OR lv_data(4) <> c_pack_start.
      _raise 'Unexpected pack header'.
    ENDIF.
    lv_data = lv_data+4.

* version
    IF lv_data(4) <> c_version.
      _raise 'Version not supported'.
    ENDIF.
    lv_data = lv_data+4.

* number of objects
    lv_xstring = lv_data(4).
    lv_objects = lcl_convert=>xstring_to_int( lv_xstring ).
    lv_data = lv_data+4.


    DO lv_objects TIMES.

      lv_x = lv_data(1).
      lv_type = get_type( lv_x ).

      get_length( IMPORTING ev_length = lv_expected
                  CHANGING cv_data = lv_data ).

      IF lv_type = gc_ref_d.
        lv_ref_delta = lv_data(20).
        lv_data = lv_data+20.
      ENDIF.

* strip header, '789C', CMF + FLG
      lv_zlib = lv_data(2).
      IF lv_zlib <> c_zlib AND lv_zlib <> c_zlib_hmm.
        _raise 'Unexpected zlib header'.
      ENDIF.
      lv_data = lv_data+2.

*******************************

      IF lv_zlib = c_zlib.
        cl_abap_gzip=>decompress_binary(
          EXPORTING
            gzip_in     = lv_data
          IMPORTING
            raw_out     = lv_decompressed
            raw_out_len = lv_decompress_len ).

        IF lv_expected <> lv_decompress_len.
          _raise 'Decompression falied'.
        ENDIF.

        cl_abap_gzip=>compress_binary(
          EXPORTING
            raw_in         = lv_decompressed
          IMPORTING
            gzip_out       = lv_compressed
            gzip_out_len   = lv_compressed_len ).

        IF lv_compressed(lv_compressed_len) <> lv_data(lv_compressed_len).
          _raise 'Compressed data doesnt match'.
        ENDIF.

        lv_data = lv_data+lv_compressed_len.
        lv_data = lv_data+4. " skip adler checksum

      ELSEIF lv_zlib = c_zlib_hmm.
* this takes some processing, when time permits, implement DEFLATE algorithm
* cl_abap_gzip copmression works for '789C', but does not produce the same
* result when '7801'
* compressed data might be larger than origial so add 10, adding 10 is safe
* as package always ends with sha1 checksum
        DO lv_expected + 10 TIMES.
          lv_compressed_len = sy-index.

          cl_abap_gzip=>decompress_binary(
            EXPORTING
              gzip_in     = lv_data
              gzip_in_len = lv_compressed_len
            IMPORTING
              raw_out     = lv_decompressed
              raw_out_len = lv_decompress_len ).

          IF lv_decompress_len = lv_expected.
            EXIT.
          ELSE.
            CLEAR lv_compressed_len.
          ENDIF.
        ENDDO.

        IF lv_compressed_len IS INITIAL.
          _raise 'Decompression falied :o/'.
        ENDIF.

        lv_data = lv_data+lv_compressed_len.

        lv_adler32 = lcl_hash=>adler32( lv_decompressed ).
        IF lv_data(4) <> lv_adler32.
          lv_data = lv_data+1.
        ENDIF.
        IF lv_data(4) <> lv_adler32.
          lv_data = lv_data+1.
        ENDIF.
        IF lv_data(4) <> lv_adler32.
          _raise 'Wrong Adler checksum'.
        ENDIF.

        lv_data = lv_data+4. " skip adler checksum

      ENDIF.

*************************

      CLEAR ls_object.
      IF lv_type = gc_ref_d.
        ls_object-sha1 = lv_ref_delta.
      ELSE.
        ls_object-sha1 = lcl_hash=>sha1( iv_type = lv_type iv_data = lv_decompressed ).
      ENDIF.
      ls_object-type = lv_type.
      ls_object-data = lv_decompressed.
      APPEND ls_object TO rt_objects.

      IF c_debug_pack = abap_true.
        WRITE: /.
      ENDIF.
    ENDDO.

* check SHA1 at end of pack
    lv_len = xstrlen( iv_data ) - 20.
    lv_xstring = iv_data(lv_len).
    lv_sha1 = lcl_hash=>sha1_raw( lv_xstring ).
    IF lv_sha1 <> lv_data.
      _raise 'SHA1 at end of pack doesnt match'.
    ENDIF.

  ENDMETHOD.                    "decode

  METHOD encode.

    DATA: lv_sha1       TYPE t_sha1,
          lv_adler32    TYPE t_adler32,
          lv_len        TYPE i,
          lv_compressed TYPE xstring,
          lv_xstring    TYPE xstring.

    FIELD-SYMBOLS: <ls_object> LIKE LINE OF it_objects.


    rv_data = c_pack_start.

    CONCATENATE rv_data c_version INTO rv_data IN BYTE MODE.

    lv_len = lines( it_objects ).
    lv_xstring = lcl_convert=>int_to_xstring( iv_i      = lv_len
                                              iv_length = 4 ).
    CONCATENATE rv_data lv_xstring INTO rv_data IN BYTE MODE.

    LOOP AT it_objects ASSIGNING <ls_object>.
      lv_xstring = type_and_length( <ls_object> ).
      CONCATENATE rv_data lv_xstring INTO rv_data IN BYTE MODE.

      cl_abap_gzip=>compress_binary(
        EXPORTING
          raw_in   = <ls_object>-data
        IMPORTING
          gzip_out = lv_compressed ).

      CONCATENATE rv_data c_zlib lv_compressed INTO rv_data IN BYTE MODE.

      lv_adler32 = lcl_hash=>adler32( <ls_object>-data ).
      CONCATENATE rv_data lv_adler32  INTO rv_data IN BYTE MODE.

    ENDLOOP.

    lv_sha1 = lcl_hash=>sha1_raw( rv_data ).
    CONCATENATE rv_data lv_sha1 INTO rv_data IN BYTE MODE.

  ENDMETHOD.                    "encode

ENDCLASS.                    "lcl_pack IMPLEMENTATION

*----------------------------------------------------------------------*
*       CLASS lcl_persistence DEFINITION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS lcl_persistence DEFINITION FINAL.

  PUBLIC SECTION.
* class-methods delete

    CLASS-METHODS list RETURNING value(rt_repos) TYPE tt_repos_sha1
                       RAISING lcx_exception.

    CLASS-METHODS update IMPORTING is_repo TYPE st_repo
                                   iv_branch TYPE t_sha1
                         RAISING lcx_exception.

    CLASS-METHODS add IMPORTING is_repo TYPE st_repo
                                   iv_branch TYPE t_sha1
                         RAISING lcx_exception.

  PRIVATE SECTION.
    CLASS-METHODS read_text RETURNING value(rt_repos) TYPE tt_repos_sha1
                            RAISING lcx_exception.

    CLASS-METHODS save_text IMPORTING it_repos TYPE tt_repos_sha1
                            RAISING lcx_exception.

    CLASS-METHODS header RETURNING value(rs_header) TYPE thead.

ENDCLASS.                    "lcl_persistence DEFINITION

*----------------------------------------------------------------------*
*       CLASS lcl_persistence IMPLEMENTATION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS lcl_persistence IMPLEMENTATION.

  METHOD header.
    rs_header-tdid     = 'ST'.
    rs_header-tdspras  = 'E'.
    rs_header-tdname   = 'ZABAPGIT'.
    rs_header-tdobject = 'TEXT'.
  ENDMETHOD.                    "header

  METHOD save_text.

    DATA: lt_lines  TYPE TABLE OF tline,
          ls_header TYPE thead.

    FIELD-SYMBOLS: <ls_repo> LIKE LINE OF it_repos,
                   <ls_line> LIKE LINE OF lt_lines.


    LOOP AT it_repos ASSIGNING <ls_repo>.
      APPEND INITIAL LINE TO lt_lines ASSIGNING <ls_line>.
      <ls_line>-tdformat = '*'.
      <ls_line>-tdline = <ls_repo>-url.
      APPEND INITIAL LINE TO lt_lines ASSIGNING <ls_line>.
      <ls_line>-tdformat = '*'.
      <ls_line>-tdline = <ls_repo>-branch_name.
      APPEND INITIAL LINE TO lt_lines ASSIGNING <ls_line>.
      <ls_line>-tdformat = '*'.
      <ls_line>-tdline = <ls_repo>-sha1.
    ENDLOOP.

    ls_header = header( ).

    CALL FUNCTION 'SAVE_TEXT'
      EXPORTING
        header   = ls_header
      TABLES
        lines    = lt_lines
      EXCEPTIONS
        id       = 1
        language = 2
        name     = 3
        object   = 4
        OTHERS   = 5.
    IF sy-subrc <> 0.
      ROLLBACK WORK.
      _raise 'error from SAVE_TEXT'.
    ENDIF.

    COMMIT WORK.

  ENDMETHOD.                    "save_text

  METHOD add.

    DATA: lt_repos TYPE tt_repos_sha1.

    FIELD-SYMBOLS: <ls_repo> LIKE LINE OF lt_repos.


    IF iv_branch IS INITIAL.
      _raise 'update, sha empty'.
    ENDIF.

    lt_repos = list( ).

    READ TABLE lt_repos WITH KEY url = is_repo-url branch_name = is_repo-branch_name
      TRANSPORTING NO FIELDS.
    IF sy-subrc = 0.
      _raise 'already inserted'.
    ENDIF.

    APPEND INITIAL LINE TO lt_repos ASSIGNING <ls_repo>.
    <ls_repo>-url = is_repo-url.
    <ls_repo>-branch_name = is_repo-branch_name.
    <ls_repo>-sha1 = iv_branch.

    save_text( lt_repos ).

  ENDMETHOD.                    "insert

  METHOD update.

    DATA: lt_repos TYPE tt_repos_sha1.

    FIELD-SYMBOLS: <ls_repo> LIKE LINE OF lt_repos.


    IF iv_branch IS INITIAL.
      _raise 'update, sha empty'.
    ENDIF.

    lt_repos = list( ).

    READ TABLE lt_repos ASSIGNING <ls_repo>
      WITH KEY url = is_repo-url branch_name = is_repo-branch_name.
    IF sy-subrc <> 0.
      _raise 'persist update, repo not found'.
    ENDIF.

    <ls_repo>-sha1 = iv_branch.

    save_text( lt_repos ).

  ENDMETHOD.                    "update

  METHOD list.
    rt_repos = read_text( ).
  ENDMETHOD.                    "list

  METHOD read_text.

    DATA: lt_lines  TYPE TABLE OF tline,
          ls_header TYPE thead,
          ls_repo   TYPE st_repo_sha1.

    FIELD-SYMBOLS: <ls_line> LIKE LINE OF lt_lines.


    ls_header = header( ).

    CALL FUNCTION 'READ_TEXT'
      EXPORTING
        id                      = ls_header-tdid
        language                = ls_header-tdspras
        name                    = ls_header-tdname
        object                  = ls_header-tdobject
      TABLES
        lines                   = lt_lines
      EXCEPTIONS
        id                      = 1
        language                = 2
        name                    = 3
        not_found               = 4
        object                  = 5
        reference_check         = 6
        wrong_access_to_archive = 7
        OTHERS                  = 8.
    IF sy-subrc = 4.
      RETURN.
    ELSEIF sy-subrc <> 0.
      _raise 'Error from READ_TEXT'.
    ENDIF.

    IF lines( lt_lines ) MOD 3 <> 0.
      _raise 'Persistence, text broken'.
    ENDIF.

    CLEAR ls_repo.
    LOOP AT lt_lines ASSIGNING <ls_line>.
      IF <ls_line>-tdline IS INITIAL.
        _raise 'Persistence, text broken'.
      ENDIF.
      IF ls_repo-url IS INITIAL.
        ls_repo-url = <ls_line>-tdline.
        CONTINUE. " current loop
      ENDIF.
      IF ls_repo-branch_name IS INITIAL.
        ls_repo-branch_name = <ls_line>-tdline.
        CONTINUE. " current loop
      ENDIF.

      ls_repo-sha1 = <ls_line>-tdline.
      APPEND ls_repo TO rt_repos.
      CLEAR ls_repo.
    ENDLOOP.

  ENDMETHOD.                    "list

ENDCLASS.                    "lcl_persistence IMPLEMENTATION

*----------------------------------------------------------------------*
*       CLASS lcl_transport DEFINITION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS lcl_transport DEFINITION FINAL.

  PUBLIC SECTION.
* from GitHub to SAP
    CLASS-METHODS upload_pack IMPORTING is_repo TYPE st_repo
                              EXPORTING ev_pack TYPE xstring
                                        ev_branch TYPE t_sha1
                              RAISING lcx_exception.

* from SAP to GitHub
    CLASS-METHODS receive_pack IMPORTING is_repo TYPE st_repo
                                         iv_commit TYPE t_sha1
                                         iv_pack TYPE xstring
                               RAISING lcx_exception.

  PRIVATE SECTION.
    CLASS-METHODS pkt_string
                      IMPORTING iv_string TYPE string
                      RETURNING value(rv_pkt) TYPE string
                      RAISING lcx_exception.

    CLASS-METHODS parse
                      EXPORTING ev_pack TYPE xstring
                      CHANGING cv_data TYPE xstring.

    CLASS-METHODS length_utf8_hex
                      IMPORTING iv_data TYPE xstring
                      RETURNING value(rv_len) TYPE i.

    CLASS-METHODS ref_discovery
                      IMPORTING is_repo TYPE st_repo
                                iv_service TYPE string
                      EXPORTING ei_client TYPE REF TO if_http_client
                                ev_branch TYPE t_sha1
                      RAISING lcx_exception.

    CLASS-METHODS set_headers
                      IMPORTING is_repo TYPE st_repo
                                iv_service TYPE string
                                ii_client TYPE REF TO if_http_client
                      RAISING lcx_exception.

    CLASS-METHODS check_http_200
                      IMPORTING ii_client TYPE REF TO if_http_client
                      RAISING lcx_exception.

    CLASS-METHODS get_null RETURNING value(rv_c) TYPE char1.

ENDCLASS.                    "lcl_transport DEFINITION

*----------------------------------------------------------------------*
*       CLASS lcl_transport IMPLEMENTATION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS lcl_transport IMPLEMENTATION.

  METHOD set_headers.

    ii_client->request->set_header_field(
        name  = '~request_method'
        value = 'POST' ).
    ii_client->request->set_header_field(
        name  = '~request_uri'
        value = lcl_url=>path_name( is_repo-url ) && '.git/git-' && iv_service && '-pack' ).
    ii_client->request->set_header_field(
        name  = 'Content-Type'
        value = 'Content-Type: application/x-git-' && iv_service && '-pack-request' ). "#EC NOTEXT

  ENDMETHOD.                    "set_headers

  METHOD get_null.

    DATA lv_x(4) TYPE x VALUE '00000000'.
    DATA lv_z(2) TYPE c.

    FIELD-SYMBOLS <lv_y> TYPE c.


    ASSIGN lv_x TO <lv_y> CASTING.
    lv_z = <lv_y>.
    rv_c = lv_z(1).

  ENDMETHOD.                    "get_null

  METHOD check_http_200.

    DATA: lv_code TYPE i.


    ii_client->response->get_status(
      IMPORTING
        code   = lv_code ).
    IF lv_code <> 200.
      _raise 'HTTP error code'.
    ENDIF.

  ENDMETHOD.                    "http_200

  METHOD ref_discovery.

    DATA: lv_hash   TYPE c LENGTH 40,
          lv_len    TYPE i,
          lt_result TYPE TABLE OF string,
          lv_data   TYPE string.


    cl_http_client=>create_by_url(
      EXPORTING
        url    = lcl_url=>host( is_repo-url )
      IMPORTING
        client = ei_client ).

    ei_client->request->set_cdata( '' ).
    ei_client->request->set_header_field(
        name  = '~request_method'
        value = 'GET' ).
    ei_client->request->set_header_field(
        name  = '~request_uri'
        value = lcl_url=>path_name( is_repo-url ) && '.git/info/refs?service=git-' && iv_service && '-pack' ).
    ei_client->send( ).
    ei_client->receive( ).

    check_http_200( ei_client ).

    lv_data = ei_client->response->get_cdata( ).

    IF is_repo-branch_name IS INITIAL.
      _raise 'branch empty'.
    ENDIF.

    lv_len = strlen( is_repo-branch_name ).
    SPLIT lv_data AT gc_newline INTO TABLE lt_result.
    LOOP AT lt_result INTO lv_data.
      IF sy-tabix = 1.
        CONTINUE. " current loop
      ELSEIF sy-tabix = 2 AND strlen( lv_data ) > 49 AND lv_data+49(lv_len) = is_repo-branch_name.
        lv_hash = lv_data+8.
        EXIT. " current loop
      ELSEIF sy-tabix > 2 AND strlen( lv_data ) > 45 AND lv_data+45 = is_repo-branch_name.
        lv_hash = lv_data+4.
        EXIT. " current loop
      ENDIF.
    ENDLOOP.

    TRANSLATE lv_hash TO UPPER CASE.
    IF strlen( lv_hash ) <> 40.
      _raise 'Branch not found'.
    ENDIF.

    ev_branch = lv_hash.

  ENDMETHOD.                    "ref_discovery

  METHOD receive_pack.

    CONSTANTS: lc_service TYPE string VALUE 'receive'.      "#EC NOTEXT

    DATA: li_client  TYPE REF TO if_http_client,
          lv_cmd_pkt TYPE string,
          lv_line    TYPE string,
          lv_tmp     TYPE xstring,
          lv_xstring TYPE xstring,
          lv_string  TYPE string,
          lv_buffer  TYPE string,
          lv_branch  TYPE t_sha1.


    IF NOT is_repo-url CP '*Foobar*'.
      _raise 'not Foobar repository, temporary guard'.
    ENDIF.

    ref_discovery(
      EXPORTING
        is_repo    = is_repo
        iv_service = lc_service
      IMPORTING
        ei_client  = li_client
        ev_branch  = lv_branch ).
* todo, lv_branch should also be importing parameter?

    set_headers(
      EXPORTING
        is_repo    = is_repo
        iv_service = lc_service
        ii_client  = li_client ).

    lv_line = lv_branch &&
              ` ` &&
              iv_commit &&
              ` ` &&
              is_repo-branch_name &&
              get_null( ) &&
              ` ` &&
              'report-status' &&
              gc_newline.                                   "#EC NOTEXT
    lv_cmd_pkt = pkt_string( lv_line ).

    lv_buffer = lv_cmd_pkt && '0000'.
    lv_tmp = lcl_convert=>string_to_xstring_utf8( lv_buffer ).

    CONCATENATE lv_tmp iv_pack INTO lv_xstring IN BYTE MODE.

    li_client->request->set_data( lv_xstring ).

    li_client->send( ).
    li_client->receive( ).
    check_http_200( li_client ).

    lv_xstring = li_client->response->get_data( ).
    li_client->close( ).

    lv_string = lcl_convert=>xstring_to_string_utf8( lv_xstring ).
    IF NOT lv_string CP '*unpack ok*'.
      _raise 'unpack not ok'.
    ENDIF.

  ENDMETHOD.                    "receive_pack

  METHOD length_utf8_hex.

    DATA: lv_xstring TYPE xstring,
          lv_string  TYPE string,
          lv_char4   TYPE c LENGTH 4,
          lv_x       TYPE x LENGTH 2,
          lo_obj     TYPE REF TO cl_abap_conv_in_ce,
          lv_len     TYPE int4.

* hmm, can this be done easier?

    lv_xstring = iv_data(4).

    lo_obj = cl_abap_conv_in_ce=>create(
        input    = lv_xstring
        encoding = 'UTF-8' ).
    lv_len = xstrlen( lv_xstring ).

    lo_obj->read( EXPORTING n    = lv_len
                  IMPORTING data = lv_string ).

    lv_char4 = lv_string.
    TRANSLATE lv_char4 TO UPPER CASE.
    lv_x = lv_char4.
    rv_len = lv_x.

  ENDMETHOD.                    "length_utf8_hex

  METHOD parse.

    DATA: lv_len      TYPE i,
          lv_contents TYPE xstring,
          lv_pack     TYPE xstring.


    WHILE xstrlen( cv_data ) >= 4.
      lv_len = length_utf8_hex( cv_data ).
      IF lv_len = 0.
        EXIT. " current loop
      ENDIF.

      lv_contents = cv_data(lv_len).
      lv_contents = lv_contents+4.
      IF xstrlen( lv_contents ) > 1 AND lv_contents(1) = '01'. " band 1
        CONCATENATE lv_pack lv_contents+1 INTO lv_pack IN BYTE MODE.
      ENDIF.

      cv_data = cv_data+lv_len.
    ENDWHILE.

    ev_pack = lv_pack.

  ENDMETHOD.                    "parse

  METHOD upload_pack.

    CONSTANTS: lc_service TYPE string VALUE 'upload'.       "#EC NOTEXT

    DATA: li_client      TYPE REF TO if_http_client,
          lv_buffer      TYPE string,
          lv_xstring     TYPE xstring,
          lv_line        TYPE string,
          lv_pkt         TYPE string.


    ref_discovery(
      EXPORTING
        is_repo    = is_repo
        iv_service = lc_service
      IMPORTING
        ei_client  = li_client
        ev_branch  = ev_branch ).

    set_headers(
      EXPORTING
        is_repo    = is_repo
        iv_service = lc_service
        ii_client  = li_client ).

    lv_line = 'want' &&
              ` ` &&
              ev_branch &&
              ` ` &&
              'side-band-64k no-progress'
              && gc_newline.                                "#EC NOTEXT
    lv_pkt = pkt_string( lv_line ).

    lv_buffer = lv_pkt
             && '0000'
             && '0009done' && gc_newline.

    li_client->request->set_cdata( lv_buffer ).
    li_client->send( ).
    li_client->receive( ).
    check_http_200( li_client ).
    lv_xstring = li_client->response->get_data( ).
    li_client->close( ).

    parse( IMPORTING ev_pack = ev_pack
           CHANGING cv_data = lv_xstring ).

  ENDMETHOD.                    "upload_pack

  METHOD pkt_string.

    DATA: lv_x   TYPE x,
          lv_len TYPE i.


    lv_len = strlen( iv_string ).

    IF lv_len >= 255.
      _raise 'PKT, todo'.
    ENDIF.

    lv_x = lv_len + 4.

    rv_pkt = rv_pkt && '00' && lv_x && iv_string.

  ENDMETHOD.                    "pkt

ENDCLASS.                    "lcl_transport IMPLEMENTATION

*----------------------------------------------------------------------*
*       CLASS lcl_porcelain DEFINITION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS lcl_porcelain DEFINITION FINAL.

  PUBLIC SECTION.

    CLASS-METHODS pull IMPORTING is_repo TYPE st_repo
                       EXPORTING et_files TYPE tt_files
                                 et_objects TYPE tt_objects
                                 ev_branch TYPE t_sha1
                       RAISING lcx_exception.

    CLASS-METHODS push IMPORTING is_repo TYPE st_repo
                                 is_comment TYPE st_comment
                                 it_files TYPE tt_files
                       RETURNING value(rv_branch) TYPE t_sha1
                       RAISING lcx_exception.

    CLASS-METHODS add IMPORTING is_repo TYPE st_repo
                                is_comment TYPE st_comment
                                it_files TYPE tt_files
                      RAISING lcx_exception.

  PRIVATE SECTION.
    CLASS-METHODS walk IMPORTING it_objects TYPE tt_objects
                                 iv_sha1 TYPE t_sha1
                                 iv_path TYPE string
                       CHANGING ct_files TYPE tt_files
                       RAISING lcx_exception.

    CLASS-METHODS root_tree IMPORTING it_objects TYPE tt_objects
                                      iv_branch TYPE t_sha1
                            RETURNING value(rt_nodes) TYPE tt_nodes
                            RAISING lcx_exception.

    CLASS-METHODS receive_pack IMPORTING is_comment TYPE st_comment
                                         is_repo TYPE st_repo
                                         it_nodes TYPE tt_nodes
                                         it_files TYPE tt_files
                                         iv_branch TYPE t_sha1
                               RETURNING value(rv_branch) TYPE t_sha1
                               RAISING lcx_exception.

ENDCLASS.                    "lcl_porcelain DEFINITION

*----------------------------------------------------------------------*
*       CLASS lcl_porcelain IMPLEMENTATION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS lcl_porcelain IMPLEMENTATION.

  METHOD receive_pack.

    DATA: lv_tree    TYPE xstring,
          lv_time    TYPE t_unixtime,
          lv_commit  TYPE xstring,
          lt_objects TYPE tt_objects,
          lv_pack    TYPE xstring,
          ls_object  LIKE LINE OF lt_objects,
          ls_commit  TYPE st_commit.

    FIELD-SYMBOLS: <ls_file> LIKE LINE OF it_files.


    lv_tree = lcl_pack=>encode_tree( it_nodes ).

* new commit
    lv_time = lcl_time=>get( ).
    ls_commit-tree      = lcl_hash=>sha1( iv_type = gc_tree iv_data = lv_tree ).
    ls_commit-parent    = iv_branch.
    CONCATENATE is_comment-username space '<' is_comment-email '>' space lv_time
      INTO ls_commit-author RESPECTING BLANKS.
    ls_commit-committer = ls_commit-author.
    ls_commit-body      = is_comment-comment.
    lv_commit = lcl_pack=>encode_commit( ls_commit ).


    CLEAR ls_object.
    ls_object-sha1 = lcl_hash=>sha1( iv_type = gc_commit iv_data = lv_commit ).
    ls_object-type = gc_commit.
    ls_object-data = lv_commit.
    APPEND ls_object TO lt_objects.
    CLEAR ls_object.
    ls_object-sha1 = lcl_hash=>sha1( iv_type = gc_tree iv_data = lv_tree ).
    ls_object-type = gc_tree.
    ls_object-data = lv_tree.
    APPEND ls_object TO lt_objects.
    LOOP AT it_files ASSIGNING <ls_file>.
      CLEAR ls_object.
      ls_object-sha1 = lcl_hash=>sha1( iv_type = gc_blob iv_data = <ls_file>-data ).
      ls_object-type = gc_blob.
      ls_object-data = <ls_file>-data.
      APPEND ls_object TO lt_objects.
    ENDLOOP.

    lv_pack = lcl_pack=>encode( lt_objects ).

    rv_branch = lcl_hash=>sha1( iv_type = gc_commit iv_data = lv_commit ).
    lcl_transport=>receive_pack( is_repo   = is_repo
                                 iv_commit = rv_branch
                                 iv_pack   = lv_pack ).

  ENDMETHOD.                    "receive_pack

  METHOD push.

* todo, only works with root files

    DATA: lt_objects TYPE tt_objects,
          lt_nodes   TYPE tt_nodes,
          lv_branch  TYPE t_sha1.

    FIELD-SYMBOLS: <ls_file> LIKE LINE OF it_files,
                   <ls_node> LIKE LINE OF lt_nodes.


    lcl_porcelain=>pull( EXPORTING is_repo    = is_repo
                         IMPORTING et_objects = lt_objects
                                   ev_branch  = lv_branch ).

    lt_nodes = root_tree( it_objects = lt_objects
                          iv_branch  = lv_branch ).

    LOOP AT it_files ASSIGNING <ls_file>.
      READ TABLE lt_nodes ASSIGNING <ls_node> WITH KEY name = <ls_file>-filename.
      IF sy-subrc <> 0.
        _raise 'node not found'.
      ENDIF.

      <ls_node>-sha1 = lcl_hash=>sha1( iv_type = gc_blob iv_data = <ls_file>-data ).
    ENDLOOP.

    rv_branch = receive_pack( is_comment = is_comment
                              is_repo    = is_repo
                              it_nodes   = lt_nodes
                              it_files   = it_files
                              iv_branch  = lv_branch ).

  ENDMETHOD.                    "push

  METHOD root_tree.

    DATA: ls_object LIKE LINE OF it_objects,
          ls_commit TYPE st_commit.


    READ TABLE it_objects INTO ls_object WITH KEY sha1 = iv_branch type = gc_commit.
    IF sy-subrc <> 0.
      _raise 'commit not found'.
    ENDIF.
    ls_commit = lcl_pack=>decode_commit( ls_object-data ).

    READ TABLE it_objects INTO ls_object WITH KEY sha1 = ls_commit-tree type = gc_tree.
    IF sy-subrc <> 0.
      _raise 'tree not found'.
    ENDIF.
    rt_nodes = lcl_pack=>decode_tree( ls_object-data ).

  ENDMETHOD.                    "root_tree

  METHOD add.

* todo, works with root files

    DATA: lt_files   TYPE tt_files,
          lt_objects TYPE tt_objects,
          lt_nodes   TYPE tt_nodes,
          lv_branch  TYPE t_sha1.

    FIELD-SYMBOLS: <ls_file> TYPE st_file,
                   <ls_node> LIKE LINE OF lt_nodes.


* first check if files already exist in repository
    lcl_porcelain=>pull( EXPORTING is_repo    = is_repo
                         IMPORTING et_files   = lt_files
                                   et_objects = lt_objects
                                   ev_branch  = lv_branch ).

    LOOP AT it_files ASSIGNING <ls_file>.
      READ TABLE lt_files WITH KEY path = <ls_file>-path filename = <ls_file>-filename
        TRANSPORTING NO FIELDS.
      IF sy-subrc = 0.
        _raise 'already in repository'.
      ENDIF.
    ENDLOOP.

    lt_nodes = root_tree( it_objects = lt_objects
                          iv_branch  = lv_branch ).

    LOOP AT it_files ASSIGNING <ls_file>.
      APPEND INITIAL LINE TO lt_nodes ASSIGNING <ls_node>.
      <ls_node>-chmod = gc_chmod_file.
      <ls_node>-name = <ls_file>-filename.
      <ls_node>-sha1 = lcl_hash=>sha1( iv_type = gc_blob iv_data = <ls_file>-data ).
    ENDLOOP.

    receive_pack( is_comment = is_comment
                  is_repo    = is_repo
                  it_nodes   = lt_nodes
                  it_files   = it_files
                  iv_branch  = lv_branch ).

  ENDMETHOD.                    "add

  METHOD pull.

    DATA: ls_object  LIKE LINE OF et_objects,
          ls_commit  TYPE st_commit,
          lv_pack    TYPE xstring.


    lcl_transport=>upload_pack( EXPORTING is_repo = is_repo
                                IMPORTING ev_pack = lv_pack
                                          ev_branch = ev_branch ).

    IF lv_pack IS INITIAL.
      _raise 'empty pack'.
    ENDIF.

    et_objects = lcl_pack=>decode( lv_pack ).
    lcl_pack=>decode_deltas( CHANGING ct_objects = et_objects ).

    READ TABLE et_objects INTO ls_object WITH KEY sha1 = ev_branch type = gc_commit.
    IF sy-subrc <> 0.
      _raise 'Commit/branch not found'.
    ENDIF.
    ls_commit = lcl_pack=>decode_commit( ls_object-data ).

    walk( EXPORTING it_objects = et_objects
                    iv_sha1 = ls_commit-tree
                    iv_path = '/'
          CHANGING ct_files = et_files ).

  ENDMETHOD.                    "pull

  METHOD walk.

    DATA: lv_path   TYPE string,
          ls_file   LIKE LINE OF ct_files,
          lt_nodes  TYPE tt_nodes.

    FIELD-SYMBOLS: <ls_tree> LIKE LINE OF it_objects,
                   <ls_blob> LIKE LINE OF it_objects,
                   <ls_node> LIKE LINE OF lt_nodes.


    READ TABLE it_objects ASSIGNING <ls_tree> WITH KEY sha1 = iv_sha1 type = gc_tree.
    IF sy-subrc <> 0.
      _raise 'Walk, tree not found'.
    ENDIF.

    lt_nodes = lcl_pack=>decode_tree( <ls_tree>-data ).

    LOOP AT lt_nodes ASSIGNING <ls_node>.
      IF <ls_node>-chmod = gc_chmod_file.
        READ TABLE it_objects ASSIGNING <ls_blob> WITH KEY sha1 = <ls_node>-sha1 type = gc_blob.
        IF sy-subrc <> 0.
          _raise 'Walk, blob not found'.
        ENDIF.

        CLEAR ls_file.
        ls_file-path     = iv_path.
        ls_file-filename = <ls_node>-name.
        ls_file-data     = <ls_blob>-data.
        APPEND ls_file TO ct_files.
      ENDIF.
    ENDLOOP.

    LOOP AT lt_nodes ASSIGNING <ls_node> WHERE chmod = gc_chmod_dir.
      CONCATENATE iv_path <ls_node>-name '/' INTO lv_path.
      walk( EXPORTING it_objects = it_objects
                      iv_sha1 = <ls_node>-sha1
                      iv_path = lv_path
            CHANGING ct_files = ct_files ).
    ENDLOOP.

  ENDMETHOD.                    "walk

ENDCLASS.                    "lcl_porcelain IMPLEMENTATION

*----------------------------------------------------------------------*
*       CLASS lcl_view DEFINITION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS lcl_gui DEFINITION FINAL.

  PUBLIC SECTION.
    CLASS-METHODS: run RAISING lcx_exception.

    CLASS-METHODS: on_sapevent
                      FOR EVENT sapevent OF cl_gui_html_viewer
                      IMPORTING action frame getdata postdata query_table. "#EC NEEDED

  PRIVATE SECTION.
    CLASS-DATA go_html_viewer TYPE REF TO cl_gui_html_viewer.

    CLASS-METHODS: view
                      IMPORTING iv_html TYPE string.

    CLASS-METHODS: render
                      RETURNING value(rv_html) TYPE string
                      RAISING lcx_exception.

    CLASS-METHODS: render_css
                      RETURNING value(rv_html) TYPE string.

    CLASS-METHODS: render_repo
                      IMPORTING is_repo TYPE st_repo_sha1
                      RETURNING value(rv_html) TYPE string
                      RAISING lcx_exception.

    CLASS-METHODS: install
                      RAISING lcx_exception.

    CLASS-METHODS: add
                      IMPORTING is_repo TYPE st_repo
                      RAISING lcx_exception.

    CLASS-METHODS: pull
                      IMPORTING is_repo TYPE st_repo
                      RAISING lcx_exception.

    CLASS-METHODS: commit
                      IMPORTING is_repo TYPE st_repo
                      RAISING lcx_exception.

    CLASS-METHODS: struct_encode
                      IMPORTING ig_structure TYPE any
                      RETURNING value(rv_string) TYPE string.

    CLASS-METHODS: struct_decode
                      IMPORTING iv_string TYPE clike
                      CHANGING cg_structure TYPE any
                      RAISING lcx_exception.

    CLASS-METHODS: popup_comment
                      RETURNING value(rs_comment) TYPE st_comment
                      RAISING lcx_exception.

ENDCLASS.                    "lcl_gui DEFINITION

*----------------------------------------------------------------------*
*       CLASS lcl_view IMPLEMENTATION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS lcl_gui IMPLEMENTATION.

  METHOD popup_comment.

    DATA: lv_returncode TYPE c,
          lt_fields     TYPE TABLE OF sval.

    FIELD-SYMBOLS: <ls_field> LIKE LINE OF lt_fields.


    APPEND INITIAL LINE TO lt_fields ASSIGNING <ls_field>.
    <ls_field>-tabname = 'BAPIRTEXT'.
    <ls_field>-fieldname = 'TEXT'.
    <ls_field>-fieldtext = 'Username'.                      "#EC NOTEXT
    <ls_field>-field_obl = abap_true.
    <ls_field>-value = lcl_user=>get_username( ).

    APPEND INITIAL LINE TO lt_fields ASSIGNING <ls_field>.
    <ls_field>-tabname = 'BAPIRTEXT1'.
    <ls_field>-fieldname = 'TEXT'.
    <ls_field>-fieldtext = 'E-Mail'.                        "#EC NOTEXT
    <ls_field>-field_obl = abap_true.
    <ls_field>-value = lcl_user=>get_email( ).

    APPEND INITIAL LINE TO lt_fields ASSIGNING <ls_field>.
    <ls_field>-tabname = 'ABAPTXT255'.
    <ls_field>-fieldname = 'LINE'.
    <ls_field>-fieldtext = 'Comment'.                       "#EC NOTEXT
    <ls_field>-field_obl = abap_true.

    CALL FUNCTION 'POPUP_GET_VALUES'
      EXPORTING
        no_value_check  = abap_true
        popup_title     = 'Enter Git username and email'    "#EC NOTEXT
      IMPORTING
        returncode      = lv_returncode
      TABLES
        fields          = lt_fields
      EXCEPTIONS
        error_in_fields = 1
        OTHERS          = 2.
    IF sy-subrc <> 0.
      _raise 'Error from POPUP_GET_VALUES'.
    ENDIF.
    IF lv_returncode = 'A'.
      CLEAR rs_comment.
      RETURN.
    ENDIF.

    READ TABLE lt_fields INDEX 1 ASSIGNING <ls_field>.
    ASSERT sy-subrc = 0.
    rs_comment-username = <ls_field>-value.
    lcl_user=>set_username( rs_comment-username ).

    READ TABLE lt_fields INDEX 2 ASSIGNING <ls_field>.
    ASSERT sy-subrc = 0.
    rs_comment-email = <ls_field>-value.
    lcl_user=>set_email( rs_comment-email ).

    READ TABLE lt_fields INDEX 3 ASSIGNING <ls_field>.
    ASSERT sy-subrc = 0.
    rs_comment-comment = <ls_field>-value.

  ENDMETHOD.                    "popup_commit

  METHOD pull.

    DATA: lt_files   TYPE tt_files,
          lv_branch  TYPE t_sha1.


    lcl_porcelain=>pull( EXPORTING is_repo   = is_repo
                         IMPORTING et_files  = lt_files
                                   ev_branch = lv_branch ).

    lcl_serialize=>deserialize( lt_files ).

    lcl_persistence=>update( is_repo   = is_repo
                             iv_branch = lv_branch ).

    view( render( ) ).

  ENDMETHOD.                    "pull

  METHOD commit.

    DATA: lv_branch      TYPE t_sha1,
          lt_results     TYPE tt_results,
          lt_push        TYPE tt_files,
          ls_comment     TYPE st_comment,
          lt_files       TYPE tt_files.

    FIELD-SYMBOLS: <ls_result> LIKE LINE OF lt_results.


    lcl_porcelain=>pull( EXPORTING is_repo   = is_repo
                         IMPORTING et_files  = lt_files ).

    lt_results = lcl_serialize=>status( lt_files ).

    CLEAR lt_files[].
    LOOP AT lt_results ASSIGNING <ls_result> WHERE match = abap_false.
      lt_files = lcl_serialize=>serialize( iv_obj_type = <ls_result>-obj_type
                                           iv_obj_name = <ls_result>-obj_name ).
      APPEND LINES OF lt_files TO lt_push.
    ENDLOOP.

    IF lt_push[] IS INITIAL.
      _raise 'no changes'.
    ENDIF.

    ls_comment = popup_comment( ).
    IF ls_comment IS INITIAL.
      RETURN.
    ENDIF.

    lv_branch = lcl_porcelain=>push(
      is_comment     = ls_comment
      is_repo        = is_repo
      it_files       = lt_push ).

    lcl_persistence=>update( is_repo   = is_repo
                             iv_branch = lv_branch ).

    view( render( ) ).

  ENDMETHOD.                    "commit

  METHOD struct_decode.

    DATA: lt_fields TYPE tihttpnvp,
          lv_string TYPE string.

    FIELD-SYMBOLS: <ls_field> LIKE LINE OF lt_fields,
                   <lg_any>   TYPE any.


    lv_string = iv_string.     " type conversion
    lt_fields = cl_http_utility=>if_http_utility~string_to_fields( lv_string ).

    LOOP AT lt_fields ASSIGNING <ls_field>.
      ASSIGN COMPONENT <ls_field>-name OF STRUCTURE cg_structure TO <lg_any>.
      IF sy-subrc <> 0.
        _raise 'wrong field'.
      ENDIF.

      <lg_any> = <ls_field>-value.
    ENDLOOP.

  ENDMETHOD.                    "struct_decode

  METHOD struct_encode.

    DATA: lt_fields    TYPE tihttpnvp,
          lo_descr_ref TYPE REF TO cl_abap_structdescr,
          ls_field     LIKE LINE OF lt_fields.

    FIELD-SYMBOLS: <ls_comp> TYPE abap_compdescr,
                   <lg_any>  TYPE any.


    lo_descr_ref ?= cl_abap_typedescr=>describe_by_data( ig_structure ).

    LOOP AT lo_descr_ref->components ASSIGNING <ls_comp>.

      ASSIGN COMPONENT <ls_comp>-name OF STRUCTURE ig_structure TO <lg_any>.
      ASSERT sy-subrc = 0.

      ls_field-name = <ls_comp>-name.
      ls_field-value = <lg_any>.
      APPEND ls_field TO lt_fields.
    ENDLOOP.

    rv_string = cl_http_utility=>if_http_utility~fields_to_string( lt_fields ).
  ENDMETHOD.                    "encode_struct

  METHOD on_sapevent.

    DATA: lx_exception TYPE REF TO lcx_exception,
          ls_repo      TYPE st_repo.


    TRY.
        CASE action.
          WHEN 'install'.
            install( ).
          WHEN 'explore'.
            go_html_viewer->show_url( 'http://larshp.github.io/abapGit/explore.html' ).
          WHEN 'abapgithome'.
            cl_gui_frontend_services=>execute(
                 document = 'https://github.com/larshp/abapGit' ).
          WHEN 'add'.
            struct_decode( EXPORTING iv_string = getdata
                           CHANGING cg_structure = ls_repo ).
            add( ls_repo ).
          WHEN 'refresh'.
            view( render( ) ).
          WHEN 'commit'.
            struct_decode( EXPORTING iv_string = getdata
                           CHANGING cg_structure = ls_repo ).
            commit( ls_repo ).
          WHEN 'pull'.
            struct_decode( EXPORTING iv_string = getdata
                           CHANGING cg_structure = ls_repo ).
            pull( ls_repo ).
          WHEN OTHERS.
            _raise 'Unknown action'.
        ENDCASE.
      CATCH lcx_exception INTO lx_exception.
        MESSAGE lx_exception->mv_text TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.

  ENDMETHOD.                    "on_sapevent

  METHOD add.

    DATA: lt_files    TYPE tt_files,
          lv_obj_type TYPE rseuap-obj_type,
          lv_obj_name TYPE rseuap-obj_name,
          ls_comment  TYPE st_comment,
          lv_object   TYPE tadir-object,
          lv_name     TYPE tadir-obj_name.

* todo, by package
* todo, by transport
    CALL FUNCTION 'WB_TREE_OBJECT_CHOICE'
      IMPORTING
        obj_type = lv_obj_type
        obj_name = lv_obj_name.
    IF lv_obj_type IS INITIAL.
      RETURN.
    ENDIF.


    SELECT SINGLE tadir FROM euobjedit INTO lv_object WHERE type = lv_obj_type.
    IF sy-subrc <> 0.
      _raise 'Not found in EUOBJEDIT'.
    ENDIF.

    lv_name = lv_obj_name.
    lt_files = lcl_serialize=>serialize( iv_obj_type = lv_object
                                         iv_obj_name = lv_name ).

    ls_comment = popup_comment( ).
    IF ls_comment IS INITIAL.
      RETURN.
    ENDIF.

    lcl_porcelain=>add( is_comment = ls_comment
                        is_repo    = is_repo
                        it_files   = lt_files ).

    view( render( ) ).

  ENDMETHOD.                    "add

  METHOD install.

    DATA: lv_returncode TYPE c,
          lt_files      TYPE tt_files,
          ls_repo       TYPE st_repo,
          lv_branch     TYPE t_sha1,
          lt_fields     TYPE TABLE OF sval.

    FIELD-SYMBOLS: <ls_field> LIKE LINE OF lt_fields.


    APPEND INITIAL LINE TO lt_fields ASSIGNING <ls_field>.
    <ls_field>-tabname = 'ABAPTXT255'.
    <ls_field>-fieldname = 'LINE'.
    <ls_field>-fieldtext = 'Url'.                           "#EC NOTEXT

    CALL FUNCTION 'POPUP_GET_VALUES'
      EXPORTING
        no_value_check  = abap_true
        popup_title     = 'Clone'                           "#EC NOTEXT
      IMPORTING
        returncode      = lv_returncode
      TABLES
        fields          = lt_fields
      EXCEPTIONS
        error_in_fields = 1
        OTHERS          = 2.
    IF sy-subrc <> 0.
      _raise 'Error from POPUP_GET_VALUES'.
    ENDIF.
    IF lv_returncode = 'A'.
      RETURN.
    ENDIF.

    READ TABLE lt_fields INDEX 1 ASSIGNING <ls_field>.
    ASSERT sy-subrc = 0.

    ls_repo-url = <ls_field>-value.
* todo
    ls_repo-branch_name = 'refs/heads/master'.              "#EC NOTEXT
    lcl_url=>name( ls_repo-url ).         " validate


    lcl_porcelain=>pull( EXPORTING is_repo   = ls_repo
                         IMPORTING et_files  = lt_files
                                   ev_branch = lv_branch ).

    lcl_serialize=>deserialize( lt_files ).

    lcl_persistence=>add( is_repo   = ls_repo
                          iv_branch = lv_branch ).

    view( render( ) ).

  ENDMETHOD.                    "install

  METHOD render_css.

    rv_html = '<style type="text/css">' && gc_newline &&
          'body {'                      && gc_newline &&    "#EC NOTEXT
          '  font-family: verdana;'     && gc_newline &&    "#EC NOTEXT
          '}'                           && gc_newline &&
          'a:link {'                    && gc_newline &&    "#EC NOTEXT
          '  color: blue;'              && gc_newline &&    "#EC NOTEXT
          '}'                           && gc_newline &&
          'a:visited {'                 && gc_newline &&    "#EC NOTEXT
          '  color: blue;'              && gc_newline &&    "#EC NOTEXT
          '}'                           && gc_newline &&
          'a.grey:link {'               && gc_newline &&    "#EC NOTEXT
          '  color: grey;'              && gc_newline &&    "#EC NOTEXT
          '  font-size: smaller;'       && gc_newline &&    "#EC NOTEXT
          '}'                           && gc_newline &&
          'a.grey:visited {'            && gc_newline &&    "#EC NOTEXT
          '  color: grey;'              && gc_newline &&    "#EC NOTEXT
          '  font-size: smaller;'       && gc_newline &&    "#EC NOTEXT
          '}'                           && gc_newline &&
          'h1 {'                        && gc_newline &&    "#EC NOTEXT
          '  display: inline;'          && gc_newline &&    "#EC NOTEXT
          '}'                           && gc_newline &&
          'h2 {'                        && gc_newline &&    "#EC NOTEXT
          '  display: inline;'          && gc_newline &&    "#EC NOTEXT
          '}'                           && gc_newline &&
          'h3 {'                        && gc_newline &&    "#EC NOTEXT
          '  display: inline;'          && gc_newline &&    "#EC NOTEXT
          '  color: grey;'              && gc_newline &&    "#EC NOTEXT
          '  font-weight:normal;'       && gc_newline &&    "#EC NOTEXT
          '  font-size: smaller;'       && gc_newline &&    "#EC NOTEXT
          '}'                           && gc_newline &&
          '</style>'                    && gc_newline.

  ENDMETHOD.                    "render_css

  METHOD render.

    DATA: lt_repos TYPE tt_repos_sha1,
          ls_repo  LIKE LINE OF lt_repos.


    lt_repos = lcl_persistence=>list( ).

    rv_html = '<html>'                                                      && gc_newline &&
      '<head>'                                                              && gc_newline &&
      '<title>abapGit</title>'                                              && gc_newline &&
      render_css( )                                                         && gc_newline &&
      '<meta http-equiv="content-type" content="text/html; charset=utf-8">' && gc_newline &&
      '</head>'                                                             && gc_newline &&
      '<body>'                                                              && gc_newline &&
      '<h1>abapGit</h1>&nbsp;'                                              && gc_newline &&
      '<a href="sapevent:refresh">Refresh</a>&nbsp;'                        && gc_newline &&
      '<a href="sapevent:install">Clone</a>&nbsp;'                          && gc_newline &&
      '<a href="sapevent:explore">Explore</a>&nbsp;'                        && gc_newline &&
      '<a href="sapevent:abapgithome">abapGit@GitHub</a>&nbsp;'             && gc_newline &&
      '<hr>'                                                                && gc_newline.

    LOOP AT lt_repos INTO ls_repo.
      rv_html = rv_html &&
        '<a href="#' && lcl_url=>name( ls_repo-url ) &&'" class="grey">' &&
        lcl_url=>name( ls_repo-url ) &&
        '</a>&nbsp;'.
    ENDLOOP.

    rv_html = rv_html && '<br><br><br>'.

    LOOP AT lt_repos INTO ls_repo.
      rv_html = rv_html && render_repo( ls_repo ).
    ENDLOOP.

    rv_html = rv_html &&
              '<br><br><hr><center><h3>abapGit Version:&nbsp;' &&
              gc_version &&
              '</h3></center>'.

    rv_html = rv_html && '</body></html>'.

  ENDMETHOD.                    "render

  METHOD render_repo.

    DATA: lt_files   TYPE tt_files,
          ls_repo    TYPE st_repo,
          lv_branch  TYPE t_sha1,
          lv_status  TYPE string,
          lt_results TYPE tt_results.

    FIELD-SYMBOLS: <ls_file>   LIKE LINE OF lt_files,
                   <ls_result> LIKE LINE OF lt_results.


    rv_html = rv_html &&
      '<a id="' && lcl_url=>name( is_repo-url ) && '"></a>' &&
      '<h2>' && lcl_url=>name( is_repo-url ) && '</h2>&nbsp;' &&
      '<h3>' && is_repo-url && '</h3>&nbsp;' &&
      '<h3>' && is_repo-branch_name && '</h3>&nbsp;' &&
      '<br>'.

    MOVE-CORRESPONDING is_repo TO ls_repo.
    lcl_porcelain=>pull( EXPORTING is_repo   = ls_repo
                         IMPORTING et_files  = lt_files
                                   ev_branch = lv_branch ).

    rv_html = rv_html && '<table border="1">' && gc_newline.
    LOOP AT lt_files ASSIGNING <ls_file>.
      rv_html = rv_html &&
        '<tr>' && gc_newline &&
        '<td>' && <ls_file>-path && '</td>' && gc_newline &&
        '<td>' && <ls_file>-filename && '</td>' && gc_newline &&
        '</tr>' && gc_newline.
    ENDLOOP.
    rv_html = rv_html && '</table>' && gc_newline.

    rv_html = rv_html && '<br>'.

    lt_results = lcl_serialize=>status( lt_files ).
    IF lv_branch <> is_repo-sha1.
      lv_status = 'pull'.                                   "#EC NOTEXT
    ELSE.
      READ TABLE lt_results WITH KEY match = abap_false TRANSPORTING NO FIELDS.
      IF sy-subrc = 0.
        lv_status = 'commit'.                               "#EC NOTEXT
      ELSE.
        lv_status = 'match'.                                "#EC NOTEXT
      ENDIF.
    ENDIF.

    LOOP AT lt_results ASSIGNING <ls_result>.
      rv_html = rv_html &&
        <ls_result>-obj_type &&
        '&nbsp;' &&
        <ls_result>-obj_name &&
        '<br>'.
    ENDLOOP.

    CASE lv_status.
      WHEN 'match'.
        rv_html = rv_html && '<a href="sapevent:add?' && struct_encode( ls_repo ) && '">add</a>'.
      WHEN 'commit'.
        rv_html = rv_html && '<a href="sapevent:commit?' && struct_encode( ls_repo ) && '">commit</a>'.
      WHEN 'pull'.
        rv_html = rv_html && '<a href="sapevent:pull?' && struct_encode( ls_repo ) && '">pull</a>'.
      WHEN OTHERS.
        _raise 'status unknown'.
    ENDCASE.

  ENDMETHOD.                    "render_repo

  METHOD run.

    DATA: lt_events TYPE cntl_simple_events,
          ls_event  LIKE LINE OF lt_events.


    CREATE OBJECT go_html_viewer
      EXPORTING
        parent = cl_gui_container=>screen0.

    CLEAR ls_event.
    ls_event-eventid = go_html_viewer->m_id_sapevent.
    ls_event-appl_event = 'x'.
    APPEND ls_event TO lt_events.
    go_html_viewer->set_registered_events( lt_events ).

    SET HANDLER lcl_gui=>on_sapevent FOR go_html_viewer.

    view( render( ) ).

  ENDMETHOD.                    "init

  METHOD view.

    DATA: lt_data TYPE TABLE OF text200,
          lv_html TYPE string,
          lv_url  TYPE text200.


    lv_html = iv_html.

    WHILE strlen( lv_html ) > 0.
      IF strlen( lv_html ) < 200.
        APPEND lv_html TO lt_data.
        CLEAR lv_html.
      ELSE.
        APPEND lv_html(200) TO lt_data.
        lv_html = lv_html+200.
      ENDIF.
    ENDWHILE.

    go_html_viewer->load_data(
      IMPORTING
        assigned_url = lv_url
      CHANGING
        data_table   = lt_data ).

    go_html_viewer->show_url( lv_url ).

  ENDMETHOD.                    "view

ENDCLASS.                    "lcl_gui IMPLEMENTATION

*&---------------------------------------------------------------------*
*&      Form  run
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM run.

  DATA: lx_exception TYPE REF TO lcx_exception.


  TRY.
      lcl_gui=>run( ).
    CATCH lcx_exception INTO lx_exception.
      MESSAGE lx_exception->mv_text TYPE 'E'.
  ENDTRY.

  WRITE: / '.'.     " required

ENDFORM.                    "run

*----------------------------------------------------------------------*
*       CLASS test DEFINITION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS lcl_abap_unit DEFINITION FOR TESTING RISK LEVEL HARMLESS DURATION SHORT FINAL.

  PRIVATE SECTION.
    METHODS repository_foobar FOR TESTING RAISING lcx_exception.
    METHODS repository_mousechase FOR TESTING RAISING lcx_exception.
    METHODS repository_dicing FOR TESTING RAISING lcx_exception.

    METHODS encode_decode_tree FOR TESTING RAISING lcx_exception.
    METHODS encode_decode_commit FOR TESTING RAISING lcx_exception.
    METHODS encode_decode_pack_short FOR TESTING RAISING lcx_exception.
    METHODS encode_decode_pack_long FOR TESTING RAISING lcx_exception.
    METHODS encode_decode_pack_multiple FOR TESTING RAISING lcx_exception.

    METHODS convert_int FOR TESTING RAISING lcx_exception.

    METHODS repo_url FOR TESTING RAISING lcx_exception.
    METHODS repo_error FOR TESTING.

    CLASS-METHODS compare IMPORTING is_repo TYPE st_repo
                          RAISING lcx_exception.
    CLASS-METHODS http_fetch IMPORTING iv_url TYPE string
                             RETURNING value(rv_data) TYPE xstring.

ENDCLASS.                    "test DEFINITION
*----------------------------------------------------------------------*
*       CLASS test IMPLEMENTATION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS lcl_abap_unit IMPLEMENTATION.

  METHOD repo_error.

    TRY.
        lcl_url=>host( 'not a real url' ).                  "#EC NOTEXT
        cl_abap_unit_assert=>fail( ).
      CATCH lcx_exception.                              "#EC NO_HANDLER
    ENDTRY.

  ENDMETHOD.                    "repo_error

  METHOD repo_url.

    DATA: lv_host TYPE string.

    lv_host = lcl_url=>host( 'https://github.com/larshp/Foobar.git' ).

    cl_abap_unit_assert=>assert_equals(
        exp = 'https://github.com'
        act = lv_host ).

  ENDMETHOD.                    "repo_url

  METHOD convert_int.

    DATA: lv_xstring TYPE xstring,
          lv_input   TYPE i,
          lv_result  TYPE i.


    DO 1000 TIMES.
      lv_input = sy-index.
      lv_xstring = lcl_convert=>int_to_xstring( iv_i      = lv_input
                                                iv_length = 4 ).
      lv_result = lcl_convert=>xstring_to_int( lv_xstring ).

      cl_abap_unit_assert=>assert_equals(
          exp = lv_input
          act = lv_result ).
    ENDDO.

  ENDMETHOD.                    "convert_int

  METHOD encode_decode_pack_multiple.

    DATA: lt_objects TYPE tt_objects,
          ls_object  LIKE LINE OF lt_objects,
          lt_nodes   TYPE tt_nodes,
          ls_node    LIKE LINE OF lt_nodes,
          ls_commit  TYPE st_commit,
          lt_result  TYPE tt_objects,
          lv_data    TYPE xstring.


* blob
    lv_data = '123456789ABCDEF545794254754554'.
    CLEAR ls_object.
    ls_object-sha1 = lcl_hash=>sha1( iv_type = gc_blob iv_data = lv_data ).
    ls_object-type = gc_blob.
    ls_object-data = lv_data.
    APPEND ls_object TO lt_objects.

* commit
    CLEAR ls_commit.
    ls_commit-tree      = '5F46CB3C4B7F0B3600B64F744CDE614A283A88DC'.
    ls_commit-parent    = '5F46CB3C4B7F0B3600B64F744CDE614A283A88DC'.
    ls_commit-author    = 'John Foobar'.
    ls_commit-committer = 'John Foobar'.
    ls_commit-body      = 'body'.
    lv_data = lcl_pack=>encode_commit( ls_commit ).
    CLEAR ls_object.
    ls_object-sha1 = lcl_hash=>sha1( iv_type = gc_commit iv_data = lv_data ).
    ls_object-type = gc_commit.
    ls_object-data = lv_data.
    APPEND ls_object TO lt_objects.

* tree
    CLEAR ls_node.
    ls_node-chmod     = '12456'.
    ls_node-name      = 'foobar.abap'.
    ls_node-sha1      = '5F46CB3C4B7F0B3600B64F744CDE614A283A88DC'.
    APPEND ls_node TO lt_nodes.
    lv_data = lcl_pack=>encode_tree( lt_nodes ).
    CLEAR ls_object.
    ls_object-sha1 = lcl_hash=>sha1( iv_type = gc_tree iv_data = lv_data ).
    ls_object-type = gc_tree.
    ls_object-data = lv_data.
    APPEND ls_object TO lt_objects.


    CLEAR lv_data.
    lv_data = lcl_pack=>encode( lt_objects ).
    lt_result = lcl_pack=>decode( lv_data ).

    cl_abap_unit_assert=>assert_equals(
        exp = lt_objects
        act = lt_result ).

  ENDMETHOD.                    "encode_decode_pack_multiple

  METHOD encode_decode_pack_short.

    DATA: lt_objects TYPE tt_objects,
          ls_object  LIKE LINE OF lt_objects,
          lt_result  TYPE tt_objects,
          lv_data    TYPE xstring.


    lv_data = '0123456789ABCDEF'.

    CLEAR ls_object.
    ls_object-sha1 = lcl_hash=>sha1( iv_type = gc_blob
                                     iv_data = lv_data ).
    ls_object-type = gc_blob.
    ls_object-data = lv_data.
    APPEND ls_object TO lt_objects.

    CLEAR lv_data.
    lv_data = lcl_pack=>encode( lt_objects ).
    lt_result = lcl_pack=>decode( lv_data ).

    cl_abap_unit_assert=>assert_equals(
        exp = lt_objects
        act = lt_result ).

  ENDMETHOD.                    "encode_decode_pack

  METHOD encode_decode_pack_long.

    DATA: lt_objects TYPE tt_objects,
          ls_object  LIKE LINE OF lt_objects,
          lv_xstring TYPE xstring,
          lt_result  TYPE tt_objects,
          lv_data    TYPE xstring.


    lv_xstring = '0123456789ABCDEF'.
    DO 20 TIMES.
      CONCATENATE lv_xstring lv_data INTO lv_data IN BYTE MODE.
    ENDDO.

    CLEAR ls_object.
    ls_object-sha1 = lcl_hash=>sha1( iv_type = gc_blob
                                     iv_data = lv_data ).
    ls_object-type = gc_blob.
    ls_object-data = lv_data.
    APPEND ls_object TO lt_objects.

    CLEAR lv_data.
    lv_data = lcl_pack=>encode( lt_objects ).
    lt_result = lcl_pack=>decode( lv_data ).

    cl_abap_unit_assert=>assert_equals(
        exp = lt_objects
        act = lt_result ).

  ENDMETHOD.                    "encode_decode_pack_long

  METHOD encode_decode_tree.

    DATA: lt_nodes  TYPE tt_nodes,
          ls_node   LIKE LINE OF lt_nodes,
          lv_data   TYPE xstring,
          lt_result TYPE tt_nodes.

    CLEAR ls_node.
    ls_node-chmod = gc_chmod_file.
    ls_node-name = 'foobar.txt'.
    ls_node-sha1 = '5F46CB3C4B7F0B3600B64F744CDE614A283A88DC'.
    APPEND ls_node TO lt_nodes.

    lv_data = lcl_pack=>encode_tree( lt_nodes ).
    lt_result = lcl_pack=>decode_tree( lv_data ).

    cl_abap_unit_assert=>assert_equals(
        exp = lt_nodes
        act = lt_result ).

  ENDMETHOD.                    "tree_encode_decode

  METHOD encode_decode_commit.

    DATA: ls_commit TYPE st_commit,
          ls_result TYPE st_commit,
          lv_data   TYPE xstring.


    ls_commit-tree      = '44CDE614A283A88DC5F46CB3C4B7F0B3600B64F7'.
    ls_commit-parent    = '83A88DC5F46CB3C4B7F0B3600B64F744CDE614A2'.
    ls_commit-author    = 'larshp <larshp@hotmail.com> 1387823471 +0100'.
    ls_commit-committer = 'larshp <larshp@hotmail.com> 1387823471 +0100'.
    ls_commit-body      = 'very informative'.

    lv_data = lcl_pack=>encode_commit( ls_commit ).
    ls_result = lcl_pack=>decode_commit( lv_data ).

    cl_abap_unit_assert=>assert_equals(
        exp = ls_commit
        act = ls_result ).

  ENDMETHOD.                    "commit_encode_decode

  METHOD http_fetch.

    DATA: li_client TYPE REF TO if_http_client,
          lv_code   TYPE i.

    cl_http_client=>create_by_url(
      EXPORTING
        url    = iv_url
      IMPORTING
        client = li_client ).

    li_client->send( ).
    li_client->receive( ).
    li_client->response->get_status(
      IMPORTING
        code   = lv_code ).

    cl_abap_unit_assert=>assert_equals(
        exp = 200
        act = lv_code ).

    rv_data = li_client->response->get_data( ).

  ENDMETHOD.                    "http_fetch

  METHOD compare.

    DATA: lv_url    TYPE string,
          lv_data   TYPE xstring,
          lt_files TYPE tt_files.

    FIELD-SYMBOLS: <ls_file> LIKE LINE OF lt_files.


    lcl_porcelain=>pull( EXPORTING is_repo  = is_repo
                         IMPORTING et_files = lt_files ).

    cl_abap_unit_assert=>assert_not_initial( lt_files ).

    LOOP AT lt_files ASSIGNING <ls_file>.
      lv_url =
        'https://raw.githubusercontent.com' &&
        lcl_url=>path_name( is_repo-url ) &&
        '/master' &&
        <ls_file>-path &&
        <ls_file>-filename.                                 "#EC NOTEXT

      lv_data = http_fetch( lv_url ).

      cl_abap_unit_assert=>assert_equals(
          exp = <ls_file>-data
          act = lv_data ).
    ENDLOOP.

  ENDMETHOD.                    "compare

  METHOD repository_foobar.

    DATA: ls_repo TYPE st_repo.

    ls_repo-url = 'https://github.com/larshp/Foobar.git'.   "#EC NOTEXT
    ls_repo-branch_name = 'refs/heads/master'.              "#EC NOTEXT

    compare( ls_repo ).

  ENDMETHOD.                    "test_minus_ten_percent

  METHOD repository_mousechase.

    DATA: ls_repo TYPE st_repo.

    ls_repo-url = 'https://github.com/larshp/MouseChase.git'. "#EC NOTEXT
    ls_repo-branch_name = 'refs/heads/master'.              "#EC NOTEXT

    compare( ls_repo ).

  ENDMETHOD.                    "larshp_mousechase

  METHOD repository_dicing.

    DATA: ls_repo TYPE st_repo.

    ls_repo-url = 'https://github.com/larshp/Dicing.git'.   "#EC NOTEXT
    ls_repo-branch_name = 'refs/heads/master'.              "#EC NOTEXT

    compare( ls_repo ).

  ENDMETHOD.                    "larshp_dicing

ENDCLASS.                    "lcl_abap_unit IMPLEMENTATION