# Magnetization Transfer MRI Pipelines

This repository contains Bash and MATLAB pipelines for processing magnetization transfer MRI data and generating quantitative or semi-quantitative maps related to white matter and myelin-sensitive imaging.

The repository includes pipelines for:

- **MTR**: Magnetization Transfer Ratio
- **MTSat**: Magnetization Transfer Saturation
- **RF local / B1 mapping**: B1 map generation from DREAM acquisition data

## Repository structure

```text
Magnetization-Transfer-
├── Magnetization_transfer.md
├── MTR/
│   ├── MTR.md
│   └── Mapa_MTR.sh
├── MTSAT/
│   ├── MTSAT.md
│   ├── Mapa_MTSat.sh
│   └── matlab/
│       ├── nii2mtsat.m
│       └── calcMTsat.m
    └── RFlocal/
     ├── RFlocal.md
     └── RFlocal.sh
```

## Pipelines

### 1. MTR pipeline

The MTR pipeline generates Magnetization Transfer Ratio maps from a 4D image containing two volumes:

| Volume | Description |
|---|---|
| Volume 0 | Image without saturation pulse |
| Volume 1 | Image with saturation pulse |

The MTR map is computed voxel by voxel using:

```text
MTR = ((M0 - MSAT) / M0) × 100
```

where:

- `M0` is the image acquired without the saturation pulse.
- `MSAT` is the image acquired with the saturation pulse.

See the full documentation here:

[MTR pipeline documentation](MTR/MTR.md)

---

### 2. RF local / B1 map pipeline

The RF local pipeline generates a B1 map from DREAM acquisition data. It uses the STE and FID volumes, extracts the `SteamPulse` value from the Bruker `method` file, concatenates the volumes, and runs `qi dream`.

The resulting B1 map can be used as the RF local map required for B1 correction in the MTSat pipeline.

See the full documentation here:

[RF local / B1 pipeline documentation](MTSAT/Rflocal.md)

---

### 3. MTSat pipeline

The MTSat pipeline generates Magnetization Transfer Saturation maps using:

| Input | Description |
|---|---|
| PD/MTSat 4D image | Image containing MT-off and MT-on volumes |
| T1-weighted image | T1-weighted acquisition |
| B1 / RF local map | B1 correction map |
| Bruker `acqp` files | Acquisition parameters |
| MATLAB functions | `nii2mtsat.m` and `calcMTsat.m` |

The pipeline prepares the images, performs registration, reapplies intensity scaling, extracts acquisition parameters, applies denoising, and calls MATLAB to compute the final MTSat map.

See the full documentation here:

[MTSat pipeline documentation](MTSAT/MTSAT.md)

## Requirements

Depending on the pipeline, the following tools are required:

- MRtrix3
  - `mrconvert`
  - `mrcalc`
  - `mrinfo`
  - `mrcat`
- FSL
  - `flirt`
- ANTs
  - `DenoiseImage`
- QUIT / QI
  - `qi`
- MATLAB
- Bash

Make sure all required commands are available in your system `PATH` before running the scripts.

## General workflow

A typical workflow may include:

1. Generate the RF local / B1 map using the DREAM acquisition:

```bash
./RFlocal/RFlocal.sh -s STE.nii.gz -f FID.nii.gz -m method
```

2. Generate the MTR map:

```bash
./MTR/Mapa_MTR.sh -i input4D.nii.gz -r 1 -d 1 -o MTR_output.nii.gz
```

3. Generate the MTSat map:

```bash
./MTSAT/Mapa_MTSat.sh \
  -p sag_FLASH_PD_Mtsat.nii.gz \
  -t sag_FLASH_T1.nii.gz \
  -b prefixdream_B1map.nii.gz \
  -a acqpPD \
  -A acqpT1 \
  -g 0 \
  -m ./MTSAT/matlab
```

## Important notes

- The input images should be visually inspected before and after preprocessing.
- The RF local / B1 map should correspond to the same subject and acquisition session as the images used for MTSat.
- The MATLAB functions `nii2mtsat.m` and `calcMTsat.m` must be located in the same folder.
- Running the scripts multiple times in the same directory may overwrite intermediate files.


## Outputs

The main outputs are:

| Pipeline | Output |
|---|---|
| MTR | MTR map |
| RF local / B1 | B1 map and flip angle map |
| MTSat | MTSat map |

## Author

Yessenia García Rizo
