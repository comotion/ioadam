use IO::Socket::INET;
$MySocket=new IO::Socket::INET->new(LocalPort=>1234,
        Proto=>'udp');
$MySocket->recv($text,128);
print "S:$text\n";
$MySocket->send("F00F".$text);

