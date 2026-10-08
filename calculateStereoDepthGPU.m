function [disparity_map, depth_map] = calculateStereoDepthGPU(left_img, right_img, calib, win_size, show_plot)
% calculateStereoDepthGPU Computes disparity and depth maps from stereo images using the GPU.

    % --- 0. Handle Optional Arguments ---
    if nargin < 4 || isempty(win_size)
        win_size = 9; 
    end
    if nargin < 5 || isempty(show_plot)
        show_plot = true;
    end

    % --- 1. Extract Calibration Parameters ---
    baseline = calib.baseline;
    max_disparity = calib.ndisp;
    focal_length = calib.cam0(1, 1); % Extract f_x from the intrinsic matrix
    
    % NEW: Dynamically calculate Max Depth using vmin (Minimum Disparity)
    % If vmin is 0 or missing, default to 1 to prevent division by zero
    if isfield(calib, 'vmin') && calib.vmin > 0
        min_disparity = calib.vmin;
    else
        min_disparity = 1; 
    end
    
    % The smallest valid disparity gives us the maximum valid depth bounds
    max_depth = (baseline * focal_length) / min_disparity; 
    
    % --- 2. Preprocess Images ---
    if size(left_img, 3) == 3
        left_img = rgb2gray(left_img);
        right_img = rgb2gray(right_img);
    end
    
    left_img = double(left_img);
    right_img = double(right_img);
    
    left_gpu = gpuArray(left_img);
    right_gpu = gpuArray(right_img);
    [height, width] = size(left_gpu);

    % --- 3. Initialize GPU Variables ---
    box_filter = gpuArray(ones(win_size, win_size));
    best_cost_gpu = gpuArray(inf(height, width));
    disparity_map_gpu = gpuArray(zeros(height, width));
    
    disp('Calculating disparity map on GPU...');
    tic; 

    % --- 4. Vectorized GPU Block Matching ---
    for d = 0 : max_disparity
        shifted_right = [zeros(height, d, 'gpuArray'), right_gpu(:, 1:end-d)];
        abs_diff = abs(left_gpu - shifted_right);
        cost_volume = imfilter(abs_diff, box_filter, 'symmetric');
        
        update_mask = cost_volume < best_cost_gpu;
        
        best_cost_gpu(update_mask) = cost_volume(update_mask);
        disparity_map_gpu(update_mask) = d;
    end

    % --- 5. Retrieve Data & Calculate Depth ---
    disparity_map = gather(disparity_map_gpu);
    
    elapsed_time = toc; 
    fprintf('GPU Calculation finished in %.2f seconds!\n', elapsed_time);
    fprintf('Calculated Maximum Depth bounds: %.2f units\n', max_depth);
    
    % Calculate actual depth map
    depth_map = (baseline * focal_length) ./ (disparity_map + eps); 

    % --- 6. Display Results ---
    if show_plot
        figure('Name', 'GPU Stereo Processing Results', 'NumberTitle', 'off', 'Position', [100, 100, 1000, 800]);
        
        subplot(2,2,1); 
        imshow(uint8(left_img)); 
        title('Left Image');
        
        subplot(2,2,2); 
        imshow(uint8(right_img)); 
        title('Right Image');
        
        % Display Disparity (using calibration vmin and vmax if available)
        subplot(2,2,3); 
        if isfield(calib, 'vmax')
            imshow(disparity_map, [calib.vmin, calib.vmax]); 
        else
            imshow(disparity_map, []); 
        end
        colormap(gca, jet); colorbar; 
        title('Disparity Map (High = Closer)');
        
        % Display Depth (Capped perfectly by the dynamic max_depth)
        subplot(2,2,4); 
        depth_viz = min(depth_map, max_depth);
        imshow(depth_viz, []); 
        colormap(gca, hot); colorbar;
        title(sprintf('Depth Map (Capped at %.0f)', max_depth));
    end
end