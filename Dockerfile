# Dockerfile for ELK stack
# Elasticsearch 2.0.0, Logstash 2.0.0, Kibana 4.2.0

# Build with:
# docker build -t <repo-user>/elk .

# Run with:
# docker run -p 5601:5601 -p 9200:9200 -p 5000:5000 -it --name elk <repo-user>/elk
FROM ubuntu:latest
# MAINTAINER Sebastien Pujadas http://pujadas.net 
COPY sources.list /etc/apt/sources.list
ENV TZ "Asia/Shanghai"
ENV LANG zh_CN.UTF-8
RUN localedef -f UTF-8 -i zh_CN zh_CN.UTF-8
ENV DEBIAN_FRONTEND noninteractive

ENV REFRESHED_AT 2015-11-20

###############################################################################
#                                INSTALLATION
###############################################################################

### install Elasticsearch && Logstash

RUN apt-get update -qq \
 && apt-get install -qqy curl wget

RUN wget -qO - https://packages.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
RUN wget -qO - https://packages.elasticsearch.org/GPG-KEY-elasticsearch | sudo apt-key add -
RUN echo deb http://packages.elasticsearch.org/elasticsearch/2.x/debian stable main > /etc/apt/sources.list.d/elasticsearch-2.x.list
RUN echo deb http://packages.elasticsearch.org/logstash/2.0/debian stable main > /etc/apt/sources.list.d/logstash.list
RUN apt-get update -qq \
 && apt-get install -qqy \
		elasticsearch \
		logstash \
		openjdk-7-jdk \
 && apt-get clean

### install Kibana

ENV KIBANA_HOME /opt/kibana
ENV KIBANA_PACKAGE kibana-4.2.0-linux-x64.tar.gz

RUN mkdir ${KIBANA_HOME} \
 && curl -O https://download.elasticsearch.org/kibana/kibana/${KIBANA_PACKAGE} \
 && tar xzf ${KIBANA_PACKAGE} -C ${KIBANA_HOME} --strip-components=1 \
 && rm -f ${KIBANA_PACKAGE} \
 && groupadd -r kibana \
 && useradd -r -s /usr/sbin/nologin -d ${KIBANA_HOME} -c "Kibana service user" -g kibana kibana \
 && chown -R kibana:kibana ${KIBANA_HOME}

ADD ./kibana-init /etc/init.d/kibana
RUN sed -i -e 's#^KIBANA_HOME=$#KIBANA_HOME='$KIBANA_HOME'#' /etc/init.d/kibana \
 && chmod +x /etc/init.d/kibana


###############################################################################
#                               CONFIGURATION
###############################################################################

### configure Elasticsearch

ADD ./elasticsearch.yml /etc/elasticsearch/elasticsearch.yml


### configure Logstash

# cert/key
RUN mkdir -p /etc/pki/tls/certs && mkdir /etc/pki/tls/private
ADD ./logstash-forwarder.crt /etc/pki/tls/certs/logstash-forwarder.crt
ADD ./logstash-forwarder.key /etc/pki/tls/private/logstash-forwarder.key

# filters
ADD ./01-filebeat-input.conf /etc/logstash/conf.d/01-filebeat-input.conf
ADD ./10-syslog.conf /etc/logstash/conf.d/10-syslog.conf
ADD ./11-nginx.conf /etc/logstash/conf.d/11-nginx.conf
ADD ./30-output.conf /etc/logstash/conf.d/30-output.conf

# patterns
ADD ./nginx.pattern /opt/logstash/patterns/nginx
RUN chown -R logstash:logstash /opt/logstash/patterns

# filebeat
RUN yes Y | /opt/logstash/bin/plugin install --version '0.9.6' logstash-input-beats


###############################################################################
#                                   START
###############################################################################

ADD ./start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

EXPOSE 5601 9200 9300 5000
VOLUME /var/lib/elasticsearch

CMD [ "/usr/local/bin/start.sh" ]
