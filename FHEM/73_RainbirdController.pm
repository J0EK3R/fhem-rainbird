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
use Digest::SHA qw(sha256);
use Crypt::Mode::CBC;
use Crypt::CBC;

my $missingModul = '';
eval "use Encode qw(encode encode_utf8 decode_utf8);1" or $missingModul .= "Encode ";
eval "use IO::Socket::SSL;1" or $missingModul .= 'IO::Socket::SSL ';
eval "use JSON;1" or $missingModul .= "JSON ";

### Declare functions
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
sub RainbirdController_GetCurrentTime($;$);
sub RainbirdController_GetCurrentDate($;$);
sub RainbirdController_GetCurrentIrrigation($;$);
sub RainbirdController_GetIrrigationState($;$);
sub RainbirdController_GetRainDelay($;$);
sub RainbirdController_SetRainDelay($$;$);
sub RainbirdController_IrrigateZone($$$;$);
sub RainbirdController_TestZone($$;$);
sub RainbirdController_SetProgram($$;$);
sub RainbirdController_StopIrrigation($;$);
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


### statics
my $VERSION = '0.0.1';

my %ControllerCommands = (
    "ModelAndVersionRequest" => {"command" => "02", "response" => "82", "length" => 1},
    "AvailableStationsRequest" => {"command" => "03", "parameter" => 0, "response" => "83", "length" => 2},
    "CommandSupportRequest" => {"command" => "04", "commandToTest" => "02", "response" => "84", "length" => 2},
    "SerialNumberRequest" => {"command" => "05", "response" => "85", "length" => 1},
#    "SupportedRequest" => {"command" => "06", "response" => "85", "length" => 1},
#    "SupportedRequest" => {"command" => "07", "response" => "85", "length" => 1},
    "CurrentTimeRequest" => {"command" => "10", "response" => "90", "length" => 1},
#    "SupportedRequest" => {"command" => "11", "response" => "85", "length" => 1},
    "CurrentDateRequest" => {"command" => "12", "response" => "92", "length" => 1},
#    "SupportedRequest" => {"command" => "13", "response" => "85", "length" => 1},
#    "CurrentScheduleRequest" => {"command" => "20", "parameterOne" => 0, "parameterTwo" => 0 ,"response" => "A0", "length" => 3 },
#    "SupportedRequest" => {"command" => "21", "response" => "85", "length" => 1},
    "WaterBudgetRequest" => {"command" => "30", "parameter" => 0, "response" => "B0", "length" => 2},
#    "SupportedRequest" => {"command" => "31", "response" => "85", "length" => 1},
    "ZonesSeasonalAdjustFactorRequest" => {"command" => "32", "parameter" => 0, "response" => "B2", "length" => 2}, # not supported
    "RainDelayGetRequest" => {"command" => "36", "response" => "B6", "length" => 1},
    "RainDelaySetRequest" => {"command" => "37", "parameter" => 0, "response" => "01", "length" => 3},
    "ManuallyRunProgramRequest" => {"command" => "38", "parameter" => 0, "response" => "01", "length" => 2}, # not supported
    "ManuallyRunStationRequest" => {"command" => "39", "parameterOne" => 0, "parameterTwo" => 0, "response" => "01", "length" => 4}, 
    "TestStationsRequest" => {"command" => "3A", "parameter" => 0, "response" => "01", "length" => 2},
#    "SupportedRequest" => {"command" => "3B", "response" => "85", "length" => 1},
#    "SupportedRequest" => {"command" => "3D", "response" => "85", "length" => 1},
    "CurrentRainSensorStateRequest" => {"command" => "3E", "response" => "BE", "length" => 1},
    "CurrentStationsActiveRequest" => {"command" => "3F", "parameter" => 0, "response" => "BF", "length" => 2},
    "StopIrrigationRequest" => {"command" => "40", "response" => "01", "length" => 1},
#    "SupportedRequest" => {"command" => "41", "response" => "85", "length" => 1},
    "AdvanceStationRequest" => {"command" => "42", "parameter" => 0, "response" => "01", "length" => 2}, # not supported
    "CurrentIrrigationStateRequest" => {"command" => "48", "response" => "C8", "length" => 1},
    "CurrentControllerStateSet" => {"command" => "49", "parameter" => 0, "response" => "01", "length" => 2}, # not supported
    "ControllerEventTimestampRequest" => {"command" => "4A","parameter" => 0, "response" => "CA", "length" => 2}, # not supported
    "StackManuallyRunStationRequest" => {"command" => "4B","parameter" => 0, "parameterTwo" => 0, "parameterThree" => 0, "response" => "01", "length" => 4}, # not supported
    "CombinedControllerStateRequest" => {"command" => "4C", "response" => "CC","length" => 1 }, # not supported
#    "SupportedRequest" => {"command" => "50", "response" => "85", "length" => 1},
#    "SupportedRequest" => {"command" => "51", "response" => "85", "length" => 1},
#    "SupportedRequest" => {"command" => "52", "response" => "85", "length" => 1},
#    "SupportedRequest" => {"command" => "57", "response" => "85", "length" => 1},
);

my %ControllerResponses = (
    "00" => {"length" =>  3, "type" => "NotAcknowledgeResponse", "commandEcho" => {"position" => 2, "length" => 2}, "NAKCode" => {"position" => 4, "length" => 2} },
    "01" => {"length" =>  2, "type" => "AcknowledgeResponse", "commandEcho" => {"position" => 2, "length" => 2} },
    "82" => {"length" =>  5, "type" => "ModelAndVersionResponse", "modelID" => {"position" => 2, "length" => 4}, "protocolRevisionMajor" => {"position" => 6, "length" => 2}, "protocolRevisionMinor" => {"position" => 8, "length" => 2} },
    "83" => {"length" =>  6, "type" => "AvailableStationsResponse", "pageNumber" => {"position" => 2, "length" => 2}, "setStations" => {"position" => 4, "length" => 8} },
    "84" => {"length" =>  3,"type" => "CommandSupportResponse", "commandEcho" => {"position" => 2, "length" => 2}, "support" => {"position" => 4, "length" => 2} },
    "85" => {"length" =>  9, "type" => "SerialNumberResponse", "serialNumber" => {"position" => 2, "length" => 16} },
    "90" => {"length" =>  4, "type" => "CurrentTimeResponse", "hour" => {"position" => 2, "length" => 2}, "minute" => {"position" => 4, "length" => 2}, "second" => {"position" => 6, "length" => 2} },
    "92" => {"length" =>  4, "type" => "CurrentDateResponse", "day" => {"position" => 2, "length" => 2}, "month" => {"position" => 4, "length" => 1}, "year" => {"position" => 5, "length" => 3} },
    "B0" => {"length" =>  4, "type" => "WaterBudgetResponse", "programCode" => {"position" => 2, "length" => 2}, "seasonalAdjust" => {"position" => 4, "length" => 4} },
    "B2" => {"length" => 18, "type" => "ZonesSeasonalAdjustFactorResponse", "programCode" => {"position" => 2, "length" => 2}, "stationsSA" => {"position" => 4, "length" => 32} },
    "BE" => {"length" =>  2, "type" => "CurrentRainSensorStateResponse", "sensorState" => {"position" => 2, "length" => 2} },
    "BF" => {"length" =>  6, "type" => "CurrentStationsActiveResponse", "pageNumber" => {"position" => 2, "length" => 2}, "activeStations" => {"position" => 4, "length" => 8} },
    "B6" => {"length" =>  3, "type" => "RainDelaySettingResponse", "delaySetting" => {"position" => 2, "length" => 4} },
    "C8" => {"length" =>  2, "type" => "CurrentIrrigationStateResponse", "irrigationState" => {"position" => 2, "length" => 2} },
    "CA" => {"length" =>  6, "type" => "ControllerEventTimestampResponse", "eventId" => {"position" => 2, "length" => 2}, "timestamp" => {"position" => 4, "length" => 8} },
    "CC" => {"length" => 16, "type" => "CombinedControllerStateResponse", "hour" => {"position" => 2, "length" => 2}, "minute" => {"position" => 4, "length" => 2}, "second" => {"position" => 6, "length" => 2}, "day" => {"position" => 8, "length" => 2}, "month" => {"position" => 10, "length" => 1}, "year" => {"position" => 11, "length" => 3}, "delaySetting" => {"position" => 14, "length" => 4}, "sensorState" => {"position" => 18, "length" => 2}, "irrigationState" => {"position" => 20, "length" => 2}, "seasonalAdjust" => {"position" => 22, "length" => 4}, "remainingRuntime" => {"position" => 26, "length" => 4}, "activeStation" => {"position" => 30, "length" => 2} }
);

my $_DEFAULT_PAGE = 0;
my $DefaultInterval = 60;
my $DefaultRetryInterval = 60;
my $BLOCK_SIZE = 16;
my $INTERRUPT = "\x00";
my $PAD = "\x10";

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
    'expert:1 ' . 
    'interval ' . 
    'disabledForIntervals ' . 
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

  return 'too few parameters: define <NAME> RainbirdController' if ( @a != 3 );
  return 'Cannot define RainbirdController device. Perl modul "' . ${missingModul} . '" is missing.' if ($missingModul);

  my $name = $a[0];
  # $a[1] just contains the "RainbirdController" module name and we already know that! :-)
  my $host	= $a[2];

  ### Stop the current timer if one exists errornous 
  RemoveInternalTimer($hash);

  ### some internal settings
  $hash->{VERSION}                = $VERSION;
  $hash->{INTERVAL}               = $DefaultInterval;
  $hash->{RETRYINTERVAL}          = $DefaultRetryInterval;
  $hash->{NOTIFYDEV}              = "global,$name";
  $hash->{HOST}                   = $host;
  $hash->{EXPERTMODE}             = 0;
  $hash->{"ZONESAVAILABLECOUNT"}  = 0; # hidden internal with raw integer value
  $hash->{"ZONESAVAILABLEMASK"}   = 0; # hidden internal with raw integer value
  $hash->{"ZONEACTIVE"}           = 0; # hidden internal with raw integer value
  $hash->{"ZONEACTIVEMASK"}       = 0; # hidden internal with raw integer value
  $hash->{REQUESTID}              = 0;
  
  ### set attribute defaults
  CommandAttr( undef, $name . ' room Rainbird' )
    if ( AttrVal( $name, 'room', 'none' ) eq 'none' );

  # ensure attribute webCmd is present
  CommandAttr( undef, $name . ' webCmd StopIrrigation' )
    if ( AttrVal( $name, 'webCmd', 'none' ) eq 'none' );

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

  RemoveInternalTimer($hash);

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
      RemoveInternalTimer($hash);
      
      readingsSingleUpdate( $hash, 'state', 'inactive', 1 );
      Log3 $name, 3, "RainbirdController ($name) - disabled";
    } 
    elsif ( $cmd eq 'del' )
    {
      readingsSingleUpdate( $hash, 'state', 'active', 1 );
      Log3 $name, 3, "RainbirdController ($name) - enabled";
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
      RemoveInternalTimer($hash);

      return 'Interval must be greater than 0'
        unless ( $attrVal > 0 );

      $hash->{INTERVAL} = $attrVal;

      Log3 $name, 3, "RainbirdController ($name) - set interval: $attrVal";
    } 
    elsif ( $cmd eq 'del' )
    {
      RemoveInternalTimer($hash);
      
      $hash->{INTERVAL} = $DefaultInterval;

      Log3 $name, 3, "RainbirdController ($name) - delete User interval and set default: $hash->{INTERVAL}";
    }
  }

  ### Attribute "expert"
  if ( $attrName eq 'expert' )
  {
    if ( $cmd eq 'set' and $attrVal eq '1' )
    {
      $hash->{EXPERTMODE} = 1;
      Log3 $name, 3, "RainbirdController ($name) - expert mode enabled";
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

  return;
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
  } 
  
  ### DeletePassword
  elsif ( lc $cmd eq lc 'DeletePassword' )
  {
    RainbirdController_DeletePassword($hash);
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

  ### SetRainDelay
  elsif ( lc $cmd eq lc 'SetRainDelay' )
  {
    return "please set password first"
      if ( not defined( RainbirdController_ReadPassword($hash) ) );

    return "usage: $cmd <days>"
      if ( @args != 1 );

    my $days = $args[0];
    
    RainbirdController_SetRainDelay($hash, $days);
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
      $list .= " DeletePassword:noArg";
      $list .= " StopIrrigation:noArg";
      $list .= " IrrigateZone" if($hash->{EXPERTMODE});
      $list .= " SetRainDelay";
      $list .= " ClearReadings:noArg";
      $list .= " Update:noArg";
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
  
  ### CurrentTime
  elsif ( lc $cmd eq lc 'CurrentTime' )
  {
    return "please set password first"
      if ( not defined( RainbirdController_ReadPassword($hash) ) );
    
    RainbirdController_GetCurrentTime($hash);
  } 
  
  ### CurrentDate
  elsif ( lc $cmd eq lc 'CurrentDate' )
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
      $list .= " CurrentTime:noArg" if($hash->{EXPERTMODE});
      $list .= " CurrentDate:noArg" if($hash->{EXPERTMODE});
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
# (re)starts the internal timer
#####################################
sub RainbirdController_TimerRestart($)
{
  my ( $hash ) = @_;
  my $name = $hash->{NAME};

  RemoveInternalTimer($hash);

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

  RemoveInternalTimer($hash);

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

  my $reloadTimer = sub 
  {
    ### reload timer
    RemoveInternalTimer($hash);
    InternalTimer( gettimeofday() + $hash->{INTERVAL}, \&RainbirdController_TimerCallback, $hash );
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
      Log3 $name, 3, "RainbirdController ($name) - getDeviceState callback";
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
    my ( $result ) = @_;
    
    Log3 $name, 4, "RainbirdController ($name) - getModelAndVersion resultCallback";
    
    if( defined($result) )
    {
      readingsBeginUpdate($hash);

      if( defined($result->{"modelID"}) )
      {
        $hash->{MODELID} = $result->{"modelID"};
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
    my ( $result ) = @_;
    
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
  RainbirdController_Command($hash, $resultCallback, $command, $_DEFAULT_PAGE );
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
    my ( $result ) = @_;
    
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
    my ( $result ) = @_;
    
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
    my ( $result ) = @_;
    
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
    my ( $result ) = @_;
    
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
    
  my $command = "CurrentTime";
  
  Log3 $name, 4, "RainbirdController ($name) - getCurrentTime";
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result ) = @_;
    
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
# GetCurrentDate
#####################################
sub RainbirdController_GetCurrentDate($;$)
{
  my ( $hash, $callback ) = @_;
  my $name = $hash->{NAME};
  
  my $command = "CurrentDate";
     
  Log3 $name, 4, "RainbirdController ($name) - getCurrentDate";
    
  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $result ) = @_;
    
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
    my ( $result ) = @_;
    
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
    my ( $result ) = @_;
    
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
  RainbirdController_Command($hash, $resultCallback, $command, $_DEFAULT_PAGE );
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
    my ( $result ) = @_;
    
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
    my ( $result ) = @_;
    
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
    my ( $result ) = @_;
    
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
    my ( $result ) = @_;
    
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
    my ( $result ) = @_;
    
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
    my ( $result ) = @_;
    
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

  RainbirdController_Request($hash, $resultCallback, $command_set, $data );
}

#####################################
# Request
#####################################
sub RainbirdController_Request($$$$)
{
  my ( $hash, $resultCallback, $command_set, $data ) = @_;
  my $name = $hash->{NAME};
    
  my $request_id = ++$hash->{REQUESTID};
  #my $request_id = 666;
  
  my $send_data = 
  '{
  	"id":' . $request_id . ',
  	"jsonrpc":"2.0",
  	"method":"tunnelSip",
  	"params":
  	{
  	  "data":"' . $data . '",
  	  "length":' . $command_set->{"length"} . '
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

  Log3 $name, 5, "RainbirdController ($name) - Send with URL: $uri, HEADER: $header, DATA: $payload, METHOD: $method";
    
  HttpUtils_NonblockingGet(
  {
    hash      => $hash,
    
    url       => $uri,
    method    => $method,
    header    => $header,
    data      => $payload,
    timeout   => 20,
    doTrigger => 1,
    callback  => \&RainbirdController_ErrorHandling,
    
    request_id => $request_id,
    commandset => $command_set,
    resultCallback => $resultCallback,
  });
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

  ### check error variable
  if ( defined($err) and 
    $err ne "" )
  {
    Log3 $name, 3, "RainbirdController ($name) - ErrorHandling: Error: " . $err . " data: " . $data . "";

    readingsSingleUpdate( $hash, 'state', 'error ' . $err, 1 );

    return;
  }
  
  ### check code
  if ( $data eq "" and
    exists( $param->{code} ) and 
    $param->{code} != 200 )
  {
    Log3 $name, 3, "RainbirdController ($name) - ErrorHandling: Code: " . $param->{code} . " data: " . $data . "";
    
    if( $param->{code} == 403 ) ### Forbidden
    {
      readingsSingleUpdate( $hash, 'state', 'wrong password', 1 );
    }
    else
    {
      readingsSingleUpdate( $hash, 'state', 'error ' . $param->{code}, 1 );
    }
    
    return;
  }

  Log3 $name, 5, "RainbirdController ($name) - ErrorHandling: RequestID: " . $request_id . " data: " . $data . "";

  ### no error: process response
  RainbirdController_ResponseProcessing( $param, $data );
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
  my $command_set = $param->{commandset};
  my $resultCallback = $param->{resultCallback};

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
  my $response = $decoded->{"response"};

  if(not defined($response))
  {
    Log3 $name, 2, "RainbirdController ($name) - ResponseProcessing: response not defined";
    return;
  }
  
  # check id of response message
  if($response ne $command_set->{"response"})  
  {
  	if( $response eq "00" )
  	{
      Log3 $name, 2, "RainbirdController ($name) - ResponseProcessing: NAKCode \"" . sprintf("%X", $decoded->{"NAKCode"}) . "\" commandEcho \"" . sprintf("%X", $decoded->{"commandEcho"}) . "\"";
  	}
  	else
  	{
      Log3 $name, 2, "RainbirdController ($name) - ResponseProcessing: Status request failed with wrong response! Requested \"" . $command_set->{"response"} . "\" but got \"" . $response . "\"";
  	}
  	
    return;
  }

  # is there a callback function?
  if(defined($resultCallback))
  {
    Log3 $name, 4, "RainbirdController ($name) - ResponseProcessing: calling lambda function";
    
    $resultCallback->($decoded);
  }
}

#####################################
# EncodeData
#####################################
sub RainbirdController_EncodeData($$@)
{
  my ( $hash, $command_set, @args ) = @_;
  my $name = $hash->{NAME};

  my $len_args = scalar (@args); # Anzahl der Args

  Log3 $name, 5, "RainbirdController ($name) - encode with $len_args Args";

  # get fields from structure
  my $command_set_code = $command_set->{"command"};
  my $command_set_length = $command_set->{"length"};

  if( $len_args > $command_set_length - 1 )
  {
    Log3 $name, 2, "RainbirdController ($name) - encode: Too much parameters. " . $command_set_length - 1 . " expected\n" . $command_set;
    return undef;
  }
  
  #  params = (cmd_code,) + tuple(map(lambda x: int(x), args))
  #  arg_placeholders = (("%%0%dX" % ((command_set["length"] - len(args)) * 2))
  #                      if len(args) > 0
  #                      else "") + ("%02X" * (len(args) - 1))
  #  data = ("%s" + arg_placeholders) % (params)
  my @params = ($command_set_code, @args);

  my $arg_placeholders = "";
  if($len_args > 0)
  {
    $arg_placeholders = sprintf("%%0%dX", ($command_set_length - $len_args) * 2);
    $arg_placeholders .= ("%02X" x ($len_args - 1));
  }                        
  my $result = sprintf("%s" . $arg_placeholders, @params);
  
  Log3 $name, 5, "RainbirdController ($name) - encode: $result";
  return $result;
}

#####################################
# DecodeData
#####################################
sub RainbirdController_DecodeData($$)
{
  my ( $hash, $data ) = @_;
  my $name = $hash->{NAME};
  
  my $response = substr($data, 0, 2);
  
  # find response-structure in hash "ControllerResponses"
  my $cmd_template = $ControllerResponses{$response};
  if( not defined( $cmd_template ) )
  {
    Log3 $name, 2, "RainbirdController ($name) - decode: ControllerResponse \"" . $response . "\" not found!";
    return undef;
  }

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
    "response" => $response,
    "type" => $cmd_template->{"type"},
  );
  
  while (my($key, $value) = each(%{$cmd_template})) 
  {
    if(ref($value) eq 'HASH' and
      defined($value->{"position"}) and
      defined($value->{"length"}))
    {
      Log3 $name, 5, "RainbirdController ($name) - decode: insert $key = " . hex(substr($data, $value->{"position"}, $value->{"length"})) . "\n";

      $result{$key} = hex(substr($data, $value->{"position"}, $value->{"length"}));        
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
  #Log3 $name, 3, "RainbirdController ($name) - encrypt: c: \"$c\"";

  my $b = sha256($encryptkey);
  Log3 $name, 5, "RainbirdController ($name) - encrypt: b: \"" . (sprintf("%v02X", $b) =~ s/\.//rg) . "\"";
  #Log3 $name, 3, "RainbirdController ($name) - encrypt: b: \"$b\"";

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
  #Log3 $name, 3, "RainbirdController ($name) - encrypt: encrypteddata: \"$encrypteddata\"";

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
  #Log3 $name, 3, "RainbirdController ($name) - decrypt: decrypteddata: \"" . $decrypteddata . "\"";
  
  $decrypteddata =~ s/\x10+$//;
  $decrypteddata =~ s/\x0a+$//;
  $decrypteddata =~ s/\x00+$//;
  # Take 1 or more white spaces (\s+) till the end of the string ($), and replace them with an empty string. 
  $decrypteddata =~ s/\s+$//;
  
  Log3 $name, 5, "RainbirdController ($name) - decrypt: decrypteddata: \"" . (sprintf("%v02X", $decrypteddata) =~ s/\.//rg) . "\"";
  #Log3 $name, 3, "RainbirdController ($name) - decrypt: decrypteddata: \"" . $decrypteddata . "\"";
  
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
    Log3 $name, 3, "RainbirdController ($name) - unable to read password from file: $err";
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
    Log3 $name, 3, "RainbirdController ($name) - No password in file";
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

1;

=pod

=item device
=item summary       Modul to communicate with a Rainbird Controller

=begin html

<a name="RainbirdController"></a>
<h3>RainbirdController</h3>
<ul>
  In combination with RainbirdZone this FHEM Module controls the communication to a Rainbird Controller.
</ul>
<br>
<ul>
  <a name="RainbirdControllerdefine"></a>
  <b>Define</b>
  <br><br>
  <code>define &lt;name&gt; RainbirdController &lt;host&gt;</code>
  <br><br>
  Example:
  <ul>
    <br>
    <code>define RainbirdController RainbirdController rainbird.fritz.box</code>
    <br>
  </ul>
  <br>
  The RainbirdController device is created in the room Rainbird, then the Zones of your system are recognized automatically and created in FHEM.
  <br>
  <a name="RainbirdControllerreadings"></a>
  <br><br>
  <b>Readings</b>
  <ul>
    <li>currentDate - current internal date of the controller</li>
    <li>currentTime - current internal time of the controller</li>
    <li>irrigationState - always 1</li>
    <li>rainDelay - irrigation delay in days</li>
    <li>rainSensorState - state of the rain sensor</li>
    <li>zoneActive - the current active zone</li>
  </ul>
  <a name="RainbirdControllerset"></a>
  <br><br>
  <b>set</b>
  <ul>
    <li>ClearReadings - clears all readings</li>
    <li>DeletePassword - deletes the password from store</li>
    <li>Password - sets the password in store</li>
    <li>SetRainDelay - sets the delay in days</li>
    <li>StopIrrigation - stops irrigating</li>
    <li>IrrigateZone - starts irrigating a zone [available in expert mode]</li>
    <li>Update - updates the device info and state</li>
  </ul>
  <a name="RainbirdControllerget"></a>
  <br><br>
  <b>get</b>
  <ul>
    <li>AvailableZones - gets all available zones [available in expert mode]</li>
    <li>DeviceState - get current device state [available in expert mode]</li>
    <li>DeviceInfo - get device info [available in expert mode]</li>
    <li>ModelAndVersion - get device model and version [available in expert mode]</li>
    <li>SerialNumber - get device serial number [available in expert mode]</li>
    <li>CurrentTime - get internal device time [available in expert mode]</li>
    <li>CurrentDate - get internal device date [available in expert mode]</li>
    <li>RainSensorState - get the state of the rainsensor [available in expert mode]</li>
    <li>RainDelay - get the delay in days [available in expert mode]</li>
    <li>CurrentIrrigation - get the current irrigation state [available in expert mode]</li>
    <li>IrrigationState - get the current irrigation state [available in expert mode]</li>
    <li>CommandSupport - get supported command info [available in expert mode]</li>
  </ul>
  <a name="RainbirdControllerattributes"></a>
  <br><br>
  <b>Attributes</b>
  <ul>
    <li>disable - disables the device</li>
    <li>interval - interval of polling in seconds (Default=60)</li>
    <li>expert - switches to expert mode</li>
  </ul>
</ul>

=end html

=cut
