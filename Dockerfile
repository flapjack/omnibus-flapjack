FROM flapjack/omnibus-ubuntu:precise
MAINTAINER Jesse Reynolds @jessereynolds

RUN git clone --branch omnibus3 https://github.com/flapjack/omnibus-flapjack.git && \
    cd omnibus-flapjack && \
    bundle install --binstubs

