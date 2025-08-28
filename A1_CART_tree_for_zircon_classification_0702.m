%% 0. Initial State
clear all;         % Clear all variables
close all;         % Close all figure windows
clc;               % Clear the command window
clear path;        % Clear all added paths
clearvars -global; % Clear all global variables
clear functions;   % Clear all persistent variables
clear java;        % Clear Java objects
clear mex;         % Clear MEX files

%% 1. Select Excel File
[fileName, filePath] = uigetfile({'*.xlsx;*.xls', 'Excel Files (*.xlsx, *.xls)'}, ...
                                 'Please select an Excel file');

% Check if the user selected a file (A1_00_Zircon_Element_Example_New)
if fileName == 0
    disp('File selection cancelled by user.');
    return;
end

% Generate full file path
fullFileName = fullfile(filePath, fileName);

%% 2. Read Excel Data
try
    % Use readcell to read the complete data (text + numeric)
    raw = readcell(fullFileName); 
    disp(['Successfully read file: ', fullFileName]);

    % Get header information (first row)
    headers = raw(1, :);
    
    % Display header information
    disp('Header information:');
    disp(headers);
    
catch ME
    disp('Failed to read Excel file:');
    disp(ME.message);
    return;
end

%% 3. Process Data to Remove Excel Calculation Errors
for i = 2:size(raw, 1)  % Loop through each row (starting from row 2)
    for j = 2:size(raw, 2)  % Loop through each column (starting from column 2)
        if ischar(raw{i, j})  % Ensure the data is of type char
            if strcmp(raw{i, j}, '#DIV/0!') || contains(raw{i, j}, 'ActiveX VT_ERROR')
                raw{i, j} = 0.0;  % Replace error values with 0.0
            end
        end
    end
end

%% 4. Get Column Indices for All Geochemical Elements (Including First Column: sample)
geo_elements = headers;  % Get all column names, including the first column (sample names)
element_indices = struct();  % Store all element column indices

disp('📌 Geochemical element column indices (corrected names):');

for k = 1:length(geo_elements)
    element_name = geo_elements{k};  % Get column name
    element_idx = find(strcmp(headers, element_name));  % Get column index

    % Ensure valid MATLAB variable name
    fixed_element_name = matlab.lang.makeValidName(element_name); 

    % Store the index
    element_indices.(fixed_element_name) = element_idx;
    fprintf('%s (original: %s): Column %d\n', fixed_element_name, element_name, element_idx);
end

%% 5. Geochemical Element-Based Rock Classification (Ce/Ce* logic preserved in comments)
addcol = cell(size(raw, 1)-1, 1);

% Get column indices for classification elements (Ce/Ce* not used for now)
try
    col_Lu = element_indices.Lu;
    col_Ta = element_indices.Ta;
    col_U  = element_indices.U;
    col_Hf = element_indices.Hf;
    col_Nb = element_indices.Nb;
    col_Th = element_indices.Th;
    % col_Ce_Ce = element_indices.Ce_Ce; % Uncomment if Ce/Ce* is needed
catch
    disp('❌ Error: Some required element column names were not found. Please check the Excel file headers.');
    return;
end

% Classification logic (Ce/Ce* condition retained in comments)
for i = 2:size(raw,1)
    if raw{i,col_Lu} < 20.7
        if raw{i,col_Ta} > 0.5
            if raw{i,col_Lu} < 2.3
                addcol{i-1} = 'Kimberlite';
            else
                addcol{i-1} = 'Carbonatite';
            end
        else
            addcol{i-1} = 'Syenite';
        end
    else % Lu >= 20.7
        if raw{i,col_U} > 38
            if raw{i,col_Ta} > 0.58
                if raw{i,col_Hf} > 8000
                    % Considering the effect of La content, Ce/Ce* ratio not used for now
                    % To use Ce/Ce*, uncomment the following lines:
                    % if raw{i,col_Ce_Ce < 3.9
                        if raw{i,col_Nb} < 170
                            if raw{i,col_Th}/raw{i,col_U} > 0.44
                                addcol{i-1} = 'Granitoid(65_70%_SiO2)';
                            else
                                addcol{i-1} = 'Granitoid(70_75%_SiO2)';
                            end
                        else
                            addcol{i-1} = 'Granitoid(>75%_SiO2)';
                        end
                    % else
                        % addcol{i-1} = 'Larvikite';
                    % end
                else % Hf <= 8000 ppm
                    addcol{i-1} = 'Basalt';
                end
            else % Ta <= 0.58 ppm
                addcol{i-1} = 'Dolerite';
            end
        else % U <= 38 ppm
            addcol{i-1} = 'Ne_Syenite';
        end
    end
end

%% 6. Handle Possible Missing Values
for i = 1:numel(addcol)
    if any(ismissing(addcol{i})) || isempty(addcol{i})
        addcol{i} = "Unknown";  % Replace missing with "Unknown"
    end
end

%% 7. Combine Classification Results with Original Data
raw2 = [addcol, raw(2:end, :)];  % Concatenate directly
headers = [{'Rock_Type'}, headers]; 
raw2 = [headers; raw2];

%% 8. Ensure Missing Values Are Handled Before Writing to Excel
for i = 1:numel(raw2)
    if ismissing(raw2{i})
        raw2{i} = ""; % Replace missing with empty string
    end
end

%% 9. Save Classification Results to a New Excel File
outputFile = fullfile(filePath, 'A1_01_output_Classification_data_20250702_V1.xlsx'); % ⚠️ Note: output file name

try
    writecell(raw2, outputFile);
    disp(['✅ Classification completed. Results saved to: ', outputFile]);
catch ME
    disp('❌ Failed to write to Excel file:');
    disp(ME.message);
end
