# Duckpunch Array to have a random_subset method.
class Array
  # Returns an array of 'n' random subsets.
  def random_subset(n=1)
    raise ArgumentError, "Negative Argument" if n < 0
    (1..n).map do
      r = rand(2**self.size)
      self.select.with_index { |el, i| r[i] == 1 }
    end
  end
end

num_opt_sets = 200

o2_opts = ['-fthread-jumps', '-falign-functions',  '-falign-jumps',
           '-falign-loops', '-falign-labels', '-fcaller-saves',
           '-fcrossjumping', '-fcse-follow-jumps', '-fcse-skip-blocks',
           '-fdelete-null-pointer-checks', '-fexpensive-optimizations',
           '-fgcse', '-fgcse-lm', '-findirect-inlining',
           '-foptimize-sibling-calls', '-fpeephole2', '-fregmove',
           '-freorder-blocks', '-freorder-functions', '-frerun-cse-after-loop',
           '-fsched-interblock', '-fsched-spec', '-fschedule-insns',
           '-fschedule-insns2', '-fstrict-aliasing', '-fstrict-overflow',
           '-ftree-switch-conversion', '-ftree-pre', '-ftree-vrp']

o3_opts = ['-finline-functions', '-funswitch-loops', '-fpredictive-commoning',
          '-fgcse-after-reload', '-ftree-vectorize', '-fipa-cp-clone']

funroll_loops = ['-funroll-loops']

# Use 10 random O2 optimizations.
all_opts = o2_opts.sample(10) + o3_opts + funroll_loops

# Generate num_opt_sets random (but unique) subsets of all_opts.
chosen_opt_sets = []
num_opt_sets.times do
  unique_set_found = false
  until unique_set_found do
    opts_set = all_opts.random_subset.flatten
    if opts_set.empty?
      puts "Warning: Empty set chosen. Discarded."
    elsif chosen_opt_sets.include? opts_set
      puts "Warning: Duplicate set chosen. Discarded."
    else
      unique_set_found = true
    end
  end
  chosen_opt_sets.push(opts_set)
end

# Run through and add in any necessary -max-unroll-times.
chosen_opt_sets.map! do |opt_set|
  if opt_set.include? '-funroll-loops'
    # max-unroll-times can be 2, 4, 8, 16, or 32.
    n = 2**(rand(5) + 1)
    opt_set.push("--param max-unroll-times=#{n}").sort
  else
    opt_set.sort
  end
end

# Debug info, check that the average is about right.
sum = 0.0
chosen_opt_sets.each do |opt_set|
  sum += opt_set.length
end
avg_len = sum / num_opt_sets
puts "Average Length: #{avg_len}"

# Finally, create the file.
File.open("opts.txt", "w") do |f|
  chosen_opt_sets.each do |opt|
    # Every opt has O1.
    f.write("-O1")
    opt.each do |flag|
      f.write(" ")
      f.write(flag)
    end
    f.write("\n")
  end
end
