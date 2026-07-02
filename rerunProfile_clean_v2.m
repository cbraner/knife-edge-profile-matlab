function out = rerunProfile_clean_v2(sessionFile, varargin)
% ================================================================
% rerunProfile_clean_v2
%
% מחשב פרופיל להב מתוך session ומצייר גרף נקי.
% כולל שליטה ב:
%   1. שיטת דגימה:
%      interp='linear'  -> דגימה אינטרפולטיבית על קו דק
%      interp='none'    -> ממוצע בחלון פיקסלים סביב הקו
%
%   2. חלון הדגימה במקרה של interp='none':
%      winLeftX, winRightX, halfWinY
%
%   3. מרווח הדגימה לאורך הלהב:
%      sampleStepPix = 1  -> דגימה בכל פיקסל מיושר בערך
%      sampleStepPix = 2  -> דגימה כל שני פיקסלים מיושרים בערך
%
% דוגמה לחלון 7x5:
% out = rerunProfile_clean_v2(sessionFile, ...
%     'interp','none', 'winLeftX',3, 'winRightX',3, 'halfWinY',2, ...
%     'sampleStepPix',1, ...
%     'smoothing','gaussian','smoothK',7);
% ================================================================

    p = inputParser;

    % חלון מיצוע / דגימה
    addParameter(p,'winLeftX',2,@isscalar);
    addParameter(p,'winRightX',2,@isscalar);
    addParameter(p,'halfWinY',1,@isscalar);
    addParameter(p,'interp','linear',@(s)ischar(s)||isstring(s));
    addParameter(p,'sampleStepPix',1,@isscalar);

    % החלקה
    addParameter(p,'smoothing','none',@(s)ischar(s)||isstring(s));
    addParameter(p,'smoothK',7,@isscalar);

    % ציור
    addParameter(p,'doPlot',true,@islogical);
    addParameter(p,'plotMode','new',@(s)any(strcmpi(s,{'new','overlay'})));
    addParameter(p,'ax',[]);
    addParameter(p,'plotColor',[0 0 0],@(v)isnumeric(v)&&numel(v)==3);
    addParameter(p,'rawColor',[0.7 0 0],@(v)isnumeric(v)&&numel(v)==3);
    addParameter(p,'showRaw',true,@islogical);
    addParameter(p,'showLegend',true,@islogical);
    addParameter(p,'plotLabel','Smoothed',@(s)ischar(s)||isstring(s));
    addParameter(p,'rawLabel','Raw',@(s)ischar(s)||isstring(s));
    addParameter(p,'figureTitle','',@(s)ischar(s)||isstring(s));
    addParameter(p,'xLabel','מיקום לאורך להב הסכין [מ"מ]',@(s)ischar(s)||isstring(s));
    addParameter(p,'yLabel','Intensity (GREEN)',@(s)ischar(s)||isstring(s));
    addParameter(p,'showCaption',true,@islogical);
    addParameter(p,'caption','auto');

    % שמירה
    addParameter(p,'saveDir','',@(s)ischar(s)||isstring(s));
    addParameter(p,'saveBase','',@(s)ischar(s)||isstring(s));
    addParameter(p,'saveMat',true,@islogical);
    addParameter(p,'savePng',true,@islogical);
    addParameter(p,'pngResolution',200,@isscalar);

    parse(p,varargin{:});
    prm = p.Results;

    if prm.sampleStepPix <= 0
        error('sampleStepPix חייב להיות מספר חיובי.');
    end

    % ---- טעינת session ----
    S = load(sessionFile, 'session');
    sess = S.session;

    % ---- חישוב פרופיל על המקור עם סרגל מתוקן ----
    [x_mm, prof_raw] = profileOnOriginalUsingRectifiedRuler_local( ...
        sess.green_full, sess.tform, sess.mm_per_pix, ...
        sess.P1_orig, sess.P2_orig, ...
        'winLeftX',prm.winLeftX, ...
        'winRightX',prm.winRightX, ...
        'halfWinY',prm.halfWinY, ...
        'interp',prm.interp, ...
        'sampleStepPix',prm.sampleStepPix);

    % ---- החלקה ----
    switch lower(string(prm.smoothing))
        case "movmean"
            prof_s = movmean(prof_raw, prm.smoothK);
        case "median"
            prof_s = medfilt1(prof_raw, prm.smoothK);
        case "gaussian"
            prof_s = smoothdata(prof_raw, 'gaussian', prm.smoothK);
        otherwise
            prof_s = prof_raw;
    end

    % ---- פלט נתונים ----
    out = struct();
    out.x_mm           = x_mm;
    out.profile_raw    = prof_raw;
    out.profile_smooth = prof_s;
    out.params         = prm;
    out.P1_orig        = sess.P1_orig;
    out.P2_orig        = sess.P2_orig;
    out.mm_per_pix     = sess.mm_per_pix;
    out.sessionFile    = sessionFile;

    % ---- ציור נקי, אם נדרש ----
    fig = [];
    ax = [];

    if prm.doPlot
        switch lower(string(prm.plotMode))
            case "overlay"
                if isempty(prm.ax) || ~isvalid(prm.ax)
                    fig = figure('Name','Blade Profile','NumberTitle','off');
                    ax = gca;
                    hold(ax,'on'); grid(ax,'on');
                    xlabel(ax,prm.xLabel,'Interpreter','none');
                    ylabel(ax,prm.yLabel,'Interpreter','none');
                    if strlength(string(prm.figureTitle)) > 0
                        title(ax,prm.figureTitle,'Interpreter','none');
                    end
                else
                    ax = prm.ax;
                    fig = ancestor(ax,'figure');
                    hold(ax,'on'); grid(ax,'on');
                end

                plot(ax, x_mm, prof_s, ...
                    'LineWidth',1.25, ...
                    'Color',prm.plotColor, ...
                    'DisplayName',char(prm.plotLabel));

                if prm.showLegend
                    legend(ax,'Location','best');
                end

            otherwise
                fig = figure('Name','Blade Profile','NumberTitle','off');
                ax = axes(fig);
                hold(ax,'on'); grid(ax,'on');

                if prm.showRaw
                    plot(ax, x_mm, prof_raw, ...
                        'Color',prm.rawColor, ...
                        'LineWidth',0.9, ...
                        'DisplayName',char(prm.rawLabel));
                end

                plot(ax, x_mm, prof_s, ...
                    'Color',prm.plotColor, ...
                    'LineWidth',1.25, ...
                    'DisplayName',char(prm.plotLabel));

                title(ax, prm.figureTitle, 'Interpreter','none');
                xlabel(ax, prm.xLabel, 'Interpreter','none');
                ylabel(ax, prm.yLabel, 'Interpreter','none');

                if prm.showLegend
                    legend(ax,'Location','best');
                end

                % רווח מסודר לכיתוב תחתון
                set(fig, 'Units','normalized', 'Position',[0.10 0.10 0.75 0.75]);
                set(ax, 'Units','normalized');

                if prm.showCaption
                    ax.Position = [0.12 0.24 0.82 0.62];

                    cap = prm.caption;
                    if ischar(cap) || isstring(cap)
                        if strcmpi(string(cap),'auto')
                            cap = makeAutoCaption_local(prm, sess);
                        else
                            cap = cellstr(cap);
                        end
                    end

                    annotation(fig,'textbox',[0.07 0.03 0.86 0.08], ...
                        'String',cap, ...
                        'Interpreter','none', ...
                        'HorizontalAlignment','center', ...
                        'VerticalAlignment','middle', ...
                        'EdgeColor','none', ...
                        'FontSize',9);
                else
                    ax.Position = [0.12 0.16 0.82 0.70];
                end
        end
    end

    out.figure = fig;
    out.axes   = ax;

    % ---- שמירה ----
    if ~isempty(prm.saveDir)
        if ~exist(prm.saveDir,'dir')
            mkdir(prm.saveDir);
        end

        saveBase = char(prm.saveBase);
        if isempty(saveBase)
            saveBase = getBase_local(sessionFile);
        end

        if prm.savePng && prm.doPlot
            pngPath = fullfile(prm.saveDir, [saveBase '.png']);
            exportgraphics(fig, pngPath, 'Resolution', prm.pngResolution);
            out.pngPath = pngPath;
        end

        if prm.saveMat
            matPath = fullfile(prm.saveDir, [saveBase '.mat']);
            out_save = out;
            if isfield(out_save,'figure'), out_save = rmfield(out_save,'figure'); end
            if isfield(out_save,'axes'),   out_save = rmfield(out_save,'axes');   end
            save(matPath, '-struct', 'out_save');
            out.matPath = matPath;
        end

        fprintf('נשמרו קובצי פרופיל בתיקייה: %s\n', prm.saveDir);
    end
end

% ================================================================
% עזר: פרופיל על המקור עם סרגל אחיד לפי טרנספורמציית יישור
% ================================================================
function [x_mm, int_profile] = profileOnOriginalUsingRectifiedRuler_local( ...
        img_orig, tform, mm_per_pix, P1_orig, P2_orig, varargin)

    q = inputParser;
    addParameter(q,'winLeftX',2,@isscalar);
    addParameter(q,'winRightX',2,@isscalar);
    addParameter(q,'halfWinY',1,@isscalar);
    addParameter(q,'interp','linear',@(s)ischar(s)||isstring(s));
    addParameter(q,'sampleStepPix',1,@isscalar);
    parse(q,varargin{:});
    prm = q.Results;

    img = double(img_orig);
    [H,W] = size(img);

    % ממפים את קצות הלהב למרחב המיושר
    [x1r,y1r] = transformPointsForward(tform, P1_orig(1), P1_orig(2));
    [x2r,y2r] = transformPointsForward(tform, P2_orig(1), P2_orig(2));

    len_rect_pix = hypot(x2r - x1r, y2r - y1r);

    sampleStepPix = max(double(prm.sampleStepPix), eps);
    numSamples = max(floor(len_rect_pix / sampleStepPix) + 1, 2);

    if len_rect_pix == 0
        error('אורך קו הלהב הוא 0. בדוק את נקודות P1/P2.');
    end

    t = linspace(0, 1, numSamples).';
    xr = x1r + t * (x2r - x1r);
    yr = y1r + t * (y2r - y1r);

    % ממפים את נקודות הדגימה חזרה למקור
    [xo, yo] = transformPointsInverse(tform, xr, yr);

    int_profile = zeros(numSamples,1);

    if ~strcmpi(prm.interp,'none')
        % דגימה אינטרפולטיבית על קו דק
        [Xg,Yg] = meshgrid(1:W, 1:H);
        for i = 1:numSamples
            int_profile(i) = interp2(Xg, Yg, img, xo(i), yo(i), prm.interp, 0);
        end
    else
        % ממוצע בחלון פיקסלים סביב נקודת הדגימה
        wL = round(prm.winLeftX);
        wR = round(prm.winRightX);
        hY = round(prm.halfWinY);

        for i = 1:numSamples
            x0 = min(max(round(xo(i)),1), W);
            y0 = min(max(round(yo(i)),1), H);
            xs = max(1, x0-wL):min(W, x0+wR);
            ys = max(1, y0-hY):min(H, y0+hY);
            int_profile(i) = mean(img(ys, xs), 'all');
        end
    end

    total_len_mm = len_rect_pix * mm_per_pix;
    x_mm = linspace(0, total_len_mm, numSamples).';
end

% ================================================================
% כיתוב אוטומטי לתחתית הגרף
% ================================================================
function cap = makeAutoCaption_local(prm, sess)
    if strcmpi(prm.interp,'none')
        winW = round(prm.winLeftX) + 1 + round(prm.winRightX);
        winH = 2*round(prm.halfWinY) + 1;
        samplingLine = sprintf( ...
            'sampling=window mean %dx%d px | step=%.3g rectified px | smooth=%s(k=%d)', ...
            winW, winH, prm.sampleStepPix, string(prm.smoothing), prm.smoothK);
    else
        samplingLine = sprintf( ...
            'sampling=interpolated line (%s) | step=%.3g rectified px | smooth=%s(k=%d)', ...
            string(prm.interp), prm.sampleStepPix, string(prm.smoothing), prm.smoothK);
    end

    cap = {
        samplingLine
        sprintf('P1=(%.1f,%.1f), P2=(%.1f,%.1f) | mm/px=%.6f', ...
            sess.P1_orig(1), sess.P1_orig(2), ...
            sess.P2_orig(1), sess.P2_orig(2), ...
            sess.mm_per_pix)
    };
end

% ================================================================
% עזר: שם בסיס מקובץ
% ================================================================
function b = getBase_local(pathstr)
    [~,name,~] = fileparts(char(pathstr));
    b = name;
end
