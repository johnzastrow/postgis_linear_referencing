-- CLEANUP: 
-- 1. simplify names even more for demo
-- 2. final version with month_year in output names
-- 3. Add prep steps like turn trails line into 3D/4D

METHODS and REFERENCE:
-- https://gis.stackexchange.com/questions/112282/splitting-lines-into-non-overlapping-subsets-based-on-points-using-postgis
-- https://gis.stackexchange.com/questions/332213/splitting-lines-with-points-using-postgis?utm_source=pocket_mylist


-- INPUTS:
-- 

-- PROCESS:
-- Step 1. Create events table as the first output from the primary input which is the observations table. 
-- The other input is line layer (here trails) and here the layer is 
-- of type LINESTRINGMZ, not MULTILINESTRING.

-- All the SQL below is in aid of creating the new event table
DROP TABLE IF EXISTS greatpond.events2;
CREATE TABLE greatpond.events2 AS
-- We first need to get a candidate set of maybe-closest
-- trails, ordered by id and distance. In this example the trails layer 
-- is line layer of the trail, and observations are points of recorded single 
-- observations along the trail lines.
-- We are going to keep osm_id as the primary id for the trails. 
WITH ordered_nearest AS (
SELECT
  ST_GeometryN(greatpond.trails.geom,1) AS trails_geom, -- Reads in geom. Return the 1-based Nth element geometry of an input geometry.
  greatpond.trails.fid AS trails_fid,
  greatpond.trails.osm_id AS trails_osm_id,
  ST_LENGTH(greatpond.trails.geom) AS trail_length_m ,
  greatpond.obs.geom AS obs_geom,
  greatpond.obs.size_m AS obs_size_m,
  greatpond.obs.id_0 AS obs_id_0,
  ST_Distance(greatpond.trails.geom, greatpond.obs.geom) AS dist_to_trail_m
FROM greatpond.trails
  JOIN greatpond.obs
  ON ST_DWithin(greatpond.trails.geom, greatpond.obs.geom, 200) -- Returns true if the geometries are within a given distance, in this case 200m
ORDER BY obs_id_0, dist_to_trail_m ASC
)
-- We use the 'distinct on' PostgreSQL feature to get the first
-- trail (the nearest) for each unique trail fid. We can then
-- pass that one trail into ST_LineLocatePoint along with
-- its candidate observation to calculate the measure along the trail.
SELECT
  DISTINCT ON (obs_id_0)
  obs_id_0,
  trails_fid,
  trails_osm_id,
  trail_length_m,
  obs_size_m,
  ST_LineLocatePoint(trails_geom, obs_geom) AS measure,
  ST_LineLocatePoint(trails_geom, obs_geom) * trail_length_m AS meas_length,
  dist_to_trail_m
FROM ordered_nearest;

-- Step 1a. Update the table with some more value
-- Primary keys are useful for visualization softwares
ALTER TABLE greatpond.events2 ADD PRIMARY KEY (obs_id_0);
ALTER TABLE greatpond.events2 
	ADD column meas_per_m numeric, 
	ADD column lower_m numeric, 
	ADD column upper_m numeric, 
	ADD column lower_meas numeric, 
	ADD column upper_meas numeric
 ;

update greatpond.events2 SET
	meas_per_m = measure / meas_length,
	lower_m = meas_length - (obs_size_m/2),
	upper_m = meas_length + (obs_size_m/2),
	lower_meas = meas_per_m * lower_m,
	upper_meas = meas_per_m * upper_m -- this field did not update the first time...
;

-- Step 2. Create events layer with point objects
-- New table that turns events into spatial objects, points snapped to the line in this case
DROP TABLE IF EXISTS greatpond.event_points2;
CREATE table greatpond.event_points2 AS
SELECT
  ST_LineInterpolatePoint(ST_GeometryN(greatpond.trails.geom, 1), events2.measure) AS geom,
  obs_id_0,
  trails_fid,
  trails_osm_id,
  trail_length_m,
  measure,
  meas_length,
  obs_size_m,
  dist_to_trail_m,
  meas_per_m,
  lower_m ,
  upper_m,
  lower_meas,
  upper_meas
FROM greatpond.events2
JOIN greatpond.trails
ON (greatpond.trails.fid = greatpond.events2.trails_fid);



--- Create observation event segments based on observed sizes:
DROP TABLE IF EXISTS greatpond.segments;
create table greatpond.segments as (
WITH cuts AS (
    SELECT events2.obs_id_0, events2.trails_fid, events2.lower_meas, events2.upper_meas,	
	ST_GeometryN(trails.geom,1) as geom, trails.osm_id, trails.fid, trails.id 
	from greatpond.trails
	inner join greatpond.events2
	ON trails.fid=events2.trails_fid order by events2.upper_meas 
)
SELECT
	ST_LineSubstring(geom, lower_meas, upper_meas) as mygeom, obs_id_0, trails_fid, lower_meas, upper_meas
FROM 
    cuts);
	
	ALTER TABLE greatpond.segments ADD column id serial; 
	ALTER TABLE greatpond.segments ADD PRIMARY KEY (id);