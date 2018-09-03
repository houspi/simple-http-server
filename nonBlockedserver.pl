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
use constant MAX_CLIENTS => 10;


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
# Set O_NONBLOCK flag
my $port = $DEFAULT_PORT;
my $server = IO::Socket::INET->new(
        LocalPort => $port, 
        Type => SOCK_STREAM, 
        Reuse => 1, 
        Listen => MAX_CLIENTS )
    or die "Couldn't start server on port $port : $@\n"; 
fcntl($server, F_SETFL, fcntl($server, F_GETFL, 0) | O_NONBLOCK);
print "Start listening on $port\n";

# Create Select object. Init it with the server socket.
my $select = IO::Select->new($server);

my %input_data = ();
#main loop
while(1) {
    # read data from client
    foreach my $socket ($select->can_read())  {
        if($socket == $server) {
            # new client
            # Set O_NONBLOCK flag
            # add to Select object
            my $client = $server->accept();
            print "Client handle $client\n";
            fcntl($client, F_SETFL, fcntl($client, F_GETFL, 0) | O_NONBLOCK);
            $select->add($client);
        } else {
            # read data from client
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
                $input_data{$socket} .= $data;
            }
        }
    }
    foreach my $socket ($select->can_write())  {
        unless($socket == $server) {
            if ( exists($input_data{$socket}) && $input_data{$socket} =~ /\n\n/) {
                process_client($socket, $input_data{$socket});
                $select->remove($socket);
                delete $input_data{$socket};
                $socket->shutdown(2);
                #shutdown($socket, 2);
            }
        }
    }
}
close($server);


=head1 process_client

=cut
sub process_client {
    my $client = shift;
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


=head1 command_get

=cut
sub command_get {
    my $client = shift;
    my $param = shift;

    my $content = "";
    $param =~ s/\.\.//g;
    my $status_code;
    my $file;
    my $file_name = $DIRECTORY_ROOT . $param;
    if ( -f $file_name && open($file, $file_name)) {
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
    syswrite($client, "HTTP/1.0 " . $status_code . " " . $status{$status_code} . "\n" );
    syswrite($client, "Content-type: text/html\n");
    syswrite($client, "Content-lenght: " . length($content) . "\n\n");
    syswrite($client, $content);

}
