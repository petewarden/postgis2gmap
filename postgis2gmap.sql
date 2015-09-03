CREATE OR REPLACE FUNCTION public.latitude_to_mercator_latitude ( float8 )
RETURNS float8 LANGUAGE sql IMMUTABLE STRICT AS $$
  SELECT ((180 / pi()) * ln(tan(pi() / 4 + $1 * (pi()/180)/2)))/2
$$;

CREATE OR REPLACE FUNCTION public.mercator_latitude_to_latitude ( float8 )
RETURNS float8 LANGUAGE sql IMMUTABLE STRICT AS $$
  SELECT (180 / pi()) * (2 * atan(exp(($1 * 2) * pi()/180)) - pi() / 2)
$$;

CREATE OR REPLACE FUNCTION public.tile_indices_for_lonlat(lonlat geography, zoom_level int)
RETURNS geometry LANGUAGE plpgsql IMMUTABLE STRICT AS $$
  DECLARE 
    map_tile_width integer := 256;
    map_tile_height integer := 256;
    map_tile_origin_lat float8 := 85.05112877980659;
    map_tile_origin_lon float8 := -180.0;
    world_lat_height float8 := -170.102258;
    world_lon_width float8 := 360.0;

    mercator_latitude_origin float8;
    mercator_latitude_height float8;
    zoom_tile_count integer;
    zoom_pixels_per_degree_latitude float8;
    zoom_pixels_per_degree_longitude float8;
    tile_width_in_degrees float8;
    tile_height_in_degrees float8;
    lat_index float8;
    lon_index float8;
  BEGIN
    mercator_latitude_origin := latitude_to_mercator_latitude(map_tile_origin_lat);
    mercator_latitude_height := latitude_to_mercator_latitude(world_lat_height + map_tile_origin_lat) - mercator_latitude_origin;
    zoom_tile_count = (1 << zoom_level);
    zoom_pixels_per_degree_latitude := ((map_tile_height / mercator_latitude_height) * zoom_tile_count);
    zoom_pixels_per_degree_longitude := ((map_tile_width / world_lon_width) * zoom_tile_count);
    tile_width_in_degrees := (map_tile_width / zoom_pixels_per_degree_longitude);
    tile_height_in_degrees := (map_tile_height / zoom_pixels_per_degree_latitude);
    lat_index := ((latitude_to_mercator_latitude(ST_Y(lonlat::geometry)) - mercator_latitude_origin) / tile_height_in_degrees);
    lon_index = ((ST_X(lonlat::geometry) - map_tile_origin_lon) / tile_width_in_degrees);
    RETURN ST_MakePoint(lon_index, lat_index);
  END
$$;

CREATE OR REPLACE FUNCTION public.lonlat_for_tile_indices(lat_index float8, lon_index float8, zoom_level int)
RETURNS geography LANGUAGE plpgsql IMMUTABLE STRICT AS $$
  DECLARE 
    map_tile_width integer := 256;
    map_tile_height integer := 256;
    map_tile_origin_lat float8 := 85.05112877980659;
    map_tile_origin_lon float8 := -180.0;
    world_lat_height float8 := -170.102258;
    world_lon_width float8 := 360.0;

    mercator_latitude_origin float8;
    mercator_latitude_height float8;
    zoom_tile_count integer;
    zoom_pixels_per_degree_latitude float8;
    zoom_pixels_per_degree_longitude float8;
    tile_width_in_degrees float8;
    tile_height_in_degrees float8;
    lat float8;
    lon float8;
  BEGIN
    mercator_latitude_origin := latitude_to_mercator_latitude(map_tile_origin_lat);
    mercator_latitude_height := latitude_to_mercator_latitude(world_lat_height + map_tile_origin_lat) - mercator_latitude_origin;
    zoom_tile_count = (1 << zoom_level);
    zoom_pixels_per_degree_latitude := ((map_tile_height / mercator_latitude_height) * zoom_tile_count);
    zoom_pixels_per_degree_longitude := ((map_tile_width / world_lon_width) * zoom_tile_count);
    tile_width_in_degrees := (map_tile_width / zoom_pixels_per_degree_longitude);
    tile_height_in_degrees := (map_tile_height / zoom_pixels_per_degree_latitude);  
    lat := ((lat_index * tile_height_in_degrees) + mercator_latitude_origin);
    lon := ((lon_index * tile_width_in_degrees) + map_tile_origin_lon);
    RETURN ST_SetSRID(ST_MakePoint(lon, mercator_latitude_to_latitude(lat)), 4326);
  END
$$;

CREATE OR REPLACE FUNCTION public.cell_indices_for_tile_indices(tile_indices geometry, cells_across integer, cells_down integer)
RETURNS geometry LANGUAGE plpgsql IMMUTABLE STRICT AS $$
  DECLARE
  BEGIN
    RETURN ST_MakePoint(
      (FLOOR(ST_X(tile_indices) * cells_across) / cells_across),
      (FLOOR(ST_Y(tile_indices) * cells_down) / cells_down));
  END
$$;

CREATE OR REPLACE FUNCTION public.bounds_for_tile_indices(lat_index float8, lon_index float8, zoom_level int)
RETURNS geography LANGUAGE plpgsql IMMUTABLE STRICT AS $$
  DECLARE
  BEGIN
    RETURN ST_SetSRID(ST_MakeBox2D(
      lonlat_for_tile_indices(lat_index, lon_index, zoom_level)::geometry,
      lonlat_for_tile_indices((lat_index + 1), (lon_index + 1), zoom_level)::geometry),
      4326);
  END
$$;

CREATE OR REPLACE FUNCTION public.bounds_for_tile_and_cell_indices(lat_index float8, lon_index float8, zoom_level int, cells_across int, cells_down int)
RETURNS geography LANGUAGE plpgsql IMMUTABLE STRICT AS $$
  DECLARE
    cell_width float8;
    cell_height float8;
    snapped_lat_index float8;
    snapped_lon_index float8;
  BEGIN
    cell_width := (1.0 / cells_across);
    cell_height := (1.0 / cells_down);
    snapped_lat_index := (ROUND(lat_index * cells_down) / cells_down);
    snapped_lon_index := (ROUND(lon_index * cells_across) / cells_across);
    RETURN ST_SetSRID(ST_MakeBox2D(
      lonlat_for_tile_indices(snapped_lat_index, snapped_lon_index, zoom_level)::geometry,
      lonlat_for_tile_indices((snapped_lat_index + cell_width), (snapped_lon_index + cell_height), zoom_level)::geometry),
      4326);
  END
$$;

