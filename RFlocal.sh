#!/usr/bin/env bash
# Codigo para obtener RFlocal (B1 map)
# Autor: Yessenia Garcia Rizo

Usage() {
cat <<USAGE
Usage:
  $(basename "$0") -s STE -f FID -m METHOD [options]

Example:
  $(basename "$0") \
    -s STE.nii.gz \
    -f FID.nii.gz \
    -m method

Compulsory arguments:
  -s    Volumen STE (ej. STE.nii.gz)
  -f    Volumen FID (ej. FID.nii.gz)
  -m    Archivo method del mapa B1

Optional arguments:
  -o    Prefijo de salida [default: prefixdream]
  -h    Mostrar ayuda

Pipeline:
  1) Extraer valor ##$SteamPulse
  2) Concatenar FID + STE
  3) Ejecutar QI para generar mapa B1

Notes:
  - Requiere: mrcat (MRtrix3) y qi
USAGE
exit 1
}

# =========================
# Defaults
# =========================
output_prefix="prefixdream"

# =========================
# Parse args
# =========================
while getopts ":s:f:m:o:h" opt; do
  case "$opt" in
    s) vol_STE="$OPTARG" ;;
    f) vol_FID="$OPTARG" ;;
    m) archivo_method="$OPTARG" ;;
    o) output_prefix="$OPTARG" ;;
    h) Usage ;;
    \?) echo "Error: opción inválida -$OPTARG"; Usage ;;
    :) echo "Error: la opción -$OPTARG requiere un argumento"; Usage ;;
  esac
done

# =========================
# Validaciones
# =========================
[[ -z "$vol_STE" ]] && { echo "Error: falta -s"; Usage; }
[[ -z "$vol_FID" ]] && { echo "Error: falta -f"; Usage; }
[[ -z "$archivo_method" ]] && { echo "Error: falta -m"; Usage; }

if [[ ! -f "$vol_STE" ]]; then
  echo "Error: no existe $vol_STE"
  exit 1
fi

if [[ ! -f "$vol_FID" ]]; then
  echo "Error: no existe $vol_FID"
  exit 1
fi

if [[ ! -f "$archivo_method" ]]; then
  echo "Error: no existe $archivo_method"
  exit 1
fi

# Dependencias
for cmd in mrcat qi; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: comando '$cmd' no encontrado en PATH"
    exit 1
  fi
done

echo "      Generación de mapa B1 con QI"



# 1) Extraer SteamPulse

echo "[1/3] Extrayendo ##\$SteamPulse desde method..."

linea=$(grep "##\$SteamPulse=" "$archivo_method")

if [[ -z "$linea" ]]; then
  echo "Error: no se encontró ##\$SteamPulse="
  exit 1
fi

valor_tercero=$(echo "$linea" | sed 's/.*(//' | sed 's/).*//' | awk '{print $3}' | tr -d ',' | xargs)

if [[ -z "$valor_tercero" ]]; then
  echo "Error: no se pudo extraer el valor de SteamPulse"
  exit 1
fi

echo "➤ SteamPulse = $valor_tercero"


# 2) Concatenar volúmenes

echo "[2/3] Concatenando FID + STE..."

mrcat -axis 3 "$vol_FID" "$vol_STE" dream_file.nii.gz || {
  echo "Error en mrcat"
  exit 1
}

echo "Archivo generado: dream_file.nii.gz"


# 3) Ejecutar QI

echo "[3/3] Generando mapa B1 con QI..."

qi dream dream_file.nii.gz \
  --out="$output_prefix" \
  --order=f \
  -a "$valor_tercero" || {
  echo "Error en qi"
  exit 1
}


echo "Mapa B1 generado: ${output_prefix}_B1map.nii.gz"
