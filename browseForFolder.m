function folderPath = browseForFolder(start_path)
% browseForFolder Opens a UI dialog to select a folder.
%
% Inputs:
%   start_path - (Optional) The directory where the dialog should open first.
%                Defaults to the current working directory (pwd) if not provided.
%
% Returns:
%   folderPath - A string containing the absolute path to the selected folder.
%                Returns an empty string ('') if the user cancels the dialog.

    % Check if the user provided a start_path. If not, default to pwd.
    if nargin < 1 || isempty(start_path)
        start_path = pwd; 
    end
    
    % Define the title of the dialog box
    dialog_title = 'Select a Folder';
    
    % Open the dialog box starting at the specified path
    selected_dir = uigetdir(start_path, dialog_title);
    
    % Check if the user clicked "Cancel" or closed the window
    if selected_dir == 0
        disp('User canceled the folder selection.');
        folderPath = ''; % Return empty string
    else
        fprintf('Folder selected: %s\n', selected_dir);
        folderPath = selected_dir;
    end
end