# Knife Edge Profile MATLAB Code

This repository contains MATLAB code used for image processing and optical profile extraction in a master's thesis on the optical detection of defects in knife blades used for ritual slaughter.

The code was developed as a research tool for processing blade images, performing geometric calibration, extracting a one-dimensional reflected-light intensity profile along the blade edge, and comparing optical results with microscopic documentation.

## Main MATLAB files

### `makeBladeProfile_clean.m`

Main wrapper program for the reflected-light blade profile analysis.

This script manages the workflow:

* selecting a Nikon RAW/NEF image;
* entering geometric calibration points;
* defining the blade-edge line;
* setting sampling and smoothing parameters;
* creating and saving a `session` file;
* running the profile extraction process.

The program allows either a new analysis or a repeated run using the last saved session with different sampling or smoothing parameters.

### `raw2green.m`

Pre-processing function for extracting the green channel from the RAW image.

The reflected-light profile analysis is performed on the green-channel intensity data rather than on a processed RGB/JPG image. The extracted green image is stored in the session file and used as the basis for profile measurement.

### `rerunProfile_clean_v2.m`

Core profile extraction function.

This function loads the saved session, maps the blade-edge endpoints into the rectified coordinate system, samples the green-channel intensity along the blade edge, applies optional smoothing, plots the profile, and saves the numerical and graphical output.

The output includes:

* `x_mm` — position along the blade edge in millimeters;
* `profile_raw` — raw intensity profile;
* `profile_smooth` — smoothed intensity profile;
* analysis parameters and related metadata.

### `showRectifiedGreenImage.m`

Utility script for visual quality control of the geometric calibration.

This script displays the rectified green-channel image and marks the calibration rectangle and the blade-edge line used for sampling. It was used to verify that the calibration transform and blade-edge coordinates were correctly defined.

### `plotProfileSegment_simple.m`

Utility script for plotting selected segments of an already computed profile.

This script loads a saved profile file and allows the user to display only a selected interval along the blade, such as 20–30 mm. It can display the raw profile, the smoothed profile, or both, and can save the selected segment as a new figure and data table.

### `KnifeEdgeAnalyzer.m`

Utility script for analyzing microscope images of blade-edge defects.

This script was used to measure local defect geometry in microscope images. It detects the blade edge in a selected region, allows the user to define baseline regions on both sides of a defect, calculates the maximum defect depth relative to the fitted baseline, and converts the result from pixels to millimeters according to the microscope-image scale.

This tool was used as a complementary method for documenting and measuring defects observed under the microscope, and for comparison with the reflected-light profile results.

## Archive folder

The `archive` folder contains earlier or experimental MATLAB code versions.

These files were used during development and testing, including attempts at more automatic edge detection or interactive point selection. They were not used as the basis for the final quantitative analysis in the thesis.

## Notes

The main analysis used in the thesis is based on the files in the root folder of this repository. The code is provided for transparency and reproducibility of the image-processing workflow.

The MATLAB code assumes that the required image files and session/profile files are available locally. Large image data files, RAW images, and experimental datasets are not necessarily included in this repository.

## Repository purpose

This repository serves as a digital appendix to the thesis. It documents the MATLAB code used for:

* optical profile extraction along knife blade edges;
* geometric calibration and rectification;
* reflected-light intensity analysis;
* profile smoothing and segment inspection;
* microscope-image defect measurement.
