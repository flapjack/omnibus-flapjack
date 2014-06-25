# Building with Docker

``` bash
docker run -e "FLAPJACK_BUILD_TAG=0.9.0" omnibus-ubuntu bash -c "cd omnibus-flapjack ; bin/omnibus build project flapjack"
```

Need to build an image of all of flapjack's dependencies built so then building flapjack on top is super fast

