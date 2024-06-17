require "json"
require "http/client"

def getLatestVersion(url)
  response = HTTP::Client.get url
  latestRelease = response.headers["Location"]
  latestVersion = latestRelease[/(\d[\.\d]+)/]
end

# old version list
def fetchVersionList
  response = HTTP::Client.get "https://github.com/yanecc/vfox-ruby/releases/manifest"
  versionJson = response.body.match!(/<code>([\s\S]+)<\/code>/)[1]
  versionList = Hash(String, Array(String)).from_json versionJson
end

def fetchJRubyVersions
  response = HTTP::Client.get "https://www.jruby.org/files/downloads/index.html"
  versionList = response.body.scan(/(9\.(2\.2\d|3\.1\d|[4-9]\.\d+)\.\d)<\/a>/).map { |m| m[1] }
  versionList.reverse + ["9.1.17.0", "9.1.16.0"]
end

def compareVersions(a, b)
  a = a.split(".").map { |v| v.to_i }
  b = b.split(".").map { |v| v.to_i }
  a.each_with_index do |v, i|
    if v != b[i]
      return v <=> b[i]
    end
  end
  0
end

latestTruffleRuby = getLatestVersion "https://github.com/oracle/truffleruby/releases/latest"
latestHomebrewRuby = getLatestVersion "https://github.com/Homebrew/homebrew-portable-ruby/releases/latest"
versionList = fetchVersionList
rubyVersions = versionList["ruby"]
jrubyVersions = versionList["jruby"]
condaForgeVersions = versionList["conda-forge"]
truffleVersions = versionList["truffleruby"]
truffleJVMVersions = versionList["truffleruby-jvm"]
homebrewVersions = versionList["homebrew"]

isUpdated = true
if rubyVersions[0] != latestHomebrewRuby
  isUpdated = false
  homebrewVersions.insert(0, latestHomebrewRuby)
end

if jrubyVersions != fetchJRubyVersions
  isUpdated = false
  jrubyVersions = fetchJRubyVersions
end

if truffleVersions[0] != latestTruffleRuby
  isUpdated = false
  truffleVersions.insert(0, latestTruffleRuby)
  truffleJVMVersions.insert(0, latestTruffleRuby + ".jvm")
end

unless isUpdated
  rubyVersions = homebrewVersions + condaForgeVersions
  rubyVersions.sort! { |a, b| compareVersions(b, a) }
  rubyVersions = rubyVersions + truffleVersions + truffleJVMVersions
  # 将版本列表写入文件
  File.write("versions.json", {
    "ruby"            => rubyVersions,
    "homebrew"        => homebrewVersions,
    "conda-forge"     => condaForgeVersions,
    "jruby"           => jrubyVersions,
    "truffleruby"     => truffleVersions,
    "truffleruby-jvm" => truffleJVMVersions,
  }.to_pretty_json indent = "    ")
end
