/* -*- coding: utf-8-unix -*-
 *
 * Copyright (C) 2014 Osmo Salomaa
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.0
import QtLocation 5.0
import QtPositioning 5.3
import Sailfish.Silica 1.0
import MapboxMap 1.0
import "."

import "js/util.js" as Util

MapboxMap {
    id: map
    anchors.centerIn: parent
    /* clip: true */
    height: parent.height
    width: parent.width

    center: QtPositioning.coordinate(49,13)
    zoomLevel: 4.0
    minimumZoomLevel: 0
    maximumZoomLevel: 20

    // Theme.pixelRatio is relative to the Jolla 1,
    // which is maybe around 1.5 in terms of map scales.
    pixelRatio: Theme.pixelRatio * 1.5

    // TODO
    accessToken: "pk.eyJ1IjoicmluaWd1cyIsImEiOiJjajdkcHM0MWkwYjE4MzBwZml3OTRqOTc4In0.cjKiY1ZtOyS4KPJF0ewwQQ"
    styleUrl: "mapbox://styles/mapbox/streets-v10"

    // TODO
    cacheDatabaseMaximalSize: 20*1024*1024
    cacheDatabasePath: "/tmp/mbgl-cache.db"
    
    property bool autoCenter: false
    property bool autoRotate: false
    property bool centerFound: true
    property var  direction: app.navigationDirection || gps.direction
    property var  directionPrev: 0
    property bool halfZoom: false
    property bool hasRoute: false
    property real heightCoords: 0
    property var  maneuvers: []
    property var  pois: []
    property var  position: gps.position
    property bool ready: false
    property var  route: {}
    property real scaleX: 0
    property real scaleY: 0

    // layer that is existing in the current style and
    // which can be used to position route and other layers
    // under to avoid covering important map features, such
    // as labels.
    property string styleReferenceLayer: "waterway-label"

    property real widthCoords: 0
    property real zoomLevelPrev: 8

    property var constants: QtObject {

        // Define metrics of the canvas used. Must match what plugin uses.
        // Scale factor is relative to the traditional tile size 256.
        property real canvasTileSize: 512
        property real canvasScaleFactor: 0.5

        // Distance of position center point from screen bottom when
        // navigating and auto-rotate is on, i.e. heading up on screen.
        // This is relative to the total visible map height.
        property real navigationCenterY: 0.22

        // This is the zoom level offset at which @3x, @6x, etc. tiles
        // can be shown pixel for pixel. The exact value is log2(1.5),
        // but QML's JavaScript doesn't have Math.log2.
        property real halfZoom: 0.5849625

        // Mapbox sources, layers, and images
        property string sourcePois: "pm-source-pois"
        property string imagePoi: "pm-image-poi"
        property string layerPois: "pm-layer-pois"

        property string sourceManeuvers: "pm-source-maneuvers"
        property string layerManeuvers: "pm-layer-maneuvers"

        property string sourceRoute: "pm-source-route"
        property string layerRouteCase: "pm-layer-route-case"
        property string layerRoute: "pm-layer-route"
    }

    Behavior on center {
        CoordinateAnimation {
            duration: map.ready ? 500 : 0
            easing.type: Easing.InOutQuad
        }
    }

    Behavior on bearing {
        RotationAnimation {
            direction: RotationAnimation.Shortest
            duration: map.ready ? 500 : 0
            easing.type: Easing.Linear
        }
    }

    Behavior on pitch {
        NumberAnimation { duration: 1000 }
    }

    MapMouseArea {}
    NarrationTimer {}
    PositionMarker { id: positionMarker }
    //Route { id: route }

    Component.onCompleted: {
        map.initLayers();
        map.initProperties();
    }

    onAutoRotateChanged: {
        if (map.autoRotate && map.direction) {
            map.bearing = map.direction;
        } else {
            map.bearing = 0;
        }
    }

    onDirectionChanged: {
        // Update map rotation to match direction.
        var direction = map.direction || 0;
        if (map.autoRotate && Math.abs(direction - directionPrev) > 10) {
            map.bearing = direction;
            map.directionPrev = direction;
        }
    }

    onHasRouteChanged: {
        // Update keep-alive in case set to 'navigating'.
        app.updateKeepAlive();
    }

    onPositionChanged: {
        if (!map.centerFound) {
            // Center on user's position on first start.
            map.centerFound = true;
            map.setZoomLevel(14);
            map.centerOnPosition();
        } else if (map.autoCenter) {
            map.centerOnPosition();
            //            // Center map on position if outside center of screen.
            //            // map.toScreenPosition returns NaN when outside component and
            //            // otherwise actually relative positions inside the map component,
            //            // which can differ from the screen when using auto-rotation.
            //            var pos = map.toScreenPosition(map.position.coordinate);
            //            if (!pos.x || !pos.y)
            //                return map.centerOnPosition();
            //            var height = app.screenHeight - app.navigationBlock.height;
            //            // If the navigation block covers the top part of the screen,
            //            // center the position to the part of the map remaining visible.
            //            var dy = app.navigationBlock.height / 2;
            //            if (map.autoRotate) {
            //                // If auto-rotate is on, the user is always heading up
            //                // on the screen and should see more ahead than behind.
            //                dy += (0.5 - map.constants.navigationCenterY) * height;
            //                // Avoid overlap with the menu button. Note that the position marker
            //                // height includes the arrow, which points up when navigating,
            //                // leaving padding the size of the arrow at the bottom.
            //                dy = Math.min(dy, (app.screenHeight/2 -
            //                                   app.menuButton.height -
            //                                   app.menuButton.anchors.bottomMargin -
            //                                   map.positionMarker.height/2));

            //            }
            //            // https://en.wikipedia.org/wiki/Azimuth#Cartographical_azimuth
            //            var cx = map.width  / 2 + dy * Math.sin(Util.deg2rad(map.rotation));
            //            var cy = map.height / 2 + dy * Math.cos(Util.deg2rad(map.rotation));
            //            var threshold = map.autoRotate ? 0.12 * height :
            //                0.18 * Math.min(app.screenWidth, height);
            //            if (Util.eucd(pos.x, pos.y, cx, cy) > threshold)
            //                map.centerOnPosition();
        }
    }

    function mouseClick(coordinate, degLatPerPixel, degLonPerPixel) {
        // Process mouse clicks by comparing them with the current position,
        // and POIs

        // 15 pixels at 96dpi would correspond to 4 mm
        var nearby_lat = map.pixelRatio * 15 * degLatPerPixel;
        var nearby_lon = map.pixelRatio * 15 * degLonPerPixel;

        // check if its current position
        if ( Math.abs(coordinate.longitude - map.position.coordinate.longitude) < nearby_lon &&
                Math.abs(coordinate.latitude - map.position.coordinate.latitude) < nearby_lat ) {
            positionMarker.mouseClick();
            return;
        }

        for (var i = 0; i < map.pois.length; i++) {
            if ( Math.abs(coordinate.longitude - map.pois[i].coordinate.longitude) < nearby_lon &&
                    Math.abs(coordinate.latitude - map.pois[i].coordinate.latitude) < nearby_lat ) {
                if (!map.pois[i].bubble) {
                    var component = Qt.createComponent("PoiMarker.qml");
                    var poi = map.pois[i];
                    var trackid = "POI bubble: " + String(poi.coordinate);
                    var bubble = component.createObject(map, {
                                                            "coordinate": poi.coordinate,
                                                            "trackerId": trackid,
                                                            "title": poi.title,
                                                            "text": poi.text,
                                                            "link": poi.link
                                                        } );

                    map.trackLocation(trackid, poi.coordinate);
                    map.pois[i].bubble = bubble;
                }
                return;
            }
        }

        // Unknown click - let's close all POI dialogs
        map.hidePoiBubbles();
    }

    function addManeuvers(maneuvers) {
        /*
         * Add new maneuver markers to map.
         *
         * Expected fields for each item in in maneuvers:
         *  - x: Longitude coordinate of maneuver point
         *  - y: Latitude coordinate of maneuver point
         *  - icon: Name of maneuver icon (optional, defaults to "flag")
         *  - narrative: Plain text instruction of maneuver
         *  - passive: true if point doesn't require any actual action
         *    (optional, defaults to false)
         *  - duration: Duration (s) of leg following maneuver point
         */
        for (var i = 0; i < maneuvers.length; i++) {
            var maneuver = {
                "coordinate": QtPositioning.coordinate(maneuvers[i].y, maneuvers[i].x),
                "icon": maneuvers[i].icon || "flag",
                "narrative": maneuvers[i].narrative || "",
                "passive": maneuvers[i].passive || false,
                "duration": maneuvers[i].duration || 0,
                "verbal_alert": maneuvers[i].verbal_alert,
                "verbal_pre": maneuvers[i].verbal_pre,
                "verbal_post": maneuvers[i].verbal_post
            };
            map.maneuvers.push(maneuver);
        }
        py.call("poor.app.narrative.set_maneuvers", [maneuvers], null);
        map.updateMapManeuvers();
        map.saveManeuvers();
    }

    function addPois(pois) {
        /*
         * Add new POI markers to map.
         *
         * Expected fields for each item in pois:
         *  - x: Longitude coordinate of point
         *  - y: Latitude coordinate of point
         *  - title: Plain text name by which to refer to point
         *  - text: Text.RichText to show in POI bubble
         *  - link: Hyperlink accessible from POI bubble (optional)
         */
        var poi;
        for (var i = 0; i < pois.length; i++) {
            poi = {
                "coordinate": QtPositioning.coordinate(pois[i].y, pois[i].x),
                "title": pois[i].title || "",
                "text": pois[i].text || "",
                "link": pois[i].link || ""
            }
            map.pois.push(poi);
        }

        map.updateMapPois();
        map.savePois();
    }

    function addRoute(route, amend) {
        /*
         * Add a polyline to represent a route.
         *
         * Expected fields in route:
         *  - x: Array of route polyline longitude coordinates
         *  - y: Array of route polyline latitude coordinates
         *  - attribution: Plain text router attribution
         *  - mode: Transport mode: "car" or "transit"
         *
         * amend should be true to update the current polyline with minimum side-effects,
         * e.g. when rerouting, not given or false otherwise.
         */
        amend || map.endNavigating();
        map.clearRoute();
        map.route.x = route.x;
        map.route.y = route.y;
        map.route.attribution = route.attribution || "";
        map.route.mode = route.mode || "car";
        map.route.language = route.language;
        py.call_sync("poor.app.narrative.set_mode", [route.mode || "car"]);
        if (app.conf.get("voice_commands")) {
            py.call_sync("poor.app.narrative.set_voice", [route.language, app.conf.get("voice_gender")], null);
        } else {
            py.call_sync("poor.app.narrative.set_voice", [null])
        }
        py.call("poor.app.narrative.set_route", [route.x, route.y], function() {
            map.hasRoute = true;
        });
        map.updateMapRoute();
        map.saveRoute();
        map.saveManeuvers();
        app.navigationStarted = !!amend;
    }

    function beginNavigating() {
        // Set UI to navigation mode.
        map.zoomLevel < 16 && map.setZoomLevel(16);
        map.centerOnPosition();
        map.setMargins(0, 0.5, 0, 0.25);
//        // Wait for the centering animation to complete before turning
//        // on auto-rotate to avoid getting the trigonometry wrong.
//        py.call("poor.util.sleep", [0.5], function() {
//            map.autoCenter = true;
//            map.autoRotate = true;
//        });
        py.call("poor.app.narrative.begin", null, null);
        app.navigationActive = true;
        app.navigationPageSeen = true;
        app.navigationStarted = true;
        app.rerouteConsecutiveErrors = 0;
        app.reroutePreviousTime = -1;
        app.rerouteTotalCalls = 0;
    }

    function centerOnPosition() {
        // Center map on the current position.
        map.setCenter(map.position.coordinate.longitude,
                      map.position.coordinate.latitude);
    }

    function clear() {
        // Remove all point and route markers from the map.
        map.clearPois();
        map.clearRoute();
    }

    function clearPois() {
        // Remove all point of interest from the map.
        hidePoiBubbles();
        map.pois = [];
        map.updateMapPois();
        map.savePois();
    }

    function clearRoute() {
        // Remove all route markers from the map.
        map.maneuvers = [];
        map.route = {};
        py.call_sync("poor.app.narrative.unset", []);
        app.navigationStatus.clear();
        map.saveRoute();
        map.saveManeuvers();
        map.hasRoute = false;
        map.updateMapManeuvers();
        map.updateMapRoute();
    }

    function endNavigating() {
        // Restore UI from navigation mode.
        map.autoCenter = false;
        map.autoRotate = false;
        map.zoomLevel > 15 && map.setZoomLevel(15);
        map.setMargins(0, 0, 0, 0);
        py.call("poor.app.narrative.end", null, null);
        app.navigationActive = false;
    }

    function fitViewtoCoordinates(coords) {
        map.autoCenter = false;
        map.autoRotate = false;
        map.fitView(coords);
    }

    function fitViewToPois(pois) {
        // Set center and zoom so that given POIs are visible.
        var coords = [];
        for (var i = 0; i < pois.length; i++)
            coords.push(QtPositioning.coordinate(pois[i].y, pois[i].x));
        map.fitViewtoCoordinates(coords);
    }

    function fitViewToRoute() {
        // Set center and zoom so that the whole route is visible.
        // For performance reasons, include only a subset of points.
        if (map.route.x.length === 0) return;
        var coords = [];
        for (var i = 0; i < map.route.x.length; i = i + 10) {
            coords.push(QtPositioning.coordinate(
                            map.route.y[i], map.route.x[i]));
        }
        var x = map.route.x[map.route.x.length-1];
        var y = map.route.y[map.route.x.length-1];
        coords.push(QtPositioning.coordinate(y, x));
        map.fitViewtoCoordinates(coords);
    }

    //    function getBoundingBox() {
    //        // Return currently visible [xmin, xmax, ymin, ymax].
    //        var nw = map.toCoordinate(Qt.point(0, 0));
    //        var se = map.toCoordinate(Qt.point(map.width, map.height));
    //        return [nw.longitude, se.longitude, se.latitude, nw.latitude];
    //    }

    function getPosition() {
        // Return the current position as [x,y].
        return [map.position.coordinate.longitude,
                map.position.coordinate.latitude];

    }

    function hidePoiBubbles() {
        // Hide label bubbles of all POI markers.
        for (var i = 0; i < map.pois.length; i++) {
            if (map.pois[i].bubble) {
                map.removeLocationTracking(map.pois[i].bubble.trackerId);
                map.pois[i].bubble.destroy();
                map.pois[i].bubble = false;
            }
        }
    }

    function initLayers() {
        //////////////////////////////////////////////
        // POIs
        map.addSourcePoints(constants.sourcePois, []);
        map.addImagePath(constants.imagePoi, Qt.resolvedUrl(app.getIcon("icons/poi")))

        // since we have text labels, put the symbols on top
        map.addLayer(constants.layerPois, {"type": "symbol", "source": constants.sourcePois}); //, map.styleReferenceLayer);
        map.setLayoutProperty(constants.layerPois, "icon-image", constants.imagePoi);
        map.setLayoutProperty(constants.layerPois, "icon-size", 1.0 / map.pixelRatio);
        map.setLayoutProperty(constants.layerPois, "icon-allow-overlap", true);

        map.setLayoutProperty(constants.layerPois, "text-optional", true);
        map.setLayoutProperty(constants.layerPois, "text-field", "{name}");
        map.setLayoutProperty(constants.layerPois, "text-size", 12);
        map.setLayoutProperty(constants.layerPois, "text-anchor", "top");
        map.setLayoutPropertyList(constants.layerPois, "text-offset", [0.0, 1.0]);
        map.setPaintProperty(constants.layerPois, "text-halo-color", "white");
        map.setPaintProperty(constants.layerPois, "text-halo-width", 2);

        //////////////////////////////////////////////
        // Route
        map.addSourceLine(constants.sourceRoute, []);

        map.addLayer(constants.layerRouteCase,
                     {"type": "line", "source": constants.sourceRoute}, map.styleReferenceLayer);
        map.setLayoutProperty(constants.layerRouteCase, "line-join", "round");
        map.setLayoutProperty(constants.layerRouteCase, "line-cap", "round");
        map.setPaintProperty(constants.layerRouteCase, "line-color", "#819FFF");
        map.setPaintProperty(constants.layerRouteCase, "line-width", 8);

        map.addLayer(constants.layerRoute,
                     {"type": "line", "source": constants.sourceRoute}, map.styleReferenceLayer);
        map.setLayoutProperty(constants.layerRoute, "line-join", "round");
        map.setLayoutProperty(constants.layerRoute, "line-cap", "round");
        map.setPaintProperty(constants.layerRoute, "line-color", "white");
        map.setPaintProperty(constants.layerRoute, "line-width", 1);

        //////////////////////////////////////////////
        // Maneuvers - drawn on top of the route
        map.addSourcePoints(constants.sourceManeuvers, []);

        map.addLayer(constants.layerManeuvers,
                     {"type": "circle", "source": constants.sourceManeuvers}, map.styleReferenceLayer);
        map.setPaintProperty(constants.layerManeuvers, "circle-radius", 3);
        map.setPaintProperty(constants.layerManeuvers, "circle-color", "white");
        map.setPaintProperty(constants.layerManeuvers, "circle-stroke-width", 2);
        map.setPaintProperty(constants.layerManeuvers, "circle-stroke-color", "#819FFF");
    }

    function initProperties() {
        // Load default values and start periodic updates.
        if (!py.ready)
            return py.onReadyChanged.connect(map.initProperties);
        map.setZoomLevel(app.conf.get("zoom"));
        map.autoCenter = app.conf.get("auto_center");
        map.autoRotate = app.conf.get("auto_rotate");
        var center = app.conf.get("center");
        if (center[0] === 0.0 && center[1] === 0.0) {
            // Center on user's position on first start.
            map.centerFound = false;
            map.setCenter(13, 49);
        } else {
            map.centerFound = true;
            map.setCenter(center[0], center[1]);
        }
        app.updateKeepAlive();
        map.loadPois();
        map.loadRoute();
        map.loadManeuvers();
        map.ready = true;
    }

    function updateMapPois() {
        // update POIs drawn on the map
        var p = [];
        var n = [];
        for (var i = 0; i < map.pois.length; i++) {
            p.push(map.pois[i].coordinate);
            n.push(map.pois[i].title);
        }
        map.updateSourcePoints(constants.sourcePois, p, n);
    }

    function updateMapManeuvers() {
        // update maneuvers drawn on the map
        var p = [];
        for (var i = 0; i < map.maneuvers.length; i++) {
            p.push(map.maneuvers[i].coordinate);
        }
        map.updateSourcePoints(constants.sourceManeuvers, p);
    }

    function updateMapRoute() {
        // update route drawn on the map
        var p = [];
        if (map.route.x)  {
            for (var i = 0; i < map.route.x.length; i++) {
                p.push(QtPositioning.coordinate(
                           map.route.y[i], map.route.x[i]));
            }
        }
        map.updateSourceLine(constants.sourceRoute, p);
    }

    function loadManeuvers() {
        // Load maneuvers from JSON file.
        if (!py.ready) return;
        py.call("poor.storage.read_maneuvers", [], function(data) {
            if (data && data.length > 0)
                map.addManeuvers(data);
        });
    }

    function loadPois() {
        // Load POIs from JSON file.
        if (!py.ready) return;
        py.call("poor.storage.read_pois", [], function(data) {
            if (data && data.length > 0)
                map.addPois(data);
        });
    }

    function loadRoute() {
        // Load route from JSON file.
        if (!py.ready) return;
        py.call("poor.storage.read_route", [], function(data) {
            if (data.x && data.x.length > 0 &&
                    data.y && data.y.length > 0)
                map.addRoute(data);
        });
    }

    /* function renderTile(props) { */
    /*     // Render tile from local image file. */
    /*     if (props.half_zoom !== map.halfZoom) { */
    /*         map.halfZoom = props.half_zoom; */
    /*         map.setZoomLevel(map.zoomLevel); */
    /*     } */
    /*     for (var i = 0; i < map.tiles.length; i++) { */
    /*         if (map.tiles[i].uid !== props.uid) continue; */
    /*         map.tiles[i].coordinate.latitude = props.nwy; */
    /*         map.tiles[i].coordinate.longitude = props.nwx; */
    /*         map.tiles[i].smooth = props.smooth; */
    /*         map.tiles[i].type = props.type; */
    /*         map.tiles[i].zOffset = props.z; */
    /*         map.tiles[i].zoomLevel = props.display_zoom + */
    /*             (props.half_zoom ? constants.halfZoom : 0); */
    /*         map.tiles[i].uri = props.uri; */
    /*         map.tiles[i].setWidth(props); */
    /*         map.tiles[i].setHeight(props); */
    /*         map.tiles[i].setZ(map.zoomLevel); */
    /*         return; */
    /*     } */
    /*     // Add missing tile to collection. */
    /*     var component = Qt.createComponent("Tile.qml"); */
    /*     var tile = component.createObject(map); */
    /*     tile.uid = props.uid; */
    /*     map.tiles.push(tile); */
    /*     map.addMapItem(tile); */
    /*     map.renderTile(props); */
    /* } */

    function saveManeuvers() {
        // Save maneuvers to JSON file.
        if (!py.ready) return;
        var data = [];
        for (var i = 0; i < map.maneuvers.length; i++) {
            var maneuver = {};
            maneuver.x = map.maneuvers[i].coordinate.longitude;
            maneuver.y = map.maneuvers[i].coordinate.latitude;
            maneuver.icon = map.maneuvers[i].icon;
            maneuver.narrative = map.maneuvers[i].narrative;
            maneuver.duration = map.maneuvers[i].duration;
            maneuver.passive = map.maneuvers[i].passive;
            maneuver.verbal_alert = map.maneuvers[i].verbal_alert;
            maneuver.verbal_pre = map.maneuvers[i].verbal_pre;
            maneuver.verbal_post = map.maneuvers[i].verbal_post;
            data.push(maneuver);
        }
        py.call_sync("poor.storage.write_maneuvers", [data]);
    }

    function savePois() {
        // Save POIs to JSON file.
        if (!py.ready) return;
        var data = [];
        for (var i = 0; i < map.pois.length; i++) {
            var poi = {};
            poi.x = map.pois[i].coordinate.longitude;
            poi.y = map.pois[i].coordinate.latitude;
            poi.title = map.pois[i].title;
            poi.text = map.pois[i].text;
            poi.link = map.pois[i].link;
            data.push(poi);
        }
        py.call_sync("poor.storage.write_pois", [data]);
    }

    function saveRoute() {
        // Save route to JSON file.
        if (!py.ready) return;
        if (map.route.x && map.route.x.length > 0 &&
                map.route.y && map.route.y.length > 0) {
            var data = {};
            data.x = map.route.x;
            data.y = map.route.y;
            data.attribution = map.route.attribution;
            data.mode = map.route.mode;
            data.language = map.route.language
        } else {
            var data = {};
        }
        py.call_sync("poor.storage.write_route", [data]);
    }

    function setCenter(x, y) {
        // Set the current center position.
        // Create a new object to trigger animation.
        if (!x || !y) return;
        map.center = QtPositioning.coordinate(y, x);
    }

    /* function setZoomLevel(zoom) { */
    /*     // Set the current zoom level. */
    /*     // Round zoom level so that tiles are displayed pixel for pixel. */
    /*      zoom = map.halfZoom ? */
    /*         Math.ceil(zoom - constants.halfZoom - 0.01) + constants.halfZoom : */
    /*         Math.floor(zoom + 0.01); */
    /*     map.demoteTiles(); */
    /*     map.zoomLevel = zoom; */
    /*     map.zoomLevelPrev = zoom; */
    /*     var bbox = map.getBoundingBox(); */
    /*     map.widthCoords = bbox[1] - bbox[0]; */
    /*     map.heightCoords = bbox[3] - bbox[2]; */
    /*     map.scaleX = map.width / map.widthCoords; */
    /*     map.scaleY = map.height / map.heightCoords; */
    /*     map.hasRoute && map.route.redraw(); */
    /*     map.changed = true; */
    /* } */

    //    function updateSize() {
    //        // Update map width and height to match environment.
    //        if (map.autoRotate) {
    //            var dim = Math.floor(Math.sqrt(
    //                parent.width * parent.width +
    //                    parent.height * parent.height));
    //            map.width = dim;
    //            map.height = dim;
    //        } else {
    //            map.width = parent.width;
    //            map.height = parent.height;
    //        }
    //        map.hasRoute && map.route.redraw();
    //    }
}
