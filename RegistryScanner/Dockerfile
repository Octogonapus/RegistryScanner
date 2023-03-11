FROM ubuntu:22.04

WORKDIR /
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/New_York
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt-get update -y && \
    apt-get upgrade -y && \
    apt-get install -y ssh curl wget build-essential git && \
    rm -rf /var/lib/apt/lists/*

RUN chmod 777 /tmp
RUN mkdir -p -m 0700 ~/.ssh

RUN ssh-keyscan github.com >> ~/.ssh/known_hosts

RUN wget -nv https://julialang-s3.julialang.org/bin/linux/x64/1.8/julia-1.8.5-linux-x86_64.tar.gz && \
    tar xf julia-1.8.5-linux-x86_64.tar.gz && \
    rm julia-1.8.5-linux-x86_64.tar.gz
RUN ln -s /julia-1.8.5/bin/julia /usr/local/bin/julia

COPY Project.toml /RegistryScanner/Project.toml
COPY Manifest.toml /RegistryScanner/Manifest.toml
RUN julia -t auto --project=RegistryScanner -e 'import Pkg; Pkg.instantiate(); Pkg.build(); Pkg.precompile();'

COPY src /RegistryScanner/src
RUN julia -t auto --project=RegistryScanner -e 'import Pkg; Pkg.precompile();'

ENTRYPOINT [ "julia", "-t", "auto", "--project=RegistryScanner", "-e", "using RegistryScanner; run_service()" ]
