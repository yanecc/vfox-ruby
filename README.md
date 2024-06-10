# vfox-ruby

[Ruby](https://www.ruby-lang.org/) language plugin for [vfox](https://vfox.lhan.me).

## Requirement

|   Branch    |                Dependencies                 |
| :---------: | :-----------------------------------------: |
|    Ruby     |                    none                     |
|    JRuby    |              JRE v8 or higher               |
| TruffleRuby | `bash`, `make`, `gcc`, `g++` and `zlib-dev` |

## Install

After installing [vfox](https://github.com/version-fox/vfox), install the plugin by running:

``` shell
vfox add ruby
```

Next, search and select the version to install. By default, vfox keeps cache for available versions, use `--no-cache` flag to search without cache and rebuild the cache.

``` shell
vfox search ruby
vfox search ruby --no-cache
```

Install the latest stable version with `latest` tag.

``` shell
vfox install ruby@latest
vfox install ruby@9.4.5.0    # JRuby
vfox install ruby@24.0.1     # TruffleRuby
vfox install ruby@24.0.1.jvm # TruffleRuby-jvm
```

Some environment variables are served as following:

| Environment variables | Default value         | Description         |
| :-------------------- | :-------------------- | :------------------ |
| Conda_Forge           | `conda-forge`         | conda-forge channel |
| GITHUB_URL            | `https://github.com/` | GitHub mirror URL   |

Note: `Conda_Forge` has no effect for Windows.

Usage:

``` shell
export Conda_Forge=https://prefix.dev/conda-forge
export GITHUB_URL=https://mirror.ghproxy.com/https://github.com/
```

## FAQ
  
- **Why is there a lack of updated versions?** <br>
Currently, vfox-ruby uses precompiled packages from conda-forge and Homebrew on Linux and macOS. You could open an issue in the [ruby-feedstock](https://github.com/conda-forge/ruby-feedstock) repository to remind the maintainers to provide the latest build. Once the latest version is available, the plugin will be updated soon.