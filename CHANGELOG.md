# Changelog Community Hass.io Add-ons: Build Environment

All notable changes to this add-on will be documented in this file.

The format is based on [Keep a Changelog][keep-a-changelog]
and this project adheres to [Semantic Versioning][semantic-versioning].

## Unreleased

### Added

- Added support for additional Docker build arguments

## [v0.0.5][v0.0.5] (2017-09-18)

[Full Changelog][v0.0.4-v0.0.5]

### Fixed

- Fixes issue with parsing ARG default values from Dockerfiles [#12][12]
- Fixes issues and typo's with docker cache warmup [#13][13]

## [v0.0.4][v0.0.4] (2017-09-17)

[Full Changelog][v0.0.3-v0.0.4]

### Added

- Continuous delivery via CircleCI [#8][8]
- Added to CircleCI dependencies [#9][9]
- Markdown linting via CodeClimate [#10][10]

### Fixed

- Several Markdown improvements [#10][10]

## [v0.0.3][v0.0.3] (2017-09-17)

[Full Changelog][v0.0.2-v0.0.3]

### Fixed

- Fixes GIT version tag detection issue [#6][6]

## [v0.0.2][v0.0.2] (2017-09-16)

[Full Changelog][v0.0.1-v0.0.2]

### Added

- CodeClimate to ensure code quality [#2][2]
- CircleCI as a continuous integration system [#3][3]

### Fixed

- Fixed error in one of the examples
- Some small Markdown fixes to the documentation
- Fixed a couple of possible unbound variables and defaults [#4][4]

## [v0.0.1] (2017-09-15)

### Added

- Initial version, first release.

[10]: https://github.com/hassio-addons/build-env/pull/10
[12]: https://github.com/hassio-addons/build-env/pull/12
[13]: https://github.com/hassio-addons/build-env/pull/13
[2]: https://github.com/hassio-addons/build-env/pull/2
[3]: https://github.com/hassio-addons/build-env/pull/3
[4]: https://github.com/hassio-addons/build-env/pull/4
[6]: https://github.com/hassio-addons/build-env/pull/6
[8]: https://github.com/hassio-addons/build-env/pull/8
[9]: https://github.com/hassio-addons/build-env/pull/9
[keep-a-changelog]: http://keepachangelog.com/en/1.0.0/
[semantic-versioning]: http://semver.org/spec/v2.0.0.html
[v0.0.1-v0.0.2]: https://github.com/hassio-addons/build-env/compare/v0.0.1...v0.0.2
[v0.0.1]: https://github.com/hassio-addons/build-env/tree/v0.0.1
[v0.0.2-v0.0.3]: https://github.com/hassio-addons/build-env/compare/v0.0.2...v0.0.3
[v0.0.2]: https://github.com/hassio-addons/build-env/tree/v0.0.2
[v0.0.3-v0.0.4]: https://github.com/hassio-addons/build-env/compare/v0.0.3...v0.0.4
[v0.0.3]: https://github.com/hassio-addons/build-env/tree/v0.0.3
[v0.0.4-v0.0.5]: https://github.com/hassio-addons/build-env/compare/v0.0.4...v0.0.5
[v0.0.4]: https://github.com/hassio-addons/build-env/tree/v0.0.4
[v0.0.5]: https://github.com/hassio-addons/build-env/tree/v0.0.5
