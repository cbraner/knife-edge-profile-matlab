function out = makeBladeProfile_clean(mode)
% makeBladeProfile_clean
% ------------------------------------------------------------
% Clean MATLAB wrapper for extracting a 1D optical profile along a knife edge.
%
% Usage:
%   out = makeBladeProfile_clean
%   out = makeBladeProfile_clean('new')
%   out = makeBladeProfile_clean('last')
%
% Required functions on the MATLAB path:
%   raw2green.m
%   rerunProfile_clean_v2.m

    if nargin < 1 || strlength(string(mode)) == 0
        mode = 'ask';
    end

    mode = lower(char(string(mode)));

    requireDependency('raw2green');
    requireDependency('rerunProfile_clean_v2');

    % New settings file name, to avoid accidental reuse of old v1-v4 state files.
    lastFile = fullfile(pwd, 'last_blade_profile_settings_clean.mat');

    switch resolveRunMode(mode, lastFile)
        case 'new'
            out = runNew(lastFile);

        case 'last'
            out = runLast(lastFile);

        otherwise
            error('mode must be ask, new, or last.');
    end
end

% =====================================================================
% Main run modes
% =====================================================================

function mode = resolveRunMode(mode, lastFile)

    if strcmp(mode, 'ask')
        if isfile(lastFile)
            choice = questdlg( ...
                ['נמצאו נתוני פרופיל אחרונים מגרסת clean.' newline ...
                 'האם להשתמש באותו session ולשנות רק פרמטרי מדידה/החלקה?'], ...
                'פרופיל להב', ...
                'השתמש בנתונים האחרונים', ...
                'הכנס נתונים חדשים', ...
                'בטל', ...
                'השתמש בנתונים האחרונים');

            if isempty(choice) || strcmp(choice, 'בטל')
                error('הפעולה בוטלה.');
            elseif strcmp(choice, 'השתמש בנתונים האחרונים')
                mode = 'last';
            else
                mode = 'new';
            end
        else
            mode = 'new';
        end
    end

    if ~any(strcmp(mode, {'new','last'}))
        error('mode must be ask, new, or last.');
    end
end

function out = runNew(lastFile)

    [nefName, nefFolder] = uigetfile( ...
        {'*.NEF;*.nef','Nikon RAW files (*.NEF)'}, ...
        'בחר את קובץ ה-NEF');

    if isequal(nefName, 0)
        error('לא נבחר קובץ NEF.');
    end

    nefPath = fullfile(nefFolder, nefName);
    [outDir, imageNameFromFile, ~] = fileparts(nefPath);

    defaults = defaultState();

    % Use previous CLEAN settings only as convenient defaults.
    % The image name is still taken from the newly selected NEF file.
    if isfile(lastFile)
        try
            tmp = load(lastFile, 'state');
            defaults = mergeStructs(defaults, tmp.state);
        catch
            % If previous settings cannot be loaded, continue with generic defaults.
        end
    end

    state = askGeometry(defaults, imageNameFromFile);
    state.nefPath = nefPath;
    state.outDir = outDir;

    state = askMeasurement(state);

    session = buildSession(state);

    state.sessionFile = session.sessionFile;
    state.sessionBase = session.sessionBase;

    saveLastState(state, lastFile);

    out = runProfile(state);
end

function out = runLast(lastFile)

    if ~isfile(lastFile)
        error(['לא נמצא קובץ נתונים אחרונים של גרסת clean:' newline lastFile newline ...
               'הרץ קודם makeBladeProfile_clean(''new'').']);
    end

    tmp = load(lastFile, 'state');
    state = tmp.state;

    if ~isfield(state, 'sessionFile') || ~isfile(state.sessionFile)
        [sessionName, sessionFolder] = uigetfile( ...
            {'*.mat','MAT files (*.mat)'}, ...
            'בחר קובץ session');

        if isequal(sessionName, 0)
            error('לא נבחר קובץ session.');
        end

        state.sessionFile = fullfile(sessionFolder, sessionName);
        state.outDir = sessionFolder;
    end

    if ~isfield(state, 'outDir') || isempty(state.outDir)
        state.outDir = fileparts(state.sessionFile);
    end

    state = askMeasurement(state);

    saveLastState(state, lastFile);

    out = runProfile(state);
end

% =====================================================================
% Input dialogs
% =====================================================================

function state = askGeometry(defaults, imageNameFromFile)

    prompt = { ...
        'מספר הסכין:', ...
        'שם התמונה לכותרת הגרף:', ...
        ['4 נקודות מלבן הכיול לפי JPG, בסדר:' newline ...
         'שמאל-עליון; ימין-עליון; ימין-תחתון; שמאל-תחתון'], ...
        ['2 נקודות קצה הלהב לפי JPG, בסדר:' newline ...
         'קצה עליון; קצה תחתון'], ...
        'יחס המרה מ-JPG ל-GREEN. בדרך כלל 0.5:', ...
        'רוחב מלבן הכיול הפיזי [mm]:', ...
        'גובה מלבן הכיול הפיזי [mm]:', ...
        'גובה יעד של המלבן המיושר [pixels]:' ...
    };

    defaultsCell = { ...
        asChar(fieldOr(defaults, 'knifeNumber', '')), ...
        imageNameFromFile, ...
        matrixToText(fieldOr(defaults, 'rect4_jpg', [])), ...
        matrixToText(fieldOr(defaults, 'blade2_jpg', [])), ...
        num2str(fieldOr(defaults, 'scaleJpgToGreen', 0.5)), ...
        num2str(fieldOr(defaults, 'widthMM', 33)), ...
        num2str(fieldOr(defaults, 'heightMM', 47)), ...
        num2str(fieldOr(defaults, 'targetH', 650)) ...
    };

    dims = [ ...
        1 75; ...
        1 75; ...
        5 75; ...
        3 75; ...
        1 75; ...
        1 75; ...
        1 75; ...
        1 75 ...
    ];

    answer = inputdlg(prompt, 'נתוני נקודות וגיאומטריה', dims, defaultsCell);

    if isempty(answer)
        error('הפעולה בוטלה.');
    end

    state = defaults;

    state.knifeNumber = strtrim(asChar(answer{1}));
    state.imageName = strtrim(asChar(answer{2}));

    if isempty(state.imageName)
        state.imageName = imageNameFromFile;
    end

    state.rect4_jpg = parsePointMatrix(answer{3}, 4, 'ארבע נקודות מלבן הכיול');
    state.blade2_jpg = parsePointMatrix(answer{4}, 2, 'שתי נקודות קצה הלהב');

    state.scaleJpgToGreen = parsePositiveNumber(answer{5}, 'יחס המרה מ-JPG ל-GREEN');
    state.widthMM = parsePositiveNumber(answer{6}, 'רוחב מלבן הכיול');
    state.heightMM = parsePositiveNumber(answer{7}, 'גובה מלבן הכיול');
    state.targetH = round(parsePositiveNumber(answer{8}, 'גובה יעד'));
end

function state = askMeasurement(state)

    prompt = { ...
        ['שיטת דגימה:' newline ...
         'linear = דגימה אינטרפולטיבית על קו דק' newline ...
         'window = ממוצע בחלון פיקסלים סביב הקו'], ...
        'winLeftX - פיקסלים שמאלה מהקו, רק במצב window:', ...
        'winRightX - פיקסלים ימינה מהקו, רק במצב window:', ...
        'halfWinY - פיקסלים מעל ומתחת, רק במצב window:', ...
        'מרווח דגימה לאורך הלהב בפיקסלים מיושרים. 1 = כל פיקסל:', ...
        'שיטת החלקה: gaussian / movmean / median / none:', ...
        'עוצמת החלקה, למשל 7:', ...
        'תוספת לשם קובץ הפלט, למשל linear_gauss7:' ...
    };

    defaultsCell = { ...
        asChar(fieldOr(state, 'samplingMode', 'linear')), ...
        num2str(fieldOr(state, 'winLeftX', 2)), ...
        num2str(fieldOr(state, 'winRightX', 2)), ...
        num2str(fieldOr(state, 'halfWinY', 1)), ...
        num2str(fieldOr(state, 'sampleStepPix', 1)), ...
        asChar(fieldOr(state, 'smoothing', 'gaussian')), ...
        num2str(fieldOr(state, 'smoothK', 7)), ...
        asChar(fieldOr(state, 'saveSuffix', 'linear_gauss7')) ...
    };

    dims = [ ...
        3 75; ...
        1 75; ...
        1 75; ...
        1 75; ...
        1 75; ...
        1 75; ...
        1 75; ...
        1 75 ...
    ];

    answer = inputdlg(prompt, 'פרמטרי מדידה והחלקה', dims, defaultsCell);

    if isempty(answer)
        error('הפעולה בוטלה.');
    end

    state.samplingMode = lower(strtrim(asChar(answer{1})));
    state.winLeftX = round(parseNonNegativeNumber(answer{2}, 'winLeftX'));
    state.winRightX = round(parseNonNegativeNumber(answer{3}, 'winRightX'));
    state.halfWinY = round(parseNonNegativeNumber(answer{4}, 'halfWinY'));
    state.sampleStepPix = parsePositiveNumber(answer{5}, 'מרווח הדגימה');
    state.smoothing = lower(strtrim(asChar(answer{6})));
    state.smoothK = round(parsePositiveNumber(answer{7}, 'עוצמת ההחלקה'));
    state.saveSuffix = strtrim(asChar(answer{8}));

    validateMeasurementState(state);
end

% =====================================================================
% Session construction and profile run
% =====================================================================

function session = buildSession(state)

    fprintf('קורא NEF ומחלץ ערוץ GREEN...\n');

    green_full = raw2green(state.nefPath);
    [Hg, Wg] = size(green_full);

    rect4_green = state.rect4_jpg * state.scaleJpgToGreen;
    blade2_green = state.blade2_jpg * state.scaleJpgToGreen;

    pixPerMM = state.targetH / state.heightMM;
    mmPerPix = 1 / pixPerMM;
    targetW = round(state.widthMM * pixPerMM);

    src = rect4_green;
    dst = [ ...
        1       1; ...
        targetW 1; ...
        targetW state.targetH; ...
        1       state.targetH ...
    ];

    tform = fitgeotrans(src, dst, 'projective');

    session = struct();
    session.nef = state.nefPath;
    session.green_full = green_full;
    session.green_size = [Hg Wg];

    session.tform = tform;
    session.pix_per_mm = pixPerMM;
    session.mm_per_pix = mmPerPix;

    session.rect4_jpg = state.rect4_jpg;
    session.blade2_jpg = state.blade2_jpg;
    session.rect4_green = rect4_green;
    session.blade2_green = blade2_green;
    session.scale_from_jpg_to_green = state.scaleJpgToGreen;

    session.widthMM = state.widthMM;
    session.heightMM = state.heightMM;
    session.targetH = state.targetH;
    session.targetW = targetW;

    session.P1_orig = blade2_green(1, :);
    session.P2_orig = blade2_green(2, :);

    session.knifeNumber = state.knifeNumber;
    session.imageName = state.imageName;

    imageToken = safeToken(state.imageName);
    knifeToken = safeToken(state.knifeNumber);

    if isempty(imageToken)
        imageToken = 'image';
    end
    if isempty(knifeToken)
        knifeToken = 'unknown';
    end

    sessionBase = sprintf('%s_session_correct_tform_knife%s', imageToken, knifeToken);
    sessionFile = fullfile(state.outDir, [sessionBase '.mat']);

    save(sessionFile, 'session');

    session.sessionBase = sessionBase;
    session.sessionFile = sessionFile;

    fprintf('נשמר session: %s\n', sessionFile);
end

function out = runProfile(state)

    if strcmpi(state.samplingMode, 'window')
        interpMode = 'none';
    else
        interpMode = 'linear';
    end

    imageToken = safeToken(state.imageName);
    knifeToken = safeToken(state.knifeNumber);
    suffixToken = safeToken(state.saveSuffix);

    if isempty(suffixToken)
        suffixToken = makeAutoSuffix(state);
    end

    profileBase = sprintf('%s_profile_knife%s_%s', imageToken, knifeToken, suffixToken);

    figureTitle = sprintf('פרופיל סכין מספר %s (תמונה %s)', ...
        state.knifeNumber, state.imageName);

    out = rerunProfile_clean_v2( ...
        state.sessionFile, ...
        'interp', interpMode, ...
        'winLeftX', state.winLeftX, ...
        'winRightX', state.winRightX, ...
        'halfWinY', state.halfWinY, ...
        'sampleStepPix', state.sampleStepPix, ...
        'smoothing', state.smoothing, ...
        'smoothK', state.smoothK, ...
        'figureTitle', figureTitle, ...
        'xLabel', 'מיקום לאורך להב הסכין [מ"מ]', ...
        'yLabel', 'Intensity (GREEN)', ...
        'rawLabel', 'Raw', ...
        'plotLabel', 'Smoothed', ...
        'showCaption', true, ...
        'saveDir', state.outDir, ...
        'saveBase', profileBase);

    out.profileBase = profileBase;
    out.state = state;

    fprintf('\nהפעולה הסתיימה.\n');
    fprintf('Session: %s\n', state.sessionFile);
    fprintf('קובץ גרף: %s.png\n', fullfile(state.outDir, profileBase));
    fprintf('קובץ נתונים: %s.mat\n', fullfile(state.outDir, profileBase));

    if isfield(out, 'x_mm') && ~isempty(out.x_mm)
        fprintf('אורך הפרופיל: %.4f mm\n', max(out.x_mm));
    end
end

function saveLastState(state, lastFile)

    save(lastFile, 'state');

    if isfield(state, 'outDir') && ~isempty(state.outDir)
        try
            save(fullfile(state.outDir, 'last_blade_profile_settings_clean.mat'), 'state');
        catch
            % Non-critical convenience copy.
        end
    end
end

% =====================================================================
% Defaults and validation
% =====================================================================

function state = defaultState()

    state = struct();

    % Geometry fields are intentionally empty in the clean version.
    % They will be filled by the user or by last_blade_profile_settings_clean.mat.
    state.knifeNumber = '';
    state.imageName = '';
    state.rect4_jpg = [];
    state.blade2_jpg = [];

    state.scaleJpgToGreen = 0.5;
    state.widthMM = 33;
    state.heightMM = 47;
    state.targetH = 650;

    state.samplingMode = 'linear';
    state.winLeftX = 2;
    state.winRightX = 2;
    state.halfWinY = 1;
    state.sampleStepPix = 1;

    state.smoothing = 'gaussian';
    state.smoothK = 7;
    state.saveSuffix = 'linear_gauss7';
end

function validateMeasurementState(state)

    if ~any(strcmpi(state.samplingMode, {'linear','window'}))
        error('שיטת הדגימה חייבת להיות linear או window.');
    end

    if ~any(strcmpi(state.smoothing, {'gaussian','movmean','median','none'}))
        error('שיטת ההחלקה חייבת להיות gaussian / movmean / median / none.');
    end

    if state.smoothK < 1
        error('עוצמת ההחלקה חייבת להיות לפחות 1.');
    end
end

% =====================================================================
% Utility functions
% =====================================================================

function requireDependency(functionName)

    if exist(functionName, 'file') ~= 2
        error('הפונקציה הדרושה לא נמצאה ב-MATLAB path: %s.m', functionName);
    end
end

function state = mergeStructs(base, newer)

    state = base;

    if ~isstruct(newer)
        return;
    end

    names = fieldnames(newer);

    for k = 1:numel(names)
        state.(names{k}) = newer.(names{k});
    end
end

function value = fieldOr(s, fieldName, defaultValue)

    if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
        value = s.(fieldName);
    else
        value = defaultValue;
    end
end

function n = parsePositiveNumber(txt, label)

    n = str2double(strrep(asChar(txt), ',', '.'));

    if isnan(n) || ~isscalar(n) || n <= 0
        error('%s חייב להיות מספר חיובי.', label);
    end
end

function n = parseNonNegativeNumber(txt, label)

    n = str2double(strrep(asChar(txt), ',', '.'));

    if isnan(n) || ~isscalar(n) || n < 0
        error('%s חייב להיות מספר לא-שלילי.', label);
    end
end

function M = parsePointMatrix(txt, expectedRows, label)

    txt = asChar(txt);
    tokens = regexp(txt, '[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?', 'match');
    nums = str2double(tokens);

    if numel(nums) ~= expectedRows * 2
        error('%s צריכות לכלול בדיוק %d מספרים, כלומר מטריצה בגודל %dx2.', ...
            label, expectedRows * 2, expectedRows);
    end

    M = reshape(nums, 2, expectedRows).';
end

function txt = matrixToText(M)

    if isempty(M)
        txt = '';
        return;
    end

    lines = strings(size(M, 1), 1);

    for k = 1:size(M, 1)
        lines(k) = sprintf('%.10g %.10g', M(k,1), M(k,2));
    end

    txt = char(strjoin(lines, newline));
end

function token = safeToken(s)

    token = regexprep(char(string(s)), '[^A-Za-z0-9_.-]', '_');
    token = regexprep(token, '_+', '_');
    token = regexprep(token, '^_|_$', '');
end

function suffix = makeAutoSuffix(state)

    if strcmpi(state.samplingMode, 'window')
        winW = state.winLeftX + 1 + state.winRightX;
        winH = 2 * state.halfWinY + 1;
        suffix = sprintf('win%dx%d_step%s_%s%d', ...
            winW, winH, numToToken(state.sampleStepPix), state.smoothing, state.smoothK);
    else
        suffix = sprintf('linear_step%s_%s%d', ...
            numToToken(state.sampleStepPix), state.smoothing, state.smoothK);
    end
end

function t = numToToken(x)

    t = strrep(num2str(x), '.', 'p');
end

function txt = asChar(x)

    if isstring(x)
        x = cellstr(x(:));
        txt = strjoin(x, newline);
        txt = char(txt);

    elseif iscell(x)
        parts = cell(size(x));
        for k = 1:numel(x)
            parts{k} = asChar(x{k});
        end
        txt = strjoin(parts(:).', newline);
        txt = char(txt);

    elseif ischar(x)
        if size(x, 1) > 1
            txt = strjoin(cellstr(x), newline);
            txt = char(txt);
        else
            txt = x;
        end

    else
        txt = char(string(x));
    end

    txt = txt(:).';
end
