CREATE OR REPLACE
TYPE GisLayer FORCE
AUTHID CURRENT_USER
AS OBJECT
(

   --mschell! 20170524

   lname               VARCHAR2(32),
   lsynthkey           VARCHAR2(32),
   lbusinesskey        VARCHAR2(32),
   lshapecol           VARCHAR2(32),
   lcolumns            MDSYS.stringlist,
   ltolerance          NUMBER,

   ----------------------------------------------------------------------------
   ----------------------------------------------------------------------------

   CONSTRUCTOR FUNCTION GisLayer
   RETURN SELF AS RESULT,

   CONSTRUCTOR FUNCTION GisLayer (
      p_lname            IN VARCHAR2,
      p_lsynthkey        IN VARCHAR2,
      p_lbusinesskey     IN VARCHAR2
   ) RETURN SELF AS RESULT,

   ----------------------------------------------------------------------------
   ----------------------------------------------------------------------------

   MEMBER FUNCTION GetLname
   RETURN VARCHAR2,

   MEMBER FUNCTION GetLsynthkey
   RETURN VARCHAR2,

   MEMBER FUNCTION GetLbusinesskey
   RETURN VARCHAR2,

   MEMBER FUNCTION GetLshapecol
   RETURN VARCHAR2,

   MEMBER FUNCTION GetLcolumns(
      p_selectedcols    IN MDSYS.stringlist DEFAULT NULL
   ) RETURN MDSYS.stringlist,

   MEMBER FUNCTION GetLcolumnsstring (
      p_separator       IN VARCHAR2 DEFAULT ','
   ) RETURN VARCHAR2,

   MEMBER FUNCTION GetLtolerance
   RETURN NUMBER,

   MEMBER FUNCTION LDiff (
      p_GisLayer     IN GisLayer,
      p_Lcolumns     IN VARCHAR2 DEFAULT NULL
   ) RETURN MDSYS.stringlist,

   MEMBER FUNCTION LIntersect (
      p_GisLayer     IN GisLayer
   ) RETURN MDSYS.stringlist,

   ----------------------------------------------------------------------------
   ----------------------------------------------------------------------------

   MEMBER PROCEDURE SetLshapecol (
      p_lshapecol        IN VARCHAR2 DEFAULT NULL
   ),

   MEMBER PROCEDURE SetLtolerance (
      p_ltolerance         IN NUMBER DEFAULT NULL
   ),

   MEMBER PROCEDURE SetLcolumns,


   MEMBER FUNCTION Describe (
      p_indent             IN VARCHAR2 DEFAULT NULL
   ) RETURN VARCHAR2,


   MEMBER PROCEDURE Describe (
      p_indent          IN VARCHAR2 DEFAULT NULL
   )

);
/