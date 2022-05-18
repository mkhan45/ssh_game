# SSH Games

To join a connect four game, `ssh ssh ssh-game.fly.dev`, leave the password blank, and make/join a room

## Deployment

Use mix releases:
```
git clone https://github.com/mkhan45/ssh_game
cd ssh_game
mix release
./_build/dev/rel/ssh_ttt/bin/ssh_ttt daemon
```

## Architecture

Something like this

![image](https://user-images.githubusercontent.com/24574272/167675753-ff6c1073-1dd7-4cde-8792-2d182550aa27.png)
