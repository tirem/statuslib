# statuslib
A library for Ashita V4 that helps to track status effects, relevant enemies, and loads associated icons

## Show Your Support ##
If you would like to show your support for my addon and library creation consider buying me a coffee! 

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/A0A6JC40H)

## Overview ##
* This library expects to live within the directory ```[yourAddon]/libs/status```
* You can initialize the full statustracker with ```local statuslib = require('libs/status/status');```. Helpers are then available with ```statusHelpers.[FunctionName]```
* If you would like to just use the helpers included with this lib without initializing tracking you can use ```local statusHelpers = require('libs/status/statushelpers');```
