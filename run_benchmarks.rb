#!/usr/bin/env ruby

require 'fileutils'
require 'open3'
require 'shellwords'

# Checks if other users are logged into the current computer,
# as defined by "ps haeo user".
def other_users_online()
  userlist = `ps haeo user | sort -u`.split("\n")
  userlist -= userlist.grep(/s0840449|root/)
  not userlist.empty?
end

# Executes a unix command and times its execution
# using /usr/bin/time. Returns the real time,
# user time, and system time, stored in a hashmap
# of type => time in milliseconds.
#
# Raises an exception if the command returns with a
# non-zero status code.
def time_command(unix_command)
  stdout, stderr, status = Open3.capture3("time #{unix_command} 2> /dev/null")
  raise "Command returned non-zero status code" if status != 0

  results = {}
  stderr.split("\n").each do |line|
    unless line.strip.empty?
      type,value = line.split("\t")
      minutes,seconds = value.split("m")
      milliseconds = minutes.to_f * 60 * 1000 + seconds.chomp("s").to_f * 1000
      results[type] = milliseconds
    end
  end

  return results
end

# Helper to wrap log output. Output is just sent to STDOUT - it is
# up to the runner to redirect it to a file if necessary (e.g.
# 'ruby run_benchmarks | tee log.txt'
def log(output)
  the_time = Time.now.strftime("%Y-%m-%d %H:%M:%S")
  puts "#{the_time}: #{output}"
end

if ARGV.length < 1
  abort 'Usage: ruby run_benchmarks.rb opt_file [recovery_file]'
end

if not File.directory?("spec")
  abort 'Error: cannot find "spec" directory'
end

# Load in the opts
opts = ['-O0', '-O1', '-O2', '-O3']
File.open(ARGV[0], "r").each do |line|
  opts.push line.chomp
end

# Load in the recovery file, if there is one.
recovered_lines = []
recovered_benchmarks = -1
recovered_opts = 0
if ARGV.length == 2
  File.open(ARGV[1], "r").each do |line|
    cleaned_line = line.chomp.strip
    line_parts = Shellwords.shellwords(line.chomp.strip)
    next if cleaned_line.empty?

    # Assume that benchmark lines dont start with ".
    if line_parts.length == 1 and not cleaned_line.start_with? '"'
      puts "Benchmark recovered: #{line}"
      recovered_benchmarks += 1
      recovered_opts = 0
    elsif line_parts.length == 11
      recovered_opts += 1
    else
      # Not fully written line.
      break
    end

    recovered_lines.push(line)
  end
end

# Temporary directories
proj_dir = Dir.pwd
copt_tmp = "/tmp/s0840449/copt"
FileUtils.mkdir_p(copt_tmp)

# Output file
output_file = File.open("output.txt", "w")

# Refill the recovered lines.
recovered_lines.each do |line|
  log "Recovering line #{line}"
  output_file.print(line)
end

benchmarks = Dir.entries("spec").sort
benchmarks.each do |benchmark|
  next if benchmark == "." or benchmark == ".."

  # Skip already complete benchmarks.
  if recovered_benchmarks > 0
    log "Skipping benchmark #{benchmark} - recovered from file"
    recovered_benchmarks -= 1
    next
  end

  log "Beginning benchmark #{benchmark}"
  # Partially recovered benchmarks will already have had their name
  # printed out.
  if recovered_benchmarks == 0
    recovered_benchmarks -= 1
  else
    output_file.puts benchmark
  end

  # Delete /tmp/s0840449/copt/#{benchmark} if it exists,
  # and copy the benchmark there.
  benchmark_tmp = copt_tmp + "/#{benchmark}"
  FileUtils.rm_r(benchmark_tmp) if File.directory?(benchmark_tmp)
  log "Copying over benchmark..."
  FileUtils.cp_r("spec/" + benchmark, benchmark_tmp, {:preserve => true})
  log "Finished copying."

  # Move into the tmp folder.
  Dir.chdir(benchmark_tmp)

  # Run each benchmark.
  opts.each_with_index do |opt_set, i|

    # Skip already complete opts.
    if recovered_opts > 0
      log "Skipping opt set #{i}: \"#{opt_set}\""
      recovered_opts -= 1
      next
    end

    log "Running opt set #{i}: \"#{opt_set}\""
    output_file.print "\"#{opt_set}\""

    # Compile the code.
    log "Compiling benchmark with opts..."
    before = Time.now
    Dir.chdir("src")
    make_output = `make CFLAGS="#{opt_set}" 2>/dev/null`
    abort "Unable to make #{benchmark} with opts: \"#{opt_set}\"" if $? != 0
    log "Benchmark compiled. (#{((Time.now - before) * 1000).to_i}ms)."

    Dir.chdir(benchmark_tmp)

    # Run the benchmarks!
    10.times do |i|
      # Check for other users being online.
      log "Checking for other users online."
      while other_users_online
        the_time = Time.now.to_s
        log "#{the_time}\tWarning: Other user detected while running " +
            "benchmark #{benchmark}, optimisation set #{i}. Sleeping 5 mins.\n"
        sleep(300)
        log "Sleep-time is over!"
      end
      log "No other users online."

      # Now run the benchmark.
      log "Beginning run #{i}."
      results = time_command('./run.sh')
      # TODO: Record sys/user time?
      output_file.print("\t%.0f" % results['real'])
      log "Run #{i} finished."
    end
    output_file.print "\n"
    output_file.flush
  end

  # Cleanup!
  FileUtils.rm_r(benchmark_tmp)
  Dir.chdir(proj_dir)

  # Lets not lose our ticket...
  system "kinit -R"
end

output_file.close
