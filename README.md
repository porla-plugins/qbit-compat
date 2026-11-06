# A qBittorrent compatible API for Porla

Are you using Porla and wish it had better integration with the _\*arr_ stack?

This plugin implements enough of the qBittorrent API to make Sonarr and friends
integrate with Porla without any changes.

## Usage

_The plugin needs Porla 0.54.0 or later._

Install the plugin with the desired configuration. Like qBittorrent, the plugin
acts as one client: every login sees and can change every torrent in its
session, and categories are shared. Configure more than one user when apps
should have their own password, for example to rotate one without touching the
others, or their own session, to keep Sonarr's and Radarr's torrents apart.

#### Generating a password hash

```sh
echo -n "change-me" | argon2 $(openssl rand -hex 16) -id -t 2 -m 16 -p 1 -e
```

### Configuration

The smallest configuration is a save path and one user.

```lua
return {
    save_path = "/downloads",
    users = {
        sonarr = {
            password_hash = "$argon2id$v=19$m=65536,t=2,p=1$cmFuZG9tc2FsdDE2Y2hhcg$vlCnp+txDK2R9EAaM/P+wzocN1Wi/uMxT6dWn8tk8L8"
        }
    }
}
```

Every option, with its default where it has one:

```lua
return {
    -- where the API is served; use it as the URL Base in Sonarr or Radarr
    -- (default "/api/qbit-compat")
    prefix = "/api/qbit-compat",

    -- the absolute save path for new transfers (required); category and
    -- per-torrent save paths must be inside it, and relative ones are
    -- resolved against it
    save_path = "/downloads",

    -- the name of the session to use (default: Porla's default session)
    session = "arr",

    -- let deleteFiles=true remove downloaded data; when false only the
    -- torrent is removed (default false)
    allow_delete_files = false,

    -- seed limits for torrents that Sonarr or Radarr didn't send their own
    -- for (default: no limit). Only torrents in one of the *arrs' categories
    -- are affected: a finished one is paused, never removed, once it reaches
    -- a limit, so the *arr can remove it when "Remove Completed" is on.
    max_ratio = 2.0,
    max_seeding_time = 10080, -- minutes
    max_inactive_seeding_time = 1440, -- minutes

    -- Porla presets for added torrents; a category's preset wins over
    -- `preset` (default: none). The plugin always sets the save path and
    -- session itself, so a preset's are ignored.
    preset = "arr",
    category_presets = {
        ["tv-4k"] = "4k"
    },

    -- the logins (at least one is required); the key is the username
    users = {
        sonarr = {
            password_hash = "$argon2id$v=19$m=65536,t=2,p=1$cmFuZG9tc2FsdDE2Y2hhcg$vlCnp+txDK2R9EAaM/P+wzocN1Wi/uMxT6dWn8tk8L8",

            -- the session for this login (default: the session above)
            session = "sonarr"
        },
        radarr = {
            password_hash = "$argon2id$v=19$m=65536,t=2,p=1$cmFuZG9tc2FsdDE2Y2hhcg$vlCnp+txDK2R9EAaM/P+wzocN1Wi/uMxT6dWn8tk8L8"
        }
    }
}
```

### Setting up Sonarr and Radarr

In Sonarr or Radarr, go to _Settings → Download Clients_ and add a
_qBittorrent_ client:

- **Host** and **Port**: where Porla's HTTP server is reachable from Sonarr or
  Radarr.
- **URL Base**: the plugin's `prefix`, `/api/qbit-compat` unless you changed it.
- **Username** and **Password**: one of the `users` and the password you hashed
  for it.
- **Category**: any name, such as `tv-sonarr` or `radarr`. Sonarr and Radarr
  create the category when you click _Test_, and so does adding a torrent
  with a new category.

The other settings work as they do with qBittorrent. _Content Layout_ and
_First and Last First_ are ignored.

### Porla's HTTP settings

When Porla listens on `127.0.0.1` (the default), or `PORLA_HTTP_ALLOWED_HOSTS`
is set, it only answers to `localhost` and the allowed host names. Requests
for any other host get a 403, which Sonarr and Radarr report as a failed
login. Add the host name they use to reach Porla to `PORLA_HTTP_ALLOWED_HOSTS`.

`PORLA_HTTP_BASE_PATH` doesn't apply to plugin routes, so the API stays at
`prefix`. Behind a reverse proxy that only forwards the base path, either
forward `prefix` too or include the base path in `prefix`, for example
`/porla/api/qbit-compat`.

## Limitations

- Only the parts of the qBittorrent API that Sonarr and Radarr use are
  implemented. Other clients may call endpoints that answer with 501.
- `contentLayout` and `firstLastPiecePrio` are ignored when adding torrents.
- Failed logins aren't throttled, since plugins can't see the client's address.
- Torrents with missing files are reported as `error`, not `missingFiles`.
  Sonarr and Radarr treat both the same.
