#!/usr/bin/perl -w 

use strict;

use POSIX;
use Socket;
use IO::Socket; 
use AnyEvent;
use AnyEvent::Socket qw/tcp_server/;
use AnyEvent::Handle;

use constant BUF_SIZE => 8;
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

my $handled = 0;
$|++;

# Create socket
# Set O_NONBLOCK flag
my $port = $DEFAULT_PORT;
#my $server = IO::Socket::INET->new(
#        LocalPort => $port, 
#        Type => SOCK_STREAM, 
#        Reuse => 1, 
#        Listen => MAX_CLIENTS )
#    or die "Couldn't start server on port $port : $@\n"; 
#fcntl($server, F_SETFL, fcntl($server, F_GETFL, 0) | O_NONBLOCK);

#my $condvar = AnyEvent->condvar;
my $w; 
my $t; 

my %conns;
my %input_data = ();

my $guard = tcp_server "0", $port,  
    sub {
        my ($fh, $host, $port) = @_;
        syswrite $fh, "; you have " . scalar(keys %conns) . " buddies\015\012";
        my $hdl = AnyEvent::Handle->new(
            fh => $fh,
            on_error => sub { 
                my ($hdl, $fatal, $msg) = @_;
                my $id = "$host:$port";
                shutdown($fh, 2);
                delete $conns{$id};
                $hdl->destroy;
            }
        );
        my $id = "$host:$port";
        $conns{$id} = $fh;
        my $reader; $reader = sub {
            my $data = $_[1];
            $input_data{$id} .= $_[1] . "\n";
            if ( $input_data{$id} =~ /\n\n/ ) {
                process_client($fh, $host, $port);
                shutdown($fh, 2);
                delete $conns{$id};
                $hdl->destroy;
            }
            $hdl->push_read( line => $reader );
        };
        $hdl->push_read( line => $reader );
    };


print "Call recv\n";
AnyEvent->condvar->recv;


=head1 process_client

=cut
sub process_client {
    my ($client, $host, $port) = @_;
    
    my $id = "$host:$port";
    print "$client $id\n";
    
    if ( exists($input_data{$id}) ) {
        my @request_headers = ();
        foreach ( split(/\n/, $input_data{$id}) ) {
            push @request_headers, $_;
        }
        foreach ( @request_headers ) {
            my ($command, $param) = split(/ /, $_);
            if (exists($commands{$command})) {
                $commands{$command}->($client, $param);
            }
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
    syswrite($client, "HTTP/1.0 " . $status_code . " " . $status{$status_code} . "\n" );
    syswrite($client, "Content-type: text/html\n");
    syswrite($client, "Content-lenght: " . length($content) . "\n\n");
    syswrite($client, $content);
}
