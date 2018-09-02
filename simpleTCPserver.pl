#!/usr/bin/perl -w
#
# simple TCP Server
#
# houspi@gmail.com


use strict;
use IO::Socket; 

my $DEFAULT_PORT = "1080";
my $DIRECTORY_ROOT = "/home/edi/test/simple-http-server";

my %commands = (
        "GET"   => \&command_get,
    );

my %status = (
        "200"   => "OK",
        "404"   => "NOT FOUND",
    );

# Create socket
my $port = $DEFAULT_PORT;
my $server = IO::Socket::INET->new(
        LocalPort => $port, 
        Type => SOCK_STREAM, 
        Reuse => 1, 
        Listen => 5 )
    or die "Couldn't start server on port $port : $@\n"; 
print "Start listening on $port\n";

# main loop
# accept connection
while (my $client = $server->accept()) {
    print $client, " client connected\n";
    # processing of client
    process_client($client);
    $client->close();
}
close($server);


=head1 process_client

=cut
sub process_client {
    my $client = shift;

    print "start processing\n";
    my $data;
    my @request_headers = ();
    $client->recv($data, 2048, 0);
    $data =~ s/\r\n/\n/g;
    foreach ( split(/\n/, $data) ) {
        push @request_headers, $_;
    }
    foreach ( @request_headers ) {
        my ($command, $param) = split(/ /, $_);
        if (exists($commands{$command})) {
            $commands{$command}->($client, $param);
        }
    }
}


=head1 command_get

=cut
sub command_get {
    my $client = shift;
    my $param = shift;

    print "command GET\n";
    print "PARAM:$param\n";
    my $content = "";
    $param =~ s/\.\.//g;
    my $status_code;
    my $file;
    if (open($file, $DIRECTORY_ROOT . $param)) {
        $status_code = "200";
        {
            local $/ = undef;
            $content = <$file>;
        }
        close($file);
    } else {
        $status_code = "404";
        $content = "";
    }
    $client->send("HTTP/1.0 " . $status_code . " " . $status{$status_code} . "\n" );
    $client->send("Content-type: text/html\n");
    $client->send("Content-lenght: " . length($content) . "\n");
    $client->send("\n");
    $client->send($content);
}
