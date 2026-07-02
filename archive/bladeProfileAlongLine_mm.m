function out_mat = bladeProfileAlongLine_mm(img, P1, P2, mm_per_pix, varargin)
% out_mat: N×2  [ x_mm , intensity ]
    p = inputParser;
    addParameter(p,'winLeftX',2,@isscalar);
    addParameter(p,'winRightX',2,@isscalar);
    addParameter(p,'halfWinY',1,@isscalar);
    parse(p,varargin{:});
    wL = p.Results.winLeftX;  wR = p.Results.winRightX;  hY = p.Results.halfWinY;

    img = double(img);
    [H,W] = size(img);

    len_pix = hypot(P2(1)-P1(1), P2(2)-P1(2));
    len_mm  = len_pix * mm_per_pix;

    numSamples = max(round(len_pix), 2);
    xg = linspace(P1(1), P2(1), numSamples).';
    yg = linspace(P1(2), P2(2), numSamples).';

    prof = zeros(numSamples,1);
    for i = 1:numSamples
        x0 = min(max(round(xg(i)),1), W);
        y0 = min(max(round(yg(i)),1), H);
        xs = max(1, x0 - wL) : min(W, x0 + wR);
        ys = max(1, y0 - hY) : min(H, y0 + hY);
        prof(i) = mean(img(ys, xs), 'all');
    end

    x_mm = linspace(0, len_mm, numSamples).';
    out_mat = [x_mm, prof];
end
