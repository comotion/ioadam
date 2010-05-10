#!/usr/bin/perl
# ADAM-6066 Power Relay Ethernet Controller Software
# 
# 2009-05-13 Kacper Wysocki <kwy@redpill-linpro.com> 
#  for Elkjøp Nordic.

=head1 NAME

adam6066.pl - Control the ADAM-6066 6-channel Digital Input and 6-ch Power Relay Module

=head1 VERSION

1.0 - 2009-05-14

=head1 SYNOPSIS

The 6066 has 6 Digital Inputs and 6 switchable relays we call Digital Outputs.

The ADAM communicates using an ASCII command set over port 1025/udp.

This program lets you get the state of all inputs and outputs, as well as
set, reset, toggle, force and time-delay with a simple command line.

 $ adam6066.pl [options] [verbs]

 OPTIONS:
 --ip               : ADAM's IP address  (default: 10.121.20.30)
 --port             : ADAM's UDP port    (default: 1025)
 --version          : Show script version.
 --help             : This message.
 --debug            : Enable debug messages
 --quiet            : Don't print header.

 VERBS:
   info             : Show module name, firmware, hex state, GCL flags.
   state [channels] : Show I/O state.
   get [channels]   : Show relay output channel state. 
   getin            : Show digital input state.
   force [channels] : Set (turn ON) only these, turn OFF other channels.
   set [channels]   : Set (turn ON) digital inputs, one by one.
   reset [channels] : Reset (turn OFF) digital inputs, one by one.
   toggle [channels]: Turn channel off if is on, turn on if is off.
   wait  [ms]       : Sleep and do nothing for x milliseconds.
   reconnect [ip port]:Re-initiate communications with ADAM.
   ip  [ip]         : set the IP for new connections.
   port [port]      : set port for new connections.
   ver(sion)        : print program version
   help             : This message.
   examples         : MORE HELP and EXAMPLES ($ perldoc adam6066.pl)

All verbs are case-insensitive.

=head1 NOTES

 # Channel 0-5 is output (power relay) channel,
 channel 6-11 is digital input.

 # get without arguments will print all input channels.

 # commands without arguments will do the obvious thing, eg
   set will TURN ON ALL OUTPUTS, 
   force and reset will TURN OFF ALL OUTPUTS,
   toggle will FLIP ALL OUTPUTS, and
   wait will sleep 1 second before proceeding.

 # The ADAM-6066 has a 7 ms relay switch on time 
    and a 3 ms switch off time,  
    and a maximum switching rate of 20 operations per minute.
    
    It is unknown whether the module spontaneously combusts 
    if you do more than 20 operations per minute. Bear this in mind.

=head1 EXAMPLES

 $ adam6066.pl get

DO0:0 DO1:1 DO2:0 DO3:1 DO4:0 DO5:1 

 $ adam6066.pl get 1 3 7 9

D1: 1 D3: 1 D7: 1 D9: 1 
 
 $ adam6066.pl getin

DI0:1 DI1:1 DI2:1 DI3:1 DI4:1 DI5:1 
 
 $ adam6066.pl get force get

DO0:0 DO1:0 DO2:0 DO3:1 DO4:1 DO5:0

DO0:0 DO1:0 DO2:0 DO3:0 DO4:0 DO5:0

 $ adam6066.pl get force get set 2 4 get

DO0:0 DO1:0 DO2:0 DO3:0 DO4:0 DO5:0

DO0:0 DO1:0 DO2:0 DO3:0 DO4:0 DO5:0

DO0:0 DO1:0 DO2:1 DO3:0 DO4:1 DO5:0

 $ adam6066.pl get force get set 2 4 wait 800 get toggle get

DO0:0 DO1:0 DO2:1 DO3:0 DO4:1 DO5:0 

DO0:0 DO1:0 DO2:0 DO3:0 DO4:0 DO5:0 

DO0:0 DO1:0 DO2:1 DO3:0 DO4:1 DO5:0 

DO0:1 DO1:1 DO2:0 DO3:1 DO4:0 DO5:1

 $ adam6066.pl get set get reset 3 wait 500 get toggle get

DO0:1 DO1:1 DO2:0 DO3:1 DO4:0 DO5:1 

DO0:1 DO1:1 DO2:1 DO3:1 DO4:1 DO5:1 

DO0:1 DO1:1 DO2:1 DO3:0 DO4:1 DO5:1 

DO0:0 DO1:0 DO2:0 DO3:1 DO4:0 DO5:0 

=cut

package Adam;
use strict;
#use warnings;
use IO::Socket;
use Getopt::Long qw/:config auto_version auto_help/;

my $debug = 0;

# switching time, milliseconds
my $RELAY_ON   = 7;
my $RELAY_OFF  = 3;
# max switch: 20 ops/min
my $RELAY_RATE = 20;
my $TIMEOUT = 4;
my $quiet = 0;

my ($ip, $port) = ("10.121.20.30", 1025);
local $SIG{ALRM} = sub { die "Socket timeout, could not connect to $ip:$port\n" }; 

GetOptions(
    'ip=s'      => \$ip,
    'port=s'    => \$port,
    'debug=s'   => \$debug,
    'quiet|q' => \$quiet,
    );

print "Connect $ip:$port/udp...\n" if $debug;

# sleep for n miliseconds.
sub msleep {
    my $ms = shift;
    $ms = 1000 if not $ms;
    my $sec = $ms / 1000;
    my $msec =$ms % 1000;
    my $time = sprintf("%d.%03d", $sec, $msec);
    select(undef,undef,undef,$time);
}

# set up connection
sub commup {
    my ($ip, $port) = @_;
    alarm $TIMEOUT;
    my $sock = IO::Socket::INET->new(
                                     PeerAddr => $ip,
                                     PeerPort => $port,
                                     Proto    => 'udp',
                                     timeout  => 4);
    die "Sock: $!" if not $sock;
    alarm 0;
    return $sock;
}

sub commdown {
    my $sock = shift;
    $sock->shutdown(2);
}


# send one or more messages
sub scom {
    my $sock = shift;
    for my $msg (@_){
        alarm $TIMEOUT;
        $sock->send($msg."\r") or die "send: $!";
        alarm 0;
        msleep($RELAY_OFF); # minimal sleep time!
    }
}

# receive a message
sub rcom {
    my ($sock, $bufsize) = @_;
    $bufsize ||= 128;
    my $msg;
    alarm $TIMEOUT;
    $sock->recv($msg, $bufsize) or die "receive: $!";
    alarm 0;
    #print "rcom $msg\n";
    return $msg;
}

my $sock = commup($ip, $port);

# query command
sub scmd {
    my $cmd = shift;
    scom($sock, "\$01$cmd");
    my $ret = rcom($sock);
    die "Unrecognized command $cmd" if(substr $ret,0,1 eq '?');
    return substr $ret,3;
}

# modify command
sub rcmd {
    my $cmd = shift;
    my $time = shift;
    scom($sock, "#01$cmd");
    msleep($time) if defined $time;
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

sub print_info {
    print "Module ADAM-". module ."\n";
    print "Firmware version:". firmware."\n";
    print "IO state: ". state ."\n";
    print "GCL flags: ". getgcl ."\n";
}

# @state = get();
# print $state[3]
#
# !aa00DDDD\r
# module hexes 4 bytes
# !0100       0            F           F        D
# number| 15 14 13 12 | 11 10  9  8 |  7  6  5  4 |  3  2   1 0
# output|  1  2  3  4    5  6  7  8    9  10 11 12  13  14 15 16
# !0100 |  0  0  0  0 |  1  1  1  1 |  1  1  1  1 |  1  1  0  1
# note! only bits 0-5 of a byte represent channels!
sub get {
    my $state = state;
    #my( $res, $rest) = unpack("b*", pack("h*", $state));
    my ($res, $rest) = unpack("b*", pack("H6", $state));
    my @chans = split //, $res;
    my ($i, @out);
    for(@chans){
        # we have 16 + 8 channels and 12 IO, so 4 spare bits.
        # and 8 bits we don't know what to do with.
        # filter out dead bits.
        if($i == 6 || $i == 7 || $i > 13){
            shift;
        }else{
            push @out,$_;
        }
        $i++;
    }
    return @out;
}
# Set (switch on) a list of Digital Output Channels
# #aabbDD
sub set{
    if(not @_){ force(0,1,2,3,4,5);};
    my @chans = @_;
    for(@chans){
        if(/(\d)=(\d)/){
            rcmd("1${1}0${2}", $RELAY_ON);
        }else{
            rcmd("1${_}01", $RELAY_ON);
        }
    }
}

# Reset (switch off) a list of Digital Output Channels
# faster than set ch=0
sub rset{
    my @chans = @_;
    for(@chans){
        if(/(\d)=(\d)/){
            rcmd("1${1}0${2}", $RELAY_ON);
        }else{
            rcmd("1${_}00", $RELAY_OFF);
        }
    }
}

# Force switch on only these channels; all others are off
sub force{
    my @chans = @_;
    my ($c,$t) = (0,0);
    for(@chans){
        $c |= (1 << $_);
        $t += $RELAY_ON;
    }
    my $cmd = sprintf("%02X", $c);
    rcmd("00$cmd", $t);
}

# toggle these channels, all others stay the same
# as fast as a get-then-force
sub toggle{
    my @chans = sort {$a <=> $b} @_;
    my @state = get;
    my @set;
    my $i = 0;
    if(not @chans){
        for(0..6){
            push @set, $_ if not $state[$_];
        }
    }else{
        for my $ch (@chans){
            if(not $state[$ch]){
                push @set,$ch;
            }
            if($ch > $i + 1){
                for($i..$ch-1){
                    if($state[$_]){
                        push @set,$_;
                    }
                }
            }
            $i = $ch;
        }
    }
    force(@set);
}


sub print_state{
    my @chanlist = (0,1,2,3,4,5,6,7,8,9,10,11);
    if(@_){ @chanlist = @_; }
#my @chanlist = qw{};

    my @chans = get;
    for(@chanlist){
        print "D$_: ". $chans[$_]." ";
    }print "\n";
}

sub print_di {
    my @chans = get;
    my $i = 0;
    for(6..11){
        print "DI$i:$chans[$_] ";
        $i++;
    }
    print "\n";
}

sub print_do {
    my @chans = get;
    my $i = 0;
    for(0..5){
        print "DO$i:$chans[$_] ";
        $i++;
    }
    print "\n";
}

# interpret commands
# Main verb parser.
sub zen_word {
    # could eval("$word(@args)") but it's a little unsafe to do EVERYTHING
    my ($word, @args) = @_;
    $_ = $word;
    /^(peek|get)(out)?$/i and 
        ((@args and print_state(@args)) or
         print_do) or
    /^getin$/i and print_di or
    /^(wait|sleep|pause|tea|z*)$/i and msleep($args[0]) or
    /^(enable|on|set|poke)$/i and set(@args) or
    /^(disable|off|reset)$/i and rset(@args) or
    /^toggle$/i and toggle(@args) or
    /^force$/i and force(@args) or
    /^state$/i and print_state(@args) or
    /^info$/i and print_info or
    /^reconnect$/i and commdown($sock) and ((@args and $sock = commup(@args)) or $sock = commup($ip, $port)) or
    /^ip/i and $ip = $args[0] or
    /^port/i and $port = $args[0] or
    /^help/i and Getopt::Long::HelpMessage() or
    /^ver(sion)?/i and Getopt::Long::VersionMessage() or
    /^examples/i and system"perldoc $0";
}
# get 1 2 3 wait 450 set 5 6 get 5 reset 5 2=1 get toggle force 1 3 5 get
sub meditate_verb {
    my $word = shift;
    my ($arg, @args);
    while(@_){
        $arg = shift;
        if($arg =~ /^\d+(=\d)?$/){
            push @args, $arg;
        }else{
            unshift @_,$arg;
            last;
        }
    }
    zen_word($word, @args);
    meditate_verb(@_) if @_;
}

if(@ARGV){
    meditate_verb(@ARGV);
}else{
    print "Ready to send commands to ADAM-6066.\n".
            "\t`$0 -help` for commands.\n\n" if not $quiet;
    while(<STDIN>){
        meditate_verb(split);
    }
}
=head1 API example

print_state;
set(qw{1 3=0 5});
force(qw{3 2 4 1});
rset(qw{2 4 7});
print_state;

for(1..20){

    toggle;
    msleep($RELAY_ON*10);
    print_do;

}

print state ."\n";
=cut

=head1 TODO

Timeouts on connect / socket operations so this program doesn't hang when 
it can't contact the module.

Rate limiter that doesn't allow more than 20 operations per minute.

Support for modules other than the 6066 - if you give me one of these to hold :-)

=head1 AUTHOR

Kacper Wysocki <kwy@redpill-linpro.com>

=head1 COPYRIGHT

This program was written by Kacper Wysocki for Elkjøp.
This program is open source - you can redistribute and modify it on the same terms as perl itself.

=cut
