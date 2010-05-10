#!/usr/bin/perl

# Control the ADAM-6066 6-channel Digital Input and 6-ch Power Relay Module
# the ADAM communicates using an ASCII command set over port 1025/udp.

# 2009-05-13 Kacper Wysocki <kwy@redpill-linpro.com> Initial version for Elkjøp Nordic.

use strict;
use IO::Socket;
use Getopt::Long qw/:config auto_version auto_help/;

my $debug = 0;
my ($ip, $port) = ("10.121.20.30", 1025);

GetOptions(
    'ip=s'      => \$ip,
    'port=s'    => \$port,
    );

print "Connect $ip:$port/udp...\n" if $debug;

# set up connection
sub commup {
    my ($ip, $port) = @_;
    my $sock = IO::Socket::INET->new(
                                     PeerAddr => $ip,
                                     PeerPort => $port,
                                     Proto    => 'udp');
    die "Sock: $!" if not $sock;
    return $sock;
}

# send one or more messages
sub scom {
    my $sock = shift;
    for my $msg (@_){
        $sock->send($msg."\r") or die "send: $!";
    }
}

# receive a message
sub rcom {
    my ($sock, $bufsize) = @_;
    $bufsize ||= 128;
    my $msg;
    $sock->recv($msg, $bufsize) or die "receive: $!";
    return $msg;
}

my $sock = commup($ip, $port);

sub scmd {
    my $cmd = shift;
    scom($sock, "\$01$cmd");
    return substr rcom($sock), 3;
}
sub rcmd {
    my $cmd = shift;
    scom($sock, "#01$cmd");
    return substr rcom($sock), 3;
}

sub module {
    scmd('M');
}

sub firmware {
    scmd('F');
}

# there's also a set gcl command that is omitted for safety..
# cause you don't know what you're doing, do you?
sub getgcl {
    scmd('Vd');
}

sub state {
    scmd('6');
}

sub info {
    print "Module ADAM-". module ."\n";
    print "Firmware version:". firmware."\n";
    print "IO state: ". state ."\n";
    print "GCL flags: ". getgcl ."\n";
}

# @state = get(qw{1 3 5});
# print $state[3]
# $state = get(qw{4 11 13});
# print $state->{4}
#
# !aa00DDDD\r
# module hexes 4 bytes
# !0100       0            F           F        D
# number| 15 14 13 12 | 11 10  9  8 |  7  6  5  4 |  3  2   1 0
# output|  1  2  3  4    5  6  7  8    9  10 11 12  13  14 15 16
# !0100 |  0  0  0  0 |  1  1  1  1 |  1  1  1  1 |  1  1  0  1
# note! only bits 0-5 of a byte represent channels!
sub get {
    my @peek = @_;
    my $state = state;
    #my( $res, $rest) = unpack("b*", pack("h*", $state));
    my ($res, $rest) = unpack("b*", pack("H6", $state));
    my @chans = split //, $res;

    if(wantarray){
        # array output
        my @output;
        if(@peek){
            for(@peek){
                push @output, $chans[$_];
            }
        }else{
            @output = @chans;
        }
        return @output;
    }else{
        # hash output $out->{channel} = value;
        my $output = {};
        if(@peek){
            for(@peek){
                $output->{$_} = $chans[$_];
            }
        }else{
            my $eye = 0;
            for(@chans){
                $output->{$eye++} = $_;
            }
        }
        return $output;
    }
}

#print channels. "\n";
my @chanlist = qw{1 2 3 5};
   @chanlist = qw{ 0 1 2 3 4 5 8 9 10 11 12 13 };
#my @chanlist = qw{};

my @chans = get(@chanlist);
for my $chan (@chanlist){
    my $out = shift @chans;

    print "D$chan: $out\n";
}
my $chans = get(@chanlist);
for(sort keys %$chans){
    print;
    print " ";
}

print state ."\n";
