#!/bin/bash
# From https://github.com/benhutchins/docker-taiga/

# Sleep when asked to, to allow the database time to start
# before Taiga tries to run checkdb.py below.
: ${TAIGA_SLEEP:=0}
sleep $TAIGA_SLEEP

# Setup database automatically if needed
if [ -z "$TAIGA_SKIP_DB_CHECK" ]; then
  echo "Running database check"
  python3 /usr/src/taiga-back/checkdb.py
  DB_CHECK_STATUS=$?

  if [ $DB_CHECK_STATUS -eq 1 ]; then
    echo "Failed to connect to database server or database does not exist."
    exit 1
  elif [ $DB_CHECK_STATUS -eq 2 ]; then
    echo "Configuring initial database"
    python3 /usr/src/taiga-back/manage.py migrate --noinput
    python3 /usr/src/taiga-back/manage.py loaddata initial_user
    python3 /usr/src/taiga-back/manage.py loaddata initial_project_templates
    python3 /usr/src/taiga-back/manage.py loaddata initial_role
    python3 /usr/src/taiga-back/manage.py compilemessages
  fi
fi

# Look for static folder, if it does not exist, then generate it
if [ ! -d "/usr/src/taiga-back/static" ]; then
  python3 /usr/src/taiga-back/manage.py collectstatic --noinput
fi

# Automatically replace "TAIGA_HOSTNAME" with the environment variable
sed -i "s/TAIGA_HOSTNAME/$TAIGA_HOSTNAME/g" /usr/src/taiga-front-dist/dist/conf.json

# Look to see if we should set the "eventsUrl"
# if [ ! -z "$RABBIT_PORT_5672_TCP_ADDR" ]; then
#   echo "Enabling Taiga Events"
#   sed -i "s/eventsUrl\": null/eventsUrl\": \"ws:\/\/$TAIGA_HOSTNAME\/events\"/g" /taiga/conf.json
#   mv /etc/nginx/taiga-events.conf /etc/nginx/conf.d/default.conf
# fi

# Handle enabling/disabling SSL
if [ "$TAIGA_SSL_BY_REVERSE_PROXY" = "True" ]; then
  echo "Enabling external SSL support! SSL handling must be done by a reverse proxy or a similar system"
  sed -i "s/http:\/\//https:\/\//g" /usr/src/taiga-front-dist/dist/conf.json
  sed -i "s/ws:\/\//wss:\/\//g" /usr/src/taiga-front-dist/dist/conf.json
# elif [ "$TAIGA_SSL" = "True" ]; then
#   echo "Enabling SSL support!"
#   sed -i "s/http:\/\//https:\/\//g" /taiga/conf.json
#   sed -i "s/ws:\/\//wss:\/\//g" /taiga/conf.json
#   mv /etc/nginx/ssl.conf /etc/nginx/conf.d/default.conf
elif grep -q "wss://" "/taiga/conf.json"; then
  echo "Disabling SSL support!"
  sed -i "s/https:\/\//http:\/\//g" /usr/src/taiga-front-dist/dist/conf.json
  sed -i "s/wss:\/\//ws:\/\//g" /usr/src/taiga-front-dist/dist/conf.json
fi

# Start nginx service (need to start it as background process)
# nginx -g "daemon off;"
service nginx start

# Run CMD
exec "$@"
