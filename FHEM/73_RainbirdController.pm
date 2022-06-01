###############################################################################
#
# Developed with eclipse on windows os using fiddler to catch ip communication.
#
#  (c) 2020 Copyright: J.K. (J0EK3R at gmx dot net)
#  All rights reserved
#
#  Special thanks goes to committers:
#  * me
#
#  This script is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  any later version.
#
#  The GNU General Public License can be found at
#  http://www.gnu.org/copyleft/gpl.html.
#  A copy is found in the textfile GPL.txt and important notices to the license
#  from the author is found in LICENSE.txt distributed with these scripts.
#
#  This script is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#
# $Id: 73_RainbirdController.pm 201 2020-09-18 06:14:00Z J0EK3R $
#
###############################################################################

### our packagename
package main;

my $VERSION = "2.1.5";

use strict;
use warnings;

my $missingModul = "";
eval {use JSON;1 or $missingModul .= "JSON "};
eval {use Digest::SHA qw(sha256);1 or $missingModul .= "Digest::SHA "};
eval {use Crypt::CBC;1 or $missingModul .= "Crypt::CBC "};

#####################################
# Forward declarations
#####################################

### fhem
sub RainbirdController_Initialize($);
sub RainbirdController_Define($$);
sub RainbirdController_Ready($);
sub RainbirdController_Undef($$);
sub RainbirdController_Delete($$);
sub RainbirdController_Rename($$);
sub RainbirdController_Attr(@);
sub RainbirdController_Notify($$);
sub RainbirdController_Write($@);
sub RainbirdController_Set($@);
sub RainbirdController_Get($@);

### timer for polling
sub RainbirdController_TimerStop($);
sub RainbirdController_TimerRestart($);
sub RainbirdController_TimerLoop($);

### static device infos
sub RainbirdController_GetModelAndVersion($;$);
sub RainbirdController_GetAvailableZones($;$);
sub RainbirdController_GetCommandSupport($$;$);
sub RainbirdController_GetSerialNumber($;$);

### dynamic device infos
sub RainbirdController_GetWaterBudget($$;$);
sub RainbirdController_GetDeviceState($;$);
sub RainbirdController_GetWifiParams($;$);
sub RainbirdController_GetNetworkStatus($;$);

### device commands
sub RainbirdController_StopIrrigation($;$);
sub RainbirdController_FactoryReset($;$);

### not supported by ESP-RZXe Serie
sub RainbirdController_SetProgram($$;$);

### Time
sub RainbirdController_GetCurrentTime($;$);
sub RainbirdController_SetCurrentTime($$$$;$);
### Date
sub RainbirdController_GetCurrentDate($;$);
sub RainbirdController_SetCurrentDate($$$$;$);
### RainDelay
sub RainbirdController_GetRainDelay($;$);
sub RainbirdController_SetRainDelay($$;$);

### RainSensor
sub RainbirdController_GetRainSensorState($;$);
sub RainbirdController_GetRainSensorBypass($;$);
sub RainbirdController_SetRainSensorBypass($$;$);

sub RainbirdController_GetCurrentIrrigation($;$);
sub RainbirdController_GetActiveStation($;$);
sub RainbirdController_GetIrrigationState($;$);
### Zone
sub RainbirdController_ZoneIrrigate($$$;$);
sub RainbirdController_ZoneTest($$;$);
### Zone - Schedule
sub RainbirdController_ZoneGetSchedule($$;$);
sub RainbirdController_ZoneSetScheduleRAW($$;$);

### for testing purposes only
sub RainbirdController_TestCMD($$$;$);
sub RainbirdController_TestRAW($$;$);

### communication
sub RainbirdController_Command($$$@);
sub RainbirdController_Request($$$$$$);
sub RainbirdController_ErrorHandling($$$);
sub RainbirdController_ResponseProcessing($$);

### protocol handling
sub RainbirdController_EncodeData($$@);
sub RainbirdController_DecodeData($$$);
sub RainbirdController_AddPadding($$);
sub RainbirdController_EncryptData($$$;$);
sub RainbirdController_DecryptData($$$;$);

### password
sub RainbirdController_StorePassword($$);
sub RainbirdController_ReadPassword($);
sub RainbirdController_DeletePassword($);

### internal tool functions
sub RainbirdController_CallIfLambda($$$$);

sub RainbirdController_GetZoneFromRaw($);
sub RainbirdController_GetAvailableZoneCountFromRaw($);
sub RainbirdController_GetAvailableZoneMaskFromRaw($);

sub RainbirdController_GetTimeSpec($);
sub RainbirdController_GetDateSpec($);
sub RainbirdController_GetWeekdaysFromBitmask($);
sub RainbirdController_GetTimeFrom10Minutes($);

# startup of the app
# ModelAndVersionRequest
# -> {"id":34271,"method":"tunnelSip","params":{"length":1,"data":"02"},"jsonrpc":"2.0"}
# <- {"jsonrpc": "2.0", "result":{"length":5, "data":"8200030209"}, "id": 34271}
# -> {"id":19010,"method":"getWifiParams","params":{},"jsonrpc":"2.0"}
# <- {"jsonrpc": "2.0", "result":{"macAddress":"AA:BB:CC:DD:EE:FF", "localIpAddress":"192.168.0.77", "localNetmask":"255.255.255.0", "localGateway":"192.168.0.1", "rssi":-55, "wifiSsid":"My.WLANr", "wifiPassword":"Password", "wifiSecurity":"wpa2-aes", "apTimeoutNoLan":20, "apTimeoutIdle":20, "apSecurity":"unknown", "stickVersion":"Rain Bird Stick Rev C/1.63"}, "id": 19010}
# -> {"id":61707,"method":"getNetworkStatus","params":{},"jsonrpc":"2.0"}
# <- {"jsonrpc": "2.0", "result":{"networkUp":true, "internetUp":true}, "id": 61707}
# AvailableStationsRequest
# -> {"id":41372,"method":"tunnelSip","params":{"length":2,"data":"0300"},"jsonrpc":"2.0"}
# <- {"jsonrpc": "2.0", "result":{"length":6, "data":"8300FF000000"}, "id": 41372}
# CurrentTimeGetRequest
# -> {"id":22493,"method":"tunnelSip","params":{"length":1,"data":"10"},"jsonrpc":"2.0"}
# <- {"jsonrpc": "2.0", "result":{"length":4, "data":"90050C2E"}, "id": 22493}
# CurrentDateGetRequest
# -> {"id":4698,"method":"tunnelSip","params":{"length":1,"data":"12"},"jsonrpc":"2.0"}
# <- {"jsonrpc": "2.0", "result":{"length":4, "data":"920AA7E4"}, "id": 4698}
# RainDelayGetRequest
# -> {"id":26966,"method":"tunnelSip","params":{"length":1,"data":"36"},"jsonrpc":"2.0"}
# <- {"jsonrpc": "2.0", "result":{"length":3, "data":"B60000"}, "id": 26966}
# CurrentRainSensorStateRequest
# -> {"id":58048,"method":"tunnelSip","params":{"length":1,"data":"3E"},"jsonrpc":"2.0"}
# <- {"jsonrpc": "2.0", "result":{"length":2, "data":"BE00"}, "id": 58048}
# CurrentIrrigationStateRequest
# -> {"id":23167,"method":"tunnelSip","params":{"length":1,"data":"48"},"jsonrpc":"2.0"}
# <- {"jsonrpc": "2.0", "result":{"length":2, "data":"C801"}, "id": 23167}
# WaterBudgetRequest
# -> {"id":1606,"method":"tunnelSip","params":{"length":2,"data":"30FF"},"jsonrpc":"2.0"}
# <- {"jsonrpc": "2.0", "result":{"length":4, "data":"B0FF0064"}, "id": 1606}
# CurrentScheduleRequest
# -> {"id":18338,"method":"tunnelSip","params":{"length":3,"data":"200000"},"jsonrpc":"2.0"}
# <- {"jsonrpc": "2.0", "result":{"length":4, "data":"A0000000"}, "id": 18338}
# CurrentScheduleRequest Zone 1
# -> {"id":25843,"method":"tunnelSip","params":{"length":3,"data":"200001"},"jsonrpc":"2.0"}
# <- {"jsonrpc": "2.0", "result":{"length":14, "data":"A00001141E9090909090032B0200"}, "id": 25843}
# Zone 2 - 7
# CurrentScheduleRequest Zone 8
# -> {"id":16753,"method":"tunnelSip","params":{"length":3,"data":"200008"},"jsonrpc":"2.0"}
# <- {"jsonrpc": "2.0", "result":{"length":14, "data":"A0000800909090909090007F0200"}, "id": 16753}
# WaterBudgetRequest
# -> {"id":35389,"method":"tunnelSip","params":{"length":2,"data":"30FF"},"jsonrpc":"2.0"}
# <- {"jsonrpc": "2.0", "result":{"length":4, "data":"B0FF0064"}, "id": 35389}
# getSettings
# -> {"id":43605,"method":"getSettings","params":{},"jsonrpc":"2.0"}
# <- {"jsonrpc": "2.0", "result":{"country":"DE", "code":"12345", "globalDisable":false, "numPrograms":0, "programOptOutMask":"00", "SoilTypes": [] , "FlowRates": [] , "FlowUnits": [] }, "id": 43605}
# Unknown21Request
# -> {"id":19075,"method":"tunnelSip","params":{"length":14,"data":"2100070A363C90909090037F0100"},"jsonrpc":"2.0"}
# <- {"jsonrpc": "2.0", "result":{"length":2, "data":"0121"}, "id": 19075}
# -> {"id":21006,"method":"tunnelSip","params":{"length":14,"data":"2100070A363C90909090037F0100"},"jsonrpc":"2.0"}
# -> {"id":20153,"method":"tunnelSip","params":{"length":14,"data":"2100070A363C90909090037F0100"},"jsonrpc":"2.0"}
# -> {"id":60743,"method":"tunnelSip","params":{"length":14,"data":"2100070A363C90909090037F0100"},"jsonrpc":"2.0"}
# Unknown21Request
# -> {"id":15701,"method":"tunnelSip","params":{"length":4,"data":"21000000"},"jsonrpc":"2.0"}
# <- {"jsonrpc": "2.0", "result":{"length":2, "data":"0121"}, "id": 15701}
# Unknown31Request (save settings)
# -> {"id":37309,"method":"tunnelSip","params":{"length":4,"data":"31FF0064"},"jsonrpc":"2.0"}
# <- {"jsonrpc": "2.0", "result":{"length":2, "data":"0131"}, "id": 37309}

# activate seasonal adjust
# -> {"id":33095,"method":"setWeatherAdjustmentMask","params":{"globalDisable":true,"numPrograms":0,"programOptOutMask":"00"},"jsonrpc":"2.0"}
# <- {"jsonrpc": "2.0", "result":{}, "id": 33095}
#
# -> {"id":13544,"method":"tunnelSip","params":{"length":4,"data":"31FF0064"},"jsonrpc":"2.0"}
# <- {"jsonrpc": "2.0", "result":{"length":2, "data":"0131"}, "id": 13544}
#
# -> {"id":8078,"method":"tunnelSip","params":{"length":2,"data":"3F00"},"jsonrpc":"2.0"}
# <- {"jsonrpc": "2.0", "result":{"length":6, "data":"BF0020000000"}, "id": 8078}
#

# deaktivate seasonal adjust
# -> {"id":1118,"method":"setWeatherAdjustmentMask","params":{"globalDisable":false,"numPrograms":0,"programOptOutMask":"00"},"jsonrpc":"2.0"}
# <- {"jsonrpc": "2.0", "result":{}, "id": 1118}
#
# -> {"id":18922,"method":"tunnelSip","params":{"length":4,"data":"31FF0064"},"jsonrpc":"2.0"}
# <- {"jsonrpc": "2.0", "result":{"length":2, "data":"0131"}, "id": 18922}
#
# -> {"id":48453,"method":"tunnelSip","params":{"length":2,"data":"3F00"},"jsonrpc":"2.0"}
# <- {"jsonrpc": "2.0", "result":{"length":6, "data":"BF0020000000"}, "id": 48453}

# adjust 50%
# -> {"id":14437,"method":"tunnelSip","params":{"length":4,"data":"31FF0096"},"jsonrpc":"2.0"}
# <- {"jsonrpc": "2.0", "result":{"length":2, "data":"0131"}, "id": 14437}
#
# -> {"id":62636,"method":"tunnelSip","params":{"length":2,"data":"3F00"},"jsonrpc":"2.0"}
# <- {"jsonrpc": "2.0", "result":{"length":6, "data":"BF0020000000"}, "id": 62636}

# adjust 100%
# -> {"id":51469,"method":"tunnelSip","params":{"length":4,"data":"31FF00C8"},"jsonrpc":"2.0"}
# <- {"jsonrpc": "2.0", "result":{"length":2, "data":"0131"}, "id": 51469}
#
# -> {"id":16958,"method":"tunnelSip","params":{"length":2,"data":"3F00"},"jsonrpc":"2.0"}
# <- {"jsonrpc": "2.0", "result":{"length":6, "data":"BF0000000000"}, "id": 16958}

# adjust 0%
# -> {"id":57907,"method":"tunnelSip","params":{"length":4,"data":"31FF0064"},"jsonrpc":"2.0"}
# <- {"jsonrpc": "2.0", "result":{"length":2, "data":"0131"}, "id": 57907}
#
# -> {"id":37653,"method":"tunnelSip","params":{"length":2,"data":"3F00"},"jsonrpc":"2.0"}
# <- {"jsonrpc": "2.0", "result":{"length":6, "data":"BF0000000000"}, "id": 37653}


### format of a command entry
### command name:                 "CurrentDateSetRequest" => 
###                               {
### command number as string:       "command" => "13", 
### [opt] first parameter charlen:  "parameter1" => 2, 
### [opt] second parameter charlen: "parameter2" => 1, "
### [opt] third parameter charlen:  "parameter3" => 3, 
### response number as string:      "response" => "01", 
### total bytelength:               "length" => 4
###                               },
my %ControllerCommands = (
  "GetWifiParamsRequest"              => {"method" => "getWifiParams", "response" => "WifiParams"},
  "GetNetworkStatusRequest"           => {"method" => "getNetworkStatus", "response" => "NetworkStatus"},
  "GetSettingsRequest"                => {"method" => "getSettings", "response" => "Settings"},
  "ModelAndVersionRequest"            => {"method" => "tunnelSip", "command" => "02", "response" => "82", "length" => 1},
  "AvailableStationsRequest"          => {"method" => "tunnelSip", "command" => "03", "response" => "83", "length" => 2, 
    "parameter1"                      => {"length" =>  2}},
  "CommandSupportRequest"             => {"method" => "tunnelSip", "command" => "04", "response" => "84", "length" => 2, 
    "parameter1"                      => {"length" =>  2}}, # command like "04"
  "SerialNumberRequest"               => {"method" => "tunnelSip", "command" => "05", "response" => "85", "length" => 1},
  ### still unknown - length OK
  "Unknown06Request"                  => {"method" => "tunnelSip", "command" => "06", "response" => "86", "length" => 5, 
    "parameter1"                      => {"length" =>  2},
    "parameter2"                      => {"length" =>  2},
    "parameter3"                      => {"length" =>  2},
    "parameter4"                      => {"length" =>  2}},
  ### still unknown - length OK
  "Unknown07Request" => {"method" => "tunnelSip", "command" => "07", "response" => "86", "length" => 5, 
    "parameter1"                      => {"length" =>  2},
    "parameter2"                      => {"length" =>  2},
    "parameter3"                      => {"length" =>  2},
    "parameter4"                      => {"length" =>  2}},
  ### "AlternateBitRateSupportRequest" "09"
  ### "ControllerFirmwareVersionRequest" "0B"
  ### "UniversalMessageRequest" "0C"
  "CurrentTimeGetRequest"             => {"method" => "tunnelSip", "command" => "10", "response" => "90", "length" => 1},
  "CurrentTimeSetRequest"             => {"method" => "tunnelSip", "command" => "11", "response" => "01", "length" => 4, 
    "parameter1"                      => {"length" =>  2},
    "parameter2"                      => {"length" =>  2},
    "parameter3"                      => {"length" =>  2}},
  "CurrentDateGetRequest"             => {"method" => "tunnelSip", "command" => "12", "response" => "92", "length" => 1},
  "CurrentDateSetRequest"             => {"method" => "tunnelSip", "command" => "13", "response" => "01", "length" => 4, 
    "parameter1"                      => {"length" =>  2},
    "parameter2"                      => {"length" =>  1},
    "parameter3"                      => {"length" =>  2}},
  "GetScheduleRequest"                => {"method" => "tunnelSip", "command" => "20","response" => "A0", "length" => 3, 
    "parameter1"                      => {"length" =>  4}},  # ZoneId 1..MaxZone
  "GetRainSensorBypassRequest"        => {"method" => "tunnelSip", "command" => "20","response" => "A0", "length" => 3, 
    "parameter1"                      => {"length" =>  4}},  # ZoneId -> 0!
  "SetRainSensorBypassRequest"        => {"method" => "tunnelSip", "command" => "21", "response" => "01", "length" => 4, 
    "parameter1"                      => {"length" =>  4},   # zoneId -> 0! 
    "parameter2"                      => {"length" =>  2}},  # 0x00: on 0x80: off
  "SetScheduleRAWRequest"             => {"method" => "tunnelSip", "command" => "21", "response" => "01", "length" => 14, 
    "parameter1"                      => {"length" => 26, "format" => "%s"}}, # raw value like 0001141E9090909090032B0201
  "SetScheduleRequest"                => {"method" => "tunnelSip", "command" => "21", "response" => "01", "length" => 14, 
    "parameter1"                      => {"length" =>  4},  # zoneId -> 1..MaxZone 
    "parameter2"                      => {"length" =>  2},  # timespan 
    "parameter3"                      => {"length" =>  2},  # timer1
    "parameter4"                      => {"length" =>  2},  # timer2
    "parameter5"                      => {"length" =>  2},  # timer3
    "parameter6"                      => {"length" =>  2},  # timer4
    "parameter7"                      => {"length" =>  2},  # timer5
    "parameter8"                      => {"length" =>  2},
    "parameter9"                      => {"length" =>  2},  # mode 
    "parameter10"                     => {"length" =>  2},  # weekday 
    "parameter11"                     => {"length" =>  2},  # interval 
    "parameter12"                     => {"length" =>  2}}, # intervaldaysleft
  # not supported
    # FF ->
    # "data" : "B0FF0064",
    # "identifier" : "Rainbird",
    # "programCode" : "255",
    # "responseId" : "B0",
    # "seasonalAdjust" : "100",
    # "type" : "WaterBudgetResponse"
  "GetWaterBudgetRequest"             => {"method" => "tunnelSip", "command" => "30", "response" => "B0", "length" => 2,  
    "parameter1"                      => {"length" =>  2}},  # ZoneId -> FF for seasonal adjust
  ### {"id":14437,"method":"tunnelSip","params":{"length":4,"data":"31FF0096"},"jsonrpc":"2.0"}
  "SetWaterBudgetRequest"             => {"method" => "tunnelSip", "command" => "31", "response" => "01", "length" => 4, 
    "parameter1"                      => {"length" =>  2},  # ZoneId -> FF for seasonal adjust 
    "parameter2"                      => {"length" =>  2},  # ???
    "parameter3"                      => {"length" =>  2}}, # adjustment 0x64 = 0% 0x96 = 50% 0xC8 = 100% 
  # not supported
  "ZonesSeasonalAdjustFactorRequest"  => {"method" => "tunnelSip", "command" => "32", "response" => "B2", "length" => 2,  
    "parameter1"                      => {"length" =>  2}}, 
  ### "ZonesSeasonalAdjustFactorSet" "33"
  "RainDelayGetRequest"               => {"method" => "tunnelSip", "command" => "36", "response" => "B6", "length" => 1},
  "RainDelaySetRequest"               => {"method" => "tunnelSip", "command" => "37", "response" => "01", "length" => 3, 
    "parameter1"                      => {"length" =>  4}},
  # not supported
  "ManuallyRunProgramRequest"         => {"method" => "tunnelSip", "command" => "38", "response" => "01", "length" => 2,
    "parameter1"                      => {"length" =>  2}}, 
  "ManuallyRunStationRequest"         => {"method" => "tunnelSip", "command" => "39", "response" => "01", "length" => 4, 
    "parameter1"                      => {"length" =>  4},  # ZoneId
    "parameter2"                      => {"length" =>  2}}, # irrigation timespan in minutes
  "TestStationsRequest"               => {"method" => "tunnelSip", "command" => "3A", "response" => "01", "length" => 2, 
    "parameter1"                      => {"length" =>  2}},
  "GetIrrigationStateRequest"         => {"method" => "tunnelSip", "command" => "3B", "response" => "BB", "length" => 2,
    "parameter1"                      => {"length" =>  2}},
  ### ("CurrentStationErrorRequest", "3D", true)
  "CurrentStationErrorRequest"        => {"method" => "tunnelSip", "command" => "3D", "response" => "DB", "length" => 2,
    "parameter1"                      => {"length" =>  2}},
  "CurrentRainSensorStateRequest"     => {"method" => "tunnelSip", "command" => "3E", "response" => "BE", "length" => 1},
  "CurrentStationsActiveRequest"      => {"method" => "tunnelSip", "command" => "3F", "response" => "BF", "length" => 2, 
    "parameter1"                      => {"length" =>  2}},
  "StopIrrigationRequest"             => {"method" => "tunnelSip", "command" => "40", "response" => "01", "length" => 1},
  ### still unknown
  "Unknown41Request"                  => {"method" => "tunnelSip", "command" => "41", "response" => "01", "length" => 2, 
   "parameter1"                       => {"length" =>  2}}, # 00, FF
  # not supported
  "AdvanceStationRequest"             => {"method" => "tunnelSip", "command" => "42", "response" => "01", "length" => 2,
    "parameter1"                      => {"length" =>  2}}, 
  "CurrentIrrigationStateRequest"     => {"method" => "tunnelSip", "command" => "48", "response" => "C8", "length" => 1},
  # not supported
  "CurrentControllerStateSet"         => {"method" => "tunnelSip", "command" => "49", "response" => "01", "length" => 2, 
    "parameter1"                      => {"length" =>  2}}, 
  # not supported
  "ControllerEventTimestampRequest"   => {"method" => "tunnelSip", "command" => "4A", "response" => "CA", "length" => 2, 
    "parameter1"                      => {"length" =>  2}}, 
  # not supported
  "StackManuallyRunStationRequest"    => {"method" => "tunnelSip", "command" => "4B", "response" => "01", "length" => 4, 
    "parameter1"                      => {"length" =>  2}, 
    "parameter2"                      => {"length" =>  1}, 
    "parameter3"                      => {"length" =>  1}}, 
  # not supported
  "CombinedControllerStateRequest"    => {"method" => "tunnelSip", "command" => "4C", "response" => "CC","length" => 1 },
  ### "IrrigationStatisticsRequest" "4D"
  ### still unknown
  "Unknown50Request"                  => {"method" => "tunnelSip", "command" => "50", "response" => "01", "length" => 1},
  ### still unknown
  "Unknown51Request"                  => {"method" => "tunnelSip", "command" => "51", "response" => "01", "length" => 1},
  ### still unknown
  "Unknown52Request"                  => {"method" => "tunnelSip", "command" => "52", "response" => "01", "length" => 1},
  "FactoryResetRequest"               => {"method" => "tunnelSip", "command" => "57", "response" => "01", "length" => 1},
   ### "StartLearnFlowSequenceRequest" "60"
   ### "CancelLearnFlowSequenceRequest" "61"
   ### "LearnFlowSequenceStatusRequest" "62"
   ### "FlowMonitorStatusRequest" "63"
   ### "FlowMonitorStatusSetRequest" "64"
   ### "FlowMonitorRateRequest" "65"
   ### "LogEntriesRequest" "70"
);

### format of a response entry
### response number as string: "00" => 
###                            {
### total bytelength             "length" =>  3, 
### response name                "type" => "NotAcknowledgeResponse", 
### [opt] first parameter name   "commandEcho" => 
###                              {
### char offset in string          "position" => 2, 
### char length                    "length" => 2, 
### [opt] fromatstring             "format" => "%02X"
###                              }, 
### [opt] second parameter name  "NAKCode" => 
###                              {
### char offset in string          "position" => 4, 
### char length                    "length" => 2, 
### [opt] known values list        "knownvalues" => 
###                                {
### [opt] known value                "1" => "command not supported", 
### [opt] known value                "2" => "wrong number of parameters", 
### [opt] known value                "4" => "command not supported",
###                                } 
###                              } 
###                            },

my %ControllerResponses = (
  # {
  #   "jsonrpc": "2.0", 
  #   "result":
  #   {
  #     "macAddress":"AA:BB:CC:DD:EE:FF", 
  #     "localIpAddress":"192.168.0.77", 
  #     "localNetmask":"255.255.255.0", 
  #     "localGateway":"192.168.0.1", 
  #     "rssi":-57, "wifiSsid":"MYWLAN", 
  #     "wifiPassword":"password", 
  #     "wifiSecurity":"wpa2-aes", 
  #     "apTimeoutNoLan":20, 
  #     "apTimeoutIdle":20, 
  #     "apSecurity":"unknown", 
  #     "stickVersion":"Rain Bird Stick Rev C/1.63"
  #   }, 
  #   "id": 29
  # }
  "WifiParams"              => {"type" => "GetWifiParamsResponse"},
  
  # {
  #   "jsonrpc": "2.0",
  #   "result":
  #   {
  #     "networkUp":true, 
  #     "internetUp":true
  #   }, 
  #   "id": 30
  # }     
  "NetworkStatus"           => {"type" => "GetNetworkStatusResponse"},

  # {
  #   "jsonrpc": "2.0", 
  #   "result":
  #   {
  #     "country":"DE", 
  #     "code":"12345", 
  #     "globalDisable":false, 
  #     "numPrograms":0, 
  #     "programOptOutMask":"00", 
  #     "SoilTypes": [] , 
  #     "FlowRates": [] , 
  #     "FlowUnits": [] 
  #    }, 
  #   "id": 44
  # }
  "Settings"                => {"type" => "GetSettingsResponse"},

  "00" => {6                => {"type" => "NotAcknowledgeResponse", 
    "commandEcho"           => {"position" =>  2, "length" => 2, "format" => "%02X"}, 
    "NAKCode"               => {"position" =>  4, "length" => 2, "knownvalues" => {"1" => "[1]: command not supported", "2" => "[2]: wrong number of parameters", "4" => "[4]: illegal parameter",} } } },
  "01" => {4                => {"type" => "AcknowledgeResponse", 
    "commandEcho"           => {"position" =>  2, "length" => 2, "format" => "%02X"} } },
  "82" => {10               => {"type" => "ModelAndVersionResponse", 
    "modelID"               => {"position" =>  2, "length" => 4}, 
    "protocolRevisionMajor" => {"position" =>  6, "length" => 2}, 
    "protocolRevisionMinor" => {"position" =>  8, "length" => 2} } },
  "83" => {12               => {"type" => "AvailableStationsResponse", 
    "pageNumber"            => {"position" =>  2, "length" => 2}, 
    "setStations"           => {"position" =>  4, "length" => 8} } },
  "84" => {6                => {"type" => "CommandSupportResponse", 
    "commandEcho"           => {"position" =>  2, "length" => 2, "format" => "%02X"}, 
    "support"               => {"position" =>  4, "length" => 2} } },
  "85" => {18               => {"type" => "SerialNumberResponse", 
    "serialNumber"          => {"position" =>  2, "length" => 16} } },
  "86" => {18               => {"type" => "Unknown06Response", 
    "result1"               => {"position" =>  2, "length" => 8, "format" => "%X"}, 
    "result2"               => {"position" => 10, "length" => 8, "format" => "%X"} } },
  ### "ControllerFirmwareVersionResponse" "8B"
  ### "UniversalMessageTransportResponse" "8C"
  "90" => {8                => {"type" => "CurrentTimeGetResponse", 
    "hour"                  => {"position" =>  2, "length" => 2}, 
    "minute"                => {"position" =>  4, "length" => 2}, 
    "second"                => {"position" =>  6, "length" => 2} } },
  "92" => {8                => {"type" => "CurrentDateGetResponse", 
    "day"                   => {"position" =>  2, "length" => 2}, 
    "month"                 => {"position" =>  4, "length" => 1}, 
    "year"                  => {"position" =>  5, "length" => 3} } },

  "A0" => {
    # {"jsonrpc": "2.0", "result":{"length":4, "data":"A0000000"}, "id": 45698}
    8 => {"type"            => "GetRainSensorBypassResponse", 
      "unknown2"            => {"position" =>  2, "length" => 2},
      "unknown4"            => {"position" =>  4, "length" => 2},
      "bypass"              => {"position" =>  6, "length" => 2, "knownvalues" => {"0" => "on", "128" => "off"} } },

    # {"id":130,"jsonrpc":"2.0","result":{"data":"A0000000000000","length":7}}
    14 => {"type"           => "GetRainSensorBypassResponse", 
      "unknown2"            => {"position" =>  2, "length" => 2},
      "unknown4"            => {"position" =>  4, "length" => 2},
      "bypass"              => {"position" =>  6, "length" => 2, "knownvalues" => {"0" => "on", "128" => "off"} }, 
      "unknown8"            => {"position" =>  8, "length" => 2},
      "unknow10"            => {"position" => 10, "length" => 2},
      "unknow12"            => {"position" => 12, "length" => 2} },

    # {"jsonrpc": "2.0", "result":{"length":14, "data":"A000080F909090909090007F0200"}, "id": 45713}
    28 => {"type"           => "GetScheduleResponse", 
      "zoneId"              => {"position" =>  2, "length" => 4}, 
      "timespan"            => {"position" =>  6, "length" => 2}, 
      "timer1"              => {"position" =>  8, "length" => 2, "knownvalues" => {"24:00" => "off"}, "converter" => \&RainbirdController_GetTimeFrom10Minutes},
      "timer2"              => {"position" => 10, "length" => 2, "knownvalues" => {"24:00" => "off"}, "converter" => \&RainbirdController_GetTimeFrom10Minutes},
      "timer3"              => {"position" => 12, "length" => 2, "knownvalues" => {"24:00" => "off"}, "converter" => \&RainbirdController_GetTimeFrom10Minutes},
      "timer4"              => {"position" => 14, "length" => 2, "knownvalues" => {"24:00" => "off"}, "converter" => \&RainbirdController_GetTimeFrom10Minutes}, 
      "timer5"              => {"position" => 16, "length" => 2, "knownvalues" => {"24:00" => "off"}, "converter" => \&RainbirdController_GetTimeFrom10Minutes},
      "param1"              => {"position" => 18, "length" => 2, "knownvalues" => {"144" => "off"}}, 
      "mode"                => {"position" => 20, "length" => 2, "knownvalues" => {"0" => "user", "1" => "odd", "2" => "even", "3" => "cyclic"}}, 
      "weekday"             => {"position" => 22, "length" => 2, "converter" => \&RainbirdController_GetWeekdaysFromBitmask}, 
      "interval"            => {"position" => 24, "length" => 2}, 
      "intervaldaysleft"    => {"position" => 26, "length" => 2} } },

  "B0" => {8 => {"type"     => "GetWaterBudgetResponse", 
    "programCode"           => {"position" =>  2, "length" => 2}, 
    "seasonalAdjust"        => {"position" =>  4, "length" => 4} } },
  "B2" => {36 => {"type"    => "ZonesSeasonalAdjustFactorResponse", 
    "programCode"           => {"position" =>  2, "length" => 2}, 
    "stationsSA"            => {"position" =>  4, "length" => 32} } },
  "B6" => {6 => {"type"     => "RainDelaySettingResponse", 
    "delaySetting"          => {"position" =>  2, "length" => 4} } 
  },
    
  "BB" => {
    # {"jsonrpc": "2.0", "result":{"length":10, "data":"BB000001000006010466"}, "id": 45705}
    20 => {"type"           => "GetIrrigationStateResponse", 
      "unknown2"            => {"position" =>  2, "length" => 2},
      "unknown4"            => {"position" =>  4, "length" => 2},
      "unknown6"            => {"position" =>  6, "length" => 2},
      "unknown8"            => {"position" =>  8, "length" => 2},
      "unknown10"           => {"position" => 10, "length" => 2},
      "activeZone"          => {"position" => 12, "length" => 2},
      "unknown14"           => {"position" => 14, "length" => 2},
      "secondsLeft"         => {"position" => 16, "length" => 4} },

    # {"id":137,"jsonrpc":"2.0","result":{"data":"BB0000000000000000FF0000","length":12}}
    24 => {"type"           => "GetIrrigationStateResponse", 
      "unknown2"            => {"position" =>  2, "length" => 2},
      "unknown4"            => {"position" =>  4, "length" => 2},
      "unknown6"            => {"position" =>  6, "length" => 2},
      "unknown8"            => {"position" =>  8, "length" => 2},
      "unknown10"           => {"position" => 10, "length" => 2},
      "activeZone"          => {"position" => 12, "length" => 2},
      "unknown14"           => {"position" => 14, "length" => 2},
      "secondsLeft"         => {"position" => 16, "length" => 4},
      "unknown20"           => {"position" => 20, "length" => 2},
      "unknown22"           => {"position" => 22, "length" => 2} } 
  },
  "BD" => {12 => {"type"    => "Unknown3DResponse", 
    "sensorState"           => {"position" =>  2, "length" => 2} },
      "unknown4"            => {"position" =>  4, "length" => 2},
      "unknown6"            => {"position" =>  6, "length" => 2},
      "unknown8"            => {"position" =>  8, "length" => 2},
      "unknown10"           => {"position" => 10, "length" => 2} },
  "BE" => {4 => {"type"     => "CurrentRainSensorStateResponse", 
    "sensorState"           => {"position" =>  2, "length" => 2} } },
  "BF" => {12 => {"type"    => "CurrentStationsActiveResponse", 
    "pageNumber"            => {"position" =>  2, "length" => 2}, 
    "activeStations"        => {"position" =>  4, "length" => 8} } },
  "C8" => {4 => {"type"     => "CurrentIrrigationStateResponse", 
    "irrigationState"       => {"position" =>  2, "length" => 2} } },
  "CA" => {12 => {"type"    => "ControllerEventTimestampResponse", 
    "eventId"               => {"position" =>  2, "length" => 2}, 
    "timestamp"             => {"position" =>  4, "length" => 8} } },
  "CC" => {32 => {"type"    => "CombinedControllerStateResponse", 
    "hour"                  => {"position" =>  2, "length" => 2}, 
    "minute"                => {"position" =>  4, "length" => 2}, 
    "second"                => {"position" =>  6, "length" => 2}, 
    "day"                   => {"position" =>  8, "length" => 2}, 
    "month"                 => {"position" => 10, "length" => 1}, 
    "year"                  => {"position" => 11, "length" => 3}, 
    "delaySetting"          => {"position" => 14, "length" => 4}, 
    "sensorState"           => {"position" => 18, "length" => 2}, 
    "irrigationState"       => {"position" => 20, "length" => 2}, 
    "seasonalAdjust"        => {"position" => 22, "length" => 4}, 
    "remainingRuntime"      => {"position" => 26, "length" => 4}, 
    "activeStation"         => {"position" => 30, "length" => 2} } }
    ### "IrrigationStatisticsResponse" "CD"
    ### "StartLearnFlowSequenceResponse" "E0"
    ### "CancelLearnFlowSequenceResponse" "E0"
    ### "LearnFlowSequenceStatusResponse" "E2"
    ### "FlowMonitorStatusResponse" "E3"
    ### "FlowMonitorStatusSetResponse" "64"
    ### "FlowMonitorRateResponse" "E5"
);

### constants
my $DefaultInterval       = 60; # default value for the polling interval in seconds
my $DefaultRetryInterval  = 5;  # default value for the retry interval in seconds
my $DefaultTimeout        = 10; # default value for response timeout in seconds
my $DefaultRetries        = 2;  # default number of retries 

### hash with all known models
my %KnownModels = (
  0x0003 => ["ESP-RZXe",      "ESP-RZXe",   0, 0, 6],
  0x0007 => ["ESP_ME",        "ESP-Me",     1, 4, 6],
  0x0006 => ["ST8X_WF",       "ST8x-WiFi",  0, 0, 6],
  0x0005 => ["ESP_TM2",       "ESP-TM2",    1, 3, 4],
  0x0008 => ["ST8X_WF2",      "ST8x-WiFi2", 1, 8, 6],
  0x0009 => ["ESP_ME3",       "ESP-ME3",    1, 4 ,6],
  0x0010 => ["MOCK_ESP_ME2",  "ESP=Me2",    1, 4, 6],
  0x000A => ["ESP_TM2v2",     "ESP-TM2",    1, 3 ,4],
  0x010A => ["ESP_TM2v3",     "ESP-TM2",    1, 3, 4],
  0x0099 => ["TBOS_BT",       "TBOS-BT",    1, 3, 8],
  0x0100 => ["TBOS_BT",       "TBOS-BT",    1, 3, 8],
  0x0107 => ["ESP_MEv2",      "ESP-Me",     1, 4, 6],
  0x0103 => ["ESP_RZXe2",     "ESP-RZXe2",  1, 8, 6],
);

my $DebugMarker               = "Dbg";
my $ResponseCountSuccessRetry = "ResponseCount_Success_Try_";

my $TimerLoopIdentifier       = "Loop";
my $TimerRetryIdentifier      = "Retry";
my $NotCheckedValue           = "not checked yet";

my $DEFAULT_PAGE              = 0;
my $BLOCK_SIZE                = 16;
my $INTERRUPT                 = "\x00";
my $PAD                       = "\x10";

my $CMDSUPPORTPREFIX          = "Cmd_"; # hide with prefix "."
my $CMDSUPPORTPOSTFIX         = "_Support"; # hide with prefix "."
my $CMDSUPPORT_3F             =  $CMDSUPPORTPREFIX . '3F' . $CMDSUPPORTPOSTFIX;

### HTML hedaer
my $HEAD = 
    "Accept-Language: en\n" .
    "Accept-Encoding: gzip, deflate\n" .
    "User-Agent: RainBird/2.0 CFNetwork/811.5.4 Darwin/16.7.0\n" .
    "Accept: */*\n" .
    "Connection: keep-alive\n" .
    "Content-Type: application/octet-stream";

#####################################
# initialization of the module
#####################################
sub RainbirdController_Initialize($)
{
  my ($hash) = @_;

  $hash->{DefFn}    = \&RainbirdController_Define;
  $hash->{UndefFn}  = \&RainbirdController_Undef;
  $hash->{DeleteFn} = \&RainbirdController_Delete;
  $hash->{RenameFn} = \&RainbirdController_Rename;
  $hash->{AttrFn}   = \&RainbirdController_Attr;
  $hash->{NotifyFn} = \&RainbirdController_Notify;
  $hash->{WriteFn}  = \&RainbirdController_Write;
  $hash->{SetFn}    = \&RainbirdController_Set;
  $hash->{GetFn}    = \&RainbirdController_Get;

  $hash->{Clients}   = "RainbirdZone";
  $hash->{MatchList} = { '1:RainbirdZone' => '"identifier":"Rainbird"' }; # example: {"response":"BF","pageNumber":0,"type":"CurrentStationsActiveResponse","identifier":"Rainbird","activeStations":0}

  $hash->{AttrList} = 
    "debug:0,1 " . 
    "debugcrypt:0,1 " . 
    "disable:0,1 " . 
    "checkcmd:0,1 " . 
    "autocreatezones:1,0 " . 
    "interval " . 
    "disabledForIntervals " . 
    "timeout " . 
    "retry " . 
    $readingFnAttributes;

  foreach my $d ( sort keys %{ $modules{RainbirdController}{defptr} } )
  {
    my $hash = $modules{RainbirdController}{defptr}{$d};
    $hash->{VERSION} = $VERSION;
  }
}

#####################################
# definition of a new instance
#####################################
sub RainbirdController_Define($$)
{
  my ( $hash, $def ) = @_;

  my @a = split( '[ \t][ \t]*', $def );

  return 'Cannot define RainbirdController device. Perl modul "' . ${missingModul} . '" is missing.' 
    if ($missingModul);
    
  return 'too few parameters: define <NAME> RainbirdController' 
    if ( @a < 3 );
  
  return 'too much parameters: define <NAME> RainbirdController' 
    if ( @a > 3 );

  my $name = $a[0];
  #          $a[1] just contains the "RainbirdController" module name and we already know that! :-)
  my $host = $a[2];

  my $logInfoString = "RainbirdController_Define($name)";

  ### Stop the current timer if one exists errornous 
  #RainbirdController_TimerStop($hash);

  ### some internal settings
  $hash->{VERSION}                          = $VERSION;
  $hash->{INTERVAL}                         = $DefaultInterval;
  $hash->{RETRYINTERVAL}                    = $DefaultRetryInterval;
  $hash->{TIMEOUT}                          = $DefaultTimeout;
  $hash->{RETRIES}                          = $DefaultRetries;
  $hash->{NOTIFYDEV}                        = "global,$name";
  $hash->{HOST}                             = $host;

  $hash->{AUTOCREATEZONES}                  = 1;
  $hash->{ZONESAVAILABLECOUNT}              = 0; # 
  $hash->{ZONESAVAILABLEMASK}               = 0; # 
  $hash->{ZONEACTIVE}                       = 0; # 
  $hash->{ZONEACTIVEMASK}                   = 0; # 
  $hash->{REQUESTID}                        = 0;
  $hash->{TIMERON}                          = 0;

  $hash->{helper}{Debug}                    = "0";
  $hash->{helper}{DebugCrypt}               = "0";
  $hash->{helper}{IsDisabled}               = "0";
  $hash->{helper}{CheckCommandSupport}      = "1";
  $hash->{helper}{RequestCount}             = 0; # statistics
  $hash->{helper}{ResponseCount}            = 0; # statistics
  $hash->{helper}{ResponseCount_Success}    = 0; # statistics
  $hash->{helper}{ResponseCount_Dropped}    = 0; # statistics
  $hash->{helper}{ResponseCount_Error}      = 0; # statistics
  $hash->{helper}{ResponseTotalTimespan}    = 0; # statistics
  $hash->{helper}{ResponseAverageTimespan}  = 0; # statistics
#  $hash->{helper}{ResponseCount_Retry_0}    = 0; # statistics
#  $hash->{helper}{ResponseCount_Retry_1}    = 0; # statistics
#  $hash->{helper}{ResponseCount_Retry_2}    = 0; # statistics
  for(my $leftRetries = 0; $leftRetries <= $hash->{RETRIES}; $leftRetries++)
  { 
    my $retrystring = $ResponseCountSuccessRetry . ($hash->{RETRIES} - $leftRetries);
    $hash->{helper}{$retrystring} = 0;
  }

  $hash->{helper}{Password}                 = RainbirdController_ReadPassword($hash);

  # dont check these commands
  my $cmdKey_04 = $CMDSUPPORTPREFIX . "04" . $CMDSUPPORTPOSTFIX;
  $hash->{helper}{CMD}{$cmdKey_04} = "not checked";
    
  # set attribute defaults
  CommandAttr( undef, $name . ' room Rainbird' )
    if ( AttrVal( $name, 'room', 'none' ) eq 'none' );

  # ensure attribute webCmd is present
  CommandAttr( undef, $name . ' webCmd Stop:Update' )
    if ( AttrVal( $name, 'webCmd', 'none' ) eq 'none' );

  # ensure attribute event-on-change-reading is present
  # exclude readings currentTime and currentDate
  CommandAttr( undef, $name . ' event-on-change-reading (?!InternalTime).*' )
    if ( AttrVal( $name, 'event-on-change-reading', 'none' ) eq 'none' );

  # set reference to this instance in global modules hash
  $modules{RainbirdController}{defptr}{CONTROLLER} = $hash;

  # set initial state
  readingsSingleUpdate($hash, "state", 'initialized', 1 );

  Log3($name, 3, "$logInfoString: defined RainbirdController");

  return undef;
}

####################################
# RainbirdController_Ready( $hash )
sub RainbirdController_Ready($)
{
  my ($hash)  = @_;
  my $name    = $hash->{NAME};

  my $logInfoString = "RainbirdController_Ready($name)";

  Log3($name, 4, "$logInfoString");

  RainbirdController_TimerRestart($hash);
}

#####################################
# undefine of an instance
#####################################
sub RainbirdController_Undef($$)
{
  my ($hash, $name) = @_;

  RainbirdController_TimerStop($hash);

  delete $modules{RainbirdController}{defptr}{CONTROLLER}
    if (defined($modules{RainbirdController}{defptr}{CONTROLLER}));

  return undef;
}

#####################################
# delete of an instance
#####################################
sub RainbirdController_Delete($$)
{
  my ($hash, $name) = @_;

  ### delete saved password
  RainbirdController_DeletePassword( $hash);

  return undef;
}

#####################################
# rename
#####################################
sub RainbirdController_Rename($$)
{
  my ($new, $old) = @_;
  my $hash = $defs{$new};

  # save password
  RainbirdController_StorePassword($hash, $hash->{helper}{Password});
  setKeyValue($hash->{TYPE} . "_" . $old . "_passwd", undef );

  return undef;
}

#####################################
# attribute handling
#####################################
sub RainbirdController_Attr(@)
{
  my ($cmd, $name, $attrName, $attrVal ) = @_;
  my $hash = $defs{$name};

  my $logInfoString = "RainbirdController_Attr($name)";

  Log3($name, 4, "$logInfoString: Attr was called");

  ### Attribute "disable"
  if ($attrName eq "disable")
  {
    if ($cmd eq "set" and 
      $attrVal eq "1")
    {
      Log3($name, 3, "$logInfoString: disabled");

      $hash->{helper}{IsDisabled} = "1";
      RainbirdController_UpdateInternals($hash);

      RainbirdController_TimerStop($hash);

      readingsBeginUpdate($hash);
      readingsBulkUpdateIfChanged( $hash, "state", "inactive", 1 );
      readingsEndUpdate($hash, 1);
    } 
    else
    {
      Log3($name, 3, "$logInfoString: enabled");

      $hash->{helper}{IsDisabled} = "0";
      RainbirdController_UpdateInternals($hash);

      readingsBeginUpdate($hash);
      readingsBulkUpdateIfChanged( $hash, "state", "active", 1 );
      readingsEndUpdate($hash, 1);

      RainbirdController_TimerRestart($hash);
    }
  }

  ### Attribute "debug"
  elsif ($attrName eq "debug" )
  {
    if ($cmd eq "set" and 
      $attrVal eq "1")
    {
      Log3($name, 3, "$logInfoString: debugging enabled");

      $hash->{helper}{Debug} = "$attrVal";
      RainbirdController_UpdateInternals($hash);
    } 
    else
    {
      Log3($name, 3, "$logInfoString: debugging disabled");

      $hash->{helper}{Debug} = "0";
      RainbirdController_UpdateInternals($hash);
    }
  }

  ### Attribute "debugcrypt"
  elsif ($attrName eq "debugcrypt" )
  {
    if ($cmd eq "set" and 
      $attrVal eq "1")
    {
      Log3($name, 3, "$logInfoString: debugging en/decryption enabled");

      $hash->{helper}{DebugCrypt} = "$attrVal";
      RainbirdController_UpdateInternals($hash);
    } 
    else
    {
      Log3($name, 3, "$logInfoString: debugging en/decryption disabled");

      $hash->{helper}{DebugCrypt} = "0";
      RainbirdController_UpdateInternals($hash);
    }
  }

  ### Attribute "checkcmd"
  elsif ($attrName eq "checkcmd" )
  {
    if ($cmd eq "set" and 
      $attrVal eq "1")
    {
      $hash->{helper}{CheckCommandSupport} = "1";
      RainbirdController_UpdateInternals($hash);
    } 
    else
    {
      $hash->{helper}{CheckCommandSupport} = "0";
      RainbirdController_UpdateInternals($hash);
    }
  }

  ### Attribute "disabledForIntervals"
  elsif ($attrName eq "disabledForIntervals")
  {
    if ($cmd eq "set")
    {
      return "check disabledForIntervals Syntax HH:MM-HH:MM or 'HH:MM-HH:MM HH:MM-HH:MM ...'"
        unless ( $attrVal =~ /^((\d{2}:\d{2})-(\d{2}:\d{2})\s?)+$/ );

      Log3($name, 3, "$logInfoString: disabledForIntervals");
    } 
    else
    {
      readingsSingleUpdate($hash, "state", "active", 1 );
      
      Log3($name, 3, "$logInfoString: enabled");
    }
  }

  ### Attribute "interval"
  elsif ($attrName eq "interval")
  {
    if ($cmd eq "set")
    {
      Log3($name, 3, "$logInfoString: set interval: $attrVal");

      return "Interval must be greater than 0"
        unless ( $attrVal > 0 );

      RainbirdController_TimerStop($hash);

      $hash->{INTERVAL} = $attrVal;

      RainbirdController_TimerRestart($hash);
    } 
    else
    {
      RainbirdController_TimerStop($hash);
      
      $hash->{INTERVAL} = $DefaultInterval;

      Log3($name, 3, "$logInfoString: delete user interval and set default: $hash->{INTERVAL}");

      RainbirdController_TimerRestart($hash);
    }
  }

  ### Attribute "timeout"
  elsif ($attrName eq "timeout")
  {
    if ($cmd eq "set")
    {
      Log3($name, 3, "$logInfoString: set timeout: $attrVal");

      return "timeout must be greater than 0"
        unless ( $attrVal > 0 );

      $hash->{TIMEOUT} = $attrVal;
    } 
    else
    {
      $hash->{TIMEOUT} = $DefaultTimeout;

      Log3($name, 3, "$logInfoString: delete user timeout and set default: $hash->{TIMEOUT}");
    }
  }

  ### Attribute "retries"
  elsif ($attrName eq "retries")
  {
    if ($cmd eq "set")
    {
      Log3($name, 3, "$logInfoString: set retries: $attrVal");

      return "retries must be greater or equal than 0"
        unless ( $attrVal >= 0 );

      $hash->{RETRIES} = $attrVal;
    } 
    else
    {
      $hash->{RETRIES} = $DefaultRetries;

      Log3($name, 3, "$logInfoString: delete user retries and set default: $hash->{RETRIES}");
    }
  }

  ### Attribute "autocreatezones"
  if ($attrName eq "autocreatezones")
  {
    if ($cmd eq "set" and
      $attrVal eq "0")
    {
      $hash->{AUTOCREATEZONES} = 0;
      Log3($name, 3, "$logInfoString: autocreatezones disabled");
    } 
    else
    {
      $hash->{AUTOCREATEZONES} = 1;
      Log3($name, 3, "$logInfoString: autocreatezones disabled");
    }
  }

  return undef;
}

#####################################
# notify handling
#####################################
sub RainbirdController_Notify($$)
{
  my ($hash, $dev) = @_;
  my $name = $hash->{NAME};

  return
    if ($hash->{helper}{IsDisabled} ne "0");

  my $devname = $dev->{NAME};
  my $devtype = $dev->{TYPE};
  my $events  = deviceEvents($dev, 1);

  return
    if (!$events);

  my $logInfoString = "RainbirdController_Notify($name)";

  Log3($name, 4, "$logInfoString: DevType: \"$devtype\"");

  # process "global" events
  if ($devtype eq "Global")
  { 
    if (grep(m/^INITIALIZED$/, @{$events}))
    {
      # this is the initial call after fhem has startet
      Log3($name, 3, "$logInfoString: INITIALIZED");

      RainbirdController_Ready($hash);
    }

    elsif (grep(m/^REREADCFG$/, @{$events}))
    {
      Log3($name, 3, "$logInfoString: REREADCFG");

      RainbirdController_Ready($hash);
    }

    elsif (grep(m/^DEFINED.$name$/, @{$events}) )
    {
      Log3($name, 3, "$logInfoString: DEFINED");

      RainbirdController_Ready($hash);
    }

    elsif (grep(m/^MODIFIED.$name$/, @{$events}))
    {
      Log3($name, 3, "$logInfoString: MODIFIED");

      RainbirdController_Ready($hash);
    }

    if ($init_done)
    {
    }
  }
  
  # process internal events
  elsif ($devtype eq "RainbirdController")
  {
  }
  
  return undef;
}

#####################################
# Write
#####################################
sub RainbirdController_Write($@)
{
  my ($hash, $cmd, @args) = @_;
  my $name = $hash->{NAME};

  my $logInfoString = "RainbirdController_Write($name)";

  Log3($name, 4, "$logInfoString: Write was called cmd: $cmd:");
  
  RainbirdController_Set( $hash, $name, $cmd, @args);
}

#####################################
# Set
#####################################
sub RainbirdController_Set($@)
{
  my ($hash, $name, $cmd, @args) = @_;

  my $logInfoString = "RainbirdController_Set($name)";

  Log3($name, 4, "$logInfoString: Set was called cmd: $cmd");

  ### Password
  if (lc $cmd eq lc "Password")
  {
    return "usage: $cmd <password>"
      if ( @args != 1 );

    my $passwd = join(' ', @args);
    
    RainbirdController_StorePassword($hash, $passwd);

    $hash->{helper}{Password} = $passwd;
    RainbirdController_UpdateInternals($hash);

    RainbirdController_TimerRestart($hash);
  } 
  
  ### DeletePassword
  elsif (lc $cmd eq lc "DeletePassword")
  {
    RainbirdController_DeletePassword($hash);

    $hash->{helper}{Password} = undef;
    RainbirdController_UpdateInternals($hash);

    RainbirdController_TimerRestart($hash);
  } 
  
  ### Stop
  elsif (lc $cmd eq lc "Stop")
  {
    return "please set password first"
      if (not defined($hash->{helper}{Password}) );
    
    return RainbirdController_StopIrrigation($hash);
  } 
  
  ### IrrigateZone
  elsif (lc $cmd eq lc "IrrigateZone")
  {
    return "please set password first"
      if (not defined($hash->{helper}{Password}));

    return "usage: $cmd <zone> <minutes>"
      if ( @args != 2 );

    my $zone = $args[0];
    my $minutes = $args[1];
    
    return RainbirdController_ZoneIrrigate($hash, $zone, $minutes);
  } 

  ### RainDelay
  elsif (lc $cmd eq lc "RainDelay")
  {
    return "please set password first"
      if (not defined($hash->{helper}{Password}));

    return "usage: $cmd <days>"
      if ( @args != 1 );

    my $days = $args[0];
    
    return RainbirdController_SetRainDelay($hash, $days);
  } 

  ### RainSensorBypass
  elsif ( lc $cmd eq lc "RainSensorBypass" )
  {
    return "please set password first"
      if (not defined($hash->{helper}{Password}));

    return "usage: $cmd on|off"
      if ( @args != 1 );

    my $onoff = lc $args[0];
    
    return RainbirdController_SetRainSensorBypass($hash, $onoff);
  } 

  ### SynchronizeDateTime
  elsif ( lc $cmd eq lc "SynchronizeDateTime" )
  {
    return "please set password first"
      if (not defined($hash->{helper}{Password}));

    # $mday is the day of the month 
    # $mon the month in the range 0..11 , with 0 indicating January and 11 indicating December
    # $year contains the number of years since 1900
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime();
    
    my $callback = sub 
    {
      RainbirdController_SetCurrentDate($hash, $year + 1900, $mon + 1, $mday); 
    };
    
    return RainbirdController_SetCurrentTime($hash, $hour, $min, $sec, $callback);
  } 

  ### InternalTime
  elsif ( lc $cmd eq lc "InternalTime" )
  {
    return "please set password first"
      if (not defined($hash->{helper}{Password}));

    return "usage: $cmd <hour>:<minute>[:<second>]"
      if ( @args != 1 );

    my ($msg, $hour, $min, $sec) = RainbirdController_GetTimeSpec($args[0]);
    
    if (defined($msg) )
    {
      return $msg;
    }    
    
    return RainbirdController_SetCurrentTime($hash, $hour, $min, $sec);
  } 

  ### InternalDate
  elsif ( lc $cmd eq lc "InternalDate" )
  {
    return "please set password first"
      if (not defined($hash->{helper}{Password}));

    return "usage: $cmd <year>-<month>-<day>"
      if ( @args != 1 );

    my ($msg, $year, $month, $day) = RainbirdController_GetDateSpec($args[0]);
    
    if (defined($msg) )
    {
      return $msg;
    }    
    
    return RainbirdController_SetCurrentDate($hash, $year, $month, $day);
  } 

  ### Update
  elsif ( lc $cmd eq lc "Update" )
  {
    return "please set password first"
      if (not defined($hash->{helper}{Password}));
    
    return RainbirdController_GetDeviceState($hash);
  } 

  ### FactoryReset
  elsif ( lc $cmd eq lc "FactoryReset" )
  {
    return "please set password first"
      if (not defined($hash->{helper}{Password}));
    
    return RainbirdController_FactoryRsete($hash);
  } 

  ### Command "clearreadings"
  elsif (lc $cmd eq lc "clearreadings")
  {
    return "usage: $cmd <mask>"
      if ( @args != 1 );

    my $mask = $args[0];
    fhem("deletereading $name $mask", 1);
    return;
  }

  ### TestCMD
  elsif ( lc $cmd eq lc "TestCMD" )
  {
    return "please set password first"
      if (not defined($hash->{helper}{Password}));
    
    return "usage: $cmd <command> [<arg1>, <arg2>]"
      if ( @args < 1 );

    ### first entry is commandstring
    ### others are parameters
    my $command = shift(@args);
    
    return RainbirdController_TestCMD($hash, $command, \@args);
  } 

  ### TestRAW
  elsif ( lc $cmd eq lc "TestRAW" )
  {
    return "please set password first"
      if (not defined($hash->{helper}{Password}));
    
    return "usage: $cmd <command> <raw hex string>"
      if ( @args != 1 );

    my $rawHexString = $args[0];
    
    return RainbirdController_TestRAW($hash, $rawHexString);
  } 

  ### ZoneGetSchedule
  elsif ( lc $cmd eq lc "ZoneGetSchedule" )
  {
    return "please set password first"
      if (not defined($hash->{helper}{Password}));

    return "usage: $cmd <zone>"
      if ( @args != 1 );
    
    my $zone = $args[0];
    return RainbirdController_ZoneGetSchedule($hash, $zone);
  } 
  
  ### ZoneSetScheduleRAW
  elsif ( lc $cmd eq lc "ZoneSetScheduleRAW" )
  {
    return "please set password first"
      if (not defined($hash->{helper}{Password}));

    return "usage: $cmd <rawvalue>"
      if ( @args != 1 );
    
    my $rawValue = $args[0];
    return RainbirdController_ZoneSetScheduleRAW($hash, $rawValue);
  } 

  ### else
  else
  {
    my $list = "";

    $list .= "ClearReadings:$DebugMarker.*,.* ";
    $list .= "Password ";

    if (defined($hash->{helper}{Password}))
    {
      $list .= "DeletePassword:noArg ";
      $list .= "InternalDate ";
      $list .= "InternalTime:time ";
      $list .= "RainDelay:slider,0,1,14 ";
      $list .= "RainSensorBypass:on,off ";
      $list .= "Stop:noArg ";
      $list .= "SynchronizeDateTime:noArg ";
      $list .= "Update:noArg ";
      ### debug mode:
#      if($hash->{ZONESAVAILABLECOUNT} > 0)
#      {
#        $list .= "IrrigateZone " if($hash->{helper}{Debug} ne "0");
#      }
#      else
#      {
#        $list .= "IrrigateZone " if($hash->{helper}{Debug} ne "0");
#      }
      $list .= "IrrigateZone " if($hash->{helper}{Debug} ne "0");
      $list .= "FactoryReset:noArg " if($hash->{helper}{Debug} ne "0");
      $list .= "TestCMD " if($hash->{helper}{Debug} ne "0");
      $list .= "TestRAW " if($hash->{helper}{Debug} ne "0");
      # $list .= "ZoneGetSchedule " if($hash->{helper}{Debug} ne "0"); # don't show
      $list .= "ZoneSetScheduleRAW " if($hash->{helper}{Debug} ne "0");
    }

    return "Unknown argument $cmd, choose one of $list";
  }
}

#####################################
# Get
#####################################
sub RainbirdController_Get($@)
{
  my ( $hash, $name, $cmd, @args ) = @_;

  my $logInfoString = "RainbirdController_Get($name)";

  Log3($name, 4, "$logInfoString: Get was called cmd: $cmd");

  ### DeviceState
  if ( lc $cmd eq lc "DeviceState" )
  {
    return "please set password first"
      if (not defined($hash->{helper}{Password}));
    
    return RainbirdController_GetDeviceState($hash);
  } 
  
  ### WifiParams
  elsif ( lc $cmd eq lc "WifiParams" )
  {
    return "please set password first"
      if (not defined($hash->{helper}{Password}));
    
    return RainbirdController_GetWifiParams($hash);
  } 
  
  ### NetworStatus
  elsif ( lc $cmd eq lc "NetworStatus" )
  {
    return "please set password first"
      if (not defined($hash->{helper}{Password}));
    
    return RainbirdController_GetNetworkStatus($hash);
  } 
  
  ### Settings
  elsif ( lc $cmd eq lc "Settings" )
  {
    return "please set password first"
      if (not defined($hash->{helper}{Password}));
    
    return RainbirdController_GetSettings($hash);
  } 
  
  ### ModelAndVersion
  elsif ( lc $cmd eq lc "ModelAndVersion" )
  {
    return "please set password first"
      if (not defined($hash->{helper}{Password}));
    
    return RainbirdController_GetModelAndVersion($hash);
  } 
  
  ### AvailableZones
  elsif ( lc $cmd eq lc "AvailableZones" )
  {
    return "please set password first"
      if (not defined($hash->{helper}{Password}));
    
    return RainbirdController_GetAvailableZones($hash);
  } 
  
  ### SerialNumber
  elsif ( lc $cmd eq lc "SerialNumber" )
  {
    return "please set password first"
      if (not defined($hash->{helper}{Password}));
    
    return RainbirdController_GetSerialNumber($hash);
  } 
  
  ### Time
  elsif ( lc $cmd eq lc "Time" )
  {
    return "please set password first"
      if (not defined($hash->{helper}{Password}));
    
    return RainbirdController_GetCurrentTime($hash);
  } 
  
  ### Date
  elsif ( lc $cmd eq lc "Date" )
  {
    return "please set password first"
      if (not defined($hash->{helper}{Password}));
    
    return RainbirdController_GetCurrentDate($hash);
  } 
  
  ### RainSensorBypass
  elsif ( lc $cmd eq lc "RainSensorBypass" )
  {
    return "please set password first"
      if (not defined($hash->{helper}{Password}));
    
    return RainbirdController_GetRainSensorBypass($hash);
  } 
  
  ### RainSensorState
  elsif ( lc $cmd eq lc "RainSensorState" )
  {
    return "please set password first"
      if (not defined($hash->{helper}{Password}));
    
    return RainbirdController_GetRainSensorState($hash);
  } 
  
  ### RainDelay
  elsif ( lc $cmd eq lc "RainDelay" )
  {
    return "please set password first"
      if (not defined($hash->{helper}{Password}));
    
    return RainbirdController_GetRainDelay($hash);
  } 
  
  ### CurrentIrrigation
  elsif ( lc $cmd eq lc "CurrentIrrigation" )
  {
    return "please set password first"
      if (not defined($hash->{helper}{Password}));
    
    return RainbirdController_GetCurrentIrrigation($hash);
  } 
  
  ### IrrigationState
  elsif ( lc $cmd eq lc "IrrigationState" )
  {
    return "please set password first"
      if (not defined($hash->{helper}{Password}));
    
    return RainbirdController_GetActiveStation($hash);
  } 
  
  ### ZoneSchedule
  elsif ( lc $cmd eq lc "ZoneSchedule" )
  {
    return "please set password first"
      if (not defined($hash->{helper}{Password}));

    return "usage: $cmd <zone>"
      if ( @args != 1 );
    
    my $zone = $args[0];
    return RainbirdController_ZoneGetSchedule($hash, $zone);
  } 
  
  ### CommandSupport
  elsif ( lc $cmd eq lc "CommandSupport" )
  {
    return "please set password first"
      if (not defined($hash->{helper}{Password}));
    
    return "usage: $cmd <hexcommand>"
      if ( @args != 1 );

    my $command = lc $args[0];
    my $hexValue;

    if($command =~ m/^0x[0-9a-f]+$/i) 
    {
      $hexValue = sprintf("%X", hex($command));
    }
    else
    {
      $hexValue = sprintf("%X", $command);
    }
    return RainbirdController_GetCommandSupport($hash, $hexValue);
  } 
  
  ### DecryptHEX
  elsif ( lc $cmd eq lc "DecryptHEX" )
  {
    return "please set password first"
      if (not defined($hash->{helper}{Password}));
    
    ### byte[] arrOutput = { 0x2A, 0xD5, 0x4B, 0xE0, 0x84, 0x83, 0xFC, 0x71, 0x31, 0x4D, 0xB3, 0x29, 0x18, 0xF1, 0xEE, 0xDB, 0x8F, 0xE5, 0xD7, 0xFF, 0x21, 0xBA, 0x9D, 0x78, 0x08, 0x05, 0xD9, 0x99, 0x56, 0x81, 0x86, 0x5E, 0x98, 0xC3, 0x6B, 0xCD, 0x4A, 0x10, 0xF8, 0xE9, 0xDF, 0x49, 0x21, 0x73, 0x4D, 0x09, 0xF6, 0x90, 0x91, 0x06, 0x3A, 0xE8, 0xB2, 0x43, 0x9E, 0xEA, 0x31, 0x8A, 0x1D, 0x5C, 0x44, 0x98, 0xEA, 0x06, 0xD7, 0x1D, 0xBE, 0xED, 0xBC, 0x23, 0xF9, 0x35, 0x3C, 0x06, 0xD7, 0xAC, 0x5A, 0xBD, 0x47, 0xA2, 0x01, 0xFF, 0x2A, 0x90, 0xA1, 0x51, 0x22, 0x44, 0x98, 0xB8, 0x21, 0xB7, 0xC6, 0xC8, 0x67, 0x90, 0xAA, 0x41, 0xBB, 0x90, 0xE2, 0x6C, 0x9C, 0xDE, 0x1A, 0x3D, 0x90, 0x56, 0xDA, 0x94, 0x3B, 0xF3, 0x35, 0x18, 0x7A, 0x87, 0x64, 0x05, 0x7E, 0xDE, 0xE4, 0x27, 0xC4, 0x87, 0xC9, 0x4B, 0xFC, 0x6B, 0x56, 0x3A, 0x5D, 0x6B, 0x96, 0x3B, 0x84, 0xE7, 0x37, 0xBD, 0xF4, 0xB4, 0x2A, 0x62, 0x99, 0x5C };
    ### args like 2A D5 4B E0 84 83 FC 71 31 4D B3 29 18 F1 EE DB 8F E5 D7 FF 21 BA 9D 78 08 05 D9 99 56 81 86 5E 98 C3 6B CD 4A 10 F8 E9 DF 49 21 73 4D 09 F6 90 91 06 3A E8 B2 43 9E EA 31 8A 1D 5C 44 98 EA 06 D7 1D BE ED BC 23 F9 35 3C 06 D7 AC 5A BD 47 A2 01 FF 2A 90 A1 51 22 44 98 B8 21 B7 C6 C8 67 90 AA 41 BB 90 E2 6C 9C DE 1A 3D 90 56 DA 94 3B F3 35 18 7A 87 64 05 7E DE E4 27 C4 87 C9 4B FC 6B 56 3A 5D 6B 96 3B 84 E7 37 BD F4 B4 2A 62 99 5C
    my $string = uc(join('', @args));

    #readingsBulkUpdate($hash, 'string', $string, 1 );
    
    ### string between {}
    while($string =~ m/{(.*)}/)
    {
      ($string) = ($string =~ /{(.*)}/);
    }
    
    ### string between []
    while($string =~ m/\[(.*)\]/)
    {
      ($string) = ($string =~ /\[(.*)\]/);
    }

    ### string between ()
    while($string =~ m/\((.*)\)/)
    {
      ($string) = ($string =~ /\((.*)\)/);
    }
    
    #readingsBulkUpdate($hash, 'stringbetween', $string, 1 );

    ### replace 0x|,
    while ($string =~ s/(0X)|,//) {}
    #readingsBulkUpdate($hash, 'stringreplace', $string, 1 );

    my $bytearray = pack("H*", $string);
    #readingsBulkUpdate($hash, 'bytearray', (sprintf("%v02X", $bytearray) =~ s/\.//rg), 1 );
    
    my $password = ($hash->{helper}{Password});
    ### decrypt

    if(not defined($password))
    {
      asyncOutput($hash->{CL}, "password not defined");
    }
    
    my $decryptedData = eval { RainbirdController_DecryptData($hash, $bytearray, $password, "DecryptHEX") };
  
    if ($@)
    {
      asyncOutput($hash->{CL}, $@);
    }
    else
    {
      asyncOutput($hash->{CL}, $decryptedData);
    }
  } 
  
  ### else
  else
  {
    my $list = "";
    
    if (defined($hash->{helper}{Password}))
    {
      # debug mode
      $list .= " AvailableZones:noArg" if($hash->{helper}{Debug} ne "0");
      $list .= " CommandSupport" if($hash->{helper}{Debug} ne "0");
      $list .= " CurrentIrrigation:noArg" if($hash->{helper}{Debug} ne "0");
      $list .= " DecryptHEX" if($hash->{helper}{Debug} ne "0");
      $list .= " Date:noArg" if($hash->{helper}{Debug} ne "0");
      $list .= " DeviceState:noArg" if($hash->{helper}{Debug} ne "0");
      $list .= " IrrigationState:noArg" if($hash->{helper}{Debug} ne "0");
      $list .= " ModelAndVersion:noArg" if($hash->{helper}{Debug} ne "0");
      $list .= " NetworkStatus:noArg" if($hash->{helper}{Debug} ne "0");
      $list .= " RainDelay:noArg" if($hash->{helper}{Debug} ne "0");
      $list .= " RainSensorBypass:noArg" if($hash->{helper}{Debug} ne "0");
      $list .= " RainSensorState:noArg" if($hash->{helper}{Debug} ne "0");
      $list .= " SerialNumber:noArg" if($hash->{helper}{Debug} ne "0");
      $list .= " Settings:noArg" if($hash->{helper}{Debug} ne "0");
      $list .= " Time:noArg" if($hash->{helper}{Debug} ne "0");
      $list .= " WifiParams:noArg" if($hash->{helper}{Debug} ne "0");
      $list .= " ZoneSchedule" if($hash->{helper}{Debug} ne "0");
    }
    
    return "Unknown argument $cmd, choose one of $list";
  }
}

#####################################
# RainbirdController_UpdateInternals( $hash )
sub RainbirdController_UpdateInternals($)
{
  my ($hash)  = @_;
  my $name    = $hash->{NAME};

  my $logInfoString = "RainbirdController_UpdateInternals($name)";

  Log3($name, 4, "$logInfoString");
  
  if($hash->{helper}{Debug} eq "1")
  {
    $hash->{$DebugMarker . "_IsDisabled"}                       = $hash->{helper}{IsDisabled};
    $hash->{$DebugMarker . "_Password"}                         = "\"" . $hash->{helper}{Password} . "\"";
    $hash->{$DebugMarker . "_CheckCommandSupport"}              = $hash->{helper}{CheckCommandSupport};

    $hash->{$DebugMarker . "_Timer_Loop_On"}                    = $hash->{helper}{Timer_Loop_On};
    $hash->{$DebugMarker . "_Timer_Loop_Count"}                 = $hash->{helper}{Timer_Loop_Count};

    $hash->{$DebugMarker . "_Timer_Retry_On"}                   = $hash->{helper}{Timer_Retry_On};
    $hash->{$DebugMarker . "_Timer_Retry_Count"}                = $hash->{helper}{Timer_Retry_Count};

    $hash->{$DebugMarker . "_RequestCount"}                     = $hash->{helper}{RequestCount};
    $hash->{$DebugMarker . "_ResponseCount"}                    = $hash->{helper}{ResponseCount};
    $hash->{$DebugMarker . "_ResponseAverageTimespan"}          = $hash->{helper}{ResponseAverageTimespan};
    $hash->{$DebugMarker . "_ResponseCount_Success"}            = $hash->{helper}{ResponseCount_Success};
    $hash->{$DebugMarker . "_ResponseCount_Error"}              = $hash->{helper}{ResponseCount_Error};
    $hash->{$DebugMarker . "_ResponseCount_Dropped"}            = $hash->{helper}{ResponseCount_Dropped};

    for(my $leftRetries = 0; $leftRetries <= $hash->{RETRIES}; $leftRetries++)
    { 
      my $retrystring = $ResponseCountSuccessRetry . $leftRetries;
      $hash->{$DebugMarker . "_" . $retrystring}              = $hash->{helper}{$retrystring};
    }
    
    my $cmdTable = $hash->{helper}{CMD};
    foreach my $key (keys %$cmdTable)
    {
      $hash->{$DebugMarker . "_" . $key} = $hash->{helper}{CMD}{$key} 
    } 

    my $dbgTable = $hash->{helper}{Dbg};
    foreach my $key (keys %$dbgTable)
    {
      $hash->{$DebugMarker . "_" . $key} = $hash->{helper}{Dbg}{$key} 
    } 
  }
  else
  {
    # delete all keys starting with "DEBUG_"
    my @matching_keys =  grep /$DebugMarker/, keys %$hash;
    foreach (@matching_keys)
    {
      delete $hash->{$_};
    }
  }
}
#####################################
# stopps the internal timer
#####################################
sub RainbirdController_TimerStop($)
{
  my ( $hash ) = @_;
  my $name = $hash->{NAME};

  my $logInfoString = "RainbirdController_TimerStop($name)";

  Log3($name, 4, "$logInfoString: timerStop");

  RemoveInternalTimer($TimerLoopIdentifier);
  RemoveInternalTimer($TimerRetryIdentifier);
  
  $hash->{helper}{Timer_Loop_On}  = 0;
  $hash->{helper}{Timer_Retry_On} = 0;
  RainbirdController_UpdateInternals($hash);
}

#####################################
# (re)starts the internal timer
#####################################
sub RainbirdController_TimerRestart($)
{
  my ( $hash ) = @_;
  my $name = $hash->{NAME};

  my $logInfoString = "RainbirdController_TimerRestart($name)";

#  RainbirdController_TimerStop($hash);

#  if ($hash->{helper}{IsDisabled} ne "0")
#  {
#    readingsSingleUpdate($hash, "state", "disabled", 1);

#    Log3($name, 3, "RainbirdController_TimerRestart($name) - timerRestart: device is disabled");
#    return;
#  } 

#  if (not defined($hash->{helper}{Password}))
#  {
#    readingsSingleUpdate($hash, "state", "no password", 1 );

#    Log3($name, 3, "RainbirdController_TimerRestart($name) - timerRestart: no password");
#    return;
#  } 

  Log3($name, 4, "$logInfoString: timerRestart");

  ### if RainbirdController_Function fails no callback function is called
  ### so reload timer for next try
  #InternalTimer( gettimeofday() + $hash->{RETRYINTERVAL}, \&RainbirdController_TimerRestart, $hash );
  #$hash->{TIMERON} = 1;

  RainbirdController_TimerLoop($hash); 
}

#####################################
# callback function of the internal timer
#####################################
sub RainbirdController_TimerLoop($)
{
  my ( $hash ) = @_;
  my $name = $hash->{NAME};

  my $logInfoString = "RainbirdController_TimerLoop($name)";

  RainbirdController_TimerStop($hash);

  if ($hash->{helper}{IsDisabled} ne "0")
  {
    readingsSingleUpdate($hash, "state", "disabled", 1 );

    Log3($name, 3, "$logInfoString: device is disabled");
    return;
  }
  
  if (not defined($hash->{helper}{Password}))
  {
    readingsSingleUpdate($hash, "state", "no password", 1 );

    Log3($name, 3, "$logInfoString: no password");
    return;
  } 

  Log3($name, 4, "$logInfoString: TimerLoop");

  ### calculate nextInterval
  my $nextInterval = gettimeofday() + $hash->{INTERVAL};

  InternalTimer($nextInterval, sub { RainbirdController_TimerLoop($hash) }, $TimerLoopIdentifier);

  $hash->{helper}{Timer_Loop_Count}++;
  $hash->{helper}{Timer_Loop_On} = 1;
  RainbirdController_UpdateInternals($hash);
  
  RainbirdController_GetDeviceState($hash);
}

#####################################
# gets the dynamic values of the device
#####################################
sub RainbirdController_GetDeviceState($;$)
{
  my ( $hash, $callback ) = @_;
  my $name = $hash->{NAME};

  my $logInfoString = "RainbirdController_GetDeviceState($name)";

  Log3($name, 4, "$logInfoString: GetDeviceState");

  # definition of the callback chain
  # each function calls the given callback in their resultcallback
  
  my $runCallback = sub 
  {
    # if there is a callback then call it
    if(defined($callback))
    {
      Log3($name, 4, "$logInfoString: GetDeviceState callback");
      $callback->();
    }
  };  
  
  ### iterate all available zones
  my $getScheduleCallback = undef;
  my $currentZone = 0;
  $getScheduleCallback = sub 
  {
    $currentZone++;
    if($currentZone <= $hash->{ZONESAVAILABLECOUNT})
    {
      my $zoneGetSchedule = sub { RainbirdController_ZoneGetSchedule($hash, $currentZone, $getScheduleCallback); };
      $zoneGetSchedule->();
    }
    else
    {
      $runCallback->();
    }
  };     

  ## only call $getActiveStation if $getIrrigationState is not supported: 
  ### check-function if CMD_3F (-> GetIrrigationState) support was checked or ist true
  my $CMDSUPPORT_3F_Check = sub {return (!defined($hash->{$CMDSUPPORT_3F}) or $hash->{$CMDSUPPORT_3F} == 1); };
  my $getActiveStation = RainbirdController_CallIfLambda($hash, sub { return !$CMDSUPPORT_3F_Check->() }, \&RainbirdController_GetActiveStation, $getScheduleCallback);
  my $getIrrigationState = RainbirdController_CallIfLambda($hash, sub { return $CMDSUPPORT_3F_Check->() }, \&RainbirdController_GetIrrigationState, $getActiveStation);
  
  my $getSettings = sub { RainbirdController_GetSettings($hash, $getIrrigationState); };
  my $getNetworkStatus = sub { RainbirdController_GetNetworkStatus($hash, $getSettings); };
  my $getWifiParams = sub { RainbirdController_GetWifiParams($hash, $getNetworkStatus); };
  my $getCurrentTime = sub { RainbirdController_GetCurrentTime($hash, $getWifiParams); };
  my $getCurrentDate = sub { RainbirdController_GetCurrentDate($hash, $getCurrentTime); };
  my $getRainSensorState = sub { RainbirdController_GetRainSensorState($hash, $getCurrentDate); };
  my $getRainSensorBypass = sub { RainbirdController_GetRainSensorBypass($hash, $getRainSensorState); };
  my $getCurrentIrrigation = sub { RainbirdController_GetCurrentIrrigation($hash, $getRainSensorBypass); };
  my $getRainDelay = sub { RainbirdController_GetRainDelay($hash, $getCurrentIrrigation); };

  ### static info - only get once:
  ### skipped by RainbirdController_CallIfLambda if condition is false
  my $getModelAndVersion = RainbirdController_CallIfLambda($hash, !defined( $hash->{MODELID} ), \&RainbirdController_GetModelAndVersion, $getRainDelay);
  my $getAvailableZones = RainbirdController_CallIfLambda($hash, !defined($hash->{ZONESAVAILABLE}), \&RainbirdController_GetAvailableZones, $getModelAndVersion);
  my $getSerialNumber = RainbirdController_CallIfLambda($hash, !defined($hash->{SERIALNUMBER}), \&RainbirdController_GetSerialNumber, $getAvailableZones);

  $getSerialNumber->($hash);
}

#####################################
# CallIfLambda
#####################################
sub RainbirdController_CallIfLambda($$$$)
{
  my ( $hash, $condition, $conditionCallback, $callback ) = @_;
  my $name = $hash->{NAME};

  my $lambda = sub
  {
    my $checkedCondition;
    my $conditionType = ref($condition);
    
    ### check if $condition is a function to call or a value
    if($conditionType eq 'CODE')
    {
      $checkedCondition = $condition->();
    }
    else
    {
      $checkedCondition = $condition;
    }

    ### if $condition is true then call $conditionCallback else call $callback 
    if($checkedCondition and
      defined($conditionCallback))
    {
      $conditionCallback->($hash, $callback);
    }
    elsif(defined($callback))
    {
      $callback->($hash);
    }
  };
  return $lambda;
}

#####################################
# GetModelAndVersion
#####################################
sub RainbirdController_GetModelAndVersion($;$)
{
  my ( $hash, $callback ) = @_;
  my $name = $hash->{NAME};
    
  my $logInfoString = "RainbirdController_GetModelAndVersion($name)";

  my $command = "ModelAndVersion";
  
  Log3($name, 4, "$logInfoString: GetModelAndVersion");

  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3($name, 4, "$logInfoString: GetModelAndVersion resultCallback");
    
    if (defined($result) )
    {
      readingsBeginUpdate($hash);

      if (defined($result->{"modelID"}) )
      {
        my $modelId = $result->{"modelID"};

        $hash->{ModelID} = $modelId;
        
        my $model = $KnownModels{$modelId}[0];

        ### set known model name
        if (defined($model) )
        {
          $hash->{Model} = $model;
        }
        else
        {
          $hash->{Model} = "unknown";
        }
      }

      if (defined($result->{"protocolRevisionMajor"}) )
      {
        $hash->{Model_RevisionMajor} = $result->{"protocolRevisionMajor"};
      }

      if (defined($result->{"protocolRevisionMinor"}) )
      {
        $hash->{Model_RevisionMinor} = $result->{"protocolRevisionMinor"};
      }

      readingsEndUpdate($hash, 1);
    }

    # if there is a callback then call it
    if (defined($callback) )
    {
      Log3($name, 4, "$logInfoString: GetModelAndVersion callback");
      $callback->();
    }
  }; 
    
  # send command
  RainbirdController_Command($hash, $resultCallback, $command );
}

#####################################
# GetAvailableZones
#####################################
sub RainbirdController_GetAvailableZones($;$)
{
  my ( $hash, $callback ) = @_;
  my $name = $hash->{NAME};
  
  my $logInfoString = "RainbirdController_GetAvailableZones($name)";

  my $command = "AvailableStations";   
  my $mask = sprintf("%%0%dX", $ControllerResponses{"83"}->{12}->{"setStations"}->{"length"});

  Log3($name, 4, "$logInfoString: GetAvailableZones mask: $mask");
  
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3($name, 4, "$logInfoString: GetAvailableZones lambda");
    
    if (defined($result) )
    {
      readingsBeginUpdate($hash);

      if (defined($result->{"setStations"}) )
      {
        my $zonesAvailableCount = RainbirdController_GetAvailableZoneCountFromRaw($result->{"setStations"});
        my $zonesAvailableMask = RainbirdController_GetAvailableZoneMaskFromRaw($result->{"setStations"});

        $hash->{ZONESAVAILABLE}       = 1;
        $hash->{ZONESAVAILABLECOUNT}  = $zonesAvailableCount;
        $hash->{ZONESAVAILABLEMASK}   = $zonesAvailableMask;

        #readingsBulkUpdate($hash, 'zonesAvailable', $zonesAvailableCount);
      }
      if (defined($result->{"pageNumber"}) )
      {
        # readingsBulkUpdate($hash, 'pageNumber', $result->{"pageNumber"}, 1 );
      }

      readingsEndUpdate($hash, 1);

      ### encode $result to json string
      my $jsonString = eval{encode_json($result)};

      if($@)
      {
        Log3($name, 2, "$logInfoString: error while request: $@");
      }
      else
      {
        # dispatch to RainbirdZone::RainbirdZone_Parse()
        Dispatch( $hash, $jsonString );
      }
    }

    # if there is a callback then call it
    if (defined($callback) )
    {
      Log3($name, 4, "$logInfoString: GetAvailableZones callback");
      $callback->();
    }
  }; 
    
  # send command
  RainbirdController_Command($hash, $resultCallback, $command, $DEFAULT_PAGE );
}

#####################################
# GetCommandSupport
#####################################
sub RainbirdController_GetCommandSupport($$;$)
{
  my ( $hash, $askCommand, $callback ) = @_;
  my $name = $hash->{NAME};
  
  my $logInfoString = "RainbirdController_GetCommandSupport($name)";

  my $command = "CommandSupport";
     
  Log3($name, 4, "$logInfoString: GetCommandSupport");

  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3($name, 4, "$logInfoString: GetCommandSupport lambda");
    
    if (defined($result))
    {
      if (defined($result->{"support"}) and
        defined($result->{"commandEcho"}))
      {
        my $cmdKey = $CMDSUPPORTPREFIX . $result->{"commandEcho"} . $CMDSUPPORTPOSTFIX;
        $hash->{helper}{CMD}{$cmdKey} = "" . $result->{"support"};
      }
    }

    # if there is a callback then call it
    if (defined($callback) )
    {
      Log3($name, 4, "$logInfoString: GetCommandSupport callback");
      $callback->();
    }
  }; 
  
  ### check if value start with 0x  
  my $commandValue = hex("0x" . lc $askCommand);
  # Log3($name, 4, "RainbirdController_GetCommandSupport($name) - GetCommandSupport hex $askCommand: $commandValue");
  
  if ($hash->{helper}{CheckCommandSupport} eq "1")
  {
    # send command
    RainbirdController_Command($hash, $resultCallback, $command, $commandValue );
  }
  else
  {
    my $cmdKey = $CMDSUPPORTPREFIX . $askCommand . $CMDSUPPORTPOSTFIX;
    $hash->{helper}{CMD}{$cmdKey} = $NotCheckedValue;

    # if there is a callback then call it
    if (defined($callback) )
    {
      Log3($name, 4, "$logInfoString: GetCommandSupport callback");
      $callback->();
    }
  }
}

#####################################
# RainbirdController_GetWaterBudget
#####################################
sub RainbirdController_GetWaterBudget($$;$)
{
  my ( $hash, $budget, $callback ) = @_;
  my $name = $hash->{NAME};
    
  my $logInfoString = "RainbirdController_GetWaterBudget($name)";

  my $command = "GetWaterBudget";
  
  Log3($name, 4, "$logInfoString: GetWaterBudget");
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3($name, 4, "$logInfoString: GetWaterBudget lambda");
    
    if (defined($result) )
    {
      readingsBeginUpdate($hash);

      if (defined($result->{"programCode"}) )
      {
        readingsBulkUpdate($hash, 'programCode', $result->{"programCode"}, 1 );
      }
      if (defined($result->{"seasonalAdjust"}) )
      {
        readingsBulkUpdate($hash, 'seasonalAdjust', $result->{"seasonalAdjust"}, 1 );
      }

      readingsEndUpdate($hash, 1);
    }

    # if there is a callback then call it
    if (defined($callback) )
    {
      Log3($name, 4, "$logInfoString: GetWaterBudget callback");
      $callback->();
    }
  }; 
    
  # send command
  RainbirdController_Command($hash, $resultCallback, $command, $budget );
}

#####################################
# GetSerialNumber
#####################################
sub RainbirdController_GetSerialNumber($;$)
{
  my ( $hash, $callback ) = @_;
  my $name = $hash->{NAME};
    
  my $logInfoString = "RainbirdController_GetSerialNumber($name)";

  my $command = "SerialNumber";
  
  Log3($name, 4, "$logInfoString: GetSerialNumber");
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3($name, 4, "$logInfoString: GetSerialNumber lambda");
    
    if (defined($result) )
    {
      readingsBeginUpdate($hash);

      if (defined($result->{"serialNumber"}) )
      {
        $hash->{SERIALNUMBER} = sprintf("%08s", $result->{"serialNumber"});
      }

      readingsEndUpdate($hash, 1);
    }

    # if there is a callback then call it
    if (defined($callback) )
    {
      Log3($name, 4, "$logInfoString: GetSerialNumber callback");
      $callback->();
    }
  }; 
    
  # send command
  RainbirdController_Command($hash, $resultCallback, $command );
}

#####################################
# GetCurrentTime
#####################################
sub RainbirdController_GetCurrentTime($;$)
{
  my ( $hash, $callback ) = @_;
  my $name = $hash->{NAME};
    
  my $logInfoString = "RainbirdController_GetCurrentTime($name)";

  my $command = "CurrentTimeGet";
  
  Log3($name, 4, "$logInfoString: GetCurrentTime");
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3($name, 4, "$logInfoString: GetCurrentTime lambda");
    
    if (defined($result) )
    {
      readingsBeginUpdate($hash);

      if (defined($result->{"hour"}) and
        defined($result->{"minute"}) and
        defined($result->{"second"}) )
      {
        readingsBulkUpdate($hash, 'InternalTime', sprintf("%02s:%02s:%02s", $result->{"hour"}, $result->{"minute"}, $result->{"second"}), 1 );
      }

      readingsEndUpdate($hash, 1);
    }

    # if there is a callback then call it
    if (defined($callback))
    {
      Log3($name, 4, "$logInfoString: GetCurrentTime callback");
      $callback->();
    }
  }; 
    
  # send command
  RainbirdController_Command($hash, $resultCallback, $command );
}

#####################################
# SetCurrentTime
#####################################
sub RainbirdController_SetCurrentTime($$$$;$)
{
  my ( $hash, $hour, $minute, $second, $callback ) = @_;
  my $name = $hash->{NAME};
    
  my $logInfoString = "RainbirdController_SetCurrentTime($name)";

  my $command = "CurrentTimeSet";
  
  Log3($name, 4, "$logInfoString: SetCurrentTime: $hour:$minute:$second");
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3($name, 4, "$logInfoString: SetCurrentTime lambda");
    
    if (defined($result) )
    {
      readingsBeginUpdate($hash);

      readingsEndUpdate($hash, 1);
    }

    # update reading
    RainbirdController_GetCurrentTime($hash, $callback);
  }; 
    
  # send command
  RainbirdController_Command($hash, $resultCallback, $command, $hour, $minute, $second );
}

#####################################
# GetCurrentDate
#####################################
sub RainbirdController_GetCurrentDate($;$)
{
  my ( $hash, $callback ) = @_;
  my $name = $hash->{NAME};
  
  my $logInfoString = "RainbirdController_GetCurrentDate($name)";

  my $command = "CurrentDateGet";
     
  Log3($name, 4, "$logInfoString: GetCurrentDate");
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3($name, 4, "$logInfoString: GetCurrentDate lambda");
    
    if (defined($result) )
    {
      readingsBeginUpdate($hash);

      if (defined($result->{"year"}) and
        defined($result->{"month"}) and
        defined($result->{"day"}) )
      {
        readingsBulkUpdate($hash, 'InternalDate', sprintf("%04s-%02s-%02s", $result->{"year"}, $result->{"month"}, $result->{"day"}), 1 );
      }

      readingsEndUpdate($hash, 1);
    }

    # if there is a callback then call it
    if (defined($callback) )
    {
      Log3($name, 4, "$logInfoString: GetCurrentDate callback");
      $callback->();
    }
  }; 
    
  # send command
  RainbirdController_Command($hash, $resultCallback, $command );
}

#####################################
# SetCurrentDate
#####################################
sub RainbirdController_SetCurrentDate($$$$;$)
{
  my ( $hash, $year, $month, $day, $callback ) = @_;
  my $name = $hash->{NAME};
    
  my $logInfoString = "RainbirdController_SetCurrentDate($name)";

  my $command = "CurrentDateSet";
  
  Log3($name, 4, "$logInfoString: SetCurrentDate: $year-$month-$day");
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3($name, 4, "$logInfoString: SetCurrentDate lambda");
    
    if (defined($result) )
    {
      readingsBeginUpdate($hash);

      readingsEndUpdate($hash, 1);
    }

    # update reading
    RainbirdController_GetCurrentDate($hash, $callback);
  }; 
    
  # send command
  RainbirdController_Command($hash, $resultCallback, $command,  $day, $month, $year );
}

#####################################
# GetCurrentIrrigation
#####################################
sub RainbirdController_GetCurrentIrrigation($;$)
{
  # seems not to work: always return a value of "1"

  my ( $hash, $callback ) = @_;
  my $name = $hash->{NAME};
  
  my $logInfoString = "RainbirdController_GetCurrentIrrigation($name)";

  my $command = "CurrentIrrigationState";
  
  Log3($name, 4, "$logInfoString: GetCurrentIrrigation");
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3($name, 4, "$logInfoString: GetCurrentIrrigation lambda");
    
    if (defined($result) )
    {
      readingsBeginUpdate($hash);

      if (defined($result->{"irrigationState"}))
      {
        readingsBulkUpdate($hash, 'IrrigationState', $result->{"irrigationState"}, 1 );
      }

      readingsEndUpdate($hash, 1);
    }

    # if there is a callback then call it
    if (defined($callback) )
    {
      Log3($name, 4, "$logInfoString: GetCurrentIrrigation callback");
      $callback->();
    }
  }; 
    
  # send command
  RainbirdController_Command($hash, $resultCallback, $command );
}

#####################################
# GetActiveStation
#####################################
sub RainbirdController_GetActiveStation($;$)
{
  my ( $hash, $callback ) = @_;
  my $name = $hash->{NAME};
    
  my $logInfoString = "RainbirdController_GetActiveStation($name)";

  my $command = "CurrentStationsActive";
  my $mask = sprintf("%%0%dX", $ControllerResponses{"BF"}->{12}->{"activeStations"}->{"length"});

  Log3($name, 4, "$logInfoString: GetActiveStation mask: $mask");
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3($name, 4, "$logInfoString: GetActiveStation lambda");
    
    if (defined($result) )
    {
      readingsBeginUpdate($hash);

      if (defined($result->{"activeStations"}))
      {
        my $zoneActive = RainbirdController_GetZoneFromRaw($result->{"activeStations"});
        my $zoneActiveMask = 1 << ($zoneActive - 1);

        $hash->{ZONEACTIVE} = $zoneActive;
        $hash->{ZONEACTIVEMASK} = $zoneActiveMask;
        
        readingsBulkUpdate($hash, 'ZoneActive', $zoneActive);

        if ($zoneActive == 0 )
        {
          readingsBulkUpdate($hash, "state", 'ready', 1 );
        }
        else
        {
          readingsBulkUpdate($hash, "state", 'irrigating', 1 );
        }  
      }

      readingsEndUpdate($hash, 1);

      ### encode $result to json string
      my $jsonString = eval{encode_json($result)};

      if($@)
      {
        Log3($name, 2, "$logInfoString: GetActiveStation error while request: $@");
      }
      else
      {
        # dispatch to RainbirdZone::RainbirdZone_Parse()
        Dispatch( $hash, $jsonString );
      }
    }

    # if there is a callback then call it
    if (defined($callback) )
    {
      Log3($name, 4, "$logInfoString: GetActiveStation callback");
      $callback->();
    }
  }; 
    
  # send command
  RainbirdController_Command($hash, $resultCallback, $command, $DEFAULT_PAGE );
}

#####################################
# GetIrrigationState
#####################################
sub RainbirdController_GetIrrigationState($;$)
{
  my ( $hash, $callback ) = @_;
  my $name = $hash->{NAME};
    
  my $logInfoString = "RainbirdController_GetIrrigationState($name)";

  my $command = "GetIrrigationState";

  Log3($name, 4, "$logInfoString: GetIrrigationState");
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    # "BB" => {"length" =>  10, "type" => "GetIrrigationStateResponse", 
    #   "unknown2" => {"position" => 2, "length" => 2},
    #   "unknown4" => {"position" => 4, "length" => 2},
    #   "unknown6" => {"position" => 6, "length" => 2},
    #   "unknown8" => {"position" => 8, "length" => 2},
    #   "unknown10" => {"position" => 10, "length" => 2},
    #   "activeZone" => {"position" => 12, "length" => 2},
    #   "unknown14" => {"position" => 14, "length" => 2},
    #   "secondsLeft" => {"position" => 16, "length" => 4},
    # },

    my ( $result, $sendData ) = @_;
    
    Log3($name, 4, "$logInfoString: GetIrrigationState lambda");
    
    if (defined($result) )
    {
      readingsBeginUpdate($hash);

      if (defined($result->{"activeZone"}))
      {
        my $zoneActive = $result->{"activeZone"};
        my $zoneActiveMask = 1 << ($zoneActive - 1);
        
        $hash->{ZONEACTIVE} = $zoneActive;
        $hash->{ZONEACTIVEMASK} = $zoneActiveMask;
        
        readingsBulkUpdate($hash, 'ZoneActive', $zoneActive);

        if ($zoneActive == 0 )
        {
          readingsBulkUpdate($hash, "state", 'ready', 1 );
        }
        else
        {
          readingsBulkUpdate($hash, "state", 'irrigating', 1 );
        }  
      }

      if (defined($result->{"secondsLeft"}))
      {
        my $secondsLeft = $result->{"secondsLeft"};
        $hash->{ZONEACTIVESECONDSLEFT} = $secondsLeft;
        
        readingsBulkUpdate($hash, 'IrrigationSecondsLeft', $secondsLeft, 1 );
      }

      readingsEndUpdate($hash, 1);

      # save result hash in helper
      $hash->{helper}{'IrrigationState'} = $result;

      ### encode $result to json string
      my $jsonString = eval{encode_json($result)};

      if($@)
      {
        Log3($name, 2, "$logInfoString: GetIrrigationState error while request: $@");
      }
      else
      {
        # dispatch to RainbirdZone::RainbirdZone_Parse()
        Dispatch( $hash, $jsonString );
      }
    }

    # if there is a callback then call it
    if (defined($callback) )
    {
      Log3($name, 4, "$logInfoString: GetIrrigationState callback");
      $callback->();
    }
  }; 
    
  # send command
  RainbirdController_Command($hash, $resultCallback, $command, $DEFAULT_PAGE );
}

#####################################
# GetRainDelay
#####################################
sub RainbirdController_GetRainDelay($;$)
{
  my ( $hash, $callback ) = @_;
  my $name = $hash->{NAME};
    
  my $logInfoString = "RainbirdController_GetRainDelay($name)";

  my $command = "RainDelayGet";
  
  Log3($name, 4, "$logInfoString: GetRainDelay");
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3($name, 4, "$logInfoString: GetRainDelay lambda");
    
    if (defined($result) )
    {
      readingsBeginUpdate($hash);

      if (defined($result->{"delaySetting"}) )
      {
        readingsBulkUpdate($hash, 'RainDelay', $result->{"delaySetting"}, 1 );
      }

      readingsEndUpdate($hash, 1);
    }

    # if there is a callback then call it
    if (defined($callback) )
    {
      Log3($name, 4, "$logInfoString: GetRainDelay callback");
      $callback->();
    }
  }; 
    
  # send command
  RainbirdController_Command($hash, $resultCallback, $command );
}

#####################################
# SetRainDelay
#####################################
sub RainbirdController_SetRainDelay($$;$)
{
  my ( $hash, $days, $callback ) = @_;
  my $name = $hash->{NAME};
  
  my $logInfoString = "RainbirdController_SetRainDelay($name)";

  my $command = "RainDelaySet";
    
  Log3($name, 4, "$logInfoString: SetRainDelay for $days days");
    
  ## check parameter
  if (not defined($days) )
  {
  	return "parameter \"days\" not set!";
  }
  elsif($days < 0)
  {
  	return "parameter \"days\" must not be smaller than zero days!";
  }
  elsif($days > 20)
  {
    return "parameter \"days\" must not be greater than 14 days!";
  }
  
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3($name, 4, "$logInfoString: SetRainDelay lambda");
    
    if (defined($result) )
    {
      readingsBeginUpdate($hash);

      readingsEndUpdate($hash, 1);
    }

    # update reading
    RainbirdController_GetRainDelay($hash, $callback);
  }; 
    
  # send command
  RainbirdController_Command($hash, $resultCallback, $command, $days );
}

#####################################
# GetRainSensorState
#####################################
sub RainbirdController_GetRainSensorState($;$)
{
  my ( $hash, $callback ) = @_;
  my $name = $hash->{NAME};
  
  my $logInfoString = "RainbirdController_GetRainSensorState($name)";

  my $command = "CurrentRainSensorState";
  
  Log3($name, 4, "$logInfoString: GetRainSensorState");
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3($name, 4, "$logInfoString: GetRainSensorState lambda");
    
    if (defined($result) )
    {
      readingsBeginUpdate($hash);

      if (defined($result->{"sensorState"}) )
      {
        readingsBulkUpdate($hash, 'RainSensorState', $result->{"sensorState"}, 1 );
      }

      readingsEndUpdate($hash, 1);
    }

    # if there is a callback then call it
    if (defined($callback) )
    {
      Log3($name, 4, "$logInfoString: GetRainSensorState callback");
      $callback->();
    }
  }; 
    
  # send command
  RainbirdController_Command($hash, $resultCallback, $command );
}

#####################################
# GetRainSensorBypass
#####################################
sub RainbirdController_GetRainSensorBypass($;$)
{
  my ( $hash, $callback ) = @_;
  my $name = $hash->{NAME};

  my $logInfoString = "RainbirdController_GetRainSensorBypass($name)";

  my $command = "GetRainSensorBypass";
  my $onoff;
    
  Log3($name, 4, "$logInfoString: GetRainSensorBypass");
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3($name, 4, "$logInfoString: GetRainSensorBypass lambda");
    
    if (defined($result) )
    {
      readingsBeginUpdate($hash);

      if (defined($result->{"bypass"}) )
      {
        readingsBulkUpdate($hash, 'RainSensorBypass', $result->{"bypass"}, 1 );
      }

      readingsEndUpdate($hash, 1);
    }

    # if there is a callback then call it
    if (defined($callback) )
    {
      Log3($name, 4, "$logInfoString: GetRainSensorBypass callback");
      $callback->();
    }
  }; 
    
  # send command
  RainbirdController_Command($hash, $resultCallback, $command, 0 );
}

#####################################
# SetRainSensorBypass
#####################################
sub RainbirdController_SetRainSensorBypass($$;$)
{
  my ( $hash, $value, $callback ) = @_;
  my $name = $hash->{NAME};

  my $logInfoString = "RainbirdController_SetRainSensorBypass($name)";

  my $command = "SetRainSensorBypass";
  my $onoff;
    
  if(defined($value) and
    (($value eq 'on') or
    $value != 0))
  {
    $onoff = 0x00;
  }
  else
  {
    $onoff = 0x80;
  }
    
  Log3($name, 4, "$logInfoString: SetRainSensorBypass");
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3($name, 4, "$logInfoString: SetRainSensorBypass lambda");
    
    if (defined($result) )
    {
      readingsBeginUpdate($hash);

      readingsEndUpdate($hash, 1);
    }

    # update reading activeStations
    RainbirdController_GetRainSensorBypass($hash, $callback);
  }; 
    
  # send command
  RainbirdController_Command($hash, $resultCallback, $command, 0, $onoff );
}

#####################################
# ZoneIrrigate
#####################################
sub RainbirdController_ZoneIrrigate($$$;$)
{
  my ( $hash, $zone, $minutes, $callback ) = @_;
  my $name = $hash->{NAME};
  
  my $logInfoString = "RainbirdController_ZoneIrrigate($name)";

  my $command = "ManuallyRunStation";
    
  Log3($name, 4, "$logInfoString: ZoneIrrigate[$zone]");
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3($name, 4, "$logInfoString: ZoneIrrigate[$zone] lambda");
    
    if (defined($result) )
    {
      readingsBeginUpdate($hash);

      readingsEndUpdate($hash, 1);
    }

    # update reading activeStations
    RainbirdController_GetActiveStation($hash, $callback);
  }; 
    
  # send command
  RainbirdController_Command($hash, $resultCallback, $command, $zone, $minutes );
}

#####################################
# ZoneGetSchedule
#####################################
sub RainbirdController_ZoneGetSchedule($$;$)
{
  my ( $hash, $zone, $callback ) = @_;
  my $name = $hash->{NAME};
  
  my $logInfoString = "RainbirdController_ZoneGetSchedule($name)";

  my $command = "GetSchedule";
    
  Log3($name, 4, "$logInfoString: ZoneGetSchedule[$zone]");
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3($name, 4, "$logInfoString: ZoneGetSchedule[$zone] lambda");
    
    if (defined($result) )
    {
      readingsBeginUpdate($hash);

      readingsEndUpdate($hash, 1);

      # "A0" => {"length" =>  4, "type" => "GetScheduleResponse", 
      #     "zoneId"           => {"position" =>  2, "length" => 4}, 
      #     "timespan"         => {"position" =>  6, "length" => 2}, 
      #     "timer1"           => {"position" =>  8, "length" => 2, "knownvalues" => {"24:00" => "off"}, "converter" => \&RainbirdController_GetTimeFrom10Minutes},
      #     "timer2"           => {"position" => 10, "length" => 2, "knownvalues" => {"24:00" => "off"}, "converter" => \&RainbirdController_GetTimeFrom10Minutes},
      #     "timer3"           => {"position" => 12, "length" => 2, "knownvalues" => {"24:00" => "off"}, "converter" => \&RainbirdController_GetTimeFrom10Minutes},
      #     "timer4"           => {"position" => 14, "length" => 2, "knownvalues" => {"24:00" => "off"}, "converter" => \&RainbirdController_GetTimeFrom10Minutes}, 
      #     "timer5"           => {"position" => 16, "length" => 2, "knownvalues" => {"24:00" => "off"}, "converter" => \&RainbirdController_GetTimeFrom10Minutes},
      #     "param1"           => {"position" => 18, "length" => 2, "knownvalues" => {"144" => "off"}}, 
      #     "mode"             => {"position" => 20, "length" => 2, "knownvalues" => {"0" => "user defined", "1" => "odd", "2" => "even", "3" => "zyclic"}}, 
      #     "weekday"          => {"position" => 22, "length" => 2, "converter" => \&RainbirdController_GetWeekdaysFromBitmask}, 
      #     "interval  "       => {"position" => 24, "length" => 2}, 
      #     "intervaldaysleft" => {"position" => 26, "length" => 2}},

      # save result hash in helper
      $hash->{helper}{'Zone' . $result->{zoneId}}{'Schedule'} = $result;

      ### encode $result to json string
      my $jsonString = eval{encode_json($result)};

      if($@)
      {
        Log3($name, 2, "$logInfoString: ZoneGetSchedule[$zone] error while request: $@");
      }
      else
      {
        # dispatch to RainbirdZone::RainbirdZone_Parse()
        Dispatch( $hash, $jsonString );
      }
    }

    # if there is a callback then call it
    if (defined($callback) )
    {
      Log3($name, 4, "$logInfoString: ZoneGetSchedule[$zone] callback");
      $callback->();
    }
  }; 
    
  # send command
  RainbirdController_Command($hash, $resultCallback, $command, $zone );
}

#####################################
# ZoneSetScheduleRAW
#####################################
sub RainbirdController_ZoneSetScheduleRAW($$;$)
{
  my ( $hash, $rawValue, $callback ) = @_;
  my $name = $hash->{NAME};

  my $logInfoString = "RainbirdController_ZoneSetScheduleRAW($name)";

  # rawValue like 0001141E9090909090032B0201

  ### parameter checks 
  if(not defined($rawValue))
  {
    Log3($name, 3, "$logInfoString: ZoneSetSchedule rawValue not defined");
  }
  elsif(length($rawValue) != 26)
  {
    Log3($name, 3, "$logInfoString: ZoneSetSchedule illegal length $rawValue");
  }

  my $zone = substr($rawValue, 2, 2);
  
  my $command = "SetScheduleRAW";
    
  Log3($name, 4, "$logInfoString: ZoneSetSchedule[$zone]");
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3($name, 4, "$logInfoString: ZoneSetSchedule[$zone] lambda");
    
    if (defined($result) )
    {
      readingsBeginUpdate($hash);

      readingsEndUpdate($hash, 1);
    }
    
    RainbirdController_ZoneGetSchedule($hash, $zone, $callback);
  }; 
    
  # send command
  RainbirdController_Command($hash, $resultCallback, $command, $rawValue );
}

#####################################
# ZoneTest
#####################################
sub RainbirdController_ZoneTest($$;$)
{
  my ( $hash, $zone, $callback ) = @_;
  my $name = $hash->{NAME};
  
  my $logInfoString = "RainbirdController_ZoneTest($name)";

  my $command = "TestStations";
    
  Log3($name, 4, "$logInfoString: ZoneTest[$zone]");
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3($name, 4, "$logInfoString: ZoneTest[$zone] lambda");

    if (defined($result) )
    {
      readingsBeginUpdate($hash);

      readingsEndUpdate($hash, 1);
    }

    # if there is a callback then call it
    if (defined($callback) )
    {
      Log3($name, 4, "$logInfoString: ZoneTest[$zone] callback");
      $callback->();
    }
  }; 
    
  # send command
  RainbirdController_Command($hash, $resultCallback, $command, $zone );
}

#####################################
# SetProgram
#####################################
sub RainbirdController_SetProgram($$;$)
{
  my ( $hash, $program, $callback ) = @_;
  my $name = $hash->{NAME};
  
  my $logInfoString = "RainbirdController_SetProgram($name)";

  my $command = "ManuallyRunProgram";
    
  Log3($name, 4, "$logInfoString: SetProgram");
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3($name, 4, "$logInfoString: SetProgram lambda");
    
    if (defined($result) )
    {
      readingsBeginUpdate($hash);

      readingsEndUpdate($hash, 1);
    }

    # update reading activeStations
    RainbirdController_GetActiveStation($hash, $callback);
  }; 
    
  # send command
  RainbirdController_Command($hash, $resultCallback, $command, $program );
}

#####################################
# StopIrrigation
#####################################
sub RainbirdController_StopIrrigation($;$)
{
  my ( $hash, $callback ) = @_;
  my $name = $hash->{NAME};
  
  my $logInfoString = "RainbirdController_StopIrrigation($name)";

  my $command = "StopIrrigation";
    
  Log3($name, 4, "$logInfoString: StopIrrigation");
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3($name, 4, "$logInfoString: StopIrrigation lambda");
    
    if (defined($result) )
    {
      readingsBeginUpdate($hash);

      readingsEndUpdate($hash, 1);
    }

    # update reading activeStations
    RainbirdController_GetActiveStation($hash, $callback);
  }; 
    
  # send command
  RainbirdController_Command($hash, $resultCallback, $command );
}

#####################################
# FactoryReset
#####################################
sub RainbirdController_FactoryReset($;$)
{
  my ( $hash, $callback ) = @_;
  my $name = $hash->{NAME};
  
  my $logInfoString = "RainbirdController_FactoryReset($name)";

  my $command = "FactoryReset";
    
  Log3($name, 4, "$logInfoString: FactoryReset");
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3($name, 4, "$logInfoString: FactoryReset lambda");
    
    if (defined($result) )
    {
      readingsBeginUpdate($hash);

      readingsEndUpdate($hash, 1);
    }

    # if there is a callback then call it
    if (defined($callback) )
    {
      Log3($name, 4, "$logInfoString: FactoryReset callback");
      $callback->();
    }
  }; 
    
  # send command
  RainbirdController_Command($hash, $resultCallback, $command );
}

#####################################
# RainbirdController_GetWifiParams
#####################################
sub RainbirdController_GetWifiParams($;$)
{
  my ( $hash, $callback ) = @_;
  my $name = $hash->{NAME};
  
  my $logInfoString = "RainbirdController_GetWifiParams($name)";

  my $command = "GetWifiParams";
    
  Log3($name, 4, "$logInfoString: GetWifiParams");
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    #     "macAddress":"AA:BB:CC:DD:EE:FF", 
    #     "localIpAddress":"192.168.0.77", 
    #     "localNetmask":"255.255.255.0", 
    #     "localGateway":"192.168.0.1", 
    #     "rssi":-57, "wifiSsid":"MYWLAN", 
    #     "wifiPassword":"password", 
    #     "wifiSecurity":"wpa2-aes", 
    #     "apTimeoutNoLan":20, 
    #     "apTimeoutIdle":20, 
    #     "apSecurity":"unknown", 
    #     "stickVersion":"Rain Bird Stick Rev C/1.63"
    my ( $result, $sendData ) = @_;
    
    Log3($name, 4, "$logInfoString: GetWifiParams lambda");
    
    if (defined($result) )
    {
      readingsBeginUpdate($hash);

      if (defined($result->{"macAddress"}) )
      {
        readingsBulkUpdate($hash, 'Wifi_MacAddress', $result->{"macAddress"}, 1 );
      }
      if (defined($result->{"localIpAddress"}) )
      {
        readingsBulkUpdate($hash, 'Wifi_IpAddress', $result->{"localIpAddress"}, 1 );
      }
      if (defined($result->{"localNetmask"}) )
      {
        readingsBulkUpdate($hash, 'Wifi_Netmask', $result->{"localNetmask"}, 1 );
      }
      if (defined($result->{"localGateway"}) )
      {
        readingsBulkUpdate($hash, 'Wifi_Gateway', $result->{"localGateway"}, 1 );
      }
      if (defined($result->{"rssi"}) )
      {
        readingsBulkUpdate($hash, 'Wifi_rssi', $result->{"rssi"}, 1 );
      }
      if (defined($result->{"wifiSecurity"}) )
      {
        readingsBulkUpdate($hash, 'Wifi_Security', $result->{"wifiSecurity"}, 1 );
      }
      if (defined($result->{"apTimeoutNoLan"}) )
      {
        readingsBulkUpdate($hash, 'Wifi_ApTimeoutNoLan', $result->{"apTimeoutNoLan"}, 1 );
      }
      if (defined($result->{"apTimeoutIdle"}) )
      {
        readingsBulkUpdate($hash, 'Wifi_ApTimeoutIdle', $result->{"apTimeoutIdle"}, 1 );
      }
      if (defined($result->{"stickVersion"}) )
      {
        readingsBulkUpdate($hash, 'Wifi_StickVersion', $result->{"stickVersion"}, 1 );
      }

      readingsEndUpdate($hash, 1);
    }

    # if there is a callback then call it
    if (defined($callback) )
    {
      Log3($name, 4, "$logInfoString: GetWifiParams callback");
      $callback->();
    }
  }; 
    
  # send command
  RainbirdController_Command($hash, $resultCallback, $command );
}

#####################################
# RainbirdController_GetNetworkStatus
#####################################
sub RainbirdController_GetNetworkStatus($;$)
{
  my ( $hash, $callback ) = @_;
  my $name = $hash->{NAME};

  my $logInfoString = "RainbirdController_GetNetworkStatus($name)";
  
  my $command = "GetNetworkStatus";
    
  Log3($name, 4, "$logInfoString: GetNetworkStatus");
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    # {
    #   "jsonrpc": "2.0",
    #   "result":
    #   {
    #     "networkUp":true, 
    #     "internetUp":true
    #   }, 
    #   "id": 30
    # }     

    my ( $result, $sendData ) = @_;
    
    Log3($name, 4, "$logInfoString: GetNetworkStatus lambda");
    
    if (defined($result) )
    {
      readingsBeginUpdate($hash);

      if (defined($result->{"networkUp"}) )
      {
        readingsBulkUpdate($hash, 'NetworkUp', $result->{"networkUp"}, 1 );
      }
      if (defined($result->{"internetUp"}) )
      {
        readingsBulkUpdate($hash, 'InternetUp', $result->{"internetUp"}, 1 );
      }

      readingsEndUpdate($hash, 1);
    }

    # if there is a callback then call it
    if (defined($callback) )
    {
      Log3($name, 4, "$logInfoString: GetNetworkStatus callback");
      $callback->();
    }
  }; 
    
  # send command
  RainbirdController_Command($hash, $resultCallback, $command );
}

#####################################
# RainbirdController_GetSettings
#####################################
sub RainbirdController_GetSettings($;$)
{
  my ( $hash, $callback ) = @_;
  my $name = $hash->{NAME};
  
  my $logInfoString = "RainbirdController_GetSettings($name)";

  my $command = "GetSettings";
    
  Log3($name, 4, "$logInfoString: GetSettings");
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    # {
    #   "jsonrpc": "2.0",
    #   "result":
    #   {
    #     "country":"DE", 
    #     "code":"12345", 
    #     "globalDisable":false, 
    #     "numPrograms":0, 
    #     "programOptOutMask":"00", 
    #     "SoilTypes": [] , 
    #     "FlowRates": [] , 
    #     "FlowUnits": [] 
    #   }, 
    #   "id": 30
    # }     

    my ( $result, $sendData ) = @_;
    
    Log3($name, 4, "$logInfoString: GetSettings lambda");
    
    if (defined($result) )
    {
      readingsBeginUpdate($hash);

      if (defined($result->{"country"}) )
      {
        readingsBulkUpdate($hash, 'SettingCountry', $result->{"country"}, 1 );
      }
      if (defined($result->{"code"}) )
      {
        readingsBulkUpdate($hash, 'SettingCode', $result->{"code"}, 1 );
      }
      if (defined($result->{"globalDisable"}) )
      {
        readingsBulkUpdate($hash, 'SettingGlobalDisable', $result->{"globalDisable"}, 1 );
      }
      if (defined($result->{"numPrograms"}) )
      {
        readingsBulkUpdate($hash, 'SettingNumPrograms', $result->{"numPrograms"}, 1 );
      }
      if (defined($result->{"programOptOutMask"}) )
      {
        readingsBulkUpdate($hash, 'SettingProgramOptOutMask', $result->{"programOptOutMask"}, 1 );
      }

      readingsEndUpdate($hash, 1);
    }

    # if there is a callback then call it
    if (defined($callback) )
    {
      Log3($name, 4, "$logInfoString: GetSettings callback");
      $callback->();
    }
  }; 
    
  # send command
  RainbirdController_Command($hash, $resultCallback, $command );
}

#####################################
# TestCMD
#####################################
sub RainbirdController_TestCMD($$$;$)
{
  my ( $hash, $command, $args, $callback ) = @_;
  my $name = $hash->{NAME};
  
  my $logInfoString = "RainbirdController_TestRAW($name)";

  Log3($name, 4, "$logInfoString: TestCMD");
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3($name, 4, "$logInfoString: TestCMD lambda");
    
    if (defined($result) )
    {
      readingsBeginUpdate($hash);

      readingsBulkUpdate($hash, 'testCMDResult', encode_json($result), 1 );

      readingsEndUpdate($hash, 1);
    }

    # if there is a callback then call it
    if (defined($callback) )
    {
      Log3($name, 4, "$logInfoString: TestCMD callback");
      $callback->();
    }
  }; 
    
  # send command
  RainbirdController_Command($hash, $resultCallback, $command, @{$args} );
}

#####################################
# TestRAW
#####################################
sub RainbirdController_TestRAW($$;$)
{
  my ( $hash, $rawHexString, $callback ) = @_;
  my $name = $hash->{NAME};

  my $logInfoString = "RainbirdController_TestRAW($name)";
  
  Log3($name, 4, "$logInfoString: TestRAW");
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3($name, 4, "$logInfoString: TestRAW lambda");
    
    if (defined($result) )
    {
      readingsBeginUpdate($hash);

#      readingsBulkUpdate($hash, 'testRAWSend', encode_json(decode_json($sendData)), 1 );
      readingsBulkUpdate($hash, 'testRAWSend', JSON->new->canonical(1)->pretty->encode(decode_json($sendData)), 1 );
      readingsBulkUpdate($hash, 'testRAWResult',  JSON->new->canonical(1)->pretty->encode($result), 1 );

      readingsEndUpdate($hash, 1);
    }

    # if there is a callback then call it
    if (defined($callback) )
    {
      Log3($name, 4, "$logInfoString: TestRAW callback");
      $callback->();
    }
  }; 
    
  # send command
  my $params = '"data":"' . $rawHexString . '", "length":"' . (length($rawHexString) / 2) . '"';
  RainbirdController_Request($hash, $resultCallback, undef, "RAW", "tunnelSip", $params );
}

#####################################
# GetZoneFromRaw
# Gets the active zone from raw value
#####################################
sub RainbirdController_GetZoneFromRaw($)
{
  my ( $rawintvalue ) = @_;
  
  if(not defined($rawintvalue) or
    $rawintvalue == 0)
  {
    return 0;
  }
  
  ### 01000000 -> Zone 1
  ### 02000000 -> Zone 2
  ### 04000000 -> Zone 3
  ### 08000000 -> Zone 4
  ### 10000000 -> Zone 5
  ### 20000000 -> Zone 6
  ### 40000000 -> Zone 7
  ### 80000000 -> Zone 8
  ### 00010000 -> Zone 9
  ### 00020000 -> Zone 10
  ### 00040000 -> Zone 11
  ### 00080000 -> Zone 12
  ### 00100000 -> Zone 13
  ### 00200000 -> Zone 14
  ### 00400000 -> Zone 15
  ### 00800000 -> Zone 16
  
  ### 08000000 -> 00000080 -> Zone 4
    
  my $bytes = pack('H*', sprintf("%08X", $rawintvalue));
  my @n = unpack('V*', $bytes);
  my $zoneBit = $n[0];
  my $zone = log($zoneBit)/log(2);
  return int($zone + 1);
}

#####################################
# GetAvailableZoneCountFromRaw
# Gets the number of available zones from raw value
#####################################
sub RainbirdController_GetAvailableZoneCountFromRaw($)
{
  my ( $rawintvalue ) = @_;

  ### FF000000 -> ZonesAvailable: 8
  ### FFFF0000 -> ZonesAvailable: 16
  
  if(not defined($rawintvalue) or
    $rawintvalue == 0)
  {
    return 0;
  }
  
  my $bitcount = 0;
  while ($rawintvalue) 
  {
    $bitcount += $rawintvalue&1;
    $rawintvalue /= 2;
  }
  
  return $bitcount;
}

#####################################
# GetAvailableZoneMaskFromRaw
# Gets the bitmask with available zones from raw value
#####################################
sub RainbirdController_GetAvailableZoneMaskFromRaw($)
{
  my ( $rawintvalue ) = @_;

  ### FF000000 -> ZonesAvailable: 8  -> 000000FF 
  ### FFFF0000 -> ZonesAvailable: 16 -> 0000FFFF
  
  if(not defined($rawintvalue) or
    $rawintvalue == 0)
  {
    return 0;
  }
  
  my $bytes = pack('H*', sprintf("%08X", $rawintvalue));
  my @n = unpack('V*', $bytes);
  my $zoneBit = $n[0];
  #return sprintf("%08X", $zoneBit);
  return int($zoneBit);
}

#####################################
# Command
#####################################
sub RainbirdController_Command($$$@)
{
  my ( $hash, $resultCallback, $command, @args ) = @_;
  my $name = $hash->{NAME};
 
  my $logInfoString = "RainbirdController_Command($name)";

  Log3($name, 4, "$logInfoString: \"$command\"");
  
  # find controllercommand-structure in hash "ControllerCommands"
  my $request_command = $command . "Request";
  my $command_set = $ControllerCommands{$request_command};

  if ($hash->{helper}{IsDisabled} ne "0")
  {
  }
  elsif (defined($command_set))
  {
    my $method = $command_set->{"method"};

    ### method "tunnelSip"
    if($method eq "tunnelSip")
    {
      my $commandString = $command_set->{"command"};
      my $cmdKey = $CMDSUPPORTPREFIX . $commandString . $CMDSUPPORTPOSTFIX;
      my $debug_command = $commandString . "_" . $command;

      ### check if support of command was checked before
      if (not defined($hash->{helper}{CMD}{$cmdKey}) or
        ($hash->{helper}{CheckCommandSupport} eq "1" and
        $hash->{helper}{CMD}{$cmdKey} eq $NotCheckedValue))
      {
        ### callback - this function has to be recalled
        my $commandCallback = sub { RainbirdController_Command($hash, $resultCallback, $command, @args); };

        ### check support of the command und recall this function 
        RainbirdController_GetCommandSupport($hash, $commandString, $commandCallback);
        return; # callback is handled
      }
      ### command is supported
      elsif ($hash->{helper}{CMD}{$cmdKey} ne "0" or
        $hash->{helper}{CheckCommandSupport} eq "0")
      {
        # encode data
        my $data = RainbirdController_EncodeData($hash, $command_set, @args);  

        if(defined($data))
        {
          my $params = '"data":"' . $data . '", "length":' . (length($data) / 2) . '';
        
          ### send request to device 
          RainbirdController_Request($hash, $resultCallback, $command_set->{"response"}, $debug_command, $method, $params );
          return; # callback is handled
        }
        else
        {
          Log3($name, 2, "$logInfoString: $debug_command - data not defined");
        }
      }
      ### command is not supported
      {
        Log3($name, 2, "$logInfoString: $debug_command - $commandString is not supported");
      }
    }  
    ### method "getWifiParams"
    elsif($method eq "getWifiParams")
    {
       my $params = '';

       ### send request to device 
       RainbirdController_Request($hash, $resultCallback, $command_set->{"response"}, $command, $method, $params );
       return; # callback is handled
    }
    ### method "getNetworkStatus"
    elsif($method eq "getNetworkStatus")
    {
       my $params = '';

       ### send request to device 
       RainbirdController_Request($hash, $resultCallback, $command_set->{"response"}, $command, $method, $params );
       return; # callback is handled
    }
    ### method "getSettings"
    elsif($method eq "getSettings")
    {
       my $params = '';

       ### send request to device 
       RainbirdController_Request($hash, $resultCallback, $command_set->{"response"}, $command, $method, $params );
       return; # callback is handled
    }
    ### method is not supported
    else
    {
      Log3($name, 2, "$logInfoString: $method is not supported");
    }
  }
  else
  {
    Log3($name, 2, "$logInfoString: \"" . $request_command . "\" not found!");
  }

  # is there a callback function?
  if(defined($resultCallback))
  {
    Log3($name, 4, "$logInfoString: calling lambda function");
    
    $resultCallback->(undef, undef);
  } 
}

#####################################
# Request
#####################################
sub RainbirdController_Request($$$$$$)
{
  my ( $hash, $resultCallback, $expectedResponse_id, $command, $dataMethod, $parameters ) = @_;
  my $name = $hash->{NAME};

  my $sendReceive = undef; 
  $sendReceive = sub ($;$)
  {
    my ($leftRetries, $attempt, $retryCallback) = @_;
    
    my $request_id = ++$hash->{REQUESTID};
    
    ### limit request id
    if($request_id >= 65536)
    {
      $hash->{REQUESTID} = 0;
      $request_id = 0;
    }

    my $logInfoString = "RainbirdController_Request($name) Cmd: $command($request_id)";

    my $password = $hash->{helper}{Password};
    
    if(not defined($password))
    {
      Log3($name, 2, "$logInfoString: password not defined");

      ### is there a callback function?
      if(defined($resultCallback))
      {
        Log3($name, 4, "$logInfoString: calling lambda function");
    
        $resultCallback->(undef, undef);
      }
    }

#    my $send_data = 
#    '{
#      "id":' . $request_id . ',
#      "jsonrpc":"2.0",
#      "method":"tunnelSip",
#      "params":
#      {
#        "data":"' . $data . '",
#        "length":"' . (length($data) / 2) . '"
#      }
#    }';
    
    my $send_data = '{"id":' . $request_id . ',"jsonrpc":"2.0","method":"' . $dataMethod . '","params": {' . $parameters . '}}';

    Log3($name, 5, "$logInfoString: send_data: \"$send_data\"");

    ### encrypt data
    my $encrypt_data = RainbirdController_EncryptData($hash, $send_data, $password, $command);

    if($hash->{helper}{Debug} ne "0")
    {
      $hash->{helper}{Dbg}{"Cmd_" . $command . "_REQ"} = $send_data;

      if($hash->{helper}{DebugCrypt} ne "0")
      {
        my $hexString = (sprintf("%v02X", $encrypt_data) =~ s/\.//rg);
  
        my $room = "Rainbird";
        $hash->{helper}{Dbg}{"Cmd_" . $command . "_REQC"} = $hexString;
  #      $hash->{helper}{Dbg}{"Cmd_" . $command . "_REQC"} = "<html><a href=\"/fhem?cmd." . $name . "=get " . $name . " DecryptHEX " . $hexString . "" . $FW_CSRF . "&XHR=1\">" . $hexString . "</a></html>";
      }
      RainbirdController_UpdateInternals($hash);
    }

    if(defined($encrypt_data))
    {
      my $param = {};
      $param->{hash}                = $hash;
      
      $param->{url}                 = "http://" . $hash->{HOST} . "/stick";
      $param->{method}              = "POST";
      $param->{header}              = $HEAD;
      $param->{data}                = $encrypt_data;
      $param->{timeout}             = $hash->{TIMEOUT};
#      $param->{keepalive}           = 0;
#      $param->{noshutdown}          = 0;

      $param->{doTrigger}           = 1,
      $param->{callback}            = \&RainbirdController_ErrorHandling,
    
      $param->{request_id}          = $request_id;
      $param->{request_timestamp}   = gettimeofday();
      
      $param->{expectedResponse_id} = $expectedResponse_id;
      $param->{dataMethod}          = $dataMethod;
      $param->{command}             = $command;
      $param->{sendData}            = $send_data;
      
      $param->{attempt}             = $attempt;
      $param->{leftRetries}         = $leftRetries;
      $param->{retryCallback}       = $retryCallback;
      $param->{resultCallback}      = $resultCallback;

      Log3($name, 5, "$logInfoString: Send with URL: \"$param->{url}\", HEADER: \"$param->{header}\", METHOD: \"$param->{method}\", DATA: \"$param->{data}\"");
  
      $hash->{helper}{RequestCount}++;
      RainbirdController_UpdateInternals($hash);
    
      HttpUtils_NonblockingGet($param);
    }
    else
    {
      Log3($name, 2, "$logInfoString: - data not defined");

      ### is there a callback function?
      if(defined($resultCallback))
      {
        Log3($name, 4, "$logInfoString: calling lambda function");
    
        $resultCallback->(undef, undef);
      }
    }
  };

  $sendReceive->($hash->{RETRIES}, 1, $sendReceive);
}

#####################################
# ErrorHandling
#####################################
sub RainbirdController_ErrorHandling($$$)
{
  my ( $param, $err, $data ) = @_;
  my $hash  = $param->{hash};
  my $name  = $hash->{NAME};
  
  my $request_id                = $param->{request_id};
  my $attempt                   = $param->{attempt};
  my $leftRetries               = $param->{leftRetries};
  my $retryCallback             = $param->{retryCallback};
  my $resultCallback            = $param->{resultCallback};
  my $sendData                  = $param->{sendData};
  my $command                   = $param->{command};

  my $response_timestamp        = gettimeofday();
  my $request_timestamp         = $param->{request_timestamp};
  my $requestResponse_timespan  = $response_timestamp - $request_timestamp;
  my $retryinterval             = $hash->{RETRYINTERVAL};
  my $errorMsg                  = "";
  my $decoded                   = undef;

  my $logInfoString = "RainbirdController_ErrorHandling($name) Cmd: $command($request_id)";

  $hash->{helper}{ResponseCount}++;
  
  #HttpUtils_Close($param);

  ### check if the current callback handles the last request.
  ### else drop...
  if ($request_id != $hash->{REQUESTID})
  {
    $hash->{helper}{ResponseCount_Dropped}++;
    RainbirdController_UpdateInternals($hash);
    
    Log3($name, 3, "$logInfoString: Dropping old response: Current is: $hash->{REQUESTID}");
    return;
  }

  ### check error variable
  if (defined($err) and 
    $err ne "")
  {
    Log3($name, 3, "$logInfoString: Error: $err Data: \"$data\"");
    
    $errorMsg = "error " . $err;
  }
  
  ### check code
  if ($data eq "" and
    exists($param->{code}) and 
    $param->{code} != 200 )
  {
    if ($param->{code} == 403) ### Forbidden
    {
      $errorMsg = "wrong password";
      $leftRetries = 0; # no retry
    }
    elsif ($param->{code} == 420) ### Enhance Your Calm
    {
      $errorMsg = "error " . $param->{code} . " - To many requests - client is blocked for some minutes";
      $leftRetries = 0; # no retry
    }
    elsif ($param->{code} == 503) ### Service Unavailable
    {
      if($retryinterval > 0)
      {
        $errorMsg = "error " . $param->{code} . " - stick is busy, retrying in " . $retryinterval . " seconds";
        readingsSingleUpdate($hash, "state", $errorMsg, 1 );

        if($attempt == 1)
        {
          $leftRetries = 10; # increase number of retries
        }
      }
      else
      {
        $errorMsg = "error " . $param->{code} . " - stick is busy";
        $leftRetries = 0; # no retry
      }
    }
    else
    {
      $errorMsg = "error " . $param->{code};
      $leftRetries = 0; # no retry
    }

    Log3($name, 3, "$logInfoString: Code: $param->{code} LeftRetries: $leftRetries Msg: $errorMsg Data: \"$data\"");
  }

  Log3($name, 5, "$logInfoString: Data: \"$data\"");

  ### no error: process response
  if ($errorMsg eq "")
  {
    my $retrystring = $ResponseCountSuccessRetry . ($hash->{RETRIES} - $leftRetries);
    $hash->{helper}{ResponseCount_Success}++;
    $hash->{helper}{ResponseTotalTimespan} += $requestResponse_timespan;
    $hash->{helper}{ResponseAverageTimespan} = $hash->{helper}{ResponseTotalTimespan} / $hash->{helper}{ResponseCount_Success};
    $hash->{helper}{$retrystring}++;
    RainbirdController_UpdateInternals($hash);

    $decoded = RainbirdController_ResponseProcessing( $param, $data );

    my $decoded_String = encode_json($decoded);

    if(defined($decoded_String) and
      $hash->{helper}{Debug} ne "0")
    {
      $hash->{helper}{Dbg}{"Cmd_" . $command . "_RES_JSON"} = $decoded_String;
      RainbirdController_UpdateInternals($hash);
    }
  }
  ### error: retries left
  elsif (defined($retryCallback) and  # is retryCallback defined
    $leftRetries > 0)                 # are there any left retries
  {
    Log3($name, 5, "$logInfoString: LeftRetries: $leftRetries Msg: $errorMsg");

    if ($retryinterval == 0)
    {
      ### call retryCallback with decremented number of left retries
      $retryCallback->($leftRetries - 1, $attempt + 1, $retryCallback);
    }
    else
    {
      my $nextInterval = gettimeofday() + $retryinterval;
      $hash->{helper}{Timer_Retry_Count}++;
      $hash->{helper}{Timer_Retry_On} = 1;
      RainbirdController_UpdateInternals($hash);

      my $retrySub = sub 
      {
        $hash->{helper}{Timer_Retry_On} = 0;
        RainbirdController_UpdateInternals($hash);
        
        ### call retryCallback with decremented number of left retries
        $retryCallback->($leftRetries - 1, $attempt + 1, $retryCallback) 
      };
  
      RemoveInternalTimer($TimerRetryIdentifier);
      InternalTimer($nextInterval, $retrySub, $TimerRetryIdentifier);
    }
    return; # resultCallback is handled in retry 
  }
  else
  {
    Log3($name, 3, "$logInfoString: no retries left Mad: $errorMsg");

    $hash->{helper}{ResponseCount_Error}++;
    RainbirdController_UpdateInternals($hash);

    readingsSingleUpdate($hash, "state", $errorMsg, 1 );
    return;
  }
  
  # is there a callback function?
  if (defined($resultCallback))
  {
    Log3($name, 4, "$logInfoString: calling lambda function");
    
    $resultCallback->($decoded, $sendData);
  }
}

#####################################
# ResponseProcessing
#####################################
sub RainbirdController_ResponseProcessing($$)
{
  my ($param, $data)      = @_;

  my $hash                = $param->{hash};
  my $name                = $hash->{NAME};
  
  my $request_id          = $param->{request_id};
  my $expectedResponse_id = $param->{expectedResponse_id};
  my $dataMethod          = $param->{dataMethod};
  my $sendData            = $param->{sendData};
  my $command             = $param->{command};

  my $logInfoString = "RainbirdController_ResponseProcessing($name) [ID:$request_id M:$dataMethod Cmd:$command ExpReId:$expectedResponse_id]";

  my $password = $hash->{helper}{Password};
  
  if(not defined($password))
  {
    Log3($name, 2, "$logInfoString: password not defined");
    return undef;
  }

  ### decrypt data
  my $decrypted_data = RainbirdController_DecryptData($hash, $data, $password, $command);
  if(not defined($decrypted_data))
  {
    Log3($name, 2, "$logInfoString: decrypted_data not defined");
    return undef;
  }

  if($hash->{helper}{Debug} ne "0")
  {
    $hash->{helper}{Dbg}{"Cmd_" . $command . "_RES"} = $decrypted_data;
    $hash->{helper}{Dbg}{"Cmd_" . $command . "_Count"}++;

    if($hash->{helper}{DebugCrypt} ne "0")
    {
      $hash->{helper}{Dbg}{"Cmd_" . $command . "_RESC"} = (sprintf("%v02X", $data) =~ s/\.//rg);
    }

    RainbirdController_UpdateInternals($hash);
  }

  ### create structure from json string
  my $decode_json = eval { decode_json($decrypted_data) };

  if ($@)
  {
    Log3($name, 2, "$logInfoString: JSON error while request: $@");
    return undef;
  }
  
  if(not defined( $decode_json ))
  {
    Log3($name, 2, "$logInfoString: no JSON result.data");
    return undef;
  }
  
  if(not defined( $decode_json->{id} or
    not defined( $decode_json->{result} )))
  {
    Log3($name, 2, "$logInfoString: wrong JSON result.data");
    return undef;
  }
 
  ### compare requestId with responseId
  if($request_id ne $decode_json->{id})
  {
    Log3($name, 2, "$logInfoString: request failed with wrong ResponseId! RequestId \"" . $request_id . "\" but got ResponseId \"" . $decode_json->{id} . "\"");
    return undef;
  }
  
  ### "tunnelSip"
  if($dataMethod eq "tunnelSip")
  {
    # $decode_json =
    # {
    #   "jsonrpc": "2.0",
    #   "result":
    #   {
    #     "length":5, 
    #     "data":"8200030209"
    #   }, 
    #   "id": 666
    # }  
    if(not defined( $decode_json->{result}->{data} ))
    {
      Log3($name, 2, "$logInfoString: result data not defined Data:\"$decrypted_data\"");
      return undef;
    }
    
    ### decode data
    my $decoded = RainbirdController_DecodeData($hash, $command, $decode_json->{result}->{data});
  
    if(not defined($decoded))
    {
      Log3($name, 2, "$logInfoString: decoded not defined Data:\"$decrypted_data\"");
      return undef;
    }

    ### response
    my $response_id = $decoded->{"responseId"};

    if(not defined($response_id))
    {
      Log3($name, 2, "$logInfoString: responseId not defined");
      return undef;
    }

    # check id of response message
    if(defined($expectedResponse_id) and
      $response_id ne $expectedResponse_id)  
    {
      if ($response_id eq "00" )
      {
        Log3($name, 2, "$logInfoString: NAKCode \"" . sprintf("%X", $decoded->{"NAKCode"}) . "\" commandEcho \"" . $decoded->{"commandEcho"} . "\"");
      }
      else
      {
        Log3($name, 2, "$logInfoString: Status request failed with wrong response! Expected \"" . $expectedResponse_id . "\" but got \"" . $response_id . "\"");
      }

      return undef;
    }

    return $decoded;
  }
  ### "getWifiParams"
  elsif($dataMethod eq "getWifiParams")
  {
    # {
    #   "jsonrpc": "2.0", 
    #   "result":
    #   {
    #     "macAddress":"AA:BB:CC:DD:EE:FF", 
    #     "localIpAddress":"192.168.0.77", 
    #     "localNetmask":"255.255.255.0", 
    #     "localGateway":"192.168.0.1", 
    #     "rssi":-57, "wifiSsid":"MYWLAN", 
    #     "wifiPassword":"password", 
    #     "wifiSecurity":"wpa2-aes", 
    #     "apTimeoutNoLan":20, 
    #     "apTimeoutIdle":20, 
    #     "apSecurity":"unknown", 
    #     "stickVersion":"Rain Bird Stick Rev C/1.63"
    #   }, 
    #   "id": 29
    # }"
    
    my $decoded = $decode_json->{result};
    return $decoded;
  }
  ### "getNetworkStatus"
  elsif($dataMethod eq "getNetworkStatus")
  {
    # {
    #   "jsonrpc": "2.0",
    #   "result":
    #   {
    #     "networkUp":true, 
    #     "internetUp":true
    #   }, 
    #   "id": 30
    # }
    my $decoded = $decode_json->{result};
    return $decoded;
  }
  ### "getSettings"
  elsif($dataMethod eq "getSettings")
  {
    # {
    #   "jsonrpc": "2.0",
    #   "result":
    #   {
    #     "country":"DE", 
    #     "code":"12345", 
    #     "globalDisable":false, 
    #     "numPrograms":0, 
    #     "programOptOutMask":"00", 
    #     "SoilTypes": [] , 
    #     "FlowRates": [] , 
    #     "FlowUnits": [] 
    #   }, 
    #   "id": 30
    # }     
    my $decoded = $decode_json->{result};
    return $decoded;
  }
  ### not defined
  else
  {
    Log3($name, 2, "$logInfoString: dataMethod \"$dataMethod\" not defined");
    return undef;
  }
}

#####################################
# EncodeData
#####################################
sub RainbirdController_EncodeData($$@)
{
  my ( $hash, $command_set, @args ) = @_;
  my $name = $hash->{NAME};

  my $args_count = scalar (@args); # count of args

  my $logInfoString = "RainbirdController_EncodeData($name)";

  Log3($name, 5, "$logInfoString: encode with $args_count args");

  ### get fields from command_set structure
  my $command_set_code = $command_set->{"command"};
  my $command_set_byteLength = $command_set->{"length"};
  my $command_set_charLength = $command_set_byteLength * 2;
  
  ### put $command_set_code and args array in new params array for sprintf-call
  my @params = ($command_set_code, @args);

  my $arg_placeholders = "";
  my $arg_placeholders_charLength = 2; # first two chars for command
  my $args_found = 0;

  ### if there are any args then find them in the command_set with keyname "parameterX"
  ### and add them to format string arg_placeholder
  for my $index (1..$args_count)
  {
    ### create keyname "parameterX"
    my $keyName = "parameter" . $index;
    
    ### if there is an entry in hash then charLength is defined
    my $parameterEntry = $command_set->{$keyName};
    if(not defined($parameterEntry))
    {
      Log3($name, 3, "$logInfoString: Error \"$keyName\" not found");
      return undef;
    }
    
    my $charLength = $parameterEntry->{"length"};
    if(not defined($charLength))
    {
      Log3($name, 3, "$logInfoString: Error \"$keyName\" length not found");
      return undef;
    }

    Log3($name, 5, "$logInfoString: extend arg_placeholders with keyName: \"" . $keyName . "\" charLength: " . $charLength . " value: \"" . $args[$index - 1] . "\"");

    ### extend arg_placeholder with a format entry for any parameter
    ### the format entry is %H with leading 0s to reach the charlength from command_set
    ### charlength 1: %01X 
    ### charlength 2: %02X 
    ### charlength 3: %03X
    my $formatString = $parameterEntry->{"format"};
    
    if(not defined($formatString))
    {
      $formatString = sprintf("%%0%dX", $charLength);
    }
    
    $arg_placeholders .= $formatString;
    $arg_placeholders_charLength += $charLength;
    $args_found++
  }
  
  Log3($name, 5, "$logInfoString: arg_placeholders \"" . $arg_placeholders . "\" arg_placeholders_charLength: " . $arg_placeholders_charLength . " arg_found: " . $args_found);

  ### check if number of parameters equals to number of entries in dataset
  if($args_found != $args_count)
  {
    Log3($name, 3, "$logInfoString: Error " . $args_count . " parameters given but " . $args_found . " parameters in dataset");
    return undef;
  }
  
  ### check if char lengths matches
  if($command_set_charLength != $arg_placeholders_charLength)
  {
    Log3($name, 3, "$logInfoString: Error charLength: " . $command_set_charLength . " chars given but " . $arg_placeholders_charLength ." chars processed");
    return undef;
  }

  my $result = sprintf("%s" . $arg_placeholders, @params);
  my $result_charLength = length($result);

  Log3($name, 5, "$logInfoString: result: \"$result\"");

  ### check if char lengths matches
  if($command_set_charLength != $result_charLength)
  {
    Log3($name, 3, "$logInfoString: Error charLength: " . $command_set_charLength . " chars given but " . $result_charLength . " chars processed");
    return undef;
  }

  return $result;
}

#####################################
# DecodeData
#####################################
sub RainbirdController_DecodeData($$$)
{
  my ( $hash, $command, $data ) = @_;
  my $name = $hash->{NAME};
  
  my $response_id = substr($data, 0, 2);
  my $logInfoString = "RainbirdController_DecodeData($name) Cmd:$command($response_id)";

  Log3($name, 5, "$logInfoString: Data: \"" . $data . "\"");

  my $responseDataLength = length($data);
  
  my %result = (
    "identifier" => "Rainbird",
    "responseId" => $response_id,
    "responseDataLength" => $responseDataLength,
    "data" => $data,
  );
  

  # find response-structure in hash "ControllerResponses"
  my $responseHash = $ControllerResponses{$response_id};
  
  if (not defined( $responseHash ) )
  {
    Log3($name, 2, "$logInfoString: ControllerResponse \"" . $response_id . "\" not found! Data:\"" . $data . "\"");
  }
  else
  {
    my $cmd_template = $responseHash->{$responseDataLength};
    if (not defined( $cmd_template ) )
    {
      Log3($name, 2, "$logInfoString: ControllerResponse \"" . $response_id . "\" with length \"" . $responseDataLength . "\" not found! Data:\"" . $data . "\"");
    }
    else
    {
      # $cmd_template:
      #  "82" => 
      #  {
      #     "length" => 5, 
      #     "type" => "ModelAndVersionResponse", 
      #     "modelID" => 
      #     {
      #       "position" => 2, 
      #       "length" => 4
      #     },
      #     "protocolRevisionMajor" => 
      #     {
      #       "position" => 6, 
      #       "length" => 2
      #     },
      #     "protocolRevisionMinor" => 
      #     {
      #       "position" => 8, 
      #       "length" => 2
      #     }
      #  },

      $result{"type"} = $cmd_template->{"type"};

      while (my($key, $value) = each(%{$cmd_template})) 
      {
        if(ref($value) eq 'HASH' and
          defined($value->{"position"}) and
          defined($value->{"length"}))
        {
          my $position = $value->{"position"};
          my $length = $value->{"length"};
      
          if($position >= $responseDataLength)
          {
            Log3($name, 3, "$logInfoString: [$key] string to small");
          }
          elsif(($position + $length) > $responseDataLength)
          {
            Log3($name, 3, "$logInfoString:: [$key] string to small");
          }
          else
          {
            my $currentValue = hex(substr($data, $value->{"position"}, $value->{"length"}));

            my $format = $value->{"format"};
            my $knownValues = $value->{"knownvalues"};
            my $converter = $value->{"converter"};

            ### if converter is defined
            if(defined($converter))
            {
              $currentValue = &$converter($currentValue);
            }

            ### if knownValues is defined
            if(defined($knownValues) and
              ref($knownValues) eq 'HASH' and
              defined($knownValues->{"$currentValue"}))
            {
              $currentValue =  $knownValues->{$currentValue};
            }

            ### if format is defined?
            elsif(defined($format) and
              $format ne "")
            {
              $currentValue = sprintf($format, $currentValue);    
            }

            Log3($name, 5, "$logInfoString: insert $key = " . $currentValue);

            $result{$key} = $currentValue;
          }
        }
      }
    }
  }
  
  return \%result;
}

#####################################
# AddPadding
#####################################
sub RainbirdController_AddPadding($$)
{
  my ( $hash, $data ) = @_;
  my $name = $hash->{NAME};

  my $new_Data = $data;
  my $new_Data_len = length($new_Data);
  my $remaining_len = $BLOCK_SIZE - $new_Data_len;
  my $to_pad_len = $remaining_len % $BLOCK_SIZE;
  my $pad_string = $PAD x $to_pad_len;
  my $result = $new_Data . $pad_string;

  Log3($name, 5, "RainbirdController_AddPadding($name) - add_padding: $result");
  
  return $result;
}

#####################################
# EncryptData
#####################################
sub RainbirdController_EncryptData($$$;$)
{
  my ($hash, $data, $encryptkey, $command ) = @_;
  my $name = $hash->{NAME};
  
  $command = "UKN" if not defined($command);

  my $logInfoString = "RainbirdController_EncryptData($name) Cmd:$command";
  
  my $tocodedata = $data . "\x00\x10";
  
  my $iv =  Crypt::CBC->random_bytes(16);
  #my $iv = pack("C*", map { 0x01 } 1..16);
  Log3($name, 5, "$logInfoString: iv: \"" . (sprintf("%v02X", $iv) =~ s/\.//rg) . "\" length: " . length($iv));
  
  my $c = RainbirdController_AddPadding($hash, $tocodedata);
  Log3($name, 5, "$logInfoString: c: \"" . (sprintf("%v02X", $c) =~ s/\.//rg) . "\"");

  my $b = sha256($encryptkey);
  Log3($name, 5, "$logInfoString: b: \"" . (sprintf("%v02X", $b) =~ s/\.//rg) . "\"");

  my $b2 = sha256($data);
  Log3($name, 5, "$logInfoString: b2: \"" . (sprintf("%v02X", $b2) =~ s/\.//rg) . "\" length: " . length($b2));
  
#  my $cbc = Crypt::Mode::CBC->new('AES');
#  my $encrypteddata = $cbc->encrypt($c, $b, $iv);

  # https://metacpan.org/pod/Crypt::CBC 
  my $cbc = Crypt::CBC->new(
    -key => $b,                 # -pass,-key      The encryption/decryption passphrase.
    -pass => $b,

    -cipher => 'Cipher::AES',
    -iv => $iv,
    -padding => 'standard',

#    -regenerate_key => 0,      # -regenerate_key [deprecated; use -literal_key instead]
    -literal_key => 1,          # -literal_key    [deprected, use -pbkdf=>'none']
    -pbkdf => 'none',

    -prepend_iv => 0,           # -prepend_iv [deprecated; use -header instead]
    -header  => 'none'
  );
    
  my $encrypteddata = $cbc->encrypt($c); 
  my $result = $b2 . $iv . $encrypteddata;

  Log3($name, 5, "$logInfoString: result: \"" . (sprintf("%v02X", $result) =~ s/\.//rg) . "\"");

  if($hash->{helper}{Debug} ne "0" and
    $hash->{helper}{DebugCrypt} ne "0")
  {
    $hash->{helper}{Dbg}{"Cmd_" . $command . "_ENC_iv"} = (sprintf("%v02X", $iv) =~ s/\.//rg);
    $hash->{helper}{Dbg}{"Cmd_" . $command . "_ENC_c"} = (sprintf("%v02X", $c) =~ s/\.//rg);
    $hash->{helper}{Dbg}{"Cmd_" . $command . "_ENC_b"} = (sprintf("%v02X", $b) =~ s/\.//rg);
    $hash->{helper}{Dbg}{"Cmd_" . $command . "_ENC_b2"} = (sprintf("%v02X", $b2) =~ s/\.//rg);
    $hash->{helper}{Dbg}{"Cmd_" . $command . "_ENC"} = (sprintf("%v02X", $result) =~ s/\.//rg);
    RainbirdController_UpdateInternals($hash);
  }

  return $result;
}

#####################################
# DecryptData
#####################################
sub RainbirdController_DecryptData($$$;$)
{
  my ( $hash, $data, $decrypt_key, $command ) = @_;
  my $name = $hash->{NAME};

  $command = "UKN" if not defined($command);

  my $logInfoString = "RainbirdController_DecryptData($name) Cmd:$command";

  my $symmetric_key = substr(sha256($decrypt_key), 0, 32);
  Log3($name, 5, "$logInfoString: symmetric_key: \"" . (sprintf("%v02X", $symmetric_key) =~ s/\.//rg) . "\"");

  my $iv = substr($data, 32, 16);
  Log3($name, 5, "$logInfoString: iv: \"" . (sprintf("%v02X", $iv) =~ s/\.//rg) . "\"");

  my $encrypted_data = substr($data, 48, length($data) - 48);
  Log3($name, 5, "$logInfoString: encrypted_data: \"" . (sprintf("%v02X", $encrypted_data) =~ s/\.//rg) . "\"");

#  my $cbc = Crypt::Mode::CBC->new('AES', 0);
#  my $decrypteddata = $cbc->decrypt($encrypted_data, $symmetric_key, $iv);
 
 # https://metacpan.org/pod/Crypt::CBC
  my $cbc = Crypt::CBC->new(
    -key => $symmetric_key,     # -pass,-key      The encryption/decryption passphrase.
    -pass => $symmetric_key,
    
    -cipher => 'Cipher::AES',
    -iv => $iv,
    -padding => 'standard',

#    -regenerate_key => 0,      # -regenerate_key [deprecated; use -literal_key instead]
    -literal_key => 1,          # -literal_key    [deprected, use -pbkdf=>'none']
    -pbkdf => 'none',

    -prepend_iv => 0,           # -prepend_iv [deprecated; use -header instead]
    -header  => 'none'
  );
  my $decrypteddata = $cbc->decrypt($encrypted_data); 

  Log3($name, 5, "$logInfoString: decrypteddata: \"" . (sprintf("%v02X", $decrypteddata) =~ s/\.//rg) . "\"");
  
  $decrypteddata =~ s/\x10+$//;
  $decrypteddata =~ s/\x0a+$//;
  $decrypteddata =~ s/\x00+$//;
  # Take 1 or more white spaces (\s+) till the end of the string ($), and replace them with an empty string. 
  $decrypteddata =~ s/\s+$//;

  if($hash->{helper}{Debug} ne "0" and 
    $hash->{helper}{DebugCrypt} ne "0")
  {
    $hash->{helper}{Dbg}{"Cmd_" . $command . "_DEC_symmetric_key"} = (sprintf("%v02X", $symmetric_key) =~ s/\.//rg);
    $hash->{helper}{Dbg}{"Cmd_" . $command . "_DEC_iv"} = (sprintf("%v02X", $iv) =~ s/\.//rg);
    $hash->{helper}{Dbg}{"Cmd_" . $command . "_DEC_encrypted_data"} = (sprintf("%v02X", $encrypted_data) =~ s/\.//rg);
    $hash->{helper}{Dbg}{"Cmd_" . $command . "_DEC"} = (sprintf("%v02X", $decrypteddata) =~ s/\.//rg);
    RainbirdController_UpdateInternals($hash);
  }
  
  Log3($name, 5, "$logInfoString: decrypteddata: \"" . (sprintf("%v02X", $decrypteddata) =~ s/\.//rg) . "\"");
  Log3($name, 5, "$logInfoString: decrypteddata: \"" . $decrypteddata . "\"");
  
  return $decrypteddata;
}

####################################
# StorePassword
#####################################
sub RainbirdController_StorePassword($$)
{
  my ($hash, $password ) = @_;
  my $name    = $hash->{NAME};
  my $index   = $hash->{TYPE} . "_" . $name . "_passwd";
  my $key     = getUniqueId() . $index;
  my $enc_pwd = "";

  if (eval "use Digest::MD5;1")
  {
    $key = Digest::MD5::md5_hex(unpack "H*", $key);
    $key .= Digest::MD5::md5_hex($key);
  }

  for my $char ( split //, $password )
  {
    my $encode = chop($key);
    $enc_pwd .= sprintf("%.2x", ord($char) ^ ord($encode));
    $key = $encode . $key;
  }

  my $err = setKeyValue($index, $enc_pwd);

  return "error while saving the password - $err"
    if (defined($err));

  return "password successfully saved";
}

####################################
# ReadPassword
#####################################
sub RainbirdController_ReadPassword($)
{
  my ($hash) = @_;
  my $name   = $hash->{NAME};
  my $index  = $hash->{TYPE} . "_" . $name . "_passwd";
  my $key    = getUniqueId() . $index;
  my $password;
  my $err;

  my $logInfoString = "RainbirdController_ReadPassword($name)";

  Log3($name, 5, "$logInfoString: Read password from file");

  ($err, $password) = getKeyValue($index);

  if (defined($err))
  {
    Log3($name, 5, "$logInfoString: unable to read password from file: $err");
    return undef;
  }

  if (defined($password))
  {
    if (eval "use Digest::MD5;1")
    {
      $key = Digest::MD5::md5_hex( unpack "H*", $key );
      $key .= Digest::MD5::md5_hex($key);
    }

    my $dec_pwd = '';

    for my $char ( map { pack( 'C', hex($_) ) } ( $password =~ /(..)/g ) )
    {
      my $decode = chop($key);
      $dec_pwd .= chr( ord($char) ^ ord($decode) );
      $key = $decode . $key;
    }

    return $dec_pwd;
  } 
  else
  {
    Log3($name, 5, "$logInfoString: No password in file");
    return undef;
  }
}

#####################################
# DeletePassword
#####################################
sub RainbirdController_DeletePassword($)
{
  my ($hash) = @_;
  my $name   = $hash->{NAME};
  my $index  = $hash->{TYPE} . "_" . $name . "_passwd";

  setKeyValue($index, undef);

  return undef;
}


#####################################
### Parse a timespec: Either HH:MM:SS or HH:MM
#####################################
sub RainbirdController_GetTimeSpec($)
{
  my ($tspec) = @_;
  my ($hr, $min, $sec);

  if($tspec =~ m/^([0-9]+):([0-5][0-9]):([0-5][0-9])$/) 
  {
    ($hr, $min, $sec) = ($1, $2, $3);
  } 
  elsif($tspec =~ m/^([0-9]+):([0-5][0-9])$/) 
  {
    ($hr, $min, $sec) = ($1, $2, 0);
  } 
  else 
  {
    return ("Wrong timespec $tspec: either HH:MM:SS or HH:MM", undef, undef, undef, undef);
  }
  
  return (undef, $hr, $min, $sec);
}

#####################################
### Parse a timespec: Either HH:MM:SS or HH:MM
#####################################
sub RainbirdController_GetDateSpec($)
{
  my ($tspec) = @_;
  my ($year, $month, $day);

  if($tspec =~ m/^([0-9]+)-([0-1][0-9])-([0-3][0-9])$/) 
  {
    ($year, $month, $day) = ($1, $2, $3);
  } 
  else 
  {
    return ("Wrong timespec $tspec: YYYY-MM-DD", undef, undef, undef, undef);
  }
  
  return (undef, $year, $month, $day);
}

#####################################
### GetWeekdaysFromBitmask
#####################################
sub RainbirdController_GetWeekdaysFromBitmask($)
{
  my ($mask) = @_;
  
  my $result = "";

  if($mask == 0)
  {
  	$result = "none"
  }
  else
  {
    $result .= "Mon," if($mask &  2);
    $result .= "Tue," if($mask &  4);
    $result .= "Wed," if($mask &  8);
    $result .= "Thu," if($mask & 16);
    $result .= "Fri," if($mask & 32);
    $result .= "Sat," if($mask & 64);
    $result .= "Sun," if($mask &  1);
  }
  
  # cutoff last ","
  my $len = length($result);
  $result = substr($result, 0, $len - 1); 
  return $result;
}

#####################################
### GetTimeFrom10Minutes
#####################################
sub RainbirdController_GetTimeFrom10Minutes($)
{
  my ($_10Minutes) = @_;
  
  my $hours = int($_10Minutes / 6);
  my $minutes = ($_10Minutes - ($hours * 6)) * 10;
  
  return sprintf("%02D:%02D", $hours, $minutes);
}


1;

=pod
=item device
=item summary module to interact with LNK WiFi module of the Rain Bird Irrigation System
=begin html

  <a name="RainbirdController"></a><h3>RainbirdController</h3>
  <ul>
    In combination with the FHEM module RainbirdZone this module interacts with <b>LNK WiFi module</b> of the <b>Rain Bird Irrigation System</b>.<br>
    <br>
    You can start/stop the irrigation and get the currently active zone.<br>
    <br>
      <b>Notes</b>
      <ul>
        <li>This module communicates directly with the <b>LNK WiFi module</b> - it does not support the cloud.
        </li>
        <li>The communication of this FHEM module competes with the communication of the app - maybe the app signals a communication error.
        </li>
      </ul>
    <br>
    <a name="RainbirdControllerdefine"></a><b>Define</b>
    <ul>
      <code><B>define &lt;name&gt; RainbirdController &lt;host&gt;</B></code>
      <br><br>
      Example:<br>
      <ul>
        <code>
        define RainbirdController RainbirdController rainbird.fritz.box<br>
        <br>
        </code>
      </ul>
    </ul><br>
    <a name="RainbirdControllerset"></a><b>Set</b>
    <ul>
      <li><B>ClearReadings</B><a name="RainbirdControllerClearReadings"></a><br>
        Clears all readings.
      </li>
      <li><B>DeletePassword</B><a name="RainbirdControllerDeletePassword"></a><br>
        Deletes the password from store.
      </li>
      <li><B>FactoryReset</B><a name="RainbirdControllerFactoryReset"></a><br>
        Reset all parameters of the device to default factory settings.
      </li>
      <li><B>InternalDate</B><a name="RainbirdControllerInternalDate"></a><br>
        Set the internal date of the controller.<br>
        Format: <b>YYYY-MM-DD</b>
      </li>
      <li><B>InternalTime</B><a name="RainbirdControllerInternalTime"></a><br>
        Set the internal time of the controller<br>
        Format: <b>HH:MM</b> or <b>HH:MM:SS</b>
      </li>
      <li><B>IrrigateZone</B><a name="RainbirdControllerIrrigateZone"></a><br>
        Starts irrigating a zone.<br>
        <br>
        <code>usage: &lt;name&gt IrrigateZone &lt;zone&gt &lt;minutes&gt</code>
      </li>
      <li><B>Password</B><a name="RainbirdControllerPassword"></a><br>
        Sets the password in store.
      </li>
      <li><B>RainDelay</B><a name="RainbirdControllerRainDelay"></a><br>
        Sets the delay in days.
      </li>
      <li><B>RainSensorBypass</B><a name="RainbirdControllerRainSensorBypass"></a><br>
        Sets the bypass of the rainsensor on or off.
      </li>
      <li><B>Stop</B><a name="RainbirdControllerStop"></a><br>
        Stops the irrigating of all zones.
      </li>
      <li><B>SynchronizeDateTime</B><a name="RainbirdControllerSynchronizeDateTime"></a><br>
        Synchronizes the internal date and time of the controller with fhem's time.
      </li>
      <li><B>TestCMD</B><a name="RainbirdControllerTestCMD"></a><br>
        Tests a defined command<br>
      </li>
      <li><B>TestRAW</B><a name="RainbirdControllerTestRAW"></a><br>
        Tests a raw command
      </li>
      <li><B>Update</B><a name="RainbirdControllerUpdate"></a><br>
        Updates the device info and state.
      </li>
    </ul>
    <br>
    <a name="RainbirdControllerget"></a><b>Get</b><br>
    <ul>
      <li><B>AvailableZones</B><a name="RainbirdControllerAvailableZones"></a><br>
        Gets all available zones.
      </li>
      <li><B>CommandSupport</B><a name="RainbirdControllerCommandSupport"></a><br>
        Get supported command info.
      </li>
      <li><B>CurrentIrrigation</B><a name="RainbirdControllerCurrentIrrigation"></a><br>
        Get the current irrigation state.
      </li>
      <li><B>Date</B><a name="RainbirdControllerDate"></a><br>
        Get internal device date.
      </li>
      <li><B>DecryptHEX</B><a name="RainbirdControllerDecryptHEX"></a><br>
        Toolfunction to decrypt a captured message with the set password.<br>
        You can put a string of hex values as parameter to this function and get the decrypted string.<br>
        <br>
        The function takes the substring between any kind of braces and strips al "0x", SPACE and "," from the string.<br>
        So the format of the hex values can be:<br>
        <ul>
          <li>
            <code>AA BB CC</code>
          </li>
          <li>
            Fiddler4: Copy as 0x##<br>
            <code>byte[] arrOutput = { 0x2A, 0xD5, 0x4B, ..., 0x99, 0x5C };</code>
          </li>
        </ul>
      </li>
      <li><B>DeviceInfo</B><a name="RainbirdControllerDeviceInfo"></a><br>
        Get current device info.
      </li>
      <li><B>DeviceState</B><a name="RainbirdControllerDeviceState"></a><br>
        Get current device state.
      </li>
      <li><B>IrrigationState</B><a name="RainbirdControllerIrrigationState"></a><br>
        Get the current irrigation state.
      </li>
      <li><B>ModelAndVersion</B><a name="RainbirdControllerModelAndVersion"></a><br>
        Get device model and version.
      </li>
      <li><B>RainDelay</B><a name="RainbirdControllerRainDelay"></a><br>
        Get the delay in days.
      </li>
      <li><B>RainSensorState</B><a name="RainbirdControllerRainSensorState"></a><br>
        Get the state of the rainsensor.
      </li>
      <li><B>SerialNumber</B><a name="RainbirdControllerSerialNumber"></a><br>
        Get device serial number.
      </li>
      <li><B>Time</B><a name="RainbirdControllerTime"></a><br>
        Get internal device time.
      </li>
      <li><B>NetworkStatus</B><a name="RainbirdControllerNetworkStatus"></a><br>
        Get NetworkStatus.
      </li>
      <li><B>Settings</B><a name="RainbirdControllerSettings"></a><br>
        Get Settings.
      </li>
      <li><B>WifiParams</B><a name="RainbirdControllerWifiParams"></a><br>
        Get WifiParams.
      </li>
      <li><B>ZoneSchedule</B><a name="RainbirdControllerZoneSchedule"></a><br>
        Get schedule of a zone.
      </li>
    </ul><br>
    <a name="RainbirdControllerattr"></a><b>Attributes</b><br>
    <ul>
      <li><a name="RainbirdControllerautocreatezones">autocreatezones</a><br>
        If <b>enabled</b> (default) then RainbirdZone devices will be created automatically.<br>
        If <b>disabled</b> then  RainbirdZone devices must be create manually.<br>
      </li>
      <li><a name="RainbirdControllerdisable">disable</a><br>
        Disables the device.<br>
      </li>
      <li><a name="RainbirdControllerdebug">debug</a><br>
        Switches to <b>debug</b> mode.<br>
        If enabled then additional internals for <b>debugging purposes</b> will be shown.<br> 
      </li>
      <li><a name="RainbirdControllerdebugcrypt">debugcrypt</a><br>
        Switches to <b>debugcrypt</b> mode.<br>
        If enabled then additional internals for <b>debugging encryption and decryption</b> will be shown.<br> 
        Attribut <b>debug</b> has to be set too.<br>
      </li>
      <li><a name="RainbirdControllercheckcmd">checkcmd</a><br>
        Enables or disables the checking if command is supported by device. (Default=1)<br>
      </li>
      <li><a name="RainbirdControllerinterval">interval</a><br>
        Interval of polling in seconds (Default=60).<br>
      </li>
      <li><a name="RainbirdControllerretry">retry</a><br>
        Number of retries (Default=2)<br>
      </li>
      <li><a name="RainbirdControllertimeout">timeout</a><br>
        Timeout for expected response in seconds (Default=10)<br>
      </li>
    </ul><br>
    <a name="RainbirdControllerreadings"></a><b>Readings</b>
    <ul>
      <li><B>InternalDate</B><br>
        Internal date of the device.<br>
      </li>
      <li><B>InternalTime</B><br>
        Internal time of the device.<br>
      </li>
      <li><B>InternetUp</B><br>
        1 if connected to the internet else 0.<br>
      </li>
      <li><B>IrrigationSecondsLeft</B><br>
        Left irrigation timespan in seconds.<br>
      </li>
      <li><B>IrrigationState</B><br>
        Irrigation state.<br>
      </li>
      <li><B>NetworkUp</B><br>
        1 if network is up else 0.<br>
      </li>
      <li><B>RainDelay</B><br>
        Delay of the schedules in days.<br>
      </li>
      <li><B>RainSensorBypass</B><br>
        Enable (on) or disable (off) the bypass of the rain sensor.<br>
      </li>
      <li><B>RainSensorState</B><br>
        State of the rain sensor.<br>
      </li>
      <li><B>SettingCode</B><br>
        Zip-code of your city.<br>
      </li>
      <li><B>SettingCountry</B><br>
        Country.<br>
      </li>
      <li><B>SettingGlobalDisable</B><br>
        SettingGlobalDisable.<br>
      </li>
      <li><B>SettingNumPrograms</B><br>
        SettingNumPrograms.<br>
      </li>
      <li><B>SettingProgramOptOutMask</B><br>
        SettingProgramOptOutMask.<br>
      </li>
      <li><B>Wifi_ApTimeoutIdle</B><br>
        Wifi_ApTimeoutIdle.<br>
      </li>
      <li><B>Wifi_ApTimeoutNoLan</B><br>
        Wifi_ApTimeoutNoLan.<br>
      </li>
      <li><B>Wifi_Gateway</B><br>
        Wifi_Gateway.<br>
      </li>
      <li><B>Wifi_IpAddress</B><br>
        Wifi_IpAddress.<br>
      </li>
      <li><B>Wifi_MacAddress</B><br>
        Wifi_MacAddress.<br>
      </li>
      <li><B>Wifi_Netmask</B><br>
        Wifi_Netmask.<br>
      </li>
      <li><B>Wifi_Security</B><br>
        Wifi_Security.<br>
      </li>
      <li><B>Wifi_StickVersion</B><br>
        Wifi_StickVersion.<br>
      </li>
      <li><B>Wifi_rssi</B><br>
        Wifi_rssi.<br>
      </li>
      <li><B>ZoneActive</B><br>
        Number of active zone.<br>
      </li>
      <li><B>state</B><br>
        State.<br>
      </li>
    </ul><br>
    <br>
  </ul>
=end html

=cut
