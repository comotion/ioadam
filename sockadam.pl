#!/usr/bin/perl

# Control the ADAM-6066 6-channel Digital Input and 6-ch Power Relay Module
# the ADAM communicates using an ASCII command set over port 1025/udp.

# 2009-05-13 Kacper Wysocki <kwy@redpill-linpro.com> Initial version for Elkjøp Nordic.

use strict;
use Socket;
use Getopt::Long qw/:config auto_version auto_help/;

my ($ip, $port) = ("10.121.20.30", 1025);

GetOptions(
    'ip=s'      => \$ip,
    'port=s'    => \$port,
    );

my $proto = getprotobyname('udp');
socket(SOCKET, PF_INET, SOCK_DGRAM, $proto) or die "socket: $!";
connect(SOCKET, $ip);
print SOCKET "\$016\r";
my $sep = $/;
$/ = "\r";
print "Hangs\n";
print readline SOCKET;

