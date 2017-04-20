#!/bin/bash
set -e

# set debug
DEBUG_OPT=false
if [[ $DEBUG ]]; then
        set -x
        DEBUG_OPT=true
fi

# if heat is not installed, quit
which heat-manage &>/dev/null || { echo "Heat is not installed!" && exit 1; }

# define variable defaults

DB_HOST=${DB_HOST:-127.0.0.1}
DB_PORT=${DB_PORT:-3306}
DB_PASSWORD=${DB_PASSWORD:-veryS3cr3t}

SERVICE_TENANT_NAME=${SERVICE_TENANT_NAME:-service}
SERVICE_USER=${SERVICE_USER:-heat}
SERVICE_PASSWORD=${SERVICE_PASSWORD:-veryS3cr3t}

KEYSTONE_HOST=${KEYSTONE_HOST:-127.0.0.1}
RABBITMQ_HOST=${RABBITMQ_HOST:-127.0.0.1}
RABBITMQ_PORT=${RABBITMQ_PORT:-5672}
RABBITMQ_USER=${RABBITMQ_USER:-openstack}
RABBITMQ_PASSWORD=${RABBITMQ_PASSWORD:-veryS3cr3t}

MEMCACHED_SERVERS=${MEMCACHED_SERVERS:-127.0.0.1:11211}

INSECURE=${INSECURE:-true}

HEAT_HOST=${HEAT_HOST:-127.0.0.1}
HEAT_DOMAIN_PASS=${HEAT_DOMAIN_PASS:-veryS3cr3t}

LOG_MESSAGE="Docker start script:"
OVERRIDE=0
CONF_DIR="/etc/heat"
OVERRIDE_DIR="/heat-override"
CONF_FILES=(`cd $CONF_DIR; find . -maxdepth 3 -type f`)

# check if external configs are provided
echo "$LOG_MESSAGE Checking if external config is provided.."
if [[ -f "$OVERRIDE_DIR/${CONF_FILES[0]}" ]]; then
        echo "$LOG_MESSAGE  ==> external config found!. Using it."
        OVERRIDE=1
        for CONF in ${CONF_FILES[*]}; do
                rm -f "$CONF_DIR/$CONF"
                ln -s "$OVERRIDE_DIR/$CONF" "$CONF_DIR/$CONF"
        done
fi

if [[ $OVERRIDE -eq 0 ]]; then
        for CONF in ${CONF_FILES[*]}; do
                echo "$LOG_MESSAGE generating $CONF file ..."
                sed -i "s/_DB_HOST_/$DB_HOST/" $CONF_DIR/$CONF
                sed -i "s/_DB_PORT_/$DB_PORT/" $CONF_DIR/$CONF
                sed -i "s/_DB_PASSWORD_/$DB_PASSWORD/" $CONF_DIR/$CONF
                sed -i "s/\b_SERVICE_TENANT_NAME_\b/$SERVICE_TENANT_NAME/" $CONF_DIR/$CONF
                sed -i "s/\b_SERVICE_USER_\b/$SERVICE_USER/" $CONF_DIR/$CONF
                sed -i "s/\b_SERVICE_PASSWORD_\b/$SERVICE_PASSWORD/" $CONF_DIR/$CONF
                sed -i "s/\b_DEBUG_OPT_\b/$DEBUG_OPT/" $CONF_DIR/$CONF
                sed -i "s/\b_KEYSTONE_HOST_\b/$KEYSTONE_HOST/" $CONF_DIR/$CONF
                sed -i "s/\b_RABBITMQ_HOST_\b/$RABBITMQ_HOST/" $CONF_DIR/$CONF
                sed -i "s/\b_RABBITMQ_PORT_\b/$RABBITMQ_PORT/" $CONF_DIR/$CONF
                sed -i "s/\b_RABBITMQ_USER_\b/$RABBITMQ_USER/" $CONF_DIR/$CONF
                sed -i "s/\b_RABBITMQ_PASSWORD_\b/$RABBITMQ_PASSWORD/" $CONF_DIR/$CONF
                sed -i "s/\b_MEMCACHED_SERVERS_\b/$MEMCACHED_SERVERS/" $CONF_DIR/$CONF
                sed -i "s/\b_INSECURE_\b/$INSECURE/" $CONF_DIR/$CONF
                sed -i "s/\b_HEAT_HOST_\b/$HEAT_HOST/" $CONF_DIR/$CONF
                sed -i "s/\b_HEAT_DOMAIN_PASS_\b/$HEAT_DOMAIN_PASS/" $CONF_DIR/$CONF
        done
        echo "$LOG_MESSAGE  ==> done"
fi


[[ $DB_SYNC ]] && echo "Running db_sync ..." && heat-manage db_sync

echo "$LOG_MESSAGE starting heat"
exec "$@"
