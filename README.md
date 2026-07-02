# knife-edge-profile-matlab
MATLAB code for optical blade-edge profile analysis

This repository contains MATLAB code used for extracting a one-dimensional intensity profile along a knife blade from Nikon RAW/NEF images.

Main files:
- makeBladeProfile_clean.m — main wrapper for selecting image, entering calibration points, creating session, and running profile extraction.
- raw2green.m — extracts the green channel from the RAW image.
- rerunProfile_clean_v2.m — computes the intensity profile along the blade, applies optional smoothing, plots and saves the output.
- showRectifiedGreenImage.m — displays the rectified green-channel image.
- plotProfileSegment_simple.m — plots selected profile segments from saved profile data.

The code was used as part of a master's thesis on optical detection of defects in knife blades.
