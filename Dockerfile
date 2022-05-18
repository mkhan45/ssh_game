FROM hexpm/elixir:1.13.3-erlang-24.3.4-alpine-3.14.5 as builder

COPY . /src
WORKDIR /src

RUN MIX_ENV=prod mix release

FROM hexpm/elixir:1.13.3-erlang-24.3.4-alpine-3.14.5

COPY --from=builder /src/_build/prod/rel/ssh_ttt/ /ssh_ttt
COPY ssh_dir /ssh_ttt/ssh_dir
WORKDIR /ssh_ttt

CMD ./bin/ssh_ttt start
