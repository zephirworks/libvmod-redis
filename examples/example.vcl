#
# A trivial example to demonstrate how to use this vmod
#

import redis;

backend be1 {
  .host = "192.168.0.1";
  .port = "80";
}

#sub vcl_init {
  #
  # By default, the redis module will attempt to connect to a Redis server
  # at 127.0.0.1:6379 with a connect timeout of 200 milliseconds.
  #
  # The function redis.init_redis(host, port, timeout_ms) may be used to
  # connect to an alternate Redis server or use a different connect timeout.
  #
  # redis.init_redis("localhost", 6379, 200);  /* default values */
#}

sub vcl_recv {
  #
  # redis.send is a procedure, it will send the command to redis and ignore
  # the response. If the command errors out, it will be logged but the VCL
  # will not know.
  #
  redis.send("LPUSH client " + client.ip);

  #
  # redis.call is a function that sends the command to redis and return the
  # return value as a string.
  #
  set req.http.x-redis = redis.call("LTRIM client 0 99");
}
