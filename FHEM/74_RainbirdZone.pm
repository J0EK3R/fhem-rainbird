###############################################################################
#
# Developed with eclipse
#
#  (c) 2019 Copyright: J.K. (J0EK3R at gmx dot net)
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
# $Id: 74_RainbirdZone.pm 201 2020-09-18 06:14:00Z J0EK3R $
#
###############################################################################

### our packagename
package main;

use strict;
use warnings;

my $missingModul = "";
eval "use JSON;1" or $missingModul .= "JSON ";

### Forward declarations
sub RainbirdZone_Initialize($);
sub RainbirdZone_Define($$);
sub RainbirdZone_Undef($$);
sub RainbirdZone_Delete($$);
sub RainbirdZone_Attr(@);
sub RainbirdZone_Notify($$);
sub RainbirdZone_Set($@);
sub RainbirdZone_Parse($$);
sub RainbirdZone_ProcessMessage($$);
sub RainbirdZone_UpdateState($);
sub RainbirdZone_UpdateZoneAvailable($);
sub RainbirdZone_UpdateSchedule($);
sub RainbirdZone_UpdateIrrigation($);
sub RainbirdZone_UpdateZoneActive($);

### internal tool functions
sub RainbirdZone_GetZoneMask($);

### statics
my $VERSION = '1.8.1';

my $DefaultIrrigationTime = 10; # default value for irrigate command without parameter in minutes

#####################################
# Initialize( $hash )
#####################################
sub RainbirdZone_Initialize($)
{
  my ($hash) = @_;

  # Provider

  # Consumer
  $hash->{SetFn}    = \&RainbirdZone_Set;
  $hash->{GetFn}    = \&RainbirdZone_Get;
  $hash->{DefFn}    = \&RainbirdZone_Define;
  $hash->{UndefFn}  = \&RainbirdZone_Undef;
  $hash->{DeleteFn} = \&RainbirdZone_Delete;
  $hash->{ParseFn}  = \&RainbirdZone_Parse;
  $hash->{NotifyFn} = \&RainbirdZone_Notify;
  $hash->{AttrFn}   = \&RainbirdZone_Attr;
  
  $hash->{Match} = '"identifier":"Rainbird"'; # example {"response":"BF","pageNumber":0,"type":"CurrentStationsActiveResponse","identifier":"Rainbird","activeStations":0}

  $hash->{AttrList} = "" . 
    "IODev " . 
    'expert:1,0 ' . 
    "disable:1 " . 
    "irrigationTime:10 " .
     $readingFnAttributes;

  foreach my $d ( sort keys %{ $modules{RainbirdZone}{defptr} } )
  {
    my $hash = $modules{RainbirdZone}{defptr}{$d};
    $hash->{VERSION} = $VERSION;
  }
}

#####################################
# Define( $hash, $def)
#####################################
sub RainbirdZone_Define($$)
{
  my ( $hash, $def ) = @_;
  my @a = split( "[ \t]+", $def );

  return 'too few parameters: define <NAME> RainbirdZone <zone_Id>' if ( @a < 3 );
  return 'too much parameters: define <NAME> RainbirdZone <zone_Id>' if ( @a > 3 );
  return 'Cannot define RainbirdZone device. Perl modul "' . ${missingModul} . '" is missing.' if ($missingModul);

  my $name   = $a[0];
  #            $a[1] just contains the "RainbirdZone" module name and we already know that! :-)
  my $zoneId = $a[2];

  $hash->{VERSION}        = $VERSION;
  $hash->{NOTIFYDEV}      = "global,$name";
  $hash->{ZONEID}         = $zoneId;
  $hash->{ZONEMASK}       = RainbirdZone_GetZoneMask($zoneId);
  $hash->{IRRIGATIONTIME} = $DefaultIrrigationTime;
  $hash->{AVAILABLE}      = 0;
  $hash->{EXPERTMODE}     = 0;
  
  ### ensure attribute IODev is present
  CommandAttr( undef, $name . ' IODev ' . $modules{RainbirdController}{defptr}{CONTROLLER}->{NAME} )
    if ( AttrVal( $name, 'IODev', 'none' ) eq 'none' );

  ### get IODev and assign Zone to IODev
  my $iodev = AttrVal( $name, 'IODev', 'none' );

  AssignIoPort( $hash, $iodev )
    if ( !$hash->{IODev} );

  if ( defined( $hash->{IODev}->{NAME} ) )
  {
    Log3 $name, 3, "RainbirdZone ($name) - I/O device is " . $hash->{IODev}->{NAME};
  } 
  else
  {
    Log3 $name, 1, "RainbirdZone ($name) - no I/O device";
  }

  $iodev = $hash->{IODev}->{NAME};

  my $d = $modules{RainbirdZone}{defptr}{$zoneId};

  return "RainbirdZone device $name on RainbirdController $iodev already defined."
    if ( defined($d) and 
      $d->{IODev} == $hash->{IODev} and 
      $d->{NAME} ne $name
    );

  my $iodev_room = AttrVal( $iodev, 'room', 'Rainbird' );

  ### ensure attribute room is present
  CommandAttr( undef, $name . ' room ' . $iodev_room )
    if ( AttrVal( $name, 'room', 'none' ) eq 'none' );

  ### ensure attribute webCmd is present
  CommandAttr( undef, $name . ' webCmd Irrigate:Stop' )
    if ( AttrVal( $name, 'webCmd', 'none' ) eq 'none' );

  ### ensure attribute irrigationTime is present
  CommandAttr( undef, $name . ' irrigationTime 10' )
    if ( AttrVal( $name, 'irrigationTime', 'none' ) eq 'none' );

  # ensure attribute event-on-change-reading is present
  CommandAttr( undef, $name . ' event-on-change-reading .*' )
    if ( AttrVal( $name, 'event-on-change-reading', 'none' ) eq 'none' );

  ### set reference to this instance in global modules hash
  $modules{RainbirdZone}{defptr}{$zoneId} = $hash;

  ### set initial state
  readingsSingleUpdate( $hash, 'state', 'initialized', 1 );

  ### update -> values are fetched from internals of attached RainbirdController
  RainbirdZone_UpdateZoneAvailable($hash);
  RainbirdZone_UpdateZoneActive($hash);

  Log3 $name, 3, "RainbirdZone ($name) - defined RainbirdZone with ZONEID: $zoneId";

  return undef;
}

#####################################
# Undef( $hash, $arg )
#####################################
sub RainbirdZone_Undef($$)
{
  my ( $hash, $arg ) = @_;
  my $name     = $hash->{NAME};
  my $deviceId = $hash->{DEVICEID};

  delete $modules{RainbirdZone}{defptr}{$deviceId};

  return undef;
}

#####################################
# Delete( $hash, $name )
#####################################
sub RainbirdZone_Delete($$)
{
  my ( $hash, $name ) = @_;

  return undef;
}

#####################################
# Attr( $cmd, $name, $attrName, $attrVal )
#####################################
sub RainbirdZone_Attr(@)
{
  my ( $cmd, $name, $attrName, $attrVal ) = @_;
  my $hash = $defs{$name};

  Log3 $name, 4, "RainbirdZone ($name) - Attr was called";

  # Attribute "disable"
  if ( $attrName eq 'disable' )
  {
    if ( $cmd eq 'set' and $attrVal eq '1' )
    {
      readingsSingleUpdate( $hash, 'state', 'disabled', 1 );
      Log3 $name, 3, "RainbirdZone ($name) - disabled";
    } 
    elsif ( $cmd eq 'del' )
    {
      readingsSingleUpdate( $hash, 'state', 'ready', 1 );
      Log3 $name, 3, "RainbirdZone ($name) - enabled";
    }
  }

  # Attribute "irrigationTime"
  elsif ( $attrName eq 'irrigationTime' )
  {
    if ( $cmd eq 'set' )
    {
      $hash->{IRRIGATIONTIME} = $attrVal;
    } 
    elsif ( $cmd eq 'del' )
    {
      $hash->{IRRIGATIONTIME} = $DefaultIrrigationTime;
    }
    Log3 $name, 3, "RainbirdZone ($name) - set irrigationtime to " . $hash->{IRRIGATIONTIME} . " minutes";
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
# Notify( $hash, $dev )
#####################################
sub RainbirdZone_Notify($$)
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

  Log3 $name, 4, "RainbirdZone ($name) - Notify";

  return undef;
}

#####################################
# Set( $hash, $name, $cmd, @args )
#####################################
sub RainbirdZone_Set($@)
{
  my ( $hash, $name, $cmd, @args ) = @_;

  my $zoneId = $hash->{ZONEID};

  Log3 $name, 4, "RainbirdZone ($name) - Set was called: cmd= $cmd";

  ### Irrigate
  if ( lc $cmd eq lc 'Irrigate' )
  {
    return "usage: $cmd [opt: <minutes>]"
      if ( @args > 1 );

    ### default value from internals
    my $minutes = $hash->{IRRIGATIONTIME};
    
    ### if there is a parameter
    $minutes = $args[0]
      if ( @args == 1 );

    # send command via RainbirdController
    IOWrite( $hash, "IrrigateZone", $zoneId, $minutes );
  } 

  ### Stop
  elsif ( lc $cmd eq lc 'Stop' )
  {
    return "usage: $cmd"
      if ( @args != 0 );

    # send command via RainbirdController
    IOWrite( $hash, "StopIrrigation" );
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

    $list .= " Stop:noArg" if ($hash->{AVAILABLE} == 1);
    $list .= " Irrigate" if ($hash->{AVAILABLE} == 1);
    $list .= " ClearReadings:noArg";

    return "Unknown argument $cmd, choose one of $list";
  }
}

#####################################
# Get( $hash, $name, $cmd, @args )
#####################################
sub RainbirdZone_Get($@)
{
  my ( $hash, $name, $cmd, @args ) = @_;

  my $zoneId = $hash->{ZONEID};

  Log3 $name, 4, "RainbirdZone ($name) - Get was called: cmd= $cmd";

  ### Schedule
  if ( lc $cmd eq lc 'Schedule' )
  {
    return "usage: $cmd"
      if ( @args != 0 );

    # send command via RainbirdController
    IOWrite( $hash, "ZoneGetSchedule", $zoneId );
  } 

  ### else
  else
  {
    my $list = "";

    $list .= " Schedule:noArg" if ($hash->{EXPERTMODE} and $hash->{AVAILABLE} == 1);

    return "Unknown argument $cmd, choose one of $list";
  }
}

#####################################
# Parse( $rainbirdController_hash, $message )
#####################################
sub RainbirdZone_Parse($$)
{
  my ( $rainbirdController_hash, $message ) = @_;
  my $rainbirdController_name = $rainbirdController_hash->{NAME};

  Log3 $rainbirdController_name, 4, "RainbirdZone - Parse was called from $rainbirdController_name: \"$message\"";

  ### create structure from json string
  my $json_message = eval { decode_json($message) };

  if ($@)
  {
    Log3 $rainbirdController_name, 2, "RainbirdZone - Parse: JSON error while request: $@";
    return;
  }

  ### autocreate not existing RainbirdZone modules
  if(defined($modules{RainbirdZone}{defptr}) and
    defined($rainbirdController_hash) and
    $rainbirdController_hash->{AUTOCREATEZONES} == 1)
  {
    my $zonesAvailableMask = $rainbirdController_hash->{"ZONESAVAILABLEMASK"};
    for my $currentZoneId (1..32)
    {
      ### shift bit to current position in mask
      my $currentBit = 1 << ($currentZoneId - 1);
      
      ### if bit is set in mask
      if( $zonesAvailableMask & $currentBit and
        not defined ($modules{RainbirdZone}{defptr}{$currentZoneId}) )
      {
        Log3 $rainbirdController_name, 4, "RainbirdZone - RainbirdZone $currentZoneId not defined";

        my $rainbirdZone_name = 'RainbirdZone.' . sprintf("%02d", $currentZoneId);
        
        DoTrigger("global", 'UNDEFINED ' . $rainbirdZone_name . ' RainbirdZone ' . $currentZoneId);
      }
    }

    ### dispatch message to any existing RainbirdZone module
    if($json_message->{"identifier"} eq "Rainbird") # additional (unnecessary) check
    {
      while (my ($zoneId, $hash) = each (% {$modules{RainbirdZone}{defptr}}))
      {
        my $rainbirdZone_name = $hash->{NAME};
        Log3 $rainbirdController_name, 5, "RainbirdZone - Parse found module: \"$rainbirdZone_name\"";
      
        RainbirdZone_ProcessMessage($hash, $json_message);
        
        ### set result to trigger
        DoTrigger($rainbirdZone_name, undef);
      }  
    }
    
    ### don't use FHEM's trigger
    return "";
  }
  else
  {
    Log3 $rainbirdController_name, 4, "RainbirdZone - Parse no Zones defined";
  }
  
  return;
}

#####################################
# ProcessMessage( $hash, $json_message )
#####################################
sub RainbirdZone_ProcessMessage($$)
{
  my ( $hash, $json_message ) = @_;
  my $name = $hash->{NAME};

  return
    if ( IsDisabled($name) );

  Log3 $name, 5, "RainbirdZone ($name) - ProcessMessage was called";
  
  if( not defined($json_message) )
  {
    Log3 $name, 3, "RainbirdZone ($name) - ProcessMessage json_message undefined";
    return;
  }
  
  my $type = $json_message->{"type"};
  if( not defined($type) )
  {
    Log3 $name, 3, "RainbirdZone ($name) - ProcessMessage response undefined";
    return;
  }
  
  ### CurrentStationsActiveResponse
  if(lc $type eq lc "CurrentStationsActiveResponse")
  {
    ### "{"response":"BF","type":"CurrentStationsActiveResponse","identifier":"Rainbird","pageNumber":0,"activeStations":134217728}"

    ### just trigger function -> values are fetched from internals of attached RainbirdController
    RainbirdZone_UpdateState($hash);
  }

  ### GetIrrigationStateResponse
  if(lc $type eq lc "GetIrrigationStateResponse")
  {
    ### just trigger function -> values are fetched from internals of attached RainbirdController
    RainbirdZone_UpdateState($hash);
  }

  ### AvailableStationsResponse
  elsif(lc $type eq lc "AvailableStationsResponse")
  {
    ### "{"identifier":"Rainbird","pageNumber":0,"setStations":4278190080,"type":"AvailableStationsResponse","response":"83"}"

    ### just trigger function -> values are fetched from internals of attached RainbirdController
    RainbirdZone_UpdateState($hash);
  }

  ### CurrentScheduleResponse
  elsif(lc $type eq lc "CurrentScheduleResponse")
  {
    #"A0" => {"length" =>  4, "type" => "CurrentScheduleResponse", 
    #  "zoneId"         => {"position" =>  2, "length" => 4}, 
    #  "timespan"       => {"position" =>  6, "length" => 2}, 
    #  "timer1"         => {"position" =>  8, "length" => 2, "knownvalues" => {"24:00" => "off"}, "converter" => \&RainbirdController_GetTimeFrom10Minutes},
    #  "timer2"         => {"position" => 10, "length" => 2, "knownvalues" => {"24:00" => "off"}, "converter" => \&RainbirdController_GetTimeFrom10Minutes},
    #  "timer3"         => {"position" => 12, "length" => 2, "knownvalues" => {"24:00" => "off"}, "converter" => \&RainbirdController_GetTimeFrom10Minutes},
    #  "timer4"         => {"position" => 14, "length" => 2, "knownvalues" => {"24:00" => "off"}, "converter" => \&RainbirdController_GetTimeFrom10Minutes}, 
    #  "timer5"         => {"position" => 16, "length" => 2, "knownvalues" => {"24:00" => "off"}, "converter" => \&RainbirdController_GetTimeFrom10Minutes},
    #  "param1"         => {"position" => 18, "length" => 2, "knownvalues" => {"144" => "off"}}, 
    #  "mode"           => {"position" => 20, "length" => 2, "knownvalues" => {"0" => "user defined", "1" => "odd", "2" => "even", "3" => "zyclic"}}, 
    #  "weekday"        => {"position" => 22, "length" => 2, "converter" => \&RainbirdController_GetWeekdaysFromBitmask}, 
    #  "interval"       => {"position" => 24, "length" => 2}, 
    #  "intervaloffset" => {"position" => 26, "length" => 2}},

    RainbirdZone_UpdateState($hash);
  }

  else
  {
    Log3 $name, 4, "RainbirdZone ($name) - ProcessMessage response not handled";
  }
}

#####################################
# UpdateState( $hash )
#####################################
sub RainbirdZone_UpdateState($)
{
  my ( $hash ) = @_;
  my $name = $hash->{NAME};

  Log3 $name, 5, "RainbirdZone ($name) - UpdateState was called";
  
  RainbirdZone_UpdateZoneActive($hash);
  RainbirdZone_UpdateZoneAvailable($hash);
  RainbirdZone_UpdateSchedule($hash);
}

#####################################
# UpdateZoneActive( $hash )
#####################################
sub RainbirdZone_UpdateZoneActive($)
{
  my ( $hash ) = @_;
  my $name = $hash->{NAME};

  Log3 $name, 5, "RainbirdZone ($name) - GetZoneActive was called";

  my $activeZoneMask = $hash->{IODev}->{ZONEACTIVEMASK};
  my $mask = $hash->{ZONEMASK};
  my $result = $mask & $activeZoneMask;

  my $activeZoneSecondsLeft = $hash->{IODev}->{ZONEACTIVESECONDSLEFT};
  $activeZoneSecondsLeft = 0 if(!defined($activeZoneSecondsLeft));

  readingsBeginUpdate($hash);
  
  if($result)
  {
    readingsBulkUpdate( $hash, 'state', 'irrigating', 1 );
    readingsBulkUpdate( $hash, 'irrigating', 1, 1 );
    readingsBulkUpdate( $hash, 'irrigationSecondsLeft', $activeZoneSecondsLeft, 1 );
  }
  else
  {
    readingsBulkUpdate( $hash, 'irrigating', 0, 1 );
    readingsBulkUpdate( $hash, 'irrigationSecondsLeft', 0, 1 );
    
    if($hash->{AVAILABLE} == 1)
    {
      readingsBulkUpdate( $hash, 'state', 'ready', 1 );
    }
  }
  readingsEndUpdate( $hash, 1 );
  
  return $result;
}

#####################################
# UpdateZoneAvailable( $hash )
#####################################
sub RainbirdZone_UpdateZoneAvailable($)
{
  my ( $hash ) = @_;
  my $name = $hash->{NAME};

  Log3 $name, 5, "RainbirdZone ($name) - GetZoneAvailable was called";

  my $availableZoneMask = $hash->{IODev}->{ZONESAVAILABLEMASK}; 
  my $mask = $hash->{ZONEMASK};
  my $result = $mask & $availableZoneMask;

  Log3 $name, 5, "RainbirdZone ($name) - GetZoneAvailable $availableZoneMask $result";
  
  readingsBeginUpdate($hash);
  
  if($result)
  {
    ### set internal
    $hash->{AVAILABLE} = 1;

    #readingsBulkUpdate( $hash, 'available', 1, 1 );
    #readingsBulkUpdate( $hash, 'state', 'available', 1 );
  }
  else
  {
    ### set internal
    $hash->{AVAILABLE} = 0;

    #readingsBulkUpdate( $hash, 'available', 0, 1 );
    readingsBulkUpdate( $hash, 'state', 'unavailable', 1 );
  }
  readingsEndUpdate( $hash, 1 );
  
  return $result;
}

#####################################
# UpdateSchedule( $hash )
#####################################
sub RainbirdZone_UpdateSchedule($)
{
  my ( $hash ) = @_;
  my $name = $hash->{NAME};

  Log3 $name, 5, "RainbirdZone ($name) - GetSchedule was called";

  if(defined($hash->{IODev}) and
    defined($hash->{IODev}{helper}))
  {
    my $zoneSchedule = $hash->{IODev}{helper}{'Zone' . $hash->{ZONEID}}{'Schedule'}; 

    if(defined($zoneSchedule))
    {
      ### save schedule hash as internals
      $hash->{helper}{zoneSchedule} = $zoneSchedule;
      
      readingsBeginUpdate($hash);

      readingsBulkUpdate( $hash, 'scheduletimespan', $zoneSchedule->{"timespan"}, 1 ) if( defined( $zoneSchedule->{"timespan"} ));
      readingsBulkUpdate( $hash, 'scheduletimer1', $zoneSchedule->{"timer1"}, 1 ) if( defined( $zoneSchedule->{"timer1"} ));
      readingsBulkUpdate( $hash, 'scheduletimer2', $zoneSchedule->{"timer2"}, 1 ) if( defined( $zoneSchedule->{"timer2"} ));
      readingsBulkUpdate( $hash, 'scheduletimer3', $zoneSchedule->{"timer3"}, 1 ) if( defined( $zoneSchedule->{"timer3"} ));
      readingsBulkUpdate( $hash, 'scheduletimer4', $zoneSchedule->{"timer4"}, 1 ) if( defined( $zoneSchedule->{"timer4"} ));
      readingsBulkUpdate( $hash, 'scheduletimer5', $zoneSchedule->{"timer5"}, 1 ) if( defined( $zoneSchedule->{"timer5"} ));
      readingsBulkUpdate( $hash, 'schedulemode', $zoneSchedule->{"mode"}, 1 ) if( defined( $zoneSchedule->{"mode"} ));
      readingsBulkUpdate( $hash, 'scheduleweekday', $zoneSchedule->{"weekday"}, 1 ) if( defined( $zoneSchedule->{"weekday"} ));
      readingsBulkUpdate( $hash, 'scheduleinterval', $zoneSchedule->{"interval"}, 1 ) if( defined( $zoneSchedule->{"interval"} ));
      readingsBulkUpdate( $hash, 'scheduleintervaldaysleft', $zoneSchedule->{"intervaldaysleft"}, 1 ) if( defined( $zoneSchedule->{"intervaldaysleft"} ));

      readingsEndUpdate( $hash, 1 );
    }
  }
}

#####################################
# GetZoneMask( $hash )
#####################################
sub RainbirdZone_GetZoneMask($)
{
  my ( $zoneId ) = @_;
  
  my $mask = 1 << ($zoneId - 1);
  return $mask;
}

1;

=pod
=item device
=item summary Modul representing an irrigation zone of a Rainbird Controller
=begin html

  <a name="RainbirdZone"></a><h3>RainbirdZone</h3>
  <ul>
    In combination with RainbirdController this FHEM module represents an irrigation zone of the <b>Rain Bird Irrigation System</b>.<br>
    <br>
    Once the RainbirdController device is created and connected and autocreate is enabled all available irrigation zones are automatically recognized and created in FHEM.<br>
    <br>
    <a name="RainbirdZonedefine"></a><b>Define</b>
    <ul>
      <code><B>define &lt;name&gt; RainbirdZone &lt;ZoneId&gt;<br></B></code>
      <br><br>
      Example:<br>
      <ul>
        <code>
        define RainbirdZone.01 RainbirdZone 1<br>
        <br>
        </code>
      </ul>
    </ul><br>
    <a name="RainbirdZoneset"></a><b>Set</b>
    <ul>
      <li><B>ClearReadings</B><a name="RainbirdZoneClearReadings"></a><br>
        Clears all readings.
      </li>
      <li><B>Irrigate [&lt;minutes&gt;]</B><a name="RainbirdZoneIrrigate"></a><br>
        Starts irrigating the zone for [minutes] or attribute <b>irrigationTime</b>
      </li>
      <li><B>Stop</B><a name="RainbirdZoneStop"></a><br>
        Stops irrigating the zone.
      </li>
    </ul><br>
    <a name="RainbirdZoneget"></a><b>Get</b>
    <ul>
      <li><B>Schedule</B><a name="RainbirdZoneSchedule"></a><br>
        Get the schedule of the zone.
      </li>
    </ul><br>
    <a name="RainbirdZoneattr"></a><b>Attributes</b>
    <ul>
      <li><a name="RainbirdZonedisable">disable</a><br>
        Disables the device.<br>
      </li>
      <li><a name="RainbirdZoneirrigationTime">irrigationTime</a><br>
        Default irrigation time in minutes (used by command <b>IrrigateZone</b> without parameter)<br>
      </li>
      <li><a name="RainbirdZoneexpert">expert</a><br>
        Switches to expert mode.<br>
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
