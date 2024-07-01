require "http/client"
require "json"
require "option_parser"

record RBFile, name : String do
  include JSON::Serializable
end

def fetchRubyBuildVersions
  response = HTTP::Client.get "https://api.github.com/repos/rbenv/ruby-build/contents/share/ruby-build"
  fileList = Array(RBFile).from_json response.body
  versionList = fileList.map &.name
  versionList.select! &.match_full /[1-3]\.\d\.\d-?\w*|mruby-\d\.\d\.\d/
  mrubyList, rubyList = versionList.partition &.starts_with? "mruby-"
  rubyList.map! { |version| version + ".rb" }
  mrubyList.map! { |version| version.split("-").last + ".mrb" }
  versionList = rubyList.reverse + mrubyList.reverse
end

def getLatestVersion(url)
  response = HTTP::Client.get url
  latestRelease = response.headers["Location"]
  latestVersion = latestRelease[/\d[\.\d]+/]
end

def fetchVersionList
  response = HTTP::Client.get "https://github.com/yanecc/vfox-ruby/releases/manifest"
  versionJson = response.body.match!(/<code>([\s\S]+)<\/code>/)[1]
  versionList = Hash(String, Array(String)).from_json versionJson
end

def fetchJRubyVersions
  response = HTTP::Client.get "https://www.jruby.org/files/downloads/index.html"
  versionList = response.body.scan(/(9\.(1\.1[6-9]|2\.2\d|3\.1\d|[4-9]\.\d+)\.\d)<\/a>/).map { |m| m[1] }
  versionList.reverse
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
vlist = fetchVersionList

output = "manifest.md"

OptionParser.parse do |parser|
  parser.banner = "Usage: #{Path[Process.executable_path.not_nil!].stem} [options]"
  parser.on("-o PATH", "--output PATH", "Specify the output path") { |path| output = path }
  parser.on("-h", "--help", "Show this help") do
    puts parser
    exit
  end
  parser.invalid_option do |flag|
    STDERR.puts "ERROR: #{flag} is not a valid option."
    STDERR.puts parser
    exit(1)
  end
end

isUpdated = true
if vlist["ruby"][0] != latestHomebrewRuby
  isUpdated = false
  vlist["homebrew"].unshift(latestHomebrewRuby)
  puts "Homebrew Ruby has an updated version: #{latestHomebrewRuby}"
end

if vlist["truffleruby"][0] != latestTruffleRuby
  isUpdated = false
  vlist["truffleruby"].unshift(latestTruffleRuby)
  vlist["truffleruby-jvm"].unshift(latestTruffleRuby + ".jvm")
  puts "TruffleRuby has an updated version: #{latestTruffleRuby}"
end

if vlist["jruby"] != (jrubyVersions = fetchJRubyVersions)
  isUpdated = false
  vlist["jruby"] = jrubyVersions
  puts "JRuby version list is updated"
end

if vlist["ruby-build"] != (rbVersions = fetchRubyBuildVersions)
  isUpdated = false
  vlist["ruby-build"] = rbVersions
  puts "Ruby-build version list is updated"
end

unless isUpdated
  vlist["ruby"] = vlist["homebrew"] + vlist["conda-forge"]
  vlist["ruby"].sort! { |a, b| compareVersions(b, a) }
  vlist["ruby"] = vlist["ruby"] + vlist["truffleruby"] + vlist["truffleruby-jvm"]
  File.open(output, "a") do |file|
    file.puts "```"
    file.puts vlist.to_pretty_json(indent = "    ")
    file.puts "```"
  end
end
