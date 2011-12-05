#include <stdlib.h>
#include <stdio.h>

#include "vrt.h"
#include "bin/varnishd/cache.h"

#include "vcc_if.h"

#include <pthread.h>
#include <hiredis/hiredis.h>


#define	LOG_E(...) fprintf(stderr, __VA_ARGS__);
#ifdef DEBUG
#	define	LOG_T(...) fprintf(stderr, __VA_ARGS__);
#else
#	define	LOG_T(...) do {} while(0);
#endif

typedef struct redisConfig {
	char *host;
	int port;
} config_t;

static pthread_key_t redis_key;
static pthread_once_t redis_key_once = PTHREAD_ONCE_INIT;


static void __match_proto__()
vmod_log(struct sess *sp, const char *fmt, ...)
{
        char buf[8192], *p;
        va_list ap;

        va_start(ap, fmt);
        p = VRT_StringList(buf, sizeof buf, fmt, ap);
        va_end(ap);
        if (p != NULL)
                WSP(sp, SLT_VCL_Log, "%s", buf);
}

static void
make_key()
{
	(void)pthread_key_create(&redis_key, NULL);
}
 
int
init_function(struct vmod_priv *priv, const struct VCL_conf *conf)
{
	LOG_T("redis init called\n");

	(void)pthread_once(&redis_key_once, make_key);

	return (0);
}

static redisReply *
redis_common(struct sess *sp, struct vmod_priv *priv, const char *command)
{
	config_t *cfg;
	redisContext *c;
	redisReply *reply;

	LOG_T("redis(%x): running %s %p\n", pthread_self(), command, priv->priv);

	cfg = priv->priv;
	if (cfg == NULL) {
		priv->priv = cfg = malloc(sizeof(config_t));
		priv->free = free;
		cfg->host = strdup("127.0.0.1");
		cfg->port = 6379;
	}

	if ((c = pthread_getspecific(redis_key)) == NULL) {
		c = redisConnect(cfg->host, cfg->port);
		if (c->err) {
			LOG_E("redis error (connect): %s\n", c->errstr);
		}
		(void)pthread_setspecific(redis_key, c);
	}

	reply = redisCommand(c, command);
	if (c->err == REDIS_ERR_EOF) {
		c = redisConnect(cfg->host, cfg->port);
		if (c->err) {
			LOG_E("redis error (reconnect): %s\n", c->errstr);
			redisFree(c);
		} else {
			redisFree(pthread_getspecific(redis_key));
			(void)pthread_setspecific(redis_key, c);

			reply = redisCommand(c, command);
		}
	}
	if (reply == NULL) {
		LOG_E("redis error (command): err=%d errstr=%s\n", c->err, c->errstr);
		return NULL;
	}

	return reply;
}

void
vmod_send(struct sess *sp, struct vmod_priv *priv, const char *command)
{
	redisReply *reply = redis_common(sp, priv, command);
	if (reply != NULL) {
		freeReplyObject(reply);
	}
}

const char *
vmod_call(struct sess *sp, struct vmod_priv *priv, const char *command)
{
	redisReply *reply;
	const char *ret;

	reply = redis_common(sp, priv, command);
	if (reply == NULL) {
		return NULL;
	}

	switch (reply->type) {
	case REDIS_REPLY_STATUS:
		ret = strdup(reply->str);
		break;
	case REDIS_REPLY_ERROR:
		ret = strdup(reply->str);
		break;
	case REDIS_REPLY_INTEGER:
		ret = strdup("integer");	/* FIXME */
		break;
	case REDIS_REPLY_NIL:
		ret = NULL;
		break;
	case REDIS_REPLY_STRING:
		ret = strdup(reply->str);
		break;
	case REDIS_REPLY_ARRAY:
		ret = strdup("array");
		break;
	default:
		ret = strdup("unexpected");
	}

	freeReplyObject(reply);
	
	return ret;
}
