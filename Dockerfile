FROM flapjack/omnibus-ubuntu:latest
MAINTAINER Jesse Reynolds @jessereynolds

# could use ADD or COPY here instead I guess?
RUN git clone --branch omnibus3 https://github.com/flapjack/omnibus-flapjack.git && \
    cd omnibus-flapjack && \
    bundle install --binstubs

ENV FLAPJACK_BUILD_TAG 1.0.0rc1

RUN cd omnibus-flapjack && \
    bin/omnibus build flapjack-dependencies

RUN cd omnibus-flapjack && \
    bin/omnibus build flapjack

