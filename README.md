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
           nardsit/docker-s3cmd-sync /data/ s3://mybucket/someprefix
```

This will download the data from the S3 location you specify into the
container's `/data` directory. When the container shuts down, the data will be
synced back to S3.

### Configuring a sync interval

When the `BACKUP_INTERVAL` environment variable is set, a watcher process will
sync the `/data` directory to S3 on the interval you specify. The interval can
be specified in seconds, minutes, hours or days (adding `s`, `m`, `h` or `d` as
the suffix):

```bash
docker run -d --name my-data-container -e BACKUP_INTERVAL=2m \
           -v /home/user/.s3/.s3cfg:/root/.s3cfg \
           nardsit/docker-s3cmd-sync /data/ s3://mybucket/someprefix
```

A final put will always be performed on container shutdown, to reupload all files. It could be a sync in the future (see [Posix file attributes persist during sync](#posix-file-attributes-persist-during-sync) section).

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
    image: nardsit/docker-s3cmd-sync
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

Using S3Cmd tool we can persist posix file attributes during sync process, but actually with some limitations. The s3cmd sync command checks file dimension and MD5 hash value in order to know if a file is changed or not. So if only the file attributes changes the file will not be updated to S3 bucket.

There is an Issue opened to S3Cmd project to find a way to sync files on file attributes changing, but it is not yet resolver. Now you can force a put to all bucket to recover 

You can find Issue on S3Cmd repository here: [https://github.com/s3tools/s3cmd/issues/1280](https://github.com/s3tools/s3cmd/issues/1280)

### Temporarily strategy on final sync

The environment variable `S3CMD_FINAL_STRATEGY` could be temporarily used to force the last sync strategy to:
- `PUT` (default) as the secure option to upload again all files
- `SYNC` to sync only identificable changed files

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
