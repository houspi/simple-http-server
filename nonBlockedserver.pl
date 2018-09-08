#!/usr/bin/perl -w
#
# non Blocked TCP Server
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
use constant DEFAULT_QUEUE_SIZE => 16;
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
getopts('hdl:p:q:', \%opts);

if ($opts{'h'}) {
    Usage();
    exit(0);
}

my $log_level;
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

my $queue_size;
if ($opts{'q'}) {
    $queue_size = $opts{'q'};
    $queue_size =~ s/\D//g;
}
$queue_size = DEFAULT_QUEUE_SIZE if (!$queue_size);

if ($opts{'d'}) {
    #Turn off log if run as a daemon
    $log_level = 0;
    daemonize();
}

# Create server socket
print_log(1, "Start new server on $port. QUEUE size $queue_size\n");
my $server = IO::Socket::INET->new(
        LocalPort => $port, 
        Type => SOCK_STREAM, 
        ReuseAddr => 1,
        ReusePort => 1,
        Listen => $queue_size,
        Blocking => 0,
    )
    or die "Couldn't start server on port $port : $@\n"; 
my $select = IO::Select->new($server);

my %input_data = ();
my $clients_count = 0;
#main loop
while(1) {
    foreach my $socket ($select->can_read())  {
        if($socket == $server) {
            # new client
            my $client = $server->accept();
            fcntl($client, F_SETFL, fcntl($client, F_GETFL, 0) | O_NONBLOCK);
            $select->add($client);
            $clients_count++;
            print_log(1, "New Client. Handle: $client\n");
            print_log(2, "Clients count: $clients_count\n");
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
                print_log(2, "Clients count: $clients_count\n");
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
                $socket->shutdown(2);
                $clients_count--;
                print_log(2, "Clients count: $clients_count\n");
            }
        }
    }
}
close($server);


=item process_client

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
Usage $0 [-h] | [-d] [-l LogLevel] [-p Port] [ -q NUM ] 
  -h  display this help and exit
  -d  run as a daemon
  -l  set log level of the messages. 1 by default. 0 to turn off.
  -p  listen on Port
  -q  maximum length of the queue size of pending connections

EOF
}
