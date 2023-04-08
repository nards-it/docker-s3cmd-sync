![Docker Image Version (latest semver)](https://img.shields.io/docker/v/nards/docker-s3cmd-sync?sort=semver&label=Version&logo=docker)
![Docker Image Size (latest semver)](https://img.shields.io/docker/image-size/nards/docker-s3cmd-sync?label=Size&logo=docker)
![Docker Pulls](https://img.shields.io/docker/pulls/nards/docker-s3cmd-sync?label=Pulls&logo=docker)
![Docker Stars](https://img.shields.io/docker/stars/nards/docker-s3cmd-sync?label=Stars&logo=docker)
![GitHub Repo forks](https://img.shields.io/github/forks/nards-it/docker-s3cmd-sync?label=Forks&logo=github)
![GitHub Repo stars](https://img.shields.io/github/stars/nards-it/docker-s3cmd-sync?label=Stars&logo=github)

![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/nards-it/docker-s3cmd-sync/main.yaml?label=Latest%20build&logo=github)
![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/nards-it/docker-s3cmd-sync/release.yaml?label=Last%20release%20build&logo=github)
![GitHub issues](https://img.shields.io/github/issues/nards-it/docker-s3cmd-sync?label=Issues&logo=github)
![GitHub pull requests](https://img.shields.io/github/issues-pr/nards-it/docker-s3cmd-sync?label=Pull%20requests&logo=github)
![GitHub commits since latest release (by SemVer)](https://img.shields.io/github/commits-since/nards-it/docker-s3cmd-sync/latest?sort=semver)
![GitHub Licence](https://img.shields.io/github/license/nards-it/docker-s3cmd-sync)


# Docker sync volume using S3Cmd
Creates a Docker container that is restored and backed up to a directory on s3, **keeping posix file attributes**.
You could use this to run short lived processes that work with and persist data to and from S3.

This project is created by merging from **docker-s3-volume** and **S3Cmd**.
**docker-s3-volume** gives me a good architecture to sync periodically volumes with s3.
**S3Cmd** allows me to preserve posix file attributes into s3 bucket, usign additional attributes.

I need to fork away from that projects because no one grants me all features and my features are incompatible with evolution of the other projects.

I actually mantain this project. You could create issues or contribute as you want.

## Configuration

The ``.s3cfg`` configuration file need to be mounted into ``/root/.s3cfg`` container as volume.

It basically uses the .s3cfg configuration file. This config file contains all the variables to connect to your S3 provider. If you are already using s3cmd locally the previous docker command will use the .s3cfg file you already have at ``$HOME/.s3/.s3cfg``, or you could generate it using the following command.

```bash
s3cmd --configure
```

In case you are not using s3cmd locally or don't want to use your local .s3cfg settings, you can use the **d3kf/s3cmd** client to help you to generate your .s3cfg config file by using the following command.

```sh
mkdir .s3
docker run --rm -ti -v $(pwd):/s3 -v $(pwd)/.s3:/root d3fk/s3cmd --configure
```

## Usage

For the simplest usage, you can just start the data container:

```bash
docker run -d --name my-data-container \
           -v /home/user/.s3/.s3cfg:/root/.s3cfg \
           nards/docker-s3cmd-sync /data/ s3://mybucket/someprefix
```

This will download the data from the S3 location you specify into the
container's `/data` directory. When the container shuts down, the data will be
synced back to S3.

## Configuration

Configuration options could be passed to the script by command line or by
setting related environment variable. The command line option will always override
the command line parameters.

| Variable | Description | Command Line Option | Environment Variable |
|---|---|---|---|
| Backup interval | Time interval between backups (es. "10m", "6h") | -i \| --backup-interval \<time\> | $BACKUP_INTERVAL |
| Clean restore | Restore only if local directory is empty, else the script fails | -c \| --clean-restore | $CLEAN_RESTORE |
| Two-way sync | Does backup and restore an every cycle, else only does backup. This influence S3CMD sync flags.<br> :warning: **PARTIALLY WORKING** Read more at [Two-way sync](#two-way-sync) | -t \| --two-way-sync | $TWO_WAY_SYNC |
| Final backup strategy | Sets the s3cmd final cycle strategy on shutdown signal trap. Default is "AUTO" to better preserve posix permissions, "PUT" and "SYNC" are available. | --final-strategy \<mode\> | $S3CMD_FINAL_STRATEGY |
| S3CMD sync flags | Additional flags passed to s3cmd commands. Default to `--delete-removed`, or empty if two-way sync is enabled. Configurable only by environment variable | *n/d* | $S3_GLOBAL_FLAGS |
|| Additional flags passed to s3cmd restore commands. Default empty. Configurable only by environment variable | *n/d* | $S3_RESTORE_FLAGS |
|| Additional flags passed to s3cmd backup commands. Default empty. Configurable only by environment variable | *n/d* | $S3_BACKUP_FLAGS |
|| Additional flags passed to s3cmd last backup command on gracefully stop. Default empty. Configurable only by environment variable | *n/d* | $S3_BACKUP_FINAL_FLAGS |

### Configuring a sync interval

When the `-i <time>` command line option is given or the `BACKUP_INTERVAL` environment variable is set,
a watcher process will sync the `/data` directory to S3 on the interval you specify. The interval can
be specified in seconds, minutes, hours or days (adding `s`, `m`, `h` or `d` as
the suffix):

```bash
docker run -d --name my-data-container -e BACKUP_INTERVAL=2m \
           -v /home/user/.s3/.s3cfg:/root/.s3cfg \
           nards/docker-s3cmd-sync /data/ s3://mybucket/someprefix
```
### Final backup strategy

A final backup will always be performed when a shutdown event is trapped. The script will traps on `SIGHUP` `SIGINT` `SIGTERM` and grants docker container backup on gracefully shutdown.

The environment variable `S3CMD_FINAL_STRATEGY` could be used to force the last sync strategy to:
- `AUTO` (default) will select the best option to keep all permissions
- `PUT` will upload again all files
- `SYNC` will sync only identificable changed files

It could be configured to optimize execution and posix permissions. Read more at [Posix file attributes persist during sync](#posix-file-attributes-persist-during-sync).


### Forcing a sync

A sync can be forced by sending the container the `USR1` signal:

```bash
docker kill --signal=USR1 my-data-container
```

### Forcing a put

A push can be forced by sending the container the `USR2` signal:

```bash
docker kill --signal=USR2 my-data-container
```

### Two-way sync

> :warning: **PARTIALLY WORKING**: effective two-way sync is not implemented. This is actually a workaround.

**Two-way sync** mode could be enabled by `-e TWO_WAY_SYNC="true"` or by command line. If you not enable the `TWO_WAY_SYNC` mode, if two or more folders are synchronized to same bucket/folder you cannot see modifications.

If 2 or more folders are synchronized to the same bucket/folder it needs to propagate modifications periodically from *local* to *s3* and viceversa. Normal script flow propagate from *s3* to *local* only at startup, next only from *s3* to *local* periodically. The **two-way sync** mode changes the script flow, doing `backup` and `restore` phases on each cycle, instead of only `backup` phase.

The two-way sync mode usually manages files creation and deletion, but this is not implemented on s3cmd and not supported by this library. File deletion is **disabled** by default activating the two-way sync mode and could be changed acting on **S3CMD sync flags** and on `--delete-removed` flag.

This is a **temporary solution** and will be corrected on next versions, based on a better workaround or on s3cmd updates in that way.

### Using Compose and named volumes

Most of the time, you will use this image to sync data for another container.
You can use `docker-compose` for that:

```yaml
# docker-compose.yaml
version: "2"

volumes:
  s3data:
    driver: local

services:
  s3vol:
    image: nards/docker-s3cmd-sync
    command: /data/ s3://mybucket/somefolder
    cap_add:
      - ALL
    environment:
      - "BACKUP_INTERVAL=1h"
    volumes:
      - /home/user/.s3/.s3cfg:/root/.s3cfg
      - s3data:/data
  db:
    image: postgres
    depends_on:
      s3vol:
        condition: service_healthy
    volumes:
      - s3data:/var/lib/postgresql/data
```

Container healtcheck could be used, as in the above example, to force other services to wait all volume in synchronized. Healthcheck have a wait-time of **1 hour**.
Consider to start first backup without dependencies if you evaluate the restore could need more time!

## Posix file attributes persist during sync

Traditional S3 bucket cannot persist posix file attributes, as creation date and posix file and folder permissions.

Using S3Cmd tool we can persist posix file attributes during `sync` process, but actually with some limitations. The s3cmd sync command checks file dimension and MD5 hash value in order to know if a file is changed or not. So if only the file attributes changes the file will not be updated to S3 bucket. The s3cmd `put` command is not affected by this lack and will ever set permissions correctly.

There is an Issue opened to S3Cmd project to find a way to sync files on file attributes changing, but it is not yet resolved. Waiting the Issue will be solved, the script defaults force a `put` as backup shutdown strategy, to ensure all permissions will be backed up correctly. If you don't care it, you could set `sync` as final backup strategy.

You can find Issue on S3Cmd repository here: [https://github.com/s3tools/s3cmd/issues/1280](https://github.com/s3tools/s3cmd/issues/1280)

## Contributing

You could contribute to project as you like.

You could open issue when you want to propose a feature, a fix, report a bug or anythink else!

When you report a bug I ask you to include into Issue:
1. What is the bug you found
2. When your bug appears
3. How to build a replicable test case

You're welcome to implement features too:
1. Fork it!
2. Create your feature branch: `git checkout -b my-new-feature`
3. Commit your changes: `git commit -am 'Add some feature'`
4. Push to the branch: `git push origin my-new-feature`
5. Submit a pull request :D

## Credits

- **elementar/docker-s3-volume**: a docker image to sync volumes to s3 using the aws cli [https://github.com/elementar/docker-s3-volume]
- **crummy/docker-s3-volume** merge request on *elementar/docker-s3-volume*: it allow **docker-s3-volume** container to signal when volume is ready by using healtcheck
- **xescure/docker-s3-volume** merge request on *elementar/docker-s3-volume*: it allow to public automatically image to docker hub after commit, using workflow
- **S3Cmd**: a tool to better sync files versus S3 [https://s3tools.org/s3cmd] [https://github.com/s3tools/s3cmd]


## License

This repository is released under the MIT license:

* https://opensource.org/licenses/MIT
