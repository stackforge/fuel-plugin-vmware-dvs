#!/bin/bash

set -e

plugin_name=fuel-plugin-vmware-dvs
plugin_version=1.0
ip=`hiera master_ip`
port=8080
repo=simple

function _nova_patch {
    wget -O /usr/lib/python2.7/dist-packages/nova.patch "http://$ip:$port/plugins/$plugin_name-$plugin_version/nova.patch" && cd /usr/lib/python2.7/dist-packages/ ; patch -p1 < nova.patch
    for r in $(crm_mon -1|awk '/nova_compute_vmware/ {print $1}'); do
	crm resource restart $r
    done
}

function _dirty_hack {
    cd /usr/lib/python2.7/dist-packages/oslo
    mv messaging messaging.old
    cd /usr/lib/python2.7/dist-packages/
    mv suds suds.old
}

function _neutron_restart {
    service neutron-server restart
}

function _core_install {
    easy_install pip
    apt-get -y install git-core python-dev
}

function _driver_install {
    cd /usr/local/lib/python2.7/dist-packages/
    pip install -e git+git://github.com/yunesj/suds#egg=suds
    pip install oslo.messaging==1.8.3
    pip install git+git://github.com/Mirantis/vmware-dvs.git@mos-6.1
}

function _ln {
    cd /usr/local/lib/python2.7/dist-packages/oslo
    ln -s /usr/lib/python2.7/dist-packages/oslo/db
    ln -s /usr/lib/python2.7/dist-packages/oslo/rootwrap
}

function _config {
    cd /etc/neutron
    cp neutron.conf neutron.conf.old
    sed -i  s/"#notification_driver.*"/notification_driver=messagingv2/ neutron.conf
    sed -i  s/"#notification_topics.*"/notification_topics=vmware_dvs/ neutron.conf
    cd /etc/neutron/plugins/ml2
    mv ml2_conf.ini ml2_conf.ini.old
    wget "http://$ip:$port/plugins/$plugin_name-$plugin_version/ml2_conf.ini"
}

_nova_patch
_core_install
_dirty_hack
_driver_install
_ln
_config
_neutron_restart
