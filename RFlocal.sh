#!/usr/bin/env bash

Usage() {
    cat <<USAGE
Usage:
  $(basename "$0") -s STE -f FID -m METHOD [-o output_prefix] [-e script]

Example:
  $(basename "$0") \
    -s STE.nii.gz \
    -f FID.nii.gz \
    -m /ruta/method \
    -o prefixdream \
    -e Mapa_B1_dream.sh

Compulsory arguments:
  -s    Volumen STE (ej: STE.nii.gz)
  -f    Volumen FID (ej: FID.nii.gz)
  -m    Archivo 'method' del mapa B1

Optional arguments:
  -o    Prefijo de salida (default: prefixdream)
  -e    Script original (default: Mapa_B1_dream.sh)
  -h    Mostrar ayuda

Notes:
  - Este wrapper NO modifica tu script original
  - Internamente pasa los valores por stdin
USAGE
    exit 1
}

# Defaults
output="prefixdream"
script="Mapa_B1_dream.sh"

# Parse args
while getopts ":s:f:m:o:e:h" opt; do
    case "$opt" in
        s) vol_STE="$OPTARG" ;;
        f) vol_FID="$OPTARG" ;;
        m) method="$OPTARG" ;;
        o) output="$OPTARG" ;;
        e) script="$OPTARG" ;;
        h) Usage ;;
        \?) echo "Error: opción inválida -$OPTARG"; Usage ;;
        :) echo "Error: -$OPTARG requiere argumento"; Usage ;;
    esac
done

# Validate inputs
[[ -z "$vol_STE" ]] && { echo "Error: falta -s"; Usage; }
[[ -z "$vol_FID" ]] && { echo "Error: falta -f"; Usage; }
[[ -z "$method"  ]] && { echo "Error: falta -m"; Usage; }

for f in "$vol_STE" "$vol_FID" "$method"; do
    if [[ ! -f "$f" ]]; then
        echo "Error: no se encontró '$f'"
        exit 1
    fi
done

# Resolver script 
script_path="$(command -v "$script" 2>/dev/null || echo "$script")"

if [[ ! -f "$script_path" ]]; then
    echo "Error: no se encontró el script original: $script"
    exit 1
fi

if [[ ! -x "$script_path" ]]; then
    runner=(bash "$script_path")
else
    runner=("$script_path")
fi

# Ejecutar pasando inputs al script original
{
    printf '%s\n' "$vol_STE"
    printf '%s\n' "$vol_FID"
    printf '%s\n' "$method"
} | "${runner[@]}"