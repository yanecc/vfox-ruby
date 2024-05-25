# vfox-ruby

[Ruby](https://www.ruby-lang.org/) language plugin for [vfox](https://vfox.lhan.me).

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

Example:

``` shell
export Conda_Forge=https://prefix.dev/conda-forge
export GITHUB_URL=https://mirror.ghproxy.com/https://github.com/
```