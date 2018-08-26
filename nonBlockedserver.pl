#!/usr/bin/perl -w
#
# nonblocked TCP Server
#
# houspi@gmail.com

use strict;
use POSIX;
use Socket;
use Fcntl;
use IO::Socket; 
use IO::Select;
use Tie::RefHash;

use constant BUF_SIZE => 1024;


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

# Create socket
# Set O_NONBLOCK flag
my $server = IO::Socket::INET->new(
        LocalPort => $port, 
        Type => SOCK_STREAM, 
        Reuse => 1, 
        Listen => 5 )
    or die "Couldn't start server on port $port : $@\n"; 
fcntl($server, F_SETFL, fcntl($server, F_GETFL, 0) | O_NONBLOCK);
print "Start listening on $port\n";
# Create Select object. Init it with the server socket.
my $select = IO::Select->new($server);

my %input_data = ();
tie %input_data, 'Tie::RefHash';
#main loop
while(1) {
    # read data from client
    foreach my $socket ($select->can_read())  {
        if($socket == $server) {
            print "New connect\n";
            # new client
            # Set O_NONBLOCK flag
            # add to Select object
            my $client = $server->accept();
            print "Client handle $client\n";
            fcntl($client, F_SETFL, fcntl($client, F_GETFL, 0) | O_NONBLOCK);
            $select->add($client);
        } else {
            # read data from client
            print "read dada from $socket\n";
            my $data = "";
            #my $rv = $socket->recv($data, BUF_SIZE);
            if ( ! $socket->recv($data, BUF_SIZE) && !length($data)) {
                # error on reading
                # or client close the socket
                $select->remove($socket);
                delete $input_data{$socket};
                $socket->close();
            } else {
                $data =~ s/\r\n/\n/g;
                print "SIZE:" . length($data) . "\n";
                $input_data{$socket} .= $data;
            }
        }
    }

    # process readed data
    foreach my $socket (keys (%input_data)) {
      if ( $input_data{$socket} =~ /\n\n/) {
        print "Get empty line from $socket\n";
        handle_client($socket, $input_data{$socket});
        $select->remove($socket);
        delete $input_data{$socket};
        $socket->close();
      }
    }
}
close($server);

sub handle_client {
    my $client = shift;
    print "start handle\n";
    my $data = shift;

    my @request_headers = ();
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

sub command_get {
    my $client = shift;
    my $param = shift;
    my $content = "";
    
    print "command GET\n";
    print "PARAM:$param\n";
    $param =~ s/\.\.//g;
    my $status_code;
    if (open(FILE, $DIRECTORY_ROOT . $param)) {
        $status_code = "200";
        {
            local $/ = undef;
            $content = <FILE>;
        }
        close(FILE);
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
