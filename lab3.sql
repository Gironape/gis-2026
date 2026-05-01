INSTALL spatial;
INSTALL httpfs;

LOAD spatial;
LOAD httpfs;

DROP TABLE IF EXISTS osm_data;
CREATE TABLE osm_data AS
SELECT *
FROM ST_Read('C:\Users\kazak\Desktop\Clons\gis-2026\map.geojson');

DROP TABLE IF EXISTS links;
CREATE TABLE links AS
WITH raw_data AS (
	SELECT *
	FROM 'https://stac.overturemaps.org/2026-04-15.0/buildings/building/collection.json'
),
raw_links AS (
	SELECT unnest(links) AS link
	FROM raw_data
),
links AS (
	SELECT row_number() OVER () id, link.href
	FROM raw_links
	WHERE link.type = 'application/geo+json'
),
raw_bboxes AS (
	SELECT unnest(extent.spatial.bbox) bbox
	FROM raw_data
),
bboxes AS (
	SELECT row_number() OVER () id, bbox[1] xmin, bbox[2] ymin, bbox[3] xmax, bbox[4] ymax
	FROM raw_bboxes 
)
SELECT href, xmin, xmax, ymin, ymax
FROM links
JOIN bboxes ON links.id = bboxes.id;

SELECT DISTINCT links.href AS tile_number
FROM links
JOIN osm_data ON ST_Xmin(geom) BETWEEN links.xmin AND links.xmax 
	AND ST_Ymin(geom) BETWEEN links.ymin AND links.ymax;

DROP TABLE IF EXISTS overture_data;
CREATE TABLE overture_data AS
SELECT *
FROM read_parquet('s3://overturemaps-us-west-2/release/2026-04-15.0/theme=buildings/type=building/part-00444-4ebd20bb-df8b-51bf-bf04-9eca0f9b119c-c000.zstd.parquet')
WHERE ST_XMin(geometry) BETWEEN 50.2339802 AND 50.2654822
  AND ST_YMin(geometry) BETWEEN 53.4304547 AND 53.4466829;

DROP TABLE IF EXISTS overture_with_source;
CREATE TABLE overture_with_source AS
WITH exploded AS (
    SELECT overture.*, unnest(sources) AS source_item
    FROM overture_data overture
)
SELECT *,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM osm_data osm 
            WHERE osm.building IS NOT NULL AND ST_Intersects(osm.geom, ST_SetCRS(geometry, 'EPSG:4326'))
        ) THEN 'my'
        WHEN source_item['dataset'] = 'OpenStreetMap' THEN 'osm'
        WHEN source_item['dataset'] LIKE '%Microsoft%' 
            OR source_item['dataset'] LIKE '%Google%' 
            OR source_item['dataset'] LIKE '%ML%' THEN 'ml'
        ELSE 'other'
    END AS source_type
FROM exploded;

COPY overture_with_source
TO 'C:\Users\kazak\Desktop\Clons\gis-2026\overture_result.geojson'
WITH (FORMAT GDAL, DRIVER 'GeoJSON');