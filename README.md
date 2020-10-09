# fhem-rainbird
This repository contains two modules for the **[FHEM](https://fhem.de) house automation system** written in **Perl** to communicate with a **Rain Bird Irrigation Controller**.

The [FHEM](https://fhem.de) RainbirdController interacts with **LNK WiFi Module** of the Rain Bird Irrigation System.

There is a FHEM module **RainbirdController** which represents the irrigation **controller device** and handles the communication.
And there is an underlying FHEM module **RainbirdZone** wich represents an **irrigation zone**.
There is one RainbirdZone device for each available irrigation zone.


Currently you can
* start/stop the irrigation
* get the current active zone
* get the available zones of the controller model
* get/set internal date and time of the controller

This module communicates directly with the WiFi module - it does not support the cloud.

*The communication of this FHEM module **competes** with the communication of the app - maybe the app signals a communication error.*

This perl code is ported from project https://github.com/jbarrancos/pyrainbird.

## Define

    define <name> RainbirdController <host>

The RainbirdControler device is created in the room "Rainbird".
If **autocreate** in FHEM is enabled all available irrigation zones of your system are recognized automatically and created as RainbirdZone devices in the same room as the RainbirdController by FHEM.

Once a valid password is set RainbirdController initially reads the static infos from the controller device and stores them as internals to the FHEM device.
Then RainbirdController polls every interval for dynamic values like irrigation state, date&time, etc., stores them in readings and signals them to the underlying RainbirdZone devices.


### Example:

    define RainbirdController RainbirdController rainbird.fritz.box

## Readings
    currentDate - current internal date of the controller
    currentTime - current internal time of the controller
    irrigationState - don't know: always 1
    rainDelay - irrigation delay in days
    rainSensorState - state of the rain sensor
    zoneActive - the current active zone

## set
    ClearReadings - clears all readings
    DeletePassword - deletes the password from store
    Password - sets the password in store
    RainDelay - sets the delay in days
    StopIrrigation - stops irrigating
    SynchronizeDateTime - synchronizes the internal date and time of the controller with fhem's time
    Date - sets the internal date of the controller - format YYYY-MM-DD
    Time - sets the internal time of the controller - format HH:MM or HH:MM:SS
    Update - updates the device info and state

## set [expert mode]

Expert mode is enabled by setting the attribute "expert".

    IrrigateZone <zone> <minutes> - starts irrigating the <zone> for <minutes>

## get [expert mode]

Expert mode is enabled by setting the attribute "expert".

    DeviceState - get current device state
    DeviceInfo - get device info
    ModelAndVersion - get device model and version
    AvailableZones - gets all available zones
    SerialNumber - get device serial number
    Date - get internal device date
    Time - get internal device time
    RainSensorState - get the state of the rainsensor
    RainDelay - get the delay in days
    CurrentIrrigation - get the current irrigation state
    IrrigationState - get the current irrigation state
    CommandSupport - get supported command info

## Attributes

    disable - disables the device
    interval - interval of polling in seconds (Default=60)
    timeout - timeout for expected response in seconds (Default=20)
    retries - number of retries (Default=3)
    expert - switches to expert mode

# fhem update wiki
https://wiki.fhem.de/wiki/Update

## add repository to fhem
    update add https://raw.githubusercontent.com/J0EK3R/fhem-rainbird/master/controls_rainbird.txt

## list all repositories
    update list
