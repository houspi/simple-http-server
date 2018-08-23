#!/usr/bin/perl -w

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
my $port = $DEFAULT_PORT;

my $server = IO::Socket::INET->new(
        LocalPort => $port, 
        Type => SOCK_STREAM, 
        Reuse => 1, 
        Listen => 5 )
    or die "Couldn't start server on port $port : $@\n"; 

while (my $client = $server->accept()) {
    print $client, " client connected\n";
    handle_client($client);
}
close($server);

sub handle_client {
    my $client = shift;
    print "start handle\n";
    my $line;
    my @request_headers = ();
    do {
        $client->recv($line, 1024, 0);
        print "LINE:$line\n";
        print "LEN:", length($line), "\n";
        push(@request_headers, $line)
    } while (length($line)>2);
    foreach (@request_headers) {
        my ($command, $param) = split(/ /, $_);
        if (exists($commands{$command})) {
            $commands{$command}->($client, $param);
        }
    }
    
}

sub command_get {
    my $client = shift;
    my $param = shift;
    
    print "command GET\n";
    print "PARAM:$param\n";
    my $status_code;
    if (open(FILE, $DIRECTORY_ROOT . $param)) {
        $status_code = "200";
        $client->send($status_code . " " . $status{$status_code} . "\n\n" );
        my $content = "";
        {
            local $/ = undef;
            $content = <FILE>;
        }
        $client->send($content);
        close(FILE);
    } else {
        $status_code = "404";
        $client->send($status_code . " " . $status{$status_code} . "\n\n" );
    }
}
