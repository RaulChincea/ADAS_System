% --- 1. Load Images and Send to GPU ---
left_img = double(rgb2gray(imread('left_image.png')));
right_img = double(rgb2gray(imread('right_image.png')));

% The 'gpuArray' command sends the data from your computer's RAM to the GPU's VRAM
left_gpu = gpuArray(left_img);
right_gpu = gpuArray(right_img);

[height, width] = size(left_gpu);

% --- 2. Parameters ---
win_size = 9; 
max_disparity = 220; 

% Create a filter mask representing our window (a 9x9 grid of 1s)
% We will use this to quickly sum up the differences in the WxW window
box_filter = gpuArray(ones(win_size, win_size));

% Initialize variables on the GPU to hold the best costs and best disparities
best_cost_gpu = gpuArray(inf(height, width));
disparity_map_gpu = gpuArray(zeros(height, width));

disp('Calculating disparity map on GPU...');
tic; % Start timer

% --- 3. Vectorized GPU Block Matching ---
% We only loop over the disparities, not the pixels!
for d = 0 : max_disparity
    
    % Step A: Shift the right image horizontally by 'd' pixels
    % We pad the left side with zeros to handle the shift
    shifted_right = [zeros(height, d, 'gpuArray'), right_gpu(:, 1:end-d)];
    
    % Step B: Calculate the Absolute Difference for the ENTIRE image at once
    abs_diff = abs(left_gpu - shifted_right);
    
    % Step C: Sum up the differences in the WxW window using a 2D convolution filter
    % This replaces the need to extract small windows manually
    cost_volume = imfilter(abs_diff, box_filter, 'symmetric');
    
    % Step D: Update the best cost and disparity map
    % Find where the current cost is lower than the previously stored best cost
    update_mask = cost_volume < best_cost_gpu;
    
    % Apply the updates simultaneously across the whole matrix
    best_cost_gpu(update_mask) = cost_volume(update_mask);
    disparity_map_gpu(update_mask) = d;
    
end

% --- 4. Retrieve Data from GPU ---
% Bring the calculated map back from the GPU to the CPU RAM
disparity_map = gather(disparity_map_gpu);

elapsed_time = toc; % Stop timer
fprintf('GPU Calculation finished in %.2f seconds!\n', elapsed_time);

% Calculate depth just like before
baseline = 56.46;  
focal_length = 1758.23; 
depth_map = (baseline * focal_length) ./ (disparity_map + eps); 

% Display results
% figure;
% imshow(disparity_map, []);
% colormap(jet); colorbar;
% title('GPU Accelerated Disparity Map');

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