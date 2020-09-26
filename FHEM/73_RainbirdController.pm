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
my $VERSION = '1.5.0';
my $DefaultInterval = 60;
my $DefaultRetryInterval = 60;
my $DefaultTimeout = 20;
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
sub RainbirdController_TimerCallback($);

sub RainbirdController_GetDeviceState($;$);
sub RainbirdController_GetDeviceInfo($;$);

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
sub RainbirdController_GetIrrigationState($;$);
sub RainbirdController_IrrigateZone($$$;$);
sub RainbirdController_TestZone($$;$);
sub RainbirdController_SetProgram($$;$);
sub RainbirdController_StopIrrigation($;$);
sub RainbirdController_FactoryReset($;$);

### for testing purposes only
sub RainbirdController_TestCMD($$$;$);
sub RainbirdController_TestRAW($$;$);

### internal tool functions
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

### hash with all known models
my %KnownModels = (
  3 => "ESP-RZXe Serie",
);

### format of a command entry
### command name:                 "CurrentDateSetRequest" => 
###                               {
###	command string:                 "command" => "13", 
### [opt] first parameter charlen:  "parameter1" => 2, 
### [opt] second parameter charlen: "parameter2" => 1, "
### [opt] third parameter charlen:  "parameter3" => 3, 
### response number string:         "response" => "01", 
### total bytelength:               "length" => 4
###                               },
my %ControllerCommands = (
    "ModelAndVersionRequest" => {"command" => "02", "response" => "82", "length" => 1},
    "AvailableStationsRequest" => {"command" => "03", "parameter1" => 2, "response" => "83", "length" => 2},
    "CommandSupportRequest" => {"command" => "04", "parameter1" => 2, "response" => "84", "length" => 2},
    "SerialNumberRequest" => {"command" => "05", "response" => "85", "length" => 1},
#    "SupportedRequest" => {"command" => "06", "response" => "85", "length" => 1},
#    "SupportedRequest" => {"command" => "07", "response" => "85", "length" => 1},
    "CurrentTimeGetRequest" => {"command" => "10", "response" => "90", "length" => 1},
    "CurrentTimeSetRequest" => {"command" => "11", "parameter1" => 2, "parameter2" => 2, "parameter3" => 2, "response" => "01", "length" => 4},
    "CurrentDateGetRequest" => {"command" => "12", "response" => "92", "length" => 1},
    "CurrentDateSetRequest" => {"command" => "13", "parameter1" => 2, "parameter2" => 1, "parameter3" => 3, "response" => "01", "length" => 4},
#    "CurrentScheduleRequest" => {"command" => "20", "parameterOne" => 0, "parameterTwo" => 0 ,"response" => "A0", "length" => 3 },
    "Unknown21Request" => {"command" => "21", "parameter1" => 2, "parameter2" => 1, "parameter3" => 1, "response" => "01", "length" => 4},
    "WaterBudgetRequest" => {"command" => "30", "parameter1" => 2, "response" => "B0", "length" => 2}, # not supported
#    "SupportedRequest" => {"command" => "31", "response" => "85", "length" => 1},
    "ZonesSeasonalAdjustFactorRequest" => {"command" => "32", "parameter1" => 2, "response" => "B2", "length" => 2}, # not supported
    "RainDelayGetRequest" => {"command" => "36", "response" => "B6", "length" => 1},
    "RainDelaySetRequest" => {"command" => "37", "parameter1" => 4, "response" => "01", "length" => 3},
    "ManuallyRunProgramRequest" => {"command" => "38", "parameter1" => 2, "response" => "01", "length" => 2}, # not supported
    "ManuallyRunStationRequest" => {"command" => "39", "parameter1" => 4, "parameter2" => 2, "response" => "01", "length" => 4}, 
    "TestStationsRequest" => {"command" => "3A", "parameter1" => 2, "response" => "01", "length" => 2},
#    "SupportedRequest" => {"command" => "3B", "response" => "85", "length" => 1},
#    "SupportedRequest" => {"command" => "3D", "response" => "85", "length" => 1},
    "CurrentRainSensorStateRequest" => {"command" => "3E", "response" => "BE", "length" => 1},
    "CurrentStationsActiveRequest" => {"command" => "3F", "parameter1" => 2, "response" => "BF", "length" => 2},
    "StopIrrigationRequest" => {"command" => "40", "response" => "01", "length" => 1},
    "Unknown41Request" => {"command" => "41", "parameter1" => 2, "response" => "01", "length" => 2},
    "AdvanceStationRequest" => {"command" => "42", "parameter1" => 2, "response" => "01", "length" => 2}, # not supported
    "CurrentIrrigationStateRequest" => {"command" => "48", "response" => "C8", "length" => 1},
    "CurrentControllerStateSet" => {"command" => "49", "parameter1" => 2, "response" => "01", "length" => 2}, # not supported
    "ControllerEventTimestampRequest" => {"command" => "4A", "parameter1" => 2, "response" => "CA", "length" => 2}, # not supported
    "StackManuallyRunStationRequest" => {"command" => "4B", "parameter1" => 2, "parameter2" => 1, "parameter3" => 1, "response" => "01", "length" => 4}, # not supported
    "CombinedControllerStateRequest" => {"command" => "4C", "response" => "CC","length" => 1 }, # not supported
    "Unknown50Request" => {"command" => "50", "response" => "01", "length" => 1},
    "Unknown51Request" => {"command" => "51", "response" => "01", "length" => 1},
    "Unknown52Request" => {"command" => "52", "response" => "01", "length" => 1},
    "FactoryResetRequest" => {"command" => "57", "response" => "01", "length" => 1},
);

### format of a response entry
### response number string:    "00" => 
###                            {
### total bytelength	         "length" =>  3, 
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
    ### NAKCode
    # 1 -> command not supported
    # 2 -> parameters wrong
    "00" => {"length" =>  3, "type" => "NotAcknowledgeResponse", "commandEcho" => {"position" => 2, "length" => 2, "format" => "%02X"}, "NAKCode" => {"position" => 4, "length" => 2, "knownvalues" => {"1" => "command not supported", "2" => "wrong number of parameters", "4" => "command not supported",} } },
    "01" => {"length" =>  2, "type" => "AcknowledgeResponse", "commandEcho" => {"position" => 2, "length" => 2, "format" => "%02X"} },
    "82" => {"length" =>  5, "type" => "ModelAndVersionResponse", "modelID" => {"position" => 2, "length" => 4}, "protocolRevisionMajor" => {"position" => 6, "length" => 2}, "protocolRevisionMinor" => {"position" => 8, "length" => 2} },
    "83" => {"length" =>  6, "type" => "AvailableStationsResponse", "pageNumber" => {"position" => 2, "length" => 2}, "setStations" => {"position" => 4, "length" => 8} },
    "84" => {"length" =>  3, "type" => "CommandSupportResponse", "commandEcho" => {"position" => 2, "length" => 2}, "support" => {"position" => 4, "length" => 2} },
    "85" => {"length" =>  9, "type" => "SerialNumberResponse", "serialNumber" => {"position" => 2, "length" => 16} },
    "90" => {"length" =>  4, "type" => "CurrentTimeGetResponse", "hour" => {"position" => 2, "length" => 2}, "minute" => {"position" => 4, "length" => 2}, "second" => {"position" => 6, "length" => 2} },
    "92" => {"length" =>  4, "type" => "CurrentDateGetResponse", "day" => {"position" => 2, "length" => 2}, "month" => {"position" => 4, "length" => 1}, "year" => {"position" => 5, "length" => 3} },
    "B0" => {"length" =>  4, "type" => "WaterBudgetResponse", "programCode" => {"position" => 2, "length" => 2}, "seasonalAdjust" => {"position" => 4, "length" => 4} },
    "B2" => {"length" => 18, "type" => "ZonesSeasonalAdjustFactorResponse", "programCode" => {"position" => 2, "length" => 2}, "stationsSA" => {"position" => 4, "length" => 32} },
    "BE" => {"length" =>  2, "type" => "CurrentRainSensorStateResponse", "sensorState" => {"position" => 2, "length" => 2} },
    "BF" => {"length" =>  6, "type" => "CurrentStationsActiveResponse", "pageNumber" => {"position" => 2, "length" => 2}, "activeStations" => {"position" => 4, "length" => 8} },
    "B6" => {"length" =>  3, "type" => "RainDelaySettingResponse", "delaySetting" => {"position" => 2, "length" => 4} },
    "C8" => {"length" =>  2, "type" => "CurrentIrrigationStateResponse", "irrigationState" => {"position" => 2, "length" => 2} },
    "CA" => {"length" =>  6, "type" => "ControllerEventTimestampResponse", "eventId" => {"position" => 2, "length" => 2}, "timestamp" => {"position" => 4, "length" => 8} },
    "CC" => {"length" => 16, "type" => "CombinedControllerStateResponse", "hour" => {"position" => 2, "length" => 2}, "minute" => {"position" => 4, "length" => 2}, "second" => {"position" => 6, "length" => 2}, "day" => {"position" => 8, "length" => 2}, "month" => {"position" => 10, "length" => 1}, "year" => {"position" => 11, "length" => 3}, "delaySetting" => {"position" => 14, "length" => 4}, "sensorState" => {"position" => 18, "length" => 2}, "irrigationState" => {"position" => 20, "length" => 2}, "seasonalAdjust" => {"position" => 22, "length" => 4}, "remainingRuntime" => {"position" => 26, "length" => 4}, "activeStation" => {"position" => 30, "length" => 2} }
);

my $DEFAULT_PAGE = 0;
my $BLOCK_SIZE = 16;
my $INTERRUPT = "\x00";
my $PAD = "\x10";

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
  $hash->{"ZONESAVAILABLECOUNT"}         = 0; # 
  $hash->{"ZONESAVAILABLEMASK"}          = 0; # 
  $hash->{"ZONEACTIVE"}                  = 0; # 
  $hash->{"ZONEACTIVEMASK"}              = 0; # 
  $hash->{REQUESTID}                     = 0;
  $hash->{TIMERON}                       = 0;
  $hash->{helper}{RESPONSESUCCESSCOUNT}  = 0; # statistics
  $hash->{helper}{RESPONSEERRORCOUNT}    = 0; # statistics
  $hash->{helper}{RESPONSETOTALTIMESPAN} = 0; # statistics
    
  ### set attribute defaults
  CommandAttr( undef, $name . ' room Rainbird' )
    if ( AttrVal( $name, 'room', 'none' ) eq 'none' );

  ### ensure attribute webCmd is present
  CommandAttr( undef, $name . ' webCmd StopIrrigation' )
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
  
  ### StopIrrigation
  elsif ( lc $cmd eq lc 'StopIrrigation' )
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
    
    RainbirdController_IrrigateZone($hash, $zone, $minutes);
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
    
    # get static deviceInfo and start timer on callback
    my $callback = sub 
    {
      RainbirdController_GetDeviceState($hash); 
    };
    RainbirdController_GetDeviceInfo($hash, $callback );
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
      $list .= " StopIrrigation:noArg";
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
    
    RainbirdController_GetDeviceInfo($hash);
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
    
    RainbirdController_GetIrrigationState($hash);
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
      $list .= " CommandSupport" if($hash->{EXPERTMODE});
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

  Log3 $name, 4, "RainbirdController ($name) - timerRestart";

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

  ### if RainbirdController_Function fails no callback function is called
  ### so reload timer for next try
  InternalTimer( gettimeofday() + $hash->{RETRYINTERVAL}, \&RainbirdController_TimerRestart, $hash );
  $hash->{TIMERON} = 1;

  # get static deviceInfo and start timer on callback
  my $startTimer = sub 
  {
  	 RainbirdController_TimerCallback($hash); 
  };
  RainbirdController_GetDeviceInfo($hash, $startTimer );
}

#####################################
# callback function of the internal timer
#####################################
sub RainbirdController_TimerCallback($)
{
  my ( $hash ) = @_;
  my $name = $hash->{NAME};

  RainbirdController_TimerStop($hash);

  if ( IsDisabled($name) )
  {
    readingsSingleUpdate( $hash, 'state', 'disabled', 1 );

    Log3 $name, 3, "RainbirdController ($name) - timerCallback: device is disabled";
    return;
  } 

  Log3 $name, 4, "RainbirdController ($name) - timerCallback";

  ### if RainbirdController_Function fails no callback function is called
  ### so reload timer for next try
  InternalTimer( gettimeofday() + $hash->{RETRYINTERVAL}, \&RainbirdController_TimerCallback, $hash );
  $hash->{TIMERON} = 1;
  
  my $nextInterval = gettimeofday() + $hash->{INTERVAL};
  my $reloadTimer = sub 
  {
    ### reload timer
    RemoveInternalTimer($hash);
    InternalTimer( $nextInterval, \&RainbirdController_TimerCallback, $hash );
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

  Log3 $name, 4, "RainbirdController ($name) - getDeviceState";

  # definition of the callback chain
  # each function calls the given callback in their resultcallback
  my $runCallback = sub 
  {
    # if there is a callback then call it
    if( defined($callback))
    {
      Log3 $name, 4, "RainbirdController ($name) - getDeviceState callback";
      $callback->();
    }
  };	 
  
  my $getCurrentTime = sub { RainbirdController_GetCurrentTime($hash, $runCallback); };
  my $getCurrentDate = sub { RainbirdController_GetCurrentDate($hash, $getCurrentTime); };
  my $getRainSensorState = sub { RainbirdController_GetRainSensorState($hash, $getCurrentDate); };
  my $getCurrentIrrigation = sub { RainbirdController_GetCurrentIrrigation($hash, $getRainSensorState); };
  my $getIrrigationState = sub { RainbirdController_GetIrrigationState($hash, $getCurrentIrrigation); };
  my $getRainDelay = sub { RainbirdController_GetRainDelay($hash, $getIrrigationState); };

  $getRainDelay->($hash);
}

#####################################
# gets the static values of the device
#####################################
sub RainbirdController_GetDeviceInfo($;$)
{
  my ( $hash, $callback ) = @_;
  my $name = $hash->{NAME};

  Log3 $name, 4, "RainbirdController ($name) - getDeviceInfo";

  # definition of the callback chain
  # each function calls the given callback in their resultcallback
  my $runCallback = sub 
  {
    # if there is a callback then call it
    if( defined($callback))
    {
      Log3 $name, 4, "RainbirdController ($name) - getDeviceInfo callback";
      $callback->();
    }
  };  

  my $getModelAndVersion = sub { RainbirdController_GetModelAndVersion($hash, $runCallback); };
  my $getAvailableZones = sub { RainbirdController_GetAvailableZones($hash, $getModelAndVersion); };
  my $getSerialNumber = sub { RainbirdController_GetSerialNumber($hash, $getAvailableZones); };

  $getSerialNumber->($hash);
}

#####################################
# GetModelAndVersion
#####################################
sub RainbirdController_GetModelAndVersion($;$)
{
  my ( $hash, $callback ) = @_;
  my $name = $hash->{NAME};
    
  my $command = "ModelAndVersion";
  
  Log3 $name, 4, "RainbirdController ($name) - getModelAndVersion";

  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - getModelAndVersion resultCallback";
    
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
      Log3 $name, 4, "RainbirdController ($name) - getModelAndVersion callback";
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

  Log3 $name, 4, "RainbirdController ($name) - getAvailableZones mask: $mask";
  
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - getAvailableZones lambda";
    
    if( defined($result) )
    {
      readingsBeginUpdate($hash);

      if( defined($result->{"setStations"}) )
      {
      	my $zonesAvailableCount = RainbirdController_GetAvailableZoneCountFromRaw($result->{"setStations"});
        my $zonesAvailableMask = RainbirdController_GetAvailableZoneMaskFromRaw($result->{"setStations"});
      	
      	$hash->{"ZONESAVAILABLECOUNT"} = $zonesAvailableCount;
        $hash->{"ZONESAVAILABLEMASK"} = $zonesAvailableMask;
      	
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
      Log3 $name, 4, "RainbirdController ($name) - getAvailableZones callback";
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
     
  Log3 $name, 4, "RainbirdController ($name) - getCommandSupport";
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - getCommandSupport lambda";
    
    if( defined($result) )
    {
      readingsBeginUpdate($hash);

      if( defined($result->{"support"}) )
      {
        readingsBulkUpdate( $hash, 'commandSupport', $result->{"support"}, 1 );
      }
      if( defined($result->{"commandEcho"}) )
      {
        readingsBulkUpdate( $hash, 'commandEcho', $result->{"commandEcho"}, 1 );
      }

      readingsEndUpdate( $hash, 1 );
    }

    # if there is a callback then call it
    if( defined($callback) )
    {
      Log3 $name, 4, "RainbirdController ($name) - getCommandSupport callback";
      $callback->();
    }
  }; 
    
  # send command
  RainbirdController_Command($hash, $resultCallback, $command, $askCommand );
}

#####################################
# SetWaterBudget
#####################################
sub RainbirdController_SetWaterBudget($$;$)
{
  my ( $hash, $budget, $callback ) = @_;
  my $name = $hash->{NAME};
    
  my $command = "WaterBudget";
  Log3 $name, 4, "RainbirdController ($name) - setWaterBudget";
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - setWaterBudget lambda";
    
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
      Log3 $name, 4, "RainbirdController ($name) - setWaterBudget callback";
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
  
  Log3 $name, 4, "RainbirdController ($name) - getRainSensorState";
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - getRainSensorState lambda";
    
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
      Log3 $name, 4, "RainbirdController ($name) - getRainSensorState callback";
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
  
  Log3 $name, 4, "RainbirdController ($name) - getSerialNumber";
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - getSerialNumber lambda";
    
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
      Log3 $name, 4, "RainbirdController ($name) - getSerialNumber callback";
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
  
  Log3 $name, 4, "RainbirdController ($name) - getCurrentTime";
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - getCurrentTime lambda";
    
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
      Log3 $name, 4, "RainbirdController ($name) - getCurrentTime callback";
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
  
  Log3 $name, 4, "RainbirdController ($name) - setCurrentTime: $hour:$minute:$second";
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - setCurrentTime lambda";
    
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
     
  Log3 $name, 4, "RainbirdController ($name) - getCurrentDate";
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - getCurrentDate lambda";
    
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
      Log3 $name, 4, "RainbirdController ($name) - getCurrentDate callback";
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
  
  Log3 $name, 4, "RainbirdController ($name) - setCurrentDate: $year-$month-$day";
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - setCurrentDate lambda";
    
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
  
  Log3 $name, 4, "RainbirdController ($name) - getCurrentIrrigation";
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - getCurrentIrrigation lambda";
    
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
      Log3 $name, 4, "RainbirdController ($name) - getCurrentIrrigation callback";
      $callback->();
    }
  }; 
    
  # send command
  RainbirdController_Command($hash, $resultCallback, $command );
}

#####################################
# GetIrrigationState
#####################################
sub RainbirdController_GetIrrigationState($;$)
{
  my ( $hash, $callback ) = @_;
  my $name = $hash->{NAME};
    
  my $command = "CurrentStationsActive";
  my $mask = sprintf("%%0%dX", $ControllerResponses{"BF"}->{"activeStations"}->{"length"});

  Log3 $name, 4, "RainbirdController ($name) - getIrrigationState mask: $mask";
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - getIrrigationState lambda";
    
    if( defined($result) )
    {
      readingsBeginUpdate($hash);

      if( defined($result->{"activeStations"}))
      {
      	my $zoneActive = RainbirdController_GetZoneFromRaw($result->{"activeStations"});
        my $zoneActiveMask = 1 << ($zoneActive - 1);
      	
        $hash->{"ZONEACTIVE"} = $zoneActive;
        $hash->{"ZONEACTIVEMASK"} = $zoneActiveMask;
        
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
      Log3 $name, 4, "RainbirdController ($name) - getIrrigationState callback";
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
  
  Log3 $name, 4, "RainbirdController ($name) - getRainDelay";
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - getRainDelay lambda";
    
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
      Log3 $name, 4, "RainbirdController ($name) - getRainDelay callback";
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
    
  Log3 $name, 4, "RainbirdController ($name) - setRainDelay";
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - setRainDelay lambda";
    
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
# IrrigateZone
#####################################
sub RainbirdController_IrrigateZone($$$;$)
{
  my ( $hash, $zone, $minutes, $callback ) = @_;
  my $name = $hash->{NAME};
  
  my $command = "ManuallyRunStation";
    
  Log3 $name, 4, "RainbirdController ($name) - irrigateZone";
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - irrigateZone lambda";
    
    if( defined($result) )
    {
      readingsBeginUpdate($hash);

      readingsEndUpdate( $hash, 1 );
    }

    # update reading activeStations
    RainbirdController_GetIrrigationState($hash, $callback);
  }; 
    
  # send command
  RainbirdController_Command($hash, $resultCallback, $command, $zone, $minutes );
}

#####################################
# TestZone
#####################################
sub RainbirdController_TestZone($$;$)
{
  my ( $hash, $zone, $callback ) = @_;
  my $name = $hash->{NAME};
  
  my $command = "TestStations";
    
  Log3 $name, 4, "RainbirdController ($name) - testZone";
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - testZone lambda";

    if( defined($result) )
    {
      readingsBeginUpdate($hash);

      readingsEndUpdate( $hash, 1 );
    }

    # if there is a callback then call it
    if( defined($callback) )
    {
      Log3 $name, 4, "RainbirdController ($name) - testZone callback";
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
    
  Log3 $name, 4, "RainbirdController ($name) - setProgram";
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - setProgram lambda";
    
    if( defined($result) )
    {
      readingsBeginUpdate($hash);

      readingsEndUpdate( $hash, 1 );
    }

    # update reading activeStations
    RainbirdController_GetIrrigationState($hash, $callback);
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
    
  Log3 $name, 4, "RainbirdController ($name) - stopIrrigation";
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - stopIrrigation lambda";
    
    if( defined($result) )
    {
      readingsBeginUpdate($hash);

      readingsEndUpdate( $hash, 1 );
    }

    # update reading activeStations
    RainbirdController_GetIrrigationState($hash, $callback);
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
    RainbirdController_GetIrrigationState($hash, $callback);
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
  
  Log3 $name, 4, "RainbirdController ($name) - testCMD";
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - testCMD lambda";
    
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
  
  Log3 $name, 4, "RainbirdController ($name) - testRAW";
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result, $sendData ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - testRAW lambda";
    
    if( defined($result) )
    {
      readingsBeginUpdate($hash);

#      readingsBulkUpdate( $hash, 'testRAWSend', encode_json(decode_json($sendData)), 1 );
      readingsBulkUpdate( $hash, 'testRAWSend', $sendData, 1 );
      readingsBulkUpdate( $hash, 'testRAWResult', encode_json($result), 1 );

      readingsEndUpdate( $hash, 1 );
    }

     RainbirdController_GetDeviceState($hash, $callback); 
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
 
  Log3 $name, 4, "RainbirdController ($name) - command: $command";
  
  # find controllercommand-structure in hash "ControllerCommands"
  my $request_command = $command . "Request";
  my $command_set = $ControllerCommands{$request_command};

  if( not defined( $command_set ) )
  {
    Log3 $name, 2, "RainbirdController ($name) - command: ControllerCommand \"" . $request_command . "\" not found!";
    return undef;
  }
  
  # encode data
  my $data = RainbirdController_EncodeData($hash, $command_set, @args);  

  if(not defined($data))
  {
    Log3 $name, 2, "RainbirdController ($name) - command: data not defined";
    return;
  }  

  RainbirdController_Request($hash, $resultCallback, $command_set->{"response"}, $data );
}

#####################################
# Request
#####################################
sub RainbirdController_Request($$$$)
{
  my ( $hash, $resultCallback, $expectedResponse_id, $data ) = @_;
  my $name = $hash->{NAME};
    
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
  
  Log3 $name, 5, "RainbirdController ($name) - request: send_data: $send_data";

  ### encrypt data
  my $encrypt_data = RainbirdController_EncryptData($hash, $send_data, RainbirdController_ReadPassword($hash));          
  if(not defined($encrypt_data))
  {
    Log3 $name, 2, "RainbirdController ($name) - request: data not defined";
  	return;
  }

  ### post data 
  my $uri = 'http://' . $hash->{HOST} . '/stick';
  my $method = 'POST';
  my $payload = $encrypt_data;
  my $header = $HEAD;
  my $request_timestamp = gettimeofday();

  Log3 $name, 5, "RainbirdController ($name) - Send with URL: $uri, HEADER: $header, DATA: $payload, METHOD: $method";
  
  my $sendReceive = sub ($;$)
  {
  	my ( $leftRetries, $retryCallback ) = @_;
  	
    HttpUtils_NonblockingGet(
    {
      hash      => $hash,
    
      url       => $uri,
      method    => $method,
      header    => $header,
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
  };
  
  $sendReceive->($hash->{RETRIES}, $sendReceive)
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

  my $response_timestamp = gettimeofday();
  my $request_timestamp = $param->{request_timestamp};
  my $requestResponse_timespan = $response_timestamp - $request_timestamp;
  my $errorMsg = "";

  ### check error variable
  if ( defined($err) and 
    $err ne "" )
  {
    Log3 $name, 3, "RainbirdController ($name) - ErrorHandling: Error: " . $err . " data: " . $data . "";
    
    $errorMsg = 'error ' . $err;
  }
  
  ### check code
  if ( $data eq "" and
    exists( $param->{code} ) and 
    $param->{code} != 200 )
  {
    Log3 $name, 3, "RainbirdController ($name) - ErrorHandling: Code: " . $param->{code} . " data: " . $data . "";
    
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

  Log3 $name, 5, "RainbirdController ($name) - ErrorHandling: RequestID: " . $request_id . " data: " . $data . "";

  ### no error: process response
  if($errorMsg eq "")
  {
  	$hash->{helper}{RESPONSESUCCESSCOUNT}++;
  	$hash->{helper}{RESPONSETOTALTIMESPAN} += $requestResponse_timespan;

    $hash->{RESPONSESUCCESSCOUNT} = $hash->{helper}{RESPONSESUCCESSCOUNT};
    $hash->{RESPONSEAVERAGETIMESPAN} = $hash->{helper}{RESPONSETOTALTIMESPAN} / $hash->{helper}{RESPONSESUCCESSCOUNT};
  	
    RainbirdController_ResponseProcessing( $param, $data );
  }
  ### error: retries left
  elsif(defined($retryCallback) and # is retryCallbeck defined
    $leftRetries > 0)               # are there any left retries
  {
    Log3 $name, 5, "RainbirdController ($name) - ErrorHandling: retry " . $leftRetries . " Error: " . $errorMsg;

    ### call retryCallback with decremented number of left retries
    $retryCallback->($leftRetries - 1, $retryCallback);
  }
  else
  {
    Log3 $name, 3, "RainbirdController ($name) - ErrorHandling: no retries left Error: " . $errorMsg;

    $hash->{helper}{RESPONSEERRORCOUNT}++;
    $hash->{RESPONSEERRORCOUNT} = $hash->{helper}{RESPONSEERRORCOUNT};

    readingsSingleUpdate( $hash, 'state', $errorMsg, 1 );
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
  my $resultCallback = $param->{resultCallback};
  my $sendData = $param->{sendData};

  ### decrypt data
  my $decrypted_data = RainbirdController_DecryptData($hash, $data, RainbirdController_ReadPassword($hash));
  if(not defined($decrypted_data))
  {
    Log3 $name, 2, "RainbirdController ($name) - ResponseProcessing: encrypted_data not defined";
    return;
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
    Log3 $name, 2, "RainbirdController ($name) - ResponseProcessing: JSON error while request: $@";
    return;
  }
  
  if( not defined( $decode_json ) or
    not defined( $decode_json->{id} ) or
    not defined( $decode_json->{result} ) or
    not defined( $decode_json->{result}->{data} ))
  {
    Log3 $name, 2, "RainbirdController ($name) - ResponseProcessing: no result.data";
    return;
  }
 
  ### compare requestId with responseId
  if($request_id ne $decode_json->{id})
  {
    Log3 $name, 2, "RainbirdController ($name) - ResponseProcessing: request failed with wrong ResponseId! RequestId \"" . $request_id . "\" but got ResponseId \"" . $decode_json->{id} . "\"";
    return;	
  }
  
  ### decode data
  my $decoded = RainbirdController_DecodeData($hash, $decode_json->{result}->{data});
  
  if(not defined($decoded))
  {
    Log3 $name, 2, "RainbirdController ($name) - ResponseProcessing: decoded not defined";
  	return;
  }

  ### response
  my $response_id = $decoded->{"responseId"};

  if(not defined($response_id))
  {
    Log3 $name, 2, "RainbirdController ($name) - ResponseProcessing: response not defined";
    return;
  }
  
  # check id of response message
  if(defined($expectedResponse_id) and
    $response_id ne $expectedResponse_id)  
  {
  	if( $response_id eq "00" )
  	{
      Log3 $name, 2, "RainbirdController ($name) - ResponseProcessing: NAKCode \"" . sprintf("%X", $decoded->{"NAKCode"}) . "\" commandEcho \"" . sprintf("%X", $decoded->{"commandEcho"}) . "\"";
  	}
  	else
  	{
      Log3 $name, 2, "RainbirdController ($name) - ResponseProcessing: Status request failed with wrong response! Requested \"" . $expectedResponse_id . "\" but got \"" . $response_id . "\"";
  	}
  	
    return;
  }

  # is there a callback function?
  if(defined($resultCallback))
  {
    Log3 $name, 4, "RainbirdController ($name) - ResponseProcessing: calling lambda function";
    
    $resultCallback->($decoded, $sendData);
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
  
  # find response-structure in hash "ControllerResponses"
  my $cmd_template = $ControllerResponses{$response_id};
  if( not defined( $cmd_template ) )
  {
    Log3 $name, 2, "RainbirdController ($name) - decode: ControllerResponse \"" . $response_id . "\" not found!";
    return undef;
  }

  Log3 $name, 5, "RainbirdController ($name) - decode: data \"" . $data . "\"";

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
  
  my %result = (
    "identifier" => "Rainbird",
    "responseId" => $response_id,
    "type" => $cmd_template->{"type"},
  );
  
  while (my($key, $value) = each(%{$cmd_template})) 
  {
    if(ref($value) eq 'HASH' and
      defined($value->{"position"}) and
      defined($value->{"length"}))
    {
      my $currentValue = hex(substr($data, $value->{"position"}, $value->{"length"}));

      my $format = $value->{"format"};
      my $knownValues = $value->{"knownvalues"};
      
      ### if knownValue is defined
      if(defined($knownValues) and
        ref($knownValues) eq 'HASH' and
        defined($knownValues->{"$currentValue"}))
      {
        $currentValue =  "$currentValue: " . $knownValues->{$currentValue};
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
  Log3 $name, 5, "RainbirdController ($name) - encrypt: iv: \"" . (sprintf("%v02X", $iv) =~ s/\.//rg) . "\"";
  
  my $c = RainbirdController_AddPadding($hash, $tocodedata);
  Log3 $name, 5, "RainbirdController ($name) - encrypt: c: \"" . (sprintf("%v02X", $c) =~ s/\.//rg) . "\"";
  #Log3 $name, 5, "RainbirdController ($name) - encrypt: c: \"$c\"";

  my $b = sha256($encryptkey);
  Log3 $name, 5, "RainbirdController ($name) - encrypt: b: \"" . (sprintf("%v02X", $b) =~ s/\.//rg) . "\"";
  #Log3 $name, 5, "RainbirdController ($name) - encrypt: b: \"$b\"";

  my $b2 = sha256($data);
  Log3 $name, 5, "RainbirdController ($name) - encrypt: b2: \"" . (sprintf("%v02X", $b2) =~ s/\.//rg) . "\"";
  
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

  my $iv = substr($data, 32, 16);
  Log3 $name, 5, "RainbirdController ($name) - decrypt: iv: \"" . (sprintf("%v02X", $iv) =~ s/\.//rg) . "\"";

  my $encrypted_data = substr($data, 48, length($data));
  Log3 $name, 5, "RainbirdController ($name) - decrypt: encrypted_data: \"" . (sprintf("%v02X", $encrypted_data) =~ s/\.//rg) . "\"";

  my $symmetric_key = substr(sha256($decrypt_key), 0, 32);
  Log3 $name, 5, "RainbirdController ($name) - decrypt: symmetric_key: \"" . (sprintf("%v02X", $symmetric_key) =~ s/\.//rg) . "\"";

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

1;

=pod

=item device
=item summary Module to interact with WiFi LNK module of the Rain Bird Irrigation System

=begin html

<a name="RainbirdController"></a>
<h3>RainbirdController</h3>
<br>
In combination with the FHEM module RainbirdZone this module interacts with WiFi LNK module of the <b>Rain Bird Irrigation System</b>.<br>
<br>
You can start/stop the irrigation and get the currently active zone.<br>
<br>
This module communicates directly with the WiFi module - it does not support the cloud.<br>
The communication of this FHEM module competes with the communication of the app - maybe the app signals a communication error.
<br>
<ul>
  <a name="RainbirdControllerdefine"></a>
  <b>Define</b>
  <br><br>
  <code>define &lt;name&gt; RainbirdController &lt;host&gt;</code>
  <br><br>
  The RainbirdController device is created in the room "Rainbird".<br>
  If autocreate is enabled the zones of your system are recognized automatically and created in FHEM.
  <br><br>
  Example:
  <ul>
    <br>
    <code>define RainbirdController RainbirdController rainbird.fritz.box</code>
    <br>
  </ul>
  <br><br>
  <a name="RainbirdControllerreadings"></a>
  <b>Readings</b>
  <br><br>
  <ul>
    <li>currentDate - current internal date of the controller</li>
    <li>currentTime - current internal time of the controller</li>
    <li>irrigationState - don't know: always 1</li>
    <li>rainDelay - irrigation delay in days</li>
    <li>rainSensorState - state of the rain sensor: 1 irrigation suspended, 0 no rain detected</li>
    <li>zoneActive - the current active zone</li>
  </ul>
  <br><br>
  <a name="RainbirdControllerset"></a>
  <b>set</b>
  <br><br>
  <ul>
    <li>ClearReadings - clears all readings</li>
    <li>DeletePassword - deletes the password from store</li>
    <li>Password - sets the password in store</li>
    <li>RainDelay - sets the delay in days</li>
    <li>StopIrrigation - stops irrigating</li>
    <li>SynchronizeDateTime - synchronizes the internal date and time of the controller with fhem's time</li>
    <li>Date - sets the internal date of the controller - format YYYY-MM-DD</li>
    <li>Time - sets the internal time of the controller- format HH:MM or HH:MM:SS</li>
    <li>Update - updates the device info and state</li>
  </ul>
  <br><br>
  <a name="RainbirdControllerexpertset"></a>
  <b>set [expert mode]</b>
  <br><br>
  Expert mode is enabled by setting the attribute "expert".
  <br><br>
  <ul>
    <li>IrrigateZone - starts irrigating a zone</li>
  </ul>
  <br><br>
  <a name="RainbirdControllerexpertget"></a>
  <b>get [expert mode]</b>
  <br><br>
  Expert mode is enabled by setting the attribute "expert"".
  <br><br>
  <ul>
    <li>DeviceState - get current device state</li>
    <li>DeviceInfo - get device info</li>
    <li>ModelAndVersion - get device model and version</li>
    <li>AvailableZones - gets all available zones</li>
    <li>SerialNumber - get device serial number</li>
    <li>Date - get internal device date</li>
    <li>Time - get internal device time</li>
    <li>RainSensorState - get the state of the rainsensor</li>
    <li>RainDelay - get the delay in days</li>
    <li>CurrentIrrigation - get the current irrigation state</li>
    <li>IrrigationState - get the current irrigation state</li>
    <li>CommandSupport - get supported command info</li>
    <li>Factory Reset - reset all parameters of the device to default factory settings</li>
  </ul>
  <br><br>
  <a name="RainbirdControllerattributes"></a>
  <b>Attributes</b>
  <br><br>
  <ul>
    <li>disable - disables the device</li>
    <li>interval - interval of polling in seconds (Default=60)</li>
    <li>timeout - timeout for expected response in seconds (Default=20)</li>
    <li>retries - number of retries (Default=3)</li>
    <li>expert - switches to expert mode</li>
  </ul>
</ul>

=end html

=cut
