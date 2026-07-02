function [distanceMM, intensity] = calculateProfileWithPerspective(...
    originalImage, rectifiedImage, profilePoints, tform, mmPerPixel, spatialRef)
% calculateProfileWithPerspective - חישוב פרופיל עוצמה עם תיקון פרספקטיבה
%
% Inputs:
%   originalImage   - תמונה מקורית
%   rectifiedImage  - תמונה מיישרת
%   profilePoints   - 2×2: [x1,y1; x2,y2] בקואורדינטות תמונה מיישרת
%   tform           - טרנספורמציה
%   mmPerPixel      - גורם המרה
%   spatialRef      - ייחוס מרחבי

    fprintf('\n=== חישוב פרופיל עם תיקון פרספקטיבה ===\n');
    
    x1_rect = profilePoints(1,1);
    y1_rect = profilePoints(1,2);
    x2_rect = profilePoints(2,1);
    y2_rect = profilePoints(2,2);
    
    % אורך הקו בתמונה המיישרת
    lineLengthPixels = sqrt((x2_rect - x1_rect)^2 + (y2_rect - y1_rect)^2);
    numPoints = round(lineLengthPixels);
    
    fprintf('אורך קו: %.2f פיקסלים, %d נקודות דגימה\n', lineLengthPixels, numPoints);
    
    % נקודות לאורך הקו (קואורדינטות תמונה מיישרת)
    t = linspace(0, 1, numPoints);
    xPoints_rect = x1_rect + t * (x2_rect - x1_rect);
    yPoints_rect = y1_rect + t * (y2_rect - y1_rect);
    
    % המרה לקואורדינטות עולם
    [xWorld, yWorld] = intrinsicToWorld(spatialRef, xPoints_rect', yPoints_rect');
    
    % טרנספורמציה הפוכה לתמונה מקורית
    [xPoints_orig, yPoints_orig] = transformPointsInverse(tform, xWorld, yWorld);
    
    fprintf('טרנספורמציה הפוכה הושלמה\n');
    
    % קריאת עוצמה
    [X, Y] = meshgrid(1:size(originalImage,2), 1:size(originalImage,1));
    intensity = interp2(X, Y, double(originalImage), xPoints_orig, yPoints_orig, 'linear');
    
    % טיפול ב-NaN
    validPoints = ~isnan(intensity);
    if sum(~validPoints) > 0
        fprintf('⚠ %d נקודות מחוץ לתמונה\n', sum(~validPoints));
        intensity(~validPoints) = interp1(find(validPoints), intensity(validPoints), ...
                                          find(~validPoints), 'nearest', 'extrap');
    end
    
    % מרחקים במ"מ
    distancePixels = linspace(0, lineLengthPixels, numPoints);
    distanceMM = distancePixels * mmPerPixel;
    
    fprintf('אורך קו: %.2f מ"מ\n', distanceMM(end));
    fprintf('עוצמה: min=%.1f, max=%.1f\n\n', min(intensity), max(intensity));
    
end