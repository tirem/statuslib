# statuslib
A library for Ashita V4 that helps to track status effects, relevant enemies, and loads associated icons

* This library expects to live within the directory ```addons/libs/status```
* You can initialize the full statustracker with ```local statuslib = require('status.status');```. Helpers are then available with ```statuslib.helpers.[FunctionName]```
* If you would like to just use the helpers included with this lib without initializing tracking you can use ```local statusHelpers = require('status.statushelpers');```
