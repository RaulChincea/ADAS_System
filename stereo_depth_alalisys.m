% --- 1. Load the Stereo Image Pair ---
% Note: Download a pair from the Middlebury dataset (e.g., 'tsukuba_l.png' and 'tsukuba_r.png')
left_img = imread('left_image.png');
right_img = imread('right_image.png');

% Convert to grayscale if they are RGB
if size(left_img, 3) == 3
    left_img = rgb2gray(left_img);
    right_img = rgb2gray(right_img);
end

% Convert to double for mathematical operations
left_img = double(left_img);
right_img = double(right_img);

[height, width] = size(left_img);

% --- 2. Algorithm Parameters ---
% Window size: A small window gives more detail but more noise; 
% a large window gives a smooth map but loses structural detail (as per your slides)
win_size = 9; 
half_win = floor(win_size / 2);

max_disparity = 220; % Maximum pixel shift to search 
disparity_map = zeros(height, width);

disp('Calculating disparity map. This might take a minute...');

% --- 3. Block Matching Algorithm (With Console Tracker) ---
start_row = 1 + half_win;
end_row = height - half_win;
total_rows = end_row - start_row;

fprintf('Calculating disparity map...\n');
msg = ''; % Initialize empty message

% Loop through every pixel in the left image
for i = start_row : end_row
    
    % Calculate percentage and update console
    progress_pct = round(((i - start_row) / total_rows) * 100);
    
    % Delete the previous percentage text, then print the new one
    fprintf(repmat('\b', 1, length(msg)));
    msg = sprintf('Progress: %d%%', progress_pct);
    fprintf('%s', msg);
    
    for j = 1 + half_win + max_disparity : width - half_win
        
        win_left = left_img(i - half_win : i + half_win, j - half_win : j + half_win);
        best_cost = inf;
        best_d = 0;
        
        for d = 0 : max_disparity
            win_right = right_img(i - half_win : i + half_win, j - d - half_win : j - d + half_win);
            cost = sum(abs(win_left(:) - win_right(:)));
            
            if cost < best_cost
                best_cost = cost;
                best_d = d;
            end
        end
        disparity_map(i, j) = best_d;
    end
end
fprintf('\nDone!\n'); % Move to a new line when finished

% --- 4. Calculate Depth ---
% Based on the formula: disparity = (Baseline * focal_length) / depth
% Therefore: depth = (Baseline * focal_length) / disparity
% You would get B and f from the Middlebury dataset camera parameters (calib.txt)
baseline = 56.46; % Example value in mm
focal_length = 1758.23; % Example value in pixels

% Add a tiny value (eps) to prevent division by zero
depth_map = (baseline * focal_length) ./ (disparity_map + eps); 

% --- 5. Display Results ---
figure;
subplot(2,2,1); imshow(uint8(left_img)); title('Left Image');
subplot(2,2,2); imshow(uint8(right_img)); title('Right Image');

% Display Disparity
subplot(2,2,3); 
imshow(disparity_map, []); 
colormap(gca, jet); colorbar; 
title('Disparity Map (High = Closer)');

% Display Depth
subplot(2,2,4); 
% Cap the depth map for visualization purposes to avoid infinity spikes
max_viz_depth = 5000; 
depth_viz = min(depth_map, max_viz_depth);
imshow(depth_viz, []); 
colormap(gca, hot); colorbar;
title('Depth Map (Distance)');