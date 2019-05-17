CREATE OR REPLACE PACKAGE TILEREFRESH
AUTHID CURRENT_USER
AS

   --mschell! 20170608

   TYPE MBRSDOREC IS RECORD (
      mbr         SDO_GEOMETRY
   );

   TYPE MBRSDOTAB IS TABLE OF MBRSDOREC;

   TYPE stringarray IS TABLE OF VARCHAR2(4000)
   INDEX BY PLS_INTEGER;

   TYPE TRPARAMS_REC IS RECORD(
      project_name         VARCHAR2(32),
      layer_name           VARCHAR2(32),
      table1               VARCHAR2(32),
      table2               VARCHAR2(32),
      synthkey             VARCHAR2(32),
      businesskey          VARCHAR2(32),
      srid                 NUMBER,
      cols                 VARCHAR2(4000)
   );

   TYPE TRSEEDS_REC IS RECORD (
      seedid               INTEGER,
      project_name         VARCHAR2(32),
      layer_name           VARCHAR2(32),
      shape                SDO_GEOMETRY,
      coords               VARCHAR2(4000),
      date_last_modified   DATE
   );

   TYPE TRSEEDS_TAB IS TABLE OF TRSEEDS_REC;

   PROCEDURE CREATE_TRPARAMS (
      p_tabname         IN VARCHAR2 DEFAULT 'TILEREFRESH_PARAMS',
      p_replace         IN VARCHAR2 DEFAULT 'N'
   );

   PROCEDURE CREATE_TRSEEDS (
      p_tabname         IN VARCHAR2 DEFAULT 'TILEREFRESH_SEEDS',
      p_replace         IN VARCHAR2 DEFAULT 'N',
      p_srid            IN NUMBER DEFAULT 3857,
      p_tolerance       IN NUMBER DEFAULT .0001
   );

   PROCEDURE DROP_TRSEEDS (
      p_tabname         IN VARCHAR2 DEFAULT 'TILEREFRESH_SEEDS'
   );

   FUNCTION GET_TRPARAMS (
      p_project_name    IN VARCHAR2,
      p_layer_name      IN VARCHAR2,
      p_tabname         IN VARCHAR2 DEFAULT 'TILEREFRESH_PARAMS'
   ) RETURN TILEREFRESH.TRPARAMS_REC;

    FUNCTION MBRPOINT (
         p_sdo           IN MDSYS.SDO_GEOMETRY
        ,p_bloat         IN NUMBER
    ) RETURN MDSYS.SDO_GEOMETRY;
   
   FUNCTION DUMPDIFFSSDO (
      p_tab1            IN VARCHAR2,
      p_tab2            IN VARCHAR2,
      p_synthkey        IN VARCHAR2,
      p_businesskey     IN VARCHAR2,
      p_srid            IN NUMBER DEFAULT 3857,
      p_tolerance       IN VARCHAR2 DEFAULT .0001,
      p_cols            IN VARCHAR2 DEFAULT NULL
   ) RETURN TILEREFRESH.MBRSDOTAB PIPELINED;

   PROCEDURE DUMPCALLS (
      p_project_name    IN VARCHAR2,
      p_layer_name      IN VARCHAR2,
      p_params          IN VARCHAR2 DEFAULT 'TILEREFRESH_PARAMS',
      p_sequence        IN VARCHAR2 DEFAULT 'TILEREFRESH_SEEDSSEQ',
      p_tolerance       IN NUMBER DEFAULT .0001,
      p_seedtab         IN VARCHAR2 DEFAULT 'TILEREFRESH_SEEDS'
   );

PROCEDURE ADD_SPATIAL_INDEX (
    p_table_name      IN VARCHAR2,
    p_column_name     IN VARCHAR2,
    p_srid            IN NUMBER,
    p_tolerance       IN NUMBER,
    p_local           IN VARCHAR2 DEFAULT NULL,
    p_parallel        IN NUMBER DEFAULT NULL,
    p_idx_name        IN VARCHAR2 DEFAULT NULL,
    p_3d              IN VARCHAR2 DEFAULT 'N',
    p_depth           IN PLS_INTEGER DEFAULT 1
);

PROCEDURE DISSOLVETABLE (
    p_target_table    IN VARCHAR2,
    p_target_clause   IN VARCHAR2 DEFAULT NULL,
    p_target_pkc      IN VARCHAR2 DEFAULT 'OBJECTID',
    p_tolerance       IN NUMBER DEFAULT .0005,
    p_mask            IN VARCHAR2 DEFAULT 'ANYINTERACT'
);



END TILEREFRESH;
/
