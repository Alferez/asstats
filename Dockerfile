FROM debian:10
MAINTAINER Jose A Alferez <correo@alferez.es>

ENV DEBIAN_FRONTEND noninteractive

#### Configure TimeZone
ENV TZ=Europe/Madrid
RUN echo "Europe/Madrid" > /etc/timezone && rm /etc/localtime && ln -s /usr/share/zoneinfo/Europe/Madrid /etc/localtime && dpkg-reconfigure tzdata

#### Instalamos dependencias, Repositorios y Paquetes
RUN apt-get update && apt-get install -y --fix-missing wget curl nano rsyslog lsb-release gnupg2 git

### Instalamos dependencias de AS-Stats
#Deb 8
#RUN apt install -y rrdtool make librrd-simple-perl libnet-patricia-perl libjson-xs-perl whois libfile-find-rule-perl libdbi-perl libtrycatch-perl libdbd-sqlite3-perl netcat python3 python3-pip
#Deb 9
RUN apt install -y rrdtool make librrds-perl libnet-patricia-perl libjson-xs-perl whois libfile-find-rule-perl libdbi-perl libtrycatch-perl libdbd-sqlite3-perl netcat python3 python3-pip python


RUN (echo y;echo o conf prerequisites_policy follow;echo o conf commit)|cpan
RUN cpan install Net::sFlow

#### Instalamos ASstats
RUN mkdir /data
WORKDIR /data
RUN git clone https://github.com/manuelkasper/AS-Stats.git
WORKDIR /data/AS-Stats
RUN rm -rf www
RUN git clone https://github.com/nidebr/as-stats-gui.git
RUN mv as-stats-gui www; sed -i 's|/data/as-stats/|/data/AS-Stats/|g' /data/AS-Stats/www/config.inc; sed -i 's|/data/asstats/|/data/AS-Stats/|g' /data/AS-Stats/www/config.inc; sed -i 's|/AS-Stats/asstats/|/AS-Stats/|g' /data/AS-Stats/www/config.inc

RUN mkdir /data/AS-Stats/rrd; chmod 777 /data/AS-Stats/rrd; mkdir /data/AS-Stats/www/asset; chmod 777 /data/AS-Stats/www/asset
RUN git clone https://github.com/JackSlateur/perl-ip2as.git
#RUN ln -s /data/AS-Stats/perl-ip2as/ip2as.pm /data/AS-Stats/bin/ip2as.pm
RUN cp /data/AS-Stats/perl-ip2as/ip2as.pm /usr/lib/x86_64-linux-gnu/perl-base/
RUN if [ -f /data/AS-Stats/asstats_day.txt ]; then chmod 777 /data/AS-Stats/asstats_day.txt; fi

RUN sed -i 's|asinfo.txt|/data/AS-Stats/www/asinfo.txt|g' /data/AS-Stats/www/config.inc
RUN sed -i 's|showpeeras = false;|showpeeras = true;|g' /data/AS-Stats/www/config.inc
RUN sed -i 's|compat_rrdtool12 = false|compat_rrdtool12 = true|g' /data/AS-Stats/www/config.inc



RUN echo '*/5 * * * * root perl /data/AS-Stats/bin/rrd-extractstats.pl /data/AS-Stats/rrd /data/AS-Stats/conf/knownlinks /data/AS-Stats/asstats_day.txt' > /etc/cron.d/as-stat
RUN echo '0 0 1 * * * root (echo begin; echo verbose; for i in $(seq 1 65535); do echo "AS$i"; done; echo end) | netcat whois.cymru.com 43 | /data/AS-Stats/contrib/generate-asinfo.py > /data/AS-Stats/www/asinfo.txt' >> /etc/cron.d/as-stat

#### Instlamos Nginx
#Deb 8
# RUN apt install -y nginx php5-fpm php5-sqlite
# RUN php5enmod sqlite3

#Deb 9
RUN apt install -y nginx php-fpm php-sqlite3 php-gd php-odbc php-pear php-xml php-xmlrpc php-curl libmcrypt-dev php-dev
RUN phpenmod sqlite3 pdo_sqlite
RUN pecl install mcrypt-1.0.4
RUN phpenmod mcrypt
COPY assets/nginx /etc/nginx/sites-available/default

### Limpiamos
RUN apt-get clean
RUN rm -rf /tmp/* /var/tmp/*
RUN rm -rf /var/lib/apt/lists/*

### Add Entrypoing
COPY ./assets/start /asstats
RUN chmod +x /asstats
entrypoint /asstats

### Personalizacion
RUN echo "alias l='ls -la'" >> /root/.bashrc
RUN echo "export TERM=xterm" >> /root/.bashrc
RUN echo 'Acquire::ForceIPv4 "true";' | tee /etc/apt/apt.conf.d/99force-ipv4

EXPOSE 80
EXPOSE 6343/udp
EXPOSE 9000/udp
EXPOSE 6343
EXPOSE 9000

WORKDIR /root

