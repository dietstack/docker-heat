## Keystone docker

### Using

```
git clone git@172.27.10.10:openstack/docker-keystone.git
cd docker-keystone
docker build -t keystone .
```
Result will be keystone image in local image registry.

# Development
There is a script called `test.sh`. This can be used either for development or testing. By default, script runs couple of docker containers (galera, memcached, keystone), make tests and removes containers. This is used for testing purposes (also in CI).
When you run the script with parameter noclean, it'll build environment, runs all tests and leave all dockers running. This is usefol for development of glance containers.

