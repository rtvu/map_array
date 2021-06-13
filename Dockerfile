FROM buildpack-deps:focal

ARG USER_ID
ARG GROUP_ID

ENV LANG=C.UTF-8

RUN /bin/bash -c "if [[ -z \"$USER_ID\" ]] ; then exit 1 ; fi"
RUN /bin/bash -c "if [[ -z \"$GROUP_ID\" ]] ; then exit 1 ; fi"

RUN \
  apt-get update && \
  apt-get install -y --no-install-recommends \
    sudo \
    && \
  wget https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb && \
  apt-get install -y --no-install-recommends ./erlang-solutions_2.0_all.deb && \
  apt-get update && \
  apt-get install -y --no-install-recommends esl-erlang && \
  apt-get install -y --no-install-recommends elixir && \  
  rm erlang-solutions_2.0_all.deb && \
  rm -rf /var/lib/apt/lists/*

RUN \
  addgroup --gid $GROUP_ID user && \
  adduser --disabled-password --gecos "" --uid $USER_ID --gid $GROUP_ID user && \
  echo "user:user" | chpasswd && \
  usermod -aG sudo user

USER user

RUN \
  mix local.hex --force && \
  mix local.rebar --force && \
  mkdir /home/user/app

WORKDIR /home/user/app

CMD ["/bin/bash"]
