% =========================================================================
% SCRIPT: ADAS Semantic Stereo System - Main Execution Pipeline
% 
% DESCRIPTION:
% This script serves as the primary entry point for the Advanced Driver 
% Assistance System (ADAS) simulation. It implements a sensor fusion 
% architecture, combining 2D semantic object detection (YOLOv4 CNN) with 
% 3D geometric depth estimation (Semi-Global Matching stereo disparity). 
% The pipeline evaluates real-world object distances to validate an 
% automated emergency braking (AEB) boolean logic trigger.
%
% DEPENDENCIES:
%   - MATLAB Computer Vision Toolbox
%   - MATLAB Deep Learning Toolbox
%   - Computer Vision Toolbox Model for YOLO v4 Object Detection (Add-on)
%   - Custom local functions: 
%       * browseForKITTI.m
%       * readCalibrationFileKITTI.m
%       * runADAS_System.m
% =========================================================================

% --- Environment Initialization ---
clc; clear; close all;
disp('=== Initializing ADAS Pipeline ===');

% -------------------------------------------------------------------------
% Phase 1: Dataset Acquisition & Path Resolution
% -------------------------------------------------------------------------
% Dynamically resolve the absolute path of the current script to establish 
% the root working directory for the UI file browser.
[script_directory, ~, ~] = fileparts(mfilename('fullpath'));

% Invoke the custom UI browser to select the raw KITTI dataset frame.
[left_image_path, right_image_path, calib_file] = browseForKITTI(script_directory);

% Validate user selection to prevent downstream execution errors.
if isempty(left_image_path)
    error('Execution Terminated: No source image was provided by the user.');
end

% -------------------------------------------------------------------------
% Phase 2: Camera Calibration Parameter Extraction
% -------------------------------------------------------------------------
% Parse the KITTI calibration text file to extract intrinsic camera matrices 
% and the physical baseline distance required for disparity-to-depth conversion.
if isfile(calib_file)
    disp('Loading camera calibration matrices...');
    calib = readCalibrationFileKITTI(calib_file);
else
    error('Fatal Error: Calibration file not located at specified path: %s', calib_file);
end

% -------------------------------------------------------------------------
% Phase 3: Stereo Rectified Image Ingestion
% -------------------------------------------------------------------------
% Load the rectified left and right optical frames into memory space.
if isfile(left_image_path) && isfile(right_image_path)
    disp('Ingesting stereo image pair into memory...');
    left_img = imread(left_image_path);
    right_img = imread(right_image_path);
else
    error('Fatal Error: Target right-eye optical frame not found. Verify KITTI dataset structure.');
end

% -------------------------------------------------------------------------
% Phase 4: Convolutional Neural Network (CNN) Initialization
% -------------------------------------------------------------------------
% Instantiate the pre-trained YOLOv4 object detection model. This is executed 
% outside the main processing loop/function to prevent redundant memory 
% allocation and heavy I/O overhead on subsequent frames.
disp('Initializing Neural Network Weights (YOLOv4)...');
try
    yolo_detector = yolov4ObjectDetector('csp-darknet53-coco');
catch
    error('Network Initialization Failed. Ensure the "Computer Vision Toolbox Model for YOLO v4 Object Detection" is installed via MATLAB Add-Ons.');
end

% -------------------------------------------------------------------------
% Phase 5: Sensor Fusion & Depth Estimation Pipeline
% -------------------------------------------------------------------------
disp('Executing Semantic-Geometric Sensor Fusion...');
tic; % Initiate execution timer for performance profiling

% Pass the optical frames, camera parameters, and neural network to the 
% ADAS logic function. Returns the annotated optical frame and AEB boolean.
[final_image, brake_flag] = runADAS_System(left_img, right_img, calib, yolo_detector);

processing_time = toc; % Terminate execution timer

% -------------------------------------------------------------------------
% Phase 6: User Interface & Telemetry Visualization
% -------------------------------------------------------------------------
% Render the resulting frame with overlaid bounding boxes and depth metrics.
figure('Name', 'ADAS Telemetry Dashboard', 'NumberTitle', 'off', 'Position', [100, 100, 1200, 600]);
imshow(final_image);

% Evaluate the AEB boolean flag and render the appropriate HUD warning.
if brake_flag
    text(50, 50, 'WARNING: EMERGENCY BRAKE ENGAGED', 'Color', 'red', ...
        'FontSize', 24, 'FontWeight', 'bold', 'BackgroundColor', 'black');
    fprintf('>>> AEB SYSTEM ALERT: Collision imminent. Brakes engaged. (Pipeline Latency: %.2fs)\n', processing_time);
else
    text(50, 50, 'SYSTEM CLEAR', 'Color', 'green', ...
        'FontSize', 24, 'FontWeight', 'bold', 'BackgroundColor', 'black');
    fprintf('>>> Path verification clear. (Pipeline Latency: %.2fs)\n', processing_time);
end

disp('=== Pipeline Execution Complete ===');