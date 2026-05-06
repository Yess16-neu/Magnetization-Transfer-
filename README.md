# MTR Processing Pipeline

This repository contains a Bash pipeline for generating Magnetization Transfer Ratio (MTR) maps from a 4D MRI image acquired with and without a magnetization transfer saturation pulse.

## Overview

The script performs the following steps:

1. Splits a 4D input image into two 3D volumes:
   - Image without saturation pulse
   - Image with saturation pulse
2. Optionally registers the saturation image to the non-saturation image using FSL FLIRT.
3. Optionally applies denoising using ANTs `DenoiseImage`.
4. Computes the MTR map voxel by voxel using:

\[
MTR = \frac{M_0 - M_{SAT}}{M_0} \times 100
\]

where:

- `M0` is the image acquired without the saturation pulse.
- `MSAT` is the image acquired with the saturation pulse.

## Requirements

This pipeline requires the following software to be installed and available in your system path:

- [MRtrix3](https://www.mrtrix.org/)
  - `mrconvert`
  - `mrcalc`
- [FSL](https://fsl.fmrib.ox.ac.uk/fsl/)
  - `flirt`
- [ANTs](https://github.com/ANTsX/ANTs)
  - `DenoiseImage`
- Bash shell

## Input data

The input must be a 4D NIfTI image containing two volumes:

| Volume | Description |
|---|---|
| Volume 0 | Image without saturation pulse |
| Volume 1 | Image with saturation pulse |

The expected input format is:
input.nii.gz


## Usage
./Mapa_MTR.sh -i input4D.nii.gz [options]

### Required argument
|Argument |	Description |
|---|---|
|-i	|Input 4D NIfTI image|


### Optional arguments
|Argument |	Description	| Default |
|---|---|---|
|-r	|Perform registration using FLIRT: 0 = no, 1 = yes|	0|
|-d	|Apply denoising using ANTs: 0 = no, 1 = yes|	1|
|-o	|Output MTR filename|	MTR.nii.gz|
|-h	|Show help message|	—


#### Example

##### Run the pipeline without registration and with denoising:

./mtr_pipeline.sh -i input.nii.gz

##### Run the pipeline with registration and denoising:

./mtr_pipeline.sh -i input.nii.gz -r 1 -d 1 -o MTR_output.nii.gz

##### Run the pipeline without denoising:

./mtr_pipeline.sh -i input.nii.gz -d 0

### Output

The main output is the MTR map:

MTR.nii.gz  or the filename specified with the -o option.

The pipeline also generates intermediate files:

imagen_sin_saturacion.nii.gz

imagen_con_saturacion.nii.gz

imagen_con_saturacion_reg.nii.gz

imagen_sin_pulso_denoiseada.nii.gz

imagen_con_pulso_denoiseada.nii.gz

Depending on the selected options, some intermediate files may not be generated.

## Notes
Registration is optional and should be used when the image with saturation pulse is not spatially aligned with the image without saturation pulse.
Denoising is enabled by default.

The MTR map is expressed as a percentage.

The input image must contain the non-saturated image as the first volume and the saturated image as the second volume.
