# fhem-rainbird
The FHEM modules RainbirdControler interacts with WiFi LNK module of the Rain Bird Irrigation System.

You can start/stop the irrigation and get the currently active zone.

This module communicates directly with the WiFi module - it does not support the cloud.
The communication of this FHEM module competes with the communication of the app - maybe the app signals a communication error.

## Define

    define <name> RainbirdControler <host>

### Example:

    define RainbirdControler RainbirdControler rainbird.fritz.box

The RainbirdControler device is created in the room "Rainbird".
If autocreate is enabled the zones of your system are recognized automatically and created in FHEM.

## Readings
    currentDate - current internal date of the controler
    currentTime - current internal time of the controler
    irrigationState - always 1
    rainDelay - irrigation delay in days
    rainSensorState - state of the rain sensor
    zoneActive - the current active zone

## set
    ClearReadings - clears all readings
    DeletePassword - deletes the password from store
    Password - sets the password in store
    SetRainDelay - sets the delay in days
    StopIrrigation - stops irrigating
    Update - updates the device info and state

## set [expert mode]

Expert mode is enabled by setting the attribute "expert" .

    IrrigateZone <zone> <minutes> - starts irrigating the <zone> for <minutes>

## get [expert mode]

Expert mode is enabled by setting the attribute "expert"".

    AvailableZones - gets all available zones
    DeviceState - get current device state
    DeviceInfo - get device info
    ModelAndVersion - get device model and version
    SerialNumber - get device serial number
    CurrentTime - get internal device time
    CurrentDate - get internal device date
    RainSensorState - get the state of the rainsensor
    RainDelay - get the delay in days
    CurrentIrrigation - get the current irrigation state
    IrrigationState - get the current irrigation state
    CommandSupport - get supported command info

## Attributes

    disable - disables the device
    interval - interval of polling in seconds (Default=60)
    expert - switches to expert mode

# fhem update wiki
https://wiki.fhem.de/wiki/Update

## add repository to fhem
update add https://raw.githubusercontent.com/J0EK3R/fhem-rainbird/master/controls_rainbird.txt

## list all repositories
update list
