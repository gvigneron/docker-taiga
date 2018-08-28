FROM ubuntu:18.04
MAINTAINER Gregoire Vigneron <gregoire.vigneron.pro@gmail.com>

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get upgrade
RUN apt-get update

# #############################################################################
# PREREQUISITES
# #############################################################################

# Setup based on https://taigaio.github.io/taiga-doc/dist/setup-production.html

# Essential packages:
RUN apt-get install -y build-essential binutils-doc autoconf flex bison libjpeg-dev
RUN apt-get install -y libfreetype6-dev zlib1g-dev libzmq3-dev libgdbm-dev libncurses5-dev
RUN apt-get install -y automake libtool libffi-dev curl git tmux gettext
RUN apt-get install -y nginx
RUN apt-get install -y rabbitmq-server redis-server
RUN apt-get install -y circus

# Python (3.5) and virtualenvwrapper must be installed along with a few third-party libraries:
RUN apt-get install -y python3 python3-pip python-dev python3-dev python-pip virtualenvwrapper
RUN apt-get install -y libxml2-dev libxslt-dev
RUN apt-get install -y libssl-dev libffi-dev
RUN bash

# Forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log
RUN ln -sf /dev/stderr /var/log/nginx/error.log

# Create a user named taiga, and a virtualhost for RabbitMQ (taiga-events)
# RUN rabbitmqctl add_user taiga PASSWORD_FOR_EVENTS
# RUN rabbitmqctl add_vhost taiga
# RUN rabbitmqctl set_permissions -p taiga taiga ".*" ".*" ".*"

# Create the sources folder
RUN mkdir -p /src

# Create the logs folder
RUN mkdir -p /logs

# #############################################################################
# BACKEND CONFIGURATION
# #############################################################################

# Download the code
RUN git clone https://github.com/taigaio/taiga-back.git /src/taiga-back
WORKDIR /src/taiga-back
RUN git checkout stable

# Install dependencies
RUN pip3 install -r requirements.txt

# Copy-paste settings and DB configuration
COPY checkdb.py /src/taiga-back
COPY settings/taiga-back/local.py /src/taiga-back/settings/local.py

# Setup media
VOLUME /src/taiga-back/media

# #############################################################################
# FRONTEND CONFIGURATION
# #############################################################################

# Download the code
RUN git clone https://github.com/taigaio/taiga-front-dist.git /src/taiga-front-dist
WORKDIR /src/taiga-front-dist
RUN git checkout stable

# Copy-paste settings
COPY settings/taiga-front/conf.json /src/taiga-front-dist/dist/conf.json

# #############################################################################
# EVENTS INSTALLATION
# #############################################################################

# Not supported for now.

# #############################################################################
# START AND EXPOSE TAIGA
# #############################################################################

# Circus and gunicorn
# Not supported for now.

# Nginx
# Based on https://taigaio.github.io/taiga-doc/dist/setup-production.html
# and https://github.com/benhutchins/docker-taiga/
# Remove the default nginx config file to avoid collision with Taiga
RUN rm /etc/nginx/sites-enabled/default
COPY settings/nginx/taiga.conf /etc/nginx/conf.d/taiga.conf

COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

CMD ["python3", "/src/taiga-back/manage.py", "runserver", "0.0.0.0:8001"]
