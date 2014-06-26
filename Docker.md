# Building with Docker

``` bash
docker pull flapjack/omnibus-ubuntu

docker run -e "FLAPJACK_BUILD_TAG=1.0.0rc1" omnibus-ubuntu bash -c "cd omnibus-flapjack ; bin/omnibus build project flapjack"
```

Need to build an image of all of flapjack's dependencies built so then building flapjack on top is super fast

