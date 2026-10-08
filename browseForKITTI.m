function [left_img_path, right_img_path, calib_path] = browseForKITTI(start_path)
% =========================================================================
% FUNCTION: browseForKITTI
% DESCRIPTION: 
%   Interactive file acquisition module designed to navigate the unorganized 
%   directory structures of the KITTI Vision Benchmark Suite. It utilizes 
%   a two-step OS-native graphical user interface to acquire the primary 
%   stereo frame and intrinsic calibration file, while employing string 
%   heuristics to automatically resolve the conjugate (right-eye) image path.
%
% INPUTS:
%   start_path      - String (Optional): The root directory from which the 
%                     UI browser should initiate. Defaults to the Current 
%                     Working Directory (pwd).
%
% OUTPUTS:
%   left_img_path   - String: Absolute path to the left-eye optical frame.
%   right_img_path  - String: Inferred absolute path to the right-eye frame.
%   calib_path      - String: Absolute path to the dataset calibration file.
%                     * Note: All outputs return empty strings ('') if the 
%                       user aborts the selection process.
% =========================================================================

    % Initialize default directory state if no argument is provided
    if nargin < 1 || isempty(start_path)
        start_path = pwd; 
    end
    
    % ---------------------------------------------------------------------
    % Phase 1: Acquire Primary Sensor Frame (Left Camera)
    % ---------------------------------------------------------------------
    disp('Waiting for user to select Left Image...');
    
    % Invoke OS-native file dialog filtered for PNG optical frames
    [img_name, img_folder] = uigetfile(fullfile(start_path, '*.png'), ...
        '1. Select LEFT Image (from image_02 or image_2 folder)');
    
    % Exception Handling: Detect user cancellation of the UI prompt
    if img_name == 0
        disp('Acquisition Aborted: User canceled primary image selection.');
        left_img_path = ''; right_img_path = ''; calib_path = ''; return;
    end
    
    % Construct the absolute path for the left reference frame
    left_img_path = fullfile(img_folder, img_name);
    
    % ---------------------------------------------------------------------
    % Phase 2: Heuristic Path Inference (Right Camera)
    % ---------------------------------------------------------------------
    % The KITTI dataset maintains strict parallel directory structures. 
    % We use string substitution on the parent directory to locate the right 
    % frame without requiring a redundant UI prompt.
    % Handles both 'Raw Odometry' (image_02 -> image_03) and 
    % 'Evaluation Benchmark' (image_2 -> image_3) directory conventions.
    
    right_folder = strrep(img_folder, 'image_02', 'image_03');
    right_folder = strrep(right_folder, 'image_2', 'image_3');
    
    % Construct the absolute path for the conjugate stereo frame
    right_img_path = fullfile(right_folder, img_name);
    
    % ---------------------------------------------------------------------
    % Phase 3: Acquire Camera Calibration Matrix
    % ---------------------------------------------------------------------
    disp('Waiting for user to select Calibration file...');
    
    % Invoke OS-native file dialog filtered for TXT calibration files
    [calib_name, calib_folder] = uigetfile(fullfile(start_path, '*.txt'), ...
        '2. Select the matching CALIBRATION file (e.g., 000000.txt)');
    
    % Exception Handling: Detect user cancellation of the UI prompt
    if calib_name == 0
        disp('Acquisition Aborted: User canceled calibration selection.');
        left_img_path = ''; right_img_path = ''; calib_path = ''; return;
    end
    
    % Construct the absolute path for the dataset calibration file
    calib_path = fullfile(calib_folder, calib_name);
    
    % Log successful ingestion paths to the command window
    fprintf('\nSuccessfully Loaded:\n- Image: %s\n- Calib: %s\n', img_name, calib_name);
end