FROM osmaster
MAINTAINER Kamil Madac (kamil.madac@t-systems.sk)

ARG http_proxy
ARG https_proxy
ARG no_proxy

# Source codes to download
ENV repo="https://github.com/openstack/heat" branch="stable/newton" commit=""

# Download nova source codes
RUN if [ -z $commit ]; then \
       git clone $repo --single-branch --depth=1 --branch $branch; \
    else \
       git clone $repo --single-branch --branch $branch; \
       cd heat && git checkout $commit; \
    fi

#RUN apt-get update; apt-get install -y nginx libgd-tools nginx-doc && \
#    rm /etc/nginx/sites-enabled/default && \
#    pip install uwsgi

# some cleanup
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Apply source code patches
RUN mkdir -p /patches
COPY patches/* /patches/
RUN /patches/patch.sh

# Install keystone with dependencies
RUN cd heat; pip install -r requirements.txt -c /requirements/upper-constraints.txt; pip install supervisor python-memcached; python setup.py install

# prepare directories for supervisor
RUN mkdir -p /etc/supervisord /var/log/supervisord

# copy heat configs
COPY configs/heat/* /etc/heat/

# copy supervisor config
COPY configs/supervisord/supervisord.conf /etc

# external volume
VOLUME /heat-override

# copy startup scripts
COPY scripts /app

# Define workdir
WORKDIR /app
RUN chmod +x /app/*

ENTRYPOINT ["/app/entrypoint.sh"]

# Define default command.
CMD ["/usr/local/bin/supervisord", "-c", "/etc/supervisord.conf"]

