# Community Hass.io Add-ons: Build Environment

![Project Stage][project-stage-shield]
![Maintenance][maintenance-shield]
![Awesome][awesome-shield]
[![License][license-shield]](LICENSE.md)

[![Docker Version][version-shield]][microbadger]
[![Docker Layers][layers-shield]][microbadger]
[![Docker Pulls][pulls-shield]][dockerhub]
[![Code Climate][codeclimate-shield]][codeclimate]
[![CircleCI][circleci-shield]][circleci]

This is a build environment for building Hass.io Docker images and is
capable of building Docker images for multiple architectures.

Note: _This build environment is **HIGHLY EXPERIMENTAL**! It still needs
a lot of testing, and the documentation is far from complete. Use at your
own risk!_

## Usage

The whole build environment is based on Docker and is placed into
a single Docker image. This makes this version portable and removes the
need for "large" and complicated Bash scripts (as provided by Home Assistant).

```bash
docker run --rm --privileged \
    -v ~/.docker:/root/.docker \
    -v "$(pwd)":/docker \
    hassioaddons/build-env:latest \
    [options]
```

Adding `-v ~/.docker:/root/.docker` shares your Docker hub credentials with
the built environment. This line may be omitted in case you don't want to
push your image.

Adding `-v "$(pwd)":/docker` shares your current working directory as the
directory to start the build process from. This line MUST be omitted in case
you are building from a remote repository.

The `[options]` can be replaced by one or more of the following options:

```txt
Options:

    -h, --help
        Display this help and exit.

    -t, --target <directory>
        The target directory containing the Dockerfile to build.
        Defaults to the current working directory (.).

    -r, --repository <url>
        Build using a remote repository.
        Note: use --target to specify a subdirectory within the repository.

    -b, --branch <name>
        When using a remote repository, build this branch.
        Defaults to master.

    ------ Build Architectures ------

    --aarch64
        Build for aarch64 (arm 64 bits) architecture.

    --amd64
        Build for amd64 (intel/amd 64 bits) architecture.

    --armhf
        Build for armhf (arm 32 bits) architecture.

    --i386
        Build for i386 (intel/amd 32 bits) architecture.

    -a, --all
        Build for all architectures.
        Same as --aarch64 --amd64 --armhf --i386.
        If a limited set of supported architectures is defined in
        a configuration file, that list is still honored when using
        this flag.

    ------ Build base images ------

    These build options will override any value in your 'build.json' file.

    --aarch64-from <image>
        Use a custom base image when building for aarch64.
        e.g. --aarch64-image "homeassistant/aarch64-base".
        Note: This overrides the --from flag for this architecture.

    --amd64-from <image>
        Use a custom base image when building for amd64.
        e.g. --amd64-image "homeassistant/amd64-base".
        Note: This overrides the --from flag for this architecture.

    --armhf-from <image>
        Use a custom base image when building for armhf.
        e.g. --armhf-image "homeassistant/armhf-base".
        Note: This overrides the --from flag for this architecture.

    --i386-from <image>
        Use a custom base image when building for i386.
        e.g. --i386-image "homeassistant/i386-image".
        Note: This overrides the --from flag for this architecture.

    -f, --from <image>
        Use a custom base image when building.
        Use '{arch}' as a placeholder for the architecture name.
        e.g., --from "homeassistant/{arch}-base"

    ------ Build output ------

    -i, --image <image>
        Specify a name for the output image.
        In case of building an add-on, this will override the name
        as set in the add-on configuration file. Use '{arch}' as an
        placeholder for the architecture name.
        e.g., --image "myname/{arch}-myaddon"

    -l, --tag-latest
        Tag Docker build as latest.
        Note: This is automatically done when on the latest Git tag AND
              using the --git flag.

    --tag-test
        Tag Docker build as test.
        Note: This is automatically done when using the --git flag.

    -p, --push
        Upload the resulting build to Docker hub.

    ------ Build options ------

    --arg <key> <value>
        Pass additional build arguments into the Docker build.
        This option can be repeated for multiple key/value pairs.

    --cache-tag <tag>
        Specify the tag to use as cache image version.
        Defaults to 'latest'.

    -c, --no-cache
        Disable build from cache.

    --parallel
        Parallelize builds. Build all requested architectures in parallel.
        While this speeds up the process tremendously, it is, however, more
        prone to errors caused by system resources.

    --squash
        Squash the layers of the resulting image to the parent image, and
        still allows for base image reuse. Use with care; you can not use the
        image for caching after squashing!
        Note: This feature is still marked "Experimental" by Docker.

    ------ Build meta data ------

    -g, --git
        Use Git for version tags instead of the add-on configuration file.
        It also manages 'latest' and 'test' tags.
        Note: This will ONLY work when your Git repository only contains
              a single add-on or other Docker container!

    -n, --name <name>
        Name or title of the thing that is being built.

    -d, --description <description>
        Description of the thing that is being built.

    --vendor <vendor>
        The name of the vendor providing the thing that is being built.

    -m, --maintainer, --author <author>
        Name of the maintainer. MUST be in "My Name <email@example.com>" format.
        e.g., "Franck Nijhof <frenck@addons.community>"

    -u, --url <ur>
        URL to the homepage of the thing that is built.
        Note: When building add-ons; this will override the setting from
              the configuration file.

    -c, --doc-url <url>
        URL to the documentation of the thing that is built.
        When omitted, the value of --url will be used.

    --git-url <url>
        The URL to the Git repository (e.g., GitHub).
        When omitted, the value is detected using Git or the add-on url
        configuration value will be used.

    -o, --override
        Always override Docker labels.
        The normal behavior of the builder is to only add a label when it is
        not found in the Dockerfile. This flag enforces to override all label
        values.

```

## Examples

### Building a local add-on

The following example will build a local add-on and push it onto Docker hub.

```bash
docker run --rm --privileged \
    -v ~/.docker:/root/.docker \
    -v "$(pwd)":/docker \
    hassioaddons/build-env:latest \
    --target addon-slug \
    --tag-latest \
    --push \
    --all
```

### Building from a remote GitHub repository

The following example will build the `example` add-on. It will build it for
all architectures supported by that add-on.

```bash
docker run -it --rm --privileged --name build \
    hassioaddons/build-env:latest \
    --repository https://github.com/hassio-addons/addon-example \
    --target example \
    --git \
    --all
```

## Changelog

This repository keeps a [change log](CHANGELOG.md) and adhere to
[Semantic Versioning][semver]. The format of the log is based
on [Keep a Changelog][keepchangelog].

## Support

Got questions?

You have several options to get them answered:

- The Home Assistant [Community Forums][forums], we have a
  [dedicated topic][forums] on that forum regarding this repository.
- The Home Assistant [Discord Chat Server][discord] for general Home Assistant
  discussions and questions.
- Join the [Reddit subreddit][reddit] in [/r/homeassistant][reddit]

You could also [open an issue here][issue] GitHub.

## Contributing

This is an active open-source project. We are always open to people who want to
use the code or contribute to it.

We've set up a separate document for our [contribution guidelines](CONTRIBUTING.md).

Thank you for being involved! :heart_eyes:

## Authors & contributors

The original setup of this repository is by [Franck Nijhof][frenck].

For a full list of all authors and contributors,
check [the contributor's page][contributors].

## We've got some Hass.io add-ons for you

Want some more functionality to your Hass.io Home Assistant instance?

We have created multiple add-ons for Hass.io. For a full list, check out
our [GitHub Repository][repository].

## License

MIT License

Copyright (c) 2017 Franck Nijhof

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

[awesome-shield]: https://img.shields.io/badge/awesome%3F-yes-brightgreen.svg
[circleci-shield]: https://img.shields.io/circleci/project/github/hassio-addons/build-env.svg
[circleci]: https://circleci.com/gh/hassio-addons/build-env
[codeclimate-shield]: https://img.shields.io/codeclimate/github/hassio-addons/build-env.svg
[codeclimate]: https://codeclimate.com/github/hassio-addons/build-env
[contributors]: https://github.com/hassio-addons/build-env/graphs/contributors
[discord]: https://discord.gg/c5DvZ4e
[dockerhub]: https://hub.docker.com/r/hassioaddons/build-env
[forums]: https://community.home-assistant.io/t/repository-community-hass-io-add-ons/24705?u=frenck
[frenck]: https://github.com/frenck
[issue]: https://github.com/hassio-addons/build-env/issues
[keepchangelog]: http://keepachangelog.com/en/1.0.0/
[layers-shield]: https://images.microbadger.com/badges/image/hassioaddons/build-env.svg
[license-shield]: https://img.shields.io/github/license/hassio-addons/build-env.svg
[maintenance-shield]: https://img.shields.io/maintenance/yes/2017.svg
[microbadger]: https://microbadger.com/images/hassioaddons/build-env
[project-stage-shield]: https://img.shields.io/badge/Project%20Stage-Experimental-yellow.svg
[pulls-shield]: https://img.shields.io/docker/pulls/hassioaddons/build-env.svg
[reddit]: https://reddit.com/r/homeassistant
[repository]: https://github.com/hassio-addons/repository
[semver]: http://semver.org/spec/v2.0.0.html
[version-shield]: https://images.microbadger.com/badges/version/hassioaddons/build-env.svg
