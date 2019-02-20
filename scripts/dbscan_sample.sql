--slipshod attempt in Postgis to reduce overlapping MBRs for tile reseeding 
--Motivation: Parallel reseeding of overlapping MBRs in Geowebcache
--            rarely works for me.  Presumably the tasks bump into each other
--            and either fail or just leave space where the tiles are not reseeded.
--            In constrast, full delta truncate, then full delta seed, 
--            tends to be more reliable.
--            However: For complex tile sets this creates a long time gap
--            when tiles are missing and performance is poor
--            I am pushing toward truncate and reseed in chunks where a given
--            chunk minimally overlaps with previous and future chunks
--Demotivation: With edge caching (Akamai) who cares?
--  alternative 1: cluster the entities before generating MBRs
--  alternative 2: consider percent overlap of MBRs
--  galaxy brain 3: divide large, curvy shapes up into multiple MBRs
--                  so that the most detailed zooms dont incorporate 
--                  dead space  
-- THANKS! NICE TALKING WITH YOU!
--
--requires superuser for COPY
--change COPY 2x and ST_ClusterDBSCAN params
--
--cleanup
DROP TABLE IF EXISTS dbscaninputs; 
DROP TABLE IF EXISTS dbscantester;
DROP TABLE IF EXISTS dbscanaggregator;
DROP TABLE IF EXISTS dbscanoutputs;
--ddl
CREATE TABLE dbscaninputs 
    (llx numeric
    ,lly numeric
    ,urx numeric
    ,ury numeric);
CREATE TABLE dbscantester 
    (id numeric primary key
    ,geom geometry
    ,bucket numeric);
CREATE INDEX dbscantestergeom ON dbscantester USING gist(geom);
CREATE TABLE dbscanaggregator 
    (id numeric primary key
    ,geom geometry
    ,bucket numeric);
CREATE INDEX dbscanaggregatorgeom ON dbscanaggregator USING gist(geom);
CREATE TABLE dbscanoutputs 
    (id serial primary key
    ,geom geometry);
CREATE INDEX dbscanoutputsgeom ON dbscanoutputs USING gist(geom);
--input xys
COPY dbscaninputs FROM 'D:/renamed/to/commaseparated.csv' WITH (FORMAT csv);
ALTER TABLE dbscaninputs ADD COLUMN geom geometry; 
ALTER TABLE dbscaninputs ADD COLUMN id serial primary key; 
--work with centroids since big MBRs tend to cluster outwards unbounded
UPDATE dbscaninputs 
SET geom = ST_SetSRID(ST_Centroid(ST_MakeBox2D(ST_MakePoint(llx,lly), 
                                               ST_MakePoint(urx, ury))
                                 ),
                      3857);
--play with dbscan inputs and ogle results      
--   intuition is that smallish, clustered MBRs (centroid to centroid distance is small)  
--   will require reseeding of the same tiles
--   try to get archipelegos of little MBRs to aggregate without
--   ever catching the big ones  
INSERT INTO dbscantester 
    (id
    ,geom
    ,bucket)    
SELECT id
      ,geom
      ,ST_ClusterDBSCAN(geom,200,4) over () 
FROM dbscaninputs ORDER BY id;
--dump out the ones that we arent touching
INSERT INTO dbscanoutputs (geom)
SELECT ST_SETSRID(ST_MakeBox2D(ST_MakePoint(llx,lly), 
                               ST_MakePoint(urx, ury)),
                  3857)
FROM dbscaninputs 
WHERE id IN (SELECT id 
             FROM dbscantester 
             WHERE bucket IS NULL);
--set up table to aggregate buckets
INSERT INTO dbscanaggregator 
   (id
   ,geom
   ,bucket)
SELECT 
    b.id 
   ,ST_SETSRID(ST_MakeBox2D(ST_MakePoint(b.llx,b.lly), 
                            ST_MakePoint(b.urx, b.ury)
                            ),
               3857)
,a.bucket
FROM 
dbscaninputs b
JOIN
dbscantester a
ON a.id = b.id
WHERE a.bucket IS NOT NULL;
--aggregate MBRs on buckets
INSERT INTO dbscanoutputs (geom)
    SELECT ST_SETSRID(ST_EXTENT(geom),3857)
    FROM dbscanaggregator
    GROUP BY bucket;
COPY (SELECT 
      ST_XMin(geom) || ',' || ST_YMin(geom) || ',' || ST_XMax(geom) || ',' || ST_YMax(geom)
      FROM 
      dbscanoutputs
      ORDER BY ST_XMin(geom), ST_YMin(geom))
TO 'D:/save/to/output.txt';