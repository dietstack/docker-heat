#!/bin/bash
# Integration test for heat service
# Test runs mysql,memcached,keystone and heat container and checks whether heat is running on public and admin ports

GIT_REPO=172.27.10.10
RELEASE_REPO=172.27.9.130
CONT_PREFIX=test
BRANCH=master

. lib/functions.sh

http_proxy_args="-e http_proxy=${http_proxy:-} -e https_proxy=${https_proxy:-} -e no_proxy=${no_proxy:-}"

cleanup() {
    echo "Clean up ..."
    docker stop ${CONT_PREFIX}_galera
    docker stop ${CONT_PREFIX}_rabbitmq
    docker stop ${CONT_PREFIX}_memcached
    docker stop ${CONT_PREFIX}_keystone
    docker stop ${CONT_PREFIX}_heat

    docker rm ${CONT_PREFIX}_galera
    docker rm ${CONT_PREFIX}_rabbitmq
    docker rm ${CONT_PREFIX}_memcached
    docker rm ${CONT_PREFIX}_keystone
    docker rm ${CONT_PREFIX}_heat
}

cleanup

##### Download/Build containers

# run galera docker image
get_docker_image_from_release galera http://${RELEASE_REPO}/docker-galera/${BRANCH} latest

# run rabbitmq docker image
get_docker_image_from_release rabbitmq http://${RELEASE_REPO}/docker-rabbitmq/${BRANCH} latest

# pull keystone image
get_docker_image_from_release keystone http://${RELEASE_REPO}/docker-keystone/${BRANCH} latest

# pull osadmin docker image
get_docker_image_from_release osadmin http://${RELEASE_REPO}/docker-osadmin/${BRANCH} latest

##### Start Containers

echo "Starting galera container ..."
docker run -d --net=host -e INITIALIZE_CLUSTER=1 -e MYSQL_ROOT_PASS=veryS3cr3t -e WSREP_USER=wsrepuser -e WSREP_PASS=wsreppass -e DEBUG= --name ${CONT_PREFIX}_galera galera:latest

echo "Wait till galera is running ."
wait_for_port 3306 30

echo "Starting Memcached node (tokens caching) ..."
docker run -d --net=host -e DEBUG= --name ${CONT_PREFIX}_memcached memcached

echo "Starting RabbitMQ container ..."
docker run -d --net=host -e DEBUG= --name ${CONT_PREFIX}_rabbitmq rabbitmq

# build heat container for current sources
./build.sh

sleep 10

# create databases
create_db_osadmin keystone keystone veryS3cr3t veryS3cr3t
create_db_osadmin heat heat veryS3cr3t veryS3cr3t

echo "Starting keystone container"
docker run -d --net=host \
           -e DEBUG="true" \
           -e DB_SYNC="true" \
           $http_proxy_args \
           --name ${CONT_PREFIX}_keystone keystone:latest

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
           --name ${CONT_PREFIX}_heat heat:latest


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
                           osadmin /bin/bash -c ". /app/tokenrc; \
                                                 bash -x /app/bootstrap.sh"

echo "Testing whether openstack stack list is successful..."
docker run --rm --net=host $http_proxy_args \
                           osadmin /bin/bash -c ". /app/adminrc; \
                                                 openstack stack list"

echo "Return code $?"

echo "======== Success :) ========="

if [[ "$1" != "noclean" ]]; then
    cleanup
fi
