#!/bin/bash
# Integration test for heat service
# Test runs mysql,memcached,keystone and heat container and checks whether heat is running on public and admin ports

DOCKER_PROJ_NAME=${DOCKER_PROJ_NAME:-''}
CONT_PREFIX=test

. lib/functions.sh

http_proxy_args="-e http_proxy=${http_proxy:-} -e https_proxy=${https_proxy:-} -e no_proxy=${no_proxy:-}"

cleanup() {
    echo "Clean up ..."
    docker stop ${CONT_PREFIX}_mariadb
    docker stop ${CONT_PREFIX}_rabbitmq
    docker stop ${CONT_PREFIX}_memcached
    docker stop ${CONT_PREFIX}_keystone
    docker stop ${CONT_PREFIX}_heat

    docker rm ${CONT_PREFIX}_mariadb
    docker rm ${CONT_PREFIX}_rabbitmq
    docker rm ${CONT_PREFIX}_memcached
    docker rm ${CONT_PREFIX}_keystone
    docker rm ${CONT_PREFIX}_heat
}

cleanup

##### Start Containers

echo "Starting mariadb container ..."
docker run --net=host -d -e MYSQL_ROOT_PASSWORD=veryS3cr3t --name ${CONT_PREFIX}_mariadb \
       mariadb:10.1

echo "Wait till mariadb is running ."
wait_for_port 3306 30

echo "Starting Memcached node (tokens caching) ..."
docker run -d --net=host -e DEBUG= --name ${CONT_PREFIX}_memcached memcached

echo "Wait till Memcached is running ."
wait_for_port 11211 30

echo "Starting RabbitMQ container ..."
docker run -d --net=host -e DEBUG= --name ${CONT_PREFIX}_rabbitmq rabbitmq

echo "Wait till RabbitMQ is running ."
wait_for_port 5672 120

# create openstack user in rabbitmq
docker exec ${CONT_PREFIX}_rabbitmq rabbitmqctl add_user openstack veryS3cr3t
docker exec ${CONT_PREFIX}_rabbitmq rabbitmqctl set_permissions openstack '.*' '.*' '.*'

# build heat container for current sources
./build.sh

# create databases
create_db_osadmin keystone keystone veryS3cr3t veryS3cr3t
create_db_osadmin heat heat veryS3cr3t veryS3cr3t

echo "Starting keystone container"
docker run -d --net=host \
           -e DEBUG="true" \
           -e DB_SYNC="true" \
           $http_proxy_args \
           --name ${CONT_PREFIX}_keystone ${DOCKER_PROJ_NAME}keystone:latest

echo "Wait till keystone is running ."

wait_for_port 5000 30
ret=$?
if [ $ret -ne 0 ]; then
    echo "Error: Port 5000 (Keystone) not bounded!"
    exit $ret
fi

wait_for_port 35357 30
ret=$?
if [ $ret -ne 0 ]; then
    echo "Error: Port 35357 (Keystone Admin) not bounded!"
    exit $ret
fi

echo "Starting heat container"
docker run -d --net=host \
           -e DEBUG="true" \
           -e DB_SYNC="true" \
           $http_proxy_args \
           --name ${CONT_PREFIX}_heat ${DOCKER_PROJ_NAME}heat:latest


##### TESTS #####

wait_for_port 8004 30
ret=$?
if [ $ret -ne 0 ]; then
    echo "Error: Port 8004 (Heat Orchestration) not bounded!"
    exit $ret
fi

wait_for_port 8000 30
ret=$?
if [ $ret -ne 0 ]; then
    echo "Error: Port 8000 (Heat cloudformation) not bounded!"
    exit $ret
fi

# bootstrap openstack keystone

docker run --rm --net=host $http_proxy_args \
                           ${DOCKER_PROJ_NAME}osadmin /bin/bash -c ". /app/tokenrc; \
                                                 bash -x /app/bootstrap.sh"

echo "Testing whether openstack stack list is successful..."
docker run --rm --net=host $http_proxy_args \
                           ${DOCKER_PROJ_NAME}osadmin /bin/bash -c ". /app/adminrc; \
                                                 openstack stack list"

echo "Return code $?"

echo "======== Success :) ========="

if [[ "$1" != "noclean" ]]; then
    cleanup
fi
