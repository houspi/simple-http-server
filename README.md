# simple-http-server

nonBlockedserver.pl 3778 bytes <br>
2.jpg 546720 bytes <br>

simpleTCPserver.pl <br>
nonBlockedserver.pl 3778 bytes <br>
ab -n 1000 -c 1  Requests per second:    2166.67 [#/sec] (mean) <br>
ab -n 1000 -c 10 Requests per second:    1603.06 [#/sec] (mean) <br>
ab -n 1000 -c 20 Requests per second:    1616.71 [#/sec] (mean) <br>

2.jpg 546720 bytes <br>
ab -n 1000 -c 1  Requests per second:    789.61 [#/sec] (mean) <br>
ab -n 1000 -c 10 Requests per second:    709.53 [#/sec] (mean) <br>
ab -n 1000 -c 20 Requests per second:    1099.05 [#/sec] (mean) <br>

nonBlockedserver.pl <br>
nonBlockedserver.pl 3778 bytes <br>
ab -n 1000 -c 1  Requests per second:    1987.27 [#/sec] (mean) <br>
ab -n 1000 -c 10 Requests per second:    2194.66 [#/sec] (mean) <br>
ab -n 1000 -c 20 Requests per second:    1632.95 [#/sec] (mean) <br>

2.jpg 546720 bytes <br>
ab -n 1000 -c 1  Requests per second:    729.79 [#/sec] (mean) <br>
ab -n 1000 -c 10 Requests per second:    1299.11 [#/sec] (mean) <br>
ab -n 1000 -c 20 Requests per second:    1186.00 [#/sec] (mean) <br>

anyEventserver.pl <br>
nonBlockedserver.pl 3778 bytes <br>
ab -n 1000 -c 1  Requests per second:    1634.72 [#/sec] (mean) <br>
ab -n 1000 -c 10 Requests per second:    1843.55 [#/sec] (mean) <br>
ab -n 1000 -c 20 Requests per second:    2045.38 [#/sec] (mean) <br>

2.jpg 546720 bytes <br>
ab -n 1000 -c 1  Requests per second:    722.61 [#/sec] (mean) <br>
ab -n 1000 -c 10 Requests per second:    1178.18 [#/sec] (mean) <br>
ab -n 1000 -c 20 Requests per second:    1177.26 [#/sec] (mean) <br>
