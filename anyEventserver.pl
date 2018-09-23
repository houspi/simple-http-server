#!/usr/bin/perl -w 
#
# Simple HTTP server with anyEvent
#
# houspi@gmail.com
#

use strict;
use POSIX;
use Getopt::Std;
use Socket;
use IO::Socket; 
use AnyEvent;
use AnyEvent::Socket qw/tcp_server/;
use AnyEvent::Handle;

use constant DEFAULT_PORT => 1080;

my $DIRECTORY_ROOT = "/home/edi/test/simple-http-server";

my %http_methods = (
        "GET"   => \&method_get,
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
$port = DEFAULT_PORT if (!$port);

if ($opts{'d'}) {
    #Turn off log if run as a daemon
    $log_level = 0;
    daemonize();
}

my $condvar = AnyEvent->condvar;

my %input_data = ();
my $clients_count = 0;
my $requests_total = 0;

# Concurrent requests 128 is hardcoded in the AnyEvent::Socket module
print_log(1, "Start new server on $port.\nMax of concurrent requests 128\n");
my $guard = tcp_server "0", $port,  
    sub {
        my ($fh, $host, $port) = @_;
        print_log(1, "new connect $host, $port\n");
        my $id = "$host:$port";
        $clients_count++;
        $requests_total++;
        $input_data{$id} = [];
        print_log(2, "Active clients count: $clients_count\nTotal processed requests: $requests_total\n");
        my $hdl = AnyEvent::Handle->new(
            fh => $fh,
            on_error => sub { 
                my ($hdl, $fatal, $msg) = @_;
                print_log(2, "error on connection $host, $port: $msg\n");
                shutdown($fh, 2);
                close($fh);
                delete $input_data{$id};
                $hdl->destroy;
                $clients_count--;
            }
        );
        my $reader;
        $reader = sub {
            if ($_[1]) {
                push($input_data{$id}, $_[1]);
            } else {
                # result is ignored for now
                process_client($fh, $host, $port);
                print_log(2, "close connection $host, $port\n");
                shutdown($fh, 2);
                close($fh);
                delete $input_data{$id};
                $hdl->destroy;
                $clients_count--;
            }
            $hdl->push_read( line => $reader );
        };
        $hdl->push_read( line => $reader );
    };

#main loop
$condvar->recv;


=item process_client
    client - client's socket
    host - client's ip address
    port - client's port
    
    return value
    0 if success
    non-zero if any error
=cut
sub process_client {
    my ($client, $host, $port) = @_;
    
    my $id = "$host:$port";
    print_log(2, "$client $id\n");
    
    my %request_headers = ();
    
    if ( exists($input_data{$id}) && scalar(@{$input_data{$id}}) ) {
        # $http_ver is ignored for now
        my ($method, $uri, $http_ver) = split(' ', @{$input_data{$id}}[0]);
        
        my $last_field;
        foreach ( @{$input_data{$id}}[1 .. scalar(@{$input_data{$id}})-1] ) {
            if ( ! /^\s+/ ) {
                my ($field_name, $field_value) = split(':', $_);
                if ($field_name && $field_value) {
                    $request_headers{$field_name} = $field_value;
                    $last_field = $field_name;
                } else {
                    print_log(2, "error bad header line: $_ from $host, $port\n");
                }
            } else {
                $request_headers{$last_field} .= "\n" . $_ if ($last_field);
            }
        }
        foreach (keys %request_headers) {
            print_log(2, "$_ => $request_headers{$_}\n");
        }
        if ( $method && exists($http_methods{$method}) ) {
            return $http_methods{$method}->($client, $uri);
        } else {
            print_log(2, "error unknown method $method from $host, $port\n");
            return 1;
        }
    } else {
        print_log(2, "error empty request from $host, $port\n");
        return 1;
    }
    return 0;
}

=item method_get
    client - client's socket
    uri - URI
    
    return value
    0 if success
    non-zero if any error
=cut
sub method_get {
    my $client = shift;
    my $uri = shift;

    my $content = "";
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
    my $http_response_header = "HTTP/1.0 " . $status_code . " " . $status{$status_code} . "\n";
    $http_response_header .= "Content-type: text/html\n";
    $http_response_header .= "Content-lenght: " . length($content) . "\n\n";
    my $result;
    $result = syswrite($client, $http_response_header);
    if ($result != length($http_response_header)) {
        print_log(2, "error when send response header to  $client\n");
        return 1;
    }
    $result = syswrite($client, $content);
    if ($result != length($content)) {
        print_log(2, "error when send response content to  $client\n");
        return 1;
    }
    return 0;
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
