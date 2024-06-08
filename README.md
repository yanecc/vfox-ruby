# vfox-ruby

[Ruby](https://www.ruby-lang.org/) language plugin for [vfox](https://vfox.lhan.me).

For Linux and macos, both [Ruby(conda-forge)](https://github.com/conda-forge/ruby-feedstock) and [TruffleRuby](https://www.graalvm.org/ruby/) are provided.

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
  
- **Why is there a lack of updated versions?**<br>
To minimize the working requirements, vfox-ruby currently uses precompiled packages from conda-forge on Linux and macOS. You could open an issue in the [ruby-feedstock](https://github.com/conda-forge/ruby-feedstock/issues) repository to remind the maintainers to provide the latest build. Once the latest version is available, the plugin will be updated soon.

- **Are there any dependencies required to use this plugin?**<br>
On Windows, vfox-ruby uses standalone 7-ZIP archives provided by [RubyInstaller](https://github.com/oneclick/rubyinstaller2/wiki/faq). On Linux and macOS, installing Ruby requires no dependencies other than the built-in commands. Installing TruffleRuby requires `bash`, `make`, `gcc`, `g++` and `zlib-dev`. For more details, refer to the [dependencies](https://github.com/oracle/truffleruby/blob/master/README.md#Dependencies) section.