#!/bin/bash
# Integration test for keystone service
# Test runs mysql,memcached and keystone container and checks whether keystone is running on public and admin ports

GIT_REPO=172.27.10.10
RELEASE_REPO=172.27.9.130
ADMIN_TOKEN=veryS3cr3t
CONT_PREFIX=test
BRANCH=master

. lib/functions.sh

cleanup() {
    echo "Clean up ..."

    docker stop ${CONT_PREFIX}_galera
    docker stop ${CONT_PREFIX}_memcached
    docker stop ${CONT_PREFIX}_keystone

    docker rm ${CONT_PREFIX}_galera
    docker rm ${CONT_PREFIX}_memcached
    docker rm ${CONT_PREFIX}_keystone
}

cleanup

# turn off git ssl verification as we use self signed certs
git config --global http.sslVerify false

##### Download/Build containers

# pull galera docker image
get_docker_image_from_release galera http://${RELEASE_REPO}/docker-galera/${BRANCH} latest

# pull osmaster docker image
get_docker_image_from_release osmaster http://${RELEASE_REPO}/docker-osmaster/${BRANCH} latest

# pull osadmin docker image
get_docker_image_from_release osadmin http://${RELEASE_REPO}/docker-osadmin/${BRANCH} latest

# build keystone docker image
./build.sh --no-cache

##### Start Containers

echo "Starting galera container ..."
docker run -d --net=host -e INITIALIZE_CLUSTER=1 -e MYSQL_ROOT_PASS=veryS3cr3t -e WSREP_USER=wsrepuser -e WSREP_PASS=wsreppass -e DEBUG= --name ${CONT_PREFIX}_galera galera:latest

echo "Wait till galera is running ."
wait_for_port 3306 30

echo "Starting Memcached node (tokens caching) ..."
docker run -d --net=host -e DEBUG= --name ${CONT_PREFIX}_memcached memcached

sleep 10

# create database for keystone
create_db_osadmin keystone keystone veryS3cr3t veryS3cr3t

echo "Starting keystone container"
#KEYSTONE_TAG=$(docker images | grep -w keystone | head -n 1 | awk '{print $2}')
docker run -d --net=host -e DEBUG="true" -e DB_SYNC="true" --name ${CONT_PREFIX}_keystone keystone:latest

##### TESTS #####

wait_for_port 5000 30
ret=$?
if [ $ret -ne 0 ]; then
    echo "Error: Port 5000 not bounded!"
    exit $ret
fi

wait_for_port 35357 30
ret=$?
if [ $ret -ne 0 ]; then
    echo "Error: Port 35357 not bounded!"
    exit $ret
fi

# test whether API is really working
# we try to create service over identity API v3

# Get API call
URL="http://127.0.0.1:5000/"
echo "Test GET ${URL}"
OUT=$(curl -s "${URL}")
echo ${OUT}
if [[ ${OUT} != *"versions"* ]]; then
    echo "TEST ERROR !!!"
    exit 1
fi

# POST API call - create service
URL="http://127.0.0.1:35357/v3/services"
echo "Creating service keystone ..."
OUT=$(curl -s -X POST -H "X-Auth-Token:${ADMIN_TOKEN}" -H "Content-Type: application/json" -d '{"service": {"type": "identity", "name": "keystone", "description": "Identity"}}' "${URL}")
echo ${OUT}

# Test whether service was created
URL="http://127.0.0.1:5000/v3/services"
OUT=$(curl -s -H "X-Auth-Token:${ADMIN_TOKEN}" "${URL}")
echo ${OUT}
if [[ ${OUT} != *"services"* || ${OUT} != *"keystone"* ]]; then
    echo "TEST ERROR !!!"
    exit 1
fi

echo "======== Success :) ========="

if [[ "$1" != "noclean" ]]; then
    cleanup
fi

