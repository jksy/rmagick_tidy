# Shows how process RSS behaves when Magick::Image objects are left to Ruby's GC
# versus released by RmagickTidy.scope.
#
#   bundle exec ruby benchmark/memory.rb              # run both modes (each in its own process)
#   bundle exec ruby benchmark/memory.rb with_scope   # run a single mode
#   ITERATIONS=100 SIZE=4000 bundle exec ruby benchmark/memory.rb
#
# ENV:
#   ITERATIONS  number of read/resize loops           (default: 50)
#   SIZE        width/height of the source image, px  (default: 3000)
#   EVERY       print RSS every N iterations          (default: ITERATIONS / 10)

require "rbconfig"
require "tmpdir"
require "rmagick_tidy"

MODES = %w[without_scope with_scope].freeze
ITERATIONS = Integer(ENV.fetch("ITERATIONS", 50))
SIZE = Integer(ENV.fetch("SIZE", 3000))
EVERY = Integer(ENV.fetch("EVERY", [ITERATIONS / 10, 1].max))

# Resident set size in MB. Linux: /proc/self/status; elsewhere (macOS): ps.
def rss_mb
  status = "/proc/self/status"
  kb = if File.readable?(status)
         File.read(status)[/^VmRSS:\s+(\d+)/, 1].to_i
       else
         `ps -o rss= -p #{Process.pid}`.to_i
       end
  kb / 1024.0
end

# One unit of work: read the source image and resize it. Both images become
# garbage as soon as this returns.
def work(path)
  img = Magick::Image.read(path).first
  img.resize(SIZE / 2, SIZE / 2)
  nil
end

def report(label, megabytes)
  puts format("  %<label>-6s %<mb>8.1f MB", label: label, mb: megabytes)
end

def run(mode, path)
  puts "#{mode} (iterations=#{ITERATIONS}, size=#{SIZE}x#{SIZE})"
  report(0, rss_mb)
  peak = 0.0
  1.upto(ITERATIONS) do |i|
    mode == "with_scope" ? RmagickTidy.scope { work(path) } : work(path)
    peak = [peak, rss_mb].max
    report(i, rss_mb) if (i % EVERY).zero?
  end
  report("peak", peak)
end

def with_source_image
  Dir.mktmpdir do |dir|
    path = File.join(dir, "source.png")
    source = Magick::Image.read("gradient:red-blue") { |info| info.size = "#{SIZE}x#{SIZE}" }.first
    source.write(path)
    source.destroy!
    yield path
  end
end

mode = ARGV.first
if mode
  abort "unknown mode: #{mode} (expected one of: #{MODES.join(', ')})" unless MODES.include?(mode)
  with_source_image { |path| run(mode, path) }
else
  # Each mode gets a fresh process so one run's memory cannot affect the other.
  MODES.each { |m| system(RbConfig.ruby, __FILE__, m, exception: true) }
end
