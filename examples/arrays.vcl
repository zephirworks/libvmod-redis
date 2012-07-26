#
# A trivial example to demonstrate how to use this vmod
#

import redis;

backend be1 {
  .host = "192.168.0.1";
  .port = "80";
}

backend be2 {
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
  # redis.call is a function that sends the command to redis and return the
  # return value as a string. 
  #
  # As an example I have a hash on redis that permits me control a domain's redirect:
  #   
  # redis-cli> add vrnsh mydomain.com
  # redis-cli> hmset vrnsh:mydomain.com 'type' 'r' 'to' 'anotherdomain.com' 'code' '301'
  #
  # And I have another domain appointment to a backend server:
  #
  # redis-cli> sadd vrnsh mydomaintwo.com
  # redis-cli> hmset vrnsh:mydomaintwo.com 'type' 'd' 'backend' 'be2' 
  #
  # So, now I can read the request and check on redis if it's exists. 
  # If the response is true, the string returned would be something
  # like this:
  #
  # REDIRECT
  #
  # r:anotherdomain.com:301
  #
  # DOMAIN
  #
  # d:be2
  #
  # The keys set on the array will be disconsidered and the values
  # will be concatenated using ":" as wildcard to make the correct separation.
  #
  set req.http.redis_key = redis.call("HGETALL vrnsh:" + req.http.host);

  if( req.http.redis_key ) {
	# Read type param
	set req.http.htype = regsub(req.http.redis_key, "^(r|d):(.*)", "\1");

	# Read the domain backend from redis
   if( req.http.htype == "d" ) {
		# This regex is the number of parameters that you have returned.
		# If you have more or less parameters, please adapt this.
		# Don't forget to respect the correct parameters' sequences.
		set req.http.hbackend = regsub(req.http.redis_key, "(.*):(.*)", "\2");

		if( req.http.hbackend == "be1" ) {
			set req.backend = be11;
		} else if( req.http.hbackend == "be2" ) {
			set req.backend = be2;
		}
	}

	# Read and set a redirect from redis
	if( req.http.htype == "r" ) {
		set req.http.Location = regsub(req.http.redis_key,"(.*):(.*):(.*)", "\2");
		set req.http.herror = regsub(req.http.redis_key,"(.*):(.*):(.*)", "\3");

		if( req.http.herror == "302" ) {
			error 302 req.http.Location;
		} else if( req.http.herror == "301" ) {
			error 301 req.http.Location;
		} else {
			error 705 req.http.Location;
		}
	}
  # If not found, raise the correct error
  } else {
	error 404
  }
}
