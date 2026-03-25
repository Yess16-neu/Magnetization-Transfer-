#!/usr/bin/env bash
# MTR  pipeline
# Autor: Yessenia Garcia Rizo

Usage() {
cat <<USAGE
Usage:
  $(basename "$0") -i input4D [options]

Example:
  $(basename "$0") -i input.nii.gz -r 1 -d 1

Compulsory arguments:
  -i    Input 4D image (PD MT dataset)

Optional arguments:
  -r    Perform registration (0/1) [default: 0]
  -d    Apply denoising (0/1) [default: 1]
  -o    Output MTR filename [default: MTR.nii.gz]
  -h    Show this help

Pipeline:
  1) Split MT volumes
  2) Optional registration (FLIRT)
  3) Optional denoising (ANTs)
  4) MTR computation

USAGE
exit 1
}


# Defaults

register=0
denoise=1
output="MTR.nii.gz"


while getopts ":i:r:d:o:h" opt; do
  case "$opt" in
    i) input="$OPTARG" ;;
    r) register="$OPTARG" ;;
    d) denoise="$OPTARG" ;;
    o) output="$OPTARG" ;;
    h) Usage ;;
    \?) echo "Invalid option: -$OPTARG"; Usage ;;
    :) echo "Option -$OPTARG requires an argument"; Usage ;;
  esac
done


# Validations

[[ -z "$input" ]] && { echo "Error: missing -i"; Usage; }

if [[ ! -f "$input" ]]; then
  echo "Error: input file not found: $input"
  exit 1
fi


echo "      MTR Processing Pipeline"



# STEP 1: Split volumes

echo "[1/4] Splitting MT volumes..."

mrconvert "$input" imagen_sin_saturacion.nii.gz -coord 3 0
mrconvert "$input" imagen_con_saturacion.nii.gz -coord 3 1


# STEP 2: Registration

if [[ "$register" -eq 1 ]]; then
  echo "[2/4] Registration (FLIRT)..."

  flirt \
    -in imagen_con_saturacion.nii.gz \
    -ref imagen_sin_saturacion.nii.gz \
    -out imagen_con_saturacion_reg.nii.gz \
    -dof 7 \
    -cost mutualinfo

  sat_img="imagen_con_saturacion_reg.nii.gz"
else
  echo "[2/4] Skipping registration"
  sat_img="imagen_con_saturacion.nii.gz"
fi


# STEP 3: Denoising

if [[ "$denoise" -eq 1 ]]; then
  echo "[3/4] Denoising..."

  DenoiseImage -d 3 \
    -i "$sat_img" \
    -o imagen_con_pulso_denoiseada.nii.gz

  DenoiseImage -d 3 \
    -i imagen_sin_saturacion.nii.gz \
    -o imagen_sin_pulso_denoiseada.nii.gz

  sin_img="imagen_sin_pulso_denoiseada.nii.gz"
  con_img="imagen_con_pulso_denoiseada.nii.gz"
else
  echo "[3/4] Skipping denoising"

  sin_img="imagen_sin_saturacion.nii.gz"
  con_img="$sat_img"
fi


echo "[4/4] Generando mapa de MTR..."

mrcalc "$sin_img" "$con_img" \
  -sub "$sin_img" \
  -div 100 \
  -mul "$output"


echo " MTR generado: $output"
