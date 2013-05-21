datafiles = dir(fullfile('.', 'data', '*.data'));

num_benchmarks = size(datafiles, 1);

% Need the means and standard deviations for the -On sets, the
% fastest random set, and the average random set. Also need to keep
% all of the data, as we calculate the expectation at the end.
datas = cell(num_benchmarks);
names = cell(num_benchmarks);
standard_means = cell(num_benchmarks);
standard_stds = cell(num_benchmarks);

fastest_mean = cell(num_benchmarks);
fastest_std = cell(num_benchmarks);

average_mean = cell(num_benchmarks);
average_std = cell(num_benchmarks);

for i = 1 : num_benchmarks
    data = load(strcat('data/', datafiles(i).name))';
    datas{i} = data;
    
    name = regexp(datafiles(i).name, '\.', 'split');
    name = name(2);
    names{i} = name;
    
    standard_opts = data(:, 1:4);
    standard_means{i} = mean(standard_opts);
    standard_stds{i} = std(standard_opts);
    
    random_opts = data(:, 5:size(data,2));
    random_means = mean(random_opts);
    
    fastest_idx = find(random_means == min(random_means));
    fastest_vals = random_opts(:, fastest_idx);
    fastest_mean{i} = mean(fastest_vals);
    fastest_std{i} = std(fastest_vals);
    
    flattened_random = reshape(random_opts, 1, numel(random_opts));
    average_mean{i} = mean(flattened_random);
    average_std{i} = std(flattened_random);

    % The individual graphs.
    means = [standard_means{i}, fastest_mean{i}, average_mean{i}];
    stds = [standard_stds{i}, fastest_std{i}, average_std{i}];
    
    h = bar(means);
    set(h, 'facecolor', [0.3 0.3 1]);
    
    title_label = title(name);
    x_label = xlabel('Optimization set');
    y_label = ylabel('Time (ms)');
    
    set(title_label, 'FontSize', 24);
    set(x_label, 'FontSize', 24);
    set(y_label, 'FontSize', 24);
    set(gca,'FontSize', 14);
    set(gca,'XTickLabel', ...
        {'-O0', '-O1', '-O2', '-O3', 'fastest', 'average'})
    
    hold on
    e = errorbar(means, stds, 'color', [0.75 0 0], 'linestyle', 'none');
    errorbar_tick(e, 20);
    hold off
    
    path = fullfile('.', 'report', 'graphs', char(strcat(name, '.png')));
    saveas(e, path);
    
%     pause
end

% The grouped graphs.
for i = 1 : 3 : num_benchmarks
    means = [standard_means{i}, fastest_mean{i}, average_mean{i};
        standard_means{i + 1}, fastest_mean{i + 1}, average_mean{i + 1};
        standard_means{i + 2}, fastest_mean{i + 2}, average_mean{i + 2}]';
    
    stds = [standard_stds{i}, fastest_std{i}, average_std{i};
        standard_stds{i + 1}, fastest_std{i + 1}, average_std{i + 1};
        standard_stds{i + 2}, fastest_std{i + 2}, average_std{i + 2}]';
    
    h = bar(means);
    set(h(1), 'facecolor', [0 1 0]);
    set(h(2), 'facecolor', [0 1 1]);
    set(h(3), 'facecolor', [1 1 0]);
  
    h_legend = legend([names{i}; names{i + 1}; names{i + 2}]);
    x_label = xlabel('Optimization set');
    y_label = ylabel('Time (ms)');
    
    % Legend
    set(h_legend, 'FontSize', 16);
    
    % Axes
    set(x_label, 'FontSize', 24);
    set(y_label, 'FontSize', 24);
    set(gca,'FontSize', 14);
    set(gca,'XTickLabel', ...
        {'-O0', '-O1', '-O2', '-O3', 'fastest', 'average'});
    
    numgroups = size(means, 1);
    numbars = size(means, 2);
    
    groupwidth = min(0.8, numbars/(numbars + 1.5));
    
    hold on
    for j = 1 : numbars
        % Align the error bar with each individual bar.
        tmp = (1:numgroups) - groupwidth/2 + ...
            (2 * j - 1) * groupwidth / (2*numbars);
        h = errorbar(tmp, means(:,j), stds(:,j), 'r', 'linestyle', 'none');
    end
    hold off
    
    path = fullfile('.', 'report', 'graphs', ...
        char(strcat('combined', num2str((i + 2) / 3), '.png')));
    saveas(h, path);
  
%     pause
end

% The averages graph.
[num_runs, num_opts] = size(datas{1});
all_data = zeros(num_benchmarks * num_runs, num_opts);

for i = 1 : num_benchmarks
    all_data(i:i+9, :) = datas{i};
end

standard_opts = all_data(:, 1:4);
s_means = mean(standard_opts);

random_opts = all_data(:, 5:size(all_data,2));
random_means = mean(random_opts);

fastest_idx = find(random_means == min(random_means));
fastest_vals = random_opts(:, fastest_idx);
f_mean = mean(fastest_vals);

flattened_random = reshape(random_opts, 1, numel(random_opts));
a_mean = mean(flattened_random);

% The individual graphs.
means = [s_means, f_mean, a_mean];

h = bar(means);
set(h, 'facecolor', [0.3 0.3 1]);
    
title_label = title('SPEC Benchmark Suite');
x_label = xlabel('Optimization set');
y_label = ylabel('Time (ms)');

set(title_label, 'FontSize', 24);
set(x_label, 'FontSize', 24);
set(y_label, 'FontSize', 24);
set(gca,'FontSize', 14);
set(gca,'XTickLabel', ...
    {'-O0', '-O1', '-O2', '-O3', 'fastest', 'average'})

path = fullfile('.', 'report', 'graphs', 'averages.png');
saveas(h, path);

% pause