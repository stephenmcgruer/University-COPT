#!/usr/bin/env ruby

require 'shellwords'

class BenchmarkInfo
  attr_accessor :standard_opts, :other_opts

  def initialize
    @standard_opts = []
    @other_opts = []
  end

  def normalize!
    # Calc the mean of -O1
    sum = @standard_opts[1].inject { |sum, x| sum += x }
    mean = sum.to_f / @standard_opts[1].length

    # Now divide everything by it.
    @standard_opts.each do |opt_set|
      opt_set.map! { |x| x /= mean }
    end
    
    @other_opts.each do |opt_set|
      opt_set.map! { |x| x /= mean }
    end
  end

  def process_standard_opts
    results = []
    @standard_opts.each do |opts|
      mean = opts.inject { |sum, x| sum += x } / opts.length.to_f
      var = opts.inject { |sum, x| sum += (x - mean)**2 } / opts.length.to_f
      #std_dev = var**0.5

      results << [mean, var]#std_dev]
    end

    return results
  end

  # Return the mean and std_dev of the fastest optimization.
  def get_fastest
    means = []
    @other_opts.each do |opt_times|
      means << opt_times.inject { |sum, x| sum += x } / opt_times.length.to_f
    end
   
    fastest_mean = means.min
    fastest_index = means.index(fastest_mean)

    # Now calc the standard deviation.
    fastest = @other_opts[fastest_index]
    #fastest_std_dev = (fastest.inject { |sum, x| sum += (x - fastest_mean)**2 } / fastest.length.to_f)**0.5
    fastest_var = (fastest.inject { |sum, x| sum += (x - fastest_mean)**2 } / fastest.length.to_f)

    return fastest_mean, fastest_var #fastest_std_dev
  end

  # Return the mean and std_dev of the average
  def get_average
    means = []
    @other_opts.each do |opt_times|
      means << opt_times.inject { |sum, x| sum += x} / opt_times.length.to_f
    end

    average = means.inject { |sum, x| sum += x } / means.length
    all_times = @other_opts.flatten

    #std_dev = (all_times.inject { |sum, x| sum += (x - average)**2 } / all_times.length.to_f)**0.5
    var = (all_times.inject { |sum, x| sum += (x - average)**2 } / all_times.length.to_f)

    return average, var #std_dev
  end
end

if ARGV.length != 1
  abort 'Usage: ruby process_output.rb output_file'
end

benchmarks = {}
current_benchmark = ""

File.open(ARGV[0], "r").each do |line|
  cleaned_line = line.chomp.strip
  line_parts = Shellwords.shellwords(line.chomp.strip)
  next if cleaned_line.empty?

  # Assume that benchmark lines dont start with ".
  if line_parts.length == 1 and not cleaned_line.start_with? '"'
    current_benchmark = cleaned_line
    benchmarks[current_benchmark] = BenchmarkInfo.new
  elsif line_parts.length == 11
    times = line_parts[1..-1].map { |x| x.to_i }

    if line_parts[0].match(/-O[0-3]$/)
      benchmarks[current_benchmark].standard_opts << times
    else
      benchmarks[current_benchmark].other_opts << times
    end
  else
    # Not fully written line.
    puts "ERROR: Line: '#{cleaned_line}' cannot be parsed."
    exit 1
  end
end

benchmarks.each do |benchmark, benchmark_info|
  # Write to files.
  File.open("data/#{benchmark}.data", "w") do |file|
    standard_opt_info = benchmark_info.process_standard_opts
    standard_opt_info.each do |standard_opt|
      file.puts standard_opt[0].to_s + " " + standard_opt[1].to_s
    end

    fastest = benchmark_info.get_fastest
    average = benchmark_info.get_average

    file.puts fastest[0].to_s + " " + fastest[1].to_s
    file.puts average[0].to_s + " " + average[1].to_s
  end
end

standard_opts = [[], [], [], []]
other_opts = []
200.times do
  other_opts << []
end
benchmarks.each do |benchmark, benchmark_info|
  standard_opts.each_index do |i|
    standard_opts[i] << benchmark_info.standard_opts[i][0]
  end

  other_opts.each_index do |i|
    other_opts[i] << benchmark_info.other_opts[i]
  end
end

averages = BenchmarkInfo.new
other_opts.each do |opts|
  opts.flatten!
  averages.other_opts << opts
end

File.open("data/averages.data", "w") do |file|
  standard_opts.each do |opts|
    mean = opts.inject { |sum, x| sum += x } / opts.length.to_f
    file.puts mean.to_s + " 0"
  end

  fastest = averages.get_fastest
  average = averages.get_average

  file.puts fastest[0].to_s + " 0"
  file.puts average[0].to_s + " 0"
end
