tid = 40;      % Specify the time step ID
px = 4;         % Number of processors along x-direction
py = 4;         % Number of processors along y-direction

% Get list of all files for the given time step
filePattern = sprintf('T_x_y_%06d_*.dat', tid);
files = dir(filePattern);

% Check if files exist
if isempty(files)
    error('No files found for time step %d', tid);
end

% Preallocate structure for processor data
procData = struct('rank', [], 'rank_x', [], 'rank_y', [], 'x', [], 'y', [], 'T', []);

% Read each file and extract data
for k = 1:length(files)
    filename = files(k).name;
    
    % Extract rank from filename (e.g., T_x_y_000200_0001.dat)
    [~, name] = fileparts(filename);
    parts = strsplit(name, '_');
    rank = str2double(parts{end});
    
    % Read data
    data = dlmread(filename);
    x = data(:,1);
    y = data(:,2);
    T = data(:,3);
    
    % Determine local grid dimensions
    xUnique = unique(x);
    yUnique = unique(y);
    nx = length(xUnique);
    ny = length(yUnique);
    T = reshape(T, nx, ny);  % Reshape to 2D
    
    % Compute rank's position in the grid
    rank_x = mod(rank, px);
    rank_y = floor(rank / px);
    
    % Store data
    procData(k).rank = rank;
    procData(k).rank_x = rank_x;
    procData(k).rank_y = rank_y;
    procData(k).x = xUnique;
    procData(k).y = yUnique;
    procData(k).T = T;
end

% Build global_x from processors in the first row (rank_y=0)
firstRow = procData([procData.rank_y] == 0);
[~, order] = sort([firstRow.rank_x]);  % Sort by rank_x
global_x = vertcat(firstRow(order).x);

% Build global_y from processors in the first column (rank_x=0)
firstCol = procData([procData.rank_x] == 0);
[~, order] = sort([firstCol.rank_y]);  % Sort by rank_y
global_y = vertcat(firstCol(order).y);

% Initialize global temperature matrix
globalT = zeros(length(global_x), length(global_y));

% Place each processor's data into the global matrix
for k = 1:length(procData)
    pd = procData(k);
    
    % Find indices in global_x
    [~, xStart] = min(abs(global_x - pd.x(1)));
    xEnd = xStart + length(pd.x) - 1;
    
    % Find indices in global_y
    [~, yStart] = min(abs(global_y - pd.y(1)));
    yEnd = yStart + length(pd.y) - 1;
    
    % Insert data into globalT
    globalT(xStart:xEnd, yStart:yEnd) = pd.T;
end

% Visualization (same as original)
x = global_x;
y = global_y;
T = globalT;

figure, clf
contourf(x, y, T', 'LineColor', 'none')
xlabel('x'), ylabel('y'), title(sprintf('t = %06d', tid))
xlim([-0.05 1.05]), ylim([-0.05 1.05]), caxis([0 0.2])
colorbar
colormap('jet')
set(gca, 'FontSize', 14)
% screen2jpeg(sprintf('cont_T_%04d.png', tid));  % Uncomment if needed

figure, clf
Tmid = T(:, round(length(y)/2));
plot(x, Tmid, '-', 'LineWidth', 2)
xlabel('x'), ylabel('T'), title(sprintf('Mid-y Profile at t=%06d', tid))
xlim([-0.05 1.05])
set(gca, 'FontSize', 14)
% screen2jpeg(sprintf('line_midy_T_%04d.png', tid));  % Uncomment if needed