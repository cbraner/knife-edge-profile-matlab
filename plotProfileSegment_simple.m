clear; clc; close all;

%% בחירת קובץ פרופיל שמור
[fileName, folderName] = uigetfile( ...
    {'*_profile_*.mat;*.mat','Profile MAT files (*.mat)'}, ...
    'בחר קובץ פרופיל שמור');

if isequal(fileName,0)
    error("לא נבחר קובץ.");
end

filePath = fullfile(folderName, fileName);
[~, baseName, ~] = fileparts(fileName);

%% טעינת הקובץ
S = load(filePath);

% בדיקה שהקובץ הוא באמת קובץ פרופיל מהתוכנית שלך
requiredFields = {'x_mm','profile_raw','profile_smooth'};

for k = 1:numel(requiredFields)
    if ~isfield(S, requiredFields{k})
        error("בקובץ חסר המשתנה: %s", requiredFields{k});
    end
end

x = S.x_mm(:);
yRaw = S.profile_raw(:);
ySmooth = S.profile_smooth(:);

fprintf("\nטווח הפרופיל בקובץ:\n");
fprintf("x = %.4f עד %.4f mm\n", min(x), max(x));
fprintf("מספר נקודות: %d\n", numel(x));

%% בחירת תחום המקטע
answer = inputdlg( ...
    { ...
    'תחילת המקטע במ"מ:', ...
    'סוף המקטע במ"מ:', ...
    'איזה פרופיל להציג? smooth / raw / both:', ...
    'ציר x יחסי מתחילת המקטע? 1=כן, 0=לא:' ...
    }, ...
    'בחירת מקטע פרופיל', ...
    1, ...
    {'20','30','smooth','0'});

if isempty(answer)
    error("הפעולה בוטלה.");
end

xMin = str2double(strrep(answer{1}, ',', '.'));
xMax = str2double(strrep(answer{2}, ',', '.'));
profileMode = lower(strtrim(answer{3}));
useRelativeX = logical(str2double(strrep(answer{4}, ',', '.')));

if isnan(xMin) || isnan(xMax) || xMax <= xMin
    error("תחום המקטע אינו תקין.");
end

if ~any(strcmp(profileMode, {'smooth','raw','both'}))
    error("בחר smooth או raw או both.");
end

%% חיתוך המקטע
keep = x >= xMin & x <= xMax;

if sum(keep) < 2
    error("לא נמצאו מספיק נקודות בתחום %.3f עד %.3f mm.", xMin, xMax);
end

xSeg = x(keep);
yRawSeg = yRaw(keep);
ySmoothSeg = ySmooth(keep);

if useRelativeX
    xPlot = xSeg - xSeg(1);
    xLabelText = sprintf("מיקום יחסי בתוך המקטע [mm], התחלה מקורית %.3f mm", xSeg(1));
else
    xPlot = xSeg;
    xLabelText = "מיקום לאורך להב הסכין [mm]";
end

%% ציור הגרף
figure('Name','Profile segment','NumberTitle','off');
hold on;
grid on;

switch profileMode
    case 'smooth'
        plot(xPlot, ySmoothSeg, 'k-', 'LineWidth', 1.5, ...
            'DisplayName', 'Smoothed');

    case 'raw'
        plot(xPlot, yRawSeg, 'Color', [0.6 0 0], 'LineWidth', 1.0, ...
            'DisplayName', 'Raw');

    case 'both'
        plot(xPlot, yRawSeg, 'Color', [0.7 0.7 0.7], 'LineWidth', 0.9, ...
            'DisplayName', 'Raw');
        plot(xPlot, ySmoothSeg, 'k-', 'LineWidth', 1.5, ...
            'DisplayName', 'Smoothed');
end

xlabel(xLabelText, 'Interpreter','none');
ylabel("Intensity (GREEN)", 'Interpreter','none');

title( ...
    { ...
    "פרופיל להב הסכין - מקטע נבחר"; ...
    sprintf("%s   |   %.3f עד %.3f mm", baseName, xMin, xMax) ...
    }, ...
    'Interpreter','none');

legend('Location','best');

%% שמירת פלט
rangeToken = sprintf("_segment_%.3f_to_%.3fmm_%s", xMin, xMax, profileMode);
rangeToken = strrep(rangeToken, ".", "p");

outPng = fullfile(folderName, baseName + rangeToken + ".png");
outCsv = fullfile(folderName, baseName + rangeToken + ".csv");

T = table( ...
    xSeg, ...
    yRawSeg, ...
    ySmoothSeg, ...
    'VariableNames', {'x_mm_original','profile_raw','profile_smooth'});

if useRelativeX
    T.x_mm_relative = xPlot;
end

writetable(T, outCsv);
exportgraphics(gcf, outPng, 'Resolution', 300);

fprintf("\nנשמרו קבצים:\n");
fprintf("%s\n", outPng);
fprintf("%s\n", outCsv);