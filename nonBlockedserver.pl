#!/usr/bin/perl -w
#
# simple non Blocked HTTP Server
#
# houspi@gmail.com
#

use strict;
use POSIX;
use Getopt::Std;
use Socket;
use IO::Socket; 
use IO::Select;
use Fcntl;

use constant BUF_SIZE => 1024;
use constant MAX_CLIENTS => 16;
use constant DEFAULT_PORT => 1080;

my $DIRECTORY_ROOT = "/home/edi/test/simple-http-server";

my %commands = (
        "GET"   => \&command_get,
    );

my %status = (
        "200"   => "OK",
        "404"   => "NOT FOUND",
    );

# Parsing command line options
my %opts;
getopts('hdl:p:c:', \%opts);

if ($opts{'h'}) {
    Usage();
    exit(0);
}

my $log_level = 0;
if ( exists($opts{'l'}) ) {
    $log_level = $opts{'l'};
    $log_level =~ s/\D//g;
}
$log_level = 1 if ($log_level !~ /\d/);

my $port;
if ($opts{'p'}) {
    $port = $opts{'p'};
    $port =~ s/\D//g;
}
$port = DEFAULT_PORT if (!$port);

my $max_clients;
if ($opts{'c'}) {
    $max_clients = $opts{'c'};
    $max_clients =~ s/\D//g;
}
$max_clients = MAX_CLIENTS if (!$max_clients);

if ($opts{'d'}) {
    #Turn off log if run as a daemon
    $log_level = 0;
    daemonize();
}

# Create server socket
print_log(1, "Start new server on $port.\nMax of concurrent requests $max_clients\n");
my $server = IO::Socket::INET->new(
        LocalPort => $port, 
        Type => SOCK_STREAM, 
        ReuseAddr => 1,
        ReusePort => 1,
        Listen => $max_clients,
        Blocking => 0,
    )
    or die "Couldn't start server on port $port : $@\n"; 
my $select = IO::Select->new($server);

my %input_data = ();
my $clients_count = 0;
my $requests_total = 0;

#main loop
while(1) {
    foreach my $socket ($select->can_read())  {
        if($socket == $server) {
            # new client
            my $client = $server->accept();
            fcntl($client, F_SETFL, fcntl($client, F_GETFL, 0) | O_NONBLOCK);
            $select->add($client);
            $clients_count++;
            $requests_total++;
            print_log(1, "New Client. Handle: $client\n");
            print_log(2, "Active clients count: $clients_count\nTotal processed requests: $requests_total\n");
        } else {
            # read data from client
            my $data = "";
            if ( ! $socket->recv($data, BUF_SIZE) && !length($data)) {
                # error on reading
                # or client close the socket
                print_log(2, "Error on socket: $socket\n");
                $select->remove($socket);
                delete $input_data{$socket};
                $socket->close();
                $clients_count--;
            } else {
                $input_data{$socket} .= $data;
            }
        }
    }
    
    foreach my $socket ($select->can_write())  {
        unless($socket == $server) {
            if ( exists($input_data{$socket}) && $input_data{$socket} =~ /\r\n\r\n/) {
                process_client($socket, $input_data{$socket});
                $select->remove($socket);
                delete $input_data{$socket};
                print_log(2, "Close socket: $socket\n");
                $socket->close();
                $clients_count--;
            }
        }
    }
}
close($server);


=item process_client
    client - client's socket
    data - client's data
=cut
sub process_client {
    my $client = shift;
    my $data = shift;

    my @request_headers = ();
    foreach ( split(/\r\n/, $data) ) {
        push @request_headers, $_;
    }
    foreach ( @request_headers ) {
        my ($command, $param) = split(/ /, $_);
        if (exists($commands{$command})) {
            print_log(2, "Client: $client Command: $command\n");
            $commands{$command}->($client, $param);
        }
    }
}


=item command_get
    client - client's socket
    param - URI
=cut
sub command_get {
    my $client = shift;
    my $param = shift;

    $param =~ s/\.\.//g;
    my $file_name = $DIRECTORY_ROOT . $param;

    my ($content, $status_code, $file);

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

=item print_log
print log info
=cut
sub print_log {
    my $level = shift;
    print STDERR join(" ", @_) if ($level <= $log_level);
}

=item daemonize
run program as a daemon
=cut
sub daemonize {
   setsid() or die "Can't call setsid: $!";
   my $pid = fork() // die "Can't call fork: $!";
   exit(0) if $pid;

   open (STDIN, "</dev/null");
   open (STDOUT, ">/dev/null");
   open (STDERR, ">&STDOUT");
 }
 
=item Usage
print help screen
=cut
sub Usage {
    print <<EOF
Usage $0 [-h] | [-d] [-l LogLevel] [-p Port] [ -m NUM ] 
  -h  display this help and exit
  -d  run as a daemon
  -l  set log level of the messages. 1 by default. 0 to turn off.
  -p  listen on Port
  -c  max of concurrent requests 

EOF
}
