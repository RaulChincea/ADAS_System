% --- MAIN SCRIPT: Load Stereo Dataset ---

% 1. Ask the user to select the folder containing the dataset
[script_directory, ~, ~] = fileparts(mfilename('fullpath'));
datasetFolder = browseForFolder(script_directory);

% Check if the user canceled the dialog
if isempty(datasetFolder)
    disp('No folder selected. Exiting script.');
    return; % Stop the script here
end

fprintf('Loading files from: %s\n', datasetFolder);

% 2. Construct the full file paths safely using 'fullfile'
% fullfile automatically adds the correct slashes (\ on Windows, / on Mac/Linux)
calib_file = fullfile(datasetFolder, 'calib.txt');
im0_file   = fullfile(datasetFolder, 'im0.png');
im1_file   = fullfile(datasetFolder, 'im1.png');
disp0_file = fullfile(datasetFolder, 'disp0.pfm');
disp1_file = fullfile(datasetFolder, 'disp1.pfm');

% 3. Quick Safety Check: Ensure the crucial files actually exist in this folder
if ~isfile(calib_file) || ~isfile(im0_file) || ~isfile(disp0_file)
    error('Error: Could not find required files (calib.txt, im0.png, or disp0.pfm) in the selected folder.');
end

% 4. Load the Calibration Data
disp('Reading calibration parameters...');
calib = readCalibrationFile(calib_file);

% Extract the parameters you need for depth calculation
baseline = calib.baseline;
focal_length = calib.cam0(1, 1); % Extract fx from the intrinsic matrix
max_disparity = calib.ndisp;

% 5. Load the Images
disp('Reading image files...');
left_img  = imread(im0_file);
right_img = imread(im1_file);

% Convert to grayscale if they are RGB
if size(left_img, 3) == 3
    left_img = rgb2gray(left_img);
    right_img = rgb2gray(right_img);
end

% 6. Load the Ground Truth Disparity Maps
disp('Reading ground truth PFM files...');
ground_truth_left  = readPFM(disp0_file);
ground_truth_right = readPFM(disp1_file);

% --- DONE LOADING ---
fprintf('\n--- Dataset Loaded Successfully! ---\n');
fprintf('Baseline: %.2f mm\n', baseline);
fprintf('Focal Length: %.2f pixels\n', focal_length);
fprintf('Max Disparity: %d pixels\n', max_disparity);

% 7. Visualize everything we just loaded to confirm it works
figure('Name', 'Stereo Dataset Overview', 'NumberTitle', 'off', 'Position', [100, 100, 1000, 600]);

subplot(2, 2, 1); 
imshow(left_img); 
title('Left Image (im0.png)');

subplot(2, 2, 2); 
imshow(right_img); 
title('Right Image (im1.png)');

subplot(2, 2, 3); 
imshow(ground_truth_left, []); % '[]' automatically scales the colormap to min/max disparity
colormap(gca, jet); colorbar;
title('Ground Truth Left (disp0.pfm)');

subplot(2, 2, 4); 
imshow(ground_truth_right, []); 
colormap(gca, jet); colorbar;
title('Ground Truth Right (disp1.pfm)');

% Set the window size (optional, defaults to 9 if you leave it out)
window_size = 9; 

% Call your new function!
[my_disparity, my_depth] = calculateStereoDepthGPU(left_img, right_img, calib, window_size);
