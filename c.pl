use IO::Socket::INET;
$MySocket=new IO::Socket::INET->new(PeerPort=>1234,
        Proto=>'udp',
        PeerAddr=>'localhost');
$msg="DEADBEEFCAFE\r";
$MySocket->send($msg);
$MySocket->recv($msg,128);
print "C:$msg\n";

