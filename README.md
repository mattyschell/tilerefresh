# Tilerefresh

## Description

Given 2 spatial datasets in Oracle (usually old and new), determine differences and return the minimum bounding rectangles 
of changes.  Feed the rectangles to Geowebcache to truncate or reseed tiles.

## Dependencies

* working sqlplus on path
* write access to an oracle spatial schema
* python (2.7)

## Full Setup: Compile and run all unit tests and create empty param tables

(Windows: replace `./gradlew` with `gradlew.bat`)

* `./gradlew runUnitTests createParamTables -Pdb={database} -Pschema={schema} -Ppw={password}`

    * Required 
        * `database` The database
        * `schema` The database schema 
        * `password` The schema password
        * These parameters can also be set in gradle.properties       

Example

* `./gradlew runUnitTests createParamTables -Pdb=GEOCDEV.DOITT.NYCNET -Pschema=MSCHELL -Ppw=iluvdoitt247`

## Refresh Setup: Re-compile and run all unit tests.  Parameter tables exist so don't overwrite them

(Windows: replace `./gradlew` with `gradlew.bat`)

* `./gradlew runUnitTests -Pdb={database} -Pschema={schema} -Ppw={password}`

    * Required 
        * `database` The database name 
        * `schema` The database schema 
        * `password` The schema password
        * These parameters can also be set in gradle.properties       

Example

* `./gradlew runUnitTests -Pdb=GEOCDEV.DOITT.NYCNET -Pschema=BASEMAP -Ppw=iluvdoitt247`

List other available tasks

* `./gradlew tasks --all`

## Set Up Params and Run MBR generator
 
TILEREFRESH_PARAMS Sample Values

PROJECTNAME | LAYER_NAME | TABLE1 | TABLE2 | SYNTHKEY | BUSINESSKEY | SRID | COLS
------------ | ------------- | ------------- | ------------- | ------------- | ------------- | ------------- | ------------- |
 | BASEMAP | CENTERLINE_SDO | CENTERLINE_SDO_1 | CENTERLINE_SDO | objectid | physicalid | 3857 |  STNAME_LABEL,RW_TYPE,TRAFDIR,CARTO_DISPLAY_LEVEL  | `


Run wrapper TILEREFRESH.DUMPCALLS

` CALL tilerefresh.DUMPCALLS('BASEMAP',
                            'CENTERLINE_SDO');`

Results output as 'x1,y1,x2,y2' tilerefresh_seeds.seedcall:

`SELECT seedcall from tilerefresh_seeds where project_name = 'BASEMAP' and layer_name = 'CENTERLINE_SDO';`

The column tilerefresh_seeds.shape is also ogleable in QGIS or ArcMap.

## Call GWC to refresh tiles

refreshtiles.py layername gwcuser gwcpassword gwcspatialreference zoomstart zoomstop imageformat operation boundingboxfile gwcendpoint

example:

` refreshtiles.py basemap admin iluvdoitt247 900913 16 21 truncate jpeg D:\matt_projects_data\mschell_data\tilerefresh\geocdev\basemapbuilding.txt  "http://msslva-ctwgeo01.csc.nycnet:8080/geoserver/gwc/rest/seed/basemap.json" `