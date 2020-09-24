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
sub RainbirdZone_GetZoneAvailable($);
sub RainbirdZone_GetZoneActive($);
sub RainbirdZone_GetZoneMask($);

### statics
my $VERSION = '1.0.1';

my $DefaultIrrigationTime = 10;

#####################################
# Initialize( $hash )
#####################################
sub RainbirdZone_Initialize($)
{
  my ($hash) = @_;

  # Provider

  # Consumer
  $hash->{SetFn}    = \&RainbirdZone_Set;
  $hash->{DefFn}    = \&RainbirdZone_Define;
  $hash->{UndefFn}  = \&RainbirdZone_Undef;
  $hash->{DeleteFn} = \&RainbirdZone_Delete;
  $hash->{ParseFn}  = \&RainbirdZone_Parse;
  $hash->{NotifyFn} = \&RainbirdZone_Notify;
  $hash->{AttrFn}   = \&RainbirdZone_Attr;
  
  $hash->{Match} = '"identifier":"Rainbird"'; # example {"response":"BF","pageNumber":0,"type":"CurrentStationsActiveResponse","identifier":"Rainbird","activeStations":0}

  $hash->{AttrList} = "" . 
    "IODev " . 
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
  CommandAttr( undef, $name . ' webCmd IrrigateZone:StopIrrigation' )
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
  RainbirdZone_GetZoneAvailable($hash);
  RainbirdZone_GetZoneActive($hash);

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

  ### IrrigateZone
  if ( lc $cmd eq 'irrigatezone' )
  {
    return "usage: $cmd [opt: <minutes>]"
      if ( @args > 1 );

  	### default value from internals
    my $minutes = $hash->{IRRIGATIONTIME};
    
    ### if there is a parameter
    $minutes = $args[0]
      if ( @args == 1 );

    # send command via RainbirdController
    IOWrite( $hash, $cmd, $zoneId, $minutes );
  } 

  ### StopIrrigation
  elsif ( lc $cmd eq 'stopirrigation' )
  {
    return "usage: $cmd"
      if ( @args != 0 );

    # send command via RainbirdController
    IOWrite( $hash, $cmd );
  } 
  
  ### ClearReadings
  elsif ( lc $cmd eq 'clearreadings' )
  {
    my @cH = ($hash);
    push @cH,$defs{$hash->{$_}} foreach(grep /^channel/,keys %{$hash});
    delete $_->{READINGS} foreach (@cH);
  } 

  ### else
  else
  {
    my $list = "";

    $list .= " StopIrrigation:noArg" if ($hash->{AVAILABLE} == 1);
    $list .= " IrrigateZone" if ($hash->{AVAILABLE} == 1);
    $list .= " ClearReadings:noArg";

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
  if(defined($modules{RainbirdZone}{defptr}))
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
  	RainbirdZone_GetZoneActive($hash);
  }

  ### AvailableStationsResponse
  elsif(lc $type eq lc "AvailableStationsResponse")
  {
  	### "{"identifier":"Rainbird","pageNumber":0,"setStations":4278190080,"type":"AvailableStationsResponse","response":"83"}"

    ### just trigger function -> values are fetched from internals of attached RainbirdController
    RainbirdZone_GetZoneAvailable($hash);
  }

  else
  {
    Log3 $name, 4, "RainbirdZone ($name) - ProcessMessage response not handled";
  }
}

#####################################
# GetZoneActive( $hash )
#####################################
sub RainbirdZone_GetZoneActive($)
{
  my ( $hash ) = @_;
  my $name = $hash->{NAME};

  Log3 $name, 5, "RainbirdZone ($name) - GetZoneActive was called";

  my $activeZoneMask = $hash->{IODev}->{"ZONEACTIVEMASK"};
  my $mask = $hash->{ZONEMASK};
  my $result = $mask & $activeZoneMask;
  
  readingsBeginUpdate($hash);
  
  if($result)
  {
    readingsBulkUpdate( $hash, 'irrigating', 1, 1 );
    readingsBulkUpdate( $hash, 'state', 'irrigating', 1 );
  }
  else
  {
    readingsBulkUpdate( $hash, 'irrigating', 0, 1 );
    
    if($hash->{AVAILABLE} == 1)
    {
      readingsBulkUpdate( $hash, 'state', 'ready', 1 );
    }
  }
  readingsEndUpdate( $hash, 1 );
  
  return $result;
}

#####################################
# GetZoneAvailable( $hash )
#####################################
sub RainbirdZone_GetZoneAvailable($)
{
  my ( $hash ) = @_;
  my $name = $hash->{NAME};

  Log3 $name, 5, "RainbirdZone ($name) - GetZoneAvailable was called";

  my $availableZoneMask = $hash->{IODev}->{"ZONESAVAILABLEMASK"}; 
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
=item summary    Modul representing an irrigation zone of a Rainbird Controller

=begin html

<a name="RainbirdZone"></a>
<h3>RainbirdZone</h3>
<br>
In combination with RainbirdController this FHEM module represents an irrigation zone of the <b>Rain Bird Irrigation System</b>.<br>
<br>
Once the RainbirdController device is created and connected and autocreate is enabled all available irrigation zones are automatically recognized and created in FHEM.<br>
<br>
<ul>
  <a name="RainbirdControllerdefine"></a>
  <b>Define</b>
  <br><br>
  <code>define &lt;name&gt; RainbirdZone &lt;ZoneId&gt;</code>
  <br><br>
  Example:
  <ul>
    <br>
    <code>define RainbirdZone.01 RainbirdZone 1</code>
    <br>
  </ul>
  <br><br>
  <a name="RainbirdZonereadings"></a>
  <b>Readings</b>
  <br><br>
  <ul>
    <li>available - 1 when available else 0</li>
    <li>irrigating - 1 when irrigating else 0</li>
  </ul>
  <br><br>
  <a name="RainbirdZoneattributes"></a>
  <b>Attributes</b>
  <br><br>
  <ul>
    <li>irrigationTime - default irrigation time in minutes (used by command <b>IrrigateZone</b> without parameter)</li>
    <li>disable - disables the device</li>
  </ul>
  <br><br>
  <a name="RainbirdZoneset"></a>
  <b>set</b>
  <br><br>
  <ul>
    <li>ClearReadings - clears all readings</li>
    <li>IrrigateZone [&lt;minutes&gt;] - starts irrigating the zone for [minutes] or attribute <b>irrigationTime</b/li>
    <li>StopIrrigation - stops irrigating the zone</li>
  </ul>
</ul>

=end html
=cut
