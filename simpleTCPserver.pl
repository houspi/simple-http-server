#!/usr/bin/perl -w
#
# simple TCP Server
#
# houspi@gmail.com


use strict;
use POSIX;
use IO::Socket; 
use Getopt::Std;

my $DEFAULT_PORT = "1080";
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
getopts('hdl:p:', \%opts);

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
$port = $DEFAULT_PORT if (!$port);

if ($opts{'d'}) {
    #Turn off log if run as a daemon
    $log_level = 0;
    daemonize();
}

# Create socket
my $server = IO::Socket::INET->new(
        LocalPort => $port, 
        Type => SOCK_STREAM, 
        Reuse => 1, 
        Listen => 5 )
    or die "Couldn't start server on port $port : $@\n"; 
print_log(1, "Start listening on $port\n");

# main loop
# accept connection
while (my $client = $server->accept()) {
    print_log(2, $client, "client connected\n");
    # processing of client
    process_client($client);
    $client->close();
}
close($server);


=head1 process_client

=cut
sub process_client {
    my $client = shift;

    my $data;
    my @input_data = ();
    # We take only 2048 bytes of input
    $client->recv($data, 2048, 0);
    foreach ( split(/\r\n/, $data) ) {
        push @input_data, $_;
    }
    foreach ( @input_data ) {
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
    my $uri = shift;

    my $content;
    $uri =~ s/\.\.//g;
    my $status_code;
    my $file;
    my $file_name = $DIRECTORY_ROOT . $uri;
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
    $client->send("HTTP/1.0 " . $status_code . " " . $status{$status_code} . "\n" );
    $client->send("Content-type: text/html\n");
    $client->send("Content-lenght: " . length($content) . "\n");
    $client->send("\n");
    $client->send($content);
}

=item print_log
print input params to STDERR
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
Usage $0 [-h] | [-d] [-l LogLevel] [-p Port]
  -h  display this help and exit
  -d  run as a daemon
  -l  set log level of the messages. 1 by default. 0 to turn off.
  -p  listen on Port

EOF
}

