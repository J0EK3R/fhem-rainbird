###############################################################################
#
# Developed with eclipse
#
#  (c) 2020 Copyright: J.K. (J0EK3R at gmx dot net)
#  All rights reserved
#
#   Special thanks goes to comitters:
#
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

use strict;
use warnings;

my $missingModul = '';
eval "use JSON;1" or $missingModul .= "JSON ";
eval "use Digest::SHA qw(sha256);1" or $missingModul .= 'Digest::SHA ';
eval "use Crypt::CBC;1" or $missingModul .= 'Crypt::CBC ';
eval "use Crypt::Mode::CBC;1" or $missingModul .= 'Crypt::Mode::CBC ';

### statics
my $VERSION = '1.7.3';
my $DefaultInterval = 60;
my $DefaultRetryInterval = 60;
my $DefaultTimeout = 5;
my $DefaultRetries = 3;

### Forward declarations
sub RainbirdController_Initialize($);
sub RainbirdController_Define($$);
sub RainbirdController_Undef($$);
sub RainbirdController_Delete($$);
sub RainbirdController_Rename($$);
sub RainbirdController_Attr(@);
sub RainbirdController_Notify($$);
sub RainbirdController_Write($@);
sub RainbirdController_Set($@);
sub RainbirdController_Get($@);

sub RainbirdController_TimerStop($);
sub RainbirdController_TimerRestart($);
sub RainbirdController_TimerLoop($);

sub RainbirdController_GetDeviceState($;$);

sub RainbirdController_GetModelAndVersion($;$);
sub RainbirdController_GetAvailableZones($;$);
sub RainbirdController_GetCommandSupport($$;$);
sub RainbirdController_SetWaterBudget($$;$);
sub RainbirdController_GetRainSensorState($;$);
sub RainbirdController_GetSerialNumber($;$);
### Time
sub RainbirdController_GetCurrentTime($;$);
sub RainbirdController_SetCurrentTime($$$$;$);
### Date
sub RainbirdController_GetCurrentDate($;$);
sub RainbirdController_SetCurrentDate($$$$;$);
### RainDelay
sub RainbirdController_GetRainDelay($;$);
sub RainbirdController_SetRainDelay($$;$);

sub RainbirdController_GetCurrentIrrigation($;$);
sub RainbirdController_GetActiveStation($;$);
sub RainbirdController_GetIrrigationState($;$);
## Zone
sub RainbirdController_ZoneIrrigate($$$;$);
sub RainbirdController_ZoneGetSchedule($$;$);
sub RainbirdController_ZoneTest($$;$);

sub RainbirdController_SetProgram($$;$);
sub RainbirdController_StopIrrigation($;$);
sub RainbirdController_FactoryReset($;$);

### for testing purposes only
sub RainbirdController_TestCMD($$$;$);
sub RainbirdController_TestRAW($$;$);

### internal tool functions
sub RainbirdController_CallIfLambda($$$$);

sub RainbirdController_GetZoneFromRaw($);
sub RainbirdController_GetAvailableZoneCountFromRaw($);
sub RainbirdController_GetAvailableZoneMaskFromRaw($);

sub RainbirdController_Command($$$@);
sub RainbirdController_Request($$$$);
sub RainbirdController_ErrorHandling($$$);
sub RainbirdController_ResponseProcessing($$);

sub RainbirdController_EncodeData($$@);
sub RainbirdController_DecodeData($$);
sub RainbirdController_AddPadding($$);
sub RainbirdController_EncryptData($$$);
sub RainbirdController_DecryptData($$$);
sub RainbirdController_StorePassword($$);
sub RainbirdController_ReadPassword($);
sub RainbirdController_DeletePassword($);
sub RainbirdController_GetTimeSpec($);
sub RainbirdController_GetDateSpec($);
sub RainbirdController_GetWeekdaysFromBitmask($);
sub RainbirdController_GetTimeFrom10Minutes($);

### hash with all known models
my %KnownModels = (
  3 => "ESP-RZXe Serie",
);


# Some captured requests:
# {"id":56699,"method":"getWifiParams","params":{},"jsonrpc":"2.0"}
# {"id":3705,"method":"getNetworkStatus","params":{},"jsonrpc":"2.0"}
# {"id":52139,"method":"tunnelSip","params":{"length":2,"data":"0300"},"jsonrpc":"2.0"}       -> AvailableStationsRequest
# {"id":32497,"method":"tunnelSip","params":{"length":1,"data":"10"},"jsonrpc":"2.0"}         -> CurrentTimeGetRequest
# {"id":37666,"method":"tunnelSip","params":{"length":1,"data":"12"},"jsonrpc":"2.0"}         -> CurrentDateGetRequest
# {"id":43829,"method":"tunnelSip","params":{"length":1,"data":"36"},"jsonrpc":"2.0"}         -> RainDelayGetRequest
# {"id":10371,"method":"tunnelSip","params":{"length":1,"data":"3E"},"jsonrpc":"2.0"}         -> CurrentRainSensorStateRequest
# {"id":33655,"method":"tunnelSip","params":{"length":1,"data":"48"},"jsonrpc":"2.0"}         -> CurrentIrrigationStateRequest
# {"id":9937,"method":"tunnelSip","params":{"length":2,"data":"30FF"},"jsonrpc":"2.0"}        -> WaterBudgetRequest
# {"id":29038,"method":"tunnelSip","params":{"length":3,"data":"200000"},"jsonrpc":"2.0"}     -> CurrentScheduleRequest
# {"id":19243,"method":"tunnelSip","params":{"length":3,"data":"200001"},"jsonrpc":"2.0"}     
# {"id":10162,"method":"tunnelSip","params":{"length":3,"data":"200002"},"jsonrpc":"2.0"}
# {"id":22838,"method":"tunnelSip","params":{"length":3,"data":"200003"},"jsonrpc":"2.0"}
# {"id":61229,"method":"tunnelSip","params":{"length":3,"data":"200004"},"jsonrpc":"2.0"} 15
# {"id":22305,"method":"tunnelSip","params":{"length":3,"data":"200005"},"jsonrpc":"2.0"} 16
# {"id":39195,"method":"tunnelSip","params":{"length":3,"data":"200006"},"jsonrpc":"2.0"} 17
# {"id":50342,"method":"tunnelSip","params":{"length":3,"data":"200007"},"jsonrpc":"2.0"} 18
# {"id":27712,"method":"tunnelSip","params":{"length":3,"data":"200008"},"jsonrpc":"2.0"} 19
# {"id":42833,"method":"tunnelSip","params":{"length":2,"data":"30FF"},"jsonrpc":"2.0"} 20    -> WaterBudgetRequest
# {"id":37789,"method":"getSettings","params":{},"jsonrpc":"2.0"}
# {"id":45783,"method":"tunnelSip","params":{"length":2,"data":"3F00"},"jsonrpc":"2.0"}       -> CurrentStationsActiveRequest
# {"id":19338,"method":"tunnelSip","params":{"length":2,"data":"3B00"},"jsonrpc":"2.0"} 23    -> GetIrrigationStateRequest
# 


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
  "ModelAndVersionRequest" => {"command" => "02", "response" => "82", "length" => 1},
  "AvailableStationsRequest" => {"command" => "03", "response" => "83", "length" => 2, 
    "parameter1" => 2},
  "CommandSupportRequest" => {"command" => "04", "response" => "84", "length" => 2, 
    "parameter1" => 2}, # command like "04"
  "SerialNumberRequest" => {"command" => "05", "response" => "85", "length" => 1},
  ### still unknown - length OK
  "Unknown06Request" => {"command" => "06", "response" => "86", "length" => 5, 
    "parameter1" => 2, 
    "parameter2" => 2, 
    "parameter3" => 2, 
    "parameter4" => 2},
  ### still unknown - length OK
  "Unknown07Request" => {"command" => "07", "response" => "86", "length" => 5, 
    "parameter1" => 2, 
    "parameter2" => 2, 
    "parameter3" => 2, 
    "parameter4" => 2},
  "CurrentTimeGetRequest" => {"command" => "10", "response" => "90", "length" => 1},
  "CurrentTimeSetRequest" => {"command" => "11", "response" => "01", "length" => 4, 
    "parameter1" => 2, 
    "parameter2" => 2, 
    "parameter3" => 2},
  "CurrentDateGetRequest" => {"command" => "12", "response" => "92", "length" => 1},
  "CurrentDateSetRequest" => {"command" => "13", "response" => "01", "length" => 4, 
    "parameter1" => 2, 
    "parameter2" => 1, 
    "parameter3" => 3},
  "CurrentScheduleRequest" => {"command" => "20","response" => "A0", "length" => 3, 
    "parameter1" => 4},  # ZoneId
  ### still unknown - length OK
  "Unknown21Request" => {"command" => "21", "response" => "01", "length" => 4, 
    "parameter1" => 2, 
    "parameter2" => 1, 
    "parameter3" => 1},
  # not supported
    # FF ->
    # "data" : "B0FF0064",
    # "identifier" : "Rainbird",
    # "programCode" : "255",
    # "responseId" : "B0",
    # "seasonalAdjust" : "100",
    # "type" : "WaterBudgetResponse"
  "WaterBudgetRequest" => {"command" => "30", "response" => "B0", "length" => 2,  
    "parameter1" => 2},
  ### still unknown
  "Unknown31Request" => {"command" => "31", "response" => "85", "length" => 4, 
    "parameter1" => 2, 
    "parameter2" => 2, 
    "parameter3" => 2},
  # not supported
  "ZonesSeasonalAdjustFactorRequest" => {"command" => "32", "response" => "B2", "length" => 2,  
    "parameter1" => 2}, 
  "RainDelayGetRequest" => {"command" => "36", "response" => "B6", "length" => 1},
  "RainDelaySetRequest" => {"command" => "37", "response" => "01", "length" => 3, 
    "parameter1" => 4},
  # not supported
  "ManuallyRunProgramRequest" => {"command" => "38", "response" => "01", "length" => 2,
    "parameter1" => 2}, 
  "ManuallyRunStationRequest" => {"command" => "39", "response" => "01", "length" => 4, 
    "parameter1" => 4,  # ZoneId
    "parameter2" => 2}, # irrigation timespan in minutes
  "TestStationsRequest" => {"command" => "3A", "response" => "01", "length" => 2, 
    "parameter1" => 2},
  "GetIrrigationStateRequest" => {"command" => "3B", "response" => "BB", "length" => 2,
    "parameter1" => 2},
  ### still unknown
  "Unknown3DRequest" => {"command" => "3D", "response" => "DB", "length" => 2,
    "parameter1" => 2},
  "CurrentRainSensorStateRequest" => {"command" => "3E", "response" => "BE", "length" => 1},
  "CurrentStationsActiveRequest" => {"command" => "3F", "response" => "BF", "length" => 2, 
    "parameter1" => 2},
  "StopIrrigationRequest" => {"command" => "40", "response" => "01", "length" => 1},
  ### still unknown
  "Unknown41Request" => {"command" => "41", "response" => "01", "length" => 2, 
  	"parameter1" => 2}, # 00, FF
  # not supported
  "AdvanceStationRequest" => {"command" => "42", "response" => "01", "length" => 2,
    "parameter1" => 2}, 
  "CurrentIrrigationStateRequest" => {"command" => "48", "response" => "C8", "length" => 1},
  # not supported
  "CurrentControllerStateSet" => {"command" => "49", "response" => "01", "length" => 2, 
    "parameter1" => 2}, 
  # not supported
  "ControllerEventTimestampRequest" => {"command" => "4A", "response" => "CA", "length" => 2, 
    "parameter1" => 2}, 
  # not supported
  "StackManuallyRunStationRequest" => {"command" => "4B", "response" => "01", "length" => 4, 
    "parameter1" => 2, 
    "parameter2" => 1, 
    "parameter3" => 1}, 
  # not supported
  "CombinedControllerStateRequest" => {"command" => "4C", "response" => "CC","length" => 1 },
  ### still unknown
  "Unknown50Request" => {"command" => "50", "response" => "01", "length" => 1},
  ### still unknown
  "Unknown51Request" => {"command" => "51", "response" => "01", "length" => 1},
  ### still unknown
  "Unknown52Request" => {"command" => "52", "response" => "01", "length" => 1},
  "FactoryResetRequest" => {"command" => "57", "response" => "01", "length" => 1},
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
  "00" => {"length" =>  3, "type" => "NotAcknowledgeResponse", 
    "commandEcho" => {"position" => 2, "length" => 2, "format" => "%02X"}, 
    "NAKCode" => {"position" => 4, "length" => 2, "knownvalues" => {"1" => "[1]: command not supported", "2" => "[2]: wrong number of parameters", "4" => "[4]: illegal parameter",} } },
  "01" => {"length" =>  2, "type" => "AcknowledgeResponse", 
    "commandEcho" => {"position" => 2, "length" => 2, "format" => "%02X"} },
  "82" => {"length" =>  5, "type" => "ModelAndVersionResponse", 
    "modelID" => {"position" => 2, "length" => 4}, 
    "protocolRevisionMajor" => {"position" => 6, "length" => 2}, 
    "protocolRevisionMinor" => {"position" => 8, "length" => 2} },
  "83" => {"length" =>  6, "type" => "AvailableStationsResponse", 
    "pageNumber" => {"position" => 2, "length" => 2}, 
    "setStations" => {"position" => 4, "length" => 8} },
  "84" => {"length" =>  3, "type" => "CommandSupportResponse", 
    "commandEcho" => {"position" => 2, "length" => 2, "format" => "%02X"}, 
    "support" => {"position" => 4, "length" => 2} },
  "85" => {"length" =>  9, "type" => "SerialNumberResponse", 
    "serialNumber" => {"position" => 2, "length" => 16} },
  "86" => {"length" =>  9, "type" => "Unknown06Response", 
    "result1" => {"position" => 2, "length" => 8, "format" => "%X"}, 
    "result2" => {"position" => 10, "length" => 8, "format" => "%X"}},
  "90" => {"length" =>  4, "type" => "CurrentTimeGetResponse", 
    "hour" => {"position" => 2, "length" => 2}, 
    "minute" => {"position" => 4, "length" => 2}, 
    "second" => {"position" => 6, "length" => 2} },
  "92" => {"length" =>  4, "type" => "CurrentDateGetResponse", 
    "day" => {"position" => 2, "length" => 2}, 
    "month" => {"position" => 4, "length" => 1}, 
    "year" => {"position" => 5, "length" => 3} },
  "A0" => {"length" =>  14, "type" => "CurrentScheduleResponse", 
    "zoneId"           => {"position" =>  2, "length" => 4}, 
    "timespan"         => {"position" =>  6, "length" => 2}, 
    "timer1"           => {"position" =>  8, "length" => 2, "knownvalues" => {"24:00" => "off"}, "converter" => \&RainbirdController_GetTimeFrom10Minutes},
    "timer2"           => {"position" => 10, "length" => 2, "knownvalues" => {"24:00" => "off"}, "converter" => \&RainbirdController_GetTimeFrom10Minutes},
    "timer3"           => {"position" => 12, "length" => 2, "knownvalues" => {"24:00" => "off"}, "converter" => \&RainbirdController_GetTimeFrom10Minutes},
    "timer4"           => {"position" => 14, "length" => 2, "knownvalues" => {"24:00" => "off"}, "converter" => \&RainbirdController_GetTimeFrom10Minutes}, 
    "timer5"           => {"position" => 16, "length" => 2, "knownvalues" => {"24:00" => "off"}, "converter" => \&RainbirdController_GetTimeFrom10Minutes},
    "param1"           => {"position" => 18, "length" => 2, "knownvalues" => {"144" => "off"}}, 
    "mode"             => {"position" => 20, "length" => 2, "knownvalues" => {"0" => "user defined", "1" => "odd", "2" => "even", "3" => "zyclic"}}, 
    "weekday"          => {"position" => 22, "length" => 2, "converter" => \&RainbirdController_GetWeekdaysFromBitmask}, 
    "interval"         => {"position" => 24, "length" => 2}, 
    "intervaldaysleft" => {"position" => 26, "length" => 2}},
  "B0" => {"length" =>  4, "type" => "WaterBudgetResponse", 
    "programCode" => {"position" => 2, "length" => 2}, 
    "seasonalAdjust" => {"position" => 4, "length" => 4} },
  "B2" => {"length" => 18, "type" => "ZonesSeasonalAdjustFactorResponse", 
    "programCode" => {"position" => 2, "length" => 2}, 
    "stationsSA" => {"position" => 4, "length" => 32} },
  "B6" => {"length" =>  3, "type" => "RainDelaySettingResponse", 
    "delaySetting" => {"position" => 2, "length" => 4} },
  "BB" => {"length" =>  10, "type" => "GetIrrigationStateResponse", 
    "unknown2" => {"position" => 2, "length" => 2},
    "unknown4" => {"position" => 4, "length" => 2},
    "unknown6" => {"position" => 6, "length" => 2},
    "unknown8" => {"position" => 8, "length" => 2},
    "unknown10" => {"position" => 10, "length" => 2},
    "activeZone" => {"position" => 12, "length" => 2},
    "unknown14" => {"position" => 14, "length" => 2},
    "secondsLeft" => {"position" => 16, "length" => 4}, },
  "BD" => {"length" =>  6, "type" => "Unknown3DResponse", 
    "sensorState" => {"position" => 2, "length" => 2} },
  "BE" => {"length" =>  2, "type" => "CurrentRainSensorStateResponse", 
    "sensorState" => {"position" => 2, "length" => 2} },
  "BF" => {"length" =>  6, "type" => "CurrentStationsActiveResponse", 
    "pageNumber" => {"position" => 2, "length" => 2}, 
    "activeStations" => {"position" => 4, "length" => 8} },
  "C8" => {"length" =>  2, "type" => "CurrentIrrigationStateResponse", 
    "irrigationState" => {"position" => 2, "length" => 2} },
  "CA" => {"length" =>  6, "type" => "ControllerEventTimestampResponse", 
    "eventId" => {"position" => 2, "length" => 2}, 
    "timestamp" => {"position" => 4, "length" => 8} },
  "CC" => {"length" => 16, "type" => "CombinedControllerStateResponse", 
    "hour" => {"position" => 2, "length" => 2}, 
    "minute" => {"position" => 4, "length" => 2}, 
    "second" => {"position" => 6, "length" => 2}, 
    "day" => {"position" => 8, "length" => 2}, 
    "month" => {"position" => 10, "length" => 1}, 
    "year" => {"position" => 11, "length" => 3}, 
    "delaySetting" => {"position" => 14, "length" => 4}, 
    "sensorState" => {"position" => 18, "length" => 2}, 
    "irrigationState" => {"position" => 20, "length" => 2}, 
    "seasonalAdjust" => {"position" => 22, "length" => 4}, 
    "remainingRuntime" => {"position" => 26, "length" => 4}, 
    "activeStation" => {"position" => 30, "length" => 2} }
);

my $DEFAULT_PAGE = 0;
my $BLOCK_SIZE = 16;
my $INTERRUPT = "\x00";
my $PAD = "\x10";

my $CMDSUPPORTPREFIX = "CMDSUPPORT_"; # hide with prefix "."
my $CMDSUPPORT_3F =  $CMDSUPPORTPREFIX . '3F';

### HTML hedaer
my $HEAD = 
    "Accept-Language: en\n" .
    "Accept-Encoding: gzip, deflate\n" .
    "User-Agent: RainBird/2.0 CFNetwork/811.5.4 Darwin/16.7.0\n" .
    "Accept: */*\n" .
#    "Connection: keep-alive\n" .
    "Content-Type: application/octet-stream";

#####################################
# initialization of the module
#####################################
sub RainbirdController_Initialize($)
{
  my ($hash) = @_;

  # Provider
  $hash->{WriteFn}  = \&RainbirdController_Write;
  $hash->{Clients}   = 'RainbirdZone';
  $hash->{MatchList} = { '1:RainbirdZone' => '"identifier":"Rainbird"' }; # example: {"response":"BF","pageNumber":0,"type":"CurrentStationsActiveResponse","identifier":"Rainbird","activeStations":0}

  # Consumer
  $hash->{SetFn}    = \&RainbirdController_Set;
  $hash->{GetFn}    = \&RainbirdController_Get;
  $hash->{DefFn}    = \&RainbirdController_Define;
  $hash->{UndefFn}  = \&RainbirdController_Undef;
  $hash->{DeleteFn} = \&RainbirdController_Delete;
  $hash->{RenameFn} = \&RainbirdController_Rename;
  $hash->{NotifyFn} = \&RainbirdController_Notify;
  $hash->{AttrFn}   = \&RainbirdController_Attr;

  $hash->{AttrList} = 
    'disable:1 ' . 
    'expert:1,0 ' . 
    'autocreatezones:1,0 ' . 
    'interval ' . 
    'disabledForIntervals ' . 
    'timeout ' . 
    'retry ' . 
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

  return 'too few parameters: define <NAME> RainbirdController' if ( @a < 3 );
  return 'too much parameters: define <NAME> RainbirdController' if ( @a > 3 );
  return 'Cannot define RainbirdController device. Perl modul "' . ${missingModul} . '" is missing.' if ($missingModul);

  my $name = $a[0];
  #          $a[1] just contains the "RainbirdController" module name and we already know that! :-)
  my $host = $a[2];

  ### Stop the current timer if one exists errornous 
  RainbirdController_TimerStop($hash);

  ### some internal settings
  $hash->{VERSION}                       = $VERSION;
  $hash->{INTERVAL}                      = $DefaultInterval;
  $hash->{RETRYINTERVAL}                 = $DefaultRetryInterval;
  $hash->{TIMEOUT}                       = $DefaultTimeout;
  $hash->{RETRIES}                       = $DefaultRetries;
  $hash->{NOTIFYDEV}                     = "global,$name";
  $hash->{HOST}                          = $host;
  $hash->{EXPERTMODE}                    = 0;
  $hash->{AUTOCREATEZONES}               = 1;
  $hash->{ZONESAVAILABLECOUNT}           = 0; # 
  $hash->{ZONESAVAILABLEMASK}            = 0; # 
  $hash->{ZONEACTIVE}                    = 0; # 
  $hash->{ZONEACTIVEMASK}                = 0; # 
  $hash->{REQUESTID}                     = 0;
  $hash->{TIMERON}                       = 0;
  $hash->{helper}{RESPONSESUCCESSCOUNT}  = 0; # statistics
  $hash->{helper}{RESPONSEERRORCOUNT}    = 0; # statistics
  $hash->{helper}{RESPONSETOTALTIMESPAN} = 0; # statistics

  ### dont check these commands
  $hash->{$CMDSUPPORTPREFIX . '04'}                 = 1;
    
  ### set attribute defaults
  CommandAttr( undef, $name . ' room Rainbird' )
    if ( AttrVal( $name, 'room', 'none' ) eq 'none' );

  ### ensure attribute webCmd is present
  CommandAttr( undef, $name . ' webCmd Stop:Update' )
    if ( AttrVal( $name, 'webCmd', 'none' ) eq 'none' );

  ### ensure attribute event-on-change-reading is present
  ### exclude readings currentTime and currentDate
  CommandAttr( undef, $name . ' event-on-change-reading (?!currentTime).*' )
    if ( AttrVal( $name, 'event-on-change-reading', 'none' ) eq 'none' );

  ### set reference to this instance in global modules hash
  $modules{RainbirdController}{defptr}{CONTROLLER} = $hash;

  ### set initial state
  readingsSingleUpdate( $hash, 'state', 'initialized', 1 );

  Log3 $name, 3, "RainbirdController ($name) - defined RainbirdController";

  return undef;
}

#####################################
# undefine of an instance
#####################################
sub RainbirdController_Undef($$)
{
  my ( $hash, $name ) = @_;

  RainbirdController_TimerStop($hash);

  delete $modules{RainbirdController}{defptr}{CONTROLLER}
    if ( defined( $modules{RainbirdController}{defptr}{CONTROLLER} ) );

  return undef;
}

#####################################
# delete of an instance
#####################################
sub RainbirdController_Delete($$)
{
  my ( $hash, $name ) = @_;

  ### delete saved password
  setKeyValue( $hash->{TYPE} . '_' . $name . '_passwd', undef );

  return undef;
}

#####################################
# rename
#####################################
sub RainbirdController_Rename($$)
{
  my ( $new, $old ) = @_;
  my $hash = $defs{$new};

  ### save password
  RainbirdController_StorePassword( $hash, RainbirdController_ReadPassword($hash) );
  setKeyValue( $hash->{TYPE} . "_" . $old . "_passwd", undef );

  return undef;
}

#####################################
# attribute handling
#####################################
sub RainbirdController_Attr(@)
{
  my ( $cmd, $name, $attrName, $attrVal ) = @_;
  my $hash = $defs{$name};

  Log3 $name, 4, "RainbirdController ($name) - Attr was called";

  ### Attribute "disable"
  if ( $attrName eq 'disable' )
  {
    if ( $cmd eq 'set' and $attrVal eq '1' )
    {
      readingsSingleUpdate( $hash, 'state', 'inactive', 1 );
      Log3 $name, 3, "RainbirdController ($name) - disabled";

      RainbirdController_TimerStop($hash);
    } 
    elsif ( $cmd eq 'del' )
    {
      readingsSingleUpdate( $hash, 'state', 'active', 1 );
      Log3 $name, 3, "RainbirdController ($name) - enabled";

      RainbirdController_TimerRestart($hash);
    }
  }

  ### Attribute "disabledForIntervals"
  elsif ( $attrName eq 'disabledForIntervals' )
  {
    if ( $cmd eq 'set' )
    {
      return "check disabledForIntervals Syntax HH:MM-HH:MM or 'HH:MM-HH:MM HH:MM-HH:MM ...'"
        unless ( $attrVal =~ /^((\d{2}:\d{2})-(\d{2}:\d{2})\s?)+$/ );

      Log3 $name, 3, "RainbirdController ($name) - disabledForIntervals";
    } 
    elsif ( $cmd eq 'del' )
    {
      readingsSingleUpdate( $hash, 'state', 'active', 1 );
      
      Log3 $name, 3, "RainbirdController ($name) - enabled";
    }
  }

  ### Attribute "interval"
  elsif ( $attrName eq 'interval' )
  {
    if ( $cmd eq 'set' )
    {
      Log3 $name, 3, "RainbirdController ($name) - set interval: $attrVal";

      RainbirdController_TimerStop($hash);

      return 'Interval must be greater than 0'
        unless ( $attrVal > 0 );

      $hash->{INTERVAL} = $attrVal;

      RainbirdController_TimerRestart($hash);
    } 
    elsif ( $cmd eq 'del' )
    {
      RainbirdController_TimerStop($hash);
      
      $hash->{INTERVAL} = $DefaultInterval;

      Log3 $name, 3, "RainbirdController ($name) - delete user interval and set default: $hash->{INTERVAL}";

      RainbirdController_TimerRestart($hash);
    }
  }

  ### Attribute "timeout"
  elsif ( $attrName eq 'timeout' )
  {
    if ( $cmd eq 'set' )
    {
      Log3 $name, 3, "RainbirdController ($name) - set timeout: $attrVal";

      return 'timeout must be greater than 0'
        unless ( $attrVal > 0 );

      $hash->{TIMEOUT} = $attrVal;
    } 
    elsif ( $cmd eq 'del' )
    {
      $hash->{TIMEOUT} = $DefaultTimeout;

      Log3 $name, 3, "RainbirdController ($name) - delete user timeout and set default: $hash->{TIMEOUT}";
    }
  }

  ### Attribute "retries"
  elsif ( $attrName eq 'retries' )
  {
    if ( $cmd eq 'set' )
    {
      Log3 $name, 3, "RainbirdController ($name) - set retries: $attrVal";

      return 'retries must be greater or equal than 0'
        unless ( $attrVal >= 0 );

      $hash->{RETRIES} = $attrVal;
    } 
    elsif ( $cmd eq 'del' )
    {
      $hash->{RETRIES} = $DefaultRetries;

      Log3 $name, 3, "RainbirdController ($name) - delete user retries and set default: $hash->{RETRIES}";
    }
  }

  ### Attribute "expert"
  if ( $attrName eq 'expert' )
  {
    if ( $cmd eq 'set' )
    {
      if ($attrVal eq '1' )
      {
        $hash->{EXPERTMODE} = 1;
        Log3 $name, 3, "RainbirdController ($name) - expert mode enabled";
      }
      elsif ($attrVal eq '0' )
      {
        $hash->{EXPERTMODE} = 0;
        Log3 $name, 3, "RainbirdController ($name) - expert mode disabled";
      }
      else
      {
        return 'expert must be 0 or 1';
      }
    } 
    elsif ( $cmd eq 'del' )
    {
      $hash->{EXPERTMODE} = 0;
      Log3 $name, 3, "RainbirdController ($name) - expert mode disabled";
    }
  }

  ### Attribute "autocreatezones"
  if ( $attrName eq 'autocreatezones' )
  {
    if ( $cmd eq 'set' )
    {
      if ($attrVal eq '1' )
      {
        $hash->{AUTOCREATEZONES} = 1;
        Log3 $name, 3, "RainbirdController ($name) - autocreatezones enabled";
      }
      elsif ($attrVal eq '0' )
      {
        $hash->{AUTOCREATEZONES} = 0;
        Log3 $name, 3, "RainbirdController ($name) - autocreatezones disabled";
      }
      else
      {
        return 'autocreatezones must be 0 or 1';
      }
    } 
    elsif ( $cmd eq 'del' )
    {
      $hash->{AUTOCREATEZONES} = 1;
      Log3 $name, 3, "RainbirdController ($name) - autocreatezones disabled";
    }
  }

  return undef;
}

#####################################
# notify handling
#####################################
sub RainbirdController_Notify($$)
{
  my ( $hash, $dev ) = @_;
  my $name = $hash->{NAME};

  return
    if ( IsDisabled($name) );

  my $devname = $dev->{NAME};
  my $devtype = $dev->{TYPE};
  my $events  = deviceEvents( $dev, 1 );

  return
    if ( !$events );

  Log3 $name, 4, "RainbirdController ($name) - Notify";

  # process 'global' events
  if (
    ( $devtype eq 'Global' 
    and ( grep /^INITIALIZED$/, @{$events} 
       or grep /^REREADCFG$/, @{$events} 
       or grep /^DEFINED.$name$/, @{$events} 
       or grep /^MODIFIED.$name$/, @{$events}, @{$events} ) 
        )
    or ( $devtype eq 'RainbirdController'
      and ( grep /^Password.+/, @{$events} )
    ) )
  {
    RainbirdController_TimerRestart($hash);
  }

  # process 'global' events
  if (  $devtype eq 'Global'
    and $init_done
    and ( grep /^DELETEATTR.$name.disable$/, @{$events} 
       or grep /^ATTR.$name.disable.0$/, @{$events} 
       or grep /^DELETEATTR.$name.interval$/, @{$events} 
       or grep /^ATTR.$name.interval.[0-9]+/, @{$events} ) 
     )
  {
    RainbirdController_TimerRestart($hash);
  }

  return undef;
}

#####################################
# Write
#####################################
sub RainbirdController_Write($@)
{
  my ( $hash, $cmd, @args ) = @_;
  my $name = $hash->{NAME};

  Log3 $name, 4, "RainbirdController ($name) - Write was called cmd: $cmd:";
  
  RainbirdController_Set( $hash, $name, $cmd, @args);
}

#####################################
# Set
#####################################
sub RainbirdController_Set($@)
{
  my ( $hash, $name, $cmd, @args ) = @_;

  Log3 $name, 4, "RainbirdController ($name) - Set was called cmd: $cmd";

  ### Password
  if ( lc $cmd eq lc 'Password' )
  {
    return "usage: $cmd <password>"
      if ( @args != 1 );

    my $passwd = join( ' ', @args );
    RainbirdController_StorePassword( $hash, $passwd );
    RainbirdController_TimerRestart($hash);
  } 
  
  ### DeletePassword
  elsif ( lc $cmd eq lc 'DeletePassword' )
  {
    RainbirdController_DeletePassword($hash);
    RainbirdController_TimerRestart($hash);
  } 
  
  ### Stop
  elsif ( lc $cmd eq lc 'Stop' )
  {
    return "please set password first"
      if ( not defined( RainbirdController_ReadPassword($hash) ) );
    
    RainbirdController_StopIrrigation($hash);
  } 
  
  ### IrrigateZone
  elsif ( lc $cmd eq lc 'IrrigateZone' )
  {
    return "please set password first"
      if ( not defined( RainbirdController_ReadPassword($hash) ) );

    return "usage: $cmd <zone> <minutes>"
      if ( @args != 2 );

    my $zone = $args[0];
    my $minutes = $args[1];
    
    RainbirdController_ZoneIrrigate($hash, $zone, $minutes);
  } 

  ### RainDelay
  elsif ( lc $cmd eq lc 'RainDelay' )
  {
    return "please set password first"
      if ( not defined( RainbirdController_ReadPassword($hash) ) );

    return "usage: $cmd <days>"
      if ( @args != 1 );

    my $days = $args[0];
    
    RainbirdController_SetRainDelay($hash, $days);
  } 

  ### SynchronizeDateTime
  elsif ( lc $cmd eq lc 'SynchronizeDateTime' )
  {
    return "please set password first"
      if ( not defined( RainbirdController_ReadPassword($hash) ) );

    # $mday is the day of the month 
    # $mon the month in the range 0..11 , with 0 indicating January and 11 indicating December
    # $year contains the number of years since 1900
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime();
    
    my $callback = sub 
    {
      RainbirdController_SetCurrentDate($hash, $year + 1900, $mon + 1, $mday); 
    };
    RainbirdController_SetCurrentTime($hash, $hour, $min, $sec, $callback);
  } 

  ### Time
  elsif ( lc $cmd eq lc 'Time' )
  {
    return "please set password first"
      if ( not defined( RainbirdController_ReadPassword($hash) ) );

    return "usage: $cmd <hour>:<minute>[:<second>]"
      if ( @args != 1 );

    my ($msg, $hour, $min, $sec) = RainbirdController_GetTimeSpec($args[0]);
    
    if( defined($msg) )
    {
      return $msg;
    }    
    
    RainbirdController_SetCurrentTime($hash, $hour, $min, $sec);
  } 

  ### Date
  elsif ( lc $cmd eq lc 'Date' )
  {
    return "please set password first"
      if ( not defined( RainbirdController_ReadPassword($hash) ) );

    return "usage: $cmd <year>-<month>-<day>"
      if ( @args != 1 );

    my ($msg, $year, $month, $day) = RainbirdController_GetDateSpec($args[0]);
    
    if( defined($msg) )
    {
      return $msg;
    }    
    
    RainbirdController_SetCurrentDate($hash, $year, $month, $day);
  } 

  ### Update
  elsif ( lc $cmd eq lc 'Update' )
  {
    return "please set password first"
      if ( not defined( RainbirdController_ReadPassword($hash) ) );
    
    RainbirdController_GetDeviceState($hash);
  } 

  ### FactoryReset
  elsif ( lc $cmd eq lc 'FactoryReset' )
  {
    return "please set password first"
      if ( not defined( RainbirdController_ReadPassword($hash) ) );
    
    RainbirdController_FactoryRsete($hash);
  } 

  ### TestCMD
  elsif ( lc $cmd eq lc 'TestCMD' )
  {
    return "please set password first"
      if ( not defined( RainbirdController_ReadPassword($hash) ) );
    
    return "usage: $cmd <command> [<arg1>, <arg2>]"
      if ( @args < 1 );

    ### first entry is commandstring
    ### others are parameters
    my $command = shift(@args);
    
    RainbirdController_TestCMD($hash, $command, \@args);
  } 

  ### TestRAW
  elsif ( lc $cmd eq lc 'TestRAW' )
  {
    return "please set password first"
      if ( not defined( RainbirdController_ReadPassword($hash) ) );
    
    return "usage: $cmd <command> <raw hex string>"
      if ( @args != 1 );

    my $rawHexString = $args[0];
    
    RainbirdController_TestRAW($hash, $rawHexString);
  } 

  ### ZoneGetSchedule
  elsif ( lc $cmd eq lc 'ZoneGetSchedule' )
  {
    return "please set password first"
      if ( not defined( RainbirdController_ReadPassword($hash) ) );

    return "usage: $cmd <zone>"
      if ( @args != 1 );
    
    my $zone = $args[0];
    RainbirdController_ZoneGetSchedule($hash, $zone);
  } 
  

  ### ClearReadings
  elsif ( lc $cmd eq lc 'ClearReadings' )
  {
    my @cH = ($hash);
    push @cH,$defs{$hash->{$_}} foreach(grep /^channel/,keys %{$hash});
    delete $_->{READINGS} foreach (@cH);
  } 

  ### else
  else
  {
    my $list = "";

    if ( defined( RainbirdController_ReadPassword($hash) ))
    {
      $list .= " ClearReadings:noArg";
      $list .= " DeletePassword:noArg";
      $list .= " RainDelay";
      $list .= " Stop:noArg";
      $list .= " SynchronizeDateTime:noArg";
      $list .= " Date";
      $list .= " Time";
      $list .= " Update:noArg";
      $list .= " IrrigateZone" if($hash->{EXPERTMODE});
      $list .= " FactoryReset:noArg" if($hash->{EXPERTMODE});
      $list .= " TestCMD" if($hash->{EXPERTMODE});
      $list .= " TestRAW" if($hash->{EXPERTMODE});
    }
    else
    {
      $list .= " Password";
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

  Log3 $name, 4, "RainbirdController ($name) - Get was called cmd: $cmd";

  ### DeviceState
  if ( lc $cmd eq lc 'DeviceState' )
  {
    return "please set password first"
      if ( not defined( RainbirdController_ReadPassword($hash) ) );
    
    RainbirdController_GetDeviceState($hash);
  } 
  
  ### DeviceInfo
  elsif ( lc $cmd eq lc 'DeviceInfo' )
  {
    return "please set password first"
      if ( not defined( RainbirdController_ReadPassword($hash) ) );
    
    #RainbirdController_GetDeviceInfo($hash);
    RainbirdController_GetDeviceState($hash);
  } 
  
  ### ModelAndVersion
  elsif ( lc $cmd eq lc 'ModelAndVersion' )
  {
    return "please set password first"
      if ( not defined( RainbirdController_ReadPassword($hash) ) );
    
    RainbirdController_GetModelAndVersion($hash);
  } 
  
  ### AvailableZones
  elsif ( lc $cmd eq lc 'AvailableZones' )
  {
    return "please set password first"
      if ( not defined( RainbirdController_ReadPassword($hash) ) );
    
    RainbirdController_GetAvailableZones($hash);
  } 
  
  ### SerialNumber
  elsif ( lc $cmd eq lc 'SerialNumber' )
  {
    return "please set password first"
      if ( not defined( RainbirdController_ReadPassword($hash) ) );
    
    RainbirdController_GetSerialNumber($hash);
  } 
  
  ### Time
  elsif ( lc $cmd eq lc 'Time' )
  {
    return "please set password first"
      if ( not defined( RainbirdController_ReadPassword($hash) ) );
    
    RainbirdController_GetCurrentTime($hash);
  } 
  
  ### Date
  elsif ( lc $cmd eq lc 'Date' )
  {
    return "please set password first"
      if ( not defined( RainbirdController_ReadPassword($hash) ) );
    
    RainbirdController_GetCurrentDate($hash);
  } 
  
  ### RainsensorState
  elsif ( lc $cmd eq lc 'RainsensorState' )
  {
    return "please set password first"
      if ( not defined( RainbirdController_ReadPassword($hash) ) );
    
    RainbirdController_GetRainSensorState($hash);
  } 
  
  ### RainDelay
  elsif ( lc $cmd eq lc 'RainDelay' )
  {
    return "please set password first"
      if ( not defined( RainbirdController_ReadPassword($hash) ) );
    
    RainbirdController_GetRainDelay($hash);
  } 
  
  ### CurrentIrrigation
  elsif ( lc $cmd eq lc 'CurrentIrrigation' )
  {
    return "please set password first"
      if ( not defined( RainbirdController_ReadPassword($hash) ) );
    
    RainbirdController_GetCurrentIrrigation($hash);
  } 
  
  ### IrrigationState
  elsif ( lc $cmd eq lc 'IrrigationState' )
  {
    return "please set password first"
      if ( not defined( RainbirdController_ReadPassword($hash) ) );
    
    RainbirdController_GetActiveStation($hash);
  } 
  
  ### ZoneSchedule
  elsif ( lc $cmd eq lc 'ZoneSchedule' )
  {
    return "please set password first"
      if ( not defined( RainbirdController_ReadPassword($hash) ) );

    return "usage: $cmd <zone>"
      if ( @args != 1 );
    
    my $zone = $args[0];
    RainbirdController_ZoneGetSchedule($hash, $zone);
  } 
  
  ### CommandSupport
  elsif ( lc $cmd eq lc 'CommandSupport' )
  {
    return "please set password first"
      if ( not defined( RainbirdController_ReadPassword($hash) ) );
    
    return "usage: $cmd <hexcommand>"
      if ( @args != 1 );

    my $command = $args[0];
    RainbirdController_GetCommandSupport($hash, $command);
  } 
  
  ### DecryptHEX
  elsif ( lc $cmd eq lc 'DecryptHEX' )
  {
    return "please set password first"
      if ( not defined( RainbirdController_ReadPassword($hash) ) );

    readingsBeginUpdate($hash);
    
    ### byte[] arrOutput = { 0x2A, 0xD5, 0x4B, 0xE0, 0x84, 0x83, 0xFC, 0x71, 0x31, 0x4D, 0xB3, 0x29, 0x18, 0xF1, 0xEE, 0xDB, 0x8F, 0xE5, 0xD7, 0xFF, 0x21, 0xBA, 0x9D, 0x78, 0x08, 0x05, 0xD9, 0x99, 0x56, 0x81, 0x86, 0x5E, 0x98, 0xC3, 0x6B, 0xCD, 0x4A, 0x10, 0xF8, 0xE9, 0xDF, 0x49, 0x21, 0x73, 0x4D, 0x09, 0xF6, 0x90, 0x91, 0x06, 0x3A, 0xE8, 0xB2, 0x43, 0x9E, 0xEA, 0x31, 0x8A, 0x1D, 0x5C, 0x44, 0x98, 0xEA, 0x06, 0xD7, 0x1D, 0xBE, 0xED, 0xBC, 0x23, 0xF9, 0x35, 0x3C, 0x06, 0xD7, 0xAC, 0x5A, 0xBD, 0x47, 0xA2, 0x01, 0xFF, 0x2A, 0x90, 0xA1, 0x51, 0x22, 0x44, 0x98, 0xB8, 0x21, 0xB7, 0xC6, 0xC8, 0x67, 0x90, 0xAA, 0x41, 0xBB, 0x90, 0xE2, 0x6C, 0x9C, 0xDE, 0x1A, 0x3D, 0x90, 0x56, 0xDA, 0x94, 0x3B, 0xF3, 0x35, 0x18, 0x7A, 0x87, 0x64, 0x05, 0x7E, 0xDE, 0xE4, 0x27, 0xC4, 0x87, 0xC9, 0x4B, 0xFC, 0x6B, 0x56, 0x3A, 0x5D, 0x6B, 0x96, 0x3B, 0x84, 0xE7, 0x37, 0xBD, 0xF4, 0xB4, 0x2A, 0x62, 0x99, 0x5C };
    ### args like 2A D5 4B E0 84 83 FC 71 31 4D B3 29 18 F1 EE DB 8F E5 D7 FF 21 BA 9D 78 08 05 D9 99 56 81 86 5E 98 C3 6B CD 4A 10 F8 E9 DF 49 21 73 4D 09 F6 90 91 06 3A E8 B2 43 9E EA 31 8A 1D 5C 44 98 EA 06 D7 1D BE ED BC 23 F9 35 3C 06 D7 AC 5A BD 47 A2 01 FF 2A 90 A1 51 22 44 98 B8 21 B7 C6 C8 67 90 AA 41 BB 90 E2 6C 9C DE 1A 3D 90 56 DA 94 3B F3 35 18 7A 87 64 05 7E DE E4 27 C4 87 C9 4B FC 6B 56 3A 5D 6B 96 3B 84 E7 37 BD F4 B4 2A 62 99 5C
    my $string = uc(join('', @args));

    #readingsBulkUpdate( $hash, 'string', $string, 1 );
    
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
    
    #readingsBulkUpdate( $hash, 'stringbetween', $string, 1 );

    ### replace 0x|,
    while ($string =~ s/(0X)|,//) {}
    #readingsBulkUpdate( $hash, 'stringreplace', $string, 1 );

    my $bytearray = pack("H*", $string);
    #readingsBulkUpdate( $hash, 'bytearray', (sprintf("%v02X", $bytearray) =~ s/\.//rg), 1 );
    
    ### decrypt
    my $decryptedData = eval { RainbirdController_DecryptData($hash, $bytearray, RainbirdController_ReadPassword($hash)) };
  
    if ($@)
    {
      readingsBulkUpdate( $hash, 'decryptedData', $@, 1 );
    }
    else
    {  
      readingsBulkUpdate( $hash, 'decryptedData', $decryptedData, 1 );
    }

    readingsEndUpdate( $hash, 1 );
  } 
  
  ### else
  else
  {
    my $list = "";
    
    if ( defined( RainbirdController_ReadPassword($hash) ) )
    {
      $list .= " DeviceState:noArg" if($hash->{EXPERTMODE});
      $list .= " DeviceInfo:noArg" if($hash->{EXPERTMODE});
      $list .= " ModelAndVersion:noArg" if($hash->{EXPERTMODE});
      $list .= " AvailableZones:noArg" if($hash->{EXPERTMODE});
      $list .= " SerialNumber:noArg" if($hash->{EXPERTMODE});
      $list .= " Date:noArg" if($hash->{EXPERTMODE});
      $list .= " Time:noArg" if($hash->{EXPERTMODE});
      $list .= " RainSensorState:noArg" if($hash->{EXPERTMODE});
      $list .= " RainDelay:noArg" if($hash->{EXPERTMODE});
      $list .= " CurrentIrrigation:noArg" if($hash->{EXPERTMODE});
      $list .= " IrrigationState:noArg" if($hash->{EXPERTMODE});
      $list .= " ZoneSchedule" if($hash->{EXPERTMODE});
      $list .= " CommandSupport" if($hash->{EXPERTMODE});
      $list .= " DecryptHEX" if($hash->{EXPERTMODE});
    }
    
    return "Unknown argument $cmd, choose one of $list";
  }
}

#####################################
# stopps the internal timer
#####################################
sub RainbirdController_TimerStop($)
{
  my ( $hash ) = @_;
  my $name = $hash->{NAME};

  Log3 $name, 4, "RainbirdController ($name) - timerStop";

  RemoveInternalTimer($hash);
  $hash->{TIMERON} = 0;
}

#####################################
# (re)starts the internal timer
#####################################
sub RainbirdController_TimerRestart($)
{
  my ( $hash ) = @_;
  my $name = $hash->{NAME};

  RainbirdController_TimerStop($hash);

  if ( IsDisabled($name) )
  {
    readingsSingleUpdate( $hash, 'state', 'disabled', 1 );

    Log3 $name, 3, "RainbirdController ($name) - timerRestart: device is disabled";
    return;
  } 

  if ( not RainbirdController_ReadPassword($hash) )
  {
    readingsSingleUpdate( $hash, 'state', 'no password', 1 );

    Log3 $name, 3, "RainbirdController ($name) - timerRestart: no password";
    return;
  } 

  Log3 $name, 4, "RainbirdController ($name) - timerRestart";

  ### if RainbirdController_Function fails no callback function is called
  ### so reload timer for next try
  InternalTimer( gettimeofday() + $hash->{RETRYINTERVAL}, \&RainbirdController_TimerRestart, $hash );
  $hash->{TIMERON} = 1;

  RainbirdController_TimerLoop($hash); 
}

#####################################
# callback function of the internal timer
#####################################
sub RainbirdController_TimerLoop($)
{
  my ( $hash ) = @_;
  my $name = $hash->{NAME};

  RainbirdController_TimerStop($hash);

  if ( IsDisabled($name) )
  {
    readingsSingleUpdate( $hash, 'state', 'disabled', 1 );

    Log3 $name, 3, "RainbirdController ($name) - TimerLoop: device is disabled";
    return;
  } 

  Log3 $name, 4, "RainbirdController ($name) - TimerLoop";

  ### if RainbirdController_Function fails no callback function is called
  ### so reload timer for next try
  InternalTimer( gettimeofday() + $hash->{RETRYINTERVAL}, \&RainbirdController_TimerLoop, $hash );
  $hash->{TIMERON} = 1;
  
  ### calculate nextInterval
  my $nextInterval = gettimeofday() + $hash->{INTERVAL};
  
  ### callback to set the next interval on success
  my $reloadTimer = sub 
  {
    ### reload timer
    RemoveInternalTimer($hash);
    InternalTimer( $nextInterval, \&RainbirdController_TimerLoop, $hash );
    $hash->{TIMERON} = 1;
  };

  RainbirdController_GetDeviceState($hash, $reloadTimer);
}

#####################################
# gets the dynamic values of the device
#####################################
sub RainbirdController_GetDeviceState($;$)
{
  my ( $hash, $callback ) = @_;
  my $name = $hash->{NAME};

  Log3 $name, 4, "RainbirdController ($name) - GetDeviceState";

  # definition of the callback chain
  # each function calls the given callback in their resultcallback
  
  my $runCallback = sub 
  {
    # if there is a callback then call it
    if( defined($callback) )
    {
      Log3 $name, 4, "RainbirdController ($name) - GetDeviceState callback";
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
  
  my $getCurrentTime = sub { RainbirdController_GetCurrentTime($hash, $getIrrigationState); };
  my $getCurrentDate = sub { RainbirdController_GetCurrentDate($hash, $getCurrentTime); };
  my $getRainSensorState = sub { RainbirdController_GetRainSensorState($hash, $getCurrentDate); };
  my $getCurrentIrrigation = sub { RainbirdController_GetCurrentIrrigation($hash, $getRainSensorState); };
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
    
  my $command = "ModelAndVersion";
  
  Log3 $name, 4, "RainbirdController ($name) - GetModelAndVersion";

  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - GetModelAndVersion resultCallback";
    
    if( defined($result) )
    {
      readingsBeginUpdate($hash);

      if( defined($result->{"modelID"}) )
      {
        my $modelId = $result->{"modelID"};
        
        $hash->{MODELID} = $modelId;
        
        my $model = $KnownModels{$modelId};

        ### set known model name
        if( defined($model) )
        {
          $hash->{MODEL} = $model;
        }
        else
        {
          $hash->{MODEL} = "unknown";
        }
      }

      if( defined($result->{"protocolRevisionMajor"}) )
      {
        $hash->{PROTOCOLREVISIONMAJOR} = $result->{"protocolRevisionMajor"};
      }

      if( defined($result->{"protocolRevisionMinor"}) )
      {
        $hash->{PROTOCOLREVISIONMINOR} = $result->{"protocolRevisionMinor"};;
      }

      readingsEndUpdate( $hash, 1 );
    }

    # if there is a callback then call it
    if( defined($callback) )
    {
      Log3 $name, 4, "RainbirdController ($name) - GetModelAndVersion callback";
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
  
  my $command = "AvailableStations";   
  my $mask = sprintf("%%0%dX", $ControllerResponses{"83"}->{"setStations"}->{"length"});

  Log3 $name, 4, "RainbirdController ($name) - GetAvailableZones mask: $mask";
  
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - GetAvailableZones lambda";
    
    if( defined($result) )
    {
      readingsBeginUpdate($hash);

      if( defined($result->{"setStations"}) )
      {
        my $zonesAvailableCount = RainbirdController_GetAvailableZoneCountFromRaw($result->{"setStations"});
        my $zonesAvailableMask = RainbirdController_GetAvailableZoneMaskFromRaw($result->{"setStations"});

        $hash->{ZONESAVAILABLE} = 1;
        $hash->{ZONESAVAILABLECOUNT} = $zonesAvailableCount;
        $hash->{ZONESAVAILABLEMASK} = $zonesAvailableMask;

        #readingsBulkUpdate( $hash, 'zonesAvailable', $zonesAvailableCount);
      }
      if( defined($result->{"pageNumber"}) )
      {
        # readingsBulkUpdate( $hash, 'pageNumber', $result->{"pageNumber"}, 1 );
      }

      readingsEndUpdate( $hash, 1 );

      ### encode $result to json string
      my $jsonString = eval{encode_json($result)};

      if($@)
      {
        Log3 $name, 2, "RainbirdController ($name) - error while request: $@";
      }
      else
      {
        # dispatch to RainbirdZone::RainbirdZone_Parse()
        Dispatch( $hash, $jsonString );
      }
    }

    # if there is a callback then call it
    if( defined($callback) )
    {
      Log3 $name, 4, "RainbirdController ($name) - GetAvailableZones callback";
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
  
  my $command = "CommandSupport";
     
  Log3 $name, 4, "RainbirdController ($name) - GetCommandSupport";
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - GetCommandSupport lambda";
    
    if( defined($result) )
    {
      readingsBeginUpdate($hash);

      if( defined($result->{"support"}) and
        defined($result->{"commandEcho"}))
      {
        $hash->{$CMDSUPPORTPREFIX . $result->{"commandEcho"}} = $result->{"support"};

        #readingsBulkUpdate( $hash, 'commandSupport', $result->{"support"}, 1 );
        #readingsBulkUpdate( $hash, 'commandEcho', $result->{"commandEcho"}, 1 );
      }

      readingsEndUpdate( $hash, 1 );
    }

    # if there is a callback then call it
    if( defined($callback) )
    {
      Log3 $name, 4, "RainbirdController ($name) - GetCommandSupport callback";
      $callback->();
    }
  }; 
  
  ### check if value start with 0x  
  $askCommand = lc $askCommand;
  if($askCommand =~ m/^0x[0-9A-F]+$/i) 
  {
    # send command
    RainbirdController_Command($hash, $resultCallback, $command, hex($askCommand) );
  }
  else
  {
    # send command
    RainbirdController_Command($hash, $resultCallback, $command, int($askCommand) );
  }
}

#####################################
# SetWaterBudget
#####################################
sub RainbirdController_SetWaterBudget($$;$)
{
  my ( $hash, $budget, $callback ) = @_;
  my $name = $hash->{NAME};
    
  my $command = "WaterBudget";
  Log3 $name, 4, "RainbirdController ($name) - SetWaterBudget";
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - SetWaterBudget lambda";
    
    if( defined($result) )
    {
      readingsBeginUpdate($hash);

      if( defined($result->{"programCode"}) )
      {
        readingsBulkUpdate( $hash, 'programCode', $result->{"programCode"}, 1 );
      }
      if( defined($result->{"seasonalAdjust"}) )
      {
        readingsBulkUpdate( $hash, 'seasonalAdjust', $result->{"seasonalAdjust"}, 1 );
      }

      readingsEndUpdate( $hash, 1 );
    }

    # if there is a callback then call it
    if( defined($callback) )
    {
      Log3 $name, 4, "RainbirdController ($name) - SetWaterBudget callback";
      $callback->();
    }
  }; 
    
  # send command
  RainbirdController_Command($hash, $resultCallback, $command, $budget );
}

#####################################
# GetRainSensorState
#####################################
sub RainbirdController_GetRainSensorState($;$)
{
  my ( $hash, $callback ) = @_;
  my $name = $hash->{NAME};
  
  my $command = "CurrentRainSensorState";
  
  Log3 $name, 4, "RainbirdController ($name) - GetRainSensorState";
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - GetRainSensorState lambda";
    
    if( defined($result) )
    {
      readingsBeginUpdate($hash);

      if( defined($result->{"sensorState"}) )
      {
        readingsBulkUpdate( $hash, 'rainSensorState', $result->{"sensorState"}, 1 );
      }

      readingsEndUpdate( $hash, 1 );
    }

    # if there is a callback then call it
    if( defined($callback) )
    {
      Log3 $name, 4, "RainbirdController ($name) - GetRainSensorState callback";
      $callback->();
    }
  }; 
    
  # send command
  RainbirdController_Command($hash, $resultCallback, $command );
}

#####################################
# GetSerialNumber
#####################################
sub RainbirdController_GetSerialNumber($;$)
{
  my ( $hash, $callback ) = @_;
  my $name = $hash->{NAME};
    
  my $command = "SerialNumber";
  
  Log3 $name, 4, "RainbirdController ($name) - GetSerialNumber";
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - GetSerialNumber lambda";
    
    if( defined($result) )
    {
      readingsBeginUpdate($hash);

      if( defined($result->{"serialNumber"}) )
      {
        $hash->{SERIALNUMBER} = sprintf("%08s", $result->{"serialNumber"});
      }

      readingsEndUpdate( $hash, 1 );
    }

    # if there is a callback then call it
    if( defined($callback) )
    {
      Log3 $name, 4, "RainbirdController ($name) - GetSerialNumber callback";
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
    
  my $command = "CurrentTimeGet";
  
  Log3 $name, 4, "RainbirdController ($name) - GetCurrentTime";
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - GetCurrentTime lambda";
    
    if( defined($result) )
    {
      readingsBeginUpdate($hash);

      if( defined($result->{"hour"}) and
        defined($result->{"minute"}) and
        defined($result->{"second"}) )
      {
        readingsBulkUpdate( $hash, 'currentTime', sprintf("%02s:%02s:%02s", $result->{"hour"}, $result->{"minute"}, $result->{"second"}), 1 );
      }

      readingsEndUpdate( $hash, 1 );
    }

    # if there is a callback then call it
    if( defined($callback))
    {
      Log3 $name, 4, "RainbirdController ($name) - GetCurrentTime callback";
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
    
  my $command = "CurrentTimeSet";
  
  Log3 $name, 4, "RainbirdController ($name) - SetCurrentTime: $hour:$minute:$second";
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - SetCurrentTime lambda";
    
    if( defined($result) )
    {
      readingsBeginUpdate($hash);

      readingsEndUpdate( $hash, 1 );
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
  
  my $command = "CurrentDateGet";
     
  Log3 $name, 4, "RainbirdController ($name) - GetCurrentDate";
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - GetCurrentDate lambda";
    
    if( defined($result) )
    {
      readingsBeginUpdate($hash);

      if( defined($result->{"year"}) and
        defined($result->{"month"}) and
        defined($result->{"day"}) )
      {
        readingsBulkUpdate( $hash, 'currentDate', sprintf("%04s-%02s-%02s", $result->{"year"}, $result->{"month"}, $result->{"day"}), 1 );
      }

      readingsEndUpdate( $hash, 1 );
    }

    # if there is a callback then call it
    if( defined($callback) )
    {
      Log3 $name, 4, "RainbirdController ($name) - GetCurrentDate callback";
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
    
  my $command = "CurrentDateSet";
  
  Log3 $name, 4, "RainbirdController ($name) - SetCurrentDate: $year-$month-$day";
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - SetCurrentDate lambda";
    
    if( defined($result) )
    {
      readingsBeginUpdate($hash);

      readingsEndUpdate( $hash, 1 );
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
  
  my $command = "CurrentIrrigationState";
  
  Log3 $name, 4, "RainbirdController ($name) - GetCurrentIrrigation";
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - GetCurrentIrrigation lambda";
    
    if( defined($result) )
    {
      readingsBeginUpdate($hash);

      if( defined($result->{"irrigationState"}))
      {
        readingsBulkUpdate( $hash, 'irrigationState', $result->{"irrigationState"}, 1 );
      }

      readingsEndUpdate( $hash, 1 );
    }

    # if there is a callback then call it
    if( defined($callback) )
    {
      Log3 $name, 4, "RainbirdController ($name) - GetCurrentIrrigation callback";
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
    
  my $command = "CurrentStationsActive";
  my $mask = sprintf("%%0%dX", $ControllerResponses{"BF"}->{"activeStations"}->{"length"});

  Log3 $name, 4, "RainbirdController ($name) - GetActiveStation mask: $mask";
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - GetActiveStation lambda";
    
    if( defined($result) )
    {
      readingsBeginUpdate($hash);

      if( defined($result->{"activeStations"}))
      {
        my $zoneActive = RainbirdController_GetZoneFromRaw($result->{"activeStations"});
        my $zoneActiveMask = 1 << ($zoneActive - 1);

        $hash->{ZONEACTIVE} = $zoneActive;
        $hash->{ZONEACTIVEMASK} = $zoneActiveMask;
        
        readingsBulkUpdate( $hash, 'zoneActive', $zoneActive);

        if( $zoneActive == 0 )
        {
          readingsBulkUpdate( $hash, 'state', 'ready', 1 );
        }
        else
        {
          readingsBulkUpdate( $hash, 'state', 'irrigating', 1 );
        }  
      }

      readingsEndUpdate( $hash, 1 );

      ### encode $result to json string
      my $jsonString = eval{encode_json($result)};

      if($@)
      {
        Log3 $name, 2, "RainbirdController ($name) - GetActiveStation error while request: $@";
      }
      else
      {
        # dispatch to RainbirdZone::RainbirdZone_Parse()
        Dispatch( $hash, $jsonString );
      }
    }

    # if there is a callback then call it
    if( defined($callback) )
    {
      Log3 $name, 4, "RainbirdController ($name) - GetActiveStation callback";
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
    
  my $command = "GetIrrigationState";

  Log3 $name, 4, "RainbirdController ($name) - GetIrrigationState";
    
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
    
    Log3 $name, 4, "RainbirdController ($name) - GetIrrigationState lambda";
    
    if( defined($result) )
    {
      readingsBeginUpdate($hash);

      if( defined($result->{"activeZone"}))
      {
        my $zoneActive = $result->{"activeZone"};
        my $zoneActiveMask = 1 << ($zoneActive - 1);
        
        $hash->{ZONEACTIVE} = $zoneActive;
        $hash->{ZONEACTIVEMASK} = $zoneActiveMask;
        
        readingsBulkUpdate( $hash, 'zoneActive', $zoneActive);

        if( $zoneActive == 0 )
        {
          readingsBulkUpdate( $hash, 'state', 'ready', 1 );
        }
        else
        {
          readingsBulkUpdate( $hash, 'state', 'irrigating', 1 );
        }  
      }

      if( defined($result->{"secondsLeft"}))
      {
        my $secondsLeft = $result->{"secondsLeft"};
        $hash->{ZONEACTIVESECONDSLEFT} = $secondsLeft;
        
        readingsBulkUpdate( $hash, 'irrigationSecondsLeft', $secondsLeft, 1 );
      }

      readingsEndUpdate( $hash, 1 );

      # save result hash in helper
      $hash->{helper}{'IrrigationState'} = $result;

      ### encode $result to json string
      my $jsonString = eval{encode_json($result)};

      if($@)
      {
        Log3 $name, 2, "RainbirdController ($name) - GetIrrigationState error while request: $@";
      }
      else
      {
        # dispatch to RainbirdZone::RainbirdZone_Parse()
        Dispatch( $hash, $jsonString );
      }
    }

    # if there is a callback then call it
    if( defined($callback) )
    {
      Log3 $name, 4, "RainbirdController ($name) - GetIrrigationState callback";
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
    
  my $command = "RainDelayGet";
  
  Log3 $name, 4, "RainbirdController ($name) - GetRainDelay";
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - GetRainDelay lambda";
    
    if( defined($result) )
    {
      readingsBeginUpdate($hash);

      if( defined($result->{"delaySetting"}) )
      {
        readingsBulkUpdate( $hash, 'rainDelay', $result->{"delaySetting"}, 1 );
      }

      readingsEndUpdate( $hash, 1 );
    }

    # if there is a callback then call it
    if( defined($callback) )
    {
      Log3 $name, 4, "RainbirdController ($name) - GetRainDelay callback";
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
  
  my $command = "RainDelaySet";
    
  Log3 $name, 4, "RainbirdController ($name) - SetRainDelay";
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - SetRainDelay lambda";
    
    if( defined($result) )
    {
      readingsBeginUpdate($hash);

      readingsEndUpdate( $hash, 1 );
    }

    # update reading
    RainbirdController_GetRainDelay($hash, $callback);
  }; 
    
  # send command
  RainbirdController_Command($hash, $resultCallback, $command, $days );
}

#####################################
# ZoneIrrigate
#####################################
sub RainbirdController_ZoneIrrigate($$$;$)
{
  my ( $hash, $zone, $minutes, $callback ) = @_;
  my $name = $hash->{NAME};
  
  my $command = "ManuallyRunStation";
    
  Log3 $name, 4, "RainbirdController ($name) - ZoneIrrigate[$zone]";
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - ZoneIrrigate[$zone] lambda";
    
    if( defined($result) )
    {
      readingsBeginUpdate($hash);

      readingsEndUpdate( $hash, 1 );
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
  
  my $command = "CurrentSchedule";
    
  Log3 $name, 4, "RainbirdController ($name) - ZoneGetSchedule[$zone]";
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - ZoneGetSchedule[$zone] lambda";
    
    if( defined($result) )
    {
      readingsBeginUpdate($hash);

      readingsEndUpdate( $hash, 1 );

      # "A0" => {"length" =>  4, "type" => "CurrentScheduleResponse", 
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
        Log3 $name, 2, "RainbirdController ($name) - ZoneGetSchedule[$zone] error while request: $@";
      }
      else
      {
        # dispatch to RainbirdZone::RainbirdZone_Parse()
        Dispatch( $hash, $jsonString );
      }
    }

    # if there is a callback then call it
    if( defined($callback) )
    {
      Log3 $name, 4, "RainbirdController ($name) - ZoneGetSchedule[$zone] callback";
      $callback->();
    }
  }; 
    
  # send command
  RainbirdController_Command($hash, $resultCallback, $command, $zone );
}

#####################################
# ZoneTest
#####################################
sub RainbirdController_ZoneTest($$;$)
{
  my ( $hash, $zone, $callback ) = @_;
  my $name = $hash->{NAME};
  
  my $command = "TestStations";
    
  Log3 $name, 4, "RainbirdController ($name) - ZoneTest[$zone]";
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - ZoneTest[$zone] lambda";

    if( defined($result) )
    {
      readingsBeginUpdate($hash);

      readingsEndUpdate( $hash, 1 );
    }

    # if there is a callback then call it
    if( defined($callback) )
    {
      Log3 $name, 4, "RainbirdController ($name) - ZoneTest[$zone] callback";
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
  
  my $command = "ManuallyRunProgram";
    
  Log3 $name, 4, "RainbirdController ($name) - SetProgram";
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - SetProgram lambda";
    
    if( defined($result) )
    {
      readingsBeginUpdate($hash);

      readingsEndUpdate( $hash, 1 );
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
  
  my $command = "StopIrrigation";
    
  Log3 $name, 4, "RainbirdController ($name) - StopIrrigation";
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - StopIrrigation lambda";
    
    if( defined($result) )
    {
      readingsBeginUpdate($hash);

      readingsEndUpdate( $hash, 1 );
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
  
  my $command = "FactoryReset";
    
  Log3 $name, 4, "RainbirdController ($name) - FactoryReset";
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - FactoryReset lambda";
    
    if( defined($result) )
    {
      readingsBeginUpdate($hash);

      readingsEndUpdate( $hash, 1 );
    }

    # update reading activeStations
    RainbirdController_GetActiveStation($hash, $callback);
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
  
  Log3 $name, 4, "RainbirdController ($name) - TestCMD";
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - TestCMD lambda";
    
    if( defined($result) )
    {
      readingsBeginUpdate($hash);

      readingsBulkUpdate( $hash, 'testCMDResult', encode_json($result), 1 );

      readingsEndUpdate( $hash, 1 );
    }

     RainbirdController_GetDeviceState($hash, $callback); 
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
  
  Log3 $name, 4, "RainbirdController ($name) - TestRAW";
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - TestRAW lambda";
    
    if( defined($result) )
    {
      readingsBeginUpdate($hash);

#      readingsBulkUpdate( $hash, 'testRAWSend', encode_json(decode_json($sendData)), 1 );
      readingsBulkUpdate( $hash, 'testRAWSend', JSON->new->canonical(1)->pretty->encode(decode_json($sendData)), 1 );
      readingsBulkUpdate( $hash, 'testRAWResult',  JSON->new->canonical(1)->pretty->encode($result), 1 );

      readingsEndUpdate( $hash, 1 );
    }

    # RainbirdController_GetDeviceState($hash, $callback); 
  }; 
    
  # send command
  RainbirdController_Request($hash, $resultCallback, undef, $rawHexString );
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
 
  Log3 $name, 4, "RainbirdController ($name) - Command: \"$command\"";
  
  # find controllercommand-structure in hash "ControllerCommands"
  my $request_command = $command . "Request";
  my $command_set = $ControllerCommands{$request_command};

  if( defined( $command_set ) )
  {
    my $commandString = $command_set->{"command"};
    my $cmdKey = $CMDSUPPORTPREFIX . $commandString;
  
    ### check if support of command was checked before
    if(not defined($hash->{$cmdKey}))
    {
      ### callback - this function have to be recalled
      my $commandCallback = sub { RainbirdController_Command($hash, $resultCallback, $command, @args); };

      ### check support of the command und recall this function 
      RainbirdController_GetCommandSupport($hash, "0x" . $commandString, $commandCallback);
      return; # callback is handled
    }
    ### command is supported
    elsif($hash->{$cmdKey} == 1)
    {
      # encode data
      my $data = RainbirdController_EncodeData($hash, $command_set, @args);  

      if(defined($data))
      {
        ### send request to device 
        RainbirdController_Request($hash, $resultCallback, $command_set->{"response"}, $data );
        return; # callback is handled
      }
      else
      {
        Log3 $name, 2, "RainbirdController ($name) - Command: data not defined";
      }  
    }
    ### command is not supported
    {
      Log3 $name, 2, "RainbirdController ($name) - Command: $commandString is not supported";
    }
  }
  else
  {
    Log3 $name, 2, "RainbirdController ($name) - Command: ControllerCommand \"" . $request_command . "\" not found!";
  }

  # is there a callback function?
  if(defined($resultCallback))
  {
    Log3 $name, 4, "RainbirdController ($name) - Command: calling lambda function";
    
    $resultCallback->(undef, undef);
  } 
}

#####################################
# Request
#####################################
sub RainbirdController_Request($$$$)
{
  my ( $hash, $resultCallback, $expectedResponse_id, $data ) = @_;
  my $name = $hash->{NAME};

  my $sendReceive = undef; 
  $sendReceive = sub ($;$)
  {
    my ( $leftRetries, $retryCallback ) = @_;
    
    my $request_id = ++$hash->{REQUESTID};
  
    my $send_data = 
    '{
      "id":' . $request_id . ',
      "jsonrpc":"2.0",
      "method":"tunnelSip",
      "params":
      {
        "data":"' . $data . '",
        "length":"' . (length($data) / 2) . '"
      }
    }';
  
    Log3 $name, 5, "RainbirdController ($name) - Request[ID:$request_id] send_data: $send_data";

    ### encrypt data
    my $encrypt_data = RainbirdController_EncryptData($hash, $send_data, RainbirdController_ReadPassword($hash));          

    if(defined($encrypt_data))
    {  
      ### post data 
      my $uri = 'http://' . $hash->{HOST} . '/stick';
      my $method = 'POST';
      my $payload = $encrypt_data;
      my $header = $HEAD;
      my $request_timestamp = gettimeofday();

      Log3 $name, 5, "RainbirdController ($name) - Request[ID:$request_id] Send with URL: $uri, HEADER: $header, DATA: $payload, METHOD: $method";
  
      HttpUtils_NonblockingGet(
      {
        hash      => $hash,
    
        url       => $uri,
        method    => $method,
        header    => $header, # for debugging: . "\nRequestId: " . $request_id,
        data      => $payload,
        timeout   => $hash->{TIMEOUT},
        doTrigger => 1,
        callback  => \&RainbirdController_ErrorHandling,
    
        request_id => $request_id,
        request_timestamp => $request_timestamp,
      
        expectedResponse_id => $expectedResponse_id,
        sendData => $send_data,
      
        leftRetries => $leftRetries,
        retryCallback => $retryCallback,
        resultCallback => $resultCallback,
      });
    }
    else
    {
      Log3 $name, 2, "RainbirdController ($name) - Request[ID:$request_id] data not defined";

      ### is there a callback function?
      if(defined($resultCallback))
      {
        Log3 $name, 4, "RainbirdController ($name) - Request[ID:$request_id]: calling lambda function";
    
        $resultCallback->(undef, undef);
      }
    }
  };

  $sendReceive->($hash->{RETRIES}, $sendReceive);
}

#####################################
# ErrorHandling
#####################################
sub RainbirdController_ErrorHandling($$$)
{
  my ( $param, $err, $data ) = @_;
  my $hash  = $param->{hash};
  my $name  = $hash->{NAME};
  
  my $request_id  = $param->{request_id};
  my $leftRetries = $param->{leftRetries};
  my $retryCallback = $param->{retryCallback};
  my $resultCallback = $param->{resultCallback};
  my $sendData = $param->{sendData};

  my $response_timestamp = gettimeofday();
  my $request_timestamp = $param->{request_timestamp};
  my $requestResponse_timespan = $response_timestamp - $request_timestamp;
  my $errorMsg = "";
  my $decoded = undef;

  ### check if the current callback handles the last request.
  ### else drop...
  if($request_id != $hash->{REQUESTID})
  {
    $hash->{helper}{RESPONSECOUNT_DROPPED}++;
    $hash->{RESPONSECOUNT_DROPPED} = $hash->{helper}{RESPONSECOUNT_DROPPED};
    
    Log3 $name, 3, "RainbirdController ($name) - ErrorHandling[ID:$request_id]: Dropping old response! Current is: $hash->{REQUESTID}";
    return;
  }

  ### check error variable
  if ( defined($err) and 
    $err ne "" )
  {
    Log3 $name, 3, "RainbirdController ($name) - ErrorHandling[ID:$request_id]: Error: " . $err . " data: \"" . $data . "\"";
    
    $errorMsg = 'error ' . $err;
  }
  
  ### check code
  if ( $data eq "" and
    exists( $param->{code} ) and 
    $param->{code} != 200 )
  {
    Log3 $name, 3, "RainbirdController ($name) - ErrorHandling[ID:$request_id]: Code: " . $param->{code} . " data: \"" . $data . "\"";
    
    if( $param->{code} == 403 ) ### Forbidden
    {
      $errorMsg = 'wrong password';
      $leftRetries = 0; # no retry
    }
    elsif( $param->{code} == 503 ) ### Service Unavailable
    {
      $errorMsg = 'error ' . $param->{code};
    }
    else
    {
      $errorMsg = 'error ' . $param->{code};
    }
  }

  Log3 $name, 5, "RainbirdController ($name) - ErrorHandling[ID:$request_id]: data: \"" . $data . "\"";

  ### no error: process response
  if($errorMsg eq "")
  {
    my $retrystring = 'RESPONSECOUNT_RETRY_' . ($hash->{RETRIES} - $leftRetries);
    $hash->{helper}{RESPONSECOUNT_SUCCESS}++;
    $hash->{helper}{RESPONSETOTALTIMESPAN} += $requestResponse_timespan;
    $hash->{helper}{RESPONSEAVERAGETIMESPAN} = $hash->{helper}{RESPONSETOTALTIMESPAN} / $hash->{helper}{RESPONSECOUNT_SUCCESS};
    $hash->{helper}{$retrystring}++;

    ### just copy from helper
    $hash->{RESPONSECOUNT_SUCCESS} = $hash->{helper}{RESPONSECOUNT_SUCCESS};
    $hash->{RESPONSEAVERAGETIMESPAN} = $hash->{helper}{RESPONSEAVERAGETIMESPAN};
    $hash->{$retrystring} = $hash->{helper}{$retrystring};

    $decoded = RainbirdController_ResponseProcessing( $param, $data );
  }
  ### error: retries left
  elsif(defined($retryCallback) and # is retryCallbeck defined
    $leftRetries > 0)               # are there any left retries
  {
    Log3 $name, 5, "RainbirdController ($name) - ErrorHandling[ID:$request_id]: retry " . $leftRetries . " Error: " . $errorMsg;

    ### call retryCallback with decremented number of left retries
    $retryCallback->($leftRetries - 1, $retryCallback);
    return; # resultCallback is handled in retry 
  }
  else
  {
    Log3 $name, 3, "RainbirdController ($name) - ErrorHandling[ID:$request_id]: no retries left Error: " . $errorMsg;

    $hash->{helper}{RESPONSECOUNT_ERROR}++;
    $hash->{RESPONSECOUNT_ERROR} = $hash->{helper}{RESPONSECOUNT_ERROR};

    readingsSingleUpdate( $hash, 'state', $errorMsg, 1 );
  }
  
    # is there a callback function?
  if(defined($resultCallback))
  {
    Log3 $name, 4, "RainbirdController ($name) - ErrorHandling[ID:$request_id]: calling lambda function";
    
    $resultCallback->($decoded, $sendData);
  }
}


#####################################
# ResponseProcessing
#####################################
sub RainbirdController_ResponseProcessing($$)
{
  my ( $param, $data ) = @_;

  my $hash = $param->{hash};
  my $name = $hash->{NAME};
  
  my $request_id  = $param->{request_id};
  my $expectedResponse_id = $param->{expectedResponse_id};

  ### decrypt data
  my $decrypted_data = RainbirdController_DecryptData($hash, $data, RainbirdController_ReadPassword($hash));
  if(not defined($decrypted_data))
  {
    Log3 $name, 2, "RainbirdController ($name) - ResponseProcessing[ID:$request_id]: encrypted_data not defined";
    return undef;
  }

  ### create structure from json string
  my $decode_json = eval { decode_json($decrypted_data) };

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

  if ($@)
  {
    Log3 $name, 2, "RainbirdController ($name) - ResponseProcessing[ID:$request_id]: JSON error while request: $@";
    return undef;
  }
  
  if( not defined( $decode_json ) or
    not defined( $decode_json->{id} ) or
    not defined( $decode_json->{result} ) or
    not defined( $decode_json->{result}->{data} ))
  {
    Log3 $name, 2, "RainbirdController ($name) - ResponseProcessing[ID:$request_id]: no result.data";
    return undef;
  }
 
  ### compare requestId with responseId
  if($request_id ne $decode_json->{id})
  {
    Log3 $name, 2, "RainbirdController ($name) - ResponseProcessing[ID:$request_id]: request failed with wrong ResponseId! RequestId \"" . $request_id . "\" but got ResponseId \"" . $decode_json->{id} . "\"";
    return undef;
  }
  
  ### decode data
  my $decoded = RainbirdController_DecodeData($hash, $decode_json->{result}->{data});
  
  if(not defined($decoded))
  {
    Log3 $name, 2, "RainbirdController ($name) - ResponseProcessing[ID:$request_id]: decoded not defined";
    return undef;
  }

  ### response
  my $response_id = $decoded->{"responseId"};

  if(not defined($response_id))
  {
    Log3 $name, 2, "RainbirdController ($name) - ResponseProcessing[ID:$request_id]: response not defined";
    return undef;
  }
  
  # check id of response message
  if(defined($expectedResponse_id) and
    $response_id ne $expectedResponse_id)  
  {
    if( $response_id eq "00" )
    {
      Log3 $name, 2, "RainbirdController ($name) - ResponseProcessing[ID:$request_id]: NAKCode \"" . sprintf("%X", $decoded->{"NAKCode"}) . "\" commandEcho \"" . sprintf("%X", $decoded->{"commandEcho"}) . "\"";
    }
    else
    {
      Log3 $name, 2, "RainbirdController ($name) - ResponseProcessing[ID:$request_id]: Status request failed with wrong response! Requested \"" . $expectedResponse_id . "\" but got \"" . $response_id . "\"";
    }

    return undef;
  }

  return $decoded;
}

#####################################
# EncodeData
#####################################
sub RainbirdController_EncodeData($$@)
{
  my ( $hash, $command_set, @args ) = @_;
  my $name = $hash->{NAME};

  my $args_count = scalar (@args); # count of args

  Log3 $name, 5, "RainbirdController ($name) - encode with $args_count args";

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
    my $charLength = $command_set->{$keyName};
    
    if(not defined($charLength))
    {
      Log3 $name, 3, "RainbirdController ($name) - encode: Error \"$keyName\" not found";
      return undef;
    }

    Log3 $name, 5, "RainbirdController ($name) - encode: extend arg_placeholders with keyName: \"" . $keyName . "\" charLength: " . $charLength . " value: \"" . $args[$index - 1] . "\"";

    ### extend arg_placeholder with a format entry for any parameter
    ### the format entry is %H with leading 0s to reach the charlength from command_set
    ### charlength 1: %01X 
    ### charlength 2: %02X 
    ### charlength 3: %03X 
    $arg_placeholders .= sprintf("%%0%dX", $charLength);
    $arg_placeholders_charLength += $charLength;
    $args_found++
  }
  
  Log3 $name, 5, "RainbirdController ($name) - encode: arg_placeholders \"" . $arg_placeholders . "\" arg_placeholders_charLength: " . $arg_placeholders_charLength . " arg_found: " . $args_found;

  ### check if number of parameters equals to number of entries in dataset
  if($args_found != $args_count)
  {
    Log3 $name, 3, "RainbirdController ($name) - encode: Error " . $args_count . " parameters given but " . $args_found . " parameters in dataset";
    return undef;
  }
  
  ### check if char lengths matches
  if($command_set_charLength != $arg_placeholders_charLength)
  {
    Log3 $name, 3, "RainbirdController ($name) - encode: Error charLength: " . $command_set_charLength . " chars given but " . $arg_placeholders_charLength ." chars processed";
    return undef;
  }

  my $result = sprintf("%s" . $arg_placeholders, @params);
  my $result_charLength = length($result);

  Log3 $name, 5, "RainbirdController ($name) - encode: result: \"$result\"";

  ### check if char lengths matches
  if($command_set_charLength != $result_charLength)
  {
    Log3 $name, 3, "RainbirdController ($name) - encode: Error charLength: " . $command_set_charLength . " chars given but " . $result_charLength . " chars processed";
    return undef;
  }

  return $result;
}

#####################################
# DecodeData
#####################################
sub RainbirdController_DecodeData($$)
{
  my ( $hash, $data ) = @_;
  my $name = $hash->{NAME};
  
  my $response_id = substr($data, 0, 2);
  
  Log3 $name, 5, "RainbirdController ($name) - decode: data \"" . $data . "\"";

  my %result = (
    "identifier" => "Rainbird",
    "responseId" => $response_id,
    "data" => $data,
  );
  

  # find response-structure in hash "ControllerResponses"
  my $cmd_template = $ControllerResponses{$response_id};
  if( defined( $cmd_template ) )
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
      
        Log3 $name, 5, "RainbirdController ($name) - decode: insert $key = " . $currentValue;

        $result{$key} = $currentValue;        
      }
    }
  }
  else
  {
    Log3 $name, 2, "RainbirdController ($name) - decode: ControllerResponse \"" . $response_id . "\" not found!";
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

  Log3 $name, 5, "RainbirdController ($name) - add_padding: $result";
  
  return $result;
}

#####################################
# EncryptData
#####################################
sub RainbirdController_EncryptData($$$)
{
  my ( $hash, $data, $encryptkey ) = @_;
  my $name = $hash->{NAME};
  
  my $tocodedata = $data . "\x00\x10";
  
  my $iv =  Crypt::CBC->random_bytes(16);
  #my $iv = pack("C*", map { 0x01 } 1..16);
  Log3 $name, 5, "RainbirdController ($name) - encrypt: iv: \"" . (sprintf("%v02X", $iv) =~ s/\.//rg) . "\" length: " . length($iv);
  
  my $c = RainbirdController_AddPadding($hash, $tocodedata);
  Log3 $name, 5, "RainbirdController ($name) - encrypt: c: \"" . (sprintf("%v02X", $c) =~ s/\.//rg) . "\"";
  #Log3 $name, 5, "RainbirdController ($name) - encrypt: c: \"$c\"";

  my $b = sha256($encryptkey);
  Log3 $name, 5, "RainbirdController ($name) - encrypt: b: \"" . (sprintf("%v02X", $b) =~ s/\.//rg) . "\"";
  #Log3 $name, 5, "RainbirdController ($name) - encrypt: b: \"$b\"";

  my $b2 = sha256($data);
  Log3 $name, 5, "RainbirdController ($name) - encrypt: b2: \"" . (sprintf("%v02X", $b2) =~ s/\.//rg) . "\" length: " . length($b2);
  
  #my $cbc = Crypt::CBC->new({'key' => $b,
  #                           'cipher' => 'Cipher::AES',
  #                           'iv' => $iv,
  #                           'regenerate_key' => 0,
  #                           'padding' => 'standard',
  #                           'prepend_iv' => 0
  #                            });
  #  
  #my $encrypteddata = $cbc->encrypt($c); 

  my $cbc = Crypt::Mode::CBC->new('AES');
  my $encrypteddata = $cbc->encrypt($c, $b, $iv); 
  
  my $result = $b2 . $iv . $encrypteddata;
  Log3 $name, 5, "RainbirdController ($name) - encrypt: result: \"" . (sprintf("%v02X", $result) =~ s/\.//rg) . "\"";
  #Log3 $name, 5, "RainbirdController ($name) - encrypt: encrypteddata: \"$encrypteddata\"";

  return $result;
}

#####################################
# DecryptData
#####################################
sub RainbirdController_DecryptData($$$)
{
  my ( $hash, $data, $decrypt_key ) = @_;
  my $name = $hash->{NAME};

  my $symmetric_key = substr(sha256($decrypt_key), 0, 32);
  Log3 $name, 5, "RainbirdController ($name) - decrypt: symmetric_key: \"" . (sprintf("%v02X", $symmetric_key) =~ s/\.//rg) . "\"";

  my $iv = substr($data, 32, 16);
  Log3 $name, 5, "RainbirdController ($name) - decrypt: iv: \"" . (sprintf("%v02X", $iv) =~ s/\.//rg) . "\"";

  my $encrypted_data = substr($data, 48, length($data) - 48);
  Log3 $name, 5, "RainbirdController ($name) - decrypt: encrypted_data: \"" . (sprintf("%v02X", $encrypted_data) =~ s/\.//rg) . "\"";

  #my $cbc = Crypt::CBC->new({'key' => $symmetric_key,
  #                           'cipher' => 'Cipher::AES',
  #                           'iv' => $iv,
  #                           'regenerate_key' => 0,
  #                           'padding' => 'standard',
  #                           'prepend_iv' => 0
  #                            });
  #my $decrypteddata = $cbc->decrypt($encrypted_data); 

  #my $cbc = Crypt::Mode::CBC->new('AES', 'standard');
  my $cbc = Crypt::Mode::CBC->new('AES', 0);
  my $decrypteddata = $cbc->decrypt($encrypted_data, $symmetric_key, $iv); 

  Log3 $name, 5, "RainbirdController ($name) - decrypt: decrypteddata: \"" . (sprintf("%v02X", $decrypteddata) =~ s/\.//rg) . "\"";
  #Log3 $name, 5, "RainbirdController ($name) - decrypt: decrypteddata: \"" . $decrypteddata . "\"";
  
  $decrypteddata =~ s/\x10+$//;
  $decrypteddata =~ s/\x0a+$//;
  $decrypteddata =~ s/\x00+$//;
  # Take 1 or more white spaces (\s+) till the end of the string ($), and replace them with an empty string. 
  $decrypteddata =~ s/\s+$//;
  
  Log3 $name, 5, "RainbirdController ($name) - decrypt: decrypteddata: \"" . (sprintf("%v02X", $decrypteddata) =~ s/\.//rg) . "\"";
  #Log3 $name, 5, "RainbirdController ($name) - decrypt: decrypteddata: \"" . $decrypteddata . "\"";
  
  return $decrypteddata;
}

####################################
# StorePassword
#####################################
sub RainbirdController_StorePassword($$)
{
  my ( $hash, $password ) = @_;
  my $index   = $hash->{TYPE} . "_" . $hash->{NAME} . "_passwd";
  my $key     = getUniqueId() . $index;
  my $enc_pwd = "";

  if ( eval "use Digest::MD5;1" )
  {
    $key = Digest::MD5::md5_hex( unpack "H*", $key );
    $key .= Digest::MD5::md5_hex($key);
  }

  for my $char ( split //, $password )
  {
    my $encode = chop($key);
    $enc_pwd .= sprintf( "%.2x", ord($char) ^ ord($encode) );
    $key = $encode . $key;
  }

  my $err = setKeyValue( $index, $enc_pwd );

  return "error while saving the password - $err"
    if ( defined($err) );

  return "password successfully saved";
}

####################################
# ReadPassword
#####################################
sub RainbirdController_ReadPassword($)
{
  my ($hash) = @_;
  my $name   = $hash->{NAME};
  my $index  = $hash->{TYPE} . "_" . $hash->{NAME} . "_passwd";
  my $key    = getUniqueId() . $index;
  my ( $password, $err );

  Log3 $name, 5, "RainbirdController ($name) - Read password from file";

  ( $err, $password ) = getKeyValue($index);

  if ( defined($err) )
  {
    Log3 $name, 5, "RainbirdController ($name) - unable to read password from file: $err";
    return undef;
  }

  if ( defined($password) )
  {
    if ( eval "use Digest::MD5;1" )
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
    Log3 $name, 5, "RainbirdController ($name) - No password in file";
    return undef;
  }
}

#####################################
# DeletePassword
#####################################
sub RainbirdController_DeletePassword($)
{
  my $hash = shift;

  setKeyValue( $hash->{TYPE} . "_" . $hash->{NAME} . "_passwd", undef );

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

  $result .= " Mon" if($mask &  2);
  $result .= " Tue" if($mask &  4);
  $result .= " Wed" if($mask &  8);
  $result .= " Thu" if($mask & 16);
  $result .= " Fri" if($mask & 32);
  $result .= " Sat" if($mask & 64);
  $result .= " Sun" if($mask &  1);

  # left trim
  $result =~ s/^\s+//;
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
      <li><B>Date</B><a name="RainbirdControllerDate"></a><br>
        Sets the internal date of the controller.<br>
        Format: YYYY-MM-DD
      </li>
      <li><B>DeletePassword</B><a name="RainbirdControllerDeletePassword"></a><br>
        Deletes the password from store.
      </li>
      <li><B>FactoryReset</B><a name="RainbirdControllerFactoryReset"></a><br>
        Reset all parameters of the device to default factory settings.
      </li>
      <li><B>IrrigateZone</B><a name="RainbirdControllerIrrigateZone"></a><br>
        Starts irrigating a zone.
      </li>
      <li><B>Password</B><a name="RainbirdControllerPassword"></a><br>
        Sets the password in store.
      </li>
      <li><B>RainDelay</B><a name="RainbirdControllerRainDelay"></a><br>
        Sets the delay in days.
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
      <li><B>Time</B><a name="RainbirdControllerTime"></a><br>
        Sets the internal time of the controller<br>
        Format: HH:MM or HH:MM:SS
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
      <li><a name="RainbirdControllerexpert">expert</a><br>
        Switches to expert mode.<br>
        If enabled then additional features for <b>debugging purposes</b> will available.<br> 
      </li>
      <li><a name="RainbirdControllerinterval">interval</a><br>
        Interval of polling in seconds (Default=60).<br>
      </li>
      <li><a name="RainbirdControllerretries">retries</a><br>
        Number of retries (Default=3)<br>
      </li>
      <li><a name="RainbirdControllertimeout">timeout</a><br>
        Timeout for expected response in seconds (Default=20)<br>
      </li>
    </ul><br>
    <a name="RainbirdControllerinternals"></a><b>Internals</b>
    <ul>
      <li><B>EXPERTMODE</B><br>
        gives information if device is in expert mode<br>
      </li>
    </ul><br>
    <br>
  </ul>
=end html

=cut
