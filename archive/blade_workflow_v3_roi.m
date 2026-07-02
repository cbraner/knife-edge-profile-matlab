%function [green_rect, P1, P2, mm_per_pix] = blade_workflow_v3_roi()
% ---------------------------------------------------------------
% Workflow (ROI):
% 1) בחירת קובץ NEF
% 2) RAW -> GREEN (ממוצע G1/G2)
% 3) יישור ע"י 4 נקודות ROI (drawpoint) -> projective
% 4) חישוב קנה מידה מ״מ/פיקסל ע"פ מרחק בין שתי פינות ימין של המלבן = 47.5 מ"מ
% 5) בחירת שתי נקודות קצה לאורך הלהב (drawpoint; ללא קו)
% 6) חישוב פרופיל + ציר X במ״מ לפי mm_per_pix (ללא תלות באורך להב קבוע)
% 7) שמירה: MAT + PNG + תמונה מסומנת (2 נקודות)
% 8) החזרת green_rect, P1, P2, mm_per_pix לשימוש חוזר
% ---------------------------------------------------------------

    % פרמטרים כלליים
    ref_mm_between_right_corners = 47.5;  % המרחק הפיזי הידוע בין הפסים (מ״מ)
    winLeftX  = 2;                        % חלון ממוצע שמאלה
    winRightX = 2;                        % חלון ממוצע ימינה
    halfWinY  = 1;                        % חלון ממוצע למעלה/למטה (סימטרי)

    % בחירת קובץ
    [f,p] = uigetfile({'*.NEF','Nikon RAW (*.NEF)'}, 'בחר קובץ NEF');
    if isequal(f,0); disp('בוטל.'); green_rect=[]; P1=[]; P2=[]; mm_per_pix=NaN; return; end
    nef = fullfile(p,f);

    % --- קריאת RAW והפקת GREEN ---
    raw = double(rawread(nef));      % Bayer (RGGB)
    g1  = raw(1:2:end, 2:2:end);     % Green1
    g2  = raw(2:2:end, 1:2:end);     % Green2
    M   = min(size(g1,1), size(g2,1));
    N   = min(size(g1,2), size(g2,2));
    green_full = (g1(1:M,1:N) + g2(1:M,1:N))/2;

    % --- יישור באמצעות 4 נקודות ROI ---
    figRect = figure('Name','יישור: בחר 4 פינות מלבן ייחוס','NumberTitle','off');
    set(figRect,'Units','normalized','Position',[0.05 0.05 0.9 0.85]);
    imshow(green_full,[]); axis image; hold on;
    title({'בחר 4 פינות מלבן ייחוס (עם/נגד כיוון השעון)', ...
           'ניתן לגרור נקודה לפני אישור (דאבל־קליק על נקודה לסיום גרירה)'});

    p1 = drawpoint('Color','y'); wait(p1);
    p2 = drawpoint('Color','y'); wait(p2);
    p3 = drawpoint('Color','y'); wait(p3);
    p4 = drawpoint('Color','y'); wait(p4);

    uiwait(msgbox('כוון/גרור את 4 הנקודות עד דיוק פיקסל, ואז לחץ OK להמשך.','Rectify','modal'));

    src = [p1.Position; p2.Position; p3.Position; p4.Position]; % [x y]×4

    % סדר עקבי של ארבע הנקודות: TL, TR, BR, BL
    ordered = orderQuad_TL_TR_BR_BL(src);
    TL = ordered(1,:); TR = ordered(2,:); BR = ordered(3,:); BL = ordered(4,:);

    % יעד מלבני "ישר" (orthogonal) לפי מעטפת המקור (שומר קנה מידה מקורב)
    minx=min(src(:,1)); maxx=max(src(:,1));
    miny=min(src(:,2)); maxy=max(src(:,2));
    dst = [minx miny;  maxx miny;  maxx maxy;  minx maxy];  % TL,TR,BR,BL בהתאמה

    % טרנספורמציה פרספקטיבית ויישור
    tform  = fitgeotrans([TL;TR;BR;BL], dst, 'projective');
    outRef = imref2d(size(green_full));
    green_rect = imwarp(green_full, tform, 'OutputView', outRef);

    % --- קנה מידה (מ״מ/פיקסל) ---
    % לפי הגדרת היעד: מרחק בפיקסלים בין TR ו-BR לאחר rectify הוא:
    pix_distance_right = norm(dst(3,:) - dst(2,:));   % אורך הצד הימני במערכת היעד (בפיקסלים)
    mm_per_pix = ref_mm_between_right_corners / pix_distance_right;

    % --- בחירת שתי נקודות קצה לאורך הלהב (ללא קו) ---
    g_disp = im2double(green_rect).^0.5;   % שיפור נראות בלבד
    figPts = figure('Name','בחר שתי נקודות קצה לאורך הלהב','NumberTitle','off');
    set(figPts,'Units','normalized','Position',[0.05 0.05 0.9 0.85]);
    imshow(g_disp, []); axis image; hold on;
    title({'סמן שתי נקודות קצה לאורך הלהב (מלמעלה למטה)', ...
           'ניתן לגרור כל נקודה לפני אישור'});

    a = drawpoint('Color',[1 1 0]); wait(a);
    b = drawpoint('Color',[1 1 0]); wait(b);
    uiwait(msgbox('כוון/גרור את שתי הנקודות עד דיוק פיקסל, לחץ OK להמשך.','אישור','modal'));
    P1 = a.Position;   % [x y]
    P2 = b.Position;

    % --- חישוב פרופיל לאורך הקטע בין P1 ל-P2 ---
    % ציר X במ״מ מחושב לפי mm_per_pix (לא ננעלים ל-61 מ״מ)
    [int_profile, x_mm] = bladeProfileAlongLine_mm(green_rect, P1, P2, mm_per_pix, ...
        'winLeftX', winLeftX, 'winRightX', winRightX, 'halfWinY', halfWinY);

    % --- גרף פרופיל ---
    figProf = figure('Name','Blade Profile','NumberTitle','off');
    plot(x_mm, int_profile, 'k', 'LineWidth', 1.3); grid on
    xlabel('מיקום לאורך הסכין [מ"מ]'); ylabel('Intensity (GREEN, raw units)');
    title(sprintf('Blade reflection profile – %s', f), 'Interpreter','none');

    % --- שמירה ---
    outdir = fullfile(p, 'profiles'); 
    if ~exist(outdir, 'dir'); mkdir(outdir); end
    base = erase(f, '.NEF');

    % שומרים גם את ה"session" כדי לא לבחור שוב נקודות
    session.green_rect = green_rect;
    session.P1         = P1;
    session.P2         = P2;
    session.mm_per_pix = mm_per_pix;
    session.winLeftX   = winLeftX;
    session.winRightX  = winRightX;
    session.halfWinY   = halfWinY;
    session.ref_mm_between_right_corners = ref_mm_between_right_corners;

    matPath = fullfile(outdir, [base '_profile.mat']);
    pngPath = fullfile(outdir, [base '_profile.png']);
    jpgAnno = fullfile(outdir, [base '_annotated_points.jpg']);
    sessMat = fullfile(outdir, [base '_session.mat']);

    save(matPath, 'x_mm','int_profile','P1','P2','mm_per_pix','winLeftX','winRightX','halfWinY','ref_mm_between_right_corners');
    save(sessMat, 'session');

    exportgraphics(figProf, pngPath, 'Resolution', 200);

    % תמונת אנוטציה – רק שתי נקודות (ללא קו)
    figA = figure('Visible','off'); imshow(g_disp,[]); hold on;
    scatter([P1(1) P2(1)], [P1(2) P2(2)], 28, ...
            'Marker','o', ...
            'MarkerEdgeColor',[1 1 0], 'MarkerFaceColor',[1 1 0], ...
            'MarkerEdgeAlpha',0.85, 'MarkerFaceAlpha',0.65);
    exportgraphics(gca, jpgAnno, 'Resolution', 200);
    close(figA);

    fprintf('\nנשמרו קבצים אל: %s\n- %s\n- %s\n- %s\n- %s\n', outdir, matPath, pngPath, jpgAnno, sessMat);
%end

% ===== עזר: סדר עקבי של 4 נקודות לפינות מלבן (TL,TR,BR,BL) =====
function ordered = orderQuad_TL_TR_BR_BL(pts4)
    % pts4: 4x2 [x y] ללא סדר
    % מחזיר 4x2 מסודר: TL; TR; BR; BL
    [~, idxY] = sort(pts4(:,2), 'ascend');   % קטן=למעלה
    top2    = pts4(idxY(1:2), :);
    bottom2 = pts4(idxY(3:4), :);
    [~,it]  = sort(top2(:,1), 'ascend');     % קטן=שמאל
    TL = top2(it(1),:); TR = top2(it(2),:);
    [~,ib]  = sort(bottom2(:,1), 'ascend');
    BL = bottom2(ib(1),:); BR = bottom2(ib(2),:);
    ordered = [TL; TR; BR; BL];
end

% ===== עזר: חישוב פרופיל עם ציר במ״מ (קנה מידה נתון) =====
function [int_profile, x_mm] = bladeProfileAlongLine_mm(img, P1, P2, mm_per_pix, varargin)
    p = inputParser;
    addParameter(p,'winLeftX',2,@isscalar);
    addParameter(p,'winRightX',2,@isscalar);
    addParameter(p,'halfWinY',1,@isscalar);
    parse(p,varargin{:});
    wL = p.Results.winLeftX;  wR = p.Results.winRightX;  hY = p.Results.halfWinY;

    img = double(img);
    [H,W] = size(img);

    % אורך הקטע בפיקסלים והמרה למ״מ:
    len_pix = hypot(P2(1)-P1(1), P2(2)-P1(2));
    len_mm  = len_pix * mm_per_pix;

    % דגימה נקודתית לאורך הקו (מספר דגימות ≈ אורך בפיקסלים)
    numSamples = max(round(len_pix), 2);
    xg = linspace(P1(1), P2(1), numSamples).';   % עמודות
    yg = linspace(P1(2), P2(2), numSamples).';   % שורות

    int_profile = zeros(numSamples,1);
    for i = 1:numSamples
        x0 = min(max(round(xg(i)),1), W);
        y0 = min(max(round(yg(i)),1), H);
        xs = max(1, x0 - wL) : min(W, x0 + wR);
        ys = max(1, y0 - hY) : min(H, y0 + hY);
        int_profile(i) = mean(img(ys, xs), 'all');
    end

    % ציר X במ״מ לפי mm_per_pix (לא לפי אורך להב קבוע מראש)
    x_mm = linspace(0, len_mm, numSamples).';
end
