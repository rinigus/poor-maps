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
import Sailfish.Silica 1.0
import "."

/*
 * Since the map is outside the page stack, it cannot use the automatic
 * orientation handling, which is part of the Page container. Let's
 * handle orientation changes ourselves with two wrapper containers.
 */

Page {

    allowedOrientations: app.defaultAllowedOrientations
    //z: 100

    Map { id: map }
    MenuButton { id: menuButton }
    Meters { id: meters }
    NavigationBlock { id: navigationBlock }
    NorthArrow { id: northArrow }
    Notification { id: notification }
    ScaleBar { id: scaleBar }

    Component.onCompleted: {
        app.map = map;
        app.menuButton = menuButton;
        app.navigationBlock = navigationBlock;
        app.northArrow = northArrow;
        app.notification = notification;
        app.scaleBar = scaleBar;
    }
}
