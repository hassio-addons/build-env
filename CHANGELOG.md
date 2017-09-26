# Changelog Community Hass.io Add-ons: Build Environment

All notable changes to this add-on will be documented in this file.

The format is based on [Keep a Changelog][keep-a-changelog]
and this project adheres to [Semantic Versioning][semantic-versioning].

## Unreleased

No unreleased changes yet.

## [v0.3.4][v0.3.4] (2017-09-26)

[Full Changelog][v0.3.3-v0.3.4]

### Removed

- Removed Git master branch detection. [#35][35]

## [v0.3.3][v0.3.3] (2017-09-26)

[Full Changelog][v0.3.2-v0.3.3]

### Changed

- Updated examples in README [#34][34]

### Fixed

- Fixes issue with pushing images to Docker Hub [#34][34]
- Fixes setting default squash state, in case of a missing build.json [#34][34]
- Fixes unbound variable error when building without a build.json file [#34][34]

## [v0.3.2][v0.3.2] (2017-09-26)

[Full Changelog][v0.3.1-v0.3.2]

### Fixed

- Fixed squash, true/false mixup [#33][33]

## [v0.3.1][v0.3.1] (2017-09-26)

[Full Changelog][v0.3.0-v0.3.1]

### Fixed

- Fixes unbound variable error [#32][32]

## [v0.3.0][v0.3.0] (2017-09-26)

[Full Changelog][v0.2.1-v0.3.0]

### Added

- Automatically disable caching when using squash [#31][31]

### Changed

- Changed squash option to be disabled by default [#31][31]
- Changed parallel build option to be disabled by default [#31][31]

## [v0.2.1][v0.2.1] (2017-09-24)

[Full Changelog][v0.2.0-v0.2.1]

### Changed

- Moved buildscript into a better place [#29][29]

### Fixed

- Issue with CircleCI missing releases [#28][28]

## [v0.2.0][v0.2.0] (2017-09-24)

[Full Changelog][v0.1.1-v0.2.0]

### Added

- Reverted most of the changes in v0.1.0 [#27][27]
- Correct handling for failing background jobs [#27][27]

### Changed

- Improved Git logic [#27][27]

### Removed

- Removed support for other build types [#27][27]
- Removed backward compatibility Hassio 0.63 and lower [#27][27]

## [v0.1.1][v0.1.1] (2017-09-24)

[Full Changelog][v0.1.0-v0.1.1]

### Removed

- Removes privileged check [#25][25]

## [v0.1.0][v0.1.0] (2017-09-24)

[Full Changelog][v0.0.8-v0.1.0]

### Changed

- Simplification of the build enviroment [#23][23]

## [v0.0.8][v0.0.8] (2017-09-23)

[Full Changelog][v0.0.7-v0.0.8]

### Added

- Hass.io 0.64 compatibility [#21][21]

### Fixed

- Issues with non-parallel building [#20][20]

## Removed

- Removed support for suggested `hassio.json` file [#21][21]

## [v0.0.7][v0.0.7] (2017-09-21)

[Full Changelog][v0.0.6-v0.0.7]

### Fixed

- Fixes CircleCI when building on a release [#18][18]

## [v0.0.6][v0.0.6] (2017-09-21)

[Full Changelog][v0.0.5-v0.0.6]

### Added

- Added support for additional Docker build arguments [#15][15]

### Changed

- CicleCI deploy on release [#16][16]

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
[15]: https://github.com/hassio-addons/build-env/pull/15
[16]: https://github.com/hassio-addons/build-env/pull/16
[18]: https://github.com/hassio-addons/build-env/pull/18
[2]: https://github.com/hassio-addons/build-env/pull/2
[20]: https://github.com/hassio-addons/build-env/pull/20
[21]: https://github.com/hassio-addons/build-env/pull/21
[23]: https://github.com/hassio-addons/build-env/pull/23
[25]: https://github.com/hassio-addons/build-env/pull/25
[27]: https://github.com/hassio-addons/build-env/pull/27
[28]: https://github.com/hassio-addons/build-env/pull/28
[29]: https://github.com/hassio-addons/build-env/pull/29
[3]: https://github.com/hassio-addons/build-env/pull/3
[31]: https://github.com/hassio-addons/build-env/pull/31
[32]: https://github.com/hassio-addons/build-env/pull/32
[33]: https://github.com/hassio-addons/build-env/pull/33
[34]: https://github.com/hassio-addons/build-env/pull/34
[35]: https://github.com/hassio-addons/build-env/pull/35
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
[v0.0.5-v0.0.6]: https://github.com/hassio-addons/build-env/compare/v0.0.5...v0.0.6
[v0.0.5]: https://github.com/hassio-addons/build-env/tree/v0.0.5
[v0.0.6-v0.0.7]: https://github.com/hassio-addons/build-env/compare/v0.0.6...v0.0.7
[v0.0.6]: https://github.com/hassio-addons/build-env/tree/v0.0.6
[v0.0.7-v0.0.8]: https://github.com/hassio-addons/build-env/compare/v0.0.7...v0.0.8
[v0.0.7]: https://github.com/hassio-addons/build-env/tree/v0.0.7
[v0.0.8-v0.1.0]: https://github.com/hassio-addons/build-env/compare/v0.0.8...v0.1.0
[v0.0.8]: https://github.com/hassio-addons/build-env/tree/v0.0.8
[v0.1.0-v0.1.1]: https://github.com/hassio-addons/build-env/compare/v0.1.0...v0.1.1
[v0.1.0]: https://github.com/hassio-addons/build-env/tree/v0.1.0
[v0.1.1-v0.2.0]: https://github.com/hassio-addons/build-env/compare/v0.1.1...v0.2.0
[v0.1.1]: https://github.com/hassio-addons/build-env/tree/v0.1.1
[v0.2.0-v0.2.1]: https://github.com/hassio-addons/build-env/compare/v0.2.0...v0.2.1
[v0.2.0]: https://github.com/hassio-addons/build-env/tree/v0.2.0
[v0.2.1-v0.3.0]: https://github.com/hassio-addons/build-env/compare/v0.2.1...v0.3.0
[v0.2.1]: https://github.com/hassio-addons/build-env/tree/v0.2.1
[v0.3.0-v0.3.1]: https://github.com/hassio-addons/build-env/compare/v0.3.0...v0.3.1
[v0.3.0]: https://github.com/hassio-addons/build-env/tree/v0.3.0
[v0.3.1-v0.3.2]: https://github.com/hassio-addons/build-env/compare/v0.3.1...v0.3.2
[v0.3.1]: https://github.com/hassio-addons/build-env/tree/v0.3.1
[v0.3.2-v0.3.3]: https://github.com/hassio-addons/build-env/compare/v0.3.2...v0.3.3
[v0.3.2]: https://github.com/hassio-addons/build-env/tree/v0.3.2
[v0.3.3-v0.3.4]: https://github.com/hassio-addons/build-env/compare/v0.3.3...v0.3.4
[v0.3.3]: https://github.com/hassio-addons/build-env/tree/v0.3.3
[v0.3.4]: https://github.com/hassio-addons/build-env/tree/v0.3.4
