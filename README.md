# Davilland DH.4918 ✈️

Gear up and deploy WebDAV on the edge.

A minimal, reproducible setup for deploying a fully working WebDAV server (with locking support) on Fly.io.

---

This project provides a single script that launches working WebDAV server with locking, on the public internet, 
in minutes:

```
dav-off.sh
```

It generates everything needed to:

* build and deploy a WebDAV server
* configure authentication
* ensure persistent storage
* enable proper WebDAV locking (DavLockDB)
* verify that the deployment works correctly

---

## Features

* Basic authentication (via Fly secrets)
* Persistent storage using Fly volumes
* WebDAV locking support (works with clients like Oxygen XML Editor)
* Auto-created project directory with a welcome file
* Built-in verification script (`verify.sh`)
* Docker-based (no local Apache setup needed)

---

## Prerequisites (pre-flight)

You need:

* A **Fly.io account**
  https://fly.io

* The **Fly CLI installed and authenticated**

  ```
  fly auth login
  ```

* A local Unix-like environment:

  * bash
  * docker (for builds via `fly deploy`)
  * curl (for verification)

Optional:

* `xmllint` (for nicer XML validation in `verify.sh`)

---

## Usage

Run the setup script:

```
./dav-off.sh <project-name>
```

You will be prompted for:

* WebDAV username
* WebDAV password

The script generates a project directory containing:

* `Dockerfile`
* `fly.toml`
* `init.sh`
* `fix.conf`
* `verify.sh`
* `DEPLOY.md`

---

## Deployment

Follow the generated instructions:

```
cd <project-name>

fly apps create <project-name>
fly volumes create data_volume --region fra
fly secrets set WEBDAV_USER=<user> WEBDAV_PASSWORD=********
fly deploy
```

Once deployed, your WebDAV endpoint will be:

```
https://<project-name>.fly.dev
```

---

## Verification

Run:

```
./verify.sh https://<project-name>.fly.dev <username>
```

This will:

* check basic connectivity (HTTP 200)
* perform a WebDAV `PROPFIND` (expects 207)
* validate XML response (if `xmllint` is installed)
* confirm access to `welcome.txt`

---

## Storage layout

Inside the container:

```
/data/projects        # persistent volume (Fly)
/var/lib/dav/data     # symlink → /data/projects
/var/lib/dav/DavLock  # lock database (critical for WebDAV locking)
/user.passwd          # authentication file
```

---

## Locking support

WebDAV locking is enabled via:

```
DavLockDB /var/lib/dav/DavLock
```

The setup ensures:

* correct file type (regular file, not directory)
* proper permissions
* compatibility with WebDAV clients (e.g. Oxygen XML Editor)

---

## Welcome file

On first startup, the server creates:

```
/data/projects/welcome.txt
```

This confirms:

* the server is writable
* authentication works
* the volume is mounted correctly

---

## ⚠Notes / Caveats

* Passwords are stored securely via Fly secrets (not in the image)
* The container runs with permissive filesystem permissions (`777`) for simplicity
* This setup is intended for:

  * development
  * lightweight collaboration
  * prototyping

For production hardening, consider:

* stricter permissions
* TLS tuning
* user isolation

---

## Design philosophy

This project intentionally avoids:

* complex Apache configs
* runtime templating
* environment-dependent paths

Instead, it uses:

* minimal overrides (`fix.conf`)
* predictable filesystem layout
* runtime initialization via `init.sh`

---

## License

[ISC](LICENSE) 


------------------------------------------------------------
[ STATUS ] : CLEARED FOR THE EDGE
[ VECTOR ] : FLY.DEV / PORT 443
[ PILOT  ] : YOU HAVE THE CONTROLS
------------------------------------------------------------
          Blue skies and low latency. Out.

