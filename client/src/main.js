import 'ol/ol.css';
import Map from 'ol/Map';
import View from 'ol/View';
import TileLayer from 'ol/layer/Tile';
import OSM from 'ol/source/OSM';
import VectorLayer from 'ol/layer/Vector';
import VectorSource from 'ol/source/Vector';
import GeoJSON from 'ol/format/GeoJSON';
import { fromLonLat } from 'ol/proj';
import { applyStyle } from 'ol-mapbox-style';

const overtureSource = new VectorSource({
  url: '/overture_result.geojson',
  format: new GeoJSON()
});

const overtureLayer = new VectorLayer({
  source: overtureSource,
  declutter: true
});

const map = new Map({
  target: 'map',
  layers: [
    new TileLayer({ source: new OSM() }),
    overtureLayer
  ],
  view: new View({
    center: fromLonLat([50.251, 53.443]),
    zoom: 17
  })
});

overtureSource.on('featuresloadend', function () {
  overtureSource.getFeatures().forEach(f => {
    f.getGeometry().transform('EPSG:4326', 'EPSG:3857');
  });

  fetch('/mapbox-style.json')
    .then(r => r.json())
    .then(style => {
      applyStyle(overtureLayer, style, ['overture-fill', 'overture-outline']);
    });

  map.getView().fit(overtureSource.getExtent(), {
    padding: [100, 100, 100, 100],
    maxZoom: 17,
    duration: 1000
  });
});