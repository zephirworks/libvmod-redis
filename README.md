vmod-redis
==========

A Varnish module that allows sending commands to redis from the VCL.

At this stage it is mostly a proof-of-concept; it has only received minimal
testing and we have never used it in production. At the very minimum, it will
slow down Varnish a fair amount (at least a few milliseconds per request,
depending on how fast your network and your redis server are).

So far the module builds and runs on FreeBSD--on other platforms, you are on your own (pull requests welcome).


Functions and procedures
------------------------

*redis.init_redis(host, port, timeout_ms)*

Use the redis server at the given _host_ and _port_ with a timeout
of _timeout__ms_ milliseconds.
If _port_ is less than or equal to zero, the default port of 6379 is used.
If _timeout__ms_ is less than or equal to zero, a default timeout of 200ms is used.

This function is supposed to be called from the Varnish subroutine _vcl__init_.
If the call is left out, the module will attempt to connect to the Redis server
at 127.0.0.1:6379 with a connect timeout of 200ms.

*redis.send(command)*

Sends the given _command_ to redis; the response will be ignored.

*redis.call(command)*

Sends the given _command_ to redis; any response will be returned as a string.

Dependencies
------------

* hiredis (https://github.com/antirez/hiredis)

Building
--------

* ./autogen.sh
* make
* sudo make install

Configuration
-------------

See the _examples_ folder.
