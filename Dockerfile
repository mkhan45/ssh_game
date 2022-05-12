FROM hexpm/elixir:1.13.3-erlang-24.3.4-ubuntu-focal-20211006

WORKDIR src
CMD mix local.rebar --force && \
    mix local.hex --force && \
    mix deps.get --only prod && \
    MIX_ENV=prod mix release
