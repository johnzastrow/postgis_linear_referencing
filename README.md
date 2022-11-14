# Postgis linear referencing

Example SQL to demonstrate some linear referencing concepts using only PostGIS/Postgres. 

### Explanation of the geometric processing

The process requires two input Postgis layers each containing geometry (POINT and LINE) and a single user-provided attribute on the point layer. Other attributes can be recorded but are optional for geometric processing, The first input is a point layer of observations (perhaps collected by GPS or onscreen digitizing), or events, along linear features (road, stream, sidewalk, trail). The point layer requires a field containing a number that describes the size of the area/object being observed (pothole, stream bank erosion, cracked sidewalk, degraded trail). The size is recorded as a length from the center to the edge of the feature, and assumes the coordinate is the center of the feature. At this time the size units should be in the units of the coordinate reference system (CRS) for the layer. These must be linear distance units, not degrees of latitude/longitude as would be used for unprojected data. The second layer is of linear features -- lines of a trail in this example -- and must be in the same CRS as the point observation layer.

For example, hikers would stand at the center of a section of eroded trail and record the coordinates at the center of the eroded section. The CRS for the project is UTM and the position is recorded in meters. The hikers would record the full size of the problem region, which might be five (5.0) meters in this example.

The process snaps the points to the nearest line (because it's impossible to collect coordinates exactly on a line) at the closest location possible (does not look for a vertex or node) and records the coordinates from that snapped location. 

The output is an intermediate 

Only in PostGIS. Tested in the following environment
 * Ubuntu 22.04
 
 * output from SELECT PostGIS_full_version ();

```
POSTGIS="3.2.1 5fae8e5" [EXTENSION] PGSQL="130" GEOS="3.10.2-CAPI-1.16.0" PROJ="7.2.1" LIBXML="2.9.12" LIBJSON="0.15" LIBPROTOBUF="1.3.3" WAGYU="0.5.0 (Internal)"
```
The goals is to perform all processing, after collection of the initial observation file, in PostGIS alone.

![Observation Points](/static/obs_points.png)
 Observation points would typically be collected by GPS in the field, but could be digitized as shown above.

![Outputs and negative fixes](static/negative_meas_fix.png)
The screen above shows many important elemets. 
