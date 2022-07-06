ARG NGINX_VERSION=1.19.3
ARG BITNAMI_NGINX_REVISION=r28
ARG BITNAMI_NGINX_TAG=${NGINX_VERSION}-debian-10-${BITNAMI_NGINX_REVISION}

FROM bitnami/nginx:${BITNAMI_NGINX_TAG} AS builder
USER root
## Redeclare NGINX_VERSION so it can be used as a parameter inside this build stage
ARG NGINX_VERSION
## Install required packages and build dependencies
RUN install_packages dirmngr gpg gpg-agent curl build-essential libpcre3-dev zlib1g-dev libperl-dev wget build-essential libssl-dev libaio-dev openssl unzip libreadline-dev
## Add trusted NGINX PGP key for tarball integrity verification
RUN gpg --keyserver pgp.mit.edu --recv-key 520A9993A1C052F8
## Download luajit, lua nginx module and compile
RUN cd /tmp && wget https://github.com/openresty/luajit2/archive/refs/tags/v2.1-20220310.tar.gz && \
    tar -zxvf v2.1-20220310.tar.gz && cd luajit2-2.1-20220310 && make install && \
    wget https://github.com/openresty/lua-nginx-module/archive/refs/tags/v0.10.21rc2.tar.gz && \
    tar -zxvf v0.10.21rc2.tar.gz -C /usr/local/lib && \
    wget https://github.com/vision5/ngx_devel_kit/archive/refs/tags/v0.3.1.tar.gz && \
    tar -zxvf v0.3.1.tar.gz -C /usr/local/lib
## tell nginx's build system where to find LuaJIT 
ENV LUAJIT_LIB=/usr/local/lib
ENV LUAJIT_INC=/usr/local/include/luajit-2.1
## Download NGINX, verify integrity and extract
RUN cd /tmp && \
    curl -O http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && \
    curl -O http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz.asc && \
    gpg --verify nginx-${NGINX_VERSION}.tar.gz.asc nginx-${NGINX_VERSION}.tar.gz && \
    tar xzf nginx-${NGINX_VERSION}.tar.gz
## Compile NGINX with desired module
RUN cd /tmp/nginx-${NGINX_VERSION} && \
    rm -rf /opt/bitnami/nginx && \
    ./configure --prefix=/opt/bitnami/nginx --with-compat --with-http_ssl_module --with-http_perl_module=dynamic \
    --with-http_v2_module --with-threads --with-file-aio --with-http_stub_status_module --with-http_auth_request_module --with-http_addition_module \
    --with-ld-opt="-Wl,-rpath,/usr/local/lib" --add-module=/usr/local/lib/lua-nginx-module-0.10.21rc2 --add-module=/usr/local/lib/ngx_devel_kit-0.3.1  && \
    make && \
    make install

ARG LUA_INCLUDE_DIR=/usr/local/include/luajit-2.1/
ARG LUA_CMODULE_DIR=/usr/local/lib
ARG LUA_MODULE_DIR=/usr/local/share/luajit-2.1.0-beta3

RUN cd /tmp && wget https://github.com/openresty/lua-resty-core/archive/refs/tags/v0.1.23rc1.tar.gz && \
    tar -zxvf v0.1.23rc1.tar.gz && cd lua-resty-core-0.1.23rc1  && make install PREFIX=/opt/bitnami/nginx &&  \
    cd /tmp && wget https://github.com/openresty/lua-resty-lrucache/archive/refs/tags/v0.11.tar.gz && \
    tar -zxvf v0.11.tar.gz && cd lua-resty-lrucache-0.11  && make install PREFIX=/opt/bitnami/nginx && \
    cd /tmp && wget https://github.com/ledgetech/lua-resty-http/archive/refs/tags/v0.17.0-beta.1.tar.gz && \
    tar -zxvf v0.17.0-beta.1.tar.gz && cd lua-resty-http-0.17.0-beta.1 && make install PREFIX=/opt/bitnami/nginx && \
    cd /tmp && wget https://github.com/openresty/lua-resty-dns/archive/refs/tags/v0.22.tar.gz && \
    tar -zxvf v0.22.tar.gz && cd lua-resty-dns-0.22 && make install PREFIX=/opt/bitnami/nginx && \
    cd /tmp && wget https://github.com/ElvinEfendi/lua-resty-global-throttle/archive/refs/tags/v0.2.0.tar.gz && \
    tar -zxvf v0.2.0.tar.gz && cd lua-resty-global-throttle-0.2.0 && make install PREFIX=/opt/bitnami/nginx && \
    cd /tmp && wget https://github.com/api7/lua-resty-ipmatcher/archive/refs/tags/v0.6.1.tar.gz && \
    tar -zxvf v0.6.1.tar.gz && cd lua-resty-ipmatcher-0.6.1/ && make install && cp resty/ipmatcher.lua /opt/bitnami/nginx/lib/lua/resty/ && \
    cd /tmp && wget https://github.com/openresty/lua-cjson/archive/refs/tags/2.1.0.8rc1.tar.gz && \
    tar -zxvf 2.1.0.8rc1.tar.gz && cd lua-cjson-2.1.0.8rc1/ && make && make install && cp /usr/local/lib/cjson.so /usr/local/lib/lua/5.1/cjson.so && \
    cd /tmp && wget https://github.com/openresty/lua-resty-balancer/archive/refs/tags/v0.04.tar.gz && \
    tar -zxvf v0.04.tar.gz && cd lua-resty-balancer-0.04 && make && make install PREFIX=/opt/bitnami/nginx && cp librestychash.so  /usr/local/lib/lua/5.1/librestychash.so && \
    cd /tmp && wget https://github.com/cloudflare/lua-resty-cookie/archive/refs/tags/v0.1.0.tar.gz && \
    tar -zxvf v0.1.0.tar.gz && cd lua-resty-cookie-0.1.0/ && make install PREFIX=/opt/bitnami/nginx && \
    cd /tmp && wget https://github.com/openresty/lua-resty-lock/archive/refs/tags/v0.08.tar.gz && \
    tar -zxvf v0.08.tar.gz && cd lua-resty-lock-0.08/ && make install PREFIX=/opt/bitnami/nginx


COPY lua/ /opt/bitnami/nginx/conf/lua
COPY nginx.conf /opt/bitnami/nginx/conf/nginx.conf
COPY default-fake-certificate.pem /opt/bitnami/nginx/ssl/default-fake-certificate.pem

## Enable module
RUN echo "load_module modules/ngx_http_perl_module.so;" | cat - /opt/bitnami/nginx/conf/nginx.conf > /tmp/nginx.conf && \
    cp /tmp/nginx.conf /opt/bitnami/nginx/conf/nginx.conf

RUN rm -rf /tmp/* && mkdir /opt/bitnami/nginx/tmp && mkdir /var/log/nginx && chown -R 1001:1001 /opt/bitnami/nginx && chown -R 1001:1001 /var/log/nginx

# RUN rm -rf /tmp && sed -i '/http {/a \   \ lua_package_path "/opt/bitnami/nginx/lib/lua/?.lua;;";' /opt/bitnami/nginx/conf/nginx.conf && chown -R 1001:1001 /opt/bitnami/nginx

USER 1001
