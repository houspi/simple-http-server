# simple-http-server

simpleTCPserver.pl <br>
$ ab -c 20 -n 100 http://127.0.0.1:1080/nonBlockedserver.pl <br>
Requests per second:    229.47 [#/sec] (mean) <br>
Time per request:       87.157 [ms] (mean) <br>
Time per request:       4.358 [ms] (mean, across all concurrent requests) <br>
Transfer rate:          797.10 [Kbytes/sec] received <br>


nonBlockedserver.pl <br>
$ ab -c 20 -n 100 http://127.0.0.1:1080/nonBlockedserver.pl <br>
Requests per second:    427.08 [#/sec] (mean) <br>
Time per request:       46.829 [ms] (mean) <br>
Time per request:       2.341 [ms] (mean, across all concurrent requests) <br>
Transfer rate:          1483.53 [Kbytes/sec] received <br>


anyEventserver.pl
