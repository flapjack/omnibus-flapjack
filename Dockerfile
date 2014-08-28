FROM flapjack/omnibus-ubuntu:latest
MAINTAINER Jesse Reynolds @jessereynolds

RUN if [ ! -e /omnibus-flapjack ] ; then \
      git clone --branch omnibus3 https://github.com/flapjack/omnibus-flapjack.git /omnibus-flapjack ; \
    fi && \
    cd /omnibus-flapjack && \
    bundle install --binstubs

ENV FLAPJACK_BUILD_REF 6ba5794
ENV FLAPJACK_PACKAGE_VERSION 1.0.0~rc3~20140729T233700-6ba5794

CMD cd /omnibus-flapjack && \
    git pull && \
    bundle install --binstubs && \
    bin/omnibus build --log-level=info flapjack && \
    echo "Done building flapjack at `date`" && \
    ls -ld /omnibus-flapjack/pkg/flapjack*deb && \
    ruby -run -ehttpd . -p8000

EXPOSE 8000

