#!/bin/bash

# install openjdk
yum -y install java-11-openjdk-headless

# enable epel-release repo
yum -y install epel-release

# install pwgen
yum -y install pwgen

# install policycoreutils-python

yum -y install policycoreutils-python

# add mongodb repo
cat >/etc/yum.repos.d/mongodb-org.repo <<EOF
[mongodb-org-4.2]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/\$releasever/mongodb-org/4.2/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-4.2.asc
EOF

# install mongodb
yum -y install mongodb-org

# Reload SystemD Daemons
systemctl daemon-reload

# Start MongoDB
systemctl enable --now mongod.service

# verify MongoDB is running
systemctl --type service --state active | grep mongod || echo MongoDB not running >&2 

# add elasticsearch repo key
rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch

# add elasticsearch repo
cat >/etc/yum.repos.d/elasticsearch.repo <<EOF
[elasticsearch-7.x]
name=Elasticsearch repository for 7.x packages
baseurl=https://artifacts.elastic.co/packages/oss-7.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
EOF

# install elasticsearch
yum -y install elasticsearch-oss

# Configure elasticsearch
cat >>/etc/elasticsearch/elasticsearch.yml <<EOF
cluster.name: graylog
action.auto_create_index: false
EOF

# Reload SystemD Daemons
systemctl daemon-reload

# Start elasticsearch
systemctl enable --now elasticsearch

# verify elasticsearch is running
systemctl --type service --state active | grep elasticsearch || echo elasticsearch not running >&2

# add graylog repo
rpm -Uvh https://packages.graylog2.org/repo/packages/graylog-4.2-repository_latest.rpm

# install graylog
yum -y install graylog-server graylog-enterprise-plugins graylog-integrations-plugins graylog-enterprise-integrations-plugins

# Configure graylog
# set admin password
pass=""
admin_pass_verify=""
while [ -z "$admin_pass" ] || [ "$admin_pass" != "$admin_pass_verify" ]; do

    read -s -p "Set admin password: " admin_pass
    echo

    if [ -z "$admin_pass" ]; then
        echo "No admin password set." >&2
    else
        read -s -p "Confirm admin password: " admin_pass_verify
        echo

        if [ "$admin_pass" != "$admin_pass_verify" ]; then
            echo "Passwords do not match." >&2
        fi
    fi
done

sed -i.bak0 "s/root_password_sha2.*$/root_password_sha2 = $(echo $admin_pass | tr -d '\n' | sha256sum | cut -d' ' -f1)/g" /etc/graylog/server/server.conf
unset admin_pass
unset admin_pass_verify

# set password_secret
sed -i.bak1 "s/password_secret.*$/password_secret = $(pwgen -N 1 -s 96 | tr -d '\n')/g" /etc/graylog/server/server.conf

# set bind address
read -p "Hostname or IP to bind to (format: 198.0.2.176:9000 or for.example:8080): " http_bind
sed -i.bak2 "s/#\? *http_bind_address *= *[0-9].*$/http_bind_address = $http_bind/g" /etc/graylog/server/server.conf

# Reload SystemD Daemons
systemctl daemon-reload

# start graylog
systemctl enable --now graylog-server

# verify graylog is running
systemctl --type service --state active | grep graylog || echo graylog not running >&2

# selinux and firewall stuff
setsebool -P httpd_can_network_connect 1
semanage port -a -t http_port_t -p tcp 9000
semanage port -a -t http_port_t -p tcp 9200
semanage port -a -t mongod_port_t -p tcp 27017
firewall-cmd --permanent --add-port=9000/tcp
firewall-cmd --reload

# end message
echo "open http://$http_bind in a browser to finish setup."

