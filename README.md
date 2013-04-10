postgis2gmap
============

A small collection of PL/PGSQL functions for converting to and from Google's map tile coordinates.

The functions are in postgis2gmap.sql in this folder, and to load them run something like this:

`psql -U postgres -d your_database -f postgis2gmap.sql`

The main functions are:

### tile_indices_for_lonlat(lonlat geography, zoom_level int)

Takes a PostGIS latitude/longitude point and a zoom level, and returns a geometry object where the X component is the longitude index of the tile, and the Y component is the latitude index. These values are *not* rounded, so for a lot of purposes you'll need to FLOOR() them both, eg;

`SELECT                                                                                                                                                                            FLOOR(X(tile_indices_for_lonlat(checkins.lonlat, 4))) AS grid_lon,                                                                                                                                    FLOOR(Y(tile_indices_for_lonlat(checkins.lonlat, 4))) AS grid_lat FROM checkins;`

### lonlat_for_tile_indices(lat_index float8, lon_index float8, zoom_level int)

Does the inverse of the function above, turning a Google Maps tile index for a given zoom level into a PostGIS geometry point. You may notice that the coordinates are given as separate arguments rather than a single geometry object. That's an artifact of how my data is stored. Here's an example:

`SELECT X(lonlat_for_tile_indices(6, 2, 4)::geometry), Y(lonlat_for_tile_indices(6, 2, 4)::geometry);`

### bounds_for_tile_indices(lat_index float8, lon_index float8, zoom_level int)

This takes latitude and longitude coordinates for a tile, and a zoom level, and returns a geography object containing the bounding box for that tile. I mainly use this for limiting queries on geographic data to a particular tile, eg;

`SELECT * FROM checkins WHERE ST_Intersects(lonlat, bounds_for_tile_indices(6, 2, 4);`
