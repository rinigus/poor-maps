/* -*- coding: utf-8-unix -*-
 *
 * Copyright (C) 2015 Osmo Salomaa
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
import QtPositioning 5.3

//! Panning and pinch implementation on the maps
PinchArea {
    id: pincharea

    //! Holds previous zoom level value
    property double __oldZoom

    anchors.fill: parent

    //! Calculate zoom level
    function calcZoomDelta(zoom, percent) {
        return zoom + Math.log(percent)/Math.log(2)
    }

    //! Save previous zoom level when pinch gesture started
    onPinchStarted: {
        //console.log("Pinch started")
        __oldZoom = map.zoomLevel
    }

    //! Update map's zoom level when pinch is updating
    onPinchUpdated: {
        //map.zoomLevel = calcZoomDelta(__oldZoom, pinch.scale)
        map.setZoomLevel(calcZoomDelta(__oldZoom, pinch.scale), pinch.center)
    }

    //! Update map's zoom level when pinch is finished
    onPinchFinished: {
        //map.zoomLevel = calcZoomDelta(__oldZoom, pinch.scale)
        map.setZoomLevel(calcZoomDelta(__oldZoom, pinch.scale), pinch.center)

//        // TODO
//        // ORIGINAL CODE, MAYBE NEEDED FOR RASTER TILES IN FUTURE. NOT ADAPTED YET
//        // Round piched zoom level to avoid fuzziness.
//        var offset = map.zoomLevel < map.zoomLevelPrev ? -1 : 1;
//        Math.abs(map.zoomLevel - map.zoomLevelPrev) > 0.25 ?
//                    map.setZoomLevel(map.zoomLevelPrev + offset) :
//                    map.setZoomLevel(map.zoomLevelPrev);
    }


    //! Map's mouse area for implementation of panning in the map and zoom on double click
    MouseArea {
        id: mousearea

        //! Property used to indicate if panning the map
        property bool __isPanning: false

        //! Last pressed X and Y position
        property int __lastX: -1
        property int __lastY: -1

        //! Panned distance to distinguish panning from clicks
        property int __pannedDistance: 0

        anchors.fill : parent

        function isPanning() {
            return __isPanning && __pannedDistance > 0;
        }

        //! When pressed, indicate that panning has been started and update saved X and Y values
        onPressed: {
            __isPanning = true
            __lastX = mouse.x
            __lastY = mouse.y
            __pannedDistance = 0
        }

        //! When released, indicate that panning has finished
        onReleased: {
            __isPanning = false
        }

        //! Move the map when panning
        onPositionChanged: {
            if (__isPanning) {
                var dx = mouse.x - __lastX
                var dy = mouse.y - __lastY
                map.pan(dx, dy)
                __lastX = mouse.x
                __lastY = mouse.y
                __pannedDistance += Math.abs(dx) + Math.abs(dy);
            }
        }

        //! When canceled, indicate that panning has finished
        onCanceled: {
            __isPanning = false;
        }

        onPressAndHold: !isPanning() && map.queryCoordinateForPixel(Qt.point(mouse.x, mouse.y), "mouse onPressAndHold")

        onClicked: !isPanning() && map.queryCoordinateForPixel(Qt.point(mouse.x, mouse.y), "mouse onClicked")

        onDoubleClicked: !isPanning() && map.centerOnPosition();
    }

    Connections {
        target: map

        onReplyCoordinateForPixel: {
            if (tag === "mouse onPressAndHold") {
                map.addPois([{
                                 "x": geocoordinate.longitude,
                                 "y": geocoordinate.latitude,
                                 "title": app.tr("Unnamed point"),
                                 "text": app.tr("Unnamed point")
                             }]);
                return;
            }

            if (tag === "mouse onClicked") {
                map.mouseClick(geocoordinate, degLatPerPixel, degLonPerPixel)
                return;
            }
        }
    }
}
